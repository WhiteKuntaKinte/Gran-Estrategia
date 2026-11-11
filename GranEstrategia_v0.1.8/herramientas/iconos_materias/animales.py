"""Ganadería y pesca: animales dibujados de frente o de perfil, en el mismo estilo plano."""
import math
from lienzo import *


def _ojos(c, y, sep=15, r=4.6, col=NEGRO, x=64):
    for lado in (-1, 1):
        c.punto(x + lado * sep, y, r, col)
        c.punto(x + lado * sep + 1.2, y - 1.4, r * 0.32, hexa('ffffff'))


def res(c):
    # cuernos
    for lado in (-1, 1):
        c.cuerpo(hoja(64 + lado * 24, 40, 64 + lado * 50, 16, 6, curva=lado * -6), hexa('f2dfa8'), sombra=0.2, luz=0.2, d=1.6)
        c.cuerpo_elip(64 + lado * 38, 52, 17, 9, col=hexa('f4f6ff'), sombra=0.18, luz=0.2, d=1.8, ang=lado * 24)
    c.cuerpo(spline([(36, 44), (92, 44), (100, 74), (92, 112), (64, 124), (36, 112), (28, 74)]), hexa('f6f8ff'), sombra=0.2, luz=0.1, d=3, col_sombra=hexa('c4cde4'))
    c.cuerpo_elip(46, 58, 12, 15, col=hexa('3a3f52'), sombra=0.1, luz=0, ang=-14)
    c.cuerpo(spline([(34, 90), (94, 90), (96, 112), (64, 124), (32, 112)]), hexa('f1a0a8'), sombra=0.2, luz=0.2, d=2.4)
    _ojos(c, 64, 20, 4.8)
    for lado in (-1, 1):
        c.punto(64 + lado * 10, 104, 3.2, hexa('b8586a'))


def cerdo(c):
    for lado in (-1, 1):
        c.cuerpo(spline([(64 + lado * 20, 30), (64 + lado * 46, 24), (64 + lado * 52, 56), (64 + lado * 34, 52)]), hexa('e88aa4'), sombra=0.2, luz=0.2, d=2)
    c.cuerpo_elip(64, 72, 42, 40, col=hexa('f5a8bc'), sombra=0.2, luz=0.3, d=3.4)
    c.cuerpo_elip(64, 86, 22, 17, col=hexa('e88aa4'), sombra=0.2, luz=0.3, d=2.2)
    for lado in (-1, 1):
        c.elip(64 + lado * 8, 87, 3.4, 5.4, hexa('b8506a'))
    _ojos(c, 60, 20, 4.8)


def pollo(c):
    c.cuerpo(spline([(58, 20), (68, 8), (76, 24), (84, 12), (94, 28), (84, 40), (66, 40)]), hexa('e03c3c'), sombra=0.2, luz=0.2, d=2)
    c.cuerpo(spline([(30, 70), (52, 38), (84, 40), (100, 66), (104, 100), (84, 120), (52, 120), (34, 100)]), hexa('fafbff'), sombra=0.2, luz=0.1, d=3.4, col_sombra=hexa('c8d0e6'))
    c.cuerpo(spline([(24, 66), (34, 58), (40, 74), (30, 76)]), hexa('f4b32a'), sombra=0.1, luz=0.1, d=1.4)
    c.cuerpo(spline([(36, 80), (54, 74), (60, 100), (50, 118), (40, 108)]), hexa('e04a4a'), sombra=0.15, luz=0, d=1.6)
    c.punto(52, 58, 4.6, NEGRO)
    c.punto(53.2, 56.6, 1.6, hexa('ffffff'))
    c.cuerpo(spline([(70, 92), (94, 84), (102, 108), (84, 118), (66, 112)]), hexa('e9edf8'), sombra=0.2, luz=0, d=2, col_sombra=hexa('b8c2de'))


def cabra(c):
    for lado in (-1, 1):
        c.cuerpo(hoja(64 + lado * 16, 38, 64 + lado * 44, 6, 5, curva=lado * -6), hexa('b8a888'), sombra=0.2, luz=0.2, d=1.4)
        c.cuerpo(hoja(64 + lado * 24, 58, 64 + lado * 60, 70, 8, curva=0), hexa('d9c9a8'), sombra=0.2, luz=0.2, d=1.8)
    c.cuerpo(spline([(40, 40), (88, 40), (96, 70), (84, 106), (64, 112), (44, 106), (32, 70)]), hexa('efe6d2'), sombra=0.2, luz=0.2, d=3, col_sombra=hexa('c8bc9c'))
    c.cuerpo(spline([(48, 90), (80, 90), (82, 106), (64, 112), (46, 106)]), hexa('f6c6bc'), sombra=0.2, luz=0.2, d=2)
    c.cuerpo(spline([(58, 108), (70, 108), (68, 126), (60, 126)], por_tramo=4), hexa('d9c9a8'), sombra=0.2, luz=0.2, d=1.4)
    for lado in (-1, 1):
        c.elip(64 + lado * 16, 66, 4.6, 3.4, hexa('3a3f52'), lado * 14)
    for lado in (-1, 1):
        c.punto(64 + lado * 5, 98, 2.2, hexa('b8586a'))


