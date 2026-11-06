# Notas técnicas 0.1.7.9

## Estado de pruebas (sé honesto contigo mismo)
- Probado con Godot 4.3 headless/xvfb y render por software (llvmpipe): arranque sin errores, flujo de clic / doble clic /
  V / X / Esc, pestañas, banderas, estados, ciudades, pop-out. Capturas revisadas a mano.
- Los milisegundos por fotograma de esas pruebas NO sirven como FPS reales (render por CPU). Lo útil son los contadores
  del renderizador (triángulos y llamadas de dibujo por fotograma, mismas escenas en 0.1.7.8 y 0.1.7.9):

| Escena | 0.1.7.8 triángulos / llamadas | 0.1.7.9 triángulos / llamadas |
|---|---|---|
| Mundo zoom 2 | 905 k / 28 | 268 k / 80 |
| EE. UU. zoom 3 | 906 k / 28 | 271 k / 77 |
| Europa zoom 6 | 915 k / 30 | 288 k / 82 |
| Nueva York zoom 9 (con ciudades) | 915 k / 31 | 194 k / 73 |
| Nueva York zoom 20 | 912 k / 28 | 127 k / 62 |
| EE. UU. con pop-out zoom 3 | 955 k / 722 | 418 k / 353 |
| EE. UU. con pop-out zoom 10 | 972 k / 4055 | 290 k / 410 |
- Con ventana diminuta (carga limitada por geometría) 0.1.7.9 va entre 1,1x y 2,5x más rápido que 0.1.7.8 en todas las
  escenas SALVO el pop-out de EE. UU. a zoom 3, que es más lento (silueta + sombra de ~3200 condados).
- Arranque: ~0,7-0,9 s (0.1.7.8: ~0,5-0,65 s) por las mallas nuevas y las ciudades.

## Rendimiento (por qué)
- Mallas de relleno / costa / frontera partidas en teselas de 300x300 unidades (`teselas.json`): cada tesela es un nodo
  y Godot descarta las que no se ven. Provincias y estados por país y por tesela (`prov_rangos.json`, `estado_rangos.json`).
- Ciudades: marcadores = UNA malla por tesela con shader (`SHADER_CIUDAD`, tamaño constante en píxeles; el zoom mínimo de
  cada ciudad va codificado en el UV). Nombres en dos pasadas con una fuente SIN MSDF (`fuente_ciudad`): con MSDF cada letra
  costaba una llamada de dibujo (5500 llamadas a zoom 20; ahora 62).
- Los nombres de provincia/estado siguen con MSDF (se escalan con el mapa): cada letra es una llamada de dibujo. En zonas
  muy densas con zoom alto sigue habiendo cientos de llamadas (pop-out de EE. UU. zoom 10: 410).
- Relleno original (`malla_fill_*`) se carga solo al primer clic. `_malla_de_anillos` arma mallas pequeñas para resaltados y
  para la silueta del pop-out (antes se copiaban 350 mil vértices por clic).

## Entidades (`scripts/entidades.gd`)
- `Mundo` (registro) -> `Continente`, `Pais`, `Estado` (clave "País|Estado"), `Provincia`, `Ciudad`; todos tienen `variables`
  para que las mecánicas futuras guarden datos.
- `Mundo.transferir_provincia(idx, destino, fecha, motivo)`: mueve la provincia, anota `propietarios` en la provincia y
  `historial` ("gano"/"perdio") en los dos países. Aún no hay mecánica que la llame.
- `Pais.foco` = bloque principal de territorio (para centrar el pop-out); `col` = color base (entidades.json).

## Vistas
- `vista` = "tradicional" | "internacional". Solo cambia lo que se ve con un país enfocado (doble clic):
  tradicional = condados + estados gruesos; internacional = solo estados donde existan (EE. UU.), el resto igual.
- Clic con país enfocado: tradicional -> provincia; internacional (si hay estados) -> estado.

## Pop-out (primera versión, a pulir)
- `_enfocar_pais`: grupo Node2D escalado 1.035 sobre el centro del país (silueta con `SHADER_POPOUT`, sombra, líneas, nombres)
  sobre un `ColorRect` oscuro; cámara a 0.17 del ancho a la derecha del centro (`_mover_camara_a`).
- Limitaciones: solo se levanta UNA copia del mundo (piezas del país al otro lado de la línea de fecha, p. ej. Chukotka,
  Aleutianas, Fiyi, no saltan); las ciudades no se escalan con la silueta (quedan hasta ~3 % desplazadas hacia dentro);
  sin contorno blanco propio; coste alto en países con miles de provincias.
- Doble clic dentro de un país ya enfocado: acerca la cámara a esa provincia (o estado en vista internacional).

## Banderas (`preparar_banderas.py`)
- Fuentes SVG: oxguy3/flags (dos copias, la segunda con más países: Rusia, Japón, Brasil, Italia, Polonia, Bélgica, Austria,
  Chile, Dinamarca) + lipis/flag-icons no usado. Se busca por código ISO 3166-2 de Natural Earth; si falla, hereda la bandera de la
  región (`region_cod`, p. ej. provincias de Italia -> bandera de su región: 156 casos).
- Resultado: 244/249 países, 53/53 estados de EE. UU., 515 de 7617 provincias, 70 ciudades. El resto = `x.png`.
- NO hay banderas de departamentos de Colombia, comunidades de Argentina/Perú/etc., condados de EE. UU. (no existen en esos
  repositorios; no se pudo acceder a otros). Para añadirlas: poner el SVG/PNG y la regla en `preparar_banderas.py`.

## Economía (`tablas_economia.py` -> `economia.json`)
- Estimaciones escritas a mano con conocimiento general; NO son estadísticas oficiales. Fichas propias: 122 países y 108
  regiones (estados de EE. UU., departamentos de Colombia, estados de México). Los demás países usan un perfil por tipo de región
  (`nivel` 'r') o la ficha de su país. La pestaña lo avisa en una nota.
- Cada rubro tiene % de ingresos y su efecto en el crecimiento.

## Datos con límites conocidos
- Población por provincia = población del país repartida por peso de ciudades (Delhi, Maharashtra y similares salen 2x altos).
  Probé un reparto mixto urbano/rural: no mejoró contra 19 valores de referencia, así que se dejó el original.
- 5 territorios sin bandera; bioma de Carolina del Sur sale "Sabana y matorral" (clasificación WWF gruesa).

## Herramientas (orden de ejecución)
preparar_banderas.py -> construir_mapa.py -> construir_info.py -> construir_entidades.py -> anadir_color_foco.py
(`python3 -I herramientas/<script>.py` con los argumentos que indica cada docstring.)
