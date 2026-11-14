# Notas técnicas 0.1.8.43 — Descubrimientos a pantalla completa, IA con consecuencias, subprovincias reales, provincias que cambian de forma y pinturas por lugar

Segunda y última versión para las notas de Camilo del 12 y 13 de noviembre (la primera fue la 0.1.8.42). Todo en UNA versión y UN ZIP, como pidió.
Rama `v0.1.8-development`. Directrices de Camilo del 2026-11-13 que mandan aquí: **alta producción** (el peso en disco no es un límite; la fluidez en su PC sí),
**IA con consecuencias**, **Descubrimientos a pantalla completa**, **subprovincias = opción B** (geoBoundaries ADM2, CC BY 4.0, con crédito).

## Qué trae
1. Menos llamadas de dibujo y trabajo repartido entre fotogramas (respuesta al F9 de la 0.1.8.42: 18 FPS de media con todas las IA en el año 1 a x6).
2. **Pantalla de Descubrimientos** (tecla T): pantalla completa, hub por ramas, árbol en abanico circular que sube desde la raíz (no cuadrícula), círculos sin texto, trazos hacia otras secciones y «T», colores negro / gris / verde / dorado.
3. **IA con consecuencias**: diplomacia (opinión, alianzas, rivales, infamia, coaliciones), estabilidad social por provincia (revueltas, independencia), sobreextensión, y la IA decide con todo eso.
4. **Subprovincias reales** (geoBoundaries ADM2): doble clic en una provincia del país enfocado = sus subdivisiones, con nombre, superficie y población estimada.
5. **Provincias que cambian de forma**: conquista parcial en la paz (la provincia se parte) y concesión de territorio; las subprovincias guardadas se descartan solas.
6. **Pinturas por lugar**: provincia → estado → país → región (según dónde cae la provincia) → continente → mundo.

## 1. Rendimiento (antes de añadir nada)
- **Cuadros de tropas por lotes** (`capa_tropas.gd`): cada cuadro hacía ~8 órdenes de dibujo de tipos distintos y el motor no las funde; con IA activas eran ~1.200 por fotograma.
  Ahora cada cuadro solo se encola y `_vaciar_cajas` dibuja todo en 4 pases (fondos y bordes en una malla, banderas agrupadas por país, detalles sobre la bandera, textos).
  Si dos cuadros se pisan se vacía antes de encolar el segundo: el orden de pintado de siempre. Ayudante: `scripts/lote_dibujo.gd` (una malla de triángulos con color por vértice y UNA orden: `canvas_item_add_triangle_array`).
- **El mes del ejército se reparte entre fotogramas** (`Ejercito.avanzar_mes(grupo, n_grupos, limite)` devuelve `true` mientras quede trabajo; `Mundo._mes_en_curso`): ~6 ms con 30.000 pelotones pasan a trozos de 2–3 ms.
- **Balance por país con índice** (`Mundo._bal_pos`) y refresco solo de las filas de los países que ganaron o perdieron una provincia (en vez de rehacerlo todo al transferir).
- Llamadas de dibujo por fotograma (xvfb, mundo / Europa / Roma): **327 / 347 / 306 → 109 / 114 / 109** en 2026 (ver tabla de la sección 9).

