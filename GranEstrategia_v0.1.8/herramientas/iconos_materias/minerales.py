"""Minerales, metales, piedras, gemas y energía: lingotes, rocas con vetas, cristales y símbolos."""
import math
from lienzo import *


# ───────────── piezas reutilizables ─────────────
def _lingote(c, x, y, w, h, col, brillo=True):
    frente = [(x, y + h), (x + w, y + h), (x + w - w * 0.13, y), (x + w * 0.13, y)]
    c.cuerpo(frente, col, sombra=0.2, luz=0.0, d=2.4)
    c.poly([(x + w * 0.13, y), (x + w - w * 0.13, y), (x + w - w * 0.25, y - h * 0.5), (x + w * 0.25, y - h * 0.5)], claro(col, 0.38))
    c.poly([(x + w * 0.13, y), (x + w * 0.25, y - h * 0.5), (x + w * 0.2, y - h * 0.5), (x + w * 0.09, y)], claro(col, 0.55))
    if brillo:
        c.elip(x + w * 0.27, y + h * 0.42, w * 0.12, h * 0.16, (255, 255, 255, 130), -25)


def lingotes(c, col):
    _lingote(c, 12, 82, 52, 26, col)
    _lingote(c, 64, 82, 52, 26, claro(col, 0.06))
    _lingote(c, 38, 48, 52, 26, claro(col, 0.12))


def _roca(c, base, pts=None, d=3.4):
    pts = pts or [(18, 92), (14, 66), (36, 38), (68, 26), (100, 44), (112, 76), (104, 104), (60, 112)]
    return c.cuerpo(pts, base, sombra=0.22, luz=0.28, d=d)


def _roca_pequena(c, base, cx, cy, s=1.0, rot_=0):
    pts = [(cx - 26 * s, cy + 16 * s), (cx - 24 * s, cy - 6 * s), (cx - 6 * s, cy - 22 * s), (cx + 18 * s, cy - 18 * s), (cx + 28 * s, cy + 2 * s), (cx + 22 * s, cy + 18 * s)]
    if rot_:
        pts = rot(pts, rot_, cx, cy)
    return c.cuerpo(pts, base, sombra=0.22, luz=0.28, d=2.6)


def _cristal(c, x, y, ancho, alto, col, ang=0.0):
    p = [(x - ancho / 2, y), (x - ancho / 2, y - alto * 0.72), (x, y - alto), (x + ancho / 2, y - alto * 0.72), (x + ancho / 2, y)]
    if ang:
        p = rot(p, ang, x, y)
    c.poly(p, col)
    mid = [(x, y), (x, y - alto), (x + ancho / 2, y - alto * 0.72), (x + ancho / 2, y)]
    if ang:
        mid = rot(mid, ang, x, y)
    c.poly(mid, oscuro(col, 0.18))
    cara = [(x - ancho / 2, y), (x - ancho / 2, y - alto * 0.72), (x - ancho * 0.16, y - alto * 0.78), (x - ancho * 0.16, y - 2)]
    if ang:
        cara = rot(cara, ang, x, y)
    c.poly(cara, claro(col, 0.35))


def _puntos(c, mascara, col, semilla=1, n=26, r=2.4):
    def pintar(t):
        for i in range(n):
            a = i * 2.399 + semilla
            rr = math.sqrt((i + 1) / n)
            t.punto(64 + math.cos(a) * rr * 44, 66 + math.sin(a) * rr * 38, r * (0.7 + (i % 3) * 0.3), col)
    c.recortada(mascara, pintar)


def _vetas(c, mascara, col, n=3, ancho=2.4):
    def pintar(t):
        for k in range(n):
            y = 40 + k * 22
            t.linea(bezier((0, y + 10), (46, y - 12), (128, y + 16), 16), ancho, col)
    c.recortada(mascara, pintar)


def _bloque(c, col, cara_sup, cara_lado, x=18, y=48, w=76, h=52, dx=22, dy=-20):
    c.cuerpo([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], col, sombra=0.0, luz=0.0)
    c.poly([(x, y), (x + dx, y + dy), (x + w + dx, y + dy), (x + w, y)], cara_sup)
    c.poly([(x + w, y), (x + w + dx, y + dy), (x + w + dx, y + h + dy), (x + w, y + h)], cara_lado)


