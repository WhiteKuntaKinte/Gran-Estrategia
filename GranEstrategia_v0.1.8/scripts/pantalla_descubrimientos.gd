extends Node
## PANTALLA DE DESCUBRIMIENTOS (0.1.8.43): el catálogo COMPLETO de 1.730 descubrimientos a pantalla completa, en cualquier época.
## Tecla T o el botón «Descubrimientos» de la barra de arriba. Esc vuelve atrás (ficha → hub → cierra).
##
## · HUB: arriba las tres ramas (Militar, Científica, Sociedad), cada una con su propio ambiente (`fondo_descubrimientos.gd`); debajo, las secciones de la rama
##   como tarjetas con la constelación de sus descubrimientos (`hub_descubrimientos.gd`).
## · ÁRBOL de la sección elegida (`arbol_descubrimientos.gd`): abanico circular que sube desde la raíz, círculos sin texto, globo con descripción al pasar el ratón, trazos hacia otras secciones y «T».
## · A la izquierda del árbol, la cinta de secciones de la rama para saltar de una a otra sin volver al hub.
## · Buscador por nombre en todo el catálogo, filtros por estado y por tipo; ficha del descubrimiento elegido (año, era, ruta, tipo, estado, lo que REQUIERE y lo que ABRE).
## No guarda nada en la partida: lee Descubrimientos (scripts/descubrimientos.gd). Se actualiza sola una vez por segundo mientras está abierta.
## Para ver lo que sabe tu país se usa el país que controlas; sin país (observador) se ve lo que sabe la historia en la fecha del reloj.

signal cerrada

const Tema := preload("res://scripts/tema_hud.gd")
const ArbolScript := preload("res://scripts/arbol_descubrimientos.gd")
const HubScript := preload("res://scripts/hub_descubrimientos.gd")
const FondoScript := preload("res://scripts/fondo_descubrimientos.gd")
const LoteScript := preload("res://scripts/lote_dibujo.gd")
const REFRESCO := 1.0                       # segundos entre actualizaciones
const MAX_RESULTADOS := 80                  # tope de filas en la lista de resultados de la búsqueda
const MAX_RELACIONES := 14                  # tope de filas en «Requiere» y «Abre»
const ANCHO_FICHA := 350.0
const ANCHO_CINTA := 66.0
const ALTO_BARRA := 56.0
const ALTO_PESTANAS := 46.0
const CAPA := 24                            # por encima de las ventanas del HUD y por debajo de los avisos y las fichas
const OPCIONES_ESTADO := ["Todos los estados", "Solo conocidos", "Solo disponibles", "Bloqueados y lejanos", "Aún no llegan en la historia"]

static var _ultima_seccion := 0             # al volver a abrir, vuelve a la última sección vista…
static var _ultimo_en_arbol := false        # … y al árbol si estaba en él (si no, al hub de su rama)

var main
var fuente: Font
var fuente_neg: Font
var d                                       # Descubrimientos
var capa: CanvasLayer
var raiz: Control
var fondo: FondoScript
var hub: HubScript
var arbol: ArbolScript
var cinta: Cinta
var rama_sel := 0
var sec_sel := -1
var en_arbol := false
var cuentas := PackedInt32Array()           # por sección: cuántos conoce el país mostrado (las calcula el hub)
var totales := PackedInt32Array()           # por sección: cuántos hay
var _btns_rama: Array = []
var _btn_volver: Button
var _lbl_ruta: Label
var _lbl_info: Label
var _busca: LineEdit
var _opt_estado: OptionButton
var _opt_tipo: OptionButton
var _btn_ajustar: Button
var _btn_frontera: Button
var _panel_ficha: PanelContainer
var _ficha: VBoxContainer
var _panel_res: PanelContainer
var _sc_res: ScrollContainer
var _lista_res: VBoxContainer
var _acum := 0.0
var _firma := ""
var resultados := 0                         # (pruebas) cuántas filas tiene la lista de resultados
var filas_ficha := 0                        # (pruebas) cuántos botones de relaciones tiene la ficha


