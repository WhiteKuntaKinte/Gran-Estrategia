extends RefCounted
## EDIFICIOS por provincia (0.1.8.40).
##
## El catálogo (datos/edificios.json, 109 edificios = los descubrimientos de tipo B) lo genera herramientas/construir_edificios.py.
## Un país puede construir un edificio cuando CONOCE su descubrimiento (`Descubrimientos.conoce`, o sea, según la fecha del reloj).
## Construir cuesta dinero (la divisa del dueño) y tarda días; el edificio se guarda POR PROVINCIA en la base de datos:
##   · `edificios` (texto, provincia)  «slug:cantidad;slug:cantidad»          lo ya construido.
##   · `obras` (texto, provincia)      «slug@día_inicio@día_fin@pago_usd;...» lo que está en obra (los días son del reloj propio `dia_n`).
##   · `num_edificios` (número, provincia)  cuántos hay construidos (se suma hacia país, estado y continente).
## SIN EFECTOS de juego todavía (decisión de diseño): los edificios solo existen, se cuentan y se muestran; el resto del juego los ignora.
##
## Costo = fracción de la producción anual de la provincia según la CLASE de obra (A..F), con un piso por habitante (así vale igual en el año 1
## que en 2026). Días de obra = los de la clase. Cancelar una obra devuelve REEMBOLSO_CANCELAR del pago.

const FRAC_PISO_HAB := 20000.0           # el costo base nunca baja de lo que produciría esta cantidad de habitantes con el producto medio del país
const REEMBOLSO_CANCELAR := 0.5
const SIN_FIN := 4611686018427387904     # (1 << 62): no hay ninguna obra pendiente

var mundo
var bd
var listo := false
var n := 0
var slug := PackedStringArray()
var nombre := PackedStringArray()
var cat := PackedStringArray()
var clase := PackedStringArray()
var tope := PackedInt32Array()           # máximo por provincia (construidos + en obra)
var era := PackedInt32Array()
var anio := PackedInt32Array()
var seccion := PackedStringArray()
var desc := PackedStringArray()
var desc_idx := PackedInt32Array()       # índice del descubrimiento que lo habilita (-1 = no hay)
var idx_de_slug := {}
var categorias: Array = []               # [{cod, nombre, icono}]
var clases := {}                         # clase -> {nombre, fraccion, dias}

var dia_n := 0                           # días de juego pasados (reloj de las obras)
var terminadas := 0                      # obras terminadas desde que empezó la partida (para pruebas y Debug)
var version := 0                         # sube con cualquier cambio de edificios u obras (la interfaz sabe si debe redibujar)
var _obras := {}                         # índice de provincia -> Array de [e, ini, fin, pago_usd]
var _prox_fin := SIN_FIN
var _cache := {}                         # tid de provincia -> [texto, Dictionary slug->cantidad]
var _pc_cache := {}                      # país -> [versión económica de la base, producción anual por habitante en US$]


## Carga el catálogo (datos/edificios.json). Devuelve false si falta o está mal.
func cargar(js: Dictionary) -> bool:
	var lista: Array = js.get("edificios", [])
	if lista.is_empty():
		return false
	categorias = js.get("categorias", [])
	clases = js.get("clases", {})
	n = lista.size()
	for e in lista:
		slug.append(String(e["slug"]))
		nombre.append(String(e["nombre"]))
		cat.append(String(e["cat"]))
		clase.append(String(e["clase"]))
		tope.append(int(e.get("max", 1)))
		era.append(int(e.get("era", 0)))
		anio.append(int(e.get("anio", 0)))
		seccion.append(String(e.get("seccion", "")))
		desc.append(String(e.get("desc", "")))
		idx_de_slug[slug[slug.size() - 1]] = slug.size() - 1
	listo = true
	return true


