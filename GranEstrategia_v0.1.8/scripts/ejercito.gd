extends RefCounted
## Ejército por pelotones (0.1.7.9.9D).
##
## Los datos viven en la BASE DE DATOS PRINCIPAL; este archivo solo contiene las REGLAS (crear, envejecer, bajas, reclutar, mover).
##   · Cada país tiene un «ejército» (tipo `ejercito`, ID desde 10.000.000, padre = país).
##   · Cada pelotón es un territorio de tipo `peloton` (ID desde 11.000.000, padre = su ejército), con las variables
##     soldados, edad_media, experiencia, familiaridad, forma_fisica, bajas_mes, bajas_total y ubicacion (provincia).
##   · Cadena completa:  mundo > continente > país > ejército > pelotón.
## Un PELOTÓN agrupa hasta 1.000 soldados con los mismos datos: la pantalla puede mostrar millones y el juego solo calcula miles.
## Los soldados y mandos con nombre NO existen en la base: se generan al abrir un pelotón (scripts/mandos.gd) y no se guardan.
##
## Historial: soldados y ubicacion guardan historial por cambio (cada baja, refuerzo o movimiento deja una fila). Edad, experiencia,
## familiaridad y forma física se actualizan cada mes SIN historial (son ~21.000 pelotones; guardar cada mes pesaría mucho).
##
## REGIMIENTOS (0.1.7.9.9F-c): un regimiento (tipo `regimiento`, IDs desde 12.000.000, padre = ejército) es un GRUPO de pelotones que
## se mueve, pelea y se dibuja en el mapa como UN cuadro. Cada pelotón guarda el suyo en la variable `regimiento`. Dos regimientos
## pueden compartir provincia sin juntarse; unirlos (`unir`) o partirlos (`dividir_reg`) son órdenes deliberadas.
## PRECIOS: cada ejército guarda `mantenimiento_unidad` y `costo_reclutamiento_unidad` (US$ por unidad de 1.000 soldados). Se
## recalculan cada mes con el PIB por habitante del país (`actualizar_precios`); la tesorería los cobra en Mundo.
##
## Reglas (PROVISIONALES, como el crecimiento económico; se ajustan con pruebas de juego):
##   · Reclutas nuevos: edad ≈ 19, experiencia ≈ 5, familiaridad 0. Mezclarlos baja la experiencia y la familiaridad del
##     pelotón y baja su edad media (sube la forma física por juventud).
##   · Cada mes los soldados envejecen 1/12 de año y una parte (≈ 1,1 % al mes, ~8 años de servicio) se retira y se
##     reemplaza por reclutas: así la edad media se estabiliza en vez de crecer sin fin.
##   · Un mes SIN bajas la experiencia y la familiaridad suben (con rendimientos decrecientes). Las bajas frenan esas
##     subidas ese mes, y además quitan familiaridad de golpe.
##   · Forma física = f(edad): máxima entre ~20 y 28 años, cae a partir de ahí.

const PerfilScript := preload("res://scripts/perfil.gd")
const BDScript := preload("res://scripts/base_datos.gd")

const BASE_EJERCITO := 10000000
const BASE_PELOTON := 11000000
const BASE_REGIMIENTO := 12000000
const TAM_PELOTON := 1000
const FACTOR_MANT_DEFECTO := 6.0        # US$ al año por soldado = 6 × PIB por habitante (el gasto militar real ronda 6-8×). PROVISIONAL
const FACTOR_RECL_DEFECTO := 4.0        # US$ por soldado reclutado (pago único) = 4 × PIB por habitante. PROVISIONAL
const EDAD_RECLUTA := 19.0
const RETIRO_MENSUAL := 0.0111          # 1 - (1 - 1/8)^(1/12)
const GANA_EXP_MES := 0.9               # puntos/mes (tope 100, con rendimientos decrecientes)
const GANA_FAM_MES := 1.4
const VEL_MARCHA_KM_DIA := 30.0         # km «equivalentes» que avanza una columna por día (por mar cuesta el doble). PROVISIONAL

var mundo                                # Mundo (provincias, países, ciudades)
var bd                                   # BaseDatos
var version := 0                         # sube con cualquier cambio (la interfaz la usa para saber si redibujar)
var ej_de_pais := {}                     # ID de país -> ID de su ejército
var por_prov := {}                       # ID de provincia -> Array de IDs de pelotón vivos
var por_pais := {}                       # ID de país -> Array de IDs de pelotón vivos
var tasas: Dictionary = {}               # país (nombre) -> fracción de la población que sirve (datos/ejercito.json)
var tasa_defecto := 0.0022
var siguiente_pel := BASE_PELOTON
var _ix_todos := PackedInt32Array()      # índice denso de todos los pelotones creados (nunca se compacta)
var _rng := RandomNumberGenerator.new()
var _prov_de_tid := {}                   # ID de provincia -> Provincia
var red                                  # RedProvincias (vecinos y centros); null si faltan los datos
var marchas := {}                        # ID de marcha -> {id, pais, reg, pel[], ruta (índices de provincia), k, km, parar}
var siguiente_reg := BASE_REGIMIENTO
var cont_reg := {}                       # ID de país -> cuántos regimientos ha creado (para el nombre «Regimiento 7»)
var pel_de_reg := {}                     # ID de regimiento -> Array de IDs de pelotón
var reg_de_pel := {}                     # ID de pelotón -> ID de regimiento
var regs_prov := {}                      # ID de provincia -> Array de regimientos QUIETOS allí
var regs_pais := {}                      # ID de país -> Array de todos sus regimientos (quietos o en marcha)
var prov_de_reg := {}                    # ID de regimiento -> ID de provincia (-1 si va por el camino)
var marcha_de_reg := {}                  # ID de regimiento -> ID de marcha (solo los que van por el camino)
var llegadas := []                       # [[ID provincia, ID país], ...] columnas que terminaron su marcha (la guerra las revisa cada día)
var reg_ultimo := -1                     # regimiento creado o tocado por la última orden de reclutar
var en_marcha := {}                      # ID de pelotón -> ID de marcha (solo los que van por el camino)
var siguiente_marcha := 1
var version_marchas := 0                 # sube al crear, avanzar o terminar una marcha
var version_pilas := 0                   # sube cuando cambia QUIÉN está DÓNDE o cuántos son (no con el envejecimiento mensual)
var _cache_pilas := []
var _cache_pilas_ver := -1
var _cache_sold_pais := {}
var _cache_sold_ver := -1


# ─────────────────────────────────────────────────────────────
# Fórmulas
# ─────────────────────────────────────────────────────────────
static func fisico_de_edad(edad: float) -> float:
	var z := (edad - 24.0) / 16.0
	return 100.0 * exp(-z * z)


## Número que ve el jugador («Pelotón 25»): 1, 2, 3... en el orden de creación.
static func numero(id: int) -> int:
	return id - BASE_PELOTON + 1


func _cambio() -> void:
	version += 1
	version_pilas += 1


## Todos los regimientos QUIETOS: [[ID regimiento, ID provincia, ID país, soldados, pelotones], ...] (sin ordenar).
## Queda guardada hasta que cambia `version_pilas` (reconstruirla recorre los pelotones: unas decenas de ms con 21.000).
func regimientos_quietos() -> Array:
	if _cache_pilas_ver == version_pilas:
		return _cache_pilas
	var r := []
	var col_s: PackedFloat64Array = bd.vars["soldados"].col_f
	var idx_de_id: Dictionary = bd.idx_de_id
	for prov in regs_prov:
		for rid in regs_prov[prov]:
			var s := 0.0
			var lst: Array = pel_de_reg.get(rid, [])
			for id in lst:
				s += col_s[idx_de_id[id]]
			r.append([int(rid), int(prov), pais_de_reg(int(rid)), int(s), lst.size()])
	_cache_pilas = r
	_cache_pilas_ver = version_pilas
	return r


