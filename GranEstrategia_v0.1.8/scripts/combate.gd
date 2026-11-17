extends RefCounted
## COMBATE TÁCTICO (0.1.8.51): formaciones, cuadrícula de despliegue y resolutor de batalla.
##
## DATOS: `datos/combate.json` (lo genera `herramientas/construir_combate.py`; no se edita a mano): 10 clases de tropa (ARMAS), la matriz de quién gana a quién,
## las TROPAS (cada unidad, arma o vehículo descubierto da una clase con un NIVEL), 7 MEJORAS, 9 TERRENOS y ~48 FORMACIONES históricas. Cada formación exige un
## descubrimiento de táctica que ya existe en el catálogo (falange, legión manipular, tercios, columna de ataque, trincheras, guerra relámpago...).
##
## LA CUADRÍCULA: 8 columnas × 5 filas. Cada bando despliega en 4 columnas × 5 filas: el atacante a la izquierda (columna 0 = retaguardia, 3 = frente), el defensor
## a la derecha (x = 7 − columna). En cada casilla cabe un BLOQUE: una clase de tropa con parte de los soldados. Un CUADRO de formación son 5 × 4 letras de clase; el
## ejército se reparte entre sus casillas según el peso de cada clase (los cañones llevan pocos hombres, la infantería muchos).
##
## LA BATALLA (`simular`): hasta 24 rondas. Cada ronda los bloques avanzan hacia el enemigo (la caballería y los blindados llegan antes; los de tiro paran al tener
## el blanco a su alcance), eligen un blanco y le hacen bajas: soldados × clase × NIVEL × calidad × terreno × formación × matriz ÷ (defensa × nivel del blanco × formación del
## blanco). Atacar de lado o por la espalda suma daño; perder bajas, vecinos y flancos baja la moral; un bloque sin moral huye; si el ejército pierde casi toda su
## fuerza se rompe y la persecución (caballería, blindados) le cobra aún más. El azar sale de `azar.gd` (misma semilla = misma batalla).
##
## Lo estratégico: `factor_estrategico` da un pequeño bono por el NIVEL del ejército al poder de combate diario de `guerra.gd` (el que ya existía no lo tenía en cuenta);
## `Guerra.aplicar_tactico` mete el resultado de una batalla táctica en las tropas del mapa.

const AzarScript := preload("res://scripts/azar.gd")
const RUTA := "res://datos/combate.json"
const FILAS := 5
const COLS := 4
const ANCHO := 8                       # columnas de todo el tablero (4 + 4)
const MAX_RONDAS := 24
const K_BAJAS := 0.085                 # fracción de bajas por ronda entre dos bloques iguales frente a frente
const TOPE_BAJAS_RONDA := 0.45         # un bloque no pierde más de esto de sus soldados en una ronda
const FLANCO_BASE := 1.35              # daño extra al atacar de lado o por detrás
const COLAPSO := 0.60                  # un ejército que pierde esta fracción de su fuerza (o más) se rompe
const MORAL_POR_BAJAS := 110.0         # puntos de moral que cuesta perder el 100 % de un bloque en una ronda
const TEMA_AZAR := 7                   # tema de azar.gd (ver la lista de temas en azar.gd)
const MARGEN_EMPATE := 0.05            # diferencia de fuerza restante por debajo de la cual hay empate
const COBERTURA_MIN := 0.75            # lo que el terreno puede restar o sumar a la defensa de un bloque (según le siente bien o mal)
const COBERTURA_MAX := 1.45
const NIVEL_MIN := 0.25                # nivel que se supone a un país sin tropas conocidas
const FACTOR_ESTRATEGICO_EXP := 0.20   # el poder diario de guerra.gd se multiplica por nivel^0.20
## Si a una clase no la conoce el país, qué otras puede poner en su lugar (por orden).
const SUSTITUTOS := {"F": ["T", "I"], "T": ["I"], "L": ["P", "I"], "P": ["L", "I"], "C": ["c", "P"], "c": ["C", "I"], "A": ["T"], "B": ["C", "P"], "V": ["A"], "I": ["P"]}

