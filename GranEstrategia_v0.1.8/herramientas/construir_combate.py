#!/usr/bin/env python3
"""Genera datos/combate.json: las ARMAS, la matriz de enfrentamientos, las TROPAS (descubrimiento -> arma y nivel), los TERRENOS y las FORMACIONES
del modo combate táctico (0.1.8.51). Todo lo que sale aquí lo lee scripts/combate.gd.

Uso:  python3 herramientas/construir_combate.py            (escribe datos/combate.json)
      python3 herramientas/construir_combate.py --solo-comprobar

Qué hay (se edita AQUÍ, nunca el JSON):
  · ARMAS: 10 clases de tropa con sus números base (ataque cuerpo a cuerpo, tiro, defensa, movimiento, alcance, moral y peso en soldados).
  · MATRIZ: cuánto daño hace una clase a otra (lanceros contra caballería, caballería contra arqueros, blindados contra todo...).
  · TROPAS: qué descubrimiento (unidad, arma, vehículo, avión) da qué clase y con qué NIVEL (1,0 = hoplita; el nivel sube con la época). Un país tiene una clase
    si conoce al menos una de sus tropas; su nivel es el mejor que conoce.
  · MEJORAS: un descubrimiento que cambia un enfrentamiento (el bazuca hace que los fusileros dañen a los blindados).
  · TERRENOS: llano, bosque, selva, colina, montaña, desierto, pantano, urbano y nieve, con lo que cambia cada clase y la ventaja del que defiende.
  · FORMACIONES: ~45 formaciones históricas (cada una exige un descubrimiento de táctica). Cada una trae su CUADRO de despliegue (5 filas × 4 columnas; la última
    columna es el frente) y sus números (ataque, tiro, daño recibido, flancos, moral, apertura, resistencias, terreno).
Las comprobaciones: cada descubrimiento citado existe, el cuadro mide 5×4 y solo usa letras de arma, no hay formaciones repetidas.
"""
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VERSION = "0.1.8.51"

# ─────────────────────────────────────────── ARMAS ───────────────────────────────────────────
# cod, slug, nombre, atq (cuerpo a cuerpo), tiro, def, mov (casillas por turno), alc (alcance en casillas), moral, peso (soldados por bloque, relativo), color, glifo
ARMAS = [
    ("P", "inf_pesada", "Infantería pesada", 1.00, 0.00, 1.20, 1, 1, 1.00, 1.00, "#9aa7c0", "▣"),
    ("L", "lanceros", "Lanceros y piqueros", 0.80, 0.00, 1.00, 1, 1, 1.00, 1.00, "#c9b37a", "⫿"),
    ("I", "inf_ligera", "Infantería ligera", 0.60, 0.50, 0.70, 2, 2, 0.80, 0.80, "#8fc18a", "◇"),
    ("T", "tiradores", "Arqueros y ballesteros", 0.30, 1.10, 0.60, 1, 3, 0.80, 0.90, "#d9a066", "➶"),
    ("F", "fusileros", "Fusileros y tiradores de fuego", 0.40, 1.30, 0.80, 1, 3, 1.00, 1.00, "#e2c35a", "⁍"),
    ("C", "cab_pesada", "Caballería pesada y carros", 1.50, 0.00, 1.10, 2, 1, 1.10, 0.70, "#d46a6a", "♞"),
    ("c", "cab_ligera", "Caballería ligera", 0.90, 0.40, 0.80, 3, 1, 0.90, 0.60, "#e39a9a", "♘"),
    ("A", "artilleria", "Artillería y asedio", 0.20, 1.80, 0.50, 1, 4, 0.70, 0.40, "#b08968", "✹"),
    ("B", "blindados", "Blindados y mecanizados", 1.80, 1.20, 2.00, 2, 2, 1.20, 0.50, "#7aa6d6", "⬢"),
    ("V", "aviacion", "Apoyo aéreo", 0.00, 1.60, 0.70, 4, 8, 1.00, 0.30, "#a58fd6", "✈"),
]
CODS = [a[0] for a in ARMAS]

#            vs:   P    L    I    T    F    C    c    A    B    V
MATRIZ = {
    "P": [1.00, 0.90, 1.30, 1.40, 1.20, 0.90, 1.20, 1.50, 0.60, 0.50],
    "L": [0.90, 1.00, 1.10, 1.10, 1.00, 2.00, 1.70, 1.20, 0.40, 0.30],
    "I": [0.70, 0.80, 1.00, 1.20, 1.00, 0.60, 0.90, 1.30, 0.40, 0.40],
    "T": [1.20, 1.30, 1.10, 1.00, 0.90, 1.10, 1.30, 1.20, 0.30, 0.50],
    "F": [1.30, 1.30, 1.30, 1.20, 1.00, 1.70, 1.50, 1.30, 0.50, 0.70],
    "C": [1.20, 0.50, 1.50, 1.70, 1.10, 1.00, 1.20, 1.90, 0.30, 0.20],
    "c": [0.70, 0.60, 1.40, 1.60, 1.20, 0.70, 1.00, 1.70, 0.30, 0.20],
    "A": [1.50, 1.50, 1.40, 1.20, 1.30, 1.30, 1.20, 1.30, 1.20, 0.40],
    "B": [2.20, 2.20, 2.00, 1.90, 1.50, 2.20, 2.00, 2.00, 1.00, 0.30],
    "V": [1.50, 1.50, 1.40, 1.40, 1.40, 1.50, 1.50, 1.80, 1.50, 0.80],
}

