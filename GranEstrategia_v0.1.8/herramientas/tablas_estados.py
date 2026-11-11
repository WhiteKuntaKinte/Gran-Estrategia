"""Tabla de estados de EE. UU. (FIPS -> abreviatura, nombre en español, nombre en inglés). 0.1.7.9"""
ESTADOS_US = {
    1: ('al', 'Alabama', 'Alabama'), 2: ('ak', 'Alaska', 'Alaska'), 4: ('az', 'Arizona', 'Arizona'),
    5: ('ar', 'Arkansas', 'Arkansas'), 6: ('ca', 'California', 'California'), 8: ('co', 'Colorado', 'Colorado'),
    9: ('ct', 'Connecticut', 'Connecticut'), 10: ('de', 'Delaware', 'Delaware'),
    11: ('dc', 'Distrito de Columbia', 'District of Columbia'), 12: ('fl', 'Florida', 'Florida'),
    13: ('ga', 'Georgia', 'Georgia'), 15: ('hi', 'Hawái', 'Hawaii'), 16: ('id', 'Idaho', 'Idaho'),
    17: ('il', 'Illinois', 'Illinois'), 18: ('in', 'Indiana', 'Indiana'), 19: ('ia', 'Iowa', 'Iowa'),
    20: ('ks', 'Kansas', 'Kansas'), 21: ('ky', 'Kentucky', 'Kentucky'), 22: ('la', 'Luisiana', 'Louisiana'),
    23: ('me', 'Maine', 'Maine'), 24: ('md', 'Maryland', 'Maryland'), 25: ('ma', 'Massachusetts', 'Massachusetts'),
    26: ('mi', 'Míchigan', 'Michigan'), 27: ('mn', 'Minnesota', 'Minnesota'), 28: ('ms', 'Misisipi', 'Mississippi'),
    29: ('mo', 'Misuri', 'Missouri'), 30: ('mt', 'Montana', 'Montana'), 31: ('ne', 'Nebraska', 'Nebraska'),
    32: ('nv', 'Nevada', 'Nevada'), 33: ('nh', 'Nuevo Hampshire', 'New Hampshire'), 34: ('nj', 'Nueva Jersey', 'New Jersey'),
    35: ('nm', 'Nuevo México', 'New Mexico'), 36: ('ny', 'Nueva York', 'New York'),
    37: ('nc', 'Carolina del Norte', 'North Carolina'), 38: ('nd', 'Dakota del Norte', 'North Dakota'),
    39: ('oh', 'Ohio', 'Ohio'), 40: ('ok', 'Oklahoma', 'Oklahoma'), 41: ('or', 'Oregón', 'Oregon'),
    42: ('pa', 'Pensilvania', 'Pennsylvania'), 44: ('ri', 'Rhode Island', 'Rhode Island'),
    45: ('sc', 'Carolina del Sur', 'South Carolina'), 46: ('sd', 'Dakota del Sur', 'South Dakota'),
    47: ('tn', 'Tennessee', 'Tennessee'), 48: ('tx', 'Texas', 'Texas'), 49: ('ut', 'Utah', 'Utah'),
    50: ('vt', 'Vermont', 'Vermont'), 51: ('va', 'Virginia', 'Virginia'), 53: ('wa', 'Washington', 'Washington'),
    54: ('wv', 'Virginia Occidental', 'West Virginia'), 55: ('wi', 'Wisconsin', 'Wisconsin'), 56: ('wy', 'Wyoming', 'Wyoming'),
    72: ('pr', 'Puerto Rico', 'Puerto Rico'), 78: ('vi', 'Islas Vírgenes de EE. UU.', 'U.S. Virgin Islands'),
}

# Banderas de ciudades de EE. UU. que NO son de dominio público (CC BY / CC BY-SA, SPECIAL_LICENSES.csv de oxguy3/flags): el juego no las usa,
# esas ciudades llevan la bandera de su estado. Así el juego se puede vender sin obligaciones de atribución.
CIUDADES_US_CON_LICENCIA = {
    'c_us_ca_escondido', 'c_us_ca_san_diego', 'c_us_co_denver', 'c_us_ia_des_moines', 'c_us_ia_red_oak',
    'c_us_mn_prior_lake', 'c_us_mn_rochester', 'c_us_oh_germantown', 'c_us_pr_san_juan',
}
