extends RefCounted
## Dibujo del mapa por CELDAS (0.1.8.35; antes por provincias, 0.1.7.9.9F).
##
## El mundo está cortado en celdas (cada anillo de `anillos` es una celda: ver herramientas/construir_mapa.py, modo GE_CELDAS) y cada provincia es un
## grupo de celdas (`celda_prov`: celda → provincia). La geometría (relleno, aristas entre celdas vecinas) es la misma para todas las épocas; lo que cambia es
## la tabla. Esta clase dibuja el mapa a partir de ella y sigue ofreciendo la API de siempre POR PROVINCIA (un arreglo `dueno` con el ID del país dueño de cada
## provincia), así el resto del juego no sabe que por dentro hay celdas.
##
## Cuando una provincia cambia de dueño (conquista, anexión, debug) el mapa se rehace SOLO desde el dueño actual de cada provincia, con tres reglas:
##  1. RELLENO: una provincia con dueño distinto del original toma el color EXACTO de su país dueño (el mismo que llevan sus provincias propias). No hay
##     capas encima: se recolorean los vértices de las mismas mallas del mapa (así no hay costuras ni transparencias). Si vuelve a su dueño original
##     recupera sus colores horneados.
##  2. FRONTERAS: hay una arista por cada par de celdas vecinas (datos/malla_par_*). Se dibuja como frontera de país solo la de los pares cuyo dueño es
##     DISTINTO; las líneas de provincia son las de los pares de provincias distintas con el mismo dueño (las de dos celdas de una MISMA provincia no existen).
##  3. LÍNEAS DE PROVINCIA del país enfocado: todos los pares cuyos dos lados son suyos y de provincias distintas.
##
## Cambiar la forma de una provincia = `mover_celdas(celdas, provincia)`: se actualizan las tablas, las celdas se repintan en el siguiente `pintar` y las
## fronteras se rehacen solas (las líneas salen de las mismas aristas, ahora clasificadas con la nueva tabla). Ver scripts/territorio.gd.

var main                                        # MapaPrincipal (crea mallas con _crear_malla / _a_vec2)
var vb := PackedByteArray()                     # vértices del relleno por teselas (malla_filt_v.bin)
var ib := PackedByteArray()                     # índices del relleno por teselas (malla_filt_i.bin)
var cp := PackedByteArray()                     # colores horneados (3 bytes por vértice, malla_filt_cp.bin)
var teselas: Array = []                         # [{v0, nv, i0, ni, inst: [MeshInstance2D], cols: PackedColorArray | null}]
var runs_ofs := PackedInt32Array()              # por CELDA: posición de su primer run (n_celdas + 1 valores)
var runs := PackedInt32Array()                  # por run: [tesela, vértice global inicial, cantidad]
var original := PackedInt32Array()              # dueño con el que se hornearon los colores (por PROVINCIA)
var aplicado := PackedInt32Array()              # dueño con el que está pintada ahora cada provincia
var plano := false                              # 0.1.8.2a: true = ignora los colores horneados y pinta TODO con el color plano del dueño (esquemas de color por modo)

# ── Celdas y provincias ──
var n_celdas := 0
var celda_prov := PackedInt32Array()            # por celda: provincia a la que pertenece AHORA
var prov_celdas: Array = []                     # por provincia: PackedInt32Array con sus celdas
var original_c := PackedInt32Array()            # por celda: dueño con el que se hornearon sus colores
var _celdas_sucias := PackedInt32Array()        # celdas que cambiaron de provincia y hay que repintar

var par_v := PackedVector2Array()               # 4 vértices por segmento
var par_uv := PackedVector2Array()
var par_c := PackedColorArray()                 # distancia recorrida por vértice (codificada en 2 canales) para las franjas; vacío si falta el archivo
var par_i := PackedInt32Array()                 # patrón [0,1,2,1,3,2] + 4k (cualquier prefijo de segmentos es una malla válida)
var par_tab := PackedInt32Array()               # por par: celda a, celda b, primer segmento, cantidad de segmentos
var n_pares := 0
var listo := false

## Índices de los pares de celdas (se construyen una vez al cargar). Sirven para NO recorrer todos los pares cada vez que algo cambia de dueño.
var par_a := PackedInt32Array()                 # celda «a» de cada par (copia plana de par_tab)
var par_b := PackedInt32Array()                 # celda «b» de cada par
var par_pa := PackedInt32Array()                # provincia de la celda «a» (se mantiene al mover celdas)
var par_pb := PackedInt32Array()                # provincia de la celda «b»
var pp_ini := PackedInt32Array()                # por celda: dónde empiezan sus pares en `pp` (n_celdas + 1 valores)
var pp := PackedInt32Array()                    # pares en los que participa cada celda (agrupados por celda)

