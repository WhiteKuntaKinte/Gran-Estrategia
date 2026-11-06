extends Control
## DESCARGA DE DATOS HISTÓRICOS (0.1.7.9.9C) — herramienta que corre DENTRO de Godot, sin instalar nada más.
##
## Cómo usarla: abre el proyecto en Godot, en el panel de archivos abre herramientas/descargar_historia/descargar_historia.tscn
## y pulsa F6 (ejecutar escena actual). Empieza por «PRUEBA»: baja unos 50 estados y unos pocos países para ver que todo
## funciona (tarda unos minutos). Si sale bien, pulsa «DESCARGA COMPLETA» (puede tardar horas por las banderas; se puede
## detener y seguir otro día: lo ya bajado queda guardado).
##
## Qué baja (de Wikidata, datos libres CC0, y de Wikimedia Commons para las imágenes):
##   1. Estados históricos (reinos, imperios, repúblicas que ya no existen) con fechas, capital, predecesores y sucesores.
##   2. Todos sus nombres con fechas (oficial, común, nativo) y también los de los países actuales y los continentes.
##   3. Sus banderas y escudos con fechas, y la LICENCIA de cada imagen (para saber cuáles se pueden usar comercialmente).
##   4. Sus jefes de Estado y de gobierno con fechas.
## y lo convierte a los archivos del juego en datos/historico/ y banderas_hist/. Antes de escribir guarda una copia de lo
## anterior. Lo bajado queda en caché (user://historia_cache/): «SOLO CONVERTIR» vuelve a armar los archivos sin descargar.
##
## Configuración: herramientas/descargar_historia/config_descarga.json (todo es opcional; los valores por defecto están abajo).
## Para pruebas automáticas: godot --headless --path <proyecto> res://herramientas/descargar_historia/descargar_historia.tscn
##     -- --config=/ruta/config.json --auto=prueba|completa|convertir

const BDScript := preload("res://scripts/base_datos.gd")
const CARPETA := "res://herramientas/descargar_historia/"
const ID_ENT_INICIO := 1000000
const ID_PER_INICIO := 2000000

const Q_PAISES := """SELECT ?c ?a3 WHERE { VALUES ?a3 { {{LISTA}} } ?c wdt:P298 ?a3 . }"""

## Paso 1 (liviana): qué estados hay de cada clase y cuántas páginas de Wikipedia tiene cada uno (su «importancia»).
const Q_IDS := """SELECT ?e ?sl WHERE {
  ?e wdt:P31 wd:{{CLASE}} .
  {{FIN}}
  ?e wikibase:sitelinks ?sl . FILTER(?sl >= {{MIN}})
}"""

## Paso 2: nombre y fechas de esos estados, por lotes (el mismo tipo de consulta que ya funcionó con nombres y banderas).
const Q_DETALLE := """SELECT ?e ?l_es ?l_en ?ini ?fin WHERE {
  VALUES ?e { {{LISTA}} }
  OPTIONAL { ?e wdt:P571 ?ini1 . } OPTIONAL { ?e wdt:P580 ?ini2 . }
  OPTIONAL { ?e wdt:P576 ?fin1 . } OPTIONAL { ?e wdt:P582 ?fin2 . }
  BIND(COALESCE(?ini1, ?ini2) AS ?ini)
  BIND(COALESCE(?fin1, ?fin2) AS ?fin)
  OPTIONAL { ?e rdfs:label ?l_es . FILTER(LANG(?l_es) = "es") }
  OPTIONAL { ?e rdfs:label ?l_en . FILTER(LANG(?l_en) = "en") }
}"""

const Q_RELACIONES := """SELECT ?e ?rel ?otro ?txt WHERE {
  VALUES ?e { {{LISTA}} }
  { ?e wdt:P1365 ?otro . BIND("pred" AS ?rel) }
  UNION { ?e wdt:P1366 ?otro . BIND("suc" AS ?rel) }
  UNION { ?e wdt:P36 ?c . ?c rdfs:label ?txt . FILTER(LANG(?txt) = "es") BIND("cap_es" AS ?rel) }
  UNION { ?e wdt:P36 ?c . ?c rdfs:label ?txt . FILTER(LANG(?txt) = "en") BIND("cap_en" AS ?rel) }
}"""

const Q_NOMBRES := """SELECT ?e ?nombre (LANG(?nombre) AS ?lang) ?clase ?ini ?fin WHERE {
  VALUES ?e { {{LISTA}} }
  { ?e p:P1448 ?st . ?st ps:P1448 ?nombre . BIND("oficial" AS ?clase) OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } }
  UNION { ?e p:P2561 ?st . ?st ps:P2561 ?nombre . BIND("comun" AS ?clase) OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } }
  UNION { ?e p:P1813 ?st . ?st ps:P1813 ?nombre . BIND("comun" AS ?clase) OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } }
  UNION { ?e p:P1705 ?st . ?st ps:P1705 ?nombre . BIND("nativo" AS ?clase) OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } }
  UNION { ?e rdfs:label ?nombre . FILTER(LANG(?nombre) IN ("es", "en")) BIND("comun" AS ?clase) }
}"""

const Q_BANDERAS := """SELECT ?e ?img ?clase ?ini ?fin WHERE {
  VALUES ?e { {{LISTA}} }
  { ?e p:P41 ?st . ?st ps:P41 ?img . BIND("bandera" AS ?clase) OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } }
  UNION { ?e p:P94 ?st . ?st ps:P94 ?img . BIND("escudo" AS ?clase) OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } }
}"""

const Q_GOBERNANTES := """SELECT ?e ?p ?cargo ?ini ?fin ?pl_es ?pl_en ?nac ?mue WHERE {
  VALUES ?e { {{LISTA}} }
  { ?e p:P35 ?st . ?st ps:P35 ?p . BIND("jefe de Estado" AS ?cargo) OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } }
  UNION { ?e p:P6 ?st . ?st ps:P6 ?p . BIND("jefe de gobierno" AS ?cargo) OPTIONAL { ?st pq:P580 ?ini } OPTIONAL { ?st pq:P582 ?fin } }
  OPTIONAL { ?p rdfs:label ?pl_es . FILTER(LANG(?pl_es) = "es") }
  OPTIONAL { ?p rdfs:label ?pl_en . FILTER(LANG(?pl_en) = "en") }
  OPTIONAL { ?p wdt:P569 ?nac } OPTIONAL { ?p wdt:P570 ?mue }
}"""

var cfg := {}
var http: HTTPRequest
var detener := false
var ocupado := false
var salir_al_final := false
var consola: RichTextLabel
var barra: ProgressBar
var lbl_estado: Label
var botones: Array = []

