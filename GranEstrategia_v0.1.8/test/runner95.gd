extends Node
## 0.1.8.43 · PRUEBAS DE DIPLOMACIA, ESTABILIDAD E IA CON CONSECUENCIAS (época 1 d. C., todas las IA activas cuando hace falta):
##  · Diplomacia: opinión (olvido, razones, etiquetas), alianzas (reglas, límite de 3, rival, `relacionados_de`), llamadas de alianza (acude o rompe), infamia (conquista, traición,
##    tregua rota, vida media), coaliciones (se forman con ≥ 2 vecinos con IA, atacan juntas, se disuelven).
##  · Estabilidad: las partes de la meta (capital, conquista reciente, sobreextensión, cultura), el reparto en lotes (cada provincia una vez por ciclo, máx. 5 puntos), el motín
##    (pagar, reprimir, conceder → la tierra vuelve a su core y el país renace; sin Estado → saqueo; grupo de vecinas; encarece al repetirse; aviso al jugador).
##  · IA: no ataca a amigos, se frena con infamia o inestabilidad, va contra su rival y contra el blanco de su coalición, y descansa tras conquistar.
##  · Pop-ups del jugador (revuelta, alianza, llamada), acciones de la pestaña Diplomacia y la estabilidad en la ficha de la provincia.
var main
var m
var fallos := 0
var n_ok := 0


func _ready() -> void:
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


func tid(n: String) -> int:
	return int(m.paises[n].tid)


func nom(t: int) -> String:
	return m.bd.nombre_de(t)


## Deja la diplomacia y las guerras como al empezar (sin tocar los países).
func limpiar() -> void:
	var d = m.diplomacia
	d.opinion.clear()
	d.razones.clear()
	d.alianzas.clear()
	d._aliados.clear()
	d._rival.clear()
	d._infamia.clear()
	d.infames.clear()
	d.coaliciones.clear()
	d.llamados.clear()
	for k in m.guerra.activas.keys():
		var p: PackedStringArray = String(k).split("|")
		m.guerra.paz(int(p[0]), int(p[1]), "limpieza de prueba")
	m.ia.tregua.clear()
	for n in m.ia.activas:
		m.ia.activas[n]["no_guerra_hasta"] = 0
	m.avisos.clear()


## Un país con IA y vecinos con IA (para probar relaciones): devuelve [nombre, [vecinos con provincias]].
func elegir_con_vecinos(minimo: int) -> Array:
	m.ia._preparar_frentes()
	var mejor := ""
	var mejor_n := 0
	for n in m.ia.activas:
		var v: Array = m.ia.vecinos_de(String(n))
		var buenos := []
		for x in v:
			if m.ia.activas.has(String(x)):
				buenos.append(String(x))
		if buenos.size() > mejor_n and buenos.size() <= 6:
			mejor_n = buenos.size()
			mejor = String(n)
			if mejor_n >= minimo:
				break
	return [mejor, m.ia.vecinos_de(mejor).filter(func(x): return m.ia.activas.has(String(x)))]


func fijar_soldados(mapa: Dictionary) -> void:
	m.ia._sold_dia = mapa
	m.ia._sold_dia_n = m.ia.dia_n


# ═════════════ Diplomacia ═════════════
func t_opinion() -> void:
	var d = m.diplomacia
	var par := elegir_con_vecinos(2)
	var a: int = tid(par[0])
	var b: int = tid(par[1][0])
	limpiar()
	ok(d.opinion_de(a, b) == 0.0 and d.opinion_total(a, b) == 0.0, "Sin trato previo la opinión es 0")
	d.cambiar_opinion(a, b, 50.0, "prueba")
	ok(absf(d.opinion_de(a, b) - 50.0) < 0.01 and absf(d.opinion_de(b, a) - 50.0) < 0.01, "La opinión es simétrica: %d" % int(d.opinion_de(a, b)))
	ok(String(d.razones_de(a, b)[0][0]) == "prueba", "Se guarda la razón del cambio")
	m.ia.dia_n += 250
	ok(absf(d.opinion_de(a, b) - 40.0) < 0.5, "Se olvida a 1 punto cada 25 días: tras 250 días queda %.1f" % d.opinion_de(a, b))
	d.cambiar_opinion(a, b, 500.0)
	ok(d.opinion_de(a, b) == 100.0, "Tope de +100")
	d.cambiar_opinion(a, b, -900.0)
	ok(d.opinion_de(a, b) == -100.0, "Tope de −100")
	ok(d.etiqueta_opinion(70.0) == "Entrañable" and d.etiqueta_opinion(30.0) == "Amistosa" and d.etiqueta_opinion(0.0) == "Neutral" and d.etiqueta_opinion(-30.0) == "Hostil" and d.etiqueta_opinion(-90.0) == "Enemiga", "Etiquetas de opinión")
	for k in 6:
		d.cambiar_opinion(a, b, 1.0, "razón %d" % k)
	ok(d.razones_de(a, b).size() == d.MAX_RAZONES, "Solo se guardan las últimas %d razones" % d.MAX_RAZONES)
	ok(d.texto_relacion(a, b).find("(") > 0, "texto_relacion: «%s»" % d.texto_relacion(a, b))


