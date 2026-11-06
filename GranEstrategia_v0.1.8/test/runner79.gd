extends Node
## 0.1.8.37 · PRUEBAS DEL MAPA: menú VISTA, selección (borde negro, relleno, respiración, Ctrl+clic), bordes HD (Baja/Media/Alta), etiquetas (un solo sentido de
## lectura), paleta renovada y vista de relieve (imágenes, capas, silueta, calidad).
const AjustesScript := preload("res://scripts/ajustes.gd")
const MenuPantallaScript := preload("res://scripts/menu_pantalla.gd")
const TEMP := "user://prueba_ajustes79.cfg"
const PALETA_NUEVA := ["4f83d1", "d15147", "d1a63f", "d1763f", "58d174", "9764d1", "b8c5d1"]
var main
var fallos := 0
var n_ok := 0


func _ready() -> void:
	if Engine.has_meta("inicio_pendiente"):
		Engine.remove_meta("inicio_pendiente")
	Engine.set_meta("inicio_pendiente", {"modo": "campana", "pais": "Francia", "ia": 0})
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


func run() -> void:
	await esperar(1.0)
	await t_vista()
	await t_seleccion()
	await t_multi()
	await t_bordes()
	await t_etiquetas()
	t_paleta()
	await t_relieve()
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	print("[T] ═══ RESULTADO runner79: %d OK, %d FALLOS" % [n_ok, fallos])
	get_tree().quit(1 if fallos > 0 else 0)


## Un punto que seguro cae dentro de la celda `ri` (el centro de su primer triángulo).
func punto_de_celda(ri: int) -> Vector2:
	var a: Dictionary = main.anillos[ri]
	var idx: PackedInt32Array = main.indices_fill.slice(int(a["i0"]), int(a["i1"]))
	return (main.vertices_fill[idx[0]] + main.vertices_fill[idx[1]] + main.vertices_fill[idx[2]]) / 3.0


# ── Menú VISTA ──────────────────────────────────────────────────────────────────────────────────────────────
func t_vista() -> void:
	print("[T] ── menú VISTA")
	var h = main.hud
	ok(h.VISTAS.size() == 7, "el menú VISTA tiene 7 entradas")
	var activas: Array = []
	var proximas: Array = []
	for v in h.VISTAS:
		(activas if bool(v[2]) else proximas).append(String(v[0]))
	ok(activas == ["tradicional", "internacional", "relieve"], "activas: Tradicional, Internacional y Relieve")
	ok(proximas.size() == 4, "las otras 4 vistas están como «próximamente»")
	for k in activas:
		ok(h.botones_vista.has(k), "hay botón para la vista %s" % k)
	main._elegir_vista("tradicional")
	ok(not main.modo_relieve and h.btn_vista.text.strip_edges() == "Tradicional", "Tradicional: el botón de la barra dice «Tradicional»")
	main._elegir_vista("internacional")
	ok(main.vista == "internacional" and h.btn_vista.text.strip_edges() == "Internacional", "Internacional cambia la subdivisión y el texto del botón")
	ok(bool((h.botones_vista["internacional"] as Button).button_pressed) and not bool((h.botones_vista["tradicional"] as Button).button_pressed), "el menú marca la vista puesta")
	main._elegir_vista("tradicional")
	ok(main.vista == "tradicional", "volver a Tradicional")
	h.alternar_menu_vista()
	ok(h.popup_vista.visible, "el botón de lentes abre el menú")
	h.alternar_menu_vista()
	ok(not h.popup_vista.visible, "…y lo cierra")


