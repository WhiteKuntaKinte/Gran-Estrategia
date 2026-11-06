# Notas técnicas 0.1.8.2a — ejércitos iniciales concentrados, rutas rediseñadas, avisos de guerra, negociación de paz, colores, provincias con un clic y rendimiento

## Qué es esta versión
Pedido de Camilo (mensaje del 2 de noviembre, 03:03), más dos ajustes que dijo después (informe completo, líneas aún más finas y sin contorno):
1. **Sin tropas en muchas provincias al empezar**: cada país arranca con todo su ejército junto, en la capital.
2. **Selección múltiple en provincias distintas**: arreglar que las tropas «se muevan solas».
3. **Mejores rutas por islas.**
4. **Rutas rediseñadas**: un color por columna, finas, flechas del mismo color incrustadas, y haces tipo mapa de metro cuando varias columnas comparten camino.
5. **Aviso cuando te declaran la guerra** (con tiempo de reacción) y tiempos legibles.
6. **FPS** cuando muchas tropas van al mismo punto.
7. **Aviso de fin de guerra** con negociación: solo dos opciones, provincias y dinero, combinables.
8. **El rendimiento empeoraba al subir la velocidad** + revisión de rendimiento de todo el proyecto.
9. **Colores**: campaña = identidad fija por país; dev = tono propio dentro del color del continente, más oscuro cerca del ecuador, sin degradado.
10. **Provincias visibles**: campaña sin doble clic; dev con un clic; las de los países vecinos solo con contorno, sin nombre.
Todos los números nuevos son **PROVISIONALES** y están como constantes al principio de cada archivo.

## 1. Ejércitos iniciales (`scripts/ejercito.gd`, `_repartir_pais`)
Antes cada país arrancaba con un regimiento por provincia (decenas en países grandes). Ahora todo el ejército de un país nace en su **capital** (si no hay capital marcada, la provincia más poblada) como pelotones de `TAM_PELOTON`
más el resto (si el resto es ≥ 50). Cada país empieza con **un solo regimiento**. La IA ya enviaba «solo lo necesario» desde 0.1.8.2; con el reparto nuevo parte de un punto. Se ajustaron los runners 9, 17, 24, 25, 28 y 30 que suponían el reparto viejo.

## 2. Selección múltiple que «se movía sola» (`MapaPrincipal.gd`)
Dos causas, las dos corregidas:
- **Ctrl + clic arrastraba el grupo** si el ratón se movía un poco entre pulsar y soltar (un roce mandaba a todos los elegidos). Ahora Ctrl + clic solo elige o quita y nunca inicia un arrastre (`_ctrl_pulsado()`).
- **Soltar en la misma provincia de salida** mandaba al resto del grupo a esa provincia (el primero no se movía, los demás sí, desde otras provincias). Ahora soltar en la provincia de origen no hace nada.
- Además un **clic derecho largo** (más de `CLIC_DER_MAX_MS = 350`) se trata como mover la cámara, no como orden de marcha.
Prueba: `runner28` (cajas de varias provincias elegidas a la vez; 22/22) y `runner17`.

## 3. Rutas por islas (`herramientas/construir_vecinos.py`, `datos/vecinos_prov.json`)
Antes había solo 2 enlaces marítimos por cada par de masas de tierra: una isla pegada a Eurasia tenía 2 en total y las tropas daban la vuelta por la costa hasta ese punto. Ahora, además de esos 2, **cada provincia costera se enlaza
por mar con su provincia más cercana de cada otra masa de tierra** (`MAR_K_POR_MASA = 1`). Enlaces marítimos: **917 → 4.725** (los de tierra siguen en 19.448). El mar sigue costando el doble (`FACTOR_MAR`), así que A* solo cruza el mar cuando conviene.
El archivo se regeneró con la herramienta (la versión del JSON dice 0.1.8.2a). Pruebas: `runner51` (diagnóstico de rutas de islas) y `runner58` (benchmark de rutas).

## 4. Rutas rediseñadas (`scripts/capa_tropas.gd`, `CapaMarchas` / `_construir_y_dibujar_rutas`)
- **Un color por columna** (`color_marcha(mid)`): el primer hueco libre de una paleta de 12 colores apagados (coral, naranja, amarillo, lima, verde, turquesa, azul cielo, índigo, violeta, rosa, arena, gris claro); pasada la primera vuelta, los mismos en tono oscuro y luego claro.
  El color se libera cuando la columna llega (`_limpiar_colores`). Las columnas enemigas visibles usan `COL_HOSTIL` (rojo).
