# Notas técnicas 0.1.8.2 — primera IA de países, modo Campaña (Europa), ranking, ver tropas enemigas, WASD y reclutar cualquier cantidad

## Qué es esta versión
Pedido de Camilo (mensaje del 2 de noviembre):
1. **Ver las tropas del enemigo** en la provincia a la que mandas las tuyas y las que van hacia allí.
2. **Mover la cámara con WASD.**
3. **Reclutar la cantidad que quieras** (el tope es el dinero de la nación), por ejemplo 1.500.000 escribiéndolo en el campo.
4. **Primera versión oficial de la IA**: conquista básica de provincias; compite por más tropas y más provincias; equilibra el dinero que genera contra el dinero en caja para reponer tropas;
   cada provincia da recursos a su dueño; tabla de países (provincias, tropas, ingresos); la IA NO existe por defecto: se elige país por país desde Debug.
5. **Segunda capa al pulsar Jugar**: dos botones gigantes, **Modo Dev** (el mapa de siempre) y **Campaña** (solo Europa).
Todos los números de la IA son **PROVISIONALES** y están como constantes al principio de `scripts/ia.gd`.

## 1. Ver las tropas enemigas (`scripts/capa_tropas.gd`, `_actualizar_vision`)
Ves los regimientos y columnas de los países **en guerra contigo** pero solo dentro de tu **campo de visión**: tu propio territorio, las provincias donde tienes tropas **y sus vecinas**,
las provincias a las que marchan tus columnas (destino + vecinas) y por donde van, y la provincia que estás eligiendo como destino (mientras eliges ves sus tropas aunque aún no haya guerra: así sabes qué defiende antes de atacar). Una columna enemiga se ve mientras algún tramo de lo que le falta de ruta
pasa por ese campo. Sin guerra no se calcula nada. Los enemigos se dibujan con el mismo cuadro que las tropas propias, con un filo rojo por fuera. Países sin guerra contigo, fuera de ese caso: no se ven. Prueba: `runner41`.

## 2. WASD (`MapaPrincipal.gd`, `_mover_camara_teclado`)
W A S D y las flechas mueven la cámara; Shift = más rápido; la velocidad baja con el zoom (se ve el mismo avance en pantalla). Se usan las teclas físicas (`Input.is_physical_key_pressed`),
así funciona con cualquier teclado. No se mueve en pausa ni mientras escribes en un campo de texto (por ejemplo la cantidad a reclutar). Las flechas solo mueven si ningún control las necesita.

## 3. Reclutar cualquier cantidad (`scripts/hud_tropas.gd`)
El selector numérico se cambió por un campo propio `CampoNumero` (un `LineEdit` con puntos de miles). El máximo ya no es una fracción del ejército: es lo que alcanza el dinero de la caja
(`_max_por_dinero()`, que usa el costo real de reclutar). Botones rápidos 1.000 · 10.000 · 100.000 · 1 M · Máx. Con la caja vacía el campo avisa y no recluta. Se probó con 1.500.000 (`runner40`).

## 4. La IA (`scripts/ia.gd`, ~640 líneas)
### Cómo se activa
- **Ningún país tiene IA al arrancar.** Debug > pestaña **IA**: casilla por país (con buscador), botones rápidos **Todas · Vecinas de mi país · Ninguna** y un resumen con decisiones, guerras, paces y el costo en ms.
- Un país con IA decide **cada `PERIODO = 4` días** (repartidas con un desfase por país para que no coincidan todas el mismo día). El jugador nunca tiene IA.
- **Campaña:** solo se puede conquistar a países con IA (y al jugador). Un país **sin IA es intocable**: `Mundo.puede_atacar` lo impide y `ordenar_marcha_reg` devuelve
  «X no tiene IA: en la campaña solo se conquistan países controlados por la IA…». Si apagas la IA de un país, sus guerras abiertas terminan en paz blanca.
- «Vecinas de mi país» incluye los vecinos por **tierra y por estrecho** (costas a menos de ~200 km): sin eso Reino Unido, Islandia, Malta o Chipre no tendrían rival.

### Qué decide (en este orden, en `_decidir`)
1. **Economía** (`_economia`): foto de ingresos/precios/población cada `DIAS_FOTO_ECONOMIA = 10` días (calcularlos recorre todas las provincias); soldados desde una **foto diaria** (ver Rendimiento).
2. **Paz** (`_paz`): cobra la victoria si el puntaje de guerra ≥ `PAZ_GANADA` (0,30), con indemnización desde `PAZ_INDEMNIZACION` (0,12); con ventaja pequeña y `PAZ_LARGA_DIAS` (120) días se queda con lo ocupado;
   tablas (|puntaje| < 0,04) tras `PAZ_TABLAS_DIAS` (150) días = paz blanca; se rinde (posesión) si el puntaje ≤ `PAZ_CAPITULA` (−0,20). **Al jugador no le propone la paz**: la propone él.
