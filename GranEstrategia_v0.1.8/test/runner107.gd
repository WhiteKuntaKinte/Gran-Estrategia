extends Node
## 0.1.8.48 · CUENTA INCREMENTAL DE SOLDADOS POR PAÍS (scripts/ejercito.gd: `soldados_por_pais` con `_sold_sucios`, contra la pasada completa de siempre `soldados_por_pais_completo`).
## Cada operación que toca soldados (reclutar, reforzar, bajas, dividir, fusionar, disolver, desertar) y el paso de los días con todas las IA deben dejar las dos cuentas IGUALES.
var main
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
	main._poner_velocidad(0)


## ¿Las dos cuentas dan lo mismo en todos los países?
func iguales(ej) -> bool:
	var a: Dictionary = ej.soldados_por_pais()
	var b: Dictionary = ej.soldados_por_pais_completo()
	if a.size() != b.size():
		return false
	for k in b:
		if int(a.get(k, -1)) != int(b[k]):
			return false
	return true


func diferencias(ej) -> String:
	var a: Dictionary = ej.soldados_por_pais()
	var b: Dictionary = ej.soldados_por_pais_completo()
	var t := "tamaños %d / %d" % [a.size(), b.size()]
	var c := 0
	for k in b:
		if int(a.get(k, -1)) != int(b[k]):
			c += 1
			if c <= 3:
				t += " · país %d: %d contra %d" % [int(k), int(a.get(k, -1)), int(b[k])]
	return t


