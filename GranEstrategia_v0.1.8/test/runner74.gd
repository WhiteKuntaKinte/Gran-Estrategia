extends Node
## 0.1.8.32 · PRUEBAS de Opciones > Pantalla (ventana + gráficos del mapa + prioridad de la simulación) e Información.
## Ajustes (valores válidos, sanear, guardar/cargar, resoluciones, centrar, confirmación, aplicar a la ventana real) ·
## MenuPantalla (controles, APLICAR sin y con confirmación, cuenta atrás, MANTENER, REVERTIR) ·
## MapaPrincipal (submenú OPCIONES, ventana INFORMACIÓN, carga de ajustes al arrancar, contador de FPS).
const AjustesScript := preload("res://scripts/ajustes.gd")
const MenuPantallaScript := preload("res://scripts/menu_pantalla.gd")
const TEMP := "user://prueba_ajustes.cfg"

var main
var fallos := 0
var n_ok := 0


func _ready() -> void:
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
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


func borrar_temp() -> void:
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))


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


## Deja la ventana y el motor como los dejan las demás pruebas.
func restaurar() -> void:
	AjustesScript.aplicar(AjustesScript.por_defecto(), get_window())
	Engine.max_fps = 0
	borrar_temp()


# ───────────────────────── Ajustes: valores por defecto y saneado ─────────────────────────
func t_sanear() -> void:
	print("[T] ── Ajustes: por_defecto, sanear, iguales")
	var d := AjustesScript.por_defecto()
	ok(d.keys().size() == 18 and d.has("tema") and d.has("bordes") and d.has("ancho_fs") and d.has("alto_fs") and d.has("modo") and d.has("sin_bordes") and d.has("ancho") and d.has("alto") and d.has("vsync") and d.has("fps_max") and d.has("msaa") and d.has("mostrar_fps") and d.has("mar") and d.has("costa") and d.has("lineas_prov") and d.has("ciudades") and d.has("lagos") and d.has("sim_prio"), "por_defecto: las 18 claves (10 de ventana + 6 de gráficos + tema y bordes del mapa)")
	ok(d["mar"] == 0 and d["costa"] == 0 and d["lineas_prov"] == true and d["ciudades"] == true and d["lagos"] == true and d["sim_prio"] == 1, "por_defecto: gráficos como siempre (mar con profundidad, costa detallada, todo visible, simulación equilibrada)")
	ok(d["modo"] == 0 and d["ancho"] == 1280 and d["alto"] == 720 and d["vsync"] == 1 and d["fps_max"] == 0 and d["msaa"] == 1 and d["mostrar_fps"] == true and d["sin_bordes"] == false, "por_defecto: ventana 1280×720, VSync, 2x, FPS visibles")
	ok(AjustesScript.iguales(AjustesScript.sanear(d), d), "sanear(por_defecto) no cambia nada")
	var vacio := AjustesScript.sanear({})
	ok(AjustesScript.iguales(vacio, d), "sanear({}) = valores por defecto")
	var raro := AjustesScript.sanear({"modo": "x", "vsync": null, "msaa": [1], "fps_max": "60", "ancho": "grande", "alto": {}, "sin_bordes": "si", "mostrar_fps": 1,
		"mar": "x", "costa": null, "lineas_prov": 1, "ciudades": "no", "lagos": 0, "sim_prio": []})
	ok(AjustesScript.iguales(raro, d), "sanear: tipos equivocados (texto, null, lista, 1 en vez de bool) → por defecto")
	var fuera := AjustesScript.sanear({"modo": 5, "vsync": 3, "msaa": -1, "fps_max": 77, "mar": 5, "costa": 7, "sim_prio": -3})
	ok(int(fuera["modo"]) == 0 and int(fuera["vsync"]) == 1 and int(fuera["msaa"]) == 1 and int(fuera["fps_max"]) == 0, "sanear: valores fuera de la lista (modo 5, vsync 3, msaa -1, 77 FPS) → por defecto")
	ok(int(fuera["mar"]) == 0 and int(fuera["costa"]) == 0 and int(fuera["sim_prio"]) == 1, "sanear: mar 5, costa 7 y prioridad -3 → por defecto")
	var tam := AjustesScript.sanear({"ancho": 100, "alto": 99999})
	ok(int(tam["ancho"]) == AjustesScript.TAM_MIN.x and int(tam["alto"]) == AjustesScript.TAM_MAX.y, "sanear: tamaños acotados a %s..%s" % [str(AjustesScript.TAM_MIN), str(AjustesScript.TAM_MAX)])
	var dec := AjustesScript.sanear({"ancho": 1920.0, "alto": 1080.0, "modo": 1.0, "fps_max": 60.0})
	ok(int(dec["ancho"]) == 1920 and int(dec["alto"]) == 1080 and int(dec["modo"]) == 1 and int(dec["fps_max"]) == 60, "sanear: decimales sin parte fraccionaria valen como enteros")
	ok(int(AjustesScript.sanear({"modo": 0.5})["modo"]) == 0, "sanear: 0,5 no es un modo válido")
	var entrada := {"vsync": 0, "extra": 42}
	var salida := AjustesScript.sanear(entrada)
	ok(not salida.has("extra") and int(entrada.size()) == 2 and int(salida["vsync"]) == 0, "sanear: tira claves desconocidas y no modifica la entrada")
	var a := AjustesScript.por_defecto()
	var b := AjustesScript.por_defecto()
	b["extra"] = 1
	ok(AjustesScript.iguales(a, b), "iguales: ignora claves que no son ajustes")
	b["fps_max"] = 60
	ok(not AjustesScript.iguales(a, b), "iguales: distingue un valor distinto")
	var c := AjustesScript.por_defecto()
	c["mostrar_fps"] = false
	ok(not AjustesScript.iguales(a, c), "iguales: distingue un bool distinto")


# ───────────────────────── Ajustes: calidad gráfica (presets) y prioridad de la simulación ─────────────────────────
func t_graficos() -> void:
	print("[T] ── Ajustes: calidades, preset_de, con_preset, presupuesto de la simulación")
	var d := AjustesScript.por_defecto()
	ok(AjustesScript.PRESETS.size() == 3 and AjustesScript.PRESETS_NOMBRES.size() == 4 and AjustesScript.PRESET_PERSONALIZADA == 3, "hay 3 calidades (Alta, Media, Baja) + Personalizada")
	var todos_validos := true
	for pr in AjustesScript.PRESETS:
		for k in pr.keys():
			if not d.has(k):
				todos_validos = false
		var s: Dictionary = AjustesScript.con_preset(d, AjustesScript.PRESETS.find(pr))
		for k in pr.keys():
			if s[k] != pr[k]:
				todos_validos = false                              # un valor de preset que sanear cambiaría = preset inválido
	ok(todos_validos, "todas las calidades usan claves y valores válidos (sanear no los cambia)")
	ok(AjustesScript.preset_de(d) == 0, "los valores por defecto son la calidad Alta")
	var media := AjustesScript.con_preset(d, 1)
	ok(int(media["costa"]) == 1 and not bool(media["lagos"]) and int(media["msaa"]) == 0 and int(media["mar"]) == 0 and bool(media["lineas_prov"]) and bool(media["ciudades"]), "Media: costa media, sin lagos ni suavizado, mar y líneas como siempre")
	ok(AjustesScript.preset_de(media) == 1, "preset_de(Media) = 1")
	var baja := AjustesScript.con_preset(d, 2)
	ok(int(baja["mar"]) == 1 and int(baja["costa"]) == 2 and not bool(baja["lineas_prov"]) and not bool(baja["lagos"]) and int(baja["msaa"]) == 0 and bool(baja["ciudades"]), "Baja: mar liso, costa baja, sin líneas de provincia ni lagos ni suavizado")
	ok(AjustesScript.preset_de(baja) == 2, "preset_de(Baja) = 2")
	var otro := AjustesScript.por_defecto()
	otro["modo"] = 1
	otro["ancho"] = 1920
	otro["alto"] = 1080
	otro["vsync"] = 0
	otro["fps_max"] = 60
	otro["mostrar_fps"] = false
	otro["sim_prio"] = 0
	var ob := AjustesScript.con_preset(otro, 2)
	ok(int(ob["modo"]) == 1 and int(ob["ancho"]) == 1920 and int(ob["vsync"]) == 0 and int(ob["fps_max"]) == 60 and not bool(ob["mostrar_fps"]) and int(ob["sim_prio"]) == 0, "con_preset no toca ventana, VSync, FPS, contador ni prioridad")
	ok(AjustesScript.preset_de(ob) == 2, "…y preset_de ignora lo que no es gráfico")
	var pers := AjustesScript.con_preset(d, 2)
	pers["ciudades"] = false
	ok(AjustesScript.preset_de(pers) == AjustesScript.PRESET_PERSONALIZADA, "cambiar un solo valor de una calidad → Personalizada")
	ok(AjustesScript.iguales(AjustesScript.con_preset(d, 3), d) and AjustesScript.iguales(AjustesScript.con_preset(d, -1), d) and AjustesScript.iguales(AjustesScript.con_preset(d, 9), d), "con_preset con índice 3, -1 o 9 deja el ajuste igual")
	ok(AjustesScript.iguales(AjustesScript.con_preset(media, 0), d), "volver a Alta devuelve los valores por defecto")
	ok(AjustesScript.presupuesto_sim_us(d) == 9000 and AjustesScript.presupuesto_sim_us({"sim_prio": 0}) == 4000 and AjustesScript.presupuesto_sim_us({"sim_prio": 2}) == 14000, "presupuesto de la simulación: 4, 9 y 14 ms según la prioridad")
	ok(AjustesScript.presupuesto_sim_us({"sim_prio": 7}) == 9000 and AjustesScript.presupuesto_sim_us({}) == 9000, "presupuesto con prioridad inválida o ausente: 9 ms")
	ok(AjustesScript.SIM_PRESUPUESTO_US.size() == AjustesScript.SIM_NOMBRES.size() and AjustesScript.MAR_NOMBRES.size() == 2 and AjustesScript.COSTA_NOMBRES.size() == 3, "listas de nombres del mismo tamaño que los valores")


