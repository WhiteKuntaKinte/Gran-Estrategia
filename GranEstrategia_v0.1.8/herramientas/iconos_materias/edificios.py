"""Iconos de los 109 edificios del juego (0.1.8.41), uno por `slug` de datos/edificios.json -> iconos/edificios/<slug>.png (128 px).
Se dibujan con las mismas piezas (muros, torres, techos, arcos, columnas...) para que todo el catálogo tenga un aire común. Los que comparten
forma (los castillos, los puentes, las academias) cambian de color, de detalle o de tamaño. Sin imágenes de terceros."""
import math

from PIL import Image, ImageChops, ImageDraw

from lienzo import *

PIEDRA_C = hexa('c9c3b6')
PIEDRA = hexa('a9a396')
PIEDRA_O = hexa('807a6e')
LADRILLO = hexa('c8694a')
LADRILLO_O = hexa('9a4a33')
MADERA = hexa('b07a40')
MADERA_O = hexa('7d5128')
PAJA = hexa('d9b45a')
TEJA = hexa('c9503f')
TEJA_O = hexa('962f27')
CESPED = hexa('6dbf62')
CESPED_O = hexa('3f8f46')
TIERRA_C = hexa('c7a06a')
TIERRA_O = hexa('8b6a42')
AGUA = hexa('58a8e6')
AGUA_C = hexa('9fd4f6')
ACERO = hexa('9aa6ba')
ACERO_O = hexa('66728a')
HORMIGON = hexa('b3b8bf')
HORMIGON_O = hexa('858b94')
CIELO = hexa('8ec9f0')
AMARILLO_V = hexa('ffe28a')
LLAMA_V = hexa('ffc83d')
OSCURO_V = hexa('3d3a46')


# ───────────── piezas ─────────────
def suelo(c, y=110, col=CESPED, x0=4, x1=124, grosor=10):
    c.cuerpo([(x0, y), (x1, y), (x1, y + grosor), (x0, y + grosor)], col, sombra=0.2, luz=0.2, d=2.4)


