extends Node
## 0.1.8.45 · PRUEBAS DE LAS NOTAS DEL 15-11-2026:
##  · Presupuesto proporcional de la simulación: en un equipo rápido la simulación ya no se lleva 9 ms fijos por fotograma; en uno lento sigue el techo de siempre.
##  · Historial atrás / adelante de la pantalla de Descubrimientos.
##  · La cámara solo se acerca sola al país propio: un clic en un país ajeno lo enfoca (rótulo) sin mover la cámara.
const AjustesScript := preload("res://scripts/ajustes.gd")
const PantallaScript := preload("res://scripts/pantalla_descubrimientos.gd")

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
	t_presupuesto()
	await t_historial()
	await t_zoom()
	print("[T] ═══ RESULTADO runner100: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_presupuesto() -> void:
	print("[T] ── Presupuesto de la simulación por fotograma")
	ok(AjustesScript.SIM_FRACCION.size() == AjustesScript.SIM_PRESUPUESTO_US.size(), "una fracción por cada prioridad de simulación")
	ok(is_equal_approx(main.sim_fraccion, 0.35), "Equilibrada: la simulación usa hasta el 35 %% del fotograma (%.2f)" % main.sim_fraccion)
	main.ms_fases = 0.0
	var rapido: int = main._presupuesto_fotograma(1.0 / 240.0)                # equipo que dibuja a 240 FPS
	ok(rapido < 3000 and rapido >= main.SIM_MIN_US, "a 240 FPS la simulación pide ~2,2 ms y no 9 ms (%d µs)" % rapido)
	var lento: int = main._presupuesto_fotograma(1.0 / 30.0)                  # PC flojo a 30 FPS
	ok(lento == main.presupuesto_us, "a 30 FPS se queda con el techo de siempre (%d µs)" % lento)
	main.ms_fases = 4.0
	var con_sim: int = main._presupuesto_fotograma(0.013)                     # 13 ms de los que 4 fueron simulación: el resto (9 ms) es lo que cuenta
	ok(absi(con_sim - int(9000.0 * 0.35 / 0.65)) < 50, "descuenta la simulación del fotograma anterior al medir el resto (%d µs)" % con_sim)
	ok(main._presupuesto_fotograma(0.0) == main.SIM_MIN_US, "nunca baja del mínimo (%d µs): el tiempo siempre avanza" % main.SIM_MIN_US)
	main.ms_fases = 0.0


func t_historial() -> void:
	print("[T] ── Historial de Descubrimientos")
	PantallaScript.hist_vaciar()
	main._abrir_descubrimientos()
	await esperar(0.3)
	var p = main.panel_descubrimientos
	ok(p != null and p._btn_atras != null and p._btn_adelante != null, "la pantalla tiene los botones ◀ y ▶")
	ok(p._btn_atras.disabled and p._btn_adelante.disabled, "sin historial los dos están apagados")
	var d = p.d
	var a := -1
	for i in d.n:
		if d.req[i].size() > 0:
			a = i
			break
	ok(a >= 0, "hay un descubrimiento con prerrequisitos")
	var b: int = int(d.req[a][0])
	var c := -1
	for i in d.n:
		if int(d.seccion[i]) != int(d.seccion[b]):
			c = i
			break
	p.ir_a(a)
	p.ir_a(b)                                                                 # como pulsar su fila en «Requiere»
	p.ir_a(c)                                                                 # otro de otra sección
	ok(p.puede_atras() and not p.puede_adelante(), "tras ver 3, se puede ir atrás y no adelante")
	p.hist_atras()
	ok(p.arbol.sel == b and int(p.sec_sel) == int(d.seccion[b]), "atrás vuelve al anterior y a su sección")
	p.hist_atras()
	ok(p.arbol.sel == a and not p.puede_atras(), "atrás otra vez llega al primero")
	p.hist_adelante()
	ok(p.arbol.sel == b and p.puede_adelante(), "adelante vuelve a avanzar")
	p.ir_a(a)
	ok(not p.puede_adelante(), "abrir uno nuevo tras ir atrás corta lo de adelante")
	var n_antes: int = PantallaScript._hist.size()
	p.ir_a(a)
	ok(PantallaScript._hist.size() == n_antes, "abrir el mismo dos veces seguidas no lo repite")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_LEFT
	ev.alt_pressed = true
	p._input(ev)
	ok(p.arbol.sel == b, "Alt+← va atrás")
	main._cerrar_descubrimientos()
	await esperar(0.2)
	main._abrir_descubrimientos()
	await esperar(0.3)
	ok(main.panel_descubrimientos.puede_atras(), "el historial sigue al cerrar y volver a abrir la pantalla")
	main._cerrar_descubrimientos()
	await esperar(0.2)
	PantallaScript.hist_vaciar()


func t_zoom() -> void:
	print("[T] ── Zoom solo al país propio")
	var m = main.mundo
	var propio := ""
	var ajeno := ""
	for k in m.paises:
		if m.paises[k].provincias.size() > 3 and not m.es_inerte(k):
			if propio == "":
				propio = k
			elif ajeno == "":
				ajeno = k
				break
	m.fijar_jugador(propio)
	ok(m.jugador == propio, "controlo «%s»" % propio)
	ok(main._zoom_a_pais_permitido(propio) and not main._zoom_a_pais_permitido(ajeno), "solo el país propio permite el zoom automático")
	main.camara.zoom = Vector2(0.3, 0.3)                                       # tan lejos que antes cualquier país pedía acercarse
	ok(not main._foco_debe_mover(ajeno), "un país ajeno no mueve la cámara aunque se vea chico")
	ok(main._foco_debe_mover(propio), "el propio sí")
	var pos0: Vector2 = main.camara.position
	var z0: float = main.camara.zoom.x
	main._enfocar_pais(ajeno, main._foco_debe_mover(ajeno))
	await esperar(1.2)
	ok(main.pais_foco == ajeno, "el país ajeno queda enfocado y rotulado")
	ok(main.camara.position.distance_to(pos0) < 0.5 and is_equal_approx(main.camara.zoom.x, z0), "…y la cámara no se movió")
	main._salir_foco()
	m.fijar_jugador("")
	ok(main._zoom_a_pais_permitido(ajeno), "sin país (observador) todo se comporta como antes")
