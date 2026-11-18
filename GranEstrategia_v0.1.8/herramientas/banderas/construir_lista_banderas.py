#!/usr/bin/env python3
"""
construir_lista_banderas.py (0.1.8.52) — arma lista_banderas.json: los estados REALES de los escenarios históricos (1 d. C., 1096, 1500) con el
identificador de Wikidata que trae Cliopatria, para que commons_banderas.py busque su bandera (o su escudo) en Wikimedia Commons.

Uso:  python3 -I construir_lista_banderas.py            (se corre desde herramientas/banderas/; escribe lista_banderas.json)

Cada entrada:  {id, epoca, nombre_en, nombre_es, qid, anio, desde, hasta, tipo}
  · id = el nombre del archivo de bandera que usa el juego (e1_… / e1096_… / e1500_…), el mismo en banderas/ y banderas_hd/.
Los PUEBLOS sin estado (tribus, culturas, cazadores-recolectores) no entran: nunca tuvieron bandera y no se les inventa una.
"""
import json
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
sys.path.insert(0, os.path.join(RAIZ, 'epoca'))
from construir_epoca import slug                      # noqa: E402

EPOCAS = [('1dc', 'e1_', 1, 'cliopatria_anio1.json'), ('1096', 'e1096_', 1096, 'cliopatria_1096.json'), ('1500', 'e1500_', 1500, 'cliopatria_1500.json')]


def main():
    out = []
    for carpeta, pref, anio, arch in EPOCAS:
        ban = json.load(open(os.path.join(RAIZ, '..', 'datos', 'epocas', carpeta, 'banderas.json'), encoding='utf-8'))['paises']
        en_juego = {v: k for k, v in ban.items()}
        clio = json.load(open(os.path.join(RAIZ, 'epoca', 'fuentes', arch), encoding='utf-8'))['politicas']
        for p in clio:
            i = pref + slug(p['nombre'])
            if i not in en_juego:
                continue
            out.append({'id': i, 'epoca': carpeta, 'nombre_en': p['nombre'], 'nombre_es': en_juego[i], 'qid': p.get('wikidata', ''),
                        'anio': anio, 'desde': p.get('desde'), 'hasta': p.get('hasta')})
    json.dump(out, open(os.path.join(AQUI, 'lista_banderas.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('%d estados' % len(out), {c: sum(1 for x in out if x['epoca'] == c) for c, *_ in EPOCAS}, 'sin qid:', sum(1 for x in out if not x['qid']))


if __name__ == '__main__':
    main()
