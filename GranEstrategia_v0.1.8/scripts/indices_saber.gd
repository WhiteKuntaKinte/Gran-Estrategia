extends RefCounted
## ÍNDICES DE SABER SOCIAL por país (0.1.8.47).
##
## La población vive, nace y muere según lo que su país SABE: medicina y salud pública, agricultura, educación, urbanismo e ingeniería. En vez de inventar
## un «nivel tecnológico» aparte, cada índice sale del catálogo de descubrimientos: la fracción de las secciones de ese campo que el país ya conoce (0 a 1,
## ponderada). Así un país que descubre antes la higiene pública baja antes su mortalidad, y el planeta que descubre (0.1.8.46) cambia la demografía sin
## tocar nada más. Los 4 índices:
##   · SALUD  = 65 % medicina (MED) + 35 % servicios públicos y bienestar (SAL)
##   · AGRI   = 80 % agricultura y alimentos (AGR) + 20 % biología (BIO)
##   · EDU    = 70 % educación (EDU) + 30 % lenguas y ciencias humanas (HUM)
##   · URB    = 50 % gestión del territorio (TER) + 50 % ingeniería civil (ING)
## Contar los ~370 descubrimientos de un país cuesta ~50 µs: cada país se refresca una vez al año (rotando), no todos a la vez; un país nuevo se calcula al pedirlo.

const I_SALUD := 0
const I_AGRI := 1
const I_EDU := 2
const I_URB := 3
const N_IDX := 4
const NOMBRES := ["Salud", "Agricultura", "Educación", "Urbanismo"]
const GRUPOS := [
	[["MED", 0.65], ["SAL", 0.35]],
	[["AGR", 0.8], ["BIO", 0.2]],
	[["EDU", 0.7], ["HUM", 0.3]],
	[["TER", 0.5], ["ING", 0.5]],
]
const CICLO_DIAS := 365

var d                                       # Descubrimientos
var _grupos := []                           # por campo: Array de [PackedInt32Array de descubrimientos, peso de cada uno (peso de la sección / su tamaño)]
var _t := {}                                # ID de país -> PackedFloat32Array(N_IDX)
var _dia_de := {}                           # ID de país -> día en que se calculó
var _cursor := 0
var _campos := {}                           # clave de campo («MED», «CIE.COM») -> PackedInt32Array de sus descubrimientos
var recalculos := 0                         # cuántas veces se contó un país (pruebas)


func iniciar(desc) -> bool:
	d = desc
	_t.clear()
	_dia_de.clear()
	_campos.clear()
	_grupos = []
	if d == null or d.n <= 0:
		return false
	var por_cod := {}
	for s in d.secciones.size():
		var cod := String(d.secciones[s].get("cod", ""))
		if not por_cod.has(cod):                                   # COM está en dos ramas: no se usa aquí; los demás códigos son únicos
			por_cod[cod] = s
	var lista_sec := {}
	for i in d.n:
		var s2: int = int(d.seccion[i])
		var l: PackedInt32Array = lista_sec.get(s2, PackedInt32Array())     # los Packed* se copian al sacarlos: se vuelve a guardar
		l.append(i)
		lista_sec[s2] = l
	for campo in GRUPOS:
		var g := []
		for par in campo:
			var s3: int = int(por_cod.get(String(par[0]), -1))
			if s3 < 0 or not lista_sec.has(s3):
				push_error("indices_saber: falta la sección %s del catálogo" % String(par[0]))
				return false
			var idxs: PackedInt32Array = lista_sec[s3]
			g.append([idxs, float(par[1]) / float(idxs.size())])
		_grupos.append(g)
	return true


## Cuenta lo que `tid` sabe en cada campo (0 a 1).
func calcular(tid: int) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(N_IDX)
	var e: PackedByteArray = d.estado_de(tid)
	for c in N_IDX:
		var acum := 0.0
		for g in _grupos[c]:
			var cuenta := 0
			for i in (g[0] as PackedInt32Array):
				cuenta += e[i]
			acum += float(cuenta) * float(g[1])
		r[c] = clampf(acum, 0.0, 1.0)
	recalculos += 1
	return r


## Los descubrimientos de un campo del catálogo. `clave` = código de sección («MED») o «rama.cod» cuando el código está en dos ramas («CIE.COM», «SOC.COM»).
## Vacío si el campo no existe. Se arma la primera vez que se pide.
func campo(clave: String) -> PackedInt32Array:
	var c = _campos.get(clave)
	if c != null:
		return c
	var lista := PackedInt32Array()
	var cod := clave.get_slice(".", 1) if clave.contains(".") else clave
	var rama_cod := clave.get_slice(".", 0) if clave.contains(".") else ""
	var sec := -1
	for s in d.secciones.size():
		var sc: Dictionary = d.secciones[s]
		if String(sc.get("cod", "")) != cod:
			continue
		if rama_cod != "" and String(d.ramas[int(sc.get("rama", 0))].get("cod", "")) != rama_cod:
			continue
		sec = s
		break
	if sec >= 0:
		for i in d.n:
			if int(d.seccion[i]) == sec:
				lista.append(i)
	_campos[clave] = lista
	return lista


## Qué fracción de un campo conoce `tid` (0 a 1; 0 si el campo no existe).
func fraccion_campo(tid: int, clave: String) -> float:
	var lista := campo(clave)
	if lista.is_empty():
		return 0.0
	var e: PackedByteArray = d.estado_de(tid)
	var cuenta := 0
	for i in lista:
		cuenta += e[i]
	return float(cuenta) / float(lista.size())


## Los índices guardados de `tid` (los calcula la primera vez). `dia` = el día de juego, para anotar cuándo se contó.
func de(tid: int, dia := 0) -> PackedFloat32Array:
	var v = _t.get(tid)
	if v == null:
		v = calcular(tid)
		_t[tid] = v
		_dia_de[tid] = dia
	return v


## Vuelve a contar `tid` ahora (por ejemplo tras un cambio manual de saberes en Debug).
func refrescar_pais(tid: int, dia := 0) -> PackedFloat32Array:
	var v := calcular(tid)
	_t[tid] = v
	_dia_de[tid] = dia
	return v


## Refresca como mucho `cuota` países de `tids` (los más atrasados primero, rotando): a cada país le toca una vez cada CICLO_DIAS días.
func rotar(tids: Array, cuota: int, dia: int) -> void:
	if tids.is_empty():
		return
	var hecho := 0
	var n := tids.size()
	var visitados := 0
	while hecho < cuota and visitados < n:
		if _cursor >= n:
			_cursor = 0
		var tid: int = int(tids[_cursor])
		_cursor += 1
		visitados += 1
		if not _t.has(tid) or dia - int(_dia_de.get(tid, 0)) >= CICLO_DIAS:
			refrescar_pais(tid, dia)
			hecho += 1


## Olvida todo (cambio de fecha del Debug, escenario nuevo).
func olvidar() -> void:
	_t.clear()
	_dia_de.clear()
	_cursor = 0
