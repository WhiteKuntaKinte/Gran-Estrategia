# Checklist de testing — Gran Estrategia 0.1.8.37a

Leyenda: ✅ probado por mí en el servidor (Godot 4.3, sin GPU, con tus datos históricos reales) · 🟡 probado solo parcialmente · ⬜ NO probado (lo pruebas tú en tu PC).
Todas las pruebas automáticas se ejecutan con clics, arrastres y teclas simulados sobre el juego real, no sobre una copia del código.

## A. Pruebas automáticas (las hago yo en cada versión)

### Mapa, interfaz y datos
- ✅ `runner3` — mapa: clic selecciona, doble clic enfoca un país, V cambia de vista, X cierra, clic en el mar, Esc pausa y reanuda.
- ✅ `runner5` — base de datos: territorios, variables, historiales, economía (su único «ERROR» en el log es intencional: prueba que se rechaza una variable que no aplica).
- ✅ `runner6` — barra superior, Debug, «Mi país», versión del juego (48 comprobaciones).
- ✅ `runner7` — capa histórica: estados por fecha, nombres, banderas, personas y cargos (43 comprobaciones).
- ✅ `runner8` — datos históricos reales (1.902 estados) y fichas.

### Ejército y tropas (0.1.7.9.9D / E)
- ✅ `runner9` — ejército en la base de datos: reclutar, bajas, mover, devastación, mes de servicio, disolver (49 comprobaciones).
- ✅ `runner10` — marchas: ruta, días, total de soldados constante, detener, rutas imposibles, Colombia → Rusia (33 comprobaciones).
- ✅ `runner11` — (RETIRADO en la tercera tanda de 9F: probaba el panel de órdenes viejo; lo cubre `runner25`).

### Regimientos, precios, guerra y batallas (tercera tanda de 9F)
- ✅ `runner24` — lógica: regimientos (todo pelotón tiene uno, suman todos los soldados), precios por unidad y balance diario, reclutar paga y crea un regimiento NUEVO, unir/dividir/disolver a propósito, dos columnas que llegan a la misma provincia NO se funden, atacar una provincia ajena declara la guerra, batalla con historial día por día, rivales, paz, historial de guerras (48 comprobaciones).
- ✅ `runner25` — interfaz con clics reales y capturas: el HUD de tropas se abre al pulsar un cuadro, reclutar cobra, regimientos apilados y «+N», dividir/unir, aviso «¡GUERRA con …!», guerra declarada por clic, cuadro de batalla con espadas, pestañas Diplomacia (antes «Guerras») y Batallas, paz, precios mensuales, y ningún cuadro pisa un nombre de provincia visible (Colombia, zoom 6).

### HUD nuevo, selección múltiple y capas (0.1.8)
- ✅ `runner27` — humo del HUD: abre un país en cada pestaña (General, Economía…), clic en el nombre de tu país → General, clic en el dinero → Economía, y Militar > Regimientos deja activo el panel de tropas; capturas revisadas a ojo.
- ✅ `runner28` — con clics reales sobre las cajas del mapa: clic normal elige solo ese regimiento; Ctrl+clic en otra caja → 2 elegidos, en una tercera → 3 (el mapa marca los 3); Ctrl+clic sobre uno elegido lo quita y otro Ctrl+clic lo vuelve a añadir; las órdenes de grupo sacan en marcha a los 3 regimientos y limpian la orden pendiente; Disolver con UN clic (uno solo y varios a la vez) sin ningún diálogo de confirmación en el árbol de nodos; ningún elemento del mapa se dibuja sobre las cajas (máximo del resto 20 < cajas 214/215) y las cajas viven en su propia capa (22 comprobaciones). NO cubre el Ctrl+clic en las filas de la lista (eso lo pruebas tú).
- ✅ `runner29` — capturas del menú principal, Debug, «Mi país», pausa y Política (sin comprobaciones: se revisan a ojo).
- ✅ `runner25` — portado al HUD nuevo: Militar dentro del país, Diplomacia con «Firmar la paz», 0 fallos.
- ✅ `runner9` y `runner17` — ajustados a los nombres nuevos (pestaña «militar»; un clic en un cuadro de pila = `abrir_ordenes` con ese regimiento). Una vez `runner17` falló mientras otra prueba corría a la vez en el servidor y las dos repeticiones siguientes pasaron limpias: es una prueba sensible al tiempo (arrastres simulados), no un fallo reproducible.

### Temas, mapa y vista de Relieve (0.1.8.37)
- ✅ `runner78` (nuevo) — **74 comprobaciones**, 0 fallos: las tres paletas de tema (válidas, distintas, texto legible según contraste WCAG), `aplicar(id)`, ajustes `tema` y `bordes` (sanear, guardar, cargar), el selector «Interfaz» de Opciones (cambio en vivo + guardado al momento + no deja APLICAR activo + se ignora durante «¿Mantener estos cambios?»), el HUD que se repinta sin reiniciar y el menú principal y la pausa con el tema nuevo.
- ✅ `runner79` (nuevo) — **112 comprobaciones**, 0 fallos: menú VISTA (7 entradas, 3 activas y 4 «próximamente», el botón de la barra muestra la vista puesta, se abre y se cierra); selección (relleno amarillo, borde negro y resplandor en 3 copias, el contorno tiene exactamente las aristas exteriores de la provincia, caché, grosor en píxeles al cambiar el zoom, respiración en marcha, borrar lo deja limpio, el país enfocado ya no se agranda); Ctrl+clic (suma, quita, 2 países sin foco, con uno ya elegido, el mar no suma); bordes Baja / Media / Alta (parámetros del shader por nivel, presets, desplegable de Opciones); etiquetas (sentido de lectura de las 256: ninguna con la cuerda fuera de rango, ninguna letra pasada de ±90°, todas en el sentido de su línea, y las verticales AMÉRICA DEL SUR, CHILE, ISRAEL, MYANMAR); paleta (solo colores nuevos en los países y en el relleno horneado); vista de Relieve (las 3 imágenes miden lo que deben, la capa, el mar y el relleno se apagan, silueta con relieve, nombres con contorno, colores de la imagen: Atlántico azul, fosa de las Marianas más oscura, llanura verde, Tíbet marrón, Antártida blanca, lago Superior agua; calidad Baja → 2048 px y Alta → 8192 px con la vista puesta; volver a Tradicional lo devuelve todo; Debug > Rendimiento no reaparece el relleno).
- ✅ `runner72` (121/121) — ajustado: el panel ya no baja con «Ranking» (la barra lo contiene). `runner74` — versión 0.1.8.37.
- ✅ **Capturas revisadas a ojo** (servidor, dibujo por software): los 3 temas en panel de país, menú VISTA, Opciones y pausa; selección de una provincia y de un país; bordes Baja / Media / Alta lado a lado; AMÉRICA DEL SUR, CHILE, BOLIVIA, ARGENTINA leyéndose en un solo sentido; vista de Relieve en el mundo, en Europa, en los Alpes y con Francia enfocada.
- ✅ **Revisión de rendimiento** (`runner89`, dibujo por software, frente a la 0.1.8.36 con los mismos datos): `runner89` por software (la 0.1.8.37 con calidad de bordes **Alta**, el peor caso, contra la 0.1.8.36; dos pasadas cada una): ms por fotograma en 2026 — mundo 91 / 94 frente a 88 / 87, Europa 89 / 90 frente a 82 / 83, Roma 66 / 58 frente a 54 / 56 (≈ +5 a +12 %, que es el coste de suavizar los bordes en el shader; con calidad de bordes Baja el dibujo es el mismo que antes); triángulos iguales (+~100); `_process` 0,08–0,10 ms igual; 40 pasos de zoom+arrastre 77–80 ms frente a 65–70; simular 1 día con 249 IA 5,1–5,2 ms frente a 4,9–5,3 (igual); arranque 2,2 s igual; memoria 306 frente a 305 MB, 13 nodos más. La vista de Relieve no cuesta nada mientras no se enciende (la imagen se carga la primera vez). Bordes por nivel (3 s por medida, 2 pasadas): Baja 73–78 ms, Media 79–85, Alta 82–86.
- ✅ **Revisión de variables y código**: 25 archivos, 1.046 funciones, 0 duplicadas, 0 variables repetidas, 0 funciones sin uso y 0 variables de clase sin uso nuevas (quité `foco_contornos`, que ya nadie llenaba); `datos/variables.json` sin cambios.
- ✅ **Regresión final de la 0.1.8.37**: runner71 181, runner72 121, runner73 84, runner75 145, runner76 97, runner77 88, runner78 74, runner79 112 (headless) y runner74 220 (con ventana, xvfb): **1.122 comprobaciones, 0 fallos y 0 errores de script**.
- ⬜ NO probado: tu PC real (FPS de los tres niveles de bordes con tu tarjeta; la carga de ~0,8 s de la imagen de 8192 al encender el Relieve y su memoria de vídeo ~180 MB; cómo se leen los nombres sobre el relieve en tu pantalla); la calidad de la paleta nueva «a tu gusto»; los temas con **todas** las ventanas (el Debug y las ventanas de detalle toman colores y letra pero siguen con su estructura vieja: se rehacen en la 0.1.8.38).