## Se llama al empezar la partida, con el Mundo ya armado (base de datos, países, descubrimientos).
func iniciar(m) -> void:
	mundo = m
	bd = m.bd
	desc_idx.resize(n)
	for i in n:
		desc_idx[i] = m.descubrimientos.indice(slug[i]) if m.descubrimientos != null else -1
	dia_n = 0
	terminadas = 0
	_obras.clear()
	_cache.clear()
	_prox_fin = SIN_FIN
	for pr in m.provincias:                                  # obras que ya trajera la base (por ejemplo, de Debug o de una época con datos propios)
		var t: String = bd.txt("obras", pr.tid, "")
		if t != "":
			_obras[pr.idx] = _leer_obras(t)
	_recalcular_prox()


func indice(sl: String) -> int:
	return int(idx_de_slug.get(sl, -1))


func categoria_de(e: int) -> Dictionary:
	for c in categorias:
		if String(c["cod"]) == cat[e]:
			return c
	return {}


func nombre_clase(e: int) -> String:
	return String(clases.get(clase[e], {}).get("nombre", clase[e]))


# ───────────── lo construido ─────────────
## Lo construido en la provincia `pi` (índice en Mundo.provincias): {slug: cantidad}. No se debe modificar.
func de_provincia(pi: int) -> Dictionary:
	var tid: int = mundo.provincias[pi].tid
	var t: String = bd.txt("edificios", tid, "")
	var c = _cache.get(tid)
	if c != null and String(c[0]) == t:
		return c[1]
	var d := {}
	if t != "":
		for par in t.split(";", false):
			var p := par.split(":")
			if p.size() == 2 and idx_de_slug.has(p[0]):
				d[p[0]] = int(p[1])
	_cache[tid] = [t, d]
	return d


func cantidad(pi: int, e: int) -> int:
	return int(de_provincia(pi).get(slug[e], 0))


func num_edificios(pi: int) -> int:
	return int(bd.num("num_edificios", mundo.provincias[pi].tid, 0.0))


func _guardar(pi: int, d: Dictionary, motivo := "") -> void:
	var tid: int = mundo.provincias[pi].tid
	var claves := d.keys()
	claves.sort_custom(func(a, b): return int(idx_de_slug[a]) < int(idx_de_slug[b]))
	var t := ""
	var total := 0
	for k in claves:
		if int(d[k]) > 0:
			t += ("" if t == "" else ";") + "%s:%d" % [k, int(d[k])]
			total += int(d[k])
	bd.poner_s("edificios", tid, t, motivo)
	bd.poner_f("num_edificios", tid, float(total))
	_cache[tid] = [t, d]
	version += 1


## Pone edificios ya terminados (Debug, pruebas, épocas con datos propios). No cobra nada.
func dar(pi: int, e: int, cant := 1) -> void:
	var d: Dictionary = de_provincia(pi).duplicate()
	d[slug[e]] = maxi(int(d.get(slug[e], 0)) + cant, 0)
	_guardar(pi, d, "Debug: edificio añadido" if cant > 0 else "Debug: edificio quitado")


func quitar(pi: int, e: int, cant := 1) -> void:
	dar(pi, e, -cant)


# ───────────── obras ─────────────
func _leer_obras(t: String) -> Array:
	var r := []
	for par in t.split(";", false):
		var p := par.split("@")
		if p.size() >= 3 and idx_de_slug.has(p[0]):
			r.append([int(idx_de_slug[p[0]]), int(p[1]), int(p[2]), float(p[3]) if p.size() > 3 else 0.0])
	return r


func _escribir_obras(pi: int) -> void:
	var tid: int = mundo.provincias[pi].tid
	var lista: Array = _obras.get(pi, [])
	var t := ""
	for o in lista:
		t += ("" if t == "" else ";") + "%s@%d@%d@%d" % [slug[int(o[0])], int(o[1]), int(o[2]), int(round(float(o[3])))]
	bd.poner_s("obras", tid, t)
	if lista.is_empty():
		_obras.erase(pi)
	else:
		_obras[pi] = lista
	_recalcular_prox()
	version += 1


