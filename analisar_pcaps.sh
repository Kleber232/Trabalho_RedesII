#!/bin/bash
# analisar_pcaps.sh
# Roda a partir de ~/projetos/projeto-redes2 (onde fica results/raw/)
# Gera 3 arquivos de saida pequenos (texto) para me mandar de volta:
#   overhead_cenario_a.tsv, overhead_cenario_b.tsv, overhead_cenario_c.tsv
#   retransmissoes_tcp.csv
#
# Requer tshark/capinfos instalados no HOST (fora do container):
#   sudo apt install tshark

set -e
cd results/raw

echo "[1/4] Overhead - Cenario A (pode demorar, arquivos grandes)..."
capinfos -T -c -d -y cenario_a/*.pcapng > overhead_cenario_a.tsv 2>/dev/null

echo "[2/4] Overhead - Cenario B..."
capinfos -T -c -d -y cenario_b/*.pcapng > overhead_cenario_b.tsv 2>/dev/null

echo "[3/4] Overhead - Cenario C..."
capinfos -T -c -d -y cenario_c/*.pcapng > overhead_cenario_c.tsv 2>/dev/null

echo "[4/4] Retransmissoes TCP (so faz sentido para HTTP/1.1 e HTTP/2 - QUIC nao e TCP)..."
echo "arquivo,retransmissoes_tcp" > retransmissoes_tcp.csv
for f in cenario_b/http1.1_*.pcapng cenario_b/http2_*.pcapng cenario_c/http1.1_*.pcapng cenario_c/http2_*.pcapng; do
    [ -f "$f" ] || continue
    n=$(tshark -r "$f" -Y "tcp.analysis.retransmission" 2>/dev/null | wc -l)
    echo "$f,$n" >> retransmissoes_tcp.csv
done

echo
echo "Pronto. Me manda estes 4 arquivos (sao pequenos, so texto):"
echo "  results/raw/overhead_cenario_a.tsv"
echo "  results/raw/overhead_cenario_b.tsv"
echo "  results/raw/overhead_cenario_c.tsv"
echo "  results/raw/retransmissoes_tcp.csv"
