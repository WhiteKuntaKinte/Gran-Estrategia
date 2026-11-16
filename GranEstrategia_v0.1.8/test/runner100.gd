extends Node
## 0.1.8.45 · PRUEBAS DE LAS NOTAS DEL 15-11-2026 (el presupuesto se reescribió en la 0.1.8.46):
##  · Presupuesto de la simulación por REACCIÓN (0.1.8.46): usa el techo cuando cabe en la espera del VSync y se frena solo cuando alarga el fotograma.
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


## Un fotograma sintético: el periodo es lo que tarda el equipo en dibujar, o el periodo del monitor si es mayor, más la simulación que el juego se permita.
## Devuelve {fps, sim_us (media), periodo_us (media)} de los últimos 400 de `frames` fotogramas con la simulación siempre atrasada (x6).
## `tirones`: cada tantos fotogramas uno dura 100 ms (carga puntual, disco...).
func correr_modelo(periodo_monitor_us: float, trabajo_us: float, frames: int, tirones := 0) -> Dictionary:
	main._per_ema_us = 0.0
	main._sim_ema_us = 0.0
	main.periodo_monitor_us = periodo_monitor_us
	main._t_monitor = -1.0e9                                                  # que no relea el monitor real (en headless da 0)
	main.presupuesto_fot_us = main.SIM_MIN_US
	main.ms_fases = 0.0
	var sim_tot := 0.0
	var per_tot := 0.0
	var n := 0
	var delta := maxf(periodo_monitor_us, trabajo_us) / 1.0e6
	for f in frames:
		main._actualizar_periodo(delta)
		main.presupuesto_fot_us = main._presupuesto_fotograma()
		var sim := float(main.presupuesto_fot_us)
		main.ms_fases = sim / 1000.0
		var periodo := maxf(periodo_monitor_us, trabajo_us + sim)
		if tirones > 0 and f % tirones == 0:
			periodo += 100000.0
		delta = periodo / 1.0e6
		if f >= frames - 400:
			sim_tot += sim
			per_tot += periodo
			n += 1
	main.ms_fases = 0.0
	return {"fps": 1.0e6 / (per_tot / float(n)), "sim_us": sim_tot / float(n), "periodo_us": per_tot / float(n)}


func t_presupuesto() -> void:
	print("[T] ── Presupuesto de la simulación por fotograma (0.1.8.46: por reacción)")
	ok(AjustesScript.SIM_TOLERANCIA.size() == AjustesScript.SIM_PRESUPUESTO_US.size(), "una tolerancia por cada prioridad de simulación")
	ok(is_equal_approx(main.sim_tolerancia, 0.30), "Equilibrada: la simulación puede alargar el fotograma un 30 %% (%.2f)" % main.sim_tolerancia)
	ok(is_equal_approx(AjustesScript.tolerancia_sim({"sim_prio": 0}), 0.10) and is_equal_approx(AjustesScript.tolerancia_sim({"sim_prio": 2}), 0.60), "Fluidez 10 %, Velocidad del tiempo 60 %")
	var techo: int = main.presupuesto_us
	# 1. monitor de 60 Hz con VSync, el equipo dibuja en 4 ms: la simulación cabe en la espera, así que se queda con el techo y los FPS no bajan
	var a := correr_modelo(16667.0, 4000.0, 1500)
	ok(a["sim_us"] >= 0.92 * float(techo) and a["fps"] > 59.0, "60 Hz con VSync: la simulación usa el techo (%d de %d µs) y se mantienen los FPS (%.1f)" % [int(a["sim_us"]), techo, a["fps"]])
	# 2. monitor de 240 Hz y dibujo de 3 ms: la simulación puede llegar hasta la tolerancia (30 % sobre trabajo + mínimo) pero no más
	var b := correr_modelo(4167.0, 3000.0, 3000)
	ok(b["periodo_us"] <= (3000.0 + float(main.SIM_MIN_US)) * 1.33 and b["sim_us"] >= float(main.SIM_MIN_US), "240 Hz: el fotograma se alarga como mucho ~30 %% (%d µs de simulación, %.0f FPS)" % [int(b["sim_us"]), b["fps"]])
	ok(b["fps"] > 150.0, "240 Hz: no cae de 240 a ~70 FPS como en la 0.1.8.44 (%.0f FPS)" % b["fps"])
	# 3. sin VSync ni tope, dibujo de 4,2 ms: cada µs de simulación cuesta FPS, y la tolerancia lo limita
	var c := correr_modelo(0.0, 4200.0, 3000)
	ok(c["periodo_us"] <= (4200.0 + float(main.SIM_MIN_US)) * 1.33 and c["fps"] > 120.0, "sin tope: %.0f FPS con %d µs de simulación" % [c["fps"], int(c["sim_us"])])
	ok(c["sim_us"] > 2500.0, "…y la simulación no se queda en el mínimo: usa la tolerancia (%d µs)" % int(c["sim_us"]))
	# 4. PC flojo: 30 ms por fotograma, la simulación llega al techo como siempre
	var d := correr_modelo(0.0, 30000.0, 3000)
	ok(d["sim_us"] >= 0.9 * float(techo), "PC flojo (30 ms): la simulación usa el techo de siempre (%d µs)" % int(d["sim_us"]))
	# 5. más tolerancia = más simulación (Velocidad del tiempo > Equilibrada > Fluidez)
	var tol0: float = main.sim_tolerancia
	var us := []
	for t in AjustesScript.SIM_TOLERANCIA:
		main.sim_tolerancia = float(t)
		us.append(float(correr_modelo(0.0, 4200.0, 3000)["sim_us"]))
	main.sim_tolerancia = tol0
	ok(us[0] < us[1] and us[1] < us[2], "la prioridad ordena la simulación: %d < %d < %d µs" % [int(us[0]), int(us[1]), int(us[2])])
	# 6. con tirones sueltos de 100 ms (un fotograma de cada 97) el presupuesto no se desploma ni se dispara, y nunca sale de [mínimo, techo]
	var e := correr_modelo(0.0, 4200.0, 4000, 97)
	ok(e["sim_us"] >= float(main.SIM_MIN_US) and e["sim_us"] <= float(techo) and e["fps"] > 100.0, "con tirones sueltos de 100 ms: %d µs de simulación, %.0f FPS" % [int(e["sim_us"]), e["fps"]])
	# 7. el tiempo siempre avanza: ni siquiera con una pantalla lentísima el presupuesto baja del mínimo
	var f := correr_modelo(0.0, 90000.0, 800)
	ok(f["sim_us"] >= float(main.SIM_MIN_US) - 1.0 and f["sim_us"] <= float(techo), "PC lentísimo (90 ms): entre el mínimo y el techo (%d µs)" % int(f["sim_us"]))
	# 8. pausa y menú: ms_fases vuelve a 0 (el periodo medido es solo trabajo del equipo)
	main.ms_fases = 5.0
	main.en_pausa = true
	main._process(0.016)
	ok(main.ms_fases == 0.0, "en pausa no hay simulación que medir")
	main.en_pausa = false
	main._per_ema_us = 0.0
	main._sim_ema_us = 0.0
	main.periodo_monitor_us = 0.0
	main._t_monitor = 0.0
	main.presupuesto_fot_us = main.SIM_MIN_US


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
