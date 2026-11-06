# -*- coding: utf-8 -*-
"""
Año 1 d. C. — CIUDADES (nombre, longitud, latitud, población estimada de la ciudad).
Cifras de orden de magnitud (Chandler, Modelski, Hansen, el censo Han del año 2 d. C. y estimaciones arqueológicas);
son aproximadas. La capital de cada estado/pueblo se añade sola con rango de capital desde su ficha, no hace falta repetirla aquí.
"""

CIUDADES = [
    # ── Roma y el Mediterráneo occidental ──
    ('Roma', 12.50, 41.89, 1000000), ('Capua', 14.25, 41.08, 60000), ('Puteoli', 14.12, 40.82, 60000), ('Nápoles', 14.25, 40.85, 30000),
    ('Ostia', 12.29, 41.76, 30000), ('Milán (Mediolanum)', 9.19, 45.46, 40000), ('Aquileia', 13.37, 45.77, 50000), ('Rávena', 12.20, 44.42, 30000),
    ('Siracusa', 15.29, 37.07, 100000), ('Marsella (Massalia)', 5.37, 43.30, 30000), ('Lyon (Lugdunum)', 4.83, 45.76, 50000),
    ('Narbona (Narbo Martius)', 3.00, 43.18, 30000), ('Burdeos (Burdigala)', -0.58, 44.84, 20000), ('Tréveris (Augusta Treverorum)', 6.64, 49.75, 20000),
    ('Colonia (Colonia Agrippina)', 6.96, 50.94, 20000), ('Tarragona (Tarraco)', 1.25, 41.12, 30000), ('Cádiz (Gades)', -6.29, 36.53, 60000),
    ('Córdoba (Corduba)', -4.78, 37.88, 40000), ('Sevilla (Hispalis)', -5.99, 37.39, 30000), ('Mérida (Emerita Augusta)', -6.34, 38.92, 30000),
    ('Cartagena (Carthago Nova)', -0.99, 37.60, 30000), ('Lisboa (Olisipo)', -9.14, 38.72, 20000), ('Zaragoza (Caesaraugusta)', -0.88, 41.65, 25000),
    ('Cartago', 10.32, 36.85, 100000), ('Útica', 10.06, 37.06, 50000), ('Leptis Magna', 14.29, 32.64, 40000), ('Cirene', 21.86, 32.82, 50000),
    ('Hipona', 7.76, 36.90, 25000), ('Cirta', 6.61, 36.37, 30000), ('Volúbilis', -5.55, 34.07, 10000), ('Cesarea de Mauretania', 2.19, 36.61, 20000),
    ('Tingis (Tánger)', -5.81, 35.78, 15000), ('Lixus', -6.10, 35.20, 8000), ('Tolosa', 1.44, 43.60, 20000), ('Vienne (Vienna)', 4.87, 45.52, 20000),
    ('Nimes (Nemausus)', 4.36, 43.84, 20000), ('Arlés (Arelate)', 4.63, 43.68, 15000), ('Augusta Vindelicum (Augsburgo)', 10.90, 48.37, 10000),
    ('Emona (Liubliana)', 14.51, 46.05, 8000), ('Salona', 16.48, 43.54, 40000), ('Sirmio (Sirmium)', 19.60, 44.97, 15000), ('Carnuntum', 16.86, 48.12, 12000),
    # ── Grecia, Tracia y Anatolia ──
    ('Atenas', 23.73, 37.97, 75000), ('Corinto', 22.88, 37.91, 80000), ('Esparta', 22.43, 37.07, 20000), ('Tesalónica', 22.94, 40.64, 65000),
    ('Bizancio', 28.98, 41.01, 40000), ('Nicomedia', 29.92, 40.77, 50000), ('Cícico', 27.88, 40.39, 40000), ('Éfeso', 27.34, 37.94, 200000),
    ('Pérgamo', 27.18, 39.12, 150000), ('Esmirna', 27.14, 38.42, 90000), ('Tarso', 34.89, 36.92, 100000), ('Sinope', 35.15, 42.03, 30000),
    ('Ancira (Ankara)', 32.86, 39.93, 30000), ('Rodas', 28.23, 36.44, 40000), ('Gortina (Creta)', 24.95, 35.06, 30000), ('Salamina (Chipre)', 33.90, 35.18, 25000),
    ('Filipópolis (Plovdiv)', 24.75, 42.15, 15000), ('Apolonia (Iliria)', 19.47, 40.72, 15000), ('Dirraquio', 19.45, 41.32, 25000),
    # ── Levante, Mesopotamia y Egipto ──
    ('Alejandría', 29.92, 31.20, 400000), ('Menfis', 31.25, 29.85, 100000), ('Tebas (Egipto)', 32.64, 25.70, 50000), ('Pelusio', 32.55, 31.03, 15000),
    ('Antioquía', 36.16, 36.20, 150000), ('Damasco', 36.31, 33.51, 80000), ('Tiro', 35.20, 33.27, 40000), ('Sidón', 35.37, 33.56, 30000),
    ('Cesarea Marítima', 34.89, 32.50, 40000), ('Palmira', 38.27, 34.55, 15000), ('Seleucia del Tigris', 44.52, 33.09, 200000), ('Babilonia', 44.42, 32.54, 30000),
    ('Susa', 48.25, 32.19, 40000), ('Ecbatana (Hamadán)', 48.52, 34.80, 60000), ('Dura-Europos', 40.73, 34.75, 10000), ('Nísibis', 41.22, 37.07, 25000),
    ('Tigranocerta', 41.0, 38.3, 50000), ('Samosata', 38.5, 37.5, 25000), ('Charax Spasinu', 48.3, 30.4, 30000), ('Gaza', 34.47, 31.50, 25000),
    ('Bostra', 36.48, 32.52, 15000), ('Maribo (Marib)', 45.35, 15.43, 15000), ('Saná', 44.21, 15.35, 20000), ('Gerra', 50.1, 26.0, 25000),
    ('Olbia (Ponto)', 31.9, 46.7, 20000), ('Tanais', 39.3, 47.27, 10000), ('Dioscurias (Sujumi)', 41.0, 43.0, 15000), ('Tiflis', 44.8, 41.7, 10000),
    # ── Irán, Asia Central y el Indo ──
    ('Hecatómpilo', 54.0, 36.2, 30000), ('Merv (Margiana)', 62.19, 37.66, 30000), ('Ray (Rhages)', 51.43, 35.59, 30000), ('Persépolis', 52.89, 29.93, 15000),
    ('Bactra (Balj)', 66.9, 36.76, 50000), ('Maracanda (Samarcanda)', 66.97, 39.65, 30000), ('Alejandría Arachosia (Kandahar)', 65.71, 31.62, 30000),
    ('Purushapura (Peshawar)', 71.58, 34.01, 40000), ('Taxila (Sirkap)', 72.82, 33.75, 50000), ('Sagala (Sialkot)', 74.52, 32.50, 50000),
    ('Minnagara (Sind)', 68.3, 24.8, 30000), ('Barigaza (Broach)', 72.80, 21.70, 50000), ('Kashgar', 75.99, 39.47, 20000), ('Jotán (Khotan)', 79.93, 37.11, 20000),
    ('Loulan', 89.9, 40.5, 8000), ('Turfán (Jiaohe)', 89.5, 42.95, 10000), ('Dunhuang', 94.66, 40.14, 20000),
    # ── India y Ceilán ──
    ('Pataliputra', 85.14, 25.60, 250000), ('Mathura', 77.67, 27.49, 80000), ('Ujayini (Ujjain)', 75.78, 23.18, 80000), ('Varanasi', 83.00, 25.32, 60000),
    ('Kausambi', 81.39, 25.35, 60000), ('Vidisha', 77.81, 23.52, 40000), ('Tamralipti', 87.92, 22.30, 40000), ('Pratisthana (Paithan)', 75.38, 19.48, 60000),
    ('Dhanyakataka (Amaravati)', 80.36, 16.57, 40000), ('Madurai', 78.12, 9.92, 60000), ('Uraiyur', 78.69, 10.83, 50000), ('Kanchipuram', 79.70, 12.83, 50000),
    ('Muziris', 76.20, 10.18, 30000), ('Arikamedu', 79.82, 11.91, 20000), ('Anuradhapura', 80.40, 8.35, 40000), ('Sisupalgarh', 85.84, 20.24, 25000),
    ('Vaishali', 85.13, 25.99, 40000), ('Kapilavastu', 83.05, 27.55, 15000),
    # ── Asia oriental ──
    ('Chang\'an', 108.95, 34.27, 246000), ('Luoyang', 112.45, 34.62, 200000), ('Linzi', 118.35, 36.82, 100000), ('Chengdu', 104.07, 30.67, 100000),
    ('Wancheng (Nanyang)', 112.53, 33.00, 100000), ('Handan', 114.54, 36.62, 80000), ('Panyu (Cantón)', 113.26, 23.13, 50000), ('Suzhou (Wu)', 120.62, 31.30, 50000),
    ('Jiangling', 112.19, 30.35, 60000), ('Ye (Anyang)', 114.35, 36.10, 40000), ('Pingrang (Lelang)', 125.75, 39.02, 60000), ('Gungnae (Goguryeo)', 126.18, 41.15, 20000),
    ('Saro (Gyeongju)', 129.2, 35.84, 15000), ('Gumi (Gimhae)', 128.9, 35.23, 12000), ('Longcheng (Xiongnu)', 101.0, 47.5, 20000), ('Xian Yang', 108.7, 34.33, 50000),
    ('Dunhuang (Han)', 94.66, 40.14, 20000), ('Yoshinogari', 130.4, 33.3, 5000), ('Yamato', 135.8, 34.5, 8000), ('Long Bien (Hanói)', 105.85, 21.04, 20000),
    ('Luy Lau', 106.0, 21.05, 50000), ('Oc Eo', 105.15, 10.25, 20000), ('Beikthano', 95.3, 20.5, 30000), ('Sa Huynh', 108.9, 15.0, 8000),
    # ── África ──
    ('Meroe', 33.75, 16.94, 30000), ('Napata', 31.83, 18.54, 15000), ('Aksum', 38.72, 14.13, 20000), ('Adulis', 39.65, 15.25, 20000),
    ('Garama', 13.30, 26.48, 10000), ('Djenné-Djenno', -4.55, 13.9, 10000), ('Taruga (Nok)', 7.2, 9.8, 5000), ('Sao (Lago Chad)', 14.8, 12.0, 5000),
    ('Gran Zimbabue (precursor)', 30.9, -20.3, 2000),
    # ── Europa no romana ──
    ('Marobodum', 14.4, 50.1, 10000), ('Sarmizegetusa Regia', 23.31, 45.62, 20000), ('Camuloduno', 0.90, 51.89, 8000), ('Tara', -6.61, 53.58, 3000),
    ('Gamla Uppsala', 17.63, 59.90, 3000), ('Panticapea', 36.47, 45.35, 30000), ('Traprain Law', -2.67, 55.97, 4000), ('Isurium (Brigantes)', -1.38, 54.09, 4000),
    ('Dunadd', -5.49, 56.09, 2000), ('Eboraco (Brigantes)', -1.08, 53.96, 3000), ('Verulamium', -0.36, 51.75, 5000), ('Hjortspring (Dinamarca)', 9.9, 55.0, 2000),
    # ── Américas ──
    ('Teotihuacán', -98.84, 19.69, 50000), ('Cuicuilco', -99.18, 19.30, 20000), ('Monte Albán', -96.77, 17.04, 17000), ('El Mirador', -89.92, 17.75, 30000),
    ('Tikal', -89.62, 17.22, 10000), ('Kaminaljuyú', -90.55, 14.63, 10000), ('Tres Zapotes', -95.43, 18.46, 8000), ('La Mojarra', -95.9, 18.55, 5000),
    ('Teuchitlán', -103.85, 20.69, 10000), ('Cholula', -98.30, 19.06, 12000), ('Newark (Hopewell)', -82.4, 40.05, 5000), ('Chillicothe (Hopewell)', -82.97, 39.33, 5000),
    ('Cahuachi', -75.12, -14.82, 5000), ('Pucará', -70.37, -15.03, 10000), ('Cerro Arena', -78.9, -8.1, 8000), ('Pachacamac', -76.9, -12.25, 10000),
    ('Bacatá (Muisca)', -74.07, 4.6, 8000), ('San Agustín', -76.29, 1.88, 5000), ('La Tolita', -79.0, 1.1, 8000), ('Marajó (Camutins)', -49.5, -0.5, 4000),
    ('Chaco Canyon (precursor)', -107.96, 36.06, 2000),
]
