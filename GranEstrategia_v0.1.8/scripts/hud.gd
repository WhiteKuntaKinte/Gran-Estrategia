extends Node
## HUD 0.1.8 — panel de país con cinco pestañas: General · Diplomacia · Militar · Política · Economía.
## Diseño en tres bloques (de arriba abajo): CABECERA (bandera, nombre y migas) · FILA DE PESTAÑAS (su propia subsección, debajo del nombre)
## · SECCIÓN DE LA PESTAÑA ABIERTA (toda la información de esa pestaña). La pestaña Militar lleva dentro el manejo de tropas
## (resumen, regimientos, reclutar y batallas): ya no existe la ventana flotante de ejército.
## Recibe del mapa un diccionario `datos` (ver MapaPrincipal._enviar_hud) y se encarga solo de dibujarlo.
## Todo el aspecto (colores, fuente, estilos) viene de scripts/tema_hud.gd.

signal cerrar_pedido
signal miga_pedida(nivel: String, nombre: String)
signal vista_elegida(clave: String)   # 0.1.8.37 · una entrada del menú VISTA (tradicional, relieve...)
signal pausa_pedida
signal atras_pedido
signal velocidad_pedida(v: int)
signal jugador_pedido            # clic en la bandera/nombre del país que controlas (barra superior): abre la pestaña General
signal dinero_pedido             # clic en el dinero de la barra superior: abre la pestaña Economía
signal debug_pedido              # botón del bicho (o F1)
signal personalizar_pedido       # lápiz junto al nombre de tu país
signal ranking_pedido            # botón «Ranking» (solo en la campaña)
signal descubrimientos_pedido      # 0.1.8.42 · botón «Descubrimientos» de la barra de arriba (o la tecla T)
signal construir_pedido(pis: Array)   # 0.1.8.40 · botón «Construir…» de las tarjetas Edificios (provincias elegidas, índices de Mundo.provincias)

const Tema := preload("res://scripts/tema_hud.gd")
const TropasScript := preload("res://scripts/hud_tropas.gd")

const TAB_RATIO_ACTIVA := 2.4               # la pestaña abierta ocupa 2,4 × el ancho de cada una de las otras (que solo llevan icono)
const ANCHO_PANEL_MIN := 372.0              # 0.1.8.3: HUD menos invasivo
const ANCHO_PANEL_MAX := 420.0
const ALTO_BARRA := 44.0                    # 0.1.8.37: la barra superior ocupa todo el ancho, pegada al borde de arriba
const ALTO_PINTURA := 120.0                # 0.1.8.41: alto de la pintura que encabeza la pestaña General (el ancho es el de la tarjeta; se recorta al centro)
const PANEL_Y := ALTO_BARRA + 8.0           # donde empiezan el panel de país y el de detalle (justo debajo de la barra)
## Entradas del menú VISTA: [clave, texto, disponible]. Las no disponibles salen apagadas con «próximamente».
const VISTAS := [["tradicional", "Tradicional", true], ["relieve", "Relieve", true],
	["clima", "Clima", false], ["poblacion", "Población", false], ["economia", "Economía", false], ["cultura", "Cultura y religión", false]]
const C_BARRAS := [Color(0.42, 0.62, 1.0), Color(0.30, 0.85, 0.70), Color(1.0, 0.62, 0.30), Color(0.93, 0.45, 0.55),
	Color(0.80, 0.78, 0.35), Color(0.65, 0.50, 0.95), Color(0.55, 0.60, 0.70)]
const C_ACENTO := {"continente": Color(0.42, 0.62, 1.0), "pais": Color(0.30, 0.85, 0.70), "estado": Color(0.80, 0.78, 0.35),
	"provincia": Color(1.0, 0.62, 0.30), "ciudad": Color(0.93, 0.45, 0.55), "mar": Color(0.45, 0.85, 1.0)}
## [clave, texto, icono]
const PESTANAS := [["general", "General", "i_info"], ["diplomacia", "Diplomacia", "i_dipl"], ["militar", "Militar", "i_ejercito"],
	["politica", "Política", "i_gob"], ["economia", "Economía", "i_eco"]]
## Subsecciones de la pestaña Militar: [clave, texto]
const SUBS_MILITAR := [["res", "Resumen"], ["reg", "Regimientos"], ["rec", "Reclutar"], ["bat", "Batallas"]]
const TITULO_SECCION := {"general": "Información general", "diplomacia": "Diplomacia y guerras", "militar": "Fuerzas armadas",
	"politica": "Política y gobierno", "economia": "Economía"}

var main: Node
var fuente: Font
var fuente_neg: Font
var tema: Theme
var capa: CanvasLayer
var raiz: Control
var panel: PanelContainer
var panel_det: PanelContainer
var det_box: VBoxContainer
var cuerpo: VBoxContainer
var caja_militar: VBoxContainer
var tropas                                    # hud_tropas.gd: el manejo de tropas que vive dentro de la pestaña Militar
var lbl_titulo: Label
var lbl_sub: Label
var lbl_seccion: Label
var lbl_seccion_der: Label
var tex_bandera: TextureRect
var caja_migas: HFlowContainer
var fila_pestanas: HBoxContainer
var fila_sub: HBoxContainer
var lbl_coord: Label
var lbl_fps: Label
var lbl_hint: Label
var btn_pausa: Button
var btn_atras: Button
var btn_vista: Button
var popup_vista: PanelContainer               # 0.1.8.37: el menú VISTA (cuelga del botón de lentes)
var botones_vista := {}                       # clave de vista -> botón del menú
var datos: Dictionary = {}
var pestana := "general"
var sub_militar := "res"
var det_clave := ""
var secciones_abiertas := {"Naturaleza": true, "Descripción": true, "Población": true, "Etnias": false, "Ciudades principales": false,
	"Historial de guerras": false}
var botones_pestana := {}
var botones_sub := {}
# Barra superior (0.1.7.9.1)
var barra: PanelContainer
var tex_bandera_jug: TextureRect
var lbl_jugador: Label
var lbl_dinero: Label
var tex_dinero: TextureRect       # moneda de la divisa del país que controlas (0.1.8.41)
var _ico_din := ""
var lbl_ingreso: Label
var lbl_fecha: Label
var botones_vel := []            # pausa, 1, 2, 3
var botones_vel_extra := []      # 4, 5, 6 (ventanita que sale al pulsar la fecha)
var popup_vel: PanelContainer
var btn_debug: Button
var btn_ranking: Button
var btn_descubrimientos: Button
var btn_editar: Button
var scroll_cuerpo: ScrollContainer
var _t_dip := 0.0
var ancho_panel := 400.0                       # 0.1.8.3: ancho real del panel principal (≈30 % de la pantalla, entre 372 y 420)
var _compacto := false                        # 0.1.8.3: el panel solo muestra la cabecera (botón ▾/▸)
var btn_compacto: Button
var bloque_tabs: PanelContainer
var cab_marco: PanelContainer                 # 0.1.8.37: lo que lleva estilo de tema (se vuelve a pintar en `_pintar`)
var marco_bandera: PanelContainer
var marco_jug: PanelContainer
var barra_sec: PanelContainer
var btn_cerrar: Button
var _vel_actual := 0                          # velocidad puesta (a partir de la 4 la fecha va en naranja)
var _din_perdida := false                     # el ingreso diario es negativo
var _din_deuda := false                       # el país está en deuda
var _estilo_btns := {}                        # Button -> margen: los botones con estilo metálico propio (cambian con el tema)
var marco_seccion: PanelContainer
var _alto_max := 470.0                        # alto máximo de la sección con scroll (según la altura de la ventana)
var _ver_guerra := -1
var _msg_paz := ""                            # último resultado de una propuesta de paz (se muestra en Diplomacia)
var _guerra_pendiente := -1                   # 0.1.8.3: ID del país al que el jugador está a punto de declarar la guerra (pide una segunda pulsación para confirmar)
var _msg_guerra := ""                         # último resultado de declarar una guerra (se muestra en Diplomacia)
var _guerra_tid_vista := -2                   # país cuya ficha se vio la última vez (al cambiar se olvida la confirmación pendiente)

# 0.1.8.38 · Panel movible y redimensionable + tarjetas en columnas
const ANCHO_PANEL_USUARIO_MIN := 320.0       # lo más angosto que se puede dejar el panel arrastrando
const ANCHO_TARJETA := 340.0                 # ancho mínimo de una columna de tarjetas: el panel ancho las reparte en 2 o 3 columnas
const AGARRE_PANEL := 7.0                    # grosor (px) del borde del panel que se puede agarrar para cambiar su tamaño
const PB_IZQ := 1
const PB_DER := 2
const PB_ABA := 4
var _panel_mueve := false                    # arrastrando el panel por su cabecera
var _panel_borde := 0                        # bordes que se están arrastrando (suma de PB_*)
var _panel_movido := false                   # el jugador lo movió o le cambió el tamaño (si no, vuelve solo a su sitio)
var _items_cuerpo: Array = []                # lo que se dibujó en `cuerpo`, en su orden (para repartirlo en columnas)
var _cols_cuerpo: HBoxContainer              # las columnas de tarjetas (solo hay si caben 2 o más)
var _ult_cols := 1


