# Efectos de los edificios, fondo de obras y obras públicas de la IA (0.1.8.48)

Hasta la 0.1.8.47 los 109 edificios se construían, costaban dinero y tardaban días, pero **no hacían nada** (solo los de educación y cultura contaban como
«instituciones de saber» para la alfabetización). Desde la 0.1.8.48 **97 de los 109 hacen algo concreto** en su provincia, las IA construyen con criterio y el
presupuesto de obras del Estado deja de ser un número decorativo: es un **fondo** del que sale el dinero de las obras.

**TODAS las constantes son PROVISIONALES** (orden de magnitud razonable, no calibradas contra datos históricos). Si algo se ve raro se cambia una cifra en
`herramientas/construir_efectos_edificios.py` (y se regenera el JSON), no el diseño.

## Piezas

| Archivo | Qué hace |
|---|---|
| `herramientas/construir_efectos_edificios.py` | Fuente de verdad de los efectos. Valida: cada slug existe, los 109 edificios tienen efecto o motivo (`SOLO_SABER`), pesos positivos y por debajo del tope de su clase, clases planas con cobertura 0. Escribe `datos/edificios_efectos.json`. |
| `datos/edificios_efectos.json` | Generado; **no editar a mano**. 7 clases, 97 edificios con efecto, 12 «solo saber». |
| `scripts/edificios.gd` | Cálculo de efectos (`_sumas`, `_valor`, `efectos_nuevos`, `efecto_nuevo`, `efecto_abs`, `ganancias`), textos (`lineas_efectos`, `resumen_efectos`, `texto_efectos`), pago con fondo en `construir`, la subida de producción al terminar una obra. |
| `scripts/obras_publicas.gd` | Fase del día que decide qué construye cada IA con su fondo. |
| `scripts/demografia.gd` / `estabilidad.gd` / `guerra.gd` | Donde se leen los efectos (ver «Quién usa cada efecto»). |
| `scripts/entidades.gd` | El fondo: `Pais.fondo_obras`, `fraccion_obras()`, `_economia_dia` lo llena cada día. |
| `herramientas/anadir_variables_048.py` | Añade la variable `fondo_obras` (id 77, historial mensual, no afecta a la economía) a `datos/variables.json` (idempotente). |

## Las 7 clases de efecto

Cada edificio tiene 0 o más efectos `(clase, peso, habitantes que atiende cada unidad)`.

| Clase | Qué suma | Tope | Se diluye con la gente | Quién lo usa |
|---|---|---|---|---|
| `sal` Salud | puntos de salud efectiva (0-1) | 0,25 | sí | Demografía: sube la salud efectiva → baja la mortalidad |
| `com` Comida segura | puntos de bienestar (0-100) | 14 | sí | Demografía: meta de bienestar |
| `urb` Vivienda y ciudad | fracción urbana | 0,12 | sí | Demografía: meta de urbanización |
| `ren` Producción | fracción de lo que produce la provincia | 0,35 | sí | Al terminar la obra multiplica el producto por habitante (`pib_pc_usd`) |
| `ord` Orden y cohesión | puntos de estabilidad (0-100) | 8 | sí | Estabilidad: meta de la provincia (desglose «Edificios de orden y cohesión») |
| `def` Defensa | × al poder de los defensores | 1,2 | no (plana) | Guerra: bono local de los defensores |
| `mov` Movilidad | fracción del castigo de la distancia a la capital | 0,6 | no (plana) | Estabilidad: la lejanía de la capital resta menos |

**Fórmula.** Para una clase con sumas `S = Σ cantidad × peso × habitantes que atiende` y `W = Σ cantidad × peso`, en una provincia de `pop` habitantes:
`x = W` si la clase es plana; `x = min(W, S / max(pop, 5000))` si es por habitante; `valor = tope × (1 − e^(−x / tope))`.
Es decir: (1) **un edificio que atiende a 40.000 personas en una provincia de 4 millones rinde 1/100 de lo que rendiría en una de 40.000**; (2) nunca se puede
pasar del peso de lo construido; (3) **todo satura**: el décimo hospital da mucho menos que el primero y nunca se pasa del tope de la clase.

**Consecuencia de diseño (medida, no un fallo):** las provincias enormes (≈ 11 millones) casi no notan un edificio suelto. Las obras públicas rinden donde la
gente es poca o están muy bien cubiertas por muchas unidades. La IA lo sabe (calcula la ganancia con la gente real de la provincia) y por eso prefiere provincias
pequeñas y medianas.

## Regla de partida (qué cuenta y qué no)

Los edificios que ya había al empezar el escenario (`Edificios.sembrar_iniciales`) **ya están dentro de los datos reales** de esa época (renta, población, esperanza
de vida, urbanización). Si contaran otra vez, cada escenario partiría con un bono falso. Por eso:
- `sal`, `com`, `urb` y `ren` **solo cuentan lo construido DESPUÉS de empezar la partida** (`_s_nue`, comparado con la foto `_base`).
- `ord`, `def` y `mov` cuentan **todo** (`_s_abs`): los datos reales no traen ni orden, ni defensa, ni movilidad.
- Efecto práctico: en 2026 una provincia llena de hospitales no mejora más por ello (ya están en su mortalidad real), pero un hospital nuevo sí cuenta; un castillo de partida
  sí defiende. Cada descubrimiento nuevo vuelve a abrir obras que valen la pena.

## Producción: cuándo y cuánto

