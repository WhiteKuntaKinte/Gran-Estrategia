# -*- coding: utf-8 -*-
"""
Épocas 1096 (Primera Cruzada) y 1500 (Renacimiento) — ESTADOS y sus datos de juego.

Los TERRITORIOS salen de Cliopatria v0.2.1 (Seshat Global History Databank, CC BY 4.0), ver fuentes/cliopatria_1096.json y cliopatria_1500.json
(se sacan con extraer_cliopatria.py). Aquí va todo lo demás: nombre en español, tipo, continente, población (en MILES de habitantes), capital,
moneda y división interior. Las cifras de población son estimaciones de orden de magnitud (McEvedy y Jones, Maddison, Livi-Bacci y el consenso
historiográfico); NO son datos exactos. Los estados de Cliopatria que no tienen ficha aquí no entran en el juego (sus tierras las toman los vecinos o quedan sin reclamar).

Formato de cada ficha:  clave de Cliopatria -> dict(nombre, tipo, cont, pob (miles), cap=(ciudad, lon, lat), moneda, div, pib_pc, etn=[(grupo, %)])
Se escribe con la función F(...) (más corta). `pib_pc` = US$ de referencia por habitante y año; `etn` por defecto = un solo grupo con el nombre del pueblo.
"""

EP = (1096, 1500)
ESTADOS = {1096: {}, 1500: {}}

# Monedas de las dos épocas: código -> (nombre, símbolo, unidades por US$ de referencia). Orden de magnitud, no cotizaciones reales.
DIVISAS = {
    'DIN': ('Dinar de oro islámico', 'dn', 0.0050), 'DIR': ('Dírhem de plata', 'dh', 0.12), 'BEZ': ('Besante bizantino', 'bz', 0.0065),
    'DEN': ('Denario (penique) de plata', 'd', 1.0), 'WEN': ('Moneda de cobre (wen)', 'wn', 18.0), 'GRV': ('Grivna rusa de plata', 'gr', 0.045),
    'GAD': ('Gadyana de oro', 'gd', 0.012), 'DRM': ('Dramma de plata', 'dm', 0.35), 'TRQ': ('Trueque (ganado, sal, tejidos)', 'tr', 1.0),
    'COW': ('Cauríes', 'cw', 400.0), 'TIB': ('Polvo de oro (tibar)', 'tb', 0.02), 'AMO': ('Barras de sal (amole)', 'am', 60.0),
    'MRV': ('Maravedí', 'mv', 0.0050), 'CAC': ('Granos de cacao', 'ca', 300.0), 'MAS': ('Masa de oro javanesa', 'ms', 0.05),
    'TAE': ('Tael de plata', 'tl', 0.030), 'AKC': ('Akçe otomano', 'ak', 8.0), 'ASH': ('Ashrafí de oro', 'as', 0.0045),
    'TNK': ('Tanka de plata', 'tk', 0.3), 'PAG': ('Pagoda (varaha) de oro', 'pg', 0.014), 'DGA': ('Denga rusa', 'dg', 6.0),
    'DUC': ('Ducado de oro', 'dc', 0.0075), 'FLO': ('Florín de oro', 'fl', 0.0075), 'GRO': ('Grosz de plata', 'gz', 1.2),
    'GUL': ('Gulden renano de oro', 'gu', 0.0075), 'ECU': ('Escudo de oro', 'es', 0.0075), 'REA': ('Real de plata', 'rl', 0.06),
    'PNY': ('Penique inglés', 'p', 1.0), 'CRU': ('Cruzado de oro', 'cz', 0.0070), 'NZI': ('Conchas nzimbu', 'nz', 25.0),
}

# pib_pc por defecto de cada época (US$ de referencia por habitante y año) y multiplicador por tipo
PIB_DEF = {1096: 700, 1500: 800}
PIB_TIPO = {'confederación nómada': 0.65, 'khanato': 0.7, 'ciudades-estado': 1.2, 'república': 1.35, 'imperio': 1.05, 'cultura': 0.7, 'tribus': 0.6}
DIV_DEF = {'imperio': 'Provincias', 'reino': 'Provincias', 'sultanato': 'Emiratos', 'califato': 'Provincias', 'emirato': 'Distritos', 'khanato': 'Territorios',
           'confederación nómada': 'Territorios', 'república': 'Territorios', 'principado': 'Principados', 'ducado': 'Condados', 'condado': 'Señoríos',
           'cultura': 'Ciudades', 'ciudades-estado': 'Ciudades', 'taifa': 'Distritos', 'electorado': 'Territorios'}


def F(ep, clave, nombre, tipo, cont, pob, cap, mon, pib=None, div=None, etn=None):
    d = dict(nombre=nombre, tipo=tipo, cont=cont, pob=pob, cap=cap, moneda=mon)
    d['pib_pc'] = int((pib if pib else PIB_DEF[ep] * PIB_TIPO.get(tipo, 1.0)))
    d['div'] = div or DIV_DEF.get(tipo, 'Provincias')
    d['etn'] = etn or [(nombre, 100)]
    ESTADOS[ep][clave] = d


A, E_, AF, AN, AS, OC = 'Asia', 'Europa', 'África', 'América del Norte', 'América del Sur', 'Oceanía'

# ═══════════════════════════ 1096 ═══════════════════════════
F96 = lambda *a, **k: F(1096, *a, **k)
# ── Asia ──
F96('Great Seljuk Empire', 'Gran Imperio selyúcida', 'imperio', A, 22000, ('Isfahán', 51.67, 32.65), 'DIN', pib=900, div='Provincias',
    etn=[('Persas e iranios', 45), ('Árabes y mesopotámicos', 25), ('Turcos oguz', 15), ('Kurdos, armenios y otros', 15)])
