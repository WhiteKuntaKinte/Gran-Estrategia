extends RefCounted
## Base de datos del juego (0.1.7.9.9D).
##
## ¿Qué guarda?
##  · TERRITORIOS: un ID único por mundo, continente, país, estado, provincia y ciudad (datos/ids.json), con su padre
##    en cadena: ciudad -> provincia -> estado -> país -> continente -> mundo. El padre es el GEOGRÁFICO original.
##    Además, las ENTIDADES POLÍTICAS HISTÓRICAS (datos/historico/entidades.json) entran con tipo "entidad" y sin padre:
##    pueden ser dueñas de provincias en otra época (la variable `propietario` guarda cualquier ID).
##  · VARIABLES (datos/variables.json): cada variable es una COLUMNA con UN solo valor actual por ID. Dos variables nunca
##    comparten ni pisan sus datos, y para ver qué vale una variable en un lugar basta su ID.
##  · HISTORIAL: tablas aparte (una por variable). Cuando el valor actual cambia, el valor anterior se archiva ahí con
##    sus fechas ("desde" - "hasta") y el motivo. La variable principal nunca acumula versiones viejas.
##
## Políticas de historial (campo `historial` del catálogo):
##   cambio  -> cada cambio archiva el valor anterior.        mensual / anual -> foto al cerrar el mes / el año.
##   ninguno -> sin historial (datos fijos).
##
## Fechas: enteros AAAAMMDD con año desplazado: (año + 100000) * 10000 + mes * 100 + día. Se ordenan como números.
## "Sin dato": NAN en números, "" en textos, -1 en IDs.

const TIPOS := ["mundo", "continente", "pais", "estado", "provincia", "ciudad", "entidad", "ejercito", "peloton", "regimiento", "guerra", "batalla"]
const T_MUNDO := 0
const T_CONTINENTE := 1
const T_PAIS := 2
const T_ESTADO := 3
const T_PROVINCIA := 4
const T_CIUDAD := 5
const T_ENTIDAD := 6                     # entidad política histórica (reino, imperio...), sin padre geográfico (datos/historico/)
const T_EJERCITO := 7                    # ejército de un país (padre = país). IDs desde 10.000.000; se crean al empezar la partida
const T_PELOTON := 8                     # pelotón de hasta 1.000 soldados (padre = ejército). IDs desde 11.000.000
const T_REGIMIENTO := 9                  # grupo de pelotones que se mueve y pelea junto (padre = ejército). IDs desde 12.000.000
const T_GUERRA := 10                     # guerra entre dos países (padre = país agresor). IDs desde 13.000.000
const T_BATALLA := 11                    # combate en una provincia durante una guerra (padre = su guerra). IDs desde 14.000.000


class Variable extends RefCounted:
	var id_var := 0
	var nombre := ""
	var etiqueta := ""
	var categoria := ""
	var tipo := "numero"                 # numero | texto | id
	var unidad := ""
	var aplica := PackedByteArray()      # 1 si la variable aplica a ese tipo de territorio (orden de TIPOS)
	var historial := "cambio"
	var agregacion := "ninguna"
	var descripcion := ""
	var col_f := PackedFloat64Array()    # valores (tipo numero)
	var col_s := PackedStringArray()     # valores (tipo texto)
	var col_i := PackedInt32Array()      # valores (tipo id)
	var desde := PackedInt32Array()      # fecha en que empezó el valor actual (0 = sin valor)
	var ultimo_cierre := 0               # fecha del último cierre periódico
	var afecta_economia := false         # si cambia, hay que recalcular los ingresos de los países


class Hist extends RefCounted:
	var h_id := PackedInt32Array()       # ID del territorio
	var h_desde := PackedInt32Array()
	var h_hasta := PackedInt32Array()
	var h_f := PackedFloat64Array()
	var h_s := PackedStringArray()
	var h_i := PackedInt32Array()
	var h_motivo := PackedStringArray()
	var por_id := {}                     # ID -> lista de filas (índice rápido: no hay que recorrer todo el historial)

	func cuenta() -> int:
		return h_id.size()

	## Añade el ID de una fila nueva al historial y la indexa. Los demás campos se añaden aparte, en el mismo orden.
	func registrar(id: int) -> void:
		h_id.append(id)
		var fila := h_id.size() - 1
		if not por_id.has(id):
			por_id[id] = []
		por_id[id].append(fila)


