#!/usr/bin/env python3
"""0.1.8.48 · Añade al catálogo datos/variables.json el FONDO DE OBRAS PÚBLICAS (id 77). Es idempotente: si la variable ya está por nombre, no la toca.
Uso: python3 herramientas/anadir_variables_048.py   (desde GranEstrategia_v0.1.8/). Los ids no se reutilizan nunca (ver la «ayuda» del propio JSON)."""
import json, os, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(RAIZ, 'datos', 'variables.json')
VERSION = '0.1.8.48'

NUEVAS = [
    (77, 'fondo_obras', 'Fondo de obras públicas', 'economia', 'moneda del país', ['pais'], 'mensual', 'ninguna', False,
     'Dinero apartado para obras: la partida «Gasto en obras» de los impuestos va aquí en vez de perderse. Se gasta primero al construir (edificios) y, si pasa de tres años de aportes, '
     'lo que sobra vuelve a la tesorería. Todos los países con provincias lo tienen (0.1.8.48).'),
]


def main() -> int:
    with open(RUTA, encoding='utf-8') as f:
        cat = json.load(f)
    existentes = {v['nombre'] for v in cat['variables']}
    ids = {v['id_var'] for v in cat['variables']}
    nuevas = 0
    for (idv, nombre, etiqueta, categoria, unidad, aplica, hist, agreg, eco, desc) in NUEVAS:
        if nombre in existentes:
            continue
        if idv in ids:
            print('ERROR: el id %d ya está en uso' % idv)
            return 1
        e = {'id_var': idv, 'nombre': nombre, 'etiqueta': etiqueta, 'categoria': categoria, 'tipo': 'numero', 'unidad': unidad,
             'aplica_a': aplica, 'historial': hist, 'agregacion': agreg, 'descripcion': desc}
        if eco:
            e['afecta_economia'] = True
        cat['variables'].append(e)
        nuevas += 1
    cat['version'] = VERSION
    with open(RUTA, 'w', encoding='utf-8') as f:
        json.dump(cat, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print('variables nuevas: %d · total: %d' % (nuevas, len(cat['variables'])))
    return 0


if __name__ == '__main__':
    sys.exit(main())
