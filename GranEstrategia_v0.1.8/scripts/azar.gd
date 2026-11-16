extends RefCounted
## AZAR SIN ESTADO (0.1.8.46): números al azar que dependen SOLO de la semilla de la partida y de qué se pregunta, nunca de cuántos números se pidieron antes.
##
## Por qué: el motor de descubrimientos (scripts/saber.gd) y lo que venga después deben dar lo mismo si se repite una partida con la misma semilla, aunque el
## orden de las llamadas cambie (un país que decide antes o después, un lote más corto en un PC lento...). Con un generador con estado (`RandomNumberGenerator`)
## cualquier llamada de más lo desordena todo. Aquí cada pregunta tiene su propia respuesta: u(semilla, tema, a, b, c) siempre devuelve lo mismo.
##
## Solo usa enteros de 32 bits (los productos caben en 64 bits sin desbordar), así que da lo mismo en cualquier equipo.
##
## Temas (el segundo número) en uso: 1 riesgo mensual de un descubrimiento · 2 qué país lo descubre · 3 tardanza de un contacto · 4 vocación de un país por sección ·
## 5 viajeros lejanos · 6 aceptación por edificios (muestreo con rechazo). Quien añada uno debe sumarlo aquí para no repetir.

const MASCARA := 0xFFFFFFFF
const K := 0x45D9F3B


## Mezcla de 32 bits (dos rondas de multiplicar y desplazar).
static func mezcla(x: int) -> int:
	x &= MASCARA
	x = (((x >> 16) ^ x) * K) & MASCARA
	x = (((x >> 16) ^ x) * K) & MASCARA
	return ((x >> 16) ^ x) & MASCARA


## Un entero de 32 bits determinista para (semilla, tema, a, b, c).
static func entero(semilla: int, tema: int, a := 0, b := 0, c := 0) -> int:
	var h := mezcla(semilla + 0x9E3779B9)
	h = mezcla(h ^ (tema * 0x85EBCA6B))
	h = mezcla(h ^ (a & MASCARA))
	h = mezcla(h + (b & MASCARA) * 3 + 0x27D4EB2F)
	return mezcla(h ^ ((c & MASCARA) * 5 + 0x165667B1))


## Número en [0, 1) determinista para (semilla, tema, a, b, c).
static func u(semilla: int, tema: int, a := 0, b := 0, c := 0) -> float:
	return float(entero(semilla, tema, a, b, c)) / 4294967296.0


## Variable exponencial de media 1 (para tiempos de espera): -ln(1 - u).
static func expo(semilla: int, tema: int, a := 0, b := 0, c := 0) -> float:
	return -log(1.0 - u(semilla, tema, a, b, c))


## Semilla nueva para una partida que empieza ahora (el reloj del sistema mezclado con los microsegundos desde que arrancó el juego).
static func semilla_nueva() -> int:
	return mezcla(int(Time.get_unix_time_from_system()) ^ ((Time.get_ticks_usec() & 0xFFFFFF) * 2654435761)) & 0x7FFFFFFF
