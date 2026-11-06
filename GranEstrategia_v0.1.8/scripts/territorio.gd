extends RefCounted
## Territorio (0.1.8.35): la FORMA de las provincias.
##
## El mundo está cortado en celdas (cada anillo de `anillos` es una celda, ver scripts/fusion_mapa.gd) y una provincia es un grupo de celdas. Esta clase es
## el único sitio que cambia ese reparto: todo lo que depende de él (el dibujo, las fronteras, el clic, las cajas, los centros, los nombres) se entera por aquí.
##
##   · Consultas:  provincia_de(celda), celdas_de(provincia), celda_en(punto), area_celda / area_provincia, centro_provincia, provincias_vecinas, celdas_frontera.
##   · Cambios:    reasignar(celdas, provincia), fusionar(a, b), ceder(origen, destino, n), dividir(provincia, destino, fracción), deshacer(), restablecer().
##   · Aviso:      la señal `forma_cambiada(provincias)` sale tras cada cambio (la economía, la población o lo que venga después pueden engancharse ahí).
##
## Un cambio es barato: se actualizan unas tablas, las celdas movidas se repintan y las fronteras se rehacen desde las mismas aristas (no hay mallas que
## regenerar). Lo que NO hace (todavía): mover población, edificios ni tropas con las celdas, ni crear provincias nuevas (los datos de cada provincia
## siguen siendo los de siempre; quien decida la regla de juego lo hace desde la señal).

signal forma_cambiada(provincias: PackedInt32Array)

const HISTORIAL_MAX := 60

var main                                         # MapaPrincipal
var fusion                                       # FusionScript (tablas de celdas y pares)
var _historial: Array = []                       # para deshacer: [{"celdas": PackedInt32Array, "antes": PackedInt32Array}]
var _base := PackedInt32Array()                  # el reparto de la época (para restablecer)
var _area_c := PackedFloat32Array()              # área de cada celda en px² (se calcula bajo demanda; -1 = pendiente)
var _tri_c := PackedInt32Array()                 # por celda: índice de su triángulo más grande (para el punto interior); -1 = pendiente
var ultimo_cambio_ms := 0.0                      # lo que costó el último cambio (para las pruebas de rendimiento)


func iniciar(p_main) -> void:
	main = p_main
	fusion = main.fusion
	_historial.clear()
	_base = fusion.celda_prov.duplicate() if fusion != null else PackedInt32Array()
	_area_c = PackedFloat32Array()
	_tri_c = PackedInt32Array()


func listo() -> bool:
	return fusion != null and fusion.listo and main != null and main.mundo != null


# ── Consultas ───────────────────────────────────────────────────────────────────────────────────────────────────
func n_celdas() -> int:
	return fusion.n_celdas


func provincia_de(celda: int) -> int:
	return fusion.celda_prov[celda]


func celdas_de(prov: int) -> PackedInt32Array:
	return fusion.prov_celdas[prov]


## Celda que hay bajo el punto `p` del mapa (coordenadas del mapa, 0..2400 en x), o -1 si es mar.
func celda_en(p: Vector2) -> int:
	return main._anillo_en(Vector2(fposmod(p.x, main.ANCHO_MAPA), p.y))


func provincias_vecinas(prov: int) -> PackedInt32Array:
	return fusion.provincias_vecinas(prov)