## Soldados de cada país (todos sus pelotones, también los que van por el camino): {ID país: soldados}. Guardado por versión.
## Una sola pasada por las columnas (activo, ejército padre, soldados): sin buscar ID por ID en diccionarios (0.1.8.2: de ~15 ms a ~3 ms con 41.000 pelotones).
func soldados_por_pais() -> Dictionary:
	if _cache_sold_ver == version_pilas:
		return _cache_sold_pais
	var n_ej := 0
	for pa in ej_de_pais:
		n_ej = maxi(n_ej, int(ej_de_pais[pa]) - BASE_EJERCITO + 1)
	var pais_de_ej := PackedInt32Array()
	pais_de_ej.resize(n_ej)
	pais_de_ej.fill(-1)
	for pa in ej_de_pais:
		pais_de_ej[int(ej_de_pais[pa]) - BASE_EJERCITO] = int(pa)
	var acum := PackedFloat64Array()
	acum.resize(n_ej)
	var col_s: PackedFloat64Array = bd.vars["soldados"].col_f
	var activo: PackedByteArray = bd.t_activo
	var padre: PackedInt32Array = bd.t_padre
	var tope := col_s.size()
	for ix in _ix_todos:
		if ix >= tope or activo[ix] != 1:
			continue
		var e: int = padre[ix] - BASE_EJERCITO
		if e < 0 or e >= n_ej:
			continue
		var x: float = col_s[ix]
		if x == x:                                                      # descarta NaN
			acum[e] += x
	var r := {}
	for e2 in n_ej:
		if pais_de_ej[e2] >= 0 and por_pais.has(pais_de_ej[e2]):
			r[pais_de_ej[e2]] = int(acum[e2])
	_cache_sold_pais = r
	_cache_sold_ver = version_pilas
	return r


func soldados_de_pais(pais_tid: int) -> int:
	return int(soldados_por_pais().get(pais_tid, 0))


# ─────────────────────────────────────────────────────────────
# Regimientos
# ─────────────────────────────────────────────────────────────
func existe_reg(rid: int) -> bool:
	var ix: int = bd.idx(rid)
	return ix >= 0 and bd.t_tipo[ix] == BDScript.T_REGIMIENTO and bd.t_activo[ix] == 1


func pais_de_reg(rid: int) -> int:
	return bd.padre_de(bd.padre_de(rid))


func reg_de(pel_id: int) -> int:
	return int(reg_de_pel.get(pel_id, -1))


func soldados_reg(rid: int) -> int:
	var t := 0
	for id in pel_de_reg.get(rid, []):
		t += soldados_de(int(id))
	return t


func prov_de(rid: int) -> int:
	return int(prov_de_reg.get(rid, -1))


func en_marcha_reg(rid: int) -> bool:
	return marcha_de_reg.has(rid)


## Regimientos quietos en una provincia: [ID regimiento, ...] (todos los países).
func regs_en(prov_tid: int) -> Array:
	return regs_prov.get(prov_tid, [])


func nombre_reg(rid: int) -> String:
	return bd.nombre_de(rid)


func _registrar_reg(rid: int, prov: int, pais: int) -> void:
	if not regs_prov.has(prov):
		regs_prov[prov] = []
	if not regs_pais.has(pais):
		regs_pais[pais] = []
	regs_prov[prov].append(rid)
	regs_pais[pais].append(rid)
	prov_de_reg[rid] = prov
	if not pel_de_reg.has(rid):
		pel_de_reg[rid] = []


## Crea un regimiento vacío del país en la provincia. Devuelve su ID (-1 si el país no tiene ejército).
func _crear_reg(pais_tid: int, prov_tid: int) -> int:
	var id_ej := ejercito_de(pais_tid)
	if id_ej < 0:
		return -1
	var rid := siguiente_reg
	siguiente_reg += 1
	var k: int = int(cont_reg.get(pais_tid, 0)) + 1
	cont_reg[pais_tid] = k
	bd.anadir_territorios([[rid, BDScript.T_REGIMIENTO, "Regimiento %d" % k, id_ej, "r%d" % rid, 1]])
	pel_de_reg[rid] = []
	_registrar_reg(rid, prov_tid, pais_tid)
	return rid


## Mete un pelotón en un regimiento (lo saca del que tenía). `inicial` = carga de partida, sin historial.
func _poner_en_reg(pel: int, rid: int, motivo := "Regimiento", inicial := false) -> void:
	var viejo := int(reg_de_pel.get(pel, -1))
	if viejo == rid:
		return
	if viejo >= 0 and pel_de_reg.has(viejo):
		pel_de_reg[viejo].erase(pel)
	if inicial:
		bd.inicial_i("regimiento", pel, rid)
	else:
		bd.poner_i("regimiento", pel, rid, motivo)
	reg_de_pel[pel] = rid
	if not pel_de_reg.has(rid):
		pel_de_reg[rid] = []
	pel_de_reg[rid].append(pel)
	if viejo >= 0:
		_limpiar_reg(viejo)


## Si un regimiento se quedó sin pelotones, desaparece (y cancela su marcha si iba por el camino).
func _limpiar_reg(rid: int) -> void:
	if not pel_de_reg.has(rid) or not pel_de_reg[rid].is_empty():
		return
	var prov := int(prov_de_reg.get(rid, -1))
	if prov >= 0 and regs_prov.has(prov):
		regs_prov[prov].erase(rid)
	var pais := pais_de_reg(rid)
	if regs_pais.has(pais):
		regs_pais[pais].erase(rid)
	if marcha_de_reg.has(rid):
		marchas.erase(int(marcha_de_reg[rid]))
		marcha_de_reg.erase(rid)
		version_marchas += 1
	pel_de_reg.erase(rid)
	prov_de_reg.erase(rid)
	bd.desactivar(rid)


## Crea un pelotón nuevo dentro de un regimiento. Devuelve su ID.
func _nuevo_pel(rid: int, prov: int, sold: int, edad: float, exp_: float, fam: float) -> int:
	var pais := pais_de_reg(rid)
	var id_ej := ejercito_de(pais)
	var id := siguiente_pel
	siguiente_pel += 1
	bd.anadir_territorios([[id, BDScript.T_PELOTON, "Pelotón %d" % numero(id), id_ej, "p%d" % id, 1]])
	var ix: int = bd.idx(id)
	_ix_todos.append(ix)
	_escribir_inicial(ix, prov, sold, edad, exp_, fam)
	_indexar(id, prov, pais)
	_poner_en_reg(id, rid, "Regimiento", true)
	return id


func cuenta_pelotones() -> int:
	return _ix_todos.size()


func existe(id: int) -> bool:
	var ix: int = bd.idx(id)
	return ix >= 0 and bd.t_tipo[ix] == BDScript.T_PELOTON and bd.t_activo[ix] == 1


func pais_de(id: int) -> int:
	return bd.padre_de(bd.padre_de(id))


func ejercito_de(pais_tid: int) -> int:
	return int(ej_de_pais.get(pais_tid, -1))


func _indexar(id: int, prov: int, pais: int) -> void:
	if not por_prov.has(prov):
		por_prov[prov] = []
	if not por_pais.has(pais):
		por_pais[pais] = []
	por_prov[prov].append(id)
	por_pais[pais].append(id)


