#!/usr/bin/env bash
# Uma "bolha" de rede com vcan0, SEM sudo (namespace de rede do Linux).
#
#   ./scripts/bolha.sh criar            # cria a bolha com a vcan0 dentro
#   ./scripts/bolha.sh entrar           # abre um shell dentro da bolha
#   ./scripts/bolha.sh entrar candump vcan0    # roda um comando dentro dela
#   ./scripts/bolha.sh destruir         # apaga a bolha (e a vcan0 dela)
#
# Abra quantos terminais quiser com "entrar": todos enxergam a mesma vcan0.
# Fora da bolha, a vcan0 não existe. Precisa do módulo vcan no kernel.
set -euo pipefail

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/agiso-bolha.pid"

pid_da_bolha() {
  [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null && cat "$PIDFILE"
}

case "${1:-}" in
  criar)
    if pid_da_bolha >/dev/null; then
      echo "A bolha já existe (PID $(cat "$PIDFILE"))."
      exit 0
    fi
    # unshare -r: vira "root" só dentro da bolha; -n: rede própria e vazia
    # sem herdar o terminal: senão quem lê a saída deste script (um pipe) espera a bolha acabar
    unshare -rn sh -c 'ip link add dev vcan0 type vcan && ip link set up vcan0 && exec sleep infinity' \
      >/dev/null 2>&1 </dev/null &
    echo $! >"$PIDFILE"
    sleep 0.3
    if ! pid_da_bolha >/dev/null; then
      echo "Não consegui criar a bolha." >&2
      # Ubuntu 24.04+ bloqueia namespaces de usuário sem perfil AppArmor:
      # o unshare falha com "uid_map: Operação não permitida".
      if [[ "$(sysctl -n kernel.apparmor_restrict_unprivileged_userns 2>/dev/null)" == "1" ]]; then
        echo "Causa: o AppArmor desta máquina proíbe namespaces de usuário sem privilégio." >&2
        echo "Libere com:  sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0" >&2
        echo "Ou use o caminho com sudo:  ./scripts/setup_vcan.sh" >&2
      elif ! modinfo vcan >/dev/null 2>&1; then
        echo "Causa: o kernel não tem o módulo vcan (modinfo vcan falhou)." >&2
      else
        echo "Use o caminho com sudo:  ./scripts/setup_vcan.sh" >&2
      fi
      exit 1
    fi
    echo "Bolha criada (PID $(cat "$PIDFILE")). Entre com: $0 entrar"
    ;;
  entrar)
    PID=$(pid_da_bolha) || { echo "Crie a bolha antes: $0 criar" >&2; exit 1; }
    shift
    if [[ $# -eq 0 ]]; then
      set -- "${SHELL:-bash}"
    fi
    # --preserve-credentials: continua sendo você (arquivos, $HOME, display)
    exec nsenter --preserve-credentials -U -n -t "$PID" "$@"
    ;;
  destruir)
    if PID=$(pid_da_bolha); then
      # Encerra TUDO que está dentro da bolha (os programas abertos com "entrar"
      # mantêm a bolha viva mesmo sem o processo que a criou).
      NS=$(readlink "/proc/$PID/ns/net")
      for proc in /proc/[0-9]*; do
        if [[ "$(readlink "$proc/ns/net" 2>/dev/null)" == "$NS" ]]; then
          kill "${proc#/proc/}" 2>/dev/null || true
        fi
      done
      echo "Bolha destruída (e os programas que estavam nela)."
    else
      echo "Não há bolha."
    fi
    rm -f "$PIDFILE"
    ;;
  *)
    echo "uso: $0 criar | entrar [comando...] | destruir" >&2
    exit 2
    ;;
esac
