#!/usr/bin/env bash
# demo.sh — a demo inteira com um comando
#
#   ./demo.sh preparar            baixa o que falta (submódulo, pacotes) e compila tudo
#   ./demo.sh iniciar [opções]    sobe a rede CAN, a cabine, a plantadeira e o simulador
#   ./demo.sh parar               desliga tudo
#   ./demo.sh status              o que está rodando
#   ./demo.sh testar              as verificações e os testes com a rede CAN
#   ./demo.sh rede                abre um shell na rede da demo (para o candump, por exemplo)
#
# Opções do iniciar:
#   --automatico      sem motorista: o ./build/trator anda sozinho e o simulador só assiste
#   o resto vai para o simulador
#
# A rede: usa a vcan0 se ela existir (./scripts/setup_vcan.sh, com sudo); senão cria uma
# "bolha" só desta demo (sem sudo, veja scripts/bolha.sh).
set -euo pipefail
cd "$(dirname "$0")"
RAIZ=$PWD
DEMO=$RAIZ/.demo
CABINE=$RAIZ/apps/cabine/build/linux/x64/release/bundle/cabine
SIMULADOR=$RAIZ/apps/simulador/build/linux/x64/release/bundle/simulador

azul() { printf '\033[1;34m%s\033[0m\n' "$*"; }
erro() {
  printf '\033[1;31merro:\033[0m %s\n' "$*" >&2
  exit 1
}

# o Flutter do mise.toml (3.47.9), se o mise estiver instalado; senão, o do PATH
flutter_() {
  if command -v mise >/dev/null 2>&1; then mise exec -- flutter "$@"; else flutter "$@"; fi
}
dart_() {
  if command -v mise >/dev/null 2>&1; then mise exec -- dart "$@"; else dart "$@"; fi
}

preparar() {
  [[ "$(uname)" == Linux ]] || erro "a demo precisa de Linux (SocketCAN)"
  for c in cmake git pkg-config; do
    command -v "$c" >/dev/null || erro "falta o $c (veja os pré-requisitos no README)"
  done
  command -v flutter >/dev/null || command -v mise >/dev/null ||
    erro "falta o Flutter: instale o mise (https://mise.jdx.dev) ou o Flutter 3.47.9"
  if command -v mise >/dev/null 2>&1; then
    # o mise.toml fixa o Flutter 3.47.9: confia neste projeto e baixa a versão, se faltar
    mise trust --quiet "$RAIZ/mise.toml" >/dev/null 2>&1 || true
    azul "Flutter do mise.toml..."
    mise install
  fi
  if [[ ! -f third_party/AgIsoStack-plus-plus/CMakeLists.txt ]]; then
    azul "baixando a AgIsoStack++ (submódulo)..."
    git submodule update --init --recursive
  fi
  azul "compilando a ponte, o trator e a plantadeira (C++)..."
  local gerador=()
  command -v ninja >/dev/null && gerador=(-G Ninja)
  [[ -f build/CMakeCache.txt ]] || cmake -S . -B build "${gerador[@]}" -DCMAKE_BUILD_TYPE=Release
  cmake --build build
  azul "pacote Dart..."
  (cd pacotes/agiso && dart_ pub get >/dev/null)
  for app in cabine simulador; do
    azul "compilando o app $app (Flutter)..."
    (cd "apps/$app" && flutter_ pub get >/dev/null && flutter_ build linux --release)
  done
  azul "pronto. Agora: ./demo.sh iniciar"
}

# A rede da demo: a vcan0 deste computador, ou a bolha (sem sudo)
PREFIXO=()
abrir_rede() {
  if ip link show vcan0 >/dev/null 2>&1; then
    PREFIXO=()
    echo "vcan0" >"$DEMO/rede"
  else
    ./scripts/bolha.sh criar >/dev/null || erro "não deu para criar a rede (veja 'Se der errado' no README)"
    PREFIXO=("$RAIZ/scripts/bolha.sh" entrar)
    echo "bolha" >"$DEMO/rede"
  fi
}

# sobe um programa na rede da demo, guarda o pid e o registro
rodar() { # $1 = nome, $2 = pasta, o resto = o comando
  local nome=$1 pasta=$2
  shift 2
  (cd "$pasta" && exec "${PREFIXO[@]}" "$@" >"$DEMO/$nome.log" 2>&1 </dev/null) &
  echo $! >"$DEMO/$nome.pid"
}

