#!/usr/bin/env python3
"""
Paso A (opcional, solo para regenerar datos): convierte Natural Earth 10m (admin-1 + admin-0) en
datos/fuente_provincias.json, con TOPOLOGÍA COMPARTIDA: dos provincias vecinas comparten exactamente
los mismos vértices en su frontera, así que no quedan huecos ni solapes y los países no se ven "acartonados".

Proyección: equirectangular (x = (lon+180)*2400/360 ; y = (90-lat)*2400/360). El ecuador queda en y=600.

Uso:
    python herramientas/preparar_fuente.py  RUTA_NE  [tolerancia_px]
donde RUTA_NE contiene ne_10m_admin_0_countries.geojson y ne_10m_admin_1_states_provinces.geojson
Requiere: python3, numpy
"""
import json, os, sys, math, collections
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nombres_es import PAISES_ES

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ESC = 2400.0 / 360.0
MAX_UNIDADES = 100000          # países con más unidades que esto se agrupan por 'region'
AREA_MIN = 0.012           # px² : islas más pequeñas se descartan

CONT_ES = {'Asia': 'Asia', 'Africa': 'África', 'Europe': 'Europa', 'North America': 'América del Norte',
           'South America': 'América del Sur', 'Oceania': 'Oceanía', 'Antarctica': 'Antártida'}
CONT_ABIERTO = {'SYC': 'África', 'MUS': 'África', 'SHN': 'África', 'SGS': 'América del Sur', 'HMD': 'Antártida',
                'CLP': 'América del Norte', 'MDV': 'Asia', 'IOT': 'Asia'}


NOMBRE_PAIS_ES = {   # correcciones sobre Natural Earth (revisión de nombres 0.1.7.7)
    'SXM': 'Sint Maarten (Países Bajos)', 'MAF': 'San Martín (Francia)', 'COD': 'República Democrática del Congo',
    'CNM': 'Zona de amortiguación de Chipre', 'PGA': 'Islas Spratly', 'SCR': 'Bajo de Masinloc', 'MMR': 'Myanmar',
    'BRI': 'Isla Brasilera', 'CYN': 'Chipre del Norte', 'SOL': 'Somalilandia', 'PSX': 'Palestina', 'SWZ': 'Esuatini',
}


def limpiar_nombre(n):
    n = (n or '').strip()
    for pref in ('de ', 'del '):
        if n.startswith(pref):
            n = n[len(pref):]
    return n[:1].upper() + n[1:]


def proyectar(lon, lat):
    return ((lon + 180.0) * ESC, (90.0 - lat) * ESC)


def anillos_de(geom):
    polys = [geom['coordinates']] if geom['type'] == 'Polygon' else geom['coordinates']
    for poly in polys:
        yield poly[0]                      # solo contorno exterior (los huecos son enclaves que ya existen aparte)


def dp(P, eps):
    """Douglas-Peucker iterativo; P es (n,2). Devuelve índices conservados."""
    n = len(P)
    if n <= 2:
        return list(range(n))
    keep = np.zeros(n, bool)
    keep[0] = keep[-1] = True
    pila = [(0, n - 1)]
    while pila:
        a, b = pila.pop()
        if b <= a + 1:
            continue
        seg = P[b] - P[a]
        L = math.hypot(seg[0], seg[1])
        Q = P[a + 1:b] - P[a]
        if L < 1e-12:
            d = np.hypot(Q[:, 0], Q[:, 1])
        else:
            d = np.abs(Q[:, 0] * seg[1] - Q[:, 1] * seg[0]) / L
        k = int(np.argmax(d))
        if d[k] > eps:
            m = a + 1 + k
            keep[m] = True
            pila.append((a, m))
            pila.append((m, b))
    return list(np.flatnonzero(keep))


