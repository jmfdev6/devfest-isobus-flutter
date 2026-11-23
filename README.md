# Cabine ISOBUS em Flutter

[![CI](https://github.com/jmfdev6/devfest-isobus-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/jmfdev6/devfest-isobus-flutter/actions/workflows/ci.yml)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-green.svg)](LICENSE)

Um app **Flutter** que conversa com a rede de um trator (**ISOBUS / J1939 sobre CAN**) usando a biblioteca C++ [AgIsoStack++](https://github.com/Open-Agriculture/AgIsoStack-plus-plus) via **Dart FFI**.

Código da demo ao vivo apresentada no **DevFest Cerrado Nortão 2026**. Você não precisa de trator nem de hardware: tudo roda numa rede CAN **virtual** dentro do seu Linux.

```
 Flutter (app/)  ──►  Dart FFI (dart/)  ──►  ponte C (ponte/)  ──►  AgIsoStack++  ──►  vcan0
   botões, tela          classe Agiso           libagiso.so           pilha ISOBUS       rede CAN virtual
```

O app:

- entra na rede como uma ECU (endereço `0x81`);
- **mostra a rotação do motor** lida do PGN `0xF004` (EEC1);
- funciona como **Terminal Virtual (VT)**: recebe a tela de um implemento e repassa as teclas apertadas;
- funciona como **Task Controller (TC)**: recebe a descrição do implemento (DDOP) e envia valores, como a taxa de aplicação.

---

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Passo a passo](#passo-a-passo)
- [Sem sudo? Use a bolha](#sem-sudo-use-a-bolha)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Problemas comuns](#problemas-comuns)
- [Como contribuir](#como-contribuir)
- [Licença](#licença)

---

## Pré-requisitos

Precisa ser **Linux** (Ubuntu/Debian testados). O suporte a CAN virtual (`vcan`) é do kernel Linux; macOS e Windows não têm. No Windows, use o WSL2 com um kernel que tenha `vcan`.

### 1. Pacotes do sistema

```bash
sudo apt update
sudo apt install -y git build-essential cmake ninja-build pkg-config \
                    libgtk-3-dev can-utils
```

| Pacote | Para quê |
|---|---|
| `build-essential`, `cmake`, `ninja-build` | compilar a parte em C++ |
| `pkg-config`, `libgtk-3-dev` | compilar o app Flutter para Linux |
| `can-utils` | `candump` (ver a rede) e `cansend` (mandar mensagens) |

### 2. Flutter

Versão usada: **Flutter 3.47.9 / Dart 3.13.7**. Siga o [guia oficial para Linux](https://docs.flutter.dev/get-started/install/linux) e confira:

```bash
flutter --version
flutter doctor        # a linha "Linux toolchain" precisa estar com ✓
```

---

## Passo a passo

Abra um terminal e siga na ordem. Cada passo diz o que você deve ver.

### Passo 1: baixar o código

```bash
git clone --recurse-submodules https://github.com/jmfdev6/devfest-isobus-flutter.git
cd devfest-isobus-flutter
```

> O `--recurse-submodules` baixa também a AgIsoStack++ dentro de `third_party/`. Se esqueceu, rode `git submodule update --init`.

### Passo 2: compilar a ponte em C++

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

A primeira vez demora alguns minutos (compila a AgIsoStack++ inteira). No final devem existir:

```bash
ls build/libagiso.so build/teste
```

### Passo 3: criar a rede CAN virtual

```bash
./scripts/setup_vcan.sh
```

Esperado: `OK: vcan0 pronta.` (pede sua senha de sudo; sem sudo, veja [a bolha](#sem-sudo-use-a-bolha)).

### Passo 4: testar a ponte sem Dart

Use **dois terminais**, os dois dentro da pasta do projeto.

**Terminal A:**

```bash
./build/teste vcan0
```

**Terminal B** (em até 10 segundos):

```bash
./scripts/send_rpm.sh 1800
```

No terminal A deve aparecer:

```
endereço 0x81
rotação 1800.0 rpm
```

Se apareceu, a parte em C++ está funcionando.

### Passo 5: testar pelo Dart (terminal de texto)

**Terminal A:**

```bash
cd dart
dart pub get
dart run bin/main.dart vcan0
```

**Terminal B:**

```bash
./scripts/send_rpm.sh 621
```

No terminal A:

```
DART| na rede como 0x81
DART| motor a 621 rpm
```

Comandos que você pode digitar no terminal A:

| Comando | O que faz |
|---|---|
| `1` a `6` | aperta a tecla 1 a 6 do Terminal Virtual |
| `t 200` | o Task Controller manda a taxa de 200 L/ha |
| `s` | sai |

> **Teclas e taxa retornam `-1`?** É o esperado: nenhum implemento (pulverizador) está conectado à rede, então não há para quem mandar. A rotação funciona sozinha.

### Passo 6: rodar o app Flutter

```bash
cd app
flutter pub get
flutter run -d linux
```

Abre uma janela "Cabine ISOBUS". Em outro terminal, mande rotações e veja o número mudar:

```bash
./scripts/send_rpm.sh 900
./scripts/send_rpm.sh 2100
```

### Passo 7 (opcional): ver a rede por dentro

Em mais um terminal:

```bash
candump vcan0
```

Cada linha é uma mensagem CAN. Você verá o app anunciando o próprio endereço (`18EEFF81`) e as rotações que você manda (`0CF00401`).

### Limpar

```bash
./scripts/teardown_vcan.sh
```

---

## Sem sudo? Use a bolha

Sem acesso de administrador, o script `bolha.sh` cria uma rede isolada só sua (um *network namespace*) com a `vcan0` dentro. Todo programa que fala com a rede precisa ser aberto com `bolha.sh entrar`:

```bash
./scripts/bolha.sh criar                                   # uma vez
./scripts/bolha.sh entrar ./build/teste vcan0              # terminal A
./scripts/bolha.sh entrar ./scripts/send_rpm.sh 1800       # terminal B
./scripts/bolha.sh entrar candump vcan0                    # terminal C (opcional)
./scripts/bolha.sh destruir                                # no final
```

---

## Estrutura do projeto

```
.
├── CMakeLists.txt        # compila a ponte (libagiso.so) e o teste em C
├── ponte/                # C++: o único lugar que conhece a AgIsoStack++
│   ├── agiso.h           #   o contrato C que o Dart enxerga (leia este primeiro!)
│   ├── agiso.cpp         #   liga na rede CAN, lê a rotação, avisa o Dart
│   ├── servicos.hpp      #   liga/desliga VT e TC
│   ├── vt.cpp            #   Terminal Virtual mínimo
│   └── tc.cpp            #   Task Controller mínimo
├── teste/teste.c         # usa a ponte em C puro, sem Dart
├── dart/                 # pacote Dart: a classe Agiso esconde o FFI
│   ├── lib/agiso.dart
│   └── bin/main.dart     #   cabine em modo texto
├── app/                  # app Flutter (Linux)
│   └── lib/main.dart
├── scripts/              # criar/remover vcan, mandar rpm, bolha sem sudo
└── third_party/          # AgIsoStack++ (submódulo git)
```

**Ordem sugerida de leitura:** `ponte/agiso.h` → `teste/teste.c` → `ponte/agiso.cpp` → `dart/lib/agiso.dart` → `app/lib/main.dart` → `ponte/vt.cpp` e `ponte/tc.cpp`.

Os comentários `// [passo 7]` ... `// [/passo 7]` marcam trechos adicionados em cada etapa da palestra. Podem ser ignorados: o código funciona com tudo junto.

---

## Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| `não consegui abrir vcan0` / `agiso_start falhou: -1` | A `vcan0` não existe. Rode `./scripts/setup_vcan.sh` (ou use a bolha). |
| `modprobe: FATAL: Module vcan not found` | Kernel sem `vcan` (comum em WSL e containers). Instale `linux-modules-extra-$(uname -r)` ou use outro kernel. |
| `Failed to load dynamic library '../build/libagiso.so'` | Você não compilou (passo 2) ou rodou de outra pasta. O Dart roda de dentro de `dart/` e o Flutter de dentro de `app/`. |
| `third_party/AgIsoStack-plus-plus` vazio / erro no CMake | Faltou o submódulo: `git submodule update --init`. |
| `cansend: command not found` | `sudo apt install can-utils`. |
| `flutter run` reclama de GTK / CMake | `sudo apt install libgtk-3-dev ninja-build pkg-config` e confira `flutter doctor`. |
| Rotação não aparece | O `send_rpm.sh` e o app precisam estar na mesma rede: os dois fora, ou os dois dentro da bolha. |

---

## Como contribuir

Contribuições são bem-vindas, principalmente de quem está começando! Leia o [CONTRIBUTING.md](CONTRIBUTING.md) e o [Código de Conduta](CODE_OF_CONDUCT.md).

## Licença

[MIT](LICENSE). A AgIsoStack++ também é MIT, © The Open-Agriculture Developers.

## Créditos

- [Open-Agriculture / AgIsoStack++](https://github.com/Open-Agriculture/AgIsoStack-plus-plus), a pilha ISOBUS que faz o trabalho pesado.
- GDG / DevFest Cerrado Nortão.
