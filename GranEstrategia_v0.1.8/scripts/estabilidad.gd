extends RefCounted
## ESTABILIDAD SOCIAL por provincia (0.1.8.43). Usa la variable que ya existía, `favorabilidad` (0-100; ya multiplicaba la producción: ×(0,5 + fav/100)).
##
## Cada provincia se revisa UNA vez cada CICLO_DIAS días (en lotes: el día reparte el 1/30 del total, sin tirones) y su favorabilidad se acerca hasta
## PASO_MAX puntos a su META. La meta es la suma de:
##   · BASE (56)
##   · core nacional: +5 si es tierra propia de su dueño, −6 si es core de otro país, −2 si no tiene core
##   · cultura distinta a la de su dueño: −8
##   · conquista reciente: hasta −20, se disipa en 5 años
##   · distancia a la capital: hasta −10 (la capital misma: +10)
##   · país en guerra: −4; provincia ocupada por el enemigo: −18; devastación: hasta −20
##   · SOBREEXTENSIÓN: hasta −20 cuando el país tiene mucho más territorio que con el que empezó (a partir de 1,2 × y hasta 2,8 ×), y hasta −6 por tamaño absoluto
##   · guarnición: hasta +8 según los soldados propios que haya en la provincia
## Con la favorabilidad por debajo de UMBRAL_REVUELTA durante MESES_REVUELTA ciclos seguidos, la provincia se AMOTINA (junto con las vecinas del mismo pueblo
## que también están agitadas). El dueño puede PAGAR a los notables, REPRIMIR con tropas o CONCEDER la independencia (la tierra vuelve a su core nacional:
## el país reaparece si estaba anexado). La IA elige sola; al jugador se le abre un pop-up (aviso «revuelta»). Si no hay a quién devolverla, los rebeldes saquean (devastación).
## No hace falta tocar la base de datos: se escribe directo en la columna (como el desarrollo mensual) y la producción lo recoge con el siguiente cierre de mes.

const BDScript := preload("res://scripts/base_datos.gd")
const CICLO_DIAS := 30
const BASE := 56.0
const PASO_MAX := 5.0
const UMBRAL_AGITADA := 28.0               # por debajo, la provincia cuenta como agitada (y se suma al grupo de un motín)
const UMBRAL_REVUELTA := 15.0
const MESES_REVUELTA := 2
const LOTE := 90                           # provincias que se revisan por llamada de fase (~0,5 ms)
const GRUPO_MAX := 10
const PAGO_FRAC := 0.35                    # lo que cuesta calmar a los notables: esta fracción de lo que produce un año el grupo
const FUERZA_FRAC := 0.0012                # soldados por habitante para reprimir (más ENVIO_MIN de la IA)
const FUERZA_MIN := 1500.0
const INMUNE_PAGO := 365
const INMUNE_REPRESION := 120
const MARCA_BALANCE_DIAS := 15             # un país solo marca su balance como sucio cada tantos días por culpa de la estabilidad

var mundo
var bd
var ej
var _activas := PackedInt32Array()         # índices de las provincias que existen en este modo
var _clave_modo := ""
var _cursor := 0
var _pendiente := 0
var _en_paso := false
var conquistada := {}                      # índice de provincia -> día de la conquista
var _malos := {}                           # índice -> ciclos seguidos por debajo de UMBRAL_REVUELTA
var _inmune := {}                          # índice -> día hasta el que no se amotina
var _c_cn := PackedInt32Array()            # columnas de la base (se vuelven a pedir en cada llamada: pueden cambiar de sitio si la base crece)
var _c_cc := PackedStringArray()
var _c_oc := PackedInt32Array()
var _c_gu := PackedFloat64Array()
var _c_dv := PackedFloat64Array()
var _paises := {}                          # ID país -> {nombre, e, cap, cap_dia, cult, ix, base}
var _marca := {}                           # ID país -> día del último `marcar_balance` por estabilidad
var _res_cache := {}                       # ID país -> [día, media simple, agitadas, total]
var _veces := {}                           # índice de provincia -> cuántos motines lleva (cada uno encarece el siguiente)
var motines := 0
var independencias := 0
var pagos := 0
var represiones := 0
var sin_estado := 0
var revisadas := 0                         # provincias revisadas en total (pruebas)
var ms_max := 0.0
var usec_total := 0                        # microsegundos gastados en total en `fase_dia` (Debug > Rend. y pruebas)


