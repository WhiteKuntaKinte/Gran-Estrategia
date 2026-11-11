#!/usr/bin/env python3
"""Hoja de contacto de los iconos dibujados (para revisarlos a ojo).

  python3 vista_previa.py MODULO[,MODULO...] SALIDA.png [fondo oscuro|claro] [desde] [hasta]
  MODULO = cultivos, animales, minerales, energia, sectores...
"""
import importlib
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lienzo import Lienzo, N


def main():
    mods = sys.argv[1].split(',')
    salida = sys.argv[2]
    fondo = (58, 62, 78, 255) if (len(sys.argv) < 4 or sys.argv[3] == 'oscuro') else (232, 224, 204, 255)
    desde = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    hasta = int(sys.argv[5]) if len(sys.argv) > 5 else 10 ** 6
    items = []
    for m in mods:
        mod = importlib.import_module(m)
        for k, f in mod.ICONOS.items():
            items.append((k, f))
    items = items[desde:hasta]
    cols = 10
    celda = N + 20
    filas = (len(items) + cols - 1) // cols
    hoja = Image.new('RGBA', (cols * celda, filas * (celda + 14)), fondo)
    d = ImageDraw.Draw(hoja)
    fuente = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 10)
    for i, (k, f) in enumerate(items):
        c = Lienzo()
        try:
            f(c)
        except Exception as e:
            print('ERROR', k, e)
            raise
        x, y = (i % cols) * celda + 10, (i // cols) * (celda + 14) + 4
        hoja.alpha_composite(c.im.resize((N, N), Image.LANCZOS), (x, y))
        d.text((x, y + N + 1), k, fill=(255, 255, 255, 255) if fondo[0] < 100 else (30, 30, 30, 255), font=fuente)
    hoja.save(salida)
    print(len(items), 'iconos ->', salida)


if __name__ == '__main__':
    main()
