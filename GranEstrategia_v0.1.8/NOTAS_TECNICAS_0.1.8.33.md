# Notas técnicas 0.1.8.33 — Opciones en la pausa, pantalla verificada y MODO DEV con dos épocas (2026 y año 1 d. C.)

## Qué es esta versión
Pedido de Camilo (4 de noviembre, 18:55): *«El menú de opciones no tiene por qué estar solamente en el menú principal, también se tiene que encontrar en el menú de pausa … Le cambié la resolución al juego y no pasó absolutamente nada. Las opciones gráficas parecen ser que no funcionan. Cuando tengas estas dos cosas solucionadas quiero que pasemos a la parte dura del desarrollo … evolucionar junto con tu nación a lo largo de la historia, entonces vas a buscar información de el planeta tierra en el año 1 d. C. y vas a cambiar el modo dev a esta época, quiero poder ser capaz de entrar a los dos mapas por elección … después de seleccionar la opción de modo dev quiero poder elegir entre 2026 y el año 1 d. C. … cuando entre en el año 1 debo de poder ver el mapa del mundo como fue habitado en esa época con el nombre de las naciones del momento.»*
Y, ya con la versión casi lista: *«Antes de mandar el zip revisa el rendimiento y las variables … y quiero que SIEMPRE que mandes una versión nueva le hagas revisiones de rendimiento.»* (Regla permanente desde ahora: cada versión lleva su revisión de rendimiento y de variables; esta sección está más abajo.)
No se pidió número de versión: elegí **0.1.8.33** (`MapaPrincipal.gd` → `VERSION`, `project.godot` y las pruebas que lo comprueban).

## 1. OPCIONES también en la pausa
- La pausa (Esc) ahora usa el mismo panel y los mismos botones que el menú principal: **CONTINUAR · OPCIONES · DEBUG · MENÚ PRINCIPAL · SALIR**.
- OPCIONES abre PANTALLA / INFORMACIÓN igual que desde el menú principal; **VOLVER** regresa a la pausa (antes de esta versión, a ningún sitio: no existía). Funciona con el árbol en pausa (la ventana de pantalla y su cuenta atrás usan `PROCESS_MODE_ALWAYS`).
- Código: `_mostrar_menu_pausa` monta el panel, `_mostrar_pausa_principal` dibuja los botones, `_volver_de_opciones` decide a dónde se vuelve (pausa si `en_pausa`, menú principal si no).

## 2. «Cambié la resolución y no pasó nada»
**Causa más probable (no la puedo comprobar en tu equipo):** en Godot 4.4 o posterior, si ejecutas el juego con F5 desde el editor y la pestaña **«Juego»** tiene activado **«Embed Game on Next Start»**, el juego corre *dentro* de una ventana del editor y es el editor quien manda sobre su tamaño: el juego pide otro tamaño y el editor lo ignora. Por eso ni la resolución ni (a veces) la pantalla completa cambian. Las opciones gráficas del mapa (calidad, mar, costas…) no dependen de la ventana y sí se aplican (en la 0.1.8.32 se comprobaron con capturas); en «Media» el cambio es sutil, en «Baja» es evidente.
Qué se hizo:
- Tras APLICAR se **comprueba** la ventana real (modo, tamaño, posición) y, si no coincide con lo pedido, se reintenta y se vuelve a comprobar unos fotogramas después.
- Debajo de los botones aparece una línea de estado: «**Aplicado:** ventana 1280 × 720 · VSync … · FPS … · calidad …» o un «**AVISO:** la ventana no cambió de tamaño (se pidió X y sigue en Y)» con la explicación y qué desactivar (Godot > pestaña Juego > «Embed Game on Next Start», o ejecutar el proyecto exportado).
- Si la ventana no cambió, la cuenta atrás de «¿Mantener estos cambios?» ya no se queda esperando: no hay nada que mantener, se cierra sola. Y si cierras el menú con la cuenta atrás en marcha, la ventana vuelve a lo anterior.
- `Ajustes.reforzar_ventana`, `Ajustes.discrepancia` y `Ajustes.en_editor_incrustado` (esta última pregunta a Godot con una llamada protegida, porque no existe en 4.3).

