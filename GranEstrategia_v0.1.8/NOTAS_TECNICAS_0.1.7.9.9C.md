# Notas técnicas 0.1.7.9.9C — base de la capa histórica

## Estado de pruebas (honesto)
- Godot 4.3, xvfb + render por software. `runner7` (capa histórica): **43 comprobaciones, 0 fallos**. `runner6` (barra, Debug, «Mi país»,
  velocidades): 48 comprobaciones, 0 fallos. `runner5` (base de datos/economía) y `runner3` (mapa, clics, pausa) siguen pasando.
  El único `ERROR` que sale en `runner5` es intencional (prueba que escribir `tesoreria` en una provincia se rechaza).
- Descargador (`herramientas/descargar_historia/`): probado de punta a punta contra un **servidor falso** (Python) que imita lo justo de
  Wikidata (SPARQL JSON) y de Commons (`Special:FilePath`, API de licencias): modos prueba / completa / solo convertir, caché
  (segunda pasada = 0 consultas nuevas), conversión sin red idéntica a la original (licencias incluidas), red caída (error limpio,
  salida 1, archivos intactos), 404 y 429 con reintento, JPEG y WebP además de PNG, imagen compartida por varias entidades, años a. C.,
  año 0 y mes/día `00`, entidades sin nombre y personas sin nombre (se omiten), país actual que Wikidata también lista como
  «estado» (se salta). También con las rutas normales (`res://datos/historico/`, `res://banderas_hist/`).
- **PRUEBA real (1-nov-2026, PC de Camilo, Godot 4.7.2):** funcionó contra Wikidata y Commons reales: 50 estados, 379 nombres, 61 filas de
  banderas/escudos (47 imágenes; licencias: 48 «Public domain», 4+4 CC BY-SA 4.0/3.0, 2 CC BY 3.0, 2 CC0, 1 GFDL 1.2), 190 personas, 218 cargos.
  Lo que mostró y se corrigió después: (1) la PRUEBA traía estados oscuros porque ordena por Q-ID → ahora filtro por `wikibase:sitelinks`
  (`min_sitelinks`, 40 en prueba / 10 en completa); (2) nombres «comunes» en decenas de idiomas raros (sylheti, pali…) → lista `idiomas_comun`;
  (3) un estado con fin anterior al inicio → se ignora el fin; (4) las licencias no filtraban nada → clasificación + descarte + créditos.
  La 2.ª PRUEBA real (versión con esos arreglos, 49 estados reconocibles —Imperio neoasirio, Rus de Kiev, Raj británico, Imperio neerlandés,
  Reino de Wessex…, 60 imágenes, 0 descartadas— tardó ~4 min) salió bien; después se cambió el descubrimiento de estados a dos pasos (ver abajo) y eso
  se probó solo contra el servidor falso (la COMPLETA real de abajo se corrió con la versión ANTERIOR, la paginada).
- **COMPLETA real (1-nov-2026, 04:18–05:55 hora de Bogotá, ~97 min, versión paginada):** terminó «FIN OK». 240 países y continentes
  reconocidos; **1.902 estados, 7.236 nombres, 3.087 banderas/escudos (2.543 imágenes distintas), 2.488 personas, 2.991 cargos.**
  Wikimedia respondió 429 con `Retry-After` varias veces (sobre todo en la fase de licencias) y se resolvió con los reintentos; 1 imagen
  se perdió por 429 y 6 por formato (5 `.gif`, 1 `.jpg` que Godot no decodifica): 9 filas de banderas quedaron fuera por no tener imagen
  (se reintentan en la siguiente COMPLETA). Descartadas por licencia: 1 («Gay Pride Flag.svg», «Copyrighted free use»). 6 fechas con fin
  anterior al inicio corregidas.
  Mezcla de licencias: dominio público + CC0 = 2.049 filas (66 %); CC BY / CC BY-SA = 1.018 (33 %, hay que dar crédito y las BY-SA tienen
  condición de compartir igual al adaptar la imagen); «Attribution» 16 y «OGL-om 1.0» 4 (las 2 marcadas [REVISAR]: escudo y bandera de Omán).
  Calidad (revisada a mano sobre una muestra de 40 + estadísticas): estados reconocibles y con fechas razonables; 123 sin inicio, 88 sin fin,
  447 sin capital; 14 «vigentes en 2020» son estados a los que Wikidata no les puso fin (p. ej. Siria baazista, Medieval Egypt); 16 nombres
  repetidos (Wei ×3, Reino de Italia ×3…, ítems distintos de Wikidata con la misma etiqueta); 200 estados sin nombre en español (usan el
  inglés); gobernantes solo para 415 de los 1.902 estados. 544 banderas con fecha son de países actuales (sirven para la máquina del tiempo).
  Prueba de carga en el juego con los datos reales (`runner8`, Godot 4.3): 0 fallos; búsqueda y fichas en ~10 ms.
  Vigentes por época (solo estados históricos, los países actuales no cuentan): -300: 44 · 0: 46 · 500: 93 · 1000: 198 · 1500: 339 · 1800: 354 ·
  1900: 240 · 1950: 128 · 2000: 19.