- **Línea fina y de un solo color**: `CUERPO_PX = 3` píxeles de pantalla, **sin contorno negro** (Camilo lo pidió a las 03:21) y sin brillo.
- **Flechas**: misma velocidad y cantidad que antes, pero del color de su línea y **incrustadas en ella** (no más gruesas que la línea).
- **Haces tipo metro**: las columnas que comparten un tramo de camino no se amontonan; cada una ocupa un **carril paralelo** (`CARRIL_PX = 5,2` px entre carriles, `CARRIL_ANCHO_TOTAL = 48` como máximo), ordenadas por ID de columna,
  y al separarse o juntarse se unen con un pequeño codo.
- Se dibujan **todas las rutas del jugador** (no solo la seleccionada) y se limita la frecuencia de repintado a 25 Hz.

## 5. Avisos de guerra (`scripts/popup_guerra.gd` — nuevo; `scripts/guerra.gd`; `MapaPrincipal.gd`, «Avisos de guerra»)
- **«TE HAN DECLARADO LA GUERRA»**: pausa el tiempo y tapa el mapa con un velo hasta que respondes. Dice quién ataca, el motivo, la relación de fuerzas y **cuánto falta para el primer contacto**: en **días de juego** y en **segundos reales a la velocidad que llevabas**
  (`_contacto_estimado`: la columna enemiga más cercana que va hacia tus provincias o, si no hay ninguna en marcha, el regimiento enemigo más cercano a tu territorio). Botones: «REANUDAR (velocidad 1)» · «SEGUIR EN PAUSA».
- Los avisos nacen en `Guerra` (`mundo.avisos`) y la interfaz los saca de la cola (`_procesar_avisos`); un aviso viejo (la guerra ya no existe) se descarta.
- **Gracia inicial de la IA** (`scripts/ia.gd`): ninguna IA declara guerras en sus primeros `GRACIA_INICIAL = 120` días y **ninguna ataca al jugador** en sus primeros `GRACIA_JUGADOR = 240` días: da tiempo a orientarse. Para ver el pop-up en una partida real hay que dejar correr esos 8 meses de juego (velocidad 5 o 6); `runner53` lo dispara directamente.
- **La IA manda solo lo necesario** (`ENVIO_MARGEN = 1,35`, `ENVIO_MIN = 2.000`): al atacar envía 1,35 × lo que necesita y como mínimo 2.000 soldados, no el regimiento entero.
- **Tiempos legibles**: los plazos se muestran siempre en días de juego y en segundos reales a la velocidad actual (`SEG_POR_DIA` de `scripts/reloj.gd`).

## 6. Fin de guerra y negociación (`scripts/popup_guerra.gd`, `Guerra.evaluar_tratado` / `firmar_paz`)
Cuando una IA quiere cerrar la guerra con el jugador (`scripts/ia.gd`, `_paz`) ya no se impone: se abre un pop-up que explica el **motivo** (`victoria`, `ventaja`, `tablas`, `capitula` o `agotamiento`) y deja negociar con **solo dos monedas**. Si lo ignoras, el aviso vuelve a salir cada `AVISO_PAZ_DIAS` días:
- **Provincias** (casillas con las provincias que cedes) y **dinero** (campo numérico), **combinables**. Una casilla «conservar lo que ocupo» fija si cada bando se queda con lo que ocupa (`conserva_a` / `conserva_b`).
- El rival evalúa **en vivo**: una provincia «vale» lo que produce en 3 años (`ANIOS_VALOR_PROVINCIA = 3`); el rival exige (lo que va perdiendo − margen) × 3 años de producción × `FACTOR_EXIGENCIA`; la barra muestra ofrecido frente a exigido y el motivo si no alcanza.
- Botones: «FIRMAR LA PAZ» · «Cubrir lo que falta con dinero» (rellena el dinero que falta) · «SEGUIR EN GUERRA».
- `Guerra.firmar_paz` ahora aplica el tratado: cede provincias, paga el dinero, cierra batallas y retira tropas del territorio ajeno. Prueba: `runner53` (declaración contra el jugador y fin de guerra con tratado de provincias + dinero).

