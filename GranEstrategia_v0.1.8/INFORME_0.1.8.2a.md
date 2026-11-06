# Informe 0.1.8.2a — Gran Estrategia

2 de noviembre de 2026 · versión 0.1.8.2a (sobre 0.1.8.2)

## Resumen

La 0.1.8.2a entrega los once pedidos del 2 de noviembre; la regresión de 33 pruebas pasa sin fallos y el modelo de datos no cambió.

- **Código**: 20 archivos GDScript, 17.156 líneas (15.874 en la 0.1.8.2), 835 funciones (780) y 1.025 variables y constantes (945). Cero funciones y cero variables duplicadas.
- **Datos**: `variables.json` e `ids.json` idénticos a la 0.1.8.2. Solo cambió `vecinos_prov.json` (enlaces marítimos 917 a 4.725).
- **Pruebas**: 33 pruebas, 613 comprobaciones OK, 0 fallos, 0 errores de script.
- **Rendimiento**: un día de campaña con 54 guerras bajó de ~115 ms a ~62 ms en mi servidor. A velocidad 6 con tantas guerras sigue siendo pesado: lo que queda está en Optimización.
- **Recursividad**: solo recursan las funciones que recorren el árbol de la interfaz (`_ignorar_raton` y cuatro copias de `_sin_foco`); esta versión no añade ninguna.

No se probó jugando a mano ni en tu PC.

## Qué se hizo

Los once pedidos del 2 de noviembre están implementados, más el ajuste de las 03:21 (líneas más finas y sin contorno negro).

| Pedido | Qué se hizo | Dónde |
| --- | --- | --- |
| 1. Sin tropas en muchas provincias al empezar | Todo el ejército de cada país nace en su capital como un solo regimiento | `ejercito.gd` |
| 2. Tropas que se mueven solas con selección múltiple | Ctrl + clic ya no arrastra el grupo; soltar en la provincia de origen no hace nada; un clic derecho largo es mover la cámara | `MapaPrincipal.gd` |
| 3. Rutas por islas | Enlaces marítimos de 917 a 4.725: cada provincia costera se enlaza con la más cercana de cada otra masa de tierra | `construir_vecinos.py`, `vecinos_prov.json` |
| 4. Rutas rediseñadas | Un color por columna (12 colores y luego tonos oscuros y claros), línea de 3 px sin contorno, flechas del mismo color incrustadas, carriles paralelos tipo metro | `capa_tropas.gd` |
| 5. Aviso de guerra y tiempos legibles | Pop-up que pausa el tiempo; muestra días de juego y segundos reales hasta el primer contacto; ninguna IA declara guerras en los primeros 120 días ni ataca al jugador en los primeros 240 | `popup_guerra.gd`, `guerra.gd`, `ia.gd`, `MapaPrincipal.gd` |
| 6. Bajón de FPS con muchas tropas al mismo punto | Rutas a 25 Hz como máximo, flechas a 30 Hz solo a la vista, `dividir_reg` 6 veces más rápido, caché de rutas | `capa_tropas.gd`, `ejercito.gd`, `red_provincias.gd` |
| 7. Aviso de fin de guerra con negociación | Motivo de la paz y solo dos monedas, provincias y dinero, combinables; el rival evalúa en vivo | `popup_guerra.gd`, `guerra.gd`, `ia.gd` |
| 8. Rendimiento que empeora al subir la velocidad | El día se reparte en fases con presupuesto de 9 ms por fotograma; IA y batallas por lotes | `reloj.gd`, `entidades.gd`, `ia.gd`, `guerra.gd`, `MapaPrincipal.gd` |
| 9. Revisión de rendimiento de todo el proyecto | Perfilado por componente, seis correcciones (ver Optimización) | varios |
| 10. Colores | Campaña: color de identidad fijo por país. Dev: color del continente en un tono propio, más oscuro cerca del ecuador, sin degradado | `MapaPrincipal.gd`, `fusion_mapa.gd` |
| 11. Provincias visibles | Un clic en un país muestra sus provincias; los vecinos solo con contorno y sin nombre; la campaña muestra todos los contornos sin clic | `MapaPrincipal.gd`, `fusion_mapa.gd` |

## Cambios dentro de cada código

Se modificaron 12 archivos y se crearon 2; los otros 10 scripts y los datos del modelo quedaron idénticos a la 0.1.8.2. Líneas añadidas y quitadas, medidas con `diff` contra la 0.1.8.2.

