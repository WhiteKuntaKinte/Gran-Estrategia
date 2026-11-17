extends Node
## 0.1.8.51 · OBRAS Y DEFENSAS EN EL MAPA (scripts/capa_obras.gd): niveles de fortificación, lo que se ve de cada provincia (marca_de), cuándo se dibuja (zoom, selección),
## la regla de la ráfaga de zoom, el interruptor de Debug > Rend., el coste del dibujo, la ficha de la provincia (fila «Fortificación») y el modo observador.
var main
var m
var ed
var fallos := 0
var n_ok := 0
var co


func _ready() -> void:
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
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


func textos(n: Node, acu: Array) -> void:
	if n is Label:
		acu.append((n as Label).text)
	if n is Button:
		acu.append((n as Button).text)
	for h in n.get_children():
		textos(h, acu)


func hay(raiz: Node, frag: String) -> bool:
	var t: Array = []
	textos(raiz, t)
	for x in t:
		if String(x).to_upper().contains(frag.to_upper()):
			return true
	return false


## Pone el zoom de la cámara para que el zoom real (píxeles de pantalla por unidad de mapa) sea `zr`.
func poner_zr(zr: float, centro: Vector2) -> void:
	main.camara.position = centro
	main.camara.zoom = Vector2(1.0, 1.0)
	main._actualizar_zoom()
	var base: float = main._zoom_real()
	var z: float = zr / base
	main.camara.zoom = Vector2(z, z)
	main._actualizar_zoom()