## Escribe las variables de un pelotón recién creado (sin historial: es el estado inicial).
func _escribir_inicial(ix: int, prov: int, sold: int, edad: float, exp_: float, fam: float) -> void:
	var f: int = bd.fecha
	var v: Dictionary = bd.vars
	v["soldados"].col_f[ix] = float(sold)
	v["soldados"].desde[ix] = f
	v["edad_media"].col_f[ix] = edad
	v["experiencia"].col_f[ix] = exp_
	v["familiaridad"].col_f[ix] = fam
	v["forma_fisica"].col_f[ix] = fisico_de_edad(edad)
	v["bajas_mes"].col_f[ix] = 0.0
	v["bajas_total"].col_f[ix] = 0.0
	v["ubicacion"].col_i[ix] = prov
	v["ubicacion"].desde[ix] = f
	for nombre in ["edad_media", "experiencia", "familiaridad", "forma_fisica", "bajas_mes", "bajas_total"]:
		v[nombre].desde[ix] = f


# ─────────────────────────────────────────────────────────────
# Creación inicial (2026)
# ─────────────────────────────────────────────────────────────
## `js`: datos/ejercito.json (tasa por país). Crea un ejército por país y reparte sus soldados entre las provincias.
func generar_inicial(js: Dictionary) -> void:
	bd = mundo.bd
	tasas = js.get("tasas", {}).duplicate()
	tasa_defecto = float(js.get("tasa_defecto", tasa_defecto))
	for nombre in js.get("sin_ejercito", []):
		tasas[String(nombre)] = 0.0
	_prov_de_tid.clear()
	for pr in mundo.provincias:
		_prov_de_tid[pr.tid] = pr
	_rng.seed = 20260101
	var nombres: Array = mundo.paises.keys()
	nombres.sort()                                   # orden fijo: el mismo mundo cada vez
	var filas := []
	var plan := []                                   # [ID país, ID ejército, ID provincia, soldados, ID del pelotón]
	var n_ej := 0
	for nombre in nombres:
		var ent = mundo.paises[nombre]
		var id_ej := BASE_EJERCITO + n_ej
		n_ej += 1
		ej_de_pais[int(ent.tid)] = id_ej
		filas.append([id_ej, BDScript.T_EJERCITO, "Ejército de " + String(nombre), int(ent.tid), "ej|" + String(nombre), 1])
	var asignaciones := {}                           # nombre de país -> [[ID provincia, soldados], ...]
	for nombre in nombres:
		asignaciones[nombre] = _repartir_pais(String(nombre))
	for nombre in nombres:
		var ent2 = mundo.paises[nombre]
		var ptid := int(ent2.tid)
		var reg_de_pila := {}                            # provincia -> regimiento (al empezar, cada pila de un país es UN regimiento)
		for a in asignaciones[nombre]:
			var id_p := siguiente_pel
			siguiente_pel += 1
			var id_r: int
			if reg_de_pila.has(int(a[0])):
				id_r = int(reg_de_pila[int(a[0])])
			else:
				id_r = siguiente_reg
				siguiente_reg += 1
				reg_de_pila[int(a[0])] = id_r
				cont_reg[ptid] = int(cont_reg.get(ptid, 0)) + 1
				filas.append([id_r, BDScript.T_REGIMIENTO, "Regimiento %d" % int(cont_reg[ptid]), ej_de_pais[ptid], "r%d" % id_r, 1])
			plan.append([ptid, ej_de_pais[ptid], int(a[0]), int(a[1]), id_p, id_r])
			filas.append([id_p, BDScript.T_PELOTON, "Pelotón %d" % numero(id_p), ej_de_pais[ptid], "p%d" % id_p, 1])
	bd.anadir_territorios(filas)
	for nombre in nombres:                           # tasa militar de cada ejército, en la base
		var tid_e: int = ej_de_pais[int(mundo.paises[nombre].tid)]
		bd.inicial_f("tasa_militar", tid_e, tasa_de(String(nombre)))
	for p in plan:
		var ix: int = bd.idx(int(p[4]))
		_ix_todos.append(ix)
		var edad := clampf(_rng.randfn(28.0, 3.0), 22.0, 36.0)
		var exp_ := clampf(_rng.randfn(42.0, 8.0), 15.0, 70.0)
		var fam := clampf(_rng.randfn(50.0, 8.0), 20.0, 80.0)
		_escribir_inicial(ix, int(p[2]), int(p[3]), edad, exp_, fam)
		_indexar(int(p[4]), int(p[2]), int(p[0]))
		if not pel_de_reg.has(int(p[5])):
			_registrar_reg(int(p[5]), int(p[2]), int(p[0]))
		_poner_en_reg(int(p[4]), int(p[5]), "Regimiento", true)
	actualizar_precios(true)
	_cambio()


func tasa_de(pais: String) -> float:
	return float(tasas.get(pais, tasa_defecto))


func _provincia_capital(pais: String) -> int:
	var ent = mundo.paises.get(pais)
	if ent == null:
		return -1
	for cid in ent.ciudades:
		var c = mundo.ciudades[int(cid)]
		if c.rango_capital == 2 and c.provincia >= 0 and c.provincia < mundo.provincias.size():
			return int(mundo.provincias[c.provincia].tid)
	return -1


## Devuelve [[ID provincia, soldados], ...] para un país: un elemento = un pelotón.
func _repartir_pais(pais: String) -> Array:
	var ent = mundo.paises[pais]
	var lista: Array = []                            # provincias con gente
	var pob_total := 0.0
	for pi in ent.provincias:
		var pr = mundo.provincias[int(pi)]
		if pr.poblacion > 0.0:
			lista.append(pr)
			pob_total += pr.poblacion
	var r := []
	if lista.is_empty():
		return r
	var total := int(roundf(pob_total * tasa_de(pais)))
	if total < 50:
		return r
	var cap := _provincia_capital(pais)
	if cap < 0:
		var mayor = lista[0]
		for pr in lista:
			if pr.poblacion > mayor.poblacion:
				mayor = pr
		cap = int(mayor.tid)
	# 0.1.8.2a: TODO el ejército de un país arranca junto, en su capital, como UN regimiento (antes: un regimiento por provincia, imposible de manejar al empezar).
	var enteros := total / TAM_PELOTON
	var resto := total - enteros * TAM_PELOTON
	for _j in enteros:
		r.append([cap, TAM_PELOTON])
	if resto >= 50:
		r.append([cap, resto])
	return r