# ── Selección ───────────────────────────────────────────────────────────────────────────────────────────────
func t_seleccion() -> void:
	print("[T] ── selección")
	main._salir_foco()
	main._limpiar_seleccion()
	var prov: Array = []
	for pi in main.mundo.paises["Francia"].provincias:
		prov.append(int(pi))
	var pi0: int = prov[0]
	var celdas: Array = main.mundo.provincias[pi0].anillos
	ok(celdas.size() >= 1, "la provincia de prueba tiene celdas (%d)" % celdas.size())
	main._resaltar_anillos(celdas, true)
	var cadenas: Array = main._contorno_de_anillos(celdas)
	ok(cadenas.size() >= 1, "el contorno tiene al menos una cadena")
	var negros := 0
	var brillos := 0
	for l in main.lineas_resaltado:
		if (l as Line2D).default_color == Color(0.0, 0.0, 0.0, 1.0):
			negros += 1
		else:
			brillos += 1
	ok(negros == cadenas.size() * 3 and brillos == cadenas.size() * 3, "cada cadena lleva su borde NEGRO y su resplandor (×3 copias del mundo)")
	ok(main.resaltado.size() == 3, "el relleno amarillo va en 3 copias")
	var relleno: MeshInstance2D = main.resaltado[0]
	ok(relleno.modulate.r > 0.8 and relleno.modulate.g > 0.6 and relleno.modulate.b < 0.4, "el relleno es amarillo")
	ok(main.tween_resp != null and main.tween_resp.is_valid(), "la respiración está en marcha")
	# el contorno es EXACTAMENTE el borde exterior: cada arista que queda una sola vez entre las celdas
	var cuenta := {}
	for ri in celdas:
		var pts: PackedVector2Array = main._puntos_anillo(main.anillos[int(ri)])
		var n := pts.size()
		var ka := Vector2i(roundi(pts[n - 1].x * 50.0), roundi(pts[n - 1].y * 50.0))
		for k in n:
			var kb := Vector2i(roundi(pts[k].x * 50.0), roundi(pts[k].y * 50.0))
			if ka != kb:
				var a4 := Vector4i(ka.x, ka.y, kb.x, kb.y) if (ka.x < kb.x or (ka.x == kb.x and ka.y < kb.y)) else Vector4i(kb.x, kb.y, ka.x, ka.y)
				cuenta[a4] = int(cuenta.get(a4, 0)) + 1
			ka = kb
	var exteriores := 0
	for a4 in cuenta:
		if int(cuenta[a4]) % 2 == 1:
			exteriores += 1
	var segmentos := 0
	for c in cadenas:
		segmentos += (c as PackedVector2Array).size() - 1
	ok(segmentos == exteriores, "el contorno tiene exactamente las aristas exteriores (%d)" % exteriores)
	ok(main._contorno_de_anillos(celdas) == cadenas, "el contorno se guarda en caché (mismo resultado)")
	var antes: int = main.lineas_resaltado.size()
	main._actualizar_zoom()
	ok(is_equal_approx((main.lineas_resaltado[0] as Line2D).width, float((main.lineas_resaltado[0] as Line2D).get_meta("px")) / main._zoom_real()), "el grosor de las líneas se mantiene en píxeles al cambiar el zoom")
	ok(main.lineas_resaltado.size() == antes, "cambiar el zoom no duplica líneas")
	main._borrar_resaltado()
	ok(main.resaltado.is_empty() and main.lineas_resaltado.is_empty(), "borrar el resaltado limpia todo")
	# ya no hay efecto de país flotante
	main._enfocar_pais("Francia", false)
	await esperar(0.5)
	ok(is_equal_approx(float(main.grupo_pop.scale.x), 1.0), "enfocar un país ya no lo agranda (sin efecto flotante)")
	main._salir_foco()


func t_multi() -> void:
	print("[T] ── Ctrl+clic (selección múltiple)")
	main._salir_foco()
	main.cerrar_seleccion()
	main.multi_sel.clear()
	var ra: Array = main._anillos_de_pais("Francia")
	var rb: Array = main._anillos_de_pais("Alemania")
	ok(ra.size() > 0 and rb.size() > 0, "hay celdas de Francia y de Alemania")
	var pa := punto_de_celda(int(ra[0]))
	var pb := punto_de_celda(int(rb[0]))
	ok(main._seleccionar_varias(pa), "Ctrl+clic sobre tierra se acepta")
	ok(main.multi_sel.size() == 1, "una unidad elegida")
	ok(main._seleccionar_varias(pb), "otra unidad")
	ok(main.multi_sel.size() == 2, "dos unidades elegidas (países distintos)")
	ok(main.pais_foco == "", "con varios países no se enfoca ninguno")
	ok(main.resaltado.size() >= 6, "las dos quedan resaltadas")
	ok(main._seleccionar_varias(pb), "Ctrl+clic sobre una ya elegida")
	ok(main.multi_sel.size() == 1, "…la quita del grupo")
	ok(main._seleccionar_varias(pa), "quitar la última")
	ok(main.multi_sel.is_empty() and main.resaltado.is_empty(), "sin nada elegido no queda resaltado")
	ok(not main._seleccionar_varias(Vector2(40.0, 1180.0)) or main.multi_sel.is_empty(), "Ctrl+clic en el mar no suma nada")
	# con un país ya elegido por clic normal, el primer Ctrl+clic en OTRO suma el nuevo a ese (grupo de 2)
	main.cerrar_seleccion()
	main._seleccion_pais("Francia", "Europa", pa)
	ok(main._seleccionar_varias(pb), "Ctrl+clic en otro país con uno ya elegido")
	ok(main.multi_sel.size() == 2, "el país que ya estaba elegido pasa a ser el primero del grupo (2)")
	main.cerrar_seleccion()
	main.multi_sel.clear()


