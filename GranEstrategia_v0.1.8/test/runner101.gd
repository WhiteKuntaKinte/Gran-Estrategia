extends Node
## 0.1.8.46 · BANCO DE VELOCIDAD DEL MOTOR «EL PLANETA DESCUBRE» (scripts/saber.gd) con el reloj real y TODAS las IA activas.
## Imprime líneas «[B]» (ms por mes del motor, peor mes, coste de arrancar y días por segundo con y sin motor) y comprueba que el motor cueste poco:
## menos de 1,5 ms por mes de media y de 20 ms el peor mes (a x6 pasan 12 meses por segundo: 1,5 ms/mes son 18 ms por segundo de juego, un 2 %).
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


func arrancar(anio: int) -> float:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await esperar(0.3)
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	Engine.set_meta("semilla_partida", 2026)
	if anio != 2026:
		Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": anio})
	var t0 := Time.get_ticks_usec()
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)
	return float(Time.get_ticks_usec() - t0) / 1000.0


func banco(anio: int, anios: int) -> void:
	var ms_carga := await arrancar(anio)
	var m = main.mundo
	var sb = m.saber
	m.ia.activar_lista(m.ia.candidatos())
	var t_ini: int = Time.get_ticks_usec()
	main.debug_avanzar_dias(int(365.25 * float(anios)))
	var seg := float(Time.get_ticks_usec() - t_ini) / 1.0e6
	var dias := 365.25 * float(anios)
	var us_mes := float(sb.us_total) / maxf(float(sb.meses_corridos), 1.0)
	print("[B] época %d · %d años con %d IA: %.1f s (%.0f días/s) · motor: %.2f ms por mes, peor %.1f ms, %d descubiertos, %d contagios, %d contactos en cola · carga+arranque %.0f ms" % [
		anio, anios, m.ia.activas.size(), seg, dias / seg, us_mes / 1000.0, float(sb.us_max) / 1000.0, sb.n_descubiertos, sb.n_contagios, sb._pend.size(), ms_carga])
	ok(us_mes < 1500.0 and sb.us_max < 20000, "%d: el motor cuesta %.2f ms por mes (peor %.1f ms)" % [anio, us_mes / 1000.0, float(sb.us_max) / 1000.0])
	ok(sb.meses_corridos >= anios * 12 - 1, "%d: corrió los %d meses del reloj" % [anio, sb.meses_corridos])
	# lo mismo con el motor apagado: la diferencia de días por segundo es lo que cuesta de verdad (ruido de ±10 %: solo informativo)
	sb.desactivar()
	var t2: int = Time.get_ticks_usec()
	main.debug_avanzar_dias(int(365.25 * 2.0))
	var seg2 := float(Time.get_ticks_usec() - t2) / 1.0e6
	print("[B] época %d · 2 años más con la historia fija: %.1f s (%.0f días/s)" % [anio, seg2, 365.25 * 2.0 / seg2])
	m.ia.desactivar_todas()


func run() -> void:
	await banco(2026, 2)
	await banco(1500, 4)
	print("[T] ═══ RESULTADO runner101: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)
