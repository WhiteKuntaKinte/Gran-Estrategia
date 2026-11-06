extends RefCounted
## Ajustes de pantalla y gráficos (0.1.8.31): qué opciones hay, qué valores son válidos, cómo se guardan en disco y cómo se aplican a la ventana.
## Un ajuste es un Dictionary con estas claves:
##   modo         0 = ventana, 1 = pantalla completa
##   sin_bordes   true = la ventana no tiene barra de título (solo en modo ventana)
##   ancho, alto  tamaño de la ventana en píxeles (solo modo ventana)
##   ancho_fs, alto_fs  0.1.8.35 · resolución INTERNA en pantalla completa (0 y 0 = la de la pantalla). La ventana ocupa toda la pantalla, pero el juego
##                se dibuja a esta resolución y se estira: menos píxeles que pintar = más FPS en un PC flojo
##   vsync        0 = desactivado, 1 = activado, 2 = adaptativo
##   fps_max      0 = sin límite; si no, FPS máximos
##   msaa         suavizado de bordes del mapa: 0 = ninguno, 1 = 2x, 2 = 4x
##   mostrar_fps  true = la esquina muestra los FPS además de la versión
## 0.1.8.32 · Gráficos del mapa (lo que de verdad sube los FPS en un PC flojo):
##   mar          0 = con profundidad (batimetría, un shader por píxel de mar), 1 = color liso
##   costa        0 = costa detallada al acercar, 1 = detalle medio siempre, 2 = detalle bajo siempre (menos triángulos)
##   lineas_prov  true = en la campaña se dibujan las líneas de provincia de todos los países al acercar
##   ciudades     true = marcadores y nombres de ciudades al acercar
##   lagos        true = se dibujan los lagos
##   sim_prio     0 = fluidez (la simulación gasta como mucho 4 ms por fotograma), 1 = equilibrada (9 ms), 2 = velocidad del tiempo (14 ms)
## Todo lo que no toca la ventana real (valores por defecto, validación, listas, textos) es lógica pura y está probado en runner74.

const RUTA := "user://ajustes.cfg"
const SECCION := "pantalla"

