extends Node
## 0.1.8.25 · PRUEBAS UNITARIAS de la interfaz y del reloj de pasos (0.1.8.3 en adelante):
## HUD (pestañas, modo compacto, botón de guerra, set_campana) · ventana flotante (cambiar_tam, _aplicar_tam, esquina ◢, encoger) ·
## Debug (_nueva_pagina, _pagina_ia) · capa de tropas (_tids_visibles, _color_de, _aviso_guerra) · MapaPrincipal (_poner_velocidad, _on_dia, _on_dia_diferido,
## _correr_fases, _vaciar_fases, cámara de campaña) · Mundo (eventos_de, _armar_balances, _economia_dia) · Ia (_estado_nuevo, registrar_paz, desactivar, _decidir) ·
## Ejercito (avanzar_mes por grupos, detener_marcha, _repartir_pais).
var main
var m
var g
var ia
var ej
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


func cerca(a: float, b: float, tol := 1e-9) -> bool:
	return absf(a - b) <= tol


func vecino() -> Array:
	## [tid propio, tid rival, provincia del rival, nombre del rival]
	var jt: int = m.paises["España"].tid
	for nv in ia.vecinos_de("España"):
		var rn := String(nv)
		if m.paises.has(rn) and not m.paises[rn].provincias.is_empty():
			return [jt, int(m.paises[rn].tid), int(m.paises[rn].provincias[0]), rn]
	return []


