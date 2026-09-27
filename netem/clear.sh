#!/bin/bash

echo "[NetEm] Removendo regras..."

docker compose exec client sh -c 'tc qdisc del dev eth0 root 2>/dev/null || true'
docker compose exec server sh -c 'tc qdisc del dev eth0 root 2>/dev/null || true'

echo "[NetEm] Regras removidas."
