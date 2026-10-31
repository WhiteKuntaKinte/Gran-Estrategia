extends Node2D
## Gran Estrategia - mapa mundial (v0.1.7)
##
## IDEA CLAVE DE RENDIMIENTO:
## Todo lo pesado (triangulación, colores, bordes, posición de los nombres) se calcula UNA vez fuera de Godot
## con herramientas/construir_mapa.py y se guarda en la carpeta datos/. Aquí solo se cargan mallas ya hechas.
## Hacer zoom NO recalcula nada: solo cambia la transparencia de unas pocas capas y el grosor de los bordes.

const VERSION := "0.1.7"
const ANCHO_MAPA := 2400.0
const ZOOM_MIN := 0.55
const ZOOM_MAX := 32.0
const Y_MIN := 0.0
const Y_MAX := 1200.0
const FUENTE_BASE := 48            # tamaño base de las letras (con MSDF se escalan sin pixelarse)
const PX_LEGIBLE := 11.0           # tamaño en pantalla (px) al que un nombre empieza a aparecer

# Transiciones de zoom (vista continental -> vista de países)
const ZOOM_PAISES_INI := 1.0
const ZOOM_PAISES_FIN := 1.6

# Espaciado máximo permitido entre letras según el tipo de nombre (c=continente, p=país, m=país con provincias, v=provincia)
const ESPACIADO_MAX := {"c": 3.4, "p": 2.0, "m": 2.2, "v": 1.5}

const SHADER_BORDE := """
shader_type canvas_item;
uniform float half_width = 0.5;
uniform vec4 col : source_color = vec4(0.04, 0.05, 0.09, 1.0);
uniform float alfa = 1.0;
void vertex() {
	VERTEX += UV * half_width;
}
void fragment() {
	COLOR = vec4(col.rgb, col.a * alfa);
}
"""

# Degradado continuo por latitud. Normaliza el valor previo para quitar el centroide 0.1.6.
const SHADER_GRADIENTE_PAIS := """
shader_type canvas_item;
uniform float y_ecuador = 580.0;
uniform float rango_latitud = 330.0;
uniform float brillo_minimo = 0.50;
varying float y_mapa;
void vertex() {
	y_mapa = VERTEX.y;
}
void fragment() {
	float valor_base = max(max(COLOR.r, COLOR.g), COLOR.b);
	vec3 color_normalizado = COLOR.rgb / max(valor_base, 0.001);
	float distancia = clamp(abs(y_mapa - y_ecuador) / rango_latitud, 0.0, 1.0);
	float brillo = mix(brillo_minimo, 1.0, pow(distancia, 0.85));
	COLOR = vec4(color_normalizado * brillo, COLOR.a);
}
"""

@onready var camara: Camera2D = $Camera2D

var fuente: SystemFont
var arrastrando := false

# Datos de provincias (para clic y HUD)
var provincias: Array = []
var anillos: Array = []
var vertices_fill := PackedVector2Array()
var indices_fill := PackedInt32Array()

# Capas del mapa (cada una tiene 3 copias para el mundo infinito: izquierda, centro, derecha)
var capa_pais: Array = []
var capa_costa: Array = []
var capa_frontera: Array = []
var capa_prov: Array = []
var capa_cont: Array = []
var mat_costa: ShaderMaterial
var mat_frontera: ShaderMaterial
var mat_prov: ShaderMaterial
var mat_cont: ShaderMaterial

# Capas de texto
var capas_texto: Array = []

# Selección
var resaltado: Array = []
var lineas_resaltado: Array = []
var seleccion_activa := false

# HUD
var hud: CanvasLayer
var panel: PanelContainer
var lbl_nombre: Label
var lbl_tipo: Label
var lbl_pais: Label
var lbl_cont: Label
var lbl_coord: Label
var lbl_fps: Label

# Menú principal
var en_menu := true
var en_pausa := false
var menu: CanvasLayer
var menu_contenido: VBoxContainer
var menu_pausa: CanvasLayer


