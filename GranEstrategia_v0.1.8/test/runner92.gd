extends Node
## 0.1.8.42 · PRUEBAS DEL GRABADOR DE RENDIMIENTO GLOBAL: vive en la raíz (no dentro de la partida), sigue grabando en el menú principal y al recargar la escena
## («Nueva partida»), pone marcas solas, muestra el «● REC», y si el juego se cierra mientras graba guarda el resumen.
const GrabadorScript := preload("res://scripts/grabador_rendimiento.gd")
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


func ok(cond: bool, msg: String) -> void:
	if cond:
		n_ok += 1
		print("[T] OK    ", msg)
	else:
		fallos += 1
		print("[T] FALLO ", msg)


func nueva_main() -> void:
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)


func run() -> void:
	await nueva_main()
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)
	await t_global()
	await t_menu()
	await t_recarga()
	await t_salida()
	print("[T] ═══ RESULTADO runner92: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func leer_csv(ruta: String) -> Array:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return []
	var filas: Array = []
	while not f.eof_reached():
		var l := f.get_line()
		if l != "":
			filas.append(l.split(","))
	return filas


func t_global() -> void:
	print("[T] ── El grabador vive en la raíz")
	var g = main.grabador
	ok(g != null and g.get_parent() == get_tree().root, "el grabador cuelga de la raíz, no de la partida")
	ok(g.name == GrabadorScript.NOMBRE_NODO, "se llama «%s»" % g.name)
	ok(GrabadorScript.obtener(main) == g, "pedirlo otra vez devuelve el mismo")
	ok(not g.grabando, "empieza apagado")
	main.alternar_grabacion()
	await fotogramas(4)
	ok(g.grabando, "F9 (alternar_grabacion) lo enciende")
	ok(g.indicador != null and g.lbl_rec != null and g.lbl_rec.is_inside_tree(), "aparece el «● REC» rojo")
	ok(g.indicador.layer > 100, "el «● REC» va por encima de todo (capa %d)" % g.indicador.layer)
	g.marcar("a")
	g.marcar("b")
	await fotogramas(2)
	ok(g._marcas.size() >= 1 and String(g._marcas[0][1]) == "a + b", "dos marcas en el mismo fotograma se unen («%s»)" % String(g._marcas[0][1]))
	var cal: Dictionary = main.ajustes.duplicate()
	cal["costa"] = 2
	main._aplicar_calidad(cal)
	await fotogramas(2)
	var hay_cal := false
	for m in g._marcas:
		if String(m[1]).begins_with("calidad:"):
			hay_cal = true
	ok(hay_cal, "cambiar la calidad deja una marca sola")
	main._elegir_vista("relieve")
	await fotogramas(3)
	main._elegir_vista("tradicional")
	await fotogramas(3)
	var n_vista := 0
	for m in g._marcas:
		if String(m[1]).begins_with("vista:"):
			n_vista += 1
	ok(n_vista >= 2, "cambiar de vista deja marcas solas (%d)" % n_vista)


func t_menu() -> void:
	print("[T] ── Sigue grabando en el menú principal")
	var g = main.grabador
	var f0: int = g.n_filas
	main._volver_menu_principal()
	await fotogramas(8)
	ok(main.en_menu and g.grabando, "en el menú principal sigue grabando")
	ok(g.n_filas >= f0 + 8, "se anotan fotogramas en el menú (%d más)" % (g.n_filas - f0))
	ok(g.indicador != null and is_instance_valid(g.indicador), "el «● REC» sigue a la vista en el menú")
	var n_menu := 0
	for v in g._vistas:
		if v == "menu":
			n_menu += 1
	ok(n_menu >= 6, "esos fotogramas quedan como vista «menu» (%d)" % n_menu)
	main._on_jugar()
	await fotogramas(4)
	var hay := false
	for m in g._marcas:
		if String(m[1]).contains("menú principal"):
			hay = true
	ok(hay, "volver al menú deja su marca")


func t_recarga() -> void:
	print("[T] ── «Nueva partida» recarga la escena y el grabador sigue")
	var g = main.grabador
	var f0: int = g.n_filas
	var ruta0: String = g._ruta
	# lo que hace reload_current_scene: la partida se libera y entra otra
	main.queue_free()
	await fotogramas(3)
	ok(g.grabando and is_instance_valid(g), "con la partida liberada el grabador sigue vivo y grabando")
	ok(g.n_filas > f0, "sigue anotando fotogramas durante la recarga (%d más)" % (g.n_filas - f0))
	var carga := 0
	for v in g._vistas:
		if v == "carga":
			carga += 1
	ok(carga >= 2, "esos fotogramas quedan como «carga» (%d)" % carga)
	await nueva_main()
	ok(main.grabador == g and g.grabando, "la partida nueva se enlaza al MISMO grabador, que sigue grabando")
	ok(g._ruta == ruta0, "sigue escribiendo el mismo archivo")
	var hay := false
	for m in g._marcas:
		if String(m[1]).contains("partida nueva cargada"):
			hay = true
	ok(hay, "anota «partida nueva cargada»")
	await fotogramas(3)
	var antes: int = g.n_filas
	await fotogramas(5)
	ok(g.n_filas >= antes + 5, "graba con normalidad en la partida nueva")


func t_salida() -> void:
	print("[T] ── Detener y salir")
	var g = main.grabador
	var res: String = g.detener()
	ok(not g.grabando and g.indicador == null, "detener apaga el grabador y quita el «● REC»")
	ok(res.contains("RESUMEN DE RENDIMIENTO") and res.contains(String(main.VERSION)), "el resumen lleva la versión del juego")
	ok(res.contains("menu") and res.contains("Marcas"), "el resumen muestra la vista «menu» y las marcas")
	ok(FileAccess.file_exists(g.ultimo_archivo), "el CSV existe en disco")
	var filas := leer_csv(g.ultimo_archivo)
	ok(filas.size() > 20, "el CSV tiene los fotogramas (%d filas)" % filas.size())
	var vistas := {}
	for k in range(1, filas.size()):
		vistas[String((filas[k] as PackedStringArray)[13])] = true
	ok(vistas.has("menu") and vistas.has("carga") and (vistas.has("tradicional") or vistas.has("relieve")), "el CSV recorre menú, carga y partida (%s)" % ", ".join(PackedStringArray(vistas.keys())))
	ok(FileAccess.file_exists(g.ultimo_archivo.trim_suffix(".csv") + "_resumen.txt"), "el resumen también quedó en un archivo")
	# cerrar el juego mientras graba: el nodo sale del árbol y guarda solo
	ok(g.iniciar(), "se puede volver a grabar")
	await fotogramas(6)
	var ruta: String = g._ruta
	var raiz := get_tree().root
	raiz.remove_child(g)
	ok(not g.grabando, "al cerrar el juego mientras graba, se detiene solo")
	ok(FileAccess.file_exists(ruta.trim_suffix(".csv") + "_resumen.txt"), "…y deja su resumen escrito")
	g.queue_free()
