# Notas técnicas 0.1.8.39a — Tierras sin reclamar, Antártida y ráfaga de zoom

## Qué es esta versión
Responde a las notas de Camilo tras probar la 0.1.8.39 en el año 1 d. C. (2026-11-10). El número «a» lo elegí yo: es un arreglo sobre la 0.1.8.39, no la 0.1.8.40 del plan (HUD de provincia / Construir).

1. **Un clic en tierras sin reclamar elige SOLO esa zona** (antes enfocaba «el país»: todas las tierras sin reclamar del continente).
2. **Ficha de una zona sin reclamar sin pestañas de gobierno** (solo General): no tiene diplomacia, política, economía ni ejército.
3. **Centro de Europa (y el resto del mundo habitable) ya no queda «sin reclamar»** en el año 1: el generador del escenario reparte los huecos habitados entre las naciones vecinas.
4. **Antártida: las plataformas de hielo son tierra elegible** (antes eran zonas blancas sin límites en Relieve y «mar» en el mapa vectorial).
5. **Ráfaga de zoom**: con la rueda girando, los cuadros de tropas ya no se redibujan en cada paso (la causa del 88 % de los tirones de >50 ms en el CSV de Camilo).

## 1. Selección de tierras sin reclamar (`MapaPrincipal.gd`, `scripts/hud.gd`)
**Causa.** En el escenario del año 1 las tierras sin reclamar son UNA nación inerte por continente («Tierras sin reclamar de África»…). Un clic con zoom de país ejecutaba `_enfocar_pais(pais)`: enfoca la nación entera (nombres de TODAS sus provincias, el resto atenuado) y abre la ficha de un «país» con sus cinco pestañas.

**Arreglo.**
- `_es_libre(pais)`: ¿es la nación inerte de un escenario antiguo? (`Mundo.es_inerte`). No es un país: no tiene gobierno.
- `_seleccionar`: si el clic cae en tierras sin reclamar y el zoom es de país (≥ `ZOOM_CONTINENTE_MAX`, 1,3) → `_seleccion_provincia` + `_tras_elegir_provincia`, **sin `pais_foco`**. Con zoom de continente un clic sigue eligiendo el continente (igual que con cualquier tierra).
- `_seleccionar_varias` (Ctrl+clic) suma la zona (tipo «provincia»), no «el país».
- `_doble_click`: sale del foco, mueve la cámara a esa zona (`_mover_camara_a(_bbox_anillos(...))`) y la elige.
- `_seleccion_provincia`: para una zona libre manda al HUD `tipo = "libre"`: título = nombre de la zona (la provincia de hoy más grande que contiene), subtítulo «Tierras sin reclamar · continente», migas continente → zona, y la descripción: Tipo / Gobierno «Ninguno: ningún pueblo ni estado las reclama» / Continente / Superficie.
- `_ctx_tropas()` devuelve `{}` para una zona libre (sin órdenes de tropas), salvo que el jugador tenga tropas allí (entonces sí: se ven y ordenan las suyas).
- `hud.pestanas_de(tipo, con_tropas)`: «libre» → `["general"]` (o `["general", "militar"]` si hay tropas del jugador); `_tab_general` de una zona libre pone una nota («Nadie gobierna esta zona…») y no dibuja Población / Etnias / Ciudades.

## 2. Tierras habitadas sin reclamar: el generador del escenario (`herramientas/epoca/construir_epoca.py`)
**Causa (comprobada, no era historia).** Los polígonos de Cliopatria y los pueblos dibujados a mano dejan **huecos** entre sí (Germania, la estepa…) y **astillas** de costa y de frontera (Roma, Ravena, Istria, Hungría, Viena…): trozos de provincias de hoy que ningún polígono toca y que el generador dejaba como «sin reclamar».
Al hacer clic en Baden-Wurtemberg caía en uno de esos huecos.

