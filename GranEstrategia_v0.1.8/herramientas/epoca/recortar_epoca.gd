extends SceneTree
## Recorta las provincias de hoy (datos/fuente_provincias.json) con los territorios de una época (naciones y pueblos)
## y escribe las PIEZAS resultantes: cada pieza = (provincia de hoy) ∩ (territorio de la época), o el resto sin reclamar.
##
## Uso (desde la raíz del proyecto):
##   godot --headless --path . --script res://herramientas/epoca/recortar_epoca.gd -- FUENTE.json TERRITORIOS.json SALIDA.json
##
## TERRITORIOS.json: {"entidades": [{"clave": "...", "partes": [[[x,y],...], ...]}, ...]}  (coordenadas del mapa, anillos simples,
##   en orden de PRIORIDAD: si dos territorios se solapan gana el primero).
## SALIDA.json: {"piezas": [{"p": índice de la provincia de hoy, "e": clave del territorio ("" = sin reclamar), "r": [[[x,y],...], ...]}],
##   "stats": {...}}
## Es una herramienta de generación de datos (no la usa el juego): usa Geometry2D (Clipper) porque no hay librerías de geometría en Python.

const EPS_AREA := 1.0e-5          # px²: por debajo de esto un trozo es ruido numérico
const AREA_MIN := 0.25            # px² (≈ 70 km²): un trozo más pequeño se funde con su vecino de la misma provincia de hoy
const GROSOR_MIN := 0.15          # px: un trozo más fino que esto (y de poca área) es una astilla y se funde con su vecino
const AREA_ASTILLA := 4.0         # px²: las astillas solo se funden si son pequeñas
## Subdivisión: una pieza de un territorio (no las tierras sin reclamar) mayor que A_SUB_MAX se reparte en provincias de unos A_SUB_OBJ px²
## con un diagrama de Voronoi de semillas casi en cuadrícula (1 px² ≈ 278 km²). Las celdas menores que A_SUB_MIN se funden con su vecina.
const A_SUB_MAX := 320.0
const A_SUB_OBJ := 160.0
const A_SUB_MIN := 40.0
const K_VECINAS := 18             # cada celda de Voronoi se recorta con las K semillas más cercanas
## 0.1.8.35 · CELDAS del mapa. Las tierras sin reclamar también se parten en celdas de Voronoi (sin cambiar de provincia: todas las celdas de un trozo
## salen con sub = 0 y se quedan en la misma pieza, así el escenario sigue teniendo las mismas provincias). Así ninguna celda del mundo es gigante:
## cualquier época puede repartir esas tierras y el juego puede cambiar la forma de una provincia pasando celdas de una a otra.
## Las áreas se miden en «px² reales» (área del mapa × coseno de la latitud: el mapa estira los polos).
const A_VAC_MAX := 900.0
const A_VAC_OBJ := 450.0
const A_VAC_MIN := 90.0