# ───────────────────────── Ajustes: guardar y cargar ─────────────────────────
func t_guardar() -> void:
	print("[T] ── Ajustes: existe, guardar, cargar")
	borrar_temp()
	ok(not AjustesScript.existe(TEMP), "existe: sin archivo → false")
	ok(AjustesScript.iguales(AjustesScript.cargar(TEMP), AjustesScript.por_defecto()), "cargar sin archivo → por defecto")
	var d := {"modo": 1, "sin_bordes": true, "ancho": 1600, "alto": 900, "vsync": 0, "fps_max": 144, "msaa": 2, "mostrar_fps": false}
	ok(AjustesScript.guardar(d, TEMP) == OK, "guardar devuelve OK")
	ok(AjustesScript.existe(TEMP), "existe: con archivo → true")
	var c := AjustesScript.cargar(TEMP)
	ok(AjustesScript.iguales(c, d) and bool(c["sin_bordes"]) and not bool(c["mostrar_fps"]) and int(c["fps_max"]) == 144 and int(c["ancho"]) == 1600, "guardar → cargar devuelve lo mismo (%s)" % str(c))
	AjustesScript.guardar({"vsync": 2, "fps_max": 99}, TEMP)
	var s := AjustesScript.cargar(TEMP)
	ok(int(s["vsync"]) == 2 and int(s["fps_max"]) == 0 and int(s["ancho"]) == 1280, "guardar sanea antes de escribir (99 FPS no es válido → sin límite; lo que falta, por defecto)")
	var f := FileAccess.open(TEMP, FileAccess.WRITE)
	f.store_string("[pantalla]\nvsync=0\nmsaa=7\nancho=800\nmostrar_fps=false\n")
	f.close()
	var p := AjustesScript.cargar(TEMP)
	ok(int(p["vsync"]) == 0 and int(p["msaa"]) == 1 and int(p["ancho"]) == 800 and not bool(p["mostrar_fps"]) and int(p["alto"]) == 720, "cargar: archivo editado a mano y a medias → válido lo válido, por defecto el resto")
	var gr := {"mar": 1, "costa": 2, "lineas_prov": false, "ciudades": false, "lagos": false, "sim_prio": 2, "msaa": 0}
	AjustesScript.guardar(gr, TEMP)
	var cg := AjustesScript.cargar(TEMP)
	ok(int(cg["mar"]) == 1 and int(cg["costa"]) == 2 and not bool(cg["lineas_prov"]) and not bool(cg["ciudades"]) and not bool(cg["lagos"]) and int(cg["sim_prio"]) == 2, "guardar → cargar: los 6 ajustes gráficos nuevos se conservan")
	var vj := FileAccess.open(TEMP, FileAccess.WRITE)
	vj.store_string("[pantalla]\nmodo=0\nsin_bordes=false\nancho=1600\nalto=900\nvsync=1\nfps_max=60\nmsaa=1\nmostrar_fps=true\n")
	vj.close()
	var cv := AjustesScript.cargar(TEMP)
	ok(int(cv["ancho"]) == 1600 and int(cv["fps_max"]) == 60 and int(cv["mar"]) == 0 and int(cv["costa"]) == 0 and bool(cv["lineas_prov"]) and bool(cv["ciudades"]) and bool(cv["lagos"]) and int(cv["sim_prio"]) == 1, "cargar un archivo de la 0.1.8.31 (sin claves gráficas): lo guardado se respeta y los gráficos quedan como siempre")
	var g := FileAccess.open(TEMP, FileAccess.WRITE)
	g.store_string("esto no es un archivo de ajustes {{{")
	g.close()
	ok(AjustesScript.iguales(AjustesScript.cargar(TEMP), AjustesScript.por_defecto()), "cargar: archivo ilegible → por defecto")
	borrar_temp()


# ───────────────────────── Ajustes: listas, textos y cuentas ─────────────────────────
func t_listas() -> void:
	print("[T] ── Ajustes: resoluciones_para, textos, posicion_centrada, requiere_confirmacion")
	var r := AjustesScript.resoluciones_para(Vector2i(1920, 1080), Vector2i(1280, 720))
	ok(r == [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)], "pantalla 1920×1080: de 1024×576 hasta 1920×1080 (%s)" % str(r))
	var r2 := AjustesScript.resoluciones_para(Vector2i(3840, 2160), Vector2i(1280, 720))
	ok(r2.size() == 7 and r2[6] == Vector2i(3840, 2160), "pantalla 4K: las 7 de la lista")
	var r3 := AjustesScript.resoluciones_para(Vector2i(1920, 1080), Vector2i(1500, 800))
	ok(r3.has(Vector2i(1500, 800)) and r3.size() == 6, "tamaño actual que no está en la lista (1500×800): se añade")
	var orden_ok := true
	for i in range(1, r3.size()):
		if r3[i - 1].x * r3[i - 1].y > r3[i].x * r3[i].y:
			orden_ok = false
	ok(orden_ok and r3.find(Vector2i(1500, 800)) == r3.find(Vector2i(1366, 768)) + 1, "…y queda en su sitio por tamaño (entre 1366×768 y 1600×900)")
	ok(AjustesScript.resoluciones_para(Vector2i(1920, 1080), Vector2i(1280, 720)).count(Vector2i(1280, 720)) == 1, "un tamaño que ya está en la lista no se repite")
	ok(AjustesScript.resoluciones_para(Vector2i(800, 500), Vector2i(800, 500)) == [Vector2i(800, 500)], "pantalla más pequeña que la lista: solo su propio tamaño")
	ok(not AjustesScript.resoluciones_para(Vector2i(1920, 1080), Vector2i(300, 200)).has(Vector2i(300, 200)), "un tamaño por debajo del mínimo no se añade")
	ok(AjustesScript.limitar_a_pantalla(Vector2i(3840, 2160), Vector2i(1920, 1080)) == Vector2i(1920, 1080), "limitar_a_pantalla: una ventana de 4K en una pantalla 1080p se recorta a la pantalla")
	ok(AjustesScript.limitar_a_pantalla(Vector2i(1280, 720), Vector2i(1920, 1080)) == Vector2i(1280, 720), "limitar_a_pantalla: lo que cabe no se toca")
	ok(AjustesScript.limitar_a_pantalla(Vector2i(1280, 720), Vector2i(0, 0)) == Vector2i(1280, 720), "limitar_a_pantalla: pantalla desconocida (0×0) → no se recorta")
	ok(AjustesScript.limitar_a_pantalla(Vector2i(800, 450), Vector2i(500, 300)) == AjustesScript.TAM_MIN, "limitar_a_pantalla: nunca por debajo del mínimo (%s)" % str(AjustesScript.TAM_MIN))
	ok(AjustesScript.texto_resolucion(Vector2i(1920, 1080)) == "1920 × 1080", "texto_resolucion")
	ok(AjustesScript.texto_fps(0) == "Sin límite" and AjustesScript.texto_fps(-3) == "Sin límite" and AjustesScript.texto_fps(144) == "144 FPS", "texto_fps")
	ok(AjustesScript.posicion_centrada(Rect2i(0, 0, 1920, 1080), Vector2i(1280, 720)) == Vector2i(320, 180), "posicion_centrada: 1280×720 en 1920×1080 → (320, 180)")
	ok(AjustesScript.posicion_centrada(Rect2i(1920, 40, 1920, 1040), Vector2i(1280, 720)) == Vector2i(2240, 200), "posicion_centrada: en una segunda pantalla con desplazamiento")
	ok(AjustesScript.posicion_centrada(Rect2i(0, 30, 1280, 690), Vector2i(1600, 900)) == Vector2i(0, 30), "posicion_centrada: ventana más grande que el área → esquina del área")
	var base := AjustesScript.por_defecto()
	var cambia := func(clave: String, valor: Variant, modo_ant := 0, modo_des := 0) -> bool:
		var antes := base.duplicate()
		var despues := base.duplicate()
		antes["modo"] = modo_ant
		despues["modo"] = modo_des
		despues[clave] = valor
		return AjustesScript.requiere_confirmacion(antes, despues)
	ok(not cambia.call("vsync", 0) and not cambia.call("fps_max", 60) and not cambia.call("msaa", 2) and not cambia.call("mostrar_fps", false), "requiere_confirmacion: VSync, FPS, suavizado y contador NO la piden")
	ok(cambia.call("ancho", 1600) and cambia.call("alto", 900) and cambia.call("sin_bordes", true), "requiere_confirmacion: tamaño y «sin bordes» SÍ")
	ok(cambia.call("vsync", 1, 0, 1) and cambia.call("vsync", 1, 1, 0), "requiere_confirmacion: pasar a pantalla completa o volver, SÍ")
	var fc1 := base.duplicate()
	var fc2 := base.duplicate()
	fc1["modo"] = 1
	fc2["modo"] = 1
	fc2["ancho"] = 1920
	fc2["sin_bordes"] = true
	ok(not AjustesScript.requiere_confirmacion(fc1, fc2), "requiere_confirmacion: en pantalla completa el tamaño no cuenta")


