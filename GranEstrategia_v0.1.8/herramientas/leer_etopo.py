#!/usr/bin/env python3
"""
Lector mínimo del GeoTIFF de ETOPO 2022 (NOAA) sin GDAL ni rasterio: solo numpy + tifffile + zlib.

Los .tif de ETOPO vienen en teselas de 256x256, comprimidos con DEFLATE y con «predictor de coma flotante» (predictor 3), que tifffile solo decodifica
con el paquete imagecodecs (no siempre se puede instalar). Aquí se decodifica a mano: por cada fila de la tesela, (1) se suman los bytes en cadena (módulo 256),
(2) los 4 planos de bytes (el más significativo primero) se vuelven a entrelazar en float32 de orden «big endian».

Uso como módulo:
    from leer_etopo import leer_etopo
    z = leer_etopo("ETOPO_2022_v1_60s_N90W180_surface.tif")      # matriz float32 (10800, 21600) de metros; arriba = 90°N, izquierda = 180°O
"""
import zlib
import numpy as np
import tifffile


def leer_etopo(ruta):
    """Devuelve la matriz de elevaciones en metros (float32, alto x ancho). Los huecos «sin dato» salen como NaN (ETOPO 2022 no tiene ninguno)."""
    with tifffile.TiffFile(ruta) as t:
        p = t.pages[0]
        alto, ancho = p.shape
        tw, th = p.tilewidth, p.tilelength
        assert p.dtype == np.float32 and p.compression.value in (8, 32946) and p.predictor.value == 3, "se esperaba float32 + DEFLATE + predictor 3"
        nodata = float(p.tags["GDAL_NODATA"].value) if "GDAL_NODATA" in p.tags else None
        ntx = (ancho + tw - 1) // tw
        nty = (alto + th - 1) // th
        sal = np.empty((alto, ancho), dtype=np.float32)
        offs = p.dataoffsets
        cuentas = p.databytecounts
        fh = t.filehandle
        for ty in range(nty):
            for tx in range(ntx):
                k = ty * ntx + tx
                fh.seek(offs[k])
                crudo = np.frombuffer(zlib.decompress(fh.read(cuentas[k])), dtype=np.uint8)
                filas = np.cumsum(crudo.reshape(th, tw * 4), axis=1, dtype=np.uint8)    # (1) deshacer la diferencia entre bytes vecinos
                bytes_ = filas.reshape(th, 4, tw).transpose(0, 2, 1)                     # (2) (fila, columna, byte), el byte más significativo primero
                val = np.ascontiguousarray(bytes_).view(">f4").reshape(th, tw).astype(np.float32)
                y0, x0 = ty * th, tx * tw
                y1, x1 = min(y0 + th, alto), min(x0 + tw, ancho)
                bloque = val[: y1 - y0, : x1 - x0]
                if nodata is not None:
                    bloque = np.where(bloque == nodata, np.nan, bloque)
                sal[y0:y1, x0:x1] = bloque
    return sal


if __name__ == "__main__":
    import sys
    z = leer_etopo(sys.argv[1])
    print(z.shape, z.dtype, float(np.nanmin(z)), float(np.nanmax(z)))
