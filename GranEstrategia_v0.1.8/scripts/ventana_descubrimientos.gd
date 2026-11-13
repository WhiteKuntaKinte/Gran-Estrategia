extends Node
## Ventana DESCUBRIMIENTOS (0.1.8.42): el catálogo COMPLETO de 1.730 descubrimientos para el jugador, en cualquier época.
## Ventana flotante (no pausa el juego). Tecla T o el botón «Descubrimientos» de la barra de arriba.
##
## · Tres ramas (Militar, Científica, Sociedad) → secciones → subsecciones, con cuántos conoces de cada una.
## · El árbol de la sección elegida (`grafo_descubrimientos.gd`): quién necesita a quién, con líneas; se ve TODO, también lo que todavía no llega en la historia.
## · Buscador por nombre en todo el catálogo, filtros por estado y por tipo.
## · Ficha del descubrimiento elegido: año, era, ruta, tipo, estado, lo que REQUIERE y lo que ABRE (cada uno se pulsa para ir a él).
## No guarda nada en la partida: lee Descubrimientos (scripts/descubrimientos.gd). Se actualiza sola una vez por segundo mientras está abierta.
## Para ver lo que sabe tu país se usa el país que controlas; sin país (observador) se ve lo que sabe la historia en la fecha del reloj.

signal cerrada

const VentanaScript := preload("res://scripts/ventana_flotante.gd")
const GrafoScript := preload("res://scripts/grafo_descubrimientos.gd")
const Tema := preload("res://scripts/tema_hud.gd")
const REFRESCO := 1.0                       # segundos entre actualizaciones
const MAX_RESULTADOS := 80                  # tope de filas en la lista de resultados de la búsqueda
const MAX_RELACIONES := 14                  # tope de filas en «Requiere» y «Abre»
const ANCHO_IZQ := 232.0
const ANCHO_FICHA := 276.0
const OPCIONES_ESTADO := ["Todos los estados", "Solo conocidos", "Solo disponibles", "Bloqueados y lejanos", "Aún no llegan en la historia"]
const ROL_ESTADO := ["naranja", "azul", "ok", "tenue"]        # color del texto de cada estado del grafo (bloqueado, disponible, conocido, lejano)

static var _ultima_seccion := 0             # al volver a abrir, la ventana vuelve a la última sección vista