func t_alianzas() -> void:
	var d = m.diplomacia
	var par := elegir_con_vecinos(4)
	var a: int = tid(par[0])
	var vs: Array = par[1]
	limpiar()
	ok(vs.size() >= 3, "País de prueba con %d vecinos con IA" % vs.size())
	var b: int = tid(vs[0])
	var c: int = tid(vs[1])
	var e: int = tid(vs[2])
	ok(not bool(d.evaluar_alianza(a, b)["acepta"]), "Sin opinión suficiente la IA no se alía (%s)" % String(d.evaluar_alianza(a, b)["motivo"]).substr(0, 40))
	d.cambiar_opinion(a, b, 60.0)
	ok(bool(d.evaluar_alianza(a, b)["acepta"]), "Con opinión ≥ 25 acepta")
	ok(d.formar_alianza(a, b), "formar_alianza → true")
	ok(d.son_aliados(a, b) and d.son_aliados(b, a) and d.aliados_de(a).has(b), "Son aliados en ambos sentidos")
	ok(m.relacionados_de(nom(a)).has(nom(b)) and m.relacionados_de(nom(b)).has(nom(a)), "Mundo.relacionados_de devuelve a los aliados (sus tropas se ven en el mapa)")
	ok(m.rival_por_entrar(a, int(m.paises[nom(b)].provincias[0])) == -1, "Un aliado puede entrar en tu territorio sin declarar la guerra")
	ok(not d.formar_alianza(a, b) and d.motivo_sin_alianza(a, b) == "Ya son aliados.", "No se puede repetir la alianza")
	ok(d.opinion_total(a, b) > d.opinion_de(a, b), "La alianza suma a la opinión total (+20)")
	d.cambiar_opinion(a, c, 60.0)
	d.cambiar_opinion(a, e, 60.0)
	ok(d.formar_alianza(a, c) and d.formar_alianza(a, e), "Segunda y tercera alianza")
	var cuarto := ""
	for n in m.ia.activas:
		var t: int = tid(String(n))
		if t != a and not d.son_aliados(a, t) and (d._aliados.get(t, {}) as Dictionary).size() < d.MAX_ALIADOS:
			cuarto = String(n)
			break
	d.cambiar_opinion(a, tid(cuarto), 60.0)
	ok(d.motivo_sin_alianza(a, tid(cuarto)) != "" and not d.formar_alianza(a, tid(cuarto)), "Máximo %d aliados por país" % d.MAX_ALIADOS)
	# rival
	ok(d.declarar_rival(a, c), "declarar_rival → true")
	ok(not d.son_aliados(a, c), "Declarar rival a un aliado rompe la alianza")
	ok(d.rival_de(a) == c and d.es_rival(c, a), "rival_de y es_rival (en ambos sentidos)")
	ok(d.motivo_sin_alianza(a, c).find("rivalidad") >= 0, "Un rival no puede ser aliado")
	ok(d.opinion_total(a, c) <= d.opinion_de(a, c) - 25.0 + 0.01, "La rivalidad resta 25 a la opinión total")
	m.ia.dia_n += d.RIVAL_DIAS + 5
	ok(d.rival_de(a) == -1, "La rivalidad caduca a los 10 años")
	d.romper_alianza(a, b, "prueba")
	ok(not d.son_aliados(a, b) and not d.aliados_de(a).has(b), "romper_alianza")
	# regalo
	m.fijar_jugador(nom(a))
	var op0: float = d.opinion_de(a, b)
	var res: Dictionary = d.regalar(a, b)
	ok(bool(res["ok"]) and d.opinion_de(a, b) > op0, "Un regalo mejora la opinión: %s" % String(res["msg"]).substr(0, 40))
	m.paises[nom(a)].tesoreria = 0.0
	ok(not bool(d.regalar(a, b)["ok"]), "Sin caja no hay regalo")
	m.fijar_jugador("")
	m.ia.activar(nom(a))


func t_llamadas() -> void:
	var d = m.diplomacia
	var par := elegir_con_vecinos(3)
	var vs: Array = par[1]
	limpiar()
	var a: int = tid(par[0])                 # a es aliado de b; x ataca a b
	var b: int = tid(vs[0])
	var x: int = tid(vs[1])
	d.cambiar_opinion(a, b, 60.0)
	d.formar_alianza(a, b)
	var o_a_b: float = d.opinion_de(a, b)
	m.guerra.declarar(x, b, "Prueba")
	ok(d.llamados.size() >= 1 and int(d.llamados[0]["aliado"]) == a and int(d.llamados[0]["ayuda_a"]) == b and int(d.llamados[0]["contra"]) == x, "Atacar a un aliado genera una llamada para el otro (%d pendientes)" % d.llamados.size())
	# la IA con pocos soldados no acude: opinión −35 y la alianza se rompe
	var sold := {}
	for n in m.paises:
		sold[tid(String(n))] = 100000
	sold[a] = 500
	fijar_soldados(sold)
	d.fase_dia()
	ok(not d.son_aliados(a, b) and d.llamadas_rechazadas == 1, "Si el aliado no puede acudir, la alianza se rompe")
	ok(d.opinion_de(a, b) < o_a_b - 30.0, "… y la opinión cae 35 (de %d a %d)" % [int(o_a_b), int(d.opinion_de(a, b))])
	# acude: declara la guerra «Alianza con …» sin infamia
	limpiar()
	d.cambiar_opinion(a, b, 60.0)
	d.formar_alianza(a, b)
	d.cambiar_opinion(a, x, 0.0)
	m.guerra.declarar(x, b, "Prueba")
	var inf_a: float = d.infamia(a)
	d.responder_llamado(a, b, x, true)
	ok(m.guerra.en_guerra(a, x) and d.llamadas_atendidas == 1, "Acudir a la llamada declara la guerra al atacante de su aliado")
	ok(is_equal_approx(d.infamia(a), inf_a), "Acudir a una alianza no es agresión: sin infamia")
	ok(d.son_aliados(a, b), "… y la alianza sigue en pie")
	# llamada con IA que sí puede (soldados, opinión, IA activa)
	limpiar()
	d.cambiar_opinion(a, b, 60.0)
	d.formar_alianza(a, b)
	sold[a] = 50000
	fijar_soldados(sold)
	m.guerra.declarar(x, b, "Prueba")
	d.fase_dia()
	ok(m.guerra.en_guerra(a, x), "La IA aliada con fuerzas acude sola a la guerra")
	# el jugador recibe un aviso
	limpiar()
	m.fijar_jugador(nom(a))
	d.cambiar_opinion(a, b, 60.0)
	d.formar_alianza(a, b)
	m.guerra.declarar(x, b, "Prueba")
	d.fase_dia()
	var hay := false
	for av in m.avisos:
		if String(av["tipo"]) == "llamado" and int(av["aliado"]) == a:
			hay = true
	ok(hay, "Si el aliado es el jugador se abre un aviso «llamado» (no decide solo)")
	m.fijar_jugador("")
	m.ia.activar(nom(a))
	m.avisos.clear()