esperar() { # $1 = arquivo, $2 = padrão, $3 = segundos
  for ((i = 0; i < $3 * 2; i++)); do
    grep -q "$2" "$1" 2>/dev/null && return 0
    sleep 0.5
  done
  return 1
}

rodando() { [[ -f "$DEMO/$1.pid" ]] && kill -0 "$(cat "$DEMO/$1.pid")" 2>/dev/null; }

iniciar() {
  local automatico=0 tc=() resto=()
  while [[ $# -gt 0 ]]; do
    case $1 in
      --automatico) automatico=1 ;;
      *) resto+=("$1") ;;
    esac
    shift
  done
  # sem motorista, o trator automático percorre o talhão da demo: a cabine fica nele
  ((automatico)) && tc+=(--talhao-demo)
  [[ -x "$CABINE" && -x "$SIMULADOR" && -x build/seeder ]] || preparar
  parar >/dev/null 2>&1 || true
  mkdir -p "$DEMO"
  abrir_rede
  azul "rede: $(cat "$DEMO/rede")"

  # a ordem importa: a cabine antes da plantadeira (ela guarda o que mostrou na tela)
  azul "cabine..."
  rodar cabine "$RAIZ" "$CABINE" "${tc[@]}"
  sleep 4
  azul "plantadeira..."
  rodar plantadeira "$RAIZ/build" ./seeder --interface vcan0
  esperar "$DEMO/cabine.log" "assinei" 60 || erro "a plantadeira não conectou ao TC: veja $DEMO/cabine.log"
  if ((automatico)); then
    azul "trator automático e simulador (só assistindo)..."
    rodar trator "$RAIZ" ./build/trator vcan0 8
    rodar simulador "$RAIZ" "$SIMULADOR" --ouvinte
  else
    azul "simulador (você dirige)..."
    rodar simulador "$RAIZ" "$SIMULADOR" "${resto[@]}"
  fi
  cat <<EOF

  A demo está no ar. No simulador: W acelera, A/D volante,
  C câmera. Registros em .demo/   Para desligar: ./demo.sh parar
EOF
}

parar() {
  [[ -d "$DEMO" ]] || return 0
  for p in "$DEMO"/*.pid; do
    [[ -f "$p" ]] || continue
    kill "$(cat "$p")" 2>/dev/null || true
    rm -f "$p"
  done
  if [[ "$(cat "$DEMO/rede" 2>/dev/null)" == bolha ]]; then
    ./scripts/bolha.sh destruir >/dev/null 2>&1 || true
  fi
  rm -f "$DEMO/rede"
  echo "demo desligada"
}

status() {
  echo "rede: $(cat "$DEMO/rede" 2>/dev/null || echo 'nenhuma')"
  for nome in cabine plantadeira simulador trator; do
    if rodando "$nome"; then echo "  $nome: rodando"; elif [[ -f "$DEMO/$nome.log" ]]; then echo "  $nome: parado"; fi
  done
}

testar() {
  for nome in cabine plantadeira simulador trator; do
    rodando "$nome" && erro "a demo está rodando: ./demo.sh parar antes de testar"
  done
  [[ -x build/seeder && -x build/trator ]] || preparar
  azul "pacote Dart: análise e banco..."
  (cd pacotes/agiso && dart_ analyze && dart_ run bin/banco.dart verificar)
  azul "simulador: física..."
  (cd apps/simulador && dart_ --enable-asserts lib/fisica.dart)
  # os testes com a rede CAN numa bolha só deles, sem mexer na vcan0 nem na da demo
  azul "Task Controller com a plantadeira..."
  XDG_RUNTIME_DIR=$(mktemp -d) ./scripts/teste_tc.sh
  azul "TC-GEO e TC-SEC com o trator..."
  XDG_RUNTIME_DIR=$(mktemp -d) ./scripts/teste_geo.sh
  azul "tudo certo"
}

rede() {
  if [[ "$(cat "$DEMO/rede" 2>/dev/null)" == bolha ]]; then
    exec ./scripts/bolha.sh entrar
  elif ip link show vcan0 >/dev/null 2>&1; then
    echo "a vcan0 está neste computador: use candump vcan0 em qualquer terminal"
  else
    erro "a demo não está rodando (./demo.sh iniciar)"
  fi
}

case "${1:-}" in
  preparar) preparar ;;
  iniciar)
    shift
    iniciar "$@"
    ;;
  parar) parar ;;
  status) status ;;
  testar)
    shift
    testar "$@"
    ;;
  rede) rede ;;
  *)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
