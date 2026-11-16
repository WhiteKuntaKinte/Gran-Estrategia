extends RefCounted
## DEMOGRAFÍA VIVA (0.1.8.47): la gente nace, muere, aprende y se muda a las ciudades.
##
## Hasta la 0.1.8.46 la población era un dato fijo (la de 2026 o la del año de partida). Ahora cada provincia lleva su propia vida:
##   · NATALIDAD y MORTALIDAD (‰ por año) → crecimiento: la población sube o baja con (natalidad − mortalidad) × tiempo.
##   · ESTRUCTURA DE EDAD (niños 0-14 y mayores 65+; los adultos son lo que queda): sigue a la natalidad con ~35 años de rezago (un país joven envejece despacio).
##   · URBANIZACIÓN (0-1), ALFABETIZACIÓN (0-1) y ESCOLARIDAD MEDIA (años): se acercan despacio a la meta que permite lo que el país sabe y su riqueza.
##   · BIENESTAR (0-100): comida, vivienda, salud y paz. Entra en la estabilidad social y en la natalidad.
## Todo depende de lo que el país SABE (scripts/indices_saber.gd: salud, agricultura, educación, urbanismo, sacados del catálogo de descubrimientos) y del ACCESO a ese saber
## (la renta por habitante de la provincia: un país que conoce las vacunas sin dinero para aplicarlas sigue muriendo). No hay una tabla por época: el mismo modelo da la
## demografía de hace 2.000 años (natalidad ~45 ‰, mortalidad ~43 ‰, crecimiento casi 0) y la de hoy (natalidad ~17 ‰, mortalidad ~8 ‰), y cambia si el planeta descubre antes o después.
##
## Cómo corre: como FASE DEL DÍA en lotes (igual que la estabilidad): cada provincia se revisa una vez cada CICLO_DIAS días (120) con el tiempo REAL transcurrido desde su última
## revisión (si el reloj va rápido y la fase se atrasa, la provincia crece más de golpe: da lo mismo que crecer día a día). Escribe directo en las columnas de la base.
## Las MEDIAS por país (alfabetización, escolaridad, edades, urbanización, bienestar) se acumulan en la misma pasada y se publican cuando termina la vuelta.
## También lleva la FATIGA DE GUERRA de cada país y la calidad de sus docentes. TODAS las constantes son PROVISIONALES: ver docs/DEMOGRAFIA.md.

const IndicesScript := preload("res://scripts/indices_saber.gd")

const CICLO_DIAS := 120                    # cada provincia se revisa 3 veces al año (la demografía es lenta y los pasos son exactos: más a menudo solo costaba tiempo)
const CICLO_PAISES := 30                   # fatiga de guerra, decisiones de las IA: cada país una vez al mes
const LOTE := 70                           # provincias por llamada de fase (~0,3 ms)
const DIAS_ANIO := 365.25
const DT_MAX := 730.0                      # nunca se simula de golpe más de 2 años (un salto de fecha reinicia en vez de simular)

const NAT_MAX := 42.4                      # ‰ sin escuela ni ciudades (el mundo antiguo: ~39 ‰ con un poco de las dos)
const NAT_MIN := 7.0
const MORT_MAX := 44.0                     # ‰ sin medicina ni comida segura, con población joven
const MORT_FRENO := 14.0                   # ‰ extra como máximo por pasar el límite de lo que da la tierra (solo sociedades agrarias)
const PARTICIPACION := 0.78                # fracción de los adultos (15-64) que trabaja, estudia o puede reclutarse
const TAU_EDAD := 35.0                     # años que tarda la estructura de edad en seguir a la natalidad
const TAU_URB := 40.0
const TAU_ALFAB := 30.0
const TAU_ESC := 25.0
const TAU_BIENESTAR := 1.0

const GASTO_REF_EDU := 0.04                # con la partida de educación en este valor (fracción de los impuestos) todo rinde ×1
const GASTO_REF_SAN := 0.02
const GASTO_REF_CIE := 0.015
const GASTO_REF_OBR := 0.025
const ECO_K_REF := 0.8                     # saber medio (salud, agricultura, educación, urbanismo) desde el que la economía crece al ritmo base (2 % anual × velocidad)
const ECO_POTENCIA := 3.0                  # por debajo, el crecimiento cae con el cubo: el mundo antiguo apenas crece, y se acelera al descubrir
const ECO_MIN := 0.01
const FATIGA_POR_DIA := 0.10               # puntos de fatiga por día en guerra
const FATIGA_POR_BAJAS := 2500.0           # puntos por cada 100 % de la población que muere en combate (1 % = 25 puntos)
const FATIGA_TAU := 540.0                  # días que tarda la fatiga en caer a 1/e en paz