# ─────────────────────────────────────────────────────────────
# Paso del tiempo
# ─────────────────────────────────────────────────────────────
## Desarrollo mensual de los pelotones: la edad media, la experiencia, la familiaridad y la forma física se acercan a su equilibrio.
## 0.1.8.3: con `n_grupos` > 1 (velocidades altas) cada mes solo se procesa UNA de las `n_grupos` partes de los pelotones, aplicándole los `n_grupos`
## meses de golpe con la fórmula cerrada (la recurrencia es lineal: x' = a·x + b → xₙ = aⁿ·x + b·(1 − aⁿ)/(1 − a)). El resultado es el mismo (salvo el
## «freno» por bajas, que usa el promedio mensual) y el coste por mes baja de ~21 ms a ~7 ms con 30.000 pelotones.
## 0.1.8.43: con `limite` (pelotones por llamada) el mes se reparte entre fotogramas: devuelve true mientras quede trabajo y hay que volver a llamarla
## (sin límite, o al terminar, devuelve false). Son ~6 ms con 30.000 pelotones: partidos en trozos de 2-3 ms caben en el presupuesto del fotograma.
var _cur_mes := 0                    # siguiente pelotón (de los que toca el grupo) que le toca al mes en curso
var _muertos_mes := 0
func avanzar_mes(grupo := 0, n_grupos := 1, limite := 1 << 30) -> bool:
	if bd == null:
		return false
	var m := RETIRO_MENSUAL
	var v_ed: PackedFloat64Array = bd.vars["edad_media"].col_f
	var v_ex: PackedFloat64Array = bd.vars["experiencia"].col_f
	var v_fa: PackedFloat64Array = bd.vars["familiaridad"].col_f
	var v_fi: PackedFloat64Array = bd.vars["forma_fisica"].col_f
	var v_bm: PackedFloat64Array = bd.vars["bajas_mes"].col_f
	var n := maxi(n_grupos, 1)
	var fn := float(n)
	var ret := pow(1.0 - m, fn)                                      # lo que queda de la edad tras n meses
	var b_ed := (1.0 - m) / 12.0 + m * EDAD_RECLUTA
	var primero: int = grupo if n > 1 else 0
	var total: int = ceili(float(_ix_todos.size() - primero) / float(n)) if _ix_todos.size() > primero else 0
	var j_fin: int = total if limite >= total - _cur_mes else _cur_mes + limite
	for j in range(_cur_mes, j_fin):                                   # 0.1.8.32: solo se recorre el grupo que toca (antes se miraban todos para saltarse 2 de cada 3)
		var ix: int = _ix_todos[primero + j * n]
		if bd.t_activo[ix] == 0:
			_muertos_mes += 1
			continue
		var e: float = v_ed[ix]
		if n == 1:
			v_ed[ix] = (1.0 - m) * (e + 1.0 / 12.0) + m * EDAD_RECLUTA
		else:
			v_ed[ix] = ret * e + b_ed * (1.0 - ret) / m
		var freno := 1.0 - minf(1.0, v_bm[ix] / fn * 4.0)           # con muchas bajas este mes, no se aprende
		var x: float = v_ex[ix]
		var f: float = v_fa[ix]
		if n == 1:
			v_ex[ix] = clampf((1.0 - m) * x + GANA_EXP_MES * (1.0 - x / 100.0) * freno, 0.0, 100.0)
			v_fa[ix] = clampf((1.0 - m) * f + GANA_FAM_MES * (1.0 - f / 100.0) * freno, 0.0, 100.0)
		else:
			var ge: float = GANA_EXP_MES * freno
			var gf: float = GANA_FAM_MES * freno
			var ce: float = 1.0 - m - ge / 100.0                      # coeficiente de x en x' = ce·x + ge
			var cf: float = 1.0 - m - gf / 100.0
			var cen := pow(ce, fn)
			var cfn := pow(cf, fn)
			v_ex[ix] = clampf(cen * x + ge * (1.0 - cen) / (1.0 - ce), 0.0, 100.0)
			v_fa[ix] = clampf(cfn * f + gf * (1.0 - cfn) / (1.0 - cf), 0.0, 100.0)
		v_fi[ix] = fisico_de_edad(v_ed[ix])
		v_bm[ix] = 0.0
	if j_fin < total:
		_cur_mes = j_fin
		return true                                                    # queda trabajo: el resto, en la próxima llamada
	_cur_mes = 0
	var muertos := _muertos_mes * n                                    # (se contaron solo los del grupo: el total es n veces eso, en promedio)
	_muertos_mes = 0
	if muertos > 4000 and muertos * 5 > _ix_todos.size():              # los pelotones disueltos se quitan de la lista (si no, cada mes recorre cada vez más muertos)
		var vivos := PackedInt32Array()
		for ix2 in _ix_todos:
			if bd.t_activo[ix2] != 0:
				vivos.append(ix2)
		_ix_todos = vivos
	version += 1
	actualizar_precios()
	return false


# ─────────────────────────────────────────────────────────────
# Acciones (las usarán la guerra, el reclutamiento y el Debug)
# ─────────────────────────────────────────────────────────────
func soldados_de(id: int) -> int:
	return int(bd.num("soldados", id, 0.0))


## Quita `n` soldados. Devuelve los que murieron de verdad. Si no queda nadie, el pelotón se disuelve.
func aplicar_bajas(id: int, n: int, motivo := "Bajas") -> int:
	if not existe(id) or n <= 0:
		return 0
	var ix: int = bd.idx(id)
	var antes := soldados_de(id)
	n = mini(n, antes)
	var c := float(n) / float(antes)
	bd.poner_f("soldados", id, float(antes - n), motivo)
	var tot: PackedFloat64Array = bd.vars["bajas_total"].col_f
	tot[ix] += n
	var bm: PackedFloat64Array = bd.vars["bajas_mes"].col_f
	bm[ix] = minf(1.0, bm[ix] + c)
	var fa: PackedFloat64Array = bd.vars["familiaridad"].col_f
	fa[ix] = fa[ix] * (1.0 - 0.7 * c)                               # perder compañeros rompe la cohesión
	var ex: PackedFloat64Array = bd.vars["experiencia"].col_f
	ex[ix] = clampf(ex[ix] * (1.0 - 0.25 * c) + 8.0 * c * (1.0 - ex[ix] / 100.0), 0.0, 100.0)
	if antes - n <= 0:
		disolver(id)
	_cambio()
	return n


## Suma reclutas a un pelotón (hasta 1.000). Devuelve cuántos entraron.
func reforzar(id: int, n: int, motivo := "Refuerzo") -> int:
	if not existe(id):
		return 0
	var cabe: int = TAM_PELOTON - soldados_de(id)
	var entra := mini(n, cabe)
	if entra <= 0:
		return 0
	var ix: int = bd.idx(id)
	var antes := float(soldados_de(id))
	var nuevo := antes + float(entra)
	var ed: PackedFloat64Array = bd.vars["edad_media"].col_f
	var ex: PackedFloat64Array = bd.vars["experiencia"].col_f
	var fa: PackedFloat64Array = bd.vars["familiaridad"].col_f
	var fi: PackedFloat64Array = bd.vars["forma_fisica"].col_f
	ed[ix] = (ed[ix] * antes + EDAD_RECLUTA * entra) / nuevo
	ex[ix] = ex[ix] * antes / nuevo                                 # los reclutas llegan sin experiencia
	fa[ix] = fa[ix] * antes / nuevo                                 # ni familiaridad
	fi[ix] = fisico_de_edad(ed[ix])
	bd.poner_f("soldados", id, nuevo, motivo)
	_cambio()
	return entra


## Recluta `n` soldados de `pais_tid`.
##   · `reg` < 0 (por defecto): forman un regimiento NUEVO en `prov_tid`.
##   · `reg` ≥ 0: refuerzan ese regimiento (completan sus pelotones incompletos y el resto forma pelotones nuevos dentro de él).
## Devuelve los IDs de los pelotones tocados; `reg_ultimo` queda con el regimiento afectado (-1 si no se pudo).
func reclutar(pais_tid: int, prov_tid: int, n: int, motivo := "Reclutamiento", reg := -1) -> Array:
	var tocados := []
	reg_ultimo = -1
	if n <= 0 or ejercito_de(pais_tid) < 0:
		return tocados
	var rid := reg
	if rid >= 0:
		if not existe_reg(rid) or pais_de_reg(rid) != pais_tid or en_marcha_reg(rid):
			return tocados
		prov_tid = prov_de(rid)
		for id in pel_de_reg[rid].duplicate():
			if n <= 0:
				break
			if soldados_de(int(id)) < TAM_PELOTON:
				var entra := reforzar(int(id), n, motivo)
				if entra > 0:
					n -= entra
					tocados.append(int(id))
	else:
		rid = _crear_reg(pais_tid, prov_tid)
		if rid < 0:
			return tocados
	while n > 0:
		var t := mini(n, TAM_PELOTON)
		tocados.append(_nuevo_pel(rid, prov_tid, t, EDAD_RECLUTA, 5.0, 0.0))
		n -= t
	reg_ultimo = rid
	if not en_marcha_reg(rid):
		llegadas.append([prov_tid, pais_tid])            # tropas reclutadas en el sitio: la guerra mira si ocupan o liberan
	_cambio()
	return tocados


