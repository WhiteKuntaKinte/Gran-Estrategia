extends Node2D
## OBRAS Y DEFENSAS EN EL MAPA (0.1.8.51). Lo que se construye y lo que se tiene dentro de una provincia ahora SE VE sobre el mapa, no solo en la ventana Construir:
##   · OBRA EN MARCHA: una insignia con un anillo de progreso (dorado, en el sentido del reloj) y una grúa; si hay varias obras en la provincia sale su número y el anillo
##     es el de la que termina antes. Solo en las provincias que ves por dentro (las tuyas, las de tus aliados y vasallos; el observador, todas).
##   · FORTIFICACIÓN: una silueta según la defensa que dan los edificios de la provincia (`Edificios.efecto_abs(pi, EF_DEF)`): empalizada, muralla, castillo, fortaleza o plaza
##     fuerte, con puntitos que cuentan el nivel. Se ve en lo tuyo y también en las provincias que ves en tu campo de visión de guerra (reconocer antes de atacar).
## Todo tiene tamaño fijo en píxeles (como los cuadros de tropas) y NO se dibuja lejos (obras desde zoom 2,5; defensas desde 7, o desde 3 en la provincia elegida). Respeta la regla del zoom: nada se
## reconstruye por paso de la rueda; mientras gira la capa se desvanece y se rehace UNA vez cuando para (la ráfaga la detecta `capa_tropas`). La insignia se coloca arriba a
## la izquierda de la provincia (defensa) y arriba a la derecha (obra), por encima del cuadro de tropas, que va en una capa superior.

const RedScript := preload("res://scripts/red_provincias.gd")
const ANCHO := 2400.0
const ZOOM_OBRAS := 2.5                    # desde aquí se ven las obras en marcha (hay pocas: se leen enseguida)
const ZOOM_DEF := 7.0                      # y desde aquí las defensas de TODAS las provincias a la vista (con la modernidad casi todas tienen mucha: serían ruido lejos)
const ZOOM_DEF_ELEGIDA := 3.0              # la provincia que has elegido enseña su fortificación desde más lejos
const PERIODO_MIN_MS := 70                 # lo que pide el jugador (cámara, zoom, foco) redibuja con este tope
const MAX_MARCAS := 400                    # marcas por dibujo (hay que verlas todas a la vez para que merezca la pena)
const UMBRALES := [0.10, 0.35, 0.65, 0.95, 1.15]     # defensa (suma al poder del que defiende) desde la que se llega a cada nivel de fortificación
const NOMBRES_NIVEL := ["Sin defensas", "Empalizada", "Muralla", "Castillo", "Fortaleza", "Plaza fuerte"]
const COL_NIVEL := [Color(0.7, 0.7, 0.7), Color(0.78, 0.58, 0.36), Color(0.82, 0.83, 0.86), Color(0.96, 0.82, 0.38), Color(1.0, 0.72, 0.25), Color(1.0, 0.52, 0.28)]
const FONDO := Color(0.04, 0.06, 0.12, 0.90)
const ORO := Color(1.0, 0.84, 0.28)

var main
var fuente: Font
var n_dibujos := 0                         # cuántas veces se ha dibujado (para las pruebas y el banco de rendimiento)
var n_marcas := 0                          # marcas del último dibujo: [obras, defensas]
var n_obras := 0
var n_defensas := 0
var ms_dibujo := 0.0
var dibujadas: Array = []                  # [{pi, pos, nivel, obras, prog}] del último dibujo (pruebas)
var _sig: Array = []
var _sig_t: Array = []
var _t_ult := 0
var _centro := Vector2(-1.0e9, 0.0)
var _tam_vista := Vector2(1280.0, 720.0)


func iniciar(m: Node, f: Font) -> void:
	main = m
	fuente = f
	z_index = 13


## Nivel de fortificación (0 = ninguna, 1..5) que corresponde a una defensa `d`.
static func nivel_de(d: float) -> int:
	var n := 0
	for u in UMBRALES:
		if d >= float(u):
			n += 1
	return n


