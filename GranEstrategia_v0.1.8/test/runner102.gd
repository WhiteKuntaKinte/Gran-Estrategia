extends Node
## 0.1.8.46 · PRUEBAS DE LOS CIMIENTOS DEL SABER: catálogo ampliado (41 descubrimientos nuevos y 49 enlaces entre ramas en la 0.1.8.46; +43 y +16 en la 0.1.8.47; +36 y +41 en la 0.1.8.50), recetas (edificios y materias que ayudan)
## con su validador, y el azar sin estado (scripts/azar.gd).
const AzarScript := preload("res://scripts/azar.gd")
const DescubrimientosScript := preload("res://scripts/descubrimientos.gd")

var fallos := 0
var n_ok := 0
var d


func _ready() -> void:
	run.call_deferred()


func ok(cond: bool, msg: String) -> void:
	if cond:
		n_ok += 1
		print("[T] OK    ", msg)
	else:
		fallos += 1
		print("[T] FALLO ", msg)


func leer_json(ruta: String) -> Dictionary:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return {}
	return JSON.parse_string(f.get_as_text())


func run() -> void:
	var js := leer_json("res://datos/descubrimientos.json")
	d = DescubrimientosScript.new()
	ok(d.cargar(js), "el catálogo carga con las columnas de la receta (edif, mat, regla)")
	t_catalogo()
	t_enlaces()
	t_tejido_050()
	t_recetas()
	t_generador()
	t_azar()
	print("[T] ═══ RESULTADO runner102: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_catalogo() -> void:
	print("[T] ── Catálogo ampliado")
	ok(d.n == 1959 and d.secciones.size() == 40, "1.959 descubrimientos en 40 secciones (%d / %d)" % [d.n, d.secciones.size()])
	var nuevos := ["archivos_estatales", "posta_imperial", "censo_periodico", "presupuesto_nacional", "registro_parroquial", "estadisticas_vitales", "tablas_de_mortalidad",
		"escuelas_primeras_letras", "aprendizaje_gremial", "formacion_de_maestros", "correspondencia_erudita", "bibliotecas_publicas", "enciclopedias", "congresos_cientificos",
		"oficio_herrero", "oficio_medico", "oficio_arquitecto", "oficio_navegante", "ensayo_de_metales", "normalizacion_industrial", "prospeccion_minera", "caminos_de_peaje",
		"red_telegrafica_nacional", "transicion_demografica", "demografia_cientifica", "doctorado_investigacion",
		# 0.1.8.47: gente, escuela y campo
		"obstetricia_cientifica", "pediatria", "atencion_prenatal", "control_vectores", "fortificacion_alimentos", "terapia_rehidratacion_oral", "jabon_higiene", "banos_publicos",
		"hospicios_beneficencia", "agua_clorada", "saneamiento_rural", "calendario_vacunacion_infantil", "atencion_primaria_salud", "rotacion_cuatro_hojas", "cadena_de_frio",
		"extension_agricola", "maiz_hibrido", "riego_por_goteo", "pedagogia_cientifica", "escolaridad_obligatoria", "educacion_de_ninas", "secundaria_masiva", "codigos_construccion"]
	var faltan := []
	for s in nuevos:
		if d.indice(s) < 0:
			faltan.append(s)
	ok(faltan.is_empty(), "los descubrimientos nuevos existen (faltan: %s)" % str(faltan))
	var i: int = d.indice("registro_parroquial")
	var sec: Dictionary = d.secciones[int(d.seccion[i])]
	ok(String(sec["cod"]) == "TER" and String(d.subsecciones[int(d.sub[i])]) == "Población y estadística", "una sección «+» se reabre y trae su subsección nueva (%s › %s)" % [String(sec["cod"]), String(d.subsecciones[int(d.sub[i])])])
	# toda la lista: año dentro de su era, año >= el de sus prerrequisitos, sin ciclos (el generador ya lo comprueba; aquí se comprueba el JSON)
	var mal_anio := 0
	var mal_req := 0
	for k in d.n:
		var e: Dictionary = d.eras[int(d.era[k])]
		if (e["desde"] != null and int(d.anio[k]) < int(e["desde"])) or (e["hasta"] != null and int(d.anio[k]) > int(e["hasta"])):
			mal_anio += 1
		for r in d.req[k]:
			if int(d.anio[r]) > int(d.anio[k]):
				mal_req += 1
	ok(mal_anio == 0 and mal_req == 0, "años dentro de su era (%d mal) y nunca antes de sus prerrequisitos (%d mal)" % [mal_anio, mal_req])


func t_enlaces() -> void:
	print("[T] ── Enlaces entre ramas (enlaces.txt)")
	var pares := [["registro_civil", "registro_parroquial"], ["estadistica_oficial", "estadisticas_vitales"], ["burocracia_moderna", "contabilidad_publica"],
		["pensiones", "tablas_de_mortalidad"], ["alfabetizacion_masiva", "formacion_de_maestros"], ["brujula", "oficio_navegante"], ["rec_petroleo", "prospeccion_minera"],
		["espada_acero", "oficio_herrero"], ["acero_crisol", "ensayo_de_metales"], ["revistas_cientificas", "correspondencia_erudita"],
		["revolucion_verde", "maiz_hibrido"], ["revolucion_verde", "extension_agricola"], ["sistema_nacional_salud", "atencion_prenatal"], ["educacion_universal_gratuita", "escolaridad_obligatoria"],
		["megaciudades", "cadena_de_frio"], ["planificacion_familiar", "educacion_de_ninas"], ["seguro_salud_universal", "seguro_enfermedad_obrero"], ["oms_cooperacion_sanitaria", "control_vectores"]]
	var malos := []
	var sin_porque := []
	for p in pares:
		var a: int = d.indice(p[0])
		var b: int = d.indice(p[1])
		if a < 0 or b < 0:
			malos.append("%s←%s (no existe)" % [p[0], p[1]])
			continue
		var pide: bool = (d.req[a] as PackedInt32Array).has(b)
		for g in d.req_o[a]:
			if (g as PackedInt32Array).has(b):
				pide = true
		if not pide:
			malos.append("%s no pide %s" % [p[0], p[1]])
		if d.por_que_requisito(a, b) == "":
			sin_porque.append(p[0])
	ok(malos.is_empty(), "los enlaces extra están en los prerrequisitos (%s)" % str(malos))
	ok(sin_porque.is_empty(), "cada enlace extra trae su porqué (sin: %s)" % str(sin_porque))
	ok(d.por_que_requisito(d.indice("brujula"), d.indice("oficio_navegante")).contains("navegante"), "el porqué se lee: «%s»" % d.por_que_requisito(d.indice("brujula"), d.indice("oficio_navegante")))
	ok(d.por_que_requisito(d.indice("fuego"), d.indice("registro_parroquial")) == "", "un par sin enlace extra no inventa porqué")
	var dep: PackedInt32Array = d.dependientes[d.indice("oficio_navegante")]
	ok(dep.has(d.indice("brujula")) and dep.has(d.indice("sextante")), "«Abre» de oficio_navegante incluye la brújula y el sextante (%d)" % dep.size())
	# más conexión entre ramas: cuántos descubrimientos piden algo de OTRA rama
	var cruzados := 0
	for k in d.n:
		var rama_k: int = int(d.secciones[int(d.seccion[k])]["rama"])
		for r in d.req[k]:
			if int(d.secciones[int(d.seccion[r])]["rama"]) != rama_k:
				cruzados += 1
				break
	ok(cruzados > 150, "hay descubrimientos que piden algo de otra rama (%d)" % cruzados)


func t_tejido_050() -> void:
	print("[T] ── Tejido del saber II (0.1.8.50: 36 descubrimientos y 41 enlaces)")
	var nuevos := [
		"central_electrica", "oleoducto_gasoducto", "red_electrica_nacional", "electrificacion_rural",
		"central_nuclear_civil", "eficiencia_energetica", "mercado_electrico", "telefonia_automatica",
		"television_color", "navegacion_satelital_civil", "hoja_calculo", "software_libre",
		"firma_digital", "cibernetica", "ferrocarril_transcontinental", "senalizacion_ferroviaria",
		"vuelo_supersonico_civil", "carga_aerea_expres", "taxi_plataforma", "fabrica_electrificada",
		"proteccionismo_arancelario", "regulacion_bancaria", "descentralizacion_administrativa", "referendum_moderno",
		"derecho_del_mar", "derecho_aeronautico", "derecho_espacial", "marcas_diseno_industrial",
		"derecho_quiebras", "pasaportes_fronteras", "extradicion_tratados", "asilo_refugiados",
		"censura_previa", "cine_sonoro", "parques_nacionales", "topografia_militar_moderna"
	]
	var faltan := []
	for s in nuevos:
		if d.indice(s) < 0:
			faltan.append(s)
	ok(faltan.is_empty() and nuevos.size() == 36, "los 36 descubrimientos nuevos existen (faltan: %s)" % str(faltan))
	var pares := [
		["television_satelite_cable", "satelite_comunicaciones"], ["smartphone_adopcion", "telefonia_celular_digital"], ["internet_publico", "navegador_buscador"],
		["comercio_electronico", "cifrado_web_ssl"], ["redes_sociales", "www_web"], ["streaming_video", "fibra_optica"],
		["cadenas_suministro_globales", "contenedor_maritimo"], ["logistica_just_in_time", "codigo_barras_inventario"], ["mercados_financieros_globales", "satelite_comunicaciones"],
		["derivados_financieros", "computadora_personal"], ["banca_electronica", "computadora_digital"], ["tarjeta_credito", "credito_consumo"],
		["fordismo", "cadena_montaje"], ["publicidad_masiva", "imprenta_rotativa"], ["propaganda_masiva", "radiodifusion"],
		["agencia_senales", "criptoanalisis_mecanico"], ["guerra_relampago", "radio_campana"], ["armas_combinadas", "radio_campana"],
		["doctrina_movilizacion_ferroviaria", "red_telegrafica"], ["logistica_motorizada", "camion"], ["guerra_total", "propaganda_masiva"],
		["guerra_hibrida", "redes_sociales"], ["guerra_red_centrica", "internet_tecnologia"], ["ciberguerra", "ciberseguridad"],
		["armas_antisatelite", "satelite_comunicaciones"], ["tren_alta_velocidad", "electrificacion_rural"], ["contenedor_maritimo", "buque_motor_diesel"],
		["tabuladora_hollerith", "censo_periodico"], ["internet_de_las_cosas", "sensores_mems"], ["vehiculos_autonomos", "lidar_sensor"],
		["planificacion_central", "estadistica_oficial"], ["banca_central", "contabilidad_partida_doble"], ["sociedad_anonima", "companias_comerciales"],
		["derecho_ambiental", "movimiento_ecologista"], ["igualdad_genero_legal", "sufragio_femenino"], ["derechos_minorias", "derechos_civiles_movimiento"],
		["ong", "cruz_roja_humanitaria"], ["union_supranacional", "integracion_regional"], ["tratado_no_proliferacion", "armas_nucleares"],
		["acuerdos_climaticos", "derecho_ambiental"], ["criptomonedas", "criptografia_clave_publica"]
	]
	var malos := []
	var sin_porque := []
	for p in pares:
		var a: int = d.indice(p[0])
		var b: int = d.indice(p[1])
		if a < 0 or b < 0:
			malos.append("%s←%s (no existe)" % [p[0], p[1]])
			continue
		var pide: bool = (d.req[a] as PackedInt32Array).has(b)
		for g in d.req_o[a]:
			if (g as PackedInt32Array).has(b):
				pide = true
		if not pide:
			malos.append("%s no pide %s" % [p[0], p[1]])
		elif int(d.anio[b]) > int(d.anio[a]):
			malos.append("%s (%d) pide %s (%d) que es posterior" % [p[0], int(d.anio[a]), p[1], int(d.anio[b])])
		if d.por_que_requisito(a, b) == "":
			sin_porque.append(p[0])
	ok(pares.size() == 41 and malos.is_empty(), "los 41 enlaces nuevos están en los prerrequisitos y ninguno pide algo posterior (%s)" % str(malos))
	ok(sin_porque.is_empty(), "cada enlace nuevo trae su porqué (sin: %s)" % str(sin_porque))
	# cadena de la energía: la central abre la red, la red abre la electrificación rural, la central nuclear y el mercado eléctrico
	var red: int = d.indice("red_electrica_nacional")
	var dep: PackedInt32Array = d.dependientes[red]
	ok(dep.has(d.indice("electrificacion_rural")) and dep.has(d.indice("central_nuclear_civil")) and dep.has(d.indice("mercado_electrico")), "«Abre» de la red eléctrica nacional trae la electrificación rural, la nuclear civil y el mercado eléctrico (%d)" % dep.size())
	ok((d.req[d.indice("taxi_plataforma")] as PackedInt32Array).has(d.indice("navegacion_satelital_civil")), "el taxi por plataforma pide la navegación satelital civil")
	# ninguno de los nuevos cae en una sección que alimenta los índices de saber (la demografía no se mueve)
	var prohibidas := ["MED", "SAL", "AGR", "BIO", "EDU", "HUM", "TER", "ING"]
	var en_saber := []
	for s in nuevos:
		var cod := String(d.secciones[int(d.seccion[d.indice(s)])]["cod"])
		if prohibidas.has(cod):
			en_saber.append("%s (%s)" % [s, cod])
	ok(en_saber.is_empty(), "ningún descubrimiento nuevo cae en una sección de los índices de saber (%s)" % str(en_saber))


func t_recetas() -> void:
	print("[T] ── Recetas (edificios y materias)")
	var eco := leer_json("res://datos/economia.json")
	var mats := {}
	for nombre in eco.get("pais", {}):
		for m in eco["pais"][nombre].get("mat", []):
			mats[String(m)] = true
	var ed := leer_json("res://datos/edificios.json")
	var es_edif := {}
	for e in ed.get("edificios", []):
		es_edif[String(e["slug"])] = true
	var con_edif := 0
	var con_mat := 0
	var mal_tipo := 0
	var mal_anio := 0
	var mal_ciclo := 0
	var mal_mat := 0
	var mal_regla := 0
	for i in d.n:
		var grupos: Array = d.edif[i]
		if not grupos.is_empty():
			con_edif += 1
		if (d.regla[i] as PackedInt32Array).size() != grupos.size():
			mal_regla += 1
		for r in d.regla[i]:
			if int(r) < 0 or int(r) >= d.razones.size():
				mal_regla += 1
		for g in grupos:
			if (g as PackedInt32Array).is_empty():
				mal_anio += 1
			for b in g:
				if String(d.tipo[int(b)]) != "B" or not es_edif.has(String(d.slug[int(b)])):
					mal_tipo += 1
				if int(d.anio[int(b)]) > int(d.anio[i]):
					mal_anio += 1
				if int(b) == i or _depende(int(b), i):
					mal_ciclo += 1
		if not (d.mat[i] as PackedStringArray).is_empty():
			con_mat += 1
		for m in d.mat[i]:
			if not mats.has(String(m)):
				mal_mat += 1
	ok(con_edif > 800 and con_mat > 300, "hay recetas: %d con edificios, %d con materias" % [con_edif, con_mat])
	ok(mal_tipo == 0, "todo edificio de una receta es un edificio del catálogo (tipo B) (%d mal)" % mal_tipo)
	ok(mal_anio == 0, "todo edificio de una receta existe a la fecha del descubrimiento y ningún grupo queda vacío (%d mal)" % mal_anio)
	ok(mal_ciclo == 0, "ningún edificio de una receta depende del propio descubrimiento (%d ciclos)" % mal_ciclo)
	ok(mal_mat == 0, "toda materia de una receta existe en economia.json (%d mal)" % mal_mat)
	ok(mal_regla == 0, "cada grupo de edificios trae su razón (%d mal)" % mal_regla)
	var i_mic: int = d.indice("microprocesador")
	var nombres := []
	for b in d.edif[i_mic][0]:
		nombres.append(String(d.slug[int(b)]))
	ok(nombres.has("universidades_investigacion") and nombres.has("laboratorios_industriales") and String(d.razones[int(d.regla[i_mic][0])]).contains("escuelas técnicas"),
		"el microprocesador pide universidades o laboratorios (%s)" % str(nombres))
	ok((d.edif[d.indice("fuego")] as Array).is_empty(), "lo primitivo (el fuego) no pide edificios")
	ok((d.mat[d.indice("rec_petroleo")] as PackedStringArray).has("Petróleo"), "prospectar petróleo lo facilita producir petróleo")
	# la receta de un edificio puede pedir otros edificios más viejos, nunca a sí mismo
	var i_cat: int = d.indice("rascacielos")
	var sin_si := true
	for g in d.edif[i_cat]:
		if (g as PackedInt32Array).has(i_cat):
			sin_si = false
	ok(sin_si, "el rascacielos no se pide a sí mismo")


## ¿`a` depende (transitivamente) de `b`? (b es un antepasado de a)
func _depende(a: int, b: int) -> bool:
	var vistos := {}
	var pila := [a]
	while not pila.is_empty():
		var x: int = pila.pop_back()
		if vistos.has(x):
			continue
		vistos[x] = true
		if x == b:
			return true
		for r in d.req[x]:
			pila.append(int(r))
		for g in d.req_o[x]:
			for r2 in g:
				pila.append(int(r2))
	return false


func t_generador() -> void:
	print("[T] ── Validador del generador (python3 herramientas/construir_descubrimientos.py)")
	var py := ["python3", "python"]
	var cmd := ""
	for c in py:
		var salida := []
		if OS.execute(c, ["--version"], salida) == 0:
			cmd = c
			break
	if cmd == "":
		ok(true, "(no hay Python en este equipo: se omiten las pruebas del generador)")
		return
	var raiz := ProjectSettings.globalize_path("res://")
	var gen := raiz.path_join("herramientas/construir_descubrimientos.py")
	var s1 := []
	var c1 := OS.execute(cmd, ["-I", gen, "--solo-comprobar"], s1, true)
	ok(c1 == 0 and String(s1[0]).contains("1959 descubrimientos"), "el generador comprueba el catálogo entero sin errores")
	var tmp := OS.get_user_data_dir().path_join("enlaces_malos.txt")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("bronce|sextante|un enlace con un año imposible\n")
	f.close()
	var s2 := []
	var c2 := OS.execute(cmd, ["-I", gen, "--solo-comprobar", "--enlaces=" + tmp], s2, true)
	ok(c2 != 0 and String(s2[0]).contains("anterior a su prerrequisito"), "un enlace con año imposible (el bronce pidiendo el sextante) lo rechaza")
	f = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("fuego|slug_que_no_existe|requisito inexistente\nslug_que_no_existe|fuego|descubrimiento inexistente\nfuego|bronce\n")
	f.close()
	var s3 := []
	var c3 := OS.execute(cmd, ["-I", gen, "--solo-comprobar", "--enlaces=" + tmp], s3, true)
	var t3 := String(s3[0])
	ok(c3 != 0 and t3.contains("prerrequisito desconocido") and t3.contains("no existe") and t3.contains("formato"), "rechaza requisitos que no existen, descubrimientos que no existen y líneas mal formadas")
	DirAccess.remove_absolute(tmp)


func t_azar() -> void:
	print("[T] ── Azar sin estado")
	var a1 := AzarScript.u(777, 1, 5, 6, 7)
	var a2 := AzarScript.u(777, 1, 5, 6, 7)
	ok(a1 == a2 and a1 >= 0.0 and a1 < 1.0, "la misma pregunta da siempre la misma respuesta (%f)" % a1)
	# no depende del orden ni de cuántas preguntas se hicieron antes
	var primero := AzarScript.u(42, 2, 10, 20, 30)
	for k in 1000:
		AzarScript.u(42, 3, k, k * 3)
	ok(AzarScript.u(42, 2, 10, 20, 30) == primero, "…aunque entre medias se pidan mil números más")
	ok(AzarScript.u(43, 2, 10, 20, 30) != primero and AzarScript.u(42, 3, 10, 20, 30) != primero and AzarScript.u(42, 2, 11, 20, 30) != primero, "cambiar semilla, tema o cualquier dato cambia la respuesta")
	# distribución: media 0,5, 10 cajas parejas, sin correlación evidente entre vecinos
	var cajas := PackedInt32Array()
	cajas.resize(10)
	var suma := 0.0
	var previo := 0.0
	var cov := 0.0
	var N := 40000
	for k in N:
		var v := AzarScript.u(2026, 1, k, 3)
		suma += v
		cajas[int(v * 10.0)] += 1
		cov += (v - 0.5) * (previo - 0.5)
		previo = v
	ok(absf(suma / float(N) - 0.5) < 0.01, "media ≈ 0,5 (%.4f)" % (suma / float(N)))
	var parejas := true
	for c in cajas:
		if absf(float(c) - float(N) / 10.0) > 0.05 * float(N) / 10.0 * 2.0:
			parejas = false
	ok(parejas, "10 cajas parejas: %s" % str(cajas))
	ok(absf(cov / float(N)) < 0.005, "sin correlación entre vecinos (%.5f)" % (cov / float(N)))
	# pequeñas probabilidades: 1 de cada 1000 sale cerca de 1/1000
	var raros := 0
	for k in 200000:
		if AzarScript.u(9, 1, k) < 0.001:
			raros += 1
	ok(raros > 140 and raros < 270, "un riesgo de 0,001 sale unas 200 de 200.000 (%d)" % raros)
	# exponencial de media 1
	var se := 0.0
	for k in 20000:
		se += AzarScript.expo(5, 3, k)
	ok(absf(se / 20000.0 - 1.0) < 0.05, "tiempos de espera exponenciales de media 1 (%.3f)" % (se / 20000.0))
	var s_nueva := AzarScript.semilla_nueva()
	ok(s_nueva > 0, "una semilla nueva es positiva (%d)" % s_nueva)