| Archivo | + / − | Funciones nuevas | Cambios principales |
| --- | --- | --- | --- |
| `MapaPrincipal.gd` | +566 / −22 | 24 | Esquemas de color, avisos de guerra, un clic para enfocar, contornos de todos los países y de los vecinos, día por fases, refresco limitado del panel, corrección de Ctrl + clic y de soltar en el origen, perfilado |
| `scripts/capa_tropas.gd` | +278 / −125 | 5 (5 quitadas) | Rutas nuevas: paleta, `color_marcha`, carriles, `_construir_y_dibujar_rutas`; se retiraron `_trazar`, `_trazar_oro`, `_trazar_capa`, `_flecha` y `_dibujar_ruta_marcha`; repintado a 25 Hz |
| `scripts/guerra.gd` | +162 / −10 | 10 | Aviso al jugador, día de guerra en tres fases (llegadas, batallas por lotes, ocupaciones), evaluación y firma del tratado con provincias y dinero |
| `scripts/ia.gd` | +73 / −17 | 2 | `fase_dia` por lotes, gracia inicial de 120 días, aviso de paz al jugador en vez de imponerla |
| `scripts/ejercito.gd` | +41 / −30 | 1 | Ejército inicial en la capital, `dividir_reg` con clave entera, perfilado; se quitaron `EXP_POBLACION` y `PESO_CAPITAL` |
| `scripts/fusion_mapa.gd` | +31 / −2 | 2 | `plano`, `repintar_todo`, `vecinos_de`, modos "internas" y "conjunto" en `malla_aristas` |
| `scripts/reloj.gd` | +19 / −2 | 0 | `al_dia_diferido`, `ocupado`, presupuesto de tiempo por fotograma |
| `scripts/red_provincias.gd` | +17 / 0 | 0 | Caché de rutas (hasta 6.000), inversa por `reverse()` |
| `scripts/entidades.gd` | +15 / −4 | 1 | `fases_dia()`, cola de avisos |
| `scripts/popup_guerra.gd` | nuevo, 304 líneas | 15 | Los dos pop-ups: guerra declarada y fin de guerra con negociación |
| `herramientas/construir_vecinos.py` | +18 / −3 | 0 | Enlaces marítimos por provincia (`MAR_K_POR_MASA`) |
| `datos/vecinos_prov.json` | regenerado | 0 | Enlaces marítimos 917 → 4.725; tierra igual (19.448) |
| `project.godot` | +2 / −2 | 0 | Versión y nombre |
| `herramientas/auditar_codigo.py` | nuevo | 0 | La auditoría estática de este informe, para repetirla |

Sin cambios: `base_datos.gd`, `debug_menu.gd`, `hud.gd`, `hud_tropas.gd`, `historia.gd`, `mandos.gd`, `personalizar_pais.gd`, `ranking.gd`, `tema_hud.gd`, `ventana_flotante.gd`, `datos/variables.json` y `datos/ids.json`.

## Resultado del checklist

La regresión final corrió 33 pruebas automáticas con clics, arrastres y teclas simulados sobre el juego real: 613 comprobaciones OK, 0 fallos y 0 errores de script. Cada prueba cuenta como fallo cualquier `FALLO`, `SCRIPT ERROR` o `Parse Error`, o terminar con un código distinto de 0.

| Área | Pruebas | Comprobaciones OK | Fallos |
| --- | --- | --- | --- |
| Interfaz, historia y datos reales | `runner6` (48), `runner7` (43), `runner8` (3) | 94 | 0 |
| Ejército, marchas, guerra y economía | `runner9` (50), `runner10` (34), `runner24` (48), `runner25` (35), `runner30` (57) | 224 | 0 |
| Tropas en el mapa y selección múltiple | `runner16` (17), `runner17` (29), `runner21` (5), `runner28` (22), `runner41` (18) | 91 | 0 |
| Fusión de países y fronteras | `runner15` (47), `runner26` (11) | 58 | 0 |
| HUD, menús y reclutar | `runner27` (7), `runner40` (10), `runner48` (32), `runner49` (9) | 58 | 0 |
| IA y campaña con 50 IA durante 3 años | `runner44` (9) | 9 | 0 |
| Rendimiento y estabilidad | `runner23` (24), `runner31` (8) | 32 | 0 |
| **Nuevo en 0.1.8.2a** | `runner52` rutas (5), `runner53` pop-ups de guerra y tratado (17), `runner54` colores (5), `runner55` provincias (12), `runner60` día por fases (8) | 47 | 0 |
| Diagnósticos y humo, sin líneas OK propias | `runner3`, `runner5`, `runner32`, `runner42`, `runner43`, `runner46` | 0 | 0 |

