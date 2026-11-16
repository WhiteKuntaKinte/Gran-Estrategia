extends RefCounted
## EDUCACIÓN, INVESTIGACIÓN Y OFICIOS (0.1.8.47).
##
## La gente ya no es solo «población»: estudia, trabaja y descubre. Este módulo une tres cosas con el motor de descubrimientos del planeta (scripts/saber.gd):
##   1. CAPACIDAD DE INVESTIGAR: cuántos investigadores tiene un país (gente con estudios superiores × lo que gasta en ciencia × su política de investigación) cambia
##      su probabilidad de ser quien descubra algo (`factor_capacidad`). Un país grande pero analfabeto descubre menos que uno pequeño y culto.
##   2. POLÍTICA DE INVESTIGACIÓN: cada país reparte su esfuerzo entre las 3 ramas del árbol (militar, científica, sociedad). Más esfuerzo en una rama = más
##      probabilidad de que descubra cosas de esa rama (`factor_rama`). Las IA la ajustan solas (más militar en guerra); el jugador la fija a mano.
##   3. DIFUSIÓN: un pueblo alfabetizado se entera antes de lo que descubren sus vecinos (`factor_difusion`).
## Además reparte la gente en edad de trabajar entre 40 OFICIOS (datos/carreras.json): agricultores, soldados, maestros, médicos, programadores… según los estudios del país
## y lo que sabe (no hay cirujanos sin cirugía descubierta). Es información de juego (ficha del país, Debug) y la base de efectos futuros.
## Y decide el PRESUPUESTO de las IA (educación, ciencia, obras, sanidad): austeridad si la caja se vacía, inversión si sobra, recortes en guerra.
## Las constantes son PROVISIONALES: ver docs/DEMOGRAFIA.md.

const IndicesScript := preload("res://scripts/indices_saber.gd")
const DemografiaRef := preload("res://scripts/demografia.gd")

const RAMA_MIL := 0
const RAMA_CIE := 1
const RAMA_SOC := 2
const POLITICA_BASE := 0.3333333
const POLITICA_MIN := 0.05                # ninguna rama baja de 5 % (siempre se descubre algo de todo)
const FACTOR_RAMA_MIN := 0.25
const FACTOR_RAMA_MAX := 2.2
const SUP_BASE := 0.002                   # fracción de adultos que son eruditos aun sin universidades (escribas, sabios)
const SUP_INST := 0.010                   # ... más lo que añaden academias y bibliotecas
const FRAC_INVESTIGA := 0.22              # de la gente con estudios superiores, con el gasto de referencia en ciencia, esta fracción investiga
const ESCALA_INVESTIGA := 25.0            # densidad de investigadores a la que el factor de capacidad llega a ~76 % de su rango
const CAP_MIN := 0.5
const CAP_RANGO := 1.0
const TOPE_GASTO_REL := 3.0               # el gasto en ciencia solo rinde hasta 3 × la referencia
const AGRARIO_COEF := 1.0                 # parte agraria = (0,95 − AGRARIO_COEF · urbanización^0,9) × (1 − MECANIZA_COEF · mecanización)
const MECANIZA_COEF := 0.85               # mecanización = saber de agricultura × acceso: con máquinas y renta, el campo emplea un 85 % menos de gente
const AFINIDAD := 0.35                    # quien tiene más estudios que un oficio también puede ejercerlo, con esta probabilidad relativa por cada nivel de diferencia
const GATE_ANCHO := 0.12                  # una carrera pasa de 0 a 100 % de su peso en tanto fracción del campo después de `desde`
const SOLDADOS_GUERRA := 3.0              # los soldados profesionales pesan ×3 en un país en guerra
const AJUSTE_MENSUAL := 0.15              # fracción del camino hacia el objetivo que recorre cada partida de una IA por mes
const MESES_AUSTERIDAD := 5.0             # una IA con caja para menos meses que esto recorta
const MESES_HOLGURA := 12.0               # ... y con más meses de ingresos ahorrados que esto (y balance positivo) invierte

var mundo
var bd
var dm                                    # Demografía
var carreras: Array = []                  # [{id, nombre, nivel, campo, desde, peso, grupo, desc}]
var grupos: Array = []                    # los 12 grupos de oficio, en orden
var listo := false
var _pol := {}                            # ID de país -> PackedFloat32Array(3): reparto del esfuerzo de investigación (militar, científica, sociedad)
var _manual := {}                         # ID de país -> true si el jugador fijó su política o su presupuesto: la IA no lo toca
var _rama_sec := PackedInt32Array()       # sección del catálogo -> rama
var decisiones := 0                       # decisiones de presupuesto tomadas por IA (pruebas)