func construir(m: Node, f: Font, f_neg: Font = null) -> void:
	main = m
	fuente = f
	fuente_neg = f_neg if f_neg != null else f
	capa = CanvasLayer.new()
	capa.layer = 5
	main.add_child(capa)
	tema = Tema.crear_tema(fuente, fuente_neg)
	raiz = Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = tema
	capa.add_child(raiz)
	var vp := raiz.get_viewport().get_visible_rect().size
	_alto_max = clampf(vp.y * 0.36, 170.0, 460.0)             # 0.1.8.3: antes vp.y - 365 (el panel llegaba casi hasta abajo)
	ancho_panel = clampf(vp.x * 0.30, ANCHO_PANEL_MIN, ANCHO_PANEL_MAX)

	# ── Panel principal ──
	panel = PanelContainer.new()
	panel.position = Vector2(14.0, PANEL_Y)
	if "geo_ventanas" in main and (main.geo_ventanas as Dictionary).has("panel_pais"):
		var g: Array = (main.geo_ventanas as Dictionary)["panel_pais"]            # vuelve donde y como lo dejaste
		ancho_panel = clampf((g[1] as Vector2).x, ANCHO_PANEL_USUARIO_MIN, maxf(vp.x - 16.0, ANCHO_PANEL_USUARIO_MIN))
		_alto_max = clampf((g[1] as Vector2).y, 150.0, maxf(vp.y - 200.0, 150.0))
		panel.position = Vector2(clampf((g[0] as Vector2).x, 0.0, maxf(vp.x - 120.0, 0.0)), clampf((g[0] as Vector2).y, ALTO_BARRA, maxf(vp.y - 100.0, ALTO_BARRA)))
		_panel_movido = true
	panel.custom_minimum_size = Vector2(ancho_panel, 0.0)
	panel.visible = false
	panel.gui_input.connect(_on_panel_input)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	# 1) CABECERA: bandera + nombre del país + cerrar
	cab_marco = PanelContainer.new()
	cab_marco.mouse_default_cursor_shape = Control.CURSOR_MOVE
	cab_marco.tooltip_text = "Mover el panel\nArrastra la cabecera para moverlo. Doble clic: vuelve a su sitio y a su tamaño."
	cab_marco.gui_input.connect(_on_cab_input)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	cab_marco.add_child(cab)
	vb.add_child(cab_marco)
	marco_bandera = PanelContainer.new()
	tex_bandera = TextureRect.new()
	tex_bandera.custom_minimum_size = Vector2(72.0, 48.0)
	tex_bandera.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS       # bandera HD (256 px) reducida: con mipmaps no se pixela
	tex_bandera.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_bandera.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marco_bandera.add_child(tex_bandera)
	cab.add_child(marco_bandera)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	lbl_titulo = _lbl("", 20, Tema.TITULO, true)
	lbl_titulo.clip_text = true
	lbl_titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_sub = _lbl("", 12, Tema.TITULO_TENUE)
	lbl_sub.clip_text = true
	lbl_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(lbl_titulo)
	col.add_child(lbl_sub)
	cab.add_child(col)
	btn_compacto = Button.new()
	btn_compacto.text = "▾"
	btn_compacto.flat = true
	btn_compacto.focus_mode = Control.FOCUS_NONE
	btn_compacto.tooltip_text = "Encoger el panel\nDeja solo el nombre; el mismo botón lo vuelve a abrir."
	btn_compacto.custom_minimum_size = Vector2(30.0, 30.0)
	btn_compacto.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn_compacto.add_theme_font_size_override("font_size", 16)
	btn_compacto.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_compacto.pressed.connect(func(): alternar_compacto())
	cab.add_child(btn_compacto)
	btn_cerrar = Button.new()
	btn_cerrar.text = "✕"
	btn_cerrar.flat = true
	btn_cerrar.focus_mode = Control.FOCUS_NONE
	btn_cerrar.tooltip_text = "Cerrar"
	btn_cerrar.custom_minimum_size = Vector2(30.0, 30.0)
	btn_cerrar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn_cerrar.add_theme_font_size_override("font_size", 16)
	btn_cerrar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_cerrar.pressed.connect(func(): cerrar_pedido.emit())
	cab.add_child(btn_cerrar)

	caja_migas = HFlowContainer.new()
	caja_migas.add_theme_constant_override("h_separation", 4)
	caja_migas.add_theme_constant_override("v_separation", 4)
	vb.add_child(caja_migas)

	# 2) FILA DE PESTAÑAS: su propia subsección, justo debajo del nombre
	bloque_tabs = PanelContainer.new()
	fila_pestanas = HBoxContainer.new()
	fila_pestanas.add_theme_constant_override("separation", 3)
	bloque_tabs.add_child(fila_pestanas)
	var grupo := ButtonGroup.new()
	for t in PESTANAS:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_group = grupo
		b.text = " " + String(t[1])
		b.icon = main.icono(String(t[2]))
		b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		b.expand_icon = true
		b.custom_minimum_size = Vector2(0.0, 30.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_constant_override("icon_max_width", 16)
		_estilo_boton(b, 4.0)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var clave: String = t[0]
		b.pressed.connect(func(): abrir_pestana(clave))
		botones_pestana[clave] = b
		fila_pestanas.add_child(b)
	botones_pestana["general"].button_pressed = true
	_estilizar_pestanas()
	vb.add_child(bloque_tabs)

	# 3) SECCIÓN DE LA PESTAÑA ABIERTA: título + (subpestañas) + contenido con scroll
	marco_seccion = PanelContainer.new()
	var vs := VBoxContainer.new()
	vs.add_theme_constant_override("separation", 6)
	marco_seccion.add_child(vs)
	vb.add_child(marco_seccion)
	barra_sec = PanelContainer.new()
	var hs := HBoxContainer.new()
	hs.add_theme_constant_override("separation", 8)
	barra_sec.add_child(hs)
	lbl_seccion = _lbl("", 14, Tema.TITULO, true)
	lbl_seccion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hs.add_child(lbl_seccion)
	lbl_seccion_der = _lbl("", 11, Tema.TITULO_TENUE)
	hs.add_child(lbl_seccion_der)
	vs.add_child(barra_sec)

	fila_sub = HBoxContainer.new()
	fila_sub.add_theme_constant_override("separation", 4)
	fila_sub.visible = false
	var grupo2 := ButtonGroup.new()
	for st in SUBS_MILITAR:
		var bs := Button.new()
		bs.toggle_mode = true
		bs.focus_mode = Control.FOCUS_NONE
		bs.button_group = grupo2
		bs.text = String(st[1])
		bs.custom_minimum_size = Vector2(0.0, 28.0)
		bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bs.add_theme_font_size_override("font_size", 12)
		_estilo_boton(bs, 3.0)
		bs.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sclave: String = st[0]
		bs.pressed.connect(func(): abrir_militar(sclave))
		botones_sub[sclave] = bs
		fila_sub.add_child(bs)
	botones_sub["res"].button_pressed = true
	vs.add_child(fila_sub)

	var scroll := ScrollContainer.new()
	scroll_cuerpo = scroll
	scroll.custom_minimum_size = Vector2(0.0, _alto_max)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var cont := VBoxContainer.new()
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cont.add_theme_constant_override("separation", 6)
	scroll.add_child(cont)
	cuerpo = VBoxContainer.new()
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_theme_constant_override("separation", 6)
	cont.add_child(cuerpo)
	caja_militar = VBoxContainer.new()
	caja_militar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja_militar.add_theme_constant_override("separation", 6)
	caja_militar.visible = false
	cont.add_child(caja_militar)
	vs.add_child(scroll)
	lbl_coord = _lbl("", 11, Tema.OK)
	vb.add_child(lbl_coord)
	raiz.add_child(panel)

	# El manejo de tropas (antes una ventana flotante) vive dentro de la pestaña Militar.
	tropas = TropasScript.new()
	add_child(tropas)
	tropas.construir(main, fuente, fuente_neg, caja_militar)

	# ── Panel de detalle (aparece a la derecha del principal) ──
	panel_det = PanelContainer.new()
	panel_det.position = Vector2(panel.position.x + ancho_panel + 8.0, panel.position.y)
	panel_det.custom_minimum_size = Vector2(300.0, 0.0)
	panel_det.visible = false
	var sc2 := ScrollContainer.new()
	sc2.custom_minimum_size = Vector2(0.0, minf(380.0, _alto_max + 60.0))
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	det_box = VBoxContainer.new()
	det_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det_box.add_theme_constant_override("separation", 10)
	sc2.add_child(det_box)
	panel_det.add_child(sc2)
	raiz.add_child(panel_det)

	# ── Pista de abajo (la versión, los FPS y los botones de arriba viven dentro de la barra superior: `_construir_barra`) ──
	lbl_hint = _lbl("", 13, Color(1, 1, 1, 0.78))
	lbl_hint.anchor_left = 0.5
	lbl_hint.anchor_right = 0.5
	lbl_hint.anchor_top = 1.0
	lbl_hint.anchor_bottom = 1.0
	lbl_hint.anchor_left = 0.0
	lbl_hint.anchor_right = 1.0
	lbl_hint.offset_left = 20.0
	lbl_hint.offset_right = -20.0
	lbl_hint.offset_top = -52.0
	lbl_hint.offset_bottom = -8.0
	lbl_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_hint.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
	lbl_hint.add_theme_constant_override("outline_size", 4)
	raiz.add_child(lbl_hint)

	_construir_barra()
	_pintar()


## 0.1.8.37 · Cambia el tema en vivo (`id` 0..2, ver tema_hud.gd): recrea el `Theme`, vuelve a pintar lo que tiene estilo propio y
## redibuja el contenido de las pestañas (así toda la pantalla queda con los colores nuevos sin reiniciar).
func aplicar_tema(id: int) -> void:
	Tema.aplicar(id)
	if raiz == null:
		return
	tema = Tema.crear_tema(fuente, fuente_neg)
	raiz.theme = tema
	_pintar()
	if tropas != null and tropas.has_method("aplicar_tema"):
		tropas.aplicar_tema()
	if panel != null and datos.size() > 0:
		_dibujar_migas()
		_dibujar()
		if det_clave != "" and panel_det != null and panel_det.visible:
			_detalle(det_clave, true)


## Estilos y colores de las piezas FIJAS del HUD (las que se construyen una vez). Lo que se dibuja en cada refresco ya sale con el tema vigente.
func _pintar() -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", Tema.panel(6.0))
	panel_det.add_theme_stylebox_override("panel", Tema.panel(12.0))
	popup_vel.add_theme_stylebox_override("panel", Tema.panel(6.0))
	popup_vista.add_theme_stylebox_override("panel", Tema.panel(6.0))
	barra.add_theme_stylebox_override("panel", Tema.barra(5.0))
	cab_marco.add_theme_stylebox_override("panel", Tema.cabecera(7.0))
	barra_sec.add_theme_stylebox_override("panel", Tema.cabecera(5.0))
	marco_bandera.add_theme_stylebox_override("panel", Tema.marco_bandera(3, 2))
	marco_jug.add_theme_stylebox_override("panel", Tema.marco_bandera(2, 1))
	bloque_tabs.add_theme_stylebox_override("panel", Tema.caja(Tema.BLOQUE, Tema.ACERO_OSCURO, 4, 4, 1))
	marco_seccion.add_theme_stylebox_override("panel", Tema.caja(Tema.BLOQUE_SUAVE, Tema.ACERO_OSCURO, 5, 6, 1))
	for b in _estilo_btns.keys():
		if is_instance_valid(b):
			_estilo_boton(b, float(_estilo_btns[b]))
		else:
			_estilo_btns.erase(b)
	for b in [btn_pausa, btn_atras, btn_vista] + botones_vel + botones_vel_extra:
		_tintar_icono(b)
	lbl_fps.add_theme_color_override("font_color", Tema.TENUE)
	btn_compacto.add_theme_color_override("font_color", Tema.TITULO_TENUE)
	btn_compacto.add_theme_color_override("font_hover_color", Tema.TITULO)
	btn_cerrar.add_theme_color_override("font_color", Tema.TITULO_TENUE)
	btn_cerrar.add_theme_color_override("font_hover_color", Tema.NARANJA)
	lbl_titulo.add_theme_color_override("font_color", Tema.TITULO)
	lbl_sub.add_theme_color_override("font_color", Tema.TITULO_TENUE)
	lbl_seccion.add_theme_color_override("font_color", Tema.TITULO)
	lbl_seccion_der.add_theme_color_override("font_color", Tema.TITULO_TENUE)
	lbl_coord.add_theme_color_override("font_color", Tema.OK)
	lbl_jugador.add_theme_color_override("font_color", Tema.ORO)
	lbl_dinero.add_theme_color_override("font_color", Tema.MAL if _din_deuda else Tema.TEXTO)
	lbl_ingreso.add_theme_color_override("font_color", Tema.MAL if _din_perdida else Tema.OK)
	lbl_fecha.add_theme_color_override("font_color", Tema.NARANJA if _vel_actual >= 4 else Tema.TEXTO)


## Los iconos de una sola tinta (pausa, atrás, velocidades) toman el color del texto del tema (oscuros sobre el pergamino, claros sobre lo oscuro);
## sobre un botón elegido llevan el color del texto elegido.
func _tintar_icono(b: Button) -> void:
	b.add_theme_color_override("icon_normal_color", Tema.TEXTO)
	b.add_theme_color_override("icon_hover_color", Tema.TEXTO)
	b.add_theme_color_override("icon_pressed_color", Tema.TEXTO_SEL)
	b.add_theme_color_override("icon_hover_pressed_color", Tema.TEXTO_SEL)
	b.add_theme_color_override("icon_focus_color", Tema.TEXTO)


## Pone al botón los estilos metálicos con el margen pedido (los iconos y botones chicos necesitan menos margen que el tema).
## Se acuerda del botón para volver a pintarlo cuando cambie el tema.
func _estilo_boton(b: Button, margen: float) -> void:
	_estilo_btns[b] = margen
	b.add_theme_stylebox_override("normal", Tema.boton("normal", margen))
	b.add_theme_stylebox_override("hover", Tema.boton("sobre", margen))
	b.add_theme_stylebox_override("pressed", Tema.boton("elegido", margen))
	b.add_theme_stylebox_override("hover_pressed", Tema.boton("elegido", margen))


# ───────────── Barra superior: país controlado, dinero, fecha y velocidad (0.1.7.9.1; clics en 0.1.7.9.9B) ─────────────
## Hace que un contenedor (con hijos) reaccione al clic izquierdo y se ilumine al pasar el ratón.
func _hacer_clicable(c: Control, accion: Callable, tip: String) -> void:
	_ignorar_raton(c)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.tooltip_text = tip
	c.mouse_entered.connect(func(): c.modulate = Color(1.25, 1.2, 1.0))
	c.mouse_exited.connect(func(): c.modulate = Color(1, 1, 1))
	c.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			accion.call())