Seis pruebas necesitaron cambios en la prueba, no en el juego: `runner9`, `runner17`, `runner24`, `runner25`, `runner28` y `runner30` suponían el reparto viejo de tropas (un regimiento por provincia) y se ajustaron al nuevo. `runner28` necesitó más ajustes: a zoom 2,2 las cajas de regimiento de provincias cercanas se solapaban y solo se veían 1 o 2; a zoom 5 y con los reclutas más separados se ven al menos 4 y pasa 22 de 22.

**Lo que ninguna prueba cubre**: jugar a mano, los FPS en tu PC, cómo se ven los colores y las rutas en tu pantalla, y si la IA es demasiado guerrera. Eso está en la lista de ⬜ del `CHECKLIST_TESTING.md`, sección "0.1.8.2a (para probar en tu PC)".

## Funciones

El proyecto tiene 835 funciones en 20 archivos GDScript (780 en 19 archivos en la 0.1.8.2): 60 nuevas y 5 retiradas, y ninguna está repetida dentro de su archivo o clase. El script `herramientas/auditar_codigo.py` hace el conteo y la comprobación de duplicados por archivo y clase interna.

| Archivo | Líneas | Funciones | Nuevas | Retiradas |
| --- | --- | --- | --- | --- |
| `MapaPrincipal.gd` | 4.795 | 233 | 24 | 0 |
| `scripts/debug_menu.gd` | 1.653 | 59 | 0 | 0 |
| `scripts/hud.gd` | 1.584 | 67 | 0 | 0 |
| `scripts/capa_tropas.gd` | 1.334 | 51 | 5 | 5 |
| `scripts/ejercito.gd` | 1.236 | 75 | 1 | 0 |
| `scripts/hud_tropas.gd` | 1.201 | 61 | 0 | 0 |
| `scripts/entidades.gd` | 1.048 | 58 | 1 | 0 |
| `scripts/guerra.gd` | 831 | 50 | 10 | 0 |
| `scripts/ia.gd` | 726 | 30 | 2 | 0 |
| `scripts/base_datos.gd` | 684 | 41 | 0 | 0 |
| `scripts/historia.gd` | 338 | 20 | 0 | 0 |
| `scripts/personalizar_pais.gd` | 307 | 16 | 0 | 0 |
| `scripts/popup_guerra.gd` | 305 | 15 | 15 | 0 |
| `scripts/fusion_mapa.gd` | 234 | 8 | 2 | 0 |
| `scripts/tema_hud.gd` | 218 | 11 | 0 | 0 |
| `scripts/ventana_flotante.gd` | 183 | 11 | 0 | 0 |
| `scripts/red_provincias.gd` | 177 | 11 | 0 | 0 |
| `scripts/mandos.gd` | 113 | 8 | 0 | 0 |
| `scripts/ranking.gd` | 103 | 4 | 0 | 0 |
| `scripts/reloj.gd` | 86 | 6 | 0 | 0 |
| **Total** | **17.156** | **835** | **60** | **5** |

Funciones retiradas (todas en `capa_tropas.gd`): `_dibujar_ruta_marcha`, `_flecha`, `_trazar`, `_trazar_capa` y `_trazar_oro`, reemplazadas por `_construir_y_dibujar_rutas`, `_cinta`, `color_marcha`, `_color_paleta` y `_limpiar_colores`.

Funciones nuevas con más peso: `Guerra.evaluar_tratado`, `exigencia_usd` y `valor_oferta_usd` (la negociación), `Guerra.fase_llegadas`, `fase_batallas` y `fase_ocupaciones` y `Ia.fase_dia` (el día por fases), `MapaPrincipal._esquema_campana` y `_esquema_dev` (colores), `_contacto_estimado` (tiempo hasta el primer contacto) y `_poblar_vecinos` (contornos de vecinos).

## Variables y constantes

Hay 1.025 variables y constantes de nivel de clase (945 en la 0.1.8.2): 80 netas, 82 nuevas y 2 retiradas. Ninguna está repetida dentro de su archivo o clase interna.

