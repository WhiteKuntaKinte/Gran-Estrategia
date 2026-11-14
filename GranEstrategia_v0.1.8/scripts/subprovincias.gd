extends RefCounted
## 0.1.8.43 · SUBPROVINCIAS REALES (país → provincia → subprovincia, como estado → condado).
## Límites: geoBoundaries (William & Mary geoLab), CC BY 4.0 (compuesto CGAZ, nivel ADM2; lo prepara `herramientas/subprovincias/construir_subprovincias.py`).
## Archivos (`datos/subprov/`): un `.bin` por país actual (anillos en px del mapa × ESC, con deltas), `indice.bin` (casillas de 1° → unidades) y `nombres.json`.
##
## Cómo se usa: `de_provincia(pi)` devuelve las subprovincias de UNA provincia del juego, calculadas al pedirlas (carga el país que haga falta, recorta cada unidad con el
## contorno de la provincia y lo guarda en caché): nada de esto se hace al cargar el mundo ni por fotograma. Los límites son los de ~2020: en las épocas antiguas son una
## referencia moderna, no una división histórica (la ficha lo avisa). La población de una subprovincia es la de su provincia repartida por superficie.
const CARPETA := "res://datos/subprov/"
const ESC := 1024.0
const COLUMNAS := 360
const FILAS := 180
const ANCHO_MAPA := 2400.0
const ALTO_MAPA := 1200.0
const FRAC_MIN := 0.003                  # una unidad que cubre menos de esto de la provincia se descarta (astillas de costa)
const CACHE_MAX := 48                    # provincias guardadas
const PAISES_MAX := 24                   # archivos de país en memoria
const KM_POR_GRADO := 111.32
const CREDITO := "Límites de subprovincias: geoBoundaries (William & Mary geoLab), CC BY 4.0"

var main
var listo := false
var _isos: Array = []
var _nombres: Dictionary = {}
var _desp := PackedInt32Array()
var _ent := PackedInt32Array()
var _paises := {}                        # índice de país -> arreglo de palabras
var _orden: Array = []                   # índices de país, el más reciente al final
var _cache := {}                         # índice de provincia -> Array de subprovincias
var _orden_cache: Array = []
var ultimo_ms := 0.0                     # lo que costó la última provincia calculada
var calculadas := 0                      # cuántas provincias se han calculado (para pruebas)


func iniciar(p_main) -> void:
	main = p_main
	listo = false
	if not FileAccess.file_exists(CARPETA + "nombres.json") or not FileAccess.file_exists(CARPETA + "indice.bin"):
		return
	var js = JSON.parse_string(FileAccess.get_file_as_string(CARPETA + "nombres.json"))
	if typeof(js) != TYPE_DICTIONARY:
		return
	_isos = js["isos"]
	_nombres = js["nombres"]
	var w := _leer_bin(CARPETA + "indice.bin")
	if w.size() < COLUMNAS * FILAS + 2:
		return
	var n := COLUMNAS * FILAS + 1
	_desp = w.slice(0, n)
	_ent = w.slice(n)
	listo = true


## Archivo `.bin` → palabras int32 (4 bytes de tamaño sin comprimir + zlib).
func _leer_bin(ruta: String) -> PackedInt32Array:
	var b := FileAccess.get_file_as_bytes(ruta)
	if b.size() < 8:
		return PackedInt32Array()
	var tam := b.decode_u32(0)
	var crudo := b.slice(4).decompress(tam, FileAccess.COMPRESSION_DEFLATE)
	return crudo.to_int32_array()


func _pais(i: int) -> PackedInt32Array:
	if _paises.has(i):
		_orden.erase(i)
		_orden.append(i)
		return _paises[i]
	var w := _leer_bin(CARPETA + "%s.bin" % String(_isos[i]))
	_paises[i] = w
	_orden.append(i)
	while _orden.size() > PAISES_MAX:
		_paises.erase(_orden.pop_front())
	return w


func disponible() -> bool:
	return listo


## Lo que hay en caché (para que la interfaz sepa si ya está calculada sin forzar el cálculo).
func calculada(pi: int) -> bool:
	return _cache.has(pi)


func olvidar(pi := -1) -> void:
	if pi < 0:
		_cache.clear()
		_orden_cache.clear()
	else:
		_cache.erase(pi)
		_orden_cache.erase(pi)


