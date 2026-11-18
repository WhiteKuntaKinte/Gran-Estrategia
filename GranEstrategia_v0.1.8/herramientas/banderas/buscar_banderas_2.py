#!/usr/bin/env python3
"""
Segunda pasada de BANDERAS (0.1.8.52): para los estados que Wikidata no resolvió (resultado.json: estado «sin_imagen» o «solo_con_licencia») busca en Commons
banderas, escudos, estandartes y sellos de dominio público por el NOMBRE del estado y arma hojas de contacto para elegir a ojo.
Solo dominio público / CC0 (nada de BY ni BY-SA). Marca como «sospechosa» toda imagen cuya descripción o categorías hablen de reconstrucción, fantasía, propuesta, etc.
  python3 buscar_banderas_2.py RESULTADO.json SALIDA_DIR
SALIDA_DIR/candidatos_banderas.json  y  SALIDA_DIR/hojas/hoja_NN.jpg (6 estados por hoja, 5 miniaturas por estado)
"""
import io, json, os, re, sys, time, urllib.parse, urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "GranEstrategiaJuego/0.1 (https://github.com/WhiteKuntaKinte/gran-estrategia; juego de estrategia, banderas historicas de dominio publico)"
META = "LicenseShortName|Artist|ObjectName|ImageDescription|Categories"
SOSPECHA = re.compile(r"reconstruct|fictional|fantasy|alternate|hypothetical|speculat|propos|conjectur|imaginary|modern interpretation|unofficial|concept|redesign", re.I)


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


def bytes_de(url, intentos=4):
    for i in range(intentos):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.read()
        except Exception as e:
            time.sleep(4 * (i + 1))
    return None


def limpio(s, n=300):
    s = re.sub(r"<[^>]+>", "", str(s or ""))
    return re.sub(r"\s+", " ", s).strip()[:n]


def libre(lic):
    t = limpio(lic).lower()
    return ("public domain" in t) or t.startswith("pd") or t.startswith("cc0") or "no restrictions" in t


def buscar(q):
    d = llamar({"action": "query", "format": "json", "generator": "search", "gsrnamespace": 6, "gsrlimit": 12, "gsrsearch": q,
                "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiurlwidth": 200, "iiextmetadatafilter": META})
    pags = list((d.get("query", {}).get("pages", {})).values())
    pags.sort(key=lambda p: p.get("index", 99))
    r = []
    for p in pags:
        ii = (p.get("imageinfo") or [{}])[0]
        md = ii.get("extmetadata", {})
        g = lambda k, n=300: limpio((md.get(k) or {}).get("value", ""), n)
        if not str(ii.get("mime", "")).startswith("image/") or not libre(g("LicenseShortName", 80)):
            continue
        txt = g("ImageDescription", 400) + " " + g("Categories", 400) + " " + p.get("title", "")
        r.append({"titulo": p.get("title", ""), "licencia": g("LicenseShortName", 80), "desc": g("ImageDescription", 160), "cats": g("Categories", 200),
                  "sospechosa": bool(SOSPECHA.search(txt)), "url": ii.get("descriptionurl", ""), "mini": ii.get("thumburl", "")})
    return r


def nombres(x):
    en = re.sub(r"\s*\(.*?\)", "", x["nombre_en"]).strip()
    return en


def main():
    from PIL import Image, ImageDraw, ImageFont
    res = json.load(open(sys.argv[1], encoding="utf-8"))
    sal = sys.argv[2]
    os.makedirs(os.path.join(sal, "hojas"), exist_ok=True)
    pend = [x for x in res if x["estado"] != "ok"]
    out, filas = {}, []
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
        fb = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
    except Exception:
        f = fb = ImageFont.load_default()
    nh = 0
    for n, x in enumerate(pend):
        nom = nombres(x)
        vistos, cand = set(), []
        for q in ['intitle:"%s" flag' % nom, 'intitle:"%s" "coat of arms"' % nom, '"%s" banner OR standard OR vexillum OR seal' % nom]:
            for c in buscar(q):
                if c["titulo"] not in vistos:
                    vistos.add(c["titulo"])
                    cand.append(c)
            time.sleep(0.4)
        cand = [c for c in cand][:6]
        out[x["id"]] = {"nombre_en": x["nombre_en"], "nombre_es": x["nombre_es"], "epoca": x["epoca"], "cand": [{k: v for k, v in c.items() if k != "mini"} for c in cand]}
        print("[%d/%d] %s: %d" % (n + 1, len(pend), x["id"], len(cand)), flush=True)
        if cand:
            imgs = []
            for c in cand[:5]:
                b = bytes_de(c["mini"]) if c["mini"] else None
                try:
                    imgs.append(Image.open(io.BytesIO(b)).convert("RGBA") if b else None)
                except Exception:
                    imgs.append(None)
                time.sleep(0.3)
            filas.append((x["id"], x["nombre_en"], cand[:5], imgs))
        if len(filas) == 6 or (n == len(pend) - 1 and filas):
            W, H = 1130, 6 * 150 + 10
            im = Image.new("RGB", (W, H), (30, 30, 34))
            dr = ImageDraw.Draw(im)
            for r, (idk, nom2, cs, imgs) in enumerate(filas):
                y = 5 + r * 150
                dr.text((6, y), "%s  ·  %s" % (idk, nom2), fill=(255, 210, 90), font=fb)
                for k, c in enumerate(cs):
                    xx = 6 + k * 224
                    dr.rectangle([xx, y + 18, xx + 218, y + 106], fill=(60, 60, 66))
                    if imgs[k] is not None:
                        t = imgs[k].copy()
                        t.thumbnail((214, 84))
                        bg = Image.new("RGB", t.size, (200, 200, 200))
                        bg.paste(t, (0, 0), t)
                        im.paste(bg, (xx + 2, y + 20))
                    dr.rectangle([xx, y + 18, xx + 14, y + 32], fill=(0, 0, 0))
                    dr.text((xx + 3, y + 18), str(k), fill=(255, 255, 255), font=fb)
                    dr.text((xx, y + 108), c["titulo"].replace("File:", "")[:38], fill=(230, 230, 230), font=f)
                    dr.text((xx, y + 121), ("SOSPECHOSA " if c["sospechosa"] else "") + c["licencia"][:24], fill=(255, 120, 120) if c["sospechosa"] else (150, 200, 255), font=f)
            im.save(os.path.join(sal, "hojas", "hoja_%02d.jpg" % nh), "JPEG", quality=80)
            nh += 1
            filas = []
    json.dump(out, open(os.path.join(sal, "candidatos_banderas.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
