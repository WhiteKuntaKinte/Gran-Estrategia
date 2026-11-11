#!/usr/bin/env python3
"""
Deja las pinturas bajadas por el flujo «Traer pinturas» listas para el juego (0.1.8.41).

  python3 preparar_pinturas.py CARPETA_BAJADA... DESTINO_PINTURAS

CARPETA_BAJADA = lo que trae el Release «datos-pinturas» ya descomprimido (contiene <carpeta>/<clave>.jpg y creditos.json). Se pueden pasar varias:
las últimas ganan (así se mezcla una pasada de correcciones sobre la completa).
Para cada imagen: recorta bordes blancos, la reduce a 960 px de ancho (máx. 1100 de alto) y la guarda como JPEG calidad 80.
Escribe DESTINO/creditos.json con título, autor, año, licencia y enlace LIMPIOS (los textos de Commons traen restos de Wikidata) y DESTINO/CREDITOS.txt legible.
Solo biblioteca estándar + pillow.
"""
import json, os, re, sys
from PIL import Image, ImageChops

ANCHO, ALTO_MAX, CALIDAD = 960, 1100, 80
FOTOGRAFOS = {"Gary Todd", "Daderot", "Prof Ranga Sai", "Rudolph.A.furtado", "Immanuel Giel", "Luisalvaz", "Nasjonalbiblioteket", "Judgefloro",
              "Didier Descouens", "Paradise Chronicle", "Tangopaso", "Joe Mabel", "Metropolitan Museum of Art", "Rijksmuseum", "Gleb Simonov", "Orfeus",
              "Uriel1022", "Gobierno CDMX", "Toto López Mesa", "Mardetanha", "Chris Woodrich", "Debotrroy Dutta"}
# Correcciones a mano: "<carpeta>/<clave>" -> {"titulo", "artista", "fecha"}. Solo donde el texto de Commons describe la foto y no la obra.
CORRECCIONES = {
    "2026/china": {"titulo": "A lo largo del río durante el Festival Qingming", "artista": "Zhang Zeduan (copia fotografiada por Immanuel Giel)", "fecha": ""},
    "general/continente_asia": {"titulo": "A lo largo del río durante el Festival Qingming", "artista": "Zhang Zeduan (copia fotografiada por Immanuel Giel)", "fecha": ""},
    "1dc/dacios": {"titulo": "Columna de Trajano: guerras dacias", "artista": "Relieve romano (foto: Gary Todd)", "fecha": ""},
    "1dc/confederacion_xiongnu": {"titulo": "Corona de oro xiongnu", "artista": "Orfebrería xiongnu (foto: Gary Todd)", "fecha": ""},
    "1dc/dinastia_han": {"titulo": "Mural de una tumba Han", "artista": "Anónimo", "fecha": ""},
    "1dc/goguryeo": {"titulo": "Pintura de la Gran Tumba de Gangseo (réplica)", "artista": "Anónimo, Goguryeo (foto: Gary Todd)", "fecha": ""},
    "1dc/reino_de_aksum": {"titulo": "Icono de la Virgen con el Niño", "artista": "Anónimo, Etiopía (foto: Daderot)", "fecha": ""},
    "1dc/reino_de_anuradhapura": {"titulo": "Frescos de Sigiriya", "artista": "Anónimo, Sri Lanka (foto: Rudolph A. Furtado)", "fecha": ""},
    "1dc/pueblos_khoisan_san_y_joikoi": {"titulo": "Arte rupestre de Spitzkoppe", "artista": "Pueblo san (foto)", "fecha": ""},
    "1dc/sami_y_pueblos_de_la_fenoscandia_septentrional": {"titulo": "Sami de la costa en el Ulfsfjord", "artista": "Fotografía histórica (Biblioteca Nacional de Noruega)", "fecha": ""},
    "1dc/sarmatas_roxolanos_y_aorsos": {"titulo": "Guerreros sármatas (reconstrucción)", "artista": "Costumes of All Nations", "fecha": "1882"},
    "1dc/reino_indoescita": {"titulo": "Pintura mural kushán de Shiva y Oesho", "artista": "Anónimo, siglo III", "fecha": ""},
    "1dc/dinastia_satavahana": {"titulo": "Bodhisattva Padmapani, cueva 1 de Ajanta", "artista": "Anónimo", "fecha": ""},
    "2026/tailandia": {"titulo": "Mural del Ramakien", "artista": "Anónimo, Tailandia (foto: Prof Ranga Sai)", "fecha": ""},
    "general/region_mesoamerica_caribe": {"titulo": "Valle de México desde el cerro del Tepeyac", "artista": "José María Velasco", "fecha": "1883"},
    "2026/ghana": {"titulo": "La fiesta del ñame de los ashanti", "artista": "Thomas E. Bowdich", "fecha": "1817"},
}


