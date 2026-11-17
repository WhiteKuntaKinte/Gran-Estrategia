extends RefCounted
## EDIFICIOS por provincia (0.1.8.40).
##
## El catálogo (datos/edificios.json, 109 edificios = los descubrimientos de tipo B) lo genera herramientas/construir_edificios.py.
## Un país puede construir un edificio cuando CONOCE su descubrimiento (`Descubrimientos.conoce`, o sea, según la fecha del reloj).
## Construir cuesta dinero (la divisa del dueño) y tarda días; el edificio se guarda POR PROVINCIA en la base de datos:
##   · `edificios` (texto, provincia)  «slug:cantidad;slug:cantidad»          lo ya construido.
##   · `obras` (texto, provincia)      «slug@día_inicio@día_fin@pago_usd;...» lo que está en obra (los días son del reloj propio `dia_n`).
##   · `num_edificios` (número, provincia)  cuántos hay construidos (se suma hacia país, estado y continente).
## EFECTOS (0.1.8.48, datos/edificios_efectos.json): 7 clases de efecto (salud, comida, vivienda, producción, orden, defensa, movilidad); ver docs/EDIFICIOS_EFECTOS.md.
##   Los edificios de PARTIDA ya están en los datos de la época (renta, población, esperanza de vida): salud / comida / vivienda / producción solo cuentan lo que se
##   construye DESPUÉS; orden, defensa y movilidad cuentan todo (los datos reales no los traen). Producción: al terminar una obra sube el producto por habitante.
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
var unica := PackedByteArray()          # 1 = MARAVILLA: solo puede haber una en todo el mundo (categoría «mar»; construida o en obra)
var _unica_pi := {}                      # edificio único -> índice de la provincia que lo tiene o lo está construyendo
var _lista_unicas := PackedInt32Array()  # índices de los edificios únicos (para no recorrer los 178)
var era := PackedInt32Array()
var anio := PackedInt32Array()
var seccion := PackedStringArray()
var desc := PackedStringArray()
var desc_idx := PackedInt32Array()       # índice del descubrimiento que lo habilita (-1 = no hay)
var idx_de_slug := {}
var categorias: Array = []               # [{cod, nombre, icono}]
var clases := {}                         # clase -> {nombre, fraccion, dias}
var _frac := PackedFloat32Array()        # por edificio: fracción de la producción anual de la provincia que cuesta (la de su clase)

var dia_n := 0                           # días de juego pasados (reloj de las obras)
var terminadas := 0                      # obras terminadas desde que empezó la partida (para pruebas y Debug)
var producidas := 0                      # ... y cuántas de esas obras subieron la producción de su provincia
var version := 0                         # sube con cualquier cambio de edificios u obras (la interfaz sabe si debe redibujar)
var _obras := {}                         # índice de provincia -> Array de [e, ini, fin, pago_usd]
var _prox_fin := SIN_FIN
var _cache := {}                         # tid de provincia -> [texto, Dictionary slug->cantidad]
var _pc_cache := {}                      # país -> [versión económica de la base, producción anual por habitante en US$]
var cache_tolerante := false             # true = los costos usan la producción por habitante ya guardada aunque la economía haya cambiado (la IA lo enciende un momento: recalcularla recorre el país entero)

# ───────────── efectos (0.1.8.48) ─────────────
const EF_SAL := 0                        # salud: suma a la salud efectiva (0-1)
const EF_COM := 1                        # comida segura: puntos de bienestar
const EF_URB := 2                        # vivienda y ciudad: suma a la meta de urbanización (0-1)
const EF_REN := 3                        # producción: fracción que sube el producto por habitante al terminar la obra
const EF_ORD := 4                        # orden y cohesión: puntos de estabilidad
const EF_DEF := 5                        # defensa: × que suma al poder de los defensores
const EF_MOV := 6                        # movilidad: fracción del castigo de la distancia a la capital que se quita
const N_EF := 7
const EF_CLAVES := ["sal", "com", "urb", "ren", "ord", "def", "mov"]
var _cero3 := PackedFloat32Array([0.0, 0.0, 0.0])      # lo que devuelve `efectos_nuevos` cuando no hay nada (compartido: no se modifica)