3. **Guerra** (`_buscar_guerra`): como mucho `MAX_GUERRAS = 2`; solo si tiene ≥ 25 días de ingresos en caja, el mantenimiento ≤ 90 % de sus ingresos y ≥ 3.000 soldados. Elige al vecino al que le gana
   por `RATIO_GUERRA` (1,6) × su **cautela** (1,0 a 1,5, fija por país) en soldados, priorizando el que más produce y más frontera comparte; cada decisión tiene un 35 % de «animarse». Tregua de `TREGUA_DIAS = 365`
   tras cada paz (`registrar_paz`, llamado desde `Guerra.firmar_paz`).
4. **Operaciones** (`_operar`): objetivos = provincias controladas por un rival que tocan una suya (las suyas ocupadas valen el doble; nunca provincias de un tercero ocupadas por su rival: eso sería declarar otra guerra).
   Puntúa por valor económico / defensores; para cada objetivo manda los regimientos libres más cercanos (hasta `RADIO_ATAQUE = 70` unidades de mapa ≈ 1.170 km) solo si suman ≥ `RATIO_ATAQUE` (1,3) × los defensores.
   Máx. `MAX_ORDENES = 16` marchas y `MAX_OBJETIVOS = 14` por decisión. La provincia de la que sale el próximo ataque queda como «base» y ahí recluta.
5. **Reclutar** (`_reclutar`): el ejército objetivo es el menor de (fracción de ingresos / mantenimiento por soldado) y `MAX_POB_EJERCITO` (1,5 %) de la población. Fracción de gasto: `FRAC_GASTO_PAZ` 0,14 en paz,
   `FRAC_GASTO_GUERRA` 0,32 en guerra, hasta +0,15 si tiene mucha caja ahorrada. Guarda una reserva de `DIAS_RESERVA_*` (15) días de ingresos o 10 días de mantenimiento. Compra en lotes de ≤ 15 % del objetivo,
   reforzando el regimiento de la base mientras tenga menos de `MAX_REG = 30.000` soldados y abriendo regimientos nuevos si no (así se pueden mandar por partes). Si el mantenimiento supera los ingresos y la caja no aguanta
   12 días de ese déficit, **licencia** el 6 % de los soldados antes de que deserten.
- Las **fronteras** (`_preparar_frentes`) se calculan una vez para todas las IA y se rehacen solo si cambian dueños u ocupantes (y como mucho cada `DIAS_FRENTES = 2` días). Cuentan tierra y estrechos, sin las provincias excluidas.

### Recursos
Cada provincia produce según su población y su PIB por habitante (la economía de 0.1.8.1): lo que rinde va a la caja de su dueño (ocupada = 0 para el dueño). El dinero de la caja paga el mantenimiento
del ejército y el reclutamiento. No se añadió ningún recurso nuevo.

## 5. Modo Campaña (`Mundo.iniciar_campana`, `MapaPrincipal._preparar_campana`)
- **Países que juegan:** los 49 de Europa + Rusia y Turquía **enteras** = 51 países, 1.728 provincias menos 12 territorios lejanos (`CAMPANA_QUITAR`: Canarias, Madeira, Azores, Guayana Francesa, Martinica, Guadalupe,
  Reunión, Mayotte, Bonaire, San Eustaquio, Bouvet) = **1.716 provincias**. Los demás países quedan sin provincias (como anexados: no existen), sus ejércitos se disuelven y sus provincias quedan «excluidas»
  (`Mundo.excluidas`): ninguna marcha pasa por ellas (`RedProvincias.bloquear`) y no hay nada que elegir ahí.
- **Visual:** lo que no juega se pinta como un solo «dueño» `VACIO_ID` de color liso oscuro (no como mar); se ocultan sus nombres de país, los nombres de los otros continentes y sus ciudades;
  hacer clic ahí no selecciona nada; en la campaña no hay selección de continentes (un clic elige el país). La cámara no da la vuelta al mundo: se limita al rectángulo de la campaña
  (x ≈ 1.036–2.473 con Chukotka a la derecha de 2.400, y ≈ 54–368) y el zoom mínimo es el que deja ver toda la campaña.
- **Nueva partida:** si ya había una partida en curso, `reload_current_scene` recarga el mundo limpio (si no, la campaña heredaría ejércitos y guerras del Modo Dev) y arranca con `Engine.set_meta("inicio_pendiente", …)`.
  El menú con partida en curso muestra CONTINUAR · NUEVA PARTIDA · OPCIONES · SALIR.
