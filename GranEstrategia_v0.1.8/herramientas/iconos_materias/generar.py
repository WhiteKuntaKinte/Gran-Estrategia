#!/usr/bin/env python3
"""
Genera los iconos de materias primas, sectores y divisas del juego (0.1.8.41) y la tabla datos/materias_iconos.json.

  python3 herramientas/iconos_materias/generar.py [--solo-tabla]

Escribe (128 × 128 px, PNG con transparencia):
  iconos/materias/<clave>.png   cultivos, ganado, pesca, minerales, metales, piedras, gemas y energía
  iconos/sectores/<clave>.png   rubros de la economía (servicios, manufactura, finanzas...)
  iconos/divisas/d_<COD>.png    una moneda por divisa de datos/divisas.json
  datos/materias_iconos.json    nombre del juego («Caña de azúcar») -> icono («materias/cana»), reglas por palabras para los rubros y lista de iconos que existen
Todo se dibuja desde cero con pillow (ver lienzo.py): no hay imágenes ni iconos de terceros.
Para AÑADIR un material: dibujar su función en cultivos.py / animales.py / minerales.py, añadirla a ICONOS, poner su nombre en ALIAS (abajo) y volver a generar.
"""
import json
import os
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import animales
import cultivos
import divisas
import minerales
import sectores
from lienzo import Lienzo

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAL_ICONOS = os.path.join(RAIZ, 'iconos')
DATOS = os.path.join(RAIZ, 'datos')

# nombre en datos/economia.json -> clave del icono en iconos/materias/
ALIAS = {
    # cultivos
    'Trigo': 'trigo', 'Maíz': 'maiz', 'Caña de azúcar': 'cana', 'Arroz': 'arroz', 'Coco': 'coco', 'Hortalizas': 'hortalizas', 'Banano': 'banano', 'Yuca': 'yuca',
    'Café': 'cafe', 'Sorgo': 'sorgo', 'Papa': 'papa', 'Mijo': 'mijo', 'Soya': 'soya', 'Cebada': 'cebada', 'Taro': 'taro', 'Algodón': 'algodon',
    'Palma de aceite': 'palma_aceite', 'Plátano': 'platano', 'Cacao': 'cacao', 'Remolacha': 'remolacha', 'Olivo': 'olivo', 'Dátil': 'datil', 'Heno': 'heno',
    'Caucho': 'caucho', 'Uva': 'uva', 'Frijol': 'frijol', 'Tabaco': 'tabaco', 'Flores': 'flores', 'Girasol': 'girasol', 'Maní': 'mani', 'Manzana': 'manzana',
    'Cítricos': 'citricos', 'Té': 'te', 'Colza': 'colza', 'Avena': 'avena', 'Naranja': 'naranja', 'Arándano': 'arandano', 'Aguacate': 'aguacate', 'Vid': 'vid',
    'Piña': 'pina', 'Ñame': 'name', 'Tomate': 'tomate', 'Sésamo': 'sesamo', 'Canola': 'colza', 'Viveros': 'viveros', 'Maíz de forraje': 'maiz_forraje',
    'Chile': 'chile', 'Leche': 'leche', 'Nuez': 'nuez', 'Fresa': 'fresa', 'Agave': 'agave', 'Quinua': 'quinua', 'Teff': 'teff', 'Frutas': 'frutas',
    'Avellana': 'avellana', 'Centeno': 'centeno', 'Goma arábiga': 'goma_arabiga', 'Pistacho': 'pistacho', 'Anacardo': 'anacardo', 'Frambuesa': 'frambuesa',
    'Forraje': 'forraje', 'Mango': 'mango', 'Yute': 'yute', 'Frutos secos': 'frutos_secos', 'Pepino': 'pepino', 'Kiwi': 'kiwi', 'Vainilla': 'vainilla',
    'Jengibre': 'jengibre', 'Lechuga': 'lechuga', 'Almendra': 'almendra', 'Cereza': 'cereza', 'Lentejas': 'lentejas', 'Alfalfa': 'alfalfa',
    'Nuez pecana': 'nuez_pecana', 'Col': 'col', 'Batata': 'batata', 'Pera': 'pera', 'Hongos': 'hongos', 'Melocotón': 'melocoton', 'Arce': 'arce',
    'Frutales': 'frutas', 'Cebolla': 'cebolla', 'Henequén': 'henequen', 'Limón': 'limon', 'Azúcar': 'azucar', 'Cardamomo': 'cardamomo',
    # ganado
    'Pollo': 'pollo', 'Res': 'res', 'Cerdo': 'cerdo', 'Cabra': 'cabra', 'Cordero': 'cordero', 'Cordero,Cabra': 'cordero', 'Búfalo': 'bufalo', 'Pescado': 'pescado',
    'Camello': 'camello', 'Caballos': 'caballo', 'Caballo': 'caballo', 'Cuy': 'cuy', 'Salmón': 'salmon', 'Camarón': 'camaron', 'Pesca': 'pesca',
    # minerales y energía
    'Petróleo': 'petroleo', 'Petróleo (poco)': 'petroleo', 'Petróleo (potencial)': 'petroleo', 'Petróleo (refinería)': 'petroleo', 'Gas natural': 'gas', 'Gas': 'gas',
    'Oro': 'oro', 'Oro (artesanal)': 'oro', 'Minerales diversos': 'minerales_diversos', 'Minerales (potencial)': 'minerales_diversos', 'Carbón': 'carbon',
    'Carbón (puerto)': 'carbon', 'Madera': 'madera', 'Madera y celulosa': 'madera', 'Sal': 'sal', 'Cobre': 'cobre', 'Turismo': 'turismo', 'Copra': 'coco',
    'Hierro': 'hierro', 'Plata': 'plata', 'Arena': 'arena', 'Arena silícea': 'arena', 'Litio': 'litio', 'Níquel': 'niquel', 'Bauxita': 'bauxita', 'Zinc': 'zinc',
    'Caliza': 'caliza', 'Calizas': 'caliza', 'Investigación científica': 'investigacion', 'Potasa': 'potasa', 'Fosfatos': 'fosfatos', 'Fosfato': 'fosfatos',
    'Gemas': 'gemas', 'Mármol': 'marmol', 'Granito': 'granito', 'Diamantes': 'diamantes', 'Uranio': 'uranio', 'Energía hidroeléctrica': 'hidroelectrica',
    'Hidroenergía': 'hidroelectrica', 'Piedra': 'piedra', 'Piedra triturada': 'piedra_triturada', 'Fluorita': 'fluorita', 'Platino': 'platino', 'Ámbar': 'ambar',
    'Grafito': 'grafito', 'Estaño': 'estano', 'Tierras raras': 'tierras_raras', 'Cobalto': 'cobalto', 'Lignito': 'lignito', 'Magnesita': 'magnesita',
    'Plomo': 'plomo', 'Esmeraldas': 'esmeraldas', 'Molibdeno': 'molibdeno', 'Caolín': 'caolin', 'Yeso': 'yeso', 'Soda': 'soda', 'Trona': 'soda',
    'Energía nuclear': 'nuclear', 'Energía renovable': 'renovable', 'Energía geotérmica': 'geotermica', 'Coltán': 'coltan', 'Cromo': 'cromo', 'Metales': 'metales',
    'Cuarzo': 'cuarzo', 'Boro': 'boro', 'Boratos': 'boro', 'Pizarra': 'pizarra', 'Agua': 'agua', 'Jade': 'jade', 'Corcho': 'corcho', 'Manganeso': 'manganeso',
    'Canal interoceánico': 'canal', 'Alúmina': 'alumina', 'Helio': 'helio', 'Taconita': 'taconita', 'Talco': 'talco', 'Energía': 'energia',
}