var efectos_listos := false
var ef_tipos: Array = []                 # por clase de efecto: {nombre, por_habitante, tope, unidad, texto}
var ef_solo_saber := PackedStringArray() # edificios sin efecto propio a propósito (ya cuentan como instituciones de saber)
var _ef_tope := PackedFloat32Array()
var _ef_hab := PackedByteArray()         # 1 = el efecto depende de cuánta gente atiende el edificio
var _ef_de: Array = []                   # por edificio: Array de [clase, peso, habitantes que atiende cada unidad]
var _ef_abs_de: Array = []               # lo mismo pero solo orden, defensa y movilidad (lo que cuenta TODO lo construido: sembrar_iniciales solo suma esto)
var _base := {}                          # tid de provincia -> texto de edificios con el que empezó la partida
var _nuevos := {}                        # tid -> true: la provincia tiene más de lo que tenía al empezar
var _s_abs := {}                         # tid -> PackedFloat32Array(2 · N_EF) con TODO lo construido: [habitantes·peso ×N_EF, peso ×N_EF]
var _s_nue := {}                         # tid -> lo mismo, solo con lo construido después de empezar la partida


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
		unica.append(1 if bool(e.get("unica", false)) else 0)
		if unica[unica.size() - 1] == 1:
			_lista_unicas.append(unica.size() - 1)
		era.append(int(e.get("era", 0)))
		anio.append(int(e.get("anio", 0)))
		seccion.append(String(e.get("seccion", "")))
		desc.append(String(e.get("desc", "")))
		idx_de_slug[slug[slug.size() - 1]] = slug.size() - 1
		_frac.append(float(clases.get(String(e["clase"]), {}).get("fraccion", 0.01)))
	listo = true
	return true


## Carga datos/edificios_efectos.json (va DESPUÉS de `cargar`). Devuelve false si falta o no cuadra con el catálogo; sin efectos los edificios solo existen.
func cargar_efectos(js: Dictionary) -> bool:
	efectos_listos = false
	var tipos: Dictionary = js.get("tipos", {})
	var ef: Dictionary = js.get("efectos", {})
	if n <= 0 or tipos.is_empty() or ef.is_empty():
		return false
	_ef_tope.resize(N_EF)
	_ef_hab.resize(N_EF)
	ef_tipos = []
	for k in N_EF:
		var t: Dictionary = tipos.get(EF_CLAVES[k], {})
		if t.is_empty():
			return false
		_ef_tope[k] = float(t.get("tope", 1.0))
		_ef_hab[k] = 1 if bool(t.get("por_habitante", false)) else 0
		ef_tipos.append(t)
	_ef_de = []
	_ef_de.resize(n)
	for i in n:
		var lista := []
		for par in ef.get(slug[i], []):
			var k: int = EF_CLAVES.find(String(par[0]))
			if k < 0:
				return false
			lista.append([k, float(par[1]), float(par[2])])
		_ef_de[i] = lista
	_ef_abs_de = []
	_ef_abs_de.resize(n)
	for i in n:
		var la := []
		for x in (_ef_de[i] as Array):
			if int(x[0]) >= EF_ORD:
				la.append(x)
		_ef_abs_de[i] = la
	ef_solo_saber = PackedStringArray(js.get("solo_saber", []))
	efectos_listos = true
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
	producidas = 0
	_obras.clear()
	_cache.clear()
	_base.clear()
	_nuevos.clear()
	_s_abs.clear()
	_s_nue.clear()
	_unica_pi.clear()
	_prox_fin = SIN_FIN
	for pr in m.provincias:                                  # obras que ya trajera la base (por ejemplo, de Debug o de una época con datos propios)
		var t: String = bd.txt("obras", pr.tid, "")
		if t != "":
			_obras[pr.idx] = _leer_obras(t)
		var te: String = bd.txt("edificios", pr.tid, "")
		if te != "":                                         # lo que ya había es la partida de la época: sus efectos ya están en los datos
			_base[pr.tid] = te                                # sus sumas de efectos se calculan al primer uso (`_abs_de`)
			for eu in _lista_unicas:                         # una maravilla que ya traiga la base cuenta como existente
				if te.contains(slug[eu] + ":"):
					_unica_pi[eu] = pr.idx
	for pi_o in _obras:
		for o in _obras[pi_o]:
			if unica[int(o[0])] == 1:
				_unica_pi[int(o[0])] = pi_o
	_recalcular_prox()


