extends Node
## Ventana CONSTRUIR (0.1.8.40): los 109 edificios del catálogo para una provincia o para un grupo de provincias (Ctrl+clic).
## Ventana flotante (no pausa el juego): categorías, «solo lo que ya conoces», costo y días de cada edificio, estado (construido / en obra / no se puede),
## botón Construir (con grupo: «Construir ×N», una orden en cada provincia donde se pueda), y las obras en curso con su avance y botón de cancelar.
## No guarda nada: todo vive en Edificios (scripts/edificios.gd) y en la base de datos. Se actualiza sola una vez por segundo mientras está abierta.

signal cerrada

const VentanaScript := preload("res://scripts/ventana_flotante.gd")
const Tema := preload("res://scripts/tema_hud.gd")
const REFRESCO := 1.0                       # segundos entre actualizaciones
const ICONO_FILA := 40.0                     # lado del icono de cada edificio en la lista (los PNG son de 128 px con mipmaps)
const MAX_OBRAS_VISIBLES := 40             # tope de filas en «Obras en curso» (con un país entero puede haber cientos)

var main
var fuente: Font
var vf: VentanaScript
var pis: Array = []                         # provincias elegidas (índices en Mundo.provincias): TODAS las que se pidieron
var pais := ""                              # quien construye: el dueño de las provincias válidas
var validas: Array = []                     # las provincias del grupo que son de `pais` (solo en esas se construye)
var filtro_cat := ""                        # "" = todas las categorías
var ver_bloqueados := false                 # también lo que el país aún no conoce
var _lbl_dest: Label
var _lbl_info: Label
var _lbl_sin: Label
var _caja_cats: HFlowContainer
var _btns_cat := {}                         # código de categoría -> botón
var _chk: CheckBox
var _caja_obras: VBoxContainer
var _tit_obras: Label
var _lista: VBoxContainer
var _filas: Array = []                      # [{e, card, lbl_est, lbl_costo, btn}] (se arman una vez; luego solo se pone al día su texto)
var _acum := 0.0
var _firma_obras := 0
var filas_visibles := 0                     # (pruebas) cuántas filas de edificios se ven ahora
var obras_mostradas := 0                    # (pruebas) cuántas filas de «Obras en curso»


func construir(m: Node, f: Font, provincias: Array) -> void:
	main = m
	fuente = f
	process_mode = Node.PROCESS_MODE_ALWAYS
	vf = VentanaScript.new()
	add_child(vf)
	var vp := get_viewport().get_visible_rect().size
	var tam := Vector2(540.0, minf(640.0, vp.y - 90.0))
	vf.construir(main, fuente, "CONSTRUIR", tam, Vector2(maxf(vp.x - tam.x - 20.0, 10.0), 62.0), "i_prov", "construir")
	vf.cerrada.connect(func(): cerrada.emit())
	var c := vf.contenido
	_lbl_dest = vf.lbl_rol("", 15, "oro")
	_lbl_dest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if "fuente_ui_neg" in main:
		_lbl_dest.add_theme_font_override("font", main.fuente_ui_neg)
	c.add_child(_lbl_dest)
	_lbl_info = vf.lbl_rol("", 12, "tenue")
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_lbl_info)
	_lbl_sin = vf.lbl_rol("", 12, "naranja")
	_lbl_sin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_sin.visible = false
	c.add_child(_lbl_sin)
	# obras en curso
	_tit_obras = vf.lbl_rol("OBRAS EN CURSO", 11, "oro")
	c.add_child(_tit_obras)
	var sc_o := ScrollContainer.new()
	sc_o.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc_o.custom_minimum_size = Vector2(0.0, 0.0)
	sc_o.name = "ScrollObras"
	c.add_child(sc_o)
	_caja_obras = VBoxContainer.new()
	_caja_obras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caja_obras.add_theme_constant_override("separation", 3)
	sc_o.add_child(_caja_obras)
	# categorías
	_caja_cats = HFlowContainer.new()
	_caja_cats.add_theme_constant_override("h_separation", 4)
	_caja_cats.add_theme_constant_override("v_separation", 4)
	c.add_child(_caja_cats)
	_armar_categorias()
	_chk = CheckBox.new()
	_chk.text = "Mostrar también lo que aún no conoces"
	_chk.focus_mode = Control.FOCUS_NONE
	_chk.add_theme_font_size_override("font_size", 12)
	_chk.toggled.connect(func(v: bool):
		ver_bloqueados = v
		refrescar(true))
	c.add_child(_chk)
	# lista de edificios
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0.0, 160.0)
	c.add_child(sc)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 4)
	sc.add_child(_lista)
	_armar_filas()
	fijar_objetivo(provincias)