def cuadro(c, x0, y0, x1, y1, col, **kw):
    kw.setdefault('sombra', 0.2)
    kw.setdefault('luz', 0.22)
    kw.setdefault('d', 2.6)
    return c.cuerpo([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, **kw)


def almenas(c, x0, x1, y, col, n=None, alto=7.0):
    """Dientes de muralla sobre el borde superior `y` (el muro empieza en y)."""
    ancho = x1 - x0
    n = n or max(2, int(round(ancho / 12.0)))
    paso = ancho / (2 * n - 1)
    for i in range(n):
        xa = x0 + i * 2 * paso
        cuadro(c, xa, y - alto, xa + paso, y + 1, col, sombra=0.18, luz=0.2, d=1.8)


def muro(c, x0, x1, y0, y1, col=PIEDRA, n=None, ladrillos=True):
    cuadro(c, x0, y0, x1, y1, col)
    almenas(c, x0, x1, y0, col, n)
    if ladrillos:
        yy = y0 + 9
        k = 0
        while yy < y1 - 2:
            c.linea([(x0 + 2, yy), (x1 - 2, yy)], 1.1, oscuro(col, 0.22))
            xx = x0 + 6 + (k % 2) * 6
            while xx < x1 - 2:
                c.linea([(xx, yy), (xx, min(yy + 9, y1 - 1))], 1.1, oscuro(col, 0.22))
                xx += 12
            yy += 9
            k += 1


def torre(c, cx, y1, ancho, alto, col=PIEDRA, techo=None, n=2, ladrillos=False):
    x0, x1 = cx - ancho / 2, cx + ancho / 2
    y0 = y1 - alto
    cuadro(c, x0, y0, x1, y1, col)
    if techo is None:
        almenas(c, x0 - 1.5, x1 + 1.5, y0, col, n, alto=6.5)
    else:
        c.cuerpo([(x0 - 3, y0 + 1), (cx, y0 - ancho * 0.95), (x1 + 3, y0 + 1)], techo, sombra=0.22, luz=0.22, d=2.4)
    if ladrillos:
        for yy in range(int(y0 + 9), int(y1 - 3), 9):
            c.linea([(x0 + 2, yy), (x1 - 2, yy)], 1.0, oscuro(col, 0.2))
    return (x0, y0, x1, y1)


def aspillera(c, x, y, h=10, w=3.0, col=OSCURO_V):
    c.rect(x - w / 2, y, x + w / 2, y + h, col, r=1)


def ventana(c, x, y, w=8, h=10, col=AMARILLO_V):
    c.rect(x, y, x + w, y + h, col, r=1.2)


def puerta(c, cx, y1, w=14, h=20, col=MADERA_O, arco=True):
    if arco:
        pts = [(cx - w / 2, y1)] + [(cx - w / 2 * math.cos(math.radians(a)), y1 - h + w / 2 - w / 2 * math.sin(math.radians(a))) for a in range(0, 181, 15)] + [(cx + w / 2, y1)]
        c.poly(pts, col)
    else:
        c.rect(cx - w / 2, y1 - h, cx + w / 2, y1, col, r=1.5)


def techo(c, x0, x1, y_base, y_pico, col=TEJA, alero=4.0):
    cx = (x0 + x1) / 2
    c.cuerpo([(x0 - alero, y_base), (cx, y_pico), (x1 + alero, y_base)], col, sombra=0.24, luz=0.24, d=2.6)


def casa(c, x0, x1, y1, alto, col=hexa('e9dcc0'), col_techo=TEJA, pico=14, puerta_=True):
    y0 = y1 - alto
    cuadro(c, x0, y0, x1, y1, col)
    techo(c, x0, x1, y0 + 1, y0 - pico, col_techo)
    if puerta_:
        c.rect((x0 + x1) / 2 - 3.5, y1 - 13, (x0 + x1) / 2 + 3.5, y1, MADERA_O, r=1)
    if x1 - x0 > 26:
        ventana(c, x0 + 5, y0 + 8, 6, 7)
        ventana(c, x1 - 11, y0 + 8, 6, 7)


def arbol(c, x, y1, r=11, col=CESPED_O):
    cuadro(c, x - 2, y1 - r * 0.9, x + 2, y1, MADERA, sombra=0.2, luz=0.0, d=1.4)
    c.cuerpo_elip(x, y1 - r * 1.5, r, r * 0.95, col=col, sombra=0.25, luz=0.3, d=2.2)


def columna(c, x, y0, y1, w=9, col=hexa('f1ede2')):
    cuadro(c, x, y0, x + w, y1, col, sombra=0.2, luz=0.0, d=2.0)
    c.rect(x - 1.5, y0 - 3, x + w + 1.5, y0 + 2, hexa('ddd6c4'), r=1)
    c.rect(x - 1.5, y1 - 2, x + w + 1.5, y1 + 2, hexa('ddd6c4'), r=1)


def humo(c, x, y, n=3):
    for k in range(n):
        c.cuerpo_elip(x + k * 3.5, y - k * 8, 4.5 + k * 1.4, col=hexa('d5d8e2'), sombra=0.15, luz=0.3, d=1.4)


def olas(c, y, x0=4, x1=124, col=AGUA, n=7):
    paso = (x1 - x0) / n
    for i in range(n):
        xa = x0 + i * paso
        c.linea(spline([(xa, y), (xa + paso * 0.25, y - 4), (xa + paso * 0.5, y), (xa + paso * 0.75, y + 4), (xa + paso, y)], cerrada=False), 3.2, col)


def bandera_asta(c, x, y, alto=22, col=ROJO, ancho=16):
    c.linea([(x, y), (x, y - alto)], 2.4, GRIS2)
    c.cuerpo([(x + 1, y - alto), (x + 1 + ancho, y - alto + 4), (x + 1, y - alto + 9)], col, sombra=0.2, luz=0.2, d=1.4)


# ───────────── vivienda y ciudad ─────────────
def cabana_madera(c):
    suelo(c)
    cuadro(c, 22, 60, 106, 110, MADERA)
    for k in range(5):
        y = 60 + k * 10
        c.linea([(22, y), (106, y)], 1.6, MADERA_O)
        c.punto(22, y + 5, 4.2, MADERA_O)
        c.punto(106, y + 5, 4.2, MADERA_O)
    techo(c, 22, 106, 61, 22, hexa('9c5a34'), alero=8)
    c.rect(54, 80, 76, 110, hexa('5a3a22'), r=2)
    c.rect(82, 70, 96, 82, AMARILLO_V, r=1)
    cuadro(c, 88, 18, 98, 40, PIEDRA)
    humo(c, 93, 14, 2)


def campamento_estacional(c):
    suelo(c, col=hexa('c8b784'))
    c.cuerpo([(8, 108), (52, 28), (96, 108)], hexa('d9b87a'), sombra=0.22, luz=0.24, d=3.0)
    c.poly([(52, 28), (34, 108), (70, 108)], hexa('b98f52'))
    c.poly([(52, 50), (44, 108), (60, 108)], hexa('5a3a22'))
    c.linea([(52, 28), (52, 14)], 3, MADERA_O)
    c.linea([(36, 56), (68, 56)], 1.2, hexa('9c7440'))
    c.cuerpo([(92, 106), (100, 94), (108, 106)], hexa('f57f2a'), sombra=0.2, luz=0.2, d=1.6)
    c.poly([(97, 106), (100, 99), (103, 106)], LLAMA_V)
    c.linea([(88, 108), (112, 104)], 3.4, MADERA_O)
    c.linea([(88, 104), (112, 108)], 3.4, MADERA_O)


def adobe_barro(c):
    suelo(c, col=hexa('d2b684'))
    cuadro(c, 14, 54, 114, 110, hexa('d9b182'))
    c.rect(10, 48, 118, 58, hexa('c79d6c'), r=3)
    c.rect(48, 70, 80, 110, hexa('7a4f2e'), r=14)
    c.rect(48, 96, 80, 110, hexa('7a4f2e'))
    for x in (22, 94):
        c.rect(x, 68, x + 14, 82, hexa('5a3a22'), r=2)
    for x in (24, 46, 82, 100):
        c.linea([(x, 40), (x, 52)], 4, MADERA_O)
    c.cuerpo([(70, 26), (112, 26), (112, 50), (70, 50)], hexa('d9b182'), sombra=0.2, luz=0.2, d=2.2)
    c.rect(66, 22, 116, 30, hexa('c79d6c'), r=3)


def aldea_permanente(c):
    suelo(c)
    casa(c, 8, 44, 108, 28, hexa('e6d3a8'), PAJA, 16)
    casa(c, 84, 120, 108, 30, hexa('e6d3a8'), PAJA, 16)
    casa(c, 38, 90, 112, 40, hexa('efe0bd'), hexa('c4803f'), 20)
    arbol(c, 124, 108, 7)


def construccion_piedra(c):
    suelo(c)
    cuadro(c, 16, 52, 112, 110, PIEDRA)
    for yy in range(60, 108, 12):
        c.linea([(16, yy), (112, yy)], 1.3, PIEDRA_O)
    for k, yy in enumerate(range(52, 108, 12)):
        for xx in range(22 + (k % 2) * 8, 112, 16):
            c.linea([(xx, yy), (xx, yy + 12)], 1.3, PIEDRA_O)
    techo(c, 16, 112, 53, 16, hexa('8d6a4a'), alero=7)
    puerta(c, 64, 110, 22, 34)
    ventana(c, 26, 66, 9, 12)
    ventana(c, 93, 66, 9, 12)


def ciudad_primitiva(c):
    suelo(c, col=hexa('c8b784'))
    n = 0
    for fila, (y1, xs) in enumerate(((110, (10, 44, 78)), (78, (24, 58)), (46, (40,)))):
        for x in xs:
            cuadro(c, x, y1 - 32, x + 36, y1, hexa('dcc08e') if (fila + n) % 2 == 0 else hexa('d1b27c'))
            c.rect(x + 12, y1 - 17, x + 24, y1 - 5, hexa('6a4528'), r=1.5)
            c.linea([(x + 30, y1 - 32), (x + 30, y1 - 44)], 2.6, MADERA_O)
            n += 1
    c.linea([(102, 78), (102, 110)], 2.6, MADERA_O)
    c.linea([(110, 78), (110, 110)], 2.6, MADERA_O)
    for yy in range(84, 108, 6):
        c.linea([(102, yy), (110, yy)], 2.0, MADERA_O)


def templos_monumentales(c):
    suelo(c, col=hexa('c8b784'))
    for k, (x0, x1, y0, y1) in enumerate(((8, 120, 84, 110), (22, 106, 62, 86), (36, 92, 42, 64))):
        cuadro(c, x0, y0, x1, y1, hexa('d9c493') if k % 2 == 0 else hexa('cdb57e'), d=3.0)
    c.poly([(54, 110), (74, 110), (74, 104), (66, 104), (66, 86), (60, 86), (60, 64), (54, 64)], hexa('b8a064'))
    cuadro(c, 48, 22, 80, 42, hexa('e4d4a8'))
    c.rect(44, 17, 84, 24, hexa('c4553f'), r=2)
    c.rect(58, 28, 70, 42, hexa('5a3a22'), r=1.5)
    for xx in range(14, 112, 12):
        c.linea([(xx, 86), (xx, 108)], 1.0, hexa('b09a68'))


def arco_boveda(c):
    suelo(c, col=hexa('a9a396'))
    cuadro(c, 14, 40, 114, 110, PIEDRA_C)
    c.cuerpo([(14, 40), (114, 40), (114, 28), (14, 28)], PIEDRA, sombra=0.2, luz=0.2, d=2.2)
    pts = [(38, 110)] + [(64 - 26 * math.cos(math.radians(a)), 68 - 26 * math.sin(math.radians(a))) for a in range(0, 181, 12)] + [(90, 110)]
    c.poly(pts, hexa('3c3946'))
    c.cuerpo([(58, 36), (70, 36), (68, 48), (60, 48)], PIEDRA, sombra=0.2, luz=0.2, d=1.4)
    for xx in (22, 100):
        c.rect(xx, 52, xx + 6, 106, PIEDRA, r=1)
    for k in range(7):
        a = math.radians(180 - k * 30)
        c.linea([(64 + 26 * math.cos(a), 68 - 26 * math.sin(a)), (64 + 33 * math.cos(a), 68 - 33 * math.sin(a))], 1.5, PIEDRA_O)


def foro_agora(c):
    suelo(c, col=hexa('d8d2c0'), grosor=8, y=112)
    c.cuerpo([(6, 40), (122, 40), (112, 28), (16, 28)], hexa('e4ddc8'), sombra=0.2, luz=0.2, d=2.2)
    cuadro(c, 6, 40, 122, 48, hexa('efe9d6'))
    for k in range(6):
        columna(c, 12 + k * 19, 52, 104, 9)
    cuadro(c, 4, 104, 124, 112, hexa('d1c9b2'))


def ciudades_romanas_servicios(c):
    suelo(c, col=hexa('c8b784'), y=112, grosor=8)
    c.cuerpo(spline([(6, 112), (6, 60), (30, 34), (98, 34), (122, 60), (122, 112)]), hexa('e2c898'), sombra=0.22, luz=0.2, d=3.0)
    for fila, (y0, y1) in enumerate(((84, 112), (56, 80))):
        n = 7
        for i in range(n):
            x = 14 + i * (100 / n)
            pts = [(x, y1)] + [(x + 6 - 6 * math.cos(math.radians(a)), y0 + 7 - 7 * math.sin(math.radians(a))) for a in range(0, 181, 20)] + [(x + 12, y1)]
            c.poly(pts, hexa('5d5148'))
    for i in range(7):
        x = 12 + i * 15
        c.poly([(x, 36), (x + 8, 36), (x + 8, 50), (x, 50)], hexa('a8946a'))
    c.rect(6, 82, 122, 86, hexa('cdb07a'))


def cupula(c):
    suelo(c, col=hexa('c9c3b6'), y=112, grosor=8)
    cuadro(c, 16, 70, 112, 112, hexa('efe6d0'))
    c.cuerpo(spline([(26, 70), (28, 44), (46, 24), (64, 18), (82, 24), (100, 44), (102, 70)]), hexa('5aa8c4'), sombra=0.26, luz=0.3, d=3.4)
    c.linea([(64, 18), (64, 6)], 2.6, ORO2)
    c.punto(64, 5, 3.5, ORO)
    for k in (-1, 0, 1):
        c.linea(spline([(64 + k * 24, 70), (64 + k * 13, 40), (64 + k * 4, 22)], cerrada=False), 1.6, hexa('3d85a2'))
    c.rect(22, 66, 106, 74, hexa('dccfb0'), r=1.5)
    for i in range(5):
        x = 24 + i * 17
        pts = [(x, 110)] + [(x + 6 - 6 * math.cos(math.radians(a)), 88 - 8 * math.sin(math.radians(a))) for a in range(0, 181, 20)] + [(x + 12, 110)]
        c.poly(pts, hexa('4a4458'))


def burgos_fortificados(c):
    suelo(c)
    muro(c, 4, 124, 62, 108, PIEDRA, 6, False)
    torre(c, 14, 108, 18, 56, PIEDRA, n=2)
    torre(c, 114, 108, 18, 56, PIEDRA, n=2)
    casa(c, 30, 58, 62, 24, hexa('efe0bd'), TEJA, 14, False)
    casa(c, 70, 100, 62, 28, hexa('efe0bd'), TEJA_O, 14, False)
    puerta(c, 64, 108, 22, 30)
    aspillera(c, 14, 70, 9)
    aspillera(c, 114, 70, 9)


def catedral_gotica(c):
    suelo(c, col=hexa('b9b3a6'), y=112, grosor=8)
    cuadro(c, 34, 50, 94, 112, hexa('d9d3c4'))
    c.cuerpo([(34, 50), (64, 12), (94, 50)], hexa('c9c2b0'), sombra=0.22, luz=0.2, d=2.6)
    for cx in (22, 106):
        cuadro(c, cx - 13, 38, cx + 13, 112, hexa('cdc6b4'))
        c.cuerpo([(cx - 14, 38), (cx, 2), (cx + 14, 38)], hexa('5f6c8c'), sombra=0.24, luz=0.28, d=2.4)
        c.poly([(cx - 3, 54), (cx + 3, 54), (cx + 3, 74), (cx, 80), (cx - 3, 74)], hexa('3d3946'))
    c.cuerpo_elip(64, 52, 14, col=hexa('7ab0e8'), sombra=0.2, luz=0.2, d=2.0)
    for k in range(8):
        a = math.radians(k * 45)
        c.linea([(64, 52), (64 + 13 * math.cos(a), 52 + 13 * math.sin(a))], 1.4, hexa('e4eaf8'))
    c.poly([(52, 112), (52, 86), (64, 70), (76, 86), (76, 112)], hexa('4a3a2a'))
    c.poly([(58, 112), (58, 88), (64, 80), (70, 88), (70, 112)], hexa('2d2530'))


def plazas_mercado_urbano(c):
    suelo(c, col=hexa('d3c8a6'), y=112, grosor=8)
    for (x0, x1, a, b) in ((6, 66, TEJA, hexa('fbf6ee')), (62, 122, hexa('3f7fd0'), hexa('fbf6ee'))):
        c.cuerpo([(x0, 52), (x1, 52), (x1 + 4, 70), (x0 - 4, 70)], a, sombra=0.2, luz=0.2, d=2.4)
        for i in range(5):
            xs = x0 + i * (x1 - x0) / 5.0
            c.poly([(xs + 6, 52), (xs + 12, 52), (xs + 14, 70), (xs + 8, 70)], b)
        c.linea([(x0 + 4, 70), (x0 + 4, 108)], 3, MADERA_O)
        c.linea([(x1 - 4, 70), (x1 - 4, 108)], 3, MADERA_O)
        cuadro(c, x0 + 6, 90, x1 - 6, 110, MADERA)
    for k, col_ in enumerate((ROJO, NARANJA, LIMA, ROJO)):
        c.cuerpo_elip(16 + k * 12, 88, 6, col=col_, sombra=0.2, luz=0.35, d=1.6)
    for k, col_ in enumerate((LIMA, ROJO, NARANJA, ORO)):
        c.cuerpo_elip(74 + k * 11, 88, 6, col=col_, sombra=0.2, luz=0.35, d=1.6)


def barrios_obreros(c):
    suelo(c, col=hexa('8a8f9a'), y=112, grosor=8)
    for k in range(4):
        x0 = 6 + k * 30
        cuadro(c, x0, 56, x0 + 28, 112, LADRILLO if k % 2 == 0 else hexa('b8583c'))
        c.poly([(x0 - 2, 56), (x0 + 14, 40), (x0 + 30, 56)], hexa('5a5f6e'))
        ventana(c, x0 + 4, 66, 7, 9)
        ventana(c, x0 + 17, 66, 7, 9)
        ventana(c, x0 + 4, 86, 7, 9)
        c.rect(x0 + 17, 90, x0 + 24, 112, hexa('4a3a2a'))
        cuadro(c, x0 + 18, 28, x0 + 24, 48, LADRILLO_O, sombra=0.2, luz=0.0, d=1.6)
    humo(c, 28, 24, 3)
    humo(c, 88, 24, 3)


def parques_publicos(c):
    suelo(c, col=CESPED, y=104, grosor=16)
    c.poly([(40, 120), (88, 120), (76, 104), (52, 104)], hexa('d8c9a0'))
    arbol(c, 28, 100, 20)
    arbol(c, 100, 96, 17, hexa('4aa860'))
    arbol(c, 66, 90, 12, hexa('5cc576'))
    cuadro(c, 44, 94, 84, 100, MADERA, d=1.8)
    c.linea([(48, 100), (48, 108)], 3, MADERA_O)
    c.linea([(80, 100), (80, 108)], 3, MADERA_O)
    c.linea([(46, 88), (82, 88)], 5, MADERA)


def rascacielos(c):
    suelo(c, col=hexa('7c8497'), y=112, grosor=8)
    for (x0, x1, y0, col_) in ((8, 36, 62, hexa('7f9acc')), (92, 120, 52, hexa('8aa6d6'))):
        cuadro(c, x0, y0, x1, 112, col_)
    cuadro(c, 34, 22, 94, 112, hexa('5f86cc'), d=3.2)
    c.poly([(34, 22), (44, 12), (84, 12), (94, 22)], hexa('7aa0e0'))
    c.linea([(64, 12), (64, 2)], 2.4, ACERO)
    for k in range(9):
        for i in range(4):
            c.rect(40 + i * 13, 28 + k * 9, 48 + i * 13, 34 + k * 9, hexa('d8ecff') if (i + k) % 3 else AMARILLO_V, r=0.8)
    for x0 in (13, 97):
        for k in range(4):
            c.rect(x0, 70 + k * 10, x0 + 7, 76 + k * 10, hexa('dbe9ff'), r=0.8)
    c.rect(54, 98, 74, 112, hexa('2a3550'), r=1)



# ───────────── defensa fija ─────────────
def empalizada(c):
    suelo(c, col=hexa('b49a62'), y=108, grosor=12)
    for k in range(9):
        x = 6 + k * 13.5
        alto = 66 + (k % 3) * 6
        c.cuerpo([(x, 110), (x, 110 - alto + 14), (x + 6.5, 110 - alto), (x + 13, 110 - alto + 14), (x + 13, 110)], MADERA if k % 2 else hexa('c08a4c'), sombra=0.24, luz=0.2, d=2.0)
    c.linea([(6, 70), (122, 70)], 3.6, hexa('8a5a2c'))
    c.linea([(6, 92), (122, 92)], 3.6, hexa('8a5a2c'))


def zanja_foso(c):
    c.cuerpo([(4, 36), (46, 36), (46, 40), (4, 40)], CESPED, sombra=0.2, luz=0.2, d=2.0)
    cuadro(c, 4, 40, 124, 110, TIERRA_C)
    c.cuerpo([(4, 36), (124, 36), (124, 46), (4, 46)], CESPED, sombra=0.2, luz=0.2, d=2.2)
    c.poly([(30, 46), (98, 46), (84, 100), (44, 100)], TIERRA_O)
    c.poly([(40, 66), (88, 66), (84, 100), (44, 100)], AGUA)
    olas(c, 74, 42, 86, AGUA_C, 3)
    for x in (10, 20, 100, 110):
        c.poly([(x, 36), (x + 4, 18), (x + 8, 36)], MADERA)
        c.poly([(x, 36), (x + 4, 18), (x + 4, 36)], MADERA_O)


def murallas_urbanas(c):
    suelo(c, y=112, grosor=8)
    casa(c, 10, 40, 74, 22, hexa('efe0bd'), TEJA, 12, False)
    casa(c, 88, 118, 74, 22, hexa('efe0bd'), TEJA_O, 12, False)
    muro(c, 2, 126, 58, 112, PIEDRA, 7)
    torre(c, 24, 112, 22, 66, PIEDRA, n=2, ladrillos=False)
    torre(c, 104, 112, 22, 66, PIEDRA, n=2, ladrillos=False)
    puerta(c, 64, 112, 26, 36, hexa('4a3220'))
    for xx in (58, 64, 70):
        c.linea([(xx, 78), (xx, 112)], 1.4, hexa('7a7a82'))
    aspillera(c, 24, 66, 10)
    aspillera(c, 104, 66, 10)


def fortaleza_colina(c):
    c.cuerpo(spline([(0, 114), (10, 90), (34, 66), (64, 52), (94, 66), (118, 90), (128, 114)]), CESPED, sombra=0.24, luz=0.25, d=3.2)
    c.poly([(30, 114), (64, 76), (98, 114)], hexa('5aab55'))
    muro(c, 36, 92, 36, 62, PIEDRA, 4, False)
    torre(c, 40, 62, 14, 40, PIEDRA_C, n=2)
    torre(c, 88, 62, 14, 40, PIEDRA_C, n=2)
    c.cuerpo([(54, 16), (74, 16), (74, 40), (54, 40)], PIEDRA_C, sombra=0.2, luz=0.2, d=2.2)
    bandera_asta(c, 64, 18, 14, ROJO, 12)
    puerta(c, 64, 62, 12, 16)
    c.linea([(60, 112), (66, 94), (76, 84), (64, 76)], 4, hexa('c9b078'))


def muralla_piedra(c):
    suelo(c, y=112, grosor=8)
    muro(c, 2, 126, 50, 112, PIEDRA_C, 8)
    cuadro(c, 2, 46, 126, 52, hexa('d8d2c4'), sombra=0.15, luz=0.1, d=1.6)
    for xx in (24, 64, 104):
        aspillera(c, xx, 66, 14)
    c.cuerpo([(40, 112), (88, 112), (88, 92), (40, 92)], PIEDRA, sombra=0.0, luz=0.0)
    puerta(c, 64, 112, 28, 38, hexa('3d2a1a'))
    c.linea([(56, 78), (72, 78)], 1.6, hexa('2a2018'))


def fortin_torre_vigia(c):
    suelo(c, col=hexa('b49a62'), y=108, grosor=12)
    for x in (34, 88):
        c.linea([(x, 110), (x + (6 if x < 60 else -6), 46)], 5, MADERA_O)
    c.linea([(40, 94), (82, 94)], 3.6, MADERA)
    c.linea([(38, 70), (84, 70)], 3.6, MADERA)
    c.linea([(40, 110), (82, 70)], 3, MADERA)
    c.linea([(82, 110), (40, 70)], 3, MADERA)
    cuadro(c, 26, 40, 98, 50, MADERA, d=2.2)
    cuadro(c, 30, 20, 94, 42, hexa('c28a4c'), d=2.4)
    techo(c, 30, 94, 22, 4, MADERA_O, alero=8)
    c.rect(54, 28, 70, 42, OSCURO_V, r=1)
    c.linea([(94, 22), (94, 8)], 2.4, MADERA_O)
    c.cuerpo([(95, 8), (110, 12), (95, 17)], ROJO, sombra=0.2, luz=0.2, d=1.4)


def torres_y_almenas(c):
    suelo(c, y=112, grosor=8)
    torre(c, 40, 112, 36, 90, PIEDRA_C, n=3, ladrillos=True)
    torre(c, 92, 112, 26, 68, PIEDRA, n=2, ladrillos=True)
    for (x, y) in ((40, 40), (40, 66), (92, 62)):
        aspillera(c, x, y, 12, 3.4)
    puerta(c, 40, 112, 14, 22)
    cuadro(c, 58, 76, 80, 92, PIEDRA_C, d=2.0)
    bandera_asta(c, 40, 20, 14, ROJO, 12)


def limes_fronteras_fortificadas(c):
    suelo(c, y=112, grosor=8)
    c.cuerpo([(4, 84), (124, 56), (124, 80), (4, 112)], PIEDRA, sombra=0.2, luz=0.2, d=3.0)
    for k in range(7):
        x = 10 + k * 17
        y = 84 - (x - 4) * (28.0 / 120.0)
        c.rect(x, y - 6, x + 8, y, PIEDRA_C, r=1)
    for (x, y) in ((22, 62), (82, 40)):
        cuadro(c, x - 12, y - 6, x + 12, y + 36, PIEDRA_C)
        almenas(c, x - 13, x + 13, y - 6, PIEDRA_C, 3, 6)
        aspillera(c, x, y + 6, 12)
    for k in range(4):
        c.punto(60 + k * 14, 108 - k * 4, 3.0, hexa('d0a84a'))
    bandera_asta(c, 104, 56, 16, ROJO, 12)


def castillo_motte(c):
    c.cuerpo(spline([(0, 114), (8, 90), (30, 60), (64, 46), (98, 60), (120, 90), (128, 114)]), hexa('8bc46e'), sombra=0.26, luz=0.25, d=3.4)
    c.poly([(8, 114), (30, 94), (98, 94), (120, 114)], hexa('6fa856'))
    for k in range(7):
        x = 36 + k * 9.5
        c.cuerpo([(x, 62), (x, 56), (x + 4.75, 50), (x + 9.5, 56), (x + 9.5, 62)], MADERA, sombra=0.22, luz=0.2, d=1.6)
    cuadro(c, 44, 26, 84, 54, hexa('c28a4c'), d=2.6)
    techo(c, 44, 84, 28, 6, MADERA_O, alero=6)
    c.rect(58, 38, 70, 54, OSCURO_V, r=1)
    c.rect(48, 34, 54, 42, AMARILLO_V)
    c.rect(74, 34, 80, 42, AMARILLO_V)
    c.linea([(84, 70), (112, 104)], 4, hexa('c9a468'))


def puertas_fortificadas(c):
    suelo(c, y=112, grosor=8)
    torre(c, 22, 112, 34, 90, PIEDRA_C, n=3, ladrillos=True)
    torre(c, 106, 112, 34, 90, PIEDRA_C, n=3, ladrillos=True)
    cuadro(c, 36, 30, 92, 112, PIEDRA)
    almenas(c, 36, 92, 30, PIEDRA, 4, 7)
    pts = [(46, 112)] + [(64 - 18 * math.cos(math.radians(a)), 70 - 24 * math.sin(math.radians(a))) for a in range(0, 181, 12)] + [(82, 112)]
    c.poly(pts, hexa('2d2530'))
    for xx in range(50, 80, 6):
        c.linea([(xx, 56), (xx, 112)], 2.0, hexa('8a8a96'))
    for yy in (68, 84, 100):
        c.linea([(48, yy), (80, yy)], 2.0, hexa('8a8a96'))
    for (x, y) in ((22, 40), (106, 40)):
        aspillera(c, x, y, 12, 3.4)
    bandera_asta(c, 64, 30, 14, ROJO, 12)


def castillo_piedra(c):
    suelo(c, y=112, grosor=8)
    cuadro(c, 30, 40, 98, 112, PIEDRA_C, d=3.0)
    almenas(c, 30, 98, 40, PIEDRA_C, 5, 8)
    for (x, alto) in ((24, 84), (104, 84)):
        torre(c, x, 112, 24, alto, PIEDRA, n=2, ladrillos=True)
    cuadro(c, 48, 16, 80, 44, PIEDRA, d=2.6)
    almenas(c, 47, 81, 16, PIEDRA, 3, 7)
    puerta(c, 64, 112, 22, 32)
    for (x, y) in ((24, 44), (104, 44), (64, 24)):
        aspillera(c, x, y, 10, 3.2)
    bandera_asta(c, 64, 10, 12, ROJO, 12)


def castillo_concentrico(c):
    suelo(c, y=112, grosor=8)
    muro(c, 2, 126, 76, 112, PIEDRA, 8, False)
    torre(c, 14, 112, 20, 52, PIEDRA, n=2)
    torre(c, 114, 112, 20, 52, PIEDRA, n=2)
    muro(c, 26, 102, 50, 80, PIEDRA_C, 5, False)
    torre(c, 30, 80, 14, 36, PIEDRA_C, n=2)
    torre(c, 98, 80, 14, 36, PIEDRA_C, n=2)
    cuadro(c, 50, 12, 78, 54, PIEDRA, d=2.6)
    almenas(c, 49, 79, 12, PIEDRA, 3, 7)
    puerta(c, 64, 112, 18, 26)
    bandera_asta(c, 64, 6, 4, ROJO, 12)


def fortificacion_abaluartada(c):
    suelo(c, y=112, grosor=8, col=CESPED)
    c.cuerpo([(64, 20), (116, 56), (116, 102), (64, 110), (12, 102), (12, 56)], PIEDRA, sombra=0.24, luz=0.22, d=3.2)
    c.poly([(64, 34), (102, 60), (102, 96), (64, 102), (26, 96), (26, 60)], hexa('7ec36a'))
    for (x, y) in ((64, 22), (114, 58), (14, 58)):
        c.cuerpo(regular(x, y + 6, 14, 3, -90), PIEDRA_C, sombra=0.2, luz=0.2, d=2.0)
    c.linea([(40, 76), (88, 76)], 3, hexa('6a5a3a'))
    for k, x in enumerate((46, 64, 82)):
        c.cuerpo_elip(x, 66, 5.5, col=OSCURO_V, sombra=0.0, luz=0.0)
        c.rect(x - 1.8, 62, x + 1.8, 72, hexa('5a5a64'))


def fortaleza_estrella(c):
    suelo(c, y=112, grosor=8, col=hexa('4a90d0'))
    c.cuerpo(estrella(64, 62, 58, 36, 5), hexa('4a98e0'), sombra=0.2, luz=0.2, d=2.4)
    c.cuerpo(estrella(64, 62, 48, 30, 5), PIEDRA, sombra=0.24, luz=0.22, d=3.0)
    c.poly(estrella(64, 62, 38, 25, 5), hexa('7ec36a'))
    cuadro(c, 52, 48, 76, 76, PIEDRA_C, d=2.4)
    almenas(c, 51, 77, 48, PIEDRA_C, 3, 6)
    c.rect(60, 62, 68, 76, OSCURO_V, r=1)
    for k in range(5):
        a = math.radians(-90 + k * 72)
        c.punto(64 + 41 * math.cos(a), 62 + 41 * math.sin(a), 3.4, OSCURO_V)


def fortificaciones_permanentes(c):
    suelo(c, y=112, grosor=8)
    cuadro(c, 4, 60, 124, 112, hexa('b9b2a2'), d=3.0)
    c.poly([(4, 60), (22, 44), (106, 44), (124, 60)], PIEDRA)
    for xx in range(18, 112, 20):
        c.rect(xx, 72, xx + 12, 80, OSCURO_V, r=1.5)
    for (x, ang) in ((30, -35), (64, -60), (98, -35)):
        c.cuerpo_elip(x, 46, 7, col=hexa('4a4f5c'), sombra=0.2, luz=0.3, d=1.6)
        c.linea([(x, 46), (x + 22 * math.cos(math.radians(ang)), 46 + 22 * math.sin(math.radians(ang)))], 6, hexa('4a4f5c'))
    puerta(c, 64, 112, 18, 26)
    for yy in (92, 104):
        c.linea([(4, yy), (124, yy)], 1.2, PIEDRA_O)
    bandera_asta(c, 14, 44, 18, ROJO, 12)


def fuertes_costeros(c):
    c.cuerpo([(0, 84), (128, 84), (128, 120), (0, 120)], AGUA, sombra=0.2, luz=0.2, d=3.0)
    olas(c, 100, 4, 124, AGUA_C, 7)
    c.cuerpo(spline([(14, 90), (22, 60), (50, 50), (108, 56), (118, 74), (112, 92)]), hexa('c8b784'), sombra=0.24, luz=0.2, d=3.2)
    cuadro(c, 34, 42, 104, 86, hexa('b9b2a2'), d=3.0)
    almenas(c, 34, 104, 42, hexa('b9b2a2'), 5, 7)
    for (x, ang) in ((52, -20), (84, -20)):
        c.cuerpo_elip(x, 64, 7.5, col=hexa('4a4f5c'), sombra=0.2, luz=0.3, d=1.6)
        c.linea([(x, 64), (x - 26, 64 - 8)], 7, hexa('4a4f5c'))
    puerta(c, 70, 86, 14, 18)
    bandera_asta(c, 100, 42, 16, ROJO, 12)


def fortificacion_hormigon(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    c.cuerpo([(8, 112), (22, 64), (106, 64), (120, 112)], HORMIGON, sombra=0.22, luz=0.22, d=3.2)
    cuadro(c, 30, 34, 98, 66, HORMIGON, d=3.0)
    c.rect(36, 46, 90, 54, OSCURO_V, r=2)
    c.rect(36, 78, 60, 86, OSCURO_V, r=2)
    c.rect(68, 78, 92, 86, OSCURO_V, r=2)
    c.rect(54, 96, 74, 112, hexa('4a4f5c'), r=1.5)
    for xx in (34, 94):
        c.linea([(xx, 34), (xx, 66)], 1.2, HORMIGON_O)
    c.linea([(8, 100), (120, 100)], 1.4, HORMIGON_O)


def fuertes_acorazados(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    c.cuerpo([(6, 112), (20, 70), (108, 70), (122, 112)], HORMIGON, sombra=0.22, luz=0.22, d=3.2)
    c.cuerpo(spline([(32, 70), (36, 46), (64, 34), (92, 46), (96, 70)]), ACERO, sombra=0.28, luz=0.35, d=3.2)
    c.linea([(80, 54), (118, 40)], 8, ACERO_O)
    c.rect(114, 36, 122, 46, ACERO_O, r=1.5)
    c.cuerpo_elip(64, 52, 6, col=ACERO_O, sombra=0.0, luz=0.0)
    for xx in (40, 58, 76, 94):
        c.punto(xx, 66, 2.2, ACERO_O)
    c.rect(52, 92, 76, 112, hexa('4a4f5c'), r=1.5)
    c.rect(30, 84, 50, 90, OSCURO_V, r=1.5)
    c.rect(80, 84, 100, 90, OSCURO_V, r=1.5)


def casamatas_hormigon(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    c.cuerpo(spline([(8, 112), (12, 70), (30, 46), (64, 38), (98, 46), (116, 70), (120, 112)]), HORMIGON, sombra=0.24, luz=0.3, d=3.4)
    c.rect(34, 66, 94, 78, OSCURO_V, r=3)
    c.linea([(50, 72), (28, 80)], 6, hexa('4a4f5c'))
    c.cuerpo([(20, 112), (108, 112), (112, 96), (16, 96)], HORMIGON_O, sombra=0.2, luz=0.1, d=2.0)
    for xx in (30, 54, 78, 102):
        c.punto(xx, 104, 2.4, HORMIGON)


def sistema_trincheras(c):
    cuadro(c, 0, 0, 128, 128, hexa('b79c68'), sombra=0.0, luz=0.0)
    c.linea([(4, 50), (36, 50), (36, 88), (70, 88), (70, 50), (104, 50), (104, 84), (126, 84)], 20, hexa('6e5638'))
    c.linea([(4, 50), (36, 50), (36, 88), (70, 88), (70, 50), (104, 50), (104, 84), (126, 84)], 12, hexa('4a3a26'))
    for (x, y) in ((16, 36), (52, 74), (52, 64), (86, 36), (116, 70)):
        c.cuerpo_elip(x, y, 8, 5, col=hexa('c9b078'), sombra=0.25, luz=0.3, d=1.6)
    for x in (10, 20, 94, 114):
        c.linea([(x, 100), (x + 12, 108)], 2.6, hexa('5a5f6e'))
        c.linea([(x, 108), (x + 12, 100)], 2.6, hexa('5a5f6e'))
    c.linea([(4, 114), (124, 114)], 2.0, hexa('5a5f6e'))


def linea_defensiva_permanente(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    for k in range(4):
        x = 10 + k * 28
        c.cuerpo([(x, 112), (x + 12, 66), (x + 24, 112)], HORMIGON, sombra=0.22, luz=0.25, d=2.4)
    c.cuerpo(spline([(60, 66), (64, 46), (82, 36), (100, 46), (104, 66)]), HORMIGON, sombra=0.22, luz=0.3, d=2.4)
    cuadro(c, 56, 62, 108, 90, HORMIGON, d=2.6)
    c.rect(64, 70, 100, 76, OSCURO_V, r=1.5)
    c.linea([(70, 73), (50, 80)], 4, hexa('4a4f5c'))
    c.linea([(4, 100), (124, 100)], 2.0, hexa('5a5f6e'))


def bunker_antiaereo(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    cuadro(c, 14, 74, 114, 112, HORMIGON, d=3.2)
    c.cuerpo([(14, 74), (114, 74), (104, 62), (24, 62)], HORMIGON_O, sombra=0.0, luz=0.2, d=2.0)
    c.rect(34, 88, 64, 96, OSCURO_V, r=2)
    c.rect(78, 88, 96, 112, hexa('4a4f5c'), r=1.5)
    c.cuerpo_elip(64, 58, 12, 8, col=hexa('4a4f5c'), sombra=0.2, luz=0.3, d=1.6)
    for k in (-1, 1):
        c.linea([(64 + k * 4, 54), (64 + k * 18, 14)], 5.0, hexa('4a4f5c'))
    for (x, y) in ((22, 22), (100, 30)):
        c.linea([(x, y), (x + 14, y + 4)], 3, hexa('d0d4e0'))
        c.linea([(x + 4, y - 4), (x + 8, y + 10)], 3, hexa('d0d4e0'))


def bunker_nuclear(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    c.cuerpo(spline([(8, 112), (12, 66), (34, 38), (64, 30), (94, 38), (116, 66), (120, 112)]), HORMIGON, sombra=0.24, luz=0.3, d=3.4)
    c.cuerpo_elip(64, 70, 28, col=hexa('f5c518'), sombra=0.22, luz=0.2, d=2.4)
    c.elip(64, 70, 24, 24, hexa('2d2a30'))
    for k in range(3):
        a0 = -90 + k * 120
        pts = [(64, 70)] + [(64 + 22 * math.cos(math.radians(a0 + d)), 70 + 22 * math.sin(math.radians(a0 + d))) for d in range(-30, 31, 10)]
        c.poly(pts, hexa('f5c518'))
    c.elip(64, 70, 5, 5, hexa('2d2a30'))
    c.rect(52, 100, 76, 112, hexa('4a4f5c'), r=1.5)


def defensa_aerea_integrada(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    cuadro(c, 52, 84, 76, 112, HORMIGON, d=2.6)
    c.linea([(64, 84), (64, 62)], 5, ACERO_O)
    c.cuerpo(spline([(22, 40), (40, 24), (70, 22), (88, 36), (64, 56), (36, 56)]), ACERO, sombra=0.26, luz=0.35, d=2.8)
    c.cuerpo_elip(60, 42, 7, col=ACERO_O, sombra=0.0, luz=0.0)
    c.linea([(60, 42), (88, 18)], 3, ACERO_O)
    for k in range(3):
        c.linea(spline([(96 + k * 8, 50 - k * 6), (100 + k * 8, 42 - k * 6), (96 + k * 8, 34 - k * 6)], cerrada=False), 3, hexa('7ac0f0'))
    c.cuerpo([(14, 104), (44, 104), (44, 112), (14, 112)], hexa('7a8a5a'), sombra=0.2, luz=0.2, d=1.6)
    for k in range(2):
        c.cuerpo([(92 + k * 12, 112), (92 + k * 12, 86), (96 + k * 12, 80), (100 + k * 12, 86), (100 + k * 12, 112)], hexa('d8dde8'), sombra=0.25, luz=0.2, d=1.6)
        c.poly([(96 + k * 12, 80), (100 + k * 12, 86), (92 + k * 12, 86)], ROJO)


def silo_misil(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    cuadro(c, 0, 76, 128, 120, hexa('7a6a52'), sombra=0.0, luz=0.0)
    c.cuerpo_elip(64, 80, 46, 12, col=HORMIGON, sombra=0.2, luz=0.3, d=2.4)
    c.elip(64, 82, 36, 8, OSCURO_V)
    c.cuerpo([(52, 90), (52, 46), (58, 30), (64, 24), (70, 30), (76, 46), (76, 90)], hexa('e8ecf4'), sombra=0.28, luz=0.2, d=2.2)
    c.poly([(58, 30), (64, 12), (70, 30)], ROJO)
    c.poly([(52, 70), (40, 88), (52, 86)], ROJO)
    c.poly([(76, 70), (88, 88), (76, 86)], ROJO)
    c.rect(52, 50, 76, 54, hexa('3a62b8'))
    c.cuerpo([(14, 74), (46, 62), (50, 66), (18, 80)], ACERO, sombra=0.2, luz=0.2, d=1.8)


def base_subterranea_montana(c):
    c.cuerpo([(0, 112), (36, 40), (64, 18), (92, 40), (128, 112)], hexa('8a8f9c'), sombra=0.26, luz=0.25, d=3.4)
    c.poly([(54, 28), (64, 18), (74, 28), (68, 34), (64, 30), (58, 36)], BLANCO)
    c.poly([(0, 112), (22, 72), (36, 80), (20, 112)], hexa('9aa0ae'))
    cuadro(c, 38, 66, 90, 112, HORMIGON, d=2.8)
    pts = [(46, 112)] + [(64 - 18 * math.cos(math.radians(a)), 92 - 20 * math.sin(math.radians(a))) for a in range(0, 181, 15)] + [(82, 112)]
    c.poly(pts, hexa('2d2a35'))
    c.rect(56, 92, 72, 112, ACERO_O, r=1)
    c.linea([(64, 92), (64, 112)], 1.2, ACERO)
    c.rect(42, 70, 86, 74, hexa('f5c518'))
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))


def defensa_costera_misiles(c):
    c.cuerpo([(0, 80), (128, 80), (128, 120), (0, 120)], AGUA, sombra=0.2, luz=0.2, d=3.0)
    olas(c, 102, 4, 124, AGUA_C, 7)
    c.cuerpo([(0, 78), (128, 78), (128, 92), (0, 92)], hexa('c8b784'), sombra=0.2, luz=0.2, d=2.4)
    cuadro(c, 8, 62, 74, 80, hexa('6a7a52'), d=2.4)
    for k in range(2):
        c.cuerpo([(80 + k * 22, 80), (110 + k * 6, 20 + k * 8), (116 + k * 6, 24 + k * 8), (92 + k * 22, 80)], hexa('5a6a46'), sombra=0.25, luz=0.2, d=2.2)
        c.cuerpo([(88 + k * 22, 66), (106 + k * 6, 30 + k * 8), (110 + k * 6, 33 + k * 8), (96 + k * 22, 66)], hexa('e8ecf4'), sombra=0.25, luz=0.2, d=1.6)
        c.poly([(106 + k * 6, 30 + k * 8), (112 + k * 6, 14 + k * 8), (110 + k * 6, 33 + k * 8)], ROJO)
    for xx in (14, 34, 54):
        c.punto(xx + 4, 86, 4.4, OSCURO_V)


def escudo_antimisiles(c):
    c.cuerpo(spline([(8, 100), (10, 64), (30, 36), (64, 24), (98, 36), (118, 64), (120, 100)]), (110, 180, 255, 95), sombra=0.0, luz=0.0)
    c.linea(spline([(10, 100), (12, 64), (32, 38), (64, 26), (96, 38), (116, 64), (118, 100)], cerrada=False), 4, hexa('7ac0f8'))
    c.linea(spline([(26, 100), (28, 70), (44, 50), (64, 44), (84, 50), (100, 70), (102, 100)], cerrada=False), 2.4, hexa('b5dcff'))
    suelo(c, y=104, grosor=14, col=hexa('8f9a74'))
    cuadro(c, 44, 90, 84, 106, HORMIGON, d=2.4)
    c.cuerpo([(52, 90), (58, 74), (70, 74), (76, 90)], ACERO, sombra=0.2, luz=0.3, d=1.8)
    c.cuerpo([(98, 18), (110, 40), (104, 42), (92, 22)], hexa('e8ecf4'), sombra=0.2, luz=0.2, d=1.4)
    c.poly([(98, 18), (92, 6), (92, 22)], ROJO)
    c.cuerpo(estrella(96, 44, 7, 3, 8, 0), hexa('ffd45c'), sombra=0.0, luz=0.0)


# ───────────── economía y comercio ─────────────
def mercados_locales(c):
    suelo(c, col=hexa('d3c8a6'), y=112, grosor=8)
    c.cuerpo([(14, 40), (86, 40), (92, 62), (8, 62)], TEJA, sombra=0.2, luz=0.2, d=2.4)
    for i in range(6):
        xs = 14 + i * 12
        c.poly([(xs + 6, 40), (xs + 12, 40), (xs + 14, 62), (xs + 8, 62)], hexa('fbf6ee'))
    c.linea([(14, 62), (14, 108)], 3.2, MADERA_O)
    c.linea([(86, 62), (86, 108)], 3.2, MADERA_O)
    cuadro(c, 18, 84, 82, 108, MADERA, d=2.2)
    for k, col_ in enumerate((ROJO, NARANJA, LIMA, ORO, ROJO)):
        c.cuerpo_elip(26 + k * 13, 80, 6.5, col=col_, sombra=0.2, luz=0.35, d=1.6)
    c.cuerpo([(94, 108), (120, 108), (118, 80), (96, 80)], hexa('d9c493'), sombra=0.22, luz=0.2, d=2.0)
    c.poly([(94, 80), (120, 80), (112, 72), (102, 72)], hexa('c0aa78'))
    c.linea([(98, 90), (116, 90)], 1.4, hexa('a8925e'))


def almacenes_suministro(c):
    suelo(c, y=112, grosor=8)
    cuadro(c, 8, 54, 120, 112, hexa('c28a58'))
    techo(c, 8, 120, 55, 22, hexa('7f8aa2'), alero=6)
    c.rect(40, 70, 88, 112, hexa('6a4528'), r=2)
    c.linea([(64, 70), (64, 112)], 2.0, hexa('4a2f1a'))
    c.linea([(40, 70), (88, 112)], 2.0, hexa('4a2f1a'))
    c.linea([(88, 70), (40, 112)], 2.0, hexa('4a2f1a'))
    for (x, y) in ((12, 96), (24, 96), (18, 84)):
        cuadro(c, x, y, x + 12, y + 12, hexa('d9b182'), sombra=0.22, luz=0.2, d=1.4)
    for (x, y) in ((94, 96), (106, 96)):
        c.cuerpo_elip(x + 6, y + 6, 7, 9, col=hexa('e6dcc0'), sombra=0.2, luz=0.3, d=1.6)
    ventana(c, 62, 30, 10, 8, hexa('4a3a2a'))


def feria_comercial(c):
    suelo(c, col=hexa('9cc868'), y=108, grosor=12)
    for (cx, y0, col_) in ((30, 52, ROJO), (98, 52, hexa('3f7fd0')), (64, 40, hexa('f2b134'))):
        c.cuerpo([(cx - 28, 100), (cx, y0), (cx + 28, 100)], col_, sombra=0.22, luz=0.24, d=2.6)
        c.poly([(cx - 6, 100), (cx, y0 + 26), (cx + 6, 100)], hexa('3a2a1c'))
        c.linea([(cx, y0), (cx, y0 - 12)], 2.4, MADERA_O)
        c.cuerpo([(cx + 1, y0 - 12), (cx + 12, y0 - 9), (cx + 1, y0 - 5)], hexa('fbf6ee'), sombra=0.15, luz=0.1, d=1.2)
    c.linea(spline([(4, 28), (32, 40), (64, 28), (96, 40), (124, 28)], cerrada=False), 1.6, hexa('7a5a3a'))
    for k, col_ in enumerate((ROJO, ORO, AZUL, VERDE, ROJO, ORO, AZUL, VERDE)):
        xx = 14 + k * 14
        yy = 33 + (6 if k % 2 == 0 else 0)
        c.poly([(xx - 4, yy), (xx + 4, yy), (xx, yy + 9)], col_)


def arsenal_fundicion(c):
    suelo(c, y=112, grosor=8, col=hexa('7c8497'))
    cuadro(c, 10, 62, 96, 112, hexa('9a5a42'))
    c.poly([(6, 62), (30, 40), (100, 40), (100, 62)], hexa('5a5f6e'))
    cuadro(c, 98, 30, 118, 112, hexa('b8583c'), d=2.8)
    c.rect(96, 24, 120, 32, hexa('8a3a2a'), r=1.5)
    humo(c, 108, 18, 3)
    c.rect(24, 76, 62, 112, hexa('2d2a30'), r=3)
    c.cuerpo(spline([(28, 112), (30, 92), (44, 82), (58, 92), (60, 112)]), hexa('f57f2a'), sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo(spline([(36, 112), (38, 98), (44, 92), (52, 98), (54, 112)]), LLAMA_V, sombra=0.0, luz=0.3, d=1.6)
    c.cuerpo([(72, 98), (92, 98), (88, 106), (76, 106)], hexa('4a4f5c'), sombra=0.2, luz=0.3, d=1.6)
    c.rect(78, 106, 86, 112, hexa('4a4f5c'))
    c.rect(84, 92, 94, 98, hexa('4a4f5c'), r=1)


def fabrica_textil(c):
    suelo(c, y=112, grosor=8, col=hexa('7c8497'))
    cuadro(c, 6, 56, 100, 112, LADRILLO)
    for k in range(3):
        x = 6 + k * 31.3
        c.cuerpo([(x, 56), (x, 34), (x + 31.3, 56)], hexa('7f8aa2'), sombra=0.22, luz=0.2, d=2.2)
        c.poly([(x + 3, 54), (x + 3, 44), (x + 24, 54)], hexa('a6c8ea'))
    cuadro(c, 100, 22, 118, 112, LADRILLO_O, d=2.8)
    c.rect(98, 16, 120, 24, hexa('6a2a1a'), r=1.5)
    humo(c, 109, 12, 3)
    for k in range(4):
        ventana(c, 14 + k * 21, 66, 14, 12, hexa('d8ecff'))
    c.rect(40, 92, 66, 112, hexa('4a3a2a'), r=1.5)
    for k, col_ in enumerate((ROJO, AZUL, ORO)):
        c.cuerpo_elip(78 + k * 6, 104, 4.2, 6, col=col_, sombra=0.2, luz=0.3, d=1.2)


def grandes_almacenes(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    cuadro(c, 12, 28, 116, 112, hexa('e9dcc0'), d=3.0)
    c.rect(8, 22, 120, 32, hexa('b8583c'), r=2)
    c.rect(36, 38, 92, 52, hexa('2f5aa8'), r=2)
    c.rect(42, 42, 86, 48, hexa('f4d27a'), r=1)
    for fila in range(2):
        for k in range(5):
            ventana(c, 18 + k * 19, 58 + fila * 18, 12, 11, hexa('a6d0f2'))
    c.cuerpo([(14, 92), (114, 92), (118, 80), (10, 80)], hexa('e0605a'), sombra=0.2, luz=0.2, d=2.0)
    for k in range(6):
        c.poly([(14 + k * 17, 92), (22 + k * 17, 92), (24 + k * 17, 80), (16 + k * 17, 80)], hexa('fbf6ee'))
    c.rect(48, 94, 80, 112, hexa('4a6fb0'), r=1.5)
    c.linea([(64, 94), (64, 112)], 1.4, hexa('e4eaf8'))


# ───────────── transporte y obras públicas ─────────────
def _agua_fondo(c, y0=74, y1=120):
    c.cuerpo([(0, y0), (128, y0), (128, y1), (0, y1)], AGUA, sombra=0.2, luz=0.2, d=3.0)
    olas(c, y0 + 20, 4, 124, AGUA_C, 7)


def puente_madera(c):
    _agua_fondo(c, 78)
    c.cuerpo([(0, 76), (22, 76), (22, 96), (0, 96)], hexa('8bc46e'), sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo([(106, 76), (128, 76), (128, 96), (106, 96)], hexa('8bc46e'), sombra=0.2, luz=0.2, d=2.0)
    for x in (30, 52, 76, 98):
        c.linea([(x, 70), (x, 108)], 5, MADERA_O)
    c.cuerpo([(4, 58), (124, 58), (124, 70), (4, 70)], MADERA, sombra=0.24, luz=0.2, d=2.6)
    for x in range(10, 124, 14):
        c.linea([(x, 58), (x, 70)], 1.4, MADERA_O)
    for x in (8, 36, 64, 92, 120):
        c.linea([(x, 58), (x, 38)], 4, MADERA_O)
    c.linea([(8, 40), (120, 40)], 4, MADERA)
    c.linea([(8, 50), (120, 50)], 3, MADERA)


def puerto_piedra(c):
    _agua_fondo(c, 76)
    cuadro(c, 4, 70, 70, 112, PIEDRA_C, d=3.0)
    c.rect(2, 66, 72, 72, PIEDRA, r=1.5)
    c.linea([(20, 66), (20, 24)], 5, ACERO_O)
    c.linea([(20, 28), (62, 28)], 5, ACERO_O)
    c.linea([(56, 28), (56, 52)], 2.0, ACERO)
    c.rect(52, 52, 60, 60, hexa('d9b182'), r=1)
    cuadro(c, 12, 44, 30, 66, LADRILLO, d=2.0)
    c.cuerpo([(70, 88), (126, 88), (116, 106), (80, 106)], hexa('8a4a2a'), sombra=0.24, luz=0.2, d=2.2)
    c.linea([(98, 88), (98, 50)], 3, MADERA_O)
    c.cuerpo([(98, 52), (98, 82), (74, 82)], hexa('f6efdc'), sombra=0.2, luz=0.1, d=1.6)
    c.cuerpo([(100, 56), (100, 82), (118, 82)], hexa('e8dfc8'), sombra=0.2, luz=0.1, d=1.6)


def puente_piedra_arco(c):
    _agua_fondo(c, 86)
    cuadro(c, 4, 44, 124, 70, PIEDRA_C, d=3.0)
    for x in (30, 70, 108):
        pass
    for k in range(3):
        cx = 24 + k * 40
        pts = [(cx - 16, 100)] + [(cx - 16 * math.cos(math.radians(a)), 70 + 26 * 0 + 30 - 30 * math.sin(math.radians(a)) + 0) for a in range(0, 181, 15)] + [(cx + 16, 100)]
        c.poly(pts, hexa('3a3a46'))
    cuadro(c, 4, 70, 124, 100, PIEDRA, d=2.6, sombra=0.0, luz=0.0)
    for k in range(3):
        cx = 24 + k * 40
        pts = [(cx - 15, 102)] + [(cx - 15 * math.cos(math.radians(a)), 86 - 16 * math.sin(math.radians(a))) for a in range(0, 181, 15)] + [(cx + 15, 102)]
        c.poly(pts, AGUA)
    c.rect(4, 38, 124, 46, PIEDRA, r=2)
    for x in range(8, 124, 14):
        c.rect(x, 32, x + 8, 40, PIEDRA_C, r=1)


def calzada_pavimentada(c):
    c.cuerpo([(0, 128), (128, 128), (128, 54), (0, 54)], hexa('9bc86a'), sombra=0.0, luz=0.0)
    c.cuerpo([(40, 56), (88, 56), (122, 120), (6, 120)], PIEDRA, sombra=0.22, luz=0.2, d=3.0)
    for k, (y, f) in enumerate(((66, 0.2), (78, 0.38), (92, 0.58), (108, 0.82))):
        ancho = 48 + (122 - 6 - 48) * ((y - 56) / 64.0)
        x0 = 64 - ancho / 2
        c.linea([(x0 + 4, y), (x0 + ancho - 4, y)], 1.6, PIEDRA_O)
        n = 3 + k
        for i in range(1, n):
            xx = x0 + ancho * i / n + (ancho / n / 2 if k % 2 else 0)
            if x0 + 4 < xx < x0 + ancho - 4:
                c.linea([(xx, y), (xx + (xx - 64) * 0.12, y + 12 + k * 3)], 1.4, PIEDRA_O)
    c.linea([(64, 58), (64, 118)], 3, hexa('f2d680'))
    arbol(c, 14, 70, 8)
    arbol(c, 114, 66, 8)


def red_viaria_imperial(c):
    cuadro(c, 0, 0, 128, 128, hexa('8fc268'), sombra=0.0, luz=0.0)
    for pts in (((4, 100), (50, 70), (124, 28)), ((10, 24), (60, 66), (124, 104)), ((64, 6), (64, 66), (40, 124))):
        c.linea(spline(list(pts), cerrada=False), 12, hexa('b79c68'))
        c.linea(spline(list(pts), cerrada=False), 7, hexa('d8c49a'))
    c.cuerpo_elip(60, 68, 14, col=hexa('d8c49a'), sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo([(56, 82), (66, 82), (65, 56), (57, 56)], hexa('e4ddc8'), sombra=0.2, luz=0.1, d=1.6)
    c.cuerpo_elip(61, 52, 6, 4, col=hexa('e4ddc8'), sombra=0.0, luz=0.0)
    c.cuerpo(estrella(61, 52, 3.5, 1.5, 5), ROJO, sombra=0.0, luz=0.0)
    for (x, y) in ((20, 58), (100, 56), (104, 112)):
        arbol(c, x, y, 7)


def faro(c):
    c.cuerpo([(0, 96), (128, 96), (128, 128), (0, 128)], AGUA, sombra=0.2, luz=0.2, d=3.0)
    olas(c, 112, 4, 124, AGUA_C, 7)
    c.cuerpo(spline([(14, 100), (24, 82), (64, 76), (104, 82), (116, 100)]), hexa('8a8f9c'), sombra=0.26, luz=0.25, d=3.2)
    c.cuerpo([(46, 84), (82, 84), (74, 34), (54, 34)], hexa('f1ede2'), sombra=0.24, luz=0.15, d=3.0)
    for (y0, y1) in ((44, 56), (68, 80)):
        c.poly([(56 - (y0 - 34) * 0.17, y0), (72 + (y0 - 34) * 0.17, y0), (72 + (y1 - 34) * 0.17, y1), (56 - (y1 - 34) * 0.17, y1)], ROJO)
    c.rect(50, 28, 78, 36, hexa('4a4f5c'), r=1.5)
    c.cuerpo([(54, 28), (74, 28), (74, 14), (54, 14)], hexa('a6d8f0'), sombra=0.2, luz=0.3, d=1.6)
    c.poly([(52, 14), (64, 4), (76, 14)], ROJO)
    c.poly([(74, 18), (122, 6), (122, 34), (74, 24)], (255, 240, 160, 150))
    c.poly([(54, 18), (6, 8), (6, 32), (54, 24)], (255, 240, 160, 150))


def esclusas_canales(c):
    cuadro(c, 0, 70, 128, 128, PIEDRA, sombra=0.0, luz=0.0)
    c.cuerpo([(0, 30), (44, 30), (44, 128), (0, 128)], hexa('3f86d8'), sombra=0.2, luz=0.15, d=2.4)
    c.cuerpo([(48, 56), (128, 56), (128, 128), (48, 128)], AGUA, sombra=0.2, luz=0.15, d=2.4)
    olas(c, 70, 52, 124, AGUA_C, 4)
    olas(c, 46, 4, 40, hexa('7ab8f0'), 2)
    cuadro(c, 40, 30, 52, 100, hexa('6a4528'), d=2.4)
    for yy in (40, 56, 72, 88):
        c.linea([(40, yy), (52, yy)], 1.4, hexa('4a2f1a'))
    c.cuerpo([(0, 24), (128, 24), (128, 34), (0, 34)], hexa('c8b784'), sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo([(70, 76), (110, 76), (102, 96), (78, 96)], hexa('8a4a2a'), sombra=0.24, luz=0.2, d=2.0)
    c.linea([(90, 76), (90, 52)], 2.6, MADERA_O)
    c.cuerpo([(90, 54), (90, 72), (76, 72)], hexa('f6efdc'), sombra=0.15, luz=0.1, d=1.4)
    c.cuerpo([(8, 8), (22, 8), (22, 24), (8, 24)], hexa('b8583c'), sombra=0.2, luz=0.2, d=1.6)


def reclamacion_tierras_mar(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    c.cuerpo([(0, 70), (52, 70), (52, 128), (0, 128)], hexa('3f86d8'), sombra=0.2, luz=0.15, d=2.4)
    olas(c, 84, 4, 48, hexa('7ab8f0'), 3)
    c.cuerpo([(52, 62), (128, 62), (128, 128), (52, 128)], hexa('8bc46e'), sombra=0.2, luz=0.2, d=2.4)
    c.cuerpo([(40, 62), (64, 62), (74, 112), (30, 112)], hexa('c8b784'), sombra=0.22, luz=0.2, d=2.4)
    for k in range(3):
        c.linea([(76, 80 + k * 14), (122, 80 + k * 14)], 3, hexa('5aab55'))
    cuadro(c, 88, 32, 106, 62, hexa('e4ddc8'), d=2.0)
    c.poly([(86, 32), (97, 20), (108, 32)], hexa('b8583c'))
    c.linea([(97, 40), (68, 22)], 3.2, MADERA_O)
    c.linea([(97, 40), (126, 58)], 3.2, MADERA_O)
    c.linea([(97, 40), (120, 12)], 3.2, MADERA_O)
    c.linea([(97, 40), (74, 62)], 3.2, MADERA_O)
    c.poly([(97, 40), (110, 14), (118, 18)], hexa('f6efdc'))
    c.poly([(97, 40), (124, 52), (122, 60)], hexa('f6efdc'))
    c.poly([(97, 40), (84, 66), (76, 62)], hexa('f6efdc'))
    c.poly([(97, 40), (70, 28), (74, 20)], hexa('f6efdc'))


def tunel_excavacion(c):
    c.cuerpo([(0, 120), (30, 36), (64, 14), (98, 36), (128, 120)], hexa('9a8268'), sombra=0.26, luz=0.25, d=3.4)
    c.poly([(0, 120), (20, 80), (34, 84), (20, 120)], hexa('b09a7e'))
    pts = [(36, 120)] + [(64 - 28 * math.cos(math.radians(a)), 90 - 40 * math.sin(math.radians(a))) for a in range(0, 181, 12)] + [(92, 120)]
    c.poly(pts, hexa('2d2a35'))
    c.linea([(36, 120), (36, 88)], 5, MADERA)
    c.linea([(92, 120), (92, 88)], 5, MADERA)
    c.linea([(34, 88), (94, 88)], 5, MADERA)
    c.linea([(34, 88), (64, 64), (94, 88)], 3.4, MADERA_O)
    c.linea([(104, 110), (124, 78)], 3.4, MADERA_O)
    c.poly([(116, 72), (128, 76), (120, 84), (112, 80)], ACERO)
    c.cuerpo([(10, 112), (30, 112), (28, 102), (12, 102)], hexa('6a4528'), sombra=0.2, luz=0.2, d=1.4)


def puentes_hierro(c):
    _agua_fondo(c, 84)
    for x in (4, 106):
        cuadro(c, x, 66, x + 18, 100, PIEDRA, d=2.2)
    c.cuerpo([(4, 62), (124, 62), (124, 70), (4, 70)], ACERO_O, sombra=0.2, luz=0.3, d=2.0)
    c.linea([(14, 62), (14, 36), (114, 36), (114, 62)], 5, ACERO)
    for k in range(7):
        x0 = 14 + k * 100 / 6
        c.linea([(x0, 62), (x0 + 100 / 12, 36)], 3.4, ACERO)
        c.linea([(x0 + 100 / 12, 36), (x0 + 100 / 6, 62)], 3.4, ACERO)
    c.linea([(10, 36), (118, 36)], 5, ACERO_O)
    c.rect(10, 56, 118, 64, hexa('4a3a2a'), r=1.5)
    c.cuerpo([(20, 52), (56, 52), (56, 38), (20, 38)], hexa('b8583c'), sombra=0.0, luz=0.0)


def puentes_colgantes(c):
    _agua_fondo(c, 88)
    for x in (30, 98):
        c.cuerpo([(x - 5, 20), (x + 5, 20), (x + 7, 100), (x - 7, 100)], hexa('b8583c'), sombra=0.25, luz=0.25, d=2.4)
        c.rect(x - 8, 16, x + 8, 24, hexa('8a3a2a'), r=1.5)
    c.cuerpo([(0, 70), (128, 70), (128, 78), (0, 78)], ACERO, sombra=0.2, luz=0.3, d=2.0)
    c.linea(spline([(0, 56), (30, 22), (64, 62), (98, 22), (128, 56)], cerrada=False), 3.4, hexa('d8dde8'))
    for x in range(8, 124, 8):
        if abs(x - 30) < 4 or abs(x - 98) < 4:
            continue
        f = abs(((x - 64) / 34.0)) ** 2 if 30 < x < 98 else 0
        yc = 62 - 40 * (1 - ((x - 64) / 34.0) ** 2) if 30 <= x <= 98 else (56 - (x / 30.0) * 34 if x < 30 else 22 + ((x - 98) / 30.0) * 34)
        c.linea([(x, yc), (x, 70)], 1.4, hexa('b8c0d4'))


def metro_subterraneo(c):
    cuadro(c, 0, 0, 128, 40, CIELO, sombra=0.0, luz=0.0)
    cuadro(c, 0, 40, 128, 128, hexa('8f7e66'), sombra=0.0, luz=0.0)
    c.rect(0, 36, 128, 46, hexa('7a8294'))
    c.cuerpo_elip(64, 100, 56, 22, col=hexa('4a4f5c'), sombra=0.2, luz=0.2, d=2.4)
    c.rect(8, 92, 120, 120, hexa('3d3a46'), r=10)
    c.cuerpo([(22, 90), (106, 90), (106, 112), (22, 112)], hexa('e4e8f2'), sombra=0.22, luz=0.2, d=2.0)
    for k in range(5):
        c.rect(28 + k * 15, 94, 38 + k * 15, 104, hexa('4a6fb0'), r=1.2)
    c.rect(22, 106, 106, 110, ROJO)
    c.cuerpo([(8, 32), (52, 32), (52, 14), (8, 14)], hexa('b9b3a6'), sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo_elip(30, 24, 8, col=hexa('2f5aa8'), sombra=0.0, luz=0.0)
    c.linea([(25, 29), (25, 19), (30, 25), (35, 19), (35, 29)], 2.2, BLANCO)
    for k in range(4):
        c.poly([(68 + k * 8, 46 + k * 4), (76 + k * 8, 46 + k * 4), (76 + k * 8, 50 + k * 4), (68 + k * 8, 50 + k * 4)], hexa('c9c3b6'))


def tunel_ferroviario(c):
    c.cuerpo([(0, 120), (28, 34), (64, 12), (100, 34), (128, 120)], hexa('8a8f9c'), sombra=0.26, luz=0.25, d=3.4)
    c.poly([(54, 22), (64, 12), (74, 22), (68, 26), (64, 24), (58, 28)], BLANCO)
    cuadro(c, 30, 62, 98, 120, PIEDRA_C, d=2.8)
    pts = [(38, 120)] + [(64 - 26 * math.cos(math.radians(a)), 92 - 28 * math.sin(math.radians(a))) for a in range(0, 181, 12)] + [(90, 120)]
    c.poly(pts, hexa('2d2a35'))
    c.cuerpo([(48, 120), (80, 120), (80, 86), (72, 78), (56, 78), (48, 86)], hexa('c24a3a'), sombra=0.24, luz=0.2, d=2.0)
    c.rect(54, 86, 74, 98, hexa('a6d0f2'), r=1.5)
    c.punto(54, 108, 3.4, AMARILLO_V)
    c.punto(74, 108, 3.4, AMARILLO_V)
    c.poly([(30, 120), (98, 120), (110, 128), (18, 128)], hexa('6a5a48'))
    for k in range(5):
        c.linea([(20 + k * 22, 126), (28 + k * 20, 120)], 3, MADERA_O)


def canal_interoceanico(c):
    cuadro(c, 0, 0, 128, 128, hexa('7ec36a'), sombra=0.0, luz=0.0)
    c.cuerpo([(0, 0), (40, 0), (40, 38), (0, 38)], hexa('2f6fc8'), sombra=0.2, luz=0.15, d=2.2)
    c.cuerpo([(88, 90), (128, 90), (128, 128), (88, 128)], hexa('2f6fc8'), sombra=0.2, luz=0.15, d=2.2)
    c.linea([(30, 20), (64, 52), (64, 78), (98, 108)], 22, hexa('5aa8e6'))
    c.linea([(30, 20), (64, 52), (64, 78), (98, 108)], 14, hexa('7ac4f2'))
    c.cuerpo([(48, 56), (86, 56), (78, 72), (56, 72)], hexa('8a4a2a'), sombra=0.24, luz=0.2, d=2.0)
    c.cuerpo([(56, 40), (78, 40), (78, 56), (56, 56)], hexa('f1ede2'), sombra=0.2, luz=0.1, d=1.6)
    c.rect(66, 28, 72, 40, ROJO)
    for k in range(5):
        c.rect(52 + k * 7, 58, 56 + k * 7, 64, hexa('d8c49a'))
    c.cuerpo([(8, 74), (30, 74), (30, 96), (8, 96)], hexa('c8b784'), sombra=0.2, luz=0.2, d=1.4)
    arbol(c, 20, 118, 9)
    arbol(c, 100, 36, 9)


def transporte_urbano_masivo(c):
    suelo(c, y=112, grosor=8, col=hexa('7c8497'))
    c.linea([(4, 28), (124, 28)], 2.4, hexa('3d3a46'))
    c.linea([(64, 28), (64, 40)], 3, hexa('3d3a46'))
    c.linea([(52, 40), (76, 40)], 4, hexa('3d3a46'))
    c.cuerpo([(8, 112), (8, 52), (14, 44), (114, 44), (120, 52), (120, 112)], hexa('d84a3a'), sombra=0.24, luz=0.22, d=3.0)
    c.rect(8, 82, 120, 90, hexa('fbf6ee'))
    for k in range(5):
        c.rect(16 + k * 21, 54, 32 + k * 21, 74, hexa('a6d0f2'), r=2)
    c.rect(8, 90, 120, 94, hexa('962f27'))
    for x in (30, 98):
        c.cuerpo_elip(x, 106, 8, col=hexa('2d2a30'), sombra=0.0, luz=0.2, d=1.6)
        c.elip(x, 106, 3.4, 3.4, ACERO)
    c.punto(14, 98, 3.0, AMARILLO_V)
    c.punto(114, 98, 3.0, AMARILLO_V)


def aeropuerto(c):
    suelo(c, y=108, grosor=12, col=hexa('7c8497'))
    c.linea([(4, 118), (124, 118)], 3, hexa('f6efdc'))
    for x in range(10, 122, 22):
        c.rect(x, 114, x + 10, 118, hexa('f6efdc'))
    cuadro(c, 94, 40, 106, 108, hexa('e4e8f2'), d=2.4)
    c.cuerpo([(88, 40), (112, 40), (106, 24), (94, 24)], hexa('7aa8f0'), sombra=0.2, luz=0.3, d=2.0)
    c.rect(86, 20, 114, 26, hexa('4a4f5c'), r=1.5)
    c.linea([(100, 20), (100, 10)], 2.4, ROJO)
    c.cuerpo(spline([(10, 82), (24, 70), (70, 66), (84, 74), (70, 84), (24, 88)]), hexa('f1f4fb'), sombra=0.24, luz=0.2, d=2.4)
    c.cuerpo([(40, 78), (64, 78), (38, 52), (30, 54)], hexa('d8dde8'), sombra=0.24, luz=0.2, d=2.0)
    c.cuerpo([(40, 76), (64, 76), (40, 102), (32, 100)], hexa('d8dde8'), sombra=0.24, luz=0.2, d=2.0)
    c.poly([(12, 80), (6, 62), (18, 76)], hexa('3a62b8'))
    for k in range(5):
        c.punto(34 + k * 8, 76, 1.8, hexa('4a6fb0'))


def autopista(c):
    cuadro(c, 0, 0, 128, 128, hexa('8bc46e'), sombra=0.0, luz=0.0)
    c.cuerpo([(0, 70), (128, 70), (128, 112), (0, 112)], hexa('5a5f6e'), sombra=0.2, luz=0.2, d=2.6)
    for x in range(4, 128, 20):
        c.rect(x, 90, x + 10, 93, hexa('f6efdc'))
    c.rect(0, 70, 128, 73, hexa('f2d680'))
    c.rect(0, 109, 128, 112, hexa('f2d680'))
    c.cuerpo([(0, 38), (128, 38), (128, 54), (0, 54)], hexa('7c8497'), sombra=0.22, luz=0.25, d=2.4)
    for x in (24, 64, 104):
        cuadro(c, x - 5, 54, x + 5, 70, hexa('9aa0ae'), d=2.0)
    c.rect(0, 36, 128, 40, hexa('c9c3b6'))
    c.cuerpo([(14, 78), (40, 78), (38, 68), (18, 68)], hexa('3f7fd0'), sombra=0.22, luz=0.25, d=1.6)
    c.cuerpo([(70, 100), (98, 100), (96, 90), (74, 90)], hexa('e0605a'), sombra=0.22, luz=0.25, d=1.6)
    c.cuerpo([(100, 82), (118, 82), (116, 74), (102, 74)], hexa('f2b134'), sombra=0.22, luz=0.25, d=1.4)
    for (x, y) in ((22, 80), (36, 80), (78, 102), (92, 102)):
        c.punto(x, y, 3, hexa('2d2a30'))


def puente_atirantado(c):
    _agua_fondo(c, 90)
    c.cuerpo([(0, 70), (128, 70), (128, 78), (0, 78)], ACERO, sombra=0.2, luz=0.3, d=2.0)
    c.cuerpo([(56, 10), (72, 10), (76, 100), (52, 100)], hexa('c9c3b6'), sombra=0.26, luz=0.25, d=2.6)
    c.rect(52, 6, 76, 14, hexa('a9a396'), r=1.5)
    for k in range(6):
        y = 18 + k * 8
        c.linea([(64, y), (6 + k * 8, 70)], 1.8, hexa('e4eaf8'))
        c.linea([(64, y), (122 - k * 8, 70)], 1.8, hexa('e4eaf8'))
    c.rect(0, 66, 128, 71, hexa('4a4f5c'))


def tunel_submarino(c):
    cuadro(c, 0, 0, 128, 40, CIELO, sombra=0.0, luz=0.0)
    c.cuerpo([(0, 36), (128, 36), (128, 128), (0, 128)], hexa('3f86d8'), sombra=0.0, luz=0.0)
    olas(c, 40, 4, 124, AGUA_C, 7)
    c.cuerpo([(0, 108), (128, 108), (128, 128), (0, 128)], hexa('8f7e66'), sombra=0.2, luz=0.2, d=2.4)
    c.cuerpo(spline([(4, 96), (4, 76), (16, 64), (112, 64), (124, 76), (124, 96), (112, 108), (16, 108)]), hexa('c9c3b6'), sombra=0.25, luz=0.25, d=3.0)
    c.cuerpo(spline([(12, 94), (12, 78), (20, 71), (108, 71), (116, 78), (116, 94), (108, 101), (20, 101)]), hexa('3d3a46'), sombra=0.0, luz=0.0)
    c.cuerpo([(34, 94), (74, 94), (70, 82), (40, 82)], hexa('e0605a'), sombra=0.22, luz=0.25, d=1.6)
    c.punto(44, 96, 3.4, hexa('1d1a24'))
    c.punto(66, 96, 3.4, hexa('1d1a24'))
    c.rect(86, 86, 108, 92, hexa('f2d680'))
    for k in range(7):
        c.punto(10 + k * 18, 76, 1.6, AMARILLO_V)
    c.cuerpo([(8, 14), (36, 14), (36, 30), (8, 30)], hexa('8a4a2a'), sombra=0.22, luz=0.2, d=1.6)


# ───────────── agua y energía ─────────────
def rayo(c, x, y, k=1.0, col=LLAMA_V):
    pts = [(x + 2 * k, y - 12 * k), (x - 7 * k, y + 2 * k), (x - 1 * k, y + 2 * k), (x - 4 * k, y + 14 * k), (x + 7 * k, y - 2 * k), (x + 1 * k, y - 2 * k)]
    c.cuerpo(pts, col, sombra=0.2, luz=0.3, d=1.4)


def drenaje_urbano(c):
    cuadro(c, 0, 0, 128, 128, hexa('8a8f9a'), sombra=0.0, luz=0.0)
    c.cuerpo([(0, 70), (128, 70), (128, 96), (0, 96)], hexa('b9bdc6'), sombra=0.2, luz=0.2, d=2.4)
    c.rect(0, 70, 128, 74, hexa('d8dbe2'))
    c.cuerpo([(22, 76), (106, 76), (106, 92), (22, 92)], hexa('4a4f5c'), sombra=0.0, luz=0.0)
    for k in range(8):
        c.rect(26 + k * 10, 78, 31 + k * 10, 90, hexa('2d2a35'), r=1)
    c.cuerpo([(0, 96), (128, 96), (128, 128), (0, 128)], hexa('6a5a48'), sombra=0.2, luz=0.2, d=2.4)
    c.cuerpo([(30, 96), (98, 96), (98, 118), (30, 118)], AGUA, sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo_elip(64, 52, 14, 20, col=AGUA, sombra=0.2, luz=0.35, d=2.0)
    c.poly(gota(64, 52, 12, 24), AGUA)
    c.linea([(34, 108), (94, 108)], 2.4, AGUA_C)


def presas_gravedad(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    c.cuerpo([(0, 54), (60, 54), (60, 120), (0, 120)], hexa('3f86d8'), sombra=0.2, luz=0.15, d=2.4)
    olas(c, 70, 4, 56, hexa('7ab8f0'), 3)
    c.cuerpo([(58, 40), (82, 40), (112, 122), (58, 122)], HORMIGON, sombra=0.26, luz=0.25, d=3.2)
    for yy in (56, 76, 96):
        c.linea([(60, yy), (60 + (yy - 40) * 0.5, yy)], 1.4, HORMIGON_O)
    c.cuerpo([(100, 98), (128, 98), (128, 122), (106, 122)], hexa('8bc46e'), sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo([(90, 98), (128, 110), (128, 122), (100, 122)], AGUA, sombra=0.0, luz=0.2, d=1.6)
    c.cuerpo([(0, 46), (20, 46), (20, 54), (0, 54)], hexa('8bc46e'), sombra=0.2, luz=0.2, d=1.6)
    c.linea([(66, 40), (66, 30)], 2.4, ACERO_O)
    c.linea([(76, 40), (76, 30)], 2.4, ACERO_O)


def alcantarillado(c):
    cuadro(c, 0, 0, 128, 128, hexa('6a5a48'), sombra=0.0, luz=0.0)
    c.cuerpo([(0, 0), (128, 0), (128, 34), (0, 34)], hexa('9a9fa8'), sombra=0.2, luz=0.2, d=2.4)
    c.cuerpo_elip(64, 26, 22, 7, col=hexa('4a4f5c'), sombra=0.2, luz=0.3, d=1.8)
    for k in range(4):
        c.linea([(48 + k * 10, 24), (52 + k * 10, 29)], 1.4, hexa('2d2a35'))
    c.linea([(64, 34), (64, 62)], 14, hexa('b9bdc6'))
    c.linea([(64, 62), (64, 62)], 14, hexa('b9bdc6'))
    c.linea([(8, 80), (120, 80)], 26, hexa('b9bdc6'))
    c.linea([(8, 80), (120, 80)], 18, hexa('4a4f5c'))
    c.linea([(8, 86), (120, 86)], 7, hexa('7a9a6a'))
    c.linea([(24, 100), (24, 124)], 14, hexa('b9bdc6'))
    c.linea([(24, 100), (24, 124)], 8, hexa('4a4f5c'))
    c.linea([(100, 100), (100, 124)], 14, hexa('b9bdc6'))
    c.linea([(100, 100), (100, 124)], 8, hexa('4a4f5c'))
    c.cuerpo_elip(64, 80, 9, col=hexa('d8dbe2'), sombra=0.2, luz=0.3, d=1.6)


def acueducto(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    suelo(c, y=110, grosor=10, x0=0, x1=128)
    c.cuerpo([(0, 30), (128, 30), (128, 46), (0, 46)], hexa('d6c9a8'), sombra=0.22, luz=0.2, d=2.4)
    c.rect(4, 26, 124, 36, AGUA, r=2)
    c.rect(4, 26, 124, 29, AGUA_C)
    for fila, (y0, y1, n) in enumerate(((46, 76, 6), (74, 110, 5))):
        if fila == 0:
            cuadro(c, 0, 46, 128, 76, hexa('d6c9a8'), d=2.6)
            for k in range(6):
                x = 6 + k * 20.5
                pts = [(x, 76)] + [(x + 8 - 8 * math.cos(math.radians(a)), 62 - 14 * math.sin(math.radians(a))) for a in range(0, 181, 15)] + [(x + 16, 76)]
                c.poly(pts, CIELO)
        else:
            for k in range(0, 6):
                x = 0 + k * 26
                cuadro(c, x, 76, x + 8, 110, hexa('cdbf9a'), d=2.0)
            for k in range(5):
                x = 8 + k * 26
                pts = [(x, 110)] + [(x + 9 - 9 * math.cos(math.radians(a)), 94 - 18 * math.sin(math.radians(a))) for a in range(0, 181, 15)] + [(x + 18, 110)]
                c.poly(pts, CIELO)
    cuadro(c, 0, 74, 128, 80, hexa('c0b28c'), d=1.6)


def central_termoelectrica(c):
    suelo(c, y=112, grosor=8, col=hexa('7c8497'))
    cuadro(c, 6, 66, 76, 112, hexa('9aa6ba'), d=3.0)
    c.poly([(6, 66), (20, 54), (62, 54), (76, 66)], hexa('7c8aa2'))
    for k in range(5):
        c.rect(14 + k * 12, 76, 22 + k * 12, 100, hexa('d8ecff'), r=1)
    for (x, alto) in ((90, 82), (110, 92)):
        c.cuerpo([(x - 10, 112), (x - 6, 112 - alto), (x + 6, 112 - alto), (x + 10, 112)], hexa('c9c3b6'), sombra=0.25, luz=0.2, d=2.4)
        c.rect(x - 7, 112 - alto - 4, x + 7, 112 - alto + 3, ROJO)
        humo(c, x, 112 - alto - 6, 3)
    rayo(c, 40, 40, 1.3)


def red_electrica(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    suelo(c, y=112, grosor=8)
    c.linea([(64, 112), (64, 24)], 6, MADERA_O)
    c.linea([(34, 40), (94, 40)], 5, MADERA)
    c.linea([(42, 58), (86, 58)], 4, MADERA)
    for (x, y) in ((36, 40), (92, 40), (44, 58), (84, 58)):
        c.cuerpo_elip(x, y + 3, 3.4, 5, col=hexa('7ac0c8'), sombra=0.2, luz=0.3, d=1.2)
    for yy, ys in ((43, 70), (43, 86)):
        pass
    for (x0, y0, x1, y1) in ((36, 46, 4, 70), (36, 46, 124, 70), (92, 46, 124, 70), (44, 64, 4, 88), (84, 64, 124, 88)):
        c.linea(spline([(x0, y0), ((x0 + x1) / 2, max(y0, y1) + 8), (x1, y1)], cerrada=False), 1.6, hexa('2d2a35'))
    rayo(c, 98, 22, 1.2)


def central_hidroelectrica(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    c.cuerpo([(0, 40), (50, 40), (50, 120), (0, 120)], hexa('3f86d8'), sombra=0.2, luz=0.15, d=2.4)
    olas(c, 60, 4, 46, hexa('7ab8f0'), 3)
    c.cuerpo([(48, 34), (70, 34), (98, 122), (48, 122)], HORMIGON, sombra=0.26, luz=0.25, d=3.2)
    cuadro(c, 76, 78, 124, 122, hexa('b8c4dc'), d=2.8)
    c.poly([(72, 78), (88, 62), (118, 62), (128, 78)], hexa('7c8aa2'))
    for k in range(3):
        c.rect(84 + k * 12, 88, 92 + k * 12, 108, hexa('d8ecff'), r=1)
    c.cuerpo([(100, 122), (128, 122), (128, 110), (104, 116)], AGUA, sombra=0.0, luz=0.2, d=1.4)
    rayo(c, 20, 22, 1.2)
    c.linea([(112, 62), (112, 40), (124, 30)], 1.8, hexa('2d2a35'))


def presas_arco_hormigon(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    c.cuerpo([(30, 30), (98, 30), (98, 50), (30, 50)], hexa('3f86d8'), sombra=0.2, luz=0.15, d=2.0)
    olas(c, 38, 4, 34, hexa('7ab8f0'), 4)
    c.cuerpo([(0, 18), (34, 30), (42, 128), (0, 128)], hexa('9a8268'), sombra=0.26, luz=0.25, d=3.0)
    c.cuerpo([(94, 30), (128, 18), (128, 128), (86, 128)], hexa('9a8268'), sombra=0.26, luz=0.25, d=3.0)
    c.cuerpo(spline([(32, 46), (64, 54), (96, 46), (90, 112), (64, 118), (38, 112)]), HORMIGON, sombra=0.26, luz=0.3, d=3.4)
    for yy in (62, 76, 90, 104):
        c.linea(spline([(36 + (yy - 46) * 0.05, yy), (64, yy + 7), (92 - (yy - 46) * 0.05, yy)], cerrada=False), 1.5, HORMIGON_O)
    c.linea([(64, 54), (64, 118)], 1.4, HORMIGON_O)
    c.cuerpo([(40, 118), (88, 118), (88, 128), (40, 128)], AGUA, sombra=0.0, luz=0.2, d=1.4)
    c.linea([(52, 123), (76, 123)], 2.0, AGUA_C)


def red_alta_tension(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    for (cx, esc) in ((38, 1.0), (96, 0.78)):
        a = 22 * esc
        yb = 112
        yt = 112 - 96 * esc
        c.linea([(cx - a, yb), (cx - 5 * esc, yt + 14 * esc), (cx, yt)], 3.4, hexa('5d6a86'))
        c.linea([(cx + a, yb), (cx + 5 * esc, yt + 14 * esc), (cx, yt)], 3.4, hexa('5d6a86'))
        for k in range(1, 5):
            f = k / 5.0
            yy = yb - (yb - yt) * f
            half = a * (1 - f) + 5 * esc * f
            c.linea([(cx - half, yy), (cx + half, yy)], 2.2, hexa('4a566e'))
            if k < 4:
                half2 = a * (1 - (k + 1) / 5.0) + 5 * esc * (k + 1) / 5.0
                yy2 = yb - (yb - yt) * (k + 1) / 5.0
                c.linea([(cx - half, yy), (cx + half2, yy2)], 1.6, hexa('4a566e'))
        for (dy, w) in ((22, 26), (38, 20)):
            c.linea([(cx - w * esc, yt + dy * esc), (cx + w * esc, yt + dy * esc)], 3.6, hexa('5d6a86'))
    for (x0, y0, x1, y1) in ((12, 38, 38, 38), (38, 38, 96, 54), (96, 54, 124, 48)):
        pass
    for k, (dy0, dy1) in enumerate(((22, 38), (38, 38))):
        pass
    c.linea(spline([(12, 56), (38, 40), (66, 50), (96, 56), (124, 58)], cerrada=False), 1.6, hexa('2d2a35'))
    c.linea(spline([(12, 66), (38, 58), (66, 70), (96, 68), (124, 70)], cerrada=False), 1.6, hexa('2d2a35'))
    rayo(c, 64, 18, 1.1)


def planta_depuradora(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    for (cx, r) in ((36, 28), (92, 28)):
        c.cuerpo_elip(cx, 88, r, 12, col=hexa('b9bdc6'), sombra=0.22, luz=0.3, d=2.4)
        c.cuerpo([(cx - r, 88), (cx + r, 88), (cx + r, 104), (cx - r, 104)], hexa('9aa0ae'), sombra=0.24, luz=0.2, d=2.2)
        c.cuerpo_elip(cx, 104, r, 12, col=hexa('9aa0ae'), sombra=0.0, luz=0.0)
        c.elip(cx, 88, r - 4, 9, AGUA)
        c.elip(cx - 6, 86, 8, 3, AGUA_C)
        c.linea([(cx, 88), (cx + r - 6, 84)], 2.0, hexa('4a4f5c'))
    c.linea([(36, 100), (36, 108), (92, 108), (92, 100)], 5, hexa('7c8497'))
    c.poly(gota(64, 52, 22, 46), AGUA)
    c.cuerpo(gota(64, 52, 20, 42), AGUA, sombra=0.26, luz=0.4, d=2.6)
    c.elip(58, 48, 5, 8, (255, 255, 255, 120), -20)
    c.cuerpo(estrella(64, 56, 7, 3, 4), hexa('f6efdc'), sombra=0.0, luz=0.0)


def gas_natural(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    c.cuerpo_elip(46, 72, 36, col=hexa('d8dde8'), sombra=0.28, luz=0.3, d=3.4)
    c.linea([(30, 100), (26, 112)], 4, ACERO_O)
    c.linea([(62, 100), (66, 112)], 4, ACERO_O)
    c.linea([(10, 72), (82, 72)], 2.4, hexa('b8c0d4'))
    c.linea(spline([(20, 54), (46, 46), (72, 54)], cerrada=False), 2.0, hexa('b8c0d4'))
    c.linea([(80, 84), (118, 84), (118, 100)], 6, hexa('7c8497'))
    c.linea([(80, 84), (118, 84), (118, 100)], 3, hexa('b8c0d4'))
    c.rect(106, 98, 128, 112, hexa('c24a3a'), r=2)
    c.cuerpo([(96, 54), (112, 54), (112, 84), (96, 84)], hexa('9aa6ba'), sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo(spline([(104, 12), (116, 28), (118, 42), (104, 52), (90, 42), (92, 28)]), hexa('f57f2a'), sombra=0.2, luz=0.2, d=2.2)
    c.cuerpo(spline([(104, 26), (111, 38), (104, 48), (97, 38)]), LLAMA_V, sombra=0.0, luz=0.3, d=1.4)


def central_nuclear(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    for (x, alto) in ((32, 76), (82, 66)):
        c.cuerpo([(x - 22, 112), (x - 12, 112 - alto * 0.45), (x - 14, 112 - alto), (x + 14, 112 - alto), (x + 12, 112 - alto * 0.45), (x + 22, 112)], hexa('d4d0c4'), sombra=0.26, luz=0.2, d=3.0)
        c.cuerpo_elip(x - 4, 112 - alto - 8, 12, 8, col=hexa('f1f4fb'), sombra=0.1, luz=0.4, d=1.6)
        c.cuerpo_elip(x + 8, 112 - alto - 16, 9, 6, col=hexa('f1f4fb'), sombra=0.1, luz=0.4, d=1.6)
    c.cuerpo(spline([(76, 112), (78, 90), (92, 78), (110, 78), (124, 90), (126, 112)]), hexa('b8c4dc'), sombra=0.24, luz=0.3, d=2.8)
    c.cuerpo_elip(101, 96, 11, col=hexa('f5c518'), sombra=0.2, luz=0.2, d=1.6)
    for k in range(3):
        a0 = -90 + k * 120
        c.poly([(101, 96)] + [(101 + 10 * math.cos(math.radians(a0 + d)), 96 + 10 * math.sin(math.radians(a0 + d))) for d in range(-30, 31, 10)], hexa('2d2a30'))
    c.elip(101, 96, 2.4, 2.4, hexa('2d2a30'))


def parque_eolico(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    c.cuerpo(spline([(0, 128), (0, 92), (36, 80), (80, 90), (128, 76), (128, 128)]), hexa('7ec36a'), sombra=0.24, luz=0.25, d=3.0)
    for (x, y, k) in ((34, 90, 1.0), (88, 92, 0.8), (116, 82, 0.55)):
        c.cuerpo([(x - 3 * k, y), (x + 3 * k, y), (x + 1.4 * k, y - 62 * k), (x - 1.4 * k, y - 62 * k)], hexa('f1f4fb'), sombra=0.25, luz=0.1, d=1.6)
        for a in (-90, 30, 150):
            pts = [(x, y - 62 * k)] + [(x + 4 * math.cos(math.radians(a + 90)) * k, y - 62 * k + 4 * math.sin(math.radians(a + 90)) * k)]
            ex, ey = x + 36 * k * math.cos(math.radians(a)), y - 62 * k + 36 * k * math.sin(math.radians(a))
            nx, ny = -math.sin(math.radians(a)), math.cos(math.radians(a))
            c.cuerpo([(x + nx * 2.4 * k, y - 62 * k + ny * 2.4 * k), (ex, ey), (x - nx * 2.4 * k, y - 62 * k - ny * 2.4 * k)], hexa('f1f4fb'), sombra=0.2, luz=0.0, d=1.4)
        c.cuerpo_elip(x, y - 62 * k, 4.4 * k, col=hexa('d8dde8'), sombra=0.2, luz=0.2, d=1.2)
    rayo(c, 14, 30, 1.0)


def energia_solar_comercial(c):
    cuadro(c, 0, 0, 128, 128, CIELO, sombra=0.0, luz=0.0)
    suelo(c, y=100, grosor=28, col=hexa('c8b784'), x0=0, x1=128)
    c.cuerpo_elip(96, 28, 18, col=hexa('ffd45c'), sombra=0.22, luz=0.4, d=2.4)
    for k in range(8):
        a = math.radians(k * 45)
        c.linea([(96 + 22 * math.cos(a), 28 + 22 * math.sin(a)), (96 + 30 * math.cos(a), 28 + 30 * math.sin(a))], 3.4, hexa('ffd45c'))
    for fila, (y0, w) in enumerate(((60, 80), (78, 100))):
        x0 = 64 - w / 2
        c.cuerpo([(x0 + 10, y0), (x0 + w - 10, y0), (x0 + w, y0 + 20), (x0, y0 + 20)], hexa('2f4a8a'), sombra=0.24, luz=0.3, d=2.4)
        for k in range(1, 5):
            xx = x0 + 10 + (w - 20) * k / 5.0
            c.linea([(xx, y0), (xx - 10 + 20 * k / 5.0 - (k - 2.5) * 0, y0 + 20)], 1.4, hexa('7a9ae0'))
        c.linea([(x0 + 5, y0 + 10), (x0 + w - 5, y0 + 10)], 1.4, hexa('7a9ae0'))
    rayo(c, 28, 34, 1.1)


# ───────────── educación, cultura y ciencia ─────────────
def libro(c, x, y, w, h, col, lomo=None):
    c.cuerpo([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], col, sombra=0.22, luz=0.25, d=1.8)
    c.rect(x + 2, y + 2, x + 4, y + h - 2, lomo or claro(col, 0.4))


def escuelas_escribas(c):
    suelo(c, y=112, grosor=8, col=hexa('c8b784'))
    c.cuerpo(spline([(18, 100), (14, 40), (24, 22), (86, 22), (96, 40), (92, 100), (80, 108), (30, 108)]), hexa('d9b87a'), sombra=0.24, luz=0.25, d=3.0)
    for k, w in enumerate((46, 52, 40, 48, 34)):
        y = 36 + k * 13
        for j in range(int(w / 7)):
            x = 30 + j * 7
            c.poly([(x, y), (x + 5, y + 3), (x, y + 7)], hexa('7a5a30'))
            c.linea([(x - 1, y + 3), (x + 4, y + 3)], 1.4, hexa('7a5a30'))
    c.linea([(104, 108), (116, 54)], 5, MADERA_O)
    c.poly([(112, 56), (122, 52), (116, 46)], hexa('9c7440'))
    c.cuerpo_elip(34, 112, 14, 4, col=hexa('a8946a'), sombra=0.0, luz=0.0)


def academias_filosoficas(c):
    suelo(c, y=112, grosor=8, col=hexa('d8d2c0'))
    c.cuerpo([(14, 52), (64, 18), (114, 52)], hexa('e4ddc8'), sombra=0.2, luz=0.2, d=2.6)
    cuadro(c, 12, 50, 116, 58, hexa('efe9d6'), d=2.0)
    for k in range(5):
        columna(c, 22 + k * 20, 62, 104, 9)
    c.cuerpo([(44, 80), (84, 80), (84, 100), (44, 100)], hexa('f6efdc'), sombra=0.16, luz=0.0, d=1.6)
    c.cuerpo(spline([(48, 82), (60, 90), (48, 98)]), hexa('d9c493'), sombra=0.0, luz=0.0)
    for yy in (86, 91, 96):
        c.linea([(52, yy), (78, yy)], 1.4, hexa('8a7a5a'))
    c.cuerpo_elip(64, 38, 6, col=ORO, sombra=0.2, luz=0.3, d=1.4)


def biblioteca(c):
    suelo(c, y=112, grosor=8, col=hexa('b9b3a6'))
    cuadro(c, 6, 28, 122, 112, hexa('8a5a3a'), d=3.2)
    for fila in range(3):
        c.rect(12, 36 + fila * 26, 116, 38 + fila * 26 + 22, hexa('5a3a22'))
        x = 14
        k = 0
        cols = (ROJO, AZUL2, VERDE2, ORO2, MORADO, hexa('c0763a'), hexa('3f9e9e'))
        while x < 112:
            w = 6 + (k * 3) % 5
            h = 16 + (k * 7) % 6
            c.cuerpo([(x, 58 + fila * 26 - h), (x + w, 58 + fila * 26 - h), (x + w, 58 + fila * 26), (x, 58 + fila * 26)], cols[(k + fila) % len(cols)], sombra=0.22, luz=0.2, d=1.2)
            x += w + 1
            k += 1
        c.rect(12, 58 + fila * 26, 116, 61 + fila * 26, hexa('7a4f2a'))
    c.rect(2, 22, 126, 30, hexa('6a4528'), r=2)


def monasterios_copistas(c):
    suelo(c, y=112, grosor=8)
    cuadro(c, 6, 66, 90, 112, hexa('d9d3c4'), d=2.8)
    techo(c, 6, 90, 67, 36, hexa('b8583c'), alero=5)
    for k in range(5):
        pts = [(14 + k * 15, 110)] + [(14 + k * 15 + 5 - 5 * math.cos(math.radians(a)), 94 - 8 * math.sin(math.radians(a))) for a in range(0, 181, 30)] + [(24 + k * 15, 110)]
        c.poly(pts, hexa('4a3a2a'))
    cuadro(c, 92, 42, 118, 112, hexa('cdc6b4'), d=2.6)
    c.poly([(90, 42), (105, 20), (120, 42)], hexa('5f6c8c'))
    c.rect(100, 50, 110, 62, hexa('3d3946'), r=1)
    c.linea([(105, 20), (105, 10)], 2.4, ORO2)
    c.linea([(100, 14), (110, 14)], 2.4, ORO2)
    c.cuerpo([(20, 40), (56, 40), (60, 62), (16, 62)], hexa('f6efdc'), sombra=0.16, luz=0.1, d=1.6)
    c.linea([(38, 40), (38, 62)], 1.4, hexa('b0a078'))
    c.linea([(70, 20), (50, 52)], 3, hexa('f6efdc'))
    c.poly([(48, 56), (52, 50), (54, 54)], hexa('2d2a35'))


def escuelas_monasticas(c):
    suelo(c, y=112, grosor=8)
    cuadro(c, 8, 72, 78, 112, hexa('d6cdb4'), d=2.8)
    techo(c, 8, 78, 73, 46, hexa('8d6a4a'), alero=5)
    cuadro(c, 82, 28, 112, 112, hexa('cdc6b4'), d=2.8)
    c.poly([(80, 28), (97, 6), (114, 28)], hexa('b8583c'))
    c.poly([(90, 40), (104, 40), (104, 58), (97, 62), (90, 58)], hexa('3d3946'))
    c.cuerpo_elip(97, 50, 5, 6, col=ORO, sombra=0.2, luz=0.3, d=1.2)
    puerta(c, 43, 112, 16, 24)
    libro(c, 20, 88, 14, 10, hexa('c24a3a'))
    libro(c, 52, 90, 14, 8, hexa('3f7fd0'))
    ventana(c, 24, 80, 8, 8, hexa('4a3a2a'))


def observatorios_astronomicos(c):
    cuadro(c, 0, 0, 128, 128, hexa('1f2a52'), sombra=0.0, luz=0.0)
    for (x, y, r) in ((14, 18, 2.4), (40, 10, 1.8), (100, 16, 2.6), (116, 40, 1.8), (22, 50, 1.8), (80, 8, 1.8)):
        c.cuerpo(estrella(x, y, r * 2, r * 0.8, 4, 0), hexa('ffe28a'), sombra=0.0, luz=0.0)
    c.cuerpo_elip(100, 44, 9, col=hexa('f1ede2'), sombra=0.22, luz=0.2, d=1.8)
    c.elip(104, 41, 8, 8, hexa('1f2a52'))
    suelo(c, y=112, grosor=8, col=hexa('5a7a5a'))
    cuadro(c, 22, 76, 106, 112, hexa('d9d3c4'), d=2.8)
    c.cuerpo(spline([(22, 76), (24, 56), (44, 42), (64, 38), (84, 42), (104, 56), (106, 76)]), hexa('e4e8f2'), sombra=0.26, luz=0.3, d=3.0)
    c.poly([(60, 38), (70, 38), (74, 76), (56, 76)], hexa('1f2a52'))
    c.linea([(64, 66), (92, 28)], 8, hexa('9aa6ba'))
    c.linea([(64, 66), (92, 28)], 4, hexa('d8dde8'))
    c.rect(88, 22, 98, 32, hexa('4a4f5c'), r=1.5)
    puerta(c, 64, 112, 14, 22)


def casa_de_traduccion(c):
    suelo(c, y=112, grosor=8, col=hexa('d8d2c0'))
    c.cuerpo([(8, 40), (60, 48), (60, 100), (8, 92)], hexa('f6efdc'), sombra=0.18, luz=0.15, d=2.2)
    c.cuerpo([(120, 40), (68, 48), (68, 100), (120, 92)], hexa('efe3c8'), sombra=0.18, luz=0.15, d=2.2)
    for k in range(5):
        c.linea([(14, 54 + k * 8), (52, 58 + k * 8)], 1.6, hexa('7a869b'))
    for k in range(5):
        c.linea([(76, 58 + k * 8), (114, 54 + k * 8)], 1.6, hexa('9c7440'))
    c.cuerpo_elip(64, 28, 16, col=hexa('3f7fd0'), sombra=0.24, luz=0.3, d=2.0)
    c.linea([(56, 28), (72, 28)], 3, BLANCO)
    c.poly([(68, 23), (76, 28), (68, 33)], BLANCO)
    c.linea([(60, 28), (56, 28)], 3, BLANCO)
    c.poly([(60, 23), (52, 28), (60, 33)], BLANCO)
    c.rect(4, 96, 124, 104, hexa('8a5a3a'), r=2)


def madrasas_escuelas(c):
    suelo(c, y=112, grosor=8, col=hexa('d8d2c0'))
    cuadro(c, 22, 66, 92, 112, hexa('efe3c8'), d=3.0)
    c.cuerpo(spline([(32, 66), (34, 44), (50, 28), (57, 24), (64, 28), (80, 44), (82, 66)]), hexa('3f9e9e'), sombra=0.26, luz=0.3, d=3.0)
    c.cuerpo([(52, 24), (62, 24), (57, 12)], hexa('2f7f7f'), sombra=0.0, luz=0.0)
    c.poly([(52, 28), (62, 28), (57, 8)], ORO2)
    cuadro(c, 96, 36, 108, 112, hexa('e4d8b8'), d=2.2)
    c.rect(94, 32, 110, 38, hexa('c4a864'), r=1.5)
    c.poly([(95, 32), (102, 14), (109, 32)], hexa('3f9e9e'))
    c.punto(102, 11, 2.2, ORO)
    for k in range(2):
        pts = [(34 + k * 28, 110)] + [(34 + k * 28 + 8 - 8 * math.cos(math.radians(a)), 88 - 12 * math.sin(math.radians(a))) for a in range(0, 181, 20)] + [(50 + k * 28, 110)]
        c.poly(pts, hexa('3a5a8a'))
    libro(c, 2, 96, 16, 14, hexa('3f7fd0'))
    c.rect(24, 62, 90, 68, hexa('c4a864'), r=1)


def universidades_medievales(c):
    suelo(c, y=112, grosor=8, col=hexa('b9b3a6'))
    cuadro(c, 10, 50, 118, 112, hexa('c9c2b0'), d=3.0)
    techo(c, 10, 118, 51, 24, hexa('5f6c8c'), alero=5)
    for k in range(4):
        x = 20 + k * 25
        c.poly([(x, 110), (x, 80), (x + 7, 66), (x + 14, 80), (x + 14, 110)], hexa('3d3946'))
    c.cuerpo([(36, 42), (92, 42), (64, 30)], hexa('2d2a35'), sombra=0.0, luz=0.0)
    c.cuerpo([(40, 10), (88, 10), (64, 0)], hexa('2d2a35'), sombra=0.0, luz=0.0)
    c.cuerpo([(44, 10), (84, 10), (84, 22), (44, 22)], hexa('2d2a35'), sombra=0.2, luz=0.3, d=1.4)
    c.cuerpo([(30, 14), (64, 4), (98, 14), (64, 24)], hexa('3d3a46'), sombra=0.2, luz=0.3, d=1.6)
    c.linea([(98, 14), (104, 24)], 1.8, ORO)
    c.punto(104, 26, 2.6, ORO)


def escuelas_traduccion(c):
    suelo(c, y=112, grosor=8, col=hexa('d8d2c0'))
    c.cuerpo([(6, 50), (60, 38), (60, 92), (6, 104)], hexa('d84a3a'), sombra=0.22, luz=0.25, d=2.2)
    c.cuerpo([(122, 50), (68, 38), (68, 92), (122, 104)], hexa('3f7fd0'), sombra=0.22, luz=0.25, d=2.2)
    c.linea([(14, 62), (52, 52)], 3, hexa('fbf6ee'))
    c.linea([(14, 74), (52, 64)], 3, hexa('fbf6ee'))
    c.linea([(14, 86), (40, 80)], 3, hexa('fbf6ee'))
    c.linea([(76, 54), (114, 64)], 3, hexa('fbf6ee'))
    c.linea([(76, 66), (114, 76)], 3, hexa('fbf6ee'))
    c.linea([(76, 78), (100, 84)], 3, hexa('fbf6ee'))
    c.cuerpo_elip(64, 24, 14, col=ORO, sombra=0.24, luz=0.3, d=2.0)
    c.linea([(56, 22), (72, 22)], 2.6, hexa('8a5a10'))
    c.poly([(68, 18), (75, 22), (68, 26)], hexa('8a5a10'))
    c.linea([(72, 28), (56, 28)], 2.6, hexa('8a5a10'))
    c.poly([(60, 24), (53, 28), (60, 32)], hexa('8a5a10'))


def academias_ciencias(c):
    suelo(c, y=112, grosor=8, col=hexa('d8d2c0'))
    cuadro(c, 12, 64, 116, 112, hexa('e4ddc8'), d=3.0)
    c.cuerpo([(8, 64), (64, 38), (120, 64)], hexa('c9c2b0'), sombra=0.2, luz=0.2, d=2.6)
    for k in range(4):
        columna(c, 22 + k * 24, 70, 108, 9)
    c.linea(elipse(64, 24, 20, 8) + [elipse(64, 24, 20, 8)[0]], 2.4, hexa('3f7fd0'))
    c.linea(elipse(64, 24, 20, 8, 60) + [elipse(64, 24, 20, 8, 60)[0]], 2.4, hexa('3f7fd0'))
    c.linea(elipse(64, 24, 20, 8, -60) + [elipse(64, 24, 20, 8, -60)[0]], 2.4, hexa('3f7fd0'))
    c.cuerpo_elip(64, 24, 5, col=ROJO, sombra=0.2, luz=0.3, d=1.2)
    c.cuerpo_elip(46, 92, 8, col=hexa('7ac0f0'), sombra=0.2, luz=0.3, d=1.4)


def academias_lengua(c):
    suelo(c, y=112, grosor=8, col=hexa('d8d2c0'))
    c.cuerpo(spline([(8, 30), (12, 14), (60, 12), (64, 30), (60, 46), (30, 48), (20, 60), (22, 46), (12, 44)]), hexa('3f7fd0'), sombra=0.24, luz=0.28, d=2.4)
    c.cuerpo(spline([(120, 56), (116, 40), (68, 38), (64, 56), (68, 72), (98, 74), (108, 86), (106, 72), (116, 70)]), hexa('f2b134'), sombra=0.24, luz=0.28, d=2.4)
    c.cuerpo([(22, 26), (30, 26), (36, 38), (30, 38), (29, 35), (23, 35), (22, 38), (16, 38)], BLANCO, sombra=0.0, luz=0.0)
    c.linea([(36, 22), (52, 22)], 3, BLANCO)
    c.linea([(36, 30), (48, 30)], 3, BLANCO)
    c.linea([(78, 52), (106, 52)], 3, hexa('7a5a10'))
    c.linea([(78, 60), (98, 60)], 3, hexa('7a5a10'))
    libro(c, 20, 84, 36, 26, hexa('8a4a2a'), hexa('f2d680'))
    libro(c, 62, 90, 40, 20, hexa('2f7f6f'), hexa('f2d680'))
    c.linea([(100, 98), (118, 76)], 3.6, hexa('f6efdc'))
    c.poly([(116, 80), (120, 72), (112, 76)], hexa('f6efdc'))


def museos_publicos(c):
    suelo(c, y=112, grosor=8, col=hexa('d8d2c0'))
    c.cuerpo([(8, 46), (64, 12), (120, 46)], hexa('e4ddc8'), sombra=0.2, luz=0.2, d=2.6)
    c.poly([(28, 44), (64, 22), (100, 44)], hexa('cfc8b2'))
    cuadro(c, 6, 44, 122, 52, hexa('efe9d6'), d=2.0)
    for k in range(5):
        columna(c, 14 + k * 22, 56, 102, 10)
    cuadro(c, 4, 102, 124, 112, hexa('d1c9b2'), d=2.0)
    c.cuerpo([(52, 50), (76, 50), (76, 66), (52, 66)], hexa('7aa8f0'), sombra=0.0, luz=0.0)
    c.rect(54, 56, 74, 62, hexa('4a6fb0'))
    c.cuerpo(spline([(58, 100), (54, 90), (60, 80), (68, 80), (74, 90), (70, 100)]), hexa('c0763a'), sombra=0.24, luz=0.3, d=1.6)


def universidades_investigacion(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    cuadro(c, 8, 54, 96, 112, hexa('e9dcc0'), d=3.0)
    cuadro(c, 90, 36, 120, 112, hexa('9bb0d6'), d=3.0)
    for fila in range(3):
        for k in range(4):
            ventana(c, 16 + k * 20, 62 + fila * 16, 12, 9, hexa('a6d0f2'))
    for fila in range(5):
        for k in range(2):
            ventana(c, 95 + k * 12, 42 + fila * 13, 8, 8, hexa('d8ecff'))
    c.rect(44, 92, 60, 112, hexa('4a3a2a'), r=1.5)
    c.cuerpo([(20, 40), (62, 40), (62, 46), (20, 46)], hexa('b8583c'), sombra=0.2, luz=0.2, d=1.4)
    c.cuerpo([(14, 28), (41, 18), (68, 28), (41, 38)], hexa('2d2a35'), sombra=0.2, luz=0.3, d=1.6)
    c.cuerpo([(28, 31), (54, 31), (54, 42), (28, 42)], hexa('3d3a46'), sombra=0.2, luz=0.2, d=1.4)
    c.linea([(68, 28), (68, 40)], 1.8, ORO)
    c.punto(68, 42, 2.6, ORO)


def escuelas_tecnicas_ingenieria(c):
    suelo(c, y=112, grosor=8, col=hexa('7c8497'))
    c.cuerpo(engranaje(46, 62, 38, 30, 10), hexa('9aa6ba'), sombra=0.26, luz=0.3, d=2.8)
    c.elip(46, 62, 12, 12, hexa('3a4258'))
    c.cuerpo(engranaje(98, 34, 22, 17, 8, 12), ACERO_O, sombra=0.26, luz=0.3, d=2.2)
    c.elip(98, 34, 7, 7, hexa('3a4258'))
    c.linea([(84, 112), (112, 56)], 6, hexa('d8c070'))
    c.linea([(100, 112), (84, 74)], 6, hexa('d8c070'))
    c.linea([(84, 112), (100, 112)], 6, hexa('d8c070'))
    for k in range(4):
        c.linea([(92 + k * 3, 96 - k * 6), (96 + k * 3, 98 - k * 6)], 1.4, hexa('7a5a10'))
    c.linea([(10, 112), (40, 112)], 6, hexa('f2d680'))
    for k in range(5):
        c.linea([(14 + k * 6, 112), (14 + k * 6, 106)], 1.4, hexa('7a5a10'))


def laboratorios_industriales(c):
    suelo(c, y=112, grosor=8, col=hexa('7c8497'))
    cuadro(c, 6, 66, 76, 112, hexa('b8c4dc'), d=3.0)
    c.poly([(6, 66), (20, 54), (62, 54), (76, 66)], hexa('7c8aa2'))
    cuadro(c, 70, 40, 88, 112, hexa('a8b4cc'), d=2.4)
    humo(c, 79, 32, 2)
    for k in range(3):
        ventana(c, 12 + k * 20, 76, 12, 12, hexa('d8ecff'))
    c.rect(26, 96, 40, 112, hexa('4a3a2a'), r=1.5)
    c.cuerpo(spline([(98, 112), (98, 84), (92, 68), (92, 56), (114, 56), (114, 68), (108, 84), (108, 112)]), hexa('d8ecff'), sombra=0.2, luz=0.3, d=2.0)
    c.rect(94, 54, 112, 60, hexa('c9c3b6'), r=1.5)
    c.cuerpo(spline([(94, 112), (94, 98), (112, 98), (112, 112)]), hexa('5ed3a0'), sombra=0.2, luz=0.3, d=1.8)
    c.punto(103, 90, 2.0, hexa('b8f0d8'))
    c.punto(106, 80, 1.6, hexa('b8f0d8'))
    c.cuerpo(engranaje(104, 30, 11, 8, 8), ACERO, sombra=0.24, luz=0.3, d=1.6)
    c.elip(104, 30, 3.6, 3.6, hexa('3a4258'))


def estacion_espacial(c):
    cuadro(c, 0, 0, 128, 128, hexa('141c3a'), sombra=0.0, luz=0.0)
    for (x, y, r) in ((14, 16, 2.2), (44, 8, 1.6), (112, 18, 2.4), (100, 60, 1.6), (18, 62, 1.6), (84, 10, 1.6)):
        c.cuerpo(estrella(x, y, r * 2, r * 0.8, 4, 0), hexa('ffe28a'), sombra=0.0, luz=0.0)
    c.cuerpo(spline([(-20, 140), (-10, 100), (30, 84), (84, 88), (130, 104), (150, 140)]), hexa('3f86d8'), sombra=0.24, luz=0.3, d=3.4)
    c.poly(spline([(12, 128), (24, 106), (46, 100), (58, 118), (40, 128)]), hexa('5aab55'))
    c.poly(spline([(84, 128), (96, 108), (118, 106), (126, 128)]), hexa('5aab55'))
    c.cuerpo([(56, 54), (72, 54), (72, 74), (56, 74)], hexa('d8dde8'), sombra=0.24, luz=0.25, d=1.8)
    c.cuerpo([(40, 60), (56, 60), (56, 68), (40, 68)], hexa('9aa6ba'), sombra=0.2, luz=0.2, d=1.4)
    c.cuerpo([(72, 60), (88, 60), (88, 68), (72, 68)], hexa('9aa6ba'), sombra=0.2, luz=0.2, d=1.4)
    for (x0, x1) in ((6, 40), (88, 122)):
        c.cuerpo([(x0, 38), (x1, 38), (x1, 52), (x0, 52)], hexa('2f4a8a'), sombra=0.24, luz=0.3, d=1.8)
        c.cuerpo([(x0, 76), (x1, 76), (x1, 90), (x0, 90)], hexa('2f4a8a'), sombra=0.24, luz=0.3, d=1.8)
        for k in range(1, 4):
            xx = x0 + (x1 - x0) * k / 4.0
            c.linea([(xx, 38), (xx, 52)], 1.2, hexa('7a9ae0'))
            c.linea([(xx, 76), (xx, 90)], 1.2, hexa('7a9ae0'))
    c.linea([(64, 54), (64, 40)], 2.4, hexa('b8c0d4'))
    c.punto(64, 38, 2.6, ROJO)


# ───────────── mando y formación militar ─────────────
def calzadas_militares(c):
    cuadro(c, 0, 0, 128, 128, hexa('8fc268'), sombra=0.0, luz=0.0)
    c.cuerpo([(48, 8), (80, 8), (120, 122), (8, 122)], hexa('9a8a70'), sombra=0.22, luz=0.2, d=3.0)
    for k, y in enumerate((30, 50, 74, 100)):
        ancho = 32 + (112 - 32) * ((y - 8) / 114.0)
        c.linea([(64 - ancho / 2 + 4, y), (64 + ancho / 2 - 4, y)], 1.6, hexa('6a5a44'))
    c.linea([(64, 10), (64, 120)], 3, hexa('f2d680'))
    c.cuerpo([(14, 26), (36, 26), (36, 52), (25, 62), (14, 52)], hexa('c24a3a'), sombra=0.24, luz=0.25, d=2.0)
    c.cuerpo(estrella(25, 42, 7, 3, 5), ORO, sombra=0.0, luz=0.0)
    c.linea([(92, 18), (92, 74)], 3.4, MADERA_O)
    c.poly([(92, 10), (97, 22), (87, 22)], ACERO)
    c.linea([(102, 24), (102, 78)], 3.4, MADERA_O)
    c.poly([(102, 16), (107, 28), (97, 28)], ACERO)
    c.cuerpo_elip(96, 100, 12, 6, col=hexa('9a8a70'), sombra=0.0, luz=0.0)


def escuelas_militares(c):
    suelo(c, y=108, grosor=12, col=hexa('c8b784'))
    c.cuerpo(spline([(16, 56), (20, 26), (44, 18), (66, 26), (64, 60), (40, 80)]), hexa('b8c4dc'), sombra=0.24, luz=0.3, d=2.6)
    c.cuerpo(spline([(22, 52), (26, 32), (42, 26), (58, 32), (56, 54), (40, 70)]), hexa('3a62b8'), sombra=0.24, luz=0.3, d=2.2)
    c.cuerpo(estrella(41, 44, 10, 4.4, 5), ORO, sombra=0.0, luz=0.0)
    c.linea([(76, 100), (112, 36)], 5, ACERO)
    c.linea([(112, 36), (112, 36)], 5, ACERO)
    c.linea([(70, 82), (88, 92)], 6, hexa('b9893a'))
    c.linea([(112, 100), (76, 36)], 5, ACERO_O)
    c.linea([(72, 38), (86, 46)], 6, hexa('b9893a'))
    c.cuerpo_elip(36, 100, 20, 8, col=hexa('d8c49a'), sombra=0.2, luz=0.2, d=1.6)
    c.cuerpo_elip(36, 97, 14, 5, col=hexa('c24a3a'), sombra=0.0, luz=0.0)
    c.elip(36, 96, 6, 2.4, hexa('f6efdc'))


def academia_militar_moderna(c):
    suelo(c, y=112, grosor=8, col=hexa('8f9a74'))
    cuadro(c, 8, 62, 120, 112, hexa('d9d3c4'), d=3.0)
    cuadro(c, 44, 34, 84, 112, hexa('c9c2b0'), d=3.0)
    c.cuerpo([(40, 34), (64, 14), (88, 34)], hexa('3a62b8'), sombra=0.24, luz=0.28, d=2.4)
    c.cuerpo(estrella(64, 52, 10, 4.4, 5), ORO, sombra=0.2, luz=0.3, d=1.4)
    for k in range(3):
        ventana(c, 14 + k * 10, 74, 6, 9, hexa('d8ecff'))
        ventana(c, 92 + k * 10, 74, 6, 9, hexa('d8ecff'))
    puerta(c, 64, 112, 20, 28, hexa('3a2a1a'))
    c.linea([(64, 14), (64, 4)], 2.4, GRIS2)
    c.cuerpo([(65, 4), (80, 7), (65, 12)], ROJO, sombra=0.0, luz=0.2, d=1.2)


def centro_operaciones_ciberneticas(c):
    cuadro(c, 0, 0, 128, 128, hexa('1d2a3a'), sombra=0.0, luz=0.0)
    for k in range(7):
        c.linea([(6 + k * 20, 0), (6 + k * 20, 128)], 1.0, hexa('26405a'))
        c.linea([(0, 6 + k * 20), (128, 6 + k * 20)], 1.0, hexa('26405a'))
    c.cuerpo([(14, 20), (114, 20), (114, 82), (14, 82)], hexa('26405a'), sombra=0.24, luz=0.25, d=2.6)
    c.rect(20, 26, 108, 76, hexa('0f1a28'), r=2)
    for k, w in enumerate((60, 42, 70, 34, 52)):
        c.linea([(28, 34 + k * 9), (28 + w, 34 + k * 9)], 3, hexa('5aeaa0') if k % 2 == 0 else hexa('3fb0e0'))
    c.cuerpo([(44, 88), (84, 88), (92, 104), (36, 104)], hexa('3a4a5c'), sombra=0.24, luz=0.25, d=2.0)
    c.rect(54, 82, 74, 88, hexa('3a4a5c'))
    c.cuerpo([(84, 36), (106, 36), (106, 62), (95, 72), (84, 62)], hexa('3a62b8'), sombra=0.24, luz=0.28, d=1.8)
    c.cuerpo_elip(95, 50, 4, col=ORO, sombra=0.0, luz=0.0)
    c.rect(93.2, 52, 96.8, 60, ORO)


# ───────────── salud ─────────────
def cruz(c, x, y, k=1.0, col=ROJO):
    c.cuerpo([(x - 4 * k, y - 12 * k), (x + 4 * k, y - 12 * k), (x + 4 * k, y - 4 * k), (x + 12 * k, y - 4 * k), (x + 12 * k, y + 4 * k), (x + 4 * k, y + 4 * k),
              (x + 4 * k, y + 12 * k), (x - 4 * k, y + 12 * k), (x - 4 * k, y + 4 * k), (x - 12 * k, y + 4 * k), (x - 12 * k, y - 4 * k), (x - 4 * k, y - 4 * k)],
             col, sombra=0.2, luz=0.3, d=1.4)


def hospitales_religiosos(c):
    suelo(c, y=112, grosor=8)
    cuadro(c, 6, 62, 88, 112, hexa('e9e1cc'), d=2.8)
    techo(c, 6, 88, 63, 40, hexa('b8583c'), alero=5)
    for k in range(4):
        pts = [(14 + k * 18, 110)] + [(14 + k * 18 + 6 - 6 * math.cos(math.radians(a)), 88 - 10 * math.sin(math.radians(a))) for a in range(0, 181, 30)] + [(26 + k * 18, 110)]
        c.poly(pts, hexa('4a3a2a'))
    cuadro(c, 92, 44, 118, 112, hexa('d6cdb4'), d=2.4)
    c.poly([(90, 44), (105, 24), (120, 44)], hexa('8d6a4a'))
    c.linea([(105, 24), (105, 10)], 2.4, ORO2)
    c.linea([(100, 15), (110, 15)], 2.4, ORO2)
    cruz(c, 105, 66, 0.9)
    cruz(c, 48, 52, 0.8)


def escuelas_medicina(c):
    suelo(c, y=112, grosor=8, col=hexa('d8d2c0'))
    c.linea([(64, 12), (64, 108)], 6, hexa('c9a468'))
    c.punto(64, 10, 5, ORO)
    c.cuerpo(spline([(64, 100), (38, 92), (36, 78), (62, 70), (92, 62), (92, 48), (64, 40)], cerrada=False), hexa('4aa860'), sombra=0.0, luz=0.0)
    c.linea(spline([(64, 98), (36, 88), (40, 74), (66, 68), (90, 60), (88, 46), (64, 36)], cerrada=False), 7, hexa('4aa860'))
    c.linea(spline([(64, 98), (36, 88), (40, 74), (66, 68), (90, 60), (88, 46), (64, 36)], cerrada=False), 2.4, hexa('7fdc94'))
    c.cuerpo_elip(64, 34, 8, 6, col=hexa('3f9e57'), sombra=0.2, luz=0.3, d=1.4)
    c.punto(60, 33, 1.6, hexa('1f3a2a'))
    for sgn in (-1, 1):
        c.cuerpo([(64, 26), (64 + sgn * 34, 14), (64 + sgn * 38, 22), (64 + sgn * 30, 24), (64 + sgn * 34, 30), (64 + sgn * 22, 30), (64 + sgn * 24, 36), (64, 34)],
                 hexa('f1ede2'), sombra=0.2, luz=0.0, d=1.6)
    libro(c, 6, 90, 26, 22, hexa('c24a3a'), hexa('f2d680'))
    cruz(c, 19, 101, 0.5, hexa('f6efdc'))
    libro(c, 96, 94, 26, 18, hexa('3f7fd0'), hexa('f2d680'))


def lazaretos(c):
    c.cuerpo([(0, 84), (128, 84), (128, 128), (0, 128)], AGUA, sombra=0.2, luz=0.2, d=3.0)
    olas(c, 112, 4, 124, AGUA_C, 7)
    c.cuerpo(spline([(10, 100), (16, 84), (40, 78), (96, 78), (116, 84), (122, 100)]), hexa('c8b784'), sombra=0.24, luz=0.2, d=3.0)
    cuadro(c, 30, 46, 98, 84, hexa('e9e1cc'), d=2.8)
    techo(c, 30, 98, 47, 22, hexa('8d6a4a'), alero=5)
    ventana(c, 38, 58, 9, 10, hexa('4a3a2a'))
    ventana(c, 80, 58, 9, 10, hexa('4a3a2a'))
    c.rect(56, 62, 72, 84, hexa('4a3a2a'), r=1.5)
    c.linea([(104, 84), (104, 40)], 3, GRIS2)
    c.cuerpo([(105, 40), (124, 46), (105, 54)], hexa('f2c842'), sombra=0.2, luz=0.2, d=1.6)
    for x in range(10, 30, 6):
        c.linea([(x, 90), (x, 78)], 2.0, MADERA_O)
    c.linea([(10, 84), (28, 84)], 2.0, MADERA_O)
    cruz(c, 64, 34, 0.5, hexa('f6efdc'))


def hospital_moderno(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    cuadro(c, 14, 30, 114, 112, hexa('f1f4fb'), d=3.2)
    cuadro(c, 50, 14, 78, 112, hexa('e4e8f2'), d=2.6)
    for fila in range(4):
        for k in (0, 1, 3, 4):
            x = 20 + k * 19 if k < 2 else 20 + k * 19 + 0
            ventana(c, x if k < 2 else 82 + (k - 3) * 17, 38 + fila * 16, 11, 9, hexa('a6d0f2'))
    cruz(c, 64, 36, 1.1)
    c.rect(54, 92, 74, 112, hexa('4a6fb0'), r=1.5)
    c.linea([(64, 92), (64, 112)], 1.4, hexa('e4eaf8'))
    c.cuerpo_elip(100, 22, 10, col=hexa('3a62b8'), sombra=0.2, luz=0.2, d=1.4)
    c.linea([(96, 17), (96, 27)], 2.2, BLANCO)
    c.linea([(104, 17), (104, 27)], 2.2, BLANCO)
    c.linea([(96, 22), (104, 22)], 2.2, BLANCO)


# ───────────── registro ─────────────
def _slugs():
    import json
    import os
    ruta = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'datos', 'edificios.json')
    return [e['slug'] for e in json.load(open(ruta, encoding='utf-8'))['edificios']]


SLUGS = _slugs()


def _redondeado(f):
    """Los fondos que llegan al borde del lienzo (agua, campo, calzada...) se recortan con esquinas redondeadas."""
    def g(c):
        f(c)
        t = c.t
        m = Image.new('L', (t, t), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, t - 1, t - 1], radius=16 * K, fill=255)
        c.im.putalpha(ImageChops.multiply(c.im.getchannel('A'), m))
    return g


ICONOS = {n: _redondeado(f) for n, f in list(globals().items()) if callable(f) and n in SLUGS}
