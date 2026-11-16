# Notas técnicas 0.1.8.48 — Edificios con efectos reales, fondo de obras, obras públicas de la IA y cuenta de soldados incremental

Sale de tus mensajes del 2026-11-16 («necesito que sigas desarrollándolo… haz las bases más fuertes», «haz 8 horas de trabajo de coding, reescritura, optimización y sobre todo creación de contenido y ensamblamiento al juego»).
La 0.1.8.40 dejó 109 edificios que **se construían y no hacían nada**; la 0.1.8.47 dejó el presupuesto de obras como un descuento sin destino. Esta versión cierra las dos cosas: **97 de los 109 edificios tienen efectos reales**,
el dinero de obras se acumula en un **fondo** y **las IA construyen con criterio** lo que su gente necesita. Detalle completo, tablas y fórmulas en `docs/EDIFICIOS_EFECTOS.md`.

## 1. Qué entra
- **7 clases de efecto** (`datos/edificios_efectos.json`, generado por `herramientas/construir_efectos_edificios.py`): salud, comida segura, vivienda y ciudad, producción, orden y cohesión, defensa y movilidad. Cada edificio tiene 0 o más efectos con
  un peso y los habitantes que atiende cada unidad. 97 edificios con efecto + 12 «solo saber» (ya cuentan como instituciones de saber) = los 109.
- **Rendimientos decrecientes y dilución por gente:** `valor = tope × (1 − e^(−x/tope))`; en las clases por habitante `x = min(peso, atendidos / habitantes de la provincia)`. Un mercado en una provincia de 11 millones casi no se nota (a propósito):
  la IA lo sabe y construye donde rinde.
- **Regla de partida:** los edificios con los que empieza cada escenario ya están dentro de los datos reales de la época, así que salud / comida / vivienda / producción **solo cuentan lo construido después**. Orden, defensa y movilidad cuentan todo.
- **Dónde pesan:** salud → mortalidad (`Demografia`), comida → bienestar, vivienda → urbanización, producción → el producto por habitante sube al terminar la obra, orden → meta de estabilidad (con desglose «Edificios de orden y cohesión»),
  movilidad → la lejanía de la capital resta menos estabilidad, defensa → poder de los defensores de la provincia en la guerra.
- **Fondo de obras** (`Pais.fondo_obras`, variable nueva `fondo_obras`, id 77): la partida `gasto_obras` del presupuesto va cada día a un fondo con tope de 3 años (el exceso vuelve a la tesorería) y 6 meses de arranque. Construir paga **primero del fondo**, luego de la
  tesorería. El jugador también gasta de él.
- **Obras públicas de la IA** (`scripts/obras_publicas.gd`, una fase más: **el día tiene 11**): cada país con IA revisa una vez al año 2 provincias al azar, evalúa los edificios que conoce y puede pagar **solo con su fondo** y construye lo que más gana por su costo, según lo que la
  provincia necesita (descontento, mortalidad, hambre, guerra). Nunca toca la tesorería ni al jugador.
- **Optimización (cuenta de soldados incremental):** `Ejercito.soldados_por_pais` recorría los 21.000–41.000 pelotones cada vez que algo cambiaba (~2,7 ms por cuenta, ~25 % del día de juego en 2026). Ahora cada operación que toca soldados anota el pelotón (`_marcar_sold`) y la cuenta solo corrige
  esa diferencia en el ejército de su país: **74 µs en vez de 2.681 µs** (medido en runner107, 21.612 pelotones). La pasada completa queda para la primera cuenta y para un repaso cada 120 cuentas (`SOLD_REPASO_CADA`), por si algo se escapara. `soldados_por_pais_completo()` es la cuenta de siempre, intacta, para comparar.
- **Interfaz:** línea «Efectos» en cada fila de la ventana Construir y fondo en su cabecera; sección EFECTOS en la tarjeta Edificios del HUD; Debug > Edificios con los contadores de las obras públicas y los efectos de cada ficha.

## 2. Decisiones de diseño (y por qué)
- **Por qué «solo lo construido después» y no todo:** los datos de 2026 (o de 1500) ya traen la renta, la población y la esperanza de vida que esos edificios causaron. Contarlos otra vez regalaba a todo el mundo, al arrancar, una mejora que ya tenía.
- **Por qué la producción sube de golpe al terminar la obra y no es una tasa:** así no hay nada que recalcular cada día (coste de simulación cero salvo el instante de terminar) y la caché de ingresos lo recoge al cerrar el mes.
- **Por qué un fondo y no gastar de la tesorería:** la IA nunca puede arruinarse construyendo; el presupuesto de obras de 0.1.8.47 ahora significa algo y tiene un dueño. En 2026 el fondo casi siempre sobra (~330 obras al año por ~US$ 11 mil millones frente a ~US$ 1,2 billones de fondo):
  lo que no se gasta vuelve a la tesorería a los 3 años, así que no se pierde dinero del mundo.
- **Por qué tanto cuidado con el coste:** una primera versión de las obras públicas costaba ~1 ms por día (el 8 % del día en 2026). Se llevó a ~0,35–0,4 ms con: candidatos precalculados y ordenados por «techo» de puntaje (se deja de buscar cuando nada puede ganarle al mejor), lectura directa de columnas,
  costo de producción tolerante a un cache de unos días, 6 evaluaciones máximo por provincia, revisión anual, lotes de 6 países por llamada.