func _recalcular_prox() -> void:
	_prox_fin = SIN_FIN
	for pi in _obras:
		for o in _obras[pi]:
			_prox_fin = mini(_prox_fin, int(o[2]))


## Obras de la provincia: [{e, ini, fin, falta, pct, pago}] (falta = días que faltan; pct = avance 0-100).
func obras_de(pi: int) -> Array:
	var r := []
	for o in _obras.get(pi, []):
		var total := maxi(int(o[2]) - int(o[1]), 1)
		var falta := maxi(int(o[2]) - dia_n, 0)
		r.append({"e": int(o[0]), "ini": int(o[1]), "fin": int(o[2]), "falta": falta, "pct": clampf(100.0 * float(total - falta) / float(total), 0.0, 100.0),
			"pago": float(o[3])})
	return r


func en_obra(pi: int, e: int) -> int:
	var c := 0
	for o in _obras.get(pi, []):
		if int(o[0]) == e:
			c += 1
	return c


func provincias_en_obra() -> int:
	return _obras.size()


# ───────────── costo, días y reglas ─────────────
func dias_de(e: int) -> int:
	return int(clases.get(clase[e], {}).get("dias", 30))


func _prod_base_usd(pi: int) -> float:
	var pr = mundo.provincias[pi]
	return maxf(pr.ingreso_anual_usd(), _prod_por_hab(pr.pais) * FRAC_PISO_HAB)


## Producción anual por habitante del país (US$), guardada hasta que cambie la economía de la base (recorrer sus provincias en cada consulta era O(n²) en las órdenes de grupo).
func _prod_por_hab(pais: String) -> float:
	var c = _pc_cache.get(pais)
	if c != null and int(c[0]) == bd.version_eco:
		return float(c[1])
	var pc := 0.0
	if mundo.paises.has(pais):
		pc = mundo.produccion_anual_usd(pais) / maxf(mundo.poblacion_de(pais), 1.0)
	_pc_cache[pais] = [bd.version_eco, pc]
	return pc


## Costo en US$ de construir `e` en la provincia `pi`.
func costo_usd(pi: int, e: int) -> float:
	return float(clases.get(clase[e], {}).get("fraccion", 0.01)) * _prod_base_usd(pi)


## Costo en la divisa del dueño de la provincia.
func costo_local(pi: int, e: int) -> float:
	return costo_usd(pi, e) * _por_usd(mundo.provincias[pi].pais)


func _por_usd(pais: String) -> float:
	var d = mundo.divisa_de(pais)
	return d.por_usd if d != null else 1.0


## ¿El país conoce el descubrimiento de este edificio?
func conoce(pais: String, e: int) -> bool:
	if mundo.descubrimientos == null or not mundo.paises.has(pais) or desc_idx[e] < 0:
		return false
	return mundo.descubrimientos.conoce(int(mundo.paises[pais].tid), desc_idx[e])


## Edificios que el país puede construir ya (por fecha o por Debug), como índices del catálogo en orden de año.
func conocidos(pais: String) -> PackedInt32Array:
	var r := PackedInt32Array()
	for e in n:
		if conoce(pais, e):
			r.append(e)
	return r