func run() -> void:
	await t_operaciones()
	await t_dias(2026, 120)
	await t_dias(1500, 90)
	await t_repaso_y_coste()
	print("[T] ═══ RESULTADO runner107: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_operaciones() -> void:
	print("[T] ── Operaciones sobre pelotones")
	await arrancar(2026)
	var m = main.mundo
	var ej = m.ejercito
	ok(ej.sold_pasadas_completas == 0 or ej.sold_pasadas_completas == 1, "al empezar hay a lo sumo una pasada completa (%d)" % ej.sold_pasadas_completas)
	ok(iguales(ej), "la primera cuenta (pasada completa) coincide con la de siempre")
	ok(ej.sold_pasadas_completas == 1, "…y quedó anotada como completa (%d)" % ej.sold_pasadas_completas)
	# países con ejército y sus provincias
	var paises := []
	for n in m.paises:
		var ent = m.paises[n]
		if ej.ejercito_de(int(ent.tid)) >= 0 and not ent.provincias.is_empty() and ej.por_pais.has(int(ent.tid)) and (ej.por_pais[int(ent.tid)] as Array).size() > 3:
			paises.append(n)
	paises.sort()
	ok(paises.size() > 40, "hay países con ejército (%d)" % paises.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	var malas := 0
	var por_op := {}
	var primera_mala := ""
	var inc0: int = ej.sold_pasadas_incrementales
	for i in 360:
		var nombre: String = paises[rng.randi() % paises.size()]
		var ent = m.paises[nombre]
		var tid: int = int(ent.tid)
		var lista: Array = ej.por_pais.get(tid, [])
		var op: String
		var r := rng.randi() % 8
		if lista.is_empty():
			r = 0
		match r:
			0:
				op = "reclutar"
				var pi: int = int(ent.provincias[rng.randi() % ent.provincias.size()])
				ej.reclutar(tid, int(m.provincias[pi].tid), 50 + rng.randi() % 2500)
			1:
				op = "bajas"
				ej.aplicar_bajas(int(lista[rng.randi() % lista.size()]), 1 + rng.randi() % 600)
			2:
				op = "reforzar"
				ej.reforzar(int(lista[rng.randi() % lista.size()]), 1 + rng.randi() % 400)
			3:
				op = "dividir"
				var id: int = int(lista[rng.randi() % lista.size()])
				var s: int = ej.soldados_de(id)
				if s > 4:
					ej.dividir(id, 1 + rng.randi() % (s - 1))
			4:
				op = "compactar"
				var id2: int = int(lista[rng.randi() % lista.size()])
				var rid: int = ej.reg_de(id2)
				if rid >= 0:
					ej.compactar_reg(rid)
			5:
				op = "disolver regimiento"
				var id3: int = int(lista[rng.randi() % lista.size()])
				var rid3: int = ej.reg_de(id3)
				if rid3 >= 0 and rng.randi() % 3 == 0:
					ej.disolver_reg(rid3)
			6:
				op = "desertar"
				ej.desertar_pais(tid, 0.02 + rng.randf() * 0.1)
			_:
				op = "disolver pelotón"
				ej.disolver(int(lista[rng.randi() % lista.size()]))
		por_op[op] = int(por_op.get(op, 0)) + 1
		if not iguales(ej):
			malas += 1
			if primera_mala == "":
				primera_mala = "tras «%s» nº %d: %s" % [op, i, diferencias(ej)]
	ok(malas == 0, "360 operaciones al azar: la cuenta incremental coincide con la completa en todas (%d distintas; %s)" % [malas, primera_mala if primera_mala != "" else "sin diferencias"])
	var tipos_ok := true
	for k in ["reclutar", "bajas", "reforzar", "dividir", "compactar", "desertar", "disolver pelotón", "disolver regimiento"]:
		if int(por_op.get(k, 0)) < 5:
			tipos_ok = false
	ok(tipos_ok, "se probaron todos los tipos de operación (%s)" % str(por_op))
	ok(ej.sold_pasadas_incrementales - inc0 > 250, "casi todas las cuentas fueron incrementales (%d incrementales, %d completas)" % [ej.sold_pasadas_incrementales - inc0, ej.sold_pasadas_completas])
	ok(ej.sold_pasadas_completas <= 1 + 360 / ej.SOLD_REPASO_CADA + 1, "las pasadas completas son solo el arranque y los repasos")
	ok(ej.sold_correcciones == 0, "los repasos no encontraron ninguna diferencia (%d correcciones)" % ej.sold_correcciones)
	# sin cambios no hay trabajo: la cuenta guardada se devuelve tal cual
	var c0: Dictionary = ej.soldados_por_pais()
	var inc1: int = ej.sold_pasadas_incrementales
	var c1: Dictionary = ej.soldados_por_pais()
	ok(c0 == c1 and ej.sold_pasadas_incrementales == inc1, "sin cambios no se cuenta otra vez")
	# un pelotón de un país distinto no mueve la cuenta de los demás
	var a_nom: String = paises[0]
	var b_nom: String = paises[1]
	var a_tid: int = int(m.paises[a_nom].tid)
	var b_tid: int = int(m.paises[b_nom].tid)
	var antes_b: int = int(ej.soldados_por_pais().get(b_tid, 0))
	var antes_a: int = int(ej.soldados_por_pais().get(a_tid, 0))
	var pl: Array = ej.por_pais[a_tid]
	var idq: int = int(pl[0])
	var sq: int = ej.soldados_de(idq)
	var quitados: int = ej.aplicar_bajas(idq, mini(sq, 7))
	ok(int(ej.soldados_por_pais().get(a_tid, 0)) == antes_a - quitados and int(ej.soldados_por_pais().get(b_tid, 0)) == antes_b, "unas bajas solo restan en su país (−%d)" % quitados)


func t_dias(anio: int, dias: int) -> void:
	print("[T] ── %d días de %d con todas las IA" % [dias, anio])
	await arrancar(anio)
	var m = main.mundo
	var ej = m.ejercito
	m.ia.activar_lista(m.ia.candidatos())
	ok(iguales(ej), "(%d) al empezar las dos cuentas coinciden" % anio)
	var malas := 0
	var primera := ""
	var comp0: int = ej.sold_pasadas_completas
	var inc0: int = ej.sold_pasadas_incrementales
	var guerras_vistas := 0
	for d in dias:
		m.avanzar_dias(1)
		if d % 3 == 0:
			if not iguales(ej):
				malas += 1
				if primera == "":
					primera = "día %d: %s" % [d, diferencias(ej)]
	guerras_vistas = m.guerra.guerras.size() if m.guerra != null and "guerras" in m.guerra else 0
	ok(malas == 0, "(%d) tras %d días con la IA reclutando y peleando coinciden siempre (%d diferencias; %s)" % [anio, dias, malas, primera if primera != "" else "sin diferencias"])
	ok(ej.sold_pasadas_incrementales - inc0 > 5, "(%d) se usó la cuenta incremental (%d incrementales, %d completas nuevas)" % [anio, ej.sold_pasadas_incrementales - inc0, ej.sold_pasadas_completas - comp0])
	# fin de mes / año: el envejecimiento no cambia los soldados
	m.avanzar_dias(40)
	ok(iguales(ej), "(%d) tras cruzar un cambio de mes siguen iguales" % anio)
	ok(guerras_vistas >= 0, "(%d) guerras en curso: %d" % [anio, guerras_vistas])
	m.ia.desactivar_todas()


func t_repaso_y_coste() -> void:
	print("[T] ── Repaso y coste")
	await arrancar(2026)
	var m = main.mundo
	var ej = m.ejercito
	ok(iguales(ej), "(arranque) coinciden")
	# un cambio que se escapa (se escribe la columna sin anotarlo) se corrige en el próximo repaso completo
	var tid: int = 0
	for n in m.paises:
		var e = m.paises[n]
		if ej.por_pais.has(int(e.tid)) and (ej.por_pais[int(e.tid)] as Array).size() > 2:
			tid = int(e.tid)
			break
	var id: int = int((ej.por_pais[tid] as Array)[0])
	var ix: int = m.bd.idx(id)
	var col: PackedFloat64Array = m.bd.vars["soldados"].col_f
	col[ix] += 100.0                                           # sin _marcar_sold
	ej._cambio()
	var viejo: Dictionary = ej.soldados_por_pais()
	var real: Dictionary = ej.soldados_por_pais_completo()
	ok(int(viejo.get(tid, 0)) != int(real.get(tid, 0)), "un cambio no anotado deja la cuenta atrasada hasta el repaso (%d contra %d)" % [int(viejo.get(tid, 0)), int(real.get(tid, 0))])
	var corr0: int = ej.sold_correcciones
	ej._sold_desde_repaso = ej.SOLD_REPASO_CADA
	ej._cambio()
	ok(iguales(ej), "…y el repaso completo la deja bien")
	ok(ej.sold_correcciones == corr0 + 1, "…y lo anota como corrección (%d)" % ej.sold_correcciones)
	# coste: un cambio pequeño + la cuenta, contra la pasada completa
	var t_inc := 0
	var n_inc := 200
	var lista: Array = ej.por_pais[tid]
	for i in n_inc:
		ej.aplicar_bajas(int(lista[i % lista.size()]) if ej.existe(int(lista[i % lista.size()])) else id, 1)
		var t0 := Time.get_ticks_usec()
		ej.soldados_por_pais()
		t_inc += Time.get_ticks_usec() - t0
	var t_comp := 0
	for i in 20:
		var t1 := Time.get_ticks_usec()
		ej.soldados_por_pais_completo()
		t_comp += Time.get_ticks_usec() - t1
	var us_inc: float = float(t_inc) / float(n_inc)
	var us_comp: float = float(t_comp) / 20.0
	print("[B] cuenta de soldados: incremental %.0f µs, completa %.0f µs (%d pelotones)" % [us_inc, us_comp, ej.cuenta_pelotones()])
	ok(us_inc < us_comp * 0.35 + 50.0, "la cuenta incremental cuesta mucho menos que la completa (%.0f µs contra %.0f µs)" % [us_inc, us_comp])
	ok(iguales(ej), "(final) coinciden")
