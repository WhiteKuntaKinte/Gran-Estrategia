"""Iconos de la interfaz (0.1.8.41): los de siempre (iconos/i_*.png) redibujados a 128 px con el mismo estilo que los de materias, sectores y monedas.
Mismos nombres de archivo que antes, así que el juego los usa sin tocar nada. Los de una sola tinta (i_vel1..6, i_pausa, i_tpausa, i_atras, i_lentes) son llanos y blancos: el HUD los tiñe con el color del tema,
y se leen bien a 20 px en la barra de arriba."""
import math

from lienzo import *
import divisas

AZUL_C = hexa('8fb4f4')
AZUL_M = hexa('5f8fe0')
AZUL_O = hexa('3a62b8')
BLANCO_AZ = hexa('eaf0ff')
GRIS_AZ = hexa('8795b4')
GRIS_AZ2 = hexa('5f6c88')
PIEDRA = hexa('a5a09a')
PIEDRA2 = hexa('7d786f')
TIERRA = hexa('8b6a4a')
HOGUERA = hexa('f57f2a')
LLAMA = hexa('ffc83d')
TURQ = hexa('4fcfc0')
PAPEL = hexa('f6efdc')
TINTA = hexa('f0f4ff')           # los iconos de una sola tinta (barra, pausa, velocidad, atrás, lupa): el HUD los tiñe con el color del tema (`_tintar_icono`), así que van llanos


# ───────────── piezas sueltas ─────────────
def _globo(c, cx, cy, r, mar=AZUL_M, tierra=VERDE2, detalle=True):
    """Esfera azul con continentes y brillo."""
    m = c.cuerpo_elip(cx, cy, r, col=mar, sombra=0.30, luz=0.0, d=3.4)
    if detalle:
        def tierras(t):
            t.poly(spline([(cx - r * 0.62, cy - r * 0.35), (cx - r * 0.30, cy - r * 0.62), (cx + r * 0.05, cy - r * 0.40), (cx - r * 0.05, cy - r * 0.05),
                           (cx - r * 0.35, cy + r * 0.05), (cx - r * 0.60, cy - r * 0.02)]), tierra)
            t.poly(spline([(cx + r * 0.20, cy - r * 0.10), (cx + r * 0.55, cy - r * 0.30), (cx + r * 0.78, cy + r * 0.05), (cx + r * 0.50, cy + r * 0.38),
                           (cx + r * 0.25, cy + r * 0.25)]), tierra)
            t.poly(spline([(cx - r * 0.35, cy + r * 0.35), (cx - r * 0.05, cy + r * 0.28), (cx + r * 0.02, cy + r * 0.62), (cx - r * 0.25, cy + r * 0.72)]), tierra)
        c.recortada(m, tierras)
        c.recortada(m, lambda t: t.elip(cx - r * 0.35, cy - r * 0.45, r * 0.55, r * 0.28, (255, 255, 255, 70), -35))
    return m


# ───────────── iconos ─────────────
def alt(c):
    fondo = hexa('7f93b8')
    c.cuerpo([(52, 106), (96, 46), (124, 106)], hexa('94a6c8'), sombra=0.22, luz=0.25)
    m = c.cuerpo([(4, 110), (50, 30), (100, 110)], fondo, sombra=0.24, luz=0.25)
    c.recortada(m, lambda t: t.poly([(0, 0), (128, 0), (128, 54), (82, 50), (72, 62), (60, 50), (50, 64), (40, 50), (28, 58), (0, 56)], BLANCO))
    c.cuerpo([(96, 46), (106, 60), (99, 58), (94, 66), (88, 57), (82, 62)], BLANCO, sombra=0.12, luz=0.0, d=2.0)
    c.rect(2, 108, 126, 116, hexa('6c7aa0'), r=3)


def area(c):
    c.cuerpo([(30, 30), (98, 30), (98, 98), (30, 98)], hexa('7fdfae'), sombra=0.22, luz=0.30, d=3.2)
    c.rect(38, 38, 90, 90, hexa('a9efc8'), r=2)
    for (x, y, sx, sy) in ((14, 14, 1, 1), (114, 14, -1, 1), (14, 114, 1, -1), (114, 114, -1, -1)):
        c.poly([(x, y), (x + 22 * sx, y), (x + 22 * sx, y + 7 * sy), (x + 7 * sx, y + 7 * sy), (x + 7 * sx, y + 22 * sy), (x, y + 22 * sy)], hexa('2f9d6c'))
    c.linea([(52, 76), (76, 52)], 5, hexa('3fbf86'))
    c.poly([(68, 50), (80, 48), (78, 60)], hexa('3fbf86'))
    c.poly([(48, 80), (50, 68), (60, 78)], hexa('3fbf86'))


