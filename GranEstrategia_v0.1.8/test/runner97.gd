extends Node
## 0.1.8.43 · PRUEBAS DE PROVINCIAS QUE CAMBIAN DE FORMA: cesión parcial (celdas, población y producción, ciudades, historial, subprovincias), regla de conquista parcial
## (`Guerra.fraccion_conquista`) y la paz con posesión sobre una provincia grande (la provincia ocupada se parte, no pasa entera).
var main
var m
var fallos := 0
var n_ok := 0


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


## Una provincia con ≥ `minimo` celdas que tenga una vecina de OTRO país (con ambos países vivos): [origen, vecina].
func buscar_par(minimo: int, excluir := {}) -> Array:
	for pi in m.provincias.size():
		var pr = m.provincias[pi]
		if pr.pais == "" or m.es_inerte(pr.pais) or (pr.anillos as Array).size() < minimo or excluir.has(pi):
			continue
		for v in main.territorio.provincias_vecinas(pi):
			var pv = m.provincias[int(v)]
			if pv.pais != "" and pv.pais != pr.pais and not m.es_inerte(pv.pais) and not excluir.has(int(v)):
				return [pi, int(v)]
	return []


func produccion(pi: int) -> float:
	var pr = m.provincias[pi]
	return pr.poblacion * main.mundo.bd.num("pib_pc_usd", pr.tid, 0.0)


func ciudades_coherentes(pi: int) -> bool:
	for cid in m.provincias[pi].ciudades:
		var ci = m.ciudades[int(cid)]
		var cel: int = main.territorio.celda_en(ci.pos)
		if cel >= 0 and main.territorio.provincia_de(cel) != pi:
			return false
	return true