const MODO_VENTANA := 0
const MODO_COMPLETA := 1
const MODOS := ["Ventana", "Pantalla completa"]
const VSYNC_NOMBRES := ["Desactivado", "Activado", "Adaptativo"]
const MSAA_NOMBRES := ["Sin suavizado", "Suavizado 2x", "Suavizado 4x"]
const FPS_OPCIONES := [0, 30, 60, 75, 90, 120, 144, 165, 240]
const RESOLUCIONES := [Vector2i(1024, 576), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const MAR_NOMBRES := ["Con profundidad", "Color liso (más rápido)"]
const COSTA_NOMBRES := ["Detallada", "Detalle medio", "Detalle bajo (más rápido)"]
const SIM_NOMBRES := ["Fluidez (el tiempo puede ir más lento)", "Equilibrada", "Velocidad del tiempo"]
const SIM_PRESUPUESTO_US := [4000, 9000, 14000]                  # microsegundos por fotograma que gasta la simulación de días, según `sim_prio`
const PRESETS_NOMBRES := ["Alta", "Media", "Baja", "Personalizada"]
const PRESET_PERSONALIZADA := 3
## Qué valores fija cada calidad (la de por defecto es «Alta»: el juego como siempre). Todo lo demás (resolución, VSync, FPS...) no entra.
const PRESETS := [
	{"mar": 0, "costa": 0, "lineas_prov": true, "ciudades": true, "lagos": true, "msaa": 1},
	{"mar": 0, "costa": 1, "lineas_prov": true, "ciudades": true, "lagos": false, "msaa": 0},
	{"mar": 1, "costa": 2, "lineas_prov": false, "ciudades": true, "lagos": false, "msaa": 0},
]
const BASE_PROYECTO := Vector2i(1280, 720)                       # display/window/size del proyecto: la base de la escala «canvas_items»
const TAM_MIN := Vector2i(640, 360)
const TAM_MAX := Vector2i(7680, 4320)


## Lo que se usa si no hay nada guardado: ventana de 1280×720, VSync y suavizado 2x como trae el proyecto, FPS visibles.
static func por_defecto() -> Dictionary:
	return {"modo": MODO_VENTANA, "sin_bordes": false, "ancho": 1280, "alto": 720, "ancho_fs": 0, "alto_fs": 0, "vsync": 1, "fps_max": 0, "msaa": 1, "mostrar_fps": true,
		"mar": 0, "costa": 0, "lineas_prov": true, "ciudades": true, "lagos": true, "sim_prio": 1}


## Devuelve un ajuste completo y válido a partir de cualquier Dictionary: lo que falta o viene roto (un archivo editado a mano, una versión
## vieja) se sustituye por el valor por defecto de esa clave; los tamaños se acotan a TAM_MIN..TAM_MAX.
static func sanear(d: Dictionary) -> Dictionary:
	var r := por_defecto()
	r["modo"] = _entero_en(d.get("modo", null), [MODO_VENTANA, MODO_COMPLETA], int(r["modo"]))
	r["vsync"] = _entero_en(d.get("vsync", null), [0, 1, 2], int(r["vsync"]))
	r["msaa"] = _entero_en(d.get("msaa", null), [0, 1, 2], int(r["msaa"]))
	r["fps_max"] = _entero_en(d.get("fps_max", null), FPS_OPCIONES, int(r["fps_max"]))
	r["mar"] = _entero_en(d.get("mar", null), [0, 1], int(r["mar"]))
	r["costa"] = _entero_en(d.get("costa", null), [0, 1, 2], int(r["costa"]))
	r["sim_prio"] = _entero_en(d.get("sim_prio", null), [0, 1, 2], int(r["sim_prio"]))
	r["ancho"] = _entero_acotado(d.get("ancho", null), TAM_MIN.x, TAM_MAX.x, int(r["ancho"]))
	r["alto"] = _entero_acotado(d.get("alto", null), TAM_MIN.y, TAM_MAX.y, int(r["alto"]))
	var fs := _res_interna(d.get("ancho_fs", null), d.get("alto_fs", null))
	r["ancho_fs"] = fs.x
	r["alto_fs"] = fs.y
	for k in ["sin_bordes", "mostrar_fps", "lineas_prov", "ciudades", "lagos"]:
		var v: Variant = d.get(k, null)
		r[k] = bool(v) if v is bool else bool(r[k])
	return r


## Resolución interna válida: (0, 0) = nativa; si no, ambos números dentro de TAM_MIN..TAM_MAX (un solo valor roto o un tamaño absurdo = nativa).
static func _res_interna(a: Variant, b: Variant) -> Vector2i:
	if (a is int or a is float) and (b is int or b is float) and int(a) >= TAM_MIN.x and int(b) >= TAM_MIN.y:
		return Vector2i(clampi(int(a), TAM_MIN.x, TAM_MAX.x), clampi(int(b), TAM_MIN.y, TAM_MAX.y))
	return Vector2i.ZERO


## `v` como entero si es un número entero (o decimal sin parte fraccionaria) que está en `validos`; si no, `defecto`.
static func _entero_en(v: Variant, validos: Array, defecto: int) -> int:
	if (v is int or v is float) and is_equal_approx(float(v), roundf(float(v))) and validos.has(int(v)):
		return int(v)
	return defecto


## `v` como entero dentro de [minimo, maximo] si es un número; si no es un número, `defecto`.
static func _entero_acotado(v: Variant, minimo: int, maximo: int, defecto: int) -> int:
	if v is int or v is float:
		return clampi(int(v), minimo, maximo)
	return defecto


## ¿Dos ajustes valen lo mismo? (compara clave por clave, ya saneados)
static func iguales(a: Dictionary, b: Dictionary) -> bool:
	var sa := sanear(a)
	var sb := sanear(b)
	for k in sa.keys():
		if sa[k] != sb[k]:
			return false
	return true


## Qué calidad es `d`: 0 Alta, 1 Media, 2 Baja, o PRESET_PERSONALIZADA si sus valores gráficos no coinciden con ninguna.
static func preset_de(d: Dictionary) -> int:
	var a := sanear(d)
	for i in PRESETS.size():
		var coincide := true
		for k in PRESETS[i].keys():
			if a[k] != PRESETS[i][k]:
				coincide = false
				break
		if coincide:
			return i
	return PRESET_PERSONALIZADA


## `d` con los valores gráficos de la calidad `i` (0..2); cualquier otro índice lo deja igual (saneado).
static func con_preset(d: Dictionary, i: int) -> Dictionary:
	var a := sanear(d)
	if i >= 0 and i < PRESETS.size():
		for k in PRESETS[i].keys():
			a[k] = PRESETS[i][k]
	return a


## Microsegundos por fotograma que puede gastar la simulación de días con el ajuste `sim_prio` de `d`.
static func presupuesto_sim_us(d: Dictionary) -> int:
	return int(SIM_PRESUPUESTO_US[int(sanear(d)["sim_prio"])])


## ¿Hay un archivo de ajustes guardado? Sin archivo, el juego arranca como siempre y no toca la ventana.
static func existe(ruta := RUTA) -> bool:
	return FileAccess.file_exists(ruta)


## Lee los ajustes guardados (siempre devuelve un ajuste válido; un archivo ausente o ilegible da los de por defecto).
static func cargar(ruta := RUTA) -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(ruta) != OK:
		return por_defecto()
	var crudo := {}
	for k in por_defecto().keys():
		if cf.has_section_key(SECCION, k):                      # (get_value con un valor ausente escribe un error en la consola)
			crudo[k] = cf.get_value(SECCION, k)
	return sanear(crudo)


## Guarda un ajuste (ya saneado) en disco. Devuelve OK o el código de error de Godot.
static func guardar(d: Dictionary, ruta := RUTA) -> int:
	var cf := ConfigFile.new()
	var a := sanear(d)
	for k in a.keys():
		cf.set_value(SECCION, k, a[k])
	return cf.save(ruta)


## Resoluciones de ventana que caben en la pantalla `pantalla`, de menor a mayor. Si el tamaño `actual` de la ventana no está
## entre ellas (por ejemplo, la arrastraste con el ratón), se añade para que el desplegable lo muestre tal cual.
static func resoluciones_para(pantalla: Vector2i, actual: Vector2i) -> Array:
	var r: Array = []
	for v in RESOLUCIONES:
		if v.x <= pantalla.x and v.y <= pantalla.y:
			r.append(v)
	if r.is_empty():
		r.append(pantalla)                                      # pantalla más pequeña que la mínima de la lista
	if not r.has(actual) and actual.x >= TAM_MIN.x and actual.y >= TAM_MIN.y:
		r.append(actual)
	r.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x * a.y < b.x * b.y or (a.x * a.y == b.x * b.y and a.x < b.x))
	return r


