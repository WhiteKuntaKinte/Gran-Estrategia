extends Node
## 0.1.8.48 · EFECTOS DE LOS EDIFICIOS (scripts/edificios.gd + datos/edificios_efectos.json), FONDO DE OBRAS y OBRAS PÚBLICAS DE LA IA (scripts/obras_publicas.gd).
var main
var fallos := 0
var n_ok := 0
const EdScript := preload("res://scripts/edificios.gd")


func _ready() -> void:
	run.call_deferred()


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func fotogramas(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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
	main._poner_velocidad(0)                                  # el reloj quieto: los días se simulan a mano


func textos(n: Node, acc := []) -> Array:
	if n is Label:
		acc.append((n as Label).text)
	elif n is Button:
		acc.append((n as Button).text)
	for h in n.get_children():
		textos(h, acc)
	return acc


func hay_texto(n: Node, trozo: String) -> bool:
	for t in textos(n):
		if String(t).find(trozo) >= 0:
			return true
	return false


## La provincia de `pais` que más produce (el costo de las obras no es ridículo).
func prov_de(pais: String) -> int:
	var m = main.mundo
	var mejor := -1
	var mejor_v := -1.0
	for pi in m.paises[pais].provincias:
		var v: float = m.provincias[int(pi)].ingreso_anual_usd()
		if v > mejor_v:
			mejor_v = v
			mejor = int(pi)
	return mejor


## Una provincia de `pais` de tamaño medio (80.000–400.000 habitantes; si no hay, la de más producción): los edificios atienden a un número fijo de habitantes,
## así que en una provincia de 11 millones casi no se notan.
func prov_media(pais: String) -> int:
	var m = main.mundo
	var mejor := -1
	var mejor_v := -1.0
	for pi in m.paises[pais].provincias:
		var pop: float = float(m.provincias[int(pi)].poblacion)
		var v: float = m.provincias[int(pi)].ingreso_anual_usd()
		if pop >= 80000.0 and pop <= 400000.0 and v > mejor_v:
			mejor_v = v
			mejor = int(pi)
	return mejor if mejor >= 0 else prov_de(pais)


## Deja la provincia sin edificios, sin obras y SIN lo que traía de partida (así todo lo que se le dé cuenta como construido durante la partida).
func limpiar(pi: int) -> void:
	var ed = main.mundo.edificios
	while not ed.obras_de(pi).is_empty():
		ed.cancelar_sin_reembolso(pi, 0)
	ed._guardar(pi, {}, "Prueba: provincia vacía")
	ed._base.erase(main.mundo.provincias[pi].tid)
	ed._refrescar_efectos(main.mundo.provincias[pi].tid, {})


func run() -> void:
	t_datos()
	await t_fondo()
	await t_modelo()
	await t_produccion()
	await t_ia()
	await t_interfaz()
	print("[T] ═══ RESULTADO runner106: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ─────────────────────────────────────────────────────────────
func t_datos() -> void:
	print("[T] ── Datos de efectos y matemática de la saturación")
	var js_e = JSON.parse_string(FileAccess.get_file_as_string("res://datos/edificios.json"))
	var js_f = JSON.parse_string(FileAccess.get_file_as_string("res://datos/edificios_efectos.json"))
	ok(js_f is Dictionary and js_f.has("tipos") and js_f.has("efectos") and js_f.has("solo_saber"), "datos/edificios_efectos.json tiene tipos, efectos y solo_saber")
	var ed = EdScript.new()
	ok(ed.cargar(js_e), "el catálogo de edificios carga")
	ok(not ed.efectos_listos and ed.lineas_efectos(0).is_empty() and ed.texto_efectos(0) == "", "sin datos de efectos: no hay efectos ni texto")
	ok(ed.ganancias(0, 0, 1000.0).size() == EdScript.N_EF, "…y ganancias() devuelve ceros del tamaño correcto sin romperse")
	ok(not ed.cargar_efectos({}) and not ed.efectos_listos, "cargar_efectos con un diccionario vacío falla sin dejar nada a medias")
	ok(ed.cargar_efectos(js_f) and ed.efectos_listos, "cargar_efectos con los datos reales funciona")
	var con := 0
	var solo := 0
	var por_clase := PackedInt32Array()
	por_clase.resize(EdScript.N_EF)
	var peso_ok := true
	for e in ed.n:
		if ed.con_efecto(e):
			con += 1
			for x in (ed._ef_de[e] as Array):
				por_clase[int(x[0])] += 1
				if float(x[1]) <= 0.0 or float(x[1]) > float(ed._ef_tope[int(x[0])]):
					peso_ok = false
		elif ed.ef_solo_saber.has(ed.slug[e]):
			solo += 1
	ok(con == 129 and solo == 12 and con + solo == ed.n, "129 edificios con efecto + 12 de solo saber = los 141 (%d + %d)" % [con, solo])
	ok(peso_ok, "ningún peso es cero ni pasa del tope de su clase")
	var todas := true
	for k in EdScript.N_EF:
		if por_clase[k] < 5:
			todas = false
	ok(todas, "cada una de las 7 clases de efecto la tienen al menos 5 edificios (%s)" % str(por_clase))
	var tope_sal := float(ed._ef_tope[EdScript.EF_SAL])
	ok(ed._valor_ws(0.0, 0.0, EdScript.EF_SAL, 100000.0) == 0.0, "sin edificios el efecto es cero")
	var v_a: float = ed._valor_ws(5000.0, 0.05, EdScript.EF_SAL, 100000.0)            # 0,05 de salud atendiendo a 100.000 habitantes en una provincia de 100.000
	ok(v_a > 0.0 and v_a < 0.05 and v_a > 0.8 * 0.05, "un efecto chico rinde casi todo su peso (%.4f de 0,05)" % v_a)
	var v_b: float = ed._valor_ws(5000.0, 0.05, EdScript.EF_SAL, 1000000.0)           # la misma obra en una provincia 10 veces más grande
	ok(v_b < 0.2 * v_a, "…y en una provincia 10 veces más poblada se diluye (%.4f contra %.4f)" % [v_b, v_a])
	var v_c: float = ed._valor_ws(5.0e8, 100.0, EdScript.EF_SAL, 100000.0)
	ok(absf(v_c - tope_sal) < 1.0e-4, "con una cantidad absurda de edificios el efecto SATURA en el tope (%.4f ≈ %.2f)" % [v_c, tope_sal])
	ok(ed._valor_ws(1.0e4, 0.1, EdScript.EF_SAL, 1.0e5) > ed._valor_ws(5.0e3, 0.05, EdScript.EF_SAL, 1.0e5), "más edificios, más efecto (monótono)")
	var marg_1: float = ed._valor_ws(5.0e3, 0.05, EdScript.EF_SAL, 1.0e5) - ed._valor_ws(0.0, 0.0, EdScript.EF_SAL, 1.0e5)
	var marg_2: float = ed._valor_ws(1.0e4, 0.1, EdScript.EF_SAL, 1.0e5) - ed._valor_ws(5.0e3, 0.05, EdScript.EF_SAL, 1.0e5)
	ok(marg_2 < marg_1, "cada edificio extra rinde menos que el anterior (%.4f → %.4f)" % [marg_1, marg_2])
	var d_a: float = ed._valor_ws(0.0, 0.3, EdScript.EF_DEF, 1.0e9)
	ok(absf(d_a - float(ed._ef_tope[EdScript.EF_DEF]) * (1.0 - exp(-0.3 / float(ed._ef_tope[EdScript.EF_DEF])))) < 1.0e-6, "la defensa no depende de cuánta gente hay (no se diluye): %.4f" % d_a)
	# texto
	var e_hosp: int = ed.indice("hospital_moderno")
	var l_hosp: PackedStringArray = ed.lineas_efectos(e_hosp)
	ok(l_hosp.size() >= 1 and String(l_hosp[0]).begins_with("Salud +15,0"), "las líneas del hospital moderno dicen «Salud +15,0 …» (%s)" % str(l_hosp))
	ok(ed.texto_efectos(e_hosp).begins_with("Efectos: "), "texto_efectos empieza por «Efectos: »")
	ok(ed.texto_efectos(ed.indice("biblioteca")).find("institución de saber") >= 0, "un edificio de saber lo dice: cuenta como institución, no repite efecto")
	var e_cast: int = ed.indice("castillo_piedra")
	ok(ed.texto_efectos(e_cast).find("Defensa +50,0") >= 0, "el castillo de piedra: Defensa +50,0 %% (%s)" % ed.texto_efectos(e_cast))
	ok(ed._miles(1234567.0) == "1.234.567" and ed._miles(950.0) == "950", "formato de miles con puntos")
	ok(ed.fraccion_de(ed.indice("acueducto")) > 0.0 and ed.con_efecto(ed.indice("acueducto")) and not ed.con_efecto(-1) and not ed.con_efecto(9999), "fraccion_de y con_efecto, con índices fuera de rango")


# ─────────────────────────────────────────────────────────────
func t_fondo() -> void:
	print("[T] ── Fondo de obras públicas: entra de los impuestos, se gasta primero, se recorta a 3 años")
	await arrancar(2026)
	var m = main.mundo
	var ed = m.edificios
	ok(ed != null and ed.efectos_listos, "los edificios arrancan con sus efectos")
	ok(m.obras_publicas != null, "las obras públicas de las IA existen")
	ok(m.bd.vars.has("fondo_obras") and m.bd.vars["fondo_obras"].historial == "mensual", "variable «fondo_obras» (mensual) en la base de datos")
	var pais := "Colombia"
	var p = m.paises[pais]
	var tid: int = int(p.tid)
	var ix: int = m.bd.idx(tid)
	var col: PackedFloat64Array = m.bd.vars["fondo_obras"].col_f
	col[ix] = NAN
	m._armar_balances()
	var aporte: float = m.ingreso_diario_local(pais) * p.fraccion_obras()
	ok(aporte > 0.0, "Colombia aporta %.0f al día a su fondo (la partida de obras de sus impuestos)" % aporte)
	ok(absf(p.fraccion_obras() - p.gasto_obras) < 1.0e-9, "con el presupuesto normal, la fracción del fondo es la partida «obras» (%.3f)" % p.fraccion_obras())
	m._economia_dia(1)
	ok(absf(p.fondo_obras - aporte * 181.0) < aporte * 181.0 * 1.0e-6, "un país nuevo arranca con 6 meses de aportes y suma el del día (%.0f ≈ %.0f)" % [p.fondo_obras, aporte * 181.0])
	var tes0: float = p.tesoreria
	m._economia_dia(10)
	ok(absf(p.fondo_obras - aporte * 191.0) < aporte * 191.0 * 1.0e-6, "10 días de golpe suman 10 aportes")
	ok(p.tesoreria > tes0, "y la tesorería sigue cobrando (menos la partida de obras, que ahora va al fondo)")
	# tope de 3 años
	p.fondo_obras = aporte * 5000.0
	var tes1: float = p.tesoreria
	m._economia_dia(1)
	ok(absf(p.fondo_obras - aporte * 1095.0) < aporte * 1095.0 * 1.0e-9, "pasado de 3 años de aportes el fondo se queda en 3 años (%.0f)" % (p.fondo_obras / aporte))
	ok(p.tesoreria - tes1 > aporte * 3800.0, "…y lo que sobra vuelve a la tesorería (%.0f días de aporte)" % ((p.tesoreria - tes1) / aporte))
	# gastar: primero el fondo
	var pi := prov_media(pais)
	limpiar(pi)
	var e_c := -1
	for e in ed.conocidos(pais):
		if ed.tope[e] >= 1 and ed.con_efecto(e) and ed.fraccion_de(e) < 0.02:
			e_c = e
			break
	ok(e_c >= 0, "hay un edificio con efecto que se puede construir (%s)" % ed.nombre[e_c])
	var costo: float = ed.costo_local(pi, e_c)
	p.fondo_obras = costo * 0.5
	p.tesoreria = costo * 10.0
	var r: Dictionary = ed.construir(pais, pi, e_c)
	ok(bool(r["ok"]) and absf(p.fondo_obras) < 1.0e-6 * costo and absf(p.tesoreria - (costo * 10.0 - costo * 0.5)) < 1.0e-6 * costo, "con fondo para la mitad: sale todo el fondo y la otra mitad de la tesorería")
	ok(absf(float(r["fondo"]) - costo * 0.5) < 1.0e-6 * costo and absf(float(r["costo"]) - costo) < 1.0e-6 * costo, "construir informa cuánto salió del fondo (%.0f) y el costo total" % float(r["fondo"]))
	ed.cancelar_sin_reembolso(pi, 0)
	p.fondo_obras = costo * 2.0
	p.tesoreria = costo * 10.0
	r = ed.construir(pais, pi, e_c)
	ok(bool(r["ok"]) and absf(p.fondo_obras - costo) < 1.0e-6 * costo and absf(p.tesoreria - costo * 10.0) < 1.0e-6 * costo, "con fondo de sobra la tesorería no se toca")
	ed.cancelar_sin_reembolso(pi, 0)
	p.fondo_obras = costo * 1.01
	p.tesoreria = 0.0
	ok(bool(ed.puede(pais, pi, e_c)["ok"]), "puede(): alcanza con solo el fondo aunque la tesorería esté en cero")
	p.fondo_obras = costo * 0.4
	p.tesoreria = costo * 0.4
	ok(bool(ed.puede(pais, pi, e_c)["ok"]) == false, "puede(): fondo + tesorería < costo → «No alcanza la tesorería»")
	p.fondo_obras = costo * 0.4
	p.tesoreria = costo * 0.7
	ok(bool(ed.puede(pais, pi, e_c)["ok"]), "puede(): fondo + tesorería ≥ costo → sí")
	# presupuesto que pasa del tope
	var gtot0: float = p.gasto_total()
	var obr0: float = p.gasto_obras
	p.gasto_educacion = 0.3
	p.gasto_ciencia = 0.3
	p.gasto_sanidad = 0.3
	ok(p.gasto_total() <= 0.6 + 1.0e-9 and p.fraccion_obras() < p.gasto_obras and p.fraccion_obras() > 0.0, "si las partidas pasan del 60 %%, el aporte al fondo se recorta en proporción (%.3f de %.3f)" % [p.fraccion_obras(), p.gasto_obras])
	p.gasto_educacion = 0.04
	p.gasto_ciencia = 0.015
	p.gasto_sanidad = 0.02
	p.gasto_obras = obr0
	ok(absf(p.gasto_total() - gtot0) < 1.0e-9, "(presupuesto restaurado)")
	# la fila de balance trae el aporte
	m._armar_balances()
	var pos: int = int(m._bal_pos.get(tid, -1))
	ok(pos >= 0 and m._bal[pos].size() >= 6 and absf(float(m._bal[pos][5]) - m.ingreso_diario_local(pais) * p.fraccion_obras()) < 1.0e-6 * aporte, "la fila de balance guarda el aporte diario al fondo")
	ok(absf(float(m._bal[pos][3]) - m.ingreso_neto_diario_local(pais)) < 1.0e-6 * absf(float(m._bal[pos][3])), "…y el ingreso neto de la fila no cambió respecto a la fórmula de siempre")


# ─────────────────────────────────────────────────────────────
func t_modelo() -> void:
	print("[T] ── Los efectos entran en la demografía, la estabilidad y la guerra")
	var m = main.mundo
	var ed = m.edificios
	var dm = m.demografia
	var pais := "Colombia"
	var pi := prov_media(pais)
	var pr = m.provincias[pi]
	limpiar(pi)
	var e00: PackedFloat32Array = ed.efectos_nuevos(pi, float(pr.poblacion))
	ok(e00[0] == 0.0 and e00[1] == 0.0 and e00[2] == 0.0, "una provincia sin obras nuevas no tiene efectos nuevos")
	var tid: int = int(pr.tid)
	var ix: int = pr.ix
	var due: int = int(m.bd.vars["propietario"].col_i[ix])
	dm._cargar_columnas()
	dm._ci.clear()
	dm._estado_inicial(pi, ix, due)
	var mor0: float = dm._mor[ix]
	var bie0: float = dm._bie[ix]
	var urb0: float = dm._urb[ix]
	for sl in ["hospital_moderno", "hospital_moderno", "alcantarillado", "acueducto", "almacenes_suministro", "almacenes_suministro", "barrios_obreros", "ciudades_romanas_servicios"]:
		ed.dar(pi, ed.indice(sl), 1)
	var pop: float = float(pr.poblacion)
	var efn: PackedFloat32Array = ed.efectos_nuevos(pi, pop)
	ok(efn[0] > 0.01 and efn[1] > 0.5 and efn[2] > 0.005, "construidas durante la partida, sus efectos de salud, comida y vivienda valen algo (%.3f / %.2f / %.3f)" % [efn[0], efn[1], efn[2]])
	dm._ci.clear()
	dm._estado_inicial(pi, ix, due)
	ok(dm._mor[ix] <= mor0 + 1.0e-9, "salud: la mortalidad no sube (%.2f → %.2f ‰)" % [mor0, dm._mor[ix]])
	ok(dm._bie[ix] > bie0, "comida segura: el bienestar objetivo sube (%.1f → %.1f)" % [bie0, dm._bie[ix]])
	ok(dm._urb[ix] > urb0, "vivienda: la urbanización objetivo sube (%.3f → %.3f)" % [urb0, dm._urb[ix]])
	# baja la mortalidad en una provincia con poca salud (un país del mundo antiguo sería mejor; aquí se prueba con la función pura)
	var DemoS = load("res://scripts/demografia.gd")
	var m_sin: float = DemoS.mortalidad_de(0.20, 0.06, 55.0, 0.0, false, 0.0, 0.5)
	var m_con: float = DemoS.mortalidad_de(0.20 + 0.15, 0.06, 55.0, 0.0, false, 0.0, 0.5)
	ok(m_con < m_sin - 1.0, "con +0,15 de salud efectiva la mortalidad baja más de 1 ‰ (%.1f → %.1f)" % [m_sin, m_con])
	ok(DemoS.bienestar_objetivo(0.5, 0.5, 0.5, 0.0, false, false, 0.0, 6.0) > DemoS.bienestar_objetivo(0.5, 0.5, 0.5, 0.0, false, false, 0.0) + 5.9, "bienestar_objetivo suma los puntos de comida de las obras")
	ok(DemoS.urbanizacion_objetivo(0.5, 0.5, 10.0, 0.05) > DemoS.urbanizacion_objetivo(0.5, 0.5, 10.0) + 0.049 and DemoS.urbanizacion_objetivo(0.9, 0.9, 5000.0, 0.5) <= 0.97, "urbanizacion_objetivo suma la vivienda de las obras y nunca pasa de 0,97")
	# la regla de partida: lo que traía la provincia NO cuenta como obra nueva
	var pi2: int = -1
	for q in m.paises[pais].provincias:
		if String(m.bd.txt("edificios", int(m.provincias[int(q)].tid), "")) != "" and int(q) != pi:
			pi2 = int(q)
			break
	if pi2 >= 0:
		var en: PackedFloat32Array = ed.efectos_nuevos(pi2, float(m.provincias[pi2].poblacion))
		ok(en[0] == 0.0 and en[1] == 0.0 and en[2] == 0.0 and ed.efecto_nuevo(pi2, EdScript.EF_REN, 1.0e6) == 0.0, "una provincia con edificios de partida y nada nuevo: efectos nuevos = 0 (ya están en los datos de la época)")
		ok(ed.efecto_abs(pi2, EdScript.EF_ORD, float(m.provincias[pi2].poblacion)) >= 0.0, "…pero el orden, la defensa y la movilidad sí cuentan todo lo construido")
	# estabilidad: orden y movilidad
	var es = m.estabilidad
	es._cargar_columnas()
	var d0: Dictionary = es.desglose(pi)
	var meta0 := float(d0["meta"])
	for sl in ["templos_monumentales", "templos_monumentales", "catedral_gotica", "foro_agora", "parques_publicos"]:
		ed.dar(pi, ed.indice(sl), 1)
	var d1: Dictionary = es.desglose(pi)
	var abs_ord: float = ed.efecto_abs(pi, EdScript.EF_ORD, float(pr.poblacion))
	ok(abs_ord > 0.5, "los edificios de orden suman puntos de estabilidad (%.2f)" % abs_ord)
	ok(float(d1["meta"]) > meta0 + 0.4 or meta0 > 97.0, "la meta de estabilidad de la provincia sube (%.1f → %.1f)" % [meta0, float(d1["meta"])])
	var txt_ord := false
	for par in d1["partes"]:
		if String(par[0]).find("orden y cohesión") >= 0:
			txt_ord = true
	ok(txt_ord, "el desglose de la estabilidad muestra «Edificios de orden y cohesión»")
	# movilidad: una provincia lejos de la capital
	var lejos := -1
	var peor := 0.0
	for q in m.paises[pais].provincias:
		var dq: Dictionary = es.desglose(int(q))
		for par in dq["partes"]:
			if String(par[0]) == "Lejos de la capital" and float(par[1]) < peor:
				peor = float(par[1])
				lejos = int(q)
	ok(lejos >= 0 and peor < -3.0, "hay una provincia colombiana lejos de la capital (%.1f)" % peor)
	if lejos >= 0:
		limpiar(lejos)
		var antes := 0.0
		for par in es.desglose(lejos)["partes"]:
			if String(par[0]) == "Lejos de la capital":
				antes = float(par[1])
		ed.dar(lejos, ed.indice("red_viaria_imperial"), 1)
		ed.dar(lejos, ed.indice("calzada_pavimentada"), 1)
		var mov: float = ed.efecto_abs(lejos, EdScript.EF_MOV)
		var despues := 0.0
		for par in es.desglose(lejos)["partes"]:
			if String(par[0]) == "Lejos de la capital":
				despues = float(par[1])
		ok(mov > 0.2 and absf(despues - antes * (1.0 - mov)) < 0.01, "las calzadas quitan el %.0f %% del castigo de la distancia (%.2f → %.2f)" % [mov * 100.0, antes, despues])
	# guerra: la defensa pesa solo en casa
	var g = m.guerra
	var tid_p: int = int(p_tid(pais))
	var prov_ej := -1
	var lista: Array = []
	for q in m.paises[pais].provincias:
		lista = g.pelotones_en(int(m.provincias[int(q)].tid), tid_p)
		if not lista.is_empty():
			prov_ej = int(q)
			break
	ok(prov_ej >= 0, "el ejército de Colombia está en alguna provincia suya (%d)" % prov_ej)
	if prov_ej >= 0:
		var ptid: int = int(m.provincias[prov_ej].tid)
		var def0: float = ed.efecto_abs(prov_ej, EdScript.EF_DEF)
		var pw0: float = g._poder(lista, tid_p, ptid)
		ed.dar(prov_ej, ed.indice("castillo_piedra"), 1)
		var def1: float = ed.efecto_abs(prov_ej, EdScript.EF_DEF)
		var pw1: float = g._poder(lista, tid_p, ptid)
		ok(def1 > def0 and absf(pw1 / pw0 - (g.BONO_LOCAL + def1) / (g.BONO_LOCAL + def0)) < 1.0e-6, "un castillo sube el poder de los defensores ×%.3f = (%.2f + %.2f) / (%.2f + %.2f)" % [pw1 / pw0, g.BONO_LOCAL, def1, g.BONO_LOCAL, def0])
		var otro: int = -1
		for nombre in m.paises:
			if nombre != pais and not m.paises[nombre].provincias.is_empty():
				otro = int(m.paises[nombre].tid)
				break
		var pw_fuera: float = g._poder(lista, otro, ptid)
		ok(pw_fuera < pw0 and absf(pw_fuera - pw0 / (g.BONO_LOCAL + def0)) < 1.0e-6 * pw0, "el bono de defensa es solo del dueño de la provincia (un tercero pelea sin bono)")


func p_tid(pais: String) -> int:
	return int(main.mundo.paises[pais].tid)


# ─────────────────────────────────────────────────────────────
func t_produccion() -> void:
	print("[T] ── Una obra terminada sube la producción de su provincia")
	var m = main.mundo
	var ed = m.edificios
	var pais := "Colombia"
	var p = m.paises[pais]
	var pi := prov_media(pais)
	limpiar(pi)
	var pr = m.provincias[pi]
	var e_r: int = ed.indice("puerto_piedra")
	var e_r2: int = ed.indice("feria_comercial")
	ok(ed.con_efecto(e_r) and ed.con_efecto(e_r2), "el puerto de piedra y la feria tienen efecto de producción")
	p.tesoreria = 1.0e18
	p.fondo_obras = 0.0
	var pcol: PackedFloat64Array = m.bd.vars["pib_pc_usd"].col_f
	var pc0: float = pcol[pr.ix]
	var prod0: int = ed.producidas
	var r: Dictionary = ed.construir(pais, pi, e_r)
	ok(bool(r["ok"]), "empieza la obra del puerto")
	ok(is_equal_approx(pcol[pr.ix], pc0), "mientras se construye no cambia nada")
	ed.completar_obras(pi)
	var pob: float = float(pr.poblacion)
	var boost: float = ed.efecto_nuevo(pi, EdScript.EF_REN, pob)
	ok(boost > 0.005, "terminada, la obra vale %.1f %% de producción" % (boost * 100.0))
	ok(absf(pcol[pr.ix] / pc0 - (1.0 + boost)) < 1.0e-9, "el producto por habitante de la provincia sube exactamente esa fracción (×%.4f)" % (pcol[pr.ix] / pc0))
	ok(ed.producidas == prod0 + 1, "y se cuenta como obra que subió la producción")
	var pc1: float = pcol[pr.ix]
	var prod_antes: float = m.produccion_anual_usd(pais)
	r = ed.construir(pais, pi, e_r2)
	ed.completar_obras(pi)
	var boost2: float = ed.efecto_nuevo(pi, EdScript.EF_REN, pob)
	ok(boost2 > boost and boost2 - boost < boost, "la segunda obra suma menos que la primera junta: satura (%.3f → %.3f)" % [boost, boost2])
	ok(absf(pcol[pr.ix] / pc1 - (1.0 + boost2 - boost)) < 1.0e-9, "cada obra suma solo lo que añade")
	# la caché de ingresos lo recoge al cerrar el mes
	m.avanzar_mes()
	ok(m.produccion_anual_usd(pais) > prod_antes * 0.999, "al cerrar el mes la producción del país recoge el aumento (%.4f ×)" % (m.produccion_anual_usd(pais) / prod_antes))
	# cancelar o ceder no devuelve el aumento, pero una obra sin efecto de producción no lo cambia
	var e_s: int = ed.indice("empalizada")
	var pc2: float = pcol[pr.ix]
	r = ed.construir(pais, pi, e_s)
	ed.completar_obras(pi)
	ok(bool(r["ok"]) and absf(pcol[pr.ix] - pc2) < 1.0e-9 * pc2, "una empalizada (defensa, sin producción) no cambia el producto por habitante")


# ─────────────────────────────────────────────────────────────
func t_ia() -> void:
	print("[T] ── Obras públicas de la IA")
	await arrancar(2026)
	var m = main.mundo
	var ed = m.edificios
	var op = m.obras_publicas
	m.ia.activar_lista(m.ia.candidatos())
	var activas: int = m.ia.activas.size()
	ok(activas > 50, "hay países con IA (%d)" % activas)
	m._armar_balances()
	m._economia_dia(1)
	var jug: String = m.jugador
	var tot_jug := 0
	if jug != "" and m.paises.has(jug):
		var todas := []
		for q in m.paises[jug].provincias:
			todas.append(int(q))
		tot_jug = ed.total_en(todas) + ed.obras_en(todas)
	# solo gasta el fondo
	var nombre := "Francia"
	ok(m.ia.activas.has(nombre), "Francia juega con IA")
	var p = m.paises[nombre]
	op._dia = 1000                                              # fuerza a rehacer la lista de edificios conocidos
	op._cargar_columnas()
	p.tesoreria = 1.0e15
	p.fondo_obras = 1.0                                          # una moneda: nada cabe
	var h0: int = op.obras_hechas
	for _i in 6:
		op._decidir(nombre)
	ok(op.obras_hechas == h0 and absf(p.tesoreria - 1.0e15) < 1.0, "con el fondo vacío la IA no construye ni toca la tesorería")
	p.fondo_obras = 1.0e15
	var obras0: int = 0
	for q in p.provincias:
		obras0 += ed.obras_de(int(q)).size()
	for _i in 6:
		op._decidir(nombre)
	var obras1: int = 0
	for q in p.provincias:
		obras1 += ed.obras_de(int(q)).size()
	ok(op.obras_hechas > h0 and obras1 > obras0, "con fondo la IA empieza obras (%d nuevas)" % (obras1 - obras0))
	ok(absf(p.tesoreria - 1.0e15) < 1.0 and p.fondo_obras < 1.0e15, "…pagadas del fondo (tesorería intacta)")
	var buenas := true
	for q in p.provincias:
		for o in ed.obras_de(int(q)):
			if not ed.con_efecto(int(o["e"])):
				buenas = false
	ok(buenas, "todo lo que elige la IA tiene algún efecto (nada de obras decorativas)")
	ok(not ed.cache_tolerante, "la IA deja el costo exacto activado cuando termina")
	# el jugador no es de la IA
	var j_obras := 0
	if jug != "" and m.paises.has(jug):
		var h1: int = op.obras_hechas
		var antes_fondo: float = m.paises[jug].fondo_obras
		op._decidir(jug)
		ok(op.obras_hechas == h1 and absf(m.paises[jug].fondo_obras - antes_fondo) < 1.0e-6, "el país del jugador nunca se construye solo")
		j_obras = 1
	ok(j_obras == 1 or jug == "", "(jugador revisado)")
	# un año de juego con todas las IA
	var op_h: int = op.obras_hechas
	var term0: int = ed.terminadas
	main.debug_avanzar_dias(400)
	ok(op.obras_hechas > op_h + 20, "en 400 días las IA empezaron obras (%d)" % (op.obras_hechas - op_h))
	ok(ed.terminadas > term0 + 10, "y terminaron varias (%d)" % (ed.terminadas - term0))
	ok(op.revisiones >= activas * 400 / 360 - 20, "cada país revisa sus obras una vez al año (%d revisiones)" % op.revisiones)
	var fondos_ok := true
	var neg := 0
	for nom in m.paises:
		var f: float = m.paises[nom].fondo_obras
		if is_nan(f) or f < -1.0e-6:
			fondos_ok = false
			neg += 1
	ok(fondos_ok, "ningún fondo de obras es negativo ni NaN (%d malos)" % neg)
	if jug != "" and m.paises.has(jug):
		var todas2 := []
		for q in m.paises[jug].provincias:
			todas2.append(int(q))
		ok(ed.total_en(todas2) + ed.obras_en(todas2) == tot_jug, "las obras del jugador siguen siendo solo las suyas (%d)" % tot_jug)
	var ms_dia: float = float(op.usec_total) / 1000.0 / maxf(float(op._dia), 1.0)
	print("[T] INFO  obras públicas: %.3f ms por día de juego · %d edificios evaluados por revisión · máximo %.2f ms" % [ms_dia, int(float(op.evaluaciones) / maxf(float(op.revisiones), 1.0)), op.ms_max])
	ok(ms_dia < 0.8 and op.ms_max < 8.0, "la fase cuesta poco: %.3f ms/día y %.2f ms como máximo" % [ms_dia, op.ms_max])
	# cambiar de escenario las reinicia
	await arrancar(1500)
	ok(main.mundo.obras_publicas != null and main.mundo.obras_publicas.obras_hechas == 0 and main.mundo.edificios.efectos_listos, "en otro escenario las obras públicas empiezan de cero")


# ─────────────────────────────────────────────────────────────
func t_interfaz() -> void:
	print("[T] ── Interfaz: ventana Construir, tarjeta Edificios y Debug")
	await arrancar(2026)
	var m = main.mundo
	var ed = m.edificios
	var pais: String = m.jugador if m.jugador != "" else "Colombia"
	if not m.paises.has(pais) or m.paises[pais].provincias.is_empty():
		pais = "Colombia"
	var p = m.paises[pais]
	var pi := prov_media(pais)
	limpiar(pi)
	main._seleccion_provincia(pi, m.continente_de_provincia(pi), Vector2(1200.0, 300.0))
	await fotogramas(2)
	main._abrir_construir()
	await fotogramas(2)
	var w = main.panel_construir
	ok(w != null and is_instance_valid(w), "se abre la ventana Construir")
	ok(hay_texto(w, "Fondo de obras:"), "la cabecera de Construir muestra el fondo de obras")
	ok(hay_texto(w, "Efectos: "), "las filas de Construir dicen qué hace cada edificio")
	var n_ef := 0
	for t in textos(w):
		if String(t).begins_with("Efectos: "):
			n_ef += 1
	ok(n_ef >= 5, "al menos 5 de los edificios que conoces muestran sus efectos (%d)" % n_ef)
	p.fondo_obras = 1.0
	p.tesoreria = 0.0
	w.refrescar(true)
	await fotogramas(1)
	var bloqueados := true
	for fl in w._filas:
		var b: Button = fl["btn"]
		if (fl["card"] as Control).visible and not b.disabled and b.text != "Bloqueado":
			bloqueados = false
	ok(bloqueados, "sin fondo ni tesorería ninguna fila deja construir")
	p.fondo_obras = 1.0e15
	w.refrescar(true)
	await fotogramas(1)
	var algun_activo := false
	for fl in w._filas:
		var b2: Button = fl["btn"]
		if (fl["card"] as Control).visible and not b2.disabled:
			algun_activo = true
	ok(algun_activo, "con fondo (y tesorería en cero) las filas dejan construir: el fondo cuenta como dinero")
	w.queue_free()
	await fotogramas(2)
	# tarjeta del HUD
	ed.dar(pi, ed.indice("castillo_piedra"), 1)
	ed.dar(pi, ed.indice("templos_monumentales"), 2)
	main._seleccion_provincia(pi, m.continente_de_provincia(pi), Vector2(1200.0, 300.0))
	main.refrescar_todo(false)
	await fotogramas(3)
	ok(hay_texto(main.hud.cuerpo, "EFECTOS"), "la tarjeta Edificios del HUD tiene la sección EFECTOS")
	ok(hay_texto(main.hud.cuerpo, "Defensa +"), "…con la defensa del castillo")
	ok(hay_texto(main.hud.cuerpo, "fondo de obras"), "…y la nota del fondo de obras")
	var res: PackedStringArray = ed.resumen_efectos(pi)
	ok(res.size() >= 2 and String(res[0]).find("Orden") >= 0, "resumen_efectos: orden, defensa… (%s)" % str(res))
	# Debug
	main._alternar_debug()
	await fotogramas(2)
	var dbg = main.debug_menu
	ok(dbg != null and is_instance_valid(dbg), "se abre el Debug")
	if dbg != null and is_instance_valid(dbg):
		dbg._refrescar_edif()
		ok(hay_texto(dbg, "Obras públicas de las IA"), "Debug > Edificios muestra las obras públicas de las IA")
		ok(hay_texto(dbg, "Fondo de obras de") and hay_texto(dbg, "Efectos:"), "…y el fondo y los efectos de la provincia elegida")


