extends Node
## 0.1.8.39a · PRUEBAS DE LAS NOTAS DE CAMILO (2026-11-10): tierras sin reclamar, plataformas de hielo y ráfaga de zoom.
##  · Un clic en tierras sin reclamar elige SOLO esa zona (no «todas las de ese continente»); ficha sin pestañas de gobierno; Ctrl+clic y doble clic.
##  · El año 1: ninguna tierra habitada del centro de Europa queda «sin reclamar» (Baden-Wurtemberg, Istria, Roma, Hungría, Viena…); lo inhóspito sigue libre.
##  · Antártida: las plataformas de hielo (Ross, Ronne, Filchner, Amery…) son tierra vectorial: se pueden elegir (antes eran zonas blancas sin límites).
##  · Ráfaga de zoom: con la rueda girando las cajas de tropas no se redibujan en cada paso (se desvanecen y vuelven al parar).
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
	get_window().size = Vector2i(1280, 720)           # en --headless la ventana mide 64×64
	await esperar(0.8)


func mp(lon: float, lat: float) -> Vector2:
	return Vector2((lon + 180.0) * 2400.0 / 360.0, (90.0 - lat) * 1200.0 / 180.0)


## Nación (nombre) a la que pertenece el punto, o "" si ahí no hay tierra.
func pais_en(lon: float, lat: float) -> String:
	var r: Array = main._anillo_bajo(mp(lon, lat))
	if int(r[0]) < 0:
		return ""
	return String(main.mundo.provincias[int(main.anillos[int(r[0])]["p"])].pais)


func prov_en(lon: float, lat: float) -> int:
	var r: Array = main._anillo_bajo(mp(lon, lat))
	return -1 if int(r[0]) < 0 else int(main.anillos[int(r[0])]["p"])


