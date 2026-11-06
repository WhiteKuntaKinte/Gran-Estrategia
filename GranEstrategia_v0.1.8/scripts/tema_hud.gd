extends RefCounted
## TEMA VISUAL DEL HUD (0.1.8) — un solo lugar para los colores, la fuente y los estilos de TODAS las ventanas y paneles.
## Azul acero, oscuro y apagado, con aspecto metálico: degradado vertical, esquinas cortadas y un filo claro arriba.
## Para cambiar el aspecto del juego entero basta con tocar las constantes de aquí (o `crear_tema`).
##
## Cómo se usa:
##   · `TemaHud.crear_tema(fuente, fuente_negrita)` devuelve un `Theme` con estilos para Button, PanelContainer, Label, OptionButton,
##     SpinBox/LineEdit, sliders, barras de scroll, separadores y tooltips. Se pone en el nodo raíz (Control) de cada ventana.
##   · `TemaHud.caja(...)` / `TemaHud.metal(...)` crean estilos sueltos cuando una pieza necesita uno propio.

# ── colores ──
const FONDO_ARRIBA := Color(0.112, 0.140, 0.180, 0.97)     # panel: parte alta del degradado
const FONDO_ABAJO := Color(0.060, 0.078, 0.104, 0.97)      # panel: parte baja
const CABECERA_ARRIBA := Color(0.200, 0.246, 0.310, 1.0)   # barras de título y botones: acero claro arriba...
const CABECERA_ABAJO := Color(0.118, 0.148, 0.195, 1.0)    # ...y acero oscuro abajo
const TARJETA := Color(0.092, 0.118, 0.155, 0.98)          # tarjetas de datos
const TARJETA_SOBRE := Color(0.140, 0.178, 0.230, 1.0)     # tarjeta con el ratón encima
const ACERO := Color(0.340, 0.420, 0.520)                  # bordes
const ACERO_CLARO := Color(0.600, 0.690, 0.800)            # filos y bordes resaltados
const ACERO_OSCURO := Color(0.150, 0.190, 0.250)
const SELECCION_ARRIBA := Color(0.300, 0.440, 0.600)       # pestaña / fila elegida
const SELECCION_ABAJO := Color(0.190, 0.300, 0.430)
const ORO := Color(0.910, 0.790, 0.430)                    # acento: títulos y lo elegido (más apagado que antes)
const TEXTO := Color(0.910, 0.935, 0.970)
const TENUE := Color(0.610, 0.680, 0.780)
const NOTA := Color(0.520, 0.600, 0.710)
const OK := Color(0.480, 0.900, 0.580)
const MAL := Color(1.0, 0.560, 0.460)
const BARRA_FONDO := Color(0.130, 0.165, 0.215)

const TAM_BASE := 14


## Estilo metálico: degradado vertical, esquinas cortadas (`corte` px), borde y un filo claro arriba. Opcional: línea de acento abajo.
class EstiloMetal extends StyleBox:
	var arriba := Color.WHITE
	var abajo := Color.BLACK
	var borde := Color.GRAY
	var filo := Color(1.0, 1.0, 1.0, 0.18)
	var corte := 4.0
	var grosor := 1.0
	var acento := Color(0.0, 0.0, 0.0, 0.0)      # línea gruesa en el borde de abajo (pestaña activa)

	func _draw(ci: RID, rect: Rect2) -> void:
		var r := rect.grow(-0.5)
		var c := minf(corte, minf(r.size.x, r.size.y) * 0.5)
		var x0 := r.position.x
		var y0 := r.position.y
		var x1 := r.end.x
		var y1 := r.end.y
		var pts := PackedVector2Array([Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1 - c),
			Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c), Vector2(x0, y0 + c)])
		var alto := maxf(r.size.y, 1.0)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(arriba.lerp(abajo, clampf((p.y - y0) / alto, 0.0, 1.0)))
		RenderingServer.canvas_item_add_polygon(ci, pts, cols)
		var cerrado := pts.duplicate()
		cerrado.append(pts[0])
		RenderingServer.canvas_item_add_polyline(ci, cerrado, PackedColorArray([borde]), grosor, true)
		if filo.a > 0.0 and r.size.x > 2.0 * c + 4.0:
			RenderingServer.canvas_item_add_line(ci, Vector2(x0 + c + 1.0, y0 + 1.5), Vector2(x1 - c - 1.0, y0 + 1.5), filo, 1.0, true)
		if acento.a > 0.0 and r.size.x > 2.0 * c + 4.0:
			RenderingServer.canvas_item_add_line(ci, Vector2(x0 + c, y1 - 1.0), Vector2(x1 - c, y1 - 1.0), acento, 2.0, true)

	func _get_draw_rect(rect: Rect2) -> Rect2:
		return rect


