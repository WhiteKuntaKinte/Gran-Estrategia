# Notas técnicas 0.1.7.9.9E — tropas en el mapa: reclutar en una provincia y moverlas provincia a provincia

## Qué es esta versión
Hasta 0.1.7.9.9D el ejército solo existía en la base de datos y en el panel. Ahora se ve y se maneja:
1. **Se dibujan** en el mapa (cuadrito con bandera + número de soldados por provincia y país).
2. **Se reclutan** N soldados en una provincia concreta (ventana «Órdenes de tropas»).
3. **Se mueven** por el mapa, provincia a provincia, con el tiempo del juego (clic en el destino, ruta y días a la vista, columna que avanza).
La rivalidad entre países y la guerra siguen fuera: es solo la mecánica de tropas.

## Datos nuevos: vecindad entre provincias (`datos/vecinos_prov.json`)
Lo genera `herramientas/construir_vecinos.py` (python3 + numpy + scipy) a partir de `datos/fuente_provincias.json` (mismo orden e IDs que
`provincias_juego.json`). Formato: `{version, n, mar_max_unidades, km_por_unidad, centros: [[x,y] × 7653], aristas: [[a, b, km, mar] ...]}`.
- **centros**: un punto DENTRO de cada provincia (el centroide de la fuente si cae dentro de su polígono mayor; si no, el punto interior más
  alejado del borde). Ahí se dibujan sus tropas. (Un enclave como Bogotá dentro de Cundinamarca tiene su propio punto.)
- **aristas por tierra** (mar = 0): 19.448; dos provincias son vecinas si comparten al menos 2 vértices (tolerancia 0,02; el borde x = 2400 vale x = 0).
- **aristas por mar** (mar = 1): 917; costas a menos de ~12 unidades de mapa (~200 km) entre masas de tierra distintas, máximo 2 enlaces por par de
  masas. Las islas más lejanas (51 provincias sin ningún vecino) quedan sin ruta: todavía no hay transporte naval.
- **km**: distancia aproximada entre centros (proyección equirectangular: 1 unidad ≈ 16,68 km; el mapa da la vuelta en x y se corrige por cos(latitud)).
- Si cambian los polígonos de provincias hay que volver a ejecutar el script (el juego ignora el archivo si `n` no coincide con las provincias cargadas).

## Reglas (`scripts/ejercito.gd`, `scripts/red_provincias.gd`) — TODAS PROVISIONALES
- **Red** (`RedProvincias`): vecinos, `ruta(a, b)` por A* (coste = km por tierra, 2 × km por mar; heurística = línea recta × 0,9, nunca pasa el coste real),
  `coste_tramo`, `punto_entre`. Una ruta Colombia → Rusia (82 provincias, pasando por América del Norte y Bering) tarda ~4 ms en calcularse.
- **Velocidad**: `VEL_MARCHA_KM_DIA = 30` km «equivalentes» por día (un tramo por mar cuesta el doble). Bogotá → Vichada (2 provincias, 628 km eq.) = 21 días.
- **Marchas** (`Ejercito.marchas`: ID → `{id, pais, pel[], ruta[], k, km, parar}`): el pelotón sale de `por_prov` (ya no cuenta como «estacionado» en
  ninguna provincia) pero sigue en `por_pais`; su `ubicacion` (con historial) cambia a cada provincia por la que pasa. `en_marcha` marca qué pelotones
  van por el camino. `avanzar_dia()` (lo llama `Mundo.avanzar_dia`, o sea cada día del reloj, también en los saltos de Debug) avanza todas las columnas.
- **Dividir** (`dividir(id, n)`): crea un pelotón nuevo con `n` soldados y los mismos promedios de edad/experiencia/familiaridad. **Tomar**
  (`tomar(prov, país, n)`): elige pelotones (los más grandes primero) que sumen exactamente `n`, partiendo el último si hace falta.
