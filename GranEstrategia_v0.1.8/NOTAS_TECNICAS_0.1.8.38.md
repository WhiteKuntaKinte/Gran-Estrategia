# Notas técnicas 0.1.8.38 — HUD y ventanas (1.ª parte): Debug en cuadrícula, ventanas y panel movibles y redimensionables, tarjetas, avisos y fichas

## Qué es esta versión
La 0.1.8.38 del plan «HUD y ventanas» se entrega **en dos partes** (así quedó acordado con Camilo). Esta es la **primera**:

- **Debug en cuadrícula** con migas «Menú Debug › Sección».
- **Ventanas flotantes** (Debug, Mi país, Ranking) que se redimensionan desde cualquier borde o esquina y recuerdan su sitio y tamaño.
- **Panel del país** movible y redimensionable.
- **Tarjetas**: cada sección del panel es un bloque con marco que se reparte en 1, 2 o 3 columnas según el ancho.
- **Avisos apilados** arriba a la derecha.
- **Fichas** (tooltips con título, detalle y atajo).

**Va en la 0.1.8.38b** (siguiente): HUD de provincia (Edificios / dos Cores / Ingreso / Población), ventana Construir con los 109 edificios (cuesta dinero y tarda días, se guarda por provincia, sin efectos todavía),
totales y órdenes de grupo con Ctrl+clic. **0.1.8.39**: imágenes (pinturas por carpeta y nombre, banderas, iconos de materias primas y divisas en HD, iconos y migas rediseñados).

## 1. Debug en cuadrícula (`scripts/debug_menu.gd`)
- Al abrir F1 sale una **cuadrícula de tarjetas** (una por sección: Jugador, IA, Anexar, Provincia, Tiempo, Mundo, Datos, Historia, Ejército, Descub., Rend.). `SECCIONES` lleva clave, título, icono y descripción.
- Al entrar a una sección, una fila de **migas** arriba muestra `← Menú Debug › Sección` (`_dibujar_migas`). `←` y «Menú Debug» vuelven a la cuadrícula (`_ir_menu`); `_ir_a(clave)` abre una sección.
- Los textos del Debug usan **roles del tema** (`Tema.rotular`), así que cambian de color solos con los tres temas. `aplicar_tema()` repinta ventana, tarjetas y migas en vivo (`MapaPrincipal._aplicar_tema` lo llama si el Debug está abierto).
- `tema_hud.gd` ahora estiliza también `ItemList`, `CheckBox` y `CheckButton` (el Debug era ilegible con el tema A).

## 2. Ventanas flotantes (`scripts/ventana_flotante.gd`)
- **Bordes**: el margen del marco agarra el borde (8 px, `BORDE_AGARRE`); el cursor cambia según el borde o esquina. `arrastrar_borde(b, rel)` mueve los bordes elegidos; izquierdo y superior corren la ventana para que el contrario no se mueva.
  Nunca baja de `TAM_MIN` ni se sale de la pantalla. `cambiar_tam` recibe ahora un `tope` opcional: arrastrando el borde izquierdo, el máximo es hasta el borde derecho actual (antes no dejaba crecer hacia la izquierda si la ventana estaba pegada a la derecha).
- **Memoria**: cada ventana lleva una `clave` («debug», «mipais», «ranking»); al cerrarse (`_exit_tree`) guarda `[posición, tamaño]` en `MapaPrincipal.geo_ventanas` y al abrirse otra vez aparece ahí. Dura lo que la sesión del juego (no se escribe a disco).
- Repinta con el tema (`aplicar_tema`).

## 3. Panel del país (`scripts/hud.gd`)
- **Mover**: arrastrar la **cabecera** (`cab_marco`, `_on_cab_input` → `mover_panel`). El panel siempre queda parcialmente a la vista (120 px) y nunca sube sobre la barra. **Doble clic** en la cabecera = `volver_panel()` (sitio, ancho y alto de siempre).
- **Redimensionar**: bordes izquierdo, derecho y de abajo (`_borde_panel_en`, `arrastrar_borde_panel`). Ancho: de 320 px (`ANCHO_PANEL_USUARIO_MIN`) a la pantalla menos 16. Alto: lo que se estira es el alto máximo de la sección con scroll (`_alto_max`, mínimo 150),
  limitado para que el panel no se salga por abajo. El borde de abajo no se agarra en modo compacto (el alto de arriba lo da el contenido).
