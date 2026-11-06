extends VBoxContainer
## Ventana «PANTALLA» del menú de opciones (0.1.8.31): resolución, modo de pantalla y ajustes gráficos.
## Los controles solo cambian `pendiente`; nada toca la ventana hasta pulsar APLICAR. Si el cambio mueve o redimensiona la ventana
## (modo, tamaño, sin bordes) aparece «¿Mantener estos cambios?» con una cuenta atrás: si no se confirma, se vuelve solo a lo anterior
## (así una resolución mala nunca te deja sin imagen). Lo confirmado se guarda en user://ajustes.cfg y se aplica al arrancar.
## La lógica de valores (válidos, por defecto, guardar/cargar, aplicar) vive en ajustes.gd; aquí solo está la interfaz.
## 0.1.8.32: además de la pantalla, la ventana tiene una sección GRÁFICOS DEL MAPA (calidad Alta/Media/Baja y cada ajuste por separado) y la
## prioridad de la simulación: lo que de verdad sube los FPS en un PC flojo.

const AjustesScript := preload("res://scripts/ajustes.gd")
const SEGUNDOS_CONFIRMAR := 10
const ALTO_AREA := 330.0                 ## alto del área con los controles (los de más abajo se alcanzan con la barra de desplazamiento)

signal aplicado(ajustes: Dictionary)      ## se confirmó (o no hacía falta confirmar) y quedó guardado
signal volver_pedido                      ## el jugador pulsó VOLVER

var ruta := AjustesScript.RUTA            ## dónde se guarda (las pruebas usan otro archivo)
var vigente: Dictionary = {}              ## lo último aplicado y guardado: a esto vuelve «REVERTIR»
var pendiente: Dictionary = {}            ## lo que muestran los controles (aún sin aplicar)
var confirmando := false                  ## true mientras se ve «¿Mantener estos cambios?»
var segundos_restantes := 0

var _ventana: Window
var _antes: Dictionary = {}               ## cómo estaba la ventana justo antes de aplicar (para revertir)
var _resoluciones: Array = []             ## Vector2i que ofrece el desplegable, en el mismo orden
var _cuerpo: VBoxContainer
var _confirma: VBoxContainer
var _lbl_cuenta: Label
var _lbl_nota: Label
var _gen_verif := 0                       ## número del último APLICAR: una comprobación vieja no pisa a la nueva
var _lbl_estado: Label                    ## resultado del último APLICAR (qué quedó realmente aplicado, o por qué no)
var _timer: Timer
var _op_modo: OptionButton
var _op_res: OptionButton
var _lbl_res: Label                       ## el título de esa fila cambia: «Resolución de la ventana» / «Resolución interna (pantalla completa)»
var _chk_bordes: CheckBox
var _op_vsync: OptionButton
var _op_fps: OptionButton
var _op_msaa: OptionButton
var _chk_fps: CheckBox
var _op_calidad: OptionButton
var _op_mar: OptionButton
var _op_costa: OptionButton
var _chk_prov: CheckBox
var _chk_ciudades: CheckBox
var _chk_lagos: CheckBox
var _op_sim: OptionButton
var _filas: VBoxContainer                 ## donde van las filas de controles (dentro de un área con barra de desplazamiento)
var _btn_aplicar: Button


## Construye la ventana. `ventana`: la ventana real del juego; `ajuste_vigente`: el último ajuste conocido del juego.
func iniciar(ventana: Window, ajuste_vigente: Dictionary) -> void:
	_ventana = ventana
	vigente = AjustesScript.leer_actual(ventana, ajuste_vigente)
	pendiente = vigente.duplicate()
	add_theme_constant_override("separation", 12)
	_construir_cuerpo()
	_construir_confirmacion()
	_lbl_estado = Label.new()                 # fuera del cuerpo: se ve también mientras corre la cuenta atrás
	_lbl_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_estado.custom_minimum_size = Vector2(560.0, 0.0)
	_lbl_estado.add_theme_font_size_override("font_size", 13)
	_lbl_estado.visible = false
	add_child(_lbl_estado)
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_refrescar()