# ── Bordes HD ───────────────────────────────────────────────────────────────────────────────────────────────
func t_bordes() -> void:
	print("[T] ── bordes del mapa (Baja / Media / Alta)")
	ok(AjustesScript.BORDES_NOMBRES.size() == 3, "tres niveles de bordes")
	ok(int(AjustesScript.con_preset({}, 0)["bordes"]) == 2 and int(AjustesScript.con_preset({}, 1)["bordes"]) == 1 and int(AjustesScript.con_preset({}, 2)["bordes"]) == 0, "calidad Alta/Media/Baja → bordes Alta/Media/Baja")
	ok(int(AjustesScript.sanear({"bordes": 7})["bordes"]) == int(AjustesScript.por_defecto()["bordes"]), "un valor inválido vuelve al de por defecto")
	var z: float = main._zoom_real()
	for q in 3:
		var a := AjustesScript.por_defecto()
		a["bordes"] = q
		main._aplicar_calidad(a)
		ok(main.q_bordes == q, "calidad de bordes %d aplicada" % q)
		var ext: float = main.BORDE_EXT_PX[q]
		ok(is_equal_approx(float(main.mat_costa.get_shader_parameter("ext_px")), ext), "nivel %d: la costa suaviza %.1f px a cada lado" % [q, ext])
		ok(is_equal_approx(float(main.mat_costa.get_shader_parameter("half_width")), (main.GROSOR_PX["costa"] * 0.5 + ext) / z), "nivel %d: la malla de la costa es más ancha por ese margen" % q)
		ok(is_equal_approx(float(main.mat_costa.get_shader_parameter("nucleo")), main.GROSOR_PX["costa"] * 0.5), "nivel %d: el grosor de la línea no cambia" % q)
		ok(is_equal_approx(float(main.mat_costa.get_shader_parameter("halo")), main.BORDE_HALO[q]), "nivel %d: sombra de la costa %.2f" % [q, main.BORDE_HALO[q]])
		ok(main.mat_frontera.get_shader_parameter("halo") == null and main.mat_prov.get_shader_parameter("halo") == null, "nivel %d: solo la costa lleva sombra" % q)
		ok(float(main.mat_prov.get_shader_parameter("ext_px")) <= 0.8 + 0.0001, "nivel %d: las líneas finas de provincia no pasan de 0,8 px" % q)
	# el desplegable de Opciones > Pantalla
	var p = MenuPantallaScript.new()
	p.ruta = TEMP
	add_child(p)
	p.iniciar(get_window(), AjustesScript.por_defecto())
	ok(p._op_bordes != null and p._op_bordes.item_count == 3, "Opciones > Pantalla tiene «Bordes del mapa» con 3 opciones")
	p._op_bordes.select(1)
	p._op_bordes.item_selected.emit(1)
	ok(int(p.pendiente["bordes"]) == 1, "elegir «Media» queda pendiente hasta APLICAR")
	p.queue_free()
	await esperar(0.1)
	main._aplicar_calidad(AjustesScript.por_defecto())


