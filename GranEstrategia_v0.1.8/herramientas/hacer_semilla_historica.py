#!/usr/bin/env python3
"""Genera la SEMILLA histórica de ejemplo (datos/historico/*.json) para la versión 0.1.7.9.9C.

Son unos pocos estados, gobernantes y cambios de nombre escritos a mano con datos muy conocidos, solo para que la base
histórica funcione y se pueda probar desde el menú Debug > Historia sin haber descargado nada. NO es el contenido final:
cuando corras herramientas/descargar_historia (dentro de Godot), esas filas ("fuente": "semilla") se reemplazan por los datos
completos de Wikidata (la herramienta lo hace sola si en su configuración `quitar_semilla` está en true).

Uso:  python3 herramientas/hacer_semilla_historica.py
Formato de fechas: (año + 100000) * 10000 + mes * 100 + día; 0 = desconocida / sin fin. Años a. C.: negativos.
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, "datos", "historico")
ID_ENT = 1000000
ID_PER = 2000000


def f(a, m=1, d=1):
    return (a + 100000) * 10000 + m * 100 + d


ids = json.load(open(os.path.join(RAIZ, "datos", "ids.json"), encoding="utf-8"))
PAIS = {r[2]: r[0] for r in ids["territorios"] if r[1] == 2}


def pais(n):
    if n not in PAIS:
        sys.exit("No existe el país '%s' en ids.json" % n)
    return PAIS[n]


# clave, nombre, tipo, inicio, fin, capital, predecesores (claves), sucesores (claves de entidad o ("pais", nombre))
ENTIDADES = [
    ("gran_colombia", "Gran Colombia", "republica", f(1819, 12, 17), f(1831, 11, 19), "Bogotá", ["virreinato_nueva_granada"],
     [("pais", "Colombia"), ("pais", "Venezuela"), ("pais", "Ecuador"), ("pais", "Panamá")]),
    ("virreinato_nueva_granada", "Virreinato de la Nueva Granada", "virreinato", f(1717, 5, 27), f(1819, 8, 7), "Santafé de Bogotá", [],
     ["gran_colombia"]),
    ("urss", "Unión Soviética", "estado", f(1922, 12, 30), f(1991, 12, 26), "Moscú", ["imperio_ruso"],
     [("pais", "Rusia"), ("pais", "Ucrania"), ("pais", "Bielorrusia")]),
    ("imperio_ruso", "Imperio ruso", "imperio", f(1721, 11, 2), f(1917, 3, 15), "San Petersburgo", [], ["urss", ("pais", "Rusia")]),
    ("yugoslavia", "República Federal Socialista de Yugoslavia", "republica", f(1945, 11, 29), f(1992, 4, 27), "Belgrado", [],
     [("pais", "Serbia"), ("pais", "Macedonia del Norte"), ("pais", "Croacia"), ("pais", "Eslovenia"),
      ("pais", "Bosnia y Herzegovina"), ("pais", "Montenegro"), ("pais", "Kosovo")]),
    ("checoslovaquia", "Checoslovaquia", "republica", f(1918, 10, 28), f(1992, 12, 31), "Praga", [],
     [("pais", "Chequia"), ("pais", "Eslovaquia")]),
    ("rda", "República Democrática Alemana", "republica", f(1949, 10, 7), f(1990, 10, 3), "Berlín Este", [], [("pais", "Alemania")]),
    ("prusia", "Reino de Prusia", "reino", f(1701, 1, 18), f(1918, 11, 9), "Berlín", [], [("pais", "Alemania")]),
    ("austria_hungria", "Austria-Hungría", "imperio", f(1867, 3, 30), f(1918, 11, 11), "Viena", [],
     [("pais", "Austria"), ("pais", "Hungría"), ("pais", "Chequia"), ("pais", "Eslovaquia")]),
    ("imperio_otomano", "Imperio otomano", "imperio", f(1299, 1, 1), f(1922, 11, 1), "Constantinopla", ["imperio_bizantino"],
     [("pais", "Turquía")]),
    ("imperio_bizantino", "Imperio bizantino", "imperio", f(395, 1, 17), f(1453, 5, 29), "Constantinopla", ["imperio_romano"],
     ["imperio_otomano"]),
    ("imperio_romano", "Imperio romano", "imperio", f(-27, 1, 16), f(476, 9, 4), "Roma", [], ["imperio_bizantino", ("pais", "Italia")]),
    ("imperio_azteca", "Imperio azteca", "imperio", f(1428, 1, 1), f(1521, 8, 13), "Tenochtitlan", [], [("pais", "México")]),
    ("imperio_inca", "Imperio inca", "imperio", f(1438, 1, 1), f(1533, 7, 26), "Cusco", [], [("pais", "Perú")]),
    ("imperio_mongol", "Imperio mongol", "imperio", f(1206, 1, 1), f(1368, 1, 1), "Karakórum", [], [("pais", "Mongolia")]),
    ("imperio_qing", "Imperio Qing", "imperio", f(1636, 5, 15), f(1912, 2, 12), "Pekín", [], [("pais", "China")]),
]

# persona: clave -> (nombre, nacimiento, muerte)
PERSONAS = {
    "bolivar": ("Simón Bolívar", f(1783, 7, 24), f(1830, 12, 17)),
    "lenin": ("Vladímir Lenin", f(1870, 4, 22), f(1924, 1, 21)),
    "stalin": ("Iósif Stalin", f(1878, 12, 18), f(1953, 3, 5)),
    "jrushchov": ("Nikita Jrushchov", f(1894, 4, 15), f(1971, 9, 11)),
    "brezhnev": ("Leonid Brézhnev", f(1906, 12, 19), f(1982, 11, 10)),
    "andropov": ("Yuri Andrópov", f(1914, 6, 15), f(1984, 2, 9)),
    "chernenko": ("Konstantín Chernenko", f(1911, 9, 24), f(1985, 3, 10)),
    "gorbachov": ("Mijaíl Gorbachov", f(1931, 3, 2), f(2022, 8, 30)),
    "tito": ("Josip Broz Tito", f(1892, 5, 7), f(1980, 5, 4)),
    "osman1": ("Osmán I", f(1258, 1, 1), f(1326, 1, 1)),
    "mehmed2": ("Mehmed II el Conquistador", f(1432, 3, 30), f(1481, 5, 3)),
    "solimán1": ("Solimán I el Magnífico", f(1494, 11, 6), f(1566, 9, 6)),
    "mehmed6": ("Mehmed VI", f(1861, 1, 14), f(1926, 5, 16)),
    "augusto": ("Augusto", f(-63, 9, 23), f(14, 8, 19)),
    "trajano": ("Trajano", f(53, 9, 18), f(117, 8, 8)),
    "constantino1": ("Constantino I", f(272, 2, 27), f(337, 5, 22)),
    "romulo_augustulo": ("Rómulo Augústulo", f(460, 1, 1), 0),
    "justiniano1": ("Justiniano I", f(482, 5, 11), f(565, 11, 14)),
    "constantino11": ("Constantino XI Paleólogo", f(1405, 2, 8), f(1453, 5, 29)),
    "moctezuma2": ("Moctezuma II", f(1466, 1, 1), f(1520, 6, 29)),
    "pachacutec": ("Pachacútec", f(1418, 1, 1), f(1471, 1, 1)),
    "atahualpa": ("Atahualpa", f(1502, 1, 1), f(1533, 7, 26)),
    "gengis_kan": ("Gengis Kan", f(1162, 1, 1), f(1227, 8, 18)),
    "kublai_kan": ("Kublai Kan", f(1215, 9, 23), f(1294, 2, 18)),
    "kangxi": ("Emperador Kangxi", f(1654, 5, 4), f(1722, 12, 20)),
    "puyi": ("Puyi", f(1906, 2, 7), f(1967, 10, 17)),
    "francisco_jose1": ("Francisco José I", f(1830, 8, 18), f(1916, 11, 21)),
    "carlos1_austria": ("Carlos I de Austria", f(1887, 8, 17), f(1922, 4, 1)),
    "federico2": ("Federico II el Grande", f(1712, 1, 24), f(1786, 8, 17)),
    "guillermo2": ("Guillermo II", f(1859, 1, 27), f(1941, 6, 4)),
    "pedro1": ("Pedro I el Grande", f(1672, 6, 9), f(1725, 2, 8)),
    "catalina2": ("Catalina II la Grande", f(1729, 5, 2), f(1796, 11, 17)),
    "nicolas2": ("Nicolás II", f(1868, 5, 18), f(1918, 7, 17)),
    "masaryk": ("Tomáš Masaryk", f(1850, 3, 7), f(1937, 9, 14)),
    "havel": ("Václav Havel", f(1936, 10, 5), f(2011, 12, 18)),
    "ulbricht": ("Walter Ulbricht", f(1893, 6, 30), f(1973, 8, 1)),
    "honecker": ("Erich Honecker", f(1912, 8, 25), f(1994, 5, 29)),
}

# entidad, persona, cargo, desde, hasta
CARGOS = [
    ("gran_colombia", "bolivar", "presidente", f(1819, 12, 17), f(1830, 4, 27)),
    ("urss", "lenin", "jefe de gobierno", f(1922, 12, 30), f(1924, 1, 21)),
    ("urss", "stalin", "líder de facto (secretario general)", f(1922, 12, 30), f(1953, 3, 5)),
    ("urss", "jrushchov", "líder de facto (secretario general)", f(1953, 9, 7), f(1964, 10, 14)),
    ("urss", "brezhnev", "líder de facto (secretario general)", f(1964, 10, 14), f(1982, 11, 10)),
    ("urss", "andropov", "líder de facto (secretario general)", f(1982, 11, 12), f(1984, 2, 9)),
    ("urss", "chernenko", "líder de facto (secretario general)", f(1984, 2, 13), f(1985, 3, 10)),
    ("urss", "gorbachov", "líder de facto (secretario general)", f(1985, 3, 11), f(1991, 8, 24)),
    ("yugoslavia", "tito", "líder del Estado", f(1945, 11, 29), f(1980, 5, 4)),
    ("imperio_otomano", "osman1", "sultán", f(1299, 1, 1), f(1324, 1, 1)),
    ("imperio_otomano", "mehmed2", "sultán", f(1451, 2, 3), f(1481, 5, 3)),
    ("imperio_otomano", "solimán1", "sultán", f(1520, 9, 30), f(1566, 9, 6)),
    ("imperio_otomano", "mehmed6", "sultán", f(1918, 7, 4), f(1922, 11, 1)),
    ("imperio_romano", "augusto", "emperador", f(-27, 1, 16), f(14, 8, 19)),
    ("imperio_romano", "trajano", "emperador", f(98, 1, 28), f(117, 8, 8)),
    ("imperio_romano", "constantino1", "emperador", f(306, 7, 25), f(337, 5, 22)),
    ("imperio_romano", "romulo_augustulo", "emperador", f(475, 10, 31), f(476, 9, 4)),
    ("imperio_bizantino", "justiniano1", "emperador", f(527, 8, 1), f(565, 11, 14)),
    ("imperio_bizantino", "constantino11", "emperador", f(1449, 1, 6), f(1453, 5, 29)),
    ("imperio_azteca", "moctezuma2", "tlatoani", f(1502, 1, 1), f(1520, 6, 29)),
    ("imperio_inca", "pachacutec", "sapa inca", f(1438, 1, 1), f(1471, 1, 1)),
    ("imperio_inca", "atahualpa", "sapa inca", f(1532, 1, 1), f(1533, 7, 26)),
    ("imperio_mongol", "gengis_kan", "gran kan", f(1206, 1, 1), f(1227, 8, 18)),
    ("imperio_mongol", "kublai_kan", "gran kan", f(1260, 5, 5), f(1294, 2, 18)),
    ("imperio_qing", "kangxi", "emperador", f(1661, 2, 5), f(1722, 12, 20)),
    ("imperio_qing", "puyi", "emperador", f(1908, 11, 14), f(1912, 2, 12)),
    ("austria_hungria", "francisco_jose1", "emperador", f(1867, 3, 30), f(1916, 11, 21)),
    ("austria_hungria", "carlos1_austria", "emperador", f(1916, 11, 21), f(1918, 11, 11)),
    ("prusia", "federico2", "rey", f(1740, 5, 31), f(1786, 8, 17)),
    ("prusia", "guillermo2", "rey", f(1888, 6, 15), f(1918, 11, 9)),
    ("imperio_ruso", "pedro1", "emperador", f(1721, 11, 2), f(1725, 2, 8)),
    ("imperio_ruso", "catalina2", "emperatriz", f(1762, 7, 9), f(1796, 11, 17)),
    ("imperio_ruso", "nicolas2", "emperador", f(1894, 11, 1), f(1917, 3, 15)),
    ("checoslovaquia", "masaryk", "presidente", f(1918, 11, 14), f(1935, 12, 14)),
    ("checoslovaquia", "havel", "presidente", f(1989, 12, 29), f(1992, 7, 20)),
    ("rda", "ulbricht", "líder de facto (primer secretario)", f(1950, 7, 25), f(1971, 5, 3)),
    ("rda", "honecker", "líder de facto (primer secretario)", f(1971, 5, 3), f(1989, 10, 18)),
]

# nombres de entidades: clave, nombre, idioma, clase, desde, hasta
NOMBRES_ENT = [
    ("gran_colombia", "República de Colombia", "es", "oficial", f(1819, 12, 17), f(1831, 11, 19)),
    ("urss", "Unión de Repúblicas Socialistas Soviéticas", "es", "oficial", 0, 0),
    ("urss", "URSS", "es", "comun", 0, 0),
    ("urss", "Soviet Union", "en", "comun", 0, 0),
    ("urss", "Советский Союз", "ru", "nativo", 0, 0),
    ("imperio_otomano", "Osmanlı Devleti", "tr", "nativo", 0, 0),
    ("imperio_otomano", "Sublime Puerta", "es", "comun", 0, 0),
    ("imperio_bizantino", "Imperio romano de Oriente", "es", "comun", 0, 0),
    ("imperio_bizantino", "Βασιλεία Ῥωμαίων", "el", "nativo", 0, 0),
    ("imperio_azteca", "Triple Alianza", "es", "comun", 0, 0),
    ("imperio_inca", "Tawantinsuyu", "qu", "nativo", 0, 0),
    ("imperio_qing", "Gran Qing", "es", "oficial", 0, 0),
    ("imperio_qing", "大清", "zh", "nativo", 0, 0),
    ("austria_hungria", "Imperio austrohúngaro", "es", "comun", 0, 0),
    ("austria_hungria", "Österreich-Ungarn", "de", "nativo", 0, 0),
    ("prusia", "Preußen", "de", "nativo", 0, 0),
    ("imperio_ruso", "Российская империя", "ru", "nativo", 0, 0),
    ("rda", "Alemania Oriental", "es", "comun", 0, 0),
    ("rda", "Deutsche Demokratische Republik", "de", "nativo", 0, 0),
    ("yugoslavia", "Yugoslavia", "es", "comun", 0, 0),
    ("virreinato_nueva_granada", "Nueva Granada", "es", "comun", 0, 0),
]

# nombres que tuvo un país actual: país, nombre, idioma, clase, desde, hasta (fuera de estas fechas vale el nombre actual)
NOMBRES_PAIS = [
    ("Irán", "Persia", "es", "comun", 0, f(1935, 3, 21)),
    ("Tailandia", "Siam", "es", "oficial", 0, f(1939, 6, 24)),
    ("Tailandia", "Siam", "es", "oficial", f(1945, 9, 11), f(1949, 5, 11)),
    ("Sri Lanka", "Ceilán", "es", "oficial", 0, f(1972, 5, 22)),
    ("Myanmar", "Birmania", "es", "comun", 0, f(1989, 6, 18)),
    ("República Democrática del Congo", "Estado Libre del Congo", "es", "oficial", f(1885, 5, 29), f(1908, 11, 15)),
    ("República Democrática del Congo", "Congo Belga", "es", "oficial", f(1908, 11, 15), f(1960, 6, 30)),
    ("República Democrática del Congo", "República del Congo (Léopoldville)", "es", "oficial", f(1960, 6, 30), f(1964, 8, 1)),
    ("República Democrática del Congo", "Zaire", "es", "oficial", f(1971, 10, 27), f(1997, 5, 17)),
    ("Zimbabue", "Rodesia del Sur", "es", "oficial", f(1923, 10, 1), f(1965, 11, 11)),
    ("Zimbabue", "Rodesia", "es", "oficial", f(1965, 11, 11), f(1980, 4, 18)),
    ("Benín", "Dahomey", "es", "oficial", 0, f(1975, 11, 30)),
    ("Burkina Faso", "Alto Volta", "es", "oficial", f(1958, 12, 11), f(1984, 8, 4)),
    ("Esuatini", "Suazilandia", "es", "oficial", 0, f(2018, 4, 19)),
    ("Macedonia del Norte", "Macedonia", "es", "comun", f(1991, 9, 8), f(2019, 2, 12)),
]


def main():
    clave_id = {}
    filas_e = []
    n = ID_ENT
    for e in ENTIDADES:
        clave_id[e[0]] = n
        n += 1
    for e in ENTIDADES:
        clave, nombre, tipo, ini, fin, cap, pred, suc = e
        p = [clave_id[x] for x in pred]
        s = [pais(x[1]) if isinstance(x, tuple) else clave_id[x] for x in suc]
        filas_e.append([clave_id[clave], "semilla:" + clave, nombre, tipo, ini, fin, cap, "semilla", p, s])
    pid = {}
    filas_p = []
    n2 = ID_PER
    for clave, (nombre, nac, mue) in PERSONAS.items():
        pid[clave] = n2
        filas_p.append([n2, "semilla:" + clave, nombre, nac, mue])
        n2 += 1
    filas_c = [[pid[p], clave_id[e], cargo, d, h] for (e, p, cargo, d, h) in CARGOS]
    filas_n = [[clave_id[e], nom, idi, cl, d, h] for (e, nom, idi, cl, d, h) in NOMBRES_ENT]
    filas_n += [[pais(p), nom, idi, cl, d, h] for (p, nom, idi, cl, d, h) in NOMBRES_PAIS]
    os.makedirs(SALIDA, exist_ok=True)
    v = "0.1.7.9.9C"
    escribir("entidades.json", {"version": v, "siguiente_id": n, "columnas": ["id", "clave", "nombre", "tipo", "inicio", "fin", "capital", "fuente", "predecesores", "sucesores"], "filas": filas_e})
    escribir("nombres.json", {"version": v, "columnas": ["id", "nombre", "idioma", "clase", "desde", "hasta"], "filas": filas_n})
    escribir("banderas.json", {"version": v, "columnas": ["id", "archivo", "clase", "desde", "hasta", "licencia"], "filas": []})
    escribir("personas.json", {"version": v, "siguiente_id": n2, "columnas": ["id", "clave", "nombre", "nacimiento", "muerte"], "filas": filas_p})
    escribir("cargos.json", {"version": v, "columnas": ["persona", "entidad", "cargo", "desde", "hasta"], "filas": filas_c})
    print("Semilla: %d entidades, %d nombres, %d personas, %d cargos" % (len(filas_e), len(filas_n), len(filas_p), len(filas_c)))


def escribir(nombre, datos):
    with open(os.path.join(SALIDA, nombre), "w", encoding="utf-8") as fh:
        json.dump(datos, fh, ensure_ascii=False, separators=(",", ":"))
        fh.write("\n")


if __name__ == "__main__":
    main()
