# Notas técnicas 0.1.8.44 — Registro de fallos y Descubrimientos como un sistema solar (espacio negro, planetas con luz, estelas, pétalos por subsección)

Versión visual, la primera de las seis fases que acordamos (Cimientos … Extras; cada una con su ZIP). Rama `v0.1.8-development`.
Parte de tus observaciones del 2026-11-14 sobre las capturas de la pantalla de Descubrimientos, y de lo que contaste de la caída de la 0.1.8.43 en el PC de tu amigo.

## Qué trae
1. **Registro de fallos a archivo** (`scripts/registro_fallos.gd` + el registro de Godot encendido en `project.godot`) y botón en Opciones > Información para abrir la carpeta.
2. **Revisión de riesgos de caída de la 0.1.8.43** (sección 1): no puedo decir cuál fue la causa sin el registro de tu amigo; dejo dicho qué sospecho y qué cambié.
3. **Fondo espacial**: negro, con el color de la rama solo en la nebulosa; estrellas más brillantes en tres capas con parpadeo y paralaje; estrella fugaz; brasas en Militar; **sin planetas de fondo**.
4. **Los únicos planetas son los descubrimientos**: colores realistas y neutros (rocosos, desérticos, océanos, helados, gigantes de gas), **alumbrados por el sol de la pantalla (la raíz de la sección)**: cada uno tiene su cara iluminada, su terminación día / noche y gira sobre su eje (sin anillos). **El tamaño sale de los enlaces** (lo que pide + lo que abre). Lo verde es la LÍNEA, no el planeta.
5. **Líneas finas con estela** (cometas que recorren cada línea conocida); las que no se conocen quedan quietas y tenues.
6. **Un emblema por subsección** que cambia con el avance (anillo que se llena, pétalos que se encienden uno a uno, estrella dorada al 100 %).
7. **Más espacio y más orden**: nodos y niveles mucho más separados, el árbol ya no se condensa; cada cuña reparte sus planetas a lo ancho y **termina en su último anillo con contenido** (pétalos de distinto largo en vez de un hueco al fondo).
8. **El mapa deja de dibujarse mientras la pantalla de Descubrimientos está abierta** (la pantalla es opaca: era gasto puro de GPU).

## 1. Registro de fallos y riesgos de caída de la 0.1.8.43
**Lo que sé:** la 0.1.8.43 se cerró sola en el PC de un amigo tuyo y no tengo su registro; **no puedo afirmar la causa**. En el servidor (sin GPU, Godot 4.3 por software) no cae en ninguna prueba.
**Lo que sospecho (no verificado en hardware real), de mayor a menor:**
- **Memoria de vídeo en tarjetas integradas**: la imagen guardada del relleno es un `SubViewport` de 4096×2048 (≈ 32 MB), el Relieve en calidad Alta carga una imagen de 8192×4096 (con mipmaps ≈ 130–180 MB de vídeo según el formato) y la pantalla de Descubrimientos dibujaba su propio fondo con el mapa todavía dibujándose debajo. En una GPU compartida con poca memoria eso suma.
- **Compilación de shaders en un controlador gráfico distinto** (ANGLE / Direct3D en Windows con gráficos Intel): un shader que compila bien aquí puede fallar o colgar allá. Los shaders nuevos de esta versión (planeta, estela, emblema, fondo) son más pesados que los de la 0.1.8.43 en el servidor; **no los pude probar en una GPU real**.
- **Hilos / carga del mundo entero al primer clic en Relieve** (pico de ~114 ms ya conocido; no explica una caída, sí un tirón).
**Lo que cambié:**
- El mapa **no se dibuja** mientras la pantalla de Descubrimientos está abierta (`MapaPrincipal._mapa_oculto_desc`): se restaura al cerrarla (Esc / botón). Menos GPU y menos memoria de vídeo en uso a la vez.
- **Calidad Baja** (Opciones > Pantalla): el fondo y el árbol quedan **quietos** (sin estelas, sin giro, una sola capa de estrellas): es la salida segura para un PC flojo.
- **Registro de fallos** (abajo): la próxima vez que se caiga habrá rastro.
**Si vuelve a caerse:** abre Opciones > Información > «Abrir carpeta de registros» y mándame `godot.log` y `cierre_inesperado_*.txt` (o, si no existe, `sesion.txt`): la última línea de estado dice en qué pantalla estaba, la fecha del juego, FPS, memoria y nodos.