## Tira vertical con las secciones de la rama como fichas con su sigla y su avance; pulsar una entra a su árbol.
class Cinta extends Control:
	signal elegida(s: int)

	const LoteC := preload("res://scripts/lote_dibujo.gd")
	var secs := PackedInt32Array()
	var siglas: Array = []
	var nombres: Array = []
	var cuentas := PackedInt32Array()
	var totales := PackedInt32Array()
	var sel := -1
	var hover := -1
	var acento := Color(1.0, 0.8, 0.3)
	var fuente: Font
	var fuente_neg: Font
	var rects: Array = []                   # [{s, rect}] de la última distribución
	var _lote := LoteC.new()

	func fijar(secciones: PackedInt32Array, sg: Array, nm: Array, c: PackedInt32Array, t: PackedInt32Array, elegida_s: int, ac: Color) -> void:
		secs = secciones
		siglas = sg
		nombres = nm
		cuentas = c
		totales = t
		sel = elegida_s
		acento = ac
		queue_redraw()

	func _distribuir() -> void:
		rects = []
		var n := secs.size()
		if n == 0:
			return
		var alto := clampf((size.y - 12.0) / float(n) - 4.0, 24.0, 46.0)
		for k in n:
			rects.append({"s": int(secs[k]), "rect": Rect2(6.0, 8.0 + float(k) * (alto + 4.0), size.x - 12.0, alto), "k": k})

	func _en(p: Vector2) -> int:
		for r in rects:
			if (r["rect"] as Rect2).has_point(p):
				return int(r["s"])
		return -1

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var h := _en((ev as InputEventMouseMotion).position)
			if h != hover:
				hover = h
				queue_redraw()
		elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var s := _en((ev as InputEventMouseButton).position)
			if s >= 0:
				elegida.emit(s)
			accept_event()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hover != -1:
			hover = -1
			queue_redraw()
		elif what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		_distribuir()
		_lote.limpiar()
		_lote.base(Vector2.ZERO, 1.0)
		_lote.degradado_h(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.62), Color(0.0, 0.0, 0.0, 0.18))
		var textos: Array = []
		for r in rects:
			var s: int = r["s"]
			var rc: Rect2 = r["rect"]
			var k: int = r["k"]
			var activa := s == sel
			var sobre := s == hover
			var base := Color(0.10, 0.11, 0.15, 0.92)
			if activa:
				base = base.lerp(acento, 0.35)
			elif sobre:
				base = base.lerp(acento, 0.16)
			_lote.rectangulo(rc, base)
			var tot := maxi(int(totales[s]) if s < totales.size() else 1, 1)
			var frac := float(cuentas[s] if s < cuentas.size() else 0) / float(tot)
			_lote.rectangulo(Rect2(rc.position.x + 3.0, rc.end.y - 6.0, rc.size.x - 6.0, 3.0), Color(0.0, 0.0, 0.0, 0.6))
			_lote.rectangulo(Rect2(rc.position.x + 3.0, rc.end.y - 6.0, (rc.size.x - 6.0) * frac, 3.0), Color(0.28, 0.82, 0.42))
			_lote.marco(rc, 2.0 if activa else 1.2, Color(1.0, 0.86, 0.35, 1.0) if activa else (acento if sobre else Color(1.0, 1.0, 1.0, 0.18)))
			textos.append([Vector2(rc.position.x + 5.0, rc.position.y + rc.size.y * 0.5 + 3.0), String(siglas[k]), rc.size.x - 8.0])
		_lote.emitir(self)
		for t in textos:
			draw_string(fuente_neg, t[0], t[1], HORIZONTAL_ALIGNMENT_CENTER, t[2], 12, Color(1.0, 0.97, 0.88))
		if hover >= 0:                                                       # globo a la derecha con el nombre completo y el avance
			var nombre := ""
			var k2 := secs.find(hover)
			if k2 >= 0:
				nombre = String(nombres[k2])
			var linea2 := "%d / %d" % [cuentas[hover], totales[hover]]
			var w := maxf(fuente_neg.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, 80.0) + 20.0
			var rr: Rect2 = Rect2()
			for q in rects:
				if int(q["s"]) == hover:
					rr = q["rect"]
			var gp := Vector2(rr.end.x + 8.0, rr.position.y)
			var g := Rect2(gp, Vector2(w, 40.0))
			_lote.rectangulo(g, Color(0.04, 0.04, 0.07, 0.96))
			_lote.marco(g, 1.4, Color(1.0, 0.86, 0.35))
			_lote.emitir(self)
			draw_string(fuente_neg, gp + Vector2(9.0, 17.0), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.97, 0.88))
			draw_string(fuente, gp + Vector2(9.0, 33.0), linea2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.82, 0.9))


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	fuente_neg = main.fuente_ui_neg if "fuente_ui_neg" in main else f
	d = main.mundo.descubrimientos
	process_mode = Node.PROCESS_MODE_ALWAYS
	capa = CanvasLayer.new()
	capa.layer = CAPA
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP                 # nada del mapa recibe clics mientras la pantalla está abierta
	raiz.theme = _tema_pantalla()
	capa.add_child(raiz)
	fondo = FondoScript.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(fondo)
	if d == null or d.n == 0:
		var l0 := _lbl("Falta el catálogo (datos/descubrimientos.json).", 16, Tema.color_rol("naranja"))
		l0.position = Vector2(40.0, 40.0)
		raiz.add_child(l0)
		return
	_armar_zona()
	_armar_barra()
	_armar_pestanas()
	_armar_ficha_y_resultados()
	hub.fijar_tid(_tid())
	cuentas = hub.cuentas
	totales = hub.totales
	var s0 := clampi(_ultima_seccion, 0, d.secciones.size() - 1)
	if _ultimo_en_arbol:
		_entrar_seccion(s0)
	else:
		_elegir_rama(int(d.secciones[s0]["rama"]))
	_actualizar_textos()


