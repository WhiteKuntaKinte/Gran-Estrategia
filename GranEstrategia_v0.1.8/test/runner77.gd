extends Node
## 0.1.8.36 · PRUEBAS DE LOS DESCUBRIMIENTOS: el catálogo de 1.730 descubrimientos enlazado con el reloj (cada uno con su año).
## Cubre: datos (coherencia año/prerrequisitos/era dentro del motor), la frontera histórica de cualquier año contra una cuenta por fuerza bruta,
## avanzar el reloj año a año == empezar directamente en ese año, saltos del Debug hacia atrás y adelante, estado propio de un país (conceder / quitar),
## disponibles, textos de año, el escenario 2026 y el año 1 d. C. dentro del juego, el reloj que trae descubrimientos al cruzar de año, y el coste.
const DescScript := preload("res://scripts/descubrimientos.gd")
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


func leer() -> Dictionary:
	var f := FileAccess.open("res://datos/descubrimientos.json", FileAccess.READ)
	var j := JSON.new()
	j.parse(f.get_as_text())
	return j.data


func nuevo() -> Object:
	var d = DescScript.new()
	d.cargar(leer())
	return d


## La frontera de `a` por fuerza bruta: 1 si el descubrimiento tiene año <= a.
func bruta(d, a: int) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(d.n)
	for i in d.n:
		r[i] = 1 if d.anio[i] <= a else 0
	return r


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
	m = main.mundo


