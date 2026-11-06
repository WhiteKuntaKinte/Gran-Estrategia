extends Node
## MANEJO DE TROPAS (0.1.8) — vive DENTRO de la pestaña «Militar» del HUD de país (ya no es una ventana flotante).
## El HUD (scripts/hud.gd) le da un contenedor y decide qué subsección se ve; aquí están las páginas:
##   · Regimientos: lista de los regimientos (de la provincia elegida o de todo el país), su ficha y las órdenes:
##       Mover… (clic en el destino) · Dividir · Unir · Disolver (sin confirmación) · Detener.
##       SELECCIÓN MÚLTIPLE: Ctrl+clic en la lista o en los cuadros del mapa añade/quita regimientos, como en el explorador de archivos.
##       Con varios elegidos las órdenes valen para todos a la vez (mover, detener, unir en uno, disolver).
##   · Reclutar: soldados nuevos en la provincia elegida (si es tuya) como regimiento NUEVO o para reforzar uno; muestra el costo y
##       cuánto sube el mantenimiento. Se paga de la tesorería.
##   · Batallas: historial de estadísticas de batalla (fuerzas, bajas día por día, ganador).
## (Las guerras y la paz están ahora en la pestaña Diplomacia.)
## Solo puedes dar órdenes a las tropas de tu país (sin país elegido —observador— puedes ordenar a cualquiera).

const Tema := preload("res://scripts/tema_hud.gd")
const C_ORO := Tema.ORO
const C_TEXTO := Tema.TEXTO
const C_TENUE := Tema.TENUE
const C_OK := Tema.OK
const C_MAL := Tema.MAL
const MAX_FILAS := 60
const RECLUTA_SIN_DINERO := 1.0e9           # tope cuando el país no tiene tesorería simulada (no debería pasar desde 0.1.8.1)


## Campo para escribir cantidades grandes (1.500.000): solo acepta dígitos, pone los puntos de miles mientras escribes y respeta un máximo.
## Se usa como un SpinBox: `value`, `max_value` y la señal `valor_cambiado`.
class CampoNumero extends LineEdit:
	signal valor_cambiado(v: float)
	var max_value := 1.0e15:
		set(x):
			max_value = maxf(0.0, floorf(x))
			if _v > max_value:
				fijar(max_value)
	var _v := 0.0
	var value: float:
		get:
			return _v
		set(x):
			fijar(x)

	func _init() -> void:
		alignment = HORIZONTAL_ALIGNMENT_RIGHT
		placeholder_text = "0"
		select_all_on_focus = true
		text_changed.connect(_al_escribir)
		text_submitted.connect(func(_t): _formatear())
		focus_exited.connect(_formatear)

	static func con_puntos(n: int) -> String:
		var s := str(absi(n))
		var r := ""
		var k := 0
		for i in range(s.length() - 1, -1, -1):
			r = s[i] + r
			k += 1
			if k % 3 == 0 and i > 0:
				r = "." + r
		return ("-" if n < 0 else "") + r

	## Pone el valor (se redondea hacia abajo y se recorta a 0..max_value) y lo escribe con puntos.
	func fijar(x: float, emitir := true) -> void:
		var nuevo := clampf(floorf(x), 0.0, max_value)
		var cambio := not is_equal_approx(nuevo, _v)
		_v = nuevo
		text = con_puntos(int(_v)) if _v > 0.0 else ""
		caret_column = text.length()
		if cambio and emitir:
			valor_cambiado.emit(_v)

	func _al_escribir(t: String) -> void:
		var d := ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				d += ch
		if d.length() > 15:
			d = d.substr(0, 15)
		var n := float(d.to_int()) if d != "" else 0.0
		fijar(n)

	func _formatear() -> void:
		text = con_puntos(int(_v)) if _v > 0.0 else ""

var main
var fuente: Font
var fuente_neg: Font
var caja: Control                    # contenedor del HUD donde se construyen las páginas
var prov_tid := -1                   # provincia que se mira (-1: ninguna; el país entero)
var pais_tid := -1
var sel_reg := -1                    # regimiento principal elegido
var sel_multi: Array = []            # SELECCIÓN MÚLTIPLE: IDs de todos los regimientos elegidos (vacío si solo hay uno)
var sel_bat := -1
var filtro_todos := false
var pestana := "reg"
var puede_ordenar := false
var puede_reclutar := false
var max_n := 0
var max_reclutar := 0
var activo := false:
	set(v):
		var cambio := v != activo
		activo = v
		if v and cambio and main != null:
			_autoelegir()
			_refrescar(true)
			_sincronizar_mapa()

var lbl_pais: Label
var lbl_fin: Label
var lbl_precio: Label
var paginas := {}
# página Regimientos
var btn_f_prov: Button
var btn_f_todos: Button
var lbl_filtro: Label
var caja_lista: VBoxContainer
var sc_lista: ScrollContainer
var _ult_visible := -2               # regimiento que la lista dejó a la vista la última vez (para no pelear con el scroll del jugador)
var lbl_det: Label
var lbl_cantidad: Label
var sl_n: HSlider
var sp_n: SpinBox
var btn_mover: Button
var btn_dividir: Button
var btn_parar: Button
var btn_disolver: Button
var opt_unir: OptionButton
var btn_unir: Button
var fila_unir: HBoxContainer
# página Reclutar
var lbl_rec_prov: Label
var sp_rec: CampoNumero
var lbl_rec_max: Label
var opt_rec_dest: OptionButton
var lbl_rec_costo: Label
var btn_rec: Button
# página Batallas
var caja_bat: VBoxContainer
var lbl_bat_tot: Label
var lbl_bat_det: Label
var lbl_msg: Label
var _firma := []
var _t := 0.0
var _ids_unir := []
var _ids_dest := []
var _reg_prev := -2                  # regimiento cuya ficha se mostró la última vez (para reponer la cantidad a «todo» al cambiar)
var _rec_dest := -1                  # regimiento que el jugador eligió reforzar (-1 = formar uno nuevo)


