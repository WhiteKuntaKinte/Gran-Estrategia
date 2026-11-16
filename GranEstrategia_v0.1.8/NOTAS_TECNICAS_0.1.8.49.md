# Notas técnicas 0.1.8.49 — 32 edificios nuevos: economía, orden y culto, mando y defensa

Sale de tus mensajes del 2026-11-16 («haz las bases más fuertes… sobre todo creación de contenido y ensamblamiento al juego»). La 0.1.8.48 le dio efectos a los 109 edificios que ya existían; esta versión **añade 32 edificios nuevos**,
cada uno con su descubrimiento, su icono propio, su costo y sus efectos desde el primer día. El catálogo pasa de **109 a 141 edificios** (129 con efecto + 12 «solo saber») y el de descubrimientos de **1.814 a 1.846**
(conocidos en el año 1: 363 → 371; en 2026: 1.783 → 1.815).

## 1. Qué entra
Los 32 salen de una sola tabla (edificio, era, año, requisitos, clase de obra, máximo por provincia, descripción y efectos) y de ahí se generan el catálogo de descubrimientos (tipo B), los años, el catálogo de edificios, los efectos y los iconos.
Cada uno tiene su descubrimiento de tipo B con requisitos reales ya existentes en el árbol y un año histórico (los 8 de la Antigüedad —talleres artesanos, palacios de gobierno, molinos hidráulicos, caravasares, tribunales, templos y pagodas, teatros, cuarteles— cuentan en el año 1).

**Economía y comercio (SOC.ECO)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Talleres artesanos | 3000 a. C. | B | 4 | producción 0.02 · 40 mil hab. |
| Casas de gremio | 1250 | C | 2 | producción 0.02 · 150 mil hab.; orden y cohesión 1.5 · 150 mil hab. |
| Caravasares y posadas de camino | 200 a. C. | B | 4 | movilidad 0.05 · —; producción 0.015 · 100 mil hab. |
| Bancos y casas de cambio | 1397 | C | 2 | producción 0.04 · 300 mil hab. |
| Lonjas y bolsa de valores | 1611 | D | 1 | producción 0.05 · 600 mil hab. |
| Centros comerciales | 1956 | D | 3 | producción 0.03 · 1 M hab.; vivienda y ciudad 0.02 · 1 M hab. |

**Energía (CIE.ENE)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Molinos hidráulicos | 20 a. C. | B | 4 | producción 0.03 · 150 mil hab.; comida segura 2 · 150 mil hab. |
| Molinos de viento | 1190 | B | 4 | producción 0.025 · 120 mil hab.; comida segura 2 · 120 mil hab. |

**Transporte (CIE.TRA)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Astilleros | 1104 | D | 2 | producción 0.04 · 300 mil hab.; movilidad 0.05 · — |
| Estaciones de ferrocarril | 1830 | D | 2 | movilidad 0.2 · —; producción 0.04 · 800 mil hab. |
| Puertos de contenedores | 1960 | F | 1 | producción 0.06 · 3 M hab.; movilidad 0.1 · — |

**Manufactura (CIE.MAN)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Altos hornos | 1490 | D | 2 | producción 0.06 · 800 mil hab. |
| Fábricas de vapor | 1790 | D | 3 | producción 0.07 · 1 M hab. |
| Acerías | 1865 | E | 2 | producción 0.08 · 1.5 M hab. |
| Parques industriales | 1960 | E | 2 | producción 0.05 · 2 M hab. |

**Derecho (SOC.LEY)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Tribunales y audiencias | 450 a. C. | C | 2 | orden y cohesión 2 · 200 mil hab. |
| Prisiones | 1790 | C | 2 | orden y cohesión 2 · 300 mil hab. |
| Comisarías y cuarteles de policía | 1830 | C | 3 | orden y cohesión 3 · 400 mil hab. |

**Gobierno (SOC.GOB)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Casas consistoriales | 1250 | C | 1 | orden y cohesión 2.5 · 150 mil hab. |
| Palacios de gobierno | 2000 a. C. | D | 1 | orden y cohesión 2.5 · 300 mil hab. |
| Palacios del parlamento | 1690 | E | 1 | orden y cohesión 3.5 · 1 M hab. |