var listo := false
var armas: Array = []
var n_armas := 0
var idx_arma := {}                     # "P" -> 0
var a_atq := PackedFloat32Array()
var a_tiro := PackedFloat32Array()
var a_def := PackedFloat32Array()
var a_mov := PackedInt32Array()
var a_alc := PackedInt32Array()
var a_moral := PackedFloat32Array()
var a_peso := PackedFloat32Array()
var matriz: Array = []                 # Array de PackedFloat32Array: matriz[atacante][defensor]
var tropas: Array = []                 # [slug, arma, nivel]
var mejoras: Array = []                # [{req, arma, contra, mult, texto}]
var terrenos: Array = []
var idx_terreno := {}
var biomas := {}
var alt_montana := 2500.0
var alt_colina := 900.0
var formaciones: Array = []
var idx_formacion := {}
var version_datos := ""


## Carga el catálogo desde datos/combate.json. Devuelve false si falta o está mal.
func iniciar() -> bool:
	var f := FileAccess.open(RUTA, FileAccess.READ)
	if f == null:
		listo = false
		return false
	var js = JSON.parse_string(f.get_as_text())
	if not (js is Dictionary):
		listo = false
		return false
	return cargar(js)


func cargar(js: Dictionary) -> bool:
	listo = false
	armas = js.get("armas", [])
	n_armas = armas.size()
	if n_armas == 0:
		return false
	idx_arma = {}
	a_atq.resize(n_armas)
	a_tiro.resize(n_armas)
	a_def.resize(n_armas)
	a_mov.resize(n_armas)
	a_alc.resize(n_armas)
	a_moral.resize(n_armas)
	a_peso.resize(n_armas)
	for i in n_armas:
		var a: Dictionary = armas[i]
		idx_arma[String(a["cod"])] = i
		a_atq[i] = float(a["atq"])
		a_tiro[i] = float(a["tiro"])
		a_def[i] = float(a["def"])
		a_mov[i] = int(a["mov"])
		a_alc[i] = int(a["alc"])
		a_moral[i] = float(a["moral"])
		a_peso[i] = float(a["peso"])
	matriz = []
	for fila in js.get("matriz", []):
		matriz.append(PackedFloat32Array(fila))
	if matriz.size() != n_armas:
		return false
	tropas = js.get("tropas", [])
	mejoras = js.get("mejoras", [])
	terrenos = js.get("terrenos", [])
	idx_terreno = {}
	for i in terrenos.size():
		idx_terreno[String(terrenos[i]["cod"])] = i
	biomas = js.get("biomas", {})
	alt_montana = float(js.get("alt_montana", 2500.0))
	alt_colina = float(js.get("alt_colina", 900.0))
	formaciones = js.get("formaciones", [])
	idx_formacion = {}
	for i in formaciones.size():
		idx_formacion[String(formaciones[i]["slug"])] = i
	version_datos = String(js.get("version", ""))
	listo = formaciones.size() > 0 and terrenos.size() > 0
	return listo


# ───────────────────────────── capacidad de un país ─────────────────────────────
## Lo que un país puede poner en el campo: {"nivel": PackedFloat32Array (por clase; 0 = no la tiene), "mej": [[arma, contra, mult]], "formaciones": PackedInt32Array}.
## `conoce` es un Callable que recibe el slug de un descubrimiento y dice si el país lo conoce.
func capacidad_por(conoce: Callable) -> Dictionary:
	var niv := PackedFloat32Array()
	niv.resize(n_armas)
	for t in tropas:
		var a: int = int(idx_arma.get(String(t[1]), -1))
		if a >= 0 and float(t[2]) > niv[a] and bool(conoce.call(String(t[0]))):
			niv[a] = float(t[2])
	var mej := []
	for m in mejoras:
		if bool(conoce.call(String(m["req"]))):
			mej.append([int(idx_arma.get(String(m["arma"]), -1)), int(idx_arma.get(String(m["contra"]), -1)), float(m["mult"])])
	var fs := PackedInt32Array()
	for k in formaciones.size():
		var req := String(formaciones[k]["req"])
		if req == "" or bool(conoce.call(req)):
			fs.append(k)
	return {"nivel": niv, "mej": mej, "formaciones": fs}