var mundo
var bd
var idx                                    # IndicesSaber
var listo := false
var _ult := PackedInt32Array()             # por posición en Mundo.provincias: día de juego de su última revisión
var _cursor := 0
var _pendiente := 0
var _en_paso := false
var _cur_p := 0                            # cursor de países (fatiga y docentes)
var _tids: Array = []                      # países con tierra y gobierno (se rehace cada vuelta)
var _obj := {}                             # ID de país -> objeto Pais (el mismo de `_tids`)
var _ci := {}                              # ID de país -> [salud efectiva sin acceso, agri, edu, urb, f_edu, f_san] (vive solo dentro de una llamada)
var _slot := {}                            # ID de país -> posición en los acumuladores
var _acum := PackedFloat64Array()          # ACUM_K valores por país: lo que se va sumando en la vuelta en curso
var _pub := PackedFloat64Array()           # lo publicado de la vuelta anterior
var _bajas := {}                           # ID de país -> bajas en combate desde la última revisión de su fatiga
var _ult_pais := {}                        # ID de país -> día de su última revisión de fatiga
var _txt_edif := PackedStringArray()       # por posición en Mundo.provincias: el texto de edificios con que se contaron las instituciones
var _peso_edu := {}                        # slug de edificio -> peso como institución de saber
var vueltas := 0                           # vueltas completas (todas las provincias revisadas) desde que empezó la partida
var revisadas := 0
var usec_total := 0
var ms_max := 0.0
var mundo_hab := 0.0                       # población mundial publicada (la de la última vuelta completa)
var guias_ia := true                       # las IA deciden su presupuesto y su política de investigación (Debug / pruebas pueden apagarlo)

const ACUM_K := 11                         # 0 hab · 1 alfab · 2 escolaridad · 3 jóvenes · 4 mayores · 5 urbanización · 6 bienestar · 7 natalidad · 8 mortalidad · 9 instituciones · 10 acceso
const K_POB := 0
const K_ALF := 1
const K_ESC := 2
const K_JOV := 3
const K_MAY := 4
const K_URB := 5
const K_BIE := 6
const K_NAT := 7
const K_MOR := 8
const K_INS := 9
const K_ACC := 10

# columnas de la base (se vuelven a pedir en cada llamada: pueden cambiar de sitio si la base crece)
var _pob: PackedFloat64Array
var _nat: PackedFloat64Array
var _mor: PackedFloat64Array
var _jov: PackedFloat64Array
var _may: PackedFloat64Array
var _urb: PackedFloat64Array
var _bie: PackedFloat64Array
var _alf: PackedFloat64Array
var _esc: PackedFloat64Array
var _ins: PackedFloat64Array
var _are: PackedFloat64Array
var _pcm: PackedFloat64Array
var _dev: PackedFloat64Array
var _ocu: PackedInt32Array
var _due: PackedInt32Array
var _gue: PackedFloat64Array


# ─────────────────────────────────────────────────────────────
# El modelo (funciones puras: las usan la fase, la siembra y las pruebas)
# ─────────────────────────────────────────────────────────────
## Acceso a los servicios (0-1) según la renta por habitante: 300 US$ → 0, 60.000 US$ → 1 (escala logarítmica).
static func acceso(pc: float) -> float:
	return clampf(log(maxf(pc, 100.0) / 300.0) / log(200.0), 0.0, 1.0)


## Resiliencia del país ante la muerte (0-1): 55 % lo que sabe de medicina y salud pública + 45 % lo que sabe de agricultura (menos hambrunas).
static func resiliencia(saber_salud: float, saber_agri: float) -> float:
	return 0.55 * saber_salud + 0.45 * saber_agri


## Salud efectiva (0-1): la resiliencia del país × cuánto de eso llega a la gente de la provincia (renta) × el gasto en sanidad.
static func salud_efectiva(res: float, acc: float, f_san: float) -> float:
	return clampf(res * (0.8 + 0.2 * acc) * (0.85 + 0.15 * minf(f_san, 2.0)), 0.0, 1.0)


## Cuántas veces cabe la población rural en lo que da la tierra con la agricultura que se sabe (límite maltusiano). 1 = en el límite.
static func presion_tierra(dens: float, urb: float, agri: float) -> float:
	var k := 4.0 + 70.0 * agri                              # hab/km²
	return dens * (1.0 - urb) / k


