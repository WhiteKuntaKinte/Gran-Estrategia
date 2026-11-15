extends Node
## 0.1.8.44 · PRUEBAS DE LO VISUAL Y DEL REGISTRO DE FALLOS:
##  · Registro de fallos: archivo de sesión, línea de estado, marcas, detección de un cierre inesperado (y que un cierre limpio no la dispare), poda de copias y el ajuste del proyecto.
##  · Fondo espacial: casi negro, el color de la rama solo en la nebulosa, SIN planetas de fondo, el sol, calidad Baja, y que anima el shader (cero redibujos por fotograma).
##  · Árbol: capas hijas que no tocan el ratón, planetas (tamaño por enlaces totales), el sol en la raíz y su dirección de luz, estelas (y que Baja no las arma), emblemas por subsección
##    que cambian con el avance, el globo que sigue al ratón repinta solo su capa y el mapa que no se dibuja bajo la pantalla de Descubrimientos.
## Los shaders no se pueden compilar con --headless (el motor de dibujo es de mentira): su compilación y su aspecto se miran con xvfb (ver NOTAS_TECNICAS_0.1.8.44.md).
const RegistroScript := preload("res://scripts/registro_fallos.gd")
const AjustesScript := preload("res://scripts/ajustes.gd")
const FondoScript := preload("res://scripts/fondo_descubrimientos.gd")

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


## Espera a que el árbol deje de redibujarse por sí solo (10 fotogramas seguidos sin dibujar; tope 150): un cambio de día o de ventana lo rehace una vez con razón.
func esperar_quieto(g: Node) -> void:
	var quietos := 0
	var antes: int = g.dibujos
	for i in 150:
		await get_tree().process_frame
		if g.dibujos == antes:
			quietos += 1
			if quietos >= 10:
				return
		else:
			quietos = 0
			antes = g.dibujos


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
	await t_registro()
	await t_fondo()
	await t_arbol()
	await t_baja()
	print("[T] ═══ RESULTADO runner99: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ─────────────────────────────────────────────────────────────
func t_registro() -> void:
	print("[T] ── Registro de fallos")
	ok(bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false)), "el proyecto enciende el registro de Godot (godot.log en la carpeta de datos)")
	var reg = main.registro
	ok(reg != null and is_instance_valid(reg), "el juego crea el registro")
	ok(get_tree().root.get_node_or_null(RegistroScript.NOMBRE_NODO) == reg, "vive en la raíz (sobrevive al menú y a «Nueva partida»)")
	ok(FileAccess.file_exists(RegistroScript.ARCHIVO), "existe el archivo de la sesión (user://logs/sesion.txt)")
	reg.anotar("prueba runner99: marca de prueba")
	var txt := FileAccess.get_file_as_string(RegistroScript.ARCHIVO)
	ok(txt.begins_with("SESIÓN") and txt.contains("juego v" + String(main.VERSION)), "la primera línea dice la sesión y la versión del juego (%s)" % String(main.VERSION))
	ok(txt.contains("GPU:") and txt.contains("Sistema:") and txt.contains("Pantalla"), "el encabezado trae GPU, sistema y pantalla (sirve para fallos de un equipo concreto)")
	ok(txt.contains("marca de prueba"), "anotar() escribe al instante (si el juego se cae, la marca ya está en el archivo)")
	var linea: String = reg.linea_estado()
	ok(linea.contains("fps=") and linea.contains("mem=") and linea.contains("video=") and linea.contains("nodos=") and linea.contains("fecha="), "la línea de estado trae FPS, memoria, video, nodos y fecha del juego")
	ok(linea.contains("partida") and not linea.contains("menú"), "la línea de estado sabe que se está en la partida")
	main._abrir_descubrimientos()
	await fotogramas(2)
	ok(String(reg.linea_estado()).contains("+descubrimientos"), "y que la pantalla de Descubrimientos está abierta")
	ok(FileAccess.get_file_as_string(RegistroScript.ARCHIVO).contains("descubrimientos: abre"), "abrir la pantalla deja marca en el registro")
	main._cerrar_descubrimientos()
	await fotogramas(2)
	# cierre limpio: se anota la marca y la siguiente sesión NO lo cuenta como caída
	reg.cerrar_limpio()
	txt = FileAccess.get_file_as_string(RegistroScript.ARCHIVO)
	ok(txt.contains(RegistroScript.MARCA_LIMPIO), "un cierre normal anota «%s»" % RegistroScript.MARCA_LIMPIO)
	var nuevo = RegistroScript.new()
	nuevo._revisar_sesion_anterior()
	ok(nuevo.ruta_inesperado == "", "tras un cierre limpio la sesión siguiente no encuentra nada raro")
	# una caída: la sesión anterior no tiene la marca
	var f := FileAccess.open(RegistroScript.ARCHIVO, FileAccess.WRITE)
	f.store_line("SESIÓN falsa · juego v0.0")
	f.store_line("t=5s partida fecha=2026-01-01 vel=1 fps=60 mem=100MB video=10MB nodos=500 objetos=900")
	f.close()
	var antes := _copias()
	nuevo = RegistroScript.new()
	nuevo._revisar_sesion_anterior()
	ok(nuevo.ruta_inesperado != "" and FileAccess.file_exists(nuevo.ruta_inesperado), "sin la marca de cierre limpio guarda una copia aparte (cierre_inesperado_…)")
	ok(FileAccess.get_file_as_string(nuevo.ruta_inesperado).contains("SESIÓN falsa"), "la copia es la sesión anterior, completa")
	nuevo.free()
	# la poda deja como mucho MAX_INESPERADOS copias
	for k in 9:
		var g := FileAccess.open(RegistroScript.CARPETA + "cierre_inesperado_20200101_00000%d.txt" % k, FileAccess.WRITE)
		g.store_line("falsa %d" % k)
		g.close()
	var podador = RegistroScript.new()
	podador._podar()
	var quedan := _copias()
	ok(quedan.size() == RegistroScript.MAX_INESPERADOS, "la poda deja %d copias (quedan %d)" % [RegistroScript.MAX_INESPERADOS, quedan.size()])
	podador.free()
	# limpieza de lo que hizo la prueba (dejar la sesión como cerrada bien, y sin copias falsas)
	for n in _copias():
		if n.begins_with("cierre_inesperado_2020") or not antes.has(n):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(RegistroScript.CARPETA + n))
	var h := FileAccess.open(RegistroScript.ARCHIVO, FileAccess.WRITE)
	h.store_line(RegistroScript.MARCA_LIMPIO)
	h.close()