var _stats := {"anillos": 0, "con_corte": 0, "piezas": 0, "huecos_cortados": 0, "fundidos": 0, "sin_vecino": 0, "subdivididas": 0, "subprovincias": 0, "vacio_subdivididas": 0, "vacio_celdas": 0}
var _libre := {}                   # clave -> área de tierra (px²) del territorio SIN descontar lo que reclaman otros de más prioridad
var _sub_ctr := 0                  # contador de subprovincias dentro de la provincia de hoy que se está recortando


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Uso: -- FUENTE.json TERRITORIOS.json SALIDA.json")
		quit(2)
		return
	var t0 := Time.get_ticks_msec()
	var fuente: Array = _leer(args[0])
	var terr: Dictionary = _leer(args[1])
	var ents: Array = []
	for e in terr["entidades"]:
		var partes: Array = []
		for p in e["partes"]:
			var pv := PackedVector2Array()
			for q in p:
				pv.append(Vector2(float(q[0]), float(q[1])))
			if pv.size() >= 3 and absf(_area_firmada(pv)) > EPS_AREA:
				partes.append({"poly": pv, "bb": _bbox(pv)})
		ents.append({"clave": String(e["clave"]), "partes": partes})
	var salida: Array = []
	for pi in fuente.size():
		var prov: Dictionary = fuente[pi]
		var por_dueno := {}                         # "clave|sub" -> {"e": clave, "s": sub, "r": Array de anillos}
		_sub_ctr = 0
		for r in prov["polygons"]:
			var ring := PackedVector2Array()
			for q in r:
				ring.append(Vector2(float(q[0]), float(q[1])))
			if ring.size() < 3 or absf(_area_firmada(ring)) < EPS_AREA:
				continue
			_stats["anillos"] += 1
			for trozo in _repartir_anillo(ring, ents):
				var k := "%s|%d" % [trozo[0], trozo[1]]
				if not por_dueno.has(k):
					por_dueno[k] = {"e": trozo[0], "s": trozo[1], "r": []}
				por_dueno[k]["r"].append(trozo[2])
		for k in por_dueno:
			var rr: Array = []
			for poly in por_dueno[k]["r"]:
				var lst: Array = []
				for q in poly:
					lst.append([snappedf(q.x, 0.0001), snappedf(q.y, 0.0001)])
				rr.append(lst)
			salida.append({"p": pi, "e": por_dueno[k]["e"], "s": por_dueno[k]["s"], "r": rr})
			_stats["piezas"] += 1
	var f := FileAccess.open(args[2], FileAccess.WRITE)
	f.store_string(JSON.stringify({"piezas": salida, "stats": _stats, "libre": _libre}))
	f.close()
	print("recortar_epoca: ", _stats, " en ", Time.get_ticks_msec() - t0, " ms")
	quit(0)


func _leer(ruta: String):
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + ruta)
		quit(3)
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("JSON inválido en " + ruta)
		quit(3)
		return null
	return j.data


# ───────────── Geometría básica ─────────────
static func _area_firmada(p: PackedVector2Array) -> float:
	var a := 0.0
	var n := p.size()
	for i in n:
		var q := p[(i + 1) % n]
		a += p[i].x * q.y - q.x * p[i].y
	return a * 0.5


static func _perimetro(p: PackedVector2Array) -> float:
	var s := 0.0
	var n := p.size()
	for i in n:
		s += p[i].distance_to(p[(i + 1) % n])
	return s


static func _bbox(p: PackedVector2Array) -> Rect2:
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for q in p:
		x0 = minf(x0, q.x)
		y0 = minf(y0, q.y)
		x1 = maxf(x1, q.x)
		y1 = maxf(y1, q.y)
	return Rect2(x0, y0, x1 - x0, y1 - y0)


static func _solapan(a: Rect2, b: Rect2) -> bool:
	return a.position.x <= b.end.x and b.position.x <= a.end.x and a.position.y <= b.end.y and b.position.y <= a.end.y


## Un punto que está DENTRO del polígono (el centro de su primer triángulo).
static func _punto_interior(p: PackedVector2Array) -> Vector2:
	var tri := Geometry2D.triangulate_polygon(p)
	if tri.size() >= 3:
		var mejor := 0
		var ma := -1.0
		for k in range(0, tri.size() - 2, 3):
			var a := absf((p[tri[k + 1]] - p[tri[k]]).cross(p[tri[k + 2]] - p[tri[k]]))
			if a > ma:
				ma = a
				mejor = k
		return (p[tri[mejor]] + p[tri[mejor + 1]] + p[tri[mejor + 2]]) / 3.0
	return p[0]


