#!/usr/bin/env python3
"""
construir_ids.py — Registro único de IDs de territorio (0.1.7.9.9B).

Cada territorio del juego tiene UN ID entero, único en todo el juego y que nunca se reutiliza:

    tipo         rango de ID        padre (cadena)
    mundo        0                  —
    continente   1 – 99             mundo
    país         100 – 999          continente
    estado       1000 – 9999        país
    provincia    10000 – 99999      estado (si lo tiene) o país
    ciudad       100000 – 999999    provincia (si está dentro de una) o país

El padre es el padre GEOGRÁFICO original (no cambia al conquistar). Quién controla hoy una provincia es la variable
`propietario` de la base de datos (con historial), no esta tabla.

El archivo datos/ids.json es el registro PERMANENTE: si vuelves a ejecutar esta herramienta, los territorios que ya
existen conservan su ID y los nuevos reciben el siguiente libre. Un territorio que desaparece de los datos queda como
"baja" (su ID no se reutiliza). Así las partidas, el historial y las variables no se descuadran al regenerar el mapa.

Uso:  python3 -I herramientas/construir_ids.py        (ejecutar DESPUÉS de construir_entidades.py)
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.environ.get('GE_DATOS') or os.path.join(RAIZ, 'datos')   # 0.1.8.34: GE_DATOS = carpeta de un escenario

TIPOS = ['mundo', 'continente', 'pais', 'estado', 'provincia', 'ciudad']
RANGOS = {'mundo': (0, 0), 'continente': (1, 99), 'pais': (100, 999), 'estado': (1000, 9999),
          'provincia': (10000, 99999), 'ciudad': (100000, 999999)}
# Solo documentación: las entidades políticas históricas (1.000.000-1.999.999) y las personas (2.000.000 en adelante) NO se
# generan aquí; viven en datos/historico/ (herramientas/descargar_historia) y comparten el mismo espacio de IDs.
RANGOS_HISTORIA = {'entidad': (1000000, 1999999), 'persona': (2000000, 9999999)}
# También solo documentación: el ejército (0.1.7.9.9D) se crea al empezar la partida (scripts/ejercito.gd), no se guarda aquí.
# Cada país tiene un ejército y cada ejército sus pelotones (padre = ejército); los IDs de pelotón no se reutilizan.
RANGOS_EJERCITO = {'ejercito': (10000000, 10999999), 'peloton': (11000000, 19999999)}


def cargar(nombre):
    with open(os.path.join(DATOS, nombre), encoding='utf-8') as f:
        return json.load(f)


def main():
    ent = cargar('entidades.json')['paises']
    prov = cargar('provincias_juego.json')['provincias']
    estados = cargar('estados.json')
    ciu = cargar('ciudades.json')

    ruta_ids = os.path.join(DATOS, 'ids.json')
    viejo = {}
    siguiente = {t: RANGOS[t][0] for t in TIPOS}
    if os.path.exists(ruta_ids):
        reg = cargar('ids.json')
        for fila in reg['territorios']:
            viejo[(TIPOS[fila[1]], fila[4])] = fila[0]
        for t, v in reg.get('siguiente', {}).items():
            siguiente[t] = max(siguiente.get(t, 0), int(v))
        print('registro previo: %d IDs conservados' % len(viejo))

    filas = {}          # (tipo, clave) -> [id, tipo_idx, nombre, padre, clave, activo]
    nuevos = [0]

    def asignar(tipo, clave, nombre, padre):
        k = (tipo, clave)
        if k in filas:
            raise SystemExit('clave repetida: %s %s' % k)
        if k in viejo:
            i = viejo[k]
        else:
            i = siguiente[tipo]
            if i > RANGOS[tipo][1]:
                raise SystemExit('rango agotado para ' + tipo)
            siguiente[tipo] = i + 1
            nuevos[0] += 1
        filas[k] = [i, TIPOS.index(tipo), nombre, padre, clave, 1]
        return i

    asignar('mundo', 'mundo', 'Mundo', -1)
    id_cont = {}
    for c in sorted(set(e['cont'] for e in ent.values())):
        id_cont[c] = asignar('continente', c, c, 0)
    id_pais = {}
    for n in sorted(ent):
        id_pais[n] = asignar('pais', n, n, id_cont[ent[n]['cont']])
    id_estado = {}
    for pn in sorted(estados):
        for e in sorted(estados[pn], key=lambda x: x['n']):
            k = '%s|%s' % (pn, e['n'])
            id_estado[k] = asignar('estado', k, e['n'], id_pais[pn])
    id_prov = []
    for p in prov:
        padre = id_pais[p['c']]
        if p.get('e') and ('%s|%s' % (p['c'], p['e'])) in id_estado:
            padre = id_estado[('%s|%s' % (p['c'], p['e']))]
        id_prov.append(asignar('provincia', p['id'], p['n'], padre))
    paises_c = ciu['paises']
    vistos = {}
    for f in ciu['c']:
        pn = paises_c[f[5]]
        pid = prov[f[6]]['id'] if 0 <= f[6] < len(prov) else ''
        base = '%s|%s|%s' % (f[0], pn, pid)
        vistos[base] = vistos.get(base, 0) + 1
        clave = base if vistos[base] == 1 else '%s#%d' % (base, vistos[base])
        padre = id_prov[f[6]] if 0 <= f[6] < len(prov) else id_pais.get(pn, 0)
        asignar('ciudad', clave, f[0], padre)

    # Territorios que ya no existen: se conservan como baja (el ID no se reutiliza)
    if os.path.exists(ruta_ids):
        for fila in cargar('ids.json')['territorios']:
            k = (TIPOS[fila[1]], fila[4])
            if k not in filas:
                fila = list(fila)
                fila[5] = 0
                filas[k] = fila

    lista = sorted(filas.values(), key=lambda f: f[0])
    ids = [f[0] for f in lista]
    assert len(ids) == len(set(ids)), 'IDs repetidos'
    for f in lista:                               # cada padre existe y es de un nivel superior
        if f[3] >= 0:
            assert f[3] in set(ids), 'padre inexistente %s' % f
    salida = {
        'version': '0.1.7.9.9F',
        'tipos': TIPOS + ['entidad', 'ejercito', 'peloton'],
        'rangos': {t: list(r) for t, r in list(RANGOS.items()) + list(RANGOS_HISTORIA.items()) + list(RANGOS_EJERCITO.items())},
        'siguiente': siguiente,
        'columnas': ['id', 'tipo', 'nombre', 'padre', 'clave', 'activo'],
        'territorios': lista,
    }
    with open(ruta_ids, 'w', encoding='utf-8') as f:
        json.dump(salida, f, ensure_ascii=False, separators=(',', ':'))
    cuenta = {t: sum(1 for x in lista if x[1] == i and x[5] == 1) for i, t in enumerate(TIPOS)}
    print('IDs: %s | nuevos %d | total %d | %.1f KB' % (cuenta, nuevos[0], len(lista), os.path.getsize(ruta_ids) / 1024))


if __name__ == '__main__':
    sys.exit(main())
