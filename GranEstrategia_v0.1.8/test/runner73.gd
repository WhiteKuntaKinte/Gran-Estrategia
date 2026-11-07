extends Node
## 0.1.8.25 · PRUEBAS UNITARIAS (parte 3): lo que quedaba sin probar directamente.
## MapaPrincipal (_medir_sinc, _presupuesto_restante, _avanzar_reloj, _mandar_tropas, _preparar_campana) · Ia (_economia, _reclutar, _buscar_guerra, _operar) ·
## Guerra (_avanzar_ocupaciones por pasos de k días) · HUD (_tab_diplomacia: sección «Declarar la guerra»).
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


## Un vecino de España con IA y varias provincias: [tid propio, tid rival, nombre del rival]
func vecino_grande() -> Array:
	var mejor := ""
	var n_mejor := 0
	for nv in ia.vecinos_de("España"):
		var nom := String(nv)
		if m.paises.has(nom) and ia.activas.has(nom) and (m.paises[nom].provincias as Array).size() > n_mejor:
			mejor = nom
			n_mejor = (m.paises[nom].provincias as Array).size()
	return [int(m.paises["España"].tid), int(m.paises[mejor].tid), mejor]


func cerrar_guerras() -> void:
	for k in g.activas.keys():
		var gid: int = int(g.activas[k])
		g.paz(int(g.bd.ref("agresor", gid)), int(g.bd.ref("defensor", gid)), "prueba")
	ia.tregua.clear()


# ───────────────────────── Reloj: medición, presupuesto y el fotograma ─────────────────────────
func t_reloj() -> void:
	print("[T] ── MapaPrincipal: _medir_sinc, _presupuesto_restante, _avanzar_reloj")
	m.bd.version_propietario = maxi(m.bd.version_propietario, 1)
	var n0: int = main.n_sinc
	main._medir_sinc(Time.get_ticks_usec() + 1000000)                # t0 en el futuro: «tardó» menos de 0,3 ms
	ok(main.n_sinc == n0, "_medir_sinc: un repintado rápido (< 0,3 ms) no se cuenta")
	main._medir_sinc(Time.get_ticks_usec() - 5000)                   # tardó ≥ 5 ms
	ok(main.n_sinc == n0 + 1 and main.ms_sinc >= 5.0 and main.ms_sinc_max >= main.ms_sinc, "_medir_sinc: un repintado lento se cuenta, con su tiempo (%.1f ms) y el máximo" % main.ms_sinc)
	var tot0: float = main.ms_sinc_tot
	main._medir_sinc(Time.get_ticks_usec() - 8000)
	ok(main.n_sinc == n0 + 2 and main.ms_sinc_tot >= tot0 + 8.0, "…y el total acumulado suma (%.1f ms)" % main.ms_sinc_tot)
	var mundo_ref = main.mundo
	main.mundo = null
	main._medir_sinc(Time.get_ticks_usec() - 5000)
	ok(main.n_sinc == n0 + 2, "_medir_sinc sin mundo: no hace nada")
	main.mundo = mundo_ref
	# _presupuesto_restante
	var p1: int = main._presupuesto_restante(Time.get_ticks_usec())
	ok(p1 <= main.RelojScript.PRESUPUESTO_US and p1 > main.RelojScript.PRESUPUESTO_US - 3000, "_presupuesto_restante recién empezado ≈ el presupuesto completo (%d µs)" % p1)
	var p2: int = main._presupuesto_restante(Time.get_ticks_usec() - 4000)
	ok(p2 < p1 and p2 <= main.RelojScript.PRESUPUESTO_US - 4000 + 200, "…y baja con el tiempo gastado (%d µs)" % p2)
	ok(main._presupuesto_restante(Time.get_ticks_usec() - 50000) == 1, "…nunca baja de 1 µs (cada llamada hace al menos una fase)")
	# _avanzar_reloj
	main._fases.clear()
	main.reloj.ocupado = false
	main.reloj.acum = 0.0
	main.reloj.fijar(2026, 6, 1)
	main.reloj.velocidad = 0
	var r0: int = main.reloj.dias_totales
	main._avanzar_reloj(1.0)
	ok(main.reloj.dias_totales == r0 and main._fases.is_empty(), "_avanzar_reloj en pausa: no pasa ningún día")
	main._poner_velocidad(6)
	var d_ia0: int = ia.dia_n
	var f_ini: String = main.reloj.texto()
	var llamadas := 0
	var vistos_ocupado := false
	while main.reloj.dias_totales - r0 < 60 and llamadas < 400:
		main._avanzar_reloj(0.1)
		vistos_ocupado = vistos_ocupado or main.reloj.ocupado
		llamadas += 1
	ok(main.reloj.dias_totales - r0 >= 60, "_avanzar_reloj a x6: pasan días (%d en %d fotogramas simulados)" % [main.reloj.dias_totales - r0, llamadas])
	ok(main.dias_fot_ult > 0 and main.dias_fot_ult <= main.RelojScript.DIAS_MAX_PASO, "…y anota los días del último paso (%d)" % main.dias_fot_ult)
	main._vaciar_fases()
	ok(ia.dia_n - d_ia0 == main.reloj.dias_totales - r0, "…el reloj y la simulación van a la par: %d días de reloj = %d días de IA" % [main.reloj.dias_totales - r0, ia.dia_n - d_ia0])
	ok(main.reloj.texto() != f_ini and not main.reloj.ocupado, "…la fecha avanzó (%s → %s) y el reloj queda libre" % [f_ini, main.reloj.texto()])
	main._poner_velocidad(0)
	main._fases.clear()