## 3. Sorpresas que encontré (y cómo quedaron)
- **Escribir `pib_pc_usd` con el setter sube `bd.version_eco`** y obliga a rehacer los balances de ~250 países (7–9 ms): las obras terminadas escriben la columna directo y la caché de ingresos se pone al día al cerrar el mes.
- **Las provincias gigantes casi no ganan nada** de un edificio suelto (dilución). Es el comportamiento buscado, pero hay que saberlo al probar: para ver el efecto de un hospital en una prueba hay que usar una provincia de 80.000–400.000 habitantes (`prov_media` de runner106).
- **runner83 dependía de que no hubiera fondo:** su prueba «se cobra la suma de las tres» ahora vacía el fondo antes.

## 4. Rendimiento
Medido con `test/runner89` (headless, un día con todas las IA, 120 días) contra una copia de la 0.1.8.47, 3 pares seguidos por escenario, CPU en reposo:

| Escenario | 0.1.8.47 | 0.1.8.48 | Diferencia |
|---|---|---|---|
| 2026 (249 IA), pares 1 / 2 / 3 | 13,93 / 13,60 / 12,60 ms | 13,30 / 12,43 / 12,38 ms | **media 13,38 → 12,70 ms (−0,7 ms)** |
| 1500 (202 IA), pares 1 / 2 / 3 | 4,42 / 4,72 / 4,79 ms | 5,95 / 5,34 / 5,53 ms | media 4,64 → 5,61 ms (+1,0 ms) |

- **2026 mejora:** la cuenta de soldados incremental ahorra ~2,6 ms por cuenta, más de lo que cuestan las fases nuevas.
- **1500 sube en el banco corto:** 120 días incluyen el calentamiento (primera cuenta completa de soldados, candidatos de las obras públicas, cachés). Midiendo a régimen (30 días de calentamiento y 240 medidos, perfil por fase con `prof_fases`) la diferencia es **+0,4 ms por día (11,22 → 11,61 ms)**:
  `fase_obras` (las obras públicas de la IA) 0,002 → 0,226 ms; el resto es ruido de la IA (7,45 → 7,70 ms) y de la economía (2,68 → 2,56 ms). Es decir, a régimen el coste de la versión es ~0,23 ms por día más ~0,17 ms de ruido.
- **Mapa y zoom no cambian:** 6,9 ms por fotograma y 6,9 ms por paso de zoom en 1500, igual que la 0.1.8.47 (no se tocó el dibujo ni `_actualizar_zoom`).
- Coste de las piezas nuevas por separado (runner106 / runner107): obras públicas ~0,33–0,41 ms por día; cuenta de soldados 74 µs (antes 2.681 µs); fondo de obras dentro de la fase de economía (sin coste medible).

## 5. Revisión de variables
`python3 herramientas/auditar_codigo.py`: **1.690 funciones, 0 funciones repetidas, 0 variables repetidas.** Constantes, variables y funciones nuevas revisadas a mano (la auditoría no lista lo que no se usa): todas tienen al menos un uso fuera de su definición.
`Ejercito.soldados_por_pais_completo()` solo la usan las pruebas (es la cuenta de referencia contra la incremental; se queda a propósito).
`datos/variables.json` cambió a propósito: variable nueva `fondo_obras` (id 77, 77 variables en total, versión 0.1.8.48).

## 6. Pruebas
- **Nueva: runner107** (CUENTA INCREMENTAL DE SOLDADOS): 360 operaciones al azar (reclutar, bajas, reforzar, dividir, compactar, disolver pelotón y regimiento, desertar) comparando la cuenta incremental con la completa tras CADA una (0 diferencias); 120 días de 2026 y 90 de 1500 con todas las IA; un cambio no anotado se corrige en el repaso; coste (74 µs contra 2.681 µs). 25 comprobaciones.
- **Nueva: runner106** (EFECTOS DE LOS EDIFICIOS): datos puros (97 + 12, clases, topes, sin NaN), fondo (arranque, aporte diario, tope de 3 años, exceso a tesorería, pago con fondo primero, `puede`), modelo (saturación, dilución, regla de partida, ganancias, textos), producción (sube al terminar una obra, no al guardar),
  IA (construye con fondo, nunca con tesorería, no toca al jugador, respeta los topes y las obras en curso, coste) e interfaz (Construir, HUD, Debug). 98 comprobaciones.
- **Ajustadas:** runner71 y runner72 (el día tiene 11 fases; la fila de balance trae el aporte al fondo de obras), runner83 (vaciar el fondo antes de comprobar el cobro).
- Regresión completa: ver `CHECKLIST_TESTING.md`.

## 7. Límites y lo que sigue
- Mantenimiento de edificios, ruinas por guerra o desastres y edificios que consuman materias primas: fuera.
- Los oficios (`datos/carreras.json`) siguen sin pesar en la economía o la mortalidad.
- Las constantes de `construir_efectos_edificios.py` (pesos, cobertura) y de `obras_publicas.gd` (ciclo, valor mínimo) son **provisionales**: si ves que las IA construyen muy poco o que algo rinde demasiado, mándame el F9 y la fecha y se ajusta un número.
- Candidatos: migración entre provincias, epidemias y hambrunas por clima, burocracia y retraso de decisiones, oficios que pesen en la economía.
