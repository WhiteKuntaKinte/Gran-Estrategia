extends Node
## Menú DEBUG 0.1.7.9.9D — OVERLAY: ventana flotante que se abre/cierra con el botón del bicho (arriba a la izquierda) o F1,
## sin pausar el juego, sin oscurecer ni bloquear el mapa (solo captura los clics que caen sobre ella) y arrastrable.
## Cambios hechos aquí se ven al instante y quedan en el historial de la base de datos con el motivo «Debug».
##   · Jugador: elegir qué país controlas.            · Anexar: un país entero pasa a ser de otro.
##   · Provincia: transferir y cambiar favorabilidad, población, multiplicador y velocidad de desarrollo.
##   · Tiempo: velocidades 0-6, fijar fecha, avanzar días, dar dinero e impuestos del país que controlas.
##   · Mundo: mecánicas globales (crecimiento base anual, desarrollo de tu país) y simulaciones rápidas.
##   · Datos: inspector de la base de datos (ID, cadena de IDs, variables y su historial) de lo seleccionado en el mapa.
##   · Historia: entidades políticas de cualquier época, sus nombres, banderas y gobernantes, y cómo se llamaba / de quién
##     era lo que seleccionaste en el mapa en la fecha que elijas.
##   · Ejército: reclutar, aplicar bajas, mover pelotones, disolver tropas, fijar la devastación de la provincia y pasar un mes
##     de servicio (envejecen, ganan experiencia). Usa las mismas funciones que usará la guerra (scripts/ejercito.gd).
##   · Rendimiento: tu tarjeta gráfica, FPS en vivo, apagar capas del mapa una por una para ver cuál cuesta más, y una «Prueba de zoom»
##     que recorre todo el zoom midiendo FPS y deja un informe que se copia para pegarlo en el chat.
## No guarda nada: es una herramienta de pruebas. Todo vive en `main.mundo` (scripts/entidades.gd).

signal cerrado

const VentanaScript := preload("res://scripts/ventana_flotante.gd")
const BDScript := preload("res://scripts/base_datos.gd")
const C_ORO := Color(0.93, 0.78, 0.28)
const C_TEXTO := Color(0.95, 0.97, 1.0)
const C_TENUE := Color(0.62, 0.70, 0.86)
const C_OK := Color(0.45, 0.92, 0.55)
const Tema := preload("res://scripts/tema_hud.gd")
## 0.1.8.38 · Las secciones del Debug: [clave, título, icono, descripción corta]. La pantalla de inicio es una cuadrícula de tarjetas con estas secciones.
const SECCIONES := [
	["jugador", "Jugador", "i_pais", "Elige con qué país juegas, o suéltalo para solo observar."],
	["ia", "IA", "i_gob", "Qué países maneja la IA y cuántos hay activos."],
	["anexar", "Anexar", "i_cont", "Pasa un país a manos de otro."],
	["prov", "Provincia", "i_prov", "Busca una provincia: dueño, población y forma del territorio."],
	["tiempo", "Tiempo", "i_vel3", "Fecha del juego, velocidad del reloj y dinero."],
	["mundo", "Mundo", "i_pob", "Ritmo de desarrollo y población de todo el mundo."],
	["datos", "Datos", "i_info", "Los valores del territorio elegido y su historial."],
	["historia", "Historia", "i_desc", "Viaja a una fecha: qué estados existían y quién gobernaba."],
	["ejercito", "Ejército", "i_ejercito", "Reclutar, causar bajas, mover pelotones y devastar."],
	["edif", "Edificios", "i_prov", "Da o quita edificios, termina obras y cambia los cores de lo elegido."],
	["desc", "Descub.", "i_estrella", "Busca descubrimientos y concede o quita los de cada fecha."],
	["rend", "Rend.", "i_dens", "Tu equipo, los FPS y qué capas apagar para ir más ligero."],
]

var main
var fuente: Font
var vf: VentanaScript
var contenedor: Control
var paginas := {}
var pestana_actual := ""                  # "" = la cuadrícula de inicio; si no, la clave de la sección abierta
var pagina_menu: ScrollContainer          # 0.1.8.38: la cuadrícula de secciones (pantalla de inicio)
var caja_migas: HBoxContainer             # «Menú Debug › Sección» (con el botón ← para volver a la cuadrícula)
var _tarjetas: Dictionary = {}            # clave de sección -> botón-tarjeta de la cuadrícula
var lbl_msg: Label
var chk_seguir: CheckBox

# Jugador
var sel_jugador := {}
var lbl_info_jugador: Label
var lbl_actual: Label
var pais_jug := ""

# IA (0.1.8.2)
var chk_ia := {}                    # nombre de país -> CheckBox
var lbl_ia_resumen: Label
var lbl_ia_sel: Label
var filtro_ia: LineEdit
var _t_ia := 0.0

# Anexar
var sel_a := {}
var sel_b := {}
var pais_a := ""
var pais_b := ""
var lbl_info_anexar: Label

# Provincia
var prov_sel := -1
var filtro_prov: LineEdit
var lista_prov: ItemList
var ids_lista_prov: Array = []
var planos_prov: Array = []
var lbl_info_prov: Label
var sl_fav: HSlider
var lbl_fav: Label
var sl_mult: HSlider
var lbl_mult: Label
var sl_vprov: HSlider
var lbl_vprov: Label
var sp_pob: SpinBox
var sel_dest := {}
var pais_dest := ""
var btn_transferir: Button
var lbl_terr: Label                  # 0.1.8.35: forma del territorio (celdas de la provincia elegida)
var opt_vecina: OptionButton
var ids_vecinas: Array = []

# Tiempo
var sp_anio: SpinBox
var sp_mes: SpinBox
var sp_dia: SpinBox
var lbl_tiempo: Label
var sl_tasa: HSlider
var lbl_tasa: Label
var botones_vel := []

# Mundo
var sl_base: HSlider
var lbl_base: Label
var sl_vpais: HSlider
var lbl_vpais: Label
var lbl_mundo: Label

# Datos
var tid_datos := -1
var lbl_datos: Label
var opt_var: OptionButton
var lbl_hist: Label
var nombres_var: Array = []

# Historia
var sp_h_anio: SpinBox
var sp_h_mes: SpinBox
var sp_h_dia: SpinBox
var filtro_hist: LineEdit
var lista_hist: ItemList
var ids_lista_hist: Array = []
var ent_hist_sel := -1
var lbl_hist_res: Label
var lbl_hist_lista: Label
var lbl_hist_ficha: Label
var img_hist_bandera: TextureRect
var lbl_hist_mapa: Label

# Ejército
var lbl_ej_info: Label
var sp_ej_reclutar: SpinBox
var sp_ej_baja: SpinBox
var sp_ej_mover: SpinBox
var sl_ej_dev: HSlider
var lbl_ej_dev: Label
var _ej_bloquea := false

# Rendimiento
const CAPAS_REND := [["relleno", "Relleno de países"], ["mar", "Mar"], ["lagos", "Lagos"], ["costa", "Costa"], ["fronteras", "Fronteras"],
	["nombres", "Nombres de países"], ["ciudades", "Ciudades"], ["tropas", "Tropas"]]
# 0.1.8.36: pestaña Descubrimientos
var lbl_desc_res: Label
var lbl_desc_lista: Label
var lbl_desc_ficha: Label
var filtro_desc: LineEdit
var lista_desc: ItemList
# Edificios y cores (0.1.8.40)
var lbl_edif_res: Label
var filtro_edif: LineEdit
var lista_edif: ItemList
var ids_lista_edif: Array = []
var edif_sel := -1
var lbl_edif_ficha: Label
var sel_core := {}
var pais_core := ""
var opt_cultura: OptionButton
var ids_cultura: Array = []
var ids_lista_desc: Array = []
var desc_sel := -1

var lbl_rend: Label
var lbl_rend_hw: Label
var lbl_rend_informe: Label
var chk_capas := {}
var btn_prueba: Button
var btn_grabar: Button                # 0.1.8.39 · grabador de rendimiento
var lbl_grab: Label
var _t_rend := 0.0
var _prueba_en_curso := false
var _informe := ""


func construir(m: Node, f: Font) -> void:
	main = m
	fuente = f
	process_mode = Node.PROCESS_MODE_ALWAYS
	vf = VentanaScript.new()
	add_child(vf)
	var vp := get_viewport().get_visible_rect().size
	var tam := Vector2(minf(470.0, vp.x - 24.0), minf(560.0, vp.y - 100.0))          # 0.1.8.3: más chica de arranque; se ensancha con « » o arrastrando ◢
	vf.construir(main, fuente, "MENÚ DEBUG", tam, Vector2(maxf(vp.x - tam.x - 12.0, 8.0), 66.0), "i_debug", "debug")
	vf.cerrada.connect(func(): cerrado.emit())
	var cont: VBoxContainer = vf.contenido

	var intro := _lbl("Herramienta de pruebas · no se guarda · el juego sigue corriendo · F1 abre/cierra", 11, C_TENUE)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART          # 0.1.8.3: se parte en líneas para que la ventana pueda angostarse
	intro.custom_minimum_size = Vector2(10.0, 0.0)
	cont.add_child(intro)

	caja_migas = HBoxContainer.new()
	caja_migas.add_theme_constant_override("separation", 4)
	cont.add_child(caja_migas)

	contenedor = Control.new()
	contenedor.custom_minimum_size = Vector2(0.0, 140.0)
	contenedor.clip_contents = true
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cont.add_child(contenedor)

	chk_seguir = CheckBox.new()
	chk_seguir.text = "Seguir lo que selecciono en el mapa"
	chk_seguir.button_pressed = true
	chk_seguir.focus_mode = Control.FOCUS_NONE
	chk_seguir.add_theme_font_size_override("font_size", 12)
	cont.add_child(chk_seguir)

	lbl_msg = _lbl("", 12, C_OK)
	lbl_msg.custom_minimum_size = Vector2(0.0, 34.0)
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cont.add_child(lbl_msg)

	_construir_cuadricula()
	_pagina_jugador()
	_pagina_ia()
	_pagina_anexar()
	_pagina_provincias()
	_pagina_tiempo()
	_pagina_mundo()
	_pagina_datos()
	_pagina_historia()
	_pagina_ejercito()
	_pagina_descubrimientos()
	_pagina_edificios()
	_pagina_rendimiento()
	_ir_menu()
	if main.mundo.jugador != "":
		_seleccionar_en(sel_jugador, main.mundo.jugador)
	_decir("Elige una sección. Arrastra la barra de título para mover la ventana.")
	seleccion_cambio(String(main.sel_tipo))
	_sin_foco(vf.ventana)


## Pulsar fuera de la ventana suelta el foco de cualquier cuadro de texto, para que las teclas del juego vuelvan a funcionar.
func _input(ev: InputEvent) -> void:
	if vf != null and ev is InputEventMouseButton and ev.pressed:
		if not vf.ventana.get_global_rect().has_point(ev.position):
			var f: Control = get_viewport().gui_get_focus_owner()
			if f != null:
				f.release_focus()


## Ningún botón del overlay debe quedarse con el foco: Espacio, 1-6, V y Retroceso tienen que seguir llegando al juego.
func _sin_foco(n: Node) -> void:
	if n is BaseButton:
		(n as BaseButton).focus_mode = Control.FOCUS_NONE
	for h in n.get_children():
		_sin_foco(h)


# ───────────── Cuadrícula de inicio y migas (0.1.8.38) ─────────────
func _construir_cuadricula() -> void:
	pagina_menu = ScrollContainer.new()
	pagina_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pagina_menu.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contenedor.add_child(pagina_menu)
	var fila := HFlowContainer.new()
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_theme_constant_override("h_separation", 8)
	fila.add_theme_constant_override("v_separation", 8)
	pagina_menu.add_child(fila)
	for sec in SECCIONES:
		var b := _tarjeta(String(sec[0]), String(sec[1]), String(sec[2]), String(sec[3]))
		_tarjetas[String(sec[0])] = b
		fila.add_child(b)


## Una tarjeta de la cuadrícula: icono, título y una línea que dice para qué sirve la sección.
func _tarjeta(clave: String, titulo: String, icono: String, desc: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150.0, 104.0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = desc
	b.pressed.connect(func(): _ir_a(clave))
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for lado in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + lado, 9)
	b.add_child(mc)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 3)
	mc.add_child(vb)
	var cab := HBoxContainer.new()
	cab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cab.add_theme_constant_override("separation", 6)
	vb.add_child(cab)
	var ic := TextureRect.new()
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.texture = main.icono(icono)
	ic.custom_minimum_size = Vector2(20.0, 20.0)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cab.add_child(ic)
	var t := _lbl(titulo, 15, C_TEXTO)
	if "fuente_ui_neg" in main:
		t.add_theme_font_override("font", main.fuente_ui_neg)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cab.add_child(t)
	var d := vf.lbl_rol(desc, 11, "nota")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(120.0, 0.0)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(d)
	_pintar_tarjeta(b)
	return b


