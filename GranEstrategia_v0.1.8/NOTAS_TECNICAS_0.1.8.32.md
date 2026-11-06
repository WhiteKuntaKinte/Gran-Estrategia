# Notas técnicas 0.1.8.32 — Rendimiento (revisión de todo el código) y opciones gráficas

## Qué es esta versión
Pedido de Camilo (4 de noviembre, 16:30): *«Complete overhaul … check a todo el código … encontrar la forma de mejorar el rendimiento, hay todavía múltiples problemas … se vuelve imposible jugar … hasta que no consigas limpiar código innecesario y procesos sobrantes de verdad no quiero que me entregues un nuevo zip. Al igual que en la 0.1.8.25 no hay opciones de gráficos como había pedido, necesito ser capaz de cambiar las opciones gráficas y de pantalla desde opciones.»*
No se pidió número de versión: elegí **0.1.8.32** (`MapaPrincipal.gd` → `VERSION`, `project.godot` y las pruebas que lo comprueban). La 0.1.8.31 (Opciones > PANTALLA / INFORMACIÓN) se construyó pero nunca se entregó, así que esta versión la incluye y la amplía.

El método fue medir primero: `test/` no trae el banco (es de diagnóstico), pero se corrió una campaña real de España con cronómetro por fotograma y por función (`Perfil.anotar`), antes y después de cada cambio, y solo se tocó lo que salía en el cronómetro.

## Resultado medido
Mismo equipo, mismos datos reales (249 países, 7.653 provincias), campaña de España, `--headless` (solo cuenta el coste del código del juego: simulación + interfaz + lo que se arma para dibujar; el dibujo de la tarjeta gráfica no entra). **El PC de Camilo no está medido.**

| Escena | FPS antes → después | Fotograma «malo» (p95) antes → después | Peor fotograma antes → después |
|---|---|---|---|
| Paz, x1 | 145 → **145** | 7 ms → **7 ms** | 18 ms → **17 ms** |
| Paz, x3 | 145 → **144** | 7 ms → **7 ms** | 22 ms → **32 ms** |
| Paz, x4 | 138 → **143** | 11 ms → **8 ms** | 58 ms → **39 ms** |
| Paz, x5 | 121 → **139** | 18 ms → **13 ms** | 85 ms → **30 ms** |
| Paz, x6 (1 año por segundo) | 78 → **122** | 34 ms → **18 ms** | 168 ms → **31 ms** |
| Guerra, x1 (vista país) | 143 → **144** | 7 ms → **7 ms** | 76 ms → **36 ms** |
| Guerra, x4 (vista país) | 89 → **125** | 50 ms → **13 ms** | 132 ms → **65 ms** |
| Guerra, x4 (vista mundo) | 123 → **142** | 22 ms → **9 ms** | 70 ms → **27 ms** |
| Guerra, x6 (vista país) | 19 → **96** | 121 ms → **25 ms** | 152 ms → **61 ms** |
| Guerra, x6 (vista Europa) | 32 → **106** | 94 ms → **21 ms** | 160 ms → **40 ms** |
| Guerra, x6 (vista mundo) | 34 → **90** | 82 ms → **26 ms** | 146 ms → **49 ms** |

*FPS* = fotogramas por segundo medios (el banco está limitado a 145). *p95* = el fotograma «malo» típico: 1 de cada 20 tarda más que eso. «Peor» = el tirón más largo de la escena. A x4 o más el juego decide por tiempo real y la partida no es idéntica entre corridas, así que los números son orientativos (±15 %); a x3 o menos no hay mejora ni empeora (el pico de 32 ms a x3 es un solo fotograma). Guerra = campaña de España, 400 días tras empezar con IA en los 249 países.

Lo importante: lo que hundía los FPS era la guerra a velocidades altas (x4–x6) y los tirones de 40–170 ms cada vez que se conquistaba una provincia o cambiaba el año.

### Picos que se eliminaron (el mayor tirón de cada tipo, en ms)
| Qué | Antes (0.1.8.31) | Ahora (0.1.8.32) |
|---|---|---|
| Cierre del año (`_cierre_periodo`), el peor | 61 ms | 15 ms |
| Una batalla grande (`fase_batallas`), la peor | 32–41 ms | 12 ms |
| Desarrollo mensual (`avanzar_mes`), media por mes | 13,5 ms | 6,3 ms (el peor casi igual: 21 → 25 ms) |
| Repintar tras una conquista, el peor (`sinc max`) | 128 ms | 27 ms |
| Fronteras tras una conquista | 12,4 ms | 2,9 ms |
| País enfocado tras una conquista (`foco`) | 13,1 ms | 2,0 ms |
| Panel abierto, rehacer (`refrescar_todo`) | 48,7 ms | 3,3 ms |
| Elegir dónde va cada pila de tropas | ~14 ms | ~3,5 ms |
| **No cambió**: una decisión de la IA (`fase_dia`), la peor | 45 ms | 46 ms (es una sola decisión, atómica; ocurre pocas veces por minuto a x6) |

