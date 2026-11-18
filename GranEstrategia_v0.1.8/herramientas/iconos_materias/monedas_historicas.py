"""Monedas históricas del juego (0.1.8.52): una por cada divisa de datos/epocas/<época>/divisas.json (denario, besante, dinar, florín, wen, cauríes...).
Cada civilización tiene su forma y su motivo: bustos romanos con laurel, dracmas con diadema, besantes con Cristo y cruz, dinares con caligrafía cúfica
(sin figuras), cash chinos con agujero cuadrado, taeles en lingote, grivnas en barra, conchas, cacao y sal para las economías sin moneda acuñada.
Todo se dibuja desde cero con pillow (lienzo.py); no hay imágenes de monedas reales. Mismos nombres de archivo que las modernas: iconos/divisas/d_<COD>.png."""
import math

from lienzo import *
from divisas import METALES

# ───────────── motivos grabados: cada uno dibuja con (c, col, dx, dy); `grabar` lo pasa dos veces (luz desplazada y grabado) ─────────────


def _m(pts, dx, dy):
    return [(x + dx, y + dy) for x, y in pts]


def grabar(c, cara, grab, f):
    f(c, claro(cara, 0.55), 1.3, 1.3)
    f(c, grab, 0.0, 0.0)


def m_perfil(c, col, dx, dy, cx=64, cy=64, s=34, laurel=False, barba=False, diadema=False, casco=False, izq=False):
    """Cabeza de perfil mirando a la derecha (a la izquierda si izq)."""
    k = -1 if izq else 1
    base = [(-0.30, -0.55), (0.05, -0.62), (0.32, -0.46), (0.38, -0.22), (0.52, -0.06), (0.41, 0.02), (0.43, 0.11), (0.36, 0.19), (0.41, 0.30), (0.22, 0.36),
            (0.18, 0.52), (0.30, 0.82), (-0.52, 0.82), (-0.36, 0.36), (-0.46, 0.10), (-0.44, -0.30)]
    pts = [(cx + k * x * s + dx, cy + y * s + dy) for x, y in base]
    c.poly(pts, col)
    if barba:
        c.poly(_m([(cx + k * 0.38 * s, cy + 0.10 * s), (cx + k * 0.46 * s, cy + 0.36 * s), (cx + k * 0.12 * s, cy + 0.60 * s), (cx + k * 0.02 * s, cy + 0.28 * s)], dx, dy), col)
    if diadema:
        c.linea(_m([(cx - k * 0.40 * s, cy - 0.42 * s), (cx + k * 0.34 * s, cy - 0.36 * s)], dx, dy), 2.6, col)
        c.linea(_m([(cx - k * 0.44 * s, cy - 0.40 * s), (cx - k * 0.78 * s, cy - 0.20 * s)], dx, dy), 2.2, col)
    if casco:
        c.linea(_m(spline([(cx - k * 0.48 * s, cy - 0.05 * s), (cx - k * 0.30 * s, cy - 0.70 * s), (cx + k * 0.12 * s, cy - 0.78 * s), (cx + k * 0.40 * s, cy - 0.40 * s)], cerrada=False), dx, dy), 3.4, col)
    if laurel:
        for i in range(7):
            a = math.radians(-165 + i * 22)
            x0, y0 = cx + k * 0.0 * s + math.cos(a) * 0.62 * s, cy - 0.10 * s + math.sin(a) * 0.74 * s
            x1, y1 = x0 + math.cos(a + 1.2) * 0.30 * s, y0 + math.sin(a + 1.2) * 0.30 * s
            c.poly(_m(hoja(x0, y0, x1, y1, 2.6, 0.0, 6), dx, dy), col)


def m_frontal(c, col, dx, dy, cx=64, cy=60, s=36, halo=True, cruz=True):
    """Busto de frente (Cristo bizantino): cabeza, hombros y halo con cruz."""
    if halo:
        c.linea(_m(elipse(cx, cy - 0.18 * s, 0.62 * s, 0.62 * s, 0, 28) + [elipse(cx, cy - 0.18 * s, 0.62 * s, 0.62 * s, 0, 28)[0]], dx, dy), 2.4, col)
    c.poly(_m(elipse(cx, cy - 0.18 * s, 0.30 * s, 0.38 * s), dx, dy), col)
    c.poly(_m([(cx - 0.62 * s, cy + 0.80 * s), (cx - 0.52 * s, cy + 0.34 * s), (cx - 0.18 * s, cy + 0.22 * s), (cx + 0.18 * s, cy + 0.22 * s),
               (cx + 0.52 * s, cy + 0.34 * s), (cx + 0.62 * s, cy + 0.80 * s)], dx, dy), col)
    if cruz:
        c.linea(_m([(cx, cy - 0.78 * s), (cx, cy - 0.46 * s)], dx, dy), 2.0, claro(col, 0.0))
        c.linea(_m([(cx - 0.10 * s, cy - 0.64 * s), (cx + 0.10 * s, cy - 0.64 * s)], dx, dy), 2.0, col)


