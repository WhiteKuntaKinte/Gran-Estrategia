#!/usr/bin/env python3
"""
Genera datos/edificios.json: el catálogo de EDIFICIOS que se pueden construir en una provincia (0.1.8.40).

Salen de los descubrimientos de tipo B (datos/descubrimientos.json: nombre, era, año, sección). Aquí se les añade lo que el árbol no tiene:
categoría (para agruparlos en la ventana Construir), clase de obra (de ella salen el costo y los días), cuántos puede haber por provincia
y una línea de descripción. NO tienen efectos de juego todavía (a propósito): construirlos cuesta dinero y tarda días, se guardan por provincia
y el resto del juego solo los cuenta.

Costo: fracción de la producción anual de la provincia (así vale igual en el año 1 que en 2026), con un piso por habitante (ver scripts/edificios.gd).
Uso:  python3 -I herramientas/construir_edificios.py
"""
import json, os, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, 'datos')

CATEGORIAS = [
    ("ciu", "Vivienda y ciudad", "edificios/cabana_madera"),
    ("tra", "Transporte y obras públicas", "edificios/puente_piedra_arco"),
    ("agu", "Agua y energía", "edificios/acueducto"),
    ("eco", "Economía y comercio", "edificios/mercados_locales"),
    ("edu", "Educación, cultura y ciencia", "edificios/biblioteca"),
    ("sal", "Salud", "edificios/hospital_moderno"),
    ("def", "Defensa fija", "edificios/murallas_urbanas"),
    ("mil", "Mando y formación militar", "edificios/escuelas_militares"),
]

# clase -> (fracción de la producción anual de la provincia, días de obra)
CLASES = {
    "A": ("Básica", 0.0015, 15),
    "B": ("Pequeña", 0.004, 45),
    "C": ("Mediana", 0.012, 120),
    "D": ("Grande", 0.03, 330),
    "E": ("Monumental", 0.07, 800),
    "F": ("Megaproyecto", 0.15, 1800),
}