func _pintar_tarjeta(b: Button) -> void:
	b.add_theme_stylebox_override("normal", Tema.tarjeta(false, 0.0))
	b.add_theme_stylebox_override("hover", Tema.tarjeta(true, 0.0))
	b.add_theme_stylebox_override("pressed", Tema.tarjeta(true, 0.0))
	b.add_theme_stylebox_override("hover_pressed", Tema.tarjeta(true, 0.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## «← Menú Debug › Sección»: el botón ← y la miga «Menú Debug» vuelven a la cuadrícula; la sección actual es solo texto.
func _dibujar_migas() -> void:
	for h in caja_migas.get_children():
		caja_migas.remove_child(h)
		h.queue_free()
	if pestana_actual != "":
		var volver := vf.boton("←", _ir_menu)
		volver.custom_minimum_size = Vector2(34.0, 28.0)
		volver.tooltip_text = "Volver al menú del Debug"
		caja_migas.add_child(volver)
	var raiz_miga := Button.new()
	raiz_miga.text = "Menú Debug"
	raiz_miga.flat = true
	raiz_miga.focus_mode = Control.FOCUS_NONE
	raiz_miga.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	raiz_miga.disabled = pestana_actual == ""
	raiz_miga.add_theme_font_size_override("font_size", 14)
	raiz_miga.add_theme_color_override("font_color", Tema.ORO)
	raiz_miga.add_theme_color_override("font_hover_color", Tema.ORO.lightened(0.25))
	raiz_miga.add_theme_color_override("font_disabled_color", Tema.ORO)
	raiz_miga.pressed.connect(_ir_menu)
	caja_migas.add_child(raiz_miga)
	if pestana_actual != "":
		caja_migas.add_child(vf.lbl_rol("›", 14, "tenue"))
		var nombre := pestana_actual
		for sec in SECCIONES:
			if sec[0] == pestana_actual:
				nombre = String(sec[1])
		var actual := vf.lbl_rol(nombre, 14, "texto")
		if "fuente_ui_neg" in main:
			actual.add_theme_font_override("font", main.fuente_ui_neg)
		caja_migas.add_child(actual)
	_sin_foco(caja_migas)


## Cambio de tema en vivo: la ventana, las tarjetas y las migas se vuelven a pintar (los textos con rol se repintan solos).
func aplicar_tema() -> void:
	if vf == null:
		return
	vf.aplicar_tema()
	for k in _tarjetas:
		_pintar_tarjeta(_tarjetas[k])
	_dibujar_migas()


# ───────────── utilidades ─────────────
## Un texto del Debug. Los cuatro colores de siempre (oro, texto, tenue, ok) son ahora roles del tema (cambian solos con el tema); cualquier otro color se respeta tal cual.
func _lbl(t: String, tam: int, col: Color) -> Label:
	var rol := _rol_de(col)
	if rol != "":
		return vf.lbl_rol(t, tam, rol)
	return vf.lbl(t, tam, col)


func _rol_de(col: Color) -> String:
	if col == C_ORO:
		return "oro"
	if col == C_TEXTO:
		return "texto"
	if col == C_TENUE:
		return "tenue"
	if col == C_OK:
		return "ok"
	return ""


func _boton(t: String, accion: Callable) -> Button:
	return vf.boton(t, accion)


func _decir(t: String, ok := true) -> void:
	lbl_msg.text = t
	Tema.rotular(lbl_msg, "ok" if ok else "mal")


## Ejecuta un cambio marcándolo en el historial de la base de datos con el motivo «Debug».
func _dbg(accion: Callable) -> void:
	var bd = main.mundo.bd
	var m0: String = bd.motivo_ctx
	bd.motivo_ctx = "Debug"
	accion.call()
	bd.motivo_ctx = m0


## La cuadrícula de inicio del Debug (0.1.8.38).
func _ir_menu() -> void:
	pestana_actual = ""
	for k in paginas:
		paginas[k].visible = false
	pagina_menu.visible = true
	chk_seguir.visible = false
	_dibujar_migas()


func _ir_a(clave: String) -> void:
	pestana_actual = clave
	pagina_menu.visible = false
	chk_seguir.visible = true
	for k in paginas:
		paginas[k].visible = (k == clave)
	_dibujar_migas()
	match clave:
		"jugador":
			_refrescar_jugador()
		"ia":
			_refrescar_ia()
		"tiempo":
			_refrescar_tiempo()
		"prov":
			_mostrar_prov()
		"mundo":
			_refrescar_mundo_pagina()
		"datos":
			_refrescar_datos()
		"historia":
			_refrescar_historia()
		"ejercito":
			_refrescar_ejercito_pagina()
		"desc":
			_refrescar_desc()
		"edif":
			_refrescar_edif()
		"rend":
			_refrescar_rend()


func _process(delta: float) -> void:
	if pestana_actual == "ia" and lbl_ia_resumen != null and paginas["ia"].is_visible_in_tree():
		_t_ia += delta
		if _t_ia >= 0.7:
			_t_ia = 0.0
			_refrescar_ia()
	if pestana_actual != "rend" or lbl_rend == null or not paginas["rend"].is_visible_in_tree():
		return
	_t_rend += delta
	if _t_rend >= 0.5:
		_t_rend = 0.0
		_refrescar_rend()


func _nueva_pagina(clave: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO          # 0.1.8.3: si la ventana se angosta más que el contenido, sale barra horizontal (no se corta)
	sc.visible = false
	contenedor.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	sc.add_child(vb)
	paginas[clave] = sc
	return vb


func _plano(s: String) -> String:
	var r := s.to_lower()
	for par in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"], ["ç", "c"]]:
		r = r.replace(par[0], par[1])
	return r


## Selector de países con buscador. Devuelve {caja, lista, filtro}. `al_seleccionar(nombre)` se llama al elegir uno.
func _selector_pais(titulo: String, alto: float, al_seleccionar: Callable) -> Dictionary:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_child(_lbl(titulo, 13, C_ORO))
	var filtro := LineEdit.new()
	filtro.placeholder_text = "Buscar país…"
	filtro.clear_button_enabled = true
	caja.add_child(filtro)
	var lista := ItemList.new()
	lista.custom_minimum_size = Vector2(0.0, alto)
	lista.select_mode = ItemList.SELECT_SINGLE
	caja.add_child(lista)
	var nombres: Array = main.mundo.campana.keys() if main.mundo.es_campana() else main.mundo.paises.keys()      # en la campaña solo juegan 51 países
	nombres.sort()
	var d := {"caja": caja, "lista": lista, "filtro": filtro, "nombres": nombres}
	var llenar := func(q: String):
		lista.clear()
		var qq := _plano(q.strip_edges())
		for n in nombres:
			if qq == "" or _plano(String(n)).contains(qq):
				lista.add_item(String(n))
	filtro.text_changed.connect(llenar)
	lista.item_selected.connect(func(i: int): al_seleccionar.call(lista.get_item_text(i)))
	llenar.call("")
	d["llenar"] = llenar
	return d


func _seleccionar_en(sel: Dictionary, nombre: String) -> void:
	var filtro: LineEdit = sel["filtro"]
	var lista: ItemList = sel["lista"]
	filtro.text = ""
	sel["llenar"].call("")
	for i in lista.item_count:
		if lista.get_item_text(i) == nombre:
			lista.select(i)
			lista.call_deferred("ensure_current_is_visible")
			lista.item_selected.emit(i)
			return


func _texto_pais(p: String) -> String:
	var m = main.mundo
	if p == "" or not m.paises.has(p):
		return "Elige un país en la lista."
	var e = m.paises[p]
	var dv = m.divisa_de(p)
	var sim: String = main._simbolo_de(p)
	var t := "%s  (ID %d)\n" % [p, e.tid]
	t += "Continente: %s\n" % e.continente
	if dv != null:
		t += "Divisa: %s (%s) · %s\n" % [dv.nombre, dv.simbolo, main.fmt_cambio(dv)]
	t += "Provincias: %d · Ciudades: %d\n" % [e.provincias.size(), e.ciudades.size()]
	t += "Población: %s\n" % main.hud.fmt_pob(m.poblacion_de(p))
	t += "PIB (referencia %d): %s\n" % [main.epoca, main.fmt_dinero(e.pib_usd, "US$")]
	t += "Producción anual de sus provincias: %s\n" % main.fmt_dinero(m.produccion_anual_usd(p), "US$")
	t += "Ingresos del estado: %s por día\n" % main.fmt_dinero(m.ingreso_diario_local(p), sim)
	t += "Tesorería: %s\n" % main.fmt_dinero(e.tesoreria, sim)
	if e.anexado_a != "":
		t += "ESTADO: anexado a %s (ya no tiene provincias)\n" % e.anexado_a
	var ajenos: Array = m.origenes_ajenos(p)
	if not ajenos.is_empty():
		t += "Tiene provincias de: %s\n" % ", ".join(PackedStringArray(ajenos))
	return t


# ───────────── Selección del mapa (la llama MapaPrincipal al seleccionar algo) ─────────────
func seleccion_cambio(tipo: String) -> void:
	if chk_seguir == null or not chk_seguir.button_pressed:
		return
	match tipo:
		"provincia", "ciudad":
			var pi: int = main.debug_provincia_seleccionada()
			if pi >= 0:
				prov_sel = pi
				if pestana_actual == "prov":
					_mostrar_prov()
		"pais", "estado":
			var p: String = main.debug_pais_seleccionado()
			if p != "" and pestana_actual == "jugador":
				_seleccionar_en(sel_jugador, p)
	if pestana_actual == "ia":
		_refrescar_ia()
	tid_datos = int(main.debug_tid_seleccionado())
	if pestana_actual == "datos":
		_refrescar_datos()
	elif pestana_actual == "historia":
		_refrescar_historia_mapa()
	elif pestana_actual == "ejercito":
		_refrescar_ejercito_pagina()
	elif pestana_actual == "edif":
		_refrescar_edif()


# ───────────── Pestaña Jugador ─────────────
func _pagina_jugador() -> void:
	var pg := _nueva_pagina("jugador")
	lbl_actual = _lbl("", 15, C_OK)
	pg.add_child(lbl_actual)
	sel_jugador = _selector_pais("País que quieres controlar", 110.0, func(n: String):
		pais_jug = n
		lbl_info_jugador.text = _texto_pais(n))
	pg.add_child(sel_jugador["caja"])
	pg.add_child(_boton("← Usar el país seleccionado en el mapa", func():
		var p: String = main.debug_pais_seleccionado()
		if p == "":
			_decir("No hay ningún país seleccionado en el mapa: pulsa uno primero.", false)
			return
		_seleccionar_en(sel_jugador, p)))
	lbl_info_jugador = _lbl("Elige un país en la lista.", 13, C_TEXTO)
	lbl_info_jugador.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_info_jugador)
	pg.add_child(_boton("CONTROLAR ESTE PAÍS", func():
		if pais_jug == "":
			_decir("Primero elige un país de la lista.", false)
			return
		main.debug_controlar(pais_jug)
		_decir("Ahora controlas %s. Su dinero y sus ingresos aparecen en la barra de arriba." % pais_jug)
		_refrescar_jugador()
		lbl_info_jugador.text = _texto_pais(pais_jug)))
	pg.add_child(_boton("DEJAR DE CONTROLAR (modo observador)", func():
		main.debug_controlar("")
		_decir("Modo observador: no controlas ningún país.")
		_refrescar_jugador()))
	pg.add_child(_boton("Personalizar mi país… (nombre, moneda, impuestos, desarrollo)", func(): main._abrir_personalizar()))
	_refrescar_jugador()


func _refrescar_jugador() -> void:
	var j: String = main.mundo.jugador
	lbl_actual.text = "Controlas: %s" % (j if j != "" else "ningún país (observador)")


# ───────────── Pestaña IA (0.1.8.2) ─────────────
## Qué países los lleva el ordenador. Ninguno al arrancar. Una IA recluta con presupuesto, declara guerras, ataca y pide la paz (scripts/ia.gd).
func _pagina_ia() -> void:
	var pg := _nueva_pagina("ia")
	var ia = main.mundo.ia
	var nota := _lbl("Marca los países que quieres que juegue la IA. En el modo libre ninguno la tiene por defecto (así va más ligero); en la campaña la llevan todos menos el tuyo. Si sueltas el país que controlas (o eliges otro), la IA lo toma sola. En la campaña solo se pueden conquistar países con IA y tú.", 12, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)
	lbl_ia_resumen = _lbl("", 13, C_OK)
	lbl_ia_resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_ia_resumen)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	pg.add_child(fila)
	var b1 := _boton("Todas", func():
		var n: int = ia.activar_lista(ia.candidatos())
		_decir("IA activada en %d países." % n)
		_refrescar_ia())
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(b1)
	var b2 := _boton("Vecinas de mi país", func():
		var j: String = main.mundo.jugador
		if j == "":
			_decir("Primero elige el país que controlas (pestaña Jugador).", false)
			return
		var n2: int = ia.activar_lista(ia.vecinos_de(j))
		_decir("IA activada en los %d países que tocan a %s." % [n2, j])
		_refrescar_ia())
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(b2)
	var b3 := _boton("Ninguna", func():
		ia.desactivar_todas()
		_decir("Ninguna IA activa." + (" Sus guerras terminaron en paz." if main.mundo.es_campana() else ""))
		_refrescar_ia())
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(b3)
	filtro_ia = LineEdit.new()
	filtro_ia.placeholder_text = "Buscar país…"
	filtro_ia.clear_button_enabled = true
	filtro_ia.text_changed.connect(func(q: String):
		var qq := _plano(q.strip_edges())
		for n in chk_ia:
			(chk_ia[n] as CheckBox).visible = qq == "" or _plano(String(n)).contains(qq))
	pg.add_child(filtro_ia)
	lbl_ia_sel = _lbl("", 12, C_TEXTO)
	lbl_ia_sel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_ia_sel)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 2)
	pg.add_child(lista)
	chk_ia = {}
	var nombres: Array = main.mundo.campana.keys() if main.mundo.es_campana() else main.mundo.paises.keys()
	nombres.sort()
	for n in nombres:
		var nombre: String = String(n)
		if (main.mundo.paises[nombre].provincias as Array).is_empty():
			continue
		var c := CheckBox.new()
		c.text = nombre
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_size_override("font_size", 12)
		c.toggled.connect(func(activo: bool):
			if activo:
				if not ia.activar(nombre):
					(chk_ia[nombre] as CheckBox).set_pressed_no_signal(false)
					_decir("%s no puede tener IA (es el país que controlas o ya no existe)." % nombre, false)
					return
				_decir("IA activada en %s." % nombre)
			else:
				ia.desactivar(nombre)
				_decir("IA apagada en %s." % nombre)
			_refrescar_ia())
		chk_ia[nombre] = c
		lista.add_child(c)
	_refrescar_ia()