## «1920 × 1080» para el desplegable.
static func texto_resolucion(v: Vector2i) -> String:
	return "%d × %d" % [v.x, v.y]


## «Sin límite» o «60 FPS» para el desplegable.
static func texto_fps(n: int) -> String:
	return "Sin límite" if n <= 0 else "%d FPS" % n


## Esquina superior izquierda para centrar una ventana de tamaño `tam` en el área `area` (nunca por fuera de la esquina del área).
static func posicion_centrada(area: Rect2i, tam: Vector2i) -> Vector2i:
	return area.position + Vector2i(maxi((area.size.x - tam.x) / 2, 0), maxi((area.size.y - tam.y) / 2, 0))


## `tam` recortado para que no sea mayor que la pantalla (un ajuste guardado en otro monitor más grande no deja la ventana fuera de la pantalla).
## Si no se conoce el tamaño de la pantalla (0 o negativo, como en el modo sin ventana), no se recorta.
static func limitar_a_pantalla(tam: Vector2i, pantalla: Vector2i) -> Vector2i:
	if pantalla.x <= 0 or pantalla.y <= 0:
		return tam
	return Vector2i(clampi(tam.x, TAM_MIN.x, maxi(pantalla.x, TAM_MIN.x)), clampi(tam.y, TAM_MIN.y, maxi(pantalla.y, TAM_MIN.y)))