### Descubrimientos enlazados con el reloj (0.1.8.36)
- ✅ `runner77` (nuevo) — **88 comprobaciones**, 0 fallos (85 en el proyecto de semilla, que no trae el paquete del año 1 d. C.): catálogo coherente (1.730; todos con año, prerrequisitos que existen, sin ciclos, año ≥ año de sus prerrequisitos, año dentro de su era); frontera histórica igual a una cuenta por fuerza bruta en 31 años; cierre de prerrequisitos en 18 años; avanzar año a año = empezar directo; saltos hacia adelante y hacia atrás; conceder / quitar / reiniciar por país (sin tocar a los demás); disponibles; textos de año («44 a. C.», «2.600.000 a. C.»); y dentro del juego: 2026 (1.699), año 1 d. C. (353), 100 años de reloj, el salto de fecha del Debug y la pestaña Descub. (60 filas sin filtro, búsqueda, ficha, resumen).
- ✅ `runner71` (180/181 comprobaciones), `runner72` (120/121), `runner73` (83/84), `runner74` (219/220, con ventana real en Xvfb; en `--headless` 14 comprobaciones de ventana fallan porque no hay ventana), `runner75` (145), `runner76` (97): 0 fallos. `runner74`, `runner30`, `runner6` y `runner7`: versión 0.1.8.36.
- ✅ **Revisión de rendimiento** (`runner89` por software, dos pasadas con el catálogo y dos sin él): +~0,1 s al abrir el mapa, +1 MB de memoria, el resto dentro del ruido (ms por fotograma 98–103 con y sin; simular 1 día con 249 IA 6,2–6,5 ms con y 5,7–6,5 sin). El módulo en sí: ~12 ms al leer y armar los arreglos (una vez), 0,05 ms iniciar, 0,45 ms avanzar 100 años con 249 países con estado propio. Detalle en `NOTAS_TECNICAS_0.1.8.36.md`.
- ✅ **Revisión de variables y código**: 25 archivos, 1.013 funciones, 0 duplicadas, 0 variables repetidas, 0 funciones sin uso y 0 variables de clase sin uso en el módulo nuevo (quité un gancho, una función y una variable que nadie leía); `datos/variables.json` sin cambios (los descubrimientos no son variables de territorio).
- ✅ **Generador** `construir_descubrimientos.py --solo-comprobar`: 1.730 descubrimientos · 40 secciones · 149 subsecciones · conocidos en el año 1: 353 · en 2026: 1.699.
- ✅ **Regresión final de la 0.1.8.36**: 36 pruebas en los datos reales (`runner8 9 10 15 16 17 21 23 24 25 26 27 28 30 31 32 40 41 42 43 44 46 48 49 52 53 54 55 60 71 72 73 74 75 76 77`: 1.461 comprobaciones «OK», 0 fallos, 0 «SCRIPT ERROR» / «Parse Error») y 9 en los de semilla (`runner3 5 6 7 71 72 73 74 77`: 782 «OK», 0 fallos).
- ⬜ NO probado: tu PC real (la pestaña Descub. con una GPU real; cómo se siente con tu ratón la lista de 60 filas); el equilibrio de la historia (años de la Edad Media y de la prehistoria aproximados, la última era inventada). Los descubrimientos todavía no hacen nada en la partida (sin investigación, sin efectos).

### El mapa en celdas y la forma del territorio (0.1.8.35)
- ✅ `runner76` — territorio: tablas coherentes (celda ↔ provincia ↔ anillos ↔ pares) tras cada operación; clic, color de la celda y fronteras entre países (contra una cuenta por fuerza bruta) tras mover celdas; `fusionar`, `ceder`, `dividir` (también hacia una provincia sin celdas, el trozo nuevo es de una pieza), `deshacer`, `restablecer`, señal `forma_cambiada`; baile aleatorio de 40 celdas; gancho de texturas (con textura, sin ella, calidad Baja, carga automática de `relieve.png`); herramientas del Debug; el año 1 d. C. con las mismas celdas y otro reparto.
- ✅ `runner15` (anexión Francia → España) adaptado a celdas: los colores de las 101 provincias leídos de las mallas son EXACTAMENTE los de España, y las fronteras dibujadas coinciden con las lógicas, al anexar y al devolver.
- ✅ `runner75`: el paquete del año 1 ya no duplica la geometría y ambos escenarios reparten las mismas 16.056 celdas.
- ✅ `runner74`: resolución interna en pantalla completa (ajustes `ancho_fs`/`alto_fs`, lista de resoluciones, menú).
- ✅ `runner17` (arrastrar tropas) con la rejilla de clic: 0 fallos (sin la rejilla fallaban 4 chequeos porque cada consulta recorría las 16.056 celdas); `runner76` mide la rejilla: 6 µs frente a 7.836 µs y mismo resultado que la cuenta completa.
- ✅ **Revisión de rendimiento** (`runner89`, 0.1.8.34 y 0.1.8.35 en la misma máquina, dos pasadas): +12 % / +18 % / +7 % de triángulos en vista mundo / Europa / Roma, +39 MB de memoria tras cargar, +0,1–0,2 s de carga, simulación sin cambio; año 1 d. C. +0,5 % / +4 % / 0 % de triángulos. `datos/` baja de 113 a 80 MB. Tabla en `NOTAS_TECNICAS_0.1.8.35.md`.
- ✅ **Revisión de variables y código**: 981 funciones, 0 duplicadas, 0 variables repetidas, 0 funciones sin uso (los ciclos que marca el auditor son los de siempre; el de `Territorio.provincias_vecinas` es un falso positivo: llama a `fusion.provincias_vecinas`).
- ✅ **Capturas del mapa** revisadas a ojo (mundo, Europa, Pirineos, zoom máximo en la península ibérica): sin costuras ni huecos entre celdas del mismo país; y una reforma de frontera (EE. UU. → Canadá en Alaska): la línea se redibuja y desaparece el tramo que quedó interno.
- ✅ **Regresión final de la 0.1.8.35**: 35 pruebas en los datos reales (`runner8 9 10 15 16 17 21 23 24 25 26 27 28 30 31 32 40 41 42 43 44 46 48 49 52 53 54 55 60 71 72 73 74 75 76`: 1.373 comprobaciones «OK», 0 fallos, 0 «SCRIPT ERROR» / «Parse Error») y 8 en los de semilla (`runner3 5 6 7 71 72 73 74`: 697 «OK», 0 fallos). Las pruebas 3, 5, 32, 42, 43 y 46 no cuentan «OK» (son capturas o humo).

