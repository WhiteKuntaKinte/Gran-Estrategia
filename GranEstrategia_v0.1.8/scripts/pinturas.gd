extends RefCounted
## PINTURAS (0.1.8.41): cada país (y cada pueblo del año 1) tiene una pintura clásica de dominio público que se ve arriba de su panel.
##
## DÓNDE ESTÁN: `pinturas/<carpeta>/<clave>.jpg`, con `pinturas/creditos.json` como índice y registro de autor, título, licencia y URL de cada obra.
##   · `<carpeta>` = la época del escenario: «2026» o «1dc» (año 1 d. C.); más «general» para las que valen en cualquier época.
##   · `<clave>` = el nombre del país sin tildes, en minúsculas y con «_» (España → espana, Reino Unido → reino_unido).
## CÓMO SE ELIGE (de lo más cercano a lo más lejano; la primera que exista gana):
##   1. la del propio país en la época activa          pinturas/2026/francia.jpg
##   2. la de su región del mundo                      pinturas/general/region_europa_occidental.jpg
##   3. la de su continente                            pinturas/general/continente_europa.jpg
##   4. la del mundo                                   pinturas/general/mundo.jpg
## Para PONER O CAMBIAR una pintura basta con copiar el .jpg con el nombre correcto y añadir su línea a creditos.json (herramientas/pinturas/ explica cómo se bajan).
## La región sale del centro del bloque principal del país (`foco`) y su continente; así sirve igual para países modernos y pueblos antiguos.

const RAIZ := "res://pinturas/"
const CARPETA_EPOCA := {2026: "2026", 1: "1dc"}
const MAX_CACHE := 14                              # texturas en memoria a la vez (una de 1280 px pesa ~4 MB)
const ANCHO_MAPA := 2400.0
const ALTO_MAPA := 1200.0

var main
var creditos := {}                                 # "<carpeta>/<clave>" -> {titulo, artista, fecha, licencia, url, ...}
var listo := false
var _tex := {}                                     # ruta -> Texture2D
var _orden: Array = []                             # rutas por antigüedad de uso (para soltar las más viejas)


## Lee `pinturas/creditos.json`. Sin ese archivo el sistema no hace nada (no hay pinturas y el panel no muestra la tarjeta).
func iniciar(m) -> void:
	main = m
	creditos = {}
	var f := FileAccess.open(RAIZ + "creditos.json", FileAccess.READ)
	if f != null:
		var js = JSON.parse_string(f.get_as_text())
		if js is Dictionary:
			creditos = js
	listo = not creditos.is_empty()