func t_infamia() -> void:
	var d = m.diplomacia
	var par := elegir_con_vecinos(2)
	var a: int = tid(par[0])
	var b: int = tid(par[1][0])
	limpiar()
	ok(d.infamia(a) == 0.0, "Empieza sin infamia")
	d.al_cambiar_dueno(int(m.paises[nom(b)].provincias[0]), b, a, "Paz con prueba")
	ok(d.infamia(a) >= d.INFAMIA_PESO_MIN - 0.001 and d.infamia(a) <= 2.0 * d.INFAMIA_PESO_MAX + 0.001, "Quedarse una provincia por la fuerza suma infamia según su población (%.2f)" % d.infamia(a))
	var antes: float = d.infamia(a)
	d.al_cambiar_dueno(int(m.paises[nom(b)].provincias[0]), b, a, "Debug: transferencia")
	ok(is_equal_approx(d.infamia(a), antes), "Una transferencia que no es conquista no suma")
	m.ia.dia_n += int(d.INFAMIA_VIDA_MEDIA)
	ok(absf(d.infamia(a) - antes * 0.5) < 0.01, "La infamia se reduce a la mitad en %d días" % int(d.INFAMIA_VIDA_MEDIA))
	limpiar()
	# declarar la guerra
	m.guerra.declarar(a, b, "Prueba")
	ok(d.opinion_de(a, b) <= -59.0, "Declarar la guerra: opinión −60 (%d)" % int(d.opinion_de(a, b)))
	ok(is_equal_approx(d.infamia(a), 1.0), "Agresión sin motivo: +1 de infamia")
	limpiar()
	d.cambiar_opinion(a, b, 60.0)
	d.formar_alianza(a, b)
	m.guerra.declarar(a, b, "Prueba")
	ok(not d.son_aliados(a, b) and is_equal_approx(d.infamia(a), 5.0), "Atacar a un aliado: se rompe la alianza y +5 de infamia")
	limpiar()
	m.ia.tregua[m.guerra.clave_par(a, b)] = m.ia.dia_n + 200
	m.guerra.declarar(a, b, "Prueba")
	ok(is_equal_approx(d.infamia(a), 2.5), "Romper una tregua: +2,5")
	limpiar()
	d.cambiar_opinion(a, b, 10.0)
	d.sumar_infamia(b, 10.0)
	ok(d.opinion_total(a, b) < d.opinion_de(a, b) - 25.0, "La infamia del otro resta a la opinión total (hasta −40): %d" % int(d.opinion_total(a, b)))
	limpiar()


func t_coalicion() -> void:
	var d = m.diplomacia
	var par := elegir_con_vecinos(3)
	var t: int = tid(par[0])
	var vs: Array = par[1]
	limpiar()
	var sold := {}
	for n in m.paises:
		sold[tid(String(n))] = 20000
	fijar_soldados(sold)
	d.sumar_infamia(t, d.INFAMIA_COALICION + 1.0)
	ok(d.infames.has(t), "Con %d de infamia entra en la lista de países infames" % int(d.INFAMIA_COALICION))
	m.ia.dia_n += d.DIAS_REVISION + 1
	fijar_soldados(sold)
	d.fase_dia()
	ok(d.coaliciones.has(t), "La revisión forma una coalición contra él (%d miembros)" % (d.coaliciones[t]["miembros"].size() if d.coaliciones.has(t) else 0))
	var miembros: Array = d.coaliciones[t]["miembros"] if d.coaliciones.has(t) else []
	ok(miembros.size() >= d.COALICION_MIN and miembros.size() <= d.MAX_MIEMBROS, "Entre %d y %d miembros" % [d.COALICION_MIN, d.MAX_MIEMBROS])
	var todos_vecinos := true
	for mt in miembros:
		if not vs.has(nom(int(mt))):
			todos_vecinos = false
	ok(todos_vecinos and not miembros.has(t), "Solo entran vecinos con IA, nunca el propio objetivo")
	ok(d.en_coalicion_contra(int(miembros[0]), t) and d.objetivo_coalicion_de(int(miembros[0])) == t, "en_coalicion_contra y objetivo_coalicion_de")
	ok(d.opinion_total(int(miembros[0]), t) <= -20.0, "Los miembros lo ven mal (%d)" % int(d.opinion_total(int(miembros[0]), t)))
	ok(d.fuerza_coalicion(t, int(miembros[0])) >= 20000 * (miembros.size() - 1), "fuerza_coalicion suma a los demás miembros (%d)" % d.fuerza_coalicion(t, int(miembros[0])))
	var n_coal: int = d.coaliciones_formadas
	m.ia.dia_n += d.DIAS_REVISION + 1
	d.fase_dia()
	ok(d.coaliciones_formadas == n_coal, "No se forma otra coalición mientras existe esa")
	# la coalición ataca: un miembro declara la guerra al objetivo con la causa de la coalición
	var miembro: int = int(miembros[0])
	var nm: String = nom(miembro)
	m.ia.activas[nm]["no_guerra_hasta"] = 0
	var st: Dictionary = m.ia.activas[nm]
	var eco := {"ing": 1000.0, "sold": 20000, "mant": 100.0, "dias_caja": 100.0, "mps": 0.01, "cps": 1.0, "pob": 1.0e6, "tes": 1.0e6}
	for k in 400:
		if m.guerra.en_guerra(miembro, t):
			break
		m.ia._buscar_guerra(nm, st, m.paises[nm], miembro, eco, m.guerra.rivales_de(miembro), 1000000)
	ok(m.guerra.en_guerra(miembro, t), "Un miembro de la coalición le declara la guerra a su objetivo")
	var causa := ""
	for gid in m.guerra.guerras_de(miembro):
		causa = String(m.bd.txt("guerra_causa", int(gid), ""))
	ok(causa.begins_with("Coalición"), "Causa registrada: «%s»" % causa)
	# se disuelve cuando la infamia baja
	m.ia.dia_n += int(d.INFAMIA_VIDA_MEDIA) * 3
	m.ia.dia_n += d.DIAS_REVISION + 1
	d.fase_dia()
	ok(not d.coaliciones.has(t) and not d.infames.has(t), "Con la infamia por debajo de %d la coalición se disuelve" % int(d.INFAMIA_FIN))
	limpiar()