# Rubros de la economía: la primera palabra (sin tildes, en minúsculas) que aparezca en el nombre decide el icono. Lo específico va antes.
REGLAS = [
    ('automotri', 'sectores/automotriz'), ('aeroespacial', 'sectores/manufactura'), ('aviacion', 'sectores/manufactura'), ('electron', 'sectores/electronica'),
    ('semiconductor', 'sectores/electronica'), ('dispositivos', 'sectores/farma'), ('farma', 'sectores/farma'), ('biotec', 'sectores/farma'),
    ('petroquim', 'sectores/quimica'), ('quimica', 'sectores/quimica'), ('textil', 'sectores/textil'), ('papel', 'sectores/papel'), ('celulosa', 'materias/madera'),
    ('acero', 'sectores/manufactura'), ('maquila', 'sectores/manufactura'), ('manufactura', 'sectores/manufactura'), ('construccion', 'sectores/construccion'),
    ('hidroelectric', 'materias/hidroelectrica'), ('petroleo', 'materias/petroleo'), ('refinacion', 'materias/petroleo'), ('gas', 'materias/gas'),
    ('carbon', 'materias/carbon'), ('energia', 'materias/energia'), ('miner', 'sectores/mineria'), ('extract', 'sectores/mineria'),
    ('pesca', 'materias/pesca'), ('atun', 'materias/pescado'), ('langosta', 'materias/camaron'), ('ganader', 'sectores/ganaderia'), ('lacteos', 'materias/leche'),
    ('agroindustria', 'sectores/agroindustria'), ('agricultura', 'sectores/agricultura'), ('cafe', 'materias/cafe'), ('vino', 'materias/uva'),
    ('madera', 'materias/madera'), ('canal', 'materias/canal'), ('puerto', 'sectores/puertos'), ('logistic', 'sectores/logistica'),
    ('remesas', 'sectores/remesas'), ('turismo', 'materias/turismo'), ('juego', 'materias/turismo'), ('comerc', 'sectores/comercio'),
    ('seguros', 'sectores/seguros'), ('finanz', 'sectores/finanzas'), ('inmobil', 'sectores/inmobiliario'), ('tecnolog', 'sectores/tecnologia'),
    ('servicios publicos', 'sectores/servicios_publicos'), ('gobierno', 'sectores/gobierno'), ('entretenimiento', 'sectores/entretenimiento'),
    ('medios', 'sectores/entretenimiento'), ('musica', 'sectores/entretenimiento'), ('investig', 'materias/investigacion'), ('servicios', 'sectores/servicios'),
    ('sal', 'materias/sal'), ('otros', 'sectores/otros'),
]