## 1. Qué se cambió (por zonas)

### 1.1 Simulación
| Cambio | Dónde | Efecto |
|---|---|---|
| **El cierre anual del historial va por trozos.** Archiva ~15.000 filas; antes lo hacía todo de golpe (45–70 ms cada año de juego). Ahora `cerrar_periodo_paso` archiva como mucho 2.500 filas por llamada y el reloj reparte el resto entre fotogramas. Además solo mira las filas a las que cada variable aplica (la tesorería existe en ~250 países, no en las 50.000 filas de provincias y pelotones): `_indices_aplica` guarda esa lista y solo mira lo nuevo. | `base_datos.gd`, `MapaPrincipal._cierre_periodo` / `_fases_mes` | `_cierre_periodo` máx 61 → 9 ms |
| **Desarrollo mensual por grupos de meses a x4–x6.** A x6 pasan 12 meses por segundo y recorrer las 7.653 provincias cada mes costaba más de 3 ms. Ahora, en modo ahorro, cada mes solo se desarrolla 1/N de las provincias y con el crecimiento de N meses de golpe (x4: N=3, x5: 6, x6: 12). Crecer 12 meses de una vez da lo mismo que crecer 1 mes doce veces (se usa la forma cerrada también para la recuperación de la devastación). A x1–x3 no cambia nada. | `Mundo.avanzar_mes`, `GRUPOS_MES_VEL` | `avanzar_mes` máx 21 → 17 ms; x6 sin tirones por mes |
| **`Ejercito.avanzar_mes` recorre solo el grupo que toca** (antes miraba todos los pelotones para saltarse 2 de cada 3). | `ejercito.gd` | menos trabajo en x4–x6 |
| **Las batallas grandes se reparten entre fotogramas.** Una batalla con cientos de pelotones tardaba 30–60 ms en las sub-rondas de un paso largo (x4–x6). Ahora `fase_batallas` se corta entre sub-rondas al pasar de 5 ms (`CORTE_BATALLAS_US`) y la batalla sigue en la llamada siguiente (`_bat_curso`, `_bat_resto`). El orden de combate no cambia (una batalla termina antes de empezar la siguiente): solo cambia dónde se parte el trabajo. Si la batalla se cierra entre llamadas (paz, aniquilación) se descarta sin combatir de más. | `guerra.gd` | `fase_batallas` máx 57 → ~20 ms |
| **IA: una decisión por llamada** (`LOTE_IA` 3 → 1). Una decisión cuesta 0,3–3 ms pero a veces 20: con una por llamada el presupuesto del fotograma corta justo y no se pasa. El resultado de la IA es el mismo, solo se reparte distinto entre fotogramas. | `ia.gd` | picos de IA menores |

### 1.2 Repintado al cambiar de dueño (conquistas, anexiones)
Antes, cada conquista repintaba todo de una vez (fronteras, nombres, país enfocado, líneas de provincia): 60–130 ms en un fotograma. Ahora:
- **Por etapas**: el color se pinta al instante y las demás etapas (`fronteras` → `etiquetas` → `zoom` → `foco`) corren **una por fotograma** (`_pend_dueno`, `_correr_pend_dueno`; la etapa `zoom` rehace el nivel de detalle de los textos y antes iba pegada a `etiquetas`). Las pruebas, Debug y los cambios pedidos a mano siguen haciéndolo todo al momento.
- **Mallas de frontera incrementales** (`fusion_mapa.gd`): un índice de pares de provincias vecinas (`pp_ini`/`pp`, `par_a`/`par_b`) y un conjunto de pares-frontera que se actualiza solo con lo que cambió, en vez de recorrer todos los pares y reconstruir la malla. `fronteras` 12,4 → 3 ms.
- **Bloques de nombres por adyacencia** (`fusion.componentes`, búsqueda en anchura) en vez de comparar todas las provincias entre sí; cajas y pesos de provincia en arreglos nativos (`_calcular_cajas_provincias`). `et_bloques` 4,8 ms.
- **Líneas de «todas las provincias»** (`_actualizar_prov_todas`): se rehacen como mucho cada 1,5 s a velocidad ≥ 3 (`PROV_TODAS_MIN_MS`) y ya no cuelgan de cada reconstrucción de fronteras.

