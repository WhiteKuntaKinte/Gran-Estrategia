extends Node
## PANTALLA DE COMBATE (0.1.8.51): el tablero de la batalla. Tú eliges la FORMACIÓN, colocas tus tropas en la cuadrícula de 4 columnas × 5 filas de tu lado, ves la del enemigo
## y das la orden; la batalla se resuelve ronda a ronda con `Combate.simular` (scripts/combate.gd) y se anima en el tablero. Al terminar, el resultado se aplica a las tropas del
## mapa (`Guerra.aplicar_tactico`). Dos modos:
##   · "guerra": una batalla real (ofrecida por `Guerra._espera_tactica` al jugador). Una sola vez: no se repite. Se puede dejar que se resuelva sola.
##   · "prueba": un tablero de práctica (Debug > Combate): eliges tu país, el rival, el terreno y los soldados, y puedes repetir con otra suerte.
## Mientras está abierta el mapa de atrás se oculta (como en Descubrimientos) y el reloj queda en pausa (lo hace MapaPrincipal).

signal cerrada(aplicado: bool)

const Tema := preload("res://scripts/tema_hud.gd")
const CAPA := 26                            # por encima de la pantalla de Descubrimientos (24) y por debajo de los pop-ups (40)
const VELOCIDADES := [1.0, 2.0, 4.0]
const SEGUNDOS_RONDA := 0.75                # a velocidad 1, lo que dura cada ronda en pantalla
const TINTE_TERRENO := {
	"llano": Color(0.36, 0.42, 0.24), "bosque": Color(0.16, 0.31, 0.18), "selva": Color(0.09, 0.29, 0.15), "colina": Color(0.45, 0.40, 0.24),
	"montana": Color(0.38, 0.38, 0.41), "desierto": Color(0.66, 0.55, 0.34), "pantano": Color(0.24, 0.33, 0.30), "urbano": Color(0.37, 0.37, 0.40),
	"nieve": Color(0.78, 0.84, 0.90)}
const C_ORO := Color(0.96, 0.80, 0.40)       # texto sobre el fondo oscuro de la pantalla (los paneles de pergamino usan los colores del tema)
const C_CLARO := Color(0.90, 0.88, 0.80)
const C_TENUE := Color(0.62, 0.66, 0.76)
const COL_ATAC := Color(0.45, 0.66, 1.0)
const COL_DEF := Color(1.0, 0.50, 0.45)