func _boton_vel(icono: String, tip: String, grupo: ButtonGroup, ancho := 30.0) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.button_group = grupo
	b.icon = main.icono(icono)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 18)
	b.custom_minimum_size = Vector2(ancho, 28.0)
	b.tooltip_text = tip
	_estilo_boton(b, 2.0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _construir_barra() -> void:
	barra = PanelContainer.new()
	barra.anchor_left = 0.0
	barra.anchor_right = 1.0
	barra.offset_left = 0.0
	barra.offset_right = 0.0
	barra.offset_top = 0.0                                     # 0.1.8.37: pegada al borde de arriba, de lado a lado (ya no flota)
	barra.custom_minimum_size = Vector2(0.0, ALTO_BARRA)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	barra.add_child(fila)

	# izquierda: Debug, Ranking (solo campaña) y la versión con los FPS
	var izq := HBoxContainer.new()
	izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	izq.size_flags_stretch_ratio = 1.0
	izq.alignment = BoxContainer.ALIGNMENT_BEGIN
	izq.add_theme_constant_override("separation", 8)
	fila.add_child(izq)
	btn_debug = Button.new()
	btn_debug.custom_minimum_size = Vector2(38.0, 32.0)
	btn_debug.icon = main.icono("i_debug")
	btn_debug.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn_debug.expand_icon = true
	btn_debug.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_debug.add_theme_constant_override("icon_max_width", 20)
	btn_debug.focus_mode = Control.FOCUS_NONE
	btn_debug.tooltip_text = "Menú Debug\nSe abre encima del juego sin pausarlo.\nAtajo: F1"
	_estilo_boton(btn_debug, 3.0)
	btn_debug.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_debug.pressed.connect(func(): debug_pedido.emit())
	izq.add_child(btn_debug)
	btn_ranking = Button.new()
	btn_ranking.text = "Ranking"
	btn_ranking.custom_minimum_size = Vector2(84.0, 32.0)
	btn_ranking.focus_mode = Control.FOCUS_NONE
	btn_ranking.add_theme_font_size_override("font_size", 13)
	btn_ranking.tooltip_text = "Ranking\nTabla de posiciones de la campaña.\nAtajo: R"
	_estilo_boton(btn_ranking, 3.0)
	btn_ranking.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_ranking.pressed.connect(func(): ranking_pedido.emit())
	btn_ranking.visible = false
	izq.add_child(btn_ranking)
	btn_descubrimientos = Button.new()
	btn_descubrimientos.text = "Descubrimientos"
	btn_descubrimientos.icon = main.icono("i_estrella")
	btn_descubrimientos.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn_descubrimientos.add_theme_constant_override("icon_max_width", 18)       # sin expand_icon: el botón es de ancho automático
	btn_descubrimientos.custom_minimum_size = Vector2(0.0, 32.0)
	btn_descubrimientos.focus_mode = Control.FOCUS_NONE
	btn_descubrimientos.add_theme_font_size_override("font_size", 13)
	btn_descubrimientos.tooltip_text = "Descubrimientos\nTodo el catálogo (1.730): lo que conoces, lo que puedes investigar y lo que viene, con sus requisitos.\nAtajo: T"
	_estilo_boton(btn_descubrimientos, 3.0)
	btn_descubrimientos.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_descubrimientos.pressed.connect(func(): descubrimientos_pedido.emit())
	izq.add_child(btn_descubrimientos)
	lbl_fps = _lbl("", 12, Tema.TENUE)
	lbl_fps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	izq.add_child(lbl_fps)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_child(h)

	# país que controlas (clic: abre la pestaña General de su información, igual que pulsarlo en el mapa)
	var caja_j := HBoxContainer.new()
	caja_j.add_theme_constant_override("separation", 8)
	marco_jug = PanelContainer.new()
	tex_bandera_jug = TextureRect.new()
	tex_bandera_jug.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tex_bandera_jug.custom_minimum_size = Vector2(34.0, 22.0)
	tex_bandera_jug.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_bandera_jug.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marco_jug.add_child(tex_bandera_jug)
	marco_jug.visible = false
	caja_j.add_child(marco_jug)
	lbl_jugador = _lbl("Observador", 14, Tema.ORO, true)
	lbl_jugador.custom_minimum_size = Vector2(120.0, 0.0)
	lbl_jugador.clip_text = true
	lbl_jugador.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_jugador.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja_j.add_child(lbl_jugador)
	_hacer_clicable(caja_j, func(): jugador_pedido.emit(), "País que controlas: clic para abrir su pestaña General (se elige en Debug)")
	h.add_child(caja_j)
	btn_editar = Button.new()
	btn_editar.flat = true
	btn_editar.focus_mode = Control.FOCUS_NONE
	btn_editar.icon = main.icono("i_editar")
	btn_editar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn_editar.expand_icon = true
	btn_editar.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_editar.add_theme_constant_override("icon_max_width", 18)
	btn_editar.custom_minimum_size = Vector2(26.0, 26.0)
	btn_editar.tooltip_text = "Mi país\nPersonaliza tu país en cualquier momento: nombre, moneda, impuestos, desarrollo…"
	btn_editar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_editar.visible = false
	btn_editar.pressed.connect(func(): personalizar_pedido.emit())
	h.add_child(btn_editar)

	h.add_child(VSeparator.new())

	# dinero (clic: pestaña Economía del país que controlas)
	var caja_d := HBoxContainer.new()
	caja_d.add_theme_constant_override("separation", 5)
	tex_dinero = _icono_rect("i_moneda", 22.0)
	caja_d.add_child(tex_dinero)
	var col_d := VBoxContainer.new()
	col_d.add_theme_constant_override("separation", -2)
	lbl_dinero = _lbl("—", 14, Tema.TEXTO, true)
	lbl_ingreso = _lbl("", 10, Tema.OK)
	col_d.add_child(lbl_dinero)
	col_d.add_child(lbl_ingreso)
	caja_d.add_child(col_d)
	caja_d.custom_minimum_size = Vector2(150.0, 0.0)
	_hacer_clicable(caja_d, func(): dinero_pedido.emit(), "Tesorería de tu país (en su moneda) y lo que entra por día. Clic: abre su pestaña Economía")
	h.add_child(caja_d)

	h.add_child(VSeparator.new())

	# fecha (clic: abre las 3 velocidades extra)
	lbl_fecha = _lbl("", 16, Tema.TEXTO, true)
	lbl_fecha.custom_minimum_size = Vector2(96.0, 0.0)
	lbl_fecha.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_fecha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_fecha.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl_fecha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	lbl_fecha.tooltip_text = "Fecha\nAño, mes, día. Clic: velocidades 4, 5 y 6 (más rápidas)."
	lbl_fecha.mouse_entered.connect(func(): lbl_fecha.modulate = Color(1.25, 1.2, 1.0))
	lbl_fecha.mouse_exited.connect(func(): lbl_fecha.modulate = Color(1, 1, 1))
	lbl_fecha.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			alternar_popup_vel())
	h.add_child(lbl_fecha)

	# velocidad: pausa, x1, x2, x3
	var nombres := ["Pausar el tiempo (Espacio)", "Velocidad 1 (tecla 1)", "Velocidad 2 (tecla 2)", "Velocidad 3 (tecla 3)"]
	var iconos := ["i_tpausa", "i_vel1", "i_vel2", "i_vel3"]
	var grupo := ButtonGroup.new()
	for i in 4:
		var b := _boton_vel(iconos[i], nombres[i], grupo)
		var v := i
		b.pressed.connect(func(): velocidad_pedida.emit(v))
		botones_vel.append(b)
		h.add_child(b)

	# derecha: VISTA (menú de vistas), atrás y pausa
	var der := HBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	der.size_flags_stretch_ratio = 1.0
	der.alignment = BoxContainer.ALIGNMENT_END
	der.add_theme_constant_override("separation", 8)
	fila.add_child(der)
	btn_vista = Button.new()
	btn_vista.focus_mode = Control.FOCUS_NONE
	btn_vista.custom_minimum_size = Vector2(150.0, 32.0)
	btn_vista.icon = main.icono("i_lentes")
	btn_vista.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	btn_vista.expand_icon = true
	btn_vista.add_theme_constant_override("icon_max_width", 20)
	btn_vista.add_theme_font_size_override("font_size", 13)
	btn_vista.tooltip_text = "Vista del mapa\nCambia entre la vista tradicional y el relieve.\nAtajo: V"
	_estilo_boton(btn_vista, 6.0)
	btn_vista.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_vista.pressed.connect(alternar_menu_vista)
	der.add_child(btn_vista)
	btn_atras = _boton_icono("i_atras", "Atrás (Retroceso): sube un nivel o cierra el panel")
	btn_atras.visible = false
	btn_atras.pressed.connect(func(): atras_pedido.emit())
	der.add_child(btn_atras)
	btn_pausa = _boton_icono("i_pausa", "Pausa (Esc)")
	btn_pausa.pressed.connect(func(): pausa_pedida.emit())
	der.add_child(btn_pausa)
	raiz.add_child(barra)

	# menú VISTA (sale debajo del botón)
	popup_vista = PanelContainer.new()
	popup_vista.visible = false
	var pvv := VBoxContainer.new()
	pvv.add_theme_constant_override("separation", 3)
	popup_vista.add_child(pvv)
	pvv.add_child(_lbl("VISTA DEL MAPA", 10, Tema.TENUE))
	var grupo_v := ButtonGroup.new()
	for v in VISTAS:
		var bv := Button.new()
		bv.toggle_mode = true
		bv.button_group = grupo_v
		bv.focus_mode = Control.FOCUS_NONE
		bv.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bv.custom_minimum_size = Vector2(190.0, 30.0)
		bv.add_theme_font_size_override("font_size", 13)
		bv.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var cv: String = v[0]
		if bool(v[2]):
			bv.text = " " + String(v[1])
			bv.pressed.connect(func():
				popup_vista.visible = false
				vista_elegida.emit(cv))
		else:
			bv.text = " %s  ·  próximamente" % String(v[1])
			bv.disabled = true
		_estilo_boton(bv, 5.0)
		botones_vista[cv] = bv
		pvv.add_child(bv)
	botones_vista["tradicional"].set_pressed_no_signal(true)
	raiz.add_child(popup_vista)

	# ventanita con las velocidades 4-6 (sale debajo de la fecha)
	popup_vel = PanelContainer.new()
	popup_vel.visible = false
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	popup_vel.add_child(pv)
	pv.add_child(_lbl("MÁS RÁPIDO", 10, Tema.TENUE))
	var grupo2 := ButtonGroup.new()
	var etiquetas := ["4 · Rápido", "5 · Muy rápido", "6 · Máximo"]
	for j in 3:
		var v2 := 4 + j
		var b2 := _boton_vel("i_vel%d" % v2, "Velocidad %d (tecla %d)" % [v2, v2], grupo2, 150.0)
		b2.text = etiquetas[j]
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.add_theme_font_size_override("font_size", 13)
		b2.add_theme_constant_override("icon_max_width", 40)
		b2.add_theme_constant_override("h_separation", 8)
		b2.custom_minimum_size = Vector2(160.0, 30.0)
		b2.pressed.connect(func():
			velocidad_pedida.emit(v2)
			popup_vel.visible = false)
		botones_vel_extra.append(b2)
		pv.add_child(b2)
	raiz.add_child(popup_vel)


## Abre o cierra el menú VISTA (debajo del botón de lentes, alineado a su borde derecho).
func alternar_menu_vista() -> void:
	if popup_vista.visible:
		popup_vista.visible = false
		return
	popup_vel.visible = false
	popup_vista.reset_size()
	var r := btn_vista.get_global_rect()
	popup_vista.position = Vector2(clampf(r.end.x - popup_vista.size.x, 4.0, 4000.0), r.end.y + 6.0)
	popup_vista.visible = true


## Marca en el menú VISTA cuál está puesta.
func set_vista_activa(clave: String) -> void:
	for k in botones_vista.keys():
		(botones_vista[k] as Button).set_pressed_no_signal(k == clave)


func alternar_popup_vel() -> void:
	if popup_vel.visible:
		popup_vel.visible = false
		return
	popup_vista.visible = false
	popup_vel.reset_size()
	var r := lbl_fecha.get_global_rect()
	popup_vel.position = Vector2(r.position.x + r.size.x * 0.5 - popup_vel.size.x * 0.5, r.end.y + 10.0)
	popup_vel.visible = true


## La ventanita de velocidades se cierra al pulsar en cualquier otro sitio (sin consumir el clic).
func _input(ev: InputEvent) -> void:
	if popup_vel != null and popup_vel.visible and ev is InputEventMouseButton and ev.pressed:
		var pos: Vector2 = ev.position
		if not popup_vel.get_global_rect().has_point(pos) and not lbl_fecha.get_global_rect().has_point(pos):
			popup_vel.visible = false
	if popup_vista != null and popup_vista.visible and ev is InputEventMouseButton and ev.pressed:
		var pos2: Vector2 = ev.position
		if not popup_vista.get_global_rect().has_point(pos2) and not btn_vista.get_global_rect().has_point(pos2):
			popup_vista.visible = false


func set_fecha(t: String) -> void:
	lbl_fecha.text = t


func set_velocidad(v: int) -> void:
	for i in botones_vel.size():
		(botones_vel[i] as Button).set_pressed_no_signal(i == v)
	for j in botones_vel_extra.size():
		(botones_vel_extra[j] as Button).set_pressed_no_signal(4 + j == v)
	# con una velocidad extra la fecha se tiñe de naranja para que se note que vas rápido
	_vel_actual = v
	lbl_fecha.add_theme_color_override("font_color", Tema.NARANJA if v >= 4 else Tema.TEXTO)
	var estado := "en pausa" if v == 0 else "velocidad %d" % v
	lbl_fecha.tooltip_text = "Fecha\nAño, mes, día · %s. Clic: velocidades 4, 5 y 6 (más rápidas)." % estado


## nombre "" = sin país controlado (modo observador).
func set_jugador(nombre: String, bandera: String) -> void:
	if nombre == "":
		lbl_jugador.text = "Observador"
		tex_bandera_jug.get_parent().visible = false
		btn_editar.visible = false
		set_dinero("—", "")
	else:
		lbl_jugador.text = nombre
		tex_bandera_jug.texture = main.bandera_tex(bandera)
		tex_bandera_jug.get_parent().visible = true
		btn_editar.visible = true


func set_dinero(total: String, ingreso: String, perdida := false, en_deuda := false) -> void:
	lbl_dinero.text = total
	lbl_ingreso.text = ingreso
	_din_perdida = perdida
	_din_deuda = en_deuda
	lbl_ingreso.add_theme_color_override("font_color", Tema.MAL if perdida else Tema.OK)
	lbl_dinero.add_theme_color_override("font_color", Tema.MAL if en_deuda else Tema.TEXTO)
	var ico := "i_moneda"
	if main != null and main.materias != null and main.mundo != null and main.mundo.jugador != "":
		ico = main.materias.de_pais(main.mundo.jugador)                  # la moneda propia del país que controlas
	if ico != _ico_din:
		_ico_din = ico
		tex_dinero.texture = main.icono(ico)


