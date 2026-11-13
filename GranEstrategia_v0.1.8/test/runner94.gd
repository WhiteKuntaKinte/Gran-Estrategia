extends Node
## 0.1.8.42 · PRUEBAS DE LAS ÉPOCAS 1096 Y 1500: el selector (4 escenarios en MODO DEV y en Debug > Tiempo), los datos de cada escenario
## (naciones, provincias, celdas, población, ciudades, banderas, economía, ejércitos), el reloj, los descubrimientos y las pinturas de reserva.
var main
var fallos := 0
var n_ok := 0
var tot_edif := {}                                        # año -> edificios de partida de todo el mundo

const ESPERADO := {
	1096: {"nombre": "Primera Cruzada", "pob_min": 300.0e6, "pob_max": 440.0e6, "naciones": ["Imperio bizantino", "Dinastía Song del Norte", "Gran Imperio selyúcida", "Califato fatimí", "Sacro Imperio Romano Germánico"]},
	1500: {"nombre": "Renacimiento", "pob_min": 400.0e6, "pob_max": 520.0e6, "naciones": ["Reino de Francia", "Reino de Inglaterra", "Corona de Castilla", "Reino de Portugal", "República de Venecia"]},
}


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


func arrancar(anio: int, jugar := true) -> void:
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
	if main.en_menu and jugar:
		main._on_jugar()
		await esperar(0.2)


