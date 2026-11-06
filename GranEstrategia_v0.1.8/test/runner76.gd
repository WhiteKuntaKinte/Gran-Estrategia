extends Node
## 0.1.8.35 · PRUEBAS DEL TERRITORIO (el mapa en celdas): una provincia es un grupo de celdas y su forma puede cambiar mientras se juega.
## Cubre: tablas coherentes (celda ↔ provincia ↔ anillos de Mundo), clic y colores tras mover celdas, fronteras (contra una cuenta por fuerza bruta),
## fusionar / ceder / dividir (también hacia una provincia sin celdas), deshacer y restablecer, un baile aleatorio de celdas, las herramientas del Debug,
## el año 1 d. C. (las mismas celdas con otro reparto) y el coste de cada cambio.
var main
var terr
var fu
var m
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


func enlazar() -> void:
	terr = main.territorio
	fu = main.fusion
	m = main.mundo


func arrancar(anio: int) -> void:
	if main != null and is_instance_valid(main):
		main.queue_free()
		await esperar(0.3)
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	if anio != 2026:
		Engine.set_meta("inicio_pendiente", {"modo": "dev", "epoca": anio})
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
	await esperar(0.8)
	enlazar()


func run() -> void:
	await esperar(0.8)
	main._on_jugar()
	await esperar(0.4)
	enlazar()
	t_estructura()
	t_rejilla()
	await t_clic_color_frontera()
	await t_fusionar_ceder_dividir()
	t_historial()
	await t_baile()
	await t_relieve()
	await t_debug()
	await t_anio1()
	print("[T] ═══ RESULTADO runner76: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ── utilidades ──────────────────────────────────────────────────────────────────────────────────────────────────
## Comprueba que todas las tablas cuentan lo mismo. Devuelve "" si todo cuadra o el primer problema.
func invariantes() -> String:
	var n: int = fu.n_celdas
	if n != main.anillos.size():
		return "celdas %d != anillos %d" % [n, main.anillos.size()]
	var veces := PackedByteArray()
	veces.resize(n)
	var total := 0
	for p in fu.prov_celdas.size():
		var l: PackedInt32Array = fu.prov_celdas[p]
		total += l.size()
		for c in l:
			veces[c] += 1
			if fu.celda_prov[c] != p:
				return "la celda %d está en la lista de %d pero celda_prov dice %d" % [c, p, fu.celda_prov[c]]
	if total != n:
		return "las listas suman %d celdas, no %d" % [total, n]
	for c in n:
		if veces[c] != 1:
			return "la celda %d aparece %d veces" % [c, veces[c]]
		if int(main.anillos[c]["p"]) != fu.celda_prov[c]:
			return "anillos[%d].p = %d pero celda_prov = %d" % [c, int(main.anillos[c]["p"]), fu.celda_prov[c]]
	for p in m.provincias.size():
		var a: Array = m.provincias[p].anillos
		var l2: PackedInt32Array = fu.prov_celdas[p]
		if a.size() != l2.size():
			return "provincia %d: Mundo tiene %d anillos y fusion %d celdas" % [p, a.size(), l2.size()]
	for k in fu.n_pares:
		if fu.par_pa[k] != fu.celda_prov[fu.par_a[k]] or fu.par_pb[k] != fu.celda_prov[fu.par_b[k]]:
			return "el par %d tiene provincias desactualizadas" % k
	return ""


## Pares de frontera (distinto dueño) contados por fuerza bruta, en orden.
func fronteras_brutas(dueno: PackedInt32Array) -> PackedInt32Array:
	var r := PackedInt32Array()
	for k in fu.n_pares:
		if dueno[fu.par_pa[k]] != dueno[fu.par_pb[k]]:
			r.append(k)
	return r


## Una pareja de provincias vecinas de países distintos: [A, B] con A de ≥ 6 celdas y B de ≥ 2.
func pareja() -> Array:
	for p in m.provincias.size():
		var l: PackedInt32Array = fu.prov_celdas[p]
		if l.size() < 6:
			continue
		for q in terr.provincias_vecinas(p):
			if m.provincias[int(q)].pais != m.provincias[p].pais and (fu.prov_celdas[int(q)] as PackedInt32Array).size() >= 2:
				return [p, int(q)]
	return []


func color_celda(c: int) -> Color:
	var k: int = fu.runs_ofs[c]
	var ti: int = fu.runs[k * 3]
	var t: Dictionary = fu.teselas[ti]
	if t["cols"] == null:
		return Color(-1, -1, -1)
	return (t["cols"] as PackedColorArray)[fu.runs[k * 3 + 1] - int(t["v0"])]


## Color con el que se hornearon los vértices de la celda (el que lleva mientras su dueño sea el original).
func color_horneado(c: int) -> Color:
	var k: int = fu.runs_ofs[c]
	var q: int = int(fu.runs[k * 3 + 1]) * 3
	return Color(fu.cp[q] / 255.0, fu.cp[q + 1] / 255.0, fu.cp[q + 2] / 255.0)


func cerca(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


# ── pruebas ─────────────────────────────────────────────────────────────────────────────────────────────────────
func t_estructura() -> void:
	print("[T] ── Estructura de celdas (2026)")
	ok(terr != null and terr.listo(), "Territorio existe y está listo")
	ok(fu.n_celdas == main.anillos.size() and fu.n_celdas > 10000, "el mapa son %d celdas (los anillos)" % fu.n_celdas)
	var inv := invariantes()
	ok(inv == "", "tablas coherentes al empezar %s" % inv)
	ok(not terr.modificado(), "al empezar la forma es la de la época (modificado() = false)")
	var vacias := 0
	for p in m.provincias.size():
		if (fu.prov_celdas[p] as PackedInt32Array).is_empty():
			vacias += 1
	ok(vacias <= 3, "casi toda provincia tiene celdas (sin celdas: %d)" % vacias)
	var red = m.ejercito.red
	var fuera := 0
	var primera := -1
	for p in m.provincias.size():
		if (fu.prov_celdas[p] as PackedInt32Array).is_empty() or p >= red.centros.size():
			continue
		if not terr.contiene(p, red.centros[p]):
			fuera += 1
			if primera < 0:
				primera = p
	ok(fuera <= 30, "el punto donde se dibujan las tropas de cada provincia cae dentro de sus celdas (fuera: %d%s)" % [fuera, "" if primera < 0 else ", p. ej. %s" % m.provincias[primera].nombre])
	var pr := pareja()
	ok(pr.size() == 2, "hay provincias vecinas de países distintos para probar")
	if pr.size() < 2:
		return
	var a: int = pr[0]
	var b: int = pr[1]
	ok(terr.provincias_vecinas(b).has(a), "la vecindad es simétrica")
	var fr: PackedInt32Array = terr.celdas_frontera(a, b)
	ok(fr.size() > 0, "A tiene %d celdas que tocan a B" % fr.size())
	var bien := true
	for c in fr:
		var toca := false
		for o in fu.celdas_vecinas(c):
			if fu.celda_prov[o] == b:
				toca = true
		bien = bien and toca and fu.celda_prov[c] == a
	ok(bien, "las celdas de frontera son de A y tocan de verdad a B")
	var c_f: int = fr[0]
	ok(terr.celda_en(terr.centro_celda(c_f)) == c_f and terr.provincia_de(c_f) == a, "celda_en(centro de la celda) devuelve la celda y provincia_de su provincia")
	ok(terr.celda_en(terr.centro_celda(c_f) + Vector2(main.ANCHO_MAPA, 0.0)) == c_f, "celda_en da la vuelta al mundo (x + 2400 es el mismo punto)")
	ok(terr.celda_en(Vector2(60.0, 600.0)) == -1, "un punto en pleno Pacífico no es de ninguna celda (-1)")
	ok(terr.celdas_de(a).size() == fu.prov_celdas[a].size() and terr.n_celdas() == fu.n_celdas, "celdas_de y n_celdas cuentan lo mismo que las tablas")
	var ar: float = terr.area_provincia(a)
	var suma := 0.0
	for c in fu.prov_celdas[a]:
		suma += terr.area_celda(c)
	ok(ar > 0.0 and absf(ar - suma) < ar * 1e-4, "área de la provincia = suma de sus celdas (%.1f px²)" % ar)
	var cp: Vector2 = terr.centro_provincia(a)
	ok(terr.contiene(a, cp), "el centro que da Territorio está dentro de la provincia")
	ok(not terr.contiene(b, cp), "…y no dentro de su vecina")


## La búsqueda «qué celda hay bajo este punto» con la rejilla da lo mismo que recorrer las 16.056 celdas (de menor a mayor, como siempre) y es mucho más rápida.
func bruto(p: Vector2) -> int:
	for i in range(main.anillos.size() - 1, -1, -1):
		var b: Array = main.anillos[i]["b"]
		if p.x < b[0] or p.x > b[0] + b[2] or p.y < b[1] or p.y > b[1] + b[3]:
			continue
		if Geometry2D.is_point_in_polygon(p, main._puntos_anillo(main.anillos[i])):
			return i
	return -1


func t_rejilla() -> void:
	print("[T] ── Búsqueda de la celda bajo un punto (rejilla)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 35
	var puntos: Array = []
	for i in 300:
		puntos.append(Vector2(rng.randf() * 2400.0, rng.randf() * 1200.0))
	for i in 200:
		puntos.append(terr.centro_celda(rng.randi() % fu.n_celdas))
	puntos.append(Vector2(0.0, 0.0))
	puntos.append(Vector2(2399.99, 1199.99))
	puntos.append(Vector2(1200.0, 1200.0))
	var mal := 0
	for p in puntos:
		if main._anillo_en(p) != bruto(p):
			mal += 1
	ok(mal == 0, "la rejilla da la misma celda que recorrerlas todas (%d puntos, %d diferencias)" % [puntos.size(), mal])
	var t0 := Time.get_ticks_usec()
	for i in 1000:
		main._anillo_en(puntos[i % puntos.size()])
	var us_rej := float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	for i in 200:
		bruto(puntos[i % puntos.size()])
	var us_bru := float(Time.get_ticks_usec() - t0) / 200.0
	print("[T] PERF  celda bajo el cursor: %.1f µs con la rejilla · %.0f µs recorriendo todas (%.0f veces más)" % [us_rej, us_bru, us_bru / maxf(us_rej, 0.01)])
	ok(us_rej < 500.0, "con la rejilla buscar una celda tarda menos de 0,5 ms (%.1f µs)" % us_rej)


func t_clic_color_frontera() -> void:
	print("[T] ── Mover celdas: clic, colores y fronteras")
	var pr := pareja()
	if pr.size() < 2:
		ok(false, "sin pareja de provincias")
		return
	var a: int = pr[0]
	var b: int = pr[1]
	main._sincronizar_propiedad(true)
	var fr: PackedInt32Array = terr.celdas_frontera(a, b)
	var c: int = fr[0]
	var punto: Vector2 = terr.centro_celda(c)
	var ia: int = main._anillo_en(punto)
	ok(ia == c and int(main.anillos[ia]["p"]) == a, "el clic en el centro de la celda %d da la celda y la provincia A" % c)
	var dueno: PackedInt32Array = main._dueno_actual()
	var dueno_a := dueno[a]
	var dueno_b := dueno[b]
	ok(dueno_a != dueno_b, "A y B tienen dueños distintos")
	var horneado := color_horneado(c)
	var lejos: int = (c + fu.n_celdas / 2) % fu.n_celdas
	var col_lejos := color_celda(lejos)
	var f0: PackedInt32Array = fu._pares_frontera(main._dueno_ahora)
	var n0 := f0.size()
	var n_mov: int = terr.reasignar(PackedInt32Array([c]), b)
	ok(n_mov == 1, "reasignar mueve 1 celda")
	ok(terr.modificado(), "modificado() = true")
	ok(fu.celda_prov[c] == b and int(main.anillos[c]["p"]) == b, "la celda ahora es de B en las tablas y en los anillos")
	ok(not (fu.prov_celdas[a] as PackedInt32Array).has(c) and (fu.prov_celdas[b] as PackedInt32Array).has(c), "las listas por provincia se actualizaron")
	ok(main.mundo.provincias[b].anillos.has(c) and not main.mundo.provincias[a].anillos.has(c), "Mundo.provincias[].anillos se actualizó")
	var r: Array = main._anillo_bajo(punto)
	ok(int(r[0]) == c and int(main.anillos[int(r[0])]["p"]) == b, "el clic en el mismo punto ahora da la provincia B")
	ok(cerca(color_celda(c), main._color_de_dueno(dueno_b)), "la celda se pintó con el color del dueño de B")
	ok(cerca(color_celda(lejos), col_lejos), "una celda lejana no cambió de color")
	var f1: PackedInt32Array = fu._pares_frontera(main._dueno_ahora)
	ok(f1 == fronteras_brutas(main._dueno_ahora), "las fronteras entre países coinciden con la cuenta por fuerza bruta (%d pares, antes %d)" % [f1.size(), n0])
	ok(main._prov_caja[b].encloses(Rect2(main.anillos[c]["b"][0], main.anillos[c]["b"][1], main.anillos[c]["b"][2], main.anillos[c]["b"][3])), "la caja de B ya incluye la celda")
	ok(terr.contiene(b, punto) and not terr.contiene(a, punto), "contiene(): el punto es de B y no de A")
	print("[T] PERF  mover 1 celda y rehacer relleno, fronteras y nombres: %.1f ms" % terr.ultimo_cambio_ms)
	ok(terr.ultimo_cambio_ms < 1500.0, "un cambio de forma tarda menos de 1,5 s incluso con GL por software (%.0f ms)" % terr.ultimo_cambio_ms)
	ok(invariantes() == "", "tablas coherentes tras el cambio")
	ok(terr.deshacer(), "deshacer devuelve la celda")
	ok(fu.celda_prov[c] == a and int(main.anillos[c]["p"]) == a and not terr.modificado(), "…a A, y la forma vuelve a ser la original")
	ok(cerca(color_celda(c), horneado), "…y la celda recupera su color de siempre")


func t_fusionar_ceder_dividir() -> void:
	print("[T] ── Fusionar, ceder y dividir")
	var pr := pareja()
	var a: int = pr[0]
	var b: int = pr[1]
	var na: int = (fu.prov_celdas[a] as PackedInt32Array).size()
	var nb: int = (fu.prov_celdas[b] as PackedInt32Array).size()
	var cap_a: int = terr.ceder(a, b, 2)
	ok(cap_a == 2, "ceder(A, B, 2) mueve 2 celdas")
	ok((fu.prov_celdas[a] as PackedInt32Array).size() == na - 2 and (fu.prov_celdas[b] as PackedInt32Array).size() == nb + 2, "A pierde 2 y B gana 2")
	ok(terr.provincias_vecinas(a).has(b), "siguen siendo vecinas")
	ok(terr.ceder(a, b, 10000) == (fu.prov_celdas[a] as PackedInt32Array).size() or (fu.prov_celdas[a] as PackedInt32Array).size() == 1,
		"ceder nunca deja a la provincia sin celdas (quedan %d)" % (fu.prov_celdas[a] as PackedInt32Array).size())
	ok((fu.prov_celdas[a] as PackedInt32Array).size() >= 1, "A conserva al menos una celda")
	ok(invariantes() == "", "tablas coherentes tras ceder")
	terr.restablecer()
	ok(not terr.modificado(), "restablecer devuelve la forma de la época")
	# fusionar
	var n_ab: int = na + nb
	var movidas: int = terr.fusionar(a, b)
	ok(movidas == nb, "fusionar(A, B): se mueven las %d celdas de B" % nb)
	ok((fu.prov_celdas[b] as PackedInt32Array).is_empty() and m.provincias[b].anillos.is_empty(), "B se queda sin celdas")
	ok((fu.prov_celdas[a] as PackedInt32Array).size() == n_ab, "A tiene las celdas de las dos (%d)" % n_ab)
	ok(terr.provincias_vecinas(b).is_empty() and not terr.provincias_vecinas(a).has(b), "B ya no tiene vecinas ni A la tiene como vecina")
	ok(invariantes() == "", "tablas coherentes tras fusionar")
	# dividir hacia una provincia SIN celdas: el trozo nace dentro de A
	var antes_a: int = (fu.prov_celdas[a] as PackedInt32Array).size()
	var n_div: int = terr.dividir(a, b, 0.5)
	ok(n_div == int(roundf(antes_a * 0.5)), "dividir(A, B, ½) pasa %d de %d celdas a la provincia vacía" % [n_div, antes_a])
	ok((fu.prov_celdas[b] as PackedInt32Array).size() == n_div and not m.provincias[b].anillos.is_empty(), "la provincia vacía vuelve a tener forma")
	ok(terr.provincias_vecinas(a).has(b) and terr.provincias_vecinas(b).has(a), "y es vecina de la que la dividió")
	var pegado := true
	var l: PackedInt32Array = fu.prov_celdas[b]
	var alcanzadas := {l[0]: true}
	var cola: Array = [l[0]]
	while not cola.is_empty():
		var x: int = cola.pop_front()
		for o in fu.celdas_vecinas(x):
			if fu.celda_prov[o] == b and not alcanzadas.has(o):
				alcanzadas[o] = true
				cola.append(o)
	pegado = alcanzadas.size() == l.size()
	ok(pegado, "el trozo nuevo es de una sola pieza (%d celdas conectadas)" % alcanzadas.size())
	ok(invariantes() == "", "tablas coherentes tras dividir")
	var inv_f: PackedInt32Array = fu._pares_frontera(main._dueno_ahora)
	ok(inv_f == fronteras_brutas(main._dueno_ahora), "fronteras correctas tras fusionar y dividir")
	terr.restablecer()
	ok(not terr.modificado() and invariantes() == "", "restablecer vuelve al reparto original")


func t_historial() -> void:
	print("[T] ── Historial (deshacer)")
	var pr := pareja()
	var a: int = pr[0]
	var b: int = pr[1]
	var base: PackedInt32Array = fu.celda_prov.duplicate()
	terr.ceder(a, b, 1)
	terr.ceder(a, b, 1)
	terr.fusionar(b, a)
	ok(terr.puede_deshacer(), "puede_deshacer() = true")
	ok(terr.deshacer() and terr.deshacer() and terr.deshacer(), "tres cambios, tres deshacer")
	ok(fu.celda_prov == base, "la forma vuelve exactamente a la anterior")
	ok(not terr.puede_deshacer() and not terr.deshacer(), "sin historial: deshacer devuelve false")
	var senal := [0, PackedInt32Array()]
	var cb := func(ps: PackedInt32Array): senal[0] += 1; senal[1] = ps
	terr.forma_cambiada.connect(cb)
	terr.ceder(a, b, 1)
	terr.forma_cambiada.disconnect(cb)
	ok(int(senal[0]) == 1 and (senal[1] as PackedInt32Array).has(a) and (senal[1] as PackedInt32Array).has(b), "la señal forma_cambiada avisa de las dos provincias tocadas")
	terr.restablecer()
	ok(terr.reasignar(PackedInt32Array(), a) == 0 and terr.reasignar(PackedInt32Array([0]), -1) == 0, "reasignar con datos inválidos no hace nada")
	ok(terr.reasignar(PackedInt32Array([fu.prov_celdas[a][0]]), a) == 0, "mover una celda a su propia provincia no hace nada")
	ok(invariantes() == "", "tablas coherentes al terminar")


func t_baile() -> void:
	print("[T] ── Baile aleatorio de celdas")
	var rng := RandomNumberGenerator.new()
	rng.seed = 76
	var base: PackedInt32Array = fu.celda_prov.duplicate()
	var t0 := Time.get_ticks_usec()
	var movidas := 0
	var mal := ""
	for i in 40:
		var c: int = rng.randi() % fu.n_celdas
		var vec: PackedInt32Array = fu.celdas_vecinas(c)
		if vec.is_empty():
			continue
		var d: int = fu.celda_prov[vec[rng.randi() % vec.size()]]
		movidas += terr.reasignar(PackedInt32Array([c]), d)
		if i % 10 == 9:
			mal = invariantes()
			if mal != "":
				break
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	ok(mal == "", "tras 40 movimientos (%d celdas cambiaron) las tablas siguen coherentes %s" % [movidas, mal])
	ok(fu._pares_frontera(main._dueno_ahora) == fronteras_brutas(main._dueno_ahora), "las fronteras siguen coincidiendo con la fuerza bruta")
	print("[T] PERF  40 cambios de una celda con repintado completo: %.0f ms (%.1f ms cada uno)" % [ms, ms / 40.0])
	var d0 := 0
	for c in fu.n_celdas:
		if fu.celda_prov[c] != base[c]:
			d0 += 1
	ok(d0 > 0 and terr.modificado(), "hay %d celdas que ya no son de su provincia original" % d0)
	var n: int = terr.restablecer()
	ok(n == d0 and fu.celda_prov == base and not terr.modificado(), "restablecer devuelve las %d celdas" % n)
	ok(invariantes() == "", "tablas coherentes tras restablecer")
	# el juego sigue su curso con la forma cambiada
	var pr := pareja()
	terr.ceder(pr[0], pr[1], 3)
	main.reloj.velocidad = 1
	for i in 4:
		main._on_dia(false, false)
	await esperar(0.2)
	ok(true, "con el territorio cambiado, cuatro días de simulación corren sin error")
	terr.restablecer()


func t_relieve() -> void:
	print("[T] ── Gancho de texturas (relieve del terreno)")
	var AjustesS = load("res://scripts/ajustes.gd")
	var inst0: MeshInstance2D = fu.teselas[0]["inst"][1]
	ok(main.mat_relieve == null and main.textura_relieve == null and inst0.material == null, "sin textura: el relleno no lleva material (coste cero)")
	var img := Image.create(8, 4, false, Image.FORMAT_L8)
	img.fill(Color(0.5, 0.5, 0.5))
	main.poner_textura_relieve(ImageTexture.create_from_image(img), 0.7, 0.5)
	var todos := true
	for t in fu.teselas:
		for mi in t["inst"]:
			todos = todos and (mi as MeshInstance2D).material == main.mat_relieve
	ok(main.mat_relieve != null and todos, "con textura: todas las copias del relleno usan el material del relieve")
	ok(absf(float(main.mat_relieve.get_shader_parameter("fuerza")) - 0.7) < 1e-6 and absf(float(main.mat_relieve.get_shader_parameter("neutro")) - 0.5) < 1e-6, "fuerza y gris neutro llegan al shader")
	var c0: Color = color_celda(0)
	main._sincronizar_propiedad(true)
	ok(cerca(color_celda(0), c0), "repintar el mapa con el relieve puesto no altera los colores de las celdas")
	main._aplicar_calidad(AjustesS.con_preset(main.ajustes, 2))
	ok(inst0.material == null and main.mat_relieve != null, "la calidad Baja apaga el relieve (conserva la textura)")
	main._aplicar_calidad(AjustesS.con_preset(main.ajustes, 0))
	ok(inst0.material == main.mat_relieve, "al volver a calidad Alta el relieve vuelve")
	main.poner_textura_relieve(null)
	ok(inst0.material == null and main.mat_relieve == null, "poner_textura_relieve(null) lo quita")
	# carga automática desde datos/texturas/relieve.png
	var dir := ProjectSettings.globalize_path("res://datos/texturas")
	var ruta := ProjectSettings.globalize_path(RUTA_PNG)
	var existia := FileAccess.file_exists(ruta)
	if not existia:
		DirAccess.make_dir_recursive_absolute(dir)
		var img2 := Image.create(64, 32, false, Image.FORMAT_RGB8)
		img2.fill(Color(0.5, 0.5, 0.5))
		img2.save_png(ruta)
		main._cargar_relieve_archivo()
		ok(main.textura_relieve != null and inst0.material == main.mat_relieve, "si existe datos/texturas/relieve.png se carga solo")
		main.poner_textura_relieve(null)
		DirAccess.remove_absolute(ruta)
		DirAccess.remove_absolute(dir)
	main.poner_textura_relieve(null)


const RUTA_PNG := "res://datos/texturas/relieve.png"


func t_debug() -> void:
	print("[T] ── Herramientas del Debug (Provincia > Forma del territorio)")
	main._abrir_debug()
	await esperar(0.3)
	var dm = main.debug_menu
	ok(dm != null and is_instance_valid(dm) and dm.lbl_terr != null and dm.opt_vecina != null, "el Debug trae la sección «Forma del territorio»")
	var pr := pareja()
	var a: int = pr[0]
	var b: int = pr[1]
	dm.prov_sel = a
	dm._mostrar_prov()
	ok(dm.lbl_terr.text.contains("celdas") and dm.opt_vecina.item_count > 0, "muestra las celdas y las vecinas de la provincia elegida: «%s»" % dm.lbl_terr.text)
	var pos: int = dm.ids_vecinas.find(b)
	ok(pos >= 0, "B está entre las vecinas del selector")
	if pos >= 0:
		dm.opt_vecina.select(pos)
		var na: int = (fu.prov_celdas[a] as PackedInt32Array).size()
		dm._terr_ceder(0.5)
		ok(terr.modificado() and (fu.prov_celdas[a] as PackedInt32Array).size() < na, "«Cederle ½» mueve celdas de A a B")
		ok(dm.lbl_terr.text.contains("forma modificada"), "el panel avisa de que la forma está modificada")
		dm._terr_deshacer()
		ok(not terr.modificado(), "«Deshacer» la devuelve")
		dm._terr_absorber()
		ok((fu.prov_celdas[b] as PackedInt32Array).is_empty() and terr.modificado(), "«Absorberla toda» deja vacía a la vecina")
		dm._terr_restablecer()
		ok(not terr.modificado() and invariantes() == "", "«Restablecer forma» lo deja todo como estaba")
	dm.queue_free()
	await esperar(0.2)
	main.debug_menu = null


func t_anio1() -> void:
	print("[T] ── Año 1 d. C.: las mismas celdas con otro reparto")
	var base26: PackedInt32Array = fu.celda_prov.duplicate()
	var n26: int = fu.n_celdas
	await arrancar(1)
	ok(main.epoca == 1 and terr != null and terr.listo(), "el escenario del año 1 trae su Territorio")
	ok(fu.n_celdas == n26, "las celdas son las mismas que en 2026 (%d)" % fu.n_celdas)
	var difiere := 0
	for c in fu.n_celdas:
		if fu.celda_prov[c] != base26[c]:
			difiere += 1
	ok(difiere > 1000, "pero repartidas distinto entre las provincias del año 1 (%d celdas en otra provincia)" % difiere)
	ok(invariantes() == "", "tablas coherentes en el año 1")
	var pr := pareja()
	ok(pr.size() == 2, "hay dos provincias vecinas de naciones distintas")
	if pr.size() == 2:
		var a: int = pr[0]
		var b: int = pr[1]
		var n_a: int = (fu.prov_celdas[a] as PackedInt32Array).size()
		var mov: int = terr.ceder(a, b, 2)
		ok(mov == 2 and terr.modificado(), "ceder(A, B, 2) también funciona en el año 1")
		ok(fu._pares_frontera(main._dueno_ahora) == fronteras_brutas(main._dueno_ahora), "fronteras correctas en el año 1 tras el cambio")
		terr.fusionar(a, b)
		ok((fu.prov_celdas[b] as PackedInt32Array).is_empty(), "fusionar vacía a B en el año 1")
		terr.restablecer()
		ok(not terr.modificado() and (fu.prov_celdas[a] as PackedInt32Array).size() == n_a and invariantes() == "", "restablecer devuelve el año 1 intacto")
	var sin := -1
	for p in m.provincias.size():
		if (fu.prov_celdas[p] as PackedInt32Array).is_empty():
			sin = p
			break
	if sin >= 0 and pr.size() == 2:
		var a2: int = pr[0]
		var antes: int = (fu.prov_celdas[a2] as PackedInt32Array).size()
		var n2: int = terr.dividir(a2, sin, 0.4)
		ok(n2 > 0 and not (fu.prov_celdas[sin] as PackedInt32Array).is_empty(), "una provincia que nacía sin celdas recibe un trozo de otra (%d de %d)" % [n2, antes])
		terr.restablecer()
		ok(invariantes() == "", "y todo vuelve a cuadrar")
	else:
		print("[T] (el año 1 no trae provincias sin celdas)")
