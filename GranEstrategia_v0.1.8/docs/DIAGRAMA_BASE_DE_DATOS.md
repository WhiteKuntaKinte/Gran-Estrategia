# Diagrama de la base de datos — 0.1.8.2a (SIN cambios respecto a 0.1.8.2). 0.1.8.2 (SIN variables nuevas respecto a 0.1.8.1: la IA, el modo campaña y el ranking viven en `ia.gd`/`Mundo` y no guardan nada en la base). Lo de 0.1.8.1: (una variable nueva respecto a 0.1.8: `ocupante`, id 56, de provincia, tipo id «país que la ocupa», historial por cambio, afecta a la economía; `tesoreria` ahora la tiene CADA país con provincias, no solo el jugador, y su historial es mensual. En 0.1.8 no hubo cambios de estructura; en 9F se añadió la variable de país `anexado_a`, y el dueño legal de cada provincia sigue siendo la variable `propietario`)

Cuatro imágenes (PNG y SVG; el SVG se puede ampliar sin perder calidad):

| Archivo | Qué muestra |
|---|---|
| `diagrama_bd_general.png` | Modelo entidad-relación: TERRITORIO, VARIABLE, VALOR_ACTUAL, HISTORIAL, DIVISA |
| `diagrama_bd_variables.png` | El ID de cada territorio conectado a las 55 variables y a su historial, una a una (0.1.7.9.9D añade las de guerra y ejército) |
| `diagrama_bd_jerarquia.png` | La cadena de IDs mundo > continente > país > estado > provincia > ciudad, con rangos y cantidades reales (más entidades históricas, personas y, NUEVO en 0.1.7.9.9D, ejércitos y pelotones) |
| `diagrama_bd_historia.png` | NUEVO en 0.1.7.9.9C: la capa histórica — entidades, nombres, banderas, personas y cargos, todo con fechas |

## Cómo leer las relaciones
- **1 a 1 (en realidad 1 a 0..1)**: cada ID de territorio tiene como máximo UN valor por variable (`TERRITORIO.id` — `VAR_x.id_territorio`).
  Si no hay dato, simplemente no hay fila. Por eso nada se sobrescribe: dos variables nunca comparten celda.
- **1 a N**: un ID puede tener muchas filas de historial de una misma variable (`VAR_x` — `HIST_x`), una por cada valor anterior.
  También un territorio contiene a muchos hijos (`padre_id`): un país tiene muchas provincias, un continente muchos países.
- **N a 1 entre territorios**: `propietario` (varias provincias -> un país dueño hoy; su historial es el registro de soberanía) y
  `anexado_a` (un país absorbido -> el país que lo absorbió). Son variables normales cuyo valor es el ID de otro territorio.
- **N a 1 con DIVISA**: muchos países pueden usar la misma moneda (la variable `divisa` guarda su código).

## Los IDs
| Nivel | Rango de IDs | Cantidad |
|---|---|---|
| Mundo | 0 | 1 |
| Continente | 1 – 99 | 7 |
| País / territorio | 100 – 999 | 249 |
| Estado | 1000 – 9999 | 53 |
| Provincia | 10000 – 99999 | 7.653 |
| Ciudad | 100000 – 999999 | 7.341 |
| Entidad histórica (NUEVO) | 1000000 – 1999999 | 16 de ejemplo (la descarga trae miles) |
| Persona (tabla aparte) | 2000000 – 9999999 | 37 de ejemplo |
| Ejército (NUEVO 0.1.7.9.9D) | 10000000 – 10999999 | 249 (uno por país; se crean al empezar la partida) |
| Pelotón (NUEVO 0.1.7.9.9D) | 11000000 – 19999999 | ≈ 21.600 al empezar 2026 (hasta 1.000 soldados cada uno) |

Ejemplo real: Medellín (100102) → Antioquia (15085) → Colombia (150) → América del Sur (2) → Mundo (0).
Los IDs no se reutilizan: un territorio que desaparece queda "dado de baja" (`activo = 0`) y conserva su ID y su historial.

## El ejército (0.1.7.9.9D)
- Cada país tiene un **ejército** (territorio tipo `ejercito`, padre = el país) y cada ejército sus **pelotones** (tipo `peloton`, padre = el ejército):
  Mundo > Continente > País > Ejército > Pelotón. Son entidades de la MISMA base de datos, con las mismas reglas de variables e historial.
