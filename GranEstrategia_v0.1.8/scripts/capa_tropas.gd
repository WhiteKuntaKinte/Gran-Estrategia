extends Node2D
## Tropas dibujadas en el mapa (0.1.7.9.9E; regimientos en 0.1.7.9.9F-c).
##   · Regimiento quieto: un cuadro GRANDE con la bandera del país y el número COMPLETO de soldados (25000, no 25k), en el punto
##     interior de su provincia. Varios regimientos en la misma provincia se APILAN (no se funden: unirlos es una orden). Más de
##     cuatro se resumen con un cuadro «+N». Si la provincia muestra su nombre (país enfocado), el cuadro se coloca DEBAJO del
##     nombre para que no se pisen. Una batalla en curso pinta el cuadro con borde rojo y espadas cruzadas.
##   · Columna en marcha: cuadrito con una flecha que apunta hacia donde va; se mueve fluido entre un día y el siguiente.
##     Las columnas del jugador dejan dibujada la ruta que les falta (línea continua por tierra, rayada por mar).
##   · Modo destino: al elegir «Mover», la ruta hasta la provincia bajo el cursor se dibuja en dorado, con los días que tardaría.
## Los cuadritos tienen tamaño constante en pantalla (como los nombres de ciudad). Si dos se tapan, gana el más importante:
## pila elegida > tropas del jugador > las de sus vasallos y aliados, de más a menos soldados (las columnas en marcha siempre se ven).
## Se ven las tropas del jugador (y, cuando existan, sus vasallos y aliados) + (0.1.8.2) las de los países EN GUERRA con él, pero solo en su
## «campo de visión»: su propio territorio, las provincias donde tiene tropas y las vecinas, y las provincias a las que marchan sus columnas
## (más la provincia que está eligiendo como destino). Las columnas enemigas se ven mientras su ruta pasa por ese campo de visión.
## Las de países sin guerra con él, no; sin país elegido no se ve ninguna. Con un país «enfocado» (doble clic) sus tropas siguen el mismo salto que su silueta.
## Dos capas: las PILAS (se rehacen al mover la cámara, hacer zoom o cambiar las tropas) y las COLUMNAS + rutas (varias veces
## por día de juego, mientras avanzan). Así una columna en marcha no obliga a recolocar los cientos de cuadritos quietos.

const RelojScript := preload("res://scripts/reloj.gd")
const EjercitoScript := preload("res://scripts/ejercito.gd")
const RedScript := preload("res://scripts/red_provincias.gd")
const PerfilScript := preload("res://scripts/perfil.gd")

const ANCHO := 2400.0
const ALTO_M := 28.0                 # alto de cada cuadro (píxeles de pantalla)
const SEPARA := 3.0                  # hueco entre cuadros apilados
const MAX_APILADOS := 4              # regimientos que se dibujan en una provincia (el resto se resume en «+N»)
const FUENTE_PX := 15
const BANDERA_W := 30.0
const BANDERA_H := 20.0
const MAX_MARCAS := 300
const ORO := Color(1.0, 0.86, 0.3)
const FONDO := Color(0.04, 0.06, 0.12, 0.93)


## Segunda capa (columnas en marcha, rutas, vista previa): solo le pide a la principal que la pinte.
class CapaMarchas extends Node2D:
	var duena

	func _draw() -> void:
		if duena != null:
			duena._pintar_marchas(self)


## Tercera capa: flechas que se deslizan por la ruta dorada y el anillo que late en el destino. Se redibuja cada fotograma SOLO mientras hay una ruta dorada.
class CapaFlechas extends Node2D:
	var duena

	func _draw() -> void:
		if duena != null:
			duena._pintar_flechas(self)


## CAPAS DE CAJAS (0.1.8): los cuadros con la cantidad de tropas se dibujan en capas propias, por ENCIMA de todo lo demás del mapa
## (nombres de ciudades, rutas, flechas, resaltados). Nada puede quedar sobre un cuadro de tropas.
class CapaCajasPilas extends Node2D:
	var duena

	func _draw() -> void:
		if duena != null:
			duena._pintar_pilas(self)


class CapaCajasMarchas extends Node2D:
	var duena

	func _draw() -> void:
		if duena != null:
			duena._pintar_cajas_marchas(self)


const PERIODO_MARCHAS_MS := 40      # tope de redibujos de rutas/columnas por el paso del tiempo
const PERIODO_FLECHAS_MS := 33      # tope de redibujos de las flechas (30 por segundo)
## 0.1.8.32 · Tope de redibujos por lo que cambia la SIMULACIÓN (soldados, columnas, guerras), según la velocidad del reloj. A x4-x6 los números cambian
## más rápido de lo que se pueden leer y cada redibujo cuesta decenas de ms: se redibuja menos (lo que hace el jugador —cámara, zoom, selección— sigue al instante).
const PERIODO_PILAS_VEL := [70, 70, 70, 70, 160, 320, 500]       # pilas quietas, por velocidad 0..6
const PERIODO_MARCHAS_VEL := [40, 40, 40, 40, 90, 160, 260]      # columnas y rutas, por velocidad 0..6
const Z_CAJAS_PILAS := 200            # z_index (relativo a esta capa, que está en 14): por encima de ciudades (20), nombres (13), rutas y flechas
const Z_CAJAS_MARCHAS := 201          # las columnas en marcha van encima de las pilas quietas (también al hacer clic)

var main
var fuente: Font
var sel_regs: Array = []            # SELECCIÓN MÚLTIPLE (Ctrl+clic): IDs de todos los regimientos elegidos (vacío = solo vale `sel`)
var sel: Dictionary = {}            # {} | {"t":"reg","reg":ID de regimiento} | {"t":"marcha","id":ID de marcha}
var fantasma := {}                  # cuadrito que se está ARRASTRANDO con el ratón: {"pos": Vector2 (mapa), "txt": String, "pais": String}
var modo_destino := false
var dest_pi := -1                   # provincia bajo el cursor en modo destino
var origen_pi := -1                 # provincia de donde saldrían las tropas
var ruta_prev := PackedInt32Array()
var texto_prev := ""
var reg_prev := -1                  # regimiento que saldría (para avisar de la guerra al elegir destino)
var guerra_prev := false            # el destino es de otro país: entrar sería declarar la guerra
var dibujados: Array = []           # [Rect2 en «mundo × zoom real», datos]: lo que se vio en el último dibujo (para los clics y las pruebas)
var zr_dibujado := 1.0
var n_marcas := 0                   # cuadritos de pilas dibujados
var n_nombres := 0                  # nombres de provincia que se esquivaron en el último dibujo
var ms_dibujo := 0.0                # lo que tardó el último dibujo de pilas (ms), para medir rendimiento
var ms_marchas := 0.0               # ... y el de columnas y rutas
var ms_pilas := 0.0                 # ... y la última reconstrucción de la caché de pilas
var _nom_bandas := {}               # 0.1.8.32: nombres de provincia a esquivar, agrupados por franja horizontal de BANDA_NOMBRES píxeles (según su borde de arriba)
var _nom_alto_max := 0.0            # el nombre más alto: hasta dónde hay que mirar por encima de una pila
const BANDA_NOMBRES := 96.0
var prof := {}                      # 0.1.8.32: sección -> [µs totales, llamadas, µs de la más lenta] del dibujo de pilas (banco de rendimiento)

var red
var capa_marchas: CapaMarchas
var capa_flechas: CapaFlechas
var capa_cajas_pilas: CapaCajasPilas
var capa_cajas_marchas: CapaCajasMarchas
var _cajas_m: Array = []            # columnas del último cálculo: [centro, texto, país, ángulo, es_sel, ancho]
var _fantasma_dib: Array = []
var _m_listo := false
var _flechas_dibujadas := false
var _oro: Array = []                # rutas con flechas a la vista (0.1.8.2a: todas las del jugador, no solo la dorada): [{"pts", "cum", "fin", "col", "sel", "mid"}]
var _idx_col := {}                  # ID de marcha -> índice en la paleta (cada columna conserva su color mientras exista)
var _col_usado := {}                # índice de paleta -> ID de marcha que lo tiene
var _t_marchas := 0                 # última vez que se rehízo la capa de rutas (ms): limita los redibujos mientras el tiempo corre rápido
var _t_flechas := 0                 # ... y la de flechas
var n_carriles_max := 0             # carriles paralelos más anchos del último dibujo (para las pruebas)
var _dib_pilas: Array = []
var _dib_marchas: Array = []
var _frac := 0.0
var _sig_pilas: Array = []
var _sig_pilas_t: Array = []        # firma de lo que cambia la simulación (se redibuja con el tope de la velocidad)
var _sig_marchas_i: Array = []      # firma de lo que el jugador cambia (se redibuja al instante)
var _sig_marchas_u: Array = []      # firma del zoom y la vista (se redibuja con tope de 40 ms)
var _sig_marchas_t: Array = []      # firma de lo que cambia con el tiempo (se redibuja con el tope de la velocidad)
var _centro_pilas := Vector2(-1.0e9, 0.0)
var _centro_marchas := Vector2(-1.0e9, 0.0)
var _tam_vista := Vector2(1280.0, 720.0)
var _t_pilas := 0
var _banderas := {}
var _anchos := {}
var _nombre_pais := {}              # ID de país -> nombre (clave de Mundo.paises)
var _col_pais := {}                 # nombre de país -> color opaco
# caché de las pilas quietas (se rehace solo cuando cambia ejercito.version_pilas)
var _ver_pilas := -1
var _pilas: Array = []              # una PILA por (provincia, país): {"prov", "pais", "pi", "regs": [[ID regimiento, soldados, pelotones], ...] de mayor a menor, "total"}
var _rect_et := {}                  # índice de provincia -> {"r": Rect2 del nombre (unidades de mapa), "zin": zoom desde el que se lee}
var _rect_et_foco := "\u0001"
var _combate := {}                  # ID de provincia -> ID de batalla en curso (de los países visibles)
var _pos := PackedVector2Array()
var _pi := PackedInt32Array()
var _ancho_caja := PackedFloat32Array()
var _off := PackedFloat32Array()
var _de_pi := {}                    # índice de provincia -> índices de pilas que hay en ella
# campo de visión del jugador (0.1.8.2): se recalcula solo cuando cambian las tropas, las marchas, la propiedad o las guerras
const OBS_RUTAS_MAX := 160           # 0.1.8.3: el observador ve la ruta de cada columna si hay como mucho tantas en marcha (con más, solo las cajas moviéndose)
var _vision := {}                   # índice de provincia -> true (provincias donde se ven las tropas enemigas)
var _enemigos := {}                 # ID de país -> true (países en guerra con el jugador)
var _vision_clave: Array = []
var _hostiles: PackedInt32Array = PackedInt32Array()   # pilas enemigas dentro del campo de visión, de más a menos soldados
var n_hostiles := 0                 # cuadros de tropas enemigas dibujados en el último dibujo (para las pruebas)
var _de_pais := {}                  # ID de país -> índices (en el mismo orden)


