extends RefCounted
## Guerras y batallas (0.1.7.9.9F-c). Base de la RIVALIDAD entre países.
##
## Todo vive en la BASE DE DATOS PRINCIPAL; este archivo solo tiene las REGLAS:
##   · GUERRA  (tipo `guerra`, IDs desde 13.000.000, padre = país agresor): variables agresor, defensor, guerra_inicio, guerra_fin
##     (0 = sigue abierta), guerra_causa. Cada país cuenta sus guerras abiertas en `guerras_activas`.
##   · BATALLA (tipo `batalla`, IDs desde 14.000.000, padre = su guerra): un combate en una provincia entre dos países en guerra.
##     Variables bat_provincia, bat_guerra, bat_atacante, bat_defensor, bat_inicio, bat_fin, bat_dias, bat_ini_atac, bat_ini_def,
##     bat_bajas_atac, bat_bajas_def, bat_ganador, bat_resultado. `bat_dias`, `bat_bajas_*` y `bat_fin` tienen historial POR CAMBIO:
##     cada día de combate deja una fila → ese es el HISTORIAL DE ESTADÍSTICAS DE BATALLA.
##
## Cuándo empieza una guerra: cuando un país ORDENA una marcha a una provincia que es de otro país (Ejercito.ordenar_marcha_reg
## llama a `declarar`). Entrar es atacar. Los aliados y vasallos (Mundo.relacionados_de) quedan fuera.
## Cuándo empieza una batalla: cuando regimientos de dos países EN GUERRA coinciden quietos en una provincia (al llegar uno, o al
## declararse la guerra con ambos ya allí). Se pelea un round por día hasta que uno de los dos deja de tener tropas allí.
##
## REGLAS PROVISIONALES (se ajustan con pruebas de juego): poder = soldados × calidad (experiencia, forma física y familiaridad) ×
## 1,2 si juegan en su propia provincia; cada día cada bando pierde RITMO_BAJAS × 2 × (poder del rival ÷ poder total) de sus soldados
## (± ruido).
##
## 0.1.8.1 — RETIRADA, OCUPACIÓN Y PAZ CON CONDICIONES:
##   · RETIRADA: el bando que baja de RETIRADA_FRAC (35 %) de su fuerza inicial en la batalla y está peor que el rival se retira hacia el
##     refugio más cercano de su país (Ejercito.refugio_de). Si no tiene refugio, pelea hasta el final.
##   · OCUPACIÓN: tropas quietas de un país en una provincia cuyo controlador está en guerra con él, sin tropas enemigas, la ocupan tras
##     DIAS_OCUPACION días seguidos. El dueño NO cambia (variable `propietario`): se anota quién la ocupa en la variable `ocupante`. Una
##     provincia ocupada no rinde ingresos a su dueño. Si el dueño vuelve con tropas y se queda unos días, la libera.
##   · PAZ: «blanca» (cada ocupación se anula y las provincias vuelven a su dueño) o «posesión» (cada uno se queda con lo que ocupa: las
##     provincias cambian de dueño de verdad), con o sin indemnización. El rival acepta según el PUNTAJE DE GUERRA: la fracción de la
##     producción del rival que ocupas menos la que el rival ocupa de la tuya (ver `evaluar_paz`).

const PerfilScript := preload("res://scripts/perfil.gd")
const BDScript := preload("res://scripts/base_datos.gd")

const BASE_GUERRA := 13000000
const BASE_BATALLA := 14000000
const RITMO_BAJAS := 0.08               # fracción de los soldados que pierde cada bando al día en un combate parejo
const BONO_LOCAL := 1.2                 # el que pelea en una provincia de su propio país
const RUIDO := 0.15                     # variación diaria al azar de las bajas (±15 %)
const DIAS_OCUPACION := 3               # días seguidos con tropas solas en una provincia enemiga para ocuparla (o liberarla)
const RETIRADA_FRAC := 0.35             # el bando que queda por debajo de esta fracción de su fuerza inicial (y peor que el rival) se retira
const MARGEN_PAZ := 0.02                # tolerancia del rival al comparar lo que pides con el puntaje de guerra
const PESO_INDEMNIZACION := 0.10        # cuánto «vale» cobrar una indemnización en la misma escala que el puntaje (fracción de producción)
const DIAS_INDEMNIZACION := 90.0        # el perdedor paga hasta 90 días de sus ingresos (nunca más de lo que tiene en caja)
const ANIOS_VALOR_PROVINCIA := 3.0      # 0.1.8.2a: al negociar un tratado, una provincia «vale» lo que produce en 3 años
const FACTOR_EXIGENCIA := 0.8           # lo que el vencedor exige por devolver lo ocupado, como fracción del valor de lo que ocupa
const SUBRONDA_DIAS := 4                # 0.1.8.3: un combate largo se parte en tramos de hasta 4 días (ver `_ronda`)
const LOTE_BATALLAS := 5                # rondas de combate por llamada de `fase_batallas`
const CORTE_BATALLAS_US := 5000         # 0.1.8.32: una llamada de `fase_batallas` se corta (entre sub-rondas) al pasar de 5 ms
const DIAS_ESCANEO := 7                 # cada cuántos días corre la red de seguridad de ocupaciones

var mundo
var bd
var ej                                   # Ejercito
var siguiente_guerra := BASE_GUERRA
var siguiente_batalla := BASE_BATALLA
var activas := {}                        # "menor|mayor" (IDs de país) -> ID de guerra abierta
var batallas_activas := {}               # "provincia|menor|mayor" -> ID de batalla en curso
var guerras := []                        # todas las guerras (abiertas y cerradas), en orden de creación
var batallas := []                       # todas las batallas, en orden de creación
var _dias_escaneo := 0                  # días acumulados desde el último escaneo de ocupaciones
var ocup_prog := {}                      # ID de provincia -> {"por": ID de país, "dias": n}: ocupaciones o liberaciones en marcha
var version := 0                         # sube con cualquier cambio (la interfaz la usa para redibujar)
var _rng := RandomNumberGenerator.new()
var prof := {}                           # sección -> [microsegundos totales, llamadas] (Debug > Rend.)
var _bat_cola: Array = []                # claves de las batallas que aún combaten en el paso en curso
var _bat_lista := false                  # ¿hay un paso a medias? (la cola ya se armó)
var _bat_curso = null                    # clave de la batalla que está combatiendo ahora (null = ninguna): puede quedar a medias entre dos llamadas
var _bat_resto := 0                      # días de combate que le faltan a `_bat_curso` en este paso
var _cache_part := {}                    # "por|de" -> [versión de la economía, fracción ocupada] (ver `participacion_ocupada`)


