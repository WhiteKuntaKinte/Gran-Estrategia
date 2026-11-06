extends RefCounted
## IA de los países que controla el ordenador (0.1.8.2). Primera versión: conquista básica de provincias.
##
## Una IA NO existe por defecto en ningún país: se activa desde Debug > IA (país por país o con los botones rápidos).
## Cada IA decide cada PERIODO días (repartidas en el tiempo para que no coincidan todas el mismo día) y solo piensa en 4 cosas:
##   1. DINERO: mantiene un ejército que su economía pueda sostener (el mantenimiento no pasa de una fracción de sus ingresos),
##      guarda una reserva y gasta el resto en reclutar, sobre todo en la provincia de la que saldrá su próximo ataque.
##      Si se queda en rojo sin remedio, licencia soldados antes de que deserten.
##   2. GUERRA: ataca al vecino al que le gana por bastante en soldados y que más produce; como máximo 2 guerras a la vez, nunca con la
##      caja en rojo, y con una tregua de 365 días tras cada paz. En la campaña solo se puede atacar a países con IA y al jugador.
##   3. OPERACIONES: elige provincias enemigas pegadas a su frente (o suyas ocupadas, que valen el doble) y manda hacia allí los
##      regimientos libres más cercanos, pero solo si suman bastante más soldados que los defensores.
##   4. PAZ: cobra la victoria (paz «con posesión», con indemnización si ganó de sobra), acepta tablas si la guerra se estanca y se
##      rinde (posesión) si va perdiendo de forma clara. Al jugador no le propone la paz (la propone él).
## Todo son reglas sencillas y medibles (ver NOTAS_TECNICAS_0.1.8.2.md); los números están en las constantes de abajo (PROVISIONALES).

const PerfilScript := preload("res://scripts/perfil.gd")
const RedScript := preload("res://scripts/red_provincias.gd")

const PERIODO := 4                    # días entre decisiones de una IA que está EN GUERRA
const PERIODO_PAZ := 12               # 0.1.8.3: ... y de una IA en paz (no necesita pensar cada 4 días: solo recluta y mira si ataca a alguien)
const MAX_IA_PASO := 24               # 0.1.8.3: decisiones como máximo por paso de simulación (las más atrasadas y las que están en guerra, primero)
const IA_MS_PASO_ALTO := 12.0         # 0.1.8.3: con pasos de más de 2 días (velocidades altas) la IA deja de decidir al pasar de 12 ms en ese paso (mínimo 3 decisiones)
const MAX_GUERRAS := 2
const FRAC_GUERRAS_GLOBAL := 0.10     # 0.1.8.3: las guerras abiertas en todo el mundo no pasan del 10 % del número de IA (mínimo 2)
const ESPERA_GUERRA_DIAS := 540.0     # 0.1.8.3: una IA que PODRÍA atacar a alguien tarda en promedio 540 días en decidirlo (antes: ~11 días)
const TREGUA_DIAS := 1825             # 0.1.8.3: tras una paz, esa pareja no vuelve a la guerra por una IA en 5 años (antes: 1 año)
const DESCANSO_TRAS_PAZ := 365        # 0.1.8.3: y las IA que firmaron la paz no declaran NINGUNA otra guerra en 1 año
const TASA_EJERCITO_MIN := 0.0003     # 0.1.8.3: un país sin datos de ejército parte de esta fracción de su población
const TOPE_PAZ := 1.30                # 0.1.8.3: en paz una IA no pasa de 1,3 × su ejército inicial...
const TOPE_GUERRA := 2.5              # ... y en guerra, de 2,5 ×
const CRECE_PAZ_ANUAL := 0.05         # 0.1.8.3: cuánto puede reclutar al año (fracción de su tope) en paz...
const CRECE_GUERRA_ANUAL := 0.50      # ... y en guerra
const DIAS_RECLUTA_MAX := 90          # el cupo de reclutamiento no se acumula más de 90 días
const RATIO_GUERRA := 1.6             # soldados propios / soldados del rival para atreverse a declarar la guerra (× la cautela de cada país)
const RATIO_ATAQUE := 1.3             # fuerza enviada / defensores para atacar una provincia
const RADIO_ATAQUE := 70.0            # distancia máxima (unidades de mapa, ~1.170 km) de los regimientos que se mandan a una provincia
const MAX_ORDENES := 16               # marchas que da una IA en una decisión
const MAX_OBJETIVOS := 14             # provincias enemigas que mira por decisión
const FRAC_GASTO_PAZ := 0.14          # fracción de los ingresos que puede gastar en mantener tropas en paz...
const FRAC_GASTO_GUERRA := 0.32       # ... y en guerra
const MAX_POB_EJERCITO := 0.015       # un ejército nunca pasa del 1,5 % de la población del país (además de los topes de arriba)
const DIAS_FOTO_ECONOMIA := 10        # los ingresos y la población se recalculan cada tantos días (cambian despacio y calcularlos cuesta)
const DIAS_FRENTES := 5               # el mapa de control (quién controla cada provincia) se rehace como mucho cada tantos días
const DIAS_RESERVA_PAZ := 15.0        # reserva de caja en días de ingresos
const DIAS_RESERVA_GUERRA := 15.0
const ENVIO_MARGEN := 1.35            # al atacar manda 1,35 × lo que necesita (no todo el regimiento)
const ENVIO_MIN := 2000               # y como mínimo tantos soldados
const MAX_REG := 30000                # un regimiento de la IA nunca pasa de tantos soldados (así se pueden mandar por partes)
const LOTE_MIN := 300                 # menos soldados que esto no vale la pena reclutarlos
const LOTE_MAX_FRAC := 0.15           # una compra no pasa del 15 % del ejército objetivo (ni baja de 5.000)
const PAZ_GANADA := 0.30              # puntaje de guerra desde el que cobra la victoria
const PAZ_INDEMNIZACION := 0.12       # ... y con indemnización
const PAZ_CAPITULA := -0.20           # puntaje desde el que se rinde
const PAZ_TABLAS_DIAS := 150          # guerra estancada (|puntaje| < 4 %) tantos días: paz blanca
const PAZ_LARGA_DIAS := 120           # guerra con ventaja pequeña: se queda con lo que tiene
const GRACIA_INICIAL := 120           # 0.1.8.2a: ninguna IA declara guerras en sus primeros 120 días (da tiempo a orientarse)
const GRACIA_JUGADOR := 240           # ... y al jugador no lo ataca ninguna IA en los primeros 240 días
const AVISO_PAZ_DIAS := 45            # una IA que quiere la paz con el jugador se lo propone (pop-up) como mucho cada 45 días
const LOTE_IA := 1                    # IA que deciden por llamada de `fase_dia` (cada decisión cuesta 0,3-3 ms, a veces 20): una por llamada para que el presupuesto del fotograma corte justo

