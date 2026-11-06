#!/usr/bin/env python3
"""
construir_epoca.py — Genera el paquete de datos del escenario «año 1 d. C.» (datos/epocas/1dc/).

El escenario NO es un mapa aparte: es el mismo juego con otros datos de partida. Este script toma las provincias de hoy
(datos/fuente_provincias.json) y las RECORTA con los territorios de la época:
  · estados: polígonos de Cliopatria v0.2.1 (Seshat Global History Databank, CC BY 4.0) → fuentes/cliopatria_anio1.json
  · pueblos y culturas sin estado: zonas dibujadas a mano → datos_1dc_pueblos_a.py y datos_1dc_pueblos_b.py
  · lo que nadie reclama queda como «Tierras sin reclamar» (sin nombre, sin población, sin ejército)
Después reutiliza los generadores de siempre (construir_mapa.py, construir_vecinos.py, construir_ids.py) con GE_DATOS apuntando
al escenario, y escribe el resto de los archivos que el juego lee (info, entidades, ciudades, economía, divisas, banderas, ejército).

Uso:   python3 -I herramientas/epoca/construir_epoca.py [--godot RUTA_GODOT] [--build CARPETA_TEMP] [--out CARPETA_SALIDA]
Requiere: python3, numpy, scipy, pillow y un ejecutable de Godot 4 (solo para el recorte de polígonos, que usa Geometry2D).
"""
import colorsys
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time

import numpy as np
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
HERR = os.path.dirname(AQUI)
RAIZ = os.path.dirname(HERR)
sys.path.insert(0, AQUI)
sys.path.insert(0, HERR)

import datos_1dc_estados as DE                     # noqa: E402
import datos_1dc_pueblos_b                         # noqa: E402,F401  (registra todos los pueblos)
from datos_1dc_pueblos_a import PUEBLOS            # noqa: E402
from datos_1dc_ciudades import CIUDADES            # noqa: E402

ESC = 2400.0 / 360.0
BASE = os.path.join(RAIZ, 'datos')
ANIO = 1
PREFIJO = 'e1_'                                     # prefijo de las banderas generadas (banderas/e1_*.png)

PALETA = ['b8463c', 'd9a13a', '4f9d69', '4a78b5', '8e5aa8', 'c97a3a', '2f8f8a', 'a3475f', '7f9b3f', '5d6fa8', 'c2584b', 'd4b44a',
          '3f8f5b', '6a8fd0', 'b06ab3', 'd18b52', '3aa0a0', 'bd5f78', '95ad4a', '7d84c2', 'cf6f5a', 'c9a345', '5aa578', '5c9bd1',
          '9d6dbd', 'dd9360', '4fb5ad', 'c46b86', 'a8bd5d', '8a93d6']
FIJOS = {'Roman Empire': '9b2c3c', 'Han Dynasty': 'd8a52a', 'Parthian Empire': '3d7f58', 'Xiongnu': '7c8794'}


def slug(txt):
    import unicodedata
    t = unicodedata.normalize('NFKD', txt).encode('ascii', 'ignore').decode().lower()
    return ''.join(ch if ch.isalnum() else '_' for ch in t).strip('_')


def px(lon, lat):
    return [round((lon + 180.0) * ESC, 4), round((90.0 - lat) * ESC, 4)]


# ───────────────────── Bordes con forma natural ─────────────────────
# Los pueblos dibujados a mano tienen lados rectos; en la realidad una frontera cultural sigue ríos, sierras y costas. Cada lado se
# parte por la mitad una y otra vez, desplazando el punto medio hacia un lado o al otro (desplazamiento del punto medio, determinista:
# el desplazamiento sale de un hash de los dos extremos, así que dos pueblos que comparten un lado lo ondulan igual y no se abren huecos).
ONDA_AMP = 0.16          # desplazamiento máximo del primer corte, como fracción de la longitud del lado
ONDA_DECAE = 0.85        # cuánto baja esa fracción en cada nivel
ONDA_LMIN = 2.2          # px: no se parte un trozo más corto que esto
ONDA_NIVELES = 6


def _hash2(a, b):
    h = hashlib.md5(('%.2f,%.2f|%.2f,%.2f' % (a[0], a[1], b[0], b[1])).encode()).digest()
    return h[0] / 127.5 - 1.0


def _punto_medio(a, b, amp, niv):
    """Puntos interiores del lado a→b (sin a ni b)."""
    if niv <= 0:
        return []
    if (a[0], a[1]) > (b[0], b[1]):
        return _punto_medio(b, a, amp, niv)[::-1]
    L = math.hypot(b[0] - a[0], b[1] - a[1])
    if L < ONDA_LMIN:
        return []
    h = _hash2(a, b)
    nx, ny = -(b[1] - a[1]) / L, (b[0] - a[0]) / L
    m = [(a[0] + b[0]) / 2 + nx * h * amp * L, (a[1] + b[1]) / 2 + ny * h * amp * L]
    return _punto_medio(a, m, amp * ONDA_DECAE, niv - 1) + [m] + _punto_medio(m, b, amp * ONDA_DECAE, niv - 1)


def _es_simple(pts):
    """¿El polígono no se corta a sí mismo? (comprobación vectorizada de todos los pares de lados)"""
    P = np.asarray(pts, dtype=float)
    n = len(P)
    A = P
    B = np.roll(P, -1, axis=0)
    for i in range(n):
        a, b = A[i], B[i]
        d1 = (B[:, 0] - A[:, 0]) * (a[1] - A[:, 1]) - (B[:, 1] - A[:, 1]) * (a[0] - A[:, 0])
        d2 = (B[:, 0] - A[:, 0]) * (b[1] - A[:, 1]) - (B[:, 1] - A[:, 1]) * (b[0] - A[:, 0])
        d3 = (b[0] - a[0]) * (A[:, 1] - a[1]) - (b[1] - a[1]) * (A[:, 0] - a[0])
        d4 = (b[0] - a[0]) * (B[:, 1] - a[1]) - (b[1] - a[1]) * (B[:, 0] - a[0])
        cruza = (d1 * d2 < 0) & (d3 * d4 < 0)
        cruza[i] = False
        cruza[(i - 1) % n] = False
        cruza[(i + 1) % n] = False
        if cruza.any():
            return False
    return True


def ondular(parte):
    for amp in (ONDA_AMP, ONDA_AMP * 0.5, ONDA_AMP * 0.25):
        nuevo = []
        n = len(parte)
        for i in range(n):
            a, b = parte[i], parte[(i + 1) % n]
            nuevo.append(a)
            nuevo.extend(_punto_medio(a, b, amp, ONDA_NIVELES))
        nuevo = [[round(x, 4), round(y, 4)] for x, y in nuevo]
        if _es_simple(nuevo):
            return nuevo
    return parte


def area_poly(pts):
    a = 0.0
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        a += x1 * y2 - x2 * y1
    return a / 2.0


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def correr(cmd, env=None, etiqueta=''):
    t0 = time.time()
    r = subprocess.run(cmd, env=env, capture_output=True, text=True)
    sal = (r.stdout or '') + (r.stderr or '')
    if r.returncode != 0:
        print(sal[-3000:])
        raise SystemExit('falló ' + (etiqueta or ' '.join(cmd[:3])))
    print('  ✓ %s (%.1f s)' % (etiqueta or cmd[1], time.time() - t0))
    return sal


