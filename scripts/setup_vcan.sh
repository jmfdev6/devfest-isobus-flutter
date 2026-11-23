#!/usr/bin/env bash
# Cria um barramento CAN virtual (vcan) — nenhum hardware necessário.
# Uso: ./setup_vcan.sh [interface]   (padrão: vcan0)
set -euo pipefail
IFACE="${1:-vcan0}"

# 1. Carrega o driver vcan do kernel (só precisa uma vez por boot).
sudo modprobe vcan

# 2. Cria a interface, se ainda não existir.
if ! ip link show "$IFACE" >/dev/null 2>&1; then
  sudo ip link add dev "$IFACE" type vcan
fi

# 3. Sobe a interface.
sudo ip link set up "$IFACE"

ip -details -brief link show "$IFACE"
echo "OK: $IFACE pronta. Teste com: candump $IFACE"