F96('Kimek-Kipchak confederation', 'Confederación kimek-kipchak', 'confederación nómada', A, 2500, ('Imekia', 70.0, 52.0), 'TRQ')
F96('Northern Song', 'Dinastía Song del Norte', 'imperio', A, 104000, ('Kaifeng', 114.35, 34.80), 'WEN', pib=1100, div='Circuitos',
    etn=[('Han', 95), ('Pueblos del sur y minorías', 5)])
F96('Liao Dynasty', 'Dinastía Liao (kitán)', 'imperio', A, 7500, ('Linhuang (Capital Suprema)', 119.0, 43.97), 'WEN', div='Circuitos',
    etn=[('Han', 50), ('Kitán', 30), ('Bohai y otros', 20)])
F96('Tibetans', 'Reinos tibetanos', 'reino', A, 3000, ('Lhasa', 91.12, 29.65), 'TRQ')
F96('Ghaznavid Empire', 'Imperio gaznávida', 'imperio', A, 8000, ('Gazni', 68.25, 33.55), 'DIR', pib=850,
    etn=[('Iranios y afganos', 55), ('Panyabíes y sindhíes', 35), ('Turcos', 10)])
F96('Eastern Kara-Khanids', 'Janato karajánida oriental', 'khanato', A, 2500, ('Kashgar', 76.0, 39.47), 'DIR', pib=800)
F96('Qocho Kingdom', 'Reino uigur de Qocho', 'reino', A, 1000, ('Qocho (Gaochang)', 89.53, 42.85), 'TRQ')
F96('Western Chalukya Empire', 'Imperio chalukya occidental', 'imperio', A, 14000, ('Kalyani', 76.95, 17.88), 'GAD', div='Mandalas')
F96('Khwarezmid Dynasty', 'Dinastía joremsiana', 'reino', A, 2500, ('Gurganj', 59.15, 42.32), 'DIR')
F96('Srivijaya', 'Imperio de Srivijaya', 'imperio', A, 2500, ('Palembang', 104.76, -2.98), 'MAS', pib=850)
F96('Western Xia', 'Xia Occidental (tangut)', 'imperio', A, 3000, ('Xingqing (Yinchuan)', 106.23, 38.49), 'WEN', div='Prefecturas')
F96('Pagan Kingdom', 'Reino de Pagan', 'reino', A, 3500, ('Pagan', 94.86, 21.17), 'TRQ')
F96('Yenisei Kyrgyz', 'Kirguises del Yeniséi', 'confederación nómada', A, 400, ('Kemijkent', 91.5, 53.5), 'TRQ')
F96('Halych-Volhynia occupation', 'Tierras de los cumanos (estepa póntica)', 'confederación nómada', E_, 1500, ('Sharukan', 37.0, 49.0), 'TRQ')
F96('Khmer Empire', 'Imperio jemer', 'imperio', A, 4500, ('Angkor (Yasodharapura)', 103.86, 13.43), 'TRQ', pib=800)
F96('Chola Empire', 'Imperio chola', 'imperio', A, 15000, ('Gangaikonda Cholapuram', 79.45, 11.21), 'GAD', pib=850, div='Mandalams')
F96('Sultanate of Rum', 'Sultanato de Rum', 'sultanato', A, 4000, ('Nicea (Iznik)', 29.72, 40.43), 'DIR')
F96('Kingdom of Dali', 'Reino de Dali', 'reino', A, 3500, ('Dali', 100.16, 25.69), 'COW')
F96('Sena Dynasty', 'Dinastía Sena (Bengala)', 'reino', A, 8000, ('Vijayapura (Nabadwip)', 88.37, 23.40), 'COW', div='Bhuktis')
F96('Heian Japan', 'Japón Heian', 'imperio', A, 7000, ('Heian-kyō (Kioto)', 135.77, 35.01), 'WEN', div='Provincias (kuni)')
F96('Hamdanid Emirates', 'Emiratos de la Alta Mesopotamia', 'emirato', A, 2500, ('Alepo', 37.16, 36.20), 'DIN')
F96('Sind-Habbari Dynasty', 'Emirato habárida de Sind', 'emirato', A, 2500, ('Mansura', 68.77, 25.87), 'DIR')
F96('Lohara Dynasty', 'Reino de Cachemira (dinastía Lohara)', 'reino', A, 2500, ('Srinagar (Pravarapura)', 74.80, 34.08), 'DRM')
F96('Kashmir', 'Valle de Cachemira', 'reino', A, 900, ('Anantnag', 75.15, 33.73), 'DRM')
F96('Gahadavala Dynasty', 'Dinastía Gahadavala', 'reino', A, 10000, ('Kannauj', 79.92, 27.06), 'DRM', div='Mandalas')
F96('Najahid Dynasty', 'Emirato najáhida (Yemen)', 'emirato', A, 2000, ('Zabid', 43.31, 14.20), 'DIN')
F96('Paramara Dynasty', 'Dinastía Paramara (Malwa)', 'reino', A, 6000, ('Dhara', 75.50, 22.60), 'DRM', div='Mandalas')
F96('Chaulukya Dynasty', 'Dinastía chaulukya (Gujarat)', 'reino', A, 5000, ('Anahilapataka (Patan)', 72.11, 23.85), 'DRM', div='Mandalas')
F96('Kamarupa Kingdom', 'Reino de Kamarupa', 'reino', A, 1500, ('Kamarupanagara (Guwahati)', 91.75, 26.18), 'COW')
F96('Eastern Ganga Kingdom', 'Gangas orientales (Kalinga)', 'reino', A, 4000, ('Kalinganagara', 84.12, 18.52), 'GAD', div='Mandalas')
F96('Chauhan Dynasty', 'Dinastía chauhan (Sakambhari)', 'reino', A, 4000, ('Ajmer', 74.64, 26.45), 'DRM', div='Mandalas')
F96('Goryeo', 'Goryeo', 'reino', A, 3500, ('Gaegyeong (Kaesong)', 126.56, 37.97), 'WEN', div='Provincias (do)')
F96('Haripuñjaya', 'Reino de Haripuñjaya', 'reino', A, 700, ('Lamphun', 99.01, 18.57), 'TRQ')
F96('Lavo Kingdom', 'Reino de Lavo', 'reino', A, 800, ('Lopburi', 100.62, 14.80), 'TRQ')
F96('Ngô Dynasty', 'Đại Việt (dinastía Lý)', 'reino', A, 2000, ('Thăng Long (Hanói)', 105.85, 21.03), 'WEN')
F96('Chámpa', 'Champa', 'reino', A, 1000, ('Vijaya (Quy Nhon)', 109.20, 13.88), 'TRQ')
F96('Pala Empire', 'Imperio pala', 'imperio', A, 9000, ('Ramavati', 88.13, 25.00), 'DRM', div='Bhuktis')
F96('Kingdom of Polonnaruwa', 'Reino de Polonnaruwa', 'reino', A, 1000, ('Polonnaruwa', 81.00, 7.94), 'GAD')
F96('Uyunid Emirate', 'Emirato uyúnida (Bahréin)', 'emirato', A, 400, ('Al-Hasa', 49.59, 25.38), 'DIN')
F96('Sunda Kingdom', 'Reino de Sunda', 'reino', A, 800, ('Pakuan', 106.80, -6.60), 'MAS')
F96('Danishmendids', 'Emirato danishmendí', 'emirato', A, 1200, ('Sebaste (Sivas)', 37.02, 39.75), 'DIR')
F96('Chandela Kingdom', 'Reino chandela', 'reino', A, 3000, ('Khajuraho', 79.92, 24.85), 'DRM', div='Mandalas')
F96('Kediri Kingdom', 'Reino de Kediri', 'reino', A, 2500, ('Daha (Kediri)', 112.02, -7.82), 'MAS')
F96('Kingdom of Janggala', 'Reino de Janggala', 'reino', A, 1200, ('Kahuripan', 112.65, -7.50), 'MAS')
F96('Early Balinese Kingdoms', 'Reinos de Bali', 'reino', A, 500, ('Bedulu (Pejeng)', 115.31, -8.52), 'MAS')
F96('Kingdom of Georgia', 'Reino de Georgia', 'reino', A, 1200, ('Kutaisi', 42.70, 42.27), 'DIR')
F96('Volga Bulgaria', 'Bulgaria del Volga', 'reino', E_, 600, ('Bolgar', 49.05, 54.97), 'DIR')
F96('Northern Fujiwara', 'Fujiwara del Norte (Hiraizumi)', 'reino', A, 900, ('Hiraizumi', 141.11, 38.99), 'WEN')
# ── África ──
F96('Almoravid Dynasty', 'Imperio almorávide', 'imperio', AF, 8000, ('Marrakech', -7.99, 31.63), 'DIN', pib=850, div='Provincias',
    etn=[('Bereberes', 55), ('Andalusíes', 25), ('Árabes y otros', 20)])
