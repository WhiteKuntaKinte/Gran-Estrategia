"""Iconos de los 178 edificios del juego (0.1.8.41), uno por `slug` de datos/edificios.json -> iconos/edificios/<slug>.png (128 px).
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


# ───────────── 0.1.8.49 · economía, orden, culto y mando ─────────────
def _rueda_agua(c, cx, cy, r, col=MADERA, col_o=MADERA_O):
    c.elip(cx, cy, r, r, col_o)
    c.elip(cx, cy, r - 4, r - 4, hexa('5a4a38'))
    for k in range(8):
        a = math.radians(k * 45.0)
        c.linea([(cx, cy), (cx + (r - 2) * math.cos(a), cy + (r - 2) * math.sin(a))], 2.2, col)
        c.cuerpo(rot([(cx + r - 1, cy - 3), (cx + r + 5, cy - 3), (cx + r + 5, cy + 3), (cx + r - 1, cy + 3)], k * 45.0, cx, cy), col, sombra=0.2, luz=0.15, d=1.2)
    c.elip(cx, cy, 4, 4, ACERO_O)


def _arcada(c, x0, x1, y_base, alto, n, col=hexa('2f2c3a')):
    """Arcos de medio punto en un muro: `n` huecos entre x0 y x1."""
    paso = (x1 - x0) / n
    for k in range(n):
        xa = x0 + k * paso + paso * 0.18
        xb = x0 + (k + 1) * paso - paso * 0.18
        r = (xb - xa) / 2
        pts = [(xa, y_base)] + [((xa + xb) / 2 - r * math.cos(math.radians(a)), y_base - alto + r - r * math.sin(math.radians(a))) for a in range(0, 181, 20)] + [(xb, y_base)]
        c.poly(pts, col)


def _reloj(c, x, y, r=6):
    c.elip(x, y, r, r, hexa('f6f2e4'))
    c.elip(x, y, r - 1.2, r - 1.2, hexa('ffffff'))
    c.linea([(x, y), (x, y - r + 2.5)], 1.2, OSCURO_V)
    c.linea([(x, y), (x + r - 3, y + 1)], 1.2, OSCURO_V)


def _fronton(c, x0, x1, y_base, alto, col=hexa('efe9d6')):
    c.cuerpo([(x0, y_base), ((x0 + x1) / 2, y_base - alto), (x1, y_base)], col, sombra=0.2, luz=0.22, d=2.2)


def _moneda(c, x, y, r=6):
    c.cuerpo_elip(x, y, r, col=ORO, sombra=0.25, luz=0.35, d=1.6)
    c.elip(x, y, r - 2.4, r - 2.4, ORO2)
    c.linea([(x, y - r + 3.5), (x, y + r - 3.5)], 1.3, claro(ORO, 0.4))


def taller_artesano(c):
    suelo(c, y=112, grosor=8, col=hexa('c8b784'))
    casa(c, 8, 66, 112, 44, hexa('e0cfa6'), TEJA, 17)
    cuadro(c, 50, 30, 58, 58, LADRILLO, sombra=0.2, luz=0.2, d=1.6)
    humo(c, 54, 28, 3)
    c.rect(18, 84, 40, 112, hexa('3a2e22'), r=1.5)                                   # frente abierto del taller
    c.cuerpo([(20, 100), (38, 100), (36, 106), (22, 106)], ACERO_O, sombra=0.2, luz=0.3, d=1.4)   # yunque
    c.rect(26, 106, 32, 112, MADERA_O)
    pts = [(78, 112)] + [(98 - 20 * math.cos(math.radians(a)), 94 - 26 * math.sin(math.radians(a))) for a in range(0, 181, 15)] + [(118, 112)]
    c.cuerpo(pts, LADRILLO, sombra=0.22, luz=0.22, d=2.6)
    c.poly([(90, 112), (90, 102)] + [(98 - 8 * math.cos(math.radians(a)), 102 - 8 * math.sin(math.radians(a))) for a in range(0, 181, 30)] + [(106, 102), (106, 112)], hexa('2a1d16'))
    c.poly([(93, 112), (98, 100), (103, 112)], LLAMA_V)
    for k, (x, y, r_) in enumerate(((72, 106, 5), (80, 108, 4), (116, 108, 4))):
        c.cuerpo_elip(x, y, r_, r_ * 1.2, col=TEJA if k != 1 else hexa('d9a066'), sombra=0.2, luz=0.3, d=1.4)


def molinos_hidraulicos(c):
    c.cuerpo([(0, 92), (128, 92), (128, 128), (0, 128)], AGUA, sombra=0.2, luz=0.2, d=3.0)
    olas(c, 116, 4, 124, AGUA_C, 7)
    cuadro(c, 44, 44, 108, 100, hexa('e9e1cc'), d=2.8)
    techo(c, 44, 108, 45, 20, hexa('8d6a4a'), alero=5)
    ventana(c, 78, 56, 9, 10, hexa('4a3a2a'))
    c.rect(56, 70, 70, 100, hexa('4a3a2a'), r=1.5)
    cuadro(c, 40, 98, 112, 106, PIEDRA)
    _rueda_agua(c, 30, 88, 20)
    c.poly([(0, 92), (14, 92), (22, 100), (0, 100)], AGUA_C)
    for k in range(3):
        c.cuerpo_elip(100 + k * 6, 84 - k * 2, 4, 3, col=hexa('f4efe0'), sombra=0.15, luz=0.3, d=1.2)    # sacos de harina


def molinos_viento(c):
    suelo(c, y=112, grosor=8, col=CESPED)
    c.cuerpo([(40, 112), (88, 112), (80, 52), (48, 52)], hexa('efe6d0'), sombra=0.24, luz=0.2, d=3.0)
    c.cuerpo([(44, 54), (84, 54), (64, 28)], hexa('9a6a43'), sombra=0.24, luz=0.22, d=2.4)
    c.rect(58, 90, 70, 112, hexa('5a3a22'), r=1.5)
    ventana(c, 58, 66, 12, 10, hexa('4a3a2a'))
    hub = (64, 44)
    for ang in (35, 125, 215, 305):
        a = math.radians(ang)
        fin = (hub[0] + 44 * math.cos(a), hub[1] + 44 * math.sin(a))
        c.linea([hub, fin], 3.0, MADERA_O)
        n = (-math.sin(a), math.cos(a))
        p0 = (hub[0] + 12 * math.cos(a), hub[1] + 12 * math.sin(a))
        pts = [p0, fin, (fin[0] + n[0] * 11, fin[1] + n[1] * 11), (p0[0] + n[0] * 11, p0[1] + n[1] * 11)]
        c.cuerpo(pts, hexa('f4eed8'), sombra=0.15, luz=0.1, d=1.4)
        for t in (0.35, 0.6, 0.85):
            q = (p0[0] + (fin[0] - p0[0]) * t, p0[1] + (fin[1] - p0[1]) * t)
            c.linea([q, (q[0] + n[0] * 11, q[1] + n[1] * 11)], 1.0, MADERA)
    c.elip(hub[0], hub[1], 5, 5, MADERA_O)


def casa_gremio(c):
    suelo(c, y=112, grosor=8, col=hexa('b9ad8c'))
    cuadro(c, 22, 52, 106, 112, hexa('e6d6b0'), d=3.0)
    c.cuerpo([(16, 54), (64, 18), (112, 54)], hexa('7e4a3a'), sombra=0.24, luz=0.2, d=2.8)
    c.rect(22, 80, 106, 83, MADERA_O)                                                       # entramado de madera
    for xx in (22, 50, 78, 104):
        c.rect(xx, 52, xx + 3, 112, MADERA_O)
    for xx in (32, 60, 86):
        ventana(c, xx, 58, 10, 13, hexa('9fd4f6'))
    c.rect(52, 88, 76, 112, hexa('5a3a22'), r=1.5)
    c.linea([(106, 70), (122, 70)], 2.0, ACERO_O)
    c.cuerpo([(108, 70), (122, 70), (122, 84), (108, 84)], ORO2, sombra=0.2, luz=0.3, d=1.4)
    c.poly([(111, 80), (115, 73), (119, 80)], hexa('3a62b8'))
    bandera_asta(c, 64, 22, 14, ROJO, 12)


def caravasar_posada(c):
    suelo(c, y=112, grosor=8, col=hexa('d8c48c'))
    cuadro(c, 6, 54, 86, 112, hexa('d9b87a'), d=3.0)
    almenas(c, 6, 86, 54, hexa('d9b87a'), 6, 6)
    pts = [(32, 112)] + [(46 - 14 * math.cos(math.radians(a)), 84 - 18 * math.sin(math.radians(a))) for a in range(0, 181, 15)] + [(60, 112)]
    c.poly(pts, hexa('3a2e22'))
    for k in range(3):
        c.rect(12 + k * 4, 62, 14 + k * 4, 70, hexa('3a2e22'))
    c.linea([(98, 112), (98, 70)], 4, MADERA_O)
    for ang in (-150, -110, -70, -30, 10, 40):
        a = math.radians(ang)
        c.linea([(98, 70), (98 + 22 * math.cos(a), 70 + 14 * math.sin(a) - 6)], 3, VERDE2)
    c.cuerpo_elip(112, 100, 5, 4, col=hexa('b07a40'), sombra=0.2, luz=0.3, d=1.4)
    c.cuerpo_elip(104, 106, 6, 4.5, col=hexa('e6d8b8'), sombra=0.2, luz=0.3, d=1.4)
    c.cuerpo([(64, 100), (78, 100), (76, 112), (66, 112)], hexa('8b6a42'), sombra=0.2, luz=0.2, d=1.4)
    c.linea([(70, 100), (70, 92)], 1.6, GRIS2)
    c.cuerpo_elip(70, 90, 4, 4, col=LLAMA_V, sombra=0.2, luz=0.3, d=1.2)


def astillero(c):
    c.cuerpo([(0, 96), (128, 96), (128, 128), (0, 128)], AGUA, sombra=0.2, luz=0.2, d=3.0)
    olas(c, 118, 4, 124, AGUA_C, 7)
    cuadro(c, 4, 94, 124, 102, MADERA, d=2.4)
    casco = [(20, 62), (108, 62), (100, 90), (74, 96), (40, 96), (26, 84)]
    c.cuerpo(spline(casco), MADERA_O, sombra=0.24, luz=0.2, d=3.0)
    for xx in range(32, 100, 10):
        c.linea([(xx, 64), (xx - 2, 92)], 1.4, hexa('5a3a22'))
    c.rect(18, 58, 110, 64, hexa('a37a4a'))
    for xx in (30, 54, 78, 100):
        c.linea([(xx, 94), (xx - 6, 40)], 3, MADERA)
    c.linea([(24, 40), (104, 40)], 3, MADERA)
    c.linea([(64, 40), (64, 14)], 3.4, MADERA_O)
    c.linea([(64, 14), (92, 24)], 2.6, MADERA_O)
    c.linea([(92, 24), (92, 46)], 1.4, GRIS2)
    c.cuerpo([(88, 46), (96, 46), (96, 52), (88, 52)], ACERO_O, sombra=0.2, luz=0.3, d=1.2)


def banco_casa_cambio(c):
    suelo(c, y=112, grosor=8, col=hexa('b9b3a0'))
    for k in range(3):
        cuadro(c, 10 + k * 3, 104 - k * 3 + 0, 118 - k * 3, 112 - k * 3, hexa('d8d2c0'), d=1.6)
    _fronton(c, 10, 118, 40, 20, hexa('ece5d0'))
    _moneda(c, 64, 33, 7)
    cuadro(c, 12, 40, 116, 48, hexa('efe9d6'))
    for k in range(5):
        columna(c, 18 + k * 20, 52, 96, 9)
    cuadro(c, 12, 96, 116, 104, hexa('d1c9b2'))
    c.rect(54, 80, 74, 96, hexa('3a2e22'), r=1.5)
    _moneda(c, 22, 84, 4)


def lonja_bolsa(c):
    suelo(c, y=112, grosor=8, col=hexa('c9c3b6'))
    cuadro(c, 8, 52, 120, 112, hexa('d6b48a'), d=3.0)
    c.cuerpo([(4, 54), (124, 54), (118, 44), (10, 44)], hexa('8d6a4a'), sombra=0.24, luz=0.2, d=2.2)
    _arcada(c, 12, 116, 110, 36, 5)
    cuadro(c, 50, 14, 78, 46, hexa('e4d4a8'), d=2.4)
    c.cuerpo([(48, 16), (64, 2), (80, 16)], hexa('8d6a4a'), sombra=0.22, luz=0.2, d=1.8)
    _reloj(c, 64, 28, 8)
    for k, (x, y) in enumerate(((20, 72), (96, 72), (108, 80))):
        _moneda(c, x, y, 3.5)


def altos_hornos(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    c.cuerpo([(30, 112), (98, 112), (86, 36), (42, 36)], LADRILLO, sombra=0.25, luz=0.2, d=3.2)
    for yy in range(46, 108, 10):
        c.linea([(34 + (yy - 112) * -0.15, yy), (94 - (112 - yy) * 0.15, yy)], 1.2, LADRILLO_O)
    cuadro(c, 40, 24, 88, 38, hexa('5a5260'), d=2.4)
    for k, (x, y) in enumerate(((54, 14), (62, 8), (72, 2))):
        c.cuerpo_elip(x, y, 7 + k * 2, col=hexa('d5d8e2'), sombra=0.15, luz=0.3, d=1.4)
    c.poly([(54, 112), (54, 94)] + [(64 - 10 * math.cos(math.radians(a)), 94 - 10 * math.sin(math.radians(a))) for a in range(0, 181, 30)] + [(74, 94), (74, 112)], hexa('2a1d16'))
    c.poly([(57, 112), (64, 90), (71, 112)], hexa('ff9a2a'))
    c.poly([(60, 112), (64, 98), (68, 112)], LLAMA_V)
    c.poly([(74, 110), (122, 110), (122, 104), (78, 104)], hexa('ff7a2a'))


def fabrica_vapor(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    cuadro(c, 8, 62, 96, 112, LADRILLO, d=3.0)
    for k in range(4):
        x0 = 8 + k * 22
        c.cuerpo([(x0, 62), (x0 + 22, 62), (x0 + 22, 46)], hexa('9aa6ba'), sombra=0.2, luz=0.22, d=1.8)
    for k in range(5):
        ventana(c, 16 + k * 16, 72, 9, 12, hexa('ffe28a'))
    c.rect(44, 92, 62, 112, hexa('3d3a46'), r=1.5)
    cuadro(c, 100, 20, 116, 112, LADRILLO_O, d=2.6)
    c.rect(98, 16, 118, 24, oscuro(LADRILLO_O, 0.3), r=1)
    humo(c, 106, 12, 3)
    c.cuerpo(engranaje(30, 52, 10, 7, 8), ACERO, sombra=0.25, luz=0.3, d=1.6)
    c.elip(30, 52, 3.2, 3.2, hexa('3d3a46'))


def acerias(c):
    suelo(c, y=112, grosor=8, col=hexa('7f8490'))
    cuadro(c, 6, 54, 76, 112, hexa('8c93a0'), d=3.0)
    c.cuerpo([(2, 56), (80, 56), (74, 44), (8, 44)], hexa('5f6674'), sombra=0.24, luz=0.2, d=2.0)
    for k in range(3):
        c.rect(14 + k * 20, 70, 26 + k * 20, 84, hexa('ffb347'))
    cuadro(c, 84, 18, 98, 112, hexa('6f7482'), d=2.4)
    humo(c, 90, 14, 3)
    c.linea([(106, 34), (106, 52)], 2.0, GRIS2)
    c.linea([(98, 34), (116, 34)], 2.6, GRIS2)
    cuch = rot([(94, 52), (118, 52), (113, 78), (99, 78)], -22.0, 106, 52)
    c.cuerpo(cuch, ACERO, sombra=0.25, luz=0.3, d=2.4)
    c.poly(rot([(94, 52), (118, 52), (117, 56), (95, 56)], -22.0, 106, 52), hexa('ff9a2a'))
    c.linea([(92, 70), (90, 106)], 3.0, hexa('ff7a2a'))
    c.linea([(92, 70), (90, 106)], 1.4, LLAMA_V)
    c.cuerpo([(80, 106), (104, 106), (102, 112), (82, 112)], hexa('ff7a2a'), sombra=0.15, luz=0.2, d=1.2)
    for (x, y) in ((86, 96), (96, 98), (84, 86)):
        c.punto(x, y, 1.6, LLAMA_V)


def estacion_ferrocarril(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    cuadro(c, 10, 52, 90, 100, hexa('d6b48a'), d=3.0)
    c.cuerpo([(4, 54), (96, 54), (84, 36), (16, 36)], hexa('7e4a3a'), sombra=0.24, luz=0.2, d=2.4)
    cuadro(c, 40, 14, 60, 54, hexa('c8a678'), d=2.2)
    c.cuerpo([(38, 16), (50, 2), (62, 16)], hexa('7e4a3a'), sombra=0.22, luz=0.2, d=1.6)
    _reloj(c, 50, 26, 7)
    for k in range(4):
        ventana(c, 16 + k * 17 if k < 2 else 56 + (k - 2) * 17, 66, 9, 12, hexa('ffe28a'))
    c.rect(44, 78, 56, 100, hexa('4a3a2a'), r=1.5)
    c.cuerpo([(8, 100), (118, 100), (122, 106), (4, 106)], hexa('a9a396'), sombra=0.2, luz=0.2, d=2.0)
    c.linea([(0, 112), (128, 112)], 3.0, ACERO_O)
    c.linea([(0, 118), (128, 118)], 3.0, ACERO_O)
    for xx in range(4, 124, 10):
        c.linea([(xx, 108), (xx + 4, 124)], 2.4, MADERA_O)
    c.cuerpo([(92, 70), (118, 70), (118, 100), (92, 100)], hexa('3a4a6a'), sombra=0.22, luz=0.2, d=2.0)
    c.rect(96, 76, 106, 88, hexa('9fd4f6'), r=1.2)
    c.elip(112, 100, 4, 4, hexa('3d3a46'))


def parque_industrial(c):
    suelo(c, y=112, grosor=8, col=hexa('9a9fa8'))
    for (x0, x1, y0, col) in ((6, 52, 66, hexa('c4cad4')), (54, 96, 54, hexa('aab3c4')), (98, 124, 74, hexa('c4cad4'))):
        cuadro(c, x0, y0, x1, 112, col, d=2.6)
        c.rect(x0, y0 - 4, x1, y0 + 2, hexa('7c869b'))
        for xx in range(int(x0) + 6, int(x1) - 8, 14):
            c.rect(xx, y0 + 10, xx + 8, y0 + 18, hexa('a6d0f2'), r=1)
    c.rect(18, 90, 38, 112, hexa('4a6fb0'), r=1)
    c.rect(66, 84, 86, 112, hexa('b8403f'), r=1)
    c.cuerpo_elip(112, 60, 8, 12, col=hexa('d8dde8'), sombra=0.22, luz=0.3, d=1.8)
    cuadro(c, 104, 60, 120, 72, hexa('d8dde8'), d=1.4)
    cuadro(c, 66, 30, 74, 54, hexa('7c869b'), d=1.6)
    humo(c, 70, 28, 3)
    c.linea([(0, 118), (128, 118)], 5, hexa('6f7480'))


def puerto_contenedores(c):
    c.cuerpo([(0, 92), (128, 92), (128, 128), (0, 128)], AGUA, sombra=0.2, luz=0.2, d=3.0)
    olas(c, 120, 4, 124, AGUA_C, 7)
    cuadro(c, 0, 88, 128, 96, hexa('9a9fa8'), d=2.0)
    cols = (ROJO, AZUL2, hexa('e6a23c'), VERDE2, hexa('b8403f'), hexa('3a62b8'))
    for fila in range(3):
        for k in range(5):
            x = 8 + k * 17
            y = 86 - (fila + 1) * 11 + 3
            cuadro(c, x, y, x + 16, y + 10, cols[(k + fila * 2) % 6], d=1.4)
            for xx in (x + 4, x + 8, x + 12):
                c.linea([(xx, y + 1), (xx, y + 9)], 0.8, oscuro(cols[(k + fila * 2) % 6], 0.3))
    c.linea([(94, 88), (102, 24)], 3.2, hexa('e6a23c'))
    c.linea([(120, 88), (112, 24)], 3.2, hexa('e6a23c'))
    c.rect(96, 18, 124, 26, hexa('e6a23c'), r=1.5)
    c.linea([(104, 26), (104, 70)], 1.2, GRIS2)
    cuadro(c, 98, 66, 112, 76, AZUL2, d=1.4)
    c.cuerpo([(70, 96), (120, 96), (112, 112), (78, 112)], hexa('3d4a6a'), sombra=0.22, luz=0.2, d=2.0)


def centro_comercial(c):
    suelo(c, y=112, grosor=8, col=hexa('6f7480'))
    cuadro(c, 6, 40, 122, 100, hexa('e9ecf4'), d=3.0)
    c.rect(6, 38, 122, 46, hexa('c8503f'))
    c.rect(36, 48, 92, 60, hexa('3a62b8'), r=2)
    c.linea([(44, 54), (84, 54)], 2.4, hexa('f6f2e4'))
    for k in range(6):
        c.rect(12 + k * 18, 66, 26 + k * 18, 96, hexa('9fd4f6'), r=1.5)
    c.rect(54, 72, 74, 100, hexa('7aa8d0'), r=1.5)
    c.linea([(64, 72), (64, 100)], 1.4, hexa('e4eaf8'))
    for k, col_ in enumerate((ROJO, AZUL2, VERDE2, hexa('e6a23c'))):
        x = 10 + k * 28
        c.cuerpo([(x, 106), (x + 16, 106), (x + 14, 100), (x + 4, 100)], col_, sombra=0.2, luz=0.3, d=1.2)
        c.punto(x + 3, 107, 1.8, OSCURO_V)
        c.punto(x + 13, 107, 1.8, OSCURO_V)
    c.linea([(0, 112), (128, 112)], 1.4, hexa('e9ecf4'))


def tribunal_audiencia(c):
    suelo(c, y=112, grosor=8, col=hexa('b9b3a0'))
    cuadro(c, 8, 104, 120, 112, hexa('d1c9b2'), d=1.6)
    _fronton(c, 10, 118, 40, 22, hexa('ece5d0'))
    c.linea([(64, 22), (64, 40)], 1.6, ORO2)                                                  # la balanza
    c.linea([(52, 28), (76, 28)], 1.8, ORO2)
    c.linea([(52, 28), (48, 36)], 1.0, ORO2)
    c.linea([(52, 28), (56, 36)], 1.0, ORO2)
    c.linea([(76, 28), (72, 36)], 1.0, ORO2)
    c.linea([(76, 28), (80, 36)], 1.0, ORO2)
    c.cuerpo([(46, 36), (58, 36), (52, 39)], ORO, sombra=0.2, luz=0.3, d=1.0)
    c.cuerpo([(70, 36), (82, 36), (76, 39)], ORO, sombra=0.2, luz=0.3, d=1.0)
    cuadro(c, 10, 40, 118, 48, hexa('efe9d6'))
    for k in range(6):
        columna(c, 14 + k * 18, 52, 102, 8)
    c.rect(54, 80, 74, 104, hexa('3a2e22'), r=1.5)


def prision(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    cuadro(c, 16, 52, 112, 112, hexa('9a9fa8'), d=3.2)
    almenas(c, 16, 112, 52, hexa('9a9fa8'), 6, 7)
    torre(c, 16, 112, 22, 70, hexa('858b94'), None, 2, True)
    torre(c, 112, 112, 22, 70, hexa('858b94'), None, 2, True)
    for k in range(4):
        x = 40 + k * 18
        c.rect(x, 66, x + 8, 82, hexa('2a2f3a'), r=1)
        for xx in (x + 2.5, x + 5.5):
            c.linea([(xx, 66), (xx, 82)], 1.0, hexa('aab3c4'))
    c.rect(50, 88, 78, 112, hexa('3a3a46'), r=1.5)
    c.linea([(64, 88), (64, 112)], 1.6, ACERO)
    c.punto(60, 102, 1.8, ORO)
    c.punto(68, 102, 1.8, ORO)
    c.linea([(8, 52), (8, 34)], 2.4, GRIS2)
    c.linea([(120, 52), (120, 34)], 2.4, GRIS2)


def comisaria_policia(c):
    suelo(c, y=112, grosor=8, col=hexa('9a9fa8'))
    cuadro(c, 14, 46, 114, 112, hexa('dfe4ee'), d=3.0)
    c.rect(10, 40, 118, 50, hexa('3a62b8'))
    for k in range(4):
        ventana(c, 22 + k * 24, 60, 14, 14, hexa('a6d0f2'))
    c.rect(52, 82, 76, 112, hexa('3a4a6a'), r=1.5)
    c.linea([(64, 82), (64, 112)], 1.4, hexa('aab3c4'))
    c.cuerpo_elip(64, 30, 9, 8, col=hexa('3a62b8'), sombra=0.2, luz=0.3, d=1.6)
    c.cuerpo(estrella(64, 30, 7, 3, 5), ORO, sombra=0.2, luz=0.3, d=1.0)
    c.cuerpo_elip(24, 100, 5, 3.4, col=hexa('f1f4fb'), sombra=0.2, luz=0.2, d=1.2)
    c.rect(18, 91, 30, 95, hexa('3a62b8'))
    c.cuerpo([(92, 102), (112, 102), (110, 96), (96, 96)], hexa('3a62b8'), sombra=0.2, luz=0.3, d=1.2)
    c.punto(97, 103, 2, OSCURO_V)
    c.punto(108, 103, 2, OSCURO_V)


def casa_consistorial(c):
    suelo(c, y=112, grosor=8, col=hexa('c8b784'))
    cuadro(c, 12, 56, 116, 112, hexa('e6d6b0'), d=3.0)
    c.cuerpo([(8, 58), (64, 36), (120, 58)], hexa('9a5a3c'), sombra=0.24, luz=0.2, d=2.6)
    cuadro(c, 48, 14, 80, 58, hexa('d9c493'), d=2.4)
    c.cuerpo([(46, 16), (64, 0), (82, 16)], hexa('9a5a3c'), sombra=0.22, luz=0.2, d=1.8)
    _reloj(c, 64, 30, 8)
    for k in range(4):
        ventana(c, 20 + k * 14 if k < 2 else 78 + (k - 2) * 14, 68, 9, 14, hexa('9fd4f6'))
    c.rect(54, 84, 74, 112, hexa('5a3a22'), r=1.5)
    c.rect(50, 78, 78, 84, hexa('b8a064'))
    bandera_asta(c, 100, 56, 20, ROJO, 12)


def palacio_gobierno(c):
    suelo(c, y=112, grosor=8, col=hexa('c8b784'))
    for k in range(3):
        cuadro(c, 30 - k * 4, 108 - k * 4, 98 + k * 4, 112 - k * 4 + 0, hexa('e4d4a8'), d=1.4)
    cuadro(c, 6, 66, 122, 100, hexa('efe3c0'), d=3.0)
    c.rect(2, 62, 126, 70, ORO2)
    cuadro(c, 40, 40, 88, 100, hexa('e4d4a8'), d=2.6)
    pts = [(40, 40)] + [(64 - 24 * math.cos(math.radians(a)), 40 - 22 * math.sin(math.radians(a))) for a in range(0, 181, 12)] + [(88, 40)]
    c.cuerpo(pts, ORO, sombra=0.24, luz=0.3, d=2.4)
    c.rect(62, 10, 66, 20, ORO2)
    c.punto(64, 8, 3, ROJO)
    for k in range(5):
        columna(c, 44 + k * 9.6, 60, 100, 5)
    for xx in (14, 28, 92, 106):
        ventana(c, xx, 76, 8, 14, hexa('4a3a2a'))
    c.rect(56, 82, 72, 100, hexa('5a3a22'), r=1.5)


def parlamento_edificio(c):
    suelo(c, y=112, grosor=8, col=hexa('b9b3a0'))
    cuadro(c, 6, 66, 122, 108, hexa('e4ddc8'), d=3.0)
    cuadro(c, 4, 104, 124, 112, hexa('d1c9b2'), d=1.6)
    cuadro(c, 40, 42, 88, 66, hexa('efe9d6'), d=2.4)
    pts = [(42, 42)] + [(64 - 22 * math.cos(math.radians(a)), 42 - 24 * math.sin(math.radians(a))) for a in range(0, 181, 12)] + [(86, 42)]
    c.cuerpo(pts, hexa('9fb4c8'), sombra=0.24, luz=0.3, d=2.4)
    for k in range(5):
        c.linea([(64 - 22 * math.cos(math.radians(36 * k + 18)) * 0.9, 42), (64, 20)], 1.0, hexa('7c93a8'))
    c.rect(63, 8, 65, 20, ORO2)
    bandera_asta(c, 64, 10, 0, ROJO, 0)
    for k in range(10):
        columna(c, 12 + k * 11, 70, 104, 5)
    c.rect(54, 82, 74, 108, hexa('3a2e22'), r=1.5)
    for (x0, x1) in ((6, 40), (88, 122)):
        c.cuerpo([(x0, 66), (x1, 66), (x1 - 4, 58), (x0 + 4, 58)], hexa('c8c0a8'), sombra=0.2, luz=0.2, d=1.6)


def iglesia_parroquial(c):
    suelo(c, y=112, grosor=8, col=CESPED)
    cuadro(c, 30, 62, 112, 112, hexa('e9e1cc'), d=3.0)
    techo(c, 30, 112, 63, 34, hexa('b8583c'), alero=4)
    cuadro(c, 8, 44, 32, 112, hexa('ddd2b4'), d=2.6)
    c.cuerpo([(6, 46), (20, 20), (34, 46)], hexa('8d4a3a'), sombra=0.24, luz=0.2, d=2.0)
    c.rect(19, 8, 21, 22, hexa('f6efdc'))
    c.rect(15, 12, 25, 14, hexa('f6efdc'))
    pts = [(14, 70)] + [(20 - 6 * math.cos(math.radians(a)), 64 - 8 * math.sin(math.radians(a))) for a in range(0, 181, 30)] + [(26, 70)]
    c.poly(pts, hexa('3a2e22'))
    for k in range(2):
        pts = [(48 + k * 26, 86)] + [(54 + k * 26 - 6 * math.cos(math.radians(a)), 76 - 8 * math.sin(math.radians(a))) for a in range(0, 181, 30)] + [(60 + k * 26, 86)]
        c.poly(pts, hexa('9fd4f6'))
    pts = [(88, 112)] + [(98 - 10 * math.cos(math.radians(a)), 94 - 14 * math.sin(math.radians(a))) for a in range(0, 181, 20)] + [(108, 112)]
    c.poly(pts, hexa('5a3a22'))


def mezquita_aljama(c):
    suelo(c, y=112, grosor=8, col=hexa('d8c48c'))
    cuadro(c, 10, 70, 92, 112, hexa('f1e8cc'), d=3.0)
    pts = [(28, 70)] + [(51 - 23 * math.cos(math.radians(a)), 70 - 26 * math.sin(math.radians(a))) for a in range(0, 181, 10)] + [(74, 70)]
    c.cuerpo(pts, hexa('3f9e9a'), sombra=0.24, luz=0.3, d=2.6)
    c.rect(50, 34, 52, 44, ORO2)
    c.cuerpo_elip(51, 31, 3.6, col=ORO, sombra=0.2, luz=0.3, d=1.0)
    c.elip(52.4, 31, 3.0, 3.0, hexa('3f9e9a'))
    _arcada(c, 14, 88, 112, 30, 4, hexa('3a4a5a'))
    cuadro(c, 100, 28, 114, 112, hexa('ece2c4'), d=2.4)
    c.rect(98, 56, 116, 62, ORO2)
    c.cuerpo([(98, 30), (107, 14), (116, 30)], hexa('3f9e9a'), sombra=0.22, luz=0.3, d=1.6)
    c.rect(106, 6, 108, 16, ORO2)
    c.cuerpo_elip(107, 4, 2.6, col=ORO, sombra=0.2, luz=0.3, d=0.8)
    ventana(c, 103, 38, 8, 10, hexa('3a4a5a'))
    ventana(c, 103, 70, 8, 10, hexa('3a4a5a'))


def templo_pagoda(c):
    suelo(c, y=112, grosor=8, col=hexa('c8b784'))
    cuadro(c, 22, 100, 106, 112, hexa('b8b0a0'), d=1.8)
    for k in range(4):
        w = 40 - k * 6
        yb = 98 - k * 22
        cuadro(c, 64 - w / 2 + 4, yb - 14, 64 + w / 2 - 4, yb, hexa('b8483a'), d=2.0)
        c.cuerpo([(64 - w / 2 - 12, yb - 12), (64, yb - 26), (64 + w / 2 + 12, yb - 12), (64 + w / 2 + 6, yb - 10), (64, yb - 20), (64 - w / 2 - 6, yb - 10)], hexa('3f6f78'), sombra=0.24, luz=0.2, d=2.0)
        c.rect(60, yb - 10, 68, yb - 2, hexa('f2d680'), r=1)
    c.linea([(64, 10), (64, 2)], 2.0, ORO2)
    c.punto(64, 2, 2.4, ORO)
    c.rect(56, 90, 72, 100, hexa('5a3a22'), r=1)
    for xx in (14, 114):
        arbol(c, xx, 112, 10, hexa('3f8f46'))


def teatro_anfiteatro(c):
    suelo(c, y=112, grosor=8, col=hexa('d8c48c'))
    cav = [(64 - 54 * math.cos(math.radians(a)), 98 - 68 * math.sin(math.radians(a))) for a in range(0, 181, 6)]
    c.cuerpo(cav, hexa('d9c9a0'), sombra=0.24, luz=0.2, d=3.0)
    for k in range(1, 5):
        r = 1.0 - k * 0.17
        c.linea([(64 - 54 * r * math.cos(math.radians(a)), 98 - 68 * r * math.sin(math.radians(a))) for a in range(0, 181, 8)], 2.2, hexa('b09a68'))
    cuadro(c, 10, 94, 118, 112, hexa('cdbb8e'), d=2.2)
    _arcada(c, 12, 116, 112, 15, 8, hexa('4a3a2a'))
    cuadro(c, 40, 62, 88, 94, hexa('e6d9b4'), d=2.2)
    for xx in (45, 56, 67, 78):
        columna(c, xx, 68, 94, 6)
    c.rect(38, 58, 90, 64, hexa('b8a064'), r=1)


def estadio(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    c.cuerpo_elip(64, 80, 58, 28, col=hexa('c4cad4'), sombra=0.22, luz=0.25, d=3.0)
    c.cuerpo_elip(64, 80, 46, 20, col=hexa('9aa6ba'), sombra=0.2, luz=0.2, d=2.0)
    c.cuerpo_elip(64, 80, 36, 14, col=hexa('4fae55'), sombra=0.15, luz=0.2, d=1.6)
    c.linea([(64, 66), (64, 94)], 1.2, hexa('e4f0e0'))
    c.elip(64, 80, 6, 4, hexa('4fae55'))
    c.linea(spline([(58, 80), (58, 76), (64, 74), (70, 76), (70, 84), (64, 86), (58, 84), (58, 80)]), 1.2, hexa('e4f0e0'))
    for k, xx in enumerate((10, 118)):
        c.linea([(xx, 84), (xx, 30)], 3.2, GRIS2)
        c.rect(xx - 10, 20, xx + 10, 32, hexa('f6f2e4'), r=1.5)
        for j in range(3):
            c.punto(xx - 6 + j * 6, 24, 1.8, LLAMA_V)
            c.punto(xx - 6 + j * 6, 29, 1.8, LLAMA_V)
    for k in range(18):
        a = math.radians(k * 20)
        c.punto(64 + 52 * math.cos(a), 80 + 24 * math.sin(a), 1.6, [ROJO, AZUL2, ORO, BLANCO][k % 4])


def casa_del_pueblo(c):
    suelo(c, y=112, grosor=8, col=hexa('b9ad8c'))
    cuadro(c, 12, 56, 116, 112, hexa('c8694a'), d=3.0)
    for yy in range(62, 108, 8):
        c.linea([(14, yy), (114, yy)], 1.0, LADRILLO_O)
    c.cuerpo([(8, 58), (64, 34), (120, 58)], hexa('5a5a6a'), sombra=0.24, luz=0.2, d=2.6)
    c.rect(44, 40, 84, 54, hexa('e8e1c8'), r=1.5)
    c.rect(52, 44, 76, 50, ROJO)
    for k in range(4):
        ventana(c, 20 + k * 14 if k < 2 else 78 + (k - 2) * 14, 66, 9, 14, hexa('ffe28a'))
    c.rect(54, 82, 74, 112, hexa('3a2e22'), r=1.5)
    c.linea([(104, 56), (104, 18)], 2.6, GRIS2)
    c.cuerpo([(105, 18), (128, 22), (105, 36)], hexa('c8402f'), sombra=0.2, luz=0.2, d=1.6)
    c.cuerpo(estrella(114, 27, 4, 1.8, 5), ORO, sombra=0.1, luz=0.1, d=0.6)


def cuartel_guarnicion(c):
    suelo(c, y=112, grosor=8, col=hexa('b9ad8c'))
    muro(c, 6, 122, 60, 112, hexa('c9b88a'), 6, False)
    torre(c, 20, 112, 24, 78, hexa('b8a874'), None, 2, False)
    torre(c, 108, 112, 24, 78, hexa('b8a874'), None, 2, False)
    pts = [(48, 112)] + [(64 - 16 * math.cos(math.radians(a)), 92 - 18 * math.sin(math.radians(a))) for a in range(0, 181, 15)] + [(80, 112)]
    c.poly(pts, hexa('3a2e22'))
    c.linea([(48, 92), (80, 92)], 1.6, ACERO_O)
    for xx in (54, 60, 66, 72):
        c.linea([(xx, 76), (xx, 100)], 1.0, ACERO_O)
    bandera_asta(c, 64, 60, 30, ROJO, 16)
    for xx in (20, 108):
        aspillera(c, xx, 64, 9)
        aspillera(c, xx, 84, 9)


def polvorin(c):
    suelo(c, y=112, grosor=8, col=CESPED)
    pts = [(12, 112), (12, 76)] + [(64 - 52 * math.cos(math.radians(a)), 76 - 34 * math.sin(math.radians(a))) for a in range(0, 181, 10)] + [(116, 76), (116, 112)]
    c.cuerpo(pts, hexa('a9a396'), sombra=0.24, luz=0.2, d=3.2)
    for k in range(4):
        r = 44 - k * 11
        c.linea([(64 - r * math.cos(math.radians(a)), 76 - r * 0.65 * math.sin(math.radians(a))) for a in range(0, 181, 12)], 1.2, hexa('807a6e'))
    c.rect(50, 86, 78, 112, hexa('3a2e22'), r=1.5)
    c.linea([(64, 86), (64, 112)], 1.6, ACERO_O)
    c.punto(60, 100, 1.8, ORO)
    c.punto(68, 100, 1.8, ORO)
    for k, (x, y) in enumerate(((20, 104), (30, 106), (96, 104), (106, 106))):
        c.cuerpo_elip(x, y, 6, 6.5, col=MADERA, sombra=0.22, luz=0.25, d=1.4)
        c.linea([(x - 5.5, y - 2), (x + 5.5, y - 2)], 1.2, ACERO_O)
        c.linea([(x - 5.5, y + 2), (x + 5.5, y + 2)], 1.2, ACERO_O)
    c.punto(64, 54, 2.2, hexa('3a2e22'))


def cuartel_estado_mayor(c):
    suelo(c, y=112, grosor=8, col=hexa('b9b3a0'))
    cuadro(c, 8, 60, 120, 112, hexa('e6dec8'), d=3.0)
    c.cuerpo([(4, 62), (64, 40), (124, 62)], hexa('4a5a7a'), sombra=0.24, luz=0.2, d=2.6)
    for k in range(6):
        ventana(c, 16 + k * 17, 70, 9, 14, hexa('ffe28a'))
    c.rect(54, 88, 74, 112, hexa('3a2e22'), r=1.5)
    c.rect(36, 90, 48, 112, hexa('c4cad4'))
    c.rect(80, 90, 92, 112, hexa('c4cad4'))
    c.linea([(64, 40), (64, 12)], 2.4, GRIS2)
    c.cuerpo([(65, 12), (86, 17), (65, 26)], ROJO, sombra=0.2, luz=0.2, d=1.4)
    c.cuerpo(estrella(64, 52, 5, 2.2, 5), ORO, sombra=0.1, luz=0.2, d=0.8)
    c.cuerpo([(98, 100), (118, 100), (116, 106), (100, 106)], hexa('d9c493'), sombra=0.2, luz=0.2, d=1.2)
    c.linea([(100, 103), (116, 103)], 0.9, hexa('807a6e'))


def estacion_radar(c):
    suelo(c, y=112, grosor=8, col=hexa('8a8f9a'))
    cuadro(c, 10, 92, 118, 112, hexa('b3b8bf'), d=2.6)
    cuadro(c, 54, 58, 74, 92, hexa('9aa6ba'), d=2.2)
    c.linea([(64, 58), (64, 52)], 3, GRIS2)
    c.cuerpo(spline([(30, 40), (46, 22), (72, 18), (96, 28), (80, 46), (54, 54), (36, 50)]), hexa('e4e8f2'), sombra=0.25, luz=0.3, d=3.0)
    c.elip(64, 38, 9, 9, hexa('c4cad4'))
    c.linea([(64, 38), (104, 14)], 2.4, GRIS2)
    c.punto(104, 14, 3, ROJO)
    for k, r in enumerate((14, 22, 30)):
        c.linea([(104 - r * 0.2 + math.cos(math.radians(a)) * r * 0.6, 14 + math.sin(math.radians(a)) * r * 0.6) for a in range(-60, 61, 15)], 1.4, hexa('7ec8e8'))
    for k in range(4):
        ventana(c, 16 + k * 14 if k < 2 else 78 + (k - 2) * 14, 98, 8, 8, hexa('a6d0f2'))
    c.rect(56, 100, 72, 112, hexa('4a4f5a'), r=1)


def centro_mando_control(c):
    suelo(c, y=112, grosor=8, col=hexa('6f7480'))
    c.cuerpo([(8, 112), (8, 66), (24, 54), (104, 54), (120, 66), (120, 112)], hexa('7d838f'), sombra=0.25, luz=0.2, d=3.2)
    c.rect(18, 70, 110, 100, hexa('1f2430'), r=2)
    for fila in range(2):
        for k in range(7):
            col = [hexa('4fb3ff'), hexa('4fd89a'), hexa('ffcf4f'), hexa('4fb3ff')][(k + fila) % 4]
            c.rect(22 + k * 12.4, 74 + fila * 13, 31 + k * 12.4, 83 + fila * 13, col, r=1)
    c.rect(56, 102, 72, 112, hexa('3a3f4a'), r=1)
    c.linea([(30, 54), (30, 20)], 2.0, GRIS2)
    c.linea([(98, 54), (98, 12)], 2.0, GRIS2)
    for yy in (24, 34, 44):
        c.linea([(24, yy), (36, yy)], 1.6, GRIS2)
    c.cuerpo(spline([(76, 22), (84, 8), (108, 4), (120, 14), (108, 22), (90, 26)]), hexa('e4e8f2'), sombra=0.25, luz=0.3, d=2.4)
    c.linea([(98, 14), (98, 26)], 1.8, GRIS2)
    c.punto(98, 12, 2, ROJO)


# ───────────── 0.1.8.51 · maravillas (únicas en el mundo) y edificios corrientes nuevos ─────────────
BRONCE_E = hexa('b8793a')
ARENA_E = hexa('e2b96a')
ARENA_O = hexa('b9894a')
ROJO_PALACIO = hexa('b8423a')
DORADO_TEJA = hexa('e8b838')


def _cielo(c, col=hexa('8ec9f0'), col2=None):
    c.rect(0, 0, 128, 128, col)
    if col2 is not None:
        c.poly([(0, 70), (128, 54), (128, 128), (0, 128)], col2)


def _sol(c, x=100, y=26, r=11, col=hexa('ffd45e')):
    c.punto(x, y, r + 5, (255, 236, 160, 120))
    c.cuerpo_elip(x, y, r, col=col, sombra=0.15, luz=0.3, d=1.6)


def _nube(c, x, y, s=1.0, col=hexa('f6f9ff')):
    for dx, dy, r in ((0, 0, 9), (10, 3, 7), (-10, 3, 7), (4, -5, 8)):
        c.elip(x + dx * s, y + dy * s, r * s, r * 0.8 * s, col)


def _arco_herradura(c, x0, x1, yb, alto, col):
    r = (x1 - x0) / 2
    cx = (x0 + x1) / 2
    pts = [(x0 + 2, yb)] + [(cx - r * math.cos(math.radians(a)), yb - alto + r - r * 1.02 * math.sin(math.radians(a))) for a in range(-12, 193, 12)] + [(x1 - 2, yb)]
    c.poly(pts, col)


def _flama(c, x, y, s=1.0):
    c.poly([(x - 5 * s, y), (x, y - 16 * s), (x + 5 * s, y)], hexa('ff9a30'))
    c.poly([(x - 2.6 * s, y), (x, y - 9 * s), (x + 2.6 * s, y)], hexa('ffe27a'))


def _caja(c, x0, y0, x1, y1, col, **kw):
    return cuadro(c, x0, y0, x1, y1, col, **kw)


# ── Maravillas del mundo antiguo ──
def piramides_giza(c):
    _cielo(c, hexa('f8e2ac'))
    _sol(c, 100, 26)
    c.cuerpo([(0, 108), (128, 108), (128, 128), (0, 128)], hexa('d9b46a'), d=2.4)
    c.cuerpo([(72, 108), (94, 72), (116, 108)], hexa('c99a55'), d=2.0)
    c.cuerpo([(6, 108), (28, 78), (50, 108)], hexa('c99a55'), d=2.0)
    c.cuerpo([(28, 108), (64, 34), (100, 108)], ARENA_E, sombra=0.3, luz=0.2, d=3.0)
    c.poly([(64, 34), (100, 108), (80, 108), (64, 62)], ARENA_O)
    for k in range(1, 7):
        y = 34 + k * 11
        h = (y - 34) * 0.55
        c.linea([(64 - h, y), (64 + h * 0.3, y)], 1.1, oscuro(ARENA_E, 0.22))
    c.cuerpo([(52, 108), (64, 96), (76, 108)], hexa('3a2e22'), sombra=0, luz=0)


def jardines_colgantes(c):
    _cielo(c)
    _nube(c, 100, 22, 0.9)
    niveles = [(10, 118, 98), (22, 106, 78), (34, 94, 58), (46, 82, 38)]
    for i, (x0, x1, y) in enumerate(niveles):
        cuadro(c, x0, y, x1, y + 20, hexa('d9cdb0') if i % 2 == 0 else hexa('c9bd9c'))
        c.rect(x0 - 3, y - 5, x1 + 3, y + 2, CESPED_O, r=2)
        for x in range(int(x0) + 6, int(x1) - 2, 16):
            arbol(c, x, y - 2, r=6, col=CESPED if i % 2 else CESPED_O)
    c.linea([(98, 98), (98, 118)], 4, AGUA)
    c.linea([(40, 60), (40, 78)], 3, AGUA_C)
    c.cuerpo([(0, 118), (128, 118), (128, 128), (0, 128)], AGUA, d=1.6)


def partenon(c):
    _cielo(c)
    c.cuerpo([(0, 112), (128, 112), (128, 128), (0, 128)], hexa('c8b784'), d=2.4)
    cuadro(c, 8, 104, 120, 114, hexa('e8e0cc'))
    cuadro(c, 12, 96, 116, 104, hexa('efe9d6'))
    for i in range(8):
        columna(c, 18 + i * 12, 54, 96, w=8)
    cuadro(c, 10, 44, 118, 55, hexa('efe9d6'))
    c.cuerpo([(8, 44), (64, 20), (120, 44)], hexa('efe9d6'), sombra=0.2, luz=0.25, d=2.4)
    c.poly([(26, 42), (64, 26), (102, 42)], hexa('7fb3d8'))
    for x in (46, 64, 82):
        c.punto(x, 38, 3, hexa('efe9d6'))


def coloso_rodas(c):
    _cielo(c)
    olas(c, 110, 0, 128, AGUA, 8)
    cuadro(c, 6, 80, 36, 112, PIEDRA)
    cuadro(c, 92, 80, 122, 112, PIEDRA)
    c.cuerpo([(24, 82), (52, 44), (66, 44), (38, 82)], BRONCE_E, d=2.4)
    c.cuerpo([(104, 82), (76, 44), (62, 44), (90, 82)], BRONCE_E, d=2.4)
    c.cuerpo([(50, 46), (78, 46), (74, 20), (54, 20)], BRONCE_E, d=2.6)
    c.cuerpo_elip(64, 14, 7, 7.5, col=BRONCE_E, d=1.8)
    c.linea([(76, 24), (92, 12), (94, 6)], 4.5, BRONCE_E)
    _flama(c, 94, 8, 0.8)
    c.linea([(52, 24), (40, 34)], 4.5, BRONCE_E)
    olas(c, 116, 0, 128, claro(AGUA, 0.2), 8)


def gran_biblioteca_alejandria(c):
    _cielo(c, hexa('9fd8f0'))
    c.cuerpo([(0, 112), (128, 112), (128, 128), (0, 128)], hexa('d9c9a2'), d=2.4)
    cuadro(c, 12, 56, 116, 106, hexa('efe6cf'))
    c.cuerpo([(8, 56), (64, 30), (120, 56)], hexa('d2c4a0'), sombra=0.2, luz=0.25, d=2.4)
    for i in range(6):
        columna(c, 16 + i * 18, 62, 106, w=8)
    for x in (30, 64, 98):
        _arco_herradura(c, x - 7, x + 7, 100, 28, hexa('3e3a4c'))
    c.cuerpo_elip(64, 92, 19, 7.5, col=hexa('f6ecc8'), d=1.8)
    c.linea([(48, 92), (80, 92)], 1.2, oscuro(hexa('f6ecc8'), 0.3))
    c.cuerpo_elip(46, 92, 4, 7.5, col=hexa('e6d6a0'), d=1.2)
    c.cuerpo_elip(82, 92, 4, 7.5, col=hexa('e6d6a0'), d=1.2)


def coliseo(c):
    _cielo(c, hexa('f6dca4'))
    c.cuerpo([(0, 110), (128, 110), (128, 128), (0, 128)], hexa('d8be86'), d=2.4)
    c.cuerpo_elip(64, 44, 56, 16, col=hexa('d9c9a2'), d=2.0)
    c.elip(64, 44, 42, 10, hexa('b8a37a'))
    cuadro(c, 8, 44, 120, 108, hexa('d9c9a2'))
    for y_base in (62, 80, 98):
        _arcada(c, 12, 116, y_base, 12, 11, col=hexa('4a3f38'))
        c.rect(8, y_base - 14, 120, y_base - 12, hexa('c2b088'))
    c.cuerpo_elip(64, 108, 56, 7, col=hexa('d9c9a2'), d=1.6)


# ── Maravillas medievales ──
def santa_sofia(c):
    _cielo(c)
    c.cuerpo([(0, 112), (128, 112), (128, 128), (0, 128)], hexa('c9c3b6'), d=2.4)
    for x in (9, 119):
        cuadro(c, x - 3.5, 44, x + 3.5, 112, hexa('f1ede2'))
        c.cuerpo([(x - 5, 44), (x, 26), (x + 5, 44)], hexa('6a7690'), d=1.6)
        c.rect(x - 5, 58, x + 5, 61, hexa('c9c3b6'))
    cuadro(c, 22, 72, 106, 112, hexa('e8d6b0'))
    c.cuerpo_elip(30, 78, 12, 14, col=hexa('a6b3cb'), d=2.0)
    c.cuerpo_elip(98, 78, 12, 14, col=hexa('a6b3cb'), d=2.0)
    c.cuerpo(spline([(30, 74), (32, 46), (48, 28), (64, 24), (80, 28), (96, 46), (98, 74)]), hexa('9aa8c2'), sombra=0.26, luz=0.3, d=3.2)
    c.linea([(64, 24), (64, 12)], 2.4, ORO2)
    c.punto(64, 11, 3, ORO)
    for x in range(36, 96, 10):
        c.rect(x, 54, x + 5, 62, AMARILLO_V, r=1.2)
    for i in range(5):
        _arco_herradura(c, 28 + i * 14, 38 + i * 14, 112, 20, hexa('4a4458'))


def mezquita_cordoba(c):
    c.rect(0, 0, 128, 128, hexa('3d3340'))
    for i in range(4):
        x0 = 6 + i * 30
        _arco_herradura(c, x0, x0 + 28, 112, 80, hexa('f2ece0'))
        _arco_herradura(c, x0 + 3, x0 + 25, 112, 76, hexa('c4503b'))
        _arco_herradura(c, x0 + 6, x0 + 22, 112, 72, hexa('f2ece0'))
        _arco_herradura(c, x0 + 9, x0 + 19, 112, 66, hexa('3d3340'))
    for i in range(5):
        cuadro(c, 1 + i * 30, 56, 7 + i * 30, 112, hexa('d6c8a6'), sombra=0.22, luz=0.2, d=1.6)
    c.rect(0, 108, 128, 128, hexa('c8b88c'))
    c.linea([(0, 38), (128, 38)], 2.0, ORO2)


def borobudur(c):
    _cielo(c, hexa('a6dcc0'))
    c.cuerpo([(0, 100), (128, 100), (128, 128), (0, 128)], hexa('4f9a58'), d=2.4)
    for i, (x0, x1, y) in enumerate([(8, 120, 92), (18, 110, 78), (28, 100, 64), (38, 90, 50)]):
        cuadro(c, x0, y, x1, y + 14, hexa('9e9788') if i % 2 else hexa('b3ab9a'))
        for x in range(int(x0) + 8, int(x1) - 4, 14):
            c.cuerpo_elip(x, y + 6, 4.2, 5, col=hexa('c9c1ae'), d=1.2)
    cuadro(c, 48, 36, 80, 50, hexa('b3ab9a'))
    c.cuerpo(spline([(50, 40), (52, 24), (64, 16), (76, 24), (78, 40)]), hexa('c9c1ae'), d=2.2)
    c.linea([(64, 16), (64, 6)], 2.2, ORO2)


def angkor_wat(c):
    _cielo(c, hexa('f6c98a'))
    _sol(c, 100, 24, 9, hexa('ffe08a'))
    cuadro(c, 8, 84, 120, 100, hexa('a89a82'))
    cuadro(c, 22, 72, 106, 84, hexa('b3a68e'))
    for cx, h in ((64, 52), (36, 36), (92, 36), (16, 24), (112, 24)):
        base = 72 if h > 30 else 84
        cuadro(c, cx - 7, base - h * 0.45, cx + 7, base, hexa('b8ab92'))
        c.cuerpo([(cx - 8, base - h * 0.45), (cx - 4, base - h * 0.75), (cx - 2, base - h), (cx, base - h - 6), (cx + 2, base - h), (cx + 4, base - h * 0.75), (cx + 8, base - h * 0.45)], hexa('c4b79c'), d=1.8)
    c.rect(56, 62, 72, 72, hexa('4a4034'), r=1)
    c.cuerpo([(0, 100), (128, 100), (128, 128), (0, 128)], AGUA, sombra=0.1, luz=0.2, d=1.8)
    c.poly([(30, 106), (98, 106), (92, 112), (36, 112)], (255, 255, 255, 60))
    for x in (14, 40, 88, 112):
        c.punto(x, 114, 3.5, hexa('f48fb1'))


def alhambra(c):
    _cielo(c, hexa('a3d4f0'))
    c.cuerpo(spline([(0, 100), (14, 76), (44, 70), (84, 74), (114, 66), (128, 80), (128, 128), (0, 128)]), hexa('76b05c'), d=2.6)
    cuadro(c, 14, 64, 114, 108, hexa('d5a47c'))
    almenas(c, 14, 114, 64, hexa('d5a47c'), 7, 7)
    torre(c, 20, 108, 20, 52, hexa('c4906a'), n=2)
    torre(c, 108, 108, 20, 56, hexa('c4906a'), n=2)
    cuadro(c, 44, 40, 84, 80, hexa('e0b890'))
    c.cuerpo(spline([(46, 42), (52, 28), (64, 22), (76, 28), (82, 42)]), hexa('5ca0a8'), sombra=0.26, luz=0.3, d=2.4)
    _arco_herradura(c, 54, 74, 108, 30, hexa('4a3a34'))
    for x in (34, 94):
        ventana(c, x, 76, 6, 9, hexa('4a3a34'))
    c.rect(60, 38, 68, 46, AMARILLO_V, r=1)


def machu_picchu(c):
    _cielo(c, hexa('b2dcf0'))
    _nube(c, 96, 20, 0.9)
    c.cuerpo([(40, 90), (64, 16), (88, 90)], hexa('5fa05a'), sombra=0.3, luz=0.2, d=3.0)
    c.poly([(64, 16), (88, 90), (74, 90), (64, 44)], hexa('3f7d46'))
    c.cuerpo([(0, 128), (0, 74), (36, 92), (96, 88), (128, 70), (128, 128)], hexa('76b05c'), d=2.6)
    for i in range(5):
        y = 90 + i * 8
        c.cuerpo([(6 + i * 3, y), (122 - i * 3, y), (122 - i * 3, y + 6), (6 + i * 3, y + 6)], hexa('9a9484') if i % 2 else hexa('b0a998'), sombra=0.2, luz=0.2, d=1.4)
        c.rect(6 + i * 3, y - 2, 122 - i * 3, y + 1, hexa('6fb060'))
    for x in (30, 52, 84):
        casa(c, x, x + 14, 92, 9, hexa('b0a998'), PAJA, pico=7, puerta_=False)


# ── Maravillas modernas, palacios y obras ──
def taj_mahal(c):
    _cielo(c, hexa('f2d3a8'))
    _sol(c, 104, 22, 8, hexa('ffe08a'))
    for x in (10, 118):
        cuadro(c, x - 3, 36, x + 3, 100, hexa('f6f2ea'))
        c.cuerpo_elip(x, 34, 4, 4, col=hexa('f6f2ea'), d=1.2)
        c.rect(x - 4, 52, x + 4, 54, hexa('d8d2c4'))
    cuadro(c, 24, 66, 104, 100, hexa('f6f2ea'))
    c.cuerpo(spline([(40, 66), (40, 46), (50, 26), (64, 20), (78, 26), (88, 46), (88, 66)]), hexa('f6f2ea'), sombra=0.18, luz=0.1, d=3.2)
    c.linea([(64, 20), (64, 8)], 2.0, ORO2)
    for x in (30, 98):
        c.cuerpo(spline([(x - 6, 66), (x - 5, 56), (x, 50), (x + 5, 56), (x + 6, 66)]), hexa('f6f2ea'), d=1.6)
    _arco_herradura(c, 54, 74, 100, 30, hexa('4a5a8a'))
    c.cuerpo([(0, 100), (128, 100), (128, 128), (0, 128)], hexa('8ec0e0'), sombra=0.1, luz=0.2, d=1.6)
    c.poly([(30, 104), (98, 104), (92, 112), (36, 112)], (246, 242, 234, 110))


def cristo_redentor(c):
    _cielo(c, hexa('9ed2f0'))
    _nube(c, 24, 28, 0.9)
    _nube(c, 104, 46, 0.7)
    c.cuerpo([(0, 128), (0, 92), (36, 80), (64, 84), (96, 78), (128, 92), (128, 128)], hexa('4f9a58'), d=2.6)
    cuadro(c, 50, 78, 78, 92, hexa('b8b2a4'))
    cuadro(c, 54, 66, 74, 80, hexa('c9c3b6'))
    c.cuerpo([(56, 68), (72, 68), (74, 34), (54, 34)], hexa('f2efe6'), sombra=0.2, luz=0.1, d=2.4)
    c.cuerpo([(8, 34), (120, 34), (118, 40), (74, 44), (54, 44), (10, 40)], hexa('f2efe6'), sombra=0.2, luz=0.1, d=2.2)
    c.cuerpo_elip(64, 26, 6.5, 7.5, col=hexa('f2efe6'), d=1.6)


def megatorre_record(c):
    _cielo(c, hexa('7fb8e8'))
    _nube(c, 28, 40, 0.8)
    _nube(c, 100, 70, 0.8)
    c.cuerpo([(0, 118), (128, 118), (128, 128), (0, 128)], hexa('7c8497'), d=2.0)
    for (x0, x1, y0, col_) in ((6, 28, 84, hexa('8aa6d6')), (100, 122, 76, hexa('8aa6d6'))):
        cuadro(c, x0, y0, x1, 118, col_)
    for (x0, x1, y0) in ((46, 82, 70), (52, 76, 48), (57, 71, 28), (61, 67, 12)):
        cuadro(c, x0, y0, x1, 118, hexa('b6d0f2'), d=2.4)
    c.linea([(64, 12), (64, 1)], 2.0, ACERO)
    for k in range(10):
        for i in range(3):
            c.rect(50 + i * 10, 74 + k * 4.2, 56 + i * 10, 76.5 + k * 4.2, hexa('e8f2ff') if (i + k) % 3 else AMARILLO_V, r=0.6)
    c.rect(60, 100, 68, 118, hexa('2a3550'), r=1)


def ciudad_prohibida(c):
    _cielo(c, hexa('f2d2a0'))
    cuadro(c, 6, 86, 122, 112, ROJO_PALACIO)
    c.rect(2, 108, 126, 118, hexa('e9e0cc'), r=1.5)
    for cx, y, a, col_ in ((64, 40, 40, DORADO_TEJA), (64, 62, 52, DORADO_TEJA)):
        c.cuerpo([(cx - a - 6, y + 10), (cx - a + 6, y), (cx + a - 6, y), (cx + a + 6, y + 10)], col_, sombra=0.24, luz=0.26, d=2.4)
    cuadro(c, 30, 62, 98, 90, ROJO_PALACIO)
    cuadro(c, 40, 50, 88, 62, hexa('9a2f2c'))
    for x in range(36, 96, 10):
        c.rect(x, 66, x + 5, 90, hexa('6e1d1d'))
    c.cuerpo([(50, 40), (64, 28), (78, 40)], DORADO_TEJA, d=2.0)
    c.rect(56, 92, 72, 108, hexa('2c1a14'), r=1)
    torre(c, 14, 112, 18, 38, ROJO_PALACIO, techo=DORADO_TEJA)
    torre(c, 114, 112, 18, 38, ROJO_PALACIO, techo=DORADO_TEJA)


def versalles(c):
    _cielo(c, hexa('a3d4f0'))
    c.cuerpo([(0, 96), (128, 96), (128, 128), (0, 128)], hexa('6dbf62'), d=2.4)
    cuadro(c, 8, 54, 120, 92, hexa('efe3c8'))
    for (x0, x1) in ((4, 36), (92, 124)):
        cuadro(c, x0, 46, x1, 92, hexa('e8dabc'))
        c.cuerpo([(x0 - 2, 46), (x0 + 6, 34), (x1 - 6, 34), (x1 + 2, 46)], hexa('6a7a96'), sombra=0.24, luz=0.2, d=2.2)
    cuadro(c, 44, 40, 84, 92, hexa('f4e9cf'))
    c.cuerpo([(42, 40), (50, 26), (78, 26), (86, 40)], hexa('6a7a96'), d=2.2)
    c.linea([(64, 26), (64, 16)], 2, ORO2)
    for y in (58, 72):
        for x in range(12, 118, 11):
            if 44 < x < 84:
                continue
            ventana(c, x, y, 6, 9, hexa('7fa3d0'))
    for x in range(50, 80, 10):
        ventana(c, x, 52, 6, 14, hexa('7fa3d0'))
    for i in range(6):
        c.cuerpo_elip(14 + i * 20, 106, 8, 4, col=hexa('3f8f46'), d=1.4)
    c.poly([(54, 96), (74, 96), (96, 128), (32, 128)], hexa('c8b784'))
    c.cuerpo_elip(64, 112, 9, 4, col=AGUA_C, d=1.2)


def gran_muralla(c):
    _cielo(c, hexa('b4dcf0'))
    c.cuerpo([(0, 128), (0, 80), (24, 56), (52, 70), (80, 40), (110, 58), (128, 44), (128, 128)], hexa('7da060'), sombra=0.28, luz=0.2, d=3.0)
    c.cuerpo([(0, 128), (0, 100), (30, 84), (60, 96), (90, 70), (128, 82), (128, 128)], hexa('5f8a52'), sombra=0.28, luz=0.2, d=3.0)
    pts = [(-4, 98), (26, 88), (56, 98), (88, 74), (132, 84)]
    c.linea(pts, 9, hexa('a69c88'))
    c.linea([(p[0], p[1] - 4) for p in pts], 3, hexa('c4baa4'))
    for (x, y) in ((30, 88), (88, 74), (112, 79)):
        cuadro(c, x - 9, y - 22, x + 9, y + 2, hexa('b3a98f'))
        almenas(c, x - 10, x + 10, y - 22, hexa('b3a98f'), 3, 6)
        c.rect(x - 2.5, y - 16, x + 2.5, y - 8, hexa('3d3a46'), r=1)
    for k in range(7):
        c.linea([(8 + k * 18, 108 + (k % 2) * 4), (14 + k * 18, 104 + (k % 2) * 4)], 1.2, hexa('3f7d46'))


def torre_eiffel(c):
    _cielo(c, hexa('f0b9a0'), hexa('e8a090'))
    _sol(c, 106, 30, 8, hexa('fff0b0'))
    c.cuerpo([(0, 114), (128, 114), (128, 128), (0, 128)], hexa('6b8a52'), d=2.0)
    fe = hexa('7b5a44')
    fe2 = hexa('4d3a2e')
    c.poly([(30, 114), (50, 74), (56, 74), (48, 114)], fe)
    c.poly([(98, 114), (78, 74), (72, 74), (80, 114)], fe)
    c.poly([(46, 74), (82, 74), (80, 66), (48, 66)], fe)
    c.cuerpo([(50, 66), (78, 66), (70, 34), (58, 34)], fe, sombra=0.3, luz=0.15, d=2.4)
    c.cuerpo([(58, 34), (70, 34), (65, 10), (63, 10)], fe, d=1.6)
    c.linea([(64, 10), (64, 2)], 1.6, fe2)
    c.poly([(54, 114), (74, 114), (70, 90), (58, 90)], hexa('f0b9a0'))
    c.rect(28, 112, 100, 116, fe2)
    for (xa, ya, xb, yb) in ((52, 74, 76, 66), (76, 74, 52, 66), (58, 66, 70, 52), (70, 66, 58, 52), (60, 52, 68, 38), (68, 52, 60, 38), (38, 100, 52, 76), (90, 100, 76, 76)):
        c.linea([(xa, ya), (xb, yb)], 1.2, fe2)


def presa_tres_gargantas(c):
    _cielo(c, hexa('a6d4ec'))
    c.cuerpo([(0, 70), (24, 50), (28, 128), (0, 128)], hexa('6f9a58'), d=2.4)
    c.cuerpo([(128, 70), (104, 50), (100, 128), (128, 128)], hexa('6f9a58'), d=2.4)
    c.cuerpo([(20, 56), (108, 56), (116, 108), (12, 108)], HORMIGON, sombra=0.24, luz=0.26, d=3.0)
    c.rect(20, 52, 108, 58, hexa('d0d4da'), r=1.2)
    for i in range(7):
        x = 24 + i * 12.5
        c.rect(x, 62, x + 6, 74, hexa('5a6478'), r=1)
        c.poly([(x, 74), (x + 6, 74), (x + 8, 108), (x - 2, 108)], hexa('cfe8f8'))
    c.rect(0, 106, 128, 128, AGUA)
    c.poly([(12, 108), (116, 108), (122, 116), (6, 116)], hexa('e8f6ff'))
    c.rect(18, 36, 30, 52, hexa('8e96a4'), r=1)
    c.linea([(24, 36), (24, 26)], 2, ACERO)
    c.rect(98, 36, 110, 52, hexa('8e96a4'), r=1)


def cosmodromo(c):
    _cielo(c, hexa('16203c'))
    for (x, y) in ((14, 14), (40, 30), (98, 16), (116, 40), (24, 56), (108, 66)):
        c.punto(x, y, 1.4, hexa('fff4c0'))
    c.cuerpo([(0, 112), (128, 112), (128, 128), (0, 128)], hexa('6e7480'), d=2.0)
    cuadro(c, 70, 24, 80, 112, hexa('c24a3a'), sombra=0.2, luz=0.2, d=1.6)
    for y in range(32, 108, 12):
        c.linea([(70, y), (80, y + 10)], 1, hexa('7a2f26'))
    c.linea([(70, 54), (62, 54)], 3, hexa('c24a3a'))
    c.linea([(70, 78), (62, 78)], 3, hexa('c24a3a'))
    c.cuerpo([(48, 108), (48, 50), (55, 28), (62, 50), (62, 108)], hexa('eef1f6'), sombra=0.24, luz=0.1, d=2.4)
    c.cuerpo([(48, 92), (38, 108), (48, 108)], hexa('e0605a'), d=1.4)
    c.cuerpo([(62, 92), (72, 108), (62, 108)], hexa('e0605a'), d=1.4)
    c.punto(55, 62, 4, hexa('4a78c8'))
    c.poly([(46, 112), (64, 112), (60, 124), (50, 124)], (255, 150, 50, 200))
    _flama(c, 55, 124, 1.0)
    c.poly([(8, 112), (30, 112), (24, 104), (14, 104)], hexa('9aa3b4'))


def colisionador_particulas(c):
    c.rect(0, 0, 128, 128, hexa('1c2340'))
    c.elip(64, 66, 54, 44, hexa('5a6a9a'))
    c.elip(64, 66, 46, 36, hexa('1c2340'))
    c.elip(64, 66, 50, 40, hexa('8ea2d8'))
    c.elip(64, 66, 47, 37, hexa('1c2340'))
    c.elip(64, 66, 42, 32, hexa('4f7ad8'))
    c.elip(64, 66, 39, 29, hexa('1c2340'))
    for k in range(8):
        a = math.radians(k * 45 + 20)
        c.cuerpo_elip(64 + 48 * math.cos(a), 66 + 38 * math.sin(a), 4, 3.4, col=hexa('e0605a'), d=1.2)
    c.punto(64, 66, 14, (110, 170, 255, 120))
    c.punto(64, 66, 7, hexa('cfe4ff'))
    for k in range(10):
        a = math.radians(k * 36)
        c.linea([(64, 66), (64 + 26 * math.cos(a), 66 + 20 * math.sin(a))], 1.6, hexa('ffd45e'))
    c.cuerpo_elip(64, 108, 18, 6, col=hexa('9aa3b4'), d=1.6)


# ── Edificios corrientes ──
def minas_subterraneas(c):
    _cielo(c, hexa('a6d0ea'))
    c.cuerpo([(0, 128), (0, 66), (34, 44), (64, 34), (96, 46), (128, 66), (128, 128)], hexa('8a7a68'), sombra=0.28, luz=0.2, d=3.0)
    c.poly([(40, 50), (64, 34), (88, 50), (96, 62), (30, 62)], hexa('9a8a76'))
    c.cuerpo([(42, 112), (46, 72), (82, 72), (86, 112)], hexa('2a1f18'))
    c.linea([(40, 112), (44, 70)], 5, MADERA)
    c.linea([(88, 112), (84, 70)], 5, MADERA)
    c.linea([(40, 71), (88, 71)], 5, MADERA_O)
    c.linea([(0, 118), (128, 118)], 2.2, ACERO_O)
    for x in range(6, 124, 12):
        c.linea([(x, 112), (x, 124)], 2.4, MADERA_O)
    c.cuerpo([(56, 106), (86, 106), (82, 116), (60, 116)], hexa('7d8aa0'), d=1.8)
    c.cuerpo_elip(71, 102, 14, 5, col=hexa('c78a4a'), d=1.4)
    c.punto(62, 118, 3.2, OSCURO_V)
    c.punto(82, 118, 3.2, OSCURO_V)
    c.linea([(104, 98), (118, 84)], 2.6, MADERA)
    c.cuerpo([(112, 80), (124, 82), (120, 88)], ACERO, d=1.2)


def canales_riego(c):
    _cielo(c, hexa('bfe3f0'))
    c.rect(0, 52, 128, 128, hexa('7fb45a'))
    for i in range(6):
        y = 60 + i * 11
        c.poly([(0, y), (128, y - 4), (128, y + 3), (0, y + 7)], hexa('5fa04a') if i % 2 else hexa('8cc064'))
    c.poly([(54, 52), (74, 52), (86, 128), (42, 128)], AGUA)
    c.poly([(60, 52), (68, 52), (73, 128), (55, 128)], AGUA_C)
    c.linea([(0, 82), (128, 76)], 5, AGUA)
    c.linea([(0, 104), (128, 100)], 5, AGUA)
    c.cuerpo([(0, 52), (128, 52), (128, 60), (0, 60)], hexa('8a6a42'), d=1.6)
    for x in (16, 104):
        arbol(c, x, 52, r=8)
    _sol(c, 104, 20, 9)


def aduana_puesto_fronterizo(c):
    _cielo(c, hexa('a8d6ee'))
    c.cuerpo([(0, 96), (128, 96), (128, 128), (0, 128)], hexa('b8a88a'), d=2.2)
    c.rect(0, 100, 128, 112, hexa('8a8f9a'))
    c.linea([(0, 106), (128, 106)], 1.4, hexa('f2f5ff'))
    casa(c, 80, 118, 96, 36, hexa('e0d6bc'), TEJA, pico=14)
    c.linea([(18, 100), (18, 64)], 4, hexa('6e7480'))
    c.linea([(18, 76), (74, 70)], 6, hexa('f2f5ff'))
    for x in range(26, 74, 16):
        c.linea([(x, 75 - (x - 26) * 0.1), (x + 8, 74 - (x - 26) * 0.1)], 6, ROJO)
    bandera_asta(c, 100, 56, 30, hexa('3a7ad8'), 18)


def termas_publicas(c):
    _cielo(c, hexa('d6ecf6'))
    cuadro(c, 6, 50, 122, 112, hexa('e8dcc2'))
    c.cuerpo(spline([(26, 50), (28, 30), (64, 16), (100, 30), (102, 50)]), hexa('d4c4a2'), d=2.6)
    for i in range(5):
        _arco_herradura(c, 12 + i * 22, 28 + i * 22, 82, 24, hexa('58a8e6'))
    c.rect(6, 82, 122, 112, hexa('58a8e6'))
    c.rect(6, 82, 122, 86, hexa('9fd4f6'))
    for x in range(14, 120, 22):
        columna(c, x, 56, 84, w=6)
    for x in (30, 62, 94):
        for dy in (0, 1, 2):
            c.linea(spline([(x, 46 - dy * 8), (x + 4, 40 - dy * 8), (x - 3, 34 - dy * 8)], cerrada=False), 2.2, (255, 255, 255, 190))
    olas(c, 100, 8, 120, hexa('9fd4f6'), 6)


def casa_de_moneda(c):
    _cielo(c, hexa('d7e4f0'))
    c.cuerpo([(0, 112), (128, 112), (128, 128), (0, 128)], hexa('9a9484'), d=2.0)
    cuadro(c, 8, 62, 120, 112, hexa('d8ccae'))
    c.cuerpo([(4, 62), (64, 36), (124, 62)], hexa('b8a888'), d=2.4)
    for x in (16, 100):
        columna(c, x, 66, 108, w=8)
    c.cuerpo_elip(64, 80, 22, 22, col=ORO, sombra=0.3, luz=0.4, d=2.6)
    c.elip(64, 80, 16, 16, ORO2)
    c.elip(64, 80, 13, 13, ORO)
    c.linea([(64, 68), (64, 92)], 3.2, ORO2)
    c.linea([(56, 74), (72, 74)], 3.0, ORO2)
    c.linea([(56, 86), (72, 86)], 3.0, ORO2)
    c.cuerpo([(30, 106), (50, 106), (48, 112), (32, 112)], ACERO_O, d=1.4)


def puerto_pesquero(c):
    _cielo(c, hexa('b4dcf0'))
    c.rect(0, 78, 128, 128, AGUA)
    olas(c, 92, 0, 128, claro(AGUA, 0.3), 8)
    olas(c, 112, 0, 128, hexa('3f8fd0'), 8)
    c.cuerpo([(34, 78), (96, 78), (88, 96), (42, 96)], hexa('c0553f'), sombra=0.26, luz=0.2, d=2.6)
    c.rect(34, 80, 96, 83, hexa('f2f5ff'))
    c.linea([(66, 78), (66, 30)], 3, MADERA_O)
    c.cuerpo([(68, 34), (68, 74), (100, 74)], hexa('f4ecd6'), d=2.0)
    c.cuerpo([(64, 40), (64, 74), (42, 74)], hexa('e8dcbc'), d=2.0)
    c.cuerpo([(0, 70), (24, 70), (24, 128), (0, 128)], hexa('8a6a42'))
    for y in (74, 94, 114):
        c.linea([(0, y), (24, y)], 2.0, MADERA_O)
    c.cuerpo_elip(104, 108, 11, 5, col=hexa('c9d4e8'), d=1.2)
    c.poly([(115, 108), (124, 102), (124, 114)], hexa('c9d4e8'))
    c.punto(98, 106, 1.5, OSCURO_V)


def campo_adiestramiento(c):
    _cielo(c, hexa('b4dcf0'))
    c.cuerpo([(0, 78), (128, 70), (128, 128), (0, 128)], hexa('7fb45a'), d=2.4)
    for (x, y, s) in ((26, 92, 1.0), (64, 86, 0.8), (98, 94, 1.1)):
        c.cuerpo([(x - 22 * s, y), (x, y - 30 * s), (x + 22 * s, y)], hexa('d8cfae'), sombra=0.26, luz=0.2, d=2.4)
        c.poly([(x - 5 * s, y), (x, y - 14 * s), (x + 5 * s, y)], hexa('4a3f34'))
    bandera_asta(c, 64, 82, 38, ROJO, 20)
    c.punto(14, 112, 8, hexa('f2f5ff'))
    c.punto(14, 112, 5.2, ROJO)
    c.punto(14, 112, 2.2, hexa('f2f5ff'))
    c.linea([(14, 120), (14, 128)], 2.4, MADERA_O)
    for k in range(4):
        c.rect(46 + k * 12, 108, 51 + k * 12, 120, hexa('4a5a3a'), r=2)
        c.punto(48.5 + k * 12, 105, 3.2, hexa('d8a878'))


def base_naval(c):
    _cielo(c, hexa('b4dcf0'))
    c.rect(0, 84, 128, 128, hexa('3f8fd0'))
    olas(c, 96, 0, 128, claro(AGUA, 0.15), 8)
    c.cuerpo([(8, 92), (120, 92), (108, 106), (20, 106)], hexa('7b8497'), sombra=0.26, luz=0.2, d=2.6)
    cuadro(c, 40, 76, 78, 92, hexa('9aa3b4'))
    cuadro(c, 52, 64, 70, 76, hexa('b4bccb'))
    c.linea([(60, 64), (60, 48)], 2.4, hexa('6e7480'))
    c.linea([(54, 54), (68, 54)], 2, hexa('6e7480'))
    c.linea([(80, 80), (104, 74)], 3.4, hexa('5a6478'))
    c.linea([(18, 86), (36, 82)], 3.4, hexa('5a6478'))
    c.rect(0, 100, 20, 128, hexa('9a9484'))
    c.linea([(8, 100), (8, 60)], 4, hexa('c24a3a'))
    c.linea([(8, 62), (30, 62)], 3.4, hexa('c24a3a'))
    c.linea([(28, 62), (28, 74)], 1.2, hexa('4a4a4a'))
    c.cuerpo([(100, 100), (126, 100), (126, 128), (100, 128)], hexa('9a9484'))
    c.linea([(113, 104), (113, 122)], 2.4, hexa('3d3a46'))
    c.elip(113, 118, 7, 5, hexa('3d3a46'))


def refineria_petroleo(c):
    _cielo(c, hexa('c8d4e0'))
    c.cuerpo([(0, 112), (128, 112), (128, 128), (0, 128)], hexa('6a6f7a'), d=2.0)
    for x, h, w in ((20, 70, 14), (44, 88, 12), (66, 60, 16)):
        c.cuerpo([(x - w / 2, 112), (x - w / 2, 112 - h), (x + w / 2, 112 - h), (x + w / 2, 112)], hexa('b4bccb'), sombra=0.26, luz=0.3, d=2.4)
        for yy in range(int(112 - h + 10), 108, 14):
            c.linea([(x - w / 2, yy), (x + w / 2, yy)], 1.4, hexa('7b8497'))
    c.linea([(20, 44), (44, 24), (66, 52)], 2.4, hexa('7b8497'))
    c.linea([(20, 100), (66, 90), (100, 98)], 2.4, hexa('c24a3a'))
    c.cuerpo([(92, 112), (92, 36), (100, 36), (100, 112)], hexa('9aa3b4'), d=2.0)
    _flama(c, 96, 36, 1.0)
    c.cuerpo_elip(112, 100, 10, 12, col=hexa('d86a2a'), d=1.8)
    c.rect(102, 94, 122, 98, hexa('3d3a46'))
    c.rect(102, 104, 122, 108, hexa('3d3a46'))
    c.punto(96, 22, 4, (80, 80, 90, 140))
    c.punto(104, 14, 5, (80, 80, 90, 110))


def fabrica_automoviles(c):
    _cielo(c, hexa('bcd8ee'))
    c.cuerpo([(0, 108), (128, 108), (128, 128), (0, 128)], hexa('6a6f7a'), d=2.0)
    cuadro(c, 6, 60, 122, 108, hexa('c8826a'))
    for i in range(4):
        x = 6 + i * 29
        c.poly([(x, 60), (x + 29, 60), (x + 29, 44)], hexa('8a99b0'))
        c.cuerpo([(x, 60), (x, 44), (x + 29, 60)], hexa('7b8aa2'), d=1.4)
    c.rect(10, 70, 118, 82, hexa('bfe0f4'))
    c.linea([(40, 70), (40, 82)], 1.2, hexa('7b8497'))
    c.linea([(78, 70), (78, 82)], 1.2, hexa('7b8497'))
    cuadro(c, 100, 22, 110, 60, hexa('9a5a48'))
    humo(c, 104, 20, 3)
    c.cuerpo([(30, 108), (34, 98), (46, 92), (68, 92), (80, 98), (98, 100), (100, 108)], hexa('d8453a'), sombra=0.26, luz=0.3, d=2.4)
    c.poly([(46, 98), (50, 94), (66, 94), (74, 98)], hexa('bfe0f4'))
    c.punto(44, 108, 7, hexa('2a2f42'))
    c.punto(44, 108, 3, hexa('b4bccb'))
    c.punto(86, 108, 7, hexa('2a2f42'))
    c.punto(86, 108, 3, hexa('b4bccb'))


def base_aerea(c):
    _cielo(c, hexa('9ed2f0'))
    _nube(c, 26, 26, 0.9)
    c.cuerpo([(0, 72), (128, 72), (128, 128), (0, 128)], hexa('7a8f6a'), d=2.4)
    c.poly([(54, 72), (74, 72), (112, 128), (16, 128)], hexa('5a6070'))
    for k in range(5):
        y = 80 + k * 10
        h = 1.2 + k * 0.5
        c.rect(64 - h, y, 64 + h, y + 4 + k, hexa('f2f5ff'))
    c.cuerpo([(8, 74), (8, 60), (34, 52), (34, 74)], hexa('9aa3b4'), sombra=0.26, luz=0.2, d=2.2)
    c.poly([(8, 60), (34, 52), (34, 56), (8, 66)], hexa('7b8497'))
    c.cuerpo([(70, 40), (112, 38), (122, 42), (112, 46), (70, 46)], hexa('9aa3b4'), d=1.8)
    c.cuerpo([(92, 42), (82, 22), (88, 22), (104, 40)], hexa('7b8aa0'), d=1.4)
    c.cuerpo([(92, 46), (82, 62), (88, 62), (104, 46)], hexa('7b8aa0'), d=1.4)
    c.cuerpo([(74, 40), (68, 30), (72, 30), (80, 40)], hexa('7b8aa0'), d=1.2)
    c.punto(120, 42, 2.4, ROJO)


def planta_quimica(c):
    _cielo(c, hexa('cfdce8'))
    c.cuerpo([(0, 112), (128, 112), (128, 128), (0, 128)], hexa('6a6f7a'), d=2.0)
    c.cuerpo_elip(32, 84, 22, 22, col=hexa('b8c4d8'), sombra=0.26, luz=0.3, d=2.6)
    c.cuerpo_elip(32, 84, 15, 15, col=hexa('9fb0cc'), d=1.8)
    cuadro(c, 24, 100, 40, 112, hexa('7b8497'))
    cuadro(c, 58, 52, 80, 112, hexa('d8b44a'), sombra=0.26, luz=0.25, d=2.4)
    c.cuerpo_elip(69, 52, 11, 5, col=hexa('e8c86a'), d=1.2)
    for yy in (68, 84, 98):
        c.linea([(58, yy), (80, yy)], 1.4, hexa('9a7a24'))
    cuadro(c, 94, 40, 110, 112, hexa('b4bccb'), d=2.2)
    c.linea([(32, 62), (32, 50), (69, 50)], 2.6, hexa('c24a3a'))
    c.linea([(80, 70), (94, 70)], 2.6, hexa('4a8a50'))
    c.linea([(46, 92), (58, 92)], 2.6, hexa('4a78c8'))
    c.cuerpo([(102, 40), (104, 28), (108, 28), (110, 40)], hexa('9aa3b4'), d=1.2)
    humo(c, 106, 26, 3)
    c.cuerpo([(8, 112), (8, 100), (16, 100), (18, 90), (26, 90), (28, 100), (36, 100), (36, 112)], (160, 220, 180, 170), sombra=0, luz=0)


def viviendas_publicas(c):
    _cielo(c, hexa('a6d0ee'))
    c.cuerpo([(0, 112), (128, 112), (128, 128), (0, 128)], hexa('76a86a'), d=2.0)
    for (x0, x1, y0, col_) in ((4, 44, 44, hexa('d8ccb4')), (48, 82, 28, hexa('cfc4aa')), (86, 124, 56, hexa('d8ccb4'))):
        cuadro(c, x0, y0, x1, 112, col_, d=2.8)
        c.rect(x0 - 1.5, y0 - 3, x1 + 1.5, y0, hexa('9a948a'))
        for k in range(int((112 - y0 - 8) // 12)):
            for x in range(int(x0) + 5, int(x1) - 7, 11):
                c.rect(x, y0 + 7 + k * 12, x + 6, y0 + 14 + k * 12, hexa('8aa6c8') if (x + k) % 3 else AMARILLO_V, r=0.8)
        c.rect((x0 + x1) / 2 - 4, 98, (x0 + x1) / 2 + 4, 112, hexa('5a4a3a'), r=1)
    for x in (18, 62, 106):
        arbol(c, x, 120, r=7, col=CESPED)


def fabrica_semiconductores(c):
    c.rect(0, 0, 128, 128, hexa('d8e4f2'))
    c.cuerpo([(16, 20), (112, 20), (112, 108), (16, 108)], hexa('2f3a58'), sombra=0.26, luz=0.2, d=3.0)
    for k in range(9):
        y = 28 + k * 9
        c.rect(6, y, 16, y + 4, hexa('c8cdd8'))
        c.rect(112, y, 122, y + 4, hexa('c8cdd8'))
        x = 24 + k * 9.6
        c.rect(x, 10, x + 4, 20, hexa('c8cdd8'))
        c.rect(x, 108, x + 4, 118, hexa('c8cdd8'))
    c.cuerpo([(30, 34), (98, 34), (98, 94), (30, 94)], hexa('46557e'), d=2.0)
    for k in range(5):
        c.linea([(36, 44 + k * 10), (92, 44 + k * 10)], 1.4, hexa('7fa0e8'))
        c.linea([(44 + k * 11, 38), (44 + k * 11, 90)], 1.4, hexa('7fa0e8'))
    c.cuerpo([(52, 52), (76, 52), (76, 76), (52, 76)], hexa('1e263c'), d=1.8)
    c.rect(58, 58, 70, 70, hexa('f2c94c'), r=1.5)
    c.punto(28, 28, 2.4, hexa('f2c94c'))


def centro_datos(c):
    c.rect(0, 0, 128, 128, hexa('c8d4e6'))
    for i in range(3):
        x = 8 + i * 40
        c.cuerpo([(x, 22), (x + 34, 22), (x + 34, 112), (x, 112)], hexa('3a4466'), sombra=0.26, luz=0.2, d=2.6)
        for k in range(9):
            y = 28 + k * 9.6
            c.rect(x + 4, y, x + 30, y + 6.6, hexa('2a3250'), r=1)
            c.punto(x + 8, y + 3.3, 1.7, hexa('6fe08a') if (i + k) % 3 else hexa('ffb347'))
            c.rect(x + 16, y + 2, x + 28, y + 4.6, hexa('59658c'))
    c.rect(0, 112, 128, 128, hexa('8a93a8'))
    c.linea([(0, 118), (128, 118)], 2, hexa('f2c94c'))
    c.poly([(40, 14), (88, 14), (84, 6), (44, 6)], hexa('7aa8f0'))


# Las maravillas llevan una estrella dorada en la esquina: se distinguen de los edificios corrientes en cualquier lista.
def _con_estrella(f):
    def g(c):
        f(c)
        c.punto(106, 22, 15, (24, 28, 48, 210))
        c.cuerpo(estrella(106, 22, 13, 5.6, 5), ORO, sombra=0.25, luz=0.4, d=1.4)
        c.elip(106, 22, 2.4, 2.4, ORO2)
    return g


for _n in ("piramides_giza", "jardines_colgantes", "partenon", "coloso_rodas", "gran_biblioteca_alejandria", "coliseo", "santa_sofia", "mezquita_cordoba", "borobudur",
		"angkor_wat", "alhambra", "machu_picchu", "taj_mahal", "cristo_redentor", "megatorre_record", "ciudad_prohibida", "versalles", "gran_muralla", "torre_eiffel",
		"presa_tres_gargantas", "cosmodromo", "colisionador_particulas"):
    globals()[_n] = _con_estrella(globals()[_n])


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
