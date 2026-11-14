extends Control
## ÁRBOL de UNA sección del catálogo de descubrimientos, que CRECE HACIA ARRIBA (0.1.8.43). Lo usa la pantalla de Descubrimientos.
##
## Cómo se ve (boceto de Camilo, 2026-11-13; los bocetos son «representativos y aproximados», no una cuadrícula):
##  · Un ABANICO CIRCULAR que sube desde abajo: la RAÍZ de la sección está abajo en el centro, cada ERA es un anillo que se abre hacia arriba
##    y cada subsección es una cuña del abanico. Cada descubrimiento queda más lejos de la raíz que lo que necesita: el árbol crece con las eras.
##  · Cada descubrimiento es un CÍRCULO sin texto; al pasar el ratón sale un globo con su nombre, año, estado, descripción, requisitos y lo que abre.
##  · Colores: BLOQUEADO negro · AÚN LEJANO gris · CONOCIDO verde · DISPONIBLE dorado (con brillo).
##  · Un TRAZO NARANJA que se difumina con una flecha (sin texto) = el camino continúa en OTRA sección (flecha hacia afuera: lo abre; hacia la raíz: lo necesita).
##    Pasar el ratón dice a dónde; pulsarlo lleva allí. (Camilo: «ETC» era «el resto del contenido que va después», no una cajita escrita en cada nodo.)
##  · Una línea que termina en una «T» = camino sin salida: no abre nada.
##  · Las líneas entre prerrequisitos son CURVAS (en polares: giran mientras se alejan de la raíz), no ángulos rectos.
##  · El tamaño del círculo crece con lo que abre; la marca de dentro dice el tipo (unidad, arma, edificio…). En el borde del abanico va el nombre de cada cuña
##    y, a la izquierda, el rango de años de cada anillo.
##  · Como el árbol de habilidades de Path of Exile 2 (Camilo: «aprovecha el espacio»): un LIENZO GRANDE y espacioso (círculos de 44–76 px a zoom 1),
##    zoom con la rueda de 4 % a 280 % hacia el cursor, arrastrar para moverse; al entrar la vista se centra en lo que el país puede investigar ya (zoom 90 %).
##    «Ver todo» encaja la sección entera; «Mi frontera» vuelve a lo disponible.
##
## Todo se dibuja en UN solo control con paneo (arrastrar) y zoom (rueda), en lotes (`lote_dibujo.gd`): cuesta lo mismo con 20 que con 100 nodos.
## No hay un nodo por descubrimiento. Se redibuja solo cuando algo cambia (mover, zoom, hover, elegir, un cambio de estado).

signal elegido(i: int)                  # clic sobre un círculo (-1 = clic en el vacío)
signal salto(i: int)                    # clic en un trazo naranja: ir a ese descubrimiento (de otra sección)

const LoteScript := preload("res://scripts/lote_dibujo.gd")

const SEP_NODO := 128.0                 # separación horizontal mínima entre centros de un mismo nivel y carril (0.1.8.43b: antes 56, el árbol iba comprimido)
const SEP_NIVEL := 176.0                # separación vertical entre niveles (antes 86)
const R_MIN := 22.0
const R_MAX := 38.0
const R_RAIZ := 360.0                   # radio del primer anillo (el de las raíces)
const HOLGURA_CUNA := 1.5               # holgura de cada cuña, en nodos
const ANGULO_MAX := 2.62                # abanico máximo: 150°, para que todo quede por encima de la raíz
const SUBFILA := 108.0                  # cuando un anillo está muy lleno sus nodos se reparten en hasta 3 sub-anillos pegados (en vez de abrir el abanico sin fin)
const MAX_SUBFILAS := 3
const LOD_MARCAS := 0.4                 # por debajo de este zoom no se dibujan los trazos hacia otras secciones (y las «T» desde el 70 % de esto)
const MARGEN_X := 260.0                 # a los lados caben los años de cada anillo y los nombres de las cuñas
const MARGEN_ARRIBA := 220.0            # por arriba sobresalen los trazos hacia otras secciones y las T
const MARGEN_ABAJO := 200.0             # por abajo, los trazos de entrada
const ZOOM_MIN := 0.04
const ZOOM_MAX := 2.8
const ZOOM_AJUSTE_MIN := 0.05
const ZOOM_INICIAL := 0.75              # zoom al entrar a una sección (o al pulsar «Mi frontera») cuando lo disponible cabe
const ZOOM_FRONTERA_MIN := 0.5          # y lo más lejos que llega ese encuadre aunque lo disponible esté muy repartido
const ZOOM_AL_ELEGIR := 0.7             # ir a un descubrimiento (búsqueda, otra sección) nunca lo deja más lejos que esto
const PASO_RUEDA := 1.16
const LETRA_NIVEL := 12
const LARGO_TRAZO := 66.0               # largo (px a zoom 1) del trazo naranja hacia otra sección

const E_BLOQUEADO := 0
const E_DISPONIBLE := 1
const E_CONOCIDO := 2
const E_LEJANO := 3                     # no lo conoce, no tiene los prerrequisitos y su año es posterior al reloj
const NOMBRE_ESTADO := ["Bloqueado", "Disponible", "Conocido", "Aún lejano"]

# Colores del árbol (propios: el ambiente de cada rama es de color oscuro y esto tiene que leerse sobre cualquiera)
const C_CONOCIDO := Color(0.28, 0.82, 0.42)
const C_DISPONIBLE := Color(1.0, 0.80, 0.24)
const C_NEGRO := Color(0.012, 0.012, 0.018)
const C_NEGRO_BORDE := Color(0.40, 0.42, 0.50)
const C_GRIS := Color(0.50, 0.51, 0.56)
const C_GRIS_BORDE := Color(0.74, 0.75, 0.80)
const C_ABRE := Color(0.72, 0.52, 1.0)          # lo que ESTE abre (violeta)
const C_PASTILLA := Color(0.95, 0.55, 0.20)
# Colores de texto y globo de TODA la pantalla de Descubrimientos: fijos y claros, porque el fondo siempre es oscuro (los del tema de la interfaz están pensados para papel claro)
const T_TEXTO := Color(0.96, 0.94, 0.88)
const T_ORO := Color(1.0, 0.84, 0.40)
const T_TENUE := Color(0.70, 0.73, 0.82)
const T_NOTA := Color(0.62, 0.74, 0.95)
const T_GLOBO_ARRIBA := Color(0.10, 0.11, 0.17)
const T_GLOBO_ABAJO := Color(0.05, 0.06, 0.10)