F96('Fatimid Caliphate', 'Califato fatimí', 'califato', AF, 6500, ('El Cairo', 31.25, 30.05), 'DIN', pib=900,
    etn=[('Egipcios', 60), ('Árabes y levantinos', 25), ('Bereberes, nubios y otros', 15)])
F96('Makuria', 'Reino de Makuria', 'reino', AF, 1500, ('Dongola', 30.48, 19.17), 'TRQ')
F96('Ghana Empire', 'Imperio de Ghana', 'imperio', AF, 2500, ('Kumbi Saleh', -7.80, 15.80), 'TIB', pib=650)
F96('Alodia', 'Reino de Alodia', 'reino', AF, 1200, ('Soba', 32.70, 15.50), 'TRQ')
F96('Takrur', 'Reino de Takrur', 'reino', AF, 600, ('Podor', -14.96, 16.65), 'TIB')
F96('Hammadid Dynasty', 'Dinastía hamádida', 'emirato', AF, 900, ('Bugía (Bejaia)', 5.08, 36.75), 'DIN')
F96('Zirid dynasty', 'Dinastía zirí (Ifriqiya)', 'emirato', AF, 1800, ('Mahdía', 11.06, 35.50), 'DIN')
F96('Empire of Kanem', 'Imperio de Kanem', 'imperio', AF, 1500, ('Njimi', 15.0, 14.3), 'COW')
F96('Zagwe dynasty', 'Dinastía Zagüe', 'reino', AF, 2500, ('Roha (Lalibela)', 39.04, 12.03), 'AMO', pib=500)
# ── América del Norte ──
F96('Later Mayan City-States', 'Ciudades-estado mayas', 'ciudades-estado', AN, 1500, ('Chichén Itzá', -88.57, 20.68), 'CAC')
F96('Puebloans - Chaco Regional System', 'Sistema regional del Cañón del Chaco', 'cultura', AN, 150, ('Cañón del Chaco', -107.96, 36.06), 'TRQ')
F96('Classic Veracruz Culture', 'Cultura del Veracruz clásico (totonacas)', 'cultura', AN, 600, ('El Tajín', -97.38, 20.45), 'CAC')
F96('Norse Greenland', 'Groenlandia nórdica', 'reino', AN, 3, ('Gardar', -45.40, 61.00), 'TRQ')
# ── Europa ──
F96('Kievan Rus\'', 'Rus de Kiev (tierras de los rúrikidas)', 'principado', E_, 6000, ('Kiev', 30.52, 50.45), 'GRV', pib=600)
F96('Holy Roman Empire', 'Sacro Imperio Romano Germánico', 'imperio', E_, 11000, ('Aquisgrán', 6.08, 50.78), 'DEN', pib=750, div='Ducados',
    etn=[('Alemanes', 55), ('Italianos del norte', 25), ('Eslavos y borgoñones', 20)])