### 1.3 Dibujo de tropas (`capa_tropas.gd`)
- La **elección de dónde poner cada pila** (evitando pisar nombres de provincia y otras pilas) pasó de ~14 a ~3,5 ms: índice por bandas de las cajas de nombres (`_nom_bandas`, `BANDA_NOMBRES`) para no comparar contra todos, y solo se consulta si hay nombres visibles; combinaciones de desplazamiento ordenadas con una ordenación nativa (`_mas_cortos`) y límite `MAX_COMBOS`; ordenar regimientos con llaves enteras empaquetadas (`(total << 20) | (0xFFFFF - i)`) y `sort()` nativo en `_preparar_pilas`; inserción simple (`_ordenar_regs`) para listas cortas.
- Se mantienen **todas** las candidatas de hueco: un primer intento con topes recortaba candidatas y dejaba cuadros sin sitio (lo cazó `runner25`: «hay un cuadro clicable»); se restauró la semántica original y la ganancia viene de la estructura, no de buscar menos.

### 1.4 HUD y paneles
- `Hud.refrescar(d)`: al refrescar el panel abierto compara una **firma de lo visible** (`_firma_visible`) y no reconstruye si no cambió nada (antes se rehacía entero, ~50 ms, aunque no hubiera nada nuevo). Las claves que solo afectan a la pestaña Economía (`CLAVES_SOLO_ECONOMIA`) no refrescan las otras pestañas.
- Los refrescos del panel siguen espaciados (900 ms a x1–x2, 2,5 s a x3 o más) y el repintado por cambio de dueño se agrupa a x3+ (`SINC_MIN_MS` = 450 ms).

### 1.5 Código y procesos sobrantes que se quitaron
Funciones sin ningún llamador (comprobado con la herramienta `muertas.py` + búsqueda de cada nombre en los 23 archivos, y con las 4 pruebas): `Historia.banderas_de`, `Ejercito.pelotones_de`, `Ejercito.cuenta_regimientos`, `Ejercito.posicion_marcha`, `RedProvincias.punto_entre`, además de variables y bloques de trabajo que ya no hacían nada: `Hud.caja_dinero`, `PopupGuerra.ultima_accion`, `MapaPrincipal.seleccion_activa`, y en `capa_tropas.gd` los contadores de depuración `dbg_cnt`, `_orden` y `_sig_marchas`. **El conteo de líneas no baja** (18.070 → 18.627) porque entran las opciones gráficas nuevas y el trabajo por trozos / incremental; lo que bajó es lo que se ejecuta por segundo, no el tamaño del programa. Auditoría estática: 23 archivos, 911 funciones, 0 funciones o variables duplicadas.

### 1.6 Opciones gráficas (lo que faltaba)
`Opciones > PANTALLA` ahora tiene tres secciones (la ventana tiene barra de desplazamiento; se revisó con capturas, nada queda cortado):

| Sección | Ajuste | Valores |
|---|---|---|
| PANTALLA | Modo de pantalla | Ventana / Pantalla completa |
| | Resolución de la ventana | las que caben en tu pantalla |
| | Ventana sin bordes | sí / no |
| | VSync | Desactivado / Activado / Adaptativo |
| | Límite de FPS | Sin límite, 30 … 240 |
| | Contador de FPS | mostrar / ocultar |
| GRÁFICOS DEL MAPA | **Calidad** | Alta (como siempre) / Media / Baja / Personalizada (se pone sola si tocas algo suelto) |
| | Suavizado de bordes | Sin / 2x / 4x |
| | Mar | Con profundidad / Color liso (más rápido) |
| | Costas | Detallada (al acercar) / Detalle medio / Detalle bajo (menos triángulos) |
| | Líneas de provincia | dibujar al acercar (campaña) sí/no |
| | Ciudades | dibujar al acercar sí/no |
| | Lagos | dibujar sí/no |
| SIMULACIÓN | Prioridad | Fluidez (la simulación de días gasta como mucho 4 ms por fotograma; el tiempo puede ir más lento) / Equilibrada (9 ms) / Velocidad del tiempo (14 ms) |

- Los ajustes del mapa se aplican con `MapaPrincipal._aplicar_calidad` y **ahorran trabajo de verdad**: «Color liso» quita el shader del mar (un rectángulo de color en vez de un cálculo por píxel de mar), «Detalle medio/bajo» usa mallas de costa con menos triángulos todo el tiempo, y sin líneas de provincia, ciudades o lagos esas capas ni se dibujan ni se actualizan al mover el zoom.
- **Prioridad de simulación** cambia `presupuesto_us`: cuántos microsegundos del fotograma puede usar la simulación de días. «Fluidez» deja más fotograma libre a costa de que el tiempo avance algo más lento a velocidad alta.
- Se guardan en `user://ajustes.cfg` (`%APPDATA%\GranEstrategia\ajustes.cfg`) y se aplican al abrir el juego. Sin archivo: todo como antes (calidad Alta). Un archivo roto o de otra versión no da error: lo válido se usa y lo demás vuelve al valor por defecto (`Ajustes.sanear`).
- Confirmar o revertir: igual que en la 0.1.8.31 — si el cambio mueve o redimensiona la ventana sale «¿Mantener estos cambios?» con 10 s.
- Consejo para un PC flojo: Calidad **Baja** (ya trae mar liso, costa de detalle bajo, sin líneas de provincia ni lagos y sin suavizado), VSync desactivado y prioridad **Fluidez**.