# ─────────────────────────────────────────────────────────────
# Construcción de los controles
# ─────────────────────────────────────────────────────────────
func _construir_cuerpo() -> void:
	_cuerpo = VBoxContainer.new()
	_cuerpo.add_theme_constant_override("separation", 10)
	add_child(_cuerpo)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(620.0, ALTO_AREA)
	_cuerpo.add_child(scroll)
	_filas = VBoxContainer.new()
	_filas.add_theme_constant_override("separation", 10)
	_filas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_filas)
	_seccion("PANTALLA")
	_op_modo = _desplegable(AjustesScript.MODOS, func(i: int): poner("modo", i))
	_fila("Modo de pantalla", _op_modo)
	_op_res = _desplegable([], func(i: int): _elegir_resolucion(i))
	_lbl_res = _fila("Resolución de la ventana", _op_res)
	_chk_bordes = _casilla("Sin barra de título", func(v: bool): poner("sin_bordes", v))
	_fila("Ventana sin bordes", _chk_bordes)
	_op_vsync = _desplegable(AjustesScript.VSYNC_NOMBRES, func(i: int): poner("vsync", i))
	_fila("Sincronización vertical (VSync)", _op_vsync)
	var nombres_fps: Array = []
	for n in AjustesScript.FPS_OPCIONES:
		nombres_fps.append(AjustesScript.texto_fps(int(n)))
	_op_fps = _desplegable(nombres_fps, func(i: int): poner("fps_max", AjustesScript.FPS_OPCIONES[i]))
	_fila("Límite de FPS", _op_fps)
	_chk_fps = _casilla("Mostrar en la esquina", func(v: bool): poner("mostrar_fps", v))
	_fila("Contador de FPS", _chk_fps)
	_seccion("GRÁFICOS DEL MAPA (más FPS en un PC flojo)")
	_op_calidad = _desplegable(AjustesScript.PRESETS_NOMBRES, func(i: int): poner_calidad(i))
	_fila("Calidad", _op_calidad)
	_op_msaa = _desplegable(AjustesScript.MSAA_NOMBRES, func(i: int): poner("msaa", i))
	_fila("Suavizado de bordes", _op_msaa)
	_op_mar = _desplegable(AjustesScript.MAR_NOMBRES, func(i: int): poner("mar", i))
	_fila("Mar", _op_mar)
	_op_costa = _desplegable(AjustesScript.COSTA_NOMBRES, func(i: int): poner("costa", i))
	_fila("Costas", _op_costa)
	_chk_prov = _casilla("Dibujar al acercar (campaña)", func(v: bool): poner("lineas_prov", v))
	_fila("Líneas de provincia", _chk_prov)
	_chk_ciudades = _casilla("Dibujar al acercar", func(v: bool): poner("ciudades", v))
	_fila("Ciudades", _chk_ciudades)
	_chk_lagos = _casilla("Dibujar", func(v: bool): poner("lagos", v))
	_fila("Lagos", _chk_lagos)
	_seccion("SIMULACIÓN")
	_op_sim = _desplegable(AjustesScript.SIM_NOMBRES, func(i: int): poner("sim_prio", i))
	_fila("Prioridad", _op_sim)
	_lbl_nota = Label.new()
	_lbl_nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_nota.custom_minimum_size = Vector2(560.0, 0.0)
	_lbl_nota.add_theme_font_size_override("font_size", 13)
	_lbl_nota.add_theme_color_override("font_color", Color(0.67, 0.72, 0.82))
	_cuerpo.add_child(_lbl_nota)
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 10)
	_cuerpo.add_child(botones)
	_btn_aplicar = _boton("APLICAR", aplicar_pendiente)
	botones.add_child(_btn_aplicar)
	botones.add_child(_boton("RESTABLECER", restablecer))
	botones.add_child(_boton("VOLVER", func(): volver_pedido.emit()))


## El recuadro «¿Mantener estos cambios?» que sustituye al cuerpo mientras corre la cuenta atrás.
func _construir_confirmacion() -> void:
	_confirma = VBoxContainer.new()
	_confirma.add_theme_constant_override("separation", 14)
	_confirma.visible = false
	add_child(_confirma)
	var t := Label.new()
	t.text = "¿Mantener estos cambios?"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 22)
	_confirma.add_child(t)
	_lbl_cuenta = Label.new()
	_lbl_cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_cuenta.add_theme_font_size_override("font_size", 16)
	_confirma.add_child(_lbl_cuenta)
	_confirma.add_child(_boton("MANTENER", confirmar))
	_confirma.add_child(_boton("REVERTIR", revertir))


func _desplegable(textos: Array, al_elegir: Callable) -> OptionButton:
	var o := OptionButton.new()
	for t in textos:
		o.add_item(String(t))
	o.item_selected.connect(al_elegir)
	return o


