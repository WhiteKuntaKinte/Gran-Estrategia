extends RefCounted
## Entidades del juego (0.1.7.9.9D).
## Cada continente, país, estado, provincia y ciudad es un OBJETO con identidad propia. Desde 0.1.7.9.9B los DATOS
## variables (población, favorabilidad, dueño, tesorería, divisa...) ya no viven en el objeto sino en la BASE DE DATOS
## (scripts/base_datos.gd): una columna por variable, un solo valor por ID de territorio y el historial en tablas aparte.
## Los objetos exponen esos datos como propiedades normales (`pr.poblacion`, `pais.tesoreria`...): leer una propiedad
## lee la base y asignarla escribe en la base (archivando el valor anterior si la variable lleva historial).
## Jerarquía: Mundo(0) > Continente > País > (Estado) > Provincia > Ciudad.

const BaseDatosScript := preload("res://scripts/base_datos.gd")
const HistoriaScript := preload("res://scripts/historia.gd")
const EjercitoScript := preload("res://scripts/ejercito.gd")
const GuerraScript := preload("res://scripts/guerra.gd")
const MandosScript := preload("res://scripts/mandos.gd")
const RedProvinciasScript := preload("res://scripts/red_provincias.gd")
const IAScript := preload("res://scripts/ia.gd")
const PerfilScript := preload("res://scripts/perfil.gd")
const DescubrimientosScript := preload("res://scripts/descubrimientos.gd")

## Cuánto puede bajar lo que produce una provincia con devastación 1,0 (arrasada): -85 %. PROVISIONAL.
const DEVASTACION_EFECTO := 0.85
## Recuperación mensual de la devastación: pierde un 4 % de su valor más 0,002. PROVISIONAL.
const DEVASTACION_RECUPERA_REL := 0.04
const DEVASTACION_RECUPERA_ABS := 0.002


class Divisa extends RefCounted:
	var codigo := ""
	var nombre := ""
	var simbolo := ""
	var por_usd := 1.0            # unidades de esta divisa por 1 USD (cuanto menor, más valiosa)
	var variables := {}

	func valor_usd() -> float:
		return 1.0 / maxf(por_usd, 0.0000001)


class Ciudad extends RefCounted:
	var bd
	var tid := -1                 # ID único de territorio
	var id := 0                   # posición en Mundo.ciudades
	var nombre := ""
	var pos := Vector2.ZERO
	var rango_capital := 0        # 0 = ciudad, 1 = capital de provincia/estado, 2 = capital nacional
	var pais := ""
	var provincia := -1           # índice de provincia (-1 si no está dentro de ninguna)
	var zoom_min := 6.0
	var bandera := ""
	var variables := {}
	var poblacion: int:
		get:
			return int(bd.num("poblacion", tid))
		set(v):
			bd.poner_f("poblacion", tid, float(v))


class Provincia extends RefCounted:
	var bd
	var tid := -1                 # ID único de territorio
	var ix := -1                  # posición densa en la base de datos (acceso rápido a las columnas)
	var idx := 0                  # posición en Mundo.provincias
	var id := ""                  # código de origen (Natural Earth)
	var nombre := ""
	var estado := ""              # estado al que pertenece (solo EE. UU. por ahora)
	var pais_original := ""
	var anillos: Array = []
	var ciudades: Array = []      # ids de ciudades dentro de la provincia
	var bandera := ""
	var variables := {}

	## País actual (dueño). Vive en la variable `propietario`; su historial es el registro de soberanía.
	var pais: String:
		get:
			return bd.nombre_de(bd.ref("propietario", tid))
		set(v):
			bd.poner_i("propietario", tid, bd.id_de("pais", v))

	var poblacion: float:
		get:
			return bd.num("poblacion", tid)
		set(v):
			bd.poner_f("poblacion", tid, v)

	## Producción anual por habitante (US$). Viaja con la provincia: una provincia conquistada produce como en su origen.
	var pib_pc: float:
		get:
			return bd.num("pib_pc_usd", tid)
		set(v):
			bd.poner_f("pib_pc_usd", tid, v)

	## 0-100: opinión de la población hacia su dueño actual.
	var favorabilidad: float:
		get:
			return bd.num("favorabilidad", tid, 50.0)
		set(v):
			bd.poner_f("favorabilidad", tid, clampf(v, 0.0, 100.0))

	var mult_ingreso: float:
		get:
			return bd.num("mult_ingreso", tid, 1.0)
		set(v):
			bd.poner_f("mult_ingreso", tid, maxf(v, 0.0))

	var velocidad_desarrollo: float:
		get:
			return bd.num("velocidad_desarrollo", tid, 1.0)
		set(v):
			bd.poner_f("velocidad_desarrollo", tid, maxf(v, 0.0))

	## 0-1: daño por guerra (0 = intacta, 1 = arrasada). Reduce lo que produce y se recupera sola cada mes.
	var devastacion: float:
		get:
			return bd.num("devastacion", tid, 0.0)
		set(v):
			bd.poner_f("devastacion", tid, clampf(v, 0.0, 1.0))

	## Registro de dueños en orden cronológico: [{"pais", "desde", "hasta", "motivo"}] (el último es el actual).
	var propietarios: Array:
		get:
			var r := []
			for e in bd.historial_de("propietario", tid):
				r.append({"pais": bd.nombre_de(int(e["valor"])), "desde": BaseDatosScript.fecha_texto(int(e["desde"])),
					"hasta": BaseDatosScript.fecha_texto(int(e["hasta"])), "motivo": String(e["motivo"])})
			return r

	## Producción anual de la provincia en US$ (sin recaudar). Si pierdes la provincia pierdes esta fuente de ingresos.
	func ingreso_anual_usd() -> float:
		return pib_pc * poblacion * mult_ingreso

	## Lo que rendiría la provincia si nadie la ocupara: una población descontenta produce y paga menos (0,5x con favorabilidad 0; 1,5x con 100).
	func rendimiento_usd() -> float:
		return ingreso_anual_usd() * (0.5 + favorabilidad / 100.0) * (1.0 - DEVASTACION_EFECTO * devastacion)

	## Lo que realmente aporta a su dueño: 0 mientras esté ocupada por un enemigo (0.1.8.1).
	func ingreso_efectivo_usd() -> float:
		return 0.0 if ocupante >= 0 else rendimiento_usd()

	## ID del país que la ocupa en una guerra (-1 = nadie). El dueño sigue siendo `pais`.
	var ocupante: int:
		get:
			return bd.ref("ocupante", tid)

	func registrar_propietario(pais_nuevo: String, _fecha: String, motivo := "") -> void:
		bd.motivo_ctx = motivo
		pais = pais_nuevo

	func paises_con_registro() -> Array:
		var r := []
		for p in propietarios:
			if not r.has(p["pais"]):
				r.append(p["pais"])
		return r


class Estado extends RefCounted:
	var bd
	var tid := -1
	var nombre := ""
	var pais := ""
	var provincias: Array = []    # índices de provincia
	var bandera := ""
	var variables := {}


