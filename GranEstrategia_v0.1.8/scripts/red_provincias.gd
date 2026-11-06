extends RefCounted
## Red de provincias (0.1.7.9.9E): quién es vecino de quién, por dónde puede ir una marcha y dónde se dibujan las tropas.
## Datos: datos/vecinos_prov.json (lo genera herramientas/construir_vecinos.py). Los números de provincia son los de Mundo.provincias.
##   · Vecinos por TIERRA: comparten frontera. Vecinos por MAR: costas a menos de ~200 km (estrechos, islas cercanas); el tramo por
##     mar cuesta el doble (se avanza la mitad de rápido). Las islas lejanas no tienen ruta (todavía no hay transporte naval).
##   · El coste de un camino se mide en «km equivalentes»: tierra = km entre los centros; mar = 2 × km.

const ANCHO := 2400.0
const FACTOR_MAR := 2.0

var listo := false
var centros := PackedVector2Array()          # punto interior de cada provincia (ahí se dibujan sus tropas)
var km_por_unidad := 40075.0 / ANCHO
var aristas: Array = []                      # [a, b, km, mar]
var n_tierra := 0
var n_mar := 0
var _vecinos: Array = []                     # por provincia: PackedInt32Array de vecinos
var _info := {}                              # a * 8192 + b -> [km, mar]
var _astar: RedAStar
var _cache_rutas := {}                       # a * 8192 + b -> ruta (PackedInt32Array); ver ruta()
const CACHE_RUTAS_MAX := 6000


class RedAStar extends AStar2D:
	var costes := {}
	var centros := PackedVector2Array()
	var km_u := 16.7

	func _compute_cost(a: int, b: int) -> float:
		return float(costes.get(a * 8192 + b, 1.0e7))

	## Nunca pasa del coste real (la distancia en línea recta es el mínimo): así el camino que sale es el mejor.
	func _estimate_cost(a: int, b: int) -> float:
		var p := centros[a]
		var q := centros[b]
		var dx := absf(q.x - p.x)
		dx = minf(dx, 2400.0 - dx)
		var lat := (600.0 - 0.5 * (p.y + q.y)) / 1200.0 * 180.0
		return Vector2(dx * cos(deg_to_rad(lat)), q.y - p.y).length() * km_u * 0.9


func leer(js) -> void:
	if not (js is Dictionary):
		return
	var cs: Array = js.get("centros", [])
	if cs.is_empty():
		return
	km_por_unidad = float(js.get("km_por_unidad", km_por_unidad))
	centros.resize(cs.size())
	for i in cs.size():
		centros[i] = Vector2(float(cs[i][0]), float(cs[i][1]))
	aristas = js.get("aristas", [])
	_cache_rutas.clear()
	_vecinos.clear()
	_vecinos.resize(cs.size())
	for i in cs.size():
		_vecinos[i] = PackedInt32Array()
	_astar = RedAStar.new()
	_astar.centros = centros
	_astar.km_u = km_por_unidad
	_astar.reserve_space(cs.size())
	for i in cs.size():
		_astar.add_point(i, centros[i])
	n_tierra = 0
	n_mar = 0
	for a in aristas:
		var p := int(a[0])
		var q := int(a[1])
		var km := float(a[2])
		var mar := int(a[3])
		var coste := km * (FACTOR_MAR if mar == 1 else 1.0)
		_info[p * 8192 + q] = [km, mar]
		_info[q * 8192 + p] = [km, mar]
		_astar.costes[p * 8192 + q] = coste
		_astar.costes[q * 8192 + p] = coste
		_astar.connect_points(p, q, true)
		_vecinos[p].append(q)
		_vecinos[q].append(p)
		if mar == 1:
			n_mar += 1
		else:
			n_tierra += 1
	listo = true


## 0.1.8.35 · La provincia `i` cambió de forma: mueve el punto donde se dibujan sus tropas (y el que usa el buscador de caminos como estimación).
## Los vecinos y los kilómetros de cada tramo siguen siendo los de la época hasta que se decida otra regla.
func actualizar_centro(i: int, pos: Vector2) -> void:
	if i < 0 or i >= centros.size():
		return
	centros[i] = pos
	if _astar != null:
		var c: PackedVector2Array = _astar.centros
		c[i] = pos
		_astar.centros = c
		_astar.set_point_position(i, pos)


## Campaña: las provincias bloqueadas desaparecen de la red (no son vecinas de nadie y ninguna ruta pasa por ellas).
var _bloq := {}

func bloquear(prov: Dictionary) -> void:
	_bloq = prov
	_cache_rutas.clear()
	for pi in prov:
		if int(pi) >= 0 and int(pi) < _vecinos.size():
			_astar.set_point_disabled(int(pi), true)
	for i in _vecinos.size():
		var l: PackedInt32Array = _vecinos[i]
		var hay := false
		for v in l:
			if prov.has(int(v)):
				hay = true
				break
		if hay or prov.has(i):
			var nuevo := PackedInt32Array()
			if not prov.has(i):
				for v in l:
					if not prov.has(int(v)):
						nuevo.append(v)
			_vecinos[i] = nuevo


func vecinos(pi: int) -> PackedInt32Array:
	if pi < 0 or pi >= _vecinos.size():
		return PackedInt32Array()
	return _vecinos[pi]


## [km, mar] del tramo entre dos provincias vecinas, o [] si no lo son.
func tramo(a: int, b: int) -> Array:
	return _info.get(a * 8192 + b, [])


## Coste del tramo en km equivalentes (lo que hay que «gastar» de marcha para cruzarlo).
func coste_tramo(a: int, b: int) -> float:
	var t: Array = tramo(a, b)
	if t.is_empty():
		return 1.0e7
	return float(t[0]) * (FACTOR_MAR if int(t[1]) == 1 else 1.0)


## Camino más barato de la provincia `a` a la `b` (incluye ambas). Vacío si no hay ruta.
func ruta(a: int, b: int) -> PackedInt32Array:
	if not listo or a < 0 or b < 0 or a >= centros.size() or b >= centros.size():
		return PackedInt32Array()
	if not _bloq.is_empty() and (_bloq.has(a) or _bloq.has(b)):
		return PackedInt32Array()
	if a == b:
		return PackedInt32Array([a])
	# 0.1.8.2a: caché de rutas. La IA pide cientos de veces las mismas (de sus bases a los mismos frentes) y cada A* cuesta 0,2-0,7 ms.
	# El coste de ir y volver es el mismo, así que una ruta guardada sirve también al revés. Se vacía al cambiar la red (leer, bloquear).
	var clave := a * 8192 + b
	if _cache_rutas.has(clave):
		return _cache_rutas[clave]
	var clave_inv := b * 8192 + a
	if _cache_rutas.has(clave_inv):
		var inv := PackedInt32Array(_cache_rutas[clave_inv])
		inv.reverse()
		return inv
	var r: PackedInt64Array = _astar.get_id_path(a, b)
	var s := PackedInt32Array()
	for x in r:
		s.append(int(x))
	if _cache_rutas.size() >= CACHE_RUTAS_MAX:
		_cache_rutas.clear()
	_cache_rutas[clave] = s
	return s


func coste_ruta(r: PackedInt32Array) -> float:
	var t := 0.0
	for i in range(r.size() - 1):
		t += coste_tramo(r[i], r[i + 1])
	return t


## Diferencia en x por el camino corto (el mapa da la vuelta).
static func dx_corto(a: float, b: float) -> float:
	var d := fposmod(b - a + ANCHO * 0.5, ANCHO) - ANCHO * 0.5
	return d