var main
var fuente: Font
var vf: VentanaScript
var d                                       # Descubrimientos
var grafo: GrafoScript
var rama_sel := 0
var sec_sel := -1
var cuentas := PackedInt32Array()           # por sección: cuántos conoce el país mostrado
var totales := PackedInt32Array()           # por sección: cuántos hay
var _btns_rama: Array = []
var _filas_sec: Array = []                  # [{s, caja, btn, lbl}] las 40 secciones (se arman una vez; se muestran las de la rama elegida)
var _sc_sec: ScrollContainer
var _sc_res: ScrollContainer
var _lista_res: VBoxContainer
var _tit_izq: Label
var _busca: LineEdit
var _opt_estado: OptionButton
var _opt_tipo: OptionButton
var _ficha: VBoxContainer
var _lbl_info: Label
var _acum := 0.0
var _firma := ""
var resultados := 0                         # (pruebas) cuántas filas tiene la lista de resultados
var filas_ficha := 0                        # (pruebas) cuántos botones de relaciones tiene la ficha


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	d = main.mundo.descubrimientos
	process_mode = Node.PROCESS_MODE_ALWAYS
	vf = VentanaScript.new()
	add_child(vf)
	var vp := get_viewport().get_visible_rect().size
	var tam := Vector2(minf(1180.0, vp.x - 40.0), minf(700.0, vp.y - 90.0))
	vf.construir(main, fuente, "DESCUBRIMIENTOS", tam, Vector2(20.0, 62.0), "i_estrella", "descubrimientos")
	vf.cerrada.connect(func(): cerrada.emit())
	var c := vf.contenido
	if d == null or d.n == 0:
		var l0 := vf.lbl_rol("Falta el catálogo (datos/descubrimientos.json).", 14, "naranja")
		c.add_child(l0)
		return
	# fila de arriba: ramas, buscador, filtros
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	c.add_child(fila)
	for r in d.ramas.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0.0, 30.0)
		b.add_theme_font_size_override("font_size", 13)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_elegir_rama.bind(r))
		fila.add_child(b)
		_btns_rama.append(b)
	_busca = LineEdit.new()
	_busca.placeholder_text = "Buscar descubrimiento…"
	_busca.clear_button_enabled = true
	_busca.custom_minimum_size = Vector2(190.0, 30.0)
	_busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var b_aj := vf.boton("Ajustar vista", func(): grafo.ajustar())
	b_aj.tooltip_text = "Ajustar vista\nEncaja el árbol de la sección en la ventana.\nRueda: acercar o alejar · arrastrar: mover."
	fila.add_child(b_aj)
	_lbl_info = vf.lbl_rol("", 12, "tenue")
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_lbl_info)
	# cuerpo: secciones | árbol | ficha
	var cuerpo := HBoxContainer.new()
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 6)
	c.add_child(cuerpo)
	var izq := VBoxContainer.new()
	izq.custom_minimum_size = Vector2(ANCHO_IZQ, 0.0)
	izq.add_theme_constant_override("separation", 4)
	cuerpo.add_child(izq)
	_tit_izq = vf.lbl_rol("SECCIONES", 11, "oro")
	izq.add_child(_tit_izq)
	_sc_sec = ScrollContainer.new()
	_sc_sec.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sc_sec.size_flags_vertical = Control.SIZE_EXPAND_FILL
	izq.add_child(_sc_sec)
	var lista_sec := VBoxContainer.new()
	lista_sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista_sec.add_theme_constant_override("separation", 3)
	_sc_sec.add_child(lista_sec)
	_sc_res = ScrollContainer.new()
	_sc_res.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sc_res.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sc_res.visible = false
	izq.add_child(_sc_res)
	_lista_res = VBoxContainer.new()
	_lista_res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_res.add_theme_constant_override("separation", 2)
	_sc_res.add_child(_lista_res)
	grafo = GrafoScript.new()
	grafo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grafo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grafo.custom_minimum_size = Vector2(300.0, 200.0)
	grafo.construir(d, fuente, main.fuente_ui_neg if "fuente_ui_neg" in main else fuente)
	grafo.elegido.connect(_al_elegir_nodo)
	cuerpo.add_child(grafo)
	var sc_f := ScrollContainer.new()
	sc_f.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc_f.custom_minimum_size = Vector2(ANCHO_FICHA, 0.0)
	cuerpo.add_child(sc_f)
	_ficha = VBoxContainer.new()
	_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ficha.add_theme_constant_override("separation", 4)
	sc_f.add_child(_ficha)
	_armar_secciones(lista_sec)
	_contar()
	grafo.fijar_tid(_tid())
	var s0 := clampi(_ultima_seccion, 0, d.secciones.size() - 1)
	_elegir_seccion(s0)
	_actualizar_textos()
	grafo.resized.connect(grafo.ajustar, CONNECT_ONE_SHOT)       # el árbol se ajusta cuando la ventana ya tiene su tamaño definitivo


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


## El país cuyo estado se muestra: el que controlas; sin país, -1 = solo la historia.
func _tid() -> int:
	var m = main.mundo
	if m.jugador != "" and m.paises.has(m.jugador):
		return int(m.paises[m.jugador].tid)
	return -1


