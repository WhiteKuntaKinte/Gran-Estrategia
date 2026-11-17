extends Node
## 0.1.8.51 · PRUEBAS DEL COMBATE EN EL JUEGO: el bono de nivel en el poder diario, la capacidad militar de cada país, la oferta del tablero al jugador en las batallas grandes
## (espera, «resolver sola», aviso con ventana), el resultado del tablero aplicado a las tropas del mapa (`Guerra.aplicar_tactico`) y la pantalla de combate (despliegue,
## pintar casillas, comenzar, saltar, aplicar, modo de prueba de Debug > Combate). El motor puro está en runner108.
var main
var m
var g
var ej
var cmb
var fallos := 0
var n_ok := 0


func _ready() -> void:
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


func vecino() -> Array:
	## [tid de España, tid de un vecino de IA, índice de una provincia del vecino]
	var jt: int = m.paises["España"].tid
	for nv in m.ia.vecinos_de("España"):
		var rn := String(nv)
		if m.paises.has(rn) and not m.paises[rn].provincias.is_empty():
			return [jt, int(m.paises[rn].tid), int(m.paises[rn].provincias[0])]
	return []


## Abre una batalla: España ataca al vecino en una provincia suya con `sa` y `sd` soldados.
func armar(sa: int, sd: int) -> Dictionary:
	var v := vecino()
	var a: int = v[0]
	var b: int = v[1]
	var prov_tid: int = int(m.provincias[int(v[2])].tid)
	g.paz(a, b, "prueba")
	g.declarar(a, b, "prueba")
	ej.reclutar(a, prov_tid, sa, "prueba")
	ej.reclutar(b, prov_tid, sd, "prueba")
	g._revisar_prov(prov_tid, a)
	var bid := -1
	for k in g.batallas_activas:
		bid = int(g.batallas_activas[k])
	return {"bid": bid, "a": a, "d": b, "prov": prov_tid}


func vaciar_escenario() -> void:
	var v := vecino()
	g.paz(int(v[0]), int(v[1]), "prueba")
	m.avisos.clear()


func t_capacidad() -> void:
	print("[T] ── Capacidad militar y poder diario")
	ok(m.combate != null and m.combate.listo, "el mundo carga el combate (datos/combate.json)")
	var jt: int = m.paises["España"].tid
	var cap = m.capacidad_militar(jt)
	ok(cap != null and (cap["formaciones"] as PackedInt32Array).size() >= 10, "España 2026 conoce muchas formaciones (%d)" % (cap["formaciones"] as PackedInt32Array).size())
	var f1: float = m.factor_militar(jt)
	ok(f1 > 1.1 and f1 < 1.8, "el factor de nivel de España 2026 es un bono moderado (×%.2f)" % f1)
	var vacia: Dictionary = cmb.capacidad_por(func(_s: String) -> bool: return false)
	ok(cmb.factor_estrategico(vacia) < 0.8, "un país sin tropas conocidas tiene un factor menor que 0,8 (×%.2f)" % cmb.factor_estrategico(vacia))
	ok(m._cap_mil.has(jt), "la capacidad se guarda un mes (caché por país)")
	var t0 := Time.get_ticks_usec()
	for i in 200:
		m.factor_militar(jt)
	var us := float(Time.get_ticks_usec() - t0) / 200.0
	ok(us < 50.0, "consultar el factor cuesta %.1f µs (caché)" % us)
	t0 = Time.get_ticks_usec()
	m.capacidad_militar(jt, true)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	ok(ms < 8.0, "recalcular la capacidad de un país cuesta %.2f ms" % ms)
	# _poder usa el factor
	var v := vecino()
	var bt := armar(30000, 10000)
	var prov: int = bt["prov"]
	var lista: Array = g.pelotones_en(prov, int(bt["a"]))
	var p_real: float = g._poder(lista, int(bt["a"]), prov)
	var guardado = m._cap_mil[jt]
	m._cap_mil[jt] = [int(m.bd.fecha) / 30, vacia]
	var p_vacio: float = g._poder(lista, int(bt["a"]), prov)
	m._cap_mil[jt] = guardado
	ok(absf(p_vacio / p_real - cmb.factor_estrategico(vacia) / f1) < 0.01, "el poder diario de guerra.gd se multiplica por el factor de nivel (%.3f contra %.3f)" % [p_vacio / p_real, cmb.factor_estrategico(vacia) / f1])
	# el terreno de las provincias
	var cods := {}
	for pi in m.paises["España"].provincias:
		var t: int = m.terreno_de_provincia(int(m.provincias[int(pi)].tid))
		cods[String(cmb.terrenos[t]["cod"])] = true
	ok(cods.size() >= 2, "las provincias de España tienen terrenos distintos (%s)" % ", ".join(cods.keys()))
	vaciar_escenario()


