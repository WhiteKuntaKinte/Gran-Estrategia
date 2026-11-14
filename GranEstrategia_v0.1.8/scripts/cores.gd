extends RefCounted
## CORES de las provincias (0.1.8.40): dos marcas que dicen «de quién es esta tierra» sin importar quién la controle hoy.
##   · Core NACIONAL (`core_nacional`, ID de país): el país para el que la provincia es tierra propia por historia. Al empezar, el país original.
##     No cambia al conquistarla: sirve para saber qué provincias perdidas puede reclamar un país y cuáles son «tierra ajena» en su mapa.
##   · Core CULTURAL (`core_cultural`, id de cultura): la cultura de su gente (datos/nombres_cultura.json). Se fija al empezar según el país original.
## 0.1.8.43: ya tienen efecto: la estabilidad de cada provincia depende de si es tierra propia, de su cultura y de la conquista reciente (ver estabilidad.gd).

var mundo
var bd
var listo := false


## Se llama al empezar la partida (después de `iniciar_ejercito`, que es quien carga las culturas). Pone el core de cada provincia que aún no lo tenga.
func iniciar(m) -> void:
	mundo = m
	bd = m.bd
	listo = bd.vars.has("core_nacional") and bd.vars.has("core_cultural")
	if not listo:
		return
	for pr in m.provincias:
		var origen: String = pr.pais_original
		var pe = m.paises.get(origen)
		if pe != null and not pe.inerte and bd.ref("core_nacional", pr.tid) < 0:
			bd.inicial_i("core_nacional", pr.tid, pe.tid)
		if bd.txt("core_cultural", pr.tid, "") == "":
			var cult := _cultura_de_origen(origen, pe)
			if cult != "":
				bd.inicial_s("core_cultural", pr.tid, cult)


func _cultura_de_origen(origen: String, pe) -> String:
	if mundo.mandos == null or not mundo.mandos.listo:
		return ""
	return mundo.mandos.cultura_de(origen, pe.continente if pe != null else "")


# ───────────── consultas ─────────────
## Cultura que se considera «propia» de un país (la de su país original), "" si no se conoce.
func cultura_de_pais(nombre: String) -> String:
	var pe = mundo.paises.get(nombre)
	return _cultura_de_origen(nombre, pe) if pe != null else ""



## Nombre del país con el core nacional de la provincia `pi` ("" = ninguno).
func nacional(pi: int) -> String:
	var id: int = bd.ref("core_nacional", mundo.provincias[pi].tid)
	return bd.nombre_de(id) if id >= 0 else ""


## id de la cultura de la provincia ("" = ninguna).
func cultural(pi: int) -> String:
	return bd.txt("core_cultural", mundo.provincias[pi].tid, "")


func etiqueta_cultural(pi: int) -> String:
	var c := cultural(pi)
	if c == "" or mundo.mandos == null:
		return "—"
	return mundo.mandos.etiqueta_cultura(c)


## Relación de la provincia con su dueño actual: "propia" (el dueño es el del core), "ajena" (es core de otro país) o "libre" (sin core nacional).
func relacion(pi: int) -> String:
	var pr = mundo.provincias[pi]
	var core: int = bd.ref("core_nacional", pr.tid)
	if core < 0:
		return "libre"
	return "propia" if bd.nombre_de(core) == pr.pais else "ajena"


## ¿La cultura de la provincia es la del país que la controla (la cultura de su país original)? Mismo criterio que usa `iniciar`.
func cultura_del_dueno(pi: int) -> String:
	var pr = mundo.provincias[pi]
	var pe = mundo.paises.get(pr.pais)
	return _cultura_de_origen(pr.pais, pe)


func misma_cultura_que_dueno(pi: int) -> bool:
	var c := cultural(pi)
	return c != "" and c == cultura_del_dueno(pi)


## Cuenta lo que hay en las provincias `pis` (índices): cuántas tienen core nacional propio, de otro país o ninguno, y las culturas ({id: cantidad}).
## Mismo criterio que `relacion` y `cultural`, pero leyendo las columnas directo (un país grande tiene miles de provincias: 16 ms con las consultas una a una).
func contar(pis: Array) -> Dictionary:
	var propias := 0
	var ajenas := 0
	var libres := 0
	var culturas := {}
	var cn: PackedInt32Array = bd.vars["core_nacional"].col_i
	var du: PackedInt32Array = bd.vars["propietario"].col_i
	var cc: PackedStringArray = bd.vars["core_cultural"].col_s
	for pi in pis:
		var ix: int = mundo.provincias[int(pi)].ix
		var core: int = cn[ix]
		if core < 0:
			libres += 1
		elif core == du[ix]:
			propias += 1
		else:
			ajenas += 1
		var c: String = cc[ix]
		if c != "":
			culturas[c] = int(culturas.get(c, 0)) + 1
	return {"propias": propias, "ajenas": ajenas, "libres": libres, "culturas": culturas}


## Provincias (índices) de las que `pais` tiene el core nacional pero hoy controla otro: sus «reclamos».
func reclamos_de(pais: String) -> Array:
	var r := []
	if not listo or not mundo.paises.has(pais):
		return r
	var col: PackedInt32Array = bd.vars["core_nacional"].col_i
	var tid: int = mundo.paises[pais].tid
	var du: PackedInt32Array = bd.vars["propietario"].col_i
	for pr in mundo.provincias:
		if col[pr.ix] == tid and du[pr.ix] != tid:
			r.append(pr.idx)
	return r


# ───────────── edición (Debug) ─────────────
func fijar_nacional(pi: int, pais: String) -> bool:
	if not listo or pi < 0 or pi >= mundo.provincias.size():
		return false
	var tid: int = mundo.provincias[pi].tid
	if pais == "":
		return bd.poner_i("core_nacional", tid, -1, "Debug: core nacional quitado")
	if not mundo.paises.has(pais):
		return false
	return bd.poner_i("core_nacional", tid, int(mundo.paises[pais].tid), "Debug: core nacional")


func fijar_cultural(pi: int, cultura: String) -> bool:
	if not listo or pi < 0 or pi >= mundo.provincias.size():
		return false
	if cultura != "" and (mundo.mandos == null or not mundo.mandos.culturas.has(cultura)):
		return false
	return bd.poner_s("core_cultural", mundo.provincias[pi].tid, cultura, "Debug: core cultural")


## Vuelve los dos cores de la provincia a lo que eran al empezar (país original y su cultura).
func restaurar(pi: int) -> void:
	if not listo or pi < 0 or pi >= mundo.provincias.size():
		return
	var pr = mundo.provincias[pi]
	var pe = mundo.paises.get(pr.pais_original)
	if pe != null and not pe.inerte:
		bd.poner_i("core_nacional", pr.tid, int(pe.tid), "Debug: core restaurado")
	else:
		bd.poner_i("core_nacional", pr.tid, -1, "Debug: core restaurado")
	var cult := _cultura_de_origen(pr.pais_original, pe)
	if cult != "":
		bd.poner_s("core_cultural", pr.tid, cult, "Debug: core restaurado")
