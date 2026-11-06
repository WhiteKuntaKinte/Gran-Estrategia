#!/usr/bin/env python3
"""Construye datos/descubrimientos.json (0.1.8.36) a partir del catálogo de descubrimientos.

Fuente de verdad (se edita a mano, nunca el JSON):
  herramientas/descubrimientos/catalogo/*.txt   → qué descubrimientos hay, su era, su tipo y sus prerrequisitos
  herramientas/descubrimientos/anios.tsv        → el AÑO de cada uno (el enlace con el reloj del juego)

Formato del catálogo:
  ## RAMA|COD|Nombre|descripción|@tema      cabecera de sección (el 5.º campo, opcional, marca el tema de color)
  ### Subsección @tema                      subsección (el @tema es opcional)
  slug|Nombre|era|tipo|prerrequisitos       un descubrimiento. Prerrequisitos: a,b,(c|d)  = a Y b Y (c O d)

Reglas que COMPRUEBA este script (si falla alguna no escribe nada):
  1. todo prerrequisito existe, no hay autorreferencias ni ciclos;
  2. todo descubrimiento tiene año, y no sobra ningún año;
  3. año >= año de cada prerrequisito Y (y de al menos UNA alternativa de cada grupo O);
  4. el año cae dentro del rango de su era.

Uso:  python3 herramientas/construir_descubrimientos.py            (escribe datos/descubrimientos.json)
      python3 herramientas/construir_descubrimientos.py --solo-comprobar
"""
import glob
import json
import os
import re
import sys
from collections import OrderedDict

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAT = os.path.join(RAIZ, "herramientas", "descubrimientos", "catalogo")
ANIOS = os.path.join(RAIZ, "herramientas", "descubrimientos", "anios.tsv")
SALIDA = os.path.join(RAIZ, "datos", "descubrimientos.json")
VERSION = "0.1.8.36"

RAMAS = [("MIL", "Militar"), ("CIE", "Científica"), ("SOC", "Sociedad")]
TIPOS = OrderedDict([
    ("U", "Unidad"), ("W", "Arma o equipo"), ("V", "Vehículo o nave"), ("B", "Edificio"),
    ("G", "Gobierno o institución"), ("A", "Acción diplomática o secreta"), ("T", "Técnica o mejora"),
    ("K", "Conocimiento"), ("R", "Recurso del territorio")])
TEMAS = OrderedDict([("med", "Medicina y salud"), ("rec", "Recursos del territorio"), ("tro", "Tropas por época"), ("len", "Lenguas y ciencias humanas")])
# Eras: (nombre, año desde, año hasta); None = sin límite. Los años a. C. van en negativo.
ERAS = [
    ("Prehistoria", None, -10000), ("Neolítico", -10000, -3500), ("Edad del Bronce", -3500, -1200),
    ("Antigüedad e Hierro", -1200, 500), ("Edad Media", 500, 1450), ("Renacimiento", 1450, 1650),
    ("Ilustración", 1650, 1800), ("Industrial", 1800, 1900), ("Guerras mundiales", 1900, 1945),
    ("Guerra Fría e información", 1945, 2000), ("Presente", 2000, 2026), ("Futuro hipotético", 2027, None)]


def parse_req(s):
    """'a,b,(c|d)' -> ([a, b], [[c, d]])"""
    s = s.strip()
    ands, ors = [], []
    if not s:
        return ands, ors
    nivel, cur, partes = 0, "", []
    for ch in s:
        if ch == "(":
            nivel += 1
            cur += ch
        elif ch == ")":
            nivel -= 1
            cur += ch
        elif ch == "," and nivel == 0:
            partes.append(cur)
            cur = ""
        else:
            cur += ch
    partes.append(cur)
    for p in partes:
        p = p.strip()
        if not p:
            continue
        if p.startswith("(") and p.endswith(")"):
            ors.append([x.strip() for x in p[1:-1].split("|") if x.strip()])
        else:
            ands.append(p)
    return ands, ors