# ───────────────────────── 1. Territorios de la época ─────────────────────────
def territorios():
    """Lista de entidades con sus polígonos en coordenadas del mapa, en orden de prioridad (primero los más pequeños)."""
    clio = json.load(open(os.path.join(AQUI, 'fuentes', 'cliopatria_anio1.json'), encoding='utf-8'))
    estados = []
    for pol in clio['politicas']:
        if pol['nombre'] not in DE.ESTADOS:
            print('  AVISO: estado de Cliopatria sin ficha:', pol['nombre'])
            continue
        d = dict(DE.ESTADOS[pol['nombre']])
        d['clave'] = pol['nombre']
        d['fuente'] = 'Cliopatria'
        d['partes'] = [[px(x, y) for x, y in parte] for parte in pol['partes']]
        d['es_estado'] = True
        estados.append(d)
    pueblos = []
    for p in PUEBLOS:
        d = dict(p)
        d['partes'] = [ondular([px(x, y) for x, y in parte]) for parte in p['partes']]
        d['fuente'] = 'dibujado a mano'
        d['es_estado'] = False
        pueblos.append(d)
    for d in estados + pueblos:
        d['area_px'] = sum(abs(area_poly(parte)) for parte in d['partes'])
    estados.sort(key=lambda d: d['area_px'])
    pueblos.sort(key=lambda d: d['area_px'])
    return estados + pueblos


def recortar(ents, build, godot):
    proy = tempfile.mkdtemp(prefix='recorte_')
    open(os.path.join(proy, 'project.godot'), 'w').write('config_version=5\n[application]\nconfig/name="recorte"\n')
    shutil.copy(os.path.join(AQUI, 'recortar_epoca.gd'), os.path.join(proy, 'recortar_epoca.gd'))
    terr = os.path.join(build, 'territorios.json')
    json.dump({'entidades': [{'clave': e['clave'], 'partes': e['partes']} for e in ents]}, open(terr, 'w'), separators=(',', ':'))
    salida = os.path.join(build, 'piezas.json')
    sal = correr([godot, '--headless', '--path', proy, '--script', 'res://recortar_epoca.gd', '--',
                  os.path.join(BASE, 'fuente_provincias.json'), terr, salida], etiqueta='recorte con Geometry2D')
    for l in sal.splitlines():
        if 'recortar_epoca' in l:
            print('   ', l.strip())
    shutil.rmtree(proy, ignore_errors=True)
    return json.load(open(salida, encoding='utf-8'))


# ───────────────────────── 2. Provincias nuevas ─────────────────────────
def nombre_sin_reclamar(cont):
    return 'Tierras sin reclamar de ' + {'Europa': 'Europa', 'Asia': 'Asia', 'África': 'África', 'América del Norte': 'América del Norte',
                                         'América del Sur': 'América del Sur', 'Oceanía': 'Oceanía', 'Antártida': 'la Antártida'}.get(cont, cont)


AREA_AGRUPAR = 70.0          # px² (≈ 19.500 km²): las provincias de hoy más pequeñas que esto se agrupan con vecinas del mismo territorio
AREA_AGRUPAR_VACIO = 450.0   # px²: las tierras sin reclamar no necesitan detalle (no juegan): se agrupan mucho más


def agrupar(items, minimos):
    """Agrupa piezas pequeñas con una vecina del mismo territorio (y del mismo continente si no es de nadie) hasta llegar al mínimo.
    Vecina = comparte al menos 2 vértices (redondeados a 0,2 px). Se funde la más pequeña primero con la vecina más pequeña,
    para que los tamaños queden parejos. Cada item es un dict con a (área), e (territorio), c (continente) y r (anillos)."""
    import heapq
    n = len(items)
    donde = {}
    for i, it in enumerate(items):
        ks = set()
        for r in it['r']:
            for x, y in r:
                ks.add((int(round(x * 5)), int(round(y * 5))))
        for k in ks:
            donde.setdefault(k, []).append(i)
    nb = [dict() for _ in range(n)]
    for lst in donde.values():
        if len(lst) < 2 or len(lst) > 8:
            continue
        for i in lst:
            for j in lst:
                if i != j and items[i]['e'] == items[j]['e'] and (items[i]['e'] != '' or items[i]['c'] == items[j]['c']):
                    nb[i][j] = nb[i].get(j, 0) + 1
    del donde
    vivo = [True] * n
    heap = [(items[i]['a'], i) for i in range(n) if items[i]['a'] < minimos(items[i])]
    heapq.heapify(heap)
    fundidos = 0
    while heap:
        a, i = heapq.heappop(heap)
        if not vivo[i] or abs(a - items[i]['a']) > 1e-9:
            continue
        cand = [(items[j]['a'], -c, j) for j, c in nb[i].items() if vivo[j] and c >= 2]
        if not cand:
            cand = [(items[j]['a'], -c, j) for j, c in nb[i].items() if vivo[j]]
        if not cand:
            continue
        cand.sort()
        j = cand[0][2]
        it_i, it_j = items[i], items[j]
        if it_i['amax'] > it_j['amax']:                       # el nombre y el padre los pone el miembro mayor
            it_j['padre'], it_j['sub'], it_j['amax'], it_j['nombre'], it_j['id'] = it_i['padre'], it_i['sub'], it_i['amax'], it_i['nombre'], it_i['id']
            it_j['c'] = it_i['c'] if it_i['e'] != '' else it_j['c']
        it_j['r'] += it_i['r']
        it_j['rp'] += it_i['rp']                              # provincia de hoy de la que sale cada anillo (para las celdas)
        it_j['conts'] += it_i['conts']
        it_j['miembros'] += it_i['miembros']
        it_j['a'] += it_i['a']
        vivo[i] = False
        for k, c in nb[i].items():
            if k == j or not vivo[k]:
                continue
            nb[k].pop(i, None)
            nb[k][j] = nb[k].get(j, 0) + c
            nb[j][k] = nb[j].get(k, 0) + c
        nb[j].pop(i, None)
        nb[i] = {}
        fundidos += 1
        if it_j['a'] < minimos(it_j):
            heapq.heappush(heap, (it_j['a'], j))
    print('   agrupación: %d piezas → %d (%d fundidas)' % (n, sum(vivo), fundidos))
    return [it for it, v in zip(items, vivo) if v]


