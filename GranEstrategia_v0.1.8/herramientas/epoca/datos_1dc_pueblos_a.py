# -*- coding: utf-8 -*-
"""
Año 1 d. C. — PUEBLOS y CULTURAS dibujados a mano (Europa, Norte de África, Oriente Próximo, Asia Central y Siberia).

Son los pueblos que NO aparecen en Cliopatria (que solo trae estados con fronteras). Cada polígono es una zona aproximada en
longitud/latitud (el recorte con las provincias y con la costa lo hace la herramienta; lo que cae en el mar no cuenta). Donde un
estado de Cliopatria ya ocupa el terreno, el estado manda. Fuentes de consulta (de memoria, sin copiar ningún conjunto de datos):
atlas históricos generales, Tácito (Germania), César, Plinio, Ptolomeo, Estrabón y la bibliografía arqueológica de cada región.
LAS FRONTERAS DE ESTOS PUEBLOS SON APROXIMADAS: los pueblos antiguos no tenían fronteras lineales.
"""

def P(s):
    return [tuple(float(v) for v in pt.split(',')) for pt in s.split()]


PUEBLOS = []


def pueblo(clave, nombre, tipo, cont, pob, polys, cap=None, moneda='TRQ', pib_pc=560, etn=None, div='Territorios', desde=None, hasta=None):
    PUEBLOS.append(dict(clave=clave, nombre=nombre, tipo=tipo, cont=cont, pob=pob, partes=[P(s) for s in polys], cap=cap,
                        moneda=moneda, pib_pc=pib_pc, etn=etn or [(nombre, 100)], div=div, desde=desde, hasta=hasta))


# ───────────────────────── ISLAS BRITÁNICAS ─────────────────────────
pueblo('caledonios', 'Caledonios', 'confederación tribal', 'Europa', 130,
       ['-8.4,56.2 -8.4,59.0 -3.5,59.5 -0.3,60.9 -0.3,59.5 -1.5,58.0 -1.9,57.0 -2.5,56.5 -3.0,56.2 -3.4,56.05 -4.7,56.0 -5.5,55.6'],
       cap=('Fortaleza de Dunadd', -5.49, 56.09), pib_pc=520)
pueblo('britones_norte', 'Britones del norte (votadinos y selgovas)', 'confederación tribal', 'Europa', 110,
       ['-5.8,55.95 -4.7,56.0 -3.4,56.05 -2.0,56.05 -1.2,55.1 -1.4,54.9 -2.2,54.95 -3.2,54.9 -3.7,54.6 -5.8,54.6'],
       cap=('Traprain Law', -2.67, 55.97), pib_pc=540)
pueblo('brigantes', 'Brigantes', 'confederación tribal', 'Europa', 140,
       ['-3.7,54.6 -3.2,54.9 -2.2,54.95 -1.4,54.95 -0.4,54.5 0.3,53.6 -0.7,53.6 -1.5,53.3 -2.0,53.2 -2.6,53.3 -3.1,53.35 -3.5,53.7'],
       cap=('Isurium', -1.38, 54.09), pib_pc=560)
pueblo('catuvelaunos', 'Catuvelaunos y britones del sureste', 'reino tribal', 'Europa', 450,
       ['-3.1,53.35 -2.6,53.3 -2.0,53.2 -1.5,53.3 -0.7,53.6 0.4,53.6 2.2,53.0 2.2,51.0 0.0,50.5 -1.5,50.4 -2.6,50.5 -3.2,50.9 -3.0,51.5 -2.9,52.2 -3.1,52.9'],
       cap=('Camuloduno', 0.90, 51.89), pib_pc=640)
pueblo('britones_oeste', 'Britones galeses (silures y ordovices)', 'confederación tribal', 'Europa', 160,
       ['-5.5,51.6 -5.5,53.5 -4.4,53.5 -3.5,53.5 -3.1,53.35 -3.1,52.9 -2.9,52.2 -3.0,51.5 -3.5,51.3'],
       pib_pc=540)
pueblo('dumnonios', 'Dumnonios (Cornualles y Devon)', 'confederación tribal', 'Europa', 90,
       ['-6.2,49.7 -6.2,51.2 -3.7,51.3 -3.0,51.2 -3.2,50.9 -3.2,50.5 -4.6,49.9'],
       cap=('Isca Dumnoniorum', -3.53, 50.72), pib_pc=540)