# resultados en memoria de la corrida
var ents := {}               # qid -> {nombre, ini, fin, cap_es, cap_en, pred: [qid], suc: [qid]}
var paises_qid := {}         # qid -> ID del juego (países actuales y continentes)
var nombres: Array = []      # [qid, nombre, idioma, clase, ini, fin]
var banderas: Array = []     # [qid, archivo en Commons, clase, ini, fin]
var personas := {}           # qid -> {nombre, nac, mue}
var cargos: Array = []       # [qid entidad, qid persona, cargo, ini, fin]
var licencias := {}          # archivo en Commons -> licencia
var archivos_local := {}     # archivo en Commons -> nombre del PNG local ("" si falló)
var fallos_http := 0
var idiomas_omitidos := 0
var autores := {}            # archivo en Commons -> autor (texto, sin HTML)
var descartadas: Array = []  # [archivo, licencia, clase] imágenes que no se usan por su licencia
var fechas_raras := 0
var modo_prueba := false     # la corrida actual es una PRUEBA (muestra pequeña)
var sin_red := false         # «solo convertir»: usa únicamente la caché del disco
var f_registro: FileAccess = null   # copia del registro en un archivo (para poder mandarlo sin copiar y pegar)


# ─────────────────────────────────────────────────────────────
# Arranque e interfaz
# ─────────────────────────────────────────────────────────────
func _cfg_defecto() -> Dictionary:
	return {
		"endpoint_sparql": "https://query.wikidata.org/sparql",
		"base_commons": "https://commons.wikimedia.org",
		"agente": "GranEstrategia/0.1 (juego personal de estrategia hecho en Godot; herramienta de descarga historica)",
		"clases_estado": ["Q3024240", "Q417175", "Q48349", "Q3624078", "Q7275"],
		"continentes": {"Q15": "África", "Q18": "América del Sur", "Q46": "Europa", "Q48": "Asia", "Q49": "América del Norte", "Q51": "Antártida", "Q538": "Oceanía"},
		"limite_prueba": 50,
		"paises_prueba": 12,
		"max_imagenes_prueba": 60,
		"tamano_pagina": 400,
		"lote": 60,
		"pausa_sparql_ms": 1500,
		"pausa_imagen_ms": 300,
		"reintentos": 4,
		"ancho_bandera": 96,
		"descargar_banderas": true,
		"banderas_paises_actuales": true,
		"gobernantes": true,
		"quitar_semilla": true,
		"salida": "res://datos/historico/",
		"salida_banderas": "res://banderas_hist/",
		"cache": "user://historia_cache/",
		"respaldo": "user://historia_respaldo/",
		"archivo_registro": "res://herramientas/descargar_historia/ultimo_registro.txt",
		"limpiar_en_prueba": true,
		"min_sitelinks": 10,
		"min_sitelinks_prueba": 40,
		"idiomas_comun": ["es", "en", "fr", "de", "pt", "it", "nl", "ru", "zh", "ja", "ar", "tr", "la", "el", "mul"],
		"descartar_licencias": ["no_comercial", "sin_verificar"],
	}


func _ready() -> void:
	cfg = _cfg_defecto()
	var ruta_cfg := CARPETA + "config_descarga.json"
	var auto := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--config="):
			ruta_cfg = a.substr(9)
		elif a.begins_with("--auto="):
			auto = a.substr(7)
	if FileAccess.file_exists(ruta_cfg):
		var js = JSON.parse_string(FileAccess.get_file_as_string(ruta_cfg))
		if js is Dictionary:
			for k in js:
				if not String(k).begins_with("_"):
					cfg[k] = js[k]
	http = HTTPRequest.new()
	http.timeout = 90.0
	add_child(http)
	_construir_ui()
	if auto != "":
		salir_al_final = true
		_ejecutar.call_deferred(auto)


func _construir_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fondo := ColorRect.new()
	fondo.color = Color(0.07, 0.09, 0.14)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	caja.add_theme_constant_override("separation", 8)
	add_child(caja)
	var t := Label.new()
	t.text = "Descarga de datos históricos · Gran Estrategia 0.1.7.9.9C"
	t.add_theme_font_size_override("font_size", 20)
	caja.add_child(t)
	var ayuda := Label.new()
	ayuda.text = "Empieza por PRUEBA (unos 50 estados). Si sale bien, usa DESCARGA COMPLETA. Puedes detenerla y seguir otro día."
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(ayuda)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)
	for par in [["PRUEBA (50 estados)", "prueba"], ["DESCARGA COMPLETA", "completa"], ["SOLO CONVERTIR (sin descargar)", "convertir"]]:
		var b := Button.new()
		b.text = String(par[0])
		b.custom_minimum_size = Vector2(0.0, 40.0)
		var modo: String = par[1]
		b.pressed.connect(func(): _ejecutar(modo))
		fila.add_child(b)
		botones.append(b)
	var bd := Button.new()
	bd.text = "DETENER"
	bd.custom_minimum_size = Vector2(0.0, 40.0)
	bd.pressed.connect(func():
		detener = true
		_log("Deteniendo al terminar la petición en curso… (lo ya bajado queda guardado)"))
	fila.add_child(bd)
	lbl_estado = Label.new()
	lbl_estado.text = "Listo."
	caja.add_child(lbl_estado)
	barra = ProgressBar.new()
	barra.custom_minimum_size = Vector2(0.0, 22.0)
	caja.add_child(barra)
	consola = RichTextLabel.new()
	consola.scroll_following = true
	consola.selection_enabled = true
	consola.size_flags_vertical = Control.SIZE_EXPAND_FILL
	consola.custom_minimum_size = Vector2(0.0, 300.0)
	caja.add_child(consola)


func _log(t: String) -> void:
	var linea := "[%s] %s" % [Time.get_time_string_from_system(), t]
	print("[DESCARGA] ", linea)
	if consola != null:
		consola.append_text(linea + "\n")
	if f_registro != null:
		f_registro.store_line(linea)
		f_registro.flush()


func _estado(t: String, avance := -1.0, maximo := -1.0) -> void:
	if lbl_estado != null:
		lbl_estado.text = t
	if barra != null and maximo > 0.0:
		barra.max_value = maximo
		barra.value = clampf(avance, 0.0, maximo)


func _esperar(ms: int) -> void:
	await get_tree().create_timer(float(ms) / 1000.0).timeout


