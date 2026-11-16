# Notas técnicas 0.1.8.50 — Tejido del saber II: 36 descubrimientos y 41 enlaces entre ramas

Sale de tus mensajes del 2026-11-16 («desarrolla y añade más descubrimientos y dependencias, haz las bases más fuertes»). La 0.1.8.46 y la 0.1.8.47 tejieron las ramas con 41 + 43 descubrimientos y 49 + 16 enlaces; esta versión añade
**36 descubrimientos nuevos** (1.846 → **1.882**; en 2026 la historia conoce 1.851; el año 1 sigue en 371) y **41 enlaces extra entre ramas** con su porqué (65 → **106**).
No son edificios: son saberes que faltaban entre lo que ya existía y lo que depende de ellos (de la central eléctrica a la red nacional, del satélite al GPS civil, del derecho del mar al derecho espacial).

## 1. Qué entra
Todo sale de una tabla (rama, sección, subsección, año, tipo y requisitos) y de ahí se generan `catalogo/z_tejido_0.1.8.50.txt`, las filas de `anios.tsv` y los enlaces nuevos de `enlaces.txt`; el generador valida todo (requisitos que existen, sin ciclos, año ≥ año de cada requisito, año dentro de la era).

**Energía (CIE.ENE)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Central eléctrica pública | 1882 | técnica | dinamo, lampara electrica |
| Oleoductos y gasoductos | 1865 | técnica | petroleo perforacion, acero bessemer |
| Red eléctrica nacional | 1926 | institución | central electrica, transformador alterna, presupuesto nacional |
| Electrificación rural | 1935 | institución | red electrica nacional, motor electrico |
| Centrales nucleares civiles | 1954 | técnica | reactor nuclear, red electrica nacional |
| Eficiencia y etiquetado energético | 1975 | institución | red electrica nacional, derecho ambiental |
| Mercado eléctrico y tarifas | 1990 | institución | red electrica nacional, contabilidad publica |

**Electrónica (CIE.ELE)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Telefonía automática (conmutador) | 1891 | técnica | telefono |
| Televisión en color | 1953 | técnica | television electronica |
| Navegación satelital civil | 2000 | técnica | gps militar, telefonia celular digital |

**Computación (CIE.COM)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Hoja de cálculo | 1979 | técnica | computadora personal, lenguajes alto nivel |
| Software libre y código abierto | 1991 | institución | sistema operativo, internet tecnologia |
| Firma y documentos digitales | 1995 | institución | criptografia clave publica, contratos escritos |
| Cibernética y control por realimentación | 1948 | conocimiento | circuitos logicos, programa almacenado |

**Transporte (CIE.TRA)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Ferrocarril transcontinental | 1869 | técnica | locomotora vapor, rieles hierro, telegrafo electrico |
| Señalización ferroviaria y semáforos | 1868 | técnica | locomotora vapor, telegrafo electrico |
| Transporte aéreo supersónico | 1969 | técnica | motor jet civil, rec aleantes |
| Carga aérea y mensajería exprés | 1976 | técnica | aviacion comercial, logistica just in time |
| Transporte por plataforma | 2009 | técnica | economia plataformas, navegacion satelital civil |

**Manufactura (CIE.MAN)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Fábrica electrificada | 1910 | técnica | central electrica, motor electrico, cadena montaje |

**Economía (SOC.ECO)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Aduanas y proteccionismo arancelario | 1664 | institución | mercantilismo, sistema tributario |
| Regulación bancaria tras las crisis | 1933 | institución | banca central, bolsa valores |

**Gobierno (SOC.GOB)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Descentralización administrativa | 1982 | institución | federalismo, burocracia moderna |
| Referéndum y consulta popular | 1848 | institución | democracia directa, democracia representativa |

**Derecho (SOC.LEY)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Derecho del mar | 1982 | institución | derecho internacional clasico, navegacion oceanica |
| Derecho aéreo y aviación civil | 1944 | institución | aviacion comercial, derecho internacional clasico |
| Derecho espacial | 1967 | institución | tratados desarme, satelite comunicaciones |
| Marcas y diseño industrial | 1857 | institución | patentes propiedad intelectual, produccion en serie |
| Derecho de quiebras | 1300 | institución | derecho mercantil, credito prestamo |

**Diplomacia (SOC.DIP)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Pasaportes y control de fronteras | 1914 | institución | diplomacia permanente, registro civil |
| Extradición | 1833 | institución | derecho internacional clasico, policia moderna |
| Asilo y estatuto de los refugiados | 1951 | institución | derechos humanos universales, cruz roja humanitaria |

**Comunicación (SOC.COM)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Censura previa y licencias de imprenta | 1559 | institución | imprenta, derecho canonico |

**Religión y cultura (SOC.REL)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Cine sonoro | 1927 | técnica | cine, fonografo grabacion |

**Sociedad civil (SOC.CIV)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Parques nacionales y conservación | 1872 | institución | romanticismo, asociaciones civicas |

**Logística y mando (MIL.LOG)**

| Descubrimiento | Año | Tipo | Requisitos |
|---|---|---|---|
| Servicios topográficos militares | 1820 | técnica | cartografia militar, mapas geologicos |

