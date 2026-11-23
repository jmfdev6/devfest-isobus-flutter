#!/usr/bin/env bash
# Envia um quadro J1939 EEC1 (PGN 0xF004) com a rotação pedida.
#
# Uso: ./send_rpm.sh <rpm> [interface] [--dry-run]
#   ./send_rpm.sh 621        -> cansend vcan0 0CF00401#FFFFFF6813FFFFFF
#
# Como o quadro é montado:
#   ID 0x0CF00401 = prioridade 3 | PGN 0xF004 (EEC1) | origem 0x01 (motor)
#   bytes 4 e 5 (ordem Intel, byte menos significativo primeiro) = rpm / 0,125
set -euo pipefail

RPM="${1:?uso: send_rpm.sh <rpm> [interface] [--dry-run]}"
IFACE="vcan0"
DRY_RUN=0
for arg in "${@:2}"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) IFACE="$arg" ;;
  esac
done

# rpm -> valor bruto (resolução 0,125 rpm/bit). Aceita casas decimais (ex.: 621.5).
RAW=$(awk -v r="$RPM" 'BEGIN { v = r / 0.125; if (v < 0 || v > 64255) exit 1; printf "%d", v + 0.5 }') \
  || { echo "rpm fora da faixa (0 a 8031,875)" >&2; exit 1; }

LO=$(printf '%02X' $((RAW & 0xFF)))
HI=$(printf '%02X' $(((RAW >> 8) & 0xFF)))
FRAME="0CF00401#FFFFFF${LO}${HI}FFFFFF"

echo "rpm=$RPM  bruto=$RAW (0x$(printf '%04X' "$RAW"))  quadro=$FRAME"
if [[ "$DRY_RUN" -eq 1 ]]; then
  exit 0
fi
cansend "$IFACE" "$FRAME"
