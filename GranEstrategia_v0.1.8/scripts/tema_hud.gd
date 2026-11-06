extends RefCounted
## TEMA VISUAL DEL HUD (0.1.8.37) — un solo lugar para los colores, la fuente y los estilos de TODAS las ventanas y paneles.
## Desde la 0.1.8.37 hay TRES temas intercambiables (Opciones > Pantalla > Interfaz), con cambio en vivo y guardado en ajustes.cfg:
##   0 · Cartográfico   pergamino, tinta y rojo sello; botones crema con borde de tinta, barras de título pardo oscuro (es el de por defecto)
##   1 · Moderno oscuro azul-negro plano con acento dorado
##   2 · Mixto          marrón oscuro con bordes de bronce y acento dorado
## Los colores son `static var` (no `const`): `TemaHud.aplicar(id)` los cambia todos de golpe y luego cada pantalla se vuelve a pintar
## (`Hud.aplicar_tema`, los menús de MapaPrincipal...). Un script que quiera un color lo lee SIEMPRE en el momento de usarlo (`Tema.ORO`), nunca en un `const`.
##
## Cómo se usa:
##   · `TemaHud.crear_tema(fuente, fuente_negrita)` devuelve un `Theme` con estilos para Button, PanelContainer, Label, OptionButton,
##     SpinBox/LineEdit, sliders, barras de scroll, separadores y tooltips. Se pone en el nodo raíz (Control) de cada ventana.
##   · `TemaHud.caja(...)` / `TemaHud.metal(...)` crean estilos sueltos cuando una pieza necesita uno propio.
##   · Qué color es cada uno: TEXTO/TENUE/NOTA/ORO/OK/MAL/NARANJA se leen sobre el FONDO del panel; TITULO/TITULO_TENUE sobre las barras de título (CABECERA).

const NOMBRES := ["Cartográfico", "Moderno oscuro", "Mixto"]
const DESCRIPCIONES := ["Pergamino, tinta y rojo sello: el de siempre del mapa antiguo.", "Azul-negro plano con acento dorado: limpio y moderno.",
	"Marrón oscuro con bordes de bronce y acento dorado: mezcla de los dos."]
const TAM_BASE := 14