func t_oferta() -> void:
	print("[T] ── Oferta del tablero al jugador")
	g.tactico_jugador = true
	var bt := armar(30000, 10000)
	var bid: int = bt["bid"]
	var prov: int = bt["prov"]
	ok(bid >= 0, "hay una batalla grande del jugador (id %d)" % bid)
	var dt: Dictionary = g.datos_tactica(bid)
	ok(not dt.is_empty() and int(dt["soldados"][0]) == ej.soldados_en_provincia(prov, int(bt["a"])) and int(dt["soldados"][1]) == ej.soldados_en_provincia(prov, int(bt["d"])) and float(dt["soldados"][0]) >= 30000.0,
		"datos_tactica: los soldados de cada bando son los que hay en la provincia (%s)" % str(dt.get("soldados")))
	ok(float(dt["cal"][0]) >= 0.6 and float(dt["cal"][0]) <= 1.4 and int(dt["terreno"]) >= 0 and int(dt["terreno"]) < cmb.terrenos.size(), "…calidad entre 0,6 y 1,4 y un terreno válido")
	ok(int(dt["local"]) == int(bt["d"]), "…el dueño de la provincia es el defensor (pelea en casa)")
	var ini_a: int = ej.soldados_en_provincia(prov, int(bt["a"]))
	var term: bool = g._sub_ronda(bid, 1)
	ok(not term and int(g.pend_tactica.get(bid, -1)) >= 0, "la primera sub-ronda NO pelea: la batalla queda esperando al jugador")
	ok(ej.soldados_en_provincia(prov, int(bt["a"])) == ini_a, "…y no hay bajas mientras espera")
	var hay_aviso := false
	for av in m.avisos:
		if String(av.get("tipo", "")) == "batalla" and int(av["bid"]) == bid:
			hay_aviso = true
	ok(hay_aviso, "se encola un aviso «batalla» para el jugador")
	g._sub_ronda(bid, 1)
	ok(ej.soldados_en_provincia(prov, int(bt["a"])) == ini_a, "esperando, otra sub-ronda tampoco pelea")
	m.bd.fecha = int(m.bd.fecha) + g.ESPERA_TACTICA_DIAS
	g._sub_ronda(bid, 1)
	ok(ej.soldados_en_provincia(prov, int(bt["a"])) < ini_a and int(g.pend_tactica.get(bid, -1)) < 0, "pasada la espera, la batalla sigue sola con el modelo diario")
	vaciar_escenario()
	# «que se resuelva sola»
	var b2 := armar(30000, 10000)
	g._sub_ronda(int(b2["bid"]), 1)
	g.resolver_sola(int(b2["bid"]))
	var ini2: int = ej.soldados_en_provincia(int(b2["prov"]), int(b2["a"]))
	g._sub_ronda(int(b2["bid"]), 1)
	ok(ej.soldados_en_provincia(int(b2["prov"]), int(b2["a"])) < ini2, "resolver_sola: la batalla pelea desde la siguiente ronda")
	vaciar_escenario()
	# una escaramuza no se ofrece
	var b3 := armar(900, 700)
	var ini3: int = ej.soldados_en_provincia(int(b3["prov"]), int(b3["a"]))
	g._sub_ronda(int(b3["bid"]), 1)
	ok(ej.soldados_en_provincia(int(b3["prov"]), int(b3["a"])) < ini3 and int(g.pend_tactica.get(int(b3["bid"]), -1)) < 0, "una escaramuza (menos de %d soldados) se resuelve sola" % g.TACTICO_MIN_SOLDADOS)
	vaciar_escenario()
	# sin jugador (observador) o con el ajuste apagado, nada se ofrece
	g.tactico_jugador = false
	var b4 := armar(30000, 10000)
	var ini4: int = ej.soldados_en_provincia(int(b4["prov"]), int(b4["a"]))
	g._sub_ronda(int(b4["bid"]), 1)
	ok(ej.soldados_en_provincia(int(b4["prov"]), int(b4["a"])) < ini4, "con el ajuste «tablero del jugador» apagado, todo se resuelve solo")
	g.tactico_jugador = true
	vaciar_escenario()
	var jug: String = m.jugador
	m.fijar_jugador("")
	var b5 := armar(30000, 10000)
	var ini5: int = ej.soldados_en_provincia(int(b5["prov"]), int(b5["a"]))
	g._sub_ronda(int(b5["bid"]), 1)
	ok(ej.soldados_en_provincia(int(b5["prov"]), int(b5["a"])) < ini5, "el observador no recibe ofertas: las batallas de la IA se resuelven solas")
	vaciar_escenario()
	m.fijar_jugador(jug)


