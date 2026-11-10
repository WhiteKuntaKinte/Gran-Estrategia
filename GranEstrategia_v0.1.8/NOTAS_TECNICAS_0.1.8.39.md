# Notas técnicas 0.1.8.39 — Rendimiento y arreglos: imagen guardada del relleno, grabador de rendimiento, sin vista Internacional, nombres legibles en Relieve, campaña siempre de 2026

## Qué es esta versión
Responde a las notas de Camilo tras la 0.1.8.38 (2026-11-09). Lo que entra:

1. **Rendimiento con el mundo a la vista**: el relleno de países se dibuja como UNA imagen guardada (en vez de ~390 mil triángulos) mientras el mapa se ve de lejos.
2. **Grabador de rendimiento** (F9 / Debug > Rendimiento): anota fotograma a fotograma lo que pasa mientras juegas y deja un resumen para mandarlo. Sirve para ver los números reales de TU equipo.
3. **Vista Internacional quitada**: quedan Tradicional y Relieve; V alterna entre las dos.
4. **Nombres legibles en Relieve**: letra blanca en negrita con un halo oscuro (más grueso en los nombres chicos).
5. **Lista de la CAMPAÑA siempre de 2026** (un archivo fijo), aunque vengas del escenario del año 1 d. C.

**No entra** (queda para una versión propia, a pedido de Camilo): el relieve de altísima calidad por teselas (ver `CLAUDE.md`, «Requisito de Camilo para más adelante»). El Relieve sigue con las imágenes de 2048 / 4096 / 8192 px de siempre.

## 1. Imagen guardada del relleno (`MapaPrincipal.gd`, «IMAGEN GUARDADA DEL RELLENO»; `fusion_mapa.gd`)
**Problema medido.** Con el mundo entero a la vista el relleno de países (`malla_filt_*`: ~454 mil vértices, ~386 mil triángulos, 32 teselas × 3 copias del mundo) dibuja casi medio millón de triángulos que miden menos de un píxel. En el render por software
(solo sirve para comparar) era la mitad del coste: 113 ms → 54 ms sin relleno.

**Solución.** Un `SubViewport` (`cache_rel_vp`, 4096 × 2048, fondo transparente) con UNA instancia por tesela que comparte el mismo recurso de malla que el mapa, más tres `Sprite2D` (el mundo y sus dos copias laterales) que muestran su textura.
- Cada fotograma `_aplicar_cache_relleno()` (en `_process`, justo después de `_aplicar_capas_ocultas`) decide: si el mapa mide menos de `CACHE_RELLENO_Z_INI` (1,7) píxeles de pantalla por unidad de mapa (≈ 1 píxel de imagen por píxel de pantalla) se enseña la imagen y se apagan las mallas
  (`capa_pais.visible = false`); por encima de `CACHE_RELLENO_Z_FIN` (2,0) vuelven las mallas. Entre 1,7 y 2,0 se queda como estaba (histéresis, sin parpadeo).
- La medida es en **píxeles de pantalla** (`_zoom_real()`), no en zoom de cámara: en 1080p la imagen se usa hasta zoom ≈ 1,1; en 1440p hasta ≈ 0,85; en 4K solo en el zoom mínimo. (4096 px de ancho es el tope razonable: 32 MB de video.)
- **Recoloreo**: las instancias del SubViewport entran en los grupos `inst_fill[k]` de `fusion`, así que `_reconstruir_tesela` las actualiza junto con las del mapa (no hay una segunda ruta de colores). Cuando `fusion.pintar` toca alguna tesela marca `main.cache_rel_sucia = true`;
  la imagen se rehace (`render_target_update_mode = UPDATE_ONCE`) a lo sumo cada `CACHE_RELLENO_MIN_MS` (400 ms) y solo mientras se usa; si había cambios mientras se veían las mallas, se rehace al volver a alejar (hasta entonces no se muestra).
