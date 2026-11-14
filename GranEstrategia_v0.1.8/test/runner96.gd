extends Node
## 0.1.8.43 · PRUEBAS DE SUBPROVINCIAS (geoBoundaries ADM2, CC BY 4.0): archivos y formato, recorte por provincia (suma de fracciones, iso, cobertura, orden), caché y
## coste, punto dentro, capa del mapa (límites, hover, elegir), ficha (botones y lista), doble clic, crédito en INFORMACIÓN y el escenario de 1 d. C.
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


func mp(lon: float, lat: float) -> Vector2:
	return Vector2((lon + 180.0) * 2400.0 / 360.0, (90.0 - lat) * 1200.0 / 180.0)


func prov_en(lon: float, lat: float) -> int:
	var r: Array = main._anillo_bajo(mp(lon, lat))
	return -1 if int(r[0]) < 0 else int(main.anillos[int(r[0])]["p"])


func arrancar(anio: int) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await esperar(0.3)
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	if anio != 2026:
		Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": anio})
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)
	main._poner_velocidad(0)


func textos(n: Node, acu: Array) -> void:
	if n is Label:
		acu.append((n as Label).text)
	if n is Button:
		acu.append((n as Button).text)
	for h in n.get_children():
		textos(h, acu)


func hay(raiz: Node, frag: String) -> bool:
	var t: Array = []
	textos(raiz, t)
	for x in t:
		if String(x).to_upper().contains(frag.to_upper()):
			return true
	return false


func cobertura(pi: int, lista: Array) -> float:
	var suma := 0.0
	for d in lista:
		for pz in d["piezas"]:
			suma += absf(main.subprov._area(pz))
	var prov_px: float = main.territorio.area_provincia(pi)
	return suma / maxf(prov_px, 1.0e-9)