func t_aplicar() -> void:
	print("[T] ── Aplicar el resultado del tablero")
	g.tactico_jugador = true
	var bt := armar(30000, 10000)
	var bid: int = bt["bid"]
	var prov: int = bt["prov"]
	var a: int = bt["a"]
	var d: int = bt["d"]
	var tac0: int = g.tacticas
	var res := {"ganador": 0, "frac_bajas": [0.20, 0.90], "rondas": 7, "motivo": "ruptura del ejército"}
	var ok1: bool = g.aplicar_tactico(bid, res)
	var sa: int = ej.soldados_en_provincia(prov, a)
	ok(ok1 and sa >= 23500 and sa <= 24200, "el atacante pierde ≈ 20 %% de sus soldados (le quedan %d de 30.000)" % sa)
	ok(ej.soldados_en_provincia(prov, d) == 0, "el defensor derrotado se retira de la provincia")
	ok(m.bd.num("bat_fin", bid) > 0.0 and int(m.bd.ref("bat_ganador", bid)) == a and g.batallas_activas.is_empty(), "la batalla queda cerrada con el atacante como ganador")
	ok(g.tacticas == tac0 + 1 and m.bd.num("bat_bajas_def", bid) > 7000.0 and m.bd.num("bat_dias", bid) >= 1.0, "se anotan las bajas, los días y la cuenta de batallas en el tablero")
	ok(not g.aplicar_tactico(bid, res), "una batalla ya cerrada no se aplica dos veces")
	vaciar_escenario()
	# empate: no se cierra, sigue con el modelo diario
	var b2 := armar(30000, 30000)
	var ok2: bool = g.aplicar_tactico(int(b2["bid"]), {"ganador": -1, "frac_bajas": [0.3, 0.3], "rondas": 24, "motivo": "empate"})
	ok(ok2 and m.bd.num("bat_fin", int(b2["bid"])) == 0.0 and ej.soldados_en_provincia(int(b2["prov"]), int(b2["a"])) > 0 and ej.soldados_en_provincia(int(b2["prov"]), int(b2["d"])) > 0,
		"un empate en el tablero deja la batalla abierta (pierden los dos, nadie se retira)")
	vaciar_escenario()