# ───────────────────────── HUD ─────────────────────────
func t_hud() -> void:
	print("[T] ── HUD")
	var hud = main.hud
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	await esperar(0.4)
	for clave in ["general", "diplomacia", "militar"]:
		ok(hud.abrir_pestana(clave), "abrir_pestana(%s) → true" % clave)
		var bien := true
		for t in hud.PESTANAS:
			var b: Button = hud.botones_pestana[t[0]]
			var activa: bool = t[0] == clave
			var t_ok: bool = (b.text.strip_edges() == String(t[1])) if activa else (b.text == "")
			var tip_ok: bool = b.tooltip_text == String(t[1])
			var r_ok: bool = cerca(b.size_flags_stretch_ratio, hud.TAB_RATIO_ACTIVA if activa else 1.0, 1e-5)
			if not (t_ok and tip_ok and r_ok):
				print("[T]   pestaña ", t[0], " activa=", activa, " texto=«", b.text, "» tip=«", b.tooltip_text, "» ratio=", b.size_flags_stretch_ratio)
			bien = bien and t_ok and tip_ok and r_ok
		ok(bien, "_estilizar_pestanas (%s): solo la abierta lleva texto y ancho %.1f; todas con tooltip" % [clave, hud.TAB_RATIO_ACTIVA])
	ok(not hud.abrir_pestana("no_existe"), "abrir_pestana con una clave inexistente → false (y no cambia nada)")
	ok(hud.pestana == "militar", "…la pestaña abierta sigue siendo la anterior")
	hud.abrir_pestana("general")
	await esperar(0.2)
	# modo compacto
	ok(not hud._compacto and hud.btn_compacto.text == "▾", "panel completo al empezar (botón ▾)")
	hud.poner_compacto(true)
	await esperar(0.2)
	ok(hud._compacto and hud.btn_compacto.text == "▸", "poner_compacto(true): botón ▸")
	var oculto := true
	for n in [hud.caja_migas, hud.bloque_tabs, hud.marco_seccion, hud.lbl_coord]:
		if n != null:
			oculto = oculto and not (n as Control).visible
	ok(oculto, "…migas, pestañas, contenido y coordenadas ocultos")
	hud.poner_compacto(true)
	ok(hud._compacto, "poner_compacto(true) dos veces no se rompe")
	hud.alternar_compacto()
	await esperar(0.2)
	var visible := true
	for n in [hud.caja_migas, hud.bloque_tabs, hud.marco_seccion]:
		if n != null:
			visible = visible and (n as Control).visible
	ok(not hud._compacto and hud.btn_compacto.text == "▾" and visible, "alternar_compacto: vuelve a abrirse (▾ y todo visible)")
	hud.alternar_compacto()
	ok(hud._compacto, "alternar_compacto de nuevo: se encoge")
	main._seleccion_pais("Francia", "Europa", Vector2(800, 300))
	await esperar(0.4)
	ok(hud._compacto and not hud.bloque_tabs.visible, "el modo compacto se recuerda al elegir otro país")
	hud.poner_compacto(false)
	await esperar(0.2)
	# set_campana
	hud.set_campana(false)
	ok(cerca(hud.panel.position.y, 40.0) and cerca(hud.panel_det.position.y, 40.0), "set_campana(false): el panel arranca en y = 40")
	hud.set_campana(true)
	ok(cerca(hud.panel.position.y, 74.0) and cerca(hud.panel_det.position.y, 74.0) and hud.btn_ranking.visible, "set_campana(true): panel en y = 74 (debajo de «Ranking»), botón visible")
	# botón de guerra
	var vb := VBoxContainer.new()
	add_child(vb)
	hud._guerra_pendiente = -1
	hud._boton_guerra(vb, "Francia", 77, true, "", 0)
	var b1: Button = vb.get_child(0)
	ok(b1.text == "Declarar la guerra a Francia" and not b1.disabled, "_boton_guerra: texto normal y activo")
	ok(b1.tooltip_text.begins_with("Declara la guerra a Francia"), "…con su tooltip")
	hud._boton_guerra(vb, "Francia", 77, true, "", 400)
	var b2: Button = vb.get_child(1)
	ok(b2.text.contains("tregua: %s" % main.texto_duracion(400)), "con tregua > 0 avisa de que se rompe: «%s»" % b2.text)
	hud._guerra_pendiente = 77
	hud._boton_guerra(vb, "Francia", 77, true, "", 400)
	var b3: Button = vb.get_child(2)
	ok(b3.text.begins_with("¿Seguro?") and not b3.text.contains("tregua"), "pendiente de confirmar: «¿Seguro?…» (sin el aviso de tregua)")
	ok(b3.get_theme_color("font_color", "Button") == hud.Tema.MAL, "…en rojo")
	hud._guerra_pendiente = -1
	var n_hijos := vb.get_child_count()
	hud._boton_guerra(vb, "Francia", 77, false, "Ya estás en guerra con Francia.", 0)
	var b4: Button = vb.get_child(n_hijos)
	ok(b4.disabled and b4.tooltip_text == "Ya estás en guerra con Francia.", "puede = false: botón apagado y su tooltip es el motivo")
	ok(vb.get_child_count() == n_hijos + 2 and (vb.get_child(n_hijos + 1) as Label).text == "Ya estás en guerra con Francia.", "…y debajo una nota con el motivo")
	hud._boton_guerra(vb, "Francia", 77, false, "", 0)
	ok(vb.get_child_count() == n_hijos + 3, "puede = false sin motivo: solo el botón apagado (sin nota vacía)")
	vb.queue_free()
	# _pulsar_guerra: un rival sin IA no se puede atacar
	var v := vecino()
	var rt: int = v[1]
	ia.desactivar(String(v[3]), false)
	hud._guerra_pendiente = -1
	hud._pulsar_guerra(rt)
	hud._pulsar_guerra(rt)
	await esperar(0.1)
	ok(hud._guerra_pendiente == -1 and String(hud._msg_guerra).contains("no tiene IA") and not g.en_guerra(int(v[0]), rt), "_pulsar_guerra 2.ª vez con un rival sin IA: no declara y deja el mensaje (%s)" % String(hud._msg_guerra).left(40))
	ia.activar(String(v[3]))
	# cambiar de país en Diplomacia olvida la confirmación pendiente
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	await esperar(0.3)
	hud.abrir_pestana("diplomacia")
	await esperar(0.2)
	hud._guerra_pendiente = 12345
	hud._msg_guerra = "viejo"
	main._seleccion_pais("Francia", "Europa", Vector2(800, 300))
	await esperar(0.4)
	hud.abrir_pestana("diplomacia")
	await esperar(0.2)
	ok(hud._guerra_pendiente == -1 and hud._msg_guerra == "" and hud._guerra_tid_vista == int(m.paises["Francia"].tid), "otro país elegido: se olvida la confirmación pendiente y el mensaje anterior")
	hud.abrir_pestana("general")