## Qué se ve de una provincia: lo que ocupa la capa (para pruebas y para la ficha de la provincia).
func marca_de(pi: int) -> Dictionary:
	var ed = main.mundo.edificios
	if ed == null or not ed.efectos_listos:
		return {"nivel": 0, "defensa": 0.0, "obras": 0, "prog": 0.0, "falta": 0}
	var df: float = ed.efecto_abs(pi, ed.EF_DEF)
	var ob: Array = ed.obras_de(pi)
	var prog := 0.0
	var falta := 1 << 30
	for o in ob:
		if int(o["falta"]) < falta:
			falta = int(o["falta"])
			prog = float(o["pct"]) / 100.0
	return {"nivel": nivel_de(df), "defensa": df, "obras": ob.size(), "prog": prog, "falta": falta if not ob.is_empty() else 0}


func _process(d: float) -> void:
	if main == null or main.mundo == null:
		return
	var ed = main.mundo.edificios
	var ej = main.mundo.ejercito
	if ed == null or ej == null or ej.red == null or main.en_menu or main.rend_ocultas.has("obras"):
		if visible:
			visible = false
		return
	visible = true
	var tr = main.capa_tropas
	var rafaga: bool = tr != null and tr.rafaga_zoom
	var obj := 0.0 if rafaga else 1.0
	if modulate.a != obj:                                        # desvanece mientras gira la rueda (como los cuadros de tropas) y vuelve al parar
		modulate.a = move_toward(modulate.a, obj, d * 9.0)
	if rafaga:
		return
	var zc: float = main.camara.zoom.x
	var vps := get_viewport().get_visible_rect().size
	_tam_vista = vps / zc
	var cam: Vector2 = main.camara.position
	var sp := [zc, main.pais_foco, main.mundo.jugador, vps, main.sel_tipo, int(main.sel_ref.get("pi", -1)), main.multi_sel.size()]     # lo elegido cuenta: la provincia elegida enseña su defensa desde más lejos
	var vel: int = clampi(main.reloj.velocidad if main.reloj != null else 0, 0, 6)
	var tope_sim := 70
	if tr != null:
		tope_sim = int(tr.PERIODO_PILAS_VEL[vel])
	var st := [ed.version, ed.dia_n, main.mundo.bd.version_propietario]
	var mv: Vector2 = (cam - _centro).abs()
	var mueve := mv.x > _tam_vista.x * 0.12 or mv.y > _tam_vista.y * 0.12
	var ahora := Time.get_ticks_msec()
	var dt := ahora - _t_ult
	if ((sp != _sig or mueve) and dt >= PERIODO_MIN_MS) or (st != _sig_t and dt >= tope_sim):
		_sig = sp
		_sig_t = st
		_t_ult = ahora
		queue_redraw()


func _rect_vista() -> Rect2:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var vr0: Rect2 = inv * get_viewport().get_visible_rect()
	return vr0.grow_individual(vr0.size.x * 0.2, vr0.size.y * 0.2, vr0.size.x * 0.2, vr0.size.y * 0.2)


func _vista_pt(c: Vector2, fs: float) -> Vector2:
	var fc: Vector2 = main.foco_centro
	var qx := fc.x + RedScript.dx_corto(fc.x, c.x)
	return fc + (Vector2(qx, c.y) - fc) * fs + Vector2(main.foco_dx, 0.0)


## Provincias que se anotan, con lo que se enseña de cada una: 1 = defensa, 2 = obras, 3 = las dos.
func _candidatas(vr: Rect2, fs: float, foco: String) -> Dictionary:
	var m = main.mundo
	var red = m.ejercito.red
	var r := {}
	if m.ve_todo():                                              # observador: todo lo que cae a la vista
		var anchas: bool = vr.size.x > ANCHO * 0.9
		for pi in red.centros.size():
			var c: Vector2 = red.centros[pi]
			if foco != "":
				c = _vista_pt(c, fs)
			if anchas or vr.has_point(c) or vr.has_point(c + Vector2(ANCHO, 0.0)) or vr.has_point(c - Vector2(ANCHO, 0.0)):
				r[pi] = 3
		return r
	for nombre in m.paises_visibles():
		for pi in m.paises[nombre].provincias:
			r[int(pi)] = 3
	var tr = main.capa_tropas
	if tr != null:
		for pi in tr._vision:                                    # lo que ves de los países en guerra contigo
			if not r.has(int(pi)):
				r[int(pi)] = 1
	return r