func _refrescar_ia() -> void:
	if lbl_ia_resumen == null:
		return
	var m = main.mundo
	var ia = m.ia
	for n in chk_ia:
		var c: CheckBox = chk_ia[n]
		var debe: bool = ia.activas.has(n)
		if c.button_pressed != debe:
			c.set_pressed_no_signal(debe)
		c.disabled = (n == m.jugador)
	var en_guerra := 0
	for n in ia.activas:
		if not m.guerra.rivales_de(int(ia.activas[n]["tid"])).is_empty():
			en_guerra += 1
	lbl_ia_resumen.text = "IA activa en %d países (%d en guerra) · decisiones %d · guerras declaradas %d · paces %d\nCosto de la IA: %.2f ms el último día (máx. %.1f ms)" % [
		ia.activas.size(), en_guerra, ia.decisiones, ia.guerras_declaradas, ia.paces_firmadas, ia.ms_dia, ia.ms_max]
	var p: String = main.debug_pais_seleccionado()
	if p != "" and m.paises.has(p):
		lbl_ia_sel.text = "%s: %s" % [p, ia.texto_estado(p)]
	else:
		lbl_ia_sel.text = "Selecciona un país en el mapa para ver qué está haciendo su IA."


# ───────────── Pestaña Anexar ─────────────
func _pagina_anexar() -> void:
	var pg := _nueva_pagina("anexar")
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	pg.add_child(fila)
	sel_a = _selector_pais("A (el que desaparece)", 130.0, func(n: String):
		pais_a = n
		_refrescar_anexar())
	fila.add_child(sel_a["caja"])
	sel_b = _selector_pais("B (el que lo absorbe)", 130.0, func(n: String):
		pais_b = n
		_refrescar_anexar())
	fila.add_child(sel_b["caja"])
	var fila2 := HBoxContainer.new()
	fila2.add_theme_constant_override("separation", 10)
	pg.add_child(fila2)
	var ba := _boton("← A = el del mapa", func():
		var p: String = main.debug_pais_seleccionado()
		if p == "":
			_decir("No hay ningún país seleccionado en el mapa.", false)
			return
		_seleccionar_en(sel_a, p))
	ba.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila2.add_child(ba)
	var bb := _boton("← B = el del mapa", func():
		var p: String = main.debug_pais_seleccionado()
		if p == "":
			_decir("No hay ningún país seleccionado en el mapa.", false)
			return
		_seleccionar_en(sel_b, p))
	bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila2.add_child(bb)
	lbl_info_anexar = _lbl("Elige un país A y un país B.", 13, C_TEXTO)
	lbl_info_anexar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_info_anexar)
	var nota := _lbl("El ID de dueño de todas las provincias de A pasa a ser el de B (con las ciudades). En el mapa toman el color exacto de B y las fronteras se recalculan. Quedan con favorabilidad 35 (recién conquistadas). A se queda SIN provincias, con estado «anexado a B», y su ejército pasa a B.", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)
	pg.add_child(_boton("ANEXAR A  →  B", func():
		if pais_a == "" or pais_b == "":
			_decir("Elige un país A y un país B.", false)
			return
		if pais_a == pais_b:
			_decir("A y B son el mismo país.", false)
			return
		var res := [0]                                  # las lambdas copian las variables simples: el resultado sale por una lista
		_dbg(func(): res[0] = main.debug_anexar(pais_a, pais_b))
		var n: int = res[0]
		if n == 0:
			_decir("%s no tiene provincias que transferir." % pais_a, false)
		else:
			_decir("%s ahora es parte de %s (%d provincias transferidas)." % [pais_a, pais_b, n])
		_refrescar_anexar()))


func _refrescar_anexar() -> void:
	var t := ""
	if pais_a != "":
		t += "A → " + _texto_pais(pais_a) + "\n"
	if pais_b != "":
		t += "B → " + _texto_pais(pais_b)
	lbl_info_anexar.text = t if t != "" else "Elige un país A y un país B."


# ───────────── Pestaña Provincia ─────────────
## Fila etiqueta + deslizador + valor. Devuelve el deslizador; `lbl_out[0]` queda con la etiqueta del valor.
func _fila_slider(pg: Control, titulo: String, mn: float, mx: float, paso: float, al_mover: Callable, al_soltar: Callable, lbl_out: Array) -> HSlider:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 8)
	pg.add_child(f)
	var t := _lbl(titulo, 12, C_TENUE)
	t.custom_minimum_size = Vector2(120.0, 0.0)
	f.add_child(t)
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = paso
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(0.0, 24.0)
	sl.value_changed.connect(al_mover)
	sl.drag_ended.connect(func(_c: bool): al_soltar.call())
	f.add_child(sl)
	var l := _lbl("", 12, C_TEXTO)
	l.custom_minimum_size = Vector2(52.0, 0.0)
	f.add_child(l)
	lbl_out.append(l)
	return sl


func _pagina_provincias() -> void:
	var pg := _nueva_pagina("prov")
	pg.add_child(_lbl("Provincia", 13, C_ORO))
	filtro_prov = LineEdit.new()
	filtro_prov.placeholder_text = "Buscar provincia (ej. antioquia colombia)…"
	filtro_prov.clear_button_enabled = true
	filtro_prov.text_changed.connect(_buscar_prov)
	pg.add_child(filtro_prov)
	lista_prov = ItemList.new()
	lista_prov.custom_minimum_size = Vector2(0.0, 80.0)
	lista_prov.item_selected.connect(func(i: int):
		prov_sel = int(ids_lista_prov[i])
		_mostrar_prov())
	pg.add_child(lista_prov)
	pg.add_child(_boton("← Usar la provincia (o ciudad) seleccionada en el mapa", func():
		var pi: int = main.debug_provincia_seleccionada()
		if pi < 0:
			_decir("No hay provincia seleccionada: elige una (o una ciudad) en el mapa.", false)
			return
		prov_sel = pi
		_mostrar_prov()
		_decir("Provincia elegida: %s." % main.mundo.provincias[pi].nombre)))

	lbl_info_prov = _lbl("Elige una provincia o selecciónala en el mapa.", 13, C_TEXTO)
	lbl_info_prov.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_info_prov)

	var o1 := []
	sl_fav = _fila_slider(pg, "Favorabilidad", 0.0, 100.0, 1.0, func(v: float):
		if prov_sel < 0:
			return
		_dbg(func(): main.mundo.provincias[prov_sel].favorabilidad = v)
		_actualizar_etiquetas_prov(), func(): _refrescar_mundo(false), o1)
	lbl_fav = o1[0]
	var o2 := []
	sl_mult = _fila_slider(pg, "Mult. de ingreso", 0.0, 5.0, 0.05, func(v: float):
		if prov_sel < 0:
			return
		_dbg(func(): main.mundo.provincias[prov_sel].mult_ingreso = v)
		_actualizar_etiquetas_prov(), func(): _refrescar_mundo(false), o2)
	lbl_mult = o2[0]
	var o3 := []
	sl_vprov = _fila_slider(pg, "Veloc. desarrollo", 0.0, 5.0, 0.05, func(v: float):
		if prov_sel < 0:
			return
		_dbg(func(): main.mundo.provincias[prov_sel].velocidad_desarrollo = v)
		_actualizar_etiquetas_prov(), func(): _refrescar_mundo(false), o3)
	lbl_vprov = o3[0]

	var f3 := HBoxContainer.new()
	f3.add_theme_constant_override("separation", 8)
	pg.add_child(f3)
	var t3 := _lbl("Población", 12, C_TENUE)
	t3.custom_minimum_size = Vector2(120.0, 0.0)
	f3.add_child(t3)
	sp_pob = SpinBox.new()
	sp_pob.min_value = 0.0
	sp_pob.max_value = 5.0e9
	sp_pob.step = 1.0
	sp_pob.custom_minimum_size = Vector2(150.0, 0.0)
	sp_pob.value_changed.connect(func(v: float):
		if prov_sel < 0:
			return
		_dbg(func(): main.mundo.provincias[prov_sel].poblacion = v)
		_actualizar_etiquetas_prov()
		_refrescar_mundo(false))
	f3.add_child(sp_pob)
	f3.add_child(_boton("×0,5", func(): _escalar_pob(0.5)))
	f3.add_child(_boton("×2", func(): _escalar_pob(2.0)))

	var f4 := HBoxContainer.new()
	f4.add_theme_constant_override("separation", 6)
	pg.add_child(f4)
	var t4 := _lbl("Favorabilidad de todas las provincias del dueño →", 12, C_TENUE)
	t4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f4.add_child(t4)
	for v in [0, 50, 100]:
		var vv: int = v
		var bb := _boton("%d" % vv, func(): _fav_todas(float(vv)))
		bb.custom_minimum_size = Vector2(46.0, 30.0)
		f4.add_child(bb)

	pg.add_child(HSeparator.new())
	sel_dest = _selector_pais("Transferir esta provincia al país…", 80.0, func(n: String):
		pais_dest = n
		_actualizar_boton_transferir())
	pg.add_child(sel_dest["caja"])
	btn_transferir = _boton("TRANSFERIR", func():
		if prov_sel < 0 or pais_dest == "":
			_decir("Elige una provincia y un país de destino.", false)
			return
		var pr = main.mundo.provincias[prov_sel]
		var antes: String = pr.pais
		var res := [false]
		_dbg(func(): res[0] = main.debug_transferir(prov_sel, pais_dest))
		var ok: bool = res[0]
		if ok:
			_decir("%s pasó de %s a %s (favorabilidad 35)." % [pr.nombre, antes, pais_dest])
		else:
			_decir("%s ya pertenece a %s." % [pr.nombre, pais_dest], false)
		_mostrar_prov())
	pg.add_child(btn_transferir)
	_actualizar_boton_transferir()
	_pagina_territorio(pg)
	_buscar_prov("")


## 0.1.8.35 · Forma del territorio: mover celdas entre provincias vecinas (el mapa cambia al instante; ver scripts/territorio.gd).
func _pagina_territorio(pg: VBoxContainer) -> void:
	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Forma del territorio (celdas)", 13, C_ORO))
	lbl_terr = _lbl("Elige una provincia.", 12, C_TEXTO)
	lbl_terr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_terr)
	var fv := HBoxContainer.new()
	fv.add_theme_constant_override("separation", 6)
	pg.add_child(fv)
	var tv := _lbl("Vecina:", 12, C_TENUE)
	fv.add_child(tv)
	opt_vecina = OptionButton.new()
	opt_vecina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_vecina.clip_text = true
	fv.add_child(opt_vecina)
	var f1 := HFlowContainer.new()
	f1.add_theme_constant_override("h_separation", 6)
	f1.add_theme_constant_override("v_separation", 6)
	pg.add_child(f1)
	f1.add_child(_boton("Cederle ¼", func(): _terr_ceder(0.25)))
	f1.add_child(_boton("Cederle ½", func(): _terr_ceder(0.5)))
	f1.add_child(_boton("Absorberla toda", func(): _terr_absorber()))
	f1.add_child(_boton("Fusionarme en ella", func(): _terr_fusionar_en()))
	var f2 := HFlowContainer.new()
	f2.add_theme_constant_override("h_separation", 6)
	pg.add_child(f2)
	f2.add_child(_boton("Deshacer", func(): _terr_deshacer()))
	f2.add_child(_boton("Restablecer forma", func(): _terr_restablecer()))


func _terr_vecina() -> int:
	if opt_vecina == null or opt_vecina.item_count == 0 or opt_vecina.selected < 0 or opt_vecina.selected >= ids_vecinas.size():
		return -1
	return int(ids_vecinas[opt_vecina.selected])


func _terr_ok() -> bool:
	if main.territorio == null or not main.territorio.listo():
		_decir("El mapa de celdas no está disponible.", false)
		return false
	if prov_sel < 0:
		_decir("Primero elige una provincia.", false)
		return false
	return true


func _terr_tras_cambio(n: int, texto: String) -> void:
	if n <= 0:
		_decir("No cambió nada.", false)
	else:
		_decir(texto)
	_mostrar_prov()
	_refrescar_mundo(false)


func _terr_ceder(fraccion: float) -> void:
	var v := _terr_vecina()
	if not _terr_ok():
		return
	if v < 0:
		_decir("Esta provincia no tiene vecinas.", false)
		return
	var n: int = main.territorio.dividir(prov_sel, v, fraccion)
	_terr_tras_cambio(n, "%d celdas de %s pasaron a %s." % [n, main.mundo.provincias[prov_sel].nombre, main.mundo.provincias[v].nombre])


