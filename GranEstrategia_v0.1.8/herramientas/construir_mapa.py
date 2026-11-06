#!/usr/bin/env python3
"""
Genera los datos de mapa para Gran Estrategia v0.1.7.9 (fuera de Godot) para que el juego cargue rápido y corra fluido.

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
from geom import limpiar, dividir_autointersecciones, area_firmada, triangular, simplificar_segmentos
from nombres_es import PAISES_ES, PROVINCIAS_ES
from tablas_estados import ESTADOS_US

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.environ.get('GE_DATOS') or os.path.join(RAIZ, 'datos')   # 0.1.8.34: GE_DATOS = carpeta de un escenario (p. ej. datos/epocas/1dc)
# 0.1.8.35 · Modo CELDAS (GE_CELDAS=1): la «fuente» no son provincias sino las CELDAS del mundo (una celda = un anillo = una unidad de dibujo).
# Se generan las mallas de relleno, pares de celdas vecinas, costas y bordes continentales; no hay etiquetas ni estados (eso es de las provincias del
# escenario). Cada anillo del resultado lleva `u` = posición de su celda en la fuente, para que el generador de escenarios sepa a qué provincia pertenece.
CELDAS = os.environ.get('GE_CELDAS') == '1'
ANCHO_MAPA = 2400.0
Y_ECUADOR = 600.0   # proyección equirectangular: el ecuador está en la mitad del mapa (1200/2)

# ───────────────────────── Colores ─────────────────────────
def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

# 0.1.8.37: paleta renovada (ver herramientas/renovar_paleta.py, que pone estos mismos colores en datos ya generados)
COLOR_CONT = {
    'Europa': hexc('#4f83d1'), 'Asia': hexc('#d15147'), 'África': hexc('#d1a63f'),
    'América del Sur': hexc('#d1763f'), 'América del Norte': hexc('#58d174'),
    'Oceanía': hexc('#9764d1'), 'Antártida': hexc('#b8c5d1'),
}
# (matiz, saturación base, variación de matiz permitida)
BASE_PAIS = {  # ajusta aquí los colores base de cada continente en zoom-in
    'Europa': (0.600, 0.62, 0.040), 'África': (0.118, 0.70, 0.022), 'Asia': (0.012, 0.66, 0.030),
    'América del Sur': (0.063, 0.70, 0.022), 'América del Norte': (0.372, 0.58, 0.040),
    'Oceanía': (0.745, 0.52, 0.035), 'Antártida': (0.580, 0.12, 0.01),
}

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def mezclar_colores(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def color_continental(cont, x, y):
    """
    0.1.7.9.1: color SÓLIDO por continente (sin degradado). Todo país y provincia lleva el color de su continente.
    (x, y se conservan en la firma por compatibilidad.)
    """
    return COLOR_CONT[cont]

def jitter(txt, n):
    h = hashlib.md5(txt.encode('utf-8')).digest()
    return [h[i] / 127.5 - 1.0 for i in range(n)]

def color_pais(cont, pais, cy, prov_id, es_provincia_extra):
    """0.1.7.9.1: color sólido del continente (sin variación por país, por provincia ni por latitud)."""
    h, s, dh = BASE_PAIS[cont]
    return colorsys.hsv_to_rgb(h, s, 0.82)

# ───────────────────────── Carga ─────────────────────────
def continente_anillo(p, cx, cy):
    c = p['continent']
    pais = p['country']
    nombre = str(p.get('name', '')).lower()
    identificador = str(p.get('id', '')).lower()
    if pais == 'Russia' and cx >= 1600.0:
        return 'Asia'                 # al este de los Urales
    if pais == 'Russia':
        return 'Europa'
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
    if pais == 'Indonesia' and 'papua' in nombre:
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
        pais_es = p.get('country_es') or PAISES_ES.get(p['country']) or p['country']
        nom_es = PROVINCIAS_ES.get(p['name'], p['name'])
        if cuenta_pais[p['country']] == 1:
            nom_es = pais_es
        estado = p.get('estado')                       # 0.1.8.34: los escenarios de otras épocas traen su propia división intermedia
        if p.get('a3') == 'USA':                      # 0.1.7.9: capa de estados de EE. UU. (FIPS = primeras cifras del id)
            estado = ESTADOS_US.get(int(p['id'].split('_')[1]) // 1000, (None, None))[1]
        provincias.append({'id': p['id'], 'n': nom_es, 'c': pais_es, 'pais_en': p['country'], 'e': estado,
                           'm': cuenta_pais[p['country']] > 1, 'cont': p['continent'], 'a3': p.get('a3', ''), 'r': [],
                           'mudo': bool(p.get('mudo'))})      # mudo = tierra sin reclamar: no lleva nombre en el mapa
        conts_anillo = p.get('cont_anillos')
        for ir, r in enumerate(p['polygons']):
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
                anillos.append({'pi': pi, 'pts': lazo, 'area': abs(a),
                                'cont': conts_anillo[ir] if conts_anillo else continente_anillo(p, cx, cy)})
    anillos.sort(key=lambda r: -r['area'])   # grandes primero (los enclaves pequeños quedan encima)
    if CELDAS:
        # cada anillo es su propia unidad: la unidad k es el anillo k (así runs, pares y relleno hablan de «celda k» = anillo k)
        unidades = []
        for ri, r in enumerate(anillos):
            u = dict(provincias[r['pi']])
            u['r'] = []
            unidades.append(u)
            r['u'] = r['pi']
            r['pi'] = ri
        provincias = unidades
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
    V, I, CC, CP, PV = [], [], [], [], []   # vértices, índices, color continental, color país, provincia de cada vértice
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
            PV.append(r['pi'])
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

    cats = {'costa': [], 'frontera': [], 'prov': [], 'cont': [], 'ea': [], 'estado': []}   # 'ea' = Europa–Asia (se dibuja solo al acercar)
    pares_seg = {}        # (provincia menor, provincia mayor) -> segmentos (a, b) de su frontera común (0.1.7.9.9F)

    def anadir_par(i1, i2, a, b):
        k = (i1, i2) if i1 < i2 else (i2, i1)
        pares_seg.setdefault(k, []).append((a, b))

    def anadir_interno(p1, p2, a, b):
        cats['prov'].append((a, b, p1['c']))
        if p1['e'] and p2['e'] and p1['e'] != p2['e']:
            cats['estado'].append((a, b, p1['c']))

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
            anadir_par(e1[1], e2[1], a, b)
            if p1['pais_en'] != p2['pais_en']:
                cats['frontera'].append((a, b))
            else:
                anadir_interno(p1, p2, a, b)
            if grupo(anillos[e1[0]]['cont']) != grupo(anillos[e2[0]]['cont']):
                cats['cont'].append((a, b))
            elif anillos[e1[0]]['cont'] != anillos[e2[0]]['cont']:
                cats['ea'].append((a, b))
        elif len(lst) == 1:
            singles.append(lst[0])
        # una arista repetida solo dentro de la misma provincia se ignora

    # Aristas "casi compartidas" (vecinos con vértices desalineados, p.ej. España)
    TOL = 0.3
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
        else:
            seal.append((e[0], a, b))
            # dibuja solo una vez (la provincia con índice menor)
            if (e[1], e[0]) < (cercano[1], cercano[0]):
                p1, p2 = provincias[e[1]], provincias[cercano[1]]
                anadir_par(e[1], cercano[1], a, b)
                if p1['pais_en'] != p2['pais_en']:
                    cats['frontera'].append((a, b))
                else:
                    anadir_interno(p1, p2, a, b)
                if grupo(anillos[e[0]]['cont']) != grupo(anillos[cercano[0]]['cont']):
                    cats['cont'].append((a, b))
                elif anillos[e[0]]['cont'] != anillos[cercano[0]]['cont']:
                    cats['ea'].append((a, b))
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
            PV.append(r['pi'])
        I.extend((b0, b0 + 1, b0 + 2, b0 + 1, b0 + 3, b0 + 2))

    # ───────────── Mallas de bordes ─────────────
    def encadenar(segs):
        """Ordena segmentos (a,b) en cadenas contiguas y devuelve (a, b, dist_a, dist_b)."""
        key = lambda p: (round(p[0], 1), round(p[1], 1))
        ady = {}
        for i, (a_, b_) in enumerate(segs):
            ady.setdefault(key(a_), []).append(i)
            ady.setdefault(key(b_), []).append(i)
        usado = [False] * len(segs)
        salida = []
        for i0 in range(len(segs)):
            if usado[i0]:
                continue
            usado[i0] = True
            a_, b_ = segs[i0]
            d = 0.0
            cadena = [(a_, b_)]
            actual = b_
            while True:
                nxt = None
                for j in ady.get(key(actual), []):
                    if not usado[j]:
                        nxt = j
                        break
                if nxt is None:
                    break
                usado[nxt] = True
                pa, pb = segs[nxt]
                if key(pa) != key(actual):
                    pa, pb = pb, pa
                cadena.append((pa, pb))
                actual = pb
            for (pa, pb) in cadena:
                L = math.hypot(pb[0] - pa[0], pb[1] - pa[1])
                if L < 1e-6:
                    continue
                salida.append((pa, pb, d, d + L))
                d += L
        return salida

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

    # ── Teselas (0.1.7.9): todas las mallas grandes se trocean en una cuadrícula de 300x300 unidades de mapa.
    # Cada tesela es un MeshInstance2D independiente en Godot, así el motor descarta las que no se ven (culling).
    TW = TH = 300.0
    COSTA_LOD = ((1, 0.4), (2, 1.0))      # (nivel, tolerancia en unidades de mapa): 1 = intermedio, 2 = lejano
    NTX = int(ANCHO_MAPA // TW)

    def clave_tesela(x, y):
        tx = np.clip((x // TW).astype(int), 0, NTX - 1)
        ty = np.clip((y // TH).astype(int), 0, 3)
        return ty * NTX + tx

    def trocear_tris(Vn, In, attrs):
        tri = In.reshape(-1, 3)
        cen = Vn[tri].mean(axis=1)
        key = clave_tesela(cen[:, 0], cen[:, 1])
        out = []
        for k in np.unique(key):
            sel = tri[key == k].reshape(-1)
            uniq, inv = np.unique(sel, return_inverse=True)
            out.append((int(k % NTX), int(k // NTX), Vn[uniq], inv.astype(np.int32), {n: a_[uniq] for n, a_ in attrs.items()}))
        return out

    def trocear_quads(Vq, UVq):
        nq = len(Vq) // 4
        v4 = Vq.reshape(nq, 4, 2)
        uv4 = UVq.reshape(nq, 4, 2)
        mid = (v4[:, 0] + v4[:, 2]) * 0.5
        key = clave_tesela(mid[:, 0], mid[:, 1])
        patron = np.array([0, 1, 2, 1, 3, 2], dtype=np.int32)
        out = []
        for k in np.unique(key):
            ids_q = np.nonzero(key == k)[0]
            m = len(ids_q)
            Vt = v4[ids_q].reshape(-1, 2)
            UVt = uv4[ids_q].reshape(-1, 2)
            It = (np.arange(m, dtype=np.int32)[:, None] * 4 + patron[None, :]).reshape(-1)
            out.append((int(k % NTX), int(k // NTX), Vt, It, {'uv': UVt}))
        return out

    class Acum:
        """Concatena teselas en un conjunto de .bin y devuelve el índice [tx,ty,v0,nv,i0,ni]."""
        def __init__(self):
            self.v, self.i, self.at, self.nv, self.ni = [], [], {}, 0, 0
        def agregar(self, tiles):
            res = []
            for (tx, ty, Vt, It, At) in tiles:
                res.append([tx, ty, self.nv, len(Vt), self.ni, len(It)])
                self.v.append(Vt.astype('<f4').reshape(-1))
                self.i.append(It.astype('<i4'))
                for n, a_ in At.items():
                    self.at.setdefault(n, []).append(a_)
                self.nv += len(Vt)
                self.ni += len(It)
            return res
        def guardar(self, prefijo):
            guardar(prefijo + '_v.bin', np.concatenate(self.v) if self.v else np.zeros(0, '<f4'))
            guardar(prefijo + '_i.bin', np.concatenate(self.i) if self.i else np.zeros(0, '<i4'))
            for n, lst in self.at.items():
                arr = np.concatenate(lst)
                if n == 'uv':
                    guardar(prefijo + '_uv.bin', arr.astype('<f4').reshape(-1))
                else:
                    guardar(prefijo + '_' + n + '.bin', arr.astype('u1').reshape(-1))

    # Relleno: archivos originales (solo para clic y resaltado; Godot los lee bajo demanda) + versión en teselas con colores
    Vn = np.array(V, dtype='<f4').reshape(-1, 2)
    In = np.array(I, dtype='<i4')
    guardar('malla_fill_v.bin', Vn.reshape(-1))
    guardar('malla_fill_i.bin', In)
    CCn = (np.array(CC) * 255).round().astype('u1')
    CPn = (np.array(CP) * 255).round().astype('u1')
    PVn = np.array(PV, dtype='<u2').view('u1').reshape(-1, 2)         # provincia de cada vértice (2 bytes, little endian)
    ac = Acum()
    t_fill = ac.agregar(trocear_tris(Vn, In, {'cc': CCn, 'cp': CPn, 'pv': PVn}))
    ac.guardar('malla_filt')
    ruta_pv = os.path.join(DATOS, 'malla_filt_pv.bin')
    if os.path.exists(ruta_pv):
        os.remove(ruta_pv)                       # el mapa vértice -> provincia solo sirve para calcular los runs (abajo)
    # 0.1.7.9.9F: "runs" = tramos contiguos de vértices del relleno que pertenecen a la MISMA provincia (anillos y sellos).
    # Godot los usa para recolorear una provincia que cambia de dueño sin tocar el resto de la tesela.
    # Formato int32: [n_prov + 1 desplazamientos (en runs)] + [tesela, vértice global inicial, cantidad] por run, ordenados por provincia.
    pv_t = ac.at['pv']
    runs = []
    for ti, (tx_, ty_, v0_, nv_, i0_, ni_) in enumerate(t_fill):
        a2 = pv_t[ti].astype(np.int64)
        prov_t = a2[:, 0] | (a2[:, 1] << 8)
        corte = np.concatenate(([0], np.flatnonzero(np.diff(prov_t) != 0) + 1, [len(prov_t)]))
        for j in range(len(corte) - 1):
            runs.append((int(prov_t[corte[j]]), ti, v0_ + int(corte[j]), int(corte[j + 1] - corte[j])))
    runs.sort(key=lambda q: (q[0], q[1], q[2]))
    ofs = np.zeros(len(provincias) + 1, dtype='<i4')
    for q in runs:
        ofs[q[0] + 1] += 1
    ofs = np.cumsum(ofs).astype('<i4')
    cuerpo = np.array([[q[1], q[2], q[3]] for q in runs], dtype='<i4').reshape(-1)
    guardar('malla_filt_runs.bin', np.concatenate([ofs, cuerpo]).astype('<i4'))
    print('runs de relleno', len(runs), 'vértices en runs', sum(q[3] for q in runs), 'de', len(V))
    for viejo in ('malla_fill_cc.bin', 'malla_fill_cp.bin'):
        if os.path.exists(os.path.join(DATOS, viejo)):
            os.remove(os.path.join(DATOS, viejo))
    meta['fill'] = {'verts': len(V), 'indices': len(I), 'teselas': len(t_fill)}
    indice_teselas = {'tw': TW, 'th': TH, 'fill': t_fill}

    # 0.1.7.9.9F: las fronteras entre países y las líneas de provincia ya NO se hornean por categoría: se guardan TODAS las
    # aristas tierra-tierra agrupadas por par de provincias vecinas, y Godot arma la frontera según el dueño actual de cada una.
    os.makedirs(DATOS, exist_ok=True)
    claves_par = sorted(pares_seg)
    seg_par, tabla_par, dist_par = [], [], []
    for (i1_, i2_) in claves_par:
        util = [(a_, b_) for (a_, b_) in pares_seg[(i1_, i2_)] if math.hypot(b_[0] - a_[0], b_[1] - a_[1]) >= 1e-6]
        if not util:
            continue
        # 0.1.7.9.9F-d: los segmentos de cada par se ordenan en cadenas y llevan su distancia recorrida (para la frontera «franjada»)
        cadena_par = encadenar(util)
        if not cadena_par:
            continue
        tabla_par.append((i1_, i2_, len(seg_par), len(cadena_par)))
        for (pa_, pb_, d0_, d1_) in cadena_par:
            seg_par.append((pa_, pb_))
            dist_par.append((d0_, d1_))
    v_par, uv_par, _ids = malla_borde(seg_par)
    guardar('malla_par_v.bin', v_par)
    guardar('malla_par_uv.bin', uv_par)
    guardar('malla_par_i.bin', _ids)            # patrón [0,1,2,1,3,2] + 4k: sirve para cualquier prefijo de segmentos
    col_par = np.zeros((len(seg_par) * 4, 3), dtype='u1')   # distancia acumulada codificada en 2 canales de color (igual que malla_cont_c.bin)
    for k_, (d0_, d1_) in enumerate(dist_par):
        for j_, dist_ in enumerate((d0_, d0_, d1_, d1_)):
            di_ = int(dist_ * 20) % 65025
            col_par[k_ * 4 + j_] = (di_ // 255, di_ % 255, 0)
    guardar('malla_par_c.bin', col_par.reshape(-1))
    guardar('malla_par_tab.bin', np.array(tabla_par, dtype='<i4').reshape(-1))
    meta['par'] = {'pares': len(tabla_par), 'segmentos': len(seg_par)}
    # comprobación: los pares de países distintos son exactamente las fronteras que se dibujaban antes
    n_front = sum(len(pares_seg[(a_, b_)]) for (a_, b_) in claves_par if provincias[a_]['pais_en'] != provincias[b_]['pais_en'])
    print('pares', len(tabla_par), 'segmentos', len(seg_par), '| frontera antes', len(cats['frontera']), 'por pares', n_front)
    for viejo in [f for f in os.listdir(DATOS) if f.startswith('malla_frontera_') or f.startswith('malla_prov_')] + ['prov_rangos.json']:
        ruta_v = os.path.join(DATOS, viejo)
        if os.path.exists(ruta_v):
            os.remove(ruta_v)

    for cat in ('costa', 'cont', 'ea', 'estado'):
        segs = cats[cat]
        if cat == 'estado':
            continue
        if cat in ('cont', 'ea'):
            segs = encadenar(segs)
        v, uv, ids = malla_borde([(s_[0], s_[1]) for s_ in segs])
        if cat in ('cont', 'ea'):
            guardar('malla_%s_v.bin' % cat, v)
            guardar('malla_%s_uv.bin' % cat, uv)
            guardar('malla_%s_i.bin' % cat, ids)
            meta[cat] = {'verts': len(v) // 2, 'indices': len(ids)}
            # distancia acumulada (para el patrón de franjas), codificada en 2 canales de color
            col = np.zeros((len(segs) * 4, 3), dtype='u1')
            for k, s_ in enumerate(segs):
                for j, dist in enumerate((s_[2], s_[2], s_[3], s_[3])):
                    di = int(dist * 20) % 65025
                    col[k * 4 + j] = (di // 255, di % 255, 0)
            guardar('malla_%s_c.bin' % cat, col.reshape(-1))
            continue
        ac = Acum()
        tt = ac.agregar(trocear_quads(v.reshape(-1, 2), uv.reshape(-1, 2)))
        ac.guardar('malla_' + cat)
        indice_teselas[cat] = tt
        meta[cat] = {'verts': ac.nv, 'indices': ac.ni, 'teselas': len(tt)}
        if cat == 'costa':
            # Niveles de detalle de la costa (0.1.7.9.9G): al alejar el zoom ~106.000 segmentos de costa no se distinguen del dibujo simplificado.
            # Douglas-Peucker con error máximo `tol` unidades de mapa; el juego usa cada nivel solo mientras tol * zoom <= ~1 px.
            for nivel, tol in COSTA_LOD:
                segs_lod = simplificar_segmentos([(s_[0], s_[1]) for s_ in segs], tol)
                v_l, uv_l, _ = malla_borde(segs_lod)
                ac_l = Acum()
                tt_l = ac_l.agregar(trocear_quads(v_l.reshape(-1, 2), uv_l.reshape(-1, 2)))
                ac_l.guardar('malla_costa%d' % nivel)
                indice_teselas['costa%d' % nivel] = tt_l
                meta['costa%d' % nivel] = {'tol': tol, 'segmentos': len(segs_lod), 'verts': ac_l.nv, 'indices': ac_l.ni}
                print('costa LOD', nivel, 'tol', tol, 'segmentos', len(segs_lod), 'de', len(segs))

    # fronteras provinciales y estatales: un bloque por país, partido en teselas (Godot construye en demanda las del país enfocado)
    for cat in ('estado',):
        por_pais_seg = {}
        for (a_, b_, pais) in cats[cat]:
            por_pais_seg.setdefault(pais, []).append((a_, b_))
        ac = Acum()
        rangos = {}
        for pais, segs in por_pais_seg.items():
            v, uv, ids = malla_borde(segs)
            rangos[pais] = ac.agregar(trocear_quads(v.reshape(-1, 2), uv.reshape(-1, 2)))
        ac.guardar('malla_' + cat)
        json.dump(rangos, open(os.path.join(DATOS, 'estado_rangos.json'), 'w', encoding='utf-8'),
                  ensure_ascii=False, separators=(',', ':'))
        meta[cat] = {'verts': ac.nv, 'indices': ac.ni}
    json.dump(indice_teselas, open(os.path.join(DATOS, 'teselas.json'), 'w'), separators=(',', ':'))
    json.dump(meta, open(os.path.join(DATOS, 'malla_meta.json'), 'w'))
    print('mallas guardadas', meta, '%.1fs' % (time.time() - t0))

    # ───────────── Lagos (agua sobre la tierra) ─────────────
    LV, LI = [], []
    ruta_l = os.path.join(DATOS, 'lagos_fuente.json')
    if os.path.exists(ruta_l):
        for ring in json.load(open(ruta_l)):
            pts = limpiar(ring)
            if len(pts) < 3:
                continue
            for lazo in dividir_autointersecciones(pts):
                if abs(area_firmada(lazo)) < 1e-6:
                    continue
                tris, _ = triangular(lazo)
                b0 = len(LV)
                LV.extend(lazo)
                for (a_, b_, c_) in tris:
                    LI.extend((b0 + a_, b0 + b_, b0 + c_))
    np.array(LV, dtype='<f4').reshape(-1).tofile(os.path.join(DATOS, 'malla_lagos_v.bin'))
    np.array(LI, dtype='<i4').tofile(os.path.join(DATOS, 'malla_lagos_i.bin'))
    print('lagos', len(LV), 'vértices')

    # ───────────── Datos para clic / HUD ─────────────
    out_anillos = []
    for r in anillos:
        xs = [q[0] for q in r['pts']]
        ys = [q[1] for q in r['pts']]
        out_anillos.append({'p': r['pi'], 'k': r['cont'], 'b': [round(min(xs), 2), round(min(ys), 2),
                            round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2)],
                            'v0': r['v0'], 'n': len(r['pts']), 'i0': r['i0'], 'i1': r['i1']})
        if CELDAS:
            out_anillos[-1]['u'] = r['u']
    out_prov = []
    for p in provincias:
        d_ = {'id': p['id'], 'n': p['n'], 'c': p['c'], 'm': p['m'], 'r': p['r']}
        if p['e']:
            d_['e'] = p['e']
        out_prov.append(d_)
    json.dump({'provincias': out_prov, 'anillos': out_anillos},
              open(os.path.join(DATOS, 'provincias_juego.json'), 'w', encoding='utf-8'), ensure_ascii=False,
              separators=(',', ':'))

    if CELDAS:
        print('celdas', len(anillos), 'total %.1fs' % (time.time() - t0))
        return
    # ───────────── Etiquetas ─────────────
    from etiquetas import generar_etiquetas
    etiquetas = generar_etiquetas(provincias, anillos, PAISES_ES)
    def lum(c):
        return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    for lab in etiquetas:
        if lab['g'] == 'c':
            indice_medio = (len(lab['p']) // 4) * 2
            xm, ym = lab['p'][indice_medio], lab['p'][indice_medio + 1]
            col = color_continental(lab['k'], xm, ym)
        else:
            pi = lab['pi'] if 'pi' in lab else lab['pi0']
            col = anillos[provincias[pi]['r'][0]]['col_pais']
        lab['lc'] = 1 if (lum(col) < 0.50 or lab.get('tiny')) else 0
    prov_et = {}
    for lab in etiquetas:
        if lab['g'] == 'v':
            prov_et.setdefault(lab['pais'], []).append(lab)
    json.dump([l for l in etiquetas if l['g'] != 'v'], open(os.path.join(DATOS, 'etiquetas.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))
    json.dump(prov_et, open(os.path.join(DATOS, 'etiquetas_prov.json'), 'w', encoding='utf-8'), ensure_ascii=False,
              separators=(',', ':'))
    # Estados (EE. UU.): etiquetas y estructura
    from etiquetas import calcular
    grupos_e = {}
    for pi, pr in enumerate(provincias):
        if pr['e']:
            grupos_e.setdefault((pr['c'], pr['e']), []).append(pi)
    et_estados, estados_out = {}, {}
    for (pais, nombre), lista in grupos_e.items():
        rings = [anillos[ri]['pts'] for pi in lista for ri in provincias[pi]['r']]
        xs = [q[0] for r_ in rings for q in r_]
        ys = [q[1] for r_ in rings for q in r_]
        estados_out.setdefault(pais, []).append({'n': nombre, 'pi': lista,
                                                  'b': [round(min(xs), 2), round(min(ys), 2), round(max(xs) - min(xs), 2), round(max(ys) - min(ys), 2)]})
        rv = calcular(rings, nombre.upper(), 'e')
        if rv:
            rv.update({'g': 'e', 'pais': pais, 'e_n': nombre})
            col = anillos[provincias[lista[0]]['r'][0]]['col_pais']
            rv['lc'] = 1 if lum(col) < 0.50 else 0
            et_estados.setdefault(pais, []).append(rv)
    json.dump(et_estados, open(os.path.join(DATOS, 'etiquetas_estados.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    json.dump(estados_out, open(os.path.join(DATOS, 'estados.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('estados', sum(len(v) for v in estados_out.values()), 'etiquetas de estado', sum(len(v) for v in et_estados.values()))
    print('etiquetas', len(etiquetas), 'total %.1fs' % (time.time() - t0))

if __name__ == '__main__':
    main()