- **Memoria**: `_guardar_geo_panel()` al soltar guarda en `geo_ventanas["panel_pais"]`; `construir()` lo lee (se corrige si no cabe en la pantalla) para que el panel abra donde lo dejaste, también en otra partida.
- Si no se ha movido, `set_campana()` sigue poniendo el panel bajo la barra (comportamiento 0.1.8.37). Movido: no lo toca.
- **Panel de detalle** (`panel_det`): va pegado a la derecha del principal (`_acomodar_det`); si ya no cabe, pasa a su izquierda.

## 4. Tarjetas (`hud.gd`)
- `_seccion()` ahora devuelve el contenido de una **tarjeta** (`PanelContainer` con marco, `Tema.caja(BLOQUE_SUAVE…)`) en vez de un bloque suelto. Sigue siendo plegable.
- Cada tarjeta se pone al dibujarse (`_poner_tarjeta`, desde `_seccion`): con 1 columna, debajo de las demás (como antes); con 2 o 3 (`_columnas_tarjetas`: una columna por cada 340 px de ancho, `ANCHO_TARJETA`), en la columna más baja en ese momento.
  `_acomodar_tarjetas()` solo corre cuando el jugador cambia el ancho y cambia el número de columnas (vuelve a repartir las tarjetas guardadas en `_items_cuerpo`). Con el ancho normal (372–420 px) todo queda igual que antes.

## 5. Avisos apilados (`scripts/avisos.gd`, nuevo)
- `main.aviso(texto, nivel)`; niveles `info`, `ok`, `aviso`, `mal` (borde y franja de su color: azul acero, verde, naranja, rojo). Arriba a la derecha bajo la barra, capa 26; el más nuevo, abajo.
- Duran 4,5 / 4,5 / 6 / 8 s y se desvanecen 0,6 s. El **mismo texto seguido** suma «×N» y reinicia el tiempo. Máximo **5** (se va el más viejo). Con el ratón encima no corre el tiempo; un clic lo quita. Funcionan con el juego en pausa (`PROCESS_MODE_ALWAYS`).
- Se vacían al empezar una partida y al volver al menú principal.
- **Lo que antes pisaba la línea de ayuda de abajo** (órdenes de mover tropas: «eso es mar», «no estás en guerra con…», «no son tuyas», «ya van en marcha», orden dada; «aún no controlas ningún país»; avisos de guerra y paz del HUD y del popup) **ahora sale como aviso**.
  La línea de ayuda queda solo para la ayuda del modo (mover tropas, provincias de un país, etc.), así el mensaje de «Esc cancela» no se pierde.

## 6. Fichas (`scripts/fichas.gd`, nuevo)
- Sustituyen al tooltip nativo de Godot para **todo** control con `tooltip_text` (no hay que registrar nada; sirve también para las ventanas futuras). Un detector por fotograma (`Viewport.gui_get_hovered_control`) espera 0,45 s con el ratón quieto
  (0,12 s si ya había una ficha y pasas a otro control) y muestra una tarjeta junto al puntero, sin salirse de la pantalla; se va al salir, al hacer clic o al cambiar de control.
- Formato del texto: una línea corta (≤ 30 letras) → título; una línea larga → detalle; varias líneas → la primera es el **título** (negrita, color de acento), el resto **detalle**, y una línea «Atajo: X» sale aparte, tenue. Un control puede llevar `set_meta("ficha", Callable)` para una ficha con datos al día.
- El tooltip nativo se apaga con `gui/timers/tooltip_delay_sec=3600` en `project.godot` (la vista raíz lo lee al arrancar; no se puede cambiar en marcha). Si no se hiciera, saldrían los dos.
- Los tooltips de la barra y la cabecera se reescribieron en este formato (Menú Debug, Ranking, Mi país, Fecha, Vista del mapa, Encoger panel, Mover el panel). Los demás (pestañas, botones de guerra, tropas…) salen como ficha con su texto de siempre.
- Se repintan con el tema en vivo.

