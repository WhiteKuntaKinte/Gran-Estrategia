#!/usr/bin/env python3
"""
Busca y baja las BANDERAS (o, si no hay, el escudo o el sello) de los estados de los escenarios históricos desde Wikidata + Wikimedia Commons (0.1.8.52).
Se ejecuta en GitHub Actions (.github/workflows/traer-banderas.yml): Commons y Wikidata no se alcanzan desde el entorno donde Claude escribe el juego,
pero sí desde los servidores de GitHub.

  python3 commons_banderas.py LISTA.json MANUAL.json SALIDA_DIR

  LISTA  = lista_banderas.json (construir_lista_banderas.py): [{id, epoca, nombre_en, nombre_es, qid, anio, desde, hasta}]
  MANUAL = banderas_manual.json: {"<id>": {"archivo": "File:Nombre.svg", "tipo": "bandera|escudo|sello"}}  (gana a Wikidata; sirve para corregir a mano)
  SALIDA = SALIDA_DIR/img/<id>.png (largo máximo 512 px, con transparencia si la trae) y SALIDA_DIR/resultado.json

Qué se elige por estado (de lo mejor a lo peor):
  1. P41 «bandera» de Wikidata — la que estaba vigente en el año del escenario (calificadores P580/P582); si ninguna lo estaba, la preferida o la primera.
  2. P94 «escudo de armas».   3. P158 «sello».
Solo se BAJA lo que tiene dominio público o CC0 (si el primer candidato no es libre se prueba el siguiente tipo). Todo lo demás queda en resultado.json
con su licencia como «rechazada» (para decidir con Camilo si alguna licencia con crédito merece la pena; no se baja nada con atribución obligatoria).
Solo biblioteca estándar + pillow.
"""
import io
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

WD = "https://www.wikidata.org/w/api.php"
CM = "https://commons.wikimedia.org/w/api.php"
UA = "GranEstrategiaJuego/0.1 (https://github.com/WhiteKuntaKinte/gran-estrategia; juego de estrategia, banderas historicas de dominio publico)"
META = "LicenseShortName|Artist|UsageTerms|Copyrighted|ImageDescription"
PROPS = [("P41", "bandera"), ("P94", "escudo"), ("P158", "sello")]
LARGO = 512


def get(url, params=None, intentos=5, binario=False):
    if params:
        url = url + "?" + urllib.parse.urlencode(params)
    for i in range(intentos):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                data = r.read()
            return data if binario else json.loads(data)
        except Exception as e:
            print("  reintento", i + 1, type(e).__name__, str(e)[:90], flush=True)
            time.sleep(4 * (i + 1))
    return None


def limpio(s):
    s = re.sub(r"<[^>]+>", "", str(s or ""))
    return re.sub(r"\s+", " ", s).strip()


def es_libre(md):
    lic = limpio((md.get("LicenseShortName") or {}).get("value", "")).lower()
    copy = limpio((md.get("Copyrighted") or {}).get("value", "")).lower()
    return lic.startswith("public domain") or lic.startswith("pd") or lic.startswith("cc0") or lic.startswith("cc-zero") or copy == "false"


def anio_de(t):
    m = re.match(r"^([+-])(\d+)-", t or "")
    return int(m.group(1) + m.group(2)) if m else None


def candidatos(entidad, anio):
    """[(tipo, 'File:Nombre')] ordenados: bandera vigente, bandera, escudo, sello."""
    out = []
    claims = entidad.get("claims", {})
    for prop, tipo in PROPS:
        enunc = []
        for c in claims.get(prop, []):
            ms = c.get("mainsnak", {})
            if ms.get("snaktype") != "value" or c.get("rank") == "deprecated":
                continue
            nombre = ms["datavalue"]["value"]
            q = c.get("qualifiers", {})
            ini = anio_de(((q.get("P580") or [{}])[0].get("datavalue") or {}).get("value", {}).get("time"))
            fin = anio_de(((q.get("P582") or [{}])[0].get("datavalue") or {}).get("value", {}).get("time"))
            vigente = (ini is None or ini <= anio) and (fin is None or fin >= anio)
            fuera = (ini is not None and ini > anio) or (fin is not None and fin < anio)
            prio = 0 if vigente and (ini is not None or fin is not None) else (1 if c.get("rank") == "preferred" else (2 if not fuera else 3))
            enunc.append((prio, "File:" + nombre.replace("_", " ")))
        for _, f in sorted(enunc, key=lambda x: x[0]):
            if (tipo, f) not in out:
                out.append((tipo, f))
    return out


