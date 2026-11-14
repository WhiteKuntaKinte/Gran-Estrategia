extends Control
## HUB de una rama de Descubrimientos (0.1.8.43): las secciones como TARJETAS grandes, cada una con la constelación de sus descubrimientos de fondo
## (un punto por descubrimiento, del color de su estado: negro, gris, verde o dorado, unidos por sus líneas), su nombre y cuánto lleva el país.
## Pulsar una tarjeta entra al árbol de esa sección. Todo se dibuja en UN control, en lotes (`lote_dibujo.gd`).

signal elegida(s: int)                  # clic en la tarjeta de la sección `s`

const LoteScript := preload("res://scripts/lote_dibujo.gd")
const ArbolScript := preload("res://scripts/arbol_descubrimientos.gd")
const FondoScript := preload("res://scripts/fondo_descubrimientos.gd")

const ANCHO_MIN := 270.0
const ALTO_MIN := 112.0
const ALTO_MAX := 210.0
const HUECO := 14.0
const MARGEN := 22.0

var d
var fuente: Font
var fuente_neg: Font
var tid := -1
var rama := 0
var cuentas := PackedInt32Array()       # por sección: cuántos conoce el país mostrado
var totales := PackedInt32Array()       # por sección: cuántos hay
var disponibles := PackedInt32Array()   # por sección: cuántos puede investigar ya
var hover := -1                         # sección bajo el ratón
var tarjetas: Array = []                # [{s, rect}] de la última distribución (para clics y pruebas)
var dibujos := 0                        # (pruebas) cuántas veces se dibujó
var _secs := PackedInt32Array()         # secciones de la rama mostrada
var _mini := {}                         # sección -> {nodos, p (normalizados 0..1), ar (pares de posiciones en `nodos`)}
var _est := {}                          # sección -> PackedByteArray con el estado de cada nodo de `nodos`
var _ayuda: ArbolScript                 # solo se usa para calcular la distribución de las miniaturas
var _scroll := 0.0
var _alto_total := 0.0
var _lote := LoteScript.new()
var _tx: Array = []


func construir(descub, f: Font, f_neg: Font) -> void:
	d = descub
	fuente = f
	fuente_neg = f_neg
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_ayuda = ArbolScript.new()
	_ayuda.construir(d, f, f_neg)
	cuentas.resize(d.secciones.size())
	totales.resize(d.secciones.size())
	disponibles.resize(d.secciones.size())


func fijar_rama(r: int) -> void:
	rama = r
	_secs = PackedInt32Array()
	for s in d.secciones.size():
		if int(d.secciones[s]["rama"]) == r:
			_secs.append(s)
	_scroll = 0.0
	hover = -1
	refrescar()


func fijar_tid(t: int) -> void:
	tid = t
	refrescar()


## Miniatura de la sección `s` (se calcula una vez y se guarda: el catálogo no cambia mientras se juega).
func miniatura(s: int) -> Dictionary:
	if _mini.has(s):
		return _mini[s]
	_ayuda.fijar_seccion(s, false)
	var nodos: PackedInt32Array = _ayuda.nodos.duplicate()
	var p := PackedVector2Array()
	var ancho := maxf(_ayuda.tam_arbol.x, 1.0)
	var alto := maxf(_ayuda.tam_arbol.y, 1.0)
	var lugar := {}
	for k in nodos.size():
		var pn: Vector2 = _ayuda.pos[nodos[k]]
		p.append(Vector2(pn.x / ancho, pn.y / alto))
		lugar[nodos[k]] = k
	var ar := PackedInt32Array()
	for a in _ayuda.aristas:
		ar.append(int(lugar[int(a["a"])]))
		ar.append(int(lugar[int(a["b"])]))
	var r := {"nodos": nodos, "p": p, "ar": ar}
	_mini[s] = r
	return r


## Recalcula cuántos conoce el país en cada sección y el estado de cada punto de las miniaturas, y redibuja.
func refrescar() -> void:
	if d == null:
		return
	cuentas.fill(0)
	totales.fill(0)
	disponibles.fill(0)
	for s in _secs:
		var m := miniatura(s)
		var nodos: PackedInt32Array = m["nodos"]
		var est := PackedByteArray()
		est.resize(nodos.size())
		for k in nodos.size():
			var i: int = nodos[k]
			var e := ArbolScript.E_BLOQUEADO
			if d.conoce(tid, i):
				e = ArbolScript.E_CONOCIDO
				cuentas[s] += 1
			elif d.requisitos_cumplidos(tid, i):
				e = ArbolScript.E_DISPONIBLE
				disponibles[s] += 1
			elif int(d.anio[i]) > d.anio_actual:
				e = ArbolScript.E_LEJANO
			est[k] = e
		totales[s] = nodos.size()
		_est[s] = est
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_scroll = clampf(_scroll, 0.0, maxf(_alto_total - size.y, 0.0))
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT and hover != -1:
		hover = -1
		queue_redraw()


