#!/usr/bin/env python3
"""Recetas de los descubrimientos (0.1.8.46): QUÉ hace falta, además de los prerrequisitos, para que un país descubra algo.

Una receta tiene tres partes y cada una tiene un EFECTO en el motor (scripts/saber.gd), ninguna es adorno:
  · prerrequisitos (`req`, `req_o`): DUROS. Nadie descubre ni aprende algo si no conoce sus previos (incluye los enlaces de enlaces.txt).
  · edificios (`edif`): grupos «basta uno de cada grupo» de edificios (descubrimientos de tipo B). Un país que no los tiene sigue pudiendo
    descubrirlo, pero con muchísima menos probabilidad (factor SIN_EDIFICIO por grupo que falta). Es el primer efecto real de los edificios.
  · materias (`mat`): materias primas de economia.json que ayudan (factor CON_MATERIA si el país las produce). Es solo una ayuda: los datos de
    economía son de 2026 y gruesos, así que nunca bloquean.
Las reglas están aquí, escritas a mano y con su razón («por qué»); el generador las aplica, y COMPRUEBA que cada grupo de edificios se pueda cumplir
a la fecha del descubrimiento (edificio con año <= año del descubrimiento) y que no cree ciclos (un edificio no puede pedir algo que depende de él).
"""

# ── grupos de edificios (por slug de edificio = slug del descubrimiento de tipo B) ──
SABER = {                                   # centros de estudio según la era del descubrimiento
    3: ["escuelas_escribas", "academias_filosoficas", "biblioteca"],
    4: ["biblioteca", "monasterios_copistas", "escuelas_monasticas", "casa_de_traduccion", "madrasas_escuelas",
        "universidades_medievales", "escuelas_traduccion", "observatorios_astronomicos"],
    5: ["universidades_medievales", "biblioteca", "observatorios_astronomicos", "academias_ciencias", "casa_de_traduccion"],
    6: ["universidades_medievales", "academias_ciencias", "observatorios_astronomicos", "academias_lengua"],
    7: ["universidades_investigacion", "academias_ciencias", "escuelas_tecnicas_ingenieria", "museos_publicos"],
    8: ["universidades_investigacion", "laboratorios_industriales", "escuelas_tecnicas_ingenieria"],
    9: ["universidades_investigacion", "laboratorios_industriales"],
    10: ["universidades_investigacion", "laboratorios_industriales"],
    11: ["laboratorios_industriales", "estacion_espacial", "universidades_investigacion"],
}
CIUDAD = ["ciudad_primitiva", "templos_monumentales", "foro_agora", "ciudades_romanas_servicios", "burgos_fortificados", "plazas_mercado_urbano"]
MERCADO = ["mercados_locales", "almacenes_suministro", "feria_comercial", "plazas_mercado_urbano", "grandes_almacenes"]
SALUD = ["hospitales_religiosos", "escuelas_medicina", "lazaretos", "hospital_moderno"]
TALLER_MIL = ["arsenal_fundicion", "escuelas_militares", "academia_militar_moderna"]
TALLER_MOD = ["academia_militar_moderna", "laboratorios_industriales", "arsenal_fundicion"]
LAB = ["laboratorios_industriales", "universidades_investigacion"]
TALLER_IND = ["escuelas_tecnicas_ingenieria", "laboratorios_industriales", "fabrica_textil", "arsenal_fundicion", "universidades_investigacion"]

# Razones que ve el jugador (índice = id de regla en el JSON)
RAZONES = [
    "Se estudia donde hay escuelas, bibliotecas o universidades.",                         # 0
    "La medicina se aprende atendiendo enfermos: hacen falta hospitales o escuelas de medicina.",  # 1
    "Las armas nuevas salen de arsenales y escuelas de guerra.",                           # 2
    "Los inventos industriales salen de escuelas técnicas y laboratorios.",                # 3
    "Gobernar exige ciudades: plazas, foros y templos donde se decide.",                   # 4
    "El comercio y las cuentas necesitan mercados y almacenes.",                           # 5
    "La salud pública se organiza donde hay hospitales.",                                  # 6
    "Las armas estratégicas se desarrollan en laboratorios de investigación.",             # 7
]

# Secciones por código
CIE_SABER = {"MAT", "FIS", "QUI", "AST", "TIE", "MED", "BIO", "COM"}          # ciencias que se estudian desde la Antigüedad
CIE_TECNICAS = {"AGR", "ING", "ENE", "ELE", "TRA", "MAN"}                        # oficios que solo piden escuela técnica en la era industrial
SOC_ESTADO = {"GOB", "LEY", "DIP", "TER", "CIV", "COM"}
SOC_SABER = {"EDU", "HUM", "REL"}

