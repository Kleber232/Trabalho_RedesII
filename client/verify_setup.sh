#!/bin/bash
# Verificação rápida do ambiente: roda dentro do container "client"
# depois que "docker compose up -d" estiver de pé.
#
# Uso: docker compose exec client bash /netem/../client/verify_setup.sh
#      (ou copie para /workspace e rode de lá)

set -e
SERVER=${1:-server}

echo "== Versão do curl (deve listar HTTP3) =="
curl --version | head -n 5
echo

echo "== Teste HTTP/1.1 (porta 80, sem TLS) =="
curl -v --http1.1 "http://${SERVER}:80/" 2>&1 | grep -E "HTTP/1.1|< HTTP"
echo

echo "== Teste HTTP/2 sobre TLS 1.3 (porta 443/tcp) =="
curl -vk --http2 "https://${SERVER}:443/" 2>&1 | grep -E "HTTP/2|SSL connection|< HTTP"
echo

echo "== Teste HTTP/3 sobre QUIC (porta 443/udp) =="
curl -vk --http3 "https://${SERVER}:443/" 2>&1 | grep -E "HTTP/3|using HTTP/3|< HTTP"
echo

echo "== Teste iperf3 (UDP, Cenário A) =="
iperf3 -c "${SERVER}" -u -b 10M -t 3
echo

echo "Se todos os blocos acima retornaram resposta sem erro, o ambiente base está OK."
