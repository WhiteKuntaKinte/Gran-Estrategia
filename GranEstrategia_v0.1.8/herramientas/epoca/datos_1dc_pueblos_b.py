# -*- coding: utf-8 -*-
"""
Año 1 d. C. — PUEBLOS y CULTURAS dibujados a mano (Sur y Sureste de Asia, Japón, Indonesia, Oceanía y las Américas).
Mismas reglas y avisos que en datos_1dc_pueblos_a.py: zonas aproximadas, el estado de Cliopatria manda donde existe.
"""
from datos_1dc_pueblos_a import pueblo, PUEBLOS  # noqa: F401

# ───────────────────────── SUR DE ASIA ─────────────────────────
pueblo('ganges', 'Reinos del Ganges (Mitra, Pañcala y Kosala)', 'reinos', 'Asia', 12000,
       ['77.0,24.0 77.0,28.8 82.0,29.0 84.0,28.0 88.0,26.0 88.0,24.0 84.0,23.5 80.0,23.5'], cap=('Mathura', 77.67, 27.49), moneda='KRS', pib_pc=800, div='Distritos')
pueblo('magadha', 'Magadha y Bengala', 'reinos', 'Asia', 8000,
       ['83.5,22.0 83.5,26.0 88.0,26.0 90.0,26.0 90.0,22.0 88.5,21.5'], cap=('Pataliputra', 85.14, 25.60), moneda='KRS', pib_pc=800, div='Distritos')
pueblo('kalinga', 'Reino de Kalinga (Mahameghavahana)', 'reino', 'Asia', 3000,
       ['82.0,17.5 82.0,22.0 87.0,22.0 87.5,19.5 85.0,18.0'], cap=('Sisupalgarh', 85.84, 20.24), moneda='KRS', pib_pc=780, div='Distritos')
pueblo('panyab_rajastan', 'Repúblicas del Panyab y Rajastán (yaudheyas y malavas)', 'repúblicas tribales', 'Asia', 4000,
       ['71.0,24.5 71.0,31.0 77.5,31.5 77.5,26.0 75.0,24.0'], cap=('Rohtak', 76.6, 28.9), moneda='KRS', pib_pc=760, div='Distritos')
pueblo('malwa_gujarat', 'Malwa y Gujarat (abhiras y malavas)', 'reinos', 'Asia', 3500,
       ['68.5,20.5 68.5,24.8 75.0,24.5 77.5,23.0 77.0,21.0 73.0,19.8'], cap=('Ujayini', 75.78, 23.18), moneda='KRS', pib_pc=780, div='Distritos')
pueblo('himalaya', 'Pueblos del Himalaya (kuninda, licchavi y kirata)', 'tribus', 'Asia', 1500,
       ['78.0,28.8 78.0,32.5 82.0,31.5 90.0,28.5 92.5,27.5 88.0,26.0 84.0,28.0 82.0,29.0'], pib_pc=480, div='Distritos')
pueblo('adivasi', 'Pueblos tribales del Decán interior (gonda y bhil)', 'tribus', 'Asia', 2200,
       ['76.0,18.5 76.0,24.0 83.5,24.0 84.0,19.5 80.0,17.5'], pib_pc=420)
pueblo('assam', 'Pueblos de Assam y el Noreste (kamarupa temprano)', 'tribus', 'Asia', 700,
       ['89.5,22.5 89.5,28.0 97.0,29.0 97.0,22.5'], pib_pc=440)
pueblo('baluchis', 'Pueblos de Gedrosia y Beluchistán', 'tribus', 'Asia', 500,
       ['57.0,24.5 57.0,28.5 66.0,29.5 70.0,27.0 68.5,24.5 62.0,24.5'], pib_pc=420)

