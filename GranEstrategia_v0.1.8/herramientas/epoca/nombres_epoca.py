"""
nombres_epoca.py — Nombres de mandos del escenario «año 1 d. C.».

Parte de datos/nombres_cultura.json (las culturas de hoy: griego, persa, india, japonés...) y le AÑADE culturas de la época
(latina, han, parta, celta, germánica, tracia, escita, xiongnu, bereber, mesoamericana, andina, etc.) y el reparto de cada
nación a su cultura. Los nombres son ejemplos verosímiles, no personas concretas.
"""
import json
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(os.path.dirname(os.path.dirname(AQUI)), 'datos')

NUEVAS = {
    'latino': ('Latina (Roma)', 'nombre_apellido',
               'Gayo Marco Lucio Quinto Publio Tito Aulo Cneo Sexto Décimo Manio Servio Tiberio Apio Espurio Numerio Vibio Cayo Fabio Opio Mamerco Lucano'.split(),
               'Cornelio Valerio Claudio Fabio Julio Domicio Emilio Pompeyo Sempronio Casio Licinio Calpurnio Pisón Escipión Metelo Craso Léntulo Nerón Agripa Druso Germánico Saturnino Rufo Flaco Bruto Varrón Sila Vitelio'.split()),
    'han': ('Han (China)', 'apellido_nombre',
            'Bing Guang Zhong Ji Shu Fu Yi Cheng Ping Qing Yan Rong Kang Wu Jian Hong Long Hui Min Tai Wen Xiang Yuan Zhi'.split(),
            'Liu Wang Li Zhang Zhao Huo Wei Chen Ban Ma Dou Deng Geng Guo Zhou Yang Sun Xu Lü Cao Gongsun Xiao Zhu Fan'.split()),
    'tibetano': ('Tibetana y qiang', 'nombre_apellido',
                 'Tenzin Dorje Tashi Sonam Namgyal Pema Lobsang Karma Jigme Rinchen Gyaltsen Wangchuk Drakpa Lhundup'.split(),
                 'Dorje Gyatso Tsering Namgyal Wangdu Phuntsok Rabten Chodak Sherab Norbu Tobgyal Lhakpa'.split()),
    'parto': ('Parta (Irán)', 'nombre_apellido',
              'Mitrídates Artabano Orodes Fraates Gotarces Vologases Sinatruces Tiridates Pacoro Bahram Arsaces Vardanes Bagasis Atrapates Sanabares Gafarnes Darío Ardashir Mihrdat Narsés'.split(),
              'Surena Karen Mihrán Suren Espandiar Andegan Varaz Arsácida Gev Aspahbed Zik Kamsarakán'.split()),
    'helenico': ('Helenística', 'nombre_apellido',
                 'Alejandro Demetrio Nicanor Apolodoro Filipo Menandro Zoilo Teodoro Hermeo Arquebio Antíoco Seleuco Ptolomeo Dionisio Heraclides Lisias Antímaco Eucrátides Diomedes Teófilo'.split(),
                 ['de Atenas', 'de Rodas', 'de Tarso', 'de Antioquía', 'de Pérgamo', 'de Mileto', 'de Éfeso', 'de Corinto', 'de Tesalónica', 'de Esmirna', 'de Sinope', 'de Panticapea']),
    'celta': ('Celta', 'nombre_apellido',
              'Cunobelino Casivelauno Dumnórix Orgetórix Cingetórix Ambiórix Casticos Verica Tincomaro Dubnovelauno Comio Boduoc Venutio Cogidubno Togodumno Carataco Prasútago Brenno Epilo Uxelo'.split(),
              'Cunobelino Tasciovano Epatico Segovax Cingeto Esico Vodio Verulamio Nemeto Brigante Tarano Esus Belenos Cernuno Teutates'.split()),
    'germanico': ('Germánica', 'nombre_apellido',
                  'Arminio Marbod Segestes Inguiomero Cruptorix Boiocalo Ariovisto Gannasco Catumero Italico Vannio Vibilio Actumero Flavo Segimero Maroboduo Ucromero Adgandestrio'.split(),
                  'Segimundo Sigimero Hermann Thiudareiks Ansgar Wulfila Radagaiso Gunderico Hildebrando Ragnar Alboino Odoacro'.split()),
    'tracio': ('Tracia, dacia e ilíria', 'nombre_apellido',
               'Burebista Decébalo Deceneo Comosico Rolo Dromiquetes Cotys Remétalces Sitalces Teres Seutes Rescuporis Biteo Batón Pines Dicón Escorilo Dapix Zalmoxis Tarbus'.split(),
               'Cotyes Odrisio Geta Daco Dardano Peonio Tribalo Besio Panonio Dálmata Misio Triballo'.split()),
    'iberico': ('Íbera y lusitana', 'nombre_apellido',
                'Viriato Indíbil Mandonio Corbis Orisón Edecón Istolacio Retógenes Ambón Cauno Megara Tangino Olónico Audax Minuro'.split(),
                'Lusitano Celtíbero Cántabro Astur Vascón Turdetano Vacceo Oretano Edetano Ilergete Carpetano Galaico'.split()),
    'escita': ('Escita y sármata', 'nombre_apellido',
               'Ateas Escilúrides Palaco Sauromates Gatalo Farzoios Inismeo Aspurgo Zagaro Kamasarye Tanais Rescuporis Medosaco Sirmax Eubiotos Abeacos'.split(),
               'Aorsi Siraco Yázige Roxolano Alano Masageta Saka Sauromata Dahae Apasiaco Tocario'.split()),
    'xiongnu': ('Xiongnu y nómadas de la estepa', 'nombre_apellido',
                'Modu Laoshang Junchen Wuzhuliu Huhanye Zhizhi Huduershi Wulei Xulüquanqu Qiedihou Wuzhuleihou Xubu Tuqi Bogu Hulugu Yizhixie'.split(),
                'Luandi Huyan Lanshi Xubu Qiulin Chanyu Tuge Hunye Xiutu Rizhu'.split()),
    'bereber': ('Bereber y númida', 'nombre_apellido',
                'Masinisa Jugurta Boco Juba Sifax Tacfarinas Bogud Micipsa Adherbal Hiempsal Mastanabal Gauda Capusa Ptolomeo Aedemón Gala'.split(),
                'Numida Mauro Getulo Gárama Libio Masilio Masesilio Zegrenses Musulamio Nasamón'.split()),
    'nubio': ('Kushita (Nubia)', 'nombre_apellido',
              'Natakamani Teriteqas Arakamani Adikhalamani Shanakdakhete Amanikhabale Arnekhamani Tanyidamani Netekamani Aqrakamani Taharqo Piye'.split(),
              ['de Meroe', 'de Napata', 'de Kerma', 'de Musawwarat', 'de Naqa', 'de Basa']),
    'mesoamericano': ('Mesoamericana', 'nombre_apellido',
                      'Cipactli Ehécatl Calli Cuetzpalin Coatl Miquiztli Mazatl Tochtli Atl Itzcuintli Ozomatli Acatl Ocelotl Cuauhtli Ollin Tecpatl Balam Chaac Kan Itzam Yax Hun Ahau Muwaan'.split(),
                      'Tecuhtli Tlacatl Ahau Batab Nacom Kalomte Ajaw Ajkin Yaotl Tlatoani Cacique Halach'.split()),
    'andino': ('Andina', 'nombre_apellido',
               'Apu Sinchi Inti Amaru Kuntur Wayra Illapa Pacha Mallku Tupac Waman Puma Atoq Ayar Wari Kusi Yupa Rumi Sayri Atawalpa'.split(),
               'Qhapaq Yupanqui Rimac Mamani Condori Quispe Huanca Mayta Chuqui Apaza Sillu Ayma'.split()),
    'selva': ('Pueblos de la selva y las costas tropicales', 'nombre_apellido',
              'Aimberê Cunhambebe Araribóia Tibiriçá Jaguaretê Ubirajara Itaquí Poti Arapuã Guaraci Yara Tupã Abaeté Ibirapitanga Cauã Anhangá'.split(),
              'Guaçu Mirim Una Pitanga Tuiuiú Piraña Jaguar Karajá Tupinambá Arawak Wayúu Chibcha Tairona'.split()),
    'naturaleza': ('Pueblos cazadores y recolectores (nombres traducidos)', 'nombre_apellido',
                   'Águila Lobo Oso Búho Ciervo Halcón Nutria Castor Cuervo Bisonte Coyote Alce Zorro Salmón Garza Tejón Ardilla Foca'.split(),
                   ['Veloz', 'Gris', 'Rojo', 'Silencioso', 'del Río', 'Blanco', 'Negro', 'del Alba', 'Alto', 'Bravo', 'Sabio', 'del Norte', 'del Bosque', 'de la Costa']),
}

