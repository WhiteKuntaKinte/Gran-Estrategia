#!/usr/bin/env python3
"""
Genera banderas/*.png (96 px de ancho) y datos/banderas.json a partir de un repositorio de banderas SVG
(oxguy3/flags, dominio público casi todas; ver SPECIAL_LICENSES.csv) y de los datos del propio juego.

Uso:  python3 -I herramientas/preparar_banderas.py RUTA_SVG[:RUTA_SVG2...] RUTA_NE
  RUTA_SVG = carpeta 'svg' del repositorio de banderas (varias separadas por ':'; gana la primera que tenga el archivo)
  RUTA_NE = carpeta con los geojson de Natural Earth
  Si una provincia no tiene bandera propia hereda la de su región (campo region_cod de Natural Earth, p. ej. las
  provincias italianas heredan la bandera de su región).
Requiere: rsvg-convert, pillow
Si una provincia/estado no tiene bandera, el juego usa banderas/x.png (fondo negro con una X blanca).
"""
import json, os, subprocess, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tablas_estados import ESTADOS_US

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, 'datos')
SAL = os.path.join(RAIZ, 'banderas')
ANCHO = 96
# Unidades de Natural Earth sin código ISO: se les asigna la bandera de su soberano / organismo
OVERRIDE_A3 = {'ESB': 'gb', 'WSB': 'gb', 'USG': 'us', 'CNM': 'un'}


def rasterizar(svg, destino):
    if os.path.exists(destino):
        return True
    r = subprocess.run(['rsvg-convert', '-w', str(ANCHO), '-a', svg, '-o', destino], capture_output=True)
    if r.returncode != 0 or not os.path.exists(destino):
        return False
    im = Image.open(destino).convert('RGBA')
    if im.height > 72:                               # banderas casi cuadradas (Nepal, Suiza...) se limitan en alto
        im = im.resize((int(im.width * 72 / im.height), 72), Image.LANCZOS)
    im.save(destino, optimize=True)
    return True


def bandera_x():
    im = Image.new('RGB', (ANCHO, 64), (0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line([(14, 8), (ANCHO - 14, 56)], fill=(255, 255, 255), width=7)
    d.line([(14, 56), (ANCHO - 14, 8)], fill=(255, 255, 255), width=7)
    im.save(os.path.join(SAL, 'x.png'), optimize=True)


def buscar(svg_dirs, *partes):
    for d in svg_dirs:
        f = os.path.join(d, *partes)
        if os.path.exists(f):
            return f
    return None


def main():
    svg_dirs, ne_dir = sys.argv[1].split(':'), sys.argv[2]
    os.makedirs(SAL, exist_ok=True)
    bandera_x()
    fuente = json.load(open(os.path.join(DATOS, 'fuente_provincias.json'), encoding='utf-8'))
    ne0 = json.load(open(os.path.join(ne_dir, 'ne_10m_admin_0_countries.geojson'), encoding='utf-8'))['features']
    iso2 = {f['properties']['ADM0_A3']: f['properties']['ISO_A2_EH'] for f in ne0}
    ne1 = json.load(open(os.path.join(ne_dir, 'ne_10m_admin_1_states_provinces.geojson'), encoding='utf-8'))['features']
    iso_adm1 = {f['properties']['adm1_code']: (f['properties']['iso_3166_2'] or '') for f in ne1}
    region_adm1 = {f['properties']['adm1_code']: (f['properties'].get('region_cod') or '').replace('.', '-') for f in ne1}

    out = {'paises': {}, 'provincias': {}, 'estados': {}}
    sin_pais = []
    for p in fuente:
        pais = p['country_es']
        if pais in out['paises']:
            continue
        a3 = p['a3']
        c = OVERRIDE_A3.get(a3) or (iso2.get(a3) or '').lower()
        f_pais = buscar(svg_dirs, c + '.svg') if c not in ('', '-99') else None
        if f_pais is None:
            sin_pais.append(pais)
            continue
        if rasterizar(f_pais, os.path.join(SAL, 'p_%s.png' % c)):
            out['paises'][pais] = 'p_%s' % c
        else:
            sin_pais.append(pais)

    n_prov = 0
    n_heredada = 0
    for p in fuente:
        if p['a3'] == 'USA':
            continue
        clave = p['id'].upper().replace('_', '-')
        code = iso_adm1.get(clave, '')
        intentos = [(code, False), (region_adm1.get(clave, ''), True)]
        for cod, heredada in intentos:
            if '-' not in cod:
                continue
            a, b = cod.lower().split('-', 1)
            if heredada and a != (iso2.get(p['a3']) or '').lower():
                continue                                     # solo regiones del propio país
            f = buscar(svg_dirs, a, b + '.svg')
            if f and rasterizar(f, os.path.join(SAL, 's_%s_%s.png' % (a, b))):
                out['provincias'][p['id']] = 's_%s_%s' % (a, b)
                n_prov += 1
                n_heredada += 1 if heredada else 0
                break
    n_est = 0
    for fips, (post, es, en) in ESTADOS_US.items():
        f = buscar(svg_dirs, 'us', post + '.svg')
        if f and rasterizar(f, os.path.join(SAL, 's_us_%s.png' % post)):
            out['estados'][es] = 's_us_%s' % post
            n_est += 1
    json.dump(out, open(os.path.join(DATOS, 'banderas.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('países con bandera', len(out['paises']), 'sin bandera:', sin_pais)
    print('provincias con bandera (propia o de su región)', n_prov, '| heredadas', n_heredada, '| estados EE. UU.', n_est, '/', len(ESTADOS_US))


if __name__ == '__main__':
    main()
