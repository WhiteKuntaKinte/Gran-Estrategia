extends Node
## 0.1.8.38 · PRUEBAS DE HUD Y VENTANAS: panel del país movible y redimensionable (cabecera, bordes, memoria, vuelta a su sitio), tarjetas que se reparten en 1–3 columnas,
## Debug en cuadrícula con migas, ventanas con bordes redimensionables y memoria de sitio, avisos apilados y fichas al pasar el ratón.
const HudScript := preload("res://scripts/hud.gd")
const Tema := preload("res://scripts/tema_hud.gd")
const FichasScript := preload("res://scripts/fichas.gd")
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


func cerca_f(a: float, b: float, tol := 0.01) -> bool:
	return absf(a - b) <= tol


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.5)
	main._poner_velocidad(0)
	await t_panel()
	await t_tarjetas()
	await t_memoria_panel()
	await t_avisos()
	await t_fichas()
	await t_debug()
	await t_ventanas()
	print("[T] ═══ runner80: OK=%d FALLOS: %d" % [n_ok, fallos])
	print("FALLOS: %d" % fallos)
	get_tree().quit()


func vp() -> Vector2:
	return main.get_viewport().get_visible_rect().size


# ───────────────────────── Panel del país: mover y redimensionar ─────────────────────────
func t_panel() -> void:
	print("[T] ── Panel del país: mover y redimensionar")
	var h = main.hud
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	await esperar(0.5)
	ok(h.panel.visible and not h._panel_movido, "al elegir un país el panel se abre en su sitio de siempre")
	ok(cerca_f(h.panel.position.x, 14.0) and cerca_f(h.panel.position.y, h.PANEL_Y), "…en (14, PANEL_Y)")
	var ancho0: float = h.ancho_panel
	ok(ancho0 >= h.ANCHO_PANEL_MIN and ancho0 <= h.ANCHO_PANEL_MAX and h._ult_cols == 1, "ancho normal (%d px) = una sola columna de tarjetas" % int(ancho0))
	# mover
	var p0: Vector2 = h.panel.position
	h.mover_panel(Vector2(120, 90))
	ok(h._panel_movido and h.panel.position.is_equal_approx(p0 + Vector2(120, 90)), "mover_panel: el panel se corre lo que se arrastra y queda como «movido»")
	h.mover_panel(Vector2(9000, 9000))
	ok(h.panel.position.x <= vp().x - 119.0 and h.panel.position.y <= vp().y - 59.0, "…y no se puede sacar de la pantalla (siempre queda parte a la vista)")
	h.mover_panel(Vector2(-9000, -9000))
	ok(h.panel.position.y >= h.ALTO_BARRA - 0.01 and h.panel.position.x + h.panel.size.x >= 119.0, "…ni subirlo sobre la barra de arriba ni perderlo por la izquierda")
	h.mover_panel(Vector2(200, 150))
	h.set_campana(true)
	ok(h.panel.position.y > h.PANEL_Y + 5.0, "set_campana con el panel movido: no lo devuelve a su sitio")
	# agarres de borde
	h.volver_panel()
	await esperar(0.3)
	var sz: Vector2 = h.panel.size
	ok(h._borde_panel_en(Vector2(2, 100)) == h.PB_IZQ, "_borde_panel_en: borde izquierdo")
	ok(h._borde_panel_en(Vector2(sz.x - 2, 100)) == h.PB_DER, "…derecho")
	ok(h._borde_panel_en(Vector2(100, sz.y - 2)) == h.PB_ABA, "…de abajo")
	ok(h._borde_panel_en(Vector2(sz.x - 2, sz.y - 2)) == (h.PB_DER | h.PB_ABA), "…y la esquina de abajo a la derecha toca los dos")
	ok(h._borde_panel_en(Vector2(sz.x * 0.5, 100)) == 0, "…en medio no agarra nada")
	h.poner_compacto(true)
	ok(h._borde_panel_en(Vector2(100, h.panel.size.y - 2)) == 0, "en modo compacto el borde de abajo no se agarra (no tiene sección con scroll)")
	h.poner_compacto(false)
	await esperar(0.2)
	# ensanchar por la derecha
	h.arrastrar_borde_panel(h.PB_DER, Vector2(400, 0))
	await esperar(0.3)
	ok(h.ancho_panel > ancho0 + 300.0 and cerca_f(h.panel.custom_minimum_size.x, h.ancho_panel), "borde derecho +400: el panel se ensancha (%d px)" % int(h.ancho_panel))
	ok(h._panel_movido and cerca_f(h.panel.position.x, 14.0), "…sin correrse de sitio")
	ok(h._ult_cols == 2 and h._cols_cuerpo != null, "…y las tarjetas pasan a 2 columnas")
	# angostar por la izquierda: el borde derecho no se mueve
	var borde_der: float = h.panel.position.x + h.ancho_panel
	h.arrastrar_borde_panel(h.PB_IZQ, Vector2(250, 0))
	await esperar(0.2)
	ok(cerca_f(h.panel.position.x + h.ancho_panel, borde_der, 0.6), "borde izquierdo +250: el panel se angosta y su borde derecho se queda donde estaba")
	h.arrastrar_borde_panel(h.PB_DER, Vector2(-5000, 0))
	await esperar(0.2)
	ok(cerca_f(h.ancho_panel, h.ANCHO_PANEL_USUARIO_MIN), "no se puede angostar más del mínimo (%d px)" % int(h.ANCHO_PANEL_USUARIO_MIN))
	h.arrastrar_borde_panel(h.PB_DER, Vector2(5000, 0))
	await esperar(0.2)
	ok(h.ancho_panel <= vp().x - 16.0 + 0.01, "ni ensanchar más que la pantalla (%d de %d)" % [int(h.ancho_panel), int(vp().x)])
	# alto
	h.arrastrar_borde_panel(h.PB_DER, Vector2(-5000, 0))
	var alto0: float = h._alto_max
	h.arrastrar_borde_panel(h.PB_ABA, Vector2(0, 90))
	await esperar(0.3)
	ok(h._alto_max > alto0 + 40.0 or h.panel.position.y + h.panel.size.y >= vp().y - 12.0, "borde de abajo: el alto máximo de la sección crece (%d → %d)" % [int(alto0), int(h._alto_max)])
	h.arrastrar_borde_panel(h.PB_ABA, Vector2(0, 9000))
	await esperar(0.3)
	ok(h.panel.position.y + h.panel.size.y <= vp().y + 1.0, "…pero el panel nunca se sale por abajo (llega a %d de %d)" % [int(h.panel.position.y + h.panel.size.y), int(vp().y)])
	h.arrastrar_borde_panel(h.PB_ABA, Vector2(0, -9000))
	ok(h._alto_max >= 150.0 - 0.01, "…ni baja de 150 px")
	# panel de detalle pegado
	h.volver_panel()
	await esperar(0.3)
	h.panel_det.visible = true
	h.panel_det.reset_size()
	h._acomodar_det()
	ok(cerca_f(h.panel_det.position.x, h.panel.position.x + h.panel.size.x + 8.0, 1.5) and cerca_f(h.panel_det.position.y, h.panel.position.y), "el panel de detalle va pegado a la derecha del panel")
	h.mover_panel(Vector2(vp().x - 300.0, 0))
	h._acomodar_det()
	ok(h.panel_det.position.x < h.panel.position.x, "si el panel está pegado a la derecha de la pantalla, el detalle pasa a su izquierda")
	h.panel_det.visible = false
	# volver
	h.mover_panel(Vector2(-300, 120))
	h.arrastrar_borde_panel(h.PB_DER, Vector2(300, 0))
	h.volver_panel()
	await esperar(0.3)
	ok(not h._panel_movido and cerca_f(h.panel.position.x, 14.0) and cerca_f(h.panel.position.y, h.PANEL_Y), "volver_panel: de vuelta a su sitio")
	ok(cerca_f(h.ancho_panel, ancho0) and h._ult_cols == 1 and h._cols_cuerpo == null, "…con su ancho y una columna")
	ok(not main.geo_ventanas.has("panel_pais"), "…y olvida la posición guardada")
	# el doble clic en la cabecera lo devuelve
	h.mover_panel(Vector2(200, 100))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = true
	h._on_cab_input(ev)
	await esperar(0.2)
	ok(not h._panel_movido and cerca_f(h.panel.position.y, h.PANEL_Y), "doble clic en la cabecera: vuelve a su sitio")
	# arrastrar la cabecera con el ratón
	var p1: Vector2 = h.panel.position
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	h._on_cab_input(down)
	var mov := InputEventMouseMotion.new()
	mov.relative = Vector2(40, 30)
	h._on_cab_input(mov)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	h._on_cab_input(up)
	h._on_cab_input(mov)
	ok(h.panel.position.is_equal_approx(p1 + Vector2(40, 30)), "arrastrar la cabecera con el ratón mueve el panel (y al soltar deja de moverlo)")
	ok(main.geo_ventanas.has("panel_pais"), "…y al soltar recuerda dónde quedó")
	h.volver_panel()
	await esperar(0.2)