func iniciar(m) -> void:
	mundo = m
	bd = m.bd
	ej = m.ejercito
	_rng.seed = 20260102


static func clave_par(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]


func _clave_bat(prov: int, a: int, b: int) -> String:
	return "%d|%d|%d" % [prov, mini(a, b), maxi(a, b)]


func en_guerra(a: int, b: int) -> bool:
	return activas.has(clave_par(a, b))


func guerra_entre(a: int, b: int) -> int:
	return int(activas.get(clave_par(a, b), -1))


## IDs de las guerras abiertas de un país.
func guerras_de(pais_tid: int) -> Array:
	var r := []
	for k in activas:
		var gid: int = int(activas[k])
		if int(bd.ref("agresor", gid)) == pais_tid or int(bd.ref("defensor", gid)) == pais_tid:
			r.append(gid)
	return r


## IDs de los países con los que `pais_tid` está en guerra ahora (sus rivales).
func rivales_de(pais_tid: int) -> Array:
	var r := []
	for gid in guerras_de(pais_tid):
		var a: int = int(bd.ref("agresor", int(gid)))
		var d: int = int(bd.ref("defensor", int(gid)))
		r.append(d if a == pais_tid else a)
	return r


func _sumar_guerras(pais: int, d: int) -> void:
	var cur: float = bd.num("guerras_activas", pais, 0.0)
	bd.poner_f("guerras_activas", pais, maxf(0.0, cur + float(d)), "Guerra")


## `agresor` declara la guerra a `defensor`. Si ya hay una abierta entre ambos devuelve esa. Devuelve el ID de la guerra (-1 si no se pudo).
func declarar(agresor: int, defensor: int, causa := "Ataque a una provincia") -> int:
	if agresor == defensor or agresor < 0 or defensor < 0:
		return -1
	var k := clave_par(agresor, defensor)
	if activas.has(k):
		return int(activas[k])
	var gid := siguiente_guerra
	siguiente_guerra += 1
	var nom := "Guerra %s – %s" % [bd.nombre_de(agresor), bd.nombre_de(defensor)]
	bd.anadir_territorios([[gid, BDScript.T_GUERRA, nom, agresor, "g%d" % gid, 1]])
	bd.inicial_i("agresor", gid, agresor)
	bd.inicial_i("defensor", gid, defensor)
	bd.inicial_f("guerra_inicio", gid, float(bd.fecha))
	bd.inicial_f("guerra_fin", gid, 0.0)
	bd.inicial_s("guerra_causa", gid, causa)
	activas[k] = gid
	guerras.append(gid)
	_sumar_guerras(agresor, 1)
	_sumar_guerras(defensor, 1)
	version += 1
	_avisar_jugador(agresor, defensor, gid, causa)
	_revisar_pareja(agresor, defensor)
	return gid


## 0.1.8.2a: si le declaran la guerra al jugador, se encola un aviso (la interfaz abre un pop-up y pausa el tiempo).
func _avisar_jugador(agresor: int, defensor: int, gid: int, causa: String) -> void:
	var jug: String = mundo.jugador
	if jug == "" or not mundo.paises.has(jug) or defensor != int(mundo.paises[jug].tid) or agresor == defensor:
		return
	mundo.avisos.append({"tipo": "guerra", "agresor": agresor, "defensor": defensor, "gid": gid, "causa": causa, "fecha": bd.fecha})


## Fin de la guerra entre dos países SIN condiciones (paz blanca, sin preguntar al rival): las ocupaciones se anulan y las batallas
## en curso terminan «por paz». Es lo que usan las pruebas y el Debug; el juego usa `proponer_paz`.
func paz(a: int, b: int, motivo := "Paz") -> bool:
	return bool(firmar_paz(a, b, {}, motivo).get("ok", false))


# ─────────────────────────────────────────────────────────────
# Batallas
# ─────────────────────────────────────────────────────────────
## IDs de los pelotones QUIETOS de `pais` en la provincia `prov`.
func pelotones_en(prov: int, pais: int) -> Array:
	var r := []
	for rid in ej.regs_prov.get(prov, []):
		if ej.pais_de_reg(int(rid)) == pais:
			r.append_array(ej.pel_de_reg.get(rid, []))
	return r


func _soldados(lista: Array) -> int:
	var t := 0
	for id in lista:
		t += ej.soldados_de(int(id))
	return t


## Poder de combate de un grupo de pelotones (provisional): soldados × calidad × bono de local.
func _poder(lista: Array, pais: int, prov: int) -> float:
	var t := 0.0
	for id in lista:
		var s := float(ej.soldados_de(int(id)))
		var q: float = (0.6 + 0.004 * bd.num("experiencia", int(id))) * (0.7 + 0.003 * bd.num("forma_fisica", int(id))) * (0.8 + 0.002 * bd.num("familiaridad", int(id)))
		t += s * q
	var pr = ej.provincia_por_tid(prov)
	if pr != null and ej.dueno_de_provincia(int(pr.idx)) == pais:
		t *= BONO_LOCAL
	return t


## Provincias donde hoy coinciden tropas de los dos países: empieza la batalla (el agresor de la guerra es el atacante).
func _revisar_pareja(a: int, b: int) -> void:
	var gid := guerra_entre(a, b)
	if gid < 0:
		return
	var atac: int = int(bd.ref("agresor", gid))
	var def_ := b if atac == a else a
	for prov in ej.regs_prov.keys():
		if _clave_bat(int(prov), a, b) in batallas_activas:
			continue
		var hay_a := false
		var hay_b := false
		for rid in ej.regs_prov[prov]:
			var p: int = ej.pais_de_reg(int(rid))
			hay_a = hay_a or p == a
			hay_b = hay_b or p == b
		if hay_a and hay_b:
			_iniciar_batalla(int(prov), atac, def_, gid)
		elif hay_a or hay_b:
			_revisar_ocupacion(int(prov), a if hay_a else b)       # tropas de uno ya dentro de una provincia del otro