# ─────────────────────────────────────────────────────────────
# Capa de texto: dibuja letra por letra, cada una rotada siguiendo la forma del territorio
# ─────────────────────────────────────────────────────────────
class CapaTexto extends Node2D:
	var fuente: Font
	var ancho_mundo := 2400.0
	var chars := PackedStringArray()
	var pos := PackedVector2Array()
	var ang := PackedFloat32Array()
	var esc := PackedFloat32Array()
	var anc := PackedFloat32Array()
	var cols := PackedColorArray()

	func agregar(c: String, p: Vector2, a: float, e: float, w48: float, col: Color) -> void:
		chars.append(c)
		pos.append(p)
		ang.append(a)
		esc.append(e)
		anc.append(w48)
		cols.append(col)

	func _draw() -> void:
		for dx in [-ancho_mundo, 0.0, ancho_mundo]:
			for i in chars.size():
				draw_set_transform(pos[i] + Vector2(dx, 0.0), ang[i], Vector2(esc[i], esc[i]))
				draw_char(fuente, Vector2(-anc[i] * 0.5, 17.0), chars[i], 48, cols[i])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_configurar_fuente()
	_configurar_oceano()
	camara.enabled = true
	camara.zoom = Vector2(0.6, 0.6)
	camara.position = Vector2(1200.0, 600.0)
	camara.make_current()

	var t0 := Time.get_ticks_msec()
	_cargar_datos_provincias()
	_construir_mapa()
	_construir_etiquetas()
	_crear_hud()
	_crear_menu()
	_actualizar_zoom()
	print("Mapa cargado en ", Time.get_ticks_msec() - t0, " ms")


func _process(delta: float) -> void:
	# Solo corre en el menú: el mapa se desplaza muy despacio de fondo
	if en_menu:
		camara.position.x += delta * 6.0
		_normalizar_camara()


# ─────────────────────────────────────────────────────────────
# Preparación
# ─────────────────────────────────────────────────────────────
func _configurar_fuente() -> void:
	fuente = SystemFont.new()
	fuente.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Cambria", "Times New Roman", "serif"])
	fuente.multichannel_signed_distance_field = true
	fuente.msdf_pixel_range = 16
	fuente.msdf_size = 48
	fuente.generate_mipmaps = true


func _configurar_oceano() -> void:
	if has_node("OceanoFondo"):
		var o: ColorRect = $OceanoFondo
		o.z_index = -10
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		o.position = Vector2(-15000.0, -3000.0)
		o.size = Vector2(35000.0, 7000.0)


func _leer_bytes(nombre: String) -> PackedByteArray:
	var f := FileAccess.open("res://datos/" + nombre, FileAccess.READ)
	if f == null:
		push_error("Falta el archivo res://datos/" + nombre + " (ejecuta herramientas/construir_mapa.py)")
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b


func _leer_json(ruta: String):
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + ruta)
		return null
	var j := JSON.new()
	if j.parse(f.get_as_text()) != OK:
		push_error("JSON inválido en " + ruta + ": " + j.get_error_message())
		return null
	return j.data


func _a_vec2(b: PackedByteArray) -> PackedVector2Array:
	var f := b.to_float32_array()
	var n: int = f.size() >> 1
	var r := PackedVector2Array()
	r.resize(n)
	for i in n:
		r[i] = Vector2(f[i * 2], f[i * 2 + 1])
	return r


func _a_colores(b: PackedByteArray) -> PackedColorArray:
	var n: int = b.size() / 3
	var r := PackedColorArray()
	r.resize(n)
	for i in n:
		r[i] = Color(b[i * 3] / 255.0, b[i * 3 + 1] / 255.0, b[i * 3 + 2] / 255.0, 1.0)
	return r


func _crear_malla(v: PackedVector2Array, idx: PackedInt32Array, col := PackedColorArray(), uv := PackedVector2Array()) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = idx
	if col.size() > 0:
		arrays[Mesh.ARRAY_COLOR] = col
	if uv.size() > 0:
		arrays[Mesh.ARRAY_TEX_UV] = uv
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _instanciar(malla: ArrayMesh, material: Material, z: int) -> Array:
	var lista := []
	for dx in [-ANCHO_MAPA, 0.0, ANCHO_MAPA]:
		var mi := MeshInstance2D.new()
		mi.mesh = malla
		mi.material = material
		mi.position = Vector2(dx, 0.0)
		mi.z_index = z
		add_child(mi)
		lista.append(mi)
	return lista


func _cargar_datos_provincias() -> void:
	var d = _leer_json("res://datos/provincias_juego.json")
	if d == null:
		return
	provincias = d["provincias"]
	anillos = d["anillos"]