# ───────────── utilidades de interfaz ─────────────
func _lbl(t: String, tam: int, col: Color, negrita := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", fuente_neg if negrita else fuente)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	return l


func _caja(col: Color, borde: Color, radio: int, margen: int, bw := 1) -> StyleBoxFlat:
	return Tema.caja(col, borde, radio, margen, bw)


## Botón cuadrado con un icono (en la barra superior).
func _boton_icono(ic: String, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40.0, 32.0)
	b.icon = main.icono(ic)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 20)
	b.tooltip_text = tip
	_estilo_boton(b, 4.0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _icono_rect(nombre: String, tam: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.texture = main.icono(nombre)
	tr.custom_minimum_size = Vector2(tam, tam)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _ignorar_raton(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for h in n.get_children():
		_ignorar_raton(h)


func _limpiar(contenedor: Node) -> void:
	for h in contenedor.get_children():
		contenedor.remove_child(h)
		h.queue_free()


func fmt_num(n: float) -> String:
	var s := str(int(roundf(n)))
	var out := ""
	var cuenta := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cuenta += 1
		if cuenta % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = "." + out
	return out


func fmt_pob(n: float) -> String:
	if n >= 1.0e9:
		return ("%.2f mil millones" % (n / 1.0e9)).replace(".", ",")
	if n >= 1.0e6:
		return ("%.1f millones" % (n / 1.0e6)).replace(".", ",")
	if n >= 10000.0:
		return "≈ " + fmt_num(roundf(n / 1000.0) * 1000.0)
	return fmt_num(n)


func pct(x: float) -> String:
	if x >= 10.0:
		return "%d%%" % int(roundf(x))
	return ("%.1f%%" % x).replace(".", ",")


func corto(s: String, n: int) -> String:
	if s.length() <= n:
		return s
	return s.substr(0, n - 1).strip_edges() + "…"


func cat_alt(med: float, mx: float) -> String:
	if mx < 300.0:
		return "Llanura / costa baja"
	if med < 200.0 and mx < 1200.0:
		return "Llanuras y colinas"
	if med < 600.0:
		return "Terreno ondulado y colinas"
	if med < 1500.0:
		return "Meseta o montaña media"
	return "Alta montaña / altiplano"


# ───────────── API pública ─────────────
func set_fps_texto(t: String) -> void:
	lbl_fps.text = t


func set_hint(t: String) -> void:
	lbl_hint.text = t


func set_vista_texto(t: String) -> void:
	btn_vista.text = " " + t


func set_atras_visible(v: bool) -> void:
	# visible si hay un país enfocado o hay un panel abierto (continente, país, provincia, ciudad, mar...)
	btn_atras.visible = v or panel.visible


func _actualizar_atras() -> void:
	btn_atras.visible = panel.visible or (main != null and String(main.pais_foco) != "")


func set_visible_todo(v: bool) -> void:
	capa.visible = v


## El botón «Ranking» solo existe en la campaña.
func set_campana(v: bool) -> void:
	if btn_ranking != null:
		btn_ranking.visible = v
	if panel != null and not _panel_movido:                        # 0.1.8.37: «Ranking» está dentro de la barra: el panel empieza justo debajo de ella (salvo que lo hayas movido)
		panel.position.y = PANEL_Y
	_acomodar_det()


func ocultar() -> void:
	panel.visible = false
	panel_det.visible = false
	det_clave = ""
	if tropas != null:
		tropas.activo = false
	_actualizar_atras()


func esta_abierto() -> bool:
	return panel.visible


## Pestañas que tiene cada tipo de selección. El mar solo tiene General; los continentes no tienen diplomacia ni política propias.
func pestanas_de(tipo: String, con_tropas := false) -> Array:
	match tipo:
		"mar":
			return ["general"]
		"libre":
			return ["general", "militar"] if con_tropas else ["general"]       # 0.1.8.39a: tierras sin reclamar: sin gobierno, diplomacia ni economía
		"continente":
			return ["general", "militar", "economia"]
		"pais":
			return ["general", "diplomacia", "militar", "politica", "economia"]
	return ["general", "militar", "politica", "economia"]


func _hay_ctx() -> bool:
	var c: Dictionary = datos.get("ctx", {})
	return not c.is_empty() and int(c.get("pais_tid", -1)) >= 0


## ¿Lo que se muestra tiene tropas que manejar (un país, estado, provincia o ciudad)?
func tiene_ctx() -> bool:
	return _hay_ctx()


## Cambia a la pestaña `clave` (general, diplomacia, militar, politica, economia) y la dibuja. Devuelve false si esa pestaña no existe aquí.
func abrir_pestana(clave: String) -> bool:
	if not botones_pestana.has(clave) or not (botones_pestana[clave] as Button).visible:
		return false
	pestana = clave
	_fin_firma = 0
	for k in botones_pestana:
		(botones_pestana[k] as Button).set_pressed_no_signal(k == clave)
	_estilizar_pestanas()
	_dibujar()
	return true


## Abre la pestaña Militar en la subsección `sub` (res, reg, rec, bat).
func abrir_militar(sub: String) -> void:
	if not botones_sub.has(sub):
		return
	sub_militar = sub
	for k in botones_sub:
		(botones_sub[k] as Button).set_pressed_no_signal(k == sub)
	if pestana != "militar":
		abrir_pestana("militar")
	else:
		_dibujar()


## Pone al día las finanzas del país abierto (cuando pasan los días) sin mover el scroll ni cerrar el detalle.
var _fin_firma := 0                       # huella de lo último dibujado en Economía: si no cambió, no se reconstruye (20 ms por refresco)


func actualizar_fin(fin: Array, fin_det: Dictionary) -> void:
	if not panel.visible:
		return
	datos["fin"] = fin
	datos["fin_det"] = fin_det
	if pestana == "economia":
		var firma: int = hash(str(fin)) ^ hash(str(fin_det)) ^ (1 if panel_det.visible else 0)
		if firma == _fin_firma:
			return
		_fin_firma = firma
		var y: int = scroll_cuerpo.scroll_vertical
		_dibujar()
		scroll_cuerpo.scroll_vertical = y
		if panel_det.visible and fin_det.has(det_clave):
			_detalle(det_clave, true)


## Pone al día la pestaña Militar (cada mes pasan cosas: edades, experiencia) sin mover el scroll ni cerrar el detalle.
func refrescar_ejercito() -> void:
	if not panel.visible or pestana != "militar":
		return
	if sub_militar != "res" and _hay_ctx():
		tropas.refrescar_ya()
		return
	var y: int = scroll_cuerpo.scroll_vertical
	_dibujar()
	scroll_cuerpo.scroll_vertical = y
	if panel_det.visible and det_clave.begins_with("pel:"):
		_detalle(det_clave, true)


## Ningún botón del HUD debe quedarse con el foco: así Espacio, 1-6, V y Retroceso siguen llegando al juego.
func _sin_foco(n: Node) -> void:
	if n is Button:
		(n as Button).focus_mode = Control.FOCUS_NONE
	for h in n.get_children():
		_sin_foco(h)


## 0.1.8.32 · Refresco periódico del MISMO elemento (el mapa cambió de dueños, pasaron días...). Las pestañas General y Economía solo dependen de `d`: si
## no cambió nada de lo que traen, no se reconstruyen (eran 20-35 ms cada ~1 s, con el panel abierto y la guerra en marcha). General no enseña las
## finanzas ni la economía (cambian cada día: no cuentan). Política, Diplomacia y Militar leen el estado vivo del juego (no de `d`): se rehacen siempre.
const CLAVES_SOLO_ECONOMIA := ["fin", "fin_det", "eco"]

func refrescar(d: Dictionary) -> void:
	if panel.visible and (pestana == "general" or pestana == "economia") and _firma_visible(d) == _firma_visible(datos):
		datos = d                                                 # lo que se ve es igual, pero los datos que no se ven (finanzas...) quedan al día
		return
	mostrar(d)


## Huella de lo que enseña la pestaña actual (General o Economía) con los datos `x`.
func _firma_visible(x: Dictionary) -> int:
	if pestana != "general":
		return hash(x)
	var c := x.duplicate()
	for k in CLAVES_SOLO_ECONOMIA:
		c.erase(k)
	return hash(c)


func mostrar(d: Dictionary) -> void:
	datos = d
	_fin_firma = 0
	det_clave = ""
	panel_det.visible = false
	var tipo := String(d.get("tipo", ""))
	var lista := pestanas_de(tipo, _hay_ctx())
	for k in botones_pestana:
		(botones_pestana[k] as Button).visible = lista.has(k)
	if not lista.has(pestana):
		pestana = "general"
		for k2 in botones_pestana:
			(botones_pestana[k2] as Button).set_pressed_no_signal(k2 == "general")
		_estilizar_pestanas()
	lbl_titulo.text = String(d.get("titulo", ""))
	lbl_sub.text = String(d.get("subtitulo", "")) + (" · %d elegidos (Ctrl+clic)" % int(d["multi"]) if int(d.get("multi", 0)) > 1 else "")
	var bandera: String = String(d.get("bandera", "-"))
	tex_bandera.get_parent().visible = bandera != "-"
	if bandera != "-":
		tex_bandera.texture = main.bandera_hd(bandera)
	lbl_coord.text = String(d.get("coord", ""))
	_dibujar_migas()
	if _hay_ctx():
		var c: Dictionary = d["ctx"]
		tropas.apuntar(int(c.get("prov_tid", -1)), int(c["pais_tid"]))
	panel.visible = true
	_dibujar()
	panel.reset_size()
	_actualizar_atras()


## Icono de cada nivel de las migas (cuando el sitio no tiene bandera propia).
const ICONO_MIGA := {"continente": "i_cont", "pais": "i_pais", "estado": "i_estado", "provincia": "i_prov", "ciudad": "i_ciudad", "mar": "i_prof"}


## 0.1.8.41 · Migas rediseñadas: cada una es una píldora con su bandera (o el icono de su nivel) y el nombre. La última (donde estás) va rellena y en
## negrita; las demás, apagadas y con realce al pasar el ratón; clic = ir a ese nivel. Antes eran botones con la bandera como icono y no se veía.
func _dibujar_migas() -> void:
	_limpiar(caja_migas)
	var migas: Array = datos.get("migas", [])
	for i in migas.size():
		var m: Dictionary = migas[i]
		var nivel := String(m["nivel"])
		var activo: bool = i == migas.size() - 1
		var ac: Color = C_ACENTO.get(nivel, Tema.TENUE)
		var chip := PanelContainer.new()
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.tooltip_text = "%s\n%s" % [String(m["tipo"]), "Aquí estás." if activo else "Clic: ir a %s." % String(m["nombre"])]
		var fondo := _chip_miga(ac, activo, false)
		chip.add_theme_stylebox_override("panel", fondo)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 5)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(hb)
		var bandera := String(m.get("bandera", ""))
		var ico := TextureRect.new()
		ico.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ico.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if bandera != "" and bandera != "x" and bandera != "-":
			ico.texture = main.bandera_tex(bandera)
			ico.custom_minimum_size = Vector2(21.0, 14.0)
		else:
			ico.texture = main.icono(String(ICONO_MIGA.get(nivel, "i_prov")))
			ico.custom_minimum_size = Vector2(16.0, 16.0)
		hb.add_child(ico)
		var et := _lbl(String(m["nombre"]), 12, Color(1, 1, 1) if activo else Tema.TITULO, activo)
		et.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(et)
		var nom := String(m["nombre"])
		chip.mouse_entered.connect(func(): chip.add_theme_stylebox_override("panel", _chip_miga(ac, activo, true)))
		chip.mouse_exited.connect(func(): chip.add_theme_stylebox_override("panel", fondo))
		chip.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				miga_pedida.emit(nivel, nom))
		caja_migas.add_child(chip)
		if i < migas.size() - 1:
			var sep := _lbl("›", 15, ac.lightened(0.15))
			sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			caja_migas.add_child(sep)


func _chip_miga(ac: Color, activo: bool, realce: bool) -> StyleBoxFlat:
	var e: StyleBoxFlat
	if realce:
		e = _caja(ac.darkened(0.35), Color(1, 1, 1, 0.9), 12, 3, 1)
	elif activo:
		e = _caja(ac.darkened(0.55), ac.lightened(0.1), 12, 3, 2)
	else:
		e = _caja(Tema.CABECERA_ABAJO, ac.darkened(0.15), 12, 3, 1)
	e.content_margin_left = 7
	e.content_margin_right = 9
	e.content_margin_top = 2
	e.content_margin_bottom = 2
	return e


# ───────────── contenido por pestaña ─────────────
func _dibujar() -> void:
	_limpiar(cuerpo)
	_items_cuerpo = []                                              # las tarjetas se anotan solas en `_seccion`
	_cols_cuerpo = null
	var tipo := String(datos.get("tipo", ""))
	var hay := _hay_ctx()
	var en_tropas: bool = pestana == "militar" and hay and sub_militar != "res"
	fila_sub.visible = pestana == "militar" and hay
	cuerpo.visible = not en_tropas
	caja_militar.visible = en_tropas
	tropas.activo = en_tropas and panel.visible
	lbl_seccion.text = String(TITULO_SECCION.get(pestana, ""))
	lbl_seccion_der.text = _contexto_seccion()
	match pestana:
		"general":
			if tipo == "mar":
				_tab_mar()
			else:
				_tab_general()
		"diplomacia":
			_tab_diplomacia()
		"militar":
			if en_tropas:
				tropas.ir_a(sub_militar)
			else:
				_tab_ejercito()
		"politica":
			_tab_politica()
		"economia":
			_tab_economia()
	_sin_foco(cuerpo)
	_ult_cols = _columnas_tarjetas()
	_ajustar_alto()


## 0.1.8.3: con el panel angosto solo la pestaña abierta lleva texto; las demás quedan como icono (el nombre sale al pasar el ratón).
func _estilizar_pestanas() -> void:
	for t in PESTANAS:
		var b: Button = botones_pestana[t[0]]
		var activa: bool = (t[0] == pestana)
		b.text = (" " + String(t[1])) if activa else ""
		b.tooltip_text = String(t[1])
		b.size_flags_stretch_ratio = TAB_RATIO_ACTIVA if activa else 1.0


## 0.1.8.3: encoge el panel a solo la cabecera (nombre + bandera) o lo vuelve a abrir. Se recuerda entre selecciones.
func alternar_compacto() -> void:
	poner_compacto(not _compacto)


## Pone el panel en modo compacto (`c` = true: solo la cabecera) o completo; ajusta el botón ▾/▸ y oculta/muestra migas, pestañas, contenido y coordenadas.
func poner_compacto(c: bool) -> void:
	_compacto = c
	if btn_compacto != null:
		btn_compacto.text = "▸" if c else "▾"
	for n in [caja_migas, bloque_tabs, marco_seccion, lbl_coord]:
		if n != null:
			(n as Control).visible = not c
	if panel_det != null and c:
		panel_det.visible = false
	if panel != null:
		panel.reset_size()
	if not c:
		_ajustar_alto()


## La sección con scroll se ajusta a lo que lleva (con tope según la altura de la ventana); el manejo de tropas usa siempre el alto máximo
## para que no salte al elegir regimientos.
func _ajustar_alto() -> void:
	if panel == null:
		return
	if tropas != null and tropas.activo:
		scroll_cuerpo.custom_minimum_size.y = _alto_max
		panel.reset_size()
		return
	await get_tree().process_frame
	if panel == null or not panel.visible or (tropas != null and tropas.activo):
		return
	scroll_cuerpo.custom_minimum_size.y = clampf(cuerpo.get_combined_minimum_size().y + 8.0, 150.0, _alto_max)
	panel.reset_size()


## ─────────── 0.1.8.38 · Panel movible y redimensionable ───────────
## Cabecera: arrastrar mueve el panel; doble clic lo devuelve a su sitio y tamaño de siempre.
func _on_cab_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and ev.double_click:
			volver_panel()
			return
		_panel_mueve = ev.pressed
		if not ev.pressed:
			_guardar_geo_panel()
	elif ev is InputEventMouseMotion and _panel_mueve:
		mover_panel(ev.relative)


func mover_panel(rel: Vector2) -> void:
	var vp := raiz.get_viewport().get_visible_rect().size
	panel.position = Vector2(clampf(panel.position.x + rel.x, 120.0 - panel.size.x, maxf(vp.x - 120.0, 0.0)), clampf(panel.position.y + rel.y, ALTO_BARRA, maxf(vp.y - 60.0, ALTO_BARRA)))
	_panel_movido = true
	_acomodar_det()


## Devuelve el panel a su sitio, su ancho y su alto de siempre.
func volver_panel() -> void:
	var vp := raiz.get_viewport().get_visible_rect().size
	_alto_max = clampf(vp.y * 0.36, 170.0, 460.0)
	ancho_panel = clampf(vp.x * 0.30, ANCHO_PANEL_MIN, ANCHO_PANEL_MAX)
	panel.custom_minimum_size.x = ancho_panel
	panel.position = Vector2(14.0, PANEL_Y)
	_panel_movido = false
	panel.reset_size()
	_acomodar_tarjetas()
	_ajustar_alto()
	_acomodar_det()
	if "geo_ventanas" in main:
		(main.geo_ventanas as Dictionary).erase("panel_pais")


func _guardar_geo_panel() -> void:
	if _panel_movido and "geo_ventanas" in main:
		(main.geo_ventanas as Dictionary)["panel_pais"] = [panel.position, Vector2(ancho_panel, _alto_max)]


## Qué bordes del panel toca un punto (coordenadas del panel): izquierdo, derecho o de abajo (el de arriba no se agarra: el alto lo da el contenido).
func _borde_panel_en(p: Vector2) -> int:
	var b := 0
	if p.x <= AGARRE_PANEL:
		b |= PB_IZQ
	elif p.x >= panel.size.x - AGARRE_PANEL:
		b |= PB_DER
	if p.y >= panel.size.y - AGARRE_PANEL and not _compacto:
		b |= PB_ABA
	return b


func _on_panel_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_panel_borde = _borde_panel_en(ev.position) if ev.pressed else 0
		if not ev.pressed:
			_guardar_geo_panel()
	elif ev is InputEventMouseMotion:
		if _panel_borde != 0:
			arrastrar_borde_panel(_panel_borde, ev.relative)
		else:
			var b := _borde_panel_en(ev.position)
			if b == (PB_IZQ | PB_ABA) or b == (PB_DER | PB_ABA):
				panel.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if b == (PB_DER | PB_ABA) else Control.CURSOR_BDIAGSIZE
			elif b & (PB_IZQ | PB_DER):
				panel.mouse_default_cursor_shape = Control.CURSOR_HSIZE
			elif b & PB_ABA:
				panel.mouse_default_cursor_shape = Control.CURSOR_VSIZE
			else:
				panel.mouse_default_cursor_shape = Control.CURSOR_ARROW


## Cambia el ancho (bordes izquierdo y derecho) o el alto máximo de la sección con scroll (borde de abajo) lo que se movió el ratón.
func arrastrar_borde_panel(b: int, rel: Vector2) -> void:
	var vp := raiz.get_viewport().get_visible_rect().size
	var tope_ancho := maxf(vp.x - 16.0, ANCHO_PANEL_USUARIO_MIN)
	var antes := ancho_panel
	if b & PB_DER:
		ancho_panel = clampf(ancho_panel + rel.x, ANCHO_PANEL_USUARIO_MIN, tope_ancho)
	if b & PB_IZQ:
		ancho_panel = clampf(ancho_panel - rel.x, ANCHO_PANEL_USUARIO_MIN, tope_ancho)
		panel.position.x += antes - ancho_panel
	if b & PB_ABA:
		var resto := panel.size.y - scroll_cuerpo.size.y                       # lo que ocupan cabecera, pestañas y pie: el panel no debe salirse por abajo
		_alto_max = clampf(_alto_max + rel.y, 150.0, maxf(vp.y - panel.position.y - resto - 8.0, 150.0))
	_panel_movido = true
	panel.custom_minimum_size.x = ancho_panel
	panel.reset_size()
	if _columnas_tarjetas() != _ult_cols:
		_acomodar_tarjetas()
	_ajustar_alto()
	_acomodar_det()


## El panel de detalle va pegado al lado del panel principal (a la derecha; si ya no cabe, a la izquierda).
func _acomodar_det() -> void:
	if panel_det == null or panel == null:
		return
	var vp := raiz.get_viewport().get_visible_rect().size
	var ancho_det := maxf(panel_det.size.x, panel_det.custom_minimum_size.x)
	var x := panel.position.x + maxf(panel.size.x, ancho_panel) + 8.0
	if x + ancho_det > vp.x:
		x = panel.position.x - ancho_det - 8.0
	panel_det.position = Vector2(clampf(x, 0.0, maxf(vp.x - ancho_det, 0.0)), panel.position.y)


## Cuántas columnas de tarjetas caben en el ancho actual del panel (1 = el panel de siempre).
func _columnas_tarjetas() -> int:
	return clampi(int(floor((ancho_panel - 28.0) / ANCHO_TARJETA)), 1, 3)


## Reparte lo dibujado en `cuerpo` en columnas (cada tarjeta, a la columna más baja); con una sola columna lo deja como siempre, una debajo de otra.
func _acomodar_tarjetas() -> void:
	if cuerpo == null:
		return
	if _columnas_tarjetas() <= 1 and _cols_cuerpo == null:               # ya están una debajo de otra, tal como se dibujaron: no hay que tocar nada (mover cientos de nodos cuesta)
		_ult_cols = 1
		return
	for it in _items_cuerpo:
		if is_instance_valid(it) and (it as Node).get_parent() != null:
			(it as Node).get_parent().remove_child(it)
	if _cols_cuerpo != null and is_instance_valid(_cols_cuerpo):
		_cols_cuerpo.get_parent().remove_child(_cols_cuerpo)
		_cols_cuerpo.queue_free()
	_cols_cuerpo = null
	var n := _columnas_tarjetas()
	_ult_cols = n
	if n <= 1 or _items_cuerpo.size() < 2:
		for it in _items_cuerpo:
			if is_instance_valid(it):
				cuerpo.add_child(it)
		return
	_crear_columnas(n)
	var altos: Array = []
	for i in n:
		altos.append(0.0)
	for it in _items_cuerpo:
		if not is_instance_valid(it):
			continue
		var k := 0
		for i in n:
			if float(altos[i]) < float(altos[k]):
				k = i
		_cols_cuerpo.get_child(k).add_child(it)
		altos[k] = float(altos[k]) + (it as Control).get_combined_minimum_size().y + 6.0


## Crea las `n` columnas vacías de tarjetas dentro de `cuerpo`.
func _crear_columnas(n: int) -> void:
	_cols_cuerpo = HBoxContainer.new()
	_cols_cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cols_cuerpo.add_theme_constant_override("separation", 6)
	for i in n:
		var c := VBoxContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		c.add_theme_constant_override("separation", 6)
		_cols_cuerpo.add_child(c)
	cuerpo.add_child(_cols_cuerpo)


## Pone una tarjeta recién dibujada: debajo de las demás si hay una sola columna; si hay varias, en la columna más baja en este momento
## (así se arma directo, sin mover nodos después).
func _poner_tarjeta(card: Control) -> void:
	var n := _columnas_tarjetas()
	if n <= 1:
		cuerpo.add_child(card)
		return
	if _cols_cuerpo == null:
		_crear_columnas(n)
	var k := 0
	var menor := 1e30
	for i in _cols_cuerpo.get_child_count():
		var h := (_cols_cuerpo.get_child(i) as Control).get_combined_minimum_size().y
		if h < menor - 0.5:
			menor = h
			k = i
	_cols_cuerpo.get_child(k).add_child(card)


## Texto pequeño a la derecha del título de la sección: de qué país o territorio habla.
func _contexto_seccion() -> String:
	var tipo := String(datos.get("tipo", ""))
	if tipo == "" or tipo == "mar":
		return ""
	var c: Dictionary = datos.get("ctx", {})
	if c.has("pais_nombre") and String(c["pais_nombre"]) != "" and tipo != "pais":
		return "de " + String(c["pais_nombre"])
	return ""


func _seccion(titulo: String) -> VBoxContainer:
	var card := PanelContainer.new()                                  # 0.1.8.38: cada tema es una tarjeta con marco
	card.add_theme_stylebox_override("panel", Tema.caja(Tema.BLOQUE_SUAVE, Tema.ACERO_OSCURO, 5, 5, 1))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	var abierta: bool = secciones_abiertas.get(titulo, true)
	var cab := Button.new()
	cab.flat = true
	cab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cab.text = ("▾  " if abierta else "▸  ") + titulo.to_upper()
	cab.add_theme_font_override("font", fuente_neg)
	cab.add_theme_font_size_override("font_size", 12)
	cab.add_theme_color_override("font_color", Tema.ORO)
	cab.add_theme_color_override("font_hover_color", Tema.TEXTO)
	cab.add_theme_stylebox_override("normal", Tema.cabecera(4.0))
	cab.add_theme_stylebox_override("hover", Tema.boton("sobre", 4.0))
	cab.add_theme_stylebox_override("pressed", Tema.boton("sobre", 4.0))
	cab.add_theme_stylebox_override("hover_pressed", Tema.boton("sobre", 4.0))
	cab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	vb.add_child(cab)
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 4)
	contenido.visible = abierta
	vb.add_child(contenido)
	cab.pressed.connect(func():
		var nueva := not contenido.visible
		contenido.visible = nueva
		secciones_abiertas[titulo] = nueva
		cab.text = ("▾  " if nueva else "▸  ") + titulo.to_upper()
		_ajustar_alto())
	_items_cuerpo.append(card)
	_poner_tarjeta(card)
	return contenido