## Unidades del archivo del país `i` que tocan la caja `caja` (px del mapa): [[índice de país, índice de unidad]].
func _candidatas(caja: Rect2) -> Array:
	var gx0 := clampi(int(caja.position.x * float(COLUMNAS) / ANCHO_MAPA), 0, COLUMNAS - 1)
	var gx1 := clampi(int(caja.end.x * float(COLUMNAS) / ANCHO_MAPA), 0, COLUMNAS - 1)
	var gy0 := clampi(int(caja.position.y * float(FILAS) / ALTO_MAPA), 0, FILAS - 1)
	var gy1 := clampi(int(caja.end.y * float(FILAS) / ALTO_MAPA), 0, FILAS - 1)
	var vistas := {}
	var r: Array = []
	for gy in range(gy0, gy1 + 1):
		for gx in range(gx0, gx1 + 1):
			var c := gy * COLUMNAS + gx
			for k in range(_desp[c], _desp[c + 1]):
				var e := _ent[k]
				if not vistas.has(e):
					vistas[e] = true
					r.append(e)
	return r


## Anillos de una unidad: {"caja": Rect2, "ext": [PackedVector2Array], "huecos": [PackedVector2Array]}.
func _unidad(i: int, k: int) -> Dictionary:
	var w := _pais(i)
	var o: int = w[1 + k]
	var caja := Rect2(Vector2(w[o], w[o + 1]) / ESC, Vector2(w[o + 2] - w[o], w[o + 3] - w[o + 1]) / ESC)
	return {"caja": caja, "o": o}


func _anillos(i: int, o: int) -> Array:
	var w := _pais(i)
	var nr: int = w[o + 4]
	var p := o + 5
	var ext: Array = []
	var huecos: Array = []
	for r in nr:
		var n: int = w[p]
		var hueco: bool = w[p + 1] == 1
		var x: int = w[p + 2]
		var y: int = w[p + 3]
		var pts := PackedVector2Array()
		pts.resize(n)
		pts[0] = Vector2(x, y) / ESC
		var q := p + 4
		for j in range(1, n):
			x += w[q]
			y += w[q + 1]
			q += 2
			pts[j] = Vector2(x, y) / ESC
		p = q
		if hueco:
			huecos.append(pts)
		else:
			ext.append(pts)
	return [ext, huecos]


static func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	var n := p.size()
	for k in n:
		var a := p[k]
		var b := p[(k + 1) % n]
		s += a.x * b.y - b.x * a.y
	return 0.5 * s


static func _caja_de(p: PackedVector2Array) -> Rect2:
	var r := Rect2(p[0], Vector2.ZERO)
	for q in p:
		r = r.expand(q)
	return r


## Km² de un polígono (px del mapa, proyección equirrectangular): su área en px² × (grados por px)² × (km por grado)² × cos(latitud).
static func km2(p: PackedVector2Array) -> float:
	var lat := 90.0 - _caja_de(p).get_center().y * 180.0 / ALTO_MAPA
	var g := 360.0 / ANCHO_MAPA
	return absf(_area(p)) * g * g * KM_POR_GRADO * KM_POR_GRADO * cos(deg_to_rad(lat))


## Las subprovincias de la provincia `pi`: [{"nombre", "iso", "km2", "frac", "piezas": [PackedVector2Array], "centro": Vector2, "caja": Rect2}], de mayor a menor.
## Vacío si no hay datos o la provincia no cae sobre ninguna unidad (islas minúsculas, el polo...).
func de_provincia(pi: int) -> Array:
	if not listo or main == null or main.territorio == null or not main.territorio.listo():
		return []
	if _cache.has(pi):
		return _cache[pi]
	var t0 := Time.get_ticks_usec()
	var celdas: PackedInt32Array = main.territorio.celdas_de(pi)
	var lista: Array = []
	for c in celdas:
		lista.append(int(c))
	var contornos: Array = main._contorno_de_anillos(lista)
	var cadenas: Array = []
	for cl in contornos:
		var pts: PackedVector2Array = cl
		if pts.size() > 3 and pts[0].is_equal_approx(pts[pts.size() - 1]):
			pts = pts.slice(0, pts.size() - 1)
		if pts.size() >= 3:
			cadenas.append(pts)
	var fuera: Array = []                                           # contornos exteriores de la provincia
	var dentro: Array = []                                          # huecos de la provincia (enclaves)
	for a in cadenas.size():                                        # el contorno no trae orientación: un contorno es hueco si está dentro de un número impar de otros
		var prof := 0
		var q0: Vector2 = (cadenas[a] as PackedVector2Array)[0]
		for b in cadenas.size():
			if b != a and Geometry2D.is_point_in_polygon(q0, cadenas[b]):
				prof += 1
		if prof % 2 == 0:
			fuera.append(cadenas[a])
		else:
			dentro.append(cadenas[a])
	var resultado: Array = []
	if not fuera.is_empty():
		var caja := _caja_de(fuera[0])
		for f in fuera:
			caja = caja.merge(_caja_de(f))
		resultado = _recortar(caja, fuera, dentro)
	if resultado.size() > 0:
		resultado.sort_custom(func(a, b): return float(a["km2"]) > float(b["km2"]))
	_guardar(pi, resultado)
	ultimo_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	calculadas += 1
	return resultado