static func natalidad_de(sal_ef: float, alfab: float, urb: float, acc: float, bienestar: float, dev: float) -> float:
	var baja := clampf(0.50 * pow(alfab, 1.2) + 0.16 * urb + 0.18 * pow(acc, 1.3) + 0.05 * sal_ef, 0.0, 0.82)     # escuela, ciudad, renta y salud bajan la natalidad
	var n := NAT_MAX * (1.0 - baja) * (0.8 + 0.4 * bienestar / 100.0) * (1.0 - 0.35 * dev)
	return clampf(n, NAT_MIN, 60.0)


static func mortalidad_de(sal_ef: float, mayor: float, bienestar: float, dev: float, ocupada: bool, presion: float, agri: float) -> float:
	var sig_moderna := 1.0 / (1.0 + exp(-(sal_ef - 0.55) / 0.12))      # la medicina moderna: casi nada hasta que el saber madura, luego la mortalidad cae de golpe
	var sig_antigua := 1.0 / (1.0 + exp(-(sal_ef - 0.30) / 0.15))      # remedios, graneros y costumbres: una mejora lenta desde el principio
	var base := MORT_MAX * (1.0 - 0.70 * sig_moderna - 0.20 * sig_antigua)
	var m := base * (0.85 + 3.2 * mayor)                    # los viejos mueren más: un país con 29 % de mayores tiene casi el doble de mortalidad que uno joven
	m += maxf(0.0, 30.0 - bienestar) / 30.0 * 12.0          # hambre
	m += 30.0 * dev + (6.0 if ocupada else 0.0)             # guerra
	m += MORT_FRENO * minf(1.0, maxf(0.0, presion - 0.8)) * clampf(1.0 - agri / 0.6, 0.0, 1.0)
	return maxf(m, 1.5)


## Fracción de niños (0-14) de una población estable con esa natalidad.
static func joven_objetivo(nat: float) -> float:
	return clampf(0.04 + 0.0086 * nat, 0.08, 0.5)


## Fracción de mayores (65+) de una población estable con esa natalidad.
static func mayor_objetivo(nat: float) -> float:
	return 0.03 + 0.28 / (1.0 + exp((nat - 13.0) / 4.5))


static func urbanizacion_objetivo(saber_urb: float, acc: float, dens: float) -> float:
	var extra := 0.06 * clampf(log(dens + 1.0) / log(10.0) - 1.0, 0.0, 2.0)
	return clampf(0.02 + 0.80 * saber_urb * saber_urb * (0.25 + 0.75 * acc) + extra, 0.0, 0.97)


static func alfabetizacion_objetivo(saber_edu: float, acc: float, f_edu: float, ef_inst: float) -> float:
	var q := saber_edu * saber_edu * (0.45 + 0.55 * acc)
	return clampf(1.2 * q * (0.88 + 0.12 * minf(f_edu, 2.5)) * ef_inst, 0.0, 0.995)


static func escolaridad_objetivo(alfab: float, acc: float) -> float:
	return 12.5 * pow(alfab, 1.3) * (0.5 + 0.5 * acc)


static func bienestar_objetivo(agri: float, acc: float, sal_ef: float, dev: float, ocupada: bool, en_guerra: bool, presion: float) -> float:
	var b := 36.0 + 14.0 * agri + 26.0 * acc + 8.0 * sal_ef - 70.0 * dev
	if ocupada:
		b -= 22.0
	if en_guerra:
		b -= 4.0
	b -= 25.0 * clampf(presion - 0.8, 0.0, 1.0) * clampf(1.0 - agri / 0.6, 0.0, 1.0)
	return clampf(b, 0.0, 100.0)


## Multiplicador del crecimiento económico de un país según lo que sabe (0,01 a 1): con todo el saber de hoy vale 1; en el año 1 d. C. ~0,01; en 1500 ~0,06.
## Sin esto la renta por habitante crecía un 2 % anual en cualquier época y en 200 años el mundo antiguo era 50 veces más rico sin descubrir nada.
static func factor_economia_de(k_medio: float) -> float:
	return clampf(pow(k_medio / ECO_K_REF, ECO_POTENCIA), ECO_MIN, 1.0)


## Gente en edad de trabajar, estudiar o reclutarse, como fracción de la población.
static func activa_de(joven: float, mayor: float) -> float:
	return maxf(0.0, 1.0 - joven - mayor) * PARTICIPACION


