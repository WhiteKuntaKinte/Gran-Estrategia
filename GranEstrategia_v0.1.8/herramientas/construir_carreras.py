#!/usr/bin/env python3
"""Genera datos/carreras.json: las 40 ocupaciones de la gente (0.1.8.47).

Cada carrera dice qué nivel de estudios pide, de qué campo del catálogo de descubrimientos depende y desde qué fracción de ese campo existe
(sin medicina descubierta no hay médicos; sin computación, programadores). El juego las reparte entre la población en edad de trabajar
(scripts/educacion.gd: fuerza_laboral) según los estudios de la provincia y lo que el país sabe.

  nivel   0 = sin estudios (agrario) · 1 = oficio / primaria · 2 = secundaria · 3 = estudios superiores. Quien tiene más estudios que el nivel de un oficio también puede ejercerlo (con menos probabilidad).
  campo   código de sección del catálogo (MED, ING…). Si el código está en dos ramas se escribe «rama.cod» (CIE.COM = Computación, SOC.COM = Comunicación y medios).
  desde   fracción mínima conocida del campo para que la carrera exista (0 = desde siempre)
  peso    importancia relativa dentro de su nivel
  grupo   a qué apunta: agro, produccion, comercio, ingenieria, salud, docencia, investigacion, tecnologia, gobierno, justicia, militar, cultura

Uso: python3 herramientas/construir_carreras.py   (desde GranEstrategia_v0.1.8/)
"""
import json
import os