# ───────────────────────── Ventana flotante y Debug ─────────────────────────
func t_ventana() -> void:
	print("[T] ── Ventana flotante / Debug")
	main._abrir_debug()
	await esperar(0.5)
	var dm = main.debug_menu
	var vf = dm.vf
	var vp := get_viewport().get_visible_rect().size
	ok(vf.ventana.size.x <= 480.0, "el Debug arranca angosto (%d)" % vf.ventana.size.x)
	vf.cambiar_tam(Vector2(-5000.0, -5000.0))
	ok(vf._tam == vf.TAM_MIN and vf.ventana.size.x >= vf.TAM_MIN.x and vf.ventana.size.y >= vf.TAM_MIN.y, "cambiar_tam: nunca baja del mínimo %s (la ventana mide %s: no puede ser menor que su contenido)" % [vf.TAM_MIN, vf.ventana.size])
	vf.cambiar_tam(Vector2(5000.0, 5000.0))
	ok(vf.ventana.size.x <= vp.x - 8.0 and vf.ventana.size.y <= vp.y - 8.0, "cambiar_tam: no pasa de la pantalla (%s en %s)" % [vf.ventana.size, vp])
	ok(vf.ventana.position.x + vf.ventana.size.x <= vp.x + 0.5 and vf.ventana.position.y + vf.ventana.size.y <= vp.y + 0.5, "…y con `empujar` la ventana se corre para no salirse")
	ok(vf._tam == vf.ventana.size, "_aplicar_tam deja `_tam` y el tamaño real iguales")
	vf.cambiar_tam(Vector2(-5000.0, -5000.0))
	vf.cambiar_tam(Vector2(250.0, 400.0))                     # base cómoda (530 × 550): mayor que el mínimo del contenido
	vf.ventana.position = Vector2(100.0, 80.0)
	var base: Vector2 = vf.ventana.size
	vf.cambiar_tam(Vector2(70.0, 40.0), false)
	ok(vf.ventana.position == Vector2(100.0, 80.0) and vf.ventana.size == base + Vector2(70.0, 40.0), "cambiar_tam(…, empujar = false): crece sin mover la ventana")
	vf.ventana.position = Vector2(vp.x - 300.0, 80.0)
	vf.cambiar_tam(Vector2(5000.0, 0.0), false)
	ok(vf.ventana.position.x + vf.ventana.size.x <= vp.x + 0.5, "…y sin empujar el ancho se limita al espacio que queda a la derecha (%d)" % vf.ventana.size.x)
	# esquina ◢ (arrastre)
	vf.ventana.position = Vector2(50.0, 50.0)
	vf.cambiar_tam(Vector2(-5000.0, -5000.0))
	vf.cambiar_tam(Vector2(250.0, 400.0))
	var s0: Vector2 = vf.ventana.size
	var ev_dn := InputEventMouseButton.new()
	ev_dn.button_index = MOUSE_BUTTON_LEFT
	ev_dn.pressed = true
	vf._on_grip_input(ev_dn)
	var mv := InputEventMouseMotion.new()
	mv.relative = Vector2(30.0, 20.0)
	vf._on_grip_input(mv)
	ok(vf.ventana.size == s0 + Vector2(30.0, 20.0), "esquina ◢ pulsada: arrastrar (30, 20) agranda la ventana en (30, 20)")
	ok(vf.ventana.position == Vector2(50.0, 50.0), "…sin moverla")
	var ev_up := InputEventMouseButton.new()
	ev_up.button_index = MOUSE_BUTTON_LEFT
	ev_up.pressed = false
	vf._on_grip_input(ev_up)
	var s1: Vector2 = vf.ventana.size
	vf._on_grip_input(mv)
	ok(vf.ventana.size == s1, "esquina ◢ suelta: mover el ratón ya no cambia el tamaño")
	# barra de título (arrastrar mueve y no deja la ventana fuera)
	var ev_b := InputEventMouseButton.new()
	ev_b.button_index = MOUSE_BUTTON_LEFT
	ev_b.pressed = true
	vf._on_barra_input(ev_b)
	var mvb := InputEventMouseMotion.new()
	mvb.relative = Vector2(-5000.0, 5000.0)
	vf._on_barra_input(mvb)
	ok(vf.ventana.position.x >= 0.0 and vf.ventana.position.y <= vp.y - 40.0 + 0.5, "barra de título: la ventana no se puede sacar de la pantalla (%s)" % vf.ventana.position)
	ev_b.pressed = false
	vf._on_barra_input(ev_b)
	# encoger / expandir
	vf.ventana.position = Vector2(60.0, 60.0)
	vf.cambiar_tam(Vector2(-5000.0, -5000.0))
	vf.cambiar_tam(Vector2(120.0, 120.0))
	var ancho: float = vf.ventana.size.x
	vf._alternar_encogida()
	await esperar(0.1)
	ok(vf._encogida and vf._btn_encoger.text == "+" and not vf._cuerpo.visible and not vf._fila_grip.visible, "_alternar_encogida: botón «+», cuerpo y esquina ocultos")
	ok(cerca(vf.ventana.size.x, ancho) and vf.ventana.size.y < vf.TAM_MIN.y, "_aplicar_tam encogida: conserva el ancho y el alto queda en la barra (%s)" % vf.ventana.size)
	vf.cambiar_tam(Vector2(40.0, 100.0))
	ok(cerca(vf.ventana.size.x, ancho + 40.0) and vf.ventana.size.y < vf.TAM_MIN.y, "encogida: cambiar_tam solo cambia el ancho")
	vf._alternar_encogida()
	await esperar(0.1)
	ok(not vf._encogida and vf._btn_encoger.text == "–" and vf._cuerpo.visible and vf._fila_grip.visible and vf.ventana.size.y >= vf.TAM_MIN.y, "expandida otra vez: todo vuelve")
	# Debug: páginas
	ok(dm.paginas.has("ia") and dm.paginas["ia"] is ScrollContainer, "Debug: existe la página «IA» (ScrollContainer)")
	var pg = dm._nueva_pagina("prueba_unitaria")
	ok(pg is VBoxContainer and dm.paginas.has("prueba_unitaria") and not (dm.paginas["prueba_unitaria"] as ScrollContainer).visible, "_nueva_pagina: devuelve el VBox, la registra y nace oculta")
	ok((dm.paginas["prueba_unitaria"] as ScrollContainer).horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "…con barra horizontal automática (la ventana se puede angostar sin cortar el contenido)")
	ok(dm.lbl_ia_resumen != null and dm.lbl_ia_resumen is Label, "_pagina_ia: crea la etiqueta de resumen de IA")