# ───────────────────────── SURESTE DE ASIA Y ARCHIPIÉLAGOS ─────────────────────────
pueblo('pyu', 'Ciudades-estado pyu', 'ciudades-estado', 'Asia', 700,
       ['94.0,18.0 94.0,23.5 97.0,23.5 97.0,18.0'], cap=('Beikthano', 95.3, 20.5), pib_pc=520)
pueblo('mon', 'Pueblos mon y de Suvarnabhumi', 'tribus', 'Asia', 900,
       ['97.0,12.0 97.0,18.0 101.5,18.0 101.5,12.0'], pib_pc=500)
pueblo('dian', 'Pueblos de Yunnan y la meseta Yunnan-Guizhou', 'tribus', 'Asia', 900,
       ['97.5,22.0 97.5,26.5 104.5,26.5 104.5,22.0'], pib_pc=480)
pueblo('lao_thai', 'Pueblos tai y de Indochina interior', 'tribus', 'Asia', 800,
       ['100.0,15.0 100.0,22.0 105.5,22.0 105.5,15.0'], pib_pc=440)
pueblo('funan', 'Funán y pueblos del Mekong (cultura Oc Eo)', 'reino', 'Asia', 700,
       ['102.5,9.0 102.5,14.5 107.5,14.5 107.5,9.0'], cap=('Oc Eo', 105.15, 10.25), pib_pc=520)
pueblo('sa_huynh', 'Cultura Sa Huynh (campas tempranos)', 'cultura', 'Asia', 600,
       ['107.0,10.5 107.0,16.5 109.5,16.5 109.5,10.5'], pib_pc=500)
pueblo('vietnam_norte', 'Lac Viet y pueblos del delta del Río Rojo', 'tribus', 'Asia', 1000,
       ['103.0,19.5 103.0,23.5 108.5,23.5 108.5,19.5'], pib_pc=550)
pueblo('malayos', 'Malayos tempranos (Malaca y Sumatra)', 'tribus', 'Asia', 700,
       ['98.0,-5.5 98.0,8.5 104.5,8.5 106.5,-4.5 104.0,-6.0'], pib_pc=440)
pueblo('java_bali', 'Pueblos de Java, Bali y las Pequeñas Sondas', 'tribus', 'Asia', 1300,
       ['105.0,-9.0 105.0,-5.8 116.5,-6.5 119.5,-8.0 119.5,-10.5 110.0,-9.5'], pib_pc=480)
pueblo('borneo', 'Pueblos de Borneo (dayak)', 'tribus', 'Asia', 300,
       ['108.5,-4.0 108.5,6.0 119.5,7.5 119.5,-4.0'], pib_pc=400)
pueblo('celebes', 'Pueblos de Célebes y las Molucas', 'tribus', 'Asia', 350,
       ['118.5,-6.0 118.5,2.0 127.5,2.0 134.5,-8.5 127.0,-8.5'], pib_pc=400)
pueblo('filipinas', 'Austronesios de las Filipinas', 'tribus', 'Asia', 700,
       ['116.5,4.5 116.5,19.5 126.8,19.5 126.8,4.5'], pib_pc=420)
pueblo('taiwan', 'Pueblos austronesios de Taiwán', 'tribus', 'Asia', 150,
       ['119.8,21.8 119.8,25.4 122.2,25.4 122.2,21.8'], pib_pc=420)

# ───────────────────────── JAPÓN ─────────────────────────
pueblo('wa', 'Wa (cultura yayoi)', 'confederación tribal', 'Asia', 2800,
       ['129.0,30.0 129.0,36.2 134.5,36.5 137.5,36.8 137.5,34.0 132.0,30.0'], cap=('Yoshinogari', 130.4, 33.3), moneda='TRQ', pib_pc=560)
pueblo('yayoi_este', 'Pueblos yayoi del este (Kanto, Chubu y Tohoku sur)', 'tribus', 'Asia', 900,
       ['137.0,34.5 137.0,40.0 142.0,40.0 142.0,34.5'], pib_pc=520)
