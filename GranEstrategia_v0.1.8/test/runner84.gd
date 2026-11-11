extends Node
## 0.1.8.41 · PRUEBAS DE PINTURAS: nombres y carpetas (clave), región de cada país, la cadena país → región → continente → mundo, que cada pintura instalada
## exista, se cargue y tenga su ficha (título, autor, licencia), la caché de texturas, la tarjeta del panel en 2026 y en el año 1, y los créditos.
var main
var fallos := 0
var n_ok := 0
const Pint := preload("res://scripts/pinturas.gd")


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
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)


func run() -> void:
	t_claves()
	await t_2026()
	await t_hud()
	await t_epoca_1()
	print("[T] ═══ RESULTADO runner84: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func mp(lon: float, lat: float) -> Vector2:
	return Vector2((lon + 180.0) * 2400.0 / 360.0, (90.0 - lat) * 1200.0 / 180.0)


func textos_imagen(n: Node, acc := []) -> Array:
	if n is TextureRect:
		acc.append(n)
	for h in n.get_children():
		textos_imagen(h, acc)
	return acc


# ─────────────────────────────────────────────────────────────
func t_claves() -> void:
	print("[T] ── Claves y regiones (sin escenario)")
	ok(Pint.clave("España") == "espana", "España → espana")
	ok(Pint.clave("Reino Unido") == "reino_unido", "Reino Unido → reino_unido")
	ok(Pint.clave("República Democrática del Congo") == "republica_democratica_del_congo", "República Democrática del Congo")
	ok(Pint.clave("Pueblos de Java, Bali y las Pequeñas Sondas") == "pueblos_de_java_bali_y_las_pequenas_sondas", "nombre con comas y ñ")
	ok(Pint.clave("Muiscas (Periodo Herrera, Altiplano Cundiboyacense)") == "muiscas_periodo_herrera_altiplano_cundiboyacense", "nombre con paréntesis")
	ok(Pint.clave("América del Sur") == "america_del_sur", "continente: América del Sur")
	ok(Pint.clave("  ¡¡Hola!!  ") == "hola", "signos y espacios de los bordes no dejan «_»")
	ok(Pint.region_en("Europa", 2.0, 46.0) == "region_europa_occidental", "Francia: Europa occidental")
	ok(Pint.region_en("Europa", -3.7, 40.4) == "region_mediterraneo", "España: Mediterráneo")
	ok(Pint.region_en("Europa", 19.0, 52.0) == "region_europa_este", "Polonia: Europa del este")
	ok(Pint.region_en("Europa", 26.0, 64.0) == "region_europa_norte", "Finlandia: Europa del norte")
	ok(Pint.region_en("Europa", 15.0, 62.0) == "region_europa_norte", "Suecia: Europa del norte")
	ok(Pint.region_en("Asia", 138.0, 37.0) == "region_asia_este", "Japón: Asia oriental")
	ok(Pint.region_en("Asia", 101.0, 15.0) == "region_sudeste_asiatico", "Tailandia: sudeste asiático")
	ok(Pint.region_en("Asia", 78.0, 22.0) == "region_asia_sur", "India: Asia meridional")
	ok(Pint.region_en("Asia", 54.0, 32.0) == "region_oriente_medio", "Irán: Oriente Medio")
	ok(Pint.region_en("Asia", 67.0, 48.0) == "region_asia_central", "Kazajistán: Asia central")
	ok(Pint.region_en("África", 30.0, 26.0) == "region_africa_norte", "Egipto: norte de África")
	ok(Pint.region_en("África", 38.0, 0.0) == "region_africa_subsahariana", "Kenia: África subsahariana")
	ok(Pint.region_en("América del Norte", -102.0, 23.0) == "region_mesoamerica_caribe", "México: Mesoamérica y Caribe")
	ok(Pint.region_en("América del Norte", -100.0, 55.0) == "region_norteamerica", "Canadá: Norteamérica")
	ok(Pint.region_en("América del Sur", -75.0, -10.0) == "region_sudamerica_andes", "Perú: Andes")
	ok(Pint.region_en("América del Sur", -55.0, -10.0) == "region_sudamerica_este", "Brasil: Sudamérica oriental")
	ok(Pint.region_en("Oceanía", 134.0, -25.0) == "region_oceania", "Australia: Oceanía")
	ok(Pint.region_en("Antártida", 0.0, -80.0) == "", "Antártida: sin región")


func t_2026() -> void:
	print("[T] ── Escenario 2026: la cadena país → región → continente → mundo")
	await arrancar(2026)
	var p = main.pinturas
	ok(p != null and p.listo, "el sistema de pinturas cargó pinturas/creditos.json (%d obras)" % (p.creditos.size() if p != null else 0))
	if p == null or not p.listo:
		return
	ok(p.carpeta_epoca() == "2026", "la carpeta de la época es «2026»")
	var cont: Dictionary = p.contar()
	ok(int(cont.get("2026", 0)) >= 60 and int(cont.get("1dc", 0)) >= 25 and int(cont.get("general", 0)) >= 20, "pinturas por carpeta: %s" % str(cont))
	# toda pintura instalada: archivo, ficha completa, textura que carga
	var sin_archivo := []
	var sin_ficha := []
	for id in p.creditos:
		var c: Dictionary = p.creditos[id]
		if not FileAccess.file_exists("res://pinturas/%s.jpg" % id):
			sin_archivo.append(id)
		if String(c.get("titulo", "")) == "" or String(c.get("artista", "")) == "" or String(c.get("licencia", "")) == "" or String(c.get("url", "")) == "":
			sin_ficha.append(id)
	ok(sin_archivo.is_empty(), "cada ficha tiene su archivo .jpg (faltan %d: %s)" % [sin_archivo.size(), str(sin_archivo.slice(0, 3))])
	ok(sin_ficha.is_empty(), "cada ficha tiene título, autor, licencia y enlace (incompletas %d: %s)" % [sin_ficha.size(), str(sin_ficha.slice(0, 3))])
	var libres := true
	for id in p.creditos:
		var lic := String(p.creditos[id].get("licencia", "")).to_lower()
		if not (lic.contains("public domain") or lic.contains("cc0") or lic.contains("no restrictions")):
			libres = false
	ok(libres, "todas las licencias son dominio público / CC0")
	# nombres de las pinturas del 2026 = países reales
	var claves_paises := {}
	for nombre in main.mundo.paises:
		claves_paises[Pint.clave(String(nombre))] = String(nombre)
	var huerfanas := []
	for id in p.creditos:
		if String(id).begins_with("2026/") and not claves_paises.has(String(id).substr(5)):
			huerfanas.append(id)
	ok(huerfanas.is_empty(), "cada pintura de 2026 corresponde a un país real (sin país: %s)" % str(huerfanas))
	# regiones: todos los países con foco reciben una (salvo la Antártida)
	var sin_region := []
	for nombre in main.mundo.paises:
		var pe = main.mundo.paises[nombre]
		if pe.continente != "Antártida" and pe.foco.size() >= 4 and p.region_de(String(nombre)) == "":
			sin_region.append(nombre)
	ok(sin_region.is_empty(), "todos los países tienen región (sin región: %s)" % str(sin_region.slice(0, 5)))
	# cadena
	var f: Dictionary = p.de_pais("España")
	ok(String(f.get("nivel", "")) == "pais" and String(f.get("id", "")) == "2026/espana" and String(f.get("titulo", "")).findn("mayo") >= 0, "España: su propia pintura (%s)" % String(f.get("titulo", "")))
	ok(String(f.get("texto", "")).contains("Goya"), "la leyenda lleva al autor: %s" % String(f.get("texto", "")))
	var sin_propia := ""
	for nombre in main.mundo.paises:
		if main.mundo.paises[nombre].continente == "América del Sur" and not p.creditos.has("2026/" + Pint.clave(String(nombre))):
			sin_propia = String(nombre)
			break
	if sin_propia != "":
		var g: Dictionary = p.de_pais(sin_propia)
		ok(String(g.get("nivel", "")) == "region" and String(g["id"]).begins_with("general/region_sudamerica"), "%s no tiene propia: usa la de su región (%s)" % [sin_propia, String(g.get("id", ""))])
	var ant := ""
	for nombre in main.mundo.paises:
		if main.mundo.paises[nombre].continente == "Antártida":
			ant = String(nombre)
			break
	if ant != "":
		var h: Dictionary = p.de_pais(ant)
		ok(String(h.get("nivel", "")) == "continente" and String(h["id"]) == "general/continente_antartida", "un territorio antártico sin pintura usa la del continente (%s)" % String(h.get("id", "")))
	var w: Dictionary = p.de_pais("País que no existe")
	ok(String(w.get("nivel", "")) == "mundo" and String(w["id"]) == "general/mundo", "un nombre desconocido cae a la pintura del mundo")
	var cc: Dictionary = p.de_continente("Europa")
	ok(String(cc.get("id", "")) == "general/continente_europa", "continente Europa: su pintura")
	# texturas y caché
	var t1: Texture2D = p.textura(String(f["ruta"]))
	ok(t1 != null and t1.get_width() >= 600 and t1.get_width() <= 1000, "la textura de España carga (%dx%d)" % [t1.get_width() if t1 else 0, t1.get_height() if t1 else 0])
	ok(p.textura(String(f["ruta"])) == t1, "la segunda vez sale de la caché (misma textura)")
	ok(p.textura("res://pinturas/no_existe.jpg") == null, "una ruta que no existe da null (sin error)")
	var cargadas := 0
	for id in p.creditos:
		if cargadas >= 25:
			break
		if p.textura("res://pinturas/%s.jpg" % id) != null:
			cargadas += 1
	ok(cargadas == 25 and p._tex.size() <= Pint.MAX_CACHE, "la caché no pasa de %d texturas (hay %d tras cargar 25)" % [Pint.MAX_CACHE, p._tex.size()])
	var pesos_ok := true
	var peor := 0
	for id in p.creditos:
		var tam := FileAccess.get_file_as_bytes("res://pinturas/%s.jpg" % id).size()
		peor = maxi(peor, tam)
		if tam > 400000 or tam < 8000:
			pesos_ok = false
	ok(pesos_ok, "cada .jpg pesa entre 8 KB y 400 KB (el mayor: %d KB)" % (peor / 1024))
	ok(p.texto_creditos().contains("dominio público") and p.texto_creditos().contains(str(p.creditos.size())), "texto de créditos: %s" % p.texto_creditos().substr(0, 70))


func t_hud() -> void:
	print("[T] ── Tarjeta de pintura en el panel")
	var m = main.mundo
	var hud = main.hud
	var pi: int = int(m.paises["España"].provincias[0])
	main._seleccion_provincia(pi, m.continente_de_provincia(pi), Vector2(1200.0, 300.0))
	await fotogramas(3)
	var f: Dictionary = hud.datos.get("pintura", {})
	ok(not f.is_empty() and String(f["id"]) == "2026/espana", "al elegir una provincia de España, el HUD recibe la pintura de España")
	var imgs := textos_imagen(hud.cuerpo)
	var enc := false
	for i in imgs:
		var ti: TextureRect = i
		if ti.texture != null and ti.custom_minimum_size.y == hud.ALTO_PINTURA:
			enc = true
	ok(enc, "la pestaña General muestra la pintura arriba (alto %d)" % int(hud.ALTO_PINTURA))
	var primero = hud.cuerpo.get_child(0) if hud.cuerpo.get_child_count() > 0 else null
	ok(primero != null and textos_imagen(primero).size() > 0, "es la PRIMERA tarjeta del panel")
	var leyenda := false
	var pila := [hud.cuerpo]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is Label and (n as Label).text == String(f.get("texto", "")):
			leyenda = true
		pila.append_array(n.get_children())
	ok(leyenda, "la leyenda con título y autor está en el panel: %s" % String(f.get("texto", "")))
	var ya_dibujado: int = hud.cuerpo.get_child_count()
	main._seleccion_provincia(pi, m.continente_de_provincia(pi), Vector2(1200.0, 300.0))
	await fotogramas(2)
	ok(hud.cuerpo.get_child_count() == ya_dibujado, "elegir lo mismo otra vez no duplica tarjetas")
	main._seleccion_continente("Europa", Vector2(1200.0, 300.0))
	await fotogramas(3)
	ok(String(hud.datos.get("pintura", {}).get("id", "")) == "general/continente_europa", "al elegir el continente Europa: su pintura")
	# tierras sin reclamar: la tarjeta sigue, con la pintura de su región o continente
	var libre := -1
	for pr in m.provincias:
		if m.es_inerte(pr.pais):
			libre = pr.idx
			break
	if libre >= 0:
		main._seleccion_provincia(libre, m.continente_de_provincia(libre), Vector2(1200.0, 300.0))
		await fotogramas(3)
		ok(not hud.datos.get("pintura", {}).is_empty(), "una zona sin reclamar también lleva pintura")
	else:
		ok(true, "(2026 no tiene zonas sin reclamar)")
	# sin pinturas instaladas el panel funciona igual
	var guardadas: Dictionary = main.pinturas.creditos
	main.pinturas.creditos = {}
	main.pinturas.listo = false
	main._seleccion_provincia(pi, m.continente_de_provincia(pi), Vector2(1200.0, 300.0))
	await fotogramas(3)
	var con_pintura := false
	for i in textos_imagen(hud.cuerpo):
		if (i as TextureRect).custom_minimum_size.y == hud.ALTO_PINTURA:
			con_pintura = true
	ok(not hud.datos.has("pintura") and not con_pintura, "sin pinturas instaladas no hay tarjeta ni error")
	main.pinturas.creditos = guardadas
	main.pinturas.listo = true


func t_epoca_1() -> void:
	print("[T] ── Año 1 d. C.")
	await arrancar(1)
	var p = main.pinturas
	ok(p != null and p.listo and p.carpeta_epoca() == "1dc", "año 1: la carpeta de la época es «1dc»")
	var rom := ""
	for nombre in main.mundo.paises:
		if Pint.clave(String(nombre)) == "imperio_romano":
			rom = String(nombre)
	ok(rom != "", "el Imperio romano existe con ese nombre en los datos del año 1 (%s)" % rom)
	if rom != "":
		var f: Dictionary = p.de_pais(rom)
		ok(String(f.get("nivel", "")) == "pais" and String(f["id"]) == "1dc/imperio_romano", "Roma: su pintura del año 1 (%s)" % String(f.get("titulo", "")))
	var huerfanas := []
	var claves := {}
	for nombre in main.mundo.paises:
		claves[Pint.clave(String(nombre))] = true
	for id in p.creditos:
		if String(id).begins_with("1dc/") and not claves.has(String(id).substr(4)):
			huerfanas.append(id)
	ok(huerfanas.is_empty(), "cada pintura del año 1 corresponde a un pueblo real de los datos (sin pueblo: %s)" % str(huerfanas))
	var sin_region := []
	for nombre in main.mundo.paises:
		var pe = main.mundo.paises[nombre]
		if pe.continente != "Antártida" and pe.foco.size() >= 4 and p.region_de(String(nombre)) == "":
			sin_region.append(nombre)
	ok(sin_region.is_empty(), "todos los pueblos del año 1 tienen región (sin región: %s)" % str(sin_region.slice(0, 5)))
	var sin_nada := 0
	for nombre in main.mundo.paises:
		if p.de_pais(String(nombre)).is_empty():
			sin_nada += 1
	ok(sin_nada == 0, "ningún pueblo ni país se queda sin pintura (la cadena siempre llega a alguna)")
	# una zona sin reclamar del año 1: el panel lleva la pintura de su región o continente
	var m = main.mundo
	var libre := -1
	for pr in m.provincias:
		if m.es_inerte(pr.pais):
			libre = pr.idx
			break
	ok(libre >= 0, "el año 1 tiene zonas sin reclamar")
	if libre >= 0:
		main._seleccion_provincia(libre, m.continente_de_provincia(libre), Vector2(1200.0, 300.0))
		await fotogramas(3)
		var f2: Dictionary = main.hud.datos.get("pintura", {})
		ok(String(main.hud.datos.get("tipo", "")) == "libre" and not f2.is_empty(), "zona sin reclamar: el HUD es «libre» y recibe pintura (%s)" % String(f2.get("id", "")))
		var hay := false
		for i in textos_imagen(main.hud.cuerpo):
			if (i as TextureRect).custom_minimum_size.y == main.hud.ALTO_PINTURA:
				hay = true
		ok(hay, "la tarjeta de pintura se ve también en una zona sin reclamar")