func _ed():
	return main.mundo.edificios


## Cambia las provincias que la ventana atiende (el jugador eligió otra cosa en el mapa).
func fijar_objetivo(provincias: Array) -> void:
	pis = provincias.duplicate()
	_resolver_actor()
	_firma_obras = -1
	refrescar(true)


## Quién construye: el dueño de la primera provincia; el resto del grupo solo cuenta si es del mismo país. Y solo se ordena sobre lo propio (o como observador).
func _resolver_actor() -> void:
	var m = main.mundo
	pais = ""
	validas = []
	if pis.is_empty():
		return
	pais = String(m.provincias[int(pis[0])].pais)
	for pi in pis:
		if String(m.provincias[int(pi)].pais) == pais:
			validas.append(int(pi))


## ¿Puede el jugador dar órdenes a este país? Observador (sin país) = todo permitido, como con las tropas en el modo libre.
func puede_ordenar() -> bool:
	return main.mundo.jugador == "" or main.mundo.jugador == pais


func _armar_categorias() -> void:
	var ed = _ed()
	_btns_cat.clear()
	_btns_cat[""] = _chip("Todos", "", "")
	for ct in ed.categorias:
		_btns_cat[String(ct["cod"])] = _chip(String(ct["nombre"]), String(ct["cod"]), String(ct["icono"]))
	_marcar_chips()


func _chip(texto: String, cod: String, icono: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if icono != "":
		b.icon = main.icono(icono)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 14)
	b.tooltip_text = "Mostrar solo: %s" % texto if cod != "" else "Mostrar todas las categorías"
	b.pressed.connect(func():
		filtro_cat = cod
		_marcar_chips()
		refrescar(true))
	_caja_cats.add_child(b)
	return b


func _marcar_chips() -> void:
	for k in _btns_cat:
		(_btns_cat[k] as Button).set_pressed_no_signal(k == filtro_cat)


func _armar_filas() -> void:
	var ed = _ed()
	for e in ed.n:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Tema.tarjeta(false, 6.0))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		card.add_child(hb)
		var ic := TextureRect.new()
		var cat_d: Dictionary = ed.categoria_de(e)
		ic.texture = main.icono("edificios/" + String(ed.slug[e]))                       # el suyo (0.1.8.41); si faltara, el de su categoría
		if ic.texture == null:
			ic.texture = main.icono(String(cat_d.get("icono", "i_prov")))
		ic.custom_minimum_size = Vector2(ICONO_FILA, ICONO_FILA)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		hb.add_child(col)
		var cab := HBoxContainer.new()
		cab.add_theme_constant_override("separation", 6)
		col.add_child(cab)
		var nom := vf.lbl_rol(String(ed.nombre[e]), 13, "texto")
		if "fuente_ui_neg" in main:
			nom.add_theme_font_override("font", main.fuente_ui_neg)
		nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cab.add_child(nom)
		cab.add_child(vf.lbl_rol("%s · %s" % [ed.nombre_clase(e), _anio_txt(int(ed.anio[e]))], 10, "tenue"))
		var d := vf.lbl_rol(String(ed.desc[e]), 11, "nota")
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(d)
		var lbl_costo := vf.lbl_rol("", 12, "texto")
		lbl_costo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(lbl_costo)
		var lbl_est := vf.lbl_rol("", 11, "tenue")
		lbl_est.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(lbl_est)
		var ee: int = e
		var btn := vf.boton("Construir", func(): _construir(ee))
		btn.custom_minimum_size = Vector2(96.0, 30.0)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(btn)
		_lista.add_child(card)
		_filas.append({"e": e, "card": card, "lbl_est": lbl_est, "lbl_costo": lbl_costo, "btn": btn, "nom": nom})