## 2. Pantalla de Descubrimientos (`scripts/pantalla_descubrimientos.gd` + `hub_descubrimientos.gd`, `arbol_descubrimientos.gd`, `fondo_descubrimientos.gd`, `lote_dibujo.gd`)
- Sustituye a la ventana de la 0.1.8.42 (`ventana_descubrimientos.gd` y `grafo_descubrimientos.gd` se borraron). Tecla T o botón de la barra; **Esc** retrocede (ficha → hub → cierra). No guarda nada en la partida; lee `Descubrimientos`.
- **Hub**: tres ramas (Militar, Científica, Sociedad), cada una con su ambiente (`fondo_descubrimientos.gd`: fragua con brasas / noche con constelaciones / violeta y oro con ondas) y sus secciones como tarjetas con la constelación de sus descubrimientos.
- **Árbol** de una sección (`arbol_descubrimientos.gd`), rehecho tras las notas de Camilo del 2026-11-13 («no quiero que sea cuadricular», «aprovecha el espacio», «el ETC era el resto del contenido»):
  **abanico circular que sube desde la raíz** (la raíz abajo en el centro; cada era es un anillo —si está muy lleno, hasta 3 sub-anillos pegados—, cada subsección una cuña del abanico de 63° a 150°;
  cada nodo busca el ángulo medio de sus prerrequisitos y se separa de sus vecinos; troncos de la raíz a un cruce por cuña), **líneas curvas en polares**, círculos de 44–76 px a zoom 1 (separación 128 px),
  zoom 4–280 % con la rueda hacia el cursor, arrastrar, entra **centrado en lo que el país puede investigar ya** (zoom 75 %; si no hay nada, la sección entera), botones **«Mi frontera»** y **«Ver todo»**,
  años de cada anillo en el borde izquierdo y nombre de cada cuña en el borde de afuera. **Ya no se escribe «ETC» en ninguna parte**: lo que sigue en otra sección es un **trazo naranja difuminado con una flecha**
  (hacia afuera = lo abre; hacia la raíz = lo necesita; se ve desde zoom 40 %; pulsarlo lleva allí). **Línea terminada en «T»** = camino sin salida. El globo trae nombre, año, estado, ruta, tipo, era, tema,
  la descripción de la sección, lo que requiere y lo que abre; la ficha (clic) suma la descripción de la sección.
  Colores: **bloqueado negro · aún lejano gris · conocido verde · disponible dorado**. El tamaño del círculo crece con lo que abre; la marca de dentro dice el tipo.
- Un solo `Control` con paneo y zoom, dibujado por lotes: cuesta lo mismo con 20 que con 100 nodos; se redibuja solo cuando algo cambia. Cinta de secciones a la izquierda, buscador, filtros por estado y tipo, ficha.
- Con país controlado se ve lo que sabe ese país; como observador, lo que sabe la historia en la fecha del reloj.

## 3. IA con consecuencias
**Diplomacia (`scripts/diplomacia.gd`)** — dos diccionarios dispersos y una revisión cada `DIAS_REVISION` = 15 días solo de los países infames.
- **Opinión** entre dos países (−100…+100): cada hecho la mueve y se olvida a 1 punto cada `OP_REPOSO_DIAS` = 25 días. La que cuenta (`opinion_total`) suma además alianza, rivalidad, infamia del otro y coalición.
- **Alianza** (máx. 3): si atacan a un aliado el otro recibe la llamada (`LLAMADA_DIAS` = 40); si no acude, la opinión cae y la alianza se rompe. Un aliado puede entrar en tu territorio sin declarar la guerra y sus tropas se ven.
- **Rival** (uno por país, 10 años): pesa más que nada; no se puede ser aliado de un rival; la IA lo prefiere como blanco.
- **Infamia**: cada provincia que un país se queda por la fuerza suma entre `INFAMIA_PESO_MIN` (0,25) y `INFAMIA_PESO_MAX` (3) según su **población frente a la media del mundo** (el doble si era tierra propia de un tercero);
  atacar a un aliado +5, romper una tregua +2,5. Vida media 900 días. Con `INFAMIA_COALICION` = 12 los vecinos forman una **coalición** (2–8 miembros) que ataca junta hasta que baja de `INFAMIA_FIN` = 5.
  Con `INFAMIA_PRUDENTE` = 7 la IA deja de agredir por su cuenta.
- Ganchos: `Guerra.declarar`, `Guerra.firmar_paz`, `Mundo.transferir_provincia` (`al_cambiar_dueno`).
**Estabilidad social (`scripts/estabilidad.gd`)** — usa la variable `favorabilidad` (que ya multiplicaba la producción).
- Cada provincia se revisa una vez cada `CICLO_DIAS` = 30 (el día reparte 1/30 en lotes de `LOTE` = 90, ~0,5 ms por llamada) y su valor se acerca hasta `PASO_MAX` = 5 puntos a su **meta**: base 56; core propio +5, core de otro −6; cultura distinta −8;
  conquista reciente hasta −20 (5 años); distancia a la capital hasta −10 (la capital +10); en guerra −4, ocupada −18, devastación hasta −20; **sobreextensión** hasta −20 (de 1,2× a 2,8× el tamaño de partida) y hasta −6 por tamaño absoluto; guarnición hasta +8.
