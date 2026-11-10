# Natural Earth en Gran Estrategia

Revisión hecha para la versión 0.1.8.35. Qué es Natural Earth, qué capas usa hoy el juego, cuáles existen y todavía no se aprovechan, y cómo encajan con el
mapa nuevo en celdas (ver `MAPA_CELDAS.md`).

## 1. Qué es

- Un conjunto de mapas del mundo de **dominio público** (se pueden usar, modificar y vender sin pedir permiso ni citar; el juego los cita igualmente en créditos).
- Sitio: naturalearthdata.com. Repositorios en GitHub: `nvkelso/natural-earth-vector` (capas vectoriales, GeoJSON/Shapefile) y `nvkelso/natural-earth-raster`
  (imágenes: relieve sombreado, colores hipsométricos, fondo oceánico).
- Tres escalas: **1:10m** (la más detallada), 1:50m y 1:110m. **El juego usa siempre 10m.**
- Limitación importante: Natural Earth no trae subdivisiones por debajo de «admin-1» salvo EE. UU. (condados, «admin-2»). Por eso Canadá, Brasil, China,
  etc. tienen provincias/estados y no municipios.
- Desde esta versión solo se puede obtener por `git clone` desde github.com (el resto de hosts está bloqueado en el entorno donde se genera el mapa). Los
  scripts leen una carpeta con los `.geojson` ya descargados (`RUTA_NE`).

## 2. Capas que el juego YA usa

| Capa (10m) | Para qué | Dónde se lee |
|---|---|---|
| `admin_0_countries` | Países: fronteras, códigos ISO (`a3`), nombres | `preparar_fuente.py`, `construir_info.py`, `preparar_banderas.py` |
| `admin_1_states_provinces` | Provincias de cada país (y su código ISO 3166-2, de ahí salen las banderas) | `preparar_fuente.py`, `construir_entidades.py`, `preparar_banderas.py` |
| `admin_2_counties` | Condados de EE. UU. (sus «provincias») | `preparar_fuente.py` |
| `lakes` | Lagos (se dibujan como agua sobre las provincias) | `preparar_fuente.py` → `datos/lagos_fuente.json` |
| `populated_places` | Ciudades (población, país, provincia, zoom mínimo) | `construir_entidades.py`, `construir_info.py` |
| `geography_regions_elevation_points` | Picos (altitud máxima de cada lugar) | `construir_info.py` |
| `geography_marine_polys` | Nombres de mares y océanos | `construir_info.py` |
| `bathymetry_A_10000 … L_0` | Profundidad del mar (colores por bandas) | `construir_profundidad.py` |

Lo que NO viene de Natural Earth: altitud de fondo (ETOPO1), fronteras del año 1 d. C. (Cliopatria/Seshat, CC BY 4.0), economía (Banco Mundial),
banderas (varias fuentes libres).

## 3. Capas que existen y todavía no se usan

Nombres según el catálogo publicado de Natural Earth. Antes de usar una capa nueva conviene comprobar su nombre exacto dentro del repositorio clonado.

### Físicas
| Capa | Qué daría al juego |
|---|---|
| `land`, `coastline`, `minor_islands`, `ocean` | Una costa oficial más limpia (hoy la costa sale de unir países y lagos) y las islas menores |
| `rivers_lake_centerlines` (+ `rivers_europe`, `rivers_north_america`) | **Ríos**: líneas para dibujar y una variable «agua dulce / navegabilidad» por celda |
| `glaciated_areas`, `antarctic_ice_shelves_polys` | Hielo: textura del polo y una variable «terreno inhóspito». (0.1.8.39a: `antarctic_ice_shelves_polys` YA se usa para el contorno de la Antártida: Ross, Ronne-Filchner, Amery… se unen a la provincia `ata_00_` con `herramientas/epoca/unir_plataformas.gd`; ver `NOTAS_TECNICAS_0.1.8.39a.md`) |
| `geography_regions_polys` | Desiertos, cordilleras, mesetas, selvas… → variable de tipo de terreno por celda |
| `reefs`, `playas`, `lakes_historic` | Detalles de costa y de lagos secos |
| `geographic_lines` | Ecuador, trópicos, círculos polares (adornos del mapa) |