Todo lo nuevo que se puede afinar está como constante al principio de cada archivo:

| Constante | Valor | Para qué sirve |
| --- | --- | --- |
| `Ia.GRACIA_INICIAL` / `GRACIA_JUGADOR` | 120 / 240 días | Ninguna IA declara guerras antes de 120 días ni ataca al jugador antes de 240 |
| `Ia.AVISO_PAZ_DIAS` | 45 días | Cada cuánto puede repetir una IA su propuesta de paz al jugador |
| `Ia.ENVIO_MARGEN` / `ENVIO_MIN` | 1,35 / 2.000 | Al atacar manda 1,35 veces lo que necesita y al menos 2.000 soldados |
| `Ia.LOTE_IA` / `Guerra.LOTE_BATALLAS` | 3 / 5 | Países que deciden y batallas que se resuelven por paso del día |
| `Guerra.ANIOS_VALOR_PROVINCIA` | 3 años | Una provincia vale lo que produce en 3 años al negociar |
| `Guerra.FACTOR_EXIGENCIA` | 0,8 | Cuánto exige el vencedor por devolver lo ocupado |
| `Reloj.PRESUPUESTO_US` | 9.000 µs | Tiempo máximo por fotograma para simular días |
| `RedProvincias.CACHE_RUTAS_MAX` | 6.000 | Rutas guardadas antes de vaciar la caché |
| `capa_tropas.gd` `CUERPO_PX` | 3 px | Grosor de la línea de ruta |
| `capa_tropas.gd` `CARRIL_PX` / `CARRIL_ANCHO_TOTAL` | 5,2 px / 48 | Separación entre carriles y ancho máximo de un haz |
| `capa_tropas.gd` `PERIODO_MARCHAS_MS` / `PERIODO_FLECHAS_MS` | 40 / 33 ms | Tope de redibujos de rutas (25 Hz) y de flechas (30 Hz) |
| `MapaPrincipal.CLIC_DER_MAX_MS` | 350 ms | Un clic derecho más largo es mover la cámara |
| `MapaPrincipal.PANEL_PERIODO_MS` / `PANEL_PERIODO_ALTA_MS` | 900 / 2.500 ms | Cada cuánto se rehace el panel abierto (velocidad ≤ 2 / ≥ 3) |
| `MapaPrincipal.ZOOM_PROVINCIAS_TODAS_INI` / `FIN` | 0,7 / 2,0 | Zoom en que aparecen y llegan a su opacidad plena los contornos de la campaña |

Retiradas: `Ejercito.EXP_POBLACION` y `PESO_CAPITAL` (servían al reparto del ejército por provincias, que ya no existe). Variables de estado nuevas sin valor que afinar: cola de fases del día, cola de la IA, estado de los pop-ups y contadores de perfilado.

## Modelo de datos y sobreescritura

El modelo de datos no cambió: `datos/variables.json` y `datos/ids.json` son idénticos byte a byte a los de la 0.1.8.2 (`cmp`), así que no hay variables, tipos, columnas ni IDs nuevos y no hace falta migrar nada. Lo nuevo (avisos, tratados, colores, día por fases) vive en memoria de `Mundo`, `Guerra`, `Ia` y la interfaz y no guarda nada en la base.

**Qué impide que algo se pise sin dejar rastro**

- Todo cambio de estado pasa por `poner_f`, `poner_i` o `poner_s`. Si el valor es igual no hace nada; si cambia y la variable lleva historial por cambio, primero archiva el valor anterior con su fecha de inicio, su fecha de fin y el motivo, y después escribe el nuevo.
- Los IDs no se reutilizan: un pelotón disuelto o una guerra cerrada queda como inactivo (`desactivar`) y su historial se conserva. Los rangos de ID por tipo siguen siendo los mismos (ejército desde 10 M, pelotón 11 M, regimiento 12 M, guerra 13 M, batalla 14 M).
- Esta versión no añade ninguna escritura directa a una columna: la auditoría encuentra las mismas 26 que en la 0.1.8.2, línea por línea.

**Las 26 escrituras directas, clasificadas**