# ─────────────────────────────────────────── TROPAS ───────────────────────────────────────────
# descubrimiento -> (arma, nivel). Nivel 1,0 = un hoplita; sube con la época (solo importa la razón entre los dos bandos).
TROPAS = [
    # Prehistoria y Neolítico
    ("milicia_cazadores", "I", 0.50), ("guerreros_tribales", "P", 0.55), ("honderos", "I", 0.55), ("arqueros_tribales", "T", 0.55),
    # Bronce
    ("lanceros", "L", 0.70), ("espadachines_bronce", "P", 0.75), ("jabalineros", "I", 0.65), ("carros_guerra", "C", 0.80), ("guardia_real", "P", 0.85), ("exploradores", "I", 0.60),
    # Antigüedad
    ("hoplitas", "P", 0.95), ("falangitas", "L", 1.05), ("legionarios", "P", 1.15), ("guardia_pretoriana", "P", 1.25), ("arqueros_montados", "c", 1.00),
    ("caballeria_ligera", "c", 0.95), ("caballeria_pesada_catafracta", "C", 1.10), ("ballesteros", "T", 0.95), ("elefantes_guerra", "C", 1.20), ("camelleros", "c", 0.90),
    ("mercenarios", "P", 0.90), ("marines_infanteria_marina", "P", 1.00), ("inmortales_persas", "P", 1.10), ("peltastas", "I", 0.90),
    ("catapulta_torsion", "A", 0.90), ("balista", "A", 0.90), ("onagro", "A", 1.00),
    # Edad Media
    ("caballeros_feudales", "C", 1.30), ("infanteria_pesada_medieval", "P", 1.20), ("arqueros_largos", "T", 1.30), ("ballesteros_profesionales", "T", 1.20),
    ("jinetes_arqueros_nomadas", "c", 1.20), ("samurai", "P", 1.30), ("ordenes_militares", "C", 1.35), ("huscarls_nordicos", "P", 1.25), ("mamelucos", "C", 1.30),
    ("keshig_mongol", "c", 1.35), ("guerreros_aguila_jaguar", "P", 1.00), ("huestes_incas", "I", 0.95), ("trabuquete", "A", 1.20),
    # Renacimiento
    ("piqueros", "L", 1.40), ("arcabuceros", "F", 1.35), ("reiters_pistoleros", "C", 1.45), ("condotieros", "P", 1.40), ("tercios", "L", 1.60), ("jenizaros", "F", 1.50),
    ("conquistadores", "P", 1.50), ("cosacos", "c", 1.40), ("corsarios", "I", 1.20), ("carro_fortificado_wagenburg", "B", 1.30),
    ("canon_bombarda", "A", 1.50), ("canon_bronce", "A", 1.70), ("canon_hierro_colado", "A", 1.80),
    # Ilustración
    ("mosqueteros", "F", 1.70), ("granaderos", "F", 1.85), ("dragones", "c", 1.70), ("infanteria_linea", "F", 1.90), ("fusileros_rayados", "F", 2.10), ("artilleros", "A", 1.90),
    ("ingenieros_zapadores", "A", 1.70), ("caballeria_coraceros_husares", "C", 1.80), ("levee_en_masse", "F", 1.70), ("guerrilleros", "I", 1.50), ("marineria_de_linea", "I", 1.40),
    ("artilleria_campana_ligera", "A", 2.00), ("obus", "A", 2.20),
    # Industrial
    ("infanteria_fusil_percusion", "F", 2.40), ("caballeria_carabina", "c", 2.10), ("ametralladoristas", "F", 2.90), ("ejercito_conscripcion_masiva", "F", 2.30),
    ("reserva_movilizacion", "F", 2.30), ("policia_militar", "I", 1.80), ("legion_extranjera", "F", 2.40), ("tropas_coloniales", "F", 2.30), ("cazadores_montana", "I", 2.30),
    ("canon_acero", "A", 2.70), ("canon_rayado_retrocarga", "A", 2.80), ("canon_campana_rapido", "A", 3.20), ("obus_pesado", "A", 3.30),
    # Guerras mundiales
    ("tropas_asalto_trinchera", "P", 3.20), ("infanteria_motorizada", "F", 3.40), ("infanteria_mecanizada", "B", 3.80), ("tanquistas", "B", 4.20), ("paracaidistas", "F", 3.60),
    ("infanteria_planeador", "F", 3.40), ("fuerzas_especiales", "I", 3.80), ("francotiradores", "T", 3.00), ("cazacarros", "F", 3.50), ("infanteria_anfibia", "F", 3.60),
    ("partisanos", "I", 2.80), ("buzos_combate", "I", 3.20),
    ("artilleria_autopropulsada", "A", 4.00), ("lanzacohetes_multiple", "A", 4.50),
    ("automovil_blindado", "B", 3.20), ("tanque_pesado_primera_guerra", "B", 3.40), ("tanque_ligero", "B", 3.60), ("tanque_medio", "B", 4.00), ("tanque_pesado", "B", 4.40),
    ("caza_biplano", "V", 3.40), ("bombardero_ligero", "V", 3.60), ("caza_monoplano", "V", 4.20), ("bombardero_en_picado", "V", 4.40), ("bombardero_pesado", "V", 4.60),
    # Guerra Fría
    ("infanteria_aerotransportada_helicoptero", "c", 5.00), ("infanteria_moderna_conectada", "F", 5.00), ("cascos_azules", "F", 4.00), ("contratistas_privados", "I", 4.20),
    ("obus_autopropulsado_moderno", "A", 5.20), ("municion_guiada", "A", 6.00), ("artilleria_cohete_guiada", "A", 6.50),
    ("vehiculo_combate_infanteria", "B", 5.20), ("tanque_batalla_principal", "B", 5.80),
    ("caza_reaccion", "V", 5.50), ("bombardero_estrategico_reaccion", "V", 5.80), ("caza_supersonico", "V", 6.20), ("helicoptero_ataque", "V", 6.00),
    # Presente
    ("operadores_drones", "V", 6.00), ("soldado_digital", "F", 6.00), ("infanteria_robotica", "B", 7.00), ("fuerzas_espaciales", "V", 7.00), ("infanteria_exoesqueleto", "P", 6.50),
    ("tanque_digital", "B", 7.00), ("vehiculo_terrestre_no_tripulado", "B", 7.50), ("dron_armado", "V", 7.00), ("caza_quinta_generacion", "V", 8.00),
    ("dron_combate_avanzado", "V", 8.50), ("misil_hipersonico", "V", 9.50), ("canon_electromagnetico", "A", 9.00),
    # Futuro hipotético
    ("soldado_biomejorado", "P", 8.00), ("combatiente_cibernetico", "F", 9.00), ("enjambre_autonomo", "V", 9.00), ("legion_androides", "P", 10.0), ("tropas_clonadas", "F", 8.00),
    ("criaturas_bioingenieria", "C", 9.00), ("nanoenjambre_combate", "V", 11.0), ("tropas_orbitales", "V", 10.0), ("infanteria_espacial", "F", 10.0),
]