- **Consolidar** (`consolidar(prov, país)`): al llegar una columna (y solo entonces) los pelotones incompletos del mismo país en esa provincia se juntan
  (promedios ponderados por soldados; el pelotón absorbido se disuelve). Mover y volver a mover no produce pelotones diminutos para siempre.
- **Detener** (`detener_marcha`): la columna termina al llegar a la próxima provincia, no en medio del camino.
- **Disolver / mover (teletransporte de Debug)** conocen las marchas: disolver un pelotón en camino lo saca de su columna (si no queda nadie, la
  marcha desaparece); `mover` ignora pelotones en marcha.
- **Reclutar** (ventana): hasta el 2 % de la población de la provincia por orden (mínimo 500). Usa `Ejercito.reclutar` (completa pelotones incompletos del
  país en esa provincia; el resto forma pelotones nuevos). **No cuesta dinero ni quita población.** Solo en provincias del propio país.
- **Permisos**: se ordena solo a tropas del país del jugador; sin jugador (observador) se puede ordenar a cualquiera. Las tropas ajenas se miran.
- `version_pilas` (nuevo) sube cuando cambia quién está dónde o cuántos son; NO con el envejecimiento mensual. `version_marchas` sube cada día que avanza una columna.

## Interfaz
- `scripts/capa_tropas.gd` (`CapaTropas`, hija del mapa, z 14; subcapa de columnas z 15): dos capas para que una columna en marcha no obligue a recolocar
  los cientos de cuadritos quietos.
  - **Pilas**: `ejercito.pilas_todas()` ([provincia, país, soldados, pelotones], en caché hasta que sube `version_pilas`) → arreglos por pila (posición, texto, ancho)
    ordenados por magnitud. Se colocan con rejilla de colisiones por prioridad: pila elegida → tropas del jugador → las demás (solo con zoom de cámara ≥ 1,0).
    Tope 300 cuadritos. Se redibuja al hacer zoom (máx. ~14 veces/s), al cambiar tropas, al mover la cámara más del 12 % de la vista (margen del 30 %).
  - **Columnas**: cuadrito con flecha (rumbo = dirección del tramo), posición interpolada con la fracción del día (`reloj.acum / SEG_POR_DIA`); ruta pendiente
    (continua por tierra, rayada por mar; solo las del jugador, o todas si no hay jugador; la elegida en dorado y más gruesa). Se redibuja ~16 veces por día de juego.
  - **Modo destino**: ruta dorada hasta la provincia bajo el cursor con «N días · K prov.» (o «sin ruta» / «ya están aquí»).
  - **Foco** (doble clic en un país): las posiciones de ese país aplican la misma transformación del «salto» (`foco_centro + (p − foco_centro) × s + foco_dx`).
  - **Clics**: `marcador_en(pos)` busca el cuadrito bajo el cursor (columnas primero). Se evalúa ANTES que la selección normal del mapa.
- `scripts/ordenes_tropas.gd`: ventana flotante (`ventana_flotante.gd`): provincia y tropas, MOVER (barra + número + ¼ ½ Todo + «Mover…»), RECLUTAR (barra + número + 500/1.000/5.000/Máx),
  lista de COLUMNAS EN MARCHA del país (soldados → destino, días que faltan, «Ver», «Parar»).
- `MapaPrincipal.gd`: `abrir_ordenes`, `_cerrar_ordenes`, `_tras_elegir_provincia` (abre/actualiza la ventana al elegir una provincia tuya), `_clic_tropas`, `iniciar_destino`,
  `cancelar_destino` (Esc, antes que la pausa), `provincia_en(pos)`, `_clic_destino`, `_destino_bajo_cursor` (con la posición del ratón cada ≥ 40 ms).
- HUD: la pestaña Ejército de una provincia lleva el botón «Órdenes de tropas…» (señal `ordenes_pedido`).