# ───────────── metales ─────────────
def oro(c):
    lingotes(c, hexa('f2c33a'))
    c.poly(estrella(104, 30, 11, 3.4, 4), (255, 255, 255, 230))


def plata(c):
    lingotes(c, hexa('cdd5e4'))
    c.poly(estrella(104, 30, 11, 3.4, 4), (255, 255, 255, 230))


def cobre(c):
    lingotes(c, hexa('d9743a'))


def hierro(c):
    lingotes(c, hexa('7a869c'))
    c.poly([(30, 100), (40, 100), (36, 106)], hexa('b8573a'))
    c.poly([(86, 100), (96, 100), (92, 106)], hexa('b8573a'))


def estano(c):
    lingotes(c, hexa('cbc6b6'))


def plomo(c):
    lingotes(c, hexa('4f5b7a'))


def zinc(c):
    lingotes(c, hexa('7cc0dc'))


def platino(c):
    lingotes(c, hexa('e2e6f0'))
    c.poly(estrella(104, 30, 11, 3.4, 4), (255, 255, 255, 230))


def niquel(c):
    lingotes(c, hexa('86bba2'))


def cobalto(c):
    lingotes(c, hexa('4a66c0'))


def cromo(c):
    lingotes(c, hexa('9cc4cc'))


def manganeso(c):
    lingotes(c, hexa('a0627c'))


def molibdeno(c):
    lingotes(c, hexa('8a84b8'))


def metales(c):
    _lingote(c, 12, 82, 52, 26, hexa('d9743a'))
    _lingote(c, 64, 82, 52, 26, hexa('cdd5e4'))
    _lingote(c, 38, 48, 52, 26, hexa('f2c33a'))


def alumina(c):
    _roca_pequena(c, hexa('f0e8e4'), 50, 90, 1.4)
    _roca_pequena(c, hexa('e6d8d2'), 84, 82, 1.1, 20)
    _roca_pequena(c, hexa('f6f0ec'), 66, 56, 0.9, -20)


# ───────────── rocas y minerales ─────────────
def bauxita(c):
    m = _roca(c, hexa('b8573a'))
    _puntos(c, m, hexa('e08a5a'), 2)
    _puntos(c, m, hexa('8a3a28'), 5, 14, 3.2)


def caliza(c):
    m = _roca(c, hexa('ecdfc2'))
    _vetas(c, m, hexa('c9b88e'), 3, 2.6)
    _puntos(c, m, hexa('f9f3e0'), 3, 12, 2.6)


def caliza_plural(c):
    caliza(c)


def carbon(c):
    for (x, y, s, a) in ((42, 84, 1.2, 0), (84, 84, 1.1, 30), (62, 50, 1.0, -20)):
        _roca_pequena(c, hexa('3a3f52'), x, y, s, a)
        c.elip(x - 10 * s, y - 8 * s, 5 * s, 2.6 * s, (200, 210, 235, 150), -35)


def lignito(c):
    for (x, y, s, a) in ((42, 84, 1.2, 0), (84, 84, 1.1, 30), (62, 50, 1.0, -20)):
        _roca_pequena(c, hexa('7a5438'), x, y, s, a)
        c.elip(x - 10 * s, y - 8 * s, 4 * s, 2.2 * s, (230, 200, 170, 120), -35)


def grafito(c):
    m = _roca(c, hexa('54596c'))
    def laminas(t):
        for k in range(5):
            t.linea([(10 + k * 6, 100 - k * 14), (70 + k * 6, 54 - k * 14)], 2.6, hexa('8a90a8'))
    c.recortada(m, laminas)


def litio(c):
    m = _roca(c, hexa('c9bfe0'))
    _puntos(c, m, hexa('efe8fa'), 4, 16, 2.8)
    _vetas(c, m, hexa('a89ac8'), 2, 2.4)


def potasa(c):
    for (x, y, w, h, a) in ((40, 96, 22, 50, -16), (64, 100, 26, 62, 0), (90, 96, 22, 46, 18)):
        _cristal(c, x, y, w, h, hexa('ee8fa0'), a)


def fosfatos(c):
    for (x, y, w, h, a) in ((40, 96, 22, 50, -16), (64, 100, 26, 62, 0), (90, 96, 22, 46, 18)):
        _cristal(c, x, y, w, h, hexa('f2a640'), a)


