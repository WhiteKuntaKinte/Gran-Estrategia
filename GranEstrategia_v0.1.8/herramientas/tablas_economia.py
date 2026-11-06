# -*- coding: utf-8 -*-
"""
Perfiles económicos aproximados (0.1.7.9). Cifras de orden de magnitud, base ~2024-2026; NO son estadísticas oficiales.
Formato por línea:  CLAVE | cultivos principales | carne producida>exportada | materias primas más explotadas | rubros con peso relativo
Los pesos de los rubros se normalizan a 100 %. 'p' = dato propio del país o región; 'r' = estimación por arquetipo regional.
"""

PAISES = """
USA|Maíz,Soya,Trigo|Res>Res|Petróleo,Gas natural,Carbón|Servicios 52,Finanzas e inmobiliario 21,Manufactura 11,Comercio 6,Petróleo y gas 4,Agricultura 2,Otros 4
BRA|Soya,Caña de azúcar,Café|Pollo>Res|Hierro,Petróleo,Madera|Servicios 60,Manufactura 11,Agroindustria 9,Minería y petróleo 8,Construcción 4,Comercio 8
MEX|Maíz,Aguacate,Sorgo|Res>Res|Petróleo,Plata,Cobre|Servicios 58,Manufactura 21,Construcción 6,Minería y petróleo 5,Agricultura 4,Turismo 6
FRA|Trigo,Remolacha,Vid|Pollo>Res|Madera,Sal,Energía nuclear|Servicios 70,Manufactura 10,Finanzas 6,Turismo 7,Agricultura 2,Construcción 5
COL|Café,Palma de aceite,Caña de azúcar|Res>Res|Petróleo,Carbón,Oro|Servicios 55,Petróleo y minería 13,Manufactura 11,Agricultura 8,Construcción 6,Comercio 7
ARG|Soya,Maíz,Trigo|Res>Res|Litio,Gas natural,Petróleo|Servicios 58,Agroindustria 17,Manufactura 12,Minería y energía 6,Construcción 3,Otros 4
CAN|Trigo,Canola,Maíz|Res>Cerdo|Petróleo,Gas natural,Madera|Servicios 62,Petróleo y gas 9,Manufactura 10,Minería 4,Construcción 7,Agroindustria 4,Madera 2,Otros 2
PER|Papa,Arroz,Caña de azúcar|Pollo|Cobre,Oro,Pesca|Servicios 52,Minería 14,Manufactura 12,Agricultura 8,Construcción 7,Pesca 3,Otros 4
VEN|Maíz,Caña de azúcar,Arroz|Res|Petróleo,Hierro,Oro|Servicios 40,Petróleo 30,Manufactura 12,Comercio 9,Agricultura 6,Otros 3
CHL|Uva,Manzana,Trigo|Pollo>Cerdo|Cobre,Litio,Salmón|Servicios 55,Minería 14,Manufactura 10,Agroindustria y vino 6,Pesca y salmón 4,Construcción 6,Otros 5
GTM|Caña de azúcar,Banano,Café|Pollo|Níquel,Petróleo,Cardamomo|Servicios 58,Agricultura 10,Manufactura 14,Comercio 8,Remesas y otros 10
ECU|Banano,Cacao,Palma de aceite|Pollo|Petróleo,Camarón,Oro|Servicios 52,Petróleo y minería 11,Agricultura y pesca 10,Manufactura 12,Construcción 6,Otros 9
BOL|Soya,Caña de azúcar,Quinua|Res|Gas natural,Zinc,Litio|Servicios 47,Gas y minería 14,Agricultura 13,Manufactura 11,Construcción 5,Otros 10
HTI|Mango,Caña de azúcar,Café|Cerdo|Bauxita,Mármol|Servicios 50,Agricultura 20,Remesas e informal 15,Manufactura 8,Otros 7
DOM|Caña de azúcar,Banano,Cacao|Pollo|Oro,Níquel,Ámbar|Servicios 55,Turismo 15,Manufactura 12,Construcción 8,Minería 4,Agricultura 6
HND|Café,Banano,Palma de aceite|Pollo|Plata,Zinc,Madera|Servicios 55,Agricultura 12,Manufactura 18,Remesas y otros 10,Construcción 5
CUB|Caña de azúcar,Tabaco,Arroz|Cerdo|Níquel,Petróleo,Sal|Servicios 70,Turismo 8,Manufactura 8,Agricultura 4,Minería 4,Otros 6
NIC|Café,Frijol,Maní|Res>Res|Oro,Plata,Madera|Servicios 50,Agricultura 17,Manufactura 15,Minería 5,Remesas y otros 13
PRY|Soya,Maíz,Trigo|Res>Res|Energía hidroeléctrica|Servicios 45,Agroindustria 20,Energía hidroeléctrica 8,Manufactura 12,Construcción 7,Otros 8
SLV|Café,Caña de azúcar,Maíz|Pollo|Sal,Energía geotérmica|Servicios 62,Manufactura 18,Remesas y otros 10,Agricultura 5,Construcción 5
CRI|Banano,Piña,Café|Res>Res|Energía renovable|Servicios 62,Manufactura y dispositivos médicos 20,Turismo 8,Agricultura 5,Construcción 5
PAN|Banano,Piña,Caña de azúcar|Res|Cobre,Canal interoceánico|Servicios 70,Canal y logística 12,Minería 8,Construcción 5,Agricultura 3,Otros 2
URY|Soya,Arroz,Trigo|Res>Res|Madera y celulosa|Servicios 60,Agroindustria 14,Manufactura 12,Madera y celulosa 6,Construcción 4,Otros 4
JAM|Caña de azúcar,Banano,Café|Pollo|Bauxita,Alúmina|Servicios 65,Turismo 16,Minería 5,Manufactura 8,Agricultura 6
TTO|Cacao,Caña de azúcar|Pollo|Petróleo,Gas natural|Petróleo y gas 40,Servicios 35,Manufactura (petroquímica) 15,Otros 10
GUY|Arroz,Caña de azúcar|Pollo|Petróleo,Oro,Bauxita|Petróleo 45,Agricultura 12,Minería 10,Servicios 25,Otros 8
SUR|Arroz,Banano|Pollo|Oro,Petróleo,Bauxita|Minería 35,Servicios 40,Agricultura 10,Petróleo 10,Otros 5
BLZ|Caña de azúcar,Banano,Cítricos|Pollo|Petróleo,Madera|Servicios 60,Turismo 20,Agricultura 12,Otros 8
GRL|—|—|Pesca,Minerales (potencial)|Pesca 45,Servicios públicos 40,Minería 5,Turismo 10
IND|Arroz,Trigo,Caña de azúcar|Búfalo>Búfalo|Carbón,Hierro,Gemas|Servicios 50,Manufactura 14,Agricultura 17,Construcción 8,Minería 3,Comercio 8
CHN|Arroz,Trigo,Maíz|Cerdo>Cerdo|Carbón,Tierras raras,Hierro|Manufactura 27,Servicios 42,Construcción 6,Agricultura 7,Minería y energía 6,Finanzas e inmobiliario 12
IDN|Palma de aceite,Arroz,Caucho|Pollo|Carbón,Níquel,Petróleo|Servicios 43,Manufactura 20,Minería 8,Agricultura 12,Construcción 10,Comercio 7
PAK|Trigo,Arroz,Caña de azúcar|Búfalo>Res|Gas natural,Sal,Carbón|Servicios 55,Agricultura 23,Manufactura (textil) 13,Construcción 3,Otros 6
BGD|Arroz,Yute,Papa|Res|Gas natural|Manufactura (textil) 24,Servicios 50,Agricultura 11,Construcción 8,Remesas y otros 7
RUS|Trigo,Cebada,Girasol|Cerdo>Pollo|Petróleo,Gas natural,Carbón,Metales|Servicios 49,Petróleo y gas 15,Manufactura 14,Minería 6,Agricultura 4,Construcción 5,Otros 7
JPN|Arroz,Papa,Hortalizas|Cerdo|Pesca|Servicios 69,Manufactura 20,Construcción 6,Agricultura 1,Otros 4
PHL|Arroz,Coco,Caña de azúcar|Cerdo|Níquel,Oro,Cobre|Servicios 62,Manufactura 18,Agricultura 9,Remesas y otros 6,Minería 1,Construcción 4
VNM|Arroz,Café,Caucho|Cerdo|Carbón,Petróleo,Tierras raras|Servicios 42,Manufactura 25,Agricultura 12,Construcción 6,Minería 3,Comercio 12
IRN|Trigo,Pistacho,Arroz|Pollo|Petróleo,Gas natural,Cobre|Servicios 45,Petróleo y gas 18,Manufactura 14,Agricultura 12,Minería 4,Construcción 7
TUR|Trigo,Avellana,Algodón|Pollo|Boro,Mármol,Carbón|Servicios 55,Manufactura 22,Agricultura 6,Construcción 6,Turismo 7,Minería 4
THA|Arroz,Caucho,Yuca|Pollo>Pollo|Gas natural,Estaño|Servicios 56,Manufactura 26,Agricultura 8,Turismo 6,Minería 2,Construcción 2
MMR|Arroz,Frijol,Caña de azúcar|Pollo|Gas natural,Jade,Madera|Agricultura 22,Servicios 38,Manufactura 20,Minería 8,Construcción 7,Otros 5
KOR|Arroz,Hortalizas|Cerdo|Pesca|Servicios 58,Manufactura (electrónica) 27,Construcción 5,Finanzas 8,Agricultura 2
IRQ|Dátil,Trigo,Cebada|Cordero|Petróleo,Gas|Petróleo 45,Servicios 35,Construcción 6,Agricultura 5,Manufactura 4,Otros 5
AFG|Trigo,Uva,Frutos secos|Cordero|Litio,Cobre,Gemas|Agricultura 33,Servicios 40,Minería 6,Construcción 8,Manufactura 8,Otros 5
YEM|Sorgo,Café,Dátil|Cabra|Petróleo,Sal|Servicios 45,Agricultura 18,Petróleo 12,Comercio 15,Otros 10
SAU|Dátil,Trigo,Forraje|Pollo|Petróleo,Gas natural,Oro|Petróleo y gas 38,Servicios 38,Manufactura 12,Construcción 6,Agricultura 3,Otros 3
UZB|Algodón,Trigo,Frutas|Res|Gas natural,Oro,Uranio|Agricultura 25,Servicios 36,Minería y gas 12,Manufactura 14,Construcción 9,Otros 4
MYS|Palma de aceite,Caucho,Arroz|Pollo|Petróleo,Gas natural,Estaño|Servicios 54,Manufactura (electrónica) 23,Petróleo y gas 7,Agricultura (palma) 7,Construcción 3,Otros 6
NPL|Arroz,Maíz,Caña de azúcar|Búfalo|Energía hidroeléctrica|Agricultura 24,Servicios 50,Remesas y otros 12,Construcción 7,Manufactura 5,Turismo 2
PRK|Arroz,Maíz,Papa|Cerdo|Carbón,Hierro|Agricultura 22,Manufactura 30,Minería 14,Servicios 25,Otros 9
SYR|Trigo,Algodón,Olivo|Cordero|Petróleo,Fosfatos|Agricultura 25,Servicios 40,Manufactura 12,Petróleo 8,Otros 15
TWN|Arroz,Té,Hortalizas|Cerdo|Pesca|Manufactura (semiconductores) 36,Servicios 58,Agricultura 2,Construcción 4
LKA|Té,Arroz,Coco|Pollo|Grafito,Gemas|Servicios 58,Manufactura (textil) 17,Agricultura (té) 8,Remesas y turismo 10,Construcción 7
KAZ|Trigo,Cebada,Girasol|Res>Res|Petróleo,Uranio,Carbón|Servicios 50,Petróleo y gas 20,Minería 8,Manufactura 11,Agricultura 5,Construcción 6
KHM|Arroz,Yuca,Caucho|Cerdo|Arena,Madera|Servicios 40,Manufactura (textil) 22,Agricultura 20,Construcción 12,Turismo 6
ARE|Dátil|Pollo|Petróleo,Gas natural|Petróleo y gas 25,Servicios y finanzas 45,Comercio y logística 15,Turismo 7,Construcción 8
JOR|Tomate,Olivo,Pepino|Cordero|Fosfatos,Potasa|Servicios 62,Manufactura 18,Minería 4,Agricultura 5,Otros 11
ISR|Cítricos,Aguacate,Hortalizas|Pollo|Potasa,Gas natural|Servicios 70,Tecnología 15,Manufactura 8,Construcción 5,Agricultura 2
LAO|Arroz,Maíz,Café|Búfalo|Energía hidroeléctrica,Cobre,Oro|Servicios 40,Agricultura 17,Energía y minería 18,Manufactura 12,Construcción 8,Otros 5
MNG|Trigo,Papa|Cordero,Cabra|Carbón,Cobre,Oro|Minería 28,Servicios 40,Ganadería 12,Construcción 8,Manufactura 6,Otros 6
SGP|—|—|—|Servicios y finanzas 65,Manufactura (electrónica y química) 22,Comercio y logística 8,Construcción 4,Otros 1
HKG|—|—|—|Servicios y finanzas 85,Comercio 10,Manufactura 1,Otros 4
DEU|Trigo,Remolacha,Cebada|Cerdo>Cerdo|Lignito,Potasa,Sal|Servicios 63,Manufactura (automotriz y maquinaria) 22,Construcción 6,Finanzas 4,Agricultura 1,Otros 4
GBR|Trigo,Cebada,Colza|Cordero>Cordero|Petróleo,Gas natural,Carbón|Servicios 72,Finanzas 9,Manufactura 9,Construcción 6,Petróleo y gas 1,Otros 3
ITA|Uva,Trigo,Olivo|Pollo>Cerdo|Mármol,Gas natural|Servicios 66,Manufactura 18,Turismo 6,Construcción 5,Agricultura 2,Otros 3
ESP|Cebada,Olivo,Vid|Cerdo>Cerdo|Pizarra,Cobre,Sal|Servicios 68,Turismo 12,Manufactura 12,Construcción 6,Agricultura 3
UKR|Trigo,Maíz,Girasol|Pollo|Carbón,Hierro,Gas natural|Servicios 55,Agroindustria 16,Manufactura 10,Minería 6,Construcción 3,Otros 10
POL|Trigo,Centeno,Papa|Pollo>Pollo|Carbón,Cobre,Plata|Servicios 55,Manufactura 20,Construcción 7,Agricultura 3,Minería 3,Otros 12
ROU|Maíz,Trigo,Girasol|Cerdo|Petróleo,Sal,Madera|Servicios 56,Manufactura 21,Construcción 7,Agricultura 4,Energía 4,Otros 8
NLD|Papa,Flores,Hortalizas|Cerdo>Cerdo|Gas natural|Servicios 72,Manufactura 12,Logística y puerto 6,Agricultura (horticultura) 2,Energía 3,Otros 5
BEL|Remolacha,Papa,Trigo|Cerdo|—|Servicios 75,Manufactura (química) 14,Construcción 5,Agricultura 1,Otros 5
PRT|Vid,Olivo,Maíz|Cerdo|Corcho,Cobre,Litio|Servicios 70,Turismo 12,Manufactura 12,Construcción 5,Agricultura 2
CZE|Trigo,Cebada,Remolacha|Cerdo|Carbón,Cuarzo|Servicios 56,Manufactura (automotriz) 28,Construcción 6,Agricultura 2,Otros 8
SWE|Cebada,Trigo,Avena|Res|Hierro,Madera,Cobre|Servicios 67,Manufactura 16,Madera y papel 4,Minería 1,Construcción 6,Otros 6
GRC|Olivo,Algodón,Trigo|Cordero|Bauxita,Mármol|Servicios 70,Turismo 15,Manufactura 8,Agricultura 4,Construcción 3
HUN|Maíz,Trigo,Girasol|Cerdo|Bauxita,Gas natural|Servicios 56,Manufactura (automotriz) 24,Construcción 6,Agricultura 4,Otros 10
AUT|Trigo,Cebada,Remolacha|Cerdo|Madera,Magnesita|Servicios 66,Manufactura 19,Turismo 6,Construcción 7,Agricultura 1,Otros 1
CHE|Trigo,Remolacha,Papa|Res|Agua,Sal|Servicios y finanzas 72,Manufactura (farma y relojes) 20,Construcción 5,Agricultura 1,Otros 2
BLR|Papa,Remolacha,Trigo|Res|Potasa,Petróleo|Servicios 49,Manufactura 26,Agricultura 8,Construcción 6,Otros 11
SRB|Maíz,Frambuesa,Trigo|Cerdo|Carbón,Cobre|Servicios 55,Manufactura 20,Agricultura 6,Construcción 6,Minería 4,Otros 9
BGR|Trigo,Girasol,Maíz|Cerdo|Carbón,Cobre|Servicios 62,Manufactura 18,Construcción 5,Agricultura 4,Energía 4,Otros 7
DNK|Cebada,Trigo,Colza|Cerdo>Cerdo|Petróleo,Gas natural|Servicios 70,Manufactura (farma) 18,Construcción 5,Agricultura 1,Energía 2,Otros 4
FIN|Cebada,Avena,Trigo|Cerdo|Madera,Hierro,Níquel|Servicios 64,Manufactura 18,Madera y papel 6,Construcción 6,Otros 6
NOR|Cebada,Papa,Avena|Cordero|Petróleo,Gas natural,Salmón|Petróleo y gas 20,Servicios 55,Pesca y salmón 4,Manufactura 8,Construcción 5,Otros 8
IRL|Cebada,Papa,Trigo|Res>Res|Zinc,Plomo|Servicios y tecnología 55,Manufactura (farma) 35,Agroindustria 3,Construcción 4,Otros 3
SVK|Trigo,Maíz,Colza|Cerdo|Magnesita|Servicios 58,Manufactura (automotriz) 25,Construcción 7,Agricultura 3,Otros 7
HRV|Maíz,Trigo,Uva|Cerdo|Petróleo,Madera|Servicios 66,Turismo 15,Manufactura 12,Construcción 5,Agricultura 3
LTU|Trigo,Colza,Papa|Cerdo|Ámbar|Servicios 62,Manufactura 20,Construcción 7,Agricultura 3,Otros 8
AUS|Trigo,Cebada,Caña de azúcar|Res>Res|Hierro,Carbón,Oro,Litio|Servicios 66,Minería 12,Manufactura 6,Construcción 8,Agricultura 3,Finanzas 5
PNG|Palma de aceite,Café,Cacao|Cerdo|Oro,Cobre,Gas natural|Minería y gas 30,Agricultura 22,Servicios 33,Madera 5,Otros 10
NZL|Kiwi,Uva,Cebada|Cordero>Cordero|Madera,Gas natural,Oro|Servicios 68,Agroindustria y lácteos 10,Manufactura 9,Construcción 6,Madera 3,Turismo 4
FJI|Caña de azúcar,Coco,Jengibre|Pollo|Oro,Madera,Pesca|Turismo 25,Servicios 40,Agricultura 12,Manufactura 12,Otros 11
NGA|Yuca,Ñame,Cacao|Res|Petróleo,Gas natural|Servicios 52,Agricultura 22,Petróleo y gas 7,Manufactura 9,Comercio 10
ETH|Café,Teff,Maíz|Res|Oro,Potasa|Agricultura 33,Servicios 38,Manufactura 6,Construcción 15,Otros 8
EGY|Trigo,Arroz,Caña de azúcar|Búfalo|Petróleo,Gas natural,Fosfatos|Servicios 52,Manufactura 16,Petróleo y gas 8,Agricultura 11,Construcción 6,Turismo 7
COD|Yuca,Café,Banano|Pescado|Cobre,Cobalto,Diamantes,Coltán|Minería 30,Agricultura 20,Servicios 35,Manufactura 5,Otros 10
TZA|Maíz,Yuca,Café|Res|Oro,Gas natural,Gemas|Agricultura 26,Servicios 42,Minería 9,Construcción 13,Manufactura 8,Turismo 2
ZAF|Maíz,Caña de azúcar,Cítricos|Res>Pollo|Oro,Platino,Carbón,Cromo|Servicios 66,Manufactura 12,Minería 8,Finanzas 8,Agricultura 3,Otros 3
KEN|Té,Café,Flores|Res|Soda,Fluorita|Agricultura 22,Servicios 55,Manufactura 8,Construcción 5,Turismo 5,Otros 5
SDN|Sorgo,Sésamo,Goma arábiga|Res>Cabra|Oro,Petróleo|Agricultura 30,Servicios 40,Minería (oro) 12,Petróleo 8,Otros 10
UGA|Café,Plátano,Yuca|Res|Oro,Cobre,Petróleo (potencial)|Agricultura 24,Servicios 45,Manufactura 16,Construcción 10,Minería 3,Otros 2
DZA|Trigo,Dátil,Papa|Cordero|Petróleo,Gas natural|Petróleo y gas 20,Servicios 40,Agricultura 13,Manufactura 8,Construcción 11,Otros 8
AGO|Yuca,Café,Banano|Res|Petróleo,Diamantes|Petróleo 30,Servicios 40,Agricultura 10,Construcción 8,Minería 5,Otros 7
MAR|Trigo,Cítricos,Olivo|Pollo>Cordero|Fosfatos,Zinc,Plata|Servicios 55,Manufactura 16,Agricultura 11,Minería (fosfatos) 4,Turismo 7,Construcción 7
MOZ|Yuca,Caña de azúcar,Maíz|Res|Carbón,Gas natural,Grafito|Agricultura 27,Servicios 40,Minería y gas 15,Manufactura 8,Construcción 5,Otros 5
GHA|Cacao,Yuca,Ñame|Pollo|Oro,Petróleo,Bauxita|Servicios 45,Agricultura (cacao) 20,Minería (oro) 12,Petróleo 6,Manufactura 10,Otros 7
MDG|Arroz,Vainilla,Yuca|Res>Res|Níquel,Grafito,Gemas|Agricultura 25,Servicios 45,Minería 10,Manufactura 12,Otros 8
CIV|Cacao,Anacardo,Caucho|Pollo|Cacao,Oro,Petróleo|Servicios 45,Agricultura (cacao) 20,Manufactura 12,Minería 6,Construcción 8,Otros 9
CMR|Cacao,Banano,Café|Res|Petróleo,Madera,Bauxita|Servicios 45,Agricultura 17,Petróleo y gas 6,Manufactura 14,Madera 4,Otros 14
SEN|Maní,Mijo,Arroz|Res|Fosfatos,Oro,Pesca|Servicios 50,Agricultura 15,Pesca 4,Minería 6,Manufactura 14,Otros 11
ZMB|Maíz,Caña de azúcar,Algodón|Res|Cobre,Cobalto,Esmeraldas|Minería (cobre) 28,Servicios 40,Agricultura 9,Manufactura 8,Construcción 8,Otros 7
ZWE|Maíz,Tabaco,Algodón|Res|Oro,Platino,Litio|Servicios 45,Agricultura 15,Minería 14,Manufactura 14,Otros 12
TUN|Olivo,Trigo,Dátil|Cordero|Fosfatos,Petróleo|Servicios 55,Manufactura 17,Agricultura 10,Turismo 8,Minería y energía 5,Otros 5
LBY|Dátil,Olivo|Cordero|Petróleo,Gas natural|Petróleo 60,Servicios 28,Construcción 5,Otros 7
NAM|Mijo,Maíz|Res>Res|Diamantes,Uranio,Zinc,Pesca|Servicios 55,Minería 12,Agricultura 6,Manufactura 12,Pesca 3,Otros 12
BWA|Sorgo|Res>Res|Diamantes,Cobre,Carbón|Minería (diamantes) 18,Servicios 55,Ganadería 3,Manufactura 6,Construcción 6,Otros 12
GAB|Plátano,Yuca|Cerdo|Petróleo,Manganeso,Madera|Petróleo 35,Servicios 35,Minería 10,Madera 8,Otros 12
GNQ|Cacao,Yuca|Cerdo|Petróleo,Gas natural|Petróleo y gas 60,Servicios 25,Construcción 8,Otros 7
SOM|Sorgo,Banano,Sésamo|Cabra>Camello|Pesca|Ganadería 40,Agricultura 20,Servicios 30,Remesas 10
MUS|Caña de azúcar,Té|Pollo|Pesca|Servicios 65,Turismo 15,Manufactura 12,Agricultura 3,Otros 5
CPV|Maíz,Frijol|Cerdo|Sal,Pesca|Servicios 70,Turismo 20,Pesca 4,Otros 6
"""

