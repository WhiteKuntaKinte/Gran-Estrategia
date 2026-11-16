extends RefCounted
## SABER (0.1.8.46) · EL PLANETA DESCUBRE.
##
## Hasta la 0.1.8.45 la historia traía los descubrimientos sola: al llegar el reloj al año de cada uno, TODOS los países lo conocían a la vez. Desde aquí, en
## una partida nueva la historia se CONGELA en el año de partida (esa es la frontera inicial) y lo que viene lo descubren los países, uno primero y los demás
## por contacto. Con la misma semilla la partida da lo mismo (scripts/azar.gd: azar que no depende del orden de las llamadas).
##
## Cómo funciona (todo mensual; el coste es de microsegundos por mes):
##  1. CANDIDATOS: los descubrimientos que el planeta aún no tiene y cuyos prerrequisitos ya existen en algún país.
##  2. RIESGO del mundo: cada mes, cada candidato se descubre con probabilidad  p = BASE_P / T · 2^(Δ / T),  Δ = año actual − año histórico del descubrimiento y
##     T = «tiempo de duplicación» de su era (3.000 años en la Prehistoria, 5 en el presente). Con Δ muy negativo casi nunca ocurre antes de tiempo; con Δ = 0 ya
##     ha pasado el 54 % de las veces; si se atrasa mucho (Δ grande) el riesgo se dispara, así el mundo no se queda atrás de la historia más de unas pocas T.
##  3. QUIÉN: se reparte entre los países que conocen TODOS sus prerrequisitos, con peso  capacidad · vocación · edificios · materias:
##       capacidad = (millones de habitantes)^0,7 · (0.4 + 0.6 · lo que ya sabe respecto al planeta);
##       vocación  = 0.6 … 1.6 según país y sección (al azar fijo por semilla: un país es bueno en ingeniería y otro en medicina);
##       edificios = ×0.15 por cada grupo de la receta del que no tenga ningún edificio (scripts/edificios.gd, herramientas/receta_descubrimientos.py);
##       materias  = ×1.4 si produce alguna de las que ayudan (×1.2 si no hay datos de su economía: no se castiga a los países sin datos de 2026).
##     Los edificios se miran leyendo el texto de edificios de cada provincia, por MUESTREO CON RECHAZO (se sortea un país por capacidad·vocación·materias y se acepta con probabilidad = su factor de edificios;
##     si no, se sortea otro, hasta MAX_INTENTOS): da exactamente el mismo reparto sin tener que mirar los edificios de 200 países, que cuesta decenas de ms.
##     Si ningún país puede (faltan prerrequisitos en todos), el candidato queda BLOQUEADO hasta que algún país aprenda uno de sus prerrequisitos.
##  4. DIFUSIÓN: el país que aprende algo se lo cuenta a sus vecinos por tierra o estrecho (según los dueños de las provincias), a sus aliados y a unos pocos
##     países lejanos (viajeros). Cada uno tarda unos meses o años según la era (L_ERA) y, al aprenderlo, lo cuenta a SUS vecinos: una onda de contagio con
##     geografía (los continentes aislados tardan). Quien recibe una noticia sin tener los prerrequisitos no la pierde: en cuanto los aprende se le reprograma.
##  5. Los países SIN TIERRA (disueltos, anexados) se ponen al día cada año con el más sabio de su continente, para que uno que resurge no salga atrasado.
##
## Invariante (lo comprueba test/runner103): ningún país conoce algo sin conocer sus prerrequisitos.
## Con `activo = false` (Debug) se vuelve a la historia fija de antes: `Descubrimientos.avanzar_a`.

const AzarScript := preload("res://scripts/azar.gd")