func _tid() -> int:
	var m = main.mundo
	if m.jugador != "" and m.paises.has(m.jugador):
		return int(m.paises[m.jugador].tid)
	return -1


func _lbl(texto: String, tam: int, col: Color, neg := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	if neg:
		l.add_theme_font_override("font", fuente_neg)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ─────────────────────────────────────────────────────────────
# Estilo propio de la pantalla (fondo siempre oscuro, sea cual sea el tema de la interfaz)
# ─────────────────────────────────────────────────────────────
static func _caja(fondo_c: Color, borde: Color, grosor := 1.0, radio := 6, margen := 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo_c
	sb.border_color = borde
	sb.set_border_width_all(int(ceilf(grosor)))
	sb.set_corner_radius_all(radio)
	sb.content_margin_left = margen
	sb.content_margin_right = margen
	sb.content_margin_top = margen * 0.6
	sb.content_margin_bottom = margen * 0.6
	return sb


## El tema de la interfaz, pero con botones, campos, listas y paneles oscuros y texto claro: sobre el ambiente de cada rama los colores de papel claro no se leen.
func _tema_pantalla() -> Theme:
	var t := Tema.crear_tema(fuente, fuente_neg)
	var oro := ArbolScript.T_ORO
	var txt := ArbolScript.T_TEXTO
	var blanco := Color(1.0, 1.0, 1.0)
	t.set_color("font_color", "Label", txt)
	t.set_stylebox("panel", "PanelContainer", _caja(Color(0.05, 0.06, 0.10, 0.96), Color(1.0, 1.0, 1.0, 0.18), 1.0, 8, 10.0))
	for tipo in ["Button", "OptionButton"]:
		t.set_stylebox("normal", tipo, _caja(Color(0.09, 0.10, 0.15, 0.94), Color(1.0, 1.0, 1.0, 0.22), 1.0, 5, 10.0))
		t.set_stylebox("hover", tipo, _caja(Color(0.16, 0.17, 0.25, 0.97), Color(oro.r, oro.g, oro.b, 0.8), 1.0, 5, 10.0))
		t.set_stylebox("pressed", tipo, _caja(Color(0.34, 0.24, 0.07, 0.97), oro, 1.5, 5, 10.0))
		t.set_stylebox("hover_pressed", tipo, _caja(Color(0.42, 0.30, 0.09, 0.97), oro, 1.5, 5, 10.0))
		t.set_stylebox("disabled", tipo, _caja(Color(0.07, 0.07, 0.10, 0.8), Color(1.0, 1.0, 1.0, 0.08), 1.0, 5, 10.0))
		t.set_color("font_color", tipo, txt)
		t.set_color("font_hover_color", tipo, blanco)
		t.set_color("font_pressed_color", tipo, blanco)
		t.set_color("font_hover_pressed_color", tipo, blanco)
		t.set_color("font_focus_color", tipo, txt)
		t.set_color("font_disabled_color", tipo, Color(1.0, 1.0, 1.0, 0.35))
	t.set_stylebox("pressed_mirrored", "OptionButton", _caja(Color(0.34, 0.24, 0.07, 0.97), oro, 1.5, 5, 10.0))
	t.set_stylebox("normal_mirrored", "OptionButton", _caja(Color(0.09, 0.10, 0.15, 0.94), Color(1.0, 1.0, 1.0, 0.22), 1.0, 5, 10.0))
	t.set_stylebox("normal", "LineEdit", _caja(Color(0.03, 0.04, 0.07, 0.92), Color(1.0, 1.0, 1.0, 0.28), 1.0, 5, 10.0))
	t.set_stylebox("focus", "LineEdit", _caja(Color(0.05, 0.06, 0.10, 0.97), oro, 1.5, 5, 10.0))
	t.set_color("font_color", "LineEdit", txt)
	t.set_color("font_placeholder_color", "LineEdit", Color(1.0, 1.0, 1.0, 0.45))
	t.set_color("caret_color", "LineEdit", oro)
	t.set_color("selection_color", "LineEdit", Color(oro.r, oro.g, oro.b, 0.35))
	t.set_color("clear_button_color", "LineEdit", Color(1.0, 1.0, 1.0, 0.6))
	t.set_color("clear_button_color_pressed", "LineEdit", oro)
	t.set_stylebox("panel", "PopupMenu", _caja(Color(0.06, 0.07, 0.11, 0.98), Color(oro.r, oro.g, oro.b, 0.6), 1.0, 5, 4.0))
	t.set_stylebox("hover", "PopupMenu", _caja(Color(0.30, 0.22, 0.07, 1.0), Color(0, 0, 0, 0), 0, 3, 3.0))
	t.set_color("font_color", "PopupMenu", txt)
	t.set_color("font_hover_color", "PopupMenu", blanco)
	t.set_color("font_separator_color", "PopupMenu", ArbolScript.T_TENUE)
	t.set_stylebox("separator", "HSeparator", _caja(Color(1.0, 1.0, 1.0, 0.16), Color(0, 0, 0, 0), 0, 0, 0.0))
	t.set_constant("separation", "HSeparator", 6)
	for sc in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sc, _caja(Color(1.0, 1.0, 1.0, 0.06), Color(0, 0, 0, 0), 0, 4, 0.0))
		t.set_stylebox("grabber", sc, _caja(Color(1.0, 1.0, 1.0, 0.32), Color(0, 0, 0, 0), 0, 4, 0.0))
		t.set_stylebox("grabber_highlight", sc, _caja(Color(oro.r, oro.g, oro.b, 0.7), Color(0, 0, 0, 0), 0, 4, 0.0))
		t.set_stylebox("grabber_pressed", sc, _caja(oro, Color(0, 0, 0, 0), 0, 4, 0.0))
	return t


# ─────────────────────────────────────────────────────────────
# Armado de la pantalla
# ─────────────────────────────────────────────────────────────
## El área de debajo de la barra y las pestañas: el hub y el árbol (uno a la vez) y la cinta de secciones.
func _armar_zona() -> void:
	var zona := Control.new()
	zona.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zona.offset_top = ALTO_BARRA + ALTO_PESTANAS
	zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(zona)
	hub = HubScript.new()
	hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hub.construir(d, fuente, fuente_neg)
	hub.elegida.connect(_entrar_seccion)
	zona.add_child(hub)
	arbol = ArbolScript.new()
	arbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arbol.construir(d, fuente, fuente_neg)
	arbol.margen_izq = ANCHO_CINTA + 6.0
	arbol.margen_der = ANCHO_FICHA + 24.0
	arbol.elegido.connect(_al_elegir_nodo)
	arbol.salto.connect(ir_a)
	arbol.visible = false
	zona.add_child(arbol)
	cinta = Cinta.new()
	cinta.fuente = fuente
	cinta.fuente_neg = fuente_neg
	cinta.anchor_bottom = 1.0
	cinta.offset_right = ANCHO_CINTA
	cinta.mouse_filter = Control.MOUSE_FILTER_STOP
	cinta.elegida.connect(_entrar_seccion)
	cinta.visible = false
	zona.add_child(cinta)


func _armar_barra() -> void:
	var barra := PanelContainer.new()
	barra.anchor_right = 1.0
	barra.offset_bottom = ALTO_BARRA
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.58)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.12)
	sb.border_width_bottom = 1
	sb.content_margin_left = 16.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	barra.add_theme_stylebox_override("panel", sb)
	raiz.add_child(barra)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	barra.add_child(fila)
	var tit := _lbl("DESCUBRIMIENTOS", 22, ArbolScript.T_ORO, true)
	tit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(tit)
	var relleno := Control.new()                                          # empuja el buscador y los botones a la derecha
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(relleno)
	_busca = LineEdit.new()
	_busca.placeholder_text = "Buscar descubrimiento…"
	_busca.clear_button_enabled = true
	_busca.custom_minimum_size = Vector2(230.0, 0.0)
	_busca.text_changed.connect(func(_t: String): _buscar())
	fila.add_child(_busca)
	_opt_estado = OptionButton.new()
	_opt_estado.focus_mode = Control.FOCUS_NONE
	for t in OPCIONES_ESTADO:
		_opt_estado.add_item(t)
	_opt_estado.tooltip_text = "Resalta en el árbol solo los descubrimientos de este estado.\nEl resto se ve atenuado."
	_opt_estado.item_selected.connect(func(_i: int): _filtrar())
	fila.add_child(_opt_estado)
	_opt_tipo = OptionButton.new()
	_opt_tipo.focus_mode = Control.FOCUS_NONE
	_opt_tipo.add_item("Todos los tipos")
	_opt_tipo.set_item_metadata(0, "")
	for cod in d.tipos:
		_opt_tipo.add_item(String(d.tipos[cod]))
		_opt_tipo.set_item_metadata(_opt_tipo.item_count - 1, String(cod))
	_opt_tipo.tooltip_text = "Resalta en el árbol solo este tipo (unidades, armas, edificios…)."
	_opt_tipo.item_selected.connect(func(_i: int): _filtrar())
	fila.add_child(_opt_tipo)
	_btn_frontera = Button.new()
	_btn_frontera.text = "Mi frontera"
	_btn_frontera.focus_mode = Control.FOCUS_NONE
	_btn_frontera.tooltip_text = "Mi frontera\nCentra el árbol en lo que este país puede investigar ya (los círculos dorados).\nRueda: acercar o alejar · arrastrar: mover."
	_btn_frontera.pressed.connect(func(): arbol.vista_inicial())
	fila.add_child(_btn_frontera)
	_btn_ajustar = Button.new()
	_btn_ajustar.text = "Ver todo"
	_btn_ajustar.focus_mode = Control.FOCUS_NONE
	_btn_ajustar.tooltip_text = "Ver todo\nAleja el zoom hasta encajar la sección entera en la pantalla.\nRueda: acercar o alejar · arrastrar: mover."
	_btn_ajustar.pressed.connect(func(): arbol.ajustar())
	fila.add_child(_btn_ajustar)
	var b_x := Button.new()
	b_x.text = "Cerrar"
	b_x.focus_mode = Control.FOCUS_NONE
	b_x.tooltip_text = "Cerrar\nVuelve al mapa.\nAtajo: T"
	b_x.pressed.connect(func(): cerrada.emit())
	fila.add_child(b_x)