## Revisa una provincia donde acaba de llegar una columna de `pais_llegado`.
func _revisar_prov(prov: int, pais_llegado: int) -> void:
	var presentes := {}
	for rid in ej.regs_prov.get(prov, []):
		presentes[ej.pais_de_reg(int(rid))] = true
	if not presentes.has(pais_llegado):
		return
	for otro in presentes:
		if int(otro) == pais_llegado:
			continue
		var gid := guerra_entre(pais_llegado, int(otro))
		if gid >= 0 and not (_clave_bat(prov, pais_llegado, int(otro)) in batallas_activas):
			_iniciar_batalla(prov, pais_llegado, int(otro), gid)


func _iniciar_batalla(prov: int, atac: int, def_: int, gid: int) -> int:
	var bid := siguiente_batalla
	siguiente_batalla += 1
	var pr = ej.provincia_por_tid(prov)
	var nom_prov: String = pr.nombre if pr != null else str(prov)
	bd.anadir_territorios([[bid, BDScript.T_BATALLA, "Batalla de " + nom_prov, gid, "b%d" % bid, 1]])
	bd.inicial_i("bat_provincia", bid, prov)
	bd.inicial_i("bat_guerra", bid, gid)
	bd.inicial_i("bat_atacante", bid, atac)
	bd.inicial_i("bat_defensor", bid, def_)
	bd.inicial_f("bat_inicio", bid, float(bd.fecha))
	bd.inicial_f("bat_fin", bid, 0.0)
	bd.inicial_f("bat_dias", bid, 0.0)
	bd.inicial_f("bat_ini_atac", bid, float(_soldados(pelotones_en(prov, atac))))
	bd.inicial_f("bat_ini_def", bid, float(_soldados(pelotones_en(prov, def_))))
	bd.inicial_f("bat_bajas_atac", bid, 0.0)
	bd.inicial_f("bat_bajas_def", bid, 0.0)
	bd.inicial_i("bat_ganador", bid, -1)
	bd.inicial_s("bat_resultado", bid, "")
	batallas_activas[_clave_bat(prov, atac, def_)] = bid
	batallas.append(bid)
	version += 1
	return bid


## Pierde `frac` de los soldados de cada pelotón (mínimo 1 por pelotón). Devuelve las bajas totales.
func _aplicar(lista: Array, frac: float, motivo: String) -> int:
	var total := 0
	for id in lista.duplicate():
		var s: int = ej.soldados_de(int(id))
		if s <= 0:
			continue
		var b := clampi(int(ceilf(float(s) * frac)), 1, s)
		total += ej.aplicar_bajas(int(id), b, motivo)
	return total


## `dias` días de combate en la batalla `bid` (0.1.8.3): se parten en sub-rondas de hasta SUBRONDA_DIAS días, para que un paso largo (x6) no deje
## pelear 31 días con las fuerzas del primero: tras cada sub-ronda se recalculan los poderes y se revisa la retirada. Cuesta ~dias/4 rondas, no `dias`.
func _ronda(bid: int, dias := 1) -> void:
	var restante := dias
	while restante > 0:
		var d := mini(restante, SUBRONDA_DIAS)
		restante -= d
		if _sub_ronda(bid, d):
			return                                                    # la batalla terminó (aniquilación o retirada)


## Un tramo de `dias` días (≤ SUBRONDA_DIAS) de combate. Devuelve true si la batalla terminó.
func _sub_ronda(bid: int, dias: int) -> bool:
	var prov: int = int(bd.ref("bat_provincia", bid))
	var a: int = int(bd.ref("bat_atacante", bid))
	var d: int = int(bd.ref("bat_defensor", bid))
	var t_r := Time.get_ticks_usec()
	var pa := pelotones_en(prov, a)
	var pd := pelotones_en(prov, d)
	_p("ronda.pelotones", t_r)
	if pa.is_empty() or pd.is_empty():
		t_r = Time.get_ticks_usec()
		_terminar(bid, "")
		_p("terminar", t_r)
		return true
	t_r = Time.get_ticks_usec()
	var fa := _poder(pa, a, prov)
	var fd := _poder(pd, d, prov)
	_p("ronda.poder", t_r)
	var perdidas := _fraccion_de_bajas(fa, fd, dias)
	var la: float = perdidas[0]
	var ld: float = perdidas[1]
	var motivo: String = bd.nombre_de(bid)
	t_r = Time.get_ticks_usec()
	var ba := _aplicar(pa, la, motivo)
	var bdd := _aplicar(pd, ld, motivo)
	_p("ronda.aplicar", t_r)
	bd.poner_f("bat_dias", bid, bd.num("bat_dias", bid) + float(dias), motivo)
	bd.poner_f("bat_bajas_atac", bid, bd.num("bat_bajas_atac", bid) + float(ba), motivo)
	bd.poner_f("bat_bajas_def", bid, bd.num("bat_bajas_def", bid) + float(bdd), motivo)
	version += 1
	var pa2 := pelotones_en(prov, a)
	var pd2 := pelotones_en(prov, d)
	if pa2.is_empty() or pd2.is_empty():
		t_r = Time.get_ticks_usec()
		_terminar(bid, "")
		_p("terminar", t_r)
		return true
	var quien := _quien_se_retira(bid, pa2, pd2)
	if quien >= 0:
		t_r = Time.get_ticks_usec()
		var fuera := _retirar(prov, quien)
		_p("retirar", t_r)
		if fuera:
			t_r = Time.get_ticks_usec()
			_terminar(bid, "retirada")
			_p("terminar", t_r)
			return true
	return false