func iniciar(m, demo) -> bool:
	mundo = m
	bd = m.bd
	dm = demo
	listo = false
	_pol.clear()
	_manual.clear()
	if m.descubrimientos == null or demo == null:
		return false
	var ruta := "res://datos/carreras.json"
	if not FileAccess.file_exists(ruta):
		push_error("educacion: falta datos/carreras.json (herramientas/construir_carreras.py)")
		return false
	var j = JSON.parse_string(FileAccess.get_file_as_string(ruta))
	if typeof(j) != TYPE_DICTIONARY or not (j as Dictionary).has("carreras"):
		push_error("educacion: datos/carreras.json ilegible")
		return false
	carreras = j["carreras"]
	grupos = j["grupos"]
	_rama_sec.resize(m.descubrimientos.secciones.size())
	for s in _rama_sec.size():
		_rama_sec[s] = int(m.descubrimientos.secciones[s].get("rama", 0))
	listo = true
	return true


# ─────────────────────────────────────────────────────────────
# Política de investigación
# ─────────────────────────────────────────────────────────────
## El reparto del esfuerzo de `tid`: [militar, científica, sociedad], suma 1.
func politica(tid: int) -> PackedFloat32Array:
	var p = _pol.get(tid)
	if p == null:
		p = PackedFloat32Array([POLITICA_BASE, POLITICA_BASE, POLITICA_BASE])
	return p


## Fija la política (el jugador, o una IA): se normaliza a suma 1 con un mínimo de 5 % por rama. `manual` = el jugador la fijó (la IA ya no la cambia).
func fijar_politica(tid: int, mil: float, cie: float, soc: float, manual := false) -> void:
	var v := [maxf(mil, 0.0), maxf(cie, 0.0), maxf(soc, 0.0)]
	var s: float = float(v[0]) + float(v[1]) + float(v[2])
	if s <= 0.0:
		v = [1.0, 1.0, 1.0]
		s = 3.0
	var r := PackedFloat32Array([0.0, 0.0, 0.0])
	var libre := 1.0 - 3.0 * POLITICA_MIN
	for k in 3:
		r[k] = POLITICA_MIN + libre * float(v[k]) / s
	_pol[tid] = r
	if manual:
		_manual[tid] = true


## ¿La política o el presupuesto de este país los llevó el jugador?
func es_manual(tid: int) -> bool:
	return _manual.has(tid)


## Marca (o libera) un país como llevado a mano: la IA no toca su presupuesto ni su política.
func marcar_manual(tid: int, si: bool) -> void:
	if si:
		_manual[tid] = true
	else:
		_manual.erase(tid)


## Cuánto cambia la probabilidad de que `tid` descubra algo de la rama `rama`: 1 con el reparto parejo, de 0,25 a 2,2.
func factor_rama(tid: int, rama: int) -> float:
	var p = _pol.get(tid)
	if p == null:
		return 1.0
	return clampf(float(p[clampi(rama, 0, 2)]) * 3.0, FACTOR_RAMA_MIN, FACTOR_RAMA_MAX)


## Lo mismo por sección del catálogo (lo que usa el motor de descubrimientos).
func factor_seccion(tid: int, sec: int) -> float:
	var p = _pol.get(tid)
	if p == null:
		return 1.0
	return clampf(float(p[clampi(int(_rama_sec[sec]), 0, 2)]) * 3.0, FACTOR_RAMA_MIN, FACTOR_RAMA_MAX)


# ─────────────────────────────────────────────────────────────
# Estudios y capacidad de investigar
# ─────────────────────────────────────────────────────────────
## Reparto de los adultos por estudios, según los años de escolaridad media: x = estudios superiores, y = secundaria; el resto, primaria o nada.
static func estudios(esc: float, por_100k: float) -> Vector2:
	var sup := pow(clampf((esc - 3.0) / 12.0, 0.0, 0.62), 1.8) + SUP_BASE + SUP_INST * tanh(maxf(por_100k, 0.0))
	sup = clampf(sup, 0.0, 0.62)
	var sec := clampf(pow(clampf((esc - 1.5) / 9.0, 0.0, 0.9), 1.4) - sup, 0.0, 0.9)
	return Vector2(sup, sec)


