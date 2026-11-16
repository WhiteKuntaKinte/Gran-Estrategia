# Demografía viva, educación y presupuesto (0.1.8.47)

Hasta la 0.1.8.46 la población era un dato fijo. Desde la 0.1.8.47 cada provincia nace, muere, aprende y se muda a la ciudad, y todo
depende de **lo que su país sabe** (el catálogo de descubrimientos) y de **cuánto de eso llega a la gente** (la renta por habitante).
No hay una tabla por época: el mismo modelo da el mundo de hace 2.000 años y el de hoy, y cambia si el planeta descubre antes o después.

**TODAS las constantes son PROVISIONALES** (calibradas a ojo contra datos históricos de orden de magnitud; ver «Calibración»). Si Camilo
ve algo raro, se cambia una constante en `scripts/demografia.gd` o `scripts/educacion.gd`, no el diseño.

## Piezas

| Archivo | Qué hace |
|---|---|
| `scripts/indices_saber.gd` | 4 índices de saber por país (0-1), contados del catálogo de descubrimientos: **salud** (65 % MED + 35 % SAL), **agricultura** (80 % AGR + 20 % BIO), **educación** (70 % EDU + 30 % HUM), **urbanismo** (50 % TER + 50 % ING). Cada país se refresca una vez al año (rotando). También `campo(clave)` y `fraccion_campo(tid, clave)` (qué parte de un campo conoce un país; `CIE.COM` y `SOC.COM` distinguen las dos ramas con código `COM`). |
| `scripts/demografia.gd` | La fase del día `Demografia.fase_dia`: revisa 1/120 de las provincias por día (lotes de 70) con el tiempo REAL desde su última revisión (pasos exactos en forma cerrada: da lo mismo revisar cada mes que cada año). Escribe directo en las columnas de la base. Acumula las medias por país y las publica al cerrar cada vuelta. También la **fatiga de guerra** (por país, cada 30 días) y la calidad de los docentes. |
| `scripts/educacion.gd` | Capacidad de investigar (`factor_capacidad`), **política de investigación** (`factor_rama` / `factor_seccion`), difusión (`factor_difusion`), los **40 oficios** (`fuerza_laboral`) y las **decisiones de presupuesto de las IA** (`decidir_ia`, que escribe las partidas con `_poner_gasto`: directo en la columna, sin historial ni subir `version_eco`). |
| `datos/carreras.json` | Los 40 oficios (lo genera `herramientas/construir_carreras.py`; **no editar a mano**). |
| `herramientas/anadir_variables_047.py` | Añade las 15 variables nuevas a `datos/variables.json` (idempotente). |

## Variables nuevas (ids 62-76)

`natalidad`, `mortalidad` (‰ al año), `edad_joven`, `edad_mayor` (fracciones), `urbanizacion`, `alfabetizacion` (0-1), `escolaridad_media` (años),
`bienestar` (0-100), `instituciones_saber` (puntos de escuelas, universidades, academias y bibliotecas de la provincia, ponderados por clase),
`fatiga_guerra` (0-100, por país), `calidad_docentes` (0-100, por país) y las cuatro partidas del presupuesto `gasto_educacion`, `gasto_ciencia`,
`gasto_obras`, `gasto_sanidad` (fracción de los impuestos, por país). Ninguna guarda historial anual (columnas de 37.000 filas: sería memoria perdida).

## El modelo

* **Natalidad**: `42,4 ‰ × (1 − baja) × (0,8 + 0,4 × bienestar/100) × (1 − 0,35 × devastación)`, con
  `baja = 0,50 × alfab^1,2 + 0,16 × urbanización + 0,18 × acceso^1,3 + 0,05 × salud`. Mínimo 7 ‰.
* **Mortalidad**: `44 ‰ × (1 − 0,70 × sig((S − 0,55)/0,12) − 0,20 × sig((S − 0,30)/0,15)) × (0,85 + 3,2 × mayores)` + hambre (bienestar < 30) + guerra
  (devastación, ocupación) + freno maltusiano (solo en sociedades agrarias que pasan el límite de la tierra). `S` = salud efectiva = resiliencia × acceso × gasto
  en sanidad; la **resiliencia** es 55 % saber de salud + 45 % saber de agricultura. La sigmoide moderna (centro 0,55) es «la medicina de verdad»: casi nada hasta
  que el saber madura, luego la mortalidad cae de golpe. Mínimo 1,5 ‰.