def clave(nombre):
    """Misma regla que `Pinturas.clave` del juego: minúsculas, sin tildes, separado por «_»."""
    s = unicodedata.normalize('NFD', nombre.lower())
    s = ''.join(ch for ch in s if unicodedata.category(ch) != 'Mn')
    for a, b in (('ø', 'o'), ('ł', 'l'), ('ß', 'ss'), ('ç', 'c')):
        s = s.replace(a, b)
    r, sep = '', False
    for ch in s:
        if ('a' <= ch <= 'z') or ('0' <= ch <= '9'):
            if sep and r:
                r += '_'
            r += ch
            sep = False
        else:
            sep = True
    return r


def todos_los_iconos():
    mat = {}
    for mod in (cultivos, animales, minerales):
        mat.update(mod.ICONOS)
    return mat, sectores.ICONOS, divisas.ICONOS


def escribir(carpeta, fns):
    os.makedirs(carpeta, exist_ok=True)
    for k, f in fns.items():
        c = Lienzo()
        f(c)
        c.guardar(os.path.join(carpeta, k + '.png'))


def comprobar_cobertura(mat):
    """Todos los nombres de economia.json deben tener icono (salvo «—»)."""
    eco = json.load(open(os.path.join(DATOS, 'economia.json'), encoding='utf-8'))
    sin = set()
    for sec in ('pais', 'region'):
        for e in eco[sec].values():
            for campo in ('cult', 'carne', 'mat'):
                v = e.get(campo, [])
                if not isinstance(v, list):
                    continue
                for n in v:
                    n = str(n)
                    if n in ('—', ''):
                        continue
                    if n not in ALIAS and clave(n) not in mat:
                        sin.add(n)
    return sorted(sin)


def tabla(mat):
    alias = {}
    for nombre, k in ALIAS.items():
        if k not in mat:
            raise SystemExit('ALIAS apunta a un icono que no existe: %s -> %s' % (nombre, k))
        alias[clave(nombre)] = 'materias/' + k
    for k in mat:                                          # cada icono también responde a su propia clave (p. ej. «hierro»)
        alias.setdefault(clave(k), 'materias/' + k)
    reglas = []
    for palabra, destino in REGLAS:
        carpeta, k = destino.split('/')
        existe = (mat if carpeta == 'materias' else sectores.ICONOS)
        if k not in existe:
            raise SystemExit('REGLAS apunta a un icono que no existe: %s' % destino)
        reglas.append([clave(palabra), destino])
    return {
        'nota': 'Generado por herramientas/iconos_materias/generar.py; no editar a mano.',
        'alias': alias,
        'reglas': reglas,
        'existentes': {'materias': sorted(mat), 'sectores': sorted(sectores.ICONOS), 'divisas': sorted(k[2:] for k in divisas.ICONOS)},
    }


def main():
    solo_tabla = '--solo-tabla' in sys.argv
    mat, sec, div = todos_los_iconos()
    sin = comprobar_cobertura(mat)
    if sin:
        print('SIN ICONO:', sin)
        raise SystemExit(1)
    if not solo_tabla:
        escribir(os.path.join(SAL_ICONOS, 'materias'), mat)
        escribir(os.path.join(SAL_ICONOS, 'sectores'), sec)
        escribir(os.path.join(SAL_ICONOS, 'divisas'), div)
    t = tabla(mat)
    json.dump(t, open(os.path.join(DATOS, 'materias_iconos.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1, sort_keys=False)
    print('materias %d · sectores %d · divisas %d · alias %d · reglas %d' % (len(mat), len(sec), len(div), len(t['alias']), len(t['reglas'])))


if __name__ == '__main__':
    main()