### Culturales
| Capa | Qué daría al juego |
|---|---|
| `admin_0_map_units`, `admin_0_map_subunits` | Subunidades de un país (islas lejanas, territorios de ultramar) con su propio polígono |
| `admin_0_disputed_areas`, `admin_0_breakaway_disputed_areas` | Zonas en disputa (Cachemira, Crimea, Sáhara Occidental…) |
| `admin_0_boundary_lines_land`, `admin_1_states_provinces_lines` | Líneas de frontera ya construidas (útiles para estilos de línea por tipo de frontera) |
| `urban_areas` | **Áreas urbanas**: variable «urbanización» por celda y manchas en el mapa |
| `roads`, `railroads`, `airports`, `ports` | Infraestructura: logística, comercio y movimiento de tropas |
| `parks_and_protected_lands`, `time_zones` | Zonas protegidas y husos horarios |

### Imágenes (repositorio raster)
| Imagen | Qué es | Uso posible |
|---|---|---|
| Natural Earth I / II (`NE1_*`, `NE2_*`) | Tierra coloreada con relieve sombreado, agua y drenajes | Textura base del terreno |
| `HYP_*` (cross-blended hypsometric tints) | Colores por altitud con relieve sombreado | Textura de relieve con aspecto de atlas |
| `GRAY_*`, `SR_*`, `MSR_*` | Relieve sombreado en grises | **Relieve que se multiplica sobre los colores de los países** (el gancho que trae esta versión) |
| `OB_*` | Fondo oceánico | Textura del mar |

## 4. Cómo encaja con el mapa en celdas

Cada capa nueva se puede traducir de dos maneras, y las dos son compatibles con que la forma de las provincias cambie:

1. **Como variable por celda** (ríos, urbanización, terreno, infraestructura): se calcula una vez al generar el mapa y se guarda en una tabla indexada por
   celda (`celda → valor`). Una provincia suma o promedia las celdas que tiene hoy, de modo que si una celda cambia de provincia su río, su ciudad o su
   terreno se van con ella. Es el mismo principio que ya usan los colores horneados y el área de cada celda.
2. **Como textura o dibujo** (relieve, hielo, ríos como líneas): se dibuja encima de las celdas sin depender de qué provincia las posea, así que cambiar las
   provincias nunca obliga a rehacerlo.

## 5. Cómo se genera el mapa a partir de Natural Earth (resumen)

1. `preparar_fuente.py`: Natural Earth admin-0/admin-1/admin-2 + lagos → `datos/fuente_provincias.json` (provincias de 2026).
2. `construir_mapa.py` (modo celdas): recorta, tría el relleno y construye las mallas compartidas `datos/malla_*`.
3. Escenarios históricos (`herramientas/epoca/`): se cortan las provincias de 2026 con los territorios de la época → las **celdas** son las piezas comunes
   (la subdivisión común más fina de ambos repartos, más subdivisiones por Voronoi en tierras sin reclamar); cada escenario trae solo la tabla «qué celdas
   forman cada provincia» (`provincias_juego.json`) y la geometría es la misma para todos.
4. Para regenerar todo: `python3 -I herramientas/epoca/construir_epoca.py` (unos 3 minutos).

## 6. Siguientes pasos recomendados (cuando se decida meter contenido externo)

1. Relieve: preparar una imagen equirectangular (por ejemplo la versión de relieve sombreado en grises de Natural Earth) con `herramientas/preparar_relieve.py`
   y ponerla en `datos/texturas/relieve.png`. El juego la detecta solo (ver `MAPA_CELDAS.md`, sección «Texturas»).
2. Ríos y urbanización: dos capas nuevas en `herramientas/` que escriban `datos/celda_rios.json` y `datos/celda_urbano.json` (una cifra por celda).
3. Subunidades (`admin_0_map_subunits`): permitirían que territorios de ultramar sean provincias propias desde el primer momento.