# ───────────────────────── IA: economía, reclutar, buscar guerra, operar ─────────────────────────
func t_ia() -> void:
	print("[T] ── Ia: _economia, _reclutar, _buscar_guerra, _operar")
	cerrar_guerras()
	var nombre := "Francia"
	var e = m.paises[nombre]
	var tid: int = int(e.tid)
	var st: Dictionary = ia.activas[nombre]
	# _economia
	st["foto_dia"] = -1000
	st["foto"] = {}
	st["base_sold"] = -1.0
	var eco: Dictionary = ia._economia(nombre, st, e)
	ok(eco.has_all(["ing", "sold", "mps", "cps", "pob", "tes", "mant", "dias_caja"]), "_economia: ing, sold, mps, cps, pob, tes, mant, dias_caja")
	ok(float(eco["ing"]) > 0.0 and int(eco["sold"]) > 0 and float(eco["mps"]) > 0.0 and float(eco["cps"]) > 0.0, "…Francia: ingresos, soldados y costos positivos (ing %.0f, %d soldados)" % [float(eco["ing"]), int(eco["sold"])])
	ok(absf(float(eco["mant"]) - float(eco["mps"]) * float(eco["sold"])) < 1e-6, "…mantenimiento = costo por soldado × soldados")
	ok(absf(float(eco["dias_caja"]) - float(eco["tes"]) / maxf(float(eco["ing"]), 1.0)) < 1e-9, "…días de caja = tesorería ÷ ingresos")
	ok(float(st["base_sold"]) >= float(eco["sold"]) - 1.0, "…fija el ejército de referencia (%d)" % int(st["base_sold"]))
	ok(int(st["foto_dia"]) == ia.dia_n and not (st["foto"] as Dictionary).is_empty(), "…y guarda la foto con su día")
	st["foto"]["ing"] = 123.0
	var eco2: Dictionary = ia._economia(nombre, st, e)
	ok(float(eco2["ing"]) == 123.0, "la foto se reutiliza mientras no pasen %d días" % ia.DIAS_FOTO_ECONOMIA)
	ia.dia_n += ia.DIAS_FOTO_ECONOMIA
	var eco3: Dictionary = ia._economia(nombre, st, e)
	ok(float(eco3["ing"]) != 123.0 and int(st["foto_dia"]) == ia.dia_n, "…y se rehace al pasar los %d días" % ia.DIAS_FOTO_ECONOMIA)
	var base_ant: float = st["base_sold"]
	ia._economia(nombre, st, e)
	ok(float(st["base_sold"]) == base_ant, "el ejército de referencia no se vuelve a calcular")
	# _reclutar: topes y cupo
	ia._sold_dia_n = -1
	var sold0: int = ej.soldados_de_pais(tid)
	var eco_r: Dictionary = ia._economia(nombre, st, e)
	eco_r["ing"] = 1.0e12
	eco_r["pob"] = 1.0e10
	eco_r["tes"] = 1.0e16
	eco_r["mant"] = 0.0
	eco_r["dias_caja"] = 1000.0
	e.tesoreria = 1.0e16
	st["base_sold"] = float(sold0)
	st["cupo"] = 1.0e9
	st["ult_recl"] = ia.dia_n
	var tope_paz: float = ia.TOPE_PAZ * float(sold0)
	var ritmo: float = tope_paz * ia.CRECE_PAZ_ANUAL / 365.0
	ia._reclutar(nombre, st, e, tid, eco_r, false)
	var sold1: int = ej.soldados_de_pais(tid)
	var nuevos: int = sold1 - sold0
	ok(nuevos > 0, "_reclutar con caja de sobra: recluta (%d soldados)" % nuevos)
	ok(float(nuevos) <= ritmo * float(ia.DIAS_RECLUTA_MAX) + 1.0, "…pero no más que el cupo (CRECE_PAZ_ANUAL del tope, máx. %d días acumulados: %.0f)" % [ia.DIAS_RECLUTA_MAX, ritmo * float(ia.DIAS_RECLUTA_MAX)])
	ok(float(sold1) <= tope_paz + 1.0, "…ni pasa del tope de paz (%.1f × el ejército inicial)" % ia.TOPE_PAZ)
	ok(String(st["ultimo"]).begins_with("Reclutó"), "…y deja constancia: «%s»" % String(st["ultimo"]))
	ok(float(st["cupo"]) < ritmo * float(ia.DIAS_RECLUTA_MAX), "…el cupo se gasta")
	# ya lleno: el cupo no se acumula
	ia._sold_dia_n = -1
	st["base_sold"] = float(ej.soldados_de_pais(tid)) / 2.0
	st["cupo"] = 500.0
	var s_lleno: int = ej.soldados_de_pais(tid)
	ia._reclutar(nombre, st, e, tid, eco_r, false)
	ok(ej.soldados_de_pais(tid) == s_lleno and float(st["cupo"]) == 0.0, "_reclutar con el ejército por encima del tope: no recluta y el cupo vuelve a 0")
	# en guerra el tope es mayor
	ia._sold_dia_n = -1
	st["base_sold"] = float(ej.soldados_de_pais(tid)) / 1.5               # en paz estaría por encima del tope (1,3×); en guerra (2,5×) no
	st["cupo"] = 1.0e9
	st["ult_recl"] = ia.dia_n - 90
	var s_g0: int = ej.soldados_de_pais(tid)
	ia._reclutar(nombre, st, e, tid, eco_r, true)
	ok(ej.soldados_de_pais(tid) > s_g0, "en guerra el tope es de %.1f × y todavía puede reclutar (+%d)" % [ia.TOPE_GUERRA, ej.soldados_de_pais(tid) - s_g0])
	# economía en ruina: licencia soldados
	ia._sold_dia_n = -1
	var eco_p: Dictionary = ia._economia(nombre, st, e)
	eco_p["ing"] = 10.0
	eco_p["mant"] = 1000.0
	eco_p["tes"] = 0.0
	var s_p0: int = ej.soldados_de_pais(tid)
	ia._reclutar(nombre, st, e, tid, eco_p, false)
	ok(ej.soldados_de_pais(tid) < s_p0 and String(st["ultimo"]).begins_with("Licenció"), "_reclutar con el balance negativo y sin caja: licencia soldados antes de que deserten («%s»)" % String(st["ultimo"]).left(30))
	var eco_0: Dictionary = {"ing": 0.0, "sold": 100, "mps": 1.0, "cps": 1.0, "tes": 5.0, "mant": 1.0, "pob": 1000.0, "dias_caja": 5.0}
	var s_0: int = ej.soldados_de_pais(tid)
	ia._reclutar(nombre, st, e, tid, eco_0, false)
	ok(ej.soldados_de_pais(tid) == s_0, "_reclutar sin ingresos: no hace nada")
	# _buscar_guerra
	cerrar_guerras()
	ia._preparar_frentes()
	var n_g0: int = g.activas.size()
	var rico: Dictionary = {"ing": 1000.0, "sold": 50000, "mps": 1.0, "cps": 1.0, "tes": 1.0e6, "mant": 100.0, "pob": 1.0e8, "dias_caja": 1000.0}
	var vec_n := ""
	for nv in ia.vecinos_de(nombre):
		var nn := String(nv)
		if nn != "España" and ia.activas.has(nn) and m.paises.has(nn) and not m.paises[nn].provincias.is_empty():
			vec_n = nn
			break
	var tid_v: int = int(m.paises[vec_n].tid)
	ia._sold_dia_n = ia.dia_n
	ia._sold_dia[tid_v] = 100                                       # el vecino está casi indefenso
	st["cautela"] = 1.0
	st["no_guerra_hasta"] = ia.dia_n + 100
	ia._buscar_guerra(nombre, st, e, tid, rico, [], 100000)
	ok(g.activas.size() == n_g0, "_buscar_guerra durante la gracia (no_guerra_hasta): no declara")
	st["no_guerra_hasta"] = 0
	var pobre: Dictionary = rico.duplicate()
	pobre["dias_caja"] = 5.0
	ia._buscar_guerra(nombre, st, e, tid, pobre, [], 100000)
	ok(g.activas.size() == n_g0, "…con la caja a menos de 25 días: no declara")
	var apretado: Dictionary = rico.duplicate()
	apretado["mant"] = 950.0
	ia._buscar_guerra(nombre, st, e, tid, apretado, [], 100000)
	ok(g.activas.size() == n_g0, "…con el mantenimiento al 95 %% de los ingresos: no declara")
	var chico: Dictionary = rico.duplicate()
	chico["sold"] = 2000
	ia._buscar_guerra(nombre, st, e, tid, chico, [], 100000)
	ok(g.activas.size() == n_g0, "…con menos de 3.000 soldados: no declara")
	ia.registrar_paz(tid, tid_v)
	ia._buscar_guerra(nombre, st, e, tid, rico, [], 100000)
	ok(not g.en_guerra(tid, tid_v), "…con tregua vigente con ese vecino: no lo ataca")
	ia.tregua.clear()
	st["no_guerra_hasta"] = 0
	var dec_g0: int = ia.guerras_declaradas
	var guard_ult: Dictionary = {}
	ia._buscar_guerra(nombre, st, e, tid, rico, [], 100000)
	var declaro: bool = ia.guerras_declaradas == dec_g0 + 1
	if declaro:
		ok(true, "_buscar_guerra: rico, fuerte, sin tregua y con el rival indefenso → declara la guerra (a algún vecino)")
		ok(String(st["ultimo"]).begins_with("Declaró la guerra"), "…y lo anota: «%s»" % String(st["ultimo"]))
		ok(g.rivales_de(tid).size() >= 1 and m.eventos_de(tid, 1)[0]["texto"].contains("declara la guerra"), "…y deja un suceso")
	else:
		ok(false, "_buscar_guerra no declaró aunque todas las condiciones estaban a favor (vecinos: %s)" % str(ia._vecinos_dueno.get(tid, {})))
	# tope global de guerras
	cerrar_guerras()
	var cap: int = maxi(2, int(ceil(float(ia.activas.size()) * ia.FRAC_GUERRAS_GLOBAL)))
	var nombres: Array = []
	for nn in ia.activas:
		if nn != nombre and nn != vec_n:
			nombres.append(nn)
	var i := 0
	while g.activas.size() < cap and i + 1 < nombres.size():
		g.declarar(int(m.paises[nombres[i]].tid), int(m.paises[nombres[i + 1]].tid), "prueba")
		i += 2
	ok(g.activas.size() >= cap, "(se abrieron %d guerras de prueba = el tope global)" % g.activas.size())
	var n_g1: int = g.activas.size()
	ia._buscar_guerra(nombre, st, e, tid, rico, [], 100000)
	ok(g.activas.size() == n_g1, "_buscar_guerra con el tope global de guerras alcanzado (%d de %d): no abre otra" % [n_g1, cap])
	cerrar_guerras()
	# _operar
	ia._operar(nombre, st, tid, [])
	ok(int(st["n_ordenes"]) == 0, "_operar sin guerras: 0 órdenes")
	g.declarar(tid, tid_v, "prueba")
	ia._preparar_frentes()
	var frente: Array = ia._frente_de(tid)
	var base_prov := -1
	for par in frente:
		if int(ia._ctrl[int(par[1])]) == tid_v:
			base_prov = int(par[0])
			break
	ok(base_prov >= 0, "(Francia tiene frontera con %s)" % vec_n)
	if base_prov >= 0:
		ej.reclutar(tid, int(m.provincias[base_prov].tid), 40000, "prueba")
		var rutas0: int = ia.n_rutas
		ia._operar(nombre, st, tid, [tid_v])
		ok(int(st["n_ordenes"]) <= ia.MAX_ORDENES, "_operar: respeta el máximo de órdenes por decisión (%d ≤ %d)" % [int(st["n_ordenes"]), ia.MAX_ORDENES])
		ok(int(st["n_ordenes"]) >= 1 and ia.n_rutas == rutas0 + int(st["n_ordenes"]), "…da órdenes de marcha contra el rival (%d) y las cuenta en `n_rutas`" % int(st["n_ordenes"]))
		ok(int(st["base"]) >= 0, "…y fija la provincia desde la que recluta («base»)")
		ok(ej.marchas.size() >= int(st["n_ordenes"]), "…las columnas existen en el ejército")
	cerrar_guerras()


