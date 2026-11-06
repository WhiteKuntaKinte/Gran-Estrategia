# Notas técnicas 0.1.8.37 (y corrección 0.1.8.37a) — Temas de interfaz, barra y menú VISTA, selección nueva, bordes HD, etiquetas, paleta y vista de Relieve

## Qué es esta versión
Primera de las tres tandas del rediseño (la 0.1.8.38 es el HUD y las ventanas; la 0.1.8.39, las imágenes). Pedido de Camilo tras las maquetas de estilo: poder elegir **entre 3 temas** desde Opciones,
arreglar el mapa (selección, bordes, etiquetas, paleta) y estrenar la **vista de Relieve** con el ETOPO 2022 completo. Número de versión elegido por mí: **0.1.8.37** (`MapaPrincipal.gd` → `VERSION`, `project.godot`, `runner74`).

## 1. Temas de interfaz (`scripts/tema_hud.gd`, nuevo y reescrito)
- Tres paletas: **A · Cartográfico** (pergamino y tinta; barra de título marrón), **B · Moderno oscuro** (azul noche, texto marfil, oro como acento) y **C · Mixto** (marrón oscuro con bronce).
  Se elige en **Opciones > Pantalla > INTERFAZ**; el cambio es **en vivo** (no pasa por APLICAR ni por «¿Mantener estos cambios?») y se guarda al momento (`ajustes.tema`, por defecto A).
- Cómo se pinta: `TemaHud` guarda los colores como variables estáticas (`_static_init`, `aplicar(id)`); `EstiloMetal` es un `StyleBox` propio (degradado, esquinas cortadas, filo, acento arriba/abajo, filete
  interior) y `crear_tema()` arma el `Theme` de Godot. Los textos con rol (`rotular(label, "titulo"|"tenue"|"nota"…)`) se repintan con `repintar_roles`; los botones registran su estilo en `_estilo_btns`
  y `hud._pintar()` los vuelve a aplicar. Los iconos monocromos se tiñen con el color de texto (`_tintar_icono`).
- Cubre: barra superior, menú VISTA, Opciones, pausa, menú principal, avisos y tooltips, panel de país y HUD de tropas (rotulados por rol). **Las ventanas viejas** (Debug, detalle…) toman colores y tipo de letra
  del tema pero **conservan su estructura**: las tarjetas, el Debug en cuadrícula, la ventana de provincia con Edificios / Cores / Construir llegan en la 0.1.8.38.
- Pruebas: `runner78` (74 comprobaciones): paletas válidas, distintas y legibles (contraste WCAG), `aplicar`, ajustes `tema` y `bordes`, selector con cambio en vivo y guardado, HUD que se repinta, menús.

## 2. Barra superior y menú VISTA (`hud.gd`)
- La barra ocupa **todo el ancho y va pegada al borde de arriba** (`ALTO_BARRA = 44`); el panel de país empieza justo debajo (`PANEL_Y = 52`, `set_campana` ya no mueve el panel).
  Tres grupos: izquierda (Debug, Ranking, versión/FPS), centro (tu país, dinero, fecha y velocidad) y derecha (VISTA y atrás/pausa).
- **VISTA** (icono de lentes `iconos/i_lentes.png`, hecho por `herramientas/hacer_icono_lentes.py`): menú con **Tradicional**, **Internacional**, **Relieve** y, en gris «próximamente», Clima, Población,
  Economía y Cultura y religión. El botón muestra la vista puesta; la tecla V sigue alternando Tradicional / Internacional.

## 3. Selección (`MapaPrincipal.gd`)
- Una selección ahora es: **relleno amarillo** + **resplandor** + **borde NEGRO nítido** que sigue el contorno **exterior exacto** de lo elegido (las aristas que las celdas no comparten con otra de la misma
  selección, encadenadas en una malla de cinta con shader y grosor fijo en píxeles; en la 0.1.8.37 eran `Line2D`, ver la corrección 0.1.8.37a). El resplandor y el relleno **«respiran»** (un solo `Tween` en bucle que mueve el alfa de lo marcado con `meta "resp"`).