# ─────────────────────────────────────────────────────────────
# Ramas y secciones
# ─────────────────────────────────────────────────────────────
func _armar_secciones(lista: VBoxContainer) -> void:
	_filas_sec.clear()
	for s in d.secciones.size():
		var caja := HBoxContainer.new()
		caja.add_theme_constant_override("separation", 4)
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text = String(d.secciones[s]["nombre"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0.0, 28.0)
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = "%s\n%s" % [String(d.secciones[s]["nombre"]), String(d.secciones[s].get("desc", ""))]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_elegir_seccion.bind(s))
		caja.add_child(b)
		var l := vf.lbl_rol("", 11, "tenue")
		l.custom_minimum_size = Vector2(46.0, 0.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		caja.add_child(l)
		lista.add_child(caja)
		_filas_sec.append({"s": s, "caja": caja, "btn": b, "lbl": l})


func _elegir_rama(r: int) -> void:
	rama_sel = r
	for b in _btns_rama.size():
		(_btns_rama[b] as Button).set_pressed_no_signal(b == r)
	for fs in _filas_sec:
		(fs["caja"] as Control).visible = int(d.secciones[int(fs["s"])]["rama"]) == r
	_tit_izq.text = "SECCIONES · %s" % String(d.ramas[r]["nombre"]).to_upper()
	# si la sección elegida no es de esta rama, se pasa a la primera de la rama
	if sec_sel < 0 or int(d.secciones[sec_sel]["rama"]) != r:
		for fs in _filas_sec:
			if int(d.secciones[int(fs["s"])]["rama"]) == r:
				_elegir_seccion(int(fs["s"]))
				return


func _elegir_seccion(s: int) -> void:
	if s < 0 or s >= d.secciones.size():
		return
	sec_sel = s
	_ultima_seccion = s
	var r: int = int(d.secciones[s]["rama"])
	if r != rama_sel or _tit_izq.text == "SECCIONES":
		rama_sel = r
		for b in _btns_rama.size():
			(_btns_rama[b] as Button).set_pressed_no_signal(b == r)
		for fs in _filas_sec:
			(fs["caja"] as Control).visible = int(d.secciones[int(fs["s"])]["rama"]) == r
		_tit_izq.text = "SECCIONES · %s" % String(d.ramas[r]["nombre"]).to_upper()
	for fs2 in _filas_sec:
		(fs2["btn"] as Button).set_pressed_no_signal(int(fs2["s"]) == s)
	grafo.fijar_seccion(s)
	_armar_ficha(-1)


## Cuántos conoce el país mostrado en cada sección.
func _contar() -> void:
	var tid := _tid()
	cuentas.resize(d.secciones.size())
	totales.resize(d.secciones.size())
	cuentas.fill(0)
	totales.fill(0)
	for i in d.n:
		var s: int = int(d.seccion[i])
		totales[s] += 1
		if d.conoce(tid, i):
			cuentas[s] += 1


## Los textos que dependen de las cuentas: botones de rama, contadores de cada sección y la línea de resumen.
func _actualizar_textos() -> void:
	var por_rama := PackedInt32Array()
	var tot_rama := PackedInt32Array()
	por_rama.resize(d.ramas.size())
	tot_rama.resize(d.ramas.size())
	for s in d.secciones.size():
		var r: int = int(d.secciones[s]["rama"])
		por_rama[r] += cuentas[s]
		tot_rama[r] += totales[s]
		var fs: Dictionary = _filas_sec[s]
		(fs["lbl"] as Label).text = "%d/%d" % [cuentas[s], totales[s]]
	for r in d.ramas.size():
		(_btns_rama[r] as Button).text = "%s  %d/%d" % [String(d.ramas[r]["nombre"]), por_rama[r], tot_rama[r]]
	var tid := _tid()
	var t := "Año del reloj: %s · la historia conoce %s de %s descubrimientos" % [d.anio_texto(main.reloj.anio), _miles(d.cuenta_f), _miles(d.n)]
	if tid >= 0:
		t += " · %s conoce %s" % [main.mundo.jugador, _miles(d.cantidad(tid))]
	else:
		t += " (sin país: se muestra lo que sabe la historia)"
	_lbl_info.text = t


func _filtrar() -> void:
	var tipo := String(_opt_tipo.get_item_metadata(_opt_tipo.selected))
	grafo.fijar_filtros(_opt_estado.selected, tipo)


# ─────────────────────────────────────────────────────────────
# Búsqueda
# ─────────────────────────────────────────────────────────────
func _buscar() -> void:
	var q := _busca.text.strip_edges()
	for h in _lista_res.get_children():
		_lista_res.remove_child(h)
		h.queue_free()
	resultados = 0
	if q.length() < 2:
		_sc_res.visible = false
		_sc_sec.visible = true
		_tit_izq.text = "SECCIONES · %s" % String(d.ramas[rama_sel]["nombre"]).to_upper()
		return
	var tid := _tid()
	var hallados: PackedInt32Array = d.buscar(q, MAX_RESULTADOS)
	_sc_sec.visible = false
	_sc_res.visible = true
	_tit_izq.text = "RESULTADOS: %d%s" % [hallados.size(), "+" if hallados.size() >= MAX_RESULTADOS else ""]
	for i in hallados:
		var e: int = grafo.estado_nodo(i)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text = "%s %s · %s" % ["✓" if d.conoce(tid, i) else "·", d.anio_texto(int(d.anio[i])), String(d.nombre[i])]
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Tema.color_rol(String(ROL_ESTADO[e])))
		b.add_theme_color_override("font_hover_color", Tema.color_rol(String(ROL_ESTADO[e])).lightened(0.25))
		b.tooltip_text = "%s\n%s › %s" % [String(d.nombre[i]), String(d.ramas[int(d.secciones[int(d.seccion[i])]["rama"])]["nombre"]), String(d.secciones[int(d.seccion[i])]["nombre"])]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(ir_a.bind(i))
		_lista_res.add_child(b)
		resultados += 1


