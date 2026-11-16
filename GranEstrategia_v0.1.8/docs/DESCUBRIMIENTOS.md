# Descubrimientos (0.1.8.36 · actualizado en la 0.1.8.46)

Guía corta del sistema: dónde viven los datos, cómo se enlazan con el reloj y cómo se cambian.

## 1. Dónde viven y por qué
- **No están en `base_datos.gd`.** Esa base guarda *un valor por territorio y por fecha* (población, dueño, etc.). Un descubrimiento no pertenece a un territorio: es un dato **fijo** del juego (nombre, era, prerrequisitos, año) que no cambia durante la partida.
- Catálogo fijo: **`datos/descubrimientos.json`** (1.814 descubrimientos, 40 secciones, 158 subsecciones, 206 KB). Lo carga `scripts/descubrimientos.gd` y lo cuelga de `Mundo.descubrimientos`.
- Lo que sí cambia por país (qué conoce cada uno) es un estado aparte y muy barato (ver §3).

## 2. El enlace con el reloj: cada descubrimiento tiene un año
- Año entero con signo: antes de Cristo en negativo y sin año cero (`-44` = 44 a. C.). El reloj del juego cuenta el 1 a. C. como 0; esa diferencia de un año se ignora.
- **Regla:** un descubrimiento es conocido cuando `año del reloj >= año del descubrimiento`.
- La **frontera histórica** de una fecha = todos los descubrimientos con año ≤ esa fecha. Con ella cualquier partida puede empezar en cualquier época: el 1 d. C. arranca con 360 descubrimientos, 2026 con 1.740.
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

## 5. Recetas y enlaces (0.1.8.46)
Cada descubrimiento lleva además una **receta**, escrita a mano en `herramientas/receta_descubrimientos.py` (con su «porqué», que el jugador lee en la ficha):
- **Prerrequisitos** (`req`, `req_o`): DUROS. Nadie descubre ni aprende algo sin conocer sus previos. Incluye los **enlaces extra** de `herramientas/descubrimientos/enlaces.txt` (`slug|requisito|porqué`, 49 líneas: p. ej. la brújula pide el oficio de navegante).
- **Edificios** (`edif`): grupos «basta uno de cada grupo» de edificios (los edificios y los descubrimientos de tipo B comparten slug). Un país sin ese edificio puede descubrirlo igual, pero con ×0,15 por cada grupo que le falta (mínimo ×0,01).
- **Materias primas** (`mat`, de `economia.json`): ×1,4 si el país produce alguna (×1,2 si no hay datos de su economía; son de 2026 y gruesos, así que solo ayudan, nunca bloquean).
El generador **comprueba** que cada grupo de edificios se pueda cumplir a la fecha del descubrimiento y que no haya ciclos. Resultado: 1.177 descubrimientos con edificios, 431 con materias, 28 grupos descartados por anacrónicos.
Los 41 descubrimientos nuevos de la 0.1.8.46 viven en `catalogo/z_cimientos_0.1.8.46.txt` (`## +RAMA|COD` reabre una sección ya existente; archivos, estadística, escuelas, recursos, transporte, comercio…).

## 6. El planeta descubre (0.1.8.46)
- **Partida nueva = modo «el planeta descubre»** (`scripts/saber.gd`, `scripts/azar.gd`): la historia se congela en el año de partida y lo que viene lo descubren los países, uno primero y los demás por contagio (vecinos, aliados y «viajeros» lejanos; los continentes aislados tardan). El ritmo se calibra con la historia (motor solo, sin economía ni ejército): de 1 a 1001 el planeta descubre 59 y 57 (semillas 4242 y 777) contra 63 de la historia; de 1500 a 1600, 26 y 23 contra 26.
- Cada país tiene **su propia copia** de lo que conoce (1 byte por descubrimiento). `Descubrimientos.frontera` pasa a ser la frontera del planeta (lo que conoce al menos un país).
- **Semilla de partida** (`Mundo.semilla_partida`): con la misma semilla, la misma partida (el azar de `azar.gd` no depende del orden de las llamadas). No hay sistema de guardado todavía: la semilla es un atributo de la partida en curso.
- **Invariante:** ningún país conoce algo sin conocer sus prerrequisitos (`runner103`).
- **Debug > Descub.**: botón «VOLVER A LA HISTORIA FIJA» / «QUE EL PLANETA DESCUBRA» y, en la lista, la línea «PLANETA hasta…». Con la historia fija todo funciona como en la §3.
- **Coste:** ~0,3–0,7 ms por mes de juego con todas las IA (peor mes ~1,5 ms); la ficha de un descubrimiento muestra quién lo descubrió y cuándo, y la receta con lo que le falta a tu país.

## 7. Qué NO hace todavía
- No hay investigación ni coste en dinero: los descubrimientos aún no desbloquean unidades ni acciones, y la receta no pide dinero (`costo` queda fuera a propósito hasta que el jugador pueda investigar: Fase 1 parte B).
- Los edificios solo pesan en la receta; sus efectos de juego vienen después.
- Se puede mirar y cambiar desde **Debug > Descub.** (lista alrededor de la fecha, buscador, ficha con prerrequisitos, conceder / quitar / volver a la historia).
