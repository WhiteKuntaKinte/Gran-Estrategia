#!/usr/bin/env python3
"""0.1.8.37 · Icono i_lentes (botón VISTA de la barra superior): una lupa / lente de una sola tinta (blanca), para que el tema la tiña
(oscura sobre el pergamino, clara sobre los temas oscuros). Genera iconos/i_lentes.png de 96x96. Requiere pillow."""
import os, math
from PIL import Image, ImageDraw

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(RAIZ, 'iconos', 'i_lentes.png')
S = 4


def c(*v):
    return tuple(int(x * S) for x in v)


im = Image.new('RGBA', (96 * S, 96 * S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
blanco = (240, 244, 255, 255)
# aro de la lente
d.ellipse(c(10, 10, 62, 62), outline=blanco, width=7 * S)
# destello dentro del cristal
d.arc(c(20, 20, 52, 52), 200, 262, fill=(240, 244, 255, 190), width=4 * S)
# mango (grueso, con puntas redondeadas)
x0, y0 = 56, 56
x1, y1 = 86, 86
d.line([c(x0, y0), c(x1, y1)], fill=blanco, width=11 * S)
for (x, y) in ((x0, y0), (x1, y1)):
    d.ellipse(c(x - 5.5, y - 5.5, x + 5.5, y + 5.5), fill=blanco)
im.resize((96, 96), Image.LANCZOS).save(OUT)
print('ok', OUT)
