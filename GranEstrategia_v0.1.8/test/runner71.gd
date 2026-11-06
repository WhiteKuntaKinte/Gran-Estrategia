extends Node
## 0.1.8.25 · PRUEBAS UNITARIAS de la lógica nueva o modificada desde la 0.1.8.2 (sin dibujar nada):
## Perfil.anotar · Reloj (sumar_dias, acumular, avanzar) · Mundo (ve_todo, rival_por_entrar, fases_dias, avanzar_dias) ·
## Ia (tregua_restante, _en_tregua, control_cambiado, _armar_cola, fase_dia, _frente_de) ·
## Guerra (_aplicar, _fraccion_de_bajas, _quien_se_retira, _sub_ronda, _ronda, fase_batallas, _escanear_ocupaciones) ·
## MapaPrincipal (texto_duracion, _tregua_dias, puede_ordenar_pais, puede_declarar_guerra, declarar_guerra_jugador, _aviso_sin_guerra,
## _fases_mes, _cierre_periodo, _medir_etiqueta, etiqueta_tramo) · Ejercito.ordenar_marcha_reg (regla de «entrar = atacar»).
const PerfilScript := preload("res://scripts/perfil.gd")
const RelojScript := preload("res://scripts/reloj.gd")
var main
var m
var g
var ia
var ej
var fallos := 0
var n_ok := 0


func _ready() -> void:
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	run.call_deferred()


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func ok(cond: bool, msg: String) -> void:
	if cond:
		n_ok += 1
		print("[T] OK    ", msg)
	else:
		fallos += 1
		print("[T] FALLO ", msg)


func cerca(a: float, b: float, tol := 1e-9) -> bool:
	return absf(a - b) <= tol


# ───────────────────────── 1. Perfil ─────────────────────────
func t_perfil() -> void:
	print("[T] ── Perfil.anotar")
	var tabla := {}
	var t0 := Time.get_ticks_usec()
	PerfilScript.anotar(tabla, "a", t0)
	ok(tabla.has("a") and int(tabla["a"][1]) == 1 and int(tabla["a"][0]) >= 0, "primera anotación: 1 llamada y tiempo ≥ 0")
	PerfilScript.anotar(tabla, "a", Time.get_ticks_usec() - 5000)
	ok(int(tabla["a"][1]) == 2 and int(tabla["a"][0]) >= 5000, "segunda anotación suma la llamada y los µs (≥ 5 ms)")
	PerfilScript.anotar(tabla, "b", Time.get_ticks_usec())
	ok(tabla.size() == 2 and int(tabla["b"][1]) == 1, "cada sección lleva su propia cuenta")
	var otra := {}
	PerfilScript.anotar(otra, "a", Time.get_ticks_usec())
	ok(int(otra["a"][1]) == 1 and int(tabla["a"][1]) == 2, "dos tablas no se mezclan (el valor por defecto no se comparte)")
	ok(ia.prof is Dictionary and g.prof is Dictionary and ej.prof is Dictionary, "IA, guerra y ejército llevan su propia tabla `prof`")


# ───────────────────────── 2. Reloj ─────────────────────────
var _cb_n := 0
var _cb_ultimo := []


func _cb(mes_nuevo: bool, anio_nuevo: bool, k: int) -> void:
	_cb_n += 1
	_cb_ultimo = [mes_nuevo, anio_nuevo, k]


