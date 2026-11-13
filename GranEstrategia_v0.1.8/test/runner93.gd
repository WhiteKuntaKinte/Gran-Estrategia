extends Node
## 0.1.8.42 · PRUEBAS DE DIBUJO POR LOTES Y DE LA COSTA EN CALIDAD BAJA:
##  · `Tema.EstiloMetal.armar`: la caja entera (relleno, borde, filete, filo y acentos) es UNA malla válida (índices dentro de rango, múltiplo de 3, un color por vértice).
##  · `GrafoDescubrimientos`: ayudantes `_g_*` (rectángulo, marco, línea, cinta, disco, triángulo) producen mallas válidas; el árbol se dibuja y deja vacíos sus lotes.
##  · Costa: `_elegir_detalle_costa` con cada calidad (Detallada / media / baja) elige el nivel correcto por zoom y solo deja visible esa capa.
##    Con la calidad Baja el contorno ya no se fija al nivel lejano a todo zoom (rompía el borde de los países frente al relleno completo).
const Tema := preload("res://scripts/tema_hud.gd")
const GrafoScript := preload("res://scripts/grafo_descubrimientos.gd")
var main
var fallos := 0
var n_ok := 0


func _ready() -> void:
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


func malla_valida(m: Array) -> bool:
	var pos: PackedVector2Array = m[0]
	var col: PackedColorArray = m[1]
	var ind: PackedInt32Array = m[2]
	if pos.size() != col.size() or ind.size() % 3 != 0 or ind.is_empty():
		return false
	for k in ind:
		if k < 0 or k >= pos.size():
			return false
	return true


func t_estilo() -> void:
	var e := Tema.EstiloMetal.new()
	e.arriba = Color(0.9, 0.85, 0.7)
	e.abajo = Color(0.6, 0.5, 0.4)
	e.borde = Color(0.2, 0.1, 0.05)
	var m := e.armar(Rect2(0.0, 0.0, 120.0, 34.0))
	ok(malla_valida(m), "EstiloMetal básico: malla válida (%d vértices, %d triángulos)" % [(m[0] as PackedVector2Array).size(), (m[2] as PackedInt32Array).size() / 3])
	e.filete = Color(0.3, 0.2, 0.1, 0.6)
	e.acento = Color(1.0, 0.8, 0.2)
	e.acento_arriba = Color(0.2, 0.8, 1.0)
	var m2 := e.armar(Rect2(0.0, 0.0, 120.0, 34.0))
	ok(malla_valida(m2) and (m2[2] as PackedInt32Array).size() > (m[2] as PackedInt32Array).size(), "con filete y acentos: más triángulos, siempre una sola malla")
	e.corte = 0.0
	ok(malla_valida(e.armar(Rect2(0.0, 0.0, 80.0, 20.0))), "sin esquinas cortadas (rectángulo de 4 puntos): malla válida")
	ok(malla_valida(e.armar(Rect2(5.0, 5.0, 3.0, 3.0))), "caja diminuta (3×3 px): malla válida")
	var pos: PackedVector2Array = m[0]
	var dentro := true
	for p in pos:
		if p.x < -2.0 or p.y < -2.0 or p.x > 122.0 or p.y > 36.0:
			dentro = false
	ok(dentro, "la malla no se sale de la caja más de 2 px (suavizado incluido)")
	var col: PackedColorArray = m[1]
	var colores_altos := 0
	for c in col:
		if c.a > 0.99:
			colores_altos += 1
	ok(colores_altos > 8, "el borde y el relleno son opacos (el suavizado exterior es el único translúcido)")


