extends Node2D
## Gran Estrategia - mapa mundial (v0.1.7.9)
##
## RENDIMIENTO: todo lo pesado (triangulación, colores, bordes, posición de nombres) se calcula UNA vez fuera de Godot
## con herramientas/construir_mapa.py y se guarda en datos/. Desde 0.1.7.9 las mallas grandes están partidas en TESELAS
## (cuadrícula de 300x300 unidades): cada tesela es un nodo independiente y Godot descarta las que no se ven.
## Los nombres de provincia/estado y las ciudades también se agrupan por tesela y solo existen cuando se necesitan.

const E := preload("res://scripts/entidades.gd")
const HudScript := preload("res://scripts/hud.gd")
const RelojScript := preload("res://scripts/reloj.gd")
const BDScript := preload("res://scripts/base_datos.gd")
const DebugScript := preload("res://scripts/debug_menu.gd")
const PersonalizarScript := preload("res://scripts/personalizar_pais.gd")
const CapaTropasScript := preload("res://scripts/capa_tropas.gd")
const FusionScript := preload("res://scripts/fusion_mapa.gd")
const TerritorioScript := preload("res://scripts/territorio.gd")
const TemaHud := preload("res://scripts/tema_hud.gd")
const RankingScript := preload("res://scripts/ranking.gd")
const PopupGuerraScript := preload("res://scripts/popup_guerra.gd")
const AjustesScript := preload("res://scripts/ajustes.gd")
const MenuPantallaScript := preload("res://scripts/menu_pantalla.gd")
const PerfilScript := preload("res://scripts/perfil.gd")

const VERSION := "0.1.8.37"
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
# < ZOOM_CONTINENTE_MAX el clic elige continente; por encima elige país. Las provincias se ven con DOBLE CLIC sobre un país.
const ZOOM_CONTINENTE_MAX := 1.3
const ZOOM_PROVINCIAS_TODAS_INI := 0.7   # campaña: los contornos de provincia aparecen suaves desde aquí...
const ZOOM_PROVINCIAS_TODAS_FIN := 2.0   # ...y llegan a su opacidad plena aquí
const ZOOM_PROVINCIAS := 4.2       # a partir de aquí los nombres de país ceden paso a los de subdivisión

# Grosores de línea EN PANTALLA (píxeles). Se convierten a unidades de mapa con el zoom REAL de cada fotograma,
# así el grosor es idéntico a cualquier distancia.
# Grosores en PÍXELES de pantalla (iguales a cualquier zoom). Costa = contorno de los continentes: la línea más gruesa y negra; la línea entre
# continentes (cont) es un poco más angosta; la frontera entre países (frontera) es una franja negra/clara.
const GROSOR_PX := {"costa": 2.8, "cont": 1.8, "frontera": 2.6, "prov": 1.4, "estado": 2.4, "prov_todas": 1.0}
## 0.1.8.37 · Bordes HD (Opciones > Pantalla > Bordes del mapa): píxeles extra de malla a cada lado para suavizar el borde de la línea, y la sombra suave de la
## costa (solo Alta). Baja = 0 px = borde duro de siempre (el más barato).
const BORDE_EXT_PX := [0.0, 0.8, 2.0]
const BORDE_HALO := [0.0, 0.0, 0.16]
const PERIODO_FRANJA_PX := 9.0     # largo de cada franja de la frontera continental (en pantalla)
const PERIODO_FRONTERA_PX := 8.0   # largo de cada franja de la frontera entre países (negro + claro)
const NEGRO_FRONTERA := 0.60       # fracción de cada franja de frontera que es línea negra (el resto es hueco transparente)

# Pop-out al hacer clic en un país (0.1.8.2a: antes era doble clic)
const FOCO_DERECHA := 0.17         # el país se coloca a esta fracción del ancho a la derecha del centro de pantalla
const TESELA := 300.0

# Espaciado máximo permitido entre letras según el tipo de nombre (c=continente, p=país, m=país con subdivisiones,
# v=provincia, e=estado)
const ESPACIADO_MAX := {"c": 3.4, "p": 2.0, "m": 2.2, "v": 1.5, "e": 1.8}



const SHADER_BORDE := """
shader_type canvas_item;
uniform float half_width = 0.5;
uniform vec4 col : source_color = vec4(0.04, 0.05, 0.09, 1.0);
uniform float alfa = 1.0;
uniform float nucleo = 1.0;                     // 0.1.8.37: medio grosor de la línea, en píxeles de pantalla
uniform float ext_px = 0.0;                     // píxeles extra de malla a cada lado para el suavizado (0 = calidad Baja: borde duro de siempre)
uniform float halo = 0.0;                       // calidad Alta: intensidad de la sombra suave que rodea la línea
void vertex() {
	VERTEX += UV * half_width;
}
void fragment() {
	float a = 1.0;
	if (ext_px > 0.0) {
		float d = length(UV) * (nucleo + ext_px);
		a = clamp(nucleo - d + 0.5, 0.0, 1.0);
		a = max(a, halo * (1.0 - smoothstep(nucleo, nucleo + ext_px, d)));
	}
	COLOR = vec4(col.rgb, col.a * alfa * a);
}
"""

# Frontera continental: mismo grosor que la costa pero con patrón de franjas (oscuro / claro).
# La distancia recorrida viene codificada en el color del vértice (2 canales) y se decodifica en vertex().
const SHADER_BORDE_FRANJA := """
shader_type canvas_item;
uniform float half_width = 0.5;
uniform float periodo = 4.0;
uniform float negro = 0.5;                      // fracción de cada periodo que usa `col` (el resto usa `col2`)
uniform vec4 col : source_color = vec4(0.04, 0.05, 0.09, 1.0);
uniform vec4 col2 : source_color = vec4(0.93, 0.90, 0.78, 1.0);
uniform float alfa = 1.0;
uniform float nucleo = 1.0;                     // 0.1.8.37: ver SHADER_BORDE
uniform float ext_px = 0.0;
varying float recorrido;
void vertex() {
	recorrido = (COLOR.r * 255.0 * 255.0 + COLOR.g * 255.0) / 20.0;
	VERTEX += UV * half_width;
}
void fragment() {
	float f = fract(recorrido / periodo);
	vec3 c = f < negro ? col.rgb : col2.rgb;
	float a = 1.0;
	if (ext_px > 0.0) {
		a = clamp(nucleo - length(UV) * (nucleo + ext_px) + 0.5, 0.0, 1.0);
	}
	COLOR = vec4(c, alfa * a);
}
"""

## Frontera entre países (0.1.8): trozos NEGROS separados por huecos TRANSPARENTES, así por los huecos asoma el color de cada país
## (la línea queda centrada en la frontera: una mitad sobre un país y la otra mitad sobre el vecino). Los bordes de cada trozo se suavizan 1 px.
const SHADER_BORDE_FRANJA_ABIERTA := """
shader_type canvas_item;
uniform float half_width = 0.5;
uniform float periodo = 4.0;
uniform float negro = 0.6;                      // fracción de cada periodo que es línea negra (el resto es hueco transparente)
uniform float suave = 0.12;                     // ancho del suavizado, como fracción del periodo (1 píxel de pantalla)
uniform vec4 col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float alfa = 1.0;
uniform float nucleo = 1.0;                     // 0.1.8.37: ver SHADER_BORDE
uniform float ext_px = 0.0;
varying float recorrido;
void vertex() {
	recorrido = (COLOR.r * 255.0 * 255.0 + COLOR.g * 255.0) / 20.0;
	VERTEX += UV * half_width;
}
void fragment() {
	float f = fract(recorrido / periodo);
	float a = smoothstep(0.0, suave, f) * (1.0 - smoothstep(negro - suave, negro, f));
	if (ext_px > 0.0) {
		a *= clamp(nucleo - length(UV) * (nucleo + ext_px) + 0.5, 0.0, 1.0);
	}
	COLOR = vec4(col.rgb, alfa * a);
}
"""

# 0.1.7.9.1: colores SÓLIDOS. Cada país y provincia lleva el color de su continente a cualquier zoom (sin degradados,
# sin apagado por zoom). Las mallas ya traen el color por vértice, así que el mapa se dibuja sin shader.

# Silueta del país que "salta" (pop-out): mismo degradado tonal que el mapa pero un poco más luminosa
# Silueta del país que "salta" (pop-out): color sólido, igual al del mapa
const SHADER_POPOUT := """
shader_type canvas_item;
uniform vec4 base : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float sombra = 0.0;
void fragment() {
	if (sombra > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.45);
	} else {
		COLOR = vec4(base.rgb, 1.0);   // color sólido: el mismo del continente
	}
}
"""



# Marcadores de ciudad: un cuadrado por ciudad (4 vértices en el mismo punto). UV = esquina * (zoom mínimo | 1 + rango/2).
const SHADER_CIUDAD := """
shader_type canvas_item;
uniform float zoom = 1.0;
varying vec2 ev;
varying float rank_v;
varying float fill_f;
void vertex() {
	vec2 corner = sign(UV);
	float zmin = abs(UV.x);
	float rank = abs(UV.y) - 1.0;
	float r = 3.2;
	if (rank > 0.75) {
		r += 1.6;
	} else if (rank > 0.25) {
		r += 0.6;
	}
	float R = r + 1.3;
	float on = step(zmin, zoom);
	VERTEX += corner * R * on / zoom;
	ev = corner;
	rank_v = rank;
	fill_f = r / R;
}
void fragment() {
	float d = length(ev);
	float aa = 0.10;
	vec3 base = COLOR.rgb;
	vec3 borde = vec3(0.03, 0.05, 0.09);
	float dentro = 1.0 - smoothstep(fill_f - aa, fill_f, d);
	vec3 c = mix(borde, base, dentro);
	if (rank_v > 0.75) {
		float k = 1.0 - smoothstep(fill_f * 0.42 - aa, fill_f * 0.42, d);
		c = mix(c, vec3(0.75, 0.15, 0.15), k);
	}
	COLOR = vec4(c, 0.95 * (1.0 - smoothstep(1.0 - aa, 1.0, d)));
}
"""


# Mar con profundidad real (batimetría): textura RG8 (R = nivel 0..11, G = distancia a la costa)
const SHADER_MAR := """
shader_type canvas_item;
uniform sampler2D prof : filter_linear_mipmap, repeat_enable;
uniform float zoom = 1.0;
uniform float niveles = 11.0;
uniform float dist_max = 64.0;
const vec3 RAMPA[12] = vec3[12](
	vec3(0.30, 0.68, 0.76), vec3(0.17, 0.51, 0.66), vec3(0.11, 0.39, 0.58), vec3(0.085, 0.31, 0.52),
	vec3(0.065, 0.25, 0.46), vec3(0.05, 0.20, 0.40), vec3(0.04, 0.16, 0.34), vec3(0.032, 0.125, 0.285),
	vec3(0.026, 0.10, 0.235), vec3(0.021, 0.08, 0.195), vec3(0.017, 0.06, 0.16), vec3(0.014, 0.05, 0.13));
void fragment() {
	vec2 uv = vec2(UV.x * 3.0, UV.y);
	vec2 d = texture(prof, uv).rg;
	float t = d.r * niveles;
	int i = clamp(int(floor(t)), 0, 10);
	vec3 c = mix(RAMPA[i], RAMPA[i + 1], t - float(i));
	// Viñeta costera: luz turquesa junto a la costa que se apaga mar adentro (ancho ~constante en pantalla)
	float ancho = clamp(14.0 / zoom, 2.0, 60.0);
	float dc = d.g * dist_max;
	float halo = pow(1.0 - smoothstep(0.0, ancho, dc), 1.6);
	c = mix(c, vec3(0.50, 0.84, 0.88), halo * 0.42);
	// Curvas batimétricas suaves (cada nivel de profundidad)
	float w = max(fwidth(t) * 1.3, 0.02);
	float linea = 1.0 - smoothstep(0.0, w, abs(fract(t + 0.5) - 0.5));
	c += vec3(0.05, 0.09, 0.10) * linea * smoothstep(0.9, 2.4, zoom) * 0.8;
	COLOR = vec4(c, 1.0);
}
"""

func _construir_mar() -> void:
	var bytes := _leer_bytes("profundidad.bin")
	if bytes.size() != 4096 * 2048 * 2:
		push_warning("profundidad.bin no encontrado o con tamaño incorrecto; se usa el fondo liso")
		return
	var img := Image.create_from_data(4096, 2048, false, Image.FORMAT_RG8, bytes)
	img_prof = Image.create_from_data(4096, 2048, false, Image.FORMAT_RG8, bytes)   # copia sin mipmaps para leer profundidades
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var sh := Shader.new()
	sh.code = SHADER_MAR
	mat_mar = ShaderMaterial.new()
	mat_mar.shader = sh
	mat_mar.set_shader_parameter("prof", tex)
	capa_mar = ColorRect.new()
	capa_mar.position = Vector2(-ANCHO_MAPA, 0.0)
	capa_mar.size = Vector2(ANCHO_MAPA * 3.0, 1200.0)
	capa_mar.material = mat_mar
	capa_mar.color = Color.WHITE
	capa_mar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_mar.z_index = -1
	add_child(capa_mar)




# ── 0.1.8.35 · TEXTURAS DEL TERRENO ────────────────────────────────────────────────────────────────────────────────────────────────────
# Gancho para el relieve (o cualquier textura del mundo en proyección equirectangular, de borde a borde: x = longitud, y = latitud). Se MULTIPLICA sobre los
# colores de las provincias dentro del propio relleno, así que no añade capas ni triángulos y sigue valiendo aunque las provincias cambien de forma.
#   · Sin textura el relleno no lleva material (como siempre): coste cero.
#   · Con textura, el relleno usa SHADER_RELIEVE. El gris `neutro` de la imagen no cambia el color; más claro lo aclara y más oscuro lo oscurece.
#   · `fuerza` 0..1 dosifica el efecto. La calidad Baja lo apaga (Opciones > Pantalla).
#   · Automático: si existe datos/texturas/relieve.png se carga al abrir el mapa (herramientas/preparar_relieve.py la prepara con el gris neutro correcto).
const SHADER_RELIEVE := """
shader_type canvas_item;
uniform sampler2D relieve : filter_linear_mipmap, repeat_enable;
uniform float fuerza = 0.6;
uniform float neutro = 0.5;
uniform vec2 mapa = vec2(2400.0, 1200.0);
varying vec2 pm;
void vertex() {
	pm = VERTEX;
}
void fragment() {
	float r = dot(texture(relieve, pm / mapa).rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb *= mix(1.0, r / max(neutro, 0.01), fuerza);
}
"""
const RUTA_RELIEVE := "res://datos/texturas/relieve.png"
const RELIEVE_FUERZA := 0.6
var mat_relieve: ShaderMaterial                      # null mientras no haya textura
var textura_relieve: Texture2D
var q_relieve := true                                # la calidad gráfica permite el relieve (la Baja no)


## Pone (o quita, con null) la textura del terreno. `neutro`: luminosidad de la imagen que no cambia el color (0,5 si la preparó herramientas/preparar_relieve.py).
func poner_textura_relieve(tex: Texture2D, fuerza := RELIEVE_FUERZA, neutro := 0.5) -> void:
	textura_relieve = tex
	if tex == null:
		mat_relieve = null
	else:
		if mat_relieve == null:
			var sh := Shader.new()
			sh.code = SHADER_RELIEVE
			mat_relieve = ShaderMaterial.new()
			mat_relieve.shader = sh
		mat_relieve.set_shader_parameter("relieve", tex)
		mat_relieve.set_shader_parameter("fuerza", clampf(fuerza, 0.0, 1.0))
		mat_relieve.set_shader_parameter("neutro", clampf(neutro, 0.05, 0.95))
		mat_relieve.set_shader_parameter("mapa", Vector2(ANCHO_MAPA, 1200.0))
	_aplicar_relieve()


## Enchufa (o quita) el material del relieve en todo el relleno según haya textura y la calidad lo permita.
func _aplicar_relieve() -> void:
	if fusion == null:
		return
	var mat: ShaderMaterial = mat_relieve if (mat_relieve != null and q_relieve) else null
	for t in fusion.teselas:
		for mi in t["inst"]:
			(mi as MeshInstance2D).material = mat


## Carga datos/texturas/relieve.png si existe (se llama al abrir el mapa).
func _cargar_relieve_archivo() -> void:
	# Sin archivo no hay textura (caso normal hoy): salir antes de intentar leerlo para no llenar el registro de errores
	if not ResourceLoader.exists(RUTA_RELIEVE) and not FileAccess.file_exists(RUTA_RELIEVE):
		return
	var tex0: Texture2D = _cargar_png(RUTA_RELIEVE)
	if tex0 == null:
		return
	var img: Image = tex0.get_image()
	if img == null or img.is_empty():
		poner_textura_relieve(tex0)
		return
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	poner_textura_relieve(ImageTexture.create_from_image(img))


# ── 0.1.8.37 · VISTA «RELIEVE» ────────────────────────────────────────────────────────────────────────────────────────────────────────
# El mapa entero se pinta con una imagen ya preparada (herramientas/preparar_relieve_vista.py, a partir de ETOPO 2022 y Natural Earth): tierra por altura
# (verde azulado abajo → verdes → ocres → marrones arriba), mar por profundidad con su propia paleta, hielo y lagos. Es UNA capa rectangular encima del
# relleno y el mar (que se apagan mientras tanto, así no cuesta de más); las costas, fronteras, nombres y la selección se dibujan encima como siempre.
# La imagen se elige con la calidad gráfica: Alta 8192 px, Media 4096 px, Baja 2048 px. Se carga la primera vez que se enciende la vista.
const SHADER_RELIEVE_VISTA := """
shader_type canvas_item;
uniform sampler2D relieve : filter_linear_mipmap, repeat_enable;
uniform vec2 mapa = vec2(2400.0, 1200.0);
uniform vec2 desp = vec2(0.0);
varying vec2 pm;
void vertex() {
	pm = VERTEX + desp;
}
void fragment() {
	COLOR = vec4(texture(relieve, vec2(pm.x / mapa.x, clamp(pm.y / mapa.y, 0.0005, 0.9995))).rgb, 1.0);
}
"""
const RELIEVE_CONTORNO_TEXTO := 10                      # grosor del contorno de los nombres sobre el relieve (puntos de la fuente base)
const RELIEVE_VISTA_TAMANOS := [8192, 4096, 2048]     # de más a menos detalle
const RUTA_RELIEVE_VISTA := "res://datos/texturas/relieve_vista_%d.jpg"
var capa_relieve_vista: ColorRect                       # null hasta que se enciende la vista por primera vez
var mat_rel_mundo: ShaderMaterial                       # el rectángulo que cubre el mundo (y sus dos copias a los lados)
var mat_rel_sil: ShaderMaterial                         # la silueta del país enfocado, con la misma imagen
var tex_relieve_vista: Texture2D
var relieve_vista_tam := 0                              # ancho en píxeles de la imagen cargada (0 = ninguna)
var foco_sil: MeshInstance2D                            # la silueta del país enfocado (para pintarla con el relieve)


## Tamaño de imagen que pide la calidad gráfica vigente: Alta 8192, Media 4096, Baja 2048 (personalizada: 4096).
func _tam_relieve_pedido() -> int:
	var q := AjustesScript.preset_de(ajustes)
	return int(RELIEVE_VISTA_TAMANOS[q]) if q >= 0 and q < RELIEVE_VISTA_TAMANOS.size() else 4096


## Carga (o cambia) la imagen del relieve según la calidad. Si falta el archivo pedido usa el de menos detalle que sí exista, y si no hay ninguno devuelve false.
func _preparar_relieve_vista() -> bool:
	var pedido := _tam_relieve_pedido()
	var orden: Array = [pedido]
	for t in RELIEVE_VISTA_TAMANOS:
		if int(t) < pedido:
			orden.append(int(t))
	for t in RELIEVE_VISTA_TAMANOS:
		if int(t) > pedido:
			orden.append(int(t))
	var tam := 0
	for t in orden:
		var ruta: String = RUTA_RELIEVE_VISTA % int(t)
		if ResourceLoader.exists(ruta) or FileAccess.file_exists(ruta):
			tam = int(t)
			break
	if tam == 0:
		return false
	if tex_relieve_vista != null and relieve_vista_tam == tam:
		return true
	var tex0: Texture2D = _cargar_png(RUTA_RELIEVE_VISTA % tam)
	if tex0 == null:
		return false
	var img: Image = tex0.get_image()
	if img == null or img.is_empty():
		return false
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	tex_relieve_vista = ImageTexture.create_from_image(img)
	relieve_vista_tam = tam
	if mat_rel_mundo == null:
		var sh := Shader.new()
		sh.code = SHADER_RELIEVE_VISTA
		mat_rel_mundo = ShaderMaterial.new()
		mat_rel_mundo.shader = sh
		mat_rel_mundo.set_shader_parameter("mapa", Vector2(ANCHO_MAPA, 1200.0))
		mat_rel_mundo.set_shader_parameter("desp", Vector2(-ANCHO_MAPA, 0.0))
		mat_rel_sil = ShaderMaterial.new()
		mat_rel_sil.shader = sh
		mat_rel_sil.set_shader_parameter("mapa", Vector2(ANCHO_MAPA, 1200.0))
	mat_rel_mundo.set_shader_parameter("relieve", tex_relieve_vista)
	mat_rel_sil.set_shader_parameter("relieve", tex_relieve_vista)
	if capa_relieve_vista == null:
		capa_relieve_vista = ColorRect.new()
		capa_relieve_vista.position = Vector2(-ANCHO_MAPA, 0.0)
		capa_relieve_vista.size = Vector2(ANCHO_MAPA * 3.0, 1200.0)
		capa_relieve_vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa_relieve_vista.z_index = 1                    # encima del relleno y de los lagos (mismo z, más tarde en el árbol) y debajo de costas y fronteras
		capa_relieve_vista.material = mat_rel_mundo
		capa_relieve_vista.visible = false
		add_child(capa_relieve_vista)
	return true


## Deja visibles las capas que toca según la vista: con el relieve puesto el relleno y el mar quedan apagados (los tapa la imagen) y la silueta del país
## enfocado se pinta con la misma imagen.
func _aplicar_capas_relieve() -> void:
	var activo := modo_relieve and capa_relieve_vista != null
	if capa_relieve_vista != null:
		capa_relieve_vista.visible = activo
	if activo:
		if capa_pais != null:
			capa_pais.visible = false
		if capa_mar != null:
			capa_mar.visible = false
	if is_instance_valid(foco_sil):
		foco_sil.material = mat_rel_sil if activo else foco_sil.get_meta("mat_pais")
	CapaTexto.poner_contorno(RELIEVE_CONTORNO_TEXTO if activo else 0)


@onready var camara: Camera2D = $Camera2D

var fuente: SystemFont
var fuente_ui: Font                 # fuente de los HUD y menús (Inter, incluida en res://fuentes/): neutra y legible
var fuente_ui_neg: Font             # la misma en seminegrita (títulos y cifras)
var fuente_ciudad: SystemFont
const CLIC_DER_MAX_MS := 350      # 0.1.8.2a: un clic derecho largo es mover la cámara, no una orden (evita mandar tropas sin querer)
var _der_t0 := 0
const CLIC_DER_MAX_PX := 6.0       # un clic derecho que se movió menos que esto NO es un arrastre de cámara
var arrastrando := false
var _drag_tropas := {}              # arrastre de un cuadrito de tropas con el botón izquierdo: {prov, pais, px0, activo}
var _arrastre_px := 0.0            # píxeles arrastrados con el botón derecho (si casi no se movió, es un CLIC derecho = orden de mover tropas)

# Datos de provincias (para clic y HUD)
var provincias: Array = []
var anillos: Array = []
var vertices_fill := PackedVector2Array()      # se cargan bajo demanda (primer clic)
var indices_fill := PackedInt32Array()
var fill_cargado := false
var teselas: Dictionary = {}

# Datos generales
var info: Dictionary = {}
var mares: Array = []
var img_prof: Image
var economia: Dictionary = {}
var banderas: Dictionary = {}
var mundo                      # E.Mundo
var estados_json: Dictionary = {}
var ciudades_capas: Array = []
var mundo_pob := 0.0
var mundo_area := 0.0

# Capas del mapa
var capa_pais: Node2D
var capa_mar: ColorRect
var capa_lagos: Array = []
var mat_mar: ShaderMaterial
var capa_costa: Node2D
var capas_costa: Array = []           # [detalle completo, intermedio, lejano]: la costa se dibuja con menos segmentos al alejar el zoom
var costa_nivel := -1                 # nivel de detalle de la costa que se está mostrando
const COSTA_ZOOM_NIVEL1 := 2.4        # por debajo de este zoom REAL (px por unidad) basta el nivel intermedio (error <= ~1 px)
const COSTA_ZOOM_NIVEL2 := 1.0        # por debajo de este, el lejano
var capa_frontera: Node2D
var capa_cont: Array = []
var capa_ea: Array = []                          # línea Europa–Asia (solo al acercar)
var mat_costa: ShaderMaterial
var mat_frontera: ShaderMaterial
var mat_prov: ShaderMaterial
var mat_prov_todas: ShaderMaterial               # 0.1.8.2a: contornos de provincia de TODOS los países (campaña), más suaves que los del país enfocado
var capa_prov_todas: Node2D
var grupo_vecinos: Node2D                        # 0.1.8.2a: contornos (sin nombres) de las provincias de los países vecinos al enfocado
var mat_estado: ShaderMaterial
var mat_cont: ShaderMaterial
var mat_ea: ShaderMaterial
var mat_popout: ShaderMaterial
var mat_ciudad: ShaderMaterial

# Capas de texto globales (países, continentes)
var capas_texto: Array = []

# Foco de país (un clic)
var vista := "tradicional"        # "tradicional" | "internacional"
var modo_relieve := false         # 0.1.8.37 · el mapa se ve como relieve (alturas y fondos marinos) en vez de colores por país
var pais_foco := ""
var grupo_pop: Node2D
var dim_overlay: ColorRect
var foco_lineas_prov: Array = []
var foco_lineas_estado: Array = []
var capas_prov_texto: Array = []
var capas_estado_texto: Array = []
var et_prov: Dictionary = {}
var et_estado: Dictionary = {}
var estado_bytes := {}
var estado_rangos: Dictionary = {}
var foco_dx := 0.0
var foco_centro := Vector2.ZERO
var tween_cam: Tween
var tween_pop: Tween
var col_pais_hex: Dictionary = {}
var col_hex_continente: Dictionary = {}   # color de continente de cada país tal como viene de los datos (0.1.8.2a: base de los tonos del modo dev)

# Selección
var resaltado: Array = []
var lineas_resaltado: Array = []
var sel_tipo := ""
var sel_ref := {}

# HUD
var hud
var zoom_aplicado := -1.0
var tex_cache: Dictionary = {}

# Menú
var en_menu := true
var en_pausa := false
var reloj                      # RelojScript
var debug_menu                 # DebugScript (overlay, mientras está abierto)
var panel_pers                 # PersonalizarScript (ventana "Mi país", mientras está abierta)
var capa_tropas                # CapaTropasScript: cuadritos de tropas y columnas en marcha sobre el mapa (0.1.7.9.9E)
var panel_ordenes:                # manejo de tropas (scripts/hud_tropas.gd): vive DENTRO del HUD de país (pestaña Militar); este atajo lo devuelve
	get:
		return hud.tropas if hud != null else null
var orden_mover := {}          # {"reg": ID, "n": soldados, "grupo": [IDs] (si son varios)} mientras se elige la provincia de destino
var _t_hover_dest := 0
var fusion                     # FusionScript: relleno por dueño y fronteras desde los dueños actuales (0.1.7.9.9F; desde 0.1.8.35 por celdas)
var territorio                 # TerritorioScript (0.1.8.35): la forma de las provincias (qué celdas son de cuál) y las operaciones para cambiarla
var _ver_dueno := -1           # versión de `propietario` con la que está pintado el mapa
var _ver_ocup := -1            # versión de `ocupante` con la que está pintado el mapa (0.1.8.1)
const OCUP_BASE := 700000000   # IDs «virtuales» de dueño para pintar las provincias ocupadas: OCUP_BASE + dueño × OCUP_MOD + ocupante
const OCUP_MOD := 10000
var _ix_prov := PackedInt32Array()          # índice de provincia -> posición en las columnas de la base
var _col_dueno := {}           # ID de dueño -> Color (se arma bajo demanda)
var _dueno_ahora := PackedInt32Array()      # dueño de cada provincia en el último repintado
var etiq_pais := {}            # país -> [[CapaTexto, primer carácter, último carácter]] de su nombre horneado
var etiq_dinamicas: Array = [] # cubos de nombres calculados para países cuyo territorio cambió
var _registrar_etiq := false
var _etiq_ocultas := {}         # países cuyo nombre horneado está oculto
var vel_previa := 1            # velocidad antes de pausar con Espacio
var _t_fin := 0.0              # reloj para refrescar las finanzas del panel abierto mientras pasan los días
var menu: CanvasLayer
## 0.1.8.34 · ESCENARIOS: 2026 (los datos de siempre, datos/) y el año 1 d. C. (datos/epocas/1dc/) son el MISMO juego con otros datos de partida:
## provincias, naciones, población, economía, ejércitos, ciudades y banderas. Un escenario es una carpeta con los mismos archivos que datos/;
## lo que no trae (el mar, la profundidad, los lagos, el catálogo de variables) se lee de datos/. Las mecánicas (HUD, economía, guerra, IA) son las mismas.
const EPOCA_ACTUAL := 2026
const EPOCAS_DIR := {1: "res://datos/epocas/1dc/"}   # año del escenario -> carpeta (2026 usa datos/ directamente)
var epoca := EPOCA_ACTUAL                           # año del escenario cargado (el reloj empieza el 1 de enero de ese año)
var epoca_dir := ""                                 # "" = datos/ · si no, la carpeta del escenario (termina en «/»)
var epoca_meta: Dictionary = {}                     # epoca.json del escenario: nombre, descripción y créditos de sus fuentes
var esquema_propio := false                         # el escenario trae el color de cada nación (entidades.json: esquema_colores = «propio»)
var panel_menu_nodo: PanelContainer
var partida_activa := ""              # "" = todavía no se empezó ninguna partida · "dev" · "campana"
var _sel_pais_campana: OptionButton
var _paises_campana_lista: Array = []
var campana_activa := false           # (campaña) la cámara se limita al territorio de la campaña y fuera de él solo hay vacío
var campana_rect := Rect2()           # territorio de la campaña en coordenadas del mapa (Chukotka queda a la derecha de x = 2400)
var campana_zoom_min := 0.55
var panel_ranking                     # RankingScript (ventana, mientras está abierta)
var popup_guerra                      # PopupGuerraScript (0.1.8.2a): avisos «te declararon la guerra» y «fin de la guerra»; se crea al primer aviso
var _vel_aviso := 1                   # velocidad que llevaba el juego cuando salió el aviso (0 = ya estaba en pausa)
var etiq_cont := {}                   # continente -> [[CapaTexto, primer carácter, último carácter]] de su nombre horneado
var menu_contenido: VBoxContainer
var menu_pausa: CanvasLayer


# ─────────────────────────────────────────────────────────────
# Capa de texto: dibuja letra por letra, cada una rotada siguiendo la forma del territorio
# ─────────────────────────────────────────────────────────────
class CapaTexto extends Node2D:
	var fuente: Font
	var desplazamientos: Array = [-2400.0, 0.0, 2400.0]
	var chars := PackedStringArray()
	var pos := PackedVector2Array()
	var ang := PackedFloat32Array()
	var esc := PackedFloat32Array()
	var anc := PackedFloat32Array()
	var cols := PackedColorArray()
	var cols0 := PackedColorArray()                    # colores originales (para volver a mostrar lo que se ocultó)

	func agregar(c: String, p: Vector2, a: float, e: float, w48: float, col: Color) -> void:
		chars.append(c)
		pos.append(p)
		ang.append(a)
		esc.append(e)
		anc.append(w48)
		cols.append(col)
		cols0.append(col)

	## Muestra u oculta los caracteres [i0, i1) (el nombre de un país cuyo territorio ya no es el original).
	func fijar_visible(i0: int, i1: int, visible_: bool) -> void:
		for i in range(i0, i1):
			cols[i] = cols0[i] if visible_ else Color(cols0[i], 0.0)
		queue_redraw()

	## 0.1.8.37 · Contorno de las letras (en puntos de la fuente base de 48): 0 = sin contorno. La vista de relieve lo enciende para que los nombres se lean sobre
	## cualquier color de terreno; el contorno es oscuro si la letra es clara y claro si la letra es oscura.
	static var contorno := 0
	static var capas_vivas: Array = []                 # todas las capas de texto (para pedirles que se redibujen al cambiar el contorno)

	func _init() -> void:
		capas_vivas.append(self)

	func _exit_tree() -> void:
		capas_vivas.erase(self)

	static func poner_contorno(px: int) -> void:
		if px == contorno:
			return
		contorno = px
		for c in capas_vivas:
			if is_instance_valid(c):
				(c as Node2D).queue_redraw()

	func _draw() -> void:
		for dx in desplazamientos:
			for i in chars.size():
				draw_set_transform(pos[i] + Vector2(dx, 0.0), ang[i], Vector2(esc[i], esc[i]))
				var x0 := Vector2(-anc[i] * 0.5, 17.0)
				if contorno > 0 and cols[i].a > 0.01:
					var claro := cols[i].get_luminance() > 0.5
					draw_char_outline(fuente, x0, chars[i], 48, contorno, Color(0.04, 0.06, 0.09, 0.8 * cols[i].a) if claro else Color(0.98, 0.96, 0.9, 0.75 * cols[i].a))
				draw_char(fuente, x0, chars[i], 48, cols[i])