| Dónde | Cuántas | Qué son | ¿Pisa un valor con historial? |
| --- | --- | --- | --- |
| `base_datos.gd` | 8 | `poner_*` (3), la carga inicial sin historial `inicial_*` (3) y el relleno de filas nuevas (2) | No: son la implementación del archivado, la carga de datos de partida y filas vacías nuevas |
| `ejercito.gd` (`_escribir_inicial`) | 8 | Valores iniciales de un pelotón nuevo | No: la celda es nueva, no había valor previo |
| `ejercito.gd` (bajas, reclutamiento, unión) | 8 | Soldados, bajas del mes, experiencia y familiaridad que cambian en cada batalla, recluta o unión | Sí, en el sitio y sin historial, por diseño: cambian a diario y guardar cada paso multiplicaría las filas |
| `entidades.gd` (`avanzar_mes`) | 2 | PIB per cápita y devastación de cada provincia, una vez al mes | Sí, en el sitio; la devastación lo dice en su comentario ("no deja fila de historial") |

El dueño de cada provincia, la ocupación, las guerras, las batallas y la tesorería no están en esa lista: se escriben por `poner_*`, directo o por las propiedades de `Pais` y `Provincia`. Las pruebas de estabilidad (`runner30`, `runner31`, `runner44`) comprueban que tras dos y tres años de simulación no hay NaN ni deuda infinita y que la memoria y el tope de sucesos se mantienen.

## Optimización

Un día de juego en plena campaña pasó de ~115 ms a ~62 ms de simulación. Las cifras vienen de mi servidor (CPU lenta, render por software, sin tarjeta gráfica): sirven para comparar antes y después, no para predecir los FPS de tu PC. Escenario: campaña con 50 IA, día ~150–210, 296 a 389 columnas en marcha, 54 guerras abiertas entre 51 países.

| Parte del día | Antes (0.1.8.2) | Después (0.1.8.2a) |
| --- | --- | --- |
| IA | 82 ms | 29,4 ms |
| Guerra (llegadas, batallas, ocupaciones) | 24 ms | 20,9 ms |
| Economía | 7 ms | 6,0 ms |
| Ejército (avance de columnas) | 6 ms | 5,6 ms |
| **Total simulado por día** | **~115 ms** | **~62 ms** |
| `Ejercito.dividir_reg`, por llamada | 4,4 ms | 0,7 ms |
| Ruta A* repetida | 0,2–0,7 ms | casi gratis (caché) |
| Panel abierto rehecho | 52 ms en cada cambio | como mucho cada 0,9 s (2,5 s a velocidad 3 o más) |

**Qué se hizo**

1. **Día partido en fases.** Con el juego en marcha, el día se simula en pasos cortos repartidos entre fotogramas, con un presupuesto de 9 ms por fotograma (`PRESUPUESTO_US`) y un tope de 40 días por fotograma. Así un día caro ya no congela un fotograma entero. Es la respuesta a "el rendimiento empeora al subir la velocidad".
2. **IA y batallas por lotes**: 3 países y 5 batallas por paso.
3. **`dividir_reg`** ordena con una clave entera nativa en vez de un `sort_custom` (6 veces más rápido).
4. **Caché de rutas** de hasta 6.000 entradas; la ruta inversa sale de la guardada. Se vacía al cambiar la red.
5. **Panel limitado**: las guerras cambian ocupaciones varias veces por segundo y cada cambio rehacía el panel entero.
6. **Muchas tropas al mismo punto**: la capa de rutas se redibuja como mucho 25 veces por segundo (antes, en cada fotograma), las flechas 30 por segundo y solo si hay rutas a la vista, y los carriles se calculan en una pasada.

**Qué sigue costando (medido en la corrida final, día con 21 batallas y ~1.025 pelotones en combate)**

| Parte | ms por día |
| --- | --- |
| `Guerra._ronda`: `_aplicar` 9,6 + `_poder` 4,5 | 17,5 |
| `Ia._operar` (incluye 9,0 de órdenes de marcha) | 17,1 |
| Avance de columnas (un registro de historial por pelotón y paso) | 5,2 |
| Repintar el mapa al cambiar un dueño u ocupante: `pintar` 9,8, fronteras 12, etiquetas 18, foco 18 | 40–60 por cambio |

**Honestidad sobre la velocidad**: en este escenario extremo, a velocidad 6 el servidor gasta ~44 ms por fotograma en simular (fases 29 ms más repintados) frente a ~28 ms a velocidad 3, y el juego avanza más lento que lo nominal. Los FPS dejan de caer en picos, pero el coste por día sigue siendo el techo de la velocidad real. Lo que queda por optimizar está en la segunda tabla.