# Regiones (estados / departamentos): sobrescriben al país cuando se selecciona una unidad de esa región.
REGIONES = """
USA:Alabama|Algodón,Maní,Soya|Pollo|Carbón,Madera,Caliza|Manufactura 20,Servicios 52,Agroindustria (pollo) 6,Minería 4,Otros 18
USA:Alaska|—|—|Petróleo,Gas natural,Oro,Pesca|Petróleo y gas 45,Servicios públicos 25,Pesca 8,Minería 8,Turismo 6,Otros 8
USA:Arizona|Algodón,Lechuga,Heno|Res|Cobre,Molibdeno|Servicios 60,Manufactura (electrónica) 12,Minería (cobre) 5,Construcción 7,Turismo 6,Otros 10
USA:Arkansas|Arroz,Soya,Algodón|Pollo|Gas natural,Bauxita,Madera|Servicios 55,Agroindustria (pollo y arroz) 14,Manufactura 14,Energía 4,Otros 13
USA:California|Uva,Almendra,Hortalizas|Leche>Res|Petróleo,Oro,Boratos|Servicios y tecnología 60,Finanzas e inmobiliario 17,Manufactura 9,Agricultura 2,Entretenimiento 5,Otros 7
USA:Colorado|Maíz,Trigo,Heno|Res|Petróleo,Gas natural,Molibdeno|Servicios 62,Energía 6,Manufactura 7,Turismo 6,Construcción 7,Otros 12
USA:Connecticut|Tabaco,Viveros|Leche|Piedra triturada|Finanzas y seguros 25,Servicios 52,Manufactura (aeroespacial) 11,Construcción 3,Otros 9
USA:Delaware|Soya,Maíz|Pollo>Pollo|Arena|Finanzas 35,Servicios 40,Manufactura (química) 10,Agroindustria 5,Otros 10
USA:Distrito de Columbia|—|—|—|Gobierno federal 35,Servicios profesionales 35,Finanzas 10,Turismo 8,Otros 12
USA:Florida|Naranja,Caña de azúcar,Tomate|Res|Fosfato,Caliza|Servicios 58,Turismo 12,Inmobiliario 14,Construcción 6,Agricultura 2,Otros 8
USA:Georgia|Maní,Algodón,Pollo|Pollo>Pollo|Caolín,Granito|Servicios 60,Manufactura 12,Logística 8,Agroindustria 5,Otros 15
USA:Hawái|Caña de azúcar,Piña,Café|Res|—|Turismo 22,Servicios 45,Gobierno y defensa 18,Agricultura 2,Otros 13
USA:Idaho|Papa,Trigo,Remolacha|Res>Leche|Plata,Fosfato|Servicios 52,Manufactura (electrónica) 14,Agroindustria (papa) 12,Minería 3,Otros 19
USA:Illinois|Maíz,Soya|Cerdo|Carbón,Petróleo,Arena|Servicios 60,Manufactura 12,Finanzas 12,Agroindustria 4,Otros 12
USA:Indiana|Maíz,Soya|Cerdo>Cerdo|Carbón,Caliza|Manufactura 26,Servicios 50,Agroindustria 5,Minería 2,Otros 17
USA:Iowa|Maíz,Soya|Cerdo>Cerdo|Piedra,Yeso|Agroindustria (maíz, cerdo) 20,Servicios 45,Manufactura 18,Finanzas y seguros 10,Otros 7
USA:Kansas|Trigo,Maíz,Sorgo|Res>Res|Petróleo,Gas natural,Helio|Servicios 52,Agroindustria (res y trigo) 12,Manufactura (aviación) 14,Energía 4,Otros 18
USA:Kentucky|Maíz,Tabaco,Soya|Caballos>Pollo|Carbón,Caliza|Manufactura (automotriz) 22,Servicios 52,Minería 3,Agricultura 3,Otros 20
USA:Luisiana|Soya,Caña de azúcar,Arroz|Pollo|Petróleo,Gas natural,Sal|Petróleo, gas y petroquímica 22,Servicios 50,Puertos y logística 10,Pesca 2,Otros 16
USA:Maine|Papa,Arándano|Pollo|Madera,Piedra|Servicios 65,Madera y papel 6,Pesca (langosta) 4,Turismo 8,Manufactura 8,Otros 9
USA:Maryland|Maíz,Soya|Pollo|Carbón,Arena|Servicios 65,Gobierno federal 14,Biotecnología 8,Manufactura 5,Otros 8
USA:Massachusetts|Arándano|Leche|Granito|Servicios 60,Biotecnología y tecnología 18,Finanzas 10,Manufactura 8,Otros 4
USA:Míchigan|Maíz,Soya,Cereza|Leche|Hierro,Cobre,Sal|Manufactura (automotriz) 20,Servicios 58,Agricultura 2,Turismo 5,Otros 15
USA:Minnesota|Maíz,Soya,Remolacha|Cerdo>Cerdo|Hierro,Taconita|Servicios 56,Manufactura 14,Agroindustria 10,Minería (hierro) 2,Otros 18
USA:Misisipi|Algodón,Soya,Arroz|Pollo|Petróleo,Gas natural|Servicios 52,Agroindustria (pollo) 12,Manufactura 14,Energía 4,Otros 18
USA:Misuri|Soya,Maíz,Arroz|Res|Plomo,Caliza|Servicios 58,Manufactura 14,Agroindustria 6,Minería 2,Otros 20
USA:Montana|Trigo,Cebada,Lentejas|Res>Res|Cobre,Carbón,Petróleo|Servicios 52,Agroindustria (trigo y res) 12,Energía y minería 10,Turismo 8,Otros 18
USA:Nebraska|Maíz,Soya,Trigo|Res>Res|Petróleo (poco)|Agroindustria (res, maíz) 22,Servicios 50,Manufactura 12,Finanzas y seguros 8,Otros 8
USA:Nevada|Heno,Alfalfa|Res|Oro,Plata,Litio|Turismo y juego 25,Servicios 45,Minería (oro y litio) 6,Logística 8,Construcción 8,Otros 8
USA:Nuevo Hampshire|Maíz de forraje,Manzana|Leche|Granito|Servicios 62,Manufactura 14,Turismo 6,Construcción 5,Otros 13
USA:Nueva Jersey|Arándano,Hortalizas|Leche|Arena|Servicios 60,Farmacéutica 10,Finanzas 12,Puertos y logística 8,Manufactura 6,Otros 4
USA:Nuevo México|Heno,Chile,Nuez pecana|Res|Petróleo,Gas natural,Uranio,Potasa|Servicios 55,Petróleo y gas 14,Gobierno y laboratorios 12,Agricultura 3,Otros 16
USA:Nueva York|Manzana,Leche,Col|Leche|Sal,Gas natural|Finanzas 22,Servicios 55,Manufactura 6,Medios y cultura 7,Turismo 5,Otros 5
USA:Carolina del Norte|Tabaco,Cerdo,Batata|Cerdo>Cerdo|Fosfato,Piedra,Litio|Servicios 58,Manufactura 14,Agroindustria (cerdo, tabaco) 8,Finanzas 10,Otros 10
USA:Dakota del Norte|Trigo,Soya,Canola|Res|Petróleo,Lignito|Petróleo y gas 25,Agricultura 12,Servicios 40,Manufactura 6,Otros 17
USA:Ohio|Maíz,Soya,Trigo|Cerdo|Carbón,Sal,Arena|Servicios 58,Manufactura 17,Finanzas 8,Agricultura 2,Otros 15
USA:Oklahoma|Trigo,Algodón,Maní|Res>Res|Petróleo,Gas natural|Servicios 50,Petróleo y gas 14,Agroindustria (res y trigo) 8,Manufactura 9,Otros 19
USA:Oregón|Heno,Pera,Madera|Res|Madera,Oro|Servicios 55,Manufactura (electrónica) 16,Madera 4,Agricultura 3,Otros 22
USA:Pensilvania|Maíz,Hongos,Leche|Leche|Carbón,Gas natural|Servicios 62,Manufactura 12,Energía (gas) 7,Finanzas 8,Otros 11
USA:Rhode Island|Viveros|—|Arena|Servicios 70,Manufactura 8,Finanzas 10,Turismo 5,Otros 7
USA:Carolina del Sur|Algodón,Melocotón,Tabaco|Pollo|Granito,Caolín|Servicios 55,Manufactura (automotriz y aviación) 18,Turismo 8,Agroindustria 3,Otros 16
USA:Dakota del Sur|Maíz,Soya,Trigo|Res>Res|Oro,Piedra|Servicios 50,Agroindustria (res y maíz) 16,Finanzas 12,Manufactura 8,Otros 14
USA:Tennessee|Soya,Algodón,Maíz|Res|Zinc,Caliza|Servicios 60,Manufactura 15,Logística 8,Música y turismo 6,Otros 11
USA:Texas|Algodón,Maíz,Sorgo|Res>Res|Petróleo,Gas natural,Sal|Servicios 52,Petróleo y gas 13,Manufactura 12,Finanzas 9,Agroindustria 3,Otros 11
USA:Utah|Heno,Trigo|Res|Cobre,Sal,Petróleo|Servicios 58,Manufactura 12,Minería 3,Turismo 6,Construcción 8,Otros 13
USA:Vermont|Maíz de forraje,Arce|Leche|Granito,Talco|Servicios 62,Manufactura 12,Turismo 8,Agroindustria (lácteos y arce) 5,Otros 13
USA:Virginia|Soya,Tabaco,Maíz|Pollo|Carbón,Arena|Servicios 62,Gobierno federal y defensa 14,Manufactura 8,Tecnología 8,Otros 8
USA:Washington|Manzana,Papa,Trigo|Leche|Hidroenergía,Arena|Servicios y tecnología 60,Manufactura (aeroespacial) 12,Agroindustria (manzana) 4,Comercio 10,Otros 14
USA:Virginia Occidental|Heno,Maíz|Pollo|Carbón,Gas natural|Energía (carbón y gas) 20,Servicios 55,Manufactura 8,Turismo 4,Otros 13
USA:Wisconsin|Maíz,Soya,Arándano|Leche>Res|Arena silícea,Hierro|Manufactura 20,Servicios 50,Agroindustria (lácteos) 10,Minería 1,Otros 19
USA:Wyoming|Heno,Remolacha|Res>Res|Carbón,Petróleo,Gas natural,Trona|Minería y energía 38,Servicios 38,Turismo 6,Ganadería 4,Otros 14
USA:Puerto Rico|Café,Plátano,Caña de azúcar|Pollo|—|Manufactura (farma) 40,Servicios 45,Turismo 6,Agricultura 1,Otros 8
COL:Antioquia|Café,Banano,Flores|Res>Res|Oro,Carbón,Energía hidroeléctrica|Servicios 55,Manufactura 18,Agricultura (café y banano) 8,Minería (oro) 4,Construcción 7,Otros 8
COL:Bogotá|Flores|Pollo|—|Servicios y finanzas 70,Manufactura 12,Comercio 8,Construcción 6,Otros 4
COL:Cundinamarca|Flores,Papa,Café|Leche>Res|Sal,Carbón,Caliza|Servicios 45,Manufactura 20,Agricultura (flores y papa) 12,Minería 5,Otros 18
COL:Valle del Cauca|Caña de azúcar,Café,Frutales|Pollo|Oro,Azúcar|Servicios 55,Manufactura (agroindustria azucarera) 18,Agricultura 7,Puertos y logística 8,Otros 12
COL:Santander|Palma de aceite,Cacao,Café|Pollo>Pollo|Petróleo,Oro|Petróleo y refinación 18,Manufactura 14,Servicios 40,Agricultura 12,Minería 6,Otros 10
COL:Meta|Palma de aceite,Arroz,Maíz|Res|Petróleo|Petróleo y gas 55,Agricultura (palma, arroz) 15,Ganadería 8,Servicios 18,Otros 4
COL:Casanare|Arroz,Palma de aceite|Res>Res|Petróleo,Gas natural|Petróleo y gas 60,Ganadería 10,Agricultura 10,Servicios 15,Otros 5
COL:Boyacá|Papa,Cebolla,Café|Leche|Carbón,Esmeraldas,Hierro|Minería (carbón, esmeraldas) 20,Agricultura 18,Manufactura (acero) 12,Servicios 40,Otros 10
COL:Atlántico|Hortalizas|Pollo|Sal,Arena|Servicios 55,Manufactura 20,Puertos 10,Comercio 10,Otros 5
COL:Bolívar|Arroz,Plátano|Res|Petróleo (refinería),Oro|Manufactura (petroquímica) 22,Servicios 45,Puertos y turismo 15,Agricultura 8,Otros 10
COL:Cesar|Palma de aceite,Arroz,Algodón|Res|Carbón|Minería (carbón) 35,Agricultura 15,Ganadería 12,Servicios 30,Otros 8
COL:La Guajira|Frijol,Yuca|Cabra>Cabra|Carbón,Gas natural,Sal|Minería (carbón) 50,Servicios 20,Ganadería (cabras) 8,Sal 5,Otros 17
COL:Huila|Café,Arroz,Cacao|Res|Petróleo,Oro|Agricultura (café) 20,Petróleo 15,Servicios 40,Ganadería 8,Otros 17
COL:Tolima|Arroz,Café,Sorgo|Res|Oro,Petróleo|Agricultura (arroz, café) 18,Servicios 40,Manufactura 12,Minería 10,Ganadería 8,Otros 12
COL:Caldas|Café,Plátano|Leche|Oro,Níquel|Café 22,Servicios 42,Manufactura 14,Minería 5,Otros 17
COL:Risaralda|Café,Plátano|Pollo|—|Café 18,Servicios 48,Manufactura 15,Comercio 10,Otros 9
COL:Quindío|Café,Plátano|Leche|—|Café y agroturismo 24,Servicios 48,Comercio 12,Construcción 6,Otros 10
COL:Nariño|Papa,Café,Palma de aceite|Cuy>Res|Oro,Carbón|Agricultura 25,Servicios 40,Ganadería 10,Minería 5,Otros 20
COL:Cauca|Café,Caña de azúcar,Plátano|Res|Oro,Calizas|Agricultura 22,Servicios 40,Minería (oro) 10,Manufactura 12,Otros 16
COL:Chocó|Plátano,Arroz|—|Oro,Platino,Madera|Minería (oro y platino) 35,Madera 10,Pesca 8,Servicios 30,Otros 17
COL:Córdoba|Yuca,Maíz,Arroz|Res>Res|Níquel,Carbón|Ganadería 22,Minería (níquel) 20,Agricultura 15,Servicios 33,Otros 10
COL:Sucre|Yuca,Ñame|Res|Petróleo (poco)|Ganadería 22,Agricultura 15,Servicios 45,Otros 18
COL:Magdalena|Banano,Palma de aceite|Res|Carbón (puerto)|Agricultura (banano, palma) 25,Servicios 45,Ganadería 10,Puertos y turismo 10,Otros 10
COL:Norte de Santander|Arroz,Palma de aceite,Café|Res|Carbón,Petróleo|Servicios 50,Minería (carbón) 14,Agricultura 12,Comercio fronterizo 10,Otros 14
COL:Caquetá|Plátano,Caucho|Res>Res|Madera|Ganadería 40,Agricultura 15,Servicios 30,Otros 15
COL:Putumayo|Yuca,Plátano|Res|Petróleo|Petróleo 45,Ganadería 15,Servicios 25,Agricultura 10,Otros 5
COL:Arauca|Plátano,Cacao|Res|Petróleo|Petróleo 60,Ganadería 15,Servicios 15,Agricultura 10
COL:Guaviare|Yuca,Plátano|Res|Madera|Ganadería 35,Agricultura 20,Servicios 30,Otros 15
COL:Amazonas|Yuca|—|Madera,Pesca|Turismo 30,Servicios 40,Pesca 10,Agricultura 10,Otros 10
COL:Vichada|Arroz,Yuca|Res|—|Ganadería 35,Agricultura 20,Servicios 35,Otros 10
COL:Vaupés|Yuca|—|Madera|Agricultura 30,Servicios 50,Pesca 10,Otros 10
COL:Guainía|Yuca|—|Oro (artesanal)|Servicios 50,Agricultura 25,Minería 10,Pesca 10,Otros 5
COL:Archipiélago de San Andrés|Coco|—|Pesca|Turismo 45,Servicios 35,Pesca 10,Comercio 10
MEX:Chihuahua|Maíz,Algodón,Nuez|Res>Res|Plata,Oro,Cobre|Manufactura (maquila) 28,Servicios 45,Minería 6,Agricultura 6,Otros 15
MEX:Sonora|Trigo,Uva,Maíz|Res>Cerdo|Cobre,Oro|Minería (cobre, oro) 18,Manufactura 22,Servicios 38,Agricultura 12,Otros 10
MEX:Baja California|Hortalizas,Fresa|Res|Sal,Cobre|Manufactura (maquila) 30,Servicios 48,Agricultura 6,Turismo 8,Otros 8
MEX:Coahuila de Zaragoza|Algodón,Nuez,Trigo|Res|Carbón,Zinc,Fluorita|Manufactura (automotriz y acero) 38,Servicios 38,Minería 8,Agricultura 4,Otros 12
MEX:Nuevo León|Naranja,Sorgo|Cerdo|—|Manufactura 28,Servicios 55,Finanzas 8,Construcción 5,Otros 4
MEX:Tamaulipas|Sorgo,Maíz|Res|Petróleo,Gas natural|Servicios 45,Manufactura 20,Petróleo y gas 12,Agricultura 8,Comercio fronterizo 10,Otros 5
MEX:Jalisco|Agave,Maíz,Caña de azúcar|Cerdo>Pollo|Plata|Servicios 55,Manufactura (electrónica y tequila) 22,Agricultura (agave) 6,Turismo 7,Otros 10
MEX:Estado de Veracruz|Caña de azúcar,Naranja,Café|Res>Res|Petróleo,Gas natural|Servicios 45,Petróleo y gas 15,Manufactura 14,Agricultura 9,Otros 17
MEX:Chiapas|Café,Banano,Palma de aceite|Res|Petróleo,Ámbar|Servicios 55,Agricultura (café, banano) 15,Energía 8,Turismo 6,Otros 16
MEX:Oaxaca|Maíz,Café,Agave|Res|Plata|Servicios 60,Agricultura 12,Turismo 8,Manufactura 8,Otros 12
MEX:Tabasco|Cacao,Plátano|Res|Petróleo,Gas natural|Petróleo y gas 55,Servicios 28,Agricultura (cacao) 6,Otros 11
MEX:Campeche|Maíz,Arroz|Res|Petróleo|Petróleo 75,Servicios 15,Pesca 3,Otros 7
MEX:Yucatán|Henequén,Maíz|Cerdo>Cerdo|Sal,Caliza|Servicios 58,Manufactura 14,Turismo 12,Agricultura 4,Otros 12
MEX:Quintana Roo|Caña de azúcar|—|—|Turismo 45,Servicios 35,Construcción 10,Otros 10
MEX:Guanajuato|Sorgo,Trigo,Hortalizas|Cerdo|Plata,Oro|Manufactura (automotriz) 30,Servicios 48,Agricultura 5,Minería 3,Otros 14
MEX:Michoacán|Aguacate,Fresa,Limón|Res|Hierro,Cobre|Agricultura (aguacate) 20,Servicios 48,Manufactura 14,Minería 4,Otros 14
MEX:Sinaloa|Maíz,Tomate,Frijol|Res>Pescado|Oro,Plata|Agricultura 22,Servicios 45,Pesca (camarón, atún) 6,Manufactura 12,Otros 15
MEX:Zacatecas|Frijol,Chile,Avena|Res|Plata,Oro,Zinc|Minería (plata) 30,Servicios 40,Agricultura 12,Manufactura 8,Otros 10
MEX:San Luis Potosí|Caña de azúcar,Naranja|Res|Fluorita,Plata|Manufactura (automotriz) 28,Servicios 45,Minería 6,Agricultura 7,Otros 14
MEX:Estado de México|Maíz,Flores|Leche|—|Servicios 58,Manufactura 25,Comercio 8,Agricultura 3,Otros 6
MEX:México|—|—|—|Servicios y finanzas 78,Comercio 8,Manufactura 8,Construcción 3,Otros 3
MEX:Puebla|Maíz,Café,Papa|Pollo|Mármol|Manufactura (Volkswagen) 28,Servicios 50,Agricultura 7,Otros 15
MEX:Baja California Sur|Hortalizas,Dátil|Res|Sal,Yeso,Fosfato|Turismo 35,Servicios 35,Minería (sal) 8,Pesca 5,Otros 17
"""