## Celdas de `origen` que tocan alguna celda de `destino`.
func celdas_frontera(origen: int, destino: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	for c in fusion.prov_celdas[origen]:
		for j in range(fusion.pp_ini[c], fusion.pp_ini[c + 1]):
			var k: int = fusion.pp[j]
			var o: int = fusion.par_a[k] + fusion.par_b[k] - c
			if fusion.celda_prov[o] == destino:
				r.append(c)
				break
	return r


func _asegurar_areas() -> void:
	if _area_c.size() == fusion.n_celdas:
		return
	main._asegurar_fill()
	_area_c.resize(fusion.n_celdas)
	_area_c.fill(-1.0)
	_tri_c.resize(fusion.n_celdas)
	_tri_c.fill(-1)


## Área de la celda en px² del mapa.
func area_celda(c: int) -> float:
	_asegurar_areas()
	if _area_c[c] >= 0.0:
		return _area_c[c]
	var a: Dictionary = main.anillos[c]
	var v0 := int(a["v0"])
	var i0 := int(a["i0"])
	var i1 := int(a["i1"])
	var total := 0.0
	var mejor := -1.0
	var mejor_i := i0
	var vs: PackedVector2Array = main.vertices_fill
	var ix: PackedInt32Array = main.indices_fill
	var i := i0
	while i + 3 <= i1:
		var p0 := vs[ix[i]]
		var p1 := vs[ix[i + 1]]
		var p2 := vs[ix[i + 2]]
		var ar := absf((p1 - p0).cross(p2 - p0)) * 0.5
		total += ar
		if ar > mejor:
			mejor = ar
			mejor_i = i
		i += 3
	_area_c[c] = total
	_tri_c[c] = mejor_i
	return total


## Un punto que está DENTRO de la celda (el centro de su triángulo más grande).
func centro_celda(c: int) -> Vector2:
	area_celda(c)
	var ix: PackedInt32Array = main.indices_fill
	var vs: PackedVector2Array = main.vertices_fill
	var i: int = _tri_c[c]
	if i < 0:
		var bb: Array = main.anillos[c]["b"]
		return Vector2(float(bb[0]) + float(bb[2]) * 0.5, float(bb[1]) + float(bb[3]) * 0.5)
	return (vs[ix[i]] + vs[ix[i + 1]] + vs[ix[i + 2]]) / 3.0


## ¿El punto `p` (coordenadas del mapa) cae dentro de alguna celda de la provincia?
func contiene(prov: int, p: Vector2) -> bool:
	main._asegurar_fill()
	var q := Vector2(fposmod(p.x, main.ANCHO_MAPA), p.y)
	for c in fusion.prov_celdas[prov]:
		var b: Array = main.anillos[c]["b"]
		if q.x < b[0] or q.x > b[0] + b[2] or q.y < b[1] or q.y > b[1] + b[3]:
			continue
		if Geometry2D.is_point_in_polygon(q, main._puntos_anillo(main.anillos[c])):
			return true
	return false


func area_provincia(prov: int) -> float:
	var t := 0.0
	for c in fusion.prov_celdas[prov]:
		t += area_celda(c)
	return t


## Un punto dentro de la provincia: el centro de su celda más grande (ahí se dibujan sus tropas). Si no tiene celdas, `defecto`.
func centro_provincia(prov: int, defecto := Vector2.ZERO) -> Vector2:
	var mejor := -1
	var mejor_a := -1.0
	for c in fusion.prov_celdas[prov]:
		var a := area_celda(c)
		if a > mejor_a:
			mejor_a = a
			mejor = c
	return centro_celda(mejor) if mejor >= 0 else defecto


# ── Cambios ─────────────────────────────────────────────────────────────────────────────────────────────────────
## Pasa `celdas` a la provincia `destino`. Devuelve cuántas celdas cambiaron de provincia. Con `guardar` el cambio entra en el historial (deshacer).
func reasignar(celdas: PackedInt32Array, destino: int, guardar := true) -> int:
	if not listo() or destino < 0 or destino >= fusion.prov_celdas.size():
		return 0
	var t0 := Time.get_ticks_usec()
	var mover := PackedInt32Array()
	var antes := PackedInt32Array()
	var afectadas := {destino: true}
	for c in celdas:
		if c < 0 or c >= fusion.n_celdas:
			continue
		var vieja: int = fusion.celda_prov[c]
		if vieja == destino or mover.has(c):
			continue
		mover.append(c)
		antes.append(vieja)
		afectadas[vieja] = true
	if mover.is_empty():
		return 0
	fusion.mover_celdas(mover, destino)
	for c in mover:
		main.anillos[c]["p"] = destino
	if guardar:
		_historial.append({"celdas": mover, "antes": antes})
		if _historial.size() > HISTORIAL_MAX:
			_historial.pop_front()
	_avisar(afectadas.keys())
	ultimo_cambio_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	return mover.size()


## Todas las celdas de `b` pasan a `a` (b se queda sin territorio). Devuelve las celdas movidas.
func fusionar(a: int, b: int) -> int:
	if a == b or b < 0 or b >= fusion.prov_celdas.size():
		return 0
	return reasignar(fusion.prov_celdas[b].duplicate(), a)


## Mueve la frontera: pasa a `destino` las `n` celdas de `origen` que están más cerca de él (crece por capas desde la frontera común).
## Deja siempre al menos una celda en `origen`. Devuelve las celdas movidas.
func ceder(origen: int, destino: int, n: int) -> int:
	if origen == destino or n <= 0:
		return 0
	var mias: PackedInt32Array = fusion.prov_celdas[origen]
	var tope := mini(n, mias.size() - 1)
	if tope <= 0:
		return 0
	var elegidas := _crecer(celdas_frontera(origen, destino), origen, tope)
	return reasignar(elegidas, destino)


## Divide `prov`: la fracción `fraccion` de sus celdas pasa a `destino`. Si `destino` es vecina, es mover la frontera hacia dentro (`ceder`); si no tiene
## celdas (provincia vacía), el trozo nace en el extremo de `prov` más lejano de su primera celda y crece por capas hasta la fracción pedida.
func dividir(prov: int, destino: int, fraccion := 0.5) -> int:
	var mias: PackedInt32Array = fusion.prov_celdas[prov]
	var n := int(roundf(mias.size() * clampf(fraccion, 0.0, 1.0)))
	n = mini(n, mias.size() - 1)
	if n <= 0:
		return 0
	if not (fusion.prov_celdas[destino] as PackedInt32Array).is_empty() and celdas_frontera(prov, destino).size() > 0:
		return ceder(prov, destino, n)
	var semilla := _extremo(mias)
	return reasignar(_crecer(PackedInt32Array([semilla]), prov, n), destino)


## Crece por capas (anchura primero) desde `semillas` dentro de las celdas de `prov` hasta reunir `n` celdas. Las semillas van primero.
func _crecer(semillas: PackedInt32Array, prov: int, n: int) -> PackedInt32Array:
	var elegidas := PackedInt32Array()
	var visto := {}
	var cola := PackedInt32Array()
	for s in semillas:
		if not visto.has(s) and fusion.celda_prov[s] == prov:
			visto[s] = true
			cola.append(s)
	var cabeza := 0
	while cabeza < cola.size() and elegidas.size() < n:
		var c: int = cola[cabeza]
		cabeza += 1
		elegidas.append(c)
		for o in fusion.celdas_vecinas(c):
			if not visto.has(o) and fusion.celda_prov[o] == prov:
				visto[o] = true
				cola.append(o)
	if elegidas.size() < n:                                  # celdas de `prov` sueltas (islas): se completan con las que falten
		for c2 in fusion.prov_celdas[prov]:
			if elegidas.size() >= n:
				break
			if not visto.has(c2):
				visto[c2] = true
				elegidas.append(c2)
	return elegidas


## La celda de `celdas` más lejana de la primera (aproximación del «extremo» de una provincia).
func _extremo(celdas: PackedInt32Array) -> int:
	var c0 := centro_celda(celdas[0])
	var mejor: int = celdas[0]
	var mejor_d := -1.0
	for c in celdas:
		var d := centro_celda(c).distance_squared_to(c0)
		if d > mejor_d:
			mejor_d = d
			mejor = c
	return mejor


## Deshace el último cambio. Devuelve false si no hay nada que deshacer.
func deshacer() -> bool:
	if _historial.is_empty():
		return false
	var h: Dictionary = _historial.pop_back()
	var celdas: PackedInt32Array = h["celdas"]
	var antes: PackedInt32Array = h["antes"]
	var afectadas := {}
	for i in celdas.size():
		var c: int = celdas[i]
		afectadas[fusion.celda_prov[c]] = true
		afectadas[antes[i]] = true
		fusion.mover_celdas(PackedInt32Array([c]), antes[i])
		main.anillos[c]["p"] = antes[i]
	_avisar(afectadas.keys())
	return true


func puede_deshacer() -> bool:
	return not _historial.is_empty()


## Vuelve al reparto con el que empezó la época. Devuelve cuántas celdas cambiaron.
func restablecer() -> int:
	var n := 0
	var por_destino := {}
	for c in fusion.n_celdas:
		if fusion.celda_prov[c] != _base[c]:
			var l: PackedInt32Array = por_destino.get(_base[c], PackedInt32Array())
			l.append(c)
			por_destino[_base[c]] = l
	for d in por_destino:
		n += reasignar(por_destino[d], int(d), false)
	_historial.clear()
	return n


## ¿Se ha cambiado la forma de alguna provincia respecto a la época?
func modificado() -> bool:
	return fusion != null and fusion.celda_prov != _base


# ── Avisos ──────────────────────────────────────────────────────────────────────────────────────────────────────
## Pone al día todo lo que depende de la geometría de las provincias `provs` y avisa.
func _avisar(provs: Array) -> void:
	var lista := PackedInt32Array()
	for p in provs:
		lista.append(int(p))
		var l: PackedInt32Array = fusion.prov_celdas[int(p)]
		l.sort()                                              # los anillos van de mayor a menor área, y el índice de la celda ES su posición en esa lista
		fusion.prov_celdas[int(p)] = l
		main.mundo.provincias[int(p)].anillos = Array(l)
	main._territorio_cambio(lista)
	forma_cambiada.emit(lista)