## Un paso de `anios` años hacia la meta con constante de tiempo `tau` (años): exacto para cualquier tamaño de paso.
static func acercar(actual: float, meta: float, anios: float, tau: float) -> float:
	return meta + (actual - meta) * exp(-anios / tau)


# ─────────────────────────────────────────────────────────────
# Puesta en marcha
# ─────────────────────────────────────────────────────────────
func dia() -> int:
	return mundo.ia.dia_n if mundo.ia != null else 0


func iniciar(m) -> bool:
	mundo = m
	bd = m.bd
	listo = false
	for nombre in ["natalidad", "mortalidad", "edad_joven", "edad_mayor", "urbanizacion", "bienestar", "alfabetizacion", "escolaridad_media", "instituciones_saber", "fatiga_guerra"]:
		if not bd.vars.has(nombre):
			push_error("demografia: falta la variable %s en datos/variables.json" % nombre)
			return false
	if m.descubrimientos == null:
		return false
	idx = IndicesScript.new()
	if not idx.iniciar(m.descubrimientos):
		return false
	_peso_edu.clear()
	if m.edificios != null and m.edificios.listo:
		var ed = m.edificios
		for e in ed.n:
			if String(ed.cat[e]) == "edu":
				_peso_edu[String(ed.slug[e])] = 1.0 + 0.5 * float(maxi(ed.clase[e].unicode_at(0) - 66, 0))      # clase B = 1, C = 1,5, D = 2, E = 2,5…
	_ult.resize(m.provincias.size())
	_txt_edif.resize(m.provincias.size())
	_slot.clear()
	_bajas.clear()
	_ult_pais.clear()
	vueltas = 0
	revisadas = 0
	_cursor = 0
	_pendiente = 0
	_en_paso = false
	sembrar()
	listo = true
	return true


## Lleva a todas las provincias a su estado de equilibrio actual (inicio de partida y saltos de fecha del Debug).
func sembrar() -> void:
	idx.olvidar()
	_cargar_columnas()
	_ci.clear()
	_armar_slots()
	_acum.fill(0.0)
	var d := dia()
	for pi in mundo.provincias.size():
		_ult[pi] = d
		var ix: int = mundo.provincias[pi].ix
		var pop := _pob[ix]
		if is_nan(pop) or pop <= 0.0:
			continue
		var due: int = _due[ix]
		if due < 0:
			continue
		_estado_inicial(pi, ix, due)
		_sumar(pi, ix, due)
	_pub = _acum.duplicate()
	_acum.fill(0.0)
	_publicar_mundo()
	_ci.clear()
	_publicar_paises(true)


func _armar_slots() -> void:
	var tids := []
	for nombre in mundo.paises:
		tids.append(int(mundo.paises[nombre].tid))
	_slot.clear()
	for i in tids.size():
		_slot[int(tids[i])] = i
	_acum.resize(tids.size() * ACUM_K)
	_pub.resize(tids.size() * ACUM_K)


func _cargar_columnas() -> void:
	_pob = bd.vars["poblacion"].col_f
	_nat = bd.vars["natalidad"].col_f
	_mor = bd.vars["mortalidad"].col_f
	_jov = bd.vars["edad_joven"].col_f
	_may = bd.vars["edad_mayor"].col_f
	_urb = bd.vars["urbanizacion"].col_f
	_bie = bd.vars["bienestar"].col_f
	_alf = bd.vars["alfabetizacion"].col_f
	_esc = bd.vars["escolaridad_media"].col_f
	_ins = bd.vars["instituciones_saber"].col_f
	_are = bd.vars["area_km2"].col_f
	_pcm = bd.vars["pib_pc_usd"].col_f
	_dev = bd.vars["devastacion"].col_f
	_ocu = bd.vars["ocupante"].col_i
	_due = bd.vars["propietario"].col_i
	_gue = bd.vars["guerras_activas"].col_f


## Datos del país dueño que usan todas sus provincias: [resiliencia (salud + agricultura), saber de agricultura, de educación, de urbanismo, f_edu, f_san].
func _info(due: int) -> Array:
	var c = _ci.get(due)
	if c != null:
		return c
	var v: PackedFloat32Array = idx.de(due, dia())
	c = [resiliencia(float(v[IndicesScript.I_SALUD]), float(v[IndicesScript.I_AGRI])), float(v[IndicesScript.I_AGRI]), float(v[IndicesScript.I_EDU]), float(v[IndicesScript.I_URB]), clampf(bd.num("gasto_educacion", due, GASTO_REF_EDU) / GASTO_REF_EDU, 0.0, 2.5),
		clampf(bd.num("gasto_sanidad", due, GASTO_REF_SAN) / GASTO_REF_SAN, 0.0, 2.0)]
	_ci[due] = c
	return c