pueblo('emishi', 'Emishi y pueblos del norte de Honshu', 'tribus', 'Asia', 150,
       ['139.0,38.5 139.0,41.8 142.5,41.8 142.5,38.5'], pib_pc=420)
pueblo('ainu', 'Pueblos del Epi-Jomon y okhotsk (Hokkaido)', 'cazadores-recolectores', 'Asia', 80,
       ['139.5,41.5 139.5,45.8 146.0,45.8 146.0,41.5'], pib_pc=380)
pueblo('ryukyu', 'Pueblos de las islas Ryukyu', 'tribus', 'Asia', 60,
       ['122.5,24.0 122.5,30.0 131.5,30.0 131.5,24.0'], pib_pc=420)

# ───────────────────────── OCEANÍA ─────────────────────────
pueblo('abo_norte', 'Pueblos aborígenes del norte de Australia', 'cazadores-recolectores', 'Oceanía', 200,
       ['125.0,-17.5 125.0,-11.0 142.5,-10.5 145.5,-14.5 142.0,-19.0 135.0,-19.0 129.0,-18.0'], pib_pc=330)
pueblo('abo_este', 'Pueblos aborígenes del este de Australia', 'cazadores-recolectores', 'Oceanía', 350,
       ['142.0,-19.0 145.5,-14.5 146.5,-19.0 153.5,-25.5 153.5,-32.0 150.0,-37.5 146.0,-38.5 141.0,-34.5 141.0,-26.0'], pib_pc=330)
pueblo('abo_sur', 'Pueblos aborígenes del sur de Australia (Murray y Nullarbor)', 'cazadores-recolectores', 'Oceanía', 150,
       ['129.0,-31.5 129.0,-34.5 134.0,-35.0 138.0,-36.5 141.0,-38.5 141.0,-34.5 140.0,-31.0 135.0,-31.0'], pib_pc=330)
pueblo('abo_oeste', 'Pueblos aborígenes del suroeste de Australia (noongar)', 'cazadores-recolectores', 'Oceanía', 80,
       ['113.5,-35.5 113.5,-26.0 118.0,-26.0 123.0,-30.0 129.0,-33.5 123.5,-34.5 118.0,-35.2'], pib_pc=330)
pueblo('abo_centro', 'Pueblos aborígenes del desierto central', 'cazadores-recolectores', 'Oceanía', 60,
       ['118.0,-26.0 123.0,-30.0 129.0,-31.5 140.0,-31.0 141.0,-26.0 135.0,-19.0 129.0,-18.0 122.0,-21.0'], pib_pc=300)
pueblo('tasmania', 'Pueblos aborígenes de Tasmania', 'cazadores-recolectores', 'Oceanía', 6,
       ['144.5,-43.8 144.5,-40.5 148.5,-40.5 148.5,-43.8'], pib_pc=300)
pueblo('papues_altos', 'Papúes de las tierras altas de Nueva Guinea', 'tribus', 'Oceanía', 600,
       ['137.0,-6.0 137.0,-3.5 141.0,-3.5 147.0,-6.0 147.0,-8.0 141.0,-7.5'], pib_pc=420)
pueblo('papues_costa', 'Papúes y austronesios de la costa de Nueva Guinea', 'tribus', 'Oceanía', 500,
       ['131.0,-8.5 131.0,-0.5 141.0,-2.0 147.5,-4.0 152.0,-5.0 151.0,-10.8 142.0,-10.0 138.0,-8.5'], pib_pc=420)
pueblo('melanesia', 'Melanesios (cultura lapita): Bismarck, Salomón y Vanuatu', 'tribus', 'Oceanía', 450,
       ['148.0,-6.5 148.0,-1.0 156.5,-1.0 163.0,-10.5 170.5,-13.0 170.5,-20.5 165.5,-22.8 160.0,-12.0 152.0,-8.5'], pib_pc=420)