## Campaña (0.1.8.2): disuelve los ejércitos de los países que no juegan y las tropas que estén en provincias excluidas.
func quitar_provincias_excluidas() -> void:
	var quitar := []
	for pid in por_pais.keys():
		var juega: bool = mundo.campana.has(String(bd.nombre_de(int(pid))))
		for id in por_pais[pid]:
			if not juega:
				quitar.append(int(id))
			else:
				var pr = _prov_de_tid.get(int(bd.ref("ubicacion", int(id))))
				if pr != null and mundo.excluidas.has(int(pr.idx)):
					quitar.append(int(id))
	for id in quitar:
		disolver(int(id))


func disolver(id: int) -> void:
	if not existe(id):
		return
	var prov := int(bd.ref("ubicacion", id))
	var pais := pais_de(id)
	if por_prov.has(prov):
		por_prov[prov].erase(id)
	if por_pais.has(pais):
		por_pais[pais].erase(id)
	if en_marcha.has(id):                              # un pelotón en el camino que desaparece sale de su columna
		var m: Dictionary = marchas.get(int(en_marcha[id]), {})
		en_marcha.erase(id)
		if not m.is_empty():
			m["pel"].erase(id)
			if m["pel"].is_empty():
				marchas.erase(int(m["id"]))
				marcha_de_reg.erase(int(m.get("reg", -1)))
			version_marchas += 1
	var rid := int(reg_de_pel.get(id, -1))
	reg_de_pel.erase(id)
	if rid >= 0 and pel_de_reg.has(rid):
		pel_de_reg[rid].erase(id)
	bd.desactivar(id)
	if rid >= 0:
		_limpiar_reg(rid)
	_cambio()


## Teletransporta el REGIMIENTO de un pelotón (Debug). Los que van por el camino se ignoran: se mueven solo con su marcha.
func mover(id: int, prov_tid: int, motivo := "Movimiento") -> void:
	if not existe(id) or en_marcha.has(id):
		return
	var rid := reg_de(id)
	mover_reg(rid, prov_tid, motivo)


func mover_reg(rid: int, prov_tid: int, motivo := "Movimiento") -> void:
	if not existe_reg(rid) or en_marcha_reg(rid):
		return
	var prov := prov_de(rid)
	if prov == prov_tid:
		return
	for id in pel_de_reg[rid]:
		if por_prov.has(prov):
			por_prov[prov].erase(id)
		bd.poner_i("ubicacion", int(id), prov_tid, motivo)
		if not por_prov.has(prov_tid):
			por_prov[prov_tid] = []
		por_prov[prov_tid].append(id)
	if regs_prov.has(prov):
		regs_prov[prov].erase(rid)
	if not regs_prov.has(prov_tid):
		regs_prov[prov_tid] = []
	regs_prov[prov_tid].append(rid)
	prov_de_reg[rid] = prov_tid
	llegadas.append([prov_tid, pais_de_reg(rid)])
	_cambio()


# ─────────────────────────────────────────────────────────────
# Órdenes de tropas (0.1.7.9.9E): dividir, juntar y marchar
# ─────────────────────────────────────────────────────────────
## Parte un pelotón: `n` soldados pasan a un pelotón NUEVO en la misma provincia (mismos datos de edad, experiencia y
## familiaridad). Devuelve el ID del nuevo o -1.
func dividir(id: int, n: int, motivo := "División") -> int:
	if not existe(id) or en_marcha.has(id):
		return -1
	var total := soldados_de(id)
	if n <= 0 or n >= total:
		return -1
	var prov := int(bd.ref("ubicacion", id))
	var edad: float = bd.num("edad_media", id)
	var exp_: float = bd.num("experiencia", id)
	var fam: float = bd.num("familiaridad", id)
	var nuevo := _nuevo_pel(reg_de(id), prov, n, edad, exp_, fam)    # queda en el MISMO regimiento
	bd.poner_f("soldados", id, float(total - n), motivo)
	_cambio()
	return nuevo


## Une dos pelotones del mismo país en la misma provincia: `origen` entra en `destino` y desaparece.
func _fusionar(destino: int, origen: int) -> void:
	var sd := float(soldados_de(destino))
	var so := float(soldados_de(origen))
	var t := sd + so
	if t <= 0.0:
		return
	var ixd: int = bd.idx(destino)
	var ed: PackedFloat64Array = bd.vars["edad_media"].col_f
	var ex: PackedFloat64Array = bd.vars["experiencia"].col_f
	var fa: PackedFloat64Array = bd.vars["familiaridad"].col_f
	var fi: PackedFloat64Array = bd.vars["forma_fisica"].col_f
	var bt: PackedFloat64Array = bd.vars["bajas_total"].col_f
	ed[ixd] = (ed[ixd] * sd + bd.num("edad_media", origen) * so) / t
	ex[ixd] = (ex[ixd] * sd + bd.num("experiencia", origen) * so) / t
	fa[ixd] = (fa[ixd] * sd + bd.num("familiaridad", origen) * so) / t
	fi[ixd] = fisico_de_edad(ed[ixd])
	bt[ixd] += bd.num("bajas_total", origen)
	bd.poner_f("soldados", destino, t, "Fusión")
	bd.poner_f("soldados", origen, 0.0, "Fusión")
	disolver(origen)


## Junta los pelotones incompletos DENTRO de un regimiento (para no arrastrar decenas de pelotones de 12 soldados).
## Devuelve cuántas fusiones hizo. No cruza regimientos.
func compactar_reg(rid: int) -> int:
	if not existe_reg(rid) or en_marcha_reg(rid):
		return 0
	var lista := []
	for id in pel_de_reg[rid]:
		if soldados_de(int(id)) < TAM_PELOTON:
			lista.append(int(id))
	if lista.size() < 2:
		return 0
	lista.sort_custom(func(a, b): return soldados_de(a) > soldados_de(b) or (soldados_de(a) == soldados_de(b) and a < b))
	var hechas := 0
	for j in range(lista.size() - 1, 0, -1):
		var pequeno: int = lista[j]
		if not existe(pequeno):
			continue
		var ss := soldados_de(pequeno)
		for k in j:
			var grande: int = lista[k]
			if existe(grande) and soldados_de(grande) + ss <= TAM_PELOTON:
				_fusionar(grande, pequeno)
				hechas += 1
				break
	if hechas > 0:
		_cambio()
	return hechas


## UNIR (orden deliberada): `origen` pasa a ser parte de `destino`. Deben ser del mismo país, estar en la misma provincia y estar quietos.
## Devuelve {"ok", "msg"}.
func unir(destino: int, origen: int) -> Dictionary:
	if destino == origen:
		return {"ok": false, "msg": "Elige otro regimiento."}
	if not existe_reg(destino) or not existe_reg(origen):
		return {"ok": false, "msg": "Ese regimiento ya no existe."}
	if pais_de_reg(destino) != pais_de_reg(origen):
		return {"ok": false, "msg": "Solo se unen regimientos del mismo país."}
	if en_marcha_reg(destino) or en_marcha_reg(origen):
		return {"ok": false, "msg": "Un regimiento en marcha no se puede unir."}
	if prov_de(destino) != prov_de(origen):
		return {"ok": false, "msg": "Tienen que estar en la misma provincia."}
	var n_origen := soldados_reg(origen)
	for id in pel_de_reg[origen].duplicate():
		_poner_en_reg(int(id), destino, "Unión")
	compactar_reg(destino)
	_cambio()
	return {"ok": true, "msg": "%s se unió a %s (%d soldados)." % [nombre_reg(origen), nombre_reg(destino), n_origen], "reg": destino}