def atras(c):
    c.poly([(12, 64), (56, 22), (56, 46), (116, 46), (116, 82), (56, 82), (56, 106)], TINTA)


def carne(c):
    c.cuerpo(spline([(14, 62), (28, 34), (62, 24), (98, 34), (116, 64), (100, 96), (62, 106), (28, 94)]), hexa('f1d6c2'), sombra=0.22, luz=0.2)
    c.cuerpo(spline([(22, 62), (34, 40), (62, 33), (94, 42), (107, 64), (93, 90), (62, 97), (34, 88)]), hexa('d9544f'), sombra=0.24, luz=0.2, d=2.8)
    c.linea(spline([(40, 56), (52, 50), (66, 56)], cerrada=False), 3, hexa('f4a9a0'))
    c.linea(spline([(46, 78), (62, 70), (82, 76)], cerrada=False), 3, hexa('f4a9a0'))
    c.linea(spline([(74, 46), (84, 54)], cerrada=False), 2.6, hexa('f4a9a0'))
    c.cuerpo_elip(88, 58, 14, col=hexa('f7f1e6'), sombra=0.2, luz=0.0, d=2.6)
    c.elip(88, 58, 7, 7, hexa('d8cdb6'))


def ciudad(c):
    c.rect(8, 112, 120, 118, hexa('6f7894'), r=3)
    c.cuerpo([(12, 62), (46, 62), (46, 112), (12, 112)], hexa('8ea3c8'), sombra=0.22, luz=0.2, d=2.8)
    c.cuerpo([(78, 48), (116, 48), (116, 112), (78, 112)], hexa('9bb0d6'), sombra=0.22, luz=0.2, d=2.8)
    c.cuerpo([(38, 18), (84, 18), (84, 112), (38, 112)], hexa('6f8fcf'), sombra=0.24, luz=0.25, d=3.0)
    c.rect(56, 8, 66, 20, hexa('5a78b4'), r=1)
    for (x0, y0, nx, ny) in ((46, 28, 3, 7), (18, 70, 2, 4), (86, 56, 3, 5)):
        for i in range(nx):
            for j in range(ny):
                lit = (i * 7 + j * 3) % 5 != 0
                c.rect(x0 + i * 11 - (6 if nx == 2 else 0), y0 + j * 12, x0 + i * 11 + 6 - (6 if nx == 2 else 0), y0 + j * 12 + 7, hexa('ffe28a') if lit else hexa('4d6aa0'), r=1)
    c.rect(54, 96, 70, 112, hexa('4d3d34'), r=1)


def cont(c):
    _globo(c, 64, 64, 50)
    c.linea(elipse(64, 64, 50, 50), 2.6, hexa('3a62b8'))


def cultivo(c):
    c.linea([(64, 118), (64, 36)], 5, hexa('b08a34'))
    for i in range(5):
        y = 94 - i * 15
        c.cuerpo(hoja(64, y + 8, 34 + i * 2, y - 12, 8, 0), ORO, sombra=0.25, luz=0.35, d=2.6)
        c.cuerpo(hoja(64, y + 8, 94 - i * 2, y - 12, 8, 0), ORO, sombra=0.25, luz=0.35, d=2.6)
    c.cuerpo(hoja(64, 40, 64, 6, 7, 0), ORO, sombra=0.25, luz=0.35, d=2.6)