def fluorita(c):
    for (x, y, s, a) in ((44, 84, 30, -10), (82, 84, 28, 12), (62, 56, 26, 4)):
        p = [(x - s / 2, y - s / 2), (x + s / 2, y - s / 2), (x + s / 2, y + s / 2), (x - s / 2, y + s / 2)]
        c.cuerpo(rot(p, a, x, y), hexa('9a6ad8'), sombra=0.22, luz=0.35, d=2.2)
        c.elip(x - s * 0.22, y - s * 0.22, s * 0.12, s * 0.1, (255, 255, 255, 140), 0)


def ambar(c):
    c.cuerpo(gota(64, 78, 34, 84, 0), hexa('f0a72e'), sombra=0.22, luz=0.3, d=3.4)
    c.elip(64, 84, 8, 5, hexa('7a4a1a'), 0)
    c.linea([(56, 82), (46, 76)], 1.4, hexa('7a4a1a'))
    c.linea([(72, 82), (82, 76)], 1.4, hexa('7a4a1a'))
    c.brillo(50, 64, 4, 12, 20)


def tierras_raras(c):
    for (x, y, w, h, a) in ((38, 98, 20, 44, -20), (64, 102, 26, 66, 0), (92, 98, 20, 50, 20)):
        _cristal(c, x, y, w, h, hexa('3fb8b0'), a)
    c.poly(estrella(98, 24, 9, 3, 4), (255, 255, 255, 220))


def magnesita(c):
    m = _roca(c, hexa('d8dcd2'))
    _vetas(c, m, hexa('7ac0a8'), 3, 2.8)


def caolin(c):
    _roca_pequena(c, hexa('f6f2ea'), 64, 84, 1.9)
    c.elip(46, 70, 6, 3, (255, 255, 255, 200), -30)


def yeso(c):
    for (x, y, w, h, a) in ((38, 98, 18, 40, -24), (62, 102, 24, 62, -4), (88, 98, 18, 46, 20)):
        _cristal(c, x, y, w, h, hexa('f6f4ee'), a)


def coltan(c):
    m = _roca(c, hexa('4a5068'))
    _puntos(c, m, hexa('9aa6c4'), 7, 22, 2.4)
    _puntos(c, m, hexa('2a2f42'), 1, 12, 3.6)


def cuarzo(c):
    for (x, y, w, h, a) in ((38, 98, 20, 40, -22), (64, 102, 28, 78, 0), (92, 98, 20, 48, 22)):
        _cristal(c, x, y, w, h, hexa('e4e8f6'), a)


def boro(c):
    for (x, y, s, a) in ((44, 84, 26, 0), (80, 84, 24, 20), (62, 54, 24, -10)):
        c.cuerpo(rot(regular(x, y, s / 2 * 1.2, 6, -90), a, x, y), hexa('f0efe4'), sombra=0.2, luz=0.3, d=2)


def pizarra(c):
    for k in range(5):
        c.cuerpo(rot([(20, 100 - k * 14), (104, 100 - k * 14), (108, 90 - k * 14), (24, 90 - k * 14)], 0), hexa('4a5266') if k % 2 else hexa('59627a'), sombra=0.2, luz=0.3, d=1.6)


def talco(c):
    m = _roca(c, hexa('b8d8b4'))
    _puntos(c, m, hexa('e0f2da'), 6, 14, 3.4)


def soda(c):
    for (x, y, w, h, a) in ((40, 96, 20, 36, -18), (64, 100, 24, 54, 0), (90, 96, 20, 40, 18)):
        _cristal(c, x, y, w, h, hexa('f6e8a8'), a)


def taconita(c):
    m = _roca(c, hexa('4a4a5a'))
    _vetas(c, m, hexa('b8573a'), 4, 3.4)


def jade(c):
    c.cuerpo(spline([(20, 70), (36, 38), (76, 26), (104, 48), (108, 84), (82, 108), (40, 106)]), hexa('4fb883'), sombra=0.22, luz=0.35, d=3.6)
    c.elip(64, 66, 14, 14, (0, 0, 0, 0), 0)
    c.brillo(46, 52, 6, 14, 30)


def sal(c):
    for (x, y, s, a) in ((40, 90, 36, -6), (84, 88, 32, 8), (62, 54, 30, 4)):
        p = [(x - s / 2, y - s / 2), (x + s / 2, y - s / 2), (x + s / 2, y + s / 2), (x - s / 2, y + s / 2)]
        c.cuerpo(rot(p, a, x, y), hexa('f6f8ff'), sombra=0.2, luz=0.0, d=2.4, col_sombra=hexa('c4cde4'))
        c.elip(x - s * 0.2, y - s * 0.2, s * 0.14, s * 0.1, (190, 205, 235, 255), 0)