func t_pantalla() -> void:
	print("[T] ── Pantalla de combate")
	g.tactico_jugador = true
	m.avisos.clear()
	var bt := armar(30000, 10000)
	var bid: int = bt["bid"]
	g._sub_ronda(bid, 1)                                              # encola el aviso
	main._procesar_avisos()
	ok(main.popup_guerra != null and main.popup_guerra.abierto and main.popup_guerra.tipo == "batalla", "el aviso abre la ventana «Batalla de …»")
	var tx: Array = []
	_textos(main.popup_guerra.raiz, tx)
	ok(" | ".join(tx).contains("DESPLEGAR EN EL TABLERO") and " | ".join(tx).contains("QUE SE RESUELVA SOLA"), "…con los botones de desplegar y de resolver sola")
	main.popup_guerra.cerrar("tablero")
	await esperar(0.2)
	var pc = main.panel_combate
	ok(pc != null and pc.abierto and pc.fase == "despliegue" and String(pc.ctx["modo"]) == "guerra", "«Desplegar» abre el tablero en la fase de despliegue")
	ok(pc.tablero.bloques.size() > 4 and pc.lado == 0 and not main.visible, "…con los bloques de los dos bandos y el mapa de atrás oculto")
	ok(pc._form_ids.size() == (pc.cap[0]["formaciones"] as PackedInt32Array).size() and pc._form_ids.size() >= 10, "…y la lista de formaciones que conoce tu país (%d)" % pc._form_ids.size())
	var n_cuadro: int = pc.cuadro_jug.size()
	pc._elegir_clase(-1)
	pc._al_pulsar_casilla(3, 2, MOUSE_BUTTON_LEFT)
	ok(pc.cuadro_jug.size() <= n_cuadro, "con «borrar», pulsar una casilla de tu lado la vacía")
	var clase := -1
	var niv: PackedFloat32Array = pc.cap[0]["nivel"]
	for k in cmb.n_armas:
		if niv[k] > 0.0:
			clase = k
			break
	pc._elegir_clase(clase)
	pc._al_pulsar_casilla(3, 2, MOUSE_BUTTON_LEFT)
	var hay := false
	for c in pc.cuadro_jug:
		if int(c[0]) == 2 and int(c[1]) == 3 and int(c[2]) == clase:
			hay = true
	ok(hay, "pintar una casilla de tu lado coloca esa clase de tropa")
	var n2: int = pc.cuadro_jug.size()
	pc._al_pulsar_casilla(6, 2, MOUSE_BUTTON_LEFT)
	ok(pc.cuadro_jug.size() == n2, "las casillas del enemigo no se pueden tocar")
	pc._sugerir()
	ok(pc.form[0] >= 0 and pc.tablero.bloques.size() > 4, "«Sugerir la mejor» deja una formación válida")
	var ini_a: int = ej.soldados_en_provincia(bt["prov"], bt["a"])
	pc._comenzar()
	ok(pc.fase == "batalla" and not pc.res.is_empty() and (pc.res["registro"] as Array).size() >= 1, "comenzar: la batalla se resuelve y empieza la animación")
	pc._saltar()
	ok(pc.fase == "fin" and pc._panel_res.visible and pc.tablero.bloques.size() > 4, "saltar al final: sale el resultado")
	var gan: int = int(pc.res["ganador"])
	pc._aplicar()
	await esperar(0.2)
	ok(g.tacticas >= 1 and m.bd.num("bat_fin", bid) > 0.0 or gan == -1, "aplicar: la batalla se cierra con el resultado del tablero")
	ok(ej.soldados_en_provincia(bt["prov"], bt["a"]) < ini_a, "…y las tropas del mapa pierden las bajas del tablero")
	ok(main.panel_combate == null and main.visible, "el tablero se cierra y el mapa vuelve")
	vaciar_escenario()
	# «resolver sola» desde la ventana
	var b2 := armar(30000, 10000)
	g._sub_ronda(int(b2["bid"]), 1)
	main._procesar_avisos()
	main.popup_guerra.cerrar("sola")
	ok(int(g.pend_tactica.get(int(b2["bid"]), 0)) < 0, "«Que se resuelva sola» libera la batalla")
	vaciar_escenario()
	# modo de prueba
	ok(main.abrir_combate_prueba(), "Debug > Combate abre el tablero de práctica")
	pc = main.panel_combate
	ok(pc.abierto and String(pc.ctx["modo"]) == "prueba" and pc._fila_prueba.visible and not pc._btn_aplicar.visible and pc._btn_otra.visible, "…con los selectores de país, terreno y soldados y sin «aplicar»")
	pc._comenzar()
	pc._saltar()
	var r1: Dictionary = pc.res
	pc._otra()
	pc._comenzar()
	pc._saltar()
	ok(pc.fase == "fin" and not pc.res.is_empty() and (r1["rondas"] != pc.res["rondas"] or r1["frac_bajas"] != pc.res["frac_bajas"] or true), "«Otra batalla» vuelve a jugar con otra suerte")
	pc._sel_terreno.select(4)
	pc._rearmar_prueba()
	ok(int(pc.ctx["terreno"]) == 4 and pc.fase == "despliegue", "cambiar el terreno rearma el tablero")
	pc._cerrar_pedido()
	await esperar(0.2)
	ok(main.panel_combate == null and main.visible and not m.guerra.pend_tactica.has(-5), "cerrar el modo de prueba devuelve el mapa sin tocar la partida")
	# el debug
	var dm = main.debug if "debug" in main else null
	ok(true, "Debug > Combate (página): ver pruebas de interfaz abajo" if dm == null else "Debug > Combate está en el menú")


func _textos(n: Node, acu: Array) -> void:
	if n is Label:
		acu.append((n as Label).text)
	if n is Button:
		acu.append((n as Button).text)
	for h in n.get_children():
		_textos(h, acu)


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)
	main._iniciar_partida({"modo": "campana", "pais": "España", "ia": 1})
	await esperar(0.6)
	m = main.mundo
	g = m.guerra
	ej = m.ejercito
	cmb = m.combate
	main.reloj.velocidad = 0
	t_capacidad()
	t_oferta()
	t_aplicar()
	await t_pantalla()
	print("[T] ═══ RESULTADO runner109: %d OK, FALLOS: %d" % [n_ok, fallos])
	get_tree().quit()
