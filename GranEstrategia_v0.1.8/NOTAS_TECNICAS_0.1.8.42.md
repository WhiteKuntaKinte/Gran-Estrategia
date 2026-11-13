# Notas técnicas 0.1.8.42 — Descubrimientos visibles, 4 escenarios, edificios de partida, grabador global y menos dibujo

Responde a las notas de Camilo del 2026-11-12. Plan acordado (1: sí · 2: investigar la opción con retribución y que él decida · 3: «hazlo por partes pero no hagas 4 versiones, haz 2» · 4: me sirve): **esta es la versión 1 de 2**.
La versión 2 (**0.1.8.43**) será jerarquía país → provincia → subprovincia, provincias que cambian de forma con el tiempo y pinturas por provincia (ver «Lo que viene»).
Camilo preguntó «¿cómo quieres que la pruebe si no me la mandas?»: **desde esta versión cada entrega va con un ZIP del proyecto** (antes solo se subía a la rama).

## Qué trae
1. **Ventana DESCUBRIMIENTOS** (tecla **T** o botón «Descubrimientos» de la barra): el catálogo completo de 1.730, en cualquier época, con árbol por sección.
2. **Debug > Descubrimientos** con la lista completa (antes mostraba 30 antes y 30 después de la fecha).
3. **Dos escenarios nuevos: 1096 (Primera Cruzada) y 1500 (Renacimiento)**, jugables igual que 2026 y 1 d. C.; selector de 4 escenarios en MODO DEV y en Debug > Tiempo.
4. **Edificios de partida** en los cuatro escenarios (antes todas las provincias empezaban vacías).
5. **Grabador de rendimiento global** (F9 sirve también en el menú, la pausa y al cargar «Nueva partida»).
6. **Costa en calidad «Baja»** sin romper el contorno de los países.
7. **Menos llamadas de dibujo** (cajas del HUD y árbol de descubrimientos en lotes) y siembra de edificios optimizada.

## 1. Ventana Descubrimientos (`scripts/ventana_descubrimientos.gd`, `scripts/grafo_descubrimientos.gd`)
- Ventana flotante (`ventana_flotante.gd`, no pausa el juego, recuerda dónde la dejas). Se abre con **T** (`MapaPrincipal._unhandled_input`, solo en partida y sin pausa) o con el botón de la barra (`_abrir_descubrimientos`).
- Izquierda: **3 ramas** (Militar, Científica, Sociedad) → **40 secciones** → subsecciones, con «conoces X de Y». Centro: el **árbol de la sección elegida**. Derecha: ficha del descubrimiento (año, era, ruta, tipo, estado, **lo que requiere** y **lo que abre**, cada uno pulsable).
- Buscador por nombre en todo el catálogo y filtros por estado (todos, conocidos, disponibles, bloqueados y lejanos, aún no llegan en la historia).
- **Se ve TODO**, también lo que la historia todavía no ha inventado en la fecha del reloj (gris apagado): el jugador ve hacia dónde va el árbol. Los estados: conocido ✓ (verde), disponible (dorado: ya tienes los requisitos), bloqueado (gris), lejano (gris apagado).
- El árbol (`grafo_descubrimientos.gd`) es **un solo Control** que dibuja con paneo (arrastrar) y zoom (rueda) recortando lo que queda fuera: cuesta lo mismo con 20 que con 100 nodos (no hay un nodo por descubrimiento). Columnas por nivel de dependencia, una banda por subsección, líneas continuas («hace falta») y discontinuas («basta uno del grupo»), círculo naranja con número para los requisitos que viven en otra sección. Al pasar el ratón se resalta la cadena entera.
- No guarda nada en la partida: lee `Descubrimientos` (`descubrimientos.gd` ganó consultas de secciones, requisitos y «abre»). Se refresca una vez por segundo mientras está abierta. Sin país (observador) muestra lo que sabe la historia en la fecha del reloj.
- Debug > Descubrimientos: la lista ahora es **completa** (los 1.730 ordenados por año + una fila divisoria «HISTORIA hasta …» que marca hasta dónde llega la historia); al abrirla se posiciona en esa frontera.
- Pruebas: `runner91` (76 comprobaciones: las 40 secciones, 1 d. C. y 2026, ficha, buscador, filtros, tecla T, botón, lista del Debug). `runner77` ajustada (la lista ya no es de 60 filas).

