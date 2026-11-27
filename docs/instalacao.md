# Instalação

## Requisitos

| | |
|---|---|
| Sistema | Linux com SocketCAN e o módulo `vcan` (Ubuntu 22.04+ e Debian testados). WSL2 funciona com um kernel que tenha `vcan`. macOS não tem SocketCAN. |
| Compilador | GCC ou Clang com C++17, CMake ≥ 3.16; Ninja é opcional (mais rápido) |
| Flutter | **3.47.9** (Dart 3.13.7), fixado no [`mise.toml`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/mise.toml). O Flutter GPU exige 3.47.1 ou mais novo. |
| GTK | `libgtk-3-dev` e `pkg-config` (o *embedder* Linux do Flutter) |
| Opcional | `can-utils` (`candump`, `cansend`), um volante ou gamepad em `/dev/input/js0` |

```bash
sudo apt update
sudo apt install -y git curl build-essential cmake ninja-build pkg-config libgtk-3-dev can-utils
```

### Flutter com o mise

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc   # e abra um terminal novo
```

O `./demo.sh preparar` roda `mise trust` e `mise install` sozinho. Sem o mise, instale o Flutter 3.47.9 pelo [guia oficial](https://docs.flutter.dev/get-started/install/linux) e confira `flutter doctor` (a linha *Linux toolchain* precisa estar ✓). O `demo.sh` usa o `mise exec` quando o mise existe e o `flutter` do `PATH` quando não.

## Código

```bash
git clone --recurse-submodules https://github.com/jmfdev6/devfest-isobus-flutter.git
cd devfest-isobus-flutter
```

A AgIsoStack++ é um submódulo em `third_party/AgIsoStack-plus-plus`. Esqueceu o `--recurse-submodules`? O `preparar` roda `git submodule update --init --recursive`.

## Compilar

```bash
./demo.sh preparar
```

O que ele faz, em ordem (veja [`demo.sh`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/demo.sh)):

1. confere Linux, `cmake`, `git`, `pkg-config` e o Flutter (ou o mise);
2. `mise trust` + `mise install` (Flutter do `mise.toml`);
3. baixa o submódulo, se faltar;
4. `cmake -S . -B build [-G Ninja] -DCMAKE_BUILD_TYPE=Release` e `cmake --build build`, que gera `build/libagiso.so`, `build/trator`, `build/seeder` e `build/teste`;
5. `dart pub get` em `pacotes/agiso`;
6. `flutter pub get` e `flutter build linux --release` em `apps/cabine` e `apps/simulador`.

Os executáveis ficam em `apps/<app>/build/linux/x64/release/bundle/<app>`.

??? note "Compilar à mão, sem o demo.sh"
    ```bash
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    (cd pacotes/agiso && dart pub get)
    (cd apps/cabine && flutter pub get && flutter build linux --release)
    (cd apps/simulador && flutter pub get && flutter build linux --release)
    ```
    A primeira compilação da AgIsoStack++ leva alguns minutos.

## A rede CAN

Há dois jeitos de ter uma `vcan0`:

=== "Com sudo (vcan0 do sistema)"

    ```bash
    ./scripts/setup_vcan.sh       # modprobe vcan; ip link add vcan0 type vcan; ip link set up vcan0
    ./scripts/teardown_vcan.sh    # no fim
    ```
    Todos os programas e terminais enxergam a `vcan0`. O `demo.sh` usa esta, se ela existir.

=== "Sem sudo (a bolha)"

    ```bash
    ./scripts/bolha.sh criar                         # um network namespace com a vcan0 dentro
    ./scripts/bolha.sh entrar candump vcan0          # cada programa entra na bolha
    ./scripts/bolha.sh destruir
    ```
    A bolha usa `unshare -rn` (namespaces de usuário e de rede) e `nsenter --preserve-credentials`: você continua sendo você (mesmo `$HOME`, mesmo display), mas numa rede só sua. É o padrão do `demo.sh` quando não há `vcan0`.

!!! warning "Ubuntu 24.04+"
    O AppArmor bloqueia namespaces de usuário sem privilégio (`kernel.apparmor_restrict_unprivileged_userns=1`). O `bolha.sh` detecta e sugere `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0`, ou o caminho com sudo.

## Conferir

```bash
./demo.sh testar
```

Termina com `tudo certo`. Detalhes em [demo.sh e testes](demo.md).