**Religión y cultura (SOC.REL)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Iglesias parroquiales | 350 | B | 5 | orden y cohesión 2 · 60 mil hab. |
| Mezquitas | 700 | C | 3 | orden y cohesión 2.5 · 100 mil hab. |
| Templos y pagodas | 250 a. C. | C | 3 | orden y cohesión 2 · 100 mil hab. |
| Teatros y anfiteatros | 450 a. C. | C | 2 | orden y cohesión 2 · 100 mil hab. |
| Estadios deportivos | 1896 | D | 2 | orden y cohesión 2 · 500 mil hab. |

**Sociedad civil (SOC.CIV)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Casas del pueblo y sedes sindicales | 1880 | C | 2 | orden y cohesión 2.5 · 300 mil hab. |

**Mando y logística (MIL.LOG)**

| Edificio | Año | Obra | Máx. | Efecto (peso · atiende) |
|---|---|---|---|---|
| Cuarteles y guarniciones | 300 a. C. | C | 3 | defensa 0.15 · — |
| Polvorines | 1505 | C | 2 | defensa 0.08 · — |
| Cuarteles de estado mayor | 1810 | D | 1 | defensa 0.2 · — |
| Estaciones de radar | 1942 | E | 2 | defensa 0.3 · — |
| Centros de mando y control | 1972 | E | 1 | defensa 0.25 · — |

- **Clases de obra y costo:** salen de la misma tabla de clases de siempre (B pequeña: 0,4 % de la producción anual de la provincia y 45 días; C mediana: 1,2 % y 120 días; D grande: 3 % y 330; E monumental: 7 % y 800; F megaproyecto: 15 % y 1.800).
- **Iconos:** 32 PNG de 128 px dibujados por código con las mismas piezas de los demás (`herramientas/iconos_materias/edificios.py`); sin imágenes de terceros. Dos se rehicieron tras verlos en una hoja de contacto (teatro y acería).
- **Datos regenerados:** `herramientas/descubrimientos/catalogo/z_ciudad_estado_0.1.8.49.txt` (nuevo), `anios.tsv`, `construir_edificios.py` (E), `construir_efectos_edificios.py` (EFECTOS) → `datos/descubrimientos.json`, `datos/edificios.json`, `datos/edificios_efectos.json`.

## 2. Decisiones de diseño (y por qué)
- **Secciones fuera de los índices de saber:** todos los descubrimientos nuevos están en secciones que NO alimentan los cuatro índices de saber (medicina, agricultura, educación, ingeniería / territorio), así que **la calibración demográfica no se mueve** (runner104 sigue dando 254 M / 468 M / 8.349 M con los mismos ritmos).
- **Efectos modestos y coherentes con la regla de partida:** los edificios nuevos que producen (talleres, molinos, bancos, fábricas, acerías...) solo suman lo construido DESPUÉS de empezar, como todos; los de orden y defensa cuentan todo. Los pesos están pensados para que una provincia mediana note una docena de edificios, no uno.
- **Por qué «mov» y «def» son planos:** el cuartel, el polvorín, el estado mayor, el radar y el centro de mando dan defensa fija a la provincia (suma a los defensores en la guerra) y no atienden habitantes; los caravasares, los astilleros, el ferrocarril y el puerto de contenedores dan movilidad (la lejanía de la capital pesa menos).
- **Cuántos máximos por provincia:** 1 para lo monumental (lonja, parlamento, palacio, casa consistorial), 2–4 para lo mediano, 5 para las iglesias parroquiales: así un país grande necesita muchas provincias construidas para notar el efecto.

