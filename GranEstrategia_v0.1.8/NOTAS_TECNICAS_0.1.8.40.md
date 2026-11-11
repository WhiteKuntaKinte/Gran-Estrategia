# Notas técnicas 0.1.8.40 — Edificios, cores y ventana Construir

Se entregó junto con la 0.1.8.41 (Camilo pidió saltar directo a la última versión programada). Esta nota deja escrito lo de la 0.1.8.40; lo de imágenes está en `NOTAS_TECNICAS_0.1.8.41.md`.

## Qué es esta versión
1. **HUD de provincia** con las tarjetas **Población**, **Ingreso**, **Edificios** y **Cores**.
2. **Catálogo de 109 edificios** (`datos/edificios.json`), cada uno con categoría, clase de obra, tope por provincia y descripción.
3. **Ventana Construir** (tecla **B**, o el botón «Construir…» de la tarjeta Edificios): cuesta dinero de la tesorería y tarda días; se guarda por provincia.
4. **Dos cores por provincia**: nacional (ID de país) y cultural (id de cultura).
5. **Totales y órdenes de grupo** con Ctrl+clic (una orden = una obra en cada provincia donde se pueda).
6. **Debug > Edificios**: dar / quitar edificios, terminar obras, cambiar cores.

**Decisión de diseño:** los edificios y los cores **no tienen efectos de juego todavía**. Solo existen, se cuentan, se muestran y se guardan. El resto del juego los ignora.

## 1. Catálogo (`herramientas/construir_edificios.py` → `datos/edificios.json`)
- Los 109 edificios son los descubrimientos de tipo B de `datos/descubrimientos.json` (nombre, era, año y sección salen de ahí).
- El generador añade lo que el árbol no tiene: **categoría** (8), **clase de obra** (A–F), **máximo por provincia** y **descripción**.
- Categorías: Vivienda y ciudad (17), Transporte y obras públicas (19), Agua y energía (14), Economía y comercio (6), Educación, cultura y ciencia (17), Salud (4), Defensa fija (28), Mando y formación militar (4).
- Clases (fracción de la producción anual de la provincia / días de obra): A Básica 0,15 % / 15 · B Pequeña 0,4 % / 45 · C Mediana 1,2 % / 120 · D Grande 3 % / 330 · E Monumental 7 % / 800 · F Megaproyecto 15 % / 1.800.
- Un país puede construir un edificio cuando **conoce su descubrimiento** (`Descubrimientos.conoce`: depende de la fecha del reloj o de lo que dé el Debug).

## 2. Módulo `scripts/edificios.gd`
Se guarda **por provincia** en la base de datos (variables 57–59 de `datos/variables.json`):
- `edificios` (texto) `«slug:cantidad;slug:cantidad»` — lo construido.
- `obras` (texto) `«slug@día_inicio@día_fin@pago_usd;…»` — lo que está en obra; los días son del reloj propio `dia_n` del módulo.
- `num_edificios` (número) — cuántos hay construidos; se suma hacia país, estado y continente.

Costo y plazo:
- **Costo** = fracción de la producción anual de la provincia según la clase, con un **piso por habitante** (`FRAC_PISO_HAB` = 20.000: nunca baja de lo que produciría esa cantidad de habitantes con el producto medio del país). Así vale igual en el año 1 que en 2026.
- Se paga en la divisa del dueño (`costo_local`) y se guarda en US$ (`costo_usd`).
- **Cancelar** una obra devuelve el 50 % (`REEMBOLSO_CANCELAR`).
- Si la provincia cambia de dueño, **las obras en curso se pierden** (sin reembolso); lo ya construido se queda con la tierra (`cambio_de_dueno`).

Una fase más en el día (`Mundo.fases_dias`): `fase_obras(k)` hace avanzar las obras `k` días (casi siempre una sola comparación contra `_prox_fin`). **Ahora el día tiene 7 fases** (antes 6): se actualizaron `runner71` y `runner72`, que contaban 6. Se llamaba `fase_dia` igual que la de la IA; se renombró a `fase_obras` (así el perfilador `prof_fases` no mezcla las dos y la auditoría no ve un nombre repetido).

## 3. Cores (`scripts/cores.gd`; variables 60–61)
- **Core nacional** (`core_nacional`, ID de país): el país para el que la provincia es tierra propia por historia. Al empezar, el país original. **No cambia al conquistar.**
- **Core cultural** (`core_cultural`, id de cultura): la cultura de su gente (`datos/nombres_cultura.json`). Se fija al empezar según el país original.
- Sirven para saber qué provincias perdidas puede reclamar un país, y se editan en Debug. Sin efectos todavía.

## 4. HUD de provincia (`scripts/hud.gd`)
- Tarjetas nuevas: **Población**, **Ingreso**, **Edificios** (construidos, los 8 tipos más numerosos, «En obra» con avance y días que faltan, botón «Construir…») y **Cores**.
- Trabajan sobre `main._provincias_elegidas()`: la provincia (o la de la ciudad), todas las del país o estado, o la **unión de todo el grupo** (Ctrl+clic). Las tierras sin reclamar no cuentan: no se construye en ellas.
- Con grupo, las tarjetas suman: «Elegido: N unidades · M provincias de K países», total de edificios y obras en curso.
- El panel se redibuja cuando cambia `Edificios.firma(pis)` (al construir o terminar algo, y cada día mientras haya obras).
- **Costo con un país enorme** (EE. UU., 3.222 provincias): las sumas se hacen leyendo las columnas de la base directo, no provincia por provincia con `bd.txt`/`bd.ref`. `Edificios.total_en` y `totales_de` (salta las provincias sin edificios) y `Cores.contar` (propias / de otro país / sin core y culturas) pasaron de ~26 ms a ~2 ms en conjunto (`runner83` comprueba que dan lo mismo que sumar una por una). Elegir un país por software (solo script, sin dibujo): España 35–39 → 47–51 ms, China 36–41 → 50–53 ms, EE. UU. 52–53 → 78–83 ms (antes de este arreglo 111 ms). Lo que queda son los nodos de las cuatro tarjetas nuevas (~9 ms cada una de las dos más pesadas con un país grande); solo se paga al hacer clic o cuando cambia algo visible, no por fotograma ni por paso de zoom.

## 5. Ventana Construir (`scripts/ventana_construir.gd`)
- Ventana flotante (no pausa el juego). Se abre con **B** o desde la tarjeta Edificios.
- Chips de categoría, casilla «mostrar también lo que no conoces» (los 109), costo y días de cada edificio, estado (construido / en obra / no se puede, con el motivo) y botón **Construir** (con grupo: «Construir ×N»).
- «Obras en curso» con barra de avance, días que faltan y ✕ para cancelar (devuelve la mitad). Tope de 40 filas visibles.
- Solo ordena quien puede: el observador (sin país) todo; si juegas con un país, solo en sus provincias.
- Se actualiza sola una vez por segundo mientras está abierta. Las filas se arman **una sola vez**; luego solo se cambia su texto.
- Medido en `runner83`: refrescar con un país entero (España) < 400 ms por software.

## 6. Debug > Edificios (`scripts/debug_menu.gd`)
Lista de los 109 con filtro, ficha del elegido, «dar», «quitar», «terminar obras» y cambio de core nacional y cultural sobre lo elegido en el mapa.

## 7. Pruebas
`test/runner83` (137 comprobaciones): catálogo y variables, construir (costo, días, cancelar), cores, conquista (las obras se pierden; edificios y cores se quedan), HUD de provincia, ventana Construir, totales y órdenes de grupo, Debug y el escenario del año 1.
