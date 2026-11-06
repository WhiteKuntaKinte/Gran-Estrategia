extends RefCounted
## Capas históricas (0.1.7.9.9D).
##
## El mapa (provincias) es la TIERRA y no cambia. Lo que cambia con el tiempo es quién la manda y cómo se llama todo:
##   · ENTIDADES: reinos, imperios, repúblicas... con ID propio (rango 1.000.000-1.999.999), fechas de inicio y fin,
##     capital y predecesores / sucesores (pueden ser países actuales). Entran en la base de datos como territorios de
##     tipo "entidad", así la variable `propietario` de una provincia puede apuntar a una entidad histórica.
##   · NOMBRES con fechas, para cualquier ID (entidad, país, continente, provincia...): oficial, común o nativo.
##   · BANDERAS con fechas (bandera, escudo o estandarte) y su licencia, para filtrar lo que se puede usar comercialmente.
##   · PERSONAS (rango 2.000.000 en adelante) y CARGOS con fechas: quién gobernó cada entidad y cuándo.
## Todo se lee de datos/historico/*.json (lo llena herramientas/descargar_historia o el juego trae una semilla de ejemplo).
## Si los archivos no existen, el juego funciona igual con las tablas vacías.
##
## Fechas: las mismas de la base de datos, (año + 100000) * 10000 + mes * 100 + día. 0 = desconocida / sin fin.
## Años antes de Cristo: negativos (44 a. C. = -44; no hay año 0).

const BDScript := preload("res://scripts/base_datos.gd")
const RUTA_BANDERAS := "res://banderas_hist/"

var bd                                       # BaseDatos (para el nombre de los territorios actuales)

# ── entidades ──
var ent_ids := PackedInt32Array()
var ent_clave := PackedStringArray()
var ent_nombre := PackedStringArray()
var ent_tipo := PackedStringArray()          # reino, imperio, republica, califato, ciudad-estado, estado, otro
var ent_inicio := PackedInt32Array()
var ent_fin := PackedInt32Array()
var ent_capital := PackedStringArray()
var ent_fuente := PackedStringArray()        # "wikidata", "semilla"...
var ent_pos := {}                            # ID -> posición
var ent_pred := {}                           # ID -> [IDs]
var ent_suc := {}

# ── nombres con fechas ──
var n_id := PackedInt32Array()
var n_nombre := PackedStringArray()
var n_idioma := PackedStringArray()
var n_clase := PackedStringArray()           # oficial | comun | nativo
var n_desde := PackedInt32Array()
var n_hasta := PackedInt32Array()
var n_por_id := {}

# ── banderas con fechas ──
var b_id := PackedInt32Array()
var b_archivo := PackedStringArray()         # nombre del PNG dentro de banderas_hist/
var b_clase := PackedStringArray()           # bandera | escudo | estandarte
var b_desde := PackedInt32Array()
var b_hasta := PackedInt32Array()
var b_licencia := PackedStringArray()        # "Public domain", "CC BY-SA 4.0"... ("" = no verificada)
var b_por_id := {}

# ── personas y cargos ──
var p_id := PackedInt32Array()
var p_clave := PackedStringArray()
var p_nombre := PackedStringArray()
var p_nac := PackedInt32Array()
var p_mue := PackedInt32Array()
var p_pos := {}
var c_persona := PackedInt32Array()
var c_entidad := PackedInt32Array()
var c_cargo := PackedStringArray()
var c_desde := PackedInt32Array()
var c_hasta := PackedInt32Array()
var c_por_entidad := {}


# ─────────────────────────────────────────────────────────────
# Carga
# ─────────────────────────────────────────────────────────────
## Lee entidades.json ({"filas": [[id, clave, nombre, tipo, inicio, fin, capital, fuente, [pred], [suc]]]}).
## Se llama ANTES de crear la base de datos, porque las entidades entran en ella como territorios.
func leer_entidades(js) -> void:
	if not (js is Dictionary):
		return
	for f in js.get("filas", []):
		if not (f is Array) or f.size() < 6:
			continue
		var id := int(f[0])
		if ent_pos.has(id):
			continue
		ent_pos[id] = ent_ids.size()
		ent_ids.append(id)
		ent_clave.append(String(f[1]))
		ent_nombre.append(String(f[2]))
		ent_tipo.append(String(f[3]))
		ent_inicio.append(int(f[4]))
		ent_fin.append(int(f[5]))
		ent_capital.append(String(f[6]) if f.size() > 6 else "")
		ent_fuente.append(String(f[7]) if f.size() > 7 else "")
		ent_pred[id] = _lista_ids(f[8]) if f.size() > 8 else []
		ent_suc[id] = _lista_ids(f[9]) if f.size() > 9 else []


