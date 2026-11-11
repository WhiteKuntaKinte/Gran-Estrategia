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
	if main.en_menu:
		main._on_jugar()                                      # sin escenario pedido la partida empieza en el menú: se juega a mano
		await esperar(0.2)


func run() -> void:
	await t_datos()
	await t_modulo()
	await t_cores()
	await t_conquista()
	await t_hud()
	await t_ventana()
	await t_grupo()
	await t_debug()
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
	ok(ed.en_obra(pi, e) == 1 and ed.obras_en([pi]) >= 1, "la obra queda registrada")
	ok(m.bd.txt("obras", m.provincias[pi].tid).begins_with(e_sl + "@"), "la obra se guarda en la variable `obras`")
	var ob: Array = ed.obras_de(pi)
	ok(ob.size() == 1 and int(ob[0]["falta"]) == ed.dias_de(e), "la obra tarda los días de su clase (%d)" % ed.dias_de(e))
	if ed.tope[e] == 1:
		ok(not bool(ed.puede(pais, pi, e)["ok"]), "no se puede repetir un edificio único mientras está en obra")
	# avanza el tiempo
	ed.fase_obras(ed.dias_de(e) - 1)
	ok(ed.cantidad(pi, e) == 0 and ed.en_obra(pi, e) == 1, "un día antes de terminar sigue en obra")
	ed.fase_obras(1)
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
	# lo mismo, provincia por provincia (total_en y totales_de leen las columnas directo)
	var suma_n := 0
	var suma_d := {}
	for k in lista:
		suma_n += ed.num_edificios(int(k))
		var dk: Dictionary = ed.de_provincia(int(k))
		for sl in dk:
			suma_d[sl] = int(suma_d.get(sl, 0)) + int(dk[sl])
	ok(ed.total_en(lista) == suma_n and ed.totales_de(lista) == suma_d and ed.total_pais(pais_v) == ed.total_en(m.paises[pais_v].provincias),
		"total_en, totales_de y total_pais dan lo mismo que sumar provincia por provincia (%d)" % suma_n)


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
	ok(cs.relacion(pi) == "propia", "relación «propia»")
	ok(cs.cultural(pi) != "" and cs.etiqueta_cultural(pi) != "—", "core cultural con etiqueta (%s)" % cs.etiqueta_cultural(pi))
	ok(cs.misma_cultura_que_dueno(pi), "la cultura coincide con la del dueño al empezar")
	var n_propias := 0
	var n_ajenas := 0
	for pj in m.paises[pais].provincias:
		match cs.relacion(int(pj)):
			"propia":
				n_propias += 1
			"ajena":
				n_ajenas += 1
	ok(n_propias > 0 and n_ajenas == 0, "las provincias del país: propias %d, ajenas %d" % [n_propias, n_ajenas])
	# editar
	ok(cs.fijar_cultural(pi, "frances") and cs.cultural(pi) == "frances", "Debug: fijar core cultural")
	ok(not cs.fijar_cultural(pi, "no_existe"), "una cultura inexistente se rechaza")
	var otro := "Francia" if pais != "Francia" else "Alemania"
	ok(cs.fijar_nacional(pi, otro) and cs.nacional(pi) == otro and cs.relacion(pi) == "ajena", "Debug: fijar core nacional (relación «ajena»)")
	ok(cs.reclamos_de(otro).has(pi), "reclamos_de(): la provincia aparece en los reclamos del otro país")
	ok(cs.fijar_nacional(pi, "") and cs.relacion(pi) == "libre", "quitar el core nacional (relación «libre»)")
	var pj2 := -1
	for pj in m.paises[pais].provincias:
		if int(pj) != pi:
			pj2 = int(pj)
			break
	ok(pj2 >= 0 and cs.fijar_nacional(pj2, otro) and cs.relacion(pj2) == "ajena", "otra provincia con core ajeno (para la cuenta)")
	var cuenta: Dictionary = cs.contar(m.paises[pais].provincias)
	var b_prop := 0
	var b_aj := 0
	var b_lib := 0
	var b_cul := {}
	for pj in m.paises[pais].provincias:
		match cs.relacion(int(pj)):
			"propia":
				b_prop += 1
			"ajena":
				b_aj += 1
			_:
				b_lib += 1
		var cu: String = cs.cultural(int(pj))
		if cu != "":
			b_cul[cu] = int(b_cul.get(cu, 0)) + 1
	ok(b_lib >= 1 and b_aj >= 1 and cuenta["propias"] == b_prop and cuenta["ajenas"] == b_aj and cuenta["libres"] == b_lib and cuenta["culturas"] == b_cul,
		"contar() = relacion() y cultural() una a una (propias %d, ajenas %d, libres %d)" % [b_prop, b_aj, b_lib])
	cs.fijar_nacional(pj2, pais)
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