func construir(m: Node, f: Font, f_neg: Font, contenedor: Control) -> void:
	main = m
	fuente = f
	fuente_neg = f_neg if f_neg != null else f
	caja = contenedor
	process_mode = Node.PROCESS_MODE_ALWAYS
	lbl_pais = _lbl("", 15, C_ORO, true)
	lbl_pais.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(lbl_pais)
	lbl_fin = _lbl("", 12, C_TEXTO)
	lbl_fin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(lbl_fin)
	lbl_precio = _lbl("", 11, C_TENUE)
	lbl_precio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(lbl_precio)
	caja.add_child(HSeparator.new())
	for nombre in ["reg", "rec", "bat"]:
		var pg := VBoxContainer.new()
		pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pg.add_theme_constant_override("separation", 6)
		caja.add_child(pg)
		paginas[nombre] = pg
		match nombre:
			"reg":
				_pagina_reg(pg)
			"rec":
				_pagina_rec(pg)
			"bat":
				_pagina_bat(pg)
	lbl_msg = _lbl("", 12, C_OK)
	lbl_msg.custom_minimum_size = Vector2(0.0, 34.0)
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(lbl_msg)
	_sin_foco(caja)
	ir_a("reg")


# ─────────────────────────────────────────────────────────────
# Construcción
# ─────────────────────────────────────────────────────────────
func _lbl(t: String, tam: int, col: Color, negrita := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", fuente_neg if negrita else fuente)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	return l


func _boton(t: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE                       # así Espacio, 1-6, V, Retroceso siguen llegando al juego
	b.custom_minimum_size = Vector2(0.0, 30.0)
	b.add_theme_font_size_override("font_size", 13)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(accion)
	return b


func _spin_con_slider(pg: Control, sl: HSlider, sp: SpinBox) -> void:
	var fm := HBoxContainer.new()
	fm.add_theme_constant_override("separation", 8)
	pg.add_child(fm)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.custom_minimum_size = Vector2(0.0, 22.0)
	sl.step = 1.0
	fm.add_child(sl)
	sp.step = 1.0
	sp.custom_minimum_size = Vector2(110.0, 0.0)
	fm.add_child(sp)
	sl.value_changed.connect(func(v): sp.set_value_no_signal(v))
	sp.value_changed.connect(func(v): sl.set_value_no_signal(v))


func _rapido(t: String, accion: Callable) -> Button:
	var b := _boton(t, accion)
	b.custom_minimum_size = Vector2(56.0, 26.0)
	return b


func _pagina_reg(pg: VBoxContainer) -> void:
	var fb := HBoxContainer.new()
	fb.add_theme_constant_override("separation", 6)
	pg.add_child(fb)
	lbl_filtro = _lbl("", 12, C_TENUE)
	lbl_filtro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fb.add_child(lbl_filtro)
	btn_f_prov = _boton("Esta provincia", func(): _filtrar(false))
	btn_f_prov.toggle_mode = true
	fb.add_child(btn_f_prov)
	btn_f_todos = _boton("Todo el país", func(): _filtrar(true))
	btn_f_todos.toggle_mode = true
	fb.add_child(btn_f_todos)
	sc_lista = ScrollContainer.new()                    # la lista tiene su propio scroll: así las órdenes de abajo quedan a la vista
	sc_lista.custom_minimum_size = Vector2(0.0, 112.0)
	sc_lista.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pg.add_child(sc_lista)
	caja_lista = VBoxContainer.new()
	caja_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja_lista.add_theme_constant_override("separation", 2)
	sc_lista.add_child(caja_lista)
	lbl_det = _lbl("", 12, C_TEXTO)
	lbl_det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_det)
	lbl_cantidad = _lbl("ÓRDENES  (cantidad de soldados)", 12, C_ORO, true)
	pg.add_child(lbl_cantidad)
	sl_n = HSlider.new()
	sp_n = SpinBox.new()
	_spin_con_slider(pg, sl_n, sp_n)
	var qm := HBoxContainer.new()
	qm.add_theme_constant_override("separation", 6)
	pg.add_child(qm)
	qm.add_child(_rapido("¼", func(): _poner_n(int(max_n * 0.25))))
	qm.add_child(_rapido("½", func(): _poner_n(int(max_n * 0.5))))
	qm.add_child(_rapido("Todo", func(): _poner_n(max_n)))
	var fo := HBoxContainer.new()
	fo.add_theme_constant_override("separation", 6)
	pg.add_child(fo)
	btn_mover = _boton("Mover…", _on_mover)
	btn_mover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_mover.tooltip_text = "Luego haz clic en la provincia de destino. Para entrar en otro país hay que estar en guerra con él: declárala antes en su ficha > Diplomacia."
	fo.add_child(btn_mover)
	btn_dividir = _boton("Dividir", _on_dividir)
	btn_dividir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dividir.tooltip_text = "Separa esa cantidad de soldados en un regimiento nuevo, en la misma provincia."
	fo.add_child(btn_dividir)
	btn_parar = _boton("Detener", _on_detener)
	btn_parar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fo.add_child(btn_parar)
	fila_unir = HBoxContainer.new()
	fila_unir.add_theme_constant_override("separation", 6)
	pg.add_child(fila_unir)
	opt_unir = OptionButton.new()
	opt_unir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_unir.clip_text = true
	fila_unir.add_child(opt_unir)
	btn_unir = _boton("Unir", _on_unir)
	btn_unir.tooltip_text = "Une el regimiento elegido a este otro (deben estar quietos, en la misma provincia)."
	fila_unir.add_child(btn_unir)
	btn_disolver = _boton("Disolver regimiento", _on_disolver)
	btn_disolver.tooltip_text = "Los soldados vuelven a casa: dejan de costar mantenimiento (no se devuelve lo que costó reclutarlos). Sin confirmación."
	pg.add_child(btn_disolver)


func _pagina_rec(pg: VBoxContainer) -> void:
	lbl_rec_prov = _lbl("", 13, C_ORO, true)
	lbl_rec_prov.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_rec_prov)
	pg.add_child(_lbl("Cuántos soldados reclutar (escribe la cantidad que quieras; el límite es tu dinero)", 12, C_TENUE))
	sp_rec = CampoNumero.new()
	sp_rec.custom_minimum_size = Vector2(0.0, 30.0)
	sp_rec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_rec.valor_cambiado.connect(func(_v): _refrescar_costo())
	pg.add_child(sp_rec)
	lbl_rec_max = _lbl("", 12, C_TENUE)
	lbl_rec_max.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_rec_max)
	var qr := HBoxContainer.new()
	qr.add_theme_constant_override("separation", 6)
	pg.add_child(qr)
	qr.add_child(_rapido("1.000", func(): _poner_rec(1000)))
	qr.add_child(_rapido("10.000", func(): _poner_rec(10000)))
	qr.add_child(_rapido("100.000", func(): _poner_rec(100000)))
	qr.add_child(_rapido("1 M", func(): _poner_rec(1000000)))
	qr.add_child(_rapido("Máx", func(): _poner_rec(max_reclutar)))
	pg.add_child(_lbl("¿Adónde van?", 12, C_TENUE))
	opt_rec_dest = OptionButton.new()
	opt_rec_dest.clip_text = true
	opt_rec_dest.item_selected.connect(func(i): _rec_dest = int(_ids_dest[i]) if i >= 0 and i < _ids_dest.size() else -1; _refrescar_costo())
	pg.add_child(opt_rec_dest)
	lbl_rec_costo = _lbl("", 12, C_TEXTO)
	lbl_rec_costo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_rec_costo)
	btn_rec = _boton("Reclutar", _on_reclutar)
	pg.add_child(btn_rec)


