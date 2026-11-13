extends Node
## 0.1.8.39 · GRABADOR DE RENDIMIENTO: anota, fotograma a fotograma, cuánto tarda el juego mientras juegas de verdad (zoom, arrastre, tiempo corriendo...) y lo
## guarda en un archivo CSV que se puede mandar para ver QUÉ se atasca en tu equipo (la «Prueba de zoom» del Debug mide un recorrido fijo; esto mide lo que haces).
## · Se enciende y apaga desde Debug > Rendimiento o con la tecla F9 (con el Debug cerrado el grabador no pesa nada: solo guarda un par de números por fotograma).
## · Archivos (carpeta de datos del usuario, `user://rendimiento/`): `rend_AAAAMMDD_HHMMSS.csv` (una fila por fotograma) y `…_resumen.txt` (lo que importa:
##   FPS medios, peores fotogramas, tirones por zoom y por vista). El resumen también queda en el portapapeles para pegarlo en el chat.
## · Columnas del CSV: t_s, dt_ms (lo que duró el fotograma), proceso_ms (todo el _process de Godot), render_cpu_ms y render_gpu_ms (si el equipo los da),
##   draws, tri (triángulos), objetos, mem_video_mb, mem_tex_mb, zoom, cam_x, cam_y, vista, foco, velocidad, ms_zoom, ms_scripts_mapa, ms_ciudades, ms_tropas, marca.
## · F8 pone una MARCA en el archivo (por ejemplo antes de hacer zoom): la fila siguiente la lleva y el resumen las lista con su contexto.
## 0.1.8.42 · El grabador es GLOBAL: vive en la raíz del juego, no dentro de la partida. Sigue grabando en el menú principal, en la pausa, al cargar una «Nueva partida»
##   (que recarga la escena) y al cambiar de ajustes; si cierras el juego mientras graba, guarda el resumen al salir. Un «● REC» rojo arriba a la derecha avisa en todas
##   las pantallas. Se ponen marcas solas al cambiar de calidad, de vista, de menú a partida y al empezar una partida nueva.

signal terminado(ruta: String, resumen: String)

const CARPETA := "user://rendimiento/"
const MAX_FILAS := 216000                       # una hora a 60 fotogramas por segundo: más allá se detiene solo (para no llenar la memoria)
const UMBRAL_TIRON_MS := 50.0                   # un fotograma que dura más que esto es un «tirón» (menos de 20 FPS en ese instante)
const BANDAS_ZOOM := [[0.0, 1.0], [1.0, 2.0], [2.0, 4.0], [4.0, 8.0], [8.0, 99.0]]
const NOMBRE_NODO := "GrabadorRendimiento"
const VISTAS := ["tradicional", "relieve", "menu", "carga"]       # «menu» = menú principal · «carga» = mientras se recarga la escena (Nueva partida)
const CABECERA := "t_s,dt_ms,proceso_ms,render_cpu_ms,render_gpu_ms,draws,tri,objetos,mem_video_mb,mem_tex_mb,zoom,cam_x,cam_y,vista,foco,velocidad,ms_zoom,ms_scripts_mapa,ms_ciudades,ms_tropas,marca"

var main
var grabando := false
var version_juego := ""                         # la versión del juego (se guarda al enlazar: al salir ya no hay juego al que preguntar)
var equipo := ""                                # «Equipo y ajustes» al enlazar o iniciar (idem)
var indicador: CanvasLayer                      # el «● REC» de arriba a la derecha
var lbl_rec: Label
var ultimo_archivo := ""                        # ruta del último CSV guardado
var ultimo_resumen := ""                        # texto del último resumen
var n_filas := 0
var _t0_us := 0
var _f: FileAccess
var _ruta := ""
var _dts: PackedFloat32Array = PackedFloat32Array()
var _zooms: PackedFloat32Array = PackedFloat32Array()
var _vistas: PackedStringArray = PackedStringArray()
var _tiempos: PackedFloat32Array = PackedFloat32Array()
var _draws: PackedInt32Array = PackedInt32Array()
var _tris: PackedInt32Array = PackedInt32Array()
var _marcas: Array = []                         # [fila, texto]
var _marca_pend := ""
var _ult_flush_us := 0
var _ms_ciud_ant := 0.0
var _vp: RID
var _mide_render := false


