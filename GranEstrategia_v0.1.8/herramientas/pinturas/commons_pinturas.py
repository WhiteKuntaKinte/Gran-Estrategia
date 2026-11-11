#!/usr/bin/env python3
"""
Busca y baja pinturas de DOMINIO PÚBLICO de Wikimedia Commons para el juego (0.1.8.41). Se ejecuta en GitHub Actions
(.github/workflows/traer-pinturas.yml): desde el entorno de trabajo de Claude Commons está bloqueado, pero los servidores de GitHub sí lo alcanzan.

Dos modos:
  buscar  LISTA SALIDA.json            Para cada entrada de lista_busqueda.json prueba sus consultas y guarda los candidatos
                                       (solo dominio público / CC0, imágenes grandes) con título, tamaño, licencia y autor.
  bajar   ELEGIDAS.json SALIDA_DIR     ELEGIDAS = {"<epoca>/<clave>": "File:Titulo.jpg"}. Baja cada archivo a 1280 px de ancho (JPEG calidad 82),
                                       lo guarda en SALIDA_DIR/<epoca>/<clave>.jpg y escribe SALIDA_DIR/creditos.json (autor, título, licencia, URL).
Solo biblioteca estándar + pillow.
"""
import json, os, re, sys, time, urllib.parse, urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "GranEstrategiaJuego/0.1 (https://github.com/WhiteKuntaKinte/gran-estrategia; juego de estrategia, uso de obras de dominio publico)"
META = "LicenseShortName|Artist|ObjectName|DateTimeOriginal|Credit|UsageTerms|Restrictions"


def llamar(params, intentos=5):
    url = API + "?" + urllib.parse.urlencode(params)
    for i in range(intentos):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except Exception as e:
            print("  reintento", i + 1, type(e).__name__, str(e)[:80], flush=True)
            time.sleep(4 * (i + 1))
    return {}


def limpio(s):
    s = re.sub(r"<[^>]+>", "", str(s or ""))
    return re.sub(r"\s+", " ", s).strip()


def es_libre(lic):
    t = limpio(lic).lower()
    return ("public domain" in t) or t.startswith("pd") or t.startswith("cc0") or "no restrictions" in t


def info_de(pagina):
    ii = (pagina.get("imageinfo") or [{}])[0]
    md = ii.get("extmetadata", {})
    g = lambda k: limpio((md.get(k) or {}).get("value", ""))
    return {"titulo": pagina.get("title", ""), "w": ii.get("width", 0), "h": ii.get("height", 0), "mime": ii.get("mime", ""),
            "licencia": g("LicenseShortName"), "artista": g("Artist")[:90], "obra": g("ObjectName")[:90], "fecha": g("DateTimeOriginal")[:40],
            "url": ii.get("descriptionurl", ""), "bytes": ii.get("size", 0)}


def buscar_una(q):
    d = llamar({"action": "query", "format": "json", "generator": "search", "gsrnamespace": 6, "gsrlimit": 12,
                "gsrsearch": q + " filetype:bitmap", "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiextmetadatafilter": META})
    pags = list((d.get("query", {}).get("pages", {})).values())
    pags.sort(key=lambda p: p.get("index", 99))
    r = []
    for p in pags:
        i = info_de(p)
        if i["mime"] not in ("image/jpeg", "image/png", "image/tiff") or not es_libre(i["licencia"]):
            continue
        if min(i["w"], i["h"]) < 600 or max(i["w"], i["h"]) < 1000:
            continue
        r.append(i)
    return r


def modo_buscar(lista, salida):
    ent = json.load(open(lista, encoding="utf-8"))["entradas"]
    res = {}
    for n, e in enumerate(ent):
        k = e["epoca"] + "/" + e["clave"]
        vistos, cand = set(), []
        for q in e["q"]:
            for i in buscar_una(q):
                if i["titulo"] not in vistos:
                    vistos.add(i["titulo"])
                    i["consulta"] = q
                    cand.append(i)
            time.sleep(0.6)
        res[k] = cand
        print("[%d/%d] %s: %d candidatos" % (n + 1, len(ent), k, len(cand)), flush=True)
    json.dump(res, open(salida, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def modo_bajar(elegidas, carpeta):
    from PIL import Image
    el = json.load(open(elegidas, encoding="utf-8"))
    cred = {}
    for k, titulo in el.items():
        d = llamar({"action": "query", "format": "json", "titles": titulo, "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata",
                    "iiurlwidth": 1280, "iiextmetadatafilter": META})
        pags = list(d.get("query", {}).get("pages", {}).values())
        if not pags or "imageinfo" not in pags[0]:
            print("FALTA", k, titulo, flush=True)
            continue
        ii = pags[0]["imageinfo"][0]
        i = info_de(pags[0])
        if not es_libre(i["licencia"]):
            print("NO LIBRE", k, titulo, i["licencia"], flush=True)
            continue
        url = ii.get("thumburl") or ii.get("url")
        dest = os.path.join(carpeta, k + ".jpg")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        tmp = dest + ".tmp"
        ok = False
        for intento in range(5):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=120) as r, open(tmp, "wb") as f:
                    f.write(r.read())
                ok = True
                break
            except Exception as e:
                print("  reintento", intento + 1, str(e)[:80], flush=True)
                time.sleep(5 * (intento + 1))
        if not ok:
            print("FALLA DESCARGA", k, flush=True)
            continue
        im = Image.open(tmp).convert("RGB")
        if im.width > 1280:
            im = im.resize((1280, round(im.height * 1280 / im.width)), Image.LANCZOS)
        im.save(dest, "JPEG", quality=82, optimize=True, progressive=True)
        os.remove(tmp)
        cred[k] = {"titulo": i["obra"] or i["titulo"], "archivo_commons": i["titulo"], "artista": i["artista"], "fecha": i["fecha"],
                   "licencia": i["licencia"], "url": i["url"], "ancho": im.width, "alto": im.height}
        print("OK", k, "%dx%d" % (im.width, im.height), i["licencia"], flush=True)
        time.sleep(0.8)
    json.dump(cred, open(os.path.join(carpeta, "creditos.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "buscar":
        modo_buscar(sys.argv[2], sys.argv[3])
    elif len(sys.argv) >= 4 and sys.argv[1] == "bajar":
        modo_bajar(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