var d                                   # Descubrimientos
var fuente: Font
var fuente_neg: Font
var tid := -1                           # país cuyo estado se muestra (-1 = solo lo que sabe la historia)
var seccion := -1
var nodos := PackedInt32Array()         # índices de los descubrimientos de la sección
var pos := {}                           # índice -> Vector2 (CENTRO del círculo, en coordenadas del árbol)
var radio := {}                         # índice -> radio del círculo (coordenadas del árbol)
var nivel := {}                         # índice -> nivel (0 = raíz, abajo)
var aristas: Array = []                 # [{a, b, o, pts}]: a es prerrequisito de b; o = alternativa (basta uno)
var carriles: Array = []                # [{nombre, a0, a1, sub}] una CUÑA del abanico por subsección (ángulos en radianes, 0 = recto hacia arriba)
var ang := {}                           # índice -> ángulo del nodo respecto a la raíz (rad; + hacia la derecha)
var anillos := PackedFloat64Array()     # radio donde EMPIEZA cada nivel (distancia a la raíz)
var anillos_fin := PackedFloat64Array() # radio donde TERMINA cada nivel (si está muy lleno, ocupa hasta 3 sub-anillos)
var dist := {}                          # índice -> distancia del círculo a la raíz
var apex := Vector2.ZERO                # la raíz del abanico (abajo en el centro), en coordenadas del árbol
var abanico := 0.0                      # ángulo total del abanico (rad)
var niveles := 0
var niveles_anios: Array = []           # por nivel: [año menor, año mayor]
var pastillas: Array = []               # [{nodo, arriba, otros}]: trazo naranja hacia otra sección
var sin_salida := {}                    # índice -> true: no abre NADA en ningún lado (lleva una «T»)
var tam_arbol := Vector2.ZERO
var margen_izq := 0.0                   # franja de la izquierda que tapa la cinta de secciones (el árbol se ajusta al resto)
var zoom := 1.0
var margen_der := 0.0                   # franja de la derecha que tapa la ficha: al ir a un descubrimiento se centra en el resto
var origen := Vector2.ZERO              # dónde cae (0,0) del árbol en el control
var sel := -1
var hover := -1
var hover_pastilla := -1
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
var _lote := LoteScript.new()
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
# Distribución (hacia arriba)
# ─────────────────────────────────────────────────────────────
func fijar_seccion(s: int, ajustar_vista := true) -> void:
	seccion = s
	sel = -1
	hover = -1
	hover_pastilla = -1
	_foco = -1
	_prev.clear()
	_sig.clear()
	_distribuir()
	refrescar()
	if ajustar_vista:
		vista_inicial()


func _distribuir() -> void:
	nodos = PackedInt32Array()
	pos.clear()
	radio.clear()
	nivel.clear()
	ang.clear()
	aristas = []
	carriles = []
	niveles_anios = []
	pastillas = []
	anillos = PackedFloat64Array()
	anillos_fin = PackedFloat64Array()
	dist.clear()
	sin_salida.clear()
	niveles = 0
	tam_arbol = Vector2.ZERO
	apex = Vector2.ZERO
	abanico = 0.0
	if d == null or seccion < 0:
		return
	var en_sec := {}
	for i in d.n:
		if int(d.seccion[i]) == seccion:
			nodos.append(i)
			en_sec[i] = true
	# nivel de cada uno: 1 más que su prerrequisito más profundo DE LA MISMA SECCIÓN (así cada anillo está más lejos de la raíz que los de sus prerrequisitos)
	var prof := {}
	var visitando := {}
	for i in nodos:
		_profundidad(i, en_sec, prof, visitando)
	var maxp := 0
	for i in nodos:
		maxp = maxi(maxp, int(prof[i]))
		nivel[i] = int(prof[i])
	niveles = maxp + 1
	# subsecciones presentes = cuñas del abanico (la que no tiene, «General», primero)
	var subs: Array = []
	for i in nodos:
		var si: int = int(d.sub[i])
		if not subs.has(si):
			subs.append(si)
	subs.sort()
	# celdas (cuña, nivel): nodos por año
	var celdas := {}
	for i in nodos:
		var clave := Vector2i(int(d.sub[i]), int(prof[i]))
		if not celdas.has(clave):
			celdas[clave] = []
		(celdas[clave] as Array).append(i)
	for clave in celdas:
		(celdas[clave] as Array).sort_custom(func(a: int, b: int) -> bool: return d.anio[a] < d.anio[b] or (d.anio[a] == d.anio[b] and a < b))
	# ancho angular de cada cuña ∝ lo que pide su celda más llena; el abanico crece con el total (de 63° en secciones chicas a 150°)
	var pesos := {}
	var suma_pesos := 0.0
	for si in subs:
		var max_n := 1
		for c in niveles:
			var k := Vector2i(int(si), c)
			if celdas.has(k):
				max_n = maxi(max_n, (celdas[k] as Array).size())
		pesos[int(si)] = float(max_n) + HOLGURA_CUNA
		suma_pesos += float(pesos[int(si)])
	abanico = clampf(0.9 + 0.045 * suma_pesos, 1.1, ANGULO_MAX)
	var cuna := {}
	var th := -abanico * 0.5
	for si in subs:
		var a_w := abanico * float(pesos[int(si)]) / suma_pesos
		cuna[int(si)] = [th, th + a_w]
		var nombre_c := "General" if int(si) < 0 else String(d.subsecciones[int(si)])
		carriles.append({"nombre": nombre_c, "a0": th, "a1": th + a_w, "sub": int(si)})
		th += a_w
	# radios de los círculos según lo que cada uno abre
	for i in nodos:
		var n_dep: int = (d.dependientes[i] as PackedInt32Array).size()
		radio[i] = clampf(R_MIN + sqrt(float(n_dep)) * 4.0, R_MIN, R_MAX)
	# radio de cada anillo: lo bastante lejos del anterior y lo bastante largo para que su celda más llena quepa en su cuña; si no cabe en una fila,
	# los nodos se reparten en hasta MAX_SUBFILAS sub-anillos (se elige lo que deje el árbol más compacto)
	var r_ini_nivel := R_RAIZ
	for c in niveles:
		var mejor_k := 1
		var mejor_r := 0.0
		var mejor_ext := 1.0e18
		for k_f in range(1, MAX_SUBFILAS + 1):
			var r_k := r_ini_nivel
			for si in subs:
				var kk := Vector2i(int(si), c)
				if celdas.has(kk):
					var cu0: Array = cuna[int(si)]
					var por_fila := ceili(float((celdas[kk] as Array).size()) / float(k_f))
					r_k = maxf(r_k, (float(por_fila) + 0.3) * SEP_NODO / (float(cu0[1]) - float(cu0[0])))
			var ext := r_k + float(k_f - 1) * SUBFILA
			if ext < mejor_ext - 0.5:
				mejor_ext = ext
				mejor_k = k_f
				mejor_r = r_k
		anillos.append(mejor_r)
		anillos_fin.append(mejor_r + float(mejor_k - 1) * SUBFILA)
		# ángulos de este nivel, cuña a cuña: cada nodo busca quedar en el ángulo medio de lo que lo une (baricentro) y se separa de sus vecinos (SEP_NODO sobre su fila)
		for si2 in subs:
			var k2 := Vector2i(int(si2), c)
			if not celdas.has(k2):
				continue
			var lista: Array = celdas[k2]
			var cu: Array = cuna[int(si2)]
			var a_cuna: float = float(cu[1]) - float(cu[0])
			var capacidad := maxi(1, int(floor((a_cuna * mejor_r - SEP_NODO * 1.1) / SEP_NODO)) + 1)
			var filas := clampi(ceili(float(lista.size()) / float(capacidad)), 1, mejor_k)
			var deseados := []                                       # [ángulo deseado, índice]
			for i in lista:
				var suma := 0.0
				var cuenta := 0
				for r in _prerrequisitos(int(i)):
					if ang.has(int(r)):
						suma += float(ang[int(r)])
						cuenta += 1
				deseados.append([suma / float(cuenta) if cuenta > 0 else (float(cu[0]) + float(cu[1])) * 0.5, int(i)])
			deseados.sort_custom(func(a: Array, b: Array) -> bool:
				if float(a[0]) != float(b[0]):
					return float(a[0]) < float(b[0])
				if d.anio[int(a[1])] != d.anio[int(b[1])]:
					return d.anio[int(a[1])] < d.anio[int(b[1])]
				return int(a[1]) < int(b[1]))
			for fila in filas:
				var grupo := []                                      # los nodos de esta sub-fila, a su radio, en arco (ángulo × radio) para separarlos
				var r_fila := mejor_r + float(fila) * SUBFILA
				for j in range(fila, deseados.size(), filas):
					grupo.append([float((deseados[j] as Array)[0]) * r_fila, int((deseados[j] as Array)[1])])
				var ss := _separar(grupo, float(cu[0]) * r_fila + SEP_NODO * 0.55, float(cu[1]) * r_fila - SEP_NODO * 0.55)
				for j2 in grupo.size():
					var nid: int = int((grupo[j2] as Array)[1])
					ang[nid] = ss[j2] / r_fila
					dist[nid] = r_fila
		r_ini_nivel = mejor_r + float(mejor_k - 1) * SUBFILA + SEP_NIVEL
	# posiciones (con la raíz en el origen; luego se desplaza todo para que el árbol quede en coordenadas positivas)
	var caja := Rect2(Vector2.ZERO, Vector2.ZERO)
	var r_ult: float = anillos_fin[niveles - 1]
	for i in nodos:
		var p := _polar(float(ang[i]), float(dist[i]))
		pos[i] = p
		var rr: float = radio[i]
		caja = caja.expand(p - Vector2(rr, rr) - Vector2(30.0, 30.0)).expand(p + Vector2(rr, rr) + Vector2(30.0, 30.0))
	for cr in carriles:                                                  # el borde del abanico: nombres de las cuñas
		for aa in [float(cr["a0"]), float(cr["a1"]), (float(cr["a0"]) + float(cr["a1"])) * 0.5]:
			caja = caja.expand(_polar(float(aa), r_ult + 140.0))
	caja = caja.expand(Vector2(-160.0, 230.0)).expand(Vector2(160.0, 230.0))        # el cubo de la raíz y su título
	var desp := Vector2(MARGEN_X, MARGEN_ARRIBA) - caja.position
	apex = desp
	for i in nodos:
		pos[i] = (pos[i] as Vector2) + desp
	tam_arbol = caja.size + Vector2(MARGEN_X * 2.0, MARGEN_ARRIBA + MARGEN_ABAJO)
	# años de cada nivel (en el borde izquierdo de cada anillo)
	for c in niveles:
		niveles_anios.append([2147483647, -2147483647])
	for i in nodos:
		var par: Array = niveles_anios[int(prof[i])]
		par[0] = mini(int(par[0]), int(d.anio[i]))
		par[1] = maxi(int(par[1]), int(d.anio[i]))
	# aristas y trazos hacia otras secciones / «T»
	for i in nodos:
		var fuera_req := PackedInt32Array()
		for r in d.req[i]:
			if en_sec.has(int(r)):
				_arista(int(r), i, false)
			else:
				fuera_req.append(int(r))
		for g in d.req_o[i]:
			for r2 in g:
				if en_sec.has(int(r2)):
					_arista(int(r2), i, true)
				else:
					fuera_req.append(int(r2))
		var fuera_dep := PackedInt32Array()
		for h in (d.dependientes[i] as PackedInt32Array):
			if not en_sec.has(int(h)):
				fuera_dep.append(int(h))
		if (d.dependientes[i] as PackedInt32Array).is_empty():
			sin_salida[i] = true
		if not fuera_dep.is_empty():
			pastillas.append({"nodo": i, "arriba": true, "otros": fuera_dep})
		if not fuera_req.is_empty():
			pastillas.append({"nodo": i, "arriba": false, "otros": fuera_req})