func _armar_pestanas() -> void:
	var cont := HBoxContainer.new()
	cont.position = Vector2(14.0, ALTO_BARRA + 6.0)
	cont.add_theme_constant_override("separation", 8)
	raiz.add_child(cont)
	_btn_volver = Button.new()
	_btn_volver.text = "←  Secciones"
	_btn_volver.focus_mode = Control.FOCUS_NONE
	_btn_volver.custom_minimum_size = Vector2(0.0, 34.0)
	_btn_volver.tooltip_text = "Volver a las secciones de la rama\nAtajo: Esc"
	_btn_volver.pressed.connect(_volver)
	cont.add_child(_btn_volver)
	for r in d.ramas.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0.0, 34.0)
		b.add_theme_font_size_override("font_size", 14)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_elegir_rama.bind(r))
		cont.add_child(b)
		_btns_rama.append(b)
	_lbl_ruta = _lbl("", 15, ArbolScript.T_TEXTO, true)
	_lbl_ruta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cont.add_child(_lbl_ruta)
	_lbl_info = _lbl("", 12, ArbolScript.T_TENUE)                         # a la derecha de las pestañas
	_lbl_info.anchor_left = 1.0
	_lbl_info.anchor_right = 1.0
	_lbl_info.offset_left = -430.0
	_lbl_info.offset_right = -16.0
	_lbl_info.offset_top = ALTO_BARRA + 15.0
	_lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_info.clip_text = true
	raiz.add_child(_lbl_info)


