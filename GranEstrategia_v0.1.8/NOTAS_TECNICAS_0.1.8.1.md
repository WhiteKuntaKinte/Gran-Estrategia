# Notas técnicas 0.1.8.1 — economía de todos los países, ocupación, retirada, paz con condiciones y dos pruebas de rendimiento

## Qué es esta versión
Pedido de Camilo: «versión 0.1.8.1 con los primeros dos pasos [de la hoja de ruta de la IA] y dos pruebas de rendimiento para pulir».
1. **Paso 1 — economía simulada para TODOS los países** (tesorería, ingreso diario, mantenimiento, costo de reclutar; la quiebra puede cortar una guerra larga).
2. **Paso 2 — conquista/ocupación, retirada y paz con condiciones.**
3. **Dos pruebas de rendimiento** (`runner31` simulación, `runner32` pantalla) y el pulido que salió de ellas.
Todos los números de juego son PROVISIONALES y están como constantes al principio de `guerra.gd` / `entidades.gd`.

## Paso 1 — economía de todos (`scripts/entidades.gd`, clase `Mundo`)
- `DIAS_TESORERIA_INICIAL = 60`: cada país con provincias arranca con 60 días de sus ingresos (`iniciar_tesorerias()`, al final de `iniciar_ejercito`).
- `_economia_dia()` (primera línea de `avanzar_dia`): para cada país con provincias `tesorería += ingreso − mantenimiento`. Escribe directo en la columna y sube `bd.version` una vez.
  Un país sin provincias (anexado) ya no cobra ni gasta; si vuelve a existir (NaN) arranca con 60 días.
- **Caché de balances** (`_armar_balances`): `[tid, fila, nombre, ingreso_diario_local, mantenimiento_diario_local_por_soldado]`, válida mientras no cambie `bd.version_eco`
  ni `bd.version_propietario`. El mantenimiento sí depende de los soldados de cada día (se leen de `Ejercito.soldados_por_pais()`, que está en caché por `version_pilas`).
  `Ejercito.actualizar_precios()` sube `version_eco` (los precios cambian cada mes).
- `reclutar_pagando(pais, prov_tid, n, reg)` cobra a cualquier país con tesorería; sin dinero devuelve `{ok:false, msg:"No alcanza la tesorería: hacen falta …"}`.
- `_absorber`: la caja positiva del anexado pasa al anexador convertida con `_por_usd`; el origen queda en 0. `transferir_provincia` limpia `ocupante`.
- **Quiebra**: con la tesorería < 0, `Ejercito.desertar_pais(pais, DESERCION_DIARIA = 0,004)` quita ceil(soldados × 0,004) (mínimo 1) a cada pelotón; no suma a `bajas_total`;
  `Mundo.desertores_total` cuenta los desertores. Suceso «está en rojo» una sola vez (`_en_rojo`) y «salió del rojo».
- **Sucesos**: `Mundo.eventos` (tope `MAX_EVENTOS = 300`), `evento(pais, texto, otro)`, `eventos_de(pais, max)`. Los lee Diplomacia > «Sucesos recientes».
- Variable `tesoreria` (catálogo `datos/variables.json`): ahora la tiene cada país con provincias; historial mensual. `BDScript.cerrar_periodo` se reescribió (ver Rendimiento).
- Con los datos de hoy solo hay un país con mantenimiento > ingreso: **Corea del Norte** (1,3 M de soldados). En 2 años de paz pierde ~376.000 soldados (29 %) hasta equilibrarse.
  Es un resultado de los datos y de las fórmulas provisionales de precio (mantenimiento = 6 × PIB por habitante × 1.000 por unidad), no un fallo. Decisión de diseño pendiente de Camilo.

## Paso 2 — ocupación, retirada y paz (`scripts/guerra.gd`, `ejercito.gd`)
- **Variable nueva `ocupante`** (id_var 56, de provincia, tipo id, «cambio», `afecta_economia`). −1 = nadie. El dueño legal (`propietario`) NO cambia al ocupar.
  `BDScript.version_ocupacion` sube cuando cambia; `version_eco` también (las cachés de producción dependen de ella).
- **Ocupar** (`DIAS_OCUPACION = 3`): un país en guerra con quien controla la provincia, con regimientos quietos allí y sin tropas de países en guerra con él, la ocupa a los 3 días
  (`ocup_prog`, `_revisar_ocupacion`, `_avanzar_ocupaciones`, `_ocupar`). Si las tropas son del dueño legal, el efecto es LIBERAR (`ocupante = −1`).
  Se arranca al llegar una columna (`ej.llegadas`), al terminar una batalla con un solo bando en pie, al declarar la guerra, y — NUEVO — al reclutar en el sitio
  (`Ejercito.reclutar` ahora añade a `llegadas`), más una red de seguridad cada 7 días (`_escanear_ocupaciones`, solo los regimientos de países en guerra).