# ───────────────────────── nombres ─────────────────────────
## «España» -> «espana»; «Pueblos de Java, Bali y las Pequeñas Sondas» -> «pueblos_de_java_bali_y_las_pequenas_sondas».
static func clave(nombre: String) -> String:
	var s := nombre.to_lower()
	for par in [["á", "a"], ["à", "a"], ["â", "a"], ["ä", "a"], ["ã", "a"], ["å", "a"], ["ā", "a"], ["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["ē", "e"],
			["í", "i"], ["ì", "i"], ["î", "i"], ["ï", "i"], ["ī", "i"], ["ó", "o"], ["ò", "o"], ["ô", "o"], ["ö", "o"], ["õ", "o"], ["ø", "o"], ["ō", "o"],
			["ú", "u"], ["ù", "u"], ["û", "u"], ["ü", "u"], ["ū", "u"], ["ñ", "n"], ["ç", "c"], ["ş", "s"], ["š", "s"], ["ž", "z"], ["č", "c"], ["ć", "c"],
			["ł", "l"], ["ğ", "g"], ["ý", "y"], ["ß", "ss"]]:
		s = s.replace(par[0], par[1])
	var r := ""
	var sep := false
	for i in s.length():
		var c := s.substr(i, 1)
		var es_alnum := (c >= "a" and c <= "z") or (c >= "0" and c <= "9")
		if es_alnum:
			if sep and r != "":
				r += "_"
			r += c
			sep = false
		else:
			sep = true
	return r


func carpeta_epoca() -> String:
	var e := int(main.epoca) if main != null else 2026
	return String(CARPETA_EPOCA.get(e, "2026"))


## Región del mundo de un país: «region_europa_occidental», «region_asia_este»… ("" si no tiene: Antártida o sin datos).
## Sale del centro del bloque principal del país (lon/lat) y de su continente.
func region_de(pais: String) -> String:
	if main == null or main.mundo == null or not main.mundo.paises.has(pais):
		return ""
	var p = main.mundo.paises[pais]
	var foco: Array = p.foco
	if foco.size() < 4:
		return ""
	var lon: float = (float(foco[0]) + float(foco[2]) * 0.5) / ANCHO_MAPA * 360.0 - 180.0
	var lat: float = 90.0 - (float(foco[1]) + float(foco[3]) * 0.5) / ALTO_MAPA * 180.0
	return region_en(String(p.continente), lon, lat)


## La regla de las regiones (separada para poder probarla con coordenadas).
static func region_en(continente: String, lon: float, lat: float) -> String:
	match continente:
		"Europa":
			if lon >= 19.0 and lat >= 44.5:
				if lat >= 55.5 and lon <= 33.0:
					return "region_europa_norte"                              # Finlandia, Estonia, Letonia
				return "region_europa_este"
			if lat >= 55.5:
				return "region_europa_norte"                                  # Escandinavia, Dinamarca, Islandia
			if lat < 44.0 and lon < 30.0:
				return "region_mediterraneo"                                  # Iberia, Italia, Balcanes, Grecia
			return "region_europa_occidental"
		"Asia":
			if lon >= 92.0:
				return "region_sudeste_asiatico" if lat < 22.5 else "region_asia_este"
			if lon >= 60.0 and lat < 36.0:
				return "region_asia_sur"
			if lon >= 52.0 and lat >= 36.0:
				return "region_asia_central"
			if lon < 62.0:
				return "region_oriente_medio"
			return "region_asia_este"
		"África":
			return "region_africa_norte" if lat >= 15.5 else "region_africa_subsahariana"
		"América del Norte":
			return "region_mesoamerica_caribe" if lat < 25.5 else "region_norteamerica"
		"América del Sur":
			return "region_sudamerica_andes" if lon <= -64.5 else "region_sudamerica_este"
		"Oceanía":
			return "region_oceania"
	return ""


# ───────────────────────── búsqueda ─────────────────────────
## La pintura de un país: {"id", "ruta", "nivel" ("pais"/"region"/"continente"/"mundo"), "titulo", "artista", "fecha", "licencia", "url", "texto"}.
## Vacío si no hay ninguna pintura instalada.
func de_pais(pais: String) -> Dictionary:
	if not listo:
		return {}
	var cont := ""
	if main != null and main.mundo != null and main.mundo.paises.has(pais):
		cont = String(main.mundo.paises[pais].continente)
	var intentos := [
		[carpeta_epoca() + "/" + clave(pais), "pais"],
		["general/" + region_de(pais), "region"],
		["general/continente_" + clave(cont), "continente"],
		["general/mundo", "mundo"],
	]
	for it in intentos:
		var id: String = it[0]
		if creditos.has(id):
			return _ficha(id, String(it[1]))
	return {}


## La pintura de un continente («Europa», «América del Sur»…): la suya o, si no hay, la del mundo.
func de_continente(cont: String) -> Dictionary:
	if not listo:
		return {}
	for it in [["general/continente_" + clave(cont), "continente"], ["general/mundo", "mundo"]]:
		if creditos.has(String(it[0])):
			return _ficha(String(it[0]), String(it[1]))
	return {}


func _ficha(id: String, nivel: String) -> Dictionary:
	var c: Dictionary = creditos[id]
	var titulo := String(c.get("titulo", ""))
	var artista := String(c.get("artista", ""))
	var fecha := String(c.get("fecha", ""))
	var texto := "«%s»" % titulo if titulo != "" else ""
	if artista != "":
		texto += (" · " if texto != "" else "") + artista
	if fecha != "" and fecha.length() <= 12:
		texto += " (%s)" % fecha
	return {"id": id, "ruta": RAIZ + id + ".jpg", "nivel": nivel, "titulo": titulo, "artista": artista, "fecha": fecha,
		"licencia": String(c.get("licencia", "")), "url": String(c.get("url", "")), "texto": texto}


## Textura de una pintura (con caché que suelta las más viejas). null si el archivo no está.
func textura(ruta: String) -> Texture2D:
	if _tex.has(ruta):
		_orden.erase(ruta)
		_orden.append(ruta)
		return _tex[ruta]
	var t: Texture2D = main._cargar_png(ruta) if main != null else null
	if t == null:
		return null
	_tex[ruta] = t
	_orden.append(ruta)
	while _orden.size() > MAX_CACHE:
		_tex.erase(_orden.pop_front())
	return t


## Cuántas pinturas hay instaladas por carpeta: {"2026": n, "1dc": n, "general": n}.
func contar() -> Dictionary:
	var r := {}
	for id in creditos:
		var c := String(id).get_slice("/", 0)
		r[c] = int(r.get(c, 0)) + 1
	return r


## Líneas para la pantalla de créditos: licencia y de dónde vienen.
func texto_creditos() -> String:
	if not listo:
		return ""
	var cont := contar()
	return "Pinturas: %d obras de dominio público (Wikimedia Commons): %d de 2026, %d del año 1 y %d generales. Cada panel muestra el título y el autor de la suya; la lista completa, con licencia y enlace, está en pinturas/creditos.json." % [
		creditos.size(), int(cont.get("2026", 0)), int(cont.get("1dc", 0)), int(cont.get("general", 0))]