func _tarjeta_en(p: Vector2) -> int:
	for t in tarjetas:
		if (t["rect"] as Rect2).has_point(p):
			return int(t["s"])
	return -1


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _tarjeta_en((ev as InputEventMouseMotion).position)
		if h != hover:
			hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
			queue_redraw()
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var s := _tarjeta_en(mb.position)
			if s >= 0:
				elegida.emit(s)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = clampf(_scroll + 60.0, 0.0, maxf(_alto_total - size.y, 0.0))
			queue_redraw()
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = clampf(_scroll - 60.0, 0.0, maxf(_alto_total - size.y, 0.0))
			queue_redraw()
			accept_event()


## Reparte las tarjetas en una cuadrícula que ocupa todo el ancho; si no caben a su altura mínima, se desliza con la rueda.
func _distribuir() -> void:
	tarjetas = []
	var n := _secs.size()
	if n == 0 or size.x < 100.0:
		return
	var utiles := size.x - 2.0 * MARGEN
	var cols := clampi(int(floorf((utiles + HUECO) / (ANCHO_MIN + HUECO))), 1, 6)
	var filas := int(ceilf(float(n) / float(cols)))
	var ancho := (utiles - float(cols - 1) * HUECO) / float(cols)
	var alto := clampf((size.y - 2.0 * MARGEN - float(filas - 1) * HUECO) / float(filas), ALTO_MIN, ALTO_MAX)
	for k in n:
		var c := k % cols
		var f := floori(float(k) / float(cols))
		tarjetas.append({"s": int(_secs[k]), "rect": Rect2(MARGEN + float(c) * (ancho + HUECO), MARGEN + float(f) * (alto + HUECO) - _scroll, ancho, alto)})
	_alto_total = 2.0 * MARGEN + float(filas) * alto + float(filas - 1) * HUECO


func _draw() -> void:
	dibujos += 1
	_lote.limpiar()
	_tx.clear()
	_distribuir()
	if tarjetas.is_empty():
		return
	_lote.base(Vector2.ZERO, 1.0)
	for k in tarjetas.size():
		_tarjeta(int(tarjetas[k]["s"]), tarjetas[k]["rect"] as Rect2, k)
	_lote.emitir(self)
	_texto_emitir()


