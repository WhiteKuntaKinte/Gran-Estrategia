extends SceneTree
## Une las plataformas de hielo de la Antártida (fuentes/plataformas_hielo_px.json, ver preparar_plataformas_hielo.py) a la provincia «ata_00_»
## de datos/fuente_provincias.json. Es una herramienta de generación de datos (no la usa el juego): usa Geometry2D (Clipper) porque no hay
## librerías de geometría en Python.
##
## Uso (desde la raíz del proyecto; escribe SALIDA.json, que sustituye a datos/fuente_provincias.json):
##   godot --headless --path . --script res://herramientas/epoca/unir_plataformas.gd -- datos/fuente_provincias.json \
##         herramientas/epoca/fuentes/plataformas_hielo_px.json SALIDA.json
## Es idempotente: si la provincia ya tiene la marca «plataformas», copia el archivo tal cual.
##
## Cómo: se «cierra» la unión (se engorda CIERRE px cada anillo, se unen, se encogen de nuevo) para que las rendijas entre el continente y las
## plataformas —que vienen de dos capas distintas de Natural Earth— no dejen costuras; los huecos interiores se rellenan.

const ID_ATA := "ata_00_"
const CIERRE := 0.35           # px (≈ 5 km)
const AREA_MIN := 0.05         # px²: por debajo de esto un trozo es ruido


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Uso: -- FUENTE.json PLATAFORMAS.json SALIDA.json")
		quit(2)
		return
	var fuente: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var plat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var ia := -1
	for i in fuente.size():
		if String(fuente[i]["id"]) == ID_ATA:
			ia = i
	if ia < 0:
		push_error("No está la provincia " + ID_ATA)
		quit(3)
		return
	var prov: Dictionary = fuente[ia]
	if prov.get("plataformas", false):
		print("unir_plataformas: ya estaban unidas; no se cambia nada")
	else:
		var anillos: Array = []
		for r in prov["polygons"]:
			anillos.append(_pv(r))
		var n_cont := anillos.size()
		for r in plat["anillos"]:
			anillos.append(_pv(r))
		var antes := 0
		for r in anillos:
			antes += r.size()
		# 1) engordar
		var gordos: Array = []
		for r in anillos:
			for g in Geometry2D.offset_polygon(r, CIERRE, Geometry2D.JOIN_MITER):
				if not Geometry2D.is_polygon_clockwise(g):
					gordos.append(g)
		# 2) unir (solo se conservan los contornos exteriores: los huecos se rellenan)
		var acc: Array = []
		for g in gordos:
			var cur: PackedVector2Array = g
			var otros: Array = []
			var cambio := true
			while cambio:
				cambio = false
				otros = []
				for a in acc:
					if not _bb_toca(cur, a):
						otros.append(a)
						continue
					var m := Geometry2D.merge_polygons(cur, a)
					if m.size() == 2 and _es_disjunto(m, cur, a):
						otros.append(a)                 # se tocan las cajas pero no los polígonos
						continue
					cur = _exterior(m)
					cambio = true
				acc = otros
			acc.append(cur)
		# 3) encoger
		var fin: Array = []
		for u in acc:
			for g in Geometry2D.offset_polygon(u, -CIERRE, Geometry2D.JOIN_MITER):
				if not Geometry2D.is_polygon_clockwise(g) and absf(_area(g)) >= AREA_MIN:
					fin.append(g)
		fin.sort_custom(func(a, b): return absf(_area(a)) > absf(_area(b)))
		var salida_r: Array = []
		var despues := 0
		for g in fin:
			var r: Array = []
			for q in g:
				r.append([snappedf(q.x, 0.001), snappedf(q.y, 0.001)])
			despues += r.size()
			salida_r.append(r)
		prov["polygons"] = salida_r
		prov["plataformas"] = true
		print("unir_plataformas: %d anillos del continente + %d plataformas (%d vértices) → %d anillos (%d vértices)" % [n_cont, plat["anillos"].size(), antes, salida_r.size(), despues])
	var f := FileAccess.open(args[2], FileAccess.WRITE)
	f.store_string(JSON.stringify(fuente, "", false))
	f.close()
	quit(0)


func _pv(r: Array) -> PackedVector2Array:
	var pv := PackedVector2Array()
	for q in r:
		pv.append(Vector2(float(q[0]), float(q[1])))
	return pv


func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		s += a.x * b.y - b.x * a.y
	return 0.5 * s


func _bb_toca(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var ra := _bb(a)
	var rb := _bb(b)
	return ra.intersects(rb, true)


func _bb(p: PackedVector2Array) -> Rect2:
	var mn := p[0]
	var mx := p[0]
	for q in p:
		mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.y))
		mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.y))
	return Rect2(mn, mx - mn)


## ¿Las dos piezas que devolvió merge_polygons son el original sin tocar (no se solapaban)?
func _es_disjunto(m: Array, a: PackedVector2Array, b: PackedVector2Array) -> bool:
	if Geometry2D.is_polygon_clockwise(m[0]) or Geometry2D.is_polygon_clockwise(m[1]):
		return false                                   # exterior + hueco: sí se unieron
	return Geometry2D.intersect_polygons(a, b).is_empty()


## El contorno exterior (el de más área y no horario) de lo que devuelve merge_polygons.
func _exterior(m: Array) -> PackedVector2Array:
	var mejor: PackedVector2Array = m[0]
	var amax := -1.0
	for g in m:
		if Geometry2D.is_polygon_clockwise(g):
			continue
		var ar := absf(_area(g))
		if ar > amax:
			amax = ar
			mejor = g
	return mejor