func iniciar(m: Node, f: Font) -> void:
	main = m
	fuente = f
	z_index = 14
	for nombre in main.mundo.paises:
		_nombre_pais[int(main.mundo.paises[nombre].tid)] = String(nombre)
	capa_marchas = CapaMarchas.new()
	capa_marchas.duena = self
	capa_marchas.z_index = 1
	add_child(capa_marchas)
	capa_flechas = CapaFlechas.new()
	capa_flechas.duena = self
	capa_flechas.z_index = 2
	add_child(capa_flechas)
	capa_cajas_pilas = CapaCajasPilas.new()
	capa_cajas_pilas.duena = self
	capa_cajas_pilas.z_index = Z_CAJAS_PILAS
	add_child(capa_cajas_pilas)
	capa_cajas_marchas = CapaCajasMarchas.new()
	capa_cajas_marchas.duena = self
	capa_cajas_marchas.z_index = Z_CAJAS_MARCHAS
	add_child(capa_cajas_marchas)


# ─────────────────────────────────────────────────────────────
# Actualización
# ─────────────────────────────────────────────────────────────
func refrescar() -> void:
	_sig_pilas = []
	_sig_pilas_t = []
	_sig_marchas_i = []
	_sig_marchas_u = []
	_sig_marchas_t = []
	_centro_pilas = Vector2(-1.0e9, 0.0)
	_centro_marchas = Vector2(-1.0e9, 0.0)
	_t_pilas = 0


func _frac_dia() -> float:
	var r = main.reloj
	if r != null and r.velocidad > 0:
		_frac = clampf(r.acum / float(RelojScript.SEG_POR_DIA[r.velocidad]), 0.0, 1.0)
	return _frac


func _process(_d: float) -> void:
	if main == null or main.mundo == null:
		return
	var ej = main.mundo.ejercito
	if ej == null or ej.red == null or main.en_menu or main.rend_ocultas.has("tropas"):     # (Debug > Rendimiento puede apagar la capa)
		if visible:
			visible = false
		return
	visible = true
	var f := _frac_dia()
	var foco: String = main.pais_foco
	var esc: float = main._escala_pop() if foco != "" else 1.0
	var fc: Vector2 = main.foco_centro if foco != "" else Vector2.ZERO
	var zc: float = main.camara.zoom.x
	var vps := get_viewport().get_visible_rect().size
	_tam_vista = vps / zc
	var cam: Vector2 = main.camara.position
	var ahora := Time.get_ticks_msec()
	# pilas: lo que hace el jugador (zoom, selección, foco, cámara) redibuja ya (tope 70 ms); lo que cambia la simulación, con el tope de la velocidad
	var gv: int = main.mundo.guerra.version if main.mundo.guerra != null else 0
	var vel: int = clampi(main.reloj.velocidad if main.reloj != null else 0, 0, RelojScript.VEL_MAX)
	var sp := [zc, sel, sel_regs, foco, esc, fc, main.mundo.jugador, vps, modo_destino, dest_pi]
	var sp_t := [ej.version_pilas, gv, ej.version_marchas]
	var mv: Vector2 = (cam - _centro_pilas).abs()
	var mueve := mv.x > _tam_vista.x * 0.12 or mv.y > _tam_vista.y * 0.12
	var dt_p := ahora - _t_pilas
	if ((sp != _sig_pilas or mueve) and dt_p >= 70) or (sp_t != _sig_pilas_t and dt_p >= int(PERIODO_PILAS_VEL[vel])):
		_sig_pilas = sp
		_sig_pilas_t = sp_t
		_t_pilas = ahora
		capa_cajas_pilas.queue_redraw()
	# columnas
	var hay: bool = not ej.marchas.is_empty() or modo_destino
	# Lo que cambia por una acción del jugador se redibuja al instante; lo que cambia por el paso del tiempo (avance de las columnas, zoom corriendo)
	# no más de ~25 veces por segundo: a velocidades altas el reloj cambia en cada fotograma y rehacer todas las rutas cada vez hundía los FPS.
	var si := [sel, sel_regs, modo_destino, dest_pi, foco, main.mundo.jugador, fantasma]
	var st_u := [zc, esc, fc, vps]                                          # zoom y tamaño de la vista: los pide el jugador (tope 40 ms)
	var st := [ej.version_marchas, int(f * 16.0) if hay else 0, hay, ej.version_pilas, gv]    # el paso del tiempo: con el tope de la velocidad
	var mv2: Vector2 = (cam - _centro_marchas).abs()
	var mueve2 := mv2.x > _tam_vista.x * 0.12 or mv2.y > _tam_vista.y * 0.12
	var cambio_i: bool = si != _sig_marchas_i
	var dt_m := ahora - _t_marchas
	if cambio_i or ((st_u != _sig_marchas_u or (mueve2 and hay)) and dt_m >= PERIODO_MARCHAS_MS) or (st != _sig_marchas_t and dt_m >= int(PERIODO_MARCHAS_VEL[vel])):
		_sig_marchas_i = si
		_sig_marchas_u = st_u
		_sig_marchas_t = st
		_t_marchas = ahora
		_m_listo = false
		capa_marchas.queue_redraw()
		capa_cajas_marchas.queue_redraw()
	if not _oro.is_empty():
		if ahora - _t_flechas >= PERIODO_FLECHAS_MS:
			_t_flechas = ahora
			capa_flechas.queue_redraw()              # las flechas se mueven: un redibujo cada ~33 ms (30 por segundo), solo con rutas a la vista
	elif _flechas_dibujadas:
		_flechas_dibujadas = false
		capa_flechas.queue_redraw()                  # una última vez para borrar lo que quedó dibujado


# ─────────────────────────────────────────────────────────────
# Datos de las pilas (caché)
# ─────────────────────────────────────────────────────────────
func _color_de(pais: String) -> Color:
	if not _col_pais.has(pais):
		var c: Color = main._color_ejercito(pais)
		c.a = 1.0
		_col_pais[pais] = c
	return _col_pais[pais]


## IDs de los países cuyas tropas se ven: el del jugador y sus vasallos/aliados (ver Mundo.paises_visibles). Sin jugador (observador): todos.
func _tids_visibles() -> PackedInt32Array:
	var r := PackedInt32Array()
	if main.mundo.ve_todo():                                        # 0.1.8.3: el observador ve las tropas de todos los países
		for tv in _de_pais:
			r.append(int(tv))
		return r
	for nombre in main.mundo.paises_visibles():
		r.append(int(main.mundo.paises[nombre].tid))
	return r


func _tid_jugador() -> int:
	var j: String = main.mundo.jugador
	if j != "" and main.mundo.paises.has(j):
		return int(main.mundo.paises[j].tid)
	return -1


## Campo de visión del jugador y países en guerra con él. Se guarda hasta que cambia algo que lo afecta.
func _actualizar_vision(ej) -> void:
	var g = main.mundo.guerra
	var tj := _tid_jugador()
	var clave := [ej.version_pilas, ej.version_marchas, main.mundo.bd.version_propietario, (g.version if g != null else 0), tj]
	if clave == _vision_clave:
		return
	_vision_clave = clave
	_vision = {}
	_enemigos = {}
	_hostiles = PackedInt32Array()
	if tj < 0 or g == null:
		return
	for r in g.rivales_de(tj):
		_enemigos[int(r)] = true
	if _enemigos.is_empty():
		return                                                  # sin guerras no hay nada que ver (y no se calcula nada)
	var jug: String = main.mundo.jugador
	for pi in main.mundo.paises[jug].provincias:                # 1) su propio territorio
		_vision[int(pi)] = true
	for i in _de_pais.get(tj, []):                              # 2) donde tiene tropas, y sus vecinas
		_ver_alrededor(int(_pi[i]))
	for mid in ej.marchas:                                      # 3) a donde marchan sus columnas (destino y vecinas) y por donde van
		var m: Dictionary = ej.marchas[mid]
		if int(m["pais"]) != tj:
			continue
		var ruta: PackedInt32Array = m["ruta"]
		_ver_alrededor(int(ruta[ruta.size() - 1]))
		var k: int = mini(int(m["k"]), ruta.size() - 1)
		_vision[int(ruta[k])] = true
		if k + 1 < ruta.size():
			_vision[int(ruta[k + 1])] = true
	var lista := []
	for pi in _vision:                                          # pilas enemigas que caen dentro
		for i in _de_pi.get(int(pi), []):
			if _enemigos.has(int(_pilas[i]["pais"])):
				lista.append(int(i))
	lista.sort_custom(func(a, b): return _pilas[a]["total"] > _pilas[b]["total"])
	_hostiles = PackedInt32Array(lista)