# ───────────────────────── Tarjetas ─────────────────────────
func t_tarjetas() -> void:
	print("[T] ── Tarjetas del panel")
	var h = main.hud
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	await esperar(0.4)
	var ancho0: float = h.ancho_panel
	for par in [[372.0, 1], [420.0, 1], [700.0, 1], [708.0, 2], [1000.0, 2], [1048.0, 3], [1200.0, 3]]:
		h.ancho_panel = par[0]
		ok(h._columnas_tarjetas() == par[1], "_columnas_tarjetas con %d px → %d" % [int(par[0]), par[1]])
	h.ancho_panel = ancho0
	var hay_tarjeta := false
	for it in h._items_cuerpo:
		if it is PanelContainer:
			hay_tarjeta = true
	ok(h._items_cuerpo.size() >= 2 and hay_tarjeta, "General: el cuerpo lleva varias secciones y son tarjetas con marco (%d)" % h._items_cuerpo.size())
	for pest in ["general", "diplomacia", "militar", "politica", "economia"]:
		h.abrir_pestana(pest)
		await esperar(0.3)
		h.arrastrar_borde_panel(h.PB_DER, Vector2(5000, 0))
		await esperar(0.2)
		var n_items: int = h._items_cuerpo.size()
		var en_arbol := 0
		var cols := 0
		if h._cols_cuerpo != null:
			for c in h._cols_cuerpo.get_children():
				cols += 1
				en_arbol += c.get_child_count()
		else:
			for it in h._items_cuerpo:
				if is_instance_valid(it) and (it as Node).get_parent() == h.cuerpo:
					en_arbol += 1
		ok(en_arbol == n_items, "pestaña %s ancha: las %d tarjetas están todas en el árbol (%d columnas)" % [pest, n_items, cols])
		if pest == "militar":
			continue
		ok(cols == 0 or cols == h._ult_cols, "…y las columnas son las que tocan (%d)" % h._ult_cols)
		h.volver_panel()
		await esperar(0.2)
	h.abrir_pestana("general")
	h.arrastrar_borde_panel(h.PB_DER, Vector2(5000, 0))
	await esperar(0.3)
	if h._cols_cuerpo != null and h._items_cuerpo.size() >= 3:
		var altos: Array = []
		for c in h._cols_cuerpo.get_children():
			altos.append((c as Control).get_combined_minimum_size().y)
		var mx := 0.0
		var mn := 1e9
		for a in altos:
			mx = maxf(mx, float(a))
			mn = minf(mn, float(a))
		ok(h._cols_cuerpo.get_child_count() == h._ult_cols and mx - mn < 700.0, "el reparto en columnas queda parejo (%s)" % str(altos))
	h.volver_panel()
	await esperar(0.2)
	# cambiar de tamaño de ventana no rompe la geometría
	h.arrastrar_borde_panel(h.PB_DER, Vector2(400, 0))
	await esperar(0.2)
	ok(h.panel.size.x >= h.ancho_panel - 1.0, "con el panel ancho su ancho real es el pedido (%d / %d)" % [int(h.panel.size.x), int(h.ancho_panel)])
	h.volver_panel()
	await esperar(0.2)