def debug(c):
    c.linea([(52, 28), (36, 12)], 4, hexa('2f8d57'))
    c.linea([(76, 28), (92, 12)], 4, hexa('2f8d57'))
    for k, y in enumerate((56, 74, 92)):
        c.linea([(40, y), (14, y - 10 + k * 12)], 4.5, hexa('2f8d57'))
        c.linea([(88, y), (114, y - 10 + k * 12)], 4.5, hexa('2f8d57'))
    c.cuerpo_elip(64, 76, 28, 38, col=hexa('5fd085'), sombra=0.26, luz=0.25, d=3.2)
    c.cuerpo_elip(64, 34, 18, 16, col=hexa('4cbf72'), sombra=0.26, luz=0.25, d=2.8)
    c.linea([(64, 44), (64, 114)], 3, hexa('2f8d57'))
    c.punto(56, 30, 3.4, hexa('1f3a2a'))
    c.punto(72, 30, 3.4, hexa('1f3a2a'))
    for (x, y) in ((50, 66), (78, 66), (50, 88), (78, 88)):
        c.punto(x, y, 4.4, hexa('2f8d57'))


def dens(c):
    for i in range(4):
        for j in range(4):
            c.cuerpo_elip(24 + i * 27, 24 + j * 27, 9.5, col=ORO, sombra=0.24, luz=0.35, d=2.4)


def desc(c):
    c.cuerpo([(24, 8), (104, 8), (104, 120), (24, 120)], PAPEL, sombra=0.14, luz=0.0, d=3.0)
    for i, (x1) in enumerate((92, 92, 92, 92, 70)):
        c.rect(36, 24 + i * 18, x1, 32 + i * 18, hexa('7c869b') if i else hexa('4d5a78'), r=3)


def devast(c):
    c.cuerpo([(10, 82), (44, 82), (44, 112), (10, 112)], hexa('9a948a'), sombra=0.22, luz=0.2, d=2.6)
    c.cuerpo([(44, 98), (84, 98), (84, 112), (44, 112)], hexa('b3ada2'), sombra=0.22, luz=0.2, d=2.6)
    c.cuerpo([(84, 70), (118, 70), (118, 112), (84, 112)], hexa('9a948a'), sombra=0.22, luz=0.2, d=2.6)
    c.cuerpo(spline([(64, 6), (88, 34), (96, 56), (84, 80), (64, 92), (44, 80), (34, 58), (44, 40), (52, 52)]), HOGUERA, sombra=0.22, luz=0.2, d=2.8)
    c.cuerpo(spline([(64, 34), (78, 56), (80, 72), (64, 84), (50, 72), (52, 56)]), LLAMA, sombra=0.0, luz=0.3, d=2.4)
    c.elip(64, 70, 8, 10, hexa('fff2b0'))
    c.rect(8, 110, 120, 118, hexa('5f5a52'), r=3)


def dipl(c):
    c.linea([(98, 112), (98, 14)], 4.5, hexa('c9d2e6'))
    c.cuerpo([(98, 16), (126, 26), (98, 42)], hexa('f2f5ff'), sombra=0.2, luz=0.0, d=2.4)
    _globo(c, 52, 72, 40)
    c.linea(elipse(52, 72, 40, 40), 2.4, hexa('3a62b8'))


def eco(c):
    c.cuerpo_elip(78, 44, 34, col=ORO2, sombra=0.25, luz=0.3, d=3.0)
    c.elip(78, 44, 26, 26, hexa('f4c552'))
    c.elip(78, 44, 21, 21, hexa('e6ae2c'))
    c.cuerpo_elip(52, 78, 42, col=ORO, sombra=0.25, luz=0.35, d=3.4)
    c.elip(52, 78, 33, 33, hexa('ffe283'))
    c.elip(52, 78, 27, 27, hexa('f2c13e'))
    c.cuerpo(estrella(52, 78, 15, 6.5, 5), hexa('c98a14'), sombra=0.0, luz=0.0)
    c.cuerpo(estrella(52, 77, 13, 5.5, 5), hexa('ffd45c'), sombra=0.0, luz=0.0)
    c.elip(78, 44, 9, 9, hexa('d9a02a'))


def editar(c):
    c.cuerpo([(100, 14), (116, 30), (104, 42), (88, 26)], hexa('f08c9a'), sombra=0.2, luz=0.2, d=2.4)
    c.cuerpo([(88, 26), (104, 42), (94, 52), (78, 36)], hexa('c3cad8'), sombra=0.2, luz=0.3, d=2.4)
    c.cuerpo([(78, 36), (94, 52), (40, 106), (24, 90)], hexa('f4cc43'), sombra=0.24, luz=0.3, d=3.0)
    c.linea([(60, 48), (96, 84)], 2.5, hexa('f9e48a'))
    c.cuerpo([(24, 90), (40, 106), (12, 116)], hexa('f1dcb4'), sombra=0.2, luz=0.2, d=2.4)
    c.poly([(16, 106), (22, 112), (12, 116)], hexa('46506c'))