- Bajo `UMBRAL_AGITADA` = 28 la provincia cuenta como agitada; bajo `UMBRAL_REVUELTA` = 15 durante `MESES_REVUELTA` = 2 ciclos **se amotina** junto con las vecinas agitadas del mismo pueblo (máx. `GRUPO_MAX` = 10).
  La IA responde pagando a los notables (`PAGO_FRAC`), reprimiendo (necesita tropas: `FUERZA_FRAC`, `FUERZA_MIN`) o concediendo la independencia (la tierra vuelve a su pueblo de origen o renace como país; con IA activa el país nuevo piensa por sí mismo).
  El jugador recibe un aviso «REVUELTA» que **pausa** y le deja pagar, reprimir, conceder o ignorar. Cada motín repetido encarece el siguiente.
- `Provincia.riesgo_motin` se quitó (lo sustituye la estabilidad); la ficha de la provincia muestra la estabilidad y sus causas.
**IA (`scripts/ia.gd`)**: nuevos avisos que pausan («ALIANZA» te propone una, «LLAMADA» de un aliado, «REVUELTA»); «COALICIÓN» no pausa (aviso rojo). Reglas de decisión: sin opinión suficiente no se alía; nunca ataca a su aliado; con infamia ≥ 7 solo ataca a su rival o a quien está en su coalición;
  con estabilidad media < `MIN_ESTABILIDAD_GUERRA` = 40 o > 15 % de provincias agitadas no agrede; tras una paz con provincias **descansa** `CONSOLIDA_DIAS_PROV` = 45 días por provincia (hasta 3 años); revisa sus relaciones cada `DIAS_DIPLOMACIA` = 60 días (sociable el 75 %).
- **HUD**: pestaña Diplomacia con «Relaciones internacionales» (opinión y sus partes, alianza, rival, infamia, coalición) y botones de alianza, rival y regalo; la ficha de provincia muestra la estabilidad. El día tiene ahora **9 fases**: economía, IA, diplomacia, estabilidad, ejército, obras, llegadas, batallas, ocupaciones.
- **Resultado medido** (100 años con todas las IA activas, antes y después): no pude reproducir el imperio que se come el mundo (ni antes ni ahora pasa de ~7 % de las provincias); lo que cambia es que hay menos guerras (1.222 → 579) y sobreviven más países (134 → 159). Ver la sección 9.

## 4. Subprovincias reales (`scripts/subprovincias.gd`, `scripts/capa_subprovincias.gd`, `herramientas/subprovincias/construir_subprovincias.py`, `datos/subprov/`)
- **Fuente**: geoBoundaries (William & Mary geoLab), **CC BY 4.0** (compuesto CGAZ, nivel ADM2). El archivo lo baja el workflow `traer-geoboundaries.yml` (Release `datos-geoboundaries`: el entorno no alcanza geoboundaries.org).
  **Crédito visible** en Opciones > Información, en la ficha de las subdivisiones y en LEEME.txt: «geoBoundaries (William & Mary geoLab), CC BY 4.0».
- **Datos** (16 MB): un `.bin` por país actual (zlib de int32: anillos en px del mapa × 1024, con deltas), `indice.bin` (casillas de 1° → unidades) y `nombres.json`. El generador usa solo numpy + OpenCV (`approxPolyDP`, tolerancia ≈ 165 m; sin shapely: pypi y npm están bloqueados en el entorno).
- **Uso**: `SubprovinciasScript.de_provincia(pi)` calcula las subprovincias de UNA provincia al pedirlas (carga el país que haga falta, recorta cada unidad con el contorno de la provincia, descarta las < `FRAC_MIN` = 0,3 %, caché de `CACHE_MAX` = 48 provincias y `PAISES_MAX` = 24 países). **Nada se calcula al cargar el mundo ni por fotograma.**
  Población de una subprovincia = la de su provincia repartida por superficie.