- Riesgos que quedan para la descarga completa:
  1. alguna consulta SPARQL puede pasarse de tiempo en el servicio real (la clase `Q7275`, «estado», es enorme; se puede cambiar en
     `clases_estado` del archivo de configuración o bajar `tamano_pagina`);
  2. los Q-ID de los continentes (Q15, Q18, Q46, Q48, Q49, Q51, Q538) están escritos de memoria;
  3. límites de velocidad y redirecciones reales de Commons;
  4. fechas a. C.: Wikidata usa año astronómico (con año 0) y el juego no tiene año 0 → posible desfase de ±1 año;
  5. gobernantes: solo se leen de las propiedades de la entidad (P35 jefe de estado, P6 jefe de gobierno); para estados antiguos
     salen pocos.
  Las consultas no se comprobaron con un analizador SPARQL (no hay `rdflib` aquí); las revisé a mano.
- NO probado: tu PC, Windows, partidas largas, jugar a mano.

## Modelo de datos
- Tipo nuevo de territorio `entidad` (`BaseDatos.T_ENTIDAD = 6`). Rango de ID: entidades 1.000.000–1.999.999; personas 2.000.000–9.999.999
  (las personas **no** están en la tabla de territorios; viven en `Historia`). `datos/ids.json` lleva los rangos nuevos;
  `herramientas/construir_ids.py` los conoce (`RANGOS_HISTORIA`).
- `BaseDatos.cargar(ids, catalogo, extra)`: `extra` son las filas de entidades (padre -1); entran como territorios normales y por
  eso pueden ser valor de `propietario`.
- `BaseDatos.valor_en(variable, id, fecha)`: «viaje en el tiempo». Si el valor actual empezó en `desde <= fecha`, es el actual; si no,
  busca en el historial el intervalo `[desde, hasta)` que contiene la fecha (si hay varios, el de `desde` más reciente). `null` = sin dato.
  `BaseDatos.dueno_en(provincia, fecha)` = `valor_en("propietario", ...)` o `-1`.
- Fechas: enteros `(año+100000)*10000 + mes*100 + día`; `0` = desconocida/abierta. Años a. C. negativos, sin año 0.
- `scripts/historia.gd` (clase `Historia`, colgada de `Mundo.historia`): tablas en columnas paralelas
  - entidades: id, clave, nombre, tipo, inicio, fin, capital, fuente, predecesores, sucesores;
  - nombres: id, nombre, idioma, clase (`oficial|comun|nativo`), desde, hasta (+ índice por ID);
  - banderas: id, archivo, clase (`bandera|escudo|estandarte`), desde, hasta, licencia (+ índice);
  - personas: id, clave, nombre, nacimiento, muerte; cargos: persona, entidad, cargo, desde, hasta.
  - Consultas: `entidades_activas(f)`, `nombre_en(id, f, idioma)`, `nombres_de(id)`, `bandera_en(id, f)`, `banderas_de`, `gobernantes_en(id, f)`,
    `gobernantes_de(id)`, `ficha(id, f)`, `buscar(texto)` (también por nombres alternos), `Historia.anio_texto(f)` («44 a. C.»).
  - Elección de nombre: idioma pedido +40, `es` +20, `en` +10, sin idioma +5; oficial +6, común +3; con fecha de inicio +1; desempate = `desde` más reciente.
    Elección de bandera: bandera > estandarte > escudo, luego `desde` más reciente.
- Carga: `MapaPrincipal` lee `datos/historico/{entidades,nombres,banderas,personas,cargos}.json` (todos opcionales; si faltan no hay error)
  y los pasa a `Mundo.cargar(..., hist_json)`. Las imágenes se leen con `Image.load_from_file` desde `res://banderas_hist/`.
- Debug > pestaña **Historia** (`debug_menu.gd`): fecha (año/mes/día), lista de entidades vigentes, buscador, ficha (capital, fechas,
  predecesores/sucesores, nombres, gobernantes, bandera con su licencia) y bloque del mapa que dice cómo se llamaba la provincia
  seleccionada y quién la tenía en esa fecha.