- Con la vista de Relieve o con la capa «relleno» apagada desde el Debug, no se ve ni la imagen ni las mallas (igual que antes). `cache_rel_hechas` cuenta cuántas veces se rehízo (para pruebas).
- Comprobado: la imagen y las mallas dan el mismo dibujo (diferencia: ~0,09 % de píxeles, todos de borde, a zoom 0,8 y 1,2; `herramientas`/capturas del 2026-11-09).
- **Ojo en las pruebas sin pantalla (`--headless`)**: la ventana mide 64×64 y la escala de `_zoom_real()` es 0,05, así que la imagen estaría siempre activa; `runner81` fija la ventana en 1280×720 antes de probar.

### Medidas (render por software con xvfb, 2 pasadas; solo para comparar, no son FPS reales)
| Encuadre | 0.1.8.38 | 0.1.8.39 |
|---|---|---|
| Mundo entero | 113,5 / 115,7 ms · 533.600 triángulos · 396 dibujos | 61,3 / 61,2 ms · 119.459 triángulos · 357 dibujos |
| Europa (zoom bajo) | 110,0 / 103,1 ms · 400.244 triángulos | 56,8 / 59,8 ms · 54.225 triángulos |
| Roma de cerca | 73,9 / 74,7 ms | 82,6 / 73,3 ms (sin cambio: ahí no se usa la imagen) |
| 40 pasos de zoom + arrastre | 102,0 / 95,5 ms por paso | 82,3 / 82,7 ms por paso |
| Simular 1 día con 249 IA | 6,8 / 5,8 ms | 6,7 / 6,2 ms |

Los scripts nunca fueron el problema (`_actualizar_zoom` ≈ 0,1–0,4 ms, `_process` ≈ 0,1 ms; `runner90`): lo que cuesta es el dibujo. Por eso el grabador (siguiente sección) trae las columnas de dibujo.

