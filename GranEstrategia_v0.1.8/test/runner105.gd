extends Node
## 0.1.8.47 · EDUCACIÓN, INVESTIGACIÓN Y OFICIOS (scripts/educacion.gd) + presupuesto de las IA + tarjetas del HUD.
var main
var fallos := 0
var n_ok := 0
const EduScript := preload("res://scripts/educacion.gd")
const DemoScript := preload("res://scripts/demografia.gd")


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


func arrancar(anio: int, semilla := 777) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await esperar(0.3)
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	Engine.set_meta("semilla_partida", semilla)
	if anio != 2026:
		Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": anio})
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)


func etiquetas(n: Node, r: Array) -> void:
	for h in n.get_children():
		if h is Label:
			r.append(h.text)
		if h is Button:
			r.append(h.text)
		etiquetas(h, r)


func clic_mundo(lon: float, lat: float) -> void:
	main._seleccionar(Vector2((lon + 180.0) * 6.6667, (90.0 - lat) * 6.6667))


func suma_agraria(lista: Array) -> float:
	var t := 0.0
	var tot := 0.0
	for o in lista:
		tot += float(o["n"])
		if String(o["grupo"]) == "agro":
			t += float(o["n"])
	return t / maxf(tot, 1.0)


func n_de(lista: Array, id: String) -> float:
	for o in lista:
		if String(o["id"]) == id:
			return float(o["n"])
	return -1.0