const T_ERA := [3000.0, 1200.0, 500.0, 200.0, 90.0, 40.0, 20.0, 10.0, 6.0, 5.0, 5.0, 8.0]    # años: el riesgo se duplica cada T (por era del descubrimiento)
const L_ERA := [2400.0, 1200.0, 480.0, 240.0, 120.0, 60.0, 24.0, 12.0, 4.0, 2.0, 2.0, 3.0]   # meses que tarda un salto de contagio (por era)
const BASE_P := 0.04534                   # = 0.785 · ln 2 / 12: con Δ = 0 el 54 % ya se descubrió; con Δ = 0.35 T, el 63 %
const RIESGO_MAX := 0.5                   # tope del riesgo mensual de un candidato
const SIN_EDIFICIO := 0.15                # factor por cada grupo de edificios de la receta que el país no tiene
const CON_MATERIA := 1.4
const MATERIA_SIN_DATOS := 1.2
const MAX_INTENTOS := 12                  # sorteos de país por descubrimiento (rechazo por edificios); si ninguno se acepta, gana el de más edificios
const VIAJEROS := 3                       # países lejanos al azar a los que llega cada noticia
const MAX_SALTO_MESES := 120              # más meses de golpe que esto = salto de fecha: se reinicia en vez de simular
const REFRESCO_CAP := 6                   # cada cuántos meses se rehace la lista de países con tierra y sin tierra
const CAP_EXPONENTE := 0.7                # capacidad = (millones de habitantes + 0,02) ^ CAP_EXPONENTE · (0,4 + 0,6 · lo que sabe respecto al planeta)
const CAP_GRUPOS := 12                    # la capacidad de cada país se recalcula una vez cada CAP_GRUPOS meses (1/CAP_GRUPOS de los países por mes)
const CLAVE := 4096                       # tid * CLAVE + descubrimiento: clave de un contacto
const RIESGO_DESPRECIABLE := 1.0e-6       # por debajo de este riesgo mensual el candidato ni se mira (se pierde un 0,15 % del total de descubrimientos «demasiado pronto»)

var activo := true
var mundo
var d                                       # Descubrimientos
var semilla := 0
var listo := false

var mes_n := 0                              # mes absoluto = año · 12 + (mes − 1)
var candidatos := PackedInt32Array()
var _es_cand := PackedByteArray()
var _desde := PackedFloat64Array()          # índice -> año a partir del cual su riesgo mensual supera RIESGO_DESPRECIABLE
var _nuevos := PackedInt32Array()           # lo que descubrió el planeta desde que empezó la partida, en orden (los países sin tierra se ponen al día solo con esto)
var _bloqueado := {}                        # índice -> true: se disparó el riesgo pero ningún país puede todavía
var _cola := {}                             # mes absoluto -> Array de claves tid * CLAVE + índice (contactos que llegan ese mes)
var _pend := {}                             # clave -> true mientras haya un contacto programado
var _proc_hasta := 0                        # último mes cuyos contactos ya se procesaron
var descubridor := PackedInt32Array()       # índice -> ID del país que lo descubrió primero (-1 = ya estaba al empezar la partida)
var fecha_desc := PackedInt32Array()        # índice -> mes absoluto en que se descubrió (-1 = ya estaba)
var activos := PackedInt32Array()           # ID de los países con tierra y con gobierno
var _sin_tierra := PackedInt32Array()       # ID de los países con gobierno pero sin provincias (disueltos o anexados)
var _cap := {}                              # ID de país -> capacidad
var _busq_edif := {}                        # índice de descubrimiento -> sus búsquedas de edificios (`_busqueda_edif`)
var _nombre := {}                           # ID de país -> nombre
var _cont := {}                             # ID de país -> continente
var _conocidos_n := {}                      # ID de país -> cuántos descubrimientos conoce
var _mes_cap := -1000

# ── estadísticas (pruebas y Debug) ──
var n_descubiertos := 0                     # descubrimientos hechos desde que empezó la partida
var n_contagios := 0                        # veces que un país aprendió algo de otro
var n_bloqueos := 0
var us_total := 0
var us_max := 0
var meses_corridos := 0


