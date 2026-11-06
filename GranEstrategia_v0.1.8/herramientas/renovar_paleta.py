#!/usr/bin/env python3
"""
0.1.8.37 · Paleta renovada del mapa (colores por continente).

Cambia los 7 colores base de los continentes (los de «modo dev» y los de la vista del mundo) por tonos más sobrios y armónicos: menos neón, mismo
matiz reconocible por continente. Reescribe, SIN regenerar el mapa, los datos que ya los llevan horneados:
    datos/malla_filt_cp.bin   color de país por vértice (3 bytes)
    datos/malla_filt_cc.bin   color de continente por vértice (3 bytes)
    datos/entidades.json      campo "col" de cada país
Es idempotente: si los datos ya tienen la paleta nueva, no cambia nada. Los mismos valores están en construir_mapa.py (COLOR_CONT / BASE_PAIS),
así que un mapa regenerado sale ya con la paleta nueva.

Uso (desde la carpeta del proyecto):  python herramientas/renovar_paleta.py
"""
import json, os, re, sys
import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, 'datos')

# continente: (color de país anterior, color de país nuevo, color continental anterior, color continental nuevo)  —  hexadecimal sin «#»
PALETA = {
    'Europa':            ('2a5ed1', '4f83d1', '1d4ed8', '4f83d1'),
    'Asia':              ('d12a2f', 'd15147', 'dc2626', 'd15147'),
    'África':            ('d1a51f', 'd1a63f', 'eab308', 'd1a63f'),
    'América del Sur':   ('d16619', 'd1763f', 'ea580c', 'd1763f'),
    'América del Norte': ('34d14d', '58d174', '15803d', '58d174'),
    'Oceanía':           ('8d49d1', '9764d1', '7c3aed', '9764d1'),
    'Antártida':         ('b4c3d1', 'b8c5d1', '94a3b8', 'b8c5d1'),
}


def rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype='u1')


def remapear_bin(nombre, col_ant, col_nue):
    ruta = os.path.join(DATOS, nombre)
    if not os.path.exists(ruta):
        return 0
    a = np.fromfile(ruta, dtype='u1').reshape(-1, 3)
    tocados = 0
    for ant, nue in zip(col_ant, col_nue):
        if ant == nue:
            continue
        m = np.all(a == rgb(ant), axis=1)
        tocados += int(m.sum())
        a[m] = rgb(nue)
    a.tofile(ruta)
    return tocados


def remapear_entidades(ruta):
    if not os.path.exists(ruta):
        return 0
    txt = open(ruta, encoding='utf-8').read()
    tabla = {ant: nue for (ant, nue, _, _) in PALETA.values()}
    n = [0]

    def cambia(m):
        h = m.group(1)
        if h in tabla and tabla[h] != h:
            n[0] += 1
            return '"col":"%s"' % tabla[h]
        return m.group(0)
    nuevo = re.sub(r'"col":"([0-9a-f]{6})"', cambia, txt)
    if nuevo != txt:
        open(ruta, 'w', encoding='utf-8').write(nuevo)
    return n[0]


def main():
    cp_a = [v[0] for v in PALETA.values()]
    cp_n = [v[1] for v in PALETA.values()]
    cc_a = [v[2] for v in PALETA.values()]
    cc_n = [v[3] for v in PALETA.values()]
    print('malla_filt_cp.bin: %d vértices cambiados' % remapear_bin('malla_filt_cp.bin', cp_a, cp_n))
    print('malla_filt_cc.bin: %d vértices cambiados' % remapear_bin('malla_filt_cc.bin', cc_a, cc_n))
    print('entidades.json: %d países cambiados' % remapear_entidades(os.path.join(DATOS, 'entidades.json')))


if __name__ == '__main__':
    sys.exit(main())
