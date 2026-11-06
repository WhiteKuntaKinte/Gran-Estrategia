#!/usr/bin/env python3
"""Añade a datos/entidades.json, para cada país:
  cont  = continente DOMINANTE del país (el de más superficie de anillos; Francia era «América del Sur» solo porque la Guayana es
          la provincia con el anillo más grande, y su territorio es casi todo europeo)
  col   = color base del país en el mapa (hex): el de su continente dominante, el mismo que llevan sus provincias propias
  foco  = [x, y, ancho, alto] del grupo de territorio más grande (para centrar el pop-out del doble clic;
          así EE. UU. se centra en los 48 estados contiguos y no en Alaska o Hawái)
Se ejecuta DESPUÉS de construir_mapa.py y construir_entidades.py:  python3 -I herramientas/anadir_color_foco.py
"""
import json, os, sys
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import construir_mapa as cm          # solo se usa su función color_pais (mismo color que el mapa)
DATOS = os.path.join(os.path.dirname(AQUI), 'datos')


def agrupar(cajas, margen=6.0):
    """cajas: lista de (x, y, w, h, peso). Fusiona las que se tocan (con margen). Devuelve (x, y, w, h, peso_total) del grupo de más peso."""
    grupos = [[x, y, x + w, y + h, p] for x, y, w, h, p in cajas]
    cambio = True
    while cambio and len(grupos) > 1:
        cambio = False
        out = []
        for g in grupos:
            for o in out:
                if g[0] <= o[2] + margen and g[2] >= o[0] - margen and g[1] <= o[3] + margen and g[3] >= o[1] - margen:
                    o[0] = min(o[0], g[0]); o[1] = min(o[1], g[1]); o[2] = max(o[2], g[2]); o[3] = max(o[3], g[3]); o[4] += g[4]
                    cambio = True
                    break
            else:
                out.append(g)
        grupos = out
    g = max(grupos, key=lambda q: q[4])
    return [round(g[0], 2), round(g[1], 2), round(g[2] - g[0], 2), round(g[3] - g[1], 2)]


def main():
    prov_js = json.load(open(os.path.join(DATOS, 'provincias_juego.json'), encoding='utf-8'))
    provincias, anillos = prov_js['provincias'], prov_js['anillos']
    ent = json.load(open(os.path.join(DATOS, 'entidades.json'), encoding='utf-8'))
    fuente = json.load(open(os.path.join(DATOS, 'fuente_provincias.json'), encoding='utf-8'))
    en_de = {}
    for q in fuente:
        en_de.setdefault(q['country_es'], q['country'])
    cajas = {}
    color = {}
    peso_cont = {}                             # país -> {continente: superficie de anillos}
    for a in anillos:
        pais = provincias[a['p']]['c']
        b = a['b']
        cajas.setdefault(pais, []).append((b[0], b[1], b[2], b[3], max(b[2] * b[3], 0.01)))
        d_ = peso_cont.setdefault(pais, {})
        d_[a['k']] = d_.get(a['k'], 0.0) + max(b[2] * b[3], 0.01)
    cont_dom = {}
    for pais, d_ in peso_cont.items():
        cont_dom[pais] = max(d_.items(), key=lambda q: q[1])[0]
        r, g, bl = cm.color_pais(cont_dom[pais], en_de.get(pais, pais), 0.0, '', False)
        color[pais] = '%02x%02x%02x' % (int(round(r * 255)), int(round(g * 255)), int(round(bl * 255)))
    n = 0
    for pais, e in ent['paises'].items():
        if pais in color:
            e['col'] = color[pais]
            if e.get('cont') != cont_dom[pais]:
                print('continente de', pais, ':', e.get('cont'), '->', cont_dom[pais])
                e['cont'] = cont_dom[pais]
        if pais in cajas:
            e['foco'] = agrupar(cajas[pais])
            n += 1
    json.dump(ent, open(os.path.join(DATOS, 'entidades.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('entidades.json: col y foco para', n, 'países')


if __name__ == '__main__':
    main()