func _terr_absorber() -> void:
	var v := _terr_vecina()
	if not _terr_ok():
		return
	if v < 0:
		_decir("Esta provincia no tiene vecinas.", false)
		return
	var n: int = main.territorio.fusionar(prov_sel, v)
	_terr_tras_cambio(n, "%s absorbió las %d celdas de %s." % [main.mundo.provincias[prov_sel].nombre, n, main.mundo.provincias[v].nombre])


func _terr_fusionar_en() -> void:
	var v := _terr_vecina()
	if not _terr_ok():
		return
	if v < 0:
		_decir("Esta provincia no tiene vecinas.", false)
		return
	var n: int = main.territorio.fusionar(v, prov_sel)
	_terr_tras_cambio(n, "%s se fusionó en %s (%d celdas)." % [main.mundo.provincias[prov_sel].nombre, main.mundo.provincias[v].nombre, n])


func _terr_deshacer() -> void:
	if main.territorio == null or not main.territorio.deshacer():
		_decir("No hay nada que deshacer.", false)
		return
	_decir("Último cambio de forma deshecho.")
	_mostrar_prov()
	_refrescar_mundo(false)


func _terr_restablecer() -> void:
	if main.territorio == null:
		return
	var n: int = main.territorio.restablecer()
	_decir("Forma original restablecida (%d celdas devueltas)." % n if n > 0 else "La forma ya era la original.", n > 0)
	_mostrar_prov()
	_refrescar_mundo(false)


func _refrescar_territorio() -> void:
	if lbl_terr == null or main.territorio == null or not main.territorio.listo() or prov_sel < 0:
		return
	var t = main.territorio
	var celdas: PackedInt32Array = t.celdas_de(prov_sel)
	lbl_terr.text = "%d celdas · superficie en el mapa %.0f px² · %d provincias vecinas%s" % [
		celdas.size(), t.area_provincia(prov_sel), t.provincias_vecinas(prov_sel).size(),
		"  ·  forma modificada" if t.modificado() else ""]
	var elegida := _terr_vecina()                                 # la vecina elegida se conserva entre cambios (si sigue siéndolo)
	opt_vecina.clear()
	ids_vecinas.clear()
	for q in t.provincias_vecinas(prov_sel):
		if main.mundo.provincias[int(q)].anillos.is_empty():
			continue
		opt_vecina.add_item("%s · %s" % [main.mundo.provincias[int(q)].nombre, main.mundo.provincias[int(q)].pais])
		ids_vecinas.append(int(q))
	if opt_vecina.item_count > 0:
		var pos := ids_vecinas.find(elegida)
		opt_vecina.select(pos if pos >= 0 else 0)


func _actualizar_boton_transferir() -> void:
	btn_transferir.text = "TRANSFERIR A %s" % pais_dest.to_upper() if pais_dest != "" else "TRANSFERIR"


func _buscar_prov(q: String) -> void:
	lista_prov.clear()
	ids_lista_prov.clear()
	var terminos := _plano(q.strip_edges()).split(" ", false)
	if terminos.is_empty():
		return                      # sin texto no se lista nada: hay miles de provincias
	if planos_prov.is_empty():
		for pr in main.mundo.provincias:
			planos_prov.append(_plano(pr.nombre + " " + pr.pais_original))
	for i in planos_prov.size():
		var ok := true
		for t in terminos:
			if not String(planos_prov[i]).contains(t):
				ok = false
				break
		if ok:
			var pr = main.mundo.provincias[i]
			lista_prov.add_item("%s · %s" % [pr.nombre, pr.pais])
			ids_lista_prov.append(i)
			if ids_lista_prov.size() >= 120:
				break


func _escalar_pob(k: float) -> void:
	if prov_sel < 0:
		return
	var pr = main.mundo.provincias[prov_sel]
	_dbg(func(): pr.poblacion = maxf(roundf(pr.poblacion * k), 0.0))
	_mostrar_prov()
	_refrescar_mundo(false)


func _fav_todas(v: float) -> void:
	if prov_sel < 0:
		_decir("Primero elige una provincia.", false)
		return
	var dueno: String = main.mundo.provincias[prov_sel].pais
	var cuenta := [0]
	_dbg(func():
		for pi in main.mundo.paises[dueno].provincias:
			main.mundo.provincias[int(pi)].favorabilidad = v
			cuenta[0] += 1)
	_mostrar_prov()
	_refrescar_mundo(false)
	_decir("Favorabilidad %d en las %d provincias de %s." % [int(v), int(cuenta[0]), dueno])


func _refrescar_mundo(con_mapa: bool) -> void:
	main.refrescar_todo(con_mapa)


func _mostrar_prov() -> void:
	if lbl_info_prov == null:
		return
	if prov_sel < 0:
		lbl_info_prov.text = "Elige una provincia o selecciónala en el mapa."
		return
	var pr = main.mundo.provincias[prov_sel]
	sl_fav.set_value_no_signal(pr.favorabilidad)
	sl_mult.set_value_no_signal(pr.mult_ingreso)
	sl_vprov.set_value_no_signal(pr.velocidad_desarrollo)
	sp_pob.set_value_no_signal(pr.poblacion)
	_actualizar_etiquetas_prov()
	_refrescar_territorio()


func _actualizar_etiquetas_prov() -> void:
	if prov_sel < 0:
		return
	var m = main.mundo
	var pr = m.provincias[prov_sel]
	var sim: String = main._simbolo_de(pr.pais)
	var dv = m.divisa_de(pr.pais)
	var local: float = pr.ingreso_efectivo_usd() * (dv.por_usd if dv != null else 1.0)
	var t := "%s  (ID %d)\n" % [pr.nombre, pr.tid]
	t += "Dueño actual: %s" % pr.pais
	if pr.pais != pr.pais_original:
		t += "  (originalmente %s)" % pr.pais_original
	t += "\nProducción anual (con favorabilidad): %s  ·  %s\n" % [main.fmt_dinero(pr.ingreso_efectivo_usd(), "US$"), main.fmt_dinero(local, sim)]
	t += "Aporta %s del total del país · Ingreso del país: %s por día\n" % [
		main.hud.pct(pr.ingreso_efectivo_usd() / maxf(m.produccion_anual_usd(pr.pais), 1.0) * 100.0),
		main.fmt_dinero(m.ingreso_diario_local(pr.pais), sim)]
	t += "Favorabilidad 0 → rinde 0,5×; 100 → 1,5×.  Historial de dueños: %d" % pr.propietarios.size()
	lbl_info_prov.text = t
	lbl_fav.text = "%d" % int(roundf(pr.favorabilidad))
	lbl_mult.text = ("x%.2f" % pr.mult_ingreso).replace(".", ",")
	lbl_vprov.text = ("x%.2f" % pr.velocidad_desarrollo).replace(".", ",")
	main._actualizar_barra()


# ───────────── Pestaña Tiempo ─────────────
func _spin(mn: float, mx: float, v: float, ancho: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 1.0
	s.value = v
	s.custom_minimum_size = Vector2(ancho, 0.0)
	return s


func _pagina_tiempo() -> void:
	var pg := _nueva_pagina("tiempo")
	pg.add_child(_lbl("Fecha del juego (año, mes, día)", 13, C_ORO))
	lbl_tiempo = _lbl("", 22, C_TEXTO)
	pg.add_child(lbl_tiempo)

	pg.add_child(_lbl("Velocidad (0 = pausa; 4-6 son las rápidas extra)", 12, C_TENUE))
	var fv := HBoxContainer.new()
	fv.add_theme_constant_override("separation", 4)
	pg.add_child(fv)
	for i in 7:
		var v: int = i
		var b := _boton("⏸" if i == 0 else str(i), func(): main._poner_velocidad(v))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botones_vel.append(b)
		fv.add_child(b)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	pg.add_child(fila)
	sp_anio = _spin(-5000.0, 9999.0, float(main.epoca), 100.0)
	sp_mes = _spin(1.0, 12.0, 1.0, 70.0)
	sp_dia = _spin(1.0, 31.0, 1.0, 70.0)
	fila.add_child(sp_anio)
	fila.add_child(sp_mes)
	fila.add_child(sp_dia)
	var bf := _boton("FIJAR FECHA", func():
		main.debug_fijar_fecha(int(sp_anio.value), int(sp_mes.value), int(sp_dia.value))
		_refrescar_tiempo()
		_decir("Fecha fijada en %s." % main.reloj.texto()))
	bf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(bf)
	var fila2 := HBoxContainer.new()
	fila2.add_theme_constant_override("separation", 6)
	pg.add_child(fila2)
	for par in [["+1 día", 1], ["+30 días", 30], ["+1 año", 365], ["+10 años", 3652]]:
		var n: int = par[1]
		var b2 := _boton(String(par[0]), func():
			_dbg(func(): main.debug_avanzar_dias(n))
			_refrescar_tiempo()
			_decir("Avanzaron %d días: hoy es %s." % [n, main.reloj.texto()]))
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila2.add_child(b2)
	var nota := _lbl("Solo el país que controlas cobra ingresos al pasar los días (por ahora). Cada mes la producción por habitante crece según la velocidad de desarrollo.", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)

	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Dinero del país que controlas (en su moneda)", 13, C_ORO))
	var fila3 := HBoxContainer.new()
	fila3.add_theme_constant_override("separation", 6)
	pg.add_child(fila3)
	for par in [["+1 M", 1.0e6], ["+100 M", 1.0e8], ["+10 mil M", 1.0e10], ["−1 M", -1.0e6]]:
		var cant: float = par[1]
		var b3 := _boton(String(par[0]), func(): _dar_dinero(cant))
		b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila3.add_child(b3)
	pg.add_child(_boton("VACIAR TESORERÍA", func(): _dar_dinero(-1.0e30)))

	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Impuestos del país que controlas (parte de la producción que recauda)", 13, C_ORO))
	var o := []
	sl_tasa = _fila_slider(pg, "Impuestos", 0.0, 1.0, 0.01, func(v: float):
		var j: String = main.mundo.jugador
		if j == "":
			return
		_dbg(func(): main.mundo.paises[j].tasa_fiscal = v)
		lbl_tasa.text = "%d%%" % int(roundf(v * 100.0))
		main._actualizar_barra(), func(): _refrescar_mundo(false), o)
	lbl_tasa = o[0]


func _refrescar_tiempo() -> void:
	lbl_tiempo.text = main.reloj.texto()
	sp_anio.set_value_no_signal(main.reloj.anio)
	sp_mes.set_value_no_signal(main.reloj.mes)
	sp_dia.set_value_no_signal(main.reloj.dia)
	var j: String = main.mundo.jugador
	var t := 0.25
	if j != "" and main.mundo.paises.has(j):
		t = main.mundo.paises[j].tasa_fiscal
	sl_tasa.set_value_no_signal(t)
	lbl_tasa.text = "%d%%" % int(roundf(t * 100.0))


func _dar_dinero(cant: float) -> void:
	var j: String = main.mundo.jugador
	if j == "":
		_decir("No controlas ningún país: elígelo en la pestaña Jugador.", false)
		return
	main.debug_dar_dinero(j, cant)
	var sim: String = main._simbolo_de(j)
	_decir("Tesorería de %s: %s." % [j, main.fmt_dinero(main.mundo.paises[j].tesoreria, sim)])


# ───────────── Pestaña Mundo (mecánicas globales) ─────────────
func _pagina_mundo() -> void:
	var pg := _nueva_pagina("mundo")
	pg.add_child(_lbl("Desarrollo", 13, C_ORO))
	var nota := _lbl("Cada mes, la producción por habitante de cada provincia crece según:\ncrecimiento base × velocidad de la provincia × velocidad de su país dueño.", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)
	var o1 := []
	sl_base = _fila_slider(pg, "Crecimiento base", 0.0, 0.2, 0.005, func(v: float):
		_dbg(func(): main.mundo.bd.poner_f("crecimiento_base_anual", main.mundo.bd.id_de("mundo", "mundo"), v))
		lbl_base.text = "%s %%" % ("%.1f" % (v * 100.0)).replace(".", ","), func(): _refrescar_mundo(false), o1)
	lbl_base = o1[0]
	var o2 := []
	sl_vpais = _fila_slider(pg, "Tu país: desarrollo", 0.0, 5.0, 0.05, func(v: float):
		var j: String = main.mundo.jugador
		if j == "":
			return
		_dbg(func(): main.mundo.paises[j].velocidad_desarrollo = v)
		lbl_vpais.text = ("x%.2f" % v).replace(".", ","), func(): _refrescar_mundo(false), o2)
	lbl_vpais = o2[0]
	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Simulaciones rápidas", 13, C_ORO))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	pg.add_child(fila)
	for par in [["+1 año", 365], ["+10 años", 3652], ["+50 años", 18262]]:
		var n: int = par[1]
		var b := _boton(String(par[0]), func():
			var antes: String = main.reloj.texto()
			var t0 := Time.get_ticks_msec()
			_dbg(func(): main.debug_avanzar_dias(n))
			_refrescar_mundo_pagina()
			_decir("%s → %s  (%d ms de cálculo)" % [antes, main.reloj.texto(), Time.get_ticks_msec() - t0]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(b)
	lbl_mundo = _lbl("", 12, C_TEXTO)
	lbl_mundo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_mundo)


func _refrescar_mundo_pagina() -> void:
	var bd = main.mundo.bd
	var base: float = bd.num("crecimiento_base_anual", bd.id_de("mundo", "mundo"), 0.02)
	sl_base.set_value_no_signal(base)
	lbl_base.text = "%s %%" % ("%.1f" % (base * 100.0)).replace(".", ",")
	var j: String = main.mundo.jugador
	var vp := 1.0
	if j != "" and main.mundo.paises.has(j):
		vp = main.mundo.paises[j].velocidad_desarrollo
	sl_vpais.set_value_no_signal(vp)
	lbl_vpais.text = ("x%.2f" % vp).replace(".", ",")
	var t := "Fecha: %s\n" % main.reloj.texto()
	if j != "" and main.mundo.paises.has(j):
		var sim: String = main._simbolo_de(j)
		t += "%s: producción de sus provincias %s al año · ingresos %s por día\n" % [j, main.fmt_dinero(main.mundo.produccion_anual_usd(j), "US$"), main.fmt_dinero(main.mundo.ingreso_diario_local(j), sim)]
	var r: Dictionary = bd.resumen()
	var filas_hist := 0
	for fila in r["variables"]:
		filas_hist += int(fila["historial"])
	t += "Base de datos: %d territorios · %d variables · %d filas de historial" % [bd.n, bd.orden_vars.size(), filas_hist]
	lbl_mundo.text = t


# ───────────── Pestaña Datos (inspector de la base) ─────────────
func _pagina_datos() -> void:
	var pg := _nueva_pagina("datos")
	pg.add_child(_boton("← Inspeccionar lo seleccionado en el mapa", func():
		var t: int = int(main.debug_tid_seleccionado())
		if t < 0:
			_decir("No hay nada seleccionado en el mapa.", false)
			return
		tid_datos = t
		_refrescar_datos()))
	lbl_datos = _lbl("", 12, C_TEXTO)
	lbl_datos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_datos)
	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Historial de una variable en este ID", 13, C_ORO))
	opt_var = OptionButton.new()
	opt_var.item_selected.connect(func(_i: int): _refrescar_historial())
	pg.add_child(opt_var)
	lbl_hist = _lbl("", 12, C_TEXTO)
	lbl_hist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_hist)


