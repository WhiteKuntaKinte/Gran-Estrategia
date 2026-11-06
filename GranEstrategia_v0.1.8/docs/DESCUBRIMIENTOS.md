# Descubrimientos (0.1.8.36)

Guía corta del sistema: dónde viven los datos, cómo se enlazan con el reloj y cómo se cambian.

## 1. Dónde viven y por qué
- **No están en `base_datos.gd`.** Esa base guarda *un valor por territorio y por fecha* (población, dueño, etc.). Un descubrimiento no pertenece a un territorio: es un dato **fijo** del juego (nombre, era, prerrequisitos, año) que no cambia durante la partida.
- Catálogo fijo: **`datos/descubrimientos.json`** (1.730 descubrimientos, 157 KB). Lo carga `scripts/descubrimientos.gd` y lo cuelga de `Mundo.descubrimientos`.
- Lo que sí cambia por país (qué conoce cada uno) es un estado aparte y muy barato (ver §3).

## 2. El enlace con el reloj: cada descubrimiento tiene un año
- Año entero con signo: antes de Cristo en negativo y sin año cero (`-44` = 44 a. C.). El reloj del juego cuenta el 1 a. C. como 0; esa diferencia de un año se ignora.
- **Regla:** un descubrimiento es conocido cuando `año del reloj >= año del descubrimiento`.
- La **frontera histórica** de una fecha = todos los descubrimientos con año ≤ esa fecha. Con ella cualquier partida puede empezar en cualquier época: el 1 d. C. arranca con 353 descubrimientos, 2026 con 1.699.
- Origen del año (columna `origen`, solo informativa): `h` = fecha histórica puesta a mano (a veces aproximada) · `a` = ajustada para respetar sus prerrequisitos y el rango de su era (351) · `x` = hipotético, futuro (31, era «Futuro hipotético»). La prehistoria usa años muy aproximados.
- Rangos por era: Prehistoria ≤ −10000 · Neolítico −10000…−3500 · Edad del Bronce −3500…−1200 · Antigüedad e Hierro −1200…500 · Edad Media 500…1450 · Renacimiento 1450…1650 · Ilustración 1650…1800 · Industrial 1800…1900 · Guerras mundiales 1900…1945 · Guerra Fría e información 1945…2000 · Presente 2000…2026 · Futuro hipotético ≥ 2027.

## 3. Estado por país
- Un país que nunca se tocó **no gasta memoria**: lee la frontera histórica.
- `conceder(tid, i)` / `quitar(tid, i)` (la futura investigación, el Debug) le dan al país su propia copia: 1 byte por descubrimiento (1,7 KB).
- Reloj: `Mundo.avanzar_mes()` llama a `descubrimientos.avanzar_a(año)` cada mes; solo trabaja cuando cambia el año. Un año normal trae 0–30 descubrimientos nuevos.
- Debug > fecha: `debug_fijar_fecha` llama a `sincronizar(año, true)`: todos los países vuelven a la historia pura de ese año (hacia atrás se pierden los descubrimientos más nuevos).
- Partida nueva: `Mundo.cargar(...)` → `iniciar(año de inicio)`.

## 4. Cómo se cambia el catálogo
Fuente de verdad (se edita a mano, **nunca el JSON**):
- `herramientas/descubrimientos/catalogo/*.txt`: qué hay, era, tipo y prerrequisitos (`a,b,(c|d)` = a Y b Y (c O d)).
- `herramientas/descubrimientos/anios.tsv`: el año de cada uno.

Luego: `python3 herramientas/construir_descubrimientos.py` (o `--solo-comprobar`). El script **no escribe nada** si falla alguna regla: prerrequisitos que existen, sin ciclos, todo con año, año ≥ año de sus prerrequisitos (y de una alternativa de cada grupo «o»), año dentro del rango de su era.

## 5. Qué NO hace todavía
- Todos los países comparten la misma frontera mundial: no hay difusión regional (un país del año 1 ya «sabe» el acueducto aunque su cultura no lo haya visto).
- No hay investigación ni coste: los descubrimientos aún no desbloquean unidades, edificios ni acciones.
- Se puede mirar y cambiar desde **Debug > Descub.** (lista alrededor de la fecha, buscador, ficha con prerrequisitos, conceder / quitar / volver a la historia).
