extends Node
## 0.1.8.47 · DEMOGRAFÍA VIVA (scripts/demografia.gd + scripts/indices_saber.gd): calibración por época, invariantes, determinismo, fatiga de guerra,
## presupuesto neto, economía según el saber, estabilidad y coste.
var main
var fallos := 0
var n_ok := 0
const DemoScript := preload("res://scripts/demografia.gd")
const IndicesScript := preload("res://scripts/indices_saber.gd")


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


## Medias del mundo ponderadas por población.
func agregados() -> Dictionary:
	var m = main.mundo
	var bd = m.bd
	var pob: PackedFloat64Array = bd.vars["poblacion"].col_f
	var nat: PackedFloat64Array = bd.vars["natalidad"].col_f
	var mor: PackedFloat64Array = bd.vars["mortalidad"].col_f
	var urb: PackedFloat64Array = bd.vars["urbanizacion"].col_f
	var alf: PackedFloat64Array = bd.vars["alfabetizacion"].col_f
	var bie: PackedFloat64Array = bd.vars["bienestar"].col_f
	var jov: PackedFloat64Array = bd.vars["edad_joven"].col_f
	var may: PackedFloat64Array = bd.vars["edad_mayor"].col_f
	var r := {"pob": 0.0, "nat": 0.0, "mor": 0.0, "urb": 0.0, "alf": 0.0, "bie": 0.0, "jov": 0.0, "may": 0.0, "malas": 0, "n": 0}
	for pr in m.provincias:
		var k: int = pr.ix
		if is_nan(pob[k]) or pob[k] <= 0.0:
			continue
		if is_nan(nat[k]):
			continue
		var p: float = pob[k]
		r["n"] += 1
		r["pob"] += p
		r["nat"] += p * nat[k]
		r["mor"] += p * mor[k]
		r["urb"] += p * urb[k]
		r["alf"] += p * alf[k]
		r["bie"] += p * bie[k]
		r["jov"] += p * jov[k]
		r["may"] += p * may[k]
		if is_inf(p) or is_nan(mor[k]) or is_nan(urb[k]) or is_nan(alf[k]) or is_nan(bie[k]) or is_nan(jov[k]) or is_nan(may[k]):
			r["malas"] += 1
		elif urb[k] < 0.0 or urb[k] > 1.0 or alf[k] < 0.0 or alf[k] > 1.0 or bie[k] < 0.0 or bie[k] > 100.0 or jov[k] < 0.0 or may[k] < 0.0 or jov[k] + may[k] > 0.95:
			r["malas"] += 1
	var t: float = maxf(float(r["pob"]), 1.0)
	for c in ["nat", "mor", "urb", "alf", "bie", "jov", "may"]:
		r[c] = float(r[c]) / t
	r["crec"] = (float(r["nat"]) - float(r["mor"])) / 10.0              # % al año
	return r


## Simula `anios` años solo con las fases del día (sin reloj): rápido.
func simular(anios: int) -> void:
	var m = main.mundo
	for _a in anios:
		for _i in 12:
			m.avanzar_dias(30)
		m.avanzar_dias(5)


