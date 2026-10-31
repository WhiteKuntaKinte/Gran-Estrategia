"""Calcula, para cada país / provincia / continente, una línea curva DENTRO de su territorio sobre la que se
escribe el nombre (estilo Age of History 3: el texto sigue la forma del territorio)."""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

FUENTE_MEDIDA = '/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf'
try:
    _F = ImageFont.truetype(FUENTE_MEDIDA, 100)
except Exception:
    _F = None

NOMBRES_CONT = {
    'Europa': 'EUROPA', 'Asia': 'ASIA', 'África': 'ÁFRICA', 'América del Norte': 'AMÉRICA DEL NORTE',
    'América del Sur': 'AMÉRICA DEL SUR', 'Oceanía': 'OCEANÍA', 'Antártida': 'ANTÁRTIDA',
}

# factor de tamaño máximo respecto a sqrt(área), y espaciado máximo entre letras (lo usa también Godot)
PARAMS = {
    'c': {'emax': 0.085, 'emin': 3.0},
    'p': {'emax': 0.16, 'emin': 0.22},
    'm': {'emax': 0.10, 'emin': 0.6},
    'v': {'emax': 0.17, 'emin': 0.22},
}

def ancho_em(texto):
    if _F is None:
        return 0.62 * len(texto)
    return 0.93 * _F.getlength(texto) / 100.0


def mascara(rings, s):
    xs = [q[0] for r in rings for q in r]
    ys = [q[1] for r in rings for q in r]
    x0, y0 = min(xs) - 2.0 / s, min(ys) - 2.0 / s
    W = int((max(xs) - x0) * s) + 4
    H = int((max(ys) - y0) * s) + 4
    img = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(img)
    for r in rings:
        d.polygon([((x - x0) * s, (y - y0) * s) for x, y in r], fill=255)
    return np.array(img) > 0, x0, y0


def calcular(rings, texto, tipo):
    prm = PARAMS[tipo]
    xs = [q[0] for r in rings for q in r]
    ys = [q[1] for r in rings for q in r]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    s = max(1.5, min(24.0, 1800.0 / max(w, h, 0.5)))
    m, x0, y0 = mascara(rings, s)
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    if n == 0:
        return None
    tamanos = ndimage.sum(m, lab, range(1, n + 1))
    comp = lab == (int(np.argmax(tamanos)) + 1)
    area = float(comp.sum()) / (s * s)
    dt = ndimage.distance_transform_edt(np.pad(comp, 2))[2:-2, 2:-2] / s
    filas, cols = np.nonzero(comp)
    px = x0 + (cols + 0.5) / s
    py = y0 + (filas + 0.5) / s
    mu = np.array([px.mean(), py.mean()])
    cov = np.cov(np.vstack([px - mu[0], py - mu[1]]))
    vals, vecs = np.linalg.eigh(cov)
    u = vecs[:, int(np.argmax(vals))]
    # Todas las etiquetas continentales siguen la misma regla de lectura:
    # eje principal de izquierda a derecha; si es casi vertical, de abajo hacia arriba.
    # Esto evita que América del Sur quede invertida respecto al resto del mapa.
    if u[0] < 0 or (abs(u[0]) < 1e-3 and u[1] > 0):
        u = -u
    v = np.array([-u[1], u[0]])
    sp = (px - mu[0]) * u[0] + (py - mu[1]) * u[1]
    tp = (px - mu[0]) * v[0] + (py - mu[1]) * v[1]
    smin, smax = float(sp.min()), float(sp.max())
    if smax - smin < 1e-3:
        return None
    nb = int(max(8, min(60, (smax - smin) * s / 4)))
    bordes = np.linspace(smin, smax, nb + 1)
    cs, cc, ww = [], [], []
    for i in range(nb):
        sel = (sp >= bordes[i]) & (sp < bordes[i + 1] + 1e-9)
        if sel.sum() < 3:
            continue
        # el centro de la columna se calcula con la zona más "gruesa" para no irse a un apéndice
        cs.append((bordes[i] + bordes[i + 1]) / 2)
        cc.append((tp[sel].min() + tp[sel].max()) / 2)
        ww.append(tp[sel].max() - tp[sel].min())
    if len(cs) < 3:
        return None
    grado = 2 if len(cs) >= 6 else 1
    coef = np.polyfit(cs, cc, grado, w=np.sqrt(np.maximum(ww, 1e-3)))
    M = int(max(80, min(700, (smax - smin) * s)))
    ss = np.linspace(smin, smax, M)
    tt = np.polyval(coef, ss)
    X = mu[0] + ss * u[0] + tt * v[0]
    Y = mu[1] + ss * u[1] + tt * v[1]
    dsv = ndimage.map_coordinates(dt, [(Y - y0) * s - 0.5, (X - x0) * s - 0.5], order=1, mode='constant', cval=0.0)
    seg = np.hypot(np.diff(X), np.diff(Y))
    wem = ancho_em(texto)

    emax = min(prm['emax'] * math.sqrt(max(area, 1e-6)), 2.0 * float(dsv.max()) / 0.92)
    E = emax
    mejor = None
    while E >= prm['emin']:
        ok = dsv >= 0.46 * E
        # corrida más larga continua
        best_len, best_a, best_b = 0.0, 0, 0
        i = 0
        while i < M:
            if not ok[i]:
                i += 1
                continue
            j = i
            while j + 1 < M and ok[j + 1]:
                j += 1
            L = float(seg[i:j].sum()) if j > i else 0.0
            if L > best_len:
                best_len, best_a, best_b = L, i, j
            i = j + 1
        if best_len >= wem * E * 1.02:
            mejor = (E, best_len, best_a, best_b)
            break
        E *= 0.94
    if mejor is None:
        return None
    E, L, a, b = mejor
    n_pts = int(max(2, min(18, L / max(E * 0.9, 1e-3))))
    idx = np.linspace(a, b, n_pts + 1).round().astype(int)
    pts = []
    for k in idx:
        pts += [round(float(X[k]), 2), round(float(Y[k]), 2)]
    # asegura que el sentido de lectura sea izquierda→derecha
    return {'t': texto, 'e': round(float(E), 3), 'a': round(float(L), 2), 'p': pts, 'area': area}