## El grabador único del programa: si ya existe en la raíz lo reutiliza (y lo enlaza a esta partida); si no, lo crea. Sobrevive a «Nueva partida».
static func obtener(m: Node) -> Node:
	var raiz := m.get_tree().root
	var g := raiz.get_node_or_null(NOMBRE_NODO)
	if g == null:
		g = new()
		g.name = NOMBRE_NODO
		raiz.add_child.call_deferred(g)           # la raíz está ocupada montando la escena mientras se llama desde `_ready`
	g.construir(m)
	return g


## Lo llama cada partida nueva al armar su HUD: enlaza el grabador con ella (si estaba grabando, sigue grabando y lo anota).
func construir(m: Node) -> void:
	var antes = main
	main = m
	process_mode = Node.PROCESS_MODE_ALWAYS     # sigue anotando aunque el juego esté en pausa (una pausa también puede ir mal)
	version_juego = String(m.VERSION)
	if not grabando:
		set_process(false)
	elif antes != m:
		marcar("partida nueva cargada")
	if is_inside_tree() and "ajustes" in main and main.ajustes is Dictionary:
		equipo = texto_equipo()


## Enciende el grabador. Devuelve false si no pudo abrir el archivo.
func iniciar() -> bool:
	if grabando:
		return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var d := Time.get_datetime_dict_from_system()
	var sello := "%04d%02d%02d_%02d%02d%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"]]
	_ruta = CARPETA + "rend_%s.csv" % sello
	_f = FileAccess.open(_ruta, FileAccess.WRITE)
	if _f == null:
		return false
	_f.store_line(CABECERA)
	_dts = PackedFloat32Array()
	_zooms = PackedFloat32Array()
	_vistas = PackedStringArray()
	_tiempos = PackedFloat32Array()
	_draws = PackedInt32Array()
	_tris = PackedInt32Array()
	_marcas = []
	_marca_pend = ""
	n_filas = 0
	_t0_us = Time.get_ticks_usec()
	_ult_flush_us = _t0_us
	_ms_ciud_ant = float(main.CapaCiudades.ms_dibujo)
	equipo = texto_equipo()
	_vp = get_viewport().get_viewport_rid()
	_mide_render = RenderingServer.has_method("viewport_set_measure_render_time")
	if _mide_render:
		RenderingServer.call("viewport_set_measure_render_time", _vp, true)
	grabando = true
	set_process(true)
	_mostrar_indicador(true)
	return true


## Pone una marca en la fila siguiente (si ya había una pendiente en ese fotograma, se unen).
func marcar(texto := "marca") -> void:
	if grabando:
		var t := texto.replace(",", ";")
		_marca_pend = t if _marca_pend == "" else _marca_pend + " + " + t


func _juego_vivo() -> bool:
	return main != null and is_instance_valid(main) and main.get("camara") != null


