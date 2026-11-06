extends RefCounted
## Descubrimientos (0.1.8.36): el catálogo de 1.730 descubrimientos (Militar, Científica, Sociedad) enlazado con el RELOJ.
##
## ¿Qué guarda?
##  · CATÁLOGO (datos/descubrimientos.json, lo genera herramientas/construir_descubrimientos.py): cada descubrimiento con su era, tipo, sección,
##    prerrequisitos (todos los de `req` + uno de cada grupo de `req_o`) y, sobre todo, su AÑO (a. C. en negativo). Es un dato FIJO: no cambia
##    durante la partida, por eso NO vive en la base de datos de territorios (esa guarda «un valor por lugar y por fecha»).
##  · FRONTERA HISTÓRICA: lo que la humanidad ya sabe en la fecha del juego = todos los descubrimientos con año <= año del reloj. Es lo que permite
##    empezar una partida en cualquier época (año 1, 2026, lo que haga falta) y que el Debug viaje en el tiempo.
##  · ESTADO POR PAÍS: qué descubrimientos conoce cada país. Un país que nunca se tocó no gasta memoria: lee la frontera. En cuanto un país se
##    aparta de la historia (`conceder` / `quitar`: la futura investigación propia) recibe su propia copia (1 byte por descubrimiento).
##
## Reglas de tiempo:
##  · `iniciar(año)`: nueva partida. Todos los países parten de la frontera de ese año.
##  · `avanzar_a(año)`: el reloj pasó a un año nuevo. Los descubrimientos que toquen entran a la frontera y a TODOS los países con estado propio. Coste:
##    O(nuevos × países con estado propio): un año normal trae 0-30 descubrimientos y casi ningún país tiene estado propio.
##  · `sincronizar(año, reiniciar)`: salto de fecha del Debug. Hacia adelante igual que `avanzar_a`; hacia atrás los descubrimientos más nuevos que el año se
##    quitan a todos. Con `reiniciar = true` todos los países vuelven a la historia pura de ese año.
##
## Años: enteros con signo, a. C. en negativo y sin año cero (44 a. C. = -44). El reloj del juego cuenta el año 1 a. C. como 0: la diferencia (un año) no importa aquí.

const NINGUNO := -2147483648
const MAX_ULTIMOS := 60

var n := 0
var slug := PackedStringArray()
var nombre := PackedStringArray()
var era := PackedInt32Array()
var tipo := PackedStringArray()
var seccion := PackedInt32Array()
var sub := PackedInt32Array()
var tema := PackedInt32Array()                # -1 = ninguno; si no, índice en `temas`
var anio := PackedInt32Array()
var origen := PackedStringArray()             # h = histórico a mano · a = ajustado · x = hipotético
var req: Array = []                           # índice -> PackedInt32Array (hacen falta TODOS)
var req_o: Array = []                         # índice -> Array de PackedInt32Array (de cada grupo basta UNO)
var idx_de_slug := {}
var eras: Array = []                          # [{nombre, desde, hasta}]
var ramas: Array = []                         # [{cod, nombre}]
var secciones: Array = []                     # [{rama, cod, nombre, desc}]
var subsecciones: Array = []
var temas: Array = []
var tipos := {}                               # código -> nombre

var orden := PackedInt32Array()               # índices de descubrimiento ordenados por año (a igual año, por posición)
var anios_ord := PackedInt32Array()           # el año de cada posición de `orden` (para buscar por bisección)

# ── estado ──
var anio_actual := NINGUNO                    # año al que está sincronizada la frontera
var cuenta_f := 0                             # cuántos de `orden` (los primeros) están en la frontera
var frontera := PackedByteArray()             # 1 = ya existe en la frontera histórica
var estado := {}                              # tid de país -> PackedByteArray (solo países apartados de la historia)
var ultimos: Array = []                       # los más recientes que entraron a la frontera: [{"idx", "anio"}], el más nuevo al final