## Las tres paletas. Colores en hexadecimal RRGGBB o RRGGBBAA. `corte` = tamaño de las esquinas cortadas; `doble` = segundo filete de borde por dentro.
const PALETAS := [
	{	# 0 · Cartográfico
		"fondo_arriba": "EADDC1FA", "fondo_abajo": "E1D2AEFA", "cabecera_arriba": "4B3620", "cabecera_abajo": "3A2815",
		"titulo": "F2E6C6", "titulo_tenue": "D2BF97",
		"btn_arriba": "F8EDD3", "btn_abajo": "E8D9B4", "btn_sobre_arriba": "FFF7E0", "btn_sobre_abajo": "F1E3BF",
		"btn_pulsado_arriba": "D9C8A1", "btn_pulsado_abajo": "E3D3AB",
		"tarjeta_arriba": "E3D3AEFA", "tarjeta": "D9C8A1FA", "tarjeta_sobre": "EADBB7",
		"bloque": "D9C8A1E8", "bloque_suave": "D9C8A18C", "campo": "F6ECD2", "campo_foco": "FFF8E2",
		"acero": "3A2815", "acero_claro": "2A1B0F", "acero_oscuro": "8A7352",
		"seleccion_arriba": "9A3326", "seleccion_abajo": "7E261A", "texto_sel": "F8EDD3", "acento_sel": "E8C976",
		"oro": "8E2C1F", "texto": "2A1B0F", "tenue": "5B4630", "nota": "6B5538", "ok": "2F6B2A", "mal": "9B2418", "naranja": "A5521A",
		"barra_fondo": "BFAE86", "barra_arriba": "DDCCA3", "barra_abajo": "D2BF92", "barra_acento": "00000000",
		"texto_apagado": "8C7B5E", "popup_arriba": "F3E8CB", "popup_abajo": "E9DCB9", "popup_sobre": "CDB98E",
		"tooltip_arriba": "F8EDD3", "tooltip_abajo": "EADDBC", "scroll_fondo": "CDBB93B3", "scroll_agarre": "8A7352",
		"separador": "8A7352A6", "filo": "FFFFFF4D", "panel_acento": "00000000", "corte": 3, "doble": true},
	{	# 1 · Moderno oscuro
		"fondo_arriba": "161B24F7", "fondo_abajo": "11151CF7", "cabecera_arriba": "1F2733", "cabecera_abajo": "181F29",
		"titulo": "D8AE45", "titulo_tenue": "A5ABB5",
		"btn_arriba": "262F3D", "btn_abajo": "1D242F", "btn_sobre_arriba": "313C4E", "btn_sobre_abajo": "262F3D",
		"btn_pulsado_arriba": "141A22", "btn_pulsado_abajo": "1B222C",
		"tarjeta_arriba": "202936FA", "tarjeta": "1B222DFA", "tarjeta_sobre": "283242",
		"bloque": "0D1118DB", "bloque_suave": "0D111880", "campo": "0C1016", "campo_foco": "10151D",
		"acero": "2F3947", "acero_claro": "D8AE45", "acero_oscuro": "232B38",
		"seleccion_arriba": "D8AE45", "seleccion_abajo": "BF9636", "texto_sel": "10141B", "acento_sel": "00000000",
		"oro": "D8AE45", "texto": "E8E6E1", "tenue": "A5ABB5", "nota": "8A919C", "ok": "6FCF8B", "mal": "FF8B7A", "naranja": "FFB566",
		"barra_fondo": "232B38", "barra_arriba": "12171F", "barra_abajo": "0D1117", "barra_acento": "D8AE45",
		"texto_apagado": "5C6471", "popup_arriba": "1A212B", "popup_abajo": "141A22", "popup_sobre": "34425A",
		"tooltip_arriba": "141A22", "tooltip_abajo": "0F141B", "scroll_fondo": "0A0D12B3", "scroll_agarre": "3A4658",
		"separador": "3A4658A6", "filo": "FFFFFF14", "panel_acento": "D8AE45", "corte": 2, "doble": false},
	{	# 2 · Mixto
		"fondo_arriba": "2C241CFA", "fondo_abajo": "221C17FA", "cabecera_arriba": "3D3126", "cabecera_abajo": "2E261F",
		"titulo": "E2B558", "titulo_tenue": "B8AA8A",
		"btn_arriba": "3E3226", "btn_abajo": "30281F", "btn_sobre_arriba": "4E4030", "btn_sobre_abajo": "3E3226",
		"btn_pulsado_arriba": "261F19", "btn_pulsado_abajo": "2F271F",
		"tarjeta_arriba": "382E24FA", "tarjeta": "30271EFA", "tarjeta_sobre": "443829",
		"bloque": "1A1511DB", "bloque_suave": "1A151180", "campo": "17120F", "campo_foco": "1E1814",
		"acero": "B98B3A", "acero_claro": "E2B558", "acero_oscuro": "5A4528",
		"seleccion_arriba": "E2B558", "seleccion_abajo": "C49A40", "texto_sel": "221C17", "acento_sel": "00000000",
		"oro": "E2B558", "texto": "EADFC6", "tenue": "B8AA8A", "nota": "9C8F72", "ok": "86D08A", "mal": "FF8D78", "naranja": "FFB566",
		"barra_fondo": "3A2F24", "barra_arriba": "2B231C", "barra_abajo": "211B16", "barra_acento": "E2B558",
		"texto_apagado": "6E6350", "popup_arriba": "2F271F", "popup_abajo": "251F19", "popup_sobre": "5A4528",
		"tooltip_arriba": "2B231C", "tooltip_abajo": "211B16", "scroll_fondo": "120E0BB3", "scroll_agarre": "6E5A3A",
		"separador": "7A6240A6", "filo": "FFF0C833", "panel_acento": "00000000", "corte": 4, "doble": false},
]

