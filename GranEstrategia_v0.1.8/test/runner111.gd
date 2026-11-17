extends Node
## 0.1.8.51 · MARAVILLAS Y EDIFICIOS NUEVOS: el catálogo (178 edificios, 22 maravillas únicas en el mundo, 15 corrientes nuevos), su descubrimiento, efectos e icono, la regla de
## «solo una en todo el mundo» (obra, cancelar, construida, grupo, Debug), la IA que no las construye, su estrella en el mapa y la fila de la ficha.
var main
var m
var ed
var co
var fallos := 0
var n_ok := 0

const MARAVILLAS := ["piramides_giza", "jardines_colgantes", "partenon", "coloso_rodas", "gran_biblioteca_alejandria", "coliseo", "santa_sofia", "mezquita_cordoba", "borobudur",
	"angkor_wat", "alhambra", "machu_picchu", "taj_mahal", "cristo_redentor", "megatorre_record", "ciudad_prohibida", "versalles", "gran_muralla", "torre_eiffel",
	"presa_tres_gargantas", "cosmodromo", "colisionador_particulas"]
const CORRIENTES := ["minas_subterraneas", "canales_riego", "aduana_puesto_fronterizo", "termas_publicas", "casa_de_moneda", "puerto_pesquero", "campo_adiestramiento", "base_naval",
	"refineria_petroleo", "fabrica_automoviles", "base_aerea", "planta_quimica", "viviendas_publicas", "fabrica_semiconductores", "centro_datos"]


func _ready() -> void:
	main = load("res://mapa_principal.tscn").instantiate()
	add_child(main)
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


func textos(n: Node, acu: Array) -> void:
	if n is Label:
		acu.append((n as Label).text)
	if n is Button:
		acu.append((n as Button).text)
	for h in n.get_children():
		textos(h, acu)


func hay(raiz: Node, frag: String) -> bool:
	var t: Array = []
	textos(raiz, t)
	for x in t:
		if String(x).to_upper().contains(frag.to_upper()):
			return true
	return false