## Capacidad del país `tid` según el catálogo de descubrimientos `dsc`.
func capacidad(dsc, tid: int) -> Dictionary:
	return capacidad_por(func(sl: String) -> bool: return dsc.conoce_slug(tid, sl))


## Nivel del ejército: la media de sus tres mejores clases (un país sin nada conocido tiene NIVEL_MIN).
func nivel_ejercito(cap: Dictionary) -> float:
	var niv: PackedFloat32Array = cap["nivel"]
	var top := [0.0, 0.0, 0.0]
	for i in n_armas:
		var v := float(niv[i])
		if v > float(top[2]):
			top[2] = v
			top.sort()
			top.reverse()
	var s := 0.0
	var n := 0
	for v in top:
		if float(v) > 0.0:
			s += float(v)
			n += 1
	return maxf(s / float(n), NIVEL_MIN) if n > 0 else NIVEL_MIN


## Multiplicador del poder diario de guerra.gd por el nivel del ejército (nivel^0,20): el que tiene mejores tropas pelea mejor.
func factor_estrategico(cap: Dictionary) -> float:
	return pow(nivel_ejercito(cap), FACTOR_ESTRATEGICO_EXP)


# ───────────────────────────── terreno ─────────────────────────────
## Terreno (índice) de una provincia: sale del bioma y de la altitud. `bioma` es el código del juego (NTF, DES...), `alt_m` la altitud media.
func terreno_de(bioma: String, alt_m: float) -> int:
	var cod := "llano"
	if alt_m >= alt_montana:
		cod = "montana"
	else:
		cod = String(biomas.get(bioma, "llano"))
		if alt_m >= alt_colina and (cod == "llano" or cod == "bosque"):
			cod = "colina"
	return int(idx_terreno.get(cod, 0))


# ───────────────────────────── despliegue ─────────────────────────────
## La clase (índice) que va en una casilla del cuadro con la letra `ch` según lo que puede poner el país; -1 si no hay ninguna.
func resolver_letra(cap: Dictionary, ch: String) -> int:
	var niv: PackedFloat32Array = cap["nivel"]
	var grupos := {"M": ["P", "L", "I"], "R": ["F", "T"], "S": ["C", "c"]}
	if grupos.has(ch):
		var mejor := -1
		var mejor_n := 0.0
		for cod in grupos[ch]:
			var a: int = int(idx_arma[cod])
			if float(niv[a]) > mejor_n:
				mejor_n = float(niv[a])
				mejor = a
		return mejor
	var a0: int = int(idx_arma.get(ch, -1))
	if a0 < 0:
		return -1
	if float(niv[a0]) > 0.0:
		return a0
	for cod in SUSTITUTOS.get(ch, []):
		var a: int = int(idx_arma[cod])
		if float(niv[a]) > 0.0:
			return a
	return -1


## El cuadro de una formación ya resuelto para un país: [[fila, columna, clase]] (las casillas que su país sí puede llenar).
func cuadro_para(cap: Dictionary, f: int) -> Array:
	var r := []
	var cuadro: Array = formaciones[f]["cuadro"]
	for fila in FILAS:
		var linea := String(cuadro[fila])
		for col in COLS:
			var ch := linea.substr(col, 1)
			if ch == ".":
				continue
			var a := resolver_letra(cap, ch)
			if a >= 0:
				r.append([fila, col, a])
	if r.is_empty():                                              # un país sin ninguna de las clases pedidas: un bloque con lo mejor que tenga
		var niv: PackedFloat32Array = cap["nivel"]
		var mejor := 0
		for i in n_armas:
			if float(niv[i]) > float(niv[mejor]):
				mejor = i
		r.append([2, 3, mejor])
	return r


