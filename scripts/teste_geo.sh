#!/usr/bin/env bash
# Teste automático do TC-GEO (taxa pelo mapa) e TC-SEC (corte de seções) com GPS NMEA 2000.
#
# Uso: ./scripts/teste_geo.sh          (antes: compilar com cmake e rodar "dart pub get" em pacotes/agiso/)
#
# Sobe a cabine em modo texto, a plantadeira e o trator (a 30 km/h, para o teste ser rápido).
# Usa a vcan0 se ela existir; senão, cria uma bolha só para o teste. Confere, em ordem:
#   1. a posição NMEA 2000 do trator chega ao Dart
#   2. com o TC automático, a taxa sai do mapa (12 mil na 1ª zona, 20 mil na 2ª)
#   3. as 6 seções ligam dentro do talhão e cortam na cabeceira
#   4. na volta, a seção que passaria sobre o já plantado fica cortada
set -uo pipefail
cd "$(dirname "$0")/.."

PASTA=$(mktemp -d)
CABINE="$PASTA/cabine.log"
BOLHA=""
if ! ip link show vcan0 >/dev/null 2>&1; then
  ./scripts/bolha.sh criar >/dev/null || exit 1
  BOLHA="$PWD/scripts/bolha.sh entrar"
fi

limpar() {
  exec 3>&- 2>/dev/null
  kill $(jobs -p) 2>/dev/null
  [[ -n "$BOLHA" ]] && ./scripts/bolha.sh destruir >/dev/null 2>&1
  rm -rf "$PASTA"
}
trap limpar EXIT

esperar() { # espera até $2 segundos por uma linha da cabine que case com $1
  for ((i = 0; i < $2; i++)); do
    grep -qE "$1" "$CABINE" && return 0
    sleep 1
  done
  return 1
}

FALHAS=0
conferir() { # $1 = descrição, $2 = padrão, $3 = segundos
  if esperar "$2" "$3"; then
    echo "  ok     $1"
  else
    echo "  FALHOU $1  (esperava: $2)"
    FALHAS=$((FALHAS + 1))
  fi
}

mkfifo "$PASTA/comandos"
(cd pacotes/agiso && exec $BOLHA dart run bin/main.dart vcan0 <"$PASTA/comandos" >"$CABINE" 2>&1) &
exec 3>"$PASTA/comandos"
sleep 3
(cd build && exec $BOLHA ./seeder --interface vcan0 >"$PASTA/seeder.log" 2>&1 </dev/null) &

echo "Testando TC-GEO e TC-SEC com o trator (até 2 minutos)..."
conferir "o TC conectou à plantadeira" "^TC  \| assinei [0-9]+ valores" 60
echo "g" >&3
conferir "o TC automático ligou" "^DART\| TC automático LIGADO" 5
$BOLHA ./build/trator vcan0 30 >"$PASTA/trator.log" 2>&1 </dev/null &

conferir "a posição NMEA 2000 chegou ao Dart" "^DART\| GPS -11\.86" 10
conferir "GEO: taxa da 1ª zona (12 mil)" "^DART\| GEO taxa da zona: 12000" 15
conferir "SEC: as 6 seções ligaram no talhão" "^TC  \| Actual Work State 1-16 \(2/161\) = -2731" 15
conferir "GEO: taxa da 2ª zona (20 mil)" "^DART\| GEO taxa da zona: 20000" 15
conferir "a plantadeira recebeu a taxa da zona" "^TC  \| Target Rate \(3/11\) = 20000" 10
conferir "SEC: cortou tudo na cabeceira" "^DART\| SEC seções pedidas □□□□□□" 30
conferir "SEC: na volta, cortou a seção sobreposta" "^DART\| SEC seções pedidas ■■■■■□" 20
conferir "a plantadeira obedeceu ao corte" "^TC  \| Actual Work State 1-16 \(2/161\) = -3755" 10

if ((FALHAS == 0)); then
  echo "PASSOU"
else
  echo "FALHOU ($FALHAS)"
  echo "--- cabine (DART e seções) ---"; grep -E "^DART|2/161|3/11" "$CABINE" | tail -40
fi
exit $((FALHAS > 0))
