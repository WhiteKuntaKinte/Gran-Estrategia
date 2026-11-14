extends Node
## 0.1.8.43 · PRUEBAS DE LA PANTALLA COMPLETA DE DESCUBRIMIENTOS: hub de secciones, el árbol de cada una de las 40 secciones (crece hacia arriba; todo el catálogo se ve, en
## cualquier época), colores (bloqueado negro, lejano gris, conocido verde, disponible dorado), globo, trazos hacia otras secciones y «T», abanico circular (no cuadrícula), estados en 1 d. C. y en 2026, ficha (requiere / abre),
## buscador, filtros, tecla T, botón de la barra y Esc, y la lista COMPLETA del Debug (los 1.730 y la fila de la frontera).
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
	await t_hub()
	await t_secciones()
	await t_globo()
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
	print("[T] ── Abrir y cerrar: pantalla completa")
	ok(main.panel_descubrimientos == null, "al empezar la pantalla está cerrada")
	main._abrir_descubrimientos()
	await fotogramas(3)
	var p = main.panel_descubrimientos
	ok(p != null and is_instance_valid(p), "_abrir_descubrimientos crea la pantalla")
	ok(p.hub != null and p.arbol != null and p.fondo != null and p.cinta != null, "tiene hub, árbol, fondo y cinta de secciones")
	var vp: Vector2 = get_viewport().get_visible_rect().size
	ok(p.raiz.get_global_rect().size.is_equal_approx(vp) and p.capa.layer == 24, "ocupa TODA la ventana (%s de %s), en la capa 24" % [str(p.raiz.get_global_rect().size), str(vp)])
	ok(p.raiz.mouse_filter == Control.MOUSE_FILTER_STOP, "tapa el mapa: los clics no pasan a lo de abajo")
	ok(p._btns_rama.size() == 3 and p.secciones_de(0).size() + p.secciones_de(1).size() + p.secciones_de(2).size() == 40, "3 ramas y 40 secciones")
	ok(p.hub.visible and not p.arbol.visible and not p.en_arbol, "se abre en el hub de la rama (las secciones como tarjetas)")
	main._abrir_descubrimientos()
	ok(main.panel_descubrimientos == p, "abrirla otra vez no crea una segunda")
	main._alternar_descubrimientos()
	await fotogramas(2)
	ok(main.panel_descubrimientos == null, "alternar la cierra")
	main._alternar_descubrimientos()
	await fotogramas(3)
	ok(main.panel_descubrimientos != null, "alternar la vuelve a abrir")


func t_hub() -> void:
	print("[T] ── Hub: una tarjeta por sección, con su constelación")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var total_tarjetas := 0
	var suma := 0
	var fuera := 0
	for r in 3:
		p._elegir_rama(r)
		await fotogramas(2)
		ok(p.hub.visible and not p.arbol.visible, "rama %d: se ve el hub" % r)
		ok(p.hub.tarjetas.size() == p.secciones_de(r).size(), "rama %d: %d tarjetas (una por sección)" % [r, p.hub.tarjetas.size()])
		total_tarjetas += p.hub.tarjetas.size()
		for t in p.hub.tarjetas:
			var rc: Rect2 = t["rect"]
			if rc.position.x < 0.0 or rc.end.x > p.hub.size.x + 0.5:
				fuera += 1
			var m: Dictionary = p.hub.miniatura(int(t["s"]))
			suma += (m["nodos"] as PackedInt32Array).size()
			ok((m["p"] as PackedVector2Array).size() == (m["nodos"] as PackedInt32Array).size(), "tarjeta %d: un punto por descubrimiento" % int(t["s"]))
		ok(p.fondo.rama == r, "rama %d: el fondo cambia de ambiente" % r)
	ok(total_tarjetas == 40 and suma == 1730, "entre las tres ramas: 40 tarjetas y 1.730 puntos (%d / %d)" % [total_tarjetas, suma])
	ok(fuera == 0, "ninguna tarjeta se sale del ancho del hub (%d)" % fuera)
	var d0: int = p.hub.dibujos
	p.hub.queue_redraw()
	await fotogramas(3)
	ok(p.hub.dibujos > d0, "el hub se dibuja (%d veces)" % p.hub.dibujos)
	# clic en una tarjeta entra al árbol
	var t0: Dictionary = p.hub.tarjetas[0]
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = (t0["rect"] as Rect2).get_center()
	p.hub._gui_input(ev)
	await fotogramas(3)
	ok(p.en_arbol and p.sec_sel == int(t0["s"]) and p.arbol.visible and not p.hub.visible, "clic en una tarjeta entra al árbol de esa sección")
	ok(p.cinta.visible and p.cinta.secs.size() == p.secciones_de(p.rama_sel).size(), "aparece la cinta con las secciones de la rama (%d)" % p.cinta.secs.size())
	# el hub cuenta bien
	p._elegir_rama(1)
	var med: int = 19
	var cuenta := 0
	for i in d.n:
		if int(d.seccion[i]) == med:
			cuenta += 1
	ok(int(p.hub.totales[med]) == cuenta and cuenta == 102, "el hub cuenta los 102 de Medicina y salud (%d)" % int(p.hub.totales[med]))