# ───────────────────────── Guerra: ocupaciones por pasos ─────────────────────────
func t_ocupaciones() -> void:
	print("[T] ── Guerra: _avanzar_ocupaciones")
	cerrar_guerras()
	var v := vecino_grande()
	var a: int = v[0]
	var b: int = v[1]
	var libres: Array = []                                           # provincias del rival sin tropas
	for pi in m.paises[v[2]].provincias:
		var pt: int = int(m.provincias[int(pi)].tid)
		if ej.regs_prov.get(pt, []).is_empty():
			libres.append(pt)
		if libres.size() >= 3:
			break
	ok(libres.size() >= 3, "hay 3 provincias del rival sin tropas para probar")
	if libres.size() < 3:
		return
	g.declarar(a, b, "prueba")
	for pt in libres:
		ej.reclutar(a, int(pt), 3000, "prueba")
	g.ocup_prog.clear()
	g._revisar_ocupacion(int(libres[0]), a)
	ok(g.ocup_prog.has(int(libres[0])) and int(g.ocup_prog[int(libres[0])]["por"]) == a, "_revisar_ocupacion: tropas solas en provincia enemiga → empieza a ocuparla")
	g._avanzar_ocupaciones(2)
	ok(g.ocup_prog.has(int(libres[0])) and int(g.ocup_prog[int(libres[0])]["dias"]) == 2 and int(g.bd.ref("ocupante", int(libres[0]))) < 0, "_avanzar_ocupaciones(2): lleva 2 días de %d y aún no la ocupa" % g.DIAS_OCUPACION)
	g._avanzar_ocupaciones(1)
	ok(not g.ocup_prog.has(int(libres[0])) and int(g.bd.ref("ocupante", int(libres[0]))) == a, "_avanzar_ocupaciones(1): al 3.er día la ocupa (el ocupante es el atacante)")
	var n_ev: int = m.eventos.size()
	g.ocup_prog[int(libres[1])] = {"por": a, "dias": 0}
	g._avanzar_ocupaciones(3)
	ok(int(g.bd.ref("ocupante", int(libres[1]))) == a and not g.ocup_prog.has(int(libres[1])), "un paso de 3 días ocupa de una vez")
	ok(m.eventos.size() > n_ev, "…y la ocupación deja un suceso")
	g.paz(a, b, "prueba")                                           # sin guerra ya no se puede ocupar
	g.ocup_prog[int(libres[2])] = {"por": a, "dias": 1}             # (la paz ya había limpiado las ocupaciones: se vuelve a poner una a medias)
	var v0: int = g.version
	g._avanzar_ocupaciones(1)
	ok(not g.ocup_prog.has(int(libres[2])) and int(g.bd.ref("ocupante", int(libres[2]))) < 0 and g.version > v0, "una ocupación en marcha se cancela si ya no hay guerra")
	cerrar_guerras()


