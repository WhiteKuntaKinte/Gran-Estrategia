extends Node2D
## 0.1.8.43 · Capa de SUBPROVINCIAS: lo que se ve en el mapa cuando se abren las subdivisiones de una provincia (doble clic o botón de la ficha).
## Dibuja los límites internos (cinta de malla con grosor fijo en píxeles, como la línea de la selección: el zoom solo cambia números del shader),
## resalta la subprovincia bajo el cursor y la elegida, y muestra su nombre junto al cursor. Los datos vienen de `scripts/subprovincias.gd`.
## Nada se calcula por fotograma ni por paso de zoom: la geometría se arma una vez al abrir; el cursor solo prueba «punto dentro de polígono» (con un
## máximo de 25 pruebas por segundo) sobre las cajas de la lista.
const COPIAS := [-2400.0, 0.0, 2400.0]
const Z_LINEAS := 11
const Z_RELLENO := 10
const COLOR_HOVER := Color(1.0, 0.97, 0.80, 0.22)
const COLOR_ELEGIDA := Color(1.0, 0.82, 0.10, 0.30)

var main
var pi := -1                                  # provincia abierta (−1 = capa apagada)
var lista: Array = []
var hover := -1
var elegida := -1
var _nodos: Array = []                        # límites internos
var _nodos_hover: Array = []
var _nodos_elegida: Array = []
var _capa_texto: CanvasLayer
var _panel: PanelContainer
var _etiqueta: Label
var _t_mov := 0


func iniciar(p_main) -> void:
	main = p_main
	z_index = 0
	_capa_texto = CanvasLayer.new()
	_capa_texto.layer = 29
	add_child(_capa_texto)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	sb.border_color = Color(0.85, 0.70, 0.30, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_etiqueta = Label.new()
	_etiqueta.add_theme_font_size_override("font_size", 13)
	_etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_etiqueta)
	_capa_texto.add_child(_panel)


func activa() -> bool:
	return pi >= 0


## Abre las subdivisiones de la provincia `p`. Devuelve false si no hay datos para ella (la ficha lo explica).
func mostrar(p: int) -> bool:
	ocultar()
	if main == null or main.subprov == null or not main.subprov.disponible():
		return false
	lista = main.subprov.de_provincia(p)
	if lista.is_empty():
		return false
	pi = p
	hover = -1
	elegida = -1
	var lineas: Array = []
	for d in lista:
		for pz in d["piezas"]:
			var l: PackedVector2Array = (pz as PackedVector2Array).duplicate()
			l.append(l[0])
			lineas.append(l)
	_poner(main._malla_cintas(lineas), "sub", Z_LINEAS, _nodos)
	return true


func ocultar() -> void:
	for lst in [_nodos, _nodos_hover, _nodos_elegida]:
		for n in lst:
			if is_instance_valid(n):
				n.queue_free()
		(lst as Array).clear()
	pi = -1
	lista = []
	hover = -1
	elegida = -1
	if _panel != null:
		_panel.visible = false


func _poner(malla: ArrayMesh, clave: String, z: int, destino: Array) -> void:
	if malla == null:
		return
	var mat: ShaderMaterial = main._material_seleccion(clave)
	for dx in COPIAS:
		var mi := MeshInstance2D.new()
		mi.mesh = malla
		mi.material = mat
		mi.position = Vector2(dx, 0.0)
		mi.z_index = z
		add_child(mi)
		destino.append(mi)


func _rellenar(i: int, color: Color, destino: Array, con_borde: bool) -> void:
	for n in destino:
		if is_instance_valid(n):
			n.queue_free()
	destino.clear()
	if i < 0 or i >= lista.size():
		return
	var lineas: Array = []
	for pz in lista[i]["piezas"]:
		for dx in COPIAS:
			var pg := Polygon2D.new()
			pg.polygon = pz
			pg.color = color
			pg.position = Vector2(dx, 0.0)
			pg.z_index = Z_RELLENO
			add_child(pg)
			destino.append(pg)
		if con_borde:
			var l: PackedVector2Array = (pz as PackedVector2Array).duplicate()
			l.append(l[0])
			lineas.append(l)
	if con_borde:
		_poner(main._malla_cintas(lineas), "sub_sel", Z_LINEAS + 1, destino)


## El cursor se movió sobre el mapa (`pos` en coordenadas del mundo). Como mucho 25 pruebas por segundo.
func mover(pos: Vector2, pantalla: Vector2) -> void:
	if pi < 0:
		return
	var ahora := Time.get_ticks_msec()
	if ahora - _t_mov < 40:
		return
	_t_mov = ahora
	var i: int = main.subprov.en_punto(pi, pos)
	if i != hover:
		hover = i
		_rellenar(i, COLOR_HOVER, _nodos_hover, false)
	if i < 0:
		_panel.visible = false
		return
	var d: Dictionary = lista[i]
	_etiqueta.text = "%s\n%s km² · %.1f %% de la provincia" % [String(d["nombre"]), main.fmt_n(float(d["km2"])), 100.0 * float(d["frac"])]
	_panel.visible = true
	_panel.position = pantalla + Vector2(18.0, 18.0)


## Clic dentro de la provincia abierta: elige la subprovincia bajo el cursor. Devuelve true si el clic cayó en una (entonces nadie más lo atiende).
func elegir(pos: Vector2) -> bool:
	if pi < 0:
		return false
	var i: int = main.subprov.en_punto(pi, pos)
	if i < 0:
		return false
	elegir_indice(i)
	return true


func elegir_indice(i: int) -> void:
	elegida = i if i != elegida else -1
	_rellenar(elegida, COLOR_ELEGIDA, _nodos_elegida, true)