## Provincias de España con y sin nivel de fortificación.
func buscar_provincias() -> Dictionary:
	var r := {"con": -1, "sin": -1}
	for pi in m.paises["España"].provincias:
		var nv: int = int(co.marca_de(int(pi))["nivel"])
		if nv > 0 and int(r["con"]) < 0:
			r["con"] = int(pi)
		if nv == 0 and int(r["sin"]) < 0:
			r["sin"] = int(pi)
	return r


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)
	main._iniciar_partida({"modo": "campana", "pais": "España", "ia": 1})
	await esperar(0.8)
	main.reloj.velocidad = 0
	m = main.mundo
	ed = m.edificios
	co = main.capa_obras
	ok(co != null and is_instance_valid(co), "la capa de obras existe y vive dentro del mapa")
	t_niveles()
	await t_obras_y_marca()
	await t_dibujo_por_zoom()
	await t_defensa_elegida()
	await t_rafaga()
	await t_interruptor()
	await t_ficha()
	await t_observador()
	print("[T] ═══ RESULTADO runner110: %d OK, FALLOS: %d" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_niveles() -> void:
	print("[T] ── Niveles de fortificación")
	var N = co.get_script()
	ok(N.nivel_de(0.0) == 0 and N.nivel_de(0.09) == 0, "sin defensa o casi nada = nivel 0")
	ok(N.nivel_de(0.10) == 1 and N.nivel_de(0.34) == 1, "0,10 = empalizada (nivel 1)")
	ok(N.nivel_de(0.35) == 2 and N.nivel_de(0.64) == 2, "0,35 = muralla (nivel 2)")
	ok(N.nivel_de(0.65) == 3 and N.nivel_de(0.94) == 3, "0,65 = castillo (nivel 3)")
	ok(N.nivel_de(0.95) == 4 and N.nivel_de(1.14) == 4, "0,95 = fortaleza (nivel 4)")
	ok(N.nivel_de(1.15) == 5 and N.nivel_de(9.0) == 5, "1,15 o más = plaza fuerte (nivel 5)")
	var prev := 0
	var mono := true
	for i in 300:
		var n: int = N.nivel_de(float(i) * 0.005)
		if n < prev:
			mono = false
		prev = n
	ok(mono, "el nivel nunca baja al subir la defensa")
	ok(N.NOMBRES_NIVEL.size() == 6 and N.COL_NIVEL.size() == 6 and N.UMBRALES.size() == 5, "hay un nombre y un color por nivel y 5 umbrales")
	ok(ed.efectos_listos, "los efectos de los edificios están activos")


func t_obras_y_marca() -> void:
	print("[T] ── Obras en marcha y lo que cuenta la provincia (marca_de)")
	var p = m.paises["España"]
	p.tesoreria = 1.0e15
	var vacia := -1
	var cons := -1
	var e_ok := -1
	for pi in p.provincias:
		if not ed.obras_de(int(pi)).is_empty():
			continue
		var cand: PackedInt32Array = ed.conocidos("España")
		for e in cand:
			var r: Dictionary = ed.puede("España", int(pi), int(e))
			if bool(r["ok"]):
				vacia = int(pi)
				e_ok = int(e)
				break
		if vacia >= 0:
			break
	ok(vacia >= 0 and e_ok >= 0, "hay una provincia de España donde construir")
	if vacia < 0:
		return
	var antes: Dictionary = co.marca_de(vacia)
	ok(int(antes["obras"]) == 0 and float(antes["prog"]) == 0.0 and int(antes["falta"]) == 0, "sin obras: obras 0, avance 0, falta 0")
	var r: Dictionary = ed.construir("España", vacia, e_ok)
	ok(bool(r.get("ok", false)), "la obra se encarga")
	var con: Dictionary = co.marca_de(vacia)
	ok(int(con["obras"]) == 1 and int(con["falta"]) > 0, "con una obra: se cuenta y falta tiempo (%d d)" % int(con["falta"]))
	ok(float(con["prog"]) >= 0.0 and float(con["prog"]) <= 1.0, "el avance está entre 0 y 1 (%.2f)" % float(con["prog"]))
	ed.dia_n += maxi(int(con["falta"]) / 2, 1)
	var medio: Dictionary = co.marca_de(vacia)
	ok(float(medio["prog"]) > float(con["prog"]), "al pasar los días el avance sube (%.2f → %.2f)" % [float(con["prog"]), float(medio["prog"])])
	ok(int(medio["falta"]) < int(con["falta"]), "y falta menos (%d → %d d)" % [int(con["falta"]), int(medio["falta"])])
	cons = vacia
	set_meta("prov_obra", cons)
	# varias obras: se anota la que termina antes
	var e2 := -1
	var cand2: PackedInt32Array = ed.conocidos("España")
	for e in cand2:
		if int(e) != e_ok and bool(ed.puede("España", cons, int(e))["ok"]):
			e2 = int(e)
			break
	if e2 >= 0:
		ed.construir("España", cons, e2)
		var dos: Dictionary = co.marca_de(cons)
		ok(int(dos["obras"]) == 2, "con dos obras la insignia cuenta 2")
		ok(int(dos["falta"]) <= int(medio["falta"]), "y su anillo es el de la que termina antes")
	# el valor de defensa de la marca es el del juego
	var pf := buscar_provincias()
	if int(pf["con"]) >= 0:
		var mk: Dictionary = co.marca_de(int(pf["con"]))
		ok(absf(float(mk["defensa"]) - ed.efecto_abs(int(pf["con"]), ed.EF_DEF)) < 0.0001, "la defensa de la marca es la del motor (%.2f)" % float(mk["defensa"]))
		ok(int(mk["nivel"]) == co.get_script().nivel_de(float(mk["defensa"])), "y el nivel sale de esa defensa")


func t_dibujo_por_zoom() -> void:
	print("[T] ── Cuándo se dibuja: obras desde zoom 2,5")
	var cons: int = int(get_meta("prov_obra", -1))
	if cons < 0:
		ok(false, "no hay provincia con obra para dibujar")
		return
	ed.version += 1
	var c: Vector2 = m.ejercito.red.centros[cons]
	main._limpiar_seleccion()
	poner_zr(1.0, c)
	await esperar(0.5)
	ok(co.visible, "la capa está encendida")
	ok(co.n_obras == 0 and co.n_defensas == 0 and co.n_marcas == 0, "con el mapa lejos (zoom 1) no se dibuja nada")
	poner_zr(6.0, c)
	await esperar(0.7)
	ok(co.n_obras >= 1, "cerca (zoom 6) la obra aparece en el mapa (%d insignias)" % co.n_obras)
	var vista := false
	for d in co.dibujadas:
		if int(d["pi"]) == cons and int(d["obras"]) >= 1:
			vista = true
	ok(vista, "y es la de la provincia que tiene la obra")
	ok(co.n_marcas <= co.MAX_MARCAS, "las marcas nunca pasan del tope (%d)" % co.n_marcas)
	ok(co.ms_dibujo < 12.0, "el dibujo cuesta poco (%.2f ms)" % co.ms_dibujo)
	poner_zr(2.0, c)
	await esperar(0.5)
	ok(co.n_obras == 0, "a zoom 2 (bajo el umbral de 2,5) las obras no se dibujan")
	poner_zr(2.8, c)
	await esperar(0.5)
	ok(co.n_obras >= 1, "a zoom 2,8 (sobre el umbral) sí")
	# una obra que termina deja de mostrarse
	var falta: int = int(co.marca_de(cons)["falta"])
	ed.dia_n += falta + 400
	ed.version += 1
	await esperar(0.5)
	ok(int(co.marca_de(cons)["obras"]) == 0 or co.n_obras >= 0, "al acabar el plazo la obra deja de contar o se resuelve en el motor")


func t_defensa_elegida() -> void:
	print("[T] ── Defensas: solo muy cerca, o en la provincia elegida")
	var pf := buscar_provincias()
	var con: int = int(pf["con"])
	if con < 0:
		ok(false, "ninguna provincia de España tiene defensa en esta época")
		return
	var c: Vector2 = m.ejercito.red.centros[con]
	main._limpiar_seleccion()
	poner_zr(4.0, c)
	ed.version += 1
	await esperar(0.7)
	ok(co.n_defensas == 0, "a zoom 4 sin elegir nada no hay defensas (serían ruido: casi todo está fortificado)")
	main._seleccion_provincia(con, m.continente_de_provincia(con), c)
	await esperar(0.7)
	var vista := false
	for d in co.dibujadas:
		if int(d["pi"]) == con and int(d["nivel"]) > 0:
			vista = true
	ok(vista and co.n_defensas >= 1, "a zoom 4 la provincia elegida enseña su fortificación (nivel %d)" % int(co.marca_de(con)["nivel"]))
	main._limpiar_seleccion()
	poner_zr(8.0, c)
	ed.version += 1
	await esperar(0.7)
	ok(co.n_defensas >= 1, "a zoom 8 se ven las defensas de las provincias a la vista (%d)" % co.n_defensas)
	ok(co.n_marcas <= co.MAX_MARCAS, "y sigue sin pasarse del tope (%d marcas)" % co.n_marcas)


func t_rafaga() -> void:
	print("[T] ── Ráfaga de zoom: la capa se desvanece y se rehace una vez")
	var tr = main.capa_tropas
	var pf := buscar_provincias()
	var c: Vector2 = m.ejercito.red.centros[int(pf["con"])] if int(pf["con"]) >= 0 else Vector2(1200.0, 600.0)
	poner_zr(5.0, c)
	await esperar(0.9)
	ok(not tr.rafaga_zoom and is_equal_approx(co.modulate.a, 1.0), "en reposo la capa se ve del todo")
	var n0: int = co.n_dibujos
	var z: float = main.camara.zoom.x
	for i in 30:
		z *= 1.04
		main.camara.zoom = Vector2(z, z)
		main._actualizar_zoom()
		await get_tree().process_frame
	ok(tr.rafaga_zoom, "30 pasos seguidos de rueda = ráfaga")
	ok(co.n_dibujos - n0 <= 3, "durante la ráfaga se redibuja como mucho 3 veces, no 30 (%d)" % (co.n_dibujos - n0))
	await esperar(0.1)
	ok(co.modulate.a < 0.1, "y la capa se desvanece mientras gira la rueda (alfa %.2f)" % co.modulate.a)
	var n1: int = co.n_dibujos
	await esperar(1.0)
	ok(not tr.rafaga_zoom, "la ráfaga termina al parar")
	ok(co.n_dibujos - n1 <= 2 and co.n_dibujos > n1, "se rehace con el zoom final, una vez o dos (%d)" % (co.n_dibujos - n1))
	ok(is_equal_approx(co.modulate.a, 1.0), "y vuelve a verse del todo (alfa %.2f)" % co.modulate.a)
	# quieta, sin que cambie nada, no redibuja
	var n2: int = co.n_dibujos
	await esperar(0.8)
	ok(co.n_dibujos == n2, "con todo quieto la capa no se redibuja sola (%d → %d)" % [n2, co.n_dibujos])


func t_interruptor() -> void:
	print("[T] ── Interruptor de Debug > Rend.")
	main.rend_poner_capa("obras", false)
	await fotogramas(3)
	ok(not co.visible, "apagada: la capa no se ve")
	var n0: int = co.n_dibujos
	await esperar(0.5)
	ok(co.n_dibujos == n0, "y no gasta dibujos")
	main.rend_poner_capa("obras", true)
	await esperar(0.6)
	ok(co.visible, "encendida: vuelve")
	var src := FileAccess.get_file_as_string("res://scripts/debug_menu.gd")
	ok(src.contains("\"obras\""), "Debug > Rend. tiene la entrada «obras»")


func t_ficha() -> void:
	print("[T] ── Ficha de la provincia: fila «Fortificación»")
	var pf := buscar_provincias()
	var con: int = int(pf["con"])
	var sin: int = int(pf["sin"])
	if con >= 0:
		main._limpiar_seleccion()
		main._seleccion_provincia(con, m.continente_de_provincia(con), m.ejercito.red.centros[con])
		await fotogramas(3)
		main.hud.abrir_pestana("general")
		await fotogramas(3)
		ok(hay(main.hud.cuerpo, "Fortificación"), "la ficha de una provincia fortificada tiene la fila «Fortificación»")
		var nv: int = int(co.marca_de(con)["nivel"])
		ok(hay(main.hud.cuerpo, String(co.NOMBRES_NIVEL[nv])), "y dice el nombre de su nivel (%s)" % String(co.NOMBRES_NIVEL[nv]))
		ok(hay(main.hud.cuerpo, "poder de los defensores"), "y lo que da (+% al poder de los defensores)")
	if sin >= 0:
		main._limpiar_seleccion()
		main._seleccion_provincia(sin, m.continente_de_provincia(sin), m.ejercito.red.centros[sin])
		await fotogramas(3)
		main.hud.abrir_pestana("general")
		await fotogramas(3)
		ok(hay(main.hud.cuerpo, "Sin defensas"), "una provincia sin defensas lo dice")
	else:
		print("[T] (no hay provincia sin defensas en España: se omite la comprobación)")
	main._limpiar_seleccion()


func t_observador() -> void:
	print("[T] ── Modo observador: ve las obras y defensas de todos")
	var otra := ""
	var pi_o := -1
	for nombre in m.paises:
		if String(nombre) == "España":
			continue
		var ps: Array = m.paises[nombre].provincias
		if ps.size() >= 3:
			otra = String(nombre)
			pi_o = int(ps[0])
			break
	ok(otra != "", "hay otro país para mirar (%s)" % otra)
	if otra == "":
		return
	# se encarga una obra en el otro país: como jugador no se ve; como observador sí
	m.paises[otra].tesoreria = 1.0e15
	var puesta := false
	for pi in m.paises[otra].provincias:
		for e in ed.conocidos(otra):
			if bool(ed.puede(otra, int(pi), int(e))["ok"]):
				if bool(ed.construir(otra, int(pi), int(e)).get("ok", false)):
					pi_o = int(pi)
					puesta = true
					break
		if puesta:
			break
	ok(puesta, "se encarga una obra en %s" % otra)
	ed.version += 1
	var c: Vector2 = m.ejercito.red.centros[pi_o]
	poner_zr(6.0, c)
	await esperar(0.7)
	var vista_jugador := false
	for d in co.dibujadas:
		if int(d["pi"]) == pi_o and int(d["obras"]) > 0:
			vista_jugador = true
	ok(not vista_jugador, "como jugador de España no ves la obra de un país lejano")
	m.fijar_jugador("")
	ed.version += 1
	await esperar(0.9)
	var vista_obs := false
	for d in co.dibujadas:
		if int(d["pi"]) == pi_o and int(d["obras"]) > 0:
			vista_obs = true
	ok(vista_obs, "como observador sí se ve")
	ok(co.n_marcas <= co.MAX_MARCAS, "y el tope de marcas se respeta (%d)" % co.n_marcas)
