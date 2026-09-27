#!/bin/bash

set -e

echo "[NetEm] Configurando Cenário C..."

./netem/clear.sh

echo "[NetEm] Client: +50 ms e 3% de perda..."
docker compose exec client tc qdisc add dev eth0 root netem delay 50ms loss 3%

echo "[NetEm] Server: +50 ms e 3% de perda..."
docker compose exec server tc qdisc add dev eth0 root netem delay 50ms loss 3%

echo "[NetEm] Cenário C configurado com sucesso."
echo "[NetEm] RTT esperado: aproximadamente 100 ms."
echo "[NetEm] Perda configurada: 3% em cada direção."
