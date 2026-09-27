#!/bin/bash
# run_experiments.sh — orquestra os 3 cenários (A/B/C), 10 repetições cada,
# captura .pcapng via tshark no client, logs/metricas em results/raw/.
#
# [NÃO TESTADO POR INTEIRO] — rode com --only a primeiro pra validar o mecanismo.
#
# Uso:
#   ./run_experiments.sh              # roda tudo (A, B, C)
#   ./run_experiments.sh --only a     # roda só o cenário A
#   ./run_experiments.sh --only b
#   ./run_experiments.sh --only c

set -euo pipefail
cd "$(dirname "$0")"   # garante que rodamos a partir da raiz (netem/*.sh usam caminho relativo)

REPEATS=10
SERVER=server
RESULTS_DIR="results/raw"
RATES_A=(10 50 100 250 500)          # Mbps — [SUGESTÃO], ajuste se quiser mais pontos
FILES_B=(testfile_100M.bin testfile_500M.bin testfile_1G.bin)
RECONNECT_REPS_C=20                  # nº de handshakes isolados p/ medir reconexão

ONLY="${2:-}"
if [ "${1:-}" = "--only" ]; then
    ONLY="${2:-}"
fi

mkdir -p "$RESULTS_DIR/cenario_a" "$RESULTS_DIR/cenario_b" "$RESULTS_DIR/cenario_c"

log() { echo "[run_experiments] $*"; }

start_capture() {
    # $1 = caminho relativo dentro de results/raw (sem extensão)
    docker compose exec -d client tshark -i eth0 -w "/results/raw/$1.pcapng" 2>/dev/null
    sleep 1   # tempo pro tshark inicializar antes do tráfego começar
}

stop_capture() {
    docker compose exec -T client pkill -INT tshark 2>/dev/null || true
    sleep 1   # tempo pro tshark fazer flush do arquivo .pcapng
}

# ============================================================
# CENÁRIO A — UDP puro, iperf3, várias taxas
# ============================================================
run_scenario_a() {
    log "=== Cenário A: UDP puro (iperf3) ==="
    ./netem/scenario_a.sh

    for rate in "${RATES_A[@]}"; do
        for rep in $(seq 1 "$REPEATS"); do
            base="cenario_a/rate_${rate}M_rep_${rep}"
            log "A: rate=${rate}Mbps rep=${rep}/${REPEATS}"
            start_capture "$base"
            docker compose exec -T client \
                iperf3 -c "$SERVER" -u -b "${rate}M" -t 10 -J \
                > "$RESULTS_DIR/rate_${rate}M_rep_${rep}.json" \
                2> "$RESULTS_DIR/cenario_a/rate_${rate}M_rep_${rep}.err" || \
                log "  [AVISO] iperf3 retornou erro nesta repetição, ver .err"
            stop_capture
        done
    done
}

# ============================================================
# CENÁRIO B — TCP grande (HTTP/1.1, HTTP/2, HTTP/3), ~20ms RTT
# ============================================================
run_scenario_b() {
    log "=== Cenário B: arquivos grandes (HTTP/1.1 vs HTTP/2 vs HTTP/3) ==="
    ./netem/scenario_b.sh

    csv="$RESULTS_DIR/cenario_b_metrics.csv"
    if [ ! -f "$csv" ]; then
        echo "scenario,protocol,file,rep,time_namelookup,time_connect,time_appconnect,time_starttransfer,time_total,size_download_bytes,http_code" > "$csv"
    fi

    for file in "${FILES_B[@]}"; do
        for proto in http1.1 http2 http3; do
            case "$proto" in
                http1.1) flags="--http1.1"; url="http://${SERVER}:80/files/${file}" ;;
                http2)   flags="-k --http2"; url="https://${SERVER}:443/files/${file}" ;;
                http3)   flags="-k --http3"; url="https://${SERVER}:443/files/${file}" ;;
            esac
            for rep in $(seq 1 "$REPEATS"); do
                base="cenario_b/${proto}_${file%.bin}_rep_${rep}"
                log "B: proto=${proto} file=${file} rep=${rep}/${REPEATS}"
                start_capture "$base"
                line=$(docker compose exec -T client curl -s -o /dev/null $flags \
                    -w "%{time_namelookup},%{time_connect},%{time_appconnect},%{time_starttransfer},%{time_total},%{size_download},%{http_code}" \
                    "$url" || echo "ERRO,ERRO,ERRO,ERRO,ERRO,ERRO,000")
                stop_capture
                echo "cenario_b,${proto},${file},${rep},${line}" >> "$csv"
            done
        done
    done
}