# ─────────────────────────────────────────────────────────────
# HTTP con reintentos
# ─────────────────────────────────────────────────────────────
## Devuelve {ok, codigo, cuerpo (PackedByteArray)}. Reintenta con espera si hay error de red, 429 o 5xx.
func _pedir(url: String, cabeceras: PackedStringArray, metodo := HTTPClient.METHOD_GET, cuerpo := "") -> Dictionary:
	var espera := 2000
	for intento in int(cfg["reintentos"]):
		if detener:
			break
		var err := http.request(url, cabeceras, metodo, cuerpo)
		if err != OK:
			_log("No se pudo iniciar la petición (error %d); reintento…" % err)
			await _esperar(espera)
			espera *= 2
			continue
		var res: Array = await http.request_completed
		var codigo := int(res[1])
		if int(res[0]) == HTTPRequest.RESULT_SUCCESS and codigo >= 200 and codigo < 300:
			return {"ok": true, "codigo": codigo, "cuerpo": res[3]}
		if detener:
			break
		if int(res[0]) == HTTPRequest.RESULT_SUCCESS and codigo >= 400 and codigo < 500 and codigo != 429 and codigo != 408:
			return {"ok": false, "codigo": codigo, "cuerpo": res[3]}
		var extra := 0
		for h in res[2]:
			var hs := String(h)
			if hs.to_lower().begins_with("retry-after:"):
				extra = int(hs.get_slice(":", 1).strip_edges()) * 1000
		fallos_http += 1
		_log("Intento %d falló (resultado %d, código %d); espero %d s…" % [intento + 1, int(res[0]), codigo, int(maxi(espera, extra) / 1000.0)])
		await _esperar(maxi(espera, extra))
		espera *= 2
	return {"ok": false, "codigo": 0, "cuerpo": PackedByteArray()}


## Ejecuta una consulta SPARQL (con caché en disco) y devuelve la lista de filas, o null si falló.
func _sparql(consulta: String) -> Variant:
	var carpeta: String = cfg["cache"]
	DirAccess.make_dir_recursive_absolute(carpeta)
	var clave := consulta.md5_text()
	var ruta_cache: String = carpeta + clave + ".json"
	if FileAccess.file_exists(ruta_cache):
		var js0 = JSON.parse_string(FileAccess.get_file_as_string(ruta_cache))
		if js0 is Dictionary and js0.has("results"):
			return js0["results"]["bindings"]
	if sin_red:
		_log("Falta en la caché una consulta (¿la descarga no llegó a terminar?). Usa PRUEBA o DESCARGA COMPLETA para completarla.")
		return null
	await _esperar(int(cfg["pausa_sparql_ms"]))
	var cab := PackedStringArray(["User-Agent: " + String(cfg["agente"]), "Accept: application/sparql-results+json",
		"Content-Type: application/x-www-form-urlencoded"])
	var r: Dictionary = await _pedir(String(cfg["endpoint_sparql"]), cab, HTTPClient.METHOD_POST, "format=json&query=" + consulta.uri_encode())
	if not bool(r["ok"]):
		_log("La consulta falló (código %d)." % int(r["codigo"]))
		return null
	var texto := (r["cuerpo"] as PackedByteArray).get_string_from_utf8()
	var js = JSON.parse_string(texto)
	if not (js is Dictionary) or not js.has("results"):
		_log("Respuesta inesperada del servicio (no es JSON de SPARQL).")
		return null
	var f := FileAccess.open(ruta_cache, FileAccess.WRITE)
	if f != null:
		f.store_string(texto)
	return js["results"]["bindings"]


# ─────────────────────────────────────────────────────────────
# Utilidades de datos
# ─────────────────────────────────────────────────────────────
static func _v(b: Dictionary, k: String) -> String:
	var x = b.get(k)
	if x is Dictionary and String(x.get("type", "")) != "bnode" and not String(x.get("value", "")).contains("/.well-known/genid/"):
		return String(x.get("value", ""))
	return ""


static func _qid(uri: String) -> String:
	if uri.contains("/entity/Q"):
		return uri.get_file()
	return ""


## Fecha de Wikidata ("1819-12-17T00:00:00Z", "-0044-03-15T00:00:00Z") -> entero de fecha del juego (0 = desconocida).
static func _fecha(s: String) -> int:
	if s == "":
		return 0
	var neg := s.begins_with("-")
	var t := s.lstrip("+-").split("T")[0]
	var p := t.split("-")
	if p.size() < 3:
		return 0
	var a := int(p[0])
	if neg:
		a = -a
	if a == 0:
		a = -1                                   # el año 0 del estándar XML equivale a 1 a. C.
	return (a + 100000) * 10000 + clampi(int(p[1]), 1, 12) * 100 + clampi(int(p[2]), 1, 31)


static func _lista_wd(qids: Array) -> String:
	var r := PackedStringArray()
	for q in qids:
		r.append("wd:" + String(q))
	return " ".join(r)


func _lotes(lista: Array) -> Array:
	var r := []
	var n := int(cfg["lote"])
	var i := 0
	while i < lista.size():
		r.append(lista.slice(i, i + n))
		i += n
	return r


func _tipo_por_nombre(n: String) -> String:
	var m := n.to_lower()
	for par in [["imperio", "imperio"], ["reino", "reino"], ["república", "republica"], ["republica", "republica"], ["califato", "califato"],
			["sultanato", "sultanato"], ["virreinato", "virreinato"], ["ducado", "ducado"], ["principado", "principado"], ["dinastía", "dinastia"]]:
		if m.contains(String(par[0])):
			return String(par[1])
	return "estado"


# ─────────────────────────────────────────────────────────────
# Orquestación
# ─────────────────────────────────────────────────────────────
func _bloquear(si: bool) -> void:
	ocupado = si
	for b in botones:
		(b as Button).disabled = si


func _ejecutar(modo: String) -> void:
	if ocupado:
		return
	_bloquear(true)
	detener = false
	fallos_http = 0
	var ruta_reg := String(cfg.get("archivo_registro", ""))
	f_registro = FileAccess.open(ruta_reg, FileAccess.WRITE) if ruta_reg != "" else null
	ents.clear()
	paises_qid.clear()
	nombres.clear()
	banderas.clear()
	personas.clear()
	cargos.clear()
	licencias.clear()
	archivos_local.clear()
	autores.clear()
	descartadas.clear()
	idiomas_omitidos = 0
	fechas_raras = 0
	var carpeta_cache: String = cfg["cache"]
	DirAccess.make_dir_recursive_absolute(carpeta_cache)
	licencias = _leer_licencias()
	autores = _leer_autores()
	var ruta_modo: String = carpeta_cache + "ultimo_modo.txt"
	var efectivo := modo
	if modo == "convertir":                      # reutiliza las consultas de la última corrida (prueba o completa)
		efectivo = FileAccess.get_file_as_string(ruta_modo).strip_edges() if FileAccess.file_exists(ruta_modo) else "completa"
	else:
		var fm := FileAccess.open(ruta_modo, FileAccess.WRITE)
		if fm != null:
			fm.store_string(modo)
	var prueba := efectivo == "prueba"
	modo_prueba = prueba
	sin_red = modo == "convertir"
	_log("=== Modo: %s%s ===" % [modo, " (con las consultas de la última corrida: %s)" % efectivo if modo == "convertir" else ""])
	var exito := true
	exito = await _descargar(prueba, modo == "convertir")
	if exito and not detener:
		exito = _convertir()
	_log("=== FIN %s ===" % ("OK" if exito and not detener else ("DETENIDO" if detener else "CON ERRORES")))
	_estado("Listo." if exito else "Terminó con errores: mira el registro.")
	if f_registro != null:
		f_registro.close()
		f_registro = null
	_bloquear(false)
	if salir_al_final:
		get_tree().quit(0 if exito else 1)


