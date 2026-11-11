extends Node
## 0.1.8.40/41 · PRUEBAS DE EDIFICIOS Y CORES: catálogo, construir (costo y días), cancelar, órdenes de grupo, cores nacional y cultural,
## ownership (las obras se pierden al conquistar), guardado en la base de datos y los dos escenarios (2026 y año 1).
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
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)


func run() -> void:
	await t_datos()
	await t_modulo()
	await t_cores()
	await t_conquista()
	await t_escenario_1()
	print("[T] ═══ RESULTADO runner83: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


## Una provincia de `pais` con producción alta, para que el costo no sea ridículo.
func prov_de(pais: String) -> int:
	var m = main.mundo
	var mejor := -1
	var mejor_v := -1.0
	for pi in m.paises[pais].provincias:
		var v: float = m.provincias[int(pi)].ingreso_anual_usd()
		if v > mejor_v:
			mejor_v = v
			mejor = int(pi)
	return mejor


# ─────────────────────────────────────────────────────────────
func t_datos() -> void:
	print("[T] ── Catálogo y variables")
	var js = JSON.parse_string(FileAccess.get_file_as_string("res://datos/edificios.json"))
	ok(js is Dictionary and js.get("edificios", []).size() == 109, "datos/edificios.json: 109 edificios")
	var cats := {}
	for c in js["categorias"]:
		cats[c["cod"]] = true
	var slugs := {}
	var todos_ok := true
	for e in js["edificios"]:
		if slugs.has(e["slug"]) or not cats.has(e["cat"]) or not js["clases"].has(e["clase"]) or int(e["max"]) < 1 or String(e["nombre"]) == "":
			todos_ok = false
		slugs[e["slug"]] = true
	ok(todos_ok, "slugs únicos, categoría y clase válidas, máximo ≥ 1, con nombre")
	await arrancar(2026)
	var m = main.mundo
	ok(m.edificios != null and m.edificios.listo, "Mundo.edificios cargado")
	ok(m.cores != null and m.cores.listo, "Mundo.cores cargado")
	ok(m.edificios.n == 109, "109 edificios en el módulo")
	var sin_desc := 0
	for e in m.edificios.n:
		if m.edificios.desc_idx[e] < 0:
			sin_desc += 1
	ok(sin_desc == 0, "los 109 edificios tienen su descubrimiento (sin descubrimiento: %d)" % sin_desc)
	for v in ["edificios", "obras", "num_edificios", "core_nacional", "core_cultural"]:
		ok(m.bd.vars.has(v), "variable «%s» en la base de datos" % v)


func t_modulo() -> void:
	print("[T] ── Construir, costo, días, cancelar")
	var m = main.mundo
	var ed = m.edificios
	var pais: String = "España"
	if not m.paises.has(pais):
		pais = String(m.paises.keys()[0])
	var pi := prov_de(pais)
	ok(pi >= 0, "provincia de %s: %d" % [pais, pi])
	var e_sl: String = "muralla" if ed.indice("muralla") >= 0 else ed.slug[0]
	var e: int = ed.indice(e_sl)
	ok(e >= 0, "edificio de prueba «%s»" % e_sl)
	# sin conocer el descubrimiento no se puede
	m.descubrimientos.quitar(int(m.paises[pais].tid), ed.desc_idx[e])
	var r: Dictionary = ed.puede(pais, pi, e)
	ok(not bool(r["ok"]) and String(r["motivo"]).begins_with("Todavía no conoces"), "sin el descubrimiento no se puede construir: «%s»" % r["motivo"])
	ok(ed.conocidos(pais).find(e) < 0, "conocidos() no incluye lo que no se conoce")
	m.descubrimientos.conceder(int(m.paises[pais].tid), ed.desc_idx[e])
	ok(ed.conocidos(pais).find(e) >= 0, "conocidos() incluye lo que se conoce")
	var costo_u: float = ed.costo_usd(pi, e)
	ok(costo_u > 0.0, "el costo en US$ es positivo (%.0f)" % costo_u)
	var costo_l: float = ed.costo_local(pi, e)
	var por: float = m.divisa_de(pais).por_usd
	ok(absf(costo_l - costo_u * por) < 1e-6 * maxf(1.0, costo_l), "el costo local = US$ × divisa del dueño")
	var tes0: float = m.paises[pais].tesoreria
	var rc: Dictionary = ed.construir(pais, pi, e)
	ok(bool(rc["ok"]), "construir empieza la obra: %s" % rc["msg"])
	ok(absf(m.paises[pais].tesoreria - (tes0 - costo_l)) < 1e-6 * maxf(1.0, costo_l), "se cobra de la tesorería")
	ok(ed.en_obra(pi, e) == 1 and ed.total_obras() >= 1, "la obra queda registrada")
	ok(m.bd.txt("obras", m.provincias[pi].tid).begins_with(e_sl + "@"), "la obra se guarda en la variable `obras`")
	var ob: Array = ed.obras_de(pi)
	ok(ob.size() == 1 and int(ob[0]["falta"]) == ed.dias_de(e), "la obra tarda los días de su clase (%d)" % ed.dias_de(e))
	if ed.tope[e] == 1:
		ok(not bool(ed.puede(pais, pi, e)["ok"]), "no se puede repetir un edificio único mientras está en obra")
	# avanza el tiempo
	ed.fase_dia(ed.dias_de(e) - 1)
	ok(ed.cantidad(pi, e) == 0 and ed.en_obra(pi, e) == 1, "un día antes de terminar sigue en obra")
	ed.fase_dia(1)
	ok(ed.cantidad(pi, e) == 1 and ed.en_obra(pi, e) == 0, "al cumplirse los días el edificio queda construido")
	ok(ed.num_edificios(pi) == 1 and ed.total_pais(pais) >= 1, "num_edificios y el total del país suben")
	ok(m.bd.txt("edificios", m.provincias[pi].tid) == e_sl + ":1", "se guarda en la variable `edificios`")
	ok(ed.terminadas >= 1, "contador de obras terminadas")
	# cancelar
	var e2 := -1
	for k in ed.n:
		if k != e and ed.conoce(pais, k) and ed.tope[k] >= 1 and bool(ed.puede(pais, pi, k)["ok"]):
			e2 = k
			break
	ok(e2 >= 0, "hay otro edificio para probar la cancelación")
	var tes1: float = m.paises[pais].tesoreria
	var rc2: Dictionary = ed.construir(pais, pi, e2)
	var pagado: float = float(rc2["costo"])
	var rcan: Dictionary = ed.cancelar(pi, 0)
	ok(bool(rcan["ok"]) and ed.en_obra(pi, e2) == 0, "cancelar quita la obra")
	ok(absf(m.paises[pais].tesoreria - (tes1 - pagado * 0.5)) < 1e-6 * maxf(1.0, pagado), "cancelar devuelve la mitad")
	ok(not bool(ed.cancelar(pi, 5)["ok"]), "cancelar una obra inexistente falla sin romper nada")
	# no alcanza la tesorería
	var caja: float = m.paises[pais].tesoreria
	m.paises[pais].tesoreria = 0.0
	var rn: Dictionary = ed.construir(pais, pi, e2)
	ok(not bool(rn["ok"]) and String(rn["msg"]).find("tesorería") >= 0, "sin dinero no se construye: «%s»" % rn["msg"])
	m.paises[pais].tesoreria = caja
	# provincia ajena
	var otro := "Francia" if pais != "Francia" else "Alemania"
	if m.paises.has(otro):
		ok(not bool(ed.puede(otro, pi, e2)["ok"]), "no se construye en provincia ajena: «%s»" % ed.puede(otro, pi, e2)["motivo"])
	# dar / quitar (Debug)
	ed.dar(pi, e2, 2)
	ok(ed.cantidad(pi, e2) == 2 and ed.num_edificios(pi) == 3, "Debug: dar edificios")
	ed.quitar(pi, e2, 5)
	ok(ed.cantidad(pi, e2) == 0 and ed.num_edificios(pi) == 1, "Debug: quitar no deja negativos")
	# varias provincias
	var pais_v := pais
	var lista := []
	for k in m.paises[pais_v].provincias:
		lista.append(int(k))
		if lista.size() >= 4:
			break
	var e3: int = ed.indice("muralla") if ed.indice("muralla") >= 0 else e2
	var rv: Dictionary = ed.construir_varias(pais_v, lista, e3)
	ok(int(rv["hechas"]) + (rv["fallos"] as Array).size() == lista.size(), "órdenes de grupo: cada provincia hecha o con motivo (%d hechas, %d fallos)" % [rv["hechas"], (rv["fallos"] as Array).size()])
	ok(ed.obras_en(lista) >= int(rv["hechas"]) - 1, "obras_en() cuenta las obras del grupo")
	for k in lista:
		ed.completar_obras(int(k))
	ok(ed.obras_en(lista) == 0, "completar_obras() las termina todas")
	ok(ed.totales_de(lista).size() >= 1 and ed.total_en(lista) >= int(rv["hechas"]), "totales_de() y total_en() suman lo construido en el grupo (%d)" % ed.total_en(lista))


func t_cores() -> void:
	print("[T] ── Cores nacional y cultural")
	var m = main.mundo
	var cs = m.cores
	var n_nac := 0
	var n_cul := 0
	for pr in m.provincias:
		if cs.nacional(pr.idx) != "":
			n_nac += 1
		if cs.cultural(pr.idx) != "":
			n_cul += 1
	ok(n_nac > m.provincias.size() * 0.7, "la mayoría de las provincias tiene core nacional (%d de %d)" % [n_nac, m.provincias.size()])
	ok(n_cul == m.provincias.size(), "todas tienen core cultural (%d)" % n_cul)
	var pi := prov_de("España" if m.paises.has("España") else String(m.paises.keys()[0]))
	var pais: String = m.provincias[pi].pais
	ok(cs.nacional(pi) == m.provincias[pi].pais_original, "core nacional = país original (%s)" % cs.nacional(pi))
	ok(cs.relacion(pi) == "propia" and cs.es_core_de(pais, pi), "relación «propia» y es_core_de")
	ok(cs.cultural(pi) != "" and cs.etiqueta_cultural(pi) != "—", "core cultural con etiqueta (%s)" % cs.etiqueta_cultural(pi))
	ok(cs.misma_cultura_que_dueno(pi), "la cultura coincide con la del dueño al empezar")
	var rs: Dictionary = cs.resumen_pais(pais)
	ok(int(rs["propias"]) > 0 and int(rs["ajenas"]) == 0, "resumen del país: propias %d, ajenas %d" % [rs["propias"], rs["ajenas"]])
	# editar
	ok(cs.fijar_cultural(pi, "frances") and cs.cultural(pi) == "frances", "Debug: fijar core cultural")
	ok(not cs.fijar_cultural(pi, "no_existe"), "una cultura inexistente se rechaza")
	var otro := "Francia" if pais != "Francia" else "Alemania"
	ok(cs.fijar_nacional(pi, otro) and cs.nacional(pi) == otro and cs.relacion(pi) == "ajena", "Debug: fijar core nacional (relación «ajena»)")
	ok(cs.reclamos_de(otro).has(pi), "reclamos_de(): la provincia aparece en los reclamos del otro país")
	ok(cs.fijar_nacional(pi, "") and cs.relacion(pi) == "libre", "quitar el core nacional (relación «libre»)")
	cs.fijar_nacional(pi, pais)
	cs.fijar_cultural(pi, cs.cultura_del_dueno(pi))
	# los cores sobreviven a la conquista
	var antes: int = main.mundo.bd.historial_de("core_nacional", m.provincias[pi].tid).size()
	ok(antes >= 1, "los cambios de core dejan historial")


func t_conquista() -> void:
	print("[T] ── Conquista: obras perdidas, edificios y cores se quedan")
	var m = main.mundo
	var ed = m.edificios
	var cs = m.cores
	var pais: String = "España" if m.paises.has("España") else String(m.paises.keys()[0])
	var otro: String = "Francia" if pais != "Francia" else "Alemania"
	var pi := prov_de(pais)
	var e: int = ed.indice("muralla") if ed.indice("muralla") >= 0 else 0
	m.descubrimientos.conceder(int(m.paises[pais].tid), ed.desc_idx[e])
	m.paises[pais].tesoreria = 1.0e15
	ed.dar(pi, e, 1)
	var cant_e: int = ed.cantidad(pi, e)
	var e2 := -1
	for k in ed.n:
		if k != e and ed.tope[k] > 1 and ed.conoce(pais, k):
			e2 = k
			break
	if e2 < 0:
		for k in ed.n:
			if k != e and ed.conoce(pais, k):
				e2 = k
				break
	var rc: Dictionary = ed.construir(pais, pi, e2)
	ok(bool(rc["ok"]), "obra empezada antes de la conquista")
	var n_ev0: int = m.eventos.size()
	m.transferir_provincia(pi, otro, "2026,01,01", "Prueba")
	ok(ed.en_obra(pi, e2) == 0, "la obra en curso se pierde al cambiar de dueño")
	ok(ed.cantidad(pi, e) == cant_e and cant_e >= 1, "lo ya construido se queda con la tierra")
	ok(cs.nacional(pi) == pais and cs.relacion(pi) == "ajena", "el core nacional no cambia con la conquista (ahora es «ajena»)")
	ok(m.eventos.size() > n_ev0, "se anota un suceso para el país que perdió la obra")
	ok(ed.puede(pais, pi, e2)["ok"] == false, "el antiguo dueño ya no puede construir ahí")
	m.transferir_provincia(pi, pais, "2026,01,02", "Prueba (devolver)")
	ok(cs.relacion(pi) == "propia", "al recuperarla vuelve a ser «propia»")


func t_escenario_1() -> void:
	print("[T] ── Escenario del año 1")
	await arrancar(1)
	var m = main.mundo
	ok(m.edificios != null and m.edificios.listo and m.cores != null and m.cores.listo, "año 1: edificios y cores cargados")
	var con_core := 0
	var con_cultura := 0
	for pr in m.provincias:
		if m.cores.nacional(pr.idx) != "":
			con_core += 1
		if m.cores.cultural(pr.idx) != "":
			con_cultura += 1
	ok(con_core > 0 and con_cultura == m.provincias.size(), "año 1: cores nacionales (%d) y culturales (%d de %d)" % [con_core, con_cultura, m.provincias.size()])
	var conoce_alguno := false
	var algun_pais := ""
	for nombre in m.paises:
		if m.paises[nombre].provincias.size() > 3 and not m.paises[nombre].inerte:
			if m.edificios.conocidos(nombre).size() > 0:
				conoce_alguno = true
				algun_pais = nombre
				break
	ok(conoce_alguno, "año 1: algún país ya conoce edificios (%s)" % algun_pais)