func run() -> void:
	t_puras()
	await t_catalogo_y_oficios()
	await t_politica_y_capacidad()
	await t_ia_y_presupuesto()
	await t_saber_integrado()
	await t_hud()
	await t_debug()
	print("[T] ═══ RESULTADO runner105: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ─────────────────────────────────────────────────────────────
func t_puras() -> void:
	print("[T] ── Estudios e investigación (funciones puras)")
	var e0: Vector2 = EduScript.estudios(0.2, 0.0)
	var e1: Vector2 = EduScript.estudios(6.0, 1.0)
	var e2: Vector2 = EduScript.estudios(12.0, 3.0)
	ok(e0.x < 0.02 and e0.y < 0.05, "con 0,2 años de escuela casi nadie tiene secundaria ni estudios superiores (%.3f / %.3f)" % [e0.x, e0.y])
	ok(e2.x > e1.x and e2.x > 0.35 and e2.x <= 0.62 and e2.x + e2.y <= 1.0, "con 12 años de escuela hay muchos estudios superiores y nunca más del 100 %% entre los dos niveles (%.2f / %.2f)" % [e2.x, e2.y])
	ok(EduScript.estudios(0.3, 5.0).x > EduScript.estudios(0.3, 0.0).x, "las academias y bibliotecas crean eruditos aun sin escuela")
	var d_lo: float = EduScript.densidad_investigadores(0.1, 0.0075, 1.0)
	var d_hi: float = EduScript.densidad_investigadores(0.1, 0.03, 1.0)
	ok(d_hi > d_lo * 1.5, "gastar más en ciencia sube la densidad de investigadores (%.4f → %.4f)" % [d_lo, d_hi])
	ok(EduScript.densidad_investigadores(0.1, 0.5, 1.0) == EduScript.densidad_investigadores(0.1, 0.045, 1.0), "…pero el gasto solo rinde hasta 3 × la referencia")
	ok(EduScript.densidad_investigadores(0.1, 0.015, 1.6) > EduScript.densidad_investigadores(0.1, 0.015, 0.6), "y la política de investigación también (más esfuerzo científico, más investigadores)")


# ─────────────────────────────────────────────────────────────
func t_catalogo_y_oficios() -> void:
	print("[T] ── Los 40 oficios")
	await arrancar(2026)
	var m = main.mundo
	var ed = m.educacion
	var dm = m.demografia
	ok(ed != null and ed.listo, "el módulo de educación arranca con la partida")
	ok(ed.carreras.size() == 40 and ed.grupos.size() == 12, "hay 40 oficios en 12 grupos")
	var ids := {}
	var campos_ok := true
	var grupos_ok := true
	for c in ed.carreras:
		ids[String(c["id"])] = true
		if dm.idx.campo(String(c["campo"])).is_empty():
			campos_ok = false
			print("[T] INFO  campo desconocido: ", c["campo"])
		if not ed.grupos.has(String(c["grupo"])):
			grupos_ok = false
	ok(ids.size() == 40, "los 40 oficios tienen id distinto")
	ok(campos_ok, "cada oficio depende de un campo que existe en el catálogo de descubrimientos")
	ok(grupos_ok, "cada oficio pertenece a un grupo conocido")
	var tid_co: int = int(m.paises["Colombia"].tid)
	var tid_us: int = int(m.paises["Estados Unidos"].tid)
	var tid_ne: int = int(m.paises["Niger"].tid) if m.paises.has("Niger") else int(m.paises["Níger"].tid) if m.paises.has("Níger") else -1
	for par in [["Colombia", tid_co], ["Estados Unidos", tid_us]]:
		var lista: Array = ed.fuerza_laboral(int(par[1]))
		var res: Dictionary = ed.resumen_pais(int(par[1]))
		var suma := 0.0
		var negativos := 0
		for o in lista:
			suma += float(o["n"])
			if float(o["n"]) < 0.0 or is_nan(float(o["n"])):
				negativos += 1
		ok(lista.size() == 40 and negativos == 0 and absf(suma - float(res["activos"])) < float(res["activos"]) * 1.0e-6, "%s: los 40 oficios suman toda su gente activa (%.1f M)" % [par[0], float(res["activos"]) / 1.0e6])
	var l_co: Array = ed.fuerza_laboral(tid_co)
	var l_us: Array = ed.fuerza_laboral(tid_us)
	ok(suma_agraria(l_co) > 0.05 and suma_agraria(l_co) < 0.30, "Colombia: el campo emplea entre el 5 y el 30 %% (%.0f %%)" % (100.0 * suma_agraria(l_co)))
	ok(suma_agraria(l_us) < 0.05, "Estados Unidos: casi nadie en el campo (%.1f %%)" % (100.0 * suma_agraria(l_us)))
	if tid_ne >= 0:
		var l_ne: Array = ed.fuerza_laboral(tid_ne)
		ok(suma_agraria(l_ne) > suma_agraria(l_co), "un país pobre y rural tiene más gente en el campo que Colombia (%.0f %% vs %.0f %%)" % [100.0 * suma_agraria(l_ne), 100.0 * suma_agraria(l_co)])
	ok(n_de(l_us, "programador") > 0.0 and n_de(l_us, "medico") > 0.0 and n_de(l_us, "empleado") > n_de(l_us, "medico") * 5.0, "en 2026 hay programadores y médicos, y muchos más empleados de servicios")
	var prof_us: float = ed.trabajadores_de(tid_us, "investigacion")
	ok(prof_us > 0.0 and prof_us < float(ed.resumen_pais(tid_us)["activos"]) * 0.1, "los investigadores son una parte pequeña de la gente activa (%.1f M)" % (prof_us / 1.0e6))
	# la guerra pesa en los soldados
	var s0: float = n_de(l_co, "soldado")
	m.bd.poner_f("guerras_activas", tid_co, 1.0)
	var s1: float = n_de(ed.fuerza_laboral(tid_co), "soldado")
	m.bd.poner_f("guerras_activas", tid_co, 0.0)
	ok(s1 > s0 * 1.5, "en guerra los soldados profesionales aumentan (%.0f → %.0f)" % [s0, s1])
	# el año 1: sin programadores ni cirujanos, casi todos en el campo
	await arrancar(1)
	var m1 = main.mundo
	var e1 = m1.educacion
	var tid_r: int = int(m1.paises["Imperio romano"].tid)
	var l_r: Array = e1.fuerza_laboral(tid_r)
	var res_r: Dictionary = e1.resumen_pais(tid_r)
	var suma_r := 0.0
	for o in l_r:
		suma_r += float(o["n"])
	ok(absf(suma_r - float(res_r["activos"])) < float(res_r["activos"]) * 1.0e-6, "Imperio romano (año 1): los oficios suman su gente activa")
	ok(suma_agraria(l_r) > 0.75, "año 1: ~80 %% de la gente trabaja la tierra (%.0f %%)" % (100.0 * suma_agraria(l_r)))
	ok(n_de(l_r, "programador") == 0.0 and n_de(l_r, "ing_telecom") == 0.0 and n_de(l_r, "cirujano") == 0.0, "año 1: no hay programadores, ingenieros de telecomunicaciones ni cirujanos (aún no existen)")
	var existe_prog := true
	for o in l_r:
		if String(o["id"]) == "programador":
			existe_prog = bool(o["existe"])
	ok(not existe_prog, "…y la lista dice que el oficio de programador aún no existe")
	ok(n_de(l_r, "artesano") > 0.0 and n_de(l_r, "soldado") > 0.0 and n_de(l_r, "agricultor") > n_de(l_r, "soldado") * 20.0, "sí hay artesanos y soldados, y muchísimos más agricultores")
	ok(float(res_r["alfab"]) < 0.10 and float(res_r["f_cap"]) < 0.8, "año 1: poca alfabetización y poca capacidad de investigar (×%.2f)" % float(res_r["f_cap"]))


# ─────────────────────────────────────────────────────────────
func t_politica_y_capacidad() -> void:
	print("[T] ── Política de investigación y capacidad")
	await arrancar(2026)
	var m = main.mundo
	var ed = m.educacion
	var d = m.descubrimientos
	var tid: int = int(m.paises["Colombia"].tid)
	ok(ed.factor_rama(tid, 0) == 1.0 and ed.factor_rama(tid, 1) == 1.0 and ed.factor_rama(tid, 2) == 1.0, "por defecto el esfuerzo se reparte parejo: ×1 en las tres ramas")
	var sec_mil := -1
	var sec_cie := -1
	for s in d.secciones.size():
		if int(d.secciones[s]["rama"]) == 0 and sec_mil < 0:
			sec_mil = s
		if int(d.secciones[s]["rama"]) == 1 and sec_cie < 0:
			sec_cie = s
	ok(sec_mil >= 0 and sec_cie >= 0 and ed.factor_seccion(tid, sec_mil) == 1.0, "el factor por sección sigue a la rama (por defecto ×1)")
	ed.fijar_politica(tid, 0.05, 0.9, 0.05)
	var pol: PackedFloat32Array = ed.politica(tid)
	ok(absf(float(pol[0]) + float(pol[1]) + float(pol[2]) - 1.0) < 1.0e-5 and float(pol[0]) >= EduScript.POLITICA_MIN - 1.0e-6, "la política se normaliza a suma 1 con mínimo del 5 %% por rama (%.2f / %.2f / %.2f)" % [pol[0], pol[1], pol[2]])
	ok(ed.factor_seccion(tid, sec_cie) > 1.8 and ed.factor_seccion(tid, sec_mil) < 0.5, "más esfuerzo científico: ×%.2f en ciencia y ×%.2f en lo militar" % [ed.factor_seccion(tid, sec_cie), ed.factor_seccion(tid, sec_mil)])
	ed.fijar_politica(tid, 0.0, 0.0, 0.0)
	var pol0: PackedFloat32Array = ed.politica(tid)
	ok(absf(float(pol0[0]) - 0.3333) < 0.01, "una política en ceros se vuelve pareja (%.2f)" % float(pol0[0]))
	ed.fijar_politica(tid, 1.0, 0.0, 0.0)
	ok(ed.factor_rama(tid, 0) <= EduScript.FACTOR_RAMA_MAX and ed.factor_rama(tid, 1) >= EduScript.FACTOR_RAMA_MIN, "los factores nunca salen de [0,25 ; 2,2]")
	ok(not ed.es_manual(tid), "una política fijada por código no marca el país como llevado a mano")
	ed.fijar_politica(tid, 0.2, 0.5, 0.3, true)
	ok(ed.es_manual(tid), "…y una fijada por el jugador, sí")
	ed.reiniciar()
	ok(absf(float(ed.politica(tid)[1]) - 0.05 - (1.0 - 0.15) * 0.5) < 0.01, "un salto de fecha no borra la política del jugador")
	ed.marcar_manual(tid, false)
	ed.reiniciar()
	ok(ed.factor_rama(tid, 1) == 1.0, "…pero sí la de una IA")
	# capacidad
	var tid_us: int = int(m.paises["Estados Unidos"].tid)
	var f_cap: float = ed.factor_capacidad(tid_us)
	ok(f_cap >= 0.5 and f_cap <= 1.5 and f_cap > 1.2, "Estados Unidos (muchos estudios y gasto de referencia) pesa ×%.2f en los descubrimientos" % f_cap)
	var p_co = m.paises["Colombia"]
	var antes: float = ed.factor_capacidad(tid)
	p_co.gasto_ciencia = 0.0
	var sin_ciencia: float = ed.factor_capacidad(tid)
	p_co.gasto_ciencia = 0.03
	var mucha: float = ed.factor_capacidad(tid)
	p_co.gasto_ciencia = 0.015
	ok(sin_ciencia < antes and mucha > antes, "más gasto en ciencia, más peso en los descubrimientos (%.2f < %.2f < %.2f)" % [sin_ciencia, antes, mucha])
	var fd: float = ed.factor_difusion(tid)
	ok(fd >= 0.8 and fd <= 1.3 and fd > 1.15, "un país alfabetizado se entera antes de lo nuevo (×%.2f)" % fd)
	var res: Dictionary = ed.resumen_pais(tid)
	ok(float(res["investigadores"]) > 0.0 and float(res["calidad"]) > 0.0 and float(res["superiores"]) > 0.0, "la ficha de educación trae investigadores, calidad de docentes y estudios superiores")


# ─────────────────────────────────────────────────────────────
func t_ia_y_presupuesto() -> void:
	print("[T] ── Decisiones de presupuesto de las IA")
	var m = main.mundo
	var ed = m.educacion
	var p = m.paises["Argentina"] if m.paises.has("Argentina") else m.paises["Colombia"]
	var nombre: String = p.nombre
	var tid: int = int(p.tid)
	p.gasto_educacion = 0.04
	p.gasto_ciencia = 0.015
	p.gasto_obras = 0.025
	p.gasto_sanidad = 0.02
	ed.fijar_politica(tid, 1.0, 1.0, 1.0)
	# 1) en guerra recorta
	for _i in 12:
		ed.decidir_ia(p, true, 0.0)
	ok(p.gasto_educacion < 0.032 and p.gasto_obras < 0.02 and p.gasto_ciencia < 0.012, "en guerra una IA recorta educación, ciencia y obras (%.1f / %.1f / %.1f %%)" % [100.0 * p.gasto_educacion, 100.0 * p.gasto_ciencia, 100.0 * p.gasto_obras])
	var pol_g: PackedFloat32Array = ed.politica(tid)
	ok(float(pol_g[0]) > 0.4, "…y apunta su investigación a lo militar (%.0f %%)" % (100.0 * float(pol_g[0])))
	# 2) en paz con caja holgada invierte
	p.tesoreria = 1.0e18
	for _i in 30:
		ed.decidir_ia(p, false, 0.0)
	ok(p.gasto_educacion > 0.045 and p.gasto_obras > 0.028, "en paz y con la caja llena invierte más que la referencia (%.1f / %.1f %%)" % [100.0 * p.gasto_educacion, 100.0 * p.gasto_obras])
	var pol_p: PackedFloat32Array = ed.politica(tid)
	ok(float(pol_p[1]) > float(pol_p[0]), "…y apunta su investigación a la ciencia (%.0f %% vs %.0f %% militar)" % [100.0 * float(pol_p[1]), 100.0 * float(pol_p[0])])
	# 3) sin caja y con pérdidas: austeridad
	var tasa: float = p.tasa_fiscal
	p.tasa_fiscal = 0.0
	p.tesoreria = 0.0
	for _i in 30:
		ed.decidir_ia(p, false, 0.0)
	var recortada: bool = p.gasto_educacion < 0.025 and p.gasto_sanidad < 0.014
	p.tasa_fiscal = tasa
	ok(recortada, "con la caja vacía y pérdidas diarias aplica austeridad (%.1f %% en educación)" % (100.0 * p.gasto_educacion))
	# 4) lo que lleva el jugador o a mano, la IA no lo toca
	p.gasto_educacion = 0.123
	ed.marcar_manual(tid, true)
	for _i in 10:
		ed.decidir_ia(p, true, 90.0)
	ok(absf(p.gasto_educacion - 0.123) < 1.0e-6, "un país llevado a mano no cambia de presupuesto por decisión de la IA")
	ed.marcar_manual(tid, false)
	var jug: String = m.jugador
	var antes_jug := -1.0
	if jug != "" and m.paises.has(jug):
		antes_jug = m.paises[jug].gasto_educacion
		ed.decidir_ia(m.paises[jug], true, 90.0)
		ok(m.paises[jug].gasto_educacion == antes_jug, "el país del jugador nunca lo decide la IA")
	# 5) integrado en la fase del día: solo las IA activas, y se puede apagar
	p.gasto_educacion = 0.04
	p.gasto_ciencia = 0.015
	p.gasto_obras = 0.025
	p.gasto_sanidad = 0.02
	var n0: int = ed.decisiones
	for _i in 4:
		m.avanzar_dias(30)
	ok(ed.decisiones == n0, "sin IA activa nadie decide su presupuesto en la fase del día")
	ok(m.ia.activar(nombre) and m.ia.activas.has(nombre), "activo la IA de %s" % nombre)
	for _i in 4:
		m.avanzar_dias(30)
	ok(ed.decisiones > n0, "con la IA activa su presupuesto se revisa cada mes (%d decisiones)" % (ed.decisiones - n0))
	var n1: int = ed.decisiones
	m.demografia.guias_ia = false
	for _i in 3:
		m.avanzar_dias(30)
	ok(ed.decisiones == n1, "se puede apagar (Debug)")
	m.demografia.guias_ia = true
	m.ia.desactivar(nombre)
	# 6) coste (0.1.8.47): el presupuesto de la IA no rehace los balances de ~250 países ni guarda historial, y el balance rápido coincide con el de siempre
	m._economia_dia()
	p.gasto_educacion = 0.04
	p.gasto_obras = 0.025
	m._economia_dia()
	var ve0: int = m.bd.version_eco
	m._bal_sucios.clear()
	ed.decidir_ia(p, true, 0.0)
	ok(m.bd.version_eco == ve0, "decidir_ia no sube la versión económica (si no, cada día se rehacen los balances de ~250 países)")
	ok(m._bal_sucios.has(tid), "…pero marca el balance de ese país para rehacerlo (solo el suyo)")
	m._economia_dia()
	var rap: float = m.balance_diario_rapido(nombre)
	var loc: float = m.balance_diario_local(nombre)
	ok(absf(rap - loc) <= 1.0e-6 * maxf(absf(loc), 1.0), "balance_diario_rapido da lo mismo que balance_diario_local tras la economía del día (%.2f vs %.2f)" % [rap, loc])
	ok(m.balance_diario_rapido("País que no existe") == 0.0, "…y 0 para un país que no existe")


# ─────────────────────────────────────────────────────────────
## Que los países sigan sabiendo lo que saben sin romper prerrequisitos y que el motor use el reparto.
func t_saber_integrado() -> void:
	print("[T] ── Integración con el motor de descubrimientos (reloj real, 1500)")
	await arrancar(1500)
	var m = main.mundo
	var sb = m.saber
	var ed = m.educacion
	ok(sb != null and sb.listo and ed != null and ed.listo, "el planeta descubre y la educación corren juntos")
	var antes: int = sb.mes_n
	main.debug_avanzar_dias(365 * 12)
	ok(sb.mes_n - antes >= 140, "12 años de reloj: el motor avanzó %d meses" % (sb.mes_n - antes))
	var malos := 0
	var d = m.descubrimientos
	for tid in d.estado:
		var e: PackedByteArray = d.estado[tid]
		for i in d.n:
			if e[i] == 1:
				for r in d.req[i]:
					if e[r] == 0:
						malos += 1
	ok(malos == 0, "ningún país conoce algo sin conocer sus prerrequisitos")
	var cap_ok := true
	for tid in sb._cap:
		var v: float = float(sb._cap[tid])
		if is_nan(v) or v < 0.0 or is_inf(v):
			cap_ok = false
	ok(cap_ok and sb._cap.size() > 100, "la capacidad de cada país es un número sano (%d países)" % sb._cap.size())
	# la población y la economía siguen sanas
	var pob := 0.0
	var col: PackedFloat64Array = m.bd.vars["poblacion"].col_f
	for pr in m.provincias:
		if not is_nan(col[pr.ix]):
			pob += col[pr.ix]
	ok(pob > 3.0e8 and pob < 8.0e8, "tras 12 años la población del mundo es plausible (%.0f M)" % (pob / 1.0e6))
	var pc: PackedFloat64Array = m.bd.vars["pib_pc_usd"].col_f
	var tot_pc := 0.0
	var n_pc := 0
	for pr in m.provincias:
		if not is_nan(pc[pr.ix]) and col[pr.ix] > 0.0:
			tot_pc += pc[pr.ix]
			n_pc += 1
	ok(n_pc > 0 and tot_pc / float(n_pc) < 1.0e6, "la renta por habitante no se disparó (media %.0f US$)" % (tot_pc / float(maxi(n_pc, 1))))


# ─────────────────────────────────────────────────────────────
func t_hud() -> void:
	print("[T] ── Tarjetas del HUD: Gente, Presupuesto, Educación, Oficios")
	await arrancar(2026)
	main._seleccion_pais("Colombia", "América del Sur", Vector2(1000, 400))
	await esperar(0.3)
	var hud = main.hud
	ok(main.sel_tipo == "pais" and hud.esta_abierto(), "un clic elige el país y abre el HUD (selección: %s)" % main.sel_tipo)
	hud.abrir_pestana("poblacion")
	await esperar(0.1)
	var t: Array = []
	etiquetas(hud.panel, t)
	var todo: String = "\n".join(PackedStringArray(t)).to_upper()
	ok(todo.contains("GENTE") and todo.contains("CRECIMIENTO") and todo.contains("EDADES") and todo.contains("CIUDAD Y CAMPO"), "Población: tarjeta «Gente» con crecimiento, edades y ciudad")
	hud.abrir_pestana("economia")
	await esperar(0.1)
	var t2: Array = []
	etiquetas(hud.panel, t2)
	var todo2: String = "\n".join(PackedStringArray(t2)).to_upper()
	ok(todo2.contains("PRESUPUESTO") and todo2.contains("LLEGA A LA TESORERÍA"), "Economía: tarjeta «Presupuesto» con lo que llega a la tesorería")
	hud.abrir_pestana("progreso")
	await esperar(0.1)
	var t3: Array = []
	etiquetas(hud.panel, t3)
	var todo3: String = "\n".join(PackedStringArray(t3)).to_upper()
	ok(todo3.contains("EDUCACIÓN E INVESTIGACIÓN") and todo3.contains("POLÍTICA DE INVESTIGACIÓN"), "Progreso: tarjeta «Educación e investigación» con la política de investigación")
	ok(todo3.contains("OFICIOS") and todo3.contains("EMPLEADO DE SERVICIOS"), "Progreso: tarjeta «Oficios» con los más numerosos")
	ok(todo3.contains("SABER SOCIAL") and todo3.contains("URBANISMO") and todo3.contains("AGRICULTURA"), "Progreso: tarjeta «Saber social» con los 4 índices")
	var v: Dictionary = main.pueblo_vista()
	ok(not v.is_empty() and String(v["pais"]) == "Colombia" and (v["oficios"] as Array).size() == 40 and not bool(v["propio"]), "pueblo_vista trae lo del país elegido (no es el tuyo)")
	# el jugador mueve las partidas
	main.mundo.jugador = "Colombia"
	await esperar(0.1)
	var v2: Dictionary = main.pueblo_vista()
	ok(bool(v2["propio"]), "si el país es el tuyo, el panel lo sabe")
	main.fijar_gasto("Colombia", 0, 0.08)
	main.fijar_gasto("Colombia", 1, 0.03)
	main.fijar_gasto("Colombia", 2, 0.01)
	main.fijar_gasto("Colombia", 3, 0.05)
	var p = main.mundo.paises["Colombia"]
	ok(absf(p.gasto_educacion - 0.08) < 1.0e-9 and absf(p.gasto_ciencia - 0.03) < 1.0e-9 and absf(p.gasto_obras - 0.01) < 1.0e-9 and absf(p.gasto_sanidad - 0.05) < 1.0e-9, "fijar_gasto cambia las cuatro partidas")
	ok(main.mundo.educacion.es_manual(int(p.tid)), "…y marca el país como llevado a mano")
	main.fijar_investigacion("Colombia", 10.0, 80.0, 10.0)
	var pol: PackedFloat32Array = main.mundo.educacion.politica(int(p.tid))
	ok(float(pol[1]) > 0.6, "fijar_investigacion reparte el esfuerzo (%.0f %% científico)" % (100.0 * float(pol[1])))
	var sliders := 0
	for tab in ["economia", "progreso"]:
		hud.abrir_pestana(tab)
		await esperar(0.1)
		var pila: Array = [hud.panel]
		while not pila.is_empty():
			var n: Node = pila.pop_back()
			if n is HSlider:
				sliders += 1
			for h in n.get_children():
				pila.append(h)
	ok(sliders >= 7, "en tu país el panel trae deslizadores: 4 partidas + 3 ramas de investigación (%d)" % sliders)
	main.mundo.jugador = ""


# ─────────────────────────────────────────────────────────────
func t_debug() -> void:
	print("[T] ── Debug › Gente")
	main._abrir_debug()
	await esperar(0.4)
	var d = main.debug_menu
	ok(d != null and d._tarjetas.has("gente"), "el Debug trae la sección «Gente»")
	d._ir_a("gente")
	await esperar(0.2)
	var m = main.mundo
	ok(d.lbl_gente_mundo.text.contains("MUNDO") and d.lbl_gente_mundo.text.contains("Los 8 más poblados"), "resumen del mundo con los países más poblados")
	ok(d.btn_gente_guias.text.contains("SÍ"), "las guías de la IA aparecen encendidas")
	d.btn_gente_guias.pressed.emit()
	ok(not m.demografia.guias_ia and d.btn_gente_guias.text.contains("NO"), "el botón apaga las guías de la IA")
	d.btn_gente_guias.pressed.emit()
	ok(m.demografia.guias_ia, "…y las vuelve a encender")
	d._seleccionar_en(d.sel_gente, "Colombia")
	await esperar(0.1)
	var t: String = d.lbl_gente_pais.text
	ok(d.pais_gente == "Colombia" and t.contains("Colombia") and t.contains("Saber social") and t.contains("Presupuesto") and t.contains("Oficios"), "ficha de Colombia: población, saber social, presupuesto y oficios")
	d._gente_fatiga(25.0)
	ok(absf(m.paises["Colombia"].fatiga_guerra - 25.0) < 0.01 and d.lbl_gente_pais.text.contains("25 de 100"), "«Cansar de guerra» sube la fatiga y la muestra")
	d._gente_fatiga(-1000.0)
	ok(m.paises["Colombia"].fatiga_guerra == 0.0, "«Descansar» la deja en 0")