## Cuenta las instituciones de saber (escuelas, universidades, bibliotecas…) de una provincia a partir del texto de sus edificios, con peso por clase.
func _contar_instituciones(pi: int, ix: int) -> float:
	var t: String = bd.txt("edificios", int(mundo.provincias[pi].tid), "")
	if t == _txt_edif[pi] and not is_nan(_ins[ix]):
		return _ins[ix]
	_txt_edif[pi] = t
	var s := 0.0
	if t != "" and not _peso_edu.is_empty():
		for par in t.split(";"):
			var w = _peso_edu.get(par.get_slice(":", 0))
			if w != null:
				s += float(w) * float(par.get_slice(":", 1).to_int())
	return s


## Efecto de las instituciones de saber sobre la meta de alfabetización: 1,0 sin ninguna, hasta ~1,2 con varias por cada 100.000 habitantes.
static func efecto_instituciones(inst: float, pop: float) -> float:
	var por_100k := inst / (pop / 100000.0 + 0.3)
	return 1.0 + 0.2 * tanh(por_100k)


func _densidad(ix: int, pop: float) -> float:
	var a := _are[ix]
	return pop / a if (not is_nan(a) and a > 0.0) else 0.0


## Estado de equilibrio de una provincia (sin tiempo): lo que da el modelo con el saber de su país hoy.
func _estado_inicial(pi: int, ix: int, due: int) -> void:
	var c := _info(due)
	var pop := _pob[ix]
	var pc := _pcm[ix]
	var acc := acceso(pc if not is_nan(pc) else 300.0)
	var sal := salud_efectiva(c[0], acc, c[5])
	var dev := _dev[ix] if not is_nan(_dev[ix]) else 0.0
	var ocup: bool = _ocu[ix] >= 0 and _ocu[ix] != due
	var ix_p: int = bd.idx(due)
	var guerra: bool = ix_p >= 0 and _gue[ix_p] > 0.0
	var dens := _densidad(ix, pop)
	var inst := _contar_instituciones(pi, ix)
	_ins[ix] = inst
	var urb := urbanizacion_objetivo(c[3], acc, dens)
	var alf := alfabetizacion_objetivo(c[2], acc, c[4], efecto_instituciones(inst, pop))
	var pres := presion_tierra(dens, urb, c[1])
	var bie := bienestar_objetivo(c[1], acc, sal, dev, ocup, guerra, pres)
	var nat := natalidad_de(sal, alf, urb, acc, bie, dev)
	var may := mayor_objetivo(nat)
	var mor := mortalidad_de(sal, may, bie, dev, ocup, pres, c[1])
	_urb[ix] = urb
	_alf[ix] = alf
	_esc[ix] = escolaridad_objetivo(alf, acc)
	_bie[ix] = bie
	_jov[ix] = joven_objetivo(nat)
	_may[ix] = may
	_nat[ix] = nat
	_mor[ix] = mor


func _sumar(_pi: int, ix: int, due: int) -> void:
	var s: int = int(_slot.get(due, -1))
	if s < 0:
		return
	var o := s * ACUM_K
	var pop := _pob[ix]
	_acum[o + K_POB] += pop
	_acum[o + K_ALF] += pop * _alf[ix]
	_acum[o + K_ESC] += pop * _esc[ix]
	_acum[o + K_JOV] += pop * _jov[ix]
	_acum[o + K_MAY] += pop * _may[ix]
	_acum[o + K_URB] += pop * _urb[ix]
	_acum[o + K_BIE] += pop * _bie[ix]
	_acum[o + K_NAT] += pop * _nat[ix]
	_acum[o + K_MOR] += pop * _mor[ix]
	_acum[o + K_INS] += _ins[ix]
	var pc := _pcm[ix]
	_acum[o + K_ACC] += pop * acceso(pc if not is_nan(pc) else 300.0)