## 3. MODO DEV con elección de época
### Flujo
JUGAR → MODO DEV → **«MODO DEV · ÉPOCA»: 2026 / AÑO 1 d. C. / VOLVER** (CAMPAÑA no cambia: sigue siendo Europa en 2026). Si falta `datos/historico/mapa_1dc.json`, el botón del año 1 queda desactivado con una explicación, y pedir el año 1 arranca 2026.
### Qué hay en el año 1 (primer hito: solo mapa, nombres y ficha)
- **126 naciones y pueblos** con su nombre, color, tipo, capital y fechas: Roma (ID 1000011, el mismo del Imperio romano de la semilla), el Imperio parto y sus vasallos, los reinos del Ponto, Capadocia y Comagene, el Reino herodiano (Judea), los nabateos, Himyar, Aksum, Kush, la China Han, los Xiongnu, Goguryeo/Baekje/Silla, Wa, el Gran Yuezhi (Bactria), los Satavahana, Teotihuacán, los zapotecas, los mayas, Moche y Nazca, Hopewell, y decenas de pueblos germanos, celtas, eslavos, bálticos, bereberes, bantúes, polinesios, aborígenes…
- Las 7.653 provincias del mapa quedan repartidas: **7.424 en alguna nación** y **229 «tierra sin poblar»** (polos, islas remotas; se pintan oscuras y no llevan nombre).
- **Los nombres** se escriben sobre el bloque contiguo más grande de cada nación con el mismo sistema que ya usaba el juego para países cambiados (`_actualizar_etiquetas_dueno`, ahora también para dueños que no son un país de 2026). Los nombres de los países de hoy se ocultan.
- **Ficha**: clic (o doble clic) sobre una nación abre arriba a la derecha su ficha: nombre, tipo y capital, «Existió: 27 a. C. – 476 d. C.» si hay fechas, cuántas provincias de hoy cubre, la provincia elegida y la nota «fronteras aproximadas». Esc la cierra (el segundo Esc abre la pausa); clic en el mar también.
- **El tiempo está detenido** en «Año 1 d. C.» (la barra superior lo dice). **No hay** economía, ejércitos, IA, ciudades, Debug ni vista internacional en esa época: son datos y reglas de 2026 y quedan bloqueados (con un aviso en la barra de ayuda) en vez de mostrar cosas falsas.
- El arranque del año 1 reutiliza el motor de dueños de siempre: `bd.inicial_i("propietario", provincia, nación)` por provincia, `_sincronizar_propiedad(true)` y las etapas de fronteras/nombres/zoom. Las naciones entran en la base de datos como entidades históricas (`T_ENTIDAD`, IDs 1.000.011 – 1.100.125), igual que el Imperio romano de la semilla.
### De dónde salen los datos (y qué tan buenos son)
- **Creados desde cero para este proyecto** (no se copió ningún conjunto de datos con licencia GPL ni de otro proyecto): `herramientas/construir_mapa_1dc.py` (tabla de naciones + motor) y `herramientas/reglas_1dc.py` (reglas ordenadas por país actual, nombre de provincia y caja de coordenadas). Generan `datos/historico/mapa_1dc.json` y, con `--png`, una vista previa. Se pueden corregir las reglas y regenerar.
- **Son aproximados.** Las provincias del juego son las de hoy, así que una frontera antigua solo puede pasar entre provincias de hoy: Roma «termina» en el límite de la provincia o estado más cercano a la frontera real del año 1. Donde no había fronteras (tribus, cazadores-recolectores) se usa el área cultural/étnica aproximada. Hay errores y zonas discutibles; dime cuáles y se corrigen.
- Zonas más inciertas: interior de Siberia y de Asia Central, el Sahel, la Amazonía, Norteamérica fuera de Mesoamérica, Papúa y la Polinesia.

## 4. Revisión de rendimiento y de variables (regla permanente)
Banco `test/runner89.gd` (no comprueba, imprime «[B]»; se corre con pantalla virtual por software — MUY lento, solo sirve para comparar — y cada época en su propio proceso). Mismo equipo, mismo tamaño de ventana (1280×720), datos reales. **Tu PC no está medido.**