# ───────────────────────── Capa de tropas ─────────────────────────
func t_tropas() -> void:
	print("[T] ── Capa de tropas")
	var capa = main.capa_tropas
	var v := vecino()
	var jt: int = v[0]
	var rt: int = v[1]
	var pi_rival: int = v[2]
	capa.refrescar()
	var vis: PackedInt32Array = capa._tids_visibles()
	ok(vis.size() == 1 and vis[0] == jt, "_tids_visibles con país: solo el propio (%s)" % str(vis))
	m.fijar_jugador("")
	capa.refrescar()
	await esperar(0.4)
	var vis2: PackedInt32Array = capa._tids_visibles()
	var todos := true
	for tv in capa._de_pais:
		todos = todos and vis2.has(int(tv))
	ok(vis2.size() == capa._de_pais.size() and vis2.size() > 10 and vis2.has(jt) and todos, "_tids_visibles observador: todos los países con tropas (%d de %d)" % [vis2.size(), capa._de_pais.size()])
	m.fijar_jugador("España")
	capa.refrescar()
	# _color_de
	capa._col_pais.clear()
	var c1: Color = capa._color_de("Francia")
	ok(c1.a == 1.0 and capa._col_pais.has("Francia"), "_color_de: opaco y guardado en la caché")
	capa._col_pais["Francia"] = Color(0.1, 0.2, 0.3, 1.0)
	ok(capa._color_de("Francia") == Color(0.1, 0.2, 0.3, 1.0), "…la 2.ª consulta usa la caché")
	capa._col_pais.clear()
	# _aviso_guerra
	var rid := -1
	for r in ej.regs_pais.get(jt, []):
		if not ej.en_marcha_reg(int(r)) and ej.soldados_reg(int(r)) > 0:
			rid = int(r)
			break
	ok(rid >= 0, "hay un regimiento propio para probar")
	capa.reg_prev = -1
	ok(capa._aviso_guerra(pi_rival) == "", "_aviso_guerra sin regimiento elegido: \"\"")
	capa.reg_prev = rid
	ok(capa._aviso_guerra(int(m.paises["España"].provincias[0])) == "", "provincia propia: sin aviso")
	var av: String = capa._aviso_guerra(pi_rival)
	ok(av.begins_with("Sin guerra con") and av.contains("Diplomacia"), "jugador y rival sin guerra: " + av)
	ia.desactivar(String(v[3]), false)
	var av2: String = capa._aviso_guerra(pi_rival)
	ok(av2.contains("no tiene IA"), "rival sin IA en la campaña: " + av2)
	ia.activar(String(v[3]))
	m.fijar_jugador("")
	var av3: String = capa._aviso_guerra(pi_rival)
	ok(av3.begins_with("¡GUERRA con"), "observador (sin país): «¡GUERRA con X!» como siempre: " + av3)
	m.fijar_jugador("España")
	var gid: int = g.declarar(jt, rt, "prueba")
	ok(capa._aviso_guerra(pi_rival) == "", "ya en guerra: sin aviso")
	g.paz(jt, rt, "prueba")
	ia.tregua.clear()
	capa.reg_prev = -1