# ─────────────────────────────────────────────────────────────
# Arranque
# ─────────────────────────────────────────────────────────────
## Congela la historia en la frontera actual y reparte a cada país su propia copia. Devuelve false si faltan descubrimientos.
func iniciar(m, sem: int) -> bool:
	mundo = m
	semilla = sem
	d = m.descubrimientos
	listo = false
	if d == null or d.n == 0:
		return false
	var n: int = d.n
	if n >= CLAVE:
		push_error("scripts/saber.gd: el catálogo (%d) no cabe en CLAVE (%d): sube CLAVE" % [n, CLAVE])
		return false
	d.modo_planeta = true
	d.estado.clear()
	for nombre in mundo.paises:                              # todos tienen estado propio: si no, leerían la frontera, que ahora crece sola
		var tid: int = int(mundo.paises[nombre].tid)
		d.estado[tid] = d.frontera.duplicate()
		_nombre[tid] = String(nombre)
		_cont[tid] = String(mundo.paises[nombre].continente)
		_conocidos_n[tid] = d.cuenta_f
	descubridor = PackedInt32Array()
	descubridor.resize(n)
	descubridor.fill(-1)
	fecha_desc = PackedInt32Array()
	fecha_desc.resize(n)
	fecha_desc.fill(-1)
	_cola.clear()
	_pend.clear()
	_bloqueado.clear()
	_nuevos = PackedInt32Array()
	_es_cand = PackedByteArray()
	_es_cand.resize(n)
	_desde = PackedFloat64Array()
	_desde.resize(n)
	for i in n:
		var t: float = T_ERA[mini(int(d.era[i]), T_ERA.size() - 1)]
		_desde[i] = float(d.anio[i]) + t * log(RIESGO_DESPRECIABLE * t / BASE_P) / log(2.0)
	candidatos = PackedInt32Array()
	for i in n:
		if d.frontera[i] == 0 and _req_planeta(i):
			_es_cand[i] = 1
			candidatos.append(i)
	mes_n = _mes_de_fecha(int(mundo.bd.fecha))
	_proc_hasta = mes_n
	_mes_cap = -1000
	n_descubiertos = 0
	n_contagios = 0
	n_bloqueos = 0
	us_total = 0
	us_max = 0
	meses_corridos = 0
	_refrescar_capacidad(true)
	if mundo.ia != null:
		mundo.ia.vecinos_ids(-1)                             # prepara la vecindad entre países (10 ms) ahora y no en el primer contagio
	listo = true
	return true


## Salto de fecha (Debug): la frontera ya es la historia de `anio` (la dejó `Descubrimientos.sincronizar`); se vuelve a congelar y a repartir.
func reiniciar() -> void:
	iniciar(mundo, semilla)


## Vuelve a la historia fija de antes (la frontera sigue al reloj y todos los países saben lo mismo). Para comparar o probar.
func desactivar() -> void:
	activo = false
	if d != null:
		d.sincronizar(floori(float(mes_n) / 12.0), true)


## El planeta vuelve a descubrir desde la fecha actual (la frontera se vuelve a congelar en la historia de este año).
func activar() -> bool:
	activo = true
	d.sincronizar(floori(float(_mes_de_fecha(int(mundo.bd.fecha))) / 12.0), true)
	return iniciar(mundo, semilla)


static func _mes_de_fecha(f: int) -> int:
	return (floori(f / 10000.0) - 100000) * 12 + (floori(f / 100.0) % 100) - 1


func _req_planeta(i: int) -> bool:
	for r in d.req[i]:
		if d.frontera[r] == 0:
			return false
	for g in d.req_o[i]:
		var alguno := false
		for r2 in g:
			if d.frontera[r2] == 1:
				alguno = true
				break
		if not alguno:
			return false
	return true


# ─────────────────────────────────────────────────────────────
# Paso del tiempo
# ─────────────────────────────────────────────────────────────
## Lo llama `Mundo.avanzar_mes` al cerrar cada mes. Barato: casi todo el tiempo son unas decenas de comparaciones.
func mes() -> void:
	if not listo or not activo:
		return
	var t0 := Time.get_ticks_usec()
	var ahora := _mes_de_fecha(int(mundo.bd.fecha))
	if ahora == mes_n:
		return
	if ahora < mes_n or ahora - mes_n > MAX_SALTO_MESES:
		d.sincronizar(floori(float(ahora) / 12.0), true)
		reiniciar()
		return
	while mes_n < ahora:
		mes_n += 1
		_un_mes()
	d.anio_actual = floori(float(mes_n) / 12.0)              # la interfaz (estado «aún lejano») compara contra el año del reloj
	var us := Time.get_ticks_usec() - t0
	us_total += us
	us_max = maxi(us_max, us)