# ───────────────────────── Memoria del panel entre sesiones ─────────────────────────
func t_memoria_panel() -> void:
	print("[T] ── Memoria del panel del país")
	var h = main.hud
	h.mover_panel(Vector2(150, 100))
	h.arrastrar_borde_panel(h.PB_DER, Vector2(200, 0))
	h._guardar_geo_panel()
	var g: Array = main.geo_ventanas["panel_pais"]
	ok((g[0] as Vector2).is_equal_approx(h.panel.position) and cerca_f((g[1] as Vector2).x, h.ancho_panel), "_guardar_geo_panel: guarda sitio y ancho")
	var pos_g: Vector2 = h.panel.position
	var ancho_g: float = h.ancho_panel
	var h2 = HudScript.new()
	main.add_child(h2)
	h2.construir(main, main.fuente_ui, main.fuente_ui_neg)
	ok(h2.panel.position.is_equal_approx(pos_g) and cerca_f(h2.ancho_panel, ancho_g) and h2._panel_movido, "un HUD nuevo (otra partida) abre el panel donde y como lo dejaste")
	h2.queue_free()
	await esperar(0.2)
	main.geo_ventanas["panel_pais"] = [Vector2(-9000, -9000), Vector2(99999, 99999)]
	var h3 = HudScript.new()
	main.add_child(h3)
	h3.construir(main, main.fuente_ui, main.fuente_ui_neg)
	ok(h3.panel.position.x >= 0.0 and h3.panel.position.y >= h3.ALTO_BARRA and h3.ancho_panel <= vp().x - 16.0 and h3._alto_max <= vp().y, "una geometría guardada absurda (otra pantalla) se corrige para que entre")
	h3.queue_free()
	await esperar(0.2)
	h.volver_panel()
	await esperar(0.2)


