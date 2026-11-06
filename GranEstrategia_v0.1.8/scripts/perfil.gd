extends RefCounted
## Medición de tiempos por sección (0.1.8.25). Antes la IA, la guerra y el ejército tenían cada uno su copia de este contador; ahora hay una sola.
## Una tabla es un Dictionary «sección -> [microsegundos totales, llamadas, microsegundos de la llamada más lenta]». Se muestra en Debug > Rend. y en las pruebas de rendimiento.


## Suma a la `seccion` de `tabla` el tiempo transcurrido desde `t0_us` (un valor de `Time.get_ticks_usec()`) y una llamada; guarda también la más lenta.
static func anotar(tabla: Dictionary, seccion: String, t0_us: int) -> void:
	var a: Array = tabla.get(seccion, [0, 0, 0])
	var dt := Time.get_ticks_usec() - t0_us
	a[0] = int(a[0]) + dt
	a[1] = int(a[1]) + 1
	if a.size() < 3:
		a.append(0)
	a[2] = maxi(int(a[2]), dt)
	tabla[seccion] = a