pueblo('hibernios', 'Hibernios (Irlanda gaélica)', 'tribus', 'Europa', 260,
       ['-10.9,51.2 -10.9,55.6 -7.0,55.5 -5.3,54.7 -5.3,53.5 -6.0,52.0 -7.5,51.3'],
       cap=('Tara', -6.61, 53.58), pib_pc=520)

# ───────────────────────── GERMANIA Y NORTE DE EUROPA ─────────────────────────
pueblo('frisios', 'Frisios y caucos', 'tribus', 'Europa', 130,
       ['4.5,52.5 4.5,53.8 9.0,54.0 9.2,53.3 8.0,52.6 6.8,52.4 5.5,52.2'], pib_pc=560)
pueblo('queruscos', 'Queruscos, catos y brúcteros', 'confederación tribal', 'Europa', 420,
       ['6.8,52.4 8.0,52.6 9.2,53.3 10.2,52.6 10.2,51.0 10.0,50.0 8.2,50.0 8.0,50.5 7.0,50.9 6.8,51.7'], pib_pc=570)
pueblo('suevos_elba', 'Semnones y suevos del Elba', 'confederación tribal', 'Europa', 330,
       ['10.2,52.6 13.0,53.4 14.6,53.0 15.0,51.8 13.8,51.1 12.0,49.8 10.0,49.5 10.0,50.5'], pib_pc=570)
pueblo('marcomanos', 'Marcomanos y cuados', 'reino tribal', 'Europa', 280,
       ['11.8,50.8 13.8,51.1 16.5,50.5 18.2,49.8 18.0,48.7 16.8,48.5 14.5,48.7 12.8,49.0 12.0,49.8'],
       cap=('Marobodum', 14.4, 50.1), pib_pc=600)
pueblo('lugios', 'Lugios y vándalos (Oder y Vístula)', 'confederación tribal', 'Europa', 330,
       ['14.6,53.0 15.0,54.0 17.5,54.3 18.5,53.5 18.5,50.5 16.5,50.5 15.0,51.8'], pib_pc=560)
pueblo('godos', 'Godos (gutones) del Vístula', 'tribus', 'Europa', 150,
       ['17.5,53.8 18.0,54.9 20.0,54.9 20.5,54.0 19.5,53.2'], pib_pc=550)
pueblo('daneses', 'Cimbrios, anglos y daneses', 'tribus', 'Europa', 230,
       ['8.0,54.0 8.0,57.9 10.7,57.9 12.8,56.3 12.7,54.6 11.0,54.0 10.0,53.8'], pib_pc=570)
pueblo('gautas', 'Gautas y escanios (sur de Suecia)', 'tribus', 'Europa', 200,
       ['12.6,55.2 14.5,55.3 16.7,56.6 16.9,58.0 16.0,58.7 14.0,58.9 12.0,58.9 11.5,57.5 12.5,56.0',
        '18.0,56.9 19.4,56.9 19.4,58.0 18.0,58.0'], pib_pc=540)
pueblo('suiones', 'Suiones (svear)', 'reino tribal', 'Europa', 130,
       ['14.0,59.0 16.0,58.8 18.5,58.7 19.5,60.0 18.8,61.5 17.0,62.0 15.0,61.0 14.0,60.0'],
       cap=('Gamla Uppsala', 17.63, 59.90), pib_pc=540)
pueblo('noruegos', 'Pueblos de Noruega meridional', 'tribus', 'Europa', 130,
       ['4.5,58.0 4.5,62.2 8.5,63.7 12.0,64.0 12.3,62.0 12.0,60.0 11.8,59.0 10.5,58.9 8.0,58.0'], pib_pc=520)
pueblo('sami', 'Sami y pueblos de la Fenoscandia septentrional', 'cazadores-recolectores', 'Europa', 25,
       ['13.0,65.5 15.0,68.5 19.0,70.0 25.0,71.0 31.0,70.5 41.0,68.8 41.0,66.5 34.0,66.0 29.0,65.5 25.0,66.0 22.0,65.5 18.0,65.0'], pib_pc=400)
pueblo('fineses', 'Pueblos fineses y estonios (fenos, ests, carelios)', 'tribus', 'Europa', 160,
       ['21.0,59.0 21.5,61.5 24.0,64.0 29.0,65.0 34.0,65.5 36.0,62.0 33.0,60.0 28.0,58.8 24.0,58.0 23.0,57.7'], pib_pc=480)