## DIVIDIR (orden deliberada): `n` soldados del regimiento pasan a un regimiento NUEVO en la misma provincia.
## Devuelve el ID del regimiento nuevo o -1.
func dividir_reg(rid: int, n: int, motivo := "División") -> int:
	if not existe_reg(rid) or en_marcha_reg(rid):
		return -1
	var total := soldados_reg(rid)
	if n <= 0 or n >= total:
		return -1
	var pais := pais_de_reg(rid)
	var prov := prov_de(rid)
	var t_s := Time.get_ticks_usec()
	# Del más grande al más chico (a igual tamaño, el de menor ID). Una clave entera por pelotón y orden nativo: con una función de
	# comparación propia, partir un regimiento de la IA (cientos de pelotones) costaba ~5 ms; así, una fracción de ms.
	var pel_reg: Array = pel_de_reg[rid]
	var claves := PackedInt64Array()
	claves.resize(pel_reg.size())
	for i in pel_reg.size():
		var pid: int = int(pel_reg[i])
		claves[i] = (1000000 - mini(soldados_de(pid), 999999)) * 4294967296 + pid
	claves.sort()
	var propios: Array = []
	propios.resize(claves.size())
	for i in claves.size():
		propios[i] = int(claves[i] & 0xFFFFFFFF)
	_p("div.orden", t_s)
	t_s = Time.get_ticks_usec()
	var elegidos := []
	var falta := n
	for id in propios:
		if falta <= 0:
			break
		var so := soldados_de(int(id))
		if so <= falta:
			elegidos.append(int(id))
			falta -= so
		else:
			var nuevo := dividir(int(id), falta, motivo)
			if nuevo >= 0:
				elegidos.append(nuevo)
			falta = 0
	_p("div.elegir", t_s)
	if elegidos.is_empty():
		return -1
	t_s = Time.get_ticks_usec()
	var nuevo_reg := _crear_reg(pais, prov)
	_p("div.crear_reg", t_s)
	if nuevo_reg < 0:
		return -1
	t_s = Time.get_ticks_usec()
	for id in elegidos:
		_poner_en_reg(int(id), nuevo_reg, motivo)
	_p("div.poner", t_s)
	_cambio()
	return nuevo_reg


## DISOLVER (orden deliberada): los soldados vuelven a la vida civil (dejan de costar mantenimiento; no se devuelve el dinero).
func disolver_reg(rid: int) -> int:
	if not existe_reg(rid):
		return 0
	var n := soldados_reg(rid)
	for id in pel_de_reg[rid].duplicate():
		disolver(int(id))
	_limpiar_reg(rid)
	return n


## DESERCIÓN POR IMPAGO (0.1.8.1): cada pelotón del país pierde `frac` de sus soldados (mínimo 1). No cuenta como baja de combate.
## Devuelve cuántos soldados se fueron.
func desertar_pais(pais_tid: int, frac: float, motivo := "Deserción por impago") -> int:
	var total := 0
	for id in por_pais.get(pais_tid, []).duplicate():
		var s := soldados_de(int(id))
		if s <= 0:
			continue
		var n := clampi(int(ceilf(float(s) * frac)), 1, s)
		total += n
		if s - n <= 0:
			disolver(int(id))
		else:
			bd.poner_f("soldados", int(id), float(s - n), motivo)
	if total > 0:
		_cambio()
	return total


## ¿Hay tropas quietas, en la provincia `pi` (índice), de algún país en guerra con `pais_tid`?
func hay_enemigos_en(pi: int, pais_tid: int) -> bool:
	if mundo.guerra == null or pi < 0 or pi >= mundo.provincias.size():
		return false
	var tid: int = int(mundo.provincias[pi].tid)
	for rid in regs_prov.get(tid, []):
		var p: int = pais_de_reg(int(rid))
		if p != pais_tid and mundo.guerra.en_guerra(pais_tid, p):
			return true
	return false


## Provincia (índice) más cercana por TIERRA a la que puede retirarse el regimiento `rid`: del mismo país y sin tropas de países con los que
## está en guerra. Busca hasta `prof_max` provincias de distancia. -1 si no hay (está rodeado o sin datos de vecindad).
func refugio_de(rid: int, prof_max := 5) -> int:
	if red == null or not red.listo or not existe_reg(rid) or en_marcha_reg(rid):
		return -1
	var pais := pais_de_reg(rid)
	var origen = _prov_de_tid.get(prov_de(rid))
	if origen == null:
		return -1
	var visto := {int(origen.idx): true}
	var frontera: Array = [int(origen.idx)]
	for _d in prof_max:
		var sig := []
		for pi in frontera:
			for q in red.vecinos(int(pi)):
				var qi: int = int(q)
				if visto.has(qi):
					continue
				visto[qi] = true
				var t: Array = red.tramo(int(pi), qi)
				if t.is_empty() or int(t[1]) == 1:
					continue                                    # por mar no se huye
				if dueno_de_provincia(qi) == pais and not hay_enemigos_en(qi, pais):
					return qi
				sig.append(qi)
		frontera = sig
	return -1


## El regimiento sale hacia su refugio más cercano (retirada tras perder una batalla, o salida tras una paz). {"ok", "destino"}.
func retirar_reg(rid: int) -> Dictionary:
	var d := refugio_de(rid)
	if d < 0:
		return {"ok": false, "destino": -1}
	var r: Dictionary = ordenar_marcha_reg(rid, 0, d)
	return {"ok": bool(r.get("ok", false)), "destino": d}


## Un país absorbe al ejército de otro (anexión, o conquista de su última provincia): todos los pelotones y columnas en marcha del
## origen pasan al ejército del destino. El ejército del origen queda vacío. Devuelve cuántos pelotones cambiaron de dueño.
func transferir_tropas(origen_tid: int, destino_tid: int) -> int:
	if origen_tid == destino_tid:
		return 0
	var id_d := ejercito_de(destino_tid)
	var lista: Array = por_pais.get(origen_tid, []).duplicate()
	if id_d < 0 or lista.is_empty():
		return 0
	var n: int = bd.reparentar_lote(lista, id_d)
	var regs: Array = regs_pais.get(origen_tid, []).duplicate()
	if not regs.is_empty():
		bd.reparentar_lote(regs, id_d)
		if not regs_pais.has(destino_tid):
			regs_pais[destino_tid] = []
		regs_pais[destino_tid].append_array(regs)
		regs_pais[origen_tid] = []
	if not por_pais.has(destino_tid):
		por_pais[destino_tid] = []
	por_pais[destino_tid].append_array(lista)
	por_pais[origen_tid] = []
	for mid in marchas:
		if int(marchas[mid]["pais"]) == origen_tid:
			marchas[mid]["pais"] = destino_tid
	version_marchas += 1
	_cambio()
	return n


func soldados_en_provincia(prov_tid: int, pais_tid: int) -> int:
	var t := 0
	for id in por_prov.get(prov_tid, []):
		if pais_de(int(id)) == pais_tid:
			t += soldados_de(int(id))
	return t


func soldados_marcha(m: Dictionary) -> int:
	var t := 0
	for id in m["pel"]:
		t += soldados_de(int(id))
	return t