# ───────────────────────── Ajustes sobre la ventana real ─────────────────────────
func t_ventana() -> void:
	print("[T] ── Ajustes: leer_actual y aplicar sobre la ventana real")
	var w := get_window()
	var ini := AjustesScript.leer_actual(w)
	ok(int(ini["modo"]) == 0 and int(ini["ancho"]) == w.size.x and int(ini["alto"]) == w.size.y, "leer_actual: ventana %d×%d en modo ventana" % [w.size.x, w.size.y])
	ok(int(ini["fps_max"]) == Engine.max_fps and int(ini["msaa"]) == int(w.msaa_2d), "leer_actual: FPS máximos y suavizado salen del motor")
	var previo := AjustesScript.por_defecto()
	previo["mostrar_fps"] = false
	previo["fps_max"] = 144
	previo["vsync"] = 2
	previo["msaa"] = 2
	var lp := AjustesScript.leer_actual(w, previo)
	ok(not bool(lp["mostrar_fps"]) and int(lp["fps_max"]) == 144 and int(lp["vsync"]) == 2 and int(lp["msaa"]) == 2, "leer_actual con `previo`: contador, FPS, VSync y suavizado salen del ajuste previo (no de la ventana)")
	ok(int(lp["ancho"]) == w.size.x and int(lp["modo"]) == 0, "leer_actual con `previo`: el tamaño y el modo salen de la ventana real")
	var d := AjustesScript.por_defecto()
	d["vsync"] = 0
	d["fps_max"] = 60
	d["msaa"] = 2
	AjustesScript.aplicar(d, w)
	ok(Engine.max_fps == 60 and int(w.msaa_2d) == 2 and int(DisplayServer.window_get_vsync_mode()) == 0, "aplicar: 60 FPS máx, suavizado 4x, VSync apagado (%d, %d, %d)" % [Engine.max_fps, int(w.msaa_2d), int(DisplayServer.window_get_vsync_mode())])
	var l := AjustesScript.leer_actual(w)
	ok(int(l["fps_max"]) == 60 and int(l["msaa"]) == 2 and int(l["vsync"]) == 0, "…y leer_actual lo devuelve igual")
	d["fps_max"] = 0
	d["msaa"] = 1
	d["vsync"] = 1
	d["ancho"] = 1024
	d["alto"] = 576
	AjustesScript.aplicar(d, w)
	await esperar(0.4)
	ok(w.size == Vector2i(1024, 576), "aplicar: ventana de 1024×576 (%s)" % str(w.size))
	ok(Engine.max_fps == 0 and int(w.msaa_2d) == 1, "…sin límite de FPS y suavizado 2x otra vez")
	d["ancho"] = 1280
	d["alto"] = 720
	AjustesScript.aplicar(d, w)
	await esperar(0.4)
	ok(w.size == Vector2i(1280, 720), "aplicar: de vuelta a 1280×720 (%s)" % str(w.size))
	AjustesScript.aplicar({"fps_max": 1234, "msaa": 9}, w)
	ok(Engine.max_fps == 0 and int(w.msaa_2d) == 1, "aplicar sanea: valores raros → por defecto, sin romper nada")
	var grande := AjustesScript.por_defecto()
	grande["ancho"] = 3840
	grande["alto"] = 2160
	AjustesScript.aplicar(grande, w)
	await esperar(0.4)
	var pant := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen(w.get_window_id()))
	ok(w.size == pant, "aplicar: un tamaño mayor que la pantalla (3840×2160) se recorta a la pantalla (%s)" % str(w.size))
	AjustesScript.aplicar(AjustesScript.por_defecto(), w)
	await esperar(0.4)
	# pantalla completa, y de vuelta a ventana (centrada y con el tamaño pedido)
	var c := AjustesScript.por_defecto()
	c["modo"] = 1
	c["ancho"] = 1024
	c["alto"] = 576
	AjustesScript.aplicar(c, w)
	await esperar(0.5)
	ok(w.mode == Window.MODE_FULLSCREEN, "aplicar: pantalla completa (modo %d)" % int(w.mode))
	var lc := AjustesScript.leer_actual(w, c)
	ok(int(lc["modo"]) == 1 and int(lc["ancho"]) == 1024 and int(lc["alto"]) == 576, "leer_actual en pantalla completa: modo 1 y se conserva el tamaño de ventana del ajuste previo (1024×576), no el de la pantalla")
	# 0.1.8.35 · resolución interna en pantalla completa
	var ci := AjustesScript.por_defecto()
	ci["modo"] = 1
	ci["ancho_fs"] = 1280
	ci["alto_fs"] = 720
	AjustesScript.aplicar(ci, w)
	await esperar(0.5)
	ok(w.mode == Window.MODE_FULLSCREEN and w.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and w.content_scale_size == Vector2i(1280, 720), "aplicar: pantalla completa con resolución interna 1280×720 → modo viewport (%d, %s)" % [int(w.content_scale_mode), str(w.content_scale_size)])
	var lci := AjustesScript.leer_actual(w, ci)
	ok(int(lci["ancho_fs"]) == 1280 and int(lci["alto_fs"]) == 720, "leer_actual en pantalla completa conserva la resolución interna elegida")
	ci["ancho_fs"] = 0
	ci["alto_fs"] = 0
	AjustesScript.aplicar(ci, w)
	await esperar(0.4)
	ok(w.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and w.content_scale_size == AjustesScript.BASE_PROYECTO, "aplicar: resolución «Nativa» (0×0) devuelve la escala del proyecto (canvas_items 1280×720)")
	ci["ancho_fs"] = 1024
	ci["alto_fs"] = 576
	ci["modo"] = 0
	AjustesScript.aplicar(ci, w)
	await esperar(0.5)
	ok(w.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and w.mode == Window.MODE_WINDOWED, "aplicar: en modo ventana la resolución interna NO cuenta (se guarda pero no se aplica)")
	var fs_s := AjustesScript.sanear({"modo": 1, "ancho_fs": 1280, "alto_fs": 720})
	ok(AjustesScript.interna_pedida(fs_s) == Vector2i(1280, 720) and AjustesScript.interna_pedida(AjustesScript.sanear({"modo": 0, "ancho_fs": 1280, "alto_fs": 720})) == Vector2i.ZERO, "interna_pedida: solo en pantalla completa")
	var rota := AjustesScript.sanear({"ancho_fs": 1280, "alto_fs": "x"})
	var chica := AjustesScript.sanear({"ancho_fs": 100, "alto_fs": 100})
	ok(int(rota["ancho_fs"]) == 0 and int(rota["alto_fs"]) == 0 and int(chica["ancho_fs"]) == 0, "sanear: una resolución interna a medias, rota o diminuta vale «Nativa» (0×0)")
	var lista_i := AjustesScript.resoluciones_internas(Vector2i(1920, 1080), Vector2i(1280, 720))
	ok(lista_i[0] == Vector2i.ZERO and lista_i.has(Vector2i(1280, 720)) and not lista_i.has(Vector2i(1920, 1080)) and not lista_i.has(Vector2i(2560, 1440)) and AjustesScript.texto_res_interna(Vector2i.ZERO, Vector2i(1920, 1080)) == "Nativa (1920 × 1080)", "resoluciones_internas: Nativa primero, solo menores que la pantalla (%s)" % str(lista_i))
	ok(not AjustesScript.requiere_confirmacion(AjustesScript.sanear({"modo": 1}), AjustesScript.sanear({"modo": 1, "ancho_fs": 1280, "alto_fs": 720})), "cambiar solo la resolución interna no pide confirmar (no mueve la ventana)")
	AjustesScript.aplicar(AjustesScript.por_defecto(), w)
	await esperar(0.4)
	c["modo"] = 0
	c["sin_bordes"] = true
	AjustesScript.aplicar(c, w)
	await esperar(0.5)
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen(w.get_window_id()))
	ok(w.mode == Window.MODE_WINDOWED and w.size == Vector2i(1024, 576) and w.borderless, "aplicar: de pantalla completa a ventana de 1024×576 sin bordes (%s)" % str(w.size))
	ok(w.position == AjustesScript.posicion_centrada(area, w.size), "…y centrada en la pantalla (%s)" % str(w.position))
	ok(AjustesScript.leer_actual(w)["sin_bordes"] == true, "leer_actual: ventana sin bordes")
	AjustesScript.aplicar(AjustesScript.por_defecto(), w)
	await esperar(0.5)
	ok(not w.borderless and w.size == Vector2i(1280, 720), "aplicar(por defecto): con bordes y 1280×720 otra vez")