# ── territorios (columnas paralelas; el índice denso es la posición en estas listas) ──
var n := 0
var t_id := PackedInt32Array()
var t_tipo := PackedByteArray()
var t_nombre := PackedStringArray()
var t_padre := PackedInt32Array()
var t_clave := PackedStringArray()
var t_activo := PackedByteArray()
var idx_de_id := {}                      # ID -> índice denso
var id_de_clave := {}                    # "tipo|clave" -> ID
var hijos_de := {}                       # ID -> Array de IDs hijos

# ── variables e historial ──
var vars := {}                           # nombre -> Variable
var hist := {}                           # nombre -> Hist
var orden_vars: Array = []               # nombres en el orden del catálogo

# ── estado ──
var fecha := 0                           # fecha actual del juego (la actualiza MapaPrincipal)
var motivo_ctx := ""                     # motivo por defecto para los cambios (p. ej. "Debug", "Conquista")
var version := 0                         # sube con cada cambio de cualquier variable
var version_propietario := 0             # sube cuando cambia el dueño de CUALQUIER provincia (el mapa se repinta al notarlo)
var version_ocupacion := 0               # sube cuando cambia quién OCUPA cualquier provincia (el mapa repinta solo el relleno)
var version_eco := 0                     # sube solo con cambios de variables que afectan a los ingresos (caché de economía)


# ─────────────────────────────────────────────────────────────
# Fechas
# ─────────────────────────────────────────────────────────────
static func fecha_int(a: int, m: int, d: int) -> int:
	return (a + 100000) * 10000 + m * 100 + d


## El año de una fecha entera (a. C. en negativo): fecha_int(1066, 10, 14) -> 1066.
static func anio_de_fecha(f: int) -> int:
	return floori(f / 10000.0) - 100000


static func fecha_texto(f: int) -> String:
	if f <= 0:
		return "—"
	return "%d,%02d,%02d" % [floori(f / 10000.0) - 100000, floori(f / 100.0) % 100, f % 100]


# ─────────────────────────────────────────────────────────────
# Carga
# ─────────────────────────────────────────────────────────────
func cargar(ids: Dictionary, catalogo: Dictionary, extra: Array = []) -> void:
	var filas: Array = ids.get("territorios", [])
	if not extra.is_empty():                 # filas [id, tipo, nombre, padre, clave, activo] de las entidades históricas
		filas = filas + extra
	n = filas.size()
	t_id.resize(n)
	t_tipo.resize(n)
	t_nombre.resize(n)
	t_padre.resize(n)
	t_clave.resize(n)
	t_activo.resize(n)
	for i in n:
		var f: Array = filas[i]
		t_id[i] = int(f[0])
		t_tipo[i] = int(f[1])
		t_nombre[i] = String(f[2])
		t_padre[i] = int(f[3])
		t_clave[i] = String(f[4])
		t_activo[i] = int(f[5])
		idx_de_id[t_id[i]] = i
		id_de_clave["%s|%s" % [TIPOS[t_tipo[i]], t_clave[i]]] = t_id[i]
	for i in n:
		var p := t_padre[i]
		if p >= 0:
			if not hijos_de.has(p):
				hijos_de[p] = []
			hijos_de[p].append(t_id[i])
	for d in catalogo.get("variables", []):
		var v := Variable.new()
		v.id_var = int(d["id_var"])
		v.nombre = String(d["nombre"])
		v.etiqueta = String(d.get("etiqueta", v.nombre))
		v.categoria = String(d.get("categoria", ""))
		v.tipo = String(d.get("tipo", "numero"))
		v.unidad = String(d.get("unidad", ""))
		v.historial = String(d.get("historial", "cambio"))
		v.agregacion = String(d.get("agregacion", "ninguna"))
		v.descripcion = String(d.get("descripcion", ""))
		v.afecta_economia = bool(d.get("afecta_economia", false))
		v.aplica.resize(TIPOS.size())
		for t in d.get("aplica_a", []):
			var k := TIPOS.find(String(t))
			if k >= 0:
				v.aplica[k] = 1
		match v.tipo:
			"numero":
				v.col_f.resize(n)
				v.col_f.fill(NAN)
			"texto":
				v.col_s.resize(n)
			"id":
				v.col_i.resize(n)
				v.col_i.fill(-1)
		v.desde.resize(n)
		vars[v.nombre] = v
		hist[v.nombre] = Hist.new()
		orden_vars.append(v.nombre)