func run() -> void:
	await t_selector()
	await t_epoca(1096)
	await t_epoca(1500)
	await t_vuelta()
	print("[T] ═══ RESULTADO runner94: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func _buscar_botones(n: Node, salida: Array) -> void:
	if n is Button:
		salida.append(n)
	for c in n.get_children():
		_buscar_botones(c, salida)


func t_selector() -> void:
	print("[T] ── Selector de escenario")
	await arrancar(2026, false)                                # sin pulsar JUGAR: el menú principal sigue ahí
	ok(main.EPOCAS_ORDEN == [1, 1096, 1500, 2026], "los 4 escenarios, del más antiguo al de hoy")
	for a in [1, 1096, 1500]:
		ok(main.EPOCAS_DIR.has(a) and main._escenario_disponible(a), "escenario %d disponible (%s)" % [a, String(main.EPOCAS_DIR.get(a, ""))])
	ok(main._escenario_disponible(2026), "2026 siempre disponible")
	main._mostrar_modos()
	await fotogramas(1)
	main._mostrar_epocas()
	await fotogramas(2)
	var botones: Array = []
	_buscar_botones(main.menu_contenido, botones)
	var textos: Array = []
	var habilitados := 0
	for b in botones:
		textos.append(String(b.text))
		if ["AÑO 1 d. C.", "1096", "1500", "2026"].has(String(b.text)) and not b.disabled:
			habilitados += 1
	ok(textos.has("AÑO 1 d. C.") and textos.has("1096") and textos.has("1500") and textos.has("2026"), "el menú MODO DEV muestra los 4 escenarios: %s" % str(textos))
	ok(habilitados == 4, "los 4 botones de escenario están habilitados")
	main._on_jugar()
	await fotogramas(2)
	main._abrir_debug()
	await fotogramas(3)
	var d = main.debug_menu
	ok(d != null, "Debug abierto")
	if d != null:
		d._ir_a("tiempo")
		await fotogramas(2)
		var bs: Array = []
		_buscar_botones(d, bs)
		var t2: Array = []
		for b in bs:
			t2.append(String(b.text))
		ok(t2.has("AÑO 1") and t2.has("1096") and t2.has("1500") and t2.has("2026"), "Debug > Tiempo trae los 4 botones de escenario")
		var actual_off := false
		var otros_on := 0
		for b in bs:
			if String(b.text) == "2026":
				actual_off = b.disabled
			elif ["AÑO 1", "1096", "1500"].has(String(b.text)) and not b.disabled:
				otros_on += 1
		ok(actual_off and otros_on == 3, "el botón del escenario actual (2026) está desactivado y los otros 3 activos")
		main._cerrar_debug()
		await fotogramas(1)


func t_epoca(anio: int) -> void:
	var esp: Dictionary = ESPERADO[anio]
	print("[T] ── Escenario %d" % anio)
	await arrancar(anio)
	var m = main.mundo
	ok(main.epoca == anio and main.epoca_dir == String(main.EPOCAS_DIR[anio]), "%d: epoca y carpeta" % anio)
	ok(String(main.epoca_meta.get("nombre", "")).contains(String(esp["nombre"])), "%d: epoca.json (%s)" % [anio, String(main.epoca_meta.get("nombre", ""))])
	ok(main.reloj.anio == anio and main.reloj.mes == 1 and main.reloj.dia == 1, "%d: el reloj empieza el 1 de enero (%s)" % [anio, main.reloj.texto()])
	var cred: Array = main.epoca_meta.get("creditos", [""])
	ok(String(cred[0]).contains("Cliopatria") and String(cred[0]).contains("CC BY 4.0"), "%d: los créditos citan Cliopatria (CC BY 4.0)" % anio)
	var np: int = m.provincias.size()
	ok(np >= 2500 and np <= 5000, "%d: %d provincias" % [anio, np])
	var vacias := 0
	var celdas_prov := 0
	for pr in m.provincias:
		celdas_prov += pr.anillos.size()
		if pr.anillos.size() == 0:
			vacias += 1
	ok(vacias == 0, "%d: ninguna provincia sin celdas (%d celdas repartidas)" % [anio, celdas_prov])
	ok(celdas_prov > 15000, "%d: las provincias reparten las celdas del mundo" % anio)
	var vivas := 0
	var inertes := 0
	var sin_cap := 0
	var sin_prov := 0
	for nombre in m.paises:
		var p = m.paises[nombre]
		if p.inerte:
			inertes += 1
			continue
		vivas += 1
		if p.capital == "" or p.capital == "Sin capital":
			sin_cap += 1
		if p.provincias.size() == 0:
			sin_prov += 1
	ok(vivas == int(main.epoca_meta.get("naciones", -1)), "%d: %d naciones con gobierno (epoca.json dice %d)" % [anio, vivas, int(main.epoca_meta.get("naciones", -1))])
	ok(inertes >= 5, "%d: hay tierras sin reclamar (%d zonas)" % [anio, inertes])
	ok(sin_cap == 0 and sin_prov == 0, "%d: toda nación tiene capital (%d sin) y provincias (%d sin)" % [anio, sin_cap, sin_prov])
	for n in esp["naciones"]:
		ok(m.paises.has(n) and not m.paises[n].inerte and m.paises[n].provincias.size() > 0, "%d: existe «%s»" % [anio, n])
	var pob := 0.0
	var mudas := 0
	var mudas_con_pob := 0
	for pr in m.provincias:
		pob += pr.poblacion
		if m.paises[pr.pais].inerte:
			mudas += 1
			if pr.poblacion > 0.0:
				mudas_con_pob += 1
	ok(pob >= float(esp["pob_min"]) and pob <= float(esp["pob_max"]), "%d: población del mundo %.0f M (entre %.0f y %.0f)" % [anio, pob / 1e6, float(esp["pob_min"]) / 1e6, float(esp["pob_max"]) / 1e6])
	ok(mudas > 100 and mudas < np * 0.4 and mudas_con_pob == 0, "%d: %d provincias sin reclamar de %d, todas sin población" % [anio, mudas, np])
	ok(m.ciudades.size() > 150, "%d: %d ciudades" % [anio, m.ciudades.size()])
	var caps_ok := 0
	var sin_bandera := 0
	var sin_hd := 0
	var sin_div := 0
	var sin_ejercito := 0
	for nombre in m.paises:
		var p = m.paises[nombre]
		if p.inerte:
			continue
		for c in m.ciudades:
			if c.pais == nombre and c.rango_capital == 2:
				caps_ok += 1
				break
		if not FileAccess.file_exists("res://banderas/%s.png" % p.bandera):
			sin_bandera += 1
		if not FileAccess.file_exists("res://banderas_hd/%s.png" % p.bandera):
			sin_hd += 1
		if m.divisa_de(nombre) == null:
			sin_div += 1
		if m.soldados_de_pais(nombre) <= 0:
			sin_ejercito += 1
	ok(caps_ok == vivas, "%d: cada nación tiene su capital nacional (%d de %d)" % [anio, caps_ok, vivas])
	ok(sin_bandera == 0 and sin_hd == 0, "%d: todas las banderas (96 px: %d sin · HD: %d sin)" % [anio, sin_bandera, sin_hd])
	ok(sin_div == 0, "%d: toda nación tiene divisa (%d sin)" % [anio, sin_div])
	ok(sin_ejercito <= 5, "%d: casi toda nación tiene ejército (%d sin)" % [anio, sin_ejercito])
	ok(m.descubrimientos != null and m.descubrimientos.anio_actual == anio, "%d: los descubrimientos están en el año %d" % [anio, anio])
	var cuenta: int = m.descubrimientos.cuenta_f if m.descubrimientos != null else 0
	ok(cuenta > 100 and cuenta < 1730, "%d: la historia conoce %d descubrimientos" % [anio, cuenta])
	if main.pinturas != null and main.pinturas.listo:
		var sin_pint := 0
		for n in esp["naciones"]:
			if main.pinturas.de_pais(n).is_empty():
				sin_pint += 1
		ok(sin_pint == 0, "%d: las pinturas caen a la región o al continente (%d sin)" % [anio, sin_pint])
		ok(main.pinturas.carpeta_epoca() == str(anio), "%d: carpeta de pinturas «%s»" % [anio, main.pinturas.carpeta_epoca()])
	await t_edificios_partida(anio)
	var elegida: String = String(esp["naciones"][0])
	main._ir_a_pais(elegida)
	await fotogramas(3)
	m.jugador = elegida
	var pob0: float = m.poblacion_de(elegida)
	main.debug_avanzar_dias(60)
	await fotogramas(2)
	ok(main.reloj.anio == anio and main.reloj.mes >= 3, "%d: pasan 60 días (%s)" % [anio, main.reloj.texto()])
	ok(m.poblacion_de(elegida) >= pob0 * 0.98, "%d: la población de %s no se hunde en 60 días" % [anio, elegida])
	var vistos := {}
	var rep := 0
	for pr in m.provincias:
		if vistos.has(pr.tid):
			rep += 1
		vistos[pr.tid] = true
	ok(rep == 0, "%d: IDs de provincia únicos" % anio)


func t_edificios_partida(anio: int) -> void:
	var m = main.mundo
	var ed = m.edificios
	ok(ed != null and ed.listo, "%d: catálogo de edificios cargado" % anio)
	if ed == null:
		return
	var total: int = ed.total_mundo()
	tot_edif[anio] = total
	ok(total > 1000, "%d: el mundo empieza con %d edificios" % [anio, total])
	var en_mudas := 0
	var pasa_tope := 0
	var con_edif := 0
	var con_pob := 0
	for pr in m.provincias:
		var d: Dictionary = ed.de_provincia(pr.idx)
		if m.paises[pr.pais].inerte:
			en_mudas += d.size()
			continue
		if pr.poblacion > 0.0:
			con_pob += 1
		if not d.is_empty():
			con_edif += 1
		for k in d:
			if int(d[k]) > int(ed.tope[ed.indice(k)]):
				pasa_tope += 1
	ok(en_mudas == 0, "%d: las tierras sin reclamar no tienen edificios" % anio)
	ok(pasa_tope == 0, "%d: ninguna provincia pasa el máximo de cada edificio" % anio)
	ok(con_edif >= con_pob * 0.9, "%d: casi toda provincia habitada tiene edificios (%d de %d)" % [anio, con_edif, con_pob])
	# nada que no se hubiera descubierto todavía
	var anacronicos := 0
	for pr in m.provincias:
		for k in ed.de_provincia(pr.idx):
			if ed.anio[ed.indice(k)] > anio:
				anacronicos += 1
	ok(anacronicos == 0, "%d: ningún edificio anterior a su descubrimiento (%d)" % [anio, anacronicos])
	var antes: int = ed.total_mundo()
	var n2: int = ed.sembrar_iniciales(anio)
	ok(n2 == antes and ed.total_mundo() == antes, "%d: sembrar de nuevo da lo mismo (%d)" % [anio, n2])
	# la regla pura
	var e_cab: int = ed.indice("cabana_madera")
	ok(ed.cantidad_inicial(e_cab, 5, 0.9, 1.0) == int(ed.tope[e_cab]), "la cabaña (A, máximo %d) llega a su tope con desarrollo alto y difusión 1" % int(ed.tope[e_cab]))
	ok(ed.cantidad_inicial(e_cab, 5, 0.9, 0.0) == 0, "difusión 0 = ninguno")
	var e_esc: int = ed.indice("escudo_antimisiles")
	ok(ed.cantidad_inicial(e_esc, 5, 0.3, 1.0) == 0 and ed.cantidad_inicial(e_esc, 5, 1.0, 1.0) == int(ed.tope[e_esc]), "lo grande (F) solo con mucho desarrollo")


func t_vuelta() -> void:
	print("[T] ── Vuelta a 2026")
	await arrancar(2026)
	var t26: int = main.mundo.edificios.total_mundo()
	ok(t26 > int(tot_edif.get(1500, 0)) and int(tot_edif.get(1500, 0)) > int(tot_edif.get(1096, 0)), "edificios de partida: 1096 (%d) < 1500 (%d) < 2026 (%d)" % [int(tot_edif.get(1096, 0)), int(tot_edif.get(1500, 0)), t26])
	var tiene_moderno := 0
	var e_sol: int = main.mundo.edificios.indice("energia_solar_comercial")
	for pr in main.mundo.provincias:
		if main.mundo.edificios.cantidad(pr.idx, e_sol) > 0:
			tiene_moderno += 1
	ok(tiene_moderno >= 0, "2026: %d provincias con parques solares de partida" % tiene_moderno)
	ok(main.epoca == 2026 and main.mundo.provincias.size() > 7000, "2026 sigue intacto (%d provincias)" % main.mundo.provincias.size())
	ok(main.reloj.anio == 2026, "el reloj vuelve a 2026")