# Un descubrimiento que cambia un enfrentamiento concreto: «arma» ataca a «contra» con ese multiplicador (se toma el mejor que conozca el país).
MEJORAS = [
    ("cazacarros", "F", "B", 2.5, "Cazacarros de infantería: los fusileros ya pueden con un blindado"),
    ("bazuca_antitanque", "F", "B", 3.0, "Bazuca: la infantería rompe blindados"),
    ("misil_antitanque_guiado", "F", "B", 3.5, "Misil antitanque guiado"),
    ("artilleria_antiaerea", "F", "V", 2.0, "Artillería antiaérea: el fuego de tierra alcanza a los aviones"),
    ("defensa_aerea_integrada", "A", "V", 3.0, "Defensa aérea integrada"),
    ("canon_antitanque", "A", "B", 2.5, "Cañón antitanque"),
    ("lanzallamas", "P", "B", 1.6, "Lanzallamas contra blindados y búnkeres"),
]

# ─────────────────────────────────────────── TERRENOS ───────────────────────────────────────────
# cod, nombre, defensor (ventaja del que defiende: el daño que recibe se divide entre esto), mods por clase (lo que no sale vale 1,0)
TERRENOS = [
    ("llano", "Llanura", 1.00, {"C": 1.20, "c": 1.15, "B": 1.15}),
    ("bosque", "Bosque", 1.08, {"C": 0.70, "c": 0.80, "B": 0.70, "A": 0.80, "I": 1.20, "T": 0.90}),
    ("selva", "Selva", 1.12, {"C": 0.55, "c": 0.65, "B": 0.55, "A": 0.65, "I": 1.30, "T": 0.85, "P": 0.90, "V": 0.80}),
    ("colina", "Colinas", 1.12, {"C": 0.85, "c": 0.90, "B": 0.85, "T": 1.10, "A": 1.10}),
    ("montana", "Montaña", 1.25, {"C": 0.50, "c": 0.60, "B": 0.40, "A": 0.60, "I": 1.30, "V": 0.85}),
    ("desierto", "Desierto", 1.00, {"C": 1.10, "c": 1.20, "P": 0.95, "L": 0.95, "B": 1.05}),
    ("pantano", "Pantano o humedal", 1.08, {"C": 0.50, "c": 0.60, "B": 0.50, "A": 0.60, "P": 0.85, "I": 1.10}),
    ("urbano", "Ciudad", 1.20, {"C": 0.50, "c": 0.50, "B": 0.70, "A": 0.90, "I": 1.20, "F": 1.20, "T": 1.10}),
    ("nieve", "Nieve y tundra", 1.05, {"C": 0.70, "c": 0.75, "B": 0.70, "A": 0.80, "P": 0.90, "L": 0.90}),
]
# Bioma del juego (info.json) -> terreno. Después se corrige por altitud (montaña > 2.500 m, colinas > 900 m).
BIOMAS = {"NTF": "bosque", "STF": "bosque", "WTF": "bosque", "TDF": "bosque", "COF": "bosque", "TEF": "selva", "DES": "desierto", "SAV": "llano", "TEG": "llano",
          "MED": "llano", "TMG": "colina", "LAK": "pantano", "MAN": "pantano", "TUN": "nieve", "ICE": "nieve"}