func _un_mes() -> void:
	meses_corridos += 1
	_refrescar_capacidad(false)
	# 1) los contactos que llegan este mes (o se quedaron atrasados)
	for m in range(_proc_hasta + 1, mes_n + 1):
		var lista = _cola.get(m)
		if lista == null:
			continue
		_cola.erase(m)
		for clave in lista:
			_contacto(int(clave))
	_proc_hasta = mes_n
	# 2) el riesgo del mundo sobre cada candidato
	var anio_f := float(mes_n) / 12.0
	var lista_c := candidatos.duplicate()                    # `_descubrir` cambia `candidatos`: se recorre una copia
	for c in lista_c:
		if anio_f < _desde[c] or _bloqueado.has(c):
			continue
		var t: float = T_ERA[mini(int(d.era[c]), T_ERA.size() - 1)]
		var p := minf(RIESGO_MAX, BASE_P / t * pow(2.0, (anio_f - float(d.anio[c])) / t))
		if AzarScript.u(semilla, 1, c, mes_n) < p:
			_descubrir(c)
	# 3) los países sin tierra se ponen al día de a 1/12 por mes, y una vez al año se reintentan los bloqueados
	_poner_al_dia_sin_tierra(posmod(mes_n, 12))
	if posmod(mes_n, 12) == 0:
		_bloqueado.clear()


# ─────────────────────────────────────────────────────────────
# Descubrir (el primero) y difundir
# ─────────────────────────────────────────────────────────────
func _descubrir(i: int) -> void:
	var sec: int = int(d.seccion[i])
	var total := 0.0
	var pesos := PackedFloat64Array()
	pesos.resize(activos.size())
	for k in activos.size():
		var tid: int = activos[k]
		if not d.requisitos_cumplidos(tid, i):
			continue
		var w: float = float(_cap.get(tid, 0.0)) * (0.6 + AzarScript.u(semilla, 4, tid, sec)) * _factor_mat(_nombre[tid], i)
		pesos[k] = w
		total += w
	if total <= 0.0:
		_bloqueado[i] = true
		n_bloqueos += 1
		return
	var elegido := -1
	var mejor_f := -1.0
	var f_de := {}                                           # factor de edificios ya calculado en este descubrimiento (el mismo país sale sorteado varias veces)
	for intento in MAX_INTENTOS:                             # muestreo con rechazo: sortea por capacidad·vocación·materias y acepta con la probabilidad de sus edificios
		var r := AzarScript.u(semilla, 2, i, mes_n, intento) * total
		var acum := 0.0
		var k_sel := activos.size() - 1
		for k in activos.size():
			acum += pesos[k]
			if pesos[k] > 0.0 and r < acum:
				k_sel = k
				break
		var tid_sel: int = activos[k_sel]
		if not f_de.has(tid_sel):
			f_de[tid_sel] = _factor_edif(_nombre[tid_sel], i)
		var f: float = f_de[tid_sel]
		if f > mejor_f:
			mejor_f = f
			elegido = tid_sel
		if AzarScript.u(semilla, 6, i, mes_n, intento) < f:
			elegido = tid_sel
			break
	d.conceder(elegido, i)
	_conocidos_n[elegido] = int(_conocidos_n.get(elegido, 0)) + 1
	d.marcar_planeta(i, floori(float(mes_n) / 12.0))
	_nuevos.append(i)
	descubridor[i] = elegido
	fecha_desc[i] = mes_n
	n_descubiertos += 1
	_quitar_candidato(i)
	for dep in d.dependientes[i]:                            # lo que se abre: nuevos candidatos del planeta, y se desbloquean los que esperaban
		var di: int = int(dep)
		if d.frontera[di] == 0 and _es_cand[di] == 0 and _req_planeta(di):
			_es_cand[di] = 1
			candidatos.append(di)
		_bloqueado.erase(di)
	if mundo.jugador != "" and _nombre.get(elegido, "") == mundo.jugador:
		mundo.evento(elegido, "Tu país descubre: %s" % String(d.nombre[i]))
	_al_aprender(elegido, i)
	_difundir(elegido, i)


func _quitar_candidato(i: int) -> void:
	_es_cand[i] = 0
	var k := candidatos.find(i)
	if k >= 0:
		candidatos.remove_at(k)