## Densidad de investigadores: fracción de los adultos que investigan.
static func densidad_investigadores(sup: float, gasto_ciencia: float, f_cie_rama: float) -> float:
	var g := clampf(gasto_ciencia / DemografiaRef.GASTO_REF_CIE, 0.0, TOPE_GASTO_REL)
	return sup * FRAC_INVESTIGA * (0.35 + 0.65 * g) * clampf(f_cie_rama, 0.5, 1.6)


## Multiplicador de la capacidad del país en el sorteo de descubrimientos (de 0,5 a 1,5): lo que cambia por tener más o menos investigadores.
func factor_capacidad(tid: int) -> float:
	if not listo:
		return 1.0
	var esc: float = dm.media_pais(tid, DemografiaRef.K_ESC)
	if is_nan(esc):
		return 1.0
	var pob: float = dm.poblacion_pais(tid)
	var por_100k: float = dm.instituciones_pais(tid) / (pob / 100000.0 + 0.3)
	var sup := estudios(esc, por_100k).x
	var dens: float = densidad_investigadores(sup, bd.num("gasto_ciencia", tid, DemografiaRef.GASTO_REF_CIE), factor_rama(tid, RAMA_CIE))
	return CAP_MIN + CAP_RANGO * tanh(ESCALA_INVESTIGA * dens)


## Divisor del tiempo que tarda en enterarse de lo que descubren otros (de 0,8 a 1,3): un pueblo alfabetizado aprende antes.
func factor_difusion(tid: int) -> float:
	if not listo:
		return 1.0
	var alf: float = dm.media_pais(tid, DemografiaRef.K_ALF)
	if is_nan(alf):
		return 1.0
	return 0.8 + 0.5 * clampf(alf, 0.0, 1.0)


# ─────────────────────────────────────────────────────────────
# Oficios
# ─────────────────────────────────────────────────────────────
## Reparte la gente en edad de trabajar de `tid` entre los 40 oficios. Devuelve una lista de {id, nombre, grupo, nivel, n, existe} en el orden del catálogo; `existe` = el país
## ya sabe lo bastante del campo para que el oficio exista. La suma de `n` es la población activa del país.
## Cómo se reparte: (1) los OFICIOS AGRARIOS se llevan una parte que baja con la urbanización y con la mecanización (saber de agricultura × acceso a máquinas); salen de los
## que menos estudios tienen. (2) El resto de la gente, por nivel de estudios (primaria o nada / secundaria / superiores), elige entre los oficios de su nivel o de uno menor
## (con ×AFINIDAD por cada nivel de diferencia), con el peso de cada oficio (0 si el país aún no sabe lo bastante de su campo).
func fuerza_laboral(tid: int) -> Array:
	var res := []
	if not listo:
		return res
	var pob: float = dm.poblacion_pais(tid)
	var jov: float = dm.media_pais(tid, DemografiaRef.K_JOV)
	var may: float = dm.media_pais(tid, DemografiaRef.K_MAY)
	var esc: float = dm.media_pais(tid, DemografiaRef.K_ESC)
	var urb: float = dm.media_pais(tid, DemografiaRef.K_URB)
	var acc: float = dm.media_pais(tid, DemografiaRef.K_ACC)
	if pob <= 0.0 or is_nan(jov) or is_nan(esc):
		return res
	var activos: float = pob * DemografiaRef.activa_de(jov, may)
	var por_100k: float = dm.instituciones_pais(tid) / (pob / 100000.0 + 0.3)
	var est := estudios(esc, por_100k)
	var v: PackedFloat32Array = dm.idx.de(tid, dm.dia())
	var mecaniza: float = float(v[IndicesScript.I_AGRI]) * (0.0 if is_nan(acc) else acc)
	var parte_agro := clampf((0.95 - AGRARIO_COEF * pow(urb, 0.9)) * (1.0 - MECANIZA_COEF * mecaniza), 0.01, 0.95)
	var en_guerra: bool = bd.num("guerras_activas", tid, 0.0) > 0.0
	var f_campo := {}
	var pesos := PackedFloat64Array()                          # peso efectivo de cada carrera (0 si aún no existe)
	for c in carreras:
		var clave := String(c["campo"])
		if not f_campo.has(clave):
			f_campo[clave] = dm.idx.fraccion_campo(tid, clave)
		var puerta := clampf((float(f_campo[clave]) - float(c["desde"])) / GATE_ANCHO + (1.0 if float(c["desde"]) <= 0.0 else 0.0), 0.0, 1.0)
		var w := float(c["peso"]) * puerta
		if String(c["id"]) == "soldado" and en_guerra:
			w *= SOLDADOS_GUERRA
		pesos.append(w)
	var n_por := PackedFloat64Array()
	n_por.resize(carreras.size())
	# (1) los agrarios, de abajo hacia arriba en estudios
	var pool := [1.0 - est.x - est.y, est.y, est.x]            # niveles 1, 2 y 3
	var por_sacar := parte_agro
	for k in 3:
		var t := minf(float(pool[k]), por_sacar)
		pool[k] = float(pool[k]) - t
		por_sacar -= t
	var suma_agro := 0.0
	for i in carreras.size():
		if String(carreras[i]["grupo"]) == "agro":
			suma_agro += pesos[i]
	if suma_agro <= 0.0:                                       # sin ningún oficio agrario disponible (no pasa con el catálogo actual): esa gente reparte como los demás
		pool[0] = float(pool[0]) + parte_agro
	else:
		for i in carreras.size():
			if String(carreras[i]["grupo"]) == "agro":
				n_por[i] = activos * parte_agro * pesos[i] / suma_agro
	# (2) los demás, por nivel de estudios
	for k in 3:
		var nivel := k + 1
		var cuota: float = float(pool[k])
		if cuota <= 0.0:
			continue
		var ef := PackedFloat64Array()
		ef.resize(carreras.size())
		var suma := 0.0
		for i in carreras.size():
			if String(carreras[i]["grupo"]) == "agro" and suma_agro > 0.0:
				continue
			var niv_c: int = maxi(int(carreras[i]["nivel"]), 1)
			if niv_c > nivel or pesos[i] <= 0.0:
				continue
			ef[i] = pesos[i] * pow(AFINIDAD, float(nivel - niv_c))
			suma += ef[i]
		if suma <= 0.0:
			continue
		for i in carreras.size():
			if ef[i] > 0.0:
				n_por[i] += activos * cuota * ef[i] / suma
	for i in carreras.size():
		var c2: Dictionary = carreras[i]
		res.append({"id": c2["id"], "nombre": c2["nombre"], "grupo": c2["grupo"], "nivel": c2["nivel"], "n": n_por[i], "existe": pesos[i] > 0.0})
	return res