# ───────────── edificios de partida (0.1.8.42) ─────────────
## Cada escenario empieza con los edificios que ya habría en esa época, NO con las provincias vacías. Es una regla (sin sorteo: sale siempre lo mismo):
##   · desarrollo de la provincia (0–1) = 60 % su población + 40 % su producción por habitante frente a la de referencia de la época;
##   · difusión del edificio (0–1) = 1 − e^(−años desde su descubrimiento / tiempo de la clase): lo antiguo ya está en todas partes y lo recién descubierto casi no;
##   · umbral de la clase: lo grande (D–F) solo en provincias muy desarrolladas, lo básico (A) en todas;
##   · cantidad = máximo del edificio × difusión × suavizado((desarrollo − umbral) / 0,2); la parte decimal se redondea con un hash fijo de (provincia, edificio).
## Las tierras sin reclamar no tienen edificios. Los edificios que da esto no cuestan nada ni se registran como historia: es el punto de partida.
const TIEMPO_CLASE := {"A": 250.0, "B": 300.0, "C": 400.0, "D": 600.0, "E": 900.0, "F": 1500.0}   # años que tarda en difundirse una clase de obra
const UMBRAL_CLASE := {"A": 0.0, "B": 0.12, "C": 0.28, "D": 0.45, "E": 0.62, "F": 0.80}           # desarrollo mínimo para empezar a tenerlos
const POB_REF := 400000.0                                                                          # población que da desarrollo máximo por habitantes
const PIB_REF_ANTIGUO := 1500.0                                                                    # US$ por habitante de referencia antes de 1900
const PIB_REF_MODERNO := 25000.0                                                                   # ... y desde 1900


## Cuántos edificios de cada tipo tiene de partida una provincia con ese desarrollo (0–1); `difusion[e]` y `umbral[e]` ya calculados. Pura: sirve para probar.
func cantidad_inicial(e: int, pi: int, desarrollo: float, difusion: float, umbral_e := -1.0) -> int:
	if difusion <= 0.004:
		return 0
	var u: float = umbral_e if umbral_e >= 0.0 else float(UMBRAL_CLASE.get(clase[e], 0.5))     # `umbral_e`: el que ya tiene calculado quien llama (0.1.8.49: sembrar_iniciales lo hace 1M de veces)
	var t: float = clampf((desarrollo - u) / 0.2, 0.0, 1.0)
	var esperado: float = float(tope[e]) * difusion * t * t * (3.0 - 2.0 * t)
	var c := int(floor(esperado))
	var frac := esperado - float(c)
	if frac > 0.0:
		var h: float = float(((pi + 1) * 2654435761 + (e + 1) * 40503) % 65536) / 65536.0
		if frac > h:
			c += 1
	return mini(c, int(tope[e]))


## Reparte los edificios de partida del escenario del año `anio`. Se llama una vez, al empezar (Mundo.iniciar_edificios).
const _NUM_TXT := ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]