### Escenarios: el año 1 d. C. con las mismas mecánicas que 2026 (0.1.8.34)
- ✅ `runner75` (reemplazada) — 144 comprobaciones de **paridad de escenarios**: datos del escenario (archivos, conteos, población del mundo, banderas, créditos Cliopatria), menú JUGAR > MODO DEV > ESCENARIO y cuándo se recarga el mundo, arranque del año 1 (reloj 1/1/1, base de datos, naciones, colores propios, nombres, INFORMACIÓN con créditos), **HUD con sus cinco pestañas dibujadas al elegir una nación y una provincia**, economía (población, PIB, producción, tesorería que se mueve), ejércitos (tamaño razonable, < 4 % de la población, casi nadie en bancarrota), reloj corriendo a x3, capa de tropas y ciudades visibles, guerra Roma–Partia, 400 días con 40 IA (actúan), Debug (propone el año del escenario) y vista, tierras sin reclamar (no se atacan ni se controlan, sin IA ni soldados, HUD sin errores), cada cultura en su sitio (caledonios, Roma en Roma y en Alejandría, Han, Partia, dacios, Amazonía, Sáhara, Patagonia, ~31 % de la tierra sin reclamar), 2026 intacto (7.653 provincias, sus países, reloj 2026) y la campaña desde el año 1 recarga 2026.
- ✅ **2026 es bit a bit lo mismo**: huella determinista (500 días con IA en los 249 países: tesorería total, soldados, provincias) idéntica en la 0.1.8.33 y en la 0.1.8.34; las pruebas de base de datos (`runner7`, `8`, `9`) vuelven a los conteos de antes de la 0.1.8.33.
- ✅ `runner74` — 210 comprobaciones (versión actualizada).
- ✅ **Revisión de rendimiento** (`runner89`, banco de escenarios, por software, 1280×720): 2026 sin cambios (405/393/335 llamadas de dibujo, ~93–97 ms por software); año 1: 500/473/310 llamadas y un 5–10 % más de ms en el dibujo por software, pero simular un día con todas las IA cuesta 1,45 ms (7,4 en 2026) y gasta 185 MB (272 en 2026). Detalle en `NOTAS_TECNICAS_0.1.8.34.md`.
- ✅ **Revisión de variables y código**: 0 funciones sin uso, 0 variables de clase sin uso (salvo las constantes de tipo `T_MUNDO`/`T_CIUDAD`, que ya estaban), 0 duplicados, 0 avisos del analizador.
- ✅ **Capturas del mapa del año 1** revisadas a ojo (Europa, Gran Bretaña con los caledonios, Mesoamérica y Norteamérica): provincias por todas partes, sin cuadrados ni óvalos, grandes zonas sin reclamar, sin rayas negras sueltas dentro de las naciones.
- ✅ **Regresión final de la 0.1.8.34**: 34 pruebas en los datos reales (`runner8 9 10 15 16 17 21 23 24 25 26 27 28 30 31 32 40 41 42 43 44 46 48 49 52 53 54 55 60 71 72 73 74 75`: 1.265 comprobaciones «OK», 0 fallos, 0 «SCRIPT ERROR» / «Parse Error») y 8 en los de semilla (`runner3 5 6 7 71 72 73 74`).
- ⬜ NO probado: tu PC real (FPS con tu GPU; la ventana del editor incrustado de Godot 4.4+), el balance de la guerra y de la IA con los ejércitos del año 1 **jugando** (solo se probó que corren sin errores 400 días), ni la exactitud histórica de cada frontera y de cada pueblo.

### Pausa y pantalla (0.1.8.33)
- ✅ OPCIONES en la pausa y comprobación de la ventana real (`runner74`, 210 comprobaciones).

### Rendimiento y opciones gráficas (0.1.8.32)
- ✅ **Banco de rendimiento** (`runner80`, no se entrega): campaña real de España con IA en todos los países, 400 días de guerra, cronómetro por fotograma y por función, `--headless` (solo cuenta el código del juego, no el dibujo de la tarjeta). Antes y después en el mismo equipo: ver `NOTAS_TECNICAS_0.1.8.32.md`.
- ✅ **A x1–x3 el juego es idéntico**: la huella determinista (`runner70`) da los mismos números que la 0.1.8.31 en fecha, soldados, hash de tropas, guerras, batallas, decisiones, paces, población, dueños y marchas. A x4–x6 solo difiere la tesorería total (~2·10⁻⁷ en relativo) por el desarrollo mensual por grupos de meses.
- ✅ `runner71` — 181 comprobaciones (cierre del periodo por trozos, IA decide de a 1, `fase_batallas` por lotes); `runner72` — 121; `runner73` — 84; `runner74` — 176 (14 ajustes, calidades Alta/Media/Baja/Personalizada, mar liso, costas, líneas de provincia, ciudades, lagos, prioridad de la simulación, aplicar a la ventana, guardar/cargar, confirmar/revertir).
- ✅ Pruebas ajustadas a lo nuevo: `runner15` (espera al repintado por etapas), `runner71` (cierre por trozos, IA de a 1), `runner8`, `9`, `10`, `24`, `44`, `45`, `57` (ya no usan `cuenta_regimientos`, `pelotones_de` ni `posicion_marcha`, que se quitaron por no usarse en el juego).
- ✅ Capturas de la ventana PANTALLA con la barra de desplazamiento arriba y abajo (1280×720): nada cortado.
- ✅ Auditoría estática: 23 archivos, 911 funciones, 0 duplicadas, 0 variables repetidas, sin funciones sin usar (ninguna sin llamadores en el juego).
- ✅ **Regresión final de la 0.1.8.32**: las 34 pruebas de siempre + `runner71`, `72`, `73` y `74` en los datos históricos reales (38 escenas, **1.148 comprobaciones «OK»**, 0 fallos, 0 «SCRIPT ERROR» / «Parse Error») y `runner3`, `5`, `6` (48) y `7` (43) en los datos de semilla, todas en 0 fallos. Las versiones comprobadas en `runner6`, `7` y `30` ya decían 0.1.8.32. (`runner6` y `7` se ajustaron: ya no usan `caja_dinero` ni `cuenta_regimientos`.)
- ⬜ NO probado: tu PC real (FPS reales con tu GPU, VSync, pantalla completa, resolución con tu monitor, dos monitores, escalado de Windows) y cuánto ganan las opciones «Calidad Baja», «Mar liso» y «Costa de detalle bajo» en tu tarjeta.

### Opciones: ventanas PANTALLA e INFORMACIÓN (0.1.8.31)
- ✅ `runner74` — **124 comprobaciones**, 0 fallos:
  - **Ajustes (lógica pura)**: valores por defecto; `sanear` con tipos equivocados, fuera de rango, decimales y claves desconocidas; `iguales`; guardar → cargar; archivo ausente, a medias, con valores raros o ilegible; resoluciones según la pantalla (y un tamaño actual que no está en la lista); centrar la ventana; recortar a la pantalla; cuándo se pide confirmación.
  - **Sobre la ventana real**: aplicar 60 FPS, suavizado 4x, VSync apagado, 1024×576, pantalla completa y vuelta a ventana (centrada, sin bordes); `leer_actual` con y sin ajuste previo.
  - **Ventana PANTALLA**: cada desplegable y casilla llega a lo pendiente; APLICAR apagado sin cambios; RESTABLECER; en pantalla completa se apagan resolución y «sin bordes»; APLICAR sin confirmación (se guarda ya), con confirmación (no se guarda todavía), cuenta atrás, MANTENER, REVERTIR con el botón, REVERTIR por tiempo, REVERTIR desde pantalla completa.
  - **Menú**: OPCIONES → PANTALLA / INFORMACIÓN / VOLVER; INFORMACIÓN con sus tres cifras, la nota y la versión; ir y volver entre menús; lo aplicado llega al mapa; contador de FPS encendido/apagado (la versión siempre se ve); `_cargar_ajustes` con y sin archivo.
- ✅ Capturas de las pantallas nuevas (submenú, PANTALLA, «¿Mantener estos cambios?», INFORMACIÓN) revisadas: nada cortado ni fuera de sitio a 1280×720 ni con la ventana reducida a 1024×576.
- ✅ Auditoría estática: 23 archivos, 892 funciones, 0 duplicadas, 0 variables repetidas.
- ✅ **El juego no cambió**: la huella determinista (`runner70`, campaña de 2 años con semilla fija) da exactamente los mismos números que en la 0.1.8.25.
- ✅ **Regresión final de la 0.1.8.31**: las 38 pruebas de siempre, 677 comprobaciones «OK», 0 fallos y 0 «SCRIPT ERROR» / «Parse Error»; más `runner71`, `72` y `73` (la 0.1.8.25) y `runner74` (esta versión), todas en 0 fallos. Las versiones comprobadas en `runner6`, `7` y `30` se actualizaron a 0.1.8.31.
- ✅ `project.godot`: los ajustes van a una carpeta fija (`GranEstrategia`), para que no se pierdan al pasar de una versión a otra.
- ⬜ NO probado: tu PC real (cambiar la resolución, pantalla completa, VSync y límite de FPS con tu monitor y tu driver), dos monitores y el escalado de Windows.