# ───────────────────────── Reloj de pasos y cámara en MapaPrincipal ─────────────────────────
func t_reloj_mapa() -> void:
	print("[T] ── Reloj de pasos / cámara")
	main._poner_velocidad(5)
	ok(main.reloj.velocidad == 5 and m.ahorro and main.reloj.acum == 0.0, "_poner_velocidad(5): modo ahorro activo y acumulador a 0")
	ok(main.vel_previa == 5, "…y recuerda la velocidad previa")
	main._poner_velocidad(2)
	ok(main.reloj.velocidad == 2 and not m.ahorro, "_poner_velocidad(2): sin modo ahorro")
	main._poner_velocidad(99)
	ok(main.reloj.velocidad == main.RelojScript.VEL_MAX and m.ahorro, "_poner_velocidad(99) se acota a la máxima (%d)" % main.reloj.velocidad)
	main._poner_velocidad(-3)
	ok(main.reloj.velocidad == 0 and main.vel_previa == main.RelojScript.VEL_MAX, "_poner_velocidad(-3) = pausa, y la velocidad previa no se pierde")
	main._poner_velocidad(0)
	# _on_dia (de golpe)
	var d0: int = ia.dia_n
	main.reloj.fijar(2026, 3, 10)
	main._on_dia(false, false, 4)
	ok(ia.dia_n == d0 + 4, "_on_dia(k = 4): simula 4 días de golpe")
	ok(m.bd.fecha == main.BDScript.fecha_int(2026, 3, 10), "…y deja la fecha de la base igual a la del reloj")
	# _on_dia_diferido + _correr_fases + _vaciar_fases
	main._fases.clear()
	main.reloj.ocupado = false
	var d1: int = ia.dia_n
	main._on_dia_diferido(true, true, 2)
	ok(main._fases.size() == 3 + 6 and main.reloj.ocupado, "_on_dia_diferido(mes y año nuevo, k = 2): 3 fases mensuales + 6 del día, y el reloj queda ocupado (%d fases)" % main._fases.size())
	var n0: int = main._fases.size()
	main._correr_fases(0)
	ok(main._fases.size() < n0 and main._fases.size() >= n0 - 3, "_correr_fases(presupuesto 0): corre al menos una fase (%d → %d)" % [n0, main._fases.size()])
	main._vaciar_fases()
	ok(main._fases.is_empty() and not main.reloj.ocupado, "_vaciar_fases: termina lo pendiente y libera al reloj")
	ok(ia.dia_n == d1 + 2, "…y el día quedó simulado entero (2 días)")
	main._on_dia_diferido(false, false, 1)
	ok(main._fases.size() == 6, "sin cambio de mes: solo las 6 fases del día")
	var d2: int = ia.dia_n
	main._on_dia(false, false, 1)                       # un día nuevo termina primero el que estaba a medias
	ok(main._fases.is_empty() and not main.reloj.ocupado and ia.dia_n == d2 + 2, "_on_dia termina antes el día que estaba a medias: 1 + 1 = 2 días (IA +%d)" % (ia.dia_n - d2))
	main.reloj.ocupado = false
	main._fases.clear()
	# cámara de campaña
	var rect: Rect2 = main.campana_rect.grow(14.0)
	main.camara.position = Vector2(-99999.0, 99999.0)
	main._normalizar_camara()
	ok(rect.has_point(main.camara.position), "_normalizar_camara (campaña): la cámara vuelve al territorio (%s)" % main.camara.position)
	ok(main.camara.zoom.x >= main.campana_zoom_min - 1e-6, "…y el zoom no baja del mínimo que enseña toda la campaña")
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	main.camara.position = Vector2(0.0, 0.0)
	main._encuadrar_campana()
	ok(rect.has_point(main.camara.position), "_encuadrar_campana: la cámara queda dentro del territorio (%s)" % main.camara.position)
	ok(main.resaltado.is_empty(), "…y se limpia la selección")
	var cen: Vector2 = main.campana_rect.get_center()
	ok(main.camara.position.distance_to(cen) < 400.0, "…y cerca del centro de la campaña (%d de distancia)" % main.camara.position.distance_to(cen))
	var cam0 = main.camara
	var pos0: Vector2 = cam0.position
	main.camara = null
	main._encuadrar_campana()
	ok(cam0.position == pos0, "_encuadrar_campana sin cámara no hace nada (y no se rompe)")
	main.camara = cam0
	var vista: Dictionary = main.politica_vista()
	ok(vista.is_empty() or vista.has("jefe"), "politica_vista: {} o {jefe}")