def leer_catalogo(errores):
    nodos = OrderedDict()
    secciones = OrderedDict()                 # (rama, cod) -> dict
    rama = sec = sub = None
    for f in sorted(glob.glob(os.path.join(CAT, "*.txt"))):
        nombre_f = os.path.basename(f)
        for ln, crudo in enumerate(open(f, encoding="utf-8"), 1):
            linea = crudo.rstrip("\n")
            if not linea.strip():
                continue
            if linea.startswith("### "):
                sub = linea[4:].strip()
                tag = None
                m = re.search(r"\s+@([a-z]+)$", sub)
                if m:
                    tag = m.group(1)
                    sub = sub[:m.start()].strip()
                s = secciones[(rama, sec)]
                if sub not in s["subs"]:
                    s["subs"].append(sub)
                s["subtags"][sub] = tag
                continue
            if linea.startswith("## "):
                p = linea[3:].split("|")
                if len(p) < 3:
                    errores.append(f"{nombre_f}:{ln} cabecera mala")
                    continue
                rama, sec = p[0].strip(), p[1].strip()
                tag = p[4].strip().lstrip("@") if len(p) > 4 and p[4].strip() else None
                secciones[(rama, sec)] = {"nombre": p[2].strip(), "desc": p[3].strip() if len(p) > 3 else "", "subs": [], "subtags": {}, "tag": tag}
                sub = None
                continue
            p = linea.split("|", 4)
            if len(p) != 5:
                errores.append(f"{nombre_f}:{ln} se esperaban 5 campos")
                continue
            slug, nom, era, tipo, req = [x.strip() for x in p]
            if not re.fullmatch(r"[a-z0-9_]+", slug):
                errores.append(f"{nombre_f}:{ln} slug raro: {slug}")
            if slug in nodos:
                errores.append(f"{nombre_f}:{ln} duplicado: {slug}")
                continue
            if tipo not in TIPOS:
                errores.append(f"{nombre_f}:{ln} tipo desconocido: {tipo}")
            try:
                era = int(era)
                if not 0 <= era < len(ERAS):
                    raise ValueError
            except ValueError:
                errores.append(f"{nombre_f}:{ln} era inválida")
                continue
            ands, ors = parse_req(req)
            nodos[slug] = {"slug": slug, "nombre": nom, "era": era, "tipo": tipo, "rama": rama, "sec": sec, "sub": sub,
                           "ands": ands, "ors": ors, "donde": f"{nombre_f}:{ln}"}
    return nodos, secciones


def leer_anios(errores):
    anios, origen = {}, {}
    for ln, crudo in enumerate(open(ANIOS, encoding="utf-8"), 1):
        linea = crudo.rstrip("\n")
        if not linea.strip() or linea.startswith("#"):
            continue
        p = linea.split("|")
        if len(p) < 3:
            errores.append(f"anios.tsv:{ln} formato")
            continue
        try:
            anios[p[0]] = int(p[1])
        except ValueError:
            errores.append(f"anios.tsv:{ln} año no numérico")
            continue
        origen[p[0]] = p[2]
    return anios, origen


def comprobar(nodos, anios, errores):
    for s in anios:
        if s not in nodos:
            errores.append(f"anios.tsv: sobra «{s}» (no está en el catálogo)")
    for n in nodos.values():
        s = n["slug"]
        refs = list(n["ands"]) + [x for g in n["ors"] for x in g]
        for r in refs:
            if r not in nodos:
                errores.append(f"{n['donde']} {s}: prerrequisito desconocido «{r}»")
        if s in refs:
            errores.append(f"{s}: se pide a sí mismo")
        if s not in anios:
            errores.append(f"{s}: falta su año en anios.tsv")
            continue
        y = anios[s]
        desde, hasta = ERAS[n["era"]][1], ERAS[n["era"]][2]
        if (desde is not None and y < desde) or (hasta is not None and y > hasta):
            errores.append(f"{s}: el año {y} queda fuera de su era {n['era']} ({ERAS[n['era']][0]})")
        for p in n["ands"]:
            if p in anios and anios[p] > y:
                errores.append(f"{s} ({y}) es anterior a su prerrequisito {p} ({anios[p]})")
        for g in n["ors"]:
            vs = [anios[p] for p in g if p in anios]
            if vs and min(vs) > y:
                errores.append(f"{s} ({y}) es anterior a TODAS las alternativas {g}")
    # ciclos (todas las aristas, AND y OR)
    deps = {s: set(n["ands"]) | {x for g in n["ors"] for x in g} for s, n in nodos.items()}
    indeg = {s: len([d for d in ds if d in nodos]) for s, ds in deps.items()}
    hijos = {s: [] for s in nodos}
    for s, ds in deps.items():
        for d in ds:
            if d in nodos:
                hijos[d].append(s)
    cola = [s for s, d in indeg.items() if d == 0]
    vistos = 0
    while cola:
        s = cola.pop()
        vistos += 1
        for h in hijos[s]:
            indeg[h] -= 1
            if indeg[h] == 0:
                cola.append(h)
    if vistos != len(nodos):
        errores.append("hay ciclos en los prerrequisitos: " + ", ".join(sorted(s for s, d in indeg.items() if d > 0)[:10]))