func _valor_txt(v, id: int) -> String:
	var bd = main.mundo.bd
	match v.tipo:
		"numero":
			var x: float = bd.num(v.nombre, id)
			if absf(x) >= 1000.0:
				return main.hud.fmt_num(x)
			return ("%.3f" % x).replace(".", ",").rstrip("0").rstrip(",")
		"id":
			return "%s (ID %d)" % [bd.nombre_de(bd.ref(v.nombre, id)), bd.ref(v.nombre, id)]
	return bd.txt(v.nombre, id)


func _refrescar_datos() -> void:
	if lbl_datos == null:
		return
	var bd = main.mundo.bd
	if tid_datos < 0 or bd.idx(tid_datos) < 0:
		lbl_datos.text = "Selecciona algo en el mapa (provincia, ciudad, país, estado, continente) y pulsa el botón de arriba (o deja marcado «Seguir lo que selecciono»)."
		opt_var.clear()
		nombres_var.clear()
		lbl_hist.text = ""
		return
	var ix: int = bd.idx(tid_datos)
	var t := "ID %d · %s · %s\n" % [tid_datos, bd.nombre_de(tid_datos), bd.tipo_de(tid_datos)]
	var partes := []
	for x in bd.ruta(tid_datos):
		partes.append("%s (%d)" % [bd.nombre_de(int(x)), int(x)])
	t += "Cadena de IDs: %s\n" % " → ".join(PackedStringArray(partes))
	t += "Hijos directos: %d\n" % bd.hijos(tid_datos).size()
	var tipo := int(bd.t_tipo[ix])
	if tipo <= BDScript.T_ESTADO:
		var provs: Array = bd.descendientes(tid_datos, BDScript.T_PROVINCIA)
		if provs.size() > 0:
			t += "Resumen de sus %d provincias: población %s · superficie %s km²\n" % [provs.size(), main.hud.fmt_num(bd.suma("poblacion", provs)), main.hud.fmt_num(bd.suma("area_km2", provs))]
	t += "\nVARIABLES CON DATO (valor actual):\n"
	nombres_var.clear()
	var previa := ""
	if opt_var.item_count > 0 and opt_var.selected >= 0 and opt_var.selected < nombres_var.size():
		previa = String(nombres_var[opt_var.selected])
	opt_var.clear()
	for nombre in bd.orden_vars:
		var v = bd.vars[nombre]
		var con_hist: bool = bd.historial_de(nombre, tid_datos, 1).size() > 0
		if bd.tiene(nombre, tid_datos):
			var unidad: String = String(v.unidad) if v.tipo == "numero" else ""
			t += "· %s = %s%s  (desde %s)\n" % [v.etiqueta, _valor_txt(v, tid_datos), " " + unidad if unidad != "" else "", BDScript.fecha_texto(int(v.desde[ix]))]
		if bd.tiene(nombre, tid_datos) or con_hist:
			opt_var.add_item("%s  [%s]" % [v.etiqueta, v.historial])
			nombres_var.append(nombre)
	lbl_datos.text = t
	var sel := maxi(nombres_var.find(previa), 0)
	if nombres_var.size() > 0:
		opt_var.select(sel)
	_refrescar_historial()


func _refrescar_historial() -> void:
	var bd = main.mundo.bd
	if nombres_var.is_empty() or opt_var.selected < 0 or opt_var.selected >= nombres_var.size():
		lbl_hist.text = "Este territorio no tiene variables con dato."
		return
	var nombre := String(nombres_var[opt_var.selected])
	var v = bd.vars[nombre]
	var h: Array = bd.historial_de(nombre, tid_datos, 40)
	var t := "%s — política de historial: %s\n%s\n\n" % [v.etiqueta, v.historial, v.descripcion]
	if h.is_empty():
		t += "Sin registros todavía."
	else:
		var i := h.size() - 1
		while i >= 0:                              # del más reciente al más viejo
			var e: Dictionary = h[i]
			var val: String
			match v.tipo:
				"numero":
					val = main.hud.fmt_num(float(e["valor"])) if absf(float(e["valor"])) >= 1000.0 else ("%.3f" % float(e["valor"])).replace(".", ",")
				"id":
					val = bd.nombre_de(int(e["valor"]))
				_:
					val = String(e["valor"])
			var rango := "desde %s" % BDScript.fecha_texto(int(e["desde"])) if bool(e["actual"]) else "%s → %s" % [BDScript.fecha_texto(int(e["desde"])), BDScript.fecha_texto(int(e["hasta"]))]
			t += "%s%s: %s  (%s)%s\n" % ["▶ " if bool(e["actual"]) else "· ", "ACTUAL" if bool(e["actual"]) else "antes", val, rango, "  · " + String(e["motivo"]) if String(e["motivo"]) != "" else ""]
			i -= 1
	lbl_hist.text = t


# ───────────── Pestaña Historia ─────────────
func _fecha_hist() -> int:
	return BDScript.fecha_int(int(sp_h_anio.value), int(sp_h_mes.value), int(sp_h_dia.value))


func _pagina_historia() -> void:
	var pg := _nueva_pagina("historia")
	lbl_hist_res = _lbl("", 11, C_TENUE)
	lbl_hist_res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_hist_res)
	pg.add_child(_lbl("Época que quieres ver (año, mes, día; años a. C. en negativo)", 13, C_ORO))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	pg.add_child(fila)
	sp_h_anio = _spin(-5000.0, 9999.0, float(main.reloj.anio), 100.0)
	sp_h_mes = _spin(1.0, 12.0, float(main.reloj.mes), 70.0)
	sp_h_dia = _spin(1.0, 31.0, float(main.reloj.dia), 70.0)
	for sp in [sp_h_anio, sp_h_mes, sp_h_dia]:
		sp.value_changed.connect(func(_v: float): _refrescar_historia())
		fila.add_child(sp)
	var bh := _boton("FECHA DEL JUEGO", func():
		sp_h_anio.set_value_no_signal(main.reloj.anio)
		sp_h_mes.set_value_no_signal(main.reloj.mes)
		sp_h_dia.set_value_no_signal(main.reloj.dia)
		_refrescar_historia())
	bh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(bh)
	filtro_hist = LineEdit.new()
	filtro_hist.placeholder_text = "Buscar entidad por nombre (otomano, URSS, Gran Colombia...)"
	filtro_hist.clear_button_enabled = true
	filtro_hist.text_changed.connect(func(_t: String): _refrescar_historia())
	pg.add_child(filtro_hist)
	lbl_hist_lista = _lbl("", 12, C_ORO)
	pg.add_child(lbl_hist_lista)
	lista_hist = ItemList.new()
	lista_hist.custom_minimum_size = Vector2(0.0, 150.0)
	lista_hist.item_selected.connect(func(i: int):
		ent_hist_sel = int(ids_lista_hist[i]) if i >= 0 and i < ids_lista_hist.size() else -1
		_refrescar_ficha_hist())
	pg.add_child(lista_hist)
	var fb := HBoxContainer.new()
	fb.add_theme_constant_override("separation", 8)
	pg.add_child(fb)
	img_hist_bandera = TextureRect.new()
	img_hist_bandera.custom_minimum_size = Vector2(96.0, 64.0)
	img_hist_bandera.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_hist_bandera.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fb.add_child(img_hist_bandera)
	lbl_hist_ficha = _lbl("", 12, C_TEXTO)
	lbl_hist_ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_hist_ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fb.add_child(lbl_hist_ficha)
	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Lo que seleccionaste en el mapa, en esa época", 13, C_ORO))
	lbl_hist_mapa = _lbl("", 12, C_TEXTO)
	lbl_hist_mapa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_hist_mapa)


func _refrescar_historia() -> void:
	if lista_hist == null:
		return
	var h = main.mundo.historia
	var f := _fecha_hist()
	var r: Dictionary = h.resumen()
	lbl_hist_res.text = "Base histórica: %d entidades · %d nombres · %d banderas · %d personas · %d cargos. Las filas «semilla» son un ejemplo; herramientas/descargar_historia trae el resto." % [
		int(r["entidades"]), int(r["nombres"]), int(r["banderas"]), int(r["personas"]), int(r["cargos"])]
	var q := filtro_hist.text.strip_edges()
	var ids: Array = h.buscar(q) if q != "" else h.entidades_activas(f)
	ids.sort_custom(func(a, b): return h.nombre_en(int(a), f) < h.nombre_en(int(b), f))
	lbl_hist_lista.text = ("Resultados de la búsqueda: %d" % ids.size()) if q != "" else ("Entidades vigentes en el año %s: %d" % [h.anio_texto(f), ids.size()])
	var previa := ent_hist_sel
	lista_hist.clear()
	ids_lista_hist = ids
	var pos_prev := -1
	for k in ids.size():
		var id := int(ids[k])
		var fi: Dictionary = h.ficha(id)
		lista_hist.add_item("%s  (%s – %s)" % [h.nombre_en(id, f), h.anio_texto(int(fi["inicio"])), h.anio_texto(int(fi["fin"])) if int(fi["fin"]) > 0 else "…"])
		if id == previa:
			pos_prev = k
	if pos_prev >= 0:
		lista_hist.select(pos_prev)
	else:
		ent_hist_sel = -1
	_refrescar_ficha_hist()
	_refrescar_historia_mapa()


func _txt_fecha_h(f: int) -> String:
	return main.mundo.historia.anio_texto(f) if f > 0 else "?"


func _refrescar_ficha_hist() -> void:
	var h = main.mundo.historia
	var bd = main.mundo.bd
	var f := _fecha_hist()
	img_hist_bandera.texture = null
	if ent_hist_sel < 0:
		lbl_hist_ficha.text = "Elige una entidad de la lista."
		return
	var fi: Dictionary = h.ficha(ent_hist_sel)
	var t := "%s  (ID %d)\n" % [h.nombre_en(ent_hist_sel, f), ent_hist_sel]
	t += "%s · %s – %s · capital: %s · fuente: %s\n" % [String(fi["tipo"]), _txt_fecha_h(int(fi["inicio"])), _txt_fecha_h(int(fi["fin"])) if int(fi["fin"]) > 0 else "sin fecha de fin", String(fi["capital"]) if String(fi["capital"]) != "" else "?", String(fi["fuente"])]
	var ban: Dictionary = h.bandera_en(ent_hist_sel, f)
	if ban.is_empty():
		t += "Bandera: sin dato para esta fecha.\n"
	else:
		t += "Bandera: %s (%s, licencia: %s)\n" % [String(ban["archivo"]), String(ban["clase"]), String(ban["licencia"]) if String(ban["licencia"]) != "" else "sin verificar"]
		if FileAccess.file_exists(String(ban["ruta"])):
			var img := Image.load_from_file(String(ban["ruta"]))
			if img != null and not img.is_empty():
				img_hist_bandera.texture = ImageTexture.create_from_image(img)
	var nom: Array = h.nombres_de(ent_hist_sel)
	if nom.size() > 0:
		var partes := []
		for n in nom:
			partes.append("%s [%s %s%s]" % [String(n["nombre"]), String(n["idioma"]), String(n["clase"]), "" if int(n["desde"]) == 0 and int(n["hasta"]) == 0 else " %s–%s" % [_txt_fecha_h(int(n["desde"])), _txt_fecha_h(int(n["hasta"]))]])
		t += "Nombres: %s\n" % "; ".join(PackedStringArray(partes))
	var gob: Array = h.gobernantes_en(ent_hist_sel, f)
	if gob.size() > 0:
		var gp := []
		for g in gob:
			gp.append("%s (%s)" % [String(g["nombre"]), String(g["cargo"])])
		t += "Gobernaba en esa fecha: %s\n" % "; ".join(PackedStringArray(gp))
	else:
		t += "Gobernaba en esa fecha: sin dato.\n"
	var todos: Array = h.gobernantes_de(ent_hist_sel)
	if todos.size() > 0:
		var tp := []
		for g in todos:
			tp.append("%s %s–%s" % [String(g["nombre"]), _txt_fecha_h(int(g["desde"])), _txt_fecha_h(int(g["hasta"])) if int(g["hasta"]) > 0 else "…"])
		t += "Todos los registrados: %s\n" % "; ".join(PackedStringArray(tp))
	var pn := []
	for x in fi["predecesores"]:
		pn.append(h.nombre_base(int(x)))
	var sn := []
	for x in fi["sucesores"]:
		sn.append(h.nombre_base(int(x)))
	if pn.size() > 0:
		t += "Vino de: %s\n" % ", ".join(PackedStringArray(pn))
	if sn.size() > 0:
		t += "Le sucedieron: %s\n" % ", ".join(PackedStringArray(sn))
	lbl_hist_ficha.text = t.strip_edges()


