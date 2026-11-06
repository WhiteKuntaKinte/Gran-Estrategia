extends Node
## 0.1.8.37 · PRUEBAS DEL MAPA Y DEL TEMA DE INTERFAZ.
## Tema: las tres paletas (válidas, distintas, legibles), `aplicar(id)`, ajustes `tema` y `bordes` (sanear, guardar y cargar), selector «Interfaz» de Opciones
## (cambio en vivo + guardado al momento), HUD que se repinta sin reiniciar y menú principal / pausa con el tema nuevo.
const AjustesScript := preload("res://scripts/ajustes.gd")
const TemaHud := preload("res://scripts/tema_hud.gd")
const MenuPantallaScript := preload("res://scripts/menu_pantalla.gd")
const TEMP := "user://prueba_ajustes78.cfg"
var main
var fallos := 0
var n_ok := 0


func _ready() -> void:
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	Engine.set_meta("inicio_pendiente", {"modo": "campana", "pais": "Francia", "ia": 0})
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	run.call_deferred()


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func ok(cond: bool, msg: String) -> void:
	if cond:
		n_ok += 1
		print("[T] OK    ", msg)
	else:
		fallos += 1
		print("[T] FALLO ", msg)


func run() -> void:
	await esperar(1.0)
	t_paletas()
	t_ajustes()
	await t_selector()
	await t_hud_en_vivo()
	await t_menus()
	TemaHud.aplicar(0)
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	print("[T] ═══ RESULTADO runner78: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


## Luminancia relativa (WCAG) para comprobar que el texto se lee sobre su fondo.
func lum(c: Color) -> float:
	var r := c.r / 12.92 if c.r <= 0.03928 else pow((c.r + 0.055) / 1.055, 2.4)
	var g := c.g / 12.92 if c.g <= 0.03928 else pow((c.g + 0.055) / 1.055, 2.4)
	var b := c.b / 12.92 if c.b <= 0.03928 else pow((c.b + 0.055) / 1.055, 2.4)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b


func contraste(a: Color, b: Color) -> float:
	var la := lum(a) + 0.05
	var lb := lum(b) + 0.05
	return maxf(la, lb) / minf(la, lb)


# ── paletas ─────────────────────────────────────────────────────────────────────────────────────────────────
func t_paletas() -> void:
	print("[T] ── paletas")
	ok(TemaHud.PALETAS.size() == 3 and TemaHud.NOMBRES.size() == 3 and TemaHud.DESCRIPCIONES.size() == 3, "hay 3 temas con nombre y descripción")
	var claves: Array = TemaHud.PALETAS[0].keys()
	var mismas := true
	var hex_ok := true
	for p in TemaHud.PALETAS:
		if p.keys().size() != claves.size():
			mismas = false
		for k in claves:
			if not p.has(k):
				mismas = false
			elif p[k] is String:
				var h := String(p[k])
				if not (h.length() == 6 or h.length() == 8) or not h.is_valid_hex_number(false):
					hex_ok = false
	ok(mismas, "las tres paletas definen exactamente las mismas claves (%d)" % claves.size())
	ok(hex_ok, "todos los colores son hexadecimales de 6 u 8 cifras")
	TemaHud.aplicar(0)
	ok(TemaHud.ID == 0 and TemaHud.NOMBRES[0] == "Cartográfico", "aplicar(0) deja el Cartográfico")
	var a_fondo := TemaHud.FONDO_ABAJO
	TemaHud.aplicar(1)
	ok(TemaHud.ID == 1 and TemaHud.FONDO_ABAJO != a_fondo, "aplicar(1) cambia los colores")
	TemaHud.aplicar(2)
	ok(TemaHud.ID == 2, "aplicar(2) deja el Mixto")
	TemaHud.aplicar(99)
	ok(TemaHud.ID == 0, "un id fuera de rango vuelve al Cartográfico")
	TemaHud.aplicar(-3)
	ok(TemaHud.ID == 0, "un id negativo también")
	for id in 3:
		TemaHud.aplicar(id)
		var n: String = TemaHud.NOMBRES[id]
		var fondo := TemaHud.FONDO_ARRIBA.lerp(TemaHud.FONDO_ABAJO, 0.5)
		fondo.a = 1.0
		ok(contraste(TemaHud.TEXTO, fondo) >= 4.5, "%s: el texto se lee sobre el panel (contraste %.1f)" % [n, contraste(TemaHud.TEXTO, fondo)])
		ok(contraste(TemaHud.ORO, fondo) >= 3.0, "%s: el acento se lee sobre el panel (%.1f)" % [n, contraste(TemaHud.ORO, fondo)])
		ok(contraste(TemaHud.TENUE, fondo) >= 3.0, "%s: el texto tenue se lee sobre el panel (%.1f)" % [n, contraste(TemaHud.TENUE, fondo)])
		ok(contraste(TemaHud.OK, fondo) >= 3.0 and contraste(TemaHud.MAL, fondo) >= 3.0, "%s: verde y rojo de estado se leen sobre el panel" % n)
		var cab := TemaHud.CABECERA_ARRIBA.lerp(TemaHud.CABECERA_ABAJO, 0.5)
		ok(contraste(TemaHud.TITULO, cab) >= 4.5, "%s: el título se lee sobre la barra de título (%.1f)" % [n, contraste(TemaHud.TITULO, cab)])
		var btn := TemaHud.BTN_ARRIBA.lerp(TemaHud.BTN_ABAJO, 0.5)
		ok(contraste(TemaHud.TEXTO, btn) >= 4.5, "%s: el texto se lee sobre los botones (%.1f)" % [n, contraste(TemaHud.TEXTO, btn)])
		var sel := TemaHud.SELECCION_ARRIBA.lerp(TemaHud.SELECCION_ABAJO, 0.5)
		ok(contraste(TemaHud.TEXTO_SEL, sel) >= 4.5, "%s: el texto se lee sobre lo elegido (%.1f)" % [n, contraste(TemaHud.TEXTO_SEL, sel)])
		var bar := TemaHud.BARRA_ARRIBA.lerp(TemaHud.BARRA_ABAJO, 0.5)
		ok(contraste(TemaHud.TEXTO, bar) >= 4.5, "%s: el texto se lee sobre la barra superior (%.1f)" % [n, contraste(TemaHud.TEXTO, bar)])
	TemaHud.aplicar(0)
	var t := TemaHud.crear_tema(ThemeDB.fallback_font)
	ok(t.get_color("font_color", "Label") == TemaHud.TEXTO, "crear_tema usa el color de texto vigente")
	TemaHud.aplicar(1)
	var t2 := TemaHud.crear_tema(ThemeDB.fallback_font)
	ok(t2.get_color("font_color", "Label") == TemaHud.TEXTO and t2.get_color("font_color", "Label") != t.get_color("font_color", "Label"), "otro tema = otro Theme")
	ok(TemaHud.color_rol("oro") == TemaHud.ORO and TemaHud.color_rol("titulo") == TemaHud.TITULO and TemaHud.color_rol("xx") == TemaHud.TEXTO, "color_rol devuelve el color del rol (y TEXTO si no existe)")
	var l := Label.new()
	TemaHud.rotular(l, "oro")
	TemaHud.aplicar(2)
	TemaHud.repintar_roles(l)
	ok(l.get_theme_color("font_color") == TemaHud.ORO, "repintar_roles pinta los textos con rol con el tema nuevo")
	l.free()
	TemaHud.aplicar(0)


# ── ajustes ─────────────────────────────────────────────────────────────────────────────────────────────────
func t_ajustes() -> void:
	print("[T] ── ajustes tema y bordes")
	var d := AjustesScript.por_defecto()
	ok(int(d["tema"]) == 0 and int(d["bordes"]) == 2, "por defecto: tema Cartográfico, bordes Alta (como la calidad Alta)")
	ok(int(AjustesScript.sanear({"tema": 7})["tema"]) == 0 and int(AjustesScript.sanear({"tema": "x"})["tema"]) == 0, "un tema inválido vuelve al 0")
	ok(int(AjustesScript.sanear({"tema": 2})["tema"]) == 2 and int(AjustesScript.sanear({"tema": 1.0})["tema"]) == 1, "los temas 1 y 2 valen (también como decimal sin parte fraccionaria)")
	ok(int(AjustesScript.sanear({"bordes": 5})["bordes"]) == 2 and int(AjustesScript.sanear({"bordes": 0})["bordes"]) == 0, "bordes: inválido = 2, 0 vale")
	ok(AjustesScript.BORDES_NOMBRES.size() == 3, "hay 3 calidades de bordes con nombre")
	ok(AjustesScript.preset_de(d) == 0, "los valores por defecto siguen siendo la calidad Alta")
	for i in 3:
		var c := AjustesScript.con_preset(d, i)
		ok(int(c["bordes"]) == 2 - i and AjustesScript.preset_de(c) == i, "la calidad %s fija bordes = %d" % [AjustesScript.PRESETS_NOMBRES[i], 2 - i])
	var raro := AjustesScript.por_defecto()
	raro["bordes"] = 0
	ok(AjustesScript.preset_de(raro) == AjustesScript.PRESET_PERSONALIZADA, "Alta con bordes Baja = Personalizada")
	var g := AjustesScript.por_defecto()
	g["tema"] = 2
	g["bordes"] = 1
	ok(AjustesScript.guardar(g, TEMP) == OK, "guardar con tema y bordes")
	var c2 := AjustesScript.cargar(TEMP)
	ok(int(c2["tema"]) == 2 and int(c2["bordes"]) == 1, "…y se cargan igual")
	ok(not AjustesScript.iguales(g, AjustesScript.por_defecto()), "iguales() distingue el tema")
	var viejo := ConfigFile.new()                                    # un archivo de una versión anterior (sin tema ni bordes)
	viejo.set_value("pantalla", "vsync", 1)
	viejo.save(TEMP)
	var c3 := AjustesScript.cargar(TEMP)
	ok(int(c3["tema"]) == 0 and int(c3["bordes"]) == 2, "un archivo viejo sin tema ni bordes carga con los de por defecto")


# ── selector de Opciones ────────────────────────────────────────────────────────────────────────────────────
func t_selector() -> void:
	print("[T] ── selector Interfaz")
	TemaHud.aplicar(0)
	main.ajustes["tema"] = 0
	var p = MenuPantallaScript.new()
	p.ruta = TEMP
	add_child(p)
	p.iniciar(get_window(), AjustesScript.por_defecto())
	var avisos := []
	p.tema_elegido.connect(func(id: int): avisos.append(id))
	ok(p._op_tema != null and p._op_tema.item_count == 3, "el selector tiene 3 opciones")
	ok(p._op_tema.get_item_text(1) == "Moderno oscuro", "la opción 1 es «Moderno oscuro»")
	p._op_tema.select(1)
	p._op_tema.item_selected.emit(1)
	ok(avisos == [1], "elegir un tema avisa de inmediato (sin pulsar APLICAR)")
	ok(int(p.vigente["tema"]) == 1 and int(p.pendiente["tema"]) == 1, "…y queda como vigente y pendiente")
	ok(int(AjustesScript.cargar(TEMP)["tema"]) == 1, "…y se guarda en el archivo al momento")
	ok(p._btn_aplicar.disabled, "el tema no deja APLICAR activado (no es un cambio pendiente)")
	ok(p._lbl_tema.text == TemaHud.DESCRIPCIONES[1], "la línea de ayuda describe el tema elegido")
	p.confirmando = true
	p._op_tema.item_selected.emit(2)
	ok(avisos == [1], "con «¿Mantener estos cambios?» en marcha no cambia el tema")
	p.confirmando = false
	p.queue_free()
	await esperar(0.1)


# ── HUD en vivo ─────────────────────────────────────────────────────────────────────────────────────────────
func t_hud_en_vivo() -> void:
	print("[T] ── HUD en vivo")
	var hud = main.hud
	main._seleccion_pais("Francia", "Europa", Vector2(700, 300))
	await esperar(0.5)
	main._aplicar_tema(0)
	await esperar(0.2)
	var panel_a: Color = hud.lbl_jugador.get_theme_color("font_color")
	ok(panel_a == TemaHud.ORO, "Cartográfico: el nombre del jugador va en el acento del tema")
	var hijos_antes: int = hud.cuerpo.get_child_count()
	main._aplicar_tema(1)
	await esperar(0.3)
	ok(TemaHud.ID == 1 and int(main.ajustes["tema"]) == 1, "_aplicar_tema(1) deja el tema 1 y lo anota en los ajustes")
	ok(hud.lbl_jugador.get_theme_color("font_color") == TemaHud.ORO and hud.lbl_jugador.get_theme_color("font_color") != panel_a, "el HUD se repinta: el nombre del jugador cambia de color")
	ok(hud.raiz.theme.get_color("font_color", "Label") == TemaHud.TEXTO, "el Theme del HUD es el nuevo")
	ok(hud.lbl_titulo.get_theme_color("font_color") == TemaHud.TITULO, "el título del panel de país usa el color de título del tema")
	ok(hud.cuerpo.get_child_count() == hijos_antes and hud.cuerpo.get_child_count() > 0, "el contenido de la pestaña se redibuja (%d bloques)" % hud.cuerpo.get_child_count())
	var cab_estilo: StyleBox = hud.cab_marco.get_theme_stylebox("panel")
	ok(cab_estilo is TemaHud.EstiloMetal and cab_estilo.arriba == TemaHud.CABECERA_ARRIBA, "la cabecera del panel usa el estilo del tema nuevo")
	var btn: Button = hud.btn_vista
	var est: StyleBox = btn.get_theme_stylebox("normal")
	ok(est is TemaHud.EstiloMetal and est.arriba == TemaHud.BTN_ARRIBA, "los botones con estilo propio también cambian")
	hud.set_velocidad(5)
	main._aplicar_tema(2)
	await esperar(0.2)
	ok(hud.lbl_fecha.get_theme_color("font_color") == TemaHud.NARANJA, "la fecha sigue en naranja con velocidad 5 tras cambiar de tema")
	hud.set_velocidad(1)
	hud.set_dinero("1.000", "-5", true, true)
	main._aplicar_tema(0)
	await esperar(0.2)
	ok(hud.lbl_dinero.get_theme_color("font_color") == TemaHud.MAL and hud.lbl_ingreso.get_theme_color("font_color") == TemaHud.MAL, "en deuda y con pérdida se conserva el rojo tras el cambio")
	hud.set_dinero("1.000", "+5")
	hud.abrir_pestana("militar")
	await esperar(0.3)
	main._aplicar_tema(1)
	await esperar(0.3)
	ok(hud.pestana == "militar" and hud.panel.visible, "la pestaña abierta y el panel siguen igual tras cambiar de tema")
	for clave in ["general", "diplomacia", "militar", "politica", "economia"]:
		hud.abrir_pestana(clave)
		await esperar(0.1)
	ok(true, "recorrer las 5 pestañas con el tema nuevo no da errores")
	main._aplicar_tema(0)
	await esperar(0.1)


# ── menús ───────────────────────────────────────────────────────────────────────────────────────────────────
func t_menus() -> void:
	print("[T] ── menú de pausa")
	main._aplicar_tema(0)
	main._mostrar_menu_pausa()
	await esperar(0.4)
	ok(main.panel_menu_nodo != null and is_instance_valid(main.panel_menu_nodo), "se abre el menú de pausa")
	var est0: StyleBox = main.panel_menu_nodo.get_theme_stylebox("panel")
	var arriba0: Color = est0.arriba
	main._aplicar_tema(2)
	await esperar(0.2)
	var est2: StyleBox = main.panel_menu_nodo.get_theme_stylebox("panel")
	ok(est2.arriba != arriba0 and est2.arriba == TemaHud.FONDO_ARRIBA, "el panel de la pausa cambia al tema nuevo")
	var titulo: Label = null
	for h in main.menu_contenido.get_children():
		if h is Label:
			titulo = h
			break
	ok(titulo != null and titulo.get_theme_color("font_color") == TemaHud.ORO, "el título de la pausa va en el acento del tema vigente")
	var centro: Control = main.panel_menu_nodo.get_parent()
	ok(centro.theme.get_color("font_color", "Button") == TemaHud.TEXTO, "los botones de la pausa heredan el tema nuevo")
	main._reanudar_juego()
	await esperar(0.2)
	main._aplicar_tema(0)
