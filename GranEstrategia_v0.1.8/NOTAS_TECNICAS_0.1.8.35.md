# Notas técnicas 0.1.8.35 — El mapa en celdas (la forma de las provincias puede cambiar) + pantalla completa

## Qué es esta versión
Pedido de Camilo (5 de noviembre, 01:24): arreglar que la pantalla completa bloquea la resolución, y **rehacer el mapa** para poder unir variables y funciones con él, controlar su
rendimiento, permitir que **las provincias cambien de forma y se delimiten distinto**, mejorar la calidad gráfica y poder meter mejores texturas en el futuro; con todo lo del mapa
bien desarrollado **antes** de meter contenido externo. Revisión de Natural Earth incluida.
No se pidió número de versión: elegí **0.1.8.35** (`MapaPrincipal.gd` → `VERSION`, `project.godot` y las pruebas que lo comprueban).

Guía completa del sistema nuevo: `docs/MAPA_CELDAS.md`. Revisión de Natural Earth: `docs/NATURAL_EARTH.md`.

## 1. Pantalla completa y resolución
Godot no puede cambiar la resolución real del monitor; en pantalla completa usa la del escritorio. Lo que sí se puede elegir es la **resolución interna** a la que se dibuja el juego:
`Window.content_scale_mode = VIEWPORT` + `content_scale_size` (se escala a toda la pantalla). Nuevas claves de ajustes `ancho_fs` y `alto_fs` (0 = nativa; ahora son 16 claves).
`Ajustes.resoluciones_internas(pantalla, actual)` ofrece las resoluciones por debajo de la pantalla; Opciones > Pantalla las muestra en pantalla completa con la primera opción «Nativa».
Una resolución interna menor da más FPS en un PC modesto. En modo ventana todo funciona como antes.

## 2. El mapa en celdas
- **Celda** = un anillo del mapa (16.056 en total). **Provincia** = grupo de celdas. La geometría (`datos/malla_*`, `teselas.json`) es común a todas las épocas; cada época trae su
  tabla `provincias_juego.json` (qué celdas forman cada provincia). El año 1 d. C. pasó de 46 MB a 4,3 MB.
- **Generación**: `recortar_epoca.gd` (Godot `Geometry2D`) genera la subdivisión común de 2026 × año 1 (más celdas de Voronoi en las tierras sin reclamar); `construir_mapa.py` (modo `CELDAS`)
  triangula y arma las mallas y la tabla de pares; `construir_epoca.py` ensambla las provincias de cada época y copia la geometría común a `datos/`.
- **`scripts/fusion_mapa.gd`** (reescrito): el relleno y las fronteras trabajan por celda; las API por provincia siguen igual (`pintar`, `malla_aristas`, `vecinos_de`, `componentes`).
  Nuevas tablas `celda_prov`, `prov_celdas`, `par_pa/par_pb`, `pp_ini/pp`; `mover_celdas(celdas, destino)`.
- **`scripts/territorio.gd`** (nuevo): la única puerta para cambiar la forma: `reasignar`, `fusionar`, `ceder`, `dividir`, `deshacer`, `restablecer`; consultas de área, centro, vecindad,
  celdas de frontera; señal `forma_cambiada`.
- **`MapaPrincipal._territorio_cambio(provs)`**: pone al día cajas de provincias, centro de las tropas (`RedProvincias.actualizar_centro`) y hace el repintado forzado (relleno, fronteras, nombres de país).
- **Debug > Provincia > «Forma del territorio»**: cederle ¼/½ a una vecina, absorber o fusionarse con ella, deshacer y restablecer.
- **Texturas**: `MapaPrincipal.poner_textura_relieve(...)` y carga automática de `datos/texturas/relieve.png` (se multiplica en el propio relleno; sin textura no hay material; la calidad Baja la apaga).
  `herramientas/preparar_relieve.py` prepara la imagen.

### Qué NO hace todavía
Mover población / edificios / tropas con las celdas, crear provincias nuevas, recalcular kilómetros de los tramos de marcha, mover nombres de provincia horneados ni la línea de estados.
Son decisiones de reglas de juego; `forma_cambiada` es el punto de enganche.

