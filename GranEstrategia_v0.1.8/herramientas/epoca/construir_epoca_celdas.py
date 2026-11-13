#!/usr/bin/env python3
"""
construir_epoca_celdas.py — Genera los paquetes de datos de las épocas 1096 (Primera Cruzada) y 1500 (Renacimiento): datos/epocas/1096/ y datos/epocas/1500/.

A diferencia de construir_epoca.py (año 1 d. C.), aquí NO se recorta ninguna provincia: el mundo ya está hecho de CELDAS (docs/MAPA_CELDAS.md), la geometría común a
todas las épocas, y una época es solo la tabla «celda → provincia». Cada celda se reparte entre los territorios de la época por mayoría de superficie (raster) y
las celdas de un mismo territorio y de una misma provincia de hoy se agrupan en provincias, igual que en el año 1:
  · estados: polígonos de Cliopatria v0.2.1 (Seshat Global History Databank, CC BY 4.0) → fuentes/cliopatria_<año>.json  (fichas: datos_medieval_estados.py)
  · pueblos sin estado: las zonas del año 1 (datos_1dc_pueblos_*.py) con nombre y población de la época (datos_medieval_pueblos.py)
  · lo que nadie reclama: «Tierras sin reclamar» (misma regla de huecos habitados que el año 1: reclamar_huecos)
Después escribe lo mismo que el año 1: info, entidades, ciudades, economía, divisas, banderas, ejército, nombres, vecindad e IDs.

Las celdas salen de una corrida de construir_epoca.py:   python3 -I herramientas/epoca/construir_epoca.py --build CARPETA   →   CARPETA/celdas/
Uso:   python3 -I herramientas/epoca/construir_epoca_celdas.py --anio 1096 [--celdas CARPETA/celdas] [--godot RUTA] [--build TEMP] [--png salida.png]
Requiere: python3, numpy, pillow. (No hace falta Godot: no se recorta nada.)
"""
import json
import os
import shutil
import subprocess
import sys
import time

import numpy as np
from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
HERR = os.path.dirname(AQUI)
RAIZ = os.path.dirname(HERR)
sys.path.insert(0, AQUI)
sys.path.insert(0, HERR)

import construir_epoca as CE                       # noqa: E402  (reutiliza reclamar_huecos, agrupar, construir_info, banderas, ciudades…)
import datos_medieval_estados as ME                # noqa: E402
import datos_medieval_pueblos as MP                # noqa: E402
import datos_1dc_pueblos_b                         # noqa: E402,F401  (registra todos los pueblos del año 1)
from datos_1dc_pueblos_a import PUEBLOS            # noqa: E402
import nombres_epoca as NM                         # noqa: E402

BASE = CE.BASE
ESC = CE.ESC
RW, RH = 4800, 2400                                 # raster de reparto: 2 px por px de mapa (≈ 0,075°)
R = RW / 360.0
NOMBRE_EPOCA = {1096: 'Primera Cruzada (1096)', 1500: 'Renacimiento (1500)'}
DESCRIPCION = {
    1096: 'El mundo en 1096: la Primera Cruzada parte hacia Jerusalén. Imperio bizantino, selyúcidas, la China de los Song, los reinos cristianos de Europa y el mundo almorávide.',
    1500: 'El mundo en 1500: el Renacimiento, los imperios otomano, safávida y ming, los reinos ibéricos que cruzan el Atlántico, los aztecas y los incas.'}
# Ajuste global de la población (las fichas de 1096 suman ~415 M, por encima de lo habitual en las estimaciones publicadas, 300–400 M; sin tocar las proporciones)
ESCALA_POB = {1096: 0.88, 1500: 1.0}
AREA_MIN_PROV = 45.0        # px² (≈ 12.500 km²): las piezas más pequeñas se agrupan con una vecina del mismo territorio (el año 1 usa 70 con piezas más finas)