class Pais extends RefCounted:
	var bd
	var tid := -1
	var nombre := ""
	var a3 := ""
	var continente := ""
	var capital := ""
	var division := "Provincias"        # cómo llama el país a su primer nivel de división (Estados, Departamentos...)
	var division_provincia := ""        # nombre del nivel inferior si existe (EE. UU.: Condados)
	var inerte := false                 # 0.1.8.34: tierras sin reclamar de un escenario antiguo: sin gobierno, ejército ni IA; no se puede jugar ni atacar
	var bandera := ""
	var foco: Array = []                # [x, y, ancho, alto] del bloque principal de territorio (para el pop-out)
	var provincias: Array = []          # índices de provincia que controla hoy
	var ciudades: Array = []
	var historial: Array = []           # [{"tipo": "gano"/"perdio", "provincia", "con", "fecha", "motivo"}]
	var variables := {}

	var divisa: String:
		get:
			return bd.txt("divisa", tid, "USD")
		set(v):
			bd.poner_s("divisa", tid, v)

	var pib_usd: float:                  # PIB 2026 estimado (referencia de partida)
		get:
			return bd.num("pib_ref_2026_usd", tid)
		set(v):
			bd.poner_f("pib_ref_2026_usd", tid, v)

	var tesoreria: float:                # dinero acumulado, en unidades de SU divisa
		get:
			return bd.num("tesoreria", tid)
		set(v):
			bd.poner_f("tesoreria", tid, v)

	var tasa_fiscal: float:
		get:
			return bd.num("tasa_fiscal", tid, 0.25)
		set(v):
			bd.poner_f("tasa_fiscal", tid, clampf(v, 0.0, 1.0))

	var velocidad_desarrollo: float:
		get:
			return bd.num("velocidad_desarrollo", tid, 1.0)
		set(v):
			bd.poner_f("velocidad_desarrollo", tid, maxf(v, 0.0))

	## Nombre que ve el jugador (si lo personalizó); si no, el original.
	var nombre_visible: String:
		get:
			return bd.txt("nombre_visible", tid, nombre)
		set(v):
			bd.poner_s("nombre_visible", tid, "" if v == nombre else v)

	var anexado_a: String:               # país que lo absorbió ("" = independiente)
		get:
			var x: int = bd.ref("anexado_a", tid)
			return bd.nombre_de(x) if x >= 0 else ""
		set(v):
			bd.poner_i("anexado_a", tid, bd.id_de("pais", v) if v != "" else -1)

	func tiene_tesoreria() -> bool:
		return bd.tiene("tesoreria", tid)


class Continente extends RefCounted:
	var bd
	var tid := -1
	var nombre := ""
	var paises: Array = []
	var variables := {}


