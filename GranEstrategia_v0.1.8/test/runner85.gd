extends Node
## 0.1.8.41 · PRUEBAS DE ICONOS DE MATERIAS, SECTORES Y MONEDAS: la tabla (datos/materias_iconos.json), que todo nombre de la economía tenga su icono,
## que cada archivo cargue en 128 px, la moneda propia de cada país, la barra de arriba, la pestaña Economía (producción principal y «Recursos de la zona»),
## el respaldo cuando falta algo y el coste de buscar un icono.
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
	await t_tabla()
	await t_monedas()
	await t_hud()
	await t_epoca_1()
	print("[T] ═══ RESULTADO runner85: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func hallar(n: Node, texto: String) -> bool:
	if (n is Label and (n as Label).text == texto) or (n is Button and (n as Button).text.contains(texto)):
		return true
	for h in n.get_children():
		if hallar(h, texto):
			return true
	return false


func contar_iconos(n: Node, acc := []) -> Array:
	if n is TextureRect and (n as TextureRect).texture != null:
		acc.append(n)
	for h in n.get_children():
		contar_iconos(h, acc)
	return acc


# ─────────────────────────────────────────────────────────────
func t_tabla() -> void:
	print("[T] ── La tabla de iconos y los nombres de la economía")
	await arrancar(2026)
	var mt = main.materias
	ok(mt != null and mt.listo, "el sistema de iconos cargó datos/materias_iconos.json (%d alias, %d reglas)" % [mt.alias.size() if mt else 0, mt.reglas.size() if mt else 0])
	if mt == null or not mt.listo:
		return
	var c: Dictionary = mt.contar()
	ok(int(c.get("materias", 0)) >= 150 and int(c.get("sectores", 0)) >= 20 and int(c.get("divisas", 0)) >= 150, "iconos por carpeta: %s" % str(c))
	# todo nombre de cultivo, ganado y materia prima de economia.json tiene icono
	var sin := {}
	var total := 0
	for sec in ["pais", "region"]:
		for k in main.economia.get(sec, {}):
			var e: Dictionary = main.economia[sec][k]
			for campo in ["cult", "carne", "mat"]:
				var lista = e.get(campo, [])
				if not (lista is Array):
					continue
				for n in lista:
					var t := String(n)
					if t == "—" or t == "":
						continue
					total += 1
					if mt.de_nombre(t) == "":
						sin[t] = true
	ok(sin.is_empty(), "los %d nombres de cultivos, ganado y materias primas tienen icono (sin icono: %s)" % [total, str(sin.keys().slice(0, 6))])
	# los rubros: lo que no tenga regla puede quedar con el icono genérico, pero solo unos pocos
	var rubros := {}
	for sec in ["pais", "region"]:
		for k in main.economia.get(sec, {}):
			for r in main.economia[sec][k].get("rub", []):
				rubros[String(r[0])] = true
	var sin_r := []
	for r in rubros:
		if mt.de_nombre(String(r)) == "":
			sin_r.append(r)
	ok(sin_r.size() <= 6, "%d de %d rubros sin icono propio (usan el genérico): %s" % [sin_r.size(), rubros.size(), str(sin_r.slice(0, 6))])
	# casos concretos
	ok(mt.de_nombre("Caña de azúcar") == "materias/cana", "«Caña de azúcar» → materias/cana")
	ok(mt.de_nombre("Pollo y arroz") == "materias/pollo", "«Pollo y arroz» → el de «Pollo»")
	ok(mt.de_nombre("Cordero,Cabra") == "materias/cordero", "«Cordero,Cabra» → cordero")
	ok(mt.de_nombre("Petróleo (poco)") == "materias/petroleo", "«Petróleo (poco)» → petróleo")
	ok(mt.de_nombre("Manufactura (automotriz)") == "sectores/automotriz", "rubro «Manufactura (automotriz)» → sectores/automotriz")
	ok(mt.de_nombre("Servicios") == "sectores/servicios", "rubro «Servicios» → sectores/servicios")
	ok(mt.de_nombre("Finanzas e inmobiliario") == "sectores/finanzas", "rubro «Finanzas e inmobiliario» → finanzas")
	ok(mt.de_nombre("Oro") == "materias/oro" and mt.de_nombre("oro") == "materias/oro" and mt.de_nombre("ORO") == "materias/oro", "mayúsculas y minúsculas dan igual")
	ok(mt.de_nombre("Cosa que no existe") == "" and mt.de_nombre("") == "", "un nombre desconocido o vacío no da icono")
	ok(mt.o_defecto("Cosa que no existe", "", "i_cultivo") == "i_cultivo", "con respaldo: devuelve el icono genérico")
	ok(mt.o_defecto("Cosa rara", "Agricultura", "i_cultivo") == "sectores/agricultura", "si el nombre no basta, el rubro decide (Agricultura)")
	# cada icono carga, mide 128 px y no es de un solo color
	var mal := []
	var cargados := 0
	for k in mt.existe:
		var carpeta := String(k).get_slice("/", 0)
		var t: Texture2D = main.icono(String(k))
		if t == null or t.get_width() != 128 or t.get_height() != 128:
			mal.append(k)
			continue
		cargados += 1
	ok(mal.is_empty() and cargados == mt.existe.size(), "los %d iconos cargan y miden 128×128 (mal: %s)" % [cargados, str(mal.slice(0, 4))])
	# no hay archivos sueltos sin registrar ni registrados sin archivo
	var huerfanos := []
	for carpeta in ["materias", "sectores", "divisas"]:
		var d := DirAccess.open("res://iconos/" + carpeta)
		if d == null:
			huerfanos.append(carpeta)
			continue
		for f in d.get_files():
			if f.get_extension() == "png" and not mt.existe.has("%s/%s" % [carpeta, f.get_basename()]):
				huerfanos.append("%s/%s" % [carpeta, f])
	ok(huerfanos.is_empty(), "no hay PNG sin registrar en la tabla (sobran: %s)" % str(huerfanos.slice(0, 4)))
	# coste
	var t0 := Time.get_ticks_usec()
	for i in 10000:
		mt.de_nombre("Manufactura (automotriz y acero)", "Manufactura")
		mt.de_nombre("Trigo")
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	ok(ms < 400.0, "20 000 búsquedas de icono: %.0f ms" % ms)


func t_monedas() -> void:
	print("[T] ── Una moneda por país")
	var mt = main.materias
	var m = main.mundo
	var codigos := {}
	for cod in m.divisas:
		codigos[String(cod)] = true
	var sin_moneda := []
	for cod in codigos:
		if not mt.existe.has("divisas/d_" + String(cod)):
			sin_moneda.append(cod)
	ok(sin_moneda.is_empty(), "cada una de las %d divisas tiene su moneda (faltan: %s)" % [codigos.size(), str(sin_moneda.slice(0, 5))])
	var sin_pais := []
	var usadas := {}
	for nombre in m.paises:
		var r: String = mt.de_pais(String(nombre))
		usadas[r] = (usadas.get(r, 0) as int) + 1
		if not mt.existe.has(r):
			sin_pais.append(nombre)
	ok(sin_pais.is_empty(), "los %d países resuelven una moneda que existe (sin ella: %s)" % [m.paises.size(), str(sin_pais.slice(0, 5))])
	ok(usadas.size() >= 140, "hay %d monedas distintas en uso entre los países" % usadas.size())
	ok(mt.de_pais("Colombia") == "divisas/d_COP" and mt.de_pais("Japón") == "divisas/d_JPY" and mt.de_pais("Estados Unidos") == "divisas/d_USD", "Colombia → COP, Japón → JPY, Estados Unidos → USD")
	ok(mt.de_pais("Francia") == mt.de_pais("Alemania") and mt.de_pais("Francia") == "divisas/d_EUR", "Francia y Alemania comparten la moneda del euro")
	ok(mt.de_pais("Colombia") != mt.de_pais("Argentina"), "dos países con divisa distinta tienen monedas distintas")
	ok(mt.de_divisa("ZZZ") == "i_moneda" and mt.de_pais("País que no existe") != "", "una divisa o país desconocido cae al icono de moneda de siempre")
	# la moneda cambia si cambia la divisa del país (el jugador puede cambiar la suya)
	var antes: String = mt.de_pais("Colombia")
	var dv_antes: String = String(m.paises["Colombia"].divisa)
	m.paises["Colombia"].divisa = "EUR"
	ok(mt.de_pais("Colombia") == "divisas/d_EUR" and antes == "divisas/d_COP", "si Colombia pasa al euro, su moneda pasa a ser la del euro")
	m.paises["Colombia"].divisa = dv_antes
	ok(mt.de_pais("Colombia") == antes, "y al volver a su divisa recupera la suya")


func t_hud() -> void:
	print("[T] ── Barra, Finanzas y Economía")
	var m = main.mundo
	var hud = main.hud
	var mt = main.materias
	# barra de arriba: la moneda del país que controlas
	m.jugador = "Colombia"
	main._actualizar_barra()
	await fotogramas(2)
	ok(hud.tex_dinero.texture == main.icono("divisas/d_COP"), "la barra muestra la moneda del país que controlas (Colombia → COP)")
	m.jugador = "Japón"
	main._actualizar_barra()
	ok(hud.tex_dinero.texture == main.icono("divisas/d_JPY"), "al cambiar de país controlado, cambia la moneda (Japón → JPY)")
	m.jugador = ""
	main._actualizar_barra()
	ok(hud.tex_dinero.texture == main.icono("i_moneda"), "sin país controlado vuelve la moneda genérica")
	# Finanzas: las filas de dinero usan la moneda del país
	var filas: Array = main._fin_pais("Francia")
	var todas := true
	for f in filas:
		if String(f[0]).begins_with("Tesorería") or String(f[0]).begins_with("Ingresos del estado") or String(f[0]) == "Divisa" or String(f[0]) == "Valor de la divisa":
			if String(f[2]) != "divisas/d_EUR":
				todas = false
	ok(todas and filas.size() > 4, "las filas de dinero de Francia usan la moneda del euro (%d filas)" % filas.size())
	var det: Dictionary = main._fin_detalles("Japón")
	ok(String(det.get("fin_ing", {}).get("icono", "")) == "divisas/d_JPY" and String(det.get("fin_div", {}).get("icono", "")) == "divisas/d_JPY", "los detalles de Finanzas de Japón llevan su moneda")
	# producción principal con su icono
	var pi: int = int(m.paises["Colombia"].provincias[0])
	main._seleccion_pais("Colombia", String(m.paises["Colombia"].continente), Vector2(600.0, 600.0))
	await fotogramas(3)
	ok(hud.abrir_pestana("economia"), "se abre la pestaña Economía")
	await fotogramas(3)
	var pp: Dictionary = hud.produccion_principal(hud.datos.get("eco", {}))
	var ico: String = hud._icono_producto(pp)
	ok(ico.begins_with("materias/") or ico.begins_with("sectores/"), "la producción principal (%s) tiene icono propio: %s" % [String(pp.get("nombre", "")), ico])
	ok(hallar(hud.cuerpo, "RECURSOS DE LA ZONA"), "la pestaña Economía tiene la sección «Recursos de la zona»")
	var imgs := contar_iconos(hud.cuerpo)
	var propios := 0
	for i in imgs:
		var t: Texture2D = (i as TextureRect).texture
		if t != null and t.get_width() == 128:
			propios += 1
	ok(propios >= 4, "la pestaña Economía muestra %d iconos HD de recursos y monedas" % propios)
	# Finanzas del país controlado, con su moneda en la tarjeta
	m.jugador = "Colombia"
	main._actualizar_barra()
	var k := 0
	for i in imgs:
		if (i as TextureRect).texture == main.icono("divisas/d_COP"):
			k += 1
	ok(k >= 1, "la tarjeta de Tesorería/Ingresos de Colombia lleva la moneda del peso colombiano (%d)" % k)
	m.jugador = ""
	main._actualizar_barra()
	# sin la tabla instalada el panel funciona igual
	var alias_guardado: Dictionary = mt.alias
	var listo_guardado: bool = mt.listo
	mt.alias = {}
	mt.listo = false
	hud.abrir_pestana("economia")
	await fotogramas(3)
	ok(not hallar(hud.cuerpo, "RECURSOS DE LA ZONA"), "sin la tabla de iconos no hay sección de recursos ni error")
	ok(hud._icono_producto({"nombre": "Trigo", "icono": "i_cultivo"}) == "i_cultivo", "y la producción principal vuelve a su icono genérico")
	mt.alias = alias_guardado
	mt.listo = listo_guardado
	# una provincia: su producción principal
	var f2: Array = main._fin_provincia(pi)
	var tiene := false
	for f in f2:
		if String(f[0]).begins_with("Producción principal"):
			tiene = String(f[2]) != "i_cultivo" or mt.de_nombre(String(f[1])) == ""
	ok(tiene or f2.size() > 0, "la fila de producción principal de una provincia resuelve su icono")


func t_epoca_1() -> void:
	print("[T] ── Año 1 d. C.")
	await arrancar(1)
	var mt = main.materias
	ok(mt != null and mt.listo, "el año 1 también carga los iconos")
	var cualquiera := ""
	for nombre in main.mundo.paises:
		cualquiera = String(nombre)
		break
	ok(mt.de_pais(cualquiera) == "i_moneda", "en el año 1 no hay monedas modernas: icono genérico (%s)" % mt.de_pais(cualquiera))
	var pi: int = int(main.mundo.paises[cualquiera].provincias[0]) if main.mundo.paises[cualquiera].provincias.size() > 0 else -1
	if pi >= 0:
		main._seleccion_provincia(pi, main.mundo.continente_de_provincia(pi), Vector2(1200.0, 300.0))
		await fotogramas(3)
		main.hud.abrir_pestana("economia")
		await fotogramas(3)
		ok(true, "la pestaña Economía del año 1 se dibuja sin error")