pueblo('balticos', 'Pueblos bálticos (aestios, galindios, curonios)', 'tribus', 'Europa', 260,
       ['19.8,54.5 21.0,56.5 23.0,57.5 24.5,57.5 27.0,57.2 28.5,55.5 28.0,53.5 25.0,52.8 22.5,53.5 20.0,53.8'], pib_pc=520)
pueblo('venedos', 'Venedos (protoeslavos)', 'tribus', 'Europa', 600,
       ['18.0,53.8 20.0,53.8 22.5,53.5 25.0,52.8 28.0,53.5 32.5,53.2 35.0,51.5 32.5,50.0 28.0,49.5 24.0,49.8 21.0,50.0 18.5,50.5'], pib_pc=520)
pueblo('bastarnas', 'Bastarnas y pueblos del Dniéster', 'confederación tribal', 'Europa', 160,
       ['24.0,49.8 28.0,49.5 31.0,48.0 30.5,46.0 28.0,46.0 26.5,46.5 25.0,47.5 23.5,48.5'], pib_pc=540)
pueblo('dacios', 'Dacios', 'reino tribal', 'Europa', 900,
       ['19.0,45.5 19.0,48.0 22.0,48.3 23.8,48.3 25.0,47.5 26.5,46.4 28.0,46.0 29.5,45.3 29.5,44.0 27.0,43.7 24.0,43.6 22.5,43.8 21.5,44.2'],
       cap=('Sarmizegetusa Regia', 23.31, 45.62), pib_pc=640)
pueblo('sarmatas', 'Sármatas (roxolanos y aorsos)', 'confederación nómada', 'Europa', 650,
       ['28.0,45.5 28.0,48.5 33.0,50.0 40.0,50.5 48.0,51.5 55.0,51.0 56.0,48.0 52.0,45.5 48.0,44.0 44.5,44.0 40.0,45.5 36.5,45.5 34.0,45.0 32.0,46.5 30.0,45.5'],
       pib_pc=500)
pueblo('finougrios', 'Pueblos finougrios del Volga, el Kama y el Dvina', 'tribus', 'Europa', 280,
       ['34.0,52.5 34.0,60.5 36.0,66.0 44.0,67.8 60.0,67.0 62.0,60.0 60.0,55.0 56.0,52.5 48.0,52.5'], pib_pc=420)

# ───────────────────────── ÁFRICA ─────────────────────────
pueblo('guanches', 'Guanches (Islas Canarias)', 'tribus', 'África', 40,
       ['-18.4,27.5 -18.4,29.5 -13.2,29.5 -13.2,27.5'], pib_pc=420)
pueblo('getulos', 'Gétulos y pueblos bereberes del Atlas y el Sahara septentrional', 'confederación tribal', 'África', 700,
       ['-13.0,27.0 -13.0,32.5 -4.0,33.0 2.0,32.0 8.0,32.5 10.5,31.0 10.5,27.5 4.0,27.0'], pib_pc=480)
pueblo('garamantes', 'Garamantes (Fezzán)', 'reino', 'África', 150,
       ['9.0,24.0 9.0,29.0 16.5,29.5 17.0,24.5 13.0,23.5'], cap=('Garama', 13.30, 26.48), pib_pc=600)
pueblo('blemios', 'Blemios y pueblos beja del desierto oriental', 'tribus', 'África', 90,
       ['32.5,17.0 32.5,24.0 36.0,24.0 37.5,19.0 37.0,16.5'], pib_pc=420)
pueblo('nubios', 'Pueblos nilóticos del Sudán meridional', 'tribus', 'África', 700,
       ['26.0,3.5 26.0,10.5 33.5,12.5 36.0,10.0 35.0,4.5 31.0,3.0'], pib_pc=430)
pueblo('cuerno', 'Pueblos cusitas del Cuerno de África', 'tribus', 'África', 1200,
       ['35.0,3.0 35.0,10.5 39.0,13.5 42.0,12.0 51.5,11.8 51.5,2.0 45.0,0.0 40.0,2.5'], pib_pc=450)
pueblo('sahel_occ', 'Pueblos del Sahel occidental (cultura de Djenné-Djenno)', 'cultura', 'África', 600,
       ['-12.0,12.0 -12.0,18.0 -4.0,18.5 4.0,17.0 4.0,13.0 -4.0,11.5'], cap=('Djenné-Djenno', -4.55, 13.9), pib_pc=470)
pueblo('nok', 'Cultura Nok y pueblos del Níger–Benue', 'cultura', 'África', 650,
       ['4.0,6.5 4.0,13.0 12.0,13.0 12.0,6.5'], cap=('Taruga', 7.2, 9.8), pib_pc=470)
