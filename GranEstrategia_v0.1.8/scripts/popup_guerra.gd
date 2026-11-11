extends Node
## Pop-ups de guerra (0.1.8.2a). Dos avisos que PAUSAN el tiempo y tapan el mapa con un velo hasta que el jugador responde:
##   1. «TE HAN DECLARADO LA GUERRA»: quién, por qué, cómo están las fuerzas y cuánto falta para el primer contacto (en días de juego y en
##      segundos reales a la velocidad que llevabas), para tener tiempo de reaccionar.
##   2. «FIN DE LA GUERRA»: el rival quiere cerrarla; se explica el MOTIVO y el jugador negocia el tratado con solo dos monedas de cambio,
##      PROVINCIAS y DINERO, que se pueden combinar. El rival evalúa en vivo (Guerra.evaluar_tratado) y la barra muestra si lo ofrecido alcanza.
## La lógica de la partida está en Guerra / MapaPrincipal; aquí solo se construye la interfaz.

signal cerrado(accion: String)

const Tema := preload("res://scripts/tema_hud.gd")
const CampoNumero := preload("res://scripts/hud_tropas.gd").CampoNumero

var main
var fuente: Font
var capa: CanvasLayer
var raiz: Control
var caja: PanelContainer
var cuerpo: VBoxContainer
var abierto := false
var tipo := ""                         # "guerra" | "paz" | ""
var aviso: Dictionary = {}

# negociación
var _prov_chk := {}                    # índice de provincia -> CheckBox
var _chk_conservar: CheckBox
var _campo_dinero
var _lbl_eval: Label
var _barra: ProgressBar
var _lbl_res: Label
var ultimo_eval := {}                  # lo último que se evaluó (para pruebas)


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	process_mode = Node.PROCESS_MODE_ALWAYS
	capa = CanvasLayer.new()
	capa.layer = 40
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	capa.visible = false
	add_child(capa)
	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.theme = Tema.crear_tema(fuente, main.fuente_ui_neg if "fuente_ui_neg" in main else fuente)
	capa.add_child(raiz)
	var velo := ColorRect.new()
	velo.color = Color(0.0, 0.0, 0.03, 0.62)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(velo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(centro)
	caja = PanelContainer.new()
	caja.custom_minimum_size = Vector2(620.0, 0.0)
	caja.add_theme_stylebox_override("panel", Tema.panel(14.0))
	centro.add_child(caja)
	cuerpo = VBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 8)
	caja.add_child(cuerpo)


## El pop-up se traga las teclas mientras está abierto (Espacio, 1-6, V… no deben llegar al juego de atrás).
func _input(ev: InputEvent) -> void:
	if abierto and ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ESCAPE or ev.keycode == KEY_SPACE or (ev.keycode >= KEY_1 and ev.keycode <= KEY_6) or ev.keycode == KEY_V or ev.keycode == KEY_BACKSPACE or ev.keycode == KEY_R or ev.keycode == KEY_F1:
			get_viewport().set_input_as_handled()


# ───────────── utilidades ─────────────
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
	b.custom_minimum_size = Vector2(0.0, 36.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(accion)
	return b


func _linea() -> HSeparator:
	return HSeparator.new()


func _limpiar() -> void:
	for h in cuerpo.get_children():
		cuerpo.remove_child(h)
		h.queue_free()
	_prov_chk = {}
	_chk_conservar = null
	_campo_dinero = null
	_lbl_eval = null
	_barra = null
	_lbl_res = null


func _cabecera(pais: String, titulo: String, subtitulo: String, col: Color) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	cuerpo.add_child(h)
	var tex = main.bandera_hd(main._bandera_pais(pais))
	if tex != null:
		var b := TextureRect.new()
		b.texture = tex
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.custom_minimum_size = Vector2(96.0, 64.0)
		b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(b)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_lbl(titulo, 22, col, true))
	if subtitulo != "":
		v.add_child(_lbl(subtitulo, 14, Tema.TENUE))


func cerrar(accion: String) -> void:
	if not abierto:
		return
	abierto = false
	capa.visible = false
	_limpiar()
	cerrado.emit(accion)