# ─────────────────────────────────────────────────────────────
# Ciudades: los marcadores son UNA malla por tesela (el shader los mantiene a tamaño constante en pantalla) y los
# nombres se dibujan en dos pasadas (todos los contornos, luego todos los textos) para que Godot los agrupe en pocas
# llamadas de dibujo. Antes: 2 círculos + 2 textos sueltos por ciudad = miles de llamadas en zoom alto.
# ─────────────────────────────────────────────────────────────
class CapaCiudades extends Node2D:
	var fuente: Font
	var items: Array = []         # [pos, nombre, pob, zmin, rango, id] ordenado por población descendente
	var zoom := 1.0
	var dibujado := -1.0
	var area := Rect2()                   # zona (coordenadas locales de la capa) de la que se dibujan nombres: la pantalla con margen
	var marcas: MeshInstance2D

	static var ms_dibujo := 0.0           # tiempo acumulado de los _draw de ciudades desde la última lectura (para medir rendimiento)
	static var n_dibujos := 0

	func pintar(z: float, area_: Rect2) -> void:
		zoom = z
		dibujado = z
		area = area_
		queue_redraw()

	func _draw() -> void:
		if zoom <= 0.0:
			return
		var t0 := Time.get_ticks_usec()
		var k := 1.0 / zoom
		var visibles: Array = []
		# Colisión entre nombres con una REJILLA (antes cada nombre se comparaba con todos los ya puestos: con zoom alto, cientos de nombres por
		# tesela = decenas de ms por redibujo y tirones al hacer zoom). Casillas de 96 × 32 px: un nombre cae en 2-4 casillas.
		var rejilla := {}
		for it in items:
			var zmin: float = it[3]
			if zoom < zmin * 1.25:
				continue
			var p: Vector2 = it[0]
			if not area.has_point(p):
				continue                                  # fuera de la pantalla (con margen): no se dibuja ni se compara
			var nombre: String = it[1]
			var ancho := nombre.length() * 6.4 + 10.0
			var rect := Rect2(p.x * zoom + 7.0, p.y * zoom - 8.0, ancho, 16.0)
			var cx0 := int(floorf(rect.position.x / 96.0))
			var cx1 := int(floorf(rect.end.x / 96.0))
			var cy0 := int(floorf(rect.position.y / 32.0))
			var cy1 := int(floorf(rect.end.y / 32.0))
			var libre := true
			for cx in range(cx0, cx1 + 1):
				for cy in range(cy0, cy1 + 1):
					var celda = rejilla.get(Vector2i(cx, cy))
					if celda != null:
						for o in celda:
							if rect.intersects(o):
								libre = false
								break
					if not libre:
						break
				if not libre:
					break
			if libre:
				for cx in range(cx0, cx1 + 1):
					for cy in range(cy0, cy1 + 1):
						var kk := Vector2i(cx, cy)
						if rejilla.has(kk):
							rejilla[kk].append(rect)
						else:
							rejilla[kk] = [rect]
				visibles.append([p, nombre])
		for v in visibles:
			draw_set_transform(v[0] + Vector2(7.0, 4.0) * k, 0.0, Vector2(k, k))
			draw_string_outline(fuente, Vector2.ZERO, v[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0.03, 0.05, 0.1, 0.95))
		for v in visibles:
			draw_set_transform(v[0] + Vector2(7.0, 4.0) * k, 0.0, Vector2(k, k))
			draw_string(fuente, Vector2.ZERO, v[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.98, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ms_dibujo += float(Time.get_ticks_usec() - t0) / 1000.0
		n_dibujos += 1


## Carga una fuente de la interfaz desde res://fuentes/. Si el archivo faltara, cae a una sans-serif del sistema.
func _cargar_fuente_ui(archivo: String, peso: int) -> Font:
	var ruta := "res://fuentes/" + archivo
	if ResourceLoader.exists(ruta):
		var r = load(ruta)
		if r is Font:
			return r
	if FileAccess.file_exists(ruta):
		var ff := FontFile.new()
		ff.data = FileAccess.get_file_as_bytes(ruta)
		ff.hinting = TextServer.HINTING_LIGHT
		return ff
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Inter", "Helvetica Neue", "Arial", "sans-serif"])
	sf.font_weight = peso
	return sf


func _configurar_fuente() -> void:
	fuente_ui = _cargar_fuente_ui("Inter-Regular.otf", 400)
	fuente_ui_neg = _cargar_fuente_ui("Inter-SemiBold.otf", 600)
	fuente = SystemFont.new()
	fuente.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "Cambria", "Times New Roman", "serif"])
	fuente.multichannel_signed_distance_field = true
	fuente.msdf_pixel_range = 16
	fuente.msdf_size = 48
	fuente.generate_mipmaps = true
	# Fuente SIN MSDF para los nombres de ciudad: tienen tamaño constante en pantalla, y los glifos normales se agrupan
	# en pocas llamadas de dibujo (con MSDF cada letra cuesta una llamada).
	fuente_ciudad = SystemFont.new()
	fuente_ciudad.font_names = fuente.font_names
	fuente_ciudad.multichannel_signed_distance_field = false
	fuente_ciudad.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	fuente_ciudad.hinting = TextServer.HINTING_LIGHT
	fuente_ciudad.antialiasing = TextServer.FONT_ANTIALIASING_GRAY


func _configurar_oceano() -> void:
	if has_node("OceanoFondo"):
		var o: ColorRect = $OceanoFondo
		o.z_index = -10
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		o.position = Vector2(-15000.0, -3000.0)
		o.size = Vector2(35000.0, 7000.0)


## Ruta de un archivo de datos (`rel` = «info.json», «malla_fill_v.bin»...). En un escenario distinto de 2026 se lee de su carpeta; lo que el escenario no
## trae se lee de datos/ (el mar, la profundidad, los lagos, el catálogo de variables). `historico/` NO tiene respaldo: es la historia de 2026 y sus
## identificadores no valen en otra época.
func _ruta_datos(rel: String) -> String:
	if epoca_dir != "":
		var p := epoca_dir + rel
		if rel.begins_with("historico/") or FileAccess.file_exists(p):
			return p
	return "res://datos/" + rel


func _leer_bytes(nombre: String) -> PackedByteArray:
	var ruta := _ruta_datos(nombre)
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		push_error("Falta el archivo " + ruta + " (ejecuta herramientas/construir_mapa.py)")
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b


## Como _leer_json pero sin quejarse si el archivo no existe (datos opcionales, p. ej. datos/historico/).
func _leer_json_opcional(ruta: String):
	if not FileAccess.file_exists(_ruta_datos_de(ruta)):
		return null
	return _leer_json(ruta)


## «res://datos/x.json» -> la ruta que corresponde al escenario cargado (las demás rutas no se tocan).
func _ruta_datos_de(ruta: String) -> String:
	if ruta.begins_with("res://datos/"):
		return _ruta_datos(ruta.substr(12))
	return ruta


func _leer_json(ruta: String):
	ruta = _ruta_datos_de(ruta)
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




func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cargar_ajustes()
	_configurar_fuente()
	_configurar_oceano()
	camara.enabled = true
	camara.zoom = Vector2(0.6, 0.6)
	camara.position = Vector2(1200.0, 600.0)
	camara.make_current()

	var t0 := Time.get_ticks_msec()
	_elegir_escenario()
	_cargar_datos_provincias()
	_cargar_info()
	_construir_mapa()
	var t1 := Time.get_ticks_msec()
	_construir_etiquetas()
	_construir_ciudades()
	var t2 := Time.get_ticks_msec()
	reloj = RelojScript.new()
	reloj.fijar(epoca, 1, 1)                                     # el escenario empieza el 1 de enero de su año
	reloj.al_dia = _on_dia
	reloj.al_dia_diferido = _on_dia_diferido
	_crear_hud()
	_crear_menu()
	_crear_capa_tropas()
	_actualizar_zoom()
	_aplicar_calidad(ajustes)
	if Engine.has_meta("inicio_pendiente"):                      # «Nueva partida» desde una partida en curso: el mundo se recargó limpio
		var ini: Dictionary = Engine.get_meta("inicio_pendiente")
		Engine.remove_meta("inicio_pendiente")
		_iniciar_partida(ini)
	print("Mapa cargado en ", Time.get_ticks_msec() - t0, " ms (mallas ", t1 - t0, " ms, textos+ciudades ", t2 - t1, " ms)")


## Escenario de esta ejecución: el que pidió «Nueva partida» (inicio_pendiente.epoca) si sus datos existen; si no, 2026. Va ANTES de leer ningún dato.
func _elegir_escenario() -> void:
	epoca = EPOCA_ACTUAL
	epoca_dir = ""
	epoca_meta = {}
	if not Engine.has_meta("inicio_pendiente"):
		return
	var ini: Dictionary = Engine.get_meta("inicio_pendiente")
	var anio := int(ini.get("epoca", EPOCA_ACTUAL))
	if anio == EPOCA_ACTUAL or not _escenario_disponible(anio):
		return
	var m = _leer_json(String(EPOCAS_DIR[anio]) + "epoca.json")      # (epoca_dir aún vacío: la ruta se lee tal cual)
	epoca = anio
	epoca_dir = String(EPOCAS_DIR[anio])
	if m is Dictionary:
		epoca_meta = m


var ms_proceso := 0.0                 # lo que tardó el último _process del mapa (para medir rendimiento)
var ms_zoom := 0.0                    # y el último _actualizar_zoom
var ms_sinc := 0.0                    # 0.1.8.2a: lo que tardó el último repintado por cambio de dueño/ocupación (_sincronizar_propiedad)
var ms_fases := 0.0                   # ... y los pasos del día simulados en el último fotograma
var dias_fot_ult := 0                 # 0.1.8.3: días de juego que simuló el último paso (para medir la velocidad real)
var ms_sinc_max := 0.0
var n_sinc := 0
var ms_sinc_tot := 0.0
var rend_ocultas := {}                # capas apagadas desde Debug > Rendimiento (clave -> true): sirve para ver qué capa cuesta más en cada PC


## Debug > Rendimiento: apaga o enciende una capa del mapa. Claves: relleno, mar, lagos, costa, fronteras, nombres, ciudades, tropas.
func rend_poner_capa(clave: String, visible_: bool) -> void:
	if visible_:
		rend_ocultas.erase(clave)
	else:
		rend_ocultas[clave] = true
	# primero se deja todo como lo dejaría el juego normal, y luego se vuelven a apagar las elegidas
	for n in [capa_pais, capa_mar, capa_tropas]:
		if n != null:
			n.visible = true
	for n in capa_lagos:
		n.visible = q_lagos
	costa_nivel = -1
	zoom_aplicado = -1.0                                         # fuerza a _actualizar_zoom a recalcular (costa, fronteras, nombres)
	_actualizar_zoom()
	_actualizar_ciudades()
	_aplicar_capas_ocultas()
	_aplicar_capas_relieve()


func _aplicar_capas_ocultas() -> void:
	if rend_ocultas.is_empty():
		return
	if rend_ocultas.has("relleno") and capa_pais != null:
		capa_pais.visible = false
	if rend_ocultas.has("mar") and capa_mar != null:
		capa_mar.visible = false
	if rend_ocultas.has("lagos"):
		for n in capa_lagos:
			n.visible = false
	if rend_ocultas.has("costa"):
		for n in capas_costa:
			if n != null:
				n.visible = false
	if rend_ocultas.has("fronteras"):
		if capa_frontera != null:
			capa_frontera.visible = false
		for n in capa_cont:
			n.visible = false
		for n in capa_ea:
			n.visible = false
	if rend_ocultas.has("nombres"):
		for lista in [capas_texto, capas_prov_texto, capas_estado_texto]:
			for c in lista:
				c["padre"].visible = false
	if rend_ocultas.has("ciudades") and not ciudades_capas.is_empty():
		(ciudades_capas[0] as Node2D).visible = false
	if rend_ocultas.has("tropas") and capa_tropas != null:
		capa_tropas.visible = false


func _process(delta: float) -> void:
	var t_proc := Time.get_ticks_usec()
	if en_menu:
		camara.position.x += delta * 6.0
		_normalizar_camara()
	else:
		_mover_camara_teclado(delta)
		if campana_activa:
			_limitar_camara_campana()                              # también durante las animaciones de la cámara
	# Cualquier cambio de zoom (rueda, animación de cámara, redimensionar ventana) reajusta grosores y capas
	var zr := camara.zoom.x * _zoom_real()
	if absf(zr - zoom_aplicado) > 0.0001:
		var t_z := Time.get_ticks_usec()
		_actualizar_zoom()
		ms_zoom = float(Time.get_ticks_usec() - t_z) / 1000.0
	_actualizar_ciudades()
	_aplicar_capas_ocultas()
	var t_sinc := Time.get_ticks_usec()
	if not _pend_dueno.is_empty():
		_correr_pend_dueno()                                     # 0.1.8.32: una etapa por fotograma del repintado anterior (fronteras, nombres, país enfocado)
	else:
		_actualizar_prov_todas()                                 # líneas de provincia: cuando la capa se ve, si quedaron viejas (y, a x3+, como mucho cada 1,5 s)
	_sincronizar_propiedad(false, true, true)                    # un dueño cambió (conquista, anexión, debug): se repinta el mapa
	_refrescar_panel_diferido()
	_medir_sinc(t_sinc)
	_actualizar_fps(delta)
	if mundo != null and not mundo.avisos.is_empty() and not en_menu and not en_pausa:
		_procesar_avisos()
	if reloj != null and not en_menu and not en_pausa:
		_avanzar_reloj(delta)
	ms_proceso = float(Time.get_ticks_usec() - t_proc) / 1000.0


## Estadística del repintado por cambio de dueño u ocupación (Debug > Rend.): solo cuenta los repintados que tardaron más de 0,3 ms.
func _medir_sinc(t0_us: int) -> void:
	if mundo == null or mundo.bd.version_propietario + mundo.bd.version_ocupacion == 0 or Time.get_ticks_usec() - t0_us <= 300:
		return
	ms_sinc = float(Time.get_ticks_usec() - t0_us) / 1000.0
	ms_sinc_max = maxf(ms_sinc_max, ms_sinc)
	n_sinc += 1
	ms_sinc_tot += ms_sinc