## 3. Error encontrado y corregido durante la versión
`FusionScript._indexar_provincias` llenaba `prov_celdas` con `(prov_celdas[p] as PackedInt32Array).append(c)`: en GDScript un arreglo empaquetado se copia al sacarlo de un `Array`, así que
la copia se modificaba y las listas quedaban vacías (el mapa no se repintaba al cambiar de dueño). Lo detectó la prueba antigua de anexión (`runner15`), que se adaptó al modelo de celdas. Corregido
(y el mismo patrón en `Territorio.restablecer`); `runner76` comprueba que las tablas cuadran tras cada operación.

## 4. Clic y cursor: rejilla de casillas
Con 16.056 celdas, buscar «qué celda está bajo el cursor» recorriéndolas todas costaba ~7,8 ms por consulta y, durante el arrastre de tropas (consulta en cada fotograma), la vista previa y el soltar
se atrasaban (esa fue la causa de los 4 fallos de `runner17`). `_anillo_en` usa ahora una rejilla de casillas de 20 px (`_construir_rejilla`, se arma una vez al abrir el mapa porque las celdas no se mueven):
solo se prueban las celdas de la casilla del punto, de menor a mayor área (los enclaves ganan). Resultado idéntico al recorrido completo (lo comprueba `runner76`, `t_rejilla`) y **6 µs** por consulta
(1.300 veces más rápido).

## 5. Rendimiento medido (0.1.8.34 vs 0.1.8.35, mismo PC de pruebas, `runner89`, render por software, dos pasadas cada uno)
| 2026 | 0.1.8.34 | 0.1.8.35 |
|---|---|---|
| carga de la escena | 2,8 s | 2,9–3,0 s |
| iniciar partida | 78 ms | 118 ms |
| memoria tras cargar | 265 MB | 304 MB (+39 MB) |
| triángulos vista mundo / Europa / Roma | 477.135 / 339.452 / 212.870 | 533.495 / 400.140 / 228.475 (+12 % / +18 % / +7 %) |
| ms por fotograma mundo / Europa / Roma | 90 / 96 / 70 | 104–109 / 105–107 / 71–74 |
| 40 pasos de zoom+arrastre | 82–90 ms | 89–95 ms |
| simular 1 día con 249 IA | 7,1–7,5 ms | 6,8–7,5 ms |

| 1 d. C. | 0.1.8.34 | 0.1.8.35 |
|---|---|---|
| carga de la escena | 1,2 s | 1,3 s |
| memoria tras cargar | 308 MB | 335 MB |
| triángulos mundo / Europa / Roma | 531.269 / 384.158 / 236.630 | 533.928 / 400.487 / 236.769 |

- El precio del modelo de celdas: más triángulos en vista lejana (las celdas son piezas más pequeñas y repiten vértices en sus cortes) y ~30–40 MB más de memoria. Con zoom cercano (Roma) no cambia.
- A cambio: la carpeta `datos/` pasa de 113 MB a 80 MB y el paquete del año 1 d. C. de 46 MB a 4,3 MB.
- Cambiar la forma de una provincia cuesta ~33 ms (una celda, con repintado completo) y ~13 ms por cambio en ráfaga (40 cambios).
- Medido en un entorno sin GPU (llvmpipe); en una GPU real el coste de triángulos pesa mucho menos que el de píxeles, pero no se ha podido medir en el PC de Camilo.

## 6. Otro detalle corregido
Sin `datos/texturas/relieve.png` (el caso normal hoy), al abrir el mapa Godot escribía en el registro «Error opening file … relieve.png». `_cargar_relieve_archivo` ahora comprueba primero que el archivo exista.

## 7. Pruebas
- Regresión final: 35 pruebas en los datos reales (1.373 «OK», 0 fallos) y 8 en los de semilla (697 «OK», 0 fallos).
- `test/runner76.gd` (nuevo, 97 comprobaciones): estructura de celdas, clic y color tras mover celdas, rejilla de clic contra la cuenta completa (y su tiempo), centro de cada provincia dentro de sus celdas, fronteras contra una cuenta por fuerza bruta, fusionar / ceder / dividir (también hacia una provincia sin celdas),
  deshacer y restablecer, baile aleatorio de celdas con invariantes, gancho de texturas, herramientas del Debug y el año 1 d. C.
- `test/runner75.gd`: el paquete del año 1 ya no duplica la geometría; ambos escenarios reparten las mismas 16.056 celdas.
- `test/runner74.gd`: versión 0.1.8.35 y resolución interna en pantalla completa.
- `runner15` (anexión Francia → España con colores y fronteras leídos de las mallas) adaptado a celdas (fronteras iniciales: 17.932 segmentos; antes 17.019 porque las celdas parten los segmentos).
