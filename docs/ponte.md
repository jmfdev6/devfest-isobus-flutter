# Ponte C e Dart FFI

## O contrato: `agiso.h`

[`nativo/ponte/agiso.h`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/nativo/ponte/agiso.h) é tudo o que o Dart enxerga. Funções `extern "C"` com visibilidade `default` (o resto da `.so` é oculto).

### Ciclo de vida

| Função | Retorno | Descrição |
|---|---|---|
| `int32_t agiso_start(const char *iface, agiso_callback cb)` | 0 ou erro | **cabine**: entra na rede em `0x81` com VT e TC |
| `int32_t agiso_start_ouvinte(const char *iface, agiso_callback cb)` | 0 ou erro | só escuta GPS, rotação e o que o implemento informa ao TC; endereço `0x90` |
| `int32_t agiso_start_trator(const char *iface, agiso_callback cb)` | 0 ou erro | como o ouvinte e, além disso, **é o trator** (`0x01`) |
| `void agiso_trator_mover(double lat, double lon, double rumo, double vel, double rpm)` | — | o estado do trator a transmitir (graus, graus a partir do norte no sentido horário, m/s com ré negativa, rpm) |
| `void agiso_stop(void)` | — | remove os *listeners* e para a pilha; depois disso o callback não é mais chamado |

Códigos de erro do `start`: `-1` a interface não abriu (a `vcan0` não existe ou não está nesta rede); `-99` exceção na inicialização.

### Terminal Virtual

| Função | Descrição |
|---|---|
| `int32_t agiso_vt_apertar(uint16_t id)` | o operador tocou numa soft key, botão ou *input boolean* (pelo ID do objeto). `-1` sem implemento. |
| `int32_t agiso_vt_tela(char *dst, int32_t tam)` | a máscara ativa como [lista de desenho JSON](vt.md#a-lista-de-desenho). Retorna o tamanho; `-1` sem implemento mostrando tela. |
| `int32_t agiso_vt_figura(uint16_t id, uint8_t *rgba, int32_t tam, int32_t *w, int32_t *h)` | os pixels de um *Picture Graphic* em RGBA 8888 |

**Protocolo de tamanho:** se o retorno for maior que `tam`, nada foi copiado; o chamador aloca um buffer maior e chama de novo. A classe `Agiso` começa com 64 KiB e dobra quando precisa.

### Task Controller

| Função | Descrição |
|---|---|
| `int32_t agiso_tc_definir(uint16_t elemento, uint16_t ddi, int32_t valor)` | manda um *Set Value* ao implemento conectado. `0` enviado; `-1` sem cliente. |

### Eventos

```c
typedef void (*agiso_callback)(int32_t evento, double valor);
```

| Código | Constante | Valor | Origem |
|---|---|---|---|
| 1 | `AGISO_ENDERECO` | endereço obtido na rede | *address claim* concluído |
| 2 | `AGISO_RPM` | rpm | EEC1 (`0xF004`), bytes 4–5 (contando de 1) × 0,125 |
| 3 | `AGISO_TAXA` | taxa (DDI 11) | process data do implemento, elemento 3 |
| 4 | `AGISO_SECOES` | DDI 161, 2 bits por seção (`00` desligada, `01` ligada, `11` não existe) | elemento 2 |
| 5 | `AGISO_DEPOSITO` | sementes no depósito (DDI 78) | elemento 3 |
| 6 | `AGISO_LAT` | graus | NMEA 2000 129025 |
| 7 | `AGISO_LON` | graus | NMEA 2000 129025 |
| 8 | `AGISO_RUMO` | graus, 0 = norte, horário | NMEA 2000 129026 (COG) |
| 9 | `AGISO_VELOCIDADE` | m/s | NMEA 2000 129026 (SOG) |

Na cabine, a ponte recebe os valores do TC (taxa, seções, depósito) pelo próprio TC *server*. Nos modos ouvinte e trator, sem TC, ela **fareja** os quadros de *process data* (PGN `0xCB00`) que o implemento manda à cabine: 4 bits de comando, 12 de elemento, 16 de DDI e 32 de valor.

O callback tem **uma assinatura só** de propósito: `(int, double)` é trivial de casar com `NativeCallable`. A posição chega em pedaços (lat, rumo, velocidade e por último lon); o Dart junta num evento `Gps` quando a longitude chega.

## O lado Dart: `Agiso`

[`pacotes/agiso/lib/agiso.dart`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/pacotes/agiso/lib/agiso.dart):

```dart
final agiso = Agiso();                 // acha a libagiso.so sozinha
agiso.eventos.listen((e) => switch (e) {
  Rotacao(:final rpm) => print('motor a $rpm'),
  Gps g => tc.aoGps(g),
  _ => null,
});
agiso.iniciar('vcan0');                // ou iniciarOuvinte / iniciarTrator
agiso.definirNoTc(3, 11, 20000);       // taxa alvo
final tela = agiso.tela();             // Map da lista de desenho, ou null
agiso.parar();
```

`Evento` é uma `sealed class` com `Endereco`, `Rotacao`, `Taxa`, `Deposito`, `Gps` e `Secoes`. Um `switch` sobre ela é verificado pelo compilador.

### Onde está a `.so`

`acharPonte()` procura, em ordem:

1. a variável de ambiente `AGISO_LIB`;
2. `build/libagiso.so`, subindo até 10 pastas a partir do **diretório atual**;
3. o mesmo, a partir da **pasta do executável** (o *bundle* do Flutter).

Por isso os apps rodam com `flutter run`, pelo executável do *bundle* ou pelo `demo.sh`, sem configuração.

### Ordem de parada

```dart
void parar() {
  _stop();             // 1. o C para de chamar
  _callback?.close();  // 2. só então o ponteiro de função morre
  ...
}
```

Fechar o `NativeCallable` antes do `agiso_stop` deixaria a thread da pilha chamando um ponteiro inválido.

## Usar a ponte sem Dart

[`nativo/teste/teste.c`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/nativo/teste/teste.c) é o contrato em C puro, útil para isolar problemas:

```bash
./build/teste vcan0            # terminal A
./scripts/send_rpm.sh 1800     # terminal B → "rotação 1800.0 rpm"
```

## Compilação

O [`CMakeLists.txt`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/CMakeLists.txt) da raiz inclui a AgIsoStack++ como subdiretório e gera:

| Alvo | Fontes | Saída |
|---|---|---|
| `agiso` | `nativo/ponte/*.cpp` | `build/libagiso.so` |
| `teste` | `nativo/teste/teste.c` | `build/teste` |
| `trator` | `nativo/trator/trator.cpp` | `build/trator` |
| `seeder` | `nativo/plantadeira/*` | `build/seeder` (+ `BasePool.iop` ao lado, por isso roda de dentro de `build/`) |