func _copias() -> Array:
	var r: Array = []
	for n in DirAccess.get_files_at(RegistroScript.CARPETA):
		if n.begins_with("cierre_inesperado_") and n.ends_with(".txt"):
			r.append(n)
	r.sort()
	return r


# ─────────────────────────────────────────────────────────────
func t_fondo() -> void:
	print("[T] ── Fondo: espacio NEGRO con el color de la rama, sin planetas")
	for r in FondoScript.PALETAS.size():
		var pal: Array = FondoScript.PALETAS[r]
		ok((pal[0] as Color).get_luminance() < 0.05 and (pal[1] as Color).get_luminance() < 0.02, "rama %d: arriba y abajo son casi negros (%.3f / %.3f)" % [r, (pal[0] as Color).get_luminance(), (pal[1] as Color).get_luminance()])
		ok((pal[2] as Color).get_luminance() > 0.3, "rama %d: el acento (nebulosa, estrellas) sí es de color vivo" % r)
	var codigo: String = FondoScript.SHADER_FONDO.code
	ok(not codigo.contains("planeta(") and not codigo.contains("sitio_planeta"), "el shader del fondo ya no dibuja planetas (los únicos planetas son los descubrimientos)")
	ok(codigo.contains("u_sol") and codigo.contains("tex_neb"), "lleva el resplandor del sol y la nebulosa por textura")
	main._abrir_descubrimientos()
	await esperar(0.4)
	var p = main.panel_descubrimientos
	var fo = p.fondo
	var m: ShaderMaterial = fo.material
	ok(m != null and m.shader == FondoScript.SHADER_FONDO, "el fondo usa su shader")
	ok(m.get_shader_parameter("tex_neb") is ImageTexture and (m.get_shader_parameter("tex_neb") as ImageTexture).get_width() == FondoScript.LADO_NEBULOSA, "la nebulosa es una textura de ruido hecha una vez (%d px)" % FondoScript.LADO_NEBULOSA)
	ok(FondoScript._textura_nebulosa() == FondoScript._textura_nebulosa(), "la textura de la nebulosa se comparte (una sola)")
	ok(float(m.get_shader_parameter("u_anim")) == 1.0, "con calidad normal el cielo se anima")
	var r0: int = fo.redibujos
	await fotogramas(40)
	ok(fo.redibujos == r0, "40 fotogramas seguidos: el fondo NO se redibuja (lo anima el shader con TIME) (%d → %d)" % [r0, fo.redibujos])
	fo.fijar(2, 3)
	await fotogramas(2)
	var c_top: Color = m.get_shader_parameter("c_top")
	ok(c_top.get_luminance() < 0.05 and fo.rama == 2, "cambiar de rama sigue dando un fondo casi negro")
	fo.poner_sol(Vector2(321.0, 654.0))
	ok(Vector2(m.get_shader_parameter("u_sol")).is_equal_approx(Vector2(321.0, 654.0)), "poner_sol mueve el resplandor del sol")
	fo.poner_sol(Vector2(-1.0, -1.0))
	ok(Vector2(m.get_shader_parameter("u_sol")).x > 0.0 and Vector2(m.get_shader_parameter("u_sol")).y > fo.size.y, "sin árbol a la vista el sol queda centrado y por debajo de la pantalla")
	fo.animado = false
	ok(float(m.get_shader_parameter("u_anim")) == 0.0, "animado = false congela el cielo")
	fo.animado = true
	main._cerrar_descubrimientos()
	await fotogramas(2)


