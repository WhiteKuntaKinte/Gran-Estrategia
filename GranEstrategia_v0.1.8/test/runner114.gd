extends Node
## 0.1.8.52 · PINTURAS POR ÉPOCA Y LUGAR + MONEDAS HISTÓRICAS: ninguna obra posterior al escenario, cada lugar con su región, cada divisa antigua con su icono.
var main
var fallos := 0
var n_ok := 0
const ANIO := {1: 1, 1096: 1096, 1500: 1500}


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


func arrancar(anio: int, semilla := 777) -> void:
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
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)


# ─────────────────────────────────────────────────────────────
func t_regla() -> void:
	print("[T] ── Regiones: el Magreb y el Nilo van separados")
	var P = load("res://scripts/pinturas.gd")
	ok(P.region_en("África", -7.0, 32.0) == "region_maghreb", "Marruecos cae en el Magreb")
	ok(P.region_en("África", 17.0, 27.0) == "region_maghreb", "Libia cae en el Magreb")
	ok(P.region_en("África", 30.0, 27.0) == "region_nilo", "Egipto cae en el Nilo")
	ok(P.region_en("África", 20.0, 5.0) == "region_africa_subsahariana", "el Congo cae en el África subsahariana")


func t_archivos() -> void:
	print("[T] ── Créditos y archivos de las pinturas")
	var cred = JSON.parse_string(FileAccess.get_file_as_string("res://pinturas/creditos.json"))
	ok(cred is Dictionary and (cred as Dictionary).size() > 300, "creditos.json trae las pinturas (%d)" % (cred as Dictionary).size())
	var sin_archivo: Array = []
	var anacronicas: Array = []
	var sin_anio: Array = []
	var licencias: Dictionary = {}
	for id in cred:
		if not FileAccess.file_exists("res://pinturas/%s.jpg" % id):
			sin_archivo.append(id)
		var c: Dictionary = cred[id]
		licencias[String(c["licencia"])] = true
		var carpeta := String(id).get_slice("/", 0)
		if carpeta in ["1dc", "1096", "1500"]:
			if not c.has("anio") or c["anio"] == null:
				sin_anio.append(id)
			elif int(c["anio"]) > int(ANIO[int(carpeta.replace("dc", "")) if carpeta != "1dc" else 1]):
				anacronicas.append("%s (%d)" % [id, int(c["anio"])])
	ok(sin_archivo.is_empty(), "cada crédito tiene su .jpg (faltan: %s)" % str(sin_archivo.slice(0, 4)))
	ok(anacronicas.is_empty(), "ninguna pintura de época es posterior a su escenario (%s)" % str(anacronicas.slice(0, 4)))
	ok(sin_anio.is_empty(), "toda pintura de época trae su año (%s)" % str(sin_anio.slice(0, 4)))
	var raras: Array = []
	for l in licencias:
		if not (String(l).findn("public domain") >= 0 or String(l).findn("cc0") >= 0 or String(l).findn("pd") >= 0):
			raras.append(l)
	ok(raras.is_empty(), "todas son de dominio público o CC0 (otras: %s)" % str(raras))
	var huerfanos: Array = []
	for carpeta in DirAccess.get_directories_at("res://pinturas"):
		for f in DirAccess.get_files_at("res://pinturas/" + carpeta):
			if f.get_extension() == "jpg" and not (cred as Dictionary).has(carpeta + "/" + f.get_basename()):
				huerfanos.append(carpeta + "/" + f)
	ok(huerfanos.is_empty(), "no sobra ningún .jpg sin crédito (sobran: %s)" % str(huerfanos.slice(0, 4)))


func t_epoca(anio: int) -> void:
	print("[T] ── Pinturas del año %d" % anio)
	await arrancar(anio)
	var p = main.pinturas
	ok(p != null and p.listo, "%d: el sistema de pinturas está listo (carpeta %s)" % [anio, p.carpeta_epoca()])
	var sin: Array = []
	var tarde: Array = []
	var otra_carpeta: Array = []
	var n := 0
	for nombre in main.mundo.paises:
		var f: Dictionary = p.de_pais(String(nombre))
		n += 1
		if f.is_empty():
			sin.append(String(nombre))
			continue
		var id := String(f["id"])
		if not String(id).begins_with(p.carpeta_epoca() + "/") and not String(id).begins_with("general/"):
			otra_carpeta.append(id)
		if not p.valida(id):
			tarde.append(id)
		elif int(p.creditos[id].get("anio", 99999)) > int(ANIO[anio]):
			tarde.append(id)
	ok(sin.is_empty(), "%d: los %d países tienen pintura (sin ella: %s)" % [anio, n, str(sin.slice(0, 3))])
	ok(tarde.is_empty(), "%d: ninguna es posterior a esa fecha (%s)" % [anio, str(tarde.slice(0, 3))])
	ok(otra_carpeta.is_empty(), "%d: ninguna sale de la carpeta de otra época (%s)" % [anio, str(otra_carpeta.slice(0, 3))])
	# el lugar importa: nada de Giza para el Magreb
	var maghreb := ""
	var nilo := ""
	for nombre in main.mundo.paises:
		var r: String = p.region_de(String(nombre))
		if r == "region_maghreb" and maghreb == "":
			maghreb = String(nombre)
		if r == "region_nilo" and nilo == "":
			nilo = String(nombre)
	if maghreb != "":
		var fm: Dictionary = p.de_pais(maghreb)
		ok(String(fm["id"]) != p.carpeta_epoca() + "/region_nilo", "%d: «%s» (Magreb) no lleva la pintura del Nilo (%s)" % [anio, maghreb, String(fm["titulo"])])
	if nilo != "":
		var fn: Dictionary = p.de_pais(nilo)
		ok(not String(fn["id"]).contains("maghreb"), "%d: «%s» (Nilo) no lleva la del Magreb (%s)" % [anio, nilo, String(fn["titulo"])])
	# monedas de la época
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://datos/epocas/%s/divisas.json" % p.carpeta_epoca()))
	var sin_ic: Array = []
	for cod in (d["divisas"] as Dictionary):
		if main.materias.de_divisa(String(cod)) == "i_moneda":
			sin_ic.append(cod)
	ok(sin_ic.is_empty(), "%d: cada divisa de la época tiene su icono propio (genéricas: %s)" % [anio, str(sin_ic)])


func t_2026() -> void:
	print("[T] ── Pinturas de 2026")
	await arrancar(2026)
	var p = main.pinturas
	for pais in ["Marruecos", "Libia", "Argelia", "Túnez"]:
		if main.mundo.paises.has(pais):
			var f: Dictionary = p.de_pais(pais)
			ok(p.region_de(pais) == "region_maghreb", "%s: su región es el Magreb (%s)" % [pais, p.region_de(pais)])
			ok(String(f["id"]) != "general/region_nilo" and String(f["id"]) != "general/continente_africa", "%s: no lleva una pintura de Egipto (%s)" % [pais, String(f["titulo"])])
	for pais in ["Egipto"]:
		if main.mundo.paises.has(pais):
			ok(p.region_de(pais) == "region_nilo", "Egipto: su región es el Nilo")


func run() -> void:
	t_regla()
	t_archivos()
	for a in [1, 1096, 1500]:
		await t_epoca(a)
	await t_2026()
	print("[T] ═══ RESULTADO runner114: %d OK, %d FALLOS" % [n_ok, fallos])
	print("FALLOS: %d" % fallos)
	get_tree().quit()