## ¿El cambio de `antes` a `despues` mueve o redimensiona la ventana? Entonces hay que pedirle al jugador que lo confirme
## (si la imagen sale mal, a los segundos se vuelve sola a lo anterior). En pantalla completa el tamaño no cuenta.
static func requiere_confirmacion(antes: Dictionary, despues: Dictionary) -> bool:
	if int(antes["modo"]) != int(despues["modo"]):
		return true
	if int(despues["modo"]) == MODO_COMPLETA:
		return false
	return bool(antes["sin_bordes"]) != bool(despues["sin_bordes"]) or int(antes["ancho"]) != int(despues["ancho"]) or int(antes["alto"]) != int(despues["alto"])


## Lo que la ventana tiene AHORA (puede haber cambiado por el sistema: maximizar, arrastrar el borde, Alt+Enter).
## `previo`: el último ajuste conocido. Si se da, de él salen todo lo que no es la forma de la ventana (VSync, FPS, suavizado, contador:
## solo cambian desde Opciones) y el tamaño de ventana cuando estamos en pantalla completa (ahí el tamaño de la ventana es el de la
## pantalla y no sirve para volver a modo ventana). Si no se da, VSync, FPS y suavizado se leen del motor (primera vez, sin archivo).
static func leer_actual(ventana: Window, previo := {}) -> Dictionary:
	var r := sanear(previo)
	if previo.is_empty():
		var vs := int(DisplayServer.window_get_vsync_mode())
		r["vsync"] = vs if vs >= 0 and vs <= 2 else 1               # «mailbox» (3) se muestra como activado
		r["fps_max"] = Engine.max_fps
		r["msaa"] = int(ventana.msaa_2d)
	var completa := ventana.mode == Window.MODE_FULLSCREEN or ventana.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	r["modo"] = MODO_COMPLETA if completa else MODO_VENTANA
	if not completa:
		r["sin_bordes"] = ventana.borderless
		r["ancho"] = ventana.size.x
		r["alto"] = ventana.size.y
	return sanear(r)


## Aplica un ajuste a la ventana real. El orden importa: primero se sale de pantalla completa y luego se cambia el tamaño.
static func aplicar(d: Dictionary, ventana: Window) -> void:
	var a := sanear(d)
	DisplayServer.window_set_vsync_mode(int(a["vsync"]) as DisplayServer.VSyncMode)
	Engine.max_fps = int(a["fps_max"])
	ventana.msaa_2d = int(a["msaa"]) as Viewport.MSAA
	aplicar_escala(a, ventana)
	if int(a["modo"]) == MODO_COMPLETA:
		ventana.mode = Window.MODE_FULLSCREEN
		return
	if ventana.mode != Window.MODE_WINDOWED:
		ventana.mode = Window.MODE_WINDOWED
	ventana.borderless = bool(a["sin_bordes"])
	var pantalla := DisplayServer.window_get_current_screen(ventana.get_window_id())
	ventana.size = limitar_a_pantalla(Vector2i(int(a["ancho"]), int(a["alto"])), DisplayServer.screen_get_size(pantalla))
	ventana.position = posicion_centrada(DisplayServer.screen_get_usable_rect(pantalla), ventana.size)


## 0.1.8.35 · Resolución interna en pantalla completa. Con una resolución propia (ancho_fs × alto_fs) la ventana pasa al modo «viewport» del motor: todo el juego
## (mapa y menús) se dibuja en una imagen de ese tamaño que la pantalla estira; con (0, 0), o en modo ventana, vuelve a lo del proyecto (el tamaño de la
## ventana manda: modo «canvas_items» con base 1280×720). Devuelve true si dejó la escala interna activa.
static func aplicar_escala(d: Dictionary, ventana: Window) -> bool:
	var a := sanear(d)
	var tam := interna_pedida(a)
	if tam != Vector2i.ZERO:
		ventana.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		ventana.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		ventana.content_scale_size = tam
		return true
	ventana.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	ventana.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	ventana.content_scale_size = BASE_PROYECTO
	return false


## Resolución interna que pide el ajuste `a`: Vector2i.ZERO si la pantalla se usa a su resolución (modo ventana, o pantalla completa «Nativa»).
static func interna_pedida(a: Dictionary) -> Vector2i:
	var c := sanear(a)
	if int(c["modo"]) != MODO_COMPLETA:
		return Vector2i.ZERO
	return Vector2i(int(c["ancho_fs"]), int(c["alto_fs"]))


