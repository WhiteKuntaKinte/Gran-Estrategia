extends Control
## FONDO AMBIENTAL de la pantalla de Descubrimientos (0.1.8.43): cada rama tiene su propio mundo y cada sección su propio tono.
##  · Militar: fragua oscura, de rojos y brasas, con tajos diagonales y chispas que suben.
##  · Científica: noche azul con constelaciones (estrellas unidas por hilos finos).
##  · Sociedad: violeta y oro viejo con ondas concéntricas que nacen abajo, como una ciudad vista desde el aire.
## Se dibuja UNA vez por cambio de rama, de sección o de tamaño (todo en una malla): no cuesta nada mientras se mueve el árbol.

const LoteScript := preload("res://scripts/lote_dibujo.gd")

## Por rama: [color de arriba, color de abajo, acento]
const PALETAS := [
	[Color(0.23, 0.06, 0.07), Color(0.045, 0.025, 0.035), Color(1.0, 0.42, 0.24)],
	[Color(0.03, 0.14, 0.22), Color(0.01, 0.035, 0.085), Color(0.35, 0.88, 0.98)],
	[Color(0.19, 0.10, 0.24), Color(0.05, 0.03, 0.08), Color(1.0, 0.78, 0.38)],
]

var rama := 0
var seccion := 0                         # posición de la sección dentro de su rama (cambia el tono y el dibujo del patrón)
var _lote := LoteScript.new()


func fijar(r: int, s: int) -> void:
	rama = clampi(r, 0, PALETAS.size() - 1)
	seccion = maxi(s, 0)
	queue_redraw()


## Color de la rama con el tono corrido según la sección (cada sección se ve algo distinta, sin dejar de ser de su rama).
func tono(c: Color, k: int) -> Color:
	return Color.from_hsv(fposmod(c.h + float(k % 9 - 4) * 0.011, 1.0), c.s, c.v, c.a)


func acento() -> Color:
	return tono(PALETAS[rama][2], seccion)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var pal: Array = PALETAS[rama]
	var arriba := tono(pal[0], seccion)
	var abajo := tono(pal[1], seccion)
	var ac := acento()
	_lote.limpiar()
	_lote.base(Vector2.ZERO, 1.0)
	_lote.degradado_v(Rect2(Vector2.ZERO, size), arriba, abajo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (rama + 1) + 104729 * seccion
	match rama:
		0:
			_fragua(rng, ac)
		1:
			_constelaciones(rng, ac)
		_:
			_ondas(rng, ac)
	# viñeta: los bordes se oscurecen
	var v := Color(0.0, 0.0, 0.0, 0.55)
	var t := Color(0.0, 0.0, 0.0, 0.0)
	var m := minf(size.x, size.y) * 0.22
	_lote.degradado_v(Rect2(0.0, 0.0, size.x, m), v, t)
	_lote.degradado_v(Rect2(0.0, size.y - m, size.x, m), t, v)
	_lote.degradado_h(Rect2(0.0, 0.0, m, size.y), v, t)
	_lote.degradado_h(Rect2(size.x - m, 0.0, m, size.y), t, v)
	_lote.emitir(self)


func _fragua(rng: RandomNumberGenerator, ac: Color) -> void:
	for k in 26:                                           # tajos diagonales muy tenues
		var x := rng.randf_range(-0.1, 1.1) * size.x
		var y := rng.randf_range(0.0, 1.0) * size.y
		var largo := rng.randf_range(0.18, 0.5) * size.y
		var a := Vector2(x, y)
		var b := a + Vector2(largo * 0.55, -largo)
		_lote.linea(a, b, rng.randf_range(1.0, 3.0), Color(ac.r, ac.g, ac.b, rng.randf_range(0.015, 0.05)))
	for k in 90:                                           # brasas: más densas abajo
		var u := rng.randf()
		var y2 := size.y * (1.0 - u * u)
		var x2 := rng.randf() * size.x
		var r := rng.randf_range(0.8, 2.4)
		_lote.disco(Vector2(x2, y2), r, Color(ac.r, ac.g * 0.9, ac.b * 0.6, rng.randf_range(0.10, 0.5) * (0.4 + 0.6 * (y2 / size.y))), 6)
	_lote.disco_radial(Vector2(size.x * 0.5, size.y * 1.02), size.x * 0.55, Color(ac.r, ac.g, ac.b, 0.14), Color(ac.r, ac.g, ac.b, 0.0), 28)


func _constelaciones(rng: RandomNumberGenerator, ac: Color) -> void:
	var estrellas := PackedVector2Array()
	for k in 150:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		estrellas.append(p)
		var r := rng.randf_range(0.7, 2.1)
		_lote.disco(p, r, Color(0.85, 0.95, 1.0, rng.randf_range(0.10, 0.55)), 6)
	for k in 36:                                           # hilos entre estrellas cercanas
		var a := estrellas[rng.randi() % estrellas.size()]
		var mejor := Vector2.ZERO
		var mejor_d := 1.0e9
		for q in estrellas:
			var dd := a.distance_to(q)
			if dd > 20.0 and dd < mejor_d and dd < 170.0:
				mejor = q
				mejor_d = dd
		if mejor_d < 1.0e8:
			_lote.linea(a, mejor, 1.0, Color(ac.r, ac.g, ac.b, 0.12))
	_lote.disco_radial(Vector2(size.x * 0.3, size.y * 0.2), size.x * 0.4, Color(ac.r, ac.g, ac.b, 0.07), Color(ac.r, ac.g, ac.b, 0.0), 28)


func _ondas(rng: RandomNumberGenerator, ac: Color) -> void:
	var c := Vector2(size.x * rng.randf_range(0.35, 0.65), size.y * 1.15)
	for k in 14:
		var r := (80.0 + float(k) * 95.0)
		_lote.anillo(c, r, 1.4 + float(k % 3), Color(ac.r, ac.g, ac.b, 0.05 + 0.02 * float(k % 2)), 72)
	for k in 70:                                           # puntitos de luz: casas y faroles
		var p := Vector2(rng.randf() * size.x, size.y * (0.35 + 0.65 * rng.randf()))
		_lote.disco(p, rng.randf_range(0.8, 1.9), Color(ac.r, ac.g, ac.b, rng.randf_range(0.08, 0.4)), 6)
	_lote.disco_radial(Vector2(size.x * 0.5, size.y * 1.05), size.x * 0.5, Color(ac.r, ac.g, ac.b, 0.10), Color(ac.r, ac.g, ac.b, 0.0), 28)