### Limpieza de código y pruebas unitarias (0.1.8.25)
- ✅ **Huella determinista** (`runner70`): campaña con semilla fija, 2 años a pasos de 1–2 días, 3 puntos de control (fecha, soldados, hash de tropas, guerras, batallas, decisiones de la IA, paces, tesorería, población, hash de dueños, marchas). Tomada antes del refactor y comparada después: **idéntica, carácter por carácter**. Es la prueba de que la limpieza no cambió el juego.
- ✅ `runner71` — **lógica (178 comprobaciones)**: `Perfil.anotar`; `Reloj` (`sumar_dias` en fin de mes/año/bisiesto/k raros, pasos de varios días = días sueltos sobre 1.500 días, `acumular` en las 6 velocidades, `avanzar`); `Mundo` (`ve_todo`, `rival_por_entrar`, `fases_dias`, `avanzar_dias`); `Ia` (`tregua_restante`, `control_cambiado` en todas las transiciones, `_armar_cola`, `fase_dia` por lotes, `_frente_de`); `Guerra` (`_fraccion_de_bajas`, `_aplicar`, `_quien_se_retira`, `_sub_ronda`, `_ronda`, `fase_batallas`, `_escanear_ocupaciones`); `MapaPrincipal` (`texto_duracion`, `_tregua_dias`, `puede_ordenar_pais`, `puede_declarar_guerra`, `declarar_guerra_jugador`, `_aviso_sin_guerra`, `_fases_mes`, `_cierre_periodo`, `_medir_etiqueta`, `etiqueta_tramo`); `Ejercito.ordenar_marcha_reg`.
- ✅ `runner72` — **interfaz y reloj de pasos (120)**: HUD (pestañas, compacto, `set_campana`, botón de guerra, doble pulsación); ventana flotante (`cambiar_tam`, ◢, encoger); Debug (`_nueva_pagina`); capa de tropas (`_tids_visibles`, `_color_de`, `_aviso_guerra`); `_poner_velocidad`, `_on_dia`, `_on_dia_diferido`, `_correr_fases`, cámara de campaña; `eventos_de`, `_armar_balances`, `_economia_dia(k)`; `_estado_nuevo`, `registrar_paz`, `desactivar`, `_decidir`; `_repartir_pais`, `detener_marcha` y `avanzar_mes` por grupos = mes a mes.
- ✅ `runner73` — **lo que faltaba (83)**: `_medir_sinc`, `_presupuesto_restante`, `_avanzar_reloj`; IA `_economia`, `_reclutar`, `_buscar_guerra`, `_operar`; `_avanzar_ocupaciones`; pestaña Diplomacia; `_mandar_tropas`; página de regimientos; `_preparar_campana`.
- ✅ **Cobertura**: de las 92 funciones añadidas o cambiadas desde la 0.1.8.2a, 80 tienen pruebas directas; las otras 12 (pantallas y flujos grandes) las cubren las pruebas con clics y capturas de antes. Las pruebas no encontraron ningún error real del juego (los fallos que salieron al escribirlas eran expectativas mal escritas y se corrigieron).
- ✅ Auditoría estática de la 0.1.8.25: 21 archivos, 857 funciones, 0 duplicadas, 0 variables repetidas; `datos/variables.json` sin cambios.
- ✅ Regresión final de la 0.1.8.25: las 38 pruebas de siempre, 677 comprobaciones «OK», 0 fallos y 0 «SCRIPT ERROR» / «Parse Error»; más `runner71`, `72` y `73` (381 comprobaciones nuevas, 0 fallos). Las tres nuevas van en la carpeta `test/` del ZIP: ábrelas en Godot y pulsa F6 (ver `test/LEEME_PRUEBAS.txt`).
- ⬜ NO probado: jugar a mano ni tu PC real. Esta versión no cambia el juego, así que lo único que hay que comprobar es que sigue igual que la 0.1.8.3.

### Declarar la guerra, IA acotada, tregua, observador, tiempo, Debug redimensionable y HUD (0.1.8.3)
- ✅ `runner66` — declarar la guerra desde Diplomacia (17): la pestaña lista vecinos «declarables» y la «relación»; mandar tropas a su territorio sin guerra se bloquea con aviso; 1.ª pulsación pide confirmar, 2.ª declara; ya en guerra la orden pasa; declarar dos veces o a uno mismo se rechaza; el observador no declara ni da órdenes en la campaña; tras la paz la tregua dura años y el jugador puede romperla.
- ✅ `runner67` — observador (12): campaña sin país con 51 IA, ve las tropas de todos los países con ejército (41 de 41), no ordena; tomar y soltar España y Francia hace que la IA deje/tome el país; la IA sigue decidiendo (1.310 decisiones en 300 días).
- ✅ `runner68` — HUD y Debug (19) con capturas revisadas a ojo: el panel mide ≤ 430 px de ancho y ≤ 80 % del alto en las 5 pestañas; ▾/▸ lo encoge y lo abre; el Debug arranca más angosto, « » lo angostan y ensanchan sin salirse de la pantalla, el alto se puede achicar y la ventana llega a ~290 px.
- ✅ `runner69` — modo dev con ~250 IA durante un año (8): los soldados totales no pasan de 1,6 × lo inicial, ningún país pasa de 2,6 × su ejército inicial, las guerras simultáneas tienen tope, el observador ve las tropas de todos (> 50 países) y con un país elegido solo las tuyas.
- ✅ `runner61` — tregua: una IA vecina declara la guerra al jugador, paz blanca, en 400 días ese país no vuelve a declararla y la tregua restante es > 1.000 días.
- ✅ Ajustados a lo nuevo: `runner16` (el observador ve todo), `runner25` (la vista previa dice «Sin guerra con Venezuela», el clic no declara; se declara desde Diplomacia y entonces la orden sale), `runner48` (52 opciones de país con «observar», sin selector de IA, IA en todos los países de la campaña menos el tuyo), `runner49` (se apaga la IA de Portugal para probar el aviso «no tiene IA»; con IA: «Sin guerra con Francia…»), `runner6`/`runner7`/`runner30` (VERSION 0.1.8.3).
- ✅ Diagnósticos de rendimiento (imprimen números, no comprueban): `runner62` (línea base con IA en todo el mundo, dev o campaña), `runner63` (micro-perfil de economía, mes y decisiones), `runner64` (velocidad real por nivel de velocidad), `runner65` (crecimiento del historial por año). Medido en mi servidor, sin pantalla: dev con 249 IA aguanta x5 al 99 % y x6 al ~58 % (≈216 días/s); campaña con 50 IA x6 al ~89 % (330 días/s).
- ⬜ NO probado: jugar a mano; tu PC real (FPS y cuánto aguanta x6 con pantalla); si los ejércitos y las guerras de la IA ahora son jugables (los números son provisionales); cómo se siente el HUD nuevo en tu pantalla.

### Ejércitos iniciales, rutas, avisos de guerra, negociación, colores, provincias y rendimiento (0.1.8.2a)
- ✅ `runner9`, `runner17`, `runner24`, `runner25`, `runner28`, `runner30` — ajustados al reparto nuevo (todo el ejército de un país nace en su capital como un regimiento; antes uno por provincia). `runner28` (selección múltiple de cajas en varias provincias): 22/22.
- ✅ `runner6` (48/48) y `runner7` (43/43) con VERSION 0.1.8.2a; `runner6` ya cuenta días con el día repartido en fases (varios días baratos por fotograma).
- ✅ `runner51` / `runner58` — rutas de islas: con los enlaces marítimos nuevos (917 → 4.725) las islas pegadas a un continente se cruzan por mar y no dan la vuelta por la costa; benchmark de A* y de la caché de rutas.
- ✅ `runner52` — rutas nuevas con capturas: varias columnas de Francia hacia destinos que comparten camino (un color por columna, líneas finas sin contorno, carriles paralelos que se juntan y separan).
- ✅ `runner53` — pop-ups de guerra: declaración contra el jugador (pausa el tiempo, quién/por qué/tiempo hasta el primer contacto) y fin de guerra con tratado de provincias + dinero (evaluación en vivo, firmar, rechazar, seguir en guerra).
- ✅ `runner54` — colores: modo dev (tono propio por país dentro del color del continente, más oscuro cerca del ecuador) y campaña (identidad fija).
- ✅ `runner55` — provincias: un clic enfoca el país, los vecinos salen solo con contorno y sin nombre, la campaña muestra los contornos de todos los países sin clic.
- ✅ `runner56` / `runner57` — rendimiento: 8 meses de campaña con 50 IA a las velocidades 3 y 6 (FPS y ms por parte) y perfil por componente de un día.
- ✅ `runner59` — ayudantes del refresco limitado del panel.
- ✅ `runner60` — día repartido en pasos con el reloj en marcha (fotogramas reales): las IA deciden una vez por día de reloj, el desarrollo mensual corre, un salto de Debug vacía el día pendiente.
- ✅ Auditoría estática (`herramientas/auditar_codigo.py`; resultado en INFORME_0.1.8.2a.md): 20 archivos GDScript, 17.156 líneas, 835 funciones, 1.025 variables/constantes; 0 funciones y 0 variables duplicadas; `datos/variables.json` y `datos/ids.json` idénticos a 0.1.8.2 (el modelo de datos no cambió).
- ⬜ NO probado: jugar a mano; los FPS en tu PC; cómo se ven los colores de identidad y las rutas en tu pantalla; si la IA es demasiado guerrera; el tiempo real que tarda un día en tu PC con muchas guerras (el día repartido en fases mantiene los FPS pero el tiempo puede avanzar más lento que el nominal).