## El país `tid` acaba de aprender `j` (por descubrimiento o contagio): lo que dependía de `j` y el planeta ya conoce se le reprograma.
func _al_aprender(tid: int, j: int) -> void:
	for dep in d.dependientes[j]:
		var di: int = int(dep)
		_bloqueado.erase(di)
		if d.frontera[di] == 1 and not d.conoce(tid, di) and d.requisitos_cumplidos(tid, di):
			_programar(tid, di, 1.5, tid)


## Cuenta la novedad `i` desde el país `desde` a sus vecinos, aliados y unos viajeros lejanos.
func _difundir(desde: int, i: int) -> void:
	if mundo.ia != null:
		for v in mundo.ia.vecinos_ids(desde):
			_programar(int(v), i, 2.0, desde)
	if mundo.diplomacia != null:
		for a in mundo.diplomacia.aliados_de(desde):
			_programar(int(a), i, 2.5, desde)
	if activos.size() > 1:
		for v in VIAJEROS:
			var k := int(AzarScript.u(semilla, 5, desde * CLAVE + i, v) * float(activos.size()))
			var destino: int = activos[mini(k, activos.size() - 1)]
			if destino != desde:
				_programar(destino, i, 0.35, desde)


## Programa que `tid` se entere de `i`. `contacto` = qué tan fácil le llega (2 = vecino; 0.35 = viajero lejano): la tardanza es L_ERA · (0.3 + Exp(1)) / contacto.
func _programar(tid: int, i: int, contacto: float, desde: int) -> void:
	if not _nombre.has(tid) or d.conoce(tid, i):
		return
	var clave := tid * CLAVE + i
	if _pend.has(clave):
		return
	var l: float = L_ERA[mini(int(d.era[i]), L_ERA.size() - 1)]
	var meses := maxi(1, roundi(l * (0.3 + AzarScript.expo(semilla, 3, clave, desde)) / contacto))
	_pend[clave] = true
	var m := mes_n + meses
	if _cola.has(m):
		(_cola[m] as Array).append(clave)
	else:
		_cola[m] = [clave]


## Llega el contacto: el país aprende `i` si conoce sus prerrequisitos (si no, queda para cuando los aprenda: `_al_aprender`).
func _contacto(clave: int) -> void:
	_pend.erase(clave)
	var tid := floori(float(clave) / float(CLAVE))
	var i := clave % CLAVE
	if d.conoce(tid, i) or not d.requisitos_cumplidos(tid, i):
		return
	d.conceder(tid, i)
	_conocidos_n[tid] = int(_conocidos_n.get(tid, 0)) + 1
	n_contagios += 1
	_al_aprender(tid, i)
	_difundir(tid, i)


## Cada país sin tierra copia una vez al año (le toca en el mes `turno` = su posición mod 12) al más sabio de su continente: la unión de dos conocimientos
## cerrados sigue cerrada. Repartido por meses para que no haya un pico de 1.700 × (países sin tierra) comprobaciones de golpe.
func _poner_al_dia_sin_tierra(turno: int) -> void:
	if turno >= _sin_tierra.size():
		return
	var mejor := {}                                          # continente -> ID del país con tierra que más conoce
	for tid in activos:
		var c: String = _cont.get(tid, "")
		if not mejor.has(c) or int(_conocidos_n.get(tid, 0)) > int(_conocidos_n.get(mejor[c], 0)):
			mejor[c] = tid
	for k in range(turno, _sin_tierra.size(), 12):
		var tid: int = _sin_tierra[k]
		var c2: String = _cont.get(tid, "")
		if not mejor.has(c2) or int(_conocidos_n.get(mejor[c2], 0)) <= int(_conocidos_n.get(tid, 0)):
			continue
		var donante: PackedByteArray = d.estado[mejor[c2]]
		var propio: PackedByteArray = d.estado[tid]
		var suma := 0
		for j in _nuevos:                                    # todo país parte de la frontera inicial: solo puede faltarle algo de lo que el planeta descubrió después (en orden, así sus prerrequisitos entran antes)
			if donante[j] == 1 and propio[j] == 0:
				propio[j] = 1
				suma += 1
		if suma > 0:
			d.estado[tid] = propio
			_conocidos_n[tid] = int(_conocidos_n.get(tid, 0)) + suma