# ───────────────────────── HUD: sección «Declarar la guerra» ─────────────────────────
func botones_de(nodo: Node, prefijo: String) -> Array:
	var r := []
	for b in nodo.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefijo):
			r.append(b)
	return r


func t_diplomacia() -> void:
	print("[T] ── HUD: _tab_diplomacia")
	var hud = main.hud
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	await esperar(0.4)
	hud.abrir_pestana("diplomacia")
	await esperar(0.3)
	var vista: Dictionary = main.diplomacia_vista()
	var n_decl: int = (vista["declarables"] as Array).size()
	var bs: Array = botones_de(hud.cuerpo, "Declarar la guerra a")
	ok(n_decl > 0 and bs.size() == n_decl, "ficha propia: un botón «Declarar la guerra a…» por vecino declarable (%d de %d)" % [bs.size(), n_decl])
	var habil := 0
	for b in bs:
		if not (b as Button).disabled:
			habil += 1
	ok(habil > 0, "…y al menos uno activo (%d)" % habil)
	# ficha ajena
	main._seleccion_pais("Francia", "Europa", Vector2(800, 300))
	await esperar(0.4)
	hud.abrir_pestana("diplomacia")
	await esperar(0.3)
	var b_f: Array = botones_de(hud.cuerpo, "Declarar la guerra a Francia")
	ok(b_f.size() == 1 and not (b_f[0] as Button).disabled, "ficha de Francia (sin guerra con ella): sección «Relación contigo» con 1 botón activo")
	var hay_rel := false
	for l in hud.cuerpo.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("En paz con"):
			hay_rel = true
	ok(hay_rel, "…y la fila «En paz con Francia»")
	# en guerra: ya no hay botón y se explica
	var jt: int = int(m.paises["España"].tid)
	var ft: int = int(m.paises["Francia"].tid)
	g.declarar(jt, ft, "prueba")
	hud.abrir_pestana("diplomacia")
	main._seleccion_pais("Francia", "Europa", Vector2(800, 300))
	await esperar(0.4)
	hud.abrir_pestana("diplomacia")
	await esperar(0.3)
	ok(botones_de(hud.cuerpo, "Declarar la guerra a Francia").is_empty(), "en guerra con Francia: desaparece el botón de declarar")
	var dice_guerra := false
	for l in hud.cuerpo.find_children("*", "Label", true, false):
		if (l as Label).text.contains("EN GUERRA con"):
			dice_guerra = true
	ok(dice_guerra, "…y la ficha dice «EN GUERRA con…»")
	cerrar_guerras()
	# tregua visible
	ia.registrar_paz(jt, ft)
	hud.abrir_pestana("diplomacia")
	await esperar(0.3)
	var b_t: Array = botones_de(hud.cuerpo, "Declarar la guerra a Francia")
	ok(b_t.size() == 1 and not (b_t[0] as Button).disabled, "con tregua: el botón de la ficha de Francia sigue activo (el jugador puede romperla)")
	var hay_nota := false
	for l in hud.cuerpo.find_children("*", "Label", true, false):
		if (l as Label).text.begins_with("Hay una tregua"):
			hay_nota = true
	ok(hay_nota, "…y una nota explica que la IA no declarará guerra durante la tregua")
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	await esperar(0.4)
	hud.abrir_pestana("diplomacia")
	await esperar(0.3)
	var b_t2: Array = botones_de(hud.cuerpo, "Declarar la guerra a Francia")
	ok(b_t2.size() == 1 and (b_t2[0] as Button).text.contains("tregua: 5 años") and not (b_t2[0] as Button).disabled, "en tu ficha, el botón de Francia dice la tregua que queda y sigue activo: «%s»" % (b_t2[0] as Button).text if b_t2.size() == 1 else "sin botón")
	ia.tregua.clear()


