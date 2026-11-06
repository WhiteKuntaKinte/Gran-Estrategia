# Notas técnicas 0.1.7.9.9F / 9F2 — fusión de provincias y leyes de frontera reconstruidas (las secciones «tercera» y «cuarta tanda» son de 9F2: regimientos, precios, guerra y líneas de borde)

## Qué es esta versión
Se rehízo desde cero cómo el mapa muestra que una provincia cambió de dueño (anexión, conquista, Debug). Antes la anexión pintaba capas encima,
las provincias de la frontera quedaban con el color/tono equivocado y el país anexado seguía «existiendo». Ahora:
1. Toda provincia con dueño distinto del original toma el color **EXACTO** del país dueño (el mismo de sus provincias propias).
2. La frontera de país se **recalcula** a partir de los dueños: desaparece la línea Francia–España y aparece la de España con sus nuevos vecinos.
3. «Pegar» un país a otro = cambiar el ID de dueño de sus provincias. Cuando Francia se queda sin provincias su estado cambia: **anexado a España**, ya no
   existe en el mapa y su ejército pasa a España.
4. Se corrigió un error de datos: Francia estaba como país de **América del Sur** (color y continente equivocados). Ahora es Europa.

## Modelo de datos (sin otra base de datos)
- El dueño de cada provincia sigue siendo la variable `propietario` de la base de datos (con su historial). La jerarquía geográfica (`padre_id`) NO cambia
  al conquistar: Francia sigue siendo «geográficamente» francesa, el dueño es otra cosa.
- Nueva variable de país `anexado_a` (ID de país, -1 = independiente; con historial y motivo). `base_datos.version_propietario` sube con cada cambio de dueño;
  el mapa la consulta en `_process` y se resincroniza solo (así funciona igual venga el cambio de Debug, de la conquista futura o de lo que sea).
- `BaseDatos.reparentar_lote(ids, nuevo_padre)`: reasigna muchos IDs de una vez (lo usan los pelotones al pasar de ejército).

## Relleno: runs por provincia (`scripts/fusion_mapa.gd`)
- Las mallas de relleno (`malla_filt_*`, teselas de 300×300 unidades) ya existían. `construir_mapa.py` ahora además guarda `malla_filt_runs.bin`: por provincia,
  la lista de «runs» `[tesela, vértice inicial, cantidad]` de los vértices que la dibujan (incluidos los sellos que tapan las rendijas).
- Al cambiar un dueño, `pintar()` recolorea esos vértices en el arreglo de colores de la tesela (color del país dueño) y reconstruye **solo las teselas tocadas**.
  Si la provincia vuelve a su dueño original se restauran los bytes horneados (`malla_filt_cp.bin`), así el mapa vuelve a ser idéntico al de fábrica.
- No hay capas encima ni transparencias: son las mismas mallas, por eso no hay costuras ni tonos distintos.
- El color de un país es el de su continente dominante (Europa 2a5ed1, etc.). `_color_de_dueno()` y `_color_de_pais()` en `MapaPrincipal.gd`.

## Fronteras: tabla de pares (`malla_par_*.bin`)
- `construir_mapa.py` genera una arista por cada **par de provincias vecinas**: 19.504 pares, 110.643 segmentos. `malla_par_tab.bin` = por par
  `[prov a, prov b, primer segmento, cantidad]`; `malla_par_v/uv/i.bin` = los cuadritos de las líneas (mismo shader de borde de siempre).
- **Frontera de país** = pares cuyos dueños son distintos. `FusionScript.malla_aristas(dueno, "frontera")` copia los segmentos de esos pares (en bloques
  consecutivos) y arma la malla; el patrón de índices `[0,1,2,1,3,2]+4k` permite usar un prefijo (`par_i.slice(0, nseg*6)`) sin recalcular índices.
- **Líneas de provincia del país enfocado** = pares donde los dos lados son suyos (`"propio"`). Al fusionar, incluye la antigua costura.
- Comprobación al construir: con los dueños de fábrica, los pares dan exactamente los **17.019** segmentos de frontera que se horneaban antes.
- Se eliminaron `malla_frontera_*`, `malla_prov_*` y `prov_rangos.json` (reemplazados por lo anterior).