## Estilo metálico con márgenes interiores `margen` (px).
static func metal(arriba: Color, abajo: Color, borde: Color, margen := 6.0, corte := 4.0, filo := Color(1.0, 1.0, 1.0, 0.18), acento := Color(0.0, 0.0, 0.0, 0.0)) -> StyleBox:
	var e := EstiloMetal.new()
	e.arriba = arriba
	e.abajo = abajo
	e.borde = borde
	e.corte = corte
	e.filo = filo
	e.acento = acento
	e.content_margin_left = margen
	e.content_margin_right = margen
	e.content_margin_top = margen
	e.content_margin_bottom = margen
	return e


## Panel principal (ventanas y HUD).
static func panel(margen := 10.0) -> StyleBox:
	return metal(FONDO_ARRIBA, FONDO_ABAJO, ACERO, margen, 6.0, Color(0.75, 0.85, 1.0, 0.16))


## Barra de título / franja de sección.
static func cabecera(margen := 5.0) -> StyleBox:
	return metal(CABECERA_ARRIBA, CABECERA_ABAJO, ACERO, margen, 4.0, Color(0.85, 0.92, 1.0, 0.30))


## Botón: estado "normal", "sobre", "pulsado", "elegido" (pestaña activa) o "apagado".
static func boton(estado: String, margen := 6.0) -> StyleBox:
	match estado:
		"sobre":
			return metal(Color(0.255, 0.315, 0.395, 1.0), Color(0.160, 0.200, 0.262, 1.0), ACERO_CLARO, margen, 4.0, Color(0.9, 0.95, 1.0, 0.38))
		"pulsado":
			return metal(Color(0.130, 0.165, 0.215, 1.0), Color(0.190, 0.240, 0.305, 1.0), ACERO_CLARO, margen, 4.0, Color(0.0, 0.0, 0.0, 0.0))
		"elegido":
			return metal(SELECCION_ARRIBA, SELECCION_ABAJO, ACERO_CLARO, margen, 4.0, Color(0.95, 0.98, 1.0, 0.42), ORO)
		"apagado":
			return metal(Color(0.120, 0.148, 0.190, 0.8), Color(0.095, 0.118, 0.155, 0.8), Color(0.22, 0.27, 0.34), margen, 4.0, Color(1.0, 1.0, 1.0, 0.05))
	return metal(CABECERA_ARRIBA, CABECERA_ABAJO, ACERO, margen, 4.0, Color(0.85, 0.92, 1.0, 0.26))


## Tarjeta de datos (una fila de información). `sobre` = con el ratón encima.
static func tarjeta(sobre := false, margen := 6.0) -> StyleBox:
	if sobre:
		return metal(TARJETA_SOBRE, Color(0.110, 0.140, 0.185, 1.0), ORO, margen, 4.0, Color(0.9, 0.95, 1.0, 0.16))
	return metal(Color(0.112, 0.142, 0.184, 0.98), TARJETA, Color(0.215, 0.275, 0.355), margen, 4.0, Color(0.9, 0.95, 1.0, 0.07))


## Caja plana con esquinas redondeadas (para marcos de banderas, barras de progreso, etc.).
static func caja(col: Color, borde: Color, radio: int, margen: int, bw := 1) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = col
	e.border_color = borde
	e.set_border_width_all(bw)
	e.set_corner_radius_all(radio)
	e.content_margin_left = margen
	e.content_margin_right = margen
	e.content_margin_top = margen
	e.content_margin_bottom = margen
	return e


## Le da grosor a la pista de un deslizador (sin márgenes la pista medía 0 px y no se veía).
static func _pista(e: StyleBoxFlat) -> StyleBoxFlat:
	e.content_margin_top = 4
	e.content_margin_bottom = 4
	return e


static func _linea(col: Color, alto: int, margen := 0) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = col
	e.content_margin_top = alto
	e.content_margin_bottom = alto
	e.content_margin_left = margen
	e.content_margin_right = margen
	return e