pueblo('fiji_polinesia', 'Pueblos de Fiyi, Tonga y Samoa (cultura lapita)', 'tribus', 'Oceanía', 90,
       ['176.5,-21.0 176.5,-16.0 180.0,-16.0 180.0,-21.0', '-180.0,-21.0 -180.0,-12.5 -171.0,-12.5 -171.0,-22.5'], pib_pc=440)
pueblo('micronesia', 'Micronesios (Marianas, Palaos, Yap y Carolinas)', 'tribus', 'Oceanía', 70,
       ['130.5,5.5 130.5,10.5 140.0,10.5 140.0,5.5', '143.5,12.5 143.5,21.0 146.5,21.0 146.5,12.5', '150.5,4.5 150.5,9.0 163.5,9.0 163.5,4.5'], pib_pc=400)

# ───────────────────────── AMÉRICA DEL NORTE ─────────────────────────
pueblo('hopewell', 'Cultura Hopewell', 'cultura', 'América del Norte', 450,
       ['-93.0,37.0 -93.0,43.0 -85.0,43.5 -79.0,41.5 -79.0,37.5 -84.0,36.5 -90.0,36.0'], cap=('Chillicothe', -82.97, 39.33), pib_pc=520, div='Territorios')
pueblo('sureste_na', 'Pueblos del sureste (cultura Marksville y Swift Creek)', 'cultura', 'América del Norte', 350,
       ['-95.0,29.5 -95.0,36.0 -90.0,36.0 -84.0,36.5 -79.0,35.0 -76.5,34.5 -80.0,31.0 -81.0,27.0 -83.0,28.5 -88.0,30.5'], pib_pc=480)
pueblo('noreste_na', 'Pueblos del noreste (algonquinos e iroqueses tempranos)', 'tribus', 'América del Norte', 250,
       ['-79.0,37.5 -79.0,43.0 -74.0,45.5 -66.0,47.5 -64.0,45.0 -70.0,41.5 -75.0,38.0'], pib_pc=430)
pueblo('subartico', 'Pueblos del Subártico (atabascos y algonquinos septentrionales)', 'cazadores-recolectores', 'América del Norte', 120,
       ['-135.0,57.0 -135.0,66.5 -120.0,68.5 -100.0,66.0 -85.0,64.0 -78.0,59.5 -62.0,55.0 -60.0,52.5 -66.0,49.5 -79.0,47.5 -93.0,49.0 -110.0,52.0 -125.0,55.0'], pib_pc=350)
pueblo('artico', 'Pueblos del Ártico (cultura Dorset y paleoesquimales)', 'cazadores-recolectores', 'América del Norte', 25,
       ['-166.0,64.0 -166.0,71.5 -141.0,70.0 -120.0,72.5 -95.0,73.0 -80.0,73.5 -65.0,66.5 -53.0,64.0 -62.0,58.5 -78.0,60.5 -90.0,64.5 -110.0,67.5 -135.0,68.5 -150.0,66.0'], pib_pc=330)
pueblo('aleutianos', 'Aleutas y pueblos del suroeste de Alaska', 'cazadores-recolectores', 'América del Norte', 20,
       ['-180.0,51.0 -180.0,54.5 -158.0,60.5 -152.0,59.0 -165.0,54.0 -172.0,52.0'], pib_pc=340)
pueblo('alaska_int', 'Pueblos del interior de Alaska (atabascos)', 'cazadores-recolectores', 'América del Norte', 20,
       ['-166.0,60.5 -166.0,66.0 -141.0,69.0 -141.0,60.0'], pib_pc=340)
pueblo('noroeste_na', 'Pueblos de la costa noroeste (tlingit, haida y salish)', 'tribus', 'América del Norte', 180,
       ['-135.5,53.0 -135.5,59.5 -130.0,59.5 -125.0,54.5 -121.5,48.5 -124.5,42.5 -127.0,43.0 -130.5,49.0'], pib_pc=480)