## Nombres de países
- Los nombres horneados (por letra, a lo largo del país) de los países cuyo dueño cambió se ocultan con alpha 0.
- El nombre nuevo se calcula en tiempo de ejecución para el país dueño: bloques contiguos de sus provincias (por la tabla de pares); se elige el bloque
  «de casa» (el que más provincias originales suyas tiene; si no hay, el más grande); el texto va a lo largo del eje principal (PCA) del bloque, tamaño
  `clamp(min(ancho*0,062, alto*0,10), 0,9, 12)`. Es una aproximación: no tiene la curvatura de los nombres horneados.

## Reglas de país anexado (`scripts/entidades.gd`)
- `transferir_provincia(idx, destino, fecha, motivo)`: cambia dueño (con historial), ciudades incluidas, favorabilidad 35. Si el origen se queda sin
  provincias → `_absorber(origen, destino)`: `anexado_a = destino`, `Ejercito.transferir_tropas` (todos los pelotones del origen pasan al ejército del destino) y,
  si el jugador controlaba al origen, el control pasa al destino.
- Resurrección: si un país anexado recupera una provincia, `anexado_a` vuelve a «ninguno» y existe otra vez (probado devolviendo París).
- `anexar_pais(origen, destino, ...)` = transferir todas las provincias; si el origen ya no tenía ninguna igual queda anexado.
- `existe_pais(p)` = tiene provincias. Un país anexado no se puede enfocar y el HUD muestra «Anexado a X · ya no tiene provincias».
- Debug > Anexar y Debug > Datos muestran el estado («ESTADO: anexado a …», «Tiene provincias de: …»).

## Estado de pruebas (honesto)
Godot 4.3 en Linux, xvfb + render por software (sin GPU), con datos semilla (tp2) y con los datos históricos REALES de Camilo (tp3).
- `runner15` (nuevo, datos reales, 46 comprobaciones, 0 fallos + capturas revisadas a ojo): Francia (101 provincias) → España: las 101 provincias con el color
  EXACTO de España, Francia sin provincias y «anexado a España», ejército 124.667 + 206.668 = 331.335 en España, total mundial de soldados igual, fronteras 17.019 →
  16.954, hay línea nueva España–Alemania, la costura sale en las líneas de provincia de España enfocada, nombres horneados ocultos y nombre nuevo calculado,
  no se puede enfocar a un país anexado; devolver París resucita a Francia; Colombia → España (naranja → azul exacto) y vuelta; EE. UU. → España (3.222 provincias);
  al devolver todo vuelven los 17.019 segmentos y los colores horneados.
- Regresión con el código final: `runner3` (mapa/clics/pausa), `runner5` (base de datos; su único `ERROR` de «tesorería no aplica a provincia» es intencional),
  `runner6` (48 OK), `runner7` (43 OK), `runner8` (datos reales), `runner9` (ejército, 49 OK), `runner10` (marchas, 33 OK), `runner11` (interfaz del panel de órdenes viejo, 26 OK; retirado en la tercera tanda): todos 0 fallos
  y 0 errores de script. (El `ERROR` de ALSA/audio en los logs es del servidor sin tarjeta de sonido.) Los runners 6 y 7 esperan ahora la versión 9F.
- Rendimiento medido en el servidor (CPU lenta, software GL): construir las fronteras de todo el mundo 3,3 ms; anexar Francia 35–58 ms en total; Colombia 27 ms; EE. UU.
  (3.222 provincias) ~125 ms; carga del mapa «mallas» ~1,9 s (≈ +0,1–0,2 s respecto a 9E). NO se midió en tu PC.
- **NO probado**: jugar a mano (lo pruebas tú), tu PC real (FPS), Windows, anexiones encadenadas muchas veces seguidas, conquista real (todavía no hay guerra: hoy el único
  disparador es Debug > Anexar).

## Visibilidad de tropas (ajuste dentro de 9F)
- Regla: en el mapa solo se dibujan las tropas de `Mundo.paises_visibles()` = el país del jugador + `relacionados_de(jugador)` (gancho para vasallos y aliados;
  hoy devuelve lista vacía). Sin jugador (observador) la lista es vacía y no se dibuja nada. Se quitó la regla vieja «otros países con zoom ≥ 1,0» (`ZOOM_OTROS`).
