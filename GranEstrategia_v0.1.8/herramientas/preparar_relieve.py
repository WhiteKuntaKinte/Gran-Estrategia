#!/usr/bin/env python3
"""
Prepara la textura de relieve del mapa (0.1.8.35): datos/texturas/relieve.png

El juego multiplica esta imagen sobre los colores de las provincias (ver SHADER_RELIEVE en MapaPrincipal.gd). Para que no cambie el color general
del mapa, el gris medio de la imagen tiene que ser 0,5: este script la pasa a escala de grises, la lleva a ese gris medio y la guarda con el tamaño pedido.

Uso:
    python3 -I herramientas/preparar_relieve.py ENTRADA [--ancho 4096] [--contraste 1.0] [--salida datos/texturas/relieve.png]

  ENTRADA     cualquier imagen del mundo entero en proyección equirectangular (2:1), p. ej. el relieve sombreado de Natural Earth
              (repositorio nvkelso/natural-earth-raster; son de dominio público). PNG, JPG o TIFF que lea Pillow.
  --ancho     ancho final en píxeles (la altura es la mitad). 2048 = ligero, 4096 = bueno, 8192 = muy detallado y pesado en memoria de vídeo.
  --contraste 1.0 deja el contraste como viene; 1.5 acentúa el relieve; 0.7 lo suaviza.

Con la calidad gráfica Baja el relieve no se dibuja, así que PCs modestos no pagan por él.
"""
import argparse
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Falta Pillow: pip install pillow --break-system-packages")

Image.MAX_IMAGE_PIXELS = None


def preparar(entrada, salida, ancho, contraste):
    img = Image.open(entrada)
    w, h = img.size
    if abs(w / h - 2.0) > 0.05:
        print("AVISO: la imagen mide %dx%d; el mapa espera una proyección equirectangular 2:1. Se estira a 2:1." % (w, h))
    alto = ancho // 2
    gris = img.convert("L").resize((ancho, alto), Image.LANCZOS)
    datos = list(gris.getdata())
    media = sum(datos) / len(datos) / 255.0
    # Lleva la media a 0,5 y aplica el contraste alrededor de ese punto
    salida_px = []
    for v in datos:
        x = v / 255.0 - media
        y = 0.5 + x * contraste
        salida_px.append(max(0, min(255, int(round(y * 255.0)))))
    out = Image.new("L", (ancho, alto))
    out.putdata(salida_px)
    os.makedirs(os.path.dirname(os.path.abspath(salida)), exist_ok=True)
    out.save(salida, optimize=True)
    print("Relieve guardado en %s (%dx%d, gris medio original %.2f → 0,50, contraste %.2f)" % (salida, ancho, alto, media, contraste))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Prepara datos/texturas/relieve.png a partir de una imagen equirectangular del mundo.")
    ap.add_argument("entrada")
    ap.add_argument("--ancho", type=int, default=4096)
    ap.add_argument("--contraste", type=float, default=1.0)
    ap.add_argument("--salida", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "datos", "texturas", "relieve.png"))
    a = ap.parse_args()
    if a.ancho < 256 or a.ancho > 16384:
        sys.exit("--ancho debe estar entre 256 y 16384")
    preparar(a.entrada, a.salida, a.ancho, a.contraste)