# ───────────────────────── Órdenes de tropas del jugador ─────────────────────────
func t_ordenes() -> void:
	print("[T] ── MapaPrincipal: _mandar_tropas")
	cerrar_guerras()
	var v := vecino_grande()
	var jt: int = v[0]
	var ft: int = v[1]
	var hud = main.hud
	var rid := -1
	for r in ej.regs_pais.get(jt, []):
		if not ej.en_marcha_reg(int(r)) and ej.soldados_reg(int(r)) > 0:
			rid = int(r)
			break
	var pi_ajena: int = int(m.paises[v[2]].provincias[0])
	var n_marchas: int = ej.marchas.size()
	main._mandar_tropas(rid, pi_ajena)
	ok(ej.marchas.size() == n_marchas and String(main.avisos.ultimo_texto).begins_with("No estás en guerra con"), "_mandar_tropas a territorio ajeno sin guerra: se bloquea con el aviso (no sale ninguna columna)")
	main._mandar_tropas(rid, -1)
	ok(String(main.avisos.ultimo_texto).begins_with("Eso es mar"), "_mandar_tropas a un punto de mar: avisa")
	var origen: int = int(ej._prov_de_tid[ej.prov_de(rid)].idx)
	main._mandar_tropas(rid, origen)
	ok(String(main.avisos.ultimo_texto).contains("ya están en esa provincia"), "_mandar_tropas a la provincia donde ya están: avisa")
	# regimiento ajeno
	var rid_f := -1
	for r in ej.regs_pais.get(ft, []):
		rid_f = int(r)
		break
	if rid_f >= 0:
		main._mandar_tropas(rid_f, origen)
		ok(String(main.avisos.ultimo_texto).begins_with("Esas tropas no son tuyas"), "_mandar_tropas con tropas de otro país: «no son tuyas»")
	main._mandar_tropas(-999, origen)
	ok(ej.marchas.size() == n_marchas, "_mandar_tropas con un regimiento que no existe: no hace nada (y no se rompe)")
	# con guerra declarada, la orden sale
	g.declarar(jt, ft, "prueba")
	main._mandar_tropas(rid, pi_ajena)
	ok(ej.marchas.size() == n_marchas + 1, "_mandar_tropas en guerra: la columna sale")
	var rid_marcha: int = -1
	for mm in ej.marchas.values():
		rid_marcha = int(mm["reg"])
	main._mandar_tropas(rid_marcha, pi_ajena)
	ok(String(main.avisos.ultimo_texto).contains("ya va en marcha") and ej.marchas.size() == n_marchas + 1, "…y no se puede ordenar dos veces a una columna que ya marcha")
	cerrar_guerras()