## El reloj de un fotograma: termina primero el paso a medias (si lo hay), después empieza los que debe (cada uno junta todos los días debidos),
## todo dentro del presupuesto de tiempo del fotograma (`presupuesto_us`, por defecto RelojScript.PRESUPUESTO_US). Lo que no cabe queda para el siguiente fotograma.
func _avanzar_reloj(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	var dias := 0
	reloj.acumular(delta)                                       # el tiempo del fotograma se suma al reloj UNA vez (también mientras un paso sigue repartido)
	for _k in 8:
		_correr_fases(_presupuesto_restante(t0))                # termina primero el paso a medias (si lo hay)...
		if not _fases.is_empty() or Time.get_ticks_usec() - t0 >= presupuesto_us:
			break                                               # se acabó el presupuesto del fotograma: el resto, en el siguiente
		var n_d: int = reloj.avanzar(0.0)                       # ...y solo entonces empieza otro (que junta todos los días debidos)
		dias += n_d
		if n_d == 0:
			break
	if not _fases.is_empty():
		_correr_fases(_presupuesto_restante(t0))
	ms_fases = float(Time.get_ticks_usec() - t0) / 1000.0
	if dias > 0:
		dias_fot_ult = dias
		_actualizar_barra()
		_t_fin += delta
		if _t_fin >= 0.4:
			_t_fin = 0.0
			_refrescar_fin_panel()


## Microsegundos que le quedan al fotograma desde `t0_us` (siempre al menos 1: cada llamada a `_correr_fases` hace una fase como mínimo).
func _presupuesto_restante(t0_us: int) -> int:
	return maxi(presupuesto_us - (Time.get_ticks_usec() - t0_us), 1)


# ─────────────────────────────────────────────────────────────
# Carga de datos
# ─────────────────────────────────────────────────────────────
func _cargar_datos_provincias() -> void:
	var d = _leer_json("res://datos/provincias_juego.json")
	if d == null:
		return
	provincias = d["provincias"]
	anillos = d["anillos"]
	var t = _leer_json("res://datos/teselas.json")
	if t != null:
		teselas = t


func _cargar_info() -> void:
	var d = _leer_json("res://datos/info.json")
	if d != null:
		info = d
		for k in info.get("cont", {}):
			mundo_pob += float(info["cont"][k]["pob"])
			mundo_area += float(info["cont"][k]["area"])
	var m = _leer_json("res://datos/mares.json")
	if m != null:
		mares = m
	var ec = _leer_json("res://datos/economia.json")
	if ec != null:
		economia = ec
	var bn = _leer_json("res://datos/banderas.json")
	if bn != null:
		banderas = bn
	var es = _leer_json("res://datos/estados.json")
	if es != null:
		estados_json = es
	var ent = _leer_json("res://datos/entidades.json")
	var ciu = _leer_json("res://datos/ciudades.json")
	var ids_json = _leer_json("res://datos/ids.json")
	var cat_json = _leer_json("res://datos/variables.json")
	mundo = E.Mundo.new()
	if ent != null and ciu != null and ids_json != null and cat_json != null:
		var hist_json := {}
		for k in ["entidades", "nombres", "banderas", "personas", "cargos"]:
			hist_json[k] = _leer_json_opcional("res://datos/historico/%s.json" % k)
		var desc_json = _leer_json_opcional("res://datos/descubrimientos.json")       # 0.1.8.36: el catálogo de descubrimientos (es el mismo en todos los escenarios)
		mundo.cargar(provincias, ent, ciu, estados_json, banderas, ids_json, cat_json, hist_json, epoca, desc_json if desc_json is Dictionary else {})
		var dv = _leer_json("res://datos/divisas.json")
		if dv != null:
			mundo.cargar_economia(dv, info.get("prov", []), economia, HudScript.produccion_principal)
		mundo.iniciar_ejercito(_leer_json_opcional("res://datos/ejercito.json"), _leer_json_opcional("res://datos/nombres_cultura.json"),
			_leer_json_opcional("res://datos/vecinos_prov.json"))
		for pais in ent["paises"]:
			var h: String = String(ent["paises"][pais].get("col", ""))
			if h != "":
				col_pais_hex[pais] = h
				col_hex_continente[pais] = h
		esquema_propio = String(ent.get("esquema_colores", "")) == "propio"
	else:
		push_error("Faltan datos/ids.json o datos/variables.json: ejecuta herramientas/construir_ids.py")
	var rg = _leer_json("res://datos/estado_rangos.json")
	if rg != null:
		estado_rangos = rg


func _asegurar_fill() -> void:
	if fill_cargado:
		return
	fill_cargado = true
	vertices_fill = _a_vec2(_leer_bytes("malla_fill_v.bin"))
	indices_fill = _leer_bytes("malla_fill_i.bin").to_int32_array()


func icono(nombre: String) -> Texture2D:
	if tex_cache.has(nombre):
		return tex_cache[nombre]
	var tex: Texture2D = _cargar_png("res://iconos/%s.png" % nombre)
	tex_cache[nombre] = tex
	return tex


func bandera_tex(clave: String) -> Texture2D:
	if clave == "" or clave == "-":
		clave = "x"
	var k := "b_" + clave
	if tex_cache.has(k):
		return tex_cache[k]
	var tex: Texture2D = _cargar_png("res://banderas/%s.png" % clave)
	if tex == null:
		tex = _cargar_png("res://banderas/x.png")
	tex_cache[k] = tex
	return tex


func _cargar_png(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		return load(ruta)
	var img := Image.load_from_file(ProjectSettings.globalize_path(ruta))
	if img != null:
		return ImageTexture.create_from_image(img)
	return null


# ─────────────────────────────────────────────────────────────
# Mapa en teselas
# ─────────────────────────────────────────────────────────────
func _malla_tesela(vb: PackedByteArray, ib: PackedByteArray, t: Array, cb := PackedByteArray(), uvb := PackedByteArray()) -> ArrayMesh:
	var v0 := int(t[2])
	var nv := int(t[3])
	var i0 := int(t[4])
	var ni := int(t[5])
	var verts := _a_vec2(vb.slice(v0 * 8, (v0 + nv) * 8))
	var idx := ib.slice(i0 * 4, (i0 + ni) * 4).to_int32_array()
	var col := PackedColorArray()
	if cb.size() > 0:
		col = _a_colores(cb.slice(v0 * 3, (v0 + nv) * 3))
	var uv := PackedVector2Array()
	if uvb.size() > 0:
		uv = _a_vec2(uvb.slice(v0 * 8, (v0 + nv) * 8))
	return _crear_malla(verts, idx, col, uv)


func _crear_capa_teselas(lista: Array, vb: PackedByteArray, ib: PackedByteArray, cb: PackedByteArray, uvb: PackedByteArray,
		material: Material, z: int, copias := [-ANCHO_MAPA, 0.0, ANCHO_MAPA], inst_out = null) -> Node2D:
	var padre := Node2D.new()
	padre.z_index = z
	add_child(padre)
	for t in lista:
		var malla := _malla_tesela(vb, ib, t, cb, uvb)
		var grupo := []
		for dx in copias:
			var mi := MeshInstance2D.new()
			mi.mesh = malla
			mi.material = material
			mi.position = Vector2(dx, 0.0)
			padre.add_child(mi)
			grupo.append(mi)
		if inst_out != null:
			inst_out.append(grupo)               # las copias de cada tesela (el relleno las recolorea al cambiar un dueño)
	return padre


func _construir_mapa() -> void:
	var vb := _leer_bytes("malla_filt_v.bin")
	var ib := _leer_bytes("malla_filt_i.bin")
	var cp := _leer_bytes("malla_filt_cp.bin")
	var lista_fill: Array = teselas.get("fill", [])
	# Una sola capa de colores sólidos (color del continente), sin material: se dibujan los colores por vértice tal cual.
	var inst_fill := []
	capa_pais = _crear_capa_teselas(lista_fill, vb, ib, cp, PackedByteArray(), null, 1, [-ANCHO_MAPA, 0.0, ANCHO_MAPA], inst_fill)

	_construir_mar()

	# Lagos: agua encima de las provincias (Grandes Lagos, Victoria, Baikal, etc.)
	var lago_v := _a_vec2(_leer_bytes("malla_lagos_v.bin"))
	var lago_i := _leer_bytes("malla_lagos_i.bin").to_int32_array()
	if lago_v.size() > 0 and lago_i.size() > 0:
		var cols_lago := PackedColorArray()
		cols_lago.resize(lago_v.size())
		cols_lago.fill(Color(0.10, 0.32, 0.47, 1.0))
		capa_lagos = _instanciar(_crear_malla(lago_v, lago_i, cols_lago), null, 1)

	# Bordes: mallas de franjas cuyo grosor se ajusta en el shader (siempre el mismo grosor en pantalla)
	var sh := Shader.new()
	sh.code = SHADER_BORDE
	mat_prov = _material_borde(sh, Color(0.03, 0.04, 0.07, 0.85))
	mat_prov_todas = _material_borde(sh, Color(0.03, 0.04, 0.07, 0.85))
	mat_estado = _material_borde(sh, Color(0.02, 0.03, 0.06, 1.0))
	mat_costa = _material_borde(sh, Color(0.0, 0.0, 0.0, 1.0))
	var sh_franja := Shader.new()
	sh_franja.code = SHADER_BORDE_FRANJA
	var sh_abierta := Shader.new()
	sh_abierta.code = SHADER_BORDE_FRANJA_ABIERTA
	mat_frontera = ShaderMaterial.new()                                      # frontera entre países: línea negra con huecos transparentes (asoma el color del país)
	mat_frontera.shader = sh_abierta
	mat_frontera.set_shader_parameter("col", Color(0.0, 0.0, 0.0, 1.0))
	mat_frontera.set_shader_parameter("negro", NEGRO_FRONTERA)
	mat_frontera.set_shader_parameter("suave", 1.0 / PERIODO_FRONTERA_PX)
	mat_cont = ShaderMaterial.new()
	mat_cont.shader = sh_franja
	mat_ea = ShaderMaterial.new()                                            # Europa–Asia: misma línea rayada que entre continentes, pero solo al acercar
	mat_ea.shader = sh_franja

	# Fronteras entre países: ya no son una malla horneada; se arman desde el dueño actual de cada provincia (fusion_mapa.gd).
	capa_frontera = Node2D.new()
	capa_frontera.z_index = 3
	add_child(capa_frontera)
	capa_prov_todas = Node2D.new()                                           # campaña: las provincias de todos los países se ven siempre
	capa_prov_todas.z_index = 2
	capa_prov_todas.visible = false
	add_child(capa_prov_todas)
	fusion = FusionScript.new()
	var dueno_base := _dueno_original()
	if mundo != null and not dueno_base.is_empty():
		fusion.iniciar(self, vb, ib, cp, lista_fill, inst_fill, dueno_base, _celda_prov_de_anillos())
	territorio = TerritorioScript.new()
	territorio.iniciar(self)
	if fusion.listo:
		_sincronizar_propiedad(true)
		_cargar_relieve_archivo()
	var vc := _leer_bytes("malla_costa_v.bin")
	capa_costa = _crear_capa_teselas(teselas.get("costa", []), vc, _leer_bytes("malla_costa_i.bin"), PackedByteArray(),
		_leer_bytes("malla_costa_uv.bin"), mat_costa, 4)
	# Niveles de detalle de la costa (0.1.7.9.9G). Si faltan los archivos se usa siempre el detalle completo.
	capas_costa = [capa_costa, null, null]
	for nivel in [1, 2]:
		var lista_l: Array = teselas.get("costa%d" % nivel, [])
		if lista_l.is_empty():
			continue
		var cl := _crear_capa_teselas(lista_l, _leer_bytes("malla_costa%d_v.bin" % nivel), _leer_bytes("malla_costa%d_i.bin" % nivel),
			PackedByteArray(), _leer_bytes("malla_costa%d_uv.bin" % nivel), mat_costa, 4)
		cl.visible = false
		capas_costa[nivel] = cl

	var m_cont := _malla_borde("cont")
	if m_cont:
		var cco := _a_colores(_leer_bytes("malla_cont_c.bin"))
		if cco.size() > 0:
			var arr := m_cont.surface_get_arrays(0)
			arr[Mesh.ARRAY_COLOR] = cco
			var m2 := ArrayMesh.new()
			m2.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m_cont = m2
		capa_cont = _instanciar(m_cont, mat_cont, 3)
	var m_ea := _malla_borde("ea")
	if m_ea:
		var cea := _a_colores(_leer_bytes("malla_ea_c.bin"))
		if cea.size() > 0:
			var arr_ea := m_ea.surface_get_arrays(0)
			arr_ea[Mesh.ARRAY_COLOR] = cea
			var m3 := ArrayMesh.new()
			m3.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr_ea)
			m_ea = m3
		capa_ea = _instanciar(m_ea, mat_ea, 3)

	# Silueta del pop-out
	var sh_p := Shader.new()
	sh_p.code = SHADER_POPOUT
	mat_popout = ShaderMaterial.new()
	mat_popout.shader = sh_p

	estado_bytes = {"v": _leer_bytes("malla_estado_v.bin"), "uv": _leer_bytes("malla_estado_uv.bin"), "i": _leer_bytes("malla_estado_i.bin")}


func _malla_borde(cat: String) -> ArrayMesh:
	var v := _a_vec2(_leer_bytes("malla_%s_v.bin" % cat))
	var uv := _a_vec2(_leer_bytes("malla_%s_uv.bin" % cat))
	var idx := _leer_bytes("malla_%s_i.bin" % cat).to_int32_array()
	if v.size() == 0:
		return null
	return _crear_malla(v, idx, PackedColorArray(), uv)


func _material_borde(sh: Shader, color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", color)
	return m


# ─────────────────────────────────────────────────────────────
# Nombres (estilo AoH3): agrupados por tesela y por nivel de zoom
# ─────────────────────────────────────────────────────────────
func _cuantizar(z: float) -> float:
	return pow(2.0, roundf(log(z) / log(2.0) * 2.0) / 2.0)


func _construir_etiquetas() -> void:
	var datos = _leer_json("res://datos/etiquetas.json")
	if datos == null:
		return
	var cubos := {}
	_registrar_etiq = true
	for lab in datos:
		_agregar_etiqueta(lab, cubos, capas_texto, self, [-ANCHO_MAPA, 0.0, ANCHO_MAPA])
	_registrar_etiq = false
	if fusion != null and fusion.listo and not _dueno_ahora.is_empty():
		_actualizar_etiquetas_dueno(_dueno_ahora)               # si el mapa ya nació con dueños cambiados


# Cada etiqueta va a un "cubo" por (tipo, zoom de aparición, tesela). Un cubo = un nodo CapaTexto.
# Los cubos de un mismo nivel cuelgan de un nodo padre, así el zoom solo cambia la transparencia del padre.
func _agregar_etiqueta(lab: Dictionary, cubos: Dictionary, destino: Array, contenedor: Node, copias: Array) -> void:
	var g: String = lab["g"]
	var e: float = lab["e"]
	if lab.has("tiny"):
		_ensanchar_tiny(lab)                                       # países diminutos: nombre horizontal más grande
		e = lab["e"]
	var zin: float = _cuantizar((PX_LEGIBLE * (0.72 if g == "e" else 1.0)) / e)   # los estados se leen antes (son pocos)
	var zf := 0.0
	var clave := ""
	if g == "c":
		clave = "c"
	elif g == "m":
		zf = _cuantizar(maxf(ZOOM_PROVINCIAS * 2.2, zin * 2.6))   # el nombre del país se mantiene más tiempo
		clave = "m|%s|%s" % [zin, zf]
	else:
		clave = "%s|%s" % [g, zin]
	if not cubos.has(clave):
		var padre := Node2D.new()
		padre.z_index = 11 if g == "c" else 10
		padre.visible = false
		contenedor.add_child(padre)
		cubos[clave] = {"padre": padre, "tipo": g, "zin": zin, "zf": zf, "tiles": {}}
		destino.append(cubos[clave])
	var flat: Array = lab["p"]
	var mx := float(flat[0]) if flat.size() >= 2 else 0.0
	var my := float(flat[1]) if flat.size() >= 2 else 0.0
	var tk := "%d|%d" % [int(mx / TESELA), int(my / TESELA)]
	var cb: Dictionary = cubos[clave]
	if not cb["tiles"].has(tk):
		var capa := CapaTexto.new()
		capa.fuente = fuente
		capa.desplazamientos = copias
		cb["padre"].add_child(capa)
		cb["tiles"][tk] = capa
	_colocar_texto(lab, cb["tiles"][tk])




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


# ─────────────────────────────────────────────────────────────
# Ciudades
# ─────────────────────────────────────────────────────────────
func _construir_ciudades() -> void:
	if mundo == null:
		return
	var sh := Shader.new()
	sh.code = SHADER_CIUDAD
	mat_ciudad = ShaderMaterial.new()
	mat_ciudad.shader = sh
	var por_tesela := {}
	for c in mundo.ciudades:
		if campana_activa and mundo.provincia_excluida(int(c.provincia)):
			continue                                          # campaña: no hay ciudades fuera del territorio jugable
		var tk := "%d|%d" % [int(c.pos.x / TESELA), int(c.pos.y / TESELA)]
		if not por_tesela.has(tk):
			por_tesela[tk] = []
		por_tesela[tk].append([c.pos, c.nombre, c.poblacion, c.zoom_min, c.rango_capital, c.id])
	var contenedor := Node2D.new()
	contenedor.z_index = 20
	contenedor.visible = false
	add_child(contenedor)
	ciudades_capas = [contenedor]
	var esquinas := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for tk in por_tesela:
		var lista: Array = por_tesela[tk]                 # ya viene ordenada por población descendente
		var partes = String(tk).split("|")
		var centro := Vector2((int(partes[0]) + 0.5) * TESELA, (int(partes[1]) + 0.5) * TESELA)
		var v := PackedVector2Array()
		var uv := PackedVector2Array()
		var col := PackedColorArray()
		var idx := PackedInt32Array()
		for it in lista:
			var rango: int = it[4]
			var color := Color(1.0, 0.86, 0.35) if rango == 2 else (Color(0.95, 0.95, 1.0) if rango == 1 else Color(0.86, 0.9, 0.98))
			var zmin := maxf(float(it[3]), 1.0)
			var base := v.size()
			for e in esquinas:
				v.append(it[0])
				uv.append(Vector2(e.x * zmin, e.y * (1.0 + float(rango) * 0.5)))
				col.append(color)
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
		var malla := _crear_malla(v, idx, col, uv)
		for dx in [-ANCHO_MAPA, 0.0, ANCHO_MAPA]:
			var capa := CapaCiudades.new()
			capa.fuente = fuente_ciudad
			capa.items = lista
			capa.position = Vector2(dx, 0.0)
			capa.set_meta("centro", centro + Vector2(dx, 0.0))
			var mi := MeshInstance2D.new()
			mi.mesh = malla
			mi.material = mat_ciudad
			mi.show_behind_parent = true
			capa.marcas = mi
			capa.add_child(mi)
			contenedor.add_child(capa)


func _actualizar_ciudades() -> void:
	if ciudades_capas.is_empty():
		return
	var contenedor: Node2D = ciudades_capas[0]
	var zc := camara.zoom.x
	var visible_c := zc >= 2.2 and not en_menu and not rend_ocultas.has("ciudades") and q_ciudades
	contenedor.visible = visible_c
	if not visible_c:
		return
	var zr := _zoom_real()
	var bucket := roundf(log(zr) / log(2.0) * 4.0)          # cuarto de octava
	var vp := get_viewport().get_visible_rect().size
	var mitad := vp / (2.0 * zr) + Vector2(TESELA, TESELA) * 0.75
	# Pantalla en coordenadas de mapa (+ un margen de 150 px para los nombres que asoman por el borde). Se dibuja la pantalla ampliada en 60 %
	# por cada lado y solo se vuelve a dibujar cuando la pantalla sale de esa zona (o cambia el zoom): panear casi nunca redibuja.
	var med_pant := vp / (2.0 * zr) + Vector2(150.0, 150.0) / zr
	var vista := Rect2(camara.position - med_pant, med_pant * 2.0)
	for capa in contenedor.get_children():
		var c: Vector2 = capa.get_meta("centro")
		var dentro: bool = absf(c.x - camara.position.x) <= mitad.x and absf(c.y - camara.position.y) <= mitad.y
		capa.visible = dentro
		if not dentro:
			continue
		var vista_loc := Rect2(vista.position - capa.position, vista.size)
		if capa.dibujado != bucket or not capa.area.encloses(vista_loc):
			capa.pintar(zr, vista_loc.grow_individual(vista.size.x * 0.6, vista.size.y * 0.6, vista.size.x * 0.6, vista.size.y * 0.6))
			capa.dibujado = bucket


# ─────────────────────────────────────────────────────────────
# Zoom: solo transparencias y grosores (cero recálculo de colores)
# ─────────────────────────────────────────────────────────────
# Zoom REAL en pantalla (incluye el escalado de la ventana): px de pantalla por unidad de mapa.
func _zoom_real() -> float:
	var t: Transform2D = get_viewport().get_final_transform() * get_viewport().get_canvas_transform()
	return maxf(t.x.length(), 0.0001)


func _poner_alfa_nodo(n: Node2D, a: float) -> void:
	n.modulate.a = a
	n.visible = a > 0.004


# Herramienta de grosor constante: fija el ancho de un borde en PÍXELES de pantalla, sea cual sea el zoom.
func _fijar_grosor(mat: ShaderMaterial, clave: String, z: float, alfa: float) -> void:
	var px: float = GROSOR_PX[clave]
	var ext: float = BORDE_EXT_PX[q_bordes]
	if clave == "prov" or clave == "prov_todas":
		ext = minf(ext, 0.8)                                                 # líneas finas: sin sombra ni margen grande
	mat.set_shader_parameter("half_width", (px * 0.5 + ext) / z)
	mat.set_shader_parameter("nucleo", px * 0.5)
	mat.set_shader_parameter("ext_px", ext)
	if clave == "costa":
		mat.set_shader_parameter("halo", BORDE_HALO[q_bordes])             # (solo la costa lleva sombra; los demás materiales ni tienen ese parámetro)
	mat.set_shader_parameter("alfa", alfa)
	if clave == "cont":
		mat.set_shader_parameter("periodo", PERIODO_FRANJA_PX / z)
	elif clave == "frontera":
		mat.set_shader_parameter("periodo", PERIODO_FRONTERA_PX / z)


## Elige qué nivel de detalle de la costa se ve según el zoom real: al alejar, cientos de miles de triángulos que no se distinguen.
func _elegir_detalle_costa(z: float) -> void:
	var nivel := 0
	if z < COSTA_ZOOM_NIVEL2 and capas_costa.size() > 2 and capas_costa[2] != null:
		nivel = 2
	elif z < COSTA_ZOOM_NIVEL1 and capas_costa.size() > 1 and capas_costa[1] != null:
		nivel = 1
	nivel = maxi(nivel, costa_nivel_min)                                      # 0.1.8.32: Opciones > Pantalla > Costas puede fijar un detalle más bajo
	while nivel > 0 and (capas_costa.size() <= nivel or capas_costa[nivel] == null):
		nivel -= 1                                                            # (si ese nivel no existe, el más bajo que haya)
	if nivel == costa_nivel:
		return
	costa_nivel = nivel
	for i in capas_costa.size():
		if capas_costa[i] != null:
			capas_costa[i].visible = (i == nivel)


func _actualizar_zoom() -> void:
	var z := _zoom_real()
	zoom_aplicado = camara.zoom.x * z
	var zc := camara.zoom.x                       # zoom de cámara: define los niveles de juego (independiente de la ventana)
	var t := smoothstep(ZOOM_PAISES_INI, ZOOM_PAISES_FIN, zc)
	var foco_t := 1.0 if pais_foco != "" else 0.0

	if mat_mar:
		mat_mar.set_shader_parameter("zoom", z)
	if mat_ciudad:
		mat_ciudad.set_shader_parameter("zoom", z)
	_fijar_grosor(mat_costa, "costa", z, 1.0)                                # borde continental (costa)
	_elegir_detalle_costa(z)
	_fijar_grosor(mat_cont, "cont", z, 1.0 - t)                              # frontera continental rayada (zoom out)
	for n in capa_cont:
		n.visible = (1.0 - t) > 0.004
	_fijar_grosor(mat_ea, "cont", z, t)                                      # Europa–Asia: se ve al acercar (la frontera continental ya se apagó)
	for n in capa_ea:
		n.visible = t > 0.004 and not rend_ocultas.has("fronteras")
	_fijar_grosor(mat_frontera, "frontera", z, t)                            # fronteras entre países
	if capa_frontera:
		capa_frontera.visible = t > 0.004
	_fijar_grosor(mat_prov, "prov", z, 0.9)                                  # provincias del país enfocado
	if capa_prov_todas != null:
		var a_todas := smoothstep(ZOOM_PROVINCIAS_TODAS_INI, ZOOM_PROVINCIAS_TODAS_FIN, zc) * 0.78
		_fijar_grosor(mat_prov_todas, "prov_todas", z, a_todas)              # campaña: contornos de todas las provincias, sin necesidad de enfocar
		capa_prov_todas.visible = campana_activa and not en_menu and a_todas > 0.004 and not rend_ocultas.has("fronteras") and q_lineas_prov
		if capa_prov_todas.visible and _prov_todas_sucia:
			_actualizar_prov_todas()                                         # se acercó y las líneas estaban sin rehacer
	_fijar_grosor(mat_estado, "estado", z, 0.95)                             # estados del país enfocado

	for c in capas_texto:
		var a := 0.0
		var zin: float = c["zin"]
		match c["tipo"]:
			"c":
				a = 1.0 - t
			"m":
				var zf: float = c["zf"]
				a = t * smoothstep(zin * 0.8, zin * 1.15, zc) * (1.0 - smoothstep(zf * 0.9, zf * 1.3, zc)) * (1.0 - foco_t)
			_:
				a = t * smoothstep(zin * 0.8, zin * 1.15, zc)
		if en_menu:
			a = 0.0                                                   # el menú no muestra nombres
		_poner_alfa_nodo(c["padre"], a)
	var hay_estados := not foco_lineas_estado.is_empty()
	for c in capas_prov_texto:
		var zin2: float = c["zin"]
		var a2 := smoothstep(zin2 * 0.8, zin2 * 1.15, zc)
		_poner_alfa_nodo(c["padre"], a2 if (vista == "tradicional" or not hay_estados) else 0.0)
	for c in capas_estado_texto:
		var zin3: float = c["zin"]
		var a3 := smoothstep(zin3 * 0.8, zin3 * 1.15, zc)
		if vista == "tradicional":
			a3 *= 1.0 - smoothstep(zin3 * 2.6, zin3 * 4.5, zc)      # en vista tradicional los estados ceden ante los condados
		_poner_alfa_nodo(c["padre"], a3)

	for l in lineas_resaltado:
		if is_instance_valid(l):
			l.width = float((l as Node).get_meta("px", 2.4)) / z


func _normalizar_camara() -> void:
	if campana_activa:
		_limitar_camara_campana()
		return
	camara.position.x = fposmod(camara.position.x, ANCHO_MAPA)
	camara.position.y = clampf(camara.position.y, Y_MIN, Y_MAX)


## 0.1.8.3 · Encuadra toda la campaña (modo observador): centro del territorio y el alejamiento máximo permitido.
func _encuadrar_campana() -> void:
	if camara == null or campana_rect.size.x < 1.0:
		return
	_limpiar_seleccion()
	camara.position = campana_rect.get_center()
	_limitar_camara_campana()
	var z := camara.zoom.x
	camara.zoom = Vector2(z * 1.02, z * 1.02)
	_limitar_camara_campana()


## Campaña: la cámara no da la vuelta al mundo ni sale del territorio de la campaña (con un margen pequeño).
func _limitar_camara_campana() -> void:
	var vs := get_viewport().get_visible_rect().size
	var r := campana_rect.grow(14.0)
	if r.size.x > 1.0 and r.size.y > 1.0:
		campana_zoom_min = maxf(ZOOM_MIN, minf(vs.x / r.size.x, vs.y / r.size.y))    # lo más lejos que se puede ir: ver toda la campaña
	if camara.zoom.x < campana_zoom_min:
		camara.zoom = Vector2(campana_zoom_min, campana_zoom_min)
	var mitad := vs * 0.5 / camara.zoom.x
	if r.size.x <= mitad.x * 2.0:
		camara.position.x = r.get_center().x
	else:
		camara.position.x = clampf(camara.position.x, r.position.x + mitad.x, r.end.x - mitad.x)
	if r.size.y <= mitad.y * 2.0:
		camara.position.y = r.get_center().y
	else:
		camara.position.y = clampf(camara.position.y, r.position.y + mitad.y, r.end.y - mitad.y)


## Movimiento de la cámara con W A S D (y las flechas). Shift = más rápido. Se usan las teclas FÍSICAS: sirve con cualquier teclado.
## No se mueve si hay una ventana de pausa o si estás escribiendo en un campo de texto (por ejemplo la cantidad de soldados a reclutar).
const CAM_VEL_TECLADO := 620.0                # píxeles del mapa por segundo con zoom 1 (con más zoom se mueve menos, se ve lo mismo)
const CAM_VEL_SHIFT := 2.6

func _mover_camara_teclado(delta: float) -> void:
	if en_pausa or camara == null or _aviso_abierto():
		return
	var foco := get_viewport().gui_get_focus_owner()
	if foco is LineEdit or foco is TextEdit or foco is SpinBox:
		return
	var flechas := foco == null                      # las flechas solo mueven el mapa si ningún control las necesita (listas, deslizadores)
	var dx := 0.0
	var dy := 0.0
	if Input.is_physical_key_pressed(KEY_A) or (flechas and Input.is_physical_key_pressed(KEY_LEFT)):
		dx -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or (flechas and Input.is_physical_key_pressed(KEY_RIGHT)):
		dx += 1.0
	if Input.is_physical_key_pressed(KEY_W) or (flechas and Input.is_physical_key_pressed(KEY_UP)):
		dy -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or (flechas and Input.is_physical_key_pressed(KEY_DOWN)):
		dy += 1.0
	if dx == 0.0 and dy == 0.0:
		return
	if tween_cam != null and tween_cam.is_valid():            # una animación de foco en curso cede ante el teclado
		tween_cam.kill()
	var v := Vector2(dx, dy).normalized() * CAM_VEL_TECLADO * delta / maxf(camara.zoom.x, 0.05)
	if Input.is_physical_key_pressed(KEY_SHIFT):
		v *= CAM_VEL_SHIFT
	camara.position += v
	_normalizar_camara()


func _zoom_en_cursor(factor: float) -> void:
	var z0 := camara.zoom.x
	var z1 := clampf(z0 * factor, campana_zoom_min if campana_activa else ZOOM_MIN, ZOOM_MAX)
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
	if _aviso_abierto():
		return                                                # con un pop-up de guerra abierto el mapa no recibe nada
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if en_menu:
				return
			if not _drag_tropas.is_empty():               # lo primero: cancelar un arrastre de tropas en curso
				_cancelar_drag_tropas()
				get_viewport().set_input_as_handled()
				return
			if not orden_mover.is_empty():                # primero cancela la orden de mover que se estaba eligiendo
				cancelar_destino()
				get_viewport().set_input_as_handled()
				return
			if en_pausa:
				_reanudar_juego()
			else:
				_mostrar_menu_pausa()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F1 and not en_menu:
			_alternar_debug()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_V and not en_menu and not en_pausa:
			_cambiar_vista()
			return
		if event.keycode == KEY_R and not en_menu and not en_pausa and campana_activa:
			_alternar_ranking()
			return
		if not en_menu and not en_pausa:
			match event.keycode:
				KEY_SPACE:
					_poner_velocidad(0 if reloj.velocidad > 0 else maxi(vel_previa, 1))
					return
				KEY_1:
					_poner_velocidad(1)
					return
				KEY_2:
					_poner_velocidad(2)
					return
				KEY_3:
					_poner_velocidad(3)
					return
				KEY_4:
					_poner_velocidad(4)
					return
				KEY_5:
					_poner_velocidad(5)
					return
				KEY_6:
					_poner_velocidad(6)
					return
				KEY_BACKSPACE:
					_atras()
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
					_arrastre_px = 0.0
					_der_t0 = Time.get_ticks_msec()
				MOUSE_BUTTON_LEFT:
					if not orden_mover.is_empty():
						_clic_destino(get_global_mouse_position())
					elif _clic_tropas(get_global_mouse_position()):
						if not _ctrl_pulsado():                  # 0.1.8.2a: Ctrl+clic solo elige/quita, nunca arrastra (antes un roce movía todo el grupo)
							_posible_drag_tropas(get_global_mouse_position(), event.position)
					elif event.double_click:
						_doble_click(get_global_mouse_position())
					else:
						_seleccionar(get_global_mouse_position())
		else:
			if event.button_index == MOUSE_BUTTON_LEFT and not _drag_tropas.is_empty():
				_soltar_drag_tropas()
			if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
				var era_arrastre := arrastrando
				arrastrando = false
				if event.button_index == MOUSE_BUTTON_RIGHT and era_arrastre and _arrastre_px < CLIC_DER_MAX_PX and Time.get_ticks_msec() - _der_t0 < CLIC_DER_MAX_MS:
					_clic_derecho(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if not _drag_tropas.is_empty():
			_mover_drag_tropas(event.position)
		if arrastrando:
			_arrastre_px += event.relative.length()
			camara.position -= event.relative / camara.zoom.x
			_normalizar_camara()
		if not orden_mover.is_empty() and capa_tropas != null:
			var ahora := Time.get_ticks_msec()
			if ahora - _t_hover_dest >= 40:
				_t_hover_dest = ahora
				_destino_bajo_cursor()




func _ensanchar_tiny(lab: Dictionary) -> void:
	var flat: Array = lab["p"]
	if flat.size() < 4:
		return
	var cx := (float(flat[0]) + float(flat[flat.size() - 2])) * 0.5
	var cy := (float(flat[1]) + float(flat[flat.size() - 1])) * 0.5
	var e := 2.2
	var ancho := float(String(lab["t"]).length()) * e * 0.75
	lab["e"] = e
	lab["p"] = [cx - ancho * 0.5, cy, cx + ancho * 0.5, cy]


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


## Medidas de una etiqueta sobre su línea de `largo` unidades de mapa. Es LA cuenta del texto (0.1.8.25: antes estaba copiada en `etiqueta_tramo` y
## en `_colocar_texto`). Devuelve {"k": escala (tamaño real / tamaño base; se encoge si el texto no cabe, nunca se sale del territorio),
## "extra": espacio extra entre letras, "largo_texto": largo del texto ya con ese espaciado, "anchos": ancho base de cada letra}.
func _medir_etiqueta(lab: Dictionary, largo: float) -> Dictionary:
	var texto: String = lab["t"]
	var n := texto.length()
	var anchos := PackedFloat32Array()
	var total48 := 0.0
	for i in n:
		var w: float = fuente.get_char_size(texto.unicode_at(i), FUENTE_BASE).x
		anchos.append(w)
		total48 += w
	var k: float = float(lab["e"]) / float(FUENTE_BASE)
	var total := total48 * k
	if total > 0.96 * largo:
		k *= 0.96 * largo / total
		total = total48 * k
	var extra := 0.0
	if n > 1:
		var alvo := minf(largo * 0.9, total * float(ESPACIADO_MAX[String(lab["g"])]))
		extra = maxf(0.0, (alvo - total) / float(n - 1))
		extra = minf(extra, k * float(FUENTE_BASE) * 1.2)
	return {"k": k, "extra": extra, "largo_texto": total + extra * float(n - 1), "anchos": anchos}


## Cuánto ocupa el texto de una etiqueta a lo largo de su línea (misma cuenta que `_colocar_texto`, ver `_medir_etiqueta`):
## [distancia a la que empieza, largo del texto, alto de las letras], en unidades de mapa. Lo usa la capa de tropas para no pisar los nombres.
func etiqueta_tramo(lab: Dictionary, largo: float) -> Array:
	var m: Dictionary = _medir_etiqueta(lab, largo)
	var lt: float = m["largo_texto"]
	return [(largo - lt) * 0.5, lt, float(m["k"]) * float(FUENTE_BASE)]


## 0.1.8.37 · Sentido de lectura de una etiqueta. Antes cada letra se daba vuelta por su cuenta al pasar de ±90°, y en las etiquetas casi verticales (AMÉRICA DEL SUR,
## CHILE, ISRAEL...) unas letras quedaban al derecho y otras al revés. Ahora se decide UNA vez para toda la línea: se lee de izquierda a derecha y, si es casi
## vertical, de abajo hacia arriba (cuerda entre -105° y +75°); si la línea va al otro lado se invierte entera. Luego cada letra sigue la curva con tope en ±90°.
func _orientar_linea_etiqueta(P: PackedVector2Array) -> PackedVector2Array:
	var cuerda := (P[P.size() - 1] - P[0]).angle()
	if cuerda > deg_to_rad(75.0) or cuerda <= deg_to_rad(-105.0):
		var R := PackedVector2Array()
		for i in range(P.size() - 1, -1, -1):
			R.append(P[i])
		return R
	return P


func _colocar_texto(lab: Dictionary, capa: CapaTexto) -> void:
	var texto: String = lab["t"]
	var g: String = lab["g"]
	var flat: Array = lab["p"]
	var P := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		P.append(Vector2(flat[i], flat[i + 1]))
	if P.size() < 2:
		return
	P = _orientar_linea_etiqueta(P)                       # 0.1.8.37: una sola dirección de lectura para TODA la etiqueta
	var cum := PackedFloat32Array([0.0])
	for i in range(1, P.size()):
		cum.append(cum[i - 1] + P[i].distance_to(P[i - 1]))
	var largo: float = cum[cum.size() - 1]
	if largo <= 0.0:
		return

	var n := texto.length()
	var med: Dictionary = _medir_etiqueta(lab, largo)
	var anchos: PackedFloat32Array = med["anchos"]
	var k: float = med["k"]                               # escala: tamaño real / tamaño base (ya encogida si no cabía)
	var extra: float = med["extra"]
	var s: float = (largo - float(med["largo_texto"])) * 0.5

	var color_texto := Color(0.99, 0.97, 0.88, 0.94)
	if int(lab["lc"]) == 0:
		color_texto = Color(0.06, 0.08, 0.12, 0.88)

	var primer_car := capa.chars.size()
	for i in n:
		var w := anchos[i] * k
		if texto[i] != " ":
			var c0 := s + w * 0.5
			var a := _posicion_en_linea(P, cum, c0 - w * 0.5)
			var b := _posicion_en_linea(P, cum, c0 + w * 0.5)
			var c := _posicion_en_linea(P, cum, c0)
			var angulo := clampf((b - a).angle(), -PI * 0.5, PI * 0.5)     # ninguna letra se da vuelta: tope en vertical (la dirección ya se fijó para toda la línea)
			capa.agregar(texto[i], c, angulo, k, anchos[i], color_texto)
		s += w + extra
	if _registrar_etiq and g == "c" and String(lab.get("k", "")) != "":
		var clave_c := String(lab["k"])
		if not etiq_cont.has(clave_c):
			etiq_cont[clave_c] = []
		etiq_cont[clave_c].append([capa, primer_car, capa.chars.size()])
	if _registrar_etiq and (g == "m" or g == "p") and lab.has("pais"):
		var clave_p := String(lab["pais"])
		if not etiq_pais.has(clave_p):
			etiq_pais[clave_p] = []
		etiq_pais[clave_p].append([capa, primer_car, capa.chars.size()])




# ─────────────────────────────────────────────────────────────
# Selección: continente / país / estado / provincia / ciudad / mar
# ─────────────────────────────────────────────────────────────
var ultimo_p := Vector2.ZERO


func _pais_de(pi: int) -> String:
	if mundo != null and pi < mundo.provincias.size():
		return mundo.provincias[pi].pais
	return String(provincias[pi]["c"])


func _tiene_estados(pais: String) -> bool:
	return estado_rangos.has(pais)


func _puntos_anillo(a: Dictionary) -> PackedVector2Array:
	var v0 := int(a["v0"])
	return vertices_fill.slice(v0, v0 + int(a["n"]))


## 0.1.8.35 · Rejilla de búsqueda: con 16.056 celdas recorrerlas todas en cada clic o movimiento del cursor costaba varios ms. El mapa se parte en casillas de
## RENDIJA_PX píxeles y cada casilla guarda las celdas cuya caja la toca; buscar es mirar solo las de la casilla del punto (unas pocas). Las celdas no se mueven
## nunca (cambiar la forma de una provincia solo cambia de quién es cada celda), así que la rejilla se construye una vez.
const RENDIJA_PX := 20.0
var _rej_casillas: Array = []                 # por casilla: PackedInt32Array con los anillos que la tocan, de menor a mayor índice
var _rej_nx := 0
var _rej_ny := 0


func _construir_rejilla() -> void:
	_rej_nx = int(ceil(ANCHO_MAPA / RENDIJA_PX))
	_rej_ny = int(ceil(1200.0 / RENDIJA_PX))
	_rej_casillas.clear()
	_rej_casillas.resize(_rej_nx * _rej_ny)
	for k in _rej_casillas.size():
		_rej_casillas[k] = PackedInt32Array()
	for ri in anillos.size():
		var b: Array = anillos[ri]["b"]
		var x0 := clampi(int(floorf(float(b[0]) / RENDIJA_PX)), 0, _rej_nx - 1)
		var x1 := clampi(int(floorf(float(b[0] + b[2]) / RENDIJA_PX)), 0, _rej_nx - 1)
		var y0 := clampi(int(floorf(float(b[1]) / RENDIJA_PX)), 0, _rej_ny - 1)
		var y1 := clampi(int(floorf(float(b[1] + b[3]) / RENDIJA_PX)), 0, _rej_ny - 1)
		for gy in range(y0, y1 + 1):
			for gx in range(x0, x1 + 1):
				var k2 := gy * _rej_nx + gx
				var l: PackedInt32Array = _rej_casillas[k2]
				_rej_casillas[k2] = null                  # (sin esta referencia de más, append copiaría la lista entera)
				l.append(ri)
				_rej_casillas[k2] = l


func _anillo_en(p: Vector2) -> int:
	_asegurar_fill()
	if _rej_casillas.is_empty():
		_construir_rejilla()
	var gx := clampi(int(floorf(p.x / RENDIJA_PX)), 0, _rej_nx - 1)
	var gy := clampi(int(floorf(p.y / RENDIJA_PX)), 0, _rej_ny - 1)
	var lista: PackedInt32Array = _rej_casillas[gy * _rej_nx + gx]
	# Los anillos están ordenados de grande a pequeño: se prueba de pequeño a grande (enclaves primero)
	for j in range(lista.size() - 1, -1, -1):
		var i: int = lista[j]
		var a: Dictionary = anillos[i]
		var b: Array = a["b"]
		if p.x < b[0] or p.x > b[0] + b[2] or p.y < b[1] or p.y > b[1] + b[3]:
			continue
		if Geometry2D.is_point_in_polygon(p, _puntos_anillo(a)):
			return i
	return -1


func _ciudad_en(pos: Vector2) -> int:
	if mundo == null or camara.zoom.x < 2.2:
		return -1
	var zr := _zoom_real()
	var rad := 10.0 / zr
	var mejor := -1
	var mejor_d := rad
	var px := fposmod(pos.x, ANCHO_MAPA)
	for c in mundo.ciudades:
		if zr < c.zoom_min:
			continue
		if campana_activa and mundo.provincia_excluida(int(c.provincia)):
			continue
		var dx := absf(c.pos.x - px)
		dx = minf(dx, ANCHO_MAPA - dx)
		if dx > rad or absf(c.pos.y - pos.y) > rad:
			continue
		var d := Vector2(dx, c.pos.y - pos.y).length()
		if d < mejor_d:
			mejor_d = d
			mejor = c.id
	return mejor


# Anillo bajo el cursor. Si hay un país enfocado, la geometría está dentro del grupo escalado: se deshace esa transformación.
func _anillo_bajo(pos: Vector2) -> Array:
	if pais_foco != "":
		var q := foco_centro + (pos - Vector2(foco_dx, 0.0) - foco_centro) / _escala_pop()
		var qw := Vector2(fposmod(q.x, ANCHO_MAPA), q.y)
		var iq := _anillo_en(qw)
		if iq >= 0 and _pais_de(int(anillos[iq]["p"])) == pais_foco:
			return [iq, qw]
	var p := Vector2(fposmod(pos.x, ANCHO_MAPA), pos.y)
	var iw := _anillo_en(p)
	if iw >= 0 and campana_activa and mundo.provincia_excluida(int(anillos[iw]["p"])):
		iw = -2                                                   # fuera de la campaña: no se elige nada (ni siquiera cuenta como mar)
	return [iw, p]


func _seleccionar(pos: Vector2) -> void:
	if _ctrl_pulsado() and _ciudad_en(pos) < 0 and _seleccionar_varias(pos):
		return                                                    # Ctrl+clic sobre una provincia o un país: se suma a la selección (o se quita)
	_limpiar_seleccion()
	var zc := camara.zoom.x
	var ci := _ciudad_en(pos)
	if ci >= 0:
		ultimo_p = Vector2(fposmod(pos.x, ANCHO_MAPA), pos.y)
		_seleccion_ciudad(ci, ultimo_p)
		return
	var r := _anillo_bajo(pos)
	var i: int = r[0]
	var p: Vector2 = r[1]
	ultimo_p = p
	if i == -2:
		return
	if i < 0:
		_salir_foco()
		_seleccion_mar(p)
		return
	var a: Dictionary = anillos[i]
	var pi := int(a["p"])
	var cont := String(a["k"])
	var pais := _pais_de(pi)
	if pais_foco != "" and pais == pais_foco:
		if vista == "internacional" and _tiene_estados(pais) and mundo.provincias[pi].estado != "":
			_seleccion_estado(pais, mundo.provincias[pi].estado, p)
		else:
			_seleccion_provincia(pi, cont, p)
			_tras_elegir_provincia(pi)
		return
	if pais_foco != "":
		_salir_foco()
	if zc < ZOOM_CONTINENTE_MAX and not campana_activa:           # en la campaña no hay continentes que elegir: se elige el país directamente
		_seleccion_continente(cont, p)
	else:
		# 0.1.8.2a: UN solo clic elige el país Y lo enfoca (provincias con nombre; las de los vecinos, solo el contorno)
		_enfocar_pais(pais, _foco_debe_mover(pais))
		_seleccion_pais(pais, cont, p)


## 0.1.8.37 · SELECCIÓN MÚLTIPLE (Ctrl+clic): suma o quita la provincia (con un país enfocado) o el país (sin foco) bajo el cursor. Todo lo elegido queda resaltado;
## el panel muestra lo último que sumaste y avisa de cuántas hay. Devuelve false si el clic no cayó en tierra (entonces se trata como un clic normal).
## (Los totales del grupo y las órdenes a varias unidades a la vez llegan con la ventana de grupo en la 0.1.8.38.)
func _seleccionar_varias(pos: Vector2) -> bool:
	var r := _anillo_bajo(pos)
	var i: int = r[0]
	if i < 0:
		return false
	var p: Vector2 = r[1]
	var a: Dictionary = anillos[i]
	var pi := int(a["p"])
	var pais := _pais_de(pi)
	var cont := String(a["k"])
	ultimo_p = p
	var u := {"tipo": "provincia" if (pais_foco != "" and pais == pais_foco) else "pais", "pi": pi, "pais": pais, "cont": cont}
	if multi_sel.is_empty():                                      # lo que había elegido hasta ahora pasa a ser el primero del grupo
		var actual := _unidad_elegida()
		if not actual.is_empty():
			multi_sel.append(actual)
	var k := _clave_unidad(u)
	var quitada := false
	for j in multi_sel.size():
		if _clave_unidad(multi_sel[j]) == k:
			multi_sel.remove_at(j)
			quitada = true
			break
	if not quitada:
		multi_sel.append(u)
	_multi_dibujar(p)
	return true


## Qué hay elegido ahora con un clic normal, como unidad de selección múltiple (vacío si nada, o si es otra cosa: ciudad, mar, continente...).
func _unidad_elegida() -> Dictionary:
	if hud == null or not hud.esta_abierto():
		return {}                                                 # con el panel cerrado no hay nada elegido (sel_tipo guarda lo último que se vio)
	match sel_tipo:
		"provincia":
			return {"tipo": "provincia", "pi": int(sel_ref["pi"]), "pais": String(sel_ref["pais"]), "cont": String(sel_ref.get("cont", ""))}
		"pais":
			var pais := String(sel_ref["pais"])
			if mundo != null and mundo.paises.has(pais) and not mundo.paises[pais].provincias.is_empty():
				return {"tipo": "pais", "pi": int(mundo.paises[pais].provincias[0]), "pais": pais, "cont": String(sel_ref.get("cont", ""))}
	return {}


func _clave_unidad(u: Dictionary) -> String:
	return ("p%d" % int(u["pi"])) if String(u["tipo"]) == "provincia" else ("c" + String(u["pais"]))


## Vuelve a dibujar el resaltado de todo `multi_sel` y manda al panel la última unidad (o lo cierra si ya no queda ninguna).
func _multi_dibujar(p: Vector2) -> void:
	var copia := multi_sel.duplicate()
	var hay_otro_pais := false
	for u in copia:
		if String(u["pais"]) != pais_foco:
			hay_otro_pais = true
	if pais_foco != "" and hay_otro_pais:
		_salir_foco()                                             # con varios países elegidos no se enfoca ninguno (el resto del mapa no se atenúa)
		multi_sel = copia
	_borrar_resaltado()
	for u in multi_sel:
		if String(u["tipo"]) == "provincia":
			_resaltar_anillos(mundo.provincias[int(u["pi"])].anillos, true)
		else:
			_resaltar_anillos(_anillos_de_pais(String(u["pais"])), true, true)
	if multi_sel.is_empty():
		sel_tipo = ""
		sel_ref = {}
		if hud:
			hud.ocultar()
		_soltar_seleccion_tropas()
		_actualizar_hint()
		return
	var ult: Dictionary = multi_sel.back()
	_multi_activo = true
	if String(ult["tipo"]) == "provincia":
		_seleccion_provincia(int(ult["pi"]), String(ult["cont"]), p)
		_tras_elegir_provincia(int(ult["pi"]))
	else:
		_seleccion_pais(String(ult["pais"]), String(ult["cont"]), p)
	_multi_activo = false


## ¿Hay que mover la cámara al enfocar con un clic? Solo si el país no se ve entero o se ve diminuto: si ya está bien a la vista,
## la cámara se queda quieta (con un clic por país, mover la cámara cada vez marea).
func _foco_debe_mover(pais: String) -> bool:
	if mundo == null or not mundo.paises.has(pais):
		return false
	var bb := _bbox_foco(pais)
	var cen := bb.get_center()
	var dx := ANCHO_MAPA * roundf((camara.position.x - cen.x) / ANCHO_MAPA)
	var vp := get_viewport().get_visible_rect().size
	var z := camara.zoom.x
	var mitad := vp * 0.5 / z
	var vista_r := Rect2(camara.position - mitad, mitad * 2.0).grow(-mitad.x * 0.1)
	var r := Rect2(bb.position + Vector2(dx, 0.0), bb.size)
	if not vista_r.encloses(r):
		return true                                               # se sale de la pantalla
	if r.size.x * z < vp.x * 0.22 and r.size.y * z < vp.y * 0.22:
		return true                                               # se ve demasiado chico para leer sus provincias
	return false


func _doble_click(pos: Vector2) -> void:
	var r := _anillo_bajo(pos)
	var i: int = r[0]
	var p: Vector2 = r[1]
	ultimo_p = p
	if i < 0:
		return
	var a: Dictionary = anillos[i]
	var pi := int(a["p"])
	var pais := _pais_de(pi)
	_limpiar_seleccion()
	if pais == pais_foco:
		_ir_a_unidad(pi)
		if vista == "internacional" and _tiene_estados(pais) and mundo.provincias[pi].estado != "":
			_seleccion_estado(pais, mundo.provincias[pi].estado, p)
		else:
			_seleccion_provincia(pi, String(a["k"]), p)
			_tras_elegir_provincia(pi)
		return
	_enfocar_pais(pais, true)
	_seleccion_pais(pais, String(a["k"]), p)


func _limpiar_seleccion() -> void:
	multi_sel.clear()
	_borrar_resaltado()


## Quita del mapa lo resaltado (relleno, resplandor y borde) y apaga la respiración; no toca la selección múltiple.
func _borrar_resaltado() -> void:
	if tween_resp != null:
		tween_resp.kill()
		tween_resp = null
	for n in resaltado:
		if is_instance_valid(n):
			n.queue_free()
	resaltado.clear()
	for l in lineas_resaltado:
		if is_instance_valid(l):
			l.queue_free()
	lineas_resaltado.clear()


func cerrar_seleccion() -> void:
	_limpiar_seleccion()
	if hud:
		hud.ocultar()
	_soltar_seleccion_tropas()


func _ocultar_paneles() -> void:
	if hud:
		hud.ocultar()
	_soltar_seleccion_tropas()
	_salir_foco()


# ───── Resaltado ─────
func _anillos_de_pais(pais: String) -> Array:
	var lista := []
	if mundo != null and mundo.paises.has(pais):
		for pi in mundo.paises[pais].provincias:
			lista.append_array(mundo.provincias[int(pi)].anillos)
	return lista


## 0.1.8.37 · Aspecto de la selección: relleno amarillo y resplandor amarillo que «respiran» (suben y bajan de intensidad), y encima un borde NEGRO fino
## y nítido (suavizado) que no cambia: se ve igual sobre cualquier color de país. Los países llevan un relleno más tenue que las provincias.
const COLOR_SEL := Color(1.0, 0.85, 0.1)
const SEL_RELLENO := Vector2(0.28, 0.52)               # alfa del relleno (mínimo, máximo) de una provincia
const SEL_RELLENO_PAIS := Vector2(0.12, 0.26)          # ídem para un país entero
const SEL_BRILLO := Vector2(0.18, 0.72)                # alfa del resplandor del borde
const SEL_BORDE_PX := 2.0                              # grosor del borde negro en pantalla (px, a cualquier zoom)
const SEL_BRILLO_PX := 7.0                             # grosor del resplandor
const SEL_PERIODO := 2.4                               # segundos de una respiración completa
var tween_resp: Tween
var multi_sel: Array = []                              # Ctrl+clic: unidades elegidas, {"tipo": "provincia" | "pais", "pi", "pais", "cont"}; vacío = selección normal
var _multi_activo := false                             # true mientras se dibuja el HUD de una selección múltiple (el resaltado lo pone `_multi_dibujar`)
var _cache_contorno: Dictionary = {}                   # hash de la lista de celdas -> contorno ya calculado (así refrescar la selección cada día no lo recalcula)


## Contorno exterior de un conjunto de celdas: las aristas que NO comparten con otra celda del conjunto, encadenadas en líneas (una por contorno cerrado,
## con el primer punto repetido al final). Una arista que aparece dos veces es interna y se cancela.
func _contorno_de_anillos(lista: Array) -> Array:
	var h := hash(lista)
	if _cache_contorno.has(h):
		return _cache_contorno[h]
	var presentes := {}                                    # arista (sin dirección) -> true, si queda una sola vez
	var punto := {}                                        # llave de punto -> posición real
	for ri in lista:
		var pts := _puntos_anillo(anillos[int(ri)])
		var n := pts.size()
		if n < 3:
			continue
		var ka := Vector2i(roundi(pts[n - 1].x * 50.0), roundi(pts[n - 1].y * 50.0))
		punto[ka] = pts[n - 1]
		for k in n:
			var kb := Vector2i(roundi(pts[k].x * 50.0), roundi(pts[k].y * 50.0))
			punto[kb] = pts[k]
			if ka != kb:
				var a4 := Vector4i(ka.x, ka.y, kb.x, kb.y) if (ka.x < kb.x or (ka.x == kb.x and ka.y < kb.y)) else Vector4i(kb.x, kb.y, ka.x, ka.y)
				if presentes.has(a4):
					presentes.erase(a4)
				else:
					presentes[a4] = true
			ka = kb
	var vecinos := {}                                      # llave de punto -> llaves de los puntos unidos a él por una arista del contorno
	for a4 in presentes:
		var p1 := Vector2i(a4.x, a4.y)
		var p2 := Vector2i(a4.z, a4.w)
		if not vecinos.has(p1):
			vecinos[p1] = []
		if not vecinos.has(p2):
			vecinos[p2] = []
		(vecinos[p1] as Array).append(p2)
		(vecinos[p2] as Array).append(p1)
	var cadenas: Array = []
	for inicio in vecinos.keys():
		while not (vecinos[inicio] as Array).is_empty():
			var cad := PackedVector2Array()
			cad.append(punto[inicio])
			var actual: Vector2i = inicio
			while true:
				var lv: Array = vecinos[actual]
				if lv.is_empty():
					break
				var sig: Vector2i = lv.pop_back()
				(vecinos[sig] as Array).erase(actual)
				cad.append(punto[sig])
				actual = sig
				if actual == inicio:
					break
			if cad.size() >= 3:
				cadenas.append(cad)
	if _cache_contorno.size() > 24:
		_cache_contorno.clear()
	_cache_contorno[h] = cadenas
	return cadenas


## Una línea de la selección: `px` es su grosor en pantalla (se reescala con el zoom).
func _linea_seleccion(pts: PackedVector2Array, dx: float, col: Color, px: float, z: float) -> Line2D:
	var l := Line2D.new()
	l.points = pts
	l.position = Vector2(dx, 0.0)
	l.width = px / z
	l.default_color = col
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.antialiased = true
	l.set_meta("px", px)
	return l


## Resalta un conjunto de celdas: relleno amarillo (`suave`: más tenue, para un país entero) y, con `contorno`, resplandor + borde negro por su contorno exterior.
func _resaltar_anillos(lista: Array, contorno: bool, suave := false) -> void:
	if lista.is_empty():
		return
	# con un país enfocado el resaltado vive dentro de su grupo, para quedar alineado con su silueta
	var en_foco := pais_foco != "" and grupo_pop != null and is_instance_valid(grupo_pop)
	var padre: Node = grupo_pop if en_foco else self
	var copias: Array = [0.0] if en_foco else [-ANCHO_MAPA, 0.0, ANCHO_MAPA]
	var malla := _malla_de_anillos(lista)
	var rango: Vector2 = SEL_RELLENO_PAIS if suave else SEL_RELLENO
	for dx in copias:
		var mi := MeshInstance2D.new()
		mi.mesh = malla
		mi.position = Vector2(dx, 0.0)
		mi.modulate = Color(COLOR_SEL.r, COLOR_SEL.g, COLOR_SEL.b, lerpf(rango.x, rango.y, 0.5))
		mi.set_meta("resp", rango)
		mi.z_index = 8 if en_foco else 12
		padre.add_child(mi)
		resaltado.append(mi)
	if contorno:
		var z := _zoom_real()
		for cad in _contorno_de_anillos(lista):
			for dx in copias:
				var brillo := _linea_seleccion(cad, dx, COLOR_SEL, SEL_BRILLO_PX, z)
				brillo.modulate.a = lerpf(SEL_BRILLO.x, SEL_BRILLO.y, 0.5)
				brillo.set_meta("resp", SEL_BRILLO)
				brillo.z_index = 9 if en_foco else 13
				padre.add_child(brillo)
				lineas_resaltado.append(brillo)
				var borde := _linea_seleccion(cad, dx, Color(0.0, 0.0, 0.0, 1.0), SEL_BORDE_PX, z)
				borde.z_index = 10 if en_foco else 14
				padre.add_child(borde)
				lineas_resaltado.append(borde)
	_iniciar_respiracion()


## La respiración: un bucle que sube y baja el alfa de todo lo resaltado que lo pide (meta «resp» = alfa mínimo y máximo). Se apaga solo cuando no hay selección.
func _iniciar_respiracion() -> void:
	if tween_resp != null and tween_resp.is_valid():
		return
	tween_resp = create_tween().set_loops()
	tween_resp.tween_method(_pulso_seleccion, 0.0, TAU, SEL_PERIODO)


func _pulso_seleccion(f: float) -> void:
	var k := 0.5 - 0.5 * cos(f)
	for n in resaltado:
		if is_instance_valid(n) and (n as Node).has_meta("resp"):
			var r: Vector2 = (n as Node).get_meta("resp")
			(n as CanvasItem).modulate.a = lerpf(r.x, r.y, k)
	for l in lineas_resaltado:
		if is_instance_valid(l) and (l as Node).has_meta("resp"):
			var r2: Vector2 = (l as Node).get_meta("resp")
			(l as CanvasItem).modulate.a = lerpf(r2.x, r2.y, k)


func _resaltar_mar(m: Dictionary) -> void:
	var z := _zoom_real()
	for r in m["r"]:
		var pts := PackedVector2Array()
		for k in range(0, r.size(), 2):
			pts.append(Vector2(r[k], r[k + 1]))
		var cierre := pts.duplicate()
		cierre.append(pts[0])
		for dx in [-ANCHO_MAPA, 0.0, ANCHO_MAPA]:
			var pg := Polygon2D.new()
			pg.polygon = pts
			pg.color = Color(0.45, 0.85, 1.0, 0.24)
			pg.position = Vector2(dx, 0.0)
			pg.z_index = -1
			add_child(pg)
			resaltado.append(pg)
			var l := Line2D.new()
			l.points = cierre
			l.position = Vector2(dx, 0.0)
			l.width = 2.4 / z
			l.default_color = Color(1.0, 0.85, 0.1, 0.9)
			l.z_index = -1
			add_child(l)
			lineas_resaltado.append(l)


func _profundidad_en(p: Vector2) -> int:
	if img_prof == null:
		return 0
	var px := clampi(int(p.x / ANCHO_MAPA * 4096.0), 0, 4095)
	var py := clampi(int(p.y / 1200.0 * 2048.0), 0, 2047)
	var tier := img_prof.get_pixel(px, py).r * 11.0
	var niv: Array = info.get("niv_m", [0, 200, 1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000])
	var i := clampi(int(floor(tier)), 0, 10)
	return int(roundf(lerpf(float(niv[i]), float(niv[i + 1]), tier - float(i)) / 10.0) * 10.0)


# ───── Banderas, migas y datos para el HUD ─────
func _bandera_pais(pais: String) -> String:
	if mundo != null and mundo.paises.has(pais) and mundo.paises[pais].bandera != "":
		return mundo.paises[pais].bandera
	return "x"


func _bandera_estado(pais: String, estado: String) -> String:
	var k := "%s|%s" % [pais, estado]
	if mundo != null and mundo.estados.has(k) and mundo.estados[k].bandera != "":
		return mundo.estados[k].bandera
	return "x"


func _bandera_prov(pi: int) -> String:
	if mundo != null and mundo.provincias[pi].bandera != "":
		return mundo.provincias[pi].bandera
	return "x"


func _miga(nivel: String, tipo: String, nombre: String, bandera: String) -> Dictionary:
	return {"nivel": nivel, "tipo": tipo, "nombre": nombre, "bandera": bandera}


func _tipo_estado(pais: String) -> String:
	if mundo != null and mundo.paises.has(pais):
		var d: String = mundo.paises[pais].division
		return d.trim_suffix("s") if d.ends_with("s") else d
	return "Estado"


func _tipo_provincia(pais: String) -> String:
	if mundo != null and mundo.paises.has(pais):
		var p = mundo.paises[pais]
		var d: String = p.division_provincia if p.division_provincia != "" else p.division
		return d.trim_suffix("s") if d.ends_with("s") else d
	return "Provincia"


func _migas_hasta(cont: String, pais: String, estado: String, prov_i: int) -> Array:
	var m := [_miga("continente", "Continente", cont, "")]
	if pais != "":
		m.append(_miga("pais", "País", pais, _bandera_pais(pais)))
	if estado != "":
		m.append(_miga("estado", _tipo_estado(pais), estado, _bandera_estado(pais, estado)))
	if prov_i >= 0 and bool(provincias[prov_i]["m"]):
		var nom := String(provincias[prov_i]["n"])
		if estado != "" and nom.ends_with(", " + estado):
			nom = nom.trim_suffix(", " + estado)
		m.append(_miga("provincia", _tipo_provincia(pais), nom, _bandera_prov(prov_i)))
	return m


func _eco_para(pais: String, estado: String, prov_nombre: String) -> Dictionary:
	var reg: Dictionary = economia.get("region", {})
	var pa: Dictionary = economia.get("pais", {})
	for k in ["%s|%s" % [pais, estado], "%s|%s" % [pais, prov_nombre]]:
		if k.ends_with("|") == false and reg.has(k):
			var e: Dictionary = reg[k].duplicate(true)
			e["nota"] = "Estimación aproximada a nivel de región; no es una estadística oficial."
			return e
	if pa.has(pais):
		var e2: Dictionary = pa[pais].duplicate(true)
		var base := "Estimación aproximada a nivel de país; no es una estadística oficial."
		if estado != "" or prov_nombre != "":
			base = "Esta zona hereda el dato del país (aún no hay ficha propia). " + base
		if String(e2.get("nivel", "p")) == "r":
			base = "Perfil estimado por tipo de región (sin ficha propia del país). " + base
		e2["nota"] = base
		return e2
	return {}


func _top_ciudades(lista_ids: Array, n := 5) -> Array:
	var out := []
	for id in lista_ids:
		var c = mundo.ciudades[int(id)]
		out.append([c.nombre, c.poblacion])
		if out.size() >= n:
			break
	return out


func _soberania_pais(pais: String) -> Array:
	var r := []
	if mundo != null and mundo.paises.has(pais):
		var p = mundo.paises[pais]
		if p.anexado_a != "":
			r.append(["Estado", "Anexado a %s · ya no tiene provincias" % _nombre_vis(p.anexado_a)])
		r.append(["Provincias controladas", str(p.provincias.size())])
		var ajenos: Array = mundo.origenes_ajenos(pais)
		if not ajenos.is_empty():
			var nombres := []
			for o in ajenos:
				nombres.append(_nombre_vis(String(o)))
			r.append(["Territorios de otros países", ", ".join(PackedStringArray(nombres))])
		var ganadas := 0
		var perdidas := 0
		for h in p.historial:
			if h["tipo"] == "gano":
				ganadas += 1
			else:
				perdidas += 1
		r.append(["Provincias ganadas / perdidas", "%d / %d" % [ganadas, perdidas]])
		r.append(["Continente", p.continente])
	return r


## A qué país y provincia se refiere la pestaña Militar según lo seleccionado ({} = nada con tropas que manejar: continentes y mar).
func _ctx_tropas() -> Dictionary:
	if mundo == null or mundo.ejercito == null:
		return {}
	var pais := ""
	var prov := -1
	match sel_tipo:
		"pais", "estado":
			pais = String(sel_ref.get("pais", ""))
		"provincia":
			var pr = mundo.provincias[int(sel_ref["pi"])]
			pais = pr.pais
			prov = int(pr.tid)
		"ciudad":
			var c = mundo.ciudades[int(sel_ref["id"])]
			pais = c.pais
			if c.provincia >= 0:
				prov = int(mundo.provincias[c.provincia].tid)
		_:
			return {}
	if not mundo.paises.has(pais):
		return {}
	var tid := int(mundo.paises[pais].tid)
	var jug: String = mundo.jugador
	if prov >= 0 and jug != "" and pais != jug and mundo.paises.has(jug):
		var jt := int(mundo.paises[jug].tid)
		if mundo.ejercito.soldados_en_provincia(prov, jt) > 0:       # provincia ajena donde tienes tropas: se ven (y ordenan) las tuyas
			tid = jt
	return {"pais_tid": tid, "prov_tid": prov, "pais_nombre": _nombre_vis(pais)}


func _enviar_hud(d: Dictionary, p: Vector2) -> void:
	d["coord"] = "Coordenadas: (X: %s, Y: %s)" % [snappedf(p.x, 0.1), snappedf(p.y, 0.1)]
	var ctx := _ctx_tropas()
	if not ctx.is_empty():
		d["ctx"] = ctx
	if multi_sel.size() > 1:
		d["multi"] = multi_sel.size()                              # 0.1.8.37: el panel avisa de que hay varias unidades elegidas
	if _en_refresco:
		hud.refrescar(d)                                          # el mismo elemento otra vez: si no cambió nada visible, no se reconstruye
	else:
		hud.mostrar(d)
	_actualizar_hint()
	if debug_menu != null and is_instance_valid(debug_menu):
		debug_menu.seleccion_cambio(sel_tipo)


func _seleccion_continente(cont: String, p: Vector2) -> void:
	var lista := []
	for i in anillos.size():
		if String(anillos[i]["k"]) == cont:
			lista.append(i)
	_resaltar_anillos(lista, false, true)
	var d: Dictionary = info.get("cont", {}).get(cont, {})
	sel_tipo = "continente"
	sel_ref = {"cont": cont}
	var ids := []
	for c in mundo.ciudades:
		if mundo.paises.has(c.pais) and mundo.paises[c.pais].continente == cont:
			ids.append(c.id)
			if ids.size() >= 5:
				break
	_enviar_hud({"tipo": "continente", "titulo": cont, "subtitulo": "Continente · %d países y territorios" % int(d.get("paises", 0)),
		"bandera": "-", "migas": [_miga("continente", "Continente", cont, "")], "d": d,
		"padre": {"pob": mundo_pob, "area": mundo_area}, "padre_n": "el mundo", "etn": [], "eco": {},
		"desc": [["Tipo", "Continente", "i_cont"], ["Países y territorios", str(int(d.get("paises", 0))), "i_pais"]],
		"ciudades": _top_ciudades(ids), "soberania": []}, p)


func _seleccion_pais(pais: String, cont: String, p: Vector2) -> void:
	if not _multi_activo:
		_resaltar_anillos(_anillos_de_pais(pais), true, true)
	var d: Dictionary = info.get("pais", {}).get(pais, {}).duplicate()
	_actualizar_datos_pais(d, pais)
	sel_tipo = "pais"
	sel_ref = {"pais": pais, "cont": cont}
	var ent = mundo.paises.get(pais)
	var desc := [["Tipo", "País / territorio", "i_pais"], ["Continente", cont, "i_cont"]]
	var sub := "País · " + cont
	if ent != null:
		desc.append(["Capital", ent.capital if ent.capital != "" else "—", "i_estrella"])
		var n_est := 0
		for k in mundo.estados:
			if mundo.estados[k].pais == pais:
				n_est += 1
		if n_est > 0:
			desc.append([ent.division, "%d (vista internacional)" % n_est, "i_estado"])
			desc.append([_tipo_provincia(pais) + "s", fmt_n(ent.provincias.size()) + " (vista tradicional)", "i_prov"])
		elif ent.provincias.size() > 1:
			desc.append([ent.division, "%d · se ven en el mapa" % ent.provincias.size(), "i_prov"])
		desc.append(["Ciudades registradas", fmt_n(ent.ciudades.size()), "i_ciudad"])
		sub = "País · %s · %s" % [cont, ent.division.to_lower() if ent.provincias.size() > 1 else "sin subdivisiones"]
	_enviar_hud({"tipo": "pais", "titulo": _nombre_vis(pais), "subtitulo": sub, "bandera": _bandera_pais(pais),
		"migas": _migas_hasta(cont, pais, "", -1), "d": d, "padre": info.get("cont", {}).get(cont, {}), "padre_n": cont,
		"etn": d.get("etn", []), "eco": _eco_para(pais, "", ""), "desc": desc,
		"ciudades": _top_ciudades(ent.ciudades if ent != null else []), "soberania": _soberania_pais(pais),
		"fin": _fin_pais(pais), "fin_det": _fin_detalles(pais)}, p)


func fmt_n(n: float) -> String:
	return hud.fmt_num(n)


func _seleccion_estado(pais: String, estado: String, p: Vector2) -> void:
	var k := "%s|%s" % [pais, estado]
	if mundo == null or not mundo.estados.has(k):
		_seleccion_pais(pais, "", p)
		return
	var es = mundo.estados[k]
	var lista := []
	for pi in es.provincias:
		lista.append_array(mundo.provincias[int(pi)].anillos)
	_resaltar_anillos(lista, true, true)
	var d: Dictionary = info.get("estado", {}).get(k, {})
	var cont: String = mundo.paises[pais].continente
	sel_tipo = "estado"
	sel_ref = {"pais": pais, "estado": estado, "cont": cont}
	var ids := []
	for pi in es.provincias:
		ids.append_array(mundo.provincias[int(pi)].ciudades)
	ids.sort()
	var tipo := _tipo_estado(pais)
	_enviar_hud({"tipo": "estado", "titulo": estado, "subtitulo": "%s · %s" % [tipo, pais], "bandera": _bandera_estado(pais, estado),
		"migas": _migas_hasta(cont, pais, estado, -1), "d": d, "padre": info.get("pais", {}).get(pais, {}), "padre_n": pais,
		"etn": info.get("pais", {}).get(pais, {}).get("etn", []), "eco": _eco_para(pais, estado, ""),
		"desc": [["Tipo", tipo, "i_estado"], ["Pertenece a", pais, "i_pais"], ["Continente", cont, "i_cont"],
			[_tipo_provincia(pais) + "s", fmt_n(es.provincias.size()), "i_prov"]],
		"ciudades": _top_ciudades(ids), "soberania": [["Soberanía", pais]]}, p)


func _seleccion_provincia(pi: int, cont: String, p: Vector2) -> void:
	var pr = mundo.provincias[pi]
	if not _multi_activo:
		_resaltar_anillos(pr.anillos, true)
	var pais: String = pr.pais
	var fila: Array = []
	if info.has("prov") and pi < info["prov"].size():
		fila = info["prov"][pi]
	var d := {}
	if fila.size() >= 6:
		d = {"pob": pr.poblacion, "area": fila[1], "alt": fila[2], "altmax": fila[3], "bio": fila[4], "reino": fila[5]}
	sel_tipo = "provincia"
	sel_ref = {"pi": pi, "pais": pais, "cont": cont}
	var ids: Array = pr.ciudades
	var tipo := _tipo_provincia(pais)
	var desc := [["Tipo", tipo if bool(provincias[pi]["m"]) else "Territorio", "i_prov"], ["Pertenece a", pais, "i_pais"]]
	if pr.estado != "":
		desc.append([_tipo_estado(pais), pr.estado, "i_estado"])
	desc.append(["Continente", cont, "i_cont"])
	if ids.size() > 0:
		desc.append(["Ciudad principal", mundo.ciudades[int(ids[0])].nombre, "i_ciudad"])
	var sob := [["Dueño actual", pais]]
	if pr.ocupante >= 0:
		sob.append(["Ocupada por", mundo.bd.nombre_de(pr.ocupante)])
	var reg: Array = pr.paises_con_registro()
	sob.append(["Países con registro", ", ".join(PackedStringArray(reg))])
	var corto: String = pr.nombre
	if pr.estado != "" and corto.ends_with(", " + pr.estado):
		corto = corto.trim_suffix(", " + pr.estado)          # "Charleston, Carolina del Sur" -> "Charleston" (el estado ya está en las migas)
	_enviar_hud({"tipo": "provincia", "titulo": corto if bool(provincias[pi]["m"]) else pais,
		"subtitulo": "%s · %s%s" % [tipo, pr.estado if pr.estado != "" else pais, (" · " + pais) if pr.estado != "" else ""],
		"bandera": _bandera_prov(pi), "migas": _migas_hasta(cont, pais, pr.estado, pi), "d": d,
		"padre": info.get("pais", {}).get(pais, {}), "padre_n": pais, "etn": info.get("pais", {}).get(pais, {}).get("etn", []),
		"eco": _eco_para(pais, pr.estado, pr.nombre), "desc": desc, "ciudades": _top_ciudades(ids), "soberania": sob,
		"nota": "dato nacional", "fin": _fin_provincia(pi)}, p)


func _seleccion_ciudad(id: int, p: Vector2) -> void:
	var c = mundo.ciudades[id]
	var pr = mundo.provincias[c.provincia] if c.provincia >= 0 else null
	var cont := ""
	if mundo.paises.has(c.pais):
		cont = mundo.paises[c.pais].continente
	var estado := ""
	var d := {}
	if pr != null:
		estado = pr.estado
		var fila: Array = info["prov"][c.provincia]
		d = {"pob": c.poblacion, "area": fila[1], "alt": fila[2], "altmax": fila[3], "bio": fila[4], "reino": fila[5], "sin_area": true}
	# marcador de selección
	var l := Line2D.new()
	var pts := PackedVector2Array()
	var rr := 9.0 / _zoom_real()
	for k in 33:
		pts.append(c.pos + Vector2(cos(k * TAU / 32.0), sin(k * TAU / 32.0)) * rr)
	l.points = pts
	l.width = 2.4 / _zoom_real()
	l.default_color = Color(1.0, 0.85, 0.1)
	l.z_index = 13
	add_child(l)
	lineas_resaltado.append(l)
	sel_tipo = "ciudad"
	sel_ref = {"id": id}
	var migas := _migas_hasta(cont, c.pais, estado, c.provincia)
	migas.append(_miga("ciudad", "Ciudad", c.nombre, c.bandera if c.bandera != "" else "x"))
	var rango := "Capital nacional" if c.rango_capital == 2 else ("Capital de provincia o estado" if c.rango_capital == 1 else "Ciudad")
	var desc := [["Tipo", rango, "i_ciudad"], ["Pertenece a", c.pais, "i_pais"]]
	if pr != null:
		desc.append(["Provincia", pr.nombre, "i_prov"])
		if estado != "":
			desc.append([_tipo_estado(c.pais), estado, "i_estado"])
	desc.append(["Continente", cont, "i_cont"])
	_enviar_hud({"tipo": "ciudad", "titulo": c.nombre, "subtitulo": "%s · %s" % [rango, c.pais],
		"bandera": c.bandera if c.bandera != "" else "x", "migas": migas, "d": d, "padre": {}, "padre_n": "",
		"etn": info.get("pais", {}).get(c.pais, {}).get("etn", []), "eco": _eco_para(c.pais, estado, pr.nombre if pr else ""),
		"desc": desc, "ciudades": [], "soberania": [["Dueño actual", c.pais]]}, p)


func _seleccion_mar(p: Vector2) -> void:
	var elegido := {}
	for m in mares:                                  # ordenados de menor a mayor área: gana el mar más específico
		var b: Array = m["b"]
		if p.x < b[0] or p.x > b[0] + b[2] or p.y < b[1] or p.y > b[1] + b[3]:
			continue
		for r in m["r"]:
			var pts := PackedVector2Array()
			for k in range(0, r.size(), 2):
				pts.append(Vector2(r[k], r[k + 1]))
			if Geometry2D.is_point_in_polygon(p, pts):
				elegido = m
				break
		if not elegido.is_empty():
			break
	var aqui := _profundidad_en(p)
	var nombre := "Aguas internacionales"
	var tipo := "Zona marítima"
	if not elegido.is_empty():
		nombre = String(elegido["n"])
		tipo = String(elegido["t"])
		_resaltar_mar(elegido)
	sel_tipo = "mar"
	sel_ref = {}
	_enviar_hud({"tipo": "mar", "titulo": nombre, "subtitulo": tipo, "bandera": "-",
		"migas": [_miga("mar", tipo, nombre, "")], "d": {}, "mar": elegido, "aqui": aqui,
		"desc": [["Tipo", tipo]]}, p)


func _on_miga(nivel: String, nombre: String) -> void:
	_limpiar_seleccion()
	match nivel:
		"continente":
			_seleccion_continente(nombre, ultimo_p)
		"pais":
			var cont := ""
			if mundo.paises.has(nombre):
				cont = mundo.paises[nombre].continente
			_seleccion_pais(nombre, cont, ultimo_p)
		"estado":
			_seleccion_estado(String(sel_ref.get("pais", pais_foco)), nombre, ultimo_p)
		"provincia":
			if sel_ref.has("pi"):
				_seleccion_provincia(int(sel_ref["pi"]), String(sel_ref.get("cont", "")), ultimo_p)


func _actualizar_hint() -> void:
	if hud == null:
		return
	var v := "Vista tradicional" if vista == "tradicional" else "Vista internacional"
	if not orden_mover.is_empty():
		if orden_mover.has("grupo"):
			hud.set_hint("Mover los %d regimientos elegidos: clic en la provincia de destino (se muestra la ruta y los días) · Esc cancela" % (orden_mover["grupo"] as Array).size())
		else:
			hud.set_hint("Mover %s soldados: clic en la provincia de destino (se muestra la ruta y los días) · Esc cancela" % fmt_n(float(orden_mover["n"])))
		return
	if pais_foco != "":
		hud.set_hint("%s · Provincias de %s · clic fuera del país, ↩ o Retroceso para salir · Ctrl+clic: sumar o quitar provincias · V cambia de vista" % [v, pais_foco])
	else:
		hud.set_hint("Clic en un país: ver sus provincias (las de los vecinos, solo el contorno) · Ctrl+clic: varios países a la vez · Doble clic en una provincia: ir a ella · V: vista · Espacio: pausar el tiempo · 1-6: velocidad (clic en la fecha) · F1: Debug · Clic en un cuadrito de tropas: elegirlas (Ctrl+clic: varias a la vez) · clic derecho en una provincia (o arrastrar el cuadrito hasta ella): moverlas")




# ─────────────────────────────────────────────────────────────
# HUD
# ─────────────────────────────────────────────────────────────
var fps_acum := 0.0
var fps_cuenta := 0


func _crear_hud() -> void:
	hud = HudScript.new()
	add_child(hud)
	hud.construir(self, fuente_ui, fuente_ui_neg)
	hud.cerrar_pedido.connect(cerrar_seleccion)
	hud.miga_pedida.connect(_on_miga)
	hud.vista_elegida.connect(_elegir_vista)
	hud.pausa_pedida.connect(_mostrar_menu_pausa)
	hud.atras_pedido.connect(_atras)
	hud.velocidad_pedida.connect(_poner_velocidad)
	hud.jugador_pedido.connect(_on_jugador_pedido)
	hud.dinero_pedido.connect(_on_dinero_pedido)
	hud.debug_pedido.connect(_alternar_debug)
	hud.personalizar_pedido.connect(_abrir_personalizar)
	hud.ranking_pedido.connect(_alternar_ranking)
	_refrescar_texto_vista()
	hud.set_fecha(reloj.texto())
	hud.set_velocidad(reloj.velocidad)
	_actualizar_barra()
	_actualizar_hint()


## Ajustes de pantalla vigentes (ver ajustes.gd). Sin archivo guardado son los que tiene la ventana ahora mismo.
var ajustes := {}


## Al arrancar: si el jugador guardó ajustes de pantalla en Opciones, se aplican; si no, no se toca nada (el juego arranca como siempre).
func _cargar_ajustes(ruta := AjustesScript.RUTA) -> void:
	if AjustesScript.existe(ruta):
		ajustes = AjustesScript.cargar(ruta)
		AjustesScript.aplicar(ajustes, get_window())
	else:
		ajustes = AjustesScript.leer_actual(get_window())
	TemaHud.aplicar(int(ajustes.get("tema", 0)))                     # 0.1.8.37: el tema de interfaz elegido (antes de construir ningún menú ni el HUD)


## 0.1.8.37 · Cambia el tema de interfaz en vivo: HUD, menú principal / pausa (el que esté abierto) y avisos. `id`: 0 Cartográfico, 1 Moderno oscuro, 2 Mixto.
func _aplicar_tema(id: int) -> void:
	TemaHud.aplicar(id)
	ajustes["tema"] = TemaHud.ID
	if hud != null:
		hud.aplicar_tema(TemaHud.ID)
	if panel_menu_nodo != null and is_instance_valid(panel_menu_nodo):
		var centro := panel_menu_nodo.get_parent() as Control
		if centro != null:
			centro.theme = TemaHud.crear_tema(fuente_ui, fuente_ui_neg)
		panel_menu_nodo.add_theme_stylebox_override("panel", TemaHud.panel(26.0))
		if menu_contenido != null and is_instance_valid(menu_contenido):
			TemaHud.repintar_roles(menu_contenido)
	if popup_guerra != null and is_instance_valid(popup_guerra) and popup_guerra.has_method("aplicar_tema"):
		popup_guerra.aplicar_tema()


## 0.1.8.32 · Gráficos del mapa y prioridad de la simulación (Opciones > Pantalla). Con los valores por defecto el juego queda como siempre.
const COLOR_MAR_LISO := Color(0.06, 0.24, 0.43)
var presupuesto_us := RelojScript.PRESUPUESTO_US     # lo que puede gastar la simulación de días por fotograma (µs), según Ajustes `sim_prio`
var q_bordes := 2                                      # 0.1.8.37: calidad de los bordes del mapa (0 Baja, 1 Media, 2 Alta)
var q_lineas_prov := true                            # la capa de líneas de provincia de la campaña puede verse
var q_ciudades := true                               # las ciudades pueden verse
var q_lagos := true                                  # los lagos se dibujan
var costa_nivel_min := 0                             # la costa nunca usa un detalle mejor que este nivel (0 = el de siempre, 2 = el más bajo)


func _aplicar_calidad(a: Dictionary) -> void:
	var c := AjustesScript.sanear(a)
	if capa_mar != null:
		if int(c["mar"]) == 1:
			capa_mar.material = null                       # sin shader: un rectángulo de color liso
			capa_mar.color = COLOR_MAR_LISO
		else:
			capa_mar.material = mat_mar
			capa_mar.color = Color.WHITE
	costa_nivel_min = int(c["costa"])
	q_lineas_prov = bool(c["lineas_prov"])
	q_bordes = int(c["bordes"])
	q_ciudades = bool(c["ciudades"])
	q_lagos = bool(c["lagos"])
	presupuesto_us = AjustesScript.presupuesto_sim_us(c)
	q_relieve = AjustesScript.preset_de(c) != 2                  # 0.1.8.35: la calidad Baja no dibuja el relieve
	_aplicar_relieve()
	for n in capa_lagos:
		n.visible = q_lagos and not rend_ocultas.has("lagos")
	if modo_relieve:
		_preparar_relieve_vista()                          # la calidad también elige el tamaño de la imagen del relieve
		_aplicar_capas_relieve()
	costa_nivel = -1                                       # que _actualizar_zoom vuelva a elegir el detalle de la costa
	zoom_aplicado = -1.0
	if camara != null and capa_frontera != null:
		_actualizar_zoom()
		_actualizar_ciudades()


func _actualizar_fps(delta: float) -> void:
	fps_acum += delta
	fps_cuenta += 1
	if fps_acum >= 0.5:
		if hud:
			var texto := "v%s" % VERSION
			if bool(ajustes.get("mostrar_fps", true)):                 # 0.1.8.31: Opciones > Pantalla puede ocultar solo el contador
				texto += " · %d FPS" % int(round(float(fps_cuenta) / fps_acum))
			hud.set_fps_texto(texto)
		fps_acum = 0.0
		fps_cuenta = 0


# ─────────────────────────────────────────────────────────────
# Vistas: tradicional / internacional (cómo se agrupan las provincias) y, aparte, el mapa de relieve (0.1.8.37)
# ─────────────────────────────────────────────────────────────
## Una entrada del menú VISTA: «tradicional» o «internacional» cambian la subdivisión; «relieve» enciende el mapa de relieve (cualquier otra
## vista lo apaga y deja la subdivisión que se pida).
func _elegir_vista(clave: String) -> void:
	if clave == "relieve":
		_poner_modo_relieve(true)
	else:
		_poner_modo_relieve(false)
		if (clave == "tradicional" or clave == "internacional") and clave != vista:
			_cambiar_vista()
	_refrescar_texto_vista()


## El botón VISTA de la barra muestra la vista puesta y el menú la marca.
func _refrescar_texto_vista() -> void:
	var clave := "relieve" if modo_relieve else vista
	hud.set_vista_texto("Relieve" if modo_relieve else ("Tradicional" if vista == "tradicional" else "Internacional"))
	hud.set_vista_activa(clave)


func _cambiar_vista() -> void:
	vista = "internacional" if vista == "tradicional" else "tradicional"
	_refrescar_texto_vista()
	_aplicar_vista()
	if sel_tipo == "provincia" or sel_tipo == "estado":
		var pais := String(sel_ref.get("pais", pais_foco))
		_limpiar_seleccion()
		_seleccion_pais(pais, String(sel_ref.get("cont", "")), ultimo_p)


## 0.1.8.37 · Enciende o apaga la vista de relieve (ver «VISTA “RELIEVE”»). Si no encuentra ninguna imagen avisa y se queda en la vista de antes.
func _poner_modo_relieve(v: bool) -> void:
	if v and not _preparar_relieve_vista():
		hud_aviso("Falta la imagen del relieve (datos/texturas/relieve_vista_*.jpg)")
		v = false
	modo_relieve = v
	if not v:
		if capa_pais != null:
			capa_pais.visible = not rend_ocultas.has("relleno")
		if capa_mar != null:
			capa_mar.visible = not rend_ocultas.has("mar")
	_aplicar_capas_relieve()


func _aplicar_vista() -> void:
	var hay_estados := not foco_lineas_estado.is_empty()
	for n in foco_lineas_prov:
		n.visible = vista == "tradicional" or not hay_estados
	for n in foco_lineas_estado:
		n.visible = true
	_actualizar_hint()
	_actualizar_zoom()


# ─────────────────────────────────────────────────────────────
# Foco de país (un clic): se atenúa el resto del mapa y la cámara lleva al país al costado derecho (0.1.8.37: la silueta ya no «salta»)
# ─────────────────────────────────────────────────────────────


func _escala_pop() -> float:
	if grupo_pop != null and is_instance_valid(grupo_pop):
		return maxf(grupo_pop.scale.x, 0.5)
	return 1.0


func _poner_escala_pop(s: float) -> void:
	if grupo_pop == null or not is_instance_valid(grupo_pop):
		return
	grupo_pop.scale = Vector2(s, s)
	grupo_pop.position = Vector2(foco_dx, 0.0) + foco_centro * (1.0 - s)


func _bbox_anillos(lista: Array) -> Rect2:
	var r := Rect2()
	var primero := true
	for ri in lista:
		var b: Array = anillos[int(ri)]["b"]
		var rr := Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
		if primero:
			r = rr
			primero = false
		else:
			r = r.merge(rr)
	return r


func _bbox_foco(pais: String) -> Rect2:
	var f = null
	if bloques_dueno.has(pais):
		return bloques_dueno[pais]                                # territorio cambiado: su bloque contiguo más grande de hoy
	if mundo != null and mundo.paises.has(pais):
		f = mundo.paises[pais].foco
	if f != null and f.size() == 4:
		return Rect2(float(f[0]), float(f[1]), float(f[2]), float(f[3]))
	return _bbox_anillos(_anillos_de_pais(pais))


# Malla compacta con solo los triángulos de los anillos pedidos (evita copiar los 350 mil vértices del mundo).
func _malla_de_anillos(lista: Array) -> ArrayMesh:
	_asegurar_fill()
	var verts := PackedVector2Array()
	var idx := PackedInt32Array()
	for ri in lista:
		var a: Dictionary = anillos[int(ri)]
		var v0 := int(a["v0"])
		var n := int(a["n"])
		var base := verts.size()
		verts.append_array(vertices_fill.slice(v0, v0 + n))
		var trozo := indices_fill.slice(int(a["i0"]), int(a["i1"]))
		var desp := base - v0
		for k in trozo.size():
			trozo[k] += desp
		idx.append_array(trozo)
	return _crear_malla(verts, idx)


func _enfocar_pais(pais: String, mover: bool) -> void:
	_salir_foco()
	if mundo == null or not mundo.paises.has(pais) or mundo.paises[pais].provincias.is_empty():
		return                                                    # un país anexado (sin provincias) no se puede enfocar
	pais_foco = pais
	var bb := _bbox_foco(pais)
	var cen := bb.get_center()
	foco_centro = cen
	foco_dx = ANCHO_MAPA * roundf((camara.position.x - cen.x) / ANCHO_MAPA)

	grupo_vecinos = Node2D.new()                                  # va ANTES que grupo_pop (mismo z): la silueta del país enfocado tapa sus propios bordes
	grupo_vecinos.z_index = 6
	add_child(grupo_vecinos)
	grupo_pop = Node2D.new()
	grupo_pop.z_index = 6
	add_child(grupo_pop)

	# Fondo atenuado (se ve el resto del mapa, pero apagado)
	if dim_overlay == null or not is_instance_valid(dim_overlay):
		dim_overlay = ColorRect.new()
		dim_overlay.position = Vector2(-15000.0, -3000.0)
		dim_overlay.size = Vector2(35000.0, 7000.0)
		dim_overlay.color = Color(0.0, 0.02, 0.07, 0.55)
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim_overlay.z_index = 5
		add_child(dim_overlay)
	dim_overlay.visible = true
	dim_overlay.modulate.a = 0.0

	_poblar_foco(pais)
	_poblar_vecinos(pais)

	hud.set_atras_visible(true)
	_poner_escala_pop(1.0)                                        # 0.1.8.37: el país ya no «salta» ni lleva sombra: solo se atenúa el resto del mapa
	_aplicar_vista()

	if tween_pop:
		tween_pop.kill()
	tween_pop = create_tween()
	tween_pop.tween_property(dim_overlay, "modulate:a", 1.0, 0.30)
	if mover:
		_mover_camara_a(Rect2(bb.position + Vector2(foco_dx, 0.0), bb.size), 0.55, 0.78, 1.05, 14.0)


# Contenido del país enfocado: silueta (con el color de su país dueño), sombra, líneas de provincia y estado, y nombres.
# Se llama al enfocar y otra vez (sin animación) si el territorio del país cambia mientras está enfocado.
func _poblar_foco(pais: String) -> void:
	var malla := _malla_de_anillos(_anillos_de_pais(pais))
	var m_sil := ShaderMaterial.new()
	m_sil.shader = mat_popout.shader
	var col_pais := _color_de_pais(pais)
	m_sil.set_shader_parameter("base", col_pais)
	var sil := MeshInstance2D.new()
	sil.mesh = malla
	sil.material = m_sil
	sil.set_meta("mat_pais", m_sil)
	grupo_pop.add_child(sil)
	foco_sil = sil
	_aplicar_capas_relieve()                                      # con la vista de relieve la silueta lleva el relieve y no el color del país

	# Líneas de provincia: todos los pares de provincias vecinas que son de este país (incluye las costuras de países fusionados)
	foco_lineas_prov.clear()
	foco_lineas_estado.clear()
	if fusion != null and fusion.listo:
		var m_prov: ArrayMesh = fusion.malla_aristas(_dueno_ahora, "propio", int(mundo.paises[pais].tid))
		if m_prov != null:
			var mi := MeshInstance2D.new()
			mi.mesh = m_prov
			mi.material = mat_prov
			mi.z_index = 1
			grupo_pop.add_child(mi)
			foco_lineas_prov.append(mi)
	for t in estado_rangos.get(pais, []):
		var mi2 := MeshInstance2D.new()
		mi2.mesh = _malla_tesela(estado_bytes["v"], estado_bytes["i"], t, PackedByteArray(), estado_bytes["uv"])
		mi2.material = mat_estado
		mi2.z_index = 2
		grupo_pop.add_child(mi2)
		foco_lineas_estado.append(mi2)

	# Nombres de provincias (solo las que hoy son de este país, aunque vengan de países anexados) y de estados.
	# Todos contrastan con el color de la silueta (que es el del país dueño).
	if et_prov.is_empty():
		var d = _leer_json("res://datos/etiquetas_prov.json")
		if d != null:
			et_prov = d
	if et_estado.is_empty():
		var d2 = _leer_json("res://datos/etiquetas_estados.json")
		if d2 != null:
			et_estado = d2
	var lc := 1 if _luminosidad(col_pais) < 0.50 else 0
	var origenes := [pais]
	for o in mundo.origenes_ajenos(pais):
		origenes.append(o)
	capas_prov_texto.clear()
	capas_estado_texto.clear()
	var cubos := {}
	for o2 in origenes:
		for lab in et_prov.get(o2, []):
			if lab.has("pi") and mundo.provincias[int(lab["pi"])].pais != pais:
				continue                                          # esta provincia ya no es de este país
			var l2: Dictionary = lab.duplicate()
			l2["lc"] = lc
			_agregar_etiqueta(l2, cubos, capas_prov_texto, grupo_pop, [0.0])
	var cubos_e := {}
	for lab in et_estado.get(pais, []):
		var l3: Dictionary = lab.duplicate()
		l3["lc"] = lc
		_agregar_etiqueta(l3, cubos_e, capas_estado_texto, grupo_pop, [0.0])


# 0.1.8.2a: contornos de provincia de los países que tocan al enfocado, con el mismo aspecto que los suyos pero SIN nombres
# (así se ve de un vistazo cómo se reparte cada vecino). Van fuera del grupo que "salta": no se agrandan con el país enfocado.
func _poblar_vecinos(pais: String) -> void:
	if grupo_vecinos == null or not is_instance_valid(grupo_vecinos):
		return
	for h in grupo_vecinos.get_children():
		grupo_vecinos.remove_child(h)
		h.queue_free()
	if fusion == null or not fusion.listo or _dueno_ahora.is_empty() or not mundo.paises.has(pais):
		return
	var tid := int(mundo.paises[pais].tid)
	var vec: Dictionary = fusion.vecinos_de(_dueno_ahora, tid, VACIO_ID)
	if vec.is_empty():
		return
	var m: ArrayMesh = fusion.malla_aristas(_dueno_ahora, "conjunto", -1, vec)
	if m == null:
		return
	for dx in [-ANCHO_MAPA, 0.0, ANCHO_MAPA]:
		var mi := MeshInstance2D.new()
		mi.mesh = m
		mi.material = mat_prov
		mi.position = Vector2(dx, 0.0)
		grupo_vecinos.add_child(mi)


# Territorio del país enfocado cambió (conquista, anexión): se rehace su contenido SIN repetir la animación ni mover la cámara.
func _refrescar_foco() -> void:
	if pais_foco == "" or grupo_pop == null or not is_instance_valid(grupo_pop):
		return
	if not mundo.paises.has(pais_foco) or mundo.paises[pais_foco].provincias.is_empty():
		_salir_foco()                                             # el país enfocado dejó de existir
		hud.ocultar()
		return
	_limpiar_seleccion()                                          # los resaltados viven dentro del grupo que se va a vaciar
	for h in grupo_pop.get_children():
		grupo_pop.remove_child(h)
		h.queue_free()
	_poblar_foco(pais_foco)
	_poblar_vecinos(pais_foco)
	_aplicar_vista()


func _salir_foco() -> void:
	if pais_foco == "":
		return
	_limpiar_seleccion()
	if tween_pop:
		tween_pop.kill()
	if is_instance_valid(grupo_pop):
		grupo_pop.queue_free()
	grupo_pop = null
	foco_sil = null
	if is_instance_valid(grupo_vecinos):
		grupo_vecinos.queue_free()
	grupo_vecinos = null
	if is_instance_valid(dim_overlay):
		dim_overlay.visible = false
	foco_lineas_prov.clear()
	foco_lineas_estado.clear()
	capas_prov_texto.clear()
	capas_estado_texto.clear()
	pais_foco = ""
	hud.set_atras_visible(false)
	_actualizar_hint()
	_actualizar_zoom()


# Lleva la cámara a ver `r` (en unidades de mapa) ocupando como mucho fw x fh de la pantalla,
# con el centro de `r` en el costado central derecho.
func _mover_camara_a(r: Rect2, fw: float, fh: float, zmin: float, zmax: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var w := maxf(r.size.x, 3.0)
	var h := maxf(r.size.y, 3.0)
	var z := clampf(minf(vp.x * fw / w, vp.y * fh / h), zmin, zmax)
	var c := r.get_center()
	var destino := Vector2(c.x - vp.x * FOCO_DERECHA / z, c.y)
	destino.y = clampf(destino.y, Y_MIN, Y_MAX)
	if tween_cam:
		tween_cam.kill()
	tween_cam = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_cam.tween_property(camara, "position", destino, 0.75)
	tween_cam.tween_property(camara, "zoom", Vector2(z, z), 0.75)


# Doble clic dentro de un país ya enfocado: acerca a esa provincia (o a ese estado en vista internacional)
func _ir_a_unidad(pi: int) -> void:
	var lista := []
	if vista == "internacional" and _tiene_estados(pais_foco) and mundo.provincias[pi].estado != "":
		var k := "%s|%s" % [pais_foco, mundo.provincias[pi].estado]
		if mundo.estados.has(k):
			for q in mundo.estados[k].provincias:
				lista.append_array(mundo.provincias[int(q)].anillos)
	if lista.is_empty():
		lista = mundo.provincias[pi].anillos
	var r := _bbox_anillos(lista)
	# la geometría vive dentro del grupo escalado: se corrige la posición del centro
	var c := r.get_center()
	var s := _escala_pop()
	var c2 := foco_centro + (c - foco_centro) * s + Vector2(foco_dx, 0.0)
	var r2 := Rect2(c2 - r.size * s * 0.5, r.size * s)
	_mover_camara_a(r2, 0.5, 0.7, 2.0, 28.0)



# ─────────────────────────────────────────────────────────────
# Menú principal: el mapa de fondo (solo colores) y un botón "JUGAR"
# ─────────────────────────────────────────────────────────────
func _crear_menu() -> void:
	hud.set_visible_todo(false)
	menu = CanvasLayer.new()
	menu.layer = 10
	add_child(menu)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.theme = TemaHud.crear_tema(fuente_ui, fuente_ui_neg)             # el mismo azul acero y la misma fuente que el HUD
	menu.add_child(centro)
	var panel_menu := PanelContainer.new()
	panel_menu.custom_minimum_size = Vector2(390.0, 280.0)
	panel_menu.add_theme_stylebox_override("panel", TemaHud.panel(26.0))
	centro.add_child(panel_menu)
	panel_menu_nodo = panel_menu
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
	titulo.add_theme_font_override("font", fuente_ui_neg)
	titulo.add_theme_font_size_override("font_size", 27)
	TemaHud.rotular(titulo, "oro")                                       # 0.1.8.37: el color sale del tema vigente
	menu_contenido.add_child(titulo)


func _boton_menu(texto: String, accion: Callable) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0.0, 44.0)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.add_theme_font_size_override("font_size", 18)
	boton.pressed.connect(accion)
	menu_contenido.add_child(boton)


func _mostrar_menu_principal() -> void:
	_limpiar_menu()
	panel_menu_nodo.custom_minimum_size = Vector2(390.0, 280.0)
	_titulo_menu("GRAN ESTRATEGIA")
	if partida_activa != "":
		_boton_menu("CONTINUAR", _on_jugar)                    # vuelve a la partida que dejaste (el mundo sigue como estaba)
		_boton_menu("NUEVA PARTIDA", _mostrar_modos)
	else:
		_boton_menu("JUGAR", _mostrar_modos)
	_boton_menu("OPCIONES", _mostrar_opciones)
	_boton_menu("SALIR", _salir_juego)


## Segunda capa del menú (0.1.8.2): dos botones gigantes en el centro.
func _mostrar_modos() -> void:
	_limpiar_menu()
	panel_menu_nodo.custom_minimum_size = Vector2(760.0, 470.0)
	_titulo_menu("MODO DE JUEGO")
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 26)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_contenido.add_child(fila)
	_columna_modo(fila, "MODO DEV", "El mapa del mundo entero. Todo está permitido; la IA solo existe si la activas en Debug > IA. Después eliges la época: 2026 o el año 1 d. C.", _mostrar_epocas)
	_columna_modo(fila, "CAMPAÑA", "Solo Europa (con Rusia y Turquía enteras). Compites con la IA por provincias, tropas e ingresos.", _mostrar_campana)
	_boton_menu("VOLVER", _mostrar_menu_principal)


## Tercera capa del MODO DEV: elegir el escenario de partida. Todos son el mismo juego (mismas mecánicas); cambian los datos de inicio.
func _mostrar_epocas() -> void:
	_limpiar_menu()
	panel_menu_nodo.custom_minimum_size = Vector2(760.0, 470.0)
	_titulo_menu("MODO DEV · ESCENARIO")
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 26)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_contenido.add_child(fila)
	_columna_modo(fila, "2026", "El mundo de hoy: países, economías, ejércitos y guerras.", func(): _nueva_partida({"modo": "dev", "epoca": EPOCA_ACTUAL}))
	var b := _columna_modo(fila, "AÑO 1 d. C.", "El mundo antiguo: Roma, el Imperio parto, la China Han y cientos de pueblos, con grandes zonas sin reclamar. Es el mismo juego que 2026: mismas mecánicas, otros datos de partida.", func(): _nueva_partida({"modo": "dev", "epoca": 1}))
	if not _escenario_disponible(1):
		b.disabled = true
		b.tooltip_text = "Faltan los datos de este escenario (datos/epocas/1dc/)."
	_boton_menu("VOLVER", _mostrar_modos)


## ¿Existe la carpeta de datos de ese escenario? (2026 siempre: son los datos de datos/.)
func _escenario_disponible(anio: int) -> bool:
	if anio == EPOCA_ACTUAL:
		return true
	return EPOCAS_DIR.has(anio) and FileAccess.file_exists(String(EPOCAS_DIR[anio]) + "epoca.json")


func _columna_modo(fila: HBoxContainer, titulo: String, descripcion: String, accion: Callable) -> Button:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(330.0, 0.0)
	fila.add_child(col)
	var b := Button.new()
	b.text = titulo
	b.custom_minimum_size = Vector2(330.0, 250.0)
	b.add_theme_font_override("font", fuente_ui_neg)
	b.add_theme_font_size_override("font_size", 38)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(accion)
	col.add_child(b)
	var l := Label.new()
	l.text = descripcion
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", fuente_ui)
	l.add_theme_font_size_override("font_size", 14)
	TemaHud.rotular(l, "tenue")
	col.add_child(l)
	return b


func _etiqueta_menu(texto: String) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_override("font", fuente_ui_neg)
	l.add_theme_font_size_override("font_size", 15)
	TemaHud.rotular(l, "oro")
	menu_contenido.add_child(l)


## Pantalla de la campaña: tu país y qué países tendrán IA.
func _mostrar_campana() -> void:
	_limpiar_menu()
	panel_menu_nodo.custom_minimum_size = Vector2(560.0, 340.0)
	_titulo_menu("CAMPAÑA · EUROPA")
	_etiqueta_menu("Tu país")
	_sel_pais_campana = OptionButton.new()
	_sel_pais_campana.custom_minimum_size = Vector2(0.0, 38.0)
	_sel_pais_campana.add_theme_font_size_override("font_size", 16)
	menu_contenido.add_child(_sel_pais_campana)
	var lista := []
	for n in mundo.paises_de_campana():
		if mundo.paises.has(n) and not (mundo.paises[n].provincias as Array).is_empty():
			lista.append([String(mundo.paises[n].nombre_visible), String(n)])
	lista.sort_custom(func(a, b): return String(a[0]).naturalnocasecmp_to(String(b[0])) < 0)
	_paises_campana_lista = [""]                                  # 0.1.8.3: la primera opción es no controlar ningún país (observador)
	_sel_pais_campana.add_item("— Ninguno: solo observar —")
	var por_defecto := 1
	for i in lista.size():
		_sel_pais_campana.add_item(String(lista[i][0]))
		_paises_campana_lista.append(String(lista[i][1]))
		if String(lista[i][1]) == "España":
			por_defecto = i + 1
	_sel_pais_campana.select(por_defecto)
	var nota := Label.new()
	nota.text = "Todos los demás países los juega la IA (y también el tuyo si dejas de controlarlo). Si eliges «Ninguno» ves cómo evoluciona todo, con todas las tropas a la vista."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_font_override("font", fuente_ui)
	nota.add_theme_font_size_override("font_size", 13)
	TemaHud.rotular(nota, "nota")
	menu_contenido.add_child(nota)
	_boton_menu("COMENZAR", _comenzar_campana_menu)
	_boton_menu("VOLVER", _mostrar_modos)


func _comenzar_campana_menu() -> void:
	var i: int = _sel_pais_campana.selected
	if i < 0 or i >= _paises_campana_lista.size():
		return
	_nueva_partida({"modo": "campana", "pais": _paises_campana_lista[i], "ia": 1})


## Empieza una partida nueva. Si ya había una en curso, se recarga el mundo entero (si no, la campaña heredaría ejércitos y guerras de la anterior).
func _nueva_partida(p: Dictionary) -> void:
	if _requiere_recarga(p):
		Engine.set_meta("inicio_pendiente", p)
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	_iniciar_partida(p)


## ¿Hay que recargar el mundo para esta partida? Sí si ya había una en curso, o si pide otro escenario (otros datos). La campaña es de 2026.
func _requiere_recarga(p: Dictionary) -> bool:
	return partida_activa != "" or int(p.get("epoca", EPOCA_ACTUAL)) != epoca


func _iniciar_partida(p: Dictionary) -> void:
	_fases.clear()                                                # un día a medias de la partida anterior no pasa a la nueva
	if reloj != null:
		reloj.ocupado = false
	if String(p.get("modo", "dev")) == "campana":
		var pais := String(p.get("pais", ""))
		_aplicar_esquema_colores("campana")
		_preparar_campana(pais, int(p.get("ia", 0)))
		partida_activa = "campana"
		_on_jugar()
		if pais != "" and mundo.paises.has(pais):
			_ir_a_pais(pais)
		else:
			_encuadrar_campana()                                    # observador: se ve toda la campaña, sin país elegido
	else:
		_aplicar_esquema_colores("dev")
		partida_activa = "dev"
		_on_jugar()
		_sincronizar_propiedad(true)
	_actualizar_barra()                                               # 0.1.8.3: la barra superior muestra tu país (o «Observador») desde el primer cuadro




# ─────────────────────────────────────────────────────────────
# Esquemas de color de los países (0.1.8.2a)
#   · CAMPAÑA: cada país tiene SIEMPRE el mismo color de identidad (tabla fija para los conocidos; el resto, un color de la paleta que
#     no repite el de ningún vecino, asignado en orden alfabético: siempre sale igual).
#   · DEV: cada país usa el color de su continente en un tono propio, plano (sin degradado): los más cercanos al ecuador, los más oscuros.
# ─────────────────────────────────────────────────────────────
const COLORES_IDENTIDAD := {
	"Francia": "2f5fc4", "Alemania": "6b7280", "España": "c97a14", "Portugal": "1f8a4c", "Reino Unido": "9b2335", "Irlanda": "3ab07a",
	"Italia": "1e9e8a", "Rusia": "6a7d3a", "Turquía": "b8312f", "Polonia": "b0455f", "Ucrania": "3b78d8", "Suecia": "2a8fb5",
	"Noruega": "7a3b3b", "Finlandia": "5b7fb0", "Grecia": "4a6fa5", "Países Bajos": "d9661f", "Bélgica": "8c7a1e", "Suiza": "a84444",
	"Austria": "a8535f", "Rumania": "b09020", "Hungría": "5e8a4a", "Dinamarca": "c0504d", "República Checa": "5a6fb5", "Serbia": "8a4a8f",
	"Bulgaria": "4a8a62", "Croacia": "6b5ab0", "Bielorrusia": "7d9441", "Lituania": "9a7b2c", "Letonia": "8a3b52", "Estonia": "3a8aa0"}
const PALETA_IDENTIDAD := ["c0392b", "2e86c1", "27ae60", "8e44ad", "d35400", "16a085", "b03a76", "7f8c3a", "5d6d9e", "a0522d", "2c7a7b", "9b59b6",
	"c27c0e", "3d9970", "7b5ea7", "b5533c", "4682b4", "6b8e23", "c0617a", "5f9ea0", "8b6f47", "708090", "9c4f96", "4f8f3a"]


func _aplicar_esquema_colores(modo: String) -> void:
	if mundo == null:
		return
	var esq: Dictionary = _esquema_campana() if modo == "campana" else _esquema_dev()
	for pais in esq:
		col_pais_hex[pais] = esq[pais]
	_col_dueno.clear()
	if fusion != null:
		fusion.plano = true
		fusion.repintar_todo()


## Colores de identidad de la campaña. Los conocidos van fijos; los demás eligen de la paleta el primero que no usa ningún vecino.
func _esquema_campana() -> Dictionary:
	var lista: Array = mundo.paises_de_campana()
	var en_c := {}
	for n in lista:
		en_c[String(n)] = true
	var vec := {}                                                     # país -> {vecino: true} (fronteras por tierra entre provincias originales)
	var red = mundo.ejercito.red if mundo.ejercito != null else null
	if red != null and red.listo:
		for a in red.aristas:
			if int(a[3]) != 0:
				continue
			var pa: String = mundo.provincias[int(a[0])].pais_original
			var pb: String = mundo.provincias[int(a[1])].pais_original
			if pa == pb or not en_c.has(pa) or not en_c.has(pb):
				continue
			if not vec.has(pa):
				vec[pa] = {}
			if not vec.has(pb):
				vec[pb] = {}
			vec[pa][pb] = true
			vec[pb][pa] = true
	var res := {}
	for n in lista:
		if COLORES_IDENTIDAD.has(String(n)):
			res[String(n)] = String(COLORES_IDENTIDAD[String(n)])
	var resto: Array = []
	for n in lista:
		if not res.has(String(n)):
			resto.append(String(n))
	resto.sort_custom(func(a, b):
		var da: int = (vec.get(a, {}) as Dictionary).size()
		var db: int = (vec.get(b, {}) as Dictionary).size()
		return da > db or (da == db and String(a) < String(b)))
	var usos := {}
	for h in PALETA_IDENTIDAD:
		usos[String(h)] = 0
	for n in resto:
		var vetados := {}
		for v in vec.get(n, {}):
			if res.has(v):
				vetados[String(res[v])] = true
		var elegido := ""
		for h in PALETA_IDENTIDAD:
			if not vetados.has(String(h)) and (elegido == "" or int(usos[String(h)]) < int(usos[elegido])):
				elegido = String(h)
				if int(usos[elegido]) == 0:
					break
		if elegido == "":
			elegido = String(PALETA_IDENTIDAD[abs(n.hash()) % PALETA_IDENTIDAD.size()])
		usos[elegido] = int(usos[elegido]) + 1
		res[n] = elegido
	return res


## Modo dev: el color de cada continente en un tono por país, de oscuro (cerca del ecuador) a claro (lejos), sin degradado dentro del país.
func _esquema_dev() -> Dictionary:
	if esquema_propio:
		return {}                                                     # el escenario trae el color de cada nación (no se tiñe por continente)
	var por_cont := {}                                                # continente -> [[latitud absoluta, nombre]]
	var red = mundo.ejercito.red if mundo.ejercito != null else null
	for nombre in mundo.paises:
		var e = mundo.paises[nombre]
		if not col_hex_continente.has(nombre):
			continue
		var ys: Array = []
		if red != null and red.listo:
			for pi in e.provincias:
				ys.append(red.centros[int(pi)].y)
		var lat := 45.0
		if not ys.is_empty():
			ys.sort()
			lat = absf((600.0 - float(ys[ys.size() / 2])) / 1200.0 * 180.0)
		var cont: String = String(e.continente)
		if not por_cont.has(cont):
			por_cont[cont] = []
		por_cont[cont].append([lat, String(nombre)])
	var res := {}
	for cont in por_cont:
		var l: Array = por_cont[cont]
		l.sort_custom(func(a, b): return float(a[0]) < float(b[0]) or (float(a[0]) == float(b[0]) and String(a[1]) < String(b[1])))
		for i in l.size():
			var nombre: String = String(l[i][1])
			var base := Color.html("#" + String(col_hex_continente[nombre]))
			var t: float = float(i) / float(maxi(l.size() - 1, 1))
			var f: float = lerpf(0.52, 1.16, t)
			res[nombre] = Color.from_hsv(base.h, base.s, clampf(base.v * f, 0.10, 1.0)).to_html(false)
	return res


## Convierte el mundo en la campaña: solo Europa (+ Rusia y Turquía), tu país elegido y las IA que pediste.
func _preparar_campana(pais: String, _ia_modo: int) -> void:
	mundo.iniciar_campana(mundo.paises_de_campana(), mundo.CAMPANA_QUITAR)
	mundo.fijar_jugador(pais)                                      # pais "" = observador: ningún país es tuyo
	mundo.ia.desactivar_todas()
	mundo.ia.activar_lista(mundo.ia.candidatos())                  # 0.1.8.3: en la campaña TODO país que no controlas lo juega la IA
	_activar_vista_campana()


## Territorio de la campaña en coordenadas del mapa. Lo que cruza el meridiano 180° (Chukotka) se cuenta a la derecha de x = 2400.
func _rect_campana() -> Rect2:
	var r := Rect2()
	var primero := true
	for i in mundo.provincias.size():
		if mundo.provincia_excluida(i):
			continue
		for ri in mundo.provincias[i].anillos:
			var bb: Array = anillos[int(ri)]["b"]
			var rr := Rect2(float(bb[0]), float(bb[1]), float(bb[2]), float(bb[3]))
			if rr.get_center().x < 600.0:
				rr.position.x += ANCHO_MAPA
			r = rr if primero else r.merge(rr)
			primero = false
	return r


## Lo visual de la campaña: lo que no juega queda como vacío oscuro, sin nombres ni ciudades, y la cámara no sale del territorio.
func _activar_vista_campana() -> void:
	campana_activa = true
	campana_rect = _rect_campana()
	hud.set_campana(true)
	for n in ciudades_capas:
		if is_instance_valid(n):
			n.queue_free()
	ciudades_capas = []
	_construir_ciudades()
	for k in etiq_cont:                                           # nombres de continentes: solo queda Europa
		if String(k) == "Europa":
			continue
		for r in etiq_cont[k]:
			(r[0] as CapaTexto).fijar_visible(int(r[1]), int(r[2]), false)
	_sincronizar_propiedad(true)
	_limitar_camara_campana()
	zoom_aplicado = -1.0
	_actualizar_zoom()


func _alternar_ranking() -> void:
	if mundo == null or en_menu or not campana_activa:
		return
	if panel_ranking != null and is_instance_valid(panel_ranking):
		_cerrar_ranking()
		return
	panel_ranking = RankingScript.new()
	add_child(panel_ranking)
	panel_ranking.construir(self, fuente_ui)
	panel_ranking.cerrada.connect(_cerrar_ranking)


func _cerrar_ranking() -> void:
	if panel_ranking != null and is_instance_valid(panel_ranking):
		panel_ranking.queue_free()
	panel_ranking = null


# ─────────────────────────────────────────────────────────────
# Avisos de guerra (0.1.8.2a): pop-ups que pausan el tiempo
# ─────────────────────────────────────────────────────────────
func _aviso_abierto() -> bool:
	return popup_guerra != null and is_instance_valid(popup_guerra) and popup_guerra.abierto


func _tid_jug() -> int:
	var j: String = mundo.jugador
	return int(mundo.paises[j].tid) if j != "" and mundo.paises.has(j) else -1


## Saca el primer aviso de la cola (si no hay otro pop-up abierto), pausa el reloj y lo muestra. Los avisos viejos (la guerra ya no existe) se descartan.
func _procesar_avisos() -> void:
	if mundo == null or en_menu or en_pausa or _aviso_abierto():
		return
	var jt := _tid_jug()
	var g = mundo.guerra
	while not mundo.avisos.is_empty():
		var av: Dictionary = mundo.avisos.pop_front()
		if jt < 0 or g == null:
			continue
		var tipo := String(av.get("tipo", ""))
		if tipo == "guerra" and g.en_guerra(int(av["agresor"]), jt):
			_abrir_aviso_guerra(av, jt)
			return
		if tipo == "paz" and g.en_guerra(int(av["ia"]), jt):
			_abrir_aviso_paz(av, jt)
			return


func _asegurar_popup() -> void:
	if popup_guerra != null and is_instance_valid(popup_guerra):
		return
	popup_guerra = PopupGuerraScript.new()
	add_child(popup_guerra)
	popup_guerra.construir(self, fuente_ui)
	popup_guerra.cerrado.connect(_al_cerrar_aviso)


func _pausar_por_aviso() -> void:
	_vel_aviso = reloj.velocidad if reloj.velocidad > 0 else 0
	_poner_velocidad(0)
	cancelar_destino()


func _al_cerrar_aviso(accion: String) -> void:
	match accion:
		"reanudar":
			_poner_velocidad(1)
		"firmada", "seguir_guerra":
			_poner_velocidad(_vel_aviso)
	if mundo != null and not mundo.avisos.is_empty():
		_procesar_avisos.call_deferred()


## Días que faltan para el primer contacto del agresor con tus provincias: [días, true si ya hay columnas en marcha hacia ti] o [-1, false].
func _contacto_estimado(ag: int, jt: int) -> Array:
	var ej = mundo.ejercito
	var mejor := -1.0
	for mid in ej.marchas:
		var m: Dictionary = ej.marchas[mid]
		if int(m["pais"]) != ag:
			continue
		var ruta: PackedInt32Array = m["ruta"]
		if ej.dueno_de_provincia(int(ruta[ruta.size() - 1])) == jt:
			var dd: float = ej.dias_restantes(m)
			if mejor < 0.0 or dd < mejor:
				mejor = dd
	if mejor >= 0.0:
		return [mejor, true]
	var red = ej.red
	if red == null:
		return [-1.0, false]
	var mias: Array = mundo.paises[mundo.jugador].provincias
	var paso: int = maxi(1, mias.size() / 400)
	var dmin := 1.0e12
	var par := [-1, -1]
	for rid in ej.regs_pais.get(ag, []):
		if ej.en_marcha_reg(int(rid)):
			continue
		var pr = ej.provincia_por_tid(ej.prov_de(int(rid)))
		if pr == null:
			continue
		var c: Vector2 = red.centros[int(pr.idx)]
		for i in range(0, mias.size(), paso):
			var q: Vector2 = red.centros[int(mias[i])]
			var dx: float = absf(q.x - c.x)
			dx = minf(dx, 2400.0 - dx)
			var d2: float = dx * dx + (q.y - c.y) * (q.y - c.y)
			if d2 < dmin:
				dmin = d2
				par = [int(pr.idx), int(mias[i])]
	if int(par[0]) < 0:
		return [-1.0, false]
	var r: PackedInt32Array = red.ruta(int(par[0]), int(par[1]))
	var coste: float = red.coste_ruta(r) if r.size() >= 2 else sqrt(dmin) * red.km_por_unidad
	return [coste / float(ej.VEL_MARCHA_KM_DIA), false]


func _abrir_aviso_guerra(av: Dictionary, jt: int) -> void:
	_asegurar_popup()
	_pausar_por_aviso()
	var ag: int = int(av["agresor"])
	var ej = mundo.ejercito
	var nom_ag: String = mundo.bd.nombre_de(ag)
	var c: Array = _contacto_estimado(ag, jt)
	var vel: int = _vel_aviso if _vel_aviso > 0 else maxi(vel_previa, 1)
	var dias: float = float(c[0])
	var causa := String(av.get("causa", ""))
	if causa.begins_with("Conquista"):
		causa = "quiere conquistar tus provincias"
	popup_guerra.mostrar_guerra({"agresor": nom_ag, "causa": causa, "fecha": BDScript.fecha_texto(int(av.get("fecha", mundo.bd.fecha))),
		"sold_jug": ej.soldados_de_pais(jt), "sold_ag": ej.soldados_de_pais(ag),
		"prov_jug": (mundo.paises[mundo.jugador].provincias as Array).size(), "prov_ag": (mundo.paises[nom_ag].provincias as Array).size() if mundo.paises.has(nom_ag) else 0,
		"dias_contacto": dias, "contacto_columnas": bool(c[1]), "vel": vel,
		"seg_vel": dias * float(RelojScript.SEG_POR_DIA[vel]), "seg_v1": dias * float(RelojScript.SEG_POR_DIA[1])})


func _abrir_aviso_paz(av: Dictionary, jt: int) -> void:
	_asegurar_popup()
	_pausar_por_aviso()
	var g = mundo.guerra
	var ia_tid: int = int(av["ia"])
	var nom: String = mundo.bd.nombre_de(ia_tid)
	var s_jug: float = g.puntaje_guerra(jt, ia_tid)
	var pct_jug: float = 100.0 * g.participacion_ocupada(jt, ia_tid)
	var pct_riv: float = 100.0 * g.participacion_ocupada(ia_tid, jt)
	var dur: int = int(av.get("duracion", 0))
	var nv: String = _nombre_vis(nom)
	var razon := ""
	match String(av.get("razon", "")):
		"victoria":
			razon = "%s domina la guerra: ocupa el %.0f %% de tu producción y quiere cerrarla ya. Si no quieres perder lo que te ocupa, tendrás que ofrecerle algo." % [nv, pct_riv]
		"ventaja":
			razon = "%s lleva %d días con ventaja y quiere cerrar la guerra." % [nv, dur]
		"tablas":
			razon = "Guerra estancada: tras %d días ninguno de los dos avanza. %s propone dejarlo en tablas." % [dur, nv]
		"capitula":
			razon = "%s está perdiendo (le ocupas el %.0f %% de su producción) y pide la paz. Puedes quedarte con lo que ocupas." % [nv, pct_jug]
		_:
			razon = "Tras %d días de guerra los dos bandos están agotados; %s propone la paz." % [dur, nv]
	var oc_rival: Array = g.provincias_ocupadas(ia_tid, jt)
	var oc_mias: Array = g.provincias_ocupadas(jt, ia_tid)
	var filas: Array = []
	for pi in mundo.paises[mundo.jugador].provincias:
		var tid_p: int = mundo.provincias[int(pi)].tid
		filas.append([int(pi), String(mundo.provincias[int(pi)].nombre), g.valor_provincia_usd(int(pi)), mundo.bd.ref("ocupante", tid_p) == ia_tid])
	filas.sort_custom(func(a, b): return (bool(a[3]) and not bool(b[3])) or (bool(a[3]) == bool(b[3]) and float(a[2]) > float(b[2])))
	if filas.size() > 60:
		filas.resize(maxi(60, oc_rival.size()) if oc_rival.size() < filas.size() else filas.size())
	var e = mundo.paises[mundo.jugador]
	var caja_usd: float = 0.0
	if e.tiene_tesoreria() and e.tesoreria > 0.0:
		caja_usd = floorf(e.tesoreria / mundo._por_usd(mundo.jugador))
	popup_guerra.mostrar_paz({"rival": nom, "rival_tid": ia_tid, "razon": razon, "pct_jug": pct_jug, "pct_rival": pct_riv, "n_ocupo": oc_mias.size(), "n_ocupa": oc_rival.size(),
		"dias": dur, "puntaje": s_jug, "provincias": filas, "caja_usd": caja_usd})


## Lo usa el pop-up de paz: ¿aceptaría el rival este tratado?
func tratado_evaluar(rival_tid: int, t: Dictionary) -> Dictionary:
	var jt := _tid_jug()
	if jt < 0 or mundo.guerra == null:
		return {"acepta": false, "motivo": "", "exigido": 0.0, "ofrecido": 0.0, "puntaje": 0.0}
	return mundo.guerra.evaluar_tratado(jt, rival_tid, t)


## Firma el tratado si el rival lo acepta. Devuelve {"ok", "msg"}.
func tratado_firmar(rival_tid: int, t: Dictionary) -> Dictionary:
	var jt := _tid_jug()
	if jt < 0 or mundo.guerra == null:
		return {"ok": false, "msg": ""}
	var ev: Dictionary = mundo.guerra.evaluar_tratado(jt, rival_tid, t)
	if not bool(ev["acepta"]):
		return {"ok": false, "msg": String(ev["motivo"])}
	var res: Dictionary = mundo.guerra.firmar_paz(jt, rival_tid, t, "Tratado de paz")
	if bool(res.get("ok", false)):
		if capa_tropas != null:
			capa_tropas.refrescar()
		_sincronizar_propiedad(true, true)
		_actualizar_barra()
	return res


## OPCIONES (0.1.8.31): dos ventanas, PANTALLA (resolución y gráficos) e INFORMACIÓN (los datos del mapa de siempre).
func _mostrar_opciones() -> void:
	_limpiar_menu()
	panel_menu_nodo.custom_minimum_size = Vector2(390.0, 280.0)
	_titulo_menu("OPCIONES")
	_boton_menu("PANTALLA", _mostrar_opciones_pantalla)
	_boton_menu("INFORMACIÓN", _mostrar_opciones_info)
	_boton_menu("VOLVER", _volver_de_opciones)


## VOLVER de OPCIONES: a la pausa si se abrió desde la pausa, y al menú principal si no.
func _volver_de_opciones() -> void:
	if en_pausa:
		_mostrar_pausa_principal()
	else:
		_mostrar_menu_principal()


## Ventana PANTALLA: el contenido lo construye menu_pantalla.gd; aquí solo se monta y se guarda lo que se confirme.
func _mostrar_opciones_pantalla() -> void:
	_limpiar_menu()
	panel_menu_nodo.custom_minimum_size = Vector2(660.0, 600.0)
	_titulo_menu("PANTALLA")
	var ventana_pantalla = MenuPantallaScript.new()
	menu_contenido.add_child(ventana_pantalla)
	ventana_pantalla.iniciar(get_window(), ajustes)
	ventana_pantalla.aplicado.connect(func(a: Dictionary):
		ajustes = a.duplicate()
		_aplicar_calidad(ajustes))
	ventana_pantalla.tema_elegido.connect(func(id: int): _aplicar_tema(id))
	ventana_pantalla.volver_pedido.connect(_mostrar_opciones)


## Ventana INFORMACIÓN: los datos del mapa (lo que antes era toda la pantalla de Opciones) y la versión.
func _mostrar_opciones_info() -> void:
	_limpiar_menu()
	panel_menu_nodo.custom_minimum_size = Vector2(390.0, 280.0)
	_titulo_menu("INFORMACIÓN")
	var paises := {}
	var cantidad_provincias := 0
	for provincia in provincias:
		paises[String(provincia.get("c", ""))] = true
		if bool(provincia.get("m", false)):
			cantidad_provincias += 1
	var texto_datos := Label.new()
	texto_datos.add_theme_font_override("font", fuente_ui)
	texto_datos.add_theme_font_size_override("font_size", 17)
	TemaHud.rotular(texto_datos, "texto")
	texto_datos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_datos.text = "Países / soberanías: %d\nProvincias administrativas: %d\nUnidades territoriales representadas: %d" % [paises.size(), cantidad_provincias, provincias.size()]
	menu_contenido.add_child(texto_datos)
	var nota := Label.new()
	nota.text = "Las provincias son subdivisiones de los países; no se cuentan como países independientes."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.add_theme_font_override("font", fuente_ui)
	nota.add_theme_font_size_override("font_size", 12)
	TemaHud.rotular(nota, "nota")
	menu_contenido.add_child(nota)
	if epoca_meta.has("creditos"):                                    # escenarios con fuentes de terceros: se citan aquí (la licencia CC BY lo exige)
		panel_menu_nodo.custom_minimum_size = Vector2(560.0, 420.0)
		var cred := Label.new()
		cred.text = "%s\n%s" % [String(epoca_meta.get("nombre", "")), "\n".join(PackedStringArray(epoca_meta["creditos"]))]
		cred.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cred.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cred.add_theme_font_override("font", fuente_ui)
		cred.add_theme_font_size_override("font_size", 12)
		TemaHud.rotular(cred, "nota")
		menu_contenido.add_child(cred)
	var version := Label.new()
	version.text = "Versión %s" % VERSION
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_override("font", fuente_ui)
	version.add_theme_font_size_override("font_size", 13)
	TemaHud.rotular(version, "nota")
	menu_contenido.add_child(version)
	_boton_menu("VOLVER", _mostrar_opciones)


func _on_jugar() -> void:
	if partida_activa == "":
		partida_activa = "dev"
	en_menu = false
	menu.queue_free()
	hud.set_visible_todo(true)
	_actualizar_zoom()




# ─────────────────────────────────────────────────────────────
# Reloj, dinero y control del jugador (0.1.7.9.1)
# ─────────────────────────────────────────────────────────────
## Lo llama el reloj cada vez que pasa un día en los saltos del Debug y en las pruebas: el día se simula entero, de golpe.
func _on_dia(mes_nuevo: bool, anio_nuevo: bool, k := 1) -> void:
	_vaciar_fases()                           # si había un día a medias (juego en marcha), primero se termina
	var bd = mundo.bd
	bd.fecha = BDScript.fecha_int(reloj.anio, reloj.mes, reloj.dia)
	if mes_nuevo:
		for f in _fases_mes(anio_nuevo):
			while f.call() == true:                   # una fase que devuelve true tiene más trabajo (el cierre anual va por trozos)
				pass
	mundo.avanzar_dias(k)
	if not mundo.avisos.is_empty():
		_procesar_avisos()                    # el aviso pausa el reloj YA: no pasan más días hasta que el jugador responda


# 0.1.8.2a · DÍA REPARTIDO EN PASOS. Con el juego en marcha el reloj no simula el día de golpe: lo parte en fases (economía, IA por lotes,
# columnas, llegadas, batallas por lotes, ocupaciones; y al cambiar de mes, el desarrollo mensual y los cierres de periodo) y cada fotograma
# ejecuta las que caben en su presupuesto (RelojScript.PRESUPUESTO_US, mínimo una). Un día con 400 columnas y 20 batallas ya no es un solo
# tirón de 60-100 ms: son pasos de unos pocos ms, y los FPS se mantienen (la partida avanza más despacio si el equipo no da abasto).
var _fases: Array = []                    # Callables pendientes del día en curso
var prof_fases_vivo := {}                 # fase -> [µs totales, llamadas, µs de la más lenta] del juego en marcha (Debug > Rend. y banco de rendimiento)

## Cierre del historial de un periodo ("mensual" o "anual"). Al cerrar un mes se refresca el panel del ejército.
const PANEL_EJ_MIN_MS := 700
var _t_panel_ej := 0                      # última vez que el cierre mensual rehízo el panel del ejército (ms)

func _cierre_periodo(politica: String, est: Dictionary) -> bool:
	if mundo.bd.cerrar_periodo_paso(politica, est):
		return true                                               # 0.1.8.32: el cierre anual (~15.000 filas) se reparte entre fotogramas
	if politica == "mensual":
		var ahora := Time.get_ticks_msec()
		if mundo.ahorro and ahora - _t_panel_ej < PANEL_EJ_MIN_MS:
			return false                                          # a x4-x6 hay hasta 12 cierres por segundo: el panel se rehace como mucho cada 700 ms
		_t_panel_ej = ahora
		hud.refrescar_ejercito()
	return false


## Lo que pasa al cambiar de mes, en tres pasos cortos: desarrollo mensual, cierre mensual del historial y (si cambia el año) cierre anual.
## Se corre de golpe (`_on_dia`) o se reparte entre fotogramas (`_on_dia_diferido`): así lo mensual está escrito una sola vez.
func _fases_mes(anio_nuevo: bool) -> Array:
	var r := [mundo.avanzar_mes, _cierre_periodo.bind("mensual", {})]
	if anio_nuevo:
		r.append(_cierre_periodo.bind("anual", {}))
	return r


func _on_dia_diferido(mes_nuevo: bool, anio_nuevo: bool, k := 1) -> void:
	mundo.bd.fecha = BDScript.fecha_int(reloj.anio, reloj.mes, reloj.dia)
	_fases.clear()
	if mes_nuevo:                                                 # 0.1.8.3: lo mensual en pasos cortos en vez de uno de ~100 ms
		_fases.append_array(_fases_mes(anio_nuevo))
	_fases.append_array(mundo.fases_dias(k))
	reloj.ocupado = true


## Corre fases del día en curso mientras quepan en `limite_us` (siempre al menos una). Al terminar libera al reloj y revisa los avisos.
func _correr_fases(limite_us: int) -> void:
	if _fases.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	while not _fases.is_empty():
		var f: Callable = _fases[0]
		var t_f := Time.get_ticks_usec()
		var mas = f.call()
		PerfilScript.anotar(prof_fases_vivo, String(f.get_method()), t_f)
		if mas != true:
			_fases.pop_front()                # esta fase terminó; si devolvió true tiene más trabajo y se queda al frente
		if Time.get_ticks_usec() - t0 >= limite_us:
			break
	if _fases.is_empty():
		reloj.ocupado = false
		if not mundo.avisos.is_empty():
			_procesar_avisos()                # el aviso pausa el reloj YA: no pasan más días hasta que el jugador responda


func _vaciar_fases() -> void:
	if _fases.is_empty():
		return
	_correr_fases(1 << 40)
	reloj.ocupado = false


const GRUPOS_MES_VEL := [1, 1, 1, 1, 3, 6, 12]               # grupos de meses del desarrollo mensual, por velocidad (solo se usan a x4-x6, en modo ahorro)

func _poner_velocidad(v: int) -> void:
	v = clampi(v, 0, RelojScript.VEL_MAX)
	if v > 0:
		vel_previa = v
	reloj.velocidad = v
	reloj.acum = 0.0
	if mundo != null:
		mundo.ahorro = v >= 4                                     # 0.1.8.3: a x4-x6 lo mensual se simplifica (ver Mundo.ahorro)
		mundo.grupos_mes = GRUPOS_MES_VEL[v]                      # 0.1.8.32: y cuanto más rápido, en más grupos de meses (x6 = 12 meses por segundo)
	hud.set_velocidad(v)


## Formato corto: 1.234 · 12,3 M · 4,56 mil M · 7,8 B (B = billón = 10^12)
func fmt_dinero(v: float, simbolo: String) -> String:
	var a := absf(v)
	var t := ""
	if a >= 1.0e12:
		t = ("%.2f B" % (v / 1.0e12)).replace(".", ",")
	elif a >= 1.0e9:
		t = ("%.2f mil M" % (v / 1.0e9)).replace(".", ",")
	elif a >= 1.0e6:
		t = ("%.2f M" % (v / 1.0e6)).replace(".", ",")
	else:
		t = hud.fmt_num(v)
	return "%s %s" % [simbolo, t]


## Tipo de cambio legible: «1 US$ = 4.083 COP» si la divisa vale menos que el dólar, «1 EUR = 1,08 US$» si vale más.
func fmt_cambio(dv) -> String:
	if dv.codigo == "USD":
		return "moneda de referencia (1 US$ = 1 US$)"
	if dv.por_usd >= 1.0:
		var u: float = dv.por_usd
		var txt: String = hud.fmt_num(u) if u >= 100.0 else ("%.2f" % u).replace(".", ",")
		return "1 US$ = %s %s" % [txt, dv.codigo]
	return "1 %s = %s US$" % [dv.codigo, ("%.2f" % dv.valor_usd()).replace(".", ",")]


func _simbolo_de(pais: String) -> String:
	var d = mundo.divisa_de(pais)
	return d.simbolo if d != null else "US$"


func _actualizar_barra() -> void:
	if hud == null or reloj == null or mundo == null:
		return
	hud.set_fecha(reloj.texto())
	var j: String = mundo.jugador
	if j == "" or not mundo.paises.has(j):
		hud.set_jugador("", "x")
		return
	hud.set_jugador(_nombre_vis(j), _bandera_pais(j))
	var sim := _simbolo_de(j)
	var bal: float = mundo.balance_diario_local(j)
	hud.set_dinero(fmt_dinero(mundo.paises[j].tesoreria, sim), "%s%s por día" % ["+" if bal >= 0.0 else "−", fmt_dinero(absf(bal), sim)], bal < 0.0, mundo.paises[j].tesoreria < 0.0)


## Datos que cambian cuando las provincias cambian de dueño o se editan (población y superficie del país).
func _actualizar_datos_pais(d: Dictionary, pais: String) -> void:
	if mundo == null or not mundo.paises.has(pais):
		return
	var tids := []
	for pi in mundo.paises[pais].provincias:
		tids.append(mundo.provincias[int(pi)].tid)
	if tids.size() > 0:
		d["pob"] = mundo.poblacion_de(pais)
		d["area"] = mundo.bd.suma("area_km2", tids)
	else:
		d["pob"] = 0.0
		d["area"] = 0.0


func _nombre_vis(pais: String) -> String:
	if mundo != null and mundo.paises.has(pais):
		return mundo.paises[pais].nombre_visible
	return pais


## Filas de la sección «Finanzas» del país. Cada fila: [título, valor, icono, clave del detalle]. El detalle sale en `_fin_detalles`.
func _fin_pais(pais: String) -> Array:
	var r := []
	if mundo == null or not mundo.paises.has(pais):
		return r
	var e = mundo.paises[pais]
	var dv = mundo.divisa_de(pais)
	var sim := _simbolo_de(pais)
	var diario: float = mundo.ingreso_diario_local(pais)
	var prod: float = mundo.produccion_anual_usd(pais)
	var con_caja: bool = e.tiene_tesoreria()                       # desde 0.1.8.1 todos los países tienen tesorería, no solo el jugador
	if con_caja:
		r.append(["Tesorería", fmt_dinero(e.tesoreria, sim) + ("  (EN ROJO)" if e.tesoreria < 0.0 else ""), "i_moneda", "fin_tes"])
	r.append(["Ingresos del estado por día", fmt_dinero(diario, sim), "i_moneda", "fin_ing"])
	r.append(["Ingresos del estado por mes", fmt_dinero(diario * DIAS_MES_MEDIO, sim), "i_moneda", "fin_ing"])
	r.append(["Ingresos del estado por año", fmt_dinero(diario * 365.25, sim), "i_moneda", "fin_ing"])
	if con_caja:
		var gasto: float = mundo.mantenimiento_diario_local(pais)
		var bal: float = diario - gasto
		r.append(["Gasto del ejército por día", fmt_dinero(gasto, sim), "i_moneda", "fin_tes"])
		r.append(["Balance por día", ("+" if bal >= 0.0 else "−") + fmt_dinero(absf(bal), sim), "i_moneda", "fin_tes"])
	r.append(["Impuestos", hud.pct(e.tasa_fiscal * 100.0) + " de la producción", "i_gob", "fin_imp"])
	r.append(["Producción anual de sus provincias", fmt_dinero(prod, "US$"), "i_prov", "fin_prov"])
	var tops := []
	var total: float = maxf(prod, 1.0)
	for t in mundo.top_provincias(pais, 3):
		var pr = mundo.provincias[int(t[0])]
		tops.append("%s %s" % [pr.nombre, hud.pct(float(t[1]) / total * 100.0)])
	if tops.size() > 0:
		r.append(["Provincias que más aportan", " · ".join(PackedStringArray(tops)), "i_prov", "fin_prov"])
	r.append(["PIB de referencia (%d)" % epoca, fmt_dinero(e.pib_usd, "US$"), "i_eco", "fin_pib"])
	r.append(["Velocidad de desarrollo", ("x%.2f" % e.velocidad_desarrollo).replace(".", ","), "i_eco", "fin_des"])
	r.append(["Favorabilidad media de la población", "%d / 100" % int(roundf(mundo.favorabilidad_media(pais))), "i_pob", "fin_fav"])
	if dv != null:
		r.append(["Divisa", "%s (%s)" % [dv.nombre, dv.simbolo], "i_moneda", "fin_div"])
		r.append(["Valor de la divisa", fmt_cambio(dv), "i_moneda", "fin_div"])
	return r


const DIAS_MES_MEDIO := 30.4375


func _c(t: String) -> String:
	return "[color=#9fb4d6]%s[/color]" % t


func _nota_pie(t: String) -> String:
	return "\n[color=#7f8fb0]%s[/color]" % t


## Texto de cada detalle económico (se abre al pulsar una fila de Finanzas). {clave: {icono, titulo, bb, barras}}
func _fin_detalles(pais: String) -> Dictionary:
	var det := {}
	if mundo == null or not mundo.paises.has(pais):
		return det
	var e = mundo.paises[pais]
	var sim := _simbolo_de(pais)
	var dv = mundo.divisa_de(pais)
	var por_usd: float = dv.por_usd if dv != null else 1.0
	var diario: float = mundo.ingreso_diario_local(pais)
	var prod: float = mundo.produccion_anual_usd(pais)
	var total: float = maxf(prod, 1.0)
	var tasa: float = e.tasa_fiscal
	var es_jug: bool = mundo.jugador == pais

	# Tesorería (todos los países desde 0.1.8.1): saldo, entradas y salidas de cada día e historial de cierres mensuales
	if e.tiene_tesoreria():
		var hist: Array = mundo.bd.historial_de("tesoreria", e.tid, 13)
		var barras := []
		var gasto_d: float = mundo.mantenimiento_diario_local(pais)
		var bal_d: float = diario - gasto_d
		var texto := "%s %s%s\n%s +%s\n%s −%s\n%s %s%s\n" % [_c("Tesorería actual:"), fmt_dinero(e.tesoreria, sim), "  (EN ROJO: los soldados desertan)" if e.tesoreria < 0.0 else "",
			_c("Entra cada día:"), fmt_dinero(diario, sim), _c("Sale cada día (mantenimiento del ejército):"), fmt_dinero(gasto_d, sim),
			_c("Balance diario:"), "+" if bal_d >= 0.0 else "−", fmt_dinero(absf(bal_d), sim)]
		var mx := 1.0
		for h in hist:
			mx = maxf(mx, float(h["valor"]))
		var previo := -1.0
		var lineas := ""
		for h in hist:
			var f: int = int(h["hasta"]) if not bool(h["actual"]) else BDScript.fecha_int(reloj.anio, reloj.mes, reloj.dia)
			var partes: PackedStringArray = BDScript.fecha_texto(f).split(",")
			var etiqueta := "%s,%s" % [partes[0], partes[1]] if partes.size() >= 2 else "—"
			if bool(h["actual"]):
				etiqueta = "Hoy"
			barras.append([etiqueta, 100.0 * float(h["valor"]) / mx])
			var delta := "" if previo < 0.0 else "  (%s%s)" % ["+" if float(h["valor"]) >= previo else "", fmt_dinero(float(h["valor"]) - previo, sim)]
			lineas += "%s: %s%s\n" % [etiqueta, fmt_dinero(float(h["valor"]), sim), delta]
			previo = float(h["valor"])
		texto += "\n" + _c("Foto de la tesorería (cierre de cada mes):") + "\n" + (lineas if lineas != "" else "Aún no hay cierres: el primero llega al terminar el mes.\n")
		texto += _nota_pie("La barra «Hoy» es el saldo actual. Cada cierre mensual queda guardado en la base de datos (tabla de historial de «tesorería»). El estado paga cada día el mantenimiento de su ejército; si la tesorería queda en negativo, los soldados empiezan a desertar. Aún no hay otros gastos.")
		det["fin_tes"] = {"icono": "i_moneda", "titulo": "Tesorería", "bb": texto, "barras": barras}

	# Ingresos
	var en_usd := diario / maxf(por_usd, 1e-12)
	var t_ing := "%s %s\n%s %s\n%s %s\n\n" % [_c("Por día:"), fmt_dinero(diario, sim), _c("Por mes (30,4 días):"), fmt_dinero(diario * DIAS_MES_MEDIO, sim), _c("Por año:"), fmt_dinero(diario * 365.25, sim)]
	t_ing += "%s %s al día  ·  %s al año\n" % [_c("En dólares:"), fmt_dinero(en_usd, "US$"), fmt_dinero(en_usd * 365.25, "US$")]
	t_ing += "%s %s de la producción de sus provincias\n\n" % [_c("Cobra:"), hud.pct(tasa * 100.0)]
	t_ing += _c("Fórmula:") + "\ningreso diario = producción anual × impuestos ÷ 365,25 × valor de la divisa"
	t_ing += _nota_pie("La producción de cada provincia = habitantes × producción por habitante × multiplicador × (0,5 + favorabilidad ÷ 100).")
	det["fin_ing"] = {"icono": "i_moneda", "titulo": "Ingresos del estado", "bb": t_ing, "barras": []}

	# Impuestos
	var t_imp := "%s %s\n%s %s al año\n%s %s al año\n" % [_c("Tasa actual:"), hud.pct(tasa * 100.0), _c("Producción total:"), fmt_dinero(prod, "US$"), _c("Recaudación:"), fmt_dinero(prod * tasa, "US$")]
	t_imp += "\n" + _c("Con otra tasa recaudarías (al año):") + "\n"
	for tz in [0.10, 0.25, 0.40, 0.60]:
		t_imp += "%s → %s\n" % [hud.pct(tz * 100.0), fmt_dinero(prod * tz * por_usd, sim)]
	t_imp += _nota_pie("Por ahora subir impuestos no tiene costo político (mecánica en desarrollo). " + ("Cámbialos con el lápiz junto al nombre de tu país." if es_jug else "El Debug permite cambiarlos en el país que controlas."))
	det["fin_imp"] = {"icono": "i_gob", "titulo": "Impuestos", "bb": t_imp, "barras": []}

	# Provincias
	var barras_p := []
	var t_prov := "%s %s al año\n\n" % [_c("Producción total:"), fmt_dinero(prod, "US$")]
	var cuantas := 0
	for t in mundo.top_provincias(pais, 10):
		var pr = mundo.provincias[int(t[0])]
		var pc := float(t[1]) / total * 100.0
		barras_p.append([pr.nombre, pc])
		cuantas += 1
		t_prov += "%d. %s: %s  ·  %s hab.\n" % [cuantas, pr.nombre, fmt_dinero(float(t[1]), "US$"), hud.fmt_num(pr.poblacion)]
	t_prov += _nota_pie("Las barras son el porcentaje de la producción del país que aporta cada provincia (las 10 mayores).")
	det["fin_prov"] = {"icono": "i_prov", "titulo": "Producción por provincia", "bb": t_prov, "barras": barras_p}

	# PIB de referencia
	var t_pib := "%s %s\n%s %s al año\n" % [_c("PIB de referencia %d:" % epoca), fmt_dinero(e.pib_usd, "US$"), _c("Producción actual de las provincias:"), fmt_dinero(prod, "US$")]
	if e.pib_usd > 0.0:
		t_pib += "%s %s\n" % [_c("Relación (producción ÷ PIB):"), hud.pct(prod / e.pib_usd * 100.0)]
	t_pib += _nota_pie("El PIB de referencia es el punto de partida (no cambia). La producción de las provincias sí crece o cae con el desarrollo, las conquistas y la favorabilidad.")
	det["fin_pib"] = {"icono": "i_eco", "titulo": "PIB de referencia", "bb": t_pib, "barras": []}

	# Desarrollo
	var base: float = mundo.bd.num("crecimiento_base_anual", mundo.bd.id_de("mundo", "mundo"), 0.02)
	var vp: float = e.velocidad_desarrollo
	var t_des := "%s x%s\n%s %s al año (con velocidad x1,00)\n%s %s al año\n" % [_c("Velocidad de desarrollo del país:"), ("%.2f" % vp).replace(".", ","), _c("Crecimiento base:"), hud.pct(base * 100.0), _c("Crecimiento efectivo (si la provincia tiene x1):"), hud.pct(base * vp * 100.0)]
	t_des += _nota_pie("Cada mes la producción por habitante de cada provincia crece según: crecimiento base × velocidad de la provincia × velocidad de su país dueño. El 2 % anual es un valor provisional.")
	det["fin_des"] = {"icono": "i_eco", "titulo": "Velocidad de desarrollo", "bb": t_des, "barras": []}

	# Favorabilidad
	var fav: float = mundo.favorabilidad_media(pais)
	var t_fav := "%s %d / 100\n%s x%s\n\n" % [_c("Favorabilidad media (ponderada por habitantes):"), int(roundf(fav)), _c("Rinde:"), ("%.2f" % (0.5 + fav / 100.0)).replace(".", ",")]
	var barras_f := []
	var ext: Array = mundo.extremos_favorabilidad(pais)
	var n_prov: int = e.provincias.size()
	for t in ext[0]:
		barras_f.append([String(t[0]), float(t[1])])
	if n_prov > 3:                                             # con ≤ 3 provincias las «peores» repetirían a las «mejores»
		var peores: Array = ext[1]
		var n_pe: int = mini(3, n_prov - 3)
		for i in n_pe:
			barras_f.append([String(peores[i][0]), float(peores[i][1])])
	t_fav += _c("Las 3 provincias más contentas y las 3 más descontentas (barras).") + "\n"
	t_fav += _nota_pie("0 = la provincia rinde la mitad (x0,5); 100 = rinde una vez y media (x1,5). Las provincias conquistadas empiezan en 35.")
	det["fin_fav"] = {"icono": "i_pob", "titulo": "Favorabilidad", "bb": t_fav, "barras": barras_f}

	# Divisa
	if dv != null:
		var t_div := "%s %s (%s) · código %s\n%s %s\n" % [_c("Moneda:"), dv.nombre, dv.simbolo, dv.codigo, _c("Valor:"), fmt_cambio(dv)]
		t_div += _nota_pie("Todos los cálculos internos se hacen en dólares y se convierten a la moneda del país al mostrarlos. Puedes cambiar tu moneda con el lápiz junto al nombre de tu país.")
		det["fin_div"] = {"icono": "i_moneda", "titulo": "Divisa", "bb": t_div, "barras": []}
	return det


func _fin_provincia(pi: int) -> Array:
	var pr = mundo.provincias[pi]
	var sim := _simbolo_de(pr.pais)
	var dv = mundo.divisa_de(pr.pais)
	var rend: float = pr.rendimiento_usd()                      # lo que produce (ocupada o no)
	var local: float = rend * (dv.por_usd if dv != null else 1.0)
	var total_pais: float = maxf(mundo.produccion_anual_usd(pr.pais), 1.0)
	var filas := []
	if pr.ocupante >= 0:
		filas.append(["OCUPADA por %s" % mundo.bd.nombre_de(pr.ocupante), "No aporta ingresos a su dueño hasta que la libere o haya paz", "i_devast"])
	filas.append_array([
		["Producción anual de la provincia", fmt_dinero(rend, "US$") + "  ·  " + fmt_dinero(local, sim), "i_eco"],
		["Aporta al total del país", hud.pct(pr.ingreso_efectivo_usd() / total_pais * 100.0), "i_pais"],
		["Producción por habitante", fmt_dinero(pr.pib_pc, "US$") + " al año", "i_eco"],
		["Favorabilidad de la población", "%d / 100" % int(roundf(pr.favorabilidad)), "i_pob"],
		["Multiplicador de ingreso", ("x%.2f" % pr.mult_ingreso).replace(".", ","), "i_eco"],
		["Velocidad de desarrollo", ("x%.2f" % pr.velocidad_desarrollo).replace(".", ","), "i_eco"],
	])
	if pr.devastacion > 0.0:
		filas.append(["Devastación", "%s · produce %s menos" % [hud.pct(pr.devastacion * 100.0), hud.pct(pr.devastacion * 85.0)], "i_devast"])
	var h: Dictionary = mundo.bd.heredado("produccion_principal", pr.tid)
	if not h.is_empty():
		var de: String = "propia" if int(h["de"]) == pr.tid else "de " + mundo.bd.nombre_de(int(h["de"]))
		filas.append(["Producción principal (%s)" % de, String(h["valor"]), "i_cultivo"])
	return filas


# ─────────────────────────────────────────────────────────────
# Ejército (0.1.7.9.9D): lo que pide la pestaña «Ejército» del panel
# ─────────────────────────────────────────────────────────────
func _ej_anio() -> int:
	return floori(float(mundo.bd.fecha) / 10000.0) - 100000


## Reparto de una lista de pelotones por provincia: [[nombre, soldados, pelotones], ...] de mayor a menor.
func _ej_reparto_prov(lista: Array) -> Array:
	var ej = mundo.ejercito
	var por := {}
	for id in lista:                                  # `lista`: IDs de pelotón
		var t: int = mundo.bd.ref("ubicacion", int(id))
		if not por.has(t):
			por[t] = [0, 0]
		por[t][0] += ej.soldados_de(int(id))
		por[t][1] += 1
	var r := []
	for t in por:
		var pr = ej.provincia_por_tid(int(t))
		r.append([pr.nombre if pr != null else "?", int(por[t][0]), int(por[t][1])])
	r.sort_custom(func(a, b): return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and String(a[0]) < String(b[0])))
	return r