- Se **quitó el efecto de país flotante**: enfocar un país ya no lo agranda ni le pone sombra; solo se atenúa el resto del mapa.
- **Ctrl+clic**: suma o quita la provincia (con un país enfocado) o el país (sin foco) bajo el cursor; todo lo elegido queda resaltado, el panel muestra lo último y avisa de cuántos hay (`multi_sel`).
  Con un país ya elegido por clic normal, el primer Ctrl+clic en otro lo suma a ese. Con varios países no se enfoca ninguno. **Todavía no**: totales del grupo y órdenes a varias unidades a la vez (0.1.8.38).
- El contorno se guarda en caché por selección (`_cache_contorno`), así refrescar la selección cada día no lo recalcula.

## 4. Bordes HD con calidad Baja / Media / Alta
- Opción nueva **Opciones > Pantalla > GRÁFICOS DEL MAPA > Bordes del mapa** (`ajustes.bordes`; la calidad Alta pone Alta, la Media pone Media y la Baja pone Baja).
- Cómo: las mallas de borde son cintas cuyas puntas llevan la normal en `UV`; el shader ahora suaviza el canto de la línea **en el propio fragmento** (distancia al centro = `length(UV)`) en vez de depender del MSAA.
  La malla se ensancha `ext_px` a cada lado: **Baja 0 px** (borde duro de siempre, mismo coste), **Media 0,8 px** (canto suave de ~1 px), **Alta 2,0 px** (canto suave + una sombra tenue alrededor de la costa,
  `BORDE_HALO`). El grosor de la línea no cambia (`nucleo`), las líneas finas de provincia no pasan de 0,8 px y la frontera rayada suaviza también su canto.
- **Rendimiento** (dibujo por software, el peor caso: en una tarjeta gráfica real el coste es casi nulo): ms por fotograma Baja 73–75, Media 79–84, Alta 82–86 (+8 % y +12 %); los triángulos son los mismos.

## 5. Etiquetas con letras al revés (`_orientar_linea_etiqueta`, `_colocar_texto`)
- Causa: cada letra se daba vuelta por su cuenta al pasar de ±90° y en las etiquetas casi verticales (AMÉRICA DEL SUR, CHILE, ISRAEL, MYANMAR, FILIPINAS… 29 de 256) unas letras quedaban al derecho y otras al revés.
- Ahora se decide **una vez por etiqueta**: se lee de izquierda a derecha y, si es casi vertical, **de abajo hacia arriba** (cuerda entre −105° y +75°; si no, se invierte la línea entera). Cada letra sigue la curva con
  tope en ±90°. Vale para países, provincias, estados y continentes (todos pasan por `_colocar_texto`).
- Prueba (`runner79`): las 256 etiquetas del mapa, ninguna con la cuerda fuera de rango, ninguna letra pasada de ±90°, todas en el sentido de su línea.

## 6. Paleta renovada (`herramientas/renovar_paleta.py`)
- Los 7 colores base de los continentes (los del modo dev y los de la vista del mundo) pasan de primarios saturados a tonos más sobrios con el mismo matiz: Europa `#4f83d1`, Asia `#d15147`,
  África `#d1a63f`, América del Sur `#d1763f`, América del Norte `#58d174`, Oceanía `#9764d1`, Antártida `#b8c5d1`.
- Se aplicó **sin regenerar el mapa** (el script cambia los colores ya horneados: `malla_filt_cp.bin`, `malla_filt_cc.bin` y el campo `col` de `entidades.json`; es idempotente) y `construir_mapa.py` ya tiene la paleta nueva.
  Los colores de la campaña (`COLORES_IDENTIDAD`, `PALETA_IDENTIDAD`) no cambian.

## 7. Vista de Relieve (ETOPO 2022)
- **Datos**: ETOPO 2022 «surface» a 60″ (NOAA, 465 MB, dominio público; GeoTIFF float32 con DEFLATE y predictor de coma flotante). Está en el Release `datos-etopo` del repositorio (no va en la rama).
  `herramientas/leer_etopo.py` lo decodifica **sin GDAL ni rasterio** (solo numpy + tifffile + zlib; el predictor 3 se deshace a mano: suma de bytes por fila y entrelazado de los 4 planos de bytes).