# nombre de cultura de HOY que ya existe y vale para la época (griego, persa, india, japonés, coreano...)
POR_CLAVE = {
    'Roman Empire': 'latino', 'Han Dynasty': 'han', 'Parthian Empire': 'parto', 'Xiongnu': 'xiongnu', 'Satavahana Dynasty': 'india',
    'Indo-Scythians': 'escita', 'Indo-Parthians': 'parto', 'Indo-Greeks': 'helenico', 'Yuezhi': 'escita', 'Wusun': 'xiongnu',
    'Great Yuan': 'escita', 'Kingdom of Kush': 'nubio', 'Kingdom of Axum': 'etiope', 'Himyarite Kingdom': 'arabe', 'Hadhramaut': 'arabe',
    'Nabataeans': 'arabe', 'Judea': 'hebreo', 'Kingdom of Pontus': 'helenico', 'Kingdom of Cappadocia': 'helenico', 'Kingdom of Armenia': 'armenio',
    'Kingdom of Commagene': 'helenico', 'Kingdom of Sophene': 'armenio', 'Kingdom of Gordyene': 'armenio', 'Kingdom of Osroene': 'arabe',
    'Kingdom of Adiabene': 'parto', 'Caucasian Iberia': 'georgiano', 'Caucasian Albania': 'georgiano', 'Lazica': 'georgiano',
    'Cimmerian Bosporus': 'helenico', 'Thracian Kingdom': 'tracio', 'Greek City-States': 'helenico', 'Mauretania': 'bereber',
    'Anurādhapura': 'india', 'Early Cholas': 'india', 'Early Pandyas': 'india', 'Early Cheras': 'india', 'Mayan City-States': 'mesoamericano',
    'Zapotec Civilization': 'mesoamericano', 'Teotihuacan': 'mesoamericano', 'Goguryeo': 'coreano', 'Dongye': 'coreano',
    'Dong-okjeo': 'coreano', 'Mahan': 'coreano', 'Jinhan': 'coreano', 'Byeonhan': 'coreano',
    # pueblos
    'caledonios': 'celta', 'britones_norte': 'celta', 'brigantes': 'celta', 'catuvelaunos': 'celta', 'britones_oeste': 'celta', 'dumnonios': 'celta',
    'hibernios': 'celta', 'frisios': 'germanico', 'queruscos': 'germanico', 'suevos_elba': 'germanico', 'marcomanos': 'germanico', 'lugios': 'germanico',
    'godos': 'germanico', 'daneses': 'germanico', 'gautas': 'germanico', 'suiones': 'germanico', 'noruegos': 'germanico', 'sami': 'fines',
    'fineses': 'fines', 'balticos': 'baltico', 'venedos': 'eslavo_occidental', 'bastarnas': 'germanico', 'dacios': 'tracio', 'sarmatas': 'escita',
    'finougrios': 'fines', 'guanches': 'bereber', 'getulos': 'bereber', 'garamantes': 'bereber', 'blemios': 'nubio', 'nubios': 'nubio',
    'cuerno': 'etiope', 'sahel_occ': 'africa_occidental', 'nok': 'africa_occidental', 'sao': 'africa_central', 'guinea': 'africa_occidental',
    'africa_central_n': 'africa_central', 'bantu_occ': 'africa_central', 'bantu_orient': 'africa_oriental', 'bantu_costa': 'africa_oriental',
    'bantu_sur': 'africa_austral', 'khoisan': 'africa_austral', 'arabes_centro': 'arabe', 'golfo_omani': 'arabe', 'caracena': 'arabe',
    'pueblos_taurus': 'helenico', 'kangju': 'escita', 'corasmia': 'escita', 'masagetas': 'escita', 'saka_pamir': 'escita', 'tarim': 'escita',
    'qiang': 'tibetano', 'xianbei': 'xiongnu', 'buyeo': 'coreano', 'amur': 'naturaleza', 'dingling': 'xiongnu', 'baikal': 'xiongnu',
    'sargat': 'escita', 'uralicos_sib': 'naturaleza', 'evenkis': 'naturaleza', 'paleosiberianos': 'naturaleza',
    'ganges': 'india', 'magadha': 'india', 'kalinga': 'india', 'panyab_rajastan': 'india', 'malwa_gujarat': 'india', 'himalaya': 'tibetano',
    'adivasi': 'india', 'assam': 'india', 'baluchis': 'persa', 'pyu': 'birmano', 'mon': 'birmano', 'dian': 'han', 'lao_thai': 'tailandes',
    'funan': 'jemer', 'sa_huynh': 'vietnamita', 'vietnam_norte': 'vietnamita', 'malayos': 'malayo', 'java_bali': 'malayo', 'borneo': 'malayo',
    'celebes': 'malayo', 'filipinas': 'filipino', 'taiwan': 'malayo', 'wa': 'japones', 'yayoi_este': 'japones', 'emishi': 'naturaleza', 'ainu': 'naturaleza',
    'ryukyu': 'japones', 'tasmania': 'naturaleza', 'papues_altos': 'polinesio', 'papues_costa': 'polinesio', 'melanesia': 'polinesio',
    'fiji_polinesia': 'polinesio', 'micronesia': 'polinesio', 'antillas_mayores': 'selva', 'saladoides': 'selva',
}


