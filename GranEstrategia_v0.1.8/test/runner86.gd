extends Node
## 0.1.8.41 · PRUEBAS DE BANDERAS HD: cada bandera de 96 px tiene su HD (256 px), `bandera_hd()` las carga con mipmaps y con caché limitada,
## el panel y el aviso de guerra las usan, y las ciudades de EE. UU. con licencia CC ya no existen en el juego.
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
	t_archivos()
	t_funcion()
	t_licencias()
	await t_panel()
	await t_aviso_guerra()
	print("[T] ═══ RESULTADO runner86: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func nombres_png(carpeta: String) -> Array:
	var r := []
	var d := DirAccess.open(carpeta)
	if d == null:
		return r
	for f in d.get_files():
		if f.get_extension() == "png":
			r.append(f.get_basename())
	r.sort()
	return r


func hallar_textura(n: Node, ancho_min: int) -> TextureRect:
	if n is TextureRect and (n as TextureRect).texture != null and (n as TextureRect).texture.get_width() >= ancho_min:
		return n
	for h in n.get_children():
		var r := hallar_textura(h, ancho_min)
		if r != null:
			return r
	return null


# ─────────────────────────────────────────────────────────────
func t_archivos() -> void:
	print("[T] ── Una bandera HD por cada bandera de 96 px")
	var a := nombres_png("res://banderas")
	var b := nombres_png("res://banderas_hd")
	ok(a.size() > 900 and a == b, "banderas/ (%d) y banderas_hd/ (%d) tienen los mismos nombres" % [a.size(), b.size()])
	var mal := []
	var estrechas := []
	for n in b:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://banderas_hd/%s.png" % n))
		if img == null or img.is_empty():
			mal.append(n)
		elif img.get_width() < 150:
			estrechas.append(n)
	ok(mal.is_empty(), "todas las HD abren como imagen (mal: %s)" % str(mal.slice(0, 4)))
	ok(estrechas.is_empty(), "ninguna HD es más angosta de 150 px (angostas: %s)" % str(estrechas.slice(0, 4)))
	var img0 := Image.load_from_file(ProjectSettings.globalize_path("res://banderas_hd/p_co.png"))
	ok(img0 != null and img0.get_width() == 256 and img0.get_height() > 100, "p_co.png (Colombia) mide 256 de ancho")
	var img1 := Image.load_from_file(ProjectSettings.globalize_path("res://banderas/p_co.png"))
	ok(img1 != null and img0 != null and img0.get_width() > img1.get_width() * 2, "la HD es más del doble de ancha que la de 96 px")
	var altas := []
	for n in b:
		var im := Image.load_from_file(ProjectSettings.globalize_path("res://banderas_hd/%s.png" % n))
		if im != null and im.get_height() > 192:
			altas.append(n)
	ok(altas.is_empty(), "ninguna HD pasa de 192 px de alto (pasan: %s)" % str(altas.slice(0, 4)))


func t_funcion() -> void:
	print("[T] ── bandera_hd(): mipmaps, caché y respaldo")
	var t: Texture2D = main.bandera_hd("p_co")
	ok(t is ImageTexture and t.get_width() == 256, "bandera_hd devuelve una textura de 256 px")
	ok(t.get_image().has_mipmaps(), "la textura tiene mipmaps")
	ok(main.bandera_hd("p_co") == t, "pedirla otra vez da la misma textura (caché)")
	var x_hd: Texture2D = main.bandera_hd("-")
	ok(x_hd != null and x_hd.get_width() == 256, "«-» (sin bandera) da la X en HD")
	var falta: Texture2D = main.bandera_hd("no_existe_zzz")
	ok(falta != null and falta == main.bandera_tex("no_existe_zzz"), "una clave que no existe cae a la X de 96 px sin fallar")
	# la caché no crece sin límite
	var claves := nombres_png("res://banderas_hd")
	for i in mini(40, claves.size()):
		main.bandera_hd(String(claves[i]))
	ok(main.tex_hd.size() <= main.BANDERAS_HD_MAX and main.tex_hd_orden.size() == main.tex_hd.size(), "tras pedir 40 banderas hay %d en memoria (tope %d)" % [main.tex_hd.size(), main.BANDERAS_HD_MAX])
	# la más reciente se queda, la más vieja sale
	var ultima := String(claves[mini(40, claves.size()) - 1])
	ok(main.tex_hd.has(ultima) and not main.tex_hd.has(String(claves[0])), "se queda la última pedida y sale la más vieja")
	# tocar una la vuelve la más nueva
	var vieja: String = String(main.tex_hd_orden[0])
	main.bandera_hd(vieja)
	ok(String(main.tex_hd_orden[main.tex_hd_orden.size() - 1]) == vieja and String(main.tex_hd_orden[0]) != vieja, "usar una bandera la renueva en la caché")
	# coste: cargar una HD
	var t0 := Time.get_ticks_usec()
	for i in 12:
		main.tex_hd.clear()
		main.tex_hd_orden.clear()
		main.bandera_hd(String(claves[i * 30]))
	var ms := float(Time.get_ticks_usec() - t0) / 12000.0
	ok(ms < 15.0, "cargar una bandera HD cuesta %.1f ms" % ms)


func t_licencias() -> void:
	print("[T] ── Sin banderas con licencia CC")
	var cc := ["c_us_ca_san_diego", "c_us_co_denver", "c_us_ia_des_moines", "c_us_mn_rochester", "c_us_ca_escondido", "c_us_ia_red_oak", "c_us_mn_prior_lake", "c_us_oh_germantown", "c_us_pr_san_juan"]
	var restos := []
	for c in cc:
		if FileAccess.file_exists("res://banderas/%s.png" % c) or FileAccess.file_exists("res://banderas_hd/%s.png" % c):
			restos.append(c)
	ok(restos.is_empty(), "no queda ningún PNG de las 9 banderas con licencia CC (quedan: %s)" % str(restos))
	var usadas := []
	for k in main.banderas.get("ciudades", {}):
		if cc.has(String(main.banderas["ciudades"][k])):
			usadas.append(k)
	ok(usadas.is_empty(), "banderas.json no apunta a ninguna de ellas (apuntan: %s)" % str(usadas))
	# toda bandera que el juego referencia existe en las dos carpetas
	var sin := []
	for sec in ["paises", "provincias", "estados", "ciudades"]:
		var d = main.banderas.get(sec, {})
		var vistas := {}
		for k in d:
			var v := String(d[k])
			if v != "" and not vistas.has(v):
				vistas[v] = true
				if not FileAccess.file_exists("res://banderas_hd/%s.png" % v):
					sin.append(v)
	ok(sin.is_empty(), "toda bandera de banderas.json tiene su HD (sin HD: %s)" % str(sin.slice(0, 5)))
	# las 4 ciudades que tenían bandera CC llevan la de su estado (no la X)
	var esperadas := {"San Diego|California": "s_us_ca", "Denver|Colorado": "s_us_co", "Des Moines|Iowa": "s_us_ia", "Rochester|Minnesota": "s_us_mn"}
	var bien := 0
	for k in esperadas:
		if String(main.banderas["ciudades"].get(k, "")) == String(esperadas[k]):
			bien += 1
	ok(bien == 4, "San Diego, Denver, Des Moines y Rochester usan la bandera de su estado (%d de 4)" % bien)
	var vistas_c := 0
	for c in main.mundo.ciudades:
		if esperadas.has("%s|%s" % [c.nombre, main.mundo.provincias[c.provincia].estado] if c.provincia >= 0 else ""):
			ok(c.bandera == String(esperadas["%s|%s" % [c.nombre, main.mundo.provincias[c.provincia].estado]]), "la ciudad %s del juego lleva la bandera %s" % [c.nombre, c.bandera])
			vistas_c += 1
	ok(vistas_c >= 4, "las 4 ciudades existen en el mapa (%d encontradas)" % vistas_c)


func t_panel() -> void:
	print("[T] ── El panel usa la bandera HD")
	var m = main.mundo
	var hud = main.hud
	main._seleccion_pais("Colombia", String(m.paises["Colombia"].continente), Vector2(600.0, 600.0))
	await fotogramas(3)
	var tr: TextureRect = hud.tex_bandera
	ok(tr.get_parent().visible and tr.texture != null and tr.texture.get_width() == 256, "la cabecera del panel muestra la bandera de Colombia en HD (%d px)" % (tr.texture.get_width() if tr.texture else 0))
	ok(tr.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "y su TextureRect usa filtro con mipmaps")
	ok(tr.custom_minimum_size.x >= 72.0, "el recuadro de la bandera mide %.0f×%.0f" % [tr.custom_minimum_size.x, tr.custom_minimum_size.y])
	var antes: Texture2D = tr.texture
	main._seleccion_pais("Japón", String(m.paises["Japón"].continente), Vector2(600.0, 600.0))
	await fotogramas(3)
	ok(tr.texture != antes and tr.texture.get_width() == 256, "al elegir Japón cambia a la de Japón, también HD")
	# una provincia: su bandera (o la del estado/país) también sale HD
	var pi: int = int(m.paises["Japón"].provincias[0])
	main._seleccion_provincia(pi, String(m.paises["Japón"].continente), Vector2(600.0, 600.0))
	await fotogramas(3)
	ok(tr.texture != null and tr.texture.get_width() >= 150, "la provincia de Japón muestra su bandera HD (%d px)" % (tr.texture.get_width() if tr.texture else 0))


func t_aviso_guerra() -> void:
	print("[T] ── El aviso de guerra usa la bandera HD")
	main._asegurar_popup()
	var p = main.popup_guerra
	p._limpiar()
	p._cabecera("Francia", "PRUEBA", "sub", Color(1, 0, 0))
	await fotogramas(2)
	var tr := hallar_textura(p.cuerpo, 200)
	ok(tr != null, "la cabecera del aviso lleva una bandera de 256 px")
	if tr != null:
		ok(tr.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and tr.custom_minimum_size.x >= 96.0, "con filtro de mipmaps y recuadro de %.0f×%.0f" % [tr.custom_minimum_size.x, tr.custom_minimum_size.y])
