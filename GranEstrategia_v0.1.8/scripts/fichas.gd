extends Node
## 0.1.8.38 · FICHAS: la ventanita que sale al dejar el ratón quieto sobre un botón, una pestaña, una tarjeta… (reemplaza al tooltip simple de Godot).
## Funciona sola con TODO control que tenga `tooltip_text`: no hay que registrar nada. Formato del texto:
##   · Una sola línea corta (hasta 30 letras) → solo título.   · Una línea larga → solo detalle.
##   · Varias líneas → la primera es el TÍTULO (dorado), las siguientes el detalle; una línea que empiece por «Atajo:» sale aparte, abajo, en tenue.
## También se puede poner `control.set_meta("ficha", Callable)` (devuelve el texto) para una ficha con datos al día: se pide cada vez que se muestra.
## El tooltip nativo queda apagado con `gui/timers/tooltip_delay_sec` en project.godot (si no, saldrían las dos).

const Tema := preload("res://scripts/tema_hud.gd")

const RETARDO := 0.45                      # s con el ratón quieto sobre el control hasta que sale la ficha
const RETARDO_CAMBIO := 0.12               # lo mismo si ya había una ficha a la vista y pasas a otro control
const ANCHO_MAX := 320.0
const DESPLAZ := Vector2(16.0, 22.0)       # separación respecto al puntero
const TITULO_CORTO := 30                   # una línea de hasta tantas letras se muestra como título

var main
var fuente: Font
var capa: CanvasLayer
var raiz: Control
var marco: PanelContainer
var lbl_titulo: Label
var lbl_cuerpo: Label
var lbl_atajo: Label
var activa := true                         # se puede apagar (queda sin fichas)
var ficha_de: Control = null               # el control al que pertenece la ficha que se ve ahora
var _sobre: Control = null                 # el control bajo el ratón en este momento
var _espera := 0.0
var _ult_pos := Vector2(-1.0, -1.0)
var _tw: Tween


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	process_mode = Node.PROCESS_MODE_ALWAYS
	capa = CanvasLayer.new()
	capa.layer = 30
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = Tema.crear_tema(fuente, main.fuente_ui_neg if "fuente_ui_neg" in main else fuente)
	capa.add_child(raiz)
	marco = PanelContainer.new()
	marco.visible = false
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(marco)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(vb)
	lbl_titulo = _etiqueta("oro", vb)
	if "fuente_ui_neg" in main and main.fuente_ui_neg != null:
		lbl_titulo.add_theme_font_override("font", main.fuente_ui_neg)
	lbl_cuerpo = _etiqueta("texto", vb)
	lbl_atajo = _etiqueta("tenue", vb)
	_pintar()