## 7. Pruebas y revisiones
- **`runner80` (nuevo, 128 comprobaciones)**: panel (mover con topes, bordes, ancho/alto con mínimos y máximos, detalle pegado, volver, doble clic, arrastre simulado de la cabecera), tarjetas (columnas por ancho, todas las tarjetas en el árbol en cada pestaña),
  memoria del panel (HUD nuevo lo restaura; geometría absurda se corrige), avisos (apilado, ×N, máximo, clic, hover, tema, desvanecido real de 5 s), fichas (formato, tamaño, posición, esquina, apagadas), Debug (las 11 secciones y sus migas, tema) y ventanas (bordes, memoria de Debug y Mi país).
- `runner73`: los mensajes de órdenes ahora se comprueban en `main.avisos.ultimo_texto` (antes en la línea de ayuda). `runner74`: versión 0.1.8.38.
- Se encontró y corrigió con esas pruebas: arrastrar el borde izquierdo de una ventana pegada a la derecha no la dejaba crecer (límite mal calculado).
- **Auditoría** (`herramientas/auditar_codigo.py`): 0 funciones y 0 variables repetidas; 0 sin uso; `datos/variables.json` sin cambios. (El auditor marca `debug_menu.aplicar_tema` como «recursión directa» por llamar a `vf.aplicar_tema`, que es otra clase con el mismo nombre: no es recursión.)
- **Rendimiento**: ver sección 8.

## 8. Rendimiento
Medido contra la 0.1.8.37a con los mismos datos (dos pasadas cada una):
- `runner89` (dibujo por software, ms por fotograma en 2026): mundo 104–115 frente a 107–111, Europa 102–104 frente a 105–107, Roma 73 frente a 73–75; 40 pasos de zoom+arrastre 93–95 ms frente a 91–96; simular 1 día con 249 IA 6,7–7,0 ms frente a 6,4–6,7; `_process` 0,08 ms igual; triángulos y llamadas de dibujo iguales; arranque igual; memoria 307 frente a 306 MB; +12 nodos (avisos, fichas). Todo dentro del ruido.
- `runner90` (banco de zoom, headless): **6,9 ms por fotograma en todos los casos**, igual que la 0.1.8.37a (el panel nuevo no toca `_actualizar_zoom`). `_actualizar_zoom` 0,05–0,13 ms.
- **Se encontró y corrigió un costo real**: la primera versión de las tarjetas movía todas las tarjetas de sitio (`remove_child` + `add_child`) al final de cada `_dibujar()`; redibujar el panel del país pasó de 31 a 51 ms. Ahora cada tarjeta se pone directo donde va (`_poner_tarjeta`: debajo de las demás con 1 columna; en la columna más baja con 2 o 3) y solo se reacomodan nodos cuando el jugador cambia el ancho. Resultado: 31–32 ms por `_dibujar()` (20 redibujos medidos) con 1 y con 2 columnas, igual que la 0.1.8.37a (30–34 ms). Elegir 5 países seguidos: 172–192 ms contra 180–198 de la 0.1.8.37a.
- Las fichas hacen una comprobación por fotograma (`gui_get_hovered_control`, O(1)) y los avisos no hacen nada por fotograma (solo tweens mientras están a la vista).

## 9. Lo que NO hace todavía
- HUD de provincia (Edificios, dos Cores, Ingreso, Población), ventana Construir, totales y órdenes de grupo con Ctrl+clic: **0.1.8.38b**.
- El panel de detalle y las ventanas no se guardan a disco entre ejecuciones (solo durante la sesión).
- Imágenes, banderas e iconos HD: 0.1.8.39. Filtro sepia del tema A y tarjetas con pergamino del C: pendiente. Vistas Clima / Población / Economía / Cultura: «próximamente».
- No se probó con tarjeta gráfica ni pantalla real: cómo se siente arrastrar y redimensionar, los cursores de borde y la legibilidad de las fichas en tu PC.