## Añade territorios NUEVOS con la partida ya en marcha (ejércitos y pelotones). Cada fila: [id, tipo, nombre, padre, clave, activo].
## Todas las columnas de todas las variables crecen y las celdas nuevas quedan «sin dato». Es barato en lote: mejor una llamada con
## muchas filas que muchas con una sola.
func anadir_territorios(filas: Array) -> void:
	var n0 := n
	var n1 := n0 + filas.size()
	t_id.resize(n1)
	t_tipo.resize(n1)
	t_nombre.resize(n1)
	t_padre.resize(n1)
	t_clave.resize(n1)
	t_activo.resize(n1)
	for j in filas.size():
		var f: Array = filas[j]
		var i := n0 + j
		t_id[i] = int(f[0])
		t_tipo[i] = int(f[1])
		t_nombre[i] = String(f[2])
		t_padre[i] = int(f[3])
		t_clave[i] = String(f[4])
		t_activo[i] = int(f[5])
		idx_de_id[t_id[i]] = i
		id_de_clave["%s|%s" % [TIPOS[t_tipo[i]], t_clave[i]]] = t_id[i]
		var p := t_padre[i]
		if p >= 0:
			if not hijos_de.has(p):
				hijos_de[p] = []
			hijos_de[p].append(t_id[i])
	for nombre in orden_vars:
		var v: Variable = vars[nombre]
		match v.tipo:
			"numero":
				v.col_f.resize(n1)
				for i in range(n0, n1):
					v.col_f[i] = NAN
			"texto":
				v.col_s.resize(n1)
			"id":
				v.col_i.resize(n1)
				for i in range(n0, n1):
					v.col_i[i] = -1
		v.desde.resize(n1)
	n = n1
	version += 1


## Cambia el padre de varios territorios a la vez (p. ej. los pelotones de un país anexado pasan al ejército del anexador).
## El padre de la cadena sigue siendo estructural: no deja fila de historial (el país dueño de un pelotón no se archiva).
func reparentar_lote(ids: Array, nuevo_padre: int) -> int:
	var por_viejo := {}
	for id in ids:
		var i := idx(int(id))
		if i < 0 or t_padre[i] == nuevo_padre:
			continue
		var viejo: int = t_padre[i]
		if not por_viejo.has(viejo):
			por_viejo[viejo] = {}
		por_viejo[viejo][int(id)] = true
		t_padre[i] = nuevo_padre
	var movidos := 0
	for viejo in por_viejo:
		var quitar: Dictionary = por_viejo[viejo]
		var queda := []
		for h in hijos_de.get(viejo, []):
			if not quitar.has(int(h)):
				queda.append(h)
		hijos_de[viejo] = queda
		if not hijos_de.has(nuevo_padre):
			hijos_de[nuevo_padre] = []
		hijos_de[nuevo_padre].append_array(quitar.keys())
		movidos += quitar.size()
	if movidos > 0:
		version += 1
	return movidos


## Marca un territorio como inactivo (p. ej. un pelotón disuelto). Su ID no se reutiliza y su historial se conserva.
func desactivar(id: int) -> void:
	var ix := idx(id)
	if ix >= 0:
		t_activo[ix] = 0
		version += 1


# ─────────────────────────────────────────────────────────────
# Territorios
# ─────────────────────────────────────────────────────────────
func idx(id: int) -> int:
	return int(idx_de_id.get(id, -1))