func _corregir_color_chukotka(colores: PackedColorArray) -> void:
	var desplazamiento := 0
	for anillo in anillos:
		var pi := int(anillo["p"])
		var es_chukotka := false
		if pi >= 0 and pi < provincias.size():
			var provincia: Dictionary = provincias[pi]
			var nombre := String(provincia.get("n", "")).to_lower()
			var identificador := String(provincia.get("id", "")).to_lower()
			es_chukotka = nombre.contains("chukotka") or identificador.contains("chukotka") or identificador.contains("chukchi")
		var cantidad := int(anillo["v"].size() / 2)
		if es_chukotka:
			for i in range(desplazamiento, mini(desplazamiento + cantidad, colores.size())):
				colores[i] = Color(0.86, 0.14, 0.12, 1.0)
		desplazamiento += cantidad


func _material_borde(sh: Shader, color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", color)
	return m


func _malla_borde(cat: String) -> ArrayMesh:
	var v := _a_vec2(_leer_bytes("malla_%s_v.bin" % cat))
	var uv := _a_vec2(_leer_bytes("malla_%s_uv.bin" % cat))
	var idx := _leer_bytes("malla_%s_i.bin" % cat).to_int32_array()
	if v.size() == 0:
		return null
	return _crear_malla(v, idx, PackedColorArray(), uv)


func _construir_mapa() -> void:
	# Relleno: una malla para la vista continental y otra (encima) para la vista de países.
	vertices_fill = _a_vec2(_leer_bytes("malla_fill_v.bin"))
	indices_fill = _leer_bytes("malla_fill_i.bin").to_int32_array()
	var col_cont := _a_colores(_leer_bytes("malla_fill_cc.bin"))
	var col_pais := _a_colores(_leer_bytes("malla_fill_cp.bin"))
	_corregir_color_chukotka(col_cont)
	_corregir_color_chukotka(col_pais)
	var malla_cont := _crear_malla(vertices_fill, indices_fill, col_cont)
	var malla_pais := _crear_malla(vertices_fill, indices_fill, col_pais)
	var shader_gradiente := Shader.new()
	shader_gradiente.code = SHADER_GRADIENTE_PAIS
	var material_gradiente_cont := ShaderMaterial.new()
	material_gradiente_cont.shader = shader_gradiente
	var material_gradiente_pais := ShaderMaterial.new()
	material_gradiente_pais.shader = shader_gradiente
	_instanciar(malla_cont, material_gradiente_cont, 0)
	capa_pais = _instanciar(malla_pais, material_gradiente_pais, 1)

	# Bordes: mallas de franjas cuyo grosor se ajusta en el shader (siempre se ven del mismo grosor en pantalla)
	var sh := Shader.new()
	sh.code = SHADER_BORDE
	mat_prov = _material_borde(sh, Color(0.03, 0.04, 0.07, 0.8))
	mat_frontera = _material_borde(sh, Color(0.03, 0.04, 0.07, 1.0))
	mat_cont = _material_borde(sh, Color(0.03, 0.04, 0.07, 1.0))
	mat_costa = _material_borde(sh, Color(0.03, 0.04, 0.07, 1.0))

	var m_prov := _malla_borde("prov")
	if m_prov:
		capa_prov = _instanciar(m_prov, mat_prov, 2)
	var m_front := _malla_borde("frontera")
	if m_front:
		capa_frontera = _instanciar(m_front, mat_frontera, 3)
	var m_cont := _malla_borde("cont")
	if m_cont:
		capa_cont = _instanciar(m_cont, mat_cont, 3)
	var m_costa := _malla_borde("costa")
	if m_costa:
		capa_costa = _instanciar(m_costa, mat_costa, 4)


# ─────────────────────────────────────────────────────────────
# Nombres (estilo AoH3: letras siguiendo la forma del territorio)
# ─────────────────────────────────────────────────────────────
func _cuantizar(z: float) -> float:
	return pow(2.0, roundf(log(z) / log(2.0) * 2.0) / 2.0)


func _construir_etiquetas() -> void:
	var datos = _leer_json("res://datos/etiquetas.json")
	if datos == null:
		return
	var cubos := {}
	for lab in datos:
		var g: String = lab["g"]
		var e: float = lab["e"]
		var zin: float = _cuantizar(PX_LEGIBLE / e)
		var zf := 0.0
		var clave := ""
		if g == "c":
			clave = "c"
		elif g == "m":
			zf = _cuantizar(lab["zf"])
			clave = "m|%s|%s" % [zin, zf]
		else:
			clave = "%s|%s" % [g, zin]
		if not cubos.has(clave):
			var capa := CapaTexto.new()
			capa.fuente = fuente
			capa.ancho_mundo = ANCHO_MAPA
			capa.z_index = 11 if g == "c" else 10
			capa.visible = false
			add_child(capa)
			cubos[clave] = {"capa": capa, "tipo": g, "zin": zin, "zf": zf}
			capas_texto.append(cubos[clave])
		_colocar_texto(lab, cubos[clave]["capa"])


func _posicion_en_linea(P: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Vector2:
	var total: float = cum[cum.size() - 1]
	d = clampf(d, 0.0, total)
	var i := 0
	while i < P.size() - 2 and cum[i + 1] < d:
		i += 1
	var largo: float = cum[i + 1] - cum[i]
	var f := 0.0
	if largo > 0.000001:
		f = (d - cum[i]) / largo
	return P[i].lerp(P[i + 1], f)


func _colocar_texto(lab: Dictionary, capa: CapaTexto) -> void:
	var texto: String = lab["t"]
	var g: String = lab["g"]
	var flat: Array = lab["p"]
	var P := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		P.append(Vector2(flat[i], flat[i + 1]))
	if P.size() < 2:
		return
	var cum := PackedFloat32Array([0.0])
	for i in range(1, P.size()):
		cum.append(cum[i - 1] + P[i].distance_to(P[i - 1]))
	var largo: float = cum[cum.size() - 1]
	if largo <= 0.0:
		return

	var n := texto.length()
	var anchos := PackedFloat32Array()
	var total48 := 0.0
	for i in n:
		var w: float = fuente.get_char_size(texto.unicode_at(i), FUENTE_BASE).x
		anchos.append(w)
		total48 += w

	var k: float = float(lab["e"]) / float(FUENTE_BASE)   # escala: tamaño real / tamaño base
	var total := total48 * k
	if total > 0.96 * largo:                           # si no cabe, se encoge (nunca se sale del territorio)
		k *= 0.96 * largo / total
		total = total48 * k
	var extra := 0.0
	if n > 1:
		var alvo := minf(largo * 0.9, total * float(ESPACIADO_MAX[g]))
		extra = maxf(0.0, (alvo - total) / float(n - 1))
		extra = minf(extra, k * float(FUENTE_BASE) * 1.2)
	var largo_texto := total + extra * float(n - 1)
	var s := (largo - largo_texto) * 0.5

	var color_texto := Color(0.99, 0.97, 0.88, 0.94)
	if int(lab["lc"]) == 0:
		color_texto = Color(0.06, 0.08, 0.12, 0.88)

	for i in n:
		var w := anchos[i] * k
		if texto[i] != " ":
			var c0 := s + w * 0.5
			var a := _posicion_en_linea(P, cum, c0 - w * 0.5)
			var b := _posicion_en_linea(P, cum, c0 + w * 0.5)
			var c := _posicion_en_linea(P, cum, c0)
			capa.agregar(texto[i], c, (b - a).angle(), k, anchos[i], color_texto)
		s += w + extra


# ─────────────────────────────────────────────────────────────
# Zoom: solo transparencias y grosores (cero recálculo de colores)
# ─────────────────────────────────────────────────────────────
func _poner_alfa(lista: Array, a: float) -> void:
	for n in lista:
		n.modulate.a = a
		n.visible = a > 0.004


func _poner_borde(lista: Array, mat: ShaderMaterial, px: float, z: float, alfa: float) -> void:
	if lista.is_empty():
		return
	mat.set_shader_parameter("half_width", px * 0.5 / z)
	mat.set_shader_parameter("alfa", alfa)
	for n in lista:
		n.visible = alfa > 0.004


func _actualizar_zoom() -> void:
	var z := camara.zoom.x
	var t := smoothstep(ZOOM_PAISES_INI, ZOOM_PAISES_FIN, z)

	_poner_alfa(capa_pais, t)                                           # colores por país (zoom in)
	_poner_borde(capa_costa, mat_costa, lerpf(1.7, 1.0, smoothstep(1.0, 2.5, z)), z, 1.0)
	_poner_borde(capa_cont, mat_cont, 1.7, z, 1.0 - t)                  # contorno continental (zoom out)
	_poner_borde(capa_frontera, mat_frontera, 1.1, z, t)                # fronteras entre países
	_poner_borde(capa_prov, mat_prov, 0.8, z, smoothstep(2.0, 3.4, z) * 0.7)  # fronteras entre provincias

	for c in capas_texto:
		var a := 0.0
		var zin: float = c["zin"]
		match c["tipo"]:
			"c":
				a = 1.0 - t
			"m":
				var zf: float = c["zf"]
				a = t * smoothstep(zin * 0.8, zin * 1.15, z) * (1.0 - smoothstep(zf * 0.9, zf * 1.3, z))
			_:
				a = t * smoothstep(zin * 0.8, zin * 1.15, z)
		if en_menu:
			a = 0.0                                                   # el menú no muestra nombres
		var capa: CapaTexto = c["capa"]
		capa.modulate.a = a
		capa.visible = a > 0.01

	for l in lineas_resaltado:
		l.width = 2.4 / z


func _normalizar_camara() -> void:
	camara.position.x = fposmod(camara.position.x, ANCHO_MAPA)
	camara.position.y = clampf(camara.position.y, Y_MIN, Y_MAX)


func _zoom_en_cursor(factor: float) -> void:
	var z0 := camara.zoom.x
	var z1 := clampf(z0 * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(z0, z1):
		return
	var vp := get_viewport()
	var centro := vp.get_visible_rect().size * 0.5
	var m := vp.get_mouse_position()
	var antes := camara.position + (m - centro) / z0
	camara.zoom = Vector2(z1, z1)
	camara.position = antes - (m - centro) / z1
	_normalizar_camara()
	_actualizar_zoom()


# ─────────────────────────────────────────────────────────────
# Entrada
# ─────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if en_menu:
			return
		if en_pausa:
			_reanudar_juego()
		else:
			_mostrar_menu_pausa()
		get_viewport().set_input_as_handled()
		return
	if en_menu or en_pausa:
		return
	if event is InputEventMouseButton:
		if event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_zoom_en_cursor(1.25)
				MOUSE_BUTTON_WHEEL_DOWN:
					_zoom_en_cursor(0.8)
				MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
					arrastrando = true
				MOUSE_BUTTON_LEFT:
					_seleccionar(get_global_mouse_position())
		else:
			if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
				arrastrando = false
	elif event is InputEventMouseMotion and arrastrando:
		camara.position -= event.relative / camara.zoom.x
		_normalizar_camara()


# ─────────────────────────────────────────────────────────────
# Selección de provincia / país
# ─────────────────────────────────────────────────────────────
func _puntos_anillo(a: Dictionary) -> PackedVector2Array:
	var flat: Array = a["v"]
	var r := PackedVector2Array()
	r.resize(flat.size() >> 1)
	for i in r.size():
		r[i] = Vector2(flat[i * 2], flat[i * 2 + 1])
	return r


func _seleccionar(pos: Vector2) -> void:
	_limpiar_seleccion()
	var p := Vector2(fposmod(pos.x, ANCHO_MAPA), pos.y)
	# Los anillos están ordenados de grande a pequeño: se prueba de pequeño a grande (enclaves primero)
	for i in range(anillos.size() - 1, -1, -1):
		var a: Dictionary = anillos[i]
		var b: Array = a["b"]
		if p.x < b[0] or p.x > b[0] + b[2] or p.y < b[1] or p.y > b[1] + b[3]:
			continue
		if Geometry2D.is_point_in_polygon(p, _puntos_anillo(a)):
			_resaltar(int(a["p"]), String(a["k"]), p)
			return
	panel.visible = false


func _limpiar_seleccion() -> void:
	for n in resaltado:
		n.queue_free()
	resaltado.clear()
	for l in lineas_resaltado:
		l.queue_free()
	lineas_resaltado.clear()
	seleccion_activa = false


func _resaltar(pi: int, continente: String, p: Vector2) -> void:
	var prov: Dictionary = provincias[pi]
	var idx := PackedInt32Array()
	for ri in prov["r"]:
		var a: Dictionary = anillos[int(ri)]
		idx.append_array(indices_fill.slice(int(a["i0"]), int(a["i1"])))
	if idx.size() > 0:
		var malla := _crear_malla(vertices_fill, idx)
		for dx in [-ANCHO_MAPA, 0.0, ANCHO_MAPA]:
			var mi := MeshInstance2D.new()
			mi.mesh = malla
			mi.position = Vector2(dx, 0.0)
			mi.modulate = Color(1.0, 1.0, 1.0, 0.42)
			mi.z_index = 5
			add_child(mi)
			resaltado.append(mi)
	for ri in prov["r"]:
		var pts := _puntos_anillo(anillos[int(ri)])
		pts.append(pts[0])
		for dx in [-ANCHO_MAPA, 0.0, ANCHO_MAPA]:
			var l := Line2D.new()
			l.points = pts
			l.position = Vector2(dx, 0.0)
			l.width = 2.4 / camara.zoom.x
			l.default_color = Color(1.0, 0.85, 0.1, 1.0)
			l.joint_mode = Line2D.LINE_JOINT_ROUND
			l.z_index = 6
			add_child(l)
			lineas_resaltado.append(l)
	seleccion_activa = true

	lbl_nombre.text = String(prov["n"]).to_upper()
	if prov["m"]:
		lbl_tipo.text = "Provincia"
	else:
		lbl_tipo.text = "País"
	lbl_pais.text = "Soberanía: " + String(prov["c"])
	lbl_cont.text = "Continente: " + continente
	lbl_coord.text = "Coordenadas: (X: %s, Y: %s)" % [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]
	panel.visible = true


# ─────────────────────────────────────────────────────────────
# HUD
# ─────────────────────────────────────────────────────────────
func _nueva_etiqueta(tam: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", fuente)
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


func _crear_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20.0
	panel.offset_bottom = -20.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(330.0, 0.0)
	panel.visible = false

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.07, 0.14, 0.95)
	estilo.border_color = Color(0.9, 0.75, 0.2, 1.0)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 18.0
	estilo.content_margin_top = 14.0
	estilo.content_margin_right = 18.0
	estilo.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	lbl_nombre = _nueva_etiqueta(20, Color(1.0, 0.88, 0.3))
	lbl_tipo = _nueva_etiqueta(13, Color(0.7, 0.75, 0.85))
	lbl_pais = _nueva_etiqueta(15, Color.WHITE)
	lbl_cont = _nueva_etiqueta(14, Color(0.75, 0.88, 1.0))
	lbl_coord = _nueva_etiqueta(13, Color(0.45, 0.92, 0.55))
	for l in [lbl_nombre, lbl_tipo, lbl_pais, lbl_cont, lbl_coord]:
		vbox.add_child(l)
	panel.add_child(vbox)
	hud.add_child(panel)

	# Versión + FPS (útil para reportar rendimiento)
	lbl_fps = _nueva_etiqueta(13, Color(1.0, 1.0, 1.0, 0.75))
	lbl_fps.position = Vector2(12.0, 8.0)
	hud.add_child(lbl_fps)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_actualizar_fps)
	add_child(timer)
	_actualizar_fps()


func _actualizar_fps() -> void:
	lbl_fps.text = "v%s  |  %d FPS  |  zoom %.2f" % [VERSION, Engine.get_frames_per_second(), camara.zoom.x]


# ─────────────────────────────────────────────────────────────
# Menú principal: el mapa de fondo (solo colores) y un botón "JUGAR"
# ─────────────────────────────────────────────────────────────
func _crear_menu() -> void:
	hud.visible = false
	menu = CanvasLayer.new()
	menu.layer = 10
	add_child(menu)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(centro)
	var panel_menu := PanelContainer.new()
	panel_menu.custom_minimum_size = Vector2(390.0, 280.0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.055, 0.11, 0.94)
	estilo.border_color = Color(0.9, 0.75, 0.2, 1.0)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 26.0
	estilo.content_margin_top = 24.0
	estilo.content_margin_right = 26.0
	estilo.content_margin_bottom = 24.0
	panel_menu.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel_menu)
	menu_contenido = VBoxContainer.new()
	menu_contenido.add_theme_constant_override("separation", 14)
	panel_menu.add_child(menu_contenido)
	_mostrar_menu_principal()


func _limpiar_menu() -> void:
	for hijo in menu_contenido.get_children():
		menu_contenido.remove_child(hijo)
		hijo.queue_free()


func _titulo_menu(texto: String) -> void:
	var titulo := Label.new()
	titulo.text = texto
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", fuente)
	titulo.add_theme_font_size_override("font_size", 27)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	menu_contenido.add_child(titulo)


func _boton_menu(texto: String, accion: Callable) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0.0, 44.0)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.add_theme_font_override("font", fuente)
	boton.add_theme_font_size_override("font_size", 18)
	boton.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
	boton.pressed.connect(accion)
	menu_contenido.add_child(boton)