## 7. Colores de los países (`MapaPrincipal.gd`, «Esquemas de color de los países»; `scripts/fusion_mapa.gd`, `plano`)
- **Campaña**: tabla `COLORES_IDENTIDAD` con color fijo para 30 países conocidos; los demás toman de `PALETA_IDENTIDAD` el color que menos usan sus vecinos, en orden alfabético (siempre sale igual). Un país es siempre del mismo color en cada partida de campaña.
- **Dev**: cada país usa el color de su continente en un **tono propio y plano** (sin degradado); el tono es más oscuro cuanto más cerca del ecuador está el país (`col_hex_continente` guarda el color de continente de los datos como base).
- `FusionMapa.plano = true` ignora los colores horneados y pinta cada provincia con el color plano de su dueño; `repintar_todo()` obliga a repintar al cambiar de esquema.

## 8. Provincias visibles (`MapaPrincipal.gd`)
- **Un clic** elige el país **y** lo enfoca (antes era doble clic). La cámara solo se mueve si el país no está ya a la vista (`_foco_debe_mover`).
- **Campaña**: los contornos de provincia de **todos** los países se ven siempre (capa `capa_prov_todas`, suave, con desvanecido por zoom en `_actualizar_zoom`).
- **Vecinos**: al enfocar un país se dibuja el contorno (sin nombres) de las provincias de los países que lo tocan (`grupo_vecinos`, `_poblar_vecinos`; `FusionMapa.malla_aristas` con los modos nuevos «internas» y «conjunto», y `vecinos_de`).
- Prueba: `runner55`.
- Prueba de colores: `runner54`. Prueba de rutas con capturas: `runner52`.

## 9. Rendimiento (`reloj.gd`, `entidades.gd`, `ia.gd`, `guerra.gd`, `ejercito.gd`, `red_provincias.gd`, `MapaPrincipal.gd`, `capa_tropas.gd`)
Servidor sin GPU (render por software): sirve para **comparar antes/después**, no para predecir los FPS de tu PC. Medido en un día típico en plena campaña (≈ día 150–210, 389 columnas en marcha, 54 guerras abiertas entre 51 países):
| Parte del día de juego | antes (0.1.8.2) | después (0.1.8.2a) |
|---|---|---|
| IA | 82 ms | **29,4 ms** |
| guerra (batallas, ocupación) | 24 ms | 20,9 ms |
| economía | 7 ms | 6,0 ms |
| ejército (avance) | 6 ms | 5,6 ms |
| **total simulado por día** | **~115 ms** | **~62 ms** |
| `Ejercito.dividir_reg` (por llamada) | 4,4 ms | 0,7 ms |
| A* de una ruta | 0,2–0,7 ms | repetidas ≈ gratis (caché) |
| panel abierto (rehacer entero) | 52 ms cada vez | como mucho cada 0,9 s (2,5 s a velocidad ≥ 3) |
Qué se hizo y por qué:
1. **Día partido en fases** (`Mundo.fases_dia()`, `Reloj.al_dia_diferido`, `MapaPrincipal._on_dia_diferido` / `_correr_fases`): con el juego en marcha el día se simula **en pasos cortos repartidos entre fotogramas** con un presupuesto de `PRESUPUESTO_US = 9000` µs por fotograma
   (`DIAS_MAX_POR_FOTOGRAMA = 40`). Así un día caro (IA + guerra) ya no congela un fotograma entero: **los FPS se mantienen a costa de que el tiempo avance más lento que lo nominal en PCs flojos**, y a velocidades altas los días baratos se encadenan dentro del mismo fotograma.
   Esto responde a «el rendimiento empeora al subir la velocidad»: antes cada fotograma intentaba hacer N días de golpe. `avanzar_dia()` sigue existiendo y corre las fases seguidas (lo usan Debug y las pruebas).
2. **IA por lotes** (`Ia.fase_dia`, `LOTE_IA = 3`): cada paso deja decidir a 3 países como mucho. **Batallas por lotes** (`Guerra`, `LOTE_BATALLAS = 5`).
3. **`dividir_reg`** ordena con una clave entera nativa (int64) en vez de un `sort_custom` con callable (4,4 → 0,7 ms).
4. **Caché de rutas** (`RedProvincias._cache_rutas`, hasta `CACHE_RUTAS_MAX = 6000`): la IA pide cientos de veces las mismas rutas; la inversa se saca de la guardada con `reverse()`. Se vacía al cambiar la red (`leer`, `bloquear`).
5. **Refresco del panel limitado** (`_pedir_refresco_panel`, `PANEL_PERIODO_MS = 900`, `PANEL_PERIODO_ALTA_MS = 2500`): las guerras cambian ocupaciones varias veces por segundo y antes cada cambio rehacía el panel entero.
6. **Muchas tropas yendo al mismo punto** (el bajón de FPS que contaste): (a) la capa de rutas se rehace como mucho ~25 veces por segundo (`_t_marchas`; antes se rehacía en cada fotograma y a velocidades altas el reloj cambia en cada uno), (b) las flechas se redibujan a ~30 por segundo y solo si hay rutas a la vista,
   (c) los carriles se calculan en una sola pasada con un diccionario por tramo, (d) al dar la orden, `dividir_reg` es 6 veces más rápido y todas las columnas que van al mismo destino reutilizan la misma ruta de la caché.