func _ver_alrededor(pi: int) -> void:
	_vision[pi] = true
	if red != null:
		for v in red.vecinos(pi):
			_vision[int(v)] = true


## ¿Esta columna ENEMIGA se ve? Sí, si su país está en guerra con el jugador y algún tramo de lo que le falta de ruta pasa por su campo de visión.
func _columna_hostil_visible(m: Dictionary) -> bool:
	if not _enemigos.has(int(m["pais"])):
		return false
	var ruta: PackedInt32Array = m["ruta"]
	for q in range(mini(int(m["k"]), ruta.size() - 1), ruta.size()):
		if _vision.has(int(ruta[q])):
			return true
	return false


func _ancho_de_caja(txt: String, marcha := false) -> float:
	return 5.0 + (13.0 if marcha else 0.0) + BANDERA_W + 6.0 + _ancho_txt(txt) + 6.0


## Ordena los regimientos de una pila (de más a menos soldados; a igual cantidad, el de menor ID primero) por inserción: son 1-10 elementos y
## una función de comparación llamada desde el motor cuesta más que todo el orden.
func _ordenar_regs(regs: Array) -> void:
	for i in range(1, regs.size()):
		var x: Array = regs[i]
		var j := i - 1
		while j >= 0 and (int(regs[j][1]) < int(x[1]) or (int(regs[j][1]) == int(x[1]) and int(regs[j][0]) > int(x[0]))):
			regs[j + 1] = regs[j]
			j -= 1
		regs[j + 1] = x


func _preparar_pilas(ej) -> void:
	if _ver_pilas == ej.version_pilas:
		return
	var t0 := Time.get_ticks_usec()
	_ver_pilas = ej.version_pilas
	var t_q := Time.get_ticks_usec()
	var regs: Array = ej.regimientos_quietos()           # [ID regimiento, ID provincia, ID país, soldados, pelotones]
	PerfilScript.anotar(prof, "1a regimientos_quietos", t_q)
	t_q = Time.get_ticks_usec()
	_pilas = []
	var por_clave := {}
	for r in regs:
		var clave: int = int(r[1]) * 100003 + int(r[2])
		var i: int
		if por_clave.has(clave):
			i = int(por_clave[clave])
		else:
			var pr = ej.provincia_por_tid(int(r[1]))
			i = _pilas.size()
			por_clave[clave] = i
			_pilas.append({"prov": int(r[1]), "pais": int(r[2]), "pi": (pr.idx if pr != null else 0), "regs": [], "total": 0})
		_pilas[i]["regs"].append([int(r[0]), int(r[3]), int(r[4])])
		_pilas[i]["total"] = int(_pilas[i]["total"]) + int(r[3])
	PerfilScript.anotar(prof, "1b agrupar", t_q)
	t_q = Time.get_ticks_usec()
	var n := _pilas.size()
	_pos.resize(n)
	_pi.resize(n)
	_ancho_caja.resize(n)
	_off.resize(n)
	_de_pais.clear()
	var por_prov := {}
	for i in n:
		var p: Dictionary = _pilas[i]
		_ordenar_regs(p["regs"])
		var pi: int = p["pi"]
		_pi[i] = pi
		_pos[i] = red.centros[pi]
		var w := 0.0
		var visibles: int = mini((p["regs"] as Array).size(), MAX_APILADOS)
		for j in visibles:
			w = maxf(w, _ancho_de_caja(str(int(p["regs"][j][1]))))
		_ancho_caja[i] = maxf(w, _ancho_de_caja("+99"))
		if not por_prov.has(pi):
			por_prov[pi] = []
		por_prov[pi].append(i)
	PerfilScript.anotar(prof, "1c ordenar regs y anchos", t_q)
	t_q = Time.get_ticks_usec()
	for pi in por_prov:                                  # pilas de países distintos en una provincia: una al lado de la otra
		var l: Array = por_prov[pi]
		var xs := 0.0
		for j in l.size():
			xs += _ancho_caja[l[j]] + 8.0
		var x := -xs * 0.5
		for j in l.size():
			_off[l[j]] = x + _ancho_caja[l[j]] * 0.5 if l.size() > 1 else 0.0
			x += _ancho_caja[l[j]] + 8.0
	var claves: Array = []                               # una clave entera por pila: soldados (alto) e índice (bajo); la ordenación nativa evita 1.500 llamadas a una función de comparación
	claves.resize(n)
	for i in n:
		claves[i] = (int(_pilas[i]["total"]) << 20) | (0xFFFFF - i)
	claves.sort()
	for k in range(n - 1, -1, -1):                       # de más a menos soldados (a igual cantidad, la de menor índice primero)
		var i3: int = 0xFFFFF - (int(claves[k]) & 0xFFFFF)
		var pa := int(_pilas[i3]["pais"])
		if not _de_pais.has(pa):
			_de_pais[pa] = []
		_de_pais[pa].append(i3)
	_de_pi = por_prov
	PerfilScript.anotar(prof, "1d ordenar pilas", t_q)
	_vision_clave = []                                       # las pilas cambiaron: hay que recalcular el campo de visión
	ms_pilas = float(Time.get_ticks_usec() - t0) / 1000.0


## Rectángulos de los NOMBRES de provincia del país enfocado (unidades de mapa, sin el «salto» del foco), para que los cuadros de tropas no los pisen.
func _preparar_rect_et(foco: String) -> void:
	if _rect_et_foco == foco and not (foco != "" and _rect_et.is_empty() and not main.et_prov.is_empty()):
		return
	_rect_et_foco = foco
	_rect_et.clear()
	if foco == "" or main.et_prov.is_empty():
		return
	var origenes := [foco]
	for o in main.mundo.origenes_ajenos(foco):
		origenes.append(o)
	for o2 in origenes:
		for lab in main.et_prov.get(o2, []):
			if not lab.has("pi"):
				continue
			var pi: int = int(lab["pi"])
			if main.mundo.provincias[pi].pais != foco:
				continue
			var flat: Array = lab["p"]
			if flat.size() < 4:
				continue
			var P := PackedVector2Array()
			for i in range(0, flat.size(), 2):
				P.append(Vector2(flat[i], flat[i + 1]))
			var e: float = float(lab["e"])
			var cum := PackedFloat32Array([0.0])
			for i in range(1, P.size()):
				cum.append(cum[i - 1] + P[i].distance_to(P[i - 1]))
			var largo: float = cum[cum.size() - 1]
			if largo <= 0.0:
				continue
			var tr: Array = main.etiqueta_tramo(lab, largo)          # dónde empieza y cuánto mide el texto sobre la línea
			var d0: float = float(tr[0])
			var lt: float = float(tr[1])
			var alto_letra: float = float(tr[2])
			var bb := Rect2(_punto_en(P, cum, d0), Vector2.ZERO)
			bb = bb.expand(_punto_en(P, cum, d0 + lt))
			for i in P.size():
				if cum[i] > d0 and cum[i] < d0 + lt:
					bb = bb.expand(P[i])
			bb = bb.grow(alto_letra * 0.6)
			# rectángulos pequeños a lo largo del texto (el texto inclinado ocupa mucho menos que su caja envolvente)
			var rs: Array = []
			var paso: float = maxf(alto_letra * 0.8, lt / 40.0)
			var dd: float = d0
			while dd <= d0 + lt + paso * 0.5:
				var pt := _punto_en(P, cum, minf(dd, d0 + lt))
				rs.append(Rect2(pt, Vector2.ZERO).grow(alto_letra * 0.55))
				dd += paso
			e = maxf(e, 0.0001)
			_rect_et[pi] = {"r": bb, "rs": rs, "zin": main.PX_LEGIBLE / e}


## Desplazamiento (px, Vector2 x/y) que deja el rectángulo `r` sin pisar ningún nombre de provincia (ni otro cuadro).
## Primero prueba mover solo en vertical (0 y «justo encima / justo debajo» de cada nombre cercano), luego solo en horizontal y al final
## combinaciones de ambos. Devuelve [desplazamiento, ¿sin pisar ningún nombre?]; si no hay hueco totalmente libre, el de menor solape.
const MAX_COMBOS := 10                # combinaciones horizontal × vertical que se prueban además de los desplazamientos en un solo eje

