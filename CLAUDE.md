# Gran Estrategia — guía para Claude

Juego de gran estrategia (estilo Age of History 3) en **Godot 4.3 / GDScript**. Lo crea Camilo (Bogotá, español colombiano informal) con IA: **él no programa, yo escribo todo el código**.
Rama de trabajo: `v0.1.8-development` (`main` no se toca, ver README). Proyecto vigente: `GranEstrategia_v0.1.8/` (ahí está `project.godot`). `GranEstrategia_v0.1.7/` es una versión vieja: ignorarla al buscar.

## Cómo trabajar con Camilo
- Responder en **español, conciso y directo**, sin rodeos ni repetir explicaciones. Decirle cuándo una mecánica queda implementada.
- **No enviar ZIP ni ejecutable** salvo que lo pida. Si pide «descríbeme antes de crear», no tocar el juego hasta que dé permiso.
- Antes de entregar cualquier versión: **revisión de rendimiento** (`test/runner89`, medir con y sin el cambio) y **revisión de variables** (`herramientas/auditar_codigo.py`: 0 funciones y variables repetidas, 0 sin uso; `datos/variables.json` solo cambia a propósito).
- Cada versión: subir `VERSION` en `MapaPrincipal.gd` y `project.godot` (`runner74` lo comprueba), y escribir `NOTAS_TECNICAS_<versión>.md`, `CHECKLIST_TESTING.md`, `LEEME.txt` y `LEEME_INSTRUCCIONES.txt`.

## Mapa del código (todo en `GranEstrategia_v0.1.8/`)
- `MapaPrincipal.gd`: dibujo del mapa, selección, entrada. `scripts/`: `entidades.gd` (Mundo, países, provincias), `base_datos.gd` (un valor por territorio y fecha), `territorio.gd` (celdas), `descubrimientos.gd`, `ejercito.gd`, `guerra.gd`, `ia.gd`, `hud.gd`, `debug_menu.gd`, `reloj.gd`…
- `datos/`: JSON y `.bin` **generados**; no editarlos a mano. `herramientas/`: generadores en Python (`construir_*.py`, `preparar_*.py`). Los descubrimientos se editan en `herramientas/descubrimientos/` (catálogo + `anios.tsv`) y se regeneran con `construir_descubrimientos.py`.
- `docs/`: `DESCUBRIMIENTOS.md`, `MAPA_CELDAS.md`, `NATURAL_EARTH.md`, `DIAGRAMA_BASE_DE_DATOS.md`. Lo hecho en cada versión: `NOTAS_TECNICAS_*.md`.

## Probar
- Godot 4.3 sin ventana: `Godot_v4.3-stable_linux.x86_64 --headless --path GranEstrategia_v0.1.8 res://test/runner77.tscn` (se baja de github.com/godotengine/godot/releases; el entorno solo alcanza github.com y los registros de paquetes). Cada prueba imprime `FALLOS: 0` si todo va bien.
- `runner74` necesita ventana: `xvfb-run -a godot --path … --rendering-driver opengl3 res://test/runner74.tscn`. Primera vez en una carpeta limpia: `--import`.
- Pruebas incluidas: `test/runner71`–`77` y `89` (rendimiento); ver `test/LEEME_PRUEBAS.txt`. Las ~80 antiguas y los datos históricos reales no están en el repo.
- Auditoría estática: `python3 herramientas/auditar_codigo.py GranEstrategia_v0.1.8 salida.json`.

## Estado
Versión actual **0.1.8.36** (rama de descubrimientos enlazada con el reloj): ver `NOTAS_TECNICAS_0.1.8.36.md` y `docs/DESCUBRIMIENTOS.md`.
Pendiente conocido: etiquetas verticales del mapa (AMÉRICA DEL SUR y otras 20 tienen tramos con la curva fuera de ±90° y letras invertidas), rediseño visual, HUD de país/provincia, menú Debug en cuadrícula, vista de relieve, pinturas e iconos de divisa.