## 2. Escenarios 1096 y 1500 (`docs/EPOCAS.md`, `herramientas/epoca/construir_epoca_celdas.py`)
- Cada escenario es una carpeta `datos/epocas/<año>/` con los mismos archivos que `datos/`. Ahora hay cuatro: 2026 (`datos/`), `1dc`, `1096`, `1500` (`MapaPrincipal.EPOCAS_ORDEN` / `EPOCAS_TEXTO`).
- 1096 → **221 naciones, 3.033 provincias, ~367 M hab.**; 1500 → **202 naciones, 3.049 provincias, ~468 M hab.** Las poblaciones son estimaciones de orden de magnitud, no censos.
- **Cómo se arman sin recalcular la geometría**: el año 1 recortaba las provincias de hoy con polígonos (Godot + `Geometry2D`) y de ahí salían las celdas. Estos dos escenarios **reparten las mismas celdas** (~16.000): cada celda y cada territorio se dibujan en un raster de 4.800 × 2.400 px, la celda es del territorio que cubre más de su superficie, y un territorio que no gana celdas se queda con la que más cubre. Desde ahí se reusan las funciones del año 1 (`reclamar_huecos`, `agrupar`, `construir_info`, `plantilla_eco`, `hacer_bandera`, `Localizador`, `asignar_colores`, `ensamblar_provincias`) con `import construir_epoca as CE`. Determinista, sin Godot, ~2 minutos.
- **Fronteras**: Cliopatria v0.2.1 (Seshat Global History Databank, **CC BY 4.0**; créditos en `epoca.json` y en el juego). **Esto es lo único con atribución obligatoria**; el resto (pueblos, poblaciones, ciudades, economía, banderas) es propio.
- Fichas de estados (`datos_medieval_estados.py`: 117 en 1096, 112 en 1500), pueblos sin estado (`datos_medieval_pueblos.py`), ciudades (`datos_medieval_ciudades.py`: 303 y 296), divisas de la época, ejército = población × tasa por tipo de nación, 96 y 256 px de bandera dibujada por código (`e1096_*`, `e1500_*`), nombres de mandos por cultura.
- Selector: MODO DEV muestra **4 botones** (2026 · 1500 · 1096 · 1 d. C.) en `_mostrar_epocas`; Debug > Tiempo > «Escenario (reinicia el mundo con los datos de esa época)» tiene los mismos cuatro.
- Pinturas: `pinturas.gd` mapea 1096 y 1500 a carpetas propias (`CARPETA_EPOCA`); mientras no haya pintura propia caen a la de la región, el continente o el mundo.
- Pruebas: `runner94` (92 comprobaciones: los dos escenarios cargan, ids y banderas, población y economía coherentes, ciudades, ejércitos, nombres, selector, Debug, edificios de partida). `runner75` ajustada al selector de 4; `runner89` mide los 4 escenarios.

## 3. Edificios de partida (`scripts/edificios.gd`: `sembrar_iniciales`, `cantidad_inicial`)
Regla determinista, sin sorteo, igual para las cuatro épocas (detalle en `docs/EPOCAS.md`):
- **desarrollo** de la provincia (0–1) = 0,6 · población (logarítmica, tope 400.000 hab.) + 0,4 · producción por habitante frente a la de referencia de la época (1.500 US$ antes de 1900; 25.000 desde 1900);
- **difusión** de cada edificio = 1 − e^(−años desde su descubrimiento ÷ tiempo de su clase) (A 250, B 300, C 400, D 600, E 900, F 1.500 años);
- cantidad = máximo del edificio × difusión × suavizado (umbral de desarrollo por clase, ventana 0,2); la parte decimal se redondea con un hash fijo de (provincia, edificio).
- Resultado: por provincia reclamada 41 (1 d. C.) → 59 (1096) → 71 (1500) → 90 (2026); tipos presentes 34 → 46 → 53 → 109; **ningún edificio anacrónico** (nada que su descubrimiento aún no haya existido) y ninguno en tierras sin reclamar.
- No cuestan dinero ni quedan como historia (se escriben con `inicial_s` / `inicial_f`) y **siguen sin efectos de juego** (decisión de diseño desde la 0.1.8.40).
- **Rendimiento**: `Mundo.iniciar_edificios` lo llama una vez al armar la partida. Primera versión: 1,2 s en 2026 y 0,2 s en las demás. Ahora **0,54 s en 2026 y ~0,1 s en las otras** (salta lo que la provincia aún no puede tener antes de llamar a `cantidad_inicial`; arma el texto en orden canónico sin ordenar; escribe directo sin avisos de cambio). Los totales salieron idénticos antes y después.
- Pruebas ajustadas: `runner83` y `runner88` partían de provincias vacías; ahora vacían la provincia de prueba (`vaciar`) o eligen un edificio al que aún le quepa otro (`con_cupo`); `runner83` comprueba además que 2026 empieza con edificios.