# slug -> (categoría, clase, máximo por provincia, descripción)
E = {
    "cabana_madera": ("ciu", "A", 5, "Refugios de troncos y ramas: el primer techo estable."),
    "campamento_estacional": ("ciu", "A", 3, "Asentamiento temporal de cazadores y pastores que siguen las estaciones."),
    "adobe_barro": ("ciu", "A", 3, "Casas de barro y adobe secado al sol."),
    "construccion_piedra": ("ciu", "B", 3, "Muros de piedra que duran siglos."),
    "aldea_permanente": ("ciu", "B", 3, "Un pueblo estable de agricultores con graneros y calles."),
    "ciudad_primitiva": ("ciu", "D", 1, "Primeras ciudades: templo, almacén, mercado y murallas."),
    "templos_monumentales": ("ciu", "E", 1, "Zigurats, pirámides y templos que dan identidad a la ciudad."),
    "arco_boveda": ("ciu", "C", 2, "Arcos y bóvedas: cubrir grandes espacios sin vigas."),
    "cupula": ("ciu", "E", 1, "Cúpulas monumentales sobre basílicas y mezquitas."),
    "catedral_gotica": ("ciu", "E", 1, "Catedral con arbotantes y vitrales; obra de generaciones."),
    "burgos_fortificados": ("ciu", "D", 2, "Poblaciones amuralladas alrededor de un castillo o iglesia."),
    "foro_agora": ("ciu", "C", 1, "Plaza pública donde se comercia, se vota y se discute."),
    "ciudades_romanas_servicios": ("ciu", "E", 1, "Ciudad con foro, agua corriente, cloacas, termas y calles ordenadas."),
    "plazas_mercado_urbano": ("ciu", "B", 3, "Plazas con puestos fijos que ordenan el comercio diario."),
    "barrios_obreros": ("ciu", "D", 2, "Barrios de vivienda para la mano de obra de las fábricas."),
    "parques_publicos": ("ciu", "C", 3, "Parques abiertos a todos los vecinos."),
    "rascacielos": ("ciu", "F", 3, "Torres de acero y vidrio que multiplican el suelo urbano."),
    "monasterios_copistas": ("edu", "C", 2, "Monasterios donde se copian y conservan los libros."),
    "museos_publicos": ("edu", "D", 1, "Colecciones abiertas al público."),
    "puente_madera": ("tra", "B", 5, "Puentes de vigas sobre ríos y barrancos."),
    "puente_piedra_arco": ("tra", "D", 3, "Puentes de piedra con arcos que resisten crecidas."),
    "puentes_hierro": ("tra", "D", 3, "Puentes de hierro fundido y forjado."),
    "puentes_colgantes": ("tra", "E", 2, "Tableros colgados de cables para luces enormes."),
    "puente_atirantado": ("tra", "E", 2, "Puentes sostenidos por tirantes desde torres altas."),
    "calzada_pavimentada": ("tra", "D", 2, "Caminos empedrados con drenaje y mojones."),
    "red_viaria_imperial": ("tra", "E", 1, "Red de caminos que une todas las provincias con la capital."),
    "puerto_piedra": ("tra", "D", 2, "Muelles y rompeolas de piedra."),
    "faro": ("tra", "C", 3, "Torre con fuego o linterna que guía a los barcos."),
    "esclusas_canales": ("tra", "E", 2, "Canales con esclusas que suben y bajan las barcazas."),
    "reclamacion_tierras_mar": ("tra", "E", 1, "Pólderes: tierra ganada al mar con diques y bombeo."),
    "tunel_excavacion": ("tra", "D", 2, "Túneles excavados a pico, pólvora y luego a máquina."),
    "tunel_ferroviario": ("tra", "E", 2, "Túneles para el ferrocarril a través de montañas."),
    "canal_interoceanico": ("tra", "F", 1, "Un canal que une dos océanos."),
    "metro_subterraneo": ("tra", "F", 1, "Trenes urbanos bajo la ciudad."),
    "transporte_urbano_masivo": ("tra", "E", 1, "Tranvías, autobuses y trenes que mueven a la ciudad entera."),
    "autopista": ("tra", "E", 2, "Carreteras de alta capacidad sin cruces."),
    "aeropuerto": ("tra", "E", 1, "Pistas, torre de control y terminales."),
    "tunel_submarino": ("tra", "F", 1, "Túnel bajo un estrecho o un mar."),
    "drenaje_urbano": ("agu", "B", 2, "Zanjas y canales que sacan el agua sucia de la ciudad."),
    "alcantarillado": ("agu", "C", 2, "Cloacas cubiertas de piedra o ladrillo."),
    "acueducto": ("agu", "D", 2, "Conducciones que traen agua desde lejos."),
    "presas_gravedad": ("agu", "D", 2, "Muros macizos que embalsan un río."),
    "presas_arco_hormigon": ("agu", "E", 2, "Grandes presas de hormigón."),
    "planta_depuradora": ("agu", "D", 1, "Limpia el agua antes de devolverla al río."),
    "central_termoelectrica": ("agu", "E", 1, "Quema carbón o gas para mover turbinas."),
    "red_electrica": ("agu", "D", 1, "Cables y farolas eléctricas en la ciudad."),
    "central_hidroelectrica": ("agu", "E", 1, "Turbinas movidas por el salto de agua."),
    "red_alta_tension": ("agu", "D", 1, "Líneas que llevan la electricidad a cientos de kilómetros."),
    "gas_natural": ("agu", "E", 1, "Pozos, gasoductos y redes de gas."),
    "central_nuclear": ("agu", "F", 1, "Reactor que genera electricidad con uranio."),
    "energia_solar_comercial": ("agu", "E", 2, "Campos de paneles solares conectados a la red."),
    "parque_eolico": ("agu", "E", 2, "Aerogeneradores en filas sobre colinas o mar."),
    "mercados_locales": ("eco", "A", 3, "Mercado de trueque y venta de excedentes."),
    "feria_comercial": ("eco", "C", 2, "Ferias anuales que atraen mercaderes de lejos."),
    "grandes_almacenes": ("eco", "D", 2, "Tiendas enormes con todo bajo un techo."),
    "fabrica_textil": ("eco", "D", 3, "Telares mecánicos movidos por agua o vapor."),
    "almacenes_suministro": ("eco", "B", 3, "Graneros y depósitos para tiempos de escasez y guerra."),
    "arsenal_fundicion": ("eco", "D", 2, "Fundiciones y arsenales del Estado."),
    "escuelas_escribas": ("edu", "B", 2, "Escuelas donde se aprende a escribir y contar."),
    "academias_filosoficas": ("edu", "C", 1, "Escuelas de filosofía, matemáticas y política."),
    "escuelas_monasticas": ("edu", "B", 2, "Escuelas junto a monasterios y catedrales."),
    "madrasas_escuelas": ("edu", "C", 2, "Colegios de derecho, teología y ciencias."),
    "casa_de_traduccion": ("edu", "C", 1, "Traductores de obras antiguas a otras lenguas."),
    "escuelas_traduccion": ("edu", "C", 1, "Escuelas que traducen textos entre culturas."),
    "universidades_medievales": ("edu", "D", 1, "Gremios de maestros y estudiantes con títulos."),
    "academias_ciencias": ("edu", "D", 1, "Sociedades de sabios con experimentos y revistas."),
    "escuelas_tecnicas_ingenieria": ("edu", "D", 1, "Formación de ingenieros y técnicos."),
    "universidades_investigacion": ("edu", "E", 1, "Universidades con laboratorios y doctorados."),
    "laboratorios_industriales": ("edu", "E", 1, "Investigación aplicada de las empresas."),
    "biblioteca": ("edu", "C", 2, "Rollos y libros reunidos para consulta."),
    "academias_lengua": ("edu", "C", 1, "Fijan la ortografía y el diccionario de la lengua."),
    "observatorios_astronomicos": ("edu", "D", 1, "Torres y cúpulas para observar el cielo."),
    "estacion_espacial": ("edu", "F", 1, "Laboratorio habitado en órbita (la provincia aporta la base de lanzamiento)."),
    "escuelas_medicina": ("sal", "C", 1, "Enseñan a curar con método y práctica."),
    "hospitales_religiosos": ("sal", "C", 2, "Hospicios y hospitales de órdenes religiosas."),
    "lazaretos": ("sal", "B", 2, "Aislamiento de enfermos y viajeros en cuarentena."),
    "hospital_moderno": ("sal", "E", 2, "Salas, quirófanos y especialistas."),
    "empalizada": ("def", "A", 3, "Muro de estacas de madera alrededor del poblado."),
    "zanja_foso": ("def", "A", 3, "Foso excavado para frenar al enemigo."),
    "fortaleza_colina": ("def", "C", 2, "Refugio fortificado en lo alto de una colina."),
    "fortin_torre_vigia": ("def", "B", 5, "Torres que vigilan caminos, costas y pasos."),
    "muralla_piedra": ("def", "D", 1, "Muralla de piedra con puertas."),
    "murallas_urbanas": ("def", "D", 1, "Muros que rodean la ciudad entera."),
    "torres_y_almenas": ("def", "C", 3, "Torres con almenas para los defensores."),
    "puertas_fortificadas": ("def", "C", 2, "Puertas con torres, rastrillo y puente levadizo."),
    "castillo_motte": ("def", "C", 2, "Torre de madera sobre un montículo con patio."),
    "castillo_piedra": ("def", "D", 2, "Castillo de piedra con torre del homenaje."),
    "castillo_concentrico": ("def", "E", 1, "Dos anillos de murallas, uno dentro del otro."),
    "fortificacion_abaluartada": ("def", "E", 1, "Baluartes angulares contra la artillería."),
    "fortaleza_estrella": ("def", "E", 1, "Fortaleza en forma de estrella con fosos y baluartes."),
    "fortificaciones_permanentes": ("def", "E", 1, "Sistema de fortalezas que cubre la frontera."),
    "fuertes_costeros": ("def", "D", 3, "Baterías de cañones que cierran puertos y bahías."),
    "limes_fronteras_fortificadas": ("def", "E", 1, "Muros, torres y fuertes a lo largo de la frontera."),
    "fortificacion_hormigon": ("def", "E", 2, "Fuertes de hormigón armado."),
    "fuertes_acorazados": ("def", "E", 2, "Cúpulas de acero en fuertes de hormigón."),
    "sistema_trincheras": ("def", "C", 2, "Redes de trincheras con refugios y comunicaciones."),
    "casamatas_hormigon": ("def", "D", 3, "Nidos de ametralladoras y cañones bajo hormigón."),
    "linea_defensiva_permanente": ("def", "F", 1, "Una línea continua de fortificaciones modernas."),
    "bunker_antiaereo": ("def", "D", 2, "Refugios y baterías antiaéreas."),
    "bunker_nuclear": ("def", "F", 1, "Búnker profundo contra ataques nucleares."),
    "silo_misil": ("def", "F", 2, "Silo blindado para misiles balísticos."),
    "base_subterranea_montana": ("def", "F", 1, "Base excavada en el interior de una montaña."),
    "defensa_aerea_integrada": ("def", "F", 1, "Radares, misiles y cazas coordinados."),
    "defensa_costera_misiles": ("def", "E", 2, "Misiles contra buques a lo largo de la costa."),
    "escudo_antimisiles": ("def", "F", 1, "Sistema estratégico contra misiles balísticos."),
    "escuelas_militares": ("mil", "C", 1, "Instrucción de oficiales."),
    "academia_militar_moderna": ("mil", "D", 1, "Academia con estado mayor, mapas y juegos de guerra."),
    "calzadas_militares": ("mil", "D", 2, "Caminos para mover ejércitos rápido."),
    "centro_operaciones_ciberneticas": ("mil", "E", 1, "Defensa y ataque en redes informáticas."),
    # 0.1.8.49
    "taller_artesano": ("eco", "B", 4, "Alfareros, tejedores y herreros reunidos en un barrio de talleres."),
    "molinos_hidraulicos": ("eco", "B", 4, "Ruedas de agua que muelen el grano de toda una comarca."),
    "molinos_viento": ("eco", "B", 4, "Aspas sobre las llanuras sin ríos: harina y bombeo de agua."),
    "casa_gremio": ("eco", "C", 2, "Sede de los oficios: fija precios, enseña aprendices y reparte el trabajo."),
    "caravasar_posada": ("eco", "B", 4, "Patios con establos y almacén donde descansan las caravanas."),
    "astillero": ("tra", "D", 2, "Gradas y diques secos donde se construyen y reparan los barcos."),
    "banco_casa_cambio": ("eco", "C", 2, "Mesas de cambio, letras y depósitos: el dinero circula más rápido."),
    "lonja_bolsa": ("eco", "D", 1, "Edificio donde se compran y venden acciones, mercancías y seguros."),
    "altos_hornos": ("eco", "D", 2, "Hornos de hierro colado alimentados por fuelles hidráulicos."),
    "fabrica_vapor": ("eco", "D", 3, "Naves con máquina de vapor que mueven decenas de telares y tornos."),
    "acerias": ("eco", "E", 2, "Convertidores y laminadoras: acero barato para rieles, puentes y barcos."),
    "estacion_ferrocarril": ("tra", "D", 2, "Andenes, depósitos y talleres: la ciudad queda a horas de la capital."),
    "parque_industrial": ("eco", "E", 2, "Zonas de fábricas con calles, energía y muelles de carga comunes."),
    "puerto_contenedores": ("tra", "F", 1, "Grúas pórtico y patios de cajas: carga y descarga en horas."),
    "centro_comercial": ("eco", "D", 3, "Galerías cubiertas con tiendas, aparcamiento y servicios."),
    "tribunal_audiencia": ("ciu", "C", 2, "Salas donde se juzga, se registra y se cumple la ley."),
    "prision": ("ciu", "C", 2, "Celdas y talleres donde se cumple la pena."),
    "comisaria_policia": ("ciu", "C", 3, "Agentes de barrio, calabozos y partes diarios."),
    "casa_consistorial": ("ciu", "C", 1, "El ayuntamiento: concejo, archivo y torre del reloj."),
    "palacio_gobierno": ("ciu", "D", 1, "Residencia y sede del poder: salas de audiencia, tesoro y archivo."),
    "parlamento_edificio": ("ciu", "E", 1, "Hemiciclo, comisiones y biblioteca: donde se discuten y votan las leyes."),
    "iglesia_parroquial": ("ciu", "B", 5, "La iglesia del pueblo: culto, registro de bautizos y socorro a los pobres."),
    "mezquita_aljama": ("ciu", "C", 3, "Sala de oración con patio, minarete y escuela anexa."),
    "templo_pagoda": ("ciu", "C", 3, "Templos de madera y piedra con torres escalonadas y jardines."),
    "teatro_anfiteatro": ("ciu", "C", 2, "Gradas de piedra para obras, juegos y asambleas."),
    "estadio": ("ciu", "D", 2, "Gradas y pista para competir ante decenas de miles."),
    "casa_del_pueblo": ("ciu", "C", 2, "Salón de asambleas, caja de resistencia y escuela nocturna."),
    "cuartel_guarnicion": ("mil", "C", 3, "Barracones, caballerizas y armería para la tropa permanente."),
    "polvorin": ("mil", "C", 2, "Bóvedas seguras para guardar la pólvora y las balas."),
    "cuartel_estado_mayor": ("mil", "D", 1, "Mapas, planes y despachos: donde se prepara la campaña."),
    "estacion_radar": ("mil", "E", 2, "Antenas que ven llegar a los aviones antes de que lleguen."),
    "centro_mando_control": ("mil", "E", 1, "Salas con pantallas y enlaces que coordinan a todas las fuerzas."),
}