# ─────────────────────────────────────────────────────────────
# Fase del día
# ─────────────────────────────────────────────────────────────
## Revisa el 1/CICLO_DIAS de las provincias (por lotes) y la parte de los países que toca. Devuelve true mientras quede trabajo en este paso.
func fase_dia(k := 1) -> bool:
	if not listo:
		return false
	if not _en_paso:
		_en_paso = true
		_pendiente = mini(_pendiente + int(ceilf(float(mundo.provincias.size()) * float(k) / float(CICLO_DIAS))), mundo.provincias.size() * 2)
		_paises_del_dia(k)
	var t0 := Time.get_ticks_usec()
	var n := mini(_pendiente, LOTE)
	var d := dia()
	_cargar_columnas()
	_ci.clear()
	var total: int = mundo.provincias.size()
	for _j in n:
		var pi := _cursor
		_cursor += 1
		if _cursor >= total:
			_cursor = 0
			_cerrar_vuelta()
		_revisar(pi, d)
	_pendiente -= n
	revisadas += n
	var dt := Time.get_ticks_usec() - t0
	usec_total += dt
	ms_max = maxf(ms_max, float(dt) / 1000.0)
	if _pendiente <= 0:
		_pendiente = 0
		_en_paso = false
		return false
	return true


func _revisar(pi: int, d: int) -> void:
	var ix: int = mundo.provincias[pi].ix
	var pop := _pob[ix]
	var due: int = _due[ix]
	var ult: int = _ult[pi]
	_ult[pi] = d
	if is_nan(pop) or pop <= 0.0 or due < 0:
		return
	if is_nan(_alf[ix]):                                           # provincia que aún no tenía estado (apareció después de sembrar): arranca en equilibrio
		_estado_inicial(pi, ix, due)
		_sumar(pi, ix, due)
		return
	var dias := float(clampi(d - ult, 0, int(DT_MAX)))
	var c := _info(due)
	var anios := dias / DIAS_ANIO
	var pc := _pcm[ix]
	var acc := acceso(pc if not is_nan(pc) else 300.0)
	var sal := salud_efectiva(c[0], acc, c[5])
	var dev := _dev[ix] if not is_nan(_dev[ix]) else 0.0
	var ocup: bool = _ocu[ix] >= 0 and _ocu[ix] != due
	var ix_p: int = bd.idx(due)
	var guerra: bool = ix_p >= 0 and _gue[ix_p] > 0.0
	var dens := _densidad(ix, pop)
	var inst := _contar_instituciones(pi, ix)
	_ins[ix] = inst
	if anios > 0.0:
		# estados lentos: se acercan a su meta
		var urb := acercar(_urb[ix], urbanizacion_objetivo(c[3], acc, dens), anios, TAU_URB)
		var f_vel: float = 0.4 + 0.6 * float(c[4])                                       # más gasto en educación = convergencia más rápida
		var alf_meta := alfabetizacion_objetivo(c[2], acc, c[4], efecto_instituciones(inst, pop))
		var alf := acercar(_alf[ix], alf_meta, anios * f_vel, TAU_ALFAB)
		var pres := presion_tierra(dens, urb, c[1])
		var bie := acercar(_bie[ix], bienestar_objetivo(c[1], acc, sal, dev, ocup, guerra, pres), anios, TAU_BIENESTAR)
		var nat := natalidad_de(sal, alf, urb, acc, bie, dev)
		var jov := acercar(_jov[ix], joven_objetivo(nat), anios, TAU_EDAD)
		var may := acercar(_may[ix], mayor_objetivo(nat), anios, TAU_EDAD)
		var mor := mortalidad_de(sal, may, bie, dev, ocup, pres, c[1])
		_urb[ix] = urb
		_alf[ix] = alf
		_esc[ix] = acercar(_esc[ix], escolaridad_objetivo(alf, acc), anios, TAU_ESC)
		_bie[ix] = bie
		_jov[ix] = jov
		_may[ix] = may
		_nat[ix] = nat
		_mor[ix] = mor
		_pob[ix] = pop * exp((nat - mor) / 1000.0 * anios)
	_sumar(pi, ix, due)


func _cerrar_vuelta() -> void:
	vueltas += 1
	_pub = _acum.duplicate()
	_acum.fill(0.0)
	_publicar_mundo()
	_publicar_paises(false)
	if mundo.bd != null:
		mundo.bd.version += 1


func _publicar_mundo() -> void:
	var t := 0.0
	for s in _slot.size():
		t += _pub[s * ACUM_K + K_POB]
	mundo_hab = t


