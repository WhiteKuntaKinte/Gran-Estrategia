# Notas técnicas 0.1.7.9.9B

## Estado de pruebas (sé honesto contigo mismo)
- Probado con Godot 4.3 headless/xvfb y render por software (llvmpipe). Guion `runner6` con **clics simulados** (InputEvent de ratón
  por el sistema de GUI, no llamadas directas): clic en nombre y bandera del país, en el dinero, en la fecha, en velocidad 5, clic
  fuera para cerrar la ventanita, teclas 3/6/Espacio/F1, botón del bicho, clic en el mapa con el Debug abierto, arrastre y
  encogido de la ventana, lápiz de «Mi país» y sus cambios. 48 comprobaciones, 0 fallos, capturas revisadas a mano.
- Base de datos: `runner5` (IDs, cadena de padres, agregados, historial por cambio / mensual / anual, propietario, desarrollo):
  el ingreso diario de Colombia da el mismo valor que antes de migrar (1.086.888.023.568 COP).
- Velocidades medidas con llvmpipe (no son FPS reales): vel 5 ≈ 85 días/s, vel 6 ≈ 252 días/s con el panel de economía abierto.
- Contadores del renderizador (no son FPS; mismas escenas que 0.1.7.9.1): triángulos iguales (mundo zoom 2: 171.868; EE. UU. zoom 3: 184.904);
  llamadas de dibujo 115 -> 130 en el mundo zoom 2 (barra superior más rica, botón del bicho y lápiz). Con una ventana flotante abierta suma unas 40-60 más.
- NO probado: tu PC, Windows, partidas largas (memoria del historial), jugar a mano.

## Barra superior (`scripts/hud.gd`)
- `_hacer_clicable(control, accion, tooltip)`: el contenedor y sus hijos ignoran el ratón y el contenedor atrapa el clic izquierdo.
  Señales nuevas: `jugador_pedido`, `dinero_pedido`, `debug_pedido`, `personalizar_pedido`.
- `MapaPrincipal._on_jugador_pedido` -> `_ir_a_pais(pais)` = `_enfocar_pais` (pop-out + cámara) + `_seleccion_pais` (igual que doble clic
  en el mapa). `_on_dinero_pedido` hace lo mismo y luego `hud.abrir_pestana("economia")`.
- Fecha: `lbl_fecha` abre `popup_vel` (velocidades 4-6, `botones_vel_extra`). Se cierra al elegir, al pulsar la fecha otra vez o al
  pulsar fuera (`HUD._input`, no consume el clic). Con velocidad >= 4 la fecha se tiñe de naranja.
- Todos los botones del HUD usan `FOCUS_NONE`; `_sin_foco()` se vuelve a pasar a los paneles que se redibujan. Así Espacio / 1-6 / V
  siguen llegando a `_unhandled_input` y no activan botones.
- Economía de tu país: `MapaPrincipal._fin_pais(pais)` -> filas `[título, valor, icono, clave]`; `_fin_detalles(pais)` -> `{clave: {icono, titulo, bb, barras}}`.
  El HUD las dibuja (`_tab_economia`, `_detalle_fin`). `_refrescar_fin_panel()` (cada 0,4 s reales mientras pasan días) llama
  `hud.actualizar_fin()` que redibuja sin perder el scroll ni el detalle abierto.

## Reloj (`scripts/reloj.gd`)
- `SEG_POR_DIA = [0, 1, 0.4, 0.12, 0.04, 0.012, 0.004]`, `VEL_MAX = 6`, máximo 40 días por fotograma (si no se alcanza, se descarta el
  atraso para no dar saltos al bajar la velocidad). Teclas 4, 5, 6 en `_unhandled_input`.

## Overlay Debug (`scripts/debug_menu.gd` + `scripts/ventana_flotante.gd`)
- `ventana_flotante.gd`: CanvasLayer 25, raíz `MOUSE_FILTER_IGNORE`, ventana `STOP` (solo captura clics sobre ella), arrastre desde
  la barra de título, encoger/cerrar, `PROCESS_MODE_ALWAYS`. La usan Debug y «Mi país».
