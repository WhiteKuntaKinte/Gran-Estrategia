extends RefCounted
## DIBUJO POR LOTES (0.1.8.43): acumula rectángulos, marcos, líneas, triángulos y discos en UNA malla de triángulos con color por vértice
## y la manda al motor como UNA sola orden de dibujo (`RenderingServer.canvas_item_add_triangle_array`).
## Motivo: cada `draw_rect`, `draw_line`, `draw_circle`… son órdenes distintas y de tipos distintos, y el motor no las puede fundir entre sí:
## con IA activas los cuadros de tropas llegaban a ~1.200 llamadas de dibujo por fotograma. En lote, todo lo que es forma plana de un
## mismo «pase» cuesta una sola.
## Las coordenadas que se pasan son LOCALES; el lote las lleva a pantalla con `mundo = origen + local · escala` (así sustituye a
## `draw_set_transform(origen, 0, Vector2(escala, escala))`) y también escala los grosores.

var _p := PackedVector2Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()
var _o := Vector2.ZERO
var _s := 1.0


## Fija el origen y la escala con los que se llevarán a pantalla las siguientes formas.
func base(origen: Vector2, escala: float) -> void:
	_o = origen
	_s = escala


func limpiar() -> void:
	_p.clear()
	_c.clear()
	_i.clear()


func esta_vacio() -> bool:
	return _i.is_empty()


## Manda todo lo acumulado como UNA orden de dibujo sobre `ci` y deja el lote vacío. Antes pone el transform neutro (las posiciones ya son de mundo).
func emitir(ci: CanvasItem) -> void:
	if not _i.is_empty():
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _i, _p, _c)
	limpiar()


func cuadrilatero(a: Vector2, b: Vector2, d: Vector2, e: Vector2, col: Color) -> void:
	var n := _p.size()
	_p.append(_o + a * _s)
	_p.append(_o + b * _s)
	_p.append(_o + d * _s)
	_p.append(_o + e * _s)
	_c.append(col)
	_c.append(col)
	_c.append(col)
	_c.append(col)
	_i.append(n)
	_i.append(n + 1)
	_i.append(n + 2)
	_i.append(n)
	_i.append(n + 2)
	_i.append(n + 3)


func rectangulo(r: Rect2, col: Color) -> void:
	var x0 := _o.x + r.position.x * _s
	var y0 := _o.y + r.position.y * _s
	var x1 := _o.x + r.end.x * _s
	var y1 := _o.y + r.end.y * _s
	var n := _p.size()
	_p.append(Vector2(x0, y0))
	_p.append(Vector2(x1, y0))
	_p.append(Vector2(x1, y1))
	_p.append(Vector2(x0, y1))
	_c.append(col)
	_c.append(col)
	_c.append(col)
	_c.append(col)
	_i.append(n)
	_i.append(n + 1)
	_i.append(n + 2)
	_i.append(n)
	_i.append(n + 2)
	_i.append(n + 3)


## Borde de `w` de grosor CENTRADO sobre el contorno del rectángulo (igual que `draw_rect(r, col, false, w)`): cuatro rectángulos que no se pisan.
func marco(r: Rect2, w: float, col: Color) -> void:
	var h := w * 0.5
	var ext := r.grow(h)
	rectangulo(Rect2(ext.position, Vector2(ext.size.x, w)), col)
	rectangulo(Rect2(Vector2(ext.position.x, ext.end.y - w), Vector2(ext.size.x, w)), col)
	rectangulo(Rect2(Vector2(ext.position.x, ext.position.y + w), Vector2(w, ext.size.y - 2.0 * w)), col)
	rectangulo(Rect2(Vector2(ext.end.x - w, ext.position.y + w), Vector2(w, ext.size.y - 2.0 * w)), col)