## Tras cada vuelta: la calidad de los docentes de cada país (0-100) sale de lo que sabe de educación, de sus instituciones por habitante y del gasto en ciencia.
func _publicar_paises(_todo: bool) -> void:
	var v = bd.vars.get("calidad_docentes")
	if v == null:
		return
	var col: PackedFloat64Array = v.col_f
	for tid in _slot:
		var o: int = int(_slot[tid]) * ACUM_K
		var pob: float = _pub[o + K_POB]
		if pob <= 0.0:
			continue
		var ix_p: int = bd.idx(int(tid))
		if ix_p < 0:
			continue
		var por_100k: float = _pub[o + K_INS] / (pob / 100000.0 + 0.3)
		var q: float = 100.0 * clampf(0.45 * float(idx.de(int(tid), dia())[IndicesScript.I_EDU]) + 0.30 * tanh(por_100k * 0.7) + 0.25 * minf(bd.num("gasto_ciencia", int(tid), GASTO_REF_CIE) / GASTO_REF_CIE, 2.0) / 2.0, 0.0, 1.0)
		col[ix_p] = q


# ─────────────────────────────────────────────────────────────
# Países: fatiga de guerra y refresco de índices de saber
# ─────────────────────────────────────────────────────────────
func _paises_del_dia(k: int) -> void:
	if _tids.is_empty() or _cur_p >= _tids.size():
		_tids = []
		_obj.clear()
		for nombre in mundo.paises:
			var p = mundo.paises[nombre]
			if not p.inerte and not (p.provincias as Array).is_empty():
				_tids.append(int(p.tid))
				_obj[int(p.tid)] = p
		_cur_p = 0
	var cuota := int(ceilf(float(_tids.size()) * float(k) / float(CICLO_PAISES)))
	var d := dia()
	idx.rotar(_tids, maxi(1, int(ceilf(float(_tids.size()) * float(k) / float(IndicesScript.CICLO_DIAS)))), d)
	var col = bd.vars["fatiga_guerra"].col_f
	var gue: PackedFloat64Array = bd.vars["guerras_activas"].col_f
	var hasta := mini(_tids.size(), _cur_p + cuota)
	while _cur_p < hasta:
		var tid: int = int(_tids[_cur_p])
		_cur_p += 1
		var ix_p: int = bd.idx(tid)
		if ix_p < 0:
			continue
		var ult: int = int(_ult_pais.get(tid, d))
		_ult_pais[tid] = d
		var dias := float(clampi(d - ult, 0, int(DT_MAX)))
		var f: float = col[ix_p] if not is_nan(col[ix_p]) else 0.0
		if guias_ia and mundo.educacion != null and mundo.ia != null and mundo.ia.activas.has(String(_obj[tid].nombre)):
			mundo.educacion.decidir_ia(_obj[tid], gue[ix_p] > 0.0, f)
		var o: int = int(_slot.get(tid, -1)) * ACUM_K
		var pob: float = _pub[o + K_POB] if o >= 0 else 0.0
		var bajas: float = float(_bajas.get(tid, 0.0))
		_bajas[tid] = 0.0
		if gue[ix_p] > 0.0:
			f += FATIGA_POR_DIA * dias + FATIGA_POR_BAJAS * bajas / maxf(pob, 100000.0)
		else:
			f = f * exp(-dias / FATIGA_TAU) - 0.01 * dias
			f += FATIGA_POR_BAJAS * bajas / maxf(pob, 100000.0)         # bajas que llegan justo al terminar la guerra
		f = clampf(f, 0.0, 100.0)
		if absf(f - (0.0 if is_nan(col[ix_p]) else col[ix_p])) > 0.005 or is_nan(col[ix_p]):
			col[ix_p] = f


## Lo llama la guerra: `n` soldados de `tid` murieron en combate (alimenta su fatiga de guerra).
func registrar_bajas(tid: int, n: int) -> void:
	if n > 0:
		_bajas[tid] = float(_bajas.get(tid, 0.0)) + float(n)


# ─────────────────────────────────────────────────────────────
# Consultas (interfaz, IA, pruebas)
# ─────────────────────────────────────────────────────────────
## Media ponderada por población de un campo de los acumuladores (K_ALF, K_ESC, K_JOV, K_MAY, K_URB, K_BIE, K_NAT, K_MOR) para un país; NAN si no hay datos.
func media_pais(tid: int, campo: int) -> float:
	var s: int = int(_slot.get(tid, -1))
	if s < 0:
		return NAN
	var o := s * ACUM_K
	var pob := _pub[o + K_POB]
	return _pub[o + campo] / pob if pob > 0.0 else NAN


func poblacion_pais(tid: int) -> float:
	var s: int = int(_slot.get(tid, -1))
	return _pub[s * ACUM_K + K_POB] if s >= 0 else 0.0