# ───────────── Operaciones con control de huecos ─────────────
## Separa el resultado de Clipper en contornos exteriores y huecos (el hueco tiene el signo de área contrario al del mayor contorno).
func _separar(res: Array) -> Array:
	var ext: Array = []
	var hue: Array = []
	if res.is_empty():
		return [ext, hue]
	var mayor := 0
	var ma := 0.0
	for i in res.size():
		var a := absf(_area_firmada(res[i]))
		if a > ma:
			ma = a
			mayor = i
	var signo := signf(_area_firmada(res[mayor]))
	for p in res:
		var a := _area_firmada(p)
		if absf(a) < EPS_AREA:
			continue
		if signf(a) == signo:
			ext.append(p)
		else:
			hue.append(p)
	return [ext, hue]


## Convierte contornos exteriores + huecos en polígonos SIN huecos, cortando con rectas verticales que atraviesan cada hueco.
## (El juego no admite huecos: los enclaves se dibujan por orden de tamaño; aquí los cortes quedan DENTRO de una misma provincia.)
func _sin_huecos(ext: Array, hue: Array) -> Array:
	if hue.is_empty():
		return ext
	var res: Array = []
	var asignados := {}
	for h in hue:
		var pt := _punto_interior(h)
		var dueno := -1
		for i in ext.size():
			if Geometry2D.is_point_in_polygon(pt, ext[i]):
				dueno = i
				break
		if dueno < 0:
			continue
		if not asignados.has(dueno):
			asignados[dueno] = []
		asignados[dueno].append(h)
	for i in ext.size():
		if not asignados.has(i):
			res.append(ext[i])
			continue
		var hs: Array = asignados[i]
		_stats["huecos_cortados"] += hs.size()
		var cortes: Array = []
		for h in hs:
			var bb := _bbox(h)
			cortes.append(bb.position.x + bb.size.x * 0.5)
		cortes.sort()
		var lim: Array = [-1.0e6]
		lim.append_array(cortes)
		lim.append(1.0e6)
		for k in lim.size() - 1:
			var x0: float = lim[k]
			var x1: float = lim[k + 1]
			if x1 - x0 < 1.0e-6:
				continue
			var caja := PackedVector2Array([Vector2(x0, -1.0e6), Vector2(x1, -1.0e6), Vector2(x1, 1.0e6), Vector2(x0, 1.0e6)])
			var lonja: Array = Geometry2D.intersect_polygons(ext[i], caja)
			var actual: Array = []
			for l in lonja:
				if absf(_area_firmada(l)) > EPS_AREA:
					actual.append(l)
			for h in hs:
				var siguiente: Array = []
				for l in actual:
					if not _solapan(_bbox(l), _bbox(h)):
						siguiente.append(l)
						continue
					var d: Array = Geometry2D.clip_polygons(l, h)
					var sp := _separar(d)
					# una lonja menos un hueco que la cruza no tiene huecos; si aun así queda alguno se ignora (el hueco se rellena)
					siguiente.append_array(sp[0])
				actual = siguiente
			res.append_array(actual)
	return res


## a − b sobre una lista de polígonos simples; devuelve polígonos simples.
func _restar(lista: Array, b: PackedVector2Array, bb: Rect2) -> Array:
	var res: Array = []
	for l in lista:
		if not _solapan(_bbox(l), bb):
			res.append(l)
			continue
		var d: Array = Geometry2D.clip_polygons(l, b)
		var sp := _separar(d)
		res.append_array(_sin_huecos(sp[0], sp[1]))
	return res


