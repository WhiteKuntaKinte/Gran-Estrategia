extends Node
## Tabla de posiciones de la campaña (0.1.8.2): ventana flotante con los países que juegan (los que tienen IA y el tuyo),
## ordenados por un puntaje combinado: 40 % provincias · 30 % tropas · 30 % ingresos (cada uno respecto al mejor de la tabla).
## Muestra provincias, soldados, ingresos por día (en US$) y el puntaje. Se actualiza sola cada pocos segundos mientras está abierta.
## No pausa el juego. Se abre con el botón «Ranking» de arriba a la izquierda (o la tecla R).

signal cerrada

const VentanaScript := preload("res://scripts/ventana_flotante.gd")
const C_ORO := Color(0.93, 0.78, 0.28)
const C_TEXTO := Color(0.95, 0.97, 1.0)
const C_TENUE := Color(0.62, 0.70, 0.86)
const C_JUG := Color(0.55, 0.95, 0.62)
const REFRESCO := 2.0                 # segundos entre actualizaciones
const COLUMNAS := ["#", "País", "Prov.", "Soldados", "Ingresos/día", "Puntaje"]

var main
var fuente: Font
var vf: VentanaScript
var rejilla: GridContainer
var lbl_pie: Label
var _acum := 0.0
var filas_mostradas := 0              # filas de la última actualización (para pruebas)


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	process_mode = Node.PROCESS_MODE_ALWAYS
	vf = VentanaScript.new()
	add_child(vf)
	var vp := get_viewport().get_visible_rect().size
	var tam := Vector2(560.0, minf(560.0, vp.y - 100.0))
	vf.construir(main, fuente, "RANKING · CAMPAÑA", tam, Vector2(10.0, 66.0), "", "ranking")
	vf.cerrada.connect(func(): cerrada.emit())
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0.0, 200.0)
	vf.contenido.add_child(sc)
	rejilla = GridContainer.new()
	rejilla.columns = COLUMNAS.size()
	rejilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rejilla.add_theme_constant_override("h_separation", 14)
	rejilla.add_theme_constant_override("v_separation", 4)
	sc.add_child(rejilla)
	lbl_pie = vf.lbl("", 12, C_TENUE)
	lbl_pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vf.contenido.add_child(lbl_pie)
	refrescar()


func _process(delta: float) -> void:
	_acum += delta
	if _acum >= REFRESCO:
		_acum = 0.0
		refrescar()


func _celda(texto: String, col: Color, alinear_der := false, neg := false, expandir := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col)
	if neg and "fuente_ui_neg" in main:
		l.add_theme_font_override("font", main.fuente_ui_neg)
	if alinear_der:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if expandir:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.custom_minimum_size = Vector2(120.0, 0.0)
	return l


func refrescar() -> void:
	if main == null or main.mundo == null:
		return
	for h in rejilla.get_children():
		rejilla.remove_child(h)
		h.queue_free()
	for i in COLUMNAS.size():
		rejilla.add_child(_celda(String(COLUMNAS[i]), C_ORO, i != 1, true, i == 1))
	var filas: Array = main.mundo.ranking()
	filas_mostradas = filas.size()
	var pos := 0
	for f in filas:
		pos += 1
		var es_jug: bool = bool(f["jugador"])
		var col := C_JUG if es_jug else C_TEXTO
		var nombre: String = main._nombre_vis(String(f["pais"]))
		if es_jug:
			nombre += "  (tú)"
		rejilla.add_child(_celda(str(pos), col, true))
		rejilla.add_child(_celda(nombre, col, false, es_jug, true))
		rejilla.add_child(_celda(main.hud.fmt_num(float(f["prov"])), col, true))
		rejilla.add_child(_celda(main.hud.fmt_num(float(f["tropas"])), col, true))
		rejilla.add_child(_celda(main.fmt_dinero(float(f["ingreso"]), "US$"), col, true))
		rejilla.add_child(_celda("%.1f" % float(f["puntaje"]), col, true, true))
	var sin_ia := filas.is_empty()
	lbl_pie.text = ("Nadie compite todavía: activa IAs en Debug > IA." if sin_ia else
		"Puntaje = 40 % provincias + 30 % soldados + 30 % ingresos (cada uno frente al mejor de la tabla). Solo aparecen los países con IA y el tuyo.")