func _pagina_bat(pg: VBoxContainer) -> void:
	lbl_bat_tot = _lbl("", 12, C_TEXTO)
	lbl_bat_tot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_bat_tot)
	caja_bat = VBoxContainer.new()
	caja_bat.add_theme_constant_override("separation", 2)
	pg.add_child(caja_bat)
	pg.add_child(HSeparator.new())
	lbl_bat_det = _lbl("", 12, C_TEXTO)
	lbl_bat_det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_bat_det)


func _sin_foco(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).focus_mode = Control.FOCUS_NONE
	for h in n.get_children():
		_sin_foco(h)


# ─────────────────────────────────────────────────────────────
# Utilidades
# ─────────────────────────────────────────────────────────────
func _ej():
	return main.mundo.ejercito


func _g():
	return main.mundo.guerra


func _nombre_pais(tid: int) -> String:
	return main.mundo.ejercito.bd.nombre_de(tid)


func _decir(t: String, ok := true) -> void:
	lbl_msg.text = t
	lbl_msg.add_theme_color_override("font_color", C_OK if ok else C_MAL)


func _n(x: float) -> String:
	return main.fmt_n(x)


func _fecha(f: int) -> String:
	if f <= 0:
		return "—"
	return "%02d/%02d/%d" % [f % 100, floori(f / 100.0) % 100, floori(f / 10000.0) - 100000]


func _dinero(x: float) -> String:
	var nombre := _nombre_pais(pais_tid)
	return main.fmt_dinero(x, main._simbolo_de(nombre))


func _poner_n(n: int) -> void:
	sl_n.value = clampi(n, 0, max_n)


func _poner_rec(n: int) -> void:
	sp_rec.value = float(clampi(n, 0, max_reclutar))


func _ctrl() -> bool:
	return Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)


## Todos los regimientos elegidos: la selección múltiple si hay (2 o más), o el regimiento principal solo.
func grupo() -> Array:
	var e = _ej()
	var r := []
	if sel_multi.size() >= 2:
		for rid in sel_multi:
			if e.existe_reg(int(rid)):
				r.append(int(rid))
	if r.is_empty() and sel_reg >= 0 and e.existe_reg(sel_reg):
		r.append(sel_reg)
	return r


func es_multiple() -> bool:
	return sel_multi.size() >= 2


func _sincronizar_mapa() -> void:
	if main.capa_tropas == null:
		return
	var e = _ej()
	var multi: Array = grupo() if es_multiple() else []
	if sel_reg >= 0 and e.existe_reg(sel_reg) and not e.en_marcha_reg(sel_reg):
		main.capa_tropas.sel = {"t": "reg", "reg": sel_reg}
	elif sel_reg >= 0 and e.existe_reg(sel_reg):
		main.capa_tropas.sel = {"t": "marcha", "id": int(e.marcha_de_reg.get(sel_reg, -1))}
	else:
		main.capa_tropas.sel = {}
	main.capa_tropas.sel_regs = multi
	main.capa_tropas.refrescar()


func ir_a(nombre: String) -> void:
	pestana = nombre
	lbl_precio.visible = nombre == "rec"            # los precios de la unidad solo hacen falta al reclutar
	for k in paginas:
		(paginas[k] as Control).visible = k == nombre
	_refrescar(true)


func _filtrar(todos: bool) -> void:
	filtro_todos = todos
	_refrescar(true)


# ─────────────────────────────────────────────────────────────
# Qué provincia, país y regimiento se miran
# ─────────────────────────────────────────────────────────────
## Lo llama el HUD cuando cambia lo seleccionado en el mapa. `prov` = -1: un país o estado entero (se ven todos sus regimientos).
func apuntar(prov: int, pais: int) -> void:
	var cambio := prov != prov_tid or pais != pais_tid
	prov_tid = prov
	pais_tid = pais
	if prov < 0:
		filtro_todos = true
	elif cambio:
		filtro_todos = false
	if cambio:
		sel_multi = []
	if activo:
		_autoelegir()
		_refrescar(true)
		_sincronizar_mapa()


## Deja elegido algo razonable: conserva lo elegido si sigue valiendo; si no, el regimiento más grande de la provincia.
func _autoelegir() -> void:
	var e = _ej()
	if e == null or pais_tid < 0:
		return
	var ok := false
	if sel_reg >= 0 and e.existe_reg(sel_reg) and e.pais_de_reg(sel_reg) == pais_tid:
		if prov_tid < 0 or filtro_todos or e.en_marcha_reg(sel_reg) or e.prov_de(sel_reg) == prov_tid:
			ok = true
	if ok:
		return
	sel_multi = []
	sel_reg = -1
	if prov_tid >= 0:
		var mejor := -1
		var ms := -1
		for rid in e.regs_en(prov_tid):
			if e.pais_de_reg(int(rid)) == pais_tid and e.soldados_reg(int(rid)) > ms:
				ms = e.soldados_reg(int(rid))
				mejor = int(rid)
		sel_reg = mejor


## Abre las tropas de una provincia (clic en un cuadro del mapa, etc.). `pais` = -1: las del dueño de la provincia. `reg` ≥ 0: lo deja elegido.
func mostrar(prov: int, pais := -1, reg := -1) -> void:
	var e = _ej()
	var pr = e.provincia_por_tid(prov)
	if pr == null:
		return
	prov_tid = prov
	if pais >= 0:
		pais_tid = pais
	elif main.mundo.paises.has(pr.pais):
		pais_tid = int(main.mundo.paises[pr.pais].tid)
	if reg >= 0 and e.existe_reg(reg):
		if not sel_multi.has(reg):
			sel_multi = []
		sel_reg = reg
		pestana = "reg"
		filtro_todos = false
	else:
		_autoelegir()
	if activo:
		ir_a(pestana)
	_sincronizar_mapa()
	if reg >= 0:
		_revelar_ordenes()


