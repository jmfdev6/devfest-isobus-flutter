# Talhão

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
| `Talhao.padrao()` | 60 × 120 m em Sinop-MT, três faixas (12, 20 e 16 mil/ha de sul a norte): o mesmo que o `./build/trator` percorre |
| `taxa(e, n)` | a taxa da zona, `taxaPadrao` dentro sem zona, `null` fora |
| `dentro(e, n)` | ponto no talhão |
| `local` / `graus` | conversões |

## Trocar o talhão

O talhão vem do `Talhao.padrao()`, em [`geo.dart`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/pacotes/agiso/lib/geo.dart). Para outro campo, mude ali o contorno, as zonas e a origem. Se o `./build/trator` for usado (`--automatico`), mude também as constantes do topo de [`trator.cpp`](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/nativo/trator/trator.cpp), para ele andar no mesmo lugar.

O banco guarda o talhão ativo: depois de mudar o padrão, apague o banco (`rm -f ~/.local/share/cabine-isobus/agro.sqlite*`, com os apps fechados) para ele ser gravado de novo.