def cordero(c):
    for (x, y, r) in ((30, 56, 18), (52, 36, 20), (80, 34, 20), (102, 56, 18), (98, 86, 18), (28, 86, 18), (64, 44, 20)):
        c.cuerpo_elip(x, y, r, r, col=hexa('fbfbff'), sombra=0.15, luz=0, d=2.6, col_sombra=hexa('cdd4ea'))
    c.cuerpo(spline([(42, 52), (86, 52), (92, 84), (76, 112), (64, 116), (52, 112), (36, 84)]), hexa('4a4a5c'), sombra=0.2, luz=0.2, d=3)
    for lado in (-1, 1):
        c.cuerpo_elip(64 + lado * 36, 78, 14, 7, col=hexa('4a4a5c'), sombra=0.2, luz=0.2, d=1.6, ang=lado * 20)
    c.cuerpo_elip(64, 28, 20, 14, col=hexa('fbfbff'), sombra=0.15, luz=0, d=2, col_sombra=hexa('cdd4ea'))
    for lado in (-1, 1):
        c.punto(64 + lado * 12, 78, 3.8, hexa('f4f6ff'))
        c.punto(64 + lado * 12 + 1, 78, 1.8, NEGRO)
    for lado in (-1, 1):
        c.punto(64 + lado * 5, 100, 2.2, hexa('9aa0b8'))


def bufalo(c):
    for lado in (-1, 1):
        c.cuerpo(spline([(64 + lado * 30, 52), (64 + lado * 54, 40), (64 + lado * 62, 22), (64 + lado * 56, 14), (64 + lado * 50, 28), (64 + lado * 42, 38), (64 + lado * 26, 44)], cerrada=True), hexa('e8e0cc'), sombra=0.22, luz=0.2, d=2.2)
        c.cuerpo_elip(64 + lado * 40, 70, 10, 15, col=hexa('4a3a2c'), sombra=0.2, luz=0.2, d=1.6, ang=lado * 20)
    c.cuerpo(spline([(34, 46), (94, 46), (100, 80), (88, 114), (64, 124), (40, 114), (28, 80)]), hexa('5a4636'), sombra=0.22, luz=0.2, d=3.2)
    c.cuerpo(spline([(36, 92), (92, 92), (96, 112), (64, 124), (32, 112)]), hexa('8a7664'), sombra=0.2, luz=0.2, d=2.4)
    for lado in (-1, 1):
        c.punto(64 + lado * 20, 68, 4.4, hexa('f4f0e0'))
        c.punto(64 + lado * 20 + 1, 68, 2.2, NEGRO)
        c.punto(64 + lado * 10, 104, 3.2, hexa('2a1e14'))


def camello(c):
    # patas
    for x in (40, 52, 82, 94):
        c.cuerpo(spline([(x - 4, 80), (x + 4, 80), (x + 3, 120), (x - 3, 120)], por_tramo=3), hexa('c8a060') if x in (52, 82) else hexa('d8b070'), sombra=0.2, luz=0.1, d=1.6)
    # cuerpo y joroba
    c.cuerpo(spline([(26, 82), (34, 58), (46, 50), (58, 38), (72, 40), (82, 56), (104, 60), (110, 84), (96, 92), (44, 92)]), hexa('e0b87a'), sombra=0.2, luz=0.25, d=3.4)
    # cuello y cabeza
    c.cuerpo(spline([(20, 84), (22, 52), (16, 28), (28, 18), (40, 22), (40, 38), (40, 60), (38, 84)]), hexa('e0b87a'), sombra=0.2, luz=0.25, d=3)
    c.cuerpo(spline([(8, 22), (16, 14), (34, 14), (40, 24), (30, 32), (14, 32)]), hexa('e8c690'), sombra=0.2, luz=0.2, d=2)
    c.punto(28, 22, 2.6, NEGRO)
    c.cuerpo(spline([(110, 76), (118, 82), (116, 98), (110, 96)]), hexa('b8904e'), sombra=0.1, luz=0, d=1)


def caballo(c):
    c.cuerpo(spline([(46, 114), (34, 80), (40, 40), (60, 14), (80, 18), (84, 36), (100, 52), (112, 72), (106, 90), (90, 92), (84, 72), (74, 114)]), hexa('a0643a'), sombra=0.22, luz=0.25, d=3.2)
    # crin
    c.cuerpo(spline([(52, 14), (66, 8), (78, 20), (60, 40), (56, 68), (46, 112), (34, 82), (40, 42)]), hexa('3a2a22'), sombra=0.2, luz=0.2, d=2)
    # hocico
    c.cuerpo(spline([(90, 56), (110, 70), (112, 86), (98, 92), (86, 76)]), hexa('c48a58'), sombra=0.2, luz=0.2, d=2)
    c.punto(76, 40, 4.4, NEGRO)
    c.punto(77, 38.6, 1.4, hexa('ffffff'))
    c.punto(106, 80, 2.6, hexa('5a3a22'))
    c.cuerpo(hoja(60, 22, 72, 2, 5, curva=-1), hexa('3a2a22'), sombra=0.2, luz=0.2, d=1.4)


