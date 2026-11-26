#!/usr/bin/env python3
"""Gera os shapefiles de exemplo de um talhão irregular em Sinop (MT):

  talhao_sinop          3 zonas de prescrição (campo TAXA, sementes/ha), em graus (WGS84)
  talhao_sinop_utm      o mesmo, em SIRGAS 2000 / UTM 21S (metros)
  contorno_sinop_utm    só o contorno do talhão, em UTM 21S
  prescricao_sinop      só a prescrição: faixas maiores que o talhão (o contorno corta),
                        campo DOSE_MIL em MIL sementes/ha, em graus

Uso: python3 exemplos/gerar_talhao.py      (só a biblioteca padrão do Python)
"""
import math
import os
import struct

LAT0, LON0 = -11.8700, -55.5100  # canto de referência
GIRO = math.radians(20)  # o talhão é inclinado: a linha AB não é norte-sul
M_POR_GRAU = 111320.0

# o contorno, em metros (leste, norte) antes do giro: um pentágono de ~4,5 ha
CONTORNO = [(0, 0), (170, 0), (190, 140), (120, 280), (-10, 250)]
# as zonas: faixas ao longo do comprimento (norte, antes do giro)
ZONAS = [(0, 90, 12000, 'baixa'), (90, 190, 20000, 'alta'), (190, 1e9, 16000, 'media')]


def recortar(poligono, n_min, n_max):
    """Sutherland-Hodgman: a parte do polígono com n_min <= norte <= n_max."""
    def corta(pontos, dentro, cruza):
        saida = []
        for i, a in enumerate(pontos):
            b = pontos[(i + 1) % len(pontos)]
            if dentro(a):
                saida.append(a)
                if not dentro(b):
                    saida.append(cruza(a, b))
            elif dentro(b):
                saida.append(cruza(a, b))
        return saida

    def no_norte(valor):
        return lambda a, b: (a[0] + (b[0] - a[0]) * (valor - a[1]) / (b[1] - a[1]), valor)

    p = corta(poligono, lambda q: q[1] >= n_min, no_norte(n_min))
    return corta(p, lambda q: q[1] <= n_max, no_norte(n_max))


def graus(e, n):
    """Gira 20° e converte metros em graus (lon, lat)."""
    eg = e * math.cos(GIRO) - n * math.sin(GIRO)
    ng = e * math.sin(GIRO) + n * math.cos(GIRO)
    return (LON0 + eg / (M_POR_GRAU * math.cos(math.radians(LAT0))), LAT0 + ng / M_POR_GRAU)


# --- Transversa de Mercator direta (Snyder, "Map Projections — A Working Manual", p. 61) ---
A_GRS80, F_GRS80 = 6378137.0, 1 / 298.257222101


def tm_direta(lon, lat, lon0, a=A_GRS80, f=F_GRS80, k0=0.9996, fe=500000.0, fn=10000000.0):
    e2 = f * (2 - f)
    ep2 = e2 / (1 - e2)
    phi, lam = math.radians(lat), math.radians(lon - lon0)

    def m(p):
        return a * ((1 - e2 / 4 - 3 * e2**2 / 64 - 5 * e2**3 / 256) * p
                    - (3 * e2 / 8 + 3 * e2**2 / 32 + 45 * e2**3 / 1024) * math.sin(2 * p)
                    + (15 * e2**2 / 256 + 45 * e2**3 / 1024) * math.sin(4 * p)
                    - (35 * e2**3 / 3072) * math.sin(6 * p))

    n = a / math.sqrt(1 - e2 * math.sin(phi)**2)
    t = math.tan(phi)**2
    c = ep2 * math.cos(phi)**2
    aa = lam * math.cos(phi)
    x = k0 * n * (aa + (1 - t + c) * aa**3 / 6 + (5 - 18 * t + t * t + 72 * c - 58 * ep2) * aa**5 / 120)
    y = k0 * (m(phi) + n * math.tan(phi) * (aa * aa / 2 + (5 - t + 9 * c + 4 * c * c) * aa**4 / 24
                                             + (61 - 58 * t + t * t + 600 * c - 330 * ep2) * aa**6 / 720))
    return fe + x, fn + y


# o exemplo numérico do livro (Clarke 1866, 40°30'N 73°30'W, meridiano central 75°W):
# x = 127.106,5 m e y = 4.484.124,4 m
_x, _y = tm_direta(-73.5, 40.5, -75, a=6378206.4, f=1 - math.sqrt(1 - 0.00676866), fe=0, fn=0)
assert abs(_x - 127106.5) < 0.1 and abs(_y - 4484124.4) < 0.1, (_x, _y)

