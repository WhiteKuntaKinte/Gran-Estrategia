# Notas técnicas 0.1.8.36 — La rama de descubrimientos, enlazada con el reloj

## Qué es esta versión
Pedido de Camilo (5 de noviembre, 22:00): empezar a meter la rama de descubrimientos en el juego; decidir yo si va en la base de datos o en una estructura nueva; y, como hay que poder simular
varias épocas, **enlazar cada descubrimiento con un año**. No se pidió número de versión: elegí **0.1.8.36** (`MapaPrincipal.gd` → `VERSION`, `project.godot` y las pruebas que lo comprueban).
Guía corta del sistema: `docs/DESCUBRIMIENTOS.md`.

## 1. Decisión: estructura nueva, no la base de datos
`base_datos.gd` guarda **un valor por territorio y por fecha** (con historial). Un descubrimiento no es de un territorio: es un dato fijo del juego (nombre, era, tipo, prerrequisitos, año) y lo único
que cambia es *qué países lo conocen*. Meterlo ahí habría obligado a crear 1.730 «variables» con historial por cada país. Resultado:
- **Catálogo fijo** `datos/descubrimientos.json` (157 KB) + módulo `scripts/descubrimientos.gd`.
- **Estado por país perezoso**: un país que nunca se tocó lee la «frontera histórica» (todo lo que tenga año ≤ año del reloj) y no gasta memoria; solo el que se aparta de la historia
  (`conceder` / `quitar`) recibe su propia copia (`PackedByteArray`, 1 byte por descubrimiento = 1,7 KB).

## 2. El catálogo
- **1.730 descubrimientos**, 3 ramas (Militar, Científica, Sociedad), 40 secciones, 149 subsecciones, 12 eras (E0–E11), 9 tipos (U unidad · W arma · V vehículo · B edificio · G gobierno · A acción · T técnica · K conocimiento · R recurso)
  y 4 temas especiales (medicina, recursos del territorio, tropas por época, lenguas).
- Prerrequisitos: `a,b,(c|d)` = a Y b Y (c O d).
- **Fuente de verdad** (a mano): `herramientas/descubrimientos/catalogo/*.txt` (9 archivos) y `herramientas/descubrimientos/anios.tsv`. `herramientas/construir_descubrimientos.py` genera el JSON
  (formato en columnas: `slug, nombre, era, tipo, seccion, sub, tema, anio, origen, req, req_o`; `req`/`req_o` son índices de fila).
- Cuántos conoce la historia: año 1 → 353 · 1000 → 412 · 1500 → 526 · 1800 → 717 · 1900 → 982 · 1945 → 1.261 · 2000 → 1.573 · 2026 → 1.699 (los otros 31 son hipotéticos, era «Futuro hipotético», desde 2027).

## 3. El año de cada descubrimiento
- Entero con signo, a. C. en negativo y sin año cero. El reloj cuenta el 1 a. C. como 0: desfase de un año, ignorado. Fecha del juego = `(año+100000)*10000+mes*100+día` → `BDScript.anio_de_fecha(f)` (nuevo).
- **Origen** (columna informativa): `h` histórico a mano (1.348; a veces aproximado) · `a` ajustado para respetar prerrequisitos y era (351) · `x` hipotético (31). La prehistoria (era 0) usa años muy aproximados.
- **Reglas que comprueba el generador** (si falla alguna no escribe nada): todo prerrequisito existe, sin ciclos ni autorreferencias · todo descubrimiento tiene año y no sobra ninguno · año ≥ año de sus prerrequisitos
  (todos los de la lista Y; al menos una alternativa de cada grupo O) · el año cae dentro del rango de su era.
- **Ajustes al catálogo para que fuera coherente** (el diagrama de abanico publicado antes ya no coincide con esto):
  - 36 descubrimientos cambiaron de era.
  - Se quitaron 11 prerrequisitos «sueltos» que obligaban a absurdos (p. ej. Monarquía constitucional saltaba de 1689 a 1787): modelo heliocéntrico−geometría analítica, fragata de vela−dinámica de fluidos,
    bloqueo naval−cronómetro marino, uniforme estandarizado−hilandería mecánica, fortificaciones permanentes−balística matemática, cascos azules y contratistas privados−infantería moderna conectada,
    competiciones atléticas−ética y filosofía moral, constitución escrita−filosofía de la Ilustración, ejército profesional−moneda acuñada, katana−forja medieval con martinete.
  - 17 años puestos a mano para cortar cascadas (modelo geocéntrico, destilación, moneda acuñada, hormigón romano, pilum, catapulta de torsión, etc.).
  - Quedan derivas medianas en la Edad Media / Edad Moderna (p. ej. ballesteros profesionales 1100 → 1370): no afectan a las partidas en el año 1 ni en 2026.

## 4. El módulo `scripts/descubrimientos.gd`
- Datos en arreglos empaquetados paralelos (`slug, nombre, era, tipo, seccion, sub, tema, anio, origen, req, req_o`), índice por slug y `orden` (índices ordenados por año) con `anios_ord` para buscar por bisección.
- `cargar(dict)` → false (sin dejar nada a medias) si el formato no es el esperado · `iniciar(año)` · `avanzar_a(año)` · `sincronizar(año, reiniciar)` · `conoce(tid, i)` / `conoce_slug` · `requisitos_cumplidos` / `disponible` ·
  `cantidad`, `cantidad_por_era`, `total_por_era`, `proximos(k)`, `ultimos` · `conceder`, `quitar`, `reiniciar_pais` · `anio_texto` («44 a. C.», «2.600.000 a. C.») y `etiqueta`.
- `tid = -1` significa «la historia pura» (para preguntar sin un país concreto).

