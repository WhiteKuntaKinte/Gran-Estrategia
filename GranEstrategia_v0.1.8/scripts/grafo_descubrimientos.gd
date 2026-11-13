extends Control
## Árbol de UNA sección del catálogo de descubrimientos (0.1.8.42). Lo usa la ventana de Descubrimientos (`ventana_descubrimientos.gd`).
##
## Cómo se dibuja:
##  · Una columna por «nivel de dependencia» dentro de la sección (la raíz a la izquierda; cada descubrimiento queda siempre a la derecha de lo que necesita).
##  · Una banda horizontal por subsección, con su nombre fijo en el borde izquierdo.
##  · Líneas entre prerrequisitos: continua = «hace falta», discontinua = «basta uno de este grupo». Un círculo naranja con un número marca los
##    prerrequisitos que viven en OTRA sección (se ven en la ficha).
##  · Estados: conocido (verde, con ✓), disponible (dorado: ya tienes los prerrequisitos), bloqueado (gris) y aún lejano (gris apagado: su año todavía no llega).
##  · Al pasar el ratón (o al elegir) se resalta la cadena entera: lo que HACE FALTA para llegar (dorado) y lo que ESTE ABRE (naranja).
##
## Todo se dibuja en UN solo control con paneo (arrastrar) y zoom (rueda), recortando lo que queda fuera de la vista: cuesta lo mismo con 20 que con 100 nodos.
## No hay un nodo por descubrimiento. Se redibuja solo cuando algo cambia (mover, zoom, hover, elegir, un cambio de estado).

signal elegido(i: int)                  # clic sobre un nodo (-1 = clic en el vacío)

const Tema := preload("res://scripts/tema_hud.gd")
const ANCHO_NODO := 176.0
const ALTO_NODO := 42.0
const SEP_X := 46.0                     # hueco entre columnas (por donde pasan las líneas)
const SEP_Y := 6.0
const ALTO_BANDA := 22.0                # cabecera de cada subsección
const SEP_BANDA := 10.0
const MARGEN := 18.0
const ZOOM_MIN := 0.25
const ZOOM_MAX := 2.2
const ALTO_CABECERA := 20.0             # franja de arriba con los años de cada columna (en pantalla, no se mueve)
const FONT_NODO := 11
const FONT_ANIO := 10
const LETRA_MIN := 7                    # por debajo de este tamaño (px) no se dibuja el texto del nodo
const ZOOM_AJUSTE_MIN := 0.75           # «Ajustar vista» no baja de aquí: con menos la letra ya no se lee (si el árbol no cabe se ve desde la esquina y se recorre)

const E_BLOQUEADO := 0
const E_DISPONIBLE := 1
const E_CONOCIDO := 2
const E_LEJANO := 3                     # no lo conoce, no tiene los prerrequisitos y su año es posterior al reloj
const NOMBRE_ESTADO := ["Bloqueado", "Disponible", "Conocido", "Aún lejano"]

var d                                   # Descubrimientos
var fuente: Font
var fuente_neg: Font
var tid := -1                           # país cuyo estado se muestra (-1 = solo lo que sabe la historia)
var seccion := -1
var nodos := PackedInt32Array()         # índices de los descubrimientos de la sección
var pos := {}                           # índice -> Vector2 (esquina superior izquierda, en coordenadas del árbol)
var textos := {}                        # índice -> PackedStringArray (el nombre partido en 1 o 2 líneas)
var externos := {}                      # índice -> cuántos prerrequisitos están en otra sección
var aristas: Array = []                 # [{a, b, o, pts}]: a es prerrequisito de b; o = alternativa (basta uno)
var columnas := 0
var cols_anios: Array = []              # por columna: [año menor, año mayor]
var bandas: Array = []                  # [{nombre, y, alto}]
var tam_arbol := Vector2.ZERO
var zoom := 1.0
var origen := Vector2(MARGEN, ALTO_CABECERA + MARGEN)    # dónde cae (0,0) del árbol en el control
var sel := -1
var hover := -1
var filtro_estado := 0                  # 0 todos · 1 conocidos · 2 disponibles · 3 bloqueados · 4 aún lejanos
var filtro_tipo := ""                   # "" = todos
var _est := {}                          # índice -> estado (se recalcula en `refrescar`)
var _prev := {}                         # la cadena de lo que hace falta para llegar al nodo enfocado (cualquier sección)
var _sig := {}                          # la cadena de lo que el nodo enfocado abre
var _foco := -1
var _arrastrando := false
var _movido := false
var _p_ini := Vector2.ZERO
var _raton := Vector2.ZERO
var _gp := PackedVector2Array()         # malla del dibujo en curso (ver `_g_emitir`)
var _gc := PackedColorArray()
var _gi := PackedInt32Array()
var _tx: Array = []                     # textos pendientes del dibujo en curso (ver `_t`)
var dibujos := 0                        # (pruebas) cuántas veces se dibujó
var nodos_dibujados := 0                # (pruebas) cuántos nodos entraron en el último dibujo