func run() -> void:
	t_datos()
	t_frontera()
	t_tiempo()
	t_pais()
	t_texto()
	t_coste()
	await t_juego()
	print("[T] ═══ RESULTADO runner77: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


# ── datos ───────────────────────────────────────────────────────────────────────────────────────────────────────
func t_datos() -> void:
	print("[T] ── datos")
	var t0 := Time.get_ticks_msec()
	var d = nuevo()
	var ms := Time.get_ticks_msec() - t0
	ok(d.n == 1730, "el catálogo trae 1.730 descubrimientos (%d)" % d.n)
	ok(d.idx_de_slug.size() == d.n, "los slugs no se repiten")
	ok(d.eras.size() == 12 and d.ramas.size() == 3 and d.secciones.size() == 40, "12 eras, 3 ramas, 40 secciones")
	ok(ms < 400, "leer y armar el catálogo tarda %d ms (< 400)" % ms)
	var orden_ok := true
	for k in range(1, d.n):
		if d.anios_ord[k] < d.anios_ord[k - 1]:
			orden_ok = false
			break
	ok(orden_ok, "la lista por años está ordenada")
	var malos := 0
	var req_malos := 0
	var era_mala := 0
	for i in d.n:
		var e: Dictionary = d.eras[int(d.era[i])]
		if e["desde"] != null and d.anio[i] < int(e["desde"]):
			era_mala += 1
		if e["hasta"] != null and d.anio[i] > int(e["hasta"]):
			era_mala += 1
		for r in d.req[i]:
			if r < 0 or r >= d.n or r == i:
				malos += 1
			elif d.anio[r] > d.anio[i]:
				req_malos += 1
		for g in d.req_o[i]:
			var mn := 1 << 40
			for r2 in g:
				if r2 < 0 or r2 >= d.n or r2 == i:
					malos += 1
				else:
					mn = mini(mn, d.anio[r2])
			if mn > d.anio[i]:
				req_malos += 1
	ok(malos == 0, "todos los prerrequisitos apuntan a descubrimientos que existen (y a otro)")
	ok(req_malos == 0, "ningún descubrimiento es anterior a un prerrequisito (año >= año del prerrequisito)")
	ok(era_mala == 0, "el año de cada descubrimiento cae dentro del rango de su era")
	var hip := 0
	for i in d.n:
		if d.origen[i] == "x":
			hip += 1
			if int(d.era[i]) != 11 or d.anio[i] <= 2026:
				hip += 1000
	ok(hip == 31, "los 31 hipotéticos son de la era 11 y de años posteriores a 2026 (%d)" % hip)
	ok(d.indice("fuego") >= 0 and d.indice("no_existe_xyz") == -1, "indice(slug): existe / no existe")


# ── frontera histórica ─────────────────────────────────────────────────────────────────────────────────────
func t_frontera() -> void:
	print("[T] ── frontera histórica")
	var d = nuevo()
	d.iniciar(1)
	ok(d.anio_actual == 1 and d.cuenta_f == 353, "año 1 d. C.: la historia conoce 353 descubrimientos (%d)" % d.cuenta_f)
	d.iniciar(2026)
	ok(d.cuenta_f == 1699, "año 2026: la historia conoce 1.699 de 1.730 (%d)" % d.cuenta_f)
	var fallos_b := 0
	for a in [-3000000, -50000, -10000, -3500, -3300, -1200, -44, 0, 1, 2, 100, 500, 800, 1000, 1066, 1450, 1500, 1650, 1789, 1800, 1900, 1914, 1945, 1969, 1990, 2000, 2010, 2026, 2027, 2030, 2100]:
		d.iniciar(a)
		var b := bruta(d, a)
		if d.frontera != b or d.cuenta_f != d.cuenta_hasta(a):
			fallos_b += 1
		var c := 0
		for i in d.n:
			c += b[i]
		if c != d.cuenta_f:
			fallos_b += 1
	ok(fallos_b == 0, "la frontera de 31 años distintos coincide con la cuenta por fuerza bruta y con la bisección")
	# cierre: todo lo conocido tiene sus prerrequisitos conocidos (la historia nunca da un descubrimiento sin sus bases)
	var cierre_mal := 0
	for a in [-100000, -20000, -9000, -3400, -1000, 1, 300, 1000, 1500, 1700, 1850, 1920, 1960, 1990, 2010, 2026, 2060, 2200]:
		d.iniciar(a)
		for i in d.n:
			if d.frontera[i] == 1 and not d.requisitos_cumplidos(-1, i):
				cierre_mal += 1
	ok(cierre_mal == 0, "en 18 años distintos, todo descubrimiento conocido tiene todos sus prerrequisitos conocidos")
	d.iniciar(1)
	ok(d.conoce(-1, d.indice("fuego")) and d.conoce(-1, d.indice("rueda")) and d.conoce(-1, d.indice("acueducto")), "año 1: se conocen fuego, rueda y acueducto")
	ok(not d.conoce(-1, d.indice("polvora")) and not d.conoce(-1, d.indice("imprenta")), "año 1: NO se conocen pólvora ni imprenta")
	d.iniciar(2026)
	ok(d.conoce(-1, d.indice("polvora")) and d.conoce(-1, d.indice("internet_tecnologia")) and d.conoce(-1, d.indice("ia_generativa")), "año 2026: se conocen pólvora, internet e IA generativa")
	ok(not d.conoce(-1, d.indice("nanorrobots_medicos")) and not d.conoce(-1, d.indice("legion_androides")), "año 2026: los hipotéticos (nanorrobots, androides) no existen todavía")
	ok(not d.conoce(-1, -1) and not d.conoce(-1, d.n) and not d.conoce(-1, 99999), "índices fuera de rango: no se conoce")


# ── tiempo ──────────────────────────────────────────────────────────────────────────────────────────────────
func t_tiempo() -> void:
	print("[T] ── el tiempo")
	var d = nuevo()
	d.iniciar(1)
	var total_nuevos := 0
	for a in range(2, 2027):
		total_nuevos += d.avanzar_a(a)
	ok(total_nuevos == 1699 - 353, "avanzar el reloj del año 1 a 2026 trae 1.346 descubrimientos (%d)" % total_nuevos)
	var e2 = nuevo()
	e2.iniciar(2026)
	ok(d.frontera == e2.frontera and d.cuenta_f == e2.cuenta_f, "avanzar año a año == empezar directamente en 2026")
	ok(d.avanzar_a(2026) == 0 and d.avanzar_a(1500) == 0, "volver a avisar un año ya sincronizado (o anterior) no hace nada")
	ok(d.ultimos.size() == d.MAX_ULTIMOS and int(d.ultimos[d.ultimos.size() - 1]["anio"]) <= 2026, "se recuerdan los %d descubrimientos más recientes" % d.MAX_ULTIMOS)
	# saltos del Debug
	d.sincronizar(1)                           # hacia atrás
	var e1 = nuevo()
	e1.iniciar(1)
	ok(d.frontera == e1.frontera and d.cuenta_f == 353 and d.anio_actual == 1, "saltar de 2026 al año 1 deja exactamente la historia del año 1")
	d.sincronizar(1789)                        # hacia adelante
	var e3 = nuevo()
	e3.iniciar(1789)
	ok(d.frontera == e3.frontera, "saltar del año 1 a 1789 deja exactamente la historia de 1789")
	d.sincronizar(1789, true)                  # mismo año con reinicio
	ok(d.frontera == e3.frontera and d.cuenta_f == e3.cuenta_f, "reiniciar en el mismo año no cambia nada")
	# la fecha 0 / negativa: sin errores
	d.sincronizar(-5000, true)
	ok(d.frontera == bruta(d, -5000), "un año a. C. (-5000) también funciona")
	# un año nuevo con descubrimientos concretos: 1969 (alunizaje)
	d.iniciar(1968)
	var antes: int = d.cuenta_f
	var en_1969 := 0
	for i in d.n:
		if d.anio[i] == 1969:
			en_1969 += 1
	var nn: int = d.avanzar_a(1969)
	var recientes := 0
	for u in d.ultimos:
		if int(u["anio"]) == 1969:
			recientes += 1
	ok(nn == en_1969 and d.cuenta_f == antes + en_1969 and recientes == en_1969, "cruzar a 1969 trae sus %d descubrimientos y los anota entre los recientes (%d)" % [en_1969, nn])
	ok(d.conoce(-1, d.indice("alunizaje")), "1969: llega la Luna")


# ── estado propio de un país ─────────────────────────────────────────────────────────────────────────────────
func t_pais() -> void:
	print("[T] ── estado por país")
	var d = nuevo()
	d.iniciar(1)
	var a := 7
	var b := 8
	var pol: int = d.indice("polvora")
	ok(not d.conoce(a, pol) and not d.conoce(b, pol), "al empezar nadie conoce la pólvora (año 1)")
	ok(d.estado.is_empty() and d.cantidad(a) == 353, "un país sin tocar no gasta memoria: lee la historia")
	ok(not d.disponible(a, pol), "la pólvora no está disponible en el año 1 (le faltan prerrequisitos)")
	ok(d.conceder(a, pol), "conceder la pólvora al país A")
	ok(d.conoce(a, pol) and not d.conoce(b, pol), "A la conoce y B no")
	ok(not d.conceder(a, pol), "conceder dos veces devuelve false")
	ok(d.cantidad(a) == 354 and d.cantidad(b) == 353, "A conoce 354 y B 353")
	ok(d.cantidad_por_era(a)[4] == d.cantidad_por_era(b)[4] + 1, "por era: A tiene 1 más en la Edad Media")
	d.avanzar_a(1000)
	ok(d.conoce(a, pol), "A conserva la pólvora al avanzar el reloj")
	var n1000: int = d.cuenta_hasta(1000)
	ok(d.cantidad(a) == n1000 and d.cantidad(b) == n1000, "al llegar el año 1000, A y B conocen lo mismo que la historia (la pólvora es de 850: %d)" % n1000)
	var rueda: int = d.indice("rueda")
	ok(d.quitar(b, rueda) and not d.conoce(b, rueda) and d.conoce(a, rueda), "quitarle la rueda a B no se la quita a A")
	d.avanzar_a(1100)
	ok(not d.conoce(b, rueda), "B sigue sin la rueda aunque pase el tiempo (se apartó de la historia)")
	d.sincronizar(100)                              # hacia atrás: se quitan los más nuevos que 100 a todos, también a los países apartados
	ok(not d.conoce(a, pol) and not d.conoce(b, d.indice("brujula")), "viajar atrás quita lo posterior al año 100 a todos los países")
	ok(not d.conoce(b, rueda), "…pero B sigue sin la rueda (no se le devuelve lo que se quitó)")
	d.sincronizar(100, true)
	ok(d.estado.is_empty() and d.conoce(b, rueda) and d.cantidad(a) == d.cuenta_hasta(100), "reiniciar: todos vuelven a la historia pura de ese año")
	d.conceder(a, pol)
	d.reiniciar_pais(a)
	ok(not d.conoce(a, pol) and d.estado.is_empty(), "reiniciar_pais descarta el estado propio")
	# disponibles
	d.iniciar(1)
	var disp := 0
	for i in d.n:
		if d.disponible(-1, i):
			disp += 1
	ok(disp > 20, "en el año 1 hay descubrimientos disponibles para investigar (%d)" % disp)
	var libres_mal := 0
	for i in d.n:
		if d.disponible(-1, i) and (d.conoce(-1, i) or not d.requisitos_cumplidos(-1, i)):
			libres_mal += 1
	ok(libres_mal == 0, "«disponible» = no lo conoce y tiene los prerrequisitos")
	var pro: PackedInt32Array = d.proximos(5)
	ok(pro.size() == 5 and d.anio[pro[0]] > 1 and d.anio[pro[0]] <= d.anio[pro[4]], "proximos(5): los 5 que siguen en el tiempo, en orden")
	# un OR: un descubrimiento con grupos alternativos
	var con_or := -1
	for i in d.n:
		if not (d.req_o[i] as Array).is_empty():
			con_or = i
			break
	ok(con_or >= 0, "el catálogo tiene prerrequisitos con alternativas (O)")
	if con_or >= 0:
		d.iniciar(-3000000)
		ok(not d.requisitos_cumplidos(-1, con_or) or d.req_o[con_or].is_empty(), "sin ninguna alternativa conocida, no se cumplen los prerrequisitos")
		d.iniciar(2026)
		ok(d.requisitos_cumplidos(-1, con_or), "en 2026 se cumplen")


# ── textos ──────────────────────────────────────────────────────────────────────────────────────────────────────
func t_texto() -> void:
	print("[T] ── textos")
	ok(DescScript.anio_texto(1769) == "1769" and DescScript.anio_texto(0) == "0", "1769 → «1769»")
	ok(DescScript.anio_texto(-44) == "44 a. C.", "-44 → «44 a. C.»")
	ok(DescScript.anio_texto(-3300) == "3.300 a. C.", "-3300 → «3.300 a. C.»")
	ok(DescScript.anio_texto(-2600000) == "2.600.000 a. C.", "-2600000 → «2.600.000 a. C.»")
	var d = nuevo()
	ok(d.etiqueta(d.indice("fuego")) == "400.000 a. C. · Dominio del fuego", "etiqueta: «%s»" % d.etiqueta(d.indice("fuego")))
	ok(preload("res://scripts/base_datos.gd").anio_de_fecha(preload("res://scripts/base_datos.gd").fecha_int(-44, 3, 15)) == -44
		and preload("res://scripts/base_datos.gd").anio_de_fecha(preload("res://scripts/base_datos.gd").fecha_int(2026, 12, 31)) == 2026, "anio_de_fecha(fecha_int(a, m, d)) == a")


# ── coste ───────────────────────────────────────────────────────────────────────────────────────────────────────
func t_coste() -> void:
	print("[T] ── coste")
	var d = nuevo()
	d.iniciar(1)
	var t0 := Time.get_ticks_usec()
	for a in range(2, 2027):
		d.avanzar_a(a)
	var us_avance := Time.get_ticks_usec() - t0
	ok(us_avance < 60000, "avanzar 2.025 años seguidos (sin países con estado propio) tarda %.1f ms (< 60)" % (us_avance / 1000.0))
	t0 = Time.get_ticks_usec()
	for _k in 12 * 100:                            # 100 años de meses «sin novedad»: lo que pasa 11 de cada 12 meses
		d.avanzar_a(2026)
	var us_vacio := Time.get_ticks_usec() - t0
	ok(us_vacio < 20000, "1.200 avisos sin novedad cuestan %.2f ms en total (%.2f µs cada uno)" % [us_vacio / 1000.0, us_vacio / 1200.0])
	t0 = Time.get_ticks_usec()
	for k in 40:
		d.sincronizar(1 + (k % 2) * 2000, true)
	var us_salto := Time.get_ticks_usec() - t0
	ok(us_salto < 80000, "40 saltos de fecha con reinicio cuestan %.1f ms (%.2f ms cada uno)" % [us_salto / 1000.0, us_salto / 40000.0])
	# con 250 países apartados de la historia
	for tid in 250:
		d.conceder(tid, d.indice("internet_tecnologia") if tid % 2 == 0 else d.indice("fuego"))
	d.sincronizar(1, true)
	for tid in 250:
		d.quitar(tid, d.indice("fuego"))
	t0 = Time.get_ticks_usec()
	for a in range(2, 2027, 1):
		d.avanzar_a(a)
	var us_250 := Time.get_ticks_usec() - t0
	ok(us_250 < 600000, "avanzar 2.025 años con 250 países apartados de la historia tarda %.1f ms (< 600)" % (us_250 / 1000.0))
	print("[B] descubrimientos · avanzar 1→2026 sin países propios %.1f ms · con 250 países propios %.1f ms · salto con reinicio %.2f ms · aviso vacío %.2f µs" % [
		us_avance / 1000.0, us_250 / 1000.0, us_salto / 40000.0, us_vacio / 1200.0])


# ── dentro del juego ────────────────────────────────────────────────────────────────────────────────────────
func t_juego() -> void:
	print("[T] ── dentro del juego")
	await arrancar(2026)
	var d = m.descubrimientos
	ok(d != null, "Mundo trae descubrimientos")
	ok(d != null and d.n == 1730 and d.anio_actual == 2026 and d.cuenta_f == 1699, "2026: 1.699 descubrimientos conocidos")
	var pais := ""
	for p in m.paises:
		if not m.paises[p].inerte and m.paises[p].provincias.size() > 0:
			pais = p
			break
	ok(pais != "", "hay un país con provincias para probar (%s)" % pais)
	ok(m.conoce_descubrimiento(pais, "internet_tecnologia") and not m.conoce_descubrimiento(pais, "nanorrobots_medicos"), "Mundo.conoce_descubrimiento: internet sí, nanorrobots no")
	ok(not m.conoce_descubrimiento("País que no existe", "internet_tecnologia") and not m.conoce_descubrimiento(pais, "slug_que_no_existe"), "…y falso si el país o el slug no existen")
	# Debug: saltos de fecha dentro del juego
	main.debug_fijar_fecha(1066, 10, 14)
	ok(d.anio_actual == 1066 and d.frontera == bruta(d, 1066), "Debug > fijar 1066: la historia es la de 1066")
	ok(not m.conoce_descubrimiento(pais, "imprenta") and m.conoce_descubrimiento(pais, "polvora"), "1066: hay pólvora, aún no hay imprenta")
	main.debug_fijar_fecha(1500, 1, 1)
	ok(m.conoce_descubrimiento(pais, "imprenta") and not m.conoce_descubrimiento(pais, "maquina_vapor"), "1500: hay imprenta, aún no hay máquina de vapor")
	main.debug_fijar_fecha(2026, 1, 1)
	ok(d.cuenta_f == 1699, "volver a 2026 deja 1.699")
	# el reloj trae descubrimientos al cruzar de año
	main.debug_fijar_fecha(2029, 12, 31)
	var antes: int = d.cuenta_f
	var en_2030 := 0
	for i in d.n:
		if d.anio[i] == 2030:
			en_2030 += 1
	ok(en_2030 > 0, "hay descubrimientos hipotéticos en 2030 para probar (%d)" % en_2030)
	main.debug_avanzar_dias(1)                      # 31 dic 2029 → 1 ene 2030: cambia el año y el mes
	ok(main.reloj.anio == 2030 and main.reloj.mes == 1, "el reloj está en el 1 de enero de 2030")
	ok(d.cuenta_f == antes + en_2030, "al cruzar a 2030 el reloj trajo %d descubrimientos (de %d a %d)" % [en_2030, antes, d.cuenta_f])
	# 11 meses sin novedad no cambian nada
	var c0: int = d.cuenta_f
	main.debug_avanzar_dias(90)
	ok(d.cuenta_f == c0, "avanzar 90 días dentro del mismo año no trae nada")
	# 5 años de reloj de verdad
	main.debug_fijar_fecha(2026, 1, 1)
	main.debug_avanzar_dias(365 * 4 + 1)
	ok(d.cuenta_f == d.cuenta_hasta(main.reloj.anio) and main.reloj.anio >= 2030, "tras 4 años de reloj la historia es la de %d (%d)" % [main.reloj.anio, d.cuenta_f])
	# estado propio de un país dentro del juego
	main.debug_fijar_fecha(2026, 1, 1)
	var tid: int = m.paises[pais].tid
	d.quitar(tid, d.indice("internet_tecnologia"))
	ok(not m.conoce_descubrimiento(pais, "internet_tecnologia"), "un país puede perder internet (estado propio)")
	main.debug_fijar_fecha(2026, 1, 1)
	ok(m.conoce_descubrimiento(pais, "internet_tecnologia"), "fijar fecha devuelve a todos los países a la historia")
	# Debug: la pestaña existe y se refresca
	main.debug_fijar_fecha(2026, 1, 1)
	var dbg = main.debug_menu if "debug_menu" in main else null
	ok(true, "(la pestaña Descub. se prueba abajo, con el Debug abierto)")
	# año 1 d. C. (solo si el proyecto trae el paquete de esa época; el proyecto de semilla no lo trae)
	if DirAccess.dir_exists_absolute("res://datos/epocas"):
		await arrancar(1)
		d = m.descubrimientos
		ok(d != null and d.anio_actual == 1 and d.cuenta_f == 353, "año 1 d. C.: 353 descubrimientos conocidos")
		var pais1 := ""
		for p2 in m.paises:
			if not m.paises[p2].inerte and m.paises[p2].provincias.size() > 0:
				pais1 = p2
				break
		ok(pais1 != "" and m.conoce_descubrimiento(pais1, "fuego") and m.conoce_descubrimiento(pais1, "acueducto"), "año 1: el país %s conoce el fuego y el acueducto" % pais1)
		ok(not m.conoce_descubrimiento(pais1, "polvora") and not m.conoce_descubrimiento(pais1, "internet_tecnologia"), "año 1: ni pólvora ni internet")
		# del año 1 hacia adelante con el reloj real: 1 → 100 años
		main.debug_avanzar_dias(365 * 100 + 25)
		ok(d.anio_actual == main.reloj.anio and d.cuenta_f == d.cuenta_hasta(main.reloj.anio), "tras 100 años de reloj (año %d) la historia conoce %d" % [main.reloj.anio, d.cuenta_f])
	else:
		ok(true, "(este proyecto no trae el paquete del año 1 d. C.: se omiten sus comprobaciones dentro del juego)")
	# volver a 2026 recarga lo de 2026
	await arrancar(2026)
	d = m.descubrimientos
	ok(d != null and d.anio_actual == 2026 and d.cuenta_f == 1699, "volver al escenario 2026 recarga 1.699")
	# pestaña Debug
	main._on_jugar()
	await esperar(0.5)
	var dm = main.get("debug_menu")
	if dm == null:
		for c in main.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("debug_menu.gd"):
				dm = c
	if dm == null:
		main._abrir_debug() if main.has_method("_abrir_debug") else null
		await esperar(0.4)
		for c in main.get_children():
			if c.get_script() != null and String(c.get_script().resource_path).ends_with("debug_menu.gd"):
				dm = c
	ok(dm != null, "el menú Debug se puede abrir")
	if dm != null:
		dm._ir_a("desc")
		var n_desc: int = main.mundo.descubrimientos.n
		ok(dm.lista_desc.item_count == n_desc + 1, "pestaña Descub.: sin filtro muestra la lista completa (%d) más la fila de la frontera (%d)" % [n_desc, dm.lista_desc.item_count])
		dm.filtro_desc.text = "pólvora"
		dm._refrescar_desc()
		ok(dm.lista_desc.item_count >= 3, "buscar «pólvora» encuentra varios (%d)" % dm.lista_desc.item_count)
		dm.lista_desc.select(0)
		dm.lista_desc.item_selected.emit(0)
		ok(dm.lbl_desc_ficha.text.contains("Año"), "la ficha muestra el año")
		dm.filtro_desc.text = ""
		dm._refrescar_desc()
		ok(dm.lbl_desc_res.text.contains("1.699") or dm.lbl_desc_res.text.contains("1699"), "el resumen cuenta 1.699 conocidos")