**Memoria**: en una simulación anterior de 24 meses con 54 guerras, la memoria subió ~158 MB, sobre todo filas de historial. No se cambió; si juegas muchos años conviene podar o archivar ese historial.

## Recursividad

Solo hay recursión real en cinco funciones (`_ignorar_raton` y cuatro copias de `_sin_foco`) que recorren el árbol de controles de la interfaz, y está acotada por la profundidad de ese árbol. Esta versión no añade recursión nueva. El grafo de llamadas, resuelto por nombre y con el algoritmo de Tarjan, marca 16 ciclos (17 en la 0.1.8.2); los revisé uno por uno en el código:

| Ciclo | Veredicto |
| --- | --- |
| `_ignorar_raton` en `hud.gd` | Recursión real: baja por los hijos de un nodo para ignorar el ratón. Termina en las hojas; se llama al armar una tarjeta o ventana |
| `_sin_foco` en `hud.gd`, `hud_tropas.gd`, `debug_menu.gd` y `personalizar_pais.gd` | Recursión real, igual que la anterior: quita el foco a los controles de un panel recién armado |
| `soldados_de_pais`, `proponer_paz`, `cargar`, `avanzar_mes`, `construir` (hud, debug, ranking, personalizar) | Falso positivo por nombre: llaman a la función del mismo nombre de otro objeto (`Mundo` a `Ejercito`, `MapaPrincipal` a `Guerra`, `HUD` a `HudTropas`, las ventanas a `VentanaFlotante`) |
| `_pedir_refresco_panel`, `_sincronizar_propiedad`, `refrescar_todo` | Ciclo por nombre cortado por un argumento: `_pedir_refresco_panel` llama a `refrescar_todo(false)` y `refrescar_todo` solo vuelve a `_sincronizar_propiedad` con `con_mapa = true`. Ya existía en la 0.1.8.2 sin la función intermedia |
| `_dibujar`, `_proponer_paz`, `_tab_diplomacia` en `hud.gd` | Dirigido por eventos: `_proponer_paz` se llama desde un botón; una pulsación rehace el panel una vez |
| `_elegir_bat`, `_refrescar`, `_refrescar_bat`, `_refrescar_reg`, `alternar_reg`, `elegir_reg` en `hud_tropas.gd` | Dirigido por eventos: `alternar_reg`, `elegir_reg` y `_elegir_bat` se llaman desde funciones anónimas conectadas a botones, nunca durante el propio refresco |

No hay funciones recursivas en la simulación (día, guerra, IA, economía, rutas): el día por fases es un bucle sobre una cola, y el algoritmo de rutas es el `AStar2D` de Godot, que es iterativo.

## Riesgos, límites y pendientes

Lo que más puede morder en tu PC es el costo por día con muchas guerras a velocidades altas; el resto son decisiones tuyas.

**Riesgos conocidos**

- **Tiempo más lento que el nominal**: el día por fases protege los FPS, pero en un PC flojo con decenas de guerras el reloj puede avanzar más despacio que lo que dice la velocidad.
- **Sin optimizar todavía**: `Guerra._ronda` (17,5 ms por día), `Ia._operar` (17,1 ms) y el repintado del mapa al cambiar un dueño (40–60 ms por cambio).
- **Memoria**: el historial crece sin tope; en una simulación de 24 meses con 54 guerras la memoria subió ~158 MB.
- **IA muy guerrera**: 54 guerras entre 51 países en 150 días. Se modera con `GRACIA_INICIAL`, `GRACIA_JUGADOR`, `MAX_GUERRAS` y la cautela de cada país en `scripts/ia.gd`.
- **Colores de ruta**: con más de 12 columnas a la vez se repiten los mismos colores en tono oscuro y luego claro.

**Pendientes tuyos**

- El estilo de las líneas de provincia, estado y costura.
- El informe de Debug > "Rend." en tu PC.
- Decir si te gustan los colores de identidad de la campaña, los tonos del modo dev, el grosor de 3 px de las rutas y los precios de la negociación de paz.

**Hoja de ruta**: máquina del tiempo, variables étnicas, árbol de investigación, deriva de idiomas, gastos del estado, subir a GitHub en una rama nueva (nunca `main`) y elegir la licencia (CC0).
