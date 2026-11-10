extends Node
## 0.1.8.39 · PRUEBAS: vista Internacional quitada (V alterna Tradicional ↔ Relieve), lista de campaña fija de 2026 (archivo = mundo de 2026), nombres legibles sobre
## el relieve (negrita + halo), imagen guardada del relleno al alejar el mapa (cuándo se usa, se rehace al cambiar un dueño, relieve y capa apagada) y grabador
## de rendimiento (archivo CSV, resumen, marcas).
const CapaTexto := preload("res://MapaPrincipal.gd").CapaTexto
var main
var fallos := 0
var n_ok := 0


func _ready() -> void:
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	Engine.set_meta("inicio_pendiente", {"modo": "campana", "pais": "Francia", "ia": 0})
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


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)                       # la base del proyecto: así 1 de zoom de cámara = 1 píxel de pantalla por unidad de mapa
	await fotogramas(3)
	await t_vista_internacional()
	t_campana_2026()
	await t_nombres_relieve()
	await t_cache_relleno()
	await t_grabador()
	print("[T] ═══ RESULTADO runner81: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func tecla(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	main._unhandled_input(ev)


# ── Vista Internacional quitada ─────────────────────────────────────────────────────────────────────────────
func t_vista_internacional() -> void:
	print("[T] ── vista Internacional quitada")
	var h = main.hud
	var claves: Array = []
	for v in h.VISTAS:
		claves.append(String(v[0]))
	ok(not claves.has("internacional") and claves.has("tradicional") and claves.has("relieve"), "el menú VISTA ya no tiene «Internacional» (%s)" % ", ".join(PackedStringArray(claves)))
	ok(not h.botones_vista.has("internacional"), "no hay botón de vista Internacional")
	ok(main.get("vista") == null, "el mapa ya no guarda una «vista» tradicional/internacional")
	ok(not main.has_method("_cambiar_vista") and not main.has_method("_aplicar_vista") and not main.has_method("_tiene_estados"), "las funciones de la vista Internacional ya no existen")
	main._elegir_vista("tradicional")
	ok(not main.modo_relieve and h.btn_vista.text.strip_edges() == "Tradicional", "arranca en Tradicional")
	tecla(KEY_V)
	ok(main.modo_relieve and h.btn_vista.text.strip_edges() == "Relieve", "V pasa a Relieve")
	ok(bool((h.botones_vista["relieve"] as Button).button_pressed) and not bool((h.botones_vista["tradicional"] as Button).button_pressed), "el menú marca Relieve")
	tecla(KEY_V)
	ok(not main.modo_relieve and h.btn_vista.text.strip_edges() == "Tradicional", "V vuelve a Tradicional")
	ok(h.btn_vista.tooltip_text.find("internacional") < 0, "el botón ya no habla de la vista internacional")
	main.pais_foco = ""
	main._actualizar_hint()
	ok(String(h.lbl_hint.text if "lbl_hint" in h else "").find("internacional") < 0, "la línea de ayuda no menciona la vista internacional")


# ── Lista de la campaña ────────────────────────────────────────────────────────────────────────────────────
func t_campana_2026() -> void:
	print("[T] ── lista de la campaña: siempre 2026")
	var lista: Array = main._paises_campana_2026()
	ok(lista.size() == 51, "la campaña tiene 51 países (%d)" % lista.size())
	for n in ["España", "Francia", "Alemania", "Rusia", "Turquía", "Ucrania", "Italia"]:
		ok(lista.has(n), "la lista incluye %s" % n)
	ok(not lista.has("Imperio romano") and not lista.has("Imperio parto"), "no hay pueblos antiguos en la lista")
	# el archivo coincide con lo que da el mundo de 2026 (si se regeneran las entidades o las provincias hay que correr construir_campana_2026.py)
	var del_mundo: Array = []
	for n in main.mundo.paises_de_campana():
		if main.mundo.paises.has(n) and not (main.mundo.paises[n].provincias as Array).is_empty():
			del_mundo.append(String(n))
	del_mundo.sort()
	var del_archivo := lista.duplicate()
	del_archivo.sort()
	ok(del_mundo == del_archivo, "el archivo datos/campana_2026.json coincide con los países de campaña del mundo de 2026 (%d vs %d)" % [del_archivo.size(), del_mundo.size()])
	ok(main.epoca == main.EPOCA_ACTUAL, "el mundo cargado es el de 2026")


# ── Nombres sobre el relieve ───────────────────────────────────────────────────────────────────────────────
func t_nombres_relieve() -> void:
	print("[T] ── nombres legibles sobre el relieve")
	main._elegir_vista("tradicional")
	await fotogramas(2)
	ok(CapaTexto.contorno == 0, "sin relieve los nombres no llevan contorno")
	main._elegir_vista("relieve")
	await fotogramas(2)
	ok(CapaTexto.contorno == main.RELIEVE_CONTORNO_TEXTO, "con relieve los nombres llevan contorno (%d)" % CapaTexto.contorno)
	ok(CapaTexto.fuente_negrita != null and CapaTexto.fuente_negrita is FontVariation, "con relieve los nombres usan la fuente en negrita")
	if CapaTexto.fuente_negrita is FontVariation:
		ok(is_equal_approx(float((CapaTexto.fuente_negrita as FontVariation).variation_embolden), main.RELIEVE_NEGRITA_TEXTO), "la negrita es la de RELIEVE_NEGRITA_TEXTO")
	ok(CapaTexto._factor_halo(0.9) == 1.0 and CapaTexto._factor_halo(0.4) > 1.0 and CapaTexto._factor_halo(0.1) > CapaTexto._factor_halo(0.4), "el halo es más grueso cuanto más chico el nombre")
	ok(CapaTexto._factor_halo(0.5) == 1.0 and CapaTexto._factor_halo(0.2) == 2.0, "los pasos del halo son fijos (pocas variantes en la caché)")
	main._elegir_vista("tradicional")
	await fotogramas(2)
	ok(CapaTexto.contorno == 0, "al volver a Tradicional se quita el contorno")


# ── Imagen guardada del relleno ────────────────────────────────────────────────────────────────────────────
func t_cache_relleno() -> void:
	print("[T] ── imagen guardada del relleno (mundo entero)")
	ok(main.cache_rel_vp != null and main.cache_rel_sprites.size() == 3, "hay un SubViewport y 3 copias de la imagen (mundo y sus dos lados)")
	var n_inst := 0
	for g in main.fusion.teselas:
		n_inst += (g["inst"] as Array).size()
	ok(n_inst == main.fusion.teselas.size() * 4, "cada tesela tiene 4 instancias para recolorear (3 copias + la de la imagen): %d" % n_inst)
	main._elegir_vista("tradicional")
	main._salir_foco()
	main._limpiar_seleccion()
	main.camara.position = Vector2(1250.0, 420.0)
	# de lejos: imagen
	main.camara.zoom = Vector2(0.8, 0.8)
	await fotogramas(8)
	ok(main.cache_rel_activo and main.cache_rel_hechas >= 1, "de lejos (zoom 0,8) se usa la imagen guardada (hechas %d)" % main.cache_rel_hechas)
	ok(not main.capa_pais.visible, "…y las mallas del relleno se apagan")
	ok((main.cache_rel_sprites[1] as Sprite2D).visible and (main.cache_rel_sprites[0] as Sprite2D).visible and (main.cache_rel_sprites[2] as Sprite2D).visible, "…y se ven las tres copias de la imagen")
	var modo_vp: int = (main.cache_rel_vp as SubViewport).render_target_update_mode
	ok(modo_vp != SubViewport.UPDATE_ALWAYS and modo_vp != SubViewport.UPDATE_WHEN_VISIBLE, "el SubViewport no se repinta solo en cada fotograma (solo cuando cambia algún dueño)")
	# de cerca: mallas
	main.camara.zoom = Vector2(2.5, 2.5)
	await fotogramas(4)
	ok(not main.cache_rel_activo and main.capa_pais.visible, "de cerca (zoom 2,5) vuelven las mallas")
	ok(not (main.cache_rel_sprites[1] as Sprite2D).visible, "…y la imagen se esconde")
	# el hueco entre entrar y salir: sin parpadeo
	main.camara.zoom = Vector2(1.85, 1.85)
	await fotogramas(4)
	ok(not main.cache_rel_activo, "entre 1,7 y 2,0 se queda como estaba (mallas, venía de cerca)")
	main.camara.zoom = Vector2(0.8, 0.8)
	await fotogramas(6)
	main.camara.zoom = Vector2(1.85, 1.85)
	await fotogramas(4)
	ok(main.cache_rel_activo, "entre 1,7 y 2,0 se queda como estaba (imagen, venía de lejos)")
	# cambia un dueño: se rehace la imagen
	main.camara.zoom = Vector2(0.8, 0.8)
	await fotogramas(4)
	var antes: int = main.cache_rel_hechas
	main.fusion.repintar_todo()
	main._sincronizar_propiedad(true)
	ok(main.cache_rel_sucia, "al repintarse el relleno la imagen queda marcada como vieja")
	await esperar(0.6)
	await fotogramas(4)
	ok(main.cache_rel_hechas == antes + 1 and not main.cache_rel_sucia, "…y se rehace sola (de %d a %d)" % [antes, main.cache_rel_hechas])
	# relieve y capa apagada
	main._elegir_vista("relieve")
	await fotogramas(4)
	ok(not main.cache_rel_activo and not main.capa_pais.visible and not (main.cache_rel_sprites[1] as Sprite2D).visible, "con el relieve no se ve ni la imagen ni las mallas del relleno")
	main._elegir_vista("tradicional")
	await fotogramas(6)
	ok(main.cache_rel_activo, "al volver a Tradicional de lejos vuelve la imagen")
	main.rend_poner_capa("relleno", false)
	await fotogramas(4)
	ok(not main.cache_rel_activo and not main.capa_pais.visible and not (main.cache_rel_sprites[1] as Sprite2D).visible, "con la capa «relleno» apagada desde el Debug no se ve ninguna de las dos")
	main.rend_poner_capa("relleno", true)
	await fotogramas(6)
	ok(main.cache_rel_activo, "al encenderla otra vez vuelve la imagen")
	main.camara.zoom = Vector2(1.0, 1.0)
	await fotogramas(3)


# ── Grabador de rendimiento ────────────────────────────────────────────────────────────────────────────────
func t_grabador() -> void:
	print("[T] ── grabador de rendimiento")
	var g = main.grabador
	ok(g != null and not g.grabando, "el grabador existe y está apagado")
	tecla(KEY_F9)
	ok(g.grabando, "F9 enciende el grabador")
	ok(String(main.avisos.ultimo_texto).find("Grabando") >= 0, "avisa que está grabando")
	await fotogramas(20)
	main.camara.zoom = Vector2(2.0, 2.0)
	g.marcar("zoom 2")
	await fotogramas(20)
	main._elegir_vista("relieve")
	await fotogramas(20)
	main._elegir_vista("tradicional")
	main.camara.zoom = Vector2(0.9, 0.9)
	await fotogramas(20)
	ok(g.n_filas >= 70, "anota una fila por fotograma (%d)" % g.n_filas)
	tecla(KEY_F9)
	ok(not g.grabando, "F9 lo apaga")
	var ruta: String = g.ultimo_archivo
	ok(ruta.begins_with("user://rendimiento/rend_") and ruta.ends_with(".csv") and FileAccess.file_exists(ruta), "queda un CSV en la carpeta del usuario (%s)" % ruta)
	var f := FileAccess.open(ruta, FileAccess.READ)
	var lineas: PackedStringArray = f.get_as_text().strip_edges().split("\n")
	f = null
	ok(lineas[0] == g.CABECERA, "la primera línea es la cabecera de columnas")
	ok(lineas.size() - 1 == g.n_filas, "hay una fila por fotograma anotado (%d)" % (lineas.size() - 1))
	var ncol: int = g.CABECERA.split(",").size()
	var bien := true
	for i in range(1, lineas.size()):
		if lineas[i].split(",").size() != ncol:
			bien = false
			break
	ok(bien, "todas las filas tienen las %d columnas" % ncol)
	var dts: Array = []
	var vistas := {}
	var marca := ""
	for i in range(1, lineas.size()):
		var c := lineas[i].split(",")
		dts.append(float(c[1]))
		vistas[c[13]] = true
		if c[20] != "":
			marca = c[20]
	ok(float(dts.max()) > 0.0 and float(dts.min()) >= 0.0, "las duraciones de fotograma son números válidos")
	ok(vistas.has("tradicional") and vistas.has("relieve"), "anota la vista de cada fotograma (tradicional y relieve)")
	ok(marca == "zoom 2", "la marca queda en su fila")
	var res: String = g.ultimo_resumen
	ok(res.find("RESUMEN DE RENDIMIENTO") >= 0 and res.find("GPU:") >= 0 and res.find("FPS medios") >= 0, "el resumen trae el equipo y los FPS medios")
	ok(res.find("peores fotogramas") >= 0 and res.find("Por vista y nivel de zoom") >= 0 and res.find("Marcas") >= 0, "el resumen trae los peores fotogramas, la tabla por vista/zoom y las marcas")
	ok(FileAccess.file_exists(ruta.trim_suffix(".csv") + "_resumen.txt"), "el resumen también queda en un archivo de texto")
	ok(DisplayServer.clipboard_get() == res or DisplayServer.get_name() == "headless", "el resumen queda en el portapapeles")
	ok(g.percentil([1.0, 2.0, 3.0, 4.0, 5.0], 0.5) == 3.0 and g.percentil([1.0, 2.0, 3.0, 4.0, 5.0], 1.0) == 5.0 and g.percentil([], 0.5) == 0.0, "percentil: mediana, máximo y lista vacía")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta.trim_suffix(".csv") + "_resumen.txt"))
	# el panel del Debug
	main._abrir_debug()
	await esperar(0.3)
	ok(main.debug_menu != null and main.debug_menu.btn_grabar != null, "Debug > Rendimiento tiene el botón de grabar")
	main.debug_menu._refrescar_rend()
	ok(main.debug_menu.btn_grabar.text.find("Empezar") >= 0, "el botón dice «Empezar a grabar» con el grabador apagado")
	main.alternar_grabacion()
	main.debug_menu._refrescar_rend()
	ok(main.debug_menu.btn_grabar.text.find("Detener") >= 0, "…y «Detener» con el grabador encendido")
	var ruta2: String = g._ruta
	main.alternar_grabacion()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta2))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta2.trim_suffix(".csv") + "_resumen.txt"))
	main.debug_menu.queue_free()
	await esperar(0.2)
	main.debug_menu = null
