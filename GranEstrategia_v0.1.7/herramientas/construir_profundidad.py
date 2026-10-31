#!/usr/bin/env python3
"""Genera una textura de profundidad marina a partir de las isóbatas vectoriales Natural Earth 10m.

Entrada: carpeta con ne_10m_bathymetry_{A..L}_{depth}.shp y sus archivos asociados.
Salida: datos/profundidad_maritima.png (2x respecto al mapa del juego).
"""
from __future__ import annotations
import argparse
import json
import math
import re
import time
from pathlib import Path

import shapefile
from PIL import Image, ImageDraw, ImageFilter

ANCHO_MAPA = 2400
ALTO_MAPA = 1200
ESCALA = 2
ANCHO = ANCHO_MAPA * ESCALA
ALTO = ALTO_MAPA * ESCALA

# La plataforma costera es más clara; las cuencas profundas son más oscuras.
PALETA = {
    0: (47, 111, 132), 200: (34, 91, 116), 1000: (23, 69, 98),
    2000: (17, 55, 82), 3000: (13, 46, 72), 4000: (10, 39, 64),
    5000: (8, 33, 57), 6000: (7, 28, 50), 7000: (6, 23, 43),
    8000: (5, 19, 37), 9000: (4, 15, 31), 10000: (3, 12, 25),
}
PATRON = re.compile(r"ne_10m_bathymetry_([A-L])_(\d+)\.shp$", re.I)


def proyectar(lon: float, lat: float) -> tuple[float, float]:
    """Misma proyección cilíndrica equivalente usada por construir_mapa.py."""
    lon = float(lon)  # puede exceder +/-180 al desenvolver la costura del mapa
    lat = max(-90.0, min(90.0, float(lat)))
    x = (lon + 180.0) / 360.0 * ANCHO_MAPA
    y = 600.0 * (1.0 - math.sin(math.radians(lat)))
    return x * ESCALA, y * ESCALA


def anillos_shape(shp):
    """Devuelve polígonos como [anillo exterior, anillos interiores...]."""
    geo = shp.__geo_interface__
    tipo = geo.get("type")
    coords = geo.get("coordinates", [])
    if tipo == "Polygon":
        return [coords]
    if tipo == "MultiPolygon":
        return coords
    return []


def desempaquetar_longitudes(ring):
    """Evita que anillos que cruzan el antimeridiano dibujen una diagonal mundial."""
    if not ring:
        return []
    out = []
    previo = None
    ajuste = 0.0
    for punto in ring:
        lon, lat = float(punto[0]), float(punto[1])
        if previo is not None:
            delta = lon + ajuste - previo
            if delta > 180.0:
                ajuste -= 360.0
            elif delta < -180.0:
                ajuste += 360.0
        out.append(proyectar(lon + ajuste, lat))
        previo = lon + ajuste
    return out


def dibujar_poligono(draw, rings):
    if not rings:
        return
    exterior = desempaquetar_longitudes(rings[0])
    if len(exterior) < 3:
        return
    # Repite el anillo +/- un mundo para resolver la costura 180°/-180°.
    for offset in (-ANCHO, 0, ANCHO):
        draw.polygon([(round(x + offset), round(y)) for x, y in exterior], fill=255)
        for agujero in rings[1:]:
            pts = desempaquetar_longitudes(agujero)
            if len(pts) >= 3:
                draw.polygon([(round(x + offset), round(y)) for x, y in pts], fill=0)


def localizar_capas(source_dir: Path):
    found = []
    for path in source_dir.rglob("ne_10m_bathymetry_*.shp"):
        m = PATRON.search(path.name)
        if m:
            found.append((int(m.group(2)), path))
    found.sort(key=lambda x: x[0])
    depths = [d for d, _ in found]
    missing = sorted(set(PALETA) - set(depths))
    if missing:
        raise RuntimeError(f"Capas de profundidad ausentes {missing}; encontradas: {depths}")
    return found


def crear(source_dir: Path, output: Path):
    t0 = time.time()
    capas = localizar_capas(source_dir)
    relieve = Image.new("RGBA", (ANCHO, ALTO), (0, 0, 0, 0))
    resumen = []
    for depth, path in capas:
        mascara = Image.new("L", (ANCHO, ALTO), 0)
        draw = ImageDraw.Draw(mascara)
        total = 0
        with shapefile.Reader(str(path)) as reader:
            for shp in reader.shapes():
                for rings in anillos_shape(shp):
                    dibujar_poligono(draw, rings)
                    total += 1
        color = PALETA.get(depth)
        capa_rgba = Image.new("RGBA", (ANCHO, ALTO), color + (242,))
        relieve = Image.composite(capa_rgba, relieve, mascara)
        resumen.append({"depth_m": depth, "features_poligonales": total})
        print(f"profundidad {depth:>5} m: {total} polígonos")

    # Dos escalas de desenfoque: conserva detalle de plataformas y suaviza las
    # transiciones amplias entre profundidades; no se dibujan rayas de costa.
    fino = relieve.filter(ImageFilter.GaussianBlur(radius=5.0 * ESCALA / 2.0))
    amplio = relieve.filter(ImageFilter.GaussianBlur(radius=15.0 * ESCALA / 2.0))
    relieve = Image.blend(fino, amplio, 0.22)

    # Halo de costa muy tenue, fundido hacia el mar como una viñeta.
    costa = Image.new("L", (ANCHO, ALTO), 0)
    draw_costa = ImageDraw.Draw(costa)
    layer0 = next(path for depth, path in capas if depth == 0)
    with shapefile.Reader(str(layer0)) as reader:
        for shp in reader.shapes():
            for rings in anillos_shape(shp):
                dibujar_poligono(draw_costa, rings)
    borde = costa.filter(ImageFilter.GaussianBlur(radius=13.0 * ESCALA / 2.0))
    halo = Image.new("RGBA", (ANCHO, ALTO), (82, 155, 174, 0))
    halo.putalpha(borde.point(lambda v: int(v * 0.12)))
    relieve = Image.alpha_composite(relieve, halo)

    output.parent.mkdir(parents=True, exist_ok=True)
    relieve.save(output, optimize=True)
    meta = {
        "archivo": output.name, "ancho_px": ANCHO, "alto_px": ALTO,
        "escala": ESCALA, "proyeccion": "cea_lambert_2_1",
        "origen": "Natural Earth 10m bathymetry 4.1.0 (SRTM Plus)",
        "capas": resumen,
    }
    output.with_suffix(".json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"textura guardada: {output} ({output.stat().st_size:,} bytes), {time.time()-t0:.1f}s")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--output", default="datos/profundidad_maritima.png", type=Path)
    args = parser.parse_args()
    crear(args.source_dir, args.output)


if __name__ == "__main__":
    main()