func sembrar_iniciales(anio_epoca: int) -> int:
	if not listo or mundo == null:
		return 0
	var difusion := PackedFloat32Array()
	difusion.resize(n)
	var activos := PackedInt32Array()
	for e in n:
		var edad := float(anio_epoca - anio[e])
		var tc: float = float(TIEMPO_CLASE.get(clase[e], 400.0))
		difusion[e] = 1.0 - exp(-edad / tc) if edad > 0.0 else 0.0
		if difusion[e] > 0.004 and unica[e] == 0:                     # las maravillas no se reparten al empezar: hay que construirlas
			activos.append(e)
	var pib_ref: float = PIB_REF_MODERNO if anio_epoca >= 1900 else PIB_REF_ANTIGUO
	var lg_pob := log(1.0 + POB_REF / 3000.0)
	var lg_pib := log(pib_ref / 200.0)
	var umbral := PackedFloat32Array()                              # por edificio, para saltarse sin llamar a nadie lo que esa provincia aún no puede tener
	umbral.resize(n)
	var prefijo := PackedStringArray()
	prefijo.resize(n)
	for e in n:
		umbral[e] = float(UMBRAL_CLASE.get(clase[e], 0.5))
		prefijo[e] = slug[e] + ":"
	var total := 0
	for pr in mundo.provincias:
		var pais = mundo.paises.get(pr.pais)
		if pais == null or pais.inerte:
			continue
		var pob: float = pr.poblacion
		if pob <= 0.0:
			continue
		var pop_f := clampf(log(1.0 + pob / 3000.0) / lg_pob, 0.0, 1.0)
		var pib_f := clampf(log(maxf(pr.pib_pc, 200.0) / 200.0) / lg_pib, 0.0, 1.0)
		var desarrollo := 0.6 * pop_f + 0.4 * pib_f
		var partes := PackedStringArray()                           # `activos` va en orden de índice: el texto sale ya en el orden canónico de `_guardar`
		var suma := 0
		var rs := PackedFloat32Array()                              # sumas de orden, defensa y movilidad de lo sembrado (`_s_abs`), sin volver a leer el texto
		rs.resize(2 * N_EF)
		for e in activos:
			if desarrollo <= umbral[e]:
				continue
			var c := cantidad_inicial(e, pr.idx, desarrollo, difusion[e], umbral[e])
			if c > 0:
				partes.append(prefijo[e] + (_NUM_TXT[c] if c < _NUM_TXT.size() else str(c)))
				suma += c
				for x in (_ef_abs_de[e] as Array):
					var kx: int = x[0]
					rs[kx] += float(c) * float(x[1]) * float(x[2])
					rs[N_EF + kx] += float(c) * float(x[1])
		if suma > 0:
			var texto := ";".join(partes)
			bd.inicial_s("edificios", pr.tid, texto)                # valores de partida: sin historial ni avisos de cambio
			bd.inicial_f("num_edificios", pr.tid, float(suma))
			_base[pr.tid] = texto
			if efectos_listos:
				_s_abs[pr.tid] = rs
			total += suma
	version += 1
	return total


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
	_refrescar_efectos(tid, d)
	_actualizar_unicas(pi, d)
	version += 1


## Pone edificios ya terminados (Debug, pruebas, épocas con datos propios). No cobra nada.
func dar(pi: int, e: int, cant := 1) -> void:
	var d: Dictionary = de_provincia(pi).duplicate()
	d[slug[e]] = maxi(int(d.get(slug[e], 0)) + cant, 0)
	_guardar(pi, d, "Debug: edificio añadido" if cant > 0 else "Debug: edificio quitado")


func quitar(pi: int, e: int, cant := 1) -> void:
	dar(pi, e, -cant)