func _process(delta: float) -> void:
	if not grabando:
		return
	var t_s := float(Time.get_ticks_usec() - _t0_us) / 1.0e6
	var dt := delta * 1000.0
	var cpu := 0.0
	var gpu := 0.0
	if _mide_render:
		cpu = float(RenderingServer.call("viewport_get_measured_render_time_cpu", _vp))
		gpu = float(RenderingServer.call("viewport_get_measured_render_time_gpu", _vp))
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var tri := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var obj := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var mv := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var mt := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
	var proceso := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var z := 0.0
	var vista := "carga"
	var cam := Vector2.ZERO
	var ms_ciud := 0.0
	var tropas := 0.0
	var foco := ""
	var vel := 0
	var ms_z := 0.0
	var ms_p := 0.0
	if _juego_vivo():
		z = main.camara.zoom.x
		vista = "menu" if main.en_menu else ("relieve" if main.modo_relieve else "tradicional")
		cam = main.camara.position
		var ciud := float(main.CapaCiudades.ms_dibujo)
		ms_ciud = ciud - _ms_ciud_ant
		_ms_ciud_ant = ciud
		tropas = float(main.capa_tropas.ms_dibujo) if main.capa_tropas != null else 0.0
		foco = String(main.pais_foco).replace(",", ";")
		vel = main.reloj.velocidad if main.reloj != null else 0
		ms_z = float(main.ms_zoom)
		ms_p = float(main.ms_proceso)
	_f.store_line("%.3f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%.1f,%.1f,%.3f,%.1f,%.1f,%s,%s,%d,%.2f,%.2f,%.2f,%.2f,%s" % [
		t_s, dt, proceso, cpu, gpu, draws, tri, obj, mv, mt, z, cam.x, cam.y, vista, foco, vel, ms_z, ms_p, ms_ciud, tropas, _marca_pend])
	if _marca_pend != "":
		_marcas.append([n_filas, _marca_pend, t_s, z, vista])
		_marca_pend = ""
	_dts.append(dt)
	_zooms.append(z)
	_vistas.append(vista)
	_tiempos.append(t_s)
	_draws.append(draws)
	_tris.append(tri)
	n_filas += 1
	if Time.get_ticks_usec() - _ult_flush_us > 2000000:         # cada 2 s se vuelca al disco: si el juego se cierra mal, no se pierde todo
		_f.flush()
		_ult_flush_us = Time.get_ticks_usec()
		if lbl_rec != null:
			lbl_rec.text = "● REC %d:%02d" % [int(t_s) / 60, int(t_s) % 60]
	if n_filas >= MAX_FILAS:
		detener()


## Apaga el grabador, cierra el CSV, escribe el resumen y lo deja en el portapapeles (`portapapeles` = false al salir del juego: ya no hay ventana). Devuelve el resumen.
func detener(portapapeles := true) -> String:
	if not grabando:
		return ultimo_resumen
	grabando = false
	set_process(false)
	_mostrar_indicador(false)
	if _mide_render:
		RenderingServer.call("viewport_set_measure_render_time", _vp, false)
	if _f != null:
		_f.flush()
		_f = null
	ultimo_archivo = _ruta
	ultimo_resumen = resumen()
	var ruta_txt := _ruta.trim_suffix(".csv") + "_resumen.txt"
	var g := FileAccess.open(ruta_txt, FileAccess.WRITE)
	if g != null:
		g.store_string(ultimo_resumen)
		g = null
	if portapapeles:
		DisplayServer.clipboard_set(ultimo_resumen)
	terminado.emit(_ruta, ultimo_resumen)
	return ultimo_resumen


## Cerrar el juego mientras graba: se guarda el resumen igual (el CSV ya estaba volcado al disco cada 2 s).
func _exit_tree() -> void:
	if grabando:
		detener(false)


## El «● REC» rojo de arriba a la derecha: capa propia por encima de todo, así se ve también en el menú principal y en la pausa.
func _mostrar_indicador(ver: bool) -> void:
	if not ver:
		if indicador != null and is_instance_valid(indicador):
			indicador.queue_free()
		indicador = null
		lbl_rec = null
		return
	if indicador != null or not is_inside_tree():
		return
	indicador = CanvasLayer.new()
	indicador.layer = 120
	indicador.process_mode = Node.PROCESS_MODE_ALWAYS
	lbl_rec = Label.new()
	lbl_rec.text = "● REC 0:00"
	lbl_rec.add_theme_font_size_override("font_size", 15)
	lbl_rec.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	lbl_rec.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl_rec.add_theme_constant_override("outline_size", 5)
	lbl_rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_rec.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lbl_rec.offset_left = -130.0
	lbl_rec.offset_top = 52.0
	lbl_rec.offset_right = -12.0
	lbl_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	indicador.add_child(lbl_rec)
	add_child(indicador)


func ruta_carpeta() -> String:
	return ProjectSettings.globalize_path(CARPETA)


# ─────────────────────────────────────────────────────────────
# Resumen
# ─────────────────────────────────────────────────────────────
## Percentil `p` (0..1) de una lista YA ordenada.
static func percentil(orden: Array, p: float) -> float:
	if orden.is_empty():
		return 0.0
	return float(orden[clampi(int(float(orden.size() - 1) * p), 0, orden.size() - 1)])