# ── colores y forma del tema vigente (arranca con el 0; `aplicar(id)` los cambia) ──
static var ID := 0
static var FONDO_ARRIBA := Color.WHITE        # panel: parte alta del degradado
static var FONDO_ABAJO := Color.WHITE         # panel: parte baja
static var CABECERA_ARRIBA := Color.WHITE     # barras de título
static var CABECERA_ABAJO := Color.WHITE
static var TITULO := Color.WHITE              # texto sobre las barras de título
static var TITULO_TENUE := Color.WHITE
static var BTN_ARRIBA := Color.WHITE          # botones
static var BTN_ABAJO := Color.WHITE
static var BTN_SOBRE_ARRIBA := Color.WHITE
static var BTN_SOBRE_ABAJO := Color.WHITE
static var BTN_PULSADO_ARRIBA := Color.WHITE
static var BTN_PULSADO_ABAJO := Color.WHITE
static var TARJETA_ARRIBA := Color.WHITE      # tarjetas de datos
static var TARJETA := Color.WHITE
static var TARJETA_SOBRE := Color.WHITE
static var BLOQUE := Color.WHITE              # subsecciones dentro de un panel (fila de pestañas, sección abierta)
static var BLOQUE_SUAVE := Color.WHITE
static var CAMPO := Color.WHITE               # campos de texto y numéricos
static var CAMPO_FOCO := Color.WHITE
static var ACERO := Color.WHITE               # bordes
static var ACERO_CLARO := Color.WHITE         # bordes resaltados
static var ACERO_OSCURO := Color.WHITE        # filetes y bordes suaves
static var SELECCION_ARRIBA := Color.WHITE    # pestaña / botón elegido
static var SELECCION_ABAJO := Color.WHITE
static var TEXTO_SEL := Color.WHITE           # texto sobre lo elegido
static var ACENTO_SEL := Color.WHITE          # línea bajo lo elegido (transparente = sin línea)
static var ORO := Color.WHITE                 # acento: títulos de sección y lo importante
static var TEXTO := Color.WHITE
static var TENUE := Color.WHITE
static var NOTA := Color.WHITE
static var OK := Color.WHITE
static var MAL := Color.WHITE
static var NARANJA := Color.WHITE
static var BARRA_FONDO := Color.WHITE         # fondo de las barras de progreso
static var BARRA_ARRIBA := Color.WHITE        # barra superior de la pantalla
static var BARRA_ABAJO := Color.WHITE
static var BARRA_ACENTO := Color.WHITE        # línea bajo la barra superior (transparente = sin línea)
static var TEXTO_APAGADO := Color.WHITE
static var POPUP_ARRIBA := Color.WHITE        # listas desplegables y menús
static var POPUP_ABAJO := Color.WHITE
static var POPUP_SOBRE := Color.WHITE
static var TOOLTIP_ARRIBA := Color.WHITE
static var TOOLTIP_ABAJO := Color.WHITE
static var SCROLL_FONDO := Color.WHITE
static var SCROLL_AGARRE := Color.WHITE
static var SEPARADOR := Color.WHITE
static var FILO := Color.WHITE                # destello claro del borde de arriba
static var PANEL_ACENTO := Color.WHITE        # línea de acento arriba de las ventanas (transparente = sin línea)
static var CORTE := 3.0                       # esquinas cortadas (px)
static var DOBLE := false                     # segundo filete de borde por dentro


## Se ejecuta una sola vez al cargar el script: deja puesto el tema 0, así ningún color queda en blanco aunque nadie llame a `aplicar` todavía.
static func _static_init() -> void:
	aplicar(0)


## Pone en marcha el tema `id` (0..2; otro valor = 0). Después hay que volver a pintar lo que ya estaba en pantalla.
static func aplicar(id: int) -> void:
	ID = id if id >= 0 and id < PALETAS.size() else 0
	var p: Dictionary = PALETAS[ID]
	FONDO_ARRIBA = Color.html(p["fondo_arriba"])
	FONDO_ABAJO = Color.html(p["fondo_abajo"])
	CABECERA_ARRIBA = Color.html(p["cabecera_arriba"])
	CABECERA_ABAJO = Color.html(p["cabecera_abajo"])
	TITULO = Color.html(p["titulo"])
	TITULO_TENUE = Color.html(p["titulo_tenue"])
	BTN_ARRIBA = Color.html(p["btn_arriba"])
	BTN_ABAJO = Color.html(p["btn_abajo"])
	BTN_SOBRE_ARRIBA = Color.html(p["btn_sobre_arriba"])
	BTN_SOBRE_ABAJO = Color.html(p["btn_sobre_abajo"])
	BTN_PULSADO_ARRIBA = Color.html(p["btn_pulsado_arriba"])
	BTN_PULSADO_ABAJO = Color.html(p["btn_pulsado_abajo"])
	TARJETA_ARRIBA = Color.html(p["tarjeta_arriba"])
	TARJETA = Color.html(p["tarjeta"])
	TARJETA_SOBRE = Color.html(p["tarjeta_sobre"])
	BLOQUE = Color.html(p["bloque"])
	BLOQUE_SUAVE = Color.html(p["bloque_suave"])
	CAMPO = Color.html(p["campo"])
	CAMPO_FOCO = Color.html(p["campo_foco"])
	ACERO = Color.html(p["acero"])
	ACERO_CLARO = Color.html(p["acero_claro"])
	ACERO_OSCURO = Color.html(p["acero_oscuro"])
	SELECCION_ARRIBA = Color.html(p["seleccion_arriba"])
	SELECCION_ABAJO = Color.html(p["seleccion_abajo"])
	TEXTO_SEL = Color.html(p["texto_sel"])
	ACENTO_SEL = Color.html(p["acento_sel"])
	ORO = Color.html(p["oro"])
	TEXTO = Color.html(p["texto"])
	TENUE = Color.html(p["tenue"])
	NOTA = Color.html(p["nota"])
	OK = Color.html(p["ok"])
	MAL = Color.html(p["mal"])
	NARANJA = Color.html(p["naranja"])
	BARRA_FONDO = Color.html(p["barra_fondo"])
	BARRA_ARRIBA = Color.html(p["barra_arriba"])
	BARRA_ABAJO = Color.html(p["barra_abajo"])
	BARRA_ACENTO = Color.html(p["barra_acento"])
	TEXTO_APAGADO = Color.html(p["texto_apagado"])
	POPUP_ARRIBA = Color.html(p["popup_arriba"])
	POPUP_ABAJO = Color.html(p["popup_abajo"])
	POPUP_SOBRE = Color.html(p["popup_sobre"])
	TOOLTIP_ARRIBA = Color.html(p["tooltip_arriba"])
	TOOLTIP_ABAJO = Color.html(p["tooltip_abajo"])
	SCROLL_FONDO = Color.html(p["scroll_fondo"])
	SCROLL_AGARRE = Color.html(p["scroll_agarre"])
	SEPARADOR = Color.html(p["separador"])
	FILO = Color.html(p["filo"])
	PANEL_ACENTO = Color.html(p["panel_acento"])
	CORTE = float(p["corte"])
	DOBLE = bool(p["doble"])