func iniciar(m) -> void:
	mundo = m
	bd = m.bd
	ej = m.ejercito


func dia() -> int:
	return mundo.ia.dia_n if mundo.ia != null else 0


static func nivel(v: float) -> String:
	if v >= 60.0:
		return "Leal"
	if v >= 40.0:
		return "Estable"
	if v >= UMBRAL_AGITADA:
		return "Descontenta"
	if v >= UMBRAL_REVUELTA:
		return "Agitada"
	return "En revuelta"


# ─────────────────────────────────────────────────────────────
# Meta de una provincia
# ─────────────────────────────────────────────────────────────
func _cargar_columnas() -> void:
	_c_cn = bd.vars["core_nacional"].col_i if bd.vars.has("core_nacional") else PackedInt32Array()
	_c_cc = bd.vars["core_cultural"].col_s if bd.vars.has("core_cultural") else PackedStringArray()
	_c_oc = bd.vars["ocupante"].col_i
	_c_gu = bd.vars["guerras_activas"].col_f
	_c_dv = bd.vars["devastacion"].col_f


func _info_pais(t: int) -> Dictionary:
	var f = _paises.get(t)
	var d := dia()
	if f != null and d - int(f["cap_dia"]) < 365:
		return f
	var nom: String = bd.nombre_de(t)
	var e = mundo.paises.get(nom)
	var cap := -1
	if e != null:
		var ct: int = ej._provincia_capital(nom)
		if ct >= 0:
			var pc = ej.provincia_por_tid(ct)
			if pc != null:
				cap = int(pc.idx)
	if f == null:
		var cult := ""
		if mundo.cores != null and mundo.cores.listo and e != null:
			cult = mundo.cores.cultura_de_pais(nom)
		f = {"nombre": nom, "e": e, "cult": cult, "ix": bd.idx(t), "base": maxi((e.provincias as Array).size(), 1) if e != null else 1}
		_paises[t] = f
	f["cap"] = cap                                                           # la capital puede cambiar de manos: se recalcula una vez al año
	f["cap_dia"] = d
	return f


