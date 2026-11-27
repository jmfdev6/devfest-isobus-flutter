# Rede CAN e mensagens

Tudo roda sobre **SocketCAN** numa interface `vcan0` (virtual). Os quadros usam o identificador estendido de 29 bits do J1939: prioridade (3 bits), PGN (18 bits) e endereço de origem (8 bits). Mensagens com mais de 8 bytes (o *object pool*, o DDOP, a posição GNSS completa) usam os protocolos de transporte (TP/ETP do ISO 11783-3, *fast packet* do NMEA 2000), que a AgIsoStack++ cuida.

## Quem manda o quê

| Mensagem | PGN | De | Para | Ritmo | Uso |
|---|---|---|---|---|---|
| Address Claim | `0xEE00` | todos | todos | na entrada | endereço de cada ECU |
| EEC1 (rotação do motor) | `0xF004` | trator | todos | 100 ms | cabine mostra o rpm |
| Ground-based speed and distance | `0xFE49` | trator | todos | 100 ms | a plantadeira dosa pela velocidade |
| Position, rapid update | 129025 (`0x1F801`) | trator | todos | da norma (100 ms) | TC automático, 3D |
| COG & SOG, rapid update | 129026 (`0x1F802`) | trator | todos | da norma (250 ms) | rumo e velocidade |
| GNSS position data | 129029 (`0x1F805`) | trator | todos | da norma (1 s) | posição completa, método RTK *fixed* |
| Vessel heading | 127250 (`0x1F112`) | trator | todos | da norma (100 ms) | proa |
| VT ↔ ECU | `0xE600` / `0xE700` | cabine ↔ plantadeira | — | sob demanda | *object pool*, mudanças de valor, soft keys |
| Process data | `0xCB00` | cabine ↔ plantadeira | — | sob demanda / assinatura | DDOP, *set value*, valores medidos |

### `0xFE49` — velocidade de solo

| Bytes | Conteúdo |
|---|---|
| 0–1 | velocidade, mm/s (little-endian) |
| 2–5 | distância, mm |
| 7 | sentido: `01` frente, `00` ré |

A plantadeira (AgIsoStack++) ignora velocidade de quem não fez *address claim*. Por isso o `send_velocidade.sh` também anuncia o endereço `0x01`.

### EEC1 — rotação

Bytes 3 e 4 (contando de 0) = rpm / 0,125, little-endian; o resto `0xFF` (não disponível).

```bash
./scripts/send_rpm.sh 1800
# cansend vcan0 0CF00401#FFFFFF4038FFFFFF  (1800 / 0,125 = 14400 = 0x3840)
```

### NMEA 2000

A ponte usa o `NMEA2000MessageInterface` da AgIsoStack++. Ao receber, publica eventos de 129025 (lat, lon) e 129026 (COG, SOG). No modo trator, os mesmos objetos são preenchidos com o estado de `agiso_trator_mover` e transmitidos no ritmo padrão de cada PGN:

| Campo | Resolução |
|---|---|
| lat/lon (129025) | 1e-7 grau, `int32` |
| lat/lon (129029) | 1e-16 grau, `int64` |
| COG, proa | 0,0001 rad |
| SOG | 0,01 m/s |

### Process data (`0xCB00`)

8 bytes: `comando` (4 bits) | `elemento` (12 bits) | `DDI` (16 bits) | `valor` (32 bits, com sinal). Os DDIs usados estão em [Task Controller](tc.md#ddis-usados).

## Ver a rede

```bash
candump vcan0                      # com a vcan0 do sistema
./demo.sh rede                     # na bolha: abre um shell dentro dela
candump -c -a vcan0                # cores e ASCII
candump vcan0,00F00400:00FFFF00    # só EEC1 (qualquer prioridade e origem)
```

Exemplos de identificadores:

| ID | Leitura |
|---|---|
| `18EEFF81` | prioridade 6, Address Claim (`EE`) para todos (`FF`), da cabine (`81`) |
| `0CF00401` | prioridade 3, EEC1 (`F004`), do `01` (o `send_rpm.sh`; a ponte usa a prioridade padrão 6: `18F00401`) |
| `0CFE4901` / `18FE4901` | velocidade de solo (`FE49`) do `01` (`send_velocidade.sh` / ponte) |
| `09F80101` | NMEA 2000 129025 (`1F801`) do trator |

## Simuladores de rede

| Ferramenta | O que faz |
|---|---|
| [`scripts/send_rpm.sh RPM`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/scripts/send_rpm.sh) | um EEC1 |
| [`scripts/send_velocidade.sh KMH`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/scripts/send_velocidade.sh) | address claim `0x01` e `0xFE49` contínuo |
| `./build/trator vcan0 KMH` | o trator automático no talhão da demo (60 × 120 m em Sinop-MT, passadas norte-sul de 7,6 m) |
| simulador Flutter | o trator dirigível |