## Cuánta gente trabaja en un grupo de oficios («salud», «investigacion», «docencia»…).
func trabajadores_de(tid: int, grupo: String) -> float:
	var t := 0.0
	for o in fuerza_laboral(tid):
		if String(o["grupo"]) == grupo:
			t += float(o["n"])
	return t


## Todo lo de educación de un país para la ficha: {esc, alfab, superiores, secundaria, politica, f_cap, f_dif, calidad, investigadores, activos, manual, saber (los 4 índices de saber social)}.
func resumen_pais(tid: int) -> Dictionary:
	var esc: float = dm.media_pais(tid, DemografiaRef.K_ESC)
	var pob: float = dm.poblacion_pais(tid)
	var por_100k: float = dm.instituciones_pais(tid) / (pob / 100000.0 + 0.3)
	var est := estudios(0.0 if is_nan(esc) else esc, por_100k)
	var activos: float = dm.activa_pais(tid)
	var dens: float = densidad_investigadores(est.x, bd.num("gasto_ciencia", tid, DemografiaRef.GASTO_REF_CIE), factor_rama(tid, RAMA_CIE))
	return {"esc": 0.0 if is_nan(esc) else esc, "alfab": maxf(0.0, dm.media_pais(tid, DemografiaRef.K_ALF)), "superiores": est.x, "secundaria": est.y,
		"politica": politica(tid), "f_cap": factor_capacidad(tid), "f_dif": factor_difusion(tid), "calidad": bd.num("calidad_docentes", tid, 0.0),
		"investigadores": activos * dens, "activos": activos, "manual": es_manual(tid), "saber": dm.idx.de(tid, dm.dia())}