def ejercito(c):
    c.linea([(26, 24), (102, 104)], 8, hexa('d5dcec'))
    c.linea([(102, 24), (26, 104)], 8, hexa('d5dcec'))
    c.linea([(20, 36), (38, 18)], 7, hexa('b9893a'))
    c.linea([(108, 36), (90, 18)], 7, hexa('b9893a'))
    c.cuerpo([(30, 30), (98, 30), (98, 70), (64, 112), (30, 70)], hexa('4a78c8'), sombra=0.26, luz=0.25, d=3.4)
    c.poly([(37, 37), (91, 37), (91, 68), (64, 102), (37, 68)], hexa('3f67ad'))
    c.cuerpo(estrella(64, 64, 22, 9, 5), ORO, sombra=0.24, luz=0.35, d=2.4)


def estado(c):
    c.cuerpo(spline([(14, 44), (38, 22), (66, 30), (98, 16), (116, 48), (104, 78), (112, 102), (78, 112), (50, 100), (26, 104), (16, 74)]), hexa('72b7dc'), sombra=0.24, luz=0.25, d=3.2)
    c.linea(spline([(24, 46), (42, 32), (66, 38), (94, 26), (106, 48), (96, 74), (102, 96), (76, 102), (50, 90), (30, 94), (26, 74)]), 2.6, hexa('d7ecf8'))
    c.cuerpo(estrella(64, 66, 15, 6.5, 5), ORO, sombra=0.24, luz=0.35, d=2.2)


def estrella_(c):
    c.cuerpo(estrella(64, 66, 54, 23, 5), ORO, sombra=0.26, luz=0.4, d=3.6)


def etn(c):
    c.elip(46, 46, 32, 32, (224, 98, 92, 225))
    c.elip(82, 46, 32, 32, (108, 196, 118, 225))
    c.elip(64, 80, 32, 32, (96, 138, 226, 225))
    c.recortada(c._mascara(elipse(46, 46, 32, 32)), lambda t: t.elip(82, 46, 32, 32, (255, 255, 255, 60)))
    c.recortada(c._mascara(elipse(64, 80, 32, 32)), lambda t: (t.elip(46, 46, 32, 32, (255, 255, 255, 60)), t.elip(82, 46, 32, 32, (255, 255, 255, 60))))


def fauna(c):
    c.cuerpo(spline([(34, 90), (30, 74), (46, 62), (64, 58), (82, 62), (98, 74), (94, 90), (80, 98), (64, 92), (48, 98)]), hexa('e8b86a'), sombra=0.26, luz=0.3, d=3.2)
    for (x, y, rx, ry, a) in ((22, 60, 10, 14, -20), (44, 36, 11, 15, -8), (74, 36, 11, 15, 8), (96, 60, 10, 14, 20)):
        c.cuerpo_elip(x + 6, y + 4, rx, ry, col=hexa('e8b86a'), ang=a, sombra=0.26, luz=0.3, d=2.6)


def flora(c):
    c.linea(spline([(64, 70), (62, 92), (66, 118)], cerrada=False), 5, hexa('3f9e57'))
    c.cuerpo(hoja(66, 104, 98, 84, 9, 0), hexa('59c26f'), sombra=0.24, luz=0.3, d=2.4)
    c.cuerpo(hoja(62, 96, 34, 80, 8, 0), hexa('59c26f'), sombra=0.24, luz=0.3, d=2.4)
    for i in range(5):
        a = math.radians(-90 + i * 72)
        c.cuerpo_elip(64 + 24 * math.cos(a), 44 + 24 * math.sin(a), 15, 15, col=hexa('f08ab0'), ang=math.degrees(a) + 90, sombra=0.22, luz=0.35, d=2.6)
    c.cuerpo_elip(64, 44, 12, col=hexa('f8d24a'), sombra=0.3, luz=0.3, d=2.4)