- `CapaTropas`: las pilas salen de `_de_pais[tid]` solo para los países visibles; la pila elegida solo se dibuja si su país es visible; las columnas en marcha de países no
  visibles se saltan; la ruta pendiente se dibuja para las del jugador (y la elegida).
- Los datos NO cambian: el ejército de los demás países sigue existiendo en la base de datos y en el panel de información de la provincia (pestaña Ejército, con los
  extranjeros marcados). Si se quiere niebla de guerra también en el panel, es un cambio aparte.
- Anexar un país mueve su ejército al anexador, así que esas tropas pasan a verse.
- `runner16` (nuevo, datos reales, 17 comprobaciones): solo pilas de Colombia en zoom mundo, zoom 3 y zoom 6 sobre Venezuela; una pila ajena elegida no se dibuja; la columna
  de Colombia se ve y la de Venezuela no; observador = 0 dibujados; tras anexar Venezuela, sus tropas se ven como de Colombia.

## Órdenes de tropas sin menú (ajuste dentro de 9F)
- Selección: clic izquierdo en un cuadrito (`capa_tropas.sel = {"t":"pila","prov","pais"}`) o en una columna (`{"t":"marcha","id"}`).
- Clic derecho (`_clic_derecho` en `MapaPrincipal.gd`): solo es orden si el botón se movió menos de `CLIC_DER_MAX_PX` (6 px) entre pulsar y soltar; si no, es
  arrastre de cámara como siempre. Con una pila propia elegida llama a `_mandar_tropas(destino)` → `_orden_dada` → `ordenar_marcha`. Mar, misma provincia y tropas
  ajenas no ordenan. La cantidad sale de la ventana de órdenes si está abierta (`max_mover`), y tras la orden `resultado_orden` la vuelve a «todas».
- Arrastrar: botón izquierdo sobre un cuadrito propio (`_posible_drag_tropas` → `_mover_drag_tropas` activa tras superar el umbral → `_soltar_drag_tropas`). Mientras
  se arrastra, `capa_tropas.poner_fantasma()` dibuja el cuadrito siguiendo al cursor y se usa la misma vista previa de ruta/días que «Mover…». Esc → `_cancelar_drag_tropas`.
- `runner17` (29 comprobaciones) cubre todos estos casos con clics y arrastres simulados.

## Línea dorada (ruta de tropas)
- `CapaMarchas` (z1) guarda la ruta en `_oro` y `CapaFlechas` (z2) anima flechas por ella. Las líneas se trazan en ESPACIO DE PANTALLA
  (`draw_set_transform(off, 0, Vector2(1/zr, 1/zr))`): el halo de antialiasing de `draw_line` mide 1 unidad local, así que dibujar en unidades de mapa daba líneas borrosas
  y el doble de anchas. Capas: borde oscuro, cuerpo dorado, hilo claro; rayada por mar. Flechas cada `FLECHA_ESPACIO_PX` = 40 px a `FLECHA_VEL_PX` = 44 px/s, máximo
  `FLECHA_MAX` = 220. Sin ruta pendiente no queda nada animándose (`runner21`, con capturas).

## Rendimiento del zoom (medido en el servidor: CPU lenta, GL por software; solo sirve para comparar)
- Diagnóstico (`runner18` por zoom, `runner19` estructura + ablación por capa, `runner20` barrido de rueda): lo caro al alejar es GEOMETRÍA (costa ~212 mil triángulos,
  relleno ~315 mil) y, del lado del código, el redibujado de nombres de ciudades con zoom alto.
- **Costa con niveles de detalle** (`herramientas/construir_mapa.py`, `COSTA_LOD = ((1, 0.4), (2, 1.0))`; funciones en `herramientas/geom.py`): los 106.009 segmentos de costa
  se unen en polilíneas (`cadenas_de_segmentos`), se simplifican con Douglas-Peucker (`dp_indices`; error máximo 0,4 y 1,0 unidades de mapa) y se arman con el mismo
  `malla_borde` + troceo en teselas. Los anillos cerrados (islas) se parten en el punto más lejano del inicio para que una isla diminuta no desaparezca. Resultado:
  nivel 1 = 35.861 segmentos, nivel 2 = 17.710 (el completo sigue siendo 106.009). Archivos nuevos `malla_costa1_*.bin`, `malla_costa2_*.bin`; `teselas.json` trae `costa1` y
  `costa2`. Reconstruido desde cero: los demás 45 archivos de datos salen idénticos byte a byte (`cmp`).
