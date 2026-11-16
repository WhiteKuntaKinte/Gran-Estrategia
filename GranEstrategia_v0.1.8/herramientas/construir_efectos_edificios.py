#!/usr/bin/env python3
"""Genera datos/edificios_efectos.json: qué hace cada uno de los 109 edificios (0.1.8.48).

Cada edificio tiene 0 o más efectos de 7 clases:
  POR HABITANTE (el edificio atiende a `cob` habitantes; su peso `w` se diluye si la provincia tiene mucha más gente de la que cubre):
    sal  salud: suma a la salud efectiva de la provincia (0-1) -> baja la mortalidad
    com  comida segura: puntos de bienestar (0-100) que suma a la meta de bienestar de la gente
    urb  vivienda y ciudad: suma a la meta de urbanización (fracción 0-1)
    ren  producción: fracción que suma a lo que produce la provincia (mercados, puertos, fábricas, redes)
    ord  orden y cohesión: puntos de estabilidad (0-100) que suma a la meta de la provincia
  PLANOS (no dependen de la gente):
    def  defensa: lo que suma al poder de los defensores en esa provincia (fortificaciones, mando militar)
    mov  movilidad: fracción en que reduce lo que resta la distancia a la capital (calzadas, puentes, puertos)
Los 17 edificios de educación y cultura ya cuentan como INSTITUCIONES DE SABER en la demografía (alfabetización y docentes): no repiten efecto aquí,
salvo los que además hacen otra cosa (museos, laboratorios, estación espacial).

Regla de partida (ver docs/EDIFICIOS_EFECTOS.md): los edificios que ya había al empezar el escenario YA están en los datos de esa época (renta, población, esperanza
de vida), así que sal / com / urb / ren solo cuentan lo construido DESPUÉS. def, ord y mov cuentan todo (los datos reales no los traen).
"""
import json, os, sys

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
VERSION = "0.1.8.49"

TIPOS = {
    "sal": {"nombre": "Salud", "por_habitante": True, "tope": 0.25, "unidad": "puntos de salud efectiva (0-1)",
            "texto": "Baja la mortalidad de la provincia"},
    "com": {"nombre": "Comida segura", "por_habitante": True, "tope": 14.0, "unidad": "puntos de bienestar",
            "texto": "Sube el bienestar de la gente (almacenes, riego, abastos)"},
    "urb": {"nombre": "Vivienda y ciudad", "por_habitante": True, "tope": 0.12, "unidad": "fracción urbana",
            "texto": "Sube la urbanización de la provincia"},
    "ren": {"nombre": "Producción", "por_habitante": True, "tope": 0.35, "unidad": "fracción de la producción",
            "texto": "Sube lo que produce la provincia (mercados, puertos, fábricas, redes)"},
    "ord": {"nombre": "Orden y cohesión", "por_habitante": True, "tope": 8.0, "unidad": "puntos de estabilidad",
            "texto": "Sube la estabilidad de la provincia"},
    "def": {"nombre": "Defensa", "por_habitante": False, "tope": 1.2, "unidad": "× al poder de los defensores",
            "texto": "Los defensores de la provincia pelean más fuerte"},
    "mov": {"nombre": "Movilidad", "por_habitante": False, "tope": 0.6, "unidad": "fracción del castigo de la distancia",
            "texto": "La provincia se siente menos lejos de la capital"},
}