func _tarjeta(s: int, r: Rect2, k: int) -> void:
	if r.end.y < 0.0 or r.position.y > size.y:
		return
	var pal: Array = FondoScript.PALETAS[rama]
	var ac: Color = Color.from_hsv(fposmod((pal[2] as Color).h + float(k % 9 - 4) * 0.011, 1.0), (pal[2] as Color).s, (pal[2] as Color).v)
	var sobre := s == hover
	var arriba: Color = (pal[0] as Color).lerp(ac, 0.20 if not sobre else 0.34)
	var abajo: Color = (pal[1] as Color).lerp(ac, 0.07 if not sobre else 0.16)
	_lote.rectangulo(Rect2(r.position + Vector2(3.0, 4.0), r.size), Color(0.0, 0.0, 0.0, 0.40))
	_lote.degradado_v(r, Color(arriba.r, arriba.g, arriba.b, 0.93), Color(abajo.r, abajo.g, abajo.b, 0.96))
	# constelación de fondo: unos puntos por descubrimiento, del color de su estado
	var m := miniatura(s)
	var p: PackedVector2Array = m["p"]
	var ar: PackedInt32Array = m["ar"]
	var est: PackedByteArray = _est.get(s, PackedByteArray())
	var zona := Rect2(r.position + Vector2(r.size.x * 0.52, 10.0), Vector2(r.size.x * 0.45, r.size.y - 26.0))
	for q in range(0, ar.size(), 2):
		var a := zona.position + Vector2(p[ar[q]].x * zona.size.x, (1.0 - p[ar[q]].y) * zona.size.y)
		var b := zona.position + Vector2(p[ar[q + 1]].x * zona.size.x, (1.0 - p[ar[q + 1]].y) * zona.size.y)
		var ca := Color(1.0, 1.0, 1.0, 0.10)
		if est.size() > ar[q] and int(est[ar[q]]) == ArbolScript.E_CONOCIDO:
			ca = Color(ArbolScript.C_CONOCIDO.r, ArbolScript.C_CONOCIDO.g, ArbolScript.C_CONOCIDO.b, 0.38)
		_lote.linea(a, b, 1.0, ca)
	var rad := clampf(minf(zona.size.x, zona.size.y) / 34.0, 1.6, 3.4)
	for j in p.size():
		var pt := zona.position + Vector2(p[j].x * zona.size.x, (1.0 - p[j].y) * zona.size.y)
		var e: int = int(est[j]) if j < est.size() else ArbolScript.E_BLOQUEADO
		match e:
			ArbolScript.E_CONOCIDO:
				_lote.disco(pt, rad, ArbolScript.C_CONOCIDO, 8)
			ArbolScript.E_DISPONIBLE:
				_lote.disco_radial(pt, rad * 3.2, Color(ArbolScript.C_DISPONIBLE.r, ArbolScript.C_DISPONIBLE.g, ArbolScript.C_DISPONIBLE.b, 0.5), Color(ArbolScript.C_DISPONIBLE.r, ArbolScript.C_DISPONIBLE.g, ArbolScript.C_DISPONIBLE.b, 0.0), 12)
				_lote.disco(pt, rad + 0.4, ArbolScript.C_DISPONIBLE, 8)
			ArbolScript.E_LEJANO:
				_lote.disco(pt, rad * 0.9, ArbolScript.C_GRIS, 8)
			_:
				_lote.disco(pt, rad + 0.7, ArbolScript.C_NEGRO_BORDE, 8)
				_lote.disco(pt, rad * 0.9, ArbolScript.C_NEGRO, 8)
	# velo oscuro bajo el texto
	_lote.degradado_h(Rect2(r.position, Vector2(r.size.x * 0.56, r.size.y)), Color(0.0, 0.0, 0.0, 0.62), Color(0.0, 0.0, 0.0, 0.0))
	# barra de progreso
	var tot: int = maxi(int(totales[s]), 1)
	var frac := float(cuentas[s]) / float(tot)
	var bar := Rect2(r.position.x + 12.0, r.end.y - 14.0, r.size.x - 24.0, 5.0)
	_lote.rectangulo(bar, Color(0.0, 0.0, 0.0, 0.5))
	_lote.rectangulo(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), ArbolScript.C_CONOCIDO)
	if int(disponibles[s]) > 0:                                          # dorado: lo que se puede investigar ya
		var f2 := float(disponibles[s]) / float(tot)
		_lote.rectangulo(Rect2(bar.position.x + bar.size.x * frac, bar.position.y, bar.size.x * f2, bar.size.y), Color(ArbolScript.C_DISPONIBLE.r, ArbolScript.C_DISPONIBLE.g, ArbolScript.C_DISPONIBLE.b, 0.85))
	# borde
	_lote.marco(r, 1.6 if not sobre else 2.4, Color(1.0, 0.86, 0.35, 1.0) if sobre else Color(ac.r, ac.g, ac.b, 0.55))
	# textos
	var nombre := String(d.secciones[s]["nombre"])
	var lineas := _partir(nombre, r.size.x * 0.48, 15, 3)
	var y := r.position.y + 24.0
	for ln in lineas:
		_texto(true, Vector2(r.position.x + 14.0, y), String(ln), 15, Color(1.0, 0.97, 0.88))
		y += 19.0
	var extra := "%d / %d" % [cuentas[s], totales[s]]
	if int(disponibles[s]) > 0:
		extra += "  ·  %d por investigar" % disponibles[s]
	_texto(false, Vector2(r.position.x + 14.0, r.end.y - 22.0), extra, 12, Color(0.92, 0.92, 0.96, 0.95), r.size.x - 28.0)
	if r.size.y >= 150.0 and (sobre or r.size.y >= 175.0):
		var desc := _partir(String(d.secciones[s].get("desc", "")), r.size.x * 0.48, 11, 3)
		var y2 := y + 4.0
		for ln2 in desc:
			if y2 > r.end.y - 34.0:
				break
			_texto(false, Vector2(r.position.x + 14.0, y2), String(ln2), 11, Color(0.80, 0.82, 0.88, 0.85))
			y2 += 14.0


func _texto(negrita: bool, p: Vector2, txt: String, tam: int, col: Color, ancho := -1.0) -> void:
	_tx.append([negrita, p, txt, tam, col, ancho])


func _texto_emitir() -> void:
	for pasada in 2:
		for t in _tx:
			if bool(t[0]) == (pasada == 1):
				draw_string(fuente_neg if pasada == 1 else fuente, t[1], t[2], HORIZONTAL_ALIGNMENT_LEFT, t[5], t[3], t[4])
	_tx.clear()


## Parte `txt` en hasta `max_l` líneas de `ancho` px (la última termina en «…» si sobra texto).
func _partir(txt: String, ancho: float, tam: int, max_l: int) -> PackedStringArray:
	var res := PackedStringArray()
	var pal := txt.split(" ")
	var actual := ""
	var k := 0
	while k < pal.size():
		var prueba: String = pal[k] if actual == "" else actual + " " + pal[k]
		if actual != "" and fuente_neg.get_string_size(prueba, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > ancho:
			res.append(actual)
			actual = ""
			if res.size() == max_l:
				break
			continue
		actual = prueba
		k += 1
	if res.size() < max_l and actual != "":
		res.append(actual)
	elif k < pal.size() and res.size() == max_l:
		res[max_l - 1] = res[max_l - 1] + "…"
	return res