class Mundo extends RefCounted:
	const DIAS_TESORERIA_INICIAL := 60.0     # todos los países arrancan con 60 días de ingresos en caja
	const DESERCION_DIARIA := 0.004          # fracción de los soldados que se va cada día mientras la tesorería esté en rojo (PROVISIONAL)
	const MAX_EVENTOS := 300
	var bd                              # BaseDatos
	var historia                        # Historia: entidades políticas históricas, nombres, banderas y gobernantes con fechas
	var ejercito                        # Ejercito: pelotones y regimientos (null hasta que se llama iniciar_ejercito)
	var guerra                          # Guerra: guerras y batallas entre países (null hasta que se llama iniciar_ejercito)
	var mandos                          # Mandos: nombres de la cadena de mando por cultura
	var ia                              # IA: decisiones de los países controlados por el ordenador (0.1.8.2; ninguno al arrancar)
	var descubrimientos                 # Descubrimientos (0.1.8.36): catálogo con años + qué conoce cada país (null si falta datos/descubrimientos.json)
	var modo := "dev"                   # "dev" = mapa mundial, todo permitido · "campana" = solo Europa + Rusia + Turquía, conquista básica
	var campana := {}                   # (campaña) nombre de país -> true: los países que juegan
	var excluidas := {}                 # (campaña) índice de provincia -> true: las que NO existen en la campaña
	var continentes := {}
	var paises := {}
	var estados := {}                   # clave "País|Estado"
	var provincias: Array = []
	var ciudades: Array = []
	var divisas := {}                   # código -> Divisa
	var tasa_fiscal := 0.25             # tasa por defecto de los países nuevos (cada país tiene la suya en la base)
	var jugador := ""                   # país que controla el jugador ("" = observador)
	var _cache_prod := {}               # país -> [versión de la base, producción anual en US$]
	var avisos: Array = []              # 0.1.8.2a: avisos que piden un pop-up al jugador (guerra declarada, paz propuesta); la interfaz los saca y los atiende
	var eventos: Array = []             # sucesos recientes [{fecha, pais, otro, texto}] (los más nuevos al final); los lee la interfaz
	var version_eventos := 0            # sube con cada suceso nuevo
	var _en_rojo := {}                  # ID de país -> true mientras su tesorería está negativa (para avisar una sola vez)
	var desertores_total := 0           # soldados que se han ido por impago desde el principio (para pruebas y estadísticas)
	var ahorro := false                 # «modo ahorro» a velocidades altas (x4-x6): lo mensual cuesta menos (pelotones y provincias por grupos de meses, balances más espaciados)
	var grupos_mes := 3                 # 0.1.8.32: en modo ahorro, en cuántos grupos de meses se reparte el desarrollo mensual (x4: 3, x5: 6, x6: 12; ver MapaPrincipal._poner_velocidad)
	var _mes_n := 0                     # meses simulados (reparte los pelotones en tercios cuando `ahorro` está activo)
	var prof_fases := {}                # nombre de la fase -> [microsegundos totales, llamadas] (solo cuando el paso se corre de golpe: pruebas y Debug)

	## 0.1.8.3: sin país elegido (OBSERVADOR) se ven las tropas de TODOS los países y todas las columnas en marcha (también en la campaña).
	func ve_todo() -> bool:
		return jugador == ""

	## Países cuyas tropas se ven en el mapa: el que controla el jugador y, cuando existan, sus vasallos y aliados.
	## (0.1.7.9.9F; 0.1.8.3: el observador no pasa por aquí, ve todo: ver `ve_todo`.)
	func paises_visibles() -> Array:
		var r: Array = []
		if jugador != "" and paises.has(jugador):
			r.append(jugador)
			for v in relacionados_de(jugador):
				if paises.has(v) and not r.has(v):
					r.append(v)
		return r

	## GANCHO PARA EL FUTURO: vasallos y aliados de un país. Todavía no existen esas relaciones, así que no devuelve a nadie;
	## cuando existan basta con rellenar esta función y sus tropas aparecerán en el mapa.
	func relacionados_de(_pais: String) -> Array:
		return []

	## `hist_json` (opcional): {"entidades", "nombres", "banderas", "personas", "cargos"} leídos de datos/historico/ (null si falta).
	func cargar(prov_json: Array, ent: Dictionary, ciu: Dictionary, est_json: Dictionary, banderas: Dictionary,
			ids: Dictionary, catalogo: Dictionary, hist_json: Dictionary = {}, anio_inicio := 2026, desc_json: Dictionary = {}) -> void:
		historia = HistoriaScript.new()
		historia.leer_entidades(hist_json.get("entidades"))     # antes que la base: las entidades entran en ella como territorios
		bd = BaseDatosScript.new()
		bd.cargar(ids, catalogo, historia.filas_territorio())
		historia.bd = bd
		historia.leer_tablas(hist_json.get("nombres"), hist_json.get("banderas"), hist_json.get("personas"), hist_json.get("cargos"))
		bd.fecha = BaseDatosScript.fecha_int(anio_inicio, 1, 1)                  # 0.1.8.34: la partida empieza el 1 de enero del año del escenario
		descubrimientos = null                                                   # 0.1.8.36: los descubrimientos que ya existen en ese año (frontera histórica)
		if not desc_json.is_empty():
			var dsc = DescubrimientosScript.new()
			if dsc.cargar(desc_json):
				dsc.iniciar(anio_inicio)
				descubrimientos = dsc
		var raiz: int = bd.id_de("mundo", "mundo")
		bd.inicial_f("crecimiento_base_anual", raiz, 0.02)
		var ents: Dictionary = ent.get("paises", {})
		for nombre in ents:
			var e: Dictionary = ents[nombre]
			var p := Pais.new()
			p.bd = bd
			p.tid = bd.id_de("pais", nombre)
			p.nombre = nombre
			p.a3 = String(e.get("a3", ""))
			p.continente = String(e.get("cont", ""))
			p.capital = String(e.get("cap", ""))
			p.division = String(e.get("div", "Provincias"))
			p.division_provincia = String(e.get("div_prov", ""))
			p.inerte = bool(e.get("sin_reclamar", false))
			p.bandera = String(e.get("bandera", ""))
			p.foco = e.get("foco", [])
			paises[nombre] = p
			bd.inicial_f("tasa_fiscal", p.tid, tasa_fiscal)
			bd.inicial_f("velocidad_desarrollo", p.tid, 1.0)
			if not continentes.has(p.continente):
				var c := Continente.new()
				c.bd = bd
				c.tid = bd.id_de("continente", p.continente)
				c.nombre = p.continente
				continentes[p.continente] = c
			continentes[p.continente].paises.append(nombre)
		var bprov: Dictionary = banderas.get("provincias", {})
		for i in prov_json.size():
			var d: Dictionary = prov_json[i]
			var pr := Provincia.new()
			pr.bd = bd
			pr.tid = bd.id_de("provincia", String(d["id"]))
			pr.ix = bd.idx(pr.tid)
			pr.idx = i
			pr.id = String(d["id"])
			pr.nombre = String(d["n"])
			pr.estado = String(d.get("e", ""))
			pr.pais_original = String(d["c"])
			pr.anillos = d["r"]
			pr.bandera = String(bprov.get(pr.id, ""))
			bd.inicial_i("propietario", pr.tid, bd.id_de("pais", pr.pais_original))
			bd.inicial_f("favorabilidad", pr.tid, 50.0)
			bd.inicial_f("mult_ingreso", pr.tid, 1.0)
			bd.inicial_f("velocidad_desarrollo", pr.tid, 1.0)
			bd.inicial_f("devastacion", pr.tid, 0.0)
			provincias.append(pr)
			if paises.has(pr.pais_original):
				paises[pr.pais_original].provincias.append(i)
		var best: Dictionary = banderas.get("estados", {})
		for pais_n in est_json:
			for e in est_json[pais_n]:
				var es := Estado.new()
				es.bd = bd
				es.nombre = String(e["n"])
				es.pais = pais_n
				es.tid = bd.id_de("estado", "%s|%s" % [pais_n, es.nombre])
				es.provincias = e["pi"]
				es.bandera = String(best.get(es.nombre, ""))
				estados["%s|%s" % [pais_n, es.nombre]] = es
		var nombres_p: Array = ciu.get("paises", [])
		var cb: Dictionary = banderas.get("ciudades", {})
		var filas: Array = ciu.get("c", [])
		var vistas := {}
		for i in filas.size():
			var f: Array = filas[i]
			var c := Ciudad.new()
			c.bd = bd
			c.id = i
			c.nombre = String(f[0])
			c.pos = Vector2(float(f[1]), float(f[2]))
			c.rango_capital = int(f[4])
			c.pais = String(nombres_p[int(f[5])])
			c.provincia = int(f[6])
			c.zoom_min = float(f[7])
			var prov_id := ""
			if c.provincia >= 0 and c.provincia < provincias.size():
				prov_id = provincias[c.provincia].id
				provincias[c.provincia].ciudades.append(i)
				c.bandera = String(cb.get("%s|%s" % [c.nombre, provincias[c.provincia].estado], ""))
			var base := "%s|%s|%s" % [c.nombre, c.pais, prov_id]
			vistas[base] = int(vistas.get(base, 0)) + 1
			c.tid = bd.id_de("ciudad", base if int(vistas[base]) == 1 else "%s#%d" % [base, int(vistas[base])])
			bd.inicial_f("poblacion", c.tid, float(f[3]))
			if paises.has(c.pais):
				paises[c.pais].ciudades.append(i)
			ciudades.append(c)

	# ───────────── Carga de datos económicos y geográficos en la base ─────────────
	## Divisas, PIB, población y datos físicos por provincia, y producción principal por país / estado / provincia.
	## `fn_principal` = función que, dado un dict de economia.json, devuelve {nombre, pct, rubro}.
	func cargar_economia(js_div: Dictionary, info_prov: Array, economia: Dictionary, fn_principal: Callable) -> void:
		for cod in js_div.get("divisas", {}):
			var d := Divisa.new()
			d.codigo = String(cod)
			d.nombre = String(js_div["divisas"][cod]["n"])
			d.simbolo = String(js_div["divisas"][cod]["s"])
			d.por_usd = float(js_div["divisas"][cod]["u"])
			divisas[cod] = d
		tasa_fiscal = float(js_div.get("tasa_fiscal", 0.25))
		var pj: Dictionary = js_div.get("paises", {})
		for nombre in pj:
			if paises.has(nombre):
				bd.inicial_s("divisa", paises[nombre].tid, String(pj[nombre]["d"]))
				bd.inicial_f("pib_ref_2026_usd", paises[nombre].tid, float(pj[nombre]["pib"]))
				bd.inicial_f("tasa_fiscal", paises[nombre].tid, tasa_fiscal)
		var pob_pais := {}
		for i in provincias.size():
			var pr: Provincia = provincias[i]
			if i < info_prov.size():
				var fila: Array = info_prov[i]
				bd.inicial_f("poblacion", pr.tid, float(fila[0]))
				bd.inicial_f("area_km2", pr.tid, float(fila[1]))
				bd.inicial_f("altitud_media_m", pr.tid, float(fila[2]))
				bd.inicial_f("altitud_max_m", pr.tid, float(fila[3]))
				if fila.size() > 4 and fila[4] is Array and fila[4].size() > 0:
					bd.inicial_s("bioma_principal", pr.tid, String(fila[4][0][0]))
				if fila.size() > 5:
					bd.inicial_s("reino_biogeografico", pr.tid, String(fila[5]))
			else:
				bd.inicial_f("poblacion", pr.tid, 0.0)
			pob_pais[pr.pais_original] = float(pob_pais.get(pr.pais_original, 0.0)) + pr.poblacion
		for pr in provincias:
			if paises.has(pr.pais_original):
				bd.inicial_f("pib_pc_usd", pr.tid, paises[pr.pais_original].pib_usd / maxf(float(pob_pais.get(pr.pais_original, 1.0)), 1.0))
			else:
				bd.inicial_f("pib_pc_usd", pr.tid, 0.0)
		# producción principal (de economia.json) por país y por región (estado o provincia con nombre propio)
		var por_nombre := {}
		for pr in provincias:
			var k: String = "%s|%s" % [pr.pais_original, pr.nombre]
			if not por_nombre.has(k):
				por_nombre[k] = pr.tid
		for nombre in economia.get("pais", {}):
			if paises.has(nombre):
				_poner_principal(paises[nombre].tid, economia["pais"][nombre], fn_principal)
		for k in economia.get("region", {}):
			var tid2: int = bd.id_de("estado", k)
			if tid2 < 0:
				tid2 = int(por_nombre.get(k, -1))
			if tid2 >= 0:
				_poner_principal(tid2, economia["region"][k], fn_principal)

	func _poner_principal(tid_: int, e: Dictionary, fn: Callable) -> void:
		var pp: Dictionary = fn.call(e)
		if pp.is_empty():
			return
		bd.inicial_s("produccion_principal", tid_, String(pp.get("nombre", "")))
		bd.inicial_f("produccion_principal_pct", tid_, float(pp.get("pct", 0.0)))
		bd.inicial_s("produccion_principal_rubro", tid_, String(pp.get("rubro", "")))

	# ───────────── Consultas ─────────────
	func divisa_de(pais: String) -> Divisa:
		if paises.has(pais) and divisas.has(paises[pais].divisa):
			return divisas[paises[pais].divisa]
		return divisas.get("USD")

	func poblacion_de(pais: String) -> float:
		var t := 0.0
		if paises.has(pais):
			var col: PackedFloat64Array = bd.vars["poblacion"].col_f
			for pi in paises[pais].provincias:
				t += col[provincias[int(pi)].ix]
		return t

	## Producción anual (ya ajustada por favorabilidad) de todas las provincias que controla el país, en US$.
	## Se guarda en caché hasta que cambie alguna variable económica de la base.
	func produccion_anual_usd(pais: String) -> float:
		if not paises.has(pais):
			return 0.0
		var c = _cache_prod.get(pais)
		if c != null and int(c[0]) == bd.version_eco:
			return float(c[1])
		var pob: PackedFloat64Array = bd.vars["poblacion"].col_f
		var pc: PackedFloat64Array = bd.vars["pib_pc_usd"].col_f
		var mu: PackedFloat64Array = bd.vars["mult_ingreso"].col_f
		var fa: PackedFloat64Array = bd.vars["favorabilidad"].col_f
		var dv: PackedFloat64Array = bd.vars["devastacion"].col_f
		var oc: PackedInt32Array = bd.vars["ocupante"].col_i
		var t := 0.0
		for pi in paises[pais].provincias:
			var k: int = provincias[int(pi)].ix
			if oc[k] >= 0:                                    # ocupada por un enemigo: no rinde nada a su dueño
				continue
			t += pc[k] * pob[k] * mu[k] * (0.5 + fa[k] / 100.0) * (1.0 - DEVASTACION_EFECTO * dv[k])
		_cache_prod[pais] = [bd.version_eco, t]
		return t

	func ingreso_diario_usd(pais: String) -> float:
		return produccion_anual_usd(pais) * paises[pais].tasa_fiscal / 365.25 if paises.has(pais) else 0.0

	func ingreso_diario_local(pais: String) -> float:
		var d := divisa_de(pais)
		return ingreso_diario_usd(pais) * (d.por_usd if d != null else 1.0)

	# ───────────── Gasto militar (0.1.7.9.9F-c) ─────────────
	## Factor de conversión de US$ a la divisa del país.
	func _por_usd(pais: String) -> float:
		var d := divisa_de(pais)
		return d.por_usd if d != null else 1.0

	## Soldados que mantiene el país (todos sus pelotones, también los que marchan).
	func soldados_de_pais(pais: String) -> int:
		if ejercito == null or not paises.has(pais):
			return 0
		return ejercito.soldados_de_pais(int(paises[pais].tid))

	## Mantenimiento de las tropas por día, en la divisa del país.
	func mantenimiento_diario_local(pais: String) -> float:
		if ejercito == null or not paises.has(pais):
			return 0.0
		return ejercito.mantenimiento_diario_usd(int(paises[pais].tid), soldados_de_pais(pais)) * _por_usd(pais)

	## Ingresos − mantenimiento por día (negativo = el país pierde dinero), en su divisa.
	func balance_diario_local(pais: String) -> float:
		return ingreso_diario_local(pais) - mantenimiento_diario_local(pais)

	## Precio por UNIDAD (1.000 soldados) en la divisa del país: {"mant": al año, "recl": pago único}.
	func precios_unidad_local(pais: String) -> Dictionary:
		if ejercito == null or not paises.has(pais):
			return {"mant": 0.0, "recl": 0.0}
		var p: Dictionary = ejercito.precios_unidad_usd(int(paises[pais].tid))
		var f := _por_usd(pais)
		return {"mant": float(p["mant"]) * f, "recl": float(p["recl"]) * f}

	## Costo de reclutar `n` soldados (divisa del país).
	func costo_reclutar_local(pais: String, n: int) -> float:
		if ejercito == null or not paises.has(pais):
			return 0.0
		return ejercito.costo_reclutar_usd(int(paises[pais].tid), n) * _por_usd(pais)

	## Recluta pagando de la tesorería (todos los países pagan desde 0.1.8.1; si la caja no alcanza, no se recluta).
	## `reg` ≥ 0 refuerza ese regimiento; si no, forma uno nuevo en `prov_tid`. Devuelve {"ok", "msg", "costo", "reg"}.
	func reclutar_pagando(pais: String, prov_tid: int, n: int, reg := -1) -> Dictionary:
		if ejercito == null or not paises.has(pais) or n <= 0:
			return {"ok": false, "msg": "No hay nada que reclutar."}
		var costo := costo_reclutar_local(pais, n)
		var e = paises[pais]
		var paga: bool = e.tiene_tesoreria()
		if e.provincias.is_empty():
			return {"ok": false, "msg": "Ese país ya no existe: no tiene provincias."}
		if costo > 0.0 and (not paga or e.tesoreria < costo):
			return {"ok": false, "msg": "No alcanza la tesorería: hacen falta %s." % _fmt_corto(costo)}
		var tocados: Array = ejercito.reclutar(int(e.tid), prov_tid, n, "Reclutamiento", reg)
		if tocados.is_empty():
			return {"ok": false, "msg": "No se pudo reclutar allí."}
		if paga:
			e.tesoreria = e.tesoreria - costo
		return {"ok": true, "costo": costo if paga else 0.0, "reg": ejercito.reg_ultimo,
			"msg": "Reclutados %d soldados%s." % [n, (" (costó %s)" % _fmt_corto(costo)) if paga else ""]}

	func _fmt_corto(x: float) -> String:
		var a := absf(x)
		var t: String
		if a >= 1.0e9:
			t = "%.2f mil millones" % (a / 1.0e9)
		elif a >= 1.0e6:
			t = "%.2f millones" % (a / 1.0e6)
		else:
			t = "%d" % int(roundf(a))
		return t.replace(".", ",")

	## Provincias del país que más aportan: [[índice, US$ efectivos]], de mayor a menor. Se calcula en UNA pasada por las columnas
	## (los condados de EE. UU. son 3.222 provincias: antes se ordenaban todas con objetos, 60 ms por llamada) y se guarda hasta que
	## cambie la economía (bd.version_eco). Guarda las 10 mayores; si se piden más, se recalcula con ese tamaño.
	var _cache_top := {}
	func top_provincias(pais: String, cuantas := 3) -> Array:
		if not paises.has(pais):
			return []
		var c = _cache_top.get(pais)
		if c == null or int(c[0]) != bd.version_eco or int(c[2]) < cuantas:
			var k: int = maxi(cuantas, 10)
			var pob: PackedFloat64Array = bd.vars["poblacion"].col_f
			var pc: PackedFloat64Array = bd.vars["pib_pc_usd"].col_f
			var mu: PackedFloat64Array = bd.vars["mult_ingreso"].col_f
			var fa: PackedFloat64Array = bd.vars["favorabilidad"].col_f
			var dv: PackedFloat64Array = bd.vars["devastacion"].col_f
			var oc: PackedInt32Array = bd.vars["ocupante"].col_i
			var lista := []
			var minimo := -1.0
			for pi in paises[pais].provincias:
				var ix: int = provincias[int(pi)].ix
				var v := 0.0
				if oc[ix] < 0:
					v = pc[ix] * pob[ix] * mu[ix] * (0.5 + fa[ix] / 100.0) * (1.0 - DEVASTACION_EFECTO * dv[ix])
				if lista.size() >= k and v <= minimo:
					continue
				var pos := lista.size()
				while pos > 0 and float(lista[pos - 1][1]) < v:
					pos -= 1
				lista.insert(pos, [int(pi), v])
				if lista.size() > k:
					lista.pop_back()
				if lista.size() >= k:
					minimo = float(lista[lista.size() - 1][1])
			c = [bd.version_eco, lista, k]
			_cache_top[pais] = c
		return (c[1] as Array).slice(0, cuantas)

	## Rendimiento total (US$/año, sin importar la ocupación) de las provincias del país y la parte que ocupa `por`: [total, ocupado, n, n_ocupadas].
	## Una pasada por las columnas (lo usa el puntaje de guerra de la diplomacia).
	func rendimiento_ocupado(pais: String, por: int) -> Array:
		var tot := 0.0
		var occ := 0.0
		var n := 0
		var n_oc := 0
		if paises.has(pais):
			var pob: PackedFloat64Array = bd.vars["poblacion"].col_f
			var pc: PackedFloat64Array = bd.vars["pib_pc_usd"].col_f
			var mu: PackedFloat64Array = bd.vars["mult_ingreso"].col_f
			var fa: PackedFloat64Array = bd.vars["favorabilidad"].col_f
			var dv: PackedFloat64Array = bd.vars["devastacion"].col_f
			var oc: PackedInt32Array = bd.vars["ocupante"].col_i
			for pi in paises[pais].provincias:
				var ix: int = provincias[int(pi)].ix
				var r: float = pc[ix] * pob[ix] * mu[ix] * (0.5 + fa[ix] / 100.0) * (1.0 - DEVASTACION_EFECTO * dv[ix])
				tot += r
				n += 1
				if oc[ix] == por:
					occ += r
					n_oc += 1
		return [tot, occ, n, n_oc]

	## Las 3 provincias más contentas (de mayor a menor) y las 3 más descontentas (de menor a mayor): [[[nombre, favorabilidad]...], [...]].
	## Una pasada por la columna y caché por versión (antes se ordenaban todas las provincias del país con objetos: 14 ms en EE. UU.).
	var _cache_fext := {}
	func extremos_favorabilidad(pais: String) -> Array:
		if not paises.has(pais):
			return [[], []]
		var c = _cache_fext.get(pais)
		if c != null and int(c[0]) == bd.version_eco:
			return c[1]
		var fa: PackedFloat64Array = bd.vars["favorabilidad"].col_f
		var mejores := []                                     # [[índice, valor]] de mayor a menor
		var peores := []                                      # de menor a mayor
		for pi in paises[pais].provincias:
			var v: float = fa[provincias[int(pi)].ix]
			if mejores.size() < 3 or v > float(mejores[2][1]):
				var pos := mejores.size()
				while pos > 0 and float(mejores[pos - 1][1]) < v:
					pos -= 1
				mejores.insert(pos, [int(pi), v])
				if mejores.size() > 3:
					mejores.pop_back()
			if peores.size() < 3 or v < float(peores[2][1]):
				var pos2 := peores.size()
				while pos2 > 0 and float(peores[pos2 - 1][1]) > v:
					pos2 -= 1
				peores.insert(pos2, [int(pi), v])
				if peores.size() > 3:
					peores.pop_back()
		var res := [[], []]
		for t in mejores:
			res[0].append([provincias[int(t[0])].nombre, float(t[1])])
		for t in peores:
			res[1].append([provincias[int(t[0])].nombre, float(t[1])])
		_cache_fext[pais] = [bd.version_eco, res]
		return res

	var _cache_fav := {}
	func favorabilidad_media(pais: String) -> float:
		if not paises.has(pais):
			return 0.0
		var c = _cache_fav.get(pais)
		if c != null and int(c[0]) == bd.version_eco:
			return float(c[1])
		var f: float = bd.media_ponderada("favorabilidad", "poblacion", _tids(pais))
		_cache_fav[pais] = [bd.version_eco, f]
		return f

	func _tids(pais: String) -> Array:
		var r := []
		for pi in paises[pais].provincias:
			r.append(provincias[int(pi)].tid)
		return r

	## Crea el ejército de 2026 y el generador de mandos. `js_ejercito` = datos/ejercito.json; `js_nombres` = datos/nombres_cultura.json.
	## Debe llamarse DESPUÉS de cargar_economia (necesita la población de cada provincia).
	func iniciar_ejercito(js_ejercito, js_nombres, js_vecinos = null) -> void:
		mandos = MandosScript.new()
		mandos.leer(js_nombres)
		ejercito = EjercitoScript.new()
		ejercito.mundo = self
		if js_vecinos is Dictionary and int(js_vecinos.get("n", 0)) == provincias.size():
			var red_p := RedProvinciasScript.new()
			red_p.leer(js_vecinos)
			if red_p.listo:
				ejercito.red = red_p
		if js_ejercito is Dictionary:
			ejercito.generar_inicial(js_ejercito)
		guerra = GuerraScript.new()
		guerra.iniciar(self)
		ia = IAScript.new()
		ia.iniciar(self)
		iniciar_tesorerias()

	## Nombre real del jefe de Estado de un país en una fecha (de Historia), o "" si no se conoce.
	func jefe_de_estado(pais: String, fecha: int) -> String:
		if historia == null or not paises.has(pais):
			return ""
		var mejor := ""
		var desde_mejor := -1
		for g in historia.gobernantes_en(paises[pais].tid, fecha):
			if String(g.get("cargo", "")) == "jefe de Estado" and int(g.get("desde", 0)) > desde_mejor:
				desde_mejor = int(g["desde"])
				mejor = String(g.get("nombre", ""))
		return mejor

	## Riesgo mensual de motín en una provincia (0-1). PROVISIONAL: sube con la devastación, con el descontento de la
	## población y con la poca familiaridad de las tropas que hay allí.
	func riesgo_motin(idx: int) -> float:
		var pr: Provincia = provincias[idx]
		var r := 0.03 + 0.40 * pr.devastacion + 0.25 * maxf(0.0, (50.0 - pr.favorabilidad) / 50.0)
		if ejercito != null:
			var res: Dictionary = ejercito.resumen(ejercito.en_provincia(pr.tid))
			if int(res["soldados"]) > 0:
				r += 0.20 * (1.0 - float(res["fam"]) / 100.0)
		return clampf(r, 0.0, 0.95)

	func fijar_jugador(pais: String) -> void:
		if es_inerte(pais):
			return
		var antes := jugador
		jugador = pais
		if pais != "" and paises.has(pais) and not paises[pais].tiene_tesoreria():
			paises[pais].tesoreria = ingreso_diario_local(pais) * DIAS_TESORERIA_INICIAL      # arranca con 60 días de ingresos
		if ia != null:
			ia.control_cambiado(antes, pais)            # 0.1.8.3: el país que sueltas lo lleva la IA; el que tomas deja de tenerla

	## Todos los países con provincias arrancan con 60 días de ingresos en caja (0.1.8.1; antes solo el del jugador).
	func iniciar_tesorerias() -> void:
		for nombre in paises:
			var e: Pais = paises[nombre]
			if e.provincias.is_empty() or e.tiene_tesoreria():
				continue
			bd.inicial_f("tesoreria", e.tid, ingreso_diario_local(nombre) * DIAS_TESORERIA_INICIAL)

	## Registra un suceso para la interfaz (el jugador ve los de su país).
	func evento(pais_tid: int, texto: String, otro_tid := -1) -> void:
		eventos.append({"fecha": bd.fecha, "pais": pais_tid, "otro": otro_tid, "texto": texto})
		if eventos.size() > MAX_EVENTOS:
			eventos = eventos.slice(eventos.size() - MAX_EVENTOS)
		version_eventos += 1

	## Sucesos que tocan a un país (más recientes primero).
	func eventos_de(pais_tid: int, maximo := 12) -> Array:
		var r := []
		for i in range(eventos.size() - 1, -1, -1):
			var ev: Dictionary = eventos[i]
			if int(ev["pais"]) == pais_tid or int(ev["otro"]) == pais_tid:
				r.append(ev)
				if r.size() >= maximo:
					break
		return r

	## Un día de economía para TODOS los países con provincias: cobran ingresos y pagan el mantenimiento de su ejército.
	## Escribe directo en la columna (190 países) y sube la versión una vez; el historial mensual lo cierra `cerrar_periodo`.
	## Con la tesorería en rojo, el ejército se va deshaciendo solo (deserción por impago) hasta que el balance lo permite.
	## Balance diario de cada país con provincias, guardado mientras no cambie la economía (bd.version_eco) ni los dueños (version_propietario):
	## [[ID país, fila en la base, nombre, ingreso diario local, mantenimiento diario local POR SOLDADO]]. Recalcular los 249 países cuesta ~9 ms;
	## con la caché, un día es una suma por país (el mantenimiento varía con los soldados, que sí cambian cada día).
	var _bal := []
	var _bal_ver_eco := -1
	var _bal_ver_prop := -1
	var _bal_mes := -100                # valor de `_mes_n` (meses simulados) cuando se armaron los balances

	func _armar_balances() -> void:
		_bal = []
		for nombre in paises:
			var e: Pais = paises[nombre]
			if e.provincias.is_empty():
				continue
			var ix: int = bd.idx(e.tid)
			if ix < 0:
				continue
			var por_sold := 0.0
			if ejercito != null:
				por_sold = ejercito.mantenimiento_diario_usd(e.tid, 1) * _por_usd(nombre)
			_bal.append([e.tid, ix, nombre, ingreso_diario_local(nombre), por_sold])
		_bal_ver_eco = bd.version_eco
		_bal_ver_prop = bd.version_propietario
		_bal_mes = _mes_n

	func _economia_dia(k := 1) -> void:
		var v = bd.vars.get("tesoreria")
		if v == null:
			return
		if _bal_ver_prop != bd.version_propietario or (_bal_ver_eco != bd.version_eco and (not ahorro or _mes_n - _bal_mes >= maxi(grupos_mes, 3))):
			_armar_balances()
		var col: PackedFloat64Array = v.col_f
		var sold: Dictionary = ejercito.soldados_por_pais() if ejercito != null else {}
		var rojos := {}
		for f in _bal:
			var tid: int = f[0]
			var ix: int = f[1]
			if is_nan(col[ix]):                                              # país que vuelve a existir: arranca con 60 días de ingresos
				col[ix] = float(f[3]) * DIAS_TESORERIA_INICIAL
				v.desde[ix] = bd.fecha
			col[ix] += (float(f[3]) - float(sold.get(tid, 0)) * float(f[4])) * float(k)     # k días de golpe (0.1.8.3)
			if col[ix] < 0.0:
				rojos[tid] = true
				if not _en_rojo.has(tid):
					_en_rojo[tid] = true
					evento(tid, "La tesorería de %s está en rojo: sin dinero para pagar al ejército, los soldados empezarán a desertar." % String(f[2]))
				if ejercito != null and int(sold.get(tid, 0)) > 0:
					desertores_total += ejercito.desertar_pais(tid, 1.0 - pow(1.0 - DESERCION_DIARIA, float(k)))
		for tid in _en_rojo.keys():
			if not rojos.has(tid):
				_en_rojo.erase(tid)
				evento(int(tid), "%s salió del rojo: la tesorería vuelve a ser positiva." % bd.nombre_de(int(tid)))
		bd.version += 1

	# ───────────── Modo campaña (0.1.8.2) ─────────────
	func es_campana() -> bool:
		return modo == "campana"

	func provincia_excluida(pi: int) -> bool:
		return not excluidas.is_empty() and excluidas.has(pi)

	func tiene_ia(pais: String) -> bool:
		return ia != null and ia.activas.has(pais)

	## Países de la campaña: los 49 de Europa + Rusia y Turquía enteras (51).
	const CAMPANA_EXTRA := ["Rusia", "Turquía"]
	## Provincias que se quitan aunque su país juegue: islas y territorios lejos de Europa (claves «País|Provincia»).
	const CAMPANA_QUITAR := ["España|Santa Cruz de Tenerife", "España|Las Palmas", "Portugal|Madeira", "Portugal|Azores",
		"Francia|Guayana Francesa", "Francia|Martinica", "Francia|Guadalupe", "Francia|Reunión", "Francia|Mayotte",
		"Países Bajos|Bonaire", "Países Bajos|San Eustaquio", "Noruega|Isla Bouvet"]

	func paises_de_campana() -> Array:
		var r := []
		if continentes.has("Europa"):
			for n in continentes["Europa"].paises:
				r.append(String(n))
		for n in CAMPANA_EXTRA:
			if paises.has(n) and not r.has(n):
				r.append(n)
		return r

	## Convierte el mundo en la CAMPAÑA: solo existen los países de `lista` (menos las provincias de `quitar`, claves «País|Provincia»).
	## Los demás países pasan a no tener provincias (como si no existieran), sus ejércitos se disuelven y sus provincias quedan
	## «excluidas»: no se pintan, no se pueden elegir y ninguna marcha pasa por ellas. Hay que llamarlo antes de elegir país.
	func iniciar_campana(lista: Array, quitar: Array) -> void:
		modo = "campana"
		campana = {}
		for n in lista:
			if paises.has(String(n)):
				campana[String(n)] = true
		var fuera := {}
		for q in quitar:
			fuera[String(q)] = true
		excluidas = {}
		for i in provincias.size():
			var pr: Provincia = provincias[i]
			if not campana.has(pr.pais) or fuera.has("%s|%s" % [pr.pais, pr.nombre]):
				excluidas[i] = true
		for nombre in paises:
			var e: Pais = paises[nombre]
			if not campana.has(nombre):
				e.provincias = []                                  # sin provincias = país que ya no existe (anexado)
			else:
				var quedan := []
				for pi in e.provincias:
					if not excluidas.has(int(pi)):
						quedan.append(pi)
				e.provincias = quedan
		if ejercito != null:
			ejercito.quitar_provincias_excluidas()
			if ejercito.red != null:
				ejercito.red.bloquear(excluidas)
		if bd != null:
			bd.version_eco += 1
			bd.version_propietario += 1

	## 0.1.8.25 · Si el país `pais_tid` entra en la provincia `pi` con tropas, ¿a qué país tendría que declararle la guerra antes? Devuelve el ID del país
	## dueño, o -1 si no hace falta (la provincia es suya, de un aliado o vasallo, no tiene dueño, o ya están en guerra). Es LA regla única:
	## la usan la orden de marcha (`Ejercito.ordenar_marcha_reg`), el aviso del mapa y el bloqueo de órdenes del jugador.
	func rival_por_entrar(pais_tid: int, pi: int) -> int:
		if guerra == null or ejercito == null:
			return -1
		var dueno: int = ejercito.dueno_de_provincia(pi)
		if dueno < 0 or dueno == pais_tid or guerra.en_guerra(pais_tid, dueno):
			return -1
		if es_inerte(bd.nombre_de(dueno)):                                # tierras sin reclamar: se recorren sin declarar guerra (no se conquistan)
			return -1
		if relacionados_de(bd.nombre_de(pais_tid)).has(bd.nombre_de(dueno)):
			return -1
		return dueno

	## ¿Puede `atacante` atacar a `defensor`? En el mundo libre, sí. En la campaña, solo entre países con IA y el jugador:
	## sin competencia (sin IA) no hay conquista.
	func puede_atacar(atacante: int, defensor: int) -> bool:
		var na: String = bd.nombre_de(atacante)
		var nd: String = bd.nombre_de(defensor)
		if es_inerte(na) or es_inerte(nd):                               # 0.1.8.34: las tierras sin reclamar no atacan ni se conquistan
			return false
		if not es_campana():
			return true
		return (na == jugador or tiene_ia(na)) and (nd == jugador or tiene_ia(nd))

	## 0.1.8.34: ¿es un territorio sin gobierno (tierras sin reclamar de un escenario antiguo)? No tiene ejército, ni IA, ni se puede controlar.
	func es_inerte(nombre: String) -> bool:
		return paises.has(nombre) and bool(paises[nombre].inerte)

	## Tabla de posiciones: los países con IA y el del jugador, con provincias, tropas, ingresos (US$ por día) y un puntaje combinado
	## (40 % provincias, 30 % tropas, 30 % ingresos, cada uno respecto al mejor de la tabla; máximo 100). De mayor a menor puntaje.
	func ranking() -> Array:
		var nombres := []
		if ia != null:
			for n in ia.activas:
				nombres.append(String(n))
		if jugador != "" and paises.has(jugador) and not nombres.has(jugador):
			nombres.append(jugador)
		var filas := []
		var mp := 1.0
		var mt := 1.0
		var mi := 1.0
		for n in nombres:
			if not paises.has(n) or (paises[n].provincias as Array).is_empty():
				continue
			var f := {"pais": n, "prov": (paises[n].provincias as Array).size(), "tropas": soldados_de_pais(n),
				"ingreso": ingreso_diario_usd(n), "ia": tiene_ia(n), "jugador": n == jugador}
			mp = maxf(mp, float(f["prov"]))
			mt = maxf(mt, float(f["tropas"]))
			mi = maxf(mi, float(f["ingreso"]))
			filas.append(f)
		for f in filas:
			f["puntaje"] = 100.0 * (0.4 * float(f["prov"]) / mp + 0.3 * float(f["tropas"]) / mt + 0.3 * float(f["ingreso"]) / mi)
		filas.sort_custom(func(a, b): return float(a["puntaje"]) > float(b["puntaje"]))
		return filas

	## Un día de juego: economía de todos los países, marchas, guerra (llegadas, batallas, ocupaciones).
	func avanzar_dia() -> void:
		avanzar_dias(1)

	## `k` días de golpe (0.1.8.3): el reloj junta los días debidos y los simula en un solo paso (nunca cruza un fin de mes).
	## Corre todas las fases de `fases_dias` una tras otra y anota cuánto tarda cada una en `prof_fases`.
	func avanzar_dias(k: int) -> void:
		for f in fases_dias(k):
			var t0 := Time.get_ticks_usec()
			while f.call() == true:                     # una fase que devuelve true tiene más trabajo pendiente: se vuelve a llamar
				pass
			PerfilScript.anotar(prof_fases, f.get_method(), t0)

	## 0.1.8.2a: el mismo paso partido en fases (en este orden). El juego en marcha las reparte entre fotogramas (cada fase es corta) para que los
	## FPS no caigan cuando hay cientos de columnas y decenas de batallas; las pruebas y el Debug las corren de golpe con `avanzar_dias`.
	## 0.1.8.3: cada fase sabe simular `k` días de una sola vez (economía × k, marchas de k días, batallas en sub-rondas, ocupaciones, IA con presupuesto).
	func fases_dias(k: int) -> Array:
		var r := [Callable(self, "_economia_dia").bind(k)]
		if ia != null:
			r.append(Callable(ia, "fase_dia").bind(k))      # las IA que toca (las más atrasadas y las que están en guerra primero) deciden, por lotes
		if ejercito != null:
			r.append(Callable(ejercito, "avanzar_dia").bind(k))     # las columnas en marcha avanzan k días
		if guerra != null:
			r.append(Callable(guerra, "fase_llegadas"))             # llegadas
			r.append(Callable(guerra, "fase_batallas").bind(k))     # batallas, por lotes
			r.append(Callable(guerra, "fase_ocupaciones").bind(k))  # ocupaciones
		return r

	## Desarrollo mensual: la producción por habitante crece según el crecimiento base y las velocidades de desarrollo
	## de la provincia y de su país dueño. Escribe directo en las columnas (7 mil provincias) y sube la versión una vez.
	## 0.1.8.32: en modo ahorro (x4-x6) cada mes solo se desarrolla 1/`grupos_mes` de las provincias, y esas con el crecimiento de `grupos_mes` meses
	## de golpe (crecer 12 meses de una vez da lo mismo que crecer 1 mes doce veces): a x6 son 12 meses por segundo y recorrer las 7.653 provincias
	## cada vez costaba más de 3 ms por mes.
	func avanzar_mes() -> void:
		var raiz: int = bd.id_de("mundo", "mundo")
		var base: float = bd.num("crecimiento_base_anual", raiz, 0.02)
		var vel_pais := {}
		for nombre in paises:
			vel_pais[paises[nombre].tid] = paises[nombre].velocidad_desarrollo
		var pc: PackedFloat64Array = bd.vars["pib_pc_usd"].col_f
		var vp: PackedFloat64Array = bd.vars["velocidad_desarrollo"].col_f
		var dueno: PackedInt32Array = bd.vars["propietario"].col_i
		var dv: PackedFloat64Array = bd.vars["devastacion"].col_f
		_mes_n += 1
		var g: int = maxi(grupos_mes, 1) if ahorro else 1
		var fg := float(g)
		var exp_g := 1.0 / 12.0 if g == 1 else fg / 12.0
		var rec_rel := 1.0 - DEVASTACION_RECUPERA_REL                  # la devastación se recupera: dv' = dv·rel − abs (g veces: forma cerrada)
		var rec_abs := DEVASTACION_RECUPERA_ABS
		if g > 1:
			rec_rel = pow(1.0 - DEVASTACION_RECUPERA_REL, fg)
			rec_abs = DEVASTACION_RECUPERA_ABS * (1.0 - rec_rel) / DEVASTACION_RECUPERA_REL
		for i in range(_mes_n % g, provincias.size(), g):
			var k: int = provincias[i].ix
			var v: float = vp[k] * float(vel_pais.get(dueno[k], 1.0))
			pc[k] *= pow(1.0 + base * v, exp_g)
			if dv[k] > 0.0:                      # recuperación natural de la devastación (no deja fila de historial)
				dv[k] = maxf(0.0, dv[k] * rec_rel - rec_abs)
		if ejercito != null:
			ejercito.avanzar_mes(_mes_n % g, g) if ahorro else ejercito.avanzar_mes()
		if descubrimientos != null:                                  # 0.1.8.36: cada año nuevo del reloj trae sus descubrimientos (11 de cada 12 meses no hace nada)
			descubrimientos.avanzar_a(BaseDatosScript.anio_de_fecha(bd.fecha))
		bd.version += 1
		bd.version_eco += 1

	## ¿El país `pais` (nombre) conoce el descubrimiento `sl` (slug)? Falso si no hay catálogo o el país/descubrimiento no existen.
	func conoce_descubrimiento(pais: String, sl: String) -> bool:
		if descubrimientos == null or not paises.has(pais):
			return false
		return descubrimientos.conoce_slug(paises[pais].tid, sl)

	## Una provincia cambia de país: ambos países y la propia provincia dejan registro.
	## 0.1.7.9.9F: (1) el país que se queda sin su ÚLTIMA provincia pasa a estar anexado a quien se la quedó (sin provincias, su
	## ejército pasa al nuevo dueño); (2) un país anexado que recupera una provincia vuelve a existir.
	func transferir_provincia(idx: int, destino: String, fecha: String, motivo := "") -> bool:
		if idx < 0 or idx >= provincias.size() or not paises.has(destino):
			return false
		var pr: Provincia = provincias[idx]
		var origen: String = pr.pais
		if origen == destino:
			return false
		if paises.has(origen):
			paises[origen].provincias.erase(idx)
			paises[origen].historial.append({"tipo": "perdio", "provincia": idx, "con": destino, "fecha": fecha, "motivo": motivo})
		paises[destino].provincias.append(idx)
		paises[destino].historial.append({"tipo": "gano", "provincia": idx, "con": origen, "fecha": fecha, "motivo": motivo})
		var m0: String = bd.motivo_ctx
		bd.motivo_ctx = motivo
		pr.registrar_propietario(destino, fecha, motivo)
		if pr.ocupante >= 0:
			bd.poner_i("ocupante", pr.tid, -1, "Cambio de dueño")      # un dueño nuevo: la ocupación anterior ya no tiene sentido
		pr.favorabilidad = 35.0          # una provincia recién cambiada de dueño empieza descontenta
		for cid in pr.ciudades:          # las ciudades cambian de país con su provincia
			var ci: Ciudad = ciudades[int(cid)]
			ci.pais = destino
			if paises.has(origen):
				paises[origen].ciudades.erase(int(cid))
			paises[destino].ciudades.append(int(cid))
		if paises[destino].anexado_a != "":
			paises[destino].anexado_a = ""                       # vuelve a existir
		if paises.has(origen) and paises[origen].provincias.is_empty() and paises[origen].anexado_a == "":
			_absorber(origen, destino)
		bd.motivo_ctx = m0
		return true

	## `origen` se quedó sin provincias: queda anexado a `destino`, su ejército pasa a `destino` y, si el jugador lo controlaba, el
	## control pasa a `destino`. Se llama con `bd.motivo_ctx` ya puesto (queda en el historial de la variable `anexado_a`).
	func _absorber(origen: String, destino: String) -> void:
		paises[origen].anexado_a = destino
		if ejercito != null:
			ejercito.transferir_tropas(paises[origen].tid, paises[destino].tid)
		if paises[origen].tiene_tesoreria():                               # la caja (si no es deuda) pasa al nuevo dueño, convertida a su moneda
			var caja: float = paises[origen].tesoreria
			if caja > 0.0:
				paises[destino].tesoreria = paises[destino].tesoreria + caja / _por_usd(origen) * _por_usd(destino)
			paises[origen].tesoreria = 0.0
		_en_rojo.erase(paises[origen].tid)
		if jugador == origen:
			jugador = destino

	## ¿Sigue existiendo el país? (tiene provincias). Un país anexado ya no existe en el mapa.
	func existe_pais(pais: String) -> bool:
		return paises.has(pais) and not paises[pais].provincias.is_empty()

	## Cambia la moneda de un país. La tesorería (si existe) se convierte para conservar su valor real en dólares.
	func cambiar_divisa(pais: String, codigo: String, motivo := "Cambio de divisa") -> bool:
		if not paises.has(pais) or not divisas.has(codigo):
			return false
		var e: Pais = paises[pais]
		var vieja: Divisa = divisa_de(pais)
		var nueva: Divisa = divisas[codigo]
		if vieja != null and vieja.codigo == codigo:
			return false
		var m0: String = bd.motivo_ctx
		bd.motivo_ctx = motivo
		if vieja != null and e.tiene_tesoreria():
			e.tesoreria = e.tesoreria / vieja.por_usd * nueva.por_usd
		e.divisa = codigo
		bd.motivo_ctx = m0
		return true

	func continente_de_provincia(idx: int) -> String:
		var pr: Provincia = provincias[idx]
		if paises.has(pr.pais):
			return paises[pr.pais].continente
		return ""

	## Países de origen de las provincias ajenas que ahora tiene `pais`.
	func origenes_ajenos(pais: String) -> Array:
		var r := {}
		if paises.has(pais):
			for pi in paises[pais].provincias:
				var o: String = provincias[int(pi)].pais_original
				if o != pais:
					r[o] = true
		return r.keys()

	## Un país pasa a ser parte de otro: todas sus provincias cambian de dueño (el ID de dueño de cada una pasa a ser el del
	## anexador) y quedan registradas. El país anexado se queda SIN provincias, con estado «anexado a X» y su ejército pasa al anexador.
	func anexar_pais(origen: String, destino: String, fecha: String, motivo := "Anexión") -> int:
		if origen == destino or not paises.has(origen) or not paises.has(destino):
			return 0
		var lista: Array = paises[origen].provincias.duplicate()
		var n := 0
		for pi in lista:
			if transferir_provincia(int(pi), destino, fecha, motivo):
				n += 1
		if paises[origen].anexado_a != destino:              # país que ya no tenía provincias: igual queda anexado
			var m1: String = bd.motivo_ctx
			bd.motivo_ctx = motivo
			_absorber(origen, destino)
			bd.motivo_ctx = m1
		return n