pueblo('sao', 'Pueblos del lago Chad (cultura Sao)', 'cultura', 'África', 350,
       ['12.0,9.0 12.0,15.5 18.0,15.5 18.0,9.0'], pib_pc=450)
pueblo('guinea', 'Pueblos de la selva guineana (mande y kwa)', 'tribus', 'África', 900,
       ['-13.5,4.5 -13.5,10.5 -4.0,11.5 4.0,6.5 4.0,4.5'], pib_pc=420)
pueblo('africa_central_n', 'Pueblos de África central septentrional (ubangianos)', 'tribus', 'África', 400,
       ['18.0,3.5 18.0,10.0 26.0,10.5 26.0,3.5'], pib_pc=400)
pueblo('bantu_occ', 'Bantúes occidentales (Camerún, Congo y Gabón)', 'tribus', 'África', 1400,
       ['8.5,-5.0 8.5,4.0 18.0,4.0 24.0,3.5 24.0,-5.0 16.0,-6.0'], pib_pc=410)
pueblo('bantu_orient', 'Bantúes orientales (Grandes Lagos, cultura Urewe)', 'cultura', 'África', 1600,
       ['24.0,-8.0 24.0,3.5 31.0,3.0 35.5,1.0 36.5,-4.5 35.0,-9.0 29.0,-9.0'], pib_pc=430)
pueblo('bantu_costa', 'Pueblos de la costa suahili', 'tribus', 'África', 500,
       ['35.0,-9.0 36.5,-4.5 39.5,-3.0 42.0,-1.0 42.0,-9.5 38.0,-11.0'], pib_pc=440)
pueblo('bantu_sur', 'Bantúes del sur y pueblos del Zambeze', 'tribus', 'África', 800,
       ['16.0,-13.0 16.0,-8.0 29.0,-9.0 35.0,-9.0 38.0,-11.0 36.0,-16.0 31.0,-21.0 24.0,-19.0 20.0,-17.0'], pib_pc=400)
pueblo('khoisan', 'Pueblos khoisan (san y joikoi)', 'cazadores-recolectores', 'África', 350,
       ['12.0,-35.0 12.0,-17.5 20.0,-17.5 24.0,-19.0 31.0,-24.0 32.5,-28.0 28.0,-34.0 19.0,-35.0'], pib_pc=360)

# ───────────────────────── ORIENTE PRÓXIMO Y ARABIA ─────────────────────────
pueblo('arabes_centro', 'Tribus árabes de Néyed y Hiyaz', 'tribus', 'Asia', 700,
       ['36.5,20.0 36.5,29.0 39.0,31.0 44.0,31.0 48.0,29.5 50.0,26.0 49.0,22.0 44.0,19.5 40.0,18.5'], pib_pc=430)
pueblo('golfo_omani', 'Pueblos del golfo Pérsico y Omán', 'ciudades-estado', 'Asia', 500,
       ['50.0,23.0 50.0,26.5 52.0,25.0 56.5,26.5 59.8,22.5 59.5,19.0 55.0,17.5 53.0,19.0'], cap=('Gerra', 50.1, 26.0), moneda='DRP', pib_pc=650)
pueblo('caracena', 'Caracena (Mesene)', 'reino', 'Asia', 300,
       ['46.5,29.5 46.5,31.8 48.8,31.8 48.8,29.5'], cap=('Spasinou Charax', 48.3, 30.4), moneda='DRP', pib_pc=950)
pueblo('pueblos_taurus', 'Pueblos del Cáucaso septentrional (alanos y adigueos)', 'tribus', 'Europa', 300,
       ['36.5,43.0 36.5,45.5 40.0,45.5 44.5,44.0 48.0,44.0 48.0,42.0 44.0,42.8 40.0,43.2'], pib_pc=480)

# ───────────────────────── ASIA CENTRAL Y SIBERIA ─────────────────────────
pueblo('kangju', 'Kangju (Sogdiana y Sir Daria)', 'confederación', 'Asia', 700,
       ['62.0,39.0 62.0,46.5 72.0,46.5 72.0,40.0 69.0,38.5 64.5,37.5'], cap=('Bitian', 66.5, 43.5), moneda='DRI', pib_pc=700)
