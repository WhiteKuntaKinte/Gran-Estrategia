"""Cultivos del juego: cereales, frutas, raíces, hortalizas, plantas industriales. Cada función dibuja un icono sobre un Lienzo."""
import math
from lienzo import *


def _curva_tallo(p0, p1, p2, n=24):
    return bezier(p0, p1, p2, n)


def _tangente(pts, i):
    a = pts[max(0, i - 1)]
    b = pts[min(len(pts) - 1, i + 1)]
    L = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
    return (b[0] - a[0]) / L, (b[1] - a[1]) / L


def _grano_a_lo_largo(c, tallo, desde, hasta, n, col, rx=5.6, ry=9.0, abre=28, arista=0.0, col_arista=None, sep=5.4):
    """Granos en pares a lo largo de un tallo (desde/hasta en 0..1)."""
    for k in range(n):
        t = desde + (hasta - desde) * (k / max(1, n - 1))
        i = min(len(tallo) - 1, int(t * (len(tallo) - 1)))
        x, y = tallo[i]
        tx, ty = _tangente(tallo, i)
        ang = math.degrees(math.atan2(ty, tx)) + 90.0
        for lado in (-1, 1):
            cx = x + (-ty) * lado * sep
            cy = y + tx * lado * sep
            c.cuerpo(elipse(cx, cy, rx, ry, ang + lado * abre), col, sombra=0.14, luz=0.35, d=1.6)
            if arista > 0:
                ex = cx + math.cos(math.radians(ang - 90 + lado * abre)) * ry * 0.9
                ey = cy + math.sin(math.radians(ang - 90 + lado * abre)) * ry * 0.9
                dx = math.cos(math.radians(ang - 90 + lado * abre * 0.6)) * arista
                dy = math.sin(math.radians(ang - 90 + lado * abre * 0.6)) * arista
                c.linea([(ex, ey), (ex + dx, ey + dy)], 1.4, col_arista or oscuro(col, 0.1))


def espiga(c, col, arista=0.0, n=6, tallo=VERDE2, ry=9.4):
    t = _curva_tallo((52, 122), (52, 80), (66, 30))
    c.linea(t, 3.6, tallo)
    _grano_a_lo_largo(c, t, 0.50, 0.95, n, col, ry=ry, arista=arista)
    ex, ey = t[-1]
    c.cuerpo(elipse(ex + 0.5, ey - 3, 5.2, 10.0, 8), col, sombra=0.14, luz=0.35, d=1.6)
    if arista > 0:
        c.linea([(ex + 1, ey - 10), (ex + 3, ey - 10 - arista)], 1.4, oscuro(col, 0.1))
    # hoja
    c.cuerpo(hoja(53, 112, 86, 80, 6, curva=-6), tallo, sombra=0.2, luz=0.2, d=1.6)


def trigo(c):
    espiga(c, ORO, arista=12, n=5)


def cebada(c):
    espiga(c, hexa('e8d27a'), arista=26, n=5, ry=8.2)


def centeno(c):
    espiga(c, hexa('bfae78'), arista=20, n=6, ry=8.6)


def avena(c):
    c.linea([(64, 122), (64, 56)], 3.4, VERDE2)
    for ang, largo in ((-64, 46), (-34, 54), (0, 56), (34, 54), (64, 46)):
        a = math.radians(ang - 90)
        ex, ey = 64 + math.cos(a) * largo * 0.8, 58 + math.sin(a) * largo * 0.8
        t = bezier((64, 56), (64 + math.cos(a) * largo * 0.6, 56 + math.sin(a) * largo * 0.9), (ex, ey + 6), 12)
        c.linea(t, 2.0, VERDE2)
        gx, gy = t[-1]
        c.cuerpo(elipse(gx, gy + 7, 5.0, 10.0, 0), hexa('efe3a8'), sombra=0.15, luz=0.3, d=1.6)
        c.cuerpo(elipse(gx + (3 if ang >= 0 else -3), gy + 20, 4.4, 8.0, 10 if ang >= 0 else -10), hexa('e6d794'), sombra=0.15, luz=0.3, d=1.6)
    c.cuerpo(hoja(64, 112, 96, 90, 6, curva=-5), VERDE, sombra=0.2, luz=0.2, d=1.6)


def mijo(c):
    t = bezier((44, 124), (44, 50), (86, 26), 22)
    c.linea(t, 3.8, VERDE2)
    m = c.cuerpo(elipse(88, 66, 17, 36, -8), hexa('d9a43e'), sombra=0.2, luz=0.3)
    def pepitas(tt):
        for i in range(60):
            a = i * 2.399
            r = math.sqrt(i / 60.0)
            x = 88 + math.cos(a) * r * 17
            y = 66 + math.sin(a) * r * 36
            tt.cuerpo(elipse(x, y, 4.2, 4.2), hexa('f0c964'), sombra=0.15, luz=0.4, d=1.2)
    c.recortada(m, pepitas)
    c.cuerpo(hoja(46, 112, 12, 82, 6, curva=5), VERDE, sombra=0.2, luz=0.2, d=1.6)


def sorgo(c):
    c.linea([(60, 124), (62, 70)], 4.0, VERDE2)
    c.cuerpo(elipse(62, 46, 22, 26, 0), hexa('a3482f'), sombra=0.2, luz=0.3)
    for i in range(40):
        a = i * 0.618 * 2 * math.pi
        r = math.sqrt(i / 40.0) * 21
        c.punto(62 + math.cos(a) * r * 0.9, 46 + math.sin(a) * r * 1.15, 3.2, hexa('c4603f') if i % 2 else hexa('8b3a27'))
    c.cuerpo(hoja(62, 112, 100, 84, 7, curva=-6), VERDE, sombra=0.2, luz=0.2, d=1.6)


def arroz(c):
    t = bezier((40, 124), (44, 40), (96, 34), 26)
    c.linea(t, 3.4, VERDE2)
    _grano_a_lo_largo(c, t, 0.40, 1.0, 8, hexa('f6efc4'), rx=5.0, ry=9.6, abre=34, sep=4.6)
    c.cuerpo(hoja(41, 118, 14, 92, 6, curva=5), VERDE, sombra=0.2, luz=0.2, d=1.6)


def quinua(c):
    c.linea([(64, 124), (64, 56)], 4.0, VERDE2)
    cols = [hexa('c9406f'), hexa('e0824a'), hexa('f0c84a'), hexa('b33a63')]
    n = 0
    for fila in range(8):
        y = 20 + fila * 7.4
        ancho = 3 + fila * 2.6
        k = 2 + fila // 2 * 1
        for j in range(k + 2):
            x = 64 + (j - (k + 1) / 2.0) * (ancho * 2 / (k + 1))
            c.cuerpo(elipse(x, y, 4.4, 4.4), cols[(n + fila) % 4], sombra=0.14, luz=0.3, d=1.4)
            n += 1


def teff(c):
    t = bezier((64, 124), (64, 90), (64, 44), 20)
    c.linea(t, 3.0, VERDE2)
    for k in range(10):
        y = 18 + k * 5.4
        w = 6 + (k % 3) * 2
        c.linea([(64, y + 10), (64 - 20 + k * 1.5, y - 2)], 1.4, VERDE2)
        c.linea([(64, y + 10), (64 + 20 - k * 1.5, y - 2)], 1.4, VERDE2)
        c.punto(64 - 20 + k * 1.5, y - 2, 3.0, hexa('d9b97a'))
        c.punto(64 + 20 - k * 1.5, y - 2, 3.0, hexa('d9b97a'))
    c.punto(64, 12, 4, hexa('d9b97a'))