func linea(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var t := (b - a).normalized()
	var nv := Vector2(-t.y, t.x) * (w * 0.5)
	cuadrilatero(a + nv, a - nv, b - nv, b + nv, col)


func triangulo(a: Vector2, b: Vector2, d: Vector2, col: Color) -> void:
	var n := _p.size()
	_p.append(_o + a * _s)
	_p.append(_o + b * _s)
	_p.append(_o + d * _s)
	_c.append(col)
	_c.append(col)
	_c.append(col)
	_i.append(n)
	_i.append(n + 1)
	_i.append(n + 2)


## Disco relleno (abanico de `seg` triángulos).
func disco(centro: Vector2, rad: float, col: Color, seg := 12) -> void:
	var n := _p.size()
	_p.append(_o + centro * _s)
	_c.append(col)
	for k in seg:
		var ang := TAU * float(k) / float(seg)
		_p.append(_o + (centro + Vector2(cos(ang), sin(ang)) * rad) * _s)
		_c.append(col)
	for k in seg:
		_i.append(n)
		_i.append(n + 1 + k)
		_i.append(n + 1 + (k + 1) % seg)


## Anillo de `w` de grosor centrado en el radio `rad`.
func anillo(centro: Vector2, rad: float, w: float, col: Color, seg := 20) -> void:
	var n := _p.size()
	var r0 := rad - w * 0.5
	var r1 := rad + w * 0.5
	for k in seg:
		var ang := TAU * float(k) / float(seg)
		var d := Vector2(cos(ang), sin(ang))
		_p.append(_o + (centro + d * r0) * _s)
		_p.append(_o + (centro + d * r1) * _s)
		_c.append(col)
		_c.append(col)
	for k in seg:
		var a0 := n + k * 2
		var a1 := n + ((k + 1) % seg) * 2
		_i.append(a0)
		_i.append(a0 + 1)
		_i.append(a1)
		_i.append(a1)
		_i.append(a0 + 1)
		_i.append(a1 + 1)


## Cinta de `w` de grosor siguiendo la curva `pts` (coordenadas LOCALES). Con `alternos` se salta un tramo de cada dos (línea discontinua).
func tira(pts: PackedVector2Array, w: float, col: Color, alternos := false) -> void:
	var n := pts.size()
	if n < 2:
		return
	var h := w * 0.5
	var base_i := _p.size()
	for k in n:
		var t: Vector2
		if k == 0:
			t = pts[1] - pts[0]
		elif k == n - 1:
			t = pts[k] - pts[k - 1]
		else:
			t = pts[k + 1] - pts[k - 1]
		t = t.normalized()
		var nv := Vector2(-t.y, t.x) * h
		_p.append(_o + (pts[k] + nv) * _s)
		_p.append(_o + (pts[k] - nv) * _s)
		_c.append(col)
		_c.append(col)
	for k in n - 1:
		if alternos and k % 2 == 1:
			continue
		var i0 := base_i + k * 2
		_i.append(i0)
		_i.append(i0 + 1)
		_i.append(i0 + 2)
		_i.append(i0 + 2)
		_i.append(i0 + 1)
		_i.append(i0 + 3)


## Degradado vertical: un rectángulo con el color `arriba` en su borde de arriba y `abajo` en el de abajo.
func degradado_v(r: Rect2, arriba: Color, abajo: Color) -> void:
	var x0 := _o.x + r.position.x * _s
	var y0 := _o.y + r.position.y * _s
	var x1 := _o.x + r.end.x * _s
	var y1 := _o.y + r.end.y * _s
	var n := _p.size()
	_p.append(Vector2(x0, y0))
	_p.append(Vector2(x1, y0))
	_p.append(Vector2(x1, y1))
	_p.append(Vector2(x0, y1))
	_c.append(arriba)
	_c.append(arriba)
	_c.append(abajo)
	_c.append(abajo)
	_i.append(n)
	_i.append(n + 1)
	_i.append(n + 2)
	_i.append(n)
	_i.append(n + 2)
	_i.append(n + 3)


## Degradado horizontal (`izq` en el borde izquierdo, `der` en el derecho).
func degradado_h(r: Rect2, izq: Color, der: Color) -> void:
	var x0 := _o.x + r.position.x * _s
	var y0 := _o.y + r.position.y * _s
	var x1 := _o.x + r.end.x * _s
	var y1 := _o.y + r.end.y * _s
	var n := _p.size()
	_p.append(Vector2(x0, y0))
	_p.append(Vector2(x1, y0))
	_p.append(Vector2(x1, y1))
	_p.append(Vector2(x0, y1))
	_c.append(izq)
	_c.append(der)
	_c.append(der)
	_c.append(izq)
	_i.append(n)
	_i.append(n + 1)
	_i.append(n + 2)
	_i.append(n)
	_i.append(n + 2)
	_i.append(n + 3)


## Disco con degradado radial: `centro` en el medio y `borde` en el contorno (halos, brillos).
func disco_radial(centro: Vector2, rad: float, col_centro: Color, col_borde: Color, seg := 20) -> void:
	var n := _p.size()
	_p.append(_o + centro * _s)
	_c.append(col_centro)
	for k in seg:
		var ang := TAU * float(k) / float(seg)
		_p.append(_o + (centro + Vector2(cos(ang), sin(ang)) * rad) * _s)
		_c.append(col_borde)
	for k in seg:
		_i.append(n)
		_i.append(n + 1 + k)
		_i.append(n + 1 + (k + 1) % seg)


## Rombo y polígonos regulares (marcas del interior de los nodos): `lados` vértices, el primero hacia arriba.
func poligono(centro: Vector2, rad: float, lados: int, col: Color) -> void:
	var n := _p.size()
	_p.append(_o + centro * _s)
	_c.append(col)
	for k in lados:
		var ang := TAU * float(k) / float(lados) - PI * 0.5
		_p.append(_o + (centro + Vector2(cos(ang), sin(ang)) * rad) * _s)
		_c.append(col)
	for k in lados:
		_i.append(n)
		_i.append(n + 1 + k)
		_i.append(n + 1 + (k + 1) % lados)
