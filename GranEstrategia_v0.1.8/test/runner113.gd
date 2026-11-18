extends Node
## 0.1.8.52 · HUD DE NUEVE SECCIONES: pestañas con icono, contenido de cada una y que cada sección quepa sin scroll en 1280×720 y 1920×1080.
var main
var fallos := 0
var n_ok := 0
const NUEVE := ["general", "poblacion", "progreso", "economia", "militar", "diplomacia", "politica", "territorio", "cultura"]


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


func arrancar(anio: int, tam: Vector2i, semilla := 777) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await esperar(0.3)
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	Engine.set_meta("semilla_partida", semilla)
	if anio != 2026:
		Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": anio})
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = tam
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)


func textos(n: Node, r: Array) -> void:
	for h in n.get_children():
		if h is Label:
			r.append(h.text)
		if h is Button:
			r.append(h.text)
		textos(h, r)


func todo_texto() -> String:
	var t: Array = []
	textos(main.hud.cuerpo, t)
	return "\n".join(PackedStringArray(t)).to_upper()


# ─────────────────────────────────────────────────────────────
func t_pestanas() -> void:
	print("[T] ── Las nueve pestañas del país")
	await arrancar(2026, Vector2i(1280, 720))
	var hud = main.hud
	ok(hud.PESTANAS.size() == 9, "el HUD define nueve pestañas (%d)" % hud.PESTANAS.size())
	var faltan: Array = []
	for t in hud.PESTANAS:
		if not ResourceLoader.exists("res://iconos/%s.png" % String(t[2])):
			faltan.append(String(t[2]))
	ok(faltan.is_empty(), "cada pestaña tiene su icono (faltan: %s)" % str(faltan))
	ok(hud.pestanas_de("pais") == NUEVE, "un país tiene las nueve")
	ok(hud.pestanas_de("provincia").size() == 7 and not hud.pestanas_de("provincia").has("diplomacia"), "una provincia tiene siete (sin Diplomacia ni Progreso)")
	ok(hud.pestanas_de("mar") == ["general"] and hud.pestanas_de("libre") == ["general"], "mar y tierra libre solo tienen el Resumen")
	main._seleccion_pais("España", "Europa", Vector2(1175.0, 330.0))
	await esperar(0.4)
	var visibles := 0
	for k in NUEVE:
		if (hud.botones_pestana[k] as Button).visible:
			visibles += 1
	ok(visibles == 9, "al elegir un país se ven los nueve botones (%d)" % visibles)
	var esperado := {
		"general": ["DE UN VISTAZO"], "poblacion": ["POBLACIÓN"], "progreso": ["DESCUBRIMIENTOS", "EDUCACIÓN E INVESTIGACIÓN"],
		"economia": ["PRESUPUESTO"], "diplomacia": [], "politica": ["GOBIERNO"], "territorio": ["NATURALEZA"], "cultura": ["ETNIAS"]}
	for k in esperado:
		ok(hud.abrir_pestana(k), "se abre «%s»" % k)
		await esperar(0.2)
		ok(hud.lbl_seccion.text == String(hud.TITULO_SECCION[k]), "«%s» pone su título (%s)" % [k, hud.lbl_seccion.text])
		var tx := todo_texto()
		for frag in esperado[k]:
			ok(tx.contains(String(frag)), "«%s» trae «%s»" % [k, frag])
		ok(hud.cuerpo.get_child_count() > 0, "«%s» no está vacía" % k)


func t_quepan() -> void:
	print("[T] ── Cada sección cabe sin scroll")
	for tam in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await arrancar(2026, tam)
		main._seleccion_pais("España", "Europa", Vector2(1175.0, 330.0))
		await esperar(0.4)
		var hud = main.hud
		var largas: Array = []
		for k in NUEVE:
			if k == "militar":
				continue                                              # las tropas llevan su propia caja
			hud.abrir_pestana(k)
			await esperar(0.25)
			var h: float = hud.cuerpo.get_combined_minimum_size().y + 8.0
			print("[T]    %dx%d · %-11s alto del contenido %4.0f · tope del panel %4.0f" % [tam.x, tam.y, k, h, hud._alto_max])
			if h > hud._alto_max + 1.0:
				largas.append("%s (%.0f > %.0f)" % [k, h, hud._alto_max])
		ok(largas.is_empty(), "%dx%d: todas las secciones caben sin scroll (se pasan: %s)" % [tam.x, tam.y, str(largas)])
		main._limpiar_seleccion()
		await esperar(0.2)
		var pi := int(main.mundo.paises["España"].provincias[0])
		main._seleccion_provincia(pi, "Europa", Vector2(1175.0, 330.0))
		await esperar(0.4)
		var largas2: Array = []
		for k2 in hud.pestanas_de("provincia"):
			if k2 == "militar":
				continue
			hud.abrir_pestana(k2)
			await esperar(0.25)
			var h2: float = hud.cuerpo.get_combined_minimum_size().y + 8.0
			print("[T]    %dx%d · provincia %-11s alto %4.0f · tope %4.0f" % [tam.x, tam.y, k2, h2, hud._alto_max])
			if h2 > hud._alto_max + 1.0:
				largas2.append("%s (%.0f > %.0f)" % [k2, h2, hud._alto_max])
		ok(largas2.is_empty(), "%dx%d: las secciones de provincia caben sin scroll (se pasan: %s)" % [tam.x, tam.y, str(largas2)])


func run() -> void:
	await t_pestanas()
	await t_quepan()
	print("[T] ═══ RESULTADO runner113: %d OK, %d FALLOS" % [n_ok, fallos])
	print("FALLOS: %d" % fallos)
	get_tree().quit()