- En el juego (`_elegir_detalle_costa`, llamado desde `_actualizar_zoom`): zoom REAL < `COSTA_ZOOM_NIVEL2` (1,0 px por unidad) → nivel 2; < `COSTA_ZOOM_NIVEL1` (2,4) → nivel 1; si no,
  completo. Error visual ≤ ~1 px (la línea mide 2,2 px). Si faltan los archivos nuevos se usa siempre el completo. Capturas lado a lado (`runner22`): 0,3–1,1 % de píxeles distintos.
- **Nombres de ciudades** (`CapaCiudades`): antes cada tesela de 300×300 comparaba y dibujaba TODOS sus nombres en cada cuarto de octava de zoom; ahora (1) la colisión usa una
  rejilla de casillas de 96×32 px (antes cada nombre contra todos los puestos) y (2) solo se consideran los que caen en la pantalla ampliada (+60 % por lado); se redibuja cuando
  cambia el zoom o la pantalla sale de esa zona (`area.encloses(vista)`), así panear casi nunca redibuja.
- Medidas del barrido de rueda (`runner20`, ventana 1280×720): fotograma medio al acercar 115,6 → 61,7 ms y al alejar 141,7 → 75,8 ms; a zoom mínimo 217–280 → 107–123 ms; ciudades con zoom 20–31:
  40–60 → ~4 ms por paso. Ablación a zoom 0,55 (`runner19`): el relleno de países sigue siendo ~54 de ~104 ms (362 mil triángulos), el mar ~16 ms, la costa ahora ~11 ms.
- **Pendiente** (siguiente rendimiento): relleno con niveles de detalle (necesita simplificar las provincias con aristas compartidas coherentes, regenerar los «runs» de recoloreado
  para cada nivel y que `fusion_mapa.gd` recolore todos), y caché de texto de ciudades.
- **Debug > «Rend.»** (`scripts/debug_menu.gd`, `_pagina_rendimiento`): GPU/sistema (`RenderingServer.get_video_adapter_name()`, etc.), FPS/ms/llamadas/objetos/triángulos en vivo,
  casillas para apagar capas (`main.rend_poner_capa(clave, visible)`; claves relleno, mar, lagos, costa, fronteras, nombres, ciudades, tropas; `rend_ocultas` se reaplica cada fotograma
  tras las actualizaciones normales; `CapaTropas` también la respeta) y «Prueba de zoom» (`_prueba_zoom`: 17 pasos, ida y vuelta de 0,55 a 32 sobre Europa; por paso FPS medio, peor
  fotograma, «tirón» = peor de los 3 primeros fotogramas tras cambiar el zoom, llamadas y triángulos; devuelve la cámara a su sitio y deja el informe en el portapapeles).
  `runner23` lo prueba entero (apagar/encender cada capa, la prueba completa, el informe, la cámara y el portapapeles).

## Regimientos, precios, guerra y batallas (tercera tanda de 9F)
Pedido de Camilo (13:38): las tropas no se funden solas, nombres y números sin superponerse, cuadro más grande, HUD de tropas como base de diseño, primer sistema de
precios, todo dentro del modelo de la base de datos, números completos, historial de estadísticas de batalla y guerra automática al atacar (base de la rivalidad).

### Modelo de datos (sin otra base de datos)
- `base_datos.gd` TIPOS nuevos: `regimiento` (9), `guerra` (10), `batalla` (11). Rangos de ID: ejército 10.000.000+, pelotón 11.000.000+, **regimiento 12.000.000+,
  guerra 13.000.000+, batalla 14.000.000+**. `bd.n` sube con cada entidad creada (los disueltos quedan desactivados, no se borran).