### IA, campaña, ranking, ver al enemigo, WASD y reclutar cantidad (0.1.8.2)
- ✅ `runner40` — reclutar: campo numérico con puntos de miles, máximo = dinero de la caja, 1.500.000 soldados, rechazo sin dinero.
- ✅ `runner41` — tropas enemigas: se ven las de un país en guerra dentro del campo de visión (provincia de destino, vecinas, columnas que van hacia allí) y no las de un país en paz.
- ✅ `runner44` — campaña con 50 IA durante 3 años: 51 países y 1.716 provincias; sin IA no se puede atacar; ~250 guerras y ~230 paces; batallas; sin NaN; ms por día.
- ✅ `runner45` / `runner47` — perfiles de rendimiento (IA por sección; guerra y economía base).
- ✅ `runner46` — `Ejercito.soldados_por_pais()` rápido == suma lenta por pelotón, en 3 momentos de una campaña con 50 IA (0 diferencias).
- ✅ `runner48` — menú: JUGAR → MODO DEV / CAMPAÑA (botones gigantes); pantalla de campaña (51 países + «observar»; desde 0.1.8.3 sin selector de IA); COMENZAR arranca la campaña con IA en todos los países menos el tuyo (incluye Reino Unido por el estrecho);
  fuera de Europa se pinta vacío y no se puede elegir; ciudades de fuera ocultas; cámara y zoom limitados (incluye Chukotka); Ranking se abre/cierra; las IA deciden; menú con partida en curso = CONTINUAR / NUEVA PARTIDA.
- ✅ `runner49` — arranque directo tras «Nueva partida» (el inicio pendiente se consume, campaña con Alemania) y aviso «X no tiene IA: no se puede conquistar» al elegir destino (con IA sigue avisando «¡GUERRA con …!»).
- ✅ `runner50` — rendimiento del caso típico: Francia + 8 IA, 2 años: día medio 6,8 ms (IA 2,6 ms).
- ✅ Regresión con pantalla virtual (Xvfb + GL por software): `runner3 5 6 7 8 9 10 15 16 17 21 23 24 25 26 27 28 30` (los que sacan capturas necesitan pantalla; 0 fallos. `runner11` sigue retirado). `runner6`, `runner7` y `runner30` con VERSION 0.1.8.2.
- ⬜ NO probado: jugar a mano; cómo se ve el vacío oscuro y el menú de dos capas en tu pantalla; si las IA son demasiado agresivas o pasivas; el tiempo de «Nueva partida» (recarga) en tu PC; informe Debug > Rend. en tu PC.

### Economía de todos, conquista, retirada y paz (0.1.8.1)
- ✅ `runner30` — lógica y mapa (57 comprobaciones): todos los países con provincias tienen tesorería (249); un día suma ingreso − mantenimiento en 6 países distintos (no solo el jugador); Francia paga el reclutamiento y sin caja no recluta; en rojo desertan ~0,4 % al día, la cuenta de desertores coincide con los soldados perdidos, NO cuentan como bajas, el aviso «en rojo» sale una sola vez y «salió del rojo» al volver; el cierre mensual guarda la tesorería; anexar Luxemburgo→Bélgica pasa su caja; 30.000 colombianos contra una guarnición venezolana → guerra, batalla, resultado «retirada», los venezolanos sobreviven y salen, Colombia ocupa a los 3 días, el dueño sigue siendo Venezuela, no rinde ingresos, la producción de Venezuela baja, el mapa pinta el color mezclado (ID virtual) y los dueños reales no cambian; puntaje de guerra simétrico; Venezuela perdiendo pide paz blanca → rechazada, rendición → aceptada, Colombia exige ocupado + indemnización → aceptada; una paz rechazada no cambia nada; la paz firmada mueve las provincias, limpia «ocupante», cobra la indemnización, resetea guerras activas, deja suceso y el mapa se repinta sin mezcla; paz blanca devuelve lo ocupado y las tropas ajenas salen marchando a casa; liberación por tropas del dueño; sin guerra no se ocupa.
- ✅ `runner31` — RENDIMIENTO 1 (simulación): ms por día en paz, con ~40 guerras simultáneas y en el segundo año; desglose de un día; estabilidad tras 2 años (sin NaN, sin deuda infinita, memoria, tope de sucesos, ningún día > 400 ms).
- ✅ `runner32` — RENDIMIENTO 2 (pantalla): datos de Diplomacia, refresco del panel por pestaña, repintado del mapa (sin cambios / ocupación / dueño), fotogramas con el HUD abierto (quieto y a velocidad máxima con guerras).
- ✅ `runner33` / `runner34` / `runner35` / `runner36` — herramientas de medición (desglose del cambio de mes y de un día de guerra; balance inicial de los ejércitos; coste de los datos de Economía de EE. UU.). Imprimen números, no comprueban.
- ✅ `runner25` — portado a los tres botones de paz de Diplomacia. `runner6` / `runner7` — versión 0.1.8.1.

### Líneas de borde (cuarta tanda de 9F; franjas transparentes en 0.1.8)
- ✅ `runner26` — la malla de frontera trae distancia por vértice (franjas), grosores en pantalla (costa 2,8 px lejos y cerca, línea entre continentes 1,8 px, frontera 2,6 px) y la frontera es visible al acercar; capturas a zoom 0,6 / 1,6 / 6 / 8 revisadas a ojo (la parte «se ve bonito» la juzgas tú).

### Fusión de provincias y fronteras (0.1.7.9.9F)
- ✅ `runner15` — Francia → España (101 provincias): color EXACTO del dueño, Francia sin provincias y «anexado a España», ejército transferido, total de soldados igual, fronteras recalculadas (17.019 → 16.954), nombres, líneas de provincia con la costura, París devuelto → Francia resucita, Colombia y EE. UU. → España y vuelta al mapa original (47 comprobaciones).
- ✅ Reconstrucción del mapa desde cero (`construir_mapa.py`): los 47 archivos de datos salen idénticos a los del proyecto.

### Tropas visibles solo las tuyas y órdenes sin menú (ajustes de 9F)
- ✅ `runner16` — solo se dibujan las tropas del país que controlas (zoom mundo, 3 y 6), un regimiento ajeno elegido no se dibuja, columnas ajenas no se dibujan, observador = ve todas (desde 0.1.8.3; antes ninguna), tras anexar un país sus tropas pasan a verse (17 comprobaciones).
- ✅ `runner17` — clic derecho sin tropas elegidas no hace nada; clic izquierdo en un cuadrito las elige; clic derecho en otra provincia las manda; clic derecho en el mar / en la misma provincia no ordena; clic derecho arrastrando mueve la cámara y NO ordena; con un temblor de 2 px sigue siendo clic; la cantidad de la ventana se respeta y tras la orden vuelve a «todas»; arrastrar el cuadrito con el izquierdo: fantasma + ruta + días, Esc cancela, soltar en el mar no ordena, soltar en una provincia manda todas; tropas ajenas no se mueven (29 comprobaciones).
- ✅ `runner21` — la línea dorada (vista previa y columna elegida) se dibuja y registra su ruta para las flechas; sin selección no queda nada animándose (capturas revisadas a ojo).

### Rendimiento del zoom (ajustes de 9F)
- ✅ `runner20` — barrido de zoom con la rueda (acercar y alejar): imprime ms por fotograma, `_process`, `_actualizar_zoom`, tropas y ciudades por paso (comparativo antes/después en las notas técnicas).
- ✅ `runner18` / `runner19` — medición por zoom y ablación por capa (cuánto cuesta cada capa del mapa).
- ✅ `runner22` — costa simplificada vs. completa a varios zoom (capturas lado a lado revisadas a ojo; 0,3–1,1 % de píxeles distintos; las islas pequeñas se conservan).
- ✅ `runner23` — Debug > «Rend.»: muestra GPU y FPS en vivo; apagar y encender cada capa (costa, relleno, mar, lagos, fronteras, nombres, ciudades, tropas) sin errores y sin que el zoom las reencienda; la «Prueba de zoom» completa arma el informe, devuelve la cámara y lo copia al portapapeles (0 fallos).
- ✅ Reconstrucción del mapa desde cero con los niveles de costa: los demás archivos de datos salen idénticos (`cmp`).