## 4. Grabador de rendimiento global (`scripts/grabador_rendimiento.gd`)
- Vive en la **raíz del juego**, no dentro de la partida: sigue grabando en el menú principal, en la pausa, al cargar una «Nueva partida» (que recarga la escena) y al cambiar ajustes; si cierras el juego mientras graba, guarda el resumen al salir. Camilo había notado que solo grababa entre partidas.
- Un «● REC» rojo arriba a la derecha avisa en todas las pantallas. Marcas automáticas al cambiar de calidad, de vista, de menú a partida y al empezar partida nueva (por eso `runner81` ya no espera «la última marca = la mía»: comprueba que la suya esté entre las marcas).
- Pruebas: `runner92` (32 comprobaciones).

## 5. Costa en calidad «Baja» (`MapaPrincipal._elegir_detalle_costa`, `COSTA_FACTOR`)
- Antes, «Baja» fijaba SIEMPRE el nivel de costa más lejano: el contorno quedaba grueso y se separaba del relleno de los países al acercar (los bordes «se rompían»).
- Ahora `Opciones > Costas` **alarga los umbrales de zoom** de cada nivel: `COSTA_FACTOR = [1.0, 1.15, 1.3]` (Detallada / media / baja). La costa simplificada dura algo más de zoom, pero con mucho zoom siempre vuelve al detalle alto (error ≤ 1,3 px). Con el factor 1,3 el nivel intermedio se mantiene hasta un zoom real de 3,12 en vez de 2,4.
- Pruebas: `runner93` (27 comprobaciones: cada calidad elige el nivel correcto por zoom y solo deja visible esa capa) y `runner74` ajustada a la nueva semántica.

## 6. Menos llamadas de dibujo
- `Tema.EstiloMetal.armar`: la caja metálica entera (relleno, borde, filete, filo y acentos) pasa de varios `draw_*` a **una sola malla** (un comando de dibujo por caja). El árbol de descubrimientos usa el mismo método (`_g_rect`, `_g_marco`, `_g_linea`, `_g_cinta`, `_g_disco`, `_g_tri`, todos validados en `runner93`).
- Llamadas de dibujo por fotograma (xvfb, 1280×720): mundo 2026 **327** (antes 363), Europa 347 (383), Roma 306 (342); año 1: 397 / 437 / 281 (antes 433 / 473 / 317); panel de país con tarjetas 213 / 295 / 628 (antes 308 / 477 / 897).

## 7. Revisión de rendimiento (runner89, xvfb por software, 1280×720; cada escenario en su proceso)
| Escenario | Provincias | Carga escena | Memoria | Mundo / Europa / Roma (ms por fotograma) | Draws (mundo/Europa/Roma) | 40 pasos zoom+arrastre | Simular 1 día |
|---|---|---|---|---|---|---|---|
| 2026 | 7.653 | 4,0 s | 384 MB | 54,5 / 51,1 / 71,1 | 327 / 347 / 306 | 63,5 ms | 6,1 ms (249 IA) |
| 1 d. C. | 4.181 | 2,3 s | 217 MB | 57,6 / 52,5 / 72,5 | 397 / 437 / 281 | 60,2 ms | 1,1 ms (186 IA) |
| 1096 | 3.033 | 2,1 s | 209 MB | 54,3 / 50,4 / 70,5 | 407 / 457 / 341 | 63,8 ms | 1,3 ms (221 IA) |
| 1500 | 3.049 | 2,1 s | 213 MB | 54,5 / 47,4 / 68,6 | 392 / 432 / 311 | 57,8 ms | 1,3 ms (202 IA) |
- Los dos escenarios nuevos cuestan lo mismo que el año 1 (más baratos de memoria: menos provincias). Los scripts por fotograma son 0,1–0,3 ms en todos; lo que pesa es el dibujo por software del servidor (sin GPU), válido solo para comparar.
- Esta tabla es la primera medición (siembra de edificios sin optimizar). **Con y sin el cambio** (0.1.8.41 contra 0.1.8.42, mismas condiciones, 2 pasadas alternadas, xvfb por software; solo sirve para comparar):
  | | 2026 · 0.1.8.41 | 2026 · 0.1.8.42 | año 1 · 0.1.8.41 | año 1 · 0.1.8.42 |
  |---|---|---|---|---|
  | Carga de la escena | 2,6 s | **3,25 s** | 1,8 s | 1,9–2,0 s |
  | Memoria | 313 MB | **355 MB** | 203 MB | 210 MB |
  | Mundo (ms por fotograma) | 59,6 / 57,1 | **51,9 / 53,5** | 52,1 / 54,9 | 50,7 / 49,6 |
  | Europa | 55,1 / 52,8 | 48,8 / 55,2 | 50,6 / 49,6 | 50,4 / 48,3 |
  | Roma | 70,1 / 62,3 | 64,4 / 66,4 | 63,3 / 66,4 | 63,3 / 62,2 |
  | Llamadas de dibujo (mundo / Europa / Roma) | 356 / 376 / 335 | **327 / 347 / 306** | 426 / 466 / 310 | **397 / 437 / 281** |
  | 40 pasos de zoom + arrastre | 58,1 / 55,2 ms | 58,3 / 60,3 ms | 59,0 / 61,4 ms | 55,9 / 54,5 ms |
  | Simular 1 día con todas las IA | 5,5 / 5,1 ms | 5,1 / 5,5 ms | 1,2 / 1,3 ms | 1,1 / 1,1 ms |
  - **Fotogramas, zoom y simulación: sin cambio** (la diferencia de ±5 ms es ruido; las llamadas de dibujo bajan ~30 en todos los encuadres).
  - **Arranque de 2026: +0,65 s** (siembra de edificios ≈ 0,54 s) y **memoria +42 MB**. Causa de la memoria: el texto de la variable `edificios` (`slug:cantidad;…`) de 7.653 provincias con ~90 tipos cada una suma 6,6 millones de caracteres, y Godot guarda cada carácter en 4 bytes (≈ 26 MB), más el resto. El año 1 y los nuevos pagan +7 MB y ~0,1–0,2 s.
  - **Para la 0.1.8.43**: con subprovincias (muchas más unidades) ese texto se multiplica; conviene un formato compacto (índice numérico del edificio en vez del `slug`, o columnas por edificio) antes de sembrar edificios por subprovincia. No se cambió ahora porque el formato `slug:n` lo leen el Debug, el HUD y varias pruebas.
