#!/bin/bash

echo "[NetEm] Configurando Cenário A..."

./netem/clear.sh

echo "[NetEm] Cenário A: rede estável, sem perda e sem atraso artificial."
echo "[NetEm] Nenhuma regra de atraso/perda será aplicada."

echo "[NetEm] Cenário A configurado."