### Cómo funciona el registro
- **`godot.log`** (lo escribe el motor; `[debug] file_logging` en `project.godot`, 8 archivos como máximo): todo lo que el juego imprime y cada error de script o del motor, con su traza.
- **`sesion.txt`** (`registro_fallos.gd`): equipo y versión al empezar y **una línea de estado cada 5 s** (cada 30 s pasada la primera hora): pantalla, fecha del juego, FPS, memoria, nodos. Al salir bien escribe «CIERRE LIMPIO».
- **`cierre_inesperado_AAAAMMDD_HHMMSS.txt`**: al arrancar, si el `sesion.txt` anterior NO terminó con «CIERRE LIMPIO» (se cayó el juego o lo mató el sistema) se guarda una copia. Máximo 6 copias; se borran las más viejas.
- Costo: una línea de texto cada 5 s y los avisos puntuales; nada por fotograma. Vive en la raíz (como el grabador F9): sobrevive al menú y a «Nueva partida».
- Carpeta: `user://logs/` (en Windows `%APPDATA%\GranEstrategia\logs\`, porque el proyecto usa carpeta de usuario propia); el botón de Opciones > Información la abre.

## 2. Fondo espacial (`scripts/fondo_descubrimientos.gd` + `shaders/fondo_espacial.gdshader`)
- **Negro primero**: la paleta de cada rama es casi negro (Militar con un soplo rojizo, Científica azulado, Sociedad violeta); **el color de la rama vive en la nebulosa** (`c_acc · neblina · 0,10`) y en el tinte de algunas estrellas.
- **Nebulosa con una textura de ruido** (`FastNoiseLite` simplex, 4 octavas, 256×256 sin costuras, hecha UNA vez al abrir el juego): una lectura de textura por píxel en vez de 16 senos.
- **Tres capas de estrellas** (brillo 1,0 / 1,45 / 2,0; las lejanas finas y muchas, las cercanas pocas y brillantes) con parpadeo y deriva a distinta velocidad (paralaje); estrella fugaz cada ~11 s; brasas que suben solo en Militar; viñeta.
- **Resplandor cálido del sol** (`u_sol`): el árbol avisa dónde quedó la raíz en pantalla (`sol_movido`) cuando te desplazas o haces zoom y el fondo mueve el resplandor. No se redibuja nada: lo anima el shader con `TIME`.
- **Calidad Baja** (`u_anim = 0`): una sola capa de estrellas, quieta, con viñeta.

## 3. Planetas, sol y estelas
- **Una sola malla para todo el árbol** (`LoteUV`, `scripts/lote_uv.gd`): un cuadro por planeta con sus datos en las UV (número de planeta = semilla de aspecto, tipo y giro; estado; dirección del sol en 32 pasos de 11,25°). Una orden de dibujo para todos los planetas y otra para las estelas y los emblemas.
- **`shaders/planeta.gdshader`**: 8 tipos (rocoso con cráteres, desértico con casquetes, océanos y nubes, helado, gigante ocre con bandas, gigante pálido, nubes venusinas, gigante de hielo azul), esfera con luz del sol (terminación día / noche, noche casi negra, aire en el borde iluminado) y giro sobre su eje. **Estados**: *bloqueado* = negro (solo un reflejo gris en el borde de día), *aún lejano* = gris, *conocido* = colores reales, *disponible* = colores reales con halo y filo dorados.
- **El sol** es la raíz del árbol: disco de fuego con granulación y corona que respira (mismo shader, estado 4).
- **Tamaño por enlaces**: `radio = R_MIN + √(enlaces) · R_POR_ENLACE` (30 → 84 px), con enlaces = prerrequisitos + descubrimientos que abre.
- **Estelas** (`shaders/estela.gdshader`): sobre las líneas conocidas (verdes, finas: 1,2 px) corren dos cometas por línea con cabeza brillante y cola larga que se afina. Tope de 700 líneas por dibujo y **solo desde zoom 0,22** (más lejos serían ruido).

## 4. Emblemas por subsección (`shaders/emblema.gdshader`)
Al borde exterior de cada cuña, un emblema procedural que **refleja cuánto se conoce de esa subsección**: un anillo que se llena en el sentido del reloj, pétalos (de 5 a 9 según la semilla) que se encienden uno a uno y, al 100 %, una estrella dorada en el centro; gira lentamente. A 0 % queda apagado. Debajo, el nombre y «x / y conocidos».
(Son emblemas dibujados por código, no imágenes: propios, sin atribución. Si más adelante quieres ilustraciones por subsección, el emblema se puede cambiar por imágenes que se encienden con el mismo avance.)

## 5. Más espacio y más orden (`scripts/arbol_descubrimientos.gd`)
- **Aprovechar el espacio**: `SEP_NODO` 128 → 230, `SEP_NIVEL` 176 → 310, `R_RAIZ` 620, sub-anillos de 190, márgenes de 340–420. Los planetas respiran; el árbol es grande y se recorre con el zoom (4–280 %) y «Ver todo» / «Mi frontera».
- **Reparto parejo dentro de la cuña**: cada planeta se coloca entre el reparto uniforme de su anillo y el ángulo medio de sus prerrequisitos (`PESO_BARICENTRO` 0,25): las cuñas ya no se amontonan a un lado.
- **Pétalos**: lo que notaste («a medida que avanza el tiempo se van más hacia un lado») es que cada subsección crece distinto; antes todas las cuñas llegaban al mismo borde y las que dejaron de crecer quedaban con un hueco largo. Ahora cada cuña **llega solo hasta su último anillo con contenido (+ `LARGO_PUNTA` 150)**: las largas son las subsecciones que siguen creciendo en la historia, las cortas las que se detuvieron. El nombre y el emblema van en la punta de cada pétalo, apartados en la dirección de la cuña para no pisar sus propios planetas.
- Los años de cada anillo siguen a la izquierda; los anillos guía recorren todo el abanico.

## 6. El mapa no se dibuja detrás de Descubrimientos
`MapaPrincipal._abrir_descubrimientos` pone `main.visible = false` (`_mapa_oculto_desc`) y `_cerrar_descubrimientos` lo restaura. Medido por software: la pantalla con el mapa oculto ahorra ~60 ms por fotograma (el mapa se seguía dibujando debajo de una pantalla opaca).

## 7. Pruebas de la versión
- Nueva: **runner99** (70 comprobaciones: registro, fondo, árbol, estelas, emblemas, largo por cuña, calidad Baja, redibujos). Los redibujos en reposo se miden esperando a que el árbol deje de redibujarse (un cambio de fecha lo rehace una vez con razón) y toleran ≤ 2 en 40 fotogramas: un fallo real (redibujar por fotograma) daría 40.
- **Regresión final** (Godot 4.3 sin ventana; `runner74` con Xvfb): **26 pruebas (runner71–73, 75–88, 91–99) = 2.129 comprobaciones, 0 fallos y 0 «SCRIPT ERROR» / «Parse Error»**, más `runner74` (221 comprobaciones, 0 fallos). Ajustada `runner74`: Opciones > Información ahora tiene dos botones (la carpeta de registros y VOLVER). `runner89` y `runner90` son de rendimiento (sección 9).
- `runner74` pide la versión 0.1.8.44 (lee `main.VERSION`).

## 8. Revisión de variables (`herramientas/auditar_codigo.py`)
- **0 funciones repetidas, 0 variables repetidas** (1.529 funciones); `datos/variables.json` sin cambios (esta versión no añade variables de datos).
- Símbolos nuevos revisados a mano uno por uno (el auditor no lista lo que no se usa). Se borraron por no usarse `LoteUV.esta_vacio` y `LoteUV.triangulos`, y al reorganizar las cuñas `r_borde` y `r_ult` (ahora cada cuña lleva su `r_fin`).

## 9. Revisión de rendimiento (runner89, xvfb por software, 1280×720; cada escenario en su proceso; con y sin el cambio)
**El mapa no cambió** (esta versión no toca su dibujo): `runner89` por software, cada escenario en su proceso, 0.1.8.43 → 0.1.8.44 (ms por fotograma; solo sirve para comparar; el ruido entre pasadas por software es de ±5 ms):

| Escenario | Mundo | Europa | Roma | 40 pasos de zoom + arrastre (ms/paso) | Dibujos (mundo) |
|---|---|---|---|---|---|
| 2026 | 66,2 → 68,0 | 64,6 → 66,1 | 84,0 → 86,7 | 78,4 → 81,3 | 109 → 109 |
| 1 d. C. | 65,1 → 77,3 | 62,7 → 63,7 | 83,9 → 83,9 | 79,4 → 78,1 | 118 → 118 |
| 1096 | 70,3 → 67,7 | 66,9 → 64,8 | 89,6 → 86,3 | 91,4 → 80,2 | 117 → 117 |
| 1500 | 66,9 → 67,7 | 62,7 → 67,2 | 83,9 → 91,9 | 83,1 → 83,0 | 115 → 115 |

- Mismas llamadas de dibujo y triángulos en todos los escenarios; la carga de la escena (3–4,7 s), la memoria (+0 a +1 MB) y simular un día con todas las IA (2026: 10,90 → 10,85 ms; año 1: 3,08 → 3,03 ms) quedan igual: las diferencias de la tabla (la más grande, «Mundo» del año 1, 65 → 77 ms) son ruido de una pasada por software y no se repiten en las demás columnas. El registro de fallos suma 1 nodo y 9 objetos y una línea de texto cada 5 s.
- **Pantalla de Descubrimientos** (1280×720 por software, comparativo relativo): con el mapa oculto el fotograma baja ~60 ms (antes el mapa se seguía dibujando debajo); el cielo animado cuesta ~11–15 ms sobre un fondo liso (con calidad Baja, ~4 ms); los planetas, estelas y emblemas son 3 órdenes de dibujo en total. Sin redibujos por fotograma: todo lo anima el shader con `TIME`.
- Por software no se puede medir el coste real en una GPU integrada: **pídeme el F9** con Descubrimientos abierta.

## Límites conocidos / para decidir
- **No se probó en un PC real**: ni los shaders nuevos en una GPU Intel HD 520 / ANGLE (lo que más puede dar sorpresas), ni el F9 de esta versión. **Pídeme el F9 de la pantalla de Descubrimientos** (abrirla, entrar a una sección grande y moverte con la rueda) y, si algo se ve mal o va lento, Opciones > Pantalla > Calidad Baja deja el fondo y el árbol quietos.
- Los emblemas son procedurales (no ilustraciones). Los cielos de las tres ramas comparten forma y cambian de color.
- El panel de la ley (esquina superior izquierda) tapa a veces los nombres de las cuñas de arriba cuando se ve todo el árbol (viene de la 0.1.8.43).
- La causa de la caída de la 0.1.8.43 sigue sin confirmar hasta tener su registro.

## Lo que viene
Fase 1 (Cimientos) según el plan acordado; el Relieve de altísima calidad (teselas) sigue esperando a que digas cuándo; actualizar CLAUDE.md con las directrices nuevas cuando lo autorices.