F96('Byzantine Empire', 'Imperio bizantino', 'imperio', E_, 9000, ('Constantinopla', 28.98, 41.01), 'BEZ', pib=950, div='Themas',
    etn=[('Griegos', 60), ('Eslavos y balcánicos', 25), ('Armenios y otros', 15)])
F96('Novgorod Republic', 'República de Nóvgorod', 'república', E_, 1000, ('Nóvgorod', 31.27, 58.52), 'GRV')
F96('Kingdom of Hungary', 'Reino de Hungría', 'reino', E_, 1700, ('Esztergom', 18.74, 47.79), 'DEN', div='Condados')
F96('Old Kingdom of Norway', 'Reino de Noruega', 'reino', E_, 400, ('Nidaros (Trondheim)', 10.40, 63.43), 'DEN')
F96('Kingdom of Castile', 'Reino de Castilla y León', 'reino', E_, 2200, ('Toledo', -4.02, 39.86), 'MRV', div='Merindades')
F96('Kingdom of Poland', 'Reino de Polonia', 'reino', E_, 1500, ('Gniezno', 17.58, 52.53), 'DEN', div='Castellanías')
F96('Principality of Chernigov', 'Principado de Chernígov', 'principado', E_, 700, ('Chernígov', 31.30, 51.50), 'GRV')
F96('Norman England', 'Inglaterra normanda', 'reino', E_, 2200, ('Londres', -0.13, 51.51), 'DEN', pib=800, div='Condados')
F96('Principality of Rostov-Suzdal', 'Principado de Rostov-Súzdal', 'principado', E_, 600, ('Súzdal', 40.43, 56.43), 'GRV')
F96('Principality of Kiev', 'Principado de Kiev', 'principado', E_, 900, ('Kiev', 30.52, 50.45), 'GRV')
F96('Kingdom of Sweden', 'Reino de Suecia', 'reino', E_, 500, ('Sigtuna', 17.72, 59.62), 'DEN')
F96('Duchy of Aquitaine', 'Ducado de Aquitania', 'ducado', E_, 2200, ('Poitiers', 0.34, 46.58), 'DEN', pib=800)
F96('Principality of Polotsky', 'Principado de Pólotsk', 'principado', E_, 300, ('Pólotsk', 28.79, 55.49), 'GRV')
F96('Principality of Smolensk', 'Principado de Smolensk', 'principado', E_, 300, ('Smolensk', 32.05, 54.78), 'GRV')
F96('Icelandic Commonwealth', 'Mancomunidad islandesa', 'república', E_, 70, ('Þingvellir', -21.12, 64.26), 'TRQ')
F96('Principality of Pereyaslavl', 'Principado de Pereyáslav', 'principado', E_, 250, ('Pereyáslav', 31.45, 50.07), 'GRV')
F96('Kingdom of Denmark', 'Reino de Dinamarca', 'reino', E_, 800, ('Roskilde', 12.08, 55.64), 'DEN')
F96('Principality of Volhynia', 'Principado de Volinia', 'principado', E_, 300, ('Volodímir', 24.32, 50.85), 'GRV')
F96('Norman Italy', 'Italia normanda (Apulia y Sicilia)', 'ducado', E_, 1700, ('Palermo', 13.36, 38.12), 'DEN', pib=850)
F96('Principality of Ryazan', 'Principado de Riazán', 'principado', E_, 200, ('Riazán', 39.75, 54.63), 'GRV')
F96('Kingdom of Alba', 'Reino de Alba (Escocia)', 'reino', E_, 400, ('Dunfermline', -3.46, 56.07), 'DEN')
F96('Principality of Terebovlia', 'Principado de Terebovlia', 'principado', E_, 150, ('Terebovlia', 25.70, 49.30), 'GRV')
F96('County of Toulouse', 'Condado de Tolosa', 'condado', E_, 800, ('Tolosa', 1.44, 43.60), 'DEN', pib=800)
F96('Principality of Peremyshl', 'Principado de Peremyshl', 'principado', E_, 150, ('Przemyśl', 22.77, 49.78), 'GRV')
F96('Viking settlements', 'Asentamientos nórdicos (Danelaw e islas)', 'reino', E_, 300, ('Dublín', -6.26, 53.35), 'DEN')
F96('Duchy of Brittany', 'Ducado de Bretaña', 'ducado', E_, 600, ('Rennes', -1.68, 48.11), 'DEN')
F96('Kingdom of Croatia', 'Reino de Croacia', 'reino', E_, 300, ('Knin', 16.20, 44.04), 'DEN')
F96('County of Blôis', 'Condado de Blois', 'condado', E_, 600, ('Blois', 1.33, 47.59), 'DEN')
F96('Taifa of Zaragoza', 'Taifa de Zaragoza', 'taifa', E_, 500, ('Zaragoza', -0.88, 41.65), 'DIN', pib=850)
F96('Jaemtland', 'Jämtland', 'reino', E_, 15, ('Frösön', 14.55, 63.19), 'DEN')
F96('County of Champagne', 'Condado de Champaña', 'condado', E_, 700, ('Troyes', 4.08, 48.30), 'DEN', pib=800)
F96('Kingdom of France', 'Reino de Francia (dominio real)', 'reino', E_, 1500, ('París', 2.35, 48.86), 'DEN', pib=800)
F96('Taifa of Dénia', 'Taifa de Denia y Baleares', 'taifa', E_, 300, ('Dénia', 0.11, 38.84), 'DIN')
F96('Grand Principality of Serbia', 'Gran Principado de Serbia (Raška)', 'principado', E_, 300, ('Ras', 20.46, 43.18), 'DEN')
F96('County of Vermandois', 'Condado de Vermandois', 'condado', E_, 400, ('Saint-Quentin', 3.29, 49.85), 'DEN')
F96('Kingdom of Aragon', 'Reino de Aragón', 'reino', E_, 400, ('Jaca', -0.55, 42.57), 'DEN')
F96('Kingdom of Arles', 'Reino de Arlés (Borgoña)', 'reino', E_, 1200, ('Arlés', 4.63, 43.68), 'DEN', pib=800)
F96('County of Flanders', 'Condado de Flandes', 'condado', E_, 400, ('Brujas', 3.22, 51.21), 'DEN', pib=900)
F96('Papal States', 'Estados Pontificios', 'principado', E_, 700, ('Roma', 12.50, 41.89), 'DEN', pib=850)
F96('Kingdom of the Isles', 'Reino de las Islas', 'reino', E_, 80, ('Peel', -4.69, 54.22), 'DEN')
F96('Republic of Pisa', 'República de Pisa', 'república', E_, 250, ('Pisa', 10.40, 43.72), 'DEN')
F96('County of Maine', 'Condado del Maine', 'condado', E_, 300, ('Le Mans', 0.20, 48.00), 'DEN')
F96('County of Anjou', 'Condado de Anjou', 'condado', E_, 400, ('Angers', -0.55, 47.47), 'DEN')
F96('County of Nevers', 'Condado de Nevers', 'condado', E_, 250, ('Nevers', 3.16, 46.99), 'DEN')
F96('Giudicato of Cagliari', 'Judicado de Cagliari', 'condado', E_, 100, ('Cagliari', 9.11, 39.22), 'DEN')
F96('Taifa of Valencia', 'Taifa de Valencia', 'taifa', E_, 300, ('Valencia', -0.38, 39.47), 'DIN')
F96('Taifa of Tortosa', 'Taifa de Tortosa', 'taifa', E_, 120, ('Tortosa', 0.52, 40.81), 'DIN')
F96('Kingdom of Duklja', 'Reino de Duklja', 'reino', E_, 100, ('Skadar', 19.51, 42.05), 'DEN')
F96('Taifa of Albarracín', 'Taifa de Albarracín', 'taifa', E_, 60, ('Albarracín', -1.44, 40.41), 'DIN')
F96('Giudicato of Logudoro', 'Judicado de Logudoro', 'condado', E_, 80, ('Ardara', 8.80, 40.65), 'DEN')
F96('County of Barcelona', 'Condado de Barcelona', 'condado', E_, 250, ('Barcelona', 2.17, 41.39), 'DEN', pib=850)
F96('Republic of Venice', 'República de Venecia', 'república', E_, 300, ('Venecia', 12.34, 45.44), 'DEN', pib=1100)