func _anio_txt(a: int) -> String:
	if a <= -10000:
		return "prehistoria"
	return ("%d a. C." % -a) if a < 0 else ("año %d" % a)


# ───────────── actualización ─────────────
func _process(delta: float) -> void:
	_acum += delta
	if _acum >= REFRESCO:
		_acum = 0.0
		refrescar()


func _sim() -> String:
	var dv = main.mundo.divisa_de(pais)
	return String(dv.simbolo) if dv != null else "US$"


func _dinero(v: float) -> String:
	return main.fmt_dinero(v, _sim())


## Pone al día cabecera, obras y filas. `forzar` también vuelve a decidir qué filas se ven (cambio de filtro o de objetivo).
func refrescar(forzar := false) -> void:
	if main == null or main.mundo == null or main.mundo.edificios == null or _lista == null:
		return
	var m = main.mundo
	var ed = _ed()
	var tes := 0.0
	var con_tes := false
	if m.paises.has(pais):
		con_tes = m.paises[pais].tiene_tesoreria()
		tes = m.paises[pais].tesoreria
	# cabecera
	if validas.is_empty():
		_lbl_dest.text = "Elige una provincia en el mapa"
		_lbl_info.text = "Después abre aquí lo que puedes construir. Con Ctrl+clic eliges varias a la vez."
	else:
		_lbl_dest.text = _texto_destino()
		_lbl_info.text = "Tesorería: %s · %s edificios construidos · %d obras en curso" % [
			_dinero(tes) if con_tes else "sin caja", main.hud.fmt_num(float(ed.total_en(validas))), ed.obras_en(validas)]
	var sin := validas.size() < pis.size()
	_lbl_sin.visible = sin or (not validas.is_empty() and not puede_ordenar())
	if not puede_ordenar() and not validas.is_empty():
		_lbl_sin.text = "Estas provincias no son de tu país: puedes verlas, pero no darles órdenes."
	elif sin:
		_lbl_sin.text = "%d de las %d provincias elegidas son de otros países: solo se construye en las de %s." % [pis.size() - validas.size(), pis.size(), main._nombre_vis(pais)]
	_obras_en_curso()
	# filas
	var visibles := 0
	var ordena := puede_ordenar() and not validas.is_empty()
	for fl in _filas:
		var e: int = fl["e"]
		var conoce: bool = not validas.is_empty() and ed.conoce(pais, e)
		var ver: bool = (filtro_cat == "" or String(ed.cat[e]) == filtro_cat) and (conoce or ver_bloqueados)
		(fl["card"] as Control).visible = ver
		if not ver:
			continue
		visibles += 1
		_poner_fila(fl, e, conoce, ordena, tes, con_tes)
	filas_visibles = visibles


func _texto_destino() -> String:
	var m = main.mundo
	if validas.size() == 1:
		var pr = m.provincias[int(validas[0])]
		return "%s · %s" % [pr.nombre, main._nombre_vis(pais)]
	return "%d provincias de %s" % [validas.size(), main._nombre_vis(pais)]