K = 1000
M = 1000 * K
# slug: [(tipo, peso, habitantes que atiende cada unidad)]  (def y mov son planos: el tercer valor es 0)
EFECTOS = {
    # ── Vivienda y ciudad ──
    "cabana_madera": [("urb", 0.004, 3 * K)],
    "campamento_estacional": [("urb", 0.002, 2 * K)],
    "adobe_barro": [("urb", 0.004, 4 * K)],
    "aldea_permanente": [("urb", 0.010, 10 * K), ("com", 1.0, 8 * K)],
    "construccion_piedra": [("urb", 0.010, 20 * K), ("sal", 0.010, 30 * K)],
    "ciudad_primitiva": [("urb", 0.050, 40 * K), ("ren", 0.020, 40 * K), ("ord", 1.0, 40 * K)],
    "templos_monumentales": [("ord", 2.5, 150 * K)],
    "arco_boveda": [("ord", 0.5, 100 * K), ("ren", 0.005, 100 * K)],
    "foro_agora": [("ord", 2.0, 100 * K), ("urb", 0.020, 100 * K)],
    "ciudades_romanas_servicios": [("sal", 0.080, 250 * K), ("urb", 0.030, 250 * K), ("ord", 1.0, 250 * K)],
    "cupula": [("ord", 1.5, 200 * K)],
    "burgos_fortificados": [("urb", 0.040, 40 * K), ("def", 0.20, 0), ("ren", 0.015, 40 * K)],
    "catedral_gotica": [("ord", 3.0, 250 * K)],
    "plazas_mercado_urbano": [("com", 3.0, 60 * K), ("ren", 0.020, 60 * K), ("urb", 0.010, 60 * K)],
    "barrios_obreros": [("urb", 0.030, 150 * K), ("ord", 1.0, 150 * K), ("sal", 0.010, 150 * K)],
    "parques_publicos": [("sal", 0.020, 100 * K), ("ord", 1.5, 100 * K)],
    "rascacielos": [("urb", 0.060, 500 * K), ("ren", 0.030, 500 * K)],
    # ── Transporte y obras públicas ──
    "puente_madera": [("mov", 0.04, 0), ("ren", 0.010, 60 * K)],
    "puerto_piedra": [("ren", 0.050, 250 * K), ("mov", 0.05, 0), ("com", 3.0, 200 * K)],
    "puente_piedra_arco": [("mov", 0.08, 0), ("ren", 0.020, 150 * K)],
    "faro": [("mov", 0.03, 0), ("ren", 0.010, 300 * K)],
    "calzada_pavimentada": [("mov", 0.15, 0), ("ren", 0.030, 200 * K)],
    "red_viaria_imperial": [("mov", 0.30, 0), ("ren", 0.060, 1 * M)],
    "esclusas_canales": [("ren", 0.050, 500 * K), ("com", 4.0, 400 * K), ("mov", 0.10, 0)],
    "reclamacion_tierras_mar": [("com", 8.0, 300 * K), ("ren", 0.030, 300 * K)],
    "tunel_excavacion": [("mov", 0.05, 0), ("ren", 0.010, 200 * K)],
    "puentes_hierro": [("mov", 0.08, 0), ("ren", 0.020, 300 * K)],
    "puentes_colgantes": [("mov", 0.08, 0), ("ren", 0.020, 400 * K)],
    "metro_subterraneo": [("ren", 0.040, 1500 * K), ("urb", 0.050, 1500 * K)],
    "tunel_ferroviario": [("mov", 0.15, 0), ("ren", 0.030, 600 * K)],
    "canal_interoceanico": [("ren", 0.060, 3 * M), ("mov", 0.10, 0)],
    "transporte_urbano_masivo": [("ren", 0.030, 800 * K), ("urb", 0.040, 800 * K)],
    "aeropuerto": [("mov", 0.20, 0), ("ren", 0.040, 1500 * K)],
    "autopista": [("mov", 0.25, 0), ("ren", 0.040, 1 * M)],
    "puente_atirantado": [("mov", 0.08, 0), ("ren", 0.020, 500 * K)],
    "tunel_submarino": [("mov", 0.10, 0), ("ren", 0.030, 2 * M)],
    # ── Agua y energía ──
    "drenaje_urbano": [("sal", 0.050, 80 * K)],
    "presas_gravedad": [("com", 5.0, 200 * K), ("ren", 0.010, 200 * K)],
    "alcantarillado": [("sal", 0.080, 150 * K)],
    "acueducto": [("sal", 0.070, 200 * K), ("com", 2.0, 200 * K), ("urb", 0.020, 200 * K)],
    "central_termoelectrica": [("ren", 0.060, 1500 * K)],
    "red_electrica": [("ren", 0.050, 800 * K), ("sal", 0.020, 800 * K)],
    "central_hidroelectrica": [("ren", 0.070, 2 * M)],
    "presas_arco_hormigon": [("com", 7.0, 600 * K), ("ren", 0.030, 600 * K)],
    "red_alta_tension": [("ren", 0.040, 2 * M)],
    "planta_depuradora": [("sal", 0.080, 500 * K)],
    "gas_natural": [("ren", 0.050, 2 * M)],
    "central_nuclear": [("ren", 0.080, 4 * M)],
    "parque_eolico": [("ren", 0.040, 1500 * K)],
    "energia_solar_comercial": [("ren", 0.040, 1500 * K)],
    # ── Economía y comercio ──
    "mercados_locales": [("com", 3.0, 40 * K), ("ren", 0.020, 40 * K)],
    "almacenes_suministro": [("com", 6.0, 60 * K), ("ren", 0.010, 60 * K)],
    "feria_comercial": [("ren", 0.030, 250 * K), ("com", 3.0, 250 * K)],
    "arsenal_fundicion": [("ren", 0.030, 400 * K), ("def", 0.10, 0)],
    "fabrica_textil": [("ren", 0.050, 300 * K)],
    "grandes_almacenes": [("ren", 0.040, 400 * K), ("com", 3.0, 400 * K)],
    # ── Educación y cultura: ya cuentan como instituciones de saber; solo los que hacen algo más ──
    "museos_publicos": [("ord", 1.0, 400 * K)],
    "laboratorios_industriales": [("ren", 0.050, 600 * K)],
    "escuelas_tecnicas_ingenieria": [("ren", 0.020, 800 * K)],
    "monasterios_copistas": [("ord", 1.0, 100 * K)],
    "escuelas_monasticas": [("ord", 0.5, 100 * K)],
    # ── Salud ──
    "hospitales_religiosos": [("sal", 0.060, 50 * K), ("ord", 0.5, 50 * K)],
    "escuelas_medicina": [("sal", 0.050, 400 * K)],
    "lazaretos": [("sal", 0.050, 120 * K)],
    "hospital_moderno": [("sal", 0.150, 400 * K)],
    # ── Defensa fija (planas) ──
    "empalizada": [("def", 0.05, 0)],
    "zanja_foso": [("def", 0.04, 0)],
    "fortin_torre_vigia": [("def", 0.06, 0)],
    "murallas_urbanas": [("def", 0.25, 0)],
    "fortaleza_colina": [("def", 0.30, 0)],
    "muralla_piedra": [("def", 0.25, 0)],
    "torres_y_almenas": [("def", 0.10, 0)],
    "limes_fronteras_fortificadas": [("def", 0.50, 0)],
    "castillo_motte": [("def", 0.35, 0)],
    "puertas_fortificadas": [("def", 0.10, 0)],
    "castillo_piedra": [("def", 0.50, 0)],
    "castillo_concentrico": [("def", 0.70, 0)],
    "fortificacion_abaluartada": [("def", 0.90, 0)],
    "fortaleza_estrella": [("def", 0.90, 0)],
    "fortificaciones_permanentes": [("def", 0.90, 0)],
    "fuertes_costeros": [("def", 0.20, 0)],
    "fortificacion_hormigon": [("def", 0.80, 0)],
    "fuertes_acorazados": [("def", 1.00, 0)],
    "casamatas_hormigon": [("def", 0.50, 0)],
    "sistema_trincheras": [("def", 0.40, 0)],
    "linea_defensiva_permanente": [("def", 1.00, 0)],
    "bunker_antiaereo": [("def", 0.20, 0)],
    "bunker_nuclear": [("def", 0.50, 0)],
    "defensa_aerea_integrada": [("def", 0.50, 0)],
    "silo_misil": [("def", 0.30, 0)],
    "base_subterranea_montana": [("def", 0.80, 0)],
    "defensa_costera_misiles": [("def", 0.30, 0)],
    "escudo_antimisiles": [("def", 0.40, 0)],
    # ── Mando y formación militar ──
    "calzadas_militares": [("mov", 0.15, 0), ("def", 0.05, 0)],
    "escuelas_militares": [("def", 0.10, 0)],
    "academia_militar_moderna": [("def", 0.15, 0)],
    "centro_operaciones_ciberneticas": [("def", 0.15, 0)],
    # 0.1.8.49
    "taller_artesano": [("ren", 0.020, 40 * K)],
    "molinos_hidraulicos": [("ren", 0.030, 150 * K), ("com", 2, 150 * K)],
    "molinos_viento": [("ren", 0.025, 120 * K), ("com", 2, 120 * K)],
    "casa_gremio": [("ren", 0.020, 150 * K), ("ord", 1.5, 150 * K)],
    "caravasar_posada": [("mov", 0.050, 0), ("ren", 0.015, 100 * K)],
    "astillero": [("ren", 0.040, 300 * K), ("mov", 0.050, 0)],
    "banco_casa_cambio": [("ren", 0.040, 300 * K)],
    "lonja_bolsa": [("ren", 0.050, 600 * K)],
    "altos_hornos": [("ren", 0.060, 800 * K)],
    "fabrica_vapor": [("ren", 0.070, 1 * M)],
    "acerias": [("ren", 0.080, 1500 * K)],
    "estacion_ferrocarril": [("mov", 0.20, 0), ("ren", 0.040, 800 * K)],
    "parque_industrial": [("ren", 0.050, 2 * M)],
    "puerto_contenedores": [("ren", 0.060, 3 * M), ("mov", 0.10, 0)],
    "centro_comercial": [("ren", 0.030, 1 * M), ("urb", 0.020, 1 * M)],
    "tribunal_audiencia": [("ord", 2, 200 * K)],
    "prision": [("ord", 2, 300 * K)],
    "comisaria_policia": [("ord", 3, 400 * K)],
    "casa_consistorial": [("ord", 2.5, 150 * K)],
    "palacio_gobierno": [("ord", 2.5, 300 * K)],
    "parlamento_edificio": [("ord", 3.5, 1 * M)],
    "iglesia_parroquial": [("ord", 2, 60 * K)],
    "mezquita_aljama": [("ord", 2.5, 100 * K)],
    "templo_pagoda": [("ord", 2, 100 * K)],
    "teatro_anfiteatro": [("ord", 2, 100 * K)],
    "estadio": [("ord", 2, 500 * K)],
    "casa_del_pueblo": [("ord", 2.5, 300 * K)],
    "cuartel_guarnicion": [("def", 0.15, 0)],
    "polvorin": [("def", 0.080, 0)],
    "cuartel_estado_mayor": [("def", 0.20, 0)],
    "estacion_radar": [("def", 0.30, 0)],
    "centro_mando_control": [("def", 0.25, 0)],
}
# edificios sin efecto propio a propósito (su efecto ya está en otra parte del modelo)
SOLO_SABER = ["escuelas_escribas", "academias_filosoficas", "biblioteca", "observatorios_astronomicos", "casa_de_traduccion", "madrasas_escuelas",
              "universidades_medievales", "escuelas_traduccion", "academias_ciencias", "academias_lengua", "universidades_investigacion", "estacion_espacial"]