## Punto a `r` de la raíz con ángulo `a` (0 = recto hacia arriba, + hacia la derecha), con la raíz en el origen.
func _polar(a: float, r: float) -> Vector2:
	return Vector2(sin(a), -cos(a)) * r


## Los prerrequisitos de `i` (los obligatorios y todas las alternativas), de cualquier sección.
func _prerrequisitos(i: int) -> PackedInt32Array:
	var r := PackedInt32Array(d.req[i])
	for g in d.req_o[i]:
		r.append_array(g)
	return r


func _profundidad(i: int, en_sec: Dictionary, prof: Dictionary, visitando: Dictionary) -> int:
	if prof.has(i):
		return int(prof[i])
	if visitando.has(i):
		return 0                                           # ciclo (no debería haberlos): se corta
	visitando[i] = true
	var m := 0
	for r in _prerrequisitos(i):
		if en_sec.has(int(r)):
			m = maxi(m, _profundidad(int(r), en_sec, prof, visitando) + 1)
	visitando.erase(i)
	prof[i] = m
	return m


## Reparte las x de una fila de nodos (ordenados por su x deseada) para que haya al menos SEP_NODO entre ellos y se alejen lo mínimo de lo deseado
## (regresión isotónica sobre x − k·SEP) dentro de [lo, hi]. Devuelve las x en el mismo orden.
func _separar(deseados: Array, lo: float, hi: float) -> PackedFloat64Array:
	var n := deseados.size()
	var bloques: Array = []                                   # [suma, cuenta]
	for k in n:
		bloques.append([float((deseados[k] as Array)[0]) - float(k) * SEP_NODO, 1])
		while bloques.size() >= 2:
			var b1: Array = bloques[bloques.size() - 1]
			var b0: Array = bloques[bloques.size() - 2]
			if float(b0[0]) / float(b0[1]) <= float(b1[0]) / float(b1[1]):
				break
			bloques.pop_back()
			b0[0] = float(b0[0]) + float(b1[0])
			b0[1] = int(b0[1]) + int(b1[1])
	var xs := PackedFloat64Array()
	var k2 := 0
	var y_lo := lo                                              # en el espacio y = x − k·SEP los límites son los mismos para todos: [lo, hi − (n−1)·SEP]
	var y_hi := maxf(lo, hi - float(n - 1) * SEP_NODO)
	for b in bloques:
		var media := clampf(float(b[0]) / float(b[1]), y_lo, y_hi)   # recortar la solución isotónica a la caja sigue siendo la óptima
		for _j in int(b[1]):
			xs.append(media + float(k2) * SEP_NODO)
			k2 += 1
	return xs