## Lo que muestra la pestaña «Ejército» según lo seleccionado. {} = sin ejército que mostrar.
func ejercito_vista() -> Dictionary:
	if mundo == null or mundo.ejercito == null:
		return {}
	var ej = mundo.ejercito
	var fecha: int = mundo.bd.fecha
	var v := {"alcance": sel_tipo}
	match sel_tipo:
		"pais":
			var pais := String(sel_ref.get("pais", ""))
			if not mundo.paises.has(pais):
				return {}
			var ent = mundo.paises[pais]
			var lista: Array = ej.de_pais(ent.tid)
			var pob: float = mundo.poblacion_de(pais)
			v["titulo"] = "Ejército de " + _nombre_vis(pais)
			v["resumen"] = ej.resumen(lista)
			v["pob"] = pob
			var rep: Array = _ej_reparto_prov(lista)
			v["reparto_n"] = rep.size()
			v["reparto"] = rep.slice(0, 8)
			v["reparto_titulo"] = "Dónde está su ejército"
			var extra := 0
			for pi in ent.provincias:
				for id_p in ej.en_provincia(int(mundo.provincias[int(pi)].tid)):
					if ej.pais_de(int(id_p)) != ent.tid:
						extra += ej.soldados_de(int(id_p))
			v["extranjeros"] = extra
			var cad: Array = mundo.mandos.cadena(pais, ent.continente, {"pelotón": 0, "provincia": 0, "país": ent.tid}, _ej_anio(), mundo.jefe_de_estado(pais, fecha), "", 0)
			v["mando"] = cad.slice(0, 2)
		"continente":
			var cont := String(sel_ref.get("cont", ""))
			var lista2 := []
			var por_pais := []
			for pn in mundo.paises:
				var e2 = mundo.paises[pn]
				if e2.continente != cont:
					continue
				var l: Array = ej.de_pais(e2.tid)
				if l.is_empty():
					continue
				lista2.append_array(l)
				por_pais.append([_nombre_vis(pn), int(ej.resumen(l)["soldados"]), l.size()])
			por_pais.sort_custom(func(a, b): return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and String(a[0]) < String(b[0])))
			v["titulo"] = "Ejércitos de " + cont
			v["resumen"] = ej.resumen(lista2)
			v["reparto_n"] = por_pais.size()
			v["reparto"] = por_pais.slice(0, 8)
			v["reparto_titulo"] = "Países con más tropas"
		"estado":
			var k := "%s|%s" % [String(sel_ref.get("pais", "")), String(sel_ref.get("estado", ""))]
			if not mundo.estados.has(k):
				return {}
			var tids := []
			for pi in mundo.estados[k].provincias:
				tids.append(int(mundo.provincias[int(pi)].tid))
			var lista3: Array = ej.en_provincias(tids)
			v["titulo"] = "Tropas en " + String(sel_ref.get("estado", ""))
			v["resumen"] = ej.resumen(lista3)
			var rep3: Array = _ej_reparto_prov(lista3)
			v["reparto_n"] = rep3.size()
			v["reparto"] = rep3.slice(0, 8)
			v["reparto_titulo"] = "Dónde están"
		"provincia", "ciudad":
			var pi2 := -1
			if sel_tipo == "provincia":
				pi2 = int(sel_ref.get("pi", -1))
			else:
				pi2 = int(mundo.ciudades[int(sel_ref["id"])].provincia)
			if pi2 < 0 or pi2 >= mundo.provincias.size():
				return {}
			var pr = mundo.provincias[pi2]
			var lista4: Array = ej.en_provincia(int(pr.tid))
			v["titulo"] = "Tropas en esta provincia" if sel_tipo == "provincia" else "Tropas en la provincia de la ciudad"
			v["resumen"] = ej.resumen(lista4)
			var pels := []
			for id_p in lista4:
				var f: Dictionary = ej.ficha(int(id_p))
				if f.is_empty():
					continue
				pels.append([int(f["id"]), int(f["soldados"]), float(f["exp"]), float(f["fam"]), mundo.bd.nombre_de(int(f["pais_tid"])),
					int(f["pais_tid"]) != int(mundo.bd.ref("propietario", pr.tid)), int(f["numero"])])
			pels.sort_custom(func(a, b): return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and int(a[0]) < int(b[0])))
			v["pelotones_n"] = pels.size()
			v["pelotones"] = pels.slice(0, 40)
			v["prov_tid"] = int(pr.tid)
			v["devastacion"] = pr.devastacion
			v["motin"] = mundo.riesgo_motin(pi2)
			v["favorabilidad"] = pr.favorabilidad
		_:
			return {}
	return v