## Color del tema para un «rol» de texto: "oro", "tenue", "nota", "ok", "mal", "naranja", "titulo", "titulo_tenue" (cualquier otro = "texto").
static func color_rol(rol: String) -> Color:
	match rol:
		"oro":
			return ORO
		"tenue":
			return TENUE
		"nota":
			return NOTA
		"ok":
			return OK
		"mal":
			return MAL
		"naranja":
			return NARANJA
		"titulo":
			return TITULO
		"titulo_tenue":
			return TITULO_TENUE
	return TEXTO


## Un texto que debe cambiar de color con el tema: se pinta ya y se anota el rol en el nodo (`repintar_roles` lo vuelve a pintar).
static func rotular(l: Label, rol: String) -> void:
	l.set_meta("rol", rol)
	l.add_theme_color_override("font_color", color_rol(rol))


## Repinta con el tema vigente todos los Label con rol (ver `rotular`) que cuelgan de `n`.
static func repintar_roles(n: Node) -> void:
	if n is Label and n.has_meta("rol"):
		(n as Label).add_theme_color_override("font_color", color_rol(String(n.get_meta("rol"))))
	for h in n.get_children():
		repintar_roles(h)


## Estilo metálico: degradado vertical, esquinas cortadas (`corte` px), borde y un filo claro arriba. Opcional: línea de acento abajo
## (pestaña activa), línea de acento arriba (ventanas del tema oscuro) y segundo filete por dentro (tema cartográfico).
class EstiloMetal extends StyleBox:
	var arriba := Color.WHITE
	var abajo := Color.BLACK
	var borde := Color.GRAY
	var filo := Color(1.0, 1.0, 1.0, 0.18)
	var corte := 4.0
	var grosor := 1.0
	var acento := Color(0.0, 0.0, 0.0, 0.0)      # línea gruesa en el borde de abajo (pestaña activa)
	var acento_arriba := Color(0.0, 0.0, 0.0, 0.0)   # línea gruesa en el borde de arriba
	var filete := Color(0.0, 0.0, 0.0, 0.0)      # segundo borde fino, 3 px por dentro del primero (alfa 0 = sin filete)

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
		if filete.a > 0.0 and r.size.x > 14.0 and r.size.y > 14.0:
			var i := r.grow(-3.5)
			var ci2 := maxf(c - 2.0, 0.0)
			var pi := PackedVector2Array([Vector2(i.position.x + ci2, i.position.y), Vector2(i.end.x - ci2, i.position.y), Vector2(i.end.x, i.position.y + ci2),
				Vector2(i.end.x, i.end.y - ci2), Vector2(i.end.x - ci2, i.end.y), Vector2(i.position.x + ci2, i.end.y), Vector2(i.position.x, i.end.y - ci2),
				Vector2(i.position.x, i.position.y + ci2), Vector2(i.position.x + ci2, i.position.y)])
			RenderingServer.canvas_item_add_polyline(ci, pi, PackedColorArray([filete]), 1.0, true)
		if filo.a > 0.0 and r.size.x > 2.0 * c + 4.0:
			RenderingServer.canvas_item_add_line(ci, Vector2(x0 + c + 1.0, y0 + 1.5), Vector2(x1 - c - 1.0, y0 + 1.5), filo, 1.0, true)
		if acento.a > 0.0 and r.size.x > 2.0 * c + 4.0:
			RenderingServer.canvas_item_add_line(ci, Vector2(x0 + c, y1 - 1.0), Vector2(x1 - c, y1 - 1.0), acento, 2.0, true)
		if acento_arriba.a > 0.0 and r.size.x > 2.0 * c + 4.0:
			RenderingServer.canvas_item_add_line(ci, Vector2(x0 + c, y0 + 1.0), Vector2(x1 - c, y0 + 1.0), acento_arriba, 2.0, true)

	func _get_draw_rect(rect: Rect2) -> Rect2:
		return rect