func _refrescar_historia_mapa() -> void:
	if lbl_hist_mapa == null:
		return
	var h = main.mundo.historia
	var bd = main.mundo.bd
	var f := _fecha_hist()
	var tid := int(main.debug_tid_seleccionado())
	if tid < 0 or bd.idx(tid) < 0:
		lbl_hist_mapa.text = "Selecciona una provincia, ciudad, estado, país o continente en el mapa."
		return
	var t := "%s (%s, ID %d)\nEn el año %s se llamaba: %s\n" % [bd.nombre_de(tid), bd.tipo_de(tid), tid, h.anio_texto(f), h.nombre_en(tid, f)]
	var ban: Dictionary = h.bandera_en(tid, f)
	if not ban.is_empty():
		t += "Bandera en esa fecha: %s\n" % String(ban["archivo"])
	if bd.tipo_de(tid) == "provincia":
		var due: int = bd.dueno_en(tid, f)
		if due < 0:
			t += "Dueño en esa fecha: sin dato (mientras no haya mapas históricos, el juego solo conoce los dueños desde la fecha de partida)."
		else:
			t += "Dueño en esa fecha: %s (ID %d)" % [h.nombre_en(due, f), due]
	elif bd.tipo_de(tid) == "pais":
		t += "Datos del país vigentes en esa fecha: se muestran los nombres con fechas registrados arriba."
	lbl_hist_mapa.text = t


# ───────────── Pestaña Ejército ─────────────
## Lo que hay seleccionado en el mapa: provincia (si la hay), su dueño y el país seleccionado.
func _ej_ctx() -> Dictionary:
	var m = main.mundo
	var r := {"pi": -1, "prov_tid": -1, "dueno": "", "pais": String(main.debug_pais_seleccionado())}
	var pi: int = main.debug_provincia_seleccionada()
	if pi >= 0 and pi < m.provincias.size():
		var pr = m.provincias[pi]
		r["pi"] = pi
		r["prov_tid"] = int(pr.tid)
		r["dueno"] = String(pr.pais)
	return r


func _ej_listo() -> bool:
	if main.mundo == null or main.mundo.ejercito == null:
		_decir("El ejército todavía no existe en esta partida.", false)
		return false
	return true


func _ej_tras_cambio(msg: String) -> void:
	main.hud.refrescar_ejercito()
	_refrescar_ejercito_pagina()
	_decir(msg)


func _pagina_ejercito() -> void:
	var pg := _nueva_pagina("ejercito")
	pg.add_child(_lbl("Ejército (pelotones de hasta 1.000 soldados)", 13, C_ORO))
	lbl_ej_info = _lbl("", 12, C_TEXTO)
	lbl_ej_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_ej_info)
	var nota := _lbl("Selecciona una provincia en el mapa. Todo queda en el historial con el motivo «Debug».", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)
	pg.add_child(HSeparator.new())

	pg.add_child(_lbl("Reclutar (para el dueño de la provincia)", 12, C_TENUE))
	var f1 := HBoxContainer.new()
	f1.add_theme_constant_override("separation", 8)
	pg.add_child(f1)
	sp_ej_reclutar = _spin(1.0, 500000.0, 5000.0, 110.0)
	f1.add_child(sp_ej_reclutar)
	f1.add_child(_lbl("soldados", 12, C_TENUE))
	var b1 := _boton("Reclutar aquí", func():
		if not _ej_listo():
			return
		var c := _ej_ctx()
		if int(c["prov_tid"]) < 0 or String(c["dueno"]) == "":
			_decir("Selecciona una provincia (con dueño) en el mapa.", false)
			return
		var m = main.mundo
		var tocados: Array = m.ejercito.reclutar(int(m.paises[String(c["dueno"])].tid), int(c["prov_tid"]), int(sp_ej_reclutar.value), "Debug")
		_ej_tras_cambio("%s: reclutados %d soldados en esta provincia (%d pelotones tocados)." % [String(c["dueno"]), int(sp_ej_reclutar.value), tocados.size()]))
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f1.add_child(b1)

	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Bajas (parte de la tropa que muere)", 12, C_TENUE))
	var f2 := HBoxContainer.new()
	f2.add_theme_constant_override("separation", 8)
	pg.add_child(f2)
	sp_ej_baja = _spin(1.0, 100.0, 25.0, 90.0)
	f2.add_child(sp_ej_baja)
	f2.add_child(_lbl("%", 12, C_TENUE))
	var b2 := _boton("En esta provincia", func():
		_ej_bajas(true))
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f2.add_child(b2)
	var b3 := _boton("En todo el país", func():
		_ej_bajas(false))
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f2.add_child(b3)

	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Mover pelotones del país seleccionado a esta provincia", 12, C_TENUE))
	var f3 := HBoxContainer.new()
	f3.add_theme_constant_override("separation", 8)
	pg.add_child(f3)
	sp_ej_mover = _spin(1.0, 2000.0, 10.0, 90.0)
	f3.add_child(sp_ej_mover)
	f3.add_child(_lbl("regimientos", 12, C_TENUE))
	var b4 := _boton("Mover aquí", func():
		if not _ej_listo():
			return
		var c := _ej_ctx()
		var pais := String(c["pais"])
		if int(c["prov_tid"]) < 0 or pais == "" or not main.mundo.paises.has(pais):
			_decir("Selecciona primero un país (con un clic) y luego, en el panel, una provincia: se mueven tropas del país seleccionado.", false)
			return
		var ej = main.mundo.ejercito
		var tid_pais: int = int(main.mundo.paises[pais].tid)
		var destino: int = int(c["prov_tid"])
		var quedan: int = int(sp_ej_mover.value)
		var movidos := 0
		var rids: Array = []
		for id in ej.de_pais(tid_pais):
			var rid0: int = ej.reg_de(int(id))
			if rid0 >= 0 and not rids.has(rid0):
				rids.append(rid0)
		for rid1 in rids:
			if quedan <= 0:
				break
			if ej.existe_reg(int(rid1)) and not ej.en_marcha_reg(int(rid1)) and ej.prov_de(int(rid1)) != destino:
				ej.mover_reg(int(rid1), destino, "Debug")
				quedan -= 1
				movidos += 1
		_ej_tras_cambio("%s: %d regimientos movidos a esta provincia (cada uno con todos sus pelotones)." % [pais, movidos]))
	b4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f3.add_child(b4)
	var nota2 := _lbl("Si la provincia no es del país que mueve las tropas, aparecen como EXTRANJERO.", 11, C_TENUE)
	nota2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota2)

	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Devastación de la provincia", 12, C_TENUE))
	var o := []
	sl_ej_dev = _fila_slider(pg, "Devastación", 0.0, 1.0, 0.05, _ej_dev_mover, _ej_dev_soltar, o)
	lbl_ej_dev = o[0]

	pg.add_child(HSeparator.new())
	var f5 := HBoxContainer.new()
	f5.add_theme_constant_override("separation", 8)
	pg.add_child(f5)
	var b5 := _boton("Pasar 1 mes de servicio", func():
		if not _ej_listo():
			return
		main.mundo.ejercito.avanzar_mes()
		_ej_tras_cambio("Pasó un mes de servicio: edad, experiencia, familiaridad y forma física actualizadas."))
	b5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f5.add_child(b5)
	var b6 := _boton("Disolver tropas de la provincia", func():
		if not _ej_listo():
			return
		var c := _ej_ctx()
		if int(c["prov_tid"]) < 0:
			_decir("Selecciona una provincia en el mapa.", false)
			return
		var ej = main.mundo.ejercito
		var lista: Array = ej.en_provincia(int(c["prov_tid"])).duplicate()
		for id in lista:
			ej.aplicar_bajas(int(id), ej.soldados_de(int(id)), "Debug")
		_ej_tras_cambio("%d pelotones disueltos." % lista.size()))
	b6.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f5.add_child(b6)


func _ej_dev_mover(v: float) -> void:
	lbl_ej_dev.text = "%d %%" % int(roundf(v * 100.0))


func _ej_dev_soltar() -> void:
	if _ej_bloquea:
		return
	var c := _ej_ctx()
	if int(c["pi"]) < 0:
		_decir("Selecciona una provincia en el mapa.", false)
		return
	var v: float = sl_ej_dev.value
	_dbg(func(): main.mundo.provincias[int(c["pi"])].devastacion = v)
	_ej_tras_cambio("Devastación de la provincia: %d %%. Cambia lo que produce y el riesgo de motín." % int(roundf(v * 100.0)))


## Bajas en porcentaje a los pelotones de la provincia seleccionada (`en_provincia` = true) o a todos los del país seleccionado.
func _ej_bajas(en_provincia: bool) -> void:
	if not _ej_listo():
		return
	var c := _ej_ctx()
	var ej = main.mundo.ejercito
	var lista: Array = []
	var donde := ""
	if en_provincia:
		if int(c["prov_tid"]) < 0:
			_decir("Selecciona una provincia en el mapa.", false)
			return
		lista = ej.en_provincia(int(c["prov_tid"])).duplicate()
		donde = "esta provincia"
	else:
		var pais := String(c["pais"])
		if pais == "" or not main.mundo.paises.has(pais):
			_decir("Selecciona un país en el mapa.", false)
			return
		lista = ej.de_pais(int(main.mundo.paises[pais].tid)).duplicate()
		donde = pais
	var pct: float = sp_ej_baja.value / 100.0
	var muertos := 0
	for id in lista:
		var n: int = int(roundf(float(ej.soldados_de(int(id))) * pct))
		muertos += ej.aplicar_bajas(int(id), maxi(n, 1), "Debug")
	_ej_tras_cambio("Bajas en %s: %d soldados muertos (%d pelotones)." % [donde, muertos, lista.size()])


func _refrescar_ejercito_pagina() -> void:
	if lbl_ej_info == null:
		return
	var m = main.mundo
	if m == null or m.ejercito == null:
		lbl_ej_info.text = "El ejército todavía no existe en esta partida."
		return
	var ej = m.ejercito
	var c := _ej_ctx()
	var t := "Mundo: %s soldados en %d pelotones.\n" % [main.fmt_n(float(ej.soldados_totales())), ej.cuenta_pelotones()]
	var pais := String(c["pais"])
	if pais != "" and m.paises.has(pais):
		var r: Dictionary = ej.resumen(ej.de_pais(int(m.paises[pais].tid)))
		t += "%s: %s soldados en %d pelotones (exp. %d, fam. %d).\n" % [pais, main.fmt_n(float(r["soldados"])), int(r["pelotones"]), int(roundf(float(r["exp"]))), int(roundf(float(r["fam"])))]
	else:
		t += "Sin país seleccionado.\n"
	_ej_bloquea = true
	if int(c["pi"]) >= 0:
		var pr = m.provincias[int(c["pi"])]
		var rp: Dictionary = ej.resumen(ej.en_provincia(int(c["prov_tid"])))
		t += "Provincia: %s (de %s): %s soldados en %d pelotones.\nDevastación %d %% · riesgo de motín %d %%." % [pr.nombre, pr.pais, main.fmt_n(float(rp["soldados"])), int(rp["pelotones"]), int(roundf(pr.devastacion * 100.0)), int(roundf(m.riesgo_motin(int(c["pi"])) * 100.0))]
		sl_ej_dev.value = pr.devastacion
		lbl_ej_dev.text = "%d %%" % int(roundf(pr.devastacion * 100.0))
	else:
		t += "Sin provincia seleccionada."
		sl_ej_dev.value = 0.0
		lbl_ej_dev.text = "—"
	_ej_bloquea = false
	lbl_ej_info.text = t