func _lista_ids(x) -> Array:
	var r := []
	if x is Array:
		for v in x:
			r.append(int(v))
	return r


## Filas de territorio [id, tipo, nombre, padre, clave, activo] que las entidades aportan a la base de datos.
func filas_territorio() -> Array:
	var r := []
	for i in ent_ids.size():
		r.append([ent_ids[i], BDScript.T_ENTIDAD, ent_nombre[i], -1, ent_clave[i], 1])
	return r


## Lee el resto de las tablas. Cada argumento es el JSON ya leído (o null si el archivo no existe).
func leer_tablas(nombres, banderas, personas, cargos) -> void:
	if nombres is Dictionary:
		for f in nombres.get("filas", []):          # [id, nombre, idioma, clase, desde, hasta]
			if f is Array and f.size() >= 6:
				var id := int(f[0])
				n_por_id[id] = n_por_id.get(id, [])
				n_por_id[id].append(n_id.size())
				n_id.append(id)
				n_nombre.append(String(f[1]))
				n_idioma.append(String(f[2]))
				n_clase.append(String(f[3]))
				n_desde.append(int(f[4]))
				n_hasta.append(int(f[5]))
	if banderas is Dictionary:
		for f in banderas.get("filas", []):         # [id, archivo, clase, desde, hasta, licencia]
			if f is Array and f.size() >= 5:
				var id2 := int(f[0])
				b_por_id[id2] = b_por_id.get(id2, [])
				b_por_id[id2].append(b_id.size())
				b_id.append(id2)
				b_archivo.append(String(f[1]))
				b_clase.append(String(f[2]))
				b_desde.append(int(f[3]))
				b_hasta.append(int(f[4]))
				b_licencia.append(String(f[5]) if f.size() > 5 else "")
	if personas is Dictionary:
		for f in personas.get("filas", []):         # [id, clave, nombre, nacimiento, muerte]
			if f is Array and f.size() >= 5:
				var id3 := int(f[0])
				if p_pos.has(id3):
					continue
				p_pos[id3] = p_id.size()
				p_id.append(id3)
				p_clave.append(String(f[1]))
				p_nombre.append(String(f[2]))
				p_nac.append(int(f[3]))
				p_mue.append(int(f[4]))
	if cargos is Dictionary:
		for f in cargos.get("filas", []):           # [persona, entidad, cargo, desde, hasta]
			if f is Array and f.size() >= 5:
				var ent := int(f[1])
				c_por_entidad[ent] = c_por_entidad.get(ent, [])
				c_por_entidad[ent].append(c_persona.size())
				c_persona.append(int(f[0]))
				c_entidad.append(ent)
				c_cargo.append(String(f[2]))
				c_desde.append(int(f[3]))
				c_hasta.append(int(f[4]))


# ─────────────────────────────────────────────────────────────
# Consultas por fecha
# ─────────────────────────────────────────────────────────────
static func _vigente(desde: int, hasta: int, f: int) -> bool:
	return (desde == 0 or desde <= f) and (hasta == 0 or f < hasta)


## IDs de las entidades históricas vigentes en esa fecha. Las que no tienen fecha de inicio no se pueden situar y se omiten;
## las que no tienen fecha de fin se consideran vigentes desde su inicio.
func entidades_activas(f: int) -> Array:
	var r := []
	for i in ent_ids.size():
		if ent_inicio[i] > 0 and _vigente(ent_inicio[i], ent_fin[i], f):
			r.append(ent_ids[i])
	return r


func nombre_base(id: int) -> String:
	if ent_pos.has(id):
		return ent_nombre[int(ent_pos[id])]
	return bd.nombre_de(id) if bd != null else ""


## Nombre que tenía un territorio o entidad en una fecha. Prefiere el idioma pedido, luego es / en, y dentro de eso el oficial
## y el que tiene fechas propias. Si no hay ninguno vigente, devuelve el nombre base.
func nombre_en(id: int, f: int, idioma := "es") -> String:
	var mejor := -1
	var mejor_p := -1
	var mejor_d := -1
	for j in n_por_id.get(id, []):
		if not _vigente(n_desde[j], n_hasta[j], f):
			continue
		var p := 0
		var lg := n_idioma[j]
		if lg == idioma:
			p += 40
		elif lg == "es":
			p += 20
		elif lg == "en":
			p += 10
		elif lg == "":
			p += 5
		match n_clase[j]:
			"oficial":
				p += 6
			"comun":
				p += 3
		if n_desde[j] > 0:
			p += 1
		if p > mejor_p or (p == mejor_p and n_desde[j] > mejor_d):
			mejor_p = p
			mejor_d = n_desde[j]
			mejor = j
	return n_nombre[mejor] if mejor >= 0 else nombre_base(id)