## Estilo metálico con márgenes interiores `margen` (px). `corte` < 0 = el del tema vigente.
static func metal(arriba: Color, abajo: Color, borde: Color, margen := 6.0, corte := -1.0, filo := Color(1.0, 1.0, 1.0, 0.18), acento := Color(0.0, 0.0, 0.0, 0.0),
		acento_arriba := Color(0.0, 0.0, 0.0, 0.0), filete := Color(0.0, 0.0, 0.0, 0.0)) -> StyleBox:
	var e := EstiloMetal.new()
	e.arriba = arriba
	e.abajo = abajo
	e.borde = borde
	e.corte = CORTE if corte < 0.0 else corte
	e.filo = filo
	e.acento = acento
	e.acento_arriba = acento_arriba
	e.filete = filete
	e.content_margin_left = margen
	e.content_margin_right = margen
	e.content_margin_top = margen
	e.content_margin_bottom = margen
	return e


## Panel principal (ventanas y HUD).
static func panel(margen := 10.0) -> StyleBox:
	return metal(FONDO_ARRIBA, FONDO_ABAJO, ACERO, margen, CORTE + 2.0, FILO, Color(0.0, 0.0, 0.0, 0.0), PANEL_ACENTO, ACERO_OSCURO if DOBLE else Color(0.0, 0.0, 0.0, 0.0))


## Barra de título / franja de sección.
static func cabecera(margen := 5.0) -> StyleBox:
	return metal(CABECERA_ARRIBA, CABECERA_ABAJO, ACERO if ID != 0 else ACERO_CLARO, margen, CORTE, FILO)


## La barra superior de la pantalla (pegada al borde de arriba): sin esquinas cortadas por arriba y con su línea de acento.
static func barra(margen := 5.0) -> StyleBox:
	return metal(BARRA_ARRIBA, BARRA_ABAJO, ACERO, margen, CORTE, FILO, BARRA_ACENTO)


## Botón: estado "normal", "sobre", "pulsado", "elegido" (pestaña activa) o "apagado".
static func boton(estado: String, margen := 6.0) -> StyleBox:
	match estado:
		"sobre":
			return metal(BTN_SOBRE_ARRIBA, BTN_SOBRE_ABAJO, ACERO_CLARO, margen, CORTE, FILO)
		"pulsado":
			return metal(BTN_PULSADO_ARRIBA, BTN_PULSADO_ABAJO, ACERO_CLARO, margen, CORTE, Color(0.0, 0.0, 0.0, 0.0))
		"elegido":
			return metal(SELECCION_ARRIBA, SELECCION_ABAJO, ACERO_CLARO, margen, CORTE, FILO, ACENTO_SEL)
		"apagado":
			return metal(BTN_ABAJO.lerp(FONDO_ABAJO, 0.55), BTN_ABAJO.lerp(FONDO_ABAJO, 0.7), ACERO_OSCURO, margen, CORTE, Color(0.0, 0.0, 0.0, 0.0))
	return metal(BTN_ARRIBA, BTN_ABAJO, ACERO, margen, CORTE, FILO)


## Tarjeta de datos (una fila de información). `sobre` = con el ratón encima.
static func tarjeta(sobre := false, margen := 6.0) -> StyleBox:
	if sobre:
		return metal(TARJETA_SOBRE, TARJETA_SOBRE.darkened(0.08), ORO, margen, CORTE, FILO)
	return metal(TARJETA_ARRIBA, TARJETA, ACERO_OSCURO, margen, CORTE, Color(FILO.r, FILO.g, FILO.b, FILO.a * 0.5))


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