## Datos de ejemplo («semilla»)
- `herramientas/hacer_semilla_historica.py` genera `datos/historico/*.json`: 16 entidades (Gran Colombia, Virreinato de la Nueva
  Granada, URSS, Imperio ruso, RFS de Yugoslavia, Checoslovaquia, RDA, Prusia, Austria-Hungría, Imperio otomano, bizantino, romano,
  azteca, inca, mongol, Qing), 36 nombres (incluye cambios de nombre de países actuales: Persia, Siam, Ceilán, Birmania, Congo Belga/
  Zaire, Rodesia, Dahomey, Alto Volta, Suazilandia, Macedonia), 37 personas y 37 cargos. `fuente = "semilla"`. Sin imágenes.
  Son datos escritos a mano de memoria: sirven para probar el sistema, no como fuente histórica fiable.

## Descargador (`herramientas/descargar_historia/`)
- Escena de Godot construida por código (sin instalar nada). Abrir `descargar_historia.tscn` y F6. Argumentos de usuario para
  pruebas automáticas: `-- --config=ruta.json --auto=prueba|completa|convertir`.
- Fuentes: Wikidata (SPARQL por POST con reintentos con `Retry-After`; estados en DOS pasos: `Q_IDS` = una consulta liviana por clase (`clases_estado`) con `wikibase:sitelinks >= min_sitelinks`, ordenados por importancia, y `Q_DETALLE` = nombre y fechas por lotes con `VALUES`; antes era una consulta paginada con `ORDER BY ?e` que en la PRUEBA real tardó hasta ~60 s por página) y Wikimedia Commons (`Special:FilePath?width=96`
  para la imagen; API para `LicenseShortName`). Imágenes: se detecta PNG/JPEG/WebP por los bytes, se guarda PNG con nombre
  `md5(archivo)[:14].png`; si varias entidades usan el mismo archivo se baja una sola vez.
- Caché en `user://historia_cache/` (respuestas SPARQL e imágenes) y `licencias.json`; copia de los archivos anteriores en
  `user://historia_respaldo/<fecha>/` antes de escribir los nuevos. IDs persistentes por `clave` (`wd:Q…`): volver a descargar no cambia
  los IDs ya dados. Con `quitar_semilla`, las filas de ejemplo se quitan solo de los IDs que reciben datos reales.
- Modos: **prueba** (~`limite_prueba` estados y `paises_prueba` países), **completa**, **convertir** (sin red, usa caché y repite la
  última consulta usada, guardada en `ultimo_modo.txt`). DETENER para entre dos peticiones.
- El registro también se escribe en `archivo_registro` (por defecto `res://herramientas/descargar_historia/ultimo_registro.txt`, se sobrescribe en cada corrida).
- Todo valor por defecto se puede cambiar en `config_descarga.json` (lo que empieza con `_` se ignora). El texto de identificación
  (`agente`) no lleva correo: si quieres ponerlo es decisión tuya.
- Licencias: cada imagen guarda su licencia (`banderas.json`, columna `licencia`); el registro avisa cuántas quedaron «sin verificar».
  El descargador **solo anota** la licencia: NO descarta imágenes por licencia (hoy no filtra las que no permiten uso comercial).
  **Hay que revisar esa columna antes de publicar el juego**; filtrar por licencia queda como mejora pendiente.

## Cambios de código fuera de lo histórico
- `MapaPrincipal.VERSION = "0.1.7.9.9C"`; `_leer_json_opcional(ruta)`; `entidades.gd` carga primero las entidades y luego la base.
- `project.godot`: nombre 0.1.7.9.9C. `datos/variables.json` y `datos/ids.json` con la versión nueva. Diagramas regenerados
  (`docs/`, nuevo `diagrama_bd_historia.png`).

## Para recordar (trampas de GDScript que ya mordieron)
- Las lambdas copian las variables simples (devolver resultados por una lista).
- Una función con retorno sin tipo (`bd.dueno_en(...)`) obliga a declarar el tipo: `var due: int = ...`, si no, error «Cannot infer the type».
- `http.cancel_request()` con una corrutina esperando la deja colgada: se usa una bandera `detener` revisada entre peticiones.

## Licencias (cambio posterior a la primera entrega)
- `_clase_licencia(texto)` → `libre | atribucion | revisar | no_comercial | sin_verificar`. Con `descartar_licencias` (por defecto
  `no_comercial` y `sin_verificar`) la imagen no se copia ni se escribe su fila en `banderas.json`. Se escriben `creditos_banderas.txt`
  (autor — campo `Artist` de Commons sin HTML —, licencia, enlace, quién la usa) y `banderas_descartadas.txt` en `datos/historico/`.
- Caché nueva `user://historia_cache/autores.json` (junto a `licencias.json`).
- No es asesoría legal; las clases son una heurística sobre el texto de `LicenseShortName`.

## Siguiente
Tropas por pelotones (≤1.000, con edad, experiencia, familiaridad y bajas), cadena de mando con nombres por cultura (los generales se
guardan como personas), devastación por provincia, guerra y conquista sobre la tabla «dueño por fecha», IA de naciones (0.1.8).