def generar_etiquetas(provincias, anillos, PAISES_ES):
    out = []
    # ── continentes ──
    for cont, nombre in NOMBRES_CONT.items():
        rings = [r['pts'] for r in anillos if r['cont'] == cont]
        if not rings:
            continue
        res = calcular(rings, nombre, 'c')
        if res:
            res.update({'g': 'c', 'k': cont})
            out.append(res)
    # ── países y provincias ──
    por_pais = {}
    for pi, pr in enumerate(provincias):
        por_pais.setdefault(pr['pais_en'], []).append(pi)
    for pais_en, lista in por_pais.items():
        pais_es = PAISES_ES.get(pais_en, pais_en)
        rings_pais = [anillos[ri]['pts'] for pi in lista for ri in provincias[pi]['r']]
        multi = len(lista) > 1
        res = calcular(rings_pais, pais_es.upper(), 'm' if multi else 'p')
        idx_pais = None
        if res:
            res['g'] = 'm' if multi else 'p'
            res['k'] = provincias[lista[0]]['cont_main']
            res['pais'] = pais_es
            res['pi0'] = lista[0]
            out.append(res)
            idx_pais = len(out) - 1
        if multi:
            zs = []
            for pi in lista:
                pr = provincias[pi]
                rr = [anillos[ri]['pts'] for ri in pr['r']]
                if not rr:
                    continue
                rv = calcular(rr, pr['n'], 'v')
                if rv:
                    rv['g'] = 'v'
                    rv['k'] = pr['cont_main']
                    rv['pais'] = pais_es
                    rv['pi'] = pi
                    out.append(rv)
                    zs.append(11.0 / rv['e'])
            if idx_pais is not None:
                zmin_m = 11.0 / out[idx_pais]['e']
                zf = float(np.percentile(zs, 20)) if zs else zmin_m * 3
                out[idx_pais]['zf'] = round(max(zf, zmin_m * 1.6), 3)
    # color del texto (claro/oscuro) según el color de país
    for lab in out:
        if lab['g'] == 'c':
            lab['lc'] = 1
            continue
    return out