# id, nombre, nivel, campo, desde, peso, grupo, descripción
CARRERAS = [
    # ── nivel 0-1: trabajo manual, oficios y comercio (los agrarios se reparten aparte: por urbanización y mecanización) ──
    ("agricultor", "Agricultor", 0, "AGR", 0.0, 100, "agro", "Siembra y cosecha. En todo país antiguo es la mayor parte de la gente."),
    ("pastor", "Pastor y ganadero", 0, "AGR", 0.0, 22, "agro", "Cuida rebaños: leche, lana, cuero y carne."),
    ("pescador", "Pescador", 0, "TIE", 0.0, 10, "agro", "Vive del mar y de los ríos."),
    ("minero", "Minero", 1, "REC", 0.02, 5, "produccion", "Saca piedra, sal, metal y carbón."),
    ("artesano", "Artesano", 1, "BAS", 0.0, 70, "produccion", "Alfarero, carpintero, curtidor: lo hace todo a mano."),
    ("constructor", "Albañil y constructor", 1, "ING", 0.02, 35, "ingenieria", "Levanta casas, murallas, acueductos y puentes."),
    ("herrero", "Herrero y metalúrgico", 1, "QUI", 0.02, 15, "produccion", "Fragua herramientas y armas."),
    ("tejedor", "Tejedor y sastre", 1, "MAN", 0.0, 25, "produccion", "Hila, teje y confecciona."),
    ("marinero", "Marinero y transportista", 1, "TRA", 0.0, 40, "comercio", "Lleva barcos y cargas por mar y por tierra, de la carreta al camión."),
    ("comerciante", "Comerciante", 1, "ECO", 0.0, 70, "comercio", "Compra, vende y viaja entre mercados."),
    ("soldado", "Soldado profesional", 1, "TRO", 0.0, 8, "militar", "Vive de las armas. En guerra su número crece."),
    ("guardia", "Guardia y policía", 1, "LEY", 0.02, 8, "justicia", "Mantiene el orden y cobra los castigos."),
    ("obrero", "Obrero industrial", 1, "MAN", 0.25, 90, "produccion", "Trabaja en talleres y fábricas."),
    ("operario_energia", "Operario de energía", 1, "ENE", 0.2, 10, "produccion", "Mantiene molinos, calderas, centrales y redes eléctricas."),
    # ── nivel 2: secundaria y formación técnica ──
    ("escriba", "Escriba y copista", 2, "SOC.COM", 0.0, 10, "cultura", "Guarda la memoria por escrito: cartas, cuentas, libros."),
    ("maestro", "Maestro", 2, "EDU", 0.02, 30, "docencia", "Enseña a leer, contar y oficios. Sin escuelas casi no hay maestros."),
    ("enfermero", "Enfermero y partera", 2, "MED", 0.02, 35, "salud", "Cuida a enfermos y trae a los niños al mundo."),
    ("contable", "Funcionario y diplomático", 2, "LEY", 0.03, 30, "gobierno", "Lleva los impuestos, los registros, la burocracia y las embajadas."),
    ("oficial", "Oficial militar", 2, "TAC", 0.02, 5, "militar", "Manda tropas y planea campañas."),
    ("tecnico", "Capataz y técnico", 2, "ING", 0.08, 30, "ingenieria", "Dirige obras y talleres con oficio de ingeniero."),
    ("clero", "Sacerdote y religioso", 2, "REL", 0.0, 15, "cultura", "Guía las creencias, los ritos y buena parte de la enseñanza antigua."),
    ("artista", "Artista y músico", 2, "REL", 0.02, 15, "cultura", "Pinta, esculpe, compone y entretiene."),
    ("jurista", "Jurista y juez", 2, "LEY", 0.05, 10, "justicia", "Escribe y aplica las leyes."),
    ("banquero", "Banquero y financiero", 2, "ECO", 0.15, 15, "comercio", "Presta, cambia moneda y mueve capital."),
    ("periodista", "Periodista y editor", 2, "SOC.COM", 0.15, 5, "cultura", "Informa, imprime y forma la opinión pública."),
    ("empleado", "Empleado de servicios y oficina", 2, "ECO", 0.15, 150, "comercio", "Atiende, registra y gestiona: el oficio más común de una economía de servicios."),
    # ── nivel 3: estudios superiores ──
    ("medico", "Médico", 3, "MED", 0.05, 10, "salud", "Diagnostica y trata. Su número baja la mortalidad."),
    ("cirujano", "Cirujano", 3, "MED", 0.3, 3, "salud", "Opera: cuando existe, salva vidas que antes se perdían."),
    ("farmaceutico", "Farmacéutico y químico", 3, "QUI", 0.15, 5, "salud", "Prepara remedios y estudia materiales."),
    ("ing_civil", "Ingeniero civil", 3, "ING", 0.15, 10, "ingenieria", "Calcula puentes, presas, canales y rascacielos."),
    ("ing_industrial", "Ingeniero mecánico y eléctrico", 3, "ENE", 0.2, 10, "ingenieria", "Máquinas, motores y redes de energía."),
    ("matematico", "Matemático", 3, "MAT", 0.06, 3, "investigacion", "Investiga números, formas y lógica: la base de todo lo demás."),
    ("fisico", "Físico y astrónomo", 3, "FIS", 0.1, 4, "investigacion", "Investiga la materia, la energía, la luz y el cielo."),
    ("biologo", "Biólogo y agrónomo", 3, "BIO", 0.1, 5, "investigacion", "Estudia la vida y mejora cultivos y razas."),
    ("filosofo", "Filósofo e historiador", 3, "HUM", 0.03, 8, "investigacion", "Piensa y estudia al ser humano y su pasado."),
    ("profesor", "Profesor universitario", 3, "EDU", 0.15, 15, "docencia", "Forma a los demás profesionales y sostiene la ciencia del país."),
    ("programador", "Programador e informático", 3, "CIE.COM", 0.2, 30, "tecnologia", "Escribe los programas que mueven la economía moderna."),
    ("ing_telecom", "Ingeniero de telecomunicaciones", 3, "ELE", 0.2, 8, "tecnologia", "Diseña telégrafos, radios, chips y redes móviles."),
    ("ing_armas", "Ingeniero de armamento", 3, "FUE", 0.1, 3, "militar", "Diseña armas, blindajes y sistemas de guerra."),
    ("gerente", "Directivo y profesional de empresa", 3, "ECO", 0.2, 150, "gobierno", "Dirige empresas, oficinas y administraciones; antes de la economía moderna, notables y grandes propietarios."),
]

GRUPOS = ["agro", "produccion", "comercio", "ingenieria", "salud", "docencia", "investigacion", "tecnologia", "gobierno", "justicia", "militar", "cultura"]


def main() -> None:
    aqui = os.path.dirname(os.path.abspath(__file__))
    destino = os.path.join(aqui, "..", "datos", "carreras.json")
    ids = set()
    salida = []
    for (cid, nombre, nivel, campo, desde, peso, grupo, desc) in CARRERAS:
        assert cid not in ids, cid
        assert grupo in GRUPOS, grupo
        assert nivel in (0, 1, 2, 3), nivel
        ids.add(cid)
        salida.append({"id": cid, "nombre": nombre, "nivel": nivel, "campo": campo, "desde": desde, "peso": peso, "grupo": grupo, "desc": desc})
    assert len(salida) == 40, len(salida)
    with open(destino, "w", encoding="utf-8") as f:
        json.dump({"version": "0.1.8.47", "grupos": GRUPOS, "carreras": salida}, f, ensure_ascii=False, indent=1)
    print("datos/carreras.json: %d carreras" % len(salida))


if __name__ == "__main__":
    main()