def main():
    d = json.load(open(os.path.join(DATOS, 'descubrimientos.json'), encoding='utf-8'))
    col = d['columnas']
    secs = d['secciones']
    filas = [dict(zip(col, r)) for r in d['filas'] if r[col.index('tipo')] == 'B']
    slugs = {f['slug'] for f in filas}
    falta = slugs - set(E)
    sobra = set(E) - slugs
    if falta or sobra:
        sys.exit("Edificios sin datos: %s · datos sin edificio: %s" % (sorted(falta), sorted(sobra)))
    lista = []
    for f in filas:
        cat, cl, mx, desc = E[f['slug']]
        lista.append({"slug": f['slug'], "nombre": f['nombre'], "cat": cat, "clase": cl, "max": mx, "era": f['era'], "anio": f['anio'],
                      "seccion": secs[f['seccion']]['nombre'], "desc": desc})
    lista.sort(key=lambda e: (e['anio'], e['nombre']))
    sal = {
        "version": "0.1.8.40",
        "ayuda": "Catálogo de EDIFICIOS construibles por provincia (109, los descubrimientos de tipo B). No se edita a mano: lo genera herramientas/construir_edificios.py. "
                 "costo = fracción de la producción anual de la provincia según la clase (con un piso por habitante); dias = días de obra de la clase. "
                 "Sin efectos de juego todavía: construirlos cuesta dinero y tarda días, se guardan por provincia.",
        "categorias": [{"cod": c, "nombre": n, "icono": i} for c, n, i in CATEGORIAS],
        "clases": {k: {"nombre": n, "fraccion": fr, "dias": dd} for k, (n, fr, dd) in CLASES.items()},
        "edificios": lista,
    }
    with open(os.path.join(DATOS, 'edificios.json'), 'w', encoding='utf-8') as fh:
        json.dump(sal, fh, ensure_ascii=False, separators=(',', ':'))
    print("edificios.json:", len(lista), "edificios,", len(CATEGORIAS), "categorías")


if __name__ == '__main__':
    main()