**Enlaces extra** (41 en total; algunos ejemplos, el resto está en `herramientas/descubrimientos/enlaces.txt`):
- **television satelite cable** ← satelite comunicaciones: Los canales por cable y satélite viven de los satélites de comunicaciones.
- **smartphone adopcion** ← telefonia celular digital: El teléfono inteligente se apoya en la red celular digital.
- **internet publico** ← navegador buscador: Sin navegador el público no entra a la red.
- **comercio electronico** ← cifrado web ssl: Pagar en línea exige un canal cifrado.
- **redes sociales** ← www web: Las redes sociales nacen sobre la web.
- **streaming video** ← fibra optica: El vídeo en línea necesita la banda ancha de la fibra.
- **cadenas suministro globales** ← contenedor maritimo: Sin contenedores no hay cadenas de suministro globales.
- **logistica just in time** ← codigo barras inventario: Entregar justo a tiempo exige saber qué hay y dónde.
- **mercados financieros globales** ← satelite comunicaciones: Los mercados operan sin pausa gracias a las comunicaciones por satélite.
- **derivados financieros** ← computadora personal: Valorar derivados exige cálculo en cada mesa de operaciones.
- **banca electronica** ← computadora digital: La banca electrónica corre sobre computadoras digitales.
- **tarjeta credito** ← credito consumo: La tarjeta es el crédito al consumo hecho plástico.
- …y 29 más: comercio electrónico ← cifrado web, cadenas de suministro ← contenedor, guerra relámpago ← radio de campaña, tabuladora de Hollerith ← censo periódico, derecho ambiental ← movimiento ecologista, ONG ← Cruz Roja, etc.

## 2. Decisiones de diseño (y por qué)
- **Fuera de los índices de saber:** todas las secciones tocadas son de energía, electrónica, computación, transporte, manufactura, economía, gobierno, derecho, diplomacia, comunicación, cultura, sociedad civil y logística militar; ninguna alimenta los cuatro índices de saber (medicina, agricultura, educación, ingeniería y territorio), así que **la demografía queda igual** (runner104 sin cambios).
- **Cada descubrimiento nuevo cruza ramas:** el GPS civil pide el GPS militar y el teléfono celular; el taxi por plataforma pide la economía de plataformas y la navegación satelital; el derecho espacial pide los tratados de desarme y el satélite; el transporte supersónico pide los motores a reacción civiles y las aleaciones (recurso del territorio).
- **Los enlaces solo suman requisitos que ya eran históricamente ciertos** (el requisito es anterior o del mismo año), así que con «historia fija» no cambia nada y con «el planeta descubre» las cosas se descubren después de aquello de lo que dependen.
- **Se descartaron 3 candidatos que ya existían** (central hidroeléctrica, metro subterráneo y zonas económicas especiales ya estaban como edificios del catálogo): el generador avisó de los duplicados.

## 3. Rendimiento
Los 36 descubrimientos y los 41 enlaces son **datos** (`datos/descubrimientos.json`): no hay código nuevo en el día de simulación.

- `runner89` (simular 1 día con todas las IA, 3 pares seguidos 0.1.8.49 → 0.1.8.50): **2026 12,7 → 12,6 ms** y **1500 6,0 → 6,3 ms** por día (promedio de 3; diferencias dentro del ruido de la máquina).
- `runner101` (coste del motor de descubrimientos): 2026 0,93 ms/mes (peor 1,9) y 1500 0,45 ms/mes (peor 1,6), igual que en la 0.1.8.48 (0,92 / 0,44): sumar 36 saberes y 41 enlaces no se nota.
- Arranque: el catálogo pasa de 1.846 a 1.882 filas (+2 %); la carga del JSON y los índices de `descubrimientos.gd` no cambian de forma.

## 4. Revisión de variables
`python3 herramientas/auditar_codigo.py`: **1.693 funciones, 0 funciones repetidas, 0 variables repetidas** (igual que la 0.1.8.49: no se tocó código del juego). No hay funciones ni variables nuevas en `scripts/`; la única función nueva es `t_tejido_050` de `test/runner102.gd` (se llama desde `run`). `datos/variables.json` no cambió.

## 5. Pruebas
- **runner102** (cimientos del saber) estrena `t_tejido_050`: los 36 slugs existen, los 41 enlaces nuevos están en los prerrequisitos de su descubrimiento, ninguno pide algo posterior en el tiempo, cada uno trae su porqué, la red eléctrica nacional abre la electrificación rural, la central nuclear civil y el mercado eléctrico, el taxi por plataforma pide la navegación satelital civil y ninguno cae en una sección de los índices de saber: **39 OK, 0 FALLOS**.
- Conteos ajustados: **runner77** y **runner91** (1.882 descubrimientos; 2026: 1.851), **runner102** (1.882 en 40 secciones; 1.480 en la comprobación de orden).
- **Regresión completa runner71–107** (runner74 con ventana virtual): **0 fallos** en todas. **runner104** (calibración demográfica) sin cambios: 75 comprobaciones.
- Rendimiento y auditoría: secciones 3 y 4.

## 6. Límites y lo que sigue
- Los 36 nuevos no tienen efectos propios: son saberes del árbol (alimentan lo que depende de ellos y las recetas de edificios y materias que el generador les asigna solo).
- Siguiente posible: más descubrimientos en las secciones de saber (necesitan recalibrar la demografía), migración entre provincias, epidemias y burocracia.