# ─────────────────────────────────────────────────────────────
# Carga
# ─────────────────────────────────────────────────────────────
## Lee el JSON del catálogo. Devuelve false (y no deja nada a medias) si el formato no es el esperado.
func cargar(d: Dictionary) -> bool:
	var cols: Array = d.get("columnas", [])
	if cols != ["slug", "nombre", "era", "tipo", "seccion", "sub", "tema", "anio", "origen", "req", "req_o"]:
		push_error("datos/descubrimientos.json: columnas inesperadas")
		return false
	var filas: Array = d.get("filas", [])
	var m := filas.size()
	slug.resize(m)
	nombre.resize(m)
	era.resize(m)
	tipo.resize(m)
	seccion.resize(m)
	sub.resize(m)
	tema.resize(m)
	anio.resize(m)
	origen.resize(m)
	req.resize(m)
	req_o.resize(m)
	idx_de_slug.clear()
	for i in m:
		var f: Array = filas[i]
		slug[i] = String(f[0])
		nombre[i] = String(f[1])
		era[i] = int(f[2])
		tipo[i] = String(f[3])
		seccion[i] = int(f[4])
		sub[i] = int(f[5])
		tema[i] = int(f[6])
		anio[i] = int(f[7])
		origen[i] = String(f[8])
		var a := PackedInt32Array()
		for x in f[9]:
			a.append(int(x))
		req[i] = a
		var os: Array = []
		for g in f[10]:
			var pg := PackedInt32Array()
			for x in g:
				pg.append(int(x))
			os.append(pg)
		req_o[i] = os
		idx_de_slug[slug[i]] = i
	n = m
	eras = d.get("eras", [])
	ramas = d.get("ramas", [])
	secciones = d.get("secciones", [])
	subsecciones = d.get("subsecciones", [])
	temas = d.get("temas", [])
	tipos.clear()
	for t in d.get("tipos", []):
		tipos[String(t["cod"])] = String(t["nombre"])
	# orden por año (estable): la frontera de cualquier año es un prefijo de esta lista
	var idx: Array = []
	for i in n:
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool: return anio[a] < anio[b] or (anio[a] == anio[b] and a < b))
	orden = PackedInt32Array(idx)
	anios_ord.resize(n)
	for k in n:
		anios_ord[k] = anio[orden[k]]
	frontera = PackedByteArray()
	frontera.resize(n)
	estado.clear()
	ultimos.clear()
	anio_actual = NINGUNO
	cuenta_f = 0
	return true


# ─────────────────────────────────────────────────────────────
# Tiempo
# ─────────────────────────────────────────────────────────────
## Cuántos descubrimientos tienen año <= `a` (bisección sobre `anios_ord`).
func cuenta_hasta(a: int) -> int:
	var lo := 0
	var hi := n
	while lo < hi:
		var mid := (lo + hi) >> 1
		if anios_ord[mid] <= a:
			lo = mid + 1
		else:
			hi = mid
	return lo


## Nueva partida en el año `a`: la frontera es la historia de ese año y ningún país se aparta de ella.
func iniciar(a: int) -> void:
	estado.clear()
	_armar_frontera(a)
	_marcar_ultimos_iniciales()


func _armar_frontera(a: int) -> void:
	anio_actual = a
	cuenta_f = cuenta_hasta(a)
	frontera = PackedByteArray()
	frontera.resize(n)
	for k in cuenta_f:
		frontera[orden[k]] = 1


func _marcar_ultimos_iniciales() -> void:
	ultimos.clear()
	for k in range(maxi(cuenta_f - MAX_ULTIMOS, 0), cuenta_f):
		ultimos.append({"idx": orden[k], "anio": anios_ord[k]})


## El reloj llegó al año `a`. Lo que toque entra a la frontera y a todos los países con estado propio. Devuelve cuántos entraron.
## Si `a` no es posterior al año ya sincronizado no hace nada (es el caso de 11 de cada 12 meses).
func avanzar_a(a: int) -> int:
	if a <= anio_actual:
		return 0
	anio_actual = a
	var c := cuenta_hasta(a)
	if c <= cuenta_f:
		return 0
	var nuevos := c - cuenta_f
	for k in range(cuenta_f, c):
		var i: int = orden[k]
		frontera[i] = 1
		for tid in estado:
			var e: PackedByteArray = estado[tid]
			e[i] = 1
			estado[tid] = e
		ultimos.append({"idx": i, "anio": anios_ord[k]})
	cuenta_f = c
	if ultimos.size() > MAX_ULTIMOS:
		ultimos = ultimos.slice(ultimos.size() - MAX_ULTIMOS)
	return nuevos


## Salto de fecha (Debug). Hacia adelante: como `avanzar_a`. Hacia atrás: se quitan a todos los países los descubrimientos más nuevos que `a`.
## Con `reiniciar = true` todos los países vuelven además a la historia pura de `a` (se descartan sus estados propios).
func sincronizar(a: int, reiniciar := false) -> void:
	if reiniciar or anio_actual == NINGUNO:
		iniciar(a)
		return
	if a >= anio_actual:
		avanzar_a(a)
		return
	var c := cuenta_hasta(a)
	for k in range(c, cuenta_f):
		var i: int = orden[k]
		frontera[i] = 0
		for tid in estado:
			var e: PackedByteArray = estado[tid]
			e[i] = 0
			estado[tid] = e
	cuenta_f = c
	anio_actual = a
	_marcar_ultimos_iniciales()