### Regresión
- ✅ Auditoría estática de la 0.1.8.3 (`herramientas/auditar_codigo.py`): 20 archivos, 860 funciones, 0 duplicadas; `datos/variables.json` sin cambios.
- ✅ Regresión final de la 0.1.8.3: 38 pruebas (`runner3 5 6 7 8 9 10 15 16 17 21 23 24 25 26 27 28 30 31 32 40 41 42 43 44 46 48 49 52 53 54 55 60 61 66 67 68 69`), 677 comprobaciones «OK», 0 fallos y 0 «SCRIPT ERROR» / «Parse Error». `runner3`, `5`, `6`, `7` corren sobre el proyecto de datos semilla; el resto, sobre los datos históricos reales. `runner11` sigue retirado (probaba la ventana flotante de tropas anterior).
- ✅ Regresión final de la 0.1.8.2a: 33 pruebas (`runner3 5 6 7 8 9 10 15 16 17 21 23 24 25 26 27 28 30 31 32 40 41 42 43 44 46 48 49 52 53 54 55 60`), 613 comprobaciones «OK», 0 fallos y 0 «SCRIPT ERROR» / «Parse Error».
- ✅ Tras cada cambio se vuelven a correr 3, 5, 6, 7, 8, 9, 10, 15, 16, 17, 21, 23, 24, 25, 26, 27, 28 y 30 (y desde 0.1.8.2a también 31, 32, 40–44, 46, 48, 49, 52–55 y 60). Criterio: 0 fallos y 0 «SCRIPT ERROR» / «Parse Error».

## B. Lo que tienes que probar tú en tu PC (⬜)
Marca cada casilla cuando lo hayas probado y dime qué pasó.

### 0.1.8.36 (para probar en tu PC)
- ⬜ F1 > pestaña «Descub.»: ¿se abre rápido? Arriba debe decir el año del reloj y «la historia conoce 1.699 de 1.730» en 2026. ¿La lista muestra los descubrimientos alrededor de la fecha, y los que faltan salen en gris?
- ⬜ Escribe «pólvora», «imprenta» o «acueducto» en el buscador y elige uno: ¿la ficha dice un año que te parezca razonable, su ruta y sus prerrequisitos con ✓ / ✗?
- ⬜ Salta de fecha en el Debug (año 1, 1500, 1800, 1945, de vuelta a 2026): ¿el resumen cambia (353 · 526 · 717 · 1.261 · 1.699)? Dime cualquier descubrimiento cuyo año te parezca claramente mal (lo corrijo en `anios.tsv`).
- ⬜ CONCEDER A MI PAÍS un descubrimiento que la historia aún no conoce, QUITAR A MI PAÍS uno que sí, y luego MI PAÍS = HISTORIA: ¿vuelve al número de la historia? Con el reloj corriendo unos años, ¿el resto de países sigue sumando los que llegan?
- ⬜ Dime cuánto tarda en abrir el mapa y cuántos FPS marca la esquina (debería ser igual que en la 0.1.8.35: el catálogo solo añade ~0,1 s y 1 MB).

### 0.1.8.35 (para probar en tu PC)
- ⬜ Opciones > PANTALLA > «Pantalla completa»: ahora la lista de resoluciones es la RESOLUCIÓN INTERNA (primera: «Nativa»). Elige una menor, APLICAR: ¿se ve el juego a esa resolución estirado a toda la pantalla? ¿Suben los FPS? Vuelve a «Nativa».
- ⬜ Cierra y abre el juego: ¿conserva la resolución interna que dejaste? En modo ventana, ¿todo como siempre?
- ⬜ MODO DEV (2026 y año 1 d. C.): ¿el mapa se ve igual que en la 0.1.8.34 (colores, fronteras, costas, lagos, nombres)? Mira que no haya rayitas o huecos entre provincias del mismo país al acercar mucho.
- ⬜ F1 > Provincia > «Forma del territorio»: elige una provincia con vecinas, pulsa «Cederle ½» y mira el mapa; luego «Deshacer». Prueba «Absorberla toda» y «Restablecer forma». ¿Se ve bien? ¿Tarda algo en responder?
- ⬜ Tras cambiar una forma, haz clic en la zona cambiada (¿selecciona la provincia nueva?) y deja correr el tiempo unos días (¿sigue todo bien?).
- ⬜ Dime cuántos FPS marca la esquina en 2026 y en el año 1, y cuánto tarda en abrir el mapa (por software la 0.1.8.34 tardaba ~2,8 s y la 0.1.8.35 ~3,0 s; con celdas hay más geometría).

### 0.1.8.34 (para probar en tu PC)
- ⬜ JUGAR > MODO DEV > AÑO 1 d. C. (el juego se recarga un momento). Haz clic en una nación (acercando un poco el zoom): ¿sale el HUD con las 5 pestañas (General, Diplomacia, Militar, Política, Economía)? ¿Es lo mismo que en 2026?
- ⬜ ¿Corre el reloj (arriba, empieza en 1,01,01)? Sube la velocidad: ¿se mueve el dinero, hay ejércitos en el mapa y puedes reclutar, mover tropas y declarar guerras como en 2026?
- ⬜ Mira el mapa: Gran Bretaña (caledonios, brigantes…), Germania, Dacia, el Sáhara, África, la India, Mesoamérica, los Andes, Australia. ¿Cada pueblo está en su sitio? ¿Las provincias se ven bien, sin figuras raras ni bordes en cuadrado? Dime zona y nombre de lo que esté mal.
- ⬜ Lo gris oscuro son «Tierras sin reclamar»: ¿tiene sentido lo que queda sin reclamar? Prueba a mandar tropas por ahí (pasan sin guerra) e intenta atacarlas (no se puede).
- ⬜ Esc > MENÚ PRINCIPAL > JUGAR > MODO DEV > 2026: ¿todo sigue exactamente igual que antes? Esc > OPCIONES > INFORMACIÓN en el año 1: ¿salen los créditos de Cliopatria?
- ⬜ ¿El año 1 se mueve bien en tu PC (zoom y arrastre)? Dime los FPS de la esquina en 2026 y en el año 1.

### 0.1.8.33 (para probar en tu PC)
- ⬜ Esc durante el juego > OPCIONES > PANTALLA: cambia la resolución y APLICAR. Debajo de los botones debe aparecer «Aplicado: ventana …» o un AVISO. Si dice AVISO y ejecutas con F5 desde Godot 4.4+, desactiva «Embed Game on Next Start» (pestaña Juego) y prueba otra vez; dime qué ves.

### 0.1.8.32 (para probar en tu PC)
- ⬜ Campaña con España (o tu país), declara una guerra y sube la velocidad a x4, x5 y x6: ¿se ve fluido? ¿Hay tirones al conquistar una provincia o al cambiar de año? Dime la velocidad y qué hacías.
- ⬜ Opciones > PANTALLA: prueba la **Calidad** (Alta / Media / Baja) y dime cuántos FPS marca la esquina en cada una a x1 y a x6. Prueba también «Mar: color liso», «Costas: detalle bajo» y «Prioridad: Fluidez» por separado.
- ⬜ Con Calidad Baja: ¿falta algo que quieras ver (líneas de provincia, lagos)? Se pueden volver a encender uno por uno.
- ⬜ Cierra el juego y vuélvelo a abrir: ¿arranca con la calidad y la resolución que dejaste?
- ⬜ Tras una conquista, los nombres y las fronteras pueden tardar un instante (unos fotogramas) en actualizarse. ¿Se nota o molesta?

### 0.1.8.31 (para probar en tu PC)
- ⬜ Menú principal > OPCIONES: salen dos botones, PANTALLA e INFORMACIÓN (más VOLVER). INFORMACIÓN muestra lo de siempre y la versión.
- ⬜ PANTALLA: cambia la resolución (p. ej. 1280×720 → 1600×900) y pulsa APLICAR: la ventana cambia y sale «¿Mantener estos cambios?». Prueba MANTENER, y luego otro cambio y REVERTIR (y también dejar que pasen los 10 s).
- ⬜ PANTALLA: pantalla completa y vuelta a ventana (APLICAR, MANTENER). ¿Se ve bien el mapa y el HUD a otras resoluciones?
- ⬜ PANTALLA: VSync desactivado + «sin límite» de FPS, y luego un límite de 60: ¿cambia el contador de FPS de la esquina? Apaga el suavizado: ¿suben los FPS en tu PC?
- ⬜ Cierra el juego y vuélvelo a abrir: ¿arranca con la resolución y los ajustes que dejaste? (Se guardan en `%APPDATA%\GranEstrategia\ajustes.cfg`.)
- ⬜ Opcional: abre `test/runner74.tscn` en Godot y pulsa F6; al final debe decir «FALLOS: 0» (la ventana saltará de tamaño mientras corre).