def limpia_titulo(t, clave):
    t = re.split(r"(label QS|title QS|date QS|QS:[A-Za-z]|\bQS:)", t)[0]
    t = re.sub(r"^(Dutch|French|German|Russian|Spanish|Portuguese|Japanese|Korean|Polish|Italian|Czech|Swedish|Chinese|English|Hungarian)\s*:\s*", "", t)
    t = re.sub(r"\s*\(\d{8,}\)\s*$", "", t)
    t = re.sub(r"\s+", " ", t).strip(" -–,:")
    if len(t) > 92:
        t = t[:90].rstrip(" ,;:-") + "…"
    return t or clave.split("/")[-1].replace("_", " ").capitalize()


def limpia_artista(a):
    a = a.strip()
    if re.search(r"unknown author|unknown artist|unknown muralist|^anonymous|^anonymousunknown", a, re.I):
        return "Anónimo"
    a = re.sub(r"https?://\S+", "", a).strip(" ,")
    a = re.sub(r"\s*\(.*$", "", a).strip() if len(a) > 40 else a
    return a


def anio(f):
    m = re.search(r"\b(1[0-9]{3}|20[0-9]{2})\b", f or "")
    if not m or int(m.group(1)) >= 1950:
        return ""
    return m.group(1)


def recorta_blancos(im):
    bg = Image.new("RGB", im.size, (255, 255, 255))
    caja = ImageChops.difference(im, bg).point(lambda p: 255 if p > 24 else 0).convert("L").getbbox()
    if not caja:
        return im
    w, h = im.size
    nuevo = (caja[2] - caja[0]) * (caja[3] - caja[1])
    if nuevo >= 0.55 * w * h and (caja[0] > 0.01 * w or caja[1] > 0.01 * h or caja[2] < 0.99 * w or caja[3] < 0.99 * h):
        return im.crop(caja)
    return im


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    origenes, destino = sys.argv[1:-1], sys.argv[-1]
    cred, archivos = {}, {}
    for o in origenes:
        c = json.load(open(os.path.join(o, "creditos.json"), encoding="utf-8"))
        for k, v in c.items():
            cred[k] = v
            archivos[k] = os.path.join(o, k + ".jpg")
    quitar = os.environ.get("QUITAR", "").split(",")
    salida = {}
    for k in sorted(cred):
        if k in quitar or not os.path.exists(archivos[k]):
            continue
        im = Image.open(archivos[k]).convert("RGB")
        im = recorta_blancos(im)
        im.thumbnail((ANCHO, ALTO_MAX), Image.LANCZOS)
        d = os.path.join(destino, k + ".jpg")
        os.makedirs(os.path.dirname(d), exist_ok=True)
        im.save(d, "JPEG", quality=CALIDAD, optimize=True, progressive=True)
        v = cred[k]
        art = limpia_artista(v.get("artista", ""))
        e = {"titulo": limpia_titulo(v.get("titulo", ""), k), "artista": art, "fecha": "" if art in FOTOGRAFOS else anio(v.get("fecha", "")),
             "licencia": v.get("licencia", ""), "url": v.get("url", ""), "archivo_commons": v.get("archivo_commons", ""), "ancho": im.width, "alto": im.height}
        e.update(CORRECCIONES.get(k, {}))
        salida[k] = e
    json.dump(salida, open(os.path.join(destino, "creditos.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    with open(os.path.join(destino, "CREDITOS.txt"), "w", encoding="utf-8") as f:
        f.write("PINTURAS DEL JUEGO · todas de dominio público o CC0, tomadas de Wikimedia Commons (reducidas de tamaño).\n"
                "Cada línea: archivo · «título» · autor (año) · licencia · página de la obra en Commons.\n\n")
        for k, e in salida.items():
            f.write("%s.jpg · «%s» · %s%s · %s · %s\n" % (k, e["titulo"], e["artista"], " (%s)" % e["fecha"] if e["fecha"] else "", e["licencia"], e["url"]))
    tam = sum(os.path.getsize(os.path.join(destino, k + ".jpg")) for k in salida)
    print("%d pinturas, %.1f MB" % (len(salida), tam / 1e6))


if __name__ == "__main__":
    main()
