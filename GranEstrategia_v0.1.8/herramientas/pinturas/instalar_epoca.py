#!/usr/bin/env python3
"""
Instala en el juego las pinturas de ÉPOCA que dejó el flujo «Traer pinturas de época» (Release datos-pinturas-epoca).

  python3 instalar_epoca.py CARPETA_BAJADA [--proyecto RUTA]
      CARPETA_BAJADA trae pinturas.zip (ya abierto en CARPETA_BAJADA/zip/<época>/<clave>.jpg) y creditos.json.
      - copia los JPG a pinturas/<época>/ y mezcla los créditos en pinturas/creditos.json;
      - quita las pinturas de una época que no pasan la regla (año de la obra <= año del escenario; sin año = no vale);
      - vuelve a escribir pinturas/CREDITOS.txt desde creditos.json y borra los JPG que ya no están en la lista.
Solo biblioteca estándar.
"""
import json, os, sys

ANIO_EPOCA = {"1dc": 1, "1096": 1096, "1500": 1500}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    bajada = args[0]
    proyecto = "."
    if "--proyecto" in sys.argv:
        proyecto = sys.argv[sys.argv.index("--proyecto") + 1]
    dest = os.path.join(proyecto, "pinturas")
    cred_path = os.path.join(dest, "creditos.json")
    cred = json.load(open(cred_path, encoding="utf-8"))
    nuevo = json.load(open(os.path.join(bajada, "creditos.json"), encoding="utf-8"))
    for k, c in nuevo.items():
        carpeta, nombre = k.split("/", 1)
        os.makedirs(os.path.join(dest, carpeta), exist_ok=True)
        with open(os.path.join(bajada, "zip", carpeta, nombre + ".jpg"), "rb") as f:
            datos = f.read()
        with open(os.path.join(dest, carpeta, nombre + ".jpg"), "wb") as f:
            f.write(datos)
        cred[k] = c
    quitadas = []
    for k in list(cred):
        carpeta = k.split("/", 1)[0]
        if carpeta in ANIO_EPOCA:
            anio = cred[k].get("anio")
            if anio is None or int(anio) > ANIO_EPOCA[carpeta]:
                quitadas.append(k)
                del cred[k]
    cred = dict(sorted(cred.items()))
    with open(cred_path, "w", encoding="utf-8") as f:
        json.dump(cred, f, ensure_ascii=False, indent=1)
    lineas = ["PINTURAS DEL JUEGO · todas de dominio público o CC0, tomadas de Wikimedia Commons (reducidas de tamaño).",
              "Cada línea: archivo · «título» · autor (año) · licencia · página de la obra en Commons.", ""]
    for k, c in cred.items():
        f = c.get("fecha", "")
        lineas.append("%s.jpg · «%s» · %s%s · %s · %s" % (k, c["titulo"], c["artista"], (" (" + f + ")") if f else "", c["licencia"], c["url"]))
    with open(os.path.join(dest, "CREDITOS.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lineas) + "\n")
    borrados = []
    for carpeta in sorted(os.listdir(dest)):
        d = os.path.join(dest, carpeta)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if fn.endswith(".jpg") and (carpeta + "/" + fn[:-4]) not in cred:
                os.remove(os.path.join(d, fn))
                borrados.append(carpeta + "/" + fn)
    print("instaladas %d · quitadas por anacronismo %d · archivos huérfanos borrados %d · total %d" % (len(nuevo), len(quitadas), len(borrados), len(cred)))
    for b in borrados:
        print("  borrado", b)


if __name__ == "__main__":
    main()
