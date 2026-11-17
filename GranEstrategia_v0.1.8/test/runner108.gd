extends Node
## 0.1.8.51 · COMBATE TÁCTICO (scripts/combate.gd): el catálogo (datos/combate.json), la capacidad de un país, el despliegue en la cuadrícula, la batalla y sus reglas
## (tiro, caballería, lanceros, terreno, fortificación, nivel de las tropas, formaciones) y el bono estratégico por nivel.
const CombateScript := preload("res://scripts/combate.gd")
const DescubrimientosScript := preload("res://scripts/descubrimientos.gd")

var fallos := 0
var n_ok := 0
var c


func _ready() -> void:
	run.call_deferred()


func ok(cond: bool, msg: String) -> void:
	if cond:
		n_ok += 1
		print("[T] OK    ", msg)
	else:
		fallos += 1
		print("[T] FALLO ", msg)


func leer_json(ruta: String) -> Variant:
	var f := FileAccess.open(ruta, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f != null else null


## Capacidad de un país que conoce exactamente estos slugs.
func cap_de(slugs: Array) -> Dictionary:
	var conocidos := {}
	for s in slugs:
		conocidos[String(s)] = true
	return c.capacidad_por(func(sl: String) -> bool: return conocidos.has(sl))


func bando_de(cap: Dictionary, form: String, n: float, local := false, bono := 0.0, cal := 1.0) -> Dictionary:
	return c.bando(cap, int(c.idx_formacion[form]), n, cal, local, bono)


func pelea(a: Dictionary, d: Dictionary, terr := "llano", semilla := 1) -> Dictionary:
	return c.simular(a, d, int(c.idx_terreno[terr]), semilla)


func run() -> void:
	c = CombateScript.new()
	ok(c.iniciar(), "el catálogo de combate carga (datos/combate.json)")
	t_catalogo()
	t_capacidad()
	t_despliegue()
	t_batalla()
	t_reglas()
	t_formaciones()
	t_estrategico()
	t_rendimiento()
	print("[T] ═══ RESULTADO runner108: %d OK, FALLOS: %d" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_catalogo() -> void:
	print("[T] ── Catálogo")
	ok(c.n_armas == 10 and c.matriz.size() == 10, "10 clases de tropa y una matriz de 10 × 10 (%d / %d)" % [c.n_armas, c.matriz.size()])
	var matriz_ok := true
	for fila in c.matriz:
		matriz_ok = matriz_ok and (fila as PackedFloat32Array).size() == 10
		for v in fila:
			matriz_ok = matriz_ok and v >= 0.0 and v <= 3.0
	ok(matriz_ok, "cada fila de la matriz tiene 10 valores entre 0 y 3")
	ok(c.formaciones.size() >= 45, "hay %d formaciones (45 o más)" % c.formaciones.size())
	ok(c.terrenos.size() == 9, "9 terrenos")
	ok(c.tropas.size() >= 130, "%d tropas enlazadas con descubrimientos" % c.tropas.size())
	# todo descubrimiento citado existe y los cuadros son de 5 × 4
	var js = leer_json("res://datos/descubrimientos.json")
	var d = DescubrimientosScript.new()
	ok(d.cargar(js), "el catálogo de descubrimientos carga")
	var no_existe := []
	for t in c.tropas:
		if d.indice(String(t[0])) < 0:
			no_existe.append(String(t[0]))
	for fo in c.formaciones:
		if String(fo["req"]) != "" and d.indice(String(fo["req"])) < 0:
			no_existe.append(String(fo["req"]))
	for m in c.mejoras:
		if d.indice(String(m["req"])) < 0:
			no_existe.append(String(m["req"]))
	ok(no_existe.is_empty(), "todos los descubrimientos citados existen (%s)" % str(no_existe))
	var malos := []
	for fo in c.formaciones:
		var cu: Array = fo["cuadro"]
		if cu.size() != 5:
			malos.append(fo["slug"])
			continue
		for fila in cu:
			if String(fila).length() != 4:
				malos.append(fo["slug"])
	ok(malos.is_empty(), "todos los cuadros miden 5 filas × 4 columnas (%s)" % str(malos))
	# una formación nunca exige un descubrimiento de una época posterior a la suya
	var tarde := []
	for fo in c.formaciones:
		if String(fo["req"]) != "":
			var i: int = d.indice(String(fo["req"]))
			if int(d.anio[i]) != int(fo["anio"]):
				tarde.append(fo["slug"])
	ok(tarde.is_empty(), "el año de cada formación es el de su descubrimiento (%s)" % str(tarde))
	ok(c.idx_formacion.has("formacion_libre") and String(c.formaciones[int(c.idx_formacion["formacion_libre"])]["req"]) == "", "la formación libre no exige nada")
	# la matriz dice lo que debe: lanceros contra caballería, caballería contra tiradores, blindados contra infantería, aviación contra artillería
	var L: int = c.idx_arma["L"]
	var C: int = c.idx_arma["C"]
	var T: int = c.idx_arma["T"]
	var B: int = c.idx_arma["B"]
	var P: int = c.idx_arma["P"]
	var A: int = c.idx_arma["A"]
	var V: int = c.idx_arma["V"]
	ok(c.matriz[L][C] >= 1.8 and c.matriz[C][L] <= 0.6, "los lanceros ganan a la caballería pesada y esta pierde contra ellos")
	ok(c.matriz[C][T] >= 1.5 and c.matriz[B][P] >= 2.0 and c.matriz[V][A] >= 1.5, "la caballería gana a los arqueros, los blindados a la infantería y la aviación a la artillería")


func t_capacidad() -> void:
	print("[T] ── Capacidad de un país")
	var antiguo := cap_de(["hoplitas", "lanceros", "arqueros_tribales", "falange", "formacion_tribal", "batalla_campal_organizada", "disciplina_formacion"])
	var niv: PackedFloat32Array = antiguo["nivel"]
	ok(float(niv[c.idx_arma["P"]]) > 0.9 and float(niv[c.idx_arma["T"]]) > 0.0 and float(niv[c.idx_arma["F"]]) == 0.0, "un país antiguo tiene infantería pesada y arqueros, y no fusileros")
	var libres: PackedInt32Array = antiguo["formaciones"]
	var nombres := []
	for f in libres:
		nombres.append(String(c.formaciones[f]["slug"]))
	ok(nombres.has("formacion_libre") and nombres.has("falange_hoplita") and nombres.has("linea_de_choque") and not nombres.has("tercio"),
		"conoce la formación libre, la línea de choque y la falange, pero no el tercio (%s)" % str(nombres))
	var moderno := cap_de(["infanteria_moderna_conectada", "tanque_batalla_principal", "caza_supersonico", "obus_autopropulsado_moderno", "guerra_red_centrica", "cazacarros"])
	var nm: PackedFloat32Array = moderno["nivel"]
	ok(float(nm[c.idx_arma["B"]]) >= 5.0 and float(nm[c.idx_arma["V"]]) >= 6.0 and float(nm[c.idx_arma["F"]]) >= 5.0, "un país moderno tiene blindados, aviación y fusileros de alto nivel")
	ok((moderno["mej"] as Array).size() == 1, "el cazacarros da una mejora (fusileros contra blindados)")
	ok(c.nivel_ejercito(moderno) > 5.0 and c.nivel_ejercito(antiguo) < 1.1, "el nivel del ejército refleja la época (%.2f contra %.2f)" % [c.nivel_ejercito(moderno), c.nivel_ejercito(antiguo)])
	var nada := cap_de([])
	ok(c.nivel_ejercito(nada) == c.NIVEL_MIN, "un país sin tropas conocidas tiene el nivel mínimo")


func t_despliegue() -> void:
	print("[T] ── Despliegue")
	var antiguo := cap_de(["hoplitas", "lanceros", "arqueros_tribales", "falange", "formacion_tribal", "batalla_campal_organizada", "disciplina_formacion", "caballeria_ligera"])
	var f: int = c.idx_formacion["falange_hoplita"]
	var bl: Array = c.desplegar(antiguo, f, 10000.0)
	var suma := 0.0
	var dentro := true
	var celdas := {}
	for b in bl:
		suma += float(b["n"])
		dentro = dentro and int(b["f"]) >= 0 and int(b["f"]) < 5 and int(b["c"]) >= 0 and int(b["c"]) < 4
		celdas["%d,%d" % [b["f"], b["c"]]] = true
	ok(absf(suma - 10000.0) < 0.5, "el despliegue reparte todos los soldados (%.1f)" % suma)
	ok(dentro and celdas.size() == bl.size(), "cada bloque cae en su propia casilla de la cuadrícula (%d bloques)" % bl.size())
	# una clase que el país no conoce se sustituye por otra parecida
	var sin_arcos := cap_de(["lanceros", "hoplitas", "falange", "disciplina_formacion"])
	var bl2: Array = c.desplegar(sin_arcos, f, 10000.0)
	var hay_t := false
	for b in bl2:
		hay_t = hay_t or int(b["arma"]) == int(c.idx_arma["T"])
	ok(not hay_t and bl2.size() > 0, "sin arqueros, las casillas de tiro se rellenan con otras clases o se dejan vacías")
	# un cuadro de fusileros en un país sin pólvora se sustituye por tiradores
	var tercio: int = c.idx_formacion["tercio"]
	var pais_f := cap_de(["arcabuceros", "tercios", "piqueros", "ballesteros"])
	var celdas_t: Array = c.cuadro_para(pais_f, tercio)
	ok(celdas_t.size() >= 12, "el tercio se despliega con piqueros y arcabuceros (%d casillas)" % celdas_t.size())
	var vacio := cap_de([])
	ok(c.cuadro_para(vacio, f).size() >= 1, "un país sin tropas conocidas aún pone un bloque")
	ok(c.resolver_letra(antiguo, "M") >= 0 and c.resolver_letra(antiguo, "R") >= 0 and c.resolver_letra(antiguo, "S") >= 0, "las letras M, R y S se resuelven con lo mejor que hay")


func t_batalla() -> void:
	print("[T] ── La batalla")
	var cap := cap_de(["hoplitas", "lanceros", "arqueros_tribales", "falange", "batalla_campal_organizada", "disciplina_formacion", "caballeria_ligera", "formacion_tribal"])
	var a := bando_de(cap, "formacion_libre", 10000.0)
	var d := bando_de(cap, "formacion_libre", 10000.0)
	var r1 := pelea(a, d, "llano", 42)
	var r2 := pelea(a, d, "llano", 42)
	ok(r1["ganador"] == r2["ganador"] and absf(float(r1["bajas"][0]) - float(r2["bajas"][0])) < 0.001, "la misma semilla da la misma batalla")
	ok(int(r1["rondas"]) >= 1 and int(r1["rondas"]) <= c.MAX_RONDAS, "la batalla dura entre 1 y %d rondas (%d)" % [c.MAX_RONDAS, int(r1["rondas"])])
	var cons := true
	for i in 2:
		cons = cons and float(r1["restan"][i]) >= 0.0 and float(r1["restan"][i]) <= float(r1["n0"][i]) + 0.01
	ok(cons, "los soldados que quedan nunca superan los iniciales ni bajan de cero")
	# ejércitos iguales: el resultado se reparte y las bajas son parecidas
	var gana := [0, 0, 0]
	var bajas_a := 0.0
	var bajas_d := 0.0
	for s in 40:
		var r := pelea(a, d, "llano", 1000 + s)
		gana[int(r["ganador"]) + 1] += 1
		bajas_a += float(r["frac_bajas"][0])
		bajas_d += float(r["frac_bajas"][1])
	ok(int(gana[1]) + int(gana[2]) + int(gana[0]) == 40, "40 batallas, 40 resultados")
	ok(absf(bajas_a - bajas_d) / 40.0 < 0.10, "con ejércitos iguales las bajas medias son parecidas (%.2f / %.2f)" % [bajas_a / 40.0, bajas_d / 40.0])
	# más soldados ganan
	var grande := bando_de(cap, "formacion_libre", 20000.0)
	var pequeno := bando_de(cap, "formacion_libre", 8000.0)
	var rg := pelea(grande, pequeno)
	ok(rg["ganador"] == 0, "20.000 contra 8.000 con las mismas tropas: gana el grande (bajas %.0f %% contra %.0f %%)" % [float(rg["frac_bajas"][0]) * 100.0, float(rg["frac_bajas"][1]) * 100.0])
	# el nivel de las tropas pesa mucho: un ejército moderno arrasa a uno antiguo
	var moderno := cap_de(["infanteria_moderna_conectada", "tanque_batalla_principal", "caza_supersonico", "obus_autopropulsado_moderno", "guerra_red_centrica"])
	var rm := pelea(bando_de(moderno, "guerra_red", 8000.0), bando_de(cap, "formacion_libre", 20000.0))
	ok(rm["ganador"] == 0 and float(rm["frac_bajas"][0]) < 0.25, "8.000 soldados modernos vencen a 20.000 antiguos con pocas bajas (%.0f %%)" % (float(rm["frac_bajas"][0]) * 100.0))
	# el registro para la animación trae una entrada por ronda
	var rr: Dictionary = c.simular(a, d, int(c.idx_terreno["llano"]), 7, true)
	ok((rr["registro"] as Array).size() == int(rr["rondas"]) and (rr["registro"][0]["pos"] as Array).size() == (a["bloques"] as Array).size() + (d["bloques"] as Array).size(),
		"con `registrar` hay una entrada por ronda con la posición de todos los bloques")


func t_reglas() -> void:
	print("[T] ── Reglas: clases, terreno y fortificación")
	var base := cap_de(["lanceros", "hoplitas", "caballeria_pesada_catafracta", "arqueros_tribales", "caballeria_ligera", "falange", "disciplina_formacion"])
	# los piqueros en cuadro frenan a la caballería pesada de su época (mismos soldados)
	var solo_l := cap_de(["piqueros", "tactica_cuadro_piqueros"])
	var solo_c := cap_de(["caballeros_feudales", "carga_caballeria_pesada"])
	var gl := 0
	for s in 20:
		var r := pelea(bando_de(solo_l, "cuadro_piqueros", 6000.0), bando_de(solo_c, "carga_feudal", 6000.0), "llano", 50 + s)
		if r["ganador"] == 0:
			gl += 1
	ok(gl >= 12, "los piqueros en cuadro resisten a la caballería pesada en la mayoría de las batallas (%d de 20)" % gl)
	# y al revés, la misma caballería rompe a los arqueros en llano pero no en colinas
	var arq := cap_de(["arqueros_largos", "tactica_arqueros_masa", "infanteria_pesada_medieval"])
	var gc_llano := 0
	var gc_colina := 0
	for s in 20:
		if pelea(bando_de(solo_c, "carga_feudal", 8000.0), bando_de(arq, "arqueros_en_masa", 8000.0, true), "llano", 70 + s)["ganador"] == 0:
			gc_llano += 1
		if pelea(bando_de(solo_c, "carga_feudal", 8000.0), bando_de(arq, "arqueros_en_masa", 8000.0, true), "colina", 70 + s)["ganador"] == 0:
			gc_colina += 1
	ok(gc_llano > gc_colina and gc_colina <= 6, "la caballería gana a los arqueros en llano (%d de 20) y casi nunca en colinas (%d de 20)" % [gc_llano, gc_colina])
	# la guerrilla cuesta mucho más en la selva que en campo abierto
	var reg := cap_de(["mosqueteros", "tactica_linea", "infanteria_linea", "granaderos"])
	var gue := cap_de(["guerrilleros", "tactica_guerrilla", "mosqueteros"])
	var b_llano := 0.0
	var b_selva := 0.0
	for s in 20:
		b_llano += float(pelea(bando_de(reg, "linea_fuego", 8000.0), bando_de(gue, "guerrilla", 8000.0, true), "llano", 90 + s)["frac_bajas"][0])
		b_selva += float(pelea(bando_de(reg, "linea_fuego", 8000.0), bando_de(gue, "guerrilla", 8000.0, true), "selva", 90 + s)["frac_bajas"][0])
	ok(b_selva > 3.0 * b_llano, "la guerrilla desgasta al ejército regular en la selva (%.0f %% de bajas) mucho más que en llano (%.0f %%)" % [b_selva / 20.0 * 100.0, b_llano / 20.0 * 100.0])
	# el terreno: la caballería rinde bastante menos en montaña que en llano
	var cav_llano := 0.0
	var cav_mont := 0.0
	for s in 20:
		cav_llano += float(pelea(bando_de(base, "carga_feudal", 8000.0), bando_de(base, "formacion_libre", 8000.0), "llano", 200 + s)["frac_bajas"][1])
		cav_mont += float(pelea(bando_de(base, "carga_feudal", 8000.0), bando_de(base, "formacion_libre", 8000.0), "montana", 200 + s)["frac_bajas"][1])
	ok(cav_llano > cav_mont, "la carga de caballería hace más bajas en llano que en montaña (%.2f contra %.2f)" % [cav_llano / 20.0, cav_mont / 20.0])
	# fortificar: el defensor local con fortificación resiste mejor
	var sin_f := 0.0
	var con_f := 0.0
	for s in 20:
		sin_f += float(pelea(bando_de(base, "formacion_libre", 8000.0), bando_de(base, "formacion_libre", 8000.0, true, 0.0), "llano", 300 + s)["frac_bajas"][1])
		con_f += float(pelea(bando_de(base, "formacion_libre", 8000.0), bando_de(base, "formacion_libre", 8000.0, true, 0.6), "llano", 300 + s)["frac_bajas"][1])
	ok(con_f < sin_f, "la fortificación del defensor reduce sus bajas (%.2f contra %.2f)" % [con_f / 20.0, sin_f / 20.0])
	# la mejora: el cazacarros hace que la infantería dañe a los blindados
	var inf := cap_de(["infanteria_motorizada"])
	var inf_mej := cap_de(["infanteria_motorizada", "cazacarros"])
	var blin := cap_de(["tanque_medio"])
	var r_sin := pelea(bando_de(inf, "formacion_libre", 8000.0), bando_de(blin, "formacion_libre", 8000.0), "llano", 9)
	var r_con := pelea(bando_de(inf_mej, "formacion_libre", 8000.0), bando_de(blin, "formacion_libre", 8000.0), "llano", 9)
	ok(float(r_con["frac_bajas"][1]) > float(r_sin["frac_bajas"][1]), "con la mejora del cazacarros los blindados sufren más bajas (%.2f contra %.2f)" % [float(r_con["frac_bajas"][1]), float(r_sin["frac_bajas"][1])])
	# la calidad de las tropas importa
	var buena := pelea(bando_de(base, "formacion_libre", 8000.0, false, 0.0, 1.4), bando_de(base, "formacion_libre", 8000.0, false, 0.0, 0.8), "llano", 5)
	ok(buena["ganador"] == 0, "con las mismas fuerzas gana el de mejor calidad (experiencia y forma física)")
	# terreno desde bioma y altitud
	ok(c.terrenos[c.terreno_de("DES", 100.0)]["cod"] == "desierto" and c.terrenos[c.terreno_de("TEF", 50.0)]["cod"] == "selva" and c.terrenos[c.terreno_de("NTF", 1200.0)]["cod"] == "colina"
		and c.terrenos[c.terreno_de("NTF", 3000.0)]["cod"] == "montana" and c.terrenos[c.terreno_de("TEG", 80.0)]["cod"] == "llano" and c.terrenos[c.terreno_de("LAK", 10.0)]["cod"] == "pantano",
		"el terreno sale del bioma y de la altitud (desierto, selva, colinas, montaña, llano, pantano)")


func t_formaciones() -> void:
	print("[T] ── Formaciones")
	var cap := cap_de(["hoplitas", "lanceros", "arqueros_tribales", "falange", "falangitas", "batalla_campal_organizada", "disciplina_formacion", "caballeria_ligera", "formacion_tribal"])
	# la falange hoplita frente a una horda desordenada gana más que a otra falange
	var vs_horda := 0
	for s in 20:
		var r := pelea(bando_de(cap, "falange_hoplita", 8000.0), bando_de(cap, "horda_tribal", 8000.0), "llano", 400 + s)
		if r["ganador"] == 0:
			vs_horda += 1
	ok(vs_horda >= 12, "la falange vence a la horda tribal en la mayoría de las batallas en llano (%d de 20)" % vs_horda)
	# el testudo casi anula a los arqueros
	var cap_t := cap_de(["legionarios", "escudo_romano_scutum", "legion_manipular", "testudo_romana", "arqueros_largos", "ballesteros", "disciplina_formacion"])
	var tes := 0.0
	var lib := 0.0
	for s in 20:
		tes += float(pelea(bando_de(cap_t, "formacion_libre", 8000.0), bando_de(cap_t, "testudo", 8000.0), "llano", 500 + s)["frac_bajas"][1])
		lib += float(pelea(bando_de(cap_t, "formacion_libre", 8000.0), bando_de(cap_t, "formacion_libre", 8000.0), "llano", 500 + s)["frac_bajas"][1])
	ok(tes < lib, "el testudo sufre menos bajas que la formación libre ante el mismo ataque (%.2f contra %.2f)" % [tes / 20.0, lib / 20.0])
	# elegir formación: devuelve una que el país conoce y a lo menos igual de buena que la libre
	var rival := bando_de(cap, "formacion_libre", 8000.0)
	var mejor: int = c.mejor_formacion(cap, cap, int(c.idx_formacion["formacion_libre"]), int(c.idx_terreno["llano"]), 8000.0, 8000.0)
	ok((cap["formaciones"] as PackedInt32Array).has(mejor), "la formación sugerida es una que el país conoce (%s)" % String(c.formaciones[mejor]["slug"]))
	var r_m := pelea(bando_de(cap, String(c.formaciones[mejor]["slug"]), 8000.0), rival, "llano", 77)
	var r_l := pelea(bando_de(cap, "formacion_libre", 8000.0), rival, "llano", 77)
	ok(float(r_m["fuerza"][0]) - float(r_m["fuerza"][1]) >= float(r_l["fuerza"][0]) - float(r_l["fuerza"][1]) - 0.15, "la sugerida no es peor que la libre (%.2f contra %.2f)" % [float(r_m["fuerza"][0]) - float(r_m["fuerza"][1]), float(r_l["fuerza"][0]) - float(r_l["fuerza"][1])])
	ok(c.ficha_formacion(int(c.idx_formacion["falange_hoplita"])).contains("flancos"), "la ficha de la falange avisa de que es débil de flancos")
	# cada formación se puede desplegar y pelear sin errores con un país que lo conozca todo
	var todo: Dictionary = c.capacidad_por(func(_sl: String) -> bool: return true)
	var mal := []
	for k in c.formaciones.size():
		var r: Dictionary = c.simular(c.bando(todo, k, 5000.0), c.bando(todo, int(c.idx_formacion["formacion_libre"]), 5000.0), 0, 3)
		if int(r["rondas"]) < 1 or float(r["restan"][0]) < 0.0:
			mal.append(c.formaciones[k]["slug"])
	ok(mal.is_empty(), "las %d formaciones se despliegan y pelean sin errores (%s)" % [c.formaciones.size(), str(mal)])


func t_estrategico() -> void:
	print("[T] ── Bono estratégico")
	var antiguo := cap_de(["hoplitas", "lanceros"])
	var moderno := cap_de(["infanteria_moderna_conectada", "tanque_batalla_principal", "caza_supersonico"])
	var fa: float = c.factor_estrategico(antiguo)
	var fm: float = c.factor_estrategico(moderno)
	ok(fm > fa and fa > 0.8 and fm < 1.8, "el bono por nivel crece con la época y es moderado (%.2f → %.2f)" % [fa, fm])


func t_rendimiento() -> void:
	print("[T] ── Rendimiento")
	var todo: Dictionary = c.capacidad_por(func(_sl: String) -> bool: return true)
	var a: Dictionary = c.bando(todo, int(c.idx_formacion["armas_combinadas"]), 20000.0)
	var d: Dictionary = c.bando(todo, int(c.idx_formacion["linea_trincheras"]), 20000.0)
	var t0 := Time.get_ticks_usec()
	for s in 20:
		c.simular(a, d, 0, 900 + s)
	var ms := float(Time.get_ticks_usec() - t0) / 20000.0
	ok(ms < 25.0, "una batalla completa tarda %.2f ms (límite 25 ms)" % ms)
	var t1 := Time.get_ticks_usec()
	c.mejor_formacion(todo, todo, int(c.idx_formacion["formacion_libre"]), 0, 20000.0, 20000.0)
	var ms2 := float(Time.get_ticks_usec() - t1) / 1000.0
	ok(ms2 < 1500.0, "elegir la mejor de %d formaciones tarda %.0f ms (límite 1.500 ms)" % [c.formaciones.size(), ms2])