## Hace scroll en el HUD lo justo para que se vean las órdenes (lo llama el mapa al elegir tropas con un clic en sus cuadros).
func _revelar_ordenes() -> void:
	if not activo or pestana != "reg" or main == null or main.hud == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if activo and is_instance_valid(lbl_msg) and main.hud.scroll_cuerpo != null:
		main.hud.scroll_cuerpo.ensure_control_visible(lbl_msg)


## Deja de haber algo elegido (el HUD se cierra o se cambia de selección).
func limpiar_seleccion() -> void:
	sel_reg = -1
	sel_multi = []
	_reg_prev = -2
	_firma = []


## Clic normal sobre un regimiento (lista o mapa): queda elegido solo ese.
func elegir_reg(rid: int) -> void:
	var e = _ej()
	sel_multi = []
	sel_reg = rid
	if e.existe_reg(rid) and not e.en_marcha_reg(rid):
		prov_tid = e.prov_de(rid)
	_refrescar(true)
	_sincronizar_mapa()


## CTRL+CLIC sobre un regimiento (lista o mapa): lo añade a la selección o lo quita, como en el explorador de archivos.
func alternar_reg(rid: int, desde_mapa := false) -> void:
	var e = _ej()
	if not e.existe_reg(rid):
		return
	if pais_tid >= 0 and e.pais_de_reg(rid) != pais_tid:
		_decir("Solo puedes juntar en una selección regimientos del mismo país.", false)
		return
	var conj: Array = sel_multi.duplicate()
	if conj.is_empty() and sel_reg >= 0 and e.existe_reg(sel_reg):
		conj = [sel_reg]
	if not e.en_marcha_reg(rid) and prov_tid >= 0 and e.prov_de(rid) != prov_tid:
		filtro_todos = true                            # elegiste uno de otra provincia: la lista pasa a mostrar todo el país
	if conj.has(rid):
		conj.erase(rid)
		if sel_reg == rid:
			sel_reg = int(conj[conj.size() - 1]) if not conj.is_empty() else -1
	else:
		conj.append(rid)
		sel_reg = rid
	sel_multi = conj if conj.size() >= 2 else []
	if conj.size() == 1:
		sel_reg = int(conj[0])
	_refrescar(true)
	_sincronizar_mapa()
	if desde_mapa:
		_revelar_ordenes()


## Cantidad que el jugador puso para mover (la usan el clic derecho y el arrastre). 0 = todo el regimiento.
func n_mover() -> int:
	return int(sp_n.value) if sel_reg >= 0 and max_n > 0 and not es_multiple() else 0


func _firma_actual() -> Array:
	var e = _ej()
	var g = _g()
	return [e.version_pilas, e.version_marchas if not e.marchas.is_empty() and pestana == "reg" else 0, g.version if g != null else 0, prov_tid, pais_tid, sel_reg, sel_multi, sel_bat, filtro_todos, pestana]


func refrescar_ya() -> void:
	_refrescar(true)


func _refrescar(forzar := false) -> void:
	var e = _ej() if main != null and main.mundo != null else null
	if e == null or not activo or pais_tid < 0:
		return
	var nombre_pais := _nombre_pais(pais_tid)
	var jugador: String = main.mundo.jugador
	puede_ordenar = main.puede_ordenar_pais(nombre_pais)
	if sel_reg >= 0 and e.existe_reg(sel_reg) and not e.en_marcha_reg(sel_reg) and prov_tid >= 0 and not filtro_todos and e.prov_de(sel_reg) != prov_tid:
		prov_tid = e.prov_de(sel_reg)                   # el regimiento llegó a otra provincia: la lista lo sigue
	_refrescar_cabecera()
	var f := _firma_actual()
	if not forzar and f == _firma:
		return
	_firma = f
	match pestana:
		"reg":
			_refrescar_reg()
		"rec":
			_refrescar_rec()
		"bat":
			_refrescar_bat()


func _refrescar_cabecera() -> void:
	var e = _ej()
	var nombre_pais := _nombre_pais(pais_tid)
	if nombre_pais == "" or not main.mundo.paises.has(nombre_pais):
		lbl_pais.text = "Tropas"
		lbl_fin.text = ""
		lbl_precio.text = ""
		return
	var m = main.mundo
	var sold: int = e.soldados_de_pais(pais_tid)
	var nregs: int = (e.regs_pais.get(pais_tid, []) as Array).size()
	lbl_pais.text = "%s · %s soldados · %d regimientos" % [nombre_pais, _n(float(sold)), nregs]
	var ing: float = m.ingreso_diario_local(nombre_pais)
	var man: float = m.mantenimiento_diario_local(nombre_pais)
	var bal := ing - man
	var t := ""
	if nombre_pais == m.jugador:
		var tes: float = m.paises[nombre_pais].tesoreria
		t = "Tesorería: %s\n" % _dinero(tes)
	t += "Ingresos %s/día  −  Mantenimiento %s/día  =  %s%s/día" % [_dinero(ing), _dinero(man), "+" if bal >= 0.0 else "−", _dinero(absf(bal))]
	lbl_fin.text = t
	lbl_fin.add_theme_color_override("font_color", C_TEXTO if bal >= 0.0 else C_MAL)
	var pu: Dictionary = m.precios_unidad_local(nombre_pais)
	lbl_precio.text = "Una unidad (1.000 soldados): mantenerla %s al año · reclutarla %s" % [_dinero(float(pu["mant"])), _dinero(float(pu["recl"]))]


# ─────────────────────────────────────────────────────────────
# Página Regimientos
# ─────────────────────────────────────────────────────────────
func _regs_de_lista() -> Array:
	var e = _ej()
	var r := []
	var vistos := {}
	for mid in e.marchas:                              # los que van por el camino salen primero
		var rid: int = int(e.marchas[mid].get("reg", -1))
		if rid >= 0 and e.pais_de_reg(rid) == pais_tid:
			r.append(rid)
			vistos[rid] = true
	var otros := []
	if filtro_todos or prov_tid < 0:
		for rid in e.regs_pais.get(pais_tid, []):
			if not vistos.has(int(rid)):
				otros.append(int(rid))
	else:
		for rid in e.regs_en(prov_tid):
			if e.pais_de_reg(int(rid)) == pais_tid and not vistos.has(int(rid)):
				otros.append(int(rid))
	otros.sort_custom(func(a, b): return e.soldados_reg(a) > e.soldados_reg(b) or (e.soldados_reg(a) == e.soldados_reg(b) and a < b))
	r.append_array(otros)
	if es_multiple():                                  # los elegidos con Ctrl+clic salen siempre, arriba, aunque estén en otra provincia
		var arriba := []
		for rid in sel_multi:
			if e.existe_reg(int(rid)):
				arriba.append(int(rid))
				r.erase(int(rid))
		arriba.append_array(r)
		r = arriba
	return r