- **Generador** `herramientas/preparar_relieve_vista.py ETOPO.tif CARPETA_geojson_NE`: pinta el mundo (proyección equirectangular, la del mapa) a 8192 × 4096 y saca 4096 y 2048:
  tierra con colores hipsométricos por altura (verde azulado → verdes → amarillos → ocres → marrones → gris claro), mar con **paleta propia** por profundidad, sombreado desde el noroeste con las pendientes reales
  (corregidas por la latitud), costa, lagos y hielo de Natural Earth 10m (`land`, `lakes`, `glaciated_areas`, `antarctic_ice_shelves_polys`; máscaras al doble de tamaño y reducidas = costas suaves).
  Tarda ~20 s. Salida: `datos/texturas/relieve_vista_2048.jpg` (0,7 MB), `_4096.jpg` (2,4 MB) y `_8192.jpg` (8,4 MB).
- **En el juego**: la calidad gráfica elige la imagen (**Alta 8192, Media 4096, Baja 2048**; personalizada, 4096) y se carga la primera vez que se enciende la vista (~0,8 s con la de 8192; cambiar de calidad con la
  vista puesta recarga la que toca). Es **una sola capa rectangular** (`capa_relieve_vista`, shader `SHADER_RELIEVE_VISTA`, 3 copias del mundo con `repeat`) encima del relleno y de los lagos y debajo de las costas, fronteras,
  nombres y la selección. Con la vista puesta **el relleno y el mar de siempre se apagan** (los tapa la imagen) y la silueta del país enfocado lleva la misma imagen; los nombres llevan un **contorno** (`CapaTexto.contorno`)
  para leerse sobre cualquier terreno.
- El gancho de la 0.1.8.35 (`relieve.png` multiplicado sobre los colores de los países, `SHADER_RELIEVE`) sigue igual; la vista de Relieve es otra cosa y no lo usa.
- **Memoria**: la de 8192 ocupa ~180 MB de memoria de vídeo con sus mipmaps; solo se carga si enciendes la vista, y con calidad Media o Baja se usa la de 4096 (45 MB) o la de 2048 (11 MB).

## 8. Correcciones menores
- `_unidad_elegida()` ya no cuenta como «elegida» una unidad cuyo panel está cerrado (el Ctrl+clic la sumaba al grupo sin estar resaltada).
- `runner72`: el panel ya no baja con «Ranking» (la barra lo contiene); `runner74`: versión 0.1.8.37.

## 9. Pruebas y revisiones
- **`runner79` (nuevo; 120 comprobaciones con la corrección 0.1.8.37a)**: menú VISTA, selección (borde negro, relleno, contorno exacto, caché, grosor en píxeles, respiración), Ctrl+clic, bordes por calidad y desplegable, etiquetas, paleta y vista de Relieve
  (tamaños de imagen, colores del océano / fosa / llanura / Tíbet / Antártida / lago, capas, silueta, cambio de calidad, volver atrás).
- `runner78`: 74 comprobaciones (temas). Resumen de la regresión y del rendimiento en `CHECKLIST_TESTING.md`.
- **Rendimiento** (`runner89` por software, 0.1.8.37 con bordes Alta contra 0.1.8.36, dos pasadas): ms por fotograma +5 a +12 % (mundo 91–94 frente a 87–88; Europa 89–90 frente a 82–83; Roma 58–66 frente a 54–56), mismos triángulos,
  `_process` igual (0,09 ms), simular 1 día con 249 IA igual (5,1 ms), memoria +1 MB, 13 nodos más. Es el coste de los bordes suaves en una GPU simulada por CPU; con bordes en Baja el dibujo es el de antes.
- **Variables**: 0 funciones y 0 variables repetidas; sin nuevas funciones ni variables de clase sin uso (se quitó `foco_contornos`).