func _hueco_sin_nombres(r: Rect2, shift_x: float, grid: Dictionary, alcance := 150.0) -> Array:
	var cerca: Array = []
	var zona := r.grow(alcance)
	var sh := Vector2(shift_x, 0.0)
	var ban0 := int(floorf((zona.position.y - _nom_alto_max) / BANDA_NOMBRES))
	var ban1 := int(floorf(zona.end.y / BANDA_NOMBRES))
	for bn in range(ban0, ban1 + 1):                          # solo las franjas que tocan la zona: antes se recorrían todos los nombres (~250) por cada pila
		var en_banda = _nom_bandas.get(bn)
		if en_banda == null:
			continue
		for er0 in (en_banda as Array):
			var er2 := Rect2((er0 as Rect2).position + sh, (er0 as Rect2).size)
			if zona.intersects(er2):
				cerca.append(er2)
	if cerca.is_empty():
		return [Vector2.ZERO, true]
	var vy := PackedFloat64Array()
	var vx := PackedFloat64Array()
	for er3 in cerca:
		var e3: Rect2 = er3
		var a1: float = e3.end.y + 2.0 - r.position.y
		var a2: float = e3.position.y - 2.0 - r.end.y
		var b1: float = e3.end.x + 2.0 - r.position.x
		var b2: float = e3.position.x - 2.0 - r.end.x
		if absf(a1) <= alcance:
			vy.append(a1)
		if absf(a2) <= alcance:
			vy.append(a2)
		if absf(b1) <= alcance:
			vx.append(b1)
		if absf(b2) <= alcance:
			vx.append(b2)
	var cy_ := _mas_cortos(vy)
	var cx_ := _mas_cortos(vx)
	var pruebas: Array = []
	for v2 in cy_:
		pruebas.append(Vector2(0.0, v2))
	for h2 in cx_:
		if h2 != 0.0:
			pruebas.append(Vector2(h2, 0.0))
	for h3 in cx_.slice(1, 1 + MAX_COMBOS):
		for v3 in cy_.slice(1, 1 + MAX_COMBOS):
			pruebas.append(Vector2(h3, v3))
	var mejor := Vector2.ZERO
	var peor_solape := INF
	for mv in pruebas:
		var rr := Rect2(r.position + (mv as Vector2), r.size)
		var solape := 0.0
		for er4 in cerca:
			if rr.intersects(er4):
				solape += rr.intersection(er4).get_area()
				if solape >= peor_solape:
					break
		if solape > 0.0 and solape >= peor_solape:
			continue
		if solape <= 0.0 and _libre(rr, grid):
			return [mv, true]                             # hueco totalmente libre
		if solape < peor_solape:
			peor_solape = solape
			mejor = mv
	return [mejor, peor_solape <= 0.0]                    # sin hueco: el de menor solape (true solo si no pisa ningún nombre)


## Los valores de `v` sin repetir, precedidos de 0.0 y ordenados por valor absoluto (a igual valor absoluto, primero el positivo).
## Orden con dos ordenaciones nativas (positivos y negativos) y una mezcla, sin funciones de comparación en GDScript.
func _mas_cortos(v: PackedFloat64Array) -> Array:
	var pos := PackedFloat64Array()
	var neg := PackedFloat64Array()
	for x in v:
		if x > 0.0:
			pos.append(x)
		elif x < 0.0:
			neg.append(-x)
	pos.sort()
	neg.sort()
	var r: Array = [0.0]
	var i := 0
	var j := 0
	var ult_p := -1.0
	var ult_n := -1.0
	while i < pos.size() or j < neg.size():
		var tp: float = pos[i] if i < pos.size() else INF
		var tn: float = neg[j] if j < neg.size() else INF
		if tp <= tn:
			if tp != ult_p:
				r.append(tp)
				ult_p = tp
			i += 1
		else:
			if tn != ult_n:
				r.append(-tn)
				ult_n = tn
			j += 1
	return r


func _punto_en(P: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Vector2:
	for i in range(1, P.size()):
		if cum[i] >= d:
			var t := (d - cum[i - 1]) / maxf(cum[i] - cum[i - 1], 0.0000001)
			return P[i - 1].lerp(P[i], clampf(t, 0.0, 1.0))
	return P[P.size() - 1]


# ─────────────────────────────────────────────────────────────
# Posiciones (con el «salto» del país enfocado)
# ─────────────────────────────────────────────────────────────
func _vista(pi: int, foco: String, fs: float) -> Vector2:
	var c: Vector2 = red.centros[pi]
	if foco != "" and main.mundo.provincias[pi].pais == foco:
		var fc: Vector2 = main.foco_centro
		var qx := fc.x + RedScript.dx_corto(fc.x, c.x)
		c = fc + (Vector2(qx, c.y) - fc) * fs + Vector2(main.foco_dx, 0.0)
	return c


## Posición y rumbo de una columna: [Vector2, ángulo].
func _pos_marcha(m: Dictionary, frac: float, foco: String, fs: float) -> Array:
	var ruta: PackedInt32Array = m["ruta"]
	var k: int = mini(int(m["k"]), ruta.size() - 2)
	var a := _vista(ruta[k], foco, fs)
	var b0 := _vista(ruta[k + 1], foco, fs)
	var b := Vector2(a.x + RedScript.dx_corto(a.x, b0.x), b0.y)
	var total: float = red.coste_tramo(ruta[k], ruta[k + 1])
	var t := clampf((float(m["km"]) + frac * EjercitoScript.VEL_MARCHA_KM_DIA) / maxf(total, 1.0), 0.0, 1.0)
	return [a.lerp(b, t), (b - a).angle()]


func _bandera(pais: String) -> Texture2D:
	if not _banderas.has(pais):
		_banderas[pais] = main.bandera_tex(main._bandera_pais(pais))
	return _banderas[pais]


static func compacto(n: int) -> String:
	if n >= 1000000:
		return ("%.1fM" % (float(n) / 1.0e6)).replace(".", ",")
	if n >= 10000:
		return "%dk" % int(round(float(n) / 1000.0))
	if n >= 1000:
		return ("%.1fk" % (float(n) / 1000.0)).replace(".", ",")
	return str(n)


func _ancho_txt(t: String) -> float:
	if not _anchos.has(t):
		_anchos[t] = fuente.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FUENTE_PX).x
	return float(_anchos[t])


# ─────────────────────────────────────────────────────────────
# Colisiones entre cuadritos (rejilla)
# ─────────────────────────────────────────────────────────────
func _libre(r: Rect2, grid: Dictionary) -> bool:
	var gx1 := int(floor(r.end.x / 64.0))
	var gy1 := int(floor(r.end.y / 28.0))
	for gx in range(int(floor(r.position.x / 64.0)), gx1 + 1):
		for gy in range(int(floor(r.position.y / 28.0)), gy1 + 1):
			var l = grid.get(gx * 100003 + gy)
			if l != null:
				for o in l:
					if r.intersects(o):
						return false
	return true


func _ocupar(r: Rect2, grid: Dictionary) -> void:
	var gx1 := int(floor(r.end.x / 64.0))
	var gy1 := int(floor(r.end.y / 28.0))
	for gx in range(int(floor(r.position.x / 64.0)), gx1 + 1):
		for gy in range(int(floor(r.position.y / 28.0)), gy1 + 1):
			var key := gx * 100003 + gy
			if not grid.has(key):
				grid[key] = []
			grid[key].append(r)


## Rectángulo de la vista (con 30 % de margen para poder mover la cámara sin redibujar).
func _rect_vista() -> Rect2:
	var inv := get_viewport().get_canvas_transform().affine_inverse()
	var vr0: Rect2 = inv * get_viewport().get_visible_rect()
	return vr0.grow_individual(vr0.size.x * 0.3, vr0.size.y * 0.3, vr0.size.x * 0.3, vr0.size.y * 0.3)


# ─────────────────────────────────────────────────────────────
# Pilas quietas
# ─────────────────────────────────────────────────────────────
## Posición de un punto del mapa con el «salto» del país enfocado (igual que `_vista` pero para un punto cualquiera).
func _vista_pt(c: Vector2, fs: float) -> Vector2:
	var fc: Vector2 = main.foco_centro
	var qx := fc.x + RedScript.dx_corto(fc.x, c.x)
	return fc + (Vector2(qx, c.y) - fc) * fs + Vector2(main.foco_dx, 0.0)