# ───────────────────────── MenuPantalla: controles ─────────────────────────
func nuevo_panel() -> Control:
	var p := MenuPantallaScript.new()
	p.ruta = TEMP
	add_child(p)
	p.iniciar(get_window(), AjustesScript.por_defecto())
	return p


func t_panel_controles() -> void:
	print("[T] ── MenuPantalla: controles y cambios pendientes")
	borrar_temp()
	var p := nuevo_panel()
	ok(AjustesScript.iguales(p.pendiente, p.vigente) and p.vigente["ancho"] == get_window().size.x, "al abrir: pendiente = vigente = lo que tiene la ventana")
	ok(p._op_modo.selected == 0 and p._op_vsync.selected == 1 and p._op_msaa.selected == 1 and p._op_fps.selected == 0 and p._chk_fps.button_pressed and not p._chk_bordes.button_pressed, "al abrir: los controles muestran los valores actuales")
	ok(p._op_res.item_count >= 2 and p._resoluciones[p._op_res.selected] == get_window().size, "al abrir: el desplegable de resolución marca la actual (%s)" % p._op_res.get_item_text(p._op_res.selected))
	ok(p._op_modo.item_count == 2 and p._op_vsync.item_count == 3 and p._op_msaa.item_count == 3 and p._op_fps.item_count == AjustesScript.FPS_OPCIONES.size(), "desplegables: 2 modos, 3 de VSync, 3 de suavizado, %d de FPS" % p._op_fps.item_count)
	ok(p._btn_aplicar.disabled, "APLICAR está apagado mientras no hay cambios")
	p.poner("vsync", 0)
	ok(int(p.pendiente["vsync"]) == 0 and p._op_vsync.selected == 0 and not p._btn_aplicar.disabled, "poner('vsync', 0): cambia lo pendiente, el desplegable y enciende APLICAR")
	ok(int(p.vigente["vsync"]) == 1, "…y lo vigente no se toca hasta aplicar")
	p.poner("vsync", 9)
	ok(int(p.pendiente["vsync"]) == 1, "poner con un valor inválido: se sanea (queda el de por defecto)")
	p._op_fps.select(3)
	p._op_fps.item_selected.emit(3)
	ok(int(p.pendiente["fps_max"]) == AjustesScript.FPS_OPCIONES[3], "elegir en el desplegable de FPS pasa por poner (%d)" % int(p.pendiente["fps_max"]))
	p._op_msaa.select(2)
	p._op_msaa.item_selected.emit(2)
	ok(int(p.pendiente["msaa"]) == 2, "desplegable de suavizado → pendiente")
	p._op_vsync.select(2)
	p._op_vsync.item_selected.emit(2)
	ok(int(p.pendiente["vsync"]) == 2, "desplegable de VSync → pendiente")
	p._chk_fps.button_pressed = false
	ok(not bool(p.pendiente["mostrar_fps"]), "casilla del contador de FPS → pendiente")
	p._chk_bordes.button_pressed = true
	ok(bool(p.pendiente["sin_bordes"]), "casilla «sin bordes» → pendiente")
	p._op_res.select(0)
	p._op_res.item_selected.emit(0)
	ok(Vector2i(int(p.pendiente["ancho"]), int(p.pendiente["alto"])) == p._resoluciones[0], "elegir resolución → ancho y alto pendientes (%s)" % AjustesScript.texto_resolucion(p._resoluciones[0]))
	p._elegir_resolucion(99)
	p._elegir_resolucion(-1)
	ok(Vector2i(int(p.pendiente["ancho"]), int(p.pendiente["alto"])) == p._resoluciones[0], "_elegir_resolucion: un índice fuera de la lista no hace nada")
	p.poner("modo", 1)
	ok(not p._op_res.disabled and p._chk_bordes.disabled and p._lbl_res.text.contains("interna") and p._resoluciones[0] == Vector2i.ZERO, "pantalla completa: «sin bordes» se apaga y la resolución pasa a ser la INTERNA (la primera opción es «Nativa»)")
	ok(p._lbl_nota.text.contains("pantalla completa") and p._lbl_nota.text.contains("PC va justa"), "pantalla completa: la nota lo explica")
	if p._resoluciones.size() >= 2:                                   # 0.1.8.35: elegir una resolución interna menor que la pantalla
		var ant_ancho := int(p.pendiente["ancho"])
		p._elegir_resolucion(1)
		var v1: Vector2i = p._resoluciones[1]
		ok(int(p.pendiente["ancho_fs"]) == v1.x and int(p.pendiente["alto_fs"]) == v1.y and int(p.pendiente["ancho"]) == ant_ancho and p._op_res.selected == 1, "pantalla completa: elegir resolución → ancho_fs/alto_fs pendientes (%s) y el tamaño de ventana no se toca" % str(v1))
		p._elegir_resolucion(0)
		ok(int(p.pendiente["ancho_fs"]) == 0 and int(p.pendiente["alto_fs"]) == 0, "pantalla completa: «Nativa» vuelve a 0×0")
	p.poner("modo", 0)
	ok(not p._op_res.disabled and not p._chk_bordes.disabled and p._lbl_nota.text.contains("APLICAR"), "modo ventana: se vuelven a encender y la nota habla de APLICAR")
	# ── gráficos del mapa
	p.restablecer()
	ok(p._op_calidad.item_count == 4 and p._op_mar.item_count == 2 and p._op_costa.item_count == 3 and p._op_sim.item_count == 3, "desplegables gráficos: 4 calidades, 2 de mar, 3 de costas, 3 de prioridad")
	ok(p._op_calidad.selected == 0 and p._op_mar.selected == 0 and p._op_costa.selected == 0 and p._chk_prov.button_pressed and p._chk_ciudades.button_pressed and p._chk_lagos.button_pressed and p._op_sim.selected == 1, "al abrir: calidad Alta y los controles gráficos con los valores por defecto")
	p.poner_calidad(1)
	ok(AjustesScript.preset_de(p.pendiente) == 1 and p._op_calidad.selected == 1 and p._op_costa.selected == 1 and not p._chk_lagos.button_pressed and p._op_msaa.selected == 0 and not p._btn_aplicar.disabled, "calidad Media: baja costa y suavizado, apaga lagos, y mueve los controles")
	p.poner_calidad(2)
	ok(p._op_mar.selected == 1 and p._op_costa.selected == 2 and not p._chk_prov.button_pressed and p._op_calidad.selected == 2, "calidad Baja: mar liso, costa baja, sin líneas de provincia")
	ok(p._op_vsync.selected == int(p.pendiente["vsync"]) and int(p.pendiente["fps_max"]) == int(p.vigente["fps_max"]) and int(p.pendiente["sim_prio"]) == 1, "cambiar de calidad no toca VSync, FPS ni la prioridad de la simulación")
	p._chk_ciudades.button_pressed = false
	ok(not bool(p.pendiente["ciudades"]) and p._op_calidad.selected == AjustesScript.PRESET_PERSONALIZADA, "tocar una casilla suelta cambia la calidad a Personalizada")
	p._chk_ciudades.button_pressed = true
	ok(p._op_calidad.selected == 2, "…y al dejarla como estaba vuelve a Baja")
	p._op_calidad.select(0)
	p._op_calidad.item_selected.emit(0)
	ok(AjustesScript.preset_de(p.pendiente) == 0 and p._op_mar.selected == 0 and p._op_costa.selected == 0 and p._chk_prov.button_pressed, "desplegable de calidad → Alta (todo como siempre)")
	p._op_calidad.select(AjustesScript.PRESET_PERSONALIZADA)
	p._op_calidad.item_selected.emit(AjustesScript.PRESET_PERSONALIZADA)
	ok(AjustesScript.preset_de(p.pendiente) == 0, "elegir «Personalizada» a mano no cambia ningún valor")
	p._op_mar.select(1)
	p._op_mar.item_selected.emit(1)
	p._op_costa.select(2)
	p._op_costa.item_selected.emit(2)
	p._chk_prov.button_pressed = false
	p._chk_lagos.button_pressed = false
	p._op_sim.select(2)
	p._op_sim.item_selected.emit(2)
	ok(int(p.pendiente["mar"]) == 1 and int(p.pendiente["costa"]) == 2 and not bool(p.pendiente["lineas_prov"]) and not bool(p.pendiente["lagos"]) and int(p.pendiente["sim_prio"]) == 2, "cada control gráfico llega a pendiente (mar, costa, líneas, lagos, prioridad)")
	p.poner("mar", 4)
	ok(int(p.pendiente["mar"]) == 0 and p._op_mar.selected == 0, "poner('mar', 4): valor inválido → por defecto")
	ok(not AjustesScript.requiere_confirmacion(p.vigente, p.pendiente), "los cambios gráficos no piden «¿Mantener estos cambios?» (no tocan la ventana)")
	p.restablecer()
	ok(AjustesScript.iguales(p.pendiente, AjustesScript.por_defecto()) and p._op_vsync.selected == 1 and p._chk_fps.button_pressed and p._op_fps.selected == 0, "RESTABLECER: todo a los valores por defecto (sin aplicar)")
	ok(p._op_calidad.selected == 0 and p._op_sim.selected == 1 and p._chk_lagos.button_pressed, "RESTABLECER: también los controles gráficos")
	ok(int(Engine.max_fps) == 0, "…y no toca el motor hasta aplicar")
	var volvio := [0]
	p.volver_pedido.connect(func(): volvio[0] += 1)
	boton(p, "VOLVER").pressed.emit()
	ok(volvio[0] == 1, "botón VOLVER emite volver_pedido")
	ok(textos_botones(p).has("APLICAR") and textos_botones(p).has("RESTABLECER") and textos_botones(p).has("MANTENER") and textos_botones(p).has("REVERTIR"), "botones: APLICAR, RESTABLECER, VOLVER y, en el recuadro, MANTENER y REVERTIR")
	p.queue_free()
	await esperar(0.05)