# ═════════════ IA con consecuencias ═════════════
func intentar_guerra(a: int, intentos := 120, ratio_alto := true) -> int:
	var d = m.diplomacia
	var nm: String = nom(a)
	var st: Dictionary = m.ia.activas[nm]
	var eco := {"ing": 1000.0, "sold": 100000, "mant": 100.0, "dias_caja": 100.0, "mps": 0.01, "cps": 1.0, "pob": 1.0e6, "tes": 1.0e6}
	var antes: int = m.ia.guerras_declaradas
	for k in intentos:
		st["no_guerra_hasta"] = 0
		m.ia._buscar_guerra(nm, st, m.paises[nm], a, eco, m.guerra.rivales_de(a), 1000000)
		if m.guerra.rivales_de(a).size() > 0:
			break
	return m.ia.guerras_declaradas - antes


func t_ia() -> void:
	var d = m.diplomacia
	var par := elegir_con_vecinos(2)
	var a: int = tid(par[0])
	var vs: Array = par[1]
	var sold := {}
	for n in m.paises:
		sold[tid(String(n))] = 1000
	sold[a] = 100000
	# control: sin nada que lo frene, ataca a algún vecino más débil
	limpiar()
	fijar_soldados(sold)
	m.estabilidad._res_cache.clear()
	ok(intentar_guerra(a) == 1, "Control: un país fuerte con vecinos débiles y sin freno declara una guerra")
	# amigos no se atacan
	limpiar()
	for v in vs:
		d.cambiar_opinion(a, tid(String(v)), 90.0)
	fijar_soldados(sold)
	ok(intentar_guerra(a) == 0, "Con opinión ≥ %d de todos sus vecinos no ataca a ninguno" % int(d.OP_AMIGOS))
	# aliados tampoco
	limpiar()
	var b: int = tid(String(vs[0]))
	d.cambiar_opinion(a, b, 60.0)
	d.formar_alianza(a, b)
	fijar_soldados(sold)
	var n_ataq := 0
	for k in 40:
		limpiar()
		d.cambiar_opinion(a, b, 60.0)
		d.formar_alianza(a, b)
		fijar_soldados(sold)
		intentar_guerra(a, 3)
		if m.guerra.en_guerra(a, b):
			n_ataq += 1
	ok(n_ataq == 0, "Nunca ataca a su aliado (40 intentos)")
	# infamia: se frena
	limpiar()
	d.sumar_infamia(a, d.INFAMIA_PRUDENTE + 1.0)
	fijar_soldados(sold)
	ok(intentar_guerra(a) == 0, "Con infamia ≥ %d deja de agredir por su cuenta" % int(d.INFAMIA_PRUDENTE))
	# pero va contra su rival
	var r: int = tid(String(vs[0]))
	d.declarar_rival(a, r)
	fijar_soldados(sold)
	ok(intentar_guerra(a) == 1 and m.guerra.en_guerra(a, r), "… pero sí contra su rival declarado")
	var causa := ""
	for gid in m.guerra.guerras_de(a):
		causa = String(m.bd.txt("guerra_causa", int(gid), ""))
	ok(causa.begins_with("Rivalidad"), "Causa: «%s»" % causa)
	# inestabilidad: se frena
	limpiar()
	var fa: PackedFloat64Array = m.bd.vars["favorabilidad"].col_f
	var guardadas := {}
	for pi in m.paises[nom(a)].provincias:
		var ix: int = m.provincias[int(pi)].ix
		guardadas[ix] = fa[ix]
		fa[ix] = 10.0
	m.estabilidad._res_cache.clear()
	fijar_soldados(sold)
	ok(intentar_guerra(a) == 0, "Con casi todas sus provincias agitadas no se mete en guerras")
	for ix in guardadas:
		fa[ix] = guardadas[ix]
	m.estabilidad._res_cache.clear()
	# consolidación tras una paz con provincias
	limpiar()
	fijar_soldados(sold)
	var st: Dictionary = m.ia.activas[nom(a)]
	var rv: int = tid(String(vs[0]))
	m.guerra.declarar(a, rv, "Prueba")
	var oc: int = int(m.paises[nom(rv)].provincias[0])
	m.bd.poner_i("ocupante", m.provincias[oc].tid, a, "Prueba")
	st["ini"][rv] = m.ia.dia_n - 200
	var dia0: int = m.ia.dia_n
	m.ia._paz(nom(a), st, a, m.guerra.rivales_de(a))
	ok(not m.guerra.en_guerra(a, rv), "La IA con ventaja cobra la paz")
	ok(int(st["no_guerra_hasta"]) >= dia0 + 30 + m.ia.CONSOLIDA_DIAS_PROV, "Tras quedarse provincias descansa para digerirlas (hasta el día +%d)" % (int(st["no_guerra_hasta"]) - dia0))
	limpiar()


