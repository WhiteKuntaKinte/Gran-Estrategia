extends RefCounted
## 0.1.8.44 · LOTE CON UV: igual que `lote_dibujo.gd` (todo en UNA orden de dibujo) pero cada vértice lleva además una coordenada UV, que los shaders de las capas
## animadas usan como datos (ver `planeta.gdshader` y `estela.gdshader`). Las posiciones son de PANTALLA (se arman al redibujar el árbol; la animación la hace el shader).

var _p := PackedVector2Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _i := PackedInt32Array()


func limpiar() -> void:
	_p.clear()
	_c.clear()
	_uv.clear()
	_i.clear()


## Manda todo lo acumulado como UNA orden de dibujo sobre `ci` (que lleva el material con el shader) y deja el lote vacío.
func emitir(ci: CanvasItem) -> void:
	if not _i.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _i, _p, _c, _uv)
	limpiar()


## Cuadro de lado 2·`mitad` centrado en `centro`; el UV va de (uv_c − uv_m) a (uv_c + uv_m) en cada eje.
func cuadro(centro: Vector2, mitad: float, col: Color, uv_c: Vector2, uv_m: float) -> void:
	var n := _p.size()
	_p.append(centro + Vector2(-mitad, -mitad))
	_p.append(centro + Vector2(mitad, -mitad))
	_p.append(centro + Vector2(mitad, mitad))
	_p.append(centro + Vector2(-mitad, mitad))
	_uv.append(uv_c + Vector2(-uv_m, -uv_m))
	_uv.append(uv_c + Vector2(uv_m, -uv_m))
	_uv.append(uv_c + Vector2(uv_m, uv_m))
	_uv.append(uv_c + Vector2(-uv_m, uv_m))
	for k in 4:
		_c.append(col)
	_i.append_array(PackedInt32Array([n, n + 1, n + 2, n, n + 2, n + 3]))


## Cinta de `ancho` px a lo largo de la polilínea `pts` (en pantalla): UV.x = distancia recorrida (+ `desfase`), UV.y = −1 / +1 a cada lado.
func cinta(pts: PackedVector2Array, ancho: float, col: Color, desfase: float) -> void:
	var m := pts.size()
	if m < 2:
		return
	var n0 := _p.size()
	var dist := desfase
	var medio := ancho * 0.5
	for k in m:
		var t: Vector2
		if k == 0:
			t = pts[1] - pts[0]
		elif k == m - 1:
			t = pts[k] - pts[k - 1]
		else:
			t = pts[k + 1] - pts[k - 1]
		if t.length_squared() < 1.0e-9:
			t = Vector2.RIGHT
		t = t.normalized()
		var nv := Vector2(-t.y, t.x) * medio
		if k > 0:
			dist += pts[k].distance_to(pts[k - 1])
		_p.append(pts[k] + nv)
		_p.append(pts[k] - nv)
		_uv.append(Vector2(dist, 1.0))
		_uv.append(Vector2(dist, -1.0))
		_c.append(col)
		_c.append(col)
	for k in m - 1:
		var a := n0 + k * 2
		_i.append_array(PackedInt32Array([a, a + 1, a + 3, a, a + 3, a + 2]))


## Como `emitir` pero SIN vaciar el lote: lo usan las capas animadas, que pueden repintarse solas (por ejemplo al cambiar de tamaño) sin que el árbol rearme su geometría.
func emitir_conservando(ci: CanvasItem) -> void:
	if not _i.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), _i, _p, _c, _uv)