# ───────────── 1. Te han declarado la guerra ─────────────
## `d` = {"agresor": nombre del país, "causa", "fecha", "sold_jug", "sold_ag", "prov_jug", "prov_ag", "dias_contacto" (-1 si no hay dato),
##        "contacto_columnas" (true si ya hay columnas en marcha hacia ti), "vel" (velocidad que llevabas), "seg_vel", "seg_v1"}
func mostrar_guerra(d: Dictionary) -> void:
	_limpiar()
	tipo = "guerra"
	aviso = d
	abierto = true
	capa.visible = true
	var ag: String = String(d["agresor"])
	_cabecera(ag, "¡%s TE HA DECLARADO LA GUERRA!" % main._nombre_vis(ag).to_upper(), "%s · Motivo: %s" % [String(d["fecha"]), String(d["causa"])], Tema.MAL)
	cuerpo.add_child(_linea())
	cuerpo.add_child(_lbl("El tiempo está en PAUSA para que puedas reaccionar con calma.", 15, Tema.ORO, true))
	var sj: int = int(d["sold_jug"])
	var sa: int = int(d["sold_ag"])
	var rel := ("%.1f veces más" % (float(sa) / float(maxi(sj, 1)))) if sa > sj else ("%.1f veces menos" % (float(sa) / float(maxi(sj, 1))) if sj > 0 else "—")
	cuerpo.add_child(_lbl("Fuerzas: tú %s soldados · %s %s soldados (%s que tú)." % [main.hud.fmt_num(float(sj)), main._nombre_vis(ag), main.hud.fmt_num(float(sa)), rel], 14, Tema.TEXTO))
	cuerpo.add_child(_lbl("Provincias: tú %d · %s %d." % [int(d["prov_jug"]), main._nombre_vis(ag), int(d["prov_ag"])], 14, Tema.TEXTO))
	var dias: float = float(d["dias_contacto"])
	if dias >= 0.0:
		var q := "Primer contacto" if bool(d["contacto_columnas"]) else "Primer contacto (como pronto, en línea recta)"
		cuerpo.add_child(_lbl("%s: ≈ %d días de juego ≈ %.0f s reales a velocidad %d (%.0f s a velocidad 1)." % [q, int(ceilf(dias)), float(d["seg_vel"]), int(d["vel"]), float(d["seg_v1"])], 14, Tema.OK))
	else:
		cuerpo.add_child(_lbl("Todavía no hay tropas suyas en camino ni cerca de tu frontera.", 14, Tema.OK))
	cuerpo.add_child(_lbl("Qué puedes hacer: junta tus tropas en la frontera (Militar > Regimientos, clic derecho para moverlas), recluta más, o pide la paz desde Diplomacia cuando veas cómo va la guerra.", 13, Tema.NOTA))
	cuerpo.add_child(_linea())
	var bs := HBoxContainer.new()
	bs.add_theme_constant_override("separation", 10)
	cuerpo.add_child(bs)
	bs.add_child(_boton("REANUDAR (velocidad 1)", func(): cerrar("reanudar"), Tema.OK))
	bs.add_child(_boton("SEGUIR EN PAUSA", func(): cerrar("pausa")))


# ───────────── 2. Fin de la guerra: negociar con provincias y dinero ─────────────
## `d` = {"rival": nombre, "rival_tid", "razon" (texto), "pct_jug" (% de la producción del rival que ocupas), "pct_rival", "n_ocupo", "n_ocupa", "dias",
##        "puntaje" (desde tu punto de vista), "provincias": [[índice, nombre, valor_usd, ocupada_por_rival]], "caja_usd"}
func mostrar_paz(d: Dictionary) -> void:
	_limpiar()
	tipo = "paz"
	aviso = d
	abierto = true
	capa.visible = true
	var rv: String = String(d["rival"])
	_cabecera(rv, "FIN DE LA GUERRA CON %s" % main._nombre_vis(rv).to_upper(), "Tras %d días de guerra · puntaje de guerra %+.0f %%" % [int(d["dias"]), 100.0 * float(d["puntaje"])], Tema.ORO)
	cuerpo.add_child(_linea())
	cuerpo.add_child(_lbl(String(d["razon"]), 15, Tema.TEXTO))
	cuerpo.add_child(_lbl("Ocupas %d provincia(s) suya(s) (%.0f %% de su producción) · %s ocupa %d tuya(s) (%.0f %% de la tuya)." % [int(d["n_ocupo"]), float(d["pct_jug"]), main._nombre_vis(rv), int(d["n_ocupa"]), float(d["pct_rival"])], 13, Tema.TENUE))
	cuerpo.add_child(_linea())
	cuerpo.add_child(_lbl("NEGOCIA EL TRATADO — solo hay dos monedas de cambio, y se pueden combinar:", 14, Tema.ORO, true))
	# a) conservar lo ocupado
	if int(d["n_ocupo"]) > 0:
		_chk_conservar = CheckBox.new()
		_chk_conservar.text = "Quedarme con las %d provincia(s) que ocupo (si no, vuelven a su dueño)" % int(d["n_ocupo"])
		_chk_conservar.button_pressed = float(d["puntaje"]) > 0.04
		_chk_conservar.focus_mode = Control.FOCUS_NONE
		_chk_conservar.toggled.connect(func(_b): _actualizar_eval())
		cuerpo.add_child(_chk_conservar)
	# b) provincias que cedes
	cuerpo.add_child(_lbl("1 · PROVINCIAS que le entregas a %s (si no entregas las que te ocupa, vuelven a ti):" % main._nombre_vis(rv), 13, Tema.TEXTO))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0.0, 150.0)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(sc)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(lista)
	for fila in d["provincias"]:
		var c := CheckBox.new()
		var ocup: bool = bool(fila[3])
		c.text = "%s%s · vale %s" % [String(fila[1]), "  (ocupada por el rival)" if ocup else "", _usd(float(fila[2]))]
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_color_override("font_color", Tema.MAL if ocup else Tema.TEXTO)
		c.toggled.connect(func(_b): _actualizar_eval())
		lista.add_child(c)
		_prov_chk[int(fila[0])] = c
	# c) dinero
	var hd := HBoxContainer.new()
	hd.add_theme_constant_override("separation", 8)
	cuerpo.add_child(hd)
	hd.add_child(_lbl("2 · DINERO (US$) que le pagas como compensación (tienes %s):" % _usd(float(d["caja_usd"])), 13, Tema.TEXTO))
	_campo_dinero = CampoNumero.new()
	_campo_dinero.custom_minimum_size = Vector2(150.0, 30.0)
	_campo_dinero.max_value = float(d["caja_usd"])
	_campo_dinero.valor_cambiado.connect(func(_v): _actualizar_eval())
	hd.add_child(_campo_dinero)
	# evaluación en vivo
	_lbl_eval = _lbl("", 14, Tema.TEXTO, true)
	cuerpo.add_child(_lbl_eval)
	_barra = ProgressBar.new()
	_barra.min_value = 0.0
	_barra.max_value = 1.0
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(0.0, 14.0)
	cuerpo.add_child(_barra)
	_lbl_res = _lbl("", 13, Tema.NOTA)
	cuerpo.add_child(_lbl_res)
	cuerpo.add_child(_linea())
	var bs := HBoxContainer.new()
	bs.add_theme_constant_override("separation", 10)
	cuerpo.add_child(bs)
	bs.add_child(_boton("FIRMAR LA PAZ", _firmar, Tema.OK))
	bs.add_child(_boton("Cubrir lo que falta con dinero", _cubrir_con_dinero))
	bs.add_child(_boton("SEGUIR EN GUERRA", func(): cerrar("seguir_guerra"), Tema.MAL))
	_actualizar_eval()