# ───────────────────────── MenuPantalla: aplicar, confirmar, revertir ─────────────────────────
func t_panel_aplicar() -> void:
	print("[T] ── MenuPantalla: APLICAR sin confirmación, con confirmación, MANTENER, REVERTIR")
	borrar_temp()
	var w := get_window()
	var p := nuevo_panel()
	var avisos: Array = []
	p.aplicado.connect(func(a: Dictionary): avisos.append(a))
	# 1) un cambio que no mueve la ventana: se aplica y se guarda al instante
	p.poner("fps_max", 60)
	p.poner("msaa", 2)
	p.poner("mostrar_fps", false)
	p.aplicar_pendiente()
	ok(not p.confirmando and Engine.max_fps == 60 and int(w.msaa_2d) == 2, "APLICAR (FPS, suavizado, contador): se aplica sin pedir confirmación")
	ok(AjustesScript.existe(TEMP) and int(AjustesScript.cargar(TEMP)["fps_max"]) == 60 and not bool(AjustesScript.cargar(TEMP)["mostrar_fps"]), "…y queda guardado en el archivo")
	ok(avisos.size() == 1 and int(avisos[0]["fps_max"]) == 60 and AjustesScript.iguales(p.vigente, p.pendiente) and p._btn_aplicar.disabled, "…avisa con `aplicado`, lo vigente se actualiza y APLICAR se apaga")
	# 2) un cambio de tamaño: pide confirmación y no guarda todavía
	borrar_temp()
	p.poner("ancho", 1024)
	p.poner("alto", 576)
	p.aplicar_pendiente()
	await esperar(0.4)
	ok(p.confirmando and p.segundos_restantes == MenuPantallaScript.SEGUNDOS_CONFIRMAR and p._confirma.visible and not p._cuerpo.visible, "APLICAR con otro tamaño: aparece «¿Mantener estos cambios?» con 10 s")
	ok(w.size == Vector2i(1024, 576) and not p._timer.is_stopped(), "…la ventana ya cambió (%s) y la cuenta atrás corre" % str(w.size))
	ok(not AjustesScript.existe(TEMP) and avisos.size() == 1, "…y todavía no se guardó nada ni se avisó")
	ok(p._lbl_cuenta.text.contains("10 s"), "…el texto dice «%s»" % p._lbl_cuenta.text)
	p.poner("vsync", 0)
	p.restablecer()
	p.aplicar_pendiente()
	ok(int(p.pendiente["vsync"]) == 1 and int(p.pendiente["ancho"]) == 1024 and p.confirmando, "durante la confirmación, poner/restablecer/aplicar no hacen nada")
	p._tick()
	ok(p.segundos_restantes == 9 and p._lbl_cuenta.text.contains("9 s"), "un segundo de cuenta atrás: 9 s")
	# 2a) MANTENER
	p.confirmar()
	ok(not p.confirmando and p._cuerpo.visible and not p._confirma.visible, "MANTENER: vuelve el cuerpo y desaparece el recuadro")
	ok(AjustesScript.existe(TEMP) and int(AjustesScript.cargar(TEMP)["ancho"]) == 1024 and int(AjustesScript.cargar(TEMP)["alto"]) == 576, "MANTENER: guarda 1024×576")
	ok(avisos.size() == 2 and int(avisos[1]["ancho"]) == 1024 and p._timer.is_stopped() and int(p.vigente["ancho"]) == 1024, "MANTENER: avisa, lo vigente es 1024×576 y para el reloj")
	# 2b) REVERTIR con el botón
	borrar_temp()
	p.poner("ancho", 1280)
	p.poner("alto", 720)
	p.aplicar_pendiente()
	await esperar(0.4)
	ok(p.confirmando and w.size == Vector2i(1280, 720), "otro cambio de tamaño (a 1280×720): pide confirmación")
	boton(p, "REVERTIR").pressed.emit()
	await esperar(0.4)
	ok(not p.confirmando and w.size == Vector2i(1024, 576) and int(p.pendiente["ancho"]) == 1024 and p._timer.is_stopped(), "REVERTIR: la ventana vuelve a 1024×576 (%s) y los controles también" % str(w.size))
	ok(not AjustesScript.existe(TEMP) and avisos.size() == 2, "REVERTIR: no guarda nada ni avisa")
	ok(p._resoluciones[p._op_res.selected] == Vector2i(1024, 576), "REVERTIR: el desplegable vuelve a marcar 1024×576")
	# 2c) se acaba el tiempo
	p.poner("ancho", 1280)
	p.poner("alto", 720)
	p.aplicar_pendiente()
	await esperar(0.3)
	for i in range(MenuPantallaScript.SEGUNDOS_CONFIRMAR):
		p._tick()
	await esperar(0.4)
	ok(not p.confirmando and w.size == Vector2i(1024, 576) and not AjustesScript.existe(TEMP), "cuenta atrás en cero: se revierte sola a 1024×576 y no se guarda")
	# 2d) pantalla completa: también pide confirmación y se puede revertir
	p.poner("modo", 1)
	p.aplicar_pendiente()
	await esperar(0.5)
	ok(p.confirmando and w.mode == Window.MODE_FULLSCREEN, "APLICAR en pantalla completa: pide confirmación (modo %d)" % int(w.mode))
	p.revertir()
	await esperar(0.5)
	ok(not p.confirmando and w.mode == Window.MODE_WINDOWED and w.size == Vector2i(1024, 576) and int(p.pendiente["modo"]) == 0, "REVERTIR desde pantalla completa: vuelve a ventana de 1024×576 (%s)" % str(w.size))
	# 3) revertir fuera de una confirmación no hace nada (no debe aplicar un ajuste vacío)
	Engine.max_fps = 77
	p.revertir()
	ok(Engine.max_fps == 77, "revertir() sin confirmación pendiente no toca la ventana ni el motor")
	p._tick()
	ok(not p.confirmando, "_tick() sin confirmación pendiente no hace nada")
	p.queue_free()
	await esperar(0.05)
	restaurar()
	await esperar(0.4)
	ok(w.size == Vector2i(1280, 720) and Engine.max_fps == 0, "al terminar: ventana 1280×720 y sin límite de FPS otra vez")