# ═══════════════════════════ 1500 ═══════════════════════════
F15 = lambda *a, **k: F(1500, *a, **k)
# ── Asia ──
F15('Mongol Khanate', 'Janato mongol oriental (Dayán Kan)', 'khanato', A, 1500, ('Karakórum', 102.84, 47.20), 'TRQ')
F15('Ming Dynasty', 'Dinastía Ming', 'imperio', A, 125000, ('Pekín', 116.40, 39.90), 'TAE', pib=1000, div='Provincias',
    etn=[('Han', 94), ('Mongoles, miao, zhuang y otros', 6)])
F15('Khanate of Sibir', 'Janato de Sibir', 'khanato', A, 120, ('Qashliq (Sibir)', 68.4, 58.2), 'TRQ')
F15('Timurid Empire', 'Imperio timúrida (Jorasán y Transoxiana)', 'imperio', A, 6000, ('Herat', 62.20, 34.34), 'TNK', pib=850,
    etn=[('Persas y tayikos', 55), ('Turcos chagatai', 30), ('Pastunes y otros', 15)])
F15('Kazakh Khanate', 'Janato kazajo', 'khanato', A, 800, ('Sygnak', 68.5, 44.0), 'TRQ')
F15('Aq Qoyunlu', 'Imperio de los Aq Qoyunlu', 'sultanato', A, 8000, ('Tabriz', 46.29, 38.08), 'TNK', pib=850,
    etn=[('Persas e iranios', 45), ('Turcomanos', 20), ('Kurdos y armenios', 20), ('Árabes y otros', 15)])
F15('Tibet', 'Tíbet (Phagmodrupa y Rinpungpa)', 'reino', A, 3000, ('Lhasa', 91.12, 29.65), 'TRQ')
F15('Moghulistan', 'Moguliztán', 'khanato', A, 800, ('Almaliq', 80.7, 44.0), 'TRQ')
F15('Ottoman Empire', 'Imperio otomano', 'imperio', A, 9500, ('Constantinopla', 28.98, 41.01), 'AKC', pib=900, div='Sanjacados',
    etn=[('Turcos', 40), ('Griegos y balcánicos', 35), ('Armenios, kurdos y otros', 25)])