func _fila(padre: Node, ic: String, titulo: String, valor: String, clave := "", banner := "") -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Tema.tarjeta(false, 6.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	card.add_child(vb)
	if banner != "":
		var ban := TextureRect.new()
		ban.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ban.texture = main.icono("bioma_" + banner)
		ban.custom_minimum_size = Vector2(0, 46)
		ban.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ban.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		vb.add_child(ban)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	hb.add_child(_icono_rect(ic, 26.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	var cap := _lbl(titulo.to_upper(), 10, Tema.TENUE)
	var val := _lbl(valor, 13, Tema.TEXTO)
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(cap)
	col.add_child(val)
	hb.add_child(col)
	if clave != "":
		hb.add_child(_lbl("›", 18, Tema.ORO))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_ignorar_raton(card)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", Tema.tarjeta(true, 6.0)))
		card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", Tema.tarjeta(false, 6.0)))
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_detalle(clave))
	else:
		_ignorar_raton(card)
	padre.add_child(card)


func _barra(padre: Node, nombre: String, valor: float, col: Color, ancho := 150.0) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var l := _lbl(nombre, 12, Tema.TEXTO)
	l.custom_minimum_size = Vector2(118.0, 0.0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(l)
	var fondo := ColorRect.new()
	fondo.color = Tema.BARRA_FONDO
	fondo.custom_minimum_size = Vector2(ancho, 14.0)
	fondo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rel := ColorRect.new()
	rel.color = col
	rel.size = Vector2(ancho * clampf(valor, 0.0, 100.0) / 100.0, 14.0)
	fondo.add_child(rel)
	hb.add_child(fondo)
	hb.add_child(_lbl(pct(valor), 12, col))
	padre.add_child(hb)


func _nota(padre: Node, t: String) -> void:
	var l := _lbl(t, 11, Tema.NOTA)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	padre.add_child(l)


## Botón de acción dentro de una pestaña.
func _boton(padre: Node, t: String, accion: Callable, deshabilitado := false) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, 30.0)
	b.disabled = deshabilitado
	b.add_theme_font_size_override("font_size", 13)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(accion)
	padre.add_child(b)
	return b


func _d() -> Dictionary:
	return datos.get("d", {})


## GENERAL: naturaleza, descripción, población, etnias y ciudades (lo que antes estaba repartido entre General y Demografía).
func _tab_general() -> void:
	var d := _d()
	_card_pintura()
	_card_grupo()
	var biomas: Dictionary = main.info.get("biomas", {})
	var bio: Array = d.get("bio", [])
	var reino := String(d.get("reino", "PAL"))
	var sec := _seccion("Naturaleza")
	if d.is_empty():
		_nota(sec, "Sin datos de naturaleza para esta entidad.")
	else:
		if bio.size() > 0 and biomas.has(bio[0][0]):
			var cod := String(bio[0][0])
			var b: Dictionary = biomas[cod]
			_fila(sec, "i_veg", "Vegetación", "%s (%d%%)" % [b["n"], int(bio[0][1])], "veg", cod)
			_fila(sec, "i_flora", "Flora", corto(String(b["flora"]), 70), "flora")
			_fila(sec, "i_fauna", "Fauna", corto(String(b["fauna"].get(reino, "")), 70), "fauna")
		_fila(sec, "i_alt", "Altitud", "media %s m · máx. ≈ %s m" % [fmt_num(float(d["alt"])), fmt_num(float(d["altmax"]))], "alt")
	var sd := _seccion("Descripción")
	for par in datos.get("desc", []):
		_fila(sd, String(par[2]) if par.size() > 2 else "i_info", String(par[0]), String(par[1]), String(par[3]) if par.size() > 3 else "")
	if String(datos.get("tipo", "")) == "libre":                      # 0.1.8.39a: tierras sin reclamar: sin población, etnias, ciudades ni economía
		_nota(sd, "Nadie gobierna esta zona: no tiene población registrada, ejército, diplomacia ni economía.")
		return
	var sp := _seccion("Población")
	if not d.is_empty():
		var pob := float(d["pob"])
		_fila(sp, "i_pob", "Población (%d, est.)" % main.epoca, fmt_pob(pob), "pob")
		_fila(sp, "i_dens", "Densidad", "%s hab/km²" % fmt_num(pob / maxf(float(d["area"]), 1.0)), "pob")
		_fila(sp, "i_area", "Superficie", "%s km²" % fmt_num(float(d["area"])), "area")
		var padre: Dictionary = datos.get("padre", {})
		if padre.has("pob"):
			var cj := VBoxContainer.new()
			cj.add_theme_constant_override("separation", 4)
			sp.add_child(cj)
			_nota(cj, "Peso en " + String(datos.get("padre_n", "")))
			_barra(cj, "Población", 100.0 * pob / maxf(float(padre["pob"]), 1.0), C_BARRAS[0])
			_barra(cj, "Superficie", 100.0 * float(d["area"]) / maxf(float(padre["area"]), 1.0), C_BARRAS[1])
	else:
		_nota(sp, "Sin datos de población.")
	_tarjetas_provincia()
	var etn: Array = datos.get("etn", [])
	if not etn.is_empty() or not d.is_empty():
		var se := _seccion("Etnias")
		if etn.is_empty():
			_nota(se, "Sin datos de etnias para esta entidad.")
		else:
			for i in etn.size():
				_barra(se, String(etn[i][0]), float(etn[i][1]), C_BARRAS[i % C_BARRAS.size()])
			_nota(se, "Composición nacional aproximada.")
	var ciu: Array = datos.get("ciudades", [])
	if ciu.size() > 0:
		var sc := _seccion("Ciudades principales")
		for c in ciu:
			_fila(sc, "i_ciudad", String(c[0]), "%s hab." % fmt_num(float(c[1])))


# ───────────── 0.1.8.40 · tarjetas de provincia: Ingreso, Edificios, Cores, y el resumen de un grupo (Ctrl+clic) ─────────────
## Las provincias que cubre lo elegido (las manda el mapa en `datos["ed_pis"]`: la provincia, todas las del país o estado, o la unión del grupo).
func _pis_ed() -> Array:
	return datos.get("ed_pis", [])


## [símbolo, unidades por US$] de la divisa del país.
func _moneda(pais: String) -> Array:
	var dv = main.mundo.divisa_de(pais)
	return [String(dv.simbolo) if dv != null else "US$", float(dv.por_usd) if dv != null else 1.0]


## Una línea pequeña «texto · valor» (sin la tarjeta con icono de `_fila`): para listas largas de edificios u obras.
func _linea(padre: Node, t: String, v: String, col_v: Color, icono := "") -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	if icono != "":
		var tr := TextureRect.new()
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.texture = main.icono(icono)
		tr.custom_minimum_size = Vector2(22.0, 22.0)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tr)
	var a := _lbl(t, 12, Tema.TEXTO)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.clip_text = true
	a.custom_minimum_size = Vector2(110.0, 0.0)
	hb.add_child(a)
	hb.add_child(_lbl(v, 12, col_v))
	padre.add_child(hb)


## GRUPO (Ctrl+clic): cuántas unidades hay elegidas y lo que suman. Va arriba de todo.
## 0.1.8.41 · La pintura clásica del país (o de su región, continente o el mundo) como cabecera de la pestaña General. Sin pintura instalada no aparece.
func _card_pintura() -> void:
	var f: Dictionary = datos.get("pintura", {})
	if f.is_empty() or main.pinturas == null:
		return
	var tex: Texture2D = main.pinturas.textura(String(f["ruta"]))
	if tex == null:
		return
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Tema.caja(Tema.BLOQUE_SUAVE, Tema.ACERO_OSCURO, 5, 3, 1))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	card.add_child(vb)
	var img := TextureRect.new()
	img.texture = tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size = Vector2(0.0, ALTO_PINTURA)
	img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	img.mouse_filter = Control.MOUSE_FILTER_PASS
	var donde := {"pais": "", "region": "una pintura de su región", "continente": "una pintura de su continente", "mundo": "una pintura del mundo"}
	img.tooltip_text = "%s\n%s\n%s%s" % [String(f["titulo"]), String(f["texto"]), String(f["licencia"]) + " · Wikimedia Commons",
		("" if String(donde.get(String(f["nivel"]), "")) == "" else "\nEste lugar no tiene pintura propia: se muestra " + String(donde[String(f["nivel"])]) + ".")]
	vb.add_child(img)
	var cap := _lbl(String(f["texto"]), 10, Tema.NOTA)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cap)
	_items_cuerpo.append(card)
	_poner_tarjeta(card)