## Fracción de sus soldados que pierden ([atacante, defensor]) en `dias` días de combate entre fuerzas `fa` y `fd`:
## cada bando pierde en proporción a la fuerza del otro, con un ruido al azar (consume 2 números del `_rng`, siempre en este orden).
func _fraccion_de_bajas(fa: float, fd: float, dias: int) -> Array:
	var tot := maxf(fa + fd, 1.0)
	var la := clampf(RITMO_BAJAS * 2.0 * fd / tot * _rng.randf_range(1.0 - RUIDO, 1.0 + RUIDO), 0.0, 0.6)
	var ld := clampf(RITMO_BAJAS * 2.0 * fa / tot * _rng.randf_range(1.0 - RUIDO, 1.0 + RUIDO), 0.0, 0.6)
	if dias > 1:                                                      # varios días seguidos: pierde (1 − (1 − l)^días) de lo que tiene
		la = 1.0 - pow(1.0 - la, float(dias))
		ld = 1.0 - pow(1.0 - ld, float(dias))
	return [la, ld]                                                   # (un Array y no un Vector2: éste guarda decimales de 32 bits y cambiaría los resultados)


## Retirada: el bando que ha perdido casi todo (y está peor que el rival) sale hacia su refugio más cercano.
## Devuelve el ID del país que se retira, o -1 si ninguno. `pa2`/`pd2`: pelotones que quedan del atacante y del defensor.
func _quien_se_retira(bid: int, pa2: Array, pd2: Array) -> int:
	var fa_rest := float(_soldados(pa2)) / maxf(bd.num("bat_ini_atac", bid), 1.0)
	var fd_rest := float(_soldados(pd2)) / maxf(bd.num("bat_ini_def", bid), 1.0)
	if fa_rest < RETIRADA_FRAC and fa_rest <= fd_rest:
		return int(bd.ref("bat_atacante", bid))
	if fd_rest < RETIRADA_FRAC:
		return int(bd.ref("bat_defensor", bid))
	return -1


## Manda a retirarse a todos los regimientos quietos de `pais` en la provincia. Devuelve true si ya no queda ninguno allí.
func _retirar(prov: int, pais: int) -> bool:
	for rid in ej.regs_prov.get(prov, []).duplicate():
		if ej.pais_de_reg(int(rid)) == pais:
			ej.retirar_reg(int(rid))
	return pelotones_en(prov, pais).is_empty()


## Cierra una batalla. `resultado` vacío = se decide según quién quedó en la provincia.
func _terminar(bid: int, resultado: String) -> void:
	var prov: int = int(bd.ref("bat_provincia", bid))
	var a: int = int(bd.ref("bat_atacante", bid))
	var d: int = int(bd.ref("bat_defensor", bid))
	var hay_a := not pelotones_en(prov, a).is_empty()
	var hay_d := not pelotones_en(prov, d).is_empty()
	var ganador := -1
	var res := resultado
	if res != "paz":
		if hay_a and not hay_d:
			ganador = a
		elif hay_d and not hay_a:
			ganador = d
		var perdedor_ini: float = bd.num("bat_ini_def", bid) if ganador == a else bd.num("bat_ini_atac", bid)
		var perdedor_baj: float = bd.num("bat_bajas_def", bid) if ganador == a else bd.num("bat_bajas_atac", bid)
		if res == "":
			if ganador == -1:
				res = "aniquilación mutua"
			elif perdedor_baj >= 0.95 * perdedor_ini:
				res = "aniquilación"
			else:
				res = "retirada"
	var motivo := "Fin de la batalla"
	bd.poner_f("bat_fin", bid, float(bd.fecha), motivo)
	bd.poner_i("bat_ganador", bid, ganador, motivo)
	bd.poner_s("bat_resultado", bid, res, motivo)
	batallas_activas.erase(_clave_bat(prov, a, d))
	version += 1
	if ganador >= 0:
		_revisar_ocupacion(prov, ganador)                    # el que se quedó solo en la provincia empieza a ocuparla


## Anota en `prof` el tiempo de una sección (ver perfil.gd).
func _p(sec: String, t0: int) -> void:
	PerfilScript.anotar(prof, sec, t0)


## Un paso de juego de `k` días, de golpe (lo llama Mundo.avanzar_dia después de que las columnas avanzan).
func avanzar_dia(k := 1) -> void:
	fase_llegadas()
	while fase_batallas(k):
		pass
	fase_ocupaciones(k)


## 0.1.8.2a: el día de guerra en tres fases (el juego las reparte entre fotogramas; `avanzar_dia` las corre de golpe).
func fase_llegadas() -> bool:
	if ej == null:
		return false
	if activas.is_empty():
		ej.llegadas.clear()
		return false
	var lleg: Array = ej.llegadas
	ej.llegadas = []
	var t0 := Time.get_ticks_usec()
	for l in lleg:
		_revisar_prov(int(l[0]), int(l[1]))
		_revisar_ocupacion(int(l[0]), int(l[1]))
	_p("llegadas", t0)
	return false


## Rondas de las batallas activas, en lotes. Devuelve true mientras queden batallas (o días de combate) por resolver hoy.
## 0.1.8.3: cada batalla combate `k` días en este paso (en sub-rondas de hasta SUBRONDA_DIAS días: ver `_ronda`).
## 0.1.8.32: una batalla grande (cientos de pelotones) tardaba 30-60 ms en sus sub-rondas de un paso largo. Ahora la llamada se corta entre sub-rondas
## cuando lleva más de CORTE_BATALLAS_US y la batalla sigue en la llamada siguiente (`_bat_curso`, `_bat_resto`). El orden de combate no cambia
## (una batalla termina antes de empezar la siguiente): solo cambia dónde se parte el trabajo entre fotogramas.
func fase_batallas(k := 1) -> bool:
	if ej == null or activas.is_empty():
		_bat_lista = false
		_bat_curso = null
		return false
	if not _bat_lista:
		_bat_cola = batallas_activas.keys()
		_bat_lista = true
		_bat_curso = null
	var t0 := Time.get_ticks_usec()
	var n := 0
	var lote := maxi(1, LOTE_BATALLAS / maxi(1, (k + SUBRONDA_DIAS - 1) / SUBRONDA_DIAS))     # un paso largo cuesta más por batalla: menos batallas por llamada
	while n < lote and (_bat_curso != null or not _bat_cola.is_empty()):
		if _bat_curso == null:
			var kb = _bat_cola.pop_front()
			n += 1
			if not batallas_activas.has(kb):                    # una batalla anterior pudo cerrar a esta (retirada)
				continue
			_bat_curso = kb
			_bat_resto = k
		elif not batallas_activas.has(_bat_curso):              # la batalla a medias se cerró entre llamadas (paz, aniquilación)
			_bat_curso = null
			continue
		var d := mini(_bat_resto, SUBRONDA_DIAS)
		_bat_resto -= d
		if _sub_ronda(int(batallas_activas[_bat_curso]), d) or _bat_resto <= 0:
			_bat_curso = null
		if Time.get_ticks_usec() - t0 > CORTE_BATALLAS_US:
			break                                               # ya se gastó lo que cabe en esta llamada: sigue en la próxima
	_p("batallas", t0)
	if _bat_cola.is_empty() and _bat_curso == null:
		_bat_lista = false
		return false
	return true