F15('Nogai Horde', 'Horda Nogai', 'confederación nómada', E_, 400, ('Saraichik', 51.7, 47.5), 'TRQ')
F15('Golden Horde', 'Gran Horda', 'khanato', E_, 1500, ('Saray', 46.0, 48.5), 'TRQ')
F15('Vijayanagara Empire', 'Imperio de Vijayanagara', 'imperio', A, 20000, ('Vijayanagara (Hampi)', 76.46, 15.34), 'PAG', pib=850, div='Nadus')
F15('Lodi Dynasty', 'Sultanato de Delhi (dinastía Lodi)', 'sultanato', A, 25000, ('Agra', 78.01, 27.18), 'TNK', pib=800, div='Iqtas')
F15('Shaybanids', 'Janato shaybánida (uzbekos)', 'khanato', A, 2000, ('Bujará', 64.43, 39.77), 'TNK')
F15('Ayutthaya Kingdom', 'Reino de Ayutthaya', 'reino', A, 3500, ('Ayutthaya', 100.56, 14.36), 'COW', pib=750)
F15('Tahirid Sultanate', 'Sultanato tahirí (Yemen)', 'sultanato', A, 2500, ('Rada', 45.26, 14.42), 'DIN')
F15('Lan Xang', 'Reino de Lan Xang', 'reino', A, 1500, ('Luang Prabang', 102.14, 19.89), 'COW')
F15('Sultanate of Bengal', 'Sultanato de Bengala', 'sultanato', A, 12000, ('Gaur', 88.13, 24.87), 'TNK', pib=850)
F15('Warring States Japan', 'Japón (periodo Sengoku)', 'imperio', A, 10000, ('Kioto', 135.77, 35.01), 'WEN', pib=800, div='Provincias (kuni)')
F15('Eastern Chagatai Khanate', 'Janato de Chagatai oriental (Yarkand)', 'khanato', A, 1000, ('Yarkand', 77.24, 38.41), 'TNK')
F15('Khmer Empire', 'Imperio jemer (en declive)', 'imperio', A, 2000, ('Longvek', 104.70, 12.00), 'COW')
F15('Shan States', 'Estados shan', 'reino', A, 1500, ('Mong Mao', 98.6, 24.4), 'COW')
F15('Joseon', 'Joseon', 'reino', A, 7000, ('Hanseong (Seúl)', 126.98, 37.57), 'WEN', pib=800, div='Provincias (do)')
F15('Lê Dynasty', 'Đại Việt (dinastía Lê)', 'reino', A, 4500, ('Thăng Long (Hanói)', 105.85, 21.03), 'WEN')
F15('Ava Kingdom', 'Reino de Ava', 'reino', A, 2000, ('Ava (Inwa)', 95.98, 21.85), 'COW')
F15('Kashmiri Sultanate', 'Sultanato de Cachemira', 'sultanato', A, 1500, ('Srinagar', 74.80, 34.08), 'TNK')
F15('Sind-Samma Dynasty', 'Dinastía Samma (Sind)', 'sultanato', A, 2500, ('Thatta', 67.92, 24.75), 'TNK')
F15('Bijapur Sultanate', 'Sultanato de Bijapur', 'sultanato', A, 4500, ('Bijapur', 75.71, 16.83), 'PAG')
F15('Kapisa', 'Principado de Kabul', 'principado', A, 600, ('Kabul', 69.17, 34.53), 'TNK')
F15('Majapahit', 'Majapahit (en declive)', 'imperio', A, 5000, ('Trowulan', 112.38, -7.56), 'MAS')
F15('Kingdom of Mrauk U', 'Reino de Mrauk U (Arakán)', 'reino', A, 1000, ('Mrauk U', 93.20, 20.59), 'COW')
F15('Berar Sultanate', 'Sultanato de Berar', 'sultanato', A, 2000, ('Ellichpur', 77.51, 21.25), 'PAG')
F15('Hanthawaddy Kingdom', 'Reino de Hanthawaddy (Pegú)', 'reino', A, 1500, ('Pegú', 96.48, 17.33), 'COW')
F15('Sultanate of Palembang', 'Palembang', 'sultanato', A, 700, ('Palembang', 104.76, -2.98), 'MAS')
F15('Ahmadnagar Sultanate', 'Sultanato de Ahmadnagar', 'sultanato', A, 3000, ('Ahmadnagar', 74.74, 19.09), 'PAG')
F15('Bahrani Dynasty', 'Emirato de Bahréin', 'emirato', A, 300, ('Al-Qatif', 50.01, 26.56), 'DIN')
F15('Bidar Sultanate', 'Sultanato de Bidar', 'sultanato', A, 1500, ('Bidar', 77.52, 17.91), 'PAG')
F15('Ceylon', 'Reino de Kotte (Ceilán)', 'reino', A, 1200, ('Kotte', 79.92, 6.89), 'COW')
F15('Sunda Kingdom', 'Reino de Sunda', 'reino', A, 800, ('Pakuan', 106.80, -6.60), 'MAS')
F15('Lan Na Kingdom', 'Reino de Lan Na', 'reino', A, 1000, ('Chiang Mai', 98.99, 18.79), 'COW')
F15('Sultanate of Brunei', 'Sultanato de Brunéi', 'sultanato', A, 120, ('Kota Batu', 114.96, 4.89), 'MAS')
F15('Shirvan', 'Shirvanshahs', 'reino', A, 600, ('Bakú', 49.87, 40.41), 'TNK')
F15('Samtskhe-Saatabago', 'Samtsjé-Saatabago', 'principado', A, 400, ('Akhaltsikhe', 43.00, 41.64), 'TNK')
F15('Beylik of Dulkadir', 'Beylicato de Dulkadir', 'emirato', A, 500, ('Elbistán', 37.20, 38.20), 'DIR')
F15('Kingdom of Georgia', 'Reino de Georgia (Kartli)', 'reino', A, 400, ('Tiflis', 44.79, 41.72), 'DIR')
F15('Ramadanid Emirate', 'Emirato ramadánida', 'emirato', A, 200, ('Adana', 35.32, 37.00), 'DIR')
F15('Kingdom of Kakheti', 'Reino de Kajetia', 'reino', A, 200, ('Gremi', 45.65, 42.00), 'DIR')
F15('Prome Kingdom', 'Reino de Prome', 'reino', A, 400, ('Prome (Pyay)', 95.22, 18.82), 'COW')
F15('Sultanate of Kedah', 'Sultanato de Kedah', 'sultanato', A, 150, ('Kota Star', 100.37, 6.12), 'MAS')
F15('Principality of Mingrelia', 'Principado de Mingrelia', 'principado', A, 150, ('Zugdidi', 41.87, 42.51), 'DIR')
F15('Jaffna kingdom', 'Reino de Jaffna', 'reino', A, 300, ('Nallur', 80.03, 9.67), 'COW')
F15('Kingdom of Imereti', 'Reino de Imericia', 'reino', A, 200, ('Kutaisi', 42.70, 42.27), 'DIR')
F15('Samudera Pasai Sultanate', 'Sultanato de Samudera Pasai', 'sultanato', A, 100, ('Pasai', 97.60, 5.17), 'MAS')
F15('Sultanate of Malacca', 'Sultanato de Malaca', 'sultanato', A, 120, ('Malaca', 102.25, 2.19), 'MAS', pib=1000)
F15('Demak Sultanate', 'Sultanato de Demak', 'sultanato', A, 500, ('Demak', 110.64, -6.89), 'MAS')
# ── África ──
F15('Mamluk Sultanate', 'Sultanato mameluco', 'sultanato', AF, 6500, ('El Cairo', 31.25, 30.05), 'ASH', pib=900,
    etn=[('Egipcios', 55), ('Árabes y levantinos', 35), ('Nubios y otros', 10)])