pueblo('california', 'Pueblos de California (chumash, pomo y yokuts)', 'tribus', 'América del Norte', 250,
       ['-124.8,32.5 -124.8,42.0 -119.5,42.0 -118.0,37.5 -114.5,33.0 -117.0,32.5'], pib_pc=420)
pueblo('gran_cuenca', 'Pueblos de la Gran Cuenca y la meseta', 'cazadores-recolectores', 'América del Norte', 120,
       ['-121.5,42.0 -121.5,49.5 -112.0,49.5 -108.0,43.0 -107.0,38.0 -114.5,36.0 -118.0,37.5 -119.5,42.0'], pib_pc=350)
pueblo('llanuras', 'Pueblos de las Grandes Llanuras (cazadores de bisontes)', 'cazadores-recolectores', 'América del Norte', 160,
       ['-112.0,49.5 -95.0,49.0 -93.0,43.0 -93.0,37.0 -95.0,32.0 -102.0,30.5 -104.5,36.0 -108.0,43.0'], pib_pc=360)
pueblo('anasazi', 'Cultura anasazi (basketmaker)', 'cultura', 'América del Norte', 60,
       ['-112.0,34.5 -112.0,38.0 -106.0,38.0 -105.0,34.0 -108.0,33.5'], pib_pc=430)
pueblo('hohokam_mogollon', 'Culturas hohokam y mogollón', 'cultura', 'América del Norte', 70,
       ['-114.5,31.0 -114.5,34.5 -108.0,34.5 -105.0,31.5 -108.0,31.0'], pib_pc=430)
pueblo('norte_mexico', 'Pueblos chichimecas del norte de México', 'cazadores-recolectores', 'América del Norte', 250,
       ['-115.5,23.0 -115.5,31.0 -105.0,31.0 -101.0,29.5 -97.5,26.5 -99.5,23.5 -103.0,22.0 -107.0,23.0'], pib_pc=380)

# ───────────────────────── MESOAMÉRICA Y EL CARIBE ─────────────────────────
pueblo('occidente_mx', 'Culturas de las tumbas de tiro del Occidente de México', 'cultura', 'América del Norte', 250,
       ['-106.0,18.5 -106.0,21.8 -102.0,21.8 -101.0,19.5 -102.5,18.0'], cap=('Teuchitlán', -103.85, 20.69), pib_pc=520)
pueblo('valle_mexico', 'Cuicuilco y Cholula (Altiplano central)', 'ciudades-estado', 'América del Norte', 250,
       ['-100.5,18.5 -100.5,20.5 -97.2,20.5 -97.2,18.5'], cap=('Cuicuilco', -99.18, 19.30), pib_pc=540)
pueblo('epiolmeca', 'Cultura epiolmeca y pueblos de la costa del Golfo', 'cultura', 'América del Norte', 250,
       ['-97.5,17.5 -97.5,22.5 -94.0,22.5 -93.5,17.5'], cap=('La Mojarra', -95.9, 18.55), pib_pc=520)
pueblo('mixteca', 'Pueblos mixtecos (Ñuiñe)', 'ciudades-estado', 'América del Norte', 200,
       ['-98.5,16.5 -98.5,18.5 -96.8,18.5 -96.8,16.5'], pib_pc=520)
pueblo('huasteca', 'Huastecos y pueblos del Pánuco', 'tribus', 'América del Norte', 120,
       ['-99.5,20.5 -99.5,23.5 -97.2,23.5 -97.2,20.5'], pib_pc=480)
pueblo('intermedio_ca', 'Pueblos del Istmo Centroamericano (lencas, chibchas y ulúas)', 'tribus', 'América del Norte', 700,
       ['-92.0,12.5 -92.0,15.5 -87.5,16.2 -83.0,15.0 -82.5,10.5 -77.5,8.0 -77.5,7.0 -83.5,8.5 -88.0,11.5'], pib_pc=470)