pueblo('corasmia', 'Corasmia (Joresm)', 'reino', 'Asia', 250,
       ['58.0,39.8 58.0,43.5 62.5,43.5 62.5,39.8'], cap=('Toprak-Kala', 60.9, 41.9), moneda='DRP', pib_pc=700)
pueblo('masagetas', 'Masagetas, dahas y pueblos esteparios del Turán', 'confederación nómada', 'Asia', 400,
       ['50.0,40.0 50.0,48.0 62.0,48.0 62.0,44.0 56.0,40.0'], pib_pc=470)
pueblo('saka_pamir', 'Sacas del Pamir y el Tianshan', 'confederación nómada', 'Asia', 150,
       ['72.0,37.0 72.0,40.8 80.0,41.5 80.0,37.0'], pib_pc=480)
pueblo('tarim', 'Ciudades-estado de la cuenca del Tarim', 'ciudades-estado', 'Asia', 500,
       ['76.0,36.0 76.0,40.5 90.0,42.0 92.5,39.5 88.0,37.0 80.0,36.0'], cap=('Kashgar', 75.99, 39.47), moneda='DRI', pib_pc=650)
pueblo('qiang', 'Pueblos qiang y zhang zhung (Tíbet)', 'tribus', 'Asia', 600,
       ['78.0,29.5 78.0,35.5 90.0,36.0 100.0,35.5 100.0,29.5 92.0,27.5 84.0,28.0'], pib_pc=420)
pueblo('xianbei', 'Xianbei y wuhuan', 'confederación nómada', 'Asia', 550,
       ['108.0,41.5 108.0,49.0 116.0,50.5 124.0,50.0 125.0,45.0 122.0,42.0 115.0,41.0'], pib_pc=480)
pueblo('buyeo', 'Reino de Buyeo (Fuyu)', 'reino', 'Asia', 250,
       ['124.0,43.0 124.0,46.5 128.5,46.5 129.0,43.5'], cap=('Fuyu', 126.0, 44.5), moneda='WZH', pib_pc=620)
pueblo('amur', 'Pueblos del Amur y el Ussuri (shiwei, sushen, mohe)', 'tribus', 'Asia', 250,
       ['118.0,50.0 121.0,53.5 130.0,54.5 140.0,54.0 141.0,48.5 135.0,43.5 130.0,43.0 129.5,45.0 126.0,47.0 123.0,48.0'], pib_pc=400)
pueblo('dingling', 'Dinglings y pueblos del Altái y el Sayán', 'tribus', 'Asia', 200,
       ['76.0,49.5 78.0,55.5 90.0,56.5 100.0,55.0 102.0,50.5 92.0,49.5 86.0,48.5'], pib_pc=420)
pueblo('baikal', 'Pueblos del Baikal y Transbaikalia', 'tribus', 'Asia', 100,
       ['100.0,55.0 104.0,58.0 112.0,58.5 120.0,56.0 118.0,50.5 108.0,50.0 102.0,50.5'], pib_pc=380)
pueblo('sargat', 'Pueblos esteparios del Ural y Siberia occidental (sargat)', 'tribus', 'Asia', 250,
       ['56.0,51.0 56.0,55.0 76.0,55.5 78.0,52.0 70.0,49.5 62.0,48.5 56.0,48.5'], pib_pc=450)
pueblo('uralicos_sib', 'Pueblos uralios de Siberia occidental (ugrios y samoyedos)', 'cazadores-recolectores', 'Asia', 80,
       ['60.0,55.5 62.0,64.0 70.0,67.5 80.0,68.0 88.0,66.0 88.0,56.0 76.0,54.5 66.0,54.5'], pib_pc=380)
pueblo('evenkis', 'Cazadores-recolectores del norte de Siberia (evenki y yucaguiros)', 'cazadores-recolectores', 'Asia', 90,
       ['90.0,57.0 92.0,70.0 105.0,73.0 128.0,72.5 150.0,71.5 170.0,69.0 170.0,63.0 158.0,58.5 143.0,58.5 138.0,54.5 130.0,54.5 120.0,56.0 112.0,58.5 104.0,58.0'], pib_pc=360)
pueblo('paleosiberianos', 'Paleosiberianos (chukchis, coriacos e itelmenos)', 'cazadores-recolectores', 'Asia', 40,
       ['155.0,50.5 155.0,62.0 165.0,66.0 180.0,69.0 180.0,64.0 170.0,59.5 163.0,55.0 157.0,51.0',
        '-180.0,64.0 -180.0,69.5 -169.0,66.5 -170.0,64.5'], pib_pc=360)