func _texto_fila(rid: int) -> String:
	var e = _ej()
	var f: Dictionary = e.ficha_reg(rid)
	if f.is_empty():
		return "?"
	var donde: String = String(f["provincia"])
	if bool(f["en_marcha"]):
		var m: Dictionary = e.marchas.get(int(f["marcha"]), {})
		if not m.is_empty():
			var ruta: PackedInt32Array = m["ruta"]
			donde = "→ %s (%d d.)" % [main.mundo.provincias[ruta[ruta.size() - 1]].nombre, int(ceilf(e.dias_restantes(m)))]
	return "%s · %s · %s soldados" % [f["nombre"], donde, _n(float(f["soldados"]))]


func _elegido(rid: int) -> bool:
	return rid == sel_reg or sel_multi.has(rid)


func _refrescar_reg() -> void:
	var e = _ej()
	var pr = e.provincia_por_tid(prov_tid) if prov_tid >= 0 else null
	var por_prov: bool = prov_tid >= 0 and not filtro_todos
	btn_f_prov.set_pressed_no_signal(por_prov)
	btn_f_todos.set_pressed_no_signal(not por_prov)
	btn_f_prov.disabled = prov_tid < 0
	lbl_filtro.text = ("En %s" % (pr.nombre if pr != null else "?")) if por_prov else "Todo %s" % _nombre_pais(pais_tid)
	for h in caja_lista.get_children():
		caja_lista.remove_child(h)
		h.queue_free()
	var lista := _regs_de_lista()
	if sel_reg >= 0 and (not e.existe_reg(sel_reg) or e.pais_de_reg(sel_reg) != pais_tid):
		sel_reg = -1
	if not sel_multi.is_empty():                       # los que dejaron de existir salen de la selección
		var vivos := []
		for rid in sel_multi:
			if e.existe_reg(int(rid)) and e.pais_de_reg(int(rid)) == pais_tid:
				vivos.append(int(rid))
		sel_multi = vivos if vivos.size() >= 2 else []
		if vivos.size() == 1:
			sel_reg = int(vivos[0])
	var n := 0
	for rid in lista:
		if n >= MAX_FILAS:
			break
		var b := Button.new()
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = _texto_fila(int(rid))
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0.0, 26.0)
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = "Clic: elegir · Ctrl+clic: añadir o quitar de la selección"
		b.set_pressed_no_signal(_elegido(int(rid)))
		if _elegido(int(rid)):
			b.add_theme_color_override("font_color", C_ORO)
			b.add_theme_color_override("font_pressed_color", C_ORO)
		var id_r := int(rid)
		b.pressed.connect(func():
			if _ctrl():
				alternar_reg(id_r)
			else:
				elegir_reg(id_r))
		caja_lista.add_child(b)
		n += 1
	if sel_reg != _ult_visible and sel_reg >= 0:           # la lista se desplaza sola hasta el regimiento elegido
		_ult_visible = sel_reg
		var idx_sel := lista.find(sel_reg)
		if idx_sel >= 0 and idx_sel < caja_lista.get_child_count():
			var fila_sel: Control = caja_lista.get_child(idx_sel)
			(func():
				await get_tree().process_frame
				if is_instance_valid(fila_sel) and is_instance_valid(sc_lista):
					sc_lista.ensure_control_visible(fila_sel)).call()
	if lista.is_empty():
		caja_lista.add_child(_lbl("No hay regimientos de %s aquí. Recluta en la subsección «Reclutar»." % _nombre_pais(pais_tid), 12, C_TENUE))
	elif lista.size() > MAX_FILAS:
		caja_lista.add_child(_lbl("… y %d regimientos más (los más chicos)." % (lista.size() - MAX_FILAS), 11, C_TENUE))
	_refrescar_detalle()