# ───────────── maravillas (0.1.8.51): una sola en el mundo ─────────────
## Mantiene `_unica_pi` cuando cambian los edificios (`d` = lo construido, o null para leerlo) o las obras de la provincia `pi`.
func _actualizar_unicas(pi: int, d) -> void:
	if _lista_unicas.is_empty():
		return
	var tiene: Dictionary = d if d != null else de_provincia(pi)
	var lista: Array = _obras.get(pi, [])
	for e in _lista_unicas:
		var aqui: bool = int(tiene.get(slug[e], 0)) > 0
		if not aqui:
			for o in lista:
				if int(o[0]) == e:
					aqui = true
					break
		if aqui:
			_unica_pi[e] = pi
		elif int(_unica_pi.get(e, -1)) == pi:
			_unica_pi.erase(e)


## Provincia que tiene (o está construyendo) la maravilla `e`; -1 si nadie.
func donde_unica(e: int) -> int:
	return int(_unica_pi.get(e, -1))


## Maravillas ya CONSTRUIDAS en la provincia `pi` (índices de edificio).
func maravillas_de(pi: int) -> PackedInt32Array:
	var r := PackedInt32Array()
	for e in _lista_unicas:
		if int(_unica_pi.get(e, -1)) == pi and cantidad(pi, e) > 0:
			r.append(e)
	return r


## Todas las maravillas construidas en el mundo: {edificio: provincia}.
func maravillas_del_mundo() -> Dictionary:
	var r := {}
	for e in _lista_unicas:
		var pi: int = int(_unica_pi.get(e, -1))
		if pi >= 0 and cantidad(pi, e) > 0:
			r[e] = pi
	return r


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
	_actualizar_unicas(pi, null)
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
	if c != null and (int(c[0]) == bd.version_eco or cache_tolerante):
		return float(c[1])
	var pc := 0.0
	if mundo.paises.has(pais):
		pc = mundo.produccion_anual_usd(pais) / maxf(mundo.poblacion_de(pais), 1.0)
	_pc_cache[pais] = [bd.version_eco, pc]
	return pc


## Costo en US$ de construir `e` en la provincia `pi`.
func costo_usd(pi: int, e: int) -> float:
	return _frac[e] * _prod_base_usd(pi)


## Fracción de la producción anual de una provincia que cuesta construir `e` (la de su clase).
func fraccion_de(e: int) -> float:
	return _frac[e]


## ¿Este edificio hace algo propio (salud, comida, vivienda, producción, orden, defensa, movilidad)? Los de saber no: ya cuentan como instituciones.
func con_efecto(e: int) -> bool:
	return efectos_listos and e >= 0 and e < n and not (_ef_de[e] as Array).is_empty()


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
	return puede_con_costo(pais, pi, e, -1.0)


## Costo en la divisa del dueño de lo que valdría un edificio de fracción 1 en la provincia `pi`: el costo de `e` es `_frac[e]` por esto. Las listas de grupo (ventana Construir
## con varias provincias) lo calculan UNA vez por provincia y no una por edificio (0.1.8.49: con 141 edificios y un país entero el refresco pasaba de 400 ms).
func base_local(pi: int) -> float:
	return _prod_base_usd(pi) * _por_usd(mundo.provincias[pi].pais)


