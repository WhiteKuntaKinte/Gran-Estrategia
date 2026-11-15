extends Node
## 0.1.8.44 · REGISTRO DE FALLOS: deja rastro en archivos para saber QUÉ pasó cuando el juego se cierra solo o se traba.
## Dos capas (carpeta de datos del usuario, `user://logs/`):
##  1. El registro de Godot (`godot.log`, se enciende en `project.godot`): todo lo que el juego imprime y cada error de script o del motor, con su traza.
##  2. Este módulo: `sesion.txt` (la sesión en curso: equipo, versión y una línea de estado cada pocos segundos: pantalla, fecha del juego, FPS, memoria, nodos) y
##     `cierre_inesperado_AAAAMMDD_HHMMSS.txt` (la copia de la sesión anterior cuando NO terminó con «CIERRE LIMPIO»: es decir, cuando el juego se cayó o lo mató el sistema).
## · Vive en la raíz como el grabador de rendimiento: sobrevive al menú y a «Nueva partida».
## · Costo: una línea de texto cada 5 s (cada 30 s pasada la primera hora) y los avisos de `anotar`. Nada por fotograma.
## · Se guardan como máximo MAX_INESPERADOS copias; se borran las más viejas.

const CARPETA := "user://logs/"
const ARCHIVO := "user://logs/sesion.txt"
const NOMBRE_NODO := "RegistroFallos"
const MAX_INESPERADOS := 6
const CADA_S := 5.0
const CADA_LENTO_S := 30.0
const LINEAS_RAPIDAS := 720                    # la primera hora (720 × 5 s) se anota cada 5 s; después, cada 30 s
const MARCA_LIMPIO := "CIERRE LIMPIO"

var main
var version_juego := ""
var ruta_inesperado := ""                      # copia de la sesión anterior si esa terminó mal (vacío si terminó bien o no había)
var lineas := 0
var _f: FileAccess
var _acum := 0.0
var _limpio := false
var _t0_ms := 0


## El registro único del programa: si ya existe en la raíz lo reutiliza (y lo enlaza a esta partida); si no, lo crea.
static func obtener(m: Node) -> Node:
	var raiz := m.get_tree().root
	var g := raiz.get_node_or_null(NOMBRE_NODO)
	if g == null:
		g = new()
		g.name = NOMBRE_NODO
		raiz.add_child.call_deferred(g)
	g.construir(m)
	return g


func construir(m: Node) -> void:
	main = m
	version_juego = String(m.VERSION)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_t0_ms = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	_revisar_sesion_anterior()
	_f = FileAccess.open(ARCHIVO, FileAccess.WRITE)
	if _f == null:
		push_warning("RegistroFallos: no se pudo abrir %s" % ARCHIVO)
		set_process(false)
		return
	_f.store_line("SESIÓN %s · juego v%s" % [_sello(), version_juego])
	_f.store_line(texto_equipo())
	if ruta_inesperado != "":
		_f.store_line("AVISO: la sesión anterior no terminó con «%s». Su copia quedó en %s" % [MARCA_LIMPIO, ruta_inesperado])
	_f.flush()


## Antes de empezar de nuevo: si la sesión anterior no tiene la marca de cierre limpio, se guarda aparte.
func _revisar_sesion_anterior() -> void:
	ruta_inesperado = ""
	if not FileAccess.file_exists(ARCHIVO):
		return
	var previo := FileAccess.get_file_as_string(ARCHIVO)
	if previo.strip_edges() == "" or previo.contains(MARCA_LIMPIO):
		return
	ruta_inesperado = CARPETA + "cierre_inesperado_%s.txt" % _sello()
	var f := FileAccess.open(ruta_inesperado, FileAccess.WRITE)
	if f != null:
		f.store_string(previo)
		f.close()
	else:
		ruta_inesperado = ""
		return
	_podar()


## Deja solo las MAX_INESPERADOS copias más recientes (el nombre lleva la fecha: el orden alfabético es el cronológico).
func _podar() -> void:
	var nombres: Array = []
	for n in DirAccess.get_files_at(CARPETA):
		if n.begins_with("cierre_inesperado_") and n.ends_with(".txt"):
			nombres.append(n)
	nombres.sort()
	while nombres.size() > MAX_INESPERADOS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CARPETA + String(nombres.pop_front())))


func _sello() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]


## El equipo y el motor en tres líneas (sirve para entender fallos de un equipo concreto).
func texto_equipo() -> String:
	var mem := OS.get_memory_info()
	var t := "GPU: %s (%s) · API %s\n" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()]
	t += "Sistema: %s · Godot %s · render %s · CPU %d hilos · RAM %d MB\n" % [OS.get_name(), String(Engine.get_version_info()["string"]),
		String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")), OS.get_processor_count(), int(int(mem.get("physical", 0)) / 1048576)]
	t += "Pantalla %d×%d · ventana %d×%d" % [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y, get_window().size.x if is_inside_tree() else 0, get_window().size.y if is_inside_tree() else 0]
	return t


## La línea de estado: dónde está el jugador y cuánto pesa el juego en este instante.
func linea_estado() -> String:
	var donde := "?"
	var fecha := "-"
	var vel := -1
	if main != null and is_instance_valid(main):
		donde = "menú" if bool(main.get("en_menu")) else "partida"
		var r = main.get("reloj")
		if r != null:
			fecha = "%d-%02d-%02d" % [int(r.anio), int(r.mes), int(r.dia)]
			vel = int(r.velocidad)
		var pd = main.get("panel_descubrimientos")
		if pd != null and is_instance_valid(pd):
			donde += "+descubrimientos"
	return "t=%ds %s fecha=%s vel=%d fps=%d mem=%dMB video=%dMB nodos=%d objetos=%d" % [
		int((Time.get_ticks_msec() - _t0_ms) / 1000), donde, fecha, vel, int(Engine.get_frames_per_second()),
		int(float(OS.get_static_memory_usage()) / 1048576.0), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT))]


## Anota algo importante (abrir una pantalla, cambiar de calidad, empezar una partida…). Sale con la hora de la sesión.
func anotar(texto: String) -> void:
	if _f == null or _limpio:
		return
	_f.store_line("[%ds] %s" % [int((Time.get_ticks_msec() - _t0_ms) / 1000), texto])
	_f.flush()


func _process(delta: float) -> void:
	if _f == null or _limpio:
		return
	_acum += delta
	if _acum < (CADA_S if lineas < LINEAS_RAPIDAS else CADA_LENTO_S):
		return
	_acum = 0.0
	lineas += 1
	_f.store_line(linea_estado())
	_f.flush()


## Terminar bien: se anota la marca que distingue un cierre normal de una caída.
func cerrar_limpio() -> void:
	if _f == null or _limpio:
		return
	_limpio = true
	_f.store_line("[%ds] %s" % [int((Time.get_ticks_msec() - _t0_ms) / 1000), MARCA_LIMPIO])
	_f.flush()
	_f.close()
	_f = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		cerrar_limpio()


func _exit_tree() -> void:
	cerrar_limpio()