def m_cruz(c, col, dx, dy, cx=64, cy=62, L=26, ancho=7.0, patada=True, latina=False):
    sup, inf = (L, L * (1.35 if latina else 1.0))
    c.linea(_m([(cx, cy - sup), (cx, cy + inf)], dx, dy), ancho, col)
    c.linea(_m([(cx - L, cy - 4), (cx + L, cy - 4)], dx, dy), ancho, col)
    if patada:
        for (x, y, h) in ((cx, cy - sup, 0), (cx, cy + inf, 0), (cx - L, cy - 4, 1), (cx + L, cy - 4, 1)):
            r = ancho * 0.95
            c.poly(_m(elipse(x, y, r * (1.2 if h == 0 else 0.8), r * (0.8 if h == 0 else 1.2)), dx, dy), col)


def m_lirio(c, col, dx, dy, cx=64, cy=62, s=1.0):
    c.poly(_m(hoja(cx, cy + 26 * s, cx, cy - 26 * s, 8 * s, 0, 12), dx, dy), col)
    for lado in (-1, 1):
        c.poly(_m(hoja(cx, cy + 4 * s, cx + lado * 20 * s, cy - 18 * s, 6 * s, lado * 7 * s, 12), dx, dy), col)
        c.linea(_m(bezier((cx, cy + 12 * s), (cx + lado * 16 * s, cy + 16 * s), (cx + lado * 20 * s, cy + 2 * s), 10), dx, dy), 3.0 * s, col)
    c.linea(_m([(cx - 14 * s, cy + 16 * s), (cx + 14 * s, cy + 16 * s)], dx, dy), 4.0 * s, col)


def m_escudo(c, col, dx, dy, cx=64, cy=64, w=22, h=30, corona=False):
    ptsE = [(cx - w, cy - h * 0.6), (cx + w, cy - h * 0.6), (cx + w, cy + h * 0.1)] + [(cx + w * math.cos(a), cy + h * 0.1 + h * 0.8 * math.sin(a)) for a in [i * math.pi / 14 for i in range(0, 8)]][1:] + [(cx, cy + h * 0.95)] + \
        [(cx - w * math.cos(a), cy + h * 0.1 + h * 0.8 * math.sin(a)) for a in [i * math.pi / 14 for i in range(7, 0, -1)]] + [(cx - w, cy + h * 0.1)]
    c.linea(_m(ptsE + [ptsE[0]], dx, dy), 3.2, col)
    c.linea(_m([(cx, cy - h * 0.6), (cx, cy + h * 0.9)], dx, dy), 2.4, col)
    c.linea(_m([(cx - w, cy - h * 0.1), (cx + w, cy - h * 0.1)], dx, dy), 2.4, col)
    if corona:
        m_corona(c, col, dx, dy, cx, cy - h * 0.6 - 9, 16)


def m_corona(c, col, dx, dy, cx=64, cy=40, w=18):
    base = [(cx - w, cy + 8), (cx - w, cy - 2), (cx - w * 0.5, cy + 3), (cx, cy - 8), (cx + w * 0.5, cy + 3), (cx + w, cy - 2), (cx + w, cy + 8)]
    c.poly(_m(base, dx, dy), col)
    for x in (cx - w, cx, cx + w):
        c.punto(x + dx, (cy - (8 if x == cx else 2)) + dy - 2.5, 2.4, col)