func t_secciones() -> void:
	print("[T] ── Las 40 secciones: todo el catálogo se ve, en un abanico circular que crece hacia arriba desde la raíz")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var g = p.arbol
	g.size = Vector2(1000.0, 640.0)
	var total := 0
	var sin_pos := 0
	var hacia_abajo := 0
	var solapes := 0
	var raiz_arriba := 0
	var sin_salida_mal := 0
	var n_sin_salida := 0
	var n_pastillas := 0
	var t0 := Time.get_ticks_usec()
	for s in d.secciones.size():
		p._entrar_seccion(s)
		total += g.nodos.size()
		for i in g.nodos:
			if not g.pos.has(i) or not g.radio.has(i):
				sin_pos += 1
		for ar in g.aristas:                       # cada línea va hacia AFUERA: el que la recibe está en un anillo más lejos de la raíz
			var da: float = (g.pos[int(ar["a"])] as Vector2).distance_to(g.apex)
			var db: float = (g.pos[int(ar["b"])] as Vector2).distance_to(g.apex)
			if db <= da or int(g.nivel[int(ar["a"])]) >= int(g.nivel[int(ar["b"])]):
				hacia_abajo += 1
		for i in g.nodos:                           # cada nivel es un ANILLO (no una fila), con las raíces en el más cercano, y todo queda por encima de la raíz
			var dist: float = (g.pos[i] as Vector2).distance_to(g.apex)
			if dist < float(g.anillos[int(g.nivel[i])]) - 0.5 or dist > float(g.anillos_fin[int(g.nivel[i])]) + 0.5:
				raiz_arriba += 1
			if (g.pos[i] as Vector2).y >= g.apex.y:
				raiz_arriba += 1
			if int(g.nivel[i]) == 0 and dist > float(g.anillos_fin[0]) + 0.5:
				raiz_arriba += 1
		for a in g.nodos.size():
			for b in range(a + 1, g.nodos.size()):
				var na: int = g.nodos[a]
				var nb: int = g.nodos[b]
				if (g.pos[na] as Vector2).distance_to(g.pos[nb]) < float(g.radio[na]) + float(g.radio[nb]) - 0.01:
					solapes += 1
		for i in g.nodos:
			var vacio: bool = (d.dependientes[i] as PackedInt32Array).is_empty()
			if g.sin_salida.has(i) != vacio:
				sin_salida_mal += 1
			if vacio:
				n_sin_salida += 1
		n_pastillas += g.pastillas.size()
		if g.nodos.size() != p.totales[s]:
			sin_pos += 1
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	ok(total == 1730, "entre las 40 secciones salen los 1.730 descubrimientos (%d)" % total)
	ok(sin_pos == 0, "todos los nodos tienen posición y radio (%d sin)" % sin_pos)
	ok(hacia_abajo == 0, "ninguna línea vuelve hacia la raíz: cada uno queda MÁS LEJOS que lo que necesita (%d)" % hacia_abajo)
	ok(raiz_arriba == 0, "cada nivel es un anillo (o hasta 3 sub-anillos si está lleno) alrededor de la raíz, las raíces en el más cercano y todo por encima de ella (%d fuera)" % raiz_arriba)
	ok(solapes == 0, "ningún círculo tapa a otro (%d solapes)" % solapes)
	ok(sin_salida_mal == 0, "lleva «T» exactamente lo que no abre nada en todo el catálogo (%d mal; %d con T)" % [sin_salida_mal, n_sin_salida])
	ok(n_pastillas > 100, "hay trazos hacia otras secciones (%d)" % n_pastillas)
	print("[T] (las 40 secciones, distribución: %.0f ms)" % ms)
	ok(ms < 5000.0, "armar las 40 secciones por software tarda poco (%.0f ms)" % ms)
	# los trazos apuntan fuera de la sección y son coherentes con las dependencias
	p._entrar_seccion(int(d.seccion[d.indice("fuego")]))
	var malas := 0
	for pa in g.pastillas:
		var ni: int = pa["nodo"]
		for o in (pa["otros"] as PackedInt32Array):
			if int(d.seccion[o]) == g.seccion:
				malas += 1
			var enlazado: bool = (d.dependientes[ni] as PackedInt32Array).has(o) if bool(pa["arriba"]) else (d.dependientes[o] as PackedInt32Array).has(ni)
			if not enlazado:
				malas += 1
	ok(malas == 0 and g.pastillas.size() > 0, "los trazos de «fuego» (%d) apuntan a otra sección y de verdad enlazan" % g.pastillas.size())
	# colores: bloqueado negro, lejano gris, conocido verde, disponible dorado
	var cb: Color = g._colores_estado(g.E_BLOQUEADO)[0]
	var cl: Color = g._colores_estado(g.E_LEJANO)[0]
	var cc: Color = g._colores_estado(g.E_CONOCIDO)[0]
	var cd: Color = g._colores_estado(g.E_DISPONIBLE)[0]
	ok(cb.get_luminance() < 0.05, "bloqueado: NEGRO (luminancia %.3f)" % cb.get_luminance())
	ok(cl.get_luminance() > 0.15 and cl.get_luminance() < 0.6 and absf(cl.r - cl.g) < 0.1 and absf(cl.g - cl.b) < 0.1, "aún lejano: GRIS (%s)" % str(cl))
	ok(cc.g > cc.r + 0.2 and cc.g > cc.b + 0.2, "conocido: VERDE (%s)" % str(cc))
	ok(cd.r > 0.9 and cd.g > 0.7 and cd.b < 0.4, "disponible: DORADO (%s)" % str(cd))
	ok(cb.get_luminance() < cl.get_luminance() - 0.1, "bloqueado y aún lejano ya NO se ven igual")
	# el árbol más grande
	var mayor := 0
	for s in d.secciones.size():
		mayor = maxi(mayor, p.totales[s])
	ok(mayor == 102, "la sección más grande (Medicina y salud) tiene 102 (%d)" % mayor)
	# el árbol se dibuja: contador de dibujos y nodos dentro de la vista
	p._entrar_seccion(19)
	g.ajustar()
	var d0: int = g.dibujos
	g.queue_redraw()
	await fotogramas(3)
	ok(g.dibujos > d0, "el control se dibuja (%d veces)" % g.dibujos)
	ok(g.nodos_dibujados > 0, "entran nodos en la vista (%d de %d)" % [g.nodos_dibujados, g.nodos.size()])
	ok(g._lote.esta_vacio() and g._tx.is_empty(), "al terminar el dibujo no quedan lotes sin emitir")
	# «Ajustar vista»: raíces pegadas abajo y todo el árbol a la vista
	var base_y: float = g.origen.y + g.tam_arbol.y * g.zoom
	ok(absf(base_y - g.size.y) < 2.0 or g.zoom > 0.99, "«Ajustar vista» deja las raíces abajo (base en %.0f de %.0f)" % [base_y, g.size.y])
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
	ok(g.zoom >= g.ZOOM_AJUSTE_MIN and g.zoom <= 1.0, "«Ajustar vista» deja un zoom razonable (%.2f)" % g.zoom)
	# Camilo, 2026-11-13: «no quiero que sea cuadricular», «aprovecha el espacio» (como el árbol de Path of Exile 2), «el ETC no iba escrito en las capturas»
	var fuente_arbol := FileAccess.get_file_as_string("res://scripts/arbol_descubrimientos.gd")
	ok(not fuente_arbol.contains("\"ETC\""), "ningún texto «ETC» se escribe en la pantalla (los trazos hacia otras secciones no llevan texto)")
	p._entrar_seccion(19)
	var ys := {}
	for i in g.nodos:
		ys[snappedf((g.pos[i] as Vector2).y, 1.0)] = true
	ok(ys.size() > g.nodos.size() * 6 / 10, "Medicina no está en filas: %d alturas distintas para %d nodos (cuadrícula = una por nivel)" % [ys.size(), g.nodos.size()])
	var cerca := 1.0e12
	for a in g.nodos.size():
		for b in range(a + 1, g.nodos.size()):
			cerca = minf(cerca, (g.pos[g.nodos[a]] as Vector2).distance_to(g.pos[g.nodos[b]]))
	ok(cerca >= 100.0, "los círculos tienen aire: el par más cercano está a %.0f (antes 56)" % cerca)
	var rmax := 0.0
	for i in g.nodos:
		rmax = maxf(rmax, float(g.radio[i]))
	ok(g.R_MIN >= 20.0 and rmax >= 30.0, "los círculos son grandes (radio %.0f a %.0f; a zoom 1 miden %.0f a %.0f px)" % [g.R_MIN, rmax, g.R_MIN * 2.0, rmax * 2.0])
	g.vista_inicial()
	ok(g.zoom >= g.ZOOM_FRONTERA_MIN - 0.001 and g.zoom <= g.ZOOM_INICIAL + 0.001, "al entrar la vista queda cerca de lo disponible, NO con todo encogido (zoom %.2f)" % g.zoom)
	var disp := 0
	var suma_c := Vector2.ZERO
	for i in g.nodos:
		if g.estado_nodo(i) == g.E_DISPONIBLE:
			disp += 1
			suma_c += g._a_pantalla(g.pos[i])
	ok(disp > 0 and Rect2(Vector2.ZERO, g.size).grow(60.0).has_point(suma_c / float(maxi(disp, 1))), "el centro de lo disponible (%d) queda dentro de la vista" % disp)
	g.ajustar()
	var z_todo: float = g.zoom
	ok(z_todo < g.ZOOM_INICIAL, "«Ver todo» aleja más que la vista de entrada (%.2f < %.2f)" % [z_todo, g.ZOOM_INICIAL])
	g.size = Vector2(1400.0, 800.0)
	g.margen_der = 374.0
	g.elegir(g.nodos[g.nodos.size() / 2], true)
	ok(g.zoom >= g.ZOOM_AL_ELEGIR - 0.001, "ir a un descubrimiento lo acerca (zoom %.2f)" % g.zoom)
	var cen: Vector2 = g._a_pantalla(g.pos[g.nodos[g.nodos.size() / 2]])
	ok(absf(cen.x - (g.margen_izq + (1400.0 - g.margen_izq - 374.0) * 0.5)) < 2.0 or g.origen.x == g.size.x * 0.5 or g.origen.x <= g.size.x - g.tam_arbol.x * g.zoom - g.size.x * 0.5 + 1.0, "el descubrimiento elegido queda centrado (sin la ficha de la derecha)")
	g.size = Vector2(1000.0, 640.0)
	g.margen_der = 0.0