def maiz(c):
    # hojas atrás
    c.cuerpo(hoja(64, 120, 20, 50, 15, curva=-10), VERDE2, sombra=0.2, luz=0.2)
    c.cuerpo(hoja(64, 120, 108, 50, 15, curva=10), VERDE2, sombra=0.2, luz=0.2)
    mz = c.cuerpo(elipse(64, 58, 20, 42, 0), hexa('f2c33a'), sombra=0.22, luz=0.3)
    def granos(t):
        for fila in range(9):
            for col in range(5):
                x = 64 + (col - 2) * 8.2
                y = 24 + fila * 8.4
                t.cuerpo(elipse(x, y, 3.7, 3.7), hexa('f8d65c'), sombra=0.12, luz=0.4, d=1.2)
    c.recortada(mz, granos)
    c.cuerpo(hoja(64, 122, 36, 62, 11, curva=6), VERDE, sombra=0.2, luz=0.25)
    c.cuerpo(hoja(64, 122, 92, 62, 11, curva=-6), VERDE, sombra=0.2, luz=0.25)
    c.cuerpo(hoja(64, 122, 64, 70, 8), LIMA, sombra=0.2, luz=0.25)


def maiz_forraje(c):
    c.linea([(40, 124), (40, 30)], 5, VERDE3)
    c.cuerpo(hoja(40, 92, 8, 62, 7, curva=5), VERDE, sombra=0.2, luz=0.2)
    c.cuerpo(hoja(40, 70, 82, 36, 7, curva=-5), VERDE, sombra=0.2, luz=0.2)
    c.cuerpo(hoja(40, 58, 10, 28, 6, curva=4), VERDE, sombra=0.2, luz=0.2)
    c.cuerpo(elipse(78, 90, 13, 28, 14), hexa('f2c33a'), sombra=0.22, luz=0.3)
    c.cuerpo(hoja(76, 122, 58, 84, 8, curva=5), VERDE, sombra=0.2, luz=0.25)
    c.cuerpo(hoja(78, 122, 104, 84, 8, curva=-5), VERDE, sombra=0.2, luz=0.25)


# ───────────── frutas ─────────────
def _tallito(c, x, y, dx=2, dy=-12, col=CAFE2):
    c.linea([(x, y), (x + dx, y + dy)], 3.0, col)


