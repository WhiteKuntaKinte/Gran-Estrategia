#!/usr/bin/env python3
"""0.1.8.47 · Añade al catálogo datos/variables.json las variables de demografía, educación y presupuesto (ids 62-76). Es idempotente: si una variable ya
está por nombre, no la toca. Uso: python3 herramientas/anadir_variables_047.py   (desde GranEstrategia_v0.1.8/)
Los ids no se reutilizan nunca (ver la «ayuda» del propio JSON)."""
import json, os, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RUTA = os.path.join(RAIZ, 'datos', 'variables.json')
VERSION = '0.1.8.47'

PROV = ['provincia']
PAIS = ['pais']
MEDIA = 'media_ponderada:poblacion'

NUEVAS = [
    (62, 'natalidad', 'Natalidad', 'demografia', '‰ por año', PROV, 'ninguno', MEDIA, False,
     'Nacimientos por cada mil habitantes y año. Baja con la alfabetización, la urbanización y la salud; sube con el bienestar. La calcula scripts/demografia.gd.'),
    (63, 'mortalidad', 'Mortalidad', 'demografia', '‰ por año', PROV, 'ninguno', MEDIA, False,
     'Muertes por cada mil habitantes y año, por todas las causas: baja con el saber de medicina y su acceso; sube con el hambre, la guerra, la devastación y el envejecimiento.'),
    (64, 'edad_joven', 'Niños (0-14)', 'demografia', '0-1', PROV, 'ninguno', MEDIA, False,
     'Fracción de la población de 0 a 14 años. Sigue a la natalidad con ~35 años de rezago.'),
    (65, 'edad_mayor', 'Mayores (65+)', 'demografia', '0-1', PROV, 'ninguno', MEDIA, False,
     'Fracción de la población de 65 años o más. Los adultos (15-64) son lo que queda: 1 − niños − mayores.'),
    (66, 'urbanizacion', 'Urbanización', 'demografia', '0-1', PROV, 'ninguno', MEDIA, False,
     'Parte de la población que vive en ciudades. Se acerca despacio a lo que permiten el urbanismo y la ingeniería que se saben y la riqueza.'),
    (67, 'bienestar', 'Bienestar', 'demografia', '0-100', PROV, 'ninguno', MEDIA, False,
     'Satisfacción de las necesidades básicas (comida, vivienda, salud, paz). Entra en la favorabilidad (estabilidad social) y en la natalidad.'),
    (68, 'alfabetizacion', 'Alfabetización', 'educacion', '0-1', PROV, 'ninguno', MEDIA, False,
     'Parte de la gente que sabe leer y escribir. Sube con lo que el país sabe de educación, las escuelas y el gasto en educación; lo lleva scripts/demografia.gd.'),
    (69, 'escolaridad_media', 'Escolaridad media', 'educacion', 'años', PROV, 'ninguno', MEDIA, False,
     'Años de estudio promedio de la gente de la provincia.'),
    (70, 'instituciones_saber', 'Instituciones de saber', 'educacion', 'puntos', PROV, 'ninguno', 'suma', False,
     'Escuelas, universidades, academias y bibliotecas de la provincia (los edificios de la categoría Educación), con más peso las de clases altas.'),
    (71, 'fatiga_guerra', 'Fatiga de guerra', 'estabilidad', '0-100', PAIS, 'ninguno', 'ninguna', False,
     'Cansancio de la gente por la guerra. Sube cada día en guerra y con las bajas (en proporción a la población), baja despacio en paz. Resta favorabilidad y acerca la paz.'),
    (72, 'calidad_docentes', 'Calidad de los docentes', 'educacion', '0-100', PAIS, 'ninguno', 'ninguna', False,
     'Nivel de maestros, escuelas y universidades del país: lo que sabe de educación, sus instituciones por habitante y el gasto en ciencia.'),
    (73, 'gasto_educacion', 'Gasto en educación', 'economia', 'fracción de los impuestos', PAIS, 'cambio', 'ninguna', True,
     'Parte de los impuestos que el país gasta en educación (referencia 4 %). Se descuenta de lo que llega a la tesorería y acelera la alfabetización.'),
    (74, 'gasto_ciencia', 'Gasto en ciencia', 'economia', 'fracción de los impuestos', PAIS, 'cambio', 'ninguna', True,
     'Parte de los impuestos que el país gasta en investigación (referencia 1,5 %). Se descuenta de la tesorería; mejora los docentes y la capacidad de descubrir.'),
    (75, 'gasto_obras', 'Gasto en obras', 'economia', 'fracción de los impuestos', PAIS, 'cambio', 'ninguna', True,
     'Parte de los impuestos que el país gasta en obras e infraestructura (referencia 2,5 %). Se descuenta de la tesorería.'),
    (76, 'gasto_sanidad', 'Gasto en sanidad', 'economia', 'fracción de los impuestos', PAIS, 'cambio', 'ninguna', True,
     'Parte de los impuestos que el país gasta en salud pública (referencia 2 %). Se descuenta de la tesorería y mejora la salud efectiva de sus provincias.'),
]


def main() -> int:
    with open(RUTA, encoding='utf-8') as f:
        cat = json.load(f)
    existentes = {v['nombre']: v for v in cat['variables']}
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