## Meta de la provincia `pi` (fila `ix` en la base, dueño `due`). Con `det` (un Array) añade las partes [texto, valor] para la interfaz.
func _meta(pi: int, ix: int, due: int, d: int, det = null) -> float:
	var f: Dictionary = _info_pais(due)
	var m := BASE
	if det != null:
		det.append(["Base", BASE])
	var cn: int = _c_cn[ix] if ix < _c_cn.size() else -1
	var x := 0.0
	if cn == due:
		x = 5.0
	elif cn >= 0:
		x = -6.0
	else:
		x = -2.0
	m += x
	if det != null:
		det.append(["Tierra propia" if x > 0.0 else ("Tierra de otro país (core ajeno)" if x < -3.0 else "Sin core nacional"), x])
	var cult_p: String = _c_cc[ix] if ix < _c_cc.size() else ""
	if cult_p != "" and String(f["cult"]) != "" and cult_p != String(f["cult"]):
		m -= 8.0
		if det != null:
			det.append(["Cultura distinta a la de su dueño", -8.0])
	var t0 = conquistada.get(pi)
	if t0 != null:
		var anios := float(d - int(t0)) / 365.0
		if anios < 5.0:
			x = -20.0 * (1.0 - anios / 5.0)
			m += x
			if det != null:
				det.append(["Conquista reciente", x])
	var cap: int = int(f["cap"])
	if cap == pi:
		m += 10.0
		if det != null:
			det.append(["Es la capital", 10.0])
	elif cap >= 0:
		var centros: PackedVector2Array = ej.red.centros
		var dx: float = fposmod(centros[pi].x - centros[cap].x + 1200.0, 2400.0) - 1200.0
		var dy: float = centros[pi].y - centros[cap].y
		x = -minf(10.0, sqrt(dx * dx + dy * dy) / 9.0)
		m += x
		if det != null and x < -0.5:
			det.append(["Lejos de la capital", x])
	var ix_p: int = int(f["ix"])
	if ix_p >= 0 and _c_gu[ix_p] > 0.0:
		m -= 4.0
		if det != null:
			det.append(["País en guerra", -4.0])
	var oc: int = _c_oc[ix]
	if oc >= 0 and oc != due:
		m -= 18.0
		if det != null:
			det.append(["Ocupada por el enemigo", -18.0])
	var dv: float = _c_dv[ix]
	if dv > 0.0:
		x = -20.0 * dv
		m += x
		if det != null and x < -0.5:
			det.append(["Devastación", x])
	var e = f["e"]
	if e != null:
		var n: int = (e.provincias as Array).size()
		var r: float = float(n) / float(maxi(int(f["base"]), 1))
		x = -20.0 * clampf((r - 1.2) / 1.6, 0.0, 1.0) - clampf(float(n) / 60.0, 0.0, 6.0)
		m += x
		if det != null and x < -0.5:
			det.append(["Sobreextensión del país (%d provincias, empezó con %d)" % [n, int(f["base"])], x])
	var s := _guarnicion(pi, due)
	if s > 0:
		x = minf(8.0, float(s) / 2500.0)
		m += x
		if det != null and x > 0.4:
			det.append(["Guarnición (%d soldados)" % s, x])
	return clampf(m, 0.0, 100.0)


func _guarnicion(pi: int, due: int) -> int:
	var regs = ej.regs_prov.get(mundo.provincias[pi].tid)
	if regs == null:
		return 0
	var s := 0
	for rid in regs:
		if ej.pais_de_reg(int(rid)) == due:
			s += ej.soldados_reg(int(rid))
	return s


## Las partes de la meta de una provincia para la interfaz: {"fav", "meta", "partes": [[texto, valor]]}.
func desglose(pi: int) -> Dictionary:
	var pr = mundo.provincias[pi]
	_cargar_columnas()
	var due: int = bd.vars["propietario"].col_i[pr.ix]
	var partes := []
	var meta := 0.0
	if due >= 0 and mundo.paises.has(bd.nombre_de(due)):
		meta = _meta(pi, pr.ix, due, dia(), partes)
	return {"fav": pr.favorabilidad, "meta": meta, "partes": partes}


# ─────────────────────────────────────────────────────────────
# Reloj
# ─────────────────────────────────────────────────────────────
func _preparar() -> void:
	var clave := "%s|%d" % [mundo.modo, mundo.excluidas.size()]
	if clave == _clave_modo and not _activas.is_empty():
		return
	_clave_modo = clave
	_activas = PackedInt32Array()
	for i in mundo.provincias.size():
		if not mundo.excluidas.has(i):
			_activas.append(i)
	_cursor = 0
	_paises = {}


## Fase del día: revisa el 1/CICLO_DIAS de las provincias (por lotes). Devuelve true mientras quede trabajo en este paso.
func fase_dia(k := 1) -> bool:
	if ej == null or ej.red == null or not ej.red.listo or not bd.vars.has("favorabilidad"):
		return false
	if not _en_paso:
		_preparar()
		if _activas.is_empty():
			return false
		_en_paso = true
		_pendiente = mini(_pendiente + int(ceilf(float(_activas.size()) * float(k) / float(CICLO_DIAS))), _activas.size() * 2)
	var t0 := Time.get_ticks_usec()
	var n := mini(_pendiente, LOTE)
	var d := dia()
	_cargar_columnas()
	var fa: PackedFloat64Array = bd.vars["favorabilidad"].col_f
	var col_d: PackedInt32Array = bd.vars["propietario"].col_i
	for _j in n:
		var pi: int = _activas[_cursor]
		_cursor += 1
		if _cursor >= _activas.size():
			_cursor = 0
		_evaluar(pi, d, fa, col_d)
	_pendiente -= n
	revisadas += n
	var dt := Time.get_ticks_usec() - t0
	usec_total += dt
	ms_max = maxf(ms_max, float(dt) / 1000.0)
	if _pendiente <= 0:
		_pendiente = 0
		_en_paso = false
		return false
	return true


