#!/usr/bin/env python3
"""Iconos nuevos de 0.1.7.9.1 (control de velocidad, moneda, debug) y 0.1.7.9.9B (velocidades 4-6, editar país). No toca los iconos anteriores. Requiere pillow."""
import os
from PIL import Image, ImageDraw

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(RAIZ, 'iconos')
S = 4


def c(*v):
    return tuple(int(x * S) for x in v)


def icono(nombre, f, col=(235, 240, 255, 255)):
    im = Image.new('RGBA', (96 * S, 96 * S), (0, 0, 0, 0))
    f(ImageDraw.Draw(im), col)
    im.resize((96, 96), Image.LANCZOS).save(os.path.join(OUT, nombre + '.png'))


def tri(d, x, col, w=26):
    d.polygon([c(x, 20), c(x + w, 48), c(x, 76)], fill=col)

def vel1(d, k):
    tri(d, 30, k, 38)

def vel2(d, k):
    tri(d, 14, k, 32); tri(d, 48, k, 32)

def vel3(d, k):
    tri(d, 6, k, 28); tri(d, 34, k, 28); tri(d, 62, k, 28)

def moneda(d, k):
    d.ellipse(c(10, 10, 86, 86), fill=(240, 200, 70, 255)); d.ellipse(c(20, 20, 76, 76), outline=(190, 140, 30, 255), width=5 * S)
    d.rounded_rectangle(c(44, 28, 52, 68), radius=3 * S, fill=(190, 140, 30, 255))
    d.rounded_rectangle(c(34, 34, 62, 42), radius=3 * S, fill=(190, 140, 30, 255))
    d.rounded_rectangle(c(34, 54, 62, 62), radius=3 * S, fill=(190, 140, 30, 255))

def debug(d, k):
    # escarabajo (bug)
    verde = (120, 220, 150, 255)
    d.ellipse(c(30, 12, 66, 40), fill=verde)
    d.ellipse(c(24, 34, 72, 86), fill=verde)
    d.line([c(48, 36), c(48, 84)], fill=(20, 40, 30, 255), width=3 * S)
    for y in (46, 60, 74):
        d.line([c(24, y), c(8, y - 8)], fill=verde, width=4 * S); d.line([c(72, y), c(88, y - 8)], fill=verde, width=4 * S)
    d.line([c(40, 14), c(32, 4)], fill=verde, width=3 * S); d.line([c(56, 14), c(64, 4)], fill=verde, width=3 * S)

def tpausa(d, k):
    # pausa del reloj: dos barras (más pequeñas que el botón de menú) dentro de un aro
    d.ellipse(c(10, 10, 86, 86), outline=k, width=6 * S)
    d.rounded_rectangle(c(34, 30, 43, 66), radius=2 * S, fill=k)
    d.rounded_rectangle(c(53, 30, 62, 66), radius=2 * S, fill=k)


def chevrons(d, k, n, ancho, paso, x0):
    for i in range(n):
        tri(d, x0 + i * paso, k, ancho)

def vel4(d, k):
    chevrons(d, (255, 190, 90, 255), 4, 20, 22, 4)

def vel5(d, k):
    chevrons(d, (255, 150, 80, 255), 5, 16, 18, 3)

def vel6(d, k):
    chevrons(d, (255, 110, 90, 255), 6, 13, 15, 3)

def editar(d, k):
    # lápiz en diagonal
    d.polygon([c(60, 14), c(82, 36), c(36, 82), c(12, 86), c(14, 60)], fill=(240, 200, 70, 255))
    d.polygon([c(60, 14), c(70, 4), c(92, 26), c(82, 36)], fill=(235, 120, 120, 255))
    d.polygon([c(14, 60), c(36, 82), c(12, 86)], fill=(245, 230, 200, 255))
    d.polygon([c(12, 86), c(14, 74), c(24, 84)], fill=(60, 60, 70, 255))

for n, f in (('vel1', vel1), ('vel2', vel2), ('vel3', vel3), ('moneda', moneda), ('debug', debug), ('tpausa', tpausa), ('vel4', vel4), ('vel5', vel5), ('vel6', vel6), ('editar', editar)):
    icono('i_' + n, f)
print('iconos nuevos: i_vel1 i_vel2 i_vel3 i_moneda i_debug i_tpausa i_vel4 i_vel5 i_vel6 i_editar')
