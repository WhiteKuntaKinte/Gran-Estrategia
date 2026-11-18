#!/usr/bin/env python3
"""
Pinturas de ÉPOCA (0.1.8.52): busca en Wikimedia Commons obras de dominio público anteriores o iguales a la fecha del escenario
(año 1 d. C., 1096 y 1500) y arma HOJAS DE CONTACTO para elegir a ojo. Corre en GitHub Actions (Commons no se alcanza desde el entorno de Claude).

  python3 commons_pinturas_epoca.py buscar LISTA.json SALIDA_DIR
      LISTA = {"entradas":[{"id":"1500/region_asia_este","q":["consulta 1","consulta 2"]}]}
      SALIDA_DIR/candidatos.json (por id: título de Commons, licencia, fecha original, categorías, descripción corta, URL, tamaño)
      SALIDA_DIR/hojas/hoja_NN.jpg (una fila por id, miniaturas numeradas; 3 ids por hoja)
  python3 commons_pinturas_epoca.py bajar ELEGIDAS.json SALIDA_DIR
      ELEGIDAS = {"1500/region_asia_este": {"archivo":"File:X.jpg","anio":1072,"titulo":"Título en español","artista":"Opcional"}}
      baja cada obra a 1280 px (JPEG 82) en SALIDA_DIR/<id>.jpg y escribe SALIDA_DIR/creditos.json con el año («anio») que el juego usa
      para rechazar anacronismos.
Solo dominio público / CC0. Biblioteca estándar + pillow.
"""
import io, json, os, re, sys, time, urllib.parse, urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "GranEstrategiaJuego/0.1 (https://github.com/WhiteKuntaKinte/gran-estrategia; juego de estrategia, pinturas de epoca de dominio publico)"
META = "LicenseShortName|Artist|ObjectName|DateTimeOriginal|ImageDescription|Categories"
MIN_LARGO = 900


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


def bajar_bytes(url, intentos=5):
    for i in range(intentos):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except Exception as e:
            print("  reintento descarga", i + 1, str(e)[:80], flush=True)
            time.sleep(5 * (i + 1))
    return None


def limpio(s, n=400):
    s = re.sub(r"<[^>]+>", "", str(s or ""))
    return re.sub(r"\s+", " ", s).strip()[:n]


def es_libre(lic):
    t = limpio(lic).lower()
    return ("public domain" in t) or t.startswith("pd") or t.startswith("cc0") or "no restrictions" in t


def info_de(p):
    ii = (p.get("imageinfo") or [{}])[0]
    md = ii.get("extmetadata", {})
    g = lambda k, n=400: limpio((md.get(k) or {}).get("value", ""), n)
    return {"titulo": p.get("title", ""), "w": ii.get("width", 0), "h": ii.get("height", 0), "mime": ii.get("mime", ""),
            "licencia": g("LicenseShortName", 80), "artista": g("Artist", 90), "obra": g("ObjectName", 120), "fecha": g("DateTimeOriginal", 60),
            "desc": g("ImageDescription", 220), "cats": g("Categories", 300), "url": ii.get("descriptionurl", ""), "mini": ii.get("thumburl", "")}


def buscar_una(q):
    d = llamar({"action": "query", "format": "json", "generator": "search", "gsrnamespace": 6, "gsrlimit": 18,
                "gsrsearch": q + " filetype:bitmap", "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiurlwidth": 300,
                "iiextmetadatafilter": META})
    pags = list((d.get("query", {}).get("pages", {})).values())
    pags.sort(key=lambda p: p.get("index", 99))
    r = []
    for p in pags:
        i = info_de(p)
        if i["mime"] not in ("image/jpeg", "image/png", "image/tiff") or not es_libre(i["licencia"]):
            continue
        if max(i["w"], i["h"]) < MIN_LARGO:
            continue
        r.append(i)
    return r