func construir(descub, f: Font, f_neg: Font) -> void:
	d = descub
	fuente = f
	fuente_neg = f_neg
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_DRAG


# ─────────────────────────────────────────────────────────────
# Estado de cada descubrimiento
# ─────────────────────────────────────────────────────────────
## Estado de `i` para el país `tid` (se calcula en el momento: sirve para cualquier descubrimiento, no solo los de la sección).
func estado_nodo(i: int) -> int:
	if d.conoce(tid, i):
		return E_CONOCIDO
	if d.requisitos_cumplidos(tid, i):
		return E_DISPONIBLE
	if int(d.anio[i]) > d.anio_actual:
		return E_LEJANO
	return E_BLOQUEADO


func refrescar() -> void:
	_est.clear()
	for i in nodos:
		_est[i] = estado_nodo(i)
	queue_redraw()


func fijar_tid(t: int) -> void:
	tid = t
	refrescar()


func fijar_filtros(estado: int, tipo: String) -> void:
	filtro_estado = estado
	filtro_tipo = tipo
	queue_redraw()


func _pasa_filtro(i: int) -> bool:
	if filtro_tipo != "" and String(d.tipo[i]) != filtro_tipo:
		return false
	var e: int = int(_est.get(i, E_BLOQUEADO))
	match filtro_estado:
		1:
			return e == E_CONOCIDO
		2:
			return e == E_DISPONIBLE
		3:
			return e == E_BLOQUEADO or e == E_LEJANO
		4:
			return e == E_LEJANO or (e == E_DISPONIBLE and int(d.anio[i]) > d.anio_actual)
	return true


# ─────────────────────────────────────────────────────────────
# Distribución
# ─────────────────────────────────────────────────────────────
func fijar_seccion(s: int, ajustar_vista := true) -> void:
	seccion = s
	sel = -1
	hover = -1
	_foco = -1
	_prev.clear()
	_sig.clear()
	_distribuir()
	refrescar()
	if ajustar_vista:
		ajustar()


func _distribuir() -> void:
	nodos = PackedInt32Array()
	pos.clear()
	textos.clear()
	externos.clear()
	aristas = []
	bandas = []
	cols_anios = []
	columnas = 0
	tam_arbol = Vector2.ZERO
	if d == null or seccion < 0:
		return
	var en_sec := {}
	for i in d.n:
		if int(d.seccion[i]) == seccion:
			nodos.append(i)
			en_sec[i] = true
	# nivel de cada uno: 1 más que su prerrequisito más profundo DE LA MISMA SECCIÓN (así las líneas siempre van hacia la derecha)
	var prof := {}
	var visitando := {}
	for i in nodos:
		_profundidad(i, en_sec, prof, visitando)
	var maxp := 0
	for i in nodos:
		maxp = maxi(maxp, int(prof[i]))
	columnas = maxp + 1
	# subsecciones presentes (la que no tiene, «General», va primero)
	var subs: Array = []
	for i in nodos:
		var si: int = int(d.sub[i])
		if not subs.has(si):
			subs.append(si)
	subs.sort()
	# por celda (subsección, columna): los nodos ordenados por año
	var celdas := {}
	for i in nodos:
		var clave := Vector2i(int(d.sub[i]), int(prof[i]))
		if not celdas.has(clave):
			celdas[clave] = []
		(celdas[clave] as Array).append(i)
	for clave in celdas:
		(celdas[clave] as Array).sort_custom(func(a: int, b: int) -> bool: return d.anio[a] < d.anio[b] or (d.anio[a] == d.anio[b] and a < b))
	var y := 0.0
	for si in subs:
		var filas := 1
		for c in columnas:
			var k := Vector2i(int(si), c)
			if celdas.has(k):
				filas = maxi(filas, (celdas[k] as Array).size())
		var nombre_b := "General" if int(si) < 0 else String(d.subsecciones[int(si)])
		var alto := ALTO_BANDA + float(filas) * (ALTO_NODO + SEP_Y) + SEP_BANDA
		bandas.append({"nombre": nombre_b, "y": y, "alto": alto})
		for c in columnas:
			var k2 := Vector2i(int(si), c)
			if not celdas.has(k2):
				continue
			var fila := 0
			for i in (celdas[k2] as Array):
				pos[int(i)] = Vector2(MARGEN + float(c) * (ANCHO_NODO + SEP_X), y + ALTO_BANDA + float(fila) * (ALTO_NODO + SEP_Y))
				fila += 1
		y += alto
	tam_arbol = Vector2(MARGEN * 2.0 + float(columnas) * (ANCHO_NODO + SEP_X) - SEP_X, y + MARGEN)
	# años de cada columna (para la franja de arriba)
	for c in columnas:
		cols_anios.append([2147483647, -2147483647])
	for i in nodos:
		var par: Array = cols_anios[int(prof[i])]
		par[0] = mini(int(par[0]), int(d.anio[i]))
		par[1] = maxi(int(par[1]), int(d.anio[i]))
	# textos y aristas
	for i in nodos:
		textos[i] = _partir(String(d.nombre[i]))
		var ext := 0
		for r in d.req[i]:
			if en_sec.has(int(r)):
				_arista(int(r), i, false)
			else:
				ext += 1
		for g in d.req_o[i]:
			var alguno_fuera := false
			for r2 in g:
				if en_sec.has(int(r2)):
					_arista(int(r2), i, true)
				else:
					alguno_fuera = true
			if alguno_fuera:
				ext += 1
		if ext > 0:
			externos[i] = ext