No es una tasa continua: cuando una obra con efecto `ren` **termina**, el producto por habitante de la provincia se multiplica por `1 + (efecto después − efecto antes)`
(`Edificios._terminar_vencidas`; escribe la columna `pib_pc_usd` directo, como el desarrollo mensual, y la caché de ingresos lo recoge al cerrar el mes). Medido: ~+1,5 %
al año en una provincia que construye con ganas, y se frena solo por la saturación. No se repite al guardar ni al cargar.

## El fondo de obras

- La partida `gasto_obras` del presupuesto (referencia 2,5 % de los impuestos; ver `docs/DEMOGRAFIA.md`) **ya no se pierde**: cada día pasa al **fondo de obras** del país
  (`Pais.fondo_obras`, variable `fondo_obras`). La fila de balance trae el aporte diario (`f[5] = ingreso × fracción de obras`) y los impuestos que llegan a la tesorería son
  `ingreso × (1 − gasto total)`.
- **Tope de 3 años** de aportes (`FONDO_DIAS_TOPE = 1095`): lo que sobra vuelve a la tesorería (nada se pierde). **Arranque**: 6 meses de aportes (`FONDO_DIAS_INICIAL = 180`) para
  que el país no empiece sin poder construir.
- `Edificios.construir` paga **primero con el fondo** y luego con la tesorería; `puede` comprueba `tesorería + fondo`. La ventana Construir (B) muestra el fondo en su cabecera y
  los tooltips dicen de dónde sale el dinero.
- **El jugador** construye como siempre (ventana Construir) y también gasta del fondo. Si el jugador reparte distinto su presupuesto, el fondo crece o se achica con él.

## Obras públicas de la IA (`scripts/obras_publicas.gd`)

Una fase más en el día (ahora son **11**: economía, IA, diplomacia, estabilidad, demografía, ejército, obras, **obras públicas de la IA**, llegadas, batallas, ocupaciones).

- Cada país con IA se revisa **una vez al año** (`CICLO_DIAS = 360`), repartido en lotes de a lo sumo `LOTE_MAX = 6` países por llamada.
- En cada revisión mira `MUESTRA_PROV = 2` provincias al azar y, en cada una, evalúa hasta `EVAL_MAX = 6` edificios (de mayor «techo» de puntaje, entre los que conoce, puede pagar y aún
  caben). **Nunca toca la tesorería**: solo gasta su fondo.
- **Puntaje** = `valor ÷ fracción de producción que cuesta el edificio`, con `valor = ren + W_SAL × sal × urgencia + W_COM × com × necesidad + W_URB × urb + W_ORD × ord × descontento + W_DEF × def × guerra + W_MOV × mov`. La
  urgencia viene de los datos de la provincia: **orden** del descontento (favorabilidad baja), **salud** de la mortalidad, **comida** del bienestar bajo, **defensa ×3 si el país está en guerra**.
- Una obra que no mejora al menos `VALOR_MIN = 0,015` no se hace. Con fondo de sobra hace hasta `OBRAS_POR_REVISION = 3` seguidas.
- `iniciar` precalcula el **techo** de cada edificio (el mayor puntaje que podría sacar) y los ordena: el bucle corta en cuanto lo que queda no puede ganarle al mejor candidato.
  Mientras decide, `Edificios.cache_tolerante = true` deja usar la producción por habitante de hace unos días (nada de recalcular balances).
- **No toca al jugador** (`mundo.jugador`). Los países sin IA tampoco construyen solos.
- Los avisos «Obra terminada» solo salen para el jugador o para países sin IA.
- **Coste medido**: ≈ 0,33 ms por día de juego en 1500 y ≈ 0,4 ms en 2026 (todas las IA activas). Contadores en Debug > Edificios: obras hechas, gastado, revisiones, evaluaciones por revisión, ms por día.

## Interfaz

- **Ventana Construir**: línea «Efectos: …» por edificio (`texto_efectos`) y el fondo en la cabecera.
- **Tarjeta Edificios del HUD** (una provincia): sección **EFECTOS** con lo que hacen hoy sus edificios (`resumen_efectos`).
- **Debug > Edificios**: producciones subidas, estadísticas de las obras públicas, fondo de la provincia / país, «Efectos:» de la ficha de cada edificio.

## Qué NO hace (todavía)

- Los 12 `SOLO_SABER` (escuelas, bibliotecas, universidades, observatorios, academias, estación espacial) siguen sin efecto propio: ya cuentan como instituciones de saber.
- Mantenimiento de los edificios, destrucción por guerra o desastres, y edificios que dependan de materias primas siguen fuera.
- Los oficios (`datos/carreras.json`) siguen siendo información: aún no pesan en la economía ni en la mortalidad.
- El fondo de las IA en 2026 casi siempre sobra (construyen ~330 edificios al año por ~US$ 11 mil millones frente a un fondo de ~US$ 1,2 billones); el exceso vuelve a la tesorería a los 3 años.
  Si se quiere que las IA construyan más, se sube `OBRAS_POR_REVISION` o se baja `CICLO_DIAS` (y cuesta CPU: ver rendimiento).

## Cómo regenerar / cambiar

```
cd GranEstrategia_v0.1.8
python3 herramientas/construir_efectos_edificios.py          # reescribe datos/edificios_efectos.json (valida antes)
python3 herramientas/anadir_variables_048.py                 # idempotente
```
Para ajustar un edificio se edita su línea en `EFECTOS` (peso y habitantes que atiende) y se regenera. Si se añade un edificio al catálogo (`construir_edificios.py`) hay que darle
efecto o ponerlo en `SOLO_SABER`, o el generador se niega a escribir. Pruebas: `test/runner106.tscn`.
