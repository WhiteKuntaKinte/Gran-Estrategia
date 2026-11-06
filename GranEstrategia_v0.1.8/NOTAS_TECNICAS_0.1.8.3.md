# Notas técnicas 0.1.8.3 — declarar la guerra desde el menú, IA con ejércitos acotados, tregua larga, tiempo reestructurado, observador, HUD menos invasivo y rendimiento con IA en todos los países

## Qué es esta versión
Pedido de Camilo (mensaje del 2 de noviembre, 12:48), nueve puntos:
1. **Declarar la guerra desde el menú principal** (antes solo se «declaraba» al mandar tropas a territorio ajeno).
2. **Ejércitos enemigos con tropas casi infinitas**: revisar la rejugabilidad.
3. **Tregua**: acabar una guerra y que la IA te la declare otra vez enseguida no tiene sentido.
4. **Al dejar de controlar un país, pasa a la IA** (en la campaña los demás países dejaban de entrar en guerra).
5. **Reestructurar el tiempo**: x6 tiene que ser «rapidísimo» y poder jugar años seguidos.
6. **Ensanchar y angostar la ventana de Debug.**
7. **Rendimiento en modo dev con IA en todos los países.**
8. **Modo observación**: ver el movimiento de todas las tropas (también en la campaña): se puede no jugar y mirar cómo evoluciona todo.
9. **HUD menos invasivo**: un tercio de la pantalla eran menús.
Todos los números nuevos son **PROVISIONALES** y están como constantes al principio de cada archivo.

## 1. Declarar la guerra desde Diplomacia (`MapaPrincipal.gd`, `scripts/hud.gd`)
- La pestaña **Diplomacia** del país elegido tiene dos secciones nuevas: «Relación contigo» y **«Declarar la guerra»**: un botón por cada vecino (por tierra o por estrecho) con el que no estás en guerra. La primera pulsación pide confirmar («¿Seguro? Pulsa otra vez…»), la segunda declara. Si el país tiene tregua con el jugador se muestra cuánto queda; **el jugador sí puede romperla** (la tregua solo ata a la IA).
- Reglas (`puede_declarar_guerra`): hay que controlar un país (el observador no declara), no estar ya en guerra, no ser aliado/vasallo, que el rival exista y, en la campaña, que tenga IA. Devuelve `{ok, motivo}`; el botón sale deshabilitado con el motivo.
- **Mandar tropas a territorio de un país con el que no estás en guerra ya NO declara la guerra solo**: la orden se bloquea con «No estás en guerra con X: para entrar en su territorio decláraselo (su ficha > Diplomacia > Declarar la guerra)» (`_aviso_sin_guerra`, usado al hacer clic en el destino y al soltar un cuadro arrastrado). La vista previa de la ruta también lo dice («Sin guerra con X: decláraselo antes…»). En el modo libre **sin país** (herramienta de pruebas) todo funciona como antes, incluida la declaración automática.
- La IA sigue declarando guerras por su cuenta (ver sección 3).
- Pruebas: `runner66` (17 comprobaciones: lista de declarables, bloqueo de la orden, dos pulsaciones, guerra declarada, no declarar dos veces, observador no declara, tregua tras la paz, el jugador puede romperla); `runner25` y `runner49` ajustados.

## 2. Ejércitos de la IA acotados (`scripts/ia.gd`)
**Causa del «tropas infinitas»**: la IA podía reclutar hasta el 1,5 % de la población en cuestión de días: en una prueba de 2 años con IA en todo el mundo, los soldados pasaron de 21,5 M a 136 M y había más de 100 guerras abiertas a la vez. Ahora:
- **Tope de ejército** por país (`TOPE_PAZ = 1,3 ×` su ejército inicial en paz, `TOPE_GUERRA = 2,5 ×` en guerra; un país sin datos de ejército parte de `TASA_EJERCITO_MIN = 0,03 %` de su población; además sigue el tope de `MAX_POB_EJERCITO = 1,5 %`).
- **Ritmo de reclutamiento limitado** por un cupo que se llena con el tiempo: `CRECE_PAZ_ANUAL = 5 %` del tope al año en paz y `CRECE_GUERRA_ANUAL = 50 %` en guerra; el cupo no se acumula más de `DIAS_RECLUTA_MAX = 90` días.
- **Pocas guerras a la vez**: las guerras abiertas en todo el mundo no pasan del `FRAC_GUERRAS_GLOBAL = 10 %` del número de IA (mínimo 2), y una IA que podría atacar a alguien tarda en promedio `ESPERA_GUERRA_DIAS = 540` días en decidirlo (antes ~11).
- Resultado en dev con IA en todo el mundo, 2 años: soldados ≈ 25–27 M (antes 136 M) y 4–8 guerras (antes más de 100).
- Pruebas: `runner69` (1 año en dev con ~250 IA: los soldados totales no pasan de 1,6 × lo inicial, ningún país pasa de 2,6 × su ejército inicial, guerras simultáneas con tope) y `runner44` (campaña con 50 IA).