**Regla nueva (`reclamar_huecos`, entre el recorte y `agrupar`).** Cada pieza libre con habitabilidad ≥ `HAB_RECLAMA` (0,60: bosque templado, mediterráneo, estepa, sabana; la selva, el manglar, la taiga, el desierto y la tundra se quedan libres) pasa a la nación vecina con la que más comparte, **capa a capa** (todas las de una capa a la vez, para que el orden no le dé ventaja a nadie), hasta `RONDAS_RECLAMA` (8) capas.
- **Estados** (Cliopatria) solo absorben **astillas** (< `AREA_ASTILLA` = 40 px² ≈ 11.000 km²) y hasta un `MAX_CRECE_ESTADO` = 30 % de su área: un estado no se come una región entera a base de piezas chicas. Los **pueblos** (dibujados a mano) absorben piezas de cualquier tamaño (su polígono era «la región»).
- **Vecino = quien comparte vértices** (≥ 2) **o**, para las astillas, quien tiene un **lado** a menos de `CERCA_PX` (0,45 px) de varios puntos de su contorno (`_dist_a_anillos`): las astillas casi nunca comparten un vértice exacto con la vecina (cada recorte de Clipper calcula sus propios cortes).
  Las islas aisladas (Azores, Feroe, Madeira, Isla de Man, Åland) no tienen a nadie tan cerca y quedan libres.
- **Población**: cada nación que gana tierra sube su población en proporción al área habitable que gana (`1 + ganado / lo_que_tenía`, tope ×`MAX_CRECE_POB` = 3), así la densidad no cambia.
- Los ids de las provincias se asignan DESPUÉS del reparto (antes dependían del dueño de cada pieza).
- La Antártida nunca se reparte (`continente_libre_ok`).

## 3. Antártida: plataformas de hielo (`herramientas/epoca/preparar_plataformas_hielo.py`, `unir_plataformas.gd`)
**Causa.** La vista de Relieve (`preparar_relieve_vista.py`) pinta las plataformas de hielo de Natural Earth (`ne_10m_antarctic_ice_shelves_polys`: Ross, Ronne-Filchner, Amery, Larsen…) como tierra blanca; las provincias vectoriales salen del admin-0 de Natural Earth, que NO las incluye. Resultado: grandes zonas blancas sin límite, que el clic trataba como mar.

**Arreglo.**
1. `preparar_plataformas_hielo.py NE/ne_10m_antarctic_ice_shelves_polys.geojson` las pasa a píxeles del mapa, las simplifica (Douglas-Peucker, 0,05 px) y guarda `herramientas/epoca/fuentes/plataformas_hielo_px.json` (130 plataformas, ~10.000 vértices, 187 KB; ya está en el repositorio).
2. `unir_plataformas.gd` (Godot sin ventana, Geometry2D) las une a la provincia `ata_00_` de `datos/fuente_provincias.json`: engorda cada anillo 0,35 px, une, rellena huecos y encoge de nuevo (cierra las rendijas entre las dos capas de Natural Earth). El resultado: **44 anillos → 13** (las islas rodeadas por plataformas — Alexander, Berkner, Roosevelt — quedan unidas al continente) y la superficie vectorial de la Antártida sube un 10 % (en píxeles del mapa; los km² no cambian: salen de la provincia de hoy). Es idempotente (marca `plataformas` en la provincia).
3. `construir_epoca.py` regenera la geometría común (las celdas de 2026 y del año 1), así que la Antártida cambia en AMBOS escenarios (los anillos del mapa pasan de 16.056 a 16.032).
Comprobado a ojo en Tradicional y Relieve: la línea de costa vectorial coincide con el borde del hielo blanco.

## 4. Ráfaga de zoom (`scripts/capa_tropas.gd`)
**Medido en el CSV de Camilo (F9, 165 s, Intel HD 520):** 159 de los 181 fotogramas de > 50 ms coincidían con un redibujo de las pilas de tropas (en esos fotogramas el reloj de proceso pasaba de 34 a 81 ms de promedio); 206 de los 268 redibujos los pedía el zoom, en 39 ráfagas. Ningún fotograma lento con zoom se explicaba sin un redibujo de pilas.