func run() -> void:
	t_modelo_puro()
	await t_calibracion()
	await t_invariantes_y_coste()
	await t_fatiga()
	t_presupuesto()
	t_economia_y_saber()
	await t_estabilidad()
	await t_determinismo()
	await t_salto_de_fecha()
	print("[T] ═══ RESULTADO runner104: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ─────────────────────────────────────────────────────────────
func t_modelo_puro() -> void:
	print("[T] ── El modelo (funciones puras)")
	var a: float = DemoScript.acceso(300.0)
	var b: float = DemoScript.acceso(60000.0)
	ok(a == 0.0 and absf(b - 1.0) < 1.0e-6 and DemoScript.acceso(5000.0) > DemoScript.acceso(1000.0), "acceso: 300 US$ → 0, 60.000 US$ → 1 y crece con la renta")
	# la natalidad baja con la escuela y la ciudad; sube con el bienestar
	var n0: float = DemoScript.natalidad_de(0.1, 0.0, 0.05, 0.1, 50.0, 0.0)
	var n1: float = DemoScript.natalidad_de(0.1, 0.9, 0.05, 0.1, 50.0, 0.0)
	var n2: float = DemoScript.natalidad_de(0.1, 0.0, 0.8, 0.1, 50.0, 0.0)
	ok(n1 < n0 - 8.0 and n2 < n0 - 2.0, "la alfabetización y la urbanización bajan la natalidad (%.1f → %.1f / %.1f ‰)" % [n0, n1, n2])
	ok(DemoScript.natalidad_de(0.5, 0.5, 0.5, 0.5, 90.0, 0.0) > DemoScript.natalidad_de(0.5, 0.5, 0.5, 0.5, 20.0, 0.0), "el bienestar sube la natalidad")
	ok(DemoScript.natalidad_de(1.0, 1.0, 1.0, 1.0, 100.0, 0.0) >= DemoScript.NAT_MIN, "la natalidad nunca baja del mínimo")
	# mortalidad: baja con la medicina (salto moderno), sube con hambre, guerra y viejos
	var m_sin: float = DemoScript.mortalidad_de(0.05, 0.03, 60.0, 0.0, false, 0.2, 0.3)
	var m_med: float = DemoScript.mortalidad_de(0.95, 0.03, 60.0, 0.0, false, 0.2, 0.3)
	ok(m_sin > 33.0 and m_med < 12.0, "sin medicina se muere ~40 ‰ y con la medicina de hoy ~8 ‰ (%.1f → %.1f)" % [m_sin, m_med])
	ok(DemoScript.mortalidad_de(0.5, 0.03, 10.0, 0.0, false, 0.2, 0.3) > DemoScript.mortalidad_de(0.5, 0.03, 70.0, 0.0, false, 0.2, 0.3) + 5.0, "el hambre (bienestar bajo) sube la mortalidad")
	ok(DemoScript.mortalidad_de(0.5, 0.03, 60.0, 0.5, false, 0.2, 0.3) > DemoScript.mortalidad_de(0.5, 0.03, 60.0, 0.0, false, 0.2, 0.3) + 10.0, "la devastación sube la mortalidad")
	ok(DemoScript.mortalidad_de(0.5, 0.25, 60.0, 0.0, false, 0.2, 0.3) > DemoScript.mortalidad_de(0.5, 0.03, 60.0, 0.0, false, 0.2, 0.3) * 1.5, "un país viejo muere más que uno joven")
	ok(DemoScript.mortalidad_de(0.5, 0.03, 60.0, 0.0, false, 1.6, 0.1) > DemoScript.mortalidad_de(0.5, 0.03, 60.0, 0.0, false, 0.2, 0.1) + 5.0, "pasar el límite de lo que da la tierra (agricultura primitiva) sube la mortalidad")
	ok(DemoScript.mortalidad_de(0.5, 0.03, 60.0, 0.0, false, 1.6, 0.9) < DemoScript.mortalidad_de(0.5, 0.03, 60.0, 0.0, false, 0.2, 0.9) + 0.5, "…pero no con agricultura moderna (el freno solo es de sociedades agrarias)")
	# estructura de edad
	ok(DemoScript.joven_objetivo(40.0) > 0.35 and DemoScript.joven_objetivo(10.0) < 0.2 and DemoScript.mayor_objetivo(10.0) > 0.15 and DemoScript.mayor_objetivo(40.0) < 0.06, "natalidad alta = país joven; baja = país viejo")
	ok(DemoScript.activa_de(0.4, 0.03) < DemoScript.activa_de(0.2, 0.1) and DemoScript.activa_de(0.5, 0.5) == 0.0, "la gente en edad de trabajar sale de los adultos")
	# acercar: exacto para cualquier tamaño de paso
	var x1: float = DemoScript.acercar(0.0, 1.0, 10.0, 20.0)
	var x2: float = DemoScript.acercar(DemoScript.acercar(0.0, 1.0, 5.0, 20.0), 1.0, 5.0, 20.0)
	ok(absf(x1 - x2) < 1.0e-9, "acercar: un paso de 10 años = dos de 5 (da lo mismo revisar cada mes que cada año)")
	# educación: más gasto y más instituciones, más alfabetización
	var f0: float = DemoScript.alfabetizacion_objetivo(0.8, 0.5, 0.2, 1.0)
	var f1: float = DemoScript.alfabetizacion_objetivo(0.8, 0.5, 2.0, 1.0)
	var f2: float = DemoScript.alfabetizacion_objetivo(0.8, 0.5, 1.0, DemoScript.efecto_instituciones(40.0, 100000.0))
	var f3: float = DemoScript.alfabetizacion_objetivo(0.8, 0.5, 1.0, DemoScript.efecto_instituciones(0.0, 100000.0))
	ok(f1 > f0 + 0.03 and f2 > f3 + 0.03, "más gasto en educación y más escuelas por habitante = más alfabetización (%.2f vs %.2f · %.2f vs %.2f)" % [f1, f0, f2, f3])
	ok(DemoScript.alfabetizacion_objetivo(0.0, 0.0, 1.0, 1.0) == 0.0 and DemoScript.alfabetizacion_objetivo(1.0, 1.0, 2.5, 1.2) <= 0.995, "sin saber de educación no hay alfabetización; nunca pasa de 99,5 %")
	ok(DemoScript.escolaridad_objetivo(0.0, 1.0) == 0.0 and DemoScript.escolaridad_objetivo(0.95, 1.0) > 10.0, "años de escuela: 0 sin alfabetización, más de 10 en un país culto y rico")
	# bienestar
	ok(DemoScript.bienestar_objetivo(0.9, 0.8, 0.8, 0.0, false, false, 0.2) > 75.0 and DemoScript.bienestar_objetivo(0.1, 0.0, 0.0, 0.0, false, false, 0.2) < 55.0, "el bienestar sube con agricultura, renta y salud")
	ok(DemoScript.bienestar_objetivo(0.5, 0.5, 0.5, 0.8, true, true, 0.2) < DemoScript.bienestar_objetivo(0.5, 0.5, 0.5, 0.0, false, false, 0.2) - 40.0, "la devastación y la ocupación hunden el bienestar")
	# riqueza según el saber
	ok(DemoScript.factor_economia_de(0.98) == 1.0 and DemoScript.factor_economia_de(0.19) < 0.05 and DemoScript.factor_economia_de(0.4) > DemoScript.factor_economia_de(0.3) and DemoScript.factor_economia_de(0.0) >= DemoScript.ECO_MIN, "la economía crece según el saber: 1 con todo el saber de hoy, ~0 en el año 1")


# ─────────────────────────────────────────────────────────────
func t_calibracion() -> void:
	print("[T] ── Calibración por época: el mismo modelo da el mundo antiguo y el de hoy")
	await arrancar(1)
	var a1 := agregados()
	print("[T] INFO  año 1: pob %.1f M · nat %.1f · mort %.1f · crec %.2f %% · urb %.0f %% · alfab %.0f %%" % [float(a1["pob"]) / 1.0e6, a1["nat"], a1["mor"], a1["crec"], 100.0 * float(a1["urb"]), 100.0 * float(a1["alf"])])
	ok(float(a1["pob"]) > 200.0e6 and float(a1["pob"]) < 320.0e6, "año 1: ~250 M de habitantes (%.0f M)" % (float(a1["pob"]) / 1.0e6))
	ok(float(a1["nat"]) > 34.0 and float(a1["nat"]) < 45.0 and float(a1["mor"]) > 33.0 and float(a1["mor"]) < 45.0, "año 1: natalidad y mortalidad de ~40 ‰ (%.1f / %.1f)" % [a1["nat"], a1["mor"]])
	ok(absf(float(a1["crec"])) < 0.2, "año 1: el mundo casi no crece (%.2f %% al año)" % float(a1["crec"]))
	ok(float(a1["urb"]) < 0.15 and float(a1["alf"]) < 0.10 and float(a1["may"]) < 0.06, "año 1: casi todos en el campo, casi nadie sabe leer, pocos mayores")
	var p0 := float(a1["pob"])
	simular(50)
	var a1b := agregados()
	var g50: float = 100.0 * (pow(float(a1b["pob"]) / p0, 1.0 / 50.0) - 1.0)
	ok(absf(g50) < 0.2 and float(a1b["pob"]) > 0.85 * p0 and float(a1b["pob"]) < 1.2 * p0, "año 1 + 50 años: la población se mantiene (%.2f %% al año, %.0f M)" % [g50, float(a1b["pob"]) / 1.0e6])
	await arrancar(1096)
	var a2 := agregados()
	ok(float(a2["pob"]) > 300.0e6 and float(a2["pob"]) < 480.0e6 and absf(float(a2["crec"])) < 0.3, "1096: ~400 M y casi sin crecer (%.0f M, %.2f %%)" % [float(a2["pob"]) / 1.0e6, float(a2["crec"])])
	await arrancar(1500)
	var a3 := agregados()
	ok(float(a3["pob"]) > 400.0e6 and float(a3["pob"]) < 560.0e6 and absf(float(a3["crec"])) < 0.3, "1500: ~470 M y casi sin crecer (%.0f M, %.2f %%)" % [float(a3["pob"]) / 1.0e6, float(a3["crec"])])
	ok(float(a3["urb"]) < 0.20 and float(a3["alf"]) < 0.25, "1500: pocas ciudades y poca escuela (%.0f %% / %.0f %%)" % [100.0 * float(a3["urb"]), 100.0 * float(a3["alf"])])
	await arrancar(2026)
	var a4 := agregados()
	print("[T] INFO  2026: pob %.0f M · nat %.1f · mort %.1f · crec %.2f %% · urb %.0f %% · alfab %.0f %% · bienestar %.0f" % [float(a4["pob"]) / 1.0e6, a4["nat"], a4["mor"], a4["crec"], 100.0 * float(a4["urb"]), 100.0 * float(a4["alf"]), a4["bie"]])
	ok(float(a4["nat"]) > 12.0 and float(a4["nat"]) < 20.0 and float(a4["mor"]) > 6.0 and float(a4["mor"]) < 11.0, "2026: natalidad ~16 ‰ y mortalidad ~8 ‰ (%.1f / %.1f)" % [a4["nat"], a4["mor"]])
	ok(float(a4["crec"]) > 0.4 and float(a4["crec"]) < 1.0, "2026: el mundo crece ~0,7 %% al año (%.2f %%)" % float(a4["crec"]))
	ok(float(a4["alf"]) > 0.80 and float(a4["alf"]) < 0.94 and float(a4["urb"]) > 0.55 and float(a4["urb"]) < 0.72, "2026: ~87 %% alfabetizado y ~64 %% urbano (%.0f %% / %.0f %%)" % [100.0 * float(a4["alf"]), 100.0 * float(a4["urb"])])
	ok(float(a4["jov"]) > 0.14 and float(a4["jov"]) < 0.24 and float(a4["may"]) > 0.08 and float(a4["may"]) < 0.20, "2026: ~18 %% niños y ~14 %% mayores")
	var p26 := float(a4["pob"])
	simular(10)
	var a4b := agregados()
	var g10: float = 100.0 * (pow(float(a4b["pob"]) / p26, 1.0 / 10.0) - 1.0)
	ok(g10 > 0.3 and g10 < 1.1 and int(a4b["malas"]) == 0, "2026 + 10 años: sigue creciendo ~0,7 %% al año (%.2f %%) y los datos siguen sanos" % g10)


# ─────────────────────────────────────────────────────────────
func t_invariantes_y_coste() -> void:
	print("[T] ── Invariantes, coste y consultas")
	var m = main.mundo
	var dm = m.demografia
	ok(dm != null and dm.listo and dm.idx != null, "la demografía arranca con la partida")
	simular(4)
	var a := agregados()
	ok(int(a["malas"]) == 0, "tras 4 años no hay NaN, infinitos ni valores fuera de rango (%d malos de %d provincias)" % [int(a["malas"]), int(a["n"])])
	ok(dm.vueltas >= 3 and dm.revisadas >= m.provincias.size() * 2, "cada provincia se revisó varias veces (%d vueltas, %d revisiones)" % [dm.vueltas, dm.revisadas])
	ok(absf(dm.mundo_hab - float(a["pob"])) / float(a["pob"]) < 0.05, "la población mundial publicada coincide con la suma (%.0f M vs %.0f M)" % [dm.mundo_hab / 1.0e6, float(a["pob"]) / 1.0e6])
	# coste: la fase del día
	var dias: float = float(dm.vueltas) * float(DemoScript.CICLO_DIAS)
	var us_dia: float = float(dm.usec_total) / maxf(dias, 1.0)
	print("[T] INFO  demografía: %.0f µs por día de juego · lote máximo %.2f ms" % [us_dia, dm.ms_max])
	ok(us_dia < 1500.0 and dm.ms_max < 10.0, "la fase cuesta poco: %.0f µs/día y %.2f ms de lote como máximo" % [us_dia, dm.ms_max])
	var t0 := Time.get_ticks_msec()
	dm.sembrar()
	var t_siembra := Time.get_ticks_msec() - t0
	ok(t_siembra < 1500, "sembrar toda la partida cuesta %d ms" % t_siembra)
	# consultas
	var tid_de_pais: int = -1
	var mejor := 0.0
	for nombre in m.paises:
		var pp: float = dm.poblacion_pais(int(m.paises[nombre].tid))
		if pp > mejor:
			mejor = pp
			tid_de_pais = int(m.paises[nombre].tid)
	ok(tid_de_pais >= 0 and mejor > 1.0e8, "el país más poblado tiene más de 100 M (%.0f M)" % (mejor / 1.0e6))
	var cr: float = dm.crecimiento_pais(tid_de_pais)
	ok(not is_nan(cr) and absf(cr) < 0.05, "el crecimiento de un país es razonable (%.2f %%)" % (cr * 100.0))
	ok(absf(dm.crecimiento_mundo() * 100.0 - float(a["crec"])) < 0.15, "el crecimiento del mundo publicado coincide con el medido (%.2f %% vs %.2f %%)" % [dm.crecimiento_mundo() * 100.0, float(a["crec"])])
	var pi0: int = -1
	var col_pob: PackedFloat64Array = m.bd.vars["poblacion"].col_f
	for i in m.provincias.size():
		var ix: int = m.provincias[i].ix
		if not is_nan(col_pob[ix]) and col_pob[ix] > 1.0e6:
			pi0 = i
			break
	var res: Dictionary = dm.resumen_provincias([pi0])
	ok(float(res["pob"]) > 1.0e6 and float(res["alfabetizacion"]) > 0.0 and float(res["activa"]) > 0.3 and float(res["activa"]) < 0.7, "el resumen de una provincia trae población, alfabetización y gente activa (%.0f %%)" % (100.0 * float(res["activa"])))
	var act_pais: float = dm.activa_pais(tid_de_pais)
	ok(act_pais > 0.3 * dm.poblacion_pais(tid_de_pais) and act_pais < 0.7 * dm.poblacion_pais(tid_de_pais), "la gente activa de un país es una parte de su población (%.0f %%)" % (100.0 * act_pais / dm.poblacion_pais(tid_de_pais)))
	var nom_pais := ""
	for nombre in m.paises:
		if int(m.paises[nombre].tid) == tid_de_pais:
			nom_pais = String(nombre)
	ok(absf(m.poblacion_activa_de(nom_pais) - act_pais) < 1.0, "Mundo.poblacion_activa_de lee la demografía")
	var todas := []
	for i in m.provincias.size():
		todas.append(i)
	var r_todas: Dictionary = dm.resumen_provincias(todas)
	ok(absf(float(r_todas["pob"]) - float(a["pob"])) / float(a["pob"]) < 0.001, "resumen de todas las provincias = población del mundo")
	# índices de saber
	var v: PackedFloat32Array = dm.idx.de(tid_de_pais, 0)
	ok(v.size() == IndicesScript.N_IDX and v[0] > 0.8 and v[1] > 0.8 and v[2] > 0.8 and v[3] > 0.8, "en 2026 los 4 índices de saber están por encima de 0,8 (%.2f %.2f %.2f %.2f)" % [v[0], v[1], v[2], v[3]])
	ok(dm.idx.campo("MED").size() > 10 and dm.idx.campo("CIE.COM").size() > 10 and dm.idx.campo("SOC.COM").size() > 10 and dm.idx.campo("CIE.COM") != dm.idx.campo("SOC.COM") and dm.idx.campo("XXX").is_empty(), "campos del catálogo: MED, Computación (CIE.COM) y Comunicación (SOC.COM) existen y son distintos; uno inventado está vacío")
	ok(dm.idx.fraccion_campo(tid_de_pais, "MED") > 0.8 and dm.idx.fraccion_campo(tid_de_pais, "XXX") == 0.0, "fracción conocida de un campo")


# ─────────────────────────────────────────────────────────────
func t_fatiga() -> void:
	print("[T] ── Fatiga de guerra")
	await arrancar(2026)
	var m = main.mundo
	var dm = m.demografia
	var bd = m.bd
	var pais := "Colombia"
	ok(m.paises.has(pais), "existe el país de prueba")
	var tid: int = int(m.paises[pais].tid)
	var p = m.paises[pais]
	ok(p.fatiga_guerra == 0.0, "al empezar nadie está cansado de la guerra")
	bd.poner_f("guerras_activas", tid, 1.0)
	for _i in 5:
		m.avanzar_dias(30)
	var f1: float = p.fatiga_guerra
	ok(f1 > 5.0 and f1 < 40.0, "tras 5 meses en guerra la fatiga sube (%.1f)" % f1)
	dm.registrar_bajas(tid, 2000000)
	for _i in 2:
		m.avanzar_dias(30)
	var f2: float = p.fatiga_guerra
	ok(f2 > f1 + 15.0, "las bajas suben la fatiga de golpe (%.1f → %.1f)" % [f1, f2])
	ok(f2 <= 100.0, "la fatiga nunca pasa de 100")
	bd.poner_f("guerras_activas", tid, 0.0)
	for _i in 12:
		m.avanzar_dias(30)
	var f3: float = p.fatiga_guerra
	ok(f3 < f2 * 0.6, "en paz la fatiga baja (%.1f → %.1f tras un año)" % [f2, f3])
	for _i in 36:
		m.avanzar_dias(30)
	ok(p.fatiga_guerra < 3.0, "…y desaparece tras unos años de paz (%.1f)" % p.fatiga_guerra)
	var otro = m.paises["Argentina"] if m.paises.has("Argentina") else null
	ok(otro == null or otro.fatiga_guerra == 0.0, "los países en paz no se cansan por la guerra de otros")


# ─────────────────────────────────────────────────────────────
func t_presupuesto() -> void:
	print("[T] ── Presupuesto por partidas")
	var m = main.mundo
	var p = m.paises["Colombia"]
	p.gasto_educacion = 0.04
	p.gasto_ciencia = 0.015
	p.gasto_obras = 0.025
	p.gasto_sanidad = 0.02
	ok(absf(p.gasto_total() - 0.10) < 1.0e-9, "las partidas de referencia suman 10 %")
	var bruto: float = m.ingreso_diario_local("Colombia")
	var neto: float = m.ingreso_neto_diario_local("Colombia")
	ok(bruto > 0.0 and absf(neto - bruto * 0.9) < bruto * 1.0e-6, "con el 10 %% de partidas llega el 90 %% de los impuestos (%.0f de %.0f)" % [neto, bruto])
	p.gasto_educacion = 0.3
	p.gasto_ciencia = 0.3
	p.gasto_obras = 0.3
	p.gasto_sanidad = 0.3
	ok(absf(p.gasto_total() - 0.6) < 1.0e-9, "todas las partidas juntas no pasan del 60 %")
	ok(m.ingreso_neto_diario_local("Colombia") >= bruto * 0.39, "siempre llega al menos el 40 %% de los impuestos")
	p.gasto_educacion = 5.0
	ok(p.gasto_educacion == 0.3, "una partida no pasa del 30 %")
	p.gasto_educacion = -1.0
	ok(p.gasto_educacion == 0.0, "ni baja de 0")
	p.gasto_educacion = 0.0
	p.gasto_ciencia = 0.0
	p.gasto_obras = 0.0
	p.gasto_sanidad = 0.0
	ok(absf(m.ingreso_neto_diario_local("Colombia") - bruto) < bruto * 1.0e-6, "sin partidas llega todo")
	var bal_antes: float = m.balance_diario_local("Colombia")
	p.gasto_educacion = 0.1
	ok(m.balance_diario_local("Colombia") < bal_antes, "el balance diario (ingresos − ejército) ya descuenta las partidas")
	p.gasto_educacion = 0.04
	p.gasto_ciencia = 0.015
	p.gasto_obras = 0.025
	p.gasto_sanidad = 0.02


# ─────────────────────────────────────────────────────────────
func t_economia_y_saber() -> void:
	print("[T] ── La economía crece según lo que el país sabe")
	var m = main.mundo
	var dm = m.demografia
	var tid: int = int(m.paises["Colombia"].tid)
	ok(absf(dm.factor_economia(tid) - 1.0) < 1.0e-6, "en 2026 el crecimiento es el de siempre (×%.3f)" % dm.factor_economia(tid))
	var pc: PackedFloat64Array = m.bd.vars["pib_pc_usd"].col_f
	var ix: int = m.provincias[0].ix
	var antes: float = pc[ix]
	m.avanzar_mes()
	ok(pc[ix] >= antes, "un mes de economía no quita renta")


# ─────────────────────────────────────────────────────────────
func t_estabilidad() -> void:
	print("[T] ── Estabilidad: bienestar y fatiga")
	var m = main.mundo
	var bd = m.bd
	var pr = null
	for p in m.provincias:
		if p.pais == "Colombia" and bd.num("poblacion", p.tid, 0.0) > 100000.0:
			pr = p
			break
	ok(pr != null, "hay una provincia de prueba")
	var pi: int = m.provincias.find(pr)
	bd.poner_f("bienestar", pr.tid, 80.0)
	var alto: Dictionary = m.estabilidad.desglose(pi)
	bd.poner_f("bienestar", pr.tid, 15.0)
	var bajo: Dictionary = m.estabilidad.desglose(pi)
	ok(float(bajo["meta"]) < float(alto["meta"]) - 8.0, "la gente con hambre se agita: meta %.0f con bienestar 15 vs %.0f con 80" % [float(bajo["meta"]), float(alto["meta"])])
	var tiene := false
	for par in bajo["partes"]:
		if String(par[0]).begins_with("Bienestar de la gente"):
			tiene = true
	ok(tiene, "el desglose explica el bienestar")
	var tid_p: int = int(m.paises["Colombia"].tid)
	bd.poner_f("fatiga_guerra", tid_p, 0.0)
	var sin_f: float = float(m.estabilidad.desglose(pi)["meta"])
	bd.poner_f("fatiga_guerra", tid_p, 60.0)
	var con_f: float = float(m.estabilidad.desglose(pi)["meta"])
	ok(absf((sin_f - con_f) - 7.2) < 0.5, "60 de fatiga restan 7,2 puntos de estabilidad (%.1f)" % (sin_f - con_f))
	var tiene_f := false
	for par in m.estabilidad.desglose(pi)["partes"]:
		if String(par[0]).begins_with("Fatiga de guerra"):
			tiene_f = true
	ok(tiene_f, "el desglose explica la fatiga")
	bd.poner_f("fatiga_guerra", tid_p, 0.0)
	bd.poner_f("bienestar", pr.tid, 65.0)


# ─────────────────────────────────────────────────────────────
func t_determinismo() -> void:
	print("[T] ── Determinismo")
	await arrancar(2026, 4242)
	simular(2)
	var a := agregados()
	await arrancar(2026, 4242)
	simular(2)
	var b := agregados()
	ok(float(a["pob"]) == float(b["pob"]) and float(a["nat"]) == float(b["nat"]) and float(a["alf"]) == float(b["alf"]), "la misma semilla da exactamente el mismo mundo (%.3f M)" % (float(a["pob"]) / 1.0e6))


func t_salto_de_fecha() -> void:
	print("[T] ── Saltos de fecha del Debug")
	await arrancar(2026)
	var m = main.mundo
	main.debug_fijar_fecha(1500, 1, 1)
	await esperar(0.2)
	ok(m.demografia.listo and m.demografia._cursor == 0, "saltar de fecha reinicia la demografía")
	main.debug_avanzar_dias(365)
	var a := agregados()
	ok(int(a["malas"]) == 0, "tras el salto y un año de reloj los datos siguen sanos")
	ok(m.saber.mes_n >= 1500 * 12, "el planeta sigue descubriendo desde 1500 (mes %d)" % m.saber.mes_n)
