"""Sectores económicos (rubros): servicios, manufactura, construcción, comercio, finanzas, logística, tecnología, remesas..."""
import math
from lienzo import *


def servicios(c):
    c.cuerpo(spline([(18, 96), (22, 66), (40, 46), (64, 40), (88, 46), (106, 66), (110, 96)], por_tramo=6, cerrada=True), hexa('d8dff0'), sombra=0.2, luz=0.3, d=3)
    c.rect(10, 96, 118, 110, hexa('9aa6c4'), r=4)
    c.rect(58, 24, 70, 42, hexa('b8c4de'), r=3)
    c.cuerpo_elip(64, 24, 12, 7, col=hexa('f2c33a'), sombra=0.2, luz=0.3, d=1.4)
    c.brillo(42, 70, 4, 14, 20)


def manufactura(c):
    c.cuerpo(spline([(14, 112), (14, 66), (44, 50), (44, 66), (74, 50), (74, 66), (104, 50), (104, 112)], por_tramo=2, cerrada=True), hexa('8aa0c8'), sombra=0.2, luz=0.25, d=2.6)
    c.rect(92, 18, 108, 70, hexa('7c869b'), r=2)
    c.rect(88, 14, 112, 24, hexa('9aa6c4'), r=2)
    for x in (24, 54, 84):
        c.rect(x, 82, x + 14, 96, hexa('ffe9a0'), r=2)
    c.cuerpo(engranaje(86, 32, 15, 11, 8), hexa('f2b134'), sombra=0.2, luz=0.3, d=1.8)
    c.punto(86, 32, 5, hexa('8aa0c8'))
    for (x, y, r) in ((100, 10, 6), (110, 4, 4)):
        c.punto(x, y, r, (230, 236, 250, 200))


def construccion(c):
    c.cuerpo(spline([(14, 82), (20, 52), (44, 32), (84, 32), (108, 52), (114, 82)], por_tramo=6, cerrada=True), hexa('f4c42c'), sombra=0.2, luz=0.3, d=3)
    c.rect(8, 82, 120, 98, hexa('e0a818'), r=5)
    c.rect(56, 24, 72, 82, hexa('f8d95a'), r=4)
    c.rect(56, 24, 62, 82, hexa('fbe88a'))
    c.brillo(34, 56, 4, 10, 30)