func t_grafo() -> void:
	var g = GrafoScript.new()
	g._g_reiniciar()
	g._g_rect(Rect2(0.0, 0.0, 10.0, 10.0), Color.RED)
	g._g_marco(Rect2(0.0, 0.0, 40.0, 20.0), 2.0, Color.BLUE)
	g._g_linea(Vector2(0.0, 0.0), Vector2(30.0, 10.0), 2.0, Color.GREEN)
	g._g_tri(Vector2(0.0, 0.0), Vector2(5.0, 0.0), Vector2(0.0, 5.0), Color.WHITE)
	g._g_disco(Vector2(20.0, 20.0), 4.0, Color.ORANGE)
	var pts := PackedVector2Array()
	for k in 9:
		pts.append(Vector2(float(k) * 10.0, sin(float(k)) * 6.0))
	g._g_tira(pts, Vector2(2.0, 3.0), 1.5, 2.0, Color.GRAY, false)
	var m := [g._gp, g._gc, g._gi]
	ok(malla_valida(m), "ayudantes _g_*: malla válida (%d vértices, %d triángulos)" % [g._gp.size(), g._gi.size() / 3])
	var tri_antes: int = g._gi.size()
	g._g_tira(pts, Vector2.ZERO, 1.0, 2.0, Color.GRAY, true)
	ok(g._gi.size() - tri_antes == 4 * 6, "línea discontinua: la mitad de los tramos (4 de 8)")
	g._g_reiniciar()
	ok(g._gp.is_empty() and g._gc.is_empty() and g._gi.is_empty(), "_g_reiniciar vacía los lotes")
	g.free()
	# con el árbol real
	var d = main.mundo.descubrimientos
	var gr = GrafoScript.new()
	gr.size = Vector2(900.0, 500.0)
	gr.construir(d, ThemeDB.fallback_font, ThemeDB.fallback_font)
	add_child(gr)
	gr.fijar_seccion(0)
	gr.refrescar()
	await get_tree().process_frame
	await get_tree().process_frame
	ok(gr.dibujos > 0 and gr.nodos_dibujados > 0, "el árbol se dibuja con %d nodos a la vista" % gr.nodos_dibujados)
	ok(gr._gi.is_empty() and gr._tx.is_empty(), "al terminar el dibujo no quedan lotes sin emitir")
	gr.queue_free()


func t_costa() -> void:
	var n: int = main.capas_costa.size()
	ok(n == 3, "hay 3 niveles de costa (hay %d)" % n)
	var casos := [
		# [calidad costa_nivel_min, zoom real, nivel esperado]
		[0, 3.4, 0], [0, 2.3, 1], [0, 0.9, 2], [0, 1.1, 1],
		[1, 2.7, 1], [1, 2.9, 0], [1, 1.1, 2], [1, 1.2, 1],
		[2, 3.4, 0], [2, 3.0, 1], [2, 3.2, 0], [2, 1.2, 2], [2, 1.4, 1],
	]
	for c in casos:
		main.costa_nivel_min = c[0]
		main.costa_nivel = -1
		main._elegir_detalle_costa(float(c[1]))
		var vis := 0
		for i in n:
			if main.capas_costa[i] != null and main.capas_costa[i].visible:
				vis += 1
		ok(main.costa_nivel == c[2] and vis == 1, "costa calidad %d, zoom real %.1f → nivel %d (da %d, capas visibles %d)" % [c[0], c[1], c[2], main.costa_nivel, vis])
	var baja: Dictionary = main.AjustesScript.PRESETS[2]
	ok(int(baja["costa"]) == 2, "el preset Baja usa costa_nivel_min 2")
	# Baja ya NO es «nivel lejano a todo zoom»: de cerca (3,4) usa el nivel completo
	main.costa_nivel_min = 2
	main.costa_nivel = -1
	main._elegir_detalle_costa(3.4)
	ok(main.costa_nivel == 0, "Baja de cerca (zoom 3,4) dibuja la costa completa, igual que el relleno")
	main.costa_nivel_min = 0


func run() -> void:
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)
	t_estilo()
	await t_grafo()
	t_costa()
	print("[T] ═══ RESULTADO runner93: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)