## Índices de las provincias elegidas (clic o Ctrl+clic).
func _provincias_elegidas() -> Dictionary:
	var r := {}
	if main.sel_tipo == "provincia" and main.sel_ref.has("pi"):
		r[int(main.sel_ref["pi"])] = true
	for u in main.multi_sel:
		if String(u.get("tipo", "")) == "provincia":
			r[int(u["pi"])] = true
	return r


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	n_dibujos += 1
	dibujadas = []
	n_obras = 0
	n_defensas = 0
	if main == null or main.mundo == null:
		return
	var ed = main.mundo.edificios
	var ej = main.mundo.ejercito
	if ed == null or ej == null or ej.red == null:
		return
	var zr: float = main._zoom_real()
	if zr < ZOOM_OBRAS:
		return
	var k := 1.0 / zr
	var vr := _rect_vista()
	_centro = main.camara.position
	var foco: String = main.pais_foco
	var fs: float = main._escala_pop() if foco != "" else 1.0
	var copias: Array = [-ANCHO, 0.0, ANCHO] if vr.size.x > ANCHO * 0.9 else [0.0]
	var cand := _candidatas(vr, fs, foco)
	var elegidas := _provincias_elegidas()
	for pi_e in elegidas:                                        # la elegida siempre cuenta, aunque no sea de las que ves por dentro
		if not cand.has(int(pi_e)):
			cand[int(pi_e)] = 1
	var red = ej.red
	var n := 0
	for pi in cand:
		var que: int = int(cand[pi])
		var c: Vector2 = red.centros[int(pi)]
		if foco != "":
			c = _vista_pt(c, fs)
		var info := marca_de(int(pi))
		var con_obra: bool = (que & 2) != 0 and int(info["obras"]) > 0
		var con_def: bool = (que & 1) != 0 and int(info["nivel"]) > 0 and (zr >= ZOOM_DEF or (zr >= ZOOM_DEF_ELEGIDA and elegidas.has(int(pi))))
		if not con_obra and not con_def:
			continue
		for dx in copias:
			var p := Vector2(c.x + float(dx), c.y)
			if not vr.has_point(p):
				continue
			n += 1
			if n > MAX_MARCAS:
				break
			draw_set_transform(p, 0.0, Vector2(k, k))
			if con_def:
				_dibujar_defensa(int(info["nivel"]))
				n_defensas += 1
			if con_obra:
				_dibujar_obra(int(info["obras"]), float(info["prog"]))
				n_obras += 1
			dibujadas.append({"pi": int(pi), "pos": p, "nivel": int(info["nivel"]) if con_def else 0, "obras": int(info["obras"]) if con_obra else 0, "prog": float(info["prog"])})
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	n_marcas = n
	ms_dibujo = float(Time.get_ticks_usec() - t0) / 1000.0