def gob(c):
    c.rect(8, 106, 120, 118, hexa('b9c2da'), r=3)
    c.rect(16, 96, 112, 108, hexa('d5dcee'), r=2)
    c.cuerpo([(8, 44), (64, 8), (120, 44)], hexa('dbe2f4'), sombra=0.2, luz=0.0, d=3.0)
    c.poly([(26, 42), (64, 18), (102, 42)], hexa('c0c9e4'))
    c.cuerpo(estrella(64, 33, 9, 4, 5), ORO, sombra=0.2, luz=0.3, d=1.8)
    c.rect(14, 44, 114, 52, hexa('eef1fb'), r=2)
    for i in range(5):
        x = 22 + i * 21
        c.cuerpo([(x, 54), (x + 12, 54), (x + 12, 96), (x, 96)], hexa('f3f5fc'), sombra=0.22, luz=0.0, d=2.2)


def info(c):
    c.cuerpo_elip(64, 64, 54, col=AZUL_M, sombra=0.28, luz=0.3, d=3.6)
    c.elip(64, 64, 46, 46, hexa('7ba3ec'))
    c.cuerpo_elip(64, 33, 7.5, col=BLANCO, sombra=0.15, luz=0.0, d=1.8)
    c.cuerpo([(56, 48), (73, 48), (73, 98), (56, 98)], BLANCO, sombra=0.15, luz=0.0, d=2.0)
    c.rect(52, 94, 78, 102, BLANCO, r=2)
    c.rect(52, 46, 66, 54, BLANCO, r=2)


def lentes(c):
    c.linea(elipse(52, 52, 36, 36) + [elipse(52, 52, 36, 36)[0]], 12, TINTA)
    c.linea([(80, 80), (112, 112)], 17, TINTA)
    c.linea(spline([(30, 40), (36, 32), (46, 28)], cerrada=False), 5, (240, 244, 255, 190))


def mineral(c):
    c.cuerpo(spline([(10, 112), (22, 70), (46, 52), (62, 70), (84, 58), (112, 112)]), hexa('9a948e'), sombra=0.24, luz=0.25, d=3.2)
    c.poly([(46, 60), (62, 76), (48, 92), (32, 78)], hexa('b6b0a8'))
    c.cuerpo([(80, 12), (108, 30), (96, 66), (64, 66), (52, 30)], hexa('5ed3df'), sombra=0.26, luz=0.4, d=3.0)
    c.poly([(80, 12), (96, 30), (64, 30)], hexa('b5f1f6'))
    c.poly([(64, 30), (96, 30), (80, 66)], hexa('3fb3c4'))
    c.rect(4, 110, 124, 118, hexa('6f6a63'), r=3)


def moneda(c):
    divisas.moneda(c, 'GEN', '¤', 'oro')


def pais(c):
    c.linea([(30, 120), (30, 12)], 7, hexa('d5dcec'))
    c.punto(30, 11, 6, ORO)
    c.cuerpo([(36, 18), (112, 18), (98, 40), (112, 62), (36, 62)], hexa('e86a64'), sombra=0.26, luz=0.25, d=3.0)
    c.cuerpo([(36, 62), (112, 62), (98, 84), (112, 106), (36, 106)], hexa('f4c842'), sombra=0.26, luz=0.25, d=3.0)


def pausa(c):
    c.rect(26, 14, 54, 114, TINTA, r=5)
    c.rect(74, 14, 102, 114, TINTA, r=5)


def pob(c):
    c.cuerpo_elip(46, 36, 19, col=hexa('6aa7f0'), sombra=0.26, luz=0.3, d=2.8)
    c.cuerpo(spline([(14, 112), (16, 76), (46, 64), (76, 76), (78, 112)]), hexa('6aa7f0'), sombra=0.26, luz=0.3, d=3.2)
    c.cuerpo_elip(86, 44, 19, col=hexa('f2a15c'), sombra=0.26, luz=0.3, d=2.8)
    c.cuerpo(spline([(50, 112), (54, 82), (86, 72), (116, 84), (116, 112)]), hexa('f2a15c'), sombra=0.26, luz=0.3, d=3.2)


def prof(c):
    for k, (y, col) in enumerate(((30, hexa('8ed0f8')), (62, hexa('5aaaf0')), (94, hexa('3a7fd8')))):
        pts = [(8 + i * 3.6, y + 11 * math.sin((i / 33.0) * math.pi * 3 + k * 0.7)) for i in range(34)]
        c.linea(pts, 13, col)