pueblo('antillas_mayores', 'Pueblos arcaicos de las Antillas Mayores (ciboney y casimiroides)', 'cazadores-recolectores', 'América del Norte', 60,
       ['-85.0,19.5 -85.0,23.5 -74.0,23.0 -68.5,20.5 -68.5,17.5 -75.5,17.5'], pib_pc=380)
pueblo('saladoides', 'Saladoides de Puerto Rico y las Antillas Menores', 'tribus', 'América del Norte', 40,
       ['-67.5,17.5 -67.5,19.0 -64.0,19.0 -60.5,16.5 -60.5,10.5 -63.5,10.5 -65.0,17.0'], pib_pc=420)

# ───────────────────────── AMÉRICA DEL SUR ─────────────────────────
pueblo('muiscas', 'Muiscas (periodo Herrera, altiplano cundiboyacense)', 'tribus', 'América del Sur', 250,
       ['-74.8,4.2 -74.8,6.8 -72.2,7.0 -72.2,4.2'], cap=('Bacatá', -74.07, 4.6), pib_pc=500)
pueblo('san_agustin', 'San Agustín, Tierradentro y el alto Magdalena', 'cultura', 'América del Sur', 150,
       ['-77.5,0.5 -77.5,4.2 -74.8,4.2 -74.8,0.5'], cap=('San Agustín', -76.29, 1.88), pib_pc=500)
pueblo('calima_quimbaya', 'Calima, Quimbaya y el Cauca medio', 'cultura', 'América del Sur', 200,
       ['-77.0,4.2 -77.0,6.5 -74.8,6.5 -74.8,4.2'], pib_pc=500)
pueblo('caribe_colombiano', 'Zenúes y pueblos del Caribe colombiano (Tairona temprano)', 'tribus', 'América del Sur', 300,
       ['-77.5,6.5 -77.5,11.5 -72.0,12.5 -72.0,7.0 -74.8,6.8'], pib_pc=480)
pueblo('tumaco_tolita', 'Culturas Tumaco-La Tolita, Jama-Coaque y Guangala', 'cultura', 'América del Sur', 300,
       ['-80.5,-3.0 -80.5,3.0 -77.5,3.0 -77.5,-3.0'], cap=('La Tolita', -79.0, 1.1), pib_pc=500)
pueblo('andes_ecuador', 'Pueblos del altiplano ecuatoriano (Cerro Narrío y Tuncahuán)', 'tribus', 'América del Sur', 250,
       ['-79.8,-4.5 -79.8,0.5 -77.0,0.5 -77.0,-4.5'], pib_pc=480)
pueblo('venezuela_arawak', 'Pueblos arawak del Orinoco y Venezuela (barrancoides)', 'tribus', 'América del Sur', 400,
       ['-72.0,7.0 -72.0,12.0 -61.0,10.8 -60.0,7.5 -66.0,5.0 -70.0,5.5'], pib_pc=430)
pueblo('guayanas', 'Pueblos de las Guayanas (caribes y arawak)', 'tribus', 'América del Sur', 250,
       ['-61.5,1.5 -61.5,7.5 -51.5,5.8 -51.5,2.0'], pib_pc=420)
pueblo('moche_salinar', 'Cultura Salinar y Cupisnique (costa norte del Perú)', 'cultura', 'América del Sur', 350,
       ['-81.5,-9.8 -81.5,-3.5 -78.0,-5.5 -77.5,-9.8'], cap=('Cerro Arena', -78.9, -8.1), pib_pc=520)
pueblo('recuay_cajamarca', 'Recuay, Cajamarca y la sierra norte', 'cultura', 'América del Sur', 450,
       ['-79.5,-10.5 -79.5,-5.0 -76.8,-5.5 -76.5,-10.5'], pib_pc=480)