# ───────────────────────── Mundo: sucesos y economía ─────────────────────────
func t_economia() -> void:
	print("[T] ── Mundo: sucesos y economía")
	var v := vecino()
	var jt: int = v[0]
	var rt: int = v[1]
	m.eventos.clear()
	m.evento(jt, "uno", rt)
	m.evento(rt, "dos", -1)
	m.evento(jt, "tres", -1)
	var e_j: Array = m.eventos_de(jt)
	ok(e_j.size() == 2 and e_j[0]["texto"] == "tres" and e_j[1]["texto"] == "uno", "eventos_de: los del país, el más reciente primero (%d)" % e_j.size())
	m.evento(jt, "cuatro", -1)
	ok(m.eventos_de(jt, 2).size() == 2 and m.eventos_de(jt).size() == 3, "eventos_de(máximo = 2) corta en 2 (sin máximo: 3)")
	ok(m.eventos_de(rt).size() == 2, "un suceso donde el país es «otro» también cuenta (%d)" % m.eventos_de(rt).size())
	ok(m.eventos_de(-5).is_empty(), "un país sin sucesos: lista vacía")
	m.eventos.clear()
	# _armar_balances
	m._armar_balances()
	var con_provs := 0
	for n in m.paises:
		if not m.paises[n].provincias.is_empty() and m.bd.idx(m.paises[n].tid) >= 0:
			con_provs += 1
	ok(m._bal.size() == con_provs and con_provs > 40, "_armar_balances: una fila por país con provincias (%d)" % m._bal.size())
	var f0: Array = m._bal[0]
	ok(f0.size() == 5 and f0[2] is String and float(f0[4]) >= 0.0, "…cada fila: [ID, fila en la base, nombre, ingreso, mantenimiento por soldado]")
	ok(m._bal_ver_eco == m.bd.version_eco and m._bal_ver_prop == m.bd.version_propietario and m._bal_mes == m._mes_n, "…y anota las versiones con las que se armó")
	# caché de balances: con `ahorro` solo se rehacen cada 3 meses (los dueños sí rehacen siempre)
	var guard_ahorro: bool = m.ahorro
	m.ahorro = true
	m.bd.version_eco += 1
	var bal_ref = m._bal
	m._economia_dia(1)
	ok(is_same(m._bal, bal_ref) and m._bal_ver_eco != m.bd.version_eco, "modo ahorro: cambió la economía pero no se rehacen los balances todavía")
	m._mes_n += 3
	m._economia_dia(1)
	ok(not is_same(m._bal, bal_ref) and m._bal_ver_eco == m.bd.version_eco, "…pasados 3 meses, sí")
	bal_ref = m._bal
	m.bd.version_propietario += 1
	m._economia_dia(1)
	ok(not is_same(m._bal, bal_ref), "un cambio de dueños rehace los balances enseguida (incluso en ahorro)")
	m.ahorro = false
	bal_ref = m._bal
	m.bd.version_eco += 1
	m._economia_dia(1)
	ok(not is_same(m._bal, bal_ref), "sin ahorro: cualquier cambio de la economía rehace los balances")
	m.ahorro = guard_ahorro
	# _economia_dia(k): k días de golpe = k × un día
	var pais = m.paises["Francia"]
	m._economia_dia(1)
	var t0: float = pais.tesoreria
	m._economia_dia(1)
	var t1: float = pais.tesoreria
	m._economia_dia(4)
	var t2: float = pais.tesoreria
	var d1: float = t1 - t0
	ok(absf(d1) > 0.0 and absf((t2 - t1) - 4.0 * d1) <= absf(d1) * 4.0 * 1e-6 + 1e-6, "_economia_dia(4) = 4 × _economia_dia(1) (%.1f vs %.1f)" % [t2 - t1, 4.0 * d1])
	# tesorería en rojo: deserción proporcional a los días
	var jug: String = "Francia"
	var tid_f: int = int(pais.tid)
	var sold0: int = ej.soldados_de_pais(tid_f)
	m._bal_ver_eco = -1
	pais.tesoreria = -1.0e12
	var des0: int = m.desertores_total
	m._economia_dia(1)
	ok(m.desertores_total > des0 and ej.soldados_de_pais(tid_f) < sold0, "tesorería en rojo: los soldados desertan (%d → %d)" % [sold0, ej.soldados_de_pais(tid_f)])
	ok(m._en_rojo.has(tid_f), "…y queda marcada «en rojo» (se avisa una sola vez)")
	var n_eventos: int = m.eventos.size()
	m._economia_dia(3)
	ok(m.eventos.size() == n_eventos, "…sin repetir el aviso al día siguiente")
	pais.tesoreria = 1.0e12
	m._economia_dia(1)
	ok(not m._en_rojo.has(tid_f), "con caja positiva sale del rojo")


