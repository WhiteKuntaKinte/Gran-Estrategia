# Notas técnicas 0.1.8 — overhaul del HUD (país con pestañas, tropas adentro, Diplomacia), selección múltiple, fronteras transparentes

## Qué es esta versión
Siete pedidos de Camilo, todos hechos:
1. Línea de frontera entre países: NEGRA con franjas TRANSPARENTES (por los huecos se ve el color del país).
2. Ctrl + clic izquierdo = selección múltiple de tropas (como el explorador de archivos).
3. Disolver una tropa ya NO pide confirmación. (Interpretación: «ese doble check es necesario» = «innecesario». Si era al revés, es un `AcceptDialog` en `_on_disolver`.)
4. La etiqueta de tropas (el rectángulo con la cantidad) va por encima de TODO lo que se dibuja en el mapa.
5. Pestaña nueva **Diplomacia** en el HUD de país: guerras abiertas y pasadas, tropas cruzadas, aliados/vasallos (gancho vacío), vecinos por tierra.
6. Overhaul del HUD: azul acero más oscuro y apagado, tipografía Inter, país con pestañas (General · Diplomacia · Militar · Política · Economía), el manejo
   de tropas vive DENTRO de la pestaña Militar y la ventana flotante de ejército desaparece.
7. Versión 0.1.8.

## HUD de país (`scripts/hud.gd`, reescrito)
- Estructura vertical: **cabecera** (bandera + nombre + cerrar) → **migas** → **fila de pestañas** (`PESTANAS`) → **marco de sección** (barra de título, sub-pestañas de
  Militar `SUBS_MILITAR` = Resumen / Regimientos / Reclutar / Batallas, cuerpo con scroll).
- `pestanas_de(tipo)`: mar → [general]; continente → [general, militar, economia]; país → las 5; estado/provincia/ciudad → [general, militar, politica, economia].
- API pública: `mostrar(d)`, `abrir_pestana(clave)`, `abrir_militar(sub)`, `tiene_ctx()`, `refrescar_ejercito()`, `actualizar_fin`, `ocultar()`; variables `pestana`, `sub_militar`,
  `tropas`, `scroll_cuerpo`. Señales: `cerrar_pedido, miga_pedida, vista_pedida, pausa_pedida, atras_pedido, velocidad_pedida, jugador_pedido, dinero_pedido, debug_pedido,
  personalizar_pedido`. La señal vieja `ordenes_pedido` ya no existe.
- Barra superior: clic en el nombre/bandera de tu país → `jugador_pedido` → `MapaPrincipal._on_jugador_pedido` selecciona el país y llama `hud.abrir_pestana("general")`;
  clic en el dinero → `dinero_pedido` → pestaña Economía.
- El diccionario de datos que recibe `mostrar(d)` lleva `d["ctx"] = {pais_tid, prov_tid, pais_nombre}` (lo arma `MapaPrincipal._ctx_tropas()`); sin ctx no hay manejo de tropas.
- Altura del cuerpo: `_alto_max = clampf(viewport.y - 365, 230, 640)`; `_ajustar_alto()` la adapta al contenido (espera un fotograma) en las pestañas que no son de tropas.
- La línea de ayuda de abajo ocupa todo el ancho (autowrap, 2 líneas) para que no se corte en el borde de la pantalla.

## Tropas dentro del HUD (`scripts/hud_tropas.gd`, antes ventana flotante)
- Ahora es un `Node` que dibuja en el contenedor de la pestaña Militar: `construir(main, fuente, fuente_neg, contenedor)`.
- Lista de regimientos en su propio `ScrollContainer` (112 px) para que las órdenes siempre queden a la vista; `_revelar_ordenes()` desplaza el HUD a las órdenes tras un clic en el mapa.
- **Selección múltiple**: `sel_reg` (el principal) + `sel_multi` (todos los elegidos). `alternar_reg(rid, desde_mapa := false)` = Ctrl+clic. En modo múltiple los elegidos salen
  arriba en la lista; si uno está en otra provincia se activa `filtro_todos` (lista de todo el país). `grupo()` devuelve los regimientos de la orden; `es_multiple()`.
  Mover/Dividir/Unir/Disolver/Detener trabajan sobre el grupo. `limpiar_seleccion()` la vacía al cerrar el HUD o cambiar de selección.
- `_on_disolver` ya no pide confirmación (ni individual ni en grupo).
- `lbl_precio` (precio de la unidad) solo se ve en la página Reclutar.

## Mapa: selección múltiple y órdenes de grupo (`MapaPrincipal.gd`)
- `_clic_tropas`: con Ctrl pulsado (`_ctrl_pulsado()`, `Input.is_key_pressed`) y el panel de regimientos abierto → `hud.tropas.alternar_reg(rid, true)`.
- `iniciar_destino_grupo(grupo)`, `_clic_derecho` (si hay selección múltiple manda el grupo), `_ordenar_grupo`, `_mandar_grupo`; al soltar un arrastre, si el cuadro arrastrado está
  en `sel_multi`, se manda todo el grupo.