func run() -> void:
	await arrancar(2026)
	var sp
	var js = JSON.parse_string(FileAccess.get_file_as_string("res://datos/subprov/nombres.json"))
	ok(main.subprov_hay(), "hay datos de subprovincias en datos/subprov")
	ok(typeof(js) == TYPE_DICTIONARY and int(js["unidades"]) > 45000 and js["isos"].size() > 190, "nombres.json: %d unidades en %d países" % [int(js["unidades"]), js["isos"].size()])
	ok(String(js["fuente"]).contains("geoBoundaries") and String(js["licencia"]).contains("CC BY 4.0"), "el archivo lleva la fuente y la licencia")
	var cuenta := 0
	for iso in js["nombres"]:
		cuenta += (js["nombres"][iso] as Array).size()
	ok(cuenta == int(js["unidades"]), "la suma de nombres por país coincide con las unidades (%d)" % cuenta)
	ok(main.subprov == null, "al cargar el mundo NO se carga nada de subprovincias (todo es bajo demanda)")
	var pm := prov_en(-3.7, 40.4)
	ok(pm >= 0 and String(main.mundo.provincias[pm].pais) == "España", "Madrid es una provincia de España (%d)" % pm)
	ok(main.mostrar_subprovincias(pm), "mostrar_subprovincias(Madrid) → true")
	sp = main.subprov
	ok(sp != null and sp.listo, "el índice se cargó al abrir (%d palabras de índice)" % sp._ent.size())
	var lista: Array = sp.de_provincia(pm)
	ok(lista.size() >= 1, "Madrid tiene %d subprovincias (%.0f ms)" % [lista.size(), sp.ultimo_ms])
	var f := 0.0
	var ordenada := true
	var nombres_ok := true
	var iso_ok := true
	for i in lista.size():
		var d: Dictionary = lista[i]
		f += float(d["frac"])
		if i > 0 and float(d["km2"]) > float(lista[i - 1]["km2"]) + 1.0e-6:
			ordenada = false
		if String(d["nombre"]) == "":
			nombres_ok = false
		if String(d["iso"]) != "ESP":
			iso_ok = false
	ok(absf(f - 1.0) < 1.0e-6, "las fracciones suman 1 (%.6f)" % f)
	ok(ordenada, "ordenadas de mayor a menor superficie")
	ok(nombres_ok and iso_ok, "todas con nombre y del país ESP (la mayor: %s)" % String(lista[0]["nombre"]))
	var cob := cobertura(pm, lista)
	ok(cob > 0.80 and cob < 1.05, "las piezas cubren %.0f %% de la provincia (el resto es costa que no coincide)" % (cob * 100.0))
	var centros_ok := true
	for i in lista.size():
		if sp.en_punto(pm, lista[i]["centro"]) != i:
			centros_ok = false
	ok(centros_ok, "en_punto(centro de cada subprovincia) devuelve esa subprovincia")
	ok(sp.en_punto(pm, mp(-100.0, 0.0)) == -1, "un punto fuera de la provincia no cae en ninguna")
	ok(sp.calculada(pm) and sp.de_provincia(pm) == lista, "la segunda llamada sale de la caché (misma lista)")
	var t0 := Time.get_ticks_usec()
	for k in 200:
		sp.de_provincia(pm)
	ok(float(Time.get_ticks_usec() - t0) / 200.0 < 100.0, "una consulta en caché cuesta %.1f µs" % (float(Time.get_ticks_usec() - t0) / 200.0))
	# otros países y tamaños
	var casos := [["Francia", -2.0, 47.0, "FRA"], ["EE. UU.", -98.0, 39.0, "USA"], ["Rusia", 90.0, 62.0, "RUS"], ["Brasil", -50.0, -10.0, "BRA"], ["Australia", 134.0, -25.0, "AUS"], ["Islandia", -19.0, 64.9, "ISL"], ["Japón", 138.0, 36.0, "JPN"]]
	var max_ms := 0.0
	for c in casos:
		var pi := prov_en(float(c[1]), float(c[2]))
		if pi < 0:
			ok(false, "%s: hay provincia en (%.0f, %.0f)" % [c[0], c[1], c[2]])
			continue
		var l: Array = sp.de_provincia(pi)
		max_ms = maxf(max_ms, sp.ultimo_ms)
		var suma := 0.0
		for d in l:
			suma += float(d["frac"])
		var iso_mayor := String(l[0]["iso"]) if l.size() > 0 else "—"
		ok(l.size() >= 1 and absf(suma - 1.0) < 1.0e-6 and iso_mayor == String(c[3]), "%s (%s): %d subprovincias, la mayor es %s de %s, cobertura %.0f %% (%.0f ms)" % [c[0], main.mundo.provincias[pi].nombre, l.size(), String(l[0]["nombre"]) if l.size() > 0 else "—", iso_mayor, cobertura(pi, l) * 100.0, sp.ultimo_ms])
	ok(max_ms < 1500.0, "la provincia más cara tardó %.0f ms (carga del país incluida)" % max_ms)
	# muestra de provincias de Europa: tiempos y caché acotada
	var tot_ms := 0.0
	var n_med := 0
	var mx := 0.0
	for pi in range(0, main.mundo.provincias.size(), 61):
		if main.mundo.provincias[pi].pais == "":
			continue
		var l: Array = sp.de_provincia(pi)
		tot_ms += sp.ultimo_ms
		mx = maxf(mx, sp.ultimo_ms)
		n_med += 1
	ok(n_med > 100 and mx < 1500.0, "%d provincias del mundo: media %.1f ms, peor %.0f ms" % [n_med, tot_ms / float(maxi(n_med, 1)), mx])
	ok(sp._cache.size() <= sp.CACHE_MAX and sp._paises.size() <= sp.PAISES_MAX, "la caché está acotada (%d provincias, %d países en memoria)" % [sp._cache.size(), sp._paises.size()])
	# capa del mapa
	main.mostrar_subprovincias(pm)
	var capa = main.capa_sub
	ok(capa != null and capa.activa() and capa.pi == pm, "la capa queda abierta en Madrid")
	await fotogramas(2)                                       # los nodos de la apertura anterior se liberan al final del fotograma
	var mallas := 0
	for h in capa.get_children():
		if h is MeshInstance2D:
			mallas += 1
	ok(mallas == 3, "los límites internos son una malla en 3 copias del mundo (%d)" % mallas)
	var mat: ShaderMaterial = main._material_seleccion("sub")
	ok(mat != null and main.mats_sel.has("sub") and float(mat.get_shader_parameter("half_width")) > 0.0, "la línea de las subprovincias usa el material de grosor fijo en pantalla")
	var cen: Vector2 = lista[0]["centro"]
	capa.mover(cen, Vector2(300.0, 200.0))
	ok(capa.hover == 0 and capa._panel.visible and capa._etiqueta.text.contains(String(lista[0]["nombre"])), "con el cursor encima se resalta y se rotula: «%s»" % capa._etiqueta.text.replace("\n", " · "))
	ok(capa._nodos_hover.size() > 0, "el resaltado del cursor tiene relleno (%d nodos)" % capa._nodos_hover.size())
	ok(capa.elegir(cen) and capa.elegida == 0 and capa._nodos_elegida.size() > 0, "un clic dentro elige la subprovincia")
	capa.elegir_indice(0)
	ok(capa.elegida == -1, "elegir la misma otra vez la suelta")
	capa.mover(mp(-100.0, 0.0), Vector2(10.0, 10.0))
	ok(capa.hover == 0, "el cursor se prueba como mucho cada 40 ms (una prueba inmediata se salta)")
	OS.delay_msec(50)
	capa.mover(mp(-100.0, 0.0), Vector2(10.0, 10.0))
	ok(capa.hover == -1 and not capa._panel.visible, "con el cursor fuera la etiqueta se esconde")
	# ficha
	main._limpiar_seleccion()
	ok(not capa.activa(), "elegir otra cosa cierra las subdivisiones")
	main._seleccion_provincia(pm, main.mundo.continente_de_provincia(pm), Vector2(1200.0, 300.0))
	await fotogramas(2)
	main.hud.abrir_pestana("general")
	await fotogramas(2)
	ok(hay(main.hud.cuerpo, "SUBDIVISIONES") and hay(main.hud.cuerpo, "Ver subdivisiones en el mapa"), "la ficha de la provincia ofrece «Ver subdivisiones en el mapa»")
	ok(hay(main.hud.cuerpo, "geoBoundaries") or hay(main.hud.cuerpo, "límites administrativos actuales"), "… y avisa de que los límites son los actuales")
	main.mostrar_subprovincias(pm)
	await fotogramas(2)
	ok(hay(main.hud.cuerpo, "Ocultar subdivisiones") and hay(main.hud.cuerpo, String(lista[0]["nombre"])), "abiertas, la ficha lista las subprovincias y ofrece ocultarlas")
	ok(hay(main.hud.cuerpo, "geoBoundaries (William & Mary geoLab), CC BY 4.0"), "la ficha cita la fuente y la licencia")
	main.elegir_subprovincia(0)
	await fotogramas(2)
	ok(hay(main.hud.cuerpo, "Población estimada") and hay(main.hud.cuerpo, "Superficie"), "al elegir una, la ficha muestra superficie y población estimada")
	main.ocultar_subprovincias()
	await fotogramas(2)
	ok(not main.capa_sub.activa() and hay(main.hud.cuerpo, "Ver subdivisiones en el mapa"), "Ocultar vuelve a dejar el botón de abrir")
	# doble clic
	main._enfocar_pais("España", false)
	await fotogramas(2)
	main._doble_click(mp(-3.7, 40.4))
	await fotogramas(2)
	ok(main.capa_sub.activa() and main.capa_sub.pi == pm, "el doble clic en una provincia de un país enfocado abre sus subdivisiones")
	var otro := prov_en(2.17, 41.39)
	main._seleccionar(mp(2.17, 41.39))
	await fotogramas(2)
	ok(not main.capa_sub.activa(), "un clic en otra provincia cierra las subdivisiones (pi=%d → %d)" % [pm, otro])
	main._salir_foco()
	# crédito en INFORMACIÓN
	var esc0 := InputEventKey.new()
	esc0.keycode = KEY_ESCAPE
	esc0.pressed = true
	main._unhandled_input(esc0)
	for b in main.menu_contenido.get_children():
		if b is Button and (b as Button).text == "OPCIONES":
			(b as Button).pressed.emit()
	for b in main.menu_contenido.get_children():
		if b is Button and (b as Button).text == "INFORMACIÓN":
			(b as Button).pressed.emit()
	ok(hay(main.menu_contenido, "geoBoundaries (William & Mary geoLab), CC BY 4.0"), "INFORMACIÓN cita a geoBoundaries (William & Mary geoLab), CC BY 4.0")
	main._reanudar_juego()
	# 1 d. C.
	await arrancar(1)
	var roma := prov_en(12.5, 41.9)
	ok(roma >= 0, "1 d. C.: hay provincia en Roma (%s)" % main.mundo.provincias[roma].nombre)
	ok(main.mostrar_subprovincias(roma), "1 d. C.: la provincia de Roma abre sus subdivisiones")
	var lr: Array = main.subprov.de_provincia(roma)
	var s2 := 0.0
	var itas := 0
	for d in lr:
		s2 += float(d["frac"])
		if String(d["iso"]) == "ITA":
			itas += 1
	ok(lr.size() >= 2 and absf(s2 - 1.0) < 1.0e-6 and itas >= 1, "1 d. C.: %d subprovincias (límites actuales: %s…), %.0f ms" % [lr.size(), String(lr[0]["nombre"]), main.subprov.ultimo_ms])
	var antartida := -1
	for pi in main.mundo.provincias.size():
		if String(main.mundo.provincias[pi].nombre).begins_with("Antártida") or String(main.mundo.provincias[pi].pais).begins_with("Antártida"):
			antartida = pi
			break
	if antartida >= 0:
		var la: Array = main.subprov.de_provincia(antartida)
		ok(la is Array, "una provincia sin unidades (Antártida) devuelve lista vacía sin fallar (%d)" % la.size())
		main.mostrar_subprovincias(antartida)
		await fotogramas(2)
		ok(main.subprov_estado(antartida)["sin_datos"] == (la.size() == 0), "la ficha sabe si no hay datos")
	print("[T] ═══ RESULTADO runner96: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)