func _evaluar(pi: int, d: int, fa: PackedFloat64Array, col_d: PackedInt32Array) -> void:
	var ix: int = mundo.provincias[pi].ix
	var due: int = col_d[ix]
	if due < 0:
		return
	var f: Dictionary = _info_pais(due)
	if f["e"] == null or bool(f["e"].inerte):
		return
	var fav: float = fa[ix]
	if is_nan(fav):
		return
	var meta := _meta(pi, ix, due, d)
	var nuevo := clampf(fav + clampf(meta - fav, -PASO_MAX, PASO_MAX), 0.0, 100.0)
	fa[ix] = nuevo
	if absf(nuevo - fav) > 0.05 and d - int(_marca.get(due, -1000)) >= MARCA_BALANCE_DIAS:
		_marca[due] = d
		mundo.marcar_balance(due)
	if nuevo < UMBRAL_REVUELTA:
		var c: int = int(_malos.get(pi, 0)) + 1
		_malos[pi] = c
		if c >= MESES_REVUELTA and d >= int(_inmune.get(pi, -1)):
			_malos.erase(pi)
			_motin(pi, due, d)
	else:
		_malos.erase(pi)


## Una provincia cambió de dueño: si fue por conquista empieza el periodo de conquista reciente; si fue por independencia, no.
func al_cambiar_dueno(idx: int, motivo: String) -> void:
	_malos.erase(idx)
	_inmune.erase(idx)
	_veces.erase(idx)
	if motivo == "Independencia":
		conquistada.erase(idx)
	else:
		conquistada[idx] = dia()


# ─────────────────────────────────────────────────────────────
# Revueltas
# ─────────────────────────────────────────────────────────────
func _puede_renacer(t: int) -> bool:
	var nom: String = bd.nombre_de(t)
	if not mundo.paises.has(nom) or mundo.es_inerte(nom):
		return false
	return not mundo.es_campana() or mundo.campana.has(nom)


func _grupo(pi: int, due: int, core: int) -> Array:
	var col_d: PackedInt32Array = bd.vars["propietario"].col_i
	var fa: PackedFloat64Array = bd.vars["favorabilidad"].col_f
	var cn: PackedInt32Array = bd.vars["core_nacional"].col_i
	var r := [pi]
	var vistos := {pi: true}
	var i := 0
	while i < r.size() and r.size() < GRUPO_MAX:
		var p: int = r[i]
		i += 1
		for v in ej.red.vecinos(p):
			var q := int(v)
			if vistos.has(q) or mundo.excluidas.has(q):
				continue
			vistos[q] = true
			var ixq: int = mundo.provincias[q].ix
			if col_d[ixq] != due or fa[ixq] >= UMBRAL_AGITADA or (core >= 0 and cn[ixq] != core):
				continue
			r.append(q)
			if r.size() >= GRUPO_MAX:
				break
	return r


## Soldados del país `due` en el grupo de provincias y en sus vecinas.
func fuerza_cerca(due: int, grupo: Array) -> int:
	var vistos := {}
	var s := 0
	for p in grupo:
		var lista := [int(p)]
		for v in ej.red.vecinos(int(p)):
			lista.append(int(v))
		for q in lista:
			if vistos.has(q):
				continue
			vistos[q] = true
			s += _guarnicion(q, due)
	return s