- `abrir_ordenes(prov_tid, pais_tid := -1, reg := -1)` ahora abre el PAÍS dueño de esas tropas (si el HUD no está ya abierto con ctx) y luego la pestaña Militar > Regimientos.
  `panel_ordenes` es una propiedad que devuelve `hud.tropas` (compatibilidad con código viejo).
- Datos nuevos para el HUD: `diplomacia_vista()` (guerras con rival/rol/causa/fechas/bajas, `extranjeros_aqui`, `propias_afuera`, `relacionados`, `vecinos` por tierra con
  número de tramos y si hay guerra, `puede_ordenar`), `politica_vista()` (jefe de Estado a la fecha), `_fecha_txt`, `_pais_de_seleccion`, `hud_aviso`.
- Diplomacia no crea un sistema nuevo: lee `mundo.guerra` (guerras/paz) y `mundo.relacionados_de(pais)` (gancho vacío para aliados y vasallos).

## Etiquetas de tropas por encima de todo (`scripts/capa_tropas.gd`)
- Los cuadros ya no son hijos de la capa de dibujo: son dos `Node2D` propios (`CapaCajasPilas`, `CapaCajasMarchas`) con `z_index` 200 y 201 bajo la capa de tropas (z 14) → z efectivo
  214 y 215. Lo más alto del resto del mapa es 20 (líneas doradas, nombres, etc.), así que NADA se dibuja sobre un cuadro. `runner28` lo comprueba.
- `sel_regs` resalta con marco dorado todos los regimientos de la selección múltiple.

## Fronteras con franjas transparentes (`MapaPrincipal.gd`)
- Shader `SHADER_BORDE_FRANJA_ABIERTA`: tramos NEGROS y huecos con alfa 0 a lo largo de la línea (misma distancia por vértice de `malla_par_c.bin`), así por los huecos asoma el color del país.
  `NEGRO_FRONTERA` = 0,60 (proporción de negro), `PERIODO_FRONTERA_PX` = 8 px, grosor 2,6 px. Costas y contorno de continentes siguen negros sólidos (2,8 px / 1,8 px).
- No cambió ningún archivo de datos de mapa.

## Tema y tipografía (`scripts/tema_hud.gd`, `fuentes/`)
- `Tema` (clase `TemaHud`): paleta azul acero (más oscuro y apagado, algo metálico), `EstiloMetal` (StyleBox con degradado vertical, esquinas cortadas y un brillo arriba),
  `panel()`, `cabecera()`, `boton(estado)`, `tarjeta()`, `caja()`, `crear_tema(fuente, fuente_neg)` (arma el `Theme` completo; lo usan el HUD, el menú principal y el de pausa).
- Fuente **Inter** (SIL Open Font License 1.1: `fuentes/LICENCIA_Inter.txt`): `Inter-Regular.otf` y `Inter-SemiBold.otf`. La carga `MapaPrincipal._cargar_fuente_ui` en `fuente_ui` / `fuente_ui_neg`.
- Los HSlider recibieron márgenes de 4 px en pista y zona de agarre (`_pista()`); antes quedaban invisibles con el nuevo estilo.
- `scripts/ventana_flotante.gd` (Debug, Mi país…) usa el mismo tema. Icono nuevo `iconos/i_dipl.png` (Diplomacia).

## Pruebas
- `runner27` — humo del HUD: pestañas por tipo, clic en el nombre → General, clic en el dinero → Economía, capturas.
- `runner28` — 22 comprobaciones: Ctrl+clic en cuadros del mapa, grupo, mover grupo, disolver sin confirmación (ningún `AcceptDialog` / `ConfirmationDialog` en el árbol), orden de capas de los cuadros.
- `runner25` portado a la API nueva (Militar dentro del HUD, Diplomacia con «Firmar la paz»).
- `runner26` (grosores y franjas por vértice) sigue pasando; que los huecos sean transparentes se revisó a ojo en las capturas (no hay comprobación automática del alfa). `runner6` / `runner7` verifican `VERSION == "0.1.8"`.
- Todo corre en el servidor (Godot 4.3, sin GPU). NO se jugó a mano ni en el PC de Camilo.

## Pendiente / ideas
- Rango con Shift (como en el explorador) y rectángulo de selección: no hechos (solo Ctrl).
- Política: de momento solo muestra el jefe de Estado conocido a la fecha; falta todo lo demás.
- Aliados y vasallos: el gancho `relacionados_de` sigue vacío.
- Estilo de líneas de provincia / estado / costura: Camilo todavía no mandó la especificación.
