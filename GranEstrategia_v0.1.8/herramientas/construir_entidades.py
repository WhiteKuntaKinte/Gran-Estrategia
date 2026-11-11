#!/usr/bin/env python3
"""
0.1.7.9 — Construye las ENTIDADES del juego a partir de los datos ya generados:
  datos/ciudades.json   ciudades (Natural Earth) con país, provincia y zoom mínimo de aparición
  datos/entidades.json  datos de identidad de cada país (continente, capital, tipo de división, bandera) y de cada estado
  datos/economia.json   perfiles económicos (país / región)
  datos/info.json       se le añade la sección 'estado' (agregados por estado de EE. UU.)
Uso:  python3 -I herramientas/construir_entidades.py RUTA_NE [RUTA_SVG_BANDERAS]
Requiere: numpy, scipy, cv2 (opencv), pillow
"""
import json, os, sys, re, unicodedata, collections, subprocess
import numpy as np
import cv2
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tablas_estados import ESTADOS_US, CIUDADES_US_CON_LICENCIA
import tablas_economia as TE

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, 'datos')
ESC = 2          # píxeles por unidad de mapa en el ráster de provincias
TIPOS_DIV = {'State': 'Estados', 'Province': 'Provincias', 'Department': 'Departamentos', 'Region': 'Regiones',
             'Municipality': 'Municipios', 'County': 'Condados', 'District': 'Distritos', 'Governorate': 'Gobernaciones',
             'Prefecture': 'Prefecturas', 'Autonomous region': 'Regiones autónomas', 'Autonomous community': 'Comunidades autónomas',
             'Canton': 'Cantones', 'Parish': 'Parroquias', 'Oblast': 'Óblasts', 'Voivodeship': 'Voivodatos',
             'Autonomous republic': 'Repúblicas autónomas', 'Republic': 'Repúblicas', 'Emirate': 'Emiratos',
             'Governorate (muhafazah)': 'Gobernaciones', 'Division': 'Divisiones', 'Territory': 'Territorios',
             'Island': 'Islas', 'Atoll': 'Atolones', 'City': 'Ciudades', 'Commune': 'Comunas', 'Metropolitan region': 'Regiones'}