def m_castillo(c, col, dx, dy, cx=64, cy=64, s=1.0):
    c.rect(cx - 20 * s + dx, cy - 6 * s + dy, cx + 20 * s + dx, cy + 24 * s + dy, col)
    for x in (-20, 0, 20):
        c.rect(cx + (x - 7) * s + dx, cy - 26 * s + dy, cx + (x + 7) * s + dx, cy + 2 * s + dy, col)
        for k in (-4, 4):
            c.rect(cx + (x + k - 2.4) * s + dx, cy - 32 * s + dy, cx + (x + k + 2.4) * s + dx, cy - 25 * s + dy, col)
    c.rect(cx - 5 * s + dx, cy + 10 * s + dy, cx + 5 * s + dx, cy + 24 * s + dy, (0, 0, 0, 0))


def m_cufico(c, col, dx, dy, cx=64, cy=62, w=40, lineas=3, sem=1):
    """Escritura angular que imita la caligrafía cúfica (sin letras reales): líneas base con astas y puntos."""
    n = lineas
    for j in range(n):
        y = cy + (j - (n - 1) / 2) * 15
        c.linea(_m([(cx - w, y + 5), (cx + w, y + 5)], dx, dy), 2.6, col)
        x = cx - w + 4
        i = 0
        while x < cx + w - 6:
            h = 8 + ((i * 7 + j * 5 + sem * 3) % 4) * 3
            c.linea(_m([(x, y + 5), (x, y + 5 - h)], dx, dy), 2.6, col)
            if (i + j + sem) % 3 == 0:
                c.punto(x + 4 + dx, y - 6 + dy, 1.5, col)
            x += 7 + (i + j) % 2 * 3
            i += 1


def m_anillo_cufico(c, col, dx, dy, cx=64, cy=62, r=40, n=22, sem=0):
    for i in range(n):
        a = math.radians(i * 360.0 / n)
        h = 4 + ((i * 5 + sem) % 4) * 1.8
        c.linea(_m([(cx + r * math.cos(a), cy + r * math.sin(a)), (cx + (r - h) * math.cos(a), cy + (r - h) * math.sin(a))], dx, dy), 2.0, col)


def m_leyenda(c, col, dx, dy, cx=64, cy=62, r=42, n=34):
    for i in range(n):
        a = math.radians(i * 360.0 / n)
        c.punto(cx + r * math.cos(a) + dx, cy + r * math.sin(a) + dy, 1.5, col)


def m_estrella(c, col, dx, dy, cx=64, cy=62, r=14, puntas=8):
    c.poly(_m(estrella(cx, cy, r, r * 0.42, puntas), dx, dy), col)


# ───────────── monedas ─────────────
def _disco(c, metal, r=54, cx=64, cy=62, perlas=True, aro=True):
    borde, cara, ar, grab = METALES[metal]
    c.cuerpo_elip(cx, cy, r, r, col=borde, sombra=0.3, luz=0.0, d=3.0)
    if perlas:
        for i in range(30):
            a = math.radians(i * 12)
            c.punto(cx + (r - 3) * math.cos(a), cy + (r - 3) * math.sin(a), 1.5, claro(borde, 0.45))
    c.cuerpo_elip(cx, cy, r - 6.5, r - 6.5, col=cara, sombra=0.2, luz=0.25, d=2.2)
    if aro:
        c.linea(elipse(cx, cy, r - 10.5, r - 10.5, 0, 60) + [elipse(cx, cy, r - 10.5, r - 10.5, 0, 60)[0]], 1.6, ar)
    return cara, grab


def _con_motivo(metal, *motivos, r=54, perlas=True, aro=True):
    def f(c):
        cara, grab = _disco(c, metal, r=r, perlas=perlas, aro=aro)
        for m in motivos:
            grabar(c, cara, grab, m)
    return f


def _agujero(c, cx=64, cy=62, lado=14):
    m = c._mascara([(cx - lado / 2, cy - lado / 2), (cx + lado / 2, cy - lado / 2), (cx + lado / 2, cy + lado / 2), (cx - lado / 2, cy + lado / 2)])
    c.im.paste((0, 0, 0, 0), (0, 0), m)
    c.rect(cx - lado / 2 - 0.0, cy - lado / 2, cx + lado / 2, cy - lado / 2 + 2.6, (0, 0, 0, 70))


def _pseudo_glifos(col, dx, dy, x0, y0, n=3, vertical=True):
    pass