var mundo
var ej
var g
var activas := {}                     # nombre de país -> estado (ver _estado_nuevo)
var version := 0                      # sube al activar o desactivar (la interfaz redibuja)
var dia_n := 0                        # días simulados desde que existe la IA
var ms_dia := 0.0                     # lo que tardó la IA el último día (ms), para medir rendimiento
var ms_max := 0.0
var decisiones := 0                   # decisiones tomadas en total (para pruebas y estadísticas)
var guerras_declaradas := 0
var paces_firmadas := 0
var tregua := {}                      # clave de pareja -> día en que termina la tregua
var _sold_dia := {}                   # ID país -> soldados (foto de HOY: se toma una vez al día y se ajusta al reclutar o licenciar)
var _sold_dia_n := -1
var prof := {}                        # sección -> [microsegundos totales, llamadas] (para medir qué cuesta más; Debug > Rend.)
var n_rutas := 0                      # órdenes de marcha dadas en total
var dec_paso := 0                     # decisiones del último paso (para medir)
var _cola_hoy: Array = []             # nombres de las IA que aún deben decidir en el paso en curso
var _cola_lista := false              # ¿hay un paso a medias? (la cola ya se armó)
var _k_paso := 1                      # días del paso en curso

# red de fronteras, guardada hasta que cambie algo (dueños u ocupantes)
var _aristas_t := PackedInt32Array()  # pares de provincias vecinas por tierra o estrecho (a, b, a, b...) sin las excluidas
var _aristas_ok := false
var _ctrl := PackedInt32Array()       # por provincia: ID del país que la controla (el ocupante si la hay; si no, el dueño)
var _dueno := PackedInt32Array()      # por provincia: ID del país dueño
var _frente := {}                     # ID de país -> [[provincia suya, provincia de otro país que la toca], ...] (según el control). 0.1.8.3: se calcula POR PAÍS cuando se pide (`_frente_de`)
var _ctrl_pais := {}                  # 0.1.8.3: ID de país -> [provincias que controla]
var _vecinos_dueno := {}              # ID de país -> {ID de país vecino: nº de fronteras} (según los dueños)
var _ver_frente := Vector2i(-1, -1)
var _dia_frente := -1000
var _activas_prov := PackedInt32Array()   # índices de las provincias que existen en este modo
var _ver_vecinos := -1
var _clave_modo := ""                 # modo del mundo con el que se prepararon las aristas (si cambia, se rehacen)


func iniciar(m) -> void:
	mundo = m
	ej = m.ejercito
	g = m.guerra


