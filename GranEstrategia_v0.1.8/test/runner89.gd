extends Node
## BANCO DE RENDIMIENTO de los escenarios (0.1.8.34): arranque, memoria y coste por fotograma del mundo de 2026 frente al del año 1 d. C. (el mismo
## juego con otros datos), en tres encuadres (mundo, Europa, Roma de cerca), más el coste de simular días con todas las IA. No comprueba nada:
## imprime líneas «[B]» para comparar entre versiones.
## Con pantalla virtual (xvfb) incluye el dibujo por software (muy lento: solo vale para comparar) y con --headless solo el coste de los scripts.
var main


func mon(m) -> float:
	return float(Performance.get_monitor(m))


func medir(nombre: String, seg: float) -> void:
	var t_ini := Time.get_ticks_usec()
	var n := 0
	var dc := 0.0
	var prim := 0.0
	var proc := 0.0
	var mx := 0.0
	while float(Time.get_ticks_usec() - t_ini) / 1.0e6 < seg:
		await get_tree().process_frame
		dc += mon(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		prim += mon(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		proc += float(main.ms_proceso)
		mx = maxf(mx, float(main.ms_proceso))
		n += 1
	var tot := float(Time.get_ticks_usec() - t_ini) / 1000.0
	print("[B] %-30s ms/fot=%6.1f  scripts(_process)=%5.2f ms (máx %5.2f)  draws=%4.0f prims=%7.0f" % [nombre, tot / float(n), proc / float(n), mx, dc / float(n), prim / float(n)])


func arrancar(epoca: int) -> void:
	if main != null:
		main.queue_free()
		await get_tree().create_timer(0.3).timeout
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	if epoca != 2026:
		Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": epoca})    # como «Nueva partida» tras recargar la escena
	var m0 := mon(Performance.MEMORY_STATIC) / 1048576.0
	var t0 := Time.get_ticks_usec()
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var ms_carga := float(Time.get_ticks_usec() - t0) / 1000.0
	await get_tree().create_timer(0.6).timeout
	var t1 := Time.get_ticks_usec()
	if epoca == 2026:
		main._iniciar_partida({"modo": "dev", "epoca": epoca})
	var ms_ini := float(Time.get_ticks_usec() - t1) / 1000.0
	await get_tree().create_timer(0.7).timeout
	main._poner_velocidad(0)
	print("[B] época %d: carga de la escena %.0f ms · _iniciar_partida %.0f ms · memoria %.0f → %.0f MB · nodos %d · objetos %d · provincias %d" % [epoca, ms_carga, ms_ini, m0, mon(Performance.MEMORY_STATIC) / 1048576.0, int(mon(Performance.OBJECT_NODE_COUNT)), int(mon(Performance.OBJECT_COUNT)), main.provincias.size()])


func recorrer(epoca: int) -> void:
	await arrancar(epoca)
	var enc := {"mundo": [0.45, Vector2(1200.0, 600.0)], "europa": [0.9, Vector2(1300.0, 380.0)], "roma": [4.0, Vector2(1283.0, 321.0)]}
	for k in ["mundo", "europa", "roma"]:
		main.camara.zoom = Vector2(enc[k][0], enc[k][0])
		main.camara.position = enc[k][1]
		await get_tree().create_timer(0.5).timeout
		await medir("época %d · %s" % [epoca, k], 2.5)
	# arrastre de cámara y rueda (lo que más hace el jugador): 60 pasos de zoom
	main.camara.position = Vector2(1300.0, 380.0)
	var t0 := Time.get_ticks_usec()
	for i in 40:
		main.camara.zoom = Vector2(0.6 + 0.08 * i, 0.6 + 0.08 * i)
		main.camara.position.x += 6.0
		await get_tree().process_frame
	print("[B] época %d · 40 pasos de zoom+arrastre: %.1f ms/paso" % [epoca, float(Time.get_ticks_usec() - t0) / 1000.0 / 40.0])
	var m = main.mundo
	m.ia.activar_lista(m.ia.candidatos())
	var t2 := Time.get_ticks_usec()
	for i in 120:
		m.avanzar_dias(1)
	print("[B] época %d · simular 1 día con %d IA: %.2f ms" % [epoca, m.ia.activas.size(), float(Time.get_ticks_usec() - t2) / 1000.0 / 120.0])
	m.ia.desactivar_todas()


func _ready() -> void:
	run.call_deferred()


func run() -> void:
	await get_tree().create_timer(1.0).timeout
	get_window().size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()               # «-- --epoca=1»: solo esa época (cada una en su propio proceso, para comparar memoria sin arrastre)
	var epocas := [2026, 1]
	for a in args:
		if String(a).begins_with("--epoca="):
			epocas = [int(String(a).substr(8))]
	for e in epocas:
		await recorrer(e)
	get_tree().quit()