func fase_ocupaciones(k := 1) -> bool:
	if ej == null or activas.is_empty():
		return false
	var t0 := Time.get_ticks_usec()
	_escanear_ocupaciones(k)
	_p("escaneo", t0)
	t0 = Time.get_ticks_usec()
	_avanzar_ocupaciones(k)
	_p("ocupaciones", t0)
	return false


# ─────────────────────────────────────────────────────────────
# Ocupación (0.1.8.1)
# ─────────────────────────────────────────────────────────────
## País que controla hoy la provincia (ID de territorio): el que la ocupa o, si nadie, su dueño. -1 si no hay.
func controlador_de(prov_tid: int) -> int:
	var oc: int = bd.ref("ocupante", prov_tid)
	if oc >= 0:
		return oc
	var pr = ej.provincia_por_tid(prov_tid)
	return ej.dueno_de_provincia(int(pr.idx)) if pr != null else -1


## ¿Puede `por` empezar (o seguir) ocupando esa provincia? Tiene tropas quietas allí, no hay tropas de países en guerra con él,
## quien la controla está en guerra con él y la provincia es del propio `por` (liberarla) o de alguien en guerra con él.
func _puede_ocupar(prov_tid: int, por: int) -> bool:
	var pr = ej.provincia_por_tid(prov_tid)
	if pr == null:
		return false
	var ctrl := controlador_de(prov_tid)
	if ctrl < 0 or ctrl == por or not en_guerra(por, ctrl):
		return false
	var dueno: int = ej.dueno_de_provincia(int(pr.idx))
	if dueno != por and not en_guerra(por, dueno):
		return false
	var propios := false
	for rid in ej.regs_prov.get(prov_tid, []):
		var p: int = ej.pais_de_reg(int(rid))
		if p == por:
			propios = true
		elif en_guerra(por, p):
			return false
	return propios


func _revisar_ocupacion(prov_tid: int, por: int) -> void:
	if ocup_prog.has(prov_tid) and int(ocup_prog[prov_tid]["por"]) == por:
		return
	if _puede_ocupar(prov_tid, por):
		ocup_prog[prov_tid] = {"por": por, "dias": 0}
		version += 1


## Red de seguridad (cada 7 días): tropas quietas que por algún camino no pasaron por «llegadas» (Debug, cambios de dueño...) también
## empiezan a ocupar/liberar. Solo mira los regimientos de países EN GUERRA y descarta rápido las provincias que ya controla su país.
func _escanear_ocupaciones(k := 1) -> void:
	_dias_escaneo += k
	if _dias_escaneo < DIAS_ESCANEO:
		return
	_dias_escaneo = 0
	var en_g := {}
	for gid in activas.values():
		en_g[int(bd.ref("agresor", int(gid)))] = true
		en_g[int(bd.ref("defensor", int(gid)))] = true
	var col_prop: PackedInt32Array = bd.vars["propietario"].col_i
	var col_oc: PackedInt32Array = bd.vars["ocupante"].col_i
	for p in en_g:
		for rid in ej.regs_pais.get(p, []):
			if ej.en_marcha_reg(int(rid)):
				continue
			var prov: int = ej.prov_de(int(rid))
			var ix: int = bd.idx(prov)
			if ix < 0 or ocup_prog.has(prov):
				continue
			var ctrl: int = col_oc[ix] if col_oc[ix] >= 0 else col_prop[ix]
			if ctrl == int(p):
				continue
			if _puede_ocupar(prov, int(p)):
				ocup_prog[prov] = {"por": int(p), "dias": 0}
				version += 1


func _avanzar_ocupaciones(k := 1) -> void:
	for pt in ocup_prog.keys():
		var d: Dictionary = ocup_prog[pt]
		var por: int = int(d["por"])
		if not _puede_ocupar(int(pt), por):
			ocup_prog.erase(pt)
			version += 1
			continue
		d["dias"] = int(d["dias"]) + k
		if int(d["dias"]) >= DIAS_OCUPACION:
			ocup_prog.erase(pt)
			_ocupar(int(pt), por)


## `por` toma el control de la provincia (la ocupa, o la libera si era suya). El dueño NO cambia.
func _ocupar(prov_tid: int, por: int) -> void:
	var pr = ej.provincia_por_tid(prov_tid)
	if pr == null:
		return
	var dueno: int = ej.dueno_de_provincia(int(pr.idx))
	var nombre_prov: String = String(pr.nombre)
	if por == dueno:
		bd.poner_i("ocupante", prov_tid, -1, "Liberación")
		mundo.evento(por, "%s liberó %s de la ocupación enemiga." % [bd.nombre_de(por), nombre_prov], dueno)
	else:
		bd.poner_i("ocupante", prov_tid, por, "Ocupación")
		mundo.evento(por, "%s ocupó %s (de %s)." % [bd.nombre_de(por), nombre_prov, bd.nombre_de(dueno)], dueno)
	version += 1