# ───────────── Pestaña Rendimiento ─────────────
func _pagina_rendimiento() -> void:
	var pg := _nueva_pagina("rend")
	pg.add_child(_lbl("Tu equipo", 13, C_ORO))
	lbl_rend_hw = _lbl("", 11, C_TENUE)
	lbl_rend_hw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_rend_hw)
	pg.add_child(_lbl("Ahora mismo", 13, C_ORO))
	lbl_rend = _lbl("", 12, C_TEXTO)
	lbl_rend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_rend)
	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Capas del mapa (quita la marca para apagar una)", 13, C_ORO))
	var nota := _lbl("Apaga una capa y mira si suben los FPS de la esquina: la que más los suba es la que más pesa en tu PC.", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	pg.add_child(rejilla)
	for par in CAPAS_REND:
		var clave: String = par[0]
		var c := CheckBox.new()
		c.text = String(par[1])
		c.button_pressed = true
		c.focus_mode = Control.FOCUS_NONE
		c.add_theme_font_size_override("font_size", 12)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.toggled.connect(func(on: bool): main.rend_poner_capa(clave, on))
		chk_capas[clave] = c
		rejilla.add_child(c)
	pg.add_child(_boton("Encender todas las capas", func():
		for k in chk_capas:
			(chk_capas[k] as CheckBox).set_pressed_no_signal(true)
		main.rend_ocultas.clear()
		main.rend_poner_capa("relleno", true)))
	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Prueba de zoom (unos 25 segundos)", 13, C_ORO))
	var nota2 := _lbl("Acerca y aleja el mapa sola, mide los FPS en cada nivel y arma un informe. No toques nada mientras corre.", 11, C_TENUE)
	nota2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota2)
	btn_prueba = _boton("▶ Empezar la prueba de zoom", func(): _prueba_zoom())
	pg.add_child(btn_prueba)
	pg.add_child(_boton("Copiar el informe (para pegarlo en el chat)", func():
		if _informe == "":
			_decir("Todavía no hay informe: corre primero la prueba de zoom.", false)
			return
		DisplayServer.clipboard_set(_informe)
		_decir("Informe copiado. Pégalo en el chat con Ctrl+V.")))
	lbl_rend_informe = _lbl("", 11, C_TEXTO)
	pg.add_child(lbl_rend_informe)
	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("Grabador de rendimiento (juega normal y mándame el resumen)", 13, C_ORO))
	var nota3 := _lbl("Anota cuánto tarda cada fotograma mientras juegas de verdad (zoom, arrastre, tiempo corriendo). Empieza a grabar, haz lo que te va mal (por ejemplo, zoom in y zoom out por Europa) y detén la grabación: queda un resumen en el portapapeles y un archivo CSV con todo. Con F9 se enciende y se apaga sin abrir este panel; F8 pone una marca.", 11, C_TENUE)
	nota3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota3)
	btn_grabar = _boton("● Empezar a grabar (F9)", func(): main.alternar_grabacion())
	pg.add_child(btn_grabar)
	pg.add_child(_boton("Copiar el último resumen", func():
		if main.grabador.ultimo_resumen == "":
			_decir("Todavía no hay grabación: empieza una con F9.", false)
			return
		DisplayServer.clipboard_set(main.grabador.ultimo_resumen)
		_decir("Resumen copiado. Pégalo en el chat con Ctrl+V.")))
	pg.add_child(_boton("Abrir la carpeta de grabaciones", func(): OS.shell_open(main.grabador.ruta_carpeta())))
	lbl_grab = _lbl("", 11, C_TEXTO)
	lbl_grab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_grab)


func _texto_equipo() -> String:
	var gpu := RenderingServer.get_video_adapter_name()
	var vend := RenderingServer.get_video_adapter_vendor()
	var api := RenderingServer.get_video_adapter_api_version()
	var ventana := get_window().size
	return "GPU: %s (%s) · API %s\nSistema: %s · Godot %s · render %s · ventana %d×%d · CPU %d hilos" % [
		gpu, vend, api, OS.get_name(), String(Engine.get_version_info()["string"]),
		String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")), ventana.x, ventana.y, OS.get_processor_count()]


func _refrescar_rend() -> void:
	lbl_rend_hw.text = _texto_equipo()
	var fps := float(Engine.get_frames_per_second())
	var ms := 1000.0 / maxf(fps, 1.0)
	var dibujos := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var objetos := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	var prim := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	lbl_rend.text = "%d FPS · %.1f ms por fotograma\nzoom %.2f · costa nivel %d · %d llamadas de dibujo · %d objetos · %s triángulos" % [
		int(round(fps)), ms, main.camara.zoom.x, int(main.costa_nivel), dibujos, objetos, _miles(prim)]
	var g = main.grabador
	btn_grabar.text = "■ Detener y guardar (F9)" if g.grabando else "● Empezar a grabar (F9)"
	if g.grabando:
		lbl_grab.text = "● GRABANDO · %d fotogramas anotados" % g.n_filas
	elif g.ultimo_archivo != "":
		lbl_grab.text = "Última grabación guardada en:\n%s" % ProjectSettings.globalize_path(g.ultimo_archivo)
	else:
		lbl_grab.text = ""


func _miles(n: int) -> String:
	var t := str(n)
	var r := ""
	for i in t.length():
		if i > 0 and (t.length() - i) % 3 == 0:
			r += "."
		r += t[i]
	return r


## Recorre el zoom (ida y vuelta) midiendo FPS en cada paso. Deja la cámara como estaba y arma el informe.
func _prueba_zoom() -> void:
	if _prueba_en_curso:
		return
	_prueba_en_curso = true
	btn_prueba.disabled = true
	var cam: Camera2D = main.camara
	var z_antes := cam.zoom
	var pos_antes := cam.position
	cam.position = Vector2(1250.0, 400.0)                  # Europa: hay costa, fronteras, nombres y muchas ciudades
	var subida := []
	var z := 0.55
	while z < 32.0:
		subida.append(z)
		z *= 1.7
	subida.append(32.0)
	var secuencia := subida.duplicate()
	var bajada := subida.duplicate()
	bajada.reverse()
	secuencia.append_array(bajada.slice(1))
	var filas := []
	var n_paso := 0
	for zz in secuencia:
		n_paso += 1
		_decir("Prueba de zoom en curso (%d de %d)… no toques nada." % [n_paso, secuencia.size()])
		cam.zoom = Vector2(zz, zz)
		main._normalizar_camara()
		var tiron := 0.0
		for i in 3:                                          # los primeros fotogramas tras cambiar el zoom: ahí se ven los tirones
			await get_tree().process_frame
			tiron = maxf(tiron, get_process_delta_time())
		var t := 0.0
		var n := 0
		var peor := 0.0
		while t < 0.8:
			await get_tree().process_frame
			var d := get_process_delta_time()
			t += d
			n += 1
			peor = maxf(peor, d)
		filas.append([float(zz), float(n) / maxf(t, 0.001), peor * 1000.0, tiron * 1000.0,
			int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))])
	cam.zoom = z_antes
	cam.position = pos_antes
	main._normalizar_camara()
	var ocultas := "ninguna" if main.rend_ocultas.is_empty() else ", ".join(PackedStringArray(main.rend_ocultas.keys()))
	var inf := "INFORME DE RENDIMIENTO · juego v%s\n%s\nCapas apagadas: %s\n" % [main.VERSION, _texto_equipo(), ocultas]
	inf += "zoom   FPS   peor fotograma   tirón al cambiar   dibujos   triángulos\n"
	var suma := 0.0
	var peor_fps := 1.0e9
	for f in filas:
		inf += "%5.2f  %4d   %6.1f ms       %6.1f ms        %4d    %9s\n" % [f[0], int(round(f[1])), f[2], f[3], f[4], _miles(f[5])]
		suma += f[1]
		peor_fps = minf(peor_fps, f[1])
	inf += "FPS medios: %d · FPS del peor paso: %d" % [int(round(suma / maxf(filas.size(), 1))), int(round(peor_fps))]
	_informe = inf
	lbl_rend_informe.text = inf
	btn_prueba.disabled = false
	_prueba_en_curso = false
	DisplayServer.clipboard_set(inf)
	_decir("Prueba terminada. El informe ya está copiado: pégalo en el chat con Ctrl+V.")


# ───────────── 0.1.8.40 · Edificios y cores ─────────────
func _pagina_edificios() -> void:
	var pg := _nueva_pagina("edif")
	lbl_edif_res = _lbl("", 12, C_TEXTO)
	lbl_edif_res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_edif_res)
	pg.add_child(HSeparator.new())
	filtro_edif = LineEdit.new()
	filtro_edif.placeholder_text = "Buscar edificio (muralla, hospital, puerto...)"
	filtro_edif.clear_button_enabled = true
	filtro_edif.text_changed.connect(func(_t: String): _refrescar_edif())
	pg.add_child(filtro_edif)
	lista_edif = ItemList.new()
	lista_edif.custom_minimum_size = Vector2(0.0, 170.0)
	lista_edif.item_selected.connect(func(i: int):
		edif_sel = int(ids_lista_edif[i]) if i >= 0 and i < ids_lista_edif.size() else -1
		_refrescar_ficha_edif())
	pg.add_child(lista_edif)
	lbl_edif_ficha = _lbl("", 12, C_TEXTO)
	lbl_edif_ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_edif_ficha)
	var f1 := HBoxContainer.new()
	f1.add_theme_constant_override("separation", 6)
	pg.add_child(f1)
	for par in [["DAR ×1 (GRATIS)", true], ["QUITAR ×1", false]]:
		var da: bool = par[1]
		var b := _boton(String(par[0]), func(): _edif_dar(da))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f1.add_child(b)
	var f2 := HBoxContainer.new()
	f2.add_theme_constant_override("separation", 6)
	pg.add_child(f2)
	var b3 := _boton("TERMINAR OBRAS", func(): _edif_obras(true))
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f2.add_child(b3)
	var b4 := _boton("CANCELAR OBRAS", func(): _edif_obras(false))
	b4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f2.add_child(b4)
	var b5 := _boton("CONCEDER SU DESCUBRIMIENTO AL DUEÑO", func(): _edif_conceder())
	pg.add_child(b5)
	pg.add_child(HSeparator.new())
	pg.add_child(_lbl("CORES de lo elegido", 13, C_ORO))
	var nota := _lbl("El core nacional es el país al que la tierra pertenece por historia; el cultural, la cultura de su gente. Sin efectos de juego todavía.", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)
	sel_core = _selector_pais("Core nacional →", 100.0, func(n: String): pais_core = n)
	pg.add_child(sel_core["caja"])
	var f3 := HBoxContainer.new()
	f3.add_theme_constant_override("separation", 6)
	pg.add_child(f3)
	var b6 := _boton("FIJAR CORE NACIONAL", func(): _core_nacional(pais_core))
	b6.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f3.add_child(b6)
	var b7 := _boton("QUITARLO", func(): _core_nacional(""))
	b7.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f3.add_child(b7)
	var f4 := HBoxContainer.new()
	f4.add_theme_constant_override("separation", 6)
	pg.add_child(f4)
	opt_cultura = OptionButton.new()
	opt_cultura.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cult: Dictionary = main.mundo.mandos.culturas if main.mundo.mandos != null else {}
	var ks := cult.keys()
	ks.sort_custom(func(a, b): return String(main.mundo.mandos.etiqueta_cultura(a)) < String(main.mundo.mandos.etiqueta_cultura(b)))
	for k in ks:
		opt_cultura.add_item(String(main.mundo.mandos.etiqueta_cultura(k)))
		ids_cultura.append(String(k))
	f4.add_child(opt_cultura)
	var b8 := _boton("FIJAR CORE CULTURAL", func(): _core_cultural())
	f4.add_child(b8)
	var b9 := _boton("CORES = LOS DE ORIGEN", func(): _core_restaurar())
	pg.add_child(b9)


## Las provincias sobre las que actúan los botones: las elegidas en el mapa (provincia, país, estado o grupo) o, si no hay, la que se eligió en Provincia.
func _edif_pis() -> Array:
	var pis: Array = main._provincias_elegidas()
	if pis.is_empty() and prov_sel >= 0:
		pis = [prov_sel]
	return pis


func _refrescar_edif() -> void:
	if lista_edif == null:
		return
	var m = main.mundo
	var ed = m.edificios
	if ed == null:
		lbl_edif_res.text = "Falta datos/edificios.json (ejecuta herramientas/construir_edificios.py)."
		lista_edif.clear()
		return
	var pis := _edif_pis()
	var t := "Mundo: %s edificios construidos · %d provincias con obras · %s obras terminadas desde que empezó la partida" % [_miles(ed.total_mundo()), ed.provincias_en_obra(), _miles(ed.terminadas)]
	if pis.is_empty():
		t += "\nElige una provincia, un país o un grupo en el mapa (o una provincia en la sección Provincia)."
	else:
		var duenos := {}
		for pi in pis:
			duenos[String(m.provincias[int(pi)].pais)] = true
		t += "\nElegido: %s provincias de %d %s · %s edificios · %d obras en curso" % [_miles(pis.size()), duenos.size(), "país" if duenos.size() == 1 else "países", _miles(ed.total_en(pis)), ed.obras_en(pis)]
		if pis.size() == 1:
			var pr = m.provincias[int(pis[0])]
			t += "\n%s · core nacional: %s · core cultural: %s" % [pr.nombre, m.cores.nacional(int(pis[0])) if m.cores.nacional(int(pis[0])) != "" else "ninguno", m.cores.etiqueta_cultural(int(pis[0]))]
	lbl_edif_res.text = t
	var antes := edif_sel
	lista_edif.clear()
	ids_lista_edif.clear()
	var q := _plano(filtro_edif.text.strip_edges())
	var tot: Dictionary = ed.totales_de(pis)
	for e in ed.n:
		if q != "" and not _plano(String(ed.nombre[e])).contains(q) and not String(ed.slug[e]).contains(q):
			continue
		var n_e: int = int(tot.get(ed.slug[e], 0))
		var item := lista_edif.add_item("%s %s · %s%s" % ["✓" if n_e > 0 else "·", ed.nombre[e], ed.nombre_clase(e), (" · ×%d" % n_e) if n_e > 0 else ""])
		if n_e == 0:
			lista_edif.set_item_custom_fg_color(item, Tema.TENUE)
		ids_lista_edif.append(e)
	edif_sel = -1
	var pos := ids_lista_edif.find(antes)
	if pos >= 0:
		lista_edif.select(pos)
		lista_edif.ensure_current_is_visible()
		edif_sel = antes
	_refrescar_ficha_edif()


