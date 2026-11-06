#!/usr/bin/env python3
"""
Genera datos/profundidad.bin (textura RG8 de 4096x2048, mapa equirectangular completo):
  R = nivel de profundidad continuo (0..11 -> 0..255). 0 = costa, 1 = 200 m, 2 = 1000 m ... 11 = 10000 m
  G = distancia a la costa del juego (unidades de mapa, 0..64 -> 0..255)
Usa la batimetría real de Natural Earth (bandas A_10000 ... L_0) y las costas del propio juego
(datos/malla_fill_*.bin), de modo que el mar queda perfectamente alineado con la tierra.

Uso:  python herramientas/construir_profundidad.py RUTA_NE
Requiere: numpy, scipy, opencv-python (cv2)
"""
import json, os, sys
import numpy as np
import cv2
from scipy import ndimage

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, 'datos')
W, H = 4096, 2048
BANDAS = ['L_0', 'K_200', 'J_1000', 'I_2000', 'H_3000', 'G_4000', 'F_5000', 'E_6000', 'D_7000', 'C_8000', 'B_9000', 'A_10000']
PAD = 256
SH = 4


def poligonos(geom):
    return [geom['coordinates']] if geom['type'] == 'Polygon' else geom['coordinates']


def a_px(ring, ox=0):
    a = np.array(ring, dtype=float)
    x = (a[:, 0] + 180.0) / 360.0 * W + ox
    y = (90.0 - a[:, 1]) / 180.0 * H
    return np.round(np.stack([x, y], 1) * (1 << SH)).astype(np.int32)


def main():
    ne = sys.argv[1]
    # 1) clases de batimetría (-1 = sin dato)
    cls = np.full((H, W), -1, np.int8)
    for k, b in enumerate(BANDAS):
        f = os.path.join(ne, 'ne_10m_bathymetry_%s.geojson' % b)
        feats = json.load(open(f, encoding='utf-8'))['features']
        m = np.zeros((H, W), np.uint8)
        for ft in feats:
            for poly in poligonos(ft['geometry']):
                cv2.fillPoly(m, [a_px(poly[0])], 1, lineType=cv2.LINE_8, shift=SH)
                for hueco in poly[1:]:
                    cv2.fillPoly(m, [a_px(hueco)], 0, lineType=cv2.LINE_8, shift=SH)
        cls[m == 1] = k
        print('banda', b, int((m == 1).sum()))

    # 2) tierra del propio juego
    V = np.fromfile(os.path.join(DATOS, 'malla_fill_v.bin'), '<f4').reshape(-1, 2)
    I = np.fromfile(os.path.join(DATOS, 'malla_fill_i.bin'), '<i4').reshape(-1, 3)
    tierra = np.zeros((H, W), np.uint8)
    P = np.round(V * np.array([W / 2400.0, H / 1200.0]) * (1 << SH)).astype(np.int32)
    for t in I:
        cv2.fillConvexPoly(tierra, P[t], 1, lineType=cv2.LINE_8, shift=SH)
    tierra = tierra.astype(bool)

    # 3) relleno: todo el agua sin dato toma la clase más cercana; la tierra no cuenta
    valido = (cls >= 0) & ~tierra
    ext = lambda a: np.concatenate([a[:, -PAD:], a, a[:, :PAD]], 1)       # envoltura horizontal
    cls_e, val_e, tie_e = ext(cls), ext(valido), ext(tierra)
    idx = ndimage.distance_transform_edt(~val_e, return_distances=False, return_indices=True)
    cls_e = cls_e[idx[0], idx[1]].astype(np.int16)
    # 4) profundidad continua: interpolación entre curvas de nivel
    prof = cls_e.astype(np.float32)
    n = len(BANDAS)
    for k in range(n):
        en = cls_e == k
        if not en.any():
            continue
        # distancia al borde "más somero" y al borde "más profundo"
        d_somero = ndimage.distance_transform_edt(cls_e >= k)    # dentro de >=k : distancia a clases menores
        d_hondo = ndimage.distance_transform_edt(cls_e <= k)     # dentro de <=k : distancia a clases mayores
        frac = d_somero / np.maximum(d_somero + d_hondo, 1e-6)
        if k == n - 1:
            frac = np.full_like(frac, 0.5)
        prof[en] = k + frac[en]
    prof = np.clip(prof, 0, n - 1)
    # 5) distancia a la costa
    dist = ndimage.distance_transform_edt(~tie_e) * (2400.0 / W)
    R = np.round(prof / (n - 1) * 255).astype(np.uint8)[:, PAD:-PAD]
    G = np.round(np.clip(dist / 64.0, 0, 1) * 255).astype(np.uint8)[:, PAD:-PAD]
    R[tierra] = 0
    G[tierra] = 0
    out = np.stack([R, G], 2)
    out.tofile(os.path.join(DATOS, 'profundidad.bin'))
    json.dump({'w': W, 'h': H, 'niveles': n - 1, 'dist_max': 64.0}, open(os.path.join(DATOS, 'profundidad_meta.json'), 'w'))
    cv2.imwrite('/tmp/prof_R.png', R)
    print('profundidad.bin', out.shape)


if __name__ == '__main__':
    main()