func _profundidad(i: int, en_sec: Dictionary, prof: Dictionary, visitando: Dictionary) -> int:
	if prof.has(i):
		return int(prof[i])
	if visitando.has(i):
		return 0                                           # ciclo (no debería haberlos): se corta
	visitando[i] = true
	var m := 0
	for r in d.req[i]:
		if en_sec.has(int(r)):
			m = maxi(m, _profundidad(int(r), en_sec, prof, visitando) + 1)
	for g in d.req_o[i]:
		for r2 in g:
			if en_sec.has(int(r2)):
				m = maxi(m, _profundidad(int(r2), en_sec, prof, visitando) + 1)
	visitando.erase(i)
	prof[i] = m
	return m


func _arista(a: int, b: int, alternativa: bool) -> void:
	for ar in aristas:
		if int(ar["a"]) == a and int(ar["b"]) == b:
			if not alternativa:
				ar["o"] = false                            # si está en `req` y en un grupo, manda «hace falta»
			return
	var p0: Vector2 = (pos[a] as Vector2) + Vector2(ANCHO_NODO, ALTO_NODO * 0.5)
	var p1: Vector2 = (pos[b] as Vector2) + Vector2(0.0, ALTO_NODO * 0.5)
	var tramos := clampi(int(p0.distance_to(p1) / 14.0), 8, 48)
	var pts := PackedVector2Array()
	for k in tramos + 1:
		var t := float(k) / float(tramos)
		var s := t * t * (3.0 - 2.0 * t)
		pts.append(Vector2(lerpf(p0.x, p1.x, t), lerpf(p0.y, p1.y, s)))
	aristas.append({"a": a, "b": b, "o": alternativa, "pts": pts})


## Parte el nombre en 1 o 2 líneas que quepan en el nodo (la segunda termina en «…» si sobra).
func _partir(nombre: String) -> PackedStringArray:
	var ancho := ANCHO_NODO - 14.0
	var pal := nombre.split(" ")
	var l1 := ""
	var k := 0
	while k < pal.size():
		var prueba := pal[k] if l1 == "" else l1 + " " + pal[k]
		if l1 != "" and fuente.get_string_size(prueba, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NODO).x > ancho:
			break
		l1 = prueba
		k += 1
	var l2 := ""
	while k < pal.size():
		l2 = pal[k] if l2 == "" else l2 + " " + pal[k]
		k += 1
	if fuente.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NODO).x > ancho:
		l1 = _recortar(l1, ancho)
	if l2 != "" and fuente.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NODO).x > ancho:
		l2 = _recortar(l2, ancho)
	return PackedStringArray([l1, l2]) if l2 != "" else PackedStringArray([l1])


func _recortar(t: String, ancho: float) -> String:
	while t.length() > 1 and fuente.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NODO).x > ancho:
		t = t.substr(0, t.length() - 1)
	return t + "…"