def comercio(c):
    c.cuerpo(spline([(14, 56), (22, 22), (106, 22), (114, 56)], por_tramo=2, cerrada=True), hexa('e0605a'), sombra=0.2, luz=0.2, d=2.4)
    for x in (30, 58, 86):
        c.poly([(x, 22), (x + 14, 22), (x + 16, 56), (x - 2, 56)], hexa('fbf6ee'))
    for x in (16, 44, 72, 100):
        c.cuerpo_elip(x + 7, 56, 14, 9, col=hexa('e0605a') if (x // 28) % 2 == 0 else hexa('fbf6ee'), sombra=0.15, luz=0.1, d=1.2)
    c.cuerpo([(20, 66), (108, 66), (108, 112), (20, 112)], hexa('d8dff0'), sombra=0.2, luz=0.2, d=2.4)
    c.rect(52, 78, 80, 112, hexa('8a6038'), r=2)
    c.rect(28, 76, 46, 96, hexa('7aa8f0'), r=2)
    c.rect(86, 76, 102, 96, hexa('7aa8f0'), r=2)


def finanzas(c):
    c.poly([(14, 46), (64, 14), (114, 46)], hexa('c4cde4'))
    c.poly([(14, 46), (64, 14), (64, 20), (24, 46)], hexa('e4eaf8'))
    c.rect(14, 46, 114, 54, hexa('e4eaf8'), r=1)
    for x in (24, 48, 72, 96):
        c.cuerpo([(x, 54), (x + 14, 54), (x + 14, 94), (x, 94)], hexa('f0f4ff'), sombra=0.2, luz=0, d=1.6, col_sombra=hexa('c0c8e0'))
    c.rect(10, 94, 118, 106, hexa('c4cde4'), r=1)
    c.rect(4, 106, 124, 118, hexa('9aa6c4'), r=2)
    c.cuerpo_elip(64, 33, 8, 8, col=hexa('f2c33a'), sombra=0.2, luz=0.3, d=1.2)


def logistica(c):
    for (x, y, col_) in ((10, 78, hexa('e0605a')), (50, 78, hexa('4a8ad8')), (90, 78, hexa('f2b134')), (30, 40, hexa('4aa86a')), (70, 40, hexa('e0605a'))):
        c.cuerpo([(x, y), (x + 36, y), (x + 36, y + 34), (x, y + 34)], col_, sombra=0.2, luz=0.25, d=2)
        for k in range(1, 5):
            c.linea([(x + k * 7, y + 3), (x + k * 7, y + 31)], 1.4, oscuro(col_, 0.25))


def tecnologia(c):
    c.cuerpo([(30, 30), (98, 30), (98, 98), (30, 98)], hexa('3a4a6a'), sombra=0.2, luz=0.2, d=2.6)
    for k in range(4):
        v = 40 + k * 16
        c.rect(v, 16, v + 8, 30, hexa('c4cde4'), r=1)
        c.rect(v, 98, v + 8, 112, hexa('c4cde4'), r=1)
        c.rect(16, v, 30, v + 8, hexa('c4cde4'), r=1)
        c.rect(98, v, 112, v + 8, hexa('c4cde4'), r=1)
    c.cuerpo([(44, 44), (84, 44), (84, 84), (44, 84)], hexa('5a7ac8'), sombra=0.2, luz=0.3, d=2)
    c.poly([(64, 52), (74, 64), (64, 76), (54, 64)], hexa('c8dcff'))


def remesas(c):
    c.cuerpo([(10, 36), (96, 36), (96, 92), (10, 92)], hexa('f4f0e0'), sombra=0.2, luz=0.2, d=2.4, col_sombra=hexa('c8c0a0'))
    c.poly([(10, 36), (53, 70), (96, 36)], hexa('d8d0b0'))
    c.linea([(10, 92), (40, 62)], 2.0, hexa('c8c0a0'))
    c.linea([(96, 92), (66, 62)], 2.0, hexa('c8c0a0'))
    c.cuerpo_elip(92, 88, 26, 26, col=hexa('f2c33a'), sombra=0.2, luz=0.3, d=2.4)
    c.elip(92, 88, 19, 19, hexa('f8d95a'))
    c.linea([(92, 76), (92, 100)], 4, hexa('c88a1a'))
    c.linea([(84, 82), (100, 82)], 3.4, hexa('c88a1a'))
    c.linea([(84, 94), (100, 94)], 3.4, hexa('c88a1a'))


def textil(c):
    c.cuerpo([(32, 28), (96, 28), (96, 100), (32, 100)], hexa('e8689a'), sombra=0.2, luz=0.25, d=2.8)
    for y in (42, 54, 66, 78, 90):
        c.linea([(32, y), (96, y + 4)], 3.0, hexa('f4a0c0'))
    c.rect(24, 16, 104, 30, hexa('c49a62'), r=3)
    c.rect(24, 98, 104, 112, hexa('c49a62'), r=3)
    c.linea(bezier((96, 60), (116, 56), (110, 20), 12), 2.2, hexa('e8689a'))


def automotriz(c):
    c.cuerpo(spline([(8, 84), (10, 66), (30, 60), (44, 36), (84, 36), (100, 58), (118, 66), (122, 84)], por_tramo=6, cerrada=True), hexa('e0605a'), sombra=0.2, luz=0.25, d=3)
    c.poly([(48, 42), (62, 42), (62, 60), (38, 60)], hexa('c8e4ff'))
    c.poly([(68, 42), (82, 42), (94, 60), (68, 60)], hexa('c8e4ff'))
    for x in (34, 94):
        c.punto(x, 88, 15, hexa('2a2f42'))
        c.punto(x, 88, 8, hexa('c4cde4'))
        c.punto(x, 88, 3, hexa('7c869b'))


def electronica(c):
    tecnologia(c)


def _semicapsula(cx, cy, medio, radio, lado):
    """Mitad de una cápsula horizontal: lado = -1 (izquierda) o 1 (derecha)."""
    pts = [(cx, cy - radio), (cx + lado * medio, cy - radio)]
    for a in range(-90, 91, 10):
        t = math.radians(a)
        pts.append((cx + lado * (medio + radio * math.cos(t)), cy + radio * math.sin(t)))
    pts += [(cx + lado * medio, cy + radio), (cx, cy + radio)]
    return pts


def farma(c):
    ang = -42
    c.cuerpo(rot(_semicapsula(64, 64, 20, 22, -1), ang, 64, 64), hexa('e0605a'), sombra=0.2, luz=0.3, d=2.6)
    c.cuerpo(rot(_semicapsula(64, 64, 20, 22, 1), ang, 64, 64), hexa('f6f8ff'), sombra=0.2, luz=0.2, d=2.6, col_sombra=hexa('c0c8e0'))
    c.poly(rot([(60, 40), (68, 40), (68, 88), (60, 88)], ang, 64, 64), (60, 70, 100, 70))
    c.poly(estrella(100, 26, 11, 4, 4), (255, 255, 255, 235))


def quimica(c):
    c.cuerpo(spline([(34, 14), (70, 14), (70, 34), (106, 108), (98, 120), (30, 120), (22, 108), (34, 34)], por_tramo=4, cerrada=True), hexa('e0eaff'), sombra=0.18, luz=0.2, d=2.6)
    c.poly(spline([(36, 80), (96, 80), (106, 108), (98, 120), (30, 120), (22, 108)], por_tramo=4, cerrada=True), hexa('b878e8'))
    c.rect(30, 10, 74, 20, hexa('b8c4de'), r=3)
    for (x, y, r) in ((50, 104, 5), (70, 96, 3), (62, 108, 3.6), (84, 106, 4.4)):
        c.punto(x, y, r, hexa('e8ccff'))


def papel(c):
    c.cuerpo([(26, 18), (84, 18), (102, 36), (102, 112), (26, 112)], hexa('f6f8ff'), sombra=0.2, luz=0.1, d=2.6, col_sombra=hexa('c0c8e0'))
    c.poly([(84, 18), (102, 36), (84, 36)], hexa('c8d2ea'))
    for y in (52, 66, 80, 94):
        c.linea([(38, y), (90, y)], 3.0, hexa('9aa6c4'))


def inmobiliario(c):
    c.cuerpo([(24, 58), (104, 58), (104, 112), (24, 112)], hexa('f4f0e0'), sombra=0.2, luz=0.2, d=2.6, col_sombra=hexa('c8c0a0'))
    c.cuerpo([(10, 62), (64, 16), (118, 62)], hexa('e0605a'), sombra=0.2, luz=0.25, d=3)
    c.rect(54, 78, 76, 112, hexa('8a6038'), r=2)
    c.rect(34, 72, 48, 90, hexa('7aa8f0'), r=2)
    c.rect(82, 72, 96, 90, hexa('7aa8f0'), r=2)
    c.rect(86, 22, 98, 44, hexa('b8573a'), r=1)


def seguros(c):
    c.cuerpo(spline([(64, 10), (108, 24), (108, 64), (92, 96), (64, 118), (36, 96), (20, 64), (20, 24)], por_tramo=6, cerrada=True), hexa('5a8ae0'), sombra=0.2, luz=0.3, d=3.4)
    c.linea([(44, 62), (58, 78), (86, 44)], 9, hexa('f4f6ff'))


def servicios_publicos(c):
    c.cuerpo(spline([(40, 70), (30, 46), (44, 20), (64, 14), (84, 20), (98, 46), (88, 70), (80, 84), (48, 84)], por_tramo=6, cerrada=True), hexa('f6dc4a'), sombra=0.2, luz=0.3, d=3)
    c.rect(46, 88, 82, 98, hexa('9aa6c4'), r=2)
    c.rect(50, 100, 78, 110, hexa('7c869b'), r=2)
    c.linea([(56, 74), (56, 50), (72, 50), (72, 74)], 3.0, hexa('d99a1f'))
    c.brillo(46, 42, 4, 11, 20)


def otros(c):
    for x in (30, 64, 98):
        c.cuerpo_elip(x, 64, 14, 14, col=hexa('9aa6c4'), sombra=0.2, luz=0.3, d=2)


def agroindustria(c):
    c.cuerpo([(18, 56), (62, 56), (62, 118), (18, 118)], hexa('d8dff0'), sombra=0.2, luz=0.2, d=2.4)
    c.cuerpo(spline([(14, 56), (18, 38), (40, 28), (62, 38), (66, 56)], por_tramo=5, cerrada=True), hexa('e0605a'), sombra=0.2, luz=0.25, d=2.4)
    for y in (70, 88, 104):
        c.linea([(18, y), (62, y)], 1.6, hexa('aab4d0'))
    c.cuerpo([(70, 70), (118, 70), (118, 118), (70, 118)], hexa('e0605a'), sombra=0.2, luz=0.25, d=2.4)
    c.poly([(66, 72), (94, 46), (122, 72)], hexa('b8403f'))
    c.rect(86, 90, 102, 118, hexa('f4f0e0'), r=1)
    c.linea([(86, 90), (102, 118)], 1.6, hexa('b8403f'))
    c.linea([(102, 90), (86, 118)], 1.6, hexa('b8403f'))


def puertos(c):
    c.linea([(64, 22), (64, 108)], 8, hexa('7c869b'))
    c.linea([(40, 44), (88, 44)], 8, hexa('7c869b'))
    c.linea(bezier((18, 80), (24, 118), (64, 118), 16) + bezier((64, 118), (104, 118), (110, 80), 16)[1:], 8, hexa('7c869b'))
    c.cuerpo_elip(64, 16, 9, 9, col=hexa('9aa6c4'), sombra=0.2, luz=0.3, d=1.6)
    c.elip(64, 16, 4, 4, (0, 0, 0, 0))
    c.poly([(8, 90), (20, 70), (28, 90)], hexa('7c869b'))
    c.poly([(120, 90), (108, 70), (100, 90)], hexa('7c869b'))


def gobierno_sector(c):
    c.poly([(10, 42), (64, 12), (118, 42)], hexa('c4cde4'))
    c.rect(10, 42, 118, 50, hexa('e4eaf8'))
    for x in (22, 44, 66, 88):
        c.cuerpo([(x, 50), (x + 14, 50), (x + 14, 94), (x, 94)], hexa('f0f4ff'), sombra=0.2, luz=0, d=1.6, col_sombra=hexa('c0c8e0'))
    c.rect(6, 94, 122, 108, hexa('c4cde4'))
    c.poly(estrella(64, 31, 7, 3, 5), hexa('f2c33a'))


def entretenimiento(c):
    c.cuerpo(spline([(24, 40), (104, 40), (104, 100), (24, 100)], por_tramo=3, cerrada=True), hexa('4a5268'), sombra=0.2, luz=0.2, d=2.6)
    c.poly([(54, 56), (54, 84), (82, 70)], hexa('f4d03a'))
    c.rect(14, 104, 114, 114, hexa('7c869b'), r=3)
    c.poly(estrella(100, 24, 10, 4, 5), hexa('f4d03a'))
    c.poly(estrella(24, 28, 7, 3, 5), hexa('f08a5a'))


def mineria(c):
    c.linea([(38, 112), (84, 38)], 9, hexa('a0683a'))
    c.cuerpo(spline([(18, 40), (40, 18), (84, 14), (116, 30), (92, 30), (62, 32), (40, 52)], por_tramo=6, cerrada=True), hexa('9aa6c4'), sombra=0.2, luz=0.3, d=2.8)
    c.cuerpo_elip(30, 100, 12, 8, col=hexa('7c869b'), sombra=0.2, luz=0.3, d=1.6)
    c.cuerpo_elip(96, 100, 16, 11, col=hexa('b8573a'), sombra=0.2, luz=0.3, d=1.8)
    c.cuerpo_elip(66, 112, 12, 8, col=hexa('9aa6c4'), sombra=0.2, luz=0.3, d=1.6)


def ganaderia(c):
    c.cuerpo(spline([(10, 64), (22, 44), (74, 42), (100, 52), (118, 66), (118, 84), (104, 92), (20, 92)], por_tramo=6, cerrada=True), hexa('f4f6ff'), sombra=0.2, luz=0.1, d=3, col_sombra=hexa('c0c8e0'))
    c.cuerpo_elip(48, 62, 14, 10, col=hexa('3a3f52'), sombra=0.1, luz=0)
    c.cuerpo_elip(84, 66, 12, 9, col=hexa('3a3f52'), sombra=0.1, luz=0)
    for x in (26, 40, 86, 100):
        c.cuerpo([(x - 4, 90), (x + 4, 90), (x + 4, 116), (x - 4, 116)], hexa('e8ecf8'), sombra=0.2, luz=0, d=1.4, col_sombra=hexa('b8c2de'))
    c.cuerpo_elip(14, 66, 14, 16, col=hexa('f1a0a8'), sombra=0.2, luz=0.2, d=1.6)
    c.poly([(8, 46), (14, 36), (18, 48)], hexa('f2dfa8'))
    c.punto(10, 62, 2.6, NEGRO)


def agricultura(c):
    # tractor
    c.cuerpo([(30, 42), (78, 42), (92, 70), (112, 70), (112, 92), (30, 92)], hexa('4aa86a'), sombra=0.2, luz=0.25, d=3)
    c.poly([(40, 24), (70, 24), (74, 42), (36, 42)], hexa('c8e4ff'))
    c.rect(34, 20, 74, 26, hexa('2f7d46'), r=2)
    c.punto(40, 96, 22, hexa('2a2f42'))
    c.punto(40, 96, 11, hexa('f2c33a'))
    c.punto(100, 102, 12, hexa('2a2f42'))
    c.punto(100, 102, 6, hexa('f2c33a'))
    c.rect(106, 54, 112, 70, hexa('7c869b'), r=1)


ICONOS = {
    'servicios': servicios, 'manufactura': manufactura, 'construccion': construccion, 'comercio': comercio, 'finanzas': finanzas, 'logistica': logistica,
    'tecnologia': tecnologia, 'remesas': remesas, 'textil': textil, 'automotriz': automotriz, 'electronica': electronica, 'farma': farma, 'quimica': quimica,
    'papel': papel, 'inmobiliario': inmobiliario, 'seguros': seguros, 'servicios_publicos': servicios_publicos, 'otros': otros, 'agroindustria': agroindustria,
    'puertos': puertos, 'gobierno': gobierno_sector, 'entretenimiento': entretenimiento, 'mineria': mineria, 'ganaderia': ganaderia, 'agricultura': agricultura,
}