## Reparte `soldados` entre las casillas de un cuadro (peso de cada clase) y devuelve los BLOQUES: [{arma, n, n0, niv, cal, f, c, moral0}].
## `cal` es la calidad media de las tropas (1,0 = normal; viene de la experiencia, la forma física y la familiaridad).
func bloques_de(cap: Dictionary, cuadro: Array, f: int, soldados: float, cal := 1.0) -> Array:
	var niv: PackedFloat32Array = cap["nivel"]
	var suma := 0.0
	for c in cuadro:
		suma += float(a_peso[int(c[2])])
	var r := []
	if suma <= 0.0:
		return r
	var fm := float(formaciones[f]["moral"]) if f >= 0 else 0.0
	for c in cuadro:
		var a := int(c[2])
		var n := soldados * float(a_peso[a]) / suma
		r.append({"arma": a, "n": n, "n0": n, "niv": maxf(float(niv[a]), NIVEL_MIN), "cal": cal, "f": int(c[0]), "c": int(c[1]),
			"moral0": clampf(60.0 * float(a_moral[a]) + fm + (cal - 1.0) * 25.0, 15.0, 110.0)})
	return r


## Atajo: despliega `soldados` con la formación `f` para el país de capacidad `cap`.
func desplegar(cap: Dictionary, f: int, soldados: float, cal := 1.0) -> Array:
	return bloques_de(cap, cuadro_para(cap, f), f, soldados, cal)


## El bando completo listo para `simular`: {bloques, f, cap, local, bono_def}.
func bando(cap: Dictionary, f: int, soldados: float, cal := 1.0, local := false, bono_def := 0.0) -> Dictionary:
	return {"bloques": desplegar(cap, f, soldados, cal), "f": f, "cap": cap, "local": local, "bono_def": bono_def}