- **Mapa**: doble clic en una provincia del país enfocado, o en tierras sin reclamar (o el botón de la tarjeta «Subdivisiones»), abre la capa: límites internos en cinta de malla de grosor fijo en píxeles (se actualiza por uniform: **no se toca `_actualizar_zoom`**), resalte bajo el cursor (máx. 25 pruebas por segundo, punto dentro de polígono sobre cajas) y elegida; clic elige.
- **Límite conocido**: los límites son los de ~2020; en las épocas antiguas son una referencia moderna, no una división histórica (la ficha lo avisa). **Los edificios siguen siendo por provincia**: con subprovincias el texto `slug:n` se multiplicaría (ver 0.1.8.42 sección 7) y habría que pasar antes a un formato compacto; queda para una versión posterior.

## 5. Provincias que cambian de forma
- `Mundo.ceder_parcial_a(provincia, país, fracción, motivo)` (callback `cesion_parcial_cb` que pone `MapaPrincipal`, que tiene el `Territorio`): cede las celdas más cercanas a la vecina del país, reparte población, producción y ciudades por superficie, deja historial y emite `Territorio.forma_cambiada`.
- **Conquista parcial** (`Guerra.fraccion_conquista`): al firmar una paz con posesión sobre una provincia grande la provincia se parte. Provincia de < `PARCIAL_MIN_CELDAS` = 6 celdas o puntaje de guerra ≥ `PARCIAL_DECISIVO` = 0,5: entera; si no, entre `PARCIAL_BASE` = 0,4 y 1 según el puntaje. `Guerra.parciales` cuenta cuántas hubo.
- Al cambiar la forma de una provincia sus subprovincias guardadas se descartan (`MapaPrincipal._forma_cambiada_sub`) y la capa abierta se rehace.
- **Repintado diferido (arreglo de un tirón hallado al medir con todas las IA a x6)**: cada cesión parcial repintaba el mapa entero DENTRO de la paz (relleno 2–9 ms + fronteras 7–12 ms + nombres, 15–25 ms por provincia; con una paz de varias provincias el pico de `Ia.fase_dia` llegó a **298 ms** en el año 1 y 111 ms en 2026,
  y `IA paz` pasó de 0,2 a 3–11 ms por llamada). Ahora `Mundo.ceder_parcial_a` (la que llama la paz) pasa `diferir = true`: los datos (celdas, población, ciudades, historial) cambian al momento, pero `MapaPrincipal._territorio_cambio` solo anota (`_forma_pend`, `_forma_provs`) y
  `_repintar_forma_pendiente` (en `_process`, antes de la sincronización normal) pinta el relleno en un fotograma y deja fronteras, nombres, zoom y foco como etapas de `_pend_dueno` (una por fotograma, como los cambios de dueño); a x3 o más se agrupa (como mucho uno cada `SINC_MIN_MS`).
  El país enfocado y la selección **solo se rehacen si la provincia que cambió de forma es suya o de un vecino** (`_foco_tocado` mira `_forma_provs`): antes cualquier paz del mundo habría vaciado la selección del jugador. Debug y las pruebas (`ceder_parcial` sin `diferir`) siguen repintando al momento.
  `Territorio.calentar()` carga al empezar la partida la geometría del relleno (28 ms la primera vez) para que no caiga en una paz. **Resultado**: pico de `fase_dia` 298 → 12 ms (año 1) y 111 → 44 ms (2026); `IA paz` 0,2 ms por llamada en el año 1.

## 6. Pinturas por lugar (`scripts/pinturas.gd`)
- Cadena nueva: **provincia** (`<época>/lugar_<país>__<provincia>`) → **estado** de EE. UU. (`<época>/estado_<país>__<estado>`; los condados son las provincias) → **país** → **región según dónde cae la provincia** (si el país no tiene pintura propia: el Sáhara de Argelia ya no cae en la región del centro del país) → continente → mundo.
  La clave usa el país de **origen** de la provincia (Toledo sigue siendo «de España» aunque la conquiste otro; el respaldo es la pintura del dueño actual). La ciudad usa la de su provincia.