# ───────────────────────── 1. Territorios de la época ─────────────────────────
def territorios(anio):
    clio = json.load(open(os.path.join(AQUI, 'fuentes', 'cliopatria_%d.json' % anio), encoding='utf-8'))
    fichas = ME.ESTADOS[anio]
    estados = []
    for pol in clio['politicas']:
        if pol['nombre'] not in fichas:
            continue
        d = dict(fichas[pol['nombre']])
        d['clave'] = pol['nombre']
        d['fuente'] = 'Cliopatria'
        d['partes'] = [[CE.px(x, y) for x, y in parte] for parte in pol['partes']]
        d['es_estado'] = True
        d['desde'] = pol.get('desde')
        d['hasta'] = pol.get('hasta')
        estados.append(d)
    por_clave = {p['clave']: p for p in PUEBLOS}
    k = 0 if anio == 1096 else 1
    pueblos = []
    for clave, v in MP.PUEBLOS_MED.items():
        nombre = v[k] if isinstance(v, tuple) else v
        if nombre is None:
            continue
        p = por_clave[clave]
        d = dict(p)
        d['nombre'] = nombre
        d['etn'] = [(nombre, 100)]
        d['partes'] = [[CE.px(x, y) for x, y in parte] for parte in p['partes']]
        d['fuente'] = 'dibujado a mano'
        d['es_estado'] = False
        d['cap'] = None
        d['moneda'] = 'TRQ'
        d['desde'] = d['hasta'] = None
        reg = 'Siberia' if clave in MP.SIBERIA else 'Asia_sudeste' if clave in MP.SUDESTE else p['cont']
        f = MP.FACTOR.get(reg, MP.FACTOR['Asia'])[k]
        d['pob'] = MP.POB_FIJA[clave][k] if clave in MP.POB_FIJA else p['pob'] * f
        pueblos.append(d)
    for d in estados + pueblos:
        d['area_px'] = sum(abs(CE.area_poly(parte)) for parte in d['partes'])
        d['pob'] = d['pob'] * ESCALA_POB[anio]
    nombres = [d['nombre'] for d in estados + pueblos]
    dup = {n for n in nombres if nombres.count(n) > 1}
    assert not dup, 'nombres repetidos: %s' % sorted(dup)
    estados.sort(key=lambda d: d['area_px'])
    pueblos.sort(key=lambda d: d['area_px'])
    return estados + pueblos


# ───────────────────────── 2. Reparto de las celdas por mayoría (raster) ─────────────────────────
def poligono(draw, parte, valor, k=2.0):
    if len(parte) >= 3:
        draw.polygon([(x * k, y * k) for x, y in parte], fill=valor)


def repartir(ents, celdas, usable):
    """Devuelve (etiqueta de cada celda: clave o '', px² de tierra que cubre cada territorio por sí solo)."""
    K = len(celdas)
    cel_img = Image.new('I', (RW, RH), 0)
    d = ImageDraw.Draw(cel_img)
    for k, c in enumerate(celdas):
        if usable[k]:
            poligono(d, c['polygons'][0], k + 1)
    cel = np.asarray(cel_img).ravel()
    del cel_img
    tierra = cel > 0
    orden = sorted([e for e in ents if not e['es_estado']], key=lambda e: -e['area_px']) + sorted([e for e in ents if e['es_estado']], key=lambda e: -e['area_px'])
    lab_img = Image.new('I', (RW, RH), 0)
    d = ImageDraw.Draw(lab_img)
    for i, e in enumerate(orden):                         # lo último que se pinta gana: primero los pueblos, y dentro de cada grupo los más grandes
        e['_id'] = i + 1
        for parte in e['partes']:
            poligono(d, parte, i + 1)
    lab = np.asarray(lab_img).ravel()
    L = len(orden)
    key = (cel[tierra].astype(np.int64) - 1) * (L + 1) + lab[tierra]
    cuentas = np.bincount(key, minlength=K * (L + 1)).reshape(K, L + 1)
    mejor = cuentas.argmax(axis=1)
    sin_pixeles = np.nonzero(cuentas.sum(axis=1) == 0)[0]
    for k in sin_pixeles:                                 # celdas más pequeñas que un píxel del raster: manda el punto de su centro
        if not usable[k]:
            continue
        ring = np.asarray(celdas[k]['polygons'][0])
        x, y = int(ring[:, 0].mean() * 2), int(ring[:, 1].mean() * 2)
        mejor[k] = lab[min(max(y, 0), RH - 1) * RW + min(max(x, 0), RW - 1)]
    # un territorio que no ganó ninguna celda se queda con la que más cubre (si cubre algo apreciable), para que los estados chicos no desaparezcan
    for e in orden:
        j = e['_id']
        if (mejor == j).any():
            continue
        col = cuentas[:, j]
        k = int(col.argmax())
        if col[k] >= 10:
            mejor[k] = j
    etiq = [''] * K
    por_id = {e['_id']: e['clave'] for e in orden}
    for k in range(K):
        if usable[k]:
            etiq[k] = por_id.get(int(mejor[k]), '')
    # tierra que cubre cada territorio por sí solo (para saber cuánto conserva tras ceder ante otros)
    solo = {}
    for e in orden:
        im = Image.new('L', (RW, RH), 0)
        dd = ImageDraw.Draw(im)
        for parte in e['partes']:
            poligono(dd, parte, 1)
        solo[e['clave']] = float(np.count_nonzero(np.asarray(im).ravel().astype(bool) & tierra)) / 4.0
    return etiq, solo


