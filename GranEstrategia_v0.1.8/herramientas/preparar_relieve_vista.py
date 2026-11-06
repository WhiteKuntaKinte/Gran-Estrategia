#!/usr/bin/env python3
"""
Prepara las texturas de la vista «Relieve» del mapa (0.1.8.37): datos/texturas/relieve_vista_2048.jpg, _4096.jpg y _8192.jpg

Cada imagen es el mundo entero en proyección equirectangular (2:1; x = longitud, y = latitud, igual que el mapa del juego) ya pintado:
  · Tierra   colores hipsométricos según la altura (ETOPO 2022, NOAA): verde azulado cerca del mar → verdes → amarillos → ocres → marrones → gris claro en
             lo más alto. Con relieve sombreado (luz desde el noroeste) para que se vean las cordilleras.
  · Mar      paleta propia según la profundidad (turquesa en la plataforma → azul marino en las fosas), también con sombreado del fondo.
  · Costa    de Natural Earth 10m (`land`), suavizada (antialiasing) para que coincida con la costa del juego.
  · Lagos    de Natural Earth 10m (`lakes`): agua lisa.
  · Hielo    de Natural Earth 10m (`glaciated_areas` y `antarctic_ice_shelves_polys`): blanco azulado con algo de sombreado.
En el juego (MapaPrincipal.gd, vista «Relieve») la imagen se estira sobre el mapa; con calidad Baja se usa la de 2048, con Media la de 4096 y con Alta la de 8192.

Uso (desde la carpeta del proyecto):
    python3 -I herramientas/preparar_relieve_vista.py ETOPO.tif CARPETA_GEOJSON_NE [--salida datos/texturas]

  ETOPO.tif        ETOPO_2022_v1_60s_N90W180_surface.tif (NOAA, ~465 MB; dominio público). Release «datos-etopo» del repositorio, o ngdc.noaa.gov.
  CARPETA_GEOJSON  carpeta `geojson` del repositorio nvkelso/natural-earth-vector (se usan ne_10m_land, ne_10m_lakes, ne_10m_glaciated_areas,
                   ne_10m_antarctic_ice_shelves_polys).
Requiere: python3, numpy, pillow, tifffile (el lector del .tif está en herramientas/leer_etopo.py). Tarda unos minutos y gasta ~4 GB de memoria.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from leer_etopo import leer_etopo

Image.MAX_IMAGE_PIXELS = None

ANCHO = 8192                                  # resolución de trabajo; las demás se sacan de esta
ALTO = ANCHO // 2
SUPER = 2                                     # las máscaras de costa/lagos/hielo se dibujan al doble y se reducen (bordes suaves)
TAMANOS = [2048, 4096, 8192]
CALIDAD_JPG = 92

# Tierra: (metros, color). Entre dos paradas se mezcla linealmente.
TIERRA = [(0, "3f9a78"), (40, "58a86a"), (150, "86b96b"), (400, "bcc579"), (800, "dcc27a"), (1400, "cf9f5f"), (2200, "b27c48"),
          (3200, "8c5b38"), (4500, "6e4630"), (6000, "8a7468"), (8800, "d8d0c8")]
# Mar: (metros de profundidad, color)
MAR = [(0, "86d0d8"), (50, "6bbfd0"), (200, "4aa3c4"), (1000, "2f7cae"), (2500, "20609a"), (4500, "153f78"), (6500, "0d2a58"), (11000, "071a3b")]
COLOR_LAGO = "3a86a8"
COLOR_HIELO = "eef4f8"
LUZ_AZIMUT = 315.0                            # grados (0 = norte, sentido horario): luz desde el noroeste
LUZ_ALTURA = 40.0
EXAGERA_TIERRA = 3.0
EXAGERA_MAR = 2.0


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def rampa(valores, paradas):
    """Color (…, 3) de cada valor según las paradas (metros, hex)."""
    xs = np.array([p[0] for p in paradas], dtype=np.float32)
    cs = np.stack([hexc(p[1]) for p in paradas])
    return np.stack([np.interp(valores, xs, cs[:, c]) for c in range(3)], axis=-1).astype(np.float32)


def a_pixel(lon, lat, ancho, alto):
    return ((lon + 180.0) / 360.0 * ancho, (90.0 - lat) / 180.0 * alto)


def mascara(ruta, ancho, alto):
    """Máscara (0..1, float32) de los polígonos de un GeoJSON, dibujada al doble de tamaño y reducida."""
    with open(ruta, encoding="utf-8") as f:
        gj = json.load(f)
    W, H = ancho * SUPER, alto * SUPER
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    n = 0
    for feat in gj["features"]:
        g = feat["geometry"]
        if g is None:
            continue
        polis = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poli in polis:
            for i, anillo in enumerate(poli):
                pts = [a_pixel(x, y, W, H) for x, y in (p[:2] for p in anillo)]
                if len(pts) >= 3:
                    d.polygon(pts, fill=255 if i == 0 else 0)          # el primer anillo es el exterior; los demás, huecos
            n += 1
    print("  %s: %d polígonos" % (os.path.basename(ruta), n))
    return np.asarray(img.resize((ancho, alto), Image.BOX), dtype=np.float32) / 255.0


def reducir_f(a, ancho, alto):
    return np.asarray(Image.fromarray(a, mode="F").resize((ancho, alto), Image.BOX), dtype=np.float32)


def sombreado(z, ancho, alto):
    """Factor de sombreado (1 = plano) con la luz fija; se calcula a media resolución del ETOPO y se reduce a ancho x alto."""
    h2, w2 = z.shape[0] // 2, z.shape[1] // 2
    zz = z[: h2 * 2, : w2 * 2].reshape(h2, 2, w2, 2).mean(axis=(1, 3))
    lat = np.linspace(90.0 - 90.0 / h2, -90.0 + 90.0 / h2, h2)
    paso_y = 111320.0 * (180.0 / h2)                                     # metros por píxel hacia el norte
    paso_x = paso_y * np.maximum(np.cos(np.radians(lat)), 0.05)[:, None]  # (hacia el este se acortan con la latitud)
    exag = np.where(zz >= 0.0, EXAGERA_TIERRA, EXAGERA_MAR).astype(np.float32)
    dzdy, dzdx = np.gradient(zz)
    gx = dzdx / paso_x * exag
    gy = dzdy / paso_y * exag                                              # (las filas crecen hacia el sur)
    pend = np.arctan(np.hypot(gx, gy))
    # dirección hacia donde mira la ladera (azimut desde el norte): la pendiente baja hacia (-gx, +gy en «norte arriba»)
    aspecto = np.arctan2(-gx, gy)
    az = np.radians(LUZ_AZIMUT)
    alt = np.radians(LUZ_ALTURA)
    luz = np.sin(alt) * np.cos(pend) + np.cos(alt) * np.sin(pend) * np.cos(az - aspecto)
    factor = (luz / np.sin(alt)).astype(np.float32)
    return reducir_f(np.ascontiguousarray(factor), ancho, alto)


def main():
    ap = argparse.ArgumentParser(description="Prepara las texturas de la vista Relieve a partir de ETOPO 2022 y Natural Earth.")
    ap.add_argument("etopo")
    ap.add_argument("ne_geojson")
    ap.add_argument("--salida", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "datos", "texturas"))
    a = ap.parse_args()
    ne = a.ne_geojson

    print("Leyendo ETOPO…")
    z = leer_etopo(a.etopo)
    print("Elevación:", z.shape, float(z.min()), float(z.max()))
    print("Sombreado…")
    sombra = sombreado(z, ANCHO, ALTO)
    h_tierra = reducir_f(np.maximum(z, 0.0), ANCHO, ALTO)
    prof = reducir_f(np.maximum(-z, 0.0), ANCHO, ALTO)
    del z

    print("Máscaras de Natural Earth…")
    tierra = mascara(os.path.join(ne, "ne_10m_land.geojson"), ANCHO, ALTO)
    lagos = mascara(os.path.join(ne, "ne_10m_lakes.geojson"), ANCHO, ALTO)
    hielo = mascara(os.path.join(ne, "ne_10m_glaciated_areas.geojson"), ANCHO, ALTO)
    plataformas = mascara(os.path.join(ne, "ne_10m_antarctic_ice_shelves_polys.geojson"), ANCHO, ALTO)
    tierra = np.maximum(tierra, plataformas)                                # las plataformas de hielo de la Antártida cuentan como tierra
    hielo = np.maximum(hielo, plataformas)

    print("Pintando…")
    col_tierra = rampa(h_tierra, TIERRA)
    col_mar = rampa(prof, MAR)
    del h_tierra, prof
    t = tierra[..., None]
    col = col_tierra * t + col_mar * (1.0 - t)
    del col_tierra, col_mar
    # el sombreado: la tierra y el mar se oscurecen/aclaran un poco distinto; el hielo casi plano
    f_tierra = np.clip(sombra, 0.55, 1.30)
    f_mar = np.clip(1.0 + (sombra - 1.0) * 0.8, 0.70, 1.20)
    f = (f_tierra * t[..., 0] + f_mar * (1.0 - t[..., 0]))[..., None]
    col *= f
    hi = (hielo * tierra)[..., None]
    col = col * (1.0 - hi) + hexc(COLOR_HIELO) * np.clip(0.92 + (f - 1.0) * 0.5, 0.78, 1.04) * hi
    lg = lagos[..., None]
    col = col * (1.0 - lg) + hexc(COLOR_LAGO) * lg
    img = Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), mode="RGB")
    del col

    os.makedirs(a.salida, exist_ok=True)
    for ancho in TAMANOS:
        im = img if ancho == ANCHO else img.resize((ancho, ancho // 2), Image.LANCZOS)
        ruta = os.path.join(a.salida, "relieve_vista_%d.jpg" % ancho)
        im.save(ruta, quality=CALIDAD_JPG, subsampling=0, optimize=True)
        print("  %s  (%d x %d, %.1f MB)" % (ruta, im.width, im.height, os.path.getsize(ruta) / 1048576.0))


if __name__ == "__main__":
    main()