# ─────────────────────────────────────────────────────────────
# Ficha
# ─────────────────────────────────────────────────────────────
func _al_elegir_nodo(i: int) -> void:
	_armar_ficha(i)


## Lleva la ventana a un descubrimiento (cambia de rama y sección si hace falta), lo centra en el árbol y muestra su ficha.
func ir_a(i: int) -> void:
	if i < 0 or i >= d.n:
		return
	var s: int = int(d.seccion[i])
	if s != sec_sel:
		_elegir_seccion(s)
	grafo.elegir(i, true)
	_armar_ficha(i)


func _armar_ficha(i: int) -> void:
	for h in _ficha.get_children():
		_ficha.remove_child(h)
		h.queue_free()
	filas_ficha = 0
	if i < 0:
		_ficha_general()
		return
	var tid := _tid()
	var e: int = grafo.estado_nodo(i)
	var t := vf.lbl_rol(String(d.nombre[i]), 16, "oro")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if "fuente_ui_neg" in main:
		t.add_theme_font_override("font", main.fuente_ui_neg)
	_ficha.add_child(t)
	var est := vf.lbl_rol(_texto_estado(i, e, tid), 12, String(ROL_ESTADO[e]))
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
	var ld := vf.lbl_rol(datos, 12, "texto")
	ld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha.add_child(ld)
	if String(d.tipo[i]) == "B":
		var lb := vf.lbl_rol("Es un edificio: se construye desde la ventana Construir (tecla B).", 11, "nota")
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ficha.add_child(lb)
	_ficha.add_child(HSeparator.new())
	# lo que REQUIERE
	_ficha.add_child(vf.lbl_rol("REQUIERE", 11, "oro"))
	var hay := false
	for r in d.req[i]:
		_ficha.add_child(_fila_relacion(int(r), tid, ""))
		hay = true
	for g in d.req_o[i]:
		if g.size() == 1:
			_ficha.add_child(_fila_relacion(int(g[0]), tid, ""))
		else:
			_ficha.add_child(vf.lbl_rol("Basta uno de:", 11, "nota"))
			for r2 in g:
				_ficha.add_child(_fila_relacion(int(r2), tid, "   "))
		hay = true
	if not hay:
		_ficha.add_child(vf.lbl_rol("Nada: es una raíz del árbol.", 12, "tenue"))
	_ficha.add_child(HSeparator.new())
	# lo que ABRE
	var abre: PackedInt32Array = d.dependientes[i]
	_ficha.add_child(vf.lbl_rol("ABRE (%d)" % abre.size(), 11, "oro"))
	if abre.is_empty():
		_ficha.add_child(vf.lbl_rol("Nada todavía: es una punta del árbol.", 12, "tenue"))
	for k in mini(abre.size(), MAX_RELACIONES):
		_ficha.add_child(_fila_relacion(int(abre[k]), tid, ""))
	if abre.size() > MAX_RELACIONES:
		_ficha.add_child(vf.lbl_rol("…y %d más." % (abre.size() - MAX_RELACIONES), 12, "tenue"))