- Lista de lugares: `herramientas/pinturas/construir_lista_lugares.py` (164 lugares buscados: 143 provincias y 21 estados; **158 con pintura**: Oaxaca, Australia Occidental, Virginia, Nueva Jersey, Cundinamarca y Bucarest no dieron una obra adecuada); se buscan y se bajan con el flujo `traer-pinturas.yml` (Commons solo es alcanzable desde GitHub Actions),
  como las demás (`elegidas_lugares.json` + `elegidas_reemplazos.json`; títulos, autores y años en español en `fichas.json`). **Solo dominio público / CC0**, 1280 px → 960 px, JPEG. Se revisaron todas a ojo en hojas de contacto: se sustituyeron una fotografía estereoscópica (Utah), un detalle demasiado cerrado (Zelanda), un estudio gris (Ivanovo) y un tondo (Quebec), y se recortaron a mano los marcos de museo de 9 obras.
  Total en el juego: **295 pinturas** (137 anteriores + 158 de lugares), 45 MB. Una es «PDM-owner» (Segantini, marca de dominio público del propietario) y las pruebas la aceptan.
- **Región según dónde cae la provincia**: `Pinturas.region_en` trataba la Rusia europea como Asia (Rusia cuenta como Asia en los datos): Moscú o Múrmansk caían en «Oriente Medio». Ahora el cuadrante europeo de Asia (lon ≥ 19°, lat ≥ 44,5°, al oeste de 52°) cae en Europa del este o del norte (runner84 lo prueba).
- `pinturas/creditos.json` y `CREDITOS.txt` llevan la ficha de cada obra; los créditos del juego cuentan cuántas son de lugares concretos.

## 7. Pruebas de la versión
- Nuevas: **runner95** (diplomacia, estabilidad, IA con consecuencias, avisos, HUD), **runner96** (subprovincias), **runner97** (cesión parcial y conquista parcial), **runner98** (pinturas por lugar). **runner91** reescrito para la pantalla de Descubrimientos.
- Ajustadas: runner71, 72 y 83 (9 fases por día; el mes del ejército en partes; reloj en pausa), runner84 (las claves `lugar_`/`estado_` no son países), runner93.
- **Regresión final** (Godot 4.3 sin ventana; `runner74` con Xvfb + GL por software): **25 pruebas (runner71–73, 75–88, 91–98) = 2.059 comprobaciones, 0 fallos**, más `runner74` (220 comprobaciones, 0 fallos). `runner89` y `runner90` son de rendimiento (sección 9).
- runner91 (170): además de la pantalla, comprueba lo que Camilo pidió el 2026-11-13: cada nivel es un anillo alrededor de la raíz (nada de filas), ninguna línea vuelve hacia la raíz, Medicina no está en filas (alturas distintas), los círculos tienen aire (par más cercano ≥ 100) y son grandes, la vista de entrada queda cerca de lo disponible (no con todo encogido), «Ver todo» aleja más, ir a un descubrimiento lo acerca y **ningún texto «ETC» se escribe en el código de la pantalla**.

## 8. Revisión de variables (`herramientas/auditar_codigo.py`)
- `auditar_codigo.py`: **1.500 funciones, 0 funciones repetidas, 0 variables repetidas**; `datos/variables.json` sin cambios (esta versión no añade variables de datos).
- Símbolos nuevos revisados a mano uno por uno (el auditor no lista lo que no se usa): todos se usan. Se borraron por no usarse `_elegir_seccion` (pantalla de Descubrimientos), `credito()` (subprovincias) y, al rehacer el árbol, `PILL_W`, `PILL_H`, `PAD_CARRIL`, `HUECO_CARRIL`; `esta_vacio` del lote se queda porque lo usan las pruebas.

## 9. Revisión de rendimiento (runner89, xvfb por software, 1280×720; cada escenario en su proceso; con y sin el cambio)
Escenario por escenario (0.1.8.42 → 0.1.8.43; ms por fotograma por software, solo sirve para comparar; llamadas de dibujo del mundo):

| Escenario | Mundo | Europa | Roma | 40 pasos de zoom + arrastre | Dibujos (mundo) |
|---|---|---|---|---|---|
| 1 d. C. | 68,5 → 67,3 | 66,1 → 62,0 | 78,4 → 79,5 | 72,3 → 75,9 ms/paso | 397 → 118 |
| 1096 | 65,9 → 65,1 | 63,7 → 59,6 | 82,7 → 79,6 | 75,3 → 74,7 | 407 → 117 |
| 1500 | 66,9 → 63,4 | 64,4 → 59,6 | 82,2 → 80,6 | 78,0 → 77,4 | 392 → 115 |
| 2026 | 68,6 → 64,5 | 63,5 → 60,0 | 82,0 → 77,1 | 75,7 → 71,9 | 327 → 109 |

