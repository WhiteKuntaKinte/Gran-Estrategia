extends Node
## Ventana flotante (overlay) reutilizable — 0.1.7.9.9B.
## No pausa el juego, no oscurece ni bloquea el mapa (solo captura los clics que caen sobre ella), se arrastra desde la
## barra de título, se puede encoger a solo el título y se cierra con la X. La usan el menú Debug y "Mi país".
## 0.1.8.3: también se puede ANGOSTAR y ENSANCHAR (botones « » de la barra y la esquina ◢ de abajo a la derecha, que se arrastra) para ver mejor el mapa.

signal cerrada

const Tema := preload("res://scripts/tema_hud.gd")

var main
var fuente: Font
var capa: CanvasLayer
var raiz: Control
var ventana: PanelContainer
var contenido: VBoxContainer          # aquí se añade lo que muestra cada ventana
var _cuerpo: Control                  # contenido + (se oculta al encoger)
var _encogida := false
var _arrastrando := false
var _tam := Vector2(460.0, 560.0)
var _btn_encoger: Button
var _redimensionando := false
const TAM_MIN := Vector2(280.0, 150.0)
const PASO_ANCHO := 70.0


func construir(m: Node, f: Font, titulo: String, tam: Vector2, pos: Vector2, icono := "") -> void:
	main = m
	fuente = f
	_tam = tam
	process_mode = Node.PROCESS_MODE_ALWAYS
	capa = CanvasLayer.new()
	capa.layer = 25
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)

	var tema := Tema.crear_tema(fuente, main.fuente_ui_neg if "fuente_ui_neg" in main else fuente)

	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE            # el mapa sigue recibiendo los clics
	raiz.theme = tema
	capa.add_child(raiz)

	ventana = PanelContainer.new()
	ventana.position = pos
	ventana.custom_minimum_size = tam
	ventana.size = tam
	ventana.mouse_filter = Control.MOUSE_FILTER_STOP
	ventana.add_theme_stylebox_override("panel", Tema.panel(8.0))
	raiz.add_child(ventana)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	ventana.add_child(vb)

	# barra de título (se arrastra desde aquí)
	var barra := PanelContainer.new()
	barra.mouse_filter = Control.MOUSE_FILTER_STOP
	barra.mouse_default_cursor_shape = Control.CURSOR_MOVE
	barra.add_theme_stylebox_override("panel", Tema.cabecera(4.0))
	barra.gui_input.connect(_on_barra_input)
	vb.add_child(barra)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	barra.add_child(h)
	if icono != "":
		var ic := TextureRect.new()
		ic.texture = main.icono(icono)
		ic.custom_minimum_size = Vector2(22.0, 22.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	var t := Label.new()
	t.text = titulo
	if "fuente_ui_neg" in main:
		t.add_theme_font_override("font", main.fuente_ui_neg)
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Tema.TITULO)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	h.add_child(_boton_barra("«", "Angostar la ventana", func(): cambiar_tam(Vector2(-PASO_ANCHO, 0.0))))
	h.add_child(_boton_barra("»", "Ensanchar la ventana", func(): cambiar_tam(Vector2(PASO_ANCHO, 0.0))))
	_btn_encoger = _boton_barra("–", "Encoger / expandir", _alternar_encogida)
	h.add_child(_btn_encoger)
	h.add_child(_boton_barra("✕", "Cerrar", func(): cerrada.emit()))

	_cuerpo = VBoxContainer.new()
	_cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(_cuerpo as VBoxContainer).add_theme_constant_override("separation", 6)
	vb.add_child(_cuerpo)
	contenido = _cuerpo as VBoxContainer
	# agarradera de abajo a la derecha: se arrastra para cambiar el tamaño
	_fila_grip = HBoxContainer.new()
	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fila_grip.add_child(relleno)
	var grip := Label.new()
	grip.text = "◢"
	grip.tooltip_text = "Arrastra para cambiar el tamaño de la ventana"
	grip.add_theme_font_size_override("font_size", 16)
	grip.add_theme_color_override("font_color", Tema.TENUE)
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.gui_input.connect(_on_grip_input)
	_fila_grip.add_child(grip)
	vb.add_child(_fila_grip)


func _boton_barra(texto: String, tip: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(26.0, 24.0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(accion)
	return b


var _fila_grip: HBoxContainer


## Cambia el tamaño de la ventana en `d` píxeles (negativo = más chica), dentro de los límites de la pantalla.
## Con `empujar` (los botones « ») la ventana se corre hacia la izquierda/arriba si al crecer se saldría de la pantalla; al arrastrar la esquina ◢ no.
func cambiar_tam(d: Vector2, empujar := true) -> void:
	if _encogida:
		d.y = 0.0
	var vp := get_viewport().get_visible_rect().size
	var maxi_v := vp - Vector2(8.0, 8.0)
	if not empujar:
		maxi_v = Vector2(maxf(vp.x - ventana.position.x, TAM_MIN.x), maxf(vp.y - ventana.position.y, TAM_MIN.y))
	_tam = Vector2(clampf(_tam.x + d.x, TAM_MIN.x, maxf(maxi_v.x, TAM_MIN.x)), clampf(_tam.y + d.y, TAM_MIN.y, maxf(maxi_v.y, TAM_MIN.y)))
	_aplicar_tam()
	if empujar:
		ventana.position.x = clampf(ventana.position.x, 0.0, maxf(vp.x - _tam.x, 0.0))
		ventana.position.y = clampf(ventana.position.y, 0.0, maxf(vp.y - (40.0 if _encogida else _tam.y), 0.0))


## Aplica `_tam` a la ventana (si está encogida, solo el ancho: el alto lo da la barra de título).
func _aplicar_tam() -> void:
	if _encogida:
		ventana.custom_minimum_size = Vector2(_tam.x, 0.0)
		ventana.size = Vector2(_tam.x, 0.0)
	else:
		ventana.custom_minimum_size = _tam
		ventana.size = _tam


## Esquina ◢: mientras se mantiene pulsada, arrastrar cambia el tamaño de la ventana (sin empujarla: crece hacia abajo y a la derecha).
func _on_grip_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_redimensionando = ev.pressed
	elif ev is InputEventMouseMotion and _redimensionando:
		cambiar_tam(ev.relative, false)


func _on_barra_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = ev.pressed
	elif ev is InputEventMouseMotion and _arrastrando:
		ventana.position += ev.relative
		_encajar()


func _encajar() -> void:
	var vp := get_viewport().get_visible_rect().size
	ventana.position.x = clampf(ventana.position.x, 0.0, maxf(vp.x - 120.0, 0.0))
	ventana.position.y = clampf(ventana.position.y, 0.0, maxf(vp.y - 40.0, 0.0))


func _alternar_encogida() -> void:
	_encogida = not _encogida
	_cuerpo.visible = not _encogida
	if _fila_grip != null:
		_fila_grip.visible = not _encogida
	_btn_encoger.text = "+" if _encogida else "–"
	_aplicar_tam()




# ───────────── utilidades de construcción para quien use la ventana ─────────────
func _caja(col: Color, borde: Color, radio: int, margen: int, bw := 1) -> StyleBoxFlat:
	return Tema.caja(col, borde, radio, margen, bw)


func lbl(t: String, tam: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	return l


func boton(t: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE                       # así Espacio, 1-6, V, Retroceso siguen llegando al juego
	b.custom_minimum_size = Vector2(0.0, 30.0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(accion)
	return b