func t_reloj() -> void:
	print("[T] ── Reloj")
	var r = RelojScript.new()
	r.al_dia = Callable(self, "_cb")
	r.fijar(2026, 1, 10)
	var n: int = r.sumar_dias(5)
	ok(n == 5 and r.texto() == "2026,01,15" and r.dias_totales == 5, "sumar_dias(5): avanza 5 días dentro del mes")
	ok(_cb_ultimo == [false, false, 5], "el aviso lleva (mes_nuevo=false, anio_nuevo=false, k=5)")
	r.fijar(2026, 1, 30)
	n = r.sumar_dias(5)
	ok(n == 2 and r.texto() == "2026,02,01", "nunca cruza el fin de mes: se queda en el día 1 del siguiente (avanzó %d)" % n)
	ok(_cb_ultimo == [true, false, 2], "…y avisa de mes nuevo UNA vez con k=2")
	r.fijar(2026, 12, 31)
	n = r.sumar_dias(10)
	ok(n == 1 and r.texto() == "2027,01,01" and _cb_ultimo == [true, true, 1], "31 de diciembre: año nuevo, mes nuevo, 1 día")
	r.fijar(2028, 2, 1)
	n = r.sumar_dias(31)
	ok(n == 29 and r.texto() == "2028,03,01", "febrero bisiesto: 29 días y no más (%d)" % n)
	r.fijar(2027, 2, 1)
	n = r.sumar_dias(31)
	ok(n == 28 and r.texto() == "2027,03,01", "febrero normal: 28 días")
	r.fijar(2026, 3, 1)
	n = r.sumar_dias(1000)
	ok(n == 31 and r.texto() == "2026,04,01", "k se acota a 31 (DIAS_MAX_PASO): marzo entero")
	r.fijar(2026, 3, 5)
	n = r.sumar_dias(0)
	ok(n == 1 and r.texto() == "2026,03,06", "k = 0 se sube a 1 (siempre avanza)")
	n = r.sumar_dias(-7)
	ok(n == 1 and r.texto() == "2026,03,07", "k negativo también avanza 1")
	r.fijar(2026, 4, 29)
	r.sumar_dia()
	ok(r.texto() == "2026,04,30", "sumar_dia() = sumar_dias(1)")
	# equivalencia: pasos de varios días == día por día
	var a = RelojScript.new()
	var b = RelojScript.new()
	a.fijar(2026, 1, 1)
	b.fijar(2026, 1, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var total := 0
	var meses_a := [0]                                   # (Array y no int: una lambda no modifica las variables sueltas de fuera)
	a.al_dia = func(mn: bool, _an: bool, _k: int): meses_a[0] += 1 if mn else 0
	var meses_b := [0]
	b.al_dia = func(mn: bool, _an: bool, _k: int): meses_b[0] += 1 if mn else 0
	while total < 1500:
		total += a.sumar_dias(rng.randi_range(1, 31))
	for _i in total:
		b.sumar_dia()
	ok(a.texto() == b.texto() and a.dias_totales == b.dias_totales and a.dias_totales == total, "%d días en pasos al azar = %d días sueltos (%s)" % [total, total, a.texto()])
	ok(meses_a[0] == meses_b[0] and meses_a[0] > 40, "el cambio de mes se avisa el mismo nº de veces (%d)" % meses_a[0])
	# acumular
	r = RelojScript.new()
	r.velocidad = 0
	r.acumular(5.0)
	ok(r.acum == 0.0, "acumular en pausa no hace nada")
	for v in range(1, RelojScript.VEL_MAX + 1):
		r.velocidad = v
		r.acum = 0.0
		r.acumular(100.0)
		var paso: float = RelojScript.SEG_POR_DIA[v]
		var tope: float = minf(maxf(2.0 * paso * float(RelojScript.DIAS_MIN_PASO[v]), 0.35), float(RelojScript.DIAS_DEUDA_MAX) * paso)
		ok(cerca(r.acum, minf(0.25, tope)), "velocidad %d: un fotograma enorme solo suma 0,25 s y respeta el tope de deuda (%.4f)" % [v, r.acum])
		r.acumular(100.0)
		r.acumular(100.0)
		ok(r.acum <= tope + 1e-9 and r.acum <= float(RelojScript.DIAS_DEUDA_MAX) * paso + 1e-9, "velocidad %d: la deuda nunca pasa de 62 días (%.1f días)" % [v, r.acum / paso])
	# avanzar
	r = RelojScript.new()
	r.fijar(2026, 1, 1)
	r.velocidad = 0
	ok(r.avanzar(1.0) == 0 and r.dias_totales == 0, "avanzar en pausa: 0 días")
	r.velocidad = 1
	ok(r.avanzar(0.25) == 0 and r.dias_totales == 0, "x1: 0,25 s no alcanzan para un día")
	var llamadas := 1
	var dias_x1 := 0
	while dias_x1 == 0 and llamadas < 10:                  # cada fotograma suma como mucho 0,25 s: hacen falta 4
		dias_x1 = r.avanzar(0.25)
		llamadas += 1
	ok(dias_x1 == 1 and llamadas == 4 and r.dias_totales == 1, "x1: al juntar 1 s (4 fotogramas de 0,25 s) pasa 1 día (%d fotogramas)" % llamadas)
	r.velocidad = 6
	r.acum = 0.0
	r.fijar(2026, 5, 1)
	var dm := [0]
	r.al_dia_diferido = func(_mn: bool, _an: bool, k: int): dm[0] += k
	var d6: int = r.avanzar(0.2)
	ok(d6 >= 20 and d6 <= RelojScript.DIAS_MAX_PASO, "x6: 0,2 s → un paso de %d días (≤ 31)" % d6)
	ok(r.texto() == "2026,05,%02d" % (1 + d6) or r.mes == 6, "x6: la fecha avanzó con el paso (%s)" % r.texto())
	ok(dm[0] == d6, "avanzar usa `al_dia_diferido` (y le pasa k=%d)" % dm[0])
	var acum_antes := 0.0
	r.fijar(2026, 5, 1)
	r.acum = 0.1
	acum_antes = r.acum
	r.ocupado = true
	ok(r.avanzar(0.0) == 0 and cerca(r.acum, minf(acum_antes, 0.1674), 1e-6) , "con `ocupado` no empieza otro paso y conserva el tiempo debido")
	r.ocupado = false
	r.fijar(2026, 5, 31)
	var antes_acum := 0.1
	r.acum = antes_acum
	var d_fin: int = r.avanzar(0.0)
	ok(d_fin == 1 and r.texto() == "2026,06,01", "x6 el 31 de mayo: el paso se corta en el fin de mes (%d día)" % d_fin)
	ok(r.acum < antes_acum and r.acum >= 0.0, "…y se descuentan solo los días simulados (%.4f)" % r.acum)
	# un aviso que pone velocidad = 0 corta al instante
	r = RelojScript.new()
	r.velocidad = 3
	r.acum = 0.2
	r.al_dia_diferido = func(_a: bool, _b: bool, _k: int): r.velocidad = 0
	r.avanzar(0.0)
	ok(r.avanzar(1.0) == 0, "si un aviso pausa el juego, el reloj no sigue")


# ───────────────────────── 3. Mundo ─────────────────────────
func vecino_ajeno() -> Array:
	## [tid propio, tid rival, provincia (índice) del rival, nombre del rival] con un rival de IA vecino del jugador
	var jt: int = m.paises["España"].tid
	for nv in ia.vecinos_de("España"):
		var rn := String(nv)
		if not m.paises.has(rn) or m.paises[rn].provincias.is_empty():
			continue
		return [jt, int(m.paises[rn].tid), int(m.paises[rn].provincias[0]), rn]
	return []


func t_mundo() -> void:
	print("[T] ── Mundo")
	var jug: String = m.jugador
	ok(not m.ve_todo(), "con país elegido, ve_todo() = false")
	m.fijar_jugador("")
	ok(m.ve_todo(), "observador (jugador \"\"): ve_todo() = true")
	ok(m.paises_visibles().is_empty(), "el observador no tiene `paises_visibles` propios (ve todo por otra vía)")
	m.fijar_jugador(jug)
	ok(m.paises_visibles() == [jug], "con país: solo el suyo (aún no hay aliados ni vasallos)")
	# rival_por_entrar
	var v := vecino_ajeno()
	ok(not v.is_empty(), "hay un vecino de IA para probar")
	if v.is_empty():
		return
	var jt: int = v[0]
	var rt: int = v[1]
	var pi_rival: int = v[2]
	var pi_propia: int = int(m.paises["España"].provincias[0])
	ok(m.rival_por_entrar(jt, pi_propia) == -1, "rival_por_entrar: entrar a una provincia PROPIA no pide guerra")
	ok(m.rival_por_entrar(jt, pi_rival) == rt, "rival_por_entrar: provincia de un vecino sin guerra → su ID (%d)" % rt)
	ok(m.rival_por_entrar(rt, pi_rival) == -1, "rival_por_entrar: el dueño entrando a la suya → -1")
	var gid: int = g.declarar(jt, rt, "prueba")
	ok(gid >= 0 and m.rival_por_entrar(jt, pi_rival) == -1, "rival_por_entrar: ya en guerra → -1")
	ok(m.rival_por_entrar(rt, pi_propia) == -1, "rival_por_entrar: simétrico, también en guerra → -1")
	g.paz(jt, rt, "prueba")
	ok(m.rival_por_entrar(jt, pi_rival) == rt, "rival_por_entrar: tras la paz vuelve a pedir guerra")
	ok(m.rival_por_entrar(jt, 999999 % m.provincias.size()) >= -1, "rival_por_entrar con una provincia cualquiera no se rompe")
	# fases_dias / avanzar_dias
	var fs: Array = m.fases_dias(3)
	ok(fs.size() == 6, "fases_dias: economía + IA + ejército + llegadas + batallas + ocupaciones = 6 (hay %d)" % fs.size())
	var todas_validas := true
	for f in fs:
		todas_validas = todas_validas and (f as Callable).is_valid()
	ok(todas_validas, "todas las fases son Callables válidos")
	var d0: int = ia.dia_n
	m.avanzar_dias(1)
	ok(ia.dia_n == d0 + 1, "avanzar_dias(1): el reloj de la IA avanza 1 día")
	m.avanzar_dias(5)
	ok(ia.dia_n == d0 + 6, "avanzar_dias(5): avanza 5 días de una sola vez")
	m.avanzar_dia()
	ok(ia.dia_n == d0 + 7, "avanzar_dia() = avanzar_dias(1)")
	ok(m.prof_fases.has("_economia_dia") and m.prof_fases.has("fase_dia") and m.prof_fases.has("fase_batallas"), "prof_fases anota cada fase por su nombre (%s)" % str(m.prof_fases.keys()))
	var llamadas_eco: int = int(m.prof_fases["_economia_dia"][1])
	ok(llamadas_eco == 3, "…y cuenta una llamada por paso (3 pasos → %d)" % llamadas_eco)
	var sin_ia_fases: Array = m.fases_dias(1)
	var ia_ref = m.ia
	m.ia = null
	var fs2: Array = m.fases_dias(1)
	m.ia = ia_ref
	ok(fs2.size() == sin_ia_fases.size() - 1, "sin IA, fases_dias no incluye la fase de IA")


# ───────────────────────── 4. IA ─────────────────────────
func t_ia() -> void:
	print("[T] ── Ia")
	var v := vecino_ajeno()
	var a: int = v[0]
	var b: int = v[1]
	var otro := -1
	for n in m.paises:
		if m.paises[n].tid != a and m.paises[n].tid != b and not m.paises[n].provincias.is_empty():
			otro = int(m.paises[n].tid)
			break
	ok(ia.tregua_restante(a, otro) == 0 and not ia._en_tregua(a, otro), "sin paz firmada: tregua_restante = 0 y _en_tregua = false")
	var guardado_dia: int = ia.dia_n
	ia.registrar_paz(a, b)
	ok(ia.tregua_restante(a, b) == ia.TREGUA_DIAS and ia._en_tregua(a, b), "registrar_paz: tregua de %d días (5 años)" % ia.TREGUA_DIAS)
	ok(ia.tregua_restante(b, a) == ia.tregua_restante(a, b), "la tregua es simétrica (a,b) = (b,a)")
	ok(ia.tregua_restante(a, otro) == 0, "…y no afecta a otros países")
	ia.dia_n += 100
	ok(ia.tregua_restante(a, b) == ia.TREGUA_DIAS - 100, "pasan 100 días: quedan %d" % ia.tregua_restante(a, b))
	ia.dia_n += ia.TREGUA_DIAS
	ok(ia.tregua_restante(a, b) == 0 and not ia._en_tregua(a, b), "vencida la tregua: 0 (nunca negativo) y _en_tregua = false")
	ia.dia_n = guardado_dia
	ia.tregua.clear()
	# control_cambiado
	var nom_a := "España"
	var nom_b := String(v[3])
	ok(ia.activas.has(nom_b) and not ia.activas.has(nom_a), "partida: el rival tiene IA y el jugador no")
	var n_ant: int = ia.activas.size()
	m.fijar_jugador(nom_b)                           # el jugador pasa de España a su vecino (fijar_jugador llama a control_cambiado)
	ok(ia.activas.has(nom_a) and not ia.activas.has(nom_b), "control_cambiado: el país que dejas pasa a la IA y el que tomas la pierde")
	ok(ia.activas.size() == n_ant, "…el nº de IA no cambia (%d)" % ia.activas.size())
	m.fijar_jugador(nom_a)
	ok(ia.activas.has(nom_b) and not ia.activas.has(nom_a) and ia.activas.size() == n_ant, "de vuelta a España: todo como al principio")
	m.fijar_jugador("")                              # el jugador pasa a observador
	ok(ia.activas.has(nom_a) and ia.activas.size() == n_ant + 1, "de un país a observador: el país suelto lo lleva la IA (%d IA)" % ia.activas.size())
	m.fijar_jugador(nom_b)                           # de observador a controlar un país
	ok(not ia.activas.has(nom_b) and ia.activas.size() == n_ant, "de observador a un país: ese país deja de tener IA")
	m.fijar_jugador(nom_a)
	ok(ia.activas.has(nom_b) and not ia.activas.has(nom_a), "…y al volver a España, todo igual")
	ia.control_cambiado(nom_a, nom_a)
	ok(not ia.activas.has(nom_a) and ia.activas.size() == n_ant, "mismo país → no pasa nada raro (sigue sin IA)")
	ia.control_cambiado("", "")
	ok(ia.activas.size() == n_ant, "control_cambiado(\"\", \"\") no toca nada")
	# la guerra abierta del país que tomas no se cierra (la hereda el jugador)
	g.declarar(int(m.paises[nom_b].tid), otro, "prueba")
	m.fijar_jugador(nom_b)
	ok(g.rivales_de(int(m.paises[nom_b].tid)).size() >= 1, "al tomar un país, sus guerras abiertas siguen (las hereda el jugador)")
	m.fijar_jugador(nom_a)
	g.paz(int(m.paises[nom_b].tid), otro, "prueba")
	ia.tregua.clear()
	# _armar_cola
	for n in ia.activas:
		ia.activas[n]["proximo"] = ia.dia_n + 50
	ia._armar_cola()
	ok(ia._cola_hoy.is_empty(), "_armar_cola: si a nadie le toca, la cola queda vacía")
	var nombres: Array = ia.activas.keys()
	for i in 3:
		ia.activas[nombres[i]]["proximo"] = ia.dia_n - [10, 2, 0][i]
	ia._armar_cola()
	ok(ia._cola_hoy == [nombres[0], nombres[1], nombres[2]], "_armar_cola: primero la más atrasada (%s)" % str(ia._cola_hoy))
	for i in nombres.size():
		ia.activas[nombres[i]]["proximo"] = ia.dia_n
	ia._armar_cola()
	ok(ia._cola_hoy.size() == ia.MAX_IA_PASO, "_armar_cola: con todas debidas, solo MAX_IA_PASO = %d (hay %d)" % [ia.MAX_IA_PASO, ia._cola_hoy.size()])
	# _armar_cola: las que están EN GUERRA van antes que las atrasadas
	for i in nombres.size():
		ia.activas[nombres[i]]["proximo"] = ia.dia_n + 50
	ia.activas[nombres[0]]["proximo"] = ia.dia_n - 30                      # muy atrasada, en paz
	var tid_g: int = int(ia.activas[nombres[1]]["tid"])
	m.bd.poner_f("guerras_activas", tid_g, 1.0, "prueba")
	ia.activas[nombres[1]]["proximo"] = ia.dia_n                           # en guerra, al día
	ia._armar_cola()
	ok(ia._cola_hoy.size() == 2 and ia._cola_hoy[0] == nombres[1], "_armar_cola: la que está en guerra va antes que la atrasada en paz (%s)" % str(ia._cola_hoy))
	m.bd.poner_f("guerras_activas", tid_g, 0.0, "prueba")
	# fase_dia: LOTE_IA decisiones por llamada (0.1.8.32: LOTE_IA = 1, para que el presupuesto del fotograma corte justo)
	ia._cola_hoy.clear()
	ia._cola_lista = false
	for i in nombres.size():
		ia.activas[nombres[i]]["proximo"] = ia.dia_n + 50
	for i in 7:
		ia.activas[nombres[i]]["proximo"] = ia.dia_n
	var dia0: int = ia.dia_n
	var dec0: int = ia.decisiones
	var r1: bool = ia.fase_dia(1)
	ok(r1 and ia.dia_n == dia0 + 1 and ia._cola_lista, "fase_dia (1.ª llamada): el reloj avanza 1 día y quedan IA por decidir → true")
	ok(ia.dec_paso == ia.LOTE_IA, "…decidieron LOTE_IA = %d" % ia.dec_paso)
	var r2: bool = ia.fase_dia(1)
	ok(r2 and ia.dia_n == dia0 + 1 and ia.dec_paso == 2 * ia.LOTE_IA, "2.ª llamada: no vuelve a sumar el día y deciden otras LOTE_IA → true")
	var llamadas := 2
	var r3: bool = r2
	while r3 and llamadas < 20:
		r3 = ia.fase_dia(1)
		llamadas += 1
	ok(not r3 and not ia._cola_lista and ia.dec_paso == 7, "al final decide la última y termina (false, 7 decisiones, %d llamadas)" % llamadas)
	ok(llamadas == int(ceil(7.0 / float(ia.LOTE_IA))), "7 IA debidas → ceil(7 / LOTE_IA) llamadas (%d)" % llamadas)
	ok(ia.decisiones - dec0 == 7, "contador global de decisiones +7")
	var todas_reprogramadas := true
	for i in 7:
		todas_reprogramadas = todas_reprogramadas and int(ia.activas[nombres[i]]["proximo"]) > ia.dia_n
	ok(todas_reprogramadas, "cada IA que decidió reprograma su próxima decisión")
	var k_dia0: int = ia.dia_n
	ia.avanzar_dia(4)
	ok(ia.dia_n == k_dia0 + 4, "avanzar_dia(4): el paso de 4 días suma 4")
	# _frente_de
	ia._preparar_frentes()
	var jt: int = a
	var fr: Array = ia._frente_de(jt)
	var valido := not fr.is_empty()
	for par in fr:
		valido = valido and int(ia._ctrl[int(par[0])]) == jt and int(ia._ctrl[int(par[1])]) != jt and int(ia._ctrl[int(par[1])]) >= 0
	ok(valido, "_frente_de(España): %d pares [provincia propia, provincia vecina de otro país]" % fr.size())
	ok(ia._frente_de(jt) == fr, "se guarda: la 2.ª consulta devuelve lo mismo")
	ok(ia._frente.has(jt), "…en la tabla `_frente` (se calcula POR PAÍS, no todo el mundo)")
	var sin_provs := -1
	for n in m.paises:
		if m.paises[n].provincias.is_empty():
			sin_provs = int(m.paises[n].tid)
			break
	if sin_provs >= 0:
		ok(ia._frente_de(sin_provs).is_empty(), "un país sin provincias no tiene frente")
	ia._frente.clear()
	ia.tregua.clear()


# ───────────────────────── 5. Guerra ─────────────────────────
func armar_batalla() -> Dictionary:
	## Pone tropas de España y de un vecino en una provincia del vecino, declara la guerra y abre la batalla. Devuelve {bid, atac, def, prov}.
	var v := vecino_ajeno()
	var a: int = v[0]
	var b: int = v[1]
	var pi: int = v[2]
	var prov_tid: int = int(m.provincias[pi].tid)
	g.declarar(a, b, "prueba")
	ej.reclutar(a, prov_tid, 30000, "prueba")
	ej.reclutar(b, prov_tid, 10000, "prueba")
	g._revisar_prov(prov_tid, a)
	var bid := -1
	for k in g.batallas_activas:
		bid = int(g.batallas_activas[k])
	return {"bid": bid, "atac": a, "def": b, "prov": prov_tid}


func t_guerra() -> void:
	print("[T] ── Guerra")
	# _fraccion_de_bajas
	g._rng.seed = 123
	var p1: Array = g._fraccion_de_bajas(1000.0, 1000.0, 1)
	g._rng.seed = 123
	var p1b: Array = g._fraccion_de_bajas(1000.0, 1000.0, 1)
	ok(p1[0] == p1b[0] and p1[1] == p1b[1], "_fraccion_de_bajas es determinista con la misma semilla")
	ok(p1[0] >= g.RITMO_BAJAS * (1.0 - g.RUIDO) - 1e-9 and p1[0] <= g.RITMO_BAJAS * (1.0 + g.RUIDO) + 1e-9, "fuerzas parejas: bajas ≈ 8 %% ± 15 %% (%.4f)" % p1[0])
	g._rng.seed = 123
	var p4: Array = g._fraccion_de_bajas(1000.0, 1000.0, 4)
	ok(cerca(p4[0], 1.0 - pow(1.0 - p1[0], 4.0)) and cerca(p4[1], 1.0 - pow(1.0 - p1[1], 4.0)), "4 días = 1 − (1 − l)^4 con el mismo ruido")
	ok(p4[0] > p1[0], "más días, más bajas")
	g._rng.seed = 7
	var pf: Array = g._fraccion_de_bajas(9000.0, 1000.0, 1)
	ok(pf[1] > pf[0] * 3.0, "el fuerte (9:1) pierde mucho menos que el débil (%.3f vs %.3f)" % [pf[0], pf[1]])
	g._rng.seed = 7
	var pt: Array = g._fraccion_de_bajas(1.0e9, 1.0, 40)
	ok(pt[0] >= 0.0 and pt[1] <= 1.0 and pt[0] < 1.0 and pt[1] < 1.0 + 1e-12, "con muchos días la fracción sigue entre 0 y 1")
	g._rng.seed = 5
	var estado_antes: int = g._rng.state
	g._fraccion_de_bajas(1.0, 1.0, 1)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	rng2.randf_range(0.0, 1.0)
	rng2.randf_range(0.0, 1.0)
	ok(g._rng.state == rng2.state and estado_antes != g._rng.state, "consume exactamente 2 números del azar (el orden de la partida no cambia)")
	g._rng.randomize()
	# batalla real
	var bt := armar_batalla()
	var bid: int = bt["bid"]
	ok(bid >= 0 and g.batallas_activas.size() == 1, "se abrió una batalla de prueba (id %d)" % bid)
	if bid < 0:
		return
	var prov: int = bt["prov"]
	var atac: int = bt["atac"]
	var def_: int = bt["def"]
	var ini_a: int = ej.soldados_en_provincia(prov, atac)
	var ini_d: int = ej.soldados_en_provincia(prov, def_)
	# _aplicar
	var pel: Array = g.pelotones_en(prov, atac)
	var antes: int = g._soldados(pel)
	var bajas: int = g._aplicar(pel, 0.10, "prueba")
	var desp: int = g._soldados(g.pelotones_en(prov, atac))
	ok(bajas > 0 and antes - desp == bajas, "_aplicar: devuelve las bajas reales (%d) y los soldados bajan en ese número" % bajas)
	ok(bajas >= pel.size() and float(bajas) <= float(antes) * 0.10 + float(pel.size()), "…cada pelotón pierde ceil(10 %%) como mucho (mín. 1)")
	ok(g._aplicar([], 0.5, "prueba") == 0, "_aplicar sobre una lista vacía: 0")
	# _quien_se_retira
	var ia_ini: float = m.bd.num("bat_ini_atac", bid)
	var id_ini: float = m.bd.num("bat_ini_def", bid)
	var pa2: Array = g.pelotones_en(prov, atac)
	var pd2: Array = g.pelotones_en(prov, def_)
	ok(g._quien_se_retira(bid, pa2, pd2) == -1, "_quien_se_retira: con fuerzas casi enteras nadie se retira")
	m.bd.poner_f("bat_ini_atac", bid, float(g._soldados(pa2)) * 10.0, "prueba")      # el atacante conserva el 10 %
	ok(g._quien_se_retira(bid, pa2, pd2) == atac, "…el atacante con <35 %% de su fuerza y peor que el rival se retira")
	m.bd.poner_f("bat_ini_def", bid, float(g._soldados(pd2)) * 20.0, "prueba")       # el defensor, 5 %
	ok(g._quien_se_retira(bid, pa2, pd2) == def_, "…si el defensor está peor que el atacante, se retira el defensor (fa ≤ fd no se cumple)")
	m.bd.poner_f("bat_ini_atac", bid, ia_ini, "prueba")
	m.bd.poner_f("bat_ini_def", bid, id_ini * 100.0, "prueba")
	ok(g._quien_se_retira(bid, pa2, pd2) == def_, "…y solo el defensor si es el único bajo el 35 %%")
	m.bd.poner_f("bat_ini_def", bid, id_ini, "prueba")
	# _sub_ronda
	var dias0: float = m.bd.num("bat_dias", bid)
	var sa0: int = ej.soldados_en_provincia(prov, atac)
	var sd0: int = ej.soldados_en_provincia(prov, def_)
	var termino: bool = g._sub_ronda(bid, 2)
	var sa1: int = ej.soldados_en_provincia(prov, atac)
	var sd1: int = ej.soldados_en_provincia(prov, def_)
	ok(sa1 < sa0 and sd1 < sd0, "_sub_ronda: los dos bandos sufren bajas (%d→%d, %d→%d)" % [sa0, sa1, sd0, sd1])
	if not termino:
		ok(cerca(m.bd.num("bat_dias", bid), dias0 + 2.0), "…y la batalla suma los 2 días")
	var baj_a: float = m.bd.num("bat_bajas_atac", bid)
	var baj_d: float = m.bd.num("bat_bajas_def", bid)
	ok(baj_a > 0.0 and baj_d > 0.0, "…y anota las bajas de cada bando en la base (%d / %d)" % [baj_a, baj_d])
	# _ronda: parte los días en sub-rondas
	if g.batallas_activas.size() > 0:
		var d_antes: float = m.bd.num("bat_dias", bid)
		g._ronda(bid, 9)
		if g.batallas_activas.size() > 0:
			ok(cerca(m.bd.num("bat_dias", bid), d_antes + 9.0), "_ronda(9 días) = 4 + 4 + 1: la batalla suma 9 días")
		else:
			ok(m.bd.num("bat_dias", bid) <= d_antes + 9.0 + 1e-9, "_ronda(9 días): la batalla terminó antes (no pasa de 9 días)")
	# una batalla que se termina sola (sin tropas de un bando)
	var bt_fin := {}
	if g.batallas_activas.size() > 0:
		var bid2 := -1
		for k in g.batallas_activas:
			bid2 = int(g.batallas_activas[k])
		for rid in ej.regs_prov.get(prov, []).duplicate():
			if ej.pais_de_reg(int(rid)) == def_:
				ej.disolver_reg(int(rid))
		var fin: bool = g._sub_ronda(bid2, 1)
		ok(fin and not g.batallas_activas.has(g._clave_bat(prov, atac, def_)), "_sub_ronda: si un bando se queda sin tropas, la batalla termina (true)")
	# fase_batallas: tamaño de lote según los días del paso (5 con k=1; con k=31 solo 1 por llamada). Se arma una cola de 12 claves que ya
	# no existen en `batallas_activas`: la fase solo las descuenta del lote y no combate nada.
	ok(g.LOTE_BATALLAS == 5 and g.SUBRONDA_DIAS == 4, "constantes: lote 5 batallas, sub-rondas de 4 días")
	g.batallas_activas.clear()
	var guerra_aux: int = g.declarar(int(m.paises["España"].tid), int(m.paises["Francia"].tid), "prueba")
	for casos in [[1, 2], [4, 2], [5, 5], [31, 11]]:       # [días del paso, llamadas que devuelven true con 12 en cola]
		g._bat_cola = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
		g._bat_lista = true
		var trues := 0
		while g.fase_batallas(int(casos[0])) and trues < 50:
			trues += 1
		ok(trues == int(casos[1]), "fase_batallas(%d días): 12 batallas en cola → %d llamadas con trabajo pendiente (%d)" % [casos[0], casos[1], trues])
	ok(not g._bat_lista, "al vaciarse la cola, `_bat_lista` vuelve a false")
	g.paz(int(m.paises["España"].tid), int(m.paises["Francia"].tid), "prueba")
	ia.tregua.clear()
	# _escanear_ocupaciones: acumula días hasta DIAS_ESCANEO
	g._dias_escaneo = 0
	g._escanear_ocupaciones(3)
	ok(g._dias_escaneo == 3, "_escanear_ocupaciones: acumula días (3)")
	g._escanear_ocupaciones(3)
	ok(g._dias_escaneo == 6, "…(6)")
	g._escanear_ocupaciones(3)
	ok(g._dias_escaneo == 0, "…al llegar a %d días corre el escaneo y vuelve a 0" % g.DIAS_ESCANEO)
	g._escanear_ocupaciones(31)
	ok(g._dias_escaneo == 0, "un paso de 31 días escanea una vez")
	# fase_llegadas / fase_ocupaciones sin guerra no hacen nada
	var guardadas: Dictionary = g.activas.duplicate()
	g.activas.clear()
	ok(not g.fase_batallas(1) and not g.fase_ocupaciones(1) and not g.fase_llegadas(), "sin guerras activas las tres fases devuelven false")
	g.activas = guardadas
	g.paz(int(bt["atac"]), int(bt["def"]), "prueba")                  # se cierra la guerra de la batalla de prueba
	ok(not g.en_guerra(int(bt["atac"]), int(bt["def"])) and g.batallas_activas.is_empty(), "la paz cierra la guerra y sus batallas")
	ia.tregua.clear()


# ───────────────────────── 6. MapaPrincipal ─────────────────────────
func filas_historial() -> int:
	var t := 0
	for nombre in m.bd.hist:
		t += int(m.bd.hist[nombre].cuenta())
	return t


func t_mapa() -> void:
	print("[T] ── MapaPrincipal")
	var casos := {0: "0 días", 1: "1 día", 12: "12 días", 44: "44 días", 45: "2 meses", 90: "3 meses", 180: "6 meses",
		364: "12 meses", 365: "1 año", 395: "1 año y 1 mes", 730: "2 años", 760: "2 años y 1 mes", 1000: "2 años y 9 meses", 1825: "5 años", 1840: "5 años"}
	for d in casos:
		var t: String = main.texto_duracion(int(d))
		ok(t == casos[d], "texto_duracion(%d) = «%s»" % [d, t])
	# _tregua_dias
	var v := vecino_ajeno()
	var jt: int = v[0]
	var rt: int = v[1]
	ok(main._tregua_dias(jt, rt) == 0, "_tregua_dias sin paz = 0")
	ia.registrar_paz(jt, rt)
	ok(main._tregua_dias(jt, rt) == ia.TREGUA_DIAS, "_tregua_dias tras la paz = %d" % ia.TREGUA_DIAS)
	var ia_ref = m.ia
	m.ia = null
	ok(main._tregua_dias(jt, rt) == 0, "_tregua_dias sin IA = 0 (no se rompe)")
	m.ia = ia_ref
	ia.tregua.clear()
	# puede_ordenar_pais
	ok(main.puede_ordenar_pais("España") and not main.puede_ordenar_pais("Francia"), "campaña con país: solo ordenas el tuyo")
	m.fijar_jugador("")
	ok(not main.puede_ordenar_pais("España") and not main.puede_ordenar_pais("Francia"), "campaña como observador: no ordenas a nadie")
	var camp: bool = main.campana_activa
	main.campana_activa = false
	ok(main.puede_ordenar_pais("Francia"), "modo libre como observador: ordenas a cualquier país")
	main.campana_activa = camp
	m.fijar_jugador("España")
	var mundo_ref = main.mundo
	main.mundo = null
	ok(not main.puede_ordenar_pais("España"), "sin mundo no se puede ordenar (y no se rompe)")
	main.mundo = mundo_ref
	# puede_declarar_guerra
	var e1: Dictionary = main.puede_declarar_guerra(jt)
	ok(not e1["ok"] and String(e1["motivo"]).contains("propio país"), "no se declara la guerra a uno mismo: " + String(e1["motivo"]))
	var e2: Dictionary = main.puede_declarar_guerra(rt)
	ok(e2["ok"] and e2["motivo"] == "", "un vecino con IA sin guerra: se puede")
	var e3: Dictionary = main.puede_declarar_guerra(999999)
	ok(not e3["ok"], "un ID que no es un país: se rechaza (%s)" % String(e3["motivo"]))
	g.declarar(jt, rt, "prueba")
	var e4: Dictionary = main.puede_declarar_guerra(rt)
	ok(not e4["ok"] and String(e4["motivo"]).begins_with("Ya estás en guerra"), "ya en guerra: " + String(e4["motivo"]))
	g.paz(jt, rt, "prueba")
	ia.desactivar(String(v[3]), false)
	var e5: Dictionary = main.puede_declarar_guerra(rt)
	ok(not e5["ok"] and String(e5["motivo"]).contains("no tiene IA"), "rival sin IA en la campaña: " + String(e5["motivo"]))
	ia.activar(String(v[3]))
	m.fijar_jugador("")
	var e6: Dictionary = main.puede_declarar_guerra(rt)
	ok(not e6["ok"] and String(e6["motivo"]).contains("observador"), "como observador: " + String(e6["motivo"]))
	m.fijar_jugador("España")
	# declarar_guerra_jugador
	var d1: Dictionary = main.declarar_guerra_jugador(jt)
	ok(not d1["ok"] and d1["msg"] != "", "declarar_guerra_jugador a uno mismo: {ok:false, msg}")
	var n_ev: int = m.eventos.size()
	var d2: Dictionary = main.declarar_guerra_jugador(rt)
	ok(d2["ok"] and g.en_guerra(jt, rt), "declarar_guerra_jugador: guerra abierta")
	ok(String(d2["msg"]).begins_with("Declaraste la guerra a"), "…con su mensaje: " + String(d2["msg"]))
	ok(m.eventos.size() == n_ev + 1, "…y deja un suceso en el historial")
	var gid: int = g.guerra_entre(jt, rt)
	ok(String(g.ficha_guerra(gid)["causa"]) == "Declaración de guerra", "…y la guerra queda con la causa «Declaración de guerra»")
	var d3: Dictionary = main.declarar_guerra_jugador(rt)
	ok(not d3["ok"], "declarar de nuevo la misma guerra: rechazado")
	# _aviso_sin_guerra
	var pi_rival: int = v[2]
	ok(main._aviso_sin_guerra(jt, pi_rival) == "", "en guerra: la orden de entrar no se avisa")
	g.paz(jt, rt, "prueba")
	var av: String = main._aviso_sin_guerra(jt, pi_rival)
	ok(av.begins_with("No estás en guerra con") and av.contains("Declarar la guerra"), "sin guerra: " + av)
	ok(main._aviso_sin_guerra(jt, int(m.paises["España"].provincias[0])) == "", "provincia propia: sin aviso")
	m.fijar_jugador("")
	ok(main._aviso_sin_guerra(jt, pi_rival) == "", "observador: sin aviso (conserva el comportamiento libre)")
	m.fijar_jugador("España")
	ia.tregua.clear()
	# regla de «entrar = atacar» en la orden de marcha
	var prov_tid_prop: int = int(m.provincias[int(m.paises["España"].provincias[0])].tid)
	var rids: Array = ej.regs_pais.get(jt, [])
	var rid_libre := -1
	for rid in rids:
		if not ej.en_marcha_reg(int(rid)) and ej.soldados_reg(int(rid)) > 0:
			rid_libre = int(rid)
			break
	if rid_libre >= 0:
		var n_guerras: int = g.activas.size()
		var res: Dictionary = ej.ordenar_marcha_reg(rid_libre, 0, pi_rival)
		ok(bool(res.get("ok", false)) and int(res["contra"]) == rt and int(res["guerra"]) >= 0, "ordenar_marcha_reg a territorio ajeno sin guerra: declara la guerra a %d (regla única de Mundo.rival_por_entrar)" % rt)
		ok(g.activas.size() == n_guerras + 1 and String(res["msg"]).begins_with("¡GUERRA con"), "…la guerra queda abierta y el mensaje la anuncia")
		g.paz(jt, rt, "prueba")
		ia.tregua.clear()
		ej.detener_marcha(int(res["marcha"]))
	# _fases_mes
	var f_mes: Array = main._fases_mes(false)
	ok(f_mes.size() == 2 and (f_mes[0] as Callable).is_valid() and (f_mes[1] as Callable).is_valid(), "_fases_mes(sin año nuevo): desarrollo + cierre mensual")
	var f_anio: Array = main._fases_mes(true)
	ok(f_anio.size() == 3, "_fases_mes(año nuevo): + cierre anual")
	var v_bd: int = m.bd.version
	for f in f_mes:
		(f as Callable).call()
	ok(m.bd.version > v_bd, "las fases mensuales corren (la versión de la base sube)")
	# _cierre_periodo
	var f0 := filas_historial()
	var est_m := {}
	while main._cierre_periodo("mensual", est_m):                # 0.1.8.32: el cierre va por trozos (devuelve true mientras quede trabajo)
		pass
	var f1 := filas_historial()
	ok(f1 > f0, "_cierre_periodo(\"mensual\") archiva filas en el historial (%d → %d)" % [f0, f1])
	var est_a := {}
	var trozos := 0
	while main._cierre_periodo("anual", est_a):
		trozos += 1
	ok(trozos >= 1, "el cierre anual se reparte en varios trozos (%d)" % (trozos + 1))
	ok(filas_historial() >= f1, "_cierre_periodo(\"anual\") también corre sin perder historial")
	# _medir_etiqueta / etiqueta_tramo
	var lab := {"t": "ESPAÑA", "e": 18.0, "g": "p", "p": [0.0, 0.0, 400.0, 0.0], "lc": 1}
	var lab_grupos: Array = main.ESPACIADO_MAX.keys()
	ok(lab_grupos.has("p") or lab_grupos.has("c"), "ESPACIADO_MAX tiene grupos (%s)" % str(lab_grupos))
	var gr: String = "p" if lab_grupos.has("p") else String(lab_grupos[0])
	lab["g"] = gr
	var med: Dictionary = main._medir_etiqueta(lab, 400.0)
	ok(med.has("k") and med.has("extra") and med.has("largo_texto") and med.has("anchos"), "_medir_etiqueta devuelve k, extra, largo_texto y anchos")
	ok((med["anchos"] as PackedFloat32Array).size() == 6, "…un ancho por letra (6)")
	ok(float(med["largo_texto"]) <= 0.96 * 400.0 + 1e-6 or float(med["largo_texto"]) <= 400.0 * 0.9 + 1e-6, "…el texto cabe en la línea (%.1f de 400)" % float(med["largo_texto"]))
	ok(float(med["extra"]) >= 0.0, "…el espacio extra entre letras nunca es negativo")
	var tr: Array = main.etiqueta_tramo(lab, 400.0)
	ok(cerca(tr[1], med["largo_texto"], 1e-6) and cerca(tr[0], (400.0 - float(med["largo_texto"])) * 0.5, 1e-6), "etiqueta_tramo = [inicio centrado, largo, alto] con la misma cuenta")
	ok(cerca(tr[2], float(med["k"]) * float(main.FUENTE_BASE), 1e-6), "…y el alto de las letras es k × FUENTE_BASE")
	var corta: Dictionary = main._medir_etiqueta(lab, 20.0)
	ok(float(corta["k"]) < float(med["k"]) and float(corta["largo_texto"]) <= 0.96 * 20.0 + 1e-6, "en una línea corta el texto se encoge (k %.3f < %.3f) y no se sale" % [float(corta["k"]), float(med["k"])])
	var una := {"t": "X", "e": 18.0, "g": gr, "p": [0.0, 0.0, 100.0, 0.0], "lc": 1}
	var m1: Dictionary = main._medir_etiqueta(una, 100.0)
	ok(cerca(float(m1["extra"]), 0.0) and (m1["anchos"] as PackedFloat32Array).size() == 1, "una sola letra: sin espaciado")
	var vacia := {"t": "", "e": 18.0, "g": gr, "p": [0.0, 0.0, 100.0, 0.0], "lc": 1}
	var m0: Dictionary = main._medir_etiqueta(vacia, 100.0)
	ok(float(m0["largo_texto"]) == 0.0 or float(m0["largo_texto"]) <= 0.0 + 1e-9, "texto vacío: largo 0 (no se rompe)")


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)
	main._iniciar_partida({"modo": "campana", "pais": "España", "ia": 1})
	await esperar(0.6)
	m = main.mundo
	g = m.guerra
	ia = m.ia
	ej = m.ejercito
	main.reloj.velocidad = 0
	t_perfil()
	t_reloj()
	t_mundo()
	t_ia()
	t_guerra()
	t_mapa()
	print("[T] ── %d comprobaciones OK · FALLOS: %d" % [n_ok, fallos])
	get_tree().quit()