7. **Conteo de soldados por país** se guarda según `version_pilas` (que sube en cada cambio real).
**Velocidad alta, sin maquillaje**: en la corrida final (54 guerras, ~290 columnas) el servidor gasta ~28 ms por fotograma en simular a velocidad 3 y ~44 ms a velocidad 6 (fases 29 ms + repintados); el juego avanza más lento que lo nominal. Los picos de FPS bajan, pero el costo por día sigue siendo el techo de la velocidad real.
Medidas que **no** se optimizaron (límites para la próxima): `Guerra._ronda` (~16–18 ms/día con 21 batallas y ~1000 pelotones: `_poder` 4,7 ms y `_aplicar` 10 ms); el avance de columnas escribe un registro de historial por pelotón por paso (~5 ms); repintar por cambio de dueño (`pintar` 12 ms, `fronteras` 13 ms, `etiquetas` 17–21 ms, `foco` 19–21 ms, solo cuando cambia un dueño); dibujar rutas con cientos de columnas de la IA (6–10 ms por repintado).
**Riesgo de memoria**: con 54 guerras a la vez, 24 meses añadieron ~158 MB (filas de historial). No se cambió; si juegas muchos años conviene archivar o podar historial.
Las IA son muy agresivas en campaña (54 guerras entre 51 países en 150 días): es comportamiento de la IA, no un fallo de rendimiento; se puede templar con `GRACIA_INICIAL`, `GRACIA_JUGADOR`, `MAX_GUERRAS` y la cautela en `scripts/ia.gd`.

## Archivos tocados (líneas añadidas / quitadas respecto a 0.1.8.2)
`MapaPrincipal.gd` +566/−22 · `scripts/capa_tropas.gd` +278/−125 · `scripts/guerra.gd` +162/−10 · `scripts/ia.gd` +73/−17 · `scripts/ejercito.gd` +41/−30 · `scripts/fusion_mapa.gd` +31/−2 · `scripts/reloj.gd` +19/−2 ·
`scripts/red_provincias.gd` +17/−0 · `scripts/entidades.gd` +15/−4 · `scripts/popup_guerra.gd` (nuevo, 304 líneas) · `herramientas/construir_vecinos.py` +18/−3 · `datos/vecinos_prov.json` (regenerado: +3.808 enlaces marítimos) · `project.godot` (versión y nombre).
**Sin cambios**: `datos/variables.json`, `datos/ids.json` (el modelo de datos es idéntico al de 0.1.8.2), `scripts/base_datos.gd`, `debug_menu.gd`, `hud.gd`, `hud_tropas.gd`, `historia.gd`, `mandos.gd`, `personalizar_pais.gd`, `ranking.gd`, `tema_hud.gd`, `ventana_flotante.gd`.

## Pruebas (todas en mi servidor, sin jugar a mano)
Nuevas o ampliadas: `runner51`/`runner58` (rutas de islas), `runner52` (rutas nuevas con capturas), `runner53` (pop-ups de guerra y tratado), `runner54` (colores), `runner55` (provincias y vecinos), `runner56` (rendimiento a distintas velocidades), `runner57` (perfil por componente), `runner58` (benchmark de rutas), `runner59` (ayudantes del panel), `runner60` (día repartido en fases), más los ajustes de `runner6/7/9/17/24/25/28/30`. Regresión de todas las anteriores: ver CHECKLIST_TESTING.md.

## Pendiente / decisiones tuyas
- Estilo de las líneas de provincia / estado / costura; informe de Debug > «Rend.» en tu PC.
- ¿Los colores de identidad de la campaña y los tonos del modo dev te gustan? ¿La paleta de rutas y su grosor (3 px) son los que quieres?
- Afinar la agresividad de la IA (ahora muy guerrera) y los precios de la negociación de paz.
- Optimizar `Guerra._ronda` y el historial por pelotón si el juego sigue pesado en tu PC.
- Hoja de ruta: máquina del tiempo, variables étnicas, árbol de investigación, deriva de idiomas, gastos del estado, subir a GitHub en una rama nueva (nunca main), licencia (CC0).
