extends RefCounted
## Reloj del juego (0.1.7.9.1, velocidades 4-6 en 0.1.7.9.9B): fecha AAAA,MM,DD con control de velocidad. Calendario gregoriano proléptico.
## Años <= 0 se cuentan astronómicamente (año 0 = 1 a. C.). Las épocas antiguas usarán el mismo reloj.

## Índice de velocidad: 0 = pausa, 1-3 = las de siempre, 4-6 = las tres rápidas extra (0.1.7.9.9B, se abren pulsando la fecha).
## 0.1.8.3: x4-x6 más rápidas (25, 83 y 370 días por segundo: x6 = un año por segundo) y, sobre todo, el reloj ya no simula ese ritmo día por día:
## junta los días que debe y los simula de una vez en PASOS de varios días (ver `avanzar` y `Mundo.avanzar_dias`), así el tiempo corre de verdad
## aunque el equipo sea modesto.
const SEG_POR_DIA := [0.0, 1.0, 0.4, 0.12, 0.04, 0.012, 0.0027]
const VEL_MAX := 6
const PRESUPUESTO_US := 9000       # microsegundos por fotograma que puede gastar la simulación de días (~9 ms)
const DIAS_MIN_PASO := [1, 1, 1, 1, 3, 8, 20]   # 0.1.8.3: días que deben acumularse para empezar un paso, según la velocidad (a x6 pasos de ~20-31 días: el coste fijo de cada paso se reparte)
const DIAS_MAX_PASO := 31          # 0.1.8.3: un paso nunca simula más de 31 días ni cruza el fin de mes (el desarrollo mensual corre una vez por mes)
const DIAS_DEUDA_MAX := 62         # y no se acumulan más de 62 días de deuda de tiempo (si el equipo no da abasto, el juego va más lento que la velocidad nominal)

var anio := 2026
var mes := 1
var dia := 1
var velocidad := 1
var acum := 0.0
var dias_totales := 0           # días transcurridos desde el inicio de la partida
var al_dia: Callable            # se llama al terminar cada día con (mes_nuevo: bool, anio_nuevo: bool)
var al_dia_diferido: Callable   # 0.1.8.2a: igual, pero lo usa SOLO `avanzar` (el juego en marcha): ese día se reparte en pasos entre fotogramas
var ocupado := false            # un día diferido sigue repartiéndose en pasos: `avanzar` no empieza otro hasta que termine
var _en_avanzar := false


static func bisiesto(a: int) -> bool:
	return posmod(a, 4) == 0 and (posmod(a, 100) != 0 or posmod(a, 400) == 0)


static func dias_mes(a: int, m: int) -> int:
	if m == 2:
		return 29 if bisiesto(a) else 28
	return 30 if m in [4, 6, 9, 11] else 31


func texto() -> String:
	return "%d,%02d,%02d" % [anio, mes, dia]


func fijar(a: int, m: int, d: int) -> void:
	anio = a
	mes = clampi(m, 1, 12)
	dia = clampi(d, 1, dias_mes(anio, mes))


func sumar_dia() -> void:
	sumar_dias(1)


## Avanza `k` días de golpe (0.1.8.3). Nunca cruza el fin de mes: se detiene como mucho en el día 1 del mes siguiente, de modo que el cambio de
## mes (y de año) ocurre exactamente una vez, igual que con días sueltos. Devuelve cuántos días avanzó de verdad (≤ k).
func sumar_dias(k: int) -> int:
	k = clampi(k, 1, DIAS_MAX_PASO)
	k = mini(k, dias_mes(anio, mes) - dia + 1)           # hasta el día 1 del mes siguiente, no más
	dia += k
	dias_totales += k
	var mes_nuevo := false
	var anio_nuevo := false
	if dia > dias_mes(anio, mes):
		dia = 1
		mes += 1
		mes_nuevo = true
		if mes > 12:
			mes = 1
			anio += 1
			anio_nuevo = true
	if _en_avanzar and al_dia_diferido.is_valid():
		al_dia_diferido.call(mes_nuevo, anio_nuevo, k)
	elif al_dia.is_valid():
		al_dia.call(mes_nuevo, anio_nuevo, k)
	return k


## Suma `delta` segundos reales al tiempo debido (sin simular nada). La deuda se acota: lo que el equipo no alcanza a simular se pierde, así el juego
## va más lento que lo nominal en equipos modestos, pero nunca se «atrasa» ni da saltos al cambiar de velocidad.
func acumular(delta: float) -> void:
	if velocidad <= 0:
		return
	var paso: float = SEG_POR_DIA[velocidad]
	var tope: float = minf(maxf(2.0 * paso * float(DIAS_MIN_PASO[velocidad]), 0.35), float(DIAS_DEUDA_MAX) * paso)
	acum = minf(acum + minf(delta, 0.25), tope)


## Avanza el reloj `delta` segundos reales. Devuelve cuántos días se simularon en esta llamada.
## 0.1.8.3: el tiempo debido (delta ÷ segundos por día) se simula en UN paso de varios días (máx. DIAS_MAX_PASO, sin cruzar el fin de mes), no día por
## día: el coste de un paso casi no depende de cuántos días contiene, así x6 pasa de verdad un año por segundo.
## Un aviso que pone `velocidad = 0` corta al instante.
func avanzar(delta: float) -> int:
	if velocidad <= 0:
		return 0
	acumular(delta)
	var paso: float = SEG_POR_DIA[velocidad]
	if ocupado or acum < paso * float(DIAS_MIN_PASO[velocidad]):
		return 0
	var debidos := int(floorf(acum / paso))
	_en_avanzar = true
	var n := sumar_dias(mini(debidos, DIAS_MAX_PASO))
	_en_avanzar = false
	acum -= float(n) * paso
	return n
