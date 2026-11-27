# Talhão e shapefile

## O modelo de talhão

[`Talhao`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/pacotes/agiso/lib/geo.dart) guarda, **em metros** (leste, norte) a partir de uma origem (o canto sudoeste):

- `contorno`: uma lista de polígonos (anel externo + buracos). "Dentro" é decidido por **par-ou-ímpar**: um raio para leste cruza as bordas um número ímpar de vezes;
- `zonas`: polígonos com uma taxa (sementes/ha), o mapa de prescrição;
- `taxaPadrao`: a taxa onde nenhuma zona cobre.

A conversão graus ↔ metros é uma projeção **equiretangular local** em torno da origem:

```text
e = (lon − lon0) · 111 320 · cos(lat0)
n = (lat − lat0) · 111 320
```

Para talhões de alguns quilômetros, o erro é de centímetros, muito menor que a largura de uma seção. O banco guarda o talhão **em graus**, e a origem é recalculada ao abrir.

| Método | Descrição |
|---|---|
| `Talhao.demo()` | 60 × 120 m em Sinop-MT, três faixas (12, 20 e 16 mil/ha de sul a norte): o mesmo que o `./build/trator` percorre |
| `Talhao.deShapefiles(nome:, contorno:, prescricao:, campoTaxa:, fator:, taxaPadrao: 16000)` | contorno e prescrição (opcionalmente separados) |
| `taxa(e, n)` | a taxa da zona, `taxaPadrao` dentro sem zona, `null` fora |
| `dentro(e, n)` | ponto no talhão |
| `linhaAB` | a AB padrão: a maior borda reta da divisa, meia barra para dentro |
| `local` / `graus` | conversões |

### Prescrição separada

Empresas de agricultura de precisão costumam entregar o **contorno** e a **prescrição** em arquivos diferentes, com zonas que passam da divisa. Na leitura, a taxa de um ponto vem da zona que o contém, e o ponto só conta se estiver dentro do contorno: **o contorno corta**.

O campo de taxa e a unidade são escolhidos na importação:

| Unidade | `fator` |
|---|---|
| sementes/ha | 1 |
| mil sementes/ha | 1000 |
| sementes/m² | 10 000 |

`Talhao.campoDeTaxaProvavel` pré-seleciona um campo numérico pelo nome (`TAXA`, `RATE`, `DOSE`, …), e a janela sugere a unidade pela ordem de grandeza dos valores.

## Leitor e escritor de shapefile

[`pacotes/agiso/lib/shapefile.dart`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/pacotes/agiso/lib/shapefile.dart): sem dependências, sobre `ByteData`.

### Leitura

| Arquivo | O que é lido |
|---|---|
| `.shp` | cabeçalho de 100 bytes; registros (big-endian no cabeçalho do registro, little-endian no conteúdo). Tipos 1 (ponto), 3 (linha) e 5 (polígono); as variantes Z e M viram estes. |
| `.dbf` | dBASE III: campos `N`, `F`, `C`, `D`…; texto em Latin-1 |
| `.prj` | WKT: graus (GEOGCS) ou Transversa de Mercator (PROJCS) |
| `.shx` | não é necessário (os registros são lidos em sequência) |

As geometrias saem **sempre em graus** (`x` = longitude, `y` = latitude). Se o `.prj` for projetado, cada ponto passa pela TM inversa. Sem `.prj`, coordenadas fora de ±180/±90 dão erro explicando o motivo.

### Escrita

`Shapefile.gravarPoligonos(...)` grava `.shp`, `.shx`, `.dbf`, `.prj` (WGS84) e `.cpg`. O anel externo vai no sentido **horário** (área com sinal negativa), como pede a especificação ESRI.

## Transversa de Mercator (UTM)

`TransversaDeMercator` implementa as séries do **Snyder, *Map Projections — A Working Manual* (USGS, 1987), p. 60–64**, para o elipsoide do `.prj` (GRS 80 no SIRGAS 2000, WGS 84…). A precisão é de milímetros dentro de uma zona UTM.

Parâmetros lidos do WKT: `False_Easting`, `False_Northing`, `Central_Meridian`, `Scale_Factor`, `Latitude_Of_Origin` e o `SPHEROID` (semieixo e inverso do achatamento).

**Inversa** (metros → graus), resumida:

```text
M   = M0 + (y − FN) / k0
μ   = M / (a (1 − e²/4 − 3e⁴/64 − 5e⁶/256))
e1  = (1 − √(1−e²)) / (1 + √(1−e²))
φ1  = μ + (3e1/2 − 27e1³/32) sin 2μ + (21e1²/16 − 55e1⁴/32) sin 4μ
        + (151e1³/96) sin 6μ + (1097e1⁴/512) sin 8μ
C1  = e'² cos²φ1,  T1 = tan²φ1,  N1 = a / √(1 − e² sin²φ1)
R1  = a (1 − e²) / (1 − e² sin²φ1)^{3/2},  D = (x − FE) / (N1 k0)
φ   = φ1 − (N1 tanφ1 / R1) [D²/2 − (5 + 3T1 + 10C1 − 4C1² − 9e'²) D⁴/24
        + (61 + 90T1 + 298C1 + 45T1² − 252e'² − 3C1²) D⁶/720]
λ   = λ0 + [D − (1 + 2T1 + C1) D³/6
        + (5 − 2C1 + 28T1 − 3C1² + 8e'² + 24T1²) D⁵/120] / cos φ1
```

A **direta** (graus → metros) está em [`exemplos/gerar_talhao.py`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/exemplos/gerar_talhao.py), conferida contra o exemplo numérico do livro (Clarke 1866, 40°30′N 73°30′W, MC 75°W → x = 127 106,5 m, y = 4 484 124,4 m). O `bin/shapefile.dart` confere a ida e volta: o talhão em UTM 21S lido de volta coincide com o em graus.

## Exemplos

Gerados por `python3 exemplos/gerar_talhao.py` (só a biblioteca padrão): um pentágono de ~4,5 ha em Sinop-MT, inclinado 20°.

| Arquivo | Projeção | Conteúdo |
|---|---|---|
| `talhao_sinop` | WGS84 (graus) | 3 zonas, campo `TAXA` (sementes/ha) e `ZONA` |
| `talhao_sinop_utm` | SIRGAS 2000 / UTM 21S | o mesmo, em metros |
| `contorno_sinop_utm` | SIRGAS 2000 / UTM 21S | só o contorno, campo `NOME` |
| `prescricao_sinop` | WGS84 | 3 faixas maiores que o talhão, campo `DOSE_MIL` (mil sementes/ha) |

```bash
cd pacotes/agiso
dart run bin/shapefile.dart                                          # confere os exemplos
dart run bin/shapefile.dart contorno.shp prescricao.shp CAMPO 1000   # inspeciona um seu
```

Projeções que não são graus nem TM (Lambert, Albers, …): converta antes, por exemplo `ogr2ogr -t_srs EPSG:4674 saida.shp entrada.shp`.
