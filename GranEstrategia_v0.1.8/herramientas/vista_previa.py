"""Genera imágenes de prueba del mapa (sin Godot) para revisar colores y nombres. Uso:
   python herramientas/vista_previa.py salida.png x0 y0 x1 y1 zoom modo(pais|cont)"""
import json, sys, os, math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
from matplotlib.collections import PolyCollection
from matplotlib import font_manager

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(RAIZ, 'datos')
out, x0, y0, x1, y1, zoom = sys.argv[1], *map(float, sys.argv[2:7])
modo = sys.argv[7] if len(sys.argv) > 7 else 'pais'
dat = json.load(open(os.path.join(D, 'provincias_juego.json'), encoding='utf-8'))
etq = json.load(open(os.path.join(D, 'etiquetas.json'), encoding='utf-8'))
V = np.fromfile(os.path.join(D, 'malla_fill_v.bin'), dtype='<f4').reshape(-1, 2)
I = np.fromfile(os.path.join(D, 'malla_fill_i.bin'), dtype='<i4').reshape(-1, 3)
C = np.fromfile(os.path.join(D, 'malla_fill_cp.bin' if modo == 'pais' else 'malla_fill_cc.bin'), dtype='u1').reshape(-1, 3) / 255.0
w_in = (x1 - x0) * zoom / 100.0
h_in = (y1 - y0) * zoom / 100.0
fig = plt.figure(figsize=(w_in, h_in), dpi=100)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_facecolor((0.02, 0.06, 0.13))
tri = V[I]
col = C[I[:, 0]]
ax.add_collection(PolyCollection(tri, facecolors=col, edgecolors=col, linewidths=0.4, antialiaseds=True))
# bordes (según zoom)
def cargar_segs(cat):
    v = np.fromfile(os.path.join(D, 'malla_%s_v.bin' % cat), dtype='<f4').reshape(-1, 4, 2)
    return v[:, [0, 2], :]
from matplotlib.collections import LineCollection
if modo == 'pais':
    ax.add_collection(LineCollection(cargar_segs('prov'), colors=(0, 0, 0, 0.35), linewidths=0.5))
    ax.add_collection(LineCollection(cargar_segs('frontera'), colors=(0.04, 0.05, 0.09, 0.9), linewidths=0.9))
ax.add_collection(LineCollection(cargar_segs('costa'), colors=(0.04, 0.05, 0.09, 1), linewidths=0.9 if modo == 'pais' else 1.3))
if modo == 'cont':
    ax.add_collection(LineCollection(cargar_segs('cont'), colors=(0.04, 0.05, 0.09, 1), linewidths=1.3))
ax.set_xlim(x0, x1); ax.set_ylim(y1, y0)
# ───── etiquetas (mismo algoritmo que Godot, con DejaVu Serif)
fp = font_manager.FontProperties(family='DejaVu Serif')
from matplotlib.textpath import TextPath
def ancho(ch, em):
    tp = TextPath((0, 0), ch, size=em, prop=fp)
    return font_manager.FontProperties
from PIL import ImageFont
F = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf', 100)
def adv(ch):
    return 0.93 * F.getlength(ch) / 100.0
MAXSP = {'c': 3.4, 'p': 2.0, 'm': 2.2, 'v': 1.5}
def sm(a, b, x):
    t = max(0, min(1, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)
for lab in etq:
    g = lab['g']
    E = lab['e']
    if modo == 'cont' and g != 'c':
        continue
    if modo == 'pais':
        if g == 'c':
            continue
        zm = 11.0 / E
        if zoom < zm * 0.9:
            continue
        if g == 'm' and zoom > lab['zf'] * 1.4:
            continue
        if g == 'v' and False:
            continue
    P = np.array(lab['p']).reshape(-1, 2)
    if P[:, 0].max() < x0 - 50 or P[:, 0].min() > x1 + 50 or P[:, 1].max() < y0 - 50 or P[:, 1].min() > y1 + 50:
        continue
    seg = np.hypot(*np.diff(P, axis=0).T)
    cum = np.concatenate([[0], np.cumsum(seg)])
    A = cum[-1]
    t = lab['t']
    ws = np.array([adv(ch) * E for ch in t])
    W = ws.sum()
    if W > 0.96 * A:
        k = 0.96 * A / W; ws *= k; W *= k; Es = E * k
    else:
        Es = E
    extra = 0.0
    if len(t) > 1:
        alvo = min(A * 0.9, W * MAXSP[g])
        extra = max(0.0, (alvo - W) / (len(t) - 1))
        extra = min(extra, Es * 1.2)
    Wt = W + extra * (len(t) - 1)
    s = (A - Wt) / 2
    def pos(d):
        d = max(0, min(A, d))
        i = int(np.searchsorted(cum, d, side='right') - 1)
        i = min(i, len(seg) - 1)
        f = (d - cum[i]) / max(seg[i], 1e-9)
        return P[i] + (P[i + 1] - P[i]) * f
    col_txt = (1, 0.98, 0.9, 0.95)
    for i, ch in enumerate(t):
        if ch == ' ':
            s += ws[i] + extra
            continue
        c0 = s + ws[i] / 2
        pa, pb = pos(c0 - ws[i] / 2), pos(c0 + ws[i] / 2)
        pc = pos(c0)
        ang = math.degrees(math.atan2(pb[1] - pa[1], pb[0] - pa[0]))
        fs_pt = Es * 0.72 * 100.0 / 72.0 * zoom * 0.72  # tamaño aproximado en puntos
        ax.text(pc[0], pc[1], ch, rotation=-ang, rotation_mode='anchor', ha='center', va='center_baseline',
                fontsize=max(1.0, Es * zoom * 0.72), family='DejaVu Serif', color=col_txt)
        s += ws[i] + extra
fig.savefig(out, dpi=100)