def manzana(c):
    c.cuerpo(spline([(64, 40), (84, 34), (102, 50), (100, 80), (84, 108), (64, 104), (44, 108), (28, 80), (26, 50), (44, 34)]), ROJO, sombra=0.2, luz=0.3, d=3.6)
    _tallito(c, 64, 42, 4, -18)
    c.cuerpo(hoja(68, 26, 96, 14, 6, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.6)
    c.brillo(42, 58, 5, 12, 10)


def pera(c):
    c.cuerpo(spline([(64, 18), (76, 28), (80, 54), (98, 82), (92, 106), (64, 114), (36, 106), (30, 82), (48, 54), (52, 28)]), hexa('b9d94c'), sombra=0.2, luz=0.3, d=3.6)
    _tallito(c, 64, 20, 5, -12)
    c.cuerpo(hoja(68, 16, 92, 8, 5, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.6)
    c.brillo(46, 86, 4, 10, 20)


def naranja(c):
    c.cuerpo_elip(64, 70, 38, 36, col=NARANJA, sombra=0.2, luz=0.3, d=3.6)
    for i in range(14):
        a = i * 2.4
        r = 5 + (i % 5) * 7
        c.punto(64 + math.cos(a) * r * 0.9, 70 + math.sin(a) * r * 0.85, 1.6, hexa('d9782a'))
    c.cuerpo(hoja(66, 36, 98, 24, 7, curva=-3), VERDE, sombra=0.2, luz=0.2, d=1.6)
    c.punto(64, 36, 3.4, VERDE3)
    c.brillo(44, 52, 5, 10, 40)


def limon(c):
    forma = spline([(14, 66), (30, 48), (64, 38), (98, 48), (114, 62), (98, 86), (64, 98), (30, 90)])
    c.cuerpo(rot(forma, -12, 64, 66), hexa('f4dc3c'), sombra=0.2, luz=0.3, d=3.6)
    c.cuerpo(hoja(66, 38, 96, 22, 6, curva=-3), VERDE, sombra=0.2, luz=0.2, d=1.6)
    c.brillo(46, 56, 4, 10, 60)


def citricos(c):
    c.cuerpo_elip(44, 78, 28, 26, col=NARANJA, sombra=0.2, luz=0.3, d=3)
    c.cuerpo(rot(spline([(60, 48), (76, 34), (104, 36), (116, 54), (104, 76), (76, 80), (60, 66)]), -10, 88, 58), hexa('f4dc3c'), sombra=0.2, luz=0.3, d=3)
    # rodaja
    c.cuerpo_elip(78, 92, 22, 22, col=hexa('f0a040'), sombra=0.18, luz=0.2, d=2.5)
    c.elip(78, 92, 17, 17, hexa('ffd27a'))
    for i in range(8):
        a = math.radians(i * 45 + 20)
        c.linea([(78, 92), (78 + math.cos(a) * 16, 92 + math.sin(a) * 16)], 1.8, hexa('f0a040'))
    c.cuerpo(hoja(44, 54, 64, 36, 5, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.4)


def melocoton(c):
    c.cuerpo(spline([(64, 36), (88, 32), (104, 54), (100, 82), (80, 106), (64, 108), (48, 106), (28, 82), (24, 54), (40, 32)]), hexa('f6a46a'), sombra=0.2, luz=0.3, d=3.6)
    c.linea(bezier((64, 38), (58, 62), (66, 96), 14), 2.2, hexa('e07a50'))
    c.cuerpo_elip(46, 60, 14, 22, col=hexa('f4846a'), sombra=0, luz=0, ang=12)
    c.elip(46, 60, 14, 22, (244, 132, 106, 90), 12)
    _tallito(c, 64, 38, 2, -10)
    c.cuerpo(hoja(66, 28, 94, 14, 6, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.6)


def cereza(c):
    c.linea(bezier((46, 80), (50, 44), (76, 18), 16), 2.6, VERDE2)
    c.linea(bezier((84, 84), (80, 48), (76, 18), 16), 2.6, VERDE2)
    c.cuerpo(hoja(76, 20, 106, 14, 5, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.6)
    c.cuerpo_elip(44, 92, 20, 20, col=hexa('c92d4a'), sombra=0.22, luz=0.3, d=3)
    c.cuerpo_elip(86, 96, 20, 20, col=hexa('d83a52'), sombra=0.22, luz=0.3, d=3)
    c.brillo(37, 85, 3, 6, 30)
    c.brillo(79, 89, 3, 6, 30)


def arandano(c):
    for (x, y, r) in ((44, 80, 26), (86, 76, 25), (64, 44, 24)):
        c.cuerpo_elip(x, y, r, r, col=hexa('4a63c4'), sombra=0.22, luz=0.25, d=3)
        c.elip(x, y - r * 0.15, r * 0.38, r * 0.38, hexa('2d3f96'))
        c.poly(estrella(x, y - r * 0.15, r * 0.34, r * 0.16, 5), hexa('7b8fe0'))
    c.brillo(36, 70, 3, 6, 30)


def fresa(c):
    c.cuerpo(spline([(64, 40), (92, 36), (108, 52), (96, 84), (64, 116), (32, 84), (20, 52), (36, 36)]), hexa('e0434f'), sombra=0.2, luz=0.3, d=3.6)
    for (x, y) in ((50, 56), (74, 54), (62, 70), (42, 74), (84, 72), (54, 88), (72, 90), (64, 104), (96, 58), (34, 58)):
        c.elip(x, y, 2.0, 3.2, hexa('f9d860'), 20)
    c.poly(estrella(64, 36, 28, 12, 7), VERDE)
    c.poly(estrella(64, 36, 18, 8, 7, ang=-80), VERDE2)
    c.linea([(64, 36), (68, 14)], 3.6, VERDE3)


def frambuesa(c):
    pts = [(64, 50), (40, 60), (88, 60), (52, 74), (76, 74), (36, 80), (92, 80), (64, 88), (48, 96), (80, 96), (64, 108), (46, 66), (82, 66)]
    c.cuerpo(spline([(64, 36), (92, 44), (104, 70), (84, 106), (64, 116), (44, 106), (24, 70), (36, 44)]), hexa('c93a62'), sombra=0.2, luz=0.2, d=3.4)
    for (x, y) in pts:
        c.cuerpo_elip(x, y, 8.4, 8.4, col=hexa('e0587e'), sombra=0.2, luz=0.4, d=1.6)
    c.poly(estrella(64, 36, 22, 8, 6), VERDE)
    c.linea([(64, 34), (66, 16)], 3.4, VERDE3)


def uva(c):
    centros = [(44, 52), (64, 52), (84, 52), (54, 72), (74, 72), (44, 74), (84, 74), (64, 92), (54, 108), (74, 108), (64, 120)]
    c.linea([(64, 40), (70, 18)], 3.6, CAFE2)
    c.cuerpo(hoja(70, 22, 104, 12, 8, curva=-3), VERDE, sombra=0.2, luz=0.2)
    for (x, y) in centros[:7] + centros[7:9]:
        c.cuerpo_elip(x, y, 11.4, 11.4, col=hexa('8a4fc0'), sombra=0.22, luz=0.3, d=2)
    for (x, y) in ((64, 92), (54, 110), (74, 110)):
        c.cuerpo_elip(x, y, 11.4, 11.4, col=hexa('8a4fc0'), sombra=0.22, luz=0.3, d=2)
    c.brillo(40, 46, 2.4, 5, 30)
    c.brillo(60, 46, 2.4, 5, 30)


def vid(c):
    # racimo con hoja grande
    c.cuerpo(hoja(20, 60, 100, 18, 16, curva=-6), VERDE, sombra=0.2, luz=0.2)
    c.linea([(30, 56), (92, 24)], 1.6, VERDE3)
    for (x, y) in ((52, 74), (72, 74), (92, 74), (62, 94), (82, 94), (72, 112)):
        c.cuerpo_elip(x, y, 11, 11, col=hexa('6e8d3c') if (x + y) % 2 else hexa('86a948'), sombra=0.22, luz=0.3, d=2)


def olivo(c):
    c.linea(bezier((16, 108), (50, 84), (112, 30), 24), 3.4, CAFE)
    for (t, lado) in ((0.22, 1), (0.36, -1), (0.5, 1), (0.64, -1), (0.8, 1)):
        p = bezier((16, 108), (50, 84), (112, 30), 24)[int(t * 24)]
        c.cuerpo(hoja(p[0], p[1], p[0] + 12 * lado, p[1] - 24 * lado * -1 - 24, 5, curva=0), VERDE2, sombra=0.2, luz=0.2, d=1.4)
    for (x, y) in ((46, 84), (72, 70), (88, 52)):
        c.cuerpo_elip(x, y + 12, 9, 11, col=hexa('5f7a38'), sombra=0.25, luz=0.3, d=2)
        c.linea([(x, y + 3), (x + 1, y - 2)], 1.6, CAFE2)


def frutas(c):
    c.cuerpo(spline([(42, 56), (58, 50), (74, 62), (74, 84), (58, 104), (42, 98), (28, 84), (28, 62)]), ROJO, sombra=0.2, luz=0.3, d=3)
    c.cuerpo(spline([(78, 44), (94, 40), (108, 52), (106, 74), (92, 94), (78, 92), (66, 74), (66, 56)]), NARANJA, sombra=0.2, luz=0.3, d=3)
    c.cuerpo_elip(60, 96, 20, 20, col=hexa('8a4fc0'), sombra=0.22, luz=0.3, d=2.5)
    c.cuerpo(hoja(44, 52, 64, 38, 6, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.4)


def tomate(c):
    c.cuerpo(spline([(64, 40), (92, 36), (110, 60), (104, 90), (82, 108), (64, 108), (46, 108), (24, 90), (18, 60), (36, 36)]), hexa('e8473c'), sombra=0.2, luz=0.3, d=3.6)
    c.poly(estrella(64, 42, 30, 10, 6), VERDE)
    c.poly(estrella(64, 42, 18, 6, 6, ang=-60), VERDE2)
    c.linea([(64, 42), (66, 22)], 3.4, VERDE3)
    c.brillo(40, 66, 5, 10, 20)


def chile(c):
    c.cuerpo(spline([(22, 40), (50, 38), (80, 52), (100, 82), (108, 118), (90, 104), (64, 80), (36, 62)], cerrada=True), hexa('d8372f'), sombra=0.22, luz=0.3, d=3)
    c.cuerpo(spline([(14, 34), (24, 28), (40, 32), (44, 48), (28, 50), (16, 44)]), VERDE2, sombra=0.2, luz=0.2, d=1.6)
    c.linea([(18, 34), (8, 22)], 4, VERDE3)


def pepino(c):
    c.cuerpo(rot(spline([(14, 64), (30, 50), (64, 46), (98, 50), (114, 64), (98, 80), (64, 84), (30, 80)]), -28, 64, 64), hexa('4faa57'), sombra=0.22, luz=0.3, d=3)
    for (x, y) in ((44, 76), (60, 64), (76, 52), (90, 40), (54, 86), (70, 74), (86, 62)):
        c.punto(x, y, 1.8, hexa('93d98c'))


def lechuga(c):
    c.cuerpo_elip(64, 76, 42, 36, col=hexa('7fd16a'), sombra=0.2, luz=0.2, d=3)
    c.cuerpo(spline([(26, 70), (40, 48), (64, 40), (88, 48), (102, 70), (88, 94), (64, 100), (40, 94)]), hexa('a6e07e'), sombra=0.15, luz=0.2, d=2.5)
    c.cuerpo_elip(64, 70, 22, 22, col=hexa('d3f09a'), sombra=0.14, luz=0.2, d=2)
    for a in (-60, -20, 20, 60):
        c.linea([(64, 90), (64 + math.sin(math.radians(a)) * 28, 90 - math.cos(math.radians(a)) * 36)], 1.6, hexa('5fa94d'))


def col(c):
    c.cuerpo_elip(64, 72, 42, 40, col=hexa('5fb85e'), sombra=0.2, luz=0.2, d=3)
    for r, cc in ((34, hexa('7fd078')), (24, hexa('a2e08a')), (14, hexa('c8f0a2'))):
        c.elip(64, 72, r, r * 0.95, cc)
    for ang in (30, 90, 150, 210, 270, 330):
        a = math.radians(ang)
        c.linea([(64, 72), (64 + math.cos(a) * 40, 72 + math.sin(a) * 38)], 1.6, hexa('5fa94d'))


def cebolla(c):
    c.cuerpo(spline([(64, 26), (84, 40), (104, 70), (92, 100), (64, 112), (36, 100), (24, 70), (44, 40)]), hexa('d9a0e0'), sombra=0.22, luz=0.25, d=3.4)
    for a in (-30, 0, 30):
        c.linea(bezier((64, 100), (64 + a * 0.6, 70), (64 + a * 0.3, 34), 10), 1.4, hexa('b678c4'))
    c.linea([(64, 26), (60, 8)], 4, VERDE2)
    c.linea([(64, 112), (60, 120), (68, 122)], 1.6, hexa('c8b890'))


def hortalizas(c):
    # zanahoria + brócoli
    c.cuerpo(hoja(24, 28, 92, 106, 14, curva=0), hexa('f08a2a'), sombra=0.22, luz=0.3, d=3)
    c.linea([(40, 50), (50, 56)], 1.8, hexa('d9701c'))
    c.linea([(52, 70), (62, 76)], 1.8, hexa('d9701c'))
    c.linea([(66, 88), (74, 92)], 1.8, hexa('d9701c'))
    for (x, y, r) in ((22, 22, 9), (36, 14, 9), (14, 36, 8)):
        c.cuerpo(hoja(28, 32, x, y, 5, curva=2), VERDE, sombra=0.2, luz=0.2, d=1.4)
    c.linea([(94, 112), (96, 84)], 6, hexa('a6d86a'))
    for (x, y, r) in ((84, 70, 14), (106, 70, 14), (95, 58, 15)):
        c.cuerpo_elip(x, y, r, r, col=VERDE2, sombra=0.22, luz=0.25, d=2.4)


# ───────────── raíces y tubérculos ─────────────
def papa(c):
    c.cuerpo(spline([(34, 62), (52, 40), (84, 36), (104, 54), (98, 86), (74, 104), (44, 102), (26, 84)]), hexa('d6a860'), sombra=0.22, luz=0.25, d=3.6)
    for (x, y) in ((54, 62), (80, 56), (70, 82), (46, 82), (90, 76)):
        c.elip(x, y, 3.2, 2.0, hexa('9a7036'), 20)


def batata(c):
    c.cuerpo(spline([(14, 90), (36, 56), (74, 36), (112, 38), (104, 62), (74, 90), (40, 108), (20, 106)]), hexa('b4527a'), sombra=0.22, luz=0.25, d=3.4)
    c.linea([(30, 90), (60, 66)], 1.6, hexa('8a3a5c'))
    c.linea([(60, 78), (88, 54)], 1.6, hexa('8a3a5c'))


def name(c):
    c.cuerpo(spline([(16, 80), (30, 52), (62, 40), (98, 42), (112, 64), (96, 90), (60, 104), (28, 100)]), hexa('8a6038'), sombra=0.22, luz=0.2, d=3.4)
    for (x, y) in ((34, 80), (52, 62), (72, 56), (92, 60), (60, 86), (82, 80)):
        c.linea([(x, y), (x + 8, y + 2)], 1.8, hexa('5e3f22'))
    c.cuerpo_elip(104, 70, 5, 9, col=hexa('f3ead2'), sombra=0.1, luz=0, ang=20)


def yuca(c):
    c.cuerpo(spline([(14, 112), (30, 80), (60, 52), (100, 22), (112, 34), (96, 66), (66, 98), (30, 116)], por_tramo=10), hexa('a4733f'), sombra=0.22, luz=0.2, d=3.2)
    c.cuerpo_elip(104, 28, 8, 12, col=hexa('f8f0dc'), sombra=0.1, luz=0, ang=40)
    for (x, y) in ((40, 98), (62, 78), (84, 54)):
        c.linea([(x - 6, y + 8), (x + 6, y - 6)], 1.8, hexa('6e4527'))


def taro(c):
    c.cuerpo(hoja(64, 88, 14, 26, 20, curva=-4), VERDE, sombra=0.2, luz=0.2)
    c.cuerpo(hoja(64, 88, 112, 36, 20, curva=4), VERDE2, sombra=0.2, luz=0.2)
    c.linea([(64, 88), (24, 36)], 1.8, VERDE3)
    c.cuerpo(spline([(34, 96), (50, 80), (80, 78), (98, 94), (86, 114), (50, 116)]), hexa('8a6ab0'), sombra=0.22, luz=0.25, d=3)
    c.linea([(40, 98), (90, 98)], 1.6, hexa('644a88'))


def jengibre(c):
    c.cuerpo(spline([(20, 82), (30, 60), (50, 62), (60, 40), (80, 40), (84, 62), (102, 56), (110, 78), (92, 100), (60, 108), (30, 104)]), hexa('d9b674'), sombra=0.22, luz=0.25, d=3.4)
    for (x, y) in ((46, 88), (74, 86), (92, 76)):
        c.linea([(x - 8, y), (x + 8, y)], 1.8, hexa('a8864a'))
    c.cuerpo_elip(70, 36, 5, 8, col=hexa('f3ead2'), sombra=0, luz=0)


def remolacha(c):
    c.cuerpo(spline([(64, 44), (92, 52), (106, 82), (88, 108), (64, 118), (40, 108), (22, 82), (36, 52)]), hexa('a8274f'), sombra=0.22, luz=0.25, d=3.6)
    c.cuerpo(hoja(64, 48, 36, 12, 7, curva=3), VERDE2, sombra=0.2, luz=0.2, d=1.6)
    c.cuerpo(hoja(64, 48, 64, 6, 7), VERDE, sombra=0.2, luz=0.2, d=1.6)
    c.cuerpo(hoja(64, 48, 92, 12, 7, curva=-3), VERDE2, sombra=0.2, luz=0.2, d=1.6)
    c.linea([(64, 118), (62, 126)], 1.6, hexa('a8274f'))


def azucar(c):
    for (x, y, rot_) in ((38, 90, -4), (74, 94, 6), (56, 62, 2)):
        c.cuerpo(rot(mover([(0, 0), (34, 0), (34, 28), (0, 28)], x - 17, y - 14), rot_, x, y), hexa('f4f6ff'), sombra=0.2, luz=0, d=2.4, col_sombra=hexa('c3cbe0'))
    c.cuerpo(rot(mover([(0, 0), (34, 0), (34, 28), (0, 28)], 72, 38), 8, 89, 52), hexa('ffffff'), sombra=0.2, luz=0, d=2.4, col_sombra=hexa('c3cbe0'))
    c.punto(30, 54, 2, hexa('d8e0f4'))


def cana(c):
    for (x0, x1, col_) in ((38, 20, hexa('5aa84e')), (62, 56, hexa('6cc060')), (86, 100, hexa('5aa84e'))):
        t = bezier((x0, 122), (x0 + (x1 - x0) * 0.2, 80), (x1, 22), 20)
        c.linea(t, 11, col_)
        for k in (0.16, 0.34, 0.52, 0.70, 0.88):
            i = int(k * 20)
            x, y = t[i]
            c.linea([(x - 6, y), (x + 6, y)], 2.0, hexa('3c7a38'))
    c.cuerpo(hoja(62, 38, 108, 8, 7, curva=-5), VERDE, sombra=0.2, luz=0.2, d=1.6)
    c.cuerpo(hoja(62, 38, 16, 8, 7, curva=5), VERDE2, sombra=0.2, luz=0.2, d=1.6)


# ───────────── tropicales ─────────────
def banano(c):
    for k in range(5):
        a = -28 + k * 14
        base = rot([(64, 30)], 0)[0]
        t = bezier((52 + k * 6, 26), (24 + k * 12, 70), (34 + k * 12, 112), 18)
        c.linea(t, 13, hexa('f6d840') if k % 2 == 0 else hexa('f2c92c'))
        x, y = t[-1]
        c.punto(x, y, 4.6, CAFE2)
    c.cuerpo(hoja(66, 26, 78, 6, 6), CAFE, sombra=0.2, luz=0.1, d=1.6)
    c.cuerpo_elip(66, 26, 11, 7, col=hexa('86b84a'), sombra=0.2, luz=0.2, d=1.6)


def platano(c):
    for k in range(4):
        t = bezier((50 + k * 8, 26), (22 + k * 14, 70), (34 + k * 14, 110), 18)
        c.linea(t, 15, hexa('9ed05a') if k % 2 == 0 else hexa('7fbd4a'))
        x, y = t[-1]
        c.punto(x, y, 4.6, CAFE2)
    c.cuerpo_elip(64, 26, 13, 8, col=hexa('86b84a'), sombra=0.2, luz=0.2, d=1.6)


def coco(c):
    c.cuerpo_elip(64, 70, 42, 40, col=hexa('7a4a2a'), sombra=0.22, luz=0.25, d=3.6)
    c.cuerpo_elip(64, 64, 30, 28, col=hexa('f4efe0'), sombra=0.14, luz=0, d=2.4, ang=0)
    c.elip(64, 66, 20, 18, hexa('ffffff'))
    c.elip(54, 58, 6, 4, (220, 235, 255, 255), -20)
    c.punto(86, 30, 3, hexa('5a3418'))
    c.cuerpo(hoja(80, 26, 112, 8, 8, curva=-4), VERDE, sombra=0.2, luz=0.2, d=1.6)


def palma_aceite(c):
    c.linea([(64, 124), (64, 54)], 6, CAFE)
    for (ang, largo) in ((-72, 48), (-36, 52), (0, 44), (36, 52), (72, 48)):
        a = math.radians(ang - 90)
        c.cuerpo(hoja(64, 52, 64 + math.cos(a) * largo, 52 + math.sin(a) * largo * 0.9, 6, curva=-4 if ang < 0 else 4), VERDE if ang % 72 else VERDE2, sombra=0.2, luz=0.2, d=1.4)
    for (x, y) in ((50, 78), (66, 74), (80, 80), (58, 92), (74, 92), (66, 106)):
        c.cuerpo_elip(x, y, 8.4, 8.4, col=hexa('e8672a'), sombra=0.22, luz=0.3, d=1.6)
        c.punto(x + 2, y - 2, 2, hexa('f6a64a'))


def datil(c):
    c.linea([(60, 124), (62, 60)], 6, CAFE)
    for (ang, largo) in ((-78, 44), (-40, 50), (0, 42), (40, 50), (78, 44)):
        a = math.radians(ang - 90)
        c.cuerpo(hoja(62, 58, 62 + math.cos(a) * largo, 58 + math.sin(a) * largo * 0.9, 5, curva=-3 if ang < 0 else 3), VERDE2, sombra=0.2, luz=0.2, d=1.4)
    for (x, y) in ((50, 74), (66, 72), (80, 78), (56, 90), (72, 90), (64, 104), (86, 94), (44, 94)):
        c.cuerpo_elip(x, y, 6.2, 9.0, col=hexa('9a5a2a'), sombra=0.22, luz=0.3, d=1.6, ang=10)


def cafe(c):
    c.linea(bezier((18, 112), (50, 70), (106, 40), 22), 3.4, CAFE2)
    c.cuerpo(hoja(40, 90, 62, 52, 9, curva=-4), VERDE2, sombra=0.2, luz=0.2, d=1.8)
    c.cuerpo(hoja(70, 70, 100, 28, 9, curva=-4), VERDE, sombra=0.2, luz=0.2, d=1.8)
    c.cuerpo_elip(46, 108, 15, 12, col=hexa('b8322f'), sombra=0.22, luz=0.3, d=2, ang=-30)
    c.cuerpo_elip(84, 92, 15, 12, col=hexa('d03f38'), sombra=0.22, luz=0.3, d=2, ang=-30)
    c.cuerpo_elip(72, 112, 16, 12, col=hexa('8a4a2a'), sombra=0.22, luz=0.2, d=1.6, ang=20)
    c.linea(bezier((60, 112), (72, 106), (84, 112), 8), 2.0, hexa('4a2a14'))


def te(c):
    c.cuerpo(hoja(24, 110, 62, 20, 20, curva=-6), VERDE, sombra=0.2, luz=0.2)
    c.linea([(28, 104), (60, 26)], 1.8, VERDE3)
    c.cuerpo(hoja(66, 110, 104, 40, 17, curva=5), VERDE2, sombra=0.2, luz=0.2)
    c.linea([(70, 104), (100, 46)], 1.6, VERDE3)
    c.punto(52, 118, 2.4, hexa('e8e0c0'))


def cacao(c):
    c.cuerpo(rot(spline([(14, 64), (30, 40), (64, 32), (98, 40), (114, 64), (98, 88), (64, 96), (30, 88)]), -28, 64, 64), hexa('d9702a'), sombra=0.22, luz=0.25, d=3.2)
    for k in range(4):
        t = bezier((32 + k * 4, 92 - k * 6), (50 + k * 4, 72 - k * 6), (74 + k * 8, 46 - k * 3), 12)
        c.linea(t, 1.8, hexa('a8501a'))
    c.linea([(104, 28), (112, 16)], 3.4, CAFE2)


def tabaco(c):
    c.cuerpo(hoja(26, 116, 100, 12, 24, curva=-8), hexa('a0b84a'), sombra=0.2, luz=0.2)
    c.linea(bezier((26, 116), (60, 64), (100, 12), 14), 2.0, hexa('6a8a30'))
    for k in range(5):
        t = bezier((26, 116), (60, 64), (100, 12), 14)[k * 2 + 2]
        c.linea([t, (t[0] + 22, t[1] + 4)], 1.4, hexa('6a8a30'))
        c.linea([t, (t[0] - 6, t[1] - 22)], 1.4, hexa('6a8a30'))


def vainilla(c):
    for (x0, x1) in ((30, 60), (54, 84), (78, 104)):
        c.linea(bezier((x0, 112), (x0 + 10, 70), (x1, 22), 16), 5, hexa('4a3220'))
    c.cuerpo_elip(78, 100, 15, 7, col=hexa('f8f0dc'), sombra=0.1, luz=0, ang=-30)
    c.poly(estrella(78, 100, 15, 7, 5), hexa('f8f0dc'))
    c.punto(78, 100, 3.6, ORO)


def cardamomo(c):
    for (x, y, a) in ((36, 70, -20), (64, 56, 10), (88, 80, 30), (54, 100, 60)):
        c.cuerpo(rot(spline([(x - 22, y), (x - 8, y - 12), (x + 8, y - 12), (x + 22, y), (x + 8, y + 12), (x - 8, y + 12)]), a, x, y), hexa('8ec45a'), sombra=0.22, luz=0.3, d=2.4)
        c.linea(rot([(x - 18, y), (x + 18, y)], a, x, y), 1.4, hexa('5a8a34'))


def algodon(c):
    c.linea([(64, 124), (64, 74)], 4.4, CAFE2)
    for a in (-60, 0, 60):
        ang = math.radians(a - 90)
        c.cuerpo(hoja(64, 76, 64 + math.cos(ang) * 40, 76 + math.sin(ang) * 40, 8, curva=0), hexa('3a2a1c'), sombra=0.1, luz=0)
    for (x, y, r) in ((46, 56, 16), (82, 56, 16), (64, 40, 17), (54, 72, 15), (76, 72, 15), (64, 58, 16)):
        c.cuerpo_elip(x, y, r, r, col=hexa('fbfcff'), sombra=0.18, luz=0, d=2.4, col_sombra=hexa('c9d2e8'))
    c.cuerpo(hoja(64, 120, 92, 94, 6, curva=-3), VERDE, sombra=0.2, luz=0.2, d=1.4)


def yute(c):
    for k in range(7):
        dx = (k - 3) * 10
        c.linea(bezier((64 + dx * 0.4, 14), (64 + dx * 1.3, 64), (64 + dx * 0.4, 114), 14), 6.4, hexa('d8b66a') if k % 2 else hexa('c9a35a'))
    c.rect(36, 54, 92, 70, hexa('8a6038'), r=4)
    c.rect(36, 54, 92, 60, hexa('a87a48'), r=3)


def henequen(c):
    c.cuerpo(hoja(64, 118, 10, 56, 11, curva=-6), hexa('6aa88a'), sombra=0.2, luz=0.2)
    c.cuerpo(hoja(64, 118, 118, 56, 11, curva=6), hexa('6aa88a'), sombra=0.2, luz=0.2)
    c.cuerpo(hoja(64, 118, 38, 18, 11, curva=-3), hexa('4f9474'), sombra=0.2, luz=0.2)
    c.cuerpo(hoja(64, 118, 90, 18, 11, curva=3), hexa('4f9474'), sombra=0.2, luz=0.2)
    c.cuerpo(hoja(64, 118, 64, 8, 11), hexa('78b898'), sombra=0.2, luz=0.2)


def agave(c):
    for (x, y, col_) in ((14, 54, hexa('4f8fa8')), (114, 54, hexa('4f8fa8')), (30, 28, hexa('5aa0b8')), (98, 28, hexa('5aa0b8')), (64, 10, hexa('68b0c4'))):
        c.cuerpo(hoja(64, 116, x, y, 9, curva=(-4 if x < 64 else 4) if x != 64 else 0), col_, sombra=0.2, luz=0.2)
    c.cuerpo_elip(64, 108, 22, 10, col=hexa('7ac0d2'), sombra=0.2, luz=0.2, d=2)


def caucho(c):
    c.cuerpo(spline([(54, 124), (52, 70), (58, 40), (70, 40), (76, 70), (74, 124)]), hexa('8a6038'), sombra=0.22, luz=0.2, d=2.8)
    c.cuerpo_elip(64, 30, 30, 24, col=VERDE, sombra=0.2, luz=0.2, d=2.6)
    c.cuerpo_elip(40, 40, 18, 15, col=VERDE2, sombra=0.2, luz=0.2, d=2)
    c.cuerpo_elip(90, 40, 18, 15, col=VERDE2, sombra=0.2, luz=0.2, d=2)
    c.cuerpo(gota(94, 96, 7, 14), hexa('f6f0e0'), sombra=0.15, luz=0, d=1.4)
    c.rect(82, 74, 98, 82, hexa('4a4a58'), r=2)
    c.linea([(76, 66), (86, 76)], 2.6, hexa('4a4a58'))
    c.cuerpo(gota(88, 106, 4.4, 9), hexa('fbf6ea'), sombra=0, luz=0)


def goma_arabiga(c):
    c.linea(bezier((12, 100), (50, 60), (112, 46), 20), 4.6, CAFE)
    for (x, y, r) in ((36, 82, 11), (62, 66, 13), (90, 54, 11)):
        c.cuerpo_elip(x, y + r, r, r * 1.2, col=hexa('e8a838'), sombra=0.22, luz=0.35, d=2.2)
    c.brillo(34, 90, 2.4, 5, 20)
    c.brillo(60, 76, 2.8, 6, 20)


def flores(c):
    for (x, y, col_) in ((34, 46, ROSA), (64, 34, hexa('f08a5a')), (94, 46, hexa('b87ae0'))):
        c.linea(bezier((64, 124), (64, 90), (x, y + 8), 14), 3.2, VERDE2)
        for i in range(6):
            a = math.radians(i * 60)
            c.cuerpo_elip(x + math.cos(a) * 11, y + math.sin(a) * 11, 8, 8, col=col_, sombra=0.2, luz=0.3, d=1.6)
        c.cuerpo_elip(x, y, 6, 6, col=ORO, sombra=0.2, luz=0.3, d=1.4)
    c.cuerpo(hoja(64, 118, 36, 92, 6, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.4)
    c.cuerpo(hoja(64, 118, 92, 92, 6, curva=2), VERDE, sombra=0.2, luz=0.2, d=1.4)


def viveros(c):
    c.cuerpo(spline([(36, 84), (92, 84), (86, 120), (42, 120)], por_tramo=4, cerrada=True), hexa('c4663a'), sombra=0.22, luz=0.25, d=2.6)
    c.rect(32, 78, 96, 90, hexa('d9784a'), r=3)
    c.linea([(64, 80), (64, 44)], 3.4, VERDE3)
    c.cuerpo(hoja(64, 56, 36, 28, 8, curva=4), VERDE, sombra=0.2, luz=0.2, d=1.8)
    c.cuerpo(hoja(64, 50, 94, 20, 8, curva=-4), VERDE, sombra=0.2, luz=0.2, d=1.8)
    c.cuerpo(hoja(64, 44, 66, 12, 6), LIMA, sombra=0.2, luz=0.2, d=1.4)


def heno(c):
    c.cuerpo(spline([(14, 52), (110, 52), (114, 108), (10, 108)], por_tramo=4, cerrada=True), hexa('e8c45a'), sombra=0.22, luz=0.25, d=3)
    for y in (66, 82, 98):
        c.linea([(14, y), (112, y)], 1.8, hexa('b8923a'))
    for x in (44, 84):
        c.rect(x - 2, 50, x + 2, 110, hexa('8a6038'))
    for (x, y, a) in ((22, 44, -40), (40, 46, -20), (60, 42, 10), (86, 44, 24), (104, 46, 40)):
        c.linea([(x, 54), (x + math.sin(math.radians(a)) * 14, 54 - 14)], 1.6, hexa('d9ad45'))


def forraje(c):
    for (x, ang, col_) in ((64, 0, VERDE), (44, -22, VERDE2), (84, 22, VERDE2), (26, -40, VERDE), (102, 40, VERDE), (54, -10, LIMA), (74, 10, LIMA)):
        a = math.radians(ang - 90)
        c.cuerpo(hoja(x, 118, x + math.cos(a) * 14 + (x - 64) * 0.2, 118 + math.sin(a) * 100, 6, curva=0), col_, sombra=0.2, luz=0.2, d=1.4)
    c.rect(40, 96, 88, 110, hexa('8a6038'), r=4)


def alfalfa(c):
    c.linea([(64, 124), (64, 46)], 3.4, VERDE2)
    for (y, lado) in ((100, -1), (84, 1), (68, -1)):
        for dx, dy in ((0, 0), (-8, -6), (8, -6)):
            c.cuerpo_elip(64 + lado * 14 + dx, y + dy, 8, 6, col=VERDE, sombra=0.2, luz=0.2, d=1.4)
        c.linea([(64, y + 6), (64 + lado * 14, y)], 1.6, VERDE2)
    for (x, y) in ((64, 34), (56, 40), (72, 40), (64, 46), (58, 26), (70, 26)):
        c.cuerpo_elip(x, y, 6.6, 6.6, col=hexa('a070d8'), sombra=0.2, luz=0.3, d=1.2)


def arce(c):
    pts = [(64, 14), (72, 36), (96, 28), (88, 52), (116, 54), (96, 74), (108, 92), (82, 90), (76, 96), (64, 124), (52, 96), (46, 90), (20, 92), (32, 74), (12, 54), (40, 52), (32, 28), (56, 36)]
    c.cuerpo(pts, hexa('d9582a'), sombra=0.22, luz=0.25, d=2.6)
    c.linea([(64, 124), (64, 40)], 2.0, hexa('a8381a'))
    for a in (-1, 1):
        c.linea([(64, 90), (64 + a * 28, 62)], 1.6, hexa('a8381a'))
        c.linea([(64, 70), (64 + a * 16, 40)], 1.6, hexa('a8381a'))


def hongos(c):
    c.cuerpo(spline([(14, 74), (22, 40), (64, 20), (106, 40), (114, 74)]), hexa('d9503a'), sombra=0.22, luz=0.25, d=3)
    c.cuerpo(spline([(14, 74), (114, 74), (110, 82), (64, 86), (18, 82)]), hexa('f2e6c8'), sombra=0.2, luz=0, d=1.6)
    c.cuerpo(spline([(48, 82), (80, 82), (84, 118), (44, 118)], por_tramo=6, cerrada=True), hexa('f4ecd8'), sombra=0.22, luz=0.1, d=2.4)
    for (x, y, r) in ((44, 52, 7), (70, 38, 6), (84, 60, 8), (60, 66, 5)):
        c.punto(x, y, r, hexa('fbf6e8'))


# ───────────── leguminosas, semillas y frutos secos ─────────────
def soya(c):
    c.cuerpo(rot(spline([(18, 64), (36, 52), (92, 52), (110, 64), (92, 78), (36, 78)]), -30, 64, 64), hexa('b8c45a'), sombra=0.22, luz=0.3, d=3)
    for (x, y) in ((42, 82), (62, 62), (84, 42)):
        c.cuerpo_elip(x, y, 11, 11, col=hexa('e8dca0'), sombra=0.2, luz=0.3, d=1.8)
    c.linea([(100, 34), (112, 22)], 3.4, VERDE3)


def frijol(c):
    for (x, y, a) in ((38, 54, -20), (84, 52, 20), (58, 88, 70), (96, 92, -50), (30, 94, 40)):
        c.cuerpo(rot(spline([(x - 18, y), (x - 10, y - 11), (x + 10, y - 11), (x + 18, y), (x + 10, y + 11), (x - 10, y + 11)]), a, x, y), hexa('a8322f'), sombra=0.22, luz=0.3, d=2.2)
        c.elip(x + math.cos(math.radians(a)) * 2, y + math.sin(math.radians(a)) * 2 - 1, 5, 2.4, hexa('e0a8a0'), a)


def lentejas(c):
    for i in range(34):
        a = i * 2.399
        r = math.sqrt(i / 34.0) * 44
        x, y = 64 + math.cos(a) * r, 72 + math.sin(a) * r * 0.7
        c.cuerpo_elip(x, y, 11, 8, col=hexa('d9873a') if i % 2 else hexa('c46e2a'), sombra=0.2, luz=0.3, d=1.4, ang=i * 40)


def mani(c):
    m = c.cuerpo(rot(spline([(14, 64), (24, 46), (46, 46), (58, 56), (70, 56), (82, 46), (104, 46), (114, 64), (104, 82), (82, 82), (70, 72), (58, 72), (46, 82), (24, 82)]), -28, 64, 64), hexa('dcb878'), sombra=0.22, luz=0.25, d=3)
    def red(t):
        for k in range(-6, 8):
            t.linea([(10 + k * 12, 20), (30 + k * 12, 110)], 1.6, hexa('b88e4a'))
            t.linea([(30 + k * 12, 20), (10 + k * 12, 110)], 1.6, hexa('b88e4a'))
    c.recortada(m, red)


def sesamo(c):
    for i in range(30):
        a = i * 2.399
        r = math.sqrt(i / 30.0) * 42
        x, y = 64 + math.cos(a) * r, 74 + math.sin(a) * r * 0.7
        c.cuerpo_elip(x, y, 5, 3, col=hexa('f2e4c0'), sombra=0.14, luz=0, d=1, ang=i * 50, col_sombra=hexa('d9c898'))


def girasol(c):
    c.linea([(64, 124), (64, 76)], 5, VERDE2)
    c.cuerpo(hoja(64, 110, 98, 92, 8, curva=-4), VERDE, sombra=0.2, luz=0.2, d=1.6)
    for i in range(14):
        a = math.radians(i * 360 / 14)
        c.cuerpo(hoja(64 + math.cos(a) * 14, 48 + math.sin(a) * 14, 64 + math.cos(a) * 42, 48 + math.sin(a) * 42, 6.4), ORO, sombra=0.2, luz=0.2, d=1.6)
    c.cuerpo_elip(64, 48, 20, 20, col=hexa('6e4527'), sombra=0.22, luz=0.2, d=2)
    for i in range(14):
        a = i * 2.399
        r = math.sqrt(i / 14.0) * 15
        c.punto(64 + math.cos(a) * r, 48 + math.sin(a) * r, 1.6, hexa('9a6a43'))


def colza(c):
    c.linea([(64, 124), (64, 52)], 3.4, VERDE2)
    for (x, y) in ((64, 40), (44, 52), (84, 52), (54, 30), (74, 30), (34, 72), (94, 72), (50, 70), (78, 70)):
        c.linea([(64, 90), (x, y + 8)], 1.4, VERDE2)
        for i in range(4):
            a = math.radians(i * 90 + 45)
            c.cuerpo_elip(x + math.cos(a) * 5, y + math.sin(a) * 5, 4.4, 4.4, col=hexa('f6dc3a'), sombra=0.14, luz=0.3, d=1)
        c.punto(x, y, 2.2, hexa('d99a1f'))


def nuez(c):
    c.cuerpo_elip(64, 70, 38, 36, col=hexa('c49a62'), sombra=0.22, luz=0.25, d=3.6)
    c.linea(bezier((64, 34), (56, 70), (64, 106), 14), 2.2, hexa('8a6038'))
    for (x, y, a) in ((44, 56, 20), (84, 56, -20), (42, 84, -20), (86, 84, 20)):
        c.linea(rot([(x - 8, y), (x + 8, y)], a, x, y), 1.8, hexa('a87e48'))


def avellana(c):
    c.cuerpo(spline([(64, 28), (90, 44), (98, 76), (84, 106), (64, 112), (44, 106), (30, 76), (38, 44)]), hexa('c68a4a'), sombra=0.22, luz=0.25, d=3.4)
    c.cuerpo(spline([(36, 38), (92, 38), (86, 56), (64, 62), (42, 56)]), hexa('8a5a2a'), sombra=0.2, luz=0.1, d=2)
    c.cuerpo(hoja(78, 38, 108, 16, 7, curva=-3), VERDE, sombra=0.2, luz=0.2, d=1.6)


def almendra(c):
    c.cuerpo(spline([(64, 16), (88, 44), (96, 78), (64, 114), (32, 78), (40, 44)]), hexa('c99458'), sombra=0.22, luz=0.25, d=3.4)
    c.linea(bezier((64, 24), (58, 60), (64, 100), 12), 2.0, hexa('8a5e2e'))
    c.brillo(48, 54, 3, 10, 14)


def pistacho(c):
    c.cuerpo(spline([(64, 18), (92, 44), (94, 80), (64, 110), (34, 80), (36, 44)]), hexa('e8dcb0'), sombra=0.22, luz=0.2, d=3)
    c.cuerpo(spline([(64, 44), (80, 56), (80, 78), (64, 96), (48, 78), (48, 56)]), hexa('8ec45a'), sombra=0.22, luz=0.3, d=2.4)
    c.linea([(64, 18), (64, 44)], 2.0, hexa('b8aa7a'))


def anacardo(c):
    c.cuerpo(spline([(50, 20), (84, 24), (106, 54), (96, 94), (66, 110), (34, 98), (46, 70), (70, 58), (62, 38)]), hexa('e8d4a0'), sombra=0.22, luz=0.2, d=3.2)
    c.cuerpo_elip(86, 28, 18, 16, col=hexa('e04a3a'), sombra=0.2, luz=0.3, d=2.2)


def nuez_pecana(c):
    c.cuerpo(spline([(64, 16), (88, 36), (94, 76), (80, 108), (64, 114), (48, 108), (34, 76), (40, 36)]), hexa('8a5a34'), sombra=0.22, luz=0.25, d=3.4)
    for x in (52, 64, 76):
        c.linea(bezier((x, 24), (x + (x - 64) * 0.4, 66), (x, 106), 12), 1.8, hexa('5e3a1c'))


def frutos_secos(c):
    nuez(c)
    # sustituir por montón: se redibuja más pequeño
    c.im.paste((0, 0, 0, 0), (0, 0, c.t, c.t))
    c.cuerpo_elip(46, 82, 24, 22, col=hexa('c49a62'), sombra=0.22, luz=0.25, d=3)
    c.cuerpo(spline([(78, 48), (96, 62), (100, 88), (80, 108), (64, 94), (64, 64)]), hexa('c99458'), sombra=0.22, luz=0.25, d=3)
    c.cuerpo_elip(72, 96, 18, 15, col=hexa('8a5a34'), sombra=0.22, luz=0.25, d=2.4)
    c.linea([(40, 66), (46, 98)], 1.6, hexa('8a6038'))


def kiwi(c):
    c.cuerpo_elip(64, 70, 42, 40, col=hexa('8a6038'), sombra=0.2, luz=0.2, d=3)
    c.elip(64, 70, 36, 34, hexa('8ed05a'))
    c.elip(64, 70, 12, 10, hexa('e8f0c0'))
    for i in range(18):
        a = math.radians(i * 20)
        c.elip(64 + math.cos(a) * 18, 70 + math.sin(a) * 17, 1.6, 2.8, hexa('2a2a2a'), math.degrees(a) + 90)
    for i in range(12):
        a = math.radians(i * 30 + 10)
        c.linea([(64 + math.cos(a) * 12, 70 + math.sin(a) * 11), (64 + math.cos(a) * 32, 70 + math.sin(a) * 30)], 1.2, hexa('a6e07a'))


def mango(c):
    c.cuerpo(rot(spline([(16, 70), (36, 38), (78, 28), (108, 52), (100, 92), (62, 108), (28, 96)]), -20, 62, 68), hexa('f0a034'), sombra=0.2, luz=0.3, d=3.6)
    c.elip(78, 54, 22, 24, (232, 80, 60, 150), -20)
    c.cuerpo(hoja(40, 40, 64, 24, 6, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.6)


def aguacate(c):
    c.cuerpo(spline([(64, 12), (84, 32), (96, 60), (104, 90), (84, 114), (64, 116), (44, 114), (24, 90), (32, 60), (44, 32)]), hexa('2f6a3a'), sombra=0.2, luz=0.2, d=3)
    c.cuerpo(spline([(64, 22), (80, 40), (90, 62), (96, 88), (80, 108), (64, 110), (48, 108), (32, 88), (38, 62), (48, 40)]), hexa('c8e07a'), sombra=0.12, luz=0, d=2)
    c.cuerpo_elip(64, 86, 17, 18, col=hexa('8a5a34'), sombra=0.22, luz=0.3, d=2.4)


def pina(c):
    c.cuerpo(hoja(64, 52, 26, 8, 8, curva=3), VERDE2, sombra=0.2, luz=0.2, d=1.4)
    c.cuerpo(hoja(64, 52, 102, 8, 8, curva=-3), VERDE2, sombra=0.2, luz=0.2, d=1.4)
    c.cuerpo(hoja(64, 52, 46, 2, 7, curva=2), VERDE, sombra=0.2, luz=0.2, d=1.4)
    c.cuerpo(hoja(64, 52, 82, 2, 7, curva=-2), VERDE, sombra=0.2, luz=0.2, d=1.4)
    c.cuerpo(hoja(64, 52, 64, -2, 8), VERDE3, sombra=0.2, luz=0.2, d=1.4)
    m = c.cuerpo_elip(64, 86, 30, 36, col=hexa('f0b43a'), sombra=0.22, luz=0.25, d=3.4)
    def rejilla(t):
        for k in range(-5, 6):
            t.linea([(64 + k * 11 - 40, 40), (64 + k * 11 + 40, 130)], 1.6, hexa('d98a22'))
            t.linea([(64 + k * 11 + 40, 40), (64 + k * 11 - 40, 130)], 1.6, hexa('d98a22'))
    c.recortada(m, rejilla)


def leche(c):
    c.cuerpo(spline([(38, 46), (90, 46), (96, 118), (32, 118)], por_tramo=4, cerrada=True), hexa('f4f6ff'), sombra=0.2, luz=0, d=3, col_sombra=hexa('c3cbe0'))
    c.cuerpo(spline([(42, 46), (86, 46), (80, 24), (48, 24)], por_tramo=4, cerrada=True), hexa('d8e4ff'), sombra=0.2, luz=0, d=2, col_sombra=hexa('a8b8e0'))
    c.rect(48, 14, 80, 26, hexa('e04a4a'), r=3)
    c.rect(38, 66, 90, 96, hexa('7aa8f0'), r=2)
    c.cuerpo(gota(64, 88, 7, 12), hexa('f4f6ff'), sombra=0, luz=0)


ICONOS = {
    'trigo': trigo, 'cebada': cebada, 'centeno': centeno, 'avena': avena, 'mijo': mijo, 'sorgo': sorgo, 'arroz': arroz, 'quinua': quinua, 'teff': teff,
    'maiz': maiz, 'maiz_forraje': maiz_forraje,
    'manzana': manzana, 'pera': pera, 'naranja': naranja, 'limon': limon, 'citricos': citricos, 'melocoton': melocoton, 'cereza': cereza, 'arandano': arandano,
    'fresa': fresa, 'frambuesa': frambuesa, 'uva': uva, 'vid': vid, 'olivo': olivo, 'frutas': frutas, 'tomate': tomate, 'chile': chile, 'pepino': pepino,
    'lechuga': lechuga, 'col': col, 'cebolla': cebolla, 'hortalizas': hortalizas,
    'papa': papa, 'batata': batata, 'name': name, 'yuca': yuca, 'taro': taro, 'jengibre': jengibre, 'remolacha': remolacha, 'azucar': azucar, 'cana': cana,
    'banano': banano, 'platano': platano, 'coco': coco, 'palma_aceite': palma_aceite, 'datil': datil, 'cafe': cafe, 'te': te, 'cacao': cacao, 'tabaco': tabaco,
    'vainilla': vainilla, 'cardamomo': cardamomo, 'algodon': algodon, 'yute': yute, 'henequen': henequen, 'agave': agave, 'caucho': caucho,
    'goma_arabiga': goma_arabiga, 'flores': flores, 'viveros': viveros, 'heno': heno, 'forraje': forraje, 'alfalfa': alfalfa, 'arce': arce, 'hongos': hongos,
    'soya': soya, 'frijol': frijol, 'lentejas': lentejas, 'mani': mani, 'sesamo': sesamo, 'girasol': girasol, 'colza': colza,
    'nuez': nuez, 'avellana': avellana, 'almendra': almendra, 'pistacho': pistacho, 'anacardo': anacardo, 'nuez_pecana': nuez_pecana, 'frutos_secos': frutos_secos,
    'kiwi': kiwi, 'mango': mango, 'aguacate': aguacate, 'pina': pina, 'leche': leche,
}