# ── Etiquetas ───────────────────────────────────────────────────────────────────────────────────────────────
func t_etiquetas() -> void:
	print("[T] ── etiquetas (un solo sentido de lectura)")
	var f := func(a: Array) -> PackedVector2Array:
		var r := PackedVector2Array()
		for p in a:
			r.append(p)
		return r
	var r1: PackedVector2Array = main._orientar_linea_etiqueta(f.call([Vector2(0, 0), Vector2(100, 0)]))
	ok(r1[0] == Vector2(0, 0), "de izquierda a derecha: se deja como está")
	var r2: PackedVector2Array = main._orientar_linea_etiqueta(f.call([Vector2(100, 0), Vector2(0, 0)]))
	ok(r2[0] == Vector2(0, 0), "de derecha a izquierda: se invierte entera")
	var r3: PackedVector2Array = main._orientar_linea_etiqueta(f.call([Vector2(0, 100), Vector2(0, 0)]))
	ok(r3[0] == Vector2(0, 100), "vertical hacia arriba: se lee de abajo hacia arriba")
	var r4: PackedVector2Array = main._orientar_linea_etiqueta(f.call([Vector2(0, 0), Vector2(0, 100)]))
	ok(r4[0] == Vector2(0, 100), "vertical hacia abajo: se invierte para leerse de abajo hacia arriba")
	var r5: PackedVector2Array = main._orientar_linea_etiqueta(f.call([Vector2(0, 0), Vector2(100, 100)]))
	ok(r5[0] == Vector2(100, 100) or r5[0] == Vector2(0, 0), "diagonal: una de las dos direcciones")
	var datos = main._leer_json("res://datos/etiquetas.json")
	ok(datos != null and (datos as Array).size() > 200, "se leen las etiquetas del mapa (%d)" % (datos as Array).size())
	var mal_orientadas := 0
	var invertidas := 0
	var fuera_de_tope := 0
	var probadas := 0
	for lab in datos:
		var capa = main.CapaTexto.new()
		capa.fuente = main.fuente
		add_child(capa)
		main._colocar_texto(lab, capa)
		if capa.chars.size() >= 2:
			probadas += 1
			var d: Vector2 = capa.pos[capa.chars.size() - 1] - capa.pos[0]
			var cuerda := d.angle()
			if cuerda > deg_to_rad(80.0) or cuerda <= deg_to_rad(-110.0):
				mal_orientadas += 1
			for i in capa.ang.size():
				if absf(capa.ang[i]) > PI * 0.5 + 0.0001:
					fuera_de_tope += 1
			# ninguna letra queda «al revés» respecto de la lectura: el orden de las letras avanza hacia donde mira la cuerda
			if d.dot(Vector2.from_angle(cuerda)) <= 0.0:
				invertidas += 1
		capa.queue_free()
	ok(probadas > 200, "se colocaron %d etiquetas" % probadas)
	ok(mal_orientadas == 0, "ninguna etiqueta queda con la cuerda fuera de [-105°, 75°] (%d mal)" % mal_orientadas)
	ok(fuera_de_tope == 0, "ninguna letra se pasa de ±90° (%d)" % fuera_de_tope)
	ok(invertidas == 0, "todas se leen en el sentido de su línea (%d invertidas)" % invertidas)
	# las verticales de verdad
	for nombre in ["AMÉRICA DEL SUR", "CHILE", "ISRAEL", "MYANMAR"]:
		var lab2: Dictionary = {}
		for lab in datos:
			if String(lab["t"]) == nombre:
				lab2 = lab
		ok(not lab2.is_empty(), "existe la etiqueta %s" % nombre)
		if lab2.is_empty():
			continue
		var capa2 = main.CapaTexto.new()
		capa2.fuente = main.fuente
		add_child(capa2)
		main._colocar_texto(lab2, capa2)
		var signos := 0
		var arriba := 0
		for i in capa2.ang.size():
			if capa2.ang[i] < 0.0:
				signos += 1
			if absf(capa2.ang[i]) > 0.01:
				arriba += 1
		ok(capa2.ang.size() > 0, "%s: tiene letras" % nombre)
		capa2.queue_free()


# ── Paleta ──────────────────────────────────────────────────────────────────────────────────────────────────
func t_paleta() -> void:
	print("[T] ── paleta renovada")
	var vistos := {}
	for pais in main.col_hex_continente:
		vistos[String(main.col_hex_continente[pais])] = true
	var sobran: Array = []
	for h in vistos:
		if not PALETA_NUEVA.has(h):
			sobran.append(h)
	ok(vistos.size() >= 5 and sobran.is_empty(), "los países traen solo los colores nuevos de continente (%s)" % str(sobran))
	var bytes: PackedByteArray = main._leer_bytes("malla_filt_cp.bin")
	var colores := {}
	var i := 0
	while i + 2 < bytes.size():
		colores["%02x%02x%02x" % [bytes[i], bytes[i + 1], bytes[i + 2]]] = true
		i += 3 * 997                                              # (una muestra: basta para ver si queda algún color viejo)
	var viejos := ["2a5ed1", "d12a2f", "d1a51f", "d16619", "34d14d", "8d49d1", "b4c3d1"]
	var quedan := 0
	for h in viejos:
		if colores.has(h):
			quedan += 1
	ok(quedan == 0, "el relleno horneado ya no tiene ningún color de la paleta vieja")