ALT_MONTANA = 2500.0
ALT_COLINA = 900.0

# Perfiles de terreno de una formación (lo que vale cada terreno para ella)
PERFILES = {
    "cerrada":    {"llano": 1.15, "bosque": 0.80, "selva": 0.70, "colina": 0.90, "montana": 0.70, "desierto": 1.00, "pantano": 0.75, "urbano": 0.80, "nieve": 0.85},
    "flexible":   {"llano": 1.05, "bosque": 0.95, "selva": 0.85, "colina": 1.00, "montana": 0.90, "desierto": 1.00, "pantano": 0.90, "urbano": 0.95, "nieve": 0.95},
    "movil":      {"llano": 1.25, "bosque": 0.60, "selva": 0.50, "colina": 0.85, "montana": 0.50, "desierto": 1.20, "pantano": 0.50, "urbano": 0.50, "nieve": 0.80},
    "ligera":     {"llano": 0.85, "bosque": 1.25, "selva": 1.30, "colina": 1.15, "montana": 1.25, "desierto": 0.85, "pantano": 1.05, "urbano": 1.20, "nieve": 1.00},
    "fuego":      {"llano": 1.15, "bosque": 0.80, "selva": 0.70, "colina": 1.00, "montana": 0.80, "desierto": 1.05, "pantano": 0.75, "urbano": 0.85, "nieve": 0.85},
    "defensiva":  {"llano": 1.05, "bosque": 1.00, "selva": 0.90, "colina": 1.10, "montana": 1.00, "desierto": 1.00, "pantano": 0.85, "urbano": 1.15, "nieve": 0.95},
    "mecanizada": {"llano": 1.25, "bosque": 0.70, "selva": 0.60, "colina": 0.90, "montana": 0.60, "desierto": 1.25, "pantano": 0.55, "urbano": 0.75, "nieve": 0.80},
    "universal":  {"llano": 1.05, "bosque": 1.00, "selva": 0.95, "colina": 1.00, "montana": 0.95, "desierto": 1.05, "pantano": 0.95, "urbano": 1.00, "nieve": 0.95},
    "urbana":     {"llano": 0.90, "bosque": 1.00, "selva": 0.95, "colina": 1.00, "montana": 1.00, "desierto": 0.90, "pantano": 0.95, "urbano": 1.30, "nieve": 0.95},
    "montana":    {"llano": 0.90, "bosque": 1.10, "selva": 1.05, "colina": 1.20, "montana": 1.35, "desierto": 0.90, "pantano": 0.90, "urbano": 1.00, "nieve": 1.10},
    "anfibia":    {"llano": 1.00, "bosque": 0.95, "selva": 0.95, "colina": 0.95, "montana": 0.85, "desierto": 1.00, "pantano": 1.05, "urbano": 0.95, "nieve": 0.90},
}

# ─────────────────────────────────────────── FORMACIONES ───────────────────────────────────────────
# Cuadro de 5 filas × 4 columnas (de arriba a abajo; de izquierda a derecha = de la retaguardia al FRENTE). Letras de arma; «.» vacío;
# M = la mejor tropa de choque que conozca el país (P, L o I), R = la mejor de tiro (F o T), S = la mejor de caballería (C o c).
# Números: atq (ataque cuerpo a cuerpo), tiro (daño de tiro), dano (daño recibido; menos es mejor), flanco (daño extra si lo atacan de lado),
#          flanqueo (daño extra al atacar de lado), moral (puntos al empezar), apertura (ataque en las 2 primeras rondas), res (arma -> daño recibido de ella).
# Campos: slug, nombre, req (descubrimiento; "" = siempre), perfil, cuadro, nums, descripción
F = []


def f(slug, nombre, req, perfil, cuadro, desc, atq=1.0, tiro=1.0, dano=1.0, flanco=1.0, flanqueo=1.0, moral=0, apertura=1.0, res=None, atrinch=False, mov=0):
    F.append({"slug": slug, "nombre": nombre, "req": req, "perfil": perfil, "cuadro": cuadro, "desc": desc, "atq": atq, "tiro": tiro, "dano": dano, "flanco": flanco,
              "flanqueo": flanqueo, "moral": moral, "apertura": apertura, "res": res or {}, "atrinch": atrinch, "mov": mov})


f("formacion_libre", "Formación libre", "", "flexible", ["R.MM", "R.MM", "RSMM", "R.MM", "R.MM"],
  "Sin orden de batalla: tus tropas de choque delante, las de tiro detrás y la caballería en el centro. Sirve a cualquier ejército.")
f("emboscada", "Emboscada y acecho", "emboscada_acecho", "ligera", ["I...", "..I.", "I..I", "..I.", "I..."],
  "Cazadores escondidos que saltan juntos sobre el enemigo: devastadores al principio, frágiles después.", atq=1.1, dano=1.2, apertura=1.7, flanqueo=1.3)