## País dueño de una provincia (ID de territorio del país) o -1.
func dueno_de_provincia(pi: int) -> int:
	if pi < 0 or pi >= mundo.provincias.size():
		return -1
	var nombre: String = mundo.provincias[pi].pais
	if nombre == "" or not mundo.paises.has(nombre):
		return -1
	return int(mundo.paises[nombre].tid)


## Manda el regimiento `rid` (o solo `n` soldados suyos; `n` ≤ 0 o ≥ total = todo) hacia la provincia número `destino_pi`
## (índice en Mundo.provincias). Si la provincia es de otro país (que no sea aliado o vasallo), ENTRAR ES ATACAR: se declara la guerra.
## Devuelve {"ok", "msg", "marcha", "reg", "guerra" (ID si se declaró una), "contra" (ID de país), "soldados", "dias", "tramos"}.
var prof := {}                         # sección -> [microsegundos totales, llamadas] (Debug > Rend.)

## Anota en `prof` el tiempo de una sección (ver perfil.gd).
func _p(sec: String, t0: int) -> void:
	PerfilScript.anotar(prof, sec, t0)


func ordenar_marcha_reg(rid: int, n: int, destino_pi: int) -> Dictionary:
	if red == null or not red.listo:
		return {"ok": false, "msg": "Faltan los datos de vecindad (datos/vecinos_prov.json)."}
	if not existe_reg(rid):
		return {"ok": false, "msg": "Ese regimiento ya no existe."}
	if en_marcha_reg(rid):
		return {"ok": false, "msg": "Ese regimiento ya va en marcha."}
	var prov_tid := prov_de(rid)
	var pais_tid := pais_de_reg(rid)
	var origen = _prov_de_tid.get(prov_tid)
	if origen == null:
		return {"ok": false, "msg": "Provincia de origen desconocida."}
	if destino_pi < 0 or destino_pi >= mundo.provincias.size():
		return {"ok": false, "msg": "Elige una provincia de destino."}
	if int(origen.idx) == destino_pi:
		return {"ok": false, "msg": "Las tropas ya están en esa provincia."}
	if mundo.provincia_excluida(destino_pi):
		return {"ok": false, "msg": "Esa provincia no forma parte de la campaña."}
	var t_o := Time.get_ticks_usec()
	var ruta: PackedInt32Array = red.ruta(int(origen.idx), destino_pi)
	_p("orden.ruta", t_o)
	if ruta.size() < 2:
		return {"ok": false, "msg": "No hay ruta por tierra ni por mar corto hasta esa provincia."}
	var total := soldados_reg(rid)
	if total <= 0:
		return {"ok": false, "msg": "No hay soldados disponibles para mover."}
	# En la campaña solo se puede atacar a países con IA (o al jugador): sin competencia no hay conquista. Se mira ANTES de partir el regimiento.
	var rival: int = mundo.rival_por_entrar(pais_tid, destino_pi)          # país al que habría que declarar la guerra (−1 si no hace falta)
	if rival >= 0 and not mundo.puede_atacar(pais_tid, rival):
		return {"ok": false, "msg": "%s no tiene IA: en la campaña solo se conquistan países controlados por la IA. Actívasela en Debug > IA." % bd.nombre_de(rival)}
	var marcha_reg := rid
	if n > 0 and n < total:                             # solo una parte: se parte el regimiento (orden deliberada del jugador)
		t_o = Time.get_ticks_usec()
		marcha_reg = dividir_reg(rid, n, "División para marchar")
		_p("orden.dividir", t_o)
		if marcha_reg < 0:
			return {"ok": false, "msg": "No se pudo formar la columna."}
	else:
		n = total
	# ¿Entrar es atacar?
	var res_guerra := {"id": -1, "contra": -1}
	if rival >= 0:
		res_guerra["id"] = mundo.guerra.declarar(pais_tid, rival, "Ataque a " + String(mundo.provincias[destino_pi].nombre))
		res_guerra["contra"] = rival
	# Sale la columna
	var pel: Array = pel_de_reg[marcha_reg].duplicate()
	for id in pel:                                      # salen de la provincia: ya no cuentan allí
		if por_prov.has(prov_tid):
			por_prov[prov_tid].erase(id)
	if regs_prov.has(prov_tid):
		regs_prov[prov_tid].erase(marcha_reg)
	prov_de_reg[marcha_reg] = -1
	var mid := siguiente_marcha
	siguiente_marcha += 1
	for id in pel:
		en_marcha[id] = mid
	marcha_de_reg[marcha_reg] = mid
	marchas[mid] = {"id": mid, "pais": pais_tid, "reg": marcha_reg, "pel": pel, "ruta": ruta, "k": 0, "km": 0.0, "parar": false}
	_cambio()
	version_marchas += 1
	var dias: float = red.coste_ruta(ruta) / VEL_MARCHA_KM_DIA
	var msg := "%s en marcha: %d soldados, %d provincias, unos %d días." % [nombre_reg(marcha_reg), n, ruta.size() - 1, int(ceilf(dias))]
	if int(res_guerra["id"]) >= 0:
		msg = "¡GUERRA con %s! %s" % [bd.nombre_de(int(res_guerra["contra"])), msg]
	return {"ok": true, "marcha": mid, "reg": marcha_reg, "soldados": n, "dias": dias, "tramos": ruta.size() - 1,
		"guerra": int(res_guerra["id"]), "contra": int(res_guerra["contra"]), "msg": msg}


## La columna sigue hasta la próxima provincia y allí se queda.
func detener_marcha(mid: int) -> void:
	if marchas.has(mid):
		marchas[mid]["parar"] = true
		version_marchas += 1


## `k` días de marcha para todas las columnas (lo llama el reloj del juego; 0.1.8.3: varios días de una vez, el coste no depende de k).
func avanzar_dia(k := 1) -> void:
	if marchas.is_empty() or red == null:
		return
	var t_d := Time.get_ticks_usec()
	var terminadas := []
	for mid in marchas.keys():
		var m: Dictionary = marchas[mid]
		var resto := VEL_MARCHA_KM_DIA * float(k)
		var ruta: PackedInt32Array = m["ruta"]
		while resto > 0.0:
			var a: int = ruta[int(m["k"])]
			var b: int = ruta[int(m["k"]) + 1]
			var falta: float = red.coste_tramo(a, b) - float(m["km"])
			if resto < falta:
				m["km"] = float(m["km"]) + resto
				break
			resto -= falta
			m["km"] = 0.0
			m["k"] = int(m["k"]) + 1
			var tid: int = int(mundo.provincias[b].tid)
			for id in m["pel"]:
				bd.poner_i("ubicacion", int(id), tid, "Marcha")
			if int(m["k"]) >= ruta.size() - 1 or bool(m["parar"]):
				terminadas.append(mid)
				break
	_p("dia.avance", t_d)
	t_d = Time.get_ticks_usec()
	for mid in terminadas:
		_terminar_marcha(int(mid))
	_p("dia.terminar", t_d)
	version_marchas += 1
	if not terminadas.is_empty():
		_cambio()


func _terminar_marcha(mid: int) -> void:
	if not marchas.has(mid):
		return
	var m: Dictionary = marchas[mid]
	var ruta: PackedInt32Array = m["ruta"]
	var pi_final: int = ruta[int(m["k"])]
	var tid_final: int = int(mundo.provincias[pi_final].tid)
	if not por_prov.has(tid_final):
		por_prov[tid_final] = []
	for id in m["pel"]:
		en_marcha.erase(id)
		por_prov[tid_final].append(id)
	marchas.erase(mid)
	var rid: int = int(m.get("reg", -1))
	if rid >= 0 and existe_reg(rid):                    # llega como regimiento propio: NO se junta con los que ya estaban (hay que unirlos)
		marcha_de_reg.erase(rid)
		if not regs_prov.has(tid_final):
			regs_prov[tid_final] = []
		regs_prov[tid_final].append(rid)
		prov_de_reg[rid] = tid_final
		llegadas.append([tid_final, int(m["pais"])])


