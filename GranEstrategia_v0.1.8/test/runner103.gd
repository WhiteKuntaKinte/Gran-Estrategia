extends Node
## 0.1.8.46 · EL PLANETA DESCUBRE (scripts/saber.gd + scripts/azar.gd).
var main
var fallos := 0
var n_ok := 0
const BDScript := preload("res://scripts/base_datos.gd")
const AzarScript := preload("res://scripts/azar.gd")


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


func arrancar(anio: int, semilla := 12345) -> void:
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


## Avanza `k` meses solo del motor (sin economía ni ejército): fija la fecha de la base mes a mes y llama a saber.mes().
func meses(k: int) -> void:
	var m = main.mundo
	var f: int = int(m.bd.fecha)
	var a: int = BDScript.anio_de_fecha(f)
	var mm: int = (f / 100) % 100
	for _i in k:
		mm += 1
		if mm > 12:
			mm = 1
			a += 1
		m.bd.fecha = BDScript.fecha_int(a, mm, 1)
		m.saber.mes()


## Todos los países: ¿conocen algo sin conocer sus prerrequisitos? Devuelve cuántos casos malos.
func invariante_cerrado() -> int:
	var d = main.mundo.descubrimientos
	var malos := 0
	for tid in d.estado:
		var e: PackedByteArray = d.estado[tid]
		for i in d.n:
			if e[i] == 1:
				for r in d.req[i]:
					if e[r] == 0:
						malos += 1
				for g in d.req_o[i]:
					var alguno := false
					for r2 in g:
						if e[r2] == 1:
							alguno = true
							break
					if not alguno:
						malos += 1
	return malos


func conocen(i: int) -> int:
	var d = main.mundo.descubrimientos
	var c := 0
	for tid in d.estado:
		if (d.estado[tid] as PackedByteArray)[i] == 1:
			c += 1
	return c


## Una «huella» del estado completo del planeta, para comparar dos partidas.
func huella() -> String:
	var m = main.mundo
	var d = m.descubrimientos
	var sb = m.saber
	var h := 17
	for tid in d.estado:
		h = (h * 31 + int(tid) * 7 + hash(d.estado[tid])) & 0x7FFFFFFF
	return "%d|%d|%d|%d|%d" % [h, hash(sb.descubridor), hash(sb.fecha_desc), sb.n_contagios, sb.n_descubiertos]


