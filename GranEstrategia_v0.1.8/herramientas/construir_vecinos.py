#!/usr/bin/env python3
"""
Vecindad entre provincias y punto de anclaje de cada una (0.1.7.9.9E) — para mover tropas por el mapa.

Uso (desde la carpeta del proyecto):   python herramientas/construir_vecinos.py
Entrada : datos/fuente_provincias.json (polígonos en coordenadas del mapa), datos/provincias_juego.json (orden de las provincias)
Salida  : datos/vecinos_prov.json

Qué calcula
  · centros   : un punto DENTRO de cada provincia (el centroide de la fuente si cae dentro del polígono más grande; si no, el punto
                interior más alejado del borde). Ahí se dibujan las tropas.
  · aristas   : [a, b, km, mar]. a y b son índices de provincia (misma posición que en provincias_juego.json).
                mar = 0: comparten frontera por tierra (al menos 2 vértices en común; el borde x = 2400 vale como x = 0).
                mar = 1: están a menos de MAR_MAX_U unidades de mapa de costa a costa y NO están unidas por tierra (estrechos,
                islas cercanas). Las islas más lejanas quedan sin ruta (por ahora no hay transporte naval).
                km = distancia aproximada entre los dos centros (la proyección es equirectangular: 1 unidad ≈ 16,68 km de latitud).
Requiere: python3, numpy, scipy.
"""
import json
import math
import os
import sys
from collections import defaultdict

import numpy as np
from scipy.spatial import cKDTree

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.environ.get('GE_DATOS') or os.path.join(RAIZ, 'datos')   # 0.1.8.34: GE_DATOS = carpeta de un escenario
ANCHO = 2400.0
ALTO = 1200.0
KM_POR_UNIDAD = 40075.0 / ANCHO            # km por unidad de mapa en el ecuador (y en latitud)
TOL = 0.02                                  # vértices a menos de esto se consideran el mismo
MAR_MAX_U = 12.0                            # ~200 km: estrechos e islas cercanas
MAR_MAX_ARISTAS_POR_PAR = 2                 # enlaces marítimos por cada par de masas de tierra (mínimo garantizado)
MAR_K_POR_MASA = 1                          # 0.1.8.2a: además, cada provincia costera se enlaza con sus K provincias más cercanas de cada otra masa de tierra


def km_entre(p, q):
    dx = abs(q[0] - p[0])
    dx = min(dx, ANCHO - dx)                # el mapa da la vuelta
    lat = (ALTO / 2.0 - 0.5 * (p[1] + q[1])) / ALTO * 180.0
    return math.hypot(dx * math.cos(math.radians(lat)) * KM_POR_UNIDAD, (q[1] - p[1]) * KM_POR_UNIDAD)


def anillos_de(prov):
    r = []
    for poly in prov['polygons']:
        if poly and isinstance(poly[0][0], list):
            r.extend(poly)
        else:
            r.append(poly)
    return [a for a in r if len(a) >= 3]


def area_firmada(a):
    s = 0.0
    for i in range(len(a)):
        x1, y1 = a[i]
        x2, y2 = a[(i + 1) % len(a)]
        s += x1 * y2 - x2 * y1
    return s / 2.0


def dentro(pt, ring):
    x, y = pt
    r = np.asarray(ring)
    xs, ys = r[:, 0], r[:, 1]
    xs2, ys2 = np.roll(xs, -1), np.roll(ys, -1)
    cruza = ((ys > y) != (ys2 > y)) & (x < (xs2 - xs) * (y - ys) / np.where(ys2 == ys, 1e-12, ys2 - ys) + xs)
    return bool(np.count_nonzero(cruza) % 2)