Memoria al cargar +15 MB (el año 1: 210 → 225 MB; 2026: 348 → 363 MB). Carga de la escena igual (2,5–3,9 s).

**Todas las IA a x6** (`tmp_ia_scen`: 400 días de calentamiento y luego 12 s a x6; respuesta a tu F9 de la 0.1.8.42, 18 FPS de media):

| | ms/fotograma | scripts (ms) | fases (ms) | dibujos | días de calendario en 12 s |
|---|---|---|---|---|---|
| 1 d. C., 186 IA — antes | 193,8 | 25,3 | 15,5 | 555 | 910 |
| 1 d. C., 186 IA — ahora | 152,8 | 16,8 | 11,7 | 158 | 423 |
| 2026, 249 IA — antes | 191,9 | 26,1 | 19,4 | 549 | 638 |
| 2026, 249 IA — ahora | 126,0 | 16,9 | 14,1 | 189 | 304 |

- **Lo que sale peor, y por qué**: con TODAS las IA activas a x6 el calendario avanza ~2× más despacio que en la 0.1.8.42 (910 → 423 días en 12 s en el año 1; 638 → 304 en 2026): cada día cuesta más (diplomacia, estabilidad, la IA que mira relaciones; en 2026 ~1,9 → ~4,4 ms por día simulado) y la simulación respeta su presupuesto por fotograma (9 ms en «equilibrada») para no trabar la pantalla. A cambio la pantalla va más fluida (193 → 153 ms y 192 → 126 ms por fotograma). Con pocas IA activas no se nota. Si a x6 con todas las IA se siente lento, Opciones > prioridad de simulación «velocidad del tiempo» (14 ms) lo compensa; si hace falta se puede optimizar el día (pedir su F9).
- **Repintado diferido** (sección 5): pico de `fase_dia` 298 → 12 ms (año 1) y 111 → 44 ms (2026).
- **Pantalla de Descubrimientos** (árbol en abanico, `tmp_arbol_perf`, 1280×720 por software, el fotograma en reposo ya cuesta ~81 ms por el fondo animado): paneo con «Ver todo» +6 a +13 ms, con la vista de entrada +5 ms; zoom con la rueda igual. Sin tirones en las 3 secciones medidas (Medicina, Tipos de tropa, Economía).
- **Equilibrio de la IA a largo plazo** (`tmp_largo`: 100 años desde el año 1 con las 186 IA activas, 0.1.8.42 contra la nueva): **no pude reproducir «el Imperio romano que se come el mundo»**: ni antes ni ahora aparece un país por encima de ~7 % de las provincias (mayor país: 252 de 4.181 antes, 283 ahora; top 3 casi igual). Lo medible es otra cosa: **guerras declaradas en 100 años 1.222 → 579**, **países que siguen vivos 134 → 159**, y los frenos funcionando (9–12 países con infamia y 8–11 coaliciones a la vez, 7.997 amotinamientos, 148 independencias, 224 conquistas parciales). Si vuelves a ver un imperio que se come el mundo, necesito tu partida o tu F9 para ver qué lo permite.

## Límites conocidos / para decidir
- **Edificios por provincia**, no por subprovincia (formato compacto pendiente). Las subprovincias son modernas en todas las épocas.
- Las pinturas de lugar cubren solo 2026; los demás escenarios usan la del país, la región, el continente o el mundo (se pueden añadir con la misma lista y el flujo).
- **No se probó en el PC de Camilo** (Intel HD 520): ni la pantalla de Descubrimientos con 100 nodos, ni el F9 con todas las IA a x6 en el año 1 (pedirlo), ni el equilibrio de la IA a largo plazo (revisar partidas de varios siglos).
- El Relieve de altísima calidad (teselas) sigue esperando a que Camilo diga cuándo.

## Lo que viene
Versión del Relieve de altísima calidad (pirámide de teselas de ETOPO 2022) cuando Camilo lo pida; edificios por subprovincia con formato compacto; subprovincias históricas por época; vistas Clima / Población / Economía / Cultura.