## Vecindad entre PROVINCIAS (sale de los pares de celdas de provincias distintas). Se rehace sola cuando se mueven celdas.
var _prv_ini := PackedInt32Array()
var _prv := PackedInt32Array()
var _prv_sucio := true

## Tiempos de la última actualización (ms), para las pruebas de rendimiento.
var ms_relleno := 0.0
var ms_frontera := 0.0
var provincias_repintadas := 0


## Obliga a que el próximo `pintar` repinte todas las provincias (al cambiar el esquema de colores).
func repintar_todo() -> void:
	aplicado.fill(-2)


## `lista_fill`: entradas [tx, ty, v0, nv, i0, ni] de teselas.json. `instancias[k]`: los MeshInstance2D (copias del mapa) de la tesela k.
## `dueno_inicial`: dueño de cada PROVINCIA. `p_celda_prov`: provincia de cada celda (el campo `p` de `anillos`).
func iniciar(p_main, p_vb: PackedByteArray, p_ib: PackedByteArray, p_cp: PackedByteArray, lista_fill: Array, instancias: Array,
		dueno_inicial: PackedInt32Array, p_celda_prov: PackedInt32Array) -> void:
	main = p_main
	vb = p_vb
	ib = p_ib
	cp = p_cp
	teselas.clear()
	for k in lista_fill.size():
		var t: Array = lista_fill[k]
		teselas.append({"v0": int(t[2]), "nv": int(t[3]), "i0": int(t[4]), "ni": int(t[5]), "inst": instancias[k], "cols": null})
	celda_prov = p_celda_prov.duplicate()
	n_celdas = celda_prov.size()
	var r: PackedInt32Array = main._leer_bytes("malla_filt_runs.bin").to_int32_array()
	if r.size() > n_celdas + 1:
		runs_ofs = r.slice(0, n_celdas + 1)
		runs = r.slice(n_celdas + 1)
	original = dueno_inicial.duplicate()
	aplicado = dueno_inicial.duplicate()
	_indexar_provincias()
	original_c.resize(n_celdas)
	for c in n_celdas:
		original_c[c] = original[celda_prov[c]]
	par_v = main._a_vec2(main._leer_bytes("malla_par_v.bin"))
	par_uv = main._a_vec2(main._leer_bytes("malla_par_uv.bin"))
	par_c = main._a_colores(main._leer_bytes("malla_par_c.bin"))
	if par_c.size() != par_v.size():
		par_c = PackedColorArray()
	par_i = main._leer_bytes("malla_par_i.bin").to_int32_array()
	par_tab = main._leer_bytes("malla_par_tab.bin").to_int32_array()
	n_pares = par_tab.size() / 4
	listo = runs_ofs.size() == n_celdas + 1 and n_pares > 0 and par_v.size() > 0
	if listo:
		_indexar_pares()


## Lista de celdas de cada provincia (a partir de `celda_prov`).
func _indexar_provincias() -> void:
	var np_ := original.size()
	prov_celdas.clear()
	prov_celdas.resize(np_)
	for p in np_:
		prov_celdas[p] = PackedInt32Array()
	for c in n_celdas:
		var p: int = celda_prov[c]
		if p >= 0 and p < np_:
			var l: PackedInt32Array = prov_celdas[p]               # los arreglos empaquetados se copian al sacarlos de un Array: se modifica la copia y se devuelve
			prov_celdas[p] = null                                  # (sin esta referencia de más, append no tiene que copiar la lista entera)
			l.append(c)
			prov_celdas[p] = l