### 0.1.8.25 (para probar en tu PC)
- ⬜ El juego se comporta exactamente igual que la 0.1.8.3 (esta versión solo limpió el código): campaña, declarar la guerra, tiempo x1–x6, Debug, HUD. Si notas CUALQUIER diferencia, dímela: no debería haberla.
- ⬜ Opcional: abre `test/runner71.tscn`, `72` y `73` en Godot y pulsa F6; al final debe decir «FALLOS: 0».

### 0.1.8.3 (para probar en tu PC)
- ⬜ Campaña con tu país → eliges un vecino → pestaña Diplomacia → «Declarar la guerra a …»: la primera pulsación pide confirmar y la segunda declara. Antes de declarar, mandar tropas a su territorio se bloquea con un aviso que dice cómo declararla.
- ⬜ Haces la paz con un país y no te la vuelve a declarar en años (la pestaña muestra cuánto falta de tregua). ¿Se siente razonable?
- ⬜ Los ejércitos de la IA ya no son «infinitos»: tras 2–3 años de juego los vecinos tienen ejércitos comparables a los iniciales (no 5–10 veces más). ¿Se puede pelear contra ellos? Dime cuáles te parecen muy fuertes o muy débiles.
- ⬜ ¿Hay guerras suficientes entre IA? (ahora son pocas a propósito: máximo ~10 % de los países en guerra a la vez). Si el mundo te parece muy tranquilo, dímelo y subo la frecuencia.
- ⬜ Debug (F1) > Jugador: sueltas tu país (o eliges otro) y el que sueltas sigue jugando solo, con guerras y reclutamiento (en la campaña).
- ⬜ Campaña → «— Ninguno: solo observar —»: ves TODAS las columnas de tropas de todos los países y puedes dejar pasar los años (x6).
- ⬜ Velocidad x6: el tiempo pasa «rapidísimo» (~1 año por segundo si tu PC aguanta). Dime cuántos días por segundo ves en x4, x5 y x6 y los FPS: ______
- ⬜ Debug: los botones « » de la barra de título angostan y ensanchan la ventana; la esquina ◢ se arrastra; el mapa se ve mejor con la ventana angosta.
- ⬜ Debug en modo dev: activa IA en TODOS los países (pestaña IA > Todas) y deja correr a x3–x6: ¿se traba o va fluido? ¿Qué FPS?: ______
- ⬜ HUD: el panel de la izquierda ocupa menos pantalla; el botón ▾ lo encoge a solo el nombre; en las pestañas solo la abierta lleva texto. ¿Sigue siendo invasivo? ¿Qué más quitarías?
- ⬜ El botón «Ranking» ya no tapa el panel.

### 0.1.8.2a (para probar en tu PC)
- ⬜ Empiezas una partida: tu país tiene UN solo regimiento en la capital (no cajas en muchas provincias).
- ⬜ Eliges varios regimientos en provincias distintas con Ctrl + clic: no se mueven solos; un roce con el ratón no manda al grupo a ningún lado; soltar un cuadro en su propia provincia no hace nada.
- ⬜ Un clic derecho largo (más de ~0,35 s) mueve la cámara y no da una orden de marcha.
- ⬜ Mandar tropas a una isla cercana: la ruta cruza el mar por el punto más corto, sin dar la vuelta por la costa.
- ⬜ Rutas: cada columna en marcha tiene su propio color; la línea es fina, de un solo color y SIN contorno negro; las flechas son del mismo color, van incrustadas en la línea y avanzan a la misma velocidad de siempre. ¿Grosor (3 px) y colores a tu gusto?
- ⬜ Varias columnas al mismo destino: sus líneas van en carriles paralelos que se juntan y separan como en un mapa de metro, sin amontonarse.
- ⬜ Mandar 10 o más regimientos al mismo punto: los FPS ya no caen (compara con 0.1.8.2).
- ⬜ Dejar que una IA te declare la guerra: sale un pop-up que PAUSA el tiempo, dice quién, por qué y cuántos días de juego (y segundos reales a tu velocidad) faltan para el primer contacto. Ninguna IA declara guerras en los primeros 120 días ni ataca al jugador en los primeros 240 (para verlo hay que dejar correr ~8 meses de juego, por ejemplo a velocidad 5–6).
- ⬜ Cuando una IA quiere la paz contigo sale un pop-up con el motivo; solo hay dos monedas, provincias y dinero, combinables; la barra dice si el rival acepta; «Cubrir lo que falta con dinero» rellena el campo; «FIRMAR LA PAZ» cambia las provincias y el dinero de verdad.
- ⬜ Velocidades altas (4–6): el juego sigue fluido en FPS (el tiempo puede ir más lento que lo nominal si hay muchas guerras; dime cuánto).
- ⬜ Campaña: cada país tiene siempre el mismo color (compara dos partidas); ningún par de vecinos con colores casi iguales.
- ⬜ Modo dev: los países de un continente son del mismo color con distinto tono; los cercanos al ecuador, más oscuros; sin degradado dentro del país.
- ⬜ Campaña: se ven los contornos de provincia de todos los países sin hacer clic. Dev: un solo clic en un país muestra sus provincias con nombre y el contorno (sin nombre) de las de los vecinos.
- ⬜ Un clic en un país que ya está a la vista NO mueve la cámara.

### Arranque y rendimiento
- ⬜ El juego abre sin errores en el panel «Salida» de Godot.
- ⬜ FPS en la esquina con el mundo entero (zoom mínimo): ______
- ⬜ FPS con zoom a un país (zoom ~3): ______
- ⬜ FPS con zoom máximo sobre una ciudad: ______
- ⬜ Debug (F1) > «Rend.»: aparece el nombre de tu tarjeta gráfica y los FPS cambian en vivo.
- ⬜ Debug > «Rend.» > «Prueba de zoom»: corre sola ~25 s, no se traba, deja la cámara donde estaba y copia el informe (pégalo con Ctrl+V): FPS medios ______ · FPS del peor paso ______
- ⬜ Apagar capas en «Rend.» (relleno, mar, costa, nombres, ciudades…): ¿cuál sube más los FPS? ______
- ⬜ Alejar el mapa por completo: la costa se ve igual que de cerca (sin saltos raros al pasar de un zoom a otro; las islitas siguen ahí).
- ⬜ Al girar la rueda del ratón se siente fluido (sin tirones) al acercar y al alejar.
- ⬜ Con velocidad 6 (teclas 1–6) el juego no se traba.

### Tropas
- ⬜ Eliges tu país en Debug (F1) > Jugador: ves SOLO tus cuadritos de tropas, ninguno de otros países, con cualquier zoom.
- ⬜ Sin país elegido no se ve ninguna tropa.
- ⬜ Clic izquierdo sobre un cuadro de tropas: queda elegido (marco dorado) y se abre tu país en Militar > Regimientos.
- ⬜ Con el cuadrito elegido, clic derecho en otra provincia: las tropas salen hacia allá (sin tocar el menú).
- ⬜ Clic derecho en el mar: avisa «Eso es mar» y no pasa nada.
- ⬜ Mantener el clic derecho y arrastrar sigue moviendo la cámara (no manda tropas).
- ⬜ Arrastrar el cuadrito con el clic izquierdo: el cuadrito sigue al cursor, aparece la ruta y los días; al soltar sobre una provincia salen las tropas; Esc cancela.
- ⬜ Si en la ventana pones una cantidad (p. ej. 1.000) el clic derecho manda esa cantidad; después vuelve a «todas».
- ⬜ La columna avanza con el tiempo y al llegar COMPARTE provincia con las que ya estaban pero NO se funde: se ven apiladas (cada una con su número).
- ⬜ Militar > Regimientos > Unir: junta a propósito dos regimientos tuyos de la misma provincia; Dividir parte uno en dos; Disolver (sin confirmación).
- ⬜ Militar > Reclutar: muestra el precio; al reclutar baja tu dinero; la barra de arriba muestra el balance diario (rojo si pierdes).
- ⬜ Con un ejército enorme para tu economía el balance se vuelve negativo, tu caja baja y al llegar a negativo tus soldados desertan (0,4 % al día, con suceso «en rojo»). Prueba con Corea del Norte como jugador.
- ⬜ Mandar tropas a una provincia de otro país: la vista previa avisa «¡GUERRA con …!»; al confirmar queda la guerra en la pestaña Diplomacia.
- ⬜ Cuando coinciden tropas enemigas: cuadro con borde rojo y espadas; la pestaña Batallas muestra bajas día por día y el ganador.
- ⬜ Zoom lejos: el contorno de los continentes se ve negro y algo más grueso que antes; la línea rayada entre continentes (Panamá, Sinaí, Nueva Guinea) es un poco más fina que el contorno.
- ⬜ Zoom cerca: la costa se ve igual de gruesa que lejos y las fronteras entre países son una línea negra con franjas TRANSPARENTES (0.1.8).
- ⬜ Los números dicen 25000 (completos, no 25k) y ningún cuadro tapa el nombre de una provincia (haz zoom en un país con muchas tropas).
- ⬜ Intentar mover tropas de otro país: solo se pueden mirar (no se mueven).