## Días que le faltan a la columna para llegar.
func dias_restantes(m: Dictionary) -> float:
	var ruta: PackedInt32Array = m["ruta"]
	var falta := -float(m["km"])
	for i in range(int(m["k"]), ruta.size() - 1):
		falta += red.coste_tramo(ruta[i], ruta[i + 1])
	return maxf(falta, 0.0) / VEL_MARCHA_KM_DIA


# ─────────────────────────────────────────────────────────────
# Consultas
# ─────────────────────────────────────────────────────────────
func en_provincia(prov_tid: int) -> Array:
	return por_prov.get(prov_tid, [])


func de_pais(pais_tid: int) -> Array:
	return por_pais.get(pais_tid, [])


## IDs de los pelotones que están en cualquiera de estas provincias (IDs de territorio).
func en_provincias(tids: Array) -> Array:
	var r := []
	for t in tids:
		r.append_array(por_prov.get(int(t), []))
	return r


## Totales y promedios (ponderados por soldados) de una lista de IDs de pelotón. Usa los mismos cálculos que
## `BaseDatos.agregado` (suma y media ponderada por soldados).
func resumen(lista: Array) -> Dictionary:
	var d := {"soldados": 0, "pelotones": lista.size(), "bajas": 0, "edad": 0.0, "exp": 0.0, "fam": 0.0, "fis": 0.0}
	if lista.is_empty():
		return d
	d["soldados"] = int(bd.suma("soldados", lista))
	d["bajas"] = int(bd.suma("bajas_total", lista))
	d["edad"] = bd.media_ponderada("edad_media", "soldados", lista)
	d["exp"] = bd.media_ponderada("experiencia", "soldados", lista)
	d["fam"] = bd.media_ponderada("familiaridad", "soldados", lista)
	d["fis"] = bd.media_ponderada("forma_fisica", "soldados", lista)
	return d


func soldados_totales() -> int:
	var s := 0
	for ix in _ix_todos:
		if bd.t_activo[ix] == 1:
			s += int(bd.vars["soldados"].col_f[ix])
	return s


func provincia_por_tid(tid: int):
	return _prov_de_tid.get(tid)


## Datos de un pelotón para la interfaz.
func ficha(id: int) -> Dictionary:
	if not existe(id):
		return {}
	var ix: int = bd.idx(id)
	var prov := int(bd.ref("ubicacion", id))
	var pr = _prov_de_tid.get(prov)
	return {"id": id, "numero": numero(id), "pais_tid": pais_de(id), "prov_tid": prov,
		"provincia": pr.nombre if pr != null else "?", "soldados": soldados_de(id), "edad": bd.num("edad_media", id),
		"exp": bd.num("experiencia", id), "fam": bd.num("familiaridad", id), "fis": bd.num("forma_fisica", id),
		"bajas_mes": bd.num("bajas_mes", id), "bajas": int(bd.num("bajas_total", id)), "ix": ix, "reg": reg_de(id)}


## Datos de un regimiento para la interfaz.
func ficha_reg(rid: int) -> Dictionary:
	if not existe_reg(rid):
		return {}
	var lista: Array = pel_de_reg.get(rid, [])
	var res: Dictionary = resumen(lista)
	var prov := prov_de(rid)
	var en_camino := en_marcha_reg(rid)
	if en_camino and not lista.is_empty():
		prov = int(bd.ref("ubicacion", int(lista[0])))
	var pr = _prov_de_tid.get(prov)
	var d := {"id": rid, "nombre": nombre_reg(rid), "pais_tid": pais_de_reg(rid), "prov_tid": prov,
		"provincia": pr.nombre if pr != null else "?", "soldados": int(res["soldados"]), "pelotones": lista.size(),
		"edad": float(res["edad"]), "exp": float(res["exp"]), "fam": float(res["fam"]), "fis": float(res["fis"]),
		"bajas": int(res["bajas"]), "en_marcha": en_camino, "marcha": int(marcha_de_reg.get(rid, -1))}
	return d


# ─────────────────────────────────────────────────────────────
# Precios (0.1.7.9.9F-c): cada país paga por tener soldados
# ─────────────────────────────────────────────────────────────
## PIB por habitante actual de un país (US$), a partir de la producción de sus provincias.
func pib_por_habitante(pais_tid: int) -> float:
	var nombre: String = bd.nombre_de(pais_tid)
	if not mundo.paises.has(nombre):
		return 0.0
	var pob: float = mundo.poblacion_de(nombre)
	if pob <= 0.0:
		return 0.0
	return mundo.produccion_anual_usd(nombre) / pob


## Recalcula el precio de una unidad (1.000 soldados) de cada país: mantenimiento al año y costo de reclutar. Se llama al empezar
## y cada mes. Usa los factores de cada ejército (`factor_mantenimiento`, `factor_reclutamiento`, editables en la base).
## `inicial`: escribe también los factores por defecto (sin historial).
func actualizar_precios(inicial := false) -> void:
	if bd == null:
		return
	for pa in ej_de_pais:
		var id_ej: int = int(ej_de_pais[pa])
		if inicial:
			bd.inicial_f("factor_mantenimiento", id_ej, FACTOR_MANT_DEFECTO)
			bd.inicial_f("factor_reclutamiento", id_ej, FACTOR_RECL_DEFECTO)
		var pc := pib_por_habitante(int(pa))
		var fm: float = bd.num("factor_mantenimiento", id_ej, FACTOR_MANT_DEFECTO)
		var fr: float = bd.num("factor_reclutamiento", id_ej, FACTOR_RECL_DEFECTO)
		if inicial:
			bd.inicial_f("mantenimiento_unidad", id_ej, fm * pc * TAM_PELOTON)
			bd.inicial_f("costo_reclutamiento_unidad", id_ej, fr * pc * TAM_PELOTON)
		else:
			bd.poner_f("mantenimiento_unidad", id_ej, fm * pc * TAM_PELOTON, "Precio mensual")
			bd.poner_f("costo_reclutamiento_unidad", id_ej, fr * pc * TAM_PELOTON, "Precio mensual")
	if not inicial:
		bd.version_eco += 1                              # la caché de balances diarios (Mundo._armar_balances) depende de los precios


## Precio de una unidad (1.000 soldados) del país en US$: {"mant": al año, "recl": pago único}.
func precios_unidad_usd(pais_tid: int) -> Dictionary:
	var id_ej := ejercito_de(pais_tid)
	if id_ej < 0:
		return {"mant": 0.0, "recl": 0.0}
	return {"mant": bd.num("mantenimiento_unidad", id_ej, 0.0), "recl": bd.num("costo_reclutamiento_unidad", id_ej, 0.0)}


## Mantenimiento por día (US$) de `soldados` soldados del país.
func mantenimiento_diario_usd(pais_tid: int, soldados: int) -> float:
	return float(soldados) / float(TAM_PELOTON) * float(precios_unidad_usd(pais_tid)["mant"]) / 365.25


## Costo en US$ de reclutar `soldados` soldados del país.
func costo_reclutar_usd(pais_tid: int, soldados: int) -> float:
	return float(soldados) / float(TAM_PELOTON) * float(precios_unidad_usd(pais_tid)["recl"])