## Detalle de un pelotón (ID de pelotón): estado de la tropa y cadena de mando con nombres. Formato de `_detalle_fin`.
func ejercito_detalle(id: int) -> Dictionary:
	var ej = mundo.ejercito
	var f: Dictionary = ej.ficha(id)
	if f.is_empty():
		return {"icono": "i_ejercito", "titulo": "Pelotón %d" % ej.numero(id), "bb": "Este pelotón ya no existe (fue disuelto).", "barras": []}
	var pais: String = mundo.bd.nombre_de(int(f["pais_tid"]))
	var cont := ""
	if mundo.paises.has(pais):
		cont = mundo.paises[pais].continente
	var anio := _ej_anio()
	var fecha: int = mundo.bd.fecha
	var cad: Array = mundo.mandos.cadena(pais, cont, {"pelotón": id, "provincia": int(f["prov_tid"]), "país": int(f["pais_tid"])}, anio,
		mundo.jefe_de_estado(pais, fecha), String(f["provincia"]))
	var t := "[color=#9fb4d6]País:[/color] %s\n[color=#9fb4d6]Ubicación:[/color] %s\n" % [_nombre_vis(pais), f["provincia"]]
	t += "[color=#9fb4d6]Soldados:[/color] %s de %d\n[color=#9fb4d6]Edad media:[/color] %s años\n" % [fmt_n(float(f["soldados"])), int(ejercito_tam()), ("%.1f" % float(f["edad"])).replace(".", ",")]
	t += "[color=#9fb4d6]Bajas totales:[/color] %s" % fmt_n(float(f["bajas"]))
	if float(f["bajas_mes"]) > 0.0:
		t += "  ([color=#ff9a7a]%s de la tropa este mes[/color])" % hud.pct(float(f["bajas_mes"]) * 100.0)
	t += "\n\n[color=#e9c76a]CADENA DE MANDO[/color]\n"
	for fila in cad:
		var col := "#ffd479" if bool(fila["real"]) else "#f2f5ff"
		t += "[color=#9fb4d6]%s[/color]\n   [color=%s]%s[/color]\n" % [fila["cargo"], col, fila["nombre"]]
	var era: Dictionary = mundo.mandos.era_de(anio)
	t += "\n[color=#7f8fb0]Los nombres se generan al abrir el pelotón según la cultura de %s (%s) y la época (%s); no se guardan. El jefe de Estado sale de Wikidata cuando se conoce (en dorado). Los soldados rasos no se muestran.[/color]" % [
		_nombre_vis(pais), mundo.mandos.etiqueta_cultura(mundo.mandos.cultura_de(pais, cont)), String(era.get("nombre", ""))]
	return {"icono": "i_ejercito", "titulo": "Pelotón %d" % int(f["numero"]), "bb": t, "barras": [
		["Dotación", float(f["soldados"]) / float(ejercito_tam()) * 100.0], ["Experiencia", float(f["exp"])],
		["Familiaridad", float(f["fam"])], ["Forma física", float(f["fis"])]]}