# ─────────────────────────────────────────────────────────────
func t_arbol() -> void:
	print("[T] ── Árbol: planetas alumbrados por el sol, estelas, emblemas y capas")
	var d = main.mundo.descubrimientos
	ok(main.visible, "antes de abrir la pantalla el mapa se dibuja")
	main._abrir_descubrimientos()
	await esperar(0.3)
	ok(not main.visible and main._mapa_oculto_desc, "con la pantalla de Descubrimientos abierta el mapa NO se dibuja (es opaca: era gasto de GPU)")
	var p = main.panel_descubrimientos
	var g = p.arbol
	p._elegir_rama(1)
	await fotogramas(2)
	p._entrar_seccion(14)
	await esperar(0.5)
	# capas
	for c in [g.capa_estelas, g.capa_emblemas, g.capa_planetas, g.capa_encima]:
		ok(c != null and c.get_parent() == g and c.mouse_filter == Control.MOUSE_FILTER_IGNORE, "capa «%s»: hija del árbol y transparente al ratón" % (c.name if c != null else "?"))
	ok(g.capa_estelas.material is ShaderMaterial and g.capa_planetas.material is ShaderMaterial and g.capa_emblemas.material is ShaderMaterial, "estelas, planetas y emblemas tienen su shader")
	ok(g.capa_encima.material == null, "la capa de encima (anillos, marcas, leyenda, globo) es dibujo normal")
	var ord := [g.capa_estelas.get_index(), g.capa_emblemas.get_index(), g.capa_planetas.get_index(), g.capa_encima.get_index()]
	ok(ord[0] < ord[1] and ord[1] < ord[2] and ord[2] < ord[3], "orden de dibujo: estelas, emblemas, planetas, encima")
	# planetas
	ok(g.planetas_dibujados > 0 and g.planetas_dibujados == g.nodos_dibujados, "un planeta por cada descubrimiento a la vista (%d)" % g.planetas_dibujados)
	ok(g.nodos.size() == 41, "la sección de Matemáticas trae sus 41 descubrimientos")
	var min_r := 1.0e9
	var max_r := 0.0
	var mal_enlaces := 0
	var monotono := true
	var pares: Array = []
	for i in g.nodos:
		var enl: int = (d.dependientes[i] as PackedInt32Array).size() + g._prerrequisitos(i).size()
		var esperado := clampf(g.R_MIN + sqrt(float(enl)) * g.R_POR_ENLACE, g.R_MIN, g.R_MAX)
		if absf(float(g.radio[i]) - esperado) > 0.001:
			mal_enlaces += 1
		min_r = minf(min_r, float(g.radio[i]))
		max_r = maxf(max_r, float(g.radio[i]))
		pares.append([enl, float(g.radio[i])])
	for a in pares:
		for b in pares:
			if int(a[0]) > int(b[0]) and float(a[1]) < float(b[1]) - 0.001:
				monotono = false
	ok(mal_enlaces == 0, "el tamaño del planeta sale de sus enlaces TOTALES (lo que pide + lo que abre): 0 fallos de %d" % g.nodos.size())
	ok(monotono, "más enlaces nunca es un planeta más chico")
	ok(max_r > min_r + 10.0 and min_r >= g.R_MIN and max_r <= g.R_MAX, "hay planetas chicos y grandes (%.0f a %.0f de radio, entre %.0f y %.0f)" % [min_r, max_r, g.R_MIN, g.R_MAX])
	ok(g.SEP_NODO >= 200.0 and g.SEP_NIVEL >= 280.0 and g.R_RAIZ >= 560.0, "el árbol aprovecha el espacio (separación %.0f, entre eras %.0f, anillo raíz %.0f)" % [g.SEP_NODO, g.SEP_NIVEL, g.R_RAIZ])
	# el sol
	ok(g._sol_pant.is_equal_approx(g._a_pantalla(g.apex)), "el sol está en la raíz del árbol (%s)" % str(g._sol_pant))
	var movidas := [0]
	g.sol_movido.connect(func(_p): movidas[0] += 1)
	g.origen += Vector2(40.0, 25.0)
	g.queue_redraw()
	await fotogramas(3)
	ok(movidas[0] >= 1, "al desplazar el árbol el sol avisa dónde quedó (el fondo mueve su resplandor)")
	ok(g.DIRECCIONES_SOL == 32 and g.SOL_ESTADO == 4, "la dirección del sol viaja en 32 pasos junto al estado del planeta")
	var codigo: String = g.SHADER_PLANETA.code
	ok(codigo.contains("superficie(") and codigo.contains("terminaci") or codigo.contains("dia = smoothstep"), "el shader del planeta lleva superficies reales y la terminación día / noche")
	# estelas
	g.zoom = 0.7
	g.queue_redraw()
	await fotogramas(3)
	ok(g.animado and g.estelas_dibujadas > 0 and g.estelas_dibujadas <= g.MAX_ESTELAS, "con calidad normal corren estelas por lo conocido (%d líneas)" % g.estelas_dibujadas)
	g.zoom = g.LOD_ESTELAS * 0.5
	g.queue_redraw()
	await fotogramas(3)
	ok(g.estelas_dibujadas == 0, "muy alejado no se arman estelas (serían ruido)")
	g.zoom = 0.7
	g.queue_redraw()
	await fotogramas(2)
	main.reloj.velocidad = 0                      # el reloj parado: si no, al cambiar el día la pantalla se refresca y el árbol se redibuja con razón
	await esperar_quieto(g)
	var d0: int = g.dibujos
	await fotogramas(40)
	ok(g.dibujos - d0 <= 2, "40 fotogramas sin tocar nada: el árbol NO se redibuja por fotograma (planetas y estelas los anima el shader; un cambio de fecha lo rehace una vez con razón) (%d → %d)" % [d0, g.dibujos])
	# emblemas
	g.ajustar()
	await fotogramas(3)
	ok(g.emblemas_dibujados > 0, "con la sección entera a la vista hay emblemas de subsección (%d)" % g.emblemas_dibujados)
	var punta_ok: bool = g.carriles.size() > 0
	var largos := {}
	for cr in g.carriles:
		var rf: float = cr["r_fin"]
		largos[snappedf(rf, 1.0)] = true
		if rf <= g.LARGO_PUNTA:
			punta_ok = false
	ok(punta_ok, "cada cuña termina en su propio último anillo con contenido (+ LARGO_PUNTA)")
	ok(largos.size() >= 2, "las cuñas no tienen todas el mismo largo: la que dejó de crecer queda corta (%d largos distintos)" % largos.size())
	var suma := 0
	var rango_ok := true
	for sb in g._cuenta:
		suma += (g._cuenta[sb] as Vector2i).y
		var av: float = g.avance_sub(int(sb))
		if av < 0.0 or av > 1.0:
			rango_ok = false
	ok(suma == g.nodos.size() and rango_ok, "el avance por subsección suma todos los descubrimientos de la sección y va de 0 a 1")
	# el emblema cambia con el avance: con todo conocido es 1, y si no se conoce nada es 0
	var sb0: int = int(g.carriles[0]["sub"])
	ok(is_equal_approx(g.avance_sub(sb0), float((g._cuenta[sb0] as Vector2i).x) / float((g._cuenta[sb0] as Vector2i).y)), "el avance de una cuña es conocidos / total")
	for i in g.nodos:
		g._est[i] = g.E_BLOQUEADO
	g._cuenta.clear()
	for i in g.nodos:
		var sb: int = int(d.sub[i])
		var cu: Vector2i = g._cuenta.get(sb, Vector2i.ZERO)
		g._cuenta[sb] = Vector2i(cu.x, cu.y + 1)
	ok(g.avance_sub(sb0) == 0.0, "sin nada conocido el avance de la cuña es 0 (el emblema queda apagado)")
	g.refrescar()
	ok(g.avance_sub(sb0) > 0.0, "al refrescar vuelve a salir el avance real")
	# el globo que sigue al ratón repinta solo la capa de encima
	await esperar_quieto(g)
	var dib0: int = g.dibujos
	g.hover = g.nodos[0]
	g.capa_encima.queue_redraw()
	await fotogramas(2)
	ok(g.dibujos == dib0, "repintar el globo no rehace todo el árbol (%d → %d)" % [dib0, g.dibujos])
	g.hover = -1
	g.queue_redraw()
	# cerrar la pantalla devuelve el mapa
	main._cerrar_descubrimientos()
	await fotogramas(3)
	ok(main.visible and not main._mapa_oculto_desc, "al cerrar la pantalla el mapa vuelve a dibujarse")
	main._abrir_descubrimientos()
	await fotogramas(2)
	main._alternar_descubrimientos()
	await fotogramas(2)
	ok(main.visible, "abrir y cerrar con la tecla T también devuelve el mapa")


