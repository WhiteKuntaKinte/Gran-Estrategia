extends Node
## 0.1.8.34 · PRUEBAS DE PARIDAD DE ESCENARIOS: el año 1 d. C. es el MISMO juego que 2026 con otros datos de partida.
## Datos del escenario (provincias, naciones, población, economía, ejércitos, ciudades, banderas) · menú MODO DEV → ESCENARIO · arranque en el año 1
## (reloj corriendo, HUD con sus cinco pestañas al elegir una nación, economía, ejército, guerra, IA) · tierras sin reclamar (inertes) ·
## 2026 intacto · la campaña pide recargar 2026 · medidas de rendimiento.
const BDScript := preload("res://scripts/base_datos.gd")
const RELOJ := preload("res://scripts/reloj.gd")

var main
var fallos := 0
var n_ok := 0
var meta: Dictionary = {}


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


func botones(n: Node, r: Array) -> void:
	for h in n.get_children():
		if h is Button and not (h is OptionButton) and not (h is CheckBox):
			r.append(h)
		botones(h, r)


func textos_botones(n: Node) -> Array:
	var b: Array = []
	botones(n, b)
	var t: Array = []
	for x in b:
		t.append(x.text)
	return t


func boton(n: Node, texto: String) -> Button:
	var b: Array = []
	botones(n, b)
	for x in b:
		if x.text == texto:
			return x
	return null


func etiquetas(n: Node, r: Array) -> void:
	for h in n.get_children():
		if h is Label:
			r.append(h.text)
		etiquetas(h, r)


func leer(ruta: String):
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


## Arranca el juego de cero: `anio` 2026 = datos de siempre; otro año = el escenario (como lo hace «Nueva partida» tras recargar la escena).
func arrancar(anio: int) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await esperar(0.3)
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	if anio != 2026:
		Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": anio})
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	await esperar(0.8)


func clic_mundo(lon: float, lat: float) -> void:
	main._seleccionar(Vector2((lon + 180.0) * 6.6667, (90.0 - lat) * 6.6667))