- Variables del pelotón: `soldados` (historial por cambio), `edad_media`, `experiencia`, `familiaridad`, `forma_fisica`, `bajas_mes`, `bajas_total`
  (sin historial, se actualizan cada mes) y `ubicacion` (ID de la provincia donde está, con historial). Del ejército: `tasa_militar`. De la
  provincia: `devastacion` (0–1, con historial por cambio).
- **NUEVO en 0.1.7.9.9F2**: entre el ejército y los pelotones hay **regimientos** (tipo `regimiento`, IDs desde 12.000.000, padre = el ejército; el pelotón apunta a él con la variable `regimiento`),
  y dos tipos más: **guerra** (IDs desde 13.000.000, padre = país agresor; variables `agresor`, `defensor`, `guerra_inicio`, `guerra_fin`, `guerra_causa`) y **batalla** (IDs desde 14.000.000, padre = su guerra;
  variables `bat_*`; cada día de combate deja una fila de historial = estadísticas de batalla). El ejército guarda además los precios por unidad de 1.000 soldados (`mantenimiento_unidad`,
  `costo_reclutamiento_unidad`, con sus factores). Los regimientos, guerras y batallas se crean durante la partida (tampoco están en `datos/ids.json`).
- Los pelotones se crean al empezar la partida (no están en `datos/ids.json`); los que se disuelven quedan `activo = 0` y su ID no se reutiliza.
- Las reglas (envejecer, bajas, reclutar, mover) están en `scripts/ejercito.gd`; los nombres de los mandos NO se guardan, se generan al abrir el pelotón.

## La capa histórica (0.1.7.9.9C)
- Una **entidad** (Imperio romano, URSS, Gran Colombia...) es un territorio más en la base, con su propio ID y sin padre geográfico.
  Nace y muere en fechas concretas (`inicio`, `fin`); `entidades_activas(fecha)` dice cuáles existían ese día.
- La variable `propietario` de una provincia puede guardar el ID de un país **o de una entidad**; con su historial sale el dueño en
  cualquier fecha (`dueno_en(provincia, fecha)`). Esta es la tabla que usarán las guerras y las fronteras de cada época.
- **Nombres**: varios por ID, con idioma, clase (oficial / común / nativo) y fechas. Sirven también para países actuales
  (Persia → Irán, Siam → Tailandia, Zaire → RD Congo).
- **Banderas**: varias por ID con fechas y la **licencia de cada imagen** (para poder publicar el juego sin sorpresas).
- **Personas y cargos**: quién gobernó qué y cuándo. Las personas no son territorios (rango de ID aparte).
- Datos de ejemplo (semilla) en `datos/historico/*.json`; el programa `herramientas/descargar_historia/` los reemplaza por los reales.

## Las variables (datos/variables.json) — 31 en 0.1.7.9.9D
| # | Variable | Aplica a | Historial |
|---|---|---|---|
| 1 | poblacion | provincia, ciudad | anual |
| 2 | favorabilidad | provincia | cambio |
| 3 | mult_ingreso | provincia | cambio |
| 4 | pib_pc_usd | provincia | anual |
| 5 | velocidad_desarrollo | país, provincia | cambio |
| 6 | propietario | provincia | cambio |
| 7–9 | area_km2, altitud_media_m, altitud_max_m | provincia | ninguno |
| 10–11 | bioma_principal, reino_biogeografico | provincia | ninguno |
| 12–14 | produccion_principal, _pct, _rubro | país, estado, provincia | cambio |
| 15 | divisa | país | cambio |
| 16 | pib_ref_2026_usd | país | ninguno |
| 17 | tesoreria | país | mensual |
| 18 | tasa_fiscal | país | cambio |
| 19 | nombre_visible | país | cambio |
| 20 | anexado_a | país | cambio |
| 21 | crecimiento_base_anual | mundo | cambio |
| 22 | devastacion (NUEVO) | provincia | cambio |
| 23 | soldados (NUEVO) | pelotón | cambio |
| 24–29 | edad_media, experiencia, familiaridad, forma_fisica, bajas_mes, bajas_total (NUEVO) | pelotón | ninguno |
| 30 | ubicacion (NUEVO) | pelotón | cambio |
| 31 | tasa_militar (NUEVO) | ejército | cambio |

Para añadir una variable nueva (por ejemplo una mecánica de investigación): una entrada nueva en `datos/variables.json`
con un `id_var` nuevo. No hay que tocar nada más para que tenga su tabla de valores y de historial.

Regenerar las imágenes: `python3 herramientas/hacer_diagrama_bd.py` (necesita mmdc y playwright; solo para quien mantiene el proyecto, no hace falta para jugar).