# ───────────────────────── HUD de tropas: página de regimientos ─────────────────────────
func t_hud_tropas() -> void:
	print("[T] ── HUD de tropas: _pagina_reg, _filtrar")
	var hud = main.hud
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	await esperar(0.4)
	hud.abrir_pestana("militar")
	hud.abrir_militar("reg")
	await esperar(0.5)
	var tr = hud.tropas
	ok(tr.pestana == "reg" and (tr.paginas["reg"] as Control).visible and not (tr.paginas["rec"] as Control).visible, "Militar > Regimientos: solo está visible la página «reg»")
	ok(tr.sc_lista != null and tr.caja_lista != null and cerca_f(tr.sc_lista.custom_minimum_size.y, 112.0) and tr.sc_lista.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "_pagina_reg: la lista tiene su propio scroll vertical (112 px mínimo, sin barra horizontal)")
	ok(tr.btn_mover != null and tr.btn_dividir != null and tr.btn_parar != null and tr.btn_unir != null and tr.btn_disolver != null, "…con los botones Mover, Dividir, Detener, Unir y Disolver")
	ok(tr.btn_mover.tooltip_text.contains("estar en guerra"), "…y el tooltip de «Mover…» explica que para entrar en otro país hay que estar en guerra")
	ok(tr.puede_ordenar and tr.caja_lista.get_child_count() >= 1, "con tu país: puedes ordenar y la lista tiene regimientos (%d filas)" % tr.caja_lista.get_child_count())
	tr._filtrar(true)
	ok(tr.filtro_todos, "_filtrar(true): «Todo el país»")
	var filas_todo: int = tr.caja_lista.get_child_count()
	tr._filtrar(false)
	ok(not tr.filtro_todos and tr.caja_lista.get_child_count() <= filas_todo, "_filtrar(false): «Esta provincia» (no hay más filas que con todo el país: %d ≤ %d)" % [tr.caja_lista.get_child_count(), filas_todo])
	main._seleccion_pais("Francia", "Europa", Vector2(800, 300))
	await esperar(0.4)
	hud.abrir_pestana("militar")
	await esperar(0.3)
	ok(not tr.puede_ordenar, "con el país de otro: no puedes ordenar sus tropas (campaña)")
	main._seleccion_pais("España", "Europa", Vector2(700, 300))
	await esperar(0.3)
	hud.abrir_pestana("militar")
	m.fijar_jugador("")
	await esperar(0.5)
	tr._refrescar(true)
	ok(not tr.puede_ordenar, "como observador de campaña: nadie da órdenes")
	m.fijar_jugador("España")
	hud.abrir_pestana("general")