func _card_grupo() -> void:
	var n_sel := int(datos.get("multi", 0))
	var pis := _pis_ed()
	if n_sel < 2 or pis.is_empty() or main.mundo.edificios == null:
		return
	var m = main.mundo
	var ed = m.edificios
	var sec := _seccion("Grupo elegido")
	var tids := []
	var prod := 0.0
	var paises := {}
	for pi in pis:
		var pr = m.provincias[int(pi)]
		tids.append(pr.tid)
		prod += pr.ingreso_anual_usd()
		paises[String(pr.pais)] = true
	_fila(sec, "i_prov", "Elegido", "%d unidades · %s provincias de %d %s" % [n_sel, fmt_num(float(pis.size())), paises.size(), "país" if paises.size() == 1 else "países"])
	_fila(sec, "i_pob", "Población total", fmt_pob(m.bd.suma("poblacion", tids)))
	_fila(sec, "i_eco", "Producción anual total", main.fmt_dinero(prod, "US$"))
	_fila(sec, "i_prov", "Edificios", "%s construidos · %d obras en curso" % [fmt_num(float(ed.total_en(pis))), ed.obras_en(pis)])
	var b := _boton(sec, "Construir en el grupo…", func(): construir_pedido.emit(pis.duplicate()))
	b.tooltip_text = "Construir en el grupo\nAbre la ventana Construir con todas las provincias elegidas. Una orden se reparte en cada provincia donde se pueda."
	_nota(sec, "Ctrl+clic suma o quita unidades. Las órdenes de construcción solo valen para provincias de tu país.")


## Ingreso, Edificios y Cores: de la provincia (o ciudad) elegida; o los totales si es un país, un estado o un grupo.
func _tarjetas_provincia() -> void:
	var pis := _pis_ed()
	var m = main.mundo
	if pis.is_empty() or m.edificios == null:
		return
	var tipo := String(datos.get("tipo", ""))
	var una := (tipo == "provincia" or tipo == "ciudad") and pis.size() == 1 and int(datos.get("multi", 0)) < 2
	if una:
		_card_ingreso(int(pis[0]))
	_card_edificios(pis, una)
	_card_cores(pis, una)


func _card_ingreso(pi: int) -> void:
	var m = main.mundo
	var pr = m.provincias[pi]
	var pais: String = pr.pais
	var mon := _moneda(pais)
	var sim: String = mon[0]
	var por: float = mon[1]
	var sec := _seccion("Ingreso")
	var ico_m: String = main.materias.de_pais(pais) if main.materias != null else "i_moneda"        # la moneda del país dueño
	var prod: float = pr.ingreso_anual_usd()
	_fila(sec, "i_eco", "Producción anual", "%s%s" % [main.fmt_dinero(prod * por, sim), "" if sim == "US$" else "  (≈ %s)" % main.fmt_dinero(prod, "US$")])
	var rend: float = pr.rendimiento_usd()
	var f_rend: float = (0.5 + pr.favorabilidad / 100.0) * (1.0 - main.E.DEVASTACION_EFECTO * pr.devastacion)
	_fila(sec, ico_m, "Rendimiento real", "%s al año · ×%s" % [main.fmt_dinero(rend * por, sim), ("%.2f" % f_rend).replace(".", ",")])
	var tasa: float = m.paises[pais].tasa_fiscal if m.paises.has(pais) else 0.25
	var diario: float = pr.ingreso_efectivo_usd() * tasa / 365.25 * por
	if pr.ocupante >= 0:
		_fila(sec, "i_devast", "Aporta a la tesorería", "0 · ocupada por %s" % m.bd.nombre_de(pr.ocupante))
	else:
		_fila(sec, ico_m, "Aporta a la tesorería", "%s por día (impuesto %d %%)" % [main.fmt_dinero(diario, sim), int(roundf(tasa * 100.0))])
	var total: float = m.produccion_anual_usd(pais)
	if total > 0.0 and pr.ocupante < 0:
		_fila(sec, "i_pais", "Peso en los ingresos del país", pct(100.0 * rend / maxf(total, 1.0)))
	_nota(sec, "Favorabilidad %d · devastación %d %%: una población descontenta o una tierra arrasada rinde menos." % [int(roundf(pr.favorabilidad)), int(roundf(pr.devastacion * 100.0))])


func _card_edificios(pis: Array, una: bool) -> void:
	var m = main.mundo
	var ed = m.edificios
	var sec := _seccion("Edificios")
	var total: int = ed.total_en(pis)
	var obras: int = ed.obras_en(pis)
	var tot: Dictionary = ed.totales_de(pis)
	_fila(sec, "i_prov", "Construidos", "%s edificios (%d tipos)%s" % [fmt_num(float(total)), tot.size(),
		"" if una else " en %s provincias" % fmt_num(float(pis.size()))])
	if not tot.is_empty():
		var claves := tot.keys()
		claves.sort_custom(func(a, b): return int(tot[a]) > int(tot[b]) or (int(tot[a]) == int(tot[b]) and ed.indice(a) < ed.indice(b)))
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 2)
		sec.add_child(caja)
		for i in mini(claves.size(), 8):
			var e: int = ed.indice(String(claves[i]))
			_linea(caja, String(ed.nombre[e]), "×%d" % int(tot[claves[i]]), Tema.ORO, "edificios/" + String(ed.slug[e]))
		if claves.size() > 8:
			_nota(caja, "… y %d tipos más (ventana Construir)." % (claves.size() - 8))
	else:
		_nota(sec, "Todavía no hay ningún edificio." if una else "Todavía no hay edificios en estas provincias.")
	if obras > 0:
		var ob_caja := VBoxContainer.new()
		ob_caja.add_theme_constant_override("separation", 2)
		sec.add_child(ob_caja)
		ob_caja.add_child(_lbl("EN OBRA (%d)" % obras, 10, Tema.TENUE))
		var filas := []
		for pi in pis:
			for o in ed.obras_de(int(pi)):
				filas.append(o)
		filas.sort_custom(func(a, b): return int(a["falta"]) < int(b["falta"]))
		for i in mini(filas.size(), 6):
			var o: Dictionary = filas[i]
			_linea(ob_caja, String(ed.nombre[int(o["e"])]), "%d %% · faltan %d d" % [int(roundf(float(o["pct"]))), int(o["falta"])], Tema.TENUE, "edificios/" + String(ed.slug[int(o["e"])]))
		if filas.size() > 6:
			_nota(ob_caja, "… y %d obras más." % (filas.size() - 6))
	var b := _boton(sec, "Construir…", func(): construir_pedido.emit(pis.duplicate()))
	b.tooltip_text = "Construir\nAbre la ventana Construir: los edificios que conoces, su costo en dinero y sus días de obra."
	_nota(sec, "Cuestan dinero de la tesorería y tardan días. Todavía no tienen efectos en el juego.")


func _card_cores(pis: Array, una: bool) -> void:
	var m = main.mundo
	if m.cores == null or not m.cores.listo:
		return
	var cs = m.cores
	var sec := _seccion("Cores")
	if una:
		var pi := int(pis[0])
		var nac: String = cs.nacional(pi)
		var rel: String = cs.relacion(pi)
		var txt_nac: String = "Sin core nacional" if nac == "" else main._nombre_vis(nac)
		if rel == "propia":
			txt_nac += " · tierra propia"
		elif rel == "ajena":
			txt_nac += " · hoy la controla %s" % main._nombre_vis(String(m.provincias[pi].pais))
		_fila(sec, "i_gob", "Core nacional", txt_nac)
		var igual: bool = cs.misma_cultura_que_dueno(pi)
		_fila(sec, "i_etn", "Core cultural", "%s · %s" % [cs.etiqueta_cultural(pi), "misma cultura que su dueño" if igual else "distinta a la de su dueño"])
		_nota(sec, "El core es de quién es la tierra por historia y cultura; no cambia al conquistarla. Todavía sin efectos.")
		return
	var cuenta: Dictionary = cs.contar(pis)
	var propias: int = cuenta["propias"]
	var ajenas: int = cuenta["ajenas"]
	var libres: int = cuenta["libres"]
	var culturas: Dictionary = cuenta["culturas"]
	_fila(sec, "i_gob", "Core nacional", "%s propias · %s de otro país · %s sin core" % [fmt_num(float(propias)), fmt_num(float(ajenas)), fmt_num(float(libres))])
	if not culturas.is_empty():
		var ks := culturas.keys()
		ks.sort_custom(func(a, b): return int(culturas[a]) > int(culturas[b]))
		var partes := []
		for i in mini(ks.size(), 3):
			partes.append("%s (%s)" % [m.mandos.etiqueta_cultura(String(ks[i])) if m.mandos != null else String(ks[i]), fmt_num(float(culturas[ks[i]]))])
		_fila(sec, "i_etn", "Core cultural", ", ".join(PackedStringArray(partes)) + (" y %d más" % (ks.size() - 3) if ks.size() > 3 else ""))
	var pais_sel: String = String(main.sel_ref.get("pais", "")) if main.sel_tipo == "pais" and int(datos.get("multi", 0)) < 2 else ""
	if pais_sel != "":
		var recl: Array = cs.reclamos_de(pais_sel)
		if not recl.is_empty():
			_fila(sec, "i_prov", "Provincias que reclama", "%s con su core nacional que hoy controla otro país" % fmt_num(float(recl.size())))
	_nota(sec, "Todavía sin efectos en el juego.")


func _tab_mar() -> void:
	var m: Dictionary = datos.get("mar", {})
	var sec := _seccion("Naturaleza")
	if not m.is_empty():
		_fila(sec, "i_area", "Superficie", "%s km²" % fmt_num(float(m["a"])), "mar")
		_fila(sec, "i_prof", "Profundidad máxima", "≈ %s m" % fmt_num(float(m["pmax"])), "mar")
		_fila(sec, "i_prof", "Profundidad media", "≈ %s m" % fmt_num(float(m["pmed"])), "mar")
	_fila(sec, "i_prof", "Profundidad en este punto", "≈ %s m" % fmt_num(float(datos.get("aqui", 0))), "mar")
	var sd := _seccion("Descripción")
	for par in datos.get("desc", []):
		_fila(sd, "i_info", String(par[0]), String(par[1]))


# 0.1.7.9.1: la pestaña Economía solo muestra la PRODUCCIÓN PRINCIPAL (lo que más ingresos genera en la zona).
# Si el rubro más grande es agrícola o extractivo se nombra el producto concreto (café, petróleo...);
# si es de servicios, manufactura, turismo, etc., se nombra el rubro.
static func produccion_principal(e: Dictionary) -> Dictionary:
	var rub: Array = e.get("rub", []) if e.get("rub", []) is Array else []
	var cult: Array = e.get("cult", []) if e.get("cult", []) is Array else []      # algunos países traen "—" (texto) en vez de lista
	var mat: Array = e.get("mat", []) if e.get("mat", []) is Array else []
	if rub.is_empty():
		if mat.size() > 0:
			return {"nombre": String(mat[0]), "pct": 0.0, "icono": "i_mineral"}
		if cult.size() > 0:
			return {"nombre": String(cult[0]), "pct": 0.0, "icono": "i_cultivo"}
		return {}
	var top: Array = rub[0]
	for r in rub:
		if String(r[0]) != "Otros" and float(r[1]) > float(top[1]):
			top = r
	var nombre := String(top[0])
	var bajo := nombre.to_lower()
	var ico := "i_eco"
	var p0 := nombre.find("(")
	var p1 := nombre.find(")")
	if p0 >= 0 and p1 > p0:
		var dentro := nombre.substr(p0 + 1, p1 - p0 - 1).strip_edges()
		nombre = dentro.substr(0, 1).to_upper() + dentro.substr(1)
		ico = "i_cultivo"
	elif "agricultura" in bajo or "agroindustria" in bajo or "cultivo" in bajo:
		ico = "i_cultivo"
		if cult.size() > 0:
			nombre = String(cult[0])
	elif "petr" in bajo or "gas" in bajo or "miner" in bajo or "carb" in bajo or "energ" in bajo or "extract" in bajo:
		ico = "i_mineral"
		if mat.size() > 0:
			nombre = String(mat[0])
	return {"nombre": nombre, "pct": float(top[1]), "icono": ico, "rubro": String(top[0])}


func _tab_economia() -> void:
	var fin: Array = datos.get("fin", [])
	if fin.size() > 0:
		var sf := _seccion("Finanzas")
		for f in fin:
			_fila(sf, String(f[2]), String(f[0]), String(f[1]), String(f[3]) if f.size() > 3 else "")
	var e: Dictionary = datos.get("eco", {})
	var pp := produccion_principal(e)
	if pp.is_empty():
		if fin.is_empty():
			var s0 := _seccion("Economía")
			_nota(s0, "Sin datos económicos para esta entidad.")
		return
	var s := _seccion("Producción principal")
	var valor := String(pp["nombre"])
	if float(pp["pct"]) > 0.0:
		valor += "  ·  %s de los ingresos" % pct(float(pp["pct"]))
	_fila(s, _icono_producto(pp), "Lo que más ingresos genera", valor, "eco_prod")
	_nota(s, String(e.get("nota", "")))
	_card_materias(e)