## El Theme común: se asigna al Control raíz de cada ventana y todo lo de adentro lo hereda.
static func crear_tema(f: Font, f_negrita: Font = null) -> Theme:
	var t := Theme.new()
	t.default_font = f
	t.default_font_size = TAM_BASE
	# etiquetas
	t.set_color("font_color", "Label", TEXTO)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	# paneles
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	# botones
	for tipo in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", tipo, boton("normal"))
		t.set_stylebox("hover", tipo, boton("sobre"))
		t.set_stylebox("pressed", tipo, boton("elegido") if tipo == "Button" else boton("pulsado"))
		t.set_stylebox("hover_pressed", tipo, boton("elegido"))
		t.set_stylebox("disabled", tipo, boton("apagado"))
		t.set_stylebox("focus", tipo, StyleBoxEmpty.new())
		t.set_color("font_color", tipo, TEXTO)
		t.set_color("font_hover_color", tipo, Color(1.0, 1.0, 1.0))
		t.set_color("font_pressed_color", tipo, Color(1.0, 0.97, 0.85))
		t.set_color("font_hover_pressed_color", tipo, Color(1.0, 0.97, 0.85))
		t.set_color("font_focus_color", tipo, TEXTO)
		t.set_color("font_disabled_color", tipo, Color(0.50, 0.56, 0.65))
		t.set_color("icon_normal_color", tipo, Color(1, 1, 1))
		t.set_color("icon_disabled_color", tipo, Color(1, 1, 1, 0.45))
	t.set_stylebox("pressed_mirrored", "OptionButton", boton("pulsado"))
	t.set_stylebox("normal_mirrored", "OptionButton", boton("normal"))
	# casillas
	t.set_color("font_color", "CheckBox", TEXTO)
	t.set_color("font_hover_color", "CheckBox", Color(1, 1, 1))
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", TEXTO)
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	# campos de texto y numéricos
	for tipo2 in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", tipo2, caja(Color(0.050, 0.065, 0.090, 1.0), ACERO, 3, 5))
		t.set_stylebox("focus", tipo2, caja(Color(0.060, 0.078, 0.108, 1.0), ORO, 3, 5))
		t.set_stylebox("read_only", tipo2, caja(Color(0.070, 0.088, 0.115, 0.9), ACERO_OSCURO, 3, 5))
		t.set_color("font_color", tipo2, TEXTO)
		t.set_color("font_uneditable_color", tipo2, TENUE)
		t.set_color("caret_color", tipo2, ORO)
		t.set_color("selection_color", tipo2, Color(0.30, 0.44, 0.60, 0.7))
	# listas desplegables (OptionButton)
	t.set_stylebox("panel", "PopupMenu", metal(Color(0.095, 0.120, 0.158, 0.99), Color(0.070, 0.090, 0.120, 0.99), ACERO_CLARO, 4.0, 4.0))
	t.set_stylebox("hover", "PopupMenu", caja(Color(0.26, 0.38, 0.52, 1.0), Color(0, 0, 0, 0), 3, 3, 0))
	t.set_color("font_color", "PopupMenu", TEXTO)
	t.set_color("font_hover_color", "PopupMenu", Color(1, 1, 1))
	# barras y deslizadores
	t.set_stylebox("slider", "HSlider", _pista(caja(Color(0.050, 0.065, 0.090, 1.0), ACERO_OSCURO, 3, 0)))
	t.set_stylebox("grabber_area", "HSlider", _pista(caja(Color(0.32, 0.46, 0.62, 1.0), Color(0, 0, 0, 0), 3, 0, 0)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _pista(caja(Color(0.42, 0.58, 0.76, 1.0), Color(0, 0, 0, 0), 3, 0, 0)))
	t.set_constant("center_grabber", "HSlider", 0)
	for sc in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sc, caja(Color(0.04, 0.05, 0.08, 0.7), Color(0, 0, 0, 0), 4, 0, 0))
		t.set_stylebox("grabber", sc, caja(Color(0.34, 0.42, 0.52, 0.95), Color(0, 0, 0, 0), 4, 0, 0))
		t.set_stylebox("grabber_highlight", sc, caja(Color(0.50, 0.60, 0.72, 1.0), Color(0, 0, 0, 0), 4, 0, 0))
		t.set_stylebox("grabber_pressed", sc, caja(Color(0.62, 0.72, 0.84, 1.0), Color(0, 0, 0, 0), 4, 0, 0))
	# separadores
	t.set_stylebox("separator", "HSeparator", _linea(Color(0.30, 0.38, 0.48, 0.65), 0))
	t.set_constant("separation", "HSeparator", 6)
	t.set_stylebox("separator", "VSeparator", _linea(Color(0.30, 0.38, 0.48, 0.65), 0))
	# ayudas emergentes
	t.set_stylebox("panel", "TooltipPanel", metal(Color(0.075, 0.095, 0.128, 0.98), Color(0.055, 0.072, 0.098, 0.98), ACERO_CLARO, 6.0, 3.0))
	t.set_color("font_color", "TooltipLabel", TEXTO)
	# texto enriquecido
	t.set_color("default_color", "RichTextLabel", TEXTO)
	return t