def moneda_agujero(metal, caracteres=2, borde_ancho=7.0):
    """Cash chino: disco con agujero cuadrado, aro elevado y signos a los lados."""
    def f(c):
        cara, grab = _disco(c, metal, perlas=False, aro=False)
        c.linea(elipse(64, 62, 44, 44, 0, 60) + [elipse(64, 62, 44, 44)[0]], borde_ancho * 0.45, claro(METALES[metal][2], 0.2))

        def signos(c2, col, dx, dy):
            posiciones = [(64, 36), (64, 88), (36, 62), (92, 62)][:max(2, caracteres)] if caracteres > 2 else [(40, 62), (88, 62)]
            for k, (x, y) in enumerate(posiciones):
                c2.linea(_m([(x - 7, y - 7), (x + 7, y - 7)], dx, dy), 2.6, col)
                c2.linea(_m([(x, y - 10), (x, y + 9)], dx, dy), 2.6, col)
                c2.linea(_m([(x - 7, y + 4), (x + 7, y + 4)], dx, dy), 2.2, col)
                c2.linea(_m([(x - 5, y + 9), (x - 1, y + 4)], dx, dy), 2.2, col)
        grabar(c, cara, grab, signos)
        _agujero(c, lado=15)
        c.linea([(56.5, 54.5), (71.5, 54.5), (71.5, 69.5), (56.5, 69.5), (56.5, 54.5)], 3.0, oscuro(METALES[metal][0], 0.3))
    return f


def tael(c):
    """Lingote de plata en forma de bote (sycee): extremos levantados y sello."""
    borde, cara, aro, grab = METALES['plata']
    casco = spline([(6, 56), (22, 30), (64, 46), (106, 30), (122, 56), (106, 92), (64, 104), (22, 92)])
    c.cuerpo(casco, cara, sombra=0.32, luz=0.4, d=3.6)
    c.cuerpo(spline([(24, 58), (40, 48), (64, 54), (88, 48), (104, 58), (88, 82), (64, 90), (40, 82)]), claro(cara, 0.15), sombra=0.18, luz=0.2, d=2.0)
    for x in (46, 64, 82):
        c.linea(bezier((x - 8, 70), (x, 62), (x + 8, 70), 8), 2.0, aro)
    c.brillo(40, 42, 16, 5)


def barra_grivna(c):
    """Grivna de Kiev: barra de plata de seis caras con muescas."""
    borde, cara, aro, grab = METALES['plata']
    c.cuerpo([(10, 64), (24, 48), (104, 48), (118, 64), (104, 80), (24, 80)], cara, sombra=0.3, luz=0.4, d=3.4)
    for x in (34, 54, 74, 94):
        c.linea([(x, 52), (x - 3, 76)], 1.8, aro)
    c.linea([(22, 60), (106, 60)], 1.4, claro(cara, 0.4))


def karshapana(c):
    """Moneda de plata punzonada de la India antigua: lámina curva con marcas."""
    borde, cara, aro, grab = METALES['plata']
    c.cuerpo(spline([(14, 40), (60, 26), (112, 38), (108, 86), (64, 100), (18, 90)]), cara, sombra=0.3, luz=0.35, d=3.2)
    for (x, y, t) in ((36, 52, 0), (66, 46, 1), (92, 58, 2), (46, 78, 3), (82, 80, 0)):
        if t == 0:
            c.linea(elipse(x, y, 8, 8, 0, 14) + [elipse(x, y, 8, 8)[0]], 2.2, grab)
            for a in range(0, 360, 60):
                c.linea([(x, y), (x + 8 * math.cos(math.radians(a)), y + 8 * math.sin(math.radians(a)))], 1.6, grab)
        elif t == 1:
            c.linea([(x - 8, y + 6), (x, y - 8), (x + 8, y + 6)], 2.4, grab)
            c.linea([(x - 4, y + 6), (x, y), (x + 4, y + 6)], 2.0, grab)
        elif t == 2:
            c.poly(estrella(x, y, 8, 3, 6), grab)
        else:
            c.linea([(x - 8, y), (x + 8, y)], 2.2, grab)
            c.linea([(x, y - 8), (x, y + 8)], 2.2, grab)


def disco_irregular(metal, motivo, r=46):
    """Denga rusa / gadyana: lámina ovalada e irregular."""
    def f(c):
        borde, cara, aro, grab = METALES[metal]
        pts = spline([(64 + r * math.cos(a) * (1 + 0.12 * math.sin(3 * a + 1)), 62 + (r - 8) * math.sin(a) * (1 + 0.10 * math.cos(2 * a))) for a in [i * math.pi / 5 for i in range(10)]])
        c.cuerpo(pts, cara, sombra=0.3, luz=0.35, d=3.2)
        grabar(c, cara, grab, motivo)
    return f