# ───────────────────────────── la batalla ─────────────────────────────
## Simula una batalla entre `A` (atacante, a la izquierda) y `D` (defensor, a la derecha) en el terreno `terreno` (índice). Devuelve:
##   {ganador: 0 atacante · 1 defensor · -1 empate, motivo, rondas, n0: [a, d], restan: [a, d], bajas: [a, d], frac_bajas: [a, d], fuerza: [a, d] (fracción de fuerza que queda),
##    bloques: [[...], [...]] (estado final de cada bloque: n, moral, huyo, x, y), registro: [[ronda: {pos, ataques}]] (solo si `registrar`)}
func simular(A: Dictionary, D: Dictionary, terreno: int, semilla: int, registrar := false) -> Dictionary:
	var ter: Dictionary = terrenos[terreno]
	var ter_mods: Dictionary = ter["mods"]
	var bando_d: Array = [A, D]
	var fo: Array = [formaciones[int(A["f"])], formaciones[int(D["f"])]]
	# todo en arreglos paralelos: el bloque `i` global; los del atacante primero
	var na: int = (A["bloques"] as Array).size()
	var nd: int = (D["bloques"] as Array).size()
	var nt := na + nd
	var X := PackedInt32Array()
	var Y := PackedInt32Array()
	var N := PackedFloat32Array()
	var N0 := PackedFloat32Array()
	var NIV := PackedFloat32Array()
	var CAL := PackedFloat32Array()
	var MOR := PackedFloat32Array()
	var ARM := PackedInt32Array()
	var LADO := PackedInt32Array()
	var VIVO := PackedByteArray()
	var HUYO := PackedByteArray()
	X.resize(nt)
	Y.resize(nt)
	ARM.resize(nt)
	LADO.resize(nt)
	N.resize(nt)
	N0.resize(nt)
	NIV.resize(nt)
	CAL.resize(nt)
	MOR.resize(nt)
	VIVO.resize(nt)
	HUYO.resize(nt)
	var i := 0
	for s in 2:
		for b in (bando_d[s] as Dictionary)["bloques"]:
			LADO[i] = s
			ARM[i] = int(b["arma"])
			N[i] = float(b["n"])
			N0[i] = float(b["n0"])
			NIV[i] = float(b["niv"])
			CAL[i] = float(b["cal"])
			MOR[i] = float(b["moral0"])
			Y[i] = int(b["f"])
			X[i] = int(b["c"]) if s == 0 else ANCHO - 1 - int(b["c"])
			VIVO[i] = 1 if N[i] > 0.0 else 0
			i += 1
	var mor0 := MOR.duplicate()
	var fuerza0 := [0.0, 0.0]
	for k in nt:
		fuerza0[LADO[k]] = float(fuerza0[LADO[k]]) + N0[k] * NIV[k]
	# multiplicadores por bloque que no cambian durante la batalla
	var ataque_m := PackedFloat32Array()         # lo que multiplica a su ataque (terreno de su clase × perfil de terreno de su formación × calidad × nivel)
	var defensa_m := PackedFloat32Array()        # su defensa total (clase × nivel × ventaja del que defiende)
	ataque_m.resize(nt)
	defensa_m.resize(nt)
	var terr_cod := String(ter["cod"])
	for k in nt:
		var s := int(LADO[k])
		var cod := String(armas[ARM[k]]["cod"])
		var fts: Dictionary = fo[s]["terreno"]
		ataque_m[k] = float(ter_mods.get(cod, 1.0)) * float(fts.get(terr_cod, 1.0)) * CAL[k] * NIV[k]
		var vent := 1.0
		var bs: Dictionary = bando_d[s]
		if bool(bs.get("local", false)):
			var bono := float(bs.get("bono_def", 0.0)) * (1.5 if bool(fo[s]["atrinch"]) else 1.0)
			vent = float(ter["defensor"]) * (1.0 + bono)
		var cubierto := clampf(sqrt(float(ter_mods.get(cod, 1.0)) * float(fts.get(terr_cod, 1.0))), COBERTURA_MIN, COBERTURA_MAX)   # el terreno que le sienta bien también lo protege
		defensa_m[k] = float(a_def[ARM[k]]) * NIV[k] * vent * cubierto
	var registro := []
	var rondas := 0
	var motivo := "agotamiento"
	var ganador := -1
	var resuelto := false
	for r in MAX_RONDAS:
		rondas = r + 1
		_mover(X, Y, ARM, LADO, VIVO, HUYO, nt)
		# ── ataques (todos a la vez: se acumulan y se aplican al final) ──
		var dano := PackedFloat32Array()
		dano.resize(nt)
		var flanqueado := PackedByteArray()
		flanqueado.resize(nt)
		var ataques := []
		for b in nt:
			if VIVO[b] == 0 or HUYO[b] == 1:
				continue
			var s := int(LADO[b])
			var t := _blanco(b, X, Y, ARM, LADO, VIVO, HUYO, N, nt)
			if t < 0:
				continue
			var ab := int(ARM[b])
			var at := int(ARM[t])
			var dx := absi(X[t] - X[b])
			var cuerpo := dx <= 1 and absi(Y[t] - Y[b]) <= 1
			var base := float(a_atq[ab]) if (cuerpo and a_atq[ab] > 0.0) else float(a_tiro[ab])
			if base <= 0.0:
				continue
			var fb: Dictionary = fo[s]
			var mult_f := float(fb["atq"]) if (cuerpo and a_atq[ab] > 0.0) else float(fb["tiro"])
			if r < 2:
				mult_f *= float(fb["apertura"])
			var fl := 1.0
			var dir := 1 if s == 0 else -1
			var detras := (X[t] - X[b]) * dir <= 0 and ab != int(idx_arma["V"])
			if detras:
				fl = FLANCO_BASE * float(fb["flanqueo"]) * float(fo[1 - s]["flanco"])
				flanqueado[t] = 1
			var m_ab := float((matriz[ab] as PackedFloat32Array)[at])
			var cap_b: Dictionary = (bando_d[s] as Dictionary)["cap"]
			for mj in cap_b["mej"]:
				if int(mj[0]) == ab and int(mj[1]) == at and float(mj[2]) > m_ab:
					m_ab = float(mj[2])
			var res := float((fo[1 - s]["res"] as Dictionary).get(String(armas[ab]["cod"]), 1.0))
			var ruido := 0.9 + 0.2 * AzarScript.u(semilla, TEMA_AZAR, r, b, t)
			var bajas := K_BAJAS * N[b] * base * ataque_m[b] * mult_f * m_ab * fl * float(fo[1 - s]["dano"]) * res * ruido / maxf(defensa_m[t], 0.05)
			dano[t] += bajas
			if registrar:
				ataques.append([b, t, bajas])
		# ── aplicar bajas, moral y huidas ──
		var muertos_ronda := PackedInt32Array()
		muertos_ronda.resize(nt)
		for t in nt:
			if VIVO[t] == 0 or HUYO[t] == 1:
				continue
			var antes := N[t]
			var baja := minf(float(dano[t]), antes * TOPE_BAJAS_RONDA)
			N[t] = antes - baja
			var cf := baja / maxf(antes, 1.0)
			MOR[t] -= cf * MORAL_POR_BAJAS
			if flanqueado[t] == 1:
				MOR[t] -= 6.0
			if cf < 0.005:
				MOR[t] = minf(MOR[t] + 1.5, mor0[t])
			if N[t] < 0.15 * N0[t] or MOR[t] <= 0.0:
				HUYO[t] = 1
				muertos_ronda[t] = 1
		for t in nt:                                                  # los vecinos de un bloque que huye pierden ánimo
			if VIVO[t] == 0 or HUYO[t] == 1:
				continue
			for u in nt:
				if muertos_ronda[u] == 1 and LADO[u] == LADO[t] and absi(X[u] - X[t]) <= 1 and absi(Y[u] - Y[t]) <= 1:
					MOR[t] -= 4.0
		if registrar:
			var pos := []
			for k in nt:
				pos.append([X[k], Y[k], N[k], MOR[k], HUYO[k]])
			registro.append({"pos": pos, "ataques": ataques})
		# ── ¿se rompió algún ejército? ──
		var viva := [0.0, 0.0]
		var campo := [0, 0]
		for k in nt:
			if HUYO[k] == 0 and VIVO[k] == 1:
				viva[LADO[k]] = float(viva[LADO[k]]) + N[k] * NIV[k]
				campo[LADO[k]] = int(campo[LADO[k]]) + 1
		var fra := float(viva[0]) / maxf(float(fuerza0[0]), 0.001)
		var frd := float(viva[1]) / maxf(float(fuerza0[1]), 0.001)
		var rota_a := fra <= 1.0 - COLAPSO or int(campo[0]) == 0
		var rota_d := frd <= 1.0 - COLAPSO or int(campo[1]) == 0
		if rota_a or rota_d:
			if rota_a and rota_d:
				ganador = 0 if fra > frd + MARGEN_EMPATE else (1 if frd > fra + MARGEN_EMPATE else -1)
			else:
				ganador = 1 if rota_a else 0
			motivo = "aniquilación" if (int(campo[0]) == 0 or int(campo[1]) == 0) else "ruptura del ejército"
			resuelto = true
			break
	# ── fin: persecución al que se rompió, o ganador por fuerza restante ──
	var viva2 := [0.0, 0.0]
	for k in nt:
		if HUYO[k] == 0 and VIVO[k] == 1:
			viva2[LADO[k]] = float(viva2[LADO[k]]) + N[k] * NIV[k]
	var fr := [float(viva2[0]) / maxf(float(fuerza0[0]), 0.001), float(viva2[1]) / maxf(float(fuerza0[1]), 0.001)]
	if not resuelto:
		ganador = 0 if float(fr[0]) > float(fr[1]) + MARGEN_EMPATE else (1 if float(fr[1]) > float(fr[0]) + MARGEN_EMPATE else -1)
	if resuelto and ganador >= 0:
		var perd := 1 - ganador
		var movil := 0.0                                              # parte de la fuerza del ganador que puede perseguir (caballería, blindados, aviación)
		var total := 0.0
		for k in nt:
			if LADO[k] == ganador and HUYO[k] == 0 and VIVO[k] == 1:
				total += N[k] * NIV[k]
				if a_mov[ARM[k]] >= 2:
					movil += N[k] * NIV[k]
		var cobro := 0.05 + 0.12 * (movil / maxf(total, 0.001))
		for k in nt:
			if LADO[k] == perd:
				N[k] = N[k] * (1.0 - cobro)
	var n0v := [0.0, 0.0]
	var restan := [0.0, 0.0]
	var salida_bloques := [[], []]
	for k in nt:
		n0v[LADO[k]] = float(n0v[LADO[k]]) + N0[k]
		restan[LADO[k]] = float(restan[LADO[k]]) + N[k]
		(salida_bloques[LADO[k]] as Array).append({"arma": ARM[k], "n": N[k], "n0": N0[k], "moral": MOR[k], "huyo": HUYO[k] == 1, "x": X[k], "y": Y[k]})
	var bajas_tot := [float(n0v[0]) - float(restan[0]), float(n0v[1]) - float(restan[1])]
	return {"ganador": ganador, "motivo": motivo if ganador != -1 else "empate", "rondas": rondas, "n0": n0v, "restan": restan, "bajas": bajas_tot,
		"frac_bajas": [float(bajas_tot[0]) / maxf(float(n0v[0]), 1.0), float(bajas_tot[1]) / maxf(float(n0v[1]), 1.0)], "fuerza": fr, "bloques": salida_bloques, "registro": registro}