# ───────────────────────── Avisos apilados ─────────────────────────
func t_avisos() -> void:
	print("[T] ── Avisos apilados")
	var av = main.avisos
	ok(av != null and av.pila != null and av.capa.layer == 26, "main.avisos existe (capa 26) con su pila")
	av.limpiar()
	ok(av.cantidad() == 0, "limpiar: sin avisos")
	main.aviso("Uno", "info")
	main.aviso("Dos", "ok")
	main.aviso("Tres", "aviso")
	ok(av.cantidad() == 3 and av.textos() == ["Uno", "Dos", "Tres"], "tres avisos distintos se apilan, el más nuevo abajo")
	ok(av.ultimo_texto == "Tres" and av.ultimo_nivel == "aviso", "ultimo_texto / ultimo_nivel guardan el último")
	main.aviso("Tres", "aviso")
	ok(av.cantidad() == 3, "el mismo texto seguido no apila otro")
	var lbl: Label = (av.pila.get_child(2).get_child(0) as Control).get_node("Texto")
	ok(lbl.text.ends_with("×2"), "…sino que suma «×2» (%s)" % lbl.text)
	main.aviso("Tres", "mal")
	ok(av.cantidad() == 4, "el mismo texto con otro nivel sí es otro aviso")
	for i in 8:
		main.aviso("Aviso %d" % i, "info")
	ok(av.cantidad() == av.MAX_AVISOS, "nunca hay más de %d a la vez (hay %d)" % [av.MAX_AVISOS, av.cantidad()])
	ok(av.textos().back() == "Aviso 7" and not av.textos().has("Uno"), "…y se va el más viejo")
	main.aviso("", "info")
	main.aviso("   ", "info")
	ok(av.cantidad() == av.MAX_AVISOS and av.ultimo_texto == "Aviso 7", "los textos vacíos no hacen aviso")
	ok(av._color_nivel("mal") == Tema.MAL and av._color_nivel("ok") == Tema.OK and av._color_nivel("aviso") == Tema.NARANJA and av._color_nivel("info") == Tema.ACERO_CLARO, "cada nivel tiene su color")
	# posición: arriba a la derecha, bajo la barra
	await esperar(0.2)
	var r: Rect2 = av.pila.get_global_rect()
	ok(r.position.y >= 40.0 and r.end.x <= vp().x - 8.0 and r.end.x >= vp().x - 30.0, "la pila está arriba a la derecha, bajo la barra (%s)" % str(r))
	# clic quita
	var primero: Node = av.pila.get_child(0)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	av._on_aviso_input(ev, primero)
	ok(av.cantidad() == av.MAX_AVISOS - 1, "un clic sobre el aviso lo quita")
	# pasar el ratón detiene el desvanecido
	var a2: PanelContainer = av.pila.get_child(0)
	av._on_sobre(a2, true)
	ok(not a2.has_meta("tween") and cerca_f(a2.modulate.a, 1.0), "con el ratón encima no corre el tiempo del aviso")
	av._on_sobre(a2, false)
	ok(a2.has_meta("tween"), "al salir el ratón se reanuda")
	# el tema repinta
	main._aplicar_tema(1)
	var sb: StyleBoxFlat = (av.pila.get_child(0) as PanelContainer).get_theme_stylebox("panel")
	ok(sb.bg_color.is_equal_approx(Tema.TARJETA), "al cambiar de tema los avisos se repintan")
	main._aplicar_tema(0)
	# se desvanece solo
	av.limpiar()
	main.aviso("Se va solo", "info")
	await esperar(av.DURACION["info"] + av.FUNDIDO + 0.6)
	ok(av.cantidad() == 0, "tras %.1f s el aviso se desvanece y se quita solo" % (av.DURACION["info"] + av.FUNDIDO))
	main.aviso("A", "mal")
	ok(float(av.DURACION["mal"]) > float(av.DURACION["info"]), "los avisos malos duran más que los informativos")
	av.limpiar()
	# los mensajes del juego ya no pisan la línea de ayuda
	var hint0: String = main.hud.lbl_hint.text
	main.hud_aviso("Guerra declarada")
	ok(main.hud.lbl_hint.text == hint0 and av.ultimo_texto == "Guerra declarada" and av.ultimo_nivel == "info", "hud_aviso va al aviso apilado y la línea de ayuda queda como estaba")
	av.limpiar()