func _descargar(prueba: bool, solo_cache := false) -> bool:
	var paises: Dictionary = _paises_juego()
	if paises.is_empty():
		_log("No encuentro datos/entidades.json o datos/ids.json: ¿abriste el proyecto correcto?")
		return false
	# ── 0. países actuales y continentes → QID
	_estado("Identificando países y continentes…")
	var a3s := paises.keys()
	if prueba:
		a3s = a3s.slice(0, int(cfg["paises_prueba"]))
	for lote in _lotes(a3s):
		if detener:
			return false
		var q := Q_PAISES.replace("{{LISTA}}", " ".join(PackedStringArray(lote.map(func(x): return '"%s"' % x))))
		var filas = await _sparql(q)
		if filas == null:
			return false
		for b in filas:
			var qid := _qid(_v(b, "c"))
			var a3 := _v(b, "a3")
			if qid != "" and paises.has(a3) and not paises_qid.has(qid):
				paises_qid[qid] = int(paises[a3])
	var conts: Dictionary = _continentes_juego()
	for qid in cfg["continentes"]:
		var nombre_c: String = String(cfg["continentes"][qid])
		if conts.has(nombre_c):
			paises_qid[String(qid)] = int(conts[nombre_c])
	_log("Países y continentes reconocidos: %d" % paises_qid.size())
	# ── 1. estados históricos: primero la lista de candidatos por clase (consulta liviana), luego los detalles por lotes
	_estado("Buscando estados históricos importantes…")
	var limite_total := int(cfg["limite_prueba"]) if prueba else 1000000000
	var minimo := int(cfg["min_sitelinks_prueba"]) if prueba else int(cfg["min_sitelinks"])
	var candidatos := {}                                   # qid -> páginas de Wikipedia (importancia)
	for c in cfg["clases_estado"]:
		if detener:
			return false
		var clase := String(c)
		var q0 := Q_IDS.replace("{{CLASE}}", clase).replace("{{FIN}}", "" if clase == "Q3024240" else "?e wdt:P576 ?fin_exigido .").replace("{{MIN}}", str(minimo))
		var filas0 = await _sparql(q0)
		if filas0 == null:
			return false
		var nuevos_c := 0
		for b in filas0:
			var qid0 := _qid(_v(b, "e"))
			if qid0 == "" or paises_qid.has(qid0):
				continue
			if not candidatos.has(qid0):
				nuevos_c += 1
			var sl_txt := _v(b, "sl")
			candidatos[qid0] = maxi(int(candidatos.get(qid0, 0)), int(sl_txt) if sl_txt.is_valid_int() else 0)
		_log("Clase %s: %d filas con al menos %d páginas de Wikipedia (%d candidatos nuevos, total %d)" % [clase, filas0.size(), minimo, nuevos_c, candidatos.size()])
	var orden: Array = candidatos.keys()
	orden.sort_custom(func(x, y): return int(candidatos[x]) > int(candidatos[y]) or (int(candidatos[x]) == int(candidatos[y]) and String(x) < String(y)))
	if prueba and orden.size() > limite_total * 2:
		orden = orden.slice(0, limite_total * 2)            # margen por los que luego se descartan (sin nombre)
	_log("Candidatos a estados (más importantes primero): %d" % orden.size())
	var lotes_d: Array = _lotes(orden)
	for i in lotes_d.size():
		if detener:
			return false
		if ents.size() >= limite_total:
			break
		_estado("Detalles de los estados…", i, lotes_d.size())
		var filas1 = await _sparql(Q_DETALLE.replace("{{LISTA}}", _lista_wd(lotes_d[i])))
		if filas1 == null:
			return false
		for b in filas1:
			var qid := _qid(_v(b, "e"))
			if qid == "" or paises_qid.has(qid):
				continue
			var nom := _v(b, "l_es") if _v(b, "l_es") != "" else _v(b, "l_en")
			if nom == "" or (nom.begins_with("Q") and nom.substr(1).is_valid_int()):
				nom = ""                          # sin nombre legible: se omite (Wikidata solo tiene su código)
			var ini := _fecha(_v(b, "ini"))
			var fin := _fecha(_v(b, "fin"))
			if ents.has(qid):
				var e0: Dictionary = ents[qid]
				if ini > 0 and (int(e0["ini"]) == 0 or ini < int(e0["ini"])):
					e0["ini"] = ini
				if fin > 0 and fin > int(e0["fin"]):
					e0["fin"] = fin
				continue
			if nom == "":
				continue
			ents[qid] = {"nombre": nom, "ini": ini, "fin": fin, "cap_es": "", "cap_en": "", "pred": [], "suc": []}
		_estado("Estados históricos: %d" % ents.size())
	if prueba and ents.size() > limite_total:
		for k in ents.keys().slice(limite_total):
			ents.erase(k)
	_log("Estados con nombre y datos: %d" % ents.size())
	if ents.is_empty():
		_log("No llegaron estados históricos. Revisa tu conexión o la configuración (clases_estado).")
		return false
	var todos_qid: Array = ents.keys()
	var objetivo_qid: Array = todos_qid + paises_qid.keys()           # estados + países + continentes (nombres, banderas, gobernantes)
	# ── 2. relaciones y capital (solo estados)
	var lotes_e: Array = _lotes(todos_qid)
	for i in lotes_e.size():
		if detener:
			return false
		_estado("Capitales y sucesiones…", i, lotes_e.size())
		var filas2 = await _sparql(Q_RELACIONES.replace("{{LISTA}}", _lista_wd(lotes_e[i])))
		if filas2 == null:
			return false
		for b in filas2:
			var qid := _qid(_v(b, "e"))
			if not ents.has(qid):
				continue
			var e: Dictionary = ents[qid]
			match _v(b, "rel"):
				"pred":
					e["pred"].append(_qid(_v(b, "otro")))
				"suc":
					e["suc"].append(_qid(_v(b, "otro")))
				"cap_es":
					e["cap_es"] = _v(b, "txt")
				"cap_en":
					e["cap_en"] = _v(b, "txt")
	# ── 3. nombres
	var lotes_o: Array = _lotes(objetivo_qid)
	for i in lotes_o.size():
		if detener:
			return false
		_estado("Nombres con fechas…", i, lotes_o.size())
		var filas3 = await _sparql(Q_NOMBRES.replace("{{LISTA}}", _lista_wd(lotes_o[i])))
		if filas3 == null:
			return false
		for b in filas3:
			var nombre := _v(b, "nombre")
			if nombre == "":
				continue
			var idioma_n := _v(b, "lang")
			if _v(b, "clase") == "comun" and idioma_n != "" and not (cfg["idiomas_comun"] as Array).has(idioma_n):
				idiomas_omitidos += 1
				continue
			nombres.append([_qid(_v(b, "e")), nombre, idioma_n, _v(b, "clase"), _fecha(_v(b, "ini")), _fecha(_v(b, "fin"))])
	_log("Nombres recibidos: %d (se omitieron %d nombres comunes en idiomas fuera de la lista «idiomas_comun»)" % [nombres.size(), idiomas_omitidos])
	# ── 4. banderas
	var qids_banderas: Array = todos_qid.duplicate()
	if bool(cfg["banderas_paises_actuales"]):
		qids_banderas += paises_qid.keys()
	var lotes_b: Array = _lotes(qids_banderas)
	for i in lotes_b.size():
		if detener:
			return false
		_estado("Banderas y escudos (lista)…", i, lotes_b.size())
		var filas4 = await _sparql(Q_BANDERAS.replace("{{LISTA}}", _lista_wd(lotes_b[i])))
		if filas4 == null:
			return false
		for b in filas4:
			var uri := _v(b, "img")
			if uri == "":
				continue
			var archivo := uri.get_slice("Special:FilePath/", 1).uri_decode().replace("_", " ") if uri.contains("Special:FilePath/") else uri.get_file().uri_decode().replace("_", " ")
			if archivo == "":
				continue
			banderas.append([_qid(_v(b, "e")), archivo, _v(b, "clase"), _fecha(_v(b, "ini")), _fecha(_v(b, "fin"))])
	_log("Banderas/escudos listados: %d" % banderas.size())
	# ── 5. gobernantes
	if bool(cfg["gobernantes"]):
		for i in lotes_o.size():
			if detener:
				return false
			_estado("Jefes de Estado y de gobierno…", i, lotes_o.size())
			var filas5 = await _sparql(Q_GOBERNANTES.replace("{{LISTA}}", _lista_wd(lotes_o[i])))
			if filas5 == null:
				return false
			for b in filas5:
				var pq := _qid(_v(b, "p"))
				if pq == "":
					continue
				var pn := _v(b, "pl_es") if _v(b, "pl_es") != "" else _v(b, "pl_en")
				if pn == "" or (pn.begins_with("Q") and pn.substr(1).is_valid_int()):
					continue
				if not personas.has(pq):
					personas[pq] = {"nombre": pn, "nac": _fecha(_v(b, "nac")), "mue": _fecha(_v(b, "mue"))}
				cargos.append([_qid(_v(b, "e")), pq, _v(b, "cargo"), _fecha(_v(b, "ini")), _fecha(_v(b, "fin"))])
		_log("Gobernantes: %d personas, %d cargos" % [personas.size(), cargos.size()])
	# ── 6. imágenes y licencias
	if bool(cfg["descargar_banderas"]) and not solo_cache:
		if not await _imagenes(prueba):
			return false
	else:
		_reconstruir_archivos_local()
	return true


