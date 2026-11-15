extends Control
## FONDO AMBIENTAL de la pantalla de Descubrimientos. Desde la 0.1.8.44 es ESPACIO NEGRO ANIMADO con el color de la rama fundido en la nebulosa (Camilo: «el fondo muy como
## el espacio, NEGRO, pero con la fusión del color de la rama»): nubes de nebulosa, tres capas de estrellas que parpadean y derivan, estrellas fugaces, el resplandor del sol
## (la raíz del árbol) y, solo en Militar, brasas que suben. NO hay planetas de fondo: los únicos planetas son los descubrimientos. Cada rama tiene su acento y cada sección su tono:
##  · Militar: rojo y brasas · Científica: azul hielo · Sociedad: violeta y oro viejo.
## TODO lo anima el shader (`shaders/fondo_espacial.gdshader`, con TIME): el script solo le pasa los colores al cambiar de rama, de sección o de tamaño, y la posición del sol
## cuando el árbol se mueve; nunca redibuja por fotograma. Con calidad Baja (`animado = false`) el cielo queda quieto y barato.

const SHADER_FONDO := preload("res://shaders/fondo_espacial.gdshader")

## Por rama: [color de arriba, color de abajo, acento]. Arriba y abajo son casi NEGROS (un soplo del color); el acento es lo que tiñe la nebulosa.
const PALETAS := [
	[Color(0.026, 0.006, 0.008), Color(0.003, 0.002, 0.003), Color(1.0, 0.36, 0.22)],
	[Color(0.005, 0.016, 0.030), Color(0.001, 0.003, 0.007), Color(0.32, 0.80, 1.0)],
	[Color(0.020, 0.009, 0.030), Color(0.004, 0.003, 0.008), Color(0.86, 0.60, 1.0)],
]

const LADO_NEBULOSA := 256                # lado (px) de la textura de ruido de la nebulosa

static var _nebulosa: ImageTexture        # una sola para todo el programa: se hace la primera vez que se abre la pantalla (cuesta unos 10 ms)

var rama := 0
var seccion := 0                         # posición de la sección dentro de su rama (cambia el tono y la semilla del cielo)
var animado := true:                     # false = cielo quieto (calidad Baja)
	set(v):
		animado = v
		_poner_uniforms()
var _mat: ShaderMaterial
var _sol := Vector2(-1.0, -1.0)           # dónde está el sol (la raíz del árbol); (−1, −1) = sin árbol a la vista: centrado y un poco por debajo de la pantalla
var redibujos := 0                       # (pruebas) cuántas veces se redibujó: debe ser UNA por cambio de tamaño, nunca una por fotograma


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_FONDO
	_mat.set_shader_parameter("tex_neb", _textura_nebulosa())
	material = _mat


## Ruido fractal repetible (FBM de FastNoiseLite) para la nebulosa del shader. Se hace una vez y se comparte.
static func _textura_nebulosa() -> ImageTexture:
	if _nebulosa == null:
		var ruido := FastNoiseLite.new()
		ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		ruido.fractal_type = FastNoiseLite.FRACTAL_FBM
		ruido.fractal_octaves = 4
		ruido.frequency = 0.016
		ruido.seed = 4417
		_nebulosa = ImageTexture.create_from_image(ruido.get_seamless_image(LADO_NEBULOSA, LADO_NEBULOSA, false, false, 0.15, true))
	return _nebulosa


func fijar(r: int, s: int) -> void:
	rama = clampi(r, 0, PALETAS.size() - 1)
	seccion = maxi(s, 0)
	_poner_uniforms()
	queue_redraw()


## Color de la rama con el tono corrido según la sección (cada sección se ve algo distinta, sin dejar de ser de su rama).
func tono(c: Color, k: int) -> Color:
	return Color.from_hsv(fposmod(c.h + float(k % 9 - 4) * 0.011, 1.0), c.s, c.v, c.a)


func acento() -> Color:
	return tono(PALETAS[rama][2], seccion)


## Pasa al shader la paleta de la rama y de la sección, la semilla del cielo y si se anima.
## Dónde está el sol (la raíz del árbol) en coordenadas de este control: el shader lo usa para el resplandor.
func poner_sol(p: Vector2) -> void:
	_sol = p
	if _mat != null:
		_mat.set_shader_parameter("u_sol", p if p.x > -0.5 else Vector2(size.x * 0.5, size.y * 1.05))


func _poner_uniforms() -> void:
	if _mat == null:
		return
	var pal: Array = PALETAS[rama]
	_mat.set_shader_parameter("c_top", tono(pal[0], seccion))
	_mat.set_shader_parameter("c_bot", tono(pal[1], seccion))
	_mat.set_shader_parameter("c_acc", acento())
	_mat.set_shader_parameter("u_rama", float(rama))
	_mat.set_shader_parameter("u_seed", float(1 + rama * 7 + seccion * 3 % 29))
	_mat.set_shader_parameter("u_anim", 1.0 if animado else 0.0)
	_mat.set_shader_parameter("u_size", size)
	_mat.set_shader_parameter("u_sol", _sol if _sol.x > -0.5 else Vector2(size.x * 0.5, size.y * 1.05))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_poner_uniforms()
		queue_redraw()


func _draw() -> void:
	redibujos += 1
	if size.x < 4.0 or size.y < 4.0:
		return
	_mat.set_shader_parameter("u_size", size)
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)       # un solo rectángulo: el shader pinta el cielo