# ───────────────────────── IA: estado, paz, desactivar, decidir ─────────────────────────
func t_ia2() -> void:
	print("[T] ── Ia: _estado_nuevo, registrar_paz, desactivar, _decidir")
	var v := vecino()
	var jt: int = v[0]
	var rt: int = v[1]
	var st: Dictionary = ia._estado_nuevo(rt)
	ok(st["tid"] == rt and float(st["cautela"]) >= 1.0 and float(st["cautela"]) <= 1.5, "_estado_nuevo: cautela entre 1,0 y 1,5 (%.3f)" % float(st["cautela"]))
	ok(int(st["proximo"]) >= ia.dia_n and int(st["proximo"]) < ia.dia_n + ia.PERIODO_PAZ, "…primera decisión repartida dentro de PERIODO_PAZ días (%d)" % (int(st["proximo"]) - ia.dia_n))
	ok(int(st["no_guerra_hasta"]) == ia.dia_n + ia.GRACIA_INICIAL, "…sin declarar guerras en sus primeros %d días" % ia.GRACIA_INICIAL)
	ok(not st.has("orden"), "…sin campos sin uso (se quitó «orden»)")
	var st2: Dictionary = ia._estado_nuevo(rt)
	ok(cerca(float(st["cautela"]), float(st2["cautela"])), "…determinista: el mismo país siempre tiene la misma cautela")
	for k in ["ini", "aviso_paz", "foto"]:
		ok(st[k] is Dictionary and st[k] != st2[k] or st[k].is_empty(), "…«%s» es un diccionario propio de cada estado" % k)
	(st["ini"] as Dictionary)[1] = 1
	ok((st2["ini"] as Dictionary).is_empty(), "…y no se comparte entre estados")
	# registrar_paz: descanso para las IA
	var nom_r := String(v[3])
	var paces0: int = ia.paces_firmadas
	ia.activas[nom_r]["no_guerra_hasta"] = 0
	ia.registrar_paz(jt, rt)
	ok(ia.paces_firmadas == paces0 + 1, "registrar_paz cuenta la paz firmada")
	ok(int(ia.activas[nom_r]["no_guerra_hasta"]) >= ia.dia_n + ia.DESCANSO_TRAS_PAZ, "…y la IA que firmó descansa %d días de guerras nuevas" % ia.DESCANSO_TRAS_PAZ)
	ia.activas[nom_r]["no_guerra_hasta"] = ia.dia_n + 99999
	ia.registrar_paz(jt, rt)
	ok(int(ia.activas[nom_r]["no_guerra_hasta"]) == ia.dia_n + 99999, "…nunca se acorta un descanso más largo")
	ia.activas[nom_r]["no_guerra_hasta"] = ia.dia_n + ia.GRACIA_INICIAL
	ia.tregua.clear()
	# desactivar: cierra o no las guerras
	var otro_nom := ""
	for nn in ia.activas:
		if nn != nom_r:
			otro_nom = String(nn)
			break
	var otro_tid: int = int(m.paises[otro_nom].tid)
	g.declarar(rt, otro_tid, "prueba")
	ia.desactivar(nom_r, false)
	ok(not ia.activas.has(nom_r) and g.en_guerra(rt, otro_tid), "desactivar(país, false): se va la IA y la guerra sigue")
	ia.activar(nom_r)
	ia.desactivar(nom_r)
	ok(not ia.activas.has(nom_r) and not g.en_guerra(rt, otro_tid), "desactivar(país): en la campaña cierra sus guerras (paz blanca)")
	ia.activar(nom_r)
	ia.tregua.clear()
	var v0: int = ia.version
	ia.desactivar("Atlantis")
	ok(ia.version == v0, "desactivar de un país que no tiene IA no hace nada")
	# _decidir del país que ahora lleva el jugador: la IA lo suelta
	ia.activas["España"] = ia._estado_nuevo(jt)
	var dec0: int = ia.decisiones
	ia._decidir("España", ia.activas["España"])
	ok(not ia.activas.has("España") and ia.decisiones == dec0, "_decidir sobre el país del jugador: la IA lo suelta y no cuenta como decisión")
	# _decidir real: reprograma y cuenta
	var st3: Dictionary = ia.activas[nom_r]
	var dec1: int = ia.decisiones
	var dia_ant: int = ia.dia_n
	ia.dia_n += 30
	ia._decidir(nom_r, st3)
	ok(ia.decisiones == dec1 + 1 and int(st3["ult_dec"]) == ia.dia_n and int(st3["proximo"]) > ia.dia_n, "_decidir: cuenta la decisión, anota el día y programa la siguiente (+%d)" % (int(st3["proximo"]) - ia.dia_n))
	ia.dia_n = dia_ant
	ia._preparar_frentes()
	ok(ia._ctrl_pais.has(jt) and (ia._ctrl_pais[jt] as Array).size() > 10 and ia._ctrl.size() == m.provincias.size(), "_preparar_frentes: control por país (España: %d provincias) y por provincia (%d)" % [(ia._ctrl_pais[jt] as Array).size(), ia._ctrl.size()])