def info_archivos(titulos):
    res = {}
    for i in range(0, len(titulos), 40):
        lote = titulos[i:i + 40]
        d = get(CM, {"action": "query", "format": "json", "titles": "|".join(lote), "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata",
                     "iiextmetadatafilter": META, "redirects": 1})
        if not d:
            continue
        q = d.get("query", {})
        redir = {r["from"]: r["to"] for r in q.get("redirects", []) + q.get("normalized", [])}
        pags = {p.get("title"): p for p in q.get("pages", {}).values()}
        for t in lote:
            p = pags.get(redir.get(t, t)) or pags.get(t)
            if not p or "imageinfo" not in p:
                continue
            ii = p["imageinfo"][0]
            md = ii.get("extmetadata", {})
            g = lambda k: limpio((md.get(k) or {}).get("value", ""))
            res[t] = {"titulo": p.get("title"), "mime": ii.get("mime", ""), "w": ii.get("width", 0), "h": ii.get("height", 0), "url": ii.get("url", ""),
                      "pagina": ii.get("descriptionurl", ""), "licencia": g("LicenseShortName"), "autor": g("Artist")[:120], "libre": es_libre(md)}
        time.sleep(0.5)
    return res


def bajar(info, destino):
    from PIL import Image
    nombre = info["titulo"].replace(" ", "_")
    url = "https://commons.wikimedia.org/wiki/Special:FilePath/" + urllib.parse.quote(nombre[5:]) + "?width=%d" % LARGO
    if info["mime"] != "image/svg+xml" and max(info["w"], info["h"]) <= LARGO:
        url = info["url"]
    data = get(url, binario=True)
    if not data:
        return False
    try:
        im = Image.open(io.BytesIO(data))
        im.load()
        im = im.convert("RGBA")
    except Exception as e:
        print("  imagen ilegible", nombre, e)
        return False
    if max(im.size) > LARGO:
        k = LARGO / float(max(im.size))
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
    im.save(destino, optimize=True)
    return True


def main():
    lista = json.load(open(sys.argv[1], encoding="utf-8"))
    manual = json.load(open(sys.argv[2], encoding="utf-8")) if os.path.exists(sys.argv[2]) else {}
    sal = sys.argv[3]
    os.makedirs(os.path.join(sal, "img"), exist_ok=True)

    qids = sorted({x["qid"] for x in lista if x.get("qid")})
    ents = {}
    for i in range(0, len(qids), 40):
        lote = qids[i:i + 40]
        d = get(WD, {"action": "wbgetentities", "format": "json", "ids": "|".join(lote), "props": "claims|labels", "languages": "en"})
        ents.update((d or {}).get("entities", {}))
        print("wikidata %d/%d" % (min(i + 40, len(qids)), len(qids)), flush=True)
        time.sleep(0.5)

    plan = {}
    for x in lista:
        if x["id"] in manual:
            m = manual[x["id"]]
            plan[x["id"]] = [(m.get("tipo", "bandera"), m["archivo"])]
        elif x.get("qid") in ents:
            plan[x["id"]] = candidatos(ents[x["qid"]], x["anio"])
        else:
            plan[x["id"]] = []
    titulos = sorted({f for c in plan.values() for _, f in c})
    print("%d archivos candidatos" % len(titulos), flush=True)
    info = info_archivos(titulos)

    res = []
    cache = {}
    for x in lista:
        r = {k: x.get(k) for k in ("id", "epoca", "nombre_en", "nombre_es", "qid", "anio")}
        r.update({"estado": "sin_imagen", "tipo": "", "archivo": "", "licencia": "", "pagina": "", "autor": "", "rechazadas": []})
        for tipo, f in plan[x["id"]]:
            i = info.get(f)
            if not i or not i["mime"].startswith("image/"):
                continue
            if not i["libre"]:
                r["rechazadas"].append({"tipo": tipo, "archivo": f, "licencia": i["licencia"], "pagina": i["pagina"]})
                continue
            destino = os.path.join(sal, "img", x["id"] + ".png")
            if f in cache:
                ok = True
                with open(cache[f], "rb") as a, open(destino, "wb") as b:
                    b.write(a.read())
            else:
                ok = bajar(i, destino)
                time.sleep(0.6)
                if ok:
                    cache[f] = destino
            if ok:
                r.update({"estado": "ok", "tipo": tipo, "archivo": f, "licencia": i["licencia"], "pagina": i["pagina"], "autor": i["autor"], "ancho": i["w"], "alto": i["h"]})
                break
        if r["estado"] != "ok" and r["rechazadas"]:
            r["estado"] = "solo_con_licencia"
        res.append(r)
    json.dump(res, open(os.path.join(sal, "resultado.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    cont = {}
    for r in res:
        cont[r["estado"]] = cont.get(r["estado"], 0) + 1
    tip = {}
    for r in res:
        if r["estado"] == "ok":
            tip[r["tipo"]] = tip.get(r["tipo"], 0) + 1
    print("RESULTADO", cont, tip)


if __name__ == "__main__":
    main()