# ─────────────────────────────────────────────────────────────
func mp(lon: float, lat: float) -> Vector2:
	return Vector2((lon + 180.0) * 2400.0 / 360.0, (90.0 - lat) * 1200.0 / 180.0)


func prov_en(lon: float, lat: float) -> int:
	var r: Array = main._anillo_bajo(mp(lon, lat))
	return -1 if int(r[0]) < 0 else int(main.anillos[int(r[0])]["p"])


## Todos los textos (Label y Button) que cuelgan de un nodo.
func textos(n: Node, acc := []) -> Array:
	if n is Label:
		acc.append((n as Label).text)
	elif n is Button:
		acc.append((n as Button).text)
	for h in n.get_children():
		textos(h, acc)
	return acc


func hay_texto(n: Node, fragmento: String) -> bool:
	for t in textos(n):
		if String(t).findn(fragmento) >= 0:
			return true
	return false


func elegir_provincia(pi: int) -> void:
	main._seleccion_provincia(pi, main.mundo.continente_de_provincia(pi), Vector2(1200.0, 300.0))
	await fotogramas(2)


func t_hud() -> void:
	print("[T] ── HUD de provincia: Población, Ingreso, Edificios, Cores")
	await arrancar(2026)
	var m = main.mundo
	var pais := "España"
	var pi := prov_en(-3.7, 40.4)
	ok(pi >= 0 and String(m.provincias[pi].pais) == pais, "Madrid es una provincia de España (%d)" % pi)
	await elegir_provincia(pi)
	var hud = main.hud
	ok(hud.datos.get("ed_pis", []) == [pi], "el mapa manda al HUD las provincias de la selección")
	for tit in ["POBLACIÓN", "INGRESO", "EDIFICIOS", "CORES"]:
		ok(hay_texto(hud.cuerpo, tit), "tarjeta «%s» en la pestaña General" % tit)
	ok(hay_texto(hud.cuerpo, "Producción anual") and hay_texto(hud.cuerpo, "Aporta a la tesorería"), "Ingreso: producción anual y aporte a la tesorería")
	ok(hay_texto(hud.cuerpo, "Core nacional") and hay_texto(hud.cuerpo, "Core cultural") and hay_texto(hud.cuerpo, "tierra propia"), "Cores: nacional (propia) y cultural")
	ok(hay_texto(hud.cuerpo, "Todavía no hay ningún edificio"), "Edificios: sin edificios todavía")
	ok(hay_texto(hud.cuerpo, "Construir…"), "botón «Construir…»")
	# tras construir algo, la tarjeta lo muestra
	var ed = m.edificios
	var e: int = ed.indice("muralla") if ed.indice("muralla") >= 0 else 0
	m.descubrimientos.conceder(int(m.paises[pais].tid), ed.desc_idx[e])
	ed.dar(pi, e, 2)
	main.refrescar_todo(false)
	await fotogramas(2)
	ok(hay_texto(hud.cuerpo, String(ed.nombre[e])) and hay_texto(hud.cuerpo, "×2"), "Edificios: lista «%s ×2» tras añadirlos" % ed.nombre[e])
	ok(not hay_texto(hud.cuerpo, "Todavía no hay ningún edificio"), "ya no dice que no hay edificios")
	# una obra se ve con su avance
	m.paises[pais].tesoreria = 1.0e15
	var e2 := -1
	for k in ed.n:
		if k != e and ed.conoce(pais, k) and bool(ed.puede(pais, pi, k)["ok"]):
			e2 = k
			break
	ed.construir(pais, pi, e2)
	main.refrescar_todo(false)
	await fotogramas(2)
	ok(hay_texto(hud.cuerpo, "EN OBRA (1)") and hay_texto(hud.cuerpo, "faltan"), "Edificios: la obra aparece con los días que faltan")
	# país: totales
	main._seleccion_pais(pais, "Europa", Vector2(1200.0, 300.0))
	await fotogramas(2)
	ok(hud.datos.get("ed_pis", []).size() == m.paises[pais].provincias.size(), "país: ed_pis = todas sus provincias")
	ok(hay_texto(hud.cuerpo, "EDIFICIOS") and hay_texto(hud.cuerpo, "CORES") and hay_texto(hud.cuerpo, "propias"), "país: tarjetas de totales de Edificios y Cores")
	ok(not hay_texto(hud.cuerpo, "INGRESO"), "país: la tarjeta Ingreso es solo de provincia")
	# tierras sin reclamar: nada de esto
	await arrancar(1)
	var libre := -1
	for pr in main.mundo.provincias:
		if main._es_libre(String(pr.pais)):
			libre = pr.idx
			break
	ok(libre >= 0, "año 1: hay tierras sin reclamar")
	main._seleccion_provincia(libre, "Europa", Vector2(1200.0, 300.0))
	await fotogramas(2)
	ok(not main.hud.datos.has("ed_pis") and not hay_texto(main.hud.cuerpo, "Construir…"), "tierras sin reclamar: sin edificios ni cores")
	await arrancar(2026)