func _pintar_pilas(ci: CanvasItem) -> void:
	var t0 := Time.get_ticks_usec()
	_dib_pilas = []
	n_marcas = 0
	if main == null or main.mundo == null:
		return
	var ej = main.mundo.ejercito
	if ej == null or ej.red == null:
		return
	red = ej.red
	var t_p := Time.get_ticks_usec()
	_preparar_pilas(ej)
	PerfilScript.anotar(prof, "1 preparar", t_p)
	t_p = Time.get_ticks_usec()
	var zr: float = main._zoom_real()
	zr_dibujado = zr
	var k := 1.0 / zr
	var vr := _rect_vista()
	_centro_pilas = main.camara.position
	var foco: String = main.pais_foco
	var fs: float = main._escala_pop() if foco != "" else 1.0
	_preparar_rect_et(foco)
	var vis := _tids_visibles()
	_actualizar_vision(ej)
	_combate = main.mundo.guerra.provincias_en_combate(Array(vis)) if main.mundo.guerra != null else {}
	PerfilScript.anotar(prof, "2 vision y combate", t_p)
	t_p = Time.get_ticks_usec()
	var n := _pilas.size()
	var cx_vista := vr.position.x + vr.size.x * 0.5
	var ancho_vista := vr.size.x
	var ancha := ancho_vista > ANCHO * 0.9           # ventana más ancha que el mapa: se ven varias copias
	var copias: Array = [-ANCHO, 0.0, ANCHO] if ancha else [0.0]
	# índice de la pila que contiene el regimiento elegido (se muestra siempre)
	var i_sel := -1
	var reg_sel := -1
	if sel.get("t", "") == "reg":
		reg_sel = int(sel["reg"])
		for i in n:
			if vis.has(int(_pilas[i]["pais"])) or _enemigos.has(int(_pilas[i]["pais"])):
				for rr in _pilas[i]["regs"]:
					if int(rr[0]) == reg_sel:
						i_sel = i
						break
			if i_sel >= 0:
				break
	# Nombres de provincia que se leen ahora (rectángulos en píxeles «mundo × zoom real»): los cuadros se apartan de TODOS, no solo del suyo.
	var nombres_vis: Array = []
	if foco != "":
		for pi_e in _rect_et:
			var et_d: Dictionary = _rect_et[pi_e]
			if zr >= float(et_d["zin"]) * 0.78:
				for er in (et_d["rs"] as Array):
					var a0: Vector2 = _vista_pt((er as Rect2).position, fs)
					var a1: Vector2 = _vista_pt((er as Rect2).end, fs)
					nombres_vis.append(Rect2(Vector2(minf(a0.x, a1.x), minf(a0.y, a1.y)) * zr, (a1 - a0).abs() * zr))
	n_nombres = nombres_vis.size()
	_nom_bandas.clear()
	_nom_alto_max = 0.0
	for er_n in nombres_vis:
		var rn: Rect2 = er_n
		var bn := int(floorf(rn.position.y / BANDA_NOMBRES))
		if not _nom_bandas.has(bn):
			_nom_bandas[bn] = []
		(_nom_bandas[bn] as Array).append(rn)
		_nom_alto_max = maxf(_nom_alto_max, rn.size.y)
	PerfilScript.anotar(prof, "3 seleccion y nombres", t_p)
	t_p = Time.get_ticks_usec()
	var grid := {}
	var acept_i := PackedInt32Array()
	var acept_c := PackedVector2Array()
	var acept_dy := PackedFloat32Array()
	var acept_dx := PackedFloat32Array()
	# SOLO se dibujan las tropas de los países que el jugador controla (y, en el futuro, sus vasallos y aliados).
	# Orden de prioridad: la pila elegida, las del país del jugador, las de sus relacionados.
	var fuentes: Array = []
	if i_sel >= 0:
		fuentes.append([PackedInt32Array([i_sel]), true])
	for tv in vis:
		if _de_pais.has(tv):
			fuentes.append([_de_pais[tv], false])
	var a_vista := PackedInt32Array()                          # 0.1.8.2: tropas de cualquier país en la provincia que se está eligiendo como destino
	if modo_destino and dest_pi >= 0:
		for i in _de_pi.get(dest_pi, []):
			if not vis.has(int(_pilas[i]["pais"])) and not _enemigos.has(int(_pilas[i]["pais"])):
				a_vista.append(int(i))
	if not a_vista.is_empty():
		fuentes.append([a_vista, false])
	if not _hostiles.is_empty():                               # y las enemigas dentro del campo de visión
		fuentes.append([_hostiles, false])
	var listo := false
	for fu in fuentes:
		if listo:
			break
		var lista = fu[0]
		var es_la_elegida: bool = fu[1]
		for i in lista:
			if i == i_sel and not es_la_elegida:
				continue                              # la elegida ya se consideró antes
			var c: Vector2 = _pos[i]
			if foco != "":
				c = _vista(_pi[i], foco, fs)
			if c.y < vr.position.y - 60.0 / zr or c.y > vr.end.y + 60.0 / zr:
				continue
			var xb := c.x + roundf((cx_vista - c.x) / ANCHO) * ANCHO
			var nb: int = mini((_pilas[i]["regs"] as Array).size(), MAX_APILADOS)
			var alto_pila := float(nb) * ALTO_M + float(nb - 1) * SEPARA
			var w := _ancho_caja[i]
			for dxc in copias:
				var cx: float = xb + float(dxc)
				if absf(cx - cx_vista) > ancho_vista * 0.5:
					continue
				var dy := 0.0
				var r := Rect2(cx * zr + _off[i] - w * 0.5, c.y * zr - alto_pila * 0.5, w, alto_pila)
				# ¿hay un nombre de provincia a la vista justo ahí? El cuadro se corre (arriba o abajo) al hueco libre más cercano.
				var dx := 0.0
				if n_nombres > 0:
					var hueco: Array = _hueco_sin_nombres(r, (cx - c.x) * zr, grid, 320.0 if i == i_sel else 150.0)
					var mov: Vector2 = hueco[0]
					if mov != Vector2.ZERO:
						r.position += mov
						dx = mov.x
						dy = mov.y
					if not bool(hueco[1]) and i != i_sel:
						continue                          # no cabe sin tapar un nombre de provincia: se verá al acercar más
				if i == i_sel or _libre(r, grid):
					_ocupar(r.grow(2.0), grid)
					acept_i.append(i)
					acept_c.append(Vector2(cx, c.y))
					acept_dy.append(dy)
					acept_dx.append(dx)
			if acept_i.size() >= MAX_MARCAS:
				listo = true
				break
	PerfilScript.anotar(prof, "4 elegir pilas", t_p)
	t_p = Time.get_ticks_usec()
	for j in acept_i.size():
		var i2: int = acept_i[j]
		var p: Dictionary = _pilas[i2]
		var pa := int(p["pais"])
		var pais := String(_nombre_pais.get(pa, ""))
		var regs: Array = p["regs"]
		var nb2: int = mini(regs.size(), MAX_APILADOS)
		var en_combate: bool = _combate.has(int(p["prov"]))
		var w2 := _ancho_caja[i2]
		var alto2 := float(nb2) * ALTO_M + float(nb2 - 1) * SEPARA
		for b in nb2:
			var cy := -alto2 * 0.5 + ALTO_M * 0.5 + float(b) * (ALTO_M + SEPARA) + acept_dy[j]
			var rr: Array = regs[b]
			var es_sel: bool = int(rr[0]) == reg_sel or sel_regs.has(int(rr[0]))
			var txt: String
			var datos: Dictionary
			if regs.size() > MAX_APILADOS and b == nb2 - 1:
				var resto := 0
				for q in range(nb2 - 1, regs.size()):
					resto += int(regs[q][1])
				txt = "+%d" % (regs.size() - nb2 + 1)
				datos = {"t": "mas", "prov": int(p["prov"]), "pais": pa, "n": regs.size() - nb2 + 1, "sold": resto}
				_dibujar_caja(ci, k, acept_c[j], _off[i2] + acept_dx[j], cy, w2, txt, pais, false, 0.0, false, en_combate, true, not vis.has(pa))
			else:
				txt = str(int(rr[1]))
				datos = {"t": "reg", "reg": int(rr[0]), "prov": int(p["prov"]), "pais": pa, "sold": int(rr[1]), "pel": int(rr[2])}
				_dibujar_caja(ci, k, acept_c[j], _off[i2] + acept_dx[j], cy, w2, txt, pais, false, 0.0, es_sel, en_combate, false, not vis.has(pa))
			var rect := Rect2(acept_c[j].x * zr + _off[i2] + acept_dx[j] - w2 * 0.5, acept_c[j].y * zr + cy - ALTO_M * 0.5, w2, ALTO_M)
			_dib_pilas.append([rect, datos])
	PerfilScript.anotar(prof, "5 dibujar cajas", t_p)
	n_marcas = acept_i.size()
	n_hostiles = 0
	for i3 in acept_i:
		if not vis.has(int(_pilas[i3]["pais"])):
			n_hostiles += 1
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_unir_dibujados()
	ms_dibujo = float(Time.get_ticks_usec() - t0) / 1000.0


func _unir_dibujados() -> void:
	dibujados = _dib_pilas + _dib_marchas