func t_relaciones_ia() -> void:
	var d = m.diplomacia
	var par := elegir_con_vecinos(2)
	var nm: String = par[0]
	var a: int = tid(nm)
	limpiar()
	var st: Dictionary = m.ia.activas[nm]
	st["sociable"] = true
	var op0 := {}
	for v in par[1]:
		op0[String(v)] = d.opinion_de(a, tid(String(v)))
	m.ia._diplomacia(nm, st, a, [])
	var sube := 0
	for v in par[1]:
		if d.opinion_de(a, tid(String(v))) > float(op0[String(v)]):
			sube += 1
	ok(sube >= 1, "Una IA sociable se acerca a sus vecinos pacíficos (+%d de opinión en %d)" % [int(m.ia.BUENA_VECINDAD), sube])
	ok(int(st["prox_dip"]) > m.ia.dia_n + m.ia.DIAS_DIPLOMACIA - 1, "Programa su próxima revisión de relaciones")
	# sin amigos no hay alianza; con un vecino de 60 de opinión la propone y se firma
	limpiar()
	var b: int = tid(String(par[1][0]))
	d.cambiar_opinion(a, b, 70.0)
	d.cambiar_opinion(b, a, 70.0)
	var sold := {}
	for n in m.paises:
		sold[tid(String(n))] = 5000
	fijar_soldados(sold)
	for k in 6:
		st["prox_dip"] = 0
		m.ia._diplomacia(nm, st, a, [])
		if d.son_aliados(a, b):
			break
	var hay_alianza: bool = d.aliados_de(a).size() >= 1
	ok(hay_alianza, "Una IA con un vecino que la quiere (opinión 70) acaba firmando una alianza")
	# rival: elige al vecino más temible
	limpiar()
	d.sumar_infamia(tid(String(par[1][0])), 6.0)
	st["prox_dip"] = 0
	m.ia._diplomacia(nm, st, a, [])
	ok(d.rival_de(a) >= 0, "Elige como rival a un vecino infame o mucho más fuerte")
	limpiar()


# ═════════════ Estabilidad ═════════════
func t_estabilidad_meta() -> void:
	var e = m.estabilidad
	var nm := "Imperio romano"
	var t: int = tid(nm)
	var f: Dictionary = e._info_pais(t)
	var cap: int = int(f["cap"])
	ok(cap >= 0, "Roma tiene una provincia capital (%s)" % (m.provincias[cap].nombre if cap >= 0 else "—"))
	var ds: Dictionary = e.desglose(cap)
	var tiene_cap := false
	for p in ds["partes"]:
		if String(p[0]) == "Es la capital":
			tiene_cap = true
	ok(tiene_cap and float(ds["meta"]) > 50.0, "La capital suma +10 (meta %.0f)" % float(ds["meta"]))
	# una provincia cualquiera del país, lejos de la capital
	var otra := -1
	for pi in m.paises[nm].provincias:
		if int(pi) != cap:
			otra = int(pi)
			break
	var ds0: Dictionary = e.desglose(otra)
	e.conquistada[otra] = m.ia.dia_n
	var ds1: Dictionary = e.desglose(otra)
	ok(float(ds1["meta"]) < float(ds0["meta"]) - 15.0, "Una conquista reciente resta hasta 20 (de %.0f a %.0f)" % [float(ds0["meta"]), float(ds1["meta"])])
	m.ia.dia_n += 5 * 365 + 1
	var ds2: Dictionary = e.desglose(otra)
	ok(absf(float(ds2["meta"]) - float(ds0["meta"])) < 0.01, "… y se disipa del todo en 5 años")
	e.conquistada.erase(otra)
	var base0: int = int(f["base"])
	f["base"] = maxi(int(base0 / 3), 1)
	var ds3: Dictionary = e.desglose(otra)
	ok(float(ds3["meta"]) < float(ds0["meta"]) - 10.0, "La sobreextensión (3 × el tamaño de partida) resta mucho (de %.0f a %.0f)" % [float(ds0["meta"]), float(ds3["meta"])])
	f["base"] = base0
	ok(e.nivel(70.0) == "Leal" and e.nivel(45.0) == "Estable" and e.nivel(30.0) == "Descontenta" and e.nivel(20.0) == "Agitada" and e.nivel(5.0) == "En revuelta", "Niveles de estabilidad")
	# tierra de otro país y cultura
	var ajena := -1
	for pi in m.paises[nm].provincias:
		if m.cores.relacion(int(pi)) == "ajena":
			ajena = int(pi)
			break
	ok(true, "(tierra ajena en 1 d. C. al empezar: %s)" % ("sí" if ajena >= 0 else "ninguna"))
	m.cores.fijar_nacional(otra, "Dinastía Han")
	var ds4: Dictionary = e.desglose(otra)
	var tiene_ajena := false
	for p in ds4["partes"]:
		if String(p[0]).begins_with("Tierra de otro país"):
			tiene_ajena = true
	ok(tiene_ajena and float(ds4["meta"]) < float(ds0["meta"]) - 8.0, "Una provincia que es core de otro país resta 11 respecto a una propia")
	m.cores.restaurar(otra)


