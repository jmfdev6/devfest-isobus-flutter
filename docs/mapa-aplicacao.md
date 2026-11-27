# Mapa de cobertura

O mapa de aplicação (*as-applied*) registra **onde e quanta semente caiu**. Um único buffer serve ao TC-SEC (o que já foi plantado), à textura do chão no 3D e ao que vai para o banco.

## A grade

[`MapaAplicacao`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/pacotes/agiso/lib/geo.dart):

| Campo | Tipo | Conteúdo |
|---|---|---|
| `origemE`, `origemN` | `double` | canto sudoeste da grade, em metros do talhão |
| `celula` | `double` | lado da célula: `max(0,5 m, maior lado / 4096)` |
| `largura`, `altura` | `int` | células; a grade cobre o talhão + margem para manobras |
| `dados` | `Uint8List` | código da taxa aplicada: `round(taxa / 250)`, 1–255; `0` = nada |
| `sobrepostas` | `Uint8List` | `1` onde caiu semente duas vezes |

O código de 1 byte cobre de 250 a 63 750 sementes/ha em passos de 250. A grade tem no máximo 4096 × 4096 células, ou 16 MB por camada.

### Marcar

```text
marcar(e, n, taxa, agora):
  i = índice(e, n)            // fora da grade → nada
  se dados[i] == 0:           // primeira vez
     dados[i] = código(taxa); quando[i] = agora
  senão se sobrepostas[i] == 0 e agora − quando[i] > 3 s:
     sobrepostas[i] = 1       // outra passada: semente em dobro
```

A janela de **3 s** existe porque a mesma passada toca a mesma célula várias vezes (amostragem a cada meia célula, barra larga). Só uma passada **posterior** é sobreposição. `agora` é contado em décimos de segundo do relógio do GPS.

Totais mantidos a cada marcação: `plantadas`, `sobrepostasN`, `hectares`, `sementes` (a sobreposição conta semente em dobro).

## Onde é usado

| Onde | Para quê |
|---|---|
| TC-SEC | `coberto(e, n)`: a seção que passaria sobre célula já plantada é cortada |
| chão 3D do simulador | a mesma grade como textura: cada célula plantada vira terra revolvida (veja [3D](3d.md#o-chao-uma-textura)) |
| banco | o trabalho guarda a grade, para continuar depois (veja [Banco](banco.md)) |

A cobertura da cabine fica na memória: para replantar o talhão do zero, reinicie a demo (`./demo.sh iniciar`).