* **Edades**: niños y mayores siguen a la natalidad con τ = 35 años. La gente activa es `(1 − niños − mayores) × 0,78`.
* **Urbanización** (τ 40 años), **alfabetización** (τ 30; más rápido con más gasto en educación) y **escolaridad** (τ 25) se acercan a su meta; el **bienestar**
  (τ 1 año) a la suya (comida, vivienda, salud, paz).
* **Acceso** al saber: `log(renta/300) / log(200)` (300 US$ → 0; 60.000 US$ → 1).
* **Economía según el saber**: el crecimiento mensual de la renta (`crecimiento_base_anual` × velocidad) se multiplica por `clamp((K/0,8)³, 0,01, 1)`, con
  K = media de los 4 índices. Sin esto la renta crecía 2 % al año en cualquier época y en 200 años el mundo del año 1 era 50 veces más rico sin descubrir
  nada (y la natalidad bajaba por «renta» sin haber escuelas). Con todo el saber de hoy el factor vale 1: **2026 no cambia**.

## Efectos sobre el resto del juego

* **Estabilidad**: el bienestar de la provincia entra en la meta (de −8 a +5; neutro en 58) y la fatiga de guerra del país resta hasta 12.
* **Presupuesto**: las partidas se descuentan de los impuestos antes de la tesorería (`Mundo.ingreso_neto_diario_local`). Con las de referencia (educación 4 %,
  ciencia 1,5 %, obras 2,5 %, sanidad 2 %) todo rinde ×1; el total no pasa del 60 % y cada partida del 30 %.
* **Descubrimientos**: el peso de un país en el sorteo de «quién descubre» (`Saber._descubrir`) se multiplica por su capacidad de investigar (de ×0,5 a ×1,5:
  investigadores = gente con estudios superiores × gasto en ciencia × política científica) y por el factor de su política de investigación para la rama de lo que se
  descubre (de ×0,25 a ×2,2). El tiempo que tarda en enterarse de lo que descubren otros se divide por ×0,8-1,3 según su alfabetización.
* **Guerra**: las bajas en combate (`Guerra._sub_ronda`) suben la fatiga de guerra (`2.500 puntos por cada 100 % de la población`; +0,10 por día en guerra; baja
  con τ = 540 días en paz).
* **IA**: una IA activa revisa su presupuesto cada mes (`Educacion.decidir_ia`): recorta en guerra, austeridad si la caja se vacía, invierte si sobra; no gasta en
  escuelas ni ciencia que su país aún no conoce; en guerra apunta su investigación a lo militar, en paz a la ciencia. Lo que lleva el jugador o fijó a mano no se toca.
  El ejército de la IA se limita por la gente en edad activa: nunca pasa de `MAX_ACTIVA_EJERCITO` = 3,2 % de ella (~1,5 % de la población), además de los topes de siempre
  (un país envejecido o poco poblado puede reclutar menos). Con los ingresos **netos** de las partidas del presupuesto (`ing` de la foto de la IA).
* **Fatiga de guerra → guerra y paz** (`ia.gd`): con fatiga ≥ `FATIGA_NO_ATACA` (30) un país no declara guerras nuevas; con ≥ `FATIGA_PIDE_PAZ` (45) y al menos
  `PAZ_CANSADA_DIAS` (60) de guerra pide la paz aunque vaya perdiendo (motivo «cansancio»; cada uno se queda con lo que ocupa).
* **Interfaz**: tarjeta «Saber social» en la ficha del país (los 4 índices, gente activa, oficios) y Debug > Gente (índices, demografía y presupuesto de un país, fatiga editable,
  avance de días con el reloj real).
* **Día de 10 fases**: economía, IA, diplomacia, estabilidad, **demografía**, ejército, obras, llegadas, batallas, ocupaciones.

## Los 40 oficios