## 5. Dónde se engancha al juego
- `Mundo.cargar(..., anio_inicio, desc_json)` crea el módulo y llama a `iniciar(anio_inicio)`; sin JSON (o inválido) `Mundo.descubrimientos` queda en `null` y todo lo demás funciona igual.
- `Mundo.avanzar_mes()` llama a `descubrimientos.avanzar_a(año de bd.fecha)` antes de subir `bd.version`. Va incrustado en el mes y NO es una fase nueva (`runner71` exige que `_fases_mes(false)` tenga 2 fases). Solo trabaja al cambiar de año.
- `MapaPrincipal.debug_fijar_fecha` llama a `sincronizar(reloj.anio, true)`: tras un salto de fecha todos los países vuelven a la historia de ese año.
- `Mundo.conoce_descubrimiento(pais, slug)`: la pregunta que hará el resto del juego (unidades, edificios, acciones) cuando se enlacen.
- **Debug > pestaña «Descub.»** (`debug_menu.gd`): resumen (año del reloj, cuántos conoce la historia y tu país, por era, últimos y próximos en llegar), lista alrededor de la fecha (30 antes y 30 después) o buscador (hasta 300 resultados),
  ficha con año y su origen, era, ruta (rama › sección › subsección), tipo, tema especial y prerrequisitos con ✓/✗ para tu país, y botones CONCEDER A MI PAÍS / QUITAR A MI PAÍS / MI PAÍS = HISTORIA.

## 6. Lo que NO hace todavía
- **Todos los países comparten la misma historia**: no hay difusión regional ni retraso (un país del año 1 ya «sabe» el acueducto, aunque su cultura no lo hubiera visto).
- No hay investigación, costes ni tiempos; los descubrimientos aún no desbloquean unidades, edificios ni acciones diplomáticas.
- Las 11 decisiones de diseño que Camilo tiene abiertas siguen abiertas.
- Los años del futuro (era 11) y de la prehistoria son inventados / muy aproximados.

## 7. Rendimiento (`runner89` por software con Xvfb, 1280×720; dos pasadas con el catálogo y dos sin él, mismo PC de pruebas)
| 2026 | sin catálogo | con catálogo |
|---|---|---|
| carga de la escena | 2,47–2,50 s | 2,56–2,78 s |
| iniciar partida | 93–115 ms | 95–109 ms |
| memoria tras cargar | 297 MB | 298 MB |
| ms por fotograma mundo / Europa / Roma | 98–103 / 97–98 / 69–71 | 101–102 / 95–100 / 68–71 |
| 40 pasos de zoom+arrastre | 89 ms | 84–88 ms |
| simular 1 día con 249 IA | 5,7–6,5 ms | 6,2–6,5 ms |

El año 1 d. C. es igual (carga 1,23–1,27 s sin / 1,32–1,34 s con; memoria 328 / 331 MB). Todo dentro del ruido salvo ~+0,1 s al abrir y +1–3 MB.
Coste del propio módulo (`--headless`, medido aparte): leer y parsear el JSON 5,6 ms + armar los arreglos 6,0 ms (una vez); `iniciar` 0,05 ms; dar estado propio a 249 países 0,09 ms; avanzar 100 años con 249 países propios 0,45 ms; 100.000 consultas `conoce` 21 ms (0,2 µs cada una).
Comparado con la 0.1.8.35 (304 MB, 2,9–3,0 s, 118 ms): son otra tanda de medidas; la comparación válida es con/sin catálogo, en la misma ejecución. Medido sin GPU (llvmpipe), no en el PC de Camilo.

## 8. Revisión de variables y código
- Auditor estático (`herramientas/auditar_codigo.py`): 25 archivos, 1.013 funciones, **0 funciones duplicadas, 0 variables repetidas**; los 17 ciclos y las 26 escrituras directas son los de siempre.
- Código sin uso: detecté y quité un gancho `al_descubrir`, la función `existe`, y la variable `cambios` (solo se escribían). `ultimos`, `sub`, `tema`, `subsecciones`, `temas`, `proximos` y `disponible` se usan en la pestaña Descub. del Debug.
- `datos/variables.json` sin cambios (los descubrimientos no son variables de territorio).
- Un error propio corregido en el camino: al quitar `cambios += 1` quedó un bloque `if` vacío en `reiniciar_pais` (error de análisis); lo vi al releer el código, antes de correr las pruebas.

## 9. Pruebas
- `test/runner77.gd` (nuevo, 88 comprobaciones): coherencia del catálogo (1.730, con año, prerrequisitos y era), la frontera contra una cuenta por fuerza bruta en 31 años, cierre de prerrequisitos en 18 años, avanzar mes a mes = empezar directo,
  saltos hacia adelante y hacia atrás, conceder / quitar / reiniciar por país, disponibles, textos de año, coste, y dentro del juego real: 2026, 1 d. C. y la pestaña Descub. del Debug.
- `runner74`: tres comprobaciones de versión → 0.1.8.36. (Se prueba con ventana real: en `--headless` 14 comprobaciones de ventana fallan porque no hay ventana; con Xvfb dan 219 OK, 0 fallos.)
- **Regresión final**: 36 pruebas en los datos reales (`runner8 9 10 15 16 17 21 23 24 25 26 27 28 30 31 32 40 41 42 43 44 46 48 49 52 53 54 55 60 71 72 73 74 75 76 77`): 1.461 comprobaciones «OK», 0 fallos, 0 «SCRIPT ERROR» / «Parse Error»; 9 en los datos de semilla (`runner3 5 6 7 71 72 73 74 77`): 782 «OK», 0 fallos. Las comprobaciones de versión de `runner6`, `7`, `30` y `74` pasaron a 0.1.8.36. `runner77` omite sus comprobaciones del año 1 dentro del juego si el proyecto no trae `datos/epocas` (el de semilla no lo trae).