- Una provincia ocupada rinde 0 a su dueño: `produccion_anual_usd` la salta; `Provincia.ingreso_efectivo_usd()` = 0; `rendimiento_usd()` es lo que rendiría sin ocupación.
- **Retirada** (`RETIRADA_FRAC = 0,35`): en `_ronda`, el bando con menos de 35 % de su fuerza inicial en la batalla y peor que el rival se retira (`_retirar` →
  `Ejercito.retirar_reg` → `refugio_de(rid, 5)`: BFS por tierra hasta una provincia propia sin enemigos). La batalla termina con resultado `"retirada"`; si no hay refugio sigue peleando.
- **Puntaje de guerra** `puntaje_guerra(a, b)` = (producción de b que ocupa a) / (producción de b) − (lo mismo al revés). `participacion_ocupada` está en caché por `version_eco`.
- **Paz con condiciones**: `evaluar_paz(proponente, otro, t)` → `{acepta, motivo, puntaje}`; `proponer_paz` (evalúa y firma) y `firmar_paz(a, b, t, motivo)` (sin evaluar).
  `t = {}` blanca · `{posesion:true}` cada uno se queda con lo ocupado · `{posesion:true, indemnizacion:true}` además cobra hasta `DIAS_INDEMNIZACION = 90` días de ingresos
  del rival sin pasar de su caja. Aceptación: posesión siempre; blanca si puntaje ≥ −`MARGEN_PAZ` (0,02); indemnización si `PESO_INDEMNIZACION` (0,10) ≤ max(puntaje,0) + `MARGEN_PAZ`.
  `firmar_paz`: termina batallas («paz»), cancela ocupaciones a medias, paga la indemnización ANTES de mover provincias, limpia `ocupante`, transfiere (`transferir_provincia`) las
  ocupadas en los dos sentidos si hay «posesión», y `_expulsar_tropas` manda a casa los regimientos quietos que quedaron en provincias ya ajenas. `Guerra.paz(a, b)` = blanca sin preguntar (pruebas y Debug).
- **Mapa** (`MapaPrincipal.gd`): `_dueno_visual` da a una provincia ocupada un dueño VIRTUAL (`OCUP_BASE = 700.000.000 + dueño × 10.000 + ocupante`) con color = dueño ↔ ocupante a 70 %.
  Como en la vista tradicional todo un continente comparte color, si ambos colores se parecen (distancia RGB < 0,2) el ocupante usa un tono propio estable (según su ID) para que se note.
  Las fronteras, nombres y todo lo demás siguen usando el dueño REAL (`_dueno_ahora`). Un cambio de solo ocupación repinta únicamente el relleno (`fusion.pintar`).
- **HUD** (`hud.gd`): Diplomacia > cada guerra muestra «Ocupas N provincias (x % de lo que produce) · te ocupa M», y «Proponer la paz a X» con tres botones
  (el que el rival rechazaría dice «(rechazaría)» y su tooltip explica el motivo); «Situación» avisa tesorería en rojo; «Sucesos recientes». Panel de provincia: fila «OCUPADA por X».
  Economía (cualquier país): Tesorería (con «EN ROJO»), Gasto del ejército por día y Balance por día.

## Pruebas de rendimiento y pulido (lo que salió)
Servidor sin GPU, CPU lenta: sirven para COMPARAR antes/después, no para predecir FPS en el PC de Camilo. «ms/día» = una llamada a `reloj.sumar_dia()` (camino real del juego).

### Prueba 1 — `runner31` (simulación: 249 países, 40 guerras simultáneas, 2 años)
| | antes del pulido | después |
|---|---|---|
| día en paz | 7,4 ms | 0,12 ms |
| día con 40 guerras | 49,2 ms (p95 94) | 4,2 ms (p95 17) |
| día de cambio de mes (paz) | 119 ms | 37 ms |
| día de cambio de mes (guerras) | 148 ms | 44 ms |
| segundo año, día normal | — | 0,46 ms |
Qué pesaba y qué se hizo:
- `Ejercito.soldados_por_pais()` usaba `bd.num` por pelotón (21.612 pelotones → 44 ms cada vez que cambiaba algo): ahora lee la columna directa → ~4 ms.
- `_economia_dia()` recalculaba ingreso/precio/divisa de 249 países cada día (9 ms): ahora usa la caché de balances (0,1–0,5 ms).
- `BDScript.cerrar_periodo()` hacía un `match` por fila sobre 41.790 territorios × 3 variables (62 ms por cambio de mes): ahora un bucle por tipo sobre la columna → 5 ms.
- Mi red de seguridad de ocupaciones diaria costaba 28 ms/día: ahora la ocupación en el sitio entra por `llegadas` y la red corre cada 7 días solo sobre países en guerra.
- Estabilidad tras 2 años: 0 tesorerías NaN/infinitas, el registro de sucesos respeta el tope, memoria +12,5 MB el primer año y +2,2 MB el segundo, ningún día > 100 ms.
  El coste por día no crece con los años.