# ─────────────────────────────────────────────────────────────
# Vista
# ─────────────────────────────────────────────────────────────
## Encaja el árbol en el control (sin pasar de zoom 1 ni bajar de `ZOOM_AJUSTE_MIN`: si no cabe entero, se ve desde la esquina y se recorre).
func ajustar() -> void:
	if tam_arbol.x <= 0.0 or size.x <= 0.0:
		return
	var ancho_v := maxf(size.x - 2.0 * MARGEN, 50.0)
	var alto_v := maxf(size.y - ALTO_CABECERA - 2.0 * MARGEN, 50.0)
	zoom = clampf(minf(ancho_v / tam_arbol.x, alto_v / tam_arbol.y), ZOOM_AJUSTE_MIN, 1.0)
	origen = Vector2(MARGEN, ALTO_CABECERA + MARGEN)
	_limitar()
	queue_redraw()


## Lleva el nodo `i` al centro de la vista y lo elige.
func elegir(i: int, centrar := true) -> void:
	sel = i
	_actualizar_foco()
	if centrar and pos.has(i):
		var c: Vector2 = (pos[i] as Vector2) + Vector2(ANCHO_NODO, ALTO_NODO) * 0.5
		origen = size * 0.5 - c * zoom
		origen.y += ALTO_CABECERA * 0.5
		_limitar()
	queue_redraw()


func _limitar() -> void:
	var w := tam_arbol.x * zoom
	var h := tam_arbol.y * zoom
	var hi_x := 80.0
	var lo_x := minf(size.x - w - 80.0, hi_x)
	var hi_y := ALTO_CABECERA + 80.0
	var lo_y := minf(size.y - h - 80.0, hi_y)
	origen = Vector2(clampf(origen.x, lo_x, hi_x), clampf(origen.y, lo_y, hi_y))


func _acercar(factor: float, en: Vector2) -> void:
	var nz := clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(nz, zoom):
		return
	origen = en - (en - origen) * (nz / zoom)
	zoom = nz
	_limitar()
	queue_redraw()