func _armar_ficha_y_resultados() -> void:
	_panel_ficha = PanelContainer.new()
	_panel_ficha.anchor_left = 1.0
	_panel_ficha.anchor_right = 1.0
	_panel_ficha.anchor_bottom = 1.0
	_panel_ficha.offset_left = -ANCHO_FICHA - 10.0
	_panel_ficha.offset_right = -10.0
	_panel_ficha.offset_top = ALTO_BARRA + ALTO_PESTANAS + 6.0
	_panel_ficha.offset_bottom = -10.0
	_panel_ficha.add_theme_stylebox_override("panel", _caja(Color(0.05, 0.06, 0.10, 0.96), Color(ArbolScript.T_ORO.r, ArbolScript.T_ORO.g, ArbolScript.T_ORO.b, 0.75), 1.5, 8, 12.0))
	_panel_ficha.visible = false
	raiz.add_child(_panel_ficha)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_ficha.add_child(sc)
	_ficha = VBoxContainer.new()
	_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ficha.add_theme_constant_override("separation", 4)
	sc.add_child(_ficha)
	_panel_res = PanelContainer.new()
	_panel_res.anchor_left = 1.0
	_panel_res.anchor_right = 1.0
	_panel_res.offset_left = -400.0
	_panel_res.offset_right = -14.0
	_panel_res.offset_top = ALTO_BARRA + 2.0
	_panel_res.offset_bottom = ALTO_BARRA + 430.0
	_panel_res.add_theme_stylebox_override("panel", _caja(Color(0.05, 0.06, 0.10, 0.97), Color(ArbolScript.T_ORO.r, ArbolScript.T_ORO.g, ArbolScript.T_ORO.b, 0.75), 1.5, 8, 8.0))
	_panel_res.visible = false
	raiz.add_child(_panel_res)
	_sc_res = ScrollContainer.new()
	_sc_res.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel_res.add_child(_sc_res)
	_lista_res = VBoxContainer.new()
	_lista_res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_res.add_theme_constant_override("separation", 2)
	_sc_res.add_child(_lista_res)


static func _miles(v: int) -> String:
	var s := str(v)
	var r := ""
	var k := 0
	for j in range(s.length() - 1, -1, -1):
		if k > 0 and k % 3 == 0:
			r = "." + r
		r = s[j] + r
		k += 1
	return r


