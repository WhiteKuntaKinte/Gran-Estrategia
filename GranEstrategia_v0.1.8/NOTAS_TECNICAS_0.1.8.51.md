# Notas técnicas 0.1.8.51 — Modo combate, obras y fortificaciones en el mapa, 22 maravillas únicas y 77 descubrimientos nuevos

Sale de tus mensajes del 2026-11-16 (14:34 y 23:58): «si estoy construyendo algo tiene que haber una representación visual dentro del mapa», «necesito que metas más descubrimientos, más materiales, más tipos de edificio y que empiece el desarrollo del ataque y el modo combate: que existan las formaciones y que en una cuadrícula puedas poner tu ejército».
Cuatro bloques: **(A) combate táctico** con formaciones y tablero, **(B) obras y fortificaciones visibles en el mapa**, **(C) 22 maravillas únicas + 15 edificios nuevos** (178 en total) y **(D) 25 descubrimientos más, 16 enlaces más y más materias que ayudan**.
Cifras: descubrimientos **1.882 → 1.959** (año 1: 371 → 386; 2026: 1.851 → 1.928), edificios **141 → 178**, enlaces entre ramas **106 → 122**, descubrimientos con materias que ayudan **434 → 516**.

## A. Combate táctico (formaciones y cuadrícula)
- **Datos** (`datos/combate.json`, lo genera `herramientas/construir_combate.py`): 10 clases de tropa, matriz de quién gana a quién, tropas con nivel (cada unidad, arma o vehículo descubierto da una clase), 7 mejoras, 9 terrenos y **48 formaciones históricas** (falange, orden oblicuo, testudo, cuña nórdica, tumen mongol, tercios, brigada sueca, línea y columna, trincheras, guerra relámpago, armas combinadas…). Cada formación se desbloquea con un descubrimiento de táctica; se añadieron **15 tácticas** nuevas al catálogo (`catalogo/z_combate_0.1.8.51.txt`).
- **Motor** (`scripts/combate.gd`): tablero de 8 × 5 (4 columnas por bando), un bloque por casilla, hasta 24 rondas con avance, elección de blanco, daño por clase × nivel × calidad × terreno × formación × matriz, flancos y espalda, moral, huida, colapso y persecución. El azar sale de `azar.gd` (tema 7): misma semilla, misma batalla. Terreno nuevo «cobertura» para el que defiende.
- **Pantalla** (`scripts/pantalla_combate.gd`): eliges formación, colocas tus tropas en tu mitad del tablero, ves la del enemigo, das la orden y la batalla se anima ronda a ronda. Oculta el mapa (como Descubrimientos) y deja el reloj en pausa.
- **Integración con la guerra** (`scripts/guerra.gd`): las batallas del JUGADOR de al menos 2.000 soldados (el otro bando ≥ 1.000) se detienen hasta 3 días y salen como aviso «batalla»: puedes **dirigirla en el tablero** o **dejar que se resuelva sola**. Las batallas entre IA no cambian. El resultado se mete en las tropas del mapa (`Guerra.aplicar_tactico`). Además el poder diario de guerra se multiplica por `nivel_del_ejército^0,20` (el bono estratégico del nivel de tus tropas).
- **Probar:** Debug > Combate > «Abrir el tablero de práctica» (eliges país, rival, terreno y soldados y repites con otra suerte), o una guerra con un ejército grande. El interruptor general está en Debug > Combate (`Guerra.tactico_jugador`).
- Pruebas: `runner108` (motor: catálogo, capacidad, despliegue, reglas de tiro/caballería/lanceros/terreno/fortificación/formaciones, rendimiento) y `runner109` (integración con la guerra y la pantalla).

## B. Obras y fortificaciones en el mapa (`scripts/capa_obras.gd`)
- **Obra en marcha:** insignia con un anillo de progreso dorado y una grúa sobre la provincia (si hay varias, su número y el anillo de la que termina antes). Se ve en lo tuyo, en lo de tus aliados y vasallos y, como observador, en todo.
- **Fortificación:** silueta según la defensa que dan los edificios (`efecto_abs(pi, EF_DEF)`): empalizada, muralla, castillo, fortaleza o plaza fuerte, con puntos de nivel. Umbrales de defensa 0,10 / 0,35 / 0,65 / 0,95 / 1,15.
- **Maravilla:** estrella dorada en la provincia que la tiene, visible en cualquier provincia a la vista (son famosas).
- **Regla del zoom respetada:** tamaño fijo en píxeles, nada se reconstruye por paso de la rueda; durante una ráfaga la capa se desvanece y se rehace UNA vez al parar (usa la señal de `capa_tropas`). Las obras desde zoom 2,5; las defensas desde 7 (desde 3 en la provincia elegida): casi todo está fortificado en 2026 y sería ruido. Tope de 400 marcas por dibujo.
- **Ficha de la provincia:** filas «Fortificación» (nivel y qué suma a los defensores) o «Fortificaciones» (resumen de un grupo) y «Maravillas».
- Interruptor en Debug > Rend. («obras»). Prueba: `runner110`.
- Error que apareció al probarlo: elegir una provincia no redibujaba su fortificación (la firma de redibujo no incluía la selección); ya incluida.