func _datos_revuelta(due: int, grupo: Array, reino: int) -> Dictionary:
	var pago := 0.0
	var pob := 0.0
	var veces := 0
	for p in grupo:
		var pr = mundo.provincias[int(p)]
		pago += pr.ingreso_efectivo_usd() * PAGO_FRAC
		pob += pr.poblacion
		veces = maxi(veces, int(_veces.get(int(p), 0)))
	pago *= 1.0 + 0.8 * float(veces)                                   # cada motín repetido en la misma tierra sale más caro calmarlo
	return {"tipo": "revuelta", "pais": due, "provincias": grupo, "reino": reino, "pago_usd": maxf(pago, 1000.0),
		"fuerza_necesaria": pob * FUERZA_FRAC + FUERZA_MIN, "fuerza_disponible": fuerza_cerca(due, grupo), "fecha": mundo.bd.fecha}


func _motin(pi: int, due: int, d: int) -> void:
	var pr = mundo.provincias[pi]
	var cn: int = bd.ref("core_nacional", pr.tid)
	var reino := cn if (cn >= 0 and cn != due and _puede_renacer(cn)) else -1
	var grupo := _grupo(pi, due, cn)
	for q in grupo:
		_inmune[int(q)] = d + 45
		_veces[int(q)] = int(_veces.get(int(q), 0)) + 1
	motines += 1
	var av := _datos_revuelta(due, grupo, reino)
	var nom: String = bd.nombre_de(due)
	if nom == mundo.jugador:
		mundo.avisos.append(av)
		return
	resolver_ia(av)


## La IA resuelve sola: paga si le sobra la caja, reprime si tiene tropas cerca, y si no concede la independencia (o, sin a quién devolverle la tierra, la deja saqueada).
func resolver_ia(av: Dictionary) -> String:
	var due: int = int(av["pais"])
	var nom: String = bd.nombre_de(due)
	var caja := _caja_usd(nom)
	var coste: float = float(av["pago_usd"])
	var op := "ignorar"
	if caja >= 4.0 * coste:
		op = "pagar"
	elif float(av["fuerza_disponible"]) >= float(av["fuerza_necesaria"]):
		op = "reprimir"
	elif caja >= coste:
		op = "pagar"
	elif int(av["reino"]) >= 0:
		op = "conceder"
	resolver_revuelta(av, op)
	return op


func _caja_usd(nombre: String) -> float:
	var e = mundo.paises.get(nombre)
	if e == null or not e.tiene_tesoreria():
		return 0.0
	return maxf(0.0, e.tesoreria / mundo._por_usd(nombre))