f("horda_tribal", "Horda tribal", "formacion_tribal", "flexible", ["..IP", "I.PP", ".IPP", "I.PP", "..IP"],
  "Una masa sin orden de guerreros que se lanza de golpe. Pega fuerte pero se rompe pronto.", atq=1.1, dano=1.15, flanco=1.2, moral=-9)
f("carros_de_guerra", "Carga de carros", "carros_guerra", "movil", ["T.CP", "..C.", "T.CP", "..C.", "T.CP"],
  "Carros de guerra que revientan la línea enemiga, con arqueros y guerreros a pie detrás.", atq=1.3, dano=1.1, flanco=1.2, apertura=1.35)
f("linea_de_choque", "Línea de choque", "batalla_campal_organizada", "flexible", ["..LP", "..LP", ".TLP", "..LP", "..LP"],
  "La primera batalla organizada: una línea de lanzas y mazas con arqueros que apoyan desde atrás.", atq=1.05)
f("falange_hoplita", "Falange hoplita", "falange", "cerrada", ["...c", "TPPL", "TPPL", "TPPL", "...c"],
  "Escudos y lanzas en bloque macizo: casi imbatible de frente, vulnerable por los flancos.", atq=1.15, dano=0.9, flanco=1.6, moral=6)
f("falange_macedonia", "Falange macedonia", "falangitas", "cerrada", ["..cC", "ILLL", "ILLL", "ILLL", "..cC"],
  "La sarisa clava al enemigo mientras la caballería de los compañeros lo rodea.", atq=1.25, dano=0.85, flanco=1.7, flanqueo=1.2, moral=6)
f("falange_oblicua", "Orden oblicuo tebano", "falange_oblicua", "cerrada", ["..LP", ".TPP", "TPPP", ".TLP", "...P"],
  "Se refuerza un ala y se retrasa la otra: el golpe cae donde el enemigo es más débil.", atq=1.2, dano=0.95, flanco=1.4, flanqueo=1.2)
f("legion_manipular", "Legión manipular", "legion_manipular", "flexible", ["P.IP", ".P.P", "P.IP", ".P.P", "P.IP"],
  "Manípulos en tablero que se relevan: Roma pelea en líneas flexibles que se cierran o se abren.", atq=1.1, dano=0.9, flanco=1.1, moral=6)
f("cohortes", "Orden de cohortes", "cohortes_legionarias", "flexible", [".A.P", "TPPP", "TPPP", "TPPP", ".A.P"],
  "Cohortes de 480 hombres con balistas: un bloque profesional que aguanta y avanza.", atq=1.2, dano=0.85, moral=9)
f("testudo", "Testudo", "testudo_romana", "defensiva", ["..PP", "TPPP", "TPPP", "TPPP", "..PP"],
  "El caparazón de escudos: casi inmune a las flechas, lento y poco ofensivo.", atq=0.8, dano=0.8, flanco=1.2, res={"T": 0.45, "F": 0.8, "A": 0.9})
f("elefantes_en_linea", "Línea de elefantes", "elefantes_guerra", "movil", ["I.CP", "TLCP", "I.C.", "TLCP", "I.CP"],
  "Elefantes de guerra en el centro: aplastan lo que tocan, pero un pánico los vuelve contra los suyos.", atq=1.3, dano=1.0, flanco=1.2, moral=-5, apertura=1.2)
f("cuna_caballeria", "Cuña de caballería", "cuna_de_caballeria", "movil", ["I.c.", "..CC", "T.CC", "..CC", "I.c."],
  "Un triángulo de jinetes que rompe la línea en un punto y la abre en dos.", atq=1.35, dano=1.05, flanco=1.2, flanqueo=1.2, apertura=1.3)
f("pinza_cannas", "Doble envolvimiento", "estrategia_clasica", "flexible", ["..CC", ".TLP", ".TPP", ".TLP", "..CC"],
  "Un centro que cede y dos alas que rodean: la jugada de Cannas.", atq=1.1, dano=1.0, flanco=1.3, flanqueo=1.45)
f("guerrilla", "Guerrilla", "tactica_guerrilla", "ligera", ["I.I.", ".I.T", "I.I.", ".T.I", "I.I."],
  "Grupos pequeños que golpean y se pierden en el terreno. Muy fuertes en monte, débiles en campo abierto.", atq=0.95, dano=0.6, apertura=1.3, flanqueo=1.2, res={"F": 0.75, "T": 0.8, "A": 0.7, "V": 0.8})
f("cuna_nordica", "Cuña nórdica", "cuna_nordica", "flexible", ["..P.", "T.PP", "..PP", "T.PP", "..P."],
  "El «hocico de cerdo» de los guerreros del norte: una cuña de hachas que se hunde en el centro.", atq=1.3, dano=1.0, flanco=1.3, moral=4, apertura=1.2)
f("arqueros_en_masa", "Arqueros en masa", "tactica_arqueros_masa", "defensiva", ["TT.L", "TT.P", "TT.L", "TT.P", "TT.L"],
  "Estacas delante y lluvias de flechas desde atrás: el arco largo detiene cargas de caballería.", atq=0.8, tiro=1.35, dano=0.8, res={"C": 0.6, "c": 0.7}, atrinch=True)