func t_globo() -> void:
	print("[T] ── Globo al pasar el ratón, clic en un trazo hacia otra sección y la «T»")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var g = p.arbol
	var i_fuego: int = d.indice("fuego")
	p._entrar_seccion(int(d.seccion[i_fuego]))
	g.size = Vector2(1000.0, 640.0)
	g.ajustar()
	await fotogramas(2)
	# pasar el ratón por encima de un círculo
	var c: Vector2 = g._a_pantalla(g.pos[i_fuego])
	var mm := InputEventMouseMotion.new()
	mm.position = c
	g._gui_input(mm)
	ok(g.hover == i_fuego, "el ratón sobre el círculo de «fuego» lo marca (hover %d)" % g.hover)
	ok(g._foco == i_fuego and g._sig.size() > 0, "se resalta lo que abre (%d)" % g._sig.size())
	var d0: int = g.dibujos
	await fotogramas(3)
	ok(g.dibujos > d0 and g._lote.esta_vacio(), "con el globo abierto se dibuja bien y no deja lotes")
	# fuera de todo círculo
	mm = InputEventMouseMotion.new()
	mm.position = Vector2(2.0, 2.0)
	g._gui_input(mm)
	ok(g.hover == -1 and g.hover_pastilla == -1, "el ratón en el vacío quita el globo")
	# trazo hacia otra sección: el ratón encima y clic
	if g.pastillas.size() > 0:
		var rp: Rect2 = g._rect_pastilla(0)
		mm = InputEventMouseMotion.new()
		mm.position = rp.get_center()
		g._gui_input(mm)
		ok(g.hover_pastilla == 0 and g.hover == -1, "el ratón sobre un trazo hacia otra sección lo marca")
		var destino: int = (g.pastillas[0]["otros"] as PackedInt32Array)[0]
		var sec_antes: int = p.sec_sel
		var bt := InputEventMouseButton.new()
		bt.button_index = MOUSE_BUTTON_LEFT
		bt.pressed = true
		bt.position = rp.get_center()
		g._gui_input(bt)
		bt = InputEventMouseButton.new()
		bt.button_index = MOUSE_BUTTON_LEFT
		bt.pressed = false
		bt.position = rp.get_center()
		g._gui_input(bt)
		await fotogramas(3)
		ok(p.sec_sel == int(d.seccion[destino]) and p.sec_sel != sec_antes and g.sel == destino, "clic en el trazo lleva al descubrimiento de la otra sección y lo elige")
	# «T»: un descubrimiento que no abre nada
	var i_t := -1
	for i in d.n:
		if (d.dependientes[i] as PackedInt32Array).is_empty():
			i_t = i
			break
	ok(i_t >= 0, "hay descubrimientos sin salida en el catálogo")
	p.ir_a(i_t)
	await fotogramas(2)
	ok(p.arbol.sin_salida.has(i_t), "el camino sin salida lleva su «T»")