## 3. Sorpresa que encontré (y cómo quedó)
- **La ventana Construir con un país entero pasó de 400 ms** (468 ms con 141 filas × todas las provincias de España): por cada fila y cada provincia se llamaba a `puede` y a `costo_local` (dos veces `ingreso_anual_usd`). Como el costo de cualquier edificio es «su fracción × lo que vale la provincia», ahora la ventana calcula lo que vale cada provincia **una vez** (`Edificios.base_local`) y lo reutiliza en todas las filas (`puede_con_costo`). Medido en runner83: **468 → 173 ms**.
- **Repartir los edificios de partida costaba más con 141 edificios** (2026: 1.551 ms con 109 → 2.050 ms con 141, 989.361 edificios sembrados en vez de 686.874). Tres arreglos sin cambiar el resultado (mismo total, mismos textos): `cantidad_inicial` recibe el umbral que ya tiene calculado quien la llama (no lo busca en un diccionario un millón de veces), los números salen de una tabla de textos en vez de `str()`, y las sumas de efectos de orden, defensa y movilidad de lo sembrado se acumulan en el mismo recorrido (solo esas tres clases cuentan lo de partida) en vez de volver a leer el texto de cada provincia (`_dict_de_texto` + `_sumas`, ~140 µs por provincia). Resultado: **2026 ~1.010 ms (antes 1.551), 1500 ~260 ms (antes 395)**, es decir, la partida arranca más rápido que en la 0.1.8.48 con 32 edificios más. (Probé también calcular esas sumas «al primer uso»: ahorraba aún más al arrancar pero movía ~1 s a los primeros 30 días de juego, ~36 ms por día en la fase de estabilidad; lo descarté.)

## 4. Rendimiento
Medido con `test/runner89` (headless, un día con todas las IA, 120 días) contra una copia de la 0.1.8.48, 3 pares seguidos por escenario, CPU en reposo:

| Escenario | 0.1.8.48 | 0.1.8.49 | Diferencia |
|---|---|---|---|
| 2026 (249 IA), pares 1 / 2 / 3 | 14,03 / 12,98 / 12,97 ms | 14,16 / 13,93 / 12,55 ms | media 13,33 → 13,55 ms (+0,2 ms, dentro del ruido) |
| 1500 (202 IA), pares 1 / 2 / 3 | 5,75 / 5,50 / 5,55 ms | 5,71 / 6,14 / 5,52 ms | media 5,60 → 5,79 ms (+0,2 ms, dentro del ruido) |

- **El día de juego no cambia de forma medible:** los 32 edificios nuevos no añaden ninguna fase y la diferencia (+0,2 ms) está dentro de la variación entre pares (hasta 1 ms entre repeticiones del mismo código).
- **Memoria:** 444 → 445 MB en 2026; 289 → 294 MB en 1500 (más edificios sembrados y 32 iconos que solo se cargan al abrir Construir).
- **Arranque:** los edificios de partida (`sembrar_iniciales`) en 2026 pasan de 1.551 ms (0.1.8.48) a ~1.010 ms con los 141 edificios (sin los arreglos de §3 serían 2.050 ms); en 1500 de 395 ms a ~260 ms.
- **Ventana Construir con un país entero:** 468 ms → 173 ms (ver §3).
- **Mapa y zoom:** no se tocó nada del dibujo ni de `_actualizar_zoom` (6,9 ms por fotograma como en la 0.1.8.48).

## 5. Revisión de variables
`python3 herramientas/auditar_codigo.py`: **1.693 funciones, 0 funciones repetidas, 0 variables repetidas.** Nuevas: `Edificios.base_local`, `Edificios.puede_con_costo`, `Edificios._abs_de`, `_ef_abs_de`, `_NUM_TXT` (todas tienen uso fuera de su definición; revisado a mano porque la auditoría no lista lo que no se usa). `datos/variables.json` no cambió.

## 6. Pruebas
- **Ajustadas a los conteos nuevos:** runner77 (1.846 / 1.815 / 371), runner83 (141 edificios), runner88 (141 iconos), runner91 y runner102 (1.846), runner106 (129 con efecto + 12 de solo saber).
- Regresión completa runner71–107: ver `CHECKLIST_TESTING.md`.

## 7. Límites y lo que sigue
- Los 32 nuevos usan los mismos pesos provisionales de la 0.1.8.48 (clase por clase): si ves algo que rinde demasiado o que la IA nunca construye, mándame el F9 y la fecha.
- Siguen fuera: mantenimiento de edificios, ruinas por guerra, edificios que consuman materias primas, y que los oficios pesen en la economía.
- Siguiente posible: más descubrimientos NO edificio con enlaces entre ramas (secciones fuera de los índices de saber), migración entre provincias, epidemias y burocracia.