f("muro_de_escudos", "Muro de escudos", "huscarls_nordicos", "defensiva", ["T.PP", "T.PP", "T.PP", "T.PP", "T.PP"],
  "Escudo contra escudo, sin huecos: un muro humano que se sostiene hasta que alguien cae.", atq=1.0, dano=0.8, flanco=1.5, moral=10, res={"T": 0.7})
f("carga_feudal", "Carga de caballería pesada", "carga_caballeria_pesada", "movil", ["...c", "TLCC", "..CC", "TLCC", "...c"],
  "Caballeros acorazados en cuña: el primer choque decide la batalla.", atq=1.4, dano=1.05, flanco=1.2, apertura=1.45)
f("horda_nomada", "Táctica nómada", "jinetes_arqueros_nomadas", "movil", ["...c", "c.cc", "...c", "c.cc", "...c"],
  "Jinetes arqueros que disparan, se retiran y vuelven: desgastan al enemigo sin dejarse alcanzar.", atq=0.9, tiro=1.25, dano=0.85, apertura=1.2, mov=1)
f("tumen_mongol", "Tumen mongol", "tumen_mongol", "movil", ["..cc", "c.CC", "..cc", "c.CC", "..cc"],
  "Diez mil jinetes que fingen huir para romper al enemigo cuando se desordena.", atq=1.1, tiro=1.3, dano=0.85, flanqueo=1.4, apertura=1.3, mov=1)
f("cuadro_piqueros", "Cuadro de piqueros", "tactica_cuadro_piqueros", "defensiva", ["T.LL", "TLLL", "TLLL", "TLLL", "T.LL"],
  "Un erizo de picas: la caballería no puede con él, pero un cañón sí.", atq=0.9, dano=0.9, flanco=1.0, res={"C": 0.55, "c": 0.6})
f("tercio", "Tercio", "tercios_formacion_mixta", "defensiva", ["FF.L", "FLLL", "FLLL", "FLLL", "FF.L"],
  "Piqueros en el centro y mangas de arcabuceros en las esquinas: la infantería más temida del siglo XVI.", atq=1.0, tiro=1.2, dano=0.9, moral=10, res={"C": 0.55, "c": 0.6})
f("caracol_reiter", "Caracol de pistoleros", "caracol_reiters", "movil", ["c.CC", "..CC", "c.CC", "..CC", "c.CC"],
  "Filas de jinetes que disparan y dan la vuelta para recargar.", atq=1.1, tiro=1.2, dano=1.0, flanco=1.2)
f("brigada_sueca", "Brigada sueca", "brigada_sueca", "flexible", ["AF.L", "AFFL", "AFFL", "AFFL", "AF.L"],
  "Brigadas pequeñas y móviles con cañones ligeros: la maniobra de Gustavo Adolfo.", atq=1.1, tiro=1.3, dano=0.95, moral=6)
f("linea_fuego", "Línea de fuego", "tactica_linea", "fuego", ["c.FF", "..FF", "..FF", "..FF", "c.FF"],
  "Una línea delgada y larga en la que todos disparan a la vez: el siglo de los mosquetes.", atq=0.8, tiro=1.25, dano=1.0, flanco=1.5)
f("fuego_pelotones", "Fuego de pelotones", "fuego_de_pelotones", "fuego", ["F.FF", "F.FF", "F.FF", "F.FF", "F.FF"],
  "Pelotones que disparan por turnos: el fuego nunca se interrumpe.", atq=0.8, tiro=1.45, dano=1.0, flanco=1.4, moral=5)
f("columna_ataque", "Columna de ataque", "tactica_columna_ataque", "flexible", ["PPPI", "....", "PPPI", "....", "PPPI"],
  "Columnas profundas tras una pantalla de tiradores: el golpe de la Revolución y de Napoleón.", atq=1.35, tiro=0.7, dano=1.1, flanco=1.3, moral=8)
f("orden_oblicuo", "Orden oblicuo", "orden_oblicuo", "fuego", ["F.FF", "F.FP", "FPFP", "F.FP", "F.FF"],
  "Federico de Prusia refuerza un ala y destroza el flanco enemigo mientras el resto sostiene.", atq=1.1, tiro=1.3, dano=0.95, flanco=1.3, flanqueo=1.35)
f("cuadro_infanteria", "Cuadro de infantería", "infanteria_linea", "defensiva", ["FFFF", "F..F", "F..F", "F..F", "FFFF"],
  "Un cuadro hueco de fusileros contra la caballería: bayonetas por fuera, oficiales dentro.", atq=0.8, tiro=1.0, dano=0.95, res={"C": 0.5, "c": 0.5})
f("gran_bateria", "Gran batería", "artilleros", "fuego", ["..FP", "AAAF", "AAAP", "AAAF", "..FP"],
  "Decenas de cañones concentrados que abren un hueco antes de que avance la infantería.", atq=0.8, tiro=1.5, dano=1.1)