def cultura_por_defecto(e):
    c = e.get('cont')
    clave = e['clave']
    if clave.startswith('abo_'):
        return 'naturaleza'
    if c == 'América del Norte':
        lon, lat = e['centro']
        return 'mesoamericano' if lat < 22 and lon < -85 or clave in ('valle_mexico', 'epiolmeca', 'mixteca', 'huasteca', 'occidente_mx') else 'naturaleza'
    if c == 'América del Sur':
        lon, lat = e['centro']
        return 'andino' if lon < -66 and lat > -36 else 'selva'
    if c == 'Oceanía':
        return 'polinesio'
    if c == 'Europa':
        return 'germanico'
    if c == 'África':
        return 'africa_central'
    return 'naturaleza'


def escribir_nombres(build, ents, paises):
    js = json.load(open(os.path.join(BASE, 'nombres_cultura.json'), encoding='utf-8'))
    for cid, (nombre, orden, nombres, apell) in NUEVAS.items():
        js['culturas'][cid] = {'nombre': nombre, 'orden': orden, 'nombres': nombres, 'apellidos': apell}
    js['paises'] = {}
    for e in ents:
        js['paises'][e['nombre']] = POR_CLAVE.get(e['clave']) or cultura_por_defecto(e)
    for n, d in paises.items():
        if d.get('sin_reclamar'):
            continue
        js['paises'].setdefault(n, 'naturaleza')
    js['defecto_continente'] = dict(js.get('defecto_continente', {}), **{'América del Norte': 'naturaleza', 'América del Sur': 'selva', 'Europa': 'germanico',
                                                                         'Oceanía': 'polinesio', 'África': 'africa_central', 'Asia': 'india'})
    for k, v in js['paises'].items():
        assert v in js['culturas'], (k, v)
    js['version'] = '1dc-0.1.8.34'
    js['ayuda'] = js.get('ayuda', '') + ' · Escenario año 1 d. C.: añade culturas de la época (latina, han, parta, celta, germánica...) y reparte las naciones antiguas entre ellas.'
    json.dump(js, open(os.path.join(build, 'nombres_cultura.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