# ─────────────────────────────────────────────────────────────
# Capacidad, edificios y materias
# ─────────────────────────────────────────────────────────────
## Capacidad por país. Cada mes se recalcula la de 1/CAP_GRUPOS de los países con tierra (sin picos); la lista de países con tierra y sin tierra se rehace cada REFRESCO_CAP
## meses (o entera con `todo`).
func _refrescar_capacidad(todo: bool) -> void:
	if todo or mes_n - _mes_cap >= REFRESCO_CAP:
		_mes_cap = mes_n
		activos = PackedInt32Array()
		_sin_tierra = PackedInt32Array()
		for nombre in mundo.paises:
			var p = mundo.paises[nombre]
			if p.inerte:
				continue
			var tid: int = int(p.tid)
			if (p.provincias as Array).is_empty():
				_sin_tierra.append(tid)
			else:
				activos.append(tid)
				if todo or not _cap.has(tid):
					_recalcular_cap(tid)
		return
	for j in range(posmod(mes_n, CAP_GRUPOS), activos.size(), CAP_GRUPOS):
		_recalcular_cap(activos[j])


func _recalcular_cap(tid: int) -> void:
	var p = mundo.paises[_nombre[tid]]
	var col: PackedFloat64Array = mundo.bd.vars["poblacion"].col_f
	var pob := 0.0
	for pi in p.provincias:
		pob += col[mundo.provincias[int(pi)].ix]
	var ratio := clampf(float(_conocidos_n.get(tid, 0)) / float(maxi(d.cuenta_f, 1)), 0.0, 1.0)
	_cap[tid] = pow(pob / 1.0e6 + 0.02, CAP_EXPONENTE) * (0.4 + 0.6 * ratio)


## Los edificios de una provincia se guardan como texto «slug:cantidad;slug:cantidad» y solo los que tienen más de 0. El motor busca ahí directamente: no arma el
## diccionario por provincia (7.600 de ellos pesaban ~70 MB y su primera lectura daba picos de 3 ms por país grande).
## `mapa` = [[«slug:», «;slug:», slug], …] (las dos formas de encontrarlo: al principio del texto o tras un «;»). Devuelve, por entrada, 1 si algún edificio del país
## la cumple. Una sola pasada por las provincias; se detiene en cuanto las encuentra todas.
func _presentes(nombre: String, mapa: Array) -> PackedByteArray:
	var hay := PackedByteArray()
	hay.resize(mapa.size())
	var faltan := mapa.size()
	var prov: Array = mundo.provincias
	var bd = mundo.bd
	for pi in mundo.paises[nombre].provincias:
		var t: String = bd.txt("edificios", int(prov[int(pi)].tid), "")
		if t == "":
			continue
		for k in mapa.size():
			if hay[k] == 0 and (t.begins_with(mapa[k][0]) or t.contains(mapa[k][1])):
				hay[k] = 1
				faltan -= 1
		if faltan == 0:
			break
	return hay


## Las búsquedas (una por edificio distinto) de la receta de `i`, con el índice del grupo de la receta que cada una cumple. Se arma una vez por descubrimiento.
func _busqueda_edif(i: int) -> Dictionary:
	var c = _busq_edif.get(i)
	if c != null:
		return c
	var mapa := []
	var grupos_de := []
	var pos := {}
	var grupos: Array = d.edif[i]
	for gi in grupos.size():
		for b in grupos[gi]:
			var sl := String(d.slug[int(b)])
			if not pos.has(sl):
				pos[sl] = mapa.size()
				mapa.append([sl + ":", ";" + sl + ":", sl])
				grupos_de.append([])
			(grupos_de[pos[sl]] as Array).append(gi)
	c = {"mapa": mapa, "grupos_de": grupos_de, "pos": pos}
	_busq_edif[i] = c
	return c