func _refrescar_detalle() -> void:
	if es_multiple():
		_refrescar_detalle_multiple()
		return
	var e = _ej()
	lbl_cantidad.text = "ÓRDENES  (cantidad de soldados)"
	var f: Dictionary = e.ficha_reg(sel_reg) if sel_reg >= 0 else {}
	var hay := not f.is_empty()
	max_n = int(f["soldados"]) if hay else 0
	sl_n.max_value = maxf(float(max_n), 1.0)
	sp_n.max_value = maxf(float(max_n), 1.0)
	if sel_reg != _reg_prev:                                  # otro regimiento: la cantidad vuelve a «todo» (no arrastra la del anterior)
		_reg_prev = sel_reg
		sl_n.value = float(max_n)
	elif sl_n.value > float(max_n) or sl_n.value <= 0.0:
		sl_n.value = float(max_n)
	var puede := puede_ordenar and hay
	sl_n.editable = puede
	sp_n.editable = puede
	btn_dividir.visible = true
	fila_unir.visible = true
	btn_unir.text = "Unir"
	btn_unir.tooltip_text = "Une el regimiento elegido a este otro (deben estar quietos, en la misma provincia)."
	if not hay:
		lbl_det.text = "Elige un regimiento de la lista para verlo y darle órdenes."
		btn_mover.text = "Mover…"
		btn_mover.disabled = true
		btn_dividir.disabled = true
		btn_parar.visible = false
		btn_disolver.text = "Disolver regimiento"
		btn_disolver.disabled = true
		opt_unir.clear()
		_ids_unir = []
		opt_unir.disabled = true
		btn_unir.disabled = true
		return
	var m = main.mundo
	var nombre_pais := _nombre_pais(pais_tid)
	var man_dia: float = m.ejercito.mantenimiento_diario_usd(pais_tid, int(f["soldados"])) * m._por_usd(nombre_pais)
	var t := "%s\n" % f["nombre"]
	if bool(f["en_marcha"]):
		var mm: Dictionary = e.marchas.get(int(f["marcha"]), {})
		if not mm.is_empty():
			var ruta: PackedInt32Array = mm["ruta"]
			var dest = m.provincias[ruta[ruta.size() - 1]]
			t += "En marcha hacia %s · llegan en %d días%s\n" % [dest.nombre, int(ceilf(e.dias_restantes(mm))), " (se detiene antes)" if bool(mm["parar"]) else ""]
	else:
		t += "En %s\n" % f["provincia"]
	t += "Soldados: %s (%d pelotones)\n" % [_n(float(f["soldados"])), int(f["pelotones"])]
	t += "Edad media %s años · Experiencia %d · Familiaridad %d · Forma física %d\n" % [("%.1f" % float(f["edad"])).replace(".", ","), int(roundf(float(f["exp"]))), int(roundf(float(f["fam"]))), int(roundf(float(f["fis"])))]
	t += "Bajas acumuladas: %s · Mantenimiento: %s por día" % [_n(float(f["bajas"])), _dinero(man_dia)]
	lbl_det.text = t
	var quieto := not bool(f["en_marcha"])
	btn_mover.text = "Mover…"
	btn_mover.disabled = not (puede and quieto)
	btn_dividir.disabled = not (puede and quieto and int(f["soldados"]) > 1)
	btn_parar.visible = bool(f["en_marcha"])
	btn_parar.disabled = not puede
	btn_disolver.text = "Disolver regimiento"
	btn_disolver.disabled = not (puede and quieto)
	# candidatos para unir: otros regimientos del mismo país, quietos, en la misma provincia
	opt_unir.clear()
	_ids_unir = []
	if quieto:
		for rid in e.regs_en(int(f["prov_tid"])):
			if int(rid) != sel_reg and e.pais_de_reg(int(rid)) == pais_tid:
				_ids_unir.append(int(rid))
		_ids_unir.sort_custom(func(a, b): return e.soldados_reg(a) > e.soldados_reg(b))
	for rid in _ids_unir:
		opt_unir.add_item("%s (%s)" % [e.nombre_reg(int(rid)), _n(float(e.soldados_reg(int(rid))))])
	if _ids_unir.is_empty():
		opt_unir.add_item("No hay otro regimiento aquí para unir")
	opt_unir.disabled = _ids_unir.is_empty() or not puede
	btn_unir.disabled = _ids_unir.is_empty() or not puede


## Ficha y órdenes cuando hay VARIOS regimientos elegidos: todo vale para el grupo.
func _refrescar_detalle_multiple() -> void:
	var e = _ej()
	var g: Array = grupo()
	var sold := 0
	var provs := {}
	var en_marcha := 0
	for rid in g:
		sold += e.soldados_reg(int(rid))
		if e.en_marcha_reg(int(rid)):
			en_marcha += 1
		else:
			provs[e.prov_de(int(rid))] = true
	var puede := puede_ordenar
	lbl_cantidad.text = "ÓRDENES  (para los %d regimientos elegidos)" % g.size()
	var t := "%d regimientos elegidos (Ctrl+clic añade o quita) · %s soldados\n" % [g.size(), _n(float(sold))]
	if en_marcha > 0:
		t += "%d van en marcha · " % en_marcha
	t += "%d %s de salida" % [provs.size(), "provincia" if provs.size() == 1 else "provincias"]
	lbl_det.text = t
	max_n = sold
	sl_n.editable = false
	sp_n.editable = false
	var quietos := g.size() - en_marcha
	btn_mover.text = "Mover los %d…" % g.size()
	btn_mover.disabled = not (puede and quietos > 0)
	btn_dividir.visible = false
	btn_parar.visible = en_marcha > 0
	btn_parar.disabled = not puede
	btn_disolver.text = "Disolver los %d regimientos" % g.size()
	btn_disolver.disabled = not (puede and quietos > 0)
	# unir en uno: todos quietos y en la misma provincia
	opt_unir.clear()
	_ids_unir = []
	opt_unir.add_item("Se unen en el más grande de los elegidos")
	opt_unir.disabled = true
	btn_unir.text = "Unir los %d en uno" % g.size()
	btn_unir.tooltip_text = "Junta todos los regimientos elegidos en uno solo (deben estar quietos y en la misma provincia)."
	btn_unir.disabled = not (puede and en_marcha == 0 and provs.size() == 1)


# ── órdenes ──
func _on_mover() -> void:
	if es_multiple():
		main.iniciar_destino_grupo(grupo())
		_decir("Haz clic en la provincia de destino (Esc cancela). Se mueven los %d regimientos elegidos; si es de otro país, será la guerra." % grupo().size(), true)
		return
	var n := int(sp_n.value)
	if sel_reg < 0 or n <= 0:
		_decir("Elige un regimiento y cuántos soldados mover.", false)
		return
	main.iniciar_destino(sel_reg, n)
	_decir("Haz clic en la provincia de destino (Esc cancela). Si es de otro país, será la guerra.", true)


func _on_dividir() -> void:
	var e = _ej()
	var n := int(sp_n.value)
	if sel_reg < 0 or n <= 0 or n >= max_n:
		_decir("Para dividir elige una cantidad menor que el total del regimiento.", false)
		return
	var nuevo: int = e.dividir_reg(sel_reg, n)
	if nuevo < 0:
		_decir("No se pudo dividir.", false)
		return
	_decir("%s se dividió: %s soldados pasaron a %s." % [e.nombre_reg(sel_reg), _n(float(n)), e.nombre_reg(nuevo)], true)
	sel_reg = nuevo
	_refrescar(true)
	_sincronizar_mapa()
	main.hud.refrescar_ejercito()


func _on_unir() -> void:
	var e = _ej()
	if es_multiple():
		var g: Array = grupo()
		g.sort_custom(func(a, b): return e.soldados_reg(a) > e.soldados_reg(b) or (e.soldados_reg(a) == e.soldados_reg(b) and a < b))
		var destino: int = int(g[0])
		var unidos := 0
		var msg := ""
		for i in range(1, g.size()):
			var r: Dictionary = e.unir(destino, int(g[i]))
			if bool(r["ok"]):
				unidos += 1
				destino = int(r["reg"])
			else:
				msg = String(r["msg"])
		sel_multi = []
		sel_reg = destino if e.existe_reg(destino) else -1
		if unidos == g.size() - 1:
			_decir("%d regimientos se unieron en %s." % [g.size(), e.nombre_reg(destino)], true)
		else:
			_decir("Se unieron %d de %d. %s" % [unidos + 1, g.size(), msg], unidos > 0)
		_refrescar(true)
		_sincronizar_mapa()
		main.hud.refrescar_ejercito()
		return
	var k := opt_unir.selected
	if sel_reg < 0 or k < 0 or k >= _ids_unir.size():
		_decir("Elige con cuál unir.", false)
		return
	var otro: int = _ids_unir[k]
	var res: Dictionary = e.unir(otro, sel_reg)      # el elegido entra en el otro: el otro conserva su nombre
	_decir(String(res["msg"]), bool(res["ok"]))
	if bool(res["ok"]):
		sel_reg = int(res["reg"])
	_refrescar(true)
	_sincronizar_mapa()
	main.hud.refrescar_ejercito()


