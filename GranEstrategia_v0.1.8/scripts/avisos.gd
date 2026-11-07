extends Node
## 0.1.8.38 · AVISOS APILADOS: mensajes cortos que salen arriba a la derecha (debajo de la barra), uno encima de otro, y se desvanecen solos.
## Sustituyen a los mensajes que antes pisaban la línea de ayuda de abajo (esa línea queda solo para la ayuda del modo en que estás).
## · Niveles: "info" (azul acero), "ok" (verde), "aviso" (naranja), "mal" (rojo). Duran 4,5 / 4,5 / 6 / 8 segundos.
## · El mismo texto repetido seguido no apila otro: se suma «×2», «×3»… y se reinicia el tiempo.
## · Máximo 5 a la vez (el más viejo se va). Pasar el ratón por encima detiene el desvanecido; un clic lo quita.

const Tema := preload("res://scripts/tema_hud.gd")

const MAX_AVISOS := 5
const ANCHO := 340.0
const MARGEN_DER := 14.0
const FUNDIDO := 0.6                       # lo que dura el desvanecido final (s)
const DURACION := {"info": 4.5, "ok": 4.5, "aviso": 6.0, "mal": 8.0}

var main
var fuente: Font
var capa: CanvasLayer
var raiz: Control
var pila: VBoxContainer                    # aquí se apilan los avisos (el más nuevo, abajo)
var ultimo_texto := ""                     # el último texto que se avisó (aunque ya se haya ido; para pruebas)
var ultimo_nivel := ""
var _y_base := 52.0


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	process_mode = Node.PROCESS_MODE_ALWAYS
	capa = CanvasLayer.new()
	capa.layer = 26
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(capa)
	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = Tema.crear_tema(fuente, main.fuente_ui_neg if "fuente_ui_neg" in main else fuente)
	capa.add_child(raiz)
	pila = VBoxContainer.new()
	pila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pila.add_theme_constant_override("separation", 6)
	pila.anchor_left = 1.0
	pila.anchor_right = 1.0
	pila.offset_left = -(ANCHO + MARGEN_DER)
	pila.offset_right = -MARGEN_DER
	pila.offset_top = _y_base
	pila.grow_vertical = Control.GROW_DIRECTION_END
	raiz.add_child(pila)


## Cuántos avisos hay a la vista ahora.
func cantidad() -> int:
	return pila.get_child_count()


## Los textos que hay a la vista, del más viejo al más nuevo (sin el «×N»).
func textos() -> Array:
	var r: Array = []
	for a in pila.get_children():
		r.append(String(a.get_meta("texto")))
	return r


## Muestra un aviso. `nivel`: "info", "ok", "aviso" o "mal".
func mostrar(texto: String, nivel := "info") -> void:
	if texto.strip_edges() == "" or pila == null:
		return
	ultimo_texto = texto
	ultimo_nivel = nivel
	for a in pila.get_children():                                    # el mismo texto seguido: no se apila otro, se cuenta
		if String(a.get_meta("texto")) == texto and String(a.get_meta("nivel")) == nivel and not a.is_queued_for_deletion():
			a.set_meta("veces", int(a.get_meta("veces")) + 1)
			_poner_texto(a)
			_reiniciar(a)
			return
	while pila.get_child_count() >= MAX_AVISOS:
		_quitar(pila.get_child(0))
	var a := PanelContainer.new()
	a.set_meta("texto", texto)
	a.set_meta("nivel", nivel)
	a.set_meta("veces", 1)
	a.mouse_filter = Control.MOUSE_FILTER_STOP
	a.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	a.gui_input.connect(_on_aviso_input.bind(a))
	a.mouse_entered.connect(_on_sobre.bind(a, true))
	a.mouse_exited.connect(_on_sobre.bind(a, false))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.add_child(fila)
	var franja := ColorRect.new()
	franja.custom_minimum_size = Vector2(4.0, 0.0)
	franja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	franja.name = "Franja"
	fila.add_child(franja)
	var lbl := Label.new()
	lbl.name = "Texto"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(ANCHO - 40.0, 0.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Tema.rotular(lbl, "texto")
	fila.add_child(lbl)
	pila.add_child(a)
	_pintar(a)
	_poner_texto(a)
	_reiniciar(a)


func limpiar() -> void:
	for a in pila.get_children():
		_quitar(a)


## Repinta los avisos que haya con el tema vigente.
func aplicar_tema() -> void:
	if raiz != null:
		raiz.theme = Tema.crear_tema(fuente, main.fuente_ui_neg if "fuente_ui_neg" in main else fuente)
	for a in pila.get_children():
		_pintar(a)
	Tema.repintar_roles(pila)


func _color_nivel(nivel: String) -> Color:
	match nivel:
		"ok":
			return Tema.OK
		"mal":
			return Tema.MAL
		"aviso":
			return Tema.NARANJA
	return Tema.ACERO_CLARO


func _pintar(a: PanelContainer) -> void:
	var c := _color_nivel(String(a.get_meta("nivel")))
	a.add_theme_stylebox_override("panel", Tema.caja(Tema.TARJETA, Color(c.r, c.g, c.b, 0.85), 5, 8, 1))
	((a.get_child(0) as Control).get_node("Franja") as ColorRect).color = c


func _poner_texto(a: PanelContainer) -> void:
	var v := int(a.get_meta("veces"))
	((a.get_child(0) as Control).get_node("Texto") as Label).text = String(a.get_meta("texto")) + ("  ×%d" % v if v > 1 else "")


## Arranca (o reinicia) el tiempo de vida de un aviso: espera, se desvanece y se quita.
func _reiniciar(a: PanelContainer) -> void:
	_parar_tween(a)
	a.modulate.a = 1.0
	var dur: float = float(DURACION.get(String(a.get_meta("nivel")), 4.5))
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(dur)
	tw.tween_property(a, "modulate:a", 0.0, FUNDIDO)
	tw.tween_callback(_quitar.bind(a))
	a.set_meta("tween", tw)


func _parar_tween(a: Node) -> void:
	if a.has_meta("tween"):
		var tw = a.get_meta("tween")
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
		a.remove_meta("tween")


func _quitar(a: Node) -> void:
	if a == null or not is_instance_valid(a) or a.is_queued_for_deletion():
		return
	_parar_tween(a)
	a.get_parent().remove_child(a)
	a.queue_free()


func _on_sobre(a: PanelContainer, dentro: bool) -> void:
	if not is_instance_valid(a) or a.is_queued_for_deletion():
		return
	if dentro:
		_parar_tween(a)
		a.modulate.a = 1.0
	else:
		_parar_tween(a)
		var tw := create_tween()                                      # al salir el ratón queda un rato corto antes de irse
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(1.5)
		tw.tween_property(a, "modulate:a", 0.0, FUNDIDO)
		tw.tween_callback(_quitar.bind(a))
		a.set_meta("tween", tw)


func _on_aviso_input(ev: InputEvent, a: PanelContainer) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_quitar(a)
		get_viewport().set_input_as_handled()
