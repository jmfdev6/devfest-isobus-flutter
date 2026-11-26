#!/usr/bin/env bash
# Simula o trator andando: envia a velocidade de solo (PGN 0xFE49) 10 vezes por segundo.
# A plantadeira (./build/seeder) só sai do alarme "Machine Speed Not Detected" com isso.
#
# Uso: ./send_velocidade.sh <km/h> [interface]      (Ctrl+C para parar)
#
# Como o quadro é montado:
#   ID 0x0CFE4901 = prioridade 3 | PGN 0xFE49 (velocidade de solo) | origem 0x01
#   bytes 0-1 = velocidade em mm/s, bytes 2-5 = distância em mm, byte 7 = 01 (para frente)
#
# Antes, o "trator" reivindica o endereço 0x01 (PGN 0xEE00, ID 18EEFF01) com um NAME:
# a AgIsoStack++ ignora velocidade vinda de quem não se apresentou na rede.
#   NAME EE07E0AF00860020 = identidade 2030, fabricante 1407, função 134 (trator), grupo 2 (agrícola)
set -euo pipefail

KMH="${1:?uso: send_velocidade.sh <km/h> [interface]}"
IFACE="${2:-vcan0}"
MMS=$(awk -v v="$KMH" 'BEGIN { m = v / 3.6 * 1000; if (m < 0 || m > 64255) exit 1; printf "%d", m + 0.5 }') \
  || { echo "velocidade fora da faixa (0 a 231 km/h)" >&2; exit 1; }

le() { # valor em hexadecimal little-endian com $2 bytes
  local v=$1 n=$2 s=""
  for ((i = 0; i < n; i++)); do s+=$(printf '%02X' $(((v >> (8 * i)) & 0xFF))); done
  echo "$s"
}

echo "velocidade $KMH km/h ($MMS mm/s) em $IFACE, Ctrl+C para parar"
cansend "$IFACE" "18EEFF01#EE07E0AF00860020"
sleep 0.3 # a norma pede 250 ms antes de usar o endereço
DIST=0
N=0
while true; do
  # repete o anúncio a cada 5 s, para quem entrou na rede depois
  if ((N++ % 50 == 0)); then cansend "$IFACE" "18EEFF01#EE07E0AF00860020"; fi
  cansend "$IFACE" "0CFE4901#$(le "$MMS" 2)$(le "$DIST" 4)FF01"
  DIST=$(((DIST + MMS / 10) & 0xFFFFFFFF))
  sleep 0.1
done
