extends Node
## 0.1.8.43 · PRUEBAS DE PINTURAS POR LUGAR: la pintura de una provincia o de un estado de EE. UU. antes que la del país, la región según dónde cae la provincia,
## que cada clave instalada («lugar_…», «estado_…») corresponda a una provincia o estado real de los datos, el HUD (provincia, ciudad, estado) y los créditos.
var main
var m
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
	m = main.mundo


func provincia_de(pais: String, nombre: String) -> int:
	for pr in m.provincias:
		if pr.pais_original == pais and pr.nombre == nombre:
			return pr.idx
	return -1


func ficha_falsa(titulo: String) -> Dictionary:
	return {"titulo": titulo, "artista": "Pintor de prueba", "fecha": "1800", "licencia": "Public domain", "url": "https://commons.wikimedia.org/wiki/File:Prueba.jpg"}


func textos_imagen(n: Node, acc := []) -> Array:
	if n is TextureRect:
		acc.append(n)
	for h in n.get_children():
		textos_imagen(h, acc)
	return acc


func run() -> void:
	await arrancar()
	var p = main.pinturas
	ok(p != null and p.listo, "el sistema de pinturas está listo (%d obras)" % (p.creditos.size() if p != null else 0))
	t_claves_reales()
	await t_cadena()
	await t_hud()
	t_creditos()
	print("[T] ═══ RESULTADO runner98: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ─────────────────────────────────────────────────────────────
func t_claves_reales() -> void:
	print("[T] ── Cada pintura de lugar instalada corresponde a una provincia o estado real")
	var p = main.pinturas
	var prov_claves := {}
	var est_claves := {}
	for pr in m.provincias:
		prov_claves["lugar_%s__%s" % [Pint.clave(String(pr.pais_original)), Pint.clave(String(pr.nombre))]] = true
		if String(pr.estado) != "":
			est_claves["estado_%s__%s" % [Pint.clave(String(pr.pais_original)), Pint.clave(String(pr.estado))]] = true
	var lugares := 0
	var estados := 0
	var huerfanas := []
	for id in p.creditos:
		var nombre := String(id).get_slice("/", 1)
		if not String(id).begins_with("2026/"):
			continue
		if nombre.begins_with("lugar_"):
			lugares += 1
			if not prov_claves.has(nombre):
				huerfanas.append(id)
		elif nombre.begins_with("estado_"):
			estados += 1
			if not est_claves.has(nombre):
				huerfanas.append(id)
	ok(lugares >= 40, "hay pinturas de provincias concretas (%d)" % lugares)
	ok(estados >= 8, "hay pinturas de estados de EE. UU. (%d)" % estados)
	ok(huerfanas.is_empty(), "ninguna clave de lugar o estado queda huérfana (sin provincia: %s)" % str(huerfanas.slice(0, 5)))
	var repetidas := {}
	var dup := 0
	for id in p.creditos:
		var nombre := String(id).get_slice("/", 1)
		if nombre.begins_with("lugar_") or nombre.begins_with("estado_"):
			var url := String(p.creditos[id].get("url", ""))
			if repetidas.has(url) and url != "":
				dup += 1
			repetidas[url] = true
	ok(dup <= 2, "casi ninguna obra se repite entre lugares (repetidas: %d)" % dup)
	var contar: Dictionary = p.contar()
	ok(int(contar.get("lugares", 0)) == lugares + estados, "contar() suma los lugares (%d)" % int(contar.get("lugares", 0)))


func t_cadena() -> void:
	print("[T] ── Cadena provincia → estado → país → región → continente → mundo")
	var p = main.pinturas
	var guardadas: Dictionary = p.creditos
	var prop: Dictionary = guardadas.duplicate()
	# quitamos cualquier pintura de lugar real para probar con las nuestras
	for id in prop.keys():
		var nombre := String(id).get_slice("/", 1)
		if nombre.begins_with("lugar_") or nombre.begins_with("estado_"):
			prop.erase(id)
	prop["2026/lugar_espana__toledo"] = ficha_falsa("Vista de Toledo (prueba)")
	prop["2026/estado_estados_unidos__california"] = ficha_falsa("Yosemite (prueba)")
	p.creditos = prop
	var toledo := provincia_de("España", "Toledo")
	var cuenca := provincia_de("España", "Cuenca")
	ok(toledo >= 0 and cuenca >= 0, "Toledo y Cuenca existen (%d, %d)" % [toledo, cuenca])
	var f: Dictionary = p.de_provincia(toledo)
	ok(String(f.get("nivel", "")) == "lugar" and String(f.get("id", "")) == "2026/lugar_espana__toledo", "Toledo: su propia pintura (%s)" % String(f.get("id", "")))
	ok(String(f.get("ruta", "")) == "res://pinturas/2026/lugar_espana__toledo.jpg" and String(f.get("texto", "")).contains("Pintor de prueba"), "ruta y leyenda de la ficha")
	var g: Dictionary = p.de_provincia(cuenca)
	ok(String(g.get("nivel", "")) == "pais" and String(g.get("id", "")) == "2026/espana", "Cuenca no tiene propia: la de España (%s)" % String(g.get("id", "")))
	# conquistada: la pintura es del lugar, no del dueño
	var pr_t = m.provincias[toledo]
	var dueno: String = pr_t.pais
	pr_t.pais = "Francia"
	var h: Dictionary = p.de_provincia(toledo)
	ok(String(h.get("id", "")) == "2026/lugar_espana__toledo", "Toledo en manos de Francia sigue con su pintura")
	pr_t.pais = dueno
	# EE. UU.: estado
	var condado := -1
	var otro := -1
	for pr in m.provincias:
		if pr.pais_original == "Estados Unidos" and pr.estado == "California" and condado < 0:
			condado = pr.idx
		if pr.pais_original == "Estados Unidos" and pr.estado == "Texas" and otro < 0:
			otro = pr.idx
	var c1: Dictionary = p.de_provincia(condado)
	ok(String(c1.get("nivel", "")) == "estado" and String(c1.get("id", "")) == "2026/estado_estados_unidos__california", "un condado de California: la pintura de su estado (%s)" % String(c1.get("id", "")))
	var c2: Dictionary = p.de_provincia(otro)
	ok(String(c2.get("nivel", "")) == "pais", "un condado de Texas (sin pintura de estado): la del país (%s)" % String(c2.get("id", "")))
	ok(String(p.de_estado("Estados Unidos", "California").get("nivel", "")) == "estado", "de_estado(California): la del estado")
	ok(String(p.de_estado("Estados Unidos", "Texas").get("nivel", "")) == "pais", "de_estado(Texas): la del país")
	# región según dónde cae la provincia (si el país no tiene pintura propia)
	var rusia_prop: Dictionary = prop.duplicate()
	rusia_prop.erase("2026/rusia")
	p.creditos = rusia_prop
	var murmansk := provincia_de("Rusia", "Múrmansk")
	var kalin := provincia_de("Rusia", "Kaliningrado")
	if murmansk >= 0 and kalin >= 0:
		var r1: String = p._region_de_provincia(m.provincias[murmansk])
		var r2: String = p._region_de_provincia(m.provincias[kalin])
		ok(r1 == "region_europa_norte", "Múrmansk cae en «Europa del norte» (%s)" % r1)
		ok(r2 == "region_europa_este", "Kaliningrado cae en «Europa del este» (%s)" % r2)
		var d1: Dictionary = p.de_provincia(murmansk)
		var d2: Dictionary = p.de_provincia(kalin)
		ok(String(d1.get("nivel", "")) == "region" and String(d1["id"]) == "general/region_europa_norte", "Rusia sin pintura propia: Múrmansk usa la de su región (%s)" % String(d1.get("id", "")))
		ok(String(d2.get("id", "")) == "general/region_europa_este", "…y Kaliningrado la suya (%s)" % String(d2.get("id", "")))
	else:
		ok(false, "Múrmansk y Kaliningrado existen")
	# índices que no existen
	p.creditos = prop
	ok(p.de_provincia(-1).is_empty() and p.de_provincia(99999999).is_empty(), "un índice que no existe da vacío, sin error")
	p.creditos = guardadas
	ok(String(p.de_provincia(cuenca).get("id", "")) == "2026/espana", "con las fichas reales restauradas todo sigue funcionando")


func t_hud() -> void:
	print("[T] ── El panel recibe la pintura del lugar")
	var p = main.pinturas
	var hud = main.hud
	# buscamos una provincia con pintura de lugar REAL instalada
	var real := -1
	var real_id := ""
	for pr in m.provincias:
		var id := "2026/lugar_%s__%s" % [Pint.clave(String(pr.pais_original)), Pint.clave(String(pr.nombre))]
		if p.creditos.has(id) and not m.es_inerte(pr.pais):
			real = pr.idx
			real_id = id
			break
	ok(real >= 0, "hay una provincia con pintura propia instalada (%s)" % real_id)
	if real < 0:
		return
	var pr = m.provincias[real]
	main._seleccion_provincia(real, m.continente_de_provincia(real), Vector2(1200.0, 300.0))
	await fotogramas(3)
	var f: Dictionary = hud.datos.get("pintura", {})
	ok(String(f.get("id", "")) == real_id and String(f.get("nivel", "")) == "lugar", "al elegir %s el HUD recibe su pintura (%s)" % [pr.nombre, String(f.get("id", ""))])
	var hay := false
	for i in textos_imagen(hud.cuerpo):
		var ti: TextureRect = i
		if ti.texture != null and ti.custom_minimum_size.y == hud.ALTO_PINTURA:
			hay = true
	ok(hay, "la pestaña General dibuja la imagen del lugar")
	var leyenda := false
	var pila := [hud.cuerpo]
	while not pila.is_empty():
		var n: Node = pila.pop_back()
		if n is Label and (n as Label).text == String(f.get("texto", "")):
			leyenda = true
		pila.append_array(n.get_children())
	ok(leyenda, "la leyenda con título y autor: %s" % String(f.get("texto", "")))
	# una ciudad de esa provincia: la misma pintura
	if (pr.ciudades as Array).size() > 0:
		main._seleccion_ciudad(int(pr.ciudades[0]), Vector2(1200.0, 300.0))
		await fotogramas(3)
		ok(String(hud.datos.get("pintura", {}).get("id", "")) == real_id, "una ciudad de la provincia muestra la pintura de la provincia")
	else:
		ok(true, "(la provincia no tiene ciudades)")
	# un estado de EE. UU. con pintura propia
	var est_id := ""
	var est_nombre := ""
	for id in p.creditos:
		var nombre := String(id).get_slice("/", 1)
		if String(id).begins_with("2026/") and nombre.begins_with("estado_estados_unidos__"):
			est_id = String(id)
			est_nombre = nombre
			break
	if est_id != "":
		var nombre_estado := ""
		for k in m.estados:
			if Pint.clave(String(k).get_slice("|", 1)) == est_nombre.trim_prefix("estado_estados_unidos__"):
				nombre_estado = String(k).get_slice("|", 1)
		ok(nombre_estado != "", "el estado «%s» existe en los datos" % est_nombre)
		if nombre_estado != "":
			main._seleccion_estado("Estados Unidos", nombre_estado, Vector2(1200.0, 300.0))
			await fotogramas(3)
			ok(String(hud.datos.get("pintura", {}).get("id", "")) == est_id, "al elegir el estado %s: su pintura (%s)" % [nombre_estado, String(hud.datos.get("pintura", {}).get("id", ""))])
			var condado := -1
			for q in m.provincias:
				if q.pais_original == "Estados Unidos" and q.estado == nombre_estado:
					condado = q.idx
					break
			main._seleccion_provincia(condado, m.continente_de_provincia(condado), Vector2(1200.0, 300.0))
			await fotogramas(3)
			ok(String(hud.datos.get("pintura", {}).get("id", "")) == est_id, "un condado de ese estado lleva la pintura del estado")
	else:
		ok(false, "hay una pintura de estado instalada")
	# la provincia vecina sin pintura propia vuelve a la del país
	var sin := -1
	for q in m.provincias:
		if q.pais == pr.pais and q.idx != real and not p.creditos.has("2026/lugar_%s__%s" % [Pint.clave(String(q.pais_original)), Pint.clave(String(q.nombre))]) and String(q.estado) == "":
			sin = q.idx
			break
	if sin >= 0:
		main._seleccion_provincia(sin, m.continente_de_provincia(sin), Vector2(1200.0, 300.0))
		await fotogramas(3)
		var nivel := String(hud.datos.get("pintura", {}).get("nivel", ""))
		ok(nivel in ["pais", "region", "continente", "mundo"], "una provincia sin pintura propia usa la del país o su región (nivel %s)" % nivel)
	# sin pinturas instaladas no hay error
	var guardadas: Dictionary = p.creditos
	p.creditos = {}
	p.listo = false
	main._seleccion_provincia(real, m.continente_de_provincia(real), Vector2(1200.0, 300.0))
	await fotogramas(3)
	ok(not hud.datos.has("pintura"), "sin pinturas instaladas el panel funciona igual")
	p.creditos = guardadas
	p.listo = true


func t_creditos() -> void:
	print("[T] ── Créditos")
	var p = main.pinturas
	var t: String = p.texto_creditos()
	ok(t.contains("provincias o estados concretos"), "los créditos cuentan las pinturas de lugares: %s" % t.substr(0, 110))
	var pesos_ok := true
	var peor := 0
	for id in p.creditos:
		var nombre := String(id).get_slice("/", 1)
		if nombre.begins_with("lugar_") or nombre.begins_with("estado_"):
			var tam := FileAccess.get_file_as_bytes("res://pinturas/%s.jpg" % id).size()
			peor = maxi(peor, tam)
			if tam > 400000 or tam < 8000:
				pesos_ok = false
	ok(pesos_ok, "cada .jpg de lugar pesa entre 8 KB y 400 KB (el mayor: %d KB)" % (peor / 1024))
	var libres := true
	for id in p.creditos:
		var lic := String(p.creditos[id].get("licencia", "")).to_lower()
		if not (lic.contains("public domain") or lic.contains("cc0") or lic.contains("no restrictions") or lic.contains("pdm")):
			libres = false
	ok(libres, "todas las licencias son dominio público / CC0")
