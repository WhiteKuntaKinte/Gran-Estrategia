extends Node
## 0.1.8.41 · PRUEBAS DE LOS ICONOS DE LA INTERFAZ Y LAS MIGAS: los 39 iconos i_*.png en HD (128 px, con mipmaps), el filtro por defecto del proyecto,
## y las migas del HUD (píldoras con bandera o icono de su nivel, la última resaltada, clic y realce).
var main
var fallos := 0
var n_ok := 0


func _ready() -> void:
	run.call_deferred()


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func fotogramas(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func ok(cond: bool, msg: String) -> void:
	if cond:
		n_ok += 1
		print("[T] OK    ", msg)
	else:
		fallos += 1
		print("[T] FALLO ", msg)


func arrancar() -> void:
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)


func run() -> void:
	await arrancar()
	t_iconos()
	await t_migas()
	print("[T] ═══ RESULTADO runner87: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func chips() -> Array:
	var r := []
	for h in main.hud.caja_migas.get_children():
		if h is PanelContainer:
			r.append(h)
	return r


func icono_de(chip: Node) -> TextureRect:
	return chip.get_child(0).get_child(0) as TextureRect


func texto_de(chip: Node) -> Label:
	return chip.get_child(0).get_child(1) as Label


func clic(chip: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	chip.gui_input.emit(ev)


# ─────────────────────────────────────────────────────────────
func t_iconos() -> void:
	print("[T] ── Iconos de la interfaz en HD")
	var nombres := ["alt", "area", "atras", "carne", "ciudad", "cont", "cultivo", "debug", "dens", "desc", "devast", "dipl", "eco", "editar", "ejercito", "estado", "estrella",
		"etn", "fauna", "flora", "gob", "info", "lentes", "mineral", "moneda", "pais", "pausa", "pob", "prof", "prov", "tpausa", "veg", "vel1", "vel2", "vel3", "vel4", "vel5", "vel6", "vista"]
	var mal := []
	var vacios := []
	var sin_mip := []
	for n in nombres:
		var t: Texture2D = main.icono("i_" + n)
		if t == null or t.get_width() != 128 or t.get_height() != 128:
			mal.append(n)
			continue
		var img := t.get_image()
		if not img.has_mipmaps():
			sin_mip.append(n)
		var opacos := 0
		for y in range(0, 128, 4):
			for x in range(0, 128, 4):
				if img.get_pixel(x, y).a > 0.5:
					opacos += 1
		if opacos < 60:                                # de 1024 muestras: un icono con menos de ~6 % de tinta está casi vacío
			vacios.append(n)
	ok(mal.is_empty(), "los %d iconos i_*.png existen y miden 128×128 (mal: %s)" % [nombres.size(), str(mal)])
	ok(vacios.is_empty(), "ninguno está vacío (vacíos: %s)" % str(vacios))
	ok(sin_mip.is_empty(), "todos se cargan con mipmaps (sin ellos: %s)" % str(sin_mip.slice(0, 4)))
	var sobran := []
	var d := DirAccess.open("res://iconos")
	for f in d.get_files():
		if f.begins_with("i_") and f.get_extension() == "png" and not nombres.has(f.get_basename().substr(2)):
			sobran.append(f)
	ok(sobran.is_empty(), "no hay otros i_*.png sin revisar (sobran: %s)" % str(sobran))
	ok(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", 1)) == 1, "el filtro de texturas del proyecto sigue en «Linear» (el mapa no paga mipmaps)")
	ok(main.hud.tex_bandera.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and main.hud.btn_vista.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"la bandera del panel y el botón de vista filtran con mipmaps")
	ok(main.hud.raiz.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE and main.hud.caja_migas.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE,
		"la raíz del HUD y la fila de migas no cambian el filtro (los fondos no pagan mipmaps)")
	ok(main.icono("i_atras") == main.icono("i_atras"), "pedir un icono dos veces da el mismo (caché)")
	var t0 := Time.get_ticks_usec()
	for n in nombres:
		main.tex_cache.erase("i_" + n)
		main.icono("i_" + n)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	ok(ms < 400.0, "cargar los 39 iconos con mipmaps tarda %.0f ms (%.1f ms cada uno)" % [ms, ms / 39.0])
	var bandera: Texture2D = main.bandera_tex("p_co")
	ok(bandera != null and bandera.get_image().has_mipmaps(), "las banderas de 96 px también llevan mipmaps")
	ok(main.bandera_tex("-") != null and main.bandera_tex("no_existe_zzz") != null, "una bandera que falta cae a la X sin fallar")


func t_migas() -> void:
	print("[T] ── Migas del HUD")
	var m = main.mundo
	var hud = main.hud
	main._seleccion_continente("Asia", Vector2(600.0, 600.0))
	await fotogramas(3)
	var c := chips()
	ok(c.size() == 1 and texto_de(c[0]).text == "Asia", "continente: una píldora «Asia» (%d)" % c.size())
	ok(icono_de(c[0]).texture == main.icono("i_cont"), "…con el icono del continente")
	ok(hud.caja_migas.get_child_count() == 1, "…y sin separadores (solo hay una)")
	main._seleccion_pais("Japón", "Asia", Vector2(600.0, 600.0))
	await fotogramas(3)
	c = chips()
	ok(c.size() == 2 and texto_de(c[0]).text == "Asia" and texto_de(c[1]).text == "Japón", "país: Asia › Japón")
	ok(hud.caja_migas.get_child_count() == 3 and hud.caja_migas.get_child(1) is Label, "…con un separador «›» entre las dos")
	ok(icono_de(c[1]).texture == main.bandera_tex("p_jp") and icono_de(c[1]).custom_minimum_size.x >= 20.0, "la píldora de Japón lleva su bandera (21×14)")
	ok(icono_de(c[0]).custom_minimum_size.x == 16.0, "la de Asia lleva un icono cuadrado de 16 px")
	ok(icono_de(c[0]).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and icono_de(c[1]).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "los iconos de las píldoras filtran con mipmaps")
	ok(texto_de(c[1]).get_theme_font("font") == hud.fuente_neg and texto_de(c[0]).get_theme_font("font") == hud.fuente, "la última (donde estás) va en negrita; las otras, normal")
	var f1: StyleBoxFlat = c[1].get_theme_stylebox("panel")
	var f0: StyleBoxFlat = c[0].get_theme_stylebox("panel")
	ok(f1.border_width_left == 2 and f0.border_width_left == 1 and f1.bg_color != f0.bg_color, "la activa tiene borde más grueso y otro fondo")
	ok(c[1].mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND and c[1].tooltip_text.begins_with("País\n"), "cursor de mano y ficha «País»")
	# todo lo que hay dentro ignora el ratón: el clic llega a la píldora
	ok(icono_de(c[0]).mouse_filter == Control.MOUSE_FILTER_IGNORE and texto_de(c[0]).mouse_filter == Control.MOUSE_FILTER_IGNORE, "icono y texto dejan pasar el ratón a la píldora")
	# clic y realce
	var pedidas := []
	hud.miga_pedida.connect(func(nivel: String, nombre: String): pedidas.append([nivel, nombre]))
	clic(c[0])
	ok(pedidas == [["continente", "Asia"]], "clic en «Asia» pide ir al continente (%s)" % str(pedidas))
	clic(c[1])
	ok(pedidas.size() == 2 and pedidas[1] == ["pais", "Japón"], "clic en «Japón» pide ir al país")
	c = chips()
	var antes: StyleBoxFlat = c[0].get_theme_stylebox("panel")
	c[0].mouse_entered.emit()
	var realce: StyleBoxFlat = c[0].get_theme_stylebox("panel")
	ok(realce != antes and realce.border_color.a > 0.8 and realce.border_color.r > 0.9, "al pasar el ratón la píldora se realza (borde blanco)")
	c[0].mouse_exited.emit()
	ok(c[0].get_theme_stylebox("panel") == antes, "…y al salir vuelve a como estaba")
	# ir de verdad a Asia con la miga
	main._on_miga("continente", "Asia")
	await fotogramas(3)
	ok(chips().size() == 1 and texto_de(chips()[0]).text == "Asia", "la miga «Asia» lleva de verdad al continente")
	# una provincia con bandera propia
	main._seleccion_pais("Japón", "Asia", Vector2(600.0, 600.0))
	await fotogramas(2)
	var pi: int = int(m.paises["Japón"].provincias[0])
	main._seleccion_provincia(pi, "Asia", Vector2(600.0, 600.0))
	await fotogramas(3)
	c = chips()
	ok(c.size() == 3 and icono_de(c[2]).custom_minimum_size.x >= 20.0, "provincia: Asia › Japón › prefectura, las tres con su bandera o icono (%d píldoras)" % c.size())
	ok(icono_de(c[2]).texture != null and texto_de(c[2]).text == String(m.provincias[pi].nombre), "la última es la provincia elegida (%s)" % texto_de(c[2]).text)
	# una ciudad con bandera (San Diego → la de California) y otra sin bandera (usa el icono de ciudad)
	var con := -1
	var sin := -1
	for c2 in m.ciudades:
		if con < 0 and c2.nombre == "San Diego" and c2.bandera != "":
			con = c2.id
		if sin < 0 and c2.bandera == "" and c2.provincia >= 0:
			sin = c2.id
	ok(con >= 0 and sin >= 0, "hay una ciudad con bandera y otra sin ella para probar")
	if con >= 0:
		main._seleccion_ciudad(con, Vector2(600.0, 600.0))
		await fotogramas(3)
		c = chips()
		ok(c.size() >= 3 and texto_de(c[c.size() - 1]).text == "San Diego" and icono_de(c[c.size() - 1]).texture == main.bandera_tex("s_us_ca"), "ciudad: «San Diego» lleva la bandera de California")
	if sin >= 0:
		main._seleccion_ciudad(sin, Vector2(600.0, 600.0))
		await fotogramas(3)
		c = chips()
		ok(icono_de(c[c.size() - 1]).texture == main.icono("i_ciudad") and icono_de(c[c.size() - 1]).custom_minimum_size.x == 16.0, "ciudad sin bandera: la píldora usa el icono de ciudad (no la X negra)")
	# compacto: las migas se esconden y vuelven
	hud.poner_compacto(true)
	await fotogramas(2)
	ok(not hud.caja_migas.visible, "en modo compacto las migas se ocultan")
	hud.poner_compacto(false)
	await fotogramas(2)
	ok(hud.caja_migas.visible, "y vuelven al abrir el panel")
	# coste de rehacerlas
	var t0 := Time.get_ticks_usec()
	for i in 20:
		hud._dibujar_migas()
	var ms := float(Time.get_ticks_usec() - t0) / 20000.0
	ok(ms < 4.0, "rehacer las migas cuesta %.2f ms" % ms)