## Índices de las provincias de `de` que ocupa `por`.
func provincias_ocupadas(por: int, de: int) -> Array:
	var r := []
	var nom: String = bd.nombre_de(de)
	if not mundo.paises.has(nom):
		return r
	for pi in mundo.paises[nom].provincias:
		if bd.ref("ocupante", mundo.provincias[int(pi)].tid) == por:
			r.append(int(pi))
	return r


## Fracción (0-1) de la producción de `de` que hoy ocupa `por`. Se guarda hasta que cambie la economía (la diplomacia la pide en cada refresco).
func participacion_ocupada(por: int, de: int) -> float:
	var clave: int = por * 1000003 + de
	var c = _cache_part.get(clave)
	if c != null and int(c[0]) == bd.version_eco:
		return float(c[1])
	var nom: String = bd.nombre_de(de)
	var r: float = 0.0
	if mundo.paises.has(nom):
		var d: Array = mundo.rendimiento_ocupado(nom, por)
		if float(d[0]) > 0.0:
			r = float(d[1]) / float(d[0])
		elif int(d[2]) > 0:
			r = float(d[3]) / float(d[2])
	_cache_part[clave] = [bd.version_eco, r]
	return r


## PUNTAJE DE GUERRA desde el punto de vista de `a` (−1 a 1): lo que `a` ocupa de `b` menos lo que `b` ocupa de `a`.
func puntaje_guerra(a: int, b: int) -> float:
	return participacion_ocupada(a, b) - participacion_ocupada(b, a)


# ─────────────────────────────────────────────────────────────
# Paz con condiciones (0.1.8.1)
# ─────────────────────────────────────────────────────────────
## `t` = lo que pide el que propone: {"posesion": bool (cada uno se queda con lo que ocupa; si no, todo vuelve a su dueño),
## "indemnizacion": bool (el rival le paga hasta 90 días de sus ingresos, sin pasar de lo que tiene en caja)}. {} = paz blanca.
##
## El RIVAL acepta si:
##   · «posesión»: siempre (se queda con lo que ya tiene);
##   · «blanca»: el puntaje de guerra de quien propone no es peor que −2 % (si el rival va ganando, no devuelve lo que ocupa);
##   · «indemnización»: el puntaje de quien propone es al menos 10 % − 2 % (tiene que haber ocupado bastante).
## Devuelve {"acepta", "motivo", "puntaje"}.
func evaluar_paz(proponente: int, otro: int, t: Dictionary) -> Dictionary:
	if not en_guerra(proponente, otro):
		return {"acepta": false, "motivo": "No están en guerra.", "puntaje": 0.0}
	var s := puntaje_guerra(proponente, otro)
	var nom: String = bd.nombre_de(otro)
	var posesion: bool = bool(t.get("posesion", false))
	var indem: bool = bool(t.get("indemnizacion", false))
	if not posesion and s < -MARGEN_PAZ:
		return {"acepta": false, "puntaje": s,
			"motivo": "%s va ganando la guerra y no devuelve lo que ocupa." % nom}
	if indem and PESO_INDEMNIZACION > maxf(s, 0.0) + MARGEN_PAZ:
		return {"acepta": false, "puntaje": s,
			"motivo": "%s no paga una indemnización: todavía no le has ocupado lo suficiente." % nom}
	return {"acepta": true, "motivo": "", "puntaje": s}


# ─────────────────────────────────────────────────────────────
# Tratado de paz del jugador (0.1.8.2a): solo dos monedas de cambio, PROVINCIAS y DINERO, combinables
# ─────────────────────────────────────────────────────────────
## Lo que «vale» una provincia al negociar (US$): ANIOS_VALOR_PROVINCIA años de lo que rinde.
func valor_provincia_usd(pi: int) -> float:
	if pi < 0 or pi >= mundo.provincias.size():
		return 0.0
	return ANIOS_VALOR_PROVINCIA * mundo.provincias[pi].rendimiento_usd()


## Lo que `b` exige a `a` para devolverle lo que le ocupa: (lo que va perdiendo `a` − margen) × valor de 3 años de su producción × FACTOR_EXIGENCIA.
## 0 si `a` no va perdiendo.
func exigencia_usd(a: int, b: int) -> float:
	var s := puntaje_guerra(a, b)
	if s >= -MARGEN_PAZ:
		return 0.0
	var tot: float = float(mundo.rendimiento_ocupado(bd.nombre_de(a), -2)[0])
	return (-s - MARGEN_PAZ) * ANIOS_VALOR_PROVINCIA * tot * FACTOR_EXIGENCIA


## Valor (US$) de lo que ofrece `a` en el tratado `t` = {"cede": [provincias], "paga_usd": dinero}.
func valor_oferta_usd(t: Dictionary) -> float:
	var v := float(t.get("paga_usd", 0.0))
	for pi in t.get("cede", []):
		v += valor_provincia_usd(int(pi))
	return v


## ¿Acepta `b` el tratado `t` de `a`? t = {"cede", "paga_usd", "conserva_a" (a se queda con lo que ocupa de b)}. Lo que b ocupa de a vuelve a `a` salvo lo cedido.
## Devuelve {"acepta", "exigido", "ofrecido", "puntaje", "motivo"}.
func evaluar_tratado(a: int, b: int, t: Dictionary) -> Dictionary:
	if not en_guerra(a, b):
		return {"acepta": false, "motivo": "No están en guerra.", "exigido": 0.0, "ofrecido": 0.0, "puntaje": 0.0}
	var s := puntaje_guerra(a, b)
	var exigido := exigencia_usd(a, b)
	if bool(t.get("conserva_a", false)):                              # dejarte lo que ocupas le cuesta lo que valen esas provincias… mientras él tenga algo que decir
		var vo := 0.0
		for pi in provincias_ocupadas(a, b):
			vo += valor_provincia_usd(int(pi))
		exigido += vo * clampf(1.0 - s / 0.2, 0.0, 1.0)
	var ofrecido := valor_oferta_usd(t)
	if ofrecido + 0.5 >= exigido:
		return {"acepta": true, "motivo": "", "exigido": exigido, "ofrecido": ofrecido, "puntaje": s}
	return {"acepta": false, "exigido": exigido, "ofrecido": ofrecido, "puntaje": s,
		"motivo": "%s no acepta: pide un valor de al menos %s y le ofreces %s." % [bd.nombre_de(b), _fmt_usd(exigido), _fmt_usd(ofrecido)]}