# ─────────────────────────────────────────────────────────────
# Navegación: hub ⇄ árbol
# ─────────────────────────────────────────────────────────────
## Secciones de una rama, en orden.
func secciones_de(r: int) -> PackedInt32Array:
	var res := PackedInt32Array()
	for s in d.secciones.size():
		if int(d.secciones[s]["rama"]) == r:
			res.append(s)
	return res


func _marcar_rama(r: int) -> void:
	rama_sel = r
	for b in _btns_rama.size():
		(_btns_rama[b] as Button).set_pressed_no_signal(b == r)


## Muestra las secciones de la rama `r` (el hub).
func _elegir_rama(r: int) -> void:
	_marcar_rama(r)
	en_arbol = false
	_ultimo_en_arbol = false
	hub.fijar_rama(r)
	cuentas = hub.cuentas
	totales = hub.totales
	fondo.fijar(r, 0)
	hub.visible = true
	arbol.visible = false
	cinta.visible = false
	_panel_ficha.visible = false
	_btn_volver.visible = false
	_btn_ajustar.visible = false
	_btn_frontera.visible = false
	_lbl_ruta.text = "  %s: elige una sección" % String(d.ramas[r]["nombre"])
	_actualizar_textos()


## Entra al árbol de la sección `s` (de cualquier rama).
func _entrar_seccion(s: int) -> void:
	if s < 0 or s >= d.secciones.size():
		return
	var r: int = int(d.secciones[s]["rama"])
	if r != rama_sel or hub._secs.is_empty():
		_marcar_rama(r)
		hub.fijar_rama(r)
		cuentas = hub.cuentas
		totales = hub.totales
	sec_sel = s
	_ultima_seccion = s
	_ultimo_en_arbol = true
	en_arbol = true
	var secs := secciones_de(r)
	var k := secs.find(s)
	fondo.fijar(r, maxi(k, 0))
	var pal: Color = FondoScript.PALETAS[r][2]
	var siglas: Array = []
	var nombres: Array = []
	for q in secs:
		siglas.append(String(d.secciones[q]["cod"]))
		nombres.append(String(d.secciones[q]["nombre"]))
	cinta.fijar(secs, siglas, nombres, cuentas, totales, s, fondo.acento())
	arbol.fijar_tid(_tid())
	arbol.fijar_seccion(s, false)
	arbol.vista_inicial()
	hub.visible = false
	arbol.visible = true
	cinta.visible = true
	_btn_volver.visible = true
	_btn_ajustar.visible = true
	_btn_frontera.visible = true
	_lbl_ruta.text = "  %s  ›  %s" % [String(d.ramas[r]["nombre"]), String(d.secciones[s]["nombre"])]
	_cerrar_ficha()
	_actualizar_textos()
	arbol.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(arbol, "modulate:a", 1.0, 0.25)


func _volver() -> void:
	if en_arbol:
		_elegir_rama(rama_sel)


## Lleva la pantalla a un descubrimiento (cambia de rama y sección si hace falta), lo centra en el árbol y muestra su ficha.
func ir_a(i: int) -> void:
	if i < 0 or i >= d.n:
		return
	var s: int = int(d.seccion[i])
	if not en_arbol or s != sec_sel:
		_entrar_seccion(s)
	arbol.elegir(i, true)
	_armar_ficha(i)


func _cerrar_ficha() -> void:
	arbol.sel = -1
	arbol._actualizar_foco()
	arbol.queue_redraw()
	_panel_ficha.visible = false


func _al_elegir_nodo(i: int) -> void:
	if i < 0:
		_panel_ficha.visible = false
	else:
		_armar_ficha(i)


## Esc: primero cierra lo que está encima (resultados, ficha), luego sube un nivel (árbol → hub) y por último cierra la pantalla.
func _input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo or ev.keycode != KEY_ESCAPE:
		return
	if raiz == null or not is_instance_valid(raiz):
		return
	get_viewport().set_input_as_handled()
	if _panel_res.visible:
		_busca.text = ""
		_buscar()
	elif _panel_ficha.visible:
		_cerrar_ficha()
	elif en_arbol:
		_volver()
	else:
		cerrada.emit()


# ─────────────────────────────────────────────────────────────
# Textos, filtros y búsqueda
# ─────────────────────────────────────────────────────────────
## Los textos que dependen de las cuentas: botones de rama y la línea de resumen.
func _actualizar_textos() -> void:
	var tid := _tid()
	var por_rama := PackedInt32Array()
	var tot_rama := PackedInt32Array()
	por_rama.resize(d.ramas.size())
	tot_rama.resize(d.ramas.size())
	for i in d.n:
		var r: int = int(d.secciones[int(d.seccion[i])]["rama"])
		tot_rama[r] += 1
		if d.conoce(tid, i):
			por_rama[r] += 1
	for r2 in d.ramas.size():
		(_btns_rama[r2] as Button).text = "%s  %d / %d" % [String(d.ramas[r2]["nombre"]), por_rama[r2], tot_rama[r2]]
	var t := "Año %s · la historia conoce %s de %s" % [d.anio_texto(main.reloj.anio), _miles(d.cuenta_f), _miles(d.n)]
	if tid >= 0:
		t += " · %s conoce %s" % [main.mundo.jugador, _miles(d.cantidad(tid))]
	else:
		t += " · sin país"
	_lbl_info.text = t


