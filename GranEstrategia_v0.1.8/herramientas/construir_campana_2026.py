#!/usr/bin/env python3
"""
0.1.8.39 — Construye datos/campana_2026.json: la lista FIJA de países de la CAMPAÑA (Europa + Rusia y Turquía, el mundo de 2026).
El menú de CAMPAÑA lee este archivo en vez del mundo cargado: si venías del escenario del año 1 d. C. (o de un viaje en el tiempo del Debug) el mundo
cargado trae pueblos antiguos, y el menú los listaba aunque la campaña siempre se juega en 2026.

Misma regla que `Mundo.paises_de_campana()` (scripts/entidades.gd): los países de continente «Europa» de datos/entidades.json más CAMPANA_EXTRA, y solo
los que tienen al menos una provincia en datos/provincias_juego.json (los demás no salen en el menú). `test/runner81` comprueba que este archivo
coincide con lo que da el mundo de 2026; si se regeneran las entidades o las provincias, hay que volver a correr este script.

Uso (desde la carpeta del proyecto):   python3 -I herramientas/construir_campana_2026.py
"""
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(RAIZ, "datos")
CAMPANA_EXTRA = ["Rusia", "Turquía"]          # igual que Mundo.CAMPANA_EXTRA


def main():
    with open(os.path.join(DATOS, "entidades.json"), encoding="utf-8") as f:
        paises = json.load(f)["paises"]
    with open(os.path.join(DATOS, "provincias_juego.json"), encoding="utf-8") as f:
        con_prov = {p["c"] for p in json.load(f)["provincias"]}
    lista = [n for n, e in paises.items() if e.get("cont") == "Europa"]
    lista += [n for n in CAMPANA_EXTRA if n in paises and n not in lista]
    lista = sorted(n for n in lista if n in con_prov)
    ruta = os.path.join(DATOS, "campana_2026.json")
    with open(ruta, "w", encoding="utf-8") as f:
        json.dump({"version": "0.1.8.39", "paises": lista}, f, ensure_ascii=False, indent=0)
        f.write("\n")
    print("%s: %d países" % (ruta, len(lista)))


if __name__ == "__main__":
    main()