func _mostrar_menu_principal() -> void:
	_limpiar_menu()
	_titulo_menu("GRAN ESTRATEGIA")
	_boton_menu("JUGAR", _on_jugar)
	_boton_menu("OPCIONES", _mostrar_opciones)
	_boton_menu("SALIR", _salir_juego)


func _mostrar_opciones() -> void:
	_limpiar_menu()
	_titulo_menu("DATOS DEL MAPA")
	var paises := {}
	var cantidad_provincias := 0
	for provincia in provincias:
		paises[String(provincia.get("c", ""))] = true
		if bool(provincia.get("m", false)):
			cantidad_provincias += 1
	var texto_datos := Label.new()
	texto_datos.add_theme_font_override("font", fuente)
	texto_datos.add_theme_font_size_override("font_size", 17)
	texto_datos.add_theme_color_override("font_color", Color(0.91, 0.93, 0.98))
	texto_datos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_datos.text = "Países / soberanías: %d\nProvincias administrativas: %d\nUnidades territoriales representadas: %d" % [paises.size(), cantidad_provincias, provincias.size()]
	menu_contenido.add_child(texto_datos)
	var nota := Label.new()
	nota.text = "Las provincias son subdivisiones de los países; no se cuentan como países independientes."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.add_theme_font_override("font", fuente)
	nota.add_theme_font_size_override("font_size", 12)
	nota.add_theme_color_override("font_color", Color(0.67, 0.72, 0.82))
	menu_contenido.add_child(nota)
	_boton_menu("VOLVER", _mostrar_menu_principal)