# ───────────── Reparto de un anillo ─────────────
## Devuelve [[clave, polígono], ...]: trozos del anillo por territorio de la época ("" = lo que nadie reclama).
func _repartir_anillo(ring: PackedVector2Array, ents: Array) -> Array:
	var bb_r := _bbox(ring)
	var trozos: Array = []                           # [clave, polígono, bbox]
	var cortado := false
	for e in ents:
		for parte in e["partes"]:
			if not _solapan(bb_r, parte["bb"]):
				continue
			var inter: Array = Geometry2D.intersect_polygons(ring, parte["poly"])
			if inter.is_empty():
				continue
			var sp := _separar(inter)
			var nuevos: Array = _sin_huecos(sp[0], sp[1])
			for n0 in nuevos:
				_libre[e["clave"]] = float(_libre.get(e["clave"], 0.0)) + absf(_area_firmada(n0))
			# lo que ya reclamó un territorio de más prioridad no se vuelve a repartir
			for t in trozos:
				nuevos = _restar(nuevos, t[1], t[2])
			for n in nuevos:
				if absf(_area_firmada(n)) > EPS_AREA:
					trozos.append([e["clave"], n, _bbox(n)])
	var resto: Array = [ring]
	for t in trozos:
		resto = _restar(resto, t[1], t[2])
	for r in resto:
		if absf(_area_firmada(r)) > EPS_AREA:
			trozos.append(["", r, _bbox(r)])
	if trozos.size() > 1:
		_stats["con_corte"] += 1
		trozos = _fundir_astillas(trozos)
	var salida: Array = []                           # [clave, sub, polígono]
	for t in trozos:
		if t[0] != "" and absf(_area_firmada(t[1])) > A_SUB_MAX:
			salida.append_array(_subdividir(t[0], t[1]))
		elif t[0] == "" and _area_real(t[1]) > A_VAC_MAX:
			salida.append_array(_subdividir(t[0], t[1], A_VAC_OBJ / _coseno_lat(t[1]), A_VAC_MIN / _coseno_lat(t[1]), false))
		else:
			salida.append([t[0], 0, t[1]])
	return salida


# ───────────── Subdivisión en provincias (Voronoi) ─────────────
## Coseno de la latitud del centro del polígono (mínimo 0,15: junto a los polos las celdas salen anchas pero no infinitas).
## El mapa es equirrectangular: y = (90 − lat) × 2400 / 360, el ecuador está en y = 600.
static func _coseno_lat(poly: PackedVector2Array) -> float:
	var bb := _bbox(poly)
	var lat := 90.0 - (bb.position.y + bb.size.y * 0.5) * 360.0 / 2400.0
	return maxf(cos(deg_to_rad(lat)), 0.15)


static func _area_real(poly: PackedVector2Array) -> float:
	return absf(_area_firmada(poly)) * _coseno_lat(poly)



## Reparte un polígono simple en celdas de Voronoi. Devuelve [[clave, sub, polígono], ...] (sub = 0 si no se pudo subdividir).
## `obj`/`amin` en px² del mapa; con `numerar` = false las celdas no son subprovincias nuevas (todas salen con sub = 0).
func _subdividir(clave: String, poly: PackedVector2Array, obj := A_SUB_OBJ, amin := A_SUB_MIN, numerar := true) -> Array:
	var bb := _bbox(poly)
	var paso := sqrt(obj)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(bb.position.x * 100.0) * 7919 + int(bb.position.y * 100.0) * 104729 + int(absf(_area_firmada(poly)))
	var sem: Array = []
	var y := bb.position.y + paso * 0.5
	while y < bb.end.y:
		var x := bb.position.x + paso * 0.5
		while x < bb.end.x:
			var p := Vector2(x + rng.randf_range(-0.38, 0.38) * paso, y + rng.randf_range(-0.38, 0.38) * paso)
			if Geometry2D.is_point_in_polygon(p, poly):
				sem.append(p)
			x += paso
		y += paso
	if sem.size() < 2:
		return [[clave, 0, poly]]
	var caja := bb.grow(paso * 2.0)
	var trozos: Array = []                           # [id de celda (texto), polígono, bbox]
	for i in sem.size():
		var celda := _celda_voronoi(sem, i, caja)
		for q in Geometry2D.intersect_polygons(poly, celda):
			if absf(_area_firmada(q)) > EPS_AREA:
				trozos.append([str(i), q, _bbox(q)])
	trozos = _fundir_astillas(trozos, amin)
	if not numerar:
		var celdas: Array = []
		for t in trozos:
			celdas.append([clave, 0, t[1]])
		_stats["vacio_subdivididas"] += 1
		_stats["vacio_celdas"] += celdas.size()
		return celdas
	var ids := {}
	var res: Array = []
	for t in trozos:
		if not ids.has(t[0]):
			_sub_ctr += 1
			ids[t[0]] = _sub_ctr
		res.append([clave, int(ids[t[0]]), t[1]])
	_stats["subdivididas"] += 1
	_stats["subprovincias"] += ids.size()
	return res