# ─────────────────────────────────────────────────────────────
func t_baja() -> void:
	print("[T] ── Calidad Baja: cielo quieto y barato, sin estelas")
	var antes: Dictionary = main.ajustes.duplicate()
	main.ajustes = AjustesScript.con_preset(main.ajustes, 2)
	ok(AjustesScript.preset_de(main.ajustes) == 2, "la calidad está en Baja")
	main._abrir_descubrimientos()
	await esperar(0.3)
	var p = main.panel_descubrimientos
	p._elegir_rama(1)
	p._entrar_seccion(14)
	await esperar(0.4)
	ok(not p.fondo.animado and not p.arbol.animado, "con Baja ni el cielo ni el árbol se animan")
	ok(float((p.fondo.material as ShaderMaterial).get_shader_parameter("u_anim")) == 0.0, "el shader del cielo recibe u_anim = 0 (camino barato)")
	p.arbol.zoom = 0.7
	p.arbol.queue_redraw()
	await fotogramas(3)
	ok(p.arbol.estelas_dibujadas == 0, "con Baja no se arma ninguna estela")
	ok(p.arbol.planetas_dibujados > 0, "los planetas se siguen viendo (quietos)")
	main._cerrar_descubrimientos()
	await fotogramas(2)
	main.ajustes = antes