def arena(c):
    c.cuerpo(spline([(8, 108), (30, 90), (46, 64), (64, 34), (82, 62), (100, 88), (120, 108)], cerrada=True), hexa('e8c878'), sombra=0.22, luz=0.25, d=3.4)
    for (x, y) in ((50, 90), (72, 82), (60, 66), (88, 98), (36, 100), (64, 102)):
        c.punto(x, y, 1.8, hexa('c9a458'))


def arena_silicea(c):
    arena(c)


def piedra(c):
    _bloque(c, hexa('9aa3b4'), hexa('c4ccda'), hexa('737c90'), x=14, y=60, w=48, h=42, dx=14, dy=-14)
    _bloque(c, hexa('8a93a6'), hexa('b4bccc'), hexa('656e82'), x=66, y=74, w=40, h=34, dx=12, dy=-12)
    _bloque(c, hexa('a4adbe'), hexa('ccd4e2'), hexa('7a8398'), x=34, y=30, w=40, h=34, dx=14, dy=-12)


def piedra_triturada(c):
    for i in range(24):
        a = i * 2.399
        r = math.sqrt((i + 1) / 24.0) * 40
        x, y = 64 + math.cos(a) * r, 84 + math.sin(a) * r * 0.45 - (i % 5) * 2
        _roca_pequena(c, hexa('a0a8b8') if i % 2 else hexa('8a93a6'), x, y, 0.34 + (i % 3) * 0.08, i * 40)


def marmol(c):
    _bloque(c, hexa('f4f5fa'), hexa('ffffff'), hexa('c8cee0'))
    m = Image.new('L', (c.t, c.t), 0)
    c.linea(bezier((26, 54), (46, 72), (30, 96), 10), 1.8, hexa('9aa4c0'))
    c.linea(bezier((64, 50), (50, 74), (78, 98), 10), 1.4, hexa('b0b8d0'))


def granito(c):
    _bloque(c, hexa('c8a8a0'), hexa('e0c8c0'), hexa('9a7e78'))
    for i in range(26):
        a = i * 2.399
        r = math.sqrt((i + 1) / 26.0)
        x, y = 56 + math.cos(a) * r * 34, 74 + math.sin(a) * r * 22
        c.punto(x, y, 1.8, hexa('4a4458') if i % 2 else hexa('f6efe6'))


def uranio(c):
    c.elip(64, 74, 50, 44, (130, 255, 120, 60), 0)
    m = _roca(c, hexa('5a7a50'), [(18, 100), (14, 78), (34, 52), (68, 44), (100, 58), (112, 84), (104, 108), (60, 116)])
    _puntos(c, m, hexa('9aff6a'), 3, 14, 3.2)
    c.punto(64, 38, 19, hexa('f2e04a'))
    for ang in (-90, 30, 150):
        pts = [(64, 38)] + [(64 + 17 * math.cos(math.radians(ang + d)), 38 + 17 * math.sin(math.radians(ang + d))) for d in range(-30, 31, 6)]
        c.poly(pts, hexa('2a2f3c'))
    c.punto(64, 38, 4, hexa('f2e04a'))
    c.punto(64, 38, 2.6, hexa('2a2f3c'))


def diamantes(c):
    gema(c, hexa('7ad8f0'))


def gema(c, col=hexa('7ad8f0'), x=64, y=64, s=1.0):
    corona = [(x - 40 * s, y - 14 * s), (x - 24 * s, y - 36 * s), (x + 24 * s, y - 36 * s), (x + 40 * s, y - 14 * s)]
    c.poly(corona + [(x + 24 * s, y - 14 * s), (x - 24 * s, y - 14 * s)], claro(col, 0.35))
    c.poly([(x - 40 * s, y - 14 * s), (x + 40 * s, y - 14 * s), (x, y + 44 * s)], col)
    c.poly([(x - 40 * s, y - 14 * s), (x - 24 * s, y - 14 * s), (x - 8 * s, y + 38 * s), (x, y + 44 * s)], claro(col, 0.18))
    c.poly([(x + 40 * s, y - 14 * s), (x + 24 * s, y - 14 * s), (x + 8 * s, y + 38 * s), (x, y + 44 * s)], oscuro(col, 0.22))
    c.poly([(x - 24 * s, y - 14 * s), (x + 24 * s, y - 14 * s), (x + 8 * s, y + 38 * s), (x - 8 * s, y + 38 * s)], mezcla(col, (255, 255, 255, 255), 0.05))
    c.poly([(x - 24 * s, y - 36 * s), (x - 12 * s, y - 14 * s), (x - 4 * s, y - 36 * s)], claro(col, 0.6))
    c.poly(estrella(x + 38 * s, y - 40 * s, 10, 3, 4), (255, 255, 255, 240))


