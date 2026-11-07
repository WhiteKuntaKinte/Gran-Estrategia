# Gran Estrategia — guía para Claude

Juego de gran estrategia (estilo Age of History 3) en **Godot 4.3 / GDScript**. Lo crea Camilo (Bogotá, español colombiano informal) con IA: **él no programa, yo escribo todo el código**.
Rama de trabajo: `v0.1.8-development` (`main` no se toca, ver README). Proyecto vigente: `GranEstrategia_v0.1.8/` (ahí está `project.godot`). `GranEstrategia_v0.1.7/` es una versión vieja: ignorarla al buscar.

## Cómo trabajar con Camilo
- Responder en **español, conciso y directo**, sin rodeos ni repetir explicaciones. Decirle cuándo una mecánica queda implementada.
- **No enviar ZIP ni ejecutable** salvo que lo pida. Si pide «descríbeme antes de crear», no tocar el juego hasta que dé permiso.
- Antes de entregar cualquier versión: **revisión de rendimiento** (`test/runner89`, medir con y sin el cambio) y **revisión de variables** (`herramientas/auditar_codigo.py`: 0 funciones y variables repetidas, 0 sin uso; `datos/variables.json` solo cambia a propósito).
- Cada versión: subir `VERSION` en `MapaPrincipal.gd` y `project.godot` (`runner74` lo comprueba), y escribir `NOTAS_TECNICAS_<versión>.md`, `CHECKLIST_TESTING.md`, `LEEME.txt` y `LEEME_INSTRUCCIONES.txt`.

## Mapa del código (todo en `GranEstrategia_v0.1.8/`)
- `MapaPrincipal.gd`: dibujo del mapa, selección, entrada, vista de Relieve. `scripts/`: `entidades.gd` (Mundo, países, provincias), `base_datos.gd` (un valor por territorio y fecha), `territorio.gd` (celdas), `descubrimientos.gd`, `ejercito.gd`, `guerra.gd`, `ia.gd`, `hud.gd` (barra y menú VISTA), `tema_hud.gd` (los 3 temas de interfaz), `debug_menu.gd`, `reloj.gd`…
- `datos/`: JSON y `.bin` **generados**; no editarlos a mano. `herramientas/`: generadores en Python (`construir_*.py`, `preparar_*.py`). Los descubrimientos se editan en `herramientas/descubrimientos/` (catálogo + `anios.tsv`) y se regeneran con `construir_descubrimientos.py`. Las imágenes de la vista de Relieve (`datos/texturas/relieve_vista_*.jpg`) salen de `preparar_relieve_vista.py` (ETOPO 2022 + Natural Earth; el .tif de 465 MB está en el Release `datos-etopo`, no en la rama; lo lee `leer_etopo.py` sin GDAL). `renovar_paleta.py` cambia los colores de continente ya horneados.
- `docs/`: `DESCUBRIMIENTOS.md`, `MAPA_CELDAS.md`, `NATURAL_EARTH.md`, `DIAGRAMA_BASE_DE_DATOS.md`. Lo hecho en cada versión: `NOTAS_TECNICAS_*.md`.

## Regla del zoom
`_actualizar_zoom()` corre en cada paso de la rueda: ahí solo valores de shader (uniforms) y alfas. **Nunca** cambiar `Line2D.width`, reconstruir mallas o texto por paso (cada cambio rehace la geometría al dibujar y da tirones). Un grosor fijo en píxeles = cinta de malla + shader con `half_width` por uniform (ver `SHADER_BORDE`, `SHADER_SELECCION`).

## Probar
- Godot 4.3 sin ventana: `Godot_v4.3-stable_linux.x86_64 --headless --path GranEstrategia_v0.1.8 res://test/runner79.tscn` (se baja de github.com/godotengine/godot/releases; el entorno solo alcanza github.com y los registros de paquetes). Cada prueba imprime `FALLOS: 0` si todo va bien.
- `runner74` necesita ventana: `xvfb-run -a godot --path … --rendering-driver opengl3 res://test/runner74.tscn`. Primera vez en una carpeta limpia: `--import`.
- Pruebas incluidas: `test/runner71`–`80`, `89` (rendimiento) y `90` (banco de zoom: mide el coste de cada paso de la rueda; usarlo si se toca algo de `_actualizar_zoom`); ver `test/LEEME_PRUEBAS.txt`. Las ~80 antiguas y los datos históricos reales no están en el repo.
- Auditoría estática: `python3 herramientas/auditar_codigo.py GranEstrategia_v0.1.8 salida.json`.

## Estado
Versión actual **0.1.8.38** = HUD y ventanas, 1.ª parte (ver `NOTAS_TECNICAS_0.1.8.38.md`): Debug en cuadrícula con migas; ventanas flotantes (Debug, Mi país, Ranking) con bordes redimensionables y memoria de sitio (`main.geo_ventanas`); panel del país movible (cabecera; doble clic = volver) y redimensionable (bordes), con tarjetas que se reparten en 1–3 columnas (`_poner_tarjeta`: se arman directo en su columna, **no mover nodos después**: costaba +20 ms por redibujo); avisos apilados (`scripts/avisos.gd`, `main.aviso(texto, nivel)`; la línea de ayuda de abajo queda solo para la ayuda del modo); fichas al pasar el ratón (`scripts/fichas.gd`; sirven para todo control con `tooltip_text`: primera línea = título, línea «Atajo: X» aparte; el tooltip nativo está apagado con `gui/timers/tooltip_delay_sec` en `project.godot`). Pruebas nuevas: `test/runner80`. Antes: 0.1.8.37a (tirones de zoom, `NOTAS_TECNICAS_0.1.8.37.md` sección 11) y 0.1.8.37 (3 temas, barra y menú VISTA, selección, bordes HD, paleta, Relieve).
Plan siguiente: **0.1.8.38b** = HUD de provincia con Edificios / dos Cores (nacional y cultural) / Ingreso / Población, ventana Construir con los 109 edificios (cuesta dinero y tarda días, se guarda por provincia, sin efectos todavía), totales y órdenes de grupo con Ctrl+clic; **0.1.8.39** = imágenes (sistema de pinturas por carpeta y nombre, banderas, iconos de materias primas y de divisas en HD, iconos y migas rediseñados).
Pendiente conocido: filtro sepia del tema A y tarjetas con pergamino del C; vistas Clima / Población / Economía / Cultura (en el menú como «próximamente»).
