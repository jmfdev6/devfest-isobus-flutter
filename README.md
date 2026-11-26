# Cabine ISOBUS em Flutter

[![CI](https://github.com/jmfdev6/devfest-isobus-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/jmfdev6/devfest-isobus-flutter/actions/workflows/ci.yml)
[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-green.svg)](LICENSE)

Um app **Flutter** que conversa com a rede de um trator (**ISOBUS / J1939 sobre CAN**) usando a biblioteca C++ [AgIsoStack++](https://github.com/Open-Agriculture/AgIsoStack-plus-plus) via **Dart FFI**.

Código da demo ao vivo apresentada no **DevFest Cerrado Nortão 2026**. Você não precisa de trator nem de hardware: tudo roda numa rede CAN **virtual** dentro do seu Linux.

```
 Flutter (apps/)  ──►  Dart FFI (pacotes/agiso)  ──►  ponte C (nativo/ponte)  ──►  AgIsoStack++  ──►  vcan0
   botões, tela          classe Agiso           libagiso.so           pilha ISOBUS       rede CAN virtual
```

O app:

- entra na rede como uma ECU (endereço `0x81`);
- **mostra a rotação do motor** lida do PGN `0xF004` (EEC1);
- funciona como **Terminal Virtual (VT)**: recebe a tela (object pool) de um implemento e a **desenha com cores, figuras e medidores**; os toques nas soft keys e nos botões vão para o implemento;
- funciona como **Task Controller (TC)**: recebe a descrição do implemento (DDOP) e envia valores, como a taxa de aplicação;
- tem um **TC automático**: com a posição do GPS (**NMEA 2000**), escolhe a taxa pelo mapa de prescrição (**TC-GEO**) e corta as seções fora do talhão ou sobre o que já foi plantado (**TC-SEC**);
- mostra ao lado do VT a **plantadeira em 3D** ([flutter_scene](https://pub.dev/packages/flutter_scene)) e o **mapa do talhão**.

E vem com um **simulador 3D** (`apps/simulador/`) em que **você dirige** o trator (teclado, volante na tela ou volante USB) ou deixa o **piloto automático** cobrir o talhão: ele é o trator na rede e manda o GPS, a velocidade e a rotação para a cabine. Os talhões vêm de **shapefile** (graus ou UTM) e cada trabalho guarda o **mapa de aplicação** num banco local.

---

## Início rápido

Com os [pré-requisitos](#pré-requisitos) instalados (Linux, pacotes do sistema e Flutter):

```bash
git clone --recurse-submodules https://github.com/jmfdev6/devfest-isobus-flutter.git
cd devfest-isobus-flutter
./demo.sh preparar     # compila tudo (a primeira vez leva alguns minutos)
./demo.sh iniciar      # abre a cabine, a plantadeira e o simulador, na ordem certa
```

No simulador: **W** acelera, **A/D** viram o volante, **P** liga o piloto automático, **C** troca a câmera, **M** mostra o mapa no chão. Para desligar: `./demo.sh parar`.

| Comando | O que faz |
|---|---|
| `./demo.sh preparar` | baixa o submódulo e os pacotes, compila o C++ e os dois apps |
| `./demo.sh iniciar` | rede CAN (a `vcan0`, ou uma bolha sem sudo) + cabine (com o TC automático) + plantadeira + simulador |
| `./demo.sh iniciar --automatico` | sem motorista: o trator anda sozinho e o simulador só assiste |
| `./demo.sh iniciar --talhao exemplos/talhao_sinop.shp` | já abre um talhão de shapefile (veja o [Passo 11](#passo-11-shapefile-piloto-automático-e-trabalhos-guardados-drift)) |
| `./demo.sh status` / `./demo.sh parar` | o que está rodando / desliga tudo |
| `./demo.sh testar` | todas as verificações e os testes com a rede CAN (`--rapido` pula o do piloto, de 2 min) |
| `./demo.sh rede` | um terminal dentro da rede da demo (para o `candump vcan0`) |

Os registros de cada programa ficam em `.demo/`. O resto deste README explica tudo **passo a passo**, como na palestra.

---

## Sumário

- [Início rápido](#início-rápido)
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

Versão usada: **Flutter 3.47.9 / Dart 3.13.7**, fixada no [`mise.toml`](mise.toml). Com o [mise](https://mise.jdx.dev), basta entrar na pasta do projeto:

```bash
mise install          # baixa o Flutter 3.47.9 (só na primeira vez)
flutter --version     # dentro da pasta do projeto, já é o 3.47.9
flutter doctor        # a linha "Linux toolchain" precisa estar com ✓
```

Sem mise, siga o [guia oficial para Linux](https://docs.flutter.dev/get-started/install/linux) e instale a mesma versão.

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
ls build/libagiso.so build/teste build/seeder
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
cd pacotes/agiso
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
| `1` a `6` | aperta a 1ª a 6ª soft key da tela atual do Terminal Virtual |
| `b 6000` | aperta um botão da tela pelo ID do objeto (6000 a 6005 = switches das seções 1 a 6) |
| `t 3 11 20000` | o Task Controller manda um valor ao implemento: elemento 3, DDI 11, valor 20000 |
| `s` | sai |

> **Teclas e `t` retornam `-1`?** Ainda não há implemento na rede, então não há para quem mandar. A rotação funciona sozinha. O próximo passo liga um.

### Passo 5b: ligar um implemento (a plantadeira)

O implemento da demo é a plantadeira de exemplo da AgIsoStack++ (`seeder_example`). Ela já traz o **cliente de VT** (manda a tela) e o **cliente de TC** (manda o DDOP e aceita valores); a cabine faz o papel dos servidores. Em mais dois terminais:

```bash
cd build && ./seeder --interface vcan0          # terminal B (precisa rodar de dentro de build/)
./scripts/send_velocidade.sh 8                  # terminal C: o "trator" andando a 8 km/h
```

Na cabine aparece:

```
VT  | tela do implemento 0x80 ACEITA
VT  | 11000="Seeder Example"  ...  12009="8.0"
TC  | DDOP recebido de 0x80: 1428 bytes
TC  | DET 3 Product
TC  |     DPD  DDI 11  Target Rate
TC  | assinei 17 valores
TC  | Target Rate (3/11) = 12000
TC  | Bin Level (3/78) = 150000
```

O TC lista o DDOP (elementos `DET` e dados `DPD`) e, a cada 2 segundos, mostra os valores que mudaram, com o nome que o implemento deu a cada um. Mande uma taxa nova e veja ela voltar:

```
t 3 11 20000
TC  | Target Rate (3/11) = 20000
```

Sem a velocidade, a plantadeira mostra o alarme "Machine Speed Not Detected". O `send_velocidade.sh` também anuncia o endereço `0x01` na rede: a AgIsoStack++ ignora velocidade de quem não se apresentou.

> O TC demora alguns segundos a mais que o VT para conectar: a norma manda o implemento esperar antes de falar com o TC.

### Passo 6: rodar o app Flutter

```bash
cd apps/cabine
flutter pub get
flutter run -d linux
```

Abre uma janela "Cabine ISOBUS". Em outro terminal, mande rotações e veja o número mudar no canto:

```bash
./scripts/send_rpm.sh 900
./scripts/send_rpm.sh 2100
```

Com a plantadeira do passo 5b na rede, a janela mostra a tela que ela mandou, como num terminal de cabine: cores, figuras, medidor e soft keys à direita. Toque nas teclas e nos botões da tela (as seções ligam e desligam). O botão "TC: 20 mil sementes/ha" manda a taxa pelo Task Controller.

### Passo 7 (opcional): ver a rede por dentro

Em mais um terminal:

```bash
candump vcan0
```

Cada linha é uma mensagem CAN. Você verá o app anunciando o próprio endereço (`18EEFF81`) e as rotações que você manda (`0CF00401`).

### Passo 8: teste automático do Task Controller

```bash
./scripts/teste_tc.sh
```

Sobe a cabine em modo texto e a plantadeira (na `vcan0`, ou numa bolha se ela não existir) e confere: o TC recebeu o DDOP, assinou os valores, recebe valores do implemento e consegue mudar a taxa alvo. Termina com `PASSOU` (código 0) ou `FALHOU` e o log da cabine. Leva uns 20 segundos.

### Passo 9: o trator com GPS (NMEA 2000) e o TC automático (TC-GEO e TC-SEC)

O `./build/trator` (em [`nativo/trator/trator.cpp`](nativo/trator/trator.cpp)) é o trator da demo: entra na rede com a AgIsoStack++, anda num talhão de 60 × 120 m em Sinop (MT), em passadas norte-sul com meia-volta na cabeceira, e manda 10 vezes por segundo:

| Mensagem | PGN | Quem usa |
|---|---|---|
| Posição rápida (NMEA 2000) | 129025 | TC automático e simulador 3D |
| Posição GNSS completa (NMEA 2000) | 129029 | (para quem quiser ver no `candump`) |
| Rumo e velocidade sobre o solo (NMEA 2000) | 129026 | TC automático e simulador 3D |
| Proa (NMEA 2000) | 127250 | (idem) |
| Velocidade de solo (ISOBUS) | `0xFE49` | a plantadeira (substitui o `send_velocidade.sh`) |

```bash
./build/trator vcan0 8          # vcan0 a 8 km/h (Ctrl+C para parar)
```

Na cabine, o **TC automático** (chip "TC automático (GEO + SEC)" no app, ou `g` no modo texto) faz, a cada posição:

- **TC-GEO:** acha em que faixa do mapa de prescrição a barra está (12, 20 e 16 mil sementes/ha, de sul a norte) e manda a taxa (DDI 11);
- **TC-SEC:** liga cada seção só se ela estiver dentro do talhão e fora do que já foi plantado. As passadas ficam a 7,6 m e a barra tem 9,1 m: na volta, a seção que passaria sobre o plantado é cortada. Na cabeceira, as seções cortam uma a uma ao sair do talhão.

O "limpar mapa" (ou `l`) esquece o que foi plantado. Teste automático (sobe tudo com o trator a 30 km/h):

```bash
./scripts/teste_geo.sh          # PASSOU em ~1 minuto
```

A plantadeira (cópia do simulador em [`nativo/plantadeira/`](nativo/plantadeira/)) também gasta semente de verdade: o depósito desce com as seções ligadas, pela área plantada e pela taxa.

### Passo 10: o simulador 3D — você dirige o trator

O `apps/simulador/` é um segundo app Flutter, desenhado com o [flutter_scene](https://pub.dev/packages/flutter_scene): **você dirige** o trator que reboca a plantadeira pelo talhão. Ele **é o trator na rede CAN**: a cada 100 ms manda o GPS NMEA 2000, a velocidade de solo (a plantadeira dosa por ela) e a rotação do motor (a cabine mostra no canto). As seções vêm do que a plantadeira informa ao TC da cabine; o que foi plantado escurece a terra atrás dela.

```bash
cd apps/simulador
flutter pub get
flutter run -d linux                    # você dirige (não rode junto com o ./build/trator)
flutter run -d linux -a --ouvinte       # só acompanha o ./build/trator automático
```

| Comando | Teclado | Na tela | Volante/gamepad USB |
|---|---|---|---|
| volante | A/D ou ←/→ (solto, volta ao centro) | arraste o volante girando | eixo 0 |
| pedal do acelerador | W ou ↑ | — | gatilho direito (eixo 5) |
| acelerador de mão (fica onde você deixou) | E põe, Q tira | a alavanca "acelerador" | — |
| freio | S, ↓ ou espaço | — | gatilho esquerdo (eixo 2) |
| frente/ré (com o trator parado) | R | botão F → R | botão A |
| câmera: cabine, atrás, de cima | C | botões no canto | botão Y |
| piloto automático (engata/solta) | P | botão "piloto" | — |
| chão plantado: terra, taxa, prescrito × aplicado | M | botões no canto | — |

O controle USB é lido direto do `/dev/input/js0` (a API de joystick do Linux). Para um volante com pedais, como o Logitech G29, troque o mapa no topo de [`apps/simulador/lib/controle_usb.dart`](apps/simulador/lib/controle_usb.dart).

O que deixa o simulador realista:

- **física** ([`apps/simulador/lib/fisica.dart`](apps/simulador/lib/fisica.dart)): motor com rotação entre a lenta e 2200 rpm, aceleração com inércia, resistência do solo, freio, ré limitada a 7 km/h, e direção pelo modelo de bicicleta (entre-eixos de 2,3 m, 38° nas rodas, 1,5 volta de volante para cada lado). Autoteste: `dart --enable-asserts lib/fisica.dart`;
- **plantadeira rebocada**: gira em torno do pino do engate, cortando por dentro nas curvas. O TC usa o mesmo modelo (`Engate`, em [`pacotes/agiso/lib/geo.dart`](pacotes/agiso/lib/geo.dart)), então o corte de seções bate com o que você vê;
- rodas dianteiras esterçando, árvores em volta, neblina no horizonte, céu com sol e sombras.

Os modelos (`.glb`) ficam em [`pacotes/cena/assets/`](pacotes/cena/assets/), num pacote usado pelos dois apps. O flutter_scene desenha com o **Flutter GPU**, ligado no runner Linux de cada app (`fl_dart_project_set_enable_flutter_gpu` em `linux/runner/my_application.cc`; precisa do Flutter 3.47.1 ou mais novo).

### Passo 11: shapefile, piloto automático e trabalhos guardados (drift)

**Talhão de shapefile.** O simulador importa shapefiles de polígonos pelo botão **importar shapefile**, que abre uma janela com:

- o **contorno** do talhão (obrigatório) e, se quiser, o **mapa de prescrição** num arquivo separado, como as empresas de agricultura de precisão entregam. As zonas da prescrição podem passar da divisa: o contorno corta;
- o **campo da taxa** (a lista dos campos numéricos do `.dbf`, com o mais provável já escolhido: `TAXA`, `RATE`, `DOSE`...) e a **unidade** (sementes/ha, mil sementes/ha, sementes/m²; adivinhada pelos valores);
- a taxa padrão (onde nenhuma zona cobre) e o nome do talhão.

As coordenadas podem estar em **graus** (WGS84, SIRGAS 2000) ou em **UTM** (SIRGAS 2000 / UTM 21S e qualquer outra Transversa de Mercator): o leitor lê o `.prj` e converte para graus (fórmulas de Snyder, precisão de milímetros). Na linha de comando, para abrir a apresentação já com o talhão:

```bash
cd apps/simulador
flutter run -d linux -a --talhao -a ../../exemplos/talhao_sinop.shp            # zonas e taxa no mesmo arquivo
flutter run -d linux -a --talhao -a ../../exemplos/contorno_sinop_utm.shp \
  -a --prescricao -a ../../exemplos/prescricao_sinop.shp -a --campo -a DOSE_MIL -a --fator -a 1000
```

Os exemplos em [`exemplos/`](exemplos/) (gerados por `python3 exemplos/gerar_talhao.py`, que também tem a Transversa de Mercator direta, conferida no exemplo numérico de Snyder): o talhão em graus e em UTM 21S, o contorno sozinho em UTM, e uma prescrição em faixas maiores que o talhão com a taxa em mil sementes/ha. Para conferir o leitor, a UTM, a prescrição separada e a exportação contra esses arquivos:

```bash
cd pacotes/agiso && dart run bin/shapefile.dart                       # confere tudo (ok/FALHOU)
cd pacotes/agiso && dart run bin/shapefile.dart contorno.shp prescricao.shp CAMPO 1000   # um shapefile seu
```

**Piloto automático elétrico, com curvas automáticas** ([`pacotes/agiso/lib/rota.dart`](pacotes/agiso/lib/rota.dart) planeja, [`apps/simulador/lib/piloto.dart`](apps/simulador/lib/piloto.dart) guia). O piloto segue uma **rota que cobre o talhão sem sair dele**:

1. uma **cabeceira** em volta do talhão (2 passadas de largura), onde se manobra;
2. as **passadas** paralelas à AB (a da maior borda reta, ou a sua: **marcar A**, ande, **marcar B**), cortadas pelo talhão menos a cabeceira; cada uma vai até a plantadeira, que vem atrás, chegar à cabeceira;
3. uma **curva em U automática** entre passadas vizinhas, com raio de meia passada (4,6 m; o trator vira em 2,9 m), conferida para ficar dentro do contorno (se não couber, a passada encurta);
4. no fim, as **duas voltas de cabeceira**, por dentro da divisa e com os cantos arredondados (raio de 6 m: canto vivo o trator não faz), deixando 30 cm de folga para a borda da plantadeira.

Com o trator perto da rota (o caminho no chão) e alinhado com ela, **P** engata; você só cuida do acelerador. O motor gira o volante (até 300°/s) com *pure pursuit* pelo eixo traseiro, **freia sozinho para 6 km/h antes das curvas**, e a barra de luz no topo mostra o trecho ("passada 3 de 17", "curva", "cabeceira 1 de 2") e o desvio. No chão, o caminho feito fica verde e os próximos 40 m, laranja. As seções e a taxa continuam com o TC da cabine (TC-SEC corta onde já foi plantado; TC-GEO troca a taxa pelas zonas do mapa). Como os de verdade, o piloto **solta** se você mexer no volante ou der ré.

O autoteste dirige a rota inteira com a física e a plantadeira rebocada, nos dois talhões, e confere que nem o trator nem as pontas da barra saem do contorno: `cd apps/simulador && dart --enable-asserts lib/piloto.dart`

| Talhão | Passadas | Percurso | Fora do talhão | Desvio na reta | Curvas | Cobertura |
|---|---|---|---|---|---|---|
| demo 60 × 120 m | 3 | 0,9 km | 0 | 2,9 cm | ≤ 6,2 km/h | 96,8% |
| `talhao_sinop.shp` | 17 | 5,6 km | 0 | 3,0 cm | ≤ 6,2 km/h | 99,4% |

(O que falta para 100% são os cantos arredondados e a folga de 30 cm junto à divisa.)

**Trabalhos e mapas de aplicação** ([`pacotes/agiso/lib/banco.dart`](pacotes/agiso/lib/banco.dart), com [drift](https://pub.dev/packages/drift)). Tudo fica num SQLite local, `~/.local/share/cabine-isobus/agro.sqlite` (o SQLite vem embutido no pacote `sqlite3`; nada a instalar):

- o **talhão** importado (contorno e zonas, em graus) vira o **ativo**, e a **cabine** o carrega sozinha (pergunta ao banco a cada 2 s): o TC-GEO dela passa a usar o mapa de prescrição do shapefile;
- cada **trabalho** guarda início, fim, hectares, sementes, distância e o **mapa de aplicação**: uma grade de 0,5 m com a taxa que a plantadeira informou ter aplicado em cada célula, e onde ela **passou duas vezes** (sobreposição: plantar de novo a mesma célula mais de 3 s depois). Salva sozinho a cada 10 s; ao reabrir, o simulador **continua** o trabalho aberto;
- **novo trabalho** encerra o atual e começa um mapa em branco; **trabalhos** lista o histórico, e cada um tem **ver** e **continuar**.

**Ver um trabalho** abre o mapa em três modos, com legenda, e o relatório ([`pacotes/agiso/lib/relatorio.dart`](pacotes/agiso/lib/relatorio.dart)):

| Modo | O que mostra |
|---|---|
| aplicado | a taxa que caiu em cada célula (amarelo = pouca semente, verde = muita) e a sobreposição (roxo) |
| prescrito × aplicado | cada célula comparada com a prescrição: **na taxa** (±5%), **abaixo**, **acima**, **sobreposta**, **não aplicada** |
| prescrição | o mapa de prescrição dentro do talhão |

O **relatório** soma, por taxa prescrita: área, área aplicada (e quanto dela na taxa, abaixo, acima e sobreposta) e sementes previstas × aplicadas. **Exportar shapefile** grava o mapa de aplicação em graus (WGS84), para abrir no QGIS ou num software agrícola: um polígono por trecho de linha da grade com os campos `TAXA_APL`, `TAXA_PRE`, `DIF_PCT`, `SOBREP` e `AREA_M2`.

A cabine mostra o mesmo mapa ao vivo (com os três modos, a legenda e o botão **relatório**). No simulador, o chão plantado também pode mostrar a taxa (mapa de calor) ou o prescrito × aplicado: tecla **M** ou os botões **terra / taxa / prescrito × aplicado**.

```bash
cd pacotes/agiso && dart run bin/banco.dart             # lista talhões e trabalhos guardados
cd pacotes/agiso && dart run bin/banco.dart verificar   # ida e volta num banco temporário
```

O código gerado do drift (`banco.g.dart`) vai no repositório; depois de mudar as tabelas: `cd pacotes/agiso && dart run build_runner build` (e uma migração em `Banco.migration`: a v2 acrescentou a sobreposição sem perder o que já estava guardado).

**Desempenho do 3D.** O chão do talhão é **um plano com uma textura** do tamanho do mapa de aplicação: plantar é pintar pixels, e a textura sobe para a GPU no máximo a cada 150 ms (antes, cada célula plantada era uma peça 3D, e cada peça nova reenviava todas: o custo crescia com o quadrado da área). A cor de base do chão (terra com manchas, levemente tingida pela zona de prescrição; carreador em volta) é calculada num *isolate*, sem travar a tela.

### Ordem para a apresentação

O `./demo.sh iniciar` já sobe tudo na ordem certa. A ordem importa: a plantadeira guarda o último valor que mandou para cada objeto da tela, então **a cabine sobe antes dela** (e, se a cabine reiniciar, a plantadeira também). À mão, é isto (com a bolha, abra cada comando com `./scripts/bolha.sh entrar`):

```bash
./scripts/setup_vcan.sh                                  # 1. a rede (ou: ./scripts/bolha.sh criar)
cd apps/cabine && flutter run -d linux -a --tc-auto      # 2. a cabine, com o TC automático ligado
cd build && ./seeder --interface vcan0                   # 3. a plantadeira (espere o "TC | assinei")
cd apps/simulador && flutter run -d linux                # 4. o trator: você dirige
```

Sem ninguém para dirigir, troque o passo 4 por `./build/trator vcan0 8` (anda sozinho no talhão da demo; abra a cabine com `-a --talhao-demo`) e, para ver em 3D, `cd apps/simulador && flutter run -d linux -a --ouvinte`. É o que o `./demo.sh iniciar --automatico` faz.

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
├── demo.sh               # prepara, liga, desliga e testa a demo inteira
├── CMakeLists.txt        # compila o C++: a ponte (libagiso.so), o trator, a plantadeira e o teste
├── nativo/               # C++ (AgIsoStack++)
│   ├── ponte/            #   a ponte que o Dart chama (o único lugar que conhece a AgIsoStack++)
│   │   ├── agiso.h       #     o contrato C que o Dart enxerga (leia este primeiro!)
│   │   ├── agiso.cpp     #     liga na rede CAN, lê a rotação e o GPS (NMEA 2000), avisa o Dart
│   │   ├── servicos.hpp  #     liga/desliga VT e TC
│   │   ├── vt.cpp        #     Terminal Virtual: transforma o object pool em lista de desenho (JSON)
│   │   └── tc.cpp        #     Task Controller (BAS, GEO e SEC)
│   ├── trator/           #   o trator automático: anda no talhão e manda GPS NMEA 2000 e velocidade
│   ├── plantadeira/      #   a plantadeira do exemplo da AgIsoStack++, com switches e consumo de semente
│   └── teste/            #   usa a ponte em C puro, sem Dart
├── pacotes/
│   ├── agiso/            # pacote Dart (sem Flutter)
│   │   ├── lib/agiso.dart      # a classe Agiso esconde o FFI (e acha a libagiso.so sozinha)
│   │   ├── lib/geo.dart        # talhão (polígonos e zonas), mapa de aplicação, engate e TC automático
│   │   ├── lib/rota.dart       # a rota do piloto: cabeceira, passadas, curvas em U e voltas
│   │   ├── lib/shapefile.dart  # lê e grava shapefile (.shp, .dbf, .prj; graus e UTM), sem dependências
│   │   ├── lib/relatorio.dart  # prescrito x aplicado, relatório e exportação em shapefile
│   │   ├── lib/banco.dart      # drift: talhões, trabalhos e mapas de aplicação (SQLite local)
│   │   └── bin/                # a cabine em modo texto e as ferramentas (shapefile, banco)
│   └── cena/             # pacote Flutter: os modelos 3D (assets/), as cenas 3D e o mapa 2D
├── apps/
│   ├── cabine/           # a cabine em Flutter: VT, TC, plantadeira 3D e mapa
│   │   └── lib/          #   main.dart, tela_vt.dart (desenha o VT), painel_tc.dart (3D e mapa)
│   └── simulador/        # o simulador 3D: física, volante, piloto automático, shapefile e trabalhos
├── exemplos/             # talhões de exemplo em shapefile (e o script Python que os gera)
├── scripts/              # vcan, bolha sem sudo, rpm e velocidade à mão, testes do TC e do GEO
└── third_party/          # AgIsoStack++ (submódulo git)
```

**Ordem sugerida de leitura:** `nativo/ponte/agiso.h` → `nativo/teste/teste.c` → `nativo/ponte/agiso.cpp` → `pacotes/agiso/lib/agiso.dart` → `apps/cabine/lib/main.dart` → `nativo/ponte/vt.cpp` → `apps/cabine/lib/tela_vt.dart` → `nativo/ponte/tc.cpp`.

Os comentários `// [passo 7]` ... `// [/passo 7]` marcam trechos adicionados em cada etapa da palestra. Podem ser ignorados: o código funciona com tudo junto.

---

## Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| `não consegui abrir vcan0` / `agiso_start falhou: -1` | A `vcan0` não existe. Rode `./scripts/setup_vcan.sh` (ou use a bolha). |
| `modprobe: FATAL: Module vcan not found` | Kernel sem `vcan` (comum em WSL e containers). Instale `linux-modules-extra-$(uname -r)` ou use outro kernel. |
| `não achei a libagiso.so` | A ponte não foi compilada: `./demo.sh preparar` (ou o passo 2). Os apps procuram a `build/libagiso.so` subindo a partir da pasta atual e da do executável; para outro lugar, use a variável `AGISO_LIB`. |
| "3D indisponível" no lugar da plantadeira, ou o simulador em branco | O Flutter GPU não ligou: confira o `fl_dart_project_set_enable_flutter_gpu` no `linux/runner/my_application.cc` e o Flutter 3.47.1+. Para testar sem mexer no runner: `flutter run -d linux --enable-flutter-gpu`. |
| O trator 3D não anda | Clique na janela do simulador (o teclado vai para a janela em foco) e ponha acelerador: W, ou E para o acelerador de mão. |
| "GPS: aguardando o trator" (modo `--ouvinte`) | O `./build/trator` não está rodando, ou está em outra rede (dentro × fora da bolha). |
| "projeção ... não suportada" ao importar | Só graus e Transversa de Mercator (UTM) são lidos. Converta: `ogr2ogr -t_srs EPSG:4674 saida.shp entrada.shp`. |
| "sem o arquivo .prj não dá para saber a projeção" | O shapefile veio sem o `.prj` e as coordenadas não são graus. Copie o `.prj` junto (mesmo nome) ou exporte de novo com ele. |
| Todas as zonas com a mesma taxa, ou taxas 1000 vezes menores | O campo ou a unidade errados na janela de importação: confira o **campo da taxa** e a **unidade** (12 em "mil sementes/ha" = 12000 sementes/ha). |
| A cabine não trocou para o talhão importado | A cabine lê o talhão **ativo** do banco a cada 2 s; confira com `cd pacotes/agiso && dart run bin/banco.dart` (o ativo tem `*`). O modo texto (`dart run bin/main.dart`) usa sempre o talhão da demo. |
| O piloto não engata | Chegue a menos de 15 m da rota (o caminho no chão), alinhado com ela (menos de 45°), andando para frente. Ele solta sozinho se você mexer no volante. |
| Começar do zero (apagar talhões e trabalhos) | Apague `~/.local/share/cabine-isobus/agro.sqlite*` com os apps fechados. |
| Dois tratores na rede (o 3D pula, o GPS da cabine salta) | O simulador dirigível e o `./build/trator` rodando juntos: use um ou outro. |
| TC automático ligado e as seções não ligam | Tudo já foi plantado (o trator recomeça o talhão no fim): toque em "limpar mapa" (ou `l`). |
| `third_party/AgIsoStack-plus-plus` vazio / erro no CMake | Faltou o submódulo: `git submodule update --init`. |
| `cansend: command not found` | `sudo apt install can-utils`. |
| `flutter: command not found` ou versão errada | Rode `mise install` dentro da pasta do projeto (o `mise.toml` fixa o 3.47.9). |
| A plantadeira fica no alarme de velocidade | Deixe `./scripts/send_velocidade.sh 8` rodando na mesma rede (ou dentro da bolha). |
| `Failed to load object pool from BasePool.iop` | Rode o `./seeder` de dentro de `build/`. |
| Tela do VT dessincronizada: switches não mudam, cores das seções erradas, velocidade parada em 1.6 | A cabine (app ou modo texto) foi reiniciada com a plantadeira rodando. A plantadeira reenvia a tela com os valores iniciais, mas acha que a cabine já mostra os valores antigos e não manda de novo. **Reinicie o `./seeder` sempre que reiniciar a cabine** (inclusive depois do `teste_tc.sh`). |
| Switches e funis com estados diferentes | Recompile (`cmake --build build`) e reinicie o `./seeder`. A cópia do simulador em `nativo/plantadeira/` faz o switch acompanhar a seção: em automático, o TC e o operador mudam os dois juntos, e vale a última ordem. (O exemplo original da AgIsoStack++ ignorava os switches no automático.) |
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
