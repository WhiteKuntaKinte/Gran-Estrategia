# Notas técnicas 0.1.8.45 — FPS al subir la velocidad, historial en Descubrimientos y zoom solo al país propio

Sale de tus notas del 2026-11-15 (F9 de 875 s en el portátil con RTX 4060, Godot 4.7.2, tope 240 FPS).

## 1. Caída de 240 a ~70 FPS al subir la velocidad
**Causa.** A x3-x6 la simulación casi siempre va atrasada (debe más días de los que alcanza), y `_avanzar_reloj` gastaba entonces el presupuesto COMPLETO de cada fotograma: `presupuesto_us` = 9 ms (Equilibrada). En un equipo que dibuja un fotograma en ~4,2 ms: 4,2 + 9 = 13,2 ms → ~75 FPS. Es exactamente lo que viste. En el PC flojo no se notaba porque allí el fotograma ya dura 25-30 ms.

**Cambio.** El presupuesto pasa a ser una PARTE del fotograma (`MapaPrincipal._presupuesto_fotograma`):
`presupuesto = resto del fotograma anterior (sin su simulación) × f ÷ (1 − f)`, acotado entre `SIM_MIN_US` (1,5 ms) y el techo de siempre (`presupuesto_us`: 4 / 9 / 14 ms).
`f` = `AjustesScript.SIM_FRACCION` = 0,20 Fluidez · 0,35 Equilibrada · 0,50 Velocidad del tiempo.
- A 240 FPS (4,2 ms de dibujo) con Equilibrada: ~2,3 ms de simulación → ~155 FPS en el peor caso (x6 atrasado), en vez de ~75.
- A 30 FPS o menos: el resultado es el techo → idéntico a la 0.1.8.44.
- **Lo que cuesta:** en el equipo rápido la simulación recibe algo menos de CPU por segundo (~350 ms/s en vez de ~675 ms/s a x6), así que si x6 iba limitado por CPU puede correr algo menos de un año por segundo. Si prefieres velocidad del tiempo sobre FPS: Opciones > Pantalla > Prioridad de la simulación > «Velocidad del tiempo» (50 %, ~120 FPS).

## 2. Descubrimientos: atrás y adelante (`scripts/pantalla_descubrimientos.gd`)
- Historial tipo navegador: cada descubrimiento abierto (clic en planeta, fila de Requiere/Abre, salto naranja, búsqueda) se anota. `◀` / `▶` junto a «Secciones», Alt+← / Alt+→ y los botones laterales del ratón (XBUTTON1/2).
- Cambia de sección y de rama si hace falta. Abrir uno nuevo tras ir atrás corta lo de adelante; el mismo dos veces seguidas no se repite; tope de 200.
- Es `static`: sobrevive a cerrar y abrir la pantalla (no se guarda en la partida). El tooltip de cada botón dice a cuál va.

## 3. Zoom solo al país propio (`MapaPrincipal._zoom_a_pais_permitido`)
- Clic y doble clic en un país ajeno: se enfoca igual (rótulo, provincias con nombre, resto atenuado, panel), pero la cámara NO se mueve.
- Tu país: como antes (se acerca si se sale de la pantalla o se ve chico). Barra superior / dinero → tu país, igual.
- Sin país controlado (observador / dev sin país): todos como antes, porque no hay «país propio».
- No cambia: doble clic en una provincia del país enfocado sigue yendo a ella.

## 4. Grabador F9 (`scripts/grabador_rendimiento.gd`)
- Nueva columna `ms_sim` (antes de `marca`, que sigue siendo la última). `runner81` ahora lee la marca como última columna.
- El resumen trae **«Por velocidad del reloj»** (FPS, ms medio, p95, scripts y simulación por x1…x6 y pausa) y los 12 peores fotogramas dicen velocidad, scripts y simulación.
- **Los tirones de ~145-150 ms de tu F9** (908 fotogramas > 50 ms, todos en el mapa, a cualquier zoom, con 100-1.000 dibujos) tienen una duración casi idéntica, lo que apunta a una tarea fija (repintado por cambio de dueño, rehacer el panel o un cierre de periodo) y no al dibujo. Con el F9 de esta versión se verá si coinciden con la simulación o con los scripts: **pásame el próximo resumen con el tiempo corriendo a varias velocidades.**

## 5. Revisión de variables
`herramientas/auditar_codigo.py`: 1.541 funciones (+12, todas nuevas y usadas), 0 funciones repetidas, 0 variables repetidas, sin recursión nueva. Variables nuevas: `presupuesto_fot_us`, `sim_fraccion`, `SIM_MIN_US` (MapaPrincipal); `SIM_FRACCION` (Ajustes); `_hist`, `_hist_pos`, `HIST_MAX`, `_btn_atras`, `_btn_adelante`, `_navegando_hist` (pantalla); `_vels`, `_procs`, `_sims` (grabador).

## 6. Revisión de rendimiento y pruebas (Godot 4.3)
**Banco de velocidad** (headless = solo scripts, como un PC con GPU rápida; 2026 con las 249 IA activas, 8 s por velocidad):

| | 0.1.8.44 | 0.1.8.45 |
|---|---|---|
| x1 | 144 FPS · 1,0 días/s | 145 FPS · 1,0 días/s |
| x3 | 136 FPS · 8,4 días/s | 142 FPS · 8,4 días/s |
| x6 | **64 FPS** · 186 días/s | **111 FPS** · 121 días/s |

Se reproduce tu caída (64 FPS a x6) y queda arreglada; el costo es que x6 con TODAS las IA avanza ~35 % menos días por segundo en un equipo rápido. Con «Velocidad del tiempo» se recupera parte. x1-x3 no pierden nada.

**runner89** (2026, headless, 0.1.8.44 → 0.1.8.45): mundo / Europa / Roma 6,9 → 6,9 ms; 40 pasos de zoom 6,9 → 6,9 ms; un día con 249 IA 11,4 → 9,2 ms (ruido); carga y memoria iguales (426 MB). El mapa no cambió.

**Regresión:** runner71–73, 75–88, 91–100 headless + runner74 con xvfb: **0 fallos y 0 «SCRIPT ERROR» / «Parse Error»**. Nueva **runner100** (24 comprobaciones: presupuesto proporcional, historial, zoom propio). `runner73` ajustada (fija el presupuesto del fotograma antes de medir `_presupuesto_restante`).
