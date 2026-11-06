extends RefCounted
## Mandos con nombre (0.1.7.9.9D): cadena de mando de un pelotón con nombres que respetan la cultura del país.
##
## Los nombres NO se guardan: se calculan al abrir el pelotón con un generador al azar cuya semilla sale de datos estables
## (pelotón, provincia, país y época). Así el mismo pelotón muestra los mismos jefes cada vez que lo abres, y los jefes
## «rotan» solos con los años (cada 3 años los de pelotón y región, cada 4 los del alto mando).
## Datos: datos/nombres_cultura.json (lo genera herramientas/hacer_nombres_cultura.py; se puede editar a mano).

var culturas := {}                 # id -> {nombre, orden, nombres[], apellidos[]}
var paises := {}                   # país -> id de cultura
var defecto_continente := {}       # continente -> id de cultura
var eras: Array = []               # [{nombre, hasta, supremo, alto_mando, region, peloton, segundo, oficial}]
var listo := false


func leer(js) -> void:
	if not (js is Dictionary):
		return
	culturas = js.get("culturas", {})
	paises = js.get("paises", {})
	defecto_continente = js.get("defecto_continente", {})
	eras = js.get("eras", [])
	listo = not culturas.is_empty() and not eras.is_empty()


func cultura_de(pais: String, continente := "") -> String:
	var c := String(paises.get(pais, ""))
	if c == "" or not culturas.has(c):
		c = String(defecto_continente.get(continente, ""))
	if c == "" or not culturas.has(c):
		c = String(culturas.keys()[0]) if not culturas.is_empty() else ""
	return c


func etiqueta_cultura(id: String) -> String:
	return String(culturas.get(id, {}).get("nombre", id))


## Era (títulos de mando) que corresponde a un año.
func era_de(anio: int) -> Dictionary:
	for e in eras:
		if anio < int(e["hasta"]):
			return e
	return eras[eras.size() - 1] if not eras.is_empty() else {}


## Semilla estable a partir de enteros (mezcla simple tipo hash; no depende de la plataforma).
static func semilla(a: int, b := 0, c := 0, d := 0) -> int:
	var h: int = 1469598103
	for v in [a, b, c, d]:
		h = (h ^ int(v)) * 16777619
		h = h & 0x7FFFFFFFFFFF
	return h


## Un nombre completo de la cultura, según su orden de escritura.
func nombre_completo(cultura: String, rng: RandomNumberGenerator) -> String:
	var c: Dictionary = culturas.get(cultura, {})
	if c.is_empty():
		return "—"
	var ns: Array = c["nombres"]
	var ap: Array = c["apellidos"]
	var n := String(ns[rng.randi() % ns.size()])
	var a1 := String(ap[rng.randi() % ap.size()])
	match String(c.get("orden", "nombre_apellido")):
		"hispano":
			var a2 := String(ap[rng.randi() % ap.size()])
			var tope := 0
			while a2 == a1 and tope < 6:
				a2 = String(ap[rng.randi() % ap.size()])
				tope += 1
			return "%s %s %s" % [n, a1, a2]
		"apellido_nombre":
			return "%s %s" % [a1, n]
		_:
			return "%s %s" % [n, a1]


## Nombre distinto de los ya usados en la misma cadena de mando.
func _nombre_unico(cultura: String, rng: RandomNumberGenerator, usados: Array) -> String:
	var s := nombre_completo(cultura, rng)
	var tope := 0
	while usados.has(s) and tope < 8:
		s = nombre_completo(cultura, rng)
		tope += 1
	usados.append(s)
	return s


## Cadena de mando de un pelotón: de arriba abajo. Cada fila: {"cargo", "nombre", "real"}.
## `jefe_estado`: nombre REAL del jefe de Estado si se conoce (de Historia); si no, solo se muestra el título.
## `semillas` = {"pelotón", "provincia", "país"} (IDs estables). `zona` = nombre del lugar para el comandante regional.
func cadena(pais: String, continente: String, semillas: Dictionary, anio: int, jefe_estado := "", zona := "", n_oficiales := 4) -> Array:
	var era := era_de(anio)
	var cultura := cultura_de(pais, continente)
	var filas := []
	var usados := []
	filas.append({"cargo": String(era.get("supremo", "Comandante supremo")),
		"nombre": jefe_estado if jefe_estado != "" else "sin nombre registrado", "real": jefe_estado != ""})
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla(int(semillas.get("país", 0)), floori(anio / 4.0), 11)
	filas.append({"cargo": String(era.get("alto_mando", "General")), "nombre": _nombre_unico(cultura, rng, usados), "real": false})
	rng.seed = semilla(int(semillas.get("provincia", 0)), floori(anio / 3.0), 23)
	var reg := String(era.get("region", "Comandante regional"))
	filas.append({"cargo": reg + ((" de " + zona) if zona != "" else ""), "nombre": _nombre_unico(cultura, rng, usados), "real": false})
	rng.seed = semilla(int(semillas.get("pelotón", 0)), floori(anio / 3.0), 37)
	filas.append({"cargo": String(era.get("peloton", "Coronel")) + " (jefe del pelotón)", "nombre": _nombre_unico(cultura, rng, usados), "real": false})
	filas.append({"cargo": String(era.get("segundo", "Teniente coronel")), "nombre": _nombre_unico(cultura, rng, usados), "real": false})
	var ofi := String(era.get("oficial", "Capitán"))
	for i in n_oficiales:
		filas.append({"cargo": "%s · %d.ª compañía" % [ofi, i + 1], "nombre": _nombre_unico(cultura, rng, usados), "real": false})
	return filas