func fila_de(e: int) -> Dictionary:
	for fl in main.panel_construir._filas:
		if int(fl["e"]) == e:
			return fl
	return {}


func t_ventana() -> void:
	print("[T] ── Ventana Construir")
	var m = main.mundo
	var ed = m.edificios
	var pais := "España"
	var pi := prov_en(-3.7, 40.4)
	m.paises[pais].tesoreria = 1.0e15
	await elegir_provincia(pi)
	main._abrir_construir()
	await fotogramas(2)
	var w = main.panel_construir
	ok(w != null and is_instance_valid(w), "se abre con _abrir_construir()")
	ok(w.pis == [pi] and w.pais == pais and w.validas == [pi], "atiende la provincia elegida")
	ok(String(w._lbl_dest.text).find(String(m.provincias[pi].nombre)) >= 0, "cabecera: %s" % w._lbl_dest.text)
	var conocidos: int = ed.conocidos(pais).size()
	ok(w.filas_visibles == conocidos and conocidos > 0, "solo se ven los edificios que conoce el país (%d)" % conocidos)
	w._chk.set_pressed(true)
	await fotogramas(1)
	ok(w.filas_visibles == 109, "«mostrar también lo que no conoces»: los 109 (%d)" % w.filas_visibles)
	w._chk.set_pressed(false)
	# categorías
	var cat_con := 0
	for e in ed.conocidos(pais):
		if String(ed.cat[e]) == "def":
			cat_con += 1
	w.filtro_cat = "def"
	w._marcar_chips()
	w.refrescar(true)
	ok(w.filas_visibles == cat_con, "filtro por categoría «def»: %d" % cat_con)
	w.filtro_cat = ""
	w._marcar_chips()
	w.refrescar(true)
	# construir desde un botón
	var e_ok := -1
	for e in ed.conocidos(pais):
		if bool(ed.puede(pais, pi, e)["ok"]):
			e_ok = e
			break
	ok(e_ok >= 0, "hay un edificio que se puede construir (%s)" % ed.nombre[e_ok])
	var fl := fila_de(e_ok)
	var btn: Button = fl["btn"]
	ok(not btn.disabled and btn.text == "Construir", "botón activo")
	var tes0: float = m.paises[pais].tesoreria
	btn.pressed.emit()
	await fotogramas(2)
	ok(ed.en_obra(pi, e_ok) == 1 and m.paises[pais].tesoreria < tes0, "pulsar Construir empieza la obra y cobra")
	ok(String(main.avisos.ultimo_texto).begins_with("Obra empezada"), "aviso: «%s»" % main.avisos.ultimo_texto)
	ok(ed.tope[e_ok] > 1 or btn.disabled, "si es único, el botón se apaga")
	ok(w.obras_mostradas == 1 and w._tit_obras.visible, "«Obras en curso» muestra la obra")
	# cancelar
	var tes1: float = m.paises[pais].tesoreria
	var bc: Button = null
	for h in w._caja_obras.get_children():
		for x in h.get_children():
			if x is Button:
				bc = x
	ok(bc != null and not bc.disabled, "botón de cancelar la obra")
	bc.pressed.emit()
	await fotogramas(2)
	ok(ed.en_obra(pi, e_ok) == 0 and m.paises[pais].tesoreria > tes1, "cancelar quita la obra y devuelve dinero")
	ok(w.obras_mostradas == 0 and not w._tit_obras.visible, "«Obras en curso» se oculta sin obras")
	# sin dinero: el botón avisa
	m.paises[pais].tesoreria = 0.0
	w.refrescar(true)
	ok(btn.disabled and String(btn.tooltip_text).find("tesorería") >= 0, "sin dinero el botón se apaga y dice por qué")
	m.paises[pais].tesoreria = 1.0e15
	# país ajeno: solo ver
	m.fijar_jugador("Francia")
	w.refrescar(true)
	ok(not w.puede_ordenar() and btn.disabled and w._lbl_sin.visible, "con otro país como jugador no se puede ordenar y la ventana lo dice")
	m.fijar_jugador("")
	w.refrescar(true)
	ok(w.puede_ordenar() and not btn.disabled, "como observador sí")
	# la ventana sigue a la selección
	var pi2 := prov_en(2.17, 41.39)
	await elegir_provincia(pi2)
	ok(w.pis == [pi2], "al elegir otra provincia la ventana la sigue")
	# tema y teclado
	main._aplicar_tema(1)
	await fotogramas(1)
	ok(is_instance_valid(w) and w.filas_visibles > 0, "cambiar de tema no la rompe")
	main._aplicar_tema(0)
	main._alternar_construir()
	await fotogramas(2)
	ok(main.panel_construir == null, "_alternar_construir() la cierra")
	ok("construir" in main.geo_ventanas, "recuerda su sitio y tamaño al cerrarse")
	main._alternar_construir()
	await fotogramas(2)
	ok(main.panel_construir != null and main.panel_construir.pis == [pi2], "y la abre otra vez sobre lo elegido")
	main._cerrar_construir()


