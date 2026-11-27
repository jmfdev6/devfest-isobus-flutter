# Roteiro da palestra

O caminho da apresentação, **sem o `demo.sh`**: cada etapa acrescenta uma peça e mostra o resultado. Os comentários `// [passo N]` no código marcam o que cada etapa trouxe.

!!! tip "Rede"
    Os comandos usam a `vcan0` do sistema (`./scripts/setup_vcan.sh`). Sem sudo, crie a bolha (`./scripts/bolha.sh criar`) e prefixe **cada** comando que fala com a rede com `./scripts/bolha.sh entrar`.

## 1. Baixar e compilar

```bash
git clone --recurse-submodules https://github.com/jmfdev6/devfest-isobus-flutter.git
cd devfest-isobus-flutter
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
ls build/libagiso.so build/teste build/seeder build/trator
```

## 2. A rede CAN virtual

```bash
./scripts/setup_vcan.sh        # → OK: vcan0 pronta.
```

## 3. A ponte, sem Dart

```bash
./build/teste vcan0            # terminal A
./scripts/send_rpm.sh 1800     # terminal B, em até 10 s
```

```text
endereço 0x81
rotação 1800.0 rpm
```

A parte em C++ funciona: *address claim* e leitura do EEC1.

## 4. A ponte pelo Dart (modo texto)

```bash
cd pacotes/agiso && dart pub get && dart run bin/main.dart vcan0   # terminal A
./scripts/send_rpm.sh 621                                          # terminal B
```

```text
DART| na rede como 0x81
DART| motor a 621 rpm
```

Comandos do modo texto:

| Comando | Efeito |
|---|---|
| `1` … `6` | aperta a 1ª … 6ª soft key da tela atual |
| `b 6000` | aperta um objeto pelo ID (6000 … 6005 = switches das seções 1 … 6) |
| `t 3 11 20000` | TC: elemento 3, DDI 11, valor 20000 |
| `g` | liga/desliga o TC automático (GEO + SEC) |
| `l` | limpa o mapa de aplicação |
| `s` | sai |

Sem implemento na rede, teclas e `t` retornam `-1`: não há para quem mandar.

## 5. Um implemento: a plantadeira

```bash
cd build && ./seeder --interface vcan0     # terminal B (de dentro de build/: lê o BasePool.iop)
./scripts/send_velocidade.sh 8             # terminal C: "trator" a 8 km/h
```

```text
VT  | tela do implemento 0x80 ACEITA
VT  | 11000="Seeder Example"  ...  12009="8.0"
TC  | DDOP recebido de 0x80: 1428 bytes
TC  | DET 3 Product
TC  |     DPD  DDI 11  Target Rate
TC  | assinei 17 valores
TC  | Target Rate (3/11) = 12000
TC  | Bin Level (3/78) = 150000
```

```text
t 3 11 20000
TC  | Target Rate (3/11) = 20000
```

Sem velocidade, a plantadeira mostra o alarme "Machine Speed Not Detected". O TC conecta alguns segundos depois do VT: a norma manda o implemento esperar.

## 6. O app Flutter

```bash
cd apps/cabine && flutter pub get && flutter run -d linux
./scripts/send_rpm.sh 900 && ./scripts/send_rpm.sh 2100       # outro terminal
```

A janela mostra a rotação e, com a plantadeira na rede, a tela dela: cores, figuras, medidor e soft keys. Toques nos botões ligam e desligam as seções; "TC: 20 mil sementes/ha" manda a taxa pelo TC.

## 7. Ver a rede por dentro

```bash
candump vcan0
```

`18EEFF81` é a cabine anunciando o endereço; `0CF00401`, as rotações enviadas. Mais em [Rede CAN](rede-can.md).

## 8. Teste automático do TC

```bash
./scripts/teste_tc.sh       # PASSOU em ~20 s
```

## 9. GPS NMEA 2000 e o TC automático

```bash
./build/trator vcan0 8      # anda no talhão da demo, 60 × 120 m em Sinop-MT
```

O trator manda 129025, 129026, 129029, 127250 e `0xFE49` (substitui o `send_velocidade.sh`). Na cabine, o TC automático (GEO + SEC) já vem ligado e o efeito aparece na tela do VT (no modo texto, `g` liga e desliga):

- **TC-GEO:** a taxa pela faixa do mapa (12, 20 e 16 mil/ha de sul a norte);
- **TC-SEC:** cada seção liga só dentro do talhão e fora do já plantado. As passadas do trator automático ficam a 7,6 m e a barra tem 9,1 m: na volta, a seção sobreposta é cortada; na cabeceira, as seções cortam uma a uma.

```bash
./scripts/teste_geo.sh      # PASSOU em ~1 min (trator a 30 km/h)
```

## 10. O simulador 3D

```bash
cd apps/simulador && flutter pub get
flutter run -d linux                    # você dirige (sem o ./build/trator!)
flutter run -d linux -a --ouvinte       # só acompanha o ./build/trator
```

Controles e física em [Simulador](simulador.md); renderização em [3D](3d.md).

## 11. Trabalhos

No simulador, **novo trabalho** começa do zero e **trabalhos** mostra o histórico (área, sementes, distância) e deixa continuar um antigo. Detalhes em [Mapa de cobertura](mapa-aplicacao.md) e [Banco](banco.md).

## Ordem no dia

A ordem importa: **a cabine sobe antes da plantadeira** (veja [por quê](demo.md#iniciar)).

```bash
./scripts/setup_vcan.sh                                  # 1. rede
cd apps/cabine && flutter run -d linux                   # 2. cabine (TC automático já ligado)
cd build && ./seeder --interface vcan0                   # 3. plantadeira (espere "TC | assinei")
cd apps/simulador && flutter run -d linux                # 4. trator: você dirige
```

Sem motorista: troque o 4 por `./build/trator vcan0 8`, abra a cabine com `-a --talhao-demo` e o simulador com `-a --ouvinte`. É o que `./demo.sh iniciar --automatico` faz.

Antes de subir no palco, rode `./demo.sh testar` na máquina da apresentação.

```bash
./scripts/teardown_vcan.sh     # no fim
```