# ───────────────────────── 3. Cultura de los nombres y economía ─────────────────────────
def cultura_estado(e):
    """Cultura de nombres (id de nombres_cultura.json) de un estado o pueblo medieval, por región."""
    if e['clave'] in NM.POR_CLAVE:
        return NM.POR_CLAVE[e['clave']]
    lon, lat = e['centro']
    c = e['cont']
    n = e['clave'].lower()
    if c == 'Europa':
        if lon > 30:
            return 'ruso' if lat > 47 else 'turco'
        if lat > 55 and -12 < lon < 31 and not (lon < -1 and lat < 59):
            return 'nordico'
        if lon < -5 and lat > 50 or 'scotland' in n or 'england' in n or 'ireland' in n or 'wales' in n:
            return 'anglo'
        if lat < 44 and lon < 4:
            return 'hispano' if lon < 3.5 or 'catalonia' in n else 'italiano'
        if lon < 8 and lat < 51.5:
            return 'frances'
        if lat < 46.5 and 6 < lon < 19 and 'swiss' not in n:
            return 'italiano'
        if 14 < lon < 24 and 43.3 < lat < 51 and ('hungar' in n or 'croat' in n):
            return 'hungaro' if 'hungar' in n else 'eslavo_sur'
        if 14 < lon < 25 and lat >= 49:
            return 'eslavo_occidental'
        if lat < 43.5 and lon > 19 or (lat < 42 and lon > 15):
            return 'griego' if lon > 20 else 'eslavo_sur'
        if lon > 20 and lat < 48.3:
            return 'rumano' if lat > 43.5 and lon > 22 else 'eslavo_sur'
        if lon > 21 and lat > 53:
            return 'baltico' if lat > 54 else 'ruso'
        return 'aleman'
    if c == 'África':
        if lat > 21 or (lat > 12 and lon > 24 and lon < 40 and lat < 25):
            return 'arabe'
        if lon > 36 and lat > 3 or 'ethiop' in n or 'abyss' in n or 'ajuran' in n or 'adal' in n:
            return 'etiope'
        if lon < 15 and lat > 3:
            return 'africa_occidental'
        if lon > 29 and lat > -12:
            return 'africa_oriental'
        if lat < -17 and lon > 15:
            return 'africa_austral'
        return 'africa_central'
    if c == 'Asia':
        if lat > 45 and 55 < lon < 140 or ('mongol' in n or 'horde' in n or 'khanate' in n and lon > 70) and lat > 38:
            return 'mongol'
        if lon < 44 and 36 < lat < 42 and lon > 25:
            return 'turco'
        if lat < 38 and 33 < lon < 60 and lat > 12:
            return 'persa' if lon > 48 and lat > 25 else 'arabe'
        if lon < 74 and lat > 24:
            return 'turcomano' if lon > 52 and lat > 37 else 'persa'
        if lon < 53:
            return 'arabe' if lat < 30 else 'turco'
        if lon < 100 and lat > 27 and lon > 78:
            return 'india' if lat < 30 else 'mongol'
        if 60 < lon < 90 and lat > 37:
            return 'turcomano'
        if lon < 98 and lat < 36:
            return 'sur_asia_islamico' if ('sultan' in n or 'delhi' in n or 'bahman' in n or 'gujarat' in n or 'bengal' in n or 'malwa' in n) else 'india'
        if lon < 98.5 and lat >= 36:
            return 'mongol'
        if 124 < lon < 132 and lat > 33:
            return 'coreano'
        if lon > 129 and lat > 30:
            return 'japones'
        if lon > 98 and lat > 22 and lon < 124:
            return 'tibetano' if lon < 103 and lat > 28 and 'tibet' in n else 'chino'
        if lat > 5 and lon > 98 and lon < 110 and 'vietnam' in n or 'dai' in n or 'viet' in n:
            return 'vietnamita'
        if lon > 98 and lon < 108 and lat > 10 and lat < 22:
            return 'tailandes' if lon < 104 else 'jemer'
        if lon < 98.5 and lat > 9:
            return 'birmano'
        if lon > 116 and lat < 20 and lon < 128:
            return 'filipino'
        return 'malayo'
    if c == 'América del Norte':
        return 'mesoamericano' if lat < 22 and lon < -85 else 'naturaleza'
    if c == 'América del Sur':
        return 'andino' if lon < -66 and lat > -36 else 'selva'
    if c == 'Oceanía':
        return 'polinesio'
    return 'naturaleza'