- `datos/variables.json` (55 variables; 24 nuevas, ids 32–55): `regimiento` (id, del pelotón; por cambio); `factor_mantenimiento`, `factor_reclutamiento`,
  `mantenimiento_unidad`, `costo_reclutamiento_unidad` (ejército; las dos últimas mensuales); `guerras_activas` (país); `agresor`, `defensor`, `guerra_inicio`,
  `guerra_fin`, `guerra_causa` (guerra); `bat_provincia`, `bat_guerra`, `bat_atacante`, `bat_defensor`, `bat_inicio`, `bat_fin`, `bat_dias`, `bat_ini_atac`,
  `bat_ini_def`, `bat_bajas_atac`, `bat_bajas_def`, `bat_ganador`, `bat_resultado` (batalla). `bat_dias`, `bat_bajas_*` y `bat_fin` guardan historial por cambio:
  **cada día de combate deja una fila = historial de estadísticas de batalla** (`Guerra.serie_bajas(bid)` lo lee).
- Cadena de mando: País > Ejército > **Regimiento** > Pelotón. El regimiento es hijo de su ejército; el pelotón apunta a él con la variable `regimiento`.
  Al iniciar hay un regimiento por (país, provincia) con tropas.

### Regimientos (`scripts/ejercito.gd`)
- Un regimiento = grupo de pelotones que se mueve, pelea y se dibuja como UN cuadro. Quietos: `regs_prov[provincia] = [rid...]`; en marcha: `marcha_de_reg[rid]` y
  `prov_de_reg[rid] = -1`. Consultas: `regimientos_quietos()` (guardada por `version_pilas`), `regs_en(prov)`, `pelotones_de(rid)`, `soldados_reg`, `prov_de`,
  `pais_de_reg`, `en_marcha_reg`, `ficha_reg`, `cuenta_regimientos()`.
- **Nada se funde solo**: `reclutar(..., reg := -1)` crea un regimiento NUEVO (o refuerza el indicado); al llegar una marcha el regimiento llega entero y comparte
  provincia con los demás. Órdenes deliberadas: `unir(destino, origen)`, `dividir_reg(rid, n)`, `disolver_reg(rid)`, `compactar_reg(rid)` (reagrupa los pelotones DENTRO
  de un mismo regimiento), `mover_reg`, `ordenar_marcha_reg(rid, n, destino_pi)` (si `n` es menor que el total, parte el regimiento y marcha la parte).
  Se eliminaron `pilas_todas`, `consolidar`, `tomar` y el viejo `ordenar_marcha`. `ej.mover(id)` / Debug «Mover aquí» mueven el regimiento completo del pelotón.

### Precios (`ejercito.gd`, `entidades.gd`)
- Por UNIDAD de 1.000 soldados, en variables del ejército: `mantenimiento_unidad` (US$ al año) y `costo_reclutamiento_unidad` (pago único) = factor × PIB por habitante ×
  1.000. Factores por defecto `FACTOR_MANT_DEFECTO = 6` y `FACTOR_RECL_DEFECTO = 4` (provisionales; editables por país en la base). `actualizar_precios()` corre al
  iniciar y cada mes (`avanzar_mes`). `precios_unidad_usd`, `mantenimiento_diario_usd`, `costo_reclutar_usd`.
- `Mundo.balance_diario_local(país)` = ingreso − mantenimiento; `avanzar_dia` lo suma a la tesorería del jugador (puede quedar NEGATIVA: sin quiebra todavía).
  `Mundo.reclutar_pagando` cobra solo al jugador (los demás países no tienen tesorería simulada). La barra superior muestra el balance (`hud.set_dinero(total, ingreso,
  perdida, en_deuda)`; rojo si pierde).

### Guerra y batallas (`scripts/guerra.gd`, nuevo)
- `Ejercito.ordenar_marcha_reg` **declara la guerra** (`mundo.guerra.declarar(agresor, defensor, causa)`) cuando el dueño de la provincia destino ≠ país del regimiento,
  no es aliado/vasallo (`Mundo.relacionados_de`) y no hay guerra ya. Devuelve `guerra` y `contra` en el resultado y el mensaje «¡GUERRA con …!»; la vista previa del
  destino (`capa_tropas.guerra_prev`) también avisa. Solo cuenta el DESTINO (no las provincias ajenas por las que se pase).