func t_estabilidad_ciclo() -> void:
	var e = m.estabilidad
	var fa: PackedFloat64Array = m.bd.vars["favorabilidad"].col_f
	for pr in m.provincias:
		fa[pr.ix] = 50.0
	e.revisadas = 0
	var nm := "Imperio romano"
	var pi: int = int(m.paises[nm].provincias[0])
	e._preparar()
	var n_act: int = e._activas.size()
	fa[m.provincias[pi].ix] = 0.0
	var antes := {}
	for q in e._activas:
		antes[q] = fa[m.provincias[q].ix]
	e._cursor = 0
	var t0 := Time.get_ticks_usec()
	var llamadas := 0
	var pasos := 0
	# un paso de 30 días: las revisa todas una vez, por lotes
	while true:
		llamadas += 1
		if not e.fase_dia(30):
			break
	pasos = llamadas
	ok(e.revisadas == n_act, "30 días revisan cada provincia exactamente una vez (%d de %d) en %d llamadas por lotes" % [e.revisadas, n_act, llamadas])
	ok(llamadas >= int(ceil(float(n_act) / float(e.LOTE))), "El trabajo se reparte en lotes de %d" % e.LOTE)
	var max_paso := 0.0
	for q in e._activas:
		max_paso = maxf(max_paso, absf(fa[m.provincias[q].ix] - float(antes[q])))
	ok(max_paso <= e.PASO_MAX + 0.001, "Ninguna provincia se mueve más de %d puntos por ciclo (máx. %.2f)" % [int(e.PASO_MAX), max_paso])
	ok(fa[m.provincias[pi].ix] >= 4.99 and fa[m.provincias[pi].ix] <= 5.01, "Una provincia en 0 con meta alta sube exactamente %d (%.2f)" % [int(e.PASO_MAX), fa[m.provincias[pi].ix]])
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	ok(ms < 1500.0, "Un ciclo completo (%d provincias) cuesta %.0f ms en total" % [n_act, ms])
	ok(e.ms_max < 25.0, "La llamada más cara de un lote cuesta %.1f ms" % e.ms_max)
	# un paso de un día reparte 1/30
	e.revisadas = 0
	while e.fase_dia(1):
		pass
	ok(absf(float(e.revisadas) - float(n_act) / 30.0) <= 1.5, "Un día revisa 1/30 del total (%d de %d)" % [e.revisadas, n_act])
	# equilibrio de producción: la media del mundo no se desmadra
	var suma := 0.0
	for pr in m.provincias:
		suma += pr.favorabilidad
	ok(suma / float(m.provincias.size()) > 40.0, "La estabilidad media del mundo es razonable (%.1f)" % (suma / float(m.provincias.size())))
	for pr in m.provincias:
		fa[pr.ix] = 50.0


func t_motin() -> void:
	var e = m.estabilidad
	var d = m.diplomacia
	limpiar()
	m.fijar_jugador("")
	var fa: PackedFloat64Array = m.bd.vars["favorabilidad"].col_f
	var col_d: PackedInt32Array = m.bd.vars["propietario"].col_i
	# provincia de Roma que es tierra de un país vecino con IA (core de otro): pasa a Roma «por conquista»
	var roma := "Imperio romano"
	var vict := ""
	for v in m.ia.vecinos_de(roma):
		if int((m.paises[v].provincias as Array).size()) >= 3 and m.paises[v].inerte == false:
			vict = String(v)
			break
	var pi0 := -1
	var pi1 := -1
	for p in m.paises[vict].provincias:
		for v in m.ejercito.red.vecinos(int(p)):
			if m.provincias[int(v)].pais == vict and not m.excluidas.has(int(v)):
				pi0 = int(p)
				pi1 = int(v)
				break
		if pi0 >= 0:
			break
	ok(pi0 >= 0, "Hay dos provincias vecinas de %s para el grupo" % vict)
	var fecha: String = m.bd.fecha_texto(m.bd.fecha)
	ok(m.transferir_provincia(pi0, roma, fecha, "Paz con prueba") and m.transferir_provincia(pi1, roma, fecha, "Paz con prueba"), "Dos provincias de %s pasan a Roma por conquista" % vict)
	ok(e.conquistada.has(pi0) and e.conquistada.has(pi1), "Quedan marcadas como conquistadas")
	ok(m.cores.nacional(pi0) == vict, "Su core nacional sigue siendo %s" % vict)
	# 1) concede: Roma sin caja y sin tropas cerca
	m.paises[roma].tesoreria = 0.0
	for q in [pi0, pi1]:
		fa[m.provincias[q].ix] = 3.0
		e._malos[q] = 1
		e._inmune.erase(q)
	var m0: int = e.motines
	var i0: int = e.independencias
	e._evaluar(pi0, m.ia.dia_n, fa, col_d)
	ok(e.motines == m0 + 1, "Dos ciclos por debajo de %d: la provincia se amotina" % int(e.UMBRAL_REVUELTA))
	var op := ["pagos", "represiones", "independencias", "sin_estado"]
	ok(e.independencias == i0 + 1 and m.provincias[pi0].pais == vict, "Sin caja ni tropas la IA concede: %s vuelve a %s" % [m.provincias[pi0].nombre, vict])
	ok(m.provincias[pi0].favorabilidad >= 59.9, "La tierra liberada empieza con estabilidad 60")
	ok(not e.conquistada.has(pi0), "La conquista deja de contar al independizarse")
	ok(d.opinion_de(tid(roma), tid(vict)) < 0.0, "Roma pierde opinión con quien se llevó la tierra")
	# el grupo: la vecina del mismo pueblo también estaba agitada y se fue con ella
	ok(m.provincias[pi1].pais == vict, "El movimiento arrastra a la vecina agitada del mismo pueblo (%s)" % m.provincias[pi1].nombre)
	# 2) paga: caja grande
	m.transferir_provincia(pi0, roma, fecha, "Paz con prueba")
	m.paises[roma].tesoreria = 1.0e15
	fa[m.provincias[pi0].ix] = 3.0
	var av := {"tipo": "revuelta", "pais": tid(roma), "provincias": [pi0], "reino": tid(vict), "pago_usd": 1000.0, "fuerza_necesaria": 1500.0, "fuerza_disponible": 0.0}
	var p0: int = e.pagos
	var res: Dictionary = e.resolver_revuelta(av, "pagar")
	ok(bool(res["ok"]) and e.pagos == p0 + 1 and fa[m.provincias[pi0].ix] >= 24.9, "Pagar a los notables: estabilidad +22 y una racha de calma (%.0f)" % fa[m.provincias[pi0].ix])
	ok(int(e._inmune.get(pi0, 0)) > m.ia.dia_n + 300, "… un año sin motines")
	e._inmune.erase(pi0)
	m.paises[roma].tesoreria = 0.0
	ok(not bool(e.resolver_revuelta(av, "pagar")["ok"]), "Sin caja no se puede pagar")
	# 3) reprime
	av["fuerza_disponible"] = 1.0e9
	var r0: int = e.represiones
	var dev0: float = m.provincias[pi0].devastacion
	var inf0: float = d.infamia(tid(roma))
	res = e.resolver_revuelta(av, "reprimir")
	ok(bool(res["ok"]) and e.represiones == r0 + 1 and m.provincias[pi0].devastacion > dev0 and d.infamia(tid(roma)) > inf0, "Reprimir: +12 de estabilidad, la tierra queda devastada y se gana infamia")
	av["fuerza_disponible"] = 0.0
	ok(not bool(e.resolver_revuelta(av, "reprimir")["ok"]), "Sin tropas suficientes no se puede reprimir")
	# 4) sin Estado al que volver
	var av2 := av.duplicate()
	av2["reino"] = -1
	var s0: int = e.sin_estado
	var dev1: float = m.provincias[pi0].devastacion
	res = e.resolver_revuelta(av2, "ignorar")
	ok(e.sin_estado == s0 + 1 and m.provincias[pi0].devastacion > dev1 + 0.19 and m.provincias[pi0].pais == roma, "Sin Estado al que volver los rebeldes saquean (devastación +0,2) y la tierra no cambia de dueño")
	# 5) el motín se encarece al repetirse
	var rica := pi0
	var mejor := -1.0
	for q in m.paises[roma].provincias:
		var ing: float = m.provincias[int(q)].ingreso_efectivo_usd()
		if ing > mejor:
			mejor = ing
			rica = int(q)
	e._veces.erase(rica)
	var d1: Dictionary = e._datos_revuelta(tid(roma), [rica], tid(vict))
	e._veces[rica] = 3
	var d2: Dictionary = e._datos_revuelta(tid(roma), [rica], tid(vict))
	ok(float(d2["pago_usd"]) > float(d1["pago_usd"]) * 2.5, "Cada motín repetido encarece el siguiente (%.0f → %.0f)" % [float(d1["pago_usd"]), float(d2["pago_usd"])])
	# 6) el jugador recibe un aviso
	e._veces.clear()
	m.fijar_jugador(roma)
	fa[m.provincias[pi0].ix] = 3.0
	e._malos[pi0] = 1
	e._inmune.erase(pi0)
	m.avisos.clear()
	e._evaluar(pi0, m.ia.dia_n, fa, col_d)
	var aviso_ok := false
	for a in m.avisos:
		if String(a["tipo"]) == "revuelta" and int(a["pais"]) == tid(roma) and (a["provincias"] as Array).has(pi0):
			aviso_ok = true
	ok(aviso_ok, "Si la provincia es del jugador se abre un aviso «revuelta» (no se resuelve sola)")
	ok(m.provincias[pi0].pais == roma, "… y mientras no responde, la tierra sigue siendo suya")
	m.avisos.clear()
	m.fijar_jugador("")
	# renacer: un país anexado revive si su tierra se independiza
	var nm_ex: String = vict
	var lista: Array = (m.paises[nm_ex].provincias as Array).duplicate()
	m.anexar_pais(nm_ex, roma, fecha, "Anexión de prueba")
	ok(m.paises[nm_ex].provincias.is_empty() and m.paises[nm_ex].anexado_a == roma, "%s queda anexado a Roma" % nm_ex)
	var p_re: int = int(lista[0])
	fa[m.provincias[p_re].ix] = 3.0
	var av3 := {"tipo": "revuelta", "pais": tid(roma), "provincias": [p_re], "reino": tid(nm_ex), "pago_usd": 1.0, "fuerza_necesaria": 1.0e12, "fuerza_disponible": 0.0}
	e.resolver_revuelta(av3, "conceder")
	ok(m.paises[nm_ex].anexado_a == "" and not m.paises[nm_ex].provincias.is_empty(), "El país anexado renace con la tierra que se independiza")
	ok(m.ia.activas.has(nm_ex), "… y como el mundo tiene IA, el país que renace piensa por sí mismo")
	limpiar()