# Materias primas por palabra del slug (nombres de datos/economia.json). Cada palabra es un prefijo de «palabra_del_slug»; con «$» al final, la palabra exacta.
MAT_PALABRAS = [
    (("bronce",), ["Cobre", "Estaño"]), (("cobre",), ["Cobre"]), (("hierro", "acero", "forja", "altos"), ["Hierro"]),
    (("carbon", "hulla", "coque"), ["Carbón"]), (("petrol", "gasolina", "refiner"), ["Petróleo"]), (("gas",), ["Gas natural"]),
    (("nuclear", "atomic", "uranio", "fision"), ["Uranio"]), (("litio", "bateria"), ["Litio"]), (("aluminio",), ["Bauxita"]),
    (("fosfato", "abono", "fertiliz"), ["Fosfatos"]), (("vidrio", "cuarzo", "silicio", "semiconduct", "chip$"), ["Cuarzo"]),
    (("oro$", "moneda", "acun"), ["Oro", "Plata"]), (("polvora", "salitre"), ["Sal"]),
]
MAT_REC = {                                                                       # prospectar un recurso es más fácil donde el país ya lo produce
    "rec_cobre": ["Cobre"], "rec_estano": ["Estaño"], "rec_oro_plata": ["Oro", "Plata"], "rec_hierro": ["Hierro"], "rec_plomo": ["Plomo"],
    "rec_sal": ["Sal"], "rec_madera_bosque": ["Madera"], "rec_bauxita": ["Bauxita"], "rec_aleantes": ["Níquel", "Cromo", "Manganeso"],
    "rec_carbon": ["Carbón"], "rec_fosfatos_nitratos": ["Fosfatos"], "rec_petroleo": ["Petróleo"], "rec_gas_natural": ["Gas natural"],
    "rec_uranio": ["Uranio"], "rec_litio": ["Litio"], "rec_tierras_raras": ["Tierras raras"], "rec_cobalto_coltan": ["Cobalto", "Coltán"],
    "rec_petroleo_marino": ["Petróleo"], "rec_esquisto": ["Petróleo", "Gas natural"], "rec_torio": ["Uranio"], "rec_salitre_azufre": ["Sal"],
    "rec_piedra_cantera": ["Mármol"],
}


def _grupo(slugs):
    return list(slugs)


def receta(n, anio):
    """n = nodo del catálogo (con slug, era, tipo, rama, sec). Devuelve (grupos de edificios [[slug,...],...], materias [..], reglas [id,...])."""
    era, tipo, rama, sec, slug = n["era"], n["tipo"], n["rama"], n["sec"], n["slug"]
    grupos, reglas = [], []

    def pon(g, r):
        grupos.append(_grupo(g))
        reglas.append(r)

    if rama == "CIE":
        if era >= 3 and sec in CIE_SABER and tipo in ("K", "T", "V", "B"):
            pon(SABER[min(era, 11)], 0)
        elif era >= 7 and sec in CIE_TECNICAS:
            pon(SABER[min(era, 11)] if era >= 8 else TALLER_IND, 3)
        if sec == "MED" and era >= 4:
            pon(SALUD, 1)
    elif rama == "MIL":
        if sec == "NBQ" and era >= 8:
            pon(LAB, 7)
        elif tipo in ("U", "W", "V") and era >= 8:
            pon(TALLER_MOD, 2)
        elif tipo in ("U", "W", "V") and era >= 5:
            pon(TALLER_MIL, 2)
    elif rama == "SOC":
        if sec in SOC_ESTADO and era >= 2 and tipo in ("G", "T", "A"):
            pon(CIUDAD, 4)
        elif sec == "ECO" and era >= 2:
            pon(MERCADO, 5)
        elif sec == "SAL" and era >= 7:
            pon(SALUD, 6)
        elif sec in SOC_SABER and era >= 3 and tipo in ("K", "T", "G"):
            pon(SABER[min(era, 11)], 0)
    # materias
    mat = []
    if tipo == "R":
        mat = list(MAT_REC.get(slug, []))
    else:
        palabras = slug.split("_")
        for prefijos, nombres in MAT_PALABRAS:
            if any((w == p[:-1]) if p.endswith("$") else w.startswith(p) for w in palabras for p in prefijos):
                mat = list(nombres)
                break
        if not mat and rama == "MIL" and tipo in ("W", "U", "V"):
            if era == 2:
                mat = ["Cobre", "Estaño"]
            elif 3 <= era <= 6:
                mat = ["Hierro"]
            elif era >= 7:
                mat = ["Hierro", "Carbón"]
    return grupos, mat, reglas