## Construye `par_a`, `par_b`, `par_pa`, `par_pb`, `pp_ini` y `pp` a partir de `par_tab` (una sola pasada).
func _indexar_pares() -> void:
	par_a.resize(n_pares)
	par_b.resize(n_pares)
	par_pa.resize(n_pares)
	par_pb.resize(n_pares)
	pp_ini.resize(n_celdas + 1)
	pp_ini.fill(0)
	for k in n_pares:
		var a: int = par_tab[k * 4]
		var b: int = par_tab[k * 4 + 1]
		par_a[k] = a
		par_b[k] = b
		par_pa[k] = celda_prov[a]
		par_pb[k] = celda_prov[b]
		pp_ini[a + 1] += 1
		pp_ini[b + 1] += 1
	for i in n_celdas:
		pp_ini[i + 1] += pp_ini[i]
	pp.resize(pp_ini[n_celdas])
	var pos := pp_ini.slice(0, n_celdas)
	for k in n_pares:
		var a2: int = par_a[k]
		var b2: int = par_b[k]
		pp[pos[a2]] = k
		pos[a2] += 1
		pp[pos[b2]] = k
		pos[b2] += 1
	_prv_sucio = true


# ── Cambiar la forma de las provincias ───────────────────────────────────────────────────────────────────────────
## Pasa `celdas` a la provincia `destino`. Actualiza las tablas (celda → provincia, provincia → celdas, provincia de cada lado de cada par) y deja las
## celdas pendientes de repintar y las fronteras por recalcular. NO toca anillos ni objetos de Mundo: eso lo hace Territorio. Devuelve cuántas se movieron.
func mover_celdas(celdas: PackedInt32Array, destino: int) -> int:
	var movidas := 0
	for c in celdas:
		var vieja: int = celda_prov[c]
		if vieja == destino:
			continue
		var lista: PackedInt32Array = prov_celdas[vieja]
		var pos := lista.find(c)
		if pos >= 0:
			lista.remove_at(pos)
			prov_celdas[vieja] = lista
		var nueva: PackedInt32Array = prov_celdas[destino]
		nueva.append(c)
		prov_celdas[destino] = nueva
		celda_prov[c] = destino
		for j in range(pp_ini[c], pp_ini[c + 1]):
			var k: int = pp[j]
			if par_a[k] == c:
				par_pa[k] = destino
			else:
				par_pb[k] = destino
		_celdas_sucias.append(c)
		movidas += 1
	if movidas > 0:
		_prv_sucio = true
		_fr_sucio = true
	return movidas