TPL_ESTADO = {'Europa': lambda e: 'med' if e['centro'][1] < 45.5 and e['centro'][0] < 31 else 'europa_n'}


def plantilla_med(e):
    c, lat = e['cont'], e['centro'][1]
    if e['clave'] in CE.TPL_CLAVE:
        return CE.TPL[CE.TPL_CLAVE[e['clave']]]
    if e['es_estado'] and c == 'Europa':
        return CE.TPL[TPL_ESTADO['Europa'](e)]
    if e['es_estado'] and c == 'África' and lat > 20:
        return CE.TPL['med']
    if e['es_estado'] and c == 'Asia' and e['centro'][0] < 62 and lat < 34 and e['centro'][0] > 34:
        return CE.TPL['iran'] if e['centro'][0] > 46 else CE.TPL['arabia']
    return CE.plantilla_eco(e)


TASA = {'imperio': 0.0055, 'reino': 0.008, 'reinos': 0.008, 'sultanato': 0.010, 'califato': 0.007, 'emirato': 0.009, 'khanato': 0.03, 'taifa': 0.009,
        'confederación nómada': 0.035, 'confederación': 0.015, 'ciudades-estado': 0.010, 'república': 0.007, 'principado': 0.009, 'ducado': 0.009,
        'condado': 0.009, 'electorado': 0.008, 'tribus': 0.015, 'confederación tribal': 0.02, 'reino tribal': 0.015, 'cultura': 0.006,
        'cazadores-recolectores': 0.008, 'repúblicas tribales': 0.012}


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--anio', type=int, required=True, choices=[1096, 1500])
    ap.add_argument('--celdas', default='/tmp/ge_b1/celdas', help='carpeta celdas/ de una corrida de construir_epoca.py --build')
    ap.add_argument('--build', default=None)
    ap.add_argument('--out', default=None)
    ap.add_argument('--min-area', type=float, default=AREA_MIN_PROV, help='área mínima (px²) de una provincia antes de agruparla con una vecina')
    ap.add_argument('--png', default=None, help='dibuja el reparto (colores por nación) en este PNG')
    args = ap.parse_args()
    anio = args.anio
    prefijo = 'e%d_' % anio
    build = args.build or '/tmp/ge_build_%d' % anio
    salida = args.out or os.path.join(BASE, 'epocas', str(anio))
    shutil.rmtree(build, ignore_errors=True)
    os.makedirs(build)
    t0 = time.time()
    CE.FIJOS = {}
    print('1. Territorios de %d' % anio)
    ents = territorios(anio)
    print('   %d estados + %d pueblos' % (sum(1 for e in ents if e['es_estado']), sum(1 for e in ents if not e['es_estado'])))
    print('2. Celdas del mundo')
    celdas = json.load(open(os.path.join(args.celdas, 'fuente_provincias.json'), encoding='utf-8'))
    ani_c = json.load(open(os.path.join(args.celdas, 'provincias_juego.json'), encoding='utf-8'))['anillos']
    hoy_pj = json.load(open(os.path.join(BASE, 'provincias_juego.json'), encoding='utf-8'))
    assert len(hoy_pj['anillos']) == len(ani_c), 'las celdas no son las del juego (¿otra corrida?)'
    for a, b in zip(ani_c, hoy_pj['anillos']):
        assert (a['v0'], a['n'], a['i0'], a['i1']) == (b['v0'], b['n'], b['i0'], b['i1']), 'la geometría de las celdas no coincide con datos/'
    K = len(celdas)
    padre = [-1] * K
    for a, b in zip(ani_c, hoy_pj['anillos']):
        padre[a['u']] = b['p']
    usable = [p >= 0 for p in padre]
    print('   %d celdas (%d sin anillo)' % (K, usable.count(False)))
    base = json.load(open(os.path.join(BASE, 'fuente_provincias.json'), encoding='utf-8'))
    juego_hoy = hoy_pj['provincias']
    info_hoy = json.load(open(os.path.join(BASE, 'info.json'), encoding='utf-8'))['prov']
    t1 = time.time()
    etiq, solo = repartir(ents, celdas, usable)
    print('   reparto por mayoría en %.1f s' % (time.time() - t1))
    area_c = [abs(CE.area_poly([tuple(q) for q in celdas[k]['polygons'][0]])) for k in range(K)]
    final = {}
    for k in range(K):
        if usable[k] and etiq[k]:
            final[etiq[k]] = final.get(etiq[k], 0.0) + area_c[k]
    retiene = {}
    for e in ents:
        k = e['clave']
        a_f, a_s = final.get(k, 0.0), solo.get(k, 0.0)
        if a_f < 3.0 or a_s <= 0:
            retiene[k] = 0.0
            if e['es_estado']:
                print('   · %s desaparece: su tierra la reclaman otros (%.1f px² de %.0f)' % (e['nombre'], a_f, a_s))
        else:
            retiene[k] = min(1.0, a_f / a_s)
            if retiene[k] > 0.97:
                retiene[k] = 1.0
    for e in ents:
        e['pob'] = e['pob'] * retiene[e['clave']]
    for k in range(K):
        if etiq[k] and retiene[etiq[k]] == 0.0:
            etiq[k] = ''
    # piezas = celdas de la misma provincia de hoy y el mismo territorio
    grupos = {}
    for k in range(K):
        if usable[k]:
            grupos.setdefault((padre[k], etiq[k]), []).append(k)
    items = []
    for (p, clave), ks in sorted(grupos.items()):
        rings = [celdas[k]['polygons'][0] for k in ks]
        conts = [celdas[k]['cont_anillos'][0] for k in ks]
        ar = [area_c[k] for k in ks]
        mayor = max(range(len(ks)), key=lambda i: ar[i])
        items.append({'padre': p, 'e': clave, 'sub': 0, 'r': rings, 'rp': list(ks), 'conts': conts, 'a': sum(ar), 'amax': ar[mayor], 'c': conts[mayor],
                      'nombre': juego_hoy[p]['n'], 'id': '', 'miembros': [(p, sum(ar))], 'par_id': base[p]['id']})
    estados_k = {e['clave'] for e in ents if e['es_estado']}
    ganado = CE.reclamar_huecos(items, lambda p_: CE.hab_pieza(info_hoy[p_]), lambda k: k in estados_k, lambda c: c != 'Antártida')
    por_clave_e = {e['clave']: e for e in ents}
    orig_w = {}
    for it in items:
        if it['e'] != '':
            orig_w[it['e']] = orig_w.get(it['e'], 0.0) + it['a'] * CE.hab_pieza(info_hoy[it['padre']])
    for k, (a_g, w_g) in ganado.items():
        e = por_clave_e.get(k)
        if e is None:
            continue
        w0 = max(orig_w.get(k, 0.0) - w_g, 1.0)
        e['pob'] = e['pob'] * min(CE.MAX_CRECE_POB, 1.0 + w_g / w0)
    ids_usados = set()
    for it in items:
        pid = '%s~%s' % (it['par_id'], it['e'] or 'sr')
        while pid in ids_usados:
            pid += '+'
        ids_usados.add(pid)
        it['id'] = pid
    n0 = len(items)
    items = CE.agrupar(items, lambda it: CE.AREA_AGRUPAR_VACIO if it['e'] == '' else args.min_area)
    usadas = {it['e'] for it in items if it['e']}
    ents = [e for e in ents if e['clave'] in usadas]
    por_clave = {e['clave']: e for e in ents}
    nombre_de = {e['clave']: e['nombre'] for e in ents}
    nuevas, meta = [], []
    tab_esc = [-1] * K
    for it in items:
        clave = it['e']
        nac = CE.nombre_sin_reclamar(it['c']) if clave == '' else nombre_de[clave]
        mayor = max(range(len(it['r'])), key=lambda i: abs(CE.area_poly([tuple(q) for q in it['r'][i]])))
        r0 = it['r'][mayor]
        cen = [round(sum(q[0] for q in r0) / len(r0), 2), round(sum(q[1] for q in r0) / len(r0), 2)]
        nuevas.append({'id': it['id'], 'name': it['nombre'], 'country': nac, 'country_es': nac, 'a3': '', 'continent': it['conts'][mayor], 'center': cen,
                       'polygons': it['r'], 'cont_anillos': it['conts'], 'mudo': clave == '', 'padres': [padre[k] for k in it['rp']]})
        meta.append({'padre': it['padre'], 'clave': clave, 'nac': nac, 'area_px': it['a'], 'cont': it['conts'][mayor], 'miembros': it['miembros']})
        for k in it['rp']:
            tab_esc[k] = len(nuevas) - 1
    print('   %d piezas → %d provincias de %d · %d naciones con tierra' % (n0, len(nuevas), anio, len(ents)))
    json.dump(nuevas, open(os.path.join(build, 'fuente_provincias.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('3. Colores')
    color, ady = CE.asignar_colores(ents, nuevas, meta)
    if args.png:
        pintar(args.png, celdas, usable, tab_esc, meta, color)
    print('4. Mapa por provincias (construir_mapa.py)')
    shutil.copy(os.path.join(BASE, 'lagos_fuente.json'), os.path.join(build, 'lagos_fuente.json'))
    env = dict(os.environ, GE_DATOS=build)
    CE.correr([sys.executable, '-I', os.path.join(HERR, 'construir_mapa.py')], env=env, etiqueta='construir_mapa')
    juego = json.load(open(os.path.join(build, 'provincias_juego.json'), encoding='utf-8'))
    assert [p['id'] for p in juego['provincias']] == [p['id'] for p in nuevas]
    print('5. Datos de juego')
    base_info = json.load(open(os.path.join(BASE, 'info.json'), encoding='utf-8'))
    filas = CE.construir_info(por_clave, nuevas, meta, base_info)
    prov_de = {}
    for i, m in enumerate(meta):
        prov_de.setdefault(m['nac'], []).append(i)
    inertes = sorted(n for n in prov_de if n.startswith('Tierras sin reclamar'))
    for e in ents:
        xs, ys, ws = [], [], []
        for i in prov_de[e['nombre']]:
            for r in nuevas[i]['polygons']:
                a = np.asarray(r)
                xs.append(a[:, 0].mean())
                ys.append(a[:, 1].mean())
                ws.append(abs(CE.area_poly([tuple(q) for q in r])))
        w = np.asarray(ws)
        cx = float(np.average(xs, weights=w)) if w.sum() > 0 else 0
        cy = float(np.average(ys, weights=w)) if w.sum() > 0 else 0
        e['centro'] = (cx / ESC - 180.0, 90.0 - cy / ESC)
    paises = {}
    for e in ents:
        lst = prov_de[e['nombre']]
        rings = [(abs(CE.area_poly([tuple(q) for q in r])), r) for i in lst for r in nuevas[i]['polygons']]
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
                               'bandera': prefijo + CE.slug(e['clave']), 'col': color[e['clave']], 'foco': foco, 'tipo': e.get('tipo', ''),
                               'desde': e.get('desde'), 'hasta': e.get('hasta'), 'fuente': e['fuente']}
    for nom in inertes:
        lst = prov_de[nom]
        cont = meta[lst[0]]['cont']
        rings = [r for i in lst for r in nuevas[i]['polygons']]
        xs = [q[0] for r in rings for q in r]
        ys = [q[1] for r in rings for q in r]
        paises[nom] = {'a3': '', 'cont': cont, 'cap': 'Sin capital', 'div': 'Territorios', 'bandera': 'x', 'col': '3b3f46',
                       'foco': [round(min(xs), 2), round(min(ys), 2), round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2)],
                       'tipo': 'sin reclamar', 'sin_reclamar': True}
    info_pais, info_cont = {}, {}
    for nom, lst in prov_de.items():
        d = CE.agregar(filas, lst)
        e = next((v for v in por_clave.values() if v['nombre'] == nom), None)
        d['cont'] = paises[nom]['cont']
        d['etn'] = [[g, float(p)] for g, p in e['etn']] if e else []
        info_pais[nom] = d
    por_cont = {}
    for nom, lst in prov_de.items():
        por_cont.setdefault(paises[nom]['cont'], []).extend(lst)
    for cont, lst in por_cont.items():
        d = CE.agregar(filas, lst)
        d['paises'] = sum(1 for n in prov_de if paises[n]['cont'] == cont)
        info_cont[cont] = d
    info = {'anio': anio, 'prov': filas, 'pais': info_pais, 'cont': info_cont, 'biomas': base_info['biomas'], 'reinos': base_info['reinos'],
            'niv_m': base_info['niv_m'], 'estado': {}}
    json.dump(info, open(os.path.join(build, 'info.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    eco = {'pais': {}, 'region': {}}
    for e in ents:
        c, ca, m, rub = plantilla_med(e)
        eco['pais'][e['nombre']] = {'cult': c, 'carne': ca, 'mat': m, 'rub': rub, 'nivel': 'r'}
    json.dump(eco, open(os.path.join(build, 'economia.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    div = {'divisas': {c: {'n': v[0], 's': v[1], 'u': v[2]} for c, v in ME.DIVISAS.items()}, 'paises': {}, 'tasa_fiscal': 0.25, 'version': str(anio)}
    for e in ents:
        pob = info_pais[e['nombre']]['pob']
        div['paises'][e['nombre']] = {'d': e['moneda'], 'pib': int(pob * e['pib_pc']), 'pob': pob}
    json.dump(div, open(os.path.join(build, 'divisas.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    banderas = {'paises': {n: paises[n]['bandera'] for n in paises if not paises[n].get('sin_reclamar')}, 'provincias': {}, 'estados': {}, 'ciudades': {}}
    json.dump(banderas, open(os.path.join(build, 'banderas.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    tasas = {e['nombre']: TASA.get(e.get('tipo', ''), 0.01) for e in ents}
    ej = {'version': str(anio), 'ayuda': 'Soldados de cada nación al empezar el año %d: población × tasa. Estimaciones de orden de magnitud.' % anio,
          'tasa_defecto': 0.01, 'tasas': tasas, 'sin_ejercito': inertes}
    json.dump(ej, open(os.path.join(build, 'ejercito.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('6. Ciudades')
    try:
        import datos_medieval_ciudades as MC
        ciudades = MC.CIUDADES[anio]
    except ImportError:
        ciudades = []
    loc = CE.Localizador(nuevas)
    nacs = sorted(paises)
    idx_nac = {n: i for i, n in enumerate(nacs)}
    filas_c, usados, aviso = [], set(), []

    def anadir(nombre, lon, lat, pop, rango, nac_forzada=None):
        x, y = (lon + 180.0) * ESC, (90.0 - lat) * ESC
        pi, dd = loc.provincia(x, y, margen=3.0)
        if pi < 0 or dd > 3.0:
            aviso.append('%s fuera de toda tierra (%.1f px)' % (nombre, dd))
            return None
        nac = meta[pi]['nac']
        if nac_forzada is not None and nac != nac_forzada:
            mejor, md = None, 1e9
            for j in prov_de[nac_forzada]:
                for r in nuevas[j]['polygons']:
                    a = np.asarray(r)
                    d2 = float(np.min(np.hypot(a[:, 0] - x, a[:, 1] - y)))
                    if d2 < md:
                        md, mejor = d2, (j, a)
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
        filas_c.append([nombre, round(x, 2), round(y, 2), int(pop), rango, idx_nac[nac], pi, CE.zoom_ciudad(pop, rango == 2, rango == 1)])
        usados.add(nombre)
        return nac

    pop_de = {c[0]: c[3] for c in ciudades}
    for e in ents:
        if e.get('cap'):
            nombre, lon, lat = e['cap']
            anadir(nombre, lon, lat, pop_de.get(nombre, 5000), 2, nac_forzada=e['nombre'])
    for nombre, lon, lat, pop in ciudades:
        if nombre in usados:
            continue
        anadir(nombre, lon, lat, pop, 1 if pop >= 50000 else 0)
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
    json.dump({'paises': paises, 'version': '%d-0.1.8.42' % anio, 'esquema_colores': 'propio'}, open(os.path.join(build, 'entidades.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))
    print('   %d ciudades' % len(filas_c))
    print('7. Vecindad e IDs')
    CE.correr([sys.executable, '-I', os.path.join(HERR, 'construir_vecinos.py')], env=env, etiqueta='construir_vecinos')
    if os.path.exists(os.path.join(build, 'ids.json')):
        os.remove(os.path.join(build, 'ids.json'))
    CE.correr([sys.executable, '-I', os.path.join(HERR, 'construir_ids.py')], env=env, etiqueta='construir_ids')
    for e in ents:                                                         # cultura de los nombres de mandos
        NM.POR_CLAVE[e['clave']] = cultura_estado(e)
    NM.escribir_nombres(build, ents, paises)
    js = json.load(open(os.path.join(build, 'nombres_cultura.json'), encoding='utf-8'))
    js['version'] = '%d-0.1.8.42' % anio
    js['ayuda'] = js.get('ayuda', '').split(' · Escenario')[0] + ' · Escenario %d: añade las culturas históricas (latina, han, parta, celta...) y reparte las naciones de la época entre ellas.' % anio
    json.dump(js, open(os.path.join(build, 'nombres_cultura.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    pob_mundo = int(sum(info_cont[c]['pob'] for c in info_cont))
    meta_ep = {'anio': anio, 'nombre': NOMBRE_EPOCA[anio], 'esquema_colores': 'propio', 'reloj': [anio, 1, 1], 'descripcion': DESCRIPCION[anio],
               'creditos': ['Fronteras de los estados: Cliopatria v0.2.1, Seshat Global History Databank (CC BY 4.0), https://github.com/Seshat-Global-History-Databank/cliopatria — adaptadas a las celdas del juego.',
                            'Pueblos y culturas sin estado, poblaciones, ciudades y economía: estimaciones propias de este proyecto.'],
               'naciones': len(ents), 'provincias': len(nuevas), 'pob_mundo': pob_mundo}
    json.dump(meta_ep, open(os.path.join(build, 'epoca.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('8. Copia al paquete y banderas')
    os.makedirs(salida, exist_ok=True)
    nopaq = ('fuente_provincias.json', 'lagos_fuente.json', 'territorios.json', 'piezas.json', 'teselas.json', 'malla_meta.json', 'provincias_juego.json', 'celdas')
    for f in sorted(os.listdir(build)):
        if f in nopaq or (f.startswith('malla_') and not f.startswith('malla_estado')):
            continue
        ruta = os.path.join(build, f)
        if not os.path.isdir(ruta):
            shutil.copy(ruta, os.path.join(salida, f))
    pj_esc, vac = CE.ensamblar_provincias(juego['provincias'], ani_c, tab_esc)
    json.dump(pj_esc, open(os.path.join(salida, 'provincias_juego.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    bdir = os.path.join(RAIZ, 'banderas')
    bdir_hd = os.path.join(RAIZ, 'banderas_hd')
    os.makedirs(bdir_hd, exist_ok=True)
    for e in ents:
        CE.hacer_bandera(e['clave'], color[e['clave']], os.path.join(bdir, paises[e['nombre']]['bandera'] + '.png'))
        CE.hacer_bandera(e['clave'], color[e['clave']], os.path.join(bdir_hd, paises[e['nombre']]['bandera'] + '.png'), ancho=256)
    tot = {c: info_cont[c]['pob'] / 1e6 for c in info_cont}
    libre = sum(info_pais[n]['area'] for n in inertes) / max(1, sum(v['area'] for v in info_pais.values()))
    print('Listo %d: %d naciones, %d provincias (%d sin celda), %d ciudades, población %.1f M · tierra libre %.0f %% · %.0f s' % (
        anio, len(ents), len(nuevas), vac, len(filas_c), pob_mundo / 1e6, 100 * libre, time.time() - t0))
    print('   por continente (M):', {c: round(v, 1) for c, v in sorted(tot.items())})


def pintar(ruta, celdas, usable, tab_esc, meta, color):
    im = Image.new('RGB', (2400, 1200), (12, 24, 40))
    d = ImageDraw.Draw(im)
    for k, c in enumerate(celdas):
        if not usable[k] or tab_esc[k] < 0:
            continue
        m = meta[tab_esc[k]]
        col = (70, 74, 82) if m['clave'] == '' else CE.hexc(color[m['clave']])
        d.polygon([tuple(q) for q in c['polygons'][0]], fill=col)
    im.save(ruta)


if __name__ == '__main__':
    sys.exit(main())