def nodar(nuevas, eps=0.03):
    """Uniones en T: si el vértice de un anillo cae sobre la arista de otro (o del mismo provincia), se inserta en esa arista.
    Tras el recorte, las piezas vecinas se parten en puntos distintos de su borde común y construir_mapa.py no reconoce esas aristas como compartidas
    (las dibujaría como COSTA en medio de un país). Con los mismos vértices a ambos lados, la arista queda compartida y desaparece."""
    CELDA = 1.0
    celdas = {}
    for p in nuevas:
        for r in p['polygons']:
            for x, y in r:
                celdas.setdefault((int(x // CELDA), int(y // CELDA)), set()).add((x, y))
    insertados = 0
    for p in nuevas:
        for ri, r in enumerate(p['polygons']):
            n = len(r)
            salida = []
            for i in range(n):
                a, b = r[i], r[(i + 1) % n]
                salida.append(a)
                dx, dy = b[0] - a[0], b[1] - a[1]
                L2 = dx * dx + dy * dy
                if L2 < 1e-12:
                    continue
                L = math.sqrt(L2)
                pasos = max(1, int(L / 0.5))
                cand = set()
                vistas = set()
                for t in range(pasos + 1):
                    cx, cy = int((a[0] + dx * t / pasos) // CELDA), int((a[1] + dy * t / pasos) // CELDA)
                    if (cx, cy) in vistas:
                        continue
                    vistas.add((cx, cy))
                    for ddx in (-1, 0, 1):
                        for ddy in (-1, 0, 1):
                            c = celdas.get((cx + ddx, cy + ddy))
                            if c:
                                cand.update(c)
                dentro = []
                for v in cand:
                    if (v[0] == a[0] and v[1] == a[1]) or (v[0] == b[0] and v[1] == b[1]):
                        continue
                    tt = ((v[0] - a[0]) * dx + (v[1] - a[1]) * dy) / L2
                    if tt * L <= eps or (1.0 - tt) * L <= eps:
                        continue
                    if abs((v[0] - a[0]) * dy - (v[1] - a[1]) * dx) / L < eps:
                        dentro.append((tt, v))
                if dentro:
                    dentro.sort()
                    ult = None
                    for tt, v in dentro:
                        if ult is not None and abs(v[0] - ult[0]) < 1e-9 and abs(v[1] - ult[1]) < 1e-9:
                            continue
                        salida.append([v[0], v[1]])
                        ult = v
                        insertados += 1
            p['polygons'][ri] = salida
    print('   nodado: %d vértices insertados en aristas vecinas' % insertados)


def construir_fuente(ents, piezas, build):
    import construir_mapa as CM
    base = json.load(open(os.path.join(BASE, 'fuente_provincias.json'), encoding='utf-8'))
    juego = json.load(open(os.path.join(BASE, 'provincias_juego.json'), encoding='utf-8'))['provincias']
    nombre_de = {e['clave']: e['nombre'] for e in ents}
    # Lo que un territorio conserva de su tierra tras ceder ante otros de más prioridad. Si casi no le queda (< 3 px² ≈ 800 km²) deja de
    # existir como nación (sus trozos pasan a tierras sin reclamar); si no, su población se reduce en proporción a lo conservado.
    final = {}
    for pz in piezas['piezas']:
        if pz['e']:
            final[pz['e']] = final.get(pz['e'], 0.0) + sum(abs(area_poly([tuple(q) for q in r])) for r in pz['r'])
    libre = piezas.get('libre', {})
    retiene = {}
    for e in ents:
        k = e['clave']
        a_final = final.get(k, 0.0)
        a_libre = libre.get(k, 0.0)
        if a_final < 3.0 or a_libre <= 0:
            retiene[k] = 0.0
            print('   · %s desaparece: su tierra la reclaman otros (%.1f px² de %.0f)' % (e['nombre'], a_final, a_libre))
        else:
            retiene[k] = min(1.0, a_final / a_libre)
    for e in ents:
        if retiene[e['clave']] > 0:
            e['pob'] = e['pob'] * retiene[e['clave']]
    for pz in piezas['piezas']:
        if pz['e'] and retiene.get(pz['e'], 1.0) == 0.0:
            pz['e'] = ''
    items = []
    ids_usados = set()
    sub_orden = {}
    for pz in piezas['piezas']:
        par = base[pz['p']]
        rings = pz['r']
        conts = []
        for r in rings:
            cx = sum(q[0] for q in r) / len(r)
            cy = sum(q[1] for q in r) / len(r)
            conts.append(CM.continente_anillo(par, cx, cy))
        ar = [abs(area_poly([tuple(q) for q in r])) for r in rings]
        mayor = max(range(len(rings)), key=lambda i: ar[i])
        clave = pz['e']
        sub = int(pz.get('s', 0))
        nombre_prov = juego[pz['p']]['n']
        if sub:
            sub_orden[(pz['p'], clave)] = sub_orden.get((pz['p'], clave), 0) + 1
            nombre_prov = '%s · zona %d' % (nombre_prov, sub_orden[(pz['p'], clave)])
        pid = '%s~%s%s' % (par['id'], clave or 'sr', ('.%d' % sub) if sub else '')
        while pid in ids_usados:
            pid += '+'
        ids_usados.add(pid)
        items.append({'padre': pz['p'], 'e': clave, 'sub': sub, 'r': list(rings), 'rp': [pz['p']] * len(rings), 'conts': list(conts), 'a': sum(ar), 'amax': ar[mayor],
                      'c': conts[mayor], 'nombre': nombre_prov, 'id': pid, 'miembros': [(pz['p'], sum(ar))]})
    n0 = len(items)
    items = agrupar(items, lambda it: AREA_AGRUPAR_VACIO if it['e'] == '' else AREA_AGRUPAR)
    nuevas, meta = [], []
    for it in items:
        clave = it['e']
        if clave == '':
            nac = nombre_sin_reclamar(it['c'])
            mudo = True
        else:
            nac = nombre_de[clave]
            mudo = False
        mayor = max(range(len(it['r'])), key=lambda i: abs(area_poly([tuple(q) for q in it['r'][i]])))
        r0 = it['r'][mayor]
        cen = [round(sum(q[0] for q in r0) / len(r0), 2), round(sum(q[1] for q in r0) / len(r0), 2)]
        nuevas.append({'id': it['id'], 'name': it['nombre'], 'country': nac, 'country_es': nac, 'a3': '', 'continent': it['conts'][mayor], 'center': cen,
                       'polygons': it['r'], 'cont_anillos': it['conts'], 'mudo': mudo, 'padres': it['rp']})
        meta.append({'padre': it['padre'], 'clave': clave, 'nac': nac, 'area_px': it['a'], 'cont': it['conts'][mayor], 'miembros': it['miembros']})
    print('   %d piezas del recorte → %d provincias del escenario' % (n0, len(nuevas)))
    t_n = time.time()
    nodar(nuevas)
    print('   nodado en %.1f s' % (time.time() - t_n))
    json.dump(nuevas, open(os.path.join(build, 'fuente_provincias.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    return nuevas, meta, base



# ───────────────────────── 2b. Celdas (0.1.8.35) ─────────────────────────
# El mapa del juego ya no se dibuja por provincias sino por CELDAS: cada anillo del mundo es una celda y una provincia es un grupo de celdas.
# La geometría (relleno, pares de celdas vecinas, costas) es UNA sola para todas las épocas y vive en datos/; cada escenario solo trae su tabla
# «celda → provincia» (el campo `p` de cada anillo en su provincias_juego.json). Las celdas son los anillos de las provincias de ESTE escenario
# (ya recortadas, subdivididas y noded): su unión es exactamente 2026 y exactamente la época; cada provincia de hoy es la unión de las celdas
# cuyo anillo salió de ella (campo `padres`).
def construir_celdas(nuevas, base, build, godot_env):
    cdir = os.path.join(build, 'celdas')
    shutil.rmtree(cdir, ignore_errors=True)
    os.makedirs(cdir)
    fuente, tab_esc, tab_hoy = [], [], []
    for i, pr in enumerate(nuevas):
        assert len(pr['padres']) == len(pr['polygons']) == len(pr['cont_anillos'])
        for j, ring in enumerate(pr['polygons']):
            par = base[pr['padres'][j]]
            k = len(fuente)
            fuente.append({'id': 'c%d' % k, 'name': 'c%d' % k, 'country': par['country'], 'country_es': par.get('country_es', ''), 'a3': '',
                           'continent': par['continent'], 'center': [round(sum(q[0] for q in ring) / len(ring), 2), round(sum(q[1] for q in ring) / len(ring), 2)],
                           'polygons': [ring], 'cont_anillos': [pr['cont_anillos'][j]]})
            tab_esc.append(i)
            tab_hoy.append(pr['padres'][j])
    json.dump(fuente, open(os.path.join(cdir, 'fuente_provincias.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    shutil.copy(os.path.join(BASE, 'lagos_fuente.json'), os.path.join(cdir, 'lagos_fuente.json'))
    env = dict(godot_env, GE_DATOS=cdir, GE_CELDAS='1')
    correr([sys.executable, '-I', os.path.join(HERR, 'construir_mapa.py')], env=env, etiqueta='construir_mapa (celdas)')
    res = json.load(open(os.path.join(cdir, 'provincias_juego.json'), encoding='utf-8'))
    anillos = res['anillos']
    if len(anillos) != len(fuente):
        print('   AVISO: %d celdas dieron %d anillos (alguna se partió por autointersección; cada anillo cuenta como una celda)' % (len(fuente), len(anillos)))
    return cdir, anillos, tab_esc, tab_hoy


def ensamblar_provincias(provincias, anillos, tabla):
    """provincias_juego.json de un escenario: los anillos son las celdas (con su provincia en `p`) y cada provincia lista sus celdas."""
    provs = []
    for p in provincias:
        d = dict(p)
        d['r'] = []
        provs.append(d)
    out = []
    for ri, a in enumerate(anillos):
        b = {k: v for k, v in a.items() if k != 'u'}
        b['p'] = int(tabla[a['u']])
        out.append(b)
        provs[b['p']]['r'].append(ri)
    vacias = [p['id'] for p in provs if not p['r']]
    if vacias:
        print('   AVISO: %d provincias sin ninguna celda: %s' % (len(vacias), vacias[:6]))
    return {'provincias': provs, 'anillos': out}, len(vacias)


def instalar_geometria_comun(cdir, destino):
    """Copia la geometría de las celdas (todo malla_* salvo los estados, y teselas.json / malla_meta.json) a datos/."""
    n = 0
    for f in sorted(os.listdir(cdir)):
        if (f.startswith('malla_') and not f.startswith('malla_estado')) or f in ('teselas.json', 'malla_meta.json'):
            shutil.copy(os.path.join(cdir, f), os.path.join(destino, f))
            n += 1
    return n


# ───────────────────────── 3. Colores ─────────────────────────
def asignar_colores(ents_usadas, nuevas, meta):
    """Colorea cada nación con un color distinto del de sus vecinas (coloreado voraz sobre el grafo de fronteras)."""
    vert = {}
    for pz, m in zip(nuevas, meta):
        if m['clave'] == '':
            continue
        for r in pz['polygons']:
            for x, y in r:
                vert.setdefault((round(x * 5), round(y * 5)), set()).add(m['clave'])
    ady = {e['clave']: set() for e in ents_usadas}
    for s in vert.values():
        if len(s) > 1:
            for a in s:
                for b in s:
                    if a != b:
                        ady[a].add(b)
    color = {}
    orden = sorted(ents_usadas, key=lambda e: (-len(ady[e['clave']]), e['clave']))
    for e in orden:
        k = e['clave']
        if k in FIJOS:
            color[k] = FIJOS[k]
    uso = {p: 0 for p in PALETA}
    for e in orden:
        k = e['clave']
        if k in color:
            continue
        vec = {color[v] for v in ady[k] if v in color}
        libres = [p for p in PALETA if p not in vec]
        if libres:
            libres.sort(key=lambda p: (uso[p], PALETA.index(p)))
            color[k] = libres[0]
        else:
            color[k] = sorted(PALETA, key=lambda p: sum(1 for v in ady[k] if color.get(v) == p))[0]
        uso[color[k]] = uso.get(color[k], 0) + 1
    return color, ady


# ───────────────────────── 4. Población y datos físicos ─────────────────────────
HAB = {'NTF': 1.0, 'WTF': 1.0, 'MED': 1.0, 'TEG': 0.9, 'STF': 0.8, 'TDF': 0.85, 'SAV': 0.7, 'TMG': 0.75, 'TEF': 0.5, 'MAN': 0.4,
       'COF': 0.22, 'LAK': 0.1, 'DES': 0.12, 'TUN': 0.06, 'ICE': 0.0}


def construir_info(ents_por_clave, nuevas, meta, base_info):
    prov_b = base_info['prov']
    # área en px² de cada provincia de hoy (para repartir su área en km²)
    base = json.load(open(os.path.join(BASE, 'fuente_provincias.json'), encoding='utf-8'))
    area_b = [sum(abs(area_poly([tuple(q) for q in r])) for r in p['polygons']) for p in base]
    filas, peso = [], []
    for pz, m in zip(nuevas, meta):
        area = 0.0
        alt = 0.0
        altmax = 0
        bio = {}
        reinos = {}
        dens = 0.0
        for padre, a_px in m['miembros']:
            fila = prov_b[padre]
            frac = min(1.0, a_px / area_b[padre]) if area_b[padre] > 0 else 0.0
            a_km = float(fila[1]) * frac
            area += a_km
            alt += float(fila[2]) * a_km
            altmax = max(altmax, int(fila[3]))
            for b_, pc in (fila[4] if len(fila) > 4 else []):
                bio[b_] = bio.get(b_, 0.0) + pc * a_km
            reinos[fila[5] if len(fila) > 5 else ''] = reinos.get(fila[5] if len(fila) > 5 else '', 0.0) + a_km
            dens += float(fila[0]) * frac / 1.0
        tb = sum(bio.values()) or 1.0
        bio_l = [[b_, int(round(100 * v / tb))] for b_, v in sorted(bio.items(), key=lambda t: -t[1])[:3]]
        rei = max(reinos.items(), key=lambda t: t[1])[0] if reinos else ''
        hab = (sum(HAB.get(b_, 0.5) * v for b_, v in bio.items()) / tb) if bio else 0.5
        d_km = dens / max(area, 1.0)
        f = min(1.0, math.log10(d_km + 1.0) / 3.0)
        filas.append([0, round(area, 1), int(round(alt / area)) if area > 0 else 0, altmax, bio_l, rei])
        peso.append(0.0 if m['clave'] == '' else area * hab * (0.25 + f))
    # población por nación = su población objetivo repartida por peso
    por_nac = {}
    for i, m in enumerate(meta):
        if m['clave'] != '':
            por_nac.setdefault(m['clave'], []).append(i)
    for clave, lst in por_nac.items():
        total = float(ents_por_clave[clave]['pob']) * 1000.0
        sw = sum(peso[i] for i in lst)
        if sw <= 0:
            sa = sum(filas[i][1] for i in lst) or 1.0
            for i in lst:
                filas[i][0] = int(round(total * filas[i][1] / sa))
        else:
            for i in lst:
                filas[i][0] = int(round(total * peso[i] / sw))
    return filas


def agregar(filas, idxs):
    pob = sum(filas[i][0] for i in idxs)
    area = sum(filas[i][1] for i in idxs)
    alt = int(round(sum(filas[i][2] * filas[i][1] for i in idxs) / area)) if area > 0 else 0
    altmax = max((filas[i][3] for i in idxs), default=0)
    bio = {}
    reino = {}
    for i in idxs:
        for b, pc in filas[i][4]:
            bio[b] = bio.get(b, 0.0) + pc * filas[i][1]
        reino[filas[i][5]] = reino.get(filas[i][5], 0.0) + filas[i][1]
    tb = sum(bio.values()) or 1.0
    bio_l = [[b, int(round(100 * v / tb))] for b, v in sorted(bio.items(), key=lambda t: -t[1])[:3]]
    rei = max(reino.items(), key=lambda t: t[1])[0] if reino else ''
    return {'pob': int(pob), 'area': int(round(area)), 'alt': alt, 'altmax': int(altmax), 'bio': bio_l, 'reino': rei}


# ───────────────────────── 5. Economía por arquetipo ─────────────────────────
TPL = {
    'med': (['Trigo', 'Vid', 'Olivo'], ['Oveja', 'Cerdo'], ['Hierro', 'Plata', 'Mármol'],
            [['Agricultura', 72], ['Comercio', 10], ['Artesanía', 8], ['Minería', 4], ['Construcción', 3], ['Otros', 3]]),
    'china': (['Mijo', 'Arroz', 'Trigo'], ['Cerdo', 'Cerdo'], ['Hierro', 'Sal', 'Seda'],
              [['Agricultura', 74], ['Artesanía y seda', 9], ['Comercio', 7], ['Hierro y minería', 5], ['Otros', 5]]),
    'india': (['Arroz', 'Mijo', 'Algodón'], ['Búfalo', 'Cabra'], ['Hierro', 'Gemas', 'Especias'],
              [['Agricultura', 72], ['Artesanía y textiles', 11], ['Comercio', 10], ['Minería', 3], ['Otros', 4]]),
    'iran': (['Trigo', 'Cebada', 'Dátil'], ['Oveja', 'Oveja'], ['Sal', 'Plata', 'Turquesa'],
             [['Agricultura', 66], ['Comercio de la Ruta de la Seda', 14], ['Artesanía', 9], ['Pastoreo', 7], ['Otros', 4]]),
    'arabia': (['Dátil', 'Cebada', 'Incienso'], ['Camello', 'Cabra'], ['Incienso', 'Mirra', 'Sal'],
               [['Comercio caravanero', 38], ['Agricultura de oasis', 30], ['Pastoreo', 20], ['Artesanía', 7], ['Otros', 5]]),
    'nomada': (['—'], ['Caballo', 'Oveja'], ['Cobre', 'Hierro', 'Pieles'],
               [['Pastoreo', 72], ['Saqueo y tributos', 12], ['Comercio', 8], ['Artesanía', 5], ['Otros', 3]]),
    'europa_n': (['Cebada', 'Avena', 'Centeno'], ['Res', 'Cerdo'], ['Hierro', 'Ámbar', 'Sal'],
                 [['Agricultura', 68], ['Ganadería', 17], ['Artesanía', 6], ['Comercio', 5], ['Otros', 4]]),
    'africa': (['Sorgo', 'Mijo', 'Ñame'], ['Res', 'Cabra'], ['Hierro', 'Oro', 'Sal'],
               [['Agricultura', 62], ['Ganadería', 18], ['Caza y pesca', 8], ['Artesanía', 7], ['Comercio', 5]]),
    'meso': (['Maíz', 'Frijol', 'Calabaza'], ['Pavo', 'Perro'], ['Obsidiana', 'Jade', 'Cacao'],
             [['Agricultura', 74], ['Artesanía', 10], ['Comercio', 8], ['Construcción', 5], ['Otros', 3]]),
    'andes': (['Papa', 'Maíz', 'Quinua'], ['Llama', 'Cuy'], ['Plata', 'Oro', 'Sal'],
              [['Agricultura', 66], ['Pastoreo de camélidos', 12], ['Pesca', 8], ['Artesanía', 9], ['Otros', 5]]),
    'tropical': (['Yuca', 'Maíz', 'Palma'], ['Caza', 'Pesca'], ['Madera', 'Resinas', 'Plumas'],
                 [['Agricultura itinerante', 48], ['Caza y pesca', 30], ['Recolección', 12], ['Artesanía', 6], ['Otros', 4]]),
    'cazador': (['—'], ['Caza', 'Pesca'], ['Pieles', 'Sílex', 'Ocre'],
                [['Caza', 40], ['Pesca', 28], ['Recolección', 24], ['Artesanía', 5], ['Otros', 3]]),
    'islas': (['Taro', 'Ñame', 'Coco'], ['Cerdo', 'Cerdo'], ['Conchas', 'Obsidiana', 'Madera'],
              [['Agricultura', 45], ['Pesca', 33], ['Artesanía', 10], ['Navegación y comercio', 8], ['Otros', 4]]),
    'norte_am': (['Maíz', 'Calabaza', 'Girasol'], ['Venado', 'Pavo'], ['Cobre', 'Mica', 'Sílex'],
                 [['Agricultura', 45], ['Caza', 25], ['Pesca y recolección', 18], ['Artesanía', 8], ['Otros', 4]]),
}
TPL_CLAVE = {
    'Roman Empire': 'med', 'Greek City-States': 'med', 'Thracian Kingdom': 'med', 'Cimmerian Bosporus': 'med', 'Kingdom of Pontus': 'med',
    'Kingdom of Cappadocia': 'med', 'Mauretania': 'med', 'Judea': 'med', 'Han Dynasty': 'china', 'Goguryeo': 'china', 'Dongye': 'china',
    'Dong-okjeo': 'china', 'Mahan': 'china', 'Jinhan': 'china', 'Byeonhan': 'china', 'Satavahana Dynasty': 'india', 'Anurādhapura': 'india',
    'Early Cholas': 'india', 'Early Pandyas': 'india', 'Early Cheras': 'india', 'Indo-Greeks': 'iran', 'Indo-Scythians': 'iran',
    'Indo-Parthians': 'iran', 'Parthian Empire': 'iran', 'Yuezhi': 'iran', 'Great Yuan': 'iran', 'Kingdom of Armenia': 'iran',
    'Caucasian Iberia': 'iran', 'Caucasian Albania': 'iran', 'Lazica': 'med', 'Kingdom of Osroene': 'iran', 'Kingdom of Adiabene': 'iran',
    'Kingdom of Gordyene': 'iran', 'Kingdom of Sophene': 'iran', 'Kingdom of Commagene': 'med', 'Nabataeans': 'arabia',
    'Himyarite Kingdom': 'arabia', 'Hadhramaut': 'arabia', 'Xiongnu': 'nomada', 'Wusun': 'nomada', 'Kingdom of Kush': 'africa',
    'Kingdom of Axum': 'africa', 'Mayan City-States': 'meso', 'Zapotec Civilization': 'meso', 'Teotihuacan': 'meso',
}


def plantilla_eco(e):
    k = e['clave']
    if k in TPL_CLAVE:
        return TPL[TPL_CLAVE[k]]
    tipo = e.get('tipo', '')
    cont = e['cont']
    if 'cazador' in tipo:
        return TPL['cazador']
    if 'nómada' in tipo:
        return TPL['nomada']
    lon, lat = e['centro']
    if cont == 'África':
        return TPL['africa'] if lat < 22 else TPL['med']
    if cont == 'Europa':
        return TPL['europa_n']
    if cont == 'Oceanía':
        return TPL['islas'] if (lon > 147 or lon < -170 or (lon < 140 and lat > -1)) else TPL['cazador']
    if cont == 'América del Sur':
        if lon < -66 and lat > -36 and e['clave'] not in ('amazonia_arawak',):
            return TPL['andes']
        return TPL['tropical']
    if cont == 'América del Norte':
        if lat < 24 or e['clave'] in ('antillas_mayores', 'saladoides'):
            return TPL['meso'] if e['clave'] not in ('antillas_mayores', 'saladoides', 'intermedio_ca') else TPL['tropical']
        return TPL['norte_am']
    if cont == 'Asia':
        if lat < 25 and lon > 95:
            return TPL['tropical'] if e['clave'] in ('malayos', 'borneo', 'celebes', 'filipinas', 'taiwan', 'java_bali') else TPL['china']
        if lon > 75 and lat < 31:
            return TPL['india']
        if lon > 100 and lat > 33:
            return TPL['china'] if 'tribus' not in tipo else TPL['europa_n']
        if lon < 76:
            return TPL['iran']
        return TPL['india']
    return TPL['europa_n']


# ───────────────────────── 6. Banderas (estandartes) ─────────────────────────
def hacer_bandera(clave, hexcol, ruta):
    c1 = hexc(hexcol)
    c2 = tuple(int(v * 0.55) for v in c1)
    c3 = tuple(min(255, int(v * 0.4 + 255 * 0.6)) for v in c1)
    h = int(hashlib.md5(clave.encode()).hexdigest()[:8], 16)
    W, H = 96, 64
    im = Image.new('RGB', (W, H), c1)
    d = ImageDraw.Draw(im)
    forma = h % 6
    if forma == 0:                                  # banda central
        d.rectangle([0, H * 0.38, W, H * 0.62], fill=c3)
    elif forma == 1:                                # círculo
        d.ellipse([W * 0.32, H * 0.2, W * 0.68, H * 0.8], fill=c3, outline=c2, width=2)
    elif forma == 2:                                # cruz
        d.rectangle([W * 0.42, 0, W * 0.58, H], fill=c3)
        d.rectangle([0, H * 0.4, W, H * 0.6], fill=c3)
    elif forma == 3:                                # triángulo
        d.polygon([(0, 0), (W * 0.5, H * 0.5), (0, H)], fill=c3)
    elif forma == 4:                                # rombo
        d.polygon([(W * 0.5, H * 0.12), (W * 0.82, H * 0.5), (W * 0.5, H * 0.88), (W * 0.18, H * 0.5)], fill=c3, outline=c2)
    else:                                           # dos franjas
        d.rectangle([0, 0, W, H * 0.22], fill=c2)
        d.rectangle([0, H * 0.78, W, H], fill=c2)
    d.rectangle([0, 0, W - 1, H - 1], outline=c2, width=2)
    im.save(ruta)


# ───────────────────────── 7. Ciudades ─────────────────────────
def zoom_ciudad(pop, cap_nac, cap_prov):
    if cap_nac or pop >= 5e6:
        return 2.4
    if pop >= 1e6:
        return 3.8
    if pop >= 3e5 or (cap_prov and pop >= 1e5):
        return 6.0
    if pop >= 1e5:
        return 9.0
    if pop >= 2e4:
        return 14.0
    return 22.0


class Localizador:
    """Dado un punto del mapa, devuelve la provincia nueva que lo contiene."""
    def __init__(self, nuevas):
        self.nuevas = nuevas
        self.bb = []
        self.anillos = []
        for i, p in enumerate(nuevas):
            for r in p['polygons']:
                a = np.asarray(r, dtype=float)
                self.bb.append((a[:, 0].min(), a[:, 1].min(), a[:, 0].max(), a[:, 1].max(), i))
                self.anillos.append(a)
        self.bbn = np.asarray(self.bb)

    @staticmethod
    def dentro(x, y, a):
        xs, ys = a[:, 0], a[:, 1]
        xs2, ys2 = np.roll(xs, -1), np.roll(ys, -1)
        dy = np.where(ys2 == ys, 1e-12, ys2 - ys)
        cruza = ((ys > y) != (ys2 > y)) & (x < (xs2 - xs) * (y - ys) / dy + xs)
        return bool(np.count_nonzero(cruza) % 2)

    def provincia(self, x, y, margen=0.0):
        bb = self.bbn
        cand = np.nonzero((bb[:, 0] - margen <= x) & (x <= bb[:, 2] + margen) & (bb[:, 1] - margen <= y) & (y <= bb[:, 3] + margen))[0]
        for k in cand:
            if self.dentro(x, y, self.anillos[k]):
                return int(bb[k, 4]), 0.0
        mejor, md = -1, 1e9
        for k in cand:
            a = self.anillos[k]
            d = float(np.min(np.hypot(a[:, 0] - x, a[:, 1] - y)))
            if d < md:
                md, mejor = d, int(bb[k, 4])
        return mejor, md


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--godot', default=os.environ.get('GODOT') or '/tmp/godot/Godot_v4.3-stable_linux.x86_64')
    ap.add_argument('--build', default='/tmp/ge_build_1dc')
    ap.add_argument('--out', default=os.path.join(BASE, 'epocas', '1dc'))
    ap.add_argument('--sin-recorte', action='store_true', help='reutiliza piezas.json de la carpeta de trabajo')
    args = ap.parse_args()
    t0 = time.time()
    build = args.build
    os.makedirs(build, exist_ok=True)
    print('1. Territorios de la época')
    ents = territorios()
    print('   %d estados + %d pueblos' % (sum(1 for e in ents if e['es_estado']), sum(1 for e in ents if not e['es_estado'])))
    print('2. Recorte de provincias')
    if args.sin_recorte and os.path.exists(os.path.join(build, 'piezas.json')):
        piezas = json.load(open(os.path.join(build, 'piezas.json'), encoding='utf-8'))
    else:
        piezas = recortar(ents, build, args.godot)
    nuevas, meta, base_fuente = construir_fuente(ents, piezas, build)
    usadas = {m['clave'] for m in meta if m['clave']}
    sin_piezas = [e['clave'] for e in ents if e['clave'] not in usadas]
    if sin_piezas:
        print('   AVISO: territorios sin ninguna provincia (no tocan tierra o los tapa otro):', sin_piezas)
    ents = [e for e in ents if e['clave'] in usadas]
    por_clave = {e['clave']: e for e in ents}
    print('   %d provincias nuevas (hoy: %d) · %d naciones con tierra' % (len(nuevas), len(base_fuente), len(ents)))
    print('3. Colores')
    color, ady = asignar_colores(ents, nuevas, meta)
    print('4. Mapa (construir_mapa.py)')
    shutil.copy(os.path.join(BASE, 'lagos_fuente.json'), os.path.join(build, 'lagos_fuente.json'))
    env = dict(os.environ, GE_DATOS=build)
    correr([sys.executable, '-I', os.path.join(HERR, 'construir_mapa.py')], env=env, etiqueta='construir_mapa')
    juego = json.load(open(os.path.join(build, 'provincias_juego.json'), encoding='utf-8'))
    assert [p['id'] for p in juego['provincias']] == [p['id'] for p in nuevas]
    print('4b. Celdas del mundo (geometría común a todas las épocas)')
    cdir, anillos_c, tab_esc, tab_hoy = construir_celdas(nuevas, base_fuente, build, env)
    print('   %d celdas' % len(anillos_c))
    print('5. Datos de juego')
    base_info = json.load(open(os.path.join(BASE, 'info.json'), encoding='utf-8'))
    filas = construir_info(por_clave, nuevas, meta, base_info)
    # naciones: provincias, bbox, centro
    prov_de = {}
    for i, m in enumerate(meta):
        prov_de.setdefault(m['nac'], []).append(i)
    inertes = sorted(n for n in prov_de if n.startswith('Tierras sin reclamar'))
    for e in ents:
        lst = prov_de[e['nombre']]
        e['centro'] = (0, 0)
        xs, ys, ws = [], [], []
        for i in lst:
            for r in nuevas[i]['polygons']:
                a = np.asarray(r)
                xs.append((a[:, 0].mean())); ys.append(a[:, 1].mean()); ws.append(abs(area_poly([tuple(q) for q in r])))
        w = np.asarray(ws)
        cx = float(np.average(xs, weights=w)) if w.sum() > 0 else 0
        cy = float(np.average(ys, weights=w)) if w.sum() > 0 else 0
        e['centro'] = (cx / ESC - 180.0, 90.0 - cy / ESC)
    # entidades.json
    paises = {}
    for e in ents:
        lst = prov_de[e['nombre']]
        rings = [(abs(area_poly([tuple(q) for q in r])), r) for i in lst for r in nuevas[i]['polygons']]
        rings.sort(key=lambda t: -t[0])
        tot = sum(a for a, _ in rings) or 1.0
        acum, sel = 0.0, []
        for a, r in rings:
            sel.append(r)
            acum += a
            if acum >= 0.95 * tot:
                break
        xs = [q[0] for r in sel for q in r]
        ys = [q[1] for r in sel for q in r]
        foco = [round(min(xs), 2), round(min(ys), 2), round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2)]
        cap = e.get('cap')
        paises[e['nombre']] = {'a3': '', 'cont': e['cont'], 'cap': cap[0] if cap else 'Sin capital', 'div': e.get('div', 'Territorios'),
                               'bandera': PREFIJO + slug(e['clave']),
                               'col': color[e['clave']], 'foco': foco, 'tipo': e.get('tipo', ''), 'desde': e.get('desde'), 'hasta': e.get('hasta'),
                               'fuente': e['fuente']}
    for nom in inertes:
        lst = prov_de[nom]
        cont = meta[lst[0]]['cont']
        rings = [r for i in lst for r in nuevas[i]['polygons']]
        xs = [q[0] for r in rings for q in r]
        ys = [q[1] for r in rings for q in r]
        paises[nom] = {'a3': '', 'cont': cont, 'cap': 'Sin capital', 'div': 'Territorios', 'bandera': 'x', 'col': '3b3f46',
                       'foco': [round(min(xs), 2), round(min(ys), 2), round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2)],
                       'tipo': 'sin reclamar', 'sin_reclamar': True}
    # info.json (provincias, países, continentes)
    info_pais, info_cont = {}, {}
    for nom, lst in prov_de.items():
        d = agregar(filas, lst)
        e = por_clave.get(next((k for k, v in por_clave.items() if v['nombre'] == nom), ''), None)
        d['cont'] = paises[nom]['cont']
        d['etn'] = [[g, float(p)] for g, p in e['etn']] if e else []
        info_pais[nom] = d
    por_cont = {}
    for nom, lst in prov_de.items():
        por_cont.setdefault(paises[nom]['cont'], []).extend(lst)
    for cont, lst in por_cont.items():
        d = agregar(filas, lst)
        d['paises'] = sum(1 for n in prov_de if paises[n]['cont'] == cont)
        info_cont[cont] = d
    info = {'anio': ANIO, 'prov': filas, 'pais': info_pais, 'cont': info_cont, 'biomas': base_info['biomas'], 'reinos': base_info['reinos'],
            'niv_m': base_info['niv_m'], 'estado': {}}
    json.dump(info, open(os.path.join(build, 'info.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    # economía
    eco = {'pais': {}, 'region': {}}
    for e in ents:
        c, ca, m, rub = plantilla_eco(e)
        eco['pais'][e['nombre']] = {'cult': c, 'carne': ca, 'mat': m, 'rub': rub, 'nivel': 'r'}
    json.dump(eco, open(os.path.join(build, 'economia.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    # divisas
    div = {'divisas': {c: {'n': v[0], 's': v[1], 'u': v[2]} for c, v in DE.DIVISAS.items()}, 'paises': {}, 'tasa_fiscal': 0.25, 'version': '1dc'}
    for e in ents:
        pob = info_pais[e['nombre']]['pob']
        div['paises'][e['nombre']] = {'d': e['moneda'], 'pib': int(pob * e['pib_pc']), 'pob': pob}
    json.dump(div, open(os.path.join(build, 'divisas.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    # banderas
    banderas = {'paises': {n: paises[n]['bandera'] for n in paises if not paises[n].get('sin_reclamar')}, 'provincias': {}, 'estados': {}, 'ciudades': {}}
    json.dump(banderas, open(os.path.join(build, 'banderas.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    # ejército
    TASA = {'imperio': 0.0055, 'reino': 0.008, 'reinos': 0.008, 'confederación nómada': 0.035, 'confederación': 0.015, 'ciudades-estado': 0.010,
            'tribus': 0.015, 'confederación tribal': 0.02, 'reino tribal': 0.015, 'cultura': 0.006, 'cazadores-recolectores': 0.008,
            'repúblicas tribales': 0.012}
    tasas = {}
    for e in ents:
        tasas[e['nombre']] = TASA.get(e.get('tipo', ''), 0.01)
    tasas['Dinastía Han'] = 0.0045
    tasas['Imperio parto'] = 0.006
    tasas['Confederación Xiongnu'] = 0.04
    ej = {'version': '1dc', 'ayuda': 'Soldados de cada nación al empezar el año 1 d. C.: población × tasa. Estimaciones de orden de magnitud (legiones y auxiliares romanos ≈ 300.000; ejército Han ≈ 250.000; arqueros xiongnu ≈ 150.000...).',
          'tasa_defecto': 0.01, 'tasas': tasas, 'sin_ejercito': inertes}
    json.dump(ej, open(os.path.join(build, 'ejercito.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('6. Ciudades')
    loc = Localizador(nuevas)
    nacs = sorted(paises)
    idx_nac = {n: i for i, n in enumerate(nacs)}
    filas_c = []
    usados = set()
    aviso = []

    def anadir(nombre, lon, lat, pop, rango, nac_forzada=None):
        x, y = (lon + 180.0) * ESC, (90.0 - lat) * ESC
        pi, d = loc.provincia(x, y, margen=3.0)
        if pi < 0 or d > 3.0:
            aviso.append('%s fuera de toda tierra (%.1f px)' % (nombre, d))
            return None
        nac = meta[pi]['nac']
        if nac_forzada is not None and nac != nac_forzada:
            # la capital cae en tierra ajena: se mueve a la provincia más cercana de su propia nación
            mejor, md = None, 1e9
            for j in prov_de[nac_forzada]:
                for r in nuevas[j]['polygons']:
                    a = np.asarray(r)
                    dd = float(np.min(np.hypot(a[:, 0] - x, a[:, 1] - y)))
                    if dd < md:
                        md, mejor = dd, (j, a)
            if mejor is None:
                return None
            j, a = mejor
            k = int(np.argmin(np.hypot(a[:, 0] - x, a[:, 1] - y)))
            c = np.asarray(nuevas[j]['center'])
            x, y = float(0.7 * a[k, 0] + 0.3 * c[0]), float(0.7 * a[k, 1] + 0.3 * c[1])
            pi2, _ = loc.provincia(x, y)
            if pi2 != j:
                x, y = float(c[0]), float(c[1])
                pi2 = j
            aviso.append('capital %s movida a su propia tierra (%.1f px de la posición histórica)' % (nombre, md))
            pi, nac = pi2, nac_forzada
        if paises[nac].get('sin_reclamar'):
            return None
        filas_c.append([nombre, round(x, 2), round(y, 2), int(pop), rango, idx_nac[nac], pi, zoom_ciudad(pop, rango == 2, rango == 1)])
        usados.add(nombre)
        return nac

    pop_de = {c[0]: c[3] for c in CIUDADES}
    for e in ents:
        if e.get('cap'):
            nombre, lon, lat = e['cap']
            anadir(nombre, lon, lat, pop_de.get(nombre, 5000), 2, nac_forzada=e['nombre'])
    for nombre, lon, lat, pop in CIUDADES:
        if nombre in usados:
            continue
        anadir(nombre, lon, lat, pop, 1 if pop >= 50000 else 0)
    # cada nación sin capital propia recibe la ciudad más poblada que tenga como capital
    tiene_cap = {nacs[f[5]] for f in filas_c if f[4] == 2}
    for e in ents:
        if e['nombre'] in tiene_cap:
            continue
        propias = [f for f in filas_c if nacs[f[5]] == e['nombre']]
        if propias:
            m = max(propias, key=lambda f: f[3])
            m[4] = 2
            m[7] = 2.4
            e['cap'] = (m[0], 0, 0)
            paises[e['nombre']]['cap'] = m[0]
    # ... y las que no tienen ninguna ciudad reciben un asentamiento principal en el centro de su provincia más poblada
    tiene_c = {nacs[f[5]] for f in filas_c}
    for e in ents:
        if e['nombre'] in tiene_c:
            continue
        lst = prov_de[e['nombre']]
        j = max(lst, key=lambda i: filas[i][0])
        c = nuevas[j]['center']
        pi, _ = loc.provincia(c[0], c[1])
        tipo_e = paises[e['nombre']].get('tipo', '')
        nombre = ('Campamento principal' if tipo_e in ('cazadores-recolectores', 'confederación nómada') else
                  'Aldea principal' if 'tribu' in tipo_e or 'tribal' in tipo_e else 'Centro principal')
        filas_c.append([nombre, c[0], c[1], max(300, int(filas[j][0] * 0.05)), 2, idx_nac[e['nombre']], j if pi != j else pi, 2.4])
        paises[e['nombre']]['cap'] = nombre
    for a in aviso:
        print('   ·', a)
    json.dump({'paises': nacs, 'c': filas_c}, open(os.path.join(build, 'ciudades.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    json.dump({'paises': paises, 'version': '1dc-0.1.8.34', 'esquema_colores': 'propio'}, open(os.path.join(build, 'entidades.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))
    print('   %d ciudades' % len(filas_c))
    print('7. Vecindad e IDs')
    correr([sys.executable, '-I', os.path.join(HERR, 'construir_vecinos.py')], env=env, etiqueta='construir_vecinos')
    if os.path.exists(os.path.join(build, 'ids.json')):
        os.remove(os.path.join(build, 'ids.json'))              # un escenario empieza con IDs nuevos (si no, conservaría los de corridas anteriores como inactivos)
    correr([sys.executable, '-I', os.path.join(HERR, 'construir_ids.py')], env=env, etiqueta='construir_ids')
    # nombres de mandos
    from nombres_epoca import escribir_nombres
    escribir_nombres(build, ents, paises)
    meta_ep = {'anio': ANIO, 'nombre': 'Año 1 d. C.', 'esquema_colores': 'propio', 'reloj': [1, 1, 1],
               'descripcion': 'El mundo en el año 1 d. C.: Roma y la China Han, el Imperio parto, cientos de pueblos y culturas, y tierras sin reclamar.',
               'creditos': ['Fronteras de los estados: Cliopatria v0.2.1, Seshat Global History Databank (CC BY 4.0), https://github.com/Seshat-Global-History-Databank/cliopatria — adaptadas a las provincias del juego.',
                            'Pueblos y culturas sin estado, poblaciones, ciudades y economía: estimaciones propias de este proyecto.'],
               'naciones': len(ents), 'provincias': len(nuevas), 'pob_mundo': int(sum(info_cont[c]['pob'] for c in info_cont))}
    json.dump(meta_ep, open(os.path.join(build, 'epoca.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('8. Copia al paquete y banderas')
    salida = args.out
    os.makedirs(salida, exist_ok=True)
    nopaq = ('fuente_provincias.json', 'lagos_fuente.json', 'territorios.json', 'piezas.json', 'teselas.json', 'malla_meta.json', 'provincias_juego.json', 'celdas')
    for f in sorted(os.listdir(build)):
        if f in nopaq or (f.startswith('malla_') and not f.startswith('malla_estado')):
            continue
        ruta = os.path.join(build, f)
        if os.path.isdir(ruta):
            continue
        shutil.copy(ruta, os.path.join(salida, f))
    for f in os.listdir(salida):                              # restos de versiones anteriores (esta época ya no trae mallas propias)
        if (f.startswith('malla_') and not f.startswith('malla_estado')) or f in ('teselas.json', 'malla_meta.json'):
            os.remove(os.path.join(salida, f))
    # celdas: la geometría común va a datos/ y cada escenario guarda su tabla celda → provincia
    pj_esc, vac1 = ensamblar_provincias(juego['provincias'], anillos_c, tab_esc)
    json.dump(pj_esc, open(os.path.join(salida, 'provincias_juego.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    pj_hoy_ruta = os.path.join(BASE, 'provincias_juego.json')
    pj_hoy_base = json.load(open(pj_hoy_ruta, encoding='utf-8'))['provincias']          # (idempotente: solo se usan id, n, c, m, e; las celdas se rehacen)
    pj_hoy, vac26 = ensamblar_provincias(pj_hoy_base, anillos_c, tab_hoy)
    json.dump(pj_hoy, open(pj_hoy_ruta, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    n_inst = instalar_geometria_comun(cdir, BASE)
    print('   %d archivos de geometría común instalados en datos/ · provincias sin celda: año 1 = %d, 2026 = %d' % (n_inst, vac1, vac26))
    bdir = os.path.join(RAIZ, 'banderas')
    n_b = 0
    for e in ents:
        hacer_bandera(e['clave'], color[e['clave']], os.path.join(bdir, paises[e['nombre']]['bandera'] + '.png'))
        n_b += 1
    pob_tot = sum(info_pais[n]['pob'] for n in info_pais)
    print('Listo: %d naciones, %d provincias, %d ciudades, población del mundo %.1f millones, %d banderas · %.0f s' % (
        len(ents), len(nuevas), len(filas_c), pob_tot / 1e6, n_b, time.time() - t0))


if __name__ == '__main__':
    sys.exit(main())