PRJ_UTM21S = ('PROJCS["SIRGAS_2000_UTM_Zone_21S",GEOGCS["GCS_SIRGAS_2000",DATUM["D_SIRGAS_2000",'
              'SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],'
              'UNIT["Degree",0.0174532925199433]],PROJECTION["Transverse_Mercator"],'
              'PARAMETER["False_Easting",500000.0],PARAMETER["False_Northing",10000000.0],'
              'PARAMETER["Central_Meridian",-57.0],PARAMETER["Scale_Factor",0.9996],'
              'PARAMETER["Latitude_Of_Origin",0.0],UNIT["Meter",1.0]]')
PRJ_WGS84 = ('GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],'
             'PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]')


def utm(anel):
    return [tm_direta(lon, lat, -57.0) for lon, lat in anel]


def horario(anel):
    """O shapefile quer o anel externo no sentido horário (área com sinal negativa)."""
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(anel, anel[1:] + anel[:1]))
    return anel if area < 0 else anel[::-1]


def escrever(base, poligonos, registros, campos, prj=PRJ_WGS84):
    # .shp e .shx: cabeçalho de 100 bytes + registros de polígono (tipo 5)
    conteudos = []
    for anel in poligonos:
        anel = horario(anel)
        anel = anel + [anel[0]]  # o anel é fechado: o último ponto repete o primeiro
        xs, ys = [p[0] for p in anel], [p[1] for p in anel]
        c = struct.pack('<i4d2i', 5, min(xs), min(ys), max(xs), max(ys), 1, len(anel))
        c += struct.pack('<i', 0) + b''.join(struct.pack('<2d', *p) for p in anel)
        conteudos.append(c)
    todos = [p for anel in poligonos for p in anel]
    caixa = (min(p[0] for p in todos), min(p[1] for p in todos), max(p[0] for p in todos), max(p[1] for p in todos))

    def cabecalho(tamanho_bytes):
        return struct.pack('>7i', 9994, 0, 0, 0, 0, 0, tamanho_bytes // 2) + struct.pack('<2i4d4d', 1000, 5, *caixa, 0, 0, 0, 0)

    shp, shx, pos = b'', b'', 50
    for i, c in enumerate(conteudos):
        shp += struct.pack('>2i', i + 1, len(c) // 2) + c
        shx += struct.pack('>2i', pos, len(c) // 2)
        pos += 4 + len(c) // 2
    open(base + '.shp', 'wb').write(cabecalho(100 + len(shp)) + shp)
    open(base + '.shx', 'wb').write(cabecalho(100 + len(shx)) + shx)

    # .dbf (dBASE III): cabeçalho, descritores de 32 bytes, 0x0D, registros, 0x1A
    tam_registro = 1 + sum(c[2] for c in campos)
    cab = struct.pack('<B3BIHH20x', 3, 126, 11, 24, len(registros), 32 + 32 * len(campos) + 1, tam_registro)
    for nome, tipo, tamanho in campos:
        cab += struct.pack('<11sc4xBB14x', nome.encode(), tipo.encode(), tamanho, 0)
    dados = b''
    for r in registros:
        dados += b' ' + b''.join(
            (str(v).rjust(t) if tipo == 'N' else str(v).ljust(t)).encode('latin1')[:t]
            for v, (_, tipo, t) in zip(r, campos))
    open(base + '.dbf', 'wb').write(cab + b'\r' + dados + b'\x1a')
    open(base + '.prj', 'w').write(prj)


if __name__ == '__main__':
    pasta = os.path.dirname(os.path.abspath(__file__))
    poligonos, registros = [], []
    for de, ate, taxa, nome in ZONAS:
        parte = recortar(CONTORNO, de, ate)
        poligonos.append([graus(*p) for p in parte])
        registros.append((taxa, nome))
    campos = [('TAXA', 'N', 8), ('ZONA', 'C', 10)]
    escrever(os.path.join(pasta, 'talhao_sinop'), poligonos, registros, campos)
    escrever(os.path.join(pasta, 'talhao_sinop_utm'), [utm(p) for p in poligonos], registros, campos, PRJ_UTM21S)
    escrever(os.path.join(pasta, 'contorno_sinop_utm'), [utm([graus(*p) for p in CONTORNO])],
             [('Talhao Sinop',)], [('NOME', 'C', 20)], PRJ_UTM21S)
    # a prescrição de uma empresa: faixas que passam da divisa, taxa em mil sementes/ha
    faixas = [(-40, 90, 12), (90, 190, 20), (190, 330, 16)]
    escrever(os.path.join(pasta, 'prescricao_sinop'),
             [[graus(e, n) for e, n in [(-40, de), (230, de), (230, ate), (-40, ate)]] for de, ate, _ in faixas],
             [(dose, 'faixa %d' % i) for i, (_, _, dose) in enumerate(faixas)],
             [('DOSE_MIL', 'N', 6), ('OBS', 'C', 12)])
    print('ok: talhao_sinop (graus e UTM 21S), contorno_sinop_utm, prescricao_sinop')