## ¿Puede `pais` construir `e` en la provincia `pi`? {"ok": bool, "motivo": String}. El motivo sale aunque no sea posible, para mostrarlo en la interfaz.
func puede(pais: String, pi: int, e: int) -> Dictionary:
	if not listo or e < 0 or e >= n or pi < 0 or pi >= mundo.provincias.size():
		return {"ok": false, "motivo": "No existe."}
	var pr = mundo.provincias[pi]
	if not mundo.paises.has(pais) or mundo.paises[pais].inerte:
		return {"ok": false, "motivo": "Ese país no puede construir."}
	if pr.pais != pais:
		return {"ok": false, "motivo": "La provincia no es tuya."}
	if pr.ocupante >= 0:
		return {"ok": false, "motivo": "Está ocupada por un enemigo."}
	if not conoce(pais, e):
		return {"ok": false, "motivo": "Todavía no conoces «%s»." % nombre[e]}
	if cantidad(pi, e) + en_obra(pi, e) >= tope[e]:
		return {"ok": false, "motivo": ("Ya está construido." if tope[e] == 1 else "Ya tiene el máximo (%d) en esta provincia." % tope[e])
			if cantidad(pi, e) >= tope[e] else "Ya hay una obra de este tipo en curso."}
	var costo := costo_local(pi, e)
	var p = mundo.paises[pais]
	if costo > 0.0 and p.tiene_tesoreria() and p.tesoreria < costo:
		return {"ok": false, "motivo": "No alcanza la tesorería."}
	return {"ok": true, "motivo": ""}


## Empieza la obra pagando de la tesorería. Devuelve {"ok", "msg", "costo"} (costo en la divisa del país).
func construir(pais: String, pi: int, e: int) -> Dictionary:
	var r := puede(pais, pi, e)
	if not bool(r["ok"]):
		return {"ok": false, "msg": String(r["motivo"]), "costo": 0.0}
	var costo_u := costo_usd(pi, e)
	var costo_l := costo_u * _por_usd(pais)
	var p = mundo.paises[pais]
	if p.tiene_tesoreria():
		p.tesoreria = p.tesoreria - costo_l
	var lista: Array = _obras.get(pi, [])
	lista.append([e, dia_n, dia_n + dias_de(e), costo_u])
	_obras[pi] = lista
	_escribir_obras(pi)
	return {"ok": true, "msg": "Obra empezada: %s (%d días)." % [nombre[e], dias_de(e)], "costo": costo_l}


## La misma obra en varias provincias (órdenes de grupo). Para al quedarse sin dinero.
## Devuelve {"hechas": n, "costo": total (divisa), "fallos": [{pi, motivo}]}.
func construir_varias(pais: String, pis: Array, e: int) -> Dictionary:
	var hechas := 0
	var total := 0.0
	var fallos := []
	for pi in pis:
		var r := construir(pais, int(pi), e)
		if bool(r["ok"]):
			hechas += 1
			total += float(r["costo"])
		else:
			fallos.append({"pi": int(pi), "motivo": String(r["msg"])})
	return {"hechas": hechas, "costo": total, "fallos": fallos}


## Cancela la obra número `i` de la provincia y devuelve la mitad de lo pagado. {"ok", "msg", "reembolso"}.
func cancelar(pi: int, i: int) -> Dictionary:
	var lista: Array = _obras.get(pi, [])
	if i < 0 or i >= lista.size():
		return {"ok": false, "msg": "Esa obra ya no existe.", "reembolso": 0.0}
	var o: Array = lista[i]
	var pais: String = mundo.provincias[pi].pais
	var ree_u := float(o[3]) * REEMBOLSO_CANCELAR
	var ree_l := ree_u * _por_usd(pais)
	if mundo.paises.has(pais) and mundo.paises[pais].tiene_tesoreria():
		mundo.paises[pais].tesoreria = mundo.paises[pais].tesoreria + ree_l
	lista.remove_at(i)
	_obras[pi] = lista
	_escribir_obras(pi)
	return {"ok": true, "msg": "Obra cancelada: %s." % nombre[int(o[0])], "reembolso": ree_l}


## Quita la obra número `i` sin devolver nada (Debug).
func cancelar_sin_reembolso(pi: int, i: int) -> bool:
	var lista: Array = _obras.get(pi, [])
	if i < 0 or i >= lista.size():
		return false
	lista.remove_at(i)
	_obras[pi] = lista
	_escribir_obras(pi)
	return true