def cuy(c):
    c.cuerpo_elip(66, 84, 44, 30, col=hexa('c48a58'), sombra=0.22, luz=0.25, d=3.4, ang=-6)
    c.cuerpo(spline([(22, 66), (40, 54), (58, 62), (62, 82), (46, 100), (24, 94)]), hexa('f6f1e4'), sombra=0.2, luz=0.2, d=2.4)
    c.cuerpo_elip(74, 74, 14, 9, col=hexa('f6f1e4'), sombra=0.2, luz=0.2, d=1.6, ang=-20)
    c.cuerpo_elip(44, 54, 7, 9, col=hexa('d99a9a'), sombra=0.2, luz=0.2, d=1.4, ang=-20)
    c.cuerpo_elip(60, 60, 6, 8, col=hexa('d99a9a'), sombra=0.2, luz=0.2, d=1.4, ang=10)
    c.punto(32, 74, 3.4, NEGRO)
    c.punto(22, 80, 2.4, hexa('7a4a3a'))


def _pez(c, cuerpo, vientre, aleta, ojo=NEGRO, rayas=None, manchas=None):
    c.cuerpo(spline([(94, 64), (116, 38), (118, 90)], por_tramo=6, cerrada=True), aleta, sombra=0.2, luz=0.2, d=2.2)
    c.cuerpo(spline([(50, 40), (64, 20), (84, 34)], por_tramo=6, cerrada=True), aleta, sombra=0.2, luz=0.2, d=2)
    c.cuerpo(spline([(50, 90), (62, 110), (82, 94)], por_tramo=6, cerrada=True), aleta, sombra=0.2, luz=0.2, d=2)
    m = c.cuerpo(spline([(8, 64), (28, 42), (62, 34), (96, 52), (100, 64), (96, 76), (62, 94), (28, 86)]), cuerpo, sombra=0.2, luz=0.3, d=3.2)
    def det(t):
        t.poly(spline([(0, 80), (40, 70), (100, 70), (110, 110), (0, 110)]), vientre)
        if rayas:
            for x in (40, 54, 68, 82):
                t.linea([(x, 32), (x - 5, 96)], 3.4, rayas)
        if manchas:
            for (x, y) in manchas:
                t.punto(x, y, 2.6, hexa('3a4258'))
    c.recortada(m, det)
    c.punto(28, 60, 5, hexa('ffffff'))
    c.punto(28, 60, 3, ojo)
    c.linea(bezier((38, 46), (42, 64), (38, 84), 10), 1.8, oscuro(cuerpo, 0.3))


def pescado(c):
    _pez(c, hexa('6ea8e8'), hexa('d8e8fa'), hexa('4a78c8'), rayas=hexa('4a78c8'))


def salmon(c):
    _pez(c, hexa('a4b4cc'), hexa('f4aa8a'), hexa('7a8aa8'), manchas=[(56, 50), (66, 46), (76, 52), (84, 58), (48, 44), (70, 58)])


def pesca(c):
    pescado(c)


def camaron(c):
    pts = bezier((92, 40), (126, 56), (100, 112), 20) + bezier((100, 112), (60, 130), (30, 94), 20)[1:]
    c.linea(pts, 20, hexa('f08a5a'))
    c.linea(pts, 9, hexa('f6b08a'))
    for i in range(3, 36, 6):
        x, y = pts[i]
        c.linea([(x - 8, y - 6), (x + 8, y + 6)], 1.6, hexa('d9602a'))
    # cola
    c.cuerpo(spline([(32, 96), (14, 108), (22, 120), (36, 112), (42, 118), (44, 104)], por_tramo=4, cerrada=True), hexa('e86a3a'), sombra=0.2, luz=0.2, d=1.8)
    # cabeza + antenas
    c.cuerpo_elip(88, 42, 18, 14, col=hexa('e86a3a'), sombra=0.2, luz=0.3, d=2.4, ang=-20)
    c.linea(bezier((98, 34), (112, 14), (124, 20), 8), 1.6, hexa('d9602a'))
    c.linea(bezier((92, 30), (100, 8), (118, 6), 8), 1.6, hexa('d9602a'))
    c.punto(94, 40, 3.4, NEGRO)


def ninguno(c):
    c.linea([(36, 36), (92, 92)], 10, hexa('6a7388'))
    c.linea([(92, 36), (36, 92)], 10, hexa('6a7388'))


ICONOS = {
    'res': res, 'cerdo': cerdo, 'pollo': pollo, 'cabra': cabra, 'cordero': cordero, 'bufalo': bufalo, 'camello': camello, 'caballo': caballo, 'cuy': cuy,
    'pescado': pescado, 'salmon': salmon, 'pesca': pesca, 'camaron': camaron, 'ninguno': ninguno,
}