## Icono de la producción principal: el de su cultivo, mineral o rubro (materias/sectores); si no hay, el genérico que ya traía.
func _icono_producto(pp: Dictionary) -> String:
	var ico := String(pp.get("icono", "i_eco"))
	if main.materias == null:
		return ico
	return main.materias.o_defecto(String(pp.get("nombre", "")), String(pp.get("rubro", "")), ico)


## Tarjeta «Recursos de la zona»: cultivos, ganado y materias primas de la zona, cada uno con su icono.
func _card_materias(e: Dictionary) -> void:
	if main.materias == null or not main.materias.listo:
		return
	var grupos := [["Cultivos", "cult"], ["Ganadería", "carne"], ["Materias primas", "mat"]]
	var sec: VBoxContainer = null
	for g in grupos:
		var lista = e.get(String(g[1]), [])
		if not (lista is Array):
			continue
		var vistos := {}
		var nombres := []
		for n in lista:
			var t := String(n).strip_edges()
			if t == "" or t == "—" or vistos.has(t):
				continue
			vistos[t] = true
			nombres.append(t)
		if nombres.is_empty():
			continue
		if sec == null:
			sec = _seccion("Recursos de la zona")
		sec.add_child(_lbl(String(g[0]).to_upper(), 10, Tema.TENUE))
		var flujo := HFlowContainer.new()
		flujo.add_theme_constant_override("h_separation", 6)
		flujo.add_theme_constant_override("v_separation", 4)
		for t in nombres:
			flujo.add_child(_chip_material(t))
		sec.add_child(flujo)


func _chip_material(nombre: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tema.tarjeta(false, 4.0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	var ico: String = main.materias.de_nombre(nombre)
	if ico != "":
		h.add_child(_icono_rect(ico, 24.0))
	h.add_child(_lbl(nombre, 12, Tema.TEXTO))
	p.add_child(h)
	_ignorar_raton(p)
	return p


func _efecto(rub: Array) -> String:
	var top: Array = rub[0]
	for r in rub:
		if float(r[1]) > float(top[1]):
			top = r
	var p := float(top[1])
	if p >= 40.0:
		return "Dependencia alta de «%s» (%s): un cambio en su precio o producción mueve fuerte todo el crecimiento." % [top[0], pct(p)]
	if p >= 28.0:
		return "«%s» (%s) es el motor principal; afecta de forma notable al crecimiento." % [top[0], pct(p)]
	return "Economía diversificada: ningún rubro pasa de %s, así que los choques se reparten." % pct(p)


## POLÍTICA (antes «Gobierno»): forma de gobierno, jefe de Estado y registro de soberanía.
func _tab_politica() -> void:
	var s := _seccion("Gobierno")
	var pol: Dictionary = main.politica_vista()
	_fila(s, "i_gob", "Tipo de gobierno", "Mecánica en desarrollo")
	var jefe := String(pol.get("jefe", ""))
	_fila(s, "i_estrella", "Jefe de Estado", jefe if jefe != "" else "Sin dato (mecánica en desarrollo)")
	_fila(s, "i_info", "Estabilidad y leyes", "Mecánica en desarrollo")
	var reg: Array = datos.get("soberania", [])
	if reg.size() > 0:
		var ss := _seccion("Soberanía (registro)")
		for r in reg:
			_fila(ss, "i_pais", String(r[0]), String(r[1]))
	_nota(cuerpo, "Aquí irán forma de gobierno, leyes y estabilidad. Las relaciones con otros países están en la pestaña Diplomacia.")


# ───────────── DIPLOMACIA ─────────────
## Una fila con la bandera de otro país, su nombre y una etiqueta de estado (clic: abre ese país).
func _fila_pais(padre: Node, nombre: String, bandera: String, estado: String, col_estado: Color, detalle := "") -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Tema.tarjeta(false, 5.0))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	card.add_child(hb)
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", Tema.marco_bandera(2, 1))
	var tr := TextureRect.new()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.texture = main.bandera_tex(bandera)
	tr.custom_minimum_size = Vector2(34.0, 22.0)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	marco.add_child(tr)
	hb.add_child(marco)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(_lbl(nombre, 13, Tema.TEXTO, true))
	if detalle != "":
		var ld := _lbl(detalle, 11, Tema.TENUE)
		ld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(ld)
	hb.add_child(col)
	hb.add_child(_lbl(estado, 12, col_estado, true))
	_ignorar_raton(card)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = "Clic: abrir " + nombre
	card.mouse_entered.connect(func(): card.add_theme_stylebox_override("panel", Tema.tarjeta(true, 5.0)))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", Tema.tarjeta(false, 5.0)))
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			miga_pedida.emit("pais", nombre))
	padre.add_child(card)


func _tab_diplomacia() -> void:
	var v: Dictionary = main.diplomacia_vista()
	if v.is_empty():
		var s0 := _seccion("Diplomacia")
		_nota(s0, "Elige un país para ver sus relaciones.")
		return
	if int(v.get("tid", -1)) != _guerra_tid_vista:                 # otro país elegido: se olvida la confirmación pendiente y el último mensaje
		_guerra_tid_vista = int(v.get("tid", -1))
		_guerra_pendiente = -1
		_msg_guerra = ""
	var guerras: Array = v["guerras"]
	var abiertas := []
	var cerradas := []
	for g in guerras:
		if bool(g["activa"]):
			abiertas.append(g)
		else:
			cerradas.append(g)
	# situación general
	var ss := _seccion("Situación")
	if abiertas.is_empty():
		_fila(ss, "i_estrella", "Estado actual", "En paz: ninguna guerra abierta")
	else:
		var nombres := []
		for g in abiertas:
			nombres.append(String(g["rival"]))
		_fila(ss, "i_devast", "Estado actual", "EN GUERRA con %s" % ", ".join(PackedStringArray(nombres)))
	if bool(v.get("tesoreria_en_rojo", false)):
		_fila(ss, "i_devast", "Tesorería", "EN ROJO: sin dinero para pagar al ejército, los soldados desertan cada día")
	if int(v["extranjeros_aqui"]) > 0:
		_fila(ss, "i_ejercito", "Tropas extranjeras en su territorio", "%s soldados" % fmt_num(float(v["extranjeros_aqui"])))
	if int(v["propias_afuera"]) > 0:
		_fila(ss, "i_ejercito", "Sus tropas en el extranjero", "%s soldados" % fmt_num(float(v["propias_afuera"])))
	# 0.1.8.3 · declarar la guerra: relación con el país elegido, o los vecinos a los que podrías declararla desde tu propia ficha
	var rel_j: Dictionary = v.get("relacion", {})
	if not rel_j.is_empty():
		var sr := _seccion("Relación contigo")
		if bool(rel_j["en_guerra"]):
			_fila(sr, "i_devast", "Estado", "EN GUERRA con %s (la paz se propone desde TU ficha > Diplomacia)" % String(rel_j["rival"]))
		else:
			_fila(sr, "i_estrella", "Estado", "En paz con %s" % String(rel_j["rival"]))
			if int(rel_j["tregua"]) > 0:
				_nota(sr, "Hay una tregua: la IA no te declarará la guerra en %s. Tú puedes romperla." % main.texto_duracion(int(rel_j["tregua"])))
			_boton_guerra(sr, String(rel_j["rival"]), int(rel_j["tid"]), bool(rel_j["puede"]), String(rel_j["motivo"]))
	var declarables: Array = v.get("declarables", [])
	if not declarables.is_empty():
		var sdg := _seccion("Declarar la guerra")
		_nota(sdg, "Entrar con tropas en el territorio de otro país exige estar en guerra con él. Declárasela aquí (pide una segunda pulsación para confirmar):")
		for dg in declarables:
			_boton_guerra(sdg, String(dg["nombre"]), int(dg["tid"]), bool(dg["puede"]), String(dg["motivo"]), int(dg["tregua"]))
	if _msg_guerra != "":
		var sdm := _seccion("Declaración")
		_nota(sdm, _msg_guerra)
	# guerras abiertas
	var sg := _seccion("Guerras abiertas")
	if abiertas.is_empty():
		_nota(sg, "Este país no está en guerra con nadie.")
	for g in abiertas:
		var det := "%s · %s · desde %s\n%d batallas · bajas propias %s · bajas del rival %s" % [String(g["rol"]), String(g["causa"]), String(g["inicio_txt"]),
			int(g["batallas"]), fmt_num(float(g["bajas_propias"])), fmt_num(float(g["bajas_rival"]))]
		_fila_pais(sg, String(g["rival"]), String(g["rival_bandera"]), "EN GUERRA", Tema.MAL, det)
		var mi_tid := int(v.get("tid", -1))
		var rival_tid := int(g["rival_tid"])
		var linea_oc := "Ocupas %d provincias de %s (%s de lo que produce) · te ocupa %d provincias (%s de lo tuyo)" % [int(g.get("ocupa_rival_n", 0)),
			String(g["rival"]), pct(100.0 * float(g.get("ocupa_rival_pct", 0.0))), int(g.get("ocupa_mias_n", 0)), pct(100.0 * float(g.get("ocupa_mias_pct", 0.0)))]
		_nota(sg, linea_oc)
		if bool(v["puede_ordenar"]):
			_nota(sg, "Proponer la paz a %s (si la acepta, se firma al instante):" % String(g["rival"]))
			for op in g.get("paz", []):
				var clave := String(op["clave"])
				var etiqueta := "%s%s" % [String(op["texto"]), "" if bool(op["acepta"]) else "  (rechazaría)"]
				var b := _boton(sg, etiqueta, func(): _proponer_paz(mi_tid, rival_tid, clave))
				b.tooltip_text = String(op["tip"]) + ("" if bool(op["acepta"]) else "\n" + String(op["motivo"]))
	if _msg_paz != "":
		_nota(sg, _msg_paz)
	_nota(sg, "Para entrar con tropas en el territorio de otro país hay que declararle la guerra (en su ficha > Diplomacia). Si tus tropas se quedan 3 días solas en una provincia suya, la OCUPAN: no rinde ingresos a su dueño hasta la paz.")
	# aliados y vasallos
	var sa := _seccion("Aliados y vasallos")
	var rel: Array = v["relacionados"]
	if rel.is_empty():
		_nota(sa, "Todavía no hay aliados ni vasallos: son mecánicas en desarrollo. Cuando existan, sus tropas también se verán en tu mapa.")
	for r in rel:
		_fila_pais(sa, String(r["nombre"]), String(r["bandera"]), "Aliado", Tema.OK)
	# vecinos
	var sv := _seccion("Vecinos por tierra")
	var vec: Array = v["vecinos"]
	if vec.is_empty():
		_nota(sv, "No tiene fronteras terrestres con otros países (o no hay datos de la red de provincias).")
	for n in vec:
		var guerra: bool = bool(n["guerra"])
		_fila_pais(sv, String(n["nombre"]), String(n["bandera"]), "En guerra" if guerra else "En paz", Tema.MAL if guerra else Tema.OK,
			"%d %s en la frontera" % [int(n["tramos"]), "provincia" if int(n["tramos"]) == 1 else "provincias"])
	# sucesos recientes (ocupaciones, paces, impagos)
	var suc: Array = v.get("sucesos", [])
	if not suc.is_empty():
		var sus := _seccion("Sucesos recientes")
		for e in suc:
			_nota(sus, "%s · %s" % [String(e["fecha_txt"]), String(e["texto"])])
	# historial
	if not cerradas.is_empty():
		var sh := _seccion("Historial de guerras")
		for g in cerradas:
			var det2 := "%s · %s\n%s – %s · %d batallas" % [String(g["rol"]), String(g["causa"]), String(g["inicio_txt"]), String(g["fin_txt"]), int(g["batallas"])]
			_fila_pais(sh, String(g["rival"]), String(g["rival_bandera"]), "Terminada", Tema.TENUE, det2)


## Botón «Declarar la guerra a X». La primera pulsación pide confirmar (cambia el texto); la segunda declara la guerra. `tregua` > 0: avisa de que se rompe.
## `puede` = false lo deja apagado y muestra `motivo` (por qué no se puede).
func _boton_guerra(padre: Node, nombre: String, tid: int, puede: bool, motivo: String, tregua := 0) -> void:
	var pendiente: bool = _guerra_pendiente == tid and puede
	var txt := "¿Seguro? Pulsa otra vez: declarar la guerra a %s" % nombre if pendiente else "Declarar la guerra a %s" % nombre
	if tregua > 0 and not pendiente:
		txt += "  (tregua: %s)" % main.texto_duracion(tregua)
	var b := _boton(padre, txt, func(): _pulsar_guerra(tid), not puede)
	if pendiente:
		b.add_theme_color_override("font_color", Tema.MAL)
	b.tooltip_text = motivo if not puede else "Declara la guerra a %s. Después podrás mandar tropas a su territorio." % nombre
	if not puede and motivo != "":
		_nota(padre, motivo)


## Pulsación del botón de guerra contra `tid`: la 1.ª vez queda «pendiente de confirmar»; la 2.ª declara la guerra (`MapaPrincipal.declarar_guerra_jugador`),
## guarda el mensaje del resultado y redibuja la pestaña sin perder la posición del scroll.
func _pulsar_guerra(tid: int) -> void:
	if _guerra_pendiente != tid:
		_guerra_pendiente = tid
		_msg_guerra = ""
	else:
		_guerra_pendiente = -1
		var res: Dictionary = main.declarar_guerra_jugador(tid)
		_msg_guerra = String(res.get("msg", ""))
		if bool(res.get("ok", false)):
			main.hud_aviso(_msg_guerra)
	var y: int = scroll_cuerpo.scroll_vertical
	_dibujar()
	scroll_cuerpo.scroll_vertical = y