# ─────────────────────────────────────────────────────────────
# Consultas
# ─────────────────────────────────────────────────────────────
func indice(sl: String) -> int:
	return int(idx_de_slug.get(sl, -1))


## ¿El país `tid` conoce el descubrimiento `i`?
func conoce(tid: int, i: int) -> bool:
	if i < 0 or i >= n:
		return false
	if estado.has(tid):
		return (estado[tid] as PackedByteArray)[i] == 1
	return frontera[i] == 1


func conoce_slug(tid: int, sl: String) -> bool:
	return conoce(tid, indice(sl))


## ¿Se conocen los prerrequisitos de `i` (todos los de `req` y uno de cada grupo de `req_o`)?
func requisitos_cumplidos(tid: int, i: int) -> bool:
	if i < 0 or i >= n:
		return false
	for r in req[i]:
		if not conoce(tid, r):
			return false
	for g in req_o[i]:
		var alguno := false
		for r2 in g:
			if conoce(tid, r2):
				alguno = true
				break
		if not alguno:
			return false
	return true


## «Disponible para investigar»: aún no lo conoce y ya tiene sus prerrequisitos.
func disponible(tid: int, i: int) -> bool:
	return i >= 0 and i < n and not conoce(tid, i) and requisitos_cumplidos(tid, i)


## El estado completo de un país (1 = lo conoce): su copia propia o, si nunca se apartó de la historia, la frontera.
func estado_de(tid: int) -> PackedByteArray:
	return estado[tid] if estado.has(tid) else frontera


func cantidad(tid: int) -> int:
	if not estado.has(tid):
		return cuenta_f
	var e: PackedByteArray = estado[tid]
	var c := 0
	for i in n:
		c += e[i]
	return c


## Cuántos conoce `tid` en cada era: PackedInt32Array de eras.size() posiciones.
func cantidad_por_era(tid: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	r.resize(eras.size())
	var e := estado_de(tid)
	for i in n:
		if e[i] == 1:
			r[era[i]] += 1
	return r


func total_por_era() -> PackedInt32Array:
	var r := PackedInt32Array()
	r.resize(eras.size())
	for i in n:
		r[era[i]] += 1
	return r


## Los `k` descubrimientos que siguen en el tiempo (los primeros que todavía no entran a la frontera).
func proximos(k: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	for j in range(cuenta_f, mini(cuenta_f + k, n)):
		r.append(orden[j])
	return r


# ─────────────────────────────────────────────────────────────
# Cambios propios de un país (la futura investigación)
# ─────────────────────────────────────────────────────────────
func _estado_propio(tid: int) -> PackedByteArray:
	if not estado.has(tid):
		estado[tid] = frontera.duplicate()
	return estado[tid]


## El país `tid` pasa a conocer `i` aunque la historia no haya llegado (o lo vuelve a tener). Devuelve false si ya lo conocía.
func conceder(tid: int, i: int) -> bool:
	if i < 0 or i >= n or conoce(tid, i):
		return false
	var e := _estado_propio(tid)
	e[i] = 1
	estado[tid] = e
	return true


## El país `tid` pierde `i` (retroceso tecnológico, pruebas). Devuelve false si no lo conocía.
func quitar(tid: int, i: int) -> bool:
	if i < 0 or i >= n or not conoce(tid, i):
		return false
	var e := _estado_propio(tid)
	e[i] = 0
	estado[tid] = e
	return true


## El país vuelve a la historia pura de la fecha actual (descarta su estado propio).
func reiniciar_pais(tid: int) -> void:
	estado.erase(tid)


# ─────────────────────────────────────────────────────────────
# Texto
# ─────────────────────────────────────────────────────────────
## Año para mostrar: 1769 → «1769», -44 → «44 a. C.», -2600000 → «2.600.000 a. C.».
static func anio_texto(a: int) -> String:
	if a >= 0:
		return str(a)
	return _miles(-a) + " a. C."


static func _miles(v: int) -> String:
	var s := str(v)
	var r := ""
	var c := 0
	for j in range(s.length() - 1, -1, -1):
		if c > 0 and c % 3 == 0:
			r = "." + r
		r = s[j] + r
		c += 1
	return r


func etiqueta(i: int) -> String:
	return "%s · %s" % [anio_texto(anio[i]), nombre[i]]