static func _fmt_usd(v: float) -> String:
	if v >= 1.0e9:
		return "US$ %.2f mil M" % (v / 1.0e9)
	if v >= 1.0e6:
		return "US$ %.1f M" % (v / 1.0e6)
	return "US$ %d" % int(v)


## Propone la paz: si el rival la acepta, se firma. Devuelve {"ok", "msg", ...lo que devuelve `firmar_paz`}.
func proponer_paz(proponente: int, otro: int, t: Dictionary) -> Dictionary:
	var ev := evaluar_paz(proponente, otro, t)
	if not bool(ev["acepta"]):
		return {"ok": false, "msg": "%s rechaza la paz. %s" % [bd.nombre_de(otro), String(ev["motivo"])]}
	return firmar_paz(proponente, otro, t, "Paz")


## Firma la paz (sin evaluar): cierra la guerra, termina las batallas, aplica las condiciones y saca a las tropas del territorio ajeno.
## Devuelve {"ok", "msg", "ganadas" (provincias para el que propone), "cedidas" (provincias que pierde), "indemnizacion" (en la moneda del que cobra)}.
func firmar_paz(a: int, b: int, t: Dictionary, motivo := "Paz") -> Dictionary:
	var k := clave_par(a, b)
	if not activas.has(k):
		return {"ok": false, "msg": "No hay una guerra abierta entre ellos."}
	var gid: int = int(activas[k])
	var posesion: bool = bool(t.get("posesion", false))
	var indem: bool = bool(t.get("indemnizacion", false))
	var quedan_a: bool = posesion or bool(t.get("conserva_a", false))      # 0.1.8.2a: cada bando puede quedarse con lo que ocupa por separado
	var quedan_b: bool = posesion or bool(t.get("conserva_b", false))
	var cede: Array = t.get("cede", [])                                    # provincias de `a` que pasan a `b` por el tratado
	var paga_usd: float = float(t.get("paga_usd", 0.0))                    # dinero (US$) que `a` le paga a `b`
	var na: String = bd.nombre_de(a)
	var nb: String = bd.nombre_de(b)
	for kb in batallas_activas.keys():
		var bid: int = int(batallas_activas[kb])
		if int(bd.ref("bat_guerra", bid)) == gid:
			_terminar(bid, "paz")
	for pt in ocup_prog.keys():                                       # las ocupaciones y liberaciones a medias entre ellos se cancelan
		var por: int = int(ocup_prog[pt]["por"])
		var ctrl := controlador_de(int(pt))
		if (por == a and ctrl == b) or (por == b and ctrl == a):
			ocup_prog.erase(pt)
	# indemnización: se calcula antes de mover provincias (con los ingresos de antes de la paz)
	var pago_local := 0.0
	var pago_usd := 0.0
	if indem and mundo.paises.has(nb) and mundo.paises.has(na):
		var eb = mundo.paises[nb]
		if eb.tiene_tesoreria() and eb.tesoreria > 0.0:
			var tope_usd: float = mundo.ingreso_diario_usd(nb) * DIAS_INDEMNIZACION
			var caja_usd: float = eb.tesoreria / mundo._por_usd(nb)
			pago_usd = minf(tope_usd, caja_usd)
			eb.tesoreria = eb.tesoreria - pago_usd * mundo._por_usd(nb)
			var ea = mundo.paises[na]
			if not ea.tiene_tesoreria():
				bd.inicial_f("tesoreria", ea.tid, 0.0)
			pago_local = pago_usd * mundo._por_usd(na)
			ea.tesoreria = ea.tesoreria + pago_local
	# dinero que `a` le paga a `b` (tratado): nunca más de lo que tiene en caja
	var pagado_usd := 0.0
	if paga_usd > 0.0 and mundo.paises.has(na) and mundo.paises.has(nb):
		var ea2 = mundo.paises[na]
		var eb2 = mundo.paises[nb]
		if ea2.tiene_tesoreria() and ea2.tesoreria > 0.0:
			pagado_usd = minf(paga_usd, ea2.tesoreria / mundo._por_usd(na))
			ea2.tesoreria = ea2.tesoreria - pagado_usd * mundo._por_usd(na)
			if not eb2.tiene_tesoreria():
				bd.inicial_f("tesoreria", eb2.tid, 0.0)
			eb2.tesoreria = eb2.tesoreria + pagado_usd * mundo._por_usd(nb)
	# provincias
	var oc_a: Array = provincias_ocupadas(a, b)                       # lo que a ocupa de b
	var oc_b: Array = provincias_ocupadas(b, a)
	var fecha_txt: String = BDScript.fecha_texto(bd.fecha)
	for pi in oc_a + oc_b:
		bd.poner_i("ocupante", mundo.provincias[int(pi)].tid, -1, "Fin de la ocupación (paz)")
	bd.poner_f("guerra_fin", gid, float(bd.fecha), motivo)
	activas.erase(k)
	_sumar_guerras(a, -1)
	_sumar_guerras(b, -1)
	var cedidas_tratado := 0
	for pi in cede:                                                   # las provincias que `a` entrega por el tratado
		if int(pi) >= 0 and int(pi) < mundo.provincias.size() and mundo.provincias[int(pi)].pais == na:
			if mundo.transferir_provincia(int(pi), nb, fecha_txt, "Tratado de paz con " + na):
				cedidas_tratado += 1
	if quedan_a:
		for pi in oc_a:
			mundo.transferir_provincia(int(pi), na, fecha_txt, "Paz con " + nb)
	if quedan_b:
		for pi in oc_b:
			if mundo.provincias[int(pi)].pais == na:                   # (las que ya se cedieron por el tratado no se repiten)
				mundo.transferir_provincia(int(pi), nb, fecha_txt, "Paz con " + na)
	_expulsar_tropas(a, b)
	_expulsar_tropas(b, a)
	version += 1
	var gan: int = oc_a.size() if quedan_a else 0
	var ced: int = (oc_b.size() if quedan_b else 0) + cedidas_tratado
	var msg := "Paz entre %s y %s." % [na, nb]
	if quedan_a or quedan_b or cedidas_tratado > 0:
		msg += " %s se queda con %d provincias; %s con %d." % [na, gan, nb, ced]
	else:
		msg += " Todo vuelve a su dueño."
	if pagado_usd > 0.0:
		msg += " %s paga a %s una compensación." % [na, nb]
	if pago_usd > 0.0:
		msg += " %s paga una indemnización." % nb
	mundo.evento(a, msg, b)
	if mundo.ia != null:
		mundo.ia.registrar_paz(a, b)                                  # tregua entre ellos (las IA no se vuelven a atacar enseguida)
	return {"ok": true, "msg": msg, "ganadas": gan, "cedidas": ced, "indemnizacion": pago_local, "pagado_usd": pagado_usd}