## Celdas que tocan a la celda `c` (comparten arista), sin repetir.
func celdas_vecinas(c: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	for j in range(pp_ini[c], pp_ini[c + 1]):
		var k: int = pp[j]
		var o: int = par_a[k] + par_b[k] - c
		if not r.has(o):
			r.append(o)
	return r


## Provincias que tocan a la provincia `p` (comparten al menos una arista entre sus celdas), sin repetir y en orden.
func provincias_vecinas(p: int) -> PackedInt32Array:
	_asegurar_prv()
	if p < 0 or p + 1 >= _prv_ini.size():
		return PackedInt32Array()
	return _prv.slice(_prv_ini[p], _prv_ini[p + 1])


func _asegurar_prv() -> void:
	if not _prv_sucio:
		return
	var np_ := original.size()
	var tmp: Array = []
	tmp.resize(np_)
	for p in np_:
		tmp[p] = {}
	for k in n_pares:
		var a: int = par_pa[k]
		var b: int = par_pb[k]
		if a != b:
			(tmp[a] as Dictionary)[b] = true
			(tmp[b] as Dictionary)[a] = true
	_prv_ini.resize(np_ + 1)
	_prv_ini[0] = 0
	var plano_prv := PackedInt32Array()
	for p in np_:
		var claves: Array = (tmp[p] as Dictionary).keys()
		claves.sort()
		plano_prv.append_array(PackedInt32Array(claves))
		_prv_ini[p + 1] = plano_prv.size()
	_prv = plano_prv
	_prv_sucio = false


# ── Relleno ─────────────────────────────────────────────────────────────────────────────────────────────────────
## Pinta cada provincia con el color de su dueño actual. `color_de`: ID de dueño -> Color. Solo toca las provincias cuyo
## dueño cambió desde la última vez (y las celdas que cambiaron de provincia) y reconstruye solo las teselas afectadas. Devuelve cuántas provincias repintó.
func pintar(dueno: PackedInt32Array, color_de: Dictionary) -> int:
	if not listo:
		return 0
	var t0 := Time.get_ticks_usec()
	var tocadas := {}
	var n := 0
	for p in dueno.size():
		var o: int = dueno[p]
		if o == aplicado[p]:
			continue
		aplicado[p] = o
		n += 1
		for c in (prov_celdas[p] as PackedInt32Array):
			_pintar_celda(c, o, color_de, tocadas)
	for c in _celdas_sucias:
		_pintar_celda(c, dueno[celda_prov[c]], color_de, tocadas)
	_celdas_sucias.clear()
	for ti in tocadas:
		_reconstruir_tesela(int(ti))
	provincias_repintadas = n
	ms_relleno = float(Time.get_ticks_usec() - t0) / 1000.0
	return n


## Pinta los vértices de la celda `c` con el color del dueño `o` (o con los horneados si `o` es el dueño con el que se hornearon).
func _pintar_celda(c: int, o: int, color_de: Dictionary, tocadas: Dictionary) -> void:
	var col_n := Color.WHITE
	var propio: bool = o == original_c[c] and not plano
	if not propio:
		col_n = color_de.get(o, Color(0.55, 0.55, 0.6))
	for k in range(runs_ofs[c], runs_ofs[c + 1]):
		var ti: int = runs[k * 3]
		var t: Dictionary = teselas[ti]
		if t["cols"] == null:
			t["cols"] = main._a_colores(cp.slice(int(t["v0"]) * 3, (int(t["v0"]) + int(t["nv"])) * 3))
		var cols: PackedColorArray = t["cols"]
		var ini: int = runs[k * 3 + 1] - int(t["v0"])
		var cant: int = runs[k * 3 + 2]
		if propio:
			var base: int = runs[k * 3 + 1] * 3
			for j in cant:
				var q := base + j * 3
				cols[ini + j] = Color(cp[q] / 255.0, cp[q + 1] / 255.0, cp[q + 2] / 255.0, 1.0)
		else:
			for j in cant:
				cols[ini + j] = col_n
		t["cols"] = cols
		tocadas[ti] = true


func _reconstruir_tesela(ti: int) -> void:
	var t: Dictionary = teselas[ti]
	var v0: int = t["v0"]
	var nv: int = t["nv"]
	var i0: int = t["i0"]
	var ni: int = t["ni"]
	var verts: PackedVector2Array = main._a_vec2(vb.slice(v0 * 8, (v0 + nv) * 8))
	var idx: PackedInt32Array = ib.slice(i0 * 4, (i0 + ni) * 4).to_int32_array()
	var malla: ArrayMesh = main._crear_malla(verts, idx, t["cols"])
	for mi in t["inst"]:
		mi.mesh = malla


# ── Aristas ─────────────────────────────────────────────────────────────────────────────────────────────────────
## Malla con las aristas de los pares que cumplen `modo`:
##   "frontera": dueños distintos.   "propio": los dos lados son de `pais_id` (líneas de provincia de ese país).
## Pares de celdas que son FRONTERA (distinto dueño), en orden. Se mantienen entre llamadas: solo se reexaminan los pares de las celdas de las provincias cuyo
## dueño cambió desde la última vez (una conquista toca ~10 provincias, no todos los pares). La primera llamada, un reparto de otro tamaño o un cambio de forma
## de provincias (`mover_celdas`) calculan todos.
var _fr_dueno := PackedInt32Array()             # reparto con el que se calculó `_fr_set`
var _fr_set := {}                               # par -> true si es frontera
var _fr_lista := PackedInt32Array()             # esos pares ordenados (se rehace solo si cambió algo)
var _fr_sucio := true                           # una celda cambió de provincia: hay que recalcular todo

func _pares_frontera(dueno: PackedInt32Array) -> PackedInt32Array:
	if _fr_dueno == dueno and not _fr_sucio:
		return _fr_lista                                           # comparación nativa: nada cambió
	if _fr_dueno.size() != dueno.size() or _fr_sucio:
		_fr_set.clear()
		for k in n_pares:
			if dueno[par_pa[k]] != dueno[par_pb[k]]:
				_fr_set[k] = true
		_fr_sucio = false
	else:
		for p in dueno.size():
			if dueno[p] == _fr_dueno[p]:
				continue
			for c in (prov_celdas[p] as PackedInt32Array):
				for j in range(pp_ini[c], pp_ini[c + 1]):
					var k2: int = pp[j]
					if dueno[par_pa[k2]] != dueno[par_pb[k2]]:
						_fr_set[k2] = true
					else:
						_fr_set.erase(k2)
	_fr_dueno = dueno
	var claves: Array = _fr_set.keys()
	claves.sort()
	_fr_lista = PackedInt32Array(claves)
	return _fr_lista


## Pares (en orden) que cumplen el modo «propio», «internas» o «conjunto» (casi todos los pares entran: se recorren todos).
## Un par entre dos celdas de la MISMA provincia nunca es una línea.
func _pares_de_modo(dueno: PackedInt32Array, modo: String, pais_id: int, conj: Dictionary) -> PackedInt32Array:
	if modo == "frontera":
		return _pares_frontera(dueno)
	var r := PackedInt32Array()
	for k in n_pares:
		var pa: int = par_pa[k]
		var pb: int = par_pb[k]
		if pa == pb:
			continue
		var da: int = dueno[pa]
		var db: int = dueno[pb]
		if modo == "internas":
			if da == db and da != pais_id:
				r.append(k)
		elif modo == "conjunto":
			if da == db and conj.has(da):
				r.append(k)
		elif da == pais_id and db == pais_id:
			r.append(k)
	return r


## Modos: "frontera" (pares de distinto dueño), "propio" (ambos del país `pais_id`), "internas" (ambos del mismo dueño, salvo `pais_id`,
## que aquí es el dueño a excluir: lo que no existe en la campaña) y "conjunto" (ambos del mismo dueño y ese dueño está en `conj`).
func malla_aristas(dueno: PackedInt32Array, modo: String, pais_id := -1, conj := {}) -> ArrayMesh:
	var t0 := Time.get_ticks_usec()
	var v := PackedVector2Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var con_col := par_c.size() > 0
	var nseg := 0
	var k0 := -1                                   # pares consecutivos seleccionados se copian de una sola vez
	var s_ini := 0
	var s_fin := 0
	for k in _pares_de_modo(dueno, modo, pais_id, conj):
		var s0: int = par_tab[k * 4 + 2]
		var sn: int = par_tab[k * 4 + 3]
		if k0 >= 0 and s0 == s_fin:
			s_fin = s0 + sn
		else:
			if k0 >= 0:
				v.append_array(par_v.slice(s_ini * 4, s_fin * 4))
				uv.append_array(par_uv.slice(s_ini * 4, s_fin * 4))
				if con_col:
					col.append_array(par_c.slice(s_ini * 4, s_fin * 4))
			s_ini = s0
			s_fin = s0 + sn
		k0 = k
		nseg += sn
	if k0 >= 0:
		v.append_array(par_v.slice(s_ini * 4, s_fin * 4))
		uv.append_array(par_uv.slice(s_ini * 4, s_fin * 4))
		if con_col:
			col.append_array(par_c.slice(s_ini * 4, s_fin * 4))
	ms_frontera = float(Time.get_ticks_usec() - t0) / 1000.0
	if nseg == 0:
		return null
	return main._crear_malla(v, par_i.slice(0, nseg * 6), col, uv)


## Dueños que tocan por tierra al dueño `id` (los países vecinos de hoy). Excluye `vacio` (lo que no existe en la campaña).
func vecinos_de(dueno: PackedInt32Array, id: int, vacio: int) -> Dictionary:
	var r := {}
	for p in dueno.size():
		if dueno[p] != id:
			continue
		for c in (prov_celdas[p] as PackedInt32Array):
			for j in range(pp_ini[c], pp_ini[c + 1]):
				var k: int = pp[j]
				var q: int = par_pa[k] + par_pb[k] - p               # la provincia del otro lado (si es la misma, q == p: dueño igual, no cuenta)
				var o: int = dueno[q]
				if o != id and o != vacio:
					r[o] = true
	return r


## Componentes conexas (por tierra) de las provincias cuyo dueño está en `ids`: etiqueta por provincia (el mismo número = mismo bloque contiguo del mismo
## dueño) o -1 si su dueño no está en `ids`. Recorre solo las provincias de esos dueños y sus vecinas, no todos los pares.
func componentes(dueno: PackedInt32Array, ids: Dictionary) -> PackedInt32Array:
	_asegurar_prv()
	var n := dueno.size()
	var comp := PackedInt32Array()
	comp.resize(n)
	comp.fill(-1)
	var sig := 0
	var pila := PackedInt32Array()
	for p0 in n:
		if comp[p0] >= 0 or not ids.has(dueno[p0]):
			continue
		var o: int = dueno[p0]
		comp[p0] = sig
		pila.append(p0)
		while not pila.is_empty():
			var p: int = pila[pila.size() - 1]
			pila.resize(pila.size() - 1)
			for j in range(_prv_ini[p], _prv_ini[p + 1]):
				var q: int = _prv[j]
				if comp[q] < 0 and dueno[q] == o:
					comp[q] = sig
					pila.append(q)
		sig += 1
	return comp
