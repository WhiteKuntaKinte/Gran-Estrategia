#!/usr/bin/env python3
"""
Construye datos/gobierno.json (0.1.8.52) a partir de los TSV de esta carpeta:
  regimenes.tsv · leyes.tsv · pais_2026.tsv · tipos_epoca.tsv · nombres_epoca.tsv
Los valores son provisionales: se editan en los TSV y se regenera con
  python3 herramientas/gobierno/construir_gobierno.py
No hay nada que bajar de internet. Biblioteca estándar.
"""
import json, os

AQUI = os.path.dirname(os.path.abspath(__file__))
SALIDA = os.path.join(AQUI, "..", "..", "datos", "gobierno.json")


def filas(nombre):
    r = []
    with open(os.path.join(AQUI, nombre), encoding="utf-8") as f:
        for l in f:
            l = l.rstrip("\n")
            if not l.strip() or l.startswith("#"):
                continue
            r.append(l.split("\t"))
    return r


def pares(txt):
    d = {}
    for p in txt.split(";"):
        p = p.strip()
        if "=" in p:
            k, v = p.split("=", 1)
            d[k.strip()] = float(v)
    return d


def main():
    regs = []
    for c in filas("regimenes.tsv"):
        regs.append({"slug": c[0], "nombre": c[1], "mando": float(c[2]), "central": float(c[3]), "lib": float(c[4]), "suces": c[5], "desde": int(c[6]), "desc": c[7]})
    leyes = []
    for c in filas("leyes.tsv"):
        leyes.append({"slug": c[0], "nombre": c[1], "desde": int(c[2]), "costo": float(c[3]), "desc": c[4], "ef": pares(c[5]), "fac": pares(c[6]) if len(c) > 6 else {}})
    p2026 = {c[0]: c[1] for c in filas("pais_2026.tsv")}
    tipos = {c[0]: c[1] for c in filas("tipos_epoca.tsv")}
    nombres = []
    for c in filas("nombres_epoca.tsv"):
        d, h = -100000, 100000
        if len(c) > 2 and ":" in c[2]:
            a, b = c[2].split(":")
            d, h = int(a), int(b)
        nombres.append({"txt": c[0], "reg": c[1], "desde": d, "hasta": h})
    slugs = {r["slug"] for r in regs}
    for v in list(p2026.values()) + list(tipos.values()) + [n["reg"] for n in nombres]:
        assert v in slugs, "régimen desconocido: " + v
    js = {"version": "0.1.8.52", "regimenes": regs, "leyes": leyes, "pais_2026": p2026, "tipos": tipos, "nombres": nombres,
          "defecto_2026": "republica_democratica", "defecto_antiguo": "cacicazgo"}
    with open(SALIDA, "w", encoding="utf-8") as f:
        json.dump(js, f, ensure_ascii=False, separators=(",", ":"))
    print("regímenes %d · leyes %d · países 2026 %d · tipos %d · ajustes por nombre %d" % (len(regs), len(leyes), len(p2026), len(tipos), len(nombres)))


if __name__ == "__main__":
    main()