func _etiqueta(rol: String, padre: Node) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(0.0, 0.0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Tema.rotular(l, rol)
	padre.add_child(l)
	return l


func _pintar() -> void:
	marco.add_theme_stylebox_override("panel", Tema.caja(Tema.TOOLTIP_ARRIBA, Tema.ACERO_CLARO, 5, 8, 1))


func aplicar_tema() -> void:
	if raiz != null:
		raiz.theme = Tema.crear_tema(fuente, main.fuente_ui_neg if "fuente_ui_neg" in main else fuente)
	_pintar()
	Tema.repintar_roles(marco)


## Parte un texto de tooltip en [título, detalle, atajo] según el formato de arriba.
static func partir(texto: String) -> Array:
	var lineas := texto.strip_edges().split("\n", false)
	var titulo := ""
	var cuerpo: Array = []
	var atajo := ""
	for i in lineas.size():
		var l := String(lineas[i]).strip_edges()
		if l.begins_with("Atajo:"):
			atajo = l
		elif i == 0 and lineas.size() > 1:
			titulo = l
		else:
			cuerpo.append(l)
	if lineas.size() == 1 and atajo == "" and cuerpo.size() == 1 and String(cuerpo[0]).length() <= TITULO_CORTO:
		titulo = String(cuerpo[0])
		cuerpo = []
	return [titulo, "\n".join(PackedStringArray(cuerpo)), atajo]


## El texto que le toca a un control: el de su `ficha` si la tiene, si no su `tooltip_text`.
static func texto_de(c: Control) -> String:
	if c.has_meta("ficha"):
		var f = c.get_meta("ficha")
		if f is Callable and (f as Callable).is_valid():
			return String((f as Callable).call())
	return c.tooltip_text


## Muestra la ficha de `c` junto al puntero (coordenadas de pantalla). La usan el temporizador y las pruebas (con `await`: espera un fotograma para medir el alto).
func mostrar_de(c: Control, pos: Vector2) -> bool:
	var t := texto_de(c)
	if t.strip_edges() == "" or not activa:
		ocultar()
		return false
	var p := partir(t)
	var largo := maxi(String(p[0]).length(), String(p[1]).length())
	var w := clampf(float(largo) * 7.4 + 24.0, 90.0, ANCHO_MAX)
	for l in [lbl_titulo, lbl_cuerpo, lbl_atajo]:
		(l as Label).custom_minimum_size.x = w - 18.0
	lbl_titulo.text = String(p[0])
	lbl_titulo.visible = String(p[0]) != ""
	lbl_cuerpo.text = String(p[1])
	lbl_cuerpo.visible = String(p[1]) != ""
	lbl_atajo.text = String(p[2])
	lbl_atajo.visible = String(p[2]) != ""
	ficha_de = c
	if _tw != null and _tw.is_valid():
		_tw.kill()
	marco.modulate.a = 0.0
	marco.visible = true
	marco.reset_size()
	await get_tree().process_frame                                     # los textos largos se parten en líneas al acomodarse: recién ahí se sabe el alto
	if ficha_de != c or not marco.visible:
		return false                                                   # mientras tanto el ratón se fue
	marco.reset_size()
	_colocar(pos)
	_tw = create_tween()
	_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tw.tween_property(marco, "modulate:a", 1.0, 0.1)
	return true


func ocultar() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	marco.visible = false
	ficha_de = null


func esta_visible() -> bool:
	return marco != null and marco.visible


## Junto al puntero, sin salirse de la pantalla (si no cabe abajo o a la derecha, pasa arriba o a la izquierda).
func _colocar(pos: Vector2) -> void:
	var vp := raiz.get_viewport().get_visible_rect().size
	var tam := marco.size
	var x := pos.x + DESPLAZ.x
	var y := pos.y + DESPLAZ.y
	if x + tam.x > vp.x - 4.0:
		x = pos.x - DESPLAZ.x - tam.x
	if y + tam.y > vp.y - 4.0:
		y = pos.y - 8.0 - tam.y
	marco.position = Vector2(clampf(x, 4.0, maxf(vp.x - tam.x - 4.0, 4.0)), clampf(y, 4.0, maxf(vp.y - tam.y - 4.0, 4.0)))


func _process(dt: float) -> void:
	if marco == null:
		return
	var vp := get_viewport()
	var c: Control = vp.gui_get_hovered_control()
	var pos := vp.get_mouse_position()
	if c != null and (c == marco or marco.is_ancestor_of(c)):
		c = null
	var con_ficha := c != null and (c.has_meta("ficha") or c.tooltip_text != "")
	if not con_ficha or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_sobre = null
		if esta_visible():
			ocultar()
		_espera = 0.0
		return
	if c != _sobre:                                                    # pasó a otro control: empieza la espera de nuevo
		_sobre = c
		_espera = 0.0
		_ult_pos = pos
		if esta_visible() and ficha_de != c:
			_espera = RETARDO - RETARDO_CAMBIO
			ocultar()
		return
	if esta_visible():
		_colocar(pos)
		return
	if pos.distance_to(_ult_pos) > 3.0:                                # el ratón se mueve: sigue esperando a que se quede quieto
		_espera = 0.0
		_ult_pos = pos
		return
	_espera += dt
	if _espera >= RETARDO:
		mostrar_de(c, pos)