## Qué grupos de la receta de `i` cumple el país `nombre` (1 = tiene algún edificio del grupo).
func _grupos_cumplidos(nombre: String, i: int) -> PackedByteArray:
	var grupos: Array = d.edif[i]
	var cumple := PackedByteArray()
	cumple.resize(grupos.size())
	if grupos.is_empty() or mundo.edificios == null:
		cumple.fill(1)
		return cumple
	var bq := _busqueda_edif(i)
	var hay := _presentes(nombre, bq["mapa"])
	for k in hay.size():
		if hay[k] == 1:
			for gi in bq["grupos_de"][k]:
				cumple[gi] = 1
	return cumple


## Factor de edificios de la receta de `i` para el país `nombre`: ×SIN_EDIFICIO por cada grupo del que no tenga ningún edificio (mínimo 0,01).
func _factor_edif(nombre: String, i: int) -> float:
	var grupos: Array = d.edif[i]
	if grupos.is_empty() or mundo.edificios == null:
		return 1.0
	var faltan := 0
	for v in _grupos_cumplidos(nombre, i):
		if v == 0:
			faltan += 1
	return maxf(pow(SIN_EDIFICIO, float(faltan)), 0.01)


func _factor_mat(nombre: String, i: int) -> float:
	var m: PackedStringArray = d.mat[i]
	if m.is_empty():
		return 1.0
	var ps = mundo.materias_pais.get(nombre)
	if ps == null:
		return MATERIA_SIN_DATOS
	for x in m:
		if (ps as PackedStringArray).has(x):
			return CON_MATERIA
	return 1.0


# ─────────────────────────────────────────────────────────────
# Consultas (ficha de la pantalla de Descubrimientos y Debug)
# ─────────────────────────────────────────────────────────────
## Quién lo descubrió y cuándo: {"pais": nombre, "anio": año} o {} si ya estaba al empezar la partida (o no se ha descubierto).
func quien(i: int) -> Dictionary:
	if not listo or i < 0 or i >= d.n or descubridor[i] < 0:
		return {}
	return {"pais": String(_nombre.get(descubridor[i], "?")), "anio": floori(float(fecha_desc[i]) / 12.0)}


## La receta de `i` mirada desde el país `pais`: qué le falta o le sobra. {"edif": [{"razon", "tiene", "opciones": [{"nombre", "tiene"}]}], "mat": [{"nombre", "tiene"}], "factor": float}
func receta_de(i: int, pais: String) -> Dictionary:
	var r := {"edif": [], "mat": [], "factor": 1.0}
	if d == null or i < 0 or i >= d.n:
		return r
	var con_pais: bool = mundo.paises.has(pais) and mundo.edificios != null
	var cumple := PackedByteArray()
	var hay := PackedByteArray()
	var bq := {}
	if con_pais:
		bq = _busqueda_edif(i)
		hay = _presentes(pais, bq["mapa"])
		cumple = _grupos_cumplidos(pais, i)
	for k in (d.edif[i] as Array).size():
		var g: PackedInt32Array = d.edif[i][k]
		var ops := []
		for b in g:
			var tiene := false
			if con_pais:
				tiene = hay[int(bq["pos"][String(d.slug[int(b)])])] == 1
			ops.append({"nombre": String(d.nombre[int(b)]), "tiene": tiene})
		var ri: int = int(d.regla[i][k]) if k < (d.regla[i] as PackedInt32Array).size() else -1
		r["edif"].append({"razon": String(d.razones[ri]) if ri >= 0 and ri < d.razones.size() else "", "tiene": con_pais and cumple[k] == 1, "opciones": ops})
	var ps = mundo.materias_pais.get(pais) if mundo.paises.has(pais) else null
	for x in d.mat[i]:
		r["mat"].append({"nombre": String(x), "tiene": ps != null and (ps as PackedStringArray).has(x)})
	if con_pais:
		r["factor"] = _factor_edif(pais, i) * _factor_mat(pais, i)
	return r


## Resumen de una línea para el Debug.
func resumen() -> String:
	return "semilla %d · mes %d · %d candidatos (%d bloqueados) · %d descubiertos · %d contagios · %d contactos en cola · %d países activos · %.2f ms por mes (máx %.1f)" % [
		semilla, mes_n, candidatos.size(), _bloqueado.size(), n_descubiertos, n_contagios, _pend.size(), activos.size(),
		float(us_total) / maxf(float(meses_corridos), 1.0) / 1000.0, float(us_max) / 1000.0]
