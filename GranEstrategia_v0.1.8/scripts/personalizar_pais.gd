extends Node
## «Mi país» 0.1.7.9.9B — ventana flotante para personalizar el país que controlas EN CUALQUIER MOMENTO de la partida
## (no solo al empezar). Se abre con el lápiz junto al nombre de tu país (barra superior) o desde Debug > Jugador.
## No pausa el juego. Cada cambio se guarda en la base de datos con su fecha y su motivo («Personalización»), así que
## queda un registro (variables nombre_visible, divisa, tasa_fiscal y velocidad_desarrollo; tablas de historial).
##   · Nombre: el nombre que ves tú (el original no se pierde).
##   · Moneda: cambia la divisa del país; la tesorería se convierte al nuevo tipo de cambio.
##   · Impuestos: parte de la producción que recauda el estado.
##   · Desarrollo: velocidad con la que crece la producción por habitante de TODAS tus provincias.

signal cerrada

const VentanaScript := preload("res://scripts/ventana_flotante.gd")
const BDScript := preload("res://scripts/base_datos.gd")
const C_ORO := Color(0.93, 0.78, 0.28)
const C_TEXTO := Color(0.95, 0.97, 1.0)
const C_TENUE := Color(0.62, 0.70, 0.86)
const C_OK := Color(0.45, 0.92, 0.55)
const MOTIVO := "Personalización"

var main
var fuente: Font
var vf: VentanaScript
var pais := ""
var le_nombre: LineEdit
var lbl_moneda: Label
var filtro_div: LineEdit
var lista_div: ItemList
var codigos_lista: Array = []
var cod_elegido := ""
var sl_tasa: HSlider
var lbl_tasa: Label
var lbl_prev_tasa: Label
var sl_des: HSlider
var lbl_des: Label
var lbl_prev_des: Label
var lbl_reg: Label
var lbl_msg: Label


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	pais = String(main.mundo.jugador)
	process_mode = Node.PROCESS_MODE_ALWAYS
	vf = VentanaScript.new()
	add_child(vf)
	var vp := get_viewport().get_visible_rect().size
	var tam := Vector2(450.0, minf(620.0, vp.y - 100.0))
	vf.construir(main, fuente, "MI PAÍS · " + String(main.mundo.paises[pais].nombre_visible).to_upper(), tam, Vector2(minf(430.0, maxf(vp.x - tam.x - 8.0, 8.0)), 66.0), "i_editar", "mipais")
	vf.cerrada.connect(func(): cerrada.emit())

	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0.0, 200.0)
	vf.contenido.add_child(sc)
	var pg := VBoxContainer.new()
	pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pg.add_theme_constant_override("separation", 8)
	sc.add_child(pg)

	var intro := vf.lbl("Cambia tu país cuando quieras. Los cambios se aplican al pulsar APLICAR y quedan guardados con su fecha en el historial.", 11, C_TENUE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(intro)

	_seccion_nombre(pg)
	pg.add_child(HSeparator.new())
	_seccion_moneda(pg)
	pg.add_child(HSeparator.new())
	_seccion_impuestos(pg)
	pg.add_child(HSeparator.new())
	_seccion_desarrollo(pg)
	pg.add_child(HSeparator.new())
	pg.add_child(vf.lbl("Registro de cambios", 13, C_ORO))
	lbl_reg = vf.lbl("", 12, C_TEXTO)
	lbl_reg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_reg)

	lbl_msg = vf.lbl("", 12, C_OK)
	lbl_msg.custom_minimum_size = Vector2(0.0, 30.0)
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vf.contenido.add_child(lbl_msg)
	_refrescar()
	_sin_foco(vf.ventana)


func _input(ev: InputEvent) -> void:
	if vf != null and ev is InputEventMouseButton and ev.pressed:
		if not vf.ventana.get_global_rect().has_point(ev.position):
			var f: Control = get_viewport().gui_get_focus_owner()
			if f != null:
				f.release_focus()


func _sin_foco(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).focus_mode = Control.FOCUS_NONE
	for h in n.get_children():
		_sin_foco(h)


func _decir(t: String, ok := true) -> void:
	lbl_msg.text = t
	lbl_msg.add_theme_color_override("font_color", C_OK if ok else Color(1.0, 0.55, 0.45))


func _e():
	return main.mundo.paises[pais]


## Aplica un cambio marcándolo con el motivo de personalización y refresca la barra superior y los paneles abiertos.
func _aplicar(accion: Callable) -> void:
	var bd = main.mundo.bd
	var m0: String = bd.motivo_ctx
	bd.motivo_ctx = MOTIVO
	accion.call()
	bd.motivo_ctx = m0
	main.refrescar_todo(false)
	_refrescar()