## Celda de Voronoi de la semilla i, recortada con las K_VECINAS semillas más cercanas y con la caja.
func _celda_voronoi(sem: Array, i: int, caja: Rect2) -> PackedVector2Array:
	var cand: Array = []
	for j in sem.size():
		if j != i:
			cand.append([sem[i].distance_squared_to(sem[j]), j])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var cel := PackedVector2Array([caja.position, Vector2(caja.end.x, caja.position.y), caja.end, Vector2(caja.position.x, caja.end.y)])
	for k in mini(cand.size(), K_VECINAS):
		cel = _semiplano(cel, sem[i], sem[int(cand[k][1])])
		if cel.size() < 3:
			break
	return cel


## Parte del polígono convexo `c` más cerca de `a` que de `b` (Sutherland–Hodgman con un semiplano).
static func _semiplano(c: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var m := (a + b) * 0.5
	var d := b - a
	var res := PackedVector2Array()
	var n := c.size()
	for k in n:
		var p := c[k]
		var q := c[(k + 1) % n]
		var dp := (p - m).dot(d)
		var dq := (q - m).dot(d)
		if dp <= 0.0:
			res.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			res.append(p + (q - p) * (dp / (dp - dq)))
	return res


## Funde los trozos diminutos o finísimos con el vecino con el que comparten más frontera (dentro del mismo anillo).
## Cada trozo es [clave, polígono, bbox, bloqueado]; «bloqueado» = ya se intentó y no tiene vecino con el que fundirse.
func _es_mala(p: PackedVector2Array, amin := AREA_MIN) -> bool:
	var a := absf(_area_firmada(p))
	if a < amin:
		return true
	return a < AREA_ASTILLA and 2.0 * a / maxf(_perimetro(p), 1.0e-9) < GROSOR_MIN


func _fundir_astillas(trozos: Array, amin := AREA_MIN) -> Array:
	for t in trozos:
		t.append(false)
	while trozos.size() > 1:
		var peor := -1
		var peor_a := INF
		for i in trozos.size():
			if trozos[i][3] or not _es_mala(trozos[i][1], amin):
				continue
			var a := absf(_area_firmada(trozos[i][1]))
			if a < peor_a:
				peor_a = a
				peor = i
		if peor < 0:
			break
		var p0: PackedVector2Array = trozos[peor][1]
		var per0 := _perimetro(p0)
		var mejor := -1
		var mejor_c := 1.0e-4
		var mejor_u: PackedVector2Array
		for j in trozos.size():
			if j == peor or not _solapan(trozos[peor][2], trozos[j][2]):
				continue
			var q: PackedVector2Array = trozos[j][1]
			var sp := _separar(Geometry2D.merge_polygons(p0, q))
			if sp[0].size() != 1 or not sp[1].is_empty():
				continue
			var comun := (per0 + _perimetro(q) - _perimetro(sp[0][0])) * 0.5
			if comun > mejor_c:
				mejor_c = comun
				mejor = j
				mejor_u = sp[0][0]
		if mejor < 0:
			trozos[peor][3] = true
			_stats["sin_vecino"] += 1
			continue
		trozos[mejor][1] = mejor_u
		trozos[mejor][2] = _bbox(mejor_u)
		trozos[mejor][3] = false
		trozos.remove_at(peor)
		_stats["fundidos"] += 1
	return trozos