func ejercito_tam() -> int:
	return mundo.ejercito.TAM_PELOTON


## Fecha de la base (entero AAAAMMDD con año desplazado) como "dd/mm/aaaa"; "—" si no hay.
func _fecha_txt(f: int) -> String:
	if f <= 0:
		return "—"
	return "%02d/%02d/%d" % [f % 100, floori(f / 100.0) % 100, floori(f / 10000.0) - 100000]


## País al que pertenece lo seleccionado ("" = continente o mar).
func _pais_de_seleccion() -> String:
	match sel_tipo:
		"pais", "estado", "provincia":
			return String(sel_ref.get("pais", ""))
		"ciudad":
			if mundo != null and sel_ref.has("id"):
				return String(mundo.ciudades[int(sel_ref["id"])].pais)
	return ""


## Datos de la pestaña Política: de momento solo el jefe de Estado conocido en la fecha actual.
func politica_vista() -> Dictionary:
	var pais := _pais_de_seleccion()
	if mundo == null or pais == "" or not mundo.paises.has(pais):
		return {}
	return {"jefe": mundo.jefe_de_estado(pais, mundo.bd.fecha)}


## 0.1.8.3: ¿puede el jugador dar órdenes a las tropas de `pais`? En el modo libre (Debug) las de cualquier país; en la campaña solo las del tuyo
## (y como observador, de ninguno).
func puede_ordenar_pais(pais: String) -> bool:
	if mundo == null:
		return false
	if mundo.jugador == "":
		return not campana_activa
	return pais == mundo.jugador