# ─────────────────────────────────────────────────────────────
# Decisiones de las IA (una vez al mes por país, desde la fase de demografía)
# ─────────────────────────────────────────────────────────────
## Una IA revisa su presupuesto y su política de investigación. `p` = el país (objeto Pais), `en_guerra` y `fatiga` ya calculadas por quien llama.
func decidir_ia(p, en_guerra: bool, fatiga: float) -> void:
	var tid: int = int(p.tid)
	if _manual.has(tid) or p.nombre == mundo.jugador:
		return
	var v: PackedFloat32Array = dm.idx.de(tid, dm.dia())
	var edu_saber: float = float(v[IndicesScript.I_EDU])
	var sal_saber: float = float(v[IndicesScript.I_SALUD])
	var tes: float = p.tesoreria
	var ingreso: float = maxf(mundo.ingreso_diario_local(p.nombre), 1.0)
	var balance: float = mundo.balance_diario_rapido(p.nombre)
	var meses_caja := 99.0                                      # cuántos meses aguanta la caja si todo sigue igual (99 = no se vacía)
	if balance < 0.0:
		meses_caja = tes / (-balance * 30.0)
	var meses_ingreso := tes / (ingreso * 30.0)                   # cuántos meses de ingresos tiene ahorrados
	var mult := 1.0
	if en_guerra:
		mult = 0.65
	if meses_caja < MESES_AUSTERIDAD:
		mult = minf(mult, 0.5)
	elif meses_ingreso > MESES_HOLGURA and balance > 0.0 and not en_guerra:
		mult = 1.3
	# no se gasta en escuelas ni ciencia que el país aún no conoce: la partida crece con el saber del ramo
	var obj_edu := DemografiaRef.GASTO_REF_EDU * mult * (0.25 + 0.75 * clampf(edu_saber * 2.2, 0.0, 1.0))
	var obj_cie := DemografiaRef.GASTO_REF_CIE * mult * (0.2 + 0.8 * clampf(edu_saber * 2.2, 0.0, 1.0))
	var obj_obr := DemografiaRef.GASTO_REF_OBR * mult
	var obj_san := DemografiaRef.GASTO_REF_SAN * mult * (0.3 + 0.7 * clampf(sal_saber * 2.5, 0.0, 1.0)) * (1.0 + 0.4 * clampf(fatiga / 100.0, 0.0, 1.0))
	var cambio := false
	cambio = _poner_gasto(p, "gasto_educacion", p.gasto_educacion + (obj_edu - p.gasto_educacion) * AJUSTE_MENSUAL) or cambio
	cambio = _poner_gasto(p, "gasto_ciencia", p.gasto_ciencia + (obj_cie - p.gasto_ciencia) * AJUSTE_MENSUAL) or cambio
	cambio = _poner_gasto(p, "gasto_obras", p.gasto_obras + (obj_obr - p.gasto_obras) * AJUSTE_MENSUAL) or cambio
	cambio = _poner_gasto(p, "gasto_sanidad", p.gasto_sanidad + (obj_san - p.gasto_sanidad) * AJUSTE_MENSUAL) or cambio
	if cambio:
		mundo.marcar_balance(tid)                                    # solo se rehace la fila de balance de este país (no las ~250)
	# política de investigación: en guerra, más militar; en paz y con estudios, más ciencia
	var mil := 0.24 + (0.30 if en_guerra else 0.0) * (1.0 - clampf(fatiga / 100.0, 0.0, 0.8))
	var cie := 0.36 + 0.14 * clampf(edu_saber * 2.0, 0.0, 1.0) - (0.10 if en_guerra else 0.0)
	var soc := 1.0 - mil - cie
	var act: PackedFloat32Array = politica(tid)
	fijar_politica(tid, float(act[RAMA_MIL]) + (mil - float(act[RAMA_MIL])) * AJUSTE_MENSUAL, float(act[RAMA_CIE]) + (cie - float(act[RAMA_CIE])) * AJUSTE_MENSUAL,
		float(act[RAMA_SOC]) + (soc - float(act[RAMA_SOC])) * AJUSTE_MENSUAL)
	decisiones += 1


## Escribe una partida del presupuesto de una IA directo en la columna: sin historial y SIN subir `version_eco`. La IA ajusta cada partida todos los meses en pasos
## pequeños; por el setter de `Pais` cada ajuste (de unos 8 países al día) subía la versión económica y rehacía el balance de los ~250 países (7 ms por día) y
## guardaba una fila de historial por cambio. Devuelve true si cambió el valor.
func _poner_gasto(p, nombre_var: String, valor: float) -> bool:
	var v = bd.vars[nombre_var]
	var ix: int = bd.idx(int(p.tid))
	if ix < 0:
		return false
	var nuevo := clampf(valor, 0.0, 0.3)
	var viejo: float = v.col_f[ix]
	if not is_nan(viejo) and absf(viejo - nuevo) < 1.0e-6:
		return false
	v.col_f[ix] = nuevo
	v.desde[ix] = bd.fecha
	return true


## Olvida lo guardado (salto de fecha, escenario nuevo).
func reiniciar() -> void:
	for tid in _pol.keys():
		if not _manual.has(tid):
			_pol.erase(tid)