## Las tropas de `de` que quedaron dentro de provincias de `en` salen hacia su refugio (tras la paz no hay derecho a quedarse).
func _expulsar_tropas(de: int, en: int) -> void:
	for rid in ej.regs_pais.get(de, []).duplicate():
		if ej.en_marcha_reg(int(rid)):
			continue
		var pr = ej.provincia_por_tid(ej.prov_de(int(rid)))
		if pr != null and ej.dueno_de_provincia(int(pr.idx)) == en:
			ej.retirar_reg(int(rid))


# ─────────────────────────────────────────────────────────────
# Consultas para la interfaz
# ─────────────────────────────────────────────────────────────
func ficha_guerra(gid: int) -> Dictionary:
	if bd.idx(gid) < 0:
		return {}
	var a: int = int(bd.ref("agresor", gid))
	var d: int = int(bd.ref("defensor", gid))
	var fin: int = int(bd.num("guerra_fin", gid, 0.0))
	var n := 0
	var baj_a := 0
	var baj_d := 0
	for bid in batallas:
		if int(bd.ref("bat_guerra", int(bid))) == gid:
			n += 1
			baj_a += int(bd.num("bat_bajas_atac", int(bid)))
			baj_d += int(bd.num("bat_bajas_def", int(bid)))
	return {"id": gid, "nombre": bd.nombre_de(gid), "agresor": a, "defensor": d, "agresor_n": bd.nombre_de(a), "defensor_n": bd.nombre_de(d),
		"inicio": int(bd.num("guerra_inicio", gid)), "fin": fin, "activa": fin == 0, "causa": bd.txt("guerra_causa", gid),
		"batallas": n, "bajas_agresor": baj_a, "bajas_defensor": baj_d}


func ficha_batalla(bid: int) -> Dictionary:
	if bd.idx(bid) < 0:
		return {}
	var prov: int = int(bd.ref("bat_provincia", bid))
	var a: int = int(bd.ref("bat_atacante", bid))
	var d: int = int(bd.ref("bat_defensor", bid))
	var fin: int = int(bd.num("bat_fin", bid, 0.0))
	var pr = ej.provincia_por_tid(prov)
	var activa := fin == 0
	var rest_a := 0
	var rest_d := 0
	if activa:
		rest_a = _soldados(pelotones_en(prov, a))
		rest_d = _soldados(pelotones_en(prov, d))
	var g: int = int(bd.ref("bat_ganador", bid))
	return {"id": bid, "nombre": bd.nombre_de(bid), "provincia": pr.nombre if pr != null else "?", "prov_tid": prov,
		"guerra": int(bd.ref("bat_guerra", bid)), "atacante": a, "defensor": d, "atacante_n": bd.nombre_de(a), "defensor_n": bd.nombre_de(d),
		"inicio": int(bd.num("bat_inicio", bid)), "fin": fin, "activa": activa, "dias": int(bd.num("bat_dias", bid)),
		"ini_atac": int(bd.num("bat_ini_atac", bid)), "ini_def": int(bd.num("bat_ini_def", bid)),
		"bajas_atac": int(bd.num("bat_bajas_atac", bid)), "bajas_def": int(bd.num("bat_bajas_def", bid)),
		"rest_atac": rest_a, "rest_def": rest_d, "ganador": g, "ganador_n": bd.nombre_de(g) if g >= 0 else "",
		"resultado": bd.txt("bat_resultado", bid)}


## Bajas acumuladas día por día: [[fecha, bajas del atacante, bajas del defensor], ...] (sale del historial de la base).
func serie_bajas(bid: int, maximo := 400) -> Array:
	var ha: Array = bd.historial_de("bat_bajas_atac", bid, maximo)
	var hd: Array = bd.historial_de("bat_bajas_def", bid, maximo)
	var r := []
	for i in mini(ha.size(), hd.size()):
		r.append([int(ha[i]["desde"]), int(float(ha[i]["valor"])), int(float(hd[i]["valor"]))])
	return r


## Batallas en las que participó un país (más recientes primero).
func batallas_de(pais_tid: int) -> Array:
	var r := []
	for i in range(batallas.size() - 1, -1, -1):
		var bid: int = int(batallas[i])
		if int(bd.ref("bat_atacante", bid)) == pais_tid or int(bd.ref("bat_defensor", bid)) == pais_tid:
			r.append(bid)
	return r


## Guerras (abiertas y cerradas) de un país (más recientes primero).
func guerras_historial_de(pais_tid: int) -> Array:
	var r := []
	for i in range(guerras.size() - 1, -1, -1):
		var gid: int = int(guerras[i])
		if int(bd.ref("agresor", gid)) == pais_tid or int(bd.ref("defensor", gid)) == pais_tid:
			r.append(gid)
	return r


## Provincias con una batalla en curso en la que participa alguno de los países dados: {ID provincia: ID batalla}.
func provincias_en_combate(paises_tid: Array) -> Dictionary:
	var r := {}
	for k in batallas_activas:
		var bid: int = int(batallas_activas[k])
		var a: int = int(bd.ref("bat_atacante", bid))
		var d: int = int(bd.ref("bat_defensor", bid))
		if paises_tid.has(a) or paises_tid.has(d):
			r[int(bd.ref("bat_provincia", bid))] = bid
	return r