## Los países y continentes del juego: a3 -> ID. Se leen de datos/entidades.json y datos/ids.json.
func _paises_juego() -> Dictionary:
	var ent = JSON.parse_string(FileAccess.get_file_as_string("res://datos/entidades.json"))
	var ids = JSON.parse_string(FileAccess.get_file_as_string("res://datos/ids.json"))
	var r := {}
	if not (ent is Dictionary) or not (ids is Dictionary):
		return r
	var por_nombre := {}
	for f in ids["territorios"]:
		if int(f[1]) == BDScript.T_PAIS:
			por_nombre[String(f[2])] = int(f[0])
	for nombre in ent["paises"]:
		var a3 := String(ent["paises"][nombre].get("a3", ""))
		if a3 != "" and por_nombre.has(nombre):
			r[a3] = por_nombre[nombre]
	return r


func _continentes_juego() -> Dictionary:
	var ids = JSON.parse_string(FileAccess.get_file_as_string("res://datos/ids.json"))
	var r := {}
	if ids is Dictionary:
		for f in ids["territorios"]:
			if int(f[1]) == BDScript.T_CONTINENTE:
				r[String(f[2])] = int(f[0])
	return r


# ─────────────────────────────────────────────────────────────
# Imágenes
# ─────────────────────────────────────────────────────────────
func _leer_licencias() -> Dictionary:
	var ruta: String = String(cfg["cache"]) + "licencias.json"
	if FileAccess.file_exists(ruta):
		var js = JSON.parse_string(FileAccess.get_file_as_string(ruta))
		if js is Dictionary:
			return js
	return {}