func id_de(tipo: String, clave: String) -> int:
	return int(id_de_clave.get("%s|%s" % [tipo, clave], -1))


func nombre_de(id: int) -> String:
	var i := idx(id)
	return t_nombre[i] if i >= 0 else ""


func tipo_de(id: int) -> String:
	var i := idx(id)
	return TIPOS[t_tipo[i]] if i >= 0 else ""


func padre_de(id: int) -> int:
	var i := idx(id)
	return t_padre[i] if i >= 0 else -1


func hijos(id: int) -> Array:
	return hijos_de.get(id, [])


## Todos los IDs por debajo de `id` en la cadena (opcionalmente solo de un tipo, p. ej. T_PROVINCIA).
func descendientes(id: int, tipo := -1) -> Array:
	var r := []
	var pila: Array = hijos(id).duplicate()
	while not pila.is_empty():
		var x: int = pila.pop_back()
		if tipo < 0 or t_tipo[idx(x)] == tipo:
			r.append(x)
		pila.append_array(hijos(x))
	return r


## [id, padre, abuelo, ..., 0]
func ruta(id: int) -> Array:
	var r := []
	var x := id
	while x >= 0 and idx(x) >= 0 and r.size() < 12:
		r.append(x)
		x = padre_de(x)
	return r



# ─────────────────────────────────────────────────────────────
# Valores actuales
# ─────────────────────────────────────────────────────────────
func _var(nombre: String) -> Variable:
	var v = vars.get(nombre)
	if v == null:
		push_error("Base de datos: no existe la variable '%s'" % nombre)
	return v


func _celda(v: Variable, id: int) -> int:
	var ix := idx(id)
	if ix < 0:
		push_error("Base de datos: ID %d inexistente" % id)
		return -1
	if v.aplica[t_tipo[ix]] == 0:
		push_error("Base de datos: '%s' no aplica a %s (ID %d)" % [v.nombre, TIPOS[t_tipo[ix]], id])
		return -1
	return ix


func tiene(nombre: String, id: int) -> bool:
	var v := _var(nombre)
	var ix := idx(id)
	if v == null or ix < 0:
		return false
	match v.tipo:
		"numero":
			return not is_nan(v.col_f[ix])
		"texto":
			return v.col_s[ix] != ""
		_:
			return v.col_i[ix] >= 0


func num(nombre: String, id: int, defecto := 0.0) -> float:
	var v := _var(nombre)
	var ix := idx(id)
	if v == null or ix < 0:
		return defecto
	var x := v.col_f[ix]
	return defecto if is_nan(x) else x


func txt(nombre: String, id: int, defecto := "") -> String:
	var v := _var(nombre)
	var ix := idx(id)
	if v == null or ix < 0:
		return defecto
	var x := v.col_s[ix]
	return defecto if x == "" else x


func ref(nombre: String, id: int) -> int:
	var v := _var(nombre)
	var ix := idx(id)
	if v == null or ix < 0:
		return -1
	return v.col_i[ix]


func leer(nombre: String, id: int) -> Variant:
	if not tiene(nombre, id):
		return null
	var v: Variable = vars[nombre]
	var ix := idx(id)
	match v.tipo:
		"numero":
			return v.col_f[ix]
		"texto":
			return v.col_s[ix]
		_:
			return v.col_i[ix]


func _archivar(nombre: String, v: Variable, id: int, ix: int, motivo: String, hasta: int) -> void:
	var h: Hist = hist[nombre]
	h.registrar(id)
	h.h_desde.append(v.desde[ix])
	h.h_hasta.append(hasta)
	h.h_motivo.append(motivo if motivo != "" else motivo_ctx)
	match v.tipo:
		"numero":
			h.h_f.append(v.col_f[ix])
		"texto":
			h.h_s.append(v.col_s[ix])
		_:
			h.h_i.append(v.col_i[ix])


func _cambio(v: Variable) -> void:
	version += 1
	if v.nombre == "propietario":
		version_propietario += 1
	elif v.nombre == "ocupante":
		version_ocupacion += 1
	if v.afecta_economia:
		version_eco += 1