# ───────────────────────── Ejército ─────────────────────────
func t_ejercito() -> void:
	print("[T] ── Ejercito: _repartir_pais, marchas, avanzar_mes por grupos")
	var v := vecino()
	var jt: int = v[0]
	var rep: Array = ej._repartir_pais("España")
	var suma := 0
	var todos_en_capital := true
	var cap0: int = int(rep[0][0]) if not rep.is_empty() else -1
	for p in rep:
		suma += int(p[1])
		todos_en_capital = todos_en_capital and int(p[0]) == cap0
	ok(not rep.is_empty() and suma > 1000, "_repartir_pais(España): hay pelotones (%d soldados en %d)" % [suma, rep.size()])
	ok(todos_en_capital, "…todo el ejército arranca junto, en la capital (un solo regimiento)")
	var tam_ok := true
	for p in rep:
		tam_ok = tam_ok and int(p[1]) <= ej.TAM_PELOTON and int(p[1]) >= 50
	ok(tam_ok, "…cada pelotón entre 50 y %d soldados" % ej.TAM_PELOTON)
	# marcha + detener
	var rid := -1
	for r in ej.regs_pais.get(jt, []):
		if not ej.en_marcha_reg(int(r)) and ej.soldados_reg(int(r)) > 0:
			rid = int(r)
			break
	var origen: int = int(ej._prov_de_tid[ej.prov_de(rid)].idx)
	var destino := -1
	for pi in m.paises["España"].provincias:
		if int(pi) != origen and ej.red.ruta(origen, int(pi)).size() >= 4:
			destino = int(pi)
			break
	var res: Dictionary = ej.ordenar_marcha_reg(rid, 0, destino)
	ok(bool(res.get("ok", false)), "ordenar_marcha_reg dentro del propio país: ok")
	var mid: int = int(res["marcha"])
	var dias_ini: float = ej.dias_restantes(ej.marchas[mid])
	var ver0: int = ej.version_marchas
	ej.avanzar_dia(2)
	ok(ej.marchas.has(mid) and ej.dias_restantes(ej.marchas[mid]) < dias_ini, "avanzar_dia(2): la columna avanza (quedan %.1f de %.1f días)" % [ej.dias_restantes(ej.marchas[mid]), dias_ini])
	ej.detener_marcha(mid)
	ok(ej.marchas[mid]["parar"] == true and ej.version_marchas > ver0, "detener_marcha: marca «parar» y sube la versión de marchas")
	var ver1: int = ej.version_marchas
	ej.detener_marcha(-12345)
	ok(ej.marchas.has(mid) and ej.version_marchas == ver1, "detener_marcha de una marcha que no existe no cambia nada")
	var vueltas := 0
	while ej.marchas.has(mid) and vueltas < 200:
		ej.avanzar_dia(3)
		vueltas += 1
	ok(not ej.marchas.has(mid) and ej.regs_prov.size() > 0, "una columna con orden de parar se detiene en la siguiente provincia y deja de marchar (%d pasos de 3 días)" % vueltas)
	# avanzar_mes por grupos == mes a mes (la fórmula cerrada de la 0.1.8.3)
	var bd = m.bd
	var nombres := ["edad_media", "experiencia", "familiaridad", "forma_fisica", "bajas_mes"]
	var guardado := {}
	for n in nombres:
		guardado[n] = (bd.vars[n].col_f as PackedFloat64Array).duplicate()
	var bm: PackedFloat64Array = bd.vars["bajas_mes"].col_f
	bm.fill(0.0)
	bd.vars["bajas_mes"].col_f = bm
	var cero := (bd.vars["bajas_mes"].col_f as PackedFloat64Array).duplicate()
	for _i in 3:
		ej.avanzar_mes()
	var a_res := {}
	for n in ["edad_media", "experiencia", "familiaridad"]:
		a_res[n] = (bd.vars[n].col_f as PackedFloat64Array).duplicate()
	for n in nombres:
		bd.vars[n].col_f = (guardado[n] as PackedFloat64Array).duplicate()
	bd.vars["bajas_mes"].col_f = cero.duplicate()
	for grupo in 3:
		ej.avanzar_mes(grupo, 3)
	var max_dif := 0.0
	for n in ["edad_media", "experiencia", "familiaridad"]:
		var a: PackedFloat64Array = a_res[n]
		var b: PackedFloat64Array = bd.vars[n].col_f
		for i in a.size():
			if not is_nan(a[i]) and not is_nan(b[i]):
				max_dif = maxf(max_dif, absf(a[i] - b[i]))
	ok(max_dif < 1e-6, "avanzar_mes(grupo, 3) × 3 grupos = 3 × avanzar_mes() (diferencia máxima %.2e)" % max_dif)
	for n in nombres:
		bd.vars[n].col_f = (guardado[n] as PackedFloat64Array).duplicate()


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)
	main._iniciar_partida({"modo": "campana", "pais": "España", "ia": 1})
	await esperar(0.6)
	m = main.mundo
	g = m.guerra
	ia = m.ia
	ej = m.ejercito
	main.reloj.velocidad = 0
	await t_hud()
	await t_ventana()
	await t_tropas()
	await t_reloj_mapa()
	await t_economia()
	await t_ia2()
	await t_ejercito()
	print("[T] ── %d comprobaciones OK · FALLOS: %d" % [n_ok, fallos])
	get_tree().quit()