# ───────────────────────── Fichas ─────────────────────────
func t_fichas() -> void:
	print("[T] ── Fichas (tooltips)")
	var f = main.fichas
	ok(f != null and f.capa.layer == 30, "main.fichas existe (capa 30)")
	ok(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)) >= 1000.0, "el tooltip nativo de Godot está apagado (si no, saldrían dos)")
	var p := FichasScript.partir("Cerrar")
	ok(p == ["Cerrar", "", ""], "partir: una línea corta → solo título")
	p = FichasScript.partir("Esto es una explicación bastante más larga que un título")
	ok(p[0] == "" and String(p[1]).begins_with("Esto es"), "partir: una línea larga → solo detalle")
	p = FichasScript.partir("Menú Debug\nSe abre encima del juego.\nAtajo: F1")
	ok(p == ["Menú Debug", "Se abre encima del juego.", "Atajo: F1"], "partir: título, detalle y atajo")
	p = FichasScript.partir("Título\nAtajo: R")
	ok(p == ["Título", "", "Atajo: R"], "partir: título y atajo sin detalle")
	p = FichasScript.partir("Uno\nDos\nTres")
	ok(p[0] == "Uno" and p[1] == "Dos\nTres", "partir: varias líneas de detalle")
	p = FichasScript.partir("")
	ok(p == ["", "", ""], "partir: texto vacío")
	var b := Button.new()
	main.add_child(b)
	b.tooltip_text = "Normal"
	ok(FichasScript.texto_de(b) == "Normal", "texto_de: el tooltip_text")
	b.set_meta("ficha", func(): return "En vivo\nvalor 42")
	ok(FichasScript.texto_de(b) == "En vivo\nvalor 42", "texto_de: la ficha con datos al día manda sobre el tooltip_text")
	b.queue_free()
	# mostrar sobre un botón de la barra
	var btn = main.hud.btn_debug
	var ok_m: bool = await f.mostrar_de(btn, Vector2(600, 300))
	ok(ok_m and f.esta_visible() and f.ficha_de == btn, "mostrar_de(Debug): la ficha se ve y sabe de qué control es")
	ok(f.lbl_titulo.text == "Menú Debug" and f.lbl_atajo.text == "Atajo: F1" and f.lbl_cuerpo.text.contains("sin pausarlo"), "…con título, detalle y atajo")
	ok(f.marco.size.y < 140.0 and f.marco.size.x <= f.ANCHO_MAX + 24.0, "…y es chica, no una columna alta (%s)" % str(f.marco.size))
	ok(f.marco.position.is_equal_approx(Vector2(616, 322)), "…junto al puntero (%s)" % str(f.marco.position))
	# en la esquina de abajo a la derecha cabe entera
	await f.mostrar_de(btn, Vector2(1275, 715))
	var r: Rect2 = Rect2(f.marco.position, f.marco.size)
	ok(r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= vp().x + 0.5 and r.end.y <= vp().y + 0.5, "en la esquina de abajo a la derecha no se sale de la pantalla (%s)" % str(r))
	f.ocultar()
	ok(not f.esta_visible() and f.ficha_de == null, "ocultar: se va")
	var sin := Button.new()
	main.add_child(sin)
	ok(not (await f.mostrar_de(sin, Vector2(10, 10))) and not f.esta_visible(), "un control sin texto no tiene ficha")
	sin.queue_free()
	f.activa = false
	ok(not (await f.mostrar_de(btn, Vector2(10, 10))), "con las fichas apagadas no sale nada")
	f.activa = true
	# todas las cosas de la barra tienen ficha con título
	for n in [main.hud.btn_debug, main.hud.btn_vista, main.hud.lbl_fecha, main.hud.btn_cerrar, main.hud.btn_compacto]:
		var pp := FichasScript.partir(FichasScript.texto_de(n))
		ok(String(pp[0]) != "", "ficha con título en %s (%s)" % [n.name, pp[0]])
	# tema
	main._aplicar_tema(1)
	ok((f.marco.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.is_equal_approx(Tema.TOOLTIP_ARRIBA), "al cambiar de tema la ficha se repinta")
	main._aplicar_tema(0)


# ───────────────────────── Debug en cuadrícula ─────────────────────────
func t_debug() -> void:
	print("[T] ── Debug: cuadrícula y migas")
	main._abrir_debug()
	await esperar(0.4)
	var d = main.debug_menu
	ok(d != null and d.pestana_actual == "" and d.pagina_menu.visible, "el Debug abre en la cuadrícula de secciones")
	ok(d._tarjetas.size() == d.SECCIONES.size(), "una tarjeta por sección (%d)" % d._tarjetas.size())
	var textos := []
	for c in d.caja_migas.get_children():
		if c is Button:
			textos.append((c as Button).text)
	ok(textos == ["Menú Debug"], "migas en la cuadrícula: solo «Menú Debug» (%s)" % str(textos))
	for sec in d.SECCIONES:
		d._ir_a(sec[0])
		await esperar(0.15)
		var vis: bool = d.paginas.has(sec[0]) and (d.paginas[sec[0]] as Control).visible
		var miga := ""
		for c in d.caja_migas.get_children():
			if c is Label and (c as Label).text != "›":
				miga = (c as Label).text
		ok(vis and not d.pagina_menu.visible and miga == String(sec[1]) and d.pestana_actual == sec[0], "sección «%s»: se abre, oculta la cuadrícula y la miga dice «Menú Debug › %s»" % [sec[1], miga])
	d._ir_menu()
	ok(d.pestana_actual == "" and d.pagina_menu.visible, "←: de vuelta a la cuadrícula")
	var hay_visible := false
	for k in d.paginas:
		if (d.paginas[k] as Control).visible:
			hay_visible = true
	ok(not hay_visible, "…y ninguna página queda a la vista")
	# tarjetas de la cuadrícula
	var tj: Button = d._tarjetas["tiempo"]
	ok(tj.tooltip_text != "" or tj.get_child_count() > 0, "las tarjetas llevan su descripción")
	tj.pressed.emit()
	ok(d.pestana_actual == "tiempo", "pulsar una tarjeta abre su sección")
	d._ir_menu()
	# tema en vivo
	var antes: Color = (d._tarjetas["tiempo"] as Button).get_theme_stylebox("normal").bg_color if (d._tarjetas["tiempo"] as Button).get_theme_stylebox("normal") is StyleBoxFlat else Color.BLACK
	main._aplicar_tema(1)
	await esperar(0.2)
	var despues: Color = (d._tarjetas["tiempo"] as Button).get_theme_stylebox("normal").bg_color if (d._tarjetas["tiempo"] as Button).get_theme_stylebox("normal") is StyleBoxFlat else Color.BLACK
	ok(not antes.is_equal_approx(despues) or antes == Color.BLACK, "cambiar de tema con el Debug abierto repinta las tarjetas")
	main._aplicar_tema(2)
	await esperar(0.2)
	main._aplicar_tema(0)
	ok(is_instance_valid(d), "…y no rompe nada tras recorrer los tres temas")


# ───────────────────────── Ventanas: bordes y memoria ─────────────────────────
func t_ventanas() -> void:
	print("[T] ── Ventanas flotantes: bordes y memoria de sitio")
	var d = main.debug_menu
	var vf = d.vf
	var w = vf.ventana
	await esperar(0.3)
	w.position = Vector2(300.0, 80.0)                           # lejos del borde derecho para que haya sitio donde crecer
	var sz0: Vector2 = w.size
	var pos0: Vector2 = w.position
	ok(vf._borde_en(Vector2(2, 100)) == vf.B_IZQ and vf._borde_en(Vector2(sz0.x - 2, 100)) == vf.B_DER, "_borde_en: izquierdo y derecho")
	ok(vf._borde_en(Vector2(100, 2)) == vf.B_ARR and vf._borde_en(Vector2(100, sz0.y - 2)) == vf.B_ABA, "…arriba y abajo")
	ok(vf._borde_en(Vector2(2, 2)) == (vf.B_IZQ | vf.B_ARR) and vf._borde_en(Vector2(sz0.x * 0.5, sz0.y * 0.5)) == 0, "…esquinas y centro")
	vf.arrastrar_borde(vf.B_DER, Vector2(60, 0))
	await esperar(0.2)
	ok(w.size.x > sz0.x + 50.0 and cerca_f(w.position.x, pos0.x, 0.6), "borde derecho +60: se ensancha y no se corre")
	var der: float = w.position.x + w.size.x
	vf.arrastrar_borde(vf.B_IZQ, Vector2(-40, 0))
	await esperar(0.2)
	ok(w.position.x < pos0.x - 30.0 and cerca_f(w.position.x + w.size.x, der, 0.6), "borde izquierdo -40: crece hacia la izquierda y el borde derecho queda quieto")
	var abajo: float = w.position.y + w.size.y
	vf.arrastrar_borde(vf.B_ARR, Vector2(0, 30))
	await esperar(0.2)
	ok(cerca_f(w.position.y + w.size.y, abajo, 0.6), "borde de arriba +30: el de abajo no se mueve")
	vf.arrastrar_borde(vf.B_DER | vf.B_ABA, Vector2(-9000, -9000))
	await esperar(0.2)
	ok(w.size.x >= vf.TAM_MIN.x - 0.5 and w.size.y >= vf.TAM_MIN.y - 0.5, "nunca baja del tamaño mínimo (%s)" % str(w.size))
	vf.arrastrar_borde(vf.B_DER | vf.B_ABA, Vector2(9000, 9000))
	await esperar(0.2)
	ok(w.position.x + w.size.x <= vp().x + 0.5 and w.position.y + w.size.y <= vp().y + 0.5, "ni se sale de la pantalla")
	# memoria
	vf.arrastrar_borde(vf.B_DER | vf.B_ABA, Vector2(-300, -250))
	await esperar(0.2)
	var pos_fin: Vector2 = w.position
	var tam_fin: Vector2 = vf._tam
	main._cerrar_debug()
	await esperar(0.4)
	ok(main.geo_ventanas.has("debug"), "al cerrar el Debug recuerda su sitio y su tamaño")
	main._abrir_debug()
	await esperar(0.4)
	var w2 = main.debug_menu.vf.ventana
	ok(w2.position.distance_to(pos_fin) < 1.5 and main.debug_menu.vf._tam.distance_to(tam_fin) < 1.5, "al abrirlo otra vez aparece donde y como lo dejaste")
	main._cerrar_debug()
	await esperar(0.3)
	# Mi país y Ranking recuerdan lo suyo
	main._abrir_personalizar()
	await esperar(0.4)
	ok(main.panel_pers != null, "«Mi país» se abre con la campaña")
	if main.panel_pers != null:
		main.panel_pers.vf.arrastrar_borde(main.panel_pers.vf.B_DER, Vector2(40, 0))
		main._cerrar_personalizar()
		await esperar(0.4)
		ok(main.geo_ventanas.has("mipais"), "«Mi país» recuerda su sitio y tamaño")
	ok(String(ProjectSettings.get_setting("application/config/name", "")).contains("0.1.8.38"), "project.godot lleva la versión 0.1.8.38")