func _arista(a: int, b: int, alternativa: bool) -> void:
	for ar in aristas:
		if int(ar["a"]) == a and int(ar["b"]) == b:
			if not alternativa:
				ar["o"] = false                            # si está en `req` y en un grupo, manda «hace falta»
			return
	var ra: float = dist[a]
	var rb: float = dist[b]
	var ta: float = ang[a]
	var tb: float = ang[b]
	var largo := absf(rb - ra) + absf(tb - ta) * (ra + rb) * 0.5
	var tramos := clampi(int(largo / 16.0), 10, 96)
	var pts := PackedVector2Array()
	var caja := Rect2(pos[a], Vector2.ZERO)
	for k in tramos + 1:
		var t := float(k) / float(tramos)
		var sm := t * t * (3.0 - 2.0 * t)
		var pk := apex + _polar(lerpf(ta, tb, sm), lerpf(ra, rb, t))          # en polares: gira mientras se aleja de la raíz
		pts.append(pk)
		caja = caja.expand(pk)
	aristas.append({"a": a, "b": b, "o": alternativa, "pts": pts, "caja": caja})


# ─────────────────────────────────────────────────────────────
# Vista
# ─────────────────────────────────────────────────────────────
## «Ver todo»: encaja el árbol entero en el control (sin pasar de zoom 1 ni bajar de `ZOOM_AJUSTE_MIN`) con las RAÍCES pegadas abajo.
func ajustar() -> void:
	if tam_arbol.x <= 0.0 or size.x <= 0.0:
		return
	var ancho_util := maxf(size.x - margen_izq, 100.0)
	zoom = clampf(minf(ancho_util / tam_arbol.x, size.y / tam_arbol.y), ZOOM_AJUSTE_MIN, 1.0)
	origen = Vector2(margen_izq + (ancho_util - tam_arbol.x * zoom) * 0.5, size.y - tam_arbol.y * zoom)
	_limitar()
	queue_redraw()


## Vista al entrar a la sección (y botón «Mi frontera»): centrada en lo que el país puede investigar ya (los dorados); si no hay, en lo último que conoce; si no hay ni eso, la sección entera.
## Zoom `ZOOM_INICIAL` (los círculos se ven grandes y con aire, como en el árbol de Path of Exile 2); baja hasta `ZOOM_FRONTERA_MIN` si lo disponible está muy repartido.
func vista_inicial() -> void:
	if tam_arbol.x <= 0.0 or size.x <= 0.0 or nodos.is_empty():
		return
	var cand: Array = []
	for i in nodos:
		if int(_est.get(i, E_BLOQUEADO)) == E_DISPONIBLE:
			cand.append(i)
	if cand.is_empty():
		var tope := -1
		for i in nodos:
			if int(_est.get(i, E_BLOQUEADO)) == E_CONOCIDO:
				tope = maxi(tope, int(nivel[i]))
		for i in nodos:
			if tope >= 0 and int(_est.get(i, E_BLOQUEADO)) == E_CONOCIDO and int(nivel[i]) == tope:
				cand.append(i)
	if cand.is_empty():                                                  # no hay nada disponible ni conocido: lo útil es ver la sección entera desde su raíz
		ajustar()
		return
	var caja := Rect2(pos[cand[0]], Vector2.ZERO)
	for i in cand:
		caja = caja.expand(pos[i])
	caja = caja.grow(260.0)
	var ancho_util := maxf(size.x - margen_izq, 100.0)
	zoom = clampf(minf(ancho_util / caja.size.x, size.y / caja.size.y), ZOOM_FRONTERA_MIN, ZOOM_INICIAL)
	origen = Vector2(margen_izq + ancho_util * 0.5, size.y * 0.5) - caja.get_center() * zoom
	_limitar()
	queue_redraw()


## Lleva el nodo `i` al centro de la vista (sin la ficha de la derecha) y lo elige. Si el zoom estaba muy lejos, se acerca a `ZOOM_AL_ELEGIR`.
func elegir(i: int, centrar := true) -> void:
	sel = i
	_actualizar_foco()
	if centrar and pos.has(i):
		zoom = maxf(zoom, ZOOM_AL_ELEGIR)
		var ancho_util := maxf(size.x - margen_izq - margen_der, 100.0)
		origen = Vector2(margen_izq + ancho_util * 0.5, size.y * 0.5) - (pos[i] as Vector2) * zoom
		_limitar()
	queue_redraw()


## El árbol se puede arrastrar hasta que su borde llegue a la mitad de la vista (en un lienzo tan grande hay que poder llevar cualquier zona al centro).
func _limitar() -> void:
	var w := tam_arbol.x * zoom
	var h := tam_arbol.y * zoom
	var mx := size.x * 0.5
	var my := size.y * 0.5
	origen = Vector2(clampf(origen.x, size.x - w - mx, mx), clampf(origen.y, size.y - h - my, my))


func _acercar(factor: float, en: Vector2) -> void:
	var nz := clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(nz, zoom):
		return
	origen = en - (en - origen) * (nz / zoom)
	zoom = nz
	_limitar()
	queue_redraw()


func _a_pantalla(p: Vector2) -> Vector2:
	return origen + p * zoom


func _radio_px(i: int) -> float:
	return maxf(float(radio[i]) * zoom, 4.0)


func _nodo_en(p: Vector2) -> int:
	var mejor := -1
	var mejor_d := 1.0e12
	for i in nodos:
		var c := _a_pantalla(pos[i])
		var dd := c.distance_squared_to(p)
		var r := _radio_px(i) + 3.0
		if dd <= r * r and dd < mejor_d:
			mejor = i
			mejor_d = dd
	return mejor


## Escala del trazo hacia otra sección: se encoge un poco al alejar el zoom (si no, se montan unos sobre otros) y crece un poco al acercar.
func _escala_pastilla() -> float:
	return clampf(zoom * 1.1, 0.6, 1.25)


## Dirección «hacia afuera» (alejándose de la raíz) del nodo `i`, en pantalla.
func _sentido_afuera(i: int) -> Vector2:
	return Vector2(sin(float(ang[i])), -cos(float(ang[i])))


## Los dos extremos del trazo `k` en pantalla (sale del borde del círculo; hacia afuera si el nodo abre algo de otra sección, hacia la raíz si lo necesita) y su dirección.
func _trazo_puntos(k: int) -> Array:
	var pa: Dictionary = pastillas[k]
	var i: int = pa["nodo"]
	var c := _a_pantalla(pos[i])
	var r := _radio_px(i)
	var dir := _sentido_afuera(i).rotated(0.32) if bool(pa["arriba"]) else (-_sentido_afuera(i)).rotated(0.32)
	var a := c + dir * (r + 4.0)
	return [a, a + dir * LARGO_TRAZO * _escala_pastilla(), dir]


## Zona sensible del trazo `k` (para el ratón): un cuadrado en medio del trazo.
func _rect_pastilla(k: int) -> Rect2:
	var t: Array = _trazo_puntos(k)
	var med: Vector2 = ((t[0] as Vector2) + (t[1] as Vector2)) * 0.5
	var tam := Vector2(34.0, 34.0) * _escala_pastilla()
	return Rect2(med - tam * 0.5, tam)


