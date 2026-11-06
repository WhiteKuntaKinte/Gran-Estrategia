extends Node
## BANCO DE ZOOM (0.1.8.38): simula la rueda del ratón (paso a paso, un paso por fotograma) y mide lo que cuesta cada paso: el reajuste de zoom del mapa
## (`ms_zoom`), todo el `_process` del mapa y el tiempo del fotograma (promedio, p95 y máximo = el «bajón» que se nota). No comprueba nada: imprime líneas «[Z]».
## Escenarios: mundo sin elegir nada · país enfocado y elegido (el de más provincias) · lo mismo con la vista de Relieve.
## Con pantalla virtual (xvfb) incluye el dibujo por software (solo vale para comparar) y con --headless solo el coste de los scripts.
var main


func esperar(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func zoomear(nombre: String, z_ini: float, z_fin: float, pasos: int) -> void:
	main.camara.zoom = Vector2(z_ini, z_ini)
	await esperar(6)
	var f := pow(z_fin / z_ini, 1.0 / float(pasos))
	var tiempos: Array = []
	var zooms: Array = []
	var procs: Array = []
	var draws := 0.0
	var t_prev := Time.get_ticks_usec()
	for i in pasos * 2:
		main._zoom_en_cursor(f if i < pasos else 1.0 / f)
		await get_tree().process_frame
		var t := Time.get_ticks_usec()
		tiempos.append(float(t - t_prev) / 1000.0)
		t_prev = t
		zooms.append(float(main.ms_zoom))
		procs.append(float(main.ms_proceso))
		draws += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var ord := tiempos.duplicate()
	ord.sort()
	var prom := func(a: Array) -> float:
		var s := 0.0
		for v in a:
			s += float(v)
		return s / float(a.size())
	var mx := func(a: Array) -> float:
		var m := 0.0
		for v in a:
			m = maxf(m, float(v))
		return m
	print("[Z] %-34s fotograma: prom %6.1f p95 %6.1f máx %6.1f ms · _actualizar_zoom: prom %5.2f máx %5.2f · _process: prom %5.2f máx %5.2f · draws %4.0f" % [
		nombre, prom.call(tiempos), ord[int(ord.size() * 0.95)], mx.call(tiempos), prom.call(zooms), mx.call(zooms), prom.call(procs), mx.call(procs), draws / float(tiempos.size())])


func run() -> void:
	await get_tree().create_timer(1.0).timeout
	get_window().size = Vector2i(1280, 720)
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	main._iniciar_partida({"modo": "dev", "epoca": 2026})
	await get_tree().create_timer(0.7).timeout
	main._poner_velocidad(0)
	main.camara.position = Vector2(1300.0, 380.0)
	await zoomear("mundo · nada elegido", 0.45, 4.0, 30)
	await zoomear("mundo · nada elegido (otra vez)", 0.45, 4.0, 30)
	# país con más provincias, enfocado y elegido
	var mejor := ""
	var n_mejor := 0
	for k in main.mundo.paises:
		var n: int = main.mundo.paises[k].provincias.size()
		if n > n_mejor:
			n_mejor = n
			mejor = k
	main.camara.zoom = Vector2(0.9, 0.9)
	main._enfocar_pais(mejor, false)
	var bb: Rect2 = main._bbox_foco(mejor)
	main.camara.position = bb.get_center()
	var t_sel := Time.get_ticks_usec()
	main._seleccion_pais(mejor, "Europa", bb.get_center())
	print("[Z] elegir el país (primera vez, sin caché): %.1f ms" % (float(Time.get_ticks_usec() - t_sel) / 1000.0))
	main._limpiar_seleccion()
	t_sel = Time.get_ticks_usec()
	main._seleccion_pais(mejor, "Europa", bb.get_center())
	print("[Z] elegir el país (segunda vez, con caché): %.1f ms" % (float(Time.get_ticks_usec() - t_sel) / 1000.0))
	await esperar(30)
	print("[Z] país elegido: %s (%d provincias)" % [mejor, n_mejor])
	await zoomear("país enfocado y elegido", 0.9, 5.0, 30)
	await zoomear("país enfocado y elegido (otra vez)", 0.9, 5.0, 30)
	if main.has_method("_poner_modo_relieve"):
		main._poner_modo_relieve(true)
		await esperar(10)
		await zoomear("país elegido + vista de Relieve", 0.9, 5.0, 30)
		main._poner_modo_relieve(false)
	get_tree().quit()


func _ready() -> void:
	run.call_deferred()