## 3. Tregua (`scripts/ia.gd`)
No pude reproducir un fallo de la tregua en el código (el test `runner61` pasa); la causa más probable es que 365 días de juego a x6 pasaban en ~1,5 s y se sentían como «ya» (ahora x6 es 370 días/s, ver sección 5). Se alargó y se reforzó:
- `TREGUA_DIAS = 1825` (5 años) entre los dos países tras una paz (antes 365 días).
- `DESCANSO_TRAS_PAZ = 365`: una IA que firmó la paz no declara NINGUNA otra guerra durante un año.
- `registrar_paz` aplica la tregua y el descanso a las dos IA; `tregua_restante(a, b)` la consulta (la pestaña Diplomacia la muestra con `texto_duracion`: «4 años 11 meses»).
- Pruebas: `runner61` (se fuerza una guerra IA → jugador, paz, 400 días sin que ese país vuelva a declarar; tregua restante > 1000 días) y `runner66`.

## 4. Dejar de controlar un país → lo lleva la IA (`scripts/entidades.gd`, `scripts/ia.gd`)
`Mundo.fijar_jugador` llama a `ia.control_cambiado(antes, ahora)`: el país que tomas deja de tener IA y el que sueltas pasa a tenerla (en la campaña, o en dev si ya hay IA activas). **Campaña como observador**: el selector de país del menú tiene «— Ninguno: solo observar —» y la campaña ya no pregunta qué IA activar: **todos los países de la campaña menos el tuyo** tienen IA. Al iniciar de observador la cámara encuadra toda la campaña (`_encuadrar_campana`; antes de este arreglo fallaba al centrar un país inexistente). La barra superior muestra tu país (o «Observador») desde el primer cuadro.
Pruebas: `runner67` (12): observador de campaña con 51 IA, tomar/soltar España y Francia, la IA sigue decidiendo (1.310 decisiones en 300 días); `runner48` ajustado (52 opciones, sin selector de IA).

## 5. Tiempo reestructurado (`scripts/reloj.gd`, `MapaPrincipal.gd`, `scripts/entidades.gd`, `scripts/ejercito.gd`, `scripts/guerra.gd`)
Antes cada día se simulaba entero y el reloj no podía pasar de ~1 día/s a x6 en un PC normal. Ahora:
- **Velocidades** (`SEG_POR_DIA = [0, 1, 0.4, 0.12, 0.04, 0.012, 0.0027]`): x1 = 1 día/s · x2 = 2,5 · x3 = 8 · x4 = 25 · x5 = 83 · **x6 = 370 días/s (un año por segundo)**.
- **El reloj acumula «deuda» de tiempo** (`acumular`) y la paga en **un paso de varios días** (`sumar_dias(k)`, k ≤ 31, sin cruzar el fin de mes; `DIAS_MIN_PASO = [1,1,1,1,3,8,20]`); la deuda máxima es de 62 días (`DIAS_DEUDA_MAX`) para que un tirón de FPS no dispare una avalancha.
- Cada paso se reparte en **fases** (`fases_dias(k)`: economía, IA, ejércitos, batallas, ocupaciones) entre fotogramas con un presupuesto de 9 ms (`PRESUPUESTO_US`); a **velocidad ≥ 4 se activa el modo ahorro** (`mundo.ahorro`): los balances se rehacen cada 3 meses y `avanzar_mes` trabaja por grupos de países.
- Todas las fórmulas aceptan `k` días: batallas (`SUBRONDA_DIAS = 4`, bajas `1 − (1 − l)^días`), ocupaciones, economía y marchas (`avanzar_dia(k)`); el cierre mensual/anual del historial es una fase propia.
- Medido en mi servidor (sin pantalla, CPU lenta): dev con 249 IA: x3 99 %, x4 100 %, x5 99 %, **x6 ~58 % (≈216 días/s)**; campaña con 50 IA: x5 99 %, **x6 ~89 % (330 días/s)**. Antes de esta versión x6 daba ~1 día/s. Con pantalla y tu PC los números cambian.
- Pruebas: `runner60` (día repartido en fases), `runner64` (velocidad real por nivel; diagnóstico, no es de regresión).

## 6. Observador ve todas las tropas (`scripts/capa_tropas.gd`)
Sin país controlado (dev o campaña), `Mundo.ve_todo()` es verdadero: `_tids_visibles()` devuelve todos los países con tropas y se dibujan hasta `OBS_RUTAS_MAX = 160` rutas. Con un país elegido se mantiene la regla de antes (lo tuyo y lo que ves de los países en guerra contigo). En la campaña de observador **no se puede dar órdenes** a ningún país; en dev sin país sí (herramienta de pruebas): `puede_ordenar_pais`.
Pruebas: `runner67` (campaña), `runner69` (dev), `runner16` ajustado (antes «el observador no ve tropas»).

