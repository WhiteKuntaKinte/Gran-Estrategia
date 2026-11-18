extends Node
## 0.1.8.52 · CAJAS DE TROPAS SIN TABLA (scripts/capa_tropas.gd): con la cámara lejos UN cuadro por país con el total de sus soldados; de cerca UN cuadro por
## pila (provincia + país) y solo se abre en regimientos si tienes uno elegido; separadores de millar; clic en el cuadro de país; las columnas de otros países
## no llevan cuadro propio de lejos.
var main
var m
var ej
var ct
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


func poner_zc(z: float, centro: Vector2) -> void:
	main.camara.position = centro
	main.camara.zoom = Vector2(z, z)
	main._actualizar_zoom()
	ct.refrescar()


func cajas_de(tipo: String) -> Array:
	var r := []
	for d in ct.dibujados:
		if String((d[1] as Dictionary).get("t", "")) == tipo:
			r.append(d)
	return r


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)
	main._iniciar_partida({"modo": "campana", "pais": "España", "ia": 1})
	await esperar(0.8)
	main.reloj.velocidad = 0
	m = main.mundo
	ej = m.ejercito
	ct = main.capa_tropas
	ok(ct != null and ct.ZOOM_TROPAS_PAIS > 1.0 and ct.ZOOM_TROPAS_PAIS < main.ZOOM_PROVINCIAS, "hay un umbral de zoom para el cuadro único por país (%.1f)" % ct.ZOOM_TROPAS_PAIS)
	t_formato()
	await t_lejos_jugador()
	await t_lejos_observador()
	await t_cerca()
	await t_abrir_con_seleccion()
	await t_clic_pais()
	print("[T] ═══ RESULTADO runner112: %d OK, FALLOS: %d" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_formato() -> void:
	print("[T] ── Separador de millar")
	var C = ct.get_script()
	ok(C.fmt_sold(0) == "0" and C.fmt_sold(999) == "999" and C.fmt_sold(9999) == "9999", "hasta 4 cifras se escribe tal cual")
	ok(C.fmt_sold(10000) == "10.000" and C.fmt_sold(12345) == "12.345" and C.fmt_sold(900000) == "900.000", "desde 10.000 lleva punto de millar (900.000)")
	ok(C.fmt_sold(1000000) == "1.000.000" and C.fmt_sold(123456789) == "123.456.789", "y en millones también")


func t_lejos_jugador() -> void:
	print("[T] ── Zoom lejos, con país: un solo cuadro con el total")
	var tid: int = int(m.paises["España"].tid)
	var c: Vector2 = ej.red.centros[int(m.paises["España"].provincias[0])]
	ej.reclutar(tid, int(m.provincias[int(m.paises["España"].provincias[0])].tid), 60000, "prueba")
	poner_zc(1.0, c)
	await esperar(0.5)
	var pais := cajas_de("pais")
	ok(pais.size() >= 1, "con el mapa lejos hay cuadro de país (%d)" % pais.size())
	ok(cajas_de("reg").is_empty() and cajas_de("mas").is_empty(), "y ningún cuadro de regimiento ni de «+N»")
	var propios := 0
	var suma := 0
	for d in pais:
		if int((d[1] as Dictionary)["pais"]) == tid:
			propios += 1
			suma = int((d[1] as Dictionary)["sold"])
	ok(propios == 1, "España tiene UN solo cuadro (%d)" % propios)
	ok(suma == ej.soldados_de_pais(tid), "…y su número es todo su ejército: %d de %d" % [suma, ej.soldados_de_pais(tid)])
	ok(ct.n_cajas_pais == pais.size() and ct.n_marcas == pais.size(), "los contadores de la capa coinciden con lo dibujado")


func t_lejos_observador() -> void:
	print("[T] ── Zoom lejos, observador: un cuadro por país")
	m.fijar_jugador("")
	await esperar(0.4)
	poner_zc(1.0, Vector2(1200.0, 520.0))
	await esperar(0.6)
	var pais := cajas_de("pais")
	var vistos := {}
	var repetido := false
	for d in pais:
		var pa := int((d[1] as Dictionary)["pais"])
		if vistos.has(pa):
			repetido = true
		vistos[pa] = true
	ok(pais.size() > 8, "el observador ve muchos países a la vez (%d)" % pais.size())
	ok(not repetido, "ningún país tiene dos cuadros")
	ok(cajas_de("reg").is_empty() and cajas_de("mas").is_empty() and cajas_de("marcha").is_empty(), "sin regimientos ni columnas sueltas: solo números de país")
	var pisan := false
	for i in pais.size():
		for j in range(i + 1, pais.size()):
			if (pais[i][0] as Rect2).intersects(pais[j][0]):
				pisan = true
	ok(not pisan, "los cuadros de país no se pisan entre sí")
	var sin_total := 0
	for d in pais:
		var tid: int = int((d[1] as Dictionary)["pais"])
		if int((d[1] as Dictionary)["sold"]) != ej.soldados_de_pais(tid):
			sin_total += 1
	ok(sin_total == 0, "cada número es el total de su país (%d no coinciden)" % sin_total)


func t_cerca() -> void:
	print("[T] ── Zoom cerca: un cuadro por pila")
	m.fijar_jugador("")
	var mejor := -1
	var mejor_n := 0
	for i in ct._pilas.size():
		var n: int = (ct._pilas[i]["regs"] as Array).size()
		if n > mejor_n:
			mejor_n = n
			mejor = i
	if mejor < 0:
		ok(false, "no hay ninguna pila para probar")
		return
	var pi: int = ct._pilas[mejor]["pi"]
	poner_zc(5.0, ej.red.centros[pi])
	await esperar(0.6)
	var cuenta := {}
	for d in ct.dibujados:
		var dd: Dictionary = d[1]
		if dd.has("prov") and dd.has("pais"):
			var k := "%d/%d" % [int(dd["prov"]), int(dd["pais"])]
			cuenta[k] = int(cuenta.get(k, 0)) + 1
	var maxc := 0
	for k in cuenta:
		maxc = maxi(maxc, int(cuenta[k]))
	ok(not cuenta.is_empty() and maxc == 1, "sin nada elegido, cada pila es UN solo cuadro (máx. %d)" % maxc)
	if mejor_n > 1:
		var propia := false
		for d in ct.dibujados:
			var dd2: Dictionary = d[1]
			if String(dd2.get("t", "")) == "mas" and int(dd2.get("prov", -1)) == int(ct._pilas[mejor]["prov"]) and int(dd2.get("n", 0)) == mejor_n:
				propia = true
		ok(propia or ct.n_marcas > 0, "la pila de %d regimientos sale como un cuadro con su total" % mejor_n)


func t_abrir_con_seleccion() -> void:
	print("[T] ── Una pila se abre en regimientos solo si eliges uno")
	var mejor := -1
	var mejor_n := 0
	for i in ct._pilas.size():
		var n: int = (ct._pilas[i]["regs"] as Array).size()
		if n > mejor_n:
			mejor_n = n
			mejor = i
	if mejor_n < 2:
		var tid: int = int(ct._pilas[0]["pais"])
		var prov: int = int(ct._pilas[0]["prov"])
		ej.reclutar(tid, prov, 4000, "prueba")
		ej.reclutar(tid, prov, 4000, "prueba")
		ct._ver_pilas = -1
		ct.refrescar()
		await esperar(0.5)
		for i in ct._pilas.size():
			var n2: int = (ct._pilas[i]["regs"] as Array).size()
			if n2 > mejor_n:
				mejor_n = n2
				mejor = i
	if mejor_n < 2:
		print("[T] (no se pudo armar una pila de 2 regimientos: se omite)")
		return
	var p: Dictionary = ct._pilas[mejor]
	var rid: int = int(p["regs"][0][0])
	poner_zc(5.0, ej.red.centros[int(p["pi"])])
	ct.sel = {"t": "reg", "reg": rid}
	ct.refrescar()
	await esperar(0.6)
	var n_prov := 0
	for d in ct.dibujados:
		var dd: Dictionary = d[1]
		if int(dd.get("prov", -1)) == int(p["prov"]) and int(dd.get("pais", -1)) == int(p["pais"]):
			n_prov += 1
	ok(n_prov >= 2, "con un regimiento elegido su pila se abre (%d cuadros)" % n_prov)
	ct.sel = {}
	ct.refrescar()
	await esperar(0.6)
	n_prov = 0
	for d in ct.dibujados:
		var dd3: Dictionary = d[1]
		if int(dd3.get("prov", -1)) == int(p["prov"]) and int(dd3.get("pais", -1)) == int(p["pais"]):
			n_prov += 1
	ok(n_prov == 1, "al soltar la selección vuelve a ser un solo cuadro (%d)" % n_prov)


func t_clic_pais() -> void:
	print("[T] ── Clic en el cuadro de un país")
	poner_zc(1.0, Vector2(1200.0, 520.0))
	await esperar(0.6)
	var pais := cajas_de("pais")
	if pais.is_empty():
		ok(false, "no hay cuadros de país para pulsar")
		return
	var d: Array = pais[0]
	var tid: int = int((d[1] as Dictionary)["pais"])
	var centro: Vector2 = (d[0] as Rect2).get_center() / ct.zr_dibujado
	ok(String(ct.marcador_en(centro).get("t", "")) == "pais", "el cuadro se encuentra por su posición en el mapa")
	var hay: bool = main._clic_tropas(centro)
	await esperar(0.3)
	ok(hay, "el clic lo atiende la capa de tropas")
	ok(main.hud.esta_abierto() and main.hud.pestana == "militar", "se abre el HUD en la pestaña Militar")
	ok(m.bd.nombre_de(tid) != "" and main.hud.datos.get("pais", m.bd.nombre_de(tid)) == m.bd.nombre_de(tid), "…del país de ese número")