- `runner90` (banco de zoom) no se corrió: no se tocó `_actualizar_zoom` (la costa cambia en `_elegir_detalle_costa`, que ya corría por paso con el mismo coste: un par de comparaciones).

## 8. Revisión de variables (`herramientas/auditar_codigo.py`)
0 funciones repetidas, 0 variables repetidas; ninguna variable, constante ni función sin uso añadida en esta versión (`datos/variables.json` no cambió). Constantes nuevas y dónde se usan: `TIEMPO_CLASE`, `UMBRAL_CLASE`, `POB_REF`, `PIB_REF_*` (siembra), `EPOCAS_ORDEN`, `EPOCAS_TEXTO` (selector), `COSTA_FACTOR` (costa), `CARPETA_EPOCA` (pinturas).

## 9. Pruebas de la versión
`runner91` 76 · `runner92` 32 · `runner93` 27 · `runner94` 92 (nuevas). Ajustadas: `runner74` (costa Baja), `runner75` (selector de 4), `runner77` (lista completa), `runner81` (marcas automáticas), `runner83` y `runner88` (edificios de partida), `runner89` (4 escenarios). Regresión completa: runner71–88 y 91–94 con `FALLOS: 0`; `runner74` (xvfb) 218 comprobaciones sin fallos.

## Límites conocidos / para decidir
- 1096 y 1500 usan las provincias de hoy agrupadas (no hay divisiones históricas) y las zonas de pueblos del año 1: **la 0.1.8.43 lo resuelve** (provincias que cambian de forma con el tiempo).
- Las fronteras de Cliopatria son gruesas y se ajustan a celdas de ~10.000 km²: una frontera puede quedar a una celda de distancia; los estados pequeños ocupan una o dos celdas.
- Las pinturas de 1096 y 1500 todavía no tienen obra propia por nación.
- Los edificios de partida no tienen efectos de juego.

## Lo que viene: 0.1.8.43 (versión 2 de 2)
- **Jerarquía país → provincia → subprovincia** (como estado → condado de EE. UU.). Las fuentes y la decisión están en `docs/SUBPROVINCIAS_FUENTES.md`. **La elección es de Camilo** (opciones A/B/C); propuesta por defecto: subprovincias procedurales (Voronoi) para todo el mundo + condados reales de EE. UU. como modelo.
- **Provincias que cambian de forma con el tiempo** (cesión o conquista parcial, vía `Territorio`; puntos de control por época).
- **Pinturas por provincia** (dominio público o CC0).
- La vista de Relieve de altísima calidad (teselas) sigue esperando a que Camilo diga cuándo.