# ═════════════ Pop-ups, pestaña Diplomacia y ficha ═════════════
func t_popups() -> void:
	var d = m.diplomacia
	limpiar()
	var roma := "Imperio romano"
	var jt: int = tid(roma)
	m.fijar_jugador(roma)
	var vs: Array = m.ia.vecinos_de(roma).filter(func(x): return m.ia.activas.has(String(x)))
	var otro: int = tid(String(vs[0]))
	# alianza propuesta por una IA
	d.cambiar_opinion(jt, otro, 60.0)
	m.avisos.append({"tipo": "alianza", "ia": otro, "jugador": jt})
	main._procesar_avisos()
	ok(main.popup_guerra != null and main.popup_guerra.abierto and main.popup_guerra.tipo == "alianza", "El aviso «alianza» abre su pop-up y pausa")
	ok(main.reloj.velocidad == 0, "… el tiempo queda en pausa")
	main.popup_guerra._responder_alianza(true)
	ok(d.son_aliados(jt, otro) and not main.popup_guerra.abierto, "Aceptar firma la alianza y cierra")
	d.romper_alianza(jt, otro)
	m.avisos.append({"tipo": "alianza", "ia": otro, "jugador": jt})
	main._procesar_avisos()
	var op_antes: float = d.opinion_de(jt, otro)
	main.popup_guerra._responder_alianza(false)
	ok(not d.son_aliados(jt, otro) and d.opinion_de(jt, otro) < op_antes - 4.0, "Rechazar baja 5 puntos la opinión (de %d a %d)" % [int(op_antes), int(d.opinion_de(jt, otro))])
	# llamada
	d.cambiar_opinion(jt, otro, 60.0)
	d.formar_alianza(jt, otro)
	var x: int = tid(String(vs[1]))
	m.guerra.declarar(x, otro, "Prueba")
	m.avisos.clear()
	m.avisos.append({"tipo": "llamado", "aliado": jt, "ayuda_a": otro, "contra": x})
	main._procesar_avisos()
	ok(main.popup_guerra.abierto and main.popup_guerra.tipo == "llamado", "El aviso «llamado» abre su pop-up")
	main.popup_guerra._responder_llamado(true)
	ok(m.guerra.en_guerra(jt, x), "Entrar declara la guerra al atacante")
	# coalición contra el jugador: aviso sin pausa
	m.avisos.clear()
	m.avisos.append({"tipo": "coalicion", "objetivo": jt, "miembros": [otro], "texto": "Coalición contra Roma (prueba)."})
	main._procesar_avisos()
	ok(not main.popup_guerra.abierto and main.avisos.ultimo_texto.find("Coalición") >= 0, "El aviso «coalición» no pausa: sale como aviso rojo")
	# revuelta
	limpiar()
	var pi: int = int(m.paises[roma].provincias[0])
	m.avisos.append({"tipo": "revuelta", "pais": jt, "provincias": [pi], "reino": otro, "pago_usd": 1000.0, "fuerza_necesaria": 1500.0, "fuerza_disponible": 10.0})
	main._procesar_avisos()
	ok(main.popup_guerra.abierto and main.popup_guerra.tipo == "revuelta", "El aviso «revuelta» abre su pop-up")
	var botones := 0
	var deshab := 0
	var pila: Array = [main.popup_guerra.cuerpo]
	while not pila.is_empty():
		var n = pila.pop_back()
		for h in n.get_children():
			if h is Button:
				botones += 1
				if (h as Button).disabled:
					deshab += 1
			pila.append(h)
	ok(botones == 4, "Cuatro respuestas: pagar, reprimir, conceder, ignorar (%d botones)" % botones)
	ok(deshab == 1, "«Reprimir» está apagado porque faltan tropas (%d apagados)" % deshab)
	m.paises[roma].tesoreria = 1.0e15
	main.popup_guerra._resolver_revuelta("pagar")
	ok(not main.popup_guerra.abierto, "Responder cierra el pop-up")
	m.paises[roma].tesoreria = 0.0
	main.popup_guerra.cerrar("reanudar")
	m.fijar_jugador("")
	limpiar()