## Datos de la pestaña Diplomacia del país seleccionado: guerras (abiertas y terminadas), tropas cruzadas, aliados y vecinos por tierra.
## {} = no hay país seleccionado.
func diplomacia_vista() -> Dictionary:
	if mundo == null or mundo.guerra == null or mundo.ejercito == null or sel_tipo != "pais":
		return {}
	var pais := String(sel_ref.get("pais", ""))
	if not mundo.paises.has(pais):
		return {}
	var g = mundo.guerra
	var ej = mundo.ejercito
	var ent = mundo.paises[pais]
	var tid := int(ent.tid)
	var guerras := []
	for gid in g.guerras_historial_de(tid):
		var f: Dictionary = g.ficha_guerra(int(gid))
		if f.is_empty():
			continue
		var agresor: bool = int(f["agresor"]) == tid
		var rival_tid: int = int(f["defensor"]) if agresor else int(f["agresor"])
		var rival: String = mundo.bd.nombre_de(rival_tid)
		var gd := {"activa": bool(f["activa"]), "rival": rival, "rival_tid": rival_tid, "rival_bandera": _bandera_pais(rival),
			"rol": "Agresor" if agresor else "Defensor", "causa": String(f["causa"]), "inicio_txt": _fecha_txt(int(f["inicio"])),
			"fin_txt": _fecha_txt(int(f["fin"])), "batallas": int(f["batallas"]),
			"bajas_propias": int(f["bajas_agresor"]) if agresor else int(f["bajas_defensor"]),
			"bajas_rival": int(f["bajas_defensor"]) if agresor else int(f["bajas_agresor"]),
			"agresor": int(f["agresor"]), "defensor": int(f["defensor"])}
		if bool(f["activa"]):                         # ocupación y opciones de paz (0.1.8.1)
			gd["ocupa_rival_n"] = g.provincias_ocupadas(tid, rival_tid).size()
			gd["ocupa_rival_pct"] = g.participacion_ocupada(tid, rival_tid)
			gd["ocupa_mias_n"] = g.provincias_ocupadas(rival_tid, tid).size()
			gd["ocupa_mias_pct"] = g.participacion_ocupada(rival_tid, tid)
			gd["puntaje"] = g.puntaje_guerra(tid, rival_tid)
			gd["paz"] = _opciones_paz(tid, rival_tid)
		guerras.append(gd)
	# tropas cruzadas
	var extranjeros := 0
	for pi in ent.provincias:
		for id_p in ej.en_provincia(int(mundo.provincias[int(pi)].tid)):
			if ej.pais_de(int(id_p)) != tid:
				extranjeros += ej.soldados_de(int(id_p))
	var afuera := 0
	for rid in ej.regs_pais.get(tid, []):
		if ej.en_marcha_reg(int(rid)):
			continue
		var pr = ej.provincia_por_tid(ej.prov_de(int(rid)))
		if pr != null and ej.dueno_de_provincia(int(pr.idx)) != tid:
			afuera += ej.soldados_reg(int(rid))
	# aliados y vasallos (gancho: todavía no existen)
	var rel := []
	for r in mundo.relacionados_de(pais):
		rel.append({"nombre": String(r), "bandera": _bandera_pais(String(r))})
	# vecinos por tierra
	var cuenta := {}
	var red = ej.red
	if red != null and red.listo:
		for pi in ent.provincias:
			for q in red.vecinos(int(pi)):
				var t: Array = red.tramo(int(pi), int(q))
				if t.is_empty() or int(t[1]) == 1:
					continue                              # por mar no cuenta como frontera
				var otro: String = mundo.provincias[int(q)].pais
				if otro != "" and otro != pais and mundo.paises.has(otro):
					cuenta[otro] = int(cuenta.get(otro, 0)) + 1
	var vecinos := []
	for nom in cuenta:
		vecinos.append({"nombre": String(nom), "bandera": _bandera_pais(String(nom)), "tramos": int(cuenta[nom]),
			"guerra": g.en_guerra(tid, int(mundo.paises[nom].tid))})
	vecinos.sort_custom(func(a, b): return int(a["tramos"]) > int(b["tramos"]) or (int(a["tramos"]) == int(b["tramos"]) and String(a["nombre"]) < String(b["nombre"])))
	var sucesos := []
	for ev in mundo.eventos_de(tid, 12):
		sucesos.append({"fecha_txt": _fecha_txt(int(ev["fecha"])), "texto": String(ev["texto"])})
	# 0.1.8.3 · declarar la guerra desde el menú: la relación del jugador con el país elegido, o (en su propia ficha) a quién podría declarársela
	var relacion := {}
	var declarables := []
	var jug: String = mundo.jugador
	if jug != "" and mundo.paises.has(jug):
		var jt := int(mundo.paises[jug].tid)
		if pais != jug:
			var evd: Dictionary = puede_declarar_guerra(tid)
			relacion = {"rival": String(ent.nombre_visible), "tid": tid, "bandera": _bandera_pais(pais), "en_guerra": g.en_guerra(jt, tid),
				"tregua": _tregua_dias(jt, tid), "puede": bool(evd["ok"]), "motivo": String(evd["motivo"])}
		else:
			for vn in vecinos:
				if bool(vn["guerra"]):
					continue
				var tv: int = int(mundo.paises[String(vn["nombre"])].tid)
				var evv: Dictionary = puede_declarar_guerra(tv)
				declarables.append({"nombre": String(mundo.paises[String(vn["nombre"])].nombre_visible), "tid": tv, "bandera": String(vn["bandera"]),
					"tregua": _tregua_dias(jt, tv), "puede": bool(evv["ok"]), "motivo": String(evv["motivo"])})
	return {"relacion": relacion, "declarables": declarables, "tid": tid, "guerras": guerras, "extranjeros_aqui": extranjeros, "propias_afuera": afuera, "relacionados": rel, "vecinos": vecinos.slice(0, 30),
		"sucesos": sucesos, "tesoreria_en_rojo": ent.tiene_tesoreria() and ent.tesoreria < 0.0,
		"puede_ordenar": puede_ordenar_pais(pais)}


## Días de tregua que quedan entre el jugador y otro país (0 = ninguna).
func _tregua_dias(a_tid: int, b_tid: int) -> int:
	return mundo.ia.tregua_restante(a_tid, b_tid) if mundo.ia != null else 0


## 0.1.8.3 · «2 años y 3 meses», «5 meses», «12 días».
func texto_duracion(dias: int) -> String:
	if dias >= 365:
		var a := dias / 365
		var m := (dias % 365) / 30
		return "%d %s" % [a, "año" if a == 1 else "años"] + ("" if m == 0 else " y %d %s" % [m, "mes" if m == 1 else "meses"])
	if dias >= 45:
		return "%d meses" % int(roundf(float(dias) / 30.0))
	return "%d %s" % [dias, "día" if dias == 1 else "días"]


## 0.1.8.3 · DECLARAR LA GUERRA desde el menú (pestaña Diplomacia). Devuelve {"ok", "motivo"}: si el jugador puede declararle la guerra a ese país ahora.
## Reglas: hay que controlar un país (el observador no declara), no estar ya en guerra ni ser aliados, el rival tiene que existir y, en la campaña, tener IA
## (sin competencia no hay conquista). Una tregua NO lo impide (solo ata a la IA): el jugador puede romperla, y la pestaña se lo avisa.
func puede_declarar_guerra(rival_tid: int) -> Dictionary:
	if mundo == null or mundo.guerra == null or mundo.jugador == "" or not mundo.paises.has(mundo.jugador):
		return {"ok": false, "motivo": "Estás de observador: para declarar guerras controla un país."}
	var jt := int(mundo.paises[mundo.jugador].tid)
	if rival_tid == jt:
		return {"ok": false, "motivo": "Es tu propio país."}
	var rn: String = mundo.bd.nombre_de(rival_tid)
	if not mundo.paises.has(rn) or not mundo.existe_pais(rn):
		return {"ok": false, "motivo": "Ese país ya no existe."}
	if mundo.es_inerte(rn):
		return {"ok": false, "motivo": "Son tierras sin reclamar: no hay gobierno al que declarar la guerra."}
	if mundo.guerra.en_guerra(jt, rival_tid):
		return {"ok": false, "motivo": "Ya estás en guerra con %s." % String(mundo.paises[rn].nombre_visible)}
	if mundo.relacionados_de(mundo.jugador).has(rn):
		return {"ok": false, "motivo": "%s es tu aliado o vasallo." % String(mundo.paises[rn].nombre_visible)}
	if not mundo.puede_atacar(jt, rival_tid):
		return {"ok": false, "motivo": "%s no tiene IA: en la campaña solo se declara la guerra a países controlados por la IA (Debug > IA)." % String(mundo.paises[rn].nombre_visible)}
	return {"ok": true, "motivo": ""}


## Declara la guerra del país del jugador a `rival_tid`. Devuelve {"ok", "msg"}.
func declarar_guerra_jugador(rival_tid: int) -> Dictionary:
	var ev: Dictionary = puede_declarar_guerra(rival_tid)
	if not bool(ev["ok"]):
		return {"ok": false, "msg": String(ev["motivo"])}
	var jt := int(mundo.paises[mundo.jugador].tid)
	var gid: int = mundo.guerra.declarar(jt, rival_tid, "Declaración de guerra")
	if gid < 0:
		return {"ok": false, "msg": "No se pudo declarar la guerra."}
	var rn: String = String(mundo.paises[mundo.bd.nombre_de(rival_tid)].nombre_visible)
	var msg := "Declaraste la guerra a %s." % rn
	mundo.evento(jt, msg, rival_tid)
	if capa_tropas != null:
		capa_tropas.refrescar()
	return {"ok": true, "msg": msg}


## 0.1.8.3 · Si el jugador manda tropas a una provincia de OTRO país sin estar en guerra con él, la orden se bloquea (antes declaraba la guerra sola:
## ahora hay que declararla desde Diplomacia). Devuelve el aviso, o "" si la orden es válida. El observador de dev (sin país) conserva lo de siempre.
func _aviso_sin_guerra(pais_tid: int, pi: int) -> String:
	if mundo == null or mundo.jugador == "":
		return ""
	var rival: int = mundo.rival_por_entrar(pais_tid, pi)
	if rival < 0:
		return ""
	return "No estás en guerra con %s: para entrar en su territorio decláraselo (su ficha > Diplomacia > Declarar la guerra)." % String(mundo.paises[mundo.bd.nombre_de(rival)].nombre_visible)


## Las tres formas de pedir la paz y si el rival las aceptaría hoy: [{"clave", "texto", "acepta", "motivo", "tip"}].
func _opciones_paz(tid: int, rival_tid: int) -> Array:
	var g = mundo.guerra
	var r := []
	for o in [["blanca", "Paz blanca", {}, "Todo vuelve a su dueño: las ocupaciones se anulan."],
			["posesion", "Cada uno se queda con lo ocupado", {"posesion": true}, "Las provincias ocupadas cambian de dueño de verdad, en los dos sentidos."],
			["indemnizacion", "Quedarse con lo ocupado + indemnización", {"posesion": true, "indemnizacion": true},
				"Además cobras hasta 90 días de ingresos del rival (sin pasar de lo que tenga en caja). Exige haberle ocupado bastante."]]:
		var ev: Dictionary = g.evaluar_paz(tid, rival_tid, o[2])
		r.append({"clave": String(o[0]), "texto": String(o[1]), "acepta": bool(ev["acepta"]), "motivo": String(ev["motivo"]), "tip": String(o[3])})
	return r


## Se propone la paz con condiciones desde la pestaña Diplomacia. Devuelve lo mismo que `Guerra.proponer_paz` ({"ok", "msg"}).
func proponer_paz(a_tid: int, b_tid: int, clave: String) -> Dictionary:
	if mundo == null or mundo.guerra == null:
		return {"ok": false, "msg": ""}
	var t := {}
	if clave == "posesion":
		t = {"posesion": true}
	elif clave == "indemnizacion":
		t = {"posesion": true, "indemnizacion": true}
	var res: Dictionary = mundo.guerra.proponer_paz(a_tid, b_tid, t)
	if bool(res.get("ok", false)):
		if capa_tropas != null:
			capa_tropas.refrescar()
		_sincronizar_propiedad(false, false)
	return res


## Aviso corto en la línea de ayuda de abajo.
func hud_aviso(t: String) -> void:
	if hud != null:
		hud.set_hint(t)


# Atrás (botón ↩ / tecla Retroceso): sube un nivel y, al llegar arriba, cierra el panel. Sirve para todo tipo de selección.
func _atras() -> void:
	if not hud.esta_abierto():
		if pais_foco != "":
			_salir_foco()
		return
	var cont := String(sel_ref.get("cont", ""))
	match sel_tipo:
		"ciudad":
			var c = mundo.ciudades[int(sel_ref["id"])]
			_limpiar_seleccion()
			if c.provincia >= 0 and bool(provincias[c.provincia]["m"]) and mundo.paises.has(c.pais):
				_seleccion_provincia(c.provincia, mundo.paises[c.pais].continente, ultimo_p)
			elif mundo.paises.has(c.pais):
				_seleccion_pais(c.pais, mundo.paises[c.pais].continente, ultimo_p)
			else:
				hud.ocultar()
		"provincia", "estado":
			var pais := String(sel_ref.get("pais", ""))
			_limpiar_seleccion()
			if mundo.paises.has(pais):
				_seleccion_pais(pais, cont, ultimo_p)
			else:
				hud.ocultar()
		_:
			# país, continente o mar: se cierra el panel (y se sale del país enfocado, si lo hay)
			_limpiar_seleccion()
			_salir_foco()
			hud.ocultar()
			_soltar_seleccion_tropas()
	_actualizar_hint()


# ─────────────────────────────────────────────────────────────
# Fusión de provincias (0.1.7.9.9F): el mapa se repinta desde el dueño ACTUAL de cada provincia
#   · relleno: color exacto del país dueño      · fronteras: solo entre dueños distintos
#   · nombres: el país que absorbió territorio recalcula su nombre; el anexado desaparece
# ─────────────────────────────────────────────────────────────
## Color de identidad de un país para los cuadritos de tropas (no es el color del mapa: distingue países del mismo continente).
func _color_ejercito(pais: String) -> Color:
	var h := float(absi(pais.hash()) % 360) / 360.0
	return Color.from_hsv(h, 0.55, 0.95, 0.60)


