# Problemas comuns

## Instalação e compilação

| Sintoma | Causa e solução |
|---|---|
| `falta o cmake` / `git` / `pkg-config` | `sudo apt install cmake git pkg-config` |
| `flutter: command not found` ou versão errada | instale o mise e rode `mise install` na pasta do projeto; o `mise.toml` fixa o 3.47.9 |
| `third_party/AgIsoStack-plus-plus` vazio / erro no CMake | `git submodule update --init --recursive` |
| `flutter build` reclama de GTK / CMake | `sudo apt install libgtk-3-dev ninja-build pkg-config` e confira `flutter doctor` |
| `não achei a libagiso.so` | `./demo.sh preparar` (ou `cmake --build build`). Os apps procuram `build/libagiso.so` subindo da pasta atual e da do executável; para outro lugar, `AGISO_LIB=/caminho/libagiso.so` |

## Rede CAN

| Sintoma | Causa e solução |
|---|---|
| `agiso_start falhou: -1` / `não consegui abrir vcan0` | a `vcan0` não existe **nesta rede**: `./scripts/setup_vcan.sh`, ou rode o programa dentro da bolha |
| `modprobe: FATAL: Module vcan not found` | kernel sem `vcan`: `sudo apt install linux-modules-extra-$(uname -r)` |
| bolha: "uid_map: Operação não permitida" / AppArmor | Ubuntu 24.04+: `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`, ou use `setup_vcan.sh` |
| WSL2 sem `vcan` | o kernel padrão do WSL não traz o módulo; é preciso compilar um kernel com `CONFIG_CAN_VCAN` e apontar o `.wslconfig` para ele |
| a rotação não aparece | o `send_rpm.sh` e o app precisam estar na mesma rede: os dois fora ou os dois dentro da bolha |
| `cansend: command not found` | `sudo apt install can-utils` |

## Plantadeira, VT e TC

| Sintoma | Causa e solução |
|---|---|
| `Failed to load object pool from BasePool.iop` | rode o `./seeder` de dentro de `build/` |
| alarme "Machine Speed Not Detected" | falta velocidade: `./scripts/send_velocidade.sh 8`, o trator ou o simulador na mesma rede |
| tela do VT dessincronizada (switches não mudam, cores das seções erradas, velocidade parada) | a cabine reiniciou com a plantadeira rodando. **Reinicie a plantadeira sempre que reiniciar a cabine** (inclusive depois do `teste_tc.sh`). `./demo.sh iniciar` já faz isso. |
| switches e funis com estados diferentes | recompile (`cmake --build build`) e reinicie o `./seeder`: a cópia em `nativo/plantadeira/` faz o switch acompanhar a seção |
| `a plantadeira não conectou ao TC` (demo.sh) | veja `.demo/cabine.log` e `.demo/plantadeira.log`; normalmente basta `./demo.sh parar && ./demo.sh iniciar` |
| as seções não ligam | tudo já foi plantado: reinicie a demo para replantar |

## Simulador e 3D

| Sintoma | Causa e solução |
|---|---|
| "3D indisponível" ou simulador em branco | o Flutter GPU não ligou: confira `fl_dart_project_set_enable_flutter_gpu` no runner e o Flutter ≥ 3.47.1; teste com `flutter run -d linux --enable-flutter-gpu` |
| o trator não anda | clique na janela do simulador (foco do teclado) e acelere: W, ou E (acelerador de mão) |
| "GPS: aguardando o trator" (`--ouvinte`) | o `./build/trator` não está rodando, ou está em outra rede |
| dois tratores (o 3D pula, o GPS salta) | simulador dirigível e `./build/trator` juntos: use um só |
| o volante USB não responde | confira `ls -l /dev/input/js0` (permissão de leitura) e os números em `jstest`; ajuste o topo de `controle_usb.dart` |

## Banco

| Sintoma | Causa e solução |
|---|---|
| a cabine não trocou para o talhão ativo | ela lê o talhão **ativo** a cada 2 s; confira com `dart run bin/banco.dart` (o ativo tem `*`). Com `--talhao-demo` (ou no modo texto), a cabine usa sempre o talhão da demo. |
| começar do zero | apps fechados: `rm -f ~/.local/share/cabine-isobus/agro.sqlite*` |
| `database is locked` | outro processo segurou a escrita mais de 5 s (`busy_timeout`); feche apps duplicados |