## Aplica la decisión sobre una revuelta («pagar», «reprimir», «conceder» o «ignorar»). Devuelve {"ok", "msg"}.
func resolver_revuelta(av: Dictionary, opcion: String) -> Dictionary:
	var due: int = int(av["pais"])
	var nom: String = bd.nombre_de(due)
	var grupo: Array = av["provincias"]
	var reino: int = int(av["reino"])
	var d := dia()
	var fa: PackedFloat64Array = bd.vars["favorabilidad"].col_f
	var primera: String = mundo.provincias[int(grupo[0])].nombre
	var donde: String = primera if grupo.size() == 1 else "%s y %d provincias más" % [primera, grupo.size() - 1]
	if opcion == "pagar":
		var coste: float = float(av["pago_usd"])
		if _caja_usd(nom) < coste:
			return {"ok": false, "msg": "No tienes caja para pagar."}
		var e = mundo.paises[nom]
		e.tesoreria = e.tesoreria - coste * mundo._por_usd(nom)
		for q in grupo:
			var ixq: int = mundo.provincias[int(q)].ix
			fa[ixq] = minf(fa[ixq] + 22.0, 100.0)
			_inmune[int(q)] = d + INMUNE_PAGO
		pagos += 1
		mundo.marcar_balance(due)
		mundo.evento(due, "%s calma la revuelta de %s pagando a los notables." % [nom, donde])
		return {"ok": true, "msg": "La revuelta en %s se apaga con dinero." % donde}
	if opcion == "reprimir":
		if float(av["fuerza_disponible"]) < float(av["fuerza_necesaria"]):
			return {"ok": false, "msg": "Faltan tropas cerca (hacen falta %d, hay %d)." % [int(av["fuerza_necesaria"]), int(av["fuerza_disponible"])]}
		for q in grupo:
			var prq = mundo.provincias[int(q)]
			var ixq2: int = prq.ix
			fa[ixq2] = minf(fa[ixq2] + 12.0, 100.0)
			prq.devastacion = prq.devastacion + 0.12
			_inmune[int(q)] = d + INMUNE_REPRESION
		represiones += 1
		if mundo.diplomacia != null:
			mundo.diplomacia.sumar_infamia(due, 0.5)
		mundo.evento(due, "%s reprime la revuelta de %s con sus tropas." % [nom, donde])
		return {"ok": true, "msg": "Las tropas aplastan la revuelta en %s (la tierra queda devastada)." % donde}
	if reino >= 0:                                             # conceder o ignorar: la tierra vuelve a su gente
		var nom_r: String = bd.nombre_de(reino)
		var fecha_txt: String = BDScript.fecha_texto(bd.fecha)
		var n := 0
		for q in grupo:
			if mundo.transferir_provincia(int(q), nom_r, fecha_txt, "Independencia"):
				n += 1
				fa[mundo.provincias[int(q)].ix] = 60.0
		if n > 0:
			independencias += 1
			mundo.marcar_balance(due)
			mundo.marcar_balance(reino)
			if mundo.diplomacia != null:
				mundo.diplomacia.cambiar_opinion(due, reino, -15.0, "Perdió provincias por una revuelta")
			if mundo.ia != null and (mundo.es_campana() or not mundo.ia.activas.is_empty()) and mundo.ia.puede_tener_ia(nom_r):
				mundo.ia.activar(nom_r)                           # el país que renace piensa por sí mismo
			mundo.evento(due, "%s se independiza de %s: %s vuelve a %s." % [donde, nom, "la tierra" if n == 1 else "las tierras", nom_r], reino)
			return {"ok": true, "msg": "%s se independiza y pasa a %s." % [donde, nom_r]}
	for q in grupo:                                            # sin Estado al que volver: los rebeldes saquean y se calman a medias
		var prq2 = mundo.provincias[int(q)]
		prq2.devastacion = prq2.devastacion + 0.2
		fa[prq2.ix] = maxf(fa[prq2.ix], UMBRAL_AGITADA)
		_inmune[int(q)] = d + 90
	sin_estado += 1
	mundo.evento(due, "Revuelta en %s: no hay Estado al que volver, los rebeldes saquean la tierra." % donde)
	return {"ok": true, "msg": "Los rebeldes saquean %s y después se dispersan." % donde}


# ─────────────────────────────────────────────────────────────
# Resumen por país (la IA lo consulta antes de atacar)
# ─────────────────────────────────────────────────────────────
## [media simple de favorabilidad, provincias agitadas (< UMBRAL_AGITADA), total]. Se guarda 10 días.
func resumen(tid: int) -> Array:
	var c = _res_cache.get(tid)
	var d := dia()
	if c != null and d - int(c[0]) < 10:
		return [c[1], c[2], c[3]]
	var nom: String = bd.nombre_de(tid)
	var e = mundo.paises.get(nom)
	var fa: PackedFloat64Array = bd.vars["favorabilidad"].col_f
	var suma := 0.0
	var mal := 0
	var n := 0
	if e != null:
		for pi in e.provincias:
			var v: float = fa[mundo.provincias[int(pi)].ix]
			suma += v
			if v < UMBRAL_AGITADA:
				mal += 1
			n += 1
	var media := suma / float(n) if n > 0 else 50.0
	_res_cache[tid] = [d, media, mal, n]
	return [media, mal, n]