## Propone la paz con la condición elegida («blanca», «posesion», «indemnizacion»). El mensaje (acepta o rechaza) queda en la pestaña.
func _proponer_paz(a: int, d: int, clave: String) -> void:
	var res: Dictionary = main.proponer_paz(a, d, clave)
	_msg_paz = String(res.get("msg", ""))
	if bool(res.get("ok", false)):
		main.hud_aviso(_msg_paz)
	var y: int = scroll_cuerpo.scroll_vertical
	_dibujar()
	scroll_cuerpo.scroll_vertical = y
	if main.capa_tropas != null:
		main.capa_tropas.refrescar()


## MILITAR · Resumen: soldados, experiencia, mando supremo y reparto. Los datos los arma MapaPrincipal.ejercito_vista() según lo seleccionado.
func _tab_ejercito() -> void:
	var v: Dictionary = main.ejercito_vista()
	if v.is_empty():
		var s0 := _seccion("Ejército")
		_nota(s0, "Sin datos de ejército para esta selección.")
		return
	var res: Dictionary = v["resumen"]
	var sold := int(res["soldados"])
	var s := _seccion(String(v["titulo"]))
	if _hay_ctx():
		_nota(s, "Para dar órdenes usa las subsecciones «Regimientos», «Reclutar» y «Batallas» de arriba.")
	if sold <= 0:
		_nota(s, "No hay tropas registradas aquí.")
	else:
		_fila(s, "i_ejercito", "Soldados", "%s en %d pelotones" % [fmt_num(sold), int(res["pelotones"])])
		if float(v.get("pob", 0.0)) > 0.0:
			_fila(s, "i_pob", "Sobre la población", pct(100.0 * sold / float(v["pob"])))
		_fila(s, "i_info", "Edad media", ("%.1f años" % float(res["edad"])).replace(".", ","))
		var caja := VBoxContainer.new()
		caja.add_theme_constant_override("separation", 4)
		s.add_child(caja)
		_barra(caja, "Experiencia", float(res["exp"]), C_BARRAS[0], 120.0)
		_barra(caja, "Familiaridad", float(res["fam"]), C_BARRAS[1], 120.0)
		_barra(caja, "Forma física", float(res["fis"]), C_BARRAS[2], 120.0)
		if int(res["bajas"]) > 0:
			_fila(s, "i_devast", "Bajas acumuladas", fmt_num(float(res["bajas"])))
	if int(v.get("extranjeros", 0)) > 0:
		_fila(s, "i_pais", "Tropas extranjeras en su territorio", fmt_num(float(v["extranjeros"])))
	var mando: Array = v.get("mando", [])
	if mando.size() > 0:
		var sm := _seccion("Mando supremo")
		for m in mando:
			_fila(sm, "i_estrella", String(m["cargo"]), String(m["nombre"]))
	var rep: Array = v.get("reparto", [])
	if rep.size() > 0:
		var sr := _seccion(String(v.get("reparto_titulo", "Reparto")))
		for r in rep:
			_fila(sr, "i_prov", String(r[0]), "%s soldados · %d pelotones" % [fmt_num(float(r[1])), int(r[2])])
		var mas: int = int(v.get("reparto_n", 0)) - rep.size()
		if mas > 0:
			_nota(sr, "y %d más…" % mas)
	if v.has("devastacion"):
		var se := _seccion("Estado de la provincia")
		var cj := VBoxContainer.new()
		cj.add_theme_constant_override("separation", 4)
		se.add_child(cj)
		_barra(cj, "Devastación", float(v["devastacion"]) * 100.0, Color(0.93, 0.45, 0.35), 120.0)
		_barra(cj, "Riesgo de motín", float(v["motin"]) * 100.0, Color(0.93, 0.62, 0.30), 120.0)
		_nota(se, "Favorabilidad de la población: %d / 100. El riesgo de motín (fórmula provisional) sube con la devastación, el descontento y la poca familiaridad de la tropa; todavía no provoca motines.  La devastación baja sola con los meses y reduce lo que produce la provincia." % int(roundf(float(v["favorabilidad"]))))
		var pels: Array = v.get("pelotones", [])
		var sp := _seccion("Pelotones")
		if pels.is_empty():
			_nota(sp, "No hay pelotones en esta provincia.")
		for p in pels:
			var ext := "  · EXTRANJERO (%s)" % String(p[4]) if bool(p[5]) else "  · %s" % String(p[4])
			_fila(sp, "i_ejercito", "Pelotón %d" % int(p[6]), "%s soldados · exp. %d · fam. %d%s" % [fmt_num(float(p[1])), int(roundf(float(p[2]))), int(roundf(float(p[3]))), ext], "pel:%d" % int(p[0]))
		var mas2: int = int(v.get("pelotones_n", 0)) - pels.size()
		if mas2 > 0:
			_nota(sp, "y %d pelotones más…" % mas2)
	_nota(cuerpo, "Un pelotón es el grupo de hasta 1.000 soldados que calcula el juego. Cifras PROVISIONALES de %d (estimaciones por país); las reglas de experiencia, familiaridad y devastación se ajustarán jugando." % main.epoca)


# ───────────── panel de detalle ─────────────
func _det_titulo(ic: String, t: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.add_child(_icono_rect(ic, 40.0))
	var l := _lbl(t, 20, Tema.ORO, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	var cerrar := Button.new()
	cerrar.text = "✕"
	cerrar.flat = true
	cerrar.pressed.connect(func():
		panel_det.visible = false
		det_clave = "")
	hb.add_child(cerrar)
	det_box.add_child(hb)


func _det_banner(cod: String) -> void:
	var ban := TextureRect.new()
	ban.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ban.texture = main.icono("bioma_" + cod)
	ban.custom_minimum_size = Vector2(0, 96)
	ban.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ban.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	det_box.add_child(ban)


func _det_texto(bb: String) -> void:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", fuente)
	r.add_theme_font_override("bold_font", fuente_neg)
	r.add_theme_font_size_override("normal_font_size", 14)
	r.add_theme_color_override("default_color", Tema.TEXTO)
	r.text = bb
	det_box.add_child(r)


## Detalle económico armado por el mapa: {"icono", "titulo", "bb" (texto), "barras": [[nombre, 0-100], ...]}
func _detalle_fin(f: Dictionary) -> void:
	_det_titulo(String(f.get("icono", "i_eco")), String(f.get("titulo", "")))
	var barras: Array = f.get("barras", [])
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 4)
	det_box.add_child(caja)
	for i in barras.size():
		_barra(caja, String(barras[i][0]), float(barras[i][1]), C_BARRAS[i % C_BARRAS.size()], 120.0)
	_det_texto(String(f.get("bb", "")))
	_sin_foco(det_box)
	panel_det.visible = true
	panel_det.reset_size()
	_acomodar_det()


func _vs(parte: float, todo: float) -> float:
	if todo <= 0.0:
		return 0.0
	return 100.0 * parte / todo


func _detalle(k: String, forzar := false) -> void:
	if det_clave == k and panel_det.visible and not forzar:
		panel_det.visible = false
		det_clave = ""
		return
	det_clave = k
	_limpiar(det_box)
	var fin_det: Dictionary = datos.get("fin_det", {})
	if fin_det.has(k):
		_detalle_fin(fin_det[k])
		return
	if k.begins_with("pel:"):
		_detalle_fin(main.ejercito_detalle(int(k.substr(4))))
		return
	var d := _d()
	var padre: Dictionary = datos.get("padre", {})
	var padre_n := String(datos.get("padre_n", ""))
	var biomas: Dictionary = main.info.get("biomas", {})
	var bio: Array = d.get("bio", [])
	var reino := String(d.get("reino", "PAL"))
	var nombre_reino := String(main.info.get("reinos", {}).get(reino, reino))
	match k:
		"veg":
			_det_titulo("i_veg", "Vegetación")
			if bio.size() > 0:
				_det_banner(String(bio[0][0]))
			var i := 0
			for b in bio:
				var caja := VBoxContainer.new()
				det_box.add_child(caja)
				_barra(caja, String(biomas[b[0]]["n"]), float(b[1]), C_BARRAS[i % C_BARRAS.size()], 130.0)
				i += 1
			var t := ""
			for b in bio:
				t += "[color=#9fb4d6]%s:[/color] %s\n\n" % [biomas[b[0]]["n"], biomas[b[0]]["flora"]]
			_det_texto(t + "[color=#7f8fb0]Biomas según ecorregiones WWF, repartidos por superficie.[/color]")
		"flora":
			_det_titulo("i_flora", "Flora típica")
			if bio.size() > 0:
				_det_banner(String(bio[0][0]))
			var t2 := ""
			for b in bio:
				t2 += "[color=#9fb4d6]%s (%d%%)[/color]\n%s\n\n" % [biomas[b[0]]["n"], int(b[1]), biomas[b[0]]["flora"]]
			_det_texto(t2 + "[color=#7f8fb0]Especies representativas del bioma; aún no hay inventario por provincia.[/color]")
		"fauna":
			_det_titulo("i_fauna", "Fauna típica")
			if bio.size() > 0:
				_det_banner(String(bio[0][0]))
			var t3 := "[color=#9fb4d6]Reino biogeográfico:[/color] %s\n\n" % nombre_reino
			for b in bio:
				t3 += "[color=#9fb4d6]%s[/color]\n%s\n\n" % [biomas[b[0]]["n"], biomas[b[0]]["fauna"].get(reino, "")]
			_det_texto(t3 + "[color=#7f8fb0]Fauna representativa del bioma y el reino; aún no hay inventario por provincia.[/color]")
		"alt":
			_det_titulo("i_alt", "Altitud y relieve")
			var med := float(d["alt"])
			var mx := float(d["altmax"])
			var t4 := "[color=#9fb4d6]Altitud media:[/color] %s m\n[color=#9fb4d6]Punto más alto (aprox.):[/color] %s m\n[color=#9fb4d6]Relieve:[/color] %s\n" % [fmt_num(med), fmt_num(mx), cat_alt(med, mx)]
			if padre.has("alt"):
				t4 += "\n[color=#9fb4d6]Altitud media de %s:[/color] %s m\n" % [padre_n, fmt_num(float(padre["alt"]))]
			_det_texto(t4 + "\n[color=#7f8fb0]Datos ETOPO1 (~18 km) y picos de Natural Earth; los picos más altos pueden ser algo mayores.[/color]")
		"pob":
			_det_titulo("i_pob", "Población")
			var pob := float(d["pob"])
			var area := maxf(float(d["area"]), 1.0)
			_det_texto("[color=#9fb4d6]Población estimada %d:[/color] %s habitantes\n[color=#9fb4d6]Densidad:[/color] %s hab/km²" % [main.epoca, fmt_num(pob), fmt_num(pob / area)])
			if padre.has("pob"):
				_det_texto("[color=#9fb4d6]Peso en %s:[/color]" % padre_n)
				var caja2 := VBoxContainer.new()
				det_box.add_child(caja2)
				_barra(caja2, "Población", _vs(pob, float(padre["pob"])), C_BARRAS[0], 130.0)
			_det_texto("[color=#7f8fb0]%s[/color]" % ("Países: Banco Mundial (2025) proyectado a 2026. Subdivisiones: reparto según ciudades de Natural Earth (estimación)." if main.epoca == main.EPOCA_ACTUAL else "Estimación histórica: población repartida por la habitabilidad de cada región (cifras de referencia, no censos)."))
		"area":
			_det_titulo("i_area", "Superficie")
			var ar := float(d["area"])
			_det_texto("[color=#9fb4d6]Superficie:[/color] %s km²\n[color=#9fb4d6]Equivale a:[/color] %s veces España" % [fmt_num(ar), ("%.2f" % (ar / 506907.0)).replace(".", ",")])
			if padre.has("area"):
				_det_texto("[color=#9fb4d6]Peso en %s:[/color]" % padre_n)
				var caja3 := VBoxContainer.new()
				det_box.add_child(caja3)
				_barra(caja3, "Superficie", _vs(ar, float(padre["area"])), C_BARRAS[1], 130.0)
		"eco_prod":
			var ee: Dictionary = datos.get("eco", {})
			var pp2 := produccion_principal(ee)
			_det_titulo(_icono_producto(pp2), "Producción principal")
			var tx := "[color=#9fb4d6]Principal:[/color] %s\n" % String(pp2.get("nombre", "—"))
			if float(pp2.get("pct", 0.0)) > 0.0:
				tx += "[color=#9fb4d6]Rubro:[/color] %s (%s de los ingresos)\n\n%s\n" % [String(pp2.get("rubro", "")), pct(float(pp2["pct"])), _efecto(ee.get("rub", []))]
			tx += "\n[color=#7f8fb0]%s[/color]" % String(ee.get("nota", ""))
			_det_texto(tx)
		"mar":
			_det_titulo("i_prof", "Mar y profundidad")
			var m: Dictionary = datos.get("mar", {})
			var aqui := float(datos.get("aqui", 0))
			var t7 := ""
			if not m.is_empty():
				t7 += "[color=#9fb4d6]%s:[/color] %s\n[color=#9fb4d6]Superficie:[/color] %s km² (%s veces España)\n" % [m["t"], m["n"], fmt_num(float(m["a"])), ("%.1f" % (float(m["a"]) / 506907.0)).replace(".", ",")]
				t7 += "[color=#9fb4d6]Profundidad máxima:[/color] ≈ %s m (%s veces el Everest)\n[color=#9fb4d6]Profundidad media:[/color] ≈ %s m\n" % [fmt_num(float(m["pmax"])), ("%.1f" % (float(m["pmax"]) / 8849.0)).replace(".", ","), fmt_num(float(m["pmed"]))]
			t7 += "[color=#9fb4d6]Profundidad en el punto elegido:[/color] ≈ %s m\n\n[color=#7f8fb0]Batimetría de Natural Earth; valores aproximados.[/color]" % fmt_num(aqui)
			_det_texto(t7)
	_sin_foco(det_box)
	panel_det.visible = true
	panel_det.reset_size()
	_acomodar_det()


## Mientras la pestaña Diplomacia está abierta se pone al día sola cuando empieza o termina una guerra.
func _process(delta: float) -> void:
	if panel == null or not panel.visible or pestana != "diplomacia" or main == null or main.mundo == null:
		return
	_t_dip += delta
	if _t_dip < 0.5:
		return
	_t_dip = 0.0
	var g = main.mundo.guerra
	var ver: int = g.version if g != null else 0
	if ver != _ver_guerra:
		_ver_guerra = ver
		var y: int = scroll_cuerpo.scroll_vertical
		_dibujar()
		scroll_cuerpo.scroll_vertical = y