def gemas(c):
    gema(c, hexa('e0566a'), 40, 82, 0.62)
    gema(c, hexa('4a8ae8'), 88, 82, 0.62)
    gema(c, hexa('4fd09a'), 64, 46, 0.62)


def esmeraldas(c):
    col = hexa('3fc07a')
    c.poly([(30, 44), (46, 24), (82, 24), (98, 44), (98, 84), (82, 104), (46, 104), (30, 84)], col)
    c.poly([(40, 50), (52, 34), (76, 34), (88, 50), (88, 78), (76, 94), (52, 94), (40, 78)], claro(col, 0.3))
    c.poly([(48, 54), (56, 44), (72, 44), (80, 54), (80, 74), (72, 84), (56, 84), (48, 74)], hexa('2a9a5e'))
    c.poly([(30, 44), (46, 24), (52, 34), (40, 50)], claro(col, 0.5))
    c.poly([(98, 84), (82, 104), (76, 94), (88, 78)], oscuro(col, 0.3))


def corcho(c):
    c.cuerpo(spline([(26, 24), (102, 24), (106, 100), (22, 100)], por_tramo=4, cerrada=True), hexa('d4a460'), sombra=0.22, luz=0.2, d=2.8)
    c.elip(64, 24, 38, 10, hexa('e8c080'))
    for (x, y) in ((44, 56), (74, 48), (60, 76), (88, 84), (36, 88)):
        c.punto(x, y, 2.4, hexa('a87a38'))


def helio(c):
    for (x, y, col) in ((44, 44, hexa('f06a8a')), (84, 40, hexa('6ab0f0')), (64, 60, hexa('f4d03a'))):
        c.linea([(x, y + 26), (64, 118)], 1.4, hexa('c8d0e4'))
        c.cuerpo(spline([(x - 22, y), (x, y - 26), (x + 22, y), (x + 14, y + 22), (x, y + 28), (x - 14, y + 22)]), col, sombra=0.22, luz=0.3, d=2.4)
    c.poly(regular(64, 118, 4, 3, 90), hexa('c8d0e4'))


def agua(c):
    c.cuerpo(gota(64, 76, 36, 74, 0), hexa('5ab4f0'), sombra=0.2, luz=0.3, d=3.4)
    c.brillo(48, 76, 5, 14, 20)


def madera(c):
    for (x, y) in ((34, 90), (82, 90), (58, 56)):
        c.cuerpo(spline([(x - 28, y - 22), (x + 28, y - 22), (x + 28, y + 22), (x - 28, y + 22)], por_tramo=3, cerrada=True), hexa('a0683a'), sombra=0.2, luz=0.25, d=2.6)
        c.cuerpo_elip(x + 28, y, 10, 22, col=hexa('e8c080'), sombra=0.15, luz=0.1, d=1.6)
        c.elip(x + 28, y, 6, 14, hexa('c99a58'))
        c.elip(x + 28, y, 2.4, 6, hexa('a87a38'))
    for (x, y) in ((22, 80), (56, 100), (60, 46)):
        c.linea([(x, y), (x + 14, y)], 1.6, hexa('7a4a28'))


def madera_celulosa(c):
    madera(c)


# ───────────── energía y lugares ─────────────
def petroleo(c):
    c.cuerpo(spline([(24, 38), (84, 38), (84, 112), (24, 112)], por_tramo=3, cerrada=True), hexa('4a5268'), sombra=0.22, luz=0.2, d=2.8)
    for y in (52, 96):
        c.rect(22, y - 3, 86, y + 5, hexa('6a7390'), r=2)
    c.cuerpo(gota(96, 74, 17, 36, 0), hexa('2a2f3c'), sombra=0.0, luz=0.0)
    c.brillo(90, 72, 2.6, 6, 20)
    c.cuerpo(spline([(40, 20), (68, 20), (68, 38), (40, 38)], por_tramo=3, cerrada=True), hexa('d9a02a'), sombra=0.2, luz=0.2, d=1.6)