# ───────────────────────── MapaPrincipal: menú OPCIONES ─────────────────────────
func t_menu() -> void:
	print("[T] ── MapaPrincipal: OPCIONES → PANTALLA / INFORMACIÓN")
	borrar_temp()
	ok(main.en_menu and textos_botones(main.menu_contenido) == ["JUGAR", "OPCIONES", "SALIR"], "menú principal: JUGAR, OPCIONES, SALIR")
	boton(main.menu_contenido, "OPCIONES").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["PANTALLA", "INFORMACIÓN", "VOLVER"], "OPCIONES abre un submenú con PANTALLA, INFORMACIÓN y VOLVER")
	var t: Array = []
	etiquetas(main.menu_contenido, t)
	ok(t.has("OPCIONES"), "…con el título OPCIONES")
	# Información
	boton(main.menu_contenido, "INFORMACIÓN").pressed.emit()
	t = []
	etiquetas(main.menu_contenido, t)
	var paises := {}
	var n_prov := 0
	for pr in main.provincias:
		paises[String(pr.get("c", ""))] = true
		if bool(pr.get("m", false)):
			n_prov += 1
	ok(t.has("INFORMACIÓN") and t.has("Países / soberanías: %d\nProvincias administrativas: %d\nUnidades territoriales representadas: %d" % [paises.size(), n_prov, main.provincias.size()]), "INFORMACIÓN: los tres datos del mapa de siempre (%d países, %d provincias, %d unidades)" % [paises.size(), n_prov, main.provincias.size()])
	ok(t.has("Las provincias son subdivisiones de los países; no se cuentan como países independientes."), "INFORMACIÓN: la nota de siempre")
	ok(t.has("Versión %s" % main.VERSION) and main.VERSION == "0.1.8.37a", "INFORMACIÓN: muestra la versión (%s)" % main.VERSION)
	ok(textos_botones(main.menu_contenido) == ["VOLVER"], "INFORMACIÓN: un botón VOLVER")
	boton(main.menu_contenido, "VOLVER").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["PANTALLA", "INFORMACIÓN", "VOLVER"], "VOLVER de INFORMACIÓN regresa a OPCIONES")
	# Pantalla
	boton(main.menu_contenido, "PANTALLA").pressed.emit()
	await esperar(0.1)
	var panel = null
	for h in main.menu_contenido.get_children():
		if h.get_script() == MenuPantallaScript:
			panel = h
	ok(panel != null, "PANTALLA: monta la ventana de ajustes de pantalla")
	t = []
	etiquetas(main.menu_contenido, t)
	ok(t.has("PANTALLA") and t.has("Modo de pantalla") and t.has("Resolución de la ventana") and t.has("Sincronización vertical (VSync)") and t.has("Límite de FPS") and t.has("Contador de FPS"), "PANTALLA: título y las filas de ajustes de la ventana")
	ok(t.has("Calidad") and t.has("Suavizado de bordes") and t.has("Mar") and t.has("Costas") and t.has("Líneas de provincia") and t.has("Ciudades") and t.has("Lagos") and t.has("Prioridad") and t.has("SIMULACIÓN") and t.has("GRÁFICOS DEL MAPA (más FPS en un PC flojo)"), "PANTALLA: las secciones y filas de gráficos del mapa y simulación")
	ok(main.panel_menu_nodo.custom_minimum_size.x >= 600.0, "PANTALLA: el panel se ensancha (%s)" % str(main.panel_menu_nodo.custom_minimum_size))
	ok(panel != null and panel.vigente["ancho"] == get_window().size.x, "PANTALLA: arranca con lo que tiene la ventana")
	# el aviso `aplicado` llega al mapa
	panel.aplicado.emit({"modo": 0, "sin_bordes": false, "ancho": 1280, "alto": 720, "vsync": 1, "fps_max": 0, "msaa": 1, "mostrar_fps": false})
	ok(not bool(main.ajustes["mostrar_fps"]), "lo aplicado en PANTALLA llega al mapa (main.ajustes)")
	main.fps_acum = 0.6
	main.fps_cuenta = 30
	main._actualizar_fps(0.0)
	ok(main.hud.lbl_fps.text == "v0.1.8.37a", "contador apagado: la esquina solo muestra la versión (%s)" % main.hud.lbl_fps.text)
	main.ajustes["mostrar_fps"] = true
	main.fps_acum = 0.6
	main.fps_cuenta = 29                                          # _actualizar_fps suma un fotograma: 30 / 0,6 s = 50 FPS
	main._actualizar_fps(0.0)
	ok(main.hud.lbl_fps.text == "v0.1.8.37a · 50 FPS", "contador encendido: versión y FPS (%s)" % main.hud.lbl_fps.text)
	panel.volver_pedido.emit()
	ok(textos_botones(main.menu_contenido) == ["PANTALLA", "INFORMACIÓN", "VOLVER"] and main.panel_menu_nodo.custom_minimum_size.x < 500.0, "VOLVER de PANTALLA regresa a OPCIONES con el panel estrecho")
	boton(main.menu_contenido, "VOLVER").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["JUGAR", "OPCIONES", "SALIR"], "VOLVER de OPCIONES regresa al menú principal")