def main(salida: str) -> int:
    cat = json.load(open(os.path.join(RAIZ, "datos", "edificios.json"), encoding="utf-8"))
    slugs = [e["slug"] for e in cat["edificios"]]
    errores = []
    for s in EFECTOS:
        if s not in slugs:
            errores.append("slug desconocido: " + s)
    for s in SOLO_SABER:
        if s not in slugs:
            errores.append("slug desconocido en SOLO_SABER: " + s)
        if s in EFECTOS:
            errores.append("está en EFECTOS y en SOLO_SABER: " + s)
    for s in slugs:
        if s not in EFECTOS and s not in SOLO_SABER:
            errores.append("sin efecto y sin motivo: " + s)
    for s, lst in EFECTOS.items():
        vistos = set()
        for t, w, cob in lst:
            if t not in TIPOS:
                errores.append("%s: tipo desconocido %s" % (s, t))
                continue
            if t in vistos:
                errores.append("%s: tipo repetido %s" % (s, t))
            vistos.add(t)
            if w <= 0:
                errores.append("%s: peso no positivo" % s)
            if TIPOS[t]["por_habitante"] and cob <= 0:
                errores.append("%s: %s necesita habitantes que atiende" % (s, t))
            if not TIPOS[t]["por_habitante"] and cob != 0:
                errores.append("%s: %s es plano (cobertura 0)" % (s, t))
            if w > TIPOS[t]["tope"]:
                errores.append("%s: peso %s pasa del tope de %s" % (s, w, t))
    if errores:
        print("ERRORES:\n  " + "\n  ".join(errores))
        return 1
    # edu con efecto en cat 'edu' que ya cuenta como institución
    out = {
        "version": VERSION,
        "ayuda": "Efectos de los edificios (0.1.8.48). No se edita a mano: lo genera herramientas/construir_efectos_edificios.py. Cada efecto es [tipo, peso, habitantes que atiende cada unidad (0 si es plano)].",
        "tipos": TIPOS,
        "solo_saber": SOLO_SABER,
        "efectos": {s: [[t, w, cob] for t, w, cob in EFECTOS[s]] for s in slugs if s in EFECTOS},
    }
    with open(salida, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write("\n")
    por_tipo = {}
    for lst in EFECTOS.values():
        for t, _, _ in lst:
            por_tipo[t] = por_tipo.get(t, 0) + 1
    print("OK: %d edificios con efecto, %d solo saber · %s" % (len(EFECTOS), len(SOLO_SABER), ", ".join("%s %d" % kv for kv in sorted(por_tipo.items()))))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "datos", "edificios_efectos.json")))
