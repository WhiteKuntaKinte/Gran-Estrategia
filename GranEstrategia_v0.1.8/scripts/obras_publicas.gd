extends RefCounted
## OBRAS PÚBLICAS DE LA IA (0.1.8.48). Cada país con IA gasta su FONDO DE OBRAS (la partida «gasto_obras» de los impuestos, ver Mundo._economia_dia) en edificios
## que de verdad le sirven: cada CICLO_DIAS días revisa unas pocas provincias al azar y, entre lo que conoce y puede pagar del fondo (nunca toca la tesorería), elige
## lo que más gana por su costo:
##   valor = producción (ren) + salud (sal) × hambre y mortalidad + comida (com) × necesidad + vivienda (urb) + orden (ord) × descontento + defensa (def) × guerra + movilidad (mov)
##   puntaje = valor ÷ fracción de producción que cuesta (la clase del edificio)
## Los edificios de partida de cada escenario no cuentan como ganancia (ver docs/EDIFICIOS_EFECTOS.md), así que cada descubrimiento nuevo vuelve a abrir obras.
## El jugador NO usa este módulo: construye él con la ventana Construir (B) y gasta también del fondo. Cuesta ~0,35–0,4 ms por día de juego con todas las IA activas (medido en 1500 y 2026; ver NOTAS_TECNICAS_0.1.8.48.md).

const CICLO_DIAS := 360                  # cada país con IA revisa sus obras una vez al año
const MUESTRA_PROV := 2                  # provincias que mira en cada revisión
const EVAL_MAX := 6                      # edificios que evalúa por provincia y obra (los de mayor techo que se pueden construir): GDScript no da para más sin tirones
const OBRAS_POR_REVISION := 3            # con fondo de sobra, hasta tantas obras seguidas en cada revisión
const LOTE_MAX := 6                      # países por llamada de fase (a x6 el día se reparte: lo que sobre se hace en las siguientes)
const RECARGA_DIAS := 365                # cada cuántos días vuelve a mirar qué edificios conoce
const VALOR_MIN := 0.015                 # una obra que no mejora al menos esto (en «fracciones de producción») no se construye
const W_SAL := 0.6
const W_COM := 0.008                     # puntos de bienestar → fracción
const W_URB := 0.5
const W_ORD := 0.01
const W_DEF := 0.12
const W_MOV := 0.15

var mundo
var ed
var _dia := 0
var _lista: Array = []                   # nombres de los países con IA (se rehace cuando cambia su número)
var _n_activas := -1
var _cursor := 0
var _pend := 0.0                         # países que tocan revisar y aún no se revisaron (fracción)
var _cand := {}                          # ID de país -> [día de la lista, PackedInt32Array de edificios con efecto que conoce, de mayor a menor techo de puntaje]
var _techo := PackedFloat32Array()       # por edificio: el mayor puntaje que podría sacar (sin saturar ni diluir, con la mayor urgencia): sirve para dejar de buscar a tiempo
var _orden := PackedInt32Array()         # los edificios con efecto, de mayor a menor techo
var _rng := RandomNumberGenerator.new()
var revisiones := 0                      # países revisados desde que empezó la partida (pruebas y Debug)
var obras_hechas := 0                    # obras que las IA empezaron
var evaluaciones := 0                    # edificios cuya ganancia se calculó (lo que cuesta cada revisión)
var gastado_usd := 0.0                   # y cuánto costaron (US$)
var usec_total := 0
var ms_max := 0.0
var _c_pob := PackedFloat64Array()       # columnas de la base (se piden una vez por día: pueden cambiar de sitio si la base crece)
var _c_pc := PackedFloat64Array()
var _c_mu := PackedFloat64Array()
var _c_fav := PackedFloat64Array()
var _c_mor := PackedFloat64Array()
var _c_bie := PackedFloat64Array()
var _c_oc := PackedInt32Array()


func iniciar(m) -> void:
	mundo = m
	ed = m.edificios
	_rng.seed = 48017
	_techo.resize(ed.n)
	for e in ed.n:
		var t := 0.0
		for x in (ed._ef_de[e] as Array):                  # [clase, peso, habitantes que atiende]: la ganancia nunca pasa del peso
			t += float(x[1]) * _w_max(int(x[0]))
		_techo[e] = t / maxf(ed.fraccion_de(e), 1.0e-6)
	var lista := []
	for e in ed.n:
		if ed.con_efecto(e):
			lista.append(e)
	lista.sort_custom(func(a, b): return _techo[a] > _techo[b])
	_orden = PackedInt32Array(lista)
	reiniciar()


## Multiplicador más alto que puede tener una clase de efecto en el puntaje (peso × urgencia máxima).
func _w_max(k: int) -> float:
	match k:
		ed.EF_REN:
			return 1.0
		ed.EF_SAL:
			return W_SAL * 2.0
		ed.EF_COM:
			return W_COM * 2.0
		ed.EF_URB:
			return W_URB
		ed.EF_ORD:
			return W_ORD * 2.0
		ed.EF_DEF:
			return W_DEF * 3.0
	return W_MOV


func reiniciar() -> void:
	_dia = 0
	_lista = []
	_n_activas = -1
	_cursor = 0
	_pend = 0.0
	_cand.clear()
	revisiones = 0
	obras_hechas = 0
	evaluaciones = 0
	gastado_usd = 0.0
	usec_total = 0
	ms_max = 0.0