- Queda: `Ejercito.avanzar_mes()` (~30 ms: recorre los 21.612 pelotones) y las rondas de batalla (~1,7 ms de media, hasta 10 ms con muchas batallas).

### Prueba 2 — `runner32` (pantalla: HUD abierto, repintado del mapa, velocidad máxima con 31 guerras)
| | antes | después |
|---|---|---|
| Economía de EE. UU. (3.222 provincias): `_fin_pais` + `_fin_detalles` | 158 ms | ~1,6 ms (promedio de 8 llamadas, la primera con la caché fría incluida) |
| Economía de Colombia: refresco del panel cada 0,4 s | 20,9 ms | 1,4 ms (3 ms de media: solo se reconstruye si cambió algo) |
| `diplomacia_vista()` (1 guerra, 3 opciones de paz) | 6,5 ms | 1,2 ms |
| `evaluar_paz` / `puntaje_guerra` | 0,9 / 0,8 ms | 0,01 / 0 ms (caché por versión) |
| repintar el mapa: sin cambios / ocupación / dueño | 0 / 2,4 / 10–15 ms | 0 / 2,4 / 14 ms |
Qué pesaba y qué se hizo:
- `Mundo.top_provincias()` ordenaba TODAS las provincias del país con objetos (60 ms para EE. UU.): una pasada por las columnas que guarda las 10 mayores, con caché por `version_eco`.
- `favorabilidad_media` y los extremos de favorabilidad (3 mejores y 3 peores): una pasada y caché (antes un `sort` de 3.222 objetos).
- `participacion_ocupada` (puntaje de guerra): `Mundo.rendimiento_ocupado()` por columnas + caché; la diplomacia lo pedía 12 veces por refresco.
- `Hud.actualizar_fin()` reconstruía toda la pestaña Economía en cada refresco; ahora compara una huella y no toca nada si no cambió.
- Fotogramas con el HUD abierto y el reloj parado: `_process` del mapa 0,1–0,3 ms con cualquier zoom (el resto del fotograma es el dibujo por software del servidor, ~75 ms: no es medible aquí).
- A velocidad máxima el juego procesa hasta 40 días por fotograma (tope `DIAS_MAX_POR_FOTOGRAMA`); aquí, por la CPU lenta, cada fotograma procesó ~33 días en 64–110 ms de `_process`
  (2–3 ms por día con 31 guerras). En un PC más rápido a 60 FPS serían ~4 días por fotograma.

## Pruebas
- `runner30` (57 comprobaciones): lógica de todo lo anterior. `runner25` portado a los tres botones de paz. `runner6` / `runner7`: `VERSION == "0.1.8.1"`.
- `runner31`, `runner32`: rendimiento (imprimen números y comprueban topes: <25 ms/día en paz, <40 ms/día con 40 guerras, ningún día >400 ms, sin NaN, memoria acotada).
- `runner33`–`runner36`: herramientas de medición. `runner37`: capturas (Diplomacia con 3 botones de paz, mapa con ocupación, Economía de otro país) revisadas a ojo.
- Regresión completa (3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 21, 23, 24, 25, 26, 27, 28, 30): 0 fallos, 0 «SCRIPT ERROR». `runner17` (arrastres simulados, sensible al tiempo) falló UNA vez
  en una pasada completa y pasó limpio en las 2 repeticiones sueltas y en la pasada siguiente.
- Todo corre en el servidor (Godot 4.3, sin GPU). NO se jugó a mano ni en el PC de Camilo.

## Pendiente / ideas
- Constantes por afinar jugando: retirada (35 %), 3 días para ocupar, 0,4 % de deserción diaria, margen de paz (2 %), indemnización (10 % / 90 días).
- La ocupación no anexa por sí sola ni hay «capitulación»; no hay cuenta de agotamiento de guerra ni costo político.
- Corea del Norte (y cualquier país con ejército > economía) se desangra por deserción: decidir si se corrigen los datos de ejército o los precios.
- Siguiente en la hoja de ruta: IA de los países (misma API que el jugador, reloj de decisión escalonado, percepción, decisiones por capas con puntaje, personalidad en la BD, frenos anti-caos, pestaña Debug > IA y prueba de simulación de varios años).
- Sigue sin especificarse el estilo de las líneas de provincia / estado / costura (pendiente de Camilo).