def construir(nodos, secciones, anios, origen):
    ordenR = {c: i for i, (c, _) in enumerate(RAMAS)}
    claves = sorted(secciones.keys(), key=lambda k: ordenR.get(k[0], 99))      # estable: respeta el orden de los archivos dentro de cada rama
    sec_idx = {k: i for i, k in enumerate(claves)}
    tema_idx = {t: i for i, t in enumerate(TEMAS)}
    subs_todas = []
    sub_idx = {}
    for k in claves:
        for sb in secciones[k]["subs"]:
            sub_idx[(k, sb)] = len(subs_todas)
            subs_todas.append(sb)
    orden = list(nodos.keys())
    pos = {s: i for i, s in enumerate(orden)}
    filas = []
    for s in orden:
        n = nodos[s]
        k = (n["rama"], n["sec"])
        sub = sub_idx.get((k, n["sub"]), -1) if n["sub"] else -1
        tag = secciones[k]["subtags"].get(n["sub"]) if n["sub"] else None
        tag = tag or secciones[k]["tag"]
        filas.append([s, n["nombre"], n["era"], n["tipo"], sec_idx[k], sub, tema_idx.get(tag, -1), anios[s], origen.get(s, "h"),
                      [pos[p] for p in n["ands"]], [[pos[p] for p in g] for g in n["ors"]]])
    return {
        "version": VERSION,
        "ayuda": ("Catálogo de DESCUBRIMIENTOS del juego (1.730). No se edita a mano: lo genera herramientas/construir_descubrimientos.py desde "
                  "herramientas/descubrimientos/. Cada descubrimiento lleva su AÑO (a. C. en negativo): un país lo conoce cuando el año del reloj es >= ese año. "
                  "req = índices (posición en `filas`) de los prerrequisitos que hacen falta TODOS; req_o = grupos de alternativas (basta UNO de cada grupo). "
                  "origen del año: h = histórico asignado a mano · a = ajustado por prerrequisitos o era · x = hipotético (futuro)."),
        "eras": [{"nombre": e[0], "desde": e[1], "hasta": e[2]} for e in ERAS],
        "tipos": [{"cod": c, "nombre": v} for c, v in TIPOS.items()],
        "temas": [{"cod": c, "nombre": v} for c, v in TEMAS.items()],
        "ramas": [{"cod": c, "nombre": v} for c, v in RAMAS],
        "secciones": [{"rama": ordenR[k[0]], "cod": k[1], "nombre": secciones[k]["nombre"], "desc": secciones[k]["desc"]} for k in claves],
        "subsecciones": subs_todas,
        "columnas": ["slug", "nombre", "era", "tipo", "seccion", "sub", "tema", "anio", "origen", "req", "req_o"],
        "filas": filas,
    }


def main():
    errores = []
    nodos, secciones = leer_catalogo(errores)
    anios, origen = leer_anios(errores)
    comprobar(nodos, anios, errores)
    if errores:
        print("ERRORES (%d):" % len(errores))
        for e in errores[:60]:
            print("  ·", e)
        sys.exit(1)
    datos = construir(nodos, secciones, anios, origen)
    print("%d descubrimientos · %d secciones · %d subsecciones · conocidos en el año 1: %d · en 2026: %d" % (
        len(datos["filas"]), len(datos["secciones"]), len(datos["subsecciones"]),
        sum(1 for f in datos["filas"] if f[7] <= 1), sum(1 for f in datos["filas"] if f[7] <= 2026)))
    if "--solo-comprobar" in sys.argv:
        return
    with open(SALIDA, "w", encoding="utf-8") as o:
        json.dump(datos, o, ensure_ascii=False, separators=(",", ":"))
    print("escrito", SALIDA, "(%d KB)" % (os.path.getsize(SALIDA) // 1024))


if __name__ == "__main__":
    main()