func _plano(s: String) -> String:
	var r := s.to_lower()
	for par in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"], ["ç", "c"]]:
		r = r.replace(par[0], par[1])
	return r


# ───────────── Nombre ─────────────
func _seccion_nombre(pg: VBoxContainer) -> void:
	pg.add_child(vf.lbl("Nombre del país", 13, C_ORO))
	le_nombre = LineEdit.new()
	le_nombre.max_length = 40
	le_nombre.placeholder_text = "Nombre que quieres ver"
	pg.add_child(le_nombre)
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 6)
	pg.add_child(f)
	var b1 := vf.boton("APLICAR NOMBRE", func():
		var t := le_nombre.text.strip_edges()
		if t == "":
			_decir("Escribe un nombre (o usa RESTAURAR).", false)
			return
		_aplicar(func(): _e().nombre_visible = t)
		_decir("Ahora tu país se llama «%s»." % t))
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_child(b1)
	var b2 := vf.boton("RESTAURAR ORIGINAL", func():
		_aplicar(func(): _e().nombre_visible = _e().nombre)
		_decir("Nombre original restaurado: %s." % _e().nombre))
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_child(b2)


# ───────────── Moneda ─────────────
func _seccion_moneda(pg: VBoxContainer) -> void:
	pg.add_child(vf.lbl("Moneda", 13, C_ORO))
	lbl_moneda = vf.lbl("", 12, C_TEXTO)
	lbl_moneda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_moneda)
	filtro_div = LineEdit.new()
	filtro_div.placeholder_text = "Buscar moneda (nombre, código o símbolo)…"
	filtro_div.clear_button_enabled = true
	filtro_div.text_changed.connect(func(q: String): _llenar_monedas(q))
	pg.add_child(filtro_div)
	lista_div = ItemList.new()
	lista_div.custom_minimum_size = Vector2(0.0, 110.0)
	lista_div.item_selected.connect(func(i: int): cod_elegido = String(codigos_lista[i]))
	pg.add_child(lista_div)
	_llenar_monedas("")
	var b := vf.boton("CAMBIAR MONEDA", func():
		if cod_elegido == "":
			_decir("Elige una moneda de la lista.", false)
			return
		var dv_nuevo = main.mundo.divisas[cod_elegido]
		var sim_antes: String = main._simbolo_de(pais)
		var tes_antes: float = _e().tesoreria
		var ok := [false]
		_aplicar(func(): ok[0] = main.mundo.cambiar_divisa(pais, cod_elegido, MOTIVO))
		if ok[0]:
			_decir("Moneda cambiada a %s. Tesorería convertida: %s → %s." % [dv_nuevo.nombre, main.fmt_dinero(tes_antes, sim_antes), main.fmt_dinero(_e().tesoreria, main._simbolo_de(pais))])
		else:
			_decir("Ya usas esa moneda.", false))
	pg.add_child(b)
	var nota := vf.lbl("La tesorería se convierte con el tipo de cambio: no ganas ni pierdes valor real. Las fotos mensuales anteriores quedan en la moneda de entonces.", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)


func _llenar_monedas(q: String) -> void:
	lista_div.clear()
	codigos_lista.clear()
	var qq := _plano(q.strip_edges())
	var cods: Array = main.mundo.divisas.keys()
	cods.sort_custom(func(a, b): return _plano(String(main.mundo.divisas[a].nombre)) < _plano(String(main.mundo.divisas[b].nombre)))
	for c in cods:
		var d = main.mundo.divisas[c]
		var txt := "%s · %s (%s)" % [d.codigo, d.nombre, d.simbolo]
		if qq == "" or _plano(txt).contains(qq):
			lista_div.add_item(txt)
			codigos_lista.append(d.codigo)


# ───────────── Impuestos ─────────────
func _fila_slider(pg: Control, mn: float, mx: float, paso: float, al_mover: Callable, lbl_out: Array) -> HSlider:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 8)
	pg.add_child(f)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = paso
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(0.0, 24.0)
	sl.value_changed.connect(al_mover)
	f.add_child(sl)
	var l := vf.lbl("", 13, C_TEXTO)
	l.custom_minimum_size = Vector2(56.0, 0.0)
	f.add_child(l)
	lbl_out.append(l)
	return sl