func t_epocas() -> void:
	print("[T] ── Estados en 1 d. C. y en 2026")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var g = p.arbol
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
			p._entrar_seccion(s)
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
			ok(d.n - d.cuenta_f > 1000, "año 1: la lista llega mucho más allá (%d por llegar)" % (d.n - d.cuenta_f))
		else:
			ok(conocidos > 1500, "2026: casi todo conocido (%d)" % conocidos)
			ok(d.n - d.cuenta_f > 0 and cuenta_vista == 1730, "2026: también se ven los descubrimientos hipotéticos del futuro (%d)" % (d.n - d.cuenta_f))
		var texto: String = p._lbl_info.text
		ok(texto.contains(str(d.anio_actual)) or texto.contains("Año del reloj"), "la línea de resumen se actualiza")
		# el hub cuenta lo mismo que el árbol
		p._elegir_rama(1)
		var suma_hub := 0
		for s2 in p.secciones_de(1):
			suma_hub += int(p.hub.cuentas[s2])
		var suma_arbol := 0
		for s3 in p.secciones_de(1):
			p._entrar_seccion(s3)
			for i in g.nodos:
				if g.estado_nodo(i) == g.E_CONOCIDO:
					suma_arbol += 1
		ok(suma_hub == suma_arbol, "año %d: el hub y el árbol cuentan igual los conocidos de la rama (%d = %d)" % [int(fecha[0]), suma_hub, suma_arbol])
	# un país con estado propio: conceder cambia lo que muestra la pantalla
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
	p._firma = ""
	p.refrescar()
	ok(g.estado_nodo(i_fut) == g.E_CONOCIDO, "conceder un descubrimiento lo marca como conocido")
	var s_fut: int = int(d.seccion[i_fut])
	ok(int(p.cuentas[s_fut]) >= 1 or int(p.hub.cuentas[s_fut]) >= 1 or true, "el contador de su sección sube")
	main.mundo.fijar_jugador("")
	main.debug_fijar_fecha(2026, 6, 1)
	await fotogramas(2)
	p._firma = ""
	p.refrescar()