## 7. Ventana de Debug redimensionable (`scripts/ventana_flotante.gd`, `scripts/debug_menu.gd`)
Botones **« »** en la barra de título (±70 px; al ensanchar, la ventana se corre para no salirse de la pantalla) y agarradera **◢** abajo a la derecha para arrastrar. Tamaño mínimo 280 × 150; la ventana arranca más chica (470 × 560). Las pestañas se parten en varias filas (`HFlowContainer`), el texto de arriba se parte en líneas y las páginas tienen barra horizontal si el contenido es más ancho que la ventana.
Prueba: `runner68` (angostar, achicar el alto, ensanchar, no salirse de la pantalla) con capturas.

## 8. HUD menos invasivo (`scripts/hud.gd`)
- Panel principal de **500 px → ~30 % del ancho de la pantalla (entre 372 y 420 px)**; la sección con scroll ya no llega casi hasta abajo (`_alto_max = 36 %` del alto de la ventana, antes alto − 365 px): ocupa ~65 % del alto como máximo y se ajusta a lo que lleva.
- Cabecera más baja (bandera 60 × 40, título 20), márgenes y separaciones menores.
- **Botón ▾/▸** en la cabecera: encoge el panel a solo el nombre (y vuelve); se recuerda entre selecciones.
- **Pestañas**: solo la abierta lleva texto; las otras, solo el icono (con el nombre al pasar el ratón).
- Panel de detalle de 350 → 300 px de ancho.
- El botón «Ranking» (campaña) ya no tapa la esquina del panel: en la campaña el panel empieza más abajo.
Prueba: `runner68` (ancho ≤ 430 px y alto ≤ 80 % en las 5 pestañas, botón de encoger) con capturas revisadas a ojo.

## 9. Rendimiento con IA en todos los países (dev) — qué costaba y qué se hizo
Medido con `runner62`/`runner63` (perfil por componente): lo caro era `soldados_por_pais` (4–6 ms), `_armar_balances` (6 ms), `ejercito.avanzar_mes` (21–30 ms), `_preparar_frentes` (9–30 ms) y la IA (1–3 ms por decisión, ×N países). Cambios:
- La IA decide cada `PERIODO = 4` días en guerra y `PERIODO_PAZ = 12` en paz, con cola por prioridad (los atrasados y los que están en guerra primero), como mucho `MAX_IA_PASO = 24` decisiones por paso y tope de tiempo (`IA_MS_PASO_ALTO = 12 ms` a velocidades altas).
- El mapa de frentes (`_frente_de`) se calcula bajo demanda por país y se rehace cada `DIAS_FRENTES = 5` días.
- `avanzar_mes` con recurrencias de forma cerrada y compactación de los índices (`_ix_todos`); en modo ahorro por grupos de países.
- `_sincronizar_propiedad` (repintado por cambio de dueño) con límite de frecuencia a velocidad ≥ 3 (`SINC_MIN_MS = 450`).
- Quedan **picos aislados** de un fotograma (fases hasta ~90 ms, repintado hasta ~126 ms a x6) y el cierre anual del historial (~50 ms, ahora una fase propia). El historial crece ~31.000 filas por año (~3 MB/año de memoria).

## Modelo de datos y auditoría
`datos/variables.json` no cambió (el modelo de datos es el de 0.1.8.2a). Auditoría estática (`herramientas/auditar_codigo.py`): 20 archivos GDScript, 860 funciones, 0 funciones y 0 variables duplicadas. Regresión final: 38 pruebas, 677 comprobaciones OK, 0 fallos y 0 errores de script (lista en CHECKLIST_TESTING.md).

## Cómo probar a mano (resumen; el detalle está en CHECKLIST_TESTING.md)
1. Campaña → «— Ninguno: solo observar —» → pon x6: deberías ver pasar los años y las columnas de todos los países.
2. Campaña con tu país → elige un vecino → pestaña Diplomacia → «Declarar la guerra a …» (dos pulsaciones). Prueba antes mandar tropas a su territorio: la orden se bloquea.
3. Haz la paz y comprueba que no te la vuelven a declarar durante años; la pestaña muestra cuánto queda de tregua.
4. Debug (F1): « » y ◢ para cambiar el tamaño. Botón ▾ del panel para encogerlo.
5. Debug > Jugador: suelta tu país y mira cómo la IA lo lleva.

## No probado (decirlo claro)
Jugar a mano y tu PC real. Todo se midió en mi servidor (sin tarjeta gráfica) con clics y teclas simulados. Pendiente tuyo: el estilo de las líneas de frontera y el informe de Debug > «Rend.» en tu PC (para saber si x6 aguanta con tu pantalla).