## ¿Hay un bloque vivo en la casilla (x, y)?
func _ocupada(x: int, y: int, X: PackedInt32Array, Y: PackedInt32Array, VIVO: PackedByteArray, HUYO: PackedByteArray, nt: int) -> bool:
	for k in nt:
		if VIVO[k] == 1 and HUYO[k] == 0 and X[k] == x and Y[k] == y:
			return true
	return false


## Alcance de ataque de un bloque: distancia máxima en columnas y filas a las que puede golpear.
func _en_alcance(b: int, t: int, X: PackedInt32Array, Y: PackedInt32Array, ARM: PackedInt32Array) -> bool:
	var a := int(ARM[b])
	if a_tiro[a] > 0.0 and a_alc[a] >= 8:
		return true                                                   # aviación: cualquier punto del tablero
	var dx := absi(X[t] - X[b])
	var dy := absi(Y[t] - Y[b])
	if dx <= 1 and dy <= 1:
		return true                                                   # cuerpo a cuerpo (incluye las diagonales)
	if a_tiro[a] <= 0.0:
		return false
	return dx <= int(a_alc[a]) and dy <= (2 if a_alc[a] >= 3 else 1)


## Cada bloque avanza hacia el enemigo más cercano mientras no tenga a ninguno a su alcance. El primero en moverse es el que va más adelante.
func _mover(X: PackedInt32Array, Y: PackedInt32Array, ARM: PackedInt32Array, LADO: PackedInt32Array, VIVO: PackedByteArray, HUYO: PackedByteArray, nt: int) -> void:
	for s in 2:
		var dir := 1 if s == 0 else -1
		var orden := []
		for k in nt:
			if LADO[k] == s and VIVO[k] == 1 and HUYO[k] == 0:
				orden.append(k)
		orden.sort_custom(func(p, q): return X[p] * dir > X[q] * dir)
		for b in orden:
			for paso in int(a_mov[ARM[b]]):
				# ¿alguien a su alcance?
				var cerca := -1
				var dmin := 999
				var dy_mejor := 0
				for e in nt:
					if LADO[e] != s and VIVO[e] == 1 and HUYO[e] == 0:
						if _en_alcance(b, e, X, Y, ARM):
							cerca = e
							break
						var d: int = absi(X[e] - X[b]) + absi(Y[e] - Y[b])
						if d < dmin:
							dmin = d
							dy_mejor = signi(Y[e] - Y[b])
				if cerca >= 0 or dmin == 999:
					break
				var nx: int = X[b] + dir
				if nx < 0 or nx >= ANCHO:
					break
				if not _ocupada(nx, Y[b], X, Y, VIVO, HUYO, nt):
					X[b] = nx
				elif dy_mejor != 0 and Y[b] + dy_mejor >= 0 and Y[b] + dy_mejor < FILAS and not _ocupada(nx, Y[b] + dy_mejor, X, Y, VIVO, HUYO, nt):
					X[b] = nx
					Y[b] = Y[b] + dy_mejor
				else:
					break