func poner_f(nombre: String, id: int, valor: float, motivo := "") -> bool:
	var v := _var(nombre)
	if v == null:
		return false
	var ix := _celda(v, id)
	if ix < 0:
		return false
	var viejo := v.col_f[ix]
	if (is_nan(viejo) and is_nan(valor)) or viejo == valor:
		return true
	if v.historial == "cambio" and not is_nan(viejo):
		_archivar(nombre, v, id, ix, motivo, fecha)
	v.col_f[ix] = valor
	v.desde[ix] = fecha
	_cambio(v)
	return true


func poner_s(nombre: String, id: int, valor: String, motivo := "") -> bool:
	var v := _var(nombre)
	if v == null:
		return false
	var ix := _celda(v, id)
	if ix < 0:
		return false
	var viejo := v.col_s[ix]
	if viejo == valor:
		return true
	if v.historial == "cambio" and viejo != "":
		_archivar(nombre, v, id, ix, motivo, fecha)
	v.col_s[ix] = valor
	v.desde[ix] = fecha
	_cambio(v)
	return true


func poner_i(nombre: String, id: int, valor: int, motivo := "") -> bool:
	var v := _var(nombre)
	if v == null:
		return false
	var ix := _celda(v, id)
	if ix < 0:
		return false
	var viejo := v.col_i[ix]
	if viejo == valor:
		return true
	if v.historial == "cambio" and viejo >= 0:
		_archivar(nombre, v, id, ix, motivo, fecha)
	v.col_i[ix] = valor
	v.desde[ix] = fecha
	_cambio(v)
	return true


## Carga inicial SIN historial (datos de partida). Pone `desde` = fecha actual.
func inicial_f(nombre: String, id: int, valor: float) -> void:
	var v := _var(nombre)
	var ix := idx(id)
	if v != null and ix >= 0 and v.aplica[t_tipo[ix]] == 1:
		v.col_f[ix] = valor
		v.desde[ix] = fecha


func inicial_s(nombre: String, id: int, valor: String) -> void:
	var v := _var(nombre)
	var ix := idx(id)
	if v != null and ix >= 0 and v.aplica[t_tipo[ix]] == 1:
		v.col_s[ix] = valor
		v.desde[ix] = fecha


func inicial_i(nombre: String, id: int, valor: int) -> void:
	var v := _var(nombre)
	var ix := idx(id)
	if v != null and ix >= 0 and v.aplica[t_tipo[ix]] == 1:
		v.col_i[ix] = valor
		v.desde[ix] = fecha


# ─────────────────────────────────────────────────────────────
# Cadena: herencia y agregados
# ─────────────────────────────────────────────────────────────
## Busca el valor en el propio ID y, si no hay, sube por la cadena (provincia -> estado -> país -> continente -> mundo).
## Devuelve {"valor": Variant, "de": ID donde estaba} o {} si nadie lo tiene.
func heredado(nombre: String, id: int) -> Dictionary:
	for x in ruta(id):
		if tiene(nombre, x):
			return {"valor": leer(nombre, x), "de": x}
	return {}


func suma(nombre: String, ids: Array) -> float:
	var v := _var(nombre)
	var t := 0.0
	if v == null:
		return t
	for id in ids:
		var ix := idx(int(id))
		if ix >= 0 and not is_nan(v.col_f[ix]):
			t += v.col_f[ix]
	return t


func media_ponderada(nombre: String, peso: String, ids: Array) -> float:
	var v := _var(nombre)
	var w := _var(peso)
	if v == null or w == null:
		return 0.0
	var s_ := 0.0
	var sw := 0.0
	for id in ids:
		var ix := idx(int(id))
		if ix >= 0 and not is_nan(v.col_f[ix]) and not is_nan(w.col_f[ix]):
			s_ += v.col_f[ix] * w.col_f[ix]
			sw += w.col_f[ix]
	return s_ / sw if sw > 0.0 else 0.0