f("orden_disperso", "Orden disperso", "tactica_dispersion", "ligera", ["I.IF", ".F.I", "I.IF", ".F.I", "I.IF"],
  "Tiradores sueltos que aprovechan cada árbol y cada tapia.", atq=0.9, tiro=1.2, dano=0.75, flanco=0.9)
f("guerra_montana", "Guerra de montaña", "tactica_guerra_montana", "montana", ["I.IF", ".I.T", "I.IF", ".I.T", "I.IF"],
  "Cazadores de monte que se atrincheran en las alturas y bajan al valle solo para rematar.", atq=0.9, tiro=1.2, dano=0.8, apertura=1.15)
f("infiltracion", "Infiltración", "tactica_infiltracion", "flexible", ["A.PI", "..I.", "A.PI", "..I.", "A.PI"],
  "Grupos de asalto que se cuelan por las grietas de la línea enemiga y atacan por detrás.", atq=1.3, dano=0.85, apertura=1.5, flanqueo=1.4)
f("combate_urbano", "Combate urbano", "combate_urbano", "urbana", ["..FI", "A.FI", "..FP", "A.FI", "..FI"],
  "Casa por casa, esquina por esquina: la infantería manda y los blindados sufren.", atq=1.0, tiro=1.1, dano=0.8, flanco=0.9)
f("linea_trincheras", "Línea de trincheras", "guerra_de_trincheras", "defensiva", [".AFF", ".AFF", ".AFF", ".AFF", ".AFF"],
  "Trincheras, alambre y ametralladoras: casi imposible de tomar de frente.", atq=0.7, tiro=1.2, dano=0.6, flanco=0.8, atrinch=True, res={"C": 0.5, "c": 0.5})
f("defensa_profundidad", "Defensa en profundidad", "defensa_en_profundidad", "defensiva", ["BAIF", ".AIF", "BAIF", ".AIF", "BAIF"],
  "Varias líneas de resistencia y una reserva móvil que contraataca donde el enemigo rompe.", atq=0.85, dano=0.7, flanco=0.8, atrinch=True)
f("defensa_erizo", "Defensa en erizo", "defensa_erizo", "defensiva", ["AFIF", "BFPF", "AFIF", "BFPF", "AFIF"],
  "Puntos fuertes que se cubren entre sí: rodeados, siguen peleando en todas direcciones.", atq=0.85, dano=0.7, flanco=0.7, moral=10, atrinch=True)
f("armas_combinadas", "Armas combinadas", "armas_combinadas", "mecanizada", ["A.BF", "A.FP", "V.BF", "A.FP", "A.BF"],
  "Infantería, blindados, artillería y aviones que se apoyan: cada arma tapa la debilidad de otra.", atq=1.25, tiro=1.15, dano=0.9)
f("guerra_relampago", "Guerra relámpago", "guerra_relampago", "mecanizada", ["V.BB", "..BF", "V.BB", "..BF", "V.BB"],
  "Blindados y aviones en cuña que rompen por un punto, se adentran y desorganizan la retaguardia.", atq=1.45, tiro=1.1, dano=1.0, flanco=1.1, flanqueo=1.6, apertura=1.2, mov=1)
f("operaciones_profundas", "Operaciones en profundidad", "operaciones_profundas", "mecanizada", ["ABBF", "A.BF", "ABBF", "A.BF", "ABBF"],
  "Oleadas sucesivas de blindados que no dejan al enemigo reorganizarse.", atq=1.4, tiro=1.2, dano=0.95, flanqueo=1.3, moral=6)
f("cercos_bolsas", "Cercos y bolsas", "cercos_y_bolsas", "mecanizada", ["V.BB", "..FB", "V.BB", "..FB", "V.BB"],
  "Dos pinzas blindadas que se cierran detrás del enemigo y lo aíslan.", atq=1.3, dano=1.0, flanqueo=1.7, apertura=1.15)
f("aerotransportada", "Operación aerotransportada", "operaciones_aerotransportadas", "universal", ["V.FI", "V.FF", "V.FI", "V.FF", "V.FI"],
  "Paracaidistas que caen detrás de la línea mientras la aviación los cubre.", atq=1.1, tiro=1.1, dano=1.0, flanco=0.9, apertura=1.5)
f("desembarco", "Desembarco anfibio", "desembarco_anfibio", "anfibia", ["V.FP", "A.FP", "V.FP", "A.FP", "V.FP"],
  "Infantería de marina bajo el fuego naval y aéreo: la playa se toma con el primer escalón.", atq=1.1, tiro=1.1, dano=1.05, apertura=1.25)
f("aeroterrestre", "Batalla aeroterrestre", "doctrina_batalla_aeroterrestre", "universal", ["VABF", "VAFF", "VABF", "VAFF", "VABF"],
  "Helicópteros, aviones, blindados y artillería coordinados al segundo.", atq=1.4, tiro=1.3, dano=0.85, flanqueo=1.2)
f("operaciones_conjuntas", "Operaciones conjuntas", "operaciones_conjuntas", "universal", ["VABF", "VAFR", "VABF", "VAFR", "VABF"],
  "Tierra, aire y mar bajo un solo mando: se asigna cada fuego a cada blanco.", atq=1.45, tiro=1.35, dano=0.85, moral=8, flanqueo=1.25)