## Fase del día (`Mundo.fases_dias`): `k` días. Devuelve siempre false (el trabajo ya es corto).
func fase_dia(k := 1) -> bool:
	if ed == null or not ed.efectos_listos or mundo.ia == null:
		return false
	_dia += k
	var activas: Dictionary = mundo.ia.activas
	if activas.size() != _n_activas:
		_n_activas = activas.size()
		_lista = activas.keys()
		_cursor = 0
	if _lista.is_empty():
		return false
	_pend = minf(_pend + float(_lista.size()) * float(k) / float(CICLO_DIAS), float(LOTE_MAX) * 3.0)
	var n := mini(int(_pend), LOTE_MAX)
	if n <= 0:
		return false
	_pend -= float(n)
	var t0 := Time.get_ticks_usec()
	_cargar_columnas()
	for _i in n:
		var nombre: String = String(_lista[_cursor])
		_cursor = (_cursor + 1) % _lista.size()
		if activas.has(nombre):
			_decidir(nombre)
	var dt := Time.get_ticks_usec() - t0
	usec_total += dt
	ms_max = maxf(ms_max, float(dt) / 1000.0)
	return false


func _cargar_columnas() -> void:
	var v: Dictionary = mundo.bd.vars
	_c_pob = v["poblacion"].col_f
	_c_pc = v["pib_pc_usd"].col_f
	_c_mu = v["mult_ingreso"].col_f
	_c_fav = v["favorabilidad"].col_f
	_c_mor = v["mortalidad"].col_f
	_c_bie = v["bienestar"].col_f
	_c_oc = v["ocupante"].col_i


## Edificios con efecto que el país conoce (se rehace una vez al año).
func _candidatos(nombre: String, tid: int) -> PackedInt32Array:
	var c = _cand.get(tid)
	if c != null and _dia - int(c[0]) < RECARGA_DIAS:
		return c[1]
	var r := PackedInt32Array()
	for e in _orden:
		if ed.conoce(nombre, e):
			r.append(e)
	_cand[tid] = [_dia, r]
	return r


func _decidir(nombre: String) -> void:
	revisiones += 1
	if not mundo.paises.has(nombre) or nombre == mundo.jugador:
		return
	var p = mundo.paises[nombre]
	if p.inerte or p.provincias.is_empty():
		return
	var fondo: float = p.fondo_obras
	if fondo <= 0.0:
		return
	var tid: int = int(p.tid)
	var cand := _candidatos(nombre, tid)
	if cand.is_empty():
		return
	var por_usd: float = mundo._por_usd(nombre)
	var guerra: float = 3.0 if mundo.bd.num("guerras_activas", tid, 0.0) > 0.0 else 1.0
	var provs: Array = p.provincias
	# las provincias que mira (con lo que cada una necesita, calculado una sola vez)
	var muestra := []                                           # [índice, habitantes, base de costo (divisa), urg_ord, urg_sal, urg_com]
	for _j in MUESTRA_PROV:
		var pi: int = int(provs[_rng.randi() % provs.size()])
		var k: int = mundo.provincias[pi].ix
		var pop: float = _c_pob[k]
		if _c_oc[k] >= 0 or is_nan(pop) or pop <= 0.0:
			continue
		var fav: float = _c_fav[k]
		var mor: float = 20.0 if is_nan(_c_mor[k]) else _c_mor[k]
		var bie: float = 50.0 if is_nan(_c_bie[k]) else _c_bie[k]
		muestra.append([pi, pop, _c_pc[k] * pop * _c_mu[k] * por_usd, 2.0 if fav < 50.0 else (0.4 if fav > 70.0 else 1.0),
			1.0 + clampf((mor - 20.0) / 20.0, 0.0, 1.0), 1.0 + clampf((50.0 - bie) / 30.0, 0.0, 1.0)])
	if muestra.is_empty():
		return
	ed.cache_tolerante = true
	for _o in OBRAS_POR_REVISION:                               # con fondo de sobra se hacen varias obras seguidas (la preparación de arriba se paga una vez)
		var mejor := 0.0
		var mejor_pi := -1
		var mejor_e := -1
		for m in muestra:
			var pi: int = m[0]
			var tiene: Dictionary = ed.de_provincia(pi)
			var vistos := 0
			for e in cand:
				if _techo[e] <= mejor:                          # ordenados de mayor a menor techo: ninguno de los que siguen puede ganarle al mejor
					break
				var fr: float = ed.fraccion_de(e)
				if fr * float(m[2]) > fondo:                    # (sin el piso de la fórmula del costo: el costo exacto se comprueba al elegir)
					continue
				if int(tiene.get(ed.slug[e], 0)) + ed.en_obra(pi, e) >= ed.tope[e]:
					continue
				evaluaciones += 1
				vistos += 1
				var g: PackedFloat32Array = ed.ganancias(pi, e, float(m[1]))
				var v: float = g[ed.EF_REN] + W_SAL * float(m[4]) * g[ed.EF_SAL] + W_COM * float(m[5]) * g[ed.EF_COM] + W_URB * g[ed.EF_URB] + W_ORD * float(m[3]) * g[ed.EF_ORD] \
					+ W_DEF * guerra * g[ed.EF_DEF] + W_MOV * g[ed.EF_MOV]
				if v >= VALOR_MIN and v / fr > mejor:
					mejor = v / fr
					mejor_pi = pi
					mejor_e = e
				if vistos >= EVAL_MAX:
					break
		if mejor_pi < 0 or ed.costo_local(mejor_pi, mejor_e) > fondo:      # solo el fondo: nunca se toca la tesorería
			break
		var r: Dictionary = ed.construir(nombre, mejor_pi, mejor_e)
		if not bool(r["ok"]):
			break
		obras_hechas += 1
		gastado_usd += float(r["costo"]) / maxf(por_usd, 1.0e-12)
		fondo -= float(r["costo"])
		if fondo <= 0.0:
			break
	ed.cache_tolerante = false