# ───────────── insignias (se dibujan en píxeles de pantalla, con el origen en el centro de la provincia) ─────────────
## Obra: disco oscuro, anillo de progreso y una grúa. Arriba a la derecha.
func _dibujar_obra(cuantas: int, prog: float) -> void:
	var c := Vector2(22.0, -30.0)
	draw_circle(c, 15.5, Color(0.0, 0.0, 0.0, 0.45))
	draw_circle(c, 14.0, FONDO)
	draw_arc(c, 11.5, 0.0, TAU, 40, Color(0.45, 0.33, 0.10, 0.9), 4.0, true)
	if prog > 0.004:
		draw_arc(c, 11.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(prog, 0.0, 1.0), maxi(int(40.0 * prog), 3), ORO, 4.2, true)
	# grúa: mástil, pluma, cable y gancho
	var col := Color(0.98, 0.95, 0.86)
	draw_line(c + Vector2(-3.0, 7.0), c + Vector2(-3.0, -7.0), col, 1.9)
	draw_line(c + Vector2(-7.5, -7.0), c + Vector2(7.0, -7.0), col, 1.9)
	draw_line(c + Vector2(4.6, -7.0), c + Vector2(4.6, -0.5), Color(col.r, col.g, col.b, 0.8), 1.2)
	draw_rect(Rect2(c + Vector2(3.0, -0.5), Vector2(3.3, 2.8)), ORO)
	draw_line(c + Vector2(-6.5, 7.0), c + Vector2(0.5, 7.0), col, 1.9)
	if cuantas > 1 and fuente != null:
		var b := c + Vector2(11.0, 11.0)
		draw_circle(b, 7.2, ORO)
		draw_string(fuente, b + Vector2(-7.0, 4.4), str(mini(cuantas, 9)), HORIZONTAL_ALIGNMENT_CENTER, 14.0, 12, Color(0.08, 0.06, 0.02))


## Fortificación: silueta según el nivel (1 empalizada · 2 muralla · 3 castillo · 4 fortaleza · 5 plaza fuerte), con tantos puntos como nivel. Arriba a la izquierda.
func _dibujar_defensa(nivel: int) -> void:
	var c := Vector2(-22.0, -30.0)
	var col: Color = COL_NIVEL[clampi(nivel, 0, 5)]
	draw_circle(c, 12.5, FONDO)
	draw_arc(c, 12.0, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.75), 1.6, true)
	match nivel:
		1:                                                       # empalizada: estacas
			for i in 5:
				var x := -7.0 + float(i) * 3.5
				draw_line(c + Vector2(x, 6.0), c + Vector2(x, -3.0), col, 2.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(x - 1.6, -3.0), c + Vector2(x + 1.6, -3.0), c + Vector2(x, -7.0)]), col)
		2:                                                       # muralla con almenas
			draw_rect(Rect2(c + Vector2(-8.0, -2.0), Vector2(16.0, 8.0)), col)
			for i in 3:
				draw_rect(Rect2(c + Vector2(-8.0 + float(i) * 6.2, -5.5), Vector2(3.6, 3.5)), col)
		3:                                                       # castillo: dos torres y un muro
			draw_rect(Rect2(c + Vector2(-8.0, -3.0), Vector2(16.0, 9.0)), col)
			draw_rect(Rect2(c + Vector2(-9.0, -7.0), Vector2(5.0, 6.0)), col)
			draw_rect(Rect2(c + Vector2(4.0, -7.0), Vector2(5.0, 6.0)), col)
			draw_rect(Rect2(c + Vector2(-2.0, 1.0), Vector2(4.0, 5.0)), FONDO)
		4:                                                       # fortaleza: tres torres y puerta
			draw_rect(Rect2(c + Vector2(-9.0, -1.0), Vector2(18.0, 7.0)), col)
			draw_rect(Rect2(c + Vector2(-10.0, -6.0), Vector2(5.0, 7.0)), col)
			draw_rect(Rect2(c + Vector2(5.0, -6.0), Vector2(5.0, 7.0)), col)
			draw_rect(Rect2(c + Vector2(-2.8, -8.0), Vector2(5.6, 9.0)), col)
			draw_rect(Rect2(c + Vector2(-1.6, 1.5), Vector2(3.2, 4.5)), FONDO)
		_:                                                       # plaza fuerte: estrella de bastiones
			var pts := PackedVector2Array()
			for i in 10:
				var ang := -PI * 0.5 + float(i) * TAU / 10.0
				var rr := 9.0 if i % 2 == 0 else 4.6
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
			draw_colored_polygon(pts, col)
			draw_circle(c, 2.2, FONDO)
	for i in nivel:                                              # puntos de nivel debajo de la silueta
		draw_circle(c + Vector2((float(i) - float(nivel - 1) * 0.5) * 3.6, 9.3), 1.15, col)