**Arreglo.** Si el zoom de la cámara cambia dos veces con menos de `ZOOM_RAFAGA_MS` (260 ms) entre una y otra, empieza una ráfaga: las cajas **no se redibujan** (ni por el zoom, ni por la cámara, ni por la simulación), se desvanecen (`FADE_SALIDA_S` 0,10 s, y la capa se apaga con alfa ≈ 0) y se rehacen UNA vez cuando la rueda para `ZOOM_REPOSO_MS` (140 ms), con un fundido de entrada de 0,16 s. Un paso de zoom aislado se redibuja al instante, como antes.
- `rafaga_zoom` (estado), `_desvanecer_pilas(d)`, `n_dibujos_pilas` (contador para pruebas y medición).
- Banco (headless, solo scripts; año 1, Europa, 40 pasos de zoom hacia dentro y 40 hacia fuera): 9 redibujos de pilas → 1 (el final). Con el equipo de Camilo (≈ 5× más lento que el servidor) un redibujo cuesta unos 15 ms; un zoom de 1 s pasaba de ~14 redibujos a 1–2.
- **Efecto visible**: mientras giras la rueda las cajas de tropas se desvanecen y vuelven en ~0,3 s tras parar. Es una decisión mía a cambio de zoom fluido: si prefieres que se queden (aunque se estiren), lo cambio.
- No toca el resto del zoom (`_actualizar_zoom`, regla del zoom intacta). Lo que sigue sin medirse: los ~140 ms de fotogramas lentos del CSV con poco script (el 12 % restante; sospecha: el controlador de ANGLE o la primera vez que se compila un shader).

### Medidas (render por software con xvfb, 2 pasadas; solo para comparar, no son FPS reales; 0.1.8.39a contra 0.1.8.39 con los mismos datos)
| Encuadre | 0.1.8.39 | 0.1.8.39a |
|---|---|---|
| Mundo entero (2026) | 66,8 / 64,1 ms | 66,4 / 69,0 ms (igual) |
| Europa (2026) | 68,4 / 62,7 ms | 67,5 / 62,1 ms (igual) |
| Roma de cerca (2026) | 81,8 / 75,9 ms | 80,2 / 80,9 ms (igual) |
| 40 pasos de zoom + arrastre (2026) | 85,6 / 81,1 ms por paso | **69,6 / 70,9 ms por paso** |
| 40 pasos de zoom + arrastre (año 1) | 84,4 / 80,9 ms por paso | **72,3 / 74,6 ms por paso** |
| Banco de zoom `runner90`, mundo | 78,8 / 75,6 ms por fotograma | **71,4 / 67,8 ms** |
| Simular 1 día (249 IA / 186 IA) | 7,0 / 1,5 ms | 6,6 / 1,9 ms (igual) |
| Memoria del año 1 / carga | 333 MB / 1,39 s | 340 MB / 1,35 s (+71 provincias) |

## 5. Pruebas
- **`runner82`** (nueva): datos y herramientas (marca de plataformas, anillos, celdas iguales en los dos escenarios), plataformas de hielo elegibles en 1 d. C. y 2026 (9 plataformas), 18 sitios del centro y sur de Europa que no son «sin reclamar», lo inhóspito sigue libre (Sáhara, Siberia, Groenlandia, tundra), población del mundo, selección de zonas libres (un clic = una zona, sin foco, sin selección múltiple escondida, solo la pestaña General, Ctrl+clic = zonas, doble clic, zoom de continente, un país de verdad como siempre) y la ráfaga de zoom (un paso aislado redibuja al instante; 30 pasos = ≤ 3 redibujos; se desvanecen; vuelven y se rehacen una vez; la selección sí redibuja al instante).
- `runner75` y el resto sin cambios: pasan con los datos regenerados.
- Regresión completa: ver `CHECKLIST_TESTING.md`.

## 6. Qué NO cambia / pendiente
- Sigue habiendo tierras sin reclamar en el año 1: Sáhara, Siberia, tundra, taiga, selvas, Groenlandia, Australia interior, el hielo, y las islas aisladas. Es lo esperable para esas zonas y para el mapa de tu escenario.
- Las zonas libres siguen siendo provincias «de hoy» agrupadas (hasta 450 px²): una zona sin reclamar puede ser grande.
- No se ha medido en el equipo real: pide el resumen F9 otra vez con el zoom (mismo recorrido) y lo comparo con el anterior.
