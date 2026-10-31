#!/usr/bin/env python3
"""
Genera los datos de mapa para Gran Estrategia v0.1.8 (fuera de Godot) para que el juego cargue rápido y corra fluido.

Uso (desde la carpeta del proyecto):
    python herramientas/construir_mapa.py

Entrada : datos/fuente_provincias.json   (provincias con sus polígonos)
Salida  : datos/malla_*.bin, datos/malla_meta.json, datos/provincias_juego.json, datos/etiquetas.json
Requiere: python3, numpy, scipy, pillow
"""
import json, math, os, sys, hashlib, colorsys, time
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geom import limpiar, dividir_autointersecciones, area_firmada, triangular
from nombres_es import PAISES_ES, PROVINCIAS_ES

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, 'datos')
ANCHO_MAPA = 2400.0
Y_ECUADOR = 580.0

# ───────────────────────── Colores ─────────────────────────
def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

COLOR_CONT = {
    'Europa': hexc('#1d4ed8'), 'Asia': hexc('#dc2626'), 'África': hexc('#eab308'),
    'América del Sur': hexc('#ea580c'), 'América del Norte': hexc('#15803d'),
    'Oceanía': hexc('#7c3aed'), 'Antártida': hexc('#94a3b8'),
}
# (matiz, saturación base, variación de matiz permitida)
BASE_PAIS = {  # ajusta aquí los colores base de cada continente en zoom-in
    'Europa': (0.615, 0.80, 0.040), 'África': (0.125, 0.85, 0.022), 'Asia': (0.995, 0.80, 0.030),
    'América del Sur': (0.070, 0.88, 0.022), 'América del Norte': (0.360, 0.75, 0.040),
    'Oceanía': (0.750, 0.65, 0.035), 'Antártida': (0.580, 0.14, 0.01),
}

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def mezclar_colores(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def color_continental(cont, x, y):
    """
    Campo cromático continuo para el zoom continental.

    La fórmula depende de la posición geográfica y no de una paleta distinta
    para cada lado de una frontera. Por eso dos vértices contiguos reciben
    el mismo color aunque pertenezcan a continentes diferentes.
    """
    # América: verde al norte y naranja al sur, con transición en Centroamérica.
    if cont in ('América del Norte', 'América del Sur'):
        t = smooth(430.0, 610.0, y)
        return mezclar_colores(COLOR_CONT['América del Norte'], COLOR_CONT['América del Sur'], t)

    # Afro-Eurasia: azul europeo -> rojo asiático en dirección oeste-este.
    # África introduce el amarillo desde el sur, con una máscara espacial
    # amplia para que el cambio también se funda a través del Mediterráneo.
    if cont in ('África', 'Europa', 'Asia'):
        t_este = smooth(1350.0, 2050.0, x)
        color_eurasia = mezclar_colores(COLOR_CONT['Europa'], COLOR_CONT['Asia'], t_este)

        peso_oeste_africa = smooth(1000.0, 1120.0, x)
        peso_este_africa = 1.0 - smooth(1400.0, 1530.0, x)
        peso_sur_africa = smooth(390.0, 530.0, y)
        peso_africa = max(0.0, min(1.0,
            peso_oeste_africa * peso_este_africa * peso_sur_africa))

        return mezclar_colores(color_eurasia, COLOR_CONT['África'], peso_africa)

    return COLOR_CONT[cont]

def jitter(txt, n):
    h = hashlib.md5(txt.encode('utf-8')).digest()
    return [h[i] / 127.5 - 1.0 for i in range(n)]

def color_pais(cont, pais, cy, prov_id, es_provincia_extra):
    """Color base estable. El degradado latitudinal se aplica por fragmento en Godot."""
    h, s, dh = BASE_PAIS[cont]
    v = 0.82
    j = jitter(pais, 3)
    h = (h + dh * j[0]) % 1.0
    s = max(0.05, min(1.0, s + 0.12 * j[1] * (s > 0.2)))
    v = max(0.30, min(1.0, v + 0.06 * j[2]))
    if es_provincia_extra:
        v = max(0.30, min(1.0, v + 0.035 * jitter(prov_id, 1)[0]))
    return colorsys.hsv_to_rgb(h, s, v)

# ───────────────────────── Carga ─────────────────────────
def continente_anillo(p, cx, cy):
    c = p['continent']
    pais = p['country']
    nombre = str(p.get('name', '')).lower()
    identificador = str(p.get('id', '')).lower()
    if 'chukchi' in nombre or 'chukotka' in nombre or 'chukchi' in identificador or 'chukotka' in identificador:
        return 'Asia'
    if pais == 'France':
        if cx < 1000 and cy > 450:
            return 'América del Sur'      # Guayana Francesa
        if cx > 1400 and cy > 550:
            return 'África'               # Reunión / Mayotte
        return 'Europa'
    if pais == 'Trinidad and Tobago':
        return 'América del Sur'
    if pais == 'Fr. S. Antarctic Lands':
        return 'Antártida'
    if p['id'] in ('ind_papua', 'ind_papua_barat'):
        return 'Oceanía'
    return c

def grupo(c):
    return 'Eurasia' if c in ('Europa', 'Asia') else c

def main():
    t0 = time.time()
    fuente = json.load(open(os.path.join(DATOS, 'fuente_provincias.json'), encoding='utf-8'))
    cuenta_pais = {}
    for p in fuente:
        cuenta_pais[p['country']] = cuenta_pais.get(p['country'], 0) + 1

    provincias = []   # info de provincias
    anillos = []      # todos los anillos limpios y simples
    for pi, p in enumerate(fuente):
        pais_es = PAISES_ES.get(p['country'], p['country'])
        nom_es = PROVINCIAS_ES.get(p['name'], p['name'])
        if cuenta_pais[p['country']] == 1:
            nom_es = pais_es
        provincias.append({'id': p['id'], 'n': nom_es, 'c': pais_es, 'pais_en': p['country'],
                           'm': cuenta_pais[p['country']] > 1, 'cont': p['continent'], 'r': []})
        for r in p['polygons']:
            pts = limpiar(r)
            if len(pts) < 3:
                continue
            for lazo in dividir_autointersecciones(pts):
                a = area_firmada(lazo)
                if abs(a) < 1e-6:
                    continue
                if a < 0:
                    lazo = lazo[::-1]
                cx = sum(q[0] for q in lazo) / len(lazo)
                cy = sum(q[1] for q in lazo) / len(lazo)
                anillos.append({'pi': pi, 'pts': lazo, 'area': abs(a), 'cont': continente_anillo(p, cx, cy)})
    anillos.sort(key=lambda r: -r['area'])   # grandes primero (los enclaves pequeños quedan encima)
    for ri, r in enumerate(anillos):
        provincias[r['pi']]['r'].append(ri)
    print('anillos', len(anillos), 'provincias', len(provincias), '%.1fs' % (time.time() - t0))

    cont_main_pais = {}
    for r in anillos:                      # ya ordenados: el primero es el anillo más grande
        cont_main_pais.setdefault(provincias[r['pi']]['pais_en'], r['cont'])
    # continente "principal" de cada provincia = el de su anillo más grande
    for pr in provincias:
        pr['cont_main'] = anillos[pr['r'][0]]['cont'] if pr['r'] else pr['cont']

    # ───────────── Triangulación + colores de relleno ─────────────
    V, I, CC, CP = [], [], [], []   # vértices, índices, color continental, color país
    base = 0
    for ri, r in enumerate(anillos):
        pr = provincias[r['pi']]
        pts = r['pts']
        tris, cub = triangular(pts)
        if abs(cub - r['area']) > max(1e-3, r['area'] * 1e-4):
            print('AVISO: triangulación incompleta', pr['id'], r['area'], cub)
        cont_ring = r['cont']
        if cont_ring != cont_main_pais[pr['pais_en']]:
            clave = pr['pais_en'] + '|' + cont_ring
        else:
            clave = pr['pais_en']
        cpais = color_pais(cont_ring, clave, 0.0, pr['id'], pr['m'])
        r['col_pais'] = cpais
        for (x, y) in pts:
            V.append((x, y))
            CC.append(color_continental(cont_ring, x, y))
            CP.append(cpais)
        r['i0'] = len(I)
        for (a, b, c) in tris:
            I.extend((base + a, base + b, base + c))
        r['i1'] = len(I)
        r['v0'] = base
        base += len(pts)
    n_fill_base = base

    # ───────────── Topología de aristas ─────────────
    def key(p):
        return (int(round(p[0] * 10)), int(round(p[1] * 10)))
    aristas = {}
    for ri, r in enumerate(anillos):
        pts = r['pts']
        n = len(pts)
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            ka, kb = key(a), key(b)
            if ka == kb:
                continue
            k = (ka, kb) if ka < kb else (kb, ka)
            aristas.setdefault(k, []).append((ri, r['pi'], a, b))

    def en_costura(a, b):
        return (a[0] <= 0.02 and b[0] <= 0.02) or (a[0] >= ANCHO_MAPA - 0.02 and b[0] >= ANCHO_MAPA - 0.02)

    cats = {'costa': [], 'frontera': [], 'prov': [], 'cont': []}
    agua_v, agua_i, agua_c = [], [], []
    singles = []
    for k, lst in aristas.items():
        provs = []
        for e in lst:
            if e[1] not in [q[1] for q in provs]:
                provs.append(e)
        if len(provs) >= 2:
            e1, e2 = provs[0], provs[1]
            a, b = e1[2], e1[3]
            if en_costura(a, b):
                continue
            p1, p2 = provincias[e1[1]], provincias[e2[1]]
            if p1['pais_en'] != p2['pais_en']:
                cats['frontera'].append((a, b))
            else:
                cats['prov'].append((a, b))
            if grupo(anillos[e1[0]]['cont']) != grupo(anillos[e2[0]]['cont']):
                cats['cont'].append((a, b))
        elif len(lst) == 1:
            singles.append(lst[0])
        # una arista repetida solo dentro de la misma provincia se ignora

    # Aristas "casi compartidas" (vecinos con vértices desalineados, p.ej. España)
    TOL = 0.5
    CELDA = 1.0
    grid = {}
    for si, e in enumerate(singles):
        a, b = e[2], e[3]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        pasos = max(1, int(L / 0.5))
        celdas = set()
        for t in range(pasos + 1):
            x = a[0] + (b[0] - a[0]) * t / pasos
            y = a[1] + (b[1] - a[1]) * t / pasos
            celdas.add((int(x // CELDA), int(y // CELDA)))
        e_cells = celdas
        for c in celdas:
            grid.setdefault(c, []).append(si)

    def dist_pto_seg(px, py, a, b):
        dx, dy = b[0] - a[0], b[1] - a[1]
        l2 = dx * dx + dy * dy
        if l2 == 0:
            return math.hypot(px - a[0], py - a[1])
        t = max(0.0, min(1.0, ((px - a[0]) * dx + (py - a[1]) * dy) / l2))
        return math.hypot(px - (a[0] + t * dx), py - (a[1] + t * dy))

    seal = []   # (ring_index, a, b) aristas que necesitan "sellar" huecos
    for si, e in enumerate(singles):
        a, b = e[2], e[3]
        if en_costura(a, b):
            continue
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        pasos = max(1, int(L / 0.5))
        vecinos = set()
        for t in range(pasos + 1):
            x = a[0] + (b[0] - a[0]) * t / pasos
            y = a[1] + (b[1] - a[1]) * t / pasos
            cx, cy = int(x // CELDA), int(y // CELDA)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    vecinos.update(grid.get((cx + dx, cy + dy), ()))
        cercano = None
        for sj in vecinos:
            if sj == si:
                continue
            f = singles[sj]
            if f[1] == e[1]:
                continue
            fa, fb = f[2], f[3]
            fm = ((fa[0] + fb[0]) / 2, (fa[1] + fb[1]) / 2)
            if dist_pto_seg(mx, my, fa, fb) < TOL or dist_pto_seg(fm[0], fm[1], a, b) < TOL:
                cercano = f
                break
        if cercano is None:
            cats['costa'].append((a, b))
            # Banda de agua: se extiende hacia el exterior del anillo.
            # Los anillos se normalizan a área positiva, por lo que su normal
            # exterior es la perpendicular derecha del segmento.
            if L > 1e-6:
                nx, ny = (b[1] - a[1]) / L, -(b[0] - a[0]) / L
                ancho_agua = 5.0
                base_agua = len(agua_v)
                agua_v.extend([
                    a, b,
                    (a[0] + nx * ancho_agua, a[1] + ny * ancho_agua),
                    (b[0] + nx * ancho_agua, b[1] + ny * ancho_agua)
                ])
                color_orilla = (0.10, 0.30, 0.44)
                color_mar = (0.02, 0.06, 0.13)
                agua_c.extend([color_orilla, color_orilla, color_mar, color_mar])
                agua_i.extend([
                    base_agua, base_agua + 2, base_agua + 1,
                    base_agua + 1, base_agua + 2, base_agua + 3
                ])
        else:
            seal.append((e[0], a, b))
            # dibuja solo una vez (la provincia con índice menor)
            if (e[1], e[0]) < (cercano[1], cercano[0]):
                p1, p2 = provincias[e[1]], provincias[cercano[1]]
                if p1['pais_en'] != p2['pais_en']:
                    cats['frontera'].append((a, b))
                else:
                    cats['prov'].append((a, b))
                if grupo(anillos[e[0]]['cont']) != grupo(anillos[cercano[0]]['cont']):
                    cats['cont'].append((a, b))
    print({k: len(v) for k, v in cats.items()}, 'sellos', len(seal), '%.1fs' % (time.time() - t0))

    # Sellos de hueco: pequeñas franjas con el color del dueño, para que no se vea el océano entre vecinos
    HW_SELLO = 0.20
    for (ri, a, b) in seal:
        r = anillos[ri]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy)
        if L < 1e-6:
            continue
        dx, dy = dx / L, dy / L
        nx, ny = -dy, dx
        quad = [(a[0] - nx * HW_SELLO, a[1] - ny * HW_SELLO), (a[0] + nx * HW_SELLO, a[1] + ny * HW_SELLO),
                (b[0] - nx * HW_SELLO, b[1] - ny * HW_SELLO), (b[0] + nx * HW_SELLO, b[1] + ny * HW_SELLO)]
        b0 = len(V)
        for q in quad:
            V.append(q)
            CC.append(color_continental(r['cont'], q[0], q[1]))
            CP.append(r['col_pais'])
        I.extend((b0, b0 + 1, b0 + 2, b0 + 1, b0 + 3, b0 + 2))

    # ───────────── Mallas de bordes ─────────────
    def malla_borde(segs):
        n = 0
        vs, uvs, ids = [], [], []
        for (a, b) in segs:
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy)
            if L < 1e-6:
                continue
            dx, dy = dx / L, dy / L
            nx, ny = -dy, dx
            base = n * 4
            vs += [a, a, b, b]
            uvs += [(-dx - nx, -dy - ny), (-dx + nx, -dy + ny), (dx - nx, dy - ny), (dx + nx, dy + ny)]
            ids += [base, base + 1, base + 2, base + 1, base + 3, base + 2]
            n += 1
        return (np.array(vs, dtype='<f4').reshape(-1), np.array(uvs, dtype='<f4').reshape(-1),
                np.array(ids, dtype='<i4'))

    meta = {}
    os.makedirs(DATOS, exist_ok=True)
    def guardar(nombre, arr):
        arr.tofile(os.path.join(DATOS, nombre))

    guardar('malla_fill_v.bin', np.array(V, dtype='<f4').reshape(-1))
    guardar('malla_fill_i.bin', np.array(I, dtype='<i4'))
    guardar('malla_fill_cc.bin', (np.array(CC) * 255).round().astype('u1').reshape(-1))
    guardar('malla_fill_cp.bin', (np.array(CP) * 255).round().astype('u1').reshape(-1))
    guardar('malla_agua_v.bin', np.array(agua_v, dtype='<f4').reshape(-1))
    guardar('malla_agua_i.bin', np.array(agua_i, dtype='<i4'))
    guardar('malla_agua_c.bin', (np.array(agua_c) * 255).round().astype('u1').reshape(-1))
    meta['fill'] = {'verts': len(V), 'indices': len(I)}
    meta['agua'] = {'verts': len(agua_v), 'indices': len(agua_i)}
    for cat, segs in cats.items():
        v, uv, ids = malla_borde(segs)
        guardar('malla_%s_v.bin' % cat, v)
        guardar('malla_%s_uv.bin' % cat, uv)
        guardar('malla_%s_i.bin' % cat, ids)
        meta[cat] = {'verts': len(v) // 2, 'indices': len(ids)}
    json.dump(meta, open(os.path.join(DATOS, 'malla_meta.json'), 'w'))
    print('mallas guardadas', meta, '%.1fs' % (time.time() - t0))

    # ───────────── Datos para clic / HUD ─────────────
    out_anillos = []
    for r in anillos:
        xs = [q[0] for q in r['pts']]
        ys = [q[1] for q in r['pts']]
        flat = []
        for q in r['pts']:
            flat += [round(q[0], 2), round(q[1], 2)]
        out_anillos.append({'p': r['pi'], 'k': r['cont'], 'b': [round(min(xs), 2), round(min(ys), 2),
                            round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2)],
                            'v': flat, 'i0': r['i0'], 'i1': r['i1']})
    out_prov = [{'id': p['id'], 'n': p['n'], 'c': p['c'], 'm': p['m'], 'r': p['r']} for p in provincias]
    json.dump({'provincias': out_prov, 'anillos': out_anillos},
              open(os.path.join(DATOS, 'provincias_juego.json'), 'w', encoding='utf-8'), ensure_ascii=False,
              separators=(',', ':'))

    # ───────────── Etiquetas ─────────────
    from etiquetas import generar_etiquetas
    etiquetas = generar_etiquetas(provincias, anillos, PAISES_ES)
    def lum(c):
        return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    for lab in etiquetas:
        if lab['g'] == 'c':
            xm = lab['p'][len(lab['p']) // 2 - (len(lab['p']) // 2) % 2]
            col = color_continental(lab['k'], xm, lab['p'][(len(lab['p']) // 4) * 2 + 1])
        else:
            pi = lab['pi'] if 'pi' in lab else lab['pi0']
            col = anillos[provincias[pi]['r'][0]]['col_pais']
        lab['lc'] = 1 if lum(col) < 0.50 else 0
    json.dump(etiquetas, open(os.path.join(DATOS, 'etiquetas.json'), 'w', encoding='utf-8'), ensure_ascii=False,
              separators=(',', ':'))
    print('etiquetas', len(etiquetas), 'total %.1fs' % (time.time() - t0))

if __name__ == '__main__':
    main()