def punto_interior(prov):
    rings = anillos_de(prov)
    if not rings:
        return list(prov['center'])
    mayor = max(rings, key=lambda a: abs(area_firmada(a)))
    c = prov['center']
    if dentro(c, mayor):
        return [round(c[0], 2), round(c[1], 2)]
    r = np.asarray(mayor)
    x0, y0 = r.min(axis=0)
    x1, y1 = r.max(axis=0)
    mejor, mejor_d = None, -1.0
    borde = r[::max(1, len(r) // 400)]
    for gx in np.linspace(x0, x1, 24):
        for gy in np.linspace(y0, y1, 24):
            if not dentro((gx, gy), mayor):
                continue
            dmin = float(np.min(np.hypot(borde[:, 0] - gx, borde[:, 1] - gy)))
            if dmin > mejor_d:
                mejor_d, mejor = dmin, (gx, gy)
    if mejor is None:
        return [round(float(r[:, 0].mean()), 2), round(float(r[:, 1].mean()), 2)]
    return [round(float(mejor[0]), 2), round(float(mejor[1]), 2)]


def main():
    fuente = json.load(open(os.path.join(DATOS, 'fuente_provincias.json'), encoding='utf-8'))
    juego = json.load(open(os.path.join(DATOS, 'provincias_juego.json'), encoding='utf-8'))['provincias']
    assert len(fuente) == len(juego), 'distinto número de provincias'
    for i, (a, b) in enumerate(zip(fuente, juego)):
        assert a['id'] == b['id'], 'orden distinto en %d: %s / %s' % (i, a['id'], b['id'])
    n = len(fuente)

    # ── vecindad por tierra: vértices compartidos ──
    dic = defaultdict(set)
    puntos, dueno = [], []
    for i, p in enumerate(fuente):
        for ring in anillos_de(p):
            for x, y in ring:
                dic[(round((x % ANCHO) / TOL), round(y / TOL))].add(i)
            for x, y in ring[::3]:
                puntos.append((x, y))
                dueno.append(i)
    pares = defaultdict(int)
    for s in dic.values():
        if len(s) > 1:
            s = sorted(s)
            for a in range(len(s)):
                for b in range(a + 1, len(s)):
                    pares[(s[a], s[b])] += 1
    tierra = sorted(k for k, v in pares.items() if v >= 2)
    print('aristas por tierra:', len(tierra))

    # ── masas de tierra (componentes) ──
    padre = list(range(n))

    def raiz(a):
        while padre[a] != a:
            padre[a] = padre[padre[a]]
            a = padre[a]
        return a

    for a, b in tierra:
        ra, rb = raiz(a), raiz(b)
        if ra != rb:
            padre[ra] = rb
    comp = [raiz(i) for i in range(n)]
    tam = defaultdict(int)
    for c in comp:
        tam[c] += 1
    print('masas de tierra:', len(tam), '· la mayor tiene', max(tam.values()), 'provincias · sueltas (1 provincia):', sum(1 for v in tam.values() if v == 1))

    # ── enlaces marítimos: costas cercanas de masas distintas ──
    pts = np.asarray(puntos)
    dueno = np.asarray(dueno)
    arbol = cKDTree(pts)
    mejores = defaultdict(lambda: defaultdict(lambda: 1e9))       # (compA, compB) -> {(provA, provB): distancia mínima}
    for i, vecinos in enumerate(arbol.query_ball_point(pts, r=MAR_MAX_U)):
        pa = int(dueno[i])
        ca = comp[pa]
        for j in vecinos:
            pb = int(dueno[j])
            cb = comp[pb]
            if cb <= ca:
                continue
            d = float(np.hypot(*(pts[i] - pts[j])))
            clave = (pa, pb) if pa < pb else (pb, pa)
            if d < mejores[(ca, cb)][clave]:
                mejores[(ca, cb)][clave] = d
    mar = []
    for (ca, cb), lista in mejores.items():
        elegidas, usados = [], set()
        for (pa, pb), d in sorted(lista.items(), key=lambda t: t[1]):
            if pa in usados or pb in usados:
                continue
            elegidas.append((pa, pb))
            usados.update((pa, pb))
            if len(elegidas) >= MAR_MAX_ARISTAS_POR_PAR:
                break
        mar.extend(elegidas)
    # 0.1.8.2a: antes solo había 2 enlaces por cada par de masas (una isla pegada a Eurasia tenía 2 en total y las tropas daban la vuelta
    # por la costa hasta ese punto). Ahora cada provincia costera tiene sus propios enlaces con las más cercanas de cada otra masa.
    cercanas = defaultdict(lambda: defaultdict(list))                # provincia -> masa ajena -> [(distancia, otra provincia)]
    for (ca, cb), lista in mejores.items():
        for (pa, pb), d in lista.items():
            cercanas[pa][cb].append((d, pb))
            cercanas[pb][ca].append((d, pa))
    extra = set()
    for pa, por_masa in cercanas.items():
        for cb, lst in por_masa.items():
            for d, pb in sorted(lst)[:MAR_K_POR_MASA]:
                extra.add((pa, pb) if pa < pb else (pb, pa))
    ya = set((a, b) if a < b else (b, a) for a, b in mar)
    mar.extend(sorted(extra - ya))
    print('enlaces marítimos:', len(mar), '(%d de ellos añadidos por provincia)' % len(extra - ya))

    # ── centros y distancias ──
    centros = [punto_interior(p) for p in fuente]
    aristas = []
    for a, b in tierra:
        aristas.append([a, b, max(1, int(round(km_entre(centros[a], centros[b])))), 0])
    for a, b in mar:
        aristas.append([a, b, max(1, int(round(km_entre(centros[a], centros[b])))), 1])
    fuera = sum(1 for i, p in enumerate(fuente) if abs(centros[i][0] - p['center'][0]) > 0.02 or abs(centros[i][1] - p['center'][1]) > 0.02)
    print('centros movidos al interior:', fuera, 'de', n)

    # ── sin ruta: provincias aisladas (ni tierra ni mar cercano) ──
    grado = [0] * n
    for a, b, _, _ in aristas:
        grado[a] += 1
        grado[b] += 1
    aisladas = [fuente[i]['name'] + ' (' + fuente[i]['country_es'] + ')' for i in range(n) if grado[i] == 0]
    print('provincias sin ningún vecino:', len(aisladas), aisladas[:12])

    salida = {'version': '0.1.8.2a', 'n': n, 'mar_max_unidades': MAR_MAX_U, 'km_por_unidad': KM_POR_UNIDAD,
              'centros': centros, 'aristas': aristas}
    ruta = os.path.join(DATOS, 'vecinos_prov.json')
    with open(ruta, 'w', encoding='utf-8') as f:
        json.dump(salida, f, ensure_ascii=False, separators=(',', ':'))
    print('escrito', ruta, '%.0f KB' % (os.path.getsize(ruta) / 1024))


if __name__ == '__main__':
    sys.exit(main())