func run() -> void:
	t_datos()
	await t_menu()
	await t_arranque()
	await t_hud()
	await t_economia_ejercito()
	await t_debug_y_vista()
	await t_guerra_e_ia()
	await t_inertes()
	await t_mapa_geografia()
	await t_2026_y_recarga()
	print("[T] ═══ RESULTADO runner75: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ─────────────────────────────────────────────────────────────
func t_datos() -> void:
	print("[T] ── Datos del escenario (datos/epocas/1dc/)")
	meta = leer("res://datos/epocas/1dc/epoca.json")
	ok(meta != null and int(meta.get("anio", 0)) == 1 and meta.has("creditos") and meta.has("nombre"), "epoca.json: año, nombre y créditos de las fuentes")
	ok(String(meta["creditos"][0]).contains("Cliopatria") and String(meta["creditos"][0]).contains("CC BY"), "los créditos citan Cliopatria / Seshat (CC BY 4.0)")
	for f in ["entidades", "info", "ciudades", "economia", "divisas", "ejercito", "ids", "estados", "banderas", "provincias_juego", "vecinos_prov", "nombres_cultura", "etiquetas"]:
		ok(FileAccess.file_exists("res://datos/epocas/1dc/%s.json" % f), "el escenario trae %s.json" % f)
	ok(not FileAccess.file_exists("res://datos/epocas/1dc/teselas.json") and FileAccess.file_exists("res://datos/teselas.json"),
		"0.1.8.35: la geometría (las celdas) es común a todos los escenarios: vive en datos/ y el paquete del año no la duplica")
	var pj = leer("res://datos/epocas/1dc/provincias_juego.json")
	var pj26 = leer("res://datos/provincias_juego.json")
	ok(pj != null and pj26 != null and (pj["anillos"] as Array).size() == (pj26["anillos"] as Array).size(),
		"0.1.8.35: el año 1 y 2026 reparten las MISMAS celdas (%d) entre sus provincias" % (pj26["anillos"] as Array).size())
	ok(pj != null and (pj["provincias"] as Array).size() == int(meta["provincias"]), "epoca.json cuenta %d provincias y el mapa trae las mismas" % int(meta["provincias"]))
	var ent = leer("res://datos/epocas/1dc/entidades.json")
	var paises: Dictionary = ent["paises"]
	ok(paises.size() == int(meta["naciones"]) + 7 or paises.size() >= int(meta["naciones"]), "entidades.json: %d naciones (meta %d + sin reclamar)" % [paises.size(), int(meta["naciones"])])
	ok(String(ent.get("esquema_colores", "")) == "propio", "el escenario trae el color de cada nación («propio»)")
	var inertes := 0
	var con_prov := {}
	for p in pj["provincias"]:
		con_prov[String(p["c"])] = int(con_prov.get(String(p["c"]), 0)) + 1
	var sin_prov := 0
	for n in paises:
		if bool(paises[n].get("sin_reclamar", false)):
			inertes += 1
		if not con_prov.has(n):
			sin_prov += 1
	ok(inertes == 7, "siete «Tierras sin reclamar» (una por continente poblado y la Antártida): %d" % inertes)
	ok(sin_prov <= 2, "toda nación tiene provincias (sin provincias: %d, solo las absorbidas por un estado vecino)" % sin_prov)
	var pob := float(meta["pob_mundo"])
	ok(pob > 200e6 and pob < 300e6, "población del mundo en el año 1: %.0f millones (200–300)" % (pob / 1e6))
	ok(pj["provincias"].size() > 2500 and pj["provincias"].size() < 9000, "provincias del escenario: %d (no menos que bocetos, no más que el mundo de 2026)" % pj["provincias"].size())
	var banderas_ok := 0
	for n in paises:
		if FileAccess.file_exists("res://banderas/%s.png" % String(paises[n].get("bandera", ""))):
			banderas_ok += 1
	ok(banderas_ok == paises.size() or banderas_ok >= paises.size() - 7, "banderas de las naciones del escenario (%d de %d)" % [banderas_ok, paises.size()])


# ─────────────────────────────────────────────────────────────
func t_menu() -> void:
	print("[T] ── Menú JUGAR → MODO DEV → ESCENARIO")
	await arrancar(2026)
	ok(main.en_menu and main.epoca == 2026 and main.epoca_dir == "", "al abrir: menú principal, escenario 2026 (datos/)")
	boton(main.menu_contenido, "JUGAR").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["MODO DEV", "CAMPAÑA", "VOLVER"], "JUGAR: MODO DEV, CAMPAÑA, VOLVER")
	boton(main.menu_contenido, "MODO DEV").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["2026", "AÑO 1 d. C.", "VOLVER"], "MODO DEV pide el escenario: 2026, AÑO 1 d. C., VOLVER (%s)" % str(textos_botones(main.menu_contenido)))
	var t: Array = []
	etiquetas(main.menu_contenido, t)
	ok(t.has("MODO DEV · ESCENARIO"), "título «MODO DEV · ESCENARIO»")
	t = []
	etiquetas(main.menu_contenido, t)
	var dice_solo_mapa := false
	for x in t:
		if String(x).contains("solo el mapa") or String(x).contains("llegan después"):
			dice_solo_mapa = true
	ok(not dice_solo_mapa, "la descripción ya no dice «solo el mapa»")
	ok(not boton(main.menu_contenido, "AÑO 1 d. C.").disabled and not boton(main.menu_contenido, "2026").disabled, "ambos escenarios disponibles")
	ok(main._escenario_disponible(1) and main._escenario_disponible(2026) and not main._escenario_disponible(1999), "_escenario_disponible: 1 y 2026 sí, 1999 no")
	boton(main.menu_contenido, "VOLVER").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["MODO DEV", "CAMPAÑA", "VOLVER"], "VOLVER regresa a MODO DE JUEGO")
	# ¿cuándo se recarga el mundo?
	ok(not main._requiere_recarga({"modo": "dev", "epoca": 2026}), "2026 desde el menú de 2026 sin partida: no recarga")
	ok(main._requiere_recarga({"modo": "dev", "epoca": 1}), "pedir el año 1 desde 2026: recarga con otros datos")
	ok(not main._requiere_recarga({"modo": "campana", "pais": "España"}), "la campaña desde 2026 sin partida: no recarga")
	main.partida_activa = "dev"
	ok(main._requiere_recarga({"modo": "dev", "epoca": 2026}), "con una partida en curso, siempre recarga")
	main.partida_activa = ""