func instituciones_pais(tid: int) -> float:
	var s: int = int(_slot.get(tid, -1))
	return _pub[s * ACUM_K + K_INS] if s >= 0 else 0.0


## Crecimiento anual del país (fracción, p. ej. 0,009 = +0,9 %), de la última vuelta; NAN si no hay datos.
func crecimiento_pais(tid: int) -> float:
	var n := media_pais(tid, K_NAT)
	var m := media_pais(tid, K_MOR)
	return (n - m) / 1000.0 if not is_nan(n) else NAN


## Crecimiento anual del mundo (fracción) de la última vuelta.
func crecimiento_mundo() -> float:
	var pn := 0.0
	var pm := 0.0
	var pt := 0.0
	for s in _slot.size():
		var o := s * ACUM_K
		pn += _pub[o + K_NAT]
		pm += _pub[o + K_MOR]
		pt += _pub[o + K_POB]
	return (pn - pm) / 1000.0 / pt if pt > 0.0 else 0.0


## Resumen de varias provincias (índices de Mundo.provincias): población, medias ponderadas por población y suma de instituciones. Para la tarjeta «Gente» del panel.
## {pob, natalidad, mortalidad, joven, mayor, activa, urbanizacion, alfabetizacion, escolaridad, bienestar, instituciones, crecimiento}; todo en 0 si no hay gente.
func resumen_provincias(pis: Array) -> Dictionary:
	_cargar_columnas()
	var pob := 0.0
	var s_nat := 0.0
	var s_mor := 0.0
	var s_jov := 0.0
	var s_may := 0.0
	var s_urb := 0.0
	var s_alf := 0.0
	var s_esc := 0.0
	var s_bie := 0.0
	var inst := 0.0
	for pi in pis:
		var ix: int = mundo.provincias[int(pi)].ix
		var p := _pob[ix]
		if is_nan(p) or p <= 0.0 or is_nan(_alf[ix]):
			continue
		pob += p
		s_nat += p * _nat[ix]
		s_mor += p * _mor[ix]
		s_jov += p * _jov[ix]
		s_may += p * _may[ix]
		s_urb += p * _urb[ix]
		s_alf += p * _alf[ix]
		s_esc += p * _esc[ix]
		s_bie += p * _bie[ix]
		inst += 0.0 if is_nan(_ins[ix]) else _ins[ix]
	if pob <= 0.0:
		return {"pob": 0.0, "natalidad": 0.0, "mortalidad": 0.0, "joven": 0.0, "mayor": 0.0, "activa": 0.0, "urbanizacion": 0.0, "alfabetizacion": 0.0, "escolaridad": 0.0,
			"bienestar": 0.0, "instituciones": 0.0, "crecimiento": 0.0}
	var jov := s_jov / pob
	var may := s_may / pob
	return {"pob": pob, "natalidad": s_nat / pob, "mortalidad": s_mor / pob, "joven": jov, "mayor": may, "activa": activa_de(jov, may), "urbanizacion": s_urb / pob,
		"alfabetizacion": s_alf / pob, "escolaridad": s_esc / pob, "bienestar": s_bie / pob, "instituciones": inst, "crecimiento": (s_nat - s_mor) / pob / 1000.0}


## Gente en edad de trabajar, estudiar o reclutarse en el país `tid` (de la última vuelta publicada): su población × la fracción activa de sus edades. 0 si no hay datos.
## Lo usa la IA para limitar su ejército: un país envejecido, o con muchos niños, puede reclutar menos.
func activa_pais(tid: int) -> float:
	var pob := poblacion_pais(tid)
	if pob <= 0.0:
		return 0.0
	return pob * activa_de(media_pais(tid, K_JOV), media_pais(tid, K_MAY))


## Multiplicador del crecimiento económico del país `tid` (ver `factor_economia_de`): lo usa el desarrollo mensual de Mundo.
func factor_economia(tid: int) -> float:
	var v: PackedFloat32Array = idx.de(tid, dia())
	return factor_economia_de((float(v[IndicesScript.I_SALUD]) + float(v[IndicesScript.I_AGRI]) + float(v[IndicesScript.I_EDU]) + float(v[IndicesScript.I_URB])) * 0.25)


## Después de un salto de fecha del Debug o de cambiar saberes a mano: vuelve a contar lo que saben los países y reajusta a todas las provincias.
func reiniciar() -> void:
	if not listo:
		return
	_cursor = 0
	_pendiente = 0
	_en_paso = false
	_cur_p = 0
	_tids = []
	_bajas.clear()
	_ult_pais.clear()
	sembrar()