func _casilla(texto: String, al_cambiar: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = texto
	c.toggled.connect(al_cambiar)
	return c


func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0.0, 44.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(accion)
	return b


## Una fila «etiqueta a la izquierda, control a la derecha».
func _fila(titulo: String, control: Control) -> Label:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = titulo
	l.custom_minimum_size = Vector2(270.0, 0.0)
	l.add_theme_font_size_override("font_size", 17)
	f.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.add_child(control)
	_filas.add_child(f)
	return l


## Un título de sección dentro de la lista de controles.
func _seccion(titulo: String) -> void:
	var l := Label.new()
	l.text = titulo
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	_filas.add_child(l)


# ─────────────────────────────────────────────────────────────
# Cambios pendientes
# ─────────────────────────────────────────────────────────────
## Cambia un valor de `pendiente` (queda saneado) y refresca los controles. Todos los controles pasan por aquí.
func poner(clave: String, valor: Variant) -> void:
	if confirmando:
		return
	var nuevo := pendiente.duplicate()
	nuevo[clave] = valor
	pendiente = AjustesScript.sanear(nuevo)
	_refrescar()


## Elige una calidad (0 Alta, 1 Media, 2 Baja): fija el suavizado, el mar, las costas, las líneas de provincia, las ciudades y los lagos.
## «Personalizada» no cambia nada (solo describe que los valores de abajo no coinciden con ninguna calidad).
func poner_calidad(i: int) -> void:
	if confirmando:
		return
	pendiente = AjustesScript.con_preset(pendiente, i)
	_refrescar()


func _elegir_resolucion(i: int) -> void:
	if i < 0 or i >= _resoluciones.size():
		return
	var v: Vector2i = _resoluciones[i]
	var nuevo := pendiente.duplicate()
	if int(pendiente["modo"]) == AjustesScript.MODO_COMPLETA:      # 0.1.8.35: en pantalla completa se elige la resolución INTERNA (Vector2i.ZERO = nativa)
		nuevo["ancho_fs"] = v.x
		nuevo["alto_fs"] = v.y
	else:
		nuevo["ancho"] = v.x
		nuevo["alto"] = v.y
	pendiente = AjustesScript.sanear(nuevo)
	_refrescar()


## Vuelve los controles a los valores por defecto (no se aplican hasta pulsar APLICAR).
func restablecer() -> void:
	if confirmando:
		return
	pendiente = AjustesScript.por_defecto()
	_refrescar()


## Pone los controles al día con `pendiente`: selecciones, lo que se apaga en pantalla completa y el texto de ayuda.
## Las selecciones se ponen sin emitir señales, para que refrescar no vuelva a llamar a `poner`.
func _refrescar() -> void:
	var completa := int(pendiente["modo"]) == AjustesScript.MODO_COMPLETA
	var pantalla := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen(_ventana.get_window_id()))
	if completa:
		var interna := Vector2i(int(pendiente["ancho_fs"]), int(pendiente["alto_fs"]))
		_resoluciones = AjustesScript.resoluciones_internas(pantalla, interna)
		_op_res.clear()
		for v in _resoluciones:
			_op_res.add_item(AjustesScript.texto_res_interna(v, pantalla))
		_op_res.select(_resoluciones.find(interna))
	else:
		_resoluciones = AjustesScript.resoluciones_para(pantalla, Vector2i(int(pendiente["ancho"]), int(pendiente["alto"])))
		_op_res.clear()
		for v in _resoluciones:
			_op_res.add_item(AjustesScript.texto_resolucion(v))
		_op_res.select(_resoluciones.find(Vector2i(int(pendiente["ancho"]), int(pendiente["alto"]))))
	_op_modo.select(int(pendiente["modo"]))
	_op_vsync.select(int(pendiente["vsync"]))
	_op_fps.select(AjustesScript.FPS_OPCIONES.find(int(pendiente["fps_max"])))
	_op_msaa.select(int(pendiente["msaa"]))
	_op_calidad.select(AjustesScript.preset_de(pendiente))
	_op_mar.select(int(pendiente["mar"]))
	_op_costa.select(int(pendiente["costa"]))
	_op_sim.select(int(pendiente["sim_prio"]))
	_chk_prov.set_pressed_no_signal(bool(pendiente["lineas_prov"]))
	_chk_ciudades.set_pressed_no_signal(bool(pendiente["ciudades"]))
	_chk_lagos.set_pressed_no_signal(bool(pendiente["lagos"]))
	_chk_bordes.set_pressed_no_signal(bool(pendiente["sin_bordes"]))
	_chk_fps.set_pressed_no_signal(bool(pendiente["mostrar_fps"]))
	_lbl_res.text = "Resolución interna (pantalla completa)" if completa else "Resolución de la ventana"
	_chk_bordes.disabled = completa
	_lbl_nota.text = _texto_nota(completa, pantalla)
	_btn_aplicar.disabled = AjustesScript.iguales(pendiente, vigente)
	_cuerpo.visible = not confirmando
	_confirma.visible = confirmando


func _texto_nota(completa: bool, pantalla: Vector2i) -> String:
	var t := "Los cambios se aplican al pulsar APLICAR y se guardan para la próxima vez."
	if completa:
		t = "En pantalla completa puedes bajar la resolución INTERNA: el juego se dibuja con menos píxeles y se estira a toda la pantalla (%s). Menos píxeles = más FPS." % AjustesScript.texto_resolucion(pantalla)
	return t + "\nSi tu PC va justa: calidad Baja, sin suavizado, y prioridad «Fluidez» en la simulación."