- Una batalla empieza cuando regimientos quietos de dos países en guerra coinciden en una provincia (`_revisar_prov` al llegar, `_revisar_pareja` al declarar). Un
  asalto por día (`avanzar_dia`, llamado desde `Mundo.avanzar_dia`): poder = soldados × calidad (experiencia, forma física, familiaridad) × `BONO_LOCAL` 1,2 si juega en su
  provincia; bajas diarias = `RITMO_BAJAS` 0,08 × 2 × poder rival ÷ poder total, ± `RUIDO` 15 %. Termina por aniquilación (o paz). **Fórmula provisional.**
- API para la interfaz: `ficha_guerra`, `ficha_batalla`, `serie_bajas`, `batallas_de(país)`, `guerras_historial_de(país)`, `rivales_de(país)`, `provincias_en_combate`,
  `paz(a, b)` (botón provisional e instantáneo). **No hay**: retirada, conquista/ocupación, tratados de paz, bloqueo de paso por provincias enemigas.

### HUD de tropas (`scripts/hud_tropas.gd`, reemplaza `ordenes_tropas.gd`)
- Ventana flotante (`ventana_flotante.gd`) con cabecera de finanzas y 4 pestañas: Regimientos (lista de la provincia o de todo el país, ficha, Mover/Dividir/Unir/
  Disolver/Detener), Reclutar (nuevo o reforzar, costo y mantenimiento resultante), Guerras y Batallas (historial). `MapaPrincipal.abrir_ordenes(prov, país, reg)` y la
  variable `panel_ordenes` se conservaron por compatibilidad. `n_mover()` da la cantidad elegida; el clic derecho y el arrastre usan `_mandar_tropas(rid, pi)`.
  `capa_tropas.sel = {"t":"reg","reg":rid}` o `{"t":"marcha","id":mid}`.

### Dibujo de tropas y nombres (`scripts/capa_tropas.gd`)
- Un cuadro por regimiento (alto 28 px, ancho según el número COMPLETO de soldados, sin «k»); varios regimientos de una provincia se apilan en columna (`MAX_APILADOS`
  = 4; el resto en un cuadro «+N»); cuadro con borde rojo y espadas si hay batalla. Los cuadros de marcha siguen su ruta.
- **Sin superponer nombres de provincia**: `_preparar_rect_et` guarda, por cada nombre del país enfocado, rectángulos pequeños a lo largo del texto (`rs`, usando
  `MapaPrincipal.etiqueta_tramo`: dónde empieza y cuánto mide el texto sobre la polilínea) y su zoom de legibilidad (`zin`). En `_draw` se juntan los nombres visibles
  (`zr ≥ 0,78 × zin`) y `_hueco_sin_nombres` desplaza cada cuadro (vertical, horizontal o ambos, hasta ~150 px; 320 px para el elegido) al hueco libre más cercano que no
  toque ningún nombre ni otro cuadro. Si no hay hueco, el cuadro no se dibuja (se ve al acercar más), salvo el elegido, que siempre se dibuja.

### Pruebas
- `runner24` (lógica, 48 OK): regimientos, precios, balance, reclutar/unir/dividir/disolver, marcha sin fusión, guerra al atacar, batalla y su historial, paz.
- `runner25` (interfaz con clics reales y capturas en `/tmp/shots25`): HUD abierto con clic, reclutar cobra, apilado, +N, aviso de guerra, batalla con espadas, pestañas
  Guerras/Batallas, precios mensuales y «ningún cuadro pisa un nombre de provincia visible» sobre Colombia a zoom 6 (34 OK).
- Portadas al modelo nuevo: `runner7`/`runner8`/`runner9` (conteo de la base con regimientos; Debug mover regimientos), `runner10` (marchas con `ordenar_marcha_reg`; la columna
  llega como regimiento propio), `runner16`/`runner17`/`runner21` (cuadros `reg`, HUD `sp_n`/`max_n`). `runner11` (interfaz del viejo panel de órdenes) se retiró: lo cubre `runner25`.

## Líneas de borde (cuarta tanda de 9F)
Pedido por voz de Camilo (1-nov, 15:06): contorno de continente (zoom lejos) más grueso y negro; línea entre continentes un poco más angosta; en zoom cerca el contorno igual
de grueso y la frontera entre países «una línea negra franjada»; costas por ahora solo línea negra.
- `MapaPrincipal.GROSOR_PX` (píxeles de pantalla, iguales a cualquier zoom): `costa` 2,8 (antes 2,2; color negro puro), `cont` 1,8 (antes 2,2), `frontera` 2,6 (antes 1,5).
  La costa no depende del zoom (se ve igual lejos y cerca); `cont` se apaga al acercar (alfa `1 − t`) y `frontera` se enciende (alfa `t`) con `ZOOM_PAISES_INI/FIN` (1,0–1,6).