## Lo mismo que `puede`, con el costo local ya calculado (`costo` < 0 = calcularlo aquí).
func puede_con_costo(pais: String, pi: int, e: int, costo: float) -> Dictionary:
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
	if unica[e] == 1:
		var otra: int = int(_unica_pi.get(e, -1))
		if otra >= 0 and otra != pi:
			var pr2 = mundo.provincias[otra]
			var hecha: bool = cantidad(otra, e) > 0
			return {"ok": false, "motivo": "%s ya %s en %s (%s): solo hay una en todo el mundo." % [nombre[e], "existe" if hecha else "se está construyendo", pr2.nombre, pr2.pais]}
	if costo < 0.0:
		costo = costo_local(pi, e)
	var p = mundo.paises[pais]
	if costo > 0.0 and p.tiene_tesoreria() and p.tesoreria + p.fondo_obras < costo:
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
	var del_fondo := minf(float(p.fondo_obras), costo_l)           # 0.1.8.48: primero se gasta el fondo de obras públicas, luego la tesorería
	if del_fondo > 0.0:
		p.fondo_obras = p.fondo_obras - del_fondo
	if p.tiene_tesoreria():
		p.tesoreria = p.tesoreria - (costo_l - del_fondo)
	var lista: Array = _obras.get(pi, [])
	lista.append([e, dia_n, dia_n + dias_de(e), costo_u])
	_obras[pi] = lista
	_escribir_obras(pi)
	return {"ok": true, "msg": "Obra empezada: %s (%d días)." % [nombre[e], dias_de(e)], "costo": costo_l, "fondo": del_fondo}


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
			if unica[e] == 1:                                       # una maravilla se levanta en una sola provincia
				break
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
		var pob: float = mundo.provincias[pi].poblacion
		var ren_antes: float = efecto_nuevo(pi, EF_REN, pob)
		for o in lista:
			if int(o[2]) <= dia_n:
				d[slug[int(o[0])]] = int(d.get(slug[int(o[0])], 0)) + 1
				terminadas += 1
				if mundo.paises.has(pais) and (pais == mundo.jugador or not mundo.tiene_ia(pais)):          # las obras de las IA no llenan el registro de sucesos
					mundo.evento(int(mundo.paises[pais].tid), "Obra terminada: %s en %s." % [nombre[int(o[0])], mundo.provincias[pi].nombre])
			else:
				quedan.append(o)
		_guardar(pi, d, "Obra terminada")
		var boost: float = efecto_nuevo(pi, EF_REN, pob) - ren_antes
		if boost > 1.0e-6:                                         # 0.1.8.48: la provincia se vuelve más productiva (sube su producto por habitante)
			var pcol: PackedFloat64Array = bd.vars["pib_pc_usd"].col_f      # escribe directo en la columna (como el desarrollo mensual): la caché de ingresos lo recoge al cerrar el mes
			var kx: int = mundo.provincias[pi].ix
			if not is_nan(pcol[kx]):
				pcol[kx] *= 1.0 + boost
				producidas += 1
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


# ───────────── efectos: cálculo (0.1.8.48) ─────────────
## {slug: cantidad} de un texto «slug:cantidad;slug:cantidad».
func _dict_de_texto(t: String) -> Dictionary:
	var d := {}
	if t != "":
		for par in t.split(";", false):
			var p := par.split(":")
			if p.size() == 2 and idx_de_slug.has(p[0]):
				d[p[0]] = int(p[1])
	return d


## Sumas de efectos de `d` ({slug: cantidad}); con `base` (otro diccionario) solo cuenta lo que pasa de ella. Devuelve 2·N_EF valores:
## [habitantes que atiende × peso, de cada clase ... , peso de cada clase ...].
func _sumas(d: Dictionary, base) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(2 * N_EF)
	if not efectos_listos:
		return r
	for sl in d:
		var e: int = int(idx_de_slug.get(sl, -1))
		if e < 0:
			continue
		var c: int = int(d[sl])
		if base != null:
			c -= int(base.get(sl, 0))
		if c <= 0:
			continue
		for x in (_ef_de[e] as Array):
			var k: int = x[0]
			r[k] += float(c) * float(x[1]) * float(x[2])
			r[N_EF + k] += float(c) * float(x[1])
	return r


## Rehace las sumas de efectos de la provincia `tid` tras un cambio de sus edificios (`d` = lo que tiene ahora).
func _refrescar_efectos(tid: int, d: Dictionary) -> void:
	if not efectos_listos:
		return
	var base: Dictionary = _dict_de_texto(String(_base.get(tid, "")))
	_s_abs[tid] = _sumas(d, null)
	var hay := false
	for sl in d:
		if int(d[sl]) > int(base.get(sl, 0)):
			hay = true
			break
	if hay:
		_nuevos[tid] = true
		_s_nue[tid] = _sumas(d, base)
	else:
		_nuevos.erase(tid)
		_s_nue.erase(tid)


