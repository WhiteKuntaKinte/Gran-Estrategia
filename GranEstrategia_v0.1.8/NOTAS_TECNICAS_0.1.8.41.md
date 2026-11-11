# Notas técnicas 0.1.8.41 — Imágenes: pinturas, banderas HD, iconos de materias, monedas, interfaz y edificios

Camilo pidió saltar directo de la 0.1.8.39a a la última versión programada («mete todo lo que dijiste que ibas a meter, independientemente de cuánto dures»). Esta versión **incluye la 0.1.8.40** (edificios, cores y ventana Construir: ver `NOTAS_TECNICAS_0.1.8.40.md`) y toda la hoja de ruta de imágenes de la 0.1.8.41.

## Qué trae
1. **Pinturas clásicas** por nación y época (137 de dominio público o CC0): cabecera de la pestaña General del panel.
2. **Banderas en HD** (937 PNG de 256 px) para la cabecera del panel y el aviso de guerra.
3. **Iconos propios** (128 px, dibujados por código) de **160 materias primas**, **25 sectores** y **151 monedas** (una por divisa).
4. **Interfaz rediseñada**: los 39 iconos `i_*` en HD y **migas de pan nuevas** (píldoras con la bandera o el icono de cada nivel).
5. **109 iconos de edificios** (uno por edificio) en la ventana Construir y en la tarjeta Edificios del HUD.
6. Licencias: **fuera las banderas de ciudades de EE. UU. con licencia CC BY / CC BY-SA** (el juego se puede vender sin atribuciones).

Todo el arte es **dibujado por código o de dominio público**: nada con licencia que obligue a atribuir, ni nada de IA generativa de imágenes.

## 1. Pinturas (`scripts/pinturas.gd`, `pinturas/`, `herramientas/pinturas/`)
- `pinturas/<carpeta>/<clave>.jpg` con `pinturas/creditos.json` (autor, título, fecha, licencia y URL de Commons de cada obra) y `pinturas/CREDITOS.txt` (la misma lista, legible).
- Carpetas: `2026/` (72), `1dc/` (42, los pueblos del año 1) y `general/` (23: regiones, continentes y el mundo). Total 137 imágenes, 21 MB.
- Se elige de lo más cercano a lo más lejano: **país → región → continente → mundo**. La región sale del centro del bloque principal del país y su continente, así que sirve igual para países modernos y pueblos antiguos.
- Tarjeta en la pestaña General (`hud._card_pintura`): imagen con pie y tooltip (título, texto, licencia y, si no es del propio lugar, «se muestra una pintura de su región…»). Sin pinturas instaladas, la tarjeta no aparece.
- Caché de texturas (`MAX_CACHE` = 14; una de 1.280 px pesa ~4 MB).
- Herramientas: `commons_pinturas.py` (búsqueda en Wikimedia Commons), `preparar_pinturas.py` (reduce, nombra y escribe `creditos.json`), listas `elegidas*.json` y `fichas.json` (texto en español de cada obra), workflow `traer-pinturas.yml` (el servidor no alcanza Commons; se baja con GitHub Actions).
- Para **cambiar una pintura**: copiar el `.jpg` con el nombre correcto y añadir su línea a `creditos.json`.

## 2. Banderas HD (`banderas_hd/`, `herramientas/preparar_banderas_hd.py`, `MapaPrincipal.bandera_hd`)
- `banderas_hd/` repite los nombres de `banderas/` (96 px) a **256 px de ancho** (máximo 192 de alto): 937 archivos, 8,4 MB. Salen de los vectores de oxguy3/flags y redoper1/flags (`RUTA1:RUTA2`; gana la primera que tenga el archivo).
- Los estandartes del año 1 (`e1_*`) se **redibujan idénticos** a 256 px con `construir_epoca.py hacer_bandera(ancho, forma)` (el script busca la forma que reproduce el PNG de 96 px al píxel).
- `bandera_hd(clave)`: mipmaps, caché LRU de 12 (`BANDERAS_HD_MAX`), y si falta usa la de 96 px. Las banderas pequeñas (listas, mapa, tropas) **no cambian**.
- Se usan en la cabecera del panel (72×48) y en el aviso de guerra (96×64).
- **Licencias:** se excluyen San Diego, Denver, Des Moines y Rochester (`CIUDADES_US_CON_LICENCIA` en `tablas_estados.py`); esas ciudades llevan la bandera de su estado (`construir_entidades.py` y `datos/banderas.json`).

## 3. Iconos de materias, sectores y monedas (`herramientas/iconos_materias/`, `scripts/materias.gd`)
- Se dibujan con Pillow (`lienzo.py`: polígonos, elipses, sombreado y brillo, supermuestreo ×4, lienzo lógico de 128 px) y se escriben con `generar.py`:
  - `iconos/materias/` — 160 (cultivos, ganado, pesca, minerales, metales, piedras, gemas, energía).
  - `iconos/sectores/` — 25 rubros.
  - `iconos/divisas/d_<COD>.png` — 151: una moneda por divisa con su símbolo (los países que comparten divisa comparten icono; el euro es uno solo).
  - `iconos/edificios/` y `iconos/i_*.png` (ver 4 y 5).