def main():
    ne = sys.argv[1]
    eps = float(sys.argv[2]) if len(sys.argv) > 2 else 0.10
    a0 = json.load(open(os.path.join(ne, 'ne_10m_admin_0_countries.geojson'), encoding='utf-8'))['features']
    a1 = json.load(open(os.path.join(ne, 'ne_10m_admin_1_states_provinces.geojson'), encoding='utf-8'))['features']
    info0 = {f['properties']['ADM0_A3']: f['properties'] for f in a0}

    # ── unidades: cada una = (id, nombre, país, continente, anillos) ──
    unidades = []
    con_a1 = set(f['properties']['adm0_a3'] for f in a1)
    ne_cond = os.path.join(ne, 'ne_10m_admin_2_counties.geojson')
    usar_cond = os.path.exists(ne_cond)
    estados = {}
    for f in a1:
        p = f['properties']
        if p['adm0_a3'] == 'USA':
            estados[p.get('postal') or p['iso_3166_2'][-2:]] = p.get('name_es') or p['name']
    if usar_cond:
        for f in json.load(open(ne_cond, encoding='utf-8'))['features']:
            p = f['properties']
            est = estados.get(p.get('REGION'), p.get('REGION') or '')
            unidades.append({'a3': 'USA', 'nombre': '%s, %s' % (p.get('NAME_ES') or p['NAME'], est), 'region': est,
                             'cod': p['ADM2_CODE'], 'geom': f['geometry']})
    for f in a1:
        p = f['properties']
        if p['adm0_a3'] not in info0:
            continue
        if usar_cond and p['adm0_a3'] == 'USA':
            continue                      # EE.UU. se subdivide en condados reales (admin-2 de Natural Earth)
        unidades.append({'a3': p['adm0_a3'], 'nombre': p.get('name_es') or p.get('name') or p.get('woe_name') or p.get('admin') or 'Sin nombre', 'region': p.get('region') or '',
                         'cod': p.get('adm1_code') or p.get('iso_3166_2') or p['name'], 'geom': f['geometry']})
    for f in a0:
        p = f['properties']
        if p['ADM0_A3'] not in con_a1:
            unidades.append({'a3': p['ADM0_A3'], 'nombre': p.get('NAME_ES') or p['NAME'], 'region': '',
                             'cod': 'A0-' + p['ADM0_A3'], 'geom': f['geometry']})

    # agrupar países con demasiadas unidades por su región
    cuenta = collections.Counter(u['a3'] for u in unidades)
    for u in unidades:
        u['grupo'] = u['cod']
        u['gnombre'] = u['nombre']
    for a3, n in cuenta.items():
        if n > MAX_UNIDADES:
            regs = set(u['region'] for u in unidades if u['a3'] == a3 and u['region'])
            if len(regs) >= 3:
                for u in unidades:
                    if u['a3'] == a3:
                        r = u['region'] or u['nombre']
                        u['grupo'] = a3 + '|' + r
                        u['gnombre'] = r

    # ── topología: aristas y su dueño ──
    def K(c):
        return (int(round(c[0] * 1e5)), int(round(c[1] * 1e5)))

    anillos = []   # (unidad, [claves], [coords proyectadas])
    for ui, u in enumerate(unidades):
        for r in anillos_de(u['geom']):
            ks, ps = [], []
            for c in r[:-1] if r[0] == r[-1] else r:
                k = K(c)
                if ks and ks[-1] == k:
                    continue
                ks.append(k)
                ps.append(proyectar(c[0], c[1]))
            if len(ks) > 1 and ks[0] == ks[-1]:
                ks.pop(); ps.pop()
            if len(ks) >= 3:
                anillos.append((ui, ks, np.array(ps)))
    dueno = collections.defaultdict(set)
    for ui, ks, _ in anillos:
        n = len(ks)
        for i in range(n):
            a, b = ks[i], ks[(i + 1) % n]
            dueno[(a, b) if a < b else (b, a)].add(ui)

    def firma(a, b):
        return frozenset(dueno[(a, b) if a < b else (b, a)])

    cache = {}
    salida = collections.defaultdict(list)
    nv_antes = nv_desp = 0
    for ui, ks, ps in anillos:
        n = len(ks)
        nv_antes += n
        nodo = []
        for i in range(n):
            sp = firma(ks[i - 1], ks[i])
            sn = firma(ks[i], ks[(i + 1) % n])
            x = ps[i][0]
            nodo.append(sp != sn or x < 1e-6 or x > 2400 - 1e-6)
        idx = [i for i in range(n) if nodo[i]]
        if len(idx) < 2:
            if not idx:
                idx = [0]
            # segundo ancla: el vértice más alejado del primero
            d = np.hypot(ps[:, 0] - ps[idx[0], 0], ps[:, 1] - ps[idx[0], 1])
            j = int(np.argmax(d))
            idx = sorted(set(idx + [j]))
        nuevo = []
        for t in range(len(idx)):
            s, e = idx[t], idx[(t + 1) % len(idx)]
            seq = list(range(s, e + 1)) if e > s else list(range(s, n)) + list(range(0, e + 1))
            claves = tuple(ks[q] for q in seq)
            inv = claves[::-1]
            canon = claves if claves <= inv else inv
            if canon not in cache:
                pts = np.array([ps[q] for q in seq]) if canon is claves else np.array([ps[q] for q in seq[::-1]])
                keep = dp(pts, eps)
                cache[canon] = pts[keep]
            res = cache[canon]
            if canon is not claves and canon != claves:
                res = res[::-1]
            nuevo.extend(map(tuple, res[:-1]))
        if len(nuevo) < 3:
            continue
        a = 0.0
        for i in range(len(nuevo)):
            x1, y1 = nuevo[i]
            x2, y2 = nuevo[(i + 1) % len(nuevo)]
            a += x1 * y2 - x2 * y1
        if abs(a) / 2 < AREA_MIN:
            continue
        nv_desp += len(nuevo)
        salida[ui].append(nuevo)
    print('vértices', nv_antes, '->', nv_desp, '| arcos', len(cache))

    # ── fuente final agrupada ──
    grupos = collections.OrderedDict()
    for ui, rings in salida.items():
        u = unidades[ui]
        g = grupos.setdefault(u['grupo'], {'u': u, 'rings': []})
        g['rings'].extend(rings)
    fuente = []
    for gid, g in grupos.items():
        u = g['u']
        i0 = info0[u['a3']]
        cont = CONT_ABIERTO.get(u['a3']) or CONT_ES.get(i0['CONTINENT'], 'Asia')
        pais = i0['NAME']
        pes = NOMBRE_PAIS_ES.get(u['a3']) or PAISES_ES.get(pais) or i0.get('NAME_ES') or pais
        polys = [[[round(x, 3), round(y, 3)] for x, y in r] for r in g['rings']]
        xs = [q[0] for r in polys for q in r]
        ys = [q[1] for r in polys for q in r]
        pid = ''.join(ch if ch.isalnum() else '_' for ch in gid).lower()
        fuente.append({'id': pid, 'name': limpiar_nombre(u['gnombre']), 'country': pais, 'country_es': pes, 'a3': u['a3'],
                       'continent': cont, 'center': [round(sum(xs) / len(xs), 1), round(sum(ys) / len(ys), 1)],
                       'polygons': polys})
    # lagos (se dibujan como agua encima de las provincias)
    ruta_l = os.path.join(ne, 'ne_10m_lakes.geojson')
    lagos = []
    if os.path.exists(ruta_l):
        for f in json.load(open(ruta_l, encoding='utf-8'))['features']:
            for r in anillos_de(f['geometry']):
                P = np.array([proyectar(c[0], c[1]) for c in r[:-1]])
                if len(P) < 4:
                    continue
                keep = dp(np.vstack([P, P[:1]]), 0.08)
                Q = np.vstack([P, P[:1]])[keep][:-1]
                if len(Q) < 3:
                    continue
                ar = abs(np.sum(Q[:, 0] * np.roll(Q[:, 1], -1) - np.roll(Q[:, 0], -1) * Q[:, 1])) / 2
                if ar >= 3.0:
                    lagos.append([[round(float(x), 3), round(float(y), 3)] for x, y in Q])
    json.dump(lagos, open(os.path.join(RAIZ, 'datos', 'lagos_fuente.json'), 'w'), separators=(',', ':'))
    print('lagos', len(lagos))
    destino = os.path.join(RAIZ, 'datos', 'fuente_provincias.json')
    json.dump(fuente, open(destino, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('provincias', len(fuente), 'países', len(set(f['a3'] for f in fuente)), '->', destino)


if __name__ == '__main__':
    main()