Cada oficio tiene nivel de estudios (0 agrario · 1 oficio · 2 secundaria · 3 superiores), un campo del catálogo del que depende y una fracción mínima (`desde`)
de ese campo para existir (sin cirugía descubierta no hay cirujanos). Reparto (`Educacion.fuerza_laboral`): los **agrarios** se llevan `(0,95 − urbanización^0,9) ×
(1 − 0,85 × saber de agricultura × acceso)` de la gente activa, tomada de los que menos estudios tienen; el resto, por nivel de estudios (primaria / secundaria /
superiores, según los años de escuela), elige entre los oficios de su nivel o de uno menor (×0,35 por cada nivel de diferencia). Los soldados pesan ×3 en guerra.
Hoy es información (ficha del país, Debug) y la base de efectos futuros (médicos que bajan la mortalidad, maestros que suben la alfabetización).

## Calibración (cifras de las pruebas `runner104`)

| Escenario | Población | Natalidad / mortalidad | Crecimiento | Urbana | Alfabetizada | Niños / 65+ |
|---|---|---|---|---|---|---|
| Año 1 | 254 M | 39,8 / 39,2 ‰ | +0,06 %/año (+50 años: 263 M) | 6 % | 2 % | 38 % / 3 % |
| 1096 | 367 M | ~38 / ~38 ‰ | −0,05 %/año | — | — | — |
| 1500 | 468 M | ~38 / ~38 ‰ | −0,03 %/año | 9 % | 7 % | 37 % / 3 % |
| 2026 | 8.349 M | 15,7 / 8,1 ‰ | +0,76 %/año | 64 % | 87 % | 18 % / 14 % |

Valores históricos de referencia: ~250 M en el año 1, ~400 M en 1100, ~460-500 M en 1500; hoy ~8.200 M con ~0,9 %/año. El crecimiento de 2026 se acelera con el
tiempo por efecto de composición (11,5 mil millones a +40 años frente a los ~10,2 de la ONU): conocido, aceptado por ahora.

**Aviso sobre el catálogo.** Los índices de saber son la *fracción de secciones conocidas* de cada campo: si se añaden descubrimientos a una sección, los índices
de las épocas antiguas bajan (el denominador crece) y la natalidad y la mortalidad del año 1 se mueven. La 0.1.8.47 añadió 43 descubrimientos (`z_gente_0.1.8.47.txt`)
y por eso `MORT_MAX` pasó de 45 a 44. **Tras ampliar el catálogo, correr `runner104` y retocar `MORT_MAX` / `NAT_MAX` si el año 1 o el 1500 dejan de estar en ~0 %/año.**

## Coste

| Medida | Valor |
|---|---|
| Repaso de provincias (`fase_dia`, 70 por lote) | 2026 ~0,9 ms por día de juego; 1500 ~0,4 ms |
| Fase completa (con la parte de países y las decisiones de las IA) | 2026 ~1,5 ms por día; 1500 ~0,8 ms |
| Un día entero con todas las IA (runner89 / banco propio) | 2026: 11,0 → 12,7 ms (+1,75); 1500: 3,3 → 5,2 ms (+1,85), media de 3 pares, respecto a la 0.1.8.46 |
| `sembrar()` al empezar | ~80 ms (2026) |
| Memoria | +16 columnas de 37.359 filas ≈ +7 MB |

## Límites conocidos / siguiente

* **Dos trampas de coste que ya se evitaron** (medidas con un banco por fase): (1) cambiar las partidas del presupuesto por el setter de `Pais` sube `version_eco` y rehace
  el balance de ~250 países en `_economia_dia` (de 0,5 a 7 ms por día) y guarda historial: por eso `Educacion._poner_gasto` escribe la columna directo y avisa con
  `Mundo.marcar_balance(tid)`; (2) `balance_diario_local` recalcula los soldados de todos los países cuando cambió el ejército (~3 ms con 250 IA): la IA usa
  `Mundo.balance_diario_rapido`, que lee la fila de balance y los soldados del último día de economía (puede llevar un día de retraso; da igual para una decisión mensual).
* Pendiente de coste (viene de antes, no de la demografía): `Ejercito.soldados_por_pais` recorre todos los pelotones una vez al día (~3 ms en 2026); llevar la cuenta
  por país de forma incremental lo dejaría casi gratis.
* Los oficios todavía no mueven la economía ni la mortalidad (solo se muestran).
* La población no migra entre provincias (solo crece o decrece en su sitio).
* No hay epidemias, hambrunas por clima ni catástrofes: el bienestar baja solo con la tierra, la guerra y la ocupación.
* La política de investigación y las partidas de los demás países son visibles; no hay espionaje que las oculte.