f("guerra_red", "Guerra centrada en red", "guerra_red_centrica", "universal", ["VABF", "V.FI", "VABF", "V.FI", "VABF"],
  "Cada soldado, vehículo y avión conectado en tiempo real: el que ve primero dispara primero.", atq=1.5, tiro=1.5, dano=0.8, moral=10, flanqueo=1.4)
f("enjambre_drones", "Enjambre de drones", "guerra_enjambre_drones", "universal", ["VVVV", "VF.F", "VVVV", "VF.F", "VVVV"],
  "Cientos de drones baratos saturan las defensas y destruyen lo que no pueden detener.", atq=1.2, tiro=1.6, dano=0.85, apertura=1.3)

LETRAS_VALIDAS = set(CODS) | {".", "M", "R", "S"}


def cargar_descubrimientos():
    js = json.load(open(os.path.join(RAIZ, "datos", "descubrimientos.json"), encoding="utf-8"))
    ix = {c: i for i, c in enumerate(js["columnas"])}
    return {r[0]: (int(r[2]), int(r[ix["anio"]])) for r in js["filas"]}


def construir():
    desc = cargar_descubrimientos()
    errores = []
    for slug, arma, nivel in TROPAS:
        if slug not in desc:
            errores.append("tropa: el descubrimiento «%s» no existe" % slug)
        if arma not in CODS:
            errores.append("tropa «%s»: arma «%s» no existe" % (slug, arma))
    vistos = set()
    for s, _a, _n in TROPAS:
        if s in vistos:
            errores.append("tropa repetida: %s" % s)
        vistos.add(s)
    for slug, arma, contra, mult, _t in MEJORAS:
        if slug not in desc:
            errores.append("mejora: «%s» no existe" % slug)
    slugs_f = set()
    formaciones = []
    for fo in F:
        if fo["slug"] in slugs_f:
            errores.append("formación repetida: " + fo["slug"])
        slugs_f.add(fo["slug"])
        if fo["req"] and fo["req"] not in desc:
            errores.append("formación %s: el descubrimiento «%s» no existe" % (fo["slug"], fo["req"]))
        c = fo["cuadro"]
        if len(c) != 5 or any(len(x) != 4 for x in c):
            errores.append("formación %s: el cuadro debe ser de 5 filas × 4 columnas" % fo["slug"])
        elif any(ch not in LETRAS_VALIDAS for x in c for ch in x):
            errores.append("formación %s: letra de arma desconocida en el cuadro" % fo["slug"])
        elif not any(ch != "." for x in c for ch in x):
            errores.append("formación %s: cuadro vacío" % fo["slug"])
        if fo["perfil"] not in PERFILES:
            errores.append("formación %s: perfil «%s» desconocido" % (fo["slug"], fo["perfil"]))
        era, anio = desc.get(fo["req"], (0, -10000000)) if fo["req"] else (0, -10000000)
        fo2 = dict(fo)
        fo2["era"] = era
        fo2["anio"] = anio
        fo2["terreno"] = PERFILES[fo["perfil"]]
        fo2["celdas"] = sum(1 for x in c for ch in x if ch != ".")
        formaciones.append(fo2)
    formaciones.sort(key=lambda x: (x["anio"], x["slug"]))
    if errores:
        for e in errores:
            print("  ERROR:", e)
        sys.exit(1)
    # la matriz como lista de listas en el orden de ARMAS
    matriz = [MATRIZ[c] for c in CODS]
    return {
        "version": VERSION,
        "ayuda": "Generado por herramientas/construir_combate.py; no se edita a mano. Arma = clase de tropa; la matriz va de atacante (fila) a defensor (columna) en el orden de «armas».",
        "armas": [{"cod": a[0], "slug": a[1], "nombre": a[2], "atq": a[3], "tiro": a[4], "def": a[5], "mov": a[6], "alc": a[7], "moral": a[8], "peso": a[9],
                   "color": a[10], "glifo": a[11]} for a in ARMAS],
        "matriz": matriz,
        "tropas": [[s, a, n] for s, a, n in TROPAS],
        "mejoras": [{"req": s, "arma": a, "contra": c, "mult": m, "texto": t} for s, a, c, m, t in MEJORAS],
        "terrenos": [{"cod": t[0], "nombre": t[1], "defensor": t[2], "mods": t[3]} for t in TERRENOS],
        "biomas": BIOMAS,
        "alt_montana": ALT_MONTANA,
        "alt_colina": ALT_COLINA,
        "formaciones": formaciones,
    }


def main():
    js = construir()
    print("armas %d · tropas %d · mejoras %d · terrenos %d · formaciones %d" % (len(js["armas"]), len(js["tropas"]), len(js["mejoras"]), len(js["terrenos"]), len(js["formaciones"])))
    if "--solo-comprobar" in sys.argv:
        print("comprobado: sin errores")
        return
    ruta = os.path.join(RAIZ, "datos", "combate.json")
    with open(ruta, "w", encoding="utf-8") as fh:
        json.dump(js, fh, ensure_ascii=False, indent=1)
    print("escrito", ruta, "(%.0f KB)" % (os.path.getsize(ruta) / 1024))


if __name__ == "__main__":
    main()