F15('Songhai Empire', 'Imperio songhai', 'imperio', AF, 5000, ('Gao', 0.04, 16.27), 'TIB', pib=650)
F15('Ethiopian Empire', 'Imperio etíope', 'imperio', AF, 5000, ('Debre Berhan', 39.53, 9.68), 'AMO', pib=500)
F15('Wattasid dynasty', 'Dinastía wattásida (Marruecos)', 'sultanato', AF, 3000, ('Fez', -5.00, 34.03), 'DIN')
F15('Mali Empire', 'Imperio de Malí (en declive)', 'imperio', AF, 3500, ('Niani', -9.0, 11.7), 'TIB', pib=650)
F15('Hafsid Dynasty', 'Dinastía hafsí', 'sultanato', AF, 2500, ('Túnez', 10.18, 36.81), 'DIN')
F15('Makuria Kingdom', 'Reino de Makuria (residual)', 'reino', AF, 500, ('Dongola', 30.48, 19.17), 'TRQ')
F15('Bornu Empire', 'Imperio de Bornu', 'imperio', AF, 2000, ('Ngazargamu', 12.4, 13.0), 'COW')
F15('Adal Sultanate', 'Sultanato de Adal', 'sultanato', AF, 1500, ('Harar', 42.12, 9.31), 'DIN')
F15('Kingdom of Kongo', 'Reino del Congo', 'reino', AF, 1500, ('Mbanza Kongo', 14.25, -6.27), 'NZI')
F15('Zayyanid dynasty', 'Dinastía zayyání (Tremecén)', 'sultanato', AF, 1000, ('Tremecén', -1.31, 34.88), 'DIN')
F15('Alodia', 'Reino de Alodia (últimos años)', 'reino', AF, 700, ('Soba', 32.70, 15.50), 'TRQ')
# ── América ──
F15('Inca Empire', 'Imperio inca', 'imperio', AS, 10000, ('Cuzco', -71.97, -13.52), 'TRQ', pib=650, div='Suyus',
    etn=[('Quechuas', 40), ('Aimaras', 15), ('Pueblos costeños y otros', 45)])
F15('Later Mayan City-States', 'Ciudades-estado mayas (Yucatán)', 'ciudades-estado', AN, 1500, ('Mayapán', -89.46, 20.63), 'CAC')
F15('Aztec Triple Alliance', 'Triple Alianza azteca', 'imperio', AN, 5000, ('Tenochtitlan', -99.13, 19.43), 'CAC', pib=700, div='Provincias tributarias',
    etn=[('Nahuas', 55), ('Otomíes, totonacas y otros', 45)])
F15('Michoacán', 'Imperio purépecha (Michoacán)', 'imperio', AN, 1000, ('Tzintzuntzan', -101.58, 19.63), 'CAC')
F15('Haudenosaunee', 'Confederación Haudenosaunee', 'confederación nómada', AN, 60, ('Onondaga', -76.15, 43.00), 'TRQ')
# ── Europa ──
F15('Grand Principality of Moscow', 'Gran Principado de Moscú', 'principado', E_, 6500, ('Moscú', 37.62, 55.76), 'DGA', pib=650)
F15('Kalmar Union', 'Unión de Kalmar', 'reino', E_, 2000, ('Copenhague', 12.57, 55.68), 'DEN', pib=850)
F15('House of Jagiellon', 'Polonia-Lituania (Jagellones)', 'reino', E_, 7500, ('Cracovia', 19.94, 50.06), 'GRO', pib=800, div='Voivodatos',
    etn=[('Polacos', 35), ('Lituanos y rutenos', 50), ('Judíos y otros', 15)])
F15('Kingdom of France', 'Reino de Francia', 'reino', E_, 16000, ('París', 2.35, 48.86), 'ECU', pib=900, div='Bailías')
F15('Crown of Castile', 'Corona de Castilla', 'reino', E_, 5000, ('Valladolid', -4.72, 41.65), 'REA', pib=900, div='Merindades')
F15('Holy Roman Empire Minor States', 'Sacro Imperio (principados y ciudades libres)', 'imperio', E_, 11000, ('Núremberg', 11.08, 49.45), 'GUL', pib=900, div='Territorios',
    etn=[('Alemanes', 80), ('Checos, polacos y otros', 20)])
