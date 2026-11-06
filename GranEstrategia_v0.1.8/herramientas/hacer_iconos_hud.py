#!/usr/bin/env python3
"""Icono nuevo de 0.1.8: i_dipl (pestaña Diplomacia: un globo con una bandera blanca). Requiere pillow."""
import os
from PIL import Image, ImageDraw

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(RAIZ, 'iconos')
S = 4


def c(*v):
    return tuple(int(x * S) for x in v)


def dipl():
    im = Image.new('RGBA', (96 * S, 96 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    azul = (70, 120, 200, 255)
    claro = (150, 190, 245, 255)
    verde = (88, 190, 110, 255)
    oro = (232, 196, 90, 255)
    d.ellipse(c(10, 22, 70, 82), fill=azul)
    d.ellipse(c(22, 30, 40, 48), fill=verde)
    d.ellipse(c(36, 50, 58, 72), fill=verde)
    d.ellipse(c(44, 28, 62, 40), fill=verde)
    d.ellipse(c(10, 22, 70, 82), outline=claro, width=3 * S)
    d.arc(c(24, 22, 56, 82), 90, 270, fill=claro, width=2 * S)
    d.arc(c(24, 22, 56, 82), -90, 90, fill=claro, width=2 * S)
    d.line([c(10, 52), c(70, 52)], fill=claro, width=2 * S)
    d.line([c(70, 14), c(70, 66)], fill=oro, width=4 * S)
    d.polygon([c(72, 16), c(92, 22), c(72, 30)], fill=(245, 247, 255, 255))
    d.ellipse(c(66, 10, 74, 18), fill=oro)
    im.resize((96, 96), Image.LANCZOS).save(os.path.join(OUT, 'i_dipl.png'))


if __name__ == '__main__':
    dipl()
    print('OK iconos ->', OUT)