## Marco de una bandera (borde fino del color del tema).
static func marco_bandera(radio := 3, margen := 2) -> StyleBoxFlat:
	return caja(Color(0, 0, 0, 0.5), ACERO_CLARO if ID == 0 else Color(0.82, 0.88, 0.96, 0.85), radio, margen, 1)


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
	var sin := Color(0, 0, 0, 0)
	var hover_txt := TEXTO.lerp(Color.WHITE if ID != 0 else Color.BLACK, 0.6)
	# etiquetas
	t.set_color("font_color", "Label", TEXTO)
	t.set_color("font_shadow_color", "Label", sin)
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
		t.set_color("font_hover_color", tipo, hover_txt)
		t.set_color("font_pressed_color", tipo, TEXTO_SEL if tipo == "Button" else TEXTO)
		t.set_color("font_hover_pressed_color", tipo, TEXTO_SEL)
		t.set_color("font_focus_color", tipo, TEXTO)
		t.set_color("font_disabled_color", tipo, TEXTO_APAGADO)
		t.set_color("icon_normal_color", tipo, Color(1, 1, 1))
		t.set_color("icon_disabled_color", tipo, Color(1, 1, 1, 0.45))
	t.set_stylebox("pressed_mirrored", "OptionButton", boton("pulsado"))
	t.set_stylebox("normal_mirrored", "OptionButton", boton("normal"))
	# casillas
	t.set_color("font_color", "CheckBox", TEXTO)
	t.set_color("font_hover_color", "CheckBox", hover_txt)
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckButton", TEXTO)
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	# campos de texto y numéricos
	for tipo2 in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", tipo2, caja(CAMPO, ACERO, 3, 5))
		t.set_stylebox("focus", tipo2, caja(CAMPO_FOCO, ORO, 3, 5))
		t.set_stylebox("read_only", tipo2, caja(CAMPO.lerp(FONDO_ABAJO, 0.5), ACERO_OSCURO, 3, 5))
		t.set_color("font_color", tipo2, TEXTO)
		t.set_color("font_uneditable_color", tipo2, TENUE)
		t.set_color("caret_color", tipo2, ORO)
		t.set_color("selection_color", tipo2, Color(ORO.r, ORO.g, ORO.b, 0.35))
	# listas desplegables (OptionButton)
	t.set_stylebox("panel", "PopupMenu", metal(POPUP_ARRIBA, POPUP_ABAJO, ACERO_CLARO, 4.0, 4.0, FILO))
	t.set_stylebox("hover", "PopupMenu", caja(POPUP_SOBRE, sin, 3, 3, 0))
	t.set_color("font_color", "PopupMenu", TEXTO)
	t.set_color("font_hover_color", "PopupMenu", hover_txt)
	# barras y deslizadores
	t.set_stylebox("slider", "HSlider", _pista(caja(CAMPO, ACERO_OSCURO, 3, 0)))
	t.set_stylebox("grabber_area", "HSlider", _pista(caja(SELECCION_ABAJO, sin, 3, 0, 0)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _pista(caja(SELECCION_ARRIBA, sin, 3, 0, 0)))
	t.set_constant("center_grabber", "HSlider", 0)
	for sc in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sc, caja(SCROLL_FONDO, sin, 4, 0, 0))
		t.set_stylebox("grabber", sc, caja(SCROLL_AGARRE, sin, 4, 0, 0))
		t.set_stylebox("grabber_highlight", sc, caja(SCROLL_AGARRE.lightened(0.18), sin, 4, 0, 0))
		t.set_stylebox("grabber_pressed", sc, caja(SCROLL_AGARRE.lightened(0.32), sin, 4, 0, 0))
	# separadores
	t.set_stylebox("separator", "HSeparator", _linea(SEPARADOR, 0))
	t.set_constant("separation", "HSeparator", 6)
	t.set_stylebox("separator", "VSeparator", _linea(SEPARADOR, 0))
	# ayudas emergentes
	t.set_stylebox("panel", "TooltipPanel", metal(TOOLTIP_ARRIBA, TOOLTIP_ABAJO, ACERO_CLARO, 6.0, 3.0, FILO))
	t.set_color("font_color", "TooltipLabel", TEXTO)
	# texto enriquecido
	t.set_color("default_color", "RichTextLabel", TEXTO)
	return t
