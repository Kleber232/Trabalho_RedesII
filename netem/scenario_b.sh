#!/bin/bash

set -e

echo "[NetEm] Configurando Cenário B..."

./netem/clear.sh

echo "[NetEm] Client: +10 ms..."
docker compose exec client tc qdisc add dev eth0 root netem delay 10ms

echo "[NetEm] Server: +10 ms..."
docker compose exec server tc qdisc add dev eth0 root netem delay 10ms

echo "[NetEm] Cenário B configurado com sucesso."
echo "[NetEm] RTT esperado: aproximadamente 20 ms."