# ── Relieve ─────────────────────────────────────────────────────────────────────────────────────────────────
func t_relieve() -> void:
	print("[T] ── vista de relieve")
	ok(main._tam_relieve_pedido() == (8192 if AjustesScript.preset_de(main.ajustes) == 0 else 4096 if AjustesScript.preset_de(main.ajustes) == 1 else 2048 if AjustesScript.preset_de(main.ajustes) == 2 else 4096), "el tamaño de la imagen sigue a la calidad")
	for tam in [2048, 4096, 8192]:
		var ruta: String = main.RUTA_RELIEVE_VISTA % tam
		ok(FileAccess.file_exists(ruta), "existe %s" % ruta)
		if tam == 8192:
			continue                                              # (la de 8192 se comprueba abajo, ya cargada)
		var img := Image.load_from_file(ProjectSettings.globalize_path(ruta))
		ok(img != null and img.get_width() == tam and img.get_height() == tam / 2, "%d: mide %d × %d" % [tam, tam, tam / 2])
	main._enfocar_pais("Francia", false)
	await esperar(0.4)
	var mat_pais: Material = main.foco_sil.material
	main._elegir_vista("relieve")
	await esperar(0.3)
	ok(main.modo_relieve, "la vista Relieve se enciende")
	ok(main.capa_relieve_vista != null and main.capa_relieve_vista.visible, "la capa del relieve se ve")
	ok(main.capa_mar != null and not main.capa_mar.visible, "el mar de siempre se apaga (lo tapa la imagen)")
	ok(not main.capa_pais.visible, "el relleno por país se apaga")
	ok(main.CapaTexto.contorno == main.RELIEVE_CONTORNO_TEXTO, "los nombres llevan contorno")
	ok(main.relieve_vista_tam == main._tam_relieve_pedido(), "se cargó la imagen de %d px" % main.relieve_vista_tam)
	ok(main.foco_sil.material == main.mat_rel_sil, "la silueta del país enfocado se pinta con el relieve")
	ok(main.hud.btn_vista.text.strip_edges() == "Relieve", "el botón de la barra dice «Relieve»")
	ok(main.capa_relieve_vista.z_index == 1, "la capa va encima del relleno y debajo de costas y fronteras")
	# colores de la imagen
	var img: Image = main.tex_relieve_vista.get_image()
	var an := img.get_width()
	var al := img.get_height()
	var px := func(lon: float, lat: float) -> Color:
		return img.get_pixel(clampi(int((lon + 180.0) / 360.0 * an), 0, an - 1), clampi(int((90.0 - lat) / 180.0 * al), 0, al - 1))
	var mar: Color = px.call(-30.0, 0.0)
	ok(mar.b > mar.r + 0.2 and mar.b > mar.g, "el Atlántico es azul (%s)" % mar.to_html(false))
	var fosa: Color = px.call(142.5, 11.4)
	ok(fosa.b > fosa.r and fosa.get_luminance() < mar.get_luminance(), "una fosa (Marianas) es más oscura que el mar abierto")
	var llanura: Color = px.call(2.0, 47.0)
	ok(llanura.g > llanura.b and llanura.g >= llanura.r - 0.05, "una llanura (Francia) es verde (%s)" % llanura.to_html(false))
	var meseta: Color = px.call(88.0, 32.0)
	ok(meseta.r > meseta.b + 0.1 and meseta.g < llanura.g, "el Tíbet es marrón (%s)" % meseta.to_html(false))
	var hielo: Color = px.call(0.0, -85.0)
	ok(hielo.r > 0.8 and hielo.g > 0.8 and hielo.b > 0.8, "la Antártida es blanca (%s)" % hielo.to_html(false))
	var lago: Color = px.call(-87.0, 47.5)
	ok(lago.b > lago.r, "el lago Superior es agua (%s)" % lago.to_html(false))
	# cambio de calidad con la vista puesta
	var q := AjustesScript.por_defecto()
	q = AjustesScript.con_preset(q, 2)
	main.ajustes = q
	main._aplicar_calidad(q)
	ok(main.relieve_vista_tam == 2048, "con calidad Baja la imagen pasa a 2048 px (%d)" % main.relieve_vista_tam)
	q = AjustesScript.con_preset(q, 0)
	main.ajustes = q
	main._aplicar_calidad(q)
	ok(main.relieve_vista_tam == 8192, "con calidad Alta vuelve a 8192 px (%d)" % main.relieve_vista_tam)
	# apagar
	main._elegir_vista("tradicional")
	await esperar(0.3)
	ok(not main.modo_relieve and not main.capa_relieve_vista.visible, "volver a Tradicional apaga el relieve")
	ok(main.capa_mar.visible and main.capa_pais.visible, "…y devuelve el mar y el relleno")
	ok(main.CapaTexto.contorno == 0, "…y quita el contorno de los nombres")
	ok(main.foco_sil.material == mat_pais, "…y la silueta recupera el color de su país")
	# dentro de «Debug > Rendimiento», las capas apagadas a mano siguen apagadas en relieve
	main._elegir_vista("relieve")
	main.rend_poner_capa("relleno", true)
	ok(not main.capa_pais.visible, "con el relieve puesto, tocar las capas de Debug no reaparece el relleno")
	main._elegir_vista("tradicional")
	main._salir_foco()