## C. 22 maravillas únicas y 15 edificios corrientes (178 edificios)
**Regla de maravilla:** categoría nueva «Maravillas del mundo» (`cat: "mar"`, campo `unica` en `datos/edificios.json`). Solo puede haber UNA de cada en todo el mundo, construida o en obra: `Edificios._unica_pi` guarda qué provincia la tiene o la está levantando y se mantiene en `_guardar` (construidas y `dar` de Debug) y en `_escribir_obras` (obras, cancelar, cambio de dueño). `puede` explica el motivo («ya se está construyendo / ya existe en X (país): solo hay una en todo el mundo»). Una orden de grupo la levanta en UNA provincia. **No se reparten al empezar** (`sembrar_iniciales` las salta) y **la IA no las construye** (`obras_publicas.gd` las excluye): son del jugador.
Todas con obra grande (E o F), máximo 1 por provincia, descubrimiento propio con año histórico y requisitos de otras ramas, efectos propios (orden, producción, comida, defensa o movilidad según la maravilla) e icono con estrella dorada.

| Maravilla | Año | Obra | Efectos |
|---|---|---|---|
| Grandes pirámides de Guiza | 2560 a. C. | E | orden 4 · producción 0,04 |
| Jardines colgantes de Babilonia | 600 a. C. | E | comida 4 · orden 2 · ciudad 0,02 |
| Partenón y la Acrópolis | 432 a. C. | E | orden 5 · producción 0,03 |
| Coloso de Rodas | 280 a. C. | E | orden 2 · defensa 0,15 · producción 0,04 |
| Gran Biblioteca de Alejandría | 283 a. C. | E | orden 3 · producción 0,04 |
| Gran Muralla | 214 a. C. | E | defensa 0,60 · orden 2 |
| Coliseo romano | 80 | E | orden 5 · producción 0,03 |
| Santa Sofía | 537 | E | orden 6 |
| Gran Mezquita de Córdoba | 785 | E | orden 5 · producción 0,02 |
| Borobudur | 825 | E | orden 4 · comida 2 |
| Angkor Wat | 1150 | E | orden 4 · comida 3 |
| La Alhambra | 1238 | E | orden 3 · defensa 0,20 · producción 0,02 |
| Ciudad Prohibida | 1420 | E | orden 4 · defensa 0,30 |
| Machu Picchu | 1450 | E | comida 3 · defensa 0,25 · orden 2 |
| Taj Mahal | 1653 | E | orden 5 · producción 0,04 |
| Palacio de Versalles | 1682 | E | orden 4 · producción 0,04 |
| Torre Eiffel | 1889 | E | producción 0,08 · orden 2 |
| Cristo Redentor | 1931 | E | orden 4 · producción 0,03 |
| Gran cosmódromo | 1961 | F | orden 3 · producción 0,06 |
| Presa de las Tres Gargantas | 2006 | F | producción 0,15 · movilidad 0,05 |
| Gran colisionador de partículas | 2008 | F | producción 0,04 · orden 2 |
| Megatorre de récord | 2010 | F | producción 0,10 · ciudad 0,03 |

Los efectos de orden, producción, comida y ciudad se diluyen con la población de la provincia (cada maravilla atiende de 200 mil a 6 M de habitantes: rinde más en una provincia pequeña); la defensa y la movilidad no se diluyen. Como cualquier edificio, solo cuentan cuando la obra termina.

**15 edificios corrientes nuevos:** minas subterráneas, canales de riego, aduanas y puestos fronterizos, termas públicas, casas de moneda, puertos pesqueros, campos de adiestramiento, bases navales, refinerías de petróleo, fábricas de automóviles, bases aéreas, plantas químicas, viviendas públicas, fábricas de semiconductores y centros de datos.
- Los 37 salen de una tabla (`edif051.py`, no incluida: de ella salieron `catalogo/z_maravillas_0.1.8.51.txt`, las filas de `anios.tsv`, `construir_edificios.py` (E y categoría), `construir_efectos_edificios.py` y los iconos).
- **Iconos:** 37 PNG de 128 px dibujados por código (`herramientas/iconos_materias/edificios.py`), sin imágenes de terceros.
- **Secciones:** todos los descubrimientos nuevos están fuera de las secciones que alimentan los índices de saber, así que la calibración demográfica no se mueve.
- **Ventana Construir:** las maravillas llevan «★ MARAVILLA ÚNICA»; con varias provincias elegidas se ofrece la primera.