static func _usd(v: float) -> String:
	if v >= 1.0e9:
		return "US$ %.2f mil M" % (v / 1.0e9)
	if v >= 1.0e6:
		return "US$ %.1f M" % (v / 1.0e6)
	return "US$ %s" % str(int(v))


## El tratado tal como está armado en pantalla.
func tratado_actual() -> Dictionary:
	var cede := []
	for pi in _prov_chk:
		if (_prov_chk[pi] as CheckBox).button_pressed:
			cede.append(int(pi))
	return {"cede": cede, "paga_usd": float(_campo_dinero.value) if _campo_dinero != null else 0.0,
		"conserva_a": _chk_conservar != null and _chk_conservar.button_pressed}


func _actualizar_eval() -> void:
	if tipo != "paz" or _lbl_eval == null:
		return
	var ev: Dictionary = main.tratado_evaluar(int(aviso["rival_tid"]), tratado_actual())
	ultimo_eval = ev
	var exigido: float = float(ev.get("exigido", 0.0))
	var ofrecido: float = float(ev.get("ofrecido", 0.0))
	var ok: bool = bool(ev.get("acepta", false))
	_lbl_eval.text = "%s exige un valor de %s · tú ofreces %s  →  %s" % [main._nombre_vis(String(aviso["rival"])), _usd(exigido), _usd(ofrecido), "ACEPTARÍA" if ok else "NO ALCANZA"]
	_lbl_eval.add_theme_color_override("font_color", Tema.OK if ok else Tema.MAL)
	_barra.value = 1.0 if exigido <= 0.0 else clampf(ofrecido / exigido, 0.0, 1.0)
	_barra.modulate = Color(0.55, 1.0, 0.65) if ok else Color(1.0, 0.55, 0.45)
	if _lbl_res != null:
		_lbl_res.text = ""


func _cubrir_con_dinero() -> void:
	var t := tratado_actual()
	var ev: Dictionary = main.tratado_evaluar(int(aviso["rival_tid"]), t)
	var falta: float = float(ev.get("exigido", 0.0)) - (float(ev.get("ofrecido", 0.0)) - float(t["paga_usd"]))
	_campo_dinero.value = clampf(ceilf(falta), 0.0, float(aviso["caja_usd"]))
	_actualizar_eval()
	if falta > float(aviso["caja_usd"]):
		_lbl_res.text = "Con todo tu dinero no alcanza: entrega también alguna provincia."


func _firmar() -> void:
	var res: Dictionary = main.tratado_firmar(int(aviso["rival_tid"]), tratado_actual())
	if bool(res.get("ok", false)):
		main.hud_aviso(String(res.get("msg", "")))
		cerrar("firmada")
	else:
		_lbl_res.text = String(res.get("msg", "No hay acuerdo."))
		_lbl_res.add_theme_color_override("font_color", Tema.MAL)