def m_jinete(c, col, dx, dy):
    c.poly(_m(spline([(30, 74), (36, 62), (54, 60), (74, 58), (86, 64), (88, 74), (80, 74), (76, 82), (70, 74), (46, 74), (40, 84), (34, 82)]), dx, dy), col)
    c.poly(_m(elipse(62, 44, 5, 6), dx, dy), col)
    c.linea(_m([(62, 50), (60, 62)], dx, dy), 4.0, col)
    c.linea(_m([(70, 36), (88, 80)], dx, dy), 2.0, col)


def m_pagoda(c, col, dx, dy):
    m_estrella(c, col, dx, dy, 64, 62, 18, 6)
    c.punto(64 + dx, 62 + dy, 4, col)
    for a in range(0, 360, 60):
        c.punto(64 + 26 * math.cos(math.radians(a + 30)) + dx, 62 + 26 * math.sin(math.radians(a + 30)) + dy, 2.4, col)


def m_grano(c, col, dx, dy):
    pass


def barras_sal(c):
    cuerpo = hexa('e8e6de')
    for (x, y, rot_) in ((22, 74, -6), (58, 66, 4), (36, 40, -3)):
        bloque = rot([(x, y), (x + 62, y), (x + 62, y + 22), (x, y + 22)], rot_, x + 31, y + 11)
        c.cuerpo(bloque, cuerpo, sombra=0.3, luz=0.4, d=2.6)
        for k in (0.18, 0.78):
            banda = rot([(x + 62 * k - 3, y - 1), (x + 62 * k + 3, y - 1), (x + 62 * k + 3, y + 23), (x + 62 * k - 3, y + 23)], rot_, x + 31, y + 11)
            c.poly(banda, hexa('9a7a4a'))
        c.linea(rot([(x + 6, y + 5), (x + 24, y + 5)], rot_, x + 31, y + 11), 1.6, hexa('ffffff'))


def cacao(c):
    for (x, y, a, col) in ((38, 68, -28, hexa('b9733a')), (78, 62, 22, hexa('c9843f')), (60, 36, 4, hexa('a8602e'))):
        vaina = elipse(x, y, 22, 14, a, 30)
        c.cuerpo(vaina, col, sombra=0.32, luz=0.35, d=3.0)
        for k in (-7, -2, 3, 8):
            c.linea(rot([(x - 18, y + k * 0.8), (x + 18, y + k * 0.8)], a, x, y), 1.4, oscuro(col, 0.35))
        c.cuerpo_elip(x + math.cos(math.radians(a)) * 21, y + math.sin(math.radians(a)) * 21, 3, 3, col=oscuro(col, 0.3), sombra=0.1, luz=0.0, d=1.0)
    for (x, y) in ((96, 96), (104, 86), (88, 100)):
        c.cuerpo_elip(x, y, 7, 5, col=hexa('7a4a2a'), sombra=0.3, luz=0.4, d=1.6, ang=-20.0)


def caurias(c):
    for (x, y, a) in ((40, 70, -20), (84, 66, 18), (62, 34, 4)):
        c.cuerpo_elip(x, y, 24, 16, col=hexa('f2e6cf'), sombra=0.28, luz=0.4, d=3.0, ang=a)
        c.linea(rot([(x - 17, y), (x + 17, y)], a, x, y), 3.0, hexa('9a7a58'))
        for k in range(-3, 4):
            c.linea(rot([(x + k * 4.6, y - 3), (x + k * 4.6, y + 3)], a, x, y), 1.4, hexa('9a7a58'))
        c.brillo(x - 8, y - 7, 8, 3, a - 25)


def nzimbu(c):
    for (x, y, a) in ((36, 80, -24), (86, 74, 18), (60, 36, 0)):
        c.cuerpo(rot([(x - 28, y), (x + 12, y - 19), (x + 32, y), (x + 12, y + 19)], a, x, y), hexa('d9b88a'), sombra=0.3, luz=0.35, d=2.8)
        for k in range(4):
            c.linea(rot(bezier((x - 16 + k * 9, y - 11), (x - 13 + k * 9, y), (x - 16 + k * 9, y + 11), 6), a, x, y), 2.2, hexa('8f6a3e'))