## D. Más descubrimientos, enlaces y materias
- **25 descubrimientos no edificio** (`catalogo/z_horizonte_0.1.8.51.txt`): patentes de invención, microfinanzas, zonas francas, geotérmica, biogás, hidrógeno, almacenamiento en baterías, eólica marina, levitación magnética, motor a reacción, transbordadores rodados, teléfono inteligente, cifrado de clave pública, realidad virtual, control numérico, materiales compuestos, plásticos sintéticos, superconductores de alta temperatura, sondas interplanetarias, rovers, tratado de no proliferación, turismo de masas, misil de crucero, carro de combate principal y helicóptero antisubmarino. (Otros once que se me ocurrieron ya existían y se descartaron.)
- **16 enlaces entre ramas** con su porqué (`enlaces.txt`): 106 → 122.
- **Más materias que ayudan** (`receta_descubrimientos.py`, `MAT_PALABRAS`): madera, pesca, mármol, plomo, zinc, níquel, platino, diamantes y gemas, grafito, tierras raras, cobalto y coltán, cromo, manganeso, potasa, arena, renovables, geotérmica, hidroeléctrica, investigación y turismo. Los descubrimientos con materias pasan de 434 a **516** (31 materias distintas). Siguen siendo solo una ayuda (nunca bloquean) y solo cuentan los países que las producen en `economia.json`.

## 2. Decisiones de diseño (y por qué)
- **Las maravillas son del jugador:** la IA con todo activo en 2026 las levantaría todas en los primeros días; así tienen valor y se pueden disputar. Quedan abiertas: restringirlas a su región histórica y que su efecto crezca con los siglos.
- **Las maravillas no se siembran al empezar:** en 2026 existen en la realidad, pero repartirlas por provincias exigiría un mapa lugar → provincia; por ahora hay que construirlas.
- **Batalla en el tablero solo para el jugador y solo si es grande:** las de IA contra IA siguen resolviéndose sin tablero (una guerra mundial con todas las IA a x6 no puede detenerse a cada batalla).
- **Defensas lejos del mapa no se dibujan:** a zoom 4 casi toda provincia de 2026 es «castillo» o más; la defensa se enseña desde zoom 7 o en la provincia elegida.

## 3. Rendimiento
Medido con `test/runner89` contra una copia de la 0.1.8.50 (git 44b2f28), en el mismo equipo y con la CPU en reposo.

**Día de simulación** (headless, un día con todas las IA, 3 pares seguidos):

| Escenario | 0.1.8.50 | 0.1.8.51 | Diferencia |
|---|---|---|---|
| 2026 (249 IA), pares 1 / 2 / 3 | 11,19 / 9,56 / 11,83 ms | 11,96 / 10,66 / 11,59 ms | media 10,86 → 11,40 ms (+0,5 ms: dentro del ruido, la misma versión varía 2,3 ms entre repeticiones) |
| 1500 (202 IA), pares 1 / 2 / 3 | 5,13 / 5,21 / 4,61 ms | 4,79 / 5,03 / 5,04 ms | media 4,98 → 4,95 ms |

**Mapa y zoom** (ventana virtual con OpenGL por software, 2 pasadas, media de las dos):

| Medida | 0.1.8.50 | 0.1.8.51 |
|---|---|---|
| 2026 · mundo / Europa / Roma (ms por fotograma) | 68,4 / 58,9 / 80,9 | 62,3 / 59,3 / 75,5 |
| Año 1 · mundo / Europa / Roma | 56,0 / 54,4 / 68,3 | 57,5 / 53,5 / 71,5 |
| 40 pasos de zoom y arrastre (ms por paso): 2026 / año 1 | 70,9 / 67,9 | 71,5 / 66,7 |
| Llamadas de dibujo (mundo / Europa / Roma) 2026 y año 1 | 109 / 114 / 109 y 118 / 132 / 104 | idénticas |