func _luminosidad(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## Color de un país en el mapa (el mismo que llevan sus provincias propias).
func _color_de_pais(pais: String) -> Color:
	var hex := String(col_pais_hex.get(pais, ""))
	if hex != "":
		return Color.html("#" + hex)
	return _color_de_dueno(int(mundo.bd.id_de("pais", pais)))


const VACIO_ID := -7777                                           # «dueño» de lo que no existe en la campaña (se pinta liso y oscuro)
const COLOR_VACIO := Color(0.085, 0.095, 0.115)


func _color_de_dueno(id: int) -> Color:
	if id == VACIO_ID:
		return COLOR_VACIO
	if _col_dueno.has(id):
		return _col_dueno[id]
	var c := Color(0.55, 0.55, 0.6)
	var nombre: String = mundo.bd.nombre_de(id)
	var hex := String(col_pais_hex.get(nombre, ""))
	if hex != "":
		c = Color.html("#" + hex)
	else:                                                         # dueño que no es un país actual (entidad histórica): color estable
		c = Color.from_hsv(float((id * 47) % 360) / 360.0, 0.5, 0.8)
	_col_dueno[id] = c
	return c


func _indices_prov() -> void:
	if _ix_prov.size() == mundo.provincias.size():
		return
	_ix_prov.resize(mundo.provincias.size())
	for i in mundo.provincias.size():
		_ix_prov[i] = mundo.provincias[i].ix


## Dueño con el que se hornearon los colores de cada provincia (su país original).
## Provincia de cada celda (los anillos del mapa SON las celdas): el campo `p` de cada anillo.
func _celda_prov_de_anillos() -> PackedInt32Array:
	var r := PackedInt32Array()
	r.resize(anillos.size())
	for i in anillos.size():
		r[i] = int(anillos[i]["p"])
	return r


func _dueno_original() -> PackedInt32Array:
	var r := PackedInt32Array()
	if mundo == null:
		return r
	r.resize(mundo.provincias.size())
	for i in mundo.provincias.size():
		r[i] = int(mundo.bd.id_de("pais", mundo.provincias[i].pais_original))
	return r


## Dueño actual de cada provincia (ID leído de la variable `propietario`).
func _dueno_actual() -> PackedInt32Array:
	_indices_prov()
	var col: PackedInt32Array = mundo.bd.vars["propietario"].col_i
	var r := PackedInt32Array()
	r.resize(_ix_prov.size())
	for i in _ix_prov.size():
		r[i] = col[_ix_prov[i]]
	if campana_activa:
		for pi in mundo.excluidas:
			if int(pi) < r.size():
				r[int(pi)] = VACIO_ID
	return r


# 0.1.8.2a · El panel abierto (país, provincia...) se rehace entero (~50 ms) y las guerras cambian ocupaciones varias veces por segundo. Antes se
# rehacía en cada cambio: a velocidad alta eso era lo que hundía los FPS. Ahora, durante el juego, se rehace como mucho cada PANEL_PERIODO_MS
# (el mapa sí se repinta al instante). Los cambios pedidos a mano (`forzar`: Debug, tratados de paz) siguen refrescando al momento.
const PANEL_PERIODO_MS := 900          # a velocidad 1-2
const PANEL_PERIODO_ALTA_MS := 2500   # a velocidad 3 o más (cada rehacer del panel son ~50 ms: mejor pocos y espaciados)
var _panel_pendiente := false
var _t_panel_ms := 0

func _pedir_refresco_panel(refrescar_panel: bool, forzar: bool) -> void:
	if not refrescar_panel:
		return
	if forzar:
		var t_s := Time.get_ticks_usec()
		refrescar_todo(false)
		_ps("refrescar_todo", t_s)
		_panel_pendiente = false
		_t_panel_ms = Time.get_ticks_msec()
	else:
		_panel_pendiente = true


func _refrescar_panel_diferido() -> void:
	if not _panel_pendiente:
		return
	var ahora := Time.get_ticks_msec()
	var periodo: int = PANEL_PERIODO_MS if reloj == null or reloj.velocidad <= 2 else PANEL_PERIODO_ALTA_MS
	if ahora - _t_panel_ms < periodo:
		return
	_panel_pendiente = false
	_t_panel_ms = ahora
	var t_s := Time.get_ticks_usec()
	refrescar_todo(false)
	_ps("refrescar_todo", t_s)


var prof_sinc := {}                   # sección -> [microsegundos, llamadas] del repintado por cambio de dueño/ocupación (Debug > Rend.)

func _ps(sec: String, t0: int) -> void:
	var a: Array = prof_sinc.get(sec, [0, 0])
	a[0] = int(a[0]) + Time.get_ticks_usec() - t0
	a[1] = int(a[1]) + 1
	prof_sinc[sec] = a


## Repinta el mapa si cambió el dueño de alguna provincia (o siempre con `forzar`). Es barato cuando no hay cambios (un entero).
const SINC_MIN_MS := 450
var _t_sinc := 0

func _sincronizar_propiedad(forzar := false, refrescar_panel := false, diferir := false) -> void:
	if mundo == null or fusion == null or not fusion.listo:
		return
	var ver: int = mundo.bd.version_propietario
	var ver_oc: int = mundo.bd.version_ocupacion
	if not forzar and ver == _ver_dueno and ver_oc == _ver_ocup:
		return
	if not forzar and reloj != null and reloj.velocidad >= 3 and Time.get_ticks_msec() - _t_sinc < SINC_MIN_MS:
		return                                                    # 0.1.8.3: a velocidades altas el repintado (~70 ms) se agrupa: como mucho uno cada SINC_MIN_MS
	_t_sinc = Time.get_ticks_msec()
	var cambio_dueno: bool = forzar or ver != _ver_dueno or _dueno_ahora.is_empty()
	_ver_dueno = ver
	_ver_ocup = ver_oc
	var t_s := Time.get_ticks_usec()
	var dueno := _dueno_actual()
	if cambio_dueno and not forzar and dueno == _dueno_ahora:
		cambio_dueno = false                                      # 0.1.8.32: la versión subió pero ningún dueño cambió: no hay fronteras ni nombres que rehacer
	var colores := {}
	var visual := _dueno_visual(dueno, colores)
	_ps("dueno_visual", t_s)
	t_s = Time.get_ticks_usec()
	fusion.pintar(visual, colores)
	_ps("pintar", t_s)
	if not cambio_dueno:                                          # solo cambió quién OCUPA una provincia: bastaba repintar el relleno
		_pedir_refresco_panel(refrescar_panel, forzar)
		return
	_anotar_cambios_dueno(dueno)
	_dueno_ahora = dueno
	_pend_dueno = ["fronteras", "etiquetas", "zoom", "foco"]
	_foco_forzado = _foco_forzado or forzar
	if forzar or not diferir:
		_correr_pend_dueno(true)                                  # pruebas, Debug y cambios pedidos a mano: todo al momento
	_pedir_refresco_panel(refrescar_panel, forzar)


## 0.1.8.32 · El repintado de dueños se reparte en etapas (fronteras, nombres, país enfocado): en el juego en marcha cada fotograma corre UNA, así un
## cambio de dueño ya no es un tirón de ~40 ms sino tres de ~10 ms. (Con `forzar`, o sin `diferir`, corren todas de golpe.)
var _pend_dueno: Array = []                   # etapas que faltan, en orden
var _foco_forzado := false                    # la etapa «foco» se hace sí o sí (cambio pedido a mano: puede haber cambiado hasta el esquema de colores)
var _zoom_pend := false                       # la etapa «zoom» tiene que rehacer el nivel de detalle de los textos (lo dejó pedido «etiquetas»)
var _cambiadas_pend := PackedInt32Array()     # provincias cuyo dueño cambió desde la última vez que se rehízo el país enfocado
var _cambiadas_ant := PackedInt32Array()      # ... y quién las tenía antes


func _correr_pend_dueno(todo := false) -> void:
	while not _pend_dueno.is_empty():
		var et: String = _pend_dueno.pop_front()
		var t_e := Time.get_ticks_usec()
		match et:
			"fronteras":
				_reconstruir_fronteras(_dueno_ahora)
			"etiquetas":
				_actualizar_etiquetas_dueno(_dueno_ahora, not todo)      # en el juego en marcha, el zoom de los textos va en su propia etapa
			"zoom":
				if _zoom_pend:
					_zoom_pend = false
					_actualizar_zoom()
			"foco":
				if pais_foco != "" and (_foco_forzado or _foco_tocado()):
					_refrescar_foco()
				_cambiadas_pend = PackedInt32Array()
				_cambiadas_ant = PackedInt32Array()
				_foco_forzado = false
		_ps(et, t_e)
		if not todo:
			return
	if todo:
		_actualizar_prov_todas(false, true)                       # modo «todo»: también las líneas de provincia, sin esperas


## Anota qué provincias cambiaron de dueño respecto al último repintado y quién las tenía (se acumulan hasta que se rehace el país enfocado).
func _anotar_cambios_dueno(dueno: PackedInt32Array) -> void:
	var antes := _dueno_ahora
	if antes.size() != dueno.size():
		_foco_forzado = true
		return
	for p in dueno.size():
		if dueno[p] != antes[p]:
			_cambiadas_pend.append(p)
			_cambiadas_ant.append(antes[p])


## ¿Cambió algo que el país enfocado dibuja? Dibuja su silueta, sus provincias y las de sus vecinos por tierra: solo cambia si alguna provincia que
## cambió de dueño era o pasó a ser del país enfocado o de uno de sus vecinos. Antes cualquier conquista del mundo entero rehacía (y deseleccionaba)
## el país enfocado.
func _foco_tocado() -> bool:
	if _cambiadas_pend.is_empty() or not mundo.paises.has(pais_foco):
		return true                                               # sin datos, o el país ya no existe: `_refrescar_foco` decide
	var tid: int = mundo.paises[pais_foco].tid
	var rel: Dictionary = fusion.vecinos_de(_dueno_ahora, tid, VACIO_ID)
	rel[tid] = true
	for j in _cambiadas_pend.size():
		if rel.has(_dueno_ahora[_cambiadas_pend[j]]) or rel.has(_cambiadas_ant[j]):
			return true
	return false


## Dueño que se PINTA en cada provincia: el real, salvo las ocupadas, que llevan un identificador propio (dueño + ocupante) con un color
## mezclado de los dos países (30 % el del dueño, 70 % el del ocupante). Llena `colores` (ID pintado -> Color).
func _dueno_visual(dueno: PackedInt32Array, colores: Dictionary) -> PackedInt32Array:
	var col_oc: PackedInt32Array = mundo.bd.vars["ocupante"].col_i
	var visual := dueno.duplicate()
	for i in dueno.size():
		var o: int = dueno[i]
		var oc: int = col_oc[_ix_prov[i]]
		if oc >= 0 and oc != o and o >= 0 and o < OCUP_MOD and oc < OCUP_MOD:
			var id_v: int = OCUP_BASE + o * OCUP_MOD + oc
			visual[i] = id_v
			if not colores.has(id_v):
				var c_dueno: Color = _color_de_dueno(o)
				var c_ocup: Color = _color_de_dueno(oc)
				# en la vista tradicional los países de un mismo continente comparten color: la mezcla no se vería. Entonces
				# el ocupante usa un tono propio y estable (según su ID) para que la ocupación siempre se distinga.
				var dr := c_dueno.r - c_ocup.r
				var dg := c_dueno.g - c_ocup.g
				var db := c_dueno.b - c_ocup.b
				if sqrt(dr * dr + dg * dg + db * db) < 0.2:
					c_ocup = Color.from_hsv(float((oc * 47) % 360) / 360.0, 0.75, 0.95)
				colores[id_v] = c_dueno.lerp(c_ocup, 0.7)
		elif not colores.has(o):
			colores[o] = _color_de_dueno(o)
	return visual


## Campaña: malla con las líneas de provincia de TODOS los países (pares de provincias del mismo dueño; lo que no existe en la campaña, no).
## 0.1.8.32: solo se rehace si la capa se VE (la malla cuesta ~10 ms y a zoom lejano está apagada); si no, queda anotado y se rehace al acercar.
var _prov_todas_sucia := false

func _reconstruir_provincias_todas(dueno: PackedInt32Array) -> void:
	if capa_prov_todas == null:
		return
	_prov_todas_sucia = false
	if not campana_activa or fusion == null or not fusion.listo:
		for h in capa_prov_todas.get_children():
			capa_prov_todas.remove_child(h)
			h.queue_free()
		return
	var m: ArrayMesh = fusion.malla_aristas(dueno, "internas", VACIO_ID)
	var hijos := capa_prov_todas.get_children()
	if m == null:
		for h in hijos:
			capa_prov_todas.remove_child(h)
			h.queue_free()
		return
	if hijos.size() == 1:
		(hijos[0] as MeshInstance2D).mesh = m                     # se reutiliza el nodo: solo cambia la malla
		return
	for h in hijos:
		capa_prov_todas.remove_child(h)
		h.queue_free()
	var mi := MeshInstance2D.new()
	mi.mesh = m
	mi.material = mat_prov_todas
	capa_prov_todas.add_child(mi)


## Rehace las líneas de provincia de la campaña si quedaron desactualizadas Y la capa está a la vista (o `siempre`).
## A velocidad 3 o más, como mucho una vez cada PROV_TODAS_MIN_MS: son líneas finas y una conquista nueva ocurre varias veces por segundo.
const PROV_TODAS_MIN_MS := 1500
var _t_prov_todas := 0

func _actualizar_prov_todas(siempre := false, sin_espera := false) -> void:
	if not _prov_todas_sucia or capa_prov_todas == null or _dueno_ahora.is_empty():
		return
	if not (siempre or capa_prov_todas.visible):
		return
	var ahora := Time.get_ticks_msec()
	if not (siempre or sin_espera) and reloj != null and reloj.velocidad >= 3 and ahora - _t_prov_todas < PROV_TODAS_MIN_MS:
		return
	_t_prov_todas = ahora
	var t_s := Time.get_ticks_usec()
	_reconstruir_provincias_todas(_dueno_ahora)
	_ps("prov_todas", t_s)


func _reconstruir_fronteras(dueno: PackedInt32Array) -> void:
	_prov_todas_sucia = true                                      # las líneas de provincia se rehacen aparte (ver _actualizar_prov_todas): no en este paso
	var malla: ArrayMesh = fusion.malla_aristas(dueno, "frontera")
	var hijos := capa_frontera.get_children()
	if malla != null and hijos.size() == 3:
		for h in hijos:
			(h as MeshInstance2D).mesh = malla                    # se reutilizan los tres nodos: solo cambia la malla
		return
	for h in hijos:
		capa_frontera.remove_child(h)
		h.queue_free()
	if malla == null:
		return
	for dx in [-ANCHO_MAPA, 0.0, ANCHO_MAPA]:
		var mi := MeshInstance2D.new()
		mi.mesh = malla
		mi.material = mat_frontera
		mi.position = Vector2(dx, 0.0)
		capa_frontera.add_child(mi)


var _prov_caja: Array = []              # por provincia: rectángulo que envuelve todos sus anillos (se calcula una vez)
var _prov_peso := PackedFloat64Array()  # por provincia: suma de las áreas de esos rectángulos; -1 si la provincia no tiene geometría

func _calcular_cajas_provincias(n: int) -> void:
	_prov_caja.resize(n)
	_prov_peso.resize(n)
	for p in n:
		_caja_provincia(p)


func _caja_provincia(p: int) -> void:
	var rect := Rect2()
	var peso := 0.0
	var primero := true
	for ri in mundo.provincias[p].anillos:
		var bb: Array = anillos[int(ri)]["b"]
		var rr := Rect2(float(bb[0]), float(bb[1]), float(bb[2]), float(bb[3]))
		peso += maxf(rr.size.x * rr.size.y, 0.01)
		rect = rr if primero else rect.merge(rr)
		primero = false
	_prov_caja[p] = rect
	_prov_peso[p] = -1.0 if primero else peso


## 0.1.8.35 · Territorio avisa: cambió la forma de las provincias `provs` (sus celdas ya están en las tablas nuevas, ver scripts/territorio.gd).
## Se ponen al día las cajas, el punto de las tropas y el recuento del país enfocado; el relleno, las fronteras y los nombres de país se rehacen
## con el mismo repintado forzado que usan Debug y las pruebas.
func _territorio_cambio(provs: PackedInt32Array) -> void:
	if mundo == null:
		return
	var red = mundo.ejercito.red if mundo.ejercito != null else null
	if _prov_peso.size() != mundo.provincias.size():
		_calcular_cajas_provincias(mundo.provincias.size())           # todavía no existían: salen ya con la forma nueva
	else:
		for p in provs:
			_caja_provincia(int(p))
	for p in provs:
		if red != null and red.listo and int(p) < red.centros.size() and territorio != null:
			var viejo: Vector2 = red.centros[int(p)]
			if not territorio.contiene(int(p), viejo):                # el punto de las tropas sigue dentro de la provincia: no se mueve
				red.actualizar_centro(int(p), territorio.centro_provincia(int(p), viejo))
	bloques_dueno.clear()
	_sincronizar_propiedad(true)


## Bloque contiguo más grande de cada dueño en `ids` (unión de provincias vecinas): {ID de dueño: {"rect": Rect2, "provs": [índices]}}.
## Sirve para colocar el nombre del país y centrar la cámara cuando su territorio ya no es el original (p. ej. España + Francia
## en un solo bloque). Manda el bloque que más provincias ORIGINALES del dueño tiene (su territorio de siempre); si no le queda
## ninguna, el más grande.
func _bloques_de(dueno: PackedInt32Array, ids: Dictionary) -> Dictionary:
	var n := dueno.size()
	var comp: PackedInt32Array = fusion.componentes(dueno, ids)  # 0.1.8.32: por vecindad de provincias, sin recorrer los ~19.500 pares
	if _prov_peso.size() != n:
		_calcular_cajas_provincias(n)
	var caja := {}                                                # componente -> {rect, peso, casa, provs, dueño}
	var orig: PackedInt32Array = fusion.original
	for p in n:
		var r: int = comp[p]
		if r < 0 or _prov_peso[p] < 0.0:
			continue                                              # fuera de `ids`, o provincia sin geometría
		var o: int = dueno[p]
		var rect: Rect2 = _prov_caja[p]
		var peso: float = _prov_peso[p]
		if not caja.has(r):
			caja[r] = {"rect": rect, "peso": 0.0, "casa": 0.0, "provs": [], "dueno": o}
		var c: Dictionary = caja[r]
		c["rect"] = (c["rect"] as Rect2).merge(rect)
		c["peso"] = float(c["peso"]) + peso
		if orig[p] == o:
			c["casa"] = float(c["casa"]) + peso
		(c["provs"] as Array).append(p)
	var mejor := {}
	for r in caja:
		var c2: Dictionary = caja[r]
		var o2: int = c2["dueno"]
		if not mejor.has(o2):
			mejor[o2] = c2
		else:
			var m: Dictionary = mejor[o2]
			if float(c2["casa"]) > float(m["casa"]) or (is_equal_approx(float(c2["casa"]), float(m["casa"])) and float(c2["peso"]) > float(m["peso"])):
				mejor[o2] = c2
	return mejor


## Línea sobre la que se escribe el nombre de un bloque: el eje principal de sus provincias (PCA ponderado por superficie de los
## centros de provincia). Siempre de izquierda a derecha. Si no hay centros (sin datos de vecindad) o es una sola provincia: horizontal.
func _linea_nombre(bloque: Dictionary) -> Array:
	var r: Rect2 = bloque["rect"]
	var c := r.get_center()
	var largo_h := maxf(r.size.x * 0.62, 1.0)
	var horizontal := [c.x - largo_h * 0.5, c.y, c.x + largo_h * 0.5, c.y]
	var provs: Array = bloque["provs"]
	var red = mundo.ejercito.red if mundo.ejercito != null else null
	if red == null or provs.size() < 3:
		return horizontal
	var pesos := []
	var pts := []
	var sw := 0.0
	var mx := 0.0
	var my := 0.0
	for p in provs:
		var q: Vector2 = red.centros[int(p)]
		var bb := _bbox_anillos(mundo.provincias[int(p)].anillos)
		var w := maxf(bb.size.x * bb.size.y, 0.05)
		pts.append(q)
		pesos.append(w)
		sw += w
		mx += q.x * w
		my += q.y * w
	mx /= sw
	my /= sw
	var sxx := 0.0
	var sxy := 0.0
	var syy := 0.0
	for i in pts.size():
		var d: Vector2 = pts[i] - Vector2(mx, my)
		var w2: float = pesos[i]
		sxx += d.x * d.x * w2
		sxy += d.x * d.y * w2
		syy += d.y * d.y * w2
	var ang := 0.5 * atan2(2.0 * sxy, sxx - syy)
	var eje := Vector2(cos(ang), sin(ang))
	if eje.x < 0.0:
		eje = -eje
	var tmin := INF
	var tmax := -INF
	for q2 in pts:
		var t: float = (q2 - Vector2(mx, my)).dot(eje)
		tmin = minf(tmin, t)
		tmax = maxf(tmax, t)
	if tmax - tmin < 1.0:
		return horizontal
	var centro := Vector2(mx, my)
	var a0 := centro + eje * tmin
	var a1 := centro + eje * tmax
	return [a0.x, a0.y, a1.x, a1.y]


var bloques_dueno := {}                                           # nombre de país -> Rect2 del bloque principal (solo países con territorio cambiado)


## Nombres de país: los horneados valen para el territorio ORIGINAL. Los países con territorio distinto (los que absorbieron
## provincias, los que perdieron algunas, los anexados) ocultan su nombre horneado; los que siguen existiendo reciben uno nuevo
## colocado sobre su bloque contiguo más grande.
func _actualizar_etiquetas_dueno(dueno: PackedInt32Array, zoom_aparte := false) -> void:
	var t_e := Time.get_ticks_usec()
	var cambiados := {}                                           # ID de país -> true
	var orig: PackedInt32Array = fusion.original
	for p in dueno.size():
		if dueno[p] != orig[p]:
			if dueno[p] != VACIO_ID:
				cambiados[dueno[p]] = true
			cambiados[orig[p]] = true
	var nombres_cambiados := {}
	for id in cambiados:
		nombres_cambiados[String(mundo.bd.nombre_de(int(id)))] = int(id)
	_ps("et_cambiados", t_e)
	t_e = Time.get_ticks_usec()
	# 1) nombres horneados: ocultos para los países cambiados, visibles para el resto (solo se toca lo que cambió de estado)
	for nombre in etiq_pais:
		var oculto: bool = nombres_cambiados.has(nombre)
		if oculto == _etiq_ocultas.has(nombre):
			continue
		if oculto:
			_etiq_ocultas[nombre] = true
		else:
			_etiq_ocultas.erase(nombre)
		for r in etiq_pais[nombre]:
			var capa: CapaTexto = r[0]
			capa.fijar_visible(int(r[1]), int(r[2]), not oculto)
	_ps("et_ocultar", t_e)
	t_e = Time.get_ticks_usec()
	# 2) nombres nuevos
	for cubo in etiq_dinamicas:
		capas_texto.erase(cubo)
		if is_instance_valid(cubo["padre"]):
			cubo["padre"].queue_free()
	etiq_dinamicas.clear()
	bloques_dueno.clear()
	if cambiados.is_empty():
		if not capas_texto.is_empty():
			_zoom_o_pedirlo(zoom_aparte)
		return
	_ps("et_liberar", t_e)
	t_e = Time.get_ticks_usec()
	var bloques := _bloques_de(dueno, cambiados)
	_ps("et_bloques", t_e)
	t_e = Time.get_ticks_usec()
	var cubos := {}
	for nombre in nombres_cambiados:
		var id: int = nombres_cambiados[nombre]
		if not bloques.has(id) or not mundo.paises.has(nombre):
			continue                                              # sin provincias: ya no hay país que nombrar
		var bl: Dictionary = bloques[id]
		var r: Rect2 = bl["rect"]
		bloques_dueno[nombre] = r
		var col := _color_de_dueno(id)
		var w := r.size.x
		var h := r.size.y
		var lab := {"t": String(mundo.paises[nombre].nombre_visible).to_upper(), "e": clampf(minf(w * 0.062, h * 0.10), 0.9, 12.0),
			"g": "m" if mundo.paises[nombre].provincias.size() > 1 else "p", "lc": 1 if _luminosidad(col) < 0.50 else 0, "pais": nombre, "k": ""}
		lab["p"] = _linea_nombre(bl)
		if w < 4.0 and h < 4.0:
			lab["tiny"] = 1
		_agregar_etiqueta(lab, cubos, capas_texto, self, [-ANCHO_MAPA, 0.0, ANCHO_MAPA])
	for k in cubos:
		etiq_dinamicas.append(cubos[k])
	_ps("et_nuevas", t_e)
	if not capas_texto.is_empty():
		_zoom_o_pedirlo(zoom_aparte)


## Rehace el nivel de detalle de los textos ahora, o (`aparte`) deja pedido que lo haga la etapa «zoom» del siguiente fotograma.
func _zoom_o_pedirlo(aparte: bool) -> void:
	if aparte:
		_zoom_pend = true
	else:
		_actualizar_zoom()


# Vuelve a dibujar el panel abierto (por si el debug cambió datos) y la barra superior.
var _en_refresco := false                 # true mientras `refrescar_todo` vuelve a mandar al HUD lo que ya mostraba (no es una selección nueva)

func refrescar_todo(con_mapa := true) -> void:
	if con_mapa:
		_sincronizar_propiedad(true)
	_actualizar_barra()
	if not hud.esta_abierto():
		return
	_en_refresco = true
	_refrescar_seleccion()
	_en_refresco = false


func _refrescar_seleccion() -> void:
	if not multi_sel.is_empty():
		_multi_dibujar(ultimo_p)                                  # selección múltiple: se vuelve a dibujar todo el grupo
		return
	var pais := String(sel_ref.get("pais", ""))
	var cont := String(sel_ref.get("cont", ""))
	match sel_tipo:
		"pais":
			_limpiar_seleccion()
			if mundo.paises.has(pais) and mundo.paises[pais].provincias.size() > 0:
				_seleccion_pais(pais, cont, ultimo_p)
			else:
				hud.ocultar()
		"provincia":
			var pi := int(sel_ref["pi"])
			_limpiar_seleccion()
			_seleccion_provincia(pi, mundo.continente_de_provincia(pi), ultimo_p)
		"estado":
			var est := String(sel_ref.get("estado", ""))
			_limpiar_seleccion()
			_seleccion_estado(pais, est, ultimo_p)


# ─────────────────────────────────────────────────────────────
# API para el menú Debug
# ─────────────────────────────────────────────────────────────
func debug_controlar(pais: String) -> void:
	mundo.fijar_jugador(pais)
	refrescar_todo()


func debug_anexar(origen: String, destino: String) -> int:
	var n: int = mundo.anexar_pais(origen, destino, reloj.texto(), "Anexión (debug)")
	refrescar_todo()
	return n


func debug_transferir(pi: int, destino: String) -> bool:
	var ok: bool = mundo.transferir_provincia(pi, destino, reloj.texto(), "Transferencia (debug)")
	refrescar_todo()
	return ok


func debug_avanzar_dias(n: int) -> void:
	for _i in n:
		reloj.sumar_dia()
	_actualizar_barra()


func debug_fijar_fecha(a: int, m: int, d: int) -> void:
	reloj.fijar(a, m, d)
	mundo.bd.fecha = BDScript.fecha_int(reloj.anio, reloj.mes, reloj.dia)
	if mundo.descubrimientos != null:
		mundo.descubrimientos.sincronizar(reloj.anio, true)               # 0.1.8.36: saltar de fecha = todos los países reciben la historia de ese año
	_actualizar_barra()


func debug_dar_dinero(pais: String, cantidad: float) -> void:
	if mundo.paises.has(pais):
		mundo.paises[pais].tesoreria = maxf(mundo.paises[pais].tesoreria + cantidad, 0.0)
	_actualizar_barra()


func debug_provincia_seleccionada() -> int:
	if sel_tipo == "provincia" and sel_ref.has("pi"):
		return int(sel_ref["pi"])
	if sel_tipo == "ciudad" and sel_ref.has("id"):
		return int(mundo.ciudades[int(sel_ref["id"])].provincia)
	return -1


## Overlay Debug: se abre/cierra con el botón del bicho o F1, sin pausar el juego ni tapar el mapa.
func _alternar_debug() -> void:
	if debug_menu != null and is_instance_valid(debug_menu):
		_cerrar_debug()
	else:
		_abrir_debug()


## País seleccionado en el mapa ("" si lo seleccionado no es un país/estado/provincia/ciudad de algún país).
func debug_pais_seleccionado() -> String:
	var p := String(sel_ref.get("pais", ""))
	if sel_tipo == "ciudad" and sel_ref.has("id"):
		p = String(mundo.ciudades[int(sel_ref["id"])].pais)
	return p if mundo != null and mundo.paises.has(p) else ""


## ID único (base de datos) de lo seleccionado en el mapa; -1 si no hay nada.
func debug_tid_seleccionado() -> int:
	if mundo == null:
		return -1
	match sel_tipo:
		"provincia":
			return mundo.provincias[int(sel_ref["pi"])].tid
		"ciudad":
			return mundo.ciudades[int(sel_ref["id"])].tid
		"pais":
			return mundo.paises[String(sel_ref["pais"])].tid if mundo.paises.has(String(sel_ref.get("pais", ""))) else -1
		"estado":
			var k := "%s|%s" % [String(sel_ref.get("pais", "")), String(sel_ref.get("estado", ""))]
			return mundo.estados[k].tid if mundo.estados.has(k) else -1
		"continente":
			var c = mundo.continentes.get(String(sel_ref.get("cont", "")))
			return c.tid if c != null else -1
	return -1


func _abrir_debug() -> void:
	if mundo == null or en_menu:
		return
	if debug_menu != null and is_instance_valid(debug_menu):
		return
	debug_menu = DebugScript.new()
	add_child(debug_menu)
	debug_menu.construir(self, fuente_ui)
	debug_menu.cerrado.connect(_cerrar_debug)


func _cerrar_debug() -> void:
	if debug_menu != null and is_instance_valid(debug_menu):
		debug_menu.queue_free()
	debug_menu = null


## Ventana «Mi país»: personalización del país que controlas (nombre, moneda, impuestos, desarrollo) en cualquier momento.
func _abrir_personalizar() -> void:
	if mundo == null or en_menu:
		return
	if mundo.jugador == "":
		hud.set_hint("Aún no controlas ningún país: elígelo en Debug (bicho de arriba a la izquierda o F1)")
		return
	if panel_pers != null and is_instance_valid(panel_pers):
		_cerrar_personalizar()
		return
	panel_pers = PersonalizarScript.new()
	add_child(panel_pers)
	panel_pers.construir(self, fuente_ui)
	panel_pers.cerrada.connect(_cerrar_personalizar)


func _cerrar_personalizar() -> void:
	if panel_pers != null and is_instance_valid(panel_pers):
		panel_pers.queue_free()
	panel_pers = null


## Clic en la bandera/nombre del país que controlas: se enfoca y se abre su información (como pulsarlo en el mapa).
func _on_jugador_pedido() -> void:
	if not _jugador_valido():
		return
	_ir_a_pais(mundo.jugador)
	hud.abrir_pestana("general")


## Clic en el dinero: lo mismo, pero abriendo directamente la pestaña Economía.
func _on_dinero_pedido() -> void:
	if not _jugador_valido():
		return
	_ir_a_pais(mundo.jugador)
	hud.abrir_pestana("economia")


func _jugador_valido() -> bool:
	if mundo == null or mundo.jugador == "" or not mundo.paises.has(mundo.jugador):
		hud.set_hint("Aún no controlas ningún país: elígelo en Debug (bicho de arriba a la izquierda o F1)")
		return false
	return true


func _ir_a_pais(pais: String) -> void:
	_limpiar_seleccion()
	var e = mundo.paises[pais]
	ultimo_p = _bbox_foco(pais).get_center() if e.provincias.size() > 0 else ultimo_p
	if e.provincias.size() > 0:
		_enfocar_pais(pais, true)
	_seleccion_pais(pais, e.continente, ultimo_p)


## Si hay un país abierto en la pestaña Economía, pone al día sus cifras mientras pasan los días.
func _refrescar_fin_panel() -> void:
	if hud == null or mundo == null or not hud.esta_abierto() or hud.pestana != "economia" or sel_tipo != "pais":
		return
	var pais := String(sel_ref.get("pais", ""))
	if mundo.paises.has(pais):
		hud.actualizar_fin(_fin_pais(pais), _fin_detalles(pais))


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
	centro.theme = TemaHud.crear_tema(fuente_ui, fuente_ui_neg)
	menu_pausa.add_child(centro)

	var panel_pausa := PanelContainer.new()
	panel_pausa.add_theme_stylebox_override("panel", TemaHud.panel(26.0))
	centro.add_child(panel_pausa)
	# 0.1.8.33: la pausa usa el mismo panel y los mismos botones que el menú principal (así OPCIONES es la misma pantalla en los dos sitios)
	panel_menu_nodo = panel_pausa
	menu_contenido = VBoxContainer.new()
	menu_contenido.add_theme_constant_override("separation", 14)
	panel_pausa.add_child(menu_contenido)
	_mostrar_pausa_principal()


## Primera pantalla de la pausa: CONTINUAR · OPCIONES · DEBUG · MENÚ PRINCIPAL · SALIR.
func _mostrar_pausa_principal() -> void:
	_limpiar_menu()
	panel_menu_nodo.custom_minimum_size = Vector2(390.0, 390.0)
	_titulo_menu("JUEGO EN PAUSA")
	_boton_menu("CONTINUAR", _reanudar_juego)
	_boton_menu("OPCIONES", _mostrar_opciones)
	_boton_menu("DEBUG", func():
		_reanudar_juego()
		_abrir_debug())
	_boton_menu("MENÚ PRINCIPAL", _volver_menu_principal)
	_boton_menu("SALIR", _salir_juego)


func _reanudar_juego() -> void:
	get_tree().paused = false
	en_pausa = false
	if is_instance_valid(menu_pausa):
		menu_pausa.queue_free()
	menu_pausa = null
	hud.set_visible_todo(true)
	_actualizar_zoom()


# ─────────────────────────────────────────────────────────────
# Tropas sobre el mapa y órdenes (0.1.7.9.9E)
# ─────────────────────────────────────────────────────────────
func _crear_capa_tropas() -> void:
	if mundo == null or mundo.ejercito == null:
		return
	capa_tropas = CapaTropasScript.new()
	add_child(capa_tropas)
	capa_tropas.iniciar(self, fuente_ciudad)


## Muestra el manejo de tropas de una provincia: el HUD de país en Militar > Regimientos (ya no hay ventana flotante).
## `pais_tid` = -1: las tropas del dueño de la provincia. `reg` ≥ 0: deja ese regimiento elegido.
func abrir_ordenes(prov_tid: int, pais_tid := -1, reg := -1) -> void:
	if mundo == null or mundo.ejercito == null or en_menu or hud == null:
		return
	var pr = mundo.ejercito.provincia_por_tid(prov_tid)
	if pr == null:
		return
	if not hud.esta_abierto() or not hud.tiene_ctx():       # no hay un país abierto: se abre el país de esas tropas en el HUD
		var pais_hud: String = String(pr.pais)
		if pais_tid >= 0:
			pais_hud = mundo.bd.nombre_de(pais_tid)
		if mundo.paises.has(pais_hud):
			_limpiar_seleccion()
			_seleccion_pais(pais_hud, String(mundo.paises[pais_hud].continente), ultimo_p)
	hud.abrir_militar("reg")
	hud.tropas.mostrar(prov_tid, pais_tid, reg)


## Suelta lo que estaba elegido en el mapa (regimientos, destino a medias). Lo llama el HUD al cerrarse.
func _soltar_seleccion_tropas() -> void:
	cancelar_destino()
	if hud != null and hud.tropas != null:
		hud.tropas.limpiar_seleccion()
	if capa_tropas != null:
		capa_tropas.sel = {}
		capa_tropas.sel_regs = []
		capa_tropas.refrescar()


func _cerrar_ordenes() -> void:
	_soltar_seleccion_tropas()


## Tras elegir una provincia con un clic: el HUD ya la muestra (con su pestaña Militar si estaba abierta), no hace falta nada más.
func _tras_elegir_provincia(_pi: int) -> void:
	pass


func _ctrl_pulsado() -> bool:
	return Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)


## Clic sobre un cuadrito de tropas. Devuelve true si había uno (el clic no sigue al mapa).
## Ctrl+clic en un cuadro de regimiento lo añade a la selección o lo quita (como en el explorador de archivos).
func _clic_tropas(pos: Vector2) -> bool:
	if capa_tropas == null or not capa_tropas.visible:
		return false
	var mk: Dictionary = capa_tropas.marcador_en(pos)
	if mk.is_empty():
		return false
	var tipo := String(mk.get("t", ""))
	var ctrl := _ctrl_pulsado()
	if tipo == "reg":
		if ctrl and _panel_regimientos_abierto():
			hud.tropas.alternar_reg(int(mk["reg"]), true)
		else:
			abrir_ordenes(int(mk["prov"]), int(mk["pais"]), int(mk["reg"]))
	elif tipo == "mas":
		abrir_ordenes(int(mk["prov"]), int(mk["pais"]))
	elif tipo == "marcha":
		var m: Dictionary = mundo.ejercito.marchas.get(int(mk["id"]), {})
		if not m.is_empty():
			if ctrl and _panel_regimientos_abierto() and int(m.get("reg", -1)) >= 0:
				hud.tropas.alternar_reg(int(m["reg"]), true)
			else:
				var ruta: PackedInt32Array = m["ruta"]
				abrir_ordenes(int(mundo.provincias[ruta[int(m["k"])]].tid), int(m["pais"]), int(m.get("reg", -1)))
	return true


## ¿El HUD está abierto en Militar > Regimientos (con tropas que manejar)?
func _panel_regimientos_abierto() -> bool:
	return hud != null and hud.esta_abierto() and hud.tiene_ctx() and hud.pestana == "militar" and hud.sub_militar == "reg" and hud.tropas != null and hud.tropas.activo


## El jugador pulsó «Mover…»: desde ahora el próximo clic en el mapa elige el destino.
func iniciar_destino(reg: int, n: int) -> void:
	if capa_tropas == null or mundo.ejercito == null or not mundo.ejercito.existe_reg(reg):
		return
	orden_mover = {"reg": reg, "n": n}
	capa_tropas.empezar_destino(mundo.ejercito.prov_de(reg), reg)
	_destino_bajo_cursor()
	_actualizar_hint()


## Lo mismo para VARIOS regimientos elegidos con Ctrl+clic: el próximo clic elige el destino de todos.
func iniciar_destino_grupo(grupo: Array) -> void:
	if capa_tropas == null or mundo.ejercito == null:
		return
	var ej = mundo.ejercito
	var primero := -1
	for rid in grupo:
		if ej.existe_reg(int(rid)) and not ej.en_marcha_reg(int(rid)):
			primero = int(rid)
			break
	if primero < 0:
		return
	orden_mover = {"reg": primero, "n": 0, "grupo": grupo.duplicate()}
	capa_tropas.empezar_destino(ej.prov_de(primero), primero)
	_destino_bajo_cursor()
	_actualizar_hint()


func cancelar_destino() -> void:
	if orden_mover.is_empty():
		return
	orden_mover = {}
	if capa_tropas != null:
		capa_tropas.terminar_destino()
	_actualizar_hint()


## Índice de provincia bajo una posición del mapa, o -1 si es mar.
func provincia_en(pos: Vector2) -> int:
	var r := _anillo_bajo(pos)
	if int(r[0]) < 0:
		return -1
	return int(anillos[int(r[0])]["p"])


func _destino_bajo_cursor() -> void:
	if capa_tropas != null and not orden_mover.is_empty():
		capa_tropas.poner_destino(provincia_en(get_global_mouse_position()))


func _clic_destino(pos: Vector2) -> void:
	var pi := provincia_en(pos)
	if pi < 0:
		hud.set_hint("Eso es mar" + (" o está fuera de la campaña" if campana_activa else "") + ": elige una provincia de tierra (Esc cancela)")
		return
	var res: Dictionary
	var pais_orden := -1
	if orden_mover.has("grupo"):
		for rid_g in orden_mover["grupo"]:
			pais_orden = mundo.ejercito.pais_de_reg(int(rid_g))
			break
	else:
		pais_orden = mundo.ejercito.pais_de_reg(int(orden_mover["reg"]))
	var aviso_g := _aviso_sin_guerra(pais_orden, pi)
	if aviso_g != "":
		hud.set_hint(aviso_g + " · elige otra provincia o pulsa Esc")
		return
	if orden_mover.has("grupo"):
		res = _ordenar_grupo(orden_mover["grupo"], pi)
	else:
		res = mundo.ejercito.ordenar_marcha_reg(int(orden_mover["reg"]), int(orden_mover["n"]), pi)
	if bool(res.get("ok", false)):
		cancelar_destino()
		_orden_dada(res)
	else:
		hud.set_hint(String(res.get("msg", "")) + " · elige otra provincia o pulsa Esc")
		if panel_ordenes != null:
			panel_ordenes.resultado_orden(res)


## Manda varios regimientos (enteros) a la provincia `pi`. Devuelve {"ok" (salió al menos uno), "msg", "marcha", "reg", "grupo": true}.
func _ordenar_grupo(grupo: Array, pi: int) -> Dictionary:
	var ej = mundo.ejercito
	var salieron := 0
	var error := ""
	var guerra_con := -1
	var ultima := {}
	for rid in grupo:
		if not ej.existe_reg(int(rid)) or ej.en_marcha_reg(int(rid)):
			continue
		var pr_r = ej.provincia_por_tid(ej.prov_de(int(rid)))
		if pr_r != null and int(pr_r.idx) == pi:      # ya está en el destino: no hace falta moverlo
			continue
		var r: Dictionary = ej.ordenar_marcha_reg(int(rid), 0, pi)
		if bool(r.get("ok", false)):
			salieron += 1
			ultima = r
			if int(r.get("contra", -1)) >= 0:
				guerra_con = int(r["contra"])
		elif error == "":
			error = String(r.get("msg", ""))
	if salieron == 0:
		return {"ok": false, "msg": error if error != "" else "Ninguno de los regimientos elegidos puede salir."}
	var dest = mundo.provincias[pi]
	var msg := "%d regimientos en marcha hacia %s." % [salieron, dest.nombre] if salieron > 1 else String(ultima["msg"])
	if guerra_con >= 0 and salieron > 1:
		msg = "¡GUERRA con %s! %s" % [mundo.bd.nombre_de(guerra_con), msg]
	if error != "":
		msg += " (%d no salieron: %s)" % [grupo.size() - salieron, error]
	return {"ok": true, "msg": msg, "marcha": int(ultima["marcha"]), "reg": int(ultima["reg"]), "grupo": true}


## Una orden de marcha salió bien: se elige la columna nueva, se avisa y se actualiza el panel.
func _orden_dada(res: Dictionary) -> void:
	if not bool(res.get("grupo", false)):
		capa_tropas.sel = {"t": "marcha", "id": int(res["marcha"])}
	capa_tropas.refrescar()
	hud.set_hint(String(res["msg"]))
	hud.refrescar_ejercito()
	_actualizar_barra()
	if panel_ordenes != null:
		panel_ordenes.resultado_orden(res)


## CLIC DERECHO (sin arrastrar) con tropas tuyas seleccionadas: las manda a la provincia que está bajo el cursor, sin pasar por el panel.
func _clic_derecho(pos: Vector2) -> void:
	if capa_tropas == null or mundo == null or mundo.ejercito == null or not orden_mover.is_empty():
		return
	if panel_ordenes != null and panel_ordenes.es_multiple():
		_mandar_grupo(panel_ordenes.grupo(), provincia_en(pos))
		return
	var s: Dictionary = capa_tropas.sel
	var rid := -1
	if String(s.get("t", "")) == "reg":
		rid = int(s["reg"])
	if rid < 0:
		return                                        # sin un regimiento seleccionado el clic derecho no hace nada
	_mandar_tropas(rid, provincia_en(pos))


## ¿Puede el jugador dar órdenes a las tropas de ese país?
func _es_mio(pais_tid: int) -> bool:
	var jug: String = mundo.jugador
	return jug == "" or (mundo.paises.has(jug) and int(mundo.paises[jug].tid) == pais_tid)


## Manda VARIOS regimientos (selección múltiple) a la provincia `pi`.
func _mandar_grupo(grupo: Array, pi: int) -> void:
	var ej = mundo.ejercito
	if grupo.is_empty():
		return
	if not _es_mio(ej.pais_de_reg(int(grupo[0]))):
		hud.set_hint("Esas tropas no son tuyas: solo puedes mirarlas")
		return
	if pi < 0:
		hud.set_hint("Eso es mar: suéltalas (o haz clic derecho) sobre una provincia de tierra")
		return
	var res: Dictionary = _ordenar_grupo(grupo, pi)
	if bool(res.get("ok", false)):
		_orden_dada(res)
	else:
		hud.set_hint(String(res.get("msg", "")))
		if panel_ordenes != null:
			panel_ordenes.resultado_orden(res)


## Manda el regimiento `rid` a la provincia `pi`. Cuántos soldados: los que haya puesto en el panel de tropas si está abierto para ese regimiento;
## si no, todo el regimiento. Lo usan el clic derecho y el arrastre del cuadro.
func _mandar_tropas(rid: int, pi: int) -> void:
	var ej = mundo.ejercito
	if not ej.existe_reg(rid):
		return
	var pais_tid: int = ej.pais_de_reg(rid)
	if not _es_mio(pais_tid):
		hud.set_hint("Esas tropas no son tuyas: solo puedes mirarlas")
		return
	if ej.en_marcha_reg(rid):
		hud.set_hint("Ese regimiento ya va en marcha")
		return
	if pi < 0:
		hud.set_hint("Eso es mar: suéltalas (o haz clic derecho) sobre una provincia de tierra")
		return
	var origen = ej.provincia_por_tid(ej.prov_de(rid))
	if origen != null and int(origen.idx) == pi:
		hud.set_hint("Esas tropas ya están en esa provincia")
		return
	var aviso_g := _aviso_sin_guerra(pais_tid, pi)
	if aviso_g != "":
		hud.set_hint(aviso_g)
		return
	var n := 0
	if panel_ordenes != null and panel_ordenes.activo and panel_ordenes.sel_reg == rid:
		n = panel_ordenes.n_mover()
	var res: Dictionary = ej.ordenar_marcha_reg(rid, n, pi)
	if bool(res.get("ok", false)):
		_orden_dada(res)
	else:
		hud.set_hint(String(res.get("msg", "")))
		if panel_ordenes != null:
			panel_ordenes.resultado_orden(res)


# ── ARRASTRAR el cuadrito de tropas con el botón izquierdo hasta la provincia de destino ──
## Al pulsar sobre un cuadrito de pila TUYO (ya quedó elegido) se prepara un posible arrastre; empieza de verdad al moverse más de 8 px.
func _posible_drag_tropas(pos: Vector2, px: Vector2) -> void:
	var mk: Dictionary = capa_tropas.marcador_en(pos)
	if String(mk.get("t", "")) != "reg":
		return
	var jug: String = mundo.jugador
	if jug != "" and (not mundo.paises.has(jug) or int(mundo.paises[jug].tid) != int(mk["pais"])):
		return                                        # las ajenas se miran, no se arrastran
	_drag_tropas = {"reg": int(mk["reg"]), "prov": int(mk["prov"]), "pais": int(mk["pais"]), "px0": px, "activo": false, "sold": int(mk["sold"]), "t": 0}


func _mover_drag_tropas(px: Vector2) -> void:
	if not bool(_drag_tropas["activo"]):
		if px.distance_to(_drag_tropas["px0"]) < 14.0:
			return
		_drag_tropas["activo"] = true
		capa_tropas.empezar_destino(int(_drag_tropas["prov"]), int(_drag_tropas["reg"]))
	var pos := get_global_mouse_position()
	var nombre := ""
	for k in mundo.paises:
		if int(mundo.paises[k].tid) == int(_drag_tropas["pais"]):
			nombre = String(k)
			break
	capa_tropas.poner_fantasma(pos, str(int(_drag_tropas["sold"])), nombre)
	var ahora := Time.get_ticks_msec()
	if ahora - int(_drag_tropas["t"]) >= 40:          # la ruta de vista previa se recalcula como mucho 25 veces por segundo
		_drag_tropas["t"] = ahora
		capa_tropas.poner_destino(provincia_en(pos))


func _soltar_drag_tropas() -> void:
	var d: Dictionary = _drag_tropas
	_drag_tropas = {}
	if not bool(d["activo"]):
		return                                        # fue un clic normal: ya quedó elegido
	var pi := provincia_en(get_global_mouse_position())
	capa_tropas.quitar_fantasma()
	capa_tropas.terminar_destino()
	var pr_o = mundo.ejercito.provincia_por_tid(int(d["prov"]))
	if pr_o != null and int(pr_o.idx) == pi:         # 0.1.8.2a: soltar en la misma provincia de salida = no hacer nada (antes mandaba el resto del grupo ahí)
		hud.set_hint("Soltaste en la misma provincia: no se movió nada")
		return
	if panel_ordenes != null and panel_ordenes.es_multiple() and panel_ordenes.sel_multi.has(int(d["reg"])):
		_mandar_grupo(panel_ordenes.grupo(), pi)             # el cuadro arrastrado era parte de la selección múltiple: va todo el grupo
	else:
		_mandar_tropas(int(d["reg"]), pi)


func _cancelar_drag_tropas() -> void:
	var activo := bool(_drag_tropas.get("activo", false))
	_drag_tropas = {}
	if activo and capa_tropas != null:
		capa_tropas.quitar_fantasma()
		capa_tropas.terminar_destino()
		hud.set_hint("Movimiento cancelado")


func _volver_menu_principal() -> void:
	if popup_guerra != null and popup_guerra.abierto:
		popup_guerra.cerrar("menu")
	_cerrar_ranking()
	_cerrar_debug()
	_cerrar_personalizar()
	_cerrar_ordenes()
	get_tree().paused = false
	en_pausa = false
	if is_instance_valid(menu_pausa):
		menu_pausa.queue_free()
	menu_pausa = null
	_limpiar_seleccion()
	sel_tipo = ""
	sel_ref = {}
	_ocultar_paneles()
	hud.set_visible_todo(false)
	en_menu = true
	_crear_menu()
	_actualizar_zoom()


func _salir_juego() -> void:
	get_tree().quit()