## El blanco de un bloque: el enemigo más cercano a su alcance (a igual distancia, el que peor se defiende de su clase). La aviación elige el más valioso.
func _blanco(b: int, X: PackedInt32Array, Y: PackedInt32Array, ARM: PackedInt32Array, LADO: PackedInt32Array, VIVO: PackedByteArray, HUYO: PackedByteArray,
		N: PackedFloat32Array, nt: int) -> int:
	var s := int(LADO[b])
	var a := int(ARM[b])
	var mejor := -1
	var mejor_p := -1.0e9
	var aire: bool = a_tiro[a] > 0.0 and a_alc[a] >= 8
	for e in nt:
		if LADO[e] == s or VIVO[e] == 0 or HUYO[e] == 1:
			continue
		if not _en_alcance(b, e, X, Y, ARM):
			continue
		var m := float((matriz[a] as PackedFloat32Array)[ARM[e]])
		var p: float
		if aire:
			p = m * (1.0 + N[e] * 0.0005)
		else:
			p = -float(absi(X[e] - X[b]) + absi(Y[e] - Y[b])) * 10.0 + m
		if p > mejor_p:
			mejor_p = p
			mejor = e
	return mejor


# ───────────────────────────── elegir formación ─────────────────────────────
## La mejor formación de `cap` contra un rival que despliega `f_rival`, en ese terreno: prueba todas las que el país conoce con una batalla corta y se queda con la de mejor
## diferencia de fuerza. Cuesta unas decenas de milisegundos: se llama cuando el jugador pide una sugerencia o cuando la IA se despliega, no cada día.
func mejor_formacion(cap: Dictionary, cap_rival: Dictionary, f_rival: int, terreno: int, soldados: float, soldados_rival: float, local := false, bono_def := 0.0,
		atacante := true, semilla := 1) -> int:
	var fs: PackedInt32Array = cap["formaciones"]
	var mejor := int(idx_formacion.get("formacion_libre", 0))
	var mejor_p := -1.0e9
	var rival := bando(cap_rival, f_rival, soldados_rival, 1.0, not local, bono_def)
	for f in fs:
		var yo := bando(cap, int(f), soldados, 1.0, local, bono_def)
		var res: Dictionary = simular(yo, rival, terreno, semilla) if atacante else simular(rival, yo, terreno, semilla)
		var mi := 0 if atacante else 1
		var fr: Array = res["fuerza"]
		var p := float(fr[mi]) - float(fr[1 - mi])
		if res["ganador"] == mi:
			p += 1.0
		elif res["ganador"] == -1:
			p += 0.4
		if p > mejor_p:
			mejor_p = p
			mejor = int(f)
	return mejor


## Texto corto de una formación para fichas y listas.
func ficha_formacion(f: int) -> String:
	var fo: Dictionary = formaciones[f]
	var partes := []
	if absf(float(fo["atq"]) - 1.0) > 0.01:
		partes.append("Cuerpo a cuerpo %+d %%" % int(roundf((float(fo["atq"]) - 1.0) * 100.0)))
	if absf(float(fo["tiro"]) - 1.0) > 0.01:
		partes.append("Tiro %+d %%" % int(roundf((float(fo["tiro"]) - 1.0) * 100.0)))
	if absf(float(fo["dano"]) - 1.0) > 0.01:
		partes.append("Daño recibido %+d %%" % int(roundf((float(fo["dano"]) - 1.0) * 100.0)))
	if float(fo["flanco"]) >= 1.15:
		partes.append("débil de flancos")
	if float(fo["flanqueo"]) >= 1.15:
		partes.append("rodea al enemigo")
	if float(fo["apertura"]) >= 1.15:
		partes.append("golpe inicial")
	if int(fo["moral"]) != 0:
		partes.append("moral %+d" % int(fo["moral"]))
	return String(fo["desc"]) + ("\n" + " · ".join(partes) if not partes.is_empty() else "")