## 10. Lo que NO hace todavía
- Las tarjetas del país, el Debug en cuadrícula, la ventana de provincia con Edificios / Cores / Construir, ventanas movibles y redimensionables, totales y órdenes de grupo: **0.1.8.38**.
- Pinturas, banderas, iconos de materias primas y de divisas en alta definición: **0.1.8.39**.
- El filtro sepia del tema A y las tarjetas con pergamino del tema C no están en esta versión (los temas ya cambian colores, tipografía, bordes y botones).
- Las vistas Clima, Población, Economía y Cultura y religión están en el menú pero como «próximamente».

## 11. Corrección 0.1.8.37a — bajones de FPS al hacer zoom
- **Lo que vio Camilo**: con la 0.1.8.37, al acercar y alejar con la rueda el juego daba tirones (solo mientras se hacía zoom).
- **Causa (mía)**: el borde negro y el resplandor de la selección eran `Line2D` con el grosor «fijo en píxeles», y para mantenerlo `_actualizar_zoom()` les reescribía `width` en **cada paso de zoom**.
  Cambiar el ancho de un `Line2D` le rehace toda la geometría (cierres redondos, antialias): con un país grande elegido eran cientos de líneas (EE. UU.: 350 cadenas, 10.029 puntos, ×2 líneas) y cada paso de la rueda costaba ~6 ms de más (el coste no sale en
  `ms_zoom` porque el rehacer se hace al dibujar, no al cambiar la propiedad). La 0.1.8.36 no tenía esas líneas.
- **Arreglo**: el contorno ahora es **una sola malla de cinta por conjunto** (`_malla_cintas`: 2 vértices por punto, UV = vector de desplazamiento con esquina en inglete limitado a 2×, `COLOR.r` = lado) con el shader `SHADER_SELECCION`, que ensancha la cinta en el
  vértice con el zoom y suaviza el canto en el fragmento (igual que los bordes HD). El resplandor y el borde son dos materiales compartidos (`mats_sel`); **el zoom solo cambia dos números por material** (`_fijar_materiales_seleccion`), la respiración solo cambia el `alfa` del
  material del resplandor (ya no recorre nodos) y la malla se guarda en caché con la lista de celdas (`_cache_cintas`). El contorno del mar elegido usa lo mismo; solo queda un `Line2D`: el aro de una ciudad elegida (33 puntos).
  Además el resplandor ahora cae suave hacia fuera (antes era un trazo de 7 px de alfa fijo).
- **Medido** (`runner90`, banco de zoom nuevo: la rueda paso a paso, un paso por fotograma, EE. UU. enfocado y elegido): scripts solos (headless) **12,9 ms por fotograma (máx. 24,2) en la 0.1.8.37 → 6,9 ms (máx. 7,1) en la 0.1.8.37a, igual que la 0.1.8.36 (6,9)**.
  Con dibujo por software (dos pasadas): 160 ms entregada, 127–136 ms corregida, 107–113 ms la 0.1.8.36; lo que queda de diferencia (~20 ms) es el coste de rellenar el resplandor y el borde en una GPU simulada por CPU; en una tarjeta real es casi nulo.
  Sin selección el zoom es igual en las tres (98 / 93–99 / 83–90 ms por software). Elegir un país por primera vez (EE. UU., sin caché) cuesta 138 ms frente a 57 ms en la 0.1.8.36 (el contorno exterior de 4.060 celdas ≈ 61 ms y las cintas ≈ 9 ms); con caché 50 frente a 39 ms.
  Es un coste de una sola vez al hacer clic, no por fotograma.
- **Pruebas**: `runner79` ahora comprueba cintas en vez de `Line2D` (3 copias del mundo, una malla por clase, sin `Line2D` en el contorno), que el zoom solo cambia el grosor de los materiales y no rehace la malla, la caché, la forma de la malla (2 vértices por punto,
  2 triángulos por tramo, UV entre 1 y 2) y el alfa máximo / mínimo de la respiración. `runner90` es el banco de zoom (no comprueba nada: imprime líneas `[Z]`).
- **Revisión de variables**: 0 funciones y 0 variables repetidas; `datos/variables.json` sin cambios; todo lo nuevo se usa (se quitó `_linea_seleccion`).
