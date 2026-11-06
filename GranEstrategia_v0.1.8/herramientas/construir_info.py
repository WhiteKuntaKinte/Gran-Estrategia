#!/usr/bin/env python3
"""
Genera datos/info.json (HUD de provincia / país / continente) y datos/mares.json (clic en océanos y mares).
Todo con base 2026. Fuentes:
  - Natural Earth 10m: ciudades (populated_places), picos (elevation_points), mares (geography_marine_polys), países
  - ETOPO1 (malla de 10 arcmin, repo fatiando-data/earth-topography-10arcmin): altitud
  - WWF ecorregiones reclasificadas (repo dmcglinn/wwf_biome, mapa de biomas): bioma / vegetación
  - Banco Mundial (repo datasets/population): población 2025 -> estimación 2026
Uso: python herramientas/construir_info.py RUTA_NE RUTA_ETOPO_XZ RUTA_BIOMAS_PNG RUTA_BIOMAS_CLAVE_CSV RUTA_POBLACION_CSV
Requiere: numpy, scipy, opencv-python, pillow
"""
import json, os, sys, math, lzma, csv, collections
import numpy as np
import cv2
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tablas_info import BIOMAS, REINOS, FAUNA_G, GRUPO_BIOMA, ETNIAS

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, 'datos')
W, H = 4800, 2400                      # raster de provincias (0.075° por píxel)
CALIB = (12.028054856, 2244.816424570, 12.048409952, 1299.329786170)   # mapa de biomas: px/° lon, offset x, px/° lat, offset y
CRE_2026 = 1.0                          # factor aplicado a la población 2025 si no hay serie (se usa crecimiento 2024->2025)
KM_GRADO = 111.2
NIV_M = [0, 200, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]


def cargar_etopo(ruta):
    txt = lzma.open(ruta, 'rt').read()
    i = txt.index('end_of_head')
    cuerpo = txt[txt.index('\n', i) + 1:]
    a = np.fromstring(cuerpo, sep=' ').reshape(-1, 3)
    lat = np.unique(a[:, 1])[::-1]
    lon = np.unique(a[:, 0])
    return a[:, 2].reshape(len(lat), len(lon)).astype(np.float32)


def muestrear_etopo(Z, lon, lat):
    fx = (lon + 180.0) / (1.0 / 6.0)
    fy = (90.0 - lat) / (1.0 / 6.0)
    return ndimage.map_coordinates(Z, [fy, fx], order=1, mode='nearest')


def area_esferica(ring):
    """km² de un anillo lon/lat (fórmula de polígono esférico)."""
    a = np.radians(np.array(ring, dtype=float))
    lam, phi = a[:, 0], a[:, 1]
    lam2, phi2 = np.roll(lam, -1), np.roll(phi, -1)
    d = lam2 - lam
    d = (d + np.pi) % (2 * np.pi) - np.pi
    s = np.sum(d * (2 + np.sin(phi) + np.sin(phi2)))
    return abs(s) * 6371.0 ** 2 / 2.0