## Efecto de la clase `k` con las sumas `S` (habitantes·peso) y `W` (peso) para una provincia de `pop` habitantes. Con efecto por habitante, lo que atienden los
## edificios se diluye si la provincia tiene mucha más gente (no puede dar más que su peso); y todo satura: más edificios dan cada vez menos (tope por clase).
func _valor_ws(sum_hab: float, sum_peso: float, k: int, pop: float) -> float:
	if sum_peso <= 0.0:
		return 0.0
	var tope: float = _ef_tope[k]
	var x := sum_peso
	if _ef_hab[k] == 1:
		x = minf(sum_peso, sum_hab / maxf(pop, 5000.0))
	return tope * (1.0 - exp(-x / tope))


func _valor(s: PackedFloat32Array, k: int, pop: float) -> float:
	return _valor_ws(s[k], s[N_EF + k], k, pop)


## Efectos de lo construido DESPUÉS de empezar la partida en la provincia `pi` (de `pop` habitantes): [salud, comida, vivienda]. Casi siempre ceros
## (arreglo compartido: no se modifica).
func efectos_nuevos(pi: int, pop: float) -> PackedFloat32Array:
	if _nuevos.is_empty():
		return _cero3
	var s = _s_nue.get(mundo.provincias[pi].tid)
	if s == null:
		return _cero3
	var r := PackedFloat32Array()
	r.resize(3)
	r[0] = _valor(s, EF_SAL, pop)
	r[1] = _valor(s, EF_COM, pop)
	r[2] = _valor(s, EF_URB, pop)
	return r


## Efecto de la clase `k` (EF_*) de lo construido después de empezar la partida.
func efecto_nuevo(pi: int, k: int, pop: float) -> float:
	var s = _s_nue.get(mundo.provincias[pi].tid)
	return 0.0 if s == null else _valor(s, k, pop)


## Sumas de efectos de TODO lo construido en la provincia `tid`. Las de los edificios de partida se calculan la primera vez que alguien las pide (si la provincia no ha cambiado desde
## entonces, `_s_abs` no la tiene y lo de partida es todo lo que hay); null si no tiene ninguno.
func _abs_de(tid: int):
	var s = _s_abs.get(tid)
	if s == null and efectos_listos:
		var te = _base.get(tid)
		if te != null:
			s = _sumas(_dict_de_texto(String(te)), null)
			_s_abs[tid] = s
	return s


## Efecto de la clase `k` (EF_ORD, EF_DEF, EF_MOV) de TODO lo construido en la provincia (también lo de partida): los datos reales no lo traen.
func efecto_abs(pi: int, k: int, pop := 0.0) -> float:
	var s = _abs_de(mundo.provincias[pi].tid)
	return 0.0 if s == null else _valor(s, k, pop)


## Lo que sumaría construir una unidad más de `e` en la provincia `pi` (de `pop` habitantes), por clase de efecto (N_EF valores): para elegir qué construir.
func ganancias(pi: int, e: int, pop: float) -> PackedFloat32Array:
	var r := PackedFloat32Array()
	r.resize(N_EF)
	if not efectos_listos:
		return r
	var tid: int = mundo.provincias[pi].tid
	var s_n = _s_nue.get(tid)
	var s_a = _abs_de(tid)
	for x in (_ef_de[e] as Array):
		var k: int = x[0]
		var s = s_a if k >= EF_ORD else s_n
		var sh := 0.0
		var sp := 0.0
		if s != null:
			sh = s[k]
			sp = s[N_EF + k]
		var dh: float = float(x[1]) * float(x[2])
		r[k] = _valor_ws(sh + dh, sp + float(x[1]), k, pop) - _valor_ws(sh, sp, k, pop)
	return r