## Disuelve lo elegido (uno o varios regimientos). SIN confirmación: un solo clic.
func _on_disolver() -> void:
	var e = _ej()
	var g: Array = grupo()
	if g.is_empty():
		return
	var total := 0
	var cuantos := 0
	var nombre := ""
	for rid in g:
		if e.en_marcha_reg(int(rid)):
			continue                                  # los que van en marcha se detienen primero
		nombre = e.nombre_reg(int(rid))
		total += e.disolver_reg(int(rid))
		cuantos += 1
	if cuantos == 0:
		_decir("Los regimientos en marcha no se pueden disolver: deténlos primero.", false)
		return
	if cuantos == 1:
		_decir("%s disuelto: %s soldados volvieron a casa." % [nombre, _n(float(total))], true)
	else:
		_decir("%d regimientos disueltos: %s soldados volvieron a casa." % [cuantos, _n(float(total))], true)
	sel_reg = -1
	sel_multi = []
	_refrescar(true)
	_sincronizar_mapa()
	main.hud.refrescar_ejercito()
	main._actualizar_barra()


func _on_detener() -> void:
	var e = _ej()
	var n := 0
	for rid in grupo():
		if e.en_marcha_reg(int(rid)):
			e.detener_marcha(int(e.marcha_de_reg[int(rid)]))
			n += 1
	if n == 1:
		_decir("La columna se detendrá en la próxima provincia.", true)
	elif n > 1:
		_decir("%d columnas se detendrán en la próxima provincia." % n, true)


## Lo llama el mapa cuando se confirmó (o falló) una orden de marcha.
func resultado_orden(r: Dictionary) -> void:
	_decir(String(r.get("msg", "")), bool(r.get("ok", false)))
	if bool(r.get("ok", false)) and int(r.get("reg", -1)) >= 0 and not es_multiple():
		sel_reg = int(r["reg"])
	_refrescar(true)
	_sincronizar_mapa()


# ─────────────────────────────────────────────────────────────
# Página Reclutar
# ─────────────────────────────────────────────────────────────
func _refrescar_rec() -> void:
	var e = _ej()
	var pr = e.provincia_por_tid(prov_tid) if prov_tid >= 0 else null
	var m = main.mundo
	if pr == null:
		lbl_rec_prov.text = "Elige una provincia tuya en el mapa (un clic) para reclutar allí."
		puede_reclutar = false
		max_reclutar = 0
		sp_rec.max_value = 0.0
		sp_rec.editable = false
		lbl_rec_max.text = ""
		opt_rec_dest.clear()
		_ids_dest = [-1]
		opt_rec_dest.disabled = true
		_refrescar_costo()
		return
	var dueno_tid := -1
	if m.paises.has(pr.pais):
		dueno_tid = int(m.paises[pr.pais].tid)
	puede_reclutar = puede_ordenar and dueno_tid == pais_tid
	lbl_rec_prov.text = "Reclutar en %s (%s)" % [pr.nombre, pr.pais]
	max_reclutar = _max_por_dinero()
	sp_rec.max_value = float(max_reclutar)
	sp_rec.editable = puede_reclutar
	lbl_rec_max.text = "Con tu dinero puedes reclutar hasta %s soldados." % CampoNumero.con_puntos(max_reclutar)
	if sp_rec.value <= 0.0 or sp_rec.value > float(max_reclutar):
		sp_rec.value = float(mini(1000, max_reclutar))
	opt_rec_dest.clear()
	_ids_dest = [-1]
	opt_rec_dest.add_item("Formar un regimiento NUEVO")
	for rid in e.regs_en(prov_tid):
		if e.pais_de_reg(int(rid)) == pais_tid:
			_ids_dest.append(int(rid))
			opt_rec_dest.add_item("Reforzar: %s (%s)" % [e.nombre_reg(int(rid)), _n(float(e.soldados_reg(int(rid))))])
	if not _ids_dest.has(_rec_dest):
		_rec_dest = -1
	opt_rec_dest.select(_ids_dest.find(_rec_dest))
	opt_rec_dest.disabled = not puede_reclutar
	_refrescar_costo()


## Máximo de soldados que alcanza a pagar la tesorería del país (sin tope por población: el límite es el dinero).
func _max_por_dinero() -> int:
	var m = main.mundo
	var nombre_pais := _nombre_pais(pais_tid)
	if m == null or not m.paises.has(nombre_pais):
		return 0
	var e = m.paises[nombre_pais]
	if not e.tiene_tesoreria():
		return int(RECLUTA_SIN_DINERO)
	var tes: float = e.tesoreria
	if is_nan(tes) or tes <= 0.0:
		return 0
	var c1: float = m.costo_reclutar_local(nombre_pais, 1)
	if c1 <= 0.0:
		return int(RECLUTA_SIN_DINERO)
	return int(minf(floorf(tes / c1), RECLUTA_SIN_DINERO * 1000.0))