def hoja(filas, destino, titulo):
    from PIL import Image, ImageDraw, ImageFont
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
        fb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 15)
    except Exception:
        f = fb = ImageFont.load_default()
    CW, CH, N = 250, 190, 8
    W = CW * N + 10
    H = (CH + 56) * len(filas) + 10
    im = Image.new("RGB", (W, H), (24, 24, 28))
    dr = ImageDraw.Draw(im)
    y = 5
    for idk, cands in filas:
        dr.text((8, y), idk, fill=(255, 210, 90), font=fb)
        y += 22
        for n, c in enumerate(cands[:N]):
            x = 5 + n * CW
            if c.get("_img") is not None:
                t = c["_img"].copy()
                t.thumbnail((CW - 6, CH - 4))
                im.paste(t, (x + (CW - 6 - t.width) // 2, y))
            dr.rectangle([x, y, x + 24, y + 18], fill=(0, 0, 0))
            dr.text((x + 5, y + 2), str(n), fill=(255, 255, 255), font=fb)
            rotulo = (c["obra"] or c["titulo"].replace("File:", ""))[:36]
            dr.text((x, y + CH - 2), rotulo, fill=(220, 220, 220), font=f)
            dr.text((x, y + CH + 14), (c["fecha"] or "?")[:30], fill=(150, 200, 255), font=f)
            dr.text((x, y + CH + 29), "%dx%d" % (c["w"], c["h"]), fill=(160, 160, 160), font=f)
        y += CH + 34
    im.save(destino, "JPEG", quality=80)


def modo_buscar(lista, salida):
    from PIL import Image
    ent = json.load(open(lista, encoding="utf-8"))["entradas"]
    os.makedirs(os.path.join(salida, "hojas"), exist_ok=True)
    res, filas = {}, []
    for n, e in enumerate(ent):
        vistos, cand = set(), []
        for q in e["q"]:
            for i in buscar_una(q):
                if i["titulo"] not in vistos:
                    vistos.add(i["titulo"])
                    i["consulta"] = q
                    cand.append(i)
            time.sleep(0.5)
        cand = cand[:e.get("max", 8)]
        for c in cand:
            c["_img"] = None
            if c["mini"]:
                b = bajar_bytes(c["mini"])
                if b:
                    try:
                        c["_img"] = Image.open(io.BytesIO(b)).convert("RGB")
                    except Exception:
                        c["_img"] = None
                time.sleep(0.35)
        res[e["id"]] = [{k: v for k, v in c.items() if k not in ("_img", "mini")} for c in cand]
        filas.append((e["id"], cand))
        print("[%d/%d] %s: %d candidatos" % (n + 1, len(ent), e["id"], len(cand)), flush=True)
        if len(filas) == 3 or n == len(ent) - 1:
            hoja(filas, os.path.join(salida, "hojas", "hoja_%02d.jpg" % (n // 3)), "")
            filas = []
    json.dump(res, open(os.path.join(salida, "candidatos.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def modo_bajar(elegidas, carpeta):
    from PIL import Image
    el = json.load(open(elegidas, encoding="utf-8"))
    cred = {}
    for k, v in el.items():
        archivo = v["archivo"] if isinstance(v, dict) else v
        d = llamar({"action": "query", "format": "json", "titles": archivo, "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata",
                    "iiurlwidth": 1280, "iiextmetadatafilter": META})
        pags = list(d.get("query", {}).get("pages", {}).values())
        if not pags or "imageinfo" not in pags[0]:
            print("FALTA", k, archivo, flush=True)
            continue
        ii = pags[0]["imageinfo"][0]
        i = info_de(pags[0])
        if not es_libre(i["licencia"]):
            print("NO LIBRE", k, archivo, i["licencia"], flush=True)
            continue
        b = bajar_bytes(ii.get("thumburl") or ii.get("url"))
        if not b:
            print("FALLA DESCARGA", k, flush=True)
            continue
        dest = os.path.join(carpeta, k + ".jpg")
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        im = Image.open(io.BytesIO(b)).convert("RGB")
        if im.width > 1280:
            im = im.resize((1280, round(im.height * 1280 / im.width)), Image.LANCZOS)
        im.save(dest, "JPEG", quality=82, optimize=True, progressive=True)
        c = {"titulo": (v.get("titulo") if isinstance(v, dict) else None) or i["obra"] or i["titulo"], "archivo_commons": i["titulo"],
             "artista": (v.get("artista") if isinstance(v, dict) else None) or i["artista"], "fecha": i["fecha"], "licencia": i["licencia"], "url": i["url"],
             "ancho": im.width, "alto": im.height}
        if isinstance(v, dict) and "anio" in v:
            c["anio"] = int(v["anio"])
        cred[k] = c
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
