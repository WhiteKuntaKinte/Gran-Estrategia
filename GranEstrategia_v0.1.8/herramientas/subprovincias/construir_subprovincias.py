#!/usr/bin/env python3
"""Subprovincias reales: geoBoundaries CGAZ ADM2 -> datos/subprov/ (0.1.8.43).

Fuente: geoBoundaries (William & Mary geoLab), CC BY 4.0 (compuesto CGAZ, ADM2). El archivo lo trae el workflow `traer-geoboundaries.yml`
(Release `datos-geoboundaries`): geoBoundariesCGAZ_ADM2.geojson.gz. No hace falta shapely: solo numpy y OpenCV (cv2.approxPolyDP).

Qué escribe (todo en `datos/subprov/`):
  · <ISO>.bin     zlib de un arreglo int32 (little endian) con un prefijo de 4 bytes = tamaño sin comprimir.
                  [n_unidades, desplazamiento_0 … desplazamiento_n-1 (en palabras, desde el inicio), y por unidad:
                   xmin, ymin, xmax, ymax, n_anillos, y por anillo: n_puntos, es_hueco, x0, y0, dx1, dy1, …]
                  Coordenadas = px del mapa × ESC (2400 × 1200 px, proyección equirrectangular), anillos con deltas entre puntos.
  · indice.bin    zlib de un arreglo int32 con prefijo de tamaño: 360 × 180 casillas de 1° → [desplazamientos (64.801)] + entradas (iso << 20 | unidad).
  · nombres.json  {"isos": [...], "nombres": {ISO: [nombre, …]}, "fuente": "...", "licencia": "..."}.
Uso: python3 construir_subprovincias.py [geoBoundariesCGAZ_ADM2.geojson.gz] [carpeta_salida] [--limite N]
"""
import gzip, json, os, struct, sys, zlib, time
import numpy as np
import cv2

W, H = 2400.0, 1200.0
ESC = 1024                  # unidades por px del mapa (1 unidad ≈ 16 m en el ecuador)
EPS = 0.010                 # tolerancia de simplificación en px del mapa (≈ 0,0015° ≈ 165 m)
AREA_MIN = 0.003            # px² (≈ 0,8 km²): anillos menores se descartan (polvo)
FUENTE = "geoBoundaries (William & Mary geoLab), CC BY 4.0"


def proyectar(coords):
    a = np.asarray(coords, dtype=np.float64)
    return np.stack([(a[:, 0] + 180.0) * W / 360.0, (90.0 - a[:, 1]) * H / 180.0], axis=1)


def area_firmada(p):
    x, y = p[:, 0], p[:, 1]
    return 0.5 * float(np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y))


def simplificar(p):
    if len(p) > 1 and np.allclose(p[0], p[-1]):
        p = p[:-1]
    if len(p) < 3:
        return None
    s = cv2.approxPolyDP(p.astype(np.float32).reshape(-1, 1, 2), EPS, True).reshape(-1, 2).astype(np.float64)
    if len(s) < 3 or abs(area_firmada(s)) < AREA_MIN:
        return None
    return s


def anillos_de(geom):
    """[(puntos, es_hueco)] de un Polygon o MultiPolygon."""
    salida = []
    if geom is None:
        return salida
    polis = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]] if geom["type"] == "Polygon" else []
    for poli in polis:
        for k, anillo in enumerate(poli):
            s = simplificar(proyectar(anillo))
            if s is not None:
                salida.append((s, k > 0))
    return salida


def palabras_unidad(anillos):
    q = [np.rint(a * ESC).astype(np.int64) for a, _ in anillos]
    xs = np.concatenate([a[:, 0] for a in q])
    ys = np.concatenate([a[:, 1] for a in q])
    w = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()), len(q)]
    for (a, hueco), p in zip(anillos, q):
        w += [len(p), 1 if hueco else 0, int(p[0, 0]), int(p[0, 1])]
        d = np.diff(p, axis=0)
        w += d.reshape(-1).tolist()
    return w, (w[0], w[1], w[2], w[3])


def empaquetar(palabras):
    crudo = np.asarray(palabras, dtype="<i4").tobytes()
    return struct.pack("<I", len(crudo)) + zlib.compress(crudo, 9)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    limite = 0
    for a in sys.argv[1:]:
        if a.startswith("--limite="):
            limite = int(a.split("=")[1])
    entrada = args[0] if args else "/tmp/gb/geoBoundariesCGAZ_ADM2.geojson.gz"
    carpeta = args[1] if len(args) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "datos", "subprov")
    os.makedirs(carpeta, exist_ok=True)
    por_iso = {}
    t0 = time.time()
    n = 0
    with gzip.open(entrada, "rt", encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip().rstrip(",")
            if not linea.startswith('{ "type": "Feature"'):
                continue
            ft = json.loads(linea)
            pr = ft["properties"]
            an = anillos_de(ft["geometry"])
            if not an:
                continue
            iso = str(pr.get("shapeGroup", "XXX")) or "XXX"
            w, bb = palabras_unidad(an)
            por_iso.setdefault(iso, []).append((str(pr.get("shapeName", "")).strip() or "Sin nombre", w, bb))
            n += 1
            if n % 5000 == 0:
                print("  %d unidades · %.0f s" % (n, time.time() - t0), flush=True)
            if limite and n >= limite:
                break
    isos = sorted(por_iso)
    nombres = {}
    cuadricula = {}
    total_bytes = 0
    for ii, iso in enumerate(isos):
        unidades = por_iso[iso]
        cab = 1 + len(unidades)
        offs = []
        cuerpo = []
        pos = cab
        for k, (nom, w, bb) in enumerate(unidades):
            offs.append(pos)
            cuerpo += w
            pos += len(w)
            gx0 = max(0, min(359, int(bb[0] / ESC * 360.0 / W)))
            gx1 = max(0, min(359, int(bb[2] / ESC * 360.0 / W)))
            gy0 = max(0, min(179, int(bb[1] / ESC * 180.0 / H)))
            gy1 = max(0, min(179, int(bb[3] / ESC * 180.0 / H)))
            for gy in range(gy0, gy1 + 1):
                for gx in range(gx0, gx1 + 1):
                    cuadricula.setdefault(gy * 360 + gx, []).append((ii << 20) | k)
        datos = empaquetar([len(unidades)] + offs + cuerpo)
        with open(os.path.join(carpeta, iso + ".bin"), "wb") as g:
            g.write(datos)
        total_bytes += len(datos)
        nombres[iso] = [u[0] for u in unidades]
    desp = [0]
    ent = []
    for c in range(360 * 180):
        ent += cuadricula.get(c, [])
        desp.append(len(ent))
    with open(os.path.join(carpeta, "indice.bin"), "wb") as g:
        g.write(empaquetar(desp + ent))
    with open(os.path.join(carpeta, "nombres.json"), "w", encoding="utf-8") as g:
        json.dump({"isos": isos, "nombres": nombres, "fuente": FUENTE, "licencia": "CC BY 4.0 https://creativecommons.org/licenses/by/4.0/",
                   "unidades": n}, g, ensure_ascii=False, separators=(",", ":"))
    print("%d unidades en %d países · %.1f MB de .bin · %.0f s" % (n, len(isos), total_bytes / 1e6, time.time() - t0))


if __name__ == "__main__":
    main()