| Medida | 0.1.8.32 (2026) | 0.1.8.33 · 2026 | 0.1.8.33 · año 1 |
|---|---|---|---|
| Fotograma, mundo entero (ms, por software) | 95,0 | 99,4 | 91,5 |
| Fotograma, Europa | 96,6 | 96,8 | 89,9 |
| Fotograma, Roma de cerca | 71,8 | 74,6 | 63,4 |
| Llamadas de dibujo (mundo / Europa / Roma) | 405 / 393 / 335 | 405 / 393 / 335 | **153 / 96 / 74** |
| Código del juego por fotograma (`_process`) | 0,10 ms | 0,11 ms | 0,08 ms |
| Zoom + arrastre, ms por paso | 92 | 92 | 80 |
| `_iniciar_partida` (una vez) | 77 ms | 80 ms | 202 ms |
| Memoria al abrir → con la partida en marcha | 257 → 265 MB | 259 → 266 MB | 259 → 267 MB |

Medido sobre el contenido del propio ZIP (los datos que recibes). Los ms por fotograma son del dibujo por software de un servidor sin tarjeta gráfica y varían ±5 % de una corrida a otra: lo que cuenta es que las llamadas y los triángulos de 2026 son **idénticos** a la 0.1.8.32. Cargar el mapa del año 1 cuesta 9 ms y ~1,4 MB, una sola vez al abrir el juego.

Lectura: **2026 queda igual** (mismas llamadas de dibujo y mismos triángulos; las diferencias de ms están dentro del ruido). **El año 1 es más barato de dibujar** porque no pinta ciudades ni tropas de 2026 (y la capa de tropas ni siquiera ejecuta su `_process`). El único coste nuevo es el arranque del año 1 (~200 ms, una vez) por crear 126 nombres y rehacer las fronteras de todo el mundo.
**Variables y código:** 0 funciones sin uso (`muertas.py`), 0 variables o constantes de clase sin uso (solo `T_MUNDO` y `T_CIUDAD`, números de tipo documentados), 0 avisos del analizador de GDScript en las pruebas. Catálogo de variables de la base de datos (`variables.json`): 56 variables, sin IDs ni nombres repetidos, todos los tipos válidos y todos los `aplica_a` conocidos. Datos del año 1: IDs, nombres y claves únicos; los 126 nombres registrados en la base; ningún nombre antiguo choca con un país de 2026; cada nación tiene ≥ 1 provincia y su contador coincide.

## 5. Pruebas
- Nuevo `runner75` (72 comprobaciones): datos del año 1, menú JUGAR → MODO DEV → época, arranque del año 1 (dueños, colores, nombres, reloj, barra), ficha con clics reales sobre Roma y Chang'an, Esc, tiempo detenido (x3 y Espacio no lo mueven), Debug/vista/tropas/ciudades bloqueados, 2026 sin cambios y arranque sin datos antiguos.
- `runner74` ampliado (pausa → OPCIONES → PANTALLA / INFORMACIÓN → VOLVER; comprobación de la ventana): 210 comprobaciones.
- Regresión completa: **34 pruebas con los datos reales (1.193 comprobaciones) y 4 con los de semilla, 0 fallos**. Tres pruebas antiguas tuvieron que actualizarse porque verifican cosas que cambiaron a propósito: el número de versión (`runner6`, `runner7`, `runner30`) y el total de territorios en la base (`runner7`, `runner8`, `runner9`: ahora hay 125 – 126 naciones antiguas más). `runner73` tiene una comprobación que depende de la velocidad del equipo («días del último paso ≤ 31»): falló una vez bajo carga y pasó al repetirla; no está relacionada con esta versión.
- **No se probó:** tu PC real (la ventana del editor incrustado, VSync, pantalla completa, FPS con tu GPU) ni la calidad histórica de cada frontera.

## Qué viene después (no está hecho)
Economía, población, ejércitos y reloj de la época antigua; calendario propio; vincular el año 1 con el 2026 (que las naciones evolucionen hasta las de hoy) y más épocas. Para esto el motor ya tiene entidades históricas con predecesoras y sucesoras (`datos/historico/entidades.json`).