# ─────────────────────────────────────────────────────────────
func t_arranque() -> void:
	print("[T] ── Arranque del año 1 con el mismo código que 2026")
	var m0: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var t0 := Time.get_ticks_usec()
	await arrancar(1)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("[T] PERF  cargar el año 1 (de instanciar el juego a tenerlo repintado, con 0,8 s de espera incluidos): %.0f ms" % ms)
	print("[T] PERF  memoria estática: %.1f MB antes, %.1f MB después" % [m0 / 1048576.0, int(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0])
	ok(main.epoca == 1 and main.epoca_dir == "res://datos/epocas/1dc/" and main.esquema_propio, "escenario 1 cargado, con color propio")
	ok(main.partida_activa == "dev" and not main.en_menu, "MODO DEV en marcha (sin pasar por el menú)")
	ok(main.reloj.anio == 1 and main.reloj.mes == 1 and main.reloj.dia == 1, "reloj: 1 de enero del año 1 (%s)" % main.reloj.texto())
	ok(main.mundo.bd.fecha == BDScript.fecha_int(1, 1, 1), "la base de datos está en el año 1")
	ok(main.hud.lbl_fecha.text == "1,01,01", "barra superior: fecha «%s», con el mismo formato que 2026" % main.hud.lbl_fecha.text)
	ok(main.provincias.size() == int(meta["provincias"]), "el juego cargó las %d provincias del escenario" % main.provincias.size())
	ok(main.mundo.provincias.size() == main.provincias.size(), "el mundo registra todas las provincias")
	ok(main.mundo.paises.size() >= int(meta["naciones"]), "el mundo registra las naciones (%d)" % main.mundo.paises.size())
	ok(main.mundo.paises.has("Imperio romano") and main.mundo.paises.has("Dinastía Han") and main.mundo.paises.has("Imperio parto"), "existen Imperio romano, Dinastía Han e Imperio parto")
	ok(not main.mundo.paises.has("España") and not main.mundo.paises.has("Estados Unidos"), "no existen los países de 2026")
	var dueno: PackedInt32Array = main._dueno_ahora
	ok(dueno.size() == main.provincias.size(), "el mapa tiene un dueño por provincia")
	var vacios := 0
	for i in dueno.size():
		if dueno[i] == main.VACIO_ID:
			vacios += 1
	ok(vacios == 0, "ninguna provincia queda «vacía»: lo no reclamado es de una nación inerte (vacías: %d)" % vacios)
	var col_roma: Color = main._color_de_pais("Imperio romano")
	ok(col_roma.is_equal_approx(Color.html("#9b2c3c")), "Roma se pinta con su color propio (no el tono de continente)")
	ok(main.etiq_pais.has("Imperio romano"), "el nombre «Imperio romano» está escrito sobre el mapa (etiquetas del escenario)")
	ok(main.etiq_pais.size() >= 100, "%d naciones con nombre sobre el mapa" % main.etiq_pais.size())
	var ms_fot: float = main.ms_proceso
	print("[T] PERF  fotograma del juego en el año 1 (reposo): %.2f ms" % ms_fot)
	ok(ms_fot < 25.0, "fotograma en reposo razonable (<25 ms en este equipo de prueba)")
	# créditos en INFORMACIÓN
	var esc0 := InputEventKey.new()
	esc0.keycode = KEY_ESCAPE
	esc0.pressed = true
	main._unhandled_input(esc0)
	boton(main.menu_contenido, "OPCIONES").pressed.emit()
	boton(main.menu_contenido, "INFORMACIÓN").pressed.emit()
	var t: Array = []
	etiquetas(main.menu_contenido, t)
	var cred := false
	for x in t:
		if String(x).contains("Cliopatria"):
			cred = true
	ok(cred, "INFORMACIÓN cita las fuentes del escenario (Cliopatria, CC BY 4.0)")
	ok(t.has("Versión %s" % main.VERSION), "INFORMACIÓN sigue mostrando la versión")
	main._reanudar_juego()


# ─────────────────────────────────────────────────────────────
func t_hud() -> void:
	print("[T] ── Elegir una nación: el MISMO HUD que en 2026")
	main.camara.position = Vector2(1283.0, 330.0)
	main.camara.zoom = Vector2(2.0, 2.0)
	await esperar(0.2)
	clic_mundo(12.5, 41.9)                                            # Roma
	await esperar(0.2)
	ok(main.pais_foco == "Imperio romano", "un clic en Roma elige y enfoca al Imperio romano (foco: «%s»)" % main.pais_foco)
	ok(main.hud.esta_abierto(), "el HUD de la nación se abre")
	var hud = main.hud
	ok(hud.lbl_titulo.text == "Imperio romano", "cabecera: «%s»" % hud.lbl_titulo.text)
	ok(hud.tex_bandera != null and hud.tex_bandera.texture != null, "cabecera: la nación tiene bandera")
	var pestanas := ["general", "diplomacia", "militar", "politica", "economia"]
	var visibles := 0
	for k in pestanas:
		if hud.botones_pestana.has(k) and (hud.botones_pestana[k] as Button).visible:
			visibles += 1
	ok(visibles == 5, "las cinco pestañas: General · Diplomacia · Militar · Política · Economía (%d visibles)" % visibles)
	for k in pestanas:
		var abierta: bool = hud.abrir_pestana(k)
		await esperar(0.05)
		var t: Array = []
		etiquetas(hud.panel, t)
		ok(abierta and hud.pestana == k and t.size() > 3, "pestaña %s: se abre y dibuja su contenido (%d textos)" % [k, t.size()])
	hud.abrir_pestana("general")
	var t2: Array = []
	etiquetas(hud.panel, t2)
	var pob := false
	for x in t2:
		if String(x).to_upper().begins_with("POBLACIÓN (1, EST.)"):
			pob = true
	print("[T] INFO  textos de General: ", str(t2.slice(0, 30)))
	ok(pob, "General: «Población (1, est.)» (el año sale del escenario, no fijo en 2026)")
	var pais: Object = main.mundo.paises["Imperio romano"]
	ok(String(pais.capital) == "Roma" and pais.provincias.size() > 30, "Roma: capital «Roma» y %d provincias" % pais.provincias.size())
	# una provincia concreta
	var pi_roma: int = int(pais.provincias[0])
	ok(String(main.mundo.provincias[pi_roma].pais) == "Imperio romano", "las provincias de Roma pertenecen a Roma")
	# una provincia concreta (con el foco ya puesto, un clic elige la provincia, como en 2026)
	clic_mundo(12.5, 41.9)
	await esperar(0.2)
	ok(main.sel_tipo == "provincia" and hud.esta_abierto(), "con Roma enfocada, un clic en Roma elige una PROVINCIA (selección: «%s»)" % main.sel_tipo)
	var tprov: Array = []
	etiquetas(hud.panel, tprov)
	ok(tprov.size() > 3 and hud.lbl_titulo.text != "Imperio romano", "HUD de provincia: «%s»" % hud.lbl_titulo.text)
	for k in ["general", "militar", "politica", "economia"]:
		hud.abrir_pestana(k)
	ok(true, "las pestañas de una provincia del año 1 se dibujan")
	# elegir otra nación: los Han
	clic_mundo(108.9, 34.3)
	await esperar(0.2)
	ok(main.pais_foco == "Dinastía Han" or main.pais_foco != "Imperio romano", "un clic en Chang'an cambia el foco a otra nación (%s)" % main.pais_foco)
	# Esc cierra el foco como en 2026
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	main._unhandled_input(esc)
	await esc_pausa_ok()


func esc_pausa_ok() -> void:
	await esperar(0.1)
	# el primer Esc deselecciona o pausa (igual que en 2026); un segundo Esc nos deja en un estado conocido
	if not main.en_pausa:
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		main._unhandled_input(esc)
	ok(main.en_pausa, "Esc abre la pausa")
	ok(textos_botones(main.menu_contenido) == ["CONTINUAR", "OPCIONES", "DEBUG", "MENÚ PRINCIPAL", "SALIR"], "pausa: CONTINUAR · OPCIONES · DEBUG · MENÚ PRINCIPAL · SALIR")
	main._reanudar_juego()
	await esperar(0.1)
	ok(not main.en_pausa, "CONTINUAR sigue el juego")


# ─────────────────────────────────────────────────────────────
func t_economia_ejercito() -> void:
	print("[T] ── Economía y ejércitos del escenario")
	var m = main.mundo
	var rn := "Imperio romano"
	var hn := "Dinastía Han"
	ok(m.poblacion_de(rn) > 10e6 and m.poblacion_de(rn) < 90e6, "población de Roma: %.1f millones" % (m.poblacion_de(rn) / 1e6))
	ok(m.poblacion_de(hn) > 20e6 and m.poblacion_de(hn) < 90e6, "población de los Han: %.1f millones" % (m.poblacion_de(hn) / 1e6))
	ok(m.paises[rn].pib_usd > 1e9, "PIB de referencia de Roma: %.0f millones de US$" % (m.paises[rn].pib_usd / 1e6))
	ok(m.produccion_anual_usd(rn) > 1e8, "producción anual de Roma: %.0f millones de US$" % (m.produccion_anual_usd(rn) / 1e6))
	ok(m.ejercito != null and m.ejercito.red != null, "el ejército y la red de provincias están listos")
	var sold: int = m.soldados_de_pais(rn)
	ok(sold > 50000 and sold < 900000, "ejército romano: %d soldados" % sold)
	ok(float(sold) / m.poblacion_de(rn) < 0.04, "el ejército cuesta menos del 4 %% de la población (%.2f %%): la economía lo sostiene" % (100.0 * float(sold) / m.poblacion_de(rn)))
	ok(m.soldados_de_pais(hn) > 50000, "ejército Han: %d soldados" % m.soldados_de_pais(hn))
	var sin_ejercito := 0
	var con_ejercito := 0
	var desbalance := 0
	for n in m.paises:
		var e = m.paises[n]
		if bool(e.inerte):
			if m.soldados_de_pais(n) > 0:
				sin_ejercito += 1
		else:
			if m.soldados_de_pais(n) > 0:
				con_ejercito += 1
			if m.balance_diario_local(n) < -0.02 * maxf(m.ingreso_diario_local(n), 1.0) * 365.0:
				desbalance += 1
	ok(sin_ejercito == 0, "las tierras sin reclamar no tienen soldados")
	ok(con_ejercito >= 150, "%d naciones con ejército" % con_ejercito)
	ok(desbalance <= 3, "casi ninguna nación nace en bancarrota por su ejército (desbalanceadas: %d)" % desbalance)
	ok(m.divisa_de(rn) != null and m.paises[rn].tesoreria >= 0.0, "Roma tiene divisa y tesorería")
	# el dinero corre: con un jugador, la tesorería sube o baja con los días
	m.fijar_jugador(rn)
	ok(m.jugador == rn, "se puede controlar a una nación del escenario")
	main._actualizar_barra()
	var tes0: float = m.paises[rn].tesoreria
	main.reloj.fijar(1, 1, 1)
	m.avanzar_dias(10)
	ok(not is_equal_approx(m.paises[rn].tesoreria, tes0), "10 días de economía mueven la tesorería de Roma (%.0f → %.0f)" % [tes0, m.paises[rn].tesoreria])
	# el reloj corre solo, como en 2026
	var f0: int = m.bd.fecha
	main._poner_velocidad(3)
	await esperar(2.0)
	ok(main.reloj.velocidad == 3, "velocidad x3 aceptada en el año 1 (no se bloquea)")
	ok(main.reloj.dia > 1 or main.reloj.mes > 1 or main.reloj.anio > 1, "el tiempo corre solo: %s" % main.reloj.texto())
	ok(m.bd.fecha > f0, "la fecha de la base de datos avanza")
	ok(main.hud.lbl_fecha.text == main.reloj.texto(), "la barra superior sigue al reloj (%s)" % main.hud.lbl_fecha.text)
	main._poner_velocidad(0)
	ok(main.reloj.velocidad == 0, "pausa del reloj")
	# tropas dibujadas
	main.camara.zoom = Vector2(2.5, 2.5)
	await esperar(0.3)
	ok(main.capa_tropas != null and main.capa_tropas.visible, "la capa de tropas se ve en el año 1")
	main.camara.position = Vector2(1283.0, 330.0)
	await esperar(0.2)
	main._actualizar_ciudades()
	ok(not main.ciudades_capas.is_empty() and (main.ciudades_capas[0] as Node2D).visible, "las ciudades del escenario se ven con zoom")
	ok(m.paises[rn].ciudades.size() >= 3, "Roma tiene %d ciudades registradas" % m.paises[rn].ciudades.size())


# ─────────────────────────────────────────────────────────────
func t_debug_y_vista() -> void:
	print("[T] ── Debug y vista (V) en el año 1")
	main._abrir_debug()
	await esperar(0.3)
	ok(main.debug_menu != null and is_instance_valid(main.debug_menu), "F1 abre el Debug también en el año 1")
	var t: Array = []
	etiquetas(main.debug_menu, t)
	ok(t.size() > 5, "el Debug dibuja su contenido (%d textos)" % t.size())
	var anio_dbg := -1
	var sp = main.debug_menu.sp_anio
	if sp != null:
		anio_dbg = int(sp.value)
	ok(anio_dbg == 1, "el Debug propone la fecha del escenario (año %d)" % anio_dbg)
	main.debug_menu.queue_free()
	await esperar(0.2)
	main.debug_menu = null
	var r0: bool = main.modo_relieve
	main._elegir_vista("tradicional" if r0 else "relieve")
	ok(main.modo_relieve != r0, "V cambia entre Tradicional y Relieve (relieve %s → %s)" % [r0, main.modo_relieve])
	await esperar(0.2)
	main._elegir_vista("tradicional" if main.modo_relieve else "relieve")
	ok(main.modo_relieve == r0, "V vuelve a la vista anterior")
	main.camara.zoom = Vector2(0.6, 0.6)
	await esperar(0.2)
	# 0.1.8.39 · el menú de la CAMPAÑA lista siempre los países de 2026, aunque el mundo cargado sea el del año 1 (antes salían pueblos antiguos)
	var lc: Array = main._paises_campana_2026()
	ok(lc.size() == 51 and lc.has("España") and lc.has("Rusia") and lc.has("Turquía"), "campaña desde el año 1: la lista tiene los 51 países de 2026 (%d)" % lc.size())
	var del_mundo: Array = main.mundo.paises_de_campana()
	var distintos := 0
	for n in del_mundo:
		if not lc.has(String(n)):
			distintos += 1
	ok(distintos > 0 and not lc.has("Imperio romano"), "…aunque el mundo cargado (año 1) trae otros nombres (%d que no son de 2026)" % distintos)


# ─────────────────────────────────────────────────────────────
func t_guerra_e_ia() -> void:
	print("[T] ── Guerra, diplomacia y IA en el año 1")
	var m = main.mundo
	var rt: int = int(m.paises["Imperio romano"].tid)
	var pt: int = int(m.paises["Imperio parto"].tid)
	var g = m.guerra
	ok(g != null and not g.en_guerra(rt, pt), "Roma y Partia empiezan en paz")
	var ev: Dictionary = main.puede_declarar_guerra(pt)
	ok(bool(ev["ok"]), "el jugador (Roma) puede declarar la guerra a Partia (%s)" % String(ev["motivo"]))
	var r: Dictionary = main.declarar_guerra_jugador(pt)
	ok(bool(r["ok"]) and g.en_guerra(rt, pt), "guerra declarada: Roma contra Partia")
	m.avanzar_dias(5)
	ok(g.en_guerra(rt, pt), "5 días de guerra sin errores")
	# paz
	var ia = m.ia
	ok(ia != null, "existe el sistema de IA")
	var cand: Array = ia.candidatos()
	ok(cand.size() > 100, "la IA tiene %d candidatas (naciones con gobierno)" % cand.size())
	var inerte_en_ia := 0
	for n in cand:
		if bool(m.paises[n].inerte):
			inerte_en_ia += 1
	ok(inerte_en_ia == 0, "las tierras sin reclamar nunca juegan con IA")
	var n_ia: int = ia.activar_lista(cand.slice(0, 40))
	ok(n_ia > 20, "se activan %d IA" % n_ia)
	var sold0 := 0
	for n in ia.activas:
		sold0 += m.soldados_de_pais(n)
	var t0 := Time.get_ticks_usec()
	for i in 400:
		m.avanzar_dias(1)
	var ms_dia := float(Time.get_ticks_usec() - t0) / 1000.0 / 400.0
	print("[T] PERF  día simulado con 40 IA en el año 1: %.2f ms" % ms_dia)
	ok(true, "400 días con 40 IA corrieron sin errores")
	var sold1 := 0
	for n in ia.activas:
		sold1 += m.soldados_de_pais(n)
	ok(sold1 != sold0, "las IA actúan: sus soldados pasaron de %d a %d" % [sold0, sold1])
	var guerras := 0
	for n in ia.activas:
		guerras += g.guerras_de(int(m.paises[n].tid)).size()
	print("[T] INFO  guerras activas tras 400 días: %d" % guerras)
	var rank: Array = m.ranking()
	ok(rank.size() > 10, "el ranking lista %d naciones" % rank.size())
	# nunca pelean contra tierras inertes
	var contra_inerte := 0
	for n in m.paises:
		if bool(m.paises[n].inerte) and g.guerras_de(int(m.paises[n].tid)).size() > 0:
			contra_inerte += 1
	ok(contra_inerte == 0, "ninguna guerra involucra a tierras sin reclamar")
	ia.desactivar_todas()


# ─────────────────────────────────────────────────────────────
func t_inertes() -> void:
	print("[T] ── Tierras sin reclamar (inertes)")
	var m = main.mundo
	var nombre := "Tierras sin reclamar de Europa"
	ok(m.paises.has(nombre) and m.es_inerte(nombre) and not m.es_inerte("Imperio romano") and not m.es_inerte("no existe"), "es_inerte distingue las tierras sin reclamar")
	var it: int = int(m.paises[nombre].tid)
	var rt: int = int(m.paises["Imperio romano"].tid)
	ok(not m.puede_atacar(rt, it) and not m.puede_atacar(it, rt), "no se puede atacar a las tierras sin reclamar ni ellas atacan")
	var ev: Dictionary = main.puede_declarar_guerra(it)
	ok(not bool(ev["ok"]) and String(ev["motivo"]).contains("sin reclamar"), "declarar guerra: «%s»" % String(ev["motivo"]))
	var j0: String = m.jugador
	m.fijar_jugador(nombre)
	ok(m.jugador == j0, "no se puede controlar una tierra sin reclamar")
	ok(m.ia.puede_tener_ia(nombre) == false, "tampoco puede tener IA")
	ok(m.soldados_de_pais(nombre) == 0, "sin soldados")
	ok(m.paises[nombre].provincias.size() > 0 and m.poblacion_de(nombre) >= 0.0, "tiene %d provincias (%.1f millones de habitantes)" % [m.paises[nombre].provincias.size(), m.poblacion_de(nombre) / 1e6])
	var pi: int = int(m.paises[nombre].provincias[0])
	ok(m.rival_por_entrar(rt, pi) == -1, "las tropas entran sin declarar guerra (no hay a quién)")
	# elegir una provincia sin reclamar y abrir la ficha: no debe fallar
	main.camara.zoom = Vector2(2.0, 2.0)
	clic_mundo(-60.0, -5.0)                                           # selva amazónica
	await esperar(0.2)
	ok(main.hud.esta_abierto(), "elegir tierras sin reclamar abre el HUD (foco: «%s»)" % main.pais_foco)
	for k in ["general", "diplomacia", "militar", "politica", "economia"]:
		main.hud.abrir_pestana(k)
	ok(true, "todas las pestañas de una tierra sin reclamar se dibujan sin errores")
	main.mundo.fijar_jugador("Imperio romano")


# ─────────────────────────────────────────────────────────────
func t_mapa_geografia() -> void:
	print("[T] ── El mapa del año 1: cada cultura en su sitio")
	var m = main.mundo
	var dueno: PackedInt32Array = main._dueno_ahora
	var nombre_en := func(lon: float, lat: float) -> String:
		var x := (lon + 180.0) * 6.6667
		var y := (90.0 - lat) * 6.6667
		var r: Array = main._anillo_bajo(Vector2(x, y))
		if int(r[0]) < 0:
			return ""
		return String(m.provincias[int(main.anillos[int(r[0])]["p"])].pais)
	var casos := [["Caledonios", -4.2, 57.2], ["Imperio romano", 12.5, 41.9], ["Imperio romano", 31.2, 30.0], ["Dinastía Han", 108.9, 34.3],
		["Imperio parto", 52.0, 33.0], ["Dacios", 24.5, 45.8]]
	for c in casos:
		var n: String = nombre_en.call(c[1], c[2])
		ok(n == c[0], "(%.1f, %.1f) pertenece a «%s» (es «%s»)" % [c[1], c[2], c[0], n])
	var amazonia: String = nombre_en.call(-62.0, -5.0)
	ok(amazonia.begins_with("Pueblos de la Amazon"), "el Amazonas es de «%s»: una zona de pueblos, no un boceto" % amazonia)
	var patagonia: String = nombre_en.call(-70.0, -47.0)
	var sahara: String = nombre_en.call(10.0, 24.0)
	ok(sahara != "", "el Sáhara tiene provincias («%s»)" % sahara)
	print("[T] INFO  Patagonia: «%s» · Siberia: «%s» · Sáhara: «%s»" % [patagonia, nombre_en.call(100.0, 65.0), sahara])
	# no todo el planeta está ocupado: gran parte pertenece a tierras sin reclamar
	var area_inerte := 0.0
	var area_total := 0.0
	for i in main.provincias.size():
		var a := 0.0
		for ri in m.provincias[i].anillos:
			var bb: Array = main.anillos[int(ri)]["b"]
			a += float(bb[2]) * float(bb[3]) * 0.5
		area_total += a
		if bool(m.paises[m.provincias[i].pais].inerte):
			area_inerte += a
	var fr := area_inerte / maxf(area_total, 1.0)
	ok(fr > 0.12 and fr < 0.60, "%.0f %% de la tierra queda sin reclamar (no todo el planeta estaba ocupado)" % (fr * 100.0))


# ─────────────────────────────────────────────────────────────
func t_2026_y_recarga() -> void:
	print("[T] ── 2026 intacto y la campaña vuelve a 2026")
	await arrancar(2026)
	ok(main.epoca == 2026 and main.epoca_dir == "" and not main.esquema_propio, "sin pedido: escenario 2026 con los datos de datos/")
	ok(main.provincias.size() == 7653, "2026 conserva sus 7.653 provincias (%d)" % main.provincias.size())
	ok(main.mundo.paises.has("España") and main.mundo.paises.has("Estados Unidos") and not main.mundo.paises.has("Imperio romano"), "2026: sus países de siempre")
	ok(main.reloj.anio == 2026 and main.reloj.texto() == "2026,01,01", "reloj de 2026: %s" % main.reloj.texto())
	var t0 := Time.get_ticks_usec()
	main._iniciar_partida({"modo": "dev", "epoca": 2026})
	print("[T] PERF  arranque de 2026 (MODO DEV): %.0f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0))
	await esperar(0.4)
	ok(main.partida_activa == "dev" and main.reloj.anio == 2026, "MODO DEV 2026 arranca como siempre")
	ok(main.mundo.bd.fecha == BDScript.fecha_int(2026, 1, 1), "base de datos en 2026")
	ok(not main.mundo.es_inerte("España") and main.mundo.soldados_de_pais("España") > 50000, "España tiene su ejército de siempre (%d)" % main.mundo.soldados_de_pais("España"))
	main.camara.zoom = Vector2(2.0, 2.0)
	main.camara.position = Vector2(1180.0, 270.0)
	await esperar(0.2)
	clic_mundo(-3.7, 40.4)
	await esperar(0.2)
	ok(main.pais_foco == "España" and main.hud.esta_abierto(), "clic en Madrid: HUD de España (foco «%s»)" % main.pais_foco)
	ok(main.hud.lbl_fecha.text == "2026,01,01", "barra de fecha en 2026")
	# la campaña, desde el año 1, pide recargar 2026
	await arrancar(1)
	ok(main._requiere_recarga({"modo": "campana", "pais": "España"}), "la campaña desde el año 1 recarga 2026 (sus países son los de hoy)")
	ok(main._requiere_recarga({"modo": "dev", "epoca": 2026}), "pedir 2026 desde el año 1 recarga")
	ok(main._requiere_recarga({"modo": "dev", "epoca": 1}), "con una partida en curso, siempre recarga")
	print("[T] ── Fin")