## Estado de pruebas (honesto)
Godot 4.3 en Linux, xvfb + render por software (sin GPU), con los datos históricos REALES de Camilo (1.902 estados).
- `runner10` (modelo de marchas, 33 comprobaciones, 0 fallos): red cargada (19.448 tierra + 917 mar), ruta de 3 provincias, orden de 1.500 soldados (parte un pelotón),
  total de soldados del mundo constante antes/durante/después, `mover()` ignora pelotones en marcha, llegada a los 21 días (estimado 20,9), historial de `ubicacion`
  con una fila por provincia, consolidación en destino, detener, ruta imposible (isla aislada), mismo destino rechazado, pedir de más se limita a lo disponible,
  disolver pelotones en marcha, ruta a Panamá por tierra, ruta Colombia → Rusia.
- `runner11` (interfaz con CLICS REALES simulados, 26 comprobaciones, 0 fallos + 11 capturas revisadas a ojo): cuadritos en vista mundo (solo tu país) y con zoom 3, foco en Colombia,
  clic abre «Órdenes», reclutar 2.500 (68.234 → 70.734), tope de reclutamiento, barra y número sincronizados, «Mover…» → modo destino, vista previa de ruta y días, Esc cancela
  (sin abrir la pausa), clic en destino confirma, columna dibujada, clic en la columna la selecciona, la marcha avanza con el reloj hasta llegar, pila nueva en el destino,
  tropas ajenas = solo mirar (botones desactivados), observador puede ordenar, cierre de la ventana.
- Regresión sobre el código final: `runner3` (mapa/clics/pausa), `runner5` (base de datos, economía, historiales; su único `ERROR` es intencional), `runner6`
  (barra, Debug, «Mi país»: 48 OK), `runner7` (capa histórica: 43 OK), `runner8` (datos reales, fichas) y `runner9` (ejército: 49 OK): todos 0 fallos y 0 errores de script.
  En el proceso se ajustaron `runner6`/`runner7` (esperaban la versión 9D).
- Rendimiento medido en el servidor (CPU lenta, sin GPU): dibujar las pilas = 12–15 ms con ~300 cuadritos (antes de optimizar eran 40–50 ms); reconstruir las pilas = 13 ms;
  `Ejercito.avanzar_dia` con 20 columnas de ruta larga (80 provincias) = 0,06 ms por día; dibujar 20 columnas con sus rutas = 3,4 ms. A velocidad 6 el reloj sigue dando
  ~260 días/s (igual que antes de esta versión). NO se midió en tu PC.
- **NO probado**: jugar a mano (lo pruebas tú), tu PC real (FPS), Windows, partidas largas con muchas columnas a velocidad 6, ventanas muy anchas (hay código para varias copias del mapa pero no se ejercitó).

## Límites conocidos
- Reclutar NO cuesta dinero, NO quita población y NO tiene tiempo de entrenamiento (solo el tope por orden).
- No hay transporte naval: las islas a más de ~200 km de otra tierra no tienen ruta (51 provincias).
- Las columnas existen solo en memoria (no hay guardar/cargar partida todavía).
- Los tramos son líneas rectas entre centros de provincia (en provincias muy irregulares la línea puede salir del polígono).
- La velocidad de marcha (30 km/día) es provisional; no depende del terreno, de la devastación ni de la forma física.
- Dos columnas de países distintos que se cruzan no hacen nada (no hay guerra).
- Los cuadritos de otros países solo aparecen con zoom ≥ 1,0; con zoom bajo solo se ve tu país.
- Provincias enclave muy pequeñas: el punto interior puede quedar muy pegado a las vecinas (se resuelve con la colisión de cuadritos).
- La máquina del tiempo (antes llamada 9E) pasa a la próxima versión.
- Lo pendiente de versiones anteriores sigue igual (ver `NOTAS_TECNICAS_0.1.7.9.9D.md` y `...9C.md`).

## Cómo regenerar
- `python3 herramientas/construir_vecinos.py` → `datos/vecinos_prov.json`.
- `python3 herramientas/construir_ids.py` → `datos/ids.json` (conserva los IDs).
- `python3 herramientas/hacer_diagrama_bd.py` → diagramas en `docs/`.
