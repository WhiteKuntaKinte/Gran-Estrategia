#!/usr/bin/env python3
"""
extraer_cliopatria.py — Saca de Cliopatria v0.2.1 (Seshat Global History Databank, CC BY 4.0) los estados que existen en un año
y los guarda en el formato que lee construir_epoca.py (fuentes/cliopatria_<año>.json).

Uso:   python3 -I extraer_cliopatria.py cliopatria_polities_only_v021.geojson ANIO SALIDA.json
(El geojson sale de cliopatria.geojson.zip de https://github.com/Seshat-Global-History-Databank/cliopatria.)

Reglas: se toma cada registro cuyo tramo [FromYear, ToYear] contiene el año; se descartan los registros de tipo RELATION y los nombres entre
paréntesis (son el «paraguas» de un señor feudal: duplican el territorio de los estados que ya están listados); de cada polígono solo se usa
el contorno exterior (los huecos casi siempre son enclaves de otro estado de la lista). `desde`/`hasta` = vida completa del estado en Cliopatria.
"""
import json
import sys


def main():
    ruta, anio, salida = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    g = json.load(open(ruta, encoding='utf-8'))
    vida = {}
    for f in g['features']:
        p = f['properties']
        a, b = int(float(p['FromYear'])), int(float(p['ToYear']))
        v = vida.setdefault(p['Name'], [a, b])
        v[0], v[1] = min(v[0], a), max(v[1], b)
    pol = {}
    for f in g['features']:
        p = f['properties']
        a, b = int(float(p['FromYear'])), int(float(p['ToYear']))
        if not (a <= anio <= b) or p.get('Type') != 'POLITY' or p['Name'].startswith('('):
            continue
        geo = f['geometry']
        polys = [geo['coordinates']] if geo['type'] == 'Polygon' else geo['coordinates']
        d = pol.setdefault(p['Name'], {'nombre': p['Name'], 'desde': vida[p['Name']][0], 'hasta': vida[p['Name']][1], 'area_km2': 0.0,
                                       'wikidata': p.get('Wikidata', ''), 'partes': []})
        d['area_km2'] += float(p['Area'])
        for pl in polys:
            d['partes'].append([[round(x, 4), round(y, 4)] for x, y in pl[0]])
    out = {'fuente': 'Cliopatria v0.2.1 (Seshat Global History Databank), CC BY 4.0, https://github.com/Seshat-Global-History-Databank/cliopatria',
           'corte_anio': anio, 'politicas': sorted(pol.values(), key=lambda d: -d['area_km2'])}
    json.dump(out, open(salida, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('%d estados en %d → %s' % (len(out['politicas']), anio, salida))


if __name__ == '__main__':
    main()