func run() -> void:
	Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": 1})
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	get_window().size = Vector2i(1280, 720)
	await esperar(0.8)
	if main.en_menu:
		main._on_jugar()
		await esperar(0.2)
	main._poner_velocidad(0)
	m = main.mundo
	var ter = main.territorio
	# ── regla de la conquista parcial
	var g = m.guerra
	var chica := -1
	var grande := -1
	for pi in m.provincias.size():
		var k: int = (m.provincias[pi].anillos as Array).size()
		if chica < 0 and k > 0 and k < g.PARCIAL_MIN_CELDAS and m.provincias[pi].pais != "":
			chica = pi
		if grande < 0 and k >= g.PARCIAL_MIN_CELDAS + 2 and m.provincias[pi].pais != "":
			grande = pi
	ok(chica >= 0 and grande >= 0, "hay provincias chicas (%d) y grandes (%d celdas) para probar" % [chica, (m.provincias[grande].anillos as Array).size()])
	ok(g.fraccion_conquista(chica, 0.0) == 1.0, "una provincia de menos de %d celdas se conquista entera" % g.PARCIAL_MIN_CELDAS)
	ok(is_equal_approx(g.fraccion_conquista(grande, 0.0), g.PARCIAL_BASE), "una provincia grande con puntaje 0: se queda %d %%" % int(g.PARCIAL_BASE * 100.0))
	ok(is_equal_approx(g.fraccion_conquista(grande, -0.3), g.PARCIAL_BASE), "con puntaje negativo no baja de ese mínimo")
	var f25: float = g.fraccion_conquista(grande, 0.25)
	ok(f25 > g.PARCIAL_BASE and f25 < 1.0, "con puntaje 0,25 se queda más (%.2f)" % f25)
	ok(g.fraccion_conquista(grande, g.PARCIAL_DECISIVO) == 1.0 and g.fraccion_conquista(grande, 0.9) == 1.0, "con una victoria clara (≥ %.1f) se queda la provincia entera" % g.PARCIAL_DECISIVO)
	# ── cesión parcial directa
	var par: Array = buscar_par(6)
	ok(par.size() == 2, "hay un par de provincias vecinas de países distintos (%s y %s)" % [m.provincias[par[0]].nombre, m.provincias[par[1]].nombre])
	var o: int = par[0]
	var d: int = par[1]
	var po = m.provincias[o]
	var pd = m.provincias[d]
	var pais_o: String = po.pais
	var pais_d: String = pd.pais
	var cel_o0: int = ter.celdas_de(o).size()
	var cel_d0: int = ter.celdas_de(d).size()
	var pob_total0: float = po.poblacion + pd.poblacion
	var prod_total0: float = produccion(o) + produccion(d)
	var hist_o0: int = m.paises[pais_o].historial.size()
	var hist_d0: int = m.paises[pais_d].historial.size()
	var cesiones0: int = m.cesiones_parciales
	var senal := [0]
	ter.forma_cambiada.connect(func(_l): senal[0] += 1)
	# subprovincias guardadas de la provincia que cambia de forma
	var abierta: bool = main.mostrar_subprovincias(o)
	var sub_antes: bool = main.subprov != null and main.subprov.calculada(o)
	ok(sub_antes, "las subdivisiones de la provincia que va a cambiar de forma quedan guardadas (con datos: %s)" % str(abierta))
	var r: Dictionary = main.ceder_parcial(o, d, 0.4, "Prueba")
	ok(bool(r["ok"]) and int(r["celdas"]) >= 1, "ceder_parcial → ok, %d celdas (%s)" % [int(r["celdas"]), String(r["msg"])])
	ok(ter.celdas_de(o).size() == cel_o0 - int(r["celdas"]) and ter.celdas_de(d).size() == cel_d0 + int(r["celdas"]), "el origen pierde celdas y el destino las gana (%d→%d · %d→%d)" % [cel_o0, ter.celdas_de(o).size(), cel_d0, ter.celdas_de(d).size()])
	ok(ter.celdas_de(o).size() >= 1, "el origen conserva al menos una celda")
	ok(senal[0] >= 1 and ter.modificado(), "salió la señal forma_cambiada y el territorio figura como modificado")
	ok(absf((po.poblacion + pd.poblacion) - pob_total0) < 1.0 and po.poblacion < pob_total0, "la población total se conserva (%.0f → %.0f) y la que se movió es %.0f" % [pob_total0, po.poblacion + pd.poblacion, float(r["pob"])])
	ok(absf((produccion(o) + produccion(d)) - prod_total0) < 1.0e-6 * maxf(prod_total0, 1.0) + 1.0, "la producción total se conserva (viaja con su gente)")
	ok(float(r["area"]) > 0.0 and float(r["area"]) < 1.0, "se movió una parte de la superficie (%.0f %%)" % (float(r["area"]) * 100.0))
	ok(po.pais == pais_o and pd.pais == pais_d, "los dueños de las dos provincias no cambian (solo la forma)")
	ok(m.paises[pais_o].historial.size() == hist_o0 + 1 and m.paises[pais_d].historial.size() == hist_d0 + 1 and String(m.paises[pais_d].historial[-1]["motivo"]).begins_with("Prueba"), "ambos países dejan registro en su historial")
	ok(m.cesiones_parciales == cesiones0 + 1, "el mundo cuenta la cesión")
	ok(ciudades_coherentes(o) and ciudades_coherentes(d), "las ciudades quedan en la provincia que cubre su posición")
	ok(main.subprov == null or not main.subprov.calculada(o), "las subprovincias guardadas de la provincia que cambió se descartaron (estaba guardada: %s)" % str(sub_antes))
	ok(main.capa_sub == null or not main.capa_sub.activa(), "y la capa de subdivisiones abierta sobre ella se cerró")
	var lista_d: PackedInt32Array = ter.celdas_de(d)
	var coherente := true
	for c in lista_d:
		if int(main.anillos[int(c)]["p"]) != d:
			coherente = false
	ok(coherente and (m.provincias[d].anillos as Array).size() == lista_d.size(), "las tablas de celdas y la lista de la provincia coinciden")
	# casos que no se pueden
	var lejana := -1
	for pi in m.provincias.size():
		if pi != o and pi != d and m.provincias[pi].pais != "" and ter.celdas_frontera(o, pi).is_empty():
			lejana = pi
			break
	ok(not bool(main.ceder_parcial(o, lejana, 0.5)["ok"]), "no se puede ceder a una provincia que no es vecina")
	ok(not bool(main.ceder_parcial(o, o, 0.5)["ok"]), "no se puede ceder a sí misma")
	var una_celda := -1
	for pi in m.provincias.size():
		if ter.celdas_de(pi).size() == 1 and m.provincias[pi].pais != "":
			for v in ter.provincias_vecinas(pi):
				una_celda = pi
				break
		if una_celda >= 0:
			break
	if una_celda >= 0:
		var vec: int = int(ter.provincias_vecinas(una_celda)[0])
		ok(not bool(main.ceder_parcial(una_celda, vec, 0.5)["ok"]), "una provincia de una sola celda no se puede partir")
	main.ceder_parcial(o, d, 1.0)
	ok(ter.celdas_de(o).size() >= 1, "ceder el 100 %% deja al menos una celda (%d)" % ter.celdas_de(o).size())
	# ── vecina_de_pais
	var par2: Array = buscar_par(6, {o: true, d: true})
	if par2.size() == 2:
		var q: int = main.vecina_de_pais(par2[0], m.provincias[par2[1]].pais)
		ok(q >= 0 and m.provincias[q].pais == m.provincias[par2[1]].pais, "vecina_de_pais devuelve una vecina del país pedido")
	ok(main.vecina_de_pais(o, "País que no existe") == -1, "vecina_de_pais: sin vecina de ese país → −1")
	# ── la paz: el vencedor se queda solo con la parte pegada a su territorio
	ter.restablecer()
	var par3: Array = buscar_par(6)
	var gran: int = par3[0]
	var veci: int = par3[1]
	var pais_perd: String = m.provincias[gran].pais
	var pais_gan: String = m.provincias[veci].pais
	var tg: int = m.paises[pais_gan].tid
	var tp: int = m.paises[pais_perd].tid
	var celdas_gran0: int = ter.celdas_de(gran).size()
	var celdas_veci0: int = ter.celdas_de(veci).size()
	g.declarar(tg, tp, "Prueba")
	m.bd.poner_i("ocupante", m.provincias[gran].tid, tg, "Prueba")
	var parciales0: int = g.parciales
	var res: Dictionary = g.firmar_paz(tg, tp, {"posesion": true}, "Paz")
	ok(bool(res["ok"]), "la paz con posesión se firma: %s" % String(res["msg"]))
	ok(g.parciales == parciales0 + 1, "contó una conquista parcial")
	ok(m.provincias[gran].pais == pais_perd and ter.celdas_de(gran).size() < celdas_gran0 and ter.celdas_de(gran).size() >= 1, "la provincia ocupada NO pasa entera: sigue siendo de %s con %d de %d celdas" % [pais_perd, ter.celdas_de(gran).size(), celdas_gran0])
	var crecidas := 0
	for v in ter.provincias_vecinas(gran):
		if m.provincias[int(v)].pais == pais_gan and ter.celdas_de(int(v)).size() > 0:
			crecidas += 1
	ok(ter.celdas_de(veci).size() >= celdas_veci0 or crecidas >= 1, "la provincia vecina del vencedor ganó esas celdas (%d → %d)" % [celdas_veci0, ter.celdas_de(veci).size()])
	ok(m.provincias[gran].ocupante < 0, "la ocupación terminó con la paz")
	# victoria clara: la provincia pasa entera
	ter.restablecer()
	var par4: Array = buscar_par(6)
	var g4: int = par4[0]
	var v4: int = par4[1]
	var pg: String = m.provincias[v4].pais
	var pp: String = m.provincias[g4].pais
	g.declarar(m.paises[pg].tid, m.paises[pp].tid, "Prueba")
	for q in m.paises[pp].provincias:
		m.bd.poner_i("ocupante", m.provincias[int(q)].tid, m.paises[pg].tid, "Prueba")      # ocupa todo: puntaje de guerra máximo
	var p0: int = g.parciales
	var cel4: int = ter.celdas_de(g4).size()
	g.firmar_paz(m.paises[pg].tid, m.paises[pp].tid, {"posesion": true}, "Paz")
	ok(g.parciales == p0 and m.provincias[g4].pais == pg and ter.celdas_de(g4).size() == cel4, "con la ocupación total (victoria clara) la provincia pasa entera a %s" % pg)
	print("[T] ═══ RESULTADO runner97: %d OK, %d FALLOS" % [n_ok, fallos])
	Engine.remove_meta("inicio_pendiente")
	get_tree().quit(1 if fallos > 0 else 0)