func _seccion_impuestos(pg: VBoxContainer) -> void:
	pg.add_child(vf.lbl("Impuestos", 13, C_ORO))
	var o := []
	sl_tasa = _fila_slider(pg, 0.0, 1.0, 0.01, func(_v: float): _vista_previa(), o)
	lbl_tasa = o[0]
	lbl_prev_tasa = vf.lbl("", 12, C_TEXTO)
	lbl_prev_tasa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_prev_tasa)
	pg.add_child(vf.boton("APLICAR IMPUESTOS", func():
		var v := sl_tasa.value
		_aplicar(func(): _e().tasa_fiscal = v)
		_decir("Impuestos fijados en %d %%." % int(roundf(v * 100.0)))))


# ───────────── Desarrollo ─────────────
func _seccion_desarrollo(pg: VBoxContainer) -> void:
	pg.add_child(vf.lbl("Prioridad de desarrollo", 13, C_ORO))
	var o := []
	sl_des = _fila_slider(pg, 0.0, 3.0, 0.05, func(_v: float): _vista_previa(), o)
	lbl_des = o[0]
	lbl_prev_des = vf.lbl("", 12, C_TEXTO)
	lbl_prev_des.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_prev_des)
	pg.add_child(vf.boton("APLICAR DESARROLLO", func():
		var v := sl_des.value
		_aplicar(func(): _e().velocidad_desarrollo = v)
		_decir("Velocidad de desarrollo fijada en x%s." % ("%.2f" % v).replace(".", ","))))
	var nota := vf.lbl("Multiplica el ritmo al que crece, cada mes, la producción por habitante de todas tus provincias (junto con la velocidad de cada provincia). Por ahora es gratis: más adelante tendrá costo.", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)


## Muestra qué pasaría con los valores de los deslizadores (todavía sin aplicar).
func _vista_previa() -> void:
	var m = main.mundo
	var sim: String = main._simbolo_de(pais)
	var dv = m.divisa_de(pais)
	var por_usd: float = dv.por_usd if dv != null else 1.0
	var prod: float = m.produccion_anual_usd(pais)
	var t := sl_tasa.value
	lbl_tasa.text = "%d %%" % int(roundf(t * 100.0))
	lbl_prev_tasa.text = "Con %d %% recaudarías %s por día (hoy: %s)." % [int(roundf(t * 100.0)), main.fmt_dinero(prod * t / 365.25 * por_usd, sim), main.fmt_dinero(m.ingreso_diario_local(pais), sim)]
	var base: float = m.bd.num("crecimiento_base_anual", m.bd.id_de("mundo", "mundo"), 0.02)
	var d := sl_des.value
	lbl_des.text = ("x%.2f" % d).replace(".", ",")
	lbl_prev_des.text = "Con x%s la producción por habitante crecería ≈ %s al año en una provincia de velocidad x1 (hoy: x%s)." % [("%.2f" % d).replace(".", ","), main.hud.pct(base * d * 100.0), ("%.2f" % _e().velocidad_desarrollo).replace(".", ",")]


# ───────────── Refresco y registro ─────────────
func _refrescar() -> void:
	var e = _e()
	var dv = main.mundo.divisa_de(pais)
	le_nombre.text = e.nombre_visible
	lbl_moneda.text = "Hoy usas: %s (%s) · %s" % [dv.nombre, dv.simbolo, main.fmt_cambio(dv)] if dv != null else "Sin moneda definida."
	sl_tasa.set_value_no_signal(e.tasa_fiscal)
	sl_des.set_value_no_signal(e.velocidad_desarrollo)
	_vista_previa()
	_refrescar_registro()


func _refrescar_registro() -> void:
	var bd = main.mundo.bd
	var e = _e()
	var filas := []
	for nombre in ["nombre_visible", "divisa", "tasa_fiscal", "velocidad_desarrollo"]:
		var v = bd.vars[nombre]
		for h in bd.historial_de(nombre, e.tid, 30):
			if bool(h["actual"]):
				continue
			var val: String
			if v.tipo == "numero":
				val = ("%.2f" % float(h["valor"])).replace(".", ",")
				if nombre == "tasa_fiscal":
					val = "%d %%" % int(roundf(float(h["valor"]) * 100.0))
			else:
				val = String(h["valor"])
			filas.append([int(h["hasta"]), "%s: antes «%s» (hasta %s)%s" % [v.etiqueta, val, BDScript.fecha_texto(int(h["hasta"])), " · " + String(h["motivo"]) if String(h["motivo"]) != "" else ""]])
	filas.sort_custom(func(a, b): return a[0] > b[0])
	var t := ""
	for i in mini(filas.size(), 14):
		t += "· " + String(filas[i][1]) + "\n"
	lbl_reg.text = t if t != "" else "Todavía no has cambiado nada."