# ───────────────────────── 0.1.8.33 · Verificar que la ventana cambió de verdad ─────────────────────────
func t_verificacion() -> void:
	print("[T] ── Ajustes: tamano_esperado, reforzar_ventana, discrepancia + aviso en MenuPantalla")
	var w := get_window()
	AjustesScript.aplicar(AjustesScript.por_defecto(), w)
	await esperar(0.4)
	var d := AjustesScript.por_defecto()
	ok(AjustesScript.tamano_esperado(d, w) == Vector2i(1280, 720), "tamano_esperado: 1280×720 cabe en la pantalla")
	var grande := AjustesScript.por_defecto()
	grande["ancho"] = 9000
	grande["alto"] = 9000
	var pant := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen(w.get_window_id()))
	ok(AjustesScript.tamano_esperado(grande, w) == pant, "tamano_esperado: un tamaño enorme se recorta a la pantalla (%s)" % str(pant))
	ok(AjustesScript.discrepancia(d, w) == "", "discrepancia: la ventana está como se pidió → texto vacío")
	var pedido := AjustesScript.por_defecto()
	pedido["ancho"] = 1024
	pedido["alto"] = 576
	var msg := AjustesScript.discrepancia(pedido, w)
	ok(msg.begins_with("AVISO") and msg.contains("1024 × 576") and msg.contains("1280 × 720") and msg.contains("editor de Godot"), "discrepancia: se pidió 1024×576 y sigue en 1280×720 → AVISO que dice los dos tamaños y menciona el editor")
	# reforzar_ventana: si el sistema pisó el tamaño, lo vuelve a poner
	w.size = Vector2i(1000, 600)
	await esperar(0.3)
	AjustesScript.reforzar_ventana(pedido, w)
	await esperar(0.4)
	ok(w.size == Vector2i(1024, 576) and AjustesScript.discrepancia(pedido, w) == "", "reforzar_ventana: tamaño pisado (1000×600) → vuelve a 1024×576")
	AjustesScript.reforzar_ventana(pedido, w)
	ok(w.size == Vector2i(1024, 576), "reforzar_ventana: con la ventana ya bien no cambia nada")
	ok(not AjustesScript.en_editor_incrustado() or Engine.has_method("is_embedded_in_editor"), "en_editor_incrustado: no falla (devuelve %s)" % str(AjustesScript.en_editor_incrustado()))
	AjustesScript.aplicar(AjustesScript.por_defecto(), w)
	await esperar(0.4)
	# MenuPantalla: tras APLICAR aparece una línea que dice lo que quedó aplicado
	borrar_temp()
	var p := nuevo_panel()
	ok(not p._lbl_estado.visible, "MenuPantalla: sin aplicar nada, la línea de estado está oculta")
	p.poner("fps_max", 60)
	p.aplicar_pendiente()
	ok(p._lbl_estado.visible and p._lbl_estado.text == "Aplicando…", "APLICAR: de inmediato dice «Aplicando…»")
	await esperar(0.5)
	ok(p._lbl_estado.text.begins_with("Aplicado:") and p._lbl_estado.text.contains("ventana 1280 × 720") and p._lbl_estado.text.contains("60 fps"), "…y al verificar dice «%s»" % p._lbl_estado.text)
	p.poner("ancho", 1024)
	p.poner("alto", 576)
	p.aplicar_pendiente()
	await esperar(0.6)
	ok(p.confirmando and w.size == Vector2i(1024, 576) and p._lbl_estado.text.contains("ventana 1024 × 576"), "cambio de tamaño: la ventana cambió y el estado lo confirma (%s)" % p._lbl_estado.text)
	ok(p._lbl_estado.is_visible_in_tree() or not p._cuerpo.visible, "…la línea de estado vive fuera del cuerpo: se ve también durante «¿Mantener?»")
	# una comprobación vieja no pisa a una nueva
	var gen: int = p._gen_verif
	p.revertir()
	ok(p._gen_verif == gen + 1, "REVERTIR lanza una comprobación nueva (la anterior queda anulada)")
	await esperar(0.6)
	ok(w.size == Vector2i(1280, 720) and p._lbl_estado.text.contains("ventana 1280 × 720"), "tras REVERTIR el estado dice «%s»" % p._lbl_estado.text)
	# cerrar el panel con la cuenta atrás en marcha (Esc en la pausa) revierte la ventana
	p.poner("ancho", 1024)
	p.poner("alto", 576)
	p.aplicar_pendiente()
	await esperar(0.4)
	ok(p.confirmando and w.size == Vector2i(1024, 576), "otra vez con confirmación pendiente (1024×576)")
	p.queue_free()
	await esperar(0.5)
	ok(w.size == Vector2i(1280, 720), "cerrar el panel con la cuenta atrás en marcha: la ventana vuelve a 1280×720 (%s)" % str(w.size))
	restaurar()
	await esperar(0.3)


# ───────────────────────── 0.1.8.33 · OPCIONES también en el menú de pausa ─────────────────────────
func t_pausa() -> void:
	print("[T] ── MapaPrincipal: menú de PAUSA → OPCIONES (PANTALLA / INFORMACIÓN) → VOLVER a la pausa")
	borrar_temp()
	var w := get_window()
	main.en_menu = false                                           # como si ya se estuviera jugando
	main._mostrar_menu_pausa()
	ok(main.en_pausa and get_tree().paused and is_instance_valid(main.menu_pausa), "Esc: el juego queda en pausa")
	ok(textos_botones(main.menu_contenido) == ["CONTINUAR", "OPCIONES", "DEBUG", "MENÚ PRINCIPAL", "SALIR"], "pausa: CONTINUAR, OPCIONES, DEBUG, MENÚ PRINCIPAL, SALIR (%s)" % str(textos_botones(main.menu_contenido)))
	var t: Array = []
	etiquetas(main.menu_contenido, t)
	ok(t.has("JUEGO EN PAUSA"), "pausa: título JUEGO EN PAUSA")
	boton(main.menu_contenido, "OPCIONES").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["PANTALLA", "INFORMACIÓN", "VOLVER"] and main.menu_pausa.is_ancestor_of(main.menu_contenido), "pausa > OPCIONES: PANTALLA, INFORMACIÓN, VOLVER dentro de la capa de pausa")
	# PANTALLA desde la pausa
	boton(main.menu_contenido, "PANTALLA").pressed.emit()
	await esperar(0.1)
	var panel = null
	for h in main.menu_contenido.get_children():
		if h.get_script() == MenuPantallaScript:
			panel = h
	ok(panel != null and main.menu_pausa.is_ancestor_of(panel), "pausa > OPCIONES > PANTALLA: monta la ventana de pantalla en la pausa")
	panel.ruta = TEMP
	panel.poner("fps_max", 120)
	panel.aplicar_pendiente()
	await esperar(0.4)
	ok(Engine.max_fps == 120 and int(main.ajustes["fps_max"]) == 120, "APLICAR desde la pausa (con el árbol en pausa): 120 FPS máx y llega a main.ajustes")
	ok(panel._lbl_estado.text.begins_with("Aplicado:"), "…y la comprobación corre también en pausa («%s»)" % panel._lbl_estado.text)
	panel.volver_pedido.emit()
	ok(textos_botones(main.menu_contenido) == ["PANTALLA", "INFORMACIÓN", "VOLVER"], "VOLVER de PANTALLA: a OPCIONES")
	# INFORMACIÓN desde la pausa
	boton(main.menu_contenido, "INFORMACIÓN").pressed.emit()
	t = []
	etiquetas(main.menu_contenido, t)
	ok(t.has("INFORMACIÓN") and t.has("Versión %s" % main.VERSION), "pausa > OPCIONES > INFORMACIÓN: muestra los datos y la versión")
	boton(main.menu_contenido, "VOLVER").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["PANTALLA", "INFORMACIÓN", "VOLVER"], "VOLVER de INFORMACIÓN: a OPCIONES")
	boton(main.menu_contenido, "VOLVER").pressed.emit()
	ok(textos_botones(main.menu_contenido) == ["CONTINUAR", "OPCIONES", "DEBUG", "MENÚ PRINCIPAL", "SALIR"] and main.en_pausa, "VOLVER de OPCIONES: regresa a la pausa (no al menú principal)")
	ok(not main.menu_contenido.get_children().is_empty() and main.panel_menu_nodo.custom_minimum_size.x < 500.0, "…con el panel estrecho otra vez")
	# Esc con la cuenta atrás de «¿Mantener?» en marcha: se reanuda y la ventana vuelve a lo de antes
	boton(main.menu_contenido, "OPCIONES").pressed.emit()
	boton(main.menu_contenido, "PANTALLA").pressed.emit()
	await esperar(0.1)
	panel = null
	for h in main.menu_contenido.get_children():
		if h.get_script() == MenuPantallaScript:
			panel = h
	panel.ruta = TEMP
	panel.poner("ancho", 1024)
	panel.poner("alto", 576)
	panel.aplicar_pendiente()
	await esperar(0.4)
	ok(panel.confirmando and w.size == Vector2i(1024, 576), "pausa > PANTALLA: cambio de tamaño con «¿Mantener?» en marcha (%s)" % str(w.size))
	main._reanudar_juego()                                         # lo que hace Esc
	await esperar(0.5)
	ok(not main.en_pausa and not get_tree().paused and main.menu_pausa == null, "Esc: se reanuda el juego")
	ok(w.size == Vector2i(1280, 720), "…y como no se confirmó, la ventana vuelve a 1280×720 (%s)" % str(w.size))
	# CONTINUAR desde la pausa
	main._mostrar_menu_pausa()
	boton(main.menu_contenido, "CONTINUAR").pressed.emit()
	ok(not main.en_pausa and not get_tree().paused, "CONTINUAR: reanuda")
	# MENÚ PRINCIPAL desde la pausa: el menú principal sigue teniendo OPCIONES y su VOLVER no va a la pausa
	main._mostrar_menu_pausa()
	boton(main.menu_contenido, "MENÚ PRINCIPAL").pressed.emit()
	await esperar(0.2)
	ok(main.en_menu and not main.en_pausa and not get_tree().paused, "MENÚ PRINCIPAL: se vuelve al menú de inicio")
	boton(main.menu_contenido, "OPCIONES").pressed.emit()
	boton(main.menu_contenido, "VOLVER").pressed.emit()
	ok(textos_botones(main.menu_contenido).has("OPCIONES") and not textos_botones(main.menu_contenido).has("DEBUG"), "menú principal > OPCIONES > VOLVER: regresa al menú principal (no a la pausa)")
	restaurar()
	await esperar(0.3)


