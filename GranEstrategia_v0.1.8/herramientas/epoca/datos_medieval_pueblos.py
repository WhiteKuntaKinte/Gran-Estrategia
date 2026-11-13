# -*- coding: utf-8 -*-
"""
Épocas 1096 y 1500 — PUEBLOS sin estado (los que llenan lo que Cliopatria no cubre).

Reutilizan las ZONAS dibujadas a mano para el año 1 (datos_1dc_pueblos_a.py y _b.py): la geografía de los pueblos de las Américas, África subsahariana,
Siberia, Oceanía o el sudeste asiático cambia poco en mil años; lo que cambia es el nombre, la población y, en Europa y el Oriente Próximo, que casi todo
pasa a ser territorio de un estado (esos pueblos del año 1 no entran aquí).

PUEBLOS_MED: clave del pueblo del año 1 -> nombre del pueblo en 1096 y en 1500 (un solo texto si no cambia; None = no existe en esa época).
La población sale de la del año 1 por un factor por región (FACTOR): estimaciones de orden de magnitud, no datos exactos.
"""

# (nombre 1096, nombre 1500)
PUEBLOS_MED = {
    # ── Europa ──
    'sami': 'Sami y pueblos de la Fenoscandia septentrional',
    'fineses': 'Pueblos fineses y carelios',
    'balticos': 'Pueblos bálticos (prusianos, lituanos y letones)',
    'finougrios': 'Pueblos finougrios del Volga y el Kama (mordvinos, mari y komi)',
    'pueblos_taurus': 'Pueblos del Cáucaso septentrional (alanos, circasianos y vainakhs)',
    'hibernios': 'Irlanda gaélica (reinos y clanes)',
    'britones_oeste': 'Gales (Gwynedd, Powys y Deheubarth)',
    'caledonios': 'Highlands y las islas escocesas',
    'guanches': 'Guanches (Islas Canarias)',
    # ── África ──
    'getulos': 'Bereberes del Atlas y el Sáhara (sanhaya y zenata)',
    'garamantes': 'Tuareg y pueblos del Fezzán',
    'blemios': 'Beja del desierto oriental',
    'nubios': 'Pueblos nilóticos del Sudán meridional (dinka, nuer y shilluk)',
    'cuerno': 'Pueblos cusitas del Cuerno de África (somalíes, oromo y afar)',
    'sahel_occ': 'Pueblos del Sahel y el Níger (mande, songhai y mossi)',
    'nok': ('Pueblos yoruba, edo e igbo (Ifé y Benín)', 'Pueblos yoruba, edo e igbo (Oyo y Benín)'),
    'sao': ('Pueblos del lago Chad y hausa', 'Ciudades-estado hausa y pueblos del lago Chad'),
    'guinea': 'Pueblos de la selva guineana (akan, mande y kru)',
    'africa_central_n': 'Pueblos de África central septentrional (azande y banda)',
    'bantu_occ': ('Bantúes occidentales (Loango, teke y kuba)', 'Bantúes occidentales (Loango, Ndongo y Luba)'),
    'bantu_orient': ('Pueblos de los Grandes Lagos (Kitara y Rwanda)', 'Pueblos de los Grandes Lagos (Bunyoro, Rwanda y Buganda)'),
    'bantu_costa': ('Ciudades-estado suahilis de la costa', 'Ciudades-estado suahilis (Kilwa, Mombasa y Malindi)'),
    'bantu_sur': ('Bantúes del sur (Mapungubwe y Gran Zimbabue)', 'Bantúes del sur (Gran Zimbabue y Mutapa)'),
    'khoisan': 'Pueblos khoisan (san y joikoi)',
    # ── Asia occidental y central ──
    'arabes_centro': 'Tribus árabes de Néyed y el Hiyaz',
    'golfo_omani': 'Omán y las ciudades del golfo Pérsico',
    'masagetas': ('Pueblos esteparios de Asia central (oguces y kipchaks)', 'Pueblos esteparios de Asia central (uzbekos y karakalpakos)'),
    'saka_pamir': 'Pueblos del Pamir y el Tianshan',
    'tarim': ('Ciudades-estado de la cuenca del Tarim (Jotán)', 'Ciudades-oasis de la cuenca del Tarim'),
    'qiang': 'Pueblos qiang y tibetanos del Kham',
    'xianbei': ('Mongoles y tártaros de la estepa oriental', 'Mongoles occidentales (oirates)'),
    'buyeo': ('Jurchen y pueblos de Manchuria', 'Jurchen (Jianzhou y Haixi)'),
    'amur': 'Pueblos del Amur y el Ussuri (nanai y ulchi)',
    'dingling': 'Pueblos túrquicos del Altái y el Sayán',
    'baikal': 'Buriatos y pueblos del Baikal',
    'sargat': 'Pueblos esteparios del Ural y Siberia occidental',
    'uralicos_sib': 'Pueblos uralios de Siberia occidental (jantis, mansis y nenets)',
    'evenkis': 'Cazadores-recolectores del norte de Siberia (evenkis y yukaguires)',
    'paleosiberianos': 'Paleosiberianos (chukchis, coriacos y kamchadales)',
    # ── Asia meridional y sudoriental ──
    'himalaya': 'Pueblos del Himalaya (newar y kirata)',
    'adivasi': 'Pueblos tribales del Decán interior (gond y bhil)',
    'assam': 'Pueblos de Assam y el Noreste (ahom y naga)',
    'baluchis': 'Baluchis y pueblos de Gedrosia',
    'mon': 'Pueblos mon de la costa birmana',
    'lao_thai': 'Pueblos tai y de Indochina interior',
    'malayos': 'Malayos (Malaca y Sumatra)',
    'java_bali': 'Pueblos de Java oriental y las Pequeñas Sondas',
    'borneo': 'Pueblos de Borneo (dayak)',
    'celebes': 'Pueblos de Célebes y las Molucas (bugis y ternate)',
    'filipinas': 'Austronesios de las Filipinas (barangayes)',
    'taiwan': 'Pueblos austronesios de Taiwán',
    'emishi': ('Emishi y ainu del norte de Honshu', None),
    'ainu': 'Ainu (Hokkaidō y Sajalín)',
    # ── Oceanía ──
    'abo_norte': 'Pueblos aborígenes del norte de Australia', 'abo_este': 'Pueblos aborígenes del este de Australia',
    'abo_sur': 'Pueblos aborígenes del sur de Australia', 'abo_oeste': 'Pueblos aborígenes del suroeste de Australia',
    'abo_centro': 'Pueblos aborígenes del desierto central', 'tasmania': 'Pueblos aborígenes de Tasmania',
    'papues_altos': 'Papúes de las tierras altas de Nueva Guinea', 'papues_costa': 'Papúes y austronesios de la costa de Nueva Guinea',
    'melanesia': 'Melanesios (Bismarck, Salomón y Vanuatu)', 'fiji_polinesia': 'Pueblos de Fiyi, Tonga y Samoa',
    'micronesia': 'Micronesios (Marianas, Palaos y Yap)',
    # ── América del Norte ──
    'hopewell': ('Cultura misisipiana (Cahokia)', 'Pueblos misisipianos (natchez y mobile)'),
    'sureste_na': ('Pueblos del sureste (misisipianos)', 'Pueblos del sureste (creek, cherokee y choctaw)'),
    'noreste_na': ('Pueblos del noreste (algonquinos e iroqueses)', 'Pueblos del noreste (algonquinos, hurones y abenaki)'),
    'subartico': 'Pueblos del Subártico (atabascos y algonquinos)',
    'artico': ('Pueblos del Ártico (dorset y thule)', 'Pueblos del Ártico (inuit)'),
    'aleutianos': 'Aleutas y pueblos del suroeste de Alaska',
    'alaska_int': 'Pueblos del interior de Alaska',
    'noroeste_na': 'Pueblos de la costa noroeste (tlingit, haida y kwakiutl)',
    'california': 'Pueblos de California (chumash y pomo)',
    'gran_cuenca': 'Pueblos de la Gran Cuenca y la meseta',
    'llanuras': 'Pueblos de las Grandes Llanuras',
    'anasazi': ('Pueblos ancestrales puebloanos (anasazi)', 'Pueblos puebloanos (hopi y zuñi)'),
    'hohokam_mogollon': ('Culturas hohokam y mogollón', 'Pueblos del desierto de Sonora (pima y apache)'),
    'norte_mexico': 'Chichimecas del norte de México',
    'occidente_mx': ('Pueblos del occidente de México (tarascos y coras)', 'Pueblos del occidente de México (coras, huicholes y caxcanes)'),
    'valle_mexico': ('Altiplano central (toltecas y chichimecas)', None),
    'epiolmeca': 'Pueblos del Golfo y el Istmo (olmeca-xicalanca y totonacas)',
    'mixteca': 'Mixtecos y zapotecos (Oaxaca)',
    'huasteca': 'Huastecos y pueblos del Pánuco',
    'intermedio_ca': 'Pueblos del Istmo Centroamericano (chibchas y lencas)',
    'antillas_mayores': ('Taínos de las Antillas Mayores', 'Taínos de las Antillas Mayores (cacicazgos)'),
    'saladoides': 'Pueblos de las Antillas Menores (caribes y arahuacos)',
    # ── América del Sur ──
    'muiscas': 'Muiscas (altiplano cundiboyacense)',
    'san_agustin': 'Pueblos del alto Magdalena y Tierradentro',
    'calima_quimbaya': 'Quimbaya, Calima y el Cauca medio',
    'caribe_colombiano': 'Zenúes y tairona del Caribe colombiano',
    'tumaco_tolita': 'Pueblos de la costa del Pacífico (manteños y huancavilcas)',
    'andes_ecuador': ('Pueblos del altiplano ecuatoriano (cañaris y quitus)', None),
    'venezuela_arawak': 'Pueblos arawak del Orinoco y Venezuela',
    'guayanas': 'Pueblos de las Guayanas (caribes y arawak)',
    'moche_salinar': ('Costa norte del Perú (sicán y chimú)', None),
    'recuay_cajamarca': ('Sierra norte del Perú (cajamarca y chachapoyas)', None),
    'lima_costa': ('Costa central del Perú (ychsma)', None),
    'paracas_nazca': ('Costa sur del Perú (ica y chincha)', None),
    'altiplano': ('Altiplano del Titicaca (herederos de Tiahuanaco)', None),
    'amazonia_arawak': 'Pueblos de la Amazonía (arawak, caribe y tupí)',
    'marajoara': 'Pueblos de la isla de Marajó y la costa amazónica',
    'brasil_je': 'Pueblos jê y del Brasil central',
    'tupi_costa': 'Tupíes de la costa atlántica',
    'chaco_guarani': 'Pueblos del Chaco y guaraníes',
    'noa_diaguita': ('Diaguitas y pueblos del noroeste argentino', None),
    'atacama_chile': ('Atacameños y pueblos del norte de Chile', None),
    'mapuche': 'Mapuches y pueblos del sur de Chile',
    'pampa_patagonia': 'Cazadores de la Pampa y la Patagonia',
    'fuego': 'Pueblos de Tierra del Fuego (selknam, yagán y kawésqar)',
}