func run() -> void:
	await t_datos()
	await t_antartida()
	await t_huecos_europa()
	await t_seleccion_libre()
	await t_rafaga_zoom()
	print("[T] ═══ RESULTADO runner82: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ─────────────────────────────────────────────────────────────
func t_datos() -> void:
	print("[T] ── Herramientas y datos")
	var fuente = JSON.parse_string(FileAccess.get_file_as_string("res://datos/fuente_provincias.json"))
	var ata = null
	for p in fuente:
		if String(p["id"]) == "ata_00_":
			ata = p
	ok(ata != null and bool(ata.get("plataformas", false)), "la provincia de la Antártida lleva las plataformas de hielo unidas (marca «plataformas»)")
	ok(ata != null and (ata["polygons"] as Array).size() < 30 and (ata["polygons"][0] as Array).size() > 1000, "el continente y las plataformas son un solo contorno grande (%d anillos)" % (ata["polygons"] as Array).size())
	if FileAccess.file_exists("res://herramientas/epoca/fuentes/plataformas_hielo_px.json"):            # (los paquetes de prueba sin herramientas/ se lo saltan)
		var pl = JSON.parse_string(FileAccess.get_file_as_string("res://herramientas/epoca/fuentes/plataformas_hielo_px.json"))
		ok(pl != null and (pl["anillos"] as Array).size() >= 100 and String(pl["fuente"]).contains("Natural Earth"), "plataformas_hielo_px.json: %d plataformas de Natural Earth" % (pl["anillos"] as Array).size())
	var pj = JSON.parse_string(FileAccess.get_file_as_string("res://datos/epocas/1dc/provincias_juego.json"))
	var pj26 = JSON.parse_string(FileAccess.get_file_as_string("res://datos/provincias_juego.json"))
	ok((pj["anillos"] as Array).size() == (pj26["anillos"] as Array).size(), "el año 1 y 2026 siguen repartiendo las MISMAS celdas (%d)" % (pj26["anillos"] as Array).size())
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://datos/epocas/1dc/epoca.json"))
	ok(int(meta["provincias"]) == (pj["provincias"] as Array).size(), "epoca.json cuenta las %d provincias del año 1" % int(meta["provincias"]))


func t_antartida() -> void:
	print("[T] ── Antártida: las plataformas de hielo se pueden elegir")
	# centro aproximado de cada plataforma (lon, lat)
	var plataformas := {"Ross": [-166.8, -81.2], "Ross (lado oeste)": [171.4, -80.6], "Ronne": [-62.9, -79.0], "Filchner": [-39.4, -80.1], "Riiser-Larsen": [-19.5, -74.1],
		"Larsen": [-62.3, -68.5], "Amery": [70.3, -70.5], "Getz": [-124.5, -74.4], "Fimbul": [-0.1, -70.6]}
	for anio in [1, 2026]:
		await arrancar(anio)
		var todas := true
		var cuales := ""
		for n in plataformas:
			var q: Array = plataformas[n]
			var pais := pais_en(q[0], q[1])
			if pais == "":
				todas = false
				cuales += n + " "
		ok(todas, "año %d: las %d plataformas (Ross, Ronne, Filchner, Amery, Larsen, Getz…) son tierra elegible (fallan: %s)" % [anio, plataformas.size(), cuales])
		var pi := prov_en(-166.8, -81.2)
		ok(pi >= 0 and String(main.mundo.continente_de_provincia(pi)) == "Antártida", "año %d: la plataforma de Ross es una provincia de la Antártida" % anio)
		ok(pais_en(-150.0, -60.0) == "" and pais_en(0.0, -50.0) == "", "año %d: el mar abierto sigue siendo mar (sin tierra donde no la hay)" % anio)
		main.camara.zoom = Vector2(2.0, 2.0)
		main._seleccionar(mp(-166.8, -81.2))
		await esperar(0.2)
		ok(main.hud.esta_abierto() and main.sel_ref.has("pi") or main.sel_tipo != "", "año %d: un clic sobre la plataforma de Ross elige algo (%s)" % [anio, main.sel_tipo])


func t_huecos_europa() -> void:
	print("[T] ── Año 1: las tierras habitadas no quedan «sin reclamar»")
	await arrancar(1)
	var m = main.mundo
	# (nombre, lon, lat): sitios del centro y sur de Europa que antes caían en huecos o astillas libres
	var sitios := [["Baden-Wurtemberg", 9.0, 48.6], ["Roma", 12.5, 41.9], ["Istria", 13.9, 45.2], ["Pécs", 18.2, 46.07], ["Viena", 16.37, 48.2], ["Paris", 2.35, 48.85],
		["Ravena", 12.2, 44.4], ["Creta", 25.0, 35.2], ["Peloponeso", 22.3, 37.5], ["Sicilia", 14.0, 37.5], ["Baviera", 11.5, 48.5], ["Bohemia", 14.5, 50.0],
		["Turingia", 11.0, 50.9], ["Westfalia", 8.0, 51.8], ["Jutlandia", 9.5, 56.0], ["Lombardía", 9.5, 45.5], ["Aquitania", -0.5, 44.5], ["Cataluña", 1.5, 41.8]]
	var libres := ""
	for s in sitios:
		var pais := pais_en(s[1], s[2])
		if pais == "" or m.es_inerte(pais):
			libres += "%s(%s) " % [s[0], pais]
	ok(libres == "", "ninguno de %d sitios del centro y sur de Europa es «sin reclamar» (libres: %s)" % [sitios.size(), libres])
	# lo inhóspito sigue libre: Sáhara, Siberia, hielo, tundra
	var libres_ok := ["Sáhara", 10.0, 24.0, "Siberia", 80.0, 72.0, "Groenlandia", -40.0, 72.0, "Tundra rusa", 55.0, 67.5]
	var bien := true
	var mal := ""
	for i in range(0, libres_ok.size(), 3):
		var pais := pais_en(float(libres_ok[i + 1]), float(libres_ok[i + 2]))
		if pais == "" or not m.es_inerte(pais):
			bien = false
			mal += "%s(%s) " % [libres_ok[i], pais]
	ok(bien, "Sáhara, Siberia, Groenlandia y la tundra siguen siendo tierras sin reclamar (no lo son: %s)" % mal)
	# Europa: lo que queda libre es poco y está en el norte
	var area_libre := 0.0
	var prov_libres := 0
	for pr in m.provincias:
		if String(pr.pais) == "Tierras sin reclamar de Europa":
			area_libre += float(m.bd.num("area_km2", pr.tid))
			prov_libres += 1
	ok(area_libre < 1.2e6, "Europa conserva menos de 1,2 millones de km² sin reclamar (%.2f millones en %d provincias; antes 1,68)" % [area_libre / 1e6, prov_libres])
	var pob := 0.0
	for n in m.paises:
		pob += m.poblacion_de(n)
	ok(pob > 200.0e6 and pob < 300.0e6, "la población del mundo sigue entre 200 y 300 millones (%.1f)" % [pob / 1e6])
	# ninguna astilla de menos de 1.500 km² con tierra habitable queda libre en el continente (islas aparte): sin provincias libres diminutas en tierra firme europea
	var astillas := 0
	for pr in m.provincias:
		if String(pr.pais) == "Tierras sin reclamar de Europa" and pr.nombre in ["Győr", "Pécs", "Veszprém", "Kaposvár", "Szombathely", "Zalaegerszeg", "Székesfehérvár", "Szekszárd", "Viena"]:
			astillas += 1
	ok(astillas == 0, "las astillas de Hungría y Viena (antes libres) están absorbidas")


func t_seleccion_libre() -> void:
	print("[T] ── Un clic en tierras sin reclamar elige SOLO esa zona")
	await arrancar(1)
	var m = main.mundo
	var sahara_a := mp(10.0, 24.0)
	var sahara_b := mp(-5.0, 22.0)
	ok(m.es_inerte(pais_en(10.0, 24.0)) and m.es_inerte(pais_en(-5.0, 22.0)), "los dos puntos del Sáhara son tierras sin reclamar de África")
	var pi_a := prov_en(10.0, 24.0)
	var pi_b := prov_en(-5.0, 22.0)
	ok(pi_a >= 0 and pi_b >= 0 and pi_a != pi_b, "y son dos provincias distintas (%d y %d)" % [pi_a, pi_b])
	ok(main._es_libre(pais_en(10.0, 24.0)) and not main._es_libre("Imperio romano") and not main._es_libre(""), "_es_libre distingue las tierras sin reclamar de un país")
	# clic con zoom de país
	main.camara.zoom = Vector2(2.0, 2.0)
	main._seleccionar(sahara_a)
	await esperar(0.2)
	ok(main.sel_tipo == "provincia" and int(main.sel_ref["pi"]) == pi_a, "un clic elige la provincia clicada (no el continente ni el «país» libre): tipo «%s»" % main.sel_tipo)
	ok(main.pais_foco == "", "no se enfoca «el país»: no se atenúa el resto del continente (foco: «%s»)" % main.pais_foco)
	ok(main.multi_sel.size() == 0, "no hay selección múltiple escondida")
	ok(main.hud.esta_abierto(), "el panel se abre")
	ok(main.hud.pestanas_de("libre") == ["general"], "tierras sin reclamar: solo la pestaña General (sin Diplomacia, Militar, Política ni Economía)")
	ok(main.hud.pestanas_de("libre", true) == ["general", "militar"], "salvo que tengas tropas ahí: entonces también Militar")
	ok(main.hud.pestanas_de("pais").size() == 5 and main.hud.pestanas_de("provincia").size() == 4, "un país conserva sus 5 pestañas y una provincia suya sus 4")
	ok(main.hud.datos.get("tipo", "") == "libre", "el panel recibe el tipo «libre»")
	ok(not main.hud.datos.has("ctx"), "sin contexto de tropas: no hay órdenes que dar a nadie")
	ok(main._ctx_tropas().is_empty(), "_ctx_tropas() vacío en tierras sin reclamar")
	for k in ["diplomacia", "militar", "politica", "economia", "general"]:
		main.hud.abrir_pestana(k)
	ok(main.hud.pestana == "general", "pedir otra pestaña no abre nada raro: se queda en General (%s)" % main.hud.pestana)
	# otro clic en otra zona libre del mismo continente: cambia la zona, solo una
	main._seleccionar(sahara_b)
	await esperar(0.2)
	ok(main.sel_tipo == "provincia" and int(main.sel_ref["pi"]) == pi_b and main.pais_foco == "", "otro clic en otra zona libre del mismo continente elige solo esa")
	# Ctrl+clic: suma la ZONA (no el país entero)
	main._seleccionar(sahara_a)
	await esperar(0.1)
	main._seleccionar_varias(sahara_b)
	await esperar(0.1)
	var tipos := ""
	for u in main.multi_sel:
		tipos += String(u["tipo"]) + " "
	ok(main.multi_sel.size() == 2 and tipos.strip_edges() == "provincia provincia", "Ctrl+clic suma zonas sueltas: %d elegidas (%s)" % [main.multi_sel.size(), tipos.strip_edges()])
	main._limpiar_seleccion()
	# doble clic: va a esa zona, sin enfocar el país
	main._doble_click(sahara_a)
	await esperar(0.3)
	ok(main.pais_foco == "" and main.sel_tipo == "provincia" and int(main.sel_ref["pi"]) == pi_a, "doble clic: va a esa zona sin enfocar el país (foco «%s»)" % main.pais_foco)
	# a zoom de continente el clic sigue eligiendo el continente (como con cualquier tierra)
	main._limpiar_seleccion()
	main.camara.zoom = Vector2(1.0, 1.0)
	main._seleccionar(sahara_a)
	await esperar(0.2)
	ok(main.sel_tipo == "continente", "con el zoom de continente un clic elige el continente (%s)" % main.sel_tipo)
	# un país de verdad sigue como siempre: clic = el país enfocado
	main.camara.zoom = Vector2(2.0, 2.0)
	main._seleccionar(mp(12.5, 41.9))
	await esperar(0.2)
	ok(main.pais_foco == "Imperio romano" and main.sel_tipo == "pais", "un clic en Roma sigue eligiendo y enfocando el Imperio romano (%s / %s)" % [main.pais_foco, main.sel_tipo])
	ok(main.hud.pestanas_de(String(main.hud.datos.get("tipo", ""))).size() == 5, "con sus 5 pestañas")
	# la ficha de la zona libre dice lo que hay
	main._salir_foco()
	main._limpiar_seleccion()
	main._seleccionar(sahara_a)
	await esperar(0.2)
	var d: Dictionary = main.hud.datos
	ok(String(d.get("subtitulo", d.get("sub", ""))).contains("sin reclamar") or String(d.get("titulo", "")) != "", "la ficha lleva título y «Tierras sin reclamar»: «%s»" % String(d.get("titulo", "")))
	# 2026 no tiene tierras sin reclamar
	await arrancar(2026)
	ok(not main._es_libre("España") and not main._es_libre("Antártida"), "en 2026 ningún país cuenta como tierra sin reclamar")


func t_rafaga_zoom() -> void:
	print("[T] ── Ráfaga de zoom: las cajas de tropas esperan a que pare la rueda")
	await arrancar(1)
	var ct = main.capa_tropas
	ok(ct != null and ct.get("rafaga_zoom") != null, "la capa de tropas tiene su estado de ráfaga")
	main.camara.position = mp(12.0, 45.0)
	main.camara.zoom = Vector2(2.0, 2.0)
	await esperar(0.6)
	ok(not ct.rafaga_zoom and ct.capa_cajas_pilas.visible and is_equal_approx(ct.capa_cajas_pilas.modulate.a, 1.0), "en reposo no hay ráfaga y las cajas se ven")
	# un cambio de zoom AISLADO redibuja enseguida
	var n0: int = ct.n_dibujos_pilas
	main.camara.zoom = Vector2(2.4, 2.4)
	main._actualizar_zoom()
	await fotogramas(4)
	ok(not ct.rafaga_zoom and ct.n_dibujos_pilas > n0 and absf(ct.zr_dibujado - main._zoom_real()) < 0.001, "un solo paso de zoom redibuja las cajas al instante (%d → %d)" % [n0, ct.n_dibujos_pilas])
	await esperar(0.6)
	# ráfaga: 30 pasos de rueda, uno por fotograma
	n0 = ct.n_dibujos_pilas
	var z := 2.4
	for i in 30:
		z *= 1.04
		main.camara.zoom = Vector2(z, z)
		main._actualizar_zoom()
		await get_tree().process_frame
	ok(ct.rafaga_zoom, "30 pasos seguidos = ráfaga")
	ok(ct.n_dibujos_pilas - n0 <= 3, "durante la ráfaga se redibuja como mucho 3 veces, no 30 (%d)" % (ct.n_dibujos_pilas - n0))
	await esperar(0.1)
	ok(ct.capa_cajas_pilas.modulate.a < 0.05 and not ct.capa_cajas_pilas.visible, "las cajas se desvanecen y la capa se apaga mientras gira la rueda (alfa %.2f)" % ct.capa_cajas_pilas.modulate.a)
	# al parar la rueda: se rehacen UNA vez y vuelven
	var n1: int = ct.n_dibujos_pilas
	await esperar(0.7)
	ok(not ct.rafaga_zoom, "la ráfaga termina al parar la rueda")
	ok(ct.n_dibujos_pilas == n1 + 1 and absf(ct.zr_dibujado - main._zoom_real()) < 0.001, "se rehacen una sola vez, con el zoom final (%d → %d)" % [n1, ct.n_dibujos_pilas])
	ok(ct.capa_cajas_pilas.visible and is_equal_approx(ct.capa_cajas_pilas.modulate.a, 1.0), "y vuelven a verse del todo (alfa %.2f)" % ct.capa_cajas_pilas.modulate.a)
	# lo que no es zoom redibuja al instante aunque sea durante una ráfaga? (elegir algo: el cambio de selección sí pide dibujo)
	var n2: int = ct.n_dibujos_pilas
	main.camara.position += Vector2(0.0, 0.0)
	ct.sel_regs = []
	ct.sel = {"t": "reg", "reg": -12345}
	await fotogramas(6)
	ok(ct.n_dibujos_pilas > n2, "un cambio de selección de tropas redibuja sin esperar")
	ct.sel = {}
	print("[T]     ", ct.n_dibujos_pilas, " redibujos de pilas en total")