func cerca_f(a: float, b: float) -> bool:
	return absf(a - b) < 1e-6


# ───────────────────────── Preparar campaña ─────────────────────────
func t_campana() -> void:
	print("[T] ── MapaPrincipal: _preparar_campana")
	main._preparar_campana("Francia", 1)
	ok(m.es_campana() and m.jugador == "Francia", "_preparar_campana(Francia): modo campaña y jugador Francia")
	ok(not ia.activas.has("Francia") and ia.activas.has("España"), "…Francia sin IA y todos los demás con IA")
	var cand: Array = ia.candidatos()
	ok(ia.activas.size() == cand.size(), "…IA en todos los candidatos (%d)" % ia.activas.size())
	main._preparar_campana("", 1)
	ok(m.jugador == "" and m.ve_todo() and ia.activas.has("Francia") and ia.activas.has("España"), "_preparar_campana(\"\"): observador, la IA lleva a todos (%d)" % ia.activas.size())
	ok(ia.activas.size() == ia.candidatos().size(), "…y la IA lleva a todos los candidatos (%d)" % ia.activas.size())


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
	t_reloj()
	t_ia()
	t_ocupaciones()
	await t_diplomacia()
	t_ordenes()
	await t_hud_tropas()
	t_campana()
	print("[T] ── %d comprobaciones OK · FALLOS: %d" % [n_ok, fallos])
	get_tree().quit()