## Resume una variable para un territorio según su `agregacion` del catálogo, usando las PROVINCIAS bajo ese ID
## (geográficas). Para "lo que controla un país hoy" se pasa la lista de provincias controladas.
func agregado(nombre: String, ids_provincias: Array) -> float:
	var v := _var(nombre)
	if v == null:
		return 0.0
	if v.agregacion == "suma":
		return suma(nombre, ids_provincias)
	if v.agregacion.begins_with("media_ponderada:"):
		return media_ponderada(nombre, v.agregacion.get_slice(":", 1), ids_provincias)
	return 0.0


var _ix_aplica := {}                     # clave de `aplica` -> {"n": hasta qué fila se miró, "ix": filas de los tipos a los que aplica}


## Filas (índices densos) cuyo tipo de territorio admite la variable `v`, en orden. Se guarda y solo se mira lo que se creó desde la última vez
## (las filas solo se añaden: pelotones y regimientos nuevos van al final).
func _indices_aplica(v: Variable) -> PackedInt32Array:
	var clave := v.aplica.hex_encode()
	var e: Dictionary = _ix_aplica.get(clave, {"n": 0, "ix": PackedInt32Array()})
	var lista: PackedInt32Array = e["ix"]
	var desde_ix: int = e["n"]
	for ix in range(desde_ix, n):
		if v.aplica[t_tipo[ix]] == 1:
			lista.append(ix)
	e["n"] = n
	e["ix"] = lista
	_ix_aplica[clave] = e
	return lista


# ─────────────────────────────────────────────────────────────
# Historial
# ─────────────────────────────────────────────────────────────
## Cierre periódico: guarda en el historial una foto de las variables con política `politica` ("mensual" / "anual"). Devuelve las filas archivadas.
## De una vez; el juego usa `cerrar_periodo_paso` para repartirlo entre fotogramas.
func cerrar_periodo(politica: String) -> int:
	var est := {}
	while cerrar_periodo_paso(politica, est, 1 << 30):
		pass
	return int(est.get("total", 0))


## 0.1.8.32 · El cierre ANUAL archiva ~15.000 filas (un cierre cada año de juego era un tirón de 45-70 ms). Esta versión trabaja por trozos: archiva como mucho
## `max_filas` filas por llamada y guarda en `est` (un diccionario que empieza vacío) por dónde va. Devuelve true mientras quede trabajo.
func cerrar_periodo_paso(politica: String, est: Dictionary, max_filas := 2500) -> bool:
	if not est.has("k"):
		est["k"] = 0                                         # variable en curso (posición en `orden_vars`)
		est["f"] = 0                                         # fila en curso dentro de `est["filas"]`
		est["total"] = 0
		est["filas"] = null                                  # filas con dato de la variable en curso; null = aún sin calcular
	var presupuesto := max_filas
	while est["k"] < orden_vars.size() and presupuesto > 0:
		var nombre: String = orden_vars[est["k"]]
		var v: Variable = vars[nombre]
		if v.historial != politica:
			est["k"] += 1
			continue
		var h: Hist = hist[nombre]
		if est["filas"] == null:
			# 1) filas con dato (un bucle por tipo, sin `match` por fila): solo las de los tipos a los que la variable aplica
			#    (la tesorería solo existe en los ~250 países, no en las 50.000 filas de provincias y pelotones).
			var filas := PackedInt32Array()
			var cand := _indices_aplica(v)
			match v.tipo:
				"numero":
					var cf: PackedFloat64Array = v.col_f
					for ix in cand:
						if not is_nan(cf[ix]):
							filas.append(ix)
				"texto":
					var cs: PackedStringArray = v.col_s
					for ix in cand:
						if cs[ix] != "":
							filas.append(ix)
				_:
					var ci: PackedInt32Array = v.col_i
					for ix in cand:
						if ci[ix] >= 0:
							filas.append(ix)
			est["filas"] = filas
			est["f"] = 0
			presupuesto -= cand.size() >> 2                   # recorrer candidatas cuesta ~4 veces menos que archivarlas
		var filas2: PackedInt32Array = est["filas"]
		var f0: int = est["f"]
		var f1: int = mini(filas2.size(), f0 + maxi(presupuesto, 1))
		# 2) archivarlas
		var motivo := "cierre " + politica
		var desde_v: int = v.ultimo_cierre
		var tipo: String = v.tipo
		for j in range(f0, f1):
			var ix2: int = filas2[j]
			h.registrar(t_id[ix2])
			h.h_desde.append(desde_v if desde_v > 0 else v.desde[ix2])
			h.h_hasta.append(fecha)
			h.h_motivo.append(motivo)
			match tipo:
				"numero":
					h.h_f.append(v.col_f[ix2])
				"texto":
					h.h_s.append(v.col_s[ix2])
				_:
					h.h_i.append(v.col_i[ix2])
		presupuesto -= f1 - f0
		est["total"] += f1 - f0
		est["f"] = f1
		if f1 >= filas2.size():                               # variable terminada
			v.ultimo_cierre = fecha
			est["filas"] = null
			est["k"] += 1
	return est["k"] < orden_vars.size()