## La provincia cambió de dueño: las obras en curso se pierden (el dinero ya se gastó, no hay reembolso); lo construido se queda con la tierra.
## `antes` = el país que la perdía. Devuelve cuántas obras se perdieron.
func cambio_de_dueno(pi: int, antes: String) -> int:
	var lista: Array = _obras.get(pi, [])
	var c := lista.size()
	if c == 0:
		return 0
	_obras.erase(pi)
	_escribir_obras(pi)
	if mundo.paises.has(antes):
		mundo.evento(int(mundo.paises[antes].tid), "Obras perdidas en %s (%d): la provincia cambió de dueño." % [mundo.provincias[pi].nombre, c])
	return c


## Fase del día del Mundo (`Mundo.fases_dias`): `k` días de obra. Casi siempre no hace nada (una sola comparación).
func fase_obras(k: int) -> bool:
	dia_n += k
	if dia_n < _prox_fin:
		return false
	_terminar_vencidas()
	return false


func _terminar_vencidas() -> void:
	var tocadas := []
	for pi in _obras:
		for o in _obras[pi]:
			if int(o[2]) <= dia_n:
				tocadas.append(pi)
				break
	for pi in tocadas:
		var lista: Array = _obras[pi]
		var quedan := []
		var d: Dictionary = de_provincia(pi).duplicate()
		var pais: String = mundo.provincias[pi].pais
		for o in lista:
			if int(o[2]) <= dia_n:
				d[slug[int(o[0])]] = int(d.get(slug[int(o[0])], 0)) + 1
				terminadas += 1
				if mundo.paises.has(pais):
					mundo.evento(int(mundo.paises[pais].tid), "Obra terminada: %s en %s." % [nombre[int(o[0])], mundo.provincias[pi].nombre])
			else:
				quedan.append(o)
		_guardar(pi, d, "Obra terminada")
		_obras[pi] = quedan
		_escribir_obras(pi)


## Termina de golpe todas las obras de una provincia (Debug). Devuelve cuántas terminó.
func completar_obras(pi: int) -> int:
	var lista: Array = _obras.get(pi, [])
	var c := lista.size()
	if c == 0:
		return 0
	for o in lista:
		o[2] = dia_n
	_prox_fin = dia_n
	_terminar_vencidas()
	return c


# ───────────── totales ─────────────
## Huella de lo que muestran las tarjetas de edificios para estas provincias: cambia cuando se construye o termina algo, y cada día mientras haya obras (el avance).
func firma(pis: Array) -> int:
	var en_obra := obras_en(pis)
	return hash([version, dia_n if en_obra > 0 else -1, en_obra, pis.size()])


## Cuántos edificios hay en las provincias del país (todas las que controla hoy).
func total_pais(pais: String) -> int:
	if not mundo.paises.has(pais):
		return 0
	return total_en(mundo.paises[pais].provincias)


## Cuántos edificios hay construidos en todo el mundo.
func total_mundo() -> int:
	var t := 0
	for v in bd.vars["num_edificios"].col_f:
		if not is_nan(v):
			t += int(v)
	return t


## {slug: cantidad} sumando varias provincias. Lee la columna de texto directo y salta las vacías (un país grande tiene miles de provincias).
func totales_de(pis: Array) -> Dictionary:
	var r := {}
	var col: PackedStringArray = bd.vars["edificios"].col_s
	for pi in pis:
		if col[mundo.provincias[int(pi)].ix] == "":
			continue
		var d: Dictionary = de_provincia(int(pi))
		for k in d:
			r[k] = int(r.get(k, 0)) + int(d[k])
	return r


func total_en(pis: Array) -> int:
	var col: PackedFloat64Array = bd.vars["num_edificios"].col_f
	var t := 0
	for pi in pis:
		var v: float = col[mundo.provincias[int(pi)].ix]
		if not is_nan(v):
			t += int(v)
	return t


func obras_en(pis: Array) -> int:
	var t := 0
	for pi in pis:
		t += (_obras.get(int(pi), []) as Array).size()
	return t