func _refrescar_costo() -> void:
	if lbl_rec_costo == null or main == null or main.mundo == null:
		return
	var m = main.mundo
	var nombre_pais := _nombre_pais(pais_tid)
	if not m.paises.has(nombre_pais):
		return
	var n := int(sp_rec.value)
	var costo: float = m.costo_reclutar_local(nombre_pais, n)
	var pu: Dictionary = m.precios_unidad_local(nombre_pais)
	var extra: float = float(n) / 1000.0 * float(pu["mant"]) / 365.25
	var t := "Costo: %s  (%s soldados = %s unidades)\n" % [_dinero(costo), CampoNumero.con_puntos(n), ("%.2f" % (float(n) / 1000.0)).replace(".", ",")]
	t += "El mantenimiento sube %s por día." % _dinero(extra)
	var alcanza := true
	if m.paises[nombre_pais].tiene_tesoreria():
		var tes: float = m.paises[nombre_pais].tesoreria
		t += "\nTesorería: %s" % _dinero(tes)
		alcanza = tes >= costo
		if not alcanza:
			t += "  —  NO ALCANZA"
	lbl_rec_costo.text = t
	lbl_rec_costo.add_theme_color_override("font_color", C_TEXTO if alcanza else C_MAL)
	btn_rec.disabled = not (puede_reclutar and alcanza and n > 0)
	if not puede_ordenar:
		btn_rec.text = "Estas tropas no son tuyas"
	elif not puede_reclutar:
		btn_rec.text = "Solo puedes reclutar en provincias de tu país"
	else:
		btn_rec.text = "Reclutar %s soldados" % CampoNumero.con_puntos(n)


func _on_reclutar() -> void:
	var m = main.mundo
	var nombre_pais := _nombre_pais(pais_tid)
	var n := int(sp_rec.value)
	var k := opt_rec_dest.selected
	var reg: int = _ids_dest[k] if k >= 0 and k < _ids_dest.size() else -1
	var res: Dictionary = m.reclutar_pagando(nombre_pais, prov_tid, n, reg)
	_decir(String(res["msg"]), bool(res["ok"]))
	if bool(res["ok"]):
		sel_multi = []
		sel_reg = int(res["reg"])
		_rec_dest = -1
		if main.capa_tropas != null:
			main.capa_tropas.refrescar()
		main.hud.refrescar_ejercito()
		main._actualizar_barra()
	_refrescar(true)
	_sincronizar_mapa()


# ─────────────────────────────────────────────────────────────
# Página Batallas (historial de estadísticas)
# ─────────────────────────────────────────────────────────────
func _refrescar_bat() -> void:
	var g = _g()
	for h in caja_bat.get_children():
		caja_bat.remove_child(h)
		h.queue_free()
	if g == null:
		return
	var lista: Array = g.batallas_de(pais_tid)
	var vict := 0
	var derr := 0
	var propias := 0
	var ajenas := 0
	for bid in lista:
		var f: Dictionary = g.ficha_batalla(int(bid))
		var soy_atac: bool = int(f["atacante"]) == pais_tid
		propias += int(f["bajas_atac"]) if soy_atac else int(f["bajas_def"])
		ajenas += int(f["bajas_def"]) if soy_atac else int(f["bajas_atac"])
		if int(f["ganador"]) == pais_tid:
			vict += 1
		elif int(f["ganador"]) >= 0:
			derr += 1
	lbl_bat_tot.text = "%s: %d batallas · %d victorias · %d derrotas\nBajas propias %s · bajas enemigas %s" % [_nombre_pais(pais_tid), lista.size(), vict, derr, _n(float(propias)), _n(float(ajenas))]
	var n := 0
	for bid in lista:
		if n >= 40:
			break
		var f2: Dictionary = g.ficha_batalla(int(bid))
		var estado := "EN CURSO" if bool(f2["activa"]) else ("ganó " + String(f2["ganador_n"]) if int(f2["ganador"]) >= 0 else String(f2["resultado"]))
		var b := Button.new()
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s · %s · %s" % [_fecha(int(f2["inicio"])), f2["nombre"], estado]
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0.0, 26.0)
		b.add_theme_font_size_override("font_size", 12)
		b.set_pressed_no_signal(int(bid) == sel_bat)
		var id_b := int(bid)
		b.pressed.connect(func(): _elegir_bat(id_b))
		caja_bat.add_child(b)
		n += 1
	if lista.is_empty():
		caja_bat.add_child(_lbl("Todavía no hay batallas. Empiezan cuando regimientos de dos países en guerra coinciden en una provincia.", 12, C_TENUE))
		lbl_bat_det.text = ""
	else:
		if sel_bat < 0 or not lista.has(sel_bat):
			sel_bat = int(lista[0])
		lbl_bat_det.text = _texto_batalla(sel_bat)


func _elegir_bat(bid: int) -> void:
	sel_bat = bid
	_refrescar(true)


func _texto_batalla(bid: int) -> String:
	var g = _g()
	var f: Dictionary = g.ficha_batalla(bid)
	if f.is_empty():
		return ""
	var t := "%s · %s contra %s\n" % [f["nombre"], f["atacante_n"], f["defensor_n"]]
	t += "Empezó %s%s · %d días de combate\n" % [_fecha(int(f["inicio"])), "" if bool(f["activa"]) else " · terminó " + _fecha(int(f["fin"])), int(f["dias"])]
	t += "ATACANTE %s: empezó con %s · bajas %s" % [f["atacante_n"], _n(float(f["ini_atac"])), _n(float(f["bajas_atac"]))]
	if bool(f["activa"]):
		t += " · quedan %s" % _n(float(f["rest_atac"]))
	t += "\nDEFENSOR %s: empezó con %s · bajas %s" % [f["defensor_n"], _n(float(f["ini_def"])), _n(float(f["bajas_def"]))]
	if bool(f["activa"]):
		t += " · quedan %s" % _n(float(f["rest_def"]))
	t += "\n"
	if bool(f["activa"]):
		t += "Sigue en combate.\n"
	elif int(f["ganador"]) >= 0:
		t += "Ganó %s (%s).\n" % [f["ganador_n"], f["resultado"]]
	else:
		t += "Sin ganador (%s).\n" % f["resultado"]
	var serie: Array = g.serie_bajas(bid, 400)
	if serie.size() > 0:
		t += "\nBajas acumuladas por día (atacante / defensor):\n"
		var desde := maxi(0, serie.size() - 12)
		for i in range(desde, serie.size()):
			t += "  %s: %s / %s\n" % ["inicio" if i == 0 else "día %d" % i, _n(float(serie[i][1])), _n(float(serie[i][2]))]
		if desde > 0:
			t += "  (se muestran los últimos 12 días de %d)\n" % serie.size()
	return t


# ─────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not activo or main == null or main.mundo == null or main.mundo.ejercito == null:
		return
	_t += delta
	var f := _firma_actual()
	if f != _firma:
		_refrescar(false)
	elif _t >= 0.5:
		_t = 0.0
		_refrescar_cabecera()
		if pestana == "rec":
			_refrescar_costo()
		elif pestana == "reg" and sel_reg >= 0 and _ej().en_marcha_reg(sel_reg):
			_refrescar_detalle()
