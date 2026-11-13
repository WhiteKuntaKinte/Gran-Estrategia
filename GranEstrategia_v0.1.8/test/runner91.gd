extends Node
## 0.1.8.42 · PRUEBAS DE LA VENTANA DE DESCUBRIMIENTOS: el árbol de cada una de las 40 secciones (todo el catálogo se ve, en cualquier época), estados en 1 d. C. y en 2026,
## ficha (requiere / abre), buscador, filtros, tecla T y botón de la barra, y la lista COMPLETA del Debug (los 1.730 y la fila de la frontera).
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
	t_catalogo()
	await t_ventana()
	await t_secciones()
	await t_epocas()
	await t_ficha()
	await t_busqueda()
	await t_entrada()
	await t_debug()
	print("[T] ═══ RESULTADO runner91: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_catalogo() -> void:
	print("[T] ── Catálogo: dependientes y búsqueda")
	var d = main.mundo.descubrimientos
	ok(d != null and d.n == 1730, "el catálogo tiene 1.730 descubrimientos (%d)" % d.n)
	var malos := 0
	var aristas := 0
	for i in d.n:
		var pedidos := PackedInt32Array(d.req[i])
		for g in d.req_o[i]:
			pedidos.append_array(g)
		for r in pedidos:
			aristas += 1
			if not (d.dependientes[r] as PackedInt32Array).has(i):
				malos += 1
	ok(malos == 0, "cada prerrequisito lista a sus dependientes (%d aristas, %d fallos)" % [aristas, malos])
	var suma := 0
	for i in d.n:
		suma += (d.dependientes[i] as PackedInt32Array).size()
	ok(suma <= aristas and suma > aristas - 40, "el índice inverso no repite (dependientes %d de %d pedidos)" % [suma, aristas])
	var b: PackedInt32Array = d.buscar("polvora")
	ok(b.size() >= 1 and String(d.nombre[b[0]]).to_lower().contains("pólvora"), "buscar «polvora» (sin tilde) encuentra Pólvora (%d)" % b.size())
	ok(d.buscar("").is_empty() and d.buscar("zzzzqq").is_empty(), "una búsqueda vacía o sin coincidencias no devuelve nada")
	var br: PackedInt32Array = d.buscar("bronce")
	var ordenado := true
	for k in range(1, br.size()):
		if d.anio[br[k]] < d.anio[br[k - 1]]:
			ordenado = false
	ok(br.size() > 1 and ordenado, "los resultados salen por año (%d con «bronce»)" % br.size())
	ok(d.buscar("bronce", 3).size() == 3, "el tope de resultados se respeta")


func t_ventana() -> void:
	print("[T] ── Abrir y cerrar")
	ok(main.panel_descubrimientos == null, "al empezar la ventana está cerrada")
	main._abrir_descubrimientos()
	await fotogramas(3)
	var p = main.panel_descubrimientos
	ok(p != null and is_instance_valid(p), "_abrir_descubrimientos crea la ventana")
	ok(p.grafo != null and p.grafo.nodos.size() > 0, "el árbol de la sección inicial tiene nodos (%d)" % p.grafo.nodos.size())
	ok(p._btns_rama.size() == 3 and p._filas_sec.size() == 40, "3 ramas y 40 secciones")
	main._abrir_descubrimientos()
	ok(main.panel_descubrimientos == p, "abrirla otra vez no crea una segunda")
	main._alternar_descubrimientos()
	await fotogramas(2)
	ok(main.panel_descubrimientos == null, "alternar la cierra")
	main._alternar_descubrimientos()
	await fotogramas(3)
	ok(main.panel_descubrimientos != null, "alternar la vuelve a abrir")


func t_secciones() -> void:
	print("[T] ── Las 40 secciones: todo el catálogo se ve")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var g = p.grafo
	g.size = Vector2(900.0, 520.0)
	var total := 0
	var sin_pos := 0
	var izquierda := 0
	var solapes := 0
	var sin_texto := 0
	var t0 := Time.get_ticks_usec()
	for s in d.secciones.size():
		p._elegir_seccion(s)
		total += g.nodos.size()
		for i in g.nodos:
			if not g.pos.has(i):
				sin_pos += 1
			if not g.textos.has(i):
				sin_texto += 1
		for ar in g.aristas:
			if (g.pos[int(ar["a"])] as Vector2).x + g.ANCHO_NODO >= (g.pos[int(ar["b"])] as Vector2).x:
				izquierda += 1
		var rs: Array = []
		for i in g.nodos:
			rs.append(Rect2(g.pos[i], Vector2(g.ANCHO_NODO, g.ALTO_NODO)))
		for a in rs.size():
			for b in range(a + 1, rs.size()):
				if (rs[a] as Rect2).intersects(rs[b]):
					solapes += 1
		if g.nodos.size() != p.totales[s]:
			sin_pos += 1
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	ok(total == 1730, "entre las 40 secciones salen los 1.730 descubrimientos (%d)" % total)
	ok(sin_pos == 0 and sin_texto == 0, "todos los nodos tienen posición y texto (%d / %d sin)" % [sin_pos, sin_texto])
	ok(izquierda == 0, "ninguna línea va hacia atrás: cada uno queda a la derecha de lo que necesita (%d)" % izquierda)
	ok(solapes == 0, "ningún nodo tapa a otro (%d solapes)" % solapes)
	print("[T] (las 40 secciones, distribuir + ficha: %.0f ms)" % ms)
	ok(ms < 4000.0, "armar las 40 secciones por software tarda poco (%.0f ms)" % ms)
	# el árbol más grande
	var mayor := 0
	for s in d.secciones.size():
		mayor = maxi(mayor, p.totales[s])
	ok(mayor == 102, "la sección más grande (Medicina y salud) tiene 102 (%d)" % mayor)
	# el árbol se dibuja: contador de dibujos y nodos dentro de la vista
	p._elegir_seccion(19)
	g.ajustar()
	var d0: int = g.dibujos
	g.queue_redraw()
	await fotogramas(3)
	ok(g.dibujos > d0, "el control se dibuja (%d veces)" % g.dibujos)
	ok(g.nodos_dibujados > 0, "entran nodos en la vista (%d de %d)" % [g.nodos_dibujados, g.nodos.size()])
	# paneo y zoom
	var z0: float = g.zoom
	g._acercar(1.5, Vector2(300.0, 200.0))
	ok(g.zoom > z0 and g.zoom <= g.ZOOM_MAX, "la rueda acerca (%.2f → %.2f)" % [z0, g.zoom])
	for _k in 40:
		g._acercar(0.7, Vector2(300.0, 200.0))
	ok(is_equal_approx(g.zoom, g.ZOOM_MIN), "el zoom no baja de %.2f" % g.ZOOM_MIN)
	for _k in 60:
		g._acercar(1.4, Vector2(300.0, 200.0))
	ok(is_equal_approx(g.zoom, g.ZOOM_MAX), "el zoom no pasa de %.2f" % g.ZOOM_MAX)
	g.origen = Vector2(-99999.0, -99999.0)
	g._limitar()
	ok(g.origen.x > -99999.0 and g.origen.y > -99999.0, "el paneo no deja perder el árbol")
	g.ajustar()
	ok(g.zoom >= 0.45 and g.zoom <= 1.0, "«Ajustar vista» deja un zoom legible (%.2f)" % g.zoom)


func t_epocas() -> void:
	print("[T] ── Estados en 1 d. C. y en 2026")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var g = p.grafo
	for fecha in [[1, 1, 1], [2026, 6, 1]]:
		main.debug_fijar_fecha(int(fecha[0]), int(fecha[1]), int(fecha[2]))
		main.mundo.fijar_jugador("")
		await fotogramas(2)
		p.refrescar()
		p._firma = ""
		p.refrescar()
		var conocidos := 0
		var lejanos := 0
		var cuenta_vista := 0
		for s in d.secciones.size():
			p._elegir_seccion(s)
			for i in g.nodos:
				cuenta_vista += 1
				var e: int = g.estado_nodo(i)
				if e == g.E_CONOCIDO:
					conocidos += 1
				elif e == g.E_LEJANO:
					lejanos += 1
		ok(cuenta_vista == 1730, "año %d: se pueden VER los 1.730 (%d)" % [int(fecha[0]), cuenta_vista])
		ok(conocidos == d.cuenta_f, "año %d: los conocidos son los de la historia (%d = %d)" % [int(fecha[0]), conocidos, d.cuenta_f])
		if int(fecha[0]) == 1:
			ok(conocidos < 700 and lejanos > 700, "año 1: quedan muchos por llegar y se ven (%d conocidos, %d lejanos)" % [conocidos, lejanos])
			var ultimo_conocido := ""
			for k in range(d.cuenta_f - 1, -1, -1):
				ultimo_conocido = String(d.nombre[d.orden[k]])
				break
			ok(d.n - d.cuenta_f > 1000, "año 1: la lista llega mucho más allá de «%s» (%d por llegar)" % [ultimo_conocido, d.n - d.cuenta_f])
		else:
			ok(conocidos > 1500, "2026: casi todo conocido (%d)" % conocidos)
			ok(d.n - d.cuenta_f > 0 and cuenta_vista == 1730, "2026: también se ven los descubrimientos hipotéticos del futuro (%d)" % (d.n - d.cuenta_f))
		var texto: String = p._lbl_info.text
		ok(texto.contains(str(d.anio_actual)) or texto.contains("Año del reloj"), "la línea de resumen se actualiza")
	# un país con estado propio: conceder cambia lo que muestra la ventana
	main.debug_fijar_fecha(1, 1, 1)
	main.mundo.fijar_jugador("España")
	await fotogramas(2)
	p._firma = ""
	p.refrescar()
	var tid: int = int(main.mundo.paises["España"].tid)
	ok(g.tid == tid, "con país, el árbol muestra lo que sabe ese país")
	var i_fut: int = d.orden[d.n - 1]
	ok(g.estado_nodo(i_fut) != g.E_CONOCIDO, "el último de la historia no lo conoce en el año 1")
	d.conceder(tid, i_fut)
	p.refrescar()
	ok(g.estado_nodo(i_fut) == g.E_CONOCIDO, "conceder un descubrimiento lo marca como conocido")
	var s_fut: int = int(d.seccion[i_fut])
	ok(int(p.cuentas[s_fut]) >= 1, "el contador de su sección sube")
	main.mundo.fijar_jugador("")
	main.debug_fijar_fecha(2026, 6, 1)
	await fotogramas(2)
	p._firma = ""
	p.refrescar()


func t_ficha() -> void:
	print("[T] ── Ficha: requiere / abre")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var g = p.grafo
	var i_fuego: int = d.indice("fuego")
	ok(i_fuego >= 0, "existe «fuego»")
	p.ir_a(i_fuego)
	await fotogramas(2)
	ok(p.sec_sel == int(d.seccion[i_fuego]) and g.sel == i_fuego, "ir_a lleva a su sección y lo elige")
	var abre: PackedInt32Array = d.dependientes[i_fuego]
	ok(abre.size() > 0 and p.filas_ficha >= mini(abre.size(), p.MAX_RELACIONES), "la ficha de «fuego» lista lo que abre (%d filas, %d dependientes)" % [p.filas_ficha, abre.size()])
	# uno de otra sección: ir_a cambia de sección y de rama
	var i_otra := -1
	for i in d.n:
		if int(d.seccion[i]) != p.sec_sel and int(d.secciones[int(d.seccion[i])]["rama"]) != int(d.secciones[p.sec_sel]["rama"]):
			i_otra = i
			break
	p.ir_a(i_otra)
	await fotogramas(2)
	ok(p.sec_sel == int(d.seccion[i_otra]) and p.rama_sel == int(d.secciones[p.sec_sel]["rama"]), "ir_a a otra rama cambia de rama y de sección")
	ok((p._btns_rama[p.rama_sel] as Button).button_pressed, "el botón de su rama queda marcado")
	# la ficha de uno con requisitos de varias formas
	var i_o := -1
	for i in d.n:
		if (d.req_o[i] as Array).size() > 0 and (d.req[i] as PackedInt32Array).size() > 0:
			i_o = i
			break
	if i_o >= 0:
		p.ir_a(i_o)
		await fotogramas(2)
		var esperado := (d.req[i_o] as PackedInt32Array).size()
		for gr in d.req_o[i_o]:
			esperado += (gr as PackedInt32Array).size()
		ok(p.filas_ficha >= esperado, "la ficha muestra todos los prerrequisitos, también las alternativas (%d filas ≥ %d)" % [p.filas_ficha, esperado])
	# sección vacía de selección: ficha general
	p._elegir_seccion(0)
	await fotogramas(1)
	ok(g.sel == -1 and p._ficha.get_child_count() > 0, "al cambiar de sección la ficha vuelve al resumen")
	# cadena resaltada al enfocar
	g.elegir(g.nodos[g.nodos.size() - 1], false)
	var ult: int = g.nodos[g.nodos.size() - 1]
	ok(g._foco == ult, "el nodo elegido queda enfocado")
	ok(g._prev.size() == _cierre(d, ult).size(), "la cadena de «lo que hace falta» es el cierre de sus prerrequisitos (%d)" % g._prev.size())


## Cierre transitivo de prerrequisitos (para comprobar el resaltado).
func _cierre(d, i: int) -> Dictionary:
	var vis := {}
	var pila := [i]
	while not pila.is_empty():
		var x: int = pila.pop_back()
		var pedidos := PackedInt32Array(d.req[x])
		for gr in d.req_o[x]:
			pedidos.append_array(gr)
		for r in pedidos:
			if not vis.has(int(r)):
				vis[int(r)] = true
				pila.append(int(r))
	return vis


func t_busqueda() -> void:
	print("[T] ── Buscador y filtros")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var g = p.grafo
	p._busca.text = "polvora"
	p._buscar()
	await fotogramas(2)
	ok(p._sc_res.visible and not p._sc_sec.visible and p.resultados >= 1, "buscar «polvora» muestra resultados (%d) en lugar de las secciones" % p.resultados)
	ok(p._tit_izq.text.begins_with("RESULTADOS"), "el título dice RESULTADOS")
	p._busca.text = "a"
	p._buscar()
	await fotogramas(1)
	ok(not p._sc_res.visible and p._sc_sec.visible, "con menos de 2 letras vuelve a las secciones")
	p._busca.text = "acero"
	p._buscar()
	await fotogramas(2)
	var primero: Button = p._lista_res.get_child(0)
	primero.pressed.emit()
	await fotogramas(2)
	ok(g.sel >= 0 and String(d.nombre[g.sel]).to_lower().contains("acero") or String(d.slug[g.sel]).contains("acero"), "pulsar un resultado va a ese descubrimiento («%s»)" % String(d.nombre[g.sel]))
	p._busca.text = ""
	p._buscar()
	await fotogramas(1)
	# filtros
	p._elegir_seccion(19)
	var tot: int = g.nodos.size()
	var n_con := 0
	g.fijar_filtros(1, "")
	for i in g.nodos:
		if g._pasa_filtro(i):
			n_con += 1
	var n_todos := 0
	g.fijar_filtros(0, "")
	for i in g.nodos:
		if g._pasa_filtro(i):
			n_todos += 1
	ok(n_todos == tot and n_con <= tot, "filtro de estado: todos %d, solo conocidos %d" % [n_todos, n_con])
	g.fijar_filtros(0, "B")
	var n_b := 0
	for i in g.nodos:
		if g._pasa_filtro(i):
			n_b += 1
			if String(d.tipo[i]) != "B":
				n_b += 1000
	ok(n_b < 1000, "filtro de tipo «Edificio» solo deja edificios (%d)" % n_b)
	p._opt_estado.select(2)
	p._opt_estado.item_selected.emit(2)
	ok(g.filtro_estado == 2, "el selector de estado llega al árbol")
	p._opt_estado.select(0)
	p._opt_estado.item_selected.emit(0)
	g.fijar_filtros(0, "")


func t_entrada() -> void:
	print("[T] ── Tecla T y botón de la barra")
	main._cerrar_descubrimientos()
	await fotogramas(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_T
	ev.pressed = true
	main._unhandled_input(ev)
	await fotogramas(3)
	ok(main.panel_descubrimientos != null, "la tecla T abre la ventana")
	main._unhandled_input(ev)
	await fotogramas(2)
	ok(main.panel_descubrimientos == null, "la tecla T la cierra")
	var btn: Button = main.hud.btn_descubrimientos
	ok(btn != null and btn.visible and btn.icon != null, "el botón «Descubrimientos» está en la barra y lleva icono")
	ok(btn.tooltip_text.contains("Atajo: T"), "su ficha dice el atajo")
	btn.pressed.emit()
	await fotogramas(3)
	ok(main.panel_descubrimientos != null, "el botón abre la ventana")
	ok(main.panel_descubrimientos.vf.ventana.visible, "la ventana flotante se ve")
	main.panel_descubrimientos.aplicar_tema()
	ok(main.panel_descubrimientos.grafo != null, "cambiar de tema con la ventana abierta no la rompe")
	main._volver_menu_principal()
	await fotogramas(2)
	ok(main.panel_descubrimientos == null, "volver al menú principal la cierra")
	if main.en_menu:
		main._on_jugar()
		await esperar(0.3)


func t_debug() -> void:
	print("[T] ── Debug > Descubrimientos: la lista es completa")
	var d = main.mundo.descubrimientos
	main._abrir_debug()
	await fotogramas(2)
	var dm = main.debug_menu
	ok(dm != null and dm.paginas.has("desc"), "el Debug tiene la sección Descubrimientos")
	for fecha in [[1, 1, 1], [2026, 6, 1], [1096, 1, 1]]:
		main.debug_fijar_fecha(int(fecha[0]), int(fecha[1]), int(fecha[2]))
		dm._ir_a("desc")
		dm.filtro_desc.text = ""
		dm._refrescar_desc()
		await fotogramas(2)
		ok(dm.lista_desc.item_count == d.n + 1, "año %d: la lista trae los %d (+ la fila de la frontera) (%d)" % [int(fecha[0]), d.n, dm.lista_desc.item_count])
		var ultimo := int(dm.ids_lista_desc[dm.ids_lista_desc.size() - 1])
		ok(ultimo == int(d.orden[d.n - 1]), "año %d: el último de la lista es el último del catálogo («%s»)" % [int(fecha[0]), String(d.nombre[ultimo])])
		var pos_front: int = dm.ids_lista_desc.find(-1)
		ok(pos_front == d.cuenta_f, "año %d: la fila divisoria cae donde termina la historia (%d = %d)" % [int(fecha[0]), pos_front, d.cuenta_f])
	dm.filtro_desc.text = "bronce"
	dm._refrescar_desc()
	ok(dm.lista_desc.item_count > 0 and dm.lista_desc.item_count < d.n, "el filtro «bronce» deja %d" % dm.lista_desc.item_count)
	dm.filtro_desc.text = ""
	dm._refrescar_desc()
	main._cerrar_debug()