def prov(c):
    c.elip(64, 118, 30, 5, (0, 0, 0, 55))
    c.cuerpo(spline([(64, 118), (30, 70), (26, 46), (42, 20), (64, 12), (86, 20), (102, 46), (98, 70)]), hexa('f2824e'), sombra=0.28, luz=0.3, d=3.4)
    c.cuerpo_elip(64, 48, 17, col=hexa('5a3a2a'), sombra=0.0, luz=0.0)
    c.elip(64, 48, 13, 13, hexa('3a241a'))
    c.recortada(c._mascara(spline([(64, 118), (30, 70), (26, 46), (42, 20), (64, 12), (86, 20), (102, 46), (98, 70)])), lambda t: t.elip(44, 30, 14, 7, (255, 255, 255, 110), -50))


def tpausa(c):
    c.linea(elipse(64, 64, 50, 50) + [elipse(64, 64, 50, 50)[0]], 11, TINTA)
    c.rect(44, 38, 58, 90, TINTA, r=3)
    c.rect(70, 38, 84, 90, TINTA, r=3)


def veg(c):
    c.cuerpo([(56, 80), (72, 80), (76, 118), (52, 118)], hexa('8c5f38'), sombra=0.28, luz=0.2, d=2.8)
    c.cuerpo_elip(64, 62, 50, 44, col=hexa('3f9e57'), sombra=0.28, luz=0.0, d=3.6)
    c.cuerpo_elip(48, 70, 26, 22, col=hexa('4cb065'), sombra=0.22, luz=0.2, d=2.6)
    c.cuerpo_elip(82, 52, 28, 24, col=hexa('5cc576'), sombra=0.22, luz=0.35, d=2.6)
    c.cuerpo_elip(56, 36, 24, 18, col=hexa('6fd286'), sombra=0.2, luz=0.4, d=2.4)


def _vel(n):
    def f(c):
        ancho = 100.0 / n
        for i in range(n):
            x0 = 14 + i * ancho
            c.poly([(x0, 16), (x0 + ancho * 1.05, 64), (x0, 112)], TINTA)
    return f


def _vel_chevron(n):
    def f(c):
        paso = 100.0 / n
        for i in range(n):
            x0 = 10 + i * paso
            c.poly([(x0, 14), (x0 + paso * 1.2, 64), (x0, 114), (x0 + paso * 0.55, 64)], TINTA)
    return f


def vista(c):
    c.cuerpo(spline([(4, 64), (34, 28), (64, 20), (94, 28), (124, 64), (94, 100), (64, 108), (34, 100)]), hexa('eef2fb'), sombra=0.22, luz=0.0, d=3.2)
    c.cuerpo_elip(64, 64, 30, col=AZUL_M, sombra=0.28, luz=0.3, d=3.0)
    c.elip(64, 64, 15, 15, hexa('1f2b4a'))
    c.punto(55, 54, 6, (255, 255, 255, 235))


ICONOS = {
    'i_alt': alt, 'i_area': area, 'i_atras': atras, 'i_carne': carne, 'i_ciudad': ciudad, 'i_cont': cont, 'i_cultivo': cultivo, 'i_debug': debug,
    'i_dens': dens, 'i_desc': desc, 'i_devast': devast, 'i_dipl': dipl, 'i_eco': eco, 'i_editar': editar, 'i_ejercito': ejercito, 'i_estado': estado,
    'i_estrella': estrella_, 'i_etn': etn, 'i_fauna': fauna, 'i_flora': flora, 'i_gob': gob, 'i_info': info, 'i_lentes': lentes, 'i_mineral': mineral,
    'i_moneda': moneda, 'i_pais': pais, 'i_pausa': pausa, 'i_pob': pob, 'i_prof': prof, 'i_prov': prov, 'i_tpausa': tpausa, 'i_veg': veg,
    'i_vel1': _vel(1), 'i_vel2': _vel(2), 'i_vel3': _vel(3), 'i_vel4': _vel_chevron(4), 'i_vel5': _vel_chevron(5), 'i_vel6': _vel_chevron(6),
    'i_vista': vista,
}
