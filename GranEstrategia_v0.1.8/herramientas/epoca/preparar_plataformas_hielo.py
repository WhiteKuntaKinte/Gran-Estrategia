#!/usr/bin/env python3
"""Convierte las plataformas de hielo de la Antártida (Natural Earth 10m, `ne_10m_antarctic_ice_shelves_polys.geojson`) a coordenadas del mapa (px),
las simplifica y las guarda en `herramientas/epoca/fuentes/plataformas_hielo_px.json`.

Por qué: la vista de Relieve pinta esas plataformas (Ross, Ronne-Filchner, Amery…) como tierra blanca, pero las provincias vectoriales salen del
«admin-0» de Natural Earth, que NO las incluye: eran zonas blancas sin límites, imposibles de elegir (nota de Camilo, 2026-11-10).
`anadir_plataformas_hielo.py` las une a la provincia de la Antártida.

Uso:  python3 preparar_plataformas_hielo.py RUTA/ne_10m_antarctic_ice_shelves_polys.geojson
(Solo hace falta si se quiere regenerar el archivo; el resultado va en el repositorio.)"""
import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
ESC = 2400.0 / 360.0
TOL = 0.05            # px (≈ 0,8 km): tolerancia de la simplificación (Douglas-Peucker)
AREA_MIN = 0.5        # px²: las plataformas más chicas que esto (≈ 140 km²) no se dibujan como zona propia


def px(lon, lat):
    return [(lon + 180.0) * ESC, (90.0 - lat) * ESC]


def area(r):
    return 0.5 * sum(r[i][0] * r[(i + 1) % len(r)][1] - r[(i + 1) % len(r)][0] * r[i][1] for i in range(len(r)))


def dp(pts, tol):
    """Douglas-Peucker iterativo (sin recursión) sobre una polilínea."""
    if len(pts) < 3:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    pila = [(0, len(pts) - 1)]
    while pila:
        a, b = pila.pop()
        ax, ay = pts[a]
        bx, by = pts[b]
        dx, dy = bx - ax, by - ay
        L = (dx * dx + dy * dy) ** 0.5
        mx, mi = -1.0, -1
        for i in range(a + 1, b):
            x, y = pts[i]
            d = abs(dy * (x - ax) - dx * (y - ay)) / L if L > 0 else ((x - ax) ** 2 + (y - ay) ** 2) ** 0.5
            if d > mx:
                mx, mi = d, i
        if mx > tol:
            keep[mi] = True
            pila.append((a, mi))
            pila.append((mi, b))
    return [p for p, k in zip(pts, keep) if k]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    g = json.load(open(sys.argv[1], encoding='utf-8'))
    out = []
    for f in g['features']:
        gm = f['geometry']
        polys = [gm['coordinates']] if gm['type'] == 'Polygon' else gm['coordinates']
        for p in polys:
            r = [px(x, y) for x, y in p[0]][:-1]            # solo el anillo exterior (sin huecos)
            if len(r) < 4:
                continue
            r = dp(r + [r[0]], TOL)[:-1]
            if len(r) >= 3 and abs(area(r)) >= AREA_MIN:
                out.append([[round(x, 3), round(y, 3)] for x, y in r])
    out.sort(key=lambda r: -abs(area(r)))
    ruta = os.path.join(AQUI, 'fuentes', 'plataformas_hielo_px.json')
    json.dump({'fuente': 'Natural Earth 10m · antarctic_ice_shelves_polys', 'anillos': out}, open(ruta, 'w'), separators=(',', ':'))
    print('%d plataformas, %d vértices → %s (%d KB)' % (len(out), sum(len(r) for r in out), ruta, os.path.getsize(ruta) // 1024))


if __name__ == '__main__':
    main()