- **Pantalla de campaña:** desplegable con tu país (51; España por defecto) y desplegable de IA: *Los vecinos de mi país (recomendado)* · *Todos* (50 IA) · *Ninguno*. Se pueden cambiar luego desde Debug > IA.
- **Conquista como en Age of History:** ocupar + **acuerdos de paz** (ya existentes desde 0.1.8.1: blanca, posesión, posesión + indemnización). Las IA pactan sus paces solas.
- **Ranking** (`scripts/ranking.gd`, botón «Ranking» arriba a la izquierda o tecla R, solo en campaña): ventana flotante con provincias, soldados, ingresos/día (US$) y puntaje = 40 % provincias + 30 % soldados +
  30 % ingresos (cada uno frente al mejor de la tabla, máx. 100). Solo salen los países con IA y el tuyo. Se actualiza cada 2 s.
  Nota: «provincias» cuenta unidades del mapa, que son muy desiguales entre países (Alemania ≈ 16 provincias, Eslovenia ≈ 190); el puntaje lo refleja. Se puede cambiar el peso o medir por superficie.

## Rendimiento (servidor sin GPU, CPU lenta: sirve para comparar antes/después, no para predecir FPS en el PC de Camilo)
Campaña con **50 IA a la vez** (`runner44` / `runner45`), 3 años simulados:
| | antes de optimizar | después |
|---|---|---|
| costo de la IA | ~106 ms/día | ~25 ms/día (p95 47) |
| día completo con 50 IA | 176 ms | ~58 ms (p95 94, máx. 145) |
| contar soldados por país (41.000 pelotones) | ~15 ms | ~3 ms |
Qué se hizo: (1) `Ejercito.soldados_por_pais()` ahora hace una sola pasada por las columnas (activo, ejército padre, soldados) con un arreglo indexado por ejército, sin diccionarios (`runner46` comprueba que da lo mismo que la
suma lenta); (2) la IA toma **una foto de soldados por día** y la ajusta al reclutar o licenciar, en vez de recontar tras cada movimiento de otra IA; (3) foto de economía cada 10 días; (4) fronteras compartidas;
(5) regimientos de ≤ 30.000 soldados. Caso típico (`runner50`: Francia + las 8 IA de sus vecinos, 2 años): día medio 6,8 ms, de los cuales la IA 2,6 ms (el máximo de ~105 ms es el cambio de mes). El resto del día (~33 ms) es la simulación base y la interfaz, no la IA.
Comportamiento en 3 años con 50 IA: ~250 guerras declaradas y ~230 paces, ~3.250 batallas, los grandes cambian de puesto en el ranking, ~13 millones de soldados en total (las IA de antes llegaban a 19,5 millones),
deserciones por impago ~58.000 (antes ~1,9 millones). Cuatro países terminan en rojo al final.

## Archivos tocados
`scripts/ia.gd` (nuevo) · `scripts/ranking.gd` (nuevo) · `scripts/entidades.gd` (campaña, `puede_atacar`, `ranking`, `iniciar_ia`) · `scripts/ejercito.gd` (`soldados_por_pais` rápido, `quitar_provincias_excluidas`) ·
`scripts/red_provincias.gd` (`bloquear`) · `scripts/guerra.gd` (hook de paz → IA) · `scripts/hud.gd` (botón Ranking) · `scripts/hud_tropas.gd` (campo de cantidad) · `scripts/debug_menu.gd` (pestaña IA) ·
`scripts/capa_tropas.gd` (visibilidad enemiga) · `MapaPrincipal.gd` (menú de dos capas, campaña, cámara, WASD) · `project.godot`, `datos/variables.json`, `docs/` (versión).

## Pruebas (todas en mi servidor, sin jugar a mano)
`runner40` reclutar 1.500.000 · `runner41` tropas enemigas · `runner44` campaña + 50 IA 3 años · `runner45` perfil · `runner46` conteo rápido = lento · `runner47` perfil de guerra · `runner48` menú, arranque, vacío, cámara, ranking · `runner49` arranque tras «Nueva partida» (inicio pendiente) y aviso «no tiene IA» al elegir destino · `runner50` rendimiento del caso típico (8 IA).
Regresión de las pruebas anteriores: ver CHECKLIST_TESTING.md.

## Pendiente / decisiones tuyas
- Estilo de las líneas de provincia / estado / costura; informe de Debug > «Rend.» en tu PC.
- Afinar los números de la IA jugando (cautela, gasto, reservas, tamaño de lotes); el ranking (pesos y unidad de «provincias»).
- La IA todavía no usa el mar ni propone alianzas; la guerra por mar no existe (solo estrechos).
- Hoja de ruta: máquina del tiempo, variables étnicas, árbol de investigación, deriva de idiomas, gastos del estado, subir a GitHub en una rama nueva (nunca main), licencia (CC0).