- `debug_menu.gd`: ya no es modal ni pausa. F1 / botón del bicho: `MapaPrincipal._alternar_debug()`. `seleccion_cambio(tipo)` lo llama
  `_enviar_hud` para seguir la selección del mapa. Cada cambio pasa por `_dbg()` (pone `bd.motivo_ctx = "Debug"`).
  Pestaña Datos = inspector: ID, cadena de IDs, variables con dato, historial de la variable elegida.
  Al pulsar fuera de la ventana se suelta el foco de los cuadros de texto (para que las teclas del juego vuelvan a funcionar).
- Las lambdas de GDScript copian las variables simples: los resultados que deben salir de una lambda se devuelven por una lista (`res[0]`).
- Menú de pausa > DEBUG: `_reanudar_juego()` + `_abrir_debug()`. `_volver_menu_principal()` cierra ambas ventanas.

## «Mi país» (`scripts/personalizar_pais.gd`)
- Nombre (`Pais.nombre_visible`), moneda (`Mundo.cambiar_divisa`: convierte la tesorería con `por_usd`; las fotos mensuales previas quedan
  en la moneda de entonces), impuestos (`tasa_fiscal`) y desarrollo (`velocidad_desarrollo`). Los deslizadores solo hacen vista previa;
  se aplica con botón para escribir UNA fila de historial por cambio (motivo «Personalización»). Registro de cambios = historial de las
  4 variables.

## Base de datos (`scripts/base_datos.gd`, `datos/ids.json`, `datos/variables.json`, `herramientas/construir_ids.py`)
- Territorios en columnas paralelas con índice denso; una `Variable` por columna (`PackedFloat64Array` / `PackedStringArray` /
  `PackedInt32Array`, NaN / "" / -1 = sin dato) y su `Hist` (`h_id`, `h_desde`, `h_hasta`, `h_f/h_s/h_i`, `h_motivo`, `por_id` = índice
  ID -> filas, para que consultar un historial no recorra todo).
- Políticas: `cambio`, `mensual`, `anual`, `ninguno`. `cerrar_periodo("mensual"/"anual")` lo llama `MapaPrincipal._on_dia`.
- API: `num/txt/ref/leer`, `poner_f/s/i`, `inicial_f/s/i` (carga sin historial), `heredado` (sube por la cadena de padres), `suma`,
  `media_ponderada`, `agregado`, `historial_de`, `descendientes`, `ruta`, `resumen`. Intentar escribir una variable en un tipo que
  no le aplica (p. ej. tesorería en una provincia) escribe un error en la consola y no hace nada.
- Cachés económicas: `version_eco` sube solo con variables `afecta_economia`.
- Desarrollo mensual (`Mundo.avanzar_mes`): `pib_pc *= (1 + crecimiento_base_anual × vel_provincia × vel_país_dueño)^(1/12)`.
  `crecimiento_base_anual = 0,02` es PROVISIONAL.
- Los IDs se conservan entre versiones: `construir_ids.py` lee el registro anterior y solo asigna IDs nuevos a lo nuevo.
- Costo de memoria: cada cierre anual añade ~22 mil filas (población + producción por habitante), unas 0,6 MB por año simulado.

## Diagramas (`herramientas/hacer_diagrama_bd.py`, carpeta `docs/`)
- General (Mermaid ER), variables (SVG propio -> PNG con Chromium) y jerarquía de IDs (Mermaid). Ver `docs/DIAGRAMA_BASE_DE_DATOS.md`.

## Pendiente
Guerra/asedio, vasallaje, gastos del estado y costo político de los impuestos, variables étnicas, árbol de investigación, idioma,
detalle de Francia (10 ciudades, carreteras), subir el proyecto a GitHub en una rama nueva (nunca main), quitar la duplicación
info.json <-> base de datos (altitud, bioma), fronteras del mapa tras una anexión.

## Herramientas (orden de ejecución)
preparar_banderas.py -> construir_mapa.py -> construir_info.py -> construir_entidades.py -> anadir_color_foco.py ->
construir_divisas.py (argumento: CSV de PIB) -> construir_ids.py ; hacer_iconos_extra.py genera los iconos nuevos ;
hacer_diagrama_bd.py regenera los diagramas.