## Dibuja un cuadro de tropas. `c` = punto del mapa, `off`/`dy` = desplazamiento en PÍXELES de pantalla, `w` = ancho en píxeles.
func _dibujar_caja(ci: CanvasItem, k: float, c: Vector2, off: float, dy: float, w: float, txt: String, pais: String, marcha: bool, ang: float, es_sel: bool, combate := false, resumen := false, hostil := false, col_marcha := ORO) -> void:
	var x0 := off - w * 0.5
	var col := _color_de(pais)
	ci.draw_set_transform(c, 0.0, Vector2(k, k))
	var r := Rect2(x0, dy - ALTO_M * 0.5, w, ALTO_M)
	if es_sel:
		ci.draw_rect(r.grow(3.0), Color(ORO.r, ORO.g, ORO.b, 0.95), false, 2.5)
	ci.draw_rect(r, FONDO, true)
	var borde := Color(1.0, 0.25, 0.2, 1.0) if combate else col.lightened(0.15)
	ci.draw_rect(r, borde, false, 2.4 if combate else 1.8)
	if hostil and not combate:                           # tropas enemigas: un filo rojo por fuera para distinguirlas de las tuyas
		ci.draw_rect(r.grow(2.0), Color(0.95, 0.22, 0.18, 0.9), false, 1.6)
	var x := x0 + 5.0
	if resumen:                                         # cuadro «+N»: solo el texto, centrado
		var tw := _ancho_txt(txt)
		ci.draw_string(fuente, Vector2(off - tw * 0.5, dy + 5.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FUENTE_PX, Color(0.98, 0.98, 1.0))
		_espadas(ci, r, combate)
		return
	if marcha:
		var tri := PackedVector2Array([Vector2(7.0, 0.0), Vector2(-5.0, -6.0), Vector2(-2.0, 0.0), Vector2(-5.0, 6.0)])
		for i in tri.size():
			tri[i] = tri[i].rotated(ang) + Vector2(x + 6.0, dy)
		ci.draw_colored_polygon(tri, col_marcha)           # el triángulo lleva el color de la línea de su ruta
		x += 13.0
	var tex := _bandera(pais)
	var rb := Rect2(x, dy - BANDERA_H * 0.5, BANDERA_W, BANDERA_H)
	if tex != null:
		ci.draw_texture_rect(tex, rb, false)
	else:
		ci.draw_rect(rb, col, true)
	ci.draw_rect(rb, Color(0.0, 0.0, 0.0, 0.55), false, 1.0)
	ci.draw_string(fuente, Vector2(x + BANDERA_W + 6.0, dy + 5.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FUENTE_PX, Color(0.98, 0.98, 1.0))
	_espadas(ci, r, combate)


## Insignia de batalla (espadas cruzadas sobre un disco rojo) en la esquina superior izquierda del cuadro.
func _espadas(ci: CanvasItem, r: Rect2, combate: bool) -> void:
	if not combate:
		return
	var c := r.position + Vector2(2.0, 1.0)
	ci.draw_circle(c, 9.0, Color(0.75, 0.08, 0.06, 1.0))
	ci.draw_arc(c, 9.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.8, 1.0), 1.2, true)
	ci.draw_line(c + Vector2(-4.5, -4.5), c + Vector2(4.5, 4.5), Color(1.0, 1.0, 1.0, 1.0), 2.0, true)
	ci.draw_line(c + Vector2(4.5, -4.5), c + Vector2(-4.5, 4.5), Color(1.0, 1.0, 1.0, 1.0), 2.0, true)
	ci.draw_line(c + Vector2(-5.5, -1.5), c + Vector2(-1.5, -5.5), Color(1.0, 0.9, 0.5, 1.0), 1.4, true)
	ci.draw_line(c + Vector2(1.5, -5.5), c + Vector2(5.5, -1.5), Color(1.0, 0.9, 0.5, 1.0), 1.4, true)


# ─────────────────────────────────────────────────────────────
# Columnas en marcha, rutas y vista previa
# ─────────────────────────────────────────────────────────────
## Copias del punto en el mapa que caen dentro de la vista (el mapa da la vuelta).
func _copias_en(c: Vector2, vr: Rect2) -> Array:
	var r := []
	for dx in [-ANCHO, 0.0, ANCHO]:
		var x: float = c.x + float(dx)
		if x >= vr.position.x and x <= vr.end.x and c.y >= vr.position.y and c.y <= vr.end.y:
			r.append(Vector2(x, c.y))
	return r


## Calcula (una sola vez por redibujo) dónde van las columnas en marcha y su cuadro. Lo usan la capa de rutas y la capa de cajas.
func _calc_marchas() -> void:
	if _m_listo:
		return
	_m_listo = true
	_cajas_m = []
	_dib_marchas = []
	_fantasma_dib = []
	if main == null or main.mundo == null or main.mundo.ejercito == null:
		return
	var ej = main.mundo.ejercito
	if ej.red == null:
		return
	red = ej.red
	if ej.marchas.is_empty() and not modo_destino:
		return
	var zr: float = main._zoom_real()
	zr_dibujado = zr
	var vr := _rect_vista()
	_centro_marchas = main.camara.position
	var foco: String = main.pais_foco
	var fs: float = main._escala_pop() if foco != "" else 1.0
	var vis := _tids_visibles()
	_actualizar_vision(ej)
	var frac := _frac_dia()
	var tid_j := _tid_jugador()
	var obs_rutas: bool = main.mundo.ve_todo() and ej.marchas.size() <= OBS_RUTAS_MAX        # observador: rutas de todas las columnas mientras no sean demasiadas
	_limpiar_colores(ej)
	for mid in ej.marchas:
		var m: Dictionary = ej.marchas[mid]
		var pa := int(m["pais"])
		var hostil := false
		if not vis.has(pa):
			if not _columna_hostil_visible(m):
				continue                              # columnas de países sin guerra contigo, o enemigas fuera de tu campo de visión: no se ven
			hostil = true
		var rid := int(m.get("reg", -1))
		var es_sel: bool = (sel.get("t", "") == "marcha" and int(sel.get("id", -1)) == int(mid)) or (rid >= 0 and sel_regs.has(rid))
		var pm: Array = _pos_marcha(m, frac, foco, fs)
		var pos: Vector2 = pm[0]
		var txt := str(ej.soldados_marcha(m))
		var w := _ancho_de_caja(txt, true)
		var pais := String(_nombre_pais.get(pa, ""))
		var copias: Array = _copias_en(pos, vr)
		var con_ruta: bool = pa == tid_j or es_sel or hostil              # de quién se dibuja la ruta
		var col_r: Color = (COL_HOSTIL if hostil else color_marcha(int(mid))) if con_ruta else ORO
		_cajas_m.append({"mid": int(mid), "m": m, "pos": pos, "ang": float(pm[1]), "es_sel": es_sel, "txt": txt, "w": w, "pais": pais, "pa": pa, "copias": copias, "hostil": hostil, "con_ruta": con_ruta, "col": col_r})
		for c in copias:
			_dib_marchas.append([Rect2(c.x * zr - w * 0.5, c.y * zr - ALTO_M * 0.5, w, ALTO_M), {"t": "marcha", "id": int(mid), "reg": rid}])
	if not fantasma.is_empty():
		var txt_f := String(fantasma["txt"])
		_fantasma_dib = [fantasma["pos"], txt_f, _ancho_de_caja(txt_f), String(fantasma["pais"])]


## CAPA DE RUTAS (debajo): rutas de las columnas, ruta dorada de la vista previa y su etiqueta de destino. Los cuadros NO se dibujan aquí.
func _pintar_marchas(ci: CanvasItem) -> void:
	var t0 := Time.get_ticks_usec()
	_oro = []
	_calc_marchas()
	if main == null or main.mundo == null or main.mundo.ejercito == null or main.mundo.ejercito.red == null:
		_unir_dibujados()
		return
	var ej = main.mundo.ejercito
	if ej.marchas.is_empty() and not modo_destino:
		_unir_dibujados()
		return
	var zr: float = main._zoom_real()
	var k := 1.0 / zr
	var vr := _rect_vista()
	var foco: String = main.pais_foco
	var fs: float = main._escala_pop() if foco != "" else 1.0
	_construir_y_dibujar_rutas(ci, foco, fs, vr, zr)
	if modo_destino and origen_pi >= 0:
		_dibujar_prevista(ci, foco, fs, vr, zr, k)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_unir_dibujados()
	ms_marchas = float(Time.get_ticks_usec() - t0) / 1000.0


## CAPA DE CAJAS DE COLUMNAS (arriba de todo): el cuadro de cada columna en marcha y el cuadrito fantasma del arrastre.
func _pintar_cajas_marchas(ci: CanvasItem) -> void:
	_calc_marchas()
	var zr: float = main._zoom_real() if main != null else 1.0
	var k := 1.0 / zr
	for e in _cajas_m:
		for c in (e["copias"] as Array):
			_dibujar_caja(ci, k, c, 0.0, 0.0, float(e["w"]), String(e["txt"]), String(e["pais"]), true, float(e["ang"]), bool(e["es_sel"]), false, false, bool(e.get("hostil", false)), e.get("col", ORO))
	if not _fantasma_dib.is_empty():
		_dibujar_caja(ci, k, _fantasma_dib[0], 0.0, 0.0, float(_fantasma_dib[2]), String(_fantasma_dib[1]), String(_fantasma_dib[3]), false, 0.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ── Colores de las rutas (0.1.8.2a): cada columna en marcha tiene el suyo, distinto de los de las demás columnas activas ──
const COL_HOSTIL := Color(1.0, 0.36, 0.32)
const PALETA: Array = [
	Color(0.96, 0.42, 0.40),   # coral
	Color(0.98, 0.66, 0.26),   # naranja
	Color(0.93, 0.86, 0.33),   # amarillo
	Color(0.62, 0.84, 0.35),   # lima
	Color(0.28, 0.76, 0.46),   # verde
	Color(0.25, 0.80, 0.78),   # turquesa
	Color(0.38, 0.65, 0.98),   # azul cielo
	Color(0.52, 0.48, 0.96),   # índigo
	Color(0.76, 0.50, 0.95),   # violeta
	Color(0.95, 0.46, 0.78),   # rosa
	Color(0.78, 0.60, 0.42),   # arena
	Color(0.88, 0.90, 0.94),   # gris claro
]
const CUERPO_PX := 3.0             # grosor del cuerpo de la línea (píxeles de pantalla)
const CARRIL_PX := 5.2             # separación entre líneas paralelas que comparten un tramo («carriles» como en un mapa de metro)
const CARRIL_ANCHO_TOTAL := 48.0   # ancho máximo que puede ocupar un haz de carriles


## Color de la ruta de una columna: el primer hueco libre de la paleta; pasada la primera vuelta, los mismos colores en tono oscuro y luego claro.
func color_marcha(mid: int) -> Color:
	if not _idx_col.has(mid):
		var i := 0
		while _col_usado.has(i):
			i += 1
		_idx_col[mid] = i
		_col_usado[i] = mid
	var idx: int = _idx_col[mid]
	return _color_paleta(idx)


static func _color_paleta(idx: int) -> Color:
	var base: Color = PALETA[idx % PALETA.size()]
	match (idx / PALETA.size()) % 3:
		1:
			return base.darkened(0.34)
		2:
			return base.lerp(Color(1, 1, 1), 0.42)
	return base


## Libera los colores de las columnas que ya llegaron.
func _limpiar_colores(ej) -> void:
	if _idx_col.is_empty():
		return
	var fuera := []
	for mid in _idx_col:
		if not ej.marchas.has(int(mid)):
			fuera.append(int(mid))
	for mid in fuera:
		_col_usado.erase(int(_idx_col[mid]))
		_idx_col.erase(mid)


## Arma las polilíneas de TODAS las rutas a dibujar y las pinta. Las columnas que comparten un tramo del camino no se amontonan: cada una ocupa
## un «carril» paralelo (ordenadas por ID de columna), y al separarse o juntarse se unen con un pequeño codo, como las líneas de un mapa de metro.
func _construir_y_dibujar_rutas(ci: CanvasItem, foco: String, fs: float, vr: Rect2, zr: float) -> void:
	var aristas := {}                                    # clave de tramo (a * 8192 + b con a < b) -> IDs de columnas que lo usan
	var lista: Array = []
	for e in _cajas_m:
		if not bool(e["con_ruta"]):
			continue
		lista.append(e)
		if bool(e.get("hostil", false)):
			continue                                     # las enemigas no ocupan carril
		var ruta: PackedInt32Array = (e["m"] as Dictionary)["ruta"]
		var k0: int = mini(int(e["m"]["k"]), ruta.size() - 2)
		for i in range(k0, ruta.size() - 1):
			var key: int = mini(ruta[i], ruta[i + 1]) * 8192 + maxi(ruta[i], ruta[i + 1])
			var usuario: int = int(e["mid"]) * 2 + (1 if ruta[i] < ruta[i + 1] else 0)     # ID de columna y sentido (1 = de la provincia menor a la mayor)
			if aristas.has(key):
				(aristas[key] as Array).append(usuario)
			else:
				aristas[key] = [usuario]
	n_carriles_max = 0
	var vpos := {}                                       # provincia -> posición en la vista
	var normales := {}                                   # clave de tramo -> normal canónica (la misma para quien lo recorra en cualquier sentido)
	for e in lista:
		var m: Dictionary = e["m"]
		var ruta: PackedInt32Array = m["ruta"]
		var k0: int = mini(int(m["k"]), ruta.size() - 2)
		var hostil: bool = bool(e.get("hostil", false))
		var pos: Vector2 = e["pos"]
		# centros de los nodos que faltan por recorrer, ya «desenrollados» (el mapa da la vuelta)
		var cent := PackedVector2Array([pos])
		var prev := pos
		for i in range(k0 + 1, ruta.size()):
			var pi: int = ruta[i]
			if not vpos.has(pi):
				vpos[pi] = _vista(pi, foco, fs)
			var q: Vector2 = vpos[pi]
			q = Vector2(prev.x + RedScript.dx_corto(prev.x, q.x), q.y)
			cent.append(q)
			prev = q
		# desplazamiento lateral de cada tramo (en unidades de mapa)
		var n_tr := ruta.size() - 1 - k0
		var desp := PackedVector2Array()
		var es_mar: Array = []
		for j in n_tr:
			var a: int = ruta[k0 + j]
			var b: int = ruta[k0 + j + 1]
			var t: Array = red.tramo(a, b)
			es_mar.append(not t.is_empty() and int(t[1]) == 1)
			var d := Vector2.ZERO
			if not hostil:
				var key: int = mini(a, b) * 8192 + maxi(a, b)
				var usan: Array = aristas[key]
				if usan.size() > 1:
					if not normales.has(key):
						usan.sort()                        # por ID de columna: la de menor ID es la «guía» del tramo
						var lo: int = mini(a, b)
						var hi: int = maxi(a, b)
						if not vpos.has(lo):
							vpos[lo] = _vista(lo, foco, fs)
						if not vpos.has(hi):
							vpos[hi] = _vista(hi, foco, fs)
						var plo: Vector2 = vpos[lo]
						var phi: Vector2 = vpos[hi]
						var dir := Vector2(RedScript.dx_corto(plo.x, phi.x), phi.y - plo.y).normalized()
						if (int(usan[0]) & 1) == 0:
							dir = -dir                     # sentido de marcha de la columna guía
						normales[key] = Vector2(-dir.y, dir.x)   # su derecha: así los carriles no se cruzan mientras compartan camino
					var mio: int = int(e["mid"]) * 2 + (1 if a < b else 0)
					var rango: int = usan.find(mio)
					var paso: float = minf(CARRIL_PX, CARRIL_ANCHO_TOTAL / float(usan.size()))
					n_carriles_max = maxi(n_carriles_max, usan.size())
					d = (normales[key] as Vector2) * ((float(rango) - float(usan.size() - 1) * 0.5) * paso / zr)
			desp.append(d)
		# polilínea: cada tramo por su carril; entre tramos con carril distinto, un codo
		var pts := PackedVector2Array([cent[0] + desp[0]])
		var mar: Array = []
		for j in n_tr:
			var fin_j: Vector2 = cent[j + 1] + desp[j]
			pts.append(fin_j)
			mar.append(es_mar[j])
			if j + 1 < n_tr:
				var ini_s: Vector2 = cent[j + 1] + desp[j + 1]
				if fin_j.distance_squared_to(ini_s) > 0.0004 / (zr * zr):
					pts.append(ini_s)
					mar.append(es_mar[j] and es_mar[j + 1])
		if desp[n_tr - 1].length_squared() > 0.0:
			pts.append(cent[n_tr])                       # al llegar, todos los carriles confluyen en el centro de la provincia de destino
			mar.append(false)
		_cinta(ci, pts, mar, e["col"], bool(e["es_sel"]), hostil, vr, zr, int(e["mid"]))


## Dibuja una ruta como una línea fina de UN solo color (sin borde) y la registra para que `CapaFlechas` deslice las flechas por dentro.
## Los tramos de tierra van continuos (una sola polilínea); los de mar, rayados. Se dibuja en PÍXELES (transformación 1/zoom): borde nítido a cualquier zoom.
func _cinta(ci: CanvasItem, pts: PackedVector2Array, mar: Array, col: Color, destacada: bool, hostil: bool, vr: Rect2, zr: float, mid := -1) -> void:
	if pts.size() < 2:
		return
	var bb := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		bb = bb.expand(p)
	var cuerpo: float = CUERPO_PX * (1.4 if destacada else 1.0)
	var vr2 := vr.grow(20.0 / zr)
	var visible_ := false
	for dx in [-ANCHO, 0.0, ANCHO]:
		if Rect2(bb.position + Vector2(float(dx), 0.0), bb.size).grow(cuerpo / zr).intersects(vr2, true):
			visible_ = true
			break
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var fin: Vector2 = pts[pts.size() - 1]
	_oro.append({"pts": pts, "cum": cum, "fin": fin, "col": col, "sel": destacada, "mid": mid, "hostil": hostil})
	if not visible_:
		return
	var px := PackedVector2Array()
	px.resize(pts.size())
	for i in pts.size():
		px[i] = pts[i] * zr
	var col_c := Color(col.r, col.g, col.b, 1.0 if destacada else 0.92)       # un solo color liso: sin borde ni contorno
	var raya := 7.0
	for dx in [-ANCHO, 0.0, ANCHO]:
		var off := Vector2(float(dx), 0.0)
		if not Rect2(bb.position + off, bb.size).grow(cuerpo / zr).intersects(vr2, true):
			continue
		ci.draw_set_transform(off, 0.0, Vector2(1.0 / zr, 1.0 / zr))
		var i := 0
		var n := px.size() - 1
		while i < n:
			if bool(mar[i]):
				ci.draw_dashed_line(px[i], px[i + 1], col_c, cuerpo, raya)
				i += 1
			else:
				var j := i
				while j < n and not bool(mar[j]):
					j += 1
				if j - i == 1:
					ci.draw_line(px[i], px[j], col_c, cuerpo, true)
				else:
					ci.draw_polyline(px.slice(i, j + 1), col_c, cuerpo, true)
				i = j
		ci.draw_circle(fin * zr, cuerpo * 0.5 + 1.0, col_c)                  # punto de llegada: un disco del mismo color
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dibujar_prevista(ci: CanvasItem, foco: String, fs: float, vr: Rect2, zr: float, k: float) -> void:
	if dest_pi < 0:
		return
	if ruta_prev.size() >= 2:
		var pts := PackedVector2Array()
		var mar := []
		var prev := Vector2.ZERO
		for i in ruta_prev.size():
			var q := _vista(ruta_prev[i], foco, fs)
			if i > 0:
				q = Vector2(prev.x + RedScript.dx_corto(prev.x, q.x), q.y)
				var t: Array = red.tramo(ruta_prev[i - 1], ruta_prev[i])
				mar.append(not t.is_empty() and int(t[1]) == 1)
			pts.append(q)
			prev = q
		_cinta(ci, pts, mar, Color(ORO.r, ORO.g, ORO.b, 1.0), true, false, vr, zr)
		var fin: Vector2 = pts[pts.size() - 1]
		for c in _copias_en(fin, vr):
			_etiqueta_destino(ci, c, texto_prev, k, Color(1.0, 0.45, 0.35, 1.0) if guerra_prev else Color(ORO.r, ORO.g, ORO.b, 1.0))
		# el punto de partida lleva un aro dorado
		for c in _copias_en(pts[0], vr):
			ci.draw_set_transform(c, 0.0, Vector2(k, k))
			ci.draw_circle(Vector2.ZERO, 3.6, Color(ORO.r, ORO.g, ORO.b, 1.0))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var c0 := _vista(dest_pi, foco, fs)
		for c in _copias_en(c0, vr):
			_etiqueta_destino(ci, c, texto_prev, k, Color(1.0, 0.5, 0.4, 1.0))


# ── flechas animadas: dentro de la cinta, del mismo color (en un tono más claro) ──
const FLECHA_ESPACIO_PX := 40.0        # distancia entre flechas (en pantalla)
const FLECHA_VEL_PX := 44.0            # a cuánto se deslizan (píxeles por segundo)
const FLECHA_MAX := 220                # tope de flechas por ruta

func _pintar_flechas(ci: CanvasItem) -> void:
	if _oro.is_empty() or main == null:
		return
	_flechas_dibujadas = true
	var zr: float = main._zoom_real()
	var vr := _rect_vista()
	var vr2 := vr.grow(20.0 / zr)
	var t: float = Time.get_ticks_msec() / 1000.0
	var fase_px: float = fposmod(t * FLECHA_VEL_PX, FLECHA_ESPACIO_PX)
	var latido := 0.5 + 0.5 * sin(t * 4.2)
	for r in _oro:
		var pts: PackedVector2Array = r["pts"]
		var cum: PackedFloat32Array = r["cum"]
		var largo_px: float = cum[cum.size() - 1] * zr
		var destacada: bool = bool(r.get("sel", false))
		var col: Color = r["col"]
		if largo_px >= 12.0:
			var bb := Rect2(pts[0], Vector2.ZERO)
			for p in pts:
				bb = bb.expand(p)
			bb = bb.grow(30.0 / zr)
			var n_flechas := mini(int(largo_px / FLECHA_ESPACIO_PX) + 1, FLECHA_MAX)
			var tinte := col.lerp(Color(1, 1, 1), 0.6)
			var ala: float = 1.3 * (1.4 if destacada else 1.0)         # semialto de la flecha: cabe dentro del cuerpo de la cinta
			var punta: float = 2.4 * (1.4 if destacada else 1.0)
			var cola: float = 1.8 * (1.4 if destacada else 1.0)
			var trazo: float = 1.0 * (1.4 if destacada else 1.0)
			for dx in [-ANCHO, 0.0, ANCHO]:
				var off := Vector2(float(dx), 0.0)
				if not Rect2(bb.position + off, bb.size).intersects(vr, true):
					continue
				var seg := 0
				var pp := PackedVector2Array()
				var cc := PackedColorArray()
				for j in n_flechas:
					var d_px: float = fase_px + float(j) * FLECHA_ESPACIO_PX
					if d_px > largo_px - 12.0:
						break
					var d: float = d_px / zr
					while seg < pts.size() - 2 and cum[seg + 1] < d:
						seg += 1
					var largo_seg: float = cum[seg + 1] - cum[seg]
					if largo_seg <= 0.0000001:
						continue
					var f: float = (d - cum[seg]) / largo_seg
					var pos: Vector2 = pts[seg].lerp(pts[seg + 1], f) + off
					if not vr2.has_point(pos):
						continue
					var u: Vector2 = (pts[seg + 1] - pts[seg]).normalized()
					var v := Vector2(-u.y, u.x)
					# se funden al salir de la tropa y al llegar al destino
					var a: float = clampf((d_px - 16.0) / 22.0, 0.0, 1.0) * clampf((largo_px - 12.0 - d_px) / 26.0, 0.0, 1.0)
					if a <= 0.01:
						continue
					var c0: Vector2 = pos * zr
					var punta_p: Vector2 = c0 + u * punta
					pp.append(c0 - u * cola + v * ala)
					pp.append(punta_p)
					pp.append(punta_p)
					pp.append(c0 - u * cola - v * ala)
					var ci_ := Color(tinte.r, tinte.g, tinte.b, a)
					cc.append(ci_)
					cc.append(ci_)
				if pp.size() >= 2:
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / zr, 1.0 / zr))
					ci.draw_multiline_colors(pp, cc, trazo, true)
		# anillo que late en el destino (solo la ruta elegida y la vista previa)
		if destacada:
			var fin: Vector2 = r["fin"]
			for c in _copias_en(fin, vr):
				ci.draw_set_transform(c, 0.0, Vector2(1.0 / zr, 1.0 / zr))
				ci.draw_arc(Vector2.ZERO, 11.0 + 5.0 * latido, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.75 * (1.0 - latido)), 2.2, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _etiqueta_destino(ci: CanvasItem, c: Vector2, texto: String, k: float, col: Color) -> void:
	ci.draw_set_transform(c, 0.0, Vector2(k, k))
	ci.draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, col, 2.5, true)
	ci.draw_circle(Vector2.ZERO, 2.5, col)
	if texto != "":
		ci.draw_string_outline(fuente, Vector2(13.0, -9.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 6, Color(0.03, 0.05, 0.1, 0.97))
		ci.draw_string(fuente, Vector2(13.0, -9.0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ─────────────────────────────────────────────────────────────
# Interacción
# ─────────────────────────────────────────────────────────────
## Datos del cuadrito que hay bajo `pos_mundo` (posición del cursor en el mapa), o {} si no hay ninguno. Las columnas van encima.
func marcador_en(pos_mundo: Vector2) -> Dictionary:
	var q := pos_mundo * zr_dibujado
	for i in range(_dib_marchas.size() - 1, -1, -1):
		if (_dib_marchas[i][0] as Rect2).has_point(q):
			return _dib_marchas[i][1]
	for i in range(_dib_pilas.size() - 1, -1, -1):
		if (_dib_pilas[i][0] as Rect2).has_point(q):
			return _dib_pilas[i][1]
	return {}


## Cuadrito que acompaña al cursor mientras se arrastra una pila hacia su destino.
func poner_fantasma(pos_mapa: Vector2, txt: String, pais: String) -> void:
	fantasma = {"pos": pos_mapa, "txt": txt, "pais": pais}


func quitar_fantasma() -> void:
	if fantasma.is_empty():
		return
	fantasma = {}
	refrescar()


## Entra en el modo «elige el destino»: `prov_tid` es la provincia de origen.
func empezar_destino(prov_tid: int, reg := -1) -> void:
	var ej = main.mundo.ejercito
	var pr = ej.provincia_por_tid(prov_tid)
	origen_pi = pr.idx if pr != null else -1
	modo_destino = origen_pi >= 0
	reg_prev = reg
	guerra_prev = false
	dest_pi = -1
	ruta_prev = PackedInt32Array()
	texto_prev = ""
	refrescar()


func terminar_destino() -> void:
	modo_destino = false
	reg_prev = -1
	guerra_prev = false
	dest_pi = -1
	origen_pi = -1
	ruta_prev = PackedInt32Array()
	texto_prev = ""
	refrescar()


## Provincia bajo el cursor (o -1 si es mar): recalcula la ruta y el tiempo que se mostrará.
func poner_destino(pi: int) -> void:
	if not modo_destino or pi == dest_pi:
		return
	dest_pi = pi
	ruta_prev = PackedInt32Array()
	texto_prev = ""
	guerra_prev = false
	if pi < 0:
		return
	if pi == origen_pi:
		texto_prev = "ya están aquí"
		return
	var r: PackedInt32Array = red.ruta(origen_pi, pi)
	if r.size() < 2:
		texto_prev = "sin ruta"
		return
	ruta_prev = r
	var dias := int(ceilf(red.coste_ruta(r) / EjercitoScript.VEL_MARCHA_KM_DIA))
	texto_prev = "%d %s · %d prov." % [dias, "día" if dias == 1 else "días", r.size() - 1]
	var aviso := _aviso_guerra(pi)
	if aviso != "":
		guerra_prev = true
		texto_prev += " · " + aviso


## «¡GUERRA con X!» si entrar a la provincia `pi` con el regimiento que va a salir declararía una guerra nueva (en el modo libre sin país);
## con un país controlado (0.1.8.3) avisa de que hay que declarar la guerra antes; si no hace falta nada, "".
func _aviso_guerra(pi: int) -> String:
	var ej = main.mundo.ejercito
	if reg_prev < 0 or not ej.existe_reg(reg_prev):
		return ""
	var pais_tid: int = ej.pais_de_reg(reg_prev)
	var dueno: int = main.mundo.rival_por_entrar(pais_tid, pi)
	if dueno < 0:
		return ""
	var nombre_d: String = ej.bd.nombre_de(dueno)
	if not main.mundo.puede_atacar(pais_tid, dueno):                 # campaña: sin IA no hay competencia ni conquista
		return "%s no tiene IA: no se puede conquistar (Debug > IA)" % nombre_d
	if main.mundo.jugador != "":                                     # 0.1.8.3: el jugador ya no declara la guerra marchando: la orden se bloquea hasta declararla en Diplomacia
		return "Sin guerra con %s: decláraselo antes (su ficha > Diplomacia)" % nombre_d
	return "¡GUERRA con %s!" % nombre_d