# ============================================================
# CENÁRIO C — alta latência + perda, muitos objetos + reconexão
# ============================================================
run_scenario_c() {
    log "=== Cenário C: objetos concorrentes + reconexão (alta latência/perda) ==="
    ./netem/scenario_c.sh

    csv_batch="$RESULTS_DIR/cenario_c_batch.csv"
    csv_reconnect="$RESULTS_DIR/cenario_c_reconnect.csv"
    [ -f "$csv_batch" ]      || echo "scenario,protocol,rep,total_time_s" > "$csv_batch"
    [ -f "$csv_reconnect" ]  || echo "scenario,protocol,rep,time_appconnect,time_starttransfer,time_total,http_code" > "$csv_reconnect"

    for proto in http1.1 http2 http3; do
        case "$proto" in
            http1.1) flags="--http1.1"; scheme="http"; port=80 ;;
            http2)   flags="-k --http2"; scheme="https"; port=443 ;;
            http3)   flags="-k --http3"; scheme="https"; port=443 ;;
        esac

        # --- teste de objetos concorrentes (100 objetos, 1 lote por repetição) ---
        for rep in $(seq 1 "$REPEATS"); do
            base="cenario_c/${proto}_batch_rep_${rep}"
            log "C: proto=${proto} [lote 100 objetos] rep=${rep}/${REPEATS}"
            # gera lista de URLs dos 100 objetos dentro do container
            urls=$(docker compose exec -T client sh -c \
                "for i in \$(seq 1 100); do echo url = \\\"${scheme}://${SERVER}:${port}/files/objects/obj_\${i}.bin\\\"; done")
            start_capture "$base"
            t0=$(date +%s.%N)
            echo "$urls" | docker compose exec -T client sh -c \
                "cat > /tmp/urls_${proto}.txt && curl -s -o /dev/null $flags --parallel --parallel-max 10 -K /tmp/urls_${proto}.txt" \
                || log "  [AVISO] lote de objetos retornou erro nesta repetição"
            t1=$(date +%s.%N)
            stop_capture
            total=$(echo "$t1 - $t0" | bc)
            echo "cenario_c,${proto},${rep},${total}" >> "$csv_batch"
        done

        # --- teste de reconexão (handshake isolado repetido) ---
        for rep in $(seq 1 "$RECONNECT_REPS_C"); do
            log "C: proto=${proto} [reconexão isolada] rep=${rep}/${RECONNECT_REPS_C}"
            line=$(docker compose exec -T client curl -s -o /dev/null $flags \
                -w "%{time_appconnect},%{time_starttransfer},%{time_total},%{http_code}" \
                "${scheme}://${SERVER}:${port}/files/objects/obj_1.bin" || echo "ERRO,ERRO,ERRO,000")
            echo "cenario_c,${proto},${rep},${line}" >> "$csv_reconnect"
        done
    done
}

# ============================================================
# MAIN
# ============================================================
case "$ONLY" in
    a) run_scenario_a ;;
    b) run_scenario_b ;;
    c) run_scenario_c ;;
    "") run_scenario_a; run_scenario_b; run_scenario_c ;;
    *) echo "Uso: $0 [--only a|b|c]"; exit 1 ;;
esac

./netem/clear.sh
log "Concluído. Resultados em ${RESULTS_DIR}/"