## El tablero: 8 × 5 casillas. Dibuja el terreno, los dos bandos, los ataques de la ronda y la casilla bajo el ratón.
class Tablero extends Control:
	signal pulsada(x: int, y: int, boton: int)
	signal sobre(x: int, y: int)
	var cmb                                   # Combate (para colores y nombres de clase)
	var bloques: Array = []                   # [{x, y, arma, n, n0, mor, huyo, lado}] en el orden de `simular` (atacante primero)
	var ataques: Array = []                   # [[bloque, blanco, bajas]] de la ronda que se muestra
	var tinte := Color(0.36, 0.42, 0.24)
	var propio := 0                           # lado que controla el jugador (0 = izquierda)
	var editable := false
	var fuente: Font
	var fmt: Callable
	var _celda := Vector2i(-1, -1)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func _casilla(p: Vector2) -> Vector2i:
		return Vector2i(clampi(int(p.x / maxf(size.x / 8.0, 1.0)), 0, 7), clampi(int(p.y / maxf(size.y / 5.0, 1.0)), 0, 4))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			var c := _casilla(ev.position)
			if c != _celda:
				_celda = c
				sobre.emit(c.x, c.y)
				queue_redraw()
		elif ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_LEFT or ev.button_index == MOUSE_BUTTON_RIGHT):
			var c2 := _casilla(ev.position)
			pulsada.emit(c2.x, c2.y, ev.button_index)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_celda = Vector2i(-1, -1)
			queue_redraw()

	func _draw() -> void:
		var cw := size.x / 8.0
		var ch := size.y / 5.0
		draw_rect(Rect2(Vector2.ZERO, size), tinte.darkened(0.55))
		for y in 5:
			for x in 8:
				var t := 0.035 if (x + y) % 2 == 0 else 0.0
				draw_rect(Rect2(x * cw + 1.0, y * ch + 1.0, cw - 2.0, ch - 2.0), Color(tinte.r + t, tinte.g + t, tinte.b + t))
		draw_rect(Rect2(0.0, 0.0, 4.0 * cw, size.y), Color(COL_ATAC.r, COL_ATAC.g, COL_ATAC.b, 0.08))
		draw_rect(Rect2(4.0 * cw, 0.0, 4.0 * cw, size.y), Color(COL_DEF.r, COL_DEF.g, COL_DEF.b, 0.08))
		draw_line(Vector2(4.0 * cw, 0.0), Vector2(4.0 * cw, size.y), Color(1.0, 1.0, 1.0, 0.28), 2.0)
		if editable:
			draw_rect(Rect2(float(propio) * 4.0 * cw + 2.0, 2.0, 4.0 * cw - 4.0, size.y - 4.0), Color(1.0, 0.85, 0.3, 0.55), false, 2.0)
		if _celda.x >= 0:
			draw_rect(Rect2(float(_celda.x) * cw + 1.0, float(_celda.y) * ch + 1.0, cw - 2.0, ch - 2.0), Color(1.0, 1.0, 1.0, 0.10))
		for a in ataques:
			var b: int = int(a[0])
			var t: int = int(a[1])
			if b < 0 or t < 0 or b >= bloques.size() or t >= bloques.size():
				continue
			var bb: Dictionary = bloques[b]
			var tb: Dictionary = bloques[t]
			var col: Color = COL_ATAC if int(bb["lado"]) == 0 else COL_DEF
			var p0 := Vector2((float(bb["x"]) + 0.5) * cw, (float(bb["y"]) + 0.5) * ch)
			var p1 := Vector2((float(tb["x"]) + 0.5) * cw, (float(tb["y"]) + 0.5) * ch)
			draw_line(p0, p1, Color(col.r, col.g, col.b, 0.55), clampf(float(a[2]) / 120.0, 1.5, 5.0), true)
		for b in bloques:
			if bool(b["huyo"]):
				_dibujar_fugitivo(b, cw, ch)
		for b in bloques:
			if not bool(b["huyo"]):
				_dibujar_bloque(b, cw, ch)

	## Un bloque que huyó: una sombra pequeña hacia su retaguardia (no tapa a quien ocupe su casilla).
	func _dibujar_fugitivo(b: Dictionary, cw: float, ch: float) -> void:
		var arma: Dictionary = cmb.armas[int(b["arma"])]
		var col := Color.html(String(arma["color"]))
		var corr := -0.28 * cw if int(b["lado"]) == 0 else 0.28 * cw
		var r := Rect2(float(b["x"]) * cw + cw * 0.22 + corr, float(b["y"]) * ch + ch * 0.55, cw * 0.56, ch * 0.30)
		draw_rect(r, Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.45))
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
		if fuente != null:
			draw_string(fuente, Vector2(r.position.x, r.position.y + r.size.y * 0.72), "huye", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color(1.0, 1.0, 1.0, 0.7))

	func _dibujar_bloque(b: Dictionary, cw: float, ch: float) -> void:
		var n: float = float(b["n"])
		var n0: float = maxf(float(b["n0"]), 1.0)
		if n <= 0.5:
			return
		var arma: Dictionary = cmb.armas[int(b["arma"])]
		var col := Color.html(String(arma["color"]))
		var lado_col: Color = COL_ATAC if int(b["lado"]) == 0 else COL_DEF
		var alfa := 1.0
		var r := Rect2(float(b["x"]) * cw + 5.0, float(b["y"]) * ch + 5.0, cw - 10.0, ch - 10.0)
		draw_rect(r, Color(col.r * 0.30, col.g * 0.30, col.b * 0.30, alfa))
		var frac := clampf(n / n0, 0.0, 1.0)
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - frac), r.size.x, r.size.y * frac), Color(col.r * 0.72, col.g * 0.72, col.b * 0.72, alfa))
		draw_rect(r, Color(lado_col.r, lado_col.g, lado_col.b, alfa), false, 2.0)
		if fuente != null:
			var tam := int(clampf(r.size.y * 0.36, 12.0, 30.0))
			draw_string(fuente, Vector2(r.position.x, r.position.y + r.size.y * 0.50), String(arma["cod"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, tam, Color(1.0, 1.0, 1.0, alfa))
			draw_string(fuente, Vector2(r.position.x, r.position.y + r.size.y * 0.76), String(fmt.call(n)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(clampf(r.size.y * 0.19, 10.0, 15.0)), Color(1.0, 1.0, 1.0, alfa))
		var mf := clampf(float(b["mor"]) / 70.0, 0.0, 1.0)
		var bm := Rect2(r.position.x + 4.0, r.end.y - 7.0, r.size.x - 8.0, 3.0)
		draw_rect(bm, Color(0.0, 0.0, 0.0, 0.55 * alfa))
		draw_rect(Rect2(bm.position, Vector2(bm.size.x * mf, bm.size.y)), Color(1.0 - mf, 0.35 + 0.55 * mf, 0.25, alfa))


var main
var fuente: Font
var cmb                                     # Combate
var guerra                                  # Guerra (null en el modo de prueba)
var capa: CanvasLayer
var raiz: Control
var tablero: Tablero
var abierto := false
var ctx: Dictionary = {}
var lado := 0                               # lado del jugador: 0 = atacante (izquierda), 1 = defensor (derecha)
var cap: Array = [{}, {}]                   # capacidad militar de cada bando
var form: Array = [0, 0]                    # formación elegida de cada bando
var cuadro_jug: Array = []                  # [[fila, columna, clase]] de tu cuadro (editable)
var base_bloques: Array = []                # bloques desplegados al empezar la batalla (atacante primero)
var _na := 0                                # cuántos de ellos son del atacante
var res: Dictionary = {}
var fase := "despliegue"                    # "despliegue" | "batalla" | "fin"
var aplicado := false
var semilla := 1
var _r_vista := 0                           # ronda que se está mostrando
var _t_ronda := 0.0
var _vel_i := 0
var _clase_sel := -1                        # clase con la que se pinta (−1 = borrar)
var _n_prev := [0.0, 0.0]

# interfaz
var _t_titulo: Label
var _t_terreno: Label
var _t_yo: Label
var _t_form_desc: Label
var _sel_form: OptionButton
var _form_ids: Array = []                   # índice del OptionButton -> índice de formación
var _caja_clases: HFlowContainer
var _btn_clase: Dictionary = {}             # clase -> Button
var _t_sobre: Label
var _t_enemigo: Label
var _t_enem_desc: Label
var _registro: RichTextLabel
var _btn_comenzar: Button
var _btns_vel: Array = []
var _btn_saltar: Button
var _t_ronda_lbl: Label
var _panel_res: PanelContainer
var _t_res_tit: Label
var _t_res_txt: Label
var _btn_aplicar: Button
var _btn_otra: Button
var _btn_ver_res: Button
var _btn_sola: Button
var _flag_a: TextureRect
var _flag_d: TextureRect
# modo de prueba
var _fila_prueba: HBoxContainer
var _sel_pais_a: OptionButton
var _sel_pais_d: OptionButton
var _sel_terreno: OptionButton
var _campo_sold: SpinBox
var _paises_prueba: Array = []              # nombres de país en el mismo orden que los OptionButton


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	process_mode = Node.PROCESS_MODE_ALWAYS
	capa = CanvasLayer.new()
	capa.layer = CAPA
	capa.visible = false
	add_child(capa)
	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.theme = Tema.crear_tema(fuente, main.fuente_ui_neg if "fuente_ui_neg" in main else fuente)
	capa.add_child(raiz)
	var fondo := ColorRect.new()
	fondo.color = Color(0.04, 0.05, 0.08)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(fondo)
	var margen := MarginContainer.new()
	margen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado_m in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado_m, 14)
	raiz.add_child(margen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margen.add_child(col)
	# ── barra de arriba ──
	var arriba := HBoxContainer.new()
	arriba.add_theme_constant_override("separation", 12)
	col.add_child(arriba)
	_flag_a = _bandera()
	arriba.add_child(_flag_a)
	_t_titulo = _lbl("", 22, C_ORO, true)
	_t_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arriba.add_child(_t_titulo)
	_flag_d = _bandera()
	arriba.add_child(_flag_d)
	var b_cerrar := _boton("Cerrar", func(): _cerrar_pedido())
	b_cerrar.size_flags_horizontal = Control.SIZE_SHRINK_END
	b_cerrar.custom_minimum_size = Vector2(96.0, 36.0)
	arriba.add_child(b_cerrar)
	_t_terreno = _lbl("", 14, C_TENUE)
	col.add_child(_t_terreno)
	_fila_prueba = HBoxContainer.new()
	_fila_prueba.add_theme_constant_override("separation", 8)
	col.add_child(_fila_prueba)
	# ── centro ──
	var centro := HBoxContainer.new()
	centro.add_theme_constant_override("separation", 12)
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(centro)
	centro.add_child(_panel_izq())
	tablero = Tablero.new()
	tablero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tablero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tablero.custom_minimum_size = Vector2(560.0, 340.0)
	tablero.fuente = fuente
	tablero.pulsada.connect(_al_pulsar_casilla)
	tablero.sobre.connect(_al_pasar_casilla)
	centro.add_child(tablero)
	centro.add_child(_panel_der())
	# ── barra de abajo ──
	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 10)
	col.add_child(abajo)
	_btn_comenzar = _boton("¡COMENZAR LA BATALLA!", func(): _comenzar(), Tema.OK)
	_btn_comenzar.custom_minimum_size = Vector2(260.0, 42.0)
	abajo.add_child(_btn_comenzar)
	_btn_sola = _boton("Que se resuelva sola", func(): _dejar_sola())
	_btn_sola.custom_minimum_size = Vector2(200.0, 42.0)
	abajo.add_child(_btn_sola)
	for i in VELOCIDADES.size():
		var bv := _boton("×%d" % int(VELOCIDADES[i]), func(): _poner_vel(i))
		bv.custom_minimum_size = Vector2(54.0, 42.0)
		bv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		abajo.add_child(bv)
		_btns_vel.append(bv)
	_btn_saltar = _boton("Saltar al final", func(): _saltar())
	_btn_saltar.custom_minimum_size = Vector2(150.0, 42.0)
	abajo.add_child(_btn_saltar)
	_btn_ver_res = _boton("Ver el resultado", func(): _ver_tablero(false))
	_btn_ver_res.custom_minimum_size = Vector2(170.0, 42.0)
	_btn_ver_res.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_btn_ver_res.visible = false
	abajo.add_child(_btn_ver_res)
	_t_ronda_lbl = _lbl("", 15, C_CLARO)
	_t_ronda_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	abajo.add_child(_t_ronda_lbl)
	# ── resultado (encima de todo) ──
	var centrado := CenterContainer.new()
	centrado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centrado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(centrado)
	_panel_res = PanelContainer.new()
	_panel_res.custom_minimum_size = Vector2(520.0, 0.0)
	_panel_res.add_theme_stylebox_override("panel", Tema.panel(16.0))
	_panel_res.visible = false
	centrado.add_child(_panel_res)
	var cr := VBoxContainer.new()
	cr.add_theme_constant_override("separation", 10)
	_panel_res.add_child(cr)
	_t_res_tit = _lbl("", 28, Tema.ORO, true)
	_t_res_tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr.add_child(_t_res_tit)
	_t_res_txt = _lbl("", 15, Tema.TEXTO)
	cr.add_child(_t_res_txt)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 10)
	cr.add_child(br)
	_btn_aplicar = _boton("APLICAR EL RESULTADO", func(): _aplicar(), Tema.OK)
	br.add_child(_btn_aplicar)
	_btn_otra = _boton("Otra batalla", func(): _otra())
	br.add_child(_btn_otra)
	br.add_child(_boton("Ver el tablero", func(): _ver_tablero(true)))
	br.add_child(_boton("Cerrar", func(): cerrar(aplicado)))


func _panel_izq() -> Control:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(350.0, 0.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(p)
	p.add_theme_stylebox_override("panel", Tema.panel(12.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_lbl("TU EJÉRCITO", 15, Tema.ORO, true))
	_t_yo = _lbl("", 13, Tema.TEXTO)
	v.add_child(_t_yo)
	v.add_child(HSeparator.new())
	v.add_child(_lbl("Formación", 14, Tema.TENUE))
	_sel_form = OptionButton.new()
	_sel_form.focus_mode = Control.FOCUS_NONE
	_sel_form.item_selected.connect(_al_elegir_formacion)
	v.add_child(_sel_form)
	_t_form_desc = _lbl("", 12, Tema.TEXTO)
	v.add_child(_t_form_desc)
	v.add_child(_boton("Sugerir la mejor contra el enemigo", func(): _sugerir(), Tema.ORO))
	v.add_child(HSeparator.new())
	v.add_child(_lbl("Colocar tropas: elige una clase y pulsa casillas de tu lado (clic derecho borra)", 12, Tema.TENUE))
	_caja_clases = HFlowContainer.new()
	_caja_clases.add_theme_constant_override("h_separation", 4)
	_caja_clases.add_theme_constant_override("v_separation", 4)
	v.add_child(_caja_clases)
	v.add_child(_boton("Volver al cuadro de la formación", func(): _restablecer_cuadro()))
	_t_sobre = _lbl("", 12, Tema.TEXTO)
	_t_sobre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_t_sobre)
	return sc


func _panel_der() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(320.0, 0.0)
	p.add_theme_stylebox_override("panel", Tema.panel(12.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_lbl("EL ENEMIGO", 15, Tema.MAL, true))
	_t_enemigo = _lbl("", 13, Tema.TEXTO)
	v.add_child(_t_enemigo)
	_t_enem_desc = _lbl("", 12, Tema.TENUE)
	v.add_child(_t_enem_desc)
	v.add_child(HSeparator.new())
	v.add_child(_lbl("Registro de la batalla", 14, Tema.TENUE))
	_registro = RichTextLabel.new()
	_registro.bbcode_enabled = true
	_registro.scroll_following = true
	_registro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_registro.add_theme_font_size_override("normal_font_size", 12)
	v.add_child(_registro)
	return p


# ───────────── utilidades de interfaz ─────────────
func _lbl(t: String, tam: int, col: Color, neg := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	if neg and "fuente_ui_neg" in main:
		l.add_theme_font_override("font", main.fuente_ui_neg)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _boton(t: String, accion: Callable, col := Tema.TEXTO) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 34.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(accion)
	return b


func _bandera() -> TextureRect:
	var b := TextureRect.new()
	b.custom_minimum_size = Vector2(72.0, 48.0)
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return b


func _fmt(v: float) -> String:
	if v >= 10000.0:
		return "%dk" % int(roundf(v / 1000.0))
	if v >= 1000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(roundf(v)))


func _nombre(l: int) -> String:
	return String(ctx["nombres"][l])


func _input(ev: InputEvent) -> void:
	if not abierto or not (ev is InputEventKey) or not ev.pressed:
		return
	if ev.keycode == KEY_ESCAPE:
		if fase == "batalla":
			_saltar()
		elif ctx.get("modo", "") == "prueba" or fase == "fin":
			cerrar(aplicado)
		get_viewport().set_input_as_handled()
	elif ev.keycode == KEY_SPACE or (ev.keycode >= KEY_1 and ev.keycode <= KEY_6) or ev.keycode == KEY_V or ev.keycode == KEY_T or ev.keycode == KEY_BACKSPACE or ev.keycode == KEY_B:
		get_viewport().set_input_as_handled()


# ───────────── abrir / cerrar ─────────────
## `c`: {"modo": "guerra" | "prueba", "bid" (guerra), "nombres": [atacante, defensor], "banderas": [clave, clave], "cap": [cap_a, cap_d], "sold": [a, d], "cal": [a, d],
##       "terreno": índice, "local": [bool, bool], "bono_def": float, "lado": 0 | 1, "titulo": texto, "semilla": int}
func abrir(c: Dictionary, armar_fila := true) -> void:
	cmb = main.mundo.combate
	guerra = main.mundo.guerra
	ctx = c
	lado = int(c["lado"])
	cap = [c["cap"][0], c["cap"][1]]
	semilla = int(c.get("semilla", 1))
	aplicado = false
	_clase_sel = -1
	var prueba: bool = String(c["modo"]) == "prueba"
	_fila_prueba.visible = prueba
	_btn_sola.visible = not prueba
	_btn_otra.visible = prueba
	_btn_aplicar.visible = not prueba
	_t_titulo.text = String(c["titulo"])
	_flag_a.texture = main.bandera_hd(String(c["banderas"][0]))
	_flag_d.texture = main.bandera_hd(String(c["banderas"][1]))
	_registro.clear()
	_panel_res.visible = false
	_btn_ver_res.visible = false
	tablero.propio = lado
	tablero.cmb = cmb
	tablero.fmt = Callable(self, "_fmt")
	var ter: Dictionary = cmb.terrenos[int(c["terreno"])]
	tablero.tinte = TINTE_TERRENO.get(String(ter["cod"]), Color(0.36, 0.42, 0.24))
	_t_terreno.text = _texto_terreno(int(c["terreno"]))
	# el enemigo elige su formación (viendo una formación libre tuya: no sabe cómo te vas a desplegar)
	var otro := 1 - lado
	form[lado] = int(cmb.idx_formacion.get("formacion_libre", 0))
	form[otro] = cmb.mejor_formacion(cap[otro], cap[lado], int(form[lado]), int(c["terreno"]), float(c["sold"][otro]), float(c["sold"][lado]), bool(c["local"][otro]),
		float(c.get("bono_def", 0.0)), otro == 0, semilla)
	_llenar_formaciones()
	_restablecer_cuadro()
	_llenar_clases()
	_pintar_info()
	_poner_vel(_vel_i)
	if prueba and armar_fila:
		_armar_fila_prueba()
	abierto = true
	capa.visible = true
	_poner_fase("despliegue")
	_refrescar_tablero()


func cerrar(con_resultado: bool) -> void:
	if not abierto:
		return
	abierto = false
	capa.visible = false
	cerrada.emit(con_resultado)


func _cerrar_pedido() -> void:
	if ctx.get("modo", "") == "guerra" and fase != "fin":
		_dejar_sola()
	else:
		cerrar(aplicado)


func _dejar_sola() -> void:
	if guerra != null and ctx.has("bid"):
		guerra.resolver_sola(int(ctx["bid"]))
	cerrar(false)


func _texto_terreno(t: int) -> String:
	var ter: Dictionary = cmb.terrenos[t]
	var partes := []
	var mods: Dictionary = ter["mods"]
	for cod in mods:
		var pct := int(roundf((float(mods[cod]) - 1.0) * 100.0))
		if pct != 0:
			partes.append("%s %+d %%" % [String(cmb.armas[int(cmb.idx_arma[String(cod)])]["nombre"]), pct])
	var s := "Terreno: %s" % String(ter["nombre"])
	if not partes.is_empty():
		s += " — " + ", ".join(partes)
	if float(ter["defensor"]) > 1.0:
		s += " · ventaja del que defiende en casa ×%.2f" % float(ter["defensor"])
	return s


func _llenar_formaciones() -> void:
	_sel_form.clear()
	_form_ids = []
	var fs: PackedInt32Array = cap[lado]["formaciones"]
	var elegida := 0
	for k in fs.size():
		var fi: int = int(fs[k])
		_sel_form.add_item(String(cmb.formaciones[fi]["nombre"]))
		_form_ids.append(fi)
		if fi == int(form[lado]):
			elegida = k
	_sel_form.select(elegida)


func _llenar_clases() -> void:
	for h in _caja_clases.get_children():
		_caja_clases.remove_child(h)
		h.queue_free()
	_btn_clase = {}
	var niv: PackedFloat32Array = cap[lado]["nivel"]
	for a in cmb.n_armas:
		if float(niv[a]) <= 0.0:
			continue
		var b := _boton("%s %s" % [String(cmb.armas[a]["cod"]), String(cmb.armas[a]["nombre"])], func(): _elegir_clase(a))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size = Vector2(0.0, 28.0)
		b.add_theme_font_size_override("font_size", 11)
		_caja_clases.add_child(b)
		_btn_clase[a] = b
	var bb := _boton("✕ Borrar", func(): _elegir_clase(-1))
	bb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bb.custom_minimum_size = Vector2(0.0, 28.0)
	bb.add_theme_font_size_override("font_size", 11)
	_caja_clases.add_child(bb)
	_btn_clase[-1] = bb
	_elegir_clase(-1 if _clase_sel < 0 or not _btn_clase.has(_clase_sel) else _clase_sel)


func _elegir_clase(a: int) -> void:
	_clase_sel = a
	for k in _btn_clase:
		(_btn_clase[k] as Button).add_theme_color_override("font_color", Tema.ORO if int(k) == a else Tema.TEXTO)


func _pintar_info() -> void:
	var o := 1 - lado
	var sj := float(ctx["sold"][lado])
	var so := float(ctx["sold"][o])
	_t_yo.text = "%s\n%s soldados · nivel %.1f · calidad %.0f %%%s" % [_nombre(lado), main.hud.fmt_num(sj), cmb.nivel_ejercito(cap[lado]), float(ctx["cal"][lado]) * 100.0,
		" · defiendes en casa" if bool(ctx["local"][lado]) else ""]
	_t_enemigo.text = "%s\n%s soldados · nivel %.1f · calidad %.0f %%%s" % [_nombre(o), main.hud.fmt_num(so), cmb.nivel_ejercito(cap[o]), float(ctx["cal"][o]) * 100.0,
		" · defiende en casa" if bool(ctx["local"][o]) else ""]
	_pintar_formacion_enemiga()
	_pintar_formacion_propia()


func _pintar_formacion_propia() -> void:
	_t_form_desc.text = cmb.ficha_formacion(int(form[lado]))


func _pintar_formacion_enemiga() -> void:
	var o := 1 - lado
	var fo: Dictionary = cmb.formaciones[int(form[o])]
	var comp := {}
	for b in _bando_de(o)["bloques"]:
		var nom := String(cmb.armas[int(b["arma"])]["nombre"])
		comp[nom] = float(comp.get(nom, 0.0)) + float(b["n"])
	var partes := []
	for k in comp:
		partes.append("%s %s" % [k, _fmt(float(comp[k]))])
	_t_enem_desc.text = "Formación: %s\n%s\nTropas: %s" % [String(fo["nombre"]), cmb.ficha_formacion(int(form[o])), ", ".join(partes)]


# ───────────── despliegue ─────────────
func _restablecer_cuadro() -> void:
	cuadro_jug = cmb.cuadro_para(cap[lado], int(form[lado]))
	_refrescar_tablero()


func _al_elegir_formacion(i: int) -> void:
	form[lado] = int(_form_ids[i])
	_pintar_formacion_propia()
	_restablecer_cuadro()
	_pintar_formacion_enemiga()


func _sugerir() -> void:
	var o := 1 - lado
	var f: int = cmb.mejor_formacion(cap[lado], cap[o], int(form[o]), int(ctx["terreno"]), float(ctx["sold"][lado]), float(ctx["sold"][o]), bool(ctx["local"][lado]),
		float(ctx.get("bono_def", 0.0)), lado == 0, semilla)
	form[lado] = f
	var k := _form_ids.find(f)
	if k >= 0:
		_sel_form.select(k)
	_pintar_formacion_propia()
	_restablecer_cuadro()
	_registro.append_text("[color=#e8c15a]Tu estado mayor aconseja:[/color] %s\n" % String(cmb.formaciones[f]["nombre"]))


func _bando_de(l: int) -> Dictionary:
	var f: int = int(form[l])
	var cuadro: Array = cuadro_jug if l == lado else cmb.cuadro_para(cap[l], f)
	var bl: Array = cmb.bloques_de(cap[l], cuadro, f, float(ctx["sold"][l]), float(ctx["cal"][l]))
	return {"bloques": bl, "f": f, "cap": cap[l], "local": bool(ctx["local"][l]), "bono_def": float(ctx.get("bono_def", 0.0))}


func _refrescar_tablero() -> void:
	if tablero == null or cmb == null or ctx.is_empty():
		return
	var lista := []
	for l in 2:
		for b in _bando_de(l)["bloques"]:
			var bb: Dictionary = b
			var x := int(bb["c"]) if l == 0 else 7 - int(bb["c"])
			lista.append({"x": x, "y": int(bb["f"]), "arma": int(bb["arma"]), "n": float(bb["n"]), "n0": float(bb["n0"]), "mor": float(bb["moral0"]), "huyo": false, "lado": l})
	tablero.bloques = lista
	tablero.ataques = []
	tablero.editable = fase == "despliegue"
	tablero.queue_redraw()
	_btn_comenzar.disabled = cuadro_jug.is_empty()


func _al_pulsar_casilla(x: int, y: int, boton: int) -> void:
	if fase != "despliegue":
		return
	var mi_lado_x: bool = (x < 4) if lado == 0 else (x >= 4)
	if not mi_lado_x:
		return
	var col := x if lado == 0 else 7 - x
	var quitar: bool = boton == MOUSE_BUTTON_RIGHT or _clase_sel < 0
	var nuevo := []
	for c in cuadro_jug:
		if int(c[0]) == y and int(c[1]) == col:
			continue
		nuevo.append(c)
	if not quitar:
		nuevo.append([y, col, _clase_sel])
	cuadro_jug = nuevo
	_refrescar_tablero()


func _al_pasar_casilla(x: int, y: int) -> void:
	for b in tablero.bloques:
		if int(b["x"]) == x and int(b["y"]) == y and (float(b["n"]) > 0.5 or bool(b["huyo"])):
			var a: Dictionary = cmb.armas[int(b["arma"])]
			var de: String = _nombre(int(b["lado"]))
			_t_sobre.text = "%s · %s\n%s soldados de %s · moral %d%s" % [String(a["nombre"]), de, main.hud.fmt_num(float(b["n"])), main.hud.fmt_num(float(b["n0"])), int(float(b["mor"])),
				" · HUYE" if bool(b["huyo"]) else ""]
			return
	_t_sobre.text = ""


# ───────────── fase de batalla ─────────────
func _poner_fase(f: String) -> void:
	fase = f
	var desp := f == "despliegue"
	_btn_comenzar.visible = desp
	_btn_sola.visible = desp and String(ctx.get("modo", "")) == "guerra"
	_sel_form.disabled = not desp
	_caja_clases.visible = desp
	for b in _btns_vel:
		(b as Button).visible = f == "batalla"
	_btn_saltar.visible = f == "batalla"
	if tablero != null:
		tablero.editable = desp
		tablero.queue_redraw()


func _poner_vel(i: int) -> void:
	_vel_i = clampi(i, 0, VELOCIDADES.size() - 1)
	for k in _btns_vel.size():
		(_btns_vel[k] as Button).add_theme_color_override("font_color", Tema.ORO if k == _vel_i else Tema.TEXTO)


func _comenzar() -> void:
	if cuadro_jug.is_empty():
		return
	var A: Dictionary = _bando_de(0)
	var D: Dictionary = _bando_de(1)
	res = cmb.simular(A, D, int(ctx["terreno"]), semilla, true)
	base_bloques = []
	_na = (A["bloques"] as Array).size()
	for b in A["bloques"]:
		base_bloques.append(b)
	for b in D["bloques"]:
		base_bloques.append(b)
	_n_prev = [float(res["n0"][0]), float(res["n0"][1])]
	_r_vista = -1
	_t_ronda = 0.0
	_registro.append_text("[color=#9aa7c0]— Las tropas avanzan —[/color]\n")
	_poner_fase("batalla")
	_avanzar_ronda()


func _process(dt: float) -> void:
	if not abierto or fase != "batalla":
		return
	_t_ronda += dt * float(VELOCIDADES[_vel_i])
	if _t_ronda >= SEGUNDOS_RONDA:
		_t_ronda = 0.0
		_avanzar_ronda()


func _avanzar_ronda() -> void:
	var reg: Array = res["registro"]
	_r_vista += 1
	if _r_vista >= reg.size():
		_terminar_vista()
		return
	_mostrar_ronda(_r_vista)
	if _r_vista >= reg.size() - 1:
		_terminar_vista()


func _mostrar_ronda(r: int) -> void:
	var ent: Dictionary = res["registro"][r]
	var pos: Array = ent["pos"]
	var lista := []
	var sumas := [0.0, 0.0]
	for k in pos.size():
		var base: Dictionary = base_bloques[k]
		var p: Array = pos[k]
		var l := 0 if k < _na else 1
		var huyo: bool = int(p[4]) == 1
		lista.append({"x": int(p[0]), "y": int(p[1]), "arma": int(base["arma"]), "n": float(p[2]), "n0": float(base["n0"]), "mor": float(p[3]), "huyo": huyo, "lado": l})
		if not huyo:
			sumas[l] = float(sumas[l]) + float(p[2])
	tablero.bloques = lista
	tablero.ataques = ent["ataques"]
	tablero.queue_redraw()
	var perd := [maxf(float(_n_prev[0]) - float(sumas[0]), 0.0), maxf(float(_n_prev[1]) - float(sumas[1]), 0.0)]
	_registro.append_text("Ronda %d · %s −%s · %s −%s\n" % [r + 1, _nombre(0), _fmt(float(perd[0])), _nombre(1), _fmt(float(perd[1]))])
	_n_prev = [float(sumas[0]), float(sumas[1])]
	_t_ronda_lbl.text = "Ronda %d de %d" % [r + 1, (res["registro"] as Array).size()]


func _saltar() -> void:
	if fase != "batalla":
		return
	var reg: Array = res["registro"]
	while _r_vista < reg.size() - 1:
		_r_vista += 1
		_mostrar_ronda(_r_vista)
	_terminar_vista()


func _terminar_vista() -> void:
	if fase == "fin":
		return
	_poner_fase("fin")
	var g := int(res["ganador"])
	var titulo := "¡VICTORIA!" if g == lado else ("DERROTA" if g == 1 - lado else "EMPATE")
	_t_res_tit.text = titulo
	_t_res_tit.add_theme_color_override("font_color", Tema.OK if g == lado else (Tema.MAL if g == 1 - lado else Tema.ORO))
	var bj: Array = res["bajas"]
	var fb: Array = res["frac_bajas"]
	var o := 1 - lado
	var motivo := String(res["motivo"])
	_t_res_txt.text = "%s en %d rondas (%s).\n\nTus bajas: %s soldados (%d %%)\nBajas de %s: %s soldados (%d %%)%s" % [
		("Ganó " + _nombre(g)) if g >= 0 else "Nadie se impuso", int(res["rondas"]), motivo, main.hud.fmt_num(float(bj[lado])), int(roundf(float(fb[lado]) * 100.0)),
		_nombre(o), main.hud.fmt_num(float(bj[o])), int(roundf(float(fb[o]) * 100.0)),
		("\n\nEl vencido se retira de la provincia." if g >= 0 and String(ctx["modo"]) == "guerra" else "")]
	_btn_aplicar.disabled = aplicado
	_panel_res.visible = true
	_btn_ver_res.visible = false
	_registro.append_text("[b]%s[/b]\n" % titulo)


## Esconde el cuadro del resultado para mirar el tablero tal como quedó (y lo vuelve a mostrar).
func _ver_tablero(solo_tablero: bool) -> void:
	_panel_res.visible = not solo_tablero
	_btn_ver_res.visible = solo_tablero and fase == "fin"


func _aplicar() -> void:
	if aplicado or res.is_empty() or guerra == null or not ctx.has("bid"):
		return
	aplicado = true
	guerra.aplicar_tactico(int(ctx["bid"]), res)
	cerrar(true)


# ───────────── modo de prueba ─────────────
func _armar_fila_prueba() -> void:
	for h in _fila_prueba.get_children():
		_fila_prueba.remove_child(h)
		h.queue_free()
	_paises_prueba = []
	var mundo = main.mundo
	var nombres := []
	for n in mundo.paises:
		var e = mundo.paises[n]
		if e.provincias.size() > 0:
			nombres.append(String(n))
	nombres.sort()
	_paises_prueba = nombres
	_fila_prueba.add_child(_lbl("Tú:", 13, C_TENUE))
	_sel_pais_a = _selector_paises(String(ctx.get("pais_a", "")))
	_sel_pais_a.item_selected.connect(func(_i): _rearmar_prueba())
	_fila_prueba.add_child(_sel_pais_a)
	_fila_prueba.add_child(_lbl("contra:", 13, C_TENUE))
	_sel_pais_d = _selector_paises(String(ctx.get("pais_d", "")))
	_sel_pais_d.item_selected.connect(func(_i): _rearmar_prueba())
	_fila_prueba.add_child(_sel_pais_d)
	_fila_prueba.add_child(_lbl("Terreno:", 13, C_TENUE))
	_sel_terreno = OptionButton.new()
	_sel_terreno.focus_mode = Control.FOCUS_NONE
	for t in cmb.terrenos:
		_sel_terreno.add_item(String(t["nombre"]))
	_sel_terreno.select(int(ctx["terreno"]))
	_sel_terreno.item_selected.connect(func(_i): _rearmar_prueba())
	_fila_prueba.add_child(_sel_terreno)
	_fila_prueba.add_child(_lbl("Soldados de cada bando:", 13, C_TENUE))
	_campo_sold = SpinBox.new()
	_campo_sold.min_value = 500.0
	_campo_sold.max_value = 500000.0
	_campo_sold.step = 500.0
	_campo_sold.value = float(ctx["sold"][0])
	_campo_sold.value_changed.connect(func(_v): _rearmar_prueba())
	_fila_prueba.add_child(_campo_sold)


func _selector_paises(actual: String) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	var sel := 0
	for k in _paises_prueba.size():
		o.add_item(main._nombre_vis(String(_paises_prueba[k])))
		if String(_paises_prueba[k]) == actual:
			sel = k
	o.select(sel)
	return o


## Cambia el país, el terreno o los soldados en el modo de prueba: vuelve a armar el tablero.
func _rearmar_prueba() -> void:
	if _sel_pais_a == null or _paises_prueba.is_empty():
		return
	var pa: String = String(_paises_prueba[_sel_pais_a.selected])
	var pd: String = String(_paises_prueba[_sel_pais_d.selected])
	var c := datos_prueba(main, pa, pd, int(_sel_terreno.selected), float(_campo_sold.value))
	c["semilla"] = semilla + 1
	abrir(c, false)


func _otra() -> void:
	semilla += 7
	ctx["semilla"] = semilla
	abrir(ctx, false)


## Datos de un tablero de práctica entre dos países (por nombre): `terreno` índice, `sold` soldados de cada bando. Lo usa Debug > Combate y las pruebas.
static func datos_prueba(m: Node, pais_a: String, pais_d: String, terreno: int, sold: float) -> Dictionary:
	var mundo = m.mundo
	var ta: int = int(mundo.paises[pais_a].tid)
	var td: int = int(mundo.paises[pais_d].tid)
	return {"modo": "prueba", "nombres": [pais_a, pais_d], "banderas": [m._bandera_pais(pais_a), m._bandera_pais(pais_d)],
		"cap": [mundo.capacidad_militar(ta, true), mundo.capacidad_militar(td, true)], "sold": [sold, sold], "cal": [1.0, 1.0], "terreno": terreno,
		"local": [false, true], "bono_def": 0.0, "lado": 0, "titulo": "Práctica: %s contra %s" % [m._nombre_vis(pais_a), m._nombre_vis(pais_d)], "pais_a": pais_a, "pais_d": pais_d, "semilla": 1}