- `generar.py` **comprueba la cobertura**: todo nombre de `economia.json` debe tener icono (si falta, no genera) y cada edificio de `edificios.json` también.
- `datos/materias_iconos.json` (generado, no se edita): `alias` (nombre sin tildes → icono), `reglas` (palabras de un rubro → icono de sector) y `existentes` (lo que hay en disco, así nunca se pide un archivo que falta).
- `scripts/materias.gd` busca por nombre con caché: `de_nombre`, `o_defecto`, `de_divisa`, `de_pais` (en el año 1 no hay monedas modernas: icono genérico).
- Usados en Finanzas, Economía (producción principal, «Recursos de la zona»), la barra superior (moneda del país que controlas) y los detalles.
- Para **añadir un material**: dibujarlo en el módulo que toque (`cultivos.py`, `animales.py`, `minerales.py`…), añadir su alias en `generar.py` y volver a generar.

## 4. Interfaz en HD y migas (`herramientas/iconos_materias/interfaz.py`, `scripts/hud.gd`)
- Los 39 `iconos/i_*.png` se redibujaron a **128 px** con el mismo estilo que los de materias y **los mismos nombres** (el código del juego no cambió).
- Los iconos de **tinta única** que el tema pinta con `_tintar_icono` (pausa, atrás, vista y las seis velocidades) son **blancos planos**: un icono de color perdería el tinte del tema.
- **Mipmaps solo en la interfaz**: `MapaPrincipal._cargar_mip` carga cada icono y bandera con sus mipmaps (si el archivo no existe devuelve `null` sin ensuciar el log) y **cada `TextureRect` o botón con icono** de la interfaz pone `texture_filter = LINEAR_WITH_MIPMAPS` (13 `TextureRect` y 7 botones en `hud.gd`, `debug_menu.gd`, `ventana_construir.gd`, `ventana_flotante.gd` y `popup_guerra.gd`; un icono nuevo debe hacer lo mismo). Así un icono de 128 px se ve limpio a 14–40 px.
  **No se cambió el filtro por defecto del proyecto** (sigue en Linear): se probó `default_texture_filter=2` y el mapa costaba ~5 ms más por paso de zoom por software (66 contra 61 ms en `runner89`, 4 pasadas), y poniéndolo en las raíces de la interfaz todavía ~3 ms (los fondos de paneles y barra también muestreaban con mipmaps; por software cada píxel con mipmaps cuesta más). Por eso va solo en los iconos.
- **Migas del HUD** (`_dibujar_migas`, `_chip_miga`): cada nivel (continente, país, estado, provincia, ciudad) es una píldora con la bandera (país, estado, provincia y ciudad con bandera) o el icono de su nivel (`ICONO_MIGA`); la última va resaltada, en negrita y con borde más grueso; hover con realce; mano al pasar; clic emite `miga_pedida(nivel, nombre)` y `main._on_miga` navega. En modo compacto se ocultan. Las migas del menú Debug son otras (botones; `runner80`).
- Limpieza: se borraron cuatro `hacer_icono*.py` obsoletos; `hacer_iconos.py` quedó solo con los biomas (misma salida, verificado).

## 5. Iconos de edificios (`herramientas/iconos_materias/edificios.py`, `iconos/edificios/`)
- **109 iconos**, uno por `slug` de `datos/edificios.json`, 128 px, con las mismas piezas (muros, torres, techos, arcos, columnas…) para que el catálogo tenga un aire común. Las funciones se llaman **igual que el slug** y se registran solas; los fondos que llegan al borde se recortan con esquinas redondeadas.
- Usos: filas de la ventana Construir (40 px), «Obras en curso» (26 px), tarjeta Edificios del HUD (22 px, tipos construidos y obras) y los **chips de categoría** (un edificio representativo por categoría: cabaña, puente, acueducto, mercado, biblioteca, hospital, muralla, escuela militar; `construir_edificios.py` → `datos/edificios.json`, solo cambió el campo `icono`).
- Si un icono faltara, la fila usa el de su categoría (`main.icono` devuelve `null`).
- **Trampa de Godot con botones de icono:** `expand_icon = true` solo sirve en botones de tamaño fijo (los de la barra, que tienen `custom_minimum_size`). En un botón de ancho automático, como los chips de categoría, el icono no suma al ancho mínimo y se dibuja de 0 px; ahí se usa solo `icon_max_width` (18). Se vio en la captura final de Construir (chips sin icono) y se corrigió.
- Costo de cargarlos: se piden al abrir Construir por primera vez; luego quedan en la caché.

## 6. Pruebas nuevas
- `runner84` pinturas · `runner85` iconos de materias, sectores y monedas (43) · `runner86` banderas HD (31) · `runner87` iconos de la interfaz y migas (36) · `runner88` iconos de edificios (20).
- Ajustadas: `runner71` y `runner72` (el día tiene 7 fases desde la 0.1.8.40) y `runner72` (un `%.2e` que GDScript no soporta cortaba la última comprobación).

## 7. Qué NO se hizo (a propósito)
- **Vista de Relieve de altísima calidad** (pirámide de teselas con ETOPO 2022): sigue en espera hasta que Camilo diga cuándo (ver CLAUDE.md).
- Los edificios y los cores **siguen sin efectos de juego**.
- Ninguna pintura ni bandera con licencia que obligue a atribuir (solo CC0 y dominio público).