### HUD de país y diseño (0.1.8)
- ⬜ El azul del HUD es más oscuro, apagado y algo metálico que antes (¿a tu gusto? ¿más claro/oscuro, más/menos brillo?).
- ⬜ La fuente (Inter) se lee bien y cansa menos, en el HUD, los menús y las ventanas de Debug / «Mi país».
- ⬜ Un clic en tu país (barra de arriba) abre la pestaña General; un clic en tu dinero abre Economía.
- ⬜ Las pestañas General · Diplomacia · Militar · Política · Economía están debajo del nombre del país y debajo sale la sección con toda la información de la pestaña.
- ⬜ Diplomacia: lista guerras abiertas (con «Firmar la paz»), guerras pasadas, tropas extranjeras/propias afuera y vecinos por tierra.
- ⬜ Militar > Regimientos: la lista, la ficha y las órdenes caben en el HUD sin salirse de la pantalla (prueba con otra resolución de ventana).
- ⬜ Ya no sale la ventana flotante de ejército: un clic en un cuadro de tropas abre tu país en Militar > Regimientos.
- ⬜ Ctrl + clic en varios cuadros del mapa los elige a la vez (marco dorado); Ctrl + clic otra vez lo quita; Mover / Detener / Unir / Disolver valen para todos.
- ⬜ Ctrl + clic en filas de la lista de regimientos hace lo mismo.
- ⬜ Disolver no pide confirmación (ni uno ni varios).
- ⬜ Ningún nombre, ciudad, línea dorada ni ventana del mapa se dibuja por encima de un cuadro de tropas.
- ⬜ Fronteras entre países de distinto color: línea NEGRA con franjas TRANSPARENTES (se ve el color del país entre las rayas negras); ¿tamaño y proporción a tu gusto?
- ⬜ Menú principal y menú de pausa con el estilo nuevo.

### Economía de todos, ocupación y paz (0.1.8.1)
- ⬜ Economía de cualquier país (no solo el tuyo): se ve Tesorería, Gasto del ejército por día y Balance por día; en rojo dice «EN ROJO».
- ⬜ Deja correr el tiempo unos meses: las tesorerías de otros países suben o bajan (haz clic en varios países y mira Economía).
- ⬜ Manda un ejército grande a una provincia enemiga con poca defensa: tras la batalla el perdedor se RETIRA (sus cuadros se van marchando) y no muere entero.
- ⬜ Quédate solo 3 días en la provincia: aparece «OCUPADA por …» en su panel y en el mapa se ve mezclando los colores del dueño y el ocupante. ¿La mezcla (70 % ocupante) es legible?
- ⬜ La provincia ocupada ya no suma ingresos a su dueño (mira Economía del rival antes y después).
- ⬜ Diplomacia > guerra: «Proponer la paz a …» con tres botones; el que el rival rechazaría dice «(rechazaría)» y su aviso explica por qué; firmar «Cada uno se queda con lo ocupado» cambia de dueño las provincias de verdad.
- ⬜ «Paz blanca» devuelve lo ocupado y tus tropas que quedaban en su territorio vuelven marchando a casa.
- ⬜ Diplomacia > «Sucesos recientes» lista ocupaciones, liberaciones, paces y quiebras.
- ⬜ ¿Los umbrales se sienten bien? (retirada con menos de 35 % de la fuerza, 3 días para ocupar, 0,4 % diario de deserción, indemnización hasta 90 días de ingresos). Dime cuáles cambiar.
- ⬜ Velocidad 6 con varias guerras abiertas: ¿se mantiene fluido?

### Línea dorada
- ⬜ La línea dorada se ve definida (borde oscuro, cuerpo dorado, hilo de luz) con cualquier zoom.
- ⬜ Las flechas se deslizan por la línea hacia el destino y el anillo del destino late.
- ⬜ Por mar la línea va rayada.
- ⬜ Sin ruta (sin selección) la línea y las flechas desaparecen.

### Anexión y fronteras
- ⬜ Debug (F1) > Anexar: Francia → España. Las provincias francesas quedan con el MISMO color que España y no hay línea de país entre ambas.
- ⬜ Francia aparece como «anexado a España» y ya no se puede enfocar.
- ⬜ Doble clic en España: se ven las líneas de provincia, incluida la antigua frontera.
- ⬜ Debug > Provincia > TRANSFERIR: devolver una provincia a Francia → Francia vuelve a existir y el mapa se corrige.
- ⬜ El nombre del país aparece bien sobre el territorio unido.

## C. Límites conocidos (no son fallos nuevos)
- Las franjas de color por continente son geográficas y no siguen al dueño.
- El nombre dinámico de un país fusionado es aproximado.
- La ocupación no anexa: solo la paz con «quedarse con lo ocupado» cambia de dueño; no hay «guerra total» ni capitulación automática, y los países NPC aún no deciden nada (la IA es lo siguiente).
- Reclutar cuesta dinero pero no población; los precios y la fórmula de batalla son provisionales; no hay barcos (islas lejanas sin ruta); las columnas no se guardan (no hay guardar partida).
- El panel de información de una provincia aún lista los pelotones extranjeros que haya en ella.
- Rendimiento: medido en un servidor sin GPU, NO en tu PC (ver las notas técnicas). Pendiente: niveles de detalle para el relleno de países (lo que más pesa al alejar).

## D. Cómo se corren las pruebas (para quien las repita)
- Godot 4.3 en Linux con `xvfb-run` y render por software: `godot --path <proyecto> --rendering-driver opengl3 res://test/runnerN.tscn`.
- Cada runner imprime líneas `[T] OK …` / `[T] FALLO …` y termina con `FALLOS: 0` (o `fallos=0`). Cualquier «SCRIPT ERROR» o «Parse Error» cuenta como fallo.
- Los runners viven en una carpeta `test/` que NO va dentro del ZIP del juego.

### Corrección 0.1.8.37a — tirones al hacer zoom
- ✅ Causa localizada con el banco `runner90` (zoom paso a paso): con un país elegido, el borde y el resplandor de la selección (`Line2D`) se rehacían en cada paso de zoom. Cambiados por una malla de cinta con shader (`SHADER_SELECCION`); el zoom solo cambia dos números por material.
- ✅ **Revisión de rendimiento** (`runner90`, EE. UU. enfocado y elegido, 30 pasos de rueda hacia dentro y 30 hacia fuera): scripts solos 12,9 → **6,9 ms por fotograma** (máx. 24,2 → 7,1; la 0.1.8.36: 6,9). Con dibujo por software, dos pasadas: entregada 160 / 161 ms, corregida 127–136 ms, 0.1.8.36 107–113 ms. Sin selección: igual en las tres. Primer clic en EE. UU. (sin caché) 138 ms frente a 57 ms; con caché 50 frente a 39 ms. `runner89` no cambia (no usa selección).
- ✅ **Revisión de variables**: 0 funciones y 0 variables repetidas; `datos/variables.json` sin cambios; sin nada nuevo sin uso.
- ✅ Revisión visual (xvfb): país elegido a zoom 3 y 14 y una provincia a zoom 10: borde negro nítido con resplandor amarillo, sin picos en las esquinas.
- ✅ `runner79` actualizado (120 comprobaciones: cintas, caché, grosor por zoom, respiración); `runner74` pide la versión 0.1.8.37a.
- ✅ **Regresión final de la 0.1.8.37a**: runner71 181, runner72 121, runner73 84, runner75 145, runner76 97, runner77 88, runner78 74, runner79 120 (headless) y runner74 220 (con ventana, xvfb): **1.130 comprobaciones, 0 fallos y 0 errores de script**.
- ☐ Pendiente de ti: que en tu PC el zoom con un país elegido vaya fluido.
