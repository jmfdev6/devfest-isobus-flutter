#!/usr/bin/env bash
# Teste automático do Task Controller da cabine, usando a plantadeira (seeder) como implemento.
#
# Uso: ./scripts/teste_tc.sh          (antes: compilar com cmake e rodar "dart pub get" em pacotes/agiso/)
#
# Usa a vcan0 se ela existir; senão, cria uma bolha só para o teste.
# Confere, em ordem:
#   1. o TC recebeu o DDOP da plantadeira
#   2. o TC assinou os valores do implemento
#   3. os valores chegam (a capacidade do depósito, por exemplo)
#   4. o TC manda a taxa alvo (elemento 3, DDI 11) e o implemento devolve o novo valor
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

# espera até $2 segundos por uma linha da cabine que case com $1
esperar() {
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

# a cabine em modo texto, recebendo comandos por um fifo
mkfifo "$PASTA/comandos"
(cd pacotes/agiso && exec $BOLHA dart run bin/main.dart vcan0 <"$PASTA/comandos" >"$CABINE" 2>&1) &
exec 3>"$PASTA/comandos"
sleep 3
(cd build && exec $BOLHA ./seeder --interface vcan0 >"$PASTA/seeder.log" 2>&1 </dev/null) &
$BOLHA ./scripts/send_velocidade.sh 8 >/dev/null 2>&1 </dev/null &

echo "Testando o Task Controller com a plantadeira (até 1 minuto)..."
conferir "recebeu o DDOP"                   "^TC  \| DDOP recebido de 0x"   60
conferir "leu os elementos do DDOP"         "^TC  \| DET 3 Product"          5
conferir "assinou os valores"               "^TC  \| assinei [0-9]+ valores" 15
conferir "recebeu valores do implemento"    "^TC  \| Bin Capacity \(3/79\) = " 10

echo "t 3 11 20000" >&3
conferir "a taxa alvo foi aceita pela pilha" "TC: elemento 3 DDI 11 = 20000: 0" 5
conferir "o implemento devolveu a nova taxa" "^TC  \| Target Rate \(3/11\) = 20000" 10
conferir "a taxa chegou ao Dart (evento Taxa)" "^DART\| taxa alvo 20000" 5

# controle de seções: modo automático (elemento 2 = barra, DDI 160) e setpoint das seções (DDI 290,
# 2 bits por seção, 01 = liga). A plantadeira tem 6 seções; as que não existem voltam como 11.
echo "t 2 160 1" >&3
conferir "o TC pôs as seções em automático" "^TC  \| Section Control State \(2/160\) = 1" 10
echo "t 2 290 1365" >&3 # 0x555: o TC liga as 6 (e os switches acompanham)
conferir "o TC ligou as 6" "^TC  \| Actual Work State 1-16 \(2/161\) = -2731" 10
conferir "com as seções plantando, o depósito desceu" "^TC  \| Bin Level \(3/78\) = 14[0-9]{4}$" 10
conferir "o depósito chegou ao Dart (evento Deposito)" "^DART\| depósito 14[0-9]{4} sementes" 5
echo "b 6005" >&3 # o operador desliga o switch da 6
conferir "o switch cortou a seção 6 no automático" "^TC  \| Actual Work State 1-16 \(2/161\) = -3755" 10
echo "t 2 290 5" >&3 # 0x005: só a 1 e a 2, as outras cortadas
conferir "o TC cortou as seções 3 a 6" "^TC  \| Actual Work State 1-16 \(2/161\) = -4091" 10
conferir "as seções chegaram ao Dart (evento Secoes)" "^DART\| seções ■■□□□□" 5

if ((FALHAS == 0)); then
  echo "PASSOU"
else
  echo "FALHOU ($FALHAS)"
  echo "--- cabine ---"; cat "$CABINE"
fi
exit $((FALHAS > 0))