## Texto «Equipo y ajustes» que va al principio del resumen.
func texto_equipo() -> String:
	if not _juego_vivo():
		return equipo
	var ventana := get_window().size
	var aj: Dictionary = main.ajustes
	var preset := int(main.AjustesScript.preset_de(aj))
	var t := "GPU: %s (%s) · API %s\n" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()]
	t += "Sistema: %s · Godot %s · render %s · CPU %d hilos · ventana %d×%d · pantalla %d×%d\n" % [
		OS.get_name(), String(Engine.get_version_info()["string"]), String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")),
		OS.get_processor_count(), ventana.x, ventana.y, DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y]
	t += "Calidad: %s · bordes %d · mar %s · costa %s · MSAA %s · VSync %s · tope de FPS %s\n" % [
		String(main.AjustesScript.PRESETS_NOMBRES[preset]), int(main.q_bordes), str(aj.get("mar", "?")), str(aj.get("costa", "?")), str(aj.get("msaa", "?")),
		str(aj.get("vsync", "?")), str(aj.get("fps_max", "?"))]
	return t


## El resumen de lo grabado (se llama al detener; también sirve para pruebas).
func resumen() -> String:
	var n := _dts.size()
	var t := "RESUMEN DE RENDIMIENTO · juego v%s\n%s" % [version_juego, texto_equipo()]
	if n < 2:
		return t + "Muy poca grabación (%d fotogramas): no hay nada que resumir.\n" % n
	var dur := float(_tiempos[n - 1])
	var orden: Array = Array(_dts)
	orden.sort()
	var suma := 0.0
	var lentos := 0
	var tirones := 0
	for v in _dts:
		suma += float(v)
		if float(v) > 25.0:
			lentos += 1
		if float(v) > UMBRAL_TIRON_MS:
			tirones += 1
	t += "\nGrabado: %.0f s · %d fotogramas · FPS medios %.0f\n" % [dur, n, 1000.0 * float(n) / maxf(suma, 0.001)]
	t += "Duración del fotograma (ms): mediana %.1f · p95 %.1f · p99 %.1f · peor %.1f\n" % [percentil(orden, 0.5), percentil(orden, 0.95), percentil(orden, 0.99), float(orden[n - 1])]
	t += "Fotogramas de más de 25 ms (menos de 40 FPS): %d (%.1f %%) · de más de %d ms (tirones): %d\n" % [lentos, 100.0 * float(lentos) / float(n), int(UMBRAL_TIRON_MS), tirones]
	# por vista y por banda de zoom
	t += "\nPor vista y nivel de zoom (fotogramas · ms medio · p95 · peor):\n"
	for vista in VISTAS:
		for b in BANDAS_ZOOM:
			var l: Array = []
			for i in n:
				if _vistas[i] == vista and float(_zooms[i]) >= float(b[0]) and float(_zooms[i]) < float(b[1]):
					l.append(float(_dts[i]))
			if l.size() < 5:
				continue
			l.sort()
			var s := 0.0
			for v in l:
				s += float(v)
			t += "  %-11s zoom %4.1f–%-4.1f  %6d fot · %5.1f ms · p95 %5.1f · peor %6.1f\n" % [vista, float(b[0]), minf(float(b[1]), 32.0), l.size(), s / float(l.size()), percentil(l, 0.95), float(l[l.size() - 1])]
	# los peores fotogramas
	var idx: Array = []
	for i in n:
		idx.append(i)
	idx.sort_custom(func(a, b): return _dts[a] > _dts[b])
	t += "\nLos 12 peores fotogramas (a los cuántos segundos · duración · zoom · vista · llamadas de dibujo · triángulos):\n"
	for k in mini(12, n):
		var i: int = idx[k]
		t += "  %7.1f s · %6.1f ms · zoom %5.2f · %-11s · %d dibujos · %d tri\n" % [float(_tiempos[i]), float(_dts[i]), float(_zooms[i]), _vistas[i], _draws[i], _tris[i]]
	if not _marcas.is_empty():
		t += "\nMarcas (F8):\n"
		for m in _marcas:
			t += "  %7.1f s · «%s» · zoom %.2f · %s\n" % [float(m[2]), String(m[1]), float(m[3]), String(m[4])]
	t += "\nArchivo con todos los fotogramas: %s\n" % ProjectSettings.globalize_path(_ruta if _ruta != "" else ultimo_archivo)
	return t