## Resoluciones internas que ofrece el desplegable en pantalla completa: las de la lista que son menores que la pantalla, y la de la pantalla (nativa) la primera.
## `actual` = lo que hay guardado (si no está en la lista y es válido, se añade). Devuelve Vector2i; (0, 0) es «Nativa».
static func resoluciones_internas(pantalla: Vector2i, actual: Vector2i) -> Array:
	var r: Array = [Vector2i.ZERO]
	for v in RESOLUCIONES:
		if v.x < pantalla.x and v.y <= pantalla.y:
			r.append(v)
	if actual != Vector2i.ZERO and not r.has(actual) and actual.x >= TAM_MIN.x and actual.y >= TAM_MIN.y:
		r.append(actual)
	return r


## «Nativa (1920 × 1080)» o «1280 × 720» para el desplegable de pantalla completa.
static func texto_res_interna(v: Vector2i, pantalla: Vector2i) -> String:
	return "Nativa (%s)" % texto_resolucion(pantalla) if v == Vector2i.ZERO else texto_resolucion(v)


## 0.1.8.33 · Tamaño que debería tener la ventana real tras aplicar `a` (el pedido, recortado a la pantalla donde está la ventana).
static func tamano_esperado(a: Dictionary, ventana: Window) -> Vector2i:
	var c := sanear(a)
	var pantalla := DisplayServer.window_get_current_screen(ventana.get_window_id())
	return limitar_a_pantalla(Vector2i(int(c["ancho"]), int(c["alto"])), DisplayServer.screen_get_size(pantalla))


## Vuelve a fijar modo, tamaño y posición. Algunos sistemas (Windows al salir de «maximizada», por ejemplo) restauran el tamaño anterior un
## instante DESPUÉS de cambiar el modo y pisan el tamaño pedido: por eso `MenuPantalla` lo repite un par de fotogramas más tarde.
static func reforzar_ventana(d: Dictionary, ventana: Window) -> void:
	var a := sanear(d)
	aplicar_escala(a, ventana)
	if int(a["modo"]) == MODO_COMPLETA:
		if ventana.mode != Window.MODE_FULLSCREEN:
			ventana.mode = Window.MODE_FULLSCREEN
		return
	if ventana.mode != Window.MODE_WINDOWED:
		ventana.mode = Window.MODE_WINDOWED
	var pantalla := DisplayServer.window_get_current_screen(ventana.get_window_id())
	var tam := tamano_esperado(a, ventana)
	if ventana.size != tam:
		ventana.size = tam
		ventana.position = posicion_centrada(DisplayServer.screen_get_usable_rect(pantalla), tam)


## ¿El juego corre incrustado en el editor de Godot (4.4+)? Ahí la ventana es del editor y el juego no puede cambiarla. Falso si el motor no lo sabe decir.
static func en_editor_incrustado() -> bool:
	return Engine.has_method("is_embedded_in_editor") and bool(Engine.call("is_embedded_in_editor"))


## ¿La ventana real quedó como se pidió? Devuelve "" si sí, o una frase que explica qué no se pudo (y por qué puede ser).
static func discrepancia(d: Dictionary, ventana: Window) -> String:
	var a := sanear(d)
	var ayuda := " Estás jugando dentro del editor de Godot: ahí la ventana es del editor (pestaña «Juego»: desactiva «Embed Game on Next Start»); en el juego exportado sí funciona." if en_editor_incrustado() \
		else " Si juegas desde el editor de Godot, ahí la ventana la controla el editor (pestaña «Juego»: desactiva «Embed Game on Next Start»); en el juego exportado sí funciona."
	if int(a["modo"]) == MODO_COMPLETA:
		if ventana.mode != Window.MODE_FULLSCREEN and ventana.mode != Window.MODE_EXCLUSIVE_FULLSCREEN:
			return "AVISO: no se pudo pasar a pantalla completa." + ayuda
		return ""
	var pedido := tamano_esperado(a, ventana)
	if ventana.size != pedido:
		return "AVISO: la ventana no cambió de tamaño (se pidió %s y sigue en %s)." % [texto_resolucion(pedido), texto_resolucion(ventana.size)] + ayuda
	return ""