# ─────────────────────────────────────────────────────────────
# Aplicar, confirmar y revertir
# ─────────────────────────────────────────────────────────────
## Botón APLICAR: aplica `pendiente` a la ventana. Si mueve o redimensiona la ventana, pide confirmación; si no, lo guarda ya.
func aplicar_pendiente() -> void:
	if confirmando:
		return
	_antes = AjustesScript.leer_actual(_ventana, vigente)
	pendiente = AjustesScript.sanear(pendiente)
	AjustesScript.aplicar(pendiente, _ventana)
	_verificar_ventana(pendiente.duplicate())
	if AjustesScript.requiere_confirmacion(_antes, pendiente):
		confirmando = true
		segundos_restantes = SEGUNDOS_CONFIRMAR
		_lbl_cuenta.text = _texto_cuenta()
		_timer.start()
		_refrescar()
	else:
		confirmar()


## 0.1.8.33 · Comprueba que la ventana quedó como se pidió y lo dice en pantalla (antes, si el sistema ignoraba el cambio, no se veía NADA).
## Repite el tamaño a los 2 fotogramas (hay sistemas que lo pisan al cambiar de modo) y mira el resultado 2 fotogramas después.
## Si no hubo manera de cambiar la ventana, la cuenta atrás de «¿Mantener?» no tiene sentido: se cierra y el aviso se queda a la vista.
func _verificar_ventana(objetivo: Dictionary) -> void:
	_gen_verif += 1
	var mi_gen := _gen_verif
	_poner_estado("Aplicando…", false)
	for _i in 2:
		await get_tree().process_frame
		if not is_inside_tree() or mi_gen != _gen_verif:
			return
	AjustesScript.reforzar_ventana(objetivo, _ventana)
	for _i in 2:
		await get_tree().process_frame
		if not is_inside_tree() or mi_gen != _gen_verif:
			return
	var problema := AjustesScript.discrepancia(objetivo, _ventana)
	if problema == "":
		_poner_estado(_texto_resultado(objetivo), false)
		return
	_poner_estado(problema, true)
	if confirmando and not AjustesScript.requiere_confirmacion(_antes, AjustesScript.leer_actual(_ventana, vigente)):
		confirmar()                             # la ventana quedó igual que antes: no hay nada que confirmar ni que revertir


## Lo que quedó aplicado, en una línea.
func _texto_resultado(a: Dictionary) -> String:
	var ventana_txt := "pantalla completa" if int(a["modo"]) == AjustesScript.MODO_COMPLETA else "ventana %s" % AjustesScript.texto_resolucion(_ventana.size)
	return "Aplicado: %s · VSync %s · FPS %s · calidad %s." % [ventana_txt, String(AjustesScript.VSYNC_NOMBRES[int(a["vsync"])]).to_lower(),
		AjustesScript.texto_fps(int(a["fps_max"])).to_lower(), String(AjustesScript.PRESETS_NOMBRES[AjustesScript.preset_de(a)]).to_lower()]


func _poner_estado(texto: String, es_aviso: bool) -> void:
	if _lbl_estado == null:
		return
	_lbl_estado.text = texto
	_lbl_estado.visible = texto != ""
	_lbl_estado.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35) if es_aviso else Color(0.55, 0.9, 0.6))


func _texto_cuenta() -> String:
	return "Si no confirmas, vuelve solo a lo anterior en %d s." % segundos_restantes


## Un segundo de la cuenta atrás; al llegar a cero se revierte.
func _tick() -> void:
	if not confirmando:
		return
	segundos_restantes -= 1
	if segundos_restantes <= 0:
		revertir()
	else:
		_lbl_cuenta.text = _texto_cuenta()


## MANTENER (o un cambio que no necesitaba confirmación): lo aplicado queda como vigente y se guarda en disco.
func confirmar() -> void:
	vigente = pendiente.duplicate()
	confirmando = false
	_timer.stop()
	AjustesScript.guardar(vigente, ruta)
	_refrescar()
	aplicado.emit(vigente)


## REVERTIR (o se acabó el tiempo): la ventana vuelve a como estaba y los controles también. No se guarda nada.
func revertir() -> void:
	if not confirmando:
		return
	AjustesScript.aplicar(_antes, _ventana)
	_verificar_ventana(_antes.duplicate())
	pendiente = _antes.duplicate()
	confirmando = false
	_timer.stop()
	_refrescar()


## Si la ventana se cierra con la cuenta atrás en marcha (por ejemplo con Esc en el menú de pausa), se vuelve a lo anterior sin preguntar.
func _exit_tree() -> void:
	if confirmando and _ventana != null and not _antes.is_empty():
		AjustesScript.aplicar(_antes, _ventana)