def main():
    ne, ruta_etopo, ruta_bio, ruta_clave, ruta_pob = sys.argv[1:6]
    pj = json.load(open(os.path.join(DATOS, 'provincias_juego.json'), encoding='utf-8'))
    provincias, anillos = pj['provincias'], pj['anillos']
    fuente = json.load(open(os.path.join(DATOS, 'fuente_provincias.json'), encoding='utf-8'))
    NP = len(provincias)
    V = np.fromfile(os.path.join(DATOS, 'malla_fill_v.bin'), '<f4').reshape(-1, 2)
    I = np.fromfile(os.path.join(DATOS, 'malla_fill_i.bin'), '<i4').reshape(-1, 3)

    # ── 1) raster de provincias + área exacta ──
    ids = np.full((H, W), -1, np.int32)
    P = np.round(V * (W / 2400.0) * 16).astype(np.int32)
    area = np.zeros(NP)
    for a in anillos:
        pi = a['p']
        for t in range(a['i0'] // 3, a['i1'] // 3):
            tri = I[t]
            cv2.fillConvexPoly(ids, P[tri], pi, lineType=cv2.LINE_8, shift=4)
            p0, p1, p2 = V[tri[0]], V[tri[1]], V[tri[2]]
            ar = abs((p1[0] - p0[0]) * (p2[1] - p0[1]) - (p1[1] - p0[1]) * (p2[0] - p0[0])) / 2.0
            lat = 90.0 - (p0[1] + p1[1] + p2[1]) / 3.0 * 0.15
            area[pi] += ar * (0.15 * KM_GRADO) ** 2 * math.cos(math.radians(lat))
    print('raster listo; cubierto %.1f%%' % (100.0 * (ids >= 0).mean()))
    tierra = ids >= 0
    yy, xx = np.nonzero(tierra)
    lon = (xx + 0.5) / W * 360.0 - 180.0
    lat = 90.0 - (yy + 0.5) / H * 180.0
    pid = ids[yy, xx]

    # centroides (lon, lat) por provincia desde el raster
    cnt = np.bincount(pid, minlength=NP).astype(float)
    cx = np.bincount(pid, weights=lon, minlength=NP) / np.maximum(cnt, 1)
    cy = np.bincount(pid, weights=lat, minlength=NP) / np.maximum(cnt, 1)
    for pi in np.flatnonzero(cnt == 0):          # provincias diminutas: usa su anillo
        a = anillos[provincias[pi]['r'][0]]
        v = V[a['v0']:a['v0'] + a['n']]
        cx[pi] = v[:, 0].mean() * 0.15 - 180.0
        cy[pi] = 90.0 - v[:, 1].mean() * 0.15

    # ── 2) altitud (ETOPO + picos de Natural Earth) ──
    Z = cargar_etopo(ruta_etopo)
    zs = np.maximum(muestrear_etopo(Z, lon, lat), 0.0)
    alt_sum = np.bincount(pid, weights=zs, minlength=NP)
    alt_med = alt_sum / np.maximum(cnt, 1)
    alt_max = np.zeros(NP)
    np.maximum.at(alt_max, pid, zs)
    for pi in np.flatnonzero(cnt == 0):
        z = max(float(muestrear_etopo(Z, np.array([cx[pi]]), np.array([cy[pi]]))[0]), 0.0)
        alt_med[pi] = alt_max[pi] = z
    for f in json.load(open(os.path.join(ne, 'ne_10m_geography_regions_elevation_points.geojson'), encoding='utf-8'))['features']:
        p = f['properties']
        if not p.get('elevation'):
            continue
        x = int((p['long_x'] + 180.0) / 360.0 * W) % W
        y = min(H - 1, max(0, int((90.0 - p['lat_y']) / 180.0 * H)))
        k = ids[y, x]
        if k >= 0:
            alt_max[k] = max(alt_max[k], float(p['elevation']))
    print('altitud lista')

    # ── 3) biomas ──
    clave = list(csv.DictReader(open(ruta_clave, encoding='utf-8')))
    codigos = [r['Code'] for r in clave if r['Code'] in BIOMAS]
    colores = np.array([[int(r['Color'][i:i + 2], 16) for i in (1, 3, 5)] for r in clave if r['Code'] in BIOMAS], float)
    img = np.array(Image.open(ruta_bio).convert('RGB')).astype(np.float32)
    h, w, _ = img.shape
    cls = np.full((h, w), -1, np.int8)
    best = np.full((h, w), 1e9, np.float32)
    for k, c in enumerate(colores):
        d = ((img - c) ** 2).sum(2)
        m = d < best
        best[m] = d[m]
        cls[m] = k
    cls[best > 30 ** 2] = -1                              # blanco / borde / antialias -> sin dato
    cls[:, -40:] = -1
    dist, (iy, ix) = ndimage.distance_transform_edt(cls < 0, return_indices=True)
    cls_f = cls[iy, ix]
    sx, ox, sy, oy = CALIB
    u = np.clip(np.round(lon * sx + ox).astype(int), 0, w - 1)
    v = np.clip(np.round(-lat * sy + oy).astype(int), 0, h - 1)
    b = cls_f[v, u].astype(int)
    lejos = dist[v, u] > 60                                # >5° del dato más cercano: islas remotas
    ib = {c: i for i, c in enumerate(codigos)}
    reglas = np.where(np.abs(lat) > 62, ib['TUN'], np.where(np.abs(lat) < 25, ib['TEF'], ib['WTF']))
    b = np.where(lejos, reglas, b)
    hielo = (b == ib['TUN']) & (np.abs(lat) > 60) & (zs > 1200)
    nb = len(codigos) + 1
    b = np.where(hielo, len(codigos), b)                    # índice len(codigos) = ICE
    codigos = codigos + ['ICE']
    tabla = np.bincount(pid * nb + b, minlength=NP * nb).reshape(NP, nb)
    for pi in np.flatnonzero(cnt == 0):
        u0 = int(np.clip(round(cx[pi] * sx + ox), 0, w - 1))
        v0 = int(np.clip(round(-cy[pi] * sy + oy), 0, h - 1))
        tabla[pi, int(cls_f[v0, u0])] = 1
    print('biomas listos')

    # ── 4) reino biogeográfico por provincia ──
    def reino(pi):
        cm = anillos[provincias[pi]['r'][0]]['k'] if provincias[pi]['r'] else 'Asia'
        lo, la = cx[pi], cy[pi]
        if cm == 'Antártida' or la < -62:
            return 'ANT'
        if cm == 'América del Sur':
            return 'NEO'
        if cm == 'América del Norte':
            return 'NEO' if (la < 23.5 and lo < -60) else 'NEA'
        if cm == 'Europa':
            return 'PAL'
        if cm == 'África':
            return 'AFR' if la < 18 else 'PAL'
        if cm == 'Oceanía':
            return 'AUS'
        if lo > 118 and la < -1 or (lo > 130 and la < 3):
            return 'AUS'
        if la < 27 and lo > 60:
            return 'IND'
        if la < 31 and 30 < lo < 60 and fuente[pi].get('a3') in ('YEM', 'OMN', 'ARE', 'QAT', 'BHR', 'KWT', 'SAU'):
            return 'AFR' if la < 18 else 'PAL'
        return 'PAL'

    # ── 5) población 2026 ──
    pop = collections.defaultdict(dict)
    for r in csv.DictReader(open(ruta_pob, encoding='utf-8')):
        if r['Year'] in ('2024', '2025'):
            pop[r['Country Code']][r['Year']] = float(r['Value'])
    a0 = json.load(open(os.path.join(ne, 'ne_10m_admin_0_countries.geojson'), encoding='utf-8'))['features']
    pop_pais = {}
    for f in a0:
        p = f['properties']
        a3 = p['ADM0_A3']
        pob = None
        for k in (p.get('WB_A3'), p.get('ISO_A3_EH'), p.get('ISO_A3'), a3):
            if k and k in pop and '2025' in pop[k]:
                d = pop[k]
                g = d['2025'] / d['2024'] if '2024' in d and d['2024'] > 0 else 1.0
                g = min(max(g, 0.97), 1.04)
                pob = d['2025'] * g
                break
        if pob is None:
            pob = float(p['POP_EST']) * 1.07            # NE (2019) -> 2026
        pop_pais[a3] = pob
    ciudades = json.load(open(os.path.join(ne, 'ne_10m_populated_places.geojson'), encoding='utf-8'))['features']
    _, (ky, kx) = ndimage.distance_transform_edt(~tierra, return_indices=True)
    peso = np.zeros(NP)
    for f in ciudades:
        c = f['geometry']['coordinates']
        x = int((c[0] + 180.0) / 360.0 * W) % W
        y = min(H - 1, max(0, int((90.0 - c[1]) / 180.0 * H)))
        yy2, xx2 = ky[y, x], kx[y, x]
        k = ids[yy2, xx2]
        if k >= 0 and (abs(yy2 - y) + abs(xx2 - x)) < 40:
            peso[k] += max(f['properties']['POP_MAX'], 1000)
    por_pais = collections.defaultdict(list)
    for pi, fu in enumerate(fuente):
        por_pais[fu['a3']].append(pi)
    pob_prov = np.zeros(NP)
    for a3, lista in por_pais.items():
        tot = pop_pais.get(a3, 0.0)
        w_ = np.array([peso[pi] + 0.02 * area[pi] + 50 for pi in lista])
        pob_prov[lista] = tot * w_ / w_.sum()
    print('población lista: mundo %.2f mil millones' % (pob_prov.sum() / 1e9))

    # ── 6) ensamblar ──
    def bio_lista(fila, topn=3):
        tot = fila.sum()
        if tot == 0:
            return []
        orden = np.argsort(-fila)[:topn]
        return [[codigos[i], round(100.0 * fila[i] / tot)] for i in orden if fila[i] / tot >= 0.12]

    prov_out = []
    for pi in range(NP):
        bl = bio_lista(tabla[pi])
        prov_out.append([int(round(pob_prov[pi])), int(round(area[pi])), int(round(alt_med[pi])), int(round(alt_max[pi])),
                         bl, reino(pi)])
    pais_acc = {}
    for pi, pr in enumerate(provincias):
        nm = pr['c']
        d = pais_acc.setdefault(nm, {'pob': 0, 'area': 0.0, 'alt_sum': 0.0, 'alt_max': 0.0, 'tabla': np.zeros(nb),
                                     'a3': fuente[pi]['a3'], 'cont': None, 'reinos': collections.Counter()})
        d['pob'] += pob_prov[pi]
        d['area'] += area[pi]
        d['alt_sum'] += alt_med[pi] * area[pi]
        d['alt_max'] = max(d['alt_max'], alt_max[pi])
        d['tabla'] += tabla[pi]
        d['reinos'][prov_out[pi][5]] += area[pi]
        for ri_ in pr['r']:                                   # superficie (caja) de anillos por continente
            b_ = anillos[ri_]['b']
            d.setdefault('sup_cont', {})
            d['sup_cont'][anillos[ri_]['k']] = d['sup_cont'].get(anillos[ri_]['k'], 0.0) + max(b_[2] * b_[3], 0.01)
    pais_out = {}
    cont_acc = {}
    for nm, d in pais_acc.items():
        d['cont'] = max(d['sup_cont'].items(), key=lambda q: q[1])[0]       # continente DOMINANTE (Francia era «América del Sur» por la Guayana)
        a3 = d['a3']
        etn = ETNIAS.get(a3)
        pais_out[nm] = {'pob': int(round(d['pob'])), 'area': int(round(d['area'])),
                        'alt': int(round(d['alt_sum'] / max(d['area'], 1))), 'altmax': int(round(d['alt_max'])),
                        'bio': bio_lista(d['tabla']), 'reino': d['reinos'].most_common(1)[0][0], 'cont': d['cont'],
                        'etn': [[g, p] for g, p in etn] if etn else []}
        c = cont_acc.setdefault(d['cont'], {'pob': 0, 'area': 0.0, 'alt_sum': 0.0, 'alt_max': 0.0, 'tabla': np.zeros(nb),
                                            'reinos': collections.Counter(), 'paises': 0})
        c['pob'] += d['pob']
        c['area'] += d['area']
        c['alt_sum'] += d['alt_sum']
        c['alt_max'] = max(c['alt_max'], d['alt_max'])
        c['tabla'] += d['tabla']
        c['reinos'].update(d['reinos'])
        c['paises'] += 1
    cont_out = {k: {'pob': int(round(c['pob'])), 'area': int(round(c['area'])), 'alt': int(round(c['alt_sum'] / max(c['area'], 1))),
                    'altmax': int(round(c['alt_max'])), 'bio': bio_lista(c['tabla'], 4),
                    'reino': c['reinos'].most_common(1)[0][0], 'paises': c['paises']} for k, c in cont_acc.items()}
    biomas = {}
    for c in codigos:
        nombre, flora = BIOMAS[c]
        g = GRUPO_BIOMA[c]
        biomas[c] = {'n': nombre, 'flora': flora, 'fauna': FAUNA_G[g]}
    json.dump({'anio': 2026, 'prov': prov_out, 'pais': pais_out, 'cont': cont_out, 'biomas': biomas, 'reinos': REINOS,
               'niv_m': NIV_M}, open(os.path.join(DATOS, 'info.json'), 'w', encoding='utf-8'), ensure_ascii=False,
              separators=(',', ':'))
    print('info.json: provincias', len(prov_out), 'países', len(pais_out), 'continentes', len(cont_out))

    # ── 7) mares ──
    prof = np.fromfile(os.path.join(DATOS, 'profundidad.bin'), 'u1').reshape(2048, 4096, 2)
    tier = prof[..., 0].astype(np.float32) / 255.0 * 11.0
    metros = np.interp(tier, np.arange(12), NIV_M)
    agua = ~((prof[..., 0] == 0) & (prof[..., 1] == 0))
    TIPO = {'ocean': 'Océano', 'sea': 'Mar', 'gulf': 'Golfo', 'bay': 'Bahía', 'strait': 'Estrecho', 'sound': 'Estrecho / seno',
            'channel': 'Canal', 'generic': 'Zona marítima', 'lagoon': 'Laguna', 'fjord': 'Fiordo', 'river': 'Estuario',
            'reef': 'Arrecife', 'inlet': 'Ensenada'}
    lat_f = 90.0 - (np.arange(2048) + 0.5) / 2048.0 * 180.0
    km2_fila = np.cos(np.radians(lat_f)) * (180.0 / 2048.0 * KM_GRADO) ** 2
    mares = []
    for f in json.load(open(os.path.join(ne, 'ne_10m_geography_marine_polys.geojson'), encoding='utf-8'))['features']:
        p = f['properties']
        g = f['geometry']
        polys = [g['coordinates']] if g['type'] == 'Polygon' else g['coordinates']
        m = np.zeros((2048, 4096), np.uint8)
        km2 = 0.0
        out_r = []
        for poly in polys:
            for k, r in enumerate(poly):
                a = np.array(r)
                pts = np.round(np.stack([(a[:, 0] + 180) / 360 * 4096, (90 - a[:, 1]) / 180 * 2048], 1) * 16).astype(np.int32)
                cv2.fillPoly(m, [pts], 1 if k == 0 else 0, shift=4)
                km2 += area_esferica(r) * (1 if k == 0 else -1)
            ext = np.array(poly[0])
            xy = np.stack([(ext[:, 0] + 180) / 360 * 2400, (90 - ext[:, 1]) / 180 * 1200], 1)
            xy = cv2.approxPolyDP(xy.astype(np.float32).reshape(-1, 1, 2), 0.25, True).reshape(-1, 2)
            if len(xy) >= 3:
                out_r.append([round(float(q), 1) for q in xy.reshape(-1)])
        sel = (m == 1) & agua
        if sel.sum() > 0:
            km2 = float((sel * km2_fila[:, None]).sum())
            pmax, pmed = float(metros[sel].max()), float(metros[sel].mean())
        else:
            pmax = pmed = 0.0
        nombre = p.get('name_es') or p.get('name') or p.get('label') or 'Mar sin nombre'
        nombre = nombre[:1].upper() + nombre[1:]
        if p['featurecla'] == 'ocean':
            en = (p.get('name') or '').lower()
            if en.startswith('north') and 'Norte' not in nombre:
                nombre += ' Norte'
            elif en.startswith('south') and 'Sur' not in nombre and 'Antártico' not in nombre:
                nombre += ' Sur'
        if not out_r:
            continue
        xs = [q for r in out_r for q in r[0::2]]
        ys = [q for r in out_r for q in r[1::2]]
        mares.append({'n': nombre, 't': TIPO.get(p['featurecla'], 'Mar'), 'a': int(round(km2)),
                      'pmax': int(round(pmax, -1)), 'pmed': int(round(pmed, -1)),
                      'b': [round(min(xs), 1), round(min(ys), 1), round(max(xs) - min(xs), 1), round(max(ys) - min(ys), 1)],
                      'r': out_r})
    mares.sort(key=lambda s: s['a'])
    json.dump(mares, open(os.path.join(DATOS, 'mares.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('mares.json', len(mares))


if __name__ == '__main__':
    main()
