# Notas técnicas 0.1.7.9.1

## Estado de pruebas (sé honesto contigo mismo)
- Probado con Godot 4.3 headless/xvfb y render por software (llvmpipe): arranque sin errores de script; reloj (velocidades,
  Espacio, 1-2-3), tesorería (+30 días = 30 x ingreso diario, comprobado), selección de país/continente/mar/provincia/ciudad con
  el botón atrás, menú Debug completo (jugador, anexar Venezuela->Colombia, búsqueda y edición de provincia, transferir a
  otro país, fecha y dinero), pop-out de un país con provincias ajenas, flujo antiguo de clic/doble clic/V/X/Esc. Capturas revisadas.
- NO probado: FPS reales en un PC de pocos recursos, Windows, partidas largas, ni clics reales sobre cada botón de la barra
  (se probaron por llamada de función y por teclado).
- Contadores del renderizador (no son FPS; mismas escenas que 0.1.7.9): mundo zoom 2: 268 k -> 171 k triángulos
  (una capa de relleno menos), llamadas de dibujo 80 -> 115 (la barra superior suma unas 30-35). EE. UU. zoom 3:
  271 k -> 185 k / 77 -> 114. Pop-out de EE. UU. zoom 3: 418 k -> 332 k / 353 -> 380.

## Colores (sin degradado)
- `construir_mapa.py`: `color_continental()` y `color_pais()` devuelven un color sólido por continente (`BASE_PAIS`/`COLOR_CONT`).
  Se regeneró todo `datos/` (≈2 min) y la cadena construir_info -> construir_entidades -> anadir_color_foco -> construir_divisas.
- Godot: una sola capa de relleno sin material (`capa_pais`, colores por vértice, `malla_filt_cp.bin`). Se eliminaron
  `SHADER_GRADIENTE_PAIS`, `SHADER_CONTINENTE` (apagado) y la capa continental. `SHADER_POPOUT` ahora es color plano.
  `malla_filt_cc.bin` ya no se usa (se dejó fuera del ZIP; el constructor todavía la escribe).

## Reloj (`scripts/reloj.gd`)
- `anio/mes/dia`, calendario gregoriano proléptico (años <= 0 astronómicos), `velocidad` 0-3 (`SEG_POR_DIA` = [pausa, 1, 0.4, 0.12]),
  `avanzar(delta)` devuelve cuántos días pasaron. `MapaPrincipal._process` lo mueve solo si no estás en el menú ni en pausa y,
  por cada día, llama `mundo.avanzar_dia()`.

## Divisas y economía (`scripts/entidades.gd`, `datos/divisas.json`)
- `Divisa` (codigo, nombre, simbolo, por_usd = unidades por 1 US$). `Mundo.divisas`, `Mundo.tasa_fiscal` (0,25), `Mundo.jugador`.
- `Pais.divisa/pib_usd/tesoreria/anexado_a`. PIB 2026 por país de `herramientas/construir_divisas.py` (Banco Mundial + `GDP_EXTRA`
  para los que faltan); cambios aproximados (no son cotizaciones reales de hoy).
- `Provincia.poblacion/pib_pc/favorabilidad/mult_ingreso`. `pib_pc` = PIB del país ORIGINAL / población del país original y viaja
  con la provincia (una provincia conquistada produce como en su país de origen).
  `ingreso_efectivo_usd = pib_pc x poblacion x mult_ingreso x (0,5 + favorabilidad/100)`.
- `Mundo.ingreso_diario_usd(pais)` = suma de las provincias del país x tasa_fiscal / 365,25. Tesorería en moneda local.
- `Mundo.transferir_provincia` ahora: pone favorabilidad 35 y mueve también las ciudades. `anexar_pais(origen, destino, fecha, motivo)`
  transfiere todas las provincias. `tiene_ajenas`, `origenes_ajenos` ayudan al pop-out.

## Menú Debug (`scripts/debug_menu.gd`)
- CanvasLayer 30 sobre la pausa; Esc / VOLVER emiten `cerrado`. Usa solo la API pública de `MapaPrincipal`:
  `debug_controlar`, `debug_anexar`, `debug_transferir`, `debug_avanzar_dias`, `debug_fijar_fecha`, `debug_dar_dinero`,
  `debug_provincia_seleccionada`, `refrescar_todo`. No guarda nada en disco.
- Marca de anexión: `_refrescar_anexiones()` dibuja un tinte (color según el nombre del dueño) sobre las provincias cuyo
  `pais != pais_original` (z 2, por debajo de las líneas).
- Limitaciones conocidas: las LÍNEAS de frontera del mapa son las originales (no desaparece la frontera entre A y B tras anexar);
  en el pop-out de B se dibujan las líneas y nombres de A solo si A fue anexado ENTERO (las provincias sueltas ganadas no llevan
  sus líneas); la lista de provincias del Debug solo muestra hasta 120 resultados.

## HUD
- Barra superior (`_construir_barra`) con bandera/nombre del país que controlas, dinero (+ por día), fecha y 4 botones de velocidad.
- Pestaña Economía: sección Finanzas (`datos["fin"]`: divisa, tipo de cambio, PIB, producción, ingresos por día, tesorería /
  producción de la provincia, % que aporta, favorabilidad, multiplicador) + Producción principal (un solo rubro).
- Atrás (`MapaPrincipal._atras`): ciudad -> provincia -> país -> cierra; continente/mar -> cierra. Botón y Retroceso.

## Cosas pendientes (de la nota post-0.1.7.8)
Hecho solo como BASE: divisas, identidad del país ligada a datos (divisa, PIB, provincias), provincias como fuente de ingresos,
conquista (solo por Debug), población y favorabilidad por provincia.
Sin hacer: guerra/asedio con decisión (anexar / vasallo / pedir ingresos), efecto de la guerra en población y favorabilidad,
variables étnicas cambiantes, árbol de investigación, evolución procedural del idioma, historia hacia atrás desde 2026.

## Herramientas (orden de ejecución)
preparar_banderas.py -> construir_mapa.py -> construir_info.py -> construir_entidades.py -> anadir_color_foco.py ->
construir_divisas.py (argumento: CSV de PIB) ; hacer_iconos_extra.py genera los iconos nuevos.