## 2. Grabador de rendimiento (`scripts/grabador_rendimiento.gd`)
- **F9** enciende y apaga la grabación (también el botón de Debug > Rendimiento); **F8** pone una marca. Mientras graba, el contador de FPS de la barra dice «● REC».
- Una fila por fotograma en `user://rendimiento/rend_AAAAMMDD_HHMMSS.csv` (en Windows: `%APPDATA%\Godot\app_userdata\Gran Estrategia (…)\rendimiento\`; el botón «Abrir la carpeta de grabaciones» la abre).
  Columnas: `t_s, dt_ms, proceso_ms, render_cpu_ms, render_gpu_ms, draws, tri, objetos, mem_video_mb, mem_tex_mb, zoom, cam_x, cam_y, vista, foco, velocidad, ms_zoom, ms_scripts_mapa, ms_ciudades, ms_tropas, marca`.
  `render_cpu_ms` y `render_gpu_ms` salen de `RenderingServer.viewport_get_measured_render_time_*` (si el equipo no los da, quedan en 0).
- Al detener: escribe `…_resumen.txt` y lo copia al portapapeles. El resumen trae el equipo (GPU, API, sistema, ventana, calidad, MSAA, VSync, tope de FPS), FPS medios, mediana / p95 / p99 / peor duración de fotograma, cuántos pasaron de 25 ms y de 50 ms,
  una tabla por **vista y nivel de zoom** (fotogramas, ms medio, p95, peor), los **12 peores fotogramas** (segundo, duración, zoom, vista, dibujos, triángulos) y las marcas con su contexto.
- El CSV se vuelca al disco cada 2 s (si el juego se cierra mal no se pierde todo) y se detiene solo a la hora de grabación (216.000 filas).
- Pasos para Camilo: F9 → hacer zoom in y zoom out por donde se ponga mal (con F8 para marcar momentos) → F9 → pegar el resumen en el chat (y, si quiere, mandar el CSV).

## 3. Vista Internacional quitada
- Fuera: la variable `vista`, `_cambiar_vista`, `_aplicar_vista`, `_tiene_estados`, las listas `foco_lineas_prov` / `foco_lineas_estado` (solo servían para esconder líneas en la vista Internacional) y la entrada «Internacional» del menú VISTA (`hud.gd: VISTAS`).
- **V** y el botón de lentes alternan **Tradicional ↔ Relieve** (`_elegir_vista`). La línea de ayuda y la ficha del botón ya no hablan de la vista internacional.
- Siguen igual los estados / condados: nombres de estado que ceden ante los de condado, migas con estado, la tarjeta del estado al elegirlo en las migas (`_seleccion_estado`). Doble clic en una provincia acerca a esa provincia (antes, en Internacional, al estado entero).
- La ficha del país ya no pone «(vista internacional)» / «(vista tradicional)» junto a los conteos de estados y provincias.
- `runner79` y `runner75` adaptadas.

## 4. Nombres legibles en Relieve (`CapaTexto` en `MapaPrincipal.gd`)
- Antes: letra con el color de su país (pensado para el relleno) y halo suave → sobre el terreno claro apenas se leían (FRANCIA, UCRANIA, TURQUÍA).
- Ahora, con Relieve: letra **blanca cálida**, en **negrita** (`FontVariation`, `RELIEVE_NEGRITA_TEXTO` = 0,8; la crea `_aplicar_capas_relieve` una sola vez) y halo **casi opaco** (alfa 0,94). El grosor del halo sube en pasos fijos para los nombres chicos
  (`_factor_halo`: ×1 / 1,4 / 2 / 2,8 según la escala de la letra; pocos tamaños = pocas variantes en la caché de glifos), porque en los países pequeños el halo medía menos de un píxel.
- Sin Relieve no cambia nada. Además `_draw` ya no dibuja las letras ocultas (alfa 0), que antes seguían pidiendo llamadas de dibujo.

## 5. Lista de la CAMPAÑA siempre de 2026
- **Causa**: `_mostrar_campana` leía `mundo.paises_de_campana()` del mundo CARGADO; si venías del escenario del año 1 d. C. (o de un viaje en el tiempo) el menú listaba pueblos antiguos, y al COMENZAR se recargaba en 2026.
- **Arreglo**: `datos/campana_2026.json` (51 países: Europa + Rusia y Turquía) lo genera `herramientas/construir_campana_2026.py` con la misma regla que `Mundo.paises_de_campana()`; el menú lo lee con `_paises_campana_2026()` (ruta directa, no depende del escenario cargado; sin archivo cae al mundo cargado).
  `runner81` comprueba que el archivo coincide con lo que da el mundo de 2026 (si se regeneran entidades o provincias hay que volver a correr el script) y `runner75` que, con el mundo del año 1 cargado, la lista sigue siendo la de 2026.
- `_on_jugar` ya no falla si el menú ya se había liberado (solo ocurría al arrancar dos partidas seguidas sin recargar, como hacían las pruebas).

## 6. Pruebas
- **`runner81`** (nueva): vista Internacional quitada (menú, V, botón, ayuda, funciones), lista de campaña (51, nombres, archivo = mundo), nombres en Relieve (contorno, negrita, pasos del halo), imagen guardada del relleno (SubViewport y 3 copias, 4 instancias por tesela, cuándo se usa y cuándo no,
  histéresis, se rehace al cambiar un dueño, Relieve, capa apagada) y grabador (F9, CSV con cabecera y columnas, vistas, marca, resumen, portapapeles, botón del Debug).
- `runner90` (banco de zoom) ahora incluye la **campaña de Europa con el tiempo corriendo** (sin y con Relieve) y el coste de redibujar ciudades y tropas por paso.
- Regresión completa: ver `CHECKLIST_TESTING.md`.

## 7. Qué NO cambia / pendiente
- El Relieve sigue pixelado de cerca: lo resuelve la versión de relieve por teselas (más adelante, cuando Camilo lo pida).
- Con el mapa de cerca (Roma, zoom ≥ 2) siguen dibujándose las mallas del relleno (~230 mil triángulos): la imagen guardada solo cubre el mundo entero. Si el grabador muestra que ahí se atasca, el siguiente paso sería una imagen por teselas.
- Los cambios del HUD principal que Camilo pidió están en el plan de la 0.1.8.40 (HUD de provincia, Construir, órdenes de grupo): Camilo confirmó que ya estaban en ese plan, no hace falta repetir la lista.