## 2. Lo que cambia en el juego (honesto)
- **A x1–x3 el juego es idéntico**: la «huella determinista» (`runner70`: campaña de 50 IA, 2 años, semilla fija) da exactamente los mismos números en fecha, soldados, hash de tropas, guerras, batallas, decisiones, paces, población, dueños y marchas que la 0.1.8.31.
- **A x4–x6 (modo ahorro) la tesorería total difiere en ~2·10⁻⁷ en relativo** (4,2·10⁹ sobre 2,17·10¹⁶ tras 2 años): es el desarrollo mensual por grupos de meses (mismo crecimiento, aplicado en otro orden / con otros redondeos). Todo lo demás de la huella, incluidos los soldados y los dueños de cada provincia, es idéntico.
- **Repintado por etapas**: tras una conquista el color cambia al instante, pero las fronteras, los nombres, su tamaño y el país enfocado se actualizan en los 1–4 fotogramas siguientes (a 60 FPS, ~65 ms). A x3+ además se agrupan (como mucho uno cada 450 ms) y las líneas de «todas las provincias» cada 1,5 s.
- **IA**: decide igual, pero una por llamada.
- Las opciones gráficas por defecto reproducen el juego de siempre (calidad Alta, suavizado 2x, sin límite de FPS, prioridad Equilibrada).

## 3. Pruebas
Todas corridas con Godot 4.3 sobre los datos reales (`tp3`) y los de semilla (`tp2`), con ventana virtual y GL por software:
- `runner71` — 181 comprobaciones (se actualizó: el cierre del periodo va por trozos y la IA decide 1 por llamada; 2 comprobaciones nuevas).
- `runner72` — 121, `runner73` — 84, `runner74` — 176 (opciones: 14 ajustes, calidades, aplicar a la ventana, guardar/cargar, confirmar/revertir, menús).
- Las 34 pruebas de siempre (mapa, HUD, guerra con clics y capturas, selección de tropas, IA, observador…) más las 4 unitarias de arriba: **38 pruebas, 1.148 comprobaciones «OK», 0 fallos y 0 «SCRIPT ERROR» / «Parse Error»**; y con los datos de semilla `runner3`, `5`, `6` (48) y `7` (43), también en 0 fallos.
- Se corrigieron pruebas que dependían de detalles internos: `runner15` (espera a que termine el repintado por etapas), `runner71` (cierre por trozos, IA de a 1) y `runner6`, `7`, `8`, `9`, `10`, `24`, `44`, `45`, `57` (usaban cosas que solo ellas llamaban: `caja_dinero`, `cuenta_regimientos`, `pelotones_de`, `posicion_marcha`; ahora leen `pel_de_reg` y `lbl_dinero`, y calculan la posición con los centros de provincia).
- Banco de rendimiento (`runner80`, no se entrega): campaña real, cronómetro por fotograma.
- Capturas de la ventana PANTALLA con la barra de desplazamiento arriba y abajo: nada cortado.

## 4. Lo que NO está probado
- **Tu PC real**: los números de arriba son de un servidor sin tarjeta gráfica y no incluyen el dibujo de la GPU. En tu PC la ganancia será menor o mayor según dónde estaba tu cuello de botella (CPU de la simulación o dibujo del mapa).
- **VSync, límite de FPS, suavizado, pantalla completa y resolución con tu monitor y tu driver**, dos monitores y el escalado de Windows al 125–150 %.
- **Cuánto ganan «Color liso», «Detalle bajo» y la calidad Baja en tu tarjeta**: la lógica está probada (la capa se cambia o no se dibuja), pero el efecto en FPS depende de tu GPU.
- **Tiempos entre guerras muy largas (años) con muchas IA activas a x6**: se probaron 400 días de campaña + varios cientos de días de guerra por escena.

## 5. Para volver atrás si algo se ve raro
Opciones > PANTALLA > RESTABLECER y APLICAR deja las opciones como antes. Si algo del repintado (fronteras o nombres que tardan un instante en aparecer) molesta, dímelo con la velocidad en la que pasa.