def polvo_oro(c):
    c.cuerpo(spline([(26, 92), (34, 62), (50, 42), (64, 34), (78, 42), (94, 62), (102, 92)]), hexa('8a5a34'), sombra=0.3, luz=0.35, d=3.0)
    c.cuerpo(hoja(48, 40, 80, 40, 6, 0, 8), hexa('b87a44'), sombra=0.2, luz=0.3, d=2.0)
    c.linea([(52, 38), (76, 38)], 3.0, hexa('3a2a1c'))
    for (x, y, r) in ((60, 98, 5), (80, 100, 4), (96, 98, 3), (44, 100, 3.5), (68, 104, 3), (30, 100, 3), (88, 106, 2.4)):
        c.cuerpo_elip(x, y, r, r * 0.8, col=ORO, sombra=0.3, luz=0.5, d=1.2)
    c.brillo(46, 62, 6, 12, 25)


def masa_javanesa(c):
    borde, cara, aro, grab = METALES['oro']
    c.cuerpo(spline([(22, 34), (60, 24), (104, 36), (106, 84), (66, 100), (24, 88)], por_tramo=6), cara, sombra=0.3, luz=0.4, d=3.2)

    def sello(c2, col, dx, dy):
        c2.linea(_m(spline([(46, 52), (56, 46), (66, 54), (60, 64), (50, 62)], cerrada=False), dx, dy), 2.6, col)
        c2.linea(_m(bezier((66, 54), (80, 48), (88, 66), 8), dx, dy), 2.6, col)
        c2.punto(54 + dx, 78 + dy, 3, col)
        c2.linea(_m([(62, 78), (88, 78)], dx, dy), 2.6, col)
    grabar(c, cara, grab, sello)


def trueque(c):
    c.cuerpo(spline([(34, 60), (40, 40), (64, 32), (88, 40), (94, 60), (98, 100), (30, 100)], por_tramo=6), hexa('c8a46a'), sombra=0.3, luz=0.35, d=3.2)
    c.cuerpo([(46, 30), (82, 30), (78, 42), (50, 42)], hexa('b08a52'), sombra=0.25, luz=0.3, d=2.0)
    c.linea([(40, 60), (88, 60)], 2.4, hexa('7a5a30'))
    for k in range(5):
        x = 48 + k * 8
        c.poly(hoja(x, 86, x + 4, 66, 3.2, 1, 6), ORO)
    c.cuerpo_elip(100, 104, 12, 7, col=hexa('eeeee6'), sombra=0.3, luz=0.4, d=1.8)


# ───────────── tabla: código → icono ─────────────
def _mon(metal, *motivos, **kw):
    return _con_motivo(metal, *motivos, **kw)


def _perfil(**kw):
    return lambda c, col, dx, dy: m_perfil(c, col, dx, dy, **kw)