# factor de población respecto al año 1 por región (continente y, para Asia, subregión): (1096, 1500)
FACTOR = {'América del Norte': (1.8, 2.6), 'América del Sur': (1.8, 2.6), 'África': (1.6, 2.0), 'Oceanía': (1.3, 1.5), 'Europa': (1.5, 2.0),
          'Asia': (1.5, 2.0), 'Asia_sudeste': (1.8, 3.0), 'Siberia': (1.2, 1.4)}
SIBERIA = {'dingling', 'baikal', 'sargat', 'uralicos_sib', 'evenkis', 'paleosiberianos', 'amur', 'ainu', 'sami', 'artico', 'subartico', 'aleutianos', 'alaska_int'}
SUDESTE = {'mon', 'lao_thai', 'malayos', 'java_bali', 'borneo', 'celebes', 'filipinas', 'taiwan'}
# claves de pueblos de los que se suprime (pocas) o se deja a mano la población: clave -> (pob 1096, pob 1500) en miles
POB_FIJA = {'valle_mexico': (1200, 0), 'hopewell': (900, 700), 'muiscas': (400, 900), 'antillas_mayores': (150, 350)}


def lista(anio):
    """[(clave, nombre, factor de población)] de los pueblos que existen en `anio` (1096 o 1500)."""
    k = 0 if anio == 1096 else 1
    out = []
    for clave, v in PUEBLOS_MED.items():
        nombre = v[k] if isinstance(v, tuple) else v
        if nombre is None:
            continue
        reg = 'Siberia' if clave in SIBERIA else 'Asia_sudeste' if clave in SUDESTE else None
        out.append((clave, nombre, FACTOR[reg or '_cont'][k] if reg else None))
    return out