func _ficha_general() -> void:
	var tid := _tid()
	var s := sec_sel
	var t := vf.lbl_rol(String(d.secciones[s]["nombre"]), 16, "oro")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if "fuente_ui_neg" in main:
		t.add_theme_font_override("font", main.fuente_ui_neg)
	_ficha.add_child(t)
	var ds := vf.lbl_rol(String(d.secciones[s].get("desc", "")), 12, "texto")
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha.add_child(ds)
	var n_c := 0
	var n_d := 0
	var n_b := 0
	var n_l := 0
	for i in grafo.nodos:
		match grafo.estado_nodo(i):
			GrafoScript.E_CONOCIDO:
				n_c += 1
			GrafoScript.E_DISPONIBLE:
				n_d += 1
			GrafoScript.E_LEJANO:
				n_l += 1
			_:
				n_b += 1
	var rs := vf.lbl_rol("%d descubrimientos\nConocidos: %d\nDisponibles: %d\nBloqueados: %d\nAún lejanos: %d" % [grafo.nodos.size(), n_c, n_d, n_b, n_l], 12, "texto")
	_ficha.add_child(rs)
	_ficha.add_child(HSeparator.new())
	var ay := vf.lbl_rol("Pulsa un descubrimiento del árbol para ver su año, lo que requiere y lo que abre.\n\nRueda del ratón: acercar o alejar.\nArrastrar: mover el árbol.\nPasar el ratón por encima resalta su cadena: lo que hace falta para llegar a él y lo que él abre (colores en la leyenda de abajo).", 12, "tenue")
	ay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha.add_child(ay)


func _texto_estado(i: int, e: int, tid: int) -> String:
	match e:
		GrafoScript.E_CONOCIDO:
			return "Conocido"
		GrafoScript.E_DISPONIBLE:
			return "Disponible: ya tiene todos sus prerrequisitos."
		GrafoScript.E_LEJANO:
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


## Una fila de la ficha: el descubrimiento `r` con su estado (✓ lo conoce, · no) y su año; al pulsarla la ventana va a él.
func _fila_relacion(r: int, tid: int, sangria: String) -> Button:
	var e: int = grafo.estado_nodo(r)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text = "%s%s %s" % [sangria, "✓" if d.conoce(tid, r) else "·", String(d.nombre[r])]
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Tema.color_rol(String(ROL_ESTADO[e])))
	b.add_theme_color_override("font_hover_color", Tema.color_rol(String(ROL_ESTADO[e])).lightened(0.25))
	var sr: int = int(d.seccion[r])
	b.tooltip_text = "%s\n%s · %s\n%s › %s\nClic: ir a este descubrimiento" % [String(d.nombre[r]), d.anio_texto(int(d.anio[r])), String(GrafoScript.NOMBRE_ESTADO[e]),
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


## Si cambió lo que sabe el país (o la fecha), se ponen al día contadores, árbol y ficha. Si no cambió nada, no hace nada.
func refrescar() -> void:
	if d == null or grafo == null:
		return
	var tid := _tid()
	var firma := "%d|%d|%d|%d" % [tid, d.anio_actual, d.cuenta_f, d.cantidad(tid)]
	if firma == _firma:
		return
	_firma = firma
	_contar()
	_actualizar_textos()
	grafo.fijar_tid(tid)
	_armar_ficha(grafo.sel)


func aplicar_tema() -> void:
	if vf == null:
		return
	vf.aplicar_tema()
	if grafo != null:
		grafo.queue_redraw()
		_armar_ficha(grafo.sel)
		if _sc_res.visible:
			_buscar()