func _guardar_licencias() -> void:
	var f := FileAccess.open(String(cfg["cache"]) + "licencias.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(licencias))



func _leer_autores() -> Dictionary:
	var ruta: String = String(cfg["cache"]) + "autores.json"
	if FileAccess.file_exists(ruta):
		var js = JSON.parse_string(FileAccess.get_file_as_string(ruta))
		if js is Dictionary:
			return js
	return {}


func _guardar_autores() -> void:
	var f := FileAccess.open(String(cfg["cache"]) + "autores.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(autores))


## El campo «Artist» de Commons viene en HTML: se deja solo el texto.
func _limpiar_html(t: String) -> String:
	var re := RegEx.new()
	re.compile("<[^>]*>")
	var r := re.sub(t, "", true)
	r = r.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'").replace("&nbsp;", " ")
	r = r.strip_edges().replace("\n", " ")
	var mitad := r.length() / 2                                  # Commons a veces repite el texto: «Unknown authorUnknown author»
	if r.length() >= 2 and r.length() % 2 == 0 and r.substr(0, mitad) == r.substr(mitad):
		r = r.substr(0, mitad)
	return r


## Clasifica el texto de licencia que da Commons:
##   libre             dominio público / CC0 (no exige nada)
##   atribucion        CC BY, CC BY-SA (se puede usar comercialmente, hay que dar crédito)
##   revisar           GFDL u otras: se usa, pero hay que mirarla a mano
##   no_comercial      NC, ND, uso legítimo, «todos los derechos reservados»: NO sirve para vender el juego
##   sin_verificar     Commons no devolvió licencia
## OJO: es una ayuda, no asesoría legal.
func _clase_licencia(lic: String) -> String:
	var t := lic.strip_edges().to_lower()
	if t == "":
		return "sin_verificar"
	for malo in ["-nc", " nc", "noncommercial", "non-commercial", "-nd", " nd", "noderiv", "fair use", "all rights reserved", "non-free", "copyrighted", "restricted"]:
		if t.contains(malo):
			return "no_comercial"
	if t.begins_with("public domain") or t.begins_with("pd") or t.begins_with("cc0") or t.contains("public domain"):
		return "libre"
	if t.begins_with("cc by") or t.begins_with("cc-by") or t.begins_with("attribution"):
		return "atribucion"
	return "revisar"


func _imagen_permitida(archivo: String) -> bool:
	var clase := _clase_licencia(String(licencias.get(archivo, "")))
	return not (cfg["descartar_licencias"] as Array).has(clase)


func _nombre_local(archivo: String) -> String:
	return archivo.md5_text().substr(0, 14) + ".png"


func _reconstruir_archivos_local() -> void:
	for b in banderas:
		var a: String = b[1]
		var ruta: String = String(cfg["salida_banderas"]) + _nombre_local(a)
		archivos_local[a] = _nombre_local(a) if FileAccess.file_exists(ruta) else ""
		if String(archivos_local[a]) != "" and not _imagen_permitida(a):
			_registrar_descartada(a)
			archivos_local[a] = ""


func _registrar_descartada(archivo: String) -> void:
	for d in descartadas:
		if d[0] == archivo:
			return
	var lic := String(licencias.get(archivo, ""))
	descartadas.append([archivo, lic, _clase_licencia(lic)])


func _imagenes(prueba: bool) -> bool:
	var unicos := {}
	for b in banderas:
		unicos[b[1]] = true
	var lista: Array = unicos.keys()
	if prueba:
		lista = lista.slice(0, int(cfg["max_imagenes_prueba"]))
	DirAccess.make_dir_recursive_absolute(String(cfg["salida_banderas"]))
	_log("Imágenes distintas por bajar: %d" % lista.size())
	# licencias (50 archivos por consulta)
	var cab := PackedStringArray(["User-Agent: " + String(cfg["agente"])])
	var sin_licencia := []
	for a in lista:
		if String(licencias.get(a, "")) == "" or not autores.has(a):
			sin_licencia.append(a)
	var i := 0
	while i < sin_licencia.size() and not detener:
		var trozo: Array = sin_licencia.slice(i, i + 50)
		_estado("Licencias de las imágenes…", i, sin_licencia.size())
		var titulos := PackedStringArray()
		for a in trozo:
			titulos.append("File:" + String(a))
		var url := String(cfg["base_commons"]) + "/w/api.php?action=query&prop=imageinfo&iiprop=extmetadata&iiextmetadatafilter=LicenseShortName%7CCopyrighted%7CArtist&format=json&formatversion=2&titles=" + "|".join(titulos).uri_encode()
		await _esperar(int(cfg["pausa_imagen_ms"]))
		var r: Dictionary = await _pedir(url, cab)
		if bool(r["ok"]):
			var js = JSON.parse_string((r["cuerpo"] as PackedByteArray).get_string_from_utf8())
			if js is Dictionary and js.has("query"):
				for pg in js["query"].get("pages", []):
					var tt := String(pg.get("title", "")).trim_prefix("File:")
					var info: Array = pg.get("imageinfo", [])
					if info.size() > 0:
						var meta: Dictionary = info[0].get("extmetadata", {})
						var lic := String(meta.get("LicenseShortName", {}).get("value", ""))
						if lic == "" and String(meta.get("Copyrighted", {}).get("value", "")) == "False":
							lic = "Public domain"
						licencias[tt] = lic
						autores[tt] = _limpiar_html(String(meta.get("Artist", {}).get("value", "")))
		else:
			_log("No pude leer licencias de un grupo de imágenes (código %d); quedarán sin verificar." % int(r["codigo"]))
		i += 50
	_guardar_licencias()
	_guardar_autores()
	# descarga de cada imagen (si ya existe en disco no se repite)
	var hechas := 0
	var bien := 0
	for a in lista:
		if detener:
			return false
		hechas += 1
		_estado("Banderas: %d de %d" % [hechas, lista.size()], hechas, lista.size())
		if hechas % 100 == 0:
			_log("Imágenes: %d de %d revisadas · %d guardadas · %d descartadas por licencia" % [hechas, lista.size(), bien, descartadas.size()])
		var local := _nombre_local(String(a))
		var ruta := String(cfg["salida_banderas"]) + local
		if not _imagen_permitida(String(a)):
			archivos_local[a] = ""
			_registrar_descartada(String(a))
			continue
		if FileAccess.file_exists(ruta):
			archivos_local[a] = local
			bien += 1
			continue
		await _esperar(int(cfg["pausa_imagen_ms"]))
		var url2 := String(cfg["base_commons"]) + "/wiki/Special:FilePath/" + String(a).uri_encode() + "?width=" + str(int(cfg["ancho_bandera"]))
		var r2: Dictionary = await _pedir(url2, cab)
		archivos_local[a] = ""
		if not bool(r2["ok"]):
			_log("Imagen no disponible: %s (código %d)" % [a, int(r2["codigo"])])
			continue
		var bytes: PackedByteArray = r2["cuerpo"]
		var img := Image.new()
		var err := ERR_FILE_UNRECOGNIZED
		if bytes.size() > 4 and bytes[0] == 0x89 and bytes[1] == 0x50:
			err = img.load_png_from_buffer(bytes)
		elif bytes.size() > 3 and bytes[0] == 0xFF and bytes[1] == 0xD8:
			err = img.load_jpg_from_buffer(bytes)
		elif bytes.size() > 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF":
			err = img.load_webp_from_buffer(bytes)
		if err != OK or img.is_empty():
			_log("Formato de imagen no reconocido: %s" % a)
			continue
		if img.save_png(ruta) == OK:
			archivos_local[a] = local
			bien += 1
	_log("Imágenes guardadas: %d de %d (%d descartadas por su licencia)" % [bien, lista.size(), descartadas.size()])
	return true


# ─────────────────────────────────────────────────────────────
# Conversión a los archivos del juego
# ─────────────────────────────────────────────────────────────
func _leer_json(ruta: String) -> Variant:
	if not FileAccess.file_exists(ruta):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(ruta))


func _escribir_json(ruta: String, datos: Dictionary) -> bool:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		_log("No pude escribir %s" % ruta)
		return false
	f.store_string(JSON.stringify(datos))
	return true


func _convertir() -> bool:
	var dir: String = cfg["salida"]
	DirAccess.make_dir_recursive_absolute(dir)
	if ents.is_empty():
		_log("No hay estados para convertir (¿primera vez? usa PRUEBA o DESCARGA COMPLETA).")
		return false
	# copia de seguridad de lo anterior
	var sello := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var dir_resp: String = String(cfg["respaldo"]) + sello + "/"
	DirAccess.make_dir_recursive_absolute(dir_resp)
	for n in ["entidades", "nombres", "banderas", "personas", "cargos"]:
		if FileAccess.file_exists(dir + n + ".json"):
			DirAccess.copy_absolute(dir + n + ".json", dir_resp + n + ".json")
	_log("Copia de lo anterior en %s" % dir_resp)
	var quitar_sem := bool(cfg["quitar_semilla"])
	# ── lo que ya había
	var old_e = _leer_json(dir + "entidades.json")
	var old_p = _leer_json(dir + "personas.json")
	var sig_e := ID_ENT_INICIO
	var sig_p := ID_PER_INICIO
	var filas_e_old := []
	var filas_p_old := []
	if old_e is Dictionary:
		sig_e = maxi(int(old_e.get("siguiente_id", ID_ENT_INICIO)), ID_ENT_INICIO)
		filas_e_old = old_e.get("filas", [])
	if old_p is Dictionary:
		sig_p = maxi(int(old_p.get("siguiente_id", ID_PER_INICIO)), ID_PER_INICIO)
		filas_p_old = old_p.get("filas", [])
	var id_por_clave := {}
	var quitar_ids := {}                                       # IDs de la semilla que se eliminan
	var soltar_ids := {}                                       # estados de Wikidata de una corrida anterior que una PRUEBA no repite
	var limpiar := modo_prueba and bool(cfg.get("limpiar_en_prueba", true))
	var conservar_e := []
	for f in filas_e_old:
		id_por_clave[String(f[1])] = int(f[0])
		if quitar_sem and String(f[7]) == "semilla":
			quitar_ids[int(f[0])] = true
		elif limpiar and String(f[7]) == "wikidata":
			soltar_ids[int(f[0])] = true                          # su ID se podrá reutilizar si vuelve a salir
		else:
			conservar_e.append(f)
	var id_per_clave := {}
	var conservar_p := []
	for f in filas_p_old:
		id_per_clave[String(f[1])] = int(f[0])
		if quitar_sem and String(f[1]).begins_with("semilla:"):
			quitar_ids[int(f[0])] = true
		else:
			conservar_p.append(f)
	# ── IDs de los estados nuevos
	var id_de_qid := {}
	for qid in ents:
		var clave := "wd:" + String(qid)
		if id_por_clave.has(clave) and not quitar_ids.has(int(id_por_clave[clave])):
			id_de_qid[qid] = int(id_por_clave[clave])
		else:
			id_de_qid[qid] = sig_e
			sig_e += 1
	for qid in paises_qid:
		id_de_qid[qid] = int(paises_qid[qid])
	var filas_e := []
	var reemplazados := {}
	for qid in ents:
		reemplazados[int(id_de_qid[qid])] = true
	var n_semilla := quitar_ids.size()
	var n_soltados := 0
	for k in soltar_ids:                                       # sus nombres, banderas y cargos viejos también se quitan
		if not reemplazados.has(int(k)):
			quitar_ids[int(k)] = true
			n_soltados += 1
	for f in conservar_e:
		if not reemplazados.has(int(f[0])):
			filas_e.append(f)
	for qid in ents:
		var e: Dictionary = ents[qid]
		var cap: String = String(e["cap_es"]) if String(e["cap_es"]) != "" else String(e["cap_en"])
		var pred := []
		for x in e["pred"]:
			if id_de_qid.has(x) and not pred.has(int(id_de_qid[x])):
				pred.append(int(id_de_qid[x]))
		var suc := []
		for x in e["suc"]:
			if id_de_qid.has(x) and not suc.has(int(id_de_qid[x])):
				suc.append(int(id_de_qid[x]))
		filas_e.append([int(id_de_qid[qid]), "wd:" + String(qid), String(e["nombre"]), _tipo_por_nombre(String(e["nombre"])), int(e["ini"]), _fin_ok(int(e["ini"]), int(e["fin"])), cap, "wikidata", pred, suc])
	# ── personas
	var id_de_pq := {}
	for pq in personas:
		var clave_p := "wd:" + String(pq)
		if id_per_clave.has(clave_p) and not quitar_ids.has(int(id_per_clave[clave_p])):
			id_de_pq[pq] = int(id_per_clave[clave_p])
		else:
			id_de_pq[pq] = sig_p
			sig_p += 1
	var filas_p := []
	var rep_p := {}
	for pq in personas:
		rep_p[int(id_de_pq[pq])] = true
	for f in conservar_p:
		if not rep_p.has(int(f[0])):
			filas_p.append(f)
	for pq in personas:
		var p: Dictionary = personas[pq]
		filas_p.append([int(id_de_pq[pq]), "wd:" + String(pq), String(p["nombre"]), int(p["nac"]), int(p["mue"])])
	# ── nombres, banderas, cargos: se reemplazan las filas viejas de los IDs que reciben filas nuevas; las de la semilla se quitan
	var nuevos_n := []
	var ids_n := {}
	var vistos := {}
	for b in nombres:
		if not id_de_qid.has(b[0]):
			continue
		var fila := [int(id_de_qid[b[0]]), String(b[1]), String(b[2]), String(b[3]), int(b[4]), _fin_ok(int(b[4]), int(b[5]))]
		var k := "|".join(PackedStringArray(fila.map(func(x): return str(x))))
		if not vistos.has(k):
			vistos[k] = true
			nuevos_n.append(fila)
			ids_n[int(fila[0])] = true
	var filas_n := _filtrar_viejas(dir + "nombres.json", 0, ids_n, quitar_ids)
	filas_n.append_array(nuevos_n)
	var nuevos_b := []
	var ids_b := {}
	var vistas_b := {}
	var sin_archivo := 0
	for b in banderas:
		if not id_de_qid.has(b[0]):
			continue
		var local := String(archivos_local.get(b[1], ""))
		if local == "":
			sin_archivo += 1
			continue
		var fila_b := [int(id_de_qid[b[0]]), local, String(b[2]), int(b[3]), _fin_ok(int(b[3]), int(b[4])), String(licencias.get(b[1], ""))]
		var kb := "|".join(PackedStringArray(fila_b.map(func(x): return str(x))))
		if not vistas_b.has(kb):
			vistas_b[kb] = true
			nuevos_b.append(fila_b)
			ids_b[int(fila_b[0])] = true
	var filas_b := _filtrar_viejas(dir + "banderas.json", 0, ids_b, quitar_ids)
	filas_b.append_array(nuevos_b)
	var nuevos_c := []
	var ids_c := {}
	var vistos_c := {}
	for c in cargos:
		if not id_de_qid.has(c[0]) or not id_de_pq.has(c[1]):
			continue
		var fila_c := [int(id_de_pq[c[1]]), int(id_de_qid[c[0]]), String(c[2]), int(c[3]), _fin_ok(int(c[3]), int(c[4]))]
		var kc := "|".join(PackedStringArray(fila_c.map(func(x): return str(x))))
		if not vistos_c.has(kc):
			vistos_c[kc] = true
			nuevos_c.append(fila_c)
			ids_c[int(fila_c[1])] = true
	var filas_c := _filtrar_viejas(dir + "cargos.json", 1, ids_c, quitar_ids, 0)
	filas_c.append_array(nuevos_c)
	# ── escribir
	var v := "0.1.7.9.9C"
	var ok := true
	ok = _escribir_json(dir + "entidades.json", {"version": v, "siguiente_id": sig_e, "columnas": ["id", "clave", "nombre", "tipo", "inicio", "fin", "capital", "fuente", "predecesores", "sucesores"], "filas": filas_e}) and ok
	ok = _escribir_json(dir + "nombres.json", {"version": v, "columnas": ["id", "nombre", "idioma", "clase", "desde", "hasta"], "filas": filas_n}) and ok
	ok = _escribir_json(dir + "banderas.json", {"version": v, "columnas": ["id", "archivo", "clase", "desde", "hasta", "licencia"], "filas": filas_b}) and ok
	ok = _escribir_json(dir + "personas.json", {"version": v, "siguiente_id": sig_p, "columnas": ["id", "clave", "nombre", "nacimiento", "muerte"], "filas": filas_p}) and ok
	ok = _escribir_json(dir + "cargos.json", {"version": v, "columnas": ["persona", "entidad", "cargo", "desde", "hasta"], "filas": filas_c}) and ok
	_log("Archivos escritos en %s: %d estados · %d nombres · %d banderas (%d sin imagen) · %d personas · %d cargos" % [dir, filas_e.size(), filas_n.size(), filas_b.size(), sin_archivo, filas_p.size(), filas_c.size()])
	if n_semilla > 0:
		_log("Se quitaron %d filas de la semilla de ejemplo (ya están los datos reales)." % n_semilla)
	if n_soltados > 0:
		_log("PRUEBA: se quitaron %d estados de una corrida anterior que ya no están en esta muestra (para no mezclar). La descarga COMPLETA conserva todo." % n_soltados)
	if fechas_raras > 0:
		_log("Fechas incoherentes (fin antes del inicio) corregidas ignorando el fin: %d" % fechas_raras)
	_escribir_creditos(dir, filas_b, filas_e)
	_log("Revisa creditos_banderas.txt y banderas_descartadas.txt en %s antes de publicar el juego." % dir)
	return ok


## Si el fin es anterior al inicio (dato malo de Wikidata) se ignora el fin.
func _fin_ok(ini: int, fin: int) -> int:
	if ini > 0 and fin > 0 and fin < ini:
		fechas_raras += 1
		return 0
	return fin


func _escribir_texto(ruta: String, texto: String) -> bool:
	var f := FileAccess.open(ruta, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(texto)
	return true


## Créditos de las imágenes (autor + licencia + enlace) y lista de las descartadas.
func _escribir_creditos(dir: String, filas_b: Array, filas_e: Array) -> void:
	var nombres_id := {}
	var ids = JSON.parse_string(FileAccess.get_file_as_string("res://datos/ids.json"))
	if ids is Dictionary:
		for f in ids["territorios"]:
			nombres_id[int(f[0])] = String(f[2])
	for f in filas_e:
		nombres_id[int(f[0])] = String(f[2])
	var rev := {}
	for a in archivos_local:
		if String(archivos_local[a]) != "":
			rev[String(archivos_local[a])] = String(a)
	var por_archivo := {}
	for f in filas_b:
		var l := String(f[1])
		if not por_archivo.has(l):
			por_archivo[l] = {"usos": [], "lic": String(f[5])}
		var usos: Array = por_archivo[l]["usos"]
		var uso := "%s (%s)" % [nombres_id.get(int(f[0]), "ID %d" % int(f[0])), String(f[2])]
		if not usos.has(uso):
			usos.append(uso)
	var t := "CRÉDITOS DE LAS IMÁGENES HISTÓRICAS (generado por el descargador; no editar a mano)\n"
	t += "Fuente: Wikimedia Commons. Antes de publicar el juego, revisar las marcadas [REVISAR]. Esto es una ayuda, no asesoría legal.\n\n"
	var llaves: Array = por_archivo.keys()
	llaves.sort()
	var n_rev := 0
	for l in llaves:
		var a := String(rev.get(l, ""))
		var lic := String(por_archivo[l]["lic"])
		var marca := ""
		var clase := _clase_licencia(lic)
		if clase == "revisar":
			marca = " [REVISAR]"
			n_rev += 1
		t += "%s%s\n  Archivo en Commons: File:%s\n  Enlace: https://commons.wikimedia.org/wiki/File:%s\n  Autor: %s\n  Licencia: %s\n  Usada por: %s\n\n" % [l, marca, a, a.replace(" ", "_").uri_encode(), String(autores.get(a, "")) if String(autores.get(a, "")) != "" else "(no informado)", lic, "; ".join(PackedStringArray(por_archivo[l]["usos"]))]
	if not _escribir_texto(dir + "creditos_banderas.txt", t):
		_log("No pude escribir creditos_banderas.txt")
	var d := "IMÁGENES DESCARTADAS POR SU LICENCIA (no se copiaron al juego)\n\n"
	for x in descartadas:
		d += "File:%s  |  licencia: %s  |  motivo: %s\n" % [x[0], x[1] if String(x[1]) != "" else "(sin dato)", x[2]]
	_escribir_texto(dir + "banderas_descartadas.txt", d)
	_log("Créditos escritos (%d imágenes, %d a revisar a mano) · descartadas por licencia: %d" % [llaves.size(), n_rev, descartadas.size()])


## Filas de un archivo existente que se conservan: se descartan las de IDs que esta corrida vuelve a escribir y las de la semilla.
func _filtrar_viejas(ruta: String, col_id: int, tocados: Dictionary, quitar: Dictionary, col_persona := -1) -> Array:
	var r := []
	var js = _leer_json(ruta)
	if js is Dictionary:
		for f in js.get("filas", []):
			var id := int(f[col_id])
			if tocados.has(id) or quitar.has(id):
				continue
			if col_persona >= 0 and quitar.has(int(f[col_persona])):
				continue
			r.append(f)
	return r