F15('Kingdom of Hungary', 'Reino de Hungría', 'reino', E_, 3200, ('Buda', 19.04, 47.50), 'DUC', div='Condados')
F15('Kingdom of England', 'Reino de Inglaterra', 'reino', E_, 3000, ('Londres', -0.13, 51.51), 'PNY', pib=950, div='Condados')
F15('Astrakhan Khanate', 'Janato de Astracán', 'khanato', E_, 300, ('Astracán', 48.04, 46.35), 'TRQ')
F15('Crimean Khanate', 'Janato de Crimea', 'khanato', E_, 500, ('Bakhchysarai', 33.93, 44.75), 'TRQ')
F15('Khanate of Kazan', 'Janato de Kazán', 'khanato', E_, 600, ('Kazán', 49.11, 55.80), 'TRQ')
F15('Crown of Aragon', 'Corona de Aragón', 'reino', E_, 1000, ('Barcelona', 2.17, 41.39), 'DUC', pib=900)
F15('Kingdom of Bohemia', 'Reino de Bohemia', 'reino', E_, 2000, ('Praga', 14.42, 50.09), 'GRO', div='Circunscripciones')
F15('Livonian Conference', 'Confederación de Livonia', 'república', E_, 600, ('Riga', 24.11, 56.95), 'GRO')
F15('Kingdom of Portugal', 'Reino de Portugal', 'reino', E_, 1200, ('Lisboa', -9.14, 38.72), 'CRU', pib=1000, div='Comarcas')
F15('House of Habsburg', 'Casa de Habsburgo (Austria)', 'ducado', E_, 1500, ('Viena', 16.37, 48.21), 'GUL')
F15('Kingdom of Scotland', 'Reino de Escocia', 'reino', E_, 700, ('Edimburgo', -3.19, 55.95), 'PNY')
F15('Principality of Moldavia', 'Principado de Moldavia', 'principado', E_, 600, ('Suceava', 26.26, 47.65), 'GRO')
F15('Principality of Wallachia', 'Principado de Valaquia', 'principado', E_, 700, ('Târgoviște', 25.46, 44.93), 'GRO')
F15('Habsburg Monarchy', 'Países Bajos borgoñones (Habsburgo)', 'ducado', E_, 2500, ('Malinas', 4.48, 51.03), 'GUL', pib=1100)
F15('Kingdom of Naples', 'Reino de Nápoles', 'reino', E_, 2500, ('Nápoles', 14.25, 40.85), 'DUC', pib=900)
F15('Republic of Venice', 'República de Venecia', 'república', E_, 1700, ('Venecia', 12.34, 45.44), 'DUC', pib=1250)
F15('County of Foix', 'Condado de Foix y Bearne', 'condado', E_, 250, ('Foix', 1.60, 42.97), 'ECU')
F15('House of Bourbon', 'Ducado de Borbón', 'ducado', E_, 800, ('Moulins', 3.33, 46.57), 'ECU')
F15('Electorate of Brandenburg', 'Electorado de Brandeburgo', 'electorado', E_, 450, ('Berlín', 13.40, 52.52), 'GUL')
F15('Papal States', 'Estados Pontificios', 'principado', E_, 1500, ('Roma', 12.50, 41.89), 'DUC', pib=950)
F15('Teutonic Order', 'Estado de la Orden Teutónica (Prusia)', 'principado', E_, 400, ('Marienburgo', 19.03, 54.04), 'GRO')
F15('Duchy of Bavaria', 'Ducado de Baviera', 'ducado', E_, 1000, ('Múnich', 11.58, 48.14), 'GUL')
F15('County of Savoy', 'Condado (Ducado) de Saboya', 'ducado', E_, 600, ('Chambéry', 5.92, 45.57), 'DUC')
F15('Electorate of Saxony', 'Electorado de Sajonia', 'electorado', E_, 700, ('Wittenberg', 12.65, 51.87), 'GUL')
F15('Duchy of Milan', 'Ducado de Milán', 'ducado', E_, 1000, ('Milán', 9.19, 45.46), 'DUC', pib=1100)
F15('Republic of Genoa', 'República de Génova', 'república', E_, 600, ('Génova', 8.93, 44.41), 'DUC', pib=1150)
F15('Qasim Khanate', 'Janato de Kasímov', 'khanato', E_, 100, ('Kasímov', 41.39, 54.94), 'TRQ')
F15('Swiss Confederation', 'Confederación Suiza', 'república', E_, 700, ('Berna', 7.45, 46.95), 'GUL', pib=1000, div='Cantones')
F15('Pskov Republic', 'República de Pskov', 'república', E_, 200, ('Pskov', 28.33, 57.82), 'DGA')
F15('Duchy of Lorraine', 'Ducado de Lorena', 'ducado', E_, 450, ('Nancy', 6.18, 48.69), 'ECU')
F15('Electorate of Trier', 'Electorado de Tréveris', 'electorado', E_, 200, ('Tréveris', 6.64, 49.75), 'GUL')
F15('Ryazan', 'Gran Ducado de Riazán', 'principado', E_, 200, ('Riazán', 39.75, 54.63), 'DGA')
F15('County of Nevers', 'Condado de Nevers', 'condado', E_, 200, ('Nevers', 3.16, 46.99), 'ECU')
F15('Republic of Florence', 'República de Florencia', 'república', E_, 700, ('Florencia', 11.26, 43.77), 'FLO', pib=1300)