func leer_json(ruta: String) -> Variant:
	var f := FileAccess.open(ruta, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f != null else null


## Dos provincias de España donde se puede construir `e`.
func dos_provincias(e: int) -> Array:
	var r := []
	for pi in m.paises["España"].provincias:
		if not ed.obras_de(int(pi)).is_empty() or ed.cantidad(int(pi), e) > 0:
			continue
		if bool(ed.puede("España", int(pi), e)["ok"]):
			r.append(int(pi))
			if r.size() == 2:
				break
	return r


func run() -> void:
	await esperar(1.0)
	get_window().size = Vector2i(1280, 720)
	main._iniciar_partida({"modo": "campana", "pais": "España", "ia": 1})
	await esperar(0.8)
	main.reloj.velocidad = 0
	m = main.mundo
	ed = m.edificios
	co = main.capa_obras
	m.paises["España"].tesoreria = 1.0e15
	t_catalogo()
	t_descubrimientos()
	t_unicidad()
	t_ia()
	await t_mapa_y_ficha()
	print("[T] ═══ RESULTADO runner111: %d OK, FALLOS: %d" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


func t_catalogo() -> void:
	print("[T] ── Catálogo: 178 edificios, 22 maravillas")
	ok(ed.n == 178, "el catálogo tiene 178 edificios (%d)" % ed.n)
	var unicas := 0
	for e in ed.n:
		unicas += int(ed.unica[e])
	ok(unicas == 22, "22 son maravillas únicas (%d)" % unicas)
	var cats := {}
	for c in ed.categorias:
		cats[String(c["cod"])] = c
	ok(cats.has("mar") and ed.categorias.size() == 9, "hay una categoría «Maravillas del mundo» (9 categorías)")
	var todo_ok := true
	var iconos_ok := true
	var efectos_ok := true
	for sl in MARAVILLAS:
		var e: int = ed.indice(sl)
		if e < 0 or ed.unica[e] != 1 or String(ed.cat[e]) != "mar" or int(ed.tope[e]) != 1 or not (String(ed.clase[e]) in ["E", "F"]):
			todo_ok = false
		if e >= 0 and not ed.con_efecto(e):
			efectos_ok = false
		if not FileAccess.file_exists("res://iconos/edificios/%s.png" % sl):
			iconos_ok = false
	ok(todo_ok, "las 22 maravillas existen, son únicas, de categoría «mar», máximo 1 y de obra grande (E/F)")
	ok(efectos_ok, "y todas tienen efecto en el juego")
	ok(iconos_ok, "y su icono propio")
	var corr_ok := true
	for sl in CORRIENTES:
		var e2: int = ed.indice(sl)
		if e2 < 0 or ed.unica[e2] != 0 or not ed.con_efecto(e2) or not FileAccess.file_exists("res://iconos/edificios/%s.png" % sl):
			corr_ok = false
	ok(corr_ok, "los 15 corrientes existen, NO son únicos, tienen efecto e icono")
	var js = leer_json("res://datos/edificios.json")
	var con_flag := 0
	for x in js["edificios"]:
		if bool(x.get("unica", false)):
			con_flag += 1
	ok(con_flag == 22, "datos/edificios.json marca 22 como únicas")
	ok(ed.con_efecto(ed.indice("base_naval")) and ed.texto_efectos(ed.indice("piramides_giza")) != "", "el texto de efectos de una maravilla no está vacío (%s)" % ed.texto_efectos(ed.indice("piramides_giza")))


func t_descubrimientos() -> void:
	print("[T] ── Cada edificio nuevo tiene su descubrimiento de tipo B")
	var d = m.descubrimientos
	var bien := true
	var antes_ok := true
	for sl in MARAVILLAS + CORRIENTES:
		var i: int = d.indice(sl)
		if i < 0 or String(d.tipo[i]) != "B":
			bien = false
			continue
		for r in d.req[i]:
			if int(d.anio[int(r)]) > int(d.anio[i]):
				antes_ok = false
	ok(bien, "los 37 existen en el catálogo de descubrimientos como tipo B")
	ok(antes_ok, "ninguno pide algo posterior en el tiempo")
	ok(d.n == 1934, "el catálogo de descubrimientos tiene 1.934 (%d)" % d.n)
	ok(ed.anio[ed.indice("piramides_giza")] == -2560 and ed.anio[ed.indice("megatorre_record")] == 2010, "los años históricos: pirámides -2560 y megatorre 2010")


func t_unicidad() -> void:
	print("[T] ── Solo una en todo el mundo")
	ok(ed.maravillas_del_mundo().is_empty(), "al empezar no hay ninguna construida (no se reparten como los edificios de partida)")
	var e: int = ed.indice("coliseo")
	ok(ed.conoce("España", e), "España conoce el Coliseo en 2026")
	var ps := dos_provincias(e)
	ok(ps.size() == 2, "hay dos provincias de España donde se puede construir")
	if ps.size() < 2:
		return
	var a: int = ps[0]
	var b: int = ps[1]
	ok(ed.donde_unica(e) == -1, "nadie la tiene ni la construye")
	var r: Dictionary = ed.construir("España", a, e)
	ok(bool(r["ok"]), "se encarga en la primera provincia")
	ok(ed.donde_unica(e) == a, "queda reservada para esa provincia")
	var rb: Dictionary = ed.puede("España", b, e)
	ok(not bool(rb["ok"]) and String(rb["motivo"]).contains("solo hay una en todo el mundo") and String(rb["motivo"]).contains("se está construyendo"), "en la segunda no se puede mientras se construye: %s" % String(rb["motivo"]))
	# cancelar libera
	var c: Dictionary = ed.cancelar(a, 0)
	ok(bool(c["ok"]) and ed.donde_unica(e) == -1, "cancelar la obra libera la maravilla")
	ok(bool(ed.puede("España", b, e)["ok"]), "y ya se puede en la otra")
	# construir de verdad
	ed.construir("España", a, e)
	ok(ed.completar_obras(a) == 1, "se termina la obra")
	ok(ed.cantidad(a, e) == 1 and ed.donde_unica(e) == a, "construida: la tiene la provincia")
	var mv: PackedInt32Array = ed.maravillas_de(a)
	ok(mv.size() == 1 and mv[0] == e, "maravillas_de(provincia) la devuelve")
	var mundo_m: Dictionary = ed.maravillas_del_mundo()
	ok(mundo_m.size() == 1 and int(mundo_m[e]) == a, "maravillas_del_mundo: {Coliseo → esa provincia}")
	var rb2: Dictionary = ed.puede("España", b, e)
	ok(not bool(rb2["ok"]) and String(rb2["motivo"]).contains("ya existe"), "construida, en ninguna otra parte: %s" % String(rb2["motivo"]))
	var ra: Dictionary = ed.puede("España", a, e)
	ok(not bool(ra["ok"]), "y en la misma ya está construida (máximo 1)")
	# otro país tampoco
	var otro := ""
	var pi_o := -1
	for nombre in m.paises:
		if String(nombre) != "España" and not m.paises[nombre].inerte and m.paises[nombre].provincias.size() > 0:
			otro = String(nombre)
			pi_o = int(m.paises[nombre].provincias[0])
			break
	if otro != "":
		m.paises[otro].tesoreria = 1.0e15
		var ro: Dictionary = ed.puede(otro, pi_o, e)
		ok(not bool(ro["ok"]), "otro país (%s) tampoco puede levantarla: %s" % [otro, String(ro["motivo"]).left(60)])
	# grupo: solo una provincia
	var e2: int = ed.indice("taj_mahal")
	var ps2 := dos_provincias(e2)
	if ps2.size() == 2:
		var g: Dictionary = ed.construir_varias("España", ps2, e2)
		ok(int(g["hechas"]) == 1, "una orden de grupo levanta la maravilla en UNA sola provincia (%d)" % int(g["hechas"]))
		ok((ed.obras_de(int(ps2[0])).size() + ed.obras_de(int(ps2[1])).size()) == 1, "y hay una sola obra en el mundo")
		ed.cancelar(int(ps2[0]), 0)
	# Debug: dar la registra
	var e3: int = ed.indice("versalles")
	var ps3 := dos_provincias(e3)
	if ps3.size() == 2:
		ed.dar(int(ps3[0]), e3)
		ok(ed.donde_unica(e3) == int(ps3[0]) and not bool(ed.puede("España", int(ps3[1]), e3)["ok"]), "dar() de Debug también la registra (y bloquea las demás)")
		ed.quitar(int(ps3[0]), e3)
		ok(ed.donde_unica(e3) == -1, "y quitarla la libera")
	# un edificio normal no se ve afectado
	var norm: int = ed.indice("minas_subterraneas")
	var ps4 := dos_provincias(norm)
	if ps4.size() == 2:
		ed.construir("España", int(ps4[0]), norm)
		ok(bool(ed.puede("España", int(ps4[1]), norm)["ok"]), "un edificio normal sí se puede levantar en otra provincia")
	# cambio de dueño: la obra se pierde y se libera la reserva
	var e5: int = ed.indice("partenon")
	var ps5 := dos_provincias(e5)
	if ps5.size() == 2:
		ed.construir("España", int(ps5[0]), e5)
		ed.cambio_de_dueno(int(ps5[0]), "España")
		ok(ed.donde_unica(e5) == -1, "si la provincia cambia de dueño en plena obra, la reserva se libera")


func t_ia() -> void:
	print("[T] ── La IA no construye maravillas")
	var op = m.obras_publicas
	if op == null:
		print("[T] (no hay obras_publicas en esta partida)")
		return
	var hay_unica := false
	for e in op._orden:
		if ed.unica[int(e)] == 1:
			hay_unica = true
	ok(not hay_unica and op._orden.size() > 100, "ninguna maravilla está en la lista de la IA (%d edificios candidatos)" % op._orden.size())


func t_mapa_y_ficha() -> void:
	print("[T] ── Estrella en el mapa y fila «Maravillas» en la ficha")
	var e: int = ed.indice("coliseo")
	var pi_c: int = ed.donde_unica(e)
	if pi_c < 0:
		ok(false, "no hay Coliseo construido para probar el mapa")
		return
	var c: Vector2 = m.ejercito.red.centros[pi_c]
	main._limpiar_seleccion()
	main.camara.position = c
	main.camara.zoom = Vector2(1.0, 1.0)
	main._actualizar_zoom()
	var base: float = main._zoom_real()
	main.camara.zoom = Vector2(6.0 / base, 6.0 / base)
	main._actualizar_zoom()
	ed.version += 1
	await esperar(0.8)
	var vista := false
	for d in co.dibujadas:
		if int(d["pi"]) == pi_c and int(d["mar"]) >= 1:
			vista = true
	ok(vista and co.n_maravillas >= 1, "cerca (zoom 6) la provincia con el Coliseo lleva su estrella (%d)" % co.n_maravillas)
	main.camara.zoom = Vector2(1.0 / base, 1.0 / base)
	main._actualizar_zoom()
	await esperar(0.6)
	ok(co.n_maravillas == 0, "con el mapa lejos no se dibuja")
	# una maravilla en un país lejano también se ve (es famosa)
	var otro_pi := -1
	for nombre in m.paises:
		if String(nombre) != "España" and not m.paises[nombre].inerte and m.paises[nombre].provincias.size() > 0:
			otro_pi = int(m.paises[nombre].provincias[0])
			break
	if otro_pi >= 0:
		var e2: int = ed.indice("partenon")
		ed.dar(otro_pi, e2)
		var c2: Vector2 = m.ejercito.red.centros[otro_pi]
		main.camara.position = c2
		main.camara.zoom = Vector2(6.0 / base, 6.0 / base)
		main._actualizar_zoom()
		await esperar(0.8)
		var v2 := false
		for d in co.dibujadas:
			if int(d["pi"]) == otro_pi and int(d["mar"]) >= 1:
				v2 = true
		ok(v2, "la maravilla de un país ajeno, también")
		ed.quitar(otro_pi, e2)
	# ficha
	main._limpiar_seleccion()
	main._seleccion_provincia(pi_c, m.continente_de_provincia(pi_c), m.ejercito.red.centros[pi_c])
	await fotogramas(3)
	main.hud.abrir_pestana("general")
	await fotogramas(3)
	ok(hay(main.hud.cuerpo, "Maravillas") and hay(main.hud.cuerpo, "Coliseo romano"), "la ficha de la provincia dice «Maravillas · Coliseo romano»")
	# ventana Construir
	main._abrir_construir()
	await fotogramas(3)
	var w = main.panel_construir
	ok(w != null and is_instance_valid(w), "la ventana Construir se abre")
	if w != null and is_instance_valid(w):
		ok(hay(w, "MARAVILLA ÚNICA"), "y las maravillas llevan su aviso «★ MARAVILLA ÚNICA»")
		w._chk.set_pressed(true)
		await fotogramas(1)
		ok(w.filas_visibles == 178, "«mostrar también lo que no conoces»: los 178 (%d)" % w.filas_visibles)