## Todos los nombres registrados de un ID: [{nombre, idioma, clase, desde, hasta}], ordenados por fecha.
func nombres_de(id: int) -> Array:
	var r := []
	for j in n_por_id.get(id, []):
		r.append({"nombre": n_nombre[j], "idioma": n_idioma[j], "clase": n_clase[j], "desde": n_desde[j], "hasta": n_hasta[j]})
	r.sort_custom(func(a, b): return int(a["desde"]) < int(b["desde"]))
	return r


## Bandera (o escudo) vigente en una fecha: {archivo, ruta, clase, licencia, desde, hasta} o {} si no hay. Prefiere banderas
## sobre escudos y, entre varias, la que empezó más tarde.
func bandera_en(id: int, f: int) -> Dictionary:
	var mejor := -1
	var mejor_p := -1
	var mejor_d := -1
	for j in b_por_id.get(id, []):
		if not _vigente(b_desde[j], b_hasta[j], f):
			continue
		var p := 1
		match b_clase[j]:
			"bandera":
				p = 3
			"estandarte":
				p = 2
		if p > mejor_p or (p == mejor_p and b_desde[j] > mejor_d):
			mejor_p = p
			mejor_d = b_desde[j]
			mejor = j
	if mejor < 0:
		return {}
	return {"archivo": b_archivo[mejor], "ruta": RUTA_BANDERAS + b_archivo[mejor], "clase": b_clase[mejor],
		"licencia": b_licencia[mejor], "desde": b_desde[mejor], "hasta": b_hasta[mejor]}


## Quién mandaba una entidad en esa fecha: [{persona, nombre, cargo, desde, hasta}].
func gobernantes_en(entidad: int, f: int) -> Array:
	var r := []
	for j in c_por_entidad.get(entidad, []):
		if _vigente(c_desde[j], c_hasta[j], f):
			var pid := c_persona[j]
			r.append({"persona": pid, "nombre": nombre_persona(pid), "cargo": c_cargo[j], "desde": c_desde[j], "hasta": c_hasta[j]})
	return r


## Todos los gobernantes de una entidad, por fecha de inicio.
func gobernantes_de(entidad: int) -> Array:
	var r := []
	for j in c_por_entidad.get(entidad, []):
		var pid := c_persona[j]
		r.append({"persona": pid, "nombre": nombre_persona(pid), "cargo": c_cargo[j], "desde": c_desde[j], "hasta": c_hasta[j]})
	r.sort_custom(func(a, b): return int(a["desde"]) < int(b["desde"]))
	return r


func nombre_persona(pid: int) -> String:
	return p_nombre[int(p_pos[pid])] if p_pos.has(pid) else "?"


func ficha(id: int) -> Dictionary:
	if not ent_pos.has(id):
		return {}
	var i: int = ent_pos[id]
	return {"id": id, "clave": ent_clave[i], "nombre": ent_nombre[i], "tipo": ent_tipo[i], "inicio": ent_inicio[i],
		"fin": ent_fin[i], "capital": ent_capital[i], "fuente": ent_fuente[i],
		"predecesores": ent_pred.get(id, []), "sucesores": ent_suc.get(id, [])}


## Busca entidades por cualquiera de sus nombres (sin distinguir mayúsculas ni tildes). Devuelve IDs.
func buscar(texto: String, maximo := 60) -> Array:
	var q := _plano(texto)
	var r := []
	var vistos := {}
	if q == "":
		return r
	for i in ent_ids.size():
		if _plano(ent_nombre[i]).contains(q):
			vistos[ent_ids[i]] = true
			r.append(ent_ids[i])
			if r.size() >= maximo:
				return r
	for j in n_id.size():
		var id := n_id[j]
		if ent_pos.has(id) and not vistos.has(id) and _plano(n_nombre[j]).contains(q):
			vistos[id] = true
			r.append(id)
			if r.size() >= maximo:
				break
	return r


static func _plano(s: String) -> String:
	var r := s.to_lower()
	for par in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["ñ", "n"], ["ç", "c"]]:
		r = r.replace(par[0], par[1])
	return r


## Texto corto de una fecha para pantallas: "1819" o "44 a. C." (solo el año).
static func anio_texto(f: int) -> String:
	if f <= 0:
		return "?"
	var a := floori(f / 10000.0) - 100000
	return "%d a. C." % -a if a < 0 else str(a)


func resumen() -> Dictionary:
	return {"entidades": ent_ids.size(), "nombres": n_id.size(), "banderas": b_id.size(), "personas": p_id.size(), "cargos": c_persona.size()}