## Valor que tenía una variable en una fecha (la actual o una pasada) o null si no había dato. Usa el valor actual si ya
## estaba vigente en esa fecha y, si no, busca el tramo del historial que la contiene ("desde" incluido, "hasta" excluido).
func valor_en(nombre: String, id: int, f: int) -> Variant:
	var v := _var(nombre)
	var ix := idx(id)
	if v == null or ix < 0:
		return null
	if tiene(nombre, id) and v.desde[ix] <= f:
		return leer(nombre, id)
	var h: Hist = hist[nombre]
	var mejor := -1
	var mejor_desde := -1
	for j in h.por_id.get(id, []):
		if h.h_desde[j] <= f and f < h.h_hasta[j] and h.h_desde[j] >= mejor_desde:
			mejor = j
			mejor_desde = h.h_desde[j]
	if mejor < 0:
		return null
	match v.tipo:
		"numero":
			return h.h_f[mejor]
		"texto":
			return h.h_s[mejor]
	return h.h_i[mejor]


## Dueño (ID de país o de entidad histórica) de una provincia en una fecha; -1 si no hay dato.
func dueno_en(prov_id: int, f: int) -> int:
	var r: Variant = valor_en("propietario", prov_id, f)
	return -1 if r == null else int(r)


## Historial de una variable en un ID, del más viejo al más nuevo; el último elemento es el valor ACTUAL ("actual": true).
func historial_de(nombre: String, id: int, maximo := 200) -> Array:
	var v := _var(nombre)
	var r := []
	if v == null:
		return r
	var h: Hist = hist[nombre]
	var k := 0
	for j in h.por_id.get(id, []):
		var valor: Variant = null
		match v.tipo:
			"numero":
				valor = h.h_f[j]
			"texto":
				valor = h.h_s[j]
			_:
				valor = h.h_i[j]
		r.append({"desde": h.h_desde[j], "hasta": h.h_hasta[j], "valor": valor, "motivo": h.h_motivo[j], "actual": false})
		k += 1
	if r.size() > maximo:
		r = r.slice(r.size() - maximo)
	if tiene(nombre, id):
		r.append({"desde": v.desde[idx(id)], "hasta": 0, "valor": leer(nombre, id), "motivo": "", "actual": true})
	return r


# ─────────────────────────────────────────────────────────────
# Información para depurar y documentar
# ─────────────────────────────────────────────────────────────
func resumen() -> Dictionary:
	var por_tipo := {}
	for ix in n:
		if t_activo[ix] == 1:
			var t: String = TIPOS[t_tipo[ix]]
			por_tipo[t] = int(por_tipo.get(t, 0)) + 1
	var filas := []
	for nombre in orden_vars:
		var v: Variable = vars[nombre]
		var llenas := 0
		for ix in n:
			match v.tipo:
				"numero":
					if not is_nan(v.col_f[ix]):
						llenas += 1
				"texto":
					if v.col_s[ix] != "":
						llenas += 1
				_:
					if v.col_i[ix] >= 0:
						llenas += 1
		filas.append({"nombre": nombre, "valores": llenas, "historial": hist[nombre].cuenta(), "politica": v.historial})
	return {"territorios": por_tipo, "variables": filas}