- `mat_frontera` ya no usa el shader liso: usa `SHADER_BORDE_FRANJA` (negro `col` + crema `col2`), con el nuevo uniforme `negro` (fracción negra de cada periodo; `NEGRO_FRONTERA` = 0,62) y
  `periodo` = `PERIODO_FRONTERA_PX` (8 px) / zoom real, fijado en `_fijar_grosor`.
- Las franjas necesitan la DISTANCIA recorrida a lo largo de la línea: `herramientas/construir_mapa.py` ordena los segmentos de cada par de provincias con `encadenar()` y guarda por vértice
  la distancia acumulada (×20, 2 canales de color, igual que `malla_cont_c.bin`) en **`datos/malla_par_c.bin`** (nuevo). `FusionMapa.par_c` la carga y `malla_aristas` la copia junto con
  los vértices (`par_c` vacío si falta el archivo: la frontera se dibuja sin franjas coherentes). `par_tab`/`par_i` no cambian; `malla_par_v/uv` quedan reordenados (misma geometría).
  El resto de archivos de datos se regeneró idéntico byte a byte (`cmp` contra los anteriores).
- La línea «entre continentes» (`cont`, 55 segmentos) solo existe donde dos masas terrestres distintas comparten arista (Panamá, Sinaí/Suez, Nueva Guinea…): en `construir_mapa.py` `grupo()` junta
  Europa y Asia en «Eurasia». La línea Europa–Asia es una categoría aparte (`ea`, `malla_ea_*.bin`, `capa_ea`/`mat_ea`): mismo estilo rayado y grosor `cont`, con alfa `t` → NO se ve lejos (Eurasia
  se ve igual que antes) y SÍ al acercar (confirmado por `runner26`: lejos 0 capas visibles, zoom 6 visible).
- `runner26` (nuevo, capturas en `/tmp/shots26`): la malla de frontera trae distancia por vértice, grosores en pantalla (costa 2,8 lejos y cerca, cont 1,8, frontera 2,6), frontera visible
  al acercar; capturas a zoom 0,6, 1,6, 6 y 8 revisadas a ojo.

## Límites conocidos
- Las franjas continentales (`capa_cont`, las bandas de color por continente) son GEOGRÁFICAS y estáticas: no siguen al dueño. Un país anexado conserva el tono de su
  continente original en esas franjas.
- Las líneas de estado/región (`estado_rangos.json`) se siguen dibujando por país original.
- `vecinos_prov.json` (rutas de tropas, 19.448 vecinos por tierra) y la tabla de pares del mapa (19.504) se calculan con criterios distintos (vértices compartidos vs. bordes
  dibujados): pueden diferir en unos pocos pares pequeños. No afecta a las rutas.
- El nombre dinámico del país es una aproximación (recta a lo largo del eje principal); países muy fragmentados (islas) pueden quedar con un nombre pequeño.
- El cambio de ejército (`reparentar_lote`) mueve los pelotones al nuevo ejército pero no deja historial por pelotón de ese cambio de padre.
- Un país anexado conserva su historial y sus datos; no se «borra» de la base de datos (puede resucitar).
- La máquina del tiempo pasa a la versión **9G**.
- Lo pendiente de versiones anteriores sigue igual (ver `NOTAS_TECNICAS_0.1.7.9.9E.md`, `...9D.md`, `...9C.md`).

## Cómo regenerar
- `python3 herramientas/construir_mapa.py` (~2,5 min; python3 + numpy + shapely según el script) → mallas del mapa, `malla_filt_runs.bin`, `malla_par_*`, `teselas.json`.
- `python3 herramientas/construir_ids.py` → `datos/ids.json` (conserva los IDs). `python3 herramientas/hacer_diagrama_bd.py` → diagramas en `docs/`.
- `herramientas/anadir_color_foco.py` y `herramientas/construir_info.py` calculan el color/continente dominante de cada país.
