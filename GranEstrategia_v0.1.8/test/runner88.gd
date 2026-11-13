extends Node
## 0.1.8.41 · PRUEBAS DE LOS ICONOS DE EDIFICIOS: los 109 PNG (128 px, con mipmaps, todos distintos, ninguno vacío), uno por edificio de datos/edificios.json,
## y su uso en la ventana Construir (filas y obras en curso) y en la tarjeta «Edificios» del HUD de provincia.
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
	await t_construir()
	await t_hud()
	print("[T] ═══ RESULTADO runner88: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func mp(lon: float, lat: float) -> Vector2:
	return Vector2((lon + 180.0) * 2400.0 / 360.0, (90.0 - lat) * 1200.0 / 180.0)


func prov_en(lon: float, lat: float) -> int:
	var r: Array = main._anillo_bajo(mp(lon, lat))
	return -1 if int(r[0]) < 0 else int(main.anillos[int(r[0])]["p"])


func elegir_provincia(pi: int) -> void:
	main._seleccion_provincia(pi, main.mundo.continente_de_provincia(pi), Vector2(1200.0, 300.0))
	await fotogramas(2)


## Todos los TextureRect que cuelgan de un nodo.
func texturas(n: Node, acc := []) -> Array:
	if n is TextureRect and (n as TextureRect).texture != null:
		acc.append(n)
	for h in n.get_children():
		texturas(h, acc)
	return acc


func t_archivos() -> void:
	print("[T] ── Archivos: iconos/edificios/")
	var ed = main.mundo.edificios
	ok(ed != null and ed.n == 109, "el catálogo tiene 109 edificios (%d)" % ed.n)
	var sin := []
	var tam_mal := []
	var vacios := []
	var sin_mip := []
	var huellas := {}
	var repetidos := []
	for e in ed.n:
		var sl := String(ed.slug[e])
		var t: Texture2D = main.icono("edificios/" + sl)
		if t == null:
			sin.append(sl)
			continue
		var im: Image = t.get_image()
		if im.get_width() != 128 or im.get_height() != 128:
			tam_mal.append(sl)
		if not im.has_mipmaps():
			sin_mip.append(sl)
		var op := 0
		var data := im.get_data()
		for i in range(3, data.size(), 4 * 4):                         # un píxel de cada cuatro basta para saber si hay dibujo
			if data[i] > 40:
				op += 1
		if float(op) / float(data.size() / 16) < 0.25:
			vacios.append(sl)
		var h := hash(data)
		if huellas.has(h):
			repetidos.append("%s = %s" % [sl, huellas[h]])
		huellas[h] = sl
	ok(sin.is_empty(), "los 109 tienen su icono (faltan: %s)" % str(sin))
	ok(tam_mal.is_empty(), "todos de 128×128 (mal: %s)" % str(tam_mal))
	ok(sin_mip.is_empty(), "todos con mipmaps (sin: %s)" % str(sin_mip))
	ok(vacios.is_empty(), "ninguno casi vacío (%s)" % str(vacios))
	ok(repetidos.is_empty(), "ningún dibujo repetido entre dos edificios (%s)" % str(repetidos))
	var en_disco := {}
	for f in DirAccess.get_files_at("res://iconos/edificios"):
		if String(f).ends_with(".png"):
			en_disco[String(f).trim_suffix(".png")] = true
	var extra := []
	for k in en_disco:
		if not ed.idx_de_slug.has(k):
			extra.append(k)
	ok(extra.is_empty() and en_disco.size() == ed.n, "la carpeta tiene exactamente un PNG por edificio (%d en disco, sobran: %s)" % [en_disco.size(), str(extra)])
	ok(main.icono("edificios/no_existe") == null, "un edificio sin icono devuelve null (el juego usa el de su categoría)")
	var t0 := Time.get_ticks_usec()
	for e in ed.n:
		main.icono("edificios/" + String(ed.slug[e]))
	ok(Time.get_ticks_usec() - t0 < 5000, "pedir los 109 ya cargados cuesta %.2f ms (caché)" % (float(Time.get_ticks_usec() - t0) / 1000.0))


## Un edificio conocido por `pais` que todavía se puede construir en `pi` (no está en `excluir`).
func con_cupo(pais: String, pi: int, excluir: Array) -> int:
	var ed = main.mundo.edificios
	for e in ed.conocidos(pais):
		if excluir.find(int(e)) < 0 and bool(ed.puede(pais, pi, int(e))["ok"]):
			return int(e)
	return -1


func t_construir() -> void:
	print("[T] ── Ventana Construir con iconos")
	var m = main.mundo
	var ed = m.edificios
	var pais := "España"
	var pi := prov_en(-3.7, 40.4)
	m.paises[pais].tesoreria = 1.0e15
	await elegir_provincia(pi)
	var t0 := Time.get_ticks_usec()
	main._abrir_construir()
	await fotogramas(2)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("[T] (abrir Construir con los iconos de los 109: %.0f ms)" % ms)
	var w = main.panel_construir
	ok(w != null and is_instance_valid(w), "se abre la ventana")
	ok(w.vf.raiz.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE, "la raíz de la ventana no cambia el filtro (los fondos no pagan mipmaps)")
	var distintos := 0
	var malas := []
	for fl in w._filas:
		var e: int = fl["e"]
		var card: Control = fl["card"]
		var ic: TextureRect = (card.get_child(0) as HBoxContainer).get_child(0) as TextureRect
		if ic.texture != main.icono("edificios/" + String(ed.slug[e])) or ic.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			malas.append(String(ed.slug[e]))
		elif ic.custom_minimum_size.x >= 40.0:
			distintos += 1
	ok(w._filas.size() == 109 and malas.is_empty(), "las 109 filas llevan el icono de su edificio (mal: %s)" % str(malas))
	ok(distintos == 109, "cada icono se pide a 40 px (%d)" % distintos)
	# chips de categoría: el icono se dibuja de verdad (con expand_icon en un botón de ancho automático quedaba de 0 px)
	var chips_mal := []
	for k in w._btns_cat:
		var cb: Button = w._btns_cat[k]
		if String(k) == "":
			continue
		if cb.icon == null or cb.expand_icon or cb.get_combined_minimum_size().x < cb.get_theme_font("font", "Button").get_string_size(cb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, cb.get_theme_font_size("font_size", "Button")).x + 18.0:
			chips_mal.append(String(k))
	ok(w._btns_cat.size() == 9 and chips_mal.is_empty(), "los 8 chips de categoría llevan icono que suma al ancho del botón (mal: %s)" % str(chips_mal))
	# una obra en curso muestra el mismo icono
	var e_obra: int = con_cupo(pais, pi, [])                          # las provincias traen edificios de partida: se busca uno al que aún le quepa otro
	w._construir(e_obra)
	await fotogramas(2)
	w._obras_en_curso()
	ok(ed.obras_en([pi]) > 0 and w._caja_obras.get_child_count() > 0, "hay una obra en curso")
	var primera: Node = w._caja_obras.get_child(0)
	var ic_o: Node = primera.get_child(0) if primera.get_child_count() > 0 else null
	ok(ic_o is TextureRect and (ic_o as TextureRect).texture == main.icono("edificios/" + String(ed.slug[e_obra])), "la fila de la obra lleva el icono de «%s»" % String(ed.nombre[e_obra]))
	main._cerrar_construir()


func t_hud() -> void:
	print("[T] ── Tarjeta «Edificios» del HUD de provincia")
	var m = main.mundo
	var ed = m.edificios
	var pi := prov_en(-3.7, 40.4)
	var sin_obra: Array = []                                         # el edificio de la obra de la prueba anterior no entra (saldría dos veces)
	for e in ed.conocidos("España"):
		if ed.en_obra(pi, int(e)) == 0:
			sin_obra.append(int(e))
	var e1: int = sin_obra[0]
	var e2: int = sin_obra[1]
	ed.dar(pi, e1, 3)
	ed.dar(pi, e2, 1)
	await elegir_provincia(pi)
	var tex := texturas(main.hud.cuerpo)
	var t1: Texture2D = main.icono("edificios/" + String(ed.slug[e1]))
	var t2: Texture2D = main.icono("edificios/" + String(ed.slug[e2]))
	var n1 := 0
	var n2 := 0
	for tr in tex:
		if (tr as TextureRect).texture == t1:
			n1 += 1
		if (tr as TextureRect).texture == t2:
			n2 += 1
	ok(n1 == 1 and n2 == 1, "la lista de construidos pone el icono de cada tipo (%d y %d)" % [n1, n2])
	var lado := 0.0
	for tr in tex:
		if (tr as TextureRect).texture == t1:
			lado = (tr as TextureRect).custom_minimum_size.x
	ok(lado == 22.0, "el icono mide 22 px en la lista (%.0f)" % lado)
	m.paises["España"].tesoreria = 1.0e15
	var e3: int = con_cupo("España", pi, [e1, e2])
	var r: Dictionary = ed.construir("España", pi, e3)
	ok(bool(r["ok"]), "se empieza una obra para ver el icono en «En obra»")
	await elegir_provincia(pi)
	var t3: Texture2D = main.icono("edificios/" + String(ed.slug[e3]))
	var n3 := 0
	for tr in texturas(main.hud.cuerpo):
		if (tr as TextureRect).texture == t3:
			n3 += 1
	ok(n3 >= 1, "la obra en curso también lleva su icono (%d)" % n3)