def sin_acentos(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')


def zoom_ciudad(pop, cap_nac, cap_prov):
    if cap_nac or pop >= 5e6:
        return 2.4
    if pop >= 1e6:
        return 3.8
    if pop >= 3e5 or (cap_prov and pop >= 1e5):
        return 6.0
    if pop >= 1e5:
        return 9.0
    if pop >= 2e4:
        return 14.0
    return 22.0


def arquetipo(nombre, cont, pob, area):
    """Perfil estimado por región para países sin ficha propia."""
    if cont == 'Antártida' or pob < 100:
        return ['—', '—', ['Pesca', 'Investigación científica'], [['Investigación científica', 70], ['Pesca', 20], ['Servicios', 10]]]
    if cont == 'Europa' and pob < 3e5:
        return ['—', '—', ['—'], [['Servicios', 55], ['Finanzas', 20], ['Turismo', 15], ['Manufactura', 10]]]
    if cont in ('América del Norte', 'América del Sur') and (pob < 6e5 or area < 5000):
        return ['Caña de azúcar', 'Banano', 'Coco'], 'Pollo', ['Pesca', 'Turismo'], [['Turismo', 40], ['Servicios', 30], ['Finanzas', 12], ['Agricultura', 6], ['Pesca', 5], ['Otros', 7]]
    if cont == 'Oceanía' and pob < 1.5e6:
        return ['Coco', 'Taro', 'Yuca'], 'Cerdo', ['Pesca', 'Copra'], [['Servicios', 40], ['Pesca', 15], ['Agricultura', 15], ['Turismo', 15], ['Otros', 15]]
    if pob < 6e5:
        return ['Coco', 'Hortalizas'], 'Pollo', ['Pesca'], [['Turismo', 30], ['Servicios', 40], ['Pesca', 15], ['Agricultura', 5], ['Otros', 10]]
    tabla = {
        'Asia': (['Arroz', 'Trigo', 'Hortalizas'], 'Pollo', ['Minerales diversos'], [['Servicios', 45], ['Agricultura', 20], ['Manufactura', 15], ['Comercio', 10], ['Construcción', 10]]),
        'África': (['Mijo', 'Sorgo', 'Maíz'], 'Cabra>Res', ['Minerales diversos'], [['Servicios', 40], ['Agricultura', 30], ['Minería', 10], ['Comercio', 12], ['Otros', 8]]),
        'Europa': (['Trigo', 'Cebada', 'Papa'], 'Cerdo', ['Madera', 'Sal'], [['Servicios', 62], ['Manufactura', 20], ['Construcción', 6], ['Agricultura', 4], ['Otros', 8]]),
        'América del Norte': (['Maíz', 'Frijol', 'Caña de azúcar'], 'Res', ['Minerales diversos'], [['Servicios', 55], ['Agricultura', 14], ['Manufactura', 14], ['Construcción', 7], ['Otros', 10]]),
        'América del Sur': (['Maíz', 'Yuca', 'Caña de azúcar'], 'Res', ['Minerales diversos'], [['Servicios', 55], ['Agricultura', 14], ['Manufactura', 14], ['Construcción', 7], ['Otros', 10]]),
        'Oceanía': (['Trigo', 'Caña de azúcar'], 'Res', ['Minerales diversos'], [['Servicios', 60], ['Agricultura', 15], ['Minería', 10], ['Manufactura', 10], ['Otros', 5]]),
    }
    return tabla.get(cont, tabla['Asia'])


def parse_linea(l):
    partes = [p.strip() for p in l.split('|')]
    cult = [] if partes[1] in ('—', '') else [x.strip() for x in partes[1].split(',')]
    carne = partes[2]
    prod, _, exp = carne.partition('>')
    if carne == '—':
        prod, exp = '—', '—'
    elif not exp:
        exp = prod
    mat = [] if partes[3] in ('—', '') else [x.strip() for x in partes[3].split(',')]
    rub = []
    for t in partes[4].split(','):
        m = re.match(r'^(.*?)\s+(\d+(?:\.\d+)?)$', t.strip())
        if m:
            rub.append([m.group(1), float(m.group(2))])
    tot = sum(r[1] for r in rub) or 1.0
    rub = [[n, round(100.0 * v / tot, 1)] for n, v in rub]
    return cult, [prod, exp], mat, rub


def main():
    ne = sys.argv[1]
    svg_dir = sys.argv[2] if len(sys.argv) > 2 else None
    prov_js = json.load(open(os.path.join(DATOS, 'provincias_juego.json'), encoding='utf-8'))
    provincias, anillos = prov_js['provincias'], prov_js['anillos']
    fuente = json.load(open(os.path.join(DATOS, 'fuente_provincias.json'), encoding='utf-8'))
    info = json.load(open(os.path.join(DATOS, 'info.json'), encoding='utf-8'))
    banderas = json.load(open(os.path.join(DATOS, 'banderas.json'), encoding='utf-8'))
    NP = len(provincias)
    a3_de = {}
    pais_de_a3 = {}
    for q in fuente:
        a3_de.setdefault(q['country_es'], q['a3'])
        pais_de_a3.setdefault(q['a3'], q['country_es'])

    # ── ráster de provincias (para ubicar ciudades) ──
    V = np.fromfile(os.path.join(DATOS, 'malla_fill_v.bin'), '<f4').reshape(-1, 2)
    I = np.fromfile(os.path.join(DATOS, 'malla_fill_i.bin'), '<i4').reshape(-1, 3)
    W, H = int(2400 * ESC), int(1200 * ESC)
    img = np.zeros((H, W), np.uint16)
    SH = 4
    P = np.round(V * ESC * (1 << SH)).astype(np.int32)
    for a in anillos:
        tri = I[a['i0'] // 3:a['i1'] // 3]
        if len(tri):
            cv2.fillPoly(img, list(P[tri]), int(a['p']) + 1, shift=SH)
    d, (iy, ix) = ndimage.distance_transform_edt(img == 0, return_indices=True)
    print('ráster de provincias listo')

    # ── ciudades ──
    gj = json.load(open(os.path.join(ne, 'ne_10m_populated_places.geojson'), encoding='utf-8'))['features']
    pais_idx, paises_lista = {}, []
    filas = []
    capital_de = {}
    for f in gj:
        p = f['properties']
        lon, lat = f['geometry']['coordinates']
        x = (lon + 180.0) / 360.0 * 2400.0
        y = (90.0 - lat) / 180.0 * 1200.0
        px, py = min(W - 1, int(x * ESC)), min(H - 1, int(y * ESC))
        k = int(img[py, px])
        if k == 0 and d[py, px] <= 14:
            k = int(img[iy[py, px], ix[py, px]])
        prov = k - 1
        pais = pais_de_a3.get(p['ADM0_A3'])
        if prov >= 0:
            pais_prov = provincias[prov]['c']
            if pais is None or a3_de.get(pais_prov) != p['ADM0_A3']:
                pais = pais_prov if pais is None else pais
        if pais is None:
            continue
        pop = int(p['POP_MAX'] or 0)
        cap_nac = 1 if p['ADM0CAP'] == 1 else 0
        cap_prov = 1 if 'Admin-1' in (p['FEATURECLA'] or '') else 0
        nombre = (p.get('NAME_ES') or p['NAME'] or '?').strip()
        if pais not in pais_idx:
            pais_idx[pais] = len(paises_lista)
            paises_lista.append(pais)
        zp = zoom_ciudad(pop, cap_nac, cap_prov)
        fila = [nombre, round(x, 2), round(y, 2), pop, 2 if cap_nac else (1 if cap_prov else 0), pais_idx[pais], prov, zp, p['NAME']]
        filas.append(fila)
        if cap_nac and (pais not in capital_de or pop > capital_de[pais][1]):
            capital_de[pais] = (nombre, pop)
    filas.sort(key=lambda r: -r[3])
    # banderas de ciudades de EE. UU. (si hay repositorio de banderas)
    ciu_banderas = {}
    if svg_dir:
        for r in filas:
            if r[5] < len(paises_lista) and paises_lista[r[5]] == 'Estados Unidos' and r[6] >= 0 and provincias[r[6]].get('e'):
                post = None
                for fips, (pp, es, en) in ESTADOS_US.items():
                    if es == provincias[r[6]]['e']:
                        post = pp
                if not post:
                    continue
                for cand in (r[8], r[0]):
                    slug = re.sub(r'[^a-z_]', '', sin_acentos(cand).lower().replace('saint ', 'st ').replace(' ', '_'))
                    if 'c_us_%s_%s' % (post, slug) in CIUDADES_US_CON_LICENCIA:
                        if os.path.exists(os.path.join(svg_dir, 'us', post, slug + '.svg')):          # bandera con licencia CC: no se usa, la ciudad lleva la de su estado
                            bandera_estado = banderas.get('estados', {}).get(provincias[r[6]]['e'])
                            if bandera_estado:
                                ciu_banderas['%s|%s' % (r[0], provincias[r[6]]['e'])] = bandera_estado
                            break
                        continue
                    f = os.path.join(svg_dir, 'us', post, slug + '.svg')
                    if os.path.exists(f):
                        destino = os.path.join(RAIZ, 'banderas', 'c_us_%s_%s.png' % (post, slug))
                        if not os.path.exists(destino):
                            subprocess.run(['rsvg-convert', '-w', '96', '-a', f, '-o', destino], capture_output=True)
                        if os.path.exists(destino):
                            ciu_banderas['%s|%s' % (r[0], provincias[r[6]]['e'])] = 'c_us_%s_%s' % (post, slug)
                        break
    banderas['ciudades'] = ciu_banderas
    json.dump(banderas, open(os.path.join(DATOS, 'banderas.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    json.dump({'paises': paises_lista, 'c': [r[:8] for r in filas]}, open(os.path.join(DATOS, 'ciudades.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))
    print('ciudades', len(filas), 'con bandera propia', len(ciu_banderas))

    # ── tipo de división de cada país (Natural Earth admin-1) ──
    tipos = collections.defaultdict(collections.Counter)
    for f in json.load(open(os.path.join(ne, 'ne_10m_admin_1_states_provinces.geojson'), encoding='utf-8'))['features']:
        p = f['properties']
        if p.get('type_en'):
            tipos[p['adm0_a3']][p['type_en']] += 1

    # ── estados (agregados) ──
    estados = json.load(open(os.path.join(DATOS, 'estados.json'), encoding='utf-8'))
    est_info = {}
    for pais, lista in estados.items():
        for e in lista:
            pob = area = alt_s = 0.0
            altmax = 0.0
            tabla = collections.Counter()
            reinos = collections.Counter()
            for pi in e['pi']:
                row = info['prov'][pi]
                pob += row[0]
                area += row[1]
                alt_s += row[2] * row[1]
                altmax = max(altmax, row[3])
                for cod, pc in row[4]:
                    tabla[cod] += pc * row[1]
                reinos[row[5]] += row[1]
            tot = sum(tabla.values()) or 1.0
            bio = [[c, int(round(100.0 * v / tot))] for c, v in tabla.most_common(3) if v / tot >= 0.12]
            est_info['%s|%s' % (pais, e['n'])] = {'pob': int(pob), 'area': int(area), 'alt': int(alt_s / max(area, 1)),
                                                   'altmax': int(altmax), 'bio': bio, 'reino': reinos.most_common(1)[0][0],
                                                   'n_prov': len(e['pi'])}
    info['estado'] = est_info
    json.dump(info, open(os.path.join(DATOS, 'info.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))

    # ── entidades país ──
    ent_p = {}
    for pais, d_ in info['pais'].items():
        a3 = a3_de.get(pais, '')
        t = tipos.get(a3)
        div = TIPOS_DIV.get(t.most_common(1)[0][0], 'Provincias') if t else 'Provincias'
        ent_p[pais] = {'a3': a3, 'cont': d_['cont'], 'cap': capital_de.get(pais, [''])[0], 'div': div,
                       'bandera': banderas['paises'].get(pais, '')}
    ent_p['Estados Unidos']['div'] = 'Estados'
    ent_p['Estados Unidos']['div_prov'] = 'Condados'
    json.dump({'paises': ent_p, 'version': '0.1.7.9'}, open(os.path.join(DATOS, 'entidades.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))

    # ── economía ──
    eco_p, eco_r = {}, {}
    por_a3 = {}
    for l in TE.PAISES.strip().split('\n'):
        a3 = l.split('|')[0].strip()
        por_a3[a3] = parse_linea(l)
    for pais, d_ in info['pais'].items():
        a3 = a3_de.get(pais, '')
        if a3 in por_a3:
            cult, carne, mat, rub = por_a3[a3]
            eco_p[pais] = {'cult': cult, 'carne': carne, 'mat': mat, 'rub': rub, 'nivel': 'p'}
        else:
            arq = arquetipo(pais, d_['cont'], d_['pob'], d_['area'])
            cult, carne, mat, rub = arq[0], arq[1], arq[2], arq[3]
            if isinstance(carne, str):
                pr, _, ex = carne.partition('>')
                carne = [pr, ex or pr]
            tot = sum(r[1] for r in rub)
            eco_p[pais] = {'cult': cult if cult != ['—'] else [], 'carne': carne if isinstance(carne, list) else [carne, carne],
                           'mat': [m for m in mat if m != '—'], 'rub': [[n, round(100.0 * v / tot, 1)] for n, v in rub], 'nivel': 'r'}
    NOMBRE_PAIS = {'USA': 'Estados Unidos', 'COL': 'Colombia', 'MEX': 'México'}
    nombres_validos = collections.defaultdict(set)
    for p in provincias:
        nombres_validos[p['c']].add(p['n'])
        if p.get('e'):
            nombres_validos[p['c']].add(p['e'])
    mal = []
    for l in TE.REGIONES.strip().split('\n'):
        clave, resto = l.split('|', 1)
        a3, reg = clave.split(':', 1)
        pais = NOMBRE_PAIS[a3]
        cult, carne, mat, rub = parse_linea('x|' + resto)
        eco_r['%s|%s' % (pais, reg)] = {'cult': cult, 'carne': carne, 'mat': mat, 'rub': rub, 'nivel': 'p'}
        if reg not in nombres_validos[pais]:
            mal.append(reg)
    json.dump({'pais': eco_p, 'region': eco_r}, open(os.path.join(DATOS, 'economia.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))
    print('economía: países', len(eco_p), '(propios %d)' % sum(1 for v in eco_p.values() if v['nivel'] == 'p'), 'regiones', len(eco_r),
          'sin coincidencia:', mal)


if __name__ == '__main__':
    main()
