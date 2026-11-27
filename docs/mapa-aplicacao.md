# Mapa de aplicação

O mapa de aplicação (*as-applied*) registra **onde e quanta semente caiu**. Um único buffer serve a quatro consumidores: a cobertura do TC-SEC, o mapa 2D da cabine, a textura do chão no 3D e o que vai para o banco.

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

## Prescrito × aplicado

[`relatorio.dart`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/pacotes/agiso/lib/relatorio.dart) amostra a prescrição no centro de cada célula da **mesma grade** (`gradeDePrescricao`) e classifica:

| Classe | Regra (nesta ordem) | Cor |
|---|---|---|
| fora | prescrito = 0 (fora do talhão) | — |
| não aplicado | aplicado = 0 | cinza-claro |
| sobreposto | `sobrepostas[i] = 1` | roxo |
| abaixo | (aplicado − prescrito) / prescrito < −5% | laranja |
| acima | > +5% | vermelho |
| na taxa | dentro de ±5% | verde |

A tolerância é um parâmetro (`tolerancia: 0.05`).

### Relatório

`Relatorio.de(mapa, prescricao)` soma, **por taxa prescrita** e no total, só dentro do talhão:

| Coluna | |
|---|---|
| área | ha prescritos com essa taxa |
| aplicada | ha com alguma semente |
| na taxa / abaixo / acima / sobreposta | ha em cada classe |
| sementes previstas | Σ prescrito × área da célula |
| sementes aplicadas | Σ aplicado × área (em dobro nas sobrepostas) |

`emTexto()` gera a tabela para o terminal; a cabine e o simulador mostram a mesma tabela num diálogo.

## Exportar como shapefile

`exportarAplicacao(...)` grava polígonos em **WGS84**. Para não gerar um polígono por célula, cada linha da grade é varrida e as células vizinhas com a mesma chave `(aplicado, prescrito, sobreposta)` viram um retângulo só.

| Campo | Tipo | Conteúdo |
|---|---|---|
| `TAXA_APL` | N | sementes/ha aplicadas |
| `TAXA_PRE` | N | sementes/ha prescritas (vazio fora das zonas) |
| `DIF_PCT` | N | diferença percentual |
| `SOBREP` | N | 1 = sobreposto |
| `AREA_M2` | N | área do polígono |

Abre no QGIS ou em softwares agrícolas. O `bin/shapefile.dart` confere a exportação relendo o arquivo gravado.

## Visualização

| Onde | Como |
|---|---|
| cabine (ao vivo) | [`pacotes/cena/lib/mapa.dart`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/pacotes/cena/lib/mapa.dart): a grade vira uma imagem refeita no máximo **1 vez por segundo**; contorno, trator e barra são desenhados por cima. Modos *aplicado*, *prescrito × aplicado* e *prescrição*, com legenda. |
| simulador, "ver trabalho" | o mesmo widget, para trabalhos guardados |
| chão 3D | a mesma grade como textura (veja [3D](3d.md#o-chao-uma-textura)); tecla **M** alterna terra / taxa / prescrito × aplicado |

Escala de cores da taxa (`corDaTaxa`): interpolação do amarelo (10 mil/ha ou menos) ao verde-escuro (22 mil/ha ou mais). A prescrição na grade é calculada num *isolate*, fora da thread da interface.
