#!/usr/bin/env python3
"""
Banderas en HD (0.1.8.41): vuelve a dibujar cada bandera de banderas/ a 256 px de ancho en banderas_hd/ con el MISMO nombre.

  python3 herramientas/preparar_banderas_hd.py RUTA_SVG[:RUTA_SVG2...]

  RUTA_SVG = carpeta 'svg' del repositorio de banderas (https://github.com/oxguy3/flags, dominio público salvo lo que dice su SPECIAL_LICENSES.csv).
  Las mismas rutas que se dieron a preparar_banderas.py, separadas por ':' (gana la primera que tenga el archivo): oxguy3/flags y
  redoper1/flags (esta segunda trae Rusia, Japón, Brasil, Italia, Polonia, Bélgica, Austria, Chile, Dinamarca...).
Cada archivo de banderas/ se rehace desde su vector:
  p_<cc>.png      -> svg/<cc>.svg                 país
  s_<a>_<b>.png   -> svg/<a>/<b>.svg              provincia, región o estado
  c_us_<st>_<ciudad>.png -> svg/us/<st>/<ciudad>.svg   ciudad de EE. UU.
  e1_<pueblo>.png -> el estandarte del año 1 se dibuja otra vez con el mismo color y el mismo dibujo (herramientas/epoca/construir_epoca.py)
  x.png           -> la X negra de «sin bandera»
Las de 96 px (banderas/) se quedan: son las de las listas, el mapa y las tropas. Las HD las pide `bandera_hd()` del juego para el panel grande.
Las banderas con licencia especial (CC BY / CC BY-SA, ver CIUDADES_US_CON_LICENCIA en tablas_estados.py) no se usan: esas ciudades llevan la bandera de su estado.
Requiere: rsvg-convert, pillow.
"""
import os
import subprocess
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tablas_estados import CIUDADES_US_CON_LICENCIA

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
ORIGEN = os.path.join(RAIZ, 'banderas')
SAL = os.path.join(RAIZ, 'banderas_hd')
ANCHO = 256
ALTO_MAX = 192                      # banderas casi cuadradas (Nepal, Suiza...) se limitan en alto, igual que las de 96 px (72 de 96)


def rasterizar(svg, destino):
    r = subprocess.run(['rsvg-convert', '-w', str(ANCHO), '-a', svg, '-o', destino], capture_output=True)
    if r.returncode != 0 or not os.path.exists(destino):
        return False
    im = Image.open(destino).convert('RGBA')
    if im.height > ALTO_MAX:
        im = im.resize((int(im.width * ALTO_MAX / im.height), ALTO_MAX), Image.LANCZOS)
    im.save(destino, optimize=True)
    return True


def bandera_x(destino):
    im = Image.new('RGB', (ANCHO, 171), (0, 0, 0))
    d = ImageDraw.Draw(im)
    k = ANCHO / 96.0
    d.line([(14 * k, 8 * k), ((96 - 14) * k, 56 * k)], fill=(255, 255, 255), width=int(7 * k))
    d.line([(14 * k, 56 * k), ((96 - 14) * k, 8 * k)], fill=(255, 255, 255), width=int(7 * k))
    im.save(destino, optimize=True)


def estandarte(archivo96, destino):
    """Año 1: color (un píxel que ningún dibujo toca) y dibujo (el que reproduce el de 96 px al pixel) -> el mismo a 256 px."""
    sys.path.insert(0, os.path.join(AQUI, 'epoca'))
    import importlib.util
    spec = importlib.util.spec_from_file_location('construir_epoca', os.path.join(AQUI, 'epoca', 'construir_epoca.py'))
    ce = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ce)
    im = Image.open(archivo96).convert('RGB')
    hexcol = '%02x%02x%02x' % im.getpixel((90, 19))
    ref = im.tobytes()
    tmp = destino + '.tmp.png'
    for forma in range(ce.FORMAS_BANDERA):
        ce.hacer_bandera('x', hexcol, tmp, ancho=96, forma=forma)
        if Image.open(tmp).convert('RGB').tobytes() == ref:
            ce.hacer_bandera('x', hexcol, destino, ancho=ANCHO, forma=forma)
            os.remove(tmp)
            return True
    if os.path.exists(tmp):
        os.remove(tmp)
    return False


def partes_de(nombre):
    if nombre.startswith('p_'):
        return (nombre[2:] + '.svg',)
    if nombre.startswith('s_'):
        a, b = nombre[2:].split('_', 1)
        return (a, b + '.svg')
    if nombre.startswith('c_us_'):
        st, ciudad = nombre[len('c_us_'):].split('_', 1)
        return ('us', st, ciudad + '.svg')
    return None


def svg_de(svg_dirs, nombre):
    partes = partes_de(nombre)
    if partes is None:
        return None
    for d in svg_dirs:
        f = os.path.join(d, *partes)
        if os.path.exists(f):
            return f
    return None


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    svg_dirs = sys.argv[1].split(':')
    os.makedirs(SAL, exist_ok=True)
    hechas, fallos, quitadas = 0, [], []
    for f in sorted(os.listdir(ORIGEN)):
        if not f.endswith('.png'):
            continue
        nombre = f[:-4]
        destino = os.path.join(SAL, f)
        if nombre in CIUDADES_US_CON_LICENCIA:
            quitadas.append(nombre)
            continue
        if nombre == 'x':
            bandera_x(destino)
            ok = True
        elif nombre.startswith('e1_'):
            ok = estandarte(os.path.join(ORIGEN, f), destino)
        else:
            svg = svg_de(svg_dirs, nombre)
            ok = svg is not None and rasterizar(svg, destino)
        if ok:
            hechas += 1
        else:
            fallos.append(nombre)
    peso = sum(os.path.getsize(os.path.join(SAL, f)) for f in os.listdir(SAL)) / 1e6
    print('banderas HD: %d hechas (%.1f MB) · sin vector: %s · excluidas por licencia: %s' % (hechas, peso, fallos, quitadas))


if __name__ == '__main__':
    main()
