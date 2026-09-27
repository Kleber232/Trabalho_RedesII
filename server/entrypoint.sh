#!/bin/bash
set -e

CERT_DIR=/usr/local/nginx/certs
HTML_DIR=/usr/local/nginx/html
LOG_DIR=/usr/local/nginx/logs

mkdir -p "$LOG_DIR"

# -------------------------------------------------------------------------
# 1. Certificado TLS autoassinado (gerado uma única vez)
# -------------------------------------------------------------------------
if [ ! -f "$CERT_DIR/server.crt" ]; then
    echo "[entrypoint] Gerando certificado TLS autoassinado..."
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$CERT_DIR/server.key" \
        -out "$CERT_DIR/server.crt" \
        -days 365 \
        -subj "/C=BR/ST=PI/L=Picos/O=UFPI/CN=server"
fi

# -------------------------------------------------------------------------
# 2. Arquivos de teste
#    - Cenário B (TCP grande): arquivos de 100 MB, 500 MB e 1 GB
#    - Cenário C (QUIC/objetos concorrentes): ~100 objetos pequenos
# -------------------------------------------------------------------------
mkdir -p "$HTML_DIR/files/objects"

if [ ! -f "$HTML_DIR/files/testfile_100M.bin" ]; then
    echo "[entrypoint] Gerando arquivos de teste para o Cenário B..."
    dd if=/dev/urandom of="$HTML_DIR/files/testfile_100M.bin" bs=1M count=100  status=none
    dd if=/dev/urandom of="$HTML_DIR/files/testfile_500M.bin" bs=1M count=500  status=none
    dd if=/dev/urandom of="$HTML_DIR/files/testfile_1G.bin"   bs=1M count=1000 status=none
fi

if [ ! -f "$HTML_DIR/files/objects/obj_1.bin" ]; then
    echo "[entrypoint] Gerando ~100 objetos pequenos para o Cenário C..."
    for i in $(seq 1 100); do
        size_kb=$(( (RANDOM % 40) + 10 ))  # entre 10KB e 50KB
        dd if=/dev/urandom of="$HTML_DIR/files/objects/obj_${i}.bin" \
            bs=1K count="$size_kb" status=none
    done
fi

# -------------------------------------------------------------------------
# 3. iperf3 server em background (usado no Cenário A - UDP puro)
# -------------------------------------------------------------------------
echo "[entrypoint] Iniciando iperf3 server (porta 5201)..."
iperf3 -s -D --logfile "$LOG_DIR/iperf3_server.log"

# -------------------------------------------------------------------------
# 4. NGINX em foreground (mantém o container vivo e logando no stdout)
# -------------------------------------------------------------------------
echo "[entrypoint] Testando configuração do NGINX..."
nginx -t

echo "[entrypoint] Iniciando NGINX (HTTP/1.1:80, HTTP/2+TLS:443/tcp, HTTP/3:443/udp)..."
exec nginx -g "daemon off;"