ICONOS = {
    # Roma, helenismo y Asia antigua (año 1)
    'd_DEN': _mon('plata', _perfil(laurel=True, cx=62, cy=64, s=33), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=30)),
    'd_DRC': _mon('plata', _perfil(diadema=True, cx=62, cy=64, s=33), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=26)),
    'd_DRP': _mon('plata', _perfil(barba=True, diadema=True, cx=64, cy=64, s=33, izq=True), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=22)),
    'd_DRI': _mon('plata', _perfil(casco=True, cx=62, cy=64, s=34), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=28)),
    'd_HMY': _mon('plata', _perfil(cx=66, cy=66, s=32, izq=True, diadema=True),
                  lambda c, col, dx, dy: (c.linea(_m(elipse(40, 36, 9, 9, 0, 20)[2:16], dx, dy), 2.6, col), c.punto(40 + dx, 34 + dy, 2.2, col)),
                  lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=24)),
    'd_KRS': karshapana,
    'd_WZH': moneda_agujero('bronce', 2),
    # China
    'd_WEN': moneda_agujero('bronce', 4),
    'd_TAE': tael,
    # Bizancio y mundo islámico
    'd_BEZ': _mon('oro', lambda c, col, dx, dy: m_frontal(c, col, dx, dy, 64, 62, 34), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=26)),
    'd_DIN': _mon('oro', lambda c, col, dx, dy: m_cufico(c, col, dx, dy, 64, 62, 26, 3, 1), lambda c, col, dx, dy: m_anillo_cufico(c, col, dx, dy, 64, 62, 43, 26, 1), aro=False),
    'd_DIR': _mon('plata', lambda c, col, dx, dy: m_cufico(c, col, dx, dy, 64, 62, 26, 3, 2), lambda c, col, dx, dy: m_anillo_cufico(c, col, dx, dy, 64, 62, 43, 24, 2), aro=False),
    'd_ASH': _mon('oro', lambda c, col, dx, dy: m_cufico(c, col, dx, dy, 64, 62, 26, 2, 3), lambda c, col, dx, dy: (m_estrella(c, col, dx, dy, 64, 36, 7, 6), m_estrella(c, col, dx, dy, 64, 88, 7, 6))),
    'd_AKC': _mon('plata', lambda c, col, dx, dy: (c.linea(_m(bezier((38, 76), (44, 40), (86, 40), 10), dx, dy), 2.8, col), c.linea(_m([(48, 78), (48, 56)], dx, dy), 2.6, col),
                                                    c.linea(_m([(64, 78), (64, 48)], dx, dy), 2.6, col), c.linea(_m([(80, 78), (80, 56)], dx, dy), 2.6, col),
                                                    c.linea(_m(bezier((36, 84), (64, 94), (92, 84), 10), dx, dy), 2.8, col)), r=46),
    'd_TNK': _mon('plata', lambda c, col, dx, dy: m_cufico(c, col, dx, dy, 64, 62, 24, 3, 0), r=50, aro=False),
    # India y Sudeste Asiático
    'd_PAG': _mon('oro', m_pagoda, r=44),
    'd_GAD': disco_irregular('oro', m_pagoda, r=40),
    'd_MAS': masa_javanesa,
    # Europa medieval
    'd_FLO': _mon('oro', lambda c, col, dx, dy: m_lirio(c, col, dx, dy, 64, 62, 1.0), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=30)),
    'd_DUC': _mon('oro', lambda c, col, dx, dy: (m_frontal(c, col, dx, dy, 64, 66, 28, halo=True, cruz=False), m_estrella(c, col, dx, dy, 64, 30, 8, 8)), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=28)),
    'd_CRU': _mon('oro', lambda c, col, dx, dy: m_cruz(c, col, dx, dy, 64, 62, 24, 7.0), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=28)),
    'd_ECU': _mon('oro', lambda c, col, dx, dy: m_escudo(c, col, dx, dy, 64, 68, 20, 26, corona=True), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=28)),
    'd_GUL': _mon('oro', lambda c, col, dx, dy: m_escudo(c, col, dx, dy, 64, 64, 22, 28), lambda c, col, dx, dy: [c.punto(64 + 36 * math.cos(math.radians(a)) + dx, 62 + 36 * math.sin(math.radians(a)) + dy, 2.2, col) for a in range(0, 360, 45)]),
    'd_MRV': _mon('oro', lambda c, col, dx, dy: m_castillo(c, col, dx, dy, 64, 62, 1.05), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=26)),
    'd_REA': _mon('plata', lambda c, col, dx, dy: m_castillo(c, col, dx, dy, 64, 62, 1.05), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=26)),
    'd_PNY': _mon('plata', lambda c, col, dx, dy: (c.linea(_m([(64, 18), (64, 106)], dx, dy), 4.0, col), c.linea(_m([(18, 62), (110, 62)], dx, dy), 4.0, col),
                                                   [c.punto(x + dx, y + dy, 2.8, col) for (x, y) in ((50, 46), (78, 46), (50, 78), (78, 78), (46, 62 - 14), (82, 62 + 14))])),
    'd_GRO': _mon('plata', lambda c, col, dx, dy: m_corona(c, col, dx, dy, 64, 52, 24), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=30)),
    'd_GRV': barra_grivna,
    'd_DGA': disco_irregular('plata', m_jinete, r=48),
    'd_DRM': _mon('plata', lambda c, col, dx, dy: m_cruz(c, col, dx, dy, 64, 60, 20, 5.0, patada=False, latina=True), lambda c, col, dx, dy: m_leyenda(c, col, dx, dy, r=43, n=24)),
    # sin moneda acuñada
    'd_AMO': barras_sal,
    'd_CAC': cacao,
    'd_COW': caurias,
    'd_NZI': nzimbu,
    'd_TIB': polvo_oro,
    'd_TRQ': trueque,
}