func _refrescar_ficha_edif() -> void:
	var ed = main.mundo.edificios
	if ed == null or edif_sel < 0:
		lbl_edif_ficha.text = "Elige un edificio de la lista."
		return
	var e := edif_sel
	lbl_edif_ficha.text = "%s\n%s\nClase %s · máximo %d por provincia · %d días de obra · aparece en el %s\n%s" % [String(ed.nombre[e]), String(ed.desc[e]), ed.nombre_clase(e), ed.tope[e], ed.dias_de(e),
		("año %d" % ed.anio[e]) if ed.anio[e] >= 0 else ("%d a. C." % -ed.anio[e]), String(ed.seccion[e])]


func _edif_dar(dar: bool) -> void:
	var ed = main.mundo.edificios
	var pis := _edif_pis()
	if ed == null or edif_sel < 0 or pis.is_empty():
		_decir("Elige un edificio de la lista y una provincia en el mapa.", false)
		return
	var hechos := 0
	for pi in pis:
		if dar:
			ed.dar(int(pi), edif_sel, 1)
			hechos += 1
		elif ed.cantidad(int(pi), edif_sel) > 0:
			ed.quitar(int(pi), edif_sel, 1)
			hechos += 1
	main.refrescar_todo(false)
	_refrescar_edif()
	_decir("%s «%s» en %d provincias." % ["Añadido" if dar else "Quitado", ed.nombre[edif_sel], hechos])


func _edif_obras(terminar: bool) -> void:
	var ed = main.mundo.edificios
	var pis := _edif_pis()
	if ed == null or pis.is_empty():
		_decir("Elige una provincia en el mapa.", false)
		return
	var c := 0
	for pi in pis:
		if terminar:
			c += ed.completar_obras(int(pi))
		else:
			while ed.obras_de(int(pi)).size() > 0:
				ed.cancelar_sin_reembolso(int(pi), 0)
				c += 1
	main.refrescar_todo(false)
	_refrescar_edif()
	_decir("%s %d obras." % ["Terminadas" if terminar else "Canceladas (sin reembolso)", c])


## Para que el dueño pueda construir lo que elegiste aunque su fecha aún no lo traiga.
func _edif_conceder() -> void:
	var m = main.mundo
	var ed = m.edificios
	var pis := _edif_pis()
	if ed == null or edif_sel < 0 or pis.is_empty() or m.descubrimientos == null or ed.desc_idx[edif_sel] < 0:
		_decir("Elige un edificio y una provincia.", false)
		return
	var hechos := {}
	for pi in pis:
		var pais := String(m.provincias[int(pi)].pais)
		if m.paises.has(pais) and not hechos.has(pais):
			m.descubrimientos.conceder(int(m.paises[pais].tid), ed.desc_idx[edif_sel])
			hechos[pais] = true
	main.refrescar_todo(false)
	_decir("%d países conocen ahora «%s»." % [hechos.size(), ed.nombre[edif_sel]])


func _core_nacional(pais: String) -> void:
	var cs = main.mundo.cores
	var pis := _edif_pis()
	if cs == null or pis.is_empty():
		_decir("Elige una provincia en el mapa.", false)
		return
	if pais != "" and not main.mundo.paises.has(pais):
		_decir("Elige el país en la lista de arriba.", false)
		return
	for pi in pis:
		cs.fijar_nacional(int(pi), pais)
	main.refrescar_todo(false)
	_refrescar_edif()
	_decir("Core nacional de %d provincias: %s." % [pis.size(), pais if pais != "" else "ninguno"])


func _core_cultural() -> void:
	var cs = main.mundo.cores
	var pis := _edif_pis()
	if cs == null or pis.is_empty() or opt_cultura == null or opt_cultura.selected < 0:
		_decir("Elige una provincia en el mapa y una cultura.", false)
		return
	var c := String(ids_cultura[opt_cultura.selected])
	for pi in pis:
		cs.fijar_cultural(int(pi), c)
	main.refrescar_todo(false)
	_refrescar_edif()
	_decir("Core cultural de %d provincias: %s." % [pis.size(), main.mundo.mandos.etiqueta_cultura(c)])


func _core_restaurar() -> void:
	var cs = main.mundo.cores
	var pis := _edif_pis()
	if cs == null or pis.is_empty():
		_decir("Elige una provincia en el mapa.", false)
		return
	for pi in pis:
		cs.restaurar(int(pi))
	main.refrescar_todo(false)
	_refrescar_edif()
	_decir("Cores de %d provincias vueltos a los de origen." % pis.size())


# ───────────── 0.1.8.36 · Descubrimientos ─────────────
func _pagina_descubrimientos() -> void:
	var pg := _nueva_pagina("desc")
	lbl_desc_res = _lbl("", 12, C_TEXTO)
	lbl_desc_res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_desc_res)
	pg.add_child(HSeparator.new())
	filtro_desc = LineEdit.new()
	filtro_desc.placeholder_text = "Buscar descubrimiento (bronce, pólvora, internet...)"
	filtro_desc.clear_button_enabled = true
	filtro_desc.text_changed.connect(func(_t: String): _refrescar_desc())
	pg.add_child(filtro_desc)
	lbl_desc_lista = _lbl("", 12, C_ORO)
	lbl_desc_lista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_desc_lista)
	lista_desc = ItemList.new()
	lista_desc.custom_minimum_size = Vector2(0.0, 190.0)
	lista_desc.item_selected.connect(func(i: int):
		desc_sel = int(ids_lista_desc[i]) if i >= 0 and i < ids_lista_desc.size() else -1
		_refrescar_ficha_desc())
	pg.add_child(lista_desc)
	lbl_desc_ficha = _lbl("", 12, C_TEXTO)
	lbl_desc_ficha.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(lbl_desc_ficha)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	pg.add_child(fila)
	var b1 := _boton("CONCEDER A MI PAÍS", func(): _desc_cambiar(true))
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(b1)
	var b2 := _boton("QUITAR A MI PAÍS", func(): _desc_cambiar(false))
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(b2)
	var b3 := _boton("MI PAÍS = HISTORIA", func():
		var d = main.mundo.descubrimientos
		if d == null or main.mundo.jugador == "":
			_decir("Controla un país en la pestaña Jugador.", false)
			return
		d.reiniciar_pais(main.mundo.paises[main.mundo.jugador].tid)
		_refrescar_desc()
		_decir("%s vuelve a conocer exactamente lo que conoce la historia en %s." % [main.mundo.jugador, d.anio_texto(d.anio_actual)]))
	b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(b3)
	var nota := _lbl("La HISTORIA es todo lo que tiene año <= el año del reloj. Cada país parte de ella y solo se aparta si le concedes o quitas un descubrimiento aquí. Al fijar una fecha en Tiempo, todos los países vuelven a la historia de ese año.", 11, C_TENUE)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pg.add_child(nota)


## El país cuyo estado se muestra: el que controlas (si controlas uno); si no, -1 = solo la historia.
func _desc_tid() -> int:
	var m = main.mundo
	if m.jugador != "" and m.paises.has(m.jugador):
		return int(m.paises[m.jugador].tid)
	return -1


func _refrescar_desc() -> void:
	if lista_desc == null:
		return
	var d = main.mundo.descubrimientos
	if d == null:
		lbl_desc_res.text = "Falta datos/descubrimientos.json (ejecuta herramientas/construir_descubrimientos.py)."
		lista_desc.clear()
		return
	var tid := _desc_tid()
	var t := "Año del reloj: %s · la historia conoce %s de %s descubrimientos" % [d.anio_texto(main.reloj.anio), _miles(d.cuenta_f), _miles(d.n)]
	if tid >= 0:
		t += "\n%s conoce %s" % [main.mundo.jugador, _miles(d.cantidad(tid))]
	if not d.ultimos.is_empty():
		var rec := PackedStringArray()
		for k in range(maxi(d.ultimos.size() - 4, 0), d.ultimos.size()):
			rec.append(d.etiqueta(int(d.ultimos[k]["idx"])))
		t += "\nÚltimos en llegar: " + " · ".join(rec)
	var prox: PackedInt32Array = d.proximos(4)
	if not prox.is_empty():
		var tx := PackedStringArray()
		for i2 in prox:
			tx.append(d.etiqueta(i2))
		t += "\nSiguientes en llegar: " + " · ".join(tx)
	t += "\nPor era (conocidos/total):"
	var cp: PackedInt32Array = d.cantidad_por_era(tid) if tid >= 0 else d.cantidad_por_era(-1)
	var tp: PackedInt32Array = d.total_por_era()
	var filas_e := PackedStringArray()
	for e in d.eras.size():
		filas_e.append("%s %d/%d" % [String(d.eras[e]["nombre"]), cp[e], tp[e]])
	t += "\n" + " · ".join(filas_e)
	lbl_desc_res.text = t
	lista_desc.clear()
	ids_lista_desc.clear()
	var q := _plano(filtro_desc.text.strip_edges())
	var cand: Array = []
	if q == "":
		for k in range(maxi(d.cuenta_f - 30, 0), mini(d.cuenta_f + 30, d.n)):
			cand.append(d.orden[k])
		lbl_desc_lista.text = "Alrededor de esta fecha (30 antes y 30 después). Escribe para buscar entre los %s." % _miles(d.n)
	else:
		for k in d.n:
			var i: int = d.orden[k]
			if _plano(String(d.nombre[i])).contains(q) or String(d.slug[i]).contains(q):
				cand.append(i)
				if cand.size() >= 300:
					break
		lbl_desc_lista.text = "%d resultados%s." % [cand.size(), " (mostrando los primeros 300)" if cand.size() >= 300 else ""]
	for i in cand:
		var sabe: bool = d.conoce(tid, i)
		var idx_item: int = lista_desc.add_item("%s %s" % ["✓" if sabe else "·", d.etiqueta(i)])
		if not sabe:
			lista_desc.set_item_custom_fg_color(idx_item, Tema.TENUE)
		ids_lista_desc.append(i)
	desc_sel = -1
	_refrescar_ficha_desc()


func _refrescar_ficha_desc() -> void:
	var d = main.mundo.descubrimientos
	if d == null or desc_sel < 0:
		lbl_desc_ficha.text = "Elige un descubrimiento de la lista."
		return
	var tid := _desc_tid()
	var i := desc_sel
	var t := "%s\nAño %s (%s) · %s · %s › %s" % [String(d.nombre[i]), d.anio_texto(d.anio[i]), _origen_anio(String(d.origen[i])),
		String(d.eras[int(d.era[i])]["nombre"]), String(d.ramas[int(d.secciones[int(d.seccion[i])]["rama"])]["nombre"]), String(d.secciones[int(d.seccion[i])]["nombre"])]
	var sub_i: int = int(d.sub[i])
	if sub_i >= 0:
		t += " › " + String(d.subsecciones[sub_i])
	t += "\nTipo: %s" % String(d.tipos.get(String(d.tipo[i]), d.tipo[i]))
	var tema_i: int = int(d.tema[i])
	if tema_i >= 0:
		t += " · Tema especial: " + String(d.temas[tema_i]["nombre"])
	var rq := PackedStringArray()
	for r in d.req[i]:
		rq.append("%s %s" % ["✓" if d.conoce(tid, r) else "✗", String(d.nombre[r])])
	for g in d.req_o[i]:
		var alts := PackedStringArray()
		for r2 in g:
			alts.append("%s %s" % ["✓" if d.conoce(tid, r2) else "✗", String(d.nombre[r2])])
		rq.append("(" + " o ".join(alts) + ")")
	t += "\nRequiere: " + (", ".join(rq) if not rq.is_empty() else "nada (es una raíz)")
	if tid >= 0:
		t += "\nPara %s: %s" % [main.mundo.jugador, "ya lo conoce" if d.conoce(tid, i) else ("DISPONIBLE (tiene los prerrequisitos)" if d.disponible(tid, i) else "le faltan prerrequisitos")]
	lbl_desc_ficha.text = t


func _origen_anio(o: String) -> String:
	match o:
		"h":
			return "histórico"
		"a":
			return "ajustado a sus prerrequisitos"
		"x":
			return "hipotético"
	return o


func _desc_cambiar(conceder: bool) -> void:
	var d = main.mundo.descubrimientos
	var m = main.mundo
	if d == null or desc_sel < 0:
		_decir("Elige un descubrimiento de la lista.", false)
		return
	if m.jugador == "" or not m.paises.has(m.jugador):
		_decir("Controla un país en la pestaña Jugador.", false)
		return
	var tid: int = m.paises[m.jugador].tid
	var ok: bool = d.conceder(tid, desc_sel) if conceder else d.quitar(tid, desc_sel)
	if ok:
		_decir("%s %s «%s»." % [m.jugador, "ahora conoce" if conceder else "ya no conoce", String(d.nombre[desc_sel])])
	else:
		_decir("%s %s «%s»." % [m.jugador, "ya conocía" if conceder else "no conocía", String(d.nombre[desc_sel])], false)
	var guardado := desc_sel
	_refrescar_desc()
	desc_sel = guardado
	_refrescar_ficha_desc()