func _filtrar() -> void:
	var tipo := String(_opt_tipo.get_item_metadata(_opt_tipo.selected))
	arbol.fijar_filtros(_opt_estado.selected, tipo)


func _color_estado(e: int) -> Color:
	match e:
		ArbolScript.E_CONOCIDO:
			return ArbolScript.C_CONOCIDO
		ArbolScript.E_DISPONIBLE:
			return ArbolScript.C_DISPONIBLE
		ArbolScript.E_LEJANO:
			return ArbolScript.C_GRIS_BORDE
	return Color(0.66, 0.68, 0.78)


func _buscar() -> void:
	var q := _busca.text.strip_edges()
	for h in _lista_res.get_children():
		_lista_res.remove_child(h)
		h.queue_free()
	resultados = 0
	if q.length() < 2:
		_panel_res.visible = false
		return
	var tid := _tid()
	var hallados: PackedInt32Array = d.buscar(q, MAX_RESULTADOS)
	arbol.tid = tid
	_panel_res.visible = true
	var cab := _lbl("RESULTADOS: %d%s" % [hallados.size(), "+" if hallados.size() >= MAX_RESULTADOS else ""], 11, ArbolScript.T_ORO, true)
	_lista_res.add_child(cab)
	for i in hallados:
		var e: int = arbol.estado_nodo(i)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text = "%s %s · %s" % ["✓" if d.conoce(tid, i) else "·", d.anio_texto(int(d.anio[i])), String(d.nombre[i])]
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", _color_estado(e))
		b.add_theme_color_override("font_hover_color", _color_estado(e).lightened(0.25))
		b.tooltip_text = "%s\n%s › %s" % [String(d.nombre[i]), String(d.ramas[int(d.secciones[int(d.seccion[i])]["rama"])]["nombre"]), String(d.secciones[int(d.seccion[i])]["nombre"])]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_ir_desde_busqueda.bind(i))
		_lista_res.add_child(b)
		resultados += 1


func _ir_desde_busqueda(i: int) -> void:
	_busca.text = ""
	_buscar()
	ir_a(i)


# ─────────────────────────────────────────────────────────────
# Ficha
# ─────────────────────────────────────────────────────────────
func _armar_ficha(i: int) -> void:
	for h in _ficha.get_children():
		_ficha.remove_child(h)
		h.queue_free()
	filas_ficha = 0
	if i < 0:
		_panel_ficha.visible = false
		return
	_panel_ficha.visible = true
	var tid := _tid()
	var e: int = arbol.estado_nodo(i)
	var t := _lbl(String(d.nombre[i]), 18, ArbolScript.T_ORO, true)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	_ficha.add_child(t)
	var est := _lbl(_texto_estado(i, e, tid), 13, _color_estado(e))
	est.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha.add_child(est)
	var sec: int = int(d.seccion[i])
	var ruta := "%s › %s" % [String(d.ramas[int(d.secciones[sec]["rama"])]["nombre"]), String(d.secciones[sec]["nombre"])]
	if int(d.sub[i]) >= 0:
		ruta += " › " + String(d.subsecciones[int(d.sub[i])])
	var datos := "Año %s (%s)\nEra: %s\n%s\nTipo: %s" % [d.anio_texto(int(d.anio[i])), _origen_anio(String(d.origen[i])), String(d.eras[int(d.era[i])]["nombre"]),
		ruta, String(d.tipos.get(String(d.tipo[i]), d.tipo[i]))]
	if int(d.tema[i]) >= 0:
		datos += "\nTema: " + String(d.temas[int(d.tema[i])]["nombre"])
	var ld := _lbl(datos, 12, ArbolScript.T_TEXTO)
	ld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha.add_child(ld)
	var desc_sec := String(d.secciones[sec].get("desc", ""))
	if desc_sec != "":
		var lds := _lbl("Esta sección: " + desc_sec, 11, ArbolScript.T_TENUE)
		lds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ficha.add_child(lds)
	if String(d.tipo[i]) == "B":
		var lb := _lbl("Es un edificio: se construye desde la ventana Construir (tecla B).", 11, ArbolScript.T_NOTA)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ficha.add_child(lb)
	_ficha.add_child(HSeparator.new())
	_ficha.add_child(_lbl("REQUIERE", 11, ArbolScript.T_ORO, true))
	var hay := false
	for r in d.req[i]:
		_ficha.add_child(_fila_relacion(int(r), tid, ""))
		hay = true
	for g in d.req_o[i]:
		if g.size() == 1:
			_ficha.add_child(_fila_relacion(int(g[0]), tid, ""))
		else:
			_ficha.add_child(_lbl("Basta uno de:", 11, ArbolScript.T_NOTA))
			for r2 in g:
				_ficha.add_child(_fila_relacion(int(r2), tid, "   "))
		hay = true
	if not hay:
		_ficha.add_child(_lbl("Nada: es una raíz del árbol.", 12, ArbolScript.T_TENUE))
	_ficha.add_child(HSeparator.new())
	var abre: PackedInt32Array = d.dependientes[i]
	_ficha.add_child(_lbl("ABRE (%d)" % abre.size(), 11, ArbolScript.T_ORO, true))
	if abre.is_empty():
		_ficha.add_child(_lbl("Nada todavía: camino sin salida.", 12, ArbolScript.T_TENUE))
	for k in mini(abre.size(), MAX_RELACIONES):
		_ficha.add_child(_fila_relacion(int(abre[k]), tid, ""))
	if abre.size() > MAX_RELACIONES:
		_ficha.add_child(_lbl("…y %d más." % (abre.size() - MAX_RELACIONES), 12, ArbolScript.T_TENUE))