def gas(c):
    c.cuerpo(spline([(64, 8), (88, 40), (98, 70), (84, 106), (64, 116), (44, 106), (30, 70), (42, 46), (50, 58), (56, 36)]), hexa('5aa8f0'), sombra=0.2, luz=0.25, d=3)
    c.cuerpo(spline([(64, 52), (78, 74), (74, 98), (64, 106), (54, 98), (50, 76)]), hexa('c0e0ff'), sombra=0.15, luz=0.3, d=2)
    c.cuerpo(spline([(64, 78), (70, 92), (64, 100), (58, 92)], por_tramo=4), hexa('ffffff'), sombra=0, luz=0)


def hidroelectrica(c):
    c.cuerpo(spline([(14, 40), (74, 40), (74, 112), (14, 112)], por_tramo=3, cerrada=True), hexa('a0a8b8'), sombra=0.22, luz=0.25, d=2.8)
    for y in (58, 76, 94):
        c.linea([(16, y), (72, y)], 1.4, hexa('7c869b'))
    c.cuerpo(spline([(78, 62), (114, 62), (114, 118), (78, 118)], por_tramo=3, cerrada=True), hexa('5ab4f0'), sombra=0.2, luz=0.25, d=2)
    for y in (76, 92, 106):
        c.linea([(84, y), (108, y)], 1.8, hexa('d8eeff'))
    c.poly([(62, 4), (46, 26), (58, 26), (50, 44), (74, 20), (62, 20), (70, 4)], hexa('f4d03a'))


def energia(c):
    c.poly([(74, 8), (30, 70), (58, 70), (48, 120), (98, 54), (68, 54), (82, 8)], hexa('f4d03a'))
    c.poly([(74, 8), (30, 70), (42, 70), (80, 18)], hexa('fbe880'))


def nuclear(c):
    c.elip(64, 64, 6, 6, hexa('f4d03a'))
    for ang in (0, 60, 120):
        pts = rot(elipse(64, 64, 46, 17), ang, 64, 64)
        c.linea(pts + [pts[0]], 3.4, hexa('7aa8f0'))
    for (x, y) in ((110, 64), (41, 24), (41, 104)):
        c.cuerpo_elip(x, y, 6, 6, col=hexa('e0605a'), sombra=0.2, luz=0.3, d=1.4)


def renovable(c):
    c.linea([(64, 118), (64, 54)], 6, hexa('e8ecf8'))
    c.rect(58, 108, 70, 120, hexa('b8c0d8'), r=2)
    for ang in (-90, 30, 150):
        a = math.radians(ang)
        c.cuerpo(hoja(64, 52, 64 + math.cos(a) * 42, 52 + math.sin(a) * 42, 6, curva=0), hexa('f4f6ff'), sombra=0.2, luz=0.1, d=1.6, col_sombra=hexa('c0c8e0'))
    c.cuerpo_elip(64, 52, 7, 7, col=hexa('7aa8f0'), sombra=0.2, luz=0.3, d=1.2)
    c.punto(104, 24, 10, hexa('f4d03a'))


def geotermica(c):
    c.cuerpo(spline([(4, 104), (24, 90), (64, 84), (104, 90), (124, 104), (124, 124), (4, 124)], por_tramo=6, cerrada=True), hexa('8a6048'), sombra=0.22, luz=0.25, d=3)
    for (x, dy) in ((40, 0), (64, 10), (88, 0)):
        c.linea(bezier((x, 84), (x - 14, 62 - dy), (x + 14, 44 - dy), 12) + bezier((x + 14, 44 - dy), (x - 10, 26 - dy), (x, 8), 12)[1:], 6, hexa('e8eeff'))


def turismo(c):
    c.linea([(64, 118), (64, 54)], 3.4, CAFE2)
    c.cuerpo(spline([(6, 56), (22, 28), (64, 14), (106, 28), (122, 56), (104, 50), (86, 56), (64, 48), (42, 56), (24, 50)]), hexa('e0605a'), sombra=0.2, luz=0.25, d=2.8)
    for x in (42, 64, 86):
        c.linea([(x, 18), (x, 50)], 1.4, hexa('fbe8e0'))
    c.cuerpo(spline([(14, 112), (50, 104), (114, 112), (118, 124), (10, 124)], por_tramo=6, cerrada=True), hexa('f4d78a'), sombra=0.2, luz=0.25, d=2.2)
    c.punto(104, 26, 8, hexa('f4d03a'))