pueblo('lima_costa', 'Cultura Lima y la costa central', 'cultura', 'América del Sur', 250,
       ['-78.5,-13.5 -78.5,-9.8 -75.5,-9.8 -75.5,-13.5'], pib_pc=500)
pueblo('paracas_nazca', 'Paracas y Nazca (costa sur del Perú)', 'cultura', 'América del Sur', 300,
       ['-77.0,-16.5 -77.0,-13.5 -73.5,-13.5 -73.5,-16.5'], cap=('Cahuachi', -75.12, -14.82), pib_pc=520)
pueblo('altiplano', 'Pucará, Yaya-Mama y el altiplano del Titicaca', 'cultura', 'América del Sur', 500,
       ['-72.5,-18.5 -72.5,-13.0 -68.0,-13.0 -67.5,-18.5'], cap=('Pucará', -70.37, -15.03), pib_pc=470)
pueblo('amazonia_arawak', 'Pueblos de la Amazonía (arawak, caribe y tupí)', 'tribus', 'América del Sur', 1200,
       ['-76.0,-12.0 -76.0,2.0 -62.0,5.0 -52.0,1.5 -50.0,-5.0 -54.0,-9.0 -64.0,-12.5'], pib_pc=380)
pueblo('marajoara', 'Cultura marajoara (isla de Marajó)', 'cultura', 'América del Sur', 100,
       ['-51.5,-1.8 -51.5,0.8 -48.2,0.8 -48.2,-1.8'], pib_pc=450)
pueblo('brasil_je', 'Pueblos jê y del Brasil central', 'tribus', 'América del Sur', 500,
       ['-54.0,-9.0 -54.0,-18.5 -46.0,-21.0 -41.0,-14.0 -42.0,-5.5 -48.0,-5.0 -50.0,-5.0'], pib_pc=380)
pueblo('tupi_costa', 'Pueblos de la costa atlántica (sambaquis y tupíes)', 'tribus', 'América del Sur', 350,
       ['-48.0,-30.0 -48.0,-21.0 -41.0,-18.0 -35.0,-5.0 -39.0,-3.5 -41.0,-14.0 -46.0,-21.0 -50.0,-27.0'], pib_pc=390)
pueblo('chaco_guarani', 'Pueblos del Chaco y guaraníes', 'tribus', 'América del Sur', 400,
       ['-64.0,-27.5 -64.0,-18.5 -54.0,-18.5 -54.0,-27.0 -56.5,-30.0 -60.0,-31.5'], pib_pc=380)
pueblo('noa_diaguita', 'Cultura Tafí, diaguitas y el noroeste argentino', 'cultura', 'América del Sur', 250,
       ['-70.5,-33.0 -70.5,-22.0 -64.0,-22.0 -64.0,-33.0'], pib_pc=440)
pueblo('atacama_chile', 'Atacameños y pueblos del norte de Chile', 'tribus', 'América del Sur', 120,
       ['-71.0,-27.5 -71.0,-18.5 -67.5,-18.5 -67.5,-27.5'], pib_pc=400)
pueblo('mapuche', 'Pueblos del sur de Chile (protomapuches, cultura Pitrén)', 'tribus', 'América del Sur', 300,
       ['-74.5,-42.5 -74.5,-30.0 -70.5,-33.0 -70.5,-42.5'], pib_pc=420)
pueblo('pampa_patagonia', 'Cazadores de la Pampa y la Patagonia (tehuelches)', 'cazadores-recolectores', 'América del Sur', 150,
       ['-70.5,-42.5 -70.5,-33.0 -64.0,-33.0 -56.5,-36.5 -57.5,-41.0 -63.5,-46.0 -69.5,-52.0'], pib_pc=340)
pueblo('fuego', 'Pueblos de Tierra del Fuego (selknam y yaganes)', 'cazadores-recolectores', 'América del Sur', 12,
       ['-75.0,-56.0 -75.0,-52.0 -66.0,-52.0 -66.0,-56.0'], pib_pc=300)