func _guardar(pi: int, r: Array) -> void:
	_cache[pi] = r
	_orden_cache.erase(pi)
	_orden_cache.append(pi)
	while _orden_cache.size() > CACHE_MAX:
		_cache.erase(_orden_cache.pop_front())


func _recortar(caja: Rect2, fuera: Array, dentro: Array) -> Array:
	var por_unidad := {}                                            # e -> {"piezas": [], "km2": 0.0}
	var orden: Array = []
	for e in _candidatas(caja):
		var i: int = int(e) >> 20
		var k: int = int(e) & 0xFFFFF
		var u := _unidad(i, k)
		if not (u["caja"] as Rect2).intersects(caja):
			continue
		var an := _anillos(i, int(u["o"]))
		var piezas: Array = []
		for ring in an[0]:
			var rc := _caja_de(ring)
			for f in fuera:
				if not rc.intersects(_caja_de(f)):
					continue
				for pz in Geometry2D.intersect_polygons(ring, f):
					piezas.append(pz)
		if piezas.is_empty():
			continue
		var huecos: Array = (an[1] as Array) + dentro
		if not huecos.is_empty():
			var sin_huecos: Array = []
			for pz in piezas:
				var parte: Array = [pz]
				for h in huecos:
					var siguiente: Array = []
					for q in parte:
						if _caja_de(q).intersects(_caja_de(h)):
							siguiente.append_array(Geometry2D.clip_polygons(q, h))
						else:
							siguiente.append(q)
					parte = siguiente
				sin_huecos.append_array(parte)
			piezas = sin_huecos
		var area := 0.0
		var buenas: Array = []
		for pz in piezas:
			if pz.size() < 3:
				continue
			buenas.append(pz)
			area += km2(pz)
		if buenas.is_empty():
			continue
		por_unidad[e] = {"piezas": buenas, "km2": area}
		orden.append(e)
	var total := 0.0
	for e in orden:
		total += float(por_unidad[e]["km2"])
	var r: Array = []
	if total <= 0.0:
		return r
	for e in orden:
		var d: Dictionary = por_unidad[e]
		var frac := float(d["km2"]) / total
		if frac < FRAC_MIN:
			continue
		var i: int = int(e) >> 20
		var k: int = int(e) & 0xFFFFF
		var piezas: Array = d["piezas"]
		var mayor: PackedVector2Array = piezas[0]
		var caja_u := _caja_de(mayor)
		for pz in piezas:
			if absf(_area(pz)) > absf(_area(mayor)):
				mayor = pz
			caja_u = caja_u.merge(_caja_de(pz))
		var iso: String = String(_isos[i])
		var nombres: Array = _nombres[iso]
		r.append({"nombre": String(nombres[k]), "iso": iso, "km2": float(d["km2"]), "frac": frac, "piezas": piezas, "centro": _centro(mayor), "caja": caja_u})
	var s := 0.0
	for d in r:
		s += float(d["frac"])
	if s > 0.0:
		for d in r:
			d["frac"] = float(d["frac"]) / s
	return r


## Un punto dentro del polígono cerca de su centro de masa.
static func _centro(p: PackedVector2Array) -> Vector2:
	var a := _area(p)
	if absf(a) < 1.0e-9:
		return p[0]
	var cx := 0.0
	var cy := 0.0
	var n := p.size()
	for k in n:
		var u := p[k]
		var v := p[(k + 1) % n]
		var f := u.x * v.y - v.x * u.y
		cx += (u.x + v.x) * f
		cy += (u.y + v.y) * f
	var c := Vector2(cx, cy) / (6.0 * a)
	if Geometry2D.is_point_in_polygon(c, p):
		return c
	var tri := Geometry2D.triangulate_polygon(p)
	if tri.size() >= 3:
		return (p[tri[0]] + p[tri[1]] + p[tri[2]]) / 3.0
	return p[0]


## Índice (en la lista de `pi`) de la subprovincia que contiene el punto `pt`, o −1.
func en_punto(pi: int, pt: Vector2) -> int:
	if not _cache.has(pi):
		return -1
	var lista: Array = _cache[pi]
	var x := fposmod(pt.x, ANCHO_MAPA)
	var q := Vector2(x, pt.y)
	for i in lista.size():
		var d: Dictionary = lista[i]
		if not (d["caja"] as Rect2).has_point(q):
			continue
		for pz in d["piezas"]:
			if Geometry2D.is_point_in_polygon(q, pz):
				return i
	return -1