def investigacion(c):
    c.cuerpo(spline([(50, 14), (78, 14), (78, 54), (112, 106), (104, 118), (24, 118), (16, 106), (50, 54)], por_tramo=4, cerrada=True), hexa('d8ecff'), sombra=0.18, luz=0.2, d=2.6)
    c.poly(spline([(38, 80), (90, 80), (112, 106), (104, 118), (24, 118), (16, 106)], por_tramo=4, cerrada=True), hexa('6ad0a8'))
    c.rect(44, 10, 84, 20, hexa('b8c4de'), r=3)
    c.punto(56, 98, 5, hexa('b8f0d8'))
    c.punto(76, 90, 3, hexa('b8f0d8'))
    c.punto(70, 104, 3.6, hexa('b8f0d8'))


def canal(c):
    c.cuerpo(spline([(6, 90), (122, 90), (116, 118), (12, 118)], por_tramo=4, cerrada=True), hexa('4a8ad8'), sombra=0.2, luz=0.25, d=2.4)
    for x in (20, 44, 68, 92):
        c.linea(bezier((x, 104), (x + 6, 98), (x + 12, 104), 8), 2.0, hexa('a8d0f8'))
    c.cuerpo(spline([(22, 60), (106, 60), (94, 90), (34, 90)], por_tramo=4, cerrada=True), hexa('e0605a'), sombra=0.2, luz=0.25, d=2.4)
    c.rect(44, 38, 84, 60, hexa('f4f6ff'), r=3)
    c.rect(56, 24, 70, 38, hexa('d0d8ec'), r=2)
    for x in (52, 64, 76):
        c.punto(x, 50, 3, hexa('4a8ad8'))
    c.rect(2, 66, 14, 96, hexa('8a93a6'), r=2)
    c.rect(114, 66, 126, 96, hexa('8a93a6'), r=2)


def minerales_diversos(c):
    _roca_pequena(c, hexa('a0a8b8'), 44, 90, 1.3)
    _roca_pequena(c, hexa('b8573a'), 86, 88, 1.1, 16)
    _roca_pequena(c, hexa('7a8ac8'), 64, 58, 1.0, -14)
    c.poly(estrella(104, 34, 10, 3, 4), (255, 255, 255, 230))


def ninguno(c):
    c.linea([(36, 36), (92, 92)], 10, hexa('6a7388'))
    c.linea([(92, 36), (36, 92)], 10, hexa('6a7388'))


ICONOS = {
    'oro': oro, 'plata': plata, 'cobre': cobre, 'hierro': hierro, 'estano': estano, 'plomo': plomo, 'zinc': zinc, 'platino': platino, 'niquel': niquel,
    'cobalto': cobalto, 'cromo': cromo, 'manganeso': manganeso, 'molibdeno': molibdeno, 'metales': metales, 'alumina': alumina,
    'bauxita': bauxita, 'caliza': caliza, 'carbon': carbon, 'lignito': lignito, 'grafito': grafito, 'litio': litio, 'potasa': potasa, 'fosfatos': fosfatos,
    'fluorita': fluorita, 'ambar': ambar, 'tierras_raras': tierras_raras, 'magnesita': magnesita, 'caolin': caolin, 'yeso': yeso, 'coltan': coltan,
    'cuarzo': cuarzo, 'boro': boro, 'pizarra': pizarra, 'talco': talco, 'soda': soda, 'taconita': taconita, 'jade': jade, 'sal': sal, 'arena': arena,
    'piedra': piedra, 'piedra_triturada': piedra_triturada, 'marmol': marmol, 'granito': granito, 'uranio': uranio, 'diamantes': diamantes, 'gemas': gemas,
    'esmeraldas': esmeraldas, 'corcho': corcho, 'helio': helio, 'agua': agua, 'madera': madera,
    'petroleo': petroleo, 'gas': gas, 'hidroelectrica': hidroelectrica, 'energia': energia, 'nuclear': nuclear, 'renovable': renovable, 'geotermica': geotermica,
    'turismo': turismo, 'investigacion': investigacion, 'canal': canal, 'minerales_diversos': minerales_diversos,
}