func t_hud() -> void:
	var roma := "Imperio romano"
	var jug := "Dinastía Han"
	m.fijar_jugador(jug)
	main._seleccion_pais(roma, "Europa", Vector2(700, 300))
	await esperar(0.2)
	var v: Dictionary = main.diplomacia_vista()
	var r: Dictionary = v["relaciones"]
	ok(r.has("texto") and r.has("lectura") and r.has("puede_aliarse") and r.has("infamia"), "diplomacia_vista trae las relaciones con el país elegido")
	main.hud.abrir_pestana("diplomacia")
	await esperar(0.2)
	var textos := ""
	var pila: Array = [main.hud.panel]
	while not pila.is_empty():
		var n = pila.pop_back()
		if n is Label:
			textos += (n as Label).text + "\n"
		if n is Button:
			textos += "[" + (n as Button).text + "]\n"
		for h in n.get_children():
			pila.append(h)
	textos = textos.to_upper()
	ok(textos.find("RELACIONES INTERNACIONALES") >= 0 and textos.find("INFAMIA") >= 0, "La pestaña Diplomacia muestra «Relaciones internacionales» e Infamia")
	ok(textos.find("[PROPONER UNA ALIANZA]") >= 0 and textos.find("[DECLARAR RIVAL]") >= 0 and textos.find("REGALO") >= 0, "… con los botones de alianza, rival y regalo")
	var d = m.diplomacia
	var rt: int = tid(roma)
	var jt: int = tid(jug)
	d.cambiar_opinion(jt, rt, 80.0)
	var res: Dictionary = main.proponer_alianza_jugador(rt)
	ok(bool(res["ok"]) and d.son_aliados(jt, rt), "Proponer la alianza con opinión alta: se firma (%s)" % String(res["msg"]))
	ok(not bool(main.proponer_alianza_jugador(rt)["ok"]), "Repetirla da error")
	res = main.romper_alianza_jugador(rt)
	ok(bool(res["ok"]) and not d.son_aliados(jt, rt) and d.opinion_de(jt, rt) < 80.0, "Romper la alianza cuesta opinión")
	res = main.rival_jugador(rt, true)
	ok(bool(res["ok"]) and d.rival_de(jt) == rt, "Declarar rival")
	res = main.rival_jugador(rt, false)
	ok(bool(res["ok"]) and d.rival_de(jt) == -1, "Quitar la rivalidad")
	# ficha de provincia: estabilidad
	var pi: int = int(m.paises[jug].provincias[0])
	main._seleccion_provincia(pi, "Asia", Vector2(1500, 300))
	await esperar(0.2)
	main.hud.abrir_pestana("general")
	await esperar(0.2)
	var t2 := ""
	var pila2: Array = [main.hud.panel]
	while not pila2.is_empty():
		var n2 = pila2.pop_back()
		if n2 is Label:
			t2 += (n2 as Label).text + "\n"
		if n2 is Button:
			t2 += (n2 as Button).text + "\n"
		for h2 in n2.get_children():
			pila2.append(h2)
	t2 = t2.to_upper()
	ok(t2.find("ESTABILIDAD SOCIAL") >= 0 or t2.find("ESTABILIDAD") >= 0, "La ficha de la provincia muestra la estabilidad y sus causas")
	m.fijar_jugador("")
	limpiar()


func run() -> void:
	Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": 1})
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(1280, 720)
	await esperar(1.0)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.3)
	main._poner_velocidad(0)
	m = main.mundo
	m.ia.activar_lista(m.ia.candidatos())
	ok(m.diplomacia != null and m.estabilidad != null, "El mundo tiene diplomacia y estabilidad (%d IA)" % m.ia.activas.size())
	t_opinion()
	t_alianzas()
	t_llamadas()
	t_infamia()
	t_coalicion()
	t_ia()
	t_relaciones_ia()
	t_estabilidad_meta()
	t_estabilidad_ciclo()
	t_motin()
	t_popups()
	await t_hud()
	print("[T] ═══ RESULTADO runner95: %d OK, %d FALLOS" % [n_ok, fallos])
	Engine.remove_meta("inicio_pendiente")
	get_tree().quit(1 if fallos > 0 else 0)