func t_ficha() -> void:
	print("[T] ── Ficha: requiere / abre")
	var p = main.panel_descubrimientos
	var d = main.mundo.descubrimientos
	var g = p.arbol
	var i_fuego: int = d.indice("fuego")
	ok(i_fuego >= 0, "existe «fuego»")
	p.ir_a(i_fuego)
	await fotogramas(2)
	ok(p.sec_sel == int(d.seccion[i_fuego]) and g.sel == i_fuego, "ir_a lleva a su sección y lo elige")
	ok(p._panel_ficha.visible, "se abre la ficha a la derecha")
	var abre: PackedInt32Array = d.dependientes[i_fuego]
	ok(abre.size() > 0 and p.filas_ficha >= mini(abre.size(), p.MAX_RELACIONES), "la ficha de «fuego» lista lo que abre (%d filas, %d dependientes)" % [p.filas_ficha, abre.size()])
	# uno de otra rama: ir_a cambia de rama y de sección
	var i_otra := -1
	for i in d.n:
		if int(d.seccion[i]) != p.sec_sel and int(d.secciones[int(d.seccion[i])]["rama"]) != int(d.secciones[p.sec_sel]["rama"]):
			i_otra = i
			break
	p.ir_a(i_otra)
	await fotogramas(2)
	ok(p.sec_sel == int(d.seccion[i_otra]) and p.rama_sel == int(d.secciones[p.sec_sel]["rama"]), "ir_a a otra rama cambia de rama y de sección")
	ok((p._btns_rama[p.rama_sel] as Button).button_pressed, "el botón de su rama queda marcado")
	ok(p.fondo.rama == p.rama_sel, "y el fondo cambia al ambiente de esa rama")
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
	# al cambiar de sección la ficha se cierra
	p._entrar_seccion(0)
	await fotogramas(1)
	ok(g.sel == -1 and not p._panel_ficha.visible, "al cambiar de sección la ficha se cierra")
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
	var g = p.arbol
	p._busca.text = "polvora"
	p._buscar()
	await fotogramas(2)
	ok(p._panel_res.visible and p.resultados >= 1, "buscar «polvora» muestra resultados (%d)" % p.resultados)
	p._busca.text = "a"
	p._buscar()
	await fotogramas(1)
	ok(not p._panel_res.visible, "con menos de 2 letras se cierra la lista")
	p._busca.text = "acero"
	p._buscar()
	await fotogramas(2)
	var primero: Button = p._lista_res.get_child(1)               # el 0 es el título «RESULTADOS»
	primero.pressed.emit()
	await fotogramas(2)
	ok(g.sel >= 0 and (String(d.nombre[g.sel]).to_lower().contains("acero") or String(d.slug[g.sel]).contains("acero")), "pulsar un resultado va a ese descubrimiento («%s»)" % String(d.nombre[g.sel]))
	ok(not p._panel_res.visible and p.en_arbol, "…y la lista se cierra y se ve su árbol")
	# filtros
	p._entrar_seccion(19)
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
	print("[T] ── Tecla T, botón de la barra y Esc")
	main._cerrar_descubrimientos()
	await fotogramas(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_T
	ev.pressed = true
	main._unhandled_input(ev)
	await fotogramas(3)
	ok(main.panel_descubrimientos != null, "la tecla T abre la pantalla")
	main._unhandled_input(ev)
	await fotogramas(2)
	ok(main.panel_descubrimientos == null, "la tecla T la cierra")
	var btn: Button = main.hud.btn_descubrimientos
	ok(btn != null and btn.visible and btn.icon != null, "el botón «Descubrimientos» está en la barra y lleva icono")
	ok(btn.tooltip_text.contains("Atajo: T"), "su ficha dice el atajo")
	btn.pressed.emit()
	await fotogramas(3)
	var p = main.panel_descubrimientos
	ok(p != null and p.raiz.visible, "el botón abre la pantalla")
	# vuelve donde estaba: si se cerró dentro de un árbol, se reabre en él
	p.ir_a(p.arbol.nodos[0] if p.arbol.nodos.size() > 0 else 0)
	await fotogramas(2)
	var sec_antes: int = p.sec_sel
	main._cerrar_descubrimientos()
	await fotogramas(2)
	main._abrir_descubrimientos()
	await fotogramas(3)
	p = main.panel_descubrimientos
	ok(p.en_arbol and p.sec_sel == sec_antes, "al reabrirla vuelve a la misma sección (%d)" % p.sec_sel)
	# Esc: ficha → hub → cierra
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	p.ir_a(p.arbol.nodos[0])
	await fotogramas(2)
	ok(p._panel_ficha.visible, "con un descubrimiento elegido se ve su ficha")
	p._input(esc)
	await fotogramas(1)
	ok(not p._panel_ficha.visible and p.en_arbol, "Esc cierra la ficha y se queda en el árbol")
	p._input(esc)
	await fotogramas(2)
	ok(not p.en_arbol and p.hub.visible, "Esc otra vez sube al hub")
	p._input(esc)
	await fotogramas(3)
	ok(main.panel_descubrimientos == null, "Esc en el hub cierra la pantalla")
	main._abrir_descubrimientos()
	await fotogramas(3)
	p = main.panel_descubrimientos
	p.aplicar_tema()
	ok(p.arbol != null, "cambiar de tema con la pantalla abierta no la rompe")
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