func _poner_fila(fl: Dictionary, e: int, conoce: bool, ordena: bool, tes: float, con_tes: bool) -> void:
	var ed = _ed()
	var lbl_costo: Label = fl["lbl_costo"]
	var lbl_est: Label = fl["lbl_est"]
	var btn: Button = fl["btn"]
	var n := validas.size()
	var construidos := 0
	var en_obra := 0
	var ok_n := 0
	var costo_ok := 0.0
	var primer_motivo := ""
	for pi in validas:
		construidos += ed.cantidad(int(pi), e)
		en_obra += ed.en_obra(int(pi), e)
		if conoce:
			var r: Dictionary = ed.puede(pais, int(pi), e)
			if bool(r["ok"]):
				ok_n += 1
				costo_ok += ed.costo_local(int(pi), e)
			elif primer_motivo == "":
				primer_motivo = String(r["motivo"])
	var dias: int = ed.dias_de(e)
	if not conoce:
		lbl_costo.text = "Requiere el descubrimiento «%s»" % (main.mundo.descubrimientos.nombre[ed.desc_idx[e]] if main.mundo.descubrimientos != null and ed.desc_idx[e] >= 0 else ed.nombre[e])
		Tema.rotular(lbl_costo, "naranja")
		lbl_est.text = ""
		btn.disabled = true
		btn.text = "Bloqueado"
		btn.tooltip_text = "Tu país todavía no conoce este descubrimiento."
		return
	var uno: float = ed.costo_local(int(validas[0]), e) if n >= 1 else 0.0
	if n == 1:
		lbl_costo.text = "Costo %s · %d días de obra" % [_dinero(uno), dias]
	else:
		lbl_costo.text = "Costo %s c/u (≈ %s en total) · %d días de obra" % [_dinero(uno), _dinero(uno * float(ok_n if ok_n > 0 else n)), dias]
	var sin_caja: bool = con_tes and ok_n > 0 and costo_ok > tes
	Tema.rotular(lbl_costo, "mal" if sin_caja or (ok_n == 0 and primer_motivo.find("tesorería") >= 0) else "texto")
	var partes := []
	if construidos > 0:
		partes.append("Construido: %d" % construidos + (" / %d" % ed.tope[e] if n == 1 else ""))
	if en_obra > 0:
		partes.append("en obra: %d" % en_obra)
	if n > 1:
		partes.append("se puede en %d de %d provincias" % [ok_n, n])
	elif ok_n == 0 and primer_motivo != "":
		partes.append(primer_motivo)
	lbl_est.text = " · ".join(PackedStringArray(partes)) if not partes.is_empty() else ("Máximo por provincia: %d" % ed.tope[e])
	Tema.rotular(lbl_est, "ok" if construidos > 0 and ok_n == 0 and primer_motivo.begins_with("Ya está") else "tenue")
	btn.text = "Construir" if n == 1 else "Construir ×%d" % ok_n
	btn.disabled = not ordena or ok_n == 0
	if not ordena:
		btn.tooltip_text = "No es tu país."
	elif ok_n == 0:
		btn.tooltip_text = primer_motivo if primer_motivo != "" else "No se puede construir ahora."
	elif n == 1:
		btn.tooltip_text = "Empezar la obra: %s y %d días.\nSe cobra de la tesorería ahora." % [_dinero(uno), dias]
	else:
		btn.tooltip_text = "Empezar la obra en %d provincias.\nCosto total ≈ %s, se cobra ahora.\nLas que no puedan (sin dinero, ya construido…) se saltan." % [ok_n, _dinero(costo_ok)]