func t_grupo() -> void:
	print("[T] ── Totales y órdenes de grupo (Ctrl+clic)")
	var m = main.mundo
	var ed = m.edificios
	var pais := "España"
	m.paises[pais].tesoreria = 1.0e15
	var pa := prov_en(-3.7, 40.4)
	var pb := prov_en(2.17, 41.39)
	var pc := prov_en(-5.99, 37.39)
	await elegir_provincia(pa)
	main._enfocar_pais(pais, false)
	main._seleccion_provincia(pa, "Europa", mp(-3.7, 40.4))
	main._seleccionar_varias(mp(2.17, 41.39))
	main._seleccionar_varias(mp(-5.99, 37.39))
	await fotogramas(2)
	var hud = main.hud
	ok(int(hud.datos.get("multi", 0)) == 3, "tres unidades elegidas con Ctrl+clic")
	var esperadas := [pa, pb, pc]
	esperadas.sort()
	var ped: Array = hud.datos.get("ed_pis", [])
	ped.sort()
	ok(ped == esperadas, "ed_pis = la unión de las tres provincias (%s)" % str(ped))
	ok(hay_texto(hud.cuerpo, "GRUPO ELEGIDO") and hay_texto(hud.cuerpo, "Población total") and hay_texto(hud.cuerpo, "Producción anual total"), "tarjeta «Grupo elegido» con los totales")
	ok(hay_texto(hud.cuerpo, "Construir en el grupo…"), "botón «Construir en el grupo…»")
	ok(not hay_texto(hud.cuerpo, "INGRESO"), "con grupo no sale la tarjeta de Ingreso de una sola provincia")
	# abrir desde el botón y construir en las tres
	hud.construir_pedido.emit(ped)
	await fotogramas(2)
	var w = main.panel_construir
	ok(w != null and w.validas.size() == 3, "la ventana se abre con las 3 provincias")
	ok(String(w._lbl_dest.text).begins_with("3 provincias"), "cabecera de grupo: «%s»" % w._lbl_dest.text)
	var e_ok := -1
	for e in ed.conocidos(pais):
		if ed.tope[e] >= 1 and bool(ed.puede(pais, pa, e)["ok"]) and bool(ed.puede(pais, pb, e)["ok"]) and bool(ed.puede(pais, pc, e)["ok"]):
			e_ok = e
			break
	ok(e_ok >= 0, "hay un edificio construible en las tres (%s)" % ed.nombre[e_ok])
	var fl := fila_de(e_ok)
	ok(String((fl["btn"] as Button).text) == "Construir ×3", "botón «%s»" % (fl["btn"] as Button).text)
	ok(String((fl["lbl_costo"] as Label).text).find("en total") >= 0, "el costo muestra el total del grupo: «%s»" % (fl["lbl_costo"] as Label).text)
	var tes0: float = m.paises[pais].tesoreria
	(fl["btn"] as Button).pressed.emit()
	await fotogramas(2)
	ok(ed.en_obra(pa, e_ok) == 1 and ed.en_obra(pb, e_ok) == 1 and ed.en_obra(pc, e_ok) == 1, "orden de grupo: obra en cada una de las tres")
	ok(absf((tes0 - m.paises[pais].tesoreria) - (ed.costo_local(pa, e_ok) + ed.costo_local(pb, e_ok) + ed.costo_local(pc, e_ok))) < 1.0e-3 * tes0 * 1.0e-6 + 1.0, "se cobra la suma de las tres")
	ok(w.obras_mostradas == 3, "«Obras en curso» lista las 3 obras")
	ok(hud.datos.get("ed_sig", 0) != 0 and hay_texto(hud.cuerpo, "EN OBRA (3)"), "el HUD de grupo muestra las 3 obras")
	# un país entero cuenta como grupo (Ctrl+clic en países)
	main._limpiar_seleccion()
	main._cerrar_construir()
	main._seleccion_pais(pais, "Europa", mp(-3.7, 40.4))
	await fotogramas(2)
	main._abrir_construir()
	await fotogramas(2)
	ok(main.panel_construir.validas.size() == m.paises[pais].provincias.size(), "país entero: la ventana atiende todas sus provincias (%d)" % main.panel_construir.validas.size())
	var t0 := Time.get_ticks_usec()
	main.panel_construir.refrescar(true)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	ok(ms < 400.0, "refrescar la ventana con el país entero cuesta %.0f ms" % ms)
	main._cerrar_construir()