# ───────────────────────── Gráficos: APLICAR guarda y avisa sin confirmar ─────────────────────────
func t_panel_graficos_aplicar() -> void:
	print("[T] ── MenuPantalla: APLICAR de los gráficos del mapa")
	borrar_temp()
	var p := nuevo_panel()
	var avisos: Array = []
	p.aplicado.connect(func(a: Dictionary): avisos.append(a))
	p.poner_calidad(2)
	p.poner("sim_prio", 0)
	p.aplicar_pendiente()
	ok(not p.confirmando and avisos.size() == 1, "APLICAR de gráficos: sin «¿Mantener?» y avisa con `aplicado`")
	var c := AjustesScript.cargar(TEMP)
	ok(int(c["mar"]) == 1 and int(c["costa"]) == 2 and not bool(c["lineas_prov"]) and not bool(c["lagos"]) and int(c["sim_prio"]) == 0, "…y guarda mar liso, costa baja, sin líneas ni lagos, prioridad fluidez")
	ok(int(avisos[0]["mar"]) == 1 and AjustesScript.iguales(p.vigente, p.pendiente) and p._btn_aplicar.disabled, "…lo vigente se actualiza y APLICAR se apaga")
	p.queue_free()
	await esperar(0.05)
	var p2 := nuevo_panel()                                    # un panel nuevo abre con lo ya aplicado de verdad
	p2.queue_free()
	await esperar(0.05)
	restaurar()


# ───────────────────────── Gráficos: efecto sobre el mapa ─────────────────────────
func t_calidad_mapa() -> void:
	print("[T] ── MapaPrincipal: _aplicar_calidad (mar, costas, líneas de provincia, ciudades, lagos, simulación)")
	var d := AjustesScript.por_defecto()
	ok(main.capa_mar != null and main.capa_mar.material == main.mat_mar and main.q_ciudades and main.q_lagos and main.q_lineas_prov and main.costa_nivel_min == 0 and main.presupuesto_us == 9000, "arranque con los valores por defecto: el mapa es el de siempre (mar con shader, todo activo, 9 ms)")
	var baja := AjustesScript.con_preset(d, 2)
	baja["sim_prio"] = 0
	main._aplicar_calidad(baja)
	ok(main.capa_mar.material == null and main.capa_mar.color.is_equal_approx(main.COLOR_MAR_LISO), "Baja: el mar pierde el shader y es un color liso")
	ok(main.costa_nivel_min == 2 and not main.q_lineas_prov and not main.q_lagos and main.q_ciudades and main.presupuesto_us == 4000, "Baja: costa mínima 2, sin líneas de provincia ni lagos, ciudades sí, simulación 4 ms")
	var lagos_ok := true
	for n in main.capa_lagos:
		if n.visible:
			lagos_ok = false
	ok(lagos_ok, "Baja: todas las capas de lagos ocultas (%d)" % main.capa_lagos.size())
	ok(main.costa_nivel == mini(2, main.capas_costa.size() - 1) or main.capas_costa.size() < 3, "Baja: se elige el detalle de costa más bajo que existe (nivel %d de %d)" % [main.costa_nivel, main.capas_costa.size()])
	var estaba_en_menu: bool = main.en_menu
	main.en_menu = false                                       # en el menú las ciudades nunca se ven: se prueba como en una partida
	main.camara.zoom = Vector2(4.0, 4.0)
	main._actualizar_zoom()
	main._actualizar_ciudades()
	ok(main.costa_nivel >= mini(2, main.capas_costa.size() - 1), "Baja: aun con mucho zoom la costa no vuelve al detalle alto (nivel %d)" % main.costa_nivel)
	ok(not main.capa_prov_todas.visible, "Baja: la capa de líneas de provincia está apagada aunque el zoom la pediría")
	var sin_ciu := AjustesScript.por_defecto()
	sin_ciu["ciudades"] = false
	main._aplicar_calidad(sin_ciu)
	main._actualizar_ciudades()
	ok(not main.ciudades_capas[0].visible, "sin ciudades: el contenedor de ciudades no se ve con zoom 4")
	main._aplicar_calidad(d)
	main._actualizar_ciudades()
	ok(main.capa_mar.material == main.mat_mar and main.capa_mar.color.is_equal_approx(Color.WHITE), "Alta: el mar recupera su shader y su color")
	ok(main.costa_nivel_min == 0 and main.q_lineas_prov and main.q_lagos and main.q_ciudades and main.presupuesto_us == 9000, "Alta: todo vuelve a como estaba")
	ok(main.ciudades_capas[0].visible, "Alta: con zoom 4 las ciudades se ven otra vez")
	var lagos_vuelven: bool = main.capa_lagos.is_empty()
	for n in main.capa_lagos:
		if n.visible:
			lagos_vuelven = true
	ok(lagos_vuelven, "Alta: los lagos vuelven")
	main.camara.zoom = Vector2(1.0, 1.0)
	main._actualizar_zoom()
	main.en_menu = estaba_en_menu
	var alta_prio := AjustesScript.por_defecto()
	alta_prio["sim_prio"] = 2
	main._aplicar_calidad(alta_prio)
	ok(main.presupuesto_us == 14000, "prioridad «velocidad del tiempo»: la simulación puede gastar 14 ms por fotograma")
	main._aplicar_calidad(d)
	# el mismo ajuste guardado en disco llega al mapa
	borrar_temp()
	AjustesScript.guardar(AjustesScript.con_preset(d, 1), TEMP)
	main._cargar_ajustes(TEMP)
	main._aplicar_calidad(main.ajustes)
	await esperar(0.4)
	ok(main.costa_nivel_min == 1 and not main.q_lagos and main.q_ciudades and main.capa_mar.material == main.mat_mar, "archivo con calidad Media → _cargar_ajustes + _aplicar_calidad: costa media, sin lagos, mar con shader")
	restaurar()
	await esperar(0.4)
	main._cargar_ajustes(TEMP)
	main._aplicar_calidad(main.ajustes)
	ok(main.costa_nivel_min == 0 and main.q_lagos and main.presupuesto_us == 9000, "tras restaurar, el mapa vuelve a calidad Alta")


# ───────────────────────── MapaPrincipal: cargar ajustes al arrancar ─────────────────────────
func t_arranque() -> void:
	print("[T] ── MapaPrincipal: _cargar_ajustes")
	borrar_temp()
	var w := get_window()
	ok(not AjustesScript.existe(), "sin archivo de ajustes real en la carpeta del usuario (las pruebas usan otro)")
	main._cargar_ajustes(TEMP)
	ok(int(main.ajustes["ancho"]) == w.size.x and int(main.ajustes["fps_max"]) == Engine.max_fps and Engine.max_fps == 0, "sin archivo: los ajustes son lo que tiene la ventana y no se toca nada")
	AjustesScript.guardar({"modo": 0, "ancho": 1024, "alto": 576, "vsync": 0, "fps_max": 90, "msaa": 0, "mostrar_fps": false}, TEMP)
	main._cargar_ajustes(TEMP)
	await esperar(0.4)
	ok(Engine.max_fps == 90 and int(w.msaa_2d) == 0 and w.size == Vector2i(1024, 576), "con archivo: se aplican 90 FPS, sin suavizado y 1024×576 (%d, %d, %s)" % [Engine.max_fps, int(w.msaa_2d), str(w.size)])
	ok(int(main.ajustes["fps_max"]) == 90 and not bool(main.ajustes["mostrar_fps"]), "con archivo: main.ajustes guarda lo leído")
	restaurar()
	await esperar(0.4)
	main._cargar_ajustes(TEMP)
	ok(w.size == Vector2i(1280, 720) and Engine.max_fps == 0 and bool(main.ajustes["mostrar_fps"]), "tras restaurar: ventana 1280×720, sin límite y contador visible")


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.3)
	t_sanear()
	t_graficos()
	t_guardar()
	t_listas()
	await t_ventana()
	await t_panel_controles()
	await t_panel_aplicar()
	await t_panel_graficos_aplicar()
	await t_calidad_mapa()
	await t_menu()
	await t_verificacion()
	await t_pausa()
	await t_arranque()
	restaurar()
	print("[T] ── %d comprobaciones OK · FALLOS: %d" % [n_ok, fallos])
	get_tree().quit()