## Obras en curso del grupo: una fila por obra con avance, días que faltan y botón de cancelar.
func _obras_en_curso() -> void:
	var ed = _ed()
	var firma: int = hash([ed.version, ed.dia_n, validas.hash(), pais])
	if firma == _firma_obras:
		return
	_firma_obras = firma
	for h in _caja_obras.get_children():
		_caja_obras.remove_child(h)
		h.queue_free()
	var filas := []
	for pi in validas:
		for o in ed.obras_de(int(pi)):
			filas.append([int(pi), o])
	var sc: ScrollContainer = _caja_obras.get_parent()
	obras_mostradas = mini(filas.size(), MAX_OBRAS_VISIBLES)
	_tit_obras.visible = not filas.is_empty()
	sc.visible = not filas.is_empty()
	if filas.is_empty():
		return
	_tit_obras.text = "OBRAS EN CURSO (%d)" % filas.size()
	sc.custom_minimum_size = Vector2(0.0, minf(float(mini(filas.size(), 4)) * 38.0, 150.0))
	filas.sort_custom(func(a, b): return int((a[1] as Dictionary)["falta"]) < int((b[1] as Dictionary)["falta"]))
	var m = main.mundo
	for k in obras_mostradas:
		var pi: int = filas[k][0]
		var o: Dictionary = filas[k][1]
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		var tex_ob: Texture2D = main.icono("edificios/" + String(ed.slug[int(o["e"])]))
		if tex_ob != null:
			var ic_ob := TextureRect.new()
			ic_ob.texture = tex_ob
			ic_ob.custom_minimum_size = Vector2(26.0, 26.0)
			ic_ob.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic_ob.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic_ob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ic_ob.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(ic_ob)
		var lbl := vf.lbl_rol("%s%s" % [ed.nombre[int(o["e"])], (" · " + String(m.provincias[pi].nombre)) if validas.size() > 1 else ""], 12, "texto")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		lbl.custom_minimum_size = Vector2(120.0, 0.0)
		hb.add_child(lbl)
		var fondo := ColorRect.new()
		fondo.color = Tema.BARRA_FONDO
		fondo.custom_minimum_size = Vector2(90.0, 12.0)
		fondo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var rel := ColorRect.new()
		rel.color = Tema.OK
		rel.size = Vector2(90.0 * float(o["pct"]) / 100.0, 12.0)
		fondo.add_child(rel)
		hb.add_child(fondo)
		hb.add_child(vf.lbl_rol("%d d" % int(o["falta"]), 11, "tenue"))
		var idx_obra := _indice_obra(pi, o)
		var bc := vf.boton("✕", func(): _cancelar(pi, idx_obra))
		bc.custom_minimum_size = Vector2(28.0, 24.0)
		bc.tooltip_text = "Cancelar la obra (devuelve la mitad de lo pagado)"
		bc.disabled = not puede_ordenar()
		hb.add_child(bc)
		_caja_obras.add_child(hb)
	if filas.size() > obras_mostradas:
		_caja_obras.add_child(vf.lbl_rol("… y %d más" % (filas.size() - obras_mostradas), 11, "tenue"))


## Posición de esa obra dentro de la lista de obras de la provincia (para cancelarla).
func _indice_obra(pi: int, o: Dictionary) -> int:
	var lista: Array = _ed().obras_de(pi)
	for i in lista.size():
		if int((lista[i] as Dictionary)["e"]) == int(o["e"]) and int((lista[i] as Dictionary)["ini"]) == int(o["ini"]):
			return i
	return -1


# ───────────── órdenes ─────────────
func _construir(e: int) -> void:
	var ed = _ed()
	if not puede_ordenar() or validas.is_empty():
		return
	if validas.size() == 1:
		var r: Dictionary = ed.construir(pais, int(validas[0]), e)
		if bool(r["ok"]):
			main.aviso("%s Costó %s." % [r["msg"], _dinero(float(r["costo"]))], "ok")
		else:
			main.aviso(String(r["msg"]), "mal")
	else:
		var r: Dictionary = ed.construir_varias(pais, validas, e)
		var hechas: int = int(r["hechas"])
		var fallos: Array = r["fallos"]
		if hechas > 0:
			main.aviso("%s: obra empezada en %d de %d provincias. Costó %s." % [ed.nombre[e], hechas, validas.size(), _dinero(float(r["costo"]))],
				"ok" if fallos.is_empty() else "aviso")
		else:
			main.aviso("No se pudo construir «%s» en ninguna: %s" % [ed.nombre[e], String((fallos[0] as Dictionary)["motivo"]) if not fallos.is_empty() else "—"], "mal")
	main.refrescar_todo(false)
	refrescar(true)


func _cancelar(pi: int, i: int) -> void:
	if not puede_ordenar():
		return
	var r: Dictionary = _ed().cancelar(pi, i)
	main.aviso("%s Se devolvió %s." % [r["msg"], _dinero(float(r["reembolso"]))] if bool(r["ok"]) else String(r["msg"]), "info" if bool(r["ok"]) else "mal")
	main.refrescar_todo(false)
	refrescar(true)


func aplicar_tema() -> void:
	if vf != null:
		vf.aplicar_tema()
		for fl in _filas:
			(fl["card"] as PanelContainer).add_theme_stylebox_override("panel", Tema.tarjeta(false, 6.0))
		_firma_obras = -1
		refrescar(true)