func _estado_nuevo(tid: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = 7919 * (tid + 13)
	return {
		"tid": tid,
		"proximo": dia_n + (tid % PERIODO_PAZ),     # 0.1.8.3: día (de la IA) en que le toca decidir; se reparte para que no decidan todas juntas
		"ult_dec": dia_n,                           # día de su última decisión
		"base_sold": -1.0,                          # ejército de referencia (el que tenía al empezar): sobre él se calculan sus topes
		"ult_recl": dia_n,                          # día desde el que cuenta su cupo de reclutamiento
		"cautela": 1.0 + 0.5 * r.randf(),          # 1,0 (decidida) a 1,5 (prudente): multiplica el ratio que pide para declarar la guerra
		"rng": r,
		"ini": {},                                  # ID rival -> día (de la IA) en que vio empezar esa guerra
		"base": -1,                                 # provincia (ID) desde la que sale su próximo ataque: ahí recluta
		"no_guerra_hasta": dia_n + GRACIA_INICIAL,
		"aviso_paz": {},                            # ID rival (jugador) -> día hasta el que no vuelve a proponerle la paz
		"ultimo": "Todavía no ha decidido nada.",   # lo último que hizo (para Debug > IA)
		"n_ordenes": 0,
		"foto_dia": -1000,                          # día en que se tomó la última foto de la economía
		"foto": {},
		"cap": -2,                                  # provincia (ID) de la capital (-2 = sin calcular, -1 = no tiene)
	}


# ─────────────────────────────────────────────────────────────
# Activar y desactivar
# ─────────────────────────────────────────────────────────────


func puede_tener_ia(pais: String) -> bool:
	if mundo == null or not mundo.paises.has(pais) or pais == mundo.jugador or mundo.es_inerte(pais):
		return false
	return not mundo.paises[pais].provincias.is_empty()


func activar(pais: String) -> bool:
	if activas.has(pais):
		return true
	if not puede_tener_ia(pais):
		return false
	activas[pais] = _estado_nuevo(int(mundo.paises[pais].tid))
	version += 1
	return true


## Apaga la IA de un país. En la campaña, un país sin IA no se puede conquistar: sus guerras abiertas terminan en paz blanca.
func desactivar(pais: String, cerrar_guerras := true) -> void:
	if not activas.has(pais):
		return
	var tid: int = int(activas[pais]["tid"])
	activas.erase(pais)
	version += 1
	if cerrar_guerras and mundo != null and mundo.es_campana() and g != null and pais != mundo.jugador:
		for r in g.rivales_de(tid):
			g.firmar_paz(tid, int(r), {}, "IA desactivada")


## 0.1.8.3: cambió quién controla qué. El país que el jugador deja pasa a ser de la IA (en la campaña siempre; en dev, si ya hay IA en el mundo: sin ella el
## modo dev es un tablero libre) y el que toma deja de tener IA SIN cerrar sus guerras (las hereda el jugador).
func control_cambiado(antes: String, ahora: String) -> void:
	if ahora != "" and activas.has(ahora):
		desactivar(ahora, false)
	if antes != "" and antes != ahora and (mundo.es_campana() or not activas.is_empty()):
		activar(antes)


func desactivar_todas() -> void:
	for p in activas.keys():
		desactivar(String(p))


## Países de la lista (o todos los que existen en este modo) que pueden tener IA. Devuelve cuántos quedaron con IA.
func activar_lista(nombres: Array) -> int:
	var n := 0
	for p in nombres:
		if activar(String(p)):
			n += 1
	return n


## Nombres de los países que tocan a `pais` por tierra o a través de un estrecho (según los dueños de las provincias).
func vecinos_de(pais: String) -> Array:
	var r := []
	if mundo == null or not mundo.paises.has(pais):
		return r
	_preparar_frentes()
	var tid: int = int(mundo.paises[pais].tid)
	for t in _vecinos_dueno.get(tid, {}):
		var n: String = mundo.bd.nombre_de(int(t))
		if mundo.paises.has(n) and not (mundo.paises[n].provincias as Array).is_empty() and not mundo.es_inerte(n) and (not mundo.es_campana() or mundo.campana.has(n)):
			r.append(n)
	r.sort()
	return r


## Los países en los que tiene sentido poner una IA en este modo (campaña: solo los de la campaña).
func candidatos() -> Array:
	var r := []
	for n in mundo.paises:
		if mundo.paises[n].provincias.is_empty() or mundo.paises[n].inerte:
			continue
		if mundo.es_campana() and not mundo.campana.has(n):
			continue
		if n == mundo.jugador:
			continue
		r.append(String(n))
	r.sort()
	return r


# ─────────────────────────────────────────────────────────────
# Reloj
# ─────────────────────────────────────────────────────────────
func registrar_paz(a: int, b: int) -> void:
	var k: String = g.clave_par(a, b)
	tregua[k] = dia_n + TREGUA_DIAS
	paces_firmadas += 1
	for t in [a, b]:                                                  # 0.1.8.3: las IA que acaban de pelear descansan un año de guerras nuevas
		var nom: String = mundo.bd.nombre_de(int(t))
		if activas.has(nom):
			activas[nom]["no_guerra_hasta"] = maxi(int(activas[nom]["no_guerra_hasta"]), dia_n + DESCANSO_TRAS_PAZ)


## Días de tregua que le quedan a la pareja (0 si no hay). Los usa la pestaña Diplomacia.
func tregua_restante(a: int, b: int) -> int:
	return maxi(0, int(tregua.get(g.clave_par(a, b), -1)) - dia_n)


## ¿Hay tregua vigente entre las dos? (atajo de `tregua_restante`)
func _en_tregua(a: int, b: int) -> bool:
	return tregua_restante(a, b) > 0


## Un paso de juego: las IA que toca hoy deciden.
func avanzar_dia(k := 1) -> void:
	while fase_dia(k):
		pass


## Un paso de la IA en LOTES (0.1.8.2a): cada llamada deja decidir a unas pocas IA y devuelve true mientras queden más por decidir en este paso.
## Así el juego reparte el paso entre fotogramas; `avanzar_dia` las corre todas de golpe.
## 0.1.8.3: el paso puede ser de `k` días. Le toca decidir a la IA cuyo `proximo` ya llegó (en guerra cada PERIODO días, en paz cada PERIODO_PAZ);
## deciden como mucho MAX_IA_PASO por paso, primero las que están en guerra y luego las más atrasadas: el coste de la IA por paso queda acotado
## aunque haya 250 IA y el tiempo corra a x6 (a cambio, en x6 cada IA piensa menos veces por año de juego).
func fase_dia(k := 1) -> bool:
	if not _cola_lista:
		dia_n += k
		_k_paso = k
		ms_dia = 0.0
		dec_paso = 0
		if activas.is_empty() or ej == null or ej.red == null or not ej.red.listo:
			return false
		_cola_lista = true
		_armar_cola()
	var t0 := Time.get_ticks_usec()
	var n := 0
	while not _cola_hoy.is_empty() and n < LOTE_IA:
		if _k_paso > 2 and dec_paso >= 3 and ms_dia + float(Time.get_ticks_usec() - t0) / 1000.0 > IA_MS_PASO_ALTO:
			_cola_hoy.clear()                                       # paso largo y sin presupuesto: las demás esperan al siguiente (siguen «atrasadas», irán primero)
			break
		var nombre: String = _cola_hoy.pop_front()
		n += 1
		if activas.has(nombre):
			_decidir(nombre, activas[nombre])
			dec_paso += 1
	ms_dia += float(Time.get_ticks_usec() - t0) / 1000.0
	if _cola_hoy.is_empty():
		_cola_lista = false
		ms_max = maxf(ms_max, ms_dia)
		return false
	return true


## Arma la cola de IA que deciden en este paso: las que ya cumplieron su `proximo`, primero las que están en guerra y luego las más atrasadas,
## y como mucho MAX_IA_PASO.
func _armar_cola() -> void:
	_cola_hoy.clear()
	var debidas := []                                               # [en guerra (0/1), atraso en días, nombre]
	for nombre in activas.keys():
		var st: Dictionary = activas[nombre]
		if dia_n >= int(st["proximo"]):
			debidas.append([0 if mundo.bd.num("guerras_activas", int(st["tid"]), 0.0) > 0.0 else 1, int(st["proximo"]) - dia_n, String(nombre)])
	debidas.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for i in mini(debidas.size(), MAX_IA_PASO):
		_cola_hoy.append(String(debidas[i][2]))


## Soldados de un país según la foto de hoy (contarlos de nuevo cada vez que otra IA mueve tropas cuesta demasiado).
func _soldados(tid: int) -> int:
	if _sold_dia_n != dia_n:
		_sold_dia = ej.soldados_por_pais().duplicate()
		_sold_dia_n = dia_n
	return int(_sold_dia.get(tid, 0))


func _ajustar_soldados(tid: int, delta: int) -> void:
	_soldados(tid)
	_sold_dia[tid] = maxi(0, int(_sold_dia.get(tid, 0)) + delta)


## Anota en `prof` el tiempo de una sección (ver perfil.gd).
func _p(sec: String, t0: int) -> void:
	PerfilScript.anotar(prof, sec, t0)


func _decidir(nombre: String, st: Dictionary) -> void:
	var e = mundo.paises.get(nombre)
	if e == null or e.provincias.is_empty() or nombre == mundo.jugador:
		activas.erase(nombre)                                # el país ya no existe o ahora lo controla el jugador
		version += 1
		return
	decisiones += 1
	var tid: int = int(e.tid)
	var dias_desde: int = maxi(dia_n - int(st["ult_dec"]), 1)       # días de juego desde su decisión anterior (los pasos largos pesan más)
	st["ult_dec"] = dia_n
	var rivales: Array = g.rivales_de(tid)
	for r in st["ini"].keys():                                # guerras que ya terminaron
		if not rivales.has(r):
			st["ini"].erase(r)
	for r in rivales:
		if not st["ini"].has(int(r)):
			st["ini"][int(r)] = dia_n
	var t0 := Time.get_ticks_usec()
	_preparar_frentes()
	_p("frentes", t0)
	t0 = Time.get_ticks_usec()
	var eco: Dictionary = _economia(nombre, st, e)
	_p("economia", t0)
	t0 = Time.get_ticks_usec()
	_paz(nombre, st, tid, rivales)
	rivales = g.rivales_de(tid)
	_p("paz", t0)
	if rivales.size() < MAX_GUERRAS:
		t0 = Time.get_ticks_usec()
		_buscar_guerra(nombre, st, e, tid, eco, rivales, dias_desde)
		rivales = g.rivales_de(tid)
		_p("guerra", t0)
	t0 = Time.get_ticks_usec()
	_operar(nombre, st, tid, rivales)
	_p("operar", t0)
	t0 = Time.get_ticks_usec()
	_reclutar(nombre, st, e, tid, eco, not rivales.is_empty())
	_p("reclutar", t0)
	st["proximo"] = dia_n + (PERIODO if not rivales.is_empty() else PERIODO_PAZ)


# ─────────────────────────────────────────────────────────────
# 1. Dinero
# ─────────────────────────────────────────────────────────────
## Foto de la economía del país en su divisa: ingresos, tropas, precio por soldado y días de caja. Los ingresos, los precios y la población
## se guardan DIAS_FOTO_ECONOMIA días (calcularlos recorre todas las provincias del país); las tropas y la caja se leen al momento.
func _economia(nombre: String, st: Dictionary, e) -> Dictionary:
	if dia_n - int(st["foto_dia"]) >= DIAS_FOTO_ECONOMIA or (st["foto"] as Dictionary).is_empty():
		var pu: Dictionary = mundo.precios_unidad_local(nombre)
		st["foto"] = {"ing": mundo.ingreso_diario_local(nombre),
			"mps": float(pu["mant"]) / 365.25 / float(ej.TAM_PELOTON),               # mantenimiento por soldado y por día
			"cps": float(pu["recl"]) / float(ej.TAM_PELOTON),                        # costo de reclutar un soldado
			"pob": mundo.poblacion_de(nombre)}
		st["foto_dia"] = dia_n
	var f: Dictionary = st["foto"]
	var sold: int = _soldados(int(e.tid))
	if float(st["base_sold"]) < 0.0:                                 # 0.1.8.3: el ejército con el que empezó (o, si no tenía, una fracción mínima de su población)
		st["base_sold"] = maxf(float(sold), TASA_EJERCITO_MIN * float(f["pob"]))
	var tes: float = e.tesoreria if e.tiene_tesoreria() else 0.0
	var ing: float = f["ing"]
	return {"ing": ing, "sold": sold, "mps": f["mps"], "cps": f["cps"], "pob": f["pob"], "tes": tes, "mant": float(f["mps"]) * float(sold),
		"dias_caja": tes / maxf(ing, 1.0)}


func _reclutar(nombre: String, st: Dictionary, e, tid: int, eco: Dictionary, en_guerra: bool) -> void:
	var ing: float = eco["ing"]
	var sold: int = eco["sold"]
	var mps: float = eco["mps"]
	var cps: float = eco["cps"]
	var tes: float = eco["tes"]
	if ing <= 0.0 or mps <= 0.0 or cps <= 0.0:
		return
	# si el balance es negativo y la caja se acaba, licencia soldados antes de que deserten
	if float(eco["mant"]) > ing and tes < 12.0 * (float(eco["mant"]) - ing) and sold > 0:
		var quitados: int = ej.desertar_pais(tid, 0.06, "Licenciamiento (IA)")
		if quitados > 0:
			_ajustar_soldados(tid, -quitados)
			st["ultimo"] = "Licenció %d soldados: su economía no podía mantenerlos." % quitados
		return
	var frac := FRAC_GASTO_GUERRA if en_guerra else FRAC_GASTO_PAZ
	frac += 0.15 * clampf((float(eco["dias_caja"]) - 60.0) / 120.0, 0.0, 1.0)         # con mucha caja ahorrada gasta más
	# 0.1.8.3 · TOPES DE EJÉRCITO: lo que aguanta la economía, pero NUNCA más de TOPE_PAZ × (o TOPE_GUERRA × en guerra) el ejército con el que empezó el
	# país, y reclutando despacio (CRECE_*_ANUAL del tope por año). Antes solo mandaba la economía (hasta el 1,5 % de la población): en 150 días el mundo
	# pasaba de 21 a 115 millones de soldados y ningún ejército se podía vencer.
	var base: float = maxf(float(st["base_sold"]), 1.0)
	var tope: float = (TOPE_GUERRA if en_guerra else TOPE_PAZ) * base
	var sold_max: float = minf(minf(frac * ing / mps, MAX_POB_EJERCITO * float(eco["pob"])), tope)
	var ritmo: float = tope * (CRECE_GUERRA_ANUAL if en_guerra else CRECE_PAZ_ANUAL) / 365.0       # soldados por día que puede reclutar
	st["cupo"] = minf(float(st.get("cupo", 0.0)) + ritmo * float(maxi(dia_n - int(st["ult_recl"]), 0)), ritmo * float(DIAS_RECLUTA_MAX))
	st["ult_recl"] = dia_n
	if float(sold) >= sold_max:
		st["cupo"] = 0.0                                              # ya está lleno: el cupo no se acumula
		return
	var reserva: float = (DIAS_RESERVA_GUERRA if en_guerra else DIAS_RESERVA_PAZ) * ing
	var libre: float = tes - maxf(reserva, 10.0 * float(eco["mant"]))
	if libre <= 0.0:
		return
	var n := int(minf(minf(floorf(libre / cps), sold_max - float(sold)), float(st["cupo"])))
	n = mini(n, maxi(5000, int(LOTE_MAX_FRAC * sold_max)))
	if n < LOTE_MIN:
		return
	var prov_tid := _prov_reclutar(nombre, st, tid)
	if prov_tid < 0:
		return
	var hecho := 0
	var reg := _regimiento_mayor(tid, prov_tid)                   # refuerza el regimiento de la base mientras no pase de MAX_REG...
	var resto := n
	while resto > 0:
		var lote := mini(resto, MAX_REG)
		if reg >= 0:
			lote = mini(lote, MAX_REG - ej.soldados_reg(reg))
			if lote < 1:
				reg = -1                                          # ... y si ya está lleno abre otro nuevo
				continue
		var res: Dictionary = mundo.reclutar_pagando(nombre, prov_tid, lote, reg)
		if not bool(res.get("ok", false)):
			break
		hecho += lote
		resto -= lote
		reg = -1
	if hecho > 0:
		_ajustar_soldados(tid, hecho)
		st["cupo"] = maxf(0.0, float(st["cupo"]) - float(hecho))
		st["ultimo"] = "Reclutó %d soldados." % hecho


## Provincia (ID) donde recluta: la base del próximo ataque si sigue siendo suya y está libre; si no, su capital; si no, la de más población.
func _prov_reclutar(nombre: String, st: Dictionary, tid: int) -> int:
	var b: int = int(st["base"])
	if b >= 0:
		var pr = ej.provincia_por_tid(b)
		if pr != null and _ctrl.size() > int(pr.idx) and int(_ctrl[int(pr.idx)]) == tid and int(_dueno[int(pr.idx)]) == tid:
			return b
	if int(st["cap"]) == -2:
		st["cap"] = ej._provincia_capital(nombre)                # recorre las ciudades del país: solo una vez
	var cap: int = int(st["cap"])
	if cap >= 0:
		var pc = ej.provincia_por_tid(cap)
		if pc != null and _ctrl.size() > int(pc.idx) and int(_ctrl[int(pc.idx)]) == tid:
			return cap
	var mejor := -1
	var mejor_pob := -1.0
	for pi in mundo.paises[nombre].provincias:
		var pr2 = mundo.provincias[int(pi)]
		if _ctrl.size() > int(pi) and int(_ctrl[int(pi)]) == tid and pr2.poblacion > mejor_pob:
			mejor_pob = pr2.poblacion
			mejor = int(pr2.tid)
	return mejor


## Regimiento quieto más grande del país en esa provincia que aún tenga sitio (para reforzarlo en vez de abrir uno nuevo); -1 si no hay.
func _regimiento_mayor(tid: int, prov_tid: int) -> int:
	var mejor := -1
	var mejor_s := -1
	for rid in ej.regs_prov.get(prov_tid, []):
		if ej.pais_de_reg(int(rid)) != tid or ej.en_marcha_reg(int(rid)):
			continue
		var s: int = ej.soldados_reg(int(rid))
		if s < MAX_REG and s > mejor_s:
			mejor_s = s
			mejor = int(rid)
	return mejor


# ─────────────────────────────────────────────────────────────
# Fronteras (compartidas por todas las IA, se rehacen solo si cambian dueños u ocupantes)
# ─────────────────────────────────────────────────────────────
func _preparar_aristas() -> void:
	if _aristas_ok:
		return
	_aristas_ok = true
	_aristas_t = PackedInt32Array()
	_activas_prov = PackedInt32Array()
	for i in mundo.provincias.size():
		if not mundo.excluidas.has(i):
			_activas_prov.append(i)
	for a in ej.red.aristas:                                          # también cuentan los estrechos (costas a menos de ~200 km): si no, las islas nunca atacarían ni serían atacadas
		var p := int(a[0])
		var q := int(a[1])
		if mundo.excluidas.has(p) or mundo.excluidas.has(q):
			continue
		_aristas_t.append(p)
		_aristas_t.append(q)


func _preparar_frentes() -> void:
	var bd = mundo.bd
	var clave := "%s|%d" % [mundo.modo, mundo.excluidas.size()]
	if clave != _clave_modo:                                         # el mundo pasó a la campaña (o al revés): se rehace todo
		_clave_modo = clave
		_aristas_ok = false
		_ctrl = PackedInt32Array()
		_ver_frente = Vector2i(-1, -1)
		_ver_vecinos = -1
		_dia_frente = -1000
	var ver := Vector2i(bd.version_propietario, bd.version_ocupacion)
	var n: int = mundo.provincias.size()
	if _ctrl.size() == n and (ver == _ver_frente or dia_n - _dia_frente < DIAS_FRENTES):
		return                                                   # nada ha cambiado, o cambió hace menos de DIAS_FRENTES días
	_preparar_aristas()
	var col_d: PackedInt32Array = bd.vars["propietario"].col_i
	var col_o: PackedInt32Array = bd.vars["ocupante"].col_i
	if _ctrl.size() != n:
		_ctrl = PackedInt32Array()
		_dueno = PackedInt32Array()
		_ctrl.resize(n)
		_dueno.resize(n)
		_ctrl.fill(-1)
		_dueno.fill(-1)
	var ctrl := _ctrl
	var dueno := _dueno
	_ctrl_pais = {}
	for i in _activas_prov:                                      # solo las provincias que existen en este modo (en la campaña, 1.716 de 7.653)
		var ix: int = mundo.provincias[i].ix
		var d: int = col_d[ix]
		var o: int = col_o[ix]
		dueno[i] = d
		var c: int = o if o >= 0 else d
		ctrl[i] = c
		if c >= 0:
			if not _ctrl_pais.has(c):
				_ctrl_pais[c] = []
			_ctrl_pais[c].append(i)
	_frente = {}                                                 # 0.1.8.3: la frontera de cada país se calcula solo cuando una IA en guerra la pide (antes: de TODO el mundo cada vez)
	_ver_frente = ver
	_dia_frente = dia_n
	if bd.version_propietario != _ver_vecinos:                   # vecindad entre países: solo cambia cuando cambia algún dueño
		_ver_vecinos = bd.version_propietario
		_vecinos_dueno = {}
		for k in range(0, _aristas_t.size(), 2):
			var a2: int = _aristas_t[k]
			var b2: int = _aristas_t[k + 1]
			var da: int = dueno[a2]
			var db: int = dueno[b2]
			if da == db or da < 0 or db < 0:
				continue
			if not _vecinos_dueno.has(da):
				_vecinos_dueno[da] = {}
			if not _vecinos_dueno.has(db):
				_vecinos_dueno[db] = {}
			_vecinos_dueno[da][db] = int(_vecinos_dueno[da].get(db, 0)) + 1
			_vecinos_dueno[db][da] = int(_vecinos_dueno[db].get(da, 0)) + 1


## 0.1.8.3 · Frontera de un país: pares [provincia que controla, provincia vecina controlada por OTRO país]. Se calcula la primera vez que se pide tras un cambio
## de dueños u ocupantes y solo recorre las provincias de ese país y sus vecinas (no las 7.600 del mundo).
func _frente_de(tid: int) -> Array:
	if _frente.has(tid):
		return _frente[tid]
	var r := []
	var red = ej.red
	for a in _ctrl_pais.get(tid, []):
		for b in red.vecinos(int(a)):
			var cb: int = _ctrl[int(b)]
			if cb != tid and cb >= 0:
				r.append([int(a), int(b)])
	_frente[tid] = r
	return r


## Valor económico de una provincia (US$ al año aprox.: lo que produciría en manos de su dueño).
func _valor(pi: int) -> float:
	var bd = mundo.bd
	var ix: int = mundo.provincias[pi].ix
	var pob: PackedFloat64Array = bd.vars["poblacion"].col_f
	var pc: PackedFloat64Array = bd.vars["pib_pc_usd"].col_f
	return pob[ix] * pc[ix]


# ─────────────────────────────────────────────────────────────
# 2. Declarar la guerra
# ─────────────────────────────────────────────────────────────
func _buscar_guerra(nombre: String, st: Dictionary, e, tid: int, eco: Dictionary, rivales: Array, dias_desde := PERIODO) -> void:
	if dia_n < int(st["no_guerra_hasta"]):
		return
	if g.activas.size() >= maxi(2, int(ceilf(float(activas.size()) * FRAC_GUERRAS_GLOBAL))):
		return                                                       # 0.1.8.3: ya hay demasiadas guerras abiertas en el mundo
	if float(eco["dias_caja"]) < 25.0 or float(eco["mant"]) > 0.9 * float(eco["ing"]):
		return                                                   # con la economía apretada no se mete en guerras
	var sold: int = eco["sold"]
	if sold < 3000:
		return
	var vec: Dictionary = _vecinos_dueno.get(tid, {})
	if vec.is_empty():
		return
	var mejor := -1
	var mejor_score := 0.0
	for tv in vec:
		var tid_v: int = int(tv)
		var nom_v: String = mundo.bd.nombre_de(tid_v)
		if not mundo.paises.has(nom_v) or (mundo.paises[nom_v].provincias as Array).is_empty():
			continue
		if rivales.has(tid_v) or g.en_guerra(tid, tid_v) or _en_tregua(tid, tid_v):
			continue
		if nom_v == mundo.jugador and dia_n < GRACIA_JUGADOR:
			continue                                             # al jugador no se le ataca en los primeros días de la partida
		if not mundo.puede_atacar(tid, tid_v):
			continue
		var sold_v: int = _soldados(tid_v)
		var ratio: float = float(sold) / maxf(float(sold_v), 1500.0)
		if ratio < RATIO_GUERRA * float(st["cautela"]):
			continue
		var score: float = (mundo.ingreso_diario_usd(nom_v) + 1.0) * minf(ratio, 3.0) * (1.0 + 0.15 * float(vec[tv]))
		if score > mejor_score:
			mejor_score = score
			mejor = tid_v
	if mejor < 0:
		return
	var r: RandomNumberGenerator = st["rng"]
	if r.randf() > minf(float(dias_desde) / ESPERA_GUERRA_DIAS, 1.0):   # 0.1.8.3: no ataca en cuanto puede: tarda de media ESPERA_GUERRA_DIAS en «animarse»
		return
	var nom_m: String = mundo.bd.nombre_de(mejor)
	var gid: int = g.declarar(tid, mejor, "Conquista (IA)")
	if gid >= 0:
		guerras_declaradas += 1
		st["ini"][mejor] = dia_n
		st["ultimo"] = "Declaró la guerra a %s." % nom_m
		mundo.evento(tid, "%s declara la guerra a %s." % [nombre, nom_m], mejor)


# ─────────────────────────────────────────────────────────────
# 3. Operaciones
# ─────────────────────────────────────────────────────────────
func _operar(nombre: String, st: Dictionary, tid: int, rivales: Array) -> void:
	st["n_ordenes"] = 0
	if rivales.is_empty():
		return
	var lista_frente: Array = _frente_de(tid)
	if lista_frente.is_empty():
		return
	# objetivos: provincias controladas por un rival que tocan una mía (o una que yo controlo)
	var vistos := {}
	var objetivos := []                                          # [prioridad, provincia objetivo, provincia base, defensores]
	for par in lista_frente:
		var pb: int = par[1]
		if vistos.has(pb) or not rivales.has(int(_ctrl[pb])):
			continue
		var d_pb: int = int(_dueno[pb])
		if d_pb != tid and not rivales.has(d_pb):
			continue                                              # provincia de un tercero ocupada por mi rival: atacarla sería declararle la guerra a otro
		vistos[pb] = true
		var prov_tid: int = int(mundo.provincias[pb].tid)
		var def_s := 0
		for rid in ej.regs_prov.get(prov_tid, []):
			if rivales.has(ej.pais_de_reg(int(rid))):
				def_s += ej.soldados_reg(int(rid))
		var valor: float = _valor(pb) * (2.0 if d_pb == tid else 1.0)                  # liberar lo propio vale el doble
		objetivos.append([(valor + 1.0) / (1.0 + float(def_s) * 0.002), pb, int(par[0]), def_s])
	if objetivos.is_empty():
		return
	objetivos.sort_custom(func(a, b): return a[0] > b[0])
	if objetivos.size() > MAX_OBJETIVOS:
		objetivos.resize(MAX_OBJETIVOS)
	st["base"] = int(mundo.provincias[int(objetivos[0][2])].tid)  # ahí recluta
	# regimientos libres (con su posición, para no pedirla una y otra vez)
	var l_rid := PackedInt32Array()
	var l_sold := PackedInt32Array()
	var l_x := PackedFloat32Array()
	var l_y := PackedFloat32Array()
	var centros: PackedVector2Array = ej.red.centros
	for rid in ej.regs_pais.get(tid, []):
		if ej.en_marcha_reg(int(rid)):
			continue
		var pr = ej.provincia_por_tid(ej.prov_de(int(rid)))
		if pr == null:
			continue
		var c: Vector2 = centros[int(pr.idx)]
		l_rid.append(int(rid))
		l_sold.append(ej.soldados_reg(int(rid)))
		l_x.append(c.x)
		l_y.append(c.y)
	var nl := l_rid.size()
	if nl == 0:
		return
	var usados := PackedByteArray()
	usados.resize(nl)
	var n_usados := 0
	var ordenes := 0
	var r2 := RADIO_ATAQUE * RADIO_ATAQUE
	for ob in objetivos:
		if ordenes >= MAX_ORDENES or n_usados >= nl:
			break
		var pb2: int = ob[1]
		var def2: int = ob[3]
		var cp: Vector2 = centros[pb2]
		var cand := []                                           # [distancia², índice]
		for i in nl:
			if usados[i] == 1:
				continue
			var dx: float = fposmod(cp.x - l_x[i] + 1200.0, 2400.0) - 1200.0
			var dy: float = cp.y - l_y[i]
			var d2: float = dx * dx + dy * dy
			if d2 <= r2:
				cand.append([d2, i])
		if cand.is_empty():
			continue
		cand.sort_custom(func(a, b): return a[0] < b[0])
		var fuerza := 0
		var elegidos := []
		var necesita: float = RATIO_ATAQUE * float(def2)
		for c2 in cand:
			elegidos.append(int(c2[1]))
			fuerza += l_sold[int(c2[1])]
			if float(fuerza) >= necesita and fuerza > 0:
				break
		if float(fuerza) < necesita or elegidos.is_empty():
			continue                                             # no le alcanza con lo que tiene cerca: espera a juntar más (recluta en la base)
		var por_enviar: float = maxf(necesita * ENVIO_MARGEN, float(ENVIO_MIN))   # manda lo necesario, no todo: el resto de un regimiento grande se queda de reserva
		for i2 in elegidos:
			if ordenes >= MAX_ORDENES or por_enviar <= 0.0:
				break
			var disp: int = l_sold[i2]
			var toma: int = mini(disp, int(ceilf(por_enviar)))
			var n_envio: int = 0 if toma >= disp - LOTE_MIN else toma          # 0 = el regimiento entero
			var t_r := Time.get_ticks_usec()
			var res: Dictionary = ej.ordenar_marcha_reg(l_rid[i2], n_envio, pb2)
			_p("marcha", t_r)
			if bool(res.get("ok", false)):
				var enviados: int = disp if n_envio == 0 else n_envio
				l_sold[i2] = disp - enviados
				if l_sold[i2] < LOTE_MIN:
					usados[i2] = 1
					n_usados += 1
				por_enviar -= float(enviados)
				ordenes += 1
				n_rutas += 1
	st["n_ordenes"] = ordenes
	if ordenes > 0:
		st["ultimo"] = "Mandó %d regimientos al frente." % ordenes


# ─────────────────────────────────────────────────────────────
# 4. Paz
# ─────────────────────────────────────────────────────────────
func _paz(nombre: String, st: Dictionary, tid: int, rivales: Array) -> void:
	for r in rivales:
		var rid: int = int(r)
		var nom_r: String = mundo.bd.nombre_de(rid)
		var s: float = g.puntaje_guerra(tid, rid)
		var dur: int = dia_n - int(st["ini"].get(rid, dia_n))
		var t := {}
		var quiere := false
		var razon := ""
		if s >= PAZ_GANADA:
			t = {"posesion": true, "indemnizacion": s >= PAZ_INDEMNIZACION}
			quiere = true
			razon = "victoria"
		elif dur >= PAZ_LARGA_DIAS and s >= 0.04:
			t = {"posesion": true}
			quiere = true
			razon = "ventaja"
		elif dur >= PAZ_TABLAS_DIAS and absf(s) < 0.04:
			quiere = true                                         # tablas: paz blanca
			razon = "tablas"
		elif s <= PAZ_CAPITULA:
			t = {"posesion": true}                                # se rinde: cada uno se queda con lo que ocupa
			quiere = true
			razon = "capitula"
		elif dur >= 3 * PAZ_TABLAS_DIAS:
			t = {"posesion": true} if s > 0.0 else {}
			quiere = true
			razon = "agotamiento"
		if not quiere:
			continue
		if nom_r == mundo.jugador:
			# 0.1.8.2a: al jugador la paz no se le impone: se le abre un pop-up con el motivo y él negocia (provincias y dinero)
			var hasta: int = int(st["aviso_paz"].get(rid, -1))
			if dia_n >= hasta and not _aviso_paz_pendiente(tid, rid):
				st["aviso_paz"][rid] = dia_n + AVISO_PAZ_DIAS
				mundo.avisos.append({"tipo": "paz", "ia": tid, "jugador": rid, "razon": razon, "puntaje_ia": s, "duracion": dur, "fecha": mundo.bd.fecha})
			continue
		var res: Dictionary = g.proponer_paz(tid, rid, t)
		if bool(res.get("ok", false)):
			st["ultimo"] = "Firmó la paz con %s." % nom_r
			st["no_guerra_hasta"] = dia_n + 30


func _aviso_paz_pendiente(tid: int, rid: int) -> bool:
	for a in mundo.avisos:
		if String(a.get("tipo", "")) == "paz" and int(a.get("ia", -1)) == tid and int(a.get("jugador", -1)) == rid:
			return true
	return false


# ─────────────────────────────────────────────────────────────
# Información para la interfaz
# ─────────────────────────────────────────────────────────────
func texto_estado(pais: String) -> String:
	if not activas.has(pais):
		return "Sin IA."
	var st: Dictionary = activas[pais]
	var tid: int = int(st["tid"])
	var rivales := []
	for r in g.rivales_de(tid):
		rivales.append(mundo.bd.nombre_de(int(r)))
	var t := "IA activa · " + ("en guerra con " + ", ".join(rivales) if not rivales.is_empty() else "en paz")
	return t + "\n" + String(st["ultimo"])