func _on_jugar() -> void:
	en_menu = false
	menu.queue_free()
	hud.visible = true
	_actualizar_zoom()



# ─────────────────────────────────────────────────────────────
# Pausa
# ─────────────────────────────────────────────────────────────
func _mostrar_menu_pausa() -> void:
	if en_menu or en_pausa:
		return
	en_pausa = true
	arrastrando = false
	get_tree().paused = true

	menu_pausa = CanvasLayer.new()
	menu_pausa.layer = 20
	menu_pausa.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_pausa)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_pausa.add_child(centro)

	var panel_pausa := PanelContainer.new()
	panel_pausa.custom_minimum_size = Vector2(390.0, 250.0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.055, 0.11, 0.96)
	estilo.border_color = Color(0.9, 0.75, 0.2, 1.0)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 26.0
	estilo.content_margin_top = 24.0
	estilo.content_margin_right = 26.0
	estilo.content_margin_bottom = 24.0
	panel_pausa.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel_pausa)

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 14)
	panel_pausa.add_child(contenido)

	var titulo := Label.new()
	titulo.text = "JUEGO EN PAUSA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", fuente)
	titulo.add_theme_font_size_override("font_size", 27)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	contenido.add_child(titulo)

	_boton_pausa(contenido, "CONTINUAR", _reanudar_juego)
	_boton_pausa(contenido, "MENÚ PRINCIPAL", _volver_menu_principal)
	_boton_pausa(contenido, "SALIR", _salir_juego)


func _boton_pausa(contenedor: VBoxContainer, texto: String, accion: Callable) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0.0, 44.0)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.add_theme_font_override("font", fuente)
	boton.add_theme_font_size_override("font_size", 18)
	boton.add_theme_color_override("font_color", Color(0.94, 0.95, 1.0))
	boton.pressed.connect(accion)
	contenedor.add_child(boton)


func _reanudar_juego() -> void:
	get_tree().paused = false
	en_pausa = false
	if is_instance_valid(menu_pausa):
		menu_pausa.queue_free()
	menu_pausa = null
	hud.visible = true
	_actualizar_zoom()


func _volver_menu_principal() -> void:
	get_tree().paused = false
	en_pausa = false
	if is_instance_valid(menu_pausa):
		menu_pausa.queue_free()
	menu_pausa = null
	_limpiar_seleccion()
	panel.visible = false
	hud.visible = false
	en_menu = true
	_crear_menu()
	_actualizar_zoom()


func _salir_juego() -> void:
	get_tree().quit()