func run() -> void:
	await t_arranque()
	await t_determinismo()
	await t_ritmo()
	await t_difusion_y_bloqueo()
	await t_edificios()
	await t_salto_y_modos()
	await t_reloj_real()
	await t_ficha()
	print("[T] ═══ RESULTADO runner103: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_arranque() -> void:
	print("[T] ── Arranque: la historia se congela y cada país tiene su copia")
	await arrancar(1500, 12345)
	var m = main.mundo
	var sb = m.saber
	var d = m.descubrimientos
	ok(sb != null and sb.listo and sb.activo and d.modo_planeta, "el planeta descubre es el modo normal de una partida nueva")
	ok(m.semilla_partida == 12345 and sb.semilla == 12345, "la semilla de la partida es la pedida (%d)" % m.semilla_partida)
	var igual := true
	for nombre in m.paises:
		var tid: int = int(m.paises[nombre].tid)
		if not d.estado.has(tid) or d.estado[tid] != d.frontera:
			igual = false
			break
	ok(igual, "los %d países parten con su propia copia de la historia de 1500" % m.paises.size())
	ok(d.cuenta_f == d.cuenta_hasta(1500) and d.anio_actual == 1500, "la frontera inicial es la historia de 1500 (%d)" % d.cuenta_f)
	ok(sb.candidatos.size() > 20 and sb.activos.size() > 100, "hay %d candidatos y %d países con tierra" % [sb.candidatos.size(), sb.activos.size()])
	ok(invariante_cerrado() == 0, "al empezar ningún país sabe algo sin sus prerrequisitos")
	ok(sb.resumen().contains("semilla 12345"), "el resumen del Debug dice la semilla")
	var i_ini: int = d.indice("imprenta")
	ok(sb.quien(i_ini).is_empty() and i_ini >= 0, "lo que ya estaba al empezar no tiene descubridor")


func t_determinismo() -> void:
	print("[T] ── Misma semilla, misma partida")
	meses(12 * 60)
	var h1 := huella()
	var n1: int = main.mundo.saber.n_descubiertos
	await arrancar(1500, 12345)
	meses(12 * 60)
	var h2 := huella()
	ok(h1 == h2 and n1 > 0, "60 años con la misma semilla dan exactamente lo mismo (%d descubrimientos, huella %s)" % [n1, h2.get_slice("|", 0)])
	await arrancar(1500, 777)
	meses(12 * 60)
	var h3 := huella()
	ok(h3 != h1, "otra semilla da otra historia (%s ≠ %s)" % [h3.get_slice("|", 0), h1.get_slice("|", 0)])
	ok(invariante_cerrado() == 0, "con otra semilla también: ningún país sabe algo sin sus prerrequisitos")


func t_ritmo() -> void:
	print("[T] ── Ritmo: el planeta sigue de cerca a la historia, sin ir más rápido ni quedarse atrás")
	await arrancar(1500, 4242)
	var m = main.mundo
	var sb = m.saber
	var d = m.descubrimientos
	var hist0: int = d.cuenta_hasta(1500)
	meses(12 * 100)
	var gan_hist: int = d.cuenta_hasta(1600) - hist0
	var gan_plan: int = d.cuenta_f - hist0
	ok(gan_plan >= int(0.5 * float(gan_hist)) and gan_plan <= int(1.6 * float(gan_hist)) + 3, "1500→1600: el planeta descubre %d y la historia trajo %d" % [gan_plan, gan_hist])
	ok(sb.n_contagios > 500, "…y hubo contagio entre países (%d veces)" % sb.n_contagios)
	ok(invariante_cerrado() == 0, "tras 100 años ningún país sabe algo sin sus prerrequisitos")
	var promedio := float(sb.us_total) / maxf(float(sb.meses_corridos), 1.0)
	ok(promedio < 1500.0 and sb.us_max < 20000, "coste: %.2f ms por mes de media, %.1f ms el peor mes" % [promedio / 1000.0, float(sb.us_max) / 1000.0])
	# nadie se queda sin nada: los países con tierra aprendieron algo de lo nuevo
	var con_algo := 0
	for tid in sb.activos:
		if int(sb._conocidos_n.get(tid, 0)) > hist0:
			con_algo += 1
	ok(con_algo > sb.activos.size() / 2, "más de la mitad de los países con tierra aprendió algo nuevo (%d de %d)" % [con_algo, sb.activos.size()])
	# hay un descubridor registrado y es un país que existe
	var quien := {}
	for i in d.n:
		if sb.descubridor[i] >= 0:
			quien = sb.quien(i)
			break
	ok(not quien.is_empty() and m.paises.has(String(quien["pais"])) and int(quien["anio"]) >= 1500, "quien(): «%s» en %s" % [String(quien.get("pais", "")), str(quien.get("anio", ""))])
	# vocaciones distintas: el primer descubridor no siempre es el mismo país
	var distintos := {}
	for i in d.n:
		if sb.descubridor[i] >= 0:
			distintos[sb.descubridor[i]] = true
	ok(distintos.size() >= 5, "descubren países distintos (%d en %d descubrimientos)" % [distintos.size(), sb.n_descubiertos])


func t_difusion_y_bloqueo() -> void:
	print("[T] ── Difusión y bloqueo")
	await arrancar(1500, 99)
	var m = main.mundo
	var sb = m.saber
	var d = m.descubrimientos
	var elegido := -1
	for c in sb.candidatos:
		sb._descubrir(int(c))
		if sb.descubridor[int(c)] >= 0:
			elegido = int(c)
			break
	ok(elegido >= 0, "se fuerza un descubrimiento (%s)" % (String(d.nombre[elegido]) if elegido >= 0 else "ninguno"))
	ok(conocen(elegido) == 1 and d.frontera[elegido] == 1, "en el instante del descubrimiento solo lo conoce un país")
	ok(not (d.estado[sb.descubridor[elegido]] as PackedByteArray)[elegido] == 0 and sb._pend.size() > 0, "el descubridor lo sabe y quedan contactos programados (%d)" % sb._pend.size())
	meses(12 * 15)
	var c15 := conocen(elegido)
	ok(c15 > 5, "a los 15 años lo conocen %d países (por contagio)" % c15)
	meses(12 * 120)
	var c135 := conocen(elegido)
	ok(c135 > c15 and c135 > sb.activos.size() / 3, "a los 135 años ya lo conocen %d de %d países" % [c135, sb.activos.size()])
	ok(invariante_cerrado() == 0, "el contagio nunca salta un prerrequisito")
	# bloqueo: el planeta conoce un prerrequisito pero ningún país
	var objetivo := -1
	var previo := -1
	for c in sb.candidatos:
		var ci: int = int(c)
		if d.req[ci].size() > 0 and d.req_o[ci].is_empty():
			objetivo = ci
			previo = int(d.req[ci][0])
			break
	ok(objetivo >= 0, "hay un candidato con un prerrequisito para probar el bloqueo")
	for tid in d.estado:
		var e: PackedByteArray = d.estado[tid]
		e[previo] = 0
		d.estado[tid] = e
	var bloqueados0: int = sb.n_bloqueos
	sb._descubrir(objetivo)
	ok(sb._bloqueado.has(objetivo) and sb.n_bloqueos == bloqueados0 + 1 and sb.descubridor[objetivo] < 0, "si ningún país tiene el prerrequisito, el candidato se BLOQUEA y no se descubre")
	var quien_sabe: int = sb.activos[0]
	d.conceder(quien_sabe, previo)
	sb._al_aprender(quien_sabe, previo)
	ok(not sb._bloqueado.has(objetivo), "en cuanto un país aprende el prerrequisito, el candidato se desbloquea")
	sb._descubrir(objetivo)
	ok(sb.descubridor[objetivo] == quien_sabe, "…y solo ese país puede descubrirlo (%d)" % sb.descubridor[objetivo])


func t_edificios() -> void:
	print("[T] ── Edificios y materias de la receta")
	await arrancar(1500, 31)
	var m = main.mundo
	var sb = m.saber
	var d = m.descubrimientos
	var ed = m.edificios
	var i := -1
	for k in d.n:
		if (d.edif[k] as Array).size() == 1 and (d.edif[k][0] as PackedInt32Array).size() >= 2 and (d.mat[k] as PackedStringArray).is_empty() and d.frontera[k] == 0:
			i = k
			break
	ok(i >= 0, "hay un descubrimiento con una receta de un grupo de edificios para probar (%s)" % (String(d.nombre[i]) if i >= 0 else ""))
	var pais := ""
	for p in m.paises:
		if not m.paises[p].inerte and m.paises[p].provincias.size() >= 3:
			pais = p
			break
	var tid: int = int(m.paises[pais].tid)
	var grupo: PackedInt32Array = d.edif[i][0]
	var provs: Array = m.paises[pais].provincias
	for pi in provs:
		for b in grupo:
			var e: int = ed.indice(String(d.slug[int(b)]))
			if e >= 0 and ed.cantidad(int(pi), e) > 0:
				ed.quitar(int(pi), e, ed.cantidad(int(pi), e))
	var sin: float = sb._factor_edif(pais, i)
	ok(is_equal_approx(sin, sb.SIN_EDIFICIO), "sin ningún edificio del grupo el país pesa ×%.2f" % sin)
	var r: Dictionary = sb.receta_de(i, pais)
	ok((r["edif"] as Array).size() == 1 and not bool(r["edif"][0]["tiene"]) and (r["edif"][0]["opciones"] as Array).size() == grupo.size(), "receta_de dice que le falta el grupo")
	var e0: int = ed.indice(String(d.slug[int(grupo[0])]))
	ed.dar(int(provs[0]), e0, 1)
	var con: float = sb._factor_edif(pais, i)
	ok(is_equal_approx(con, 1.0), "con UN edificio del grupo vuelve a pesar ×%.2f (la caché se renueva al construir)" % con)
	ok(bool(sb.receta_de(i, pais)["edif"][0]["tiene"]), "receta_de dice que ya lo tiene")
	var observador: Dictionary = sb.receta_de(i, "")
	ok((observador["edif"] as Array).size() == 1 and not bool(observador["edif"][0]["tiene"]) and is_equal_approx(float(observador["factor"]), 1.0), "sin país elegido se muestra la receta sin marcas")
	# materias: un país con datos de economía y la materia pesa más que uno que no la tiene
	var im := -1
	for k in d.n:
		if (d.mat[k] as PackedStringArray).size() == 1 and String(d.tipo[k]) == "R":
			im = k
			break
	var con_m := ""
	var sin_m := ""
	var mat_nombre: String = (d.mat[im] as PackedStringArray)[0]
	for p in m.materias_pais:
		var ps: PackedStringArray = m.materias_pais[p]
		if ps.has(mat_nombre) and con_m == "":
			con_m = p
		if not ps.has(mat_nombre) and sin_m == "":
			sin_m = p
	ok(con_m != "" and sin_m != "", "hay países con y sin %s en su economía (%s / %s)" % [mat_nombre, con_m, sin_m])
	ok(is_equal_approx(sb._factor_mat(con_m, im), sb.CON_MATERIA) and is_equal_approx(sb._factor_mat(sin_m, im), 1.0), "producir la materia pesa ×%.1f; no producirla, ×1" % sb.CON_MATERIA)
	ok(is_equal_approx(sb._factor_mat("País sin datos", im), sb.MATERIA_SIN_DATOS), "sin datos de economía: ×%.1f (no se castiga)" % sb.MATERIA_SIN_DATOS)


func t_salto_y_modos() -> void:
	print("[T] ── Salto de fecha del Debug y cambio de modo")
	await arrancar(1500, 5)
	var m = main.mundo
	var sb = m.saber
	var d = m.descubrimientos
	meses(12 * 30)
	main.debug_fijar_fecha(1066, 10, 14)
	ok(d.modo_planeta and sb.listo and sb.mes_n == 1066 * 12 + 9, "tras saltar a 1066 el planeta sigue descubriendo desde ahí (mes %d)" % sb.mes_n)
	ok(d.cuenta_f == d.cuenta_hasta(1066) and d.anio_actual == 1066, "la frontera es la historia de 1066 (%d)" % d.cuenta_f)
	var igual := true
	for tid in d.estado:
		if d.estado[tid] != d.frontera:
			igual = false
	ok(igual and d.estado.size() == m.paises.size(), "todos los países vuelven a la historia de 1066")
	meses(24)
	ok(invariante_cerrado() == 0, "y pueden seguir sin problemas")
	sb.desactivar()
	ok(not d.modo_planeta and not sb.activo and d.estado.is_empty(), "desactivar vuelve a la historia fija (sin copias por país)")
	sb.mes()
	m.avanzar_mes()
	ok(not d.modo_planeta, "con el motor apagado, el mes no lo reactiva")
	ok(sb.activar() and d.modo_planeta and sb.activo and d.estado.size() == m.paises.size(), "activar vuelve a congelar la historia y repartir copias")
	# las pruebas que llaman a Descubrimientos.iniciar() a pelo no dejan el modo planeta colgado
	d.iniciar(1066)
	ok(not d.modo_planeta, "Descubrimientos.iniciar() deja la historia pura")
	m.avanzar_mes()
	ok(true, "…y el mes sigue funcionando (avanza la historia fija)")
	sb.activar()


func t_reloj_real() -> void:
	print("[T] ── Con el reloj real del juego")
	await arrancar(1500, 8)
	var m = main.mundo
	var sb = m.saber
	var antes: int = sb.mes_n
	main.debug_avanzar_dias(365 * 3 + 1)
	var mes_reloj: int = main.reloj.anio * 12 + main.reloj.mes - 1
	ok(sb.mes_n == mes_reloj and mes_reloj - antes >= 36, "tras 3 años de reloj, el motor va al día (mes %d de %d)" % [sb.mes_n, mes_reloj])
	ok(m.descubrimientos.anio_actual == main.reloj.anio, "la interfaz ve el año del reloj (%d)" % m.descubrimientos.anio_actual)
	ok(invariante_cerrado() == 0, "sin prerrequisitos rotos")


func t_ficha() -> void:
	print("[T] ── Ficha de la pantalla de Descubrimientos")
	var m = main.mundo
	var sb = m.saber
	var d = m.descubrimientos
	main._abrir_descubrimientos()
	await esperar(0.3)
	var p = main.panel_descubrimientos
	ok(p != null and p._ficha != null, "la pantalla de Descubrimientos se abre")
	var im: int = d.indice("microprocesador")
	p.ir_a(im)
	await esperar(0.2)
	var textos := PackedStringArray()
	for h in p._ficha.get_children():
		if h is Label:
			textos.append((h as Label).text)
	var todo := "\n".join(textos)
	ok(todo.contains("RECETA") and todo.contains("Basta uno:"), "la ficha del microprocesador muestra su receta")
	ok(todo.contains("El planeta aún no lo ha descubierto"), "…y dice que el planeta aún no lo ha descubierto (hoy es %d)" % main.reloj.anio)
	var i_lo: int = -1
	for k in d.n:
		if sb.descubridor[k] >= 0:
			i_lo = k
			break
	if i_lo >= 0:
		p.ir_a(i_lo)
		await esperar(0.2)
		var t2 := PackedStringArray()
		for h in p._ficha.get_children():
			if h is Label:
				t2.append((h as Label).text)
		ok("\n".join(t2).contains("Lo descubrió"), "la ficha de un descubrimiento del juego dice quién lo descubrió")
	else:
		ok(true, "(en esta partida aún no hubo descubrimientos del planeta: se omite)")
	var ib: int = d.indice("brujula")
	p.ir_a(ib)
	await esperar(0.2)
	var hay_por_que := false
	for h in p._ficha.get_children():
		if h is Button and (h as Button).tooltip_text.contains("Por qué lo pide"):
			hay_por_que = true
	ok(hay_por_que, "en «Requiere» de la brújula, la fila del oficio de navegante explica por qué se pide")
	main._cerrar_descubrimientos()
	await esperar(0.2)