func t_debug() -> void:
	print("[T] ── Debug > Edificios")
	var m = main.mundo
	var ed = m.edificios
	var pais := "España"
	var pa := prov_en(-3.7, 40.4)
	await elegir_provincia(pa)
	main._abrir_debug()
	await fotogramas(2)
	var d = main.debug_menu
	ok(d != null and d.paginas.has("edif"), "el Debug tiene la sección Edificios")
	d._ir_a("edif")
	await fotogramas(2)
	ok(d.lista_edif.item_count == ed.n, "la lista muestra los %d edificios (%d)" % [ed.n, d.lista_edif.item_count])
	d.filtro_edif.text = "muralla"
	d._refrescar_edif()
	ok(d.lista_edif.item_count > 0 and d.lista_edif.item_count < ed.n, "el filtro «muralla» deja %d" % d.lista_edif.item_count)
	d.filtro_edif.text = ""
	d._refrescar_edif()
	d.lista_edif.select(0)
	d.edif_sel = int(d.ids_lista_edif[0])
	var e: int = d.edif_sel
	var antes: int = ed.cantidad(pa, e)
	var total0: int = ed.total_mundo()
	d._edif_dar(true)
	ok(ed.cantidad(pa, e) == antes + 1 and ed.total_mundo() == total0 + 1, "DAR ×1 suma un edificio sin cobrar")
	ok(d.edif_sel == e, "la selección de la lista se conserva después de actuar")
	d._edif_dar(false)
	ok(ed.cantidad(pa, e) == antes, "QUITAR ×1 lo devuelve")
	m.paises[pais].tesoreria = 1.0e15
	var conocido := -1
	for x in ed.conocidos(pais):
		if ed.puede(pais, pa, int(x))["ok"]:
			conocido = int(x)
			break
	d._edif_obras(false)                                      # limpia lo que dejaron las pruebas anteriores
	var r: Dictionary = ed.construir(pais, pa, conocido) if conocido >= 0 else {"ok": false}
	ok(bool(r["ok"]) and ed.obras_de(pa).size() == 1, "hay una obra en curso para probar los botones")
	var ya: int = ed.cantidad(pa, conocido)
	d._edif_obras(true)
	ok(ed.obras_de(pa).is_empty() and ed.cantidad(pa, conocido) == ya + 1, "TERMINAR OBRAS la completa")
	ed.construir(pais, pa, conocido)
	d._edif_obras(false)
	ok(ed.obras_de(pa).is_empty(), "CANCELAR OBRAS la quita sin reembolso")
	d._core_nacional("Francia")
	ok(m.cores.nacional(pa) == "Francia", "FIJAR CORE NACIONAL → Francia")
	d._core_nacional("")
	ok(m.cores.nacional(pa) == "", "QUITARLO deja la provincia sin core nacional")
	d.opt_cultura.select(0)
	d._core_cultural()
	ok(m.cores.cultural(pa) == String(d.ids_cultura[0]), "FIJAR CORE CULTURAL")
	d._core_restaurar()
	ok(m.cores.nacional(pa) == "España" and m.cores.cultural(pa) == m.cores.cultura_del_dueno(pa), "CORES = LOS DE ORIGEN los restaura")
	ok(d.lbl_edif_res.text.contains("Elegido"), "el resumen dice qué hay elegido")
	main._cerrar_debug()
	await fotogramas(1)


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