- **El mapa no cambia de forma medible:** en esos encuadres (zoom lejano, sin obras ni maravillas a la vista) la capa nueva no dibuja nada: mismas llamadas de dibujo y mismos triángulos; los milisegundos varían entre pasadas más que entre versiones.
- **Peor caso de la capa de obras** (medido con un banco aparte, no incluido): zoom 8 sobre Europa central con 33 fortificaciones a la vista: **2,0–2,4 ms por redibujo** (solo cuando cambia el encuadre, la selección o las obras; nunca por paso de la rueda); fotograma con la capa encendida contra apagada 77,4 / 79,6 contra 75,7 / 77,3 ms (+1,7 / +2,3 ms, dentro del ruido de ±3 ms de esta máquina). A zoom 12 (3 marcas): 64,1 / 66,9 contra 61,2 / 67,6 ms. El tope de 400 marcas acota el caso extremo.
- **No se tocó `_actualizar_zoom`:** la capa reacciona en su propio `_process` y usa la ráfaga de zoom de `capa_tropas`, así que no hizo falta repetir el banco de zoom (`runner90`).
- **Combate:** una batalla completa en el tablero cuesta 2,5 ms; elegir la mejor de las 48 formaciones para un despliegue, 139 ms (solo cuando el jugador lo pide); recalcular la capacidad militar de un país, 0,2 ms. Las batallas entre IA no pasan por el tablero.
- **Memoria:** 445 → 451 MB en 2026 y 294 → 297 MB en 1500 (más datos de combate y 37 iconos que solo se cargan al abrir Construir). Arranque de 2026 sin cambios apreciables (carga de la escena 3.937 → 3.932 ms).
- `runner101` (motor de descubrimientos): 2026 0,93 ms por mes (peor 1,8 ms) y 1500 0,49 ms (peor 2,2 ms), igual que en la 0.1.8.50: los 77 descubrimientos y 16 enlaces nuevos no se notan.
- **Pendiente:** el F9 de tu PC (año 1 con todas las IA a x6 y una partida normal de 2026), que sigue sin llegar desde la 0.1.8.48.

## 4. Revisión de variables
`python3 herramientas/auditar_codigo.py . salida.json`: **1.793 funciones (1.693 en la 0.1.8.50), 0 funciones repetidas, 0 variables repetidas.**
- Ciclos indirectos 27 → 28: el nuevo es de interfaz (`pantalla_combate.gd`: los selectores del tablero de práctica llaman a `_rearmar_prueba` por señal y esta vuelve a `abrir`; solo se encadena por un gesto del jugador, como los demás).
- Sin uso: de los 548 nombres nuevos (funciones, variables y constantes de `scripts/` y `MapaPrincipal.gd`) comprobados con un barrido, solo `Edificios.donde_unica` no se usaba fuera de las pruebas; ahora la usa el mensaje de `puede`. Nuevos con uso: `n_maravillas`, `n_marcas`, `dibujadas`, `ms_dibujo`, `unica`, `_unica_pi`, `_lista_unicas`, `maravillas_de`, `maravillas_del_mundo`, `tactico_jugador`, `pend_tactica`.
- `datos/variables.json` no cambió (las maravillas y las fortificaciones se calculan de lo que ya se guarda en `edificios` y `obras`).

## 5. Pruebas
Regresión completa runner71–111 (runner74 con ventana virtual, 221 comprobaciones): **0 fallos y 0 errores de script.**
- **Nuevas:** `runner108` (50), `runner109` (49), `runner110` (54), `runner111` (42).
- **Ajustadas:** `runner71` (apaga `Guerra.tactico_jugador`: sus batallas del jugador ahora esperarían al tablero), `runner77`, `runner91` y `runner102` (1.959 descubrimientos; 386 en el año 1 y 1.928 en 2026), `runner83` (178 edificios; la orden de grupo elige un edificio que no sea maravilla, porque una maravilla se levanta en UNA sola provincia), `runner88` (178 iconos y 9 categorías de Construir), `runner106` (166 con efecto + 12 de solo saber), `runner111` (1.959).
- Calibración demográfica (`runner104`: 75 comprobaciones) y motor de descubrimientos (`runner101`) sin cambios.
- Ver `test/LEEME_PRUEBAS.txt`.

## 6. Límites y lo que sigue
- La batalla táctica solo se activa o desactiva desde Debug > Combate (y por batalla con «resolver sola»); no hay casilla en Opciones.
- Las batallas entre IA no usan el tablero; no hay asedios ni batallas navales en el tablero.
- Las maravillas no tienen restricción de lugar y no se reparten al empezar.
- Siguen fuera: mantenimiento de edificios, ruinas por guerra, edificios que consuman materias primas.
- Siguiente posible: restringir cada maravilla a su región histórica, asedios en el tablero y el Relieve de altísima calidad (teselas) cuando lo pidas.
