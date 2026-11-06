#!/usr/bin/env python3
"""Iconos de 0.1.7.9.9D: ejército (escudo con espadas cruzadas) y devastación (llama sobre ruinas). Requiere pillow."""
import os
from PIL import Image, ImageDraw

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(RAIZ, 'iconos')
S = 4


def c(*v):
    return tuple(int(x * S) for x in v)


def icono(nombre, f):
    im = Image.new('RGBA', (96 * S, 96 * S), (0, 0, 0, 0))
    f(ImageDraw.Draw(im))
    im.resize((96, 96), Image.LANCZOS).save(os.path.join(OUT, nombre + '.png'))


def ejercito(d):
    acero = (205, 214, 232, 255)
    oro = (232, 196, 90, 255)
    # dos espadas cruzadas
    d.line([c(18, 18), c(78, 78)], fill=acero, width=7 * S)
    d.line([c(78, 18), c(18, 78)], fill=acero, width=7 * S)
    for (x, y, dx, dy) in ((26, 26, 1, -1), (70, 26, -1, -1)):
        d.line([c(x - 8 * dx, y + 8 * dy * -1), c(x + 8 * dx, y - 8 * dy * -1)], fill=oro, width=5 * S)
    # escudo al centro
    d.polygon([c(48, 24), c(70, 32), c(68, 58), c(48, 76), c(28, 58), c(26, 32)], fill=(60, 96, 170, 255), outline=oro)
    d.line([c(26, 32), c(48, 24), c(70, 32), c(68, 58), c(48, 76), c(28, 58), c(26, 32)], fill=oro, width=3 * S)
    d.polygon([c(48, 34), c(52, 44), c(63, 44), c(54, 51), c(57, 62), c(48, 55), c(39, 62), c(42, 51), c(33, 44), c(44, 44)], fill=oro)


def devast(d):
    # ruinas (muros rotos) y una llama
    piedra = (150, 140, 130, 255)
    d.polygon([c(10, 84), c(10, 56), c(24, 56), c(24, 66), c(36, 66), c(36, 48), c(50, 48), c(50, 84)], fill=piedra)
    d.polygon([c(56, 84), c(56, 60), c(70, 60), c(70, 70), c(86, 70), c(86, 84)], fill=piedra)
    fuego = (255, 140, 40, 255)
    d.polygon([c(44, 52), c(36, 36), c(44, 28), c(42, 14), c(56, 26), c(62, 38), c(58, 52)], fill=fuego)
    d.polygon([c(47, 52), c(43, 42), c(49, 36), c(54, 44), c(54, 52)], fill=(255, 215, 90, 255))


if __name__ == '__main__':
    icono('i_ejercito', ejercito)
    icono('i_devast', devast)
    print('OK iconos ->', OUT)