func _pastilla_en(p: Vector2) -> int:
	for k in pastillas.size():
		if _rect_pastilla(k).grow(2.0).has_point(p):
			return k
	return -1


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_acercar(PASO_RUEDA, mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_acercar(1.0 / PASO_RUEDA, mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_arrastrando = true
				_movido = false
				_p_ini = mb.position
			else:
				if _arrastrando and not _movido:
					var kp := _pastilla_en(mb.position)
					if kp >= 0:
						var otros: PackedInt32Array = pastillas[kp]["otros"]
						salto.emit(int(otros[0]))
					else:
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
			var kp2 := _pastilla_en(mm.position)
			var h2 := _nodo_en(mm.position) if kp2 < 0 else -1
			if h2 != hover or kp2 != hover_pastilla:
				hover = h2
				hover_pastilla = kp2
				_actualizar_foco()
				queue_redraw()
			elif hover >= 0 or hover_pastilla >= 0:
				queue_redraw()                              # el globo de información sigue al ratón
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (hover >= 0 or hover_pastilla >= 0) else Control.CURSOR_DRAG


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and (hover != -1 or hover_pastilla != -1) and not _arrastrando:
		hover = -1
		hover_pastilla = -1
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
		for r in _prerrequisitos(i):
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
## Colores de relleno y de borde de un círculo según su estado.
func _colores_estado(e: int) -> Array:
	match e:
		E_CONOCIDO:
			return [C_CONOCIDO, C_CONOCIDO.lightened(0.45)]
		E_DISPONIBLE:
			return [C_DISPONIBLE, C_DISPONIBLE.lightened(0.5)]
		E_LEJANO:
			return [C_GRIS, C_GRIS_BORDE]
	return [C_NEGRO, C_NEGRO_BORDE]


func _draw() -> void:
	dibujos += 1
	nodos_dibujados = 0
	_lote.limpiar()
	_tx.clear()
	if d == null or nodos.is_empty():
		return
	_lote.base(Vector2.ZERO, 1.0)
	var z := zoom
	var vista := Rect2(Vector2.ZERO, size)
	var vis_arbol := Rect2((-origen) / z, size / z).grow(60.0)
	var hay_foco := _foco >= 0
	var sp := clampf(z, 0.75, 1.4)                                       # escala de puntas, «T» y trazos: crecen un poco al acercar, no se pierden al alejar
	var r_borde: float = float(anillos_fin[niveles - 1]) + 100.0
	var r_ini: float = float(anillos[0]) * 0.5
	_lote.base(origen, z)                                                # lo que sigue está en coordenadas del árbol
	# cuñas: una banda en forma de abanico por subsección (alternan de tono) y un filete radial entre ellas
	for c in carriles.size():
		var cr: Dictionary = carriles[c]
		var a0: float = cr["a0"]
		var a1: float = cr["a1"]
		var pasos := clampi(int((a1 - a0) * r_borde / 150.0), 3, 48)
		var col_b := Color(1.0, 1.0, 1.0, 0.04 if c % 2 == 0 else 0.016)
		var visible_c := false
		var p_ant_i := apex + _polar(a0, r_ini)
		var p_ant_o := apex + _polar(a0, r_borde)
		for k in pasos:
			var ak := lerpf(a0, a1, float(k + 1) / float(pasos))
			var p_i := apex + _polar(ak, r_ini)
			var p_o := apex + _polar(ak, r_borde)
			if vis_arbol.intersects(Rect2(p_ant_i, p_o - p_ant_i).abs().merge(Rect2(p_ant_o, p_i - p_ant_o).abs())):
				_lote.cuadrilatero(p_ant_i, p_ant_o, p_o, p_i, col_b)
				visible_c = true
			p_ant_i = p_i
			p_ant_o = p_o
		if visible_c:
			_lote.linea(apex + _polar(a0, r_ini), apex + _polar(a0, r_borde), 1.0 / z, Color(1.0, 1.0, 1.0, 0.06))
	_lote.linea(apex + _polar(abanico * 0.5, r_ini), apex + _polar(abanico * 0.5, r_borde), 1.0 / z, Color(1.0, 1.0, 1.0, 0.06))
	# anillos: una guía tenue por nivel (la era), de un borde del abanico al otro
	var th_i := -abanico * 0.5 - 0.03
	var th_f := abanico * 0.5 + 0.03
	for c2 in niveles:
		var rr: float = anillos[c2]
		var pasos2 := clampi(int(abanico * rr / 90.0), 10, 160)
		var arco := PackedVector2Array()
		for k in pasos2 + 1:
			arco.append(apex + _polar(lerpf(th_i, th_f, float(k) / float(pasos2)), rr))
		_lote.tira(arco, 1.2 / z, Color(1.0, 1.0, 1.0, 0.06))
	# el tronco: de la raíz a un cruce por cuña y de ahí a cada descubrimiento de nivel 0 (así no sale un abanico de rayas)
	var por_cuna := {}                                                   # sub -> [suma de ángulos, cuenta]
	for i0n in nodos:
		if int(nivel[i0n]) == 0:
			var kc: int = int(d.sub[i0n])
			if not por_cuna.has(kc):
				por_cuna[kc] = [0.0, 0]
			por_cuna[kc][0] = float(por_cuna[kc][0]) + float(ang[i0n])
			por_cuna[kc][1] = int(por_cuna[kc][1]) + 1
	var cruce := {}
	for kc2 in por_cuna:
		var am0: float = float(por_cuna[kc2][0]) / float(por_cuna[kc2][1])
		cruce[kc2] = apex + _polar(am0, float(anillos[0]) * 0.55)
		_lote.linea(apex, cruce[kc2], 3.0 / z, Color(1.0, 0.84, 0.4, 0.26))
	for i0m in nodos:
		if int(nivel[i0m]) == 0:
			_lote.linea(cruce[int(d.sub[i0m])], pos[i0m], 1.6 / z, Color(1.0, 0.84, 0.4, 0.16))
	# líneas entre prerrequisitos (el grosor es fijo en píxeles)
	for ar in aristas:
		var a: int = ar["a"]
		var b: int = ar["b"]
		if not vis_arbol.intersects(ar["caja"] as Rect2):
			continue
		var pts: PackedVector2Array = ar["pts"]
		var col: Color
		var ancho := 2.2
		if hay_foco and (a == _foco or _prev.has(a)) and (b == _foco or _prev.has(b)):
			col = T_ORO
			ancho = 3.6
		elif hay_foco and (b == _foco or _sig.has(b)) and (a == _foco or _sig.has(a)):
			col = C_ABRE
			ancho = 3.6
		elif hay_foco:
			col = Color(1.0, 1.0, 1.0, 0.07)
		elif int(_est.get(a, 0)) == E_CONOCIDO:
			col = Color(C_CONOCIDO.r, C_CONOCIDO.g, C_CONOCIDO.b, 0.7)
		else:
			col = Color(1.0, 1.0, 1.0, 0.26)
		_lote.tira(pts, (ancho + 2.4) / z, Color(col.r, col.g, col.b, col.a * 0.25), bool(ar["o"]))     # halo suave (la malla no tiene suavizado propio)
		_lote.tira(pts, ancho / z, col, bool(ar["o"]))
	_lote.base(Vector2.ZERO, 1.0)
	for ar2 in aristas:                                                  # punta de flecha: llega al círculo del nodo de más afuera, en la dirección de la curva
		if not vis_arbol.intersects(ar2["caja"] as Rect2):
			continue
		var pts2: PackedVector2Array = ar2["pts"]
		var b2: int = ar2["b"]
		var a2: int = ar2["a"]
		var tg := (pts2[pts2.size() - 1] - pts2[pts2.size() - 2]).normalized()
		var col2: Color
		if hay_foco and (a2 == _foco or _prev.has(a2)) and (b2 == _foco or _prev.has(b2)):
			col2 = T_ORO
		elif hay_foco and (b2 == _foco or _sig.has(b2)) and (a2 == _foco or _sig.has(a2)):
			col2 = C_ABRE
		elif hay_foco:
			col2 = Color(1.0, 1.0, 1.0, 0.07)
		elif int(_est.get(a2, 0)) == E_CONOCIDO:
			col2 = Color(C_CONOCIDO.r, C_CONOCIDO.g, C_CONOCIDO.b, 0.7)
		else:
			col2 = Color(1.0, 1.0, 1.0, 0.26)
		var pf := _a_pantalla(pos[b2]) - tg * (float(radio[b2]) * z + 2.0)
		var nv := Vector2(-tg.y, tg.x)
		_lote.triangulo(pf, pf - tg * 9.5 * sp + nv * 5.5 * sp, pf - tg * 9.5 * sp - nv * 5.5 * sp, col2)
	# marcas de «T» (camino sin salida): un palito hacia afuera con una barra al final
	for i in nodos:
		if not sin_salida.has(i) or z < LOD_MARCAS * 0.7:
			continue
		var c_t := _a_pantalla(pos[i])
		if not vista.grow(60.0).has_point(c_t):
			continue
		var r_t := _radio_px(i)
		var col_t := Color(1.0, 1.0, 1.0, 0.16 if (hay_foco and i != _foco) else 0.6)
		var af := _sentido_afuera(i)
		var t0 := c_t + af * (r_t + 2.0)
		var t1 := c_t + af * (r_t + 2.0 + 26.0 * sp)
		var nt := Vector2(-af.y, af.x)
		_lote.linea(t0, t1, 2.4, col_t)
		_lote.linea(t1 - nt * 11.0 * sp, t1 + nt * 11.0 * sp, 3.6, col_t)
	# trazos naranjas hacia otras secciones (sin texto: pasar el ratón dice a dónde)
	for k in pastillas.size() if z >= LOD_MARCAS else 0:                 # muy alejado los trazos solo estorban: se ven desde zoom LOD_MARCAS
		var tr: Array = _trazo_puntos(k)
		var ta: Vector2 = tr[0]
		var tb: Vector2 = tr[1]
		if not vista.grow(80.0).intersects(Rect2(ta, tb - ta).abs()):
			continue
		var ni: int = (pastillas[k] as Dictionary)["nodo"]
		var atenuada := hay_foco and ni != _foco and hover_pastilla != k
		var alfa_t := 0.28 if atenuada else (1.0 if hover_pastilla == k else 0.9)
		_dibujar_trazo(ta, tb, tr[2], bool((pastillas[k] as Dictionary)["arriba"]), alfa_t, 3.4 if hover_pastilla == k else 2.4, _escala_pastilla())
	# la raíz: un cubo dorado abajo en el centro
	var ap := _a_pantalla(apex)
	var r_hub := clampf(54.0 * z, 12.0, 70.0)
	if vista.grow(r_hub + 60.0).has_point(ap):
		_lote.disco_radial(ap, r_hub * 2.6, Color(1.0, 0.84, 0.4, 0.28), Color(1.0, 0.84, 0.4, 0.0), 32)
		_lote.disco(ap, r_hub + 3.0, T_ORO, 36)
		_lote.disco(ap, r_hub, Color(0.07, 0.06, 0.05, 1.0), 36)
		_lote.disco(ap, r_hub * 0.45, Color(1.0, 0.84, 0.4, 0.85), 24)
	# círculos
	for i2 in nodos:
		var c := _a_pantalla(pos[i2])
		var r := _radio_px(i2)
		if not vista.grow(r + 30.0).has_point(c):
			continue
		nodos_dibujados += 1
		var e: int = int(_est.get(i2, E_BLOQUEADO))
		var atenuado := (hay_foco and i2 != _foco and not _prev.has(i2) and not _sig.has(i2)) or not _pasa_filtro(i2)
		var cols := _colores_estado(e)
		var relleno: Color = cols[0]
		var borde: Color = cols[1]
		var alfa := 0.22 if atenuado else 1.0
		if e == E_DISPONIBLE and not atenuado:                       # brillo dorado alrededor de lo que se puede investigar ya
			_lote.disco_radial(c, r * 2.4, Color(C_DISPONIBLE.r, C_DISPONIBLE.g, C_DISPONIBLE.b, 0.38), Color(C_DISPONIBLE.r, C_DISPONIBLE.g, C_DISPONIBLE.b, 0.0), 28)
		elif e == E_CONOCIDO and not atenuado:
			_lote.disco_radial(c, r * 1.8, Color(C_CONOCIDO.r, C_CONOCIDO.g, C_CONOCIDO.b, 0.20), Color(C_CONOCIDO.r, C_CONOCIDO.g, C_CONOCIDO.b, 0.0), 24)
		relleno.a = relleno.a * alfa
		borde.a = borde.a * (0.35 if atenuado else 1.0)
		var segm := 28 if r > 22.0 else (20 if r > 9.0 else 14)
		var grosor_borde := clampf(r * 0.12, 2.0, 4.5)
		if i2 == _foco:
			_lote.disco(c, r + grosor_borde + 4.0, Color(1.0, 1.0, 1.0, 0.95), 32)
		elif _prev.has(i2) and hay_foco:
			_lote.disco(c, r + grosor_borde + 3.0, T_ORO, 28)
		elif _sig.has(i2) and hay_foco:
			_lote.disco(c, r + grosor_borde + 3.0, C_ABRE, 28)
		_lote.disco(c, r + grosor_borde, borde, segm)
		_lote.disco(c, r, relleno, segm)
		_marca_tipo(c, r, String(d.tipo[i2]), relleno, atenuado)
	# textos: título de la raíz, años de cada anillo (borde izquierdo del abanico) y nombre de cada cuña (borde de afuera)
	if vista.grow(r_hub + 200.0).has_point(ap):
		var nombre_sec := String(d.secciones[seccion]["nombre"]).to_upper()
		_t(true, Vector2(ap.x - 170.0, ap.y + r_hub + 28.0), _recortar(fuente_neg, nombre_sec, 15, 340.0), 15, T_ORO, 340.0, HORIZONTAL_ALIGNMENT_CENTER)
	var y_ant := 1.0e9
	for c4 in range(niveles - 1, -1, -1):                                # de afuera hacia la raíz; si dos años quedan a menos de 17 px se omite el más cercano a la raíz
		var pl := _a_pantalla(apex + _polar(-abanico * 0.5, float(anillos[c4])))
		if not vista.grow(40.0).has_point(pl) or absf(pl.y - y_ant) < 17.0:
			continue
		y_ant = pl.y
		var par: Array = niveles_anios[c4]
		var txt := _anio_corto(int(par[0]))
		if int(par[1]) != int(par[0]):
			txt += " – " + _anio_corto(int(par[1]))
		_t(false, Vector2(pl.x - 238.0, pl.y + 4.0), txt, LETRA_NIVEL, Color(1.0, 1.0, 1.0, 0.7), 226.0, HORIZONTAL_ALIGNMENT_RIGHT)
	for c3 in carriles.size():
		var cr3: Dictionary = carriles[c3]
		var am: float = (float(cr3["a0"]) + float(cr3["a1"])) * 0.5
		var pn := _a_pantalla(apex + _polar(am, r_borde + 40.0))
		var anch := (float(cr3["a1"]) - float(cr3["a0"])) * (r_borde + 40.0) * z - 10.0
		if not vista.grow(40.0).has_point(pn) or anch < 80.0:
			continue
		var anch_t := minf(anch, 260.0)
		_t(true, Vector2(pn.x - anch_t * 0.5, pn.y), _recortar(fuente_neg, String(cr3["nombre"]), 13, anch_t), 13, Color(1.0, 1.0, 1.0, 0.82), anch_t, HORIZONTAL_ALIGNMENT_CENTER)
	_leyenda()
	_lote.emitir(self)
	_t_emitir()
	# globo de información
	if hover >= 0 and not _arrastrando:
		_globo_nodo(hover)
	elif hover_pastilla >= 0 and not _arrastrando:
		_globo_pastilla(hover_pastilla)
	_lote.emitir(self)
	_t_emitir()


## Trazo naranja que sale de un círculo hacia otra sección: se difumina y lleva una flecha a la mitad (hacia afuera = abre algo allá; hacia la raíz = lo necesita de allá).
func _dibujar_trazo(a: Vector2, b: Vector2, dir: Vector2, hacia_afuera: bool, alfa: float, ancho: float, es: float) -> void:
	var col := C_PASTILLA
	for k in 6:
		var t0 := float(k) / 6.0
		var t1 := float(k + 1) / 6.0
		_lote.linea(a.lerp(b, t0), a.lerp(b, t1), ancho, Color(col.r, col.g, col.b, alfa * (1.0 - t0 * 0.92)))
	var sentido := dir if hacia_afuera else -dir
	var mid := a.lerp(b, 0.5)
	var perp := Vector2(-sentido.y, sentido.x)
	_lote.triangulo(mid + sentido * 8.0 * es, mid - sentido * 5.0 * es + perp * 7.0 * es, mid - sentido * 5.0 * es - perp * 7.0 * es, Color(col.r, col.g, col.b, alfa * 0.85))
	_lote.disco(a, 3.2 * es, Color(col.r, col.g, col.b, alfa), 10)


## Leyenda arriba a la izquierda: los cuatro colores, el trazo hacia otra sección, la «T» y cómo moverse.
func _leyenda() -> void:
	var x0 := margen_izq + 70.0                                  # arriba a la izquierda: abajo a la izquierda están las raíces, lo primero que se mira
	var y0 := 16.0
	var panel := Rect2(x0 - 8.0, y0 - 8.0, 468.0, 76.0)
	_lote.rectangulo(panel, Color(0.0, 0.0, 0.0, 0.5))
	_lote.marco(panel, 1.0, Color(1.0, 1.0, 1.0, 0.14))
	var x := x0 + 8.0
	var estados := [[E_BLOQUEADO, "Bloqueado"], [E_LEJANO, "Aún lejano"], [E_CONOCIDO, "Conocido"], [E_DISPONIBLE, "Disponible"]]
	for e in estados:
		var cols := _colores_estado(int(e[0]))
		_lote.disco(Vector2(x, y0 + 8.0), 8.0, cols[1] as Color, 14)
		_lote.disco(Vector2(x, y0 + 8.0), 6.2, cols[0] as Color, 14)
		_t(false, Vector2(x + 13.0, y0 + 12.0), String(e[1]), 12, T_TEXTO)
		x += 36.0 + fuente.get_string_size(String(e[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var y1 := y0 + 32.0
	_dibujar_trazo(Vector2(x0 + 2.0, y1 + 6.0), Vector2(x0 + 34.0, y1 - 6.0), Vector2(1.0, -0.37).normalized(), true, 1.0, 2.4, 0.85)
	_t(false, Vector2(x0 + 44.0, y1 + 4.0), "sigue en otra sección", 12, T_TEXTO)
	var xt := x0 + 218.0
	_lote.rectangulo(Rect2(xt + 8.0, y1 - 7.0, 2.0, 14.0), Color(1.0, 1.0, 1.0, 0.7))
	_lote.rectangulo(Rect2(xt, y1 - 9.0, 18.0, 3.0), Color(1.0, 1.0, 1.0, 0.7))
	_t(false, Vector2(xt + 26.0, y1 + 4.0), "camino sin salida", 12, T_TEXTO)
	_t(false, Vector2(x0 + 2.0, y0 + 58.0), "Rueda: zoom · arrastrar: mover · mouse encima o clic: descripción", 11, T_TENUE)


## Marca del tipo dentro del círculo (los conocimientos no llevan): unidad ▲, arma/equipo ◆, vehículo ■, edificio ⬟, gobierno ★ (pentágono), diplomacia ✚, técnica ●.
func _marca_tipo(c: Vector2, r: float, tipo: String, relleno: Color, atenuado: bool) -> void:
	if r < 7.0 or tipo == "K":
		return
	var luz := relleno.get_luminance()
	var col := Color(0.0, 0.0, 0.0, 0.62) if luz > 0.35 else Color(1.0, 1.0, 1.0, 0.78)
	if atenuado:
		col.a *= 0.4
	var m := r * 0.46
	match tipo:
		"U":
			_lote.poligono(c, m * 1.15, 3, col)
		"W":
			_lote.poligono(c, m * 1.2, 4, col)
		"V":
			_lote.rectangulo(Rect2(c - Vector2(m, m) * 0.85, Vector2(m, m) * 1.7), col)
		"B":
			_lote.poligono(c, m * 1.2, 5, col)
		"G":
			_lote.poligono(c, m * 1.25, 6, col)
		"A":
			_lote.rectangulo(Rect2(c.x - m * 0.28, c.y - m, m * 0.56, m * 2.0), col)
			_lote.rectangulo(Rect2(c.x - m, c.y - m * 0.28, m * 2.0, m * 0.56), col)
		"T":
			_lote.disco(c, m * 0.8, col, 10)
		"R":
			_lote.poligono(c, m * 1.1, 8, col)


## Encola un texto: `_t_emitir` los dibuja todos seguidos (primero los de letra normal y luego los de negrita: cada fuente es una textura distinta).
func _t(negrita: bool, p: Vector2, txt: String, tam: int, col: Color, ancho := -1.0, alin := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_tx.append([negrita, p, txt, tam, col, ancho, alin])


func _t_emitir() -> void:
	for pasada in 2:
		for t in _tx:
			if bool(t[0]) == (pasada == 1):
				draw_string(fuente_neg if pasada == 1 else fuente, t[1], t[2], t[6], t[5], t[3], t[4])
	_tx.clear()


## Parte `t` en líneas de hasta `ancho` px, cortando entre palabras.
func _envolver(f: Font, t: String, tam: int, ancho: float) -> PackedStringArray:
	var filas := PackedStringArray()
	if t == "":
		return filas
	var actual := ""
	for palabra in t.split(" "):
		var prueba: String = palabra if actual == "" else actual + " " + palabra
		if actual != "" and f.get_string_size(prueba, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > ancho:
			filas.append(actual)
			actual = palabra
		else:
			actual = prueba
	if actual != "":
		filas.append(actual)
	return filas


## Texto en una sola línea recortado con «…» para que quepa en `ancho`.
func _recortar(f: Font, t: String, tam: int, ancho: float) -> String:
	if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= ancho:
		return t
	while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > ancho:
		t = t.substr(0, t.length() - 1)
	return t + "…"


## Globo con lo esencial del descubrimiento bajo el ratón: nombre, año y estado, dónde está, lo que requiere (con su estado) y cuánto abre.
func _globo_nodo(i: int) -> void:
	var e: int = int(_est.get(i, estado_nodo(i)))
	var cols := _colores_estado(e)
	var sec: int = int(d.seccion[i])
	var ruta := String(d.secciones[sec]["nombre"])
	if int(d.sub[i]) >= 0:
		ruta += " › " + String(d.subsecciones[int(d.sub[i])])
	var lineas: Array = []                                       # [punto de color o null, texto, color, negrita, tamaño]
	lineas.append([null, _recortar(fuente_neg, String(d.nombre[i]), 14, 330.0), T_TEXTO, true, 14])
	var col_e: Color = cols[1] if e != E_BLOQUEADO else C_GRIS_BORDE
	lineas.append([cols[0] if e != E_BLOQUEADO else C_NEGRO_BORDE, "%s · %s" % [d.anio_texto(int(d.anio[i])), String(NOMBRE_ESTADO[e])], col_e, false, 12])
	lineas.append([null, _recortar(fuente, ruta, 11, 330.0), T_TENUE, false, 11])
	var tipo_txt := String(d.tipos.get(String(d.tipo[i]), d.tipo[i]))
	var info := "%s · %s" % [tipo_txt, String(d.eras[int(d.era[i])]["nombre"])]
	if int(d.tema[i]) >= 0:
		info += " · " + String(d.temas[int(d.tema[i])]["nombre"])
	lineas.append([null, _recortar(fuente, info, 11, 330.0), T_NOTA, false, 11])
	for fila in _envolver(fuente, String(d.secciones[sec].get("desc", "")), 11, 300.0):
		lineas.append([null, fila, T_TENUE, false, 11])
	var pedidos := _prerrequisitos(i)
	if pedidos.is_empty():
		lineas.append([null, "Raíz del árbol: no requiere nada.", T_TENUE, false, 11])
	else:
		lineas.append([null, "Requiere:", T_ORO, false, 11])
		for k in mini(pedidos.size(), 5):
			var r: int = pedidos[k]
			var er: int = estado_nodo(r)
			var cr: Array = _colores_estado(er)
			lineas.append([cr[0] if er != E_BLOQUEADO else C_NEGRO_BORDE, _recortar(fuente, String(d.nombre[r]), 12, 300.0), T_TEXTO, false, 12])
		if pedidos.size() > 5:
			lineas.append([null, "…y %d más" % (pedidos.size() - 5), T_TENUE, false, 11])
	var n_abre: int = (d.dependientes[i] as PackedInt32Array).size()
	lineas.append([null, "Abre %d descubrimiento%s" % [n_abre, "" if n_abre == 1 else "s"] if n_abre > 0 else "No abre nada: camino sin salida", C_ABRE if n_abre > 0 else T_TENUE, false, 11])
	lineas.append([null, "Clic: ficha completa", T_ORO, false, 11])
	_dibujar_globo(lineas)


func _globo_pastilla(k: int) -> void:
	var pa: Dictionary = pastillas[k]
	var arriba: bool = pa["arriba"]
	var otros: PackedInt32Array = pa["otros"]
	var lineas: Array = []
	lineas.append([null, "Continúa en otra sección" if arriba else "Viene de otra sección", C_PASTILLA, true, 13])
	lineas.append([null, "%s «%s»" % ["Abre" if arriba else "Necesita", _recortar(fuente, String(d.nombre[int(pa["nodo"])]), 11, 260.0)], T_TENUE, false, 11])
	for j in mini(otros.size(), 6):
		var o: int = otros[j]
		var eo: int = estado_nodo(o)
		var co: Array = _colores_estado(eo)
		var so: int = int(d.seccion[o])
		lineas.append([co[0] if eo != E_BLOQUEADO else C_NEGRO_BORDE, "%s  ·  %s" % [_recortar(fuente, String(d.nombre[o]), 12, 200.0), _recortar(fuente, String(d.secciones[so]["nombre"]), 11, 150.0)], T_TEXTO, false, 12])
	if otros.size() > 6:
		lineas.append([null, "…y %d más" % (otros.size() - 6), T_TENUE, false, 11])
	lineas.append([null, "Clic: ir al primero", T_ORO, false, 11])
	_dibujar_globo(lineas)


func _dibujar_globo(lineas: Array) -> void:
	var ancho := 120.0
	var alto := 12.0
	for l in lineas:
		var f: Font = fuente_neg if bool(l[3]) else fuente
		var w := f.get_string_size(String(l[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(l[4])).x + (16.0 if l[0] != null else 0.0)
		ancho = maxf(ancho, w)
		alto += float(int(l[4])) + 5.0
	ancho += 22.0
	var p := _raton + Vector2(20.0, 20.0)
	if p.x + ancho > size.x - 6.0:
		p.x = _raton.x - ancho - 14.0
	if p.y + alto > size.y - 6.0:
		p.y = maxf(6.0, _raton.y - alto - 14.0)
	var rg := Rect2(p, Vector2(ancho, alto))
	_lote.rectangulo(rg.grow(3.0), Color(0.0, 0.0, 0.0, 0.35))
	_lote.degradado_v(rg, Color(T_GLOBO_ARRIBA.r, T_GLOBO_ARRIBA.g, T_GLOBO_ARRIBA.b, 0.97), Color(T_GLOBO_ABAJO.r, T_GLOBO_ABAJO.g, T_GLOBO_ABAJO.b, 0.97))
	_lote.marco(rg, 1.5, T_ORO)
	var y := p.y + 8.0
	for l in lineas:
		var tam: int = int(l[4])
		var x := p.x + 11.0
		if l[0] != null:
			_lote.disco(Vector2(x + 4.0, y + float(tam) * 0.5 + 1.0), 4.5, Color(0.0, 0.0, 0.0, 0.5), 12)
			_lote.disco(Vector2(x + 4.0, y + float(tam) * 0.5 + 1.0), 3.5, l[0] as Color, 12)
			x += 16.0
		_t(bool(l[3]), Vector2(x, y + float(tam) - 1.0), String(l[1]), tam, l[2] as Color)
		y += float(tam) + 5.0


## Año compacto: 1769 → «1769», -44 → «44 a. C.», -10000 → «10 mil a. C.», -2600000 → «2,6 M a. C.».
func _anio_corto(a: int) -> String:
	if a >= 0:
		return str(a)
	var v := -a
	if v >= 1000000:
		return "%s M a. C." % ("%.1f" % (float(v) / 1000000.0)).replace(".", ",")
	if v >= 10000:
		return "%d mil a. C." % int(roundf(float(v) / 1000.0))
	return "%d a. C." % v
