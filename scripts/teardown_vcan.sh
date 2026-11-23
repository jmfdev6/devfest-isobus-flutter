#!/usr/bin/env bash
# Remove a interface vcan criada por setup_vcan.sh.
set -euo pipefail
IFACE="${1:-vcan0}"
if ip link show "$IFACE" >/dev/null 2>&1; then
  sudo ip link delete "$IFACE"
  echo "Removida: $IFACE"
else
  echo "$IFACE não existe; nada a fazer."
fi