func _nodo_en(p: Vector2) -> int:
	if p.y < ALTO_CABECERA:
		return -1
	var q := (p - origen) / zoom
	for i in nodos:
		var o: Vector2 = pos[i]
		if q.x >= o.x and q.x <= o.x + ANCHO_NODO and q.y >= o.y and q.y <= o.y + ALTO_NODO:
			return i
	return -1


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_acercar(1.12, mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_acercar(1.0 / 1.12, mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_arrastrando = true
				_movido = false
				_p_ini = mb.position
			else:
				if _arrastrando and not _movido:
					var h := _nodo_en(mb.position)
					sel = h
					_actualizar_foco()
					elegido.emit(h)
					queue_redraw()
				_arrastrando = false
			accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		_raton = mm.position
		if _arrastrando:
			if not _movido and mm.position.distance_to(_p_ini) > 4.0:
				_movido = true
			if _movido:
				origen += mm.relative
				_limitar()
				queue_redraw()
		else:
			var h2 := _nodo_en(mm.position)
			if h2 != hover:
				hover = h2
				_actualizar_foco()
				queue_redraw()
			elif hover >= 0:
				queue_redraw()                              # el globo de información sigue al ratón


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hover != -1 and not _arrastrando:
		hover = -1
		_actualizar_foco()
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		_limitar()
		queue_redraw()


## El nodo enfocado es el de debajo del ratón o, si no hay, el elegido. Se calculan las dos cadenas (lo que hace falta y lo que abre) sobre TODO el catálogo.
func _actualizar_foco() -> void:
	var f := hover if hover >= 0 else sel
	if f == _foco:
		return
	_foco = f
	_prev.clear()
	_sig.clear()
	if f < 0 or d == null:
		return
	var pila := [f]
	while not pila.is_empty():
		var i: int = pila.pop_back()
		var pedidos := PackedInt32Array(d.req[i])
		for g in d.req_o[i]:
			pedidos.append_array(g)
		for r in pedidos:
			if not _prev.has(int(r)):
				_prev[int(r)] = true
				pila.append(int(r))
	pila = [f]
	while not pila.is_empty():
		var j: int = pila.pop_back()
		for h in (d.dependientes[j] as PackedInt32Array):
			if not _sig.has(int(h)):
				_sig[int(h)] = true
				pila.append(int(h))


# ─────────────────────────────────────────────────────────────
# Dibujo
# ─────────────────────────────────────────────────────────────
func _draw() -> void:
	dibujos += 1
	nodos_dibujados = 0
	_g_reiniciar()
	_tx.clear()
	if d == null or nodos.is_empty():
		return
	## Cómo se dibuja (0.1.8.42): toda la geometría de una capa (bandas, líneas, flechas, cajas, marcas) va en UNA malla de triángulos con color por vértice
	## y todos los textos de esa capa van seguidos (así el motor los junta en pocas llamadas). Antes eran 2–6 llamadas por nodo y por línea:
	## con 40 nodos a la vista, ~330 llamadas de dibujo por fotograma. Ahora son 4–8, se vea lo que se vea.
	var z := zoom
	var vista := Rect2(Vector2.ZERO, size)
	var vis_arbol := Rect2((-origen) / z, size / z).grow(30.0)
	var hay_foco := _foco >= 0
	var c_violeta := Tema.color_rol("violeta")
	var c_azul := Tema.color_rol("azul")
	# bandas (fondo alternado de lado a lado)
	for b in bandas.size():
		var bd: Dictionary = bandas[b]
		var y0: float = origen.y + float(bd["y"]) * z
		var h0: float = float(bd["alto"]) * z
		if y0 > size.y or y0 + h0 < 0.0:
			continue
		if b % 2 == 0:
			_g_rect(Rect2(0.0, y0, size.x, h0), Color(Tema.BLOQUE_SUAVE.r, Tema.BLOQUE_SUAVE.g, Tema.BLOQUE_SUAVE.b, 0.45))
	# líneas entre prerrequisitos (el grosor es fijo en píxeles)
	for ar in aristas:
		var a: int = ar["a"]
		var bb: int = ar["b"]
		var pts: PackedVector2Array = ar["pts"]
		var pa: Vector2 = pts[0]
		var pb: Vector2 = pts[pts.size() - 1]
		if not vis_arbol.intersects(Rect2(pa, pb - pa).abs()):
			continue
		var col: Color
		var ancho := 1.3
		if hay_foco and (a == _foco or _prev.has(a)) and (bb == _foco or _prev.has(bb)):
			col = Tema.ORO
			ancho = 2.6
		elif hay_foco and (bb == _foco or _sig.has(bb)) and (a == _foco or _sig.has(a)):
			col = c_violeta
			ancho = 2.6
		elif hay_foco:
			col = Color(Tema.TENUE.r, Tema.TENUE.g, Tema.TENUE.b, 0.13)
		elif int(_est.get(a, 0)) == E_CONOCIDO:
			col = Color(Tema.OK.r, Tema.OK.g, Tema.OK.b, 0.65)
		else:
			col = Color(Tema.TENUE.r, Tema.TENUE.g, Tema.TENUE.b, 0.5)
		_g_tira(pts, origen, z, ancho + 1.0, Color(col.r, col.g, col.b, col.a * 0.3), bool(ar["o"]))     # halo suave (la malla no tiene suavizado propio)
		_g_tira(pts, origen, z, ancho, col, bool(ar["o"]))
		var pf := origen + pb * z
		_g_tri(pf, pf + Vector2(-6.0, -3.5), pf + Vector2(-6.0, 3.5), col)
	# cajas de los nodos
	for i in nodos:
		var o: Vector2 = pos[i]
		var r_arbol := Rect2(o, Vector2(ANCHO_NODO, ALTO_NODO))
		if not vis_arbol.intersects(r_arbol):
			continue
		nodos_dibujados += 1
		var e: int = int(_est.get(i, E_BLOQUEADO))
		var atenuado := (hay_foco and i != _foco and not _prev.has(i) and not _sig.has(i)) or not _pasa_filtro(i)
		var fondo := Tema.TARJETA
		var borde := Tema.ACERO_OSCURO
		var grosor := 1.2
		match e:
			E_CONOCIDO:
				fondo = Tema.TARJETA.lerp(Tema.OK, 0.38)
				borde = Tema.OK
				grosor = 1.8
			E_DISPONIBLE:
				fondo = Tema.TARJETA.lerp(c_azul, 0.32)
				borde = c_azul
				grosor = 2.2
			E_LEJANO:
				fondo = Tema.TARJETA.lerp(Tema.FONDO_ABAJO, 0.45)
		if i == _foco:
			borde = Tema.TITULO if Tema.ID != 0 else Tema.TEXTO
			grosor = 3.0
		elif _prev.has(i) and hay_foco:
			borde = Tema.ORO
			grosor = 2.4
		elif _sig.has(i) and hay_foco:
			borde = c_violeta
			grosor = 2.4
		var alfa := 0.28 if atenuado else (0.72 if e == E_LEJANO else 1.0)
		fondo.a = fondo.a * alfa
		borde.a = borde.a * (0.3 if atenuado else 1.0)
		var rp := Rect2(origen + o * z, Vector2(ANCHO_NODO, ALTO_NODO) * z)
		_g_rect(rp, fondo)
		_g_marco(rp, grosor, borde)
		if e == E_CONOCIDO:                                       # ✓ dibujada (la fuente puede no traerla)
			var c0 := origen + (o + Vector2(ANCHO_NODO - 16.0, 8.0)) * z
			var cb := Color(Tema.OK.r, Tema.OK.g, Tema.OK.b, borde.a)
			_g_linea(c0, c0 + Vector2(3.5, 4.0) * z, 2.0, cb)
			_g_linea(c0 + Vector2(3.5, 4.0) * z, c0 + Vector2(10.0, -4.0) * z, 2.0, cb)
		elif e == E_DISPONIBLE:
			_g_disco(origen + (o + Vector2(ANCHO_NODO - 10.0, 10.0)) * z, 4.0 * z, Color(c_azul.r, c_azul.g, c_azul.b, borde.a))
	# texto y marcas que no escalan con el árbol: letra ya multiplicada por el zoom
	var tam_n := int(roundf(float(FONT_NODO) * z))
	var tam_a := int(roundf(float(FONT_ANIO) * z))
	var con_texto := tam_n >= LETRA_MIN
	for i in nodos:
		var o2: Vector2 = pos[i]
		var rp2 := Rect2(origen + o2 * z, Vector2(ANCHO_NODO, ALTO_NODO) * z)
		if not vista.intersects(rp2):
			continue
		var atenuado2 := (hay_foco and i != _foco and not _prev.has(i) and not _sig.has(i)) or not _pasa_filtro(i)
		var e2: int = int(_est.get(i, E_BLOQUEADO))
		if con_texto:
			var col_t := Tema.TEXTO if (e2 == E_CONOCIDO or e2 == E_DISPONIBLE) else Tema.TENUE
			if atenuado2:
				col_t.a = 0.35
			var ls: PackedStringArray = textos[i]
			var base_y := rp2.position.y + 3.0 * z
			for k in ls.size():
				_t(false, Vector2(rp2.position.x + 7.0 * z, base_y + (float(k) * 12.0 + 10.0) * z), ls[k], tam_n, col_t)
			if tam_a >= LETRA_MIN:
				var col_a := Tema.TENUE
				col_a.a = 0.35 if atenuado2 else 0.9
				_t(false, Vector2(rp2.position.x + 7.0 * z, rp2.position.y + (ALTO_NODO - 5.0) * z), d.anio_texto(int(d.anio[i])), tam_a, col_a)
		if externos.has(i):
			var rad := maxf(6.0 * z, 5.0)
			_g_disco(rp2.position, rad, Tema.NARANJA)
			if rad >= 6.0:
				_t(true, rp2.position + Vector2(-rad * 0.5, rad * 0.4), str(externos[i]), maxi(int(rad * 1.3), 7), Color.WHITE, rad, HORIZONTAL_ALIGNMENT_CENTER)
	_g_emitir()
	_t_emitir()
	# franja de arriba: años de cada columna
	_g_rect(Rect2(0.0, 0.0, size.x, ALTO_CABECERA), Tema.BLOQUE)
	_g_rect(Rect2(0.0, ALTO_CABECERA, size.x, 1.0), Tema.ACERO_OSCURO)
	for c in columnas:
		var x0 := origen.x + (MARGEN + float(c) * (ANCHO_NODO + SEP_X)) * z
		var ancho_c := ANCHO_NODO * z
		if x0 > size.x or x0 + ancho_c < 0.0:
			continue
		var par: Array = cols_anios[c]
		var txt := _anio_corto(int(par[0]))
		if int(par[1]) != int(par[0]) and ancho_c >= 110.0:
			txt += "  →  " + _anio_corto(int(par[1]))
		_t(false, Vector2(maxf(x0, 2.0), ALTO_CABECERA - 6.0), txt, 10, Tema.TENUE, maxf(ancho_c, 60.0))
	# nombres de las bandas (fijos al borde izquierdo mientras la banda se ve)
	for bd2 in bandas:
		var yb: float = origen.y + float(bd2["y"]) * z
		var hb: float = float(bd2["alto"]) * z
		if yb > size.y or yb + hb < ALTO_CABECERA:
			continue
		var ty := maxf(yb + 15.0, ALTO_CABECERA + 15.0)
		if ty > yb + hb - 4.0:
			continue
		var nombre_b: String = String(bd2["nombre"])
		var wb := fuente_neg.get_string_size(nombre_b, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_g_rect(Rect2(4.0, ty - 13.0, wb + 10.0, 18.0), Color(Tema.FONDO_ABAJO.r, Tema.FONDO_ABAJO.g, Tema.FONDO_ABAJO.b, 0.82))
		_t(true, Vector2(9.0, ty), nombre_b, 12, Tema.ORO)
	_leyenda()
	_g_emitir()
	_t_emitir()
	# globo con el nombre completo del nodo bajo el ratón
	if hover >= 0 and not _arrastrando:
		_globo(hover)
		_g_emitir()
		_t_emitir()


# ── Geometría por lotes: se acumula en `_gp/_gc/_gi` y `_g_emitir` la manda como UNA orden de dibujo ──
func _g_reiniciar() -> void:
	_gp.clear()
	_gc.clear()
	_gi.clear()


func _g_emitir() -> void:
	if not _gi.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _gi, _gp, _gc)
	_g_reiniciar()


func _g_quad(a: Vector2, b: Vector2, c: Vector2, e: Vector2, col: Color) -> void:
	var base := _gp.size()
	_gp.append(a)
	_gp.append(b)
	_gp.append(c)
	_gp.append(e)
	for k in 4:
		_gc.append(col)
	_gi.append(base)
	_gi.append(base + 1)
	_gi.append(base + 2)
	_gi.append(base)
	_gi.append(base + 2)
	_gi.append(base + 3)


func _g_rect(r: Rect2, col: Color) -> void:
	_g_quad(r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), col)


## Borde de `w` px hacia dentro del rectángulo (cuatro rectángulos que no se pisan).
func _g_marco(r: Rect2, w: float, col: Color) -> void:
	var w2 := minf(w, minf(r.size.x, r.size.y) * 0.5)
	_g_rect(Rect2(r.position, Vector2(r.size.x, w2)), col)
	_g_rect(Rect2(Vector2(r.position.x, r.end.y - w2), Vector2(r.size.x, w2)), col)
	_g_rect(Rect2(Vector2(r.position.x, r.position.y + w2), Vector2(w2, r.size.y - 2.0 * w2)), col)
	_g_rect(Rect2(Vector2(r.end.x - w2, r.position.y + w2), Vector2(w2, r.size.y - 2.0 * w2)), col)


func _g_linea(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var t := (b - a).normalized()
	var n := Vector2(-t.y, t.x) * (w * 0.5)
	_g_quad(a + n, a - n, b - n, b + n, col)


func _g_tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var base := _gp.size()
	_gp.append(a)
	_gp.append(b)
	_gp.append(c)
	for k in 3:
		_gc.append(col)
	_gi.append(base)
	_gi.append(base + 1)
	_gi.append(base + 2)


func _g_disco(c: Vector2, rad: float, col: Color) -> void:
	var base := _gp.size()
	_gp.append(c)
	_gc.append(col)
	for k in 12:
		var ang := TAU * float(k) / 12.0
		_gp.append(c + Vector2(cos(ang), sin(ang)) * rad)
		_gc.append(col)
	for k in 12:
		_gi.append(base)
		_gi.append(base + 1 + k)
		_gi.append(base + 1 + (k + 1) % 12)


## Cinta de `w` px siguiendo una curva en coordenadas del árbol (`o` + punto · `z` = pantalla). Con `alternos` se salta un tramo de cada dos (línea discontinua).
func _g_tira(pts: PackedVector2Array, o: Vector2, z: float, w: float, col: Color, alternos: bool) -> void:
	var n := pts.size()
	if n < 2:
		return
	var h := w * 0.5
	var base := _gp.size()
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
		var p := o + pts[k] * z
		_gp.append(p + nv)
		_gp.append(p - nv)
		_gc.append(col)
		_gc.append(col)
	for k in n - 1:
		if alternos and k % 2 == 1:
			continue
		var i0 := base + k * 2
		_gi.append(i0)
		_gi.append(i0 + 1)
		_gi.append(i0 + 2)
		_gi.append(i0 + 2)
		_gi.append(i0 + 1)
		_gi.append(i0 + 3)


## Encola un texto: `_t_emitir` los dibuja todos seguidos (primero los de letra normal y luego los de negrita: cada fuente es una textura distinta).
func _t(negrita: bool, p: Vector2, txt: String, tam: int, col: Color, ancho := -1.0, alin := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_tx.append([negrita, p, txt, tam, col, ancho, alin])


func _t_emitir() -> void:
	for pasada in 2:
		for t in _tx:
			if bool(t[0]) == (pasada == 1):
				draw_string(fuente_neg if pasada == 1 else fuente, t[1], t[2], t[6], t[5], t[3], t[4])
	_tx.clear()


## Franja de abajo con lo que significa cada color y cada línea (dos filas).
func _leyenda() -> void:
	var alto := 38.0
	var y0 := size.y - alto
	_g_rect(Rect2(0.0, y0, size.x, alto), Color(Tema.FONDO_ABAJO.r, Tema.FONDO_ABAJO.g, Tema.FONDO_ABAJO.b, 0.9))
	_g_rect(Rect2(0.0, y0, size.x, 1.0), Tema.ACERO_OSCURO)
	var x := 8.0
	var cy := y0 + 10.0
	var c_azul := Tema.color_rol("azul")
	var estados := [[Tema.TARJETA.lerp(Tema.OK, 0.38), Tema.OK, "Conocido"], [Tema.TARJETA.lerp(c_azul, 0.32), c_azul, "Disponible"],
		[Tema.TARJETA, Tema.ACERO_OSCURO, "Bloqueado"], [Tema.TARJETA.lerp(Tema.FONDO_ABAJO, 0.45), Tema.ACERO_OSCURO, "Aún lejano"]]
	for e in estados:
		var rc := Rect2(x, cy - 5.0, 14.0, 10.0)
		_g_rect(rc, e[0] as Color)
		_g_marco(rc, 1.5, e[1] as Color)
		x += 18.0
		_t(false, Vector2(x, cy + 4.0), String(e[2]), 11, Tema.TEXTO)
		x += fuente.get_string_size(String(e[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
	x = 8.0
	cy = y0 + 28.0
	_g_linea(Vector2(x, cy), Vector2(x + 22.0, cy), 1.6, Tema.TENUE)
	x += 26.0
	_t(false, Vector2(x, cy + 4.0), "hace falta", 11, Tema.TEXTO)
	x += fuente.get_string_size("hace falta", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
	for k in 3:
		_g_linea(Vector2(x + float(k) * 8.0, cy), Vector2(x + float(k) * 8.0 + 4.0, cy), 1.6, Tema.TENUE)
	x += 26.0
	_t(false, Vector2(x, cy + 4.0), "basta uno", 11, Tema.TEXTO)
	x += fuente.get_string_size("basta uno de varios", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
	_g_disco(Vector2(x + 6.0, cy), 6.0, Tema.NARANJA)
	_t(true, Vector2(x + 3.0, cy + 3.5), "2", 9, Color.WHITE)
	x += 16.0
	_t(false, Vector2(x, cy + 4.0), "otra sección", 11, Tema.TEXTO)
	x += fuente.get_string_size("otra sección", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
	_g_linea(Vector2(x, cy), Vector2(x + 18.0, cy), 3.0, Tema.ORO)
	x += 22.0
	_t(false, Vector2(x, cy + 4.0), "← requisitos", 11, Tema.TEXTO)
	x += fuente.get_string_size("← requisitos", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
	_g_linea(Vector2(x, cy), Vector2(x + 18.0, cy), 3.0, Tema.color_rol("violeta"))
	x += 22.0
	_t(false, Vector2(x, cy + 4.0), "abre →", 11, Tema.TEXTO)


func _globo(i: int) -> void:
	var e: int = int(_est.get(i, E_BLOQUEADO))
	var l1 := String(d.nombre[i])
	var l2 := "%s · %s" % [d.anio_texto(int(d.anio[i])), String(NOMBRE_ESTADO[e])]
	var w1 := fuente_neg.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var w2 := fuente.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var ancho := maxf(w1, w2) + 16.0
	var p := _raton + Vector2(16.0, 18.0)
	if p.x + ancho > size.x - 4.0:
		p.x = _raton.x - ancho - 10.0
	if p.y + 44.0 > size.y - 4.0:
		p.y = _raton.y - 52.0
	var rg := Rect2(p, Vector2(ancho, 40.0))
	_g_rect(rg, Tema.POPUP_ARRIBA)
	_g_marco(rg, 1.5, Tema.ORO)
	_t(true, p + Vector2(8.0, 16.0), l1, 13, Tema.TEXTO)
	_t(false, p + Vector2(8.0, 33.0), l2, 11, Tema.TENUE)


## Año compacto para la franja de columnas: 1769 → «1769», -44 → «44 a. C.», -10000 → «10 mil a. C.», -2600000 → «2,6 M a. C.».
func _anio_corto(a: int) -> String:
	if a >= 0:
		return str(a)
	var v := -a
	if v >= 1000000:
		return "%s M a. C." % ("%.1f" % (float(v) / 1000000.0)).replace(".", ",")
	if v >= 10000:
		return "%d mil a. C." % int(roundf(float(v) / 1000.0))
	return "%d a. C." % v
