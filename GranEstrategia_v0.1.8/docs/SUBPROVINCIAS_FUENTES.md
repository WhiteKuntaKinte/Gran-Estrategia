# Subprovincias: de dónde sacar los límites (decisión para la 0.1.8.43)

> **DECIDIDO (2026-11-13): opción B — límites reales de geoBoundaries ADM2 (compuesto CGAZ, CC BY 4.0), con el crédito «geoBoundaries (William & Mary geoLab), CC BY 4.0» visible en el juego y en LEEME.txt.**
> Implementado en la 0.1.8.43 (`scripts/subprovincias.gd`, `scripts/capa_subprovincias.gd`, `herramientas/subprovincias/`, `datos/subprov/`); ver `NOTAS_TECNICAS_0.1.8.43.md` sección 4. El análisis de abajo se conserva como registro.

Camilo pidió (2026-11-12) investigar la opción de **límites reales con atribución** y decidir él al empezar la 0.1.8.43.
Objetivo del diseño: país → provincia → subprovincia (como estado → condado en EE. UU.), doble clic en una provincia para ver sus subdivisiones.
Condición del proyecto: **Camilo puede vender el juego**; todo lo que entre debe permitir uso comercial. (No soy abogado: lo de abajo es lectura de las condiciones publicadas, hay que releerlas antes de publicar.)

## Fuentes revisadas

| Fuente | Cobertura | Licencia / condición | ¿Sirve para vender? |
|---|---|---|---|
| **Natural Earth** Admin 2 (condados) | **Solo EE. UU.** (el resto de países no tiene nivel 2) | Dominio público (la política general de Natural Earth) | Sí, sin atribución. Ya se usa. |
| **Natural Earth** lugares poblados (`populated_places`) | Mundial, ~7.300 ciudades con población | Dominio público | Sí, sin atribución. |
| **geoBoundaries** (CGAZ, compuesto simplificado) | **Mundial: 199 países, niveles ADM0, ADM1, ADM2** (ADM2 = distrito/municipio/condado) | **CC BY 4.0** para el compuesto; los límites originales (`gbOpen`) traen cada uno su licencia fuente (CC BY, ODbL, CC BY-SA, licencias nacionales, dominio público) | Sí **con atribución** (créditos del juego). Los originales con ODbL / CC BY-SA obligan a compartir igual: hay que quedarse con el compuesto CGAZ o filtrar. `gbAuthoritative` es **solo no comercial: no usar**. |
| **GADM** | Mundial | No comercial sin permiso | **No.** |
| **Eurostat GISCO** (NUTS / LAU) | Europa | «No para fines comerciales»; uso comercial con licencia de EuroGeographics; aviso «© EuroGeographics para los límites administrativos» | **No** (sin licencia aparte). |
| **OpenStreetMap** | Mundial | ODbL: si se mezcla con datos propios o se mejora, **hay que publicar la base resultante con la misma licencia**; cobrar solo cubre el coste de entrega | Riesgoso: obligaría a abrir las subprovincias del juego. Evitar. |
| Fuentes oficiales por país (Statistics Canada, IGN Francia, IGN España, ISTAT, BKG, ONS, INEGI, IBGE…) | País por país | Casi todas «licencia abierta + atribución», pero **cada una distinta** | Posible, pero es un proyecto aparte por país. |
| **OCHA COD-AB / HDX** | Países en desarrollo, ADM2 | Mayoría CC BY-IGO | Sí con atribución, cobertura irregular. |

## Opciones

**A. Procedimental (propuesta por defecto).** Cada provincia del juego (ya hecha de celdas) se parte en subprovincias con un reparto tipo Voronoi sembrado en los lugares poblados de Natural Earth (la ciudad más grande da el nombre y el centro). Sin licencia, sin atribución, funciona en **todo el planeta y en las 4 épocas**, y las formas pueden cambiar con el tiempo (cesión parcial, conquista) porque son celdas del propio juego. Contra: las fronteras interiores no son las reales.

**B. Límites reales con geoBoundaries ADM2 (CC BY 4.0).** Subprovincias reales en todo el mundo, con nombres reales. Hay que mostrar «geoBoundaries (William & Mary geoLab), CC BY 4.0» en los créditos del juego y en el LEEME. Contras: (1) son límites de ~2020: **anacrónicos** para 1 d. C., 1096 y 1500; (2) ~50.000 unidades en el mundo: más peso y más tiempo de dibujo (hay que simplificarlas y encajarlas en las celdas); (3) los límites exteriores de ADM2 no coinciden exactamente con nuestras provincias: hay que recortar/ajustar; (4) un solo proveedor del que dependemos; (5) la obligación de atribuir queda para siempre.

**C. Mixta.** EE. UU. con los condados de Natural Earth (dominio público, ya está), y el resto procedimental (A). Después, si Camilo quiere, un país concreto con límites reales (B) donde valga la pena.

## Recomendación

**A** para toda la 0.1.8.43 (cumple «todo propio o dominio público» y la mecánica de formas que cambian con el tiempo), con **EE. UU. real** (C). Dejar **B** como mejora posterior país por país si Camilo quiere nombres/límites reales, con la atribución en los créditos.

**Decide Camilo al empezar la 0.1.8.43.**