## Los efectos de un edificio en líneas legibles: [«Salud +8 puntos (atiende ~150.000 habitantes)», ...] (vacío si no tiene efecto propio).
func lineas_efectos(e: int) -> PackedStringArray:
	var r := PackedStringArray()
	if not efectos_listos or e < 0 or e >= n:
		return r
	for x in (_ef_de[e] as Array):
		var k: int = x[0]
		var w: float = x[1]
		var cob: float = x[2]
		var t := ""
		match k:
			EF_SAL:
				t = "Salud +%s puntos de salud efectiva (baja la mortalidad)" % _num1(w * 100.0)
			EF_COM:
				t = "Comida segura +%s puntos de bienestar" % _num1(w)
			EF_URB:
				t = "Vivienda y ciudad +%s puntos de urbanización" % _num1(w * 100.0)
			EF_REN:
				t = "Producción +%s %% al terminar la obra" % _num1(w * 100.0)
			EF_ORD:
				t = "Orden y cohesión +%s puntos de estabilidad" % _num1(w)
			EF_DEF:
				t = "Defensa +%s %% al poder de los defensores" % _num1(w * 100.0)
			EF_MOV:
				t = "Movilidad: quita el %s %% del castigo de la distancia" % _num1(w * 100.0)
		if cob > 0.0:
			t += " (atiende ~%s habitantes)" % _miles(cob)
		r.append(t)
	return r


## Lo que hacen HOY los edificios de la provincia `pi`, en líneas para la interfaz: orden, defensa y movilidad (de todo lo construido) y salud, comida, vivienda y producción
## de lo construido desde que empezó la partida (lo de partida ya está en los datos de la época). Vacío si no hay nada que mostrar.
func resumen_efectos(pi: int) -> PackedStringArray:
	var r := PackedStringArray()
	if not efectos_listos or pi < 0 or pi >= mundo.provincias.size():
		return r
	var pob: float = mundo.provincias[pi].poblacion
	var o := efecto_abs(pi, EF_ORD, pob)
	if o >= 0.05:
		r.append("Orden y cohesión +%s puntos de estabilidad" % _num1(o))
	var df := efecto_abs(pi, EF_DEF)
	if df >= 0.005:
		r.append("Defensa +%s %% al poder de los defensores" % _num1(df * 100.0))
	var mv := efecto_abs(pi, EF_MOV)
	if mv >= 0.005:
		r.append("Movilidad: quita el %s %% del castigo de la distancia" % _num1(mv * 100.0))
	var nu := efectos_nuevos(pi, pob)
	if nu[0] >= 0.005:
		r.append("Salud +%s puntos (obras de la partida)" % _num1(nu[0] * 100.0))
	if nu[1] >= 0.05:
		r.append("Comida segura +%s puntos de bienestar (obras de la partida)" % _num1(nu[1]))
	if nu[2] >= 0.005:
		r.append("Vivienda +%s puntos de urbanización (obras de la partida)" % _num1(nu[2] * 100.0))
	var rn := efecto_nuevo(pi, EF_REN, pob)
	if rn >= 0.001:
		r.append("Producción +%s %% (obras de la partida)" % _num1(rn * 100.0))
	return r


## Todos los efectos de un edificio en una sola línea para la interfaz («Producción +2 % … · Orden +1 punto…»); vacío si no tiene; los de saber lo dicen aparte.
func texto_efectos(e: int) -> String:
	if not efectos_listos or e < 0 or e >= n:
		return ""
	var lineas := lineas_efectos(e)
	if lineas.is_empty():
		return "Cuenta como institución de saber: sube la alfabetización y los docentes." if ef_solo_saber.has(slug[e]) else ""
	return "Efectos: " + " · ".join(lineas)


func _num1(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


func _miles(v: float) -> String:
	var t := str(int(round(v)))
	var out := ""
	for i in t.length():
		if i > 0 and (t.length() - i) % 3 == 0:
			out += "."
		out += t[i]
	return out


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