func _texto_estado(i: int, e: int, tid: int) -> String:
	match e:
		ArbolScript.E_CONOCIDO:
			return "Conocido"
		ArbolScript.E_DISPONIBLE:
			return "Disponible: ya tiene todos sus prerrequisitos."
		ArbolScript.E_LEJANO:
			return "Aún lejano: su año (%s) todavía no llega y faltan prerrequisitos." % d.anio_texto(int(d.anio[i]))
	var faltan := PackedStringArray()
	for r in d.req[i]:
		if not d.conoce(tid, r):
			faltan.append(String(d.nombre[r]))
	for g in d.req_o[i]:
		var alguno := false
		for r2 in g:
			if d.conoce(tid, r2):
				alguno = true
				break
		if not alguno:
			faltan.append("uno de %d alternativas" % g.size())
	return "Bloqueado: le falta %s." % ", ".join(faltan)


## Una fila de la ficha: el descubrimiento `r` con su estado (✓ lo conoce, · no); al pulsarla la pantalla va a él.
func _fila_relacion(r: int, tid: int, sangria: String) -> Button:
	var e: int = arbol.estado_nodo(r)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text = "%s%s %s" % [sangria, "✓" if d.conoce(tid, r) else "·", String(d.nombre[r])]
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", _color_estado(e))
	b.add_theme_color_override("font_hover_color", _color_estado(e).lightened(0.25))
	var sr: int = int(d.seccion[r])
	b.tooltip_text = "%s\n%s · %s\n%s › %s\nClic: ir a este descubrimiento" % [String(d.nombre[r]), d.anio_texto(int(d.anio[r])), String(ArbolScript.NOMBRE_ESTADO[e]),
		String(d.ramas[int(d.secciones[sr]["rama"])]["nombre"]), String(d.secciones[sr]["nombre"])]
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(ir_a.bind(r))
	filas_ficha += 1
	return b


func _origen_anio(o: String) -> String:
	match o:
		"h":
			return "histórico"
		"a":
			return "ajustado a sus prerrequisitos"
		"x":
			return "hipotético"
	return o


# ─────────────────────────────────────────────────────────────
# Actualización
# ─────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_acum += delta
	if _acum >= REFRESCO:
		_acum = 0.0
		refrescar()


## Si cambió lo que sabe el país (o la fecha), se ponen al día contadores, hub, árbol y ficha. Si no cambió nada, no hace nada.
func refrescar() -> void:
	if d == null or arbol == null:
		return
	var tid := _tid()
	var firma := "%d|%d|%d|%d" % [tid, d.anio_actual, d.cuenta_f, d.cantidad(tid)]
	if firma == _firma:
		return
	_firma = firma
	hub.fijar_tid(tid)
	cuentas = hub.cuentas
	totales = hub.totales
	arbol.fijar_tid(tid)
	if en_arbol:
		var secs := secciones_de(rama_sel)
		var siglas: Array = []
		var nombres: Array = []
		for q in secs:
			siglas.append(String(d.secciones[q]["cod"]))
			nombres.append(String(d.secciones[q]["nombre"]))
		cinta.fijar(secs, siglas, nombres, cuentas, totales, sec_sel, fondo.acento())
		if _panel_ficha.visible and arbol.sel >= 0:
			_armar_ficha(arbol.sel)
	_actualizar_textos()


func aplicar_tema() -> void:
	if raiz == null:
		return
	raiz.theme = _tema_pantalla()
	if arbol != null:
		arbol.queue_redraw()
		if _panel_ficha.visible:
			_armar_ficha(arbol.sel)
		if _panel_res.visible:
			_buscar()
