# Notas técnicas 0.1.7.7
Base: 0.1.7.6 (Natural Earth, equirectangular, mar con batimetría). Ver NOTAS_TECNICAS_0.1.7.6.md.

## Cambios
- `preparar_fuente.py`: sin agrupar por región; EE. UU. = condados NE admin-2 (nombre "Condado, Estado"); nombres de país corregidos
  (dict NOMBRE_PAIS_ES) y `limpiar_nombre`. Resultado: 7.653 provincias, ~328k vértices simplificados (eps 0.10 px) con arcos compartidos.
- `construir_mapa.py`: color_pais con matiz casi fijo por continente (la variación la da el shader por latitud); jitter por provincia 0.02.
- `etiquetas.py`: ~5.700 etiquetas de provincia (solo si legibles a zoom <= 40).
- `construir_info.py` (+ `tablas_info.py`): `datos/info.json` (prov = [pob, área km², alt media, alt máx, [[bioma,%]], reino]; pais/cont;
  tablas de flora/fauna por bioma y reino) y `datos/mares.json` (polígonos de mares NE ordenados por área, con profundidad máx/media).
  Población 2026 = WB 2025 × crecimiento 2024->2025 (acotado); provincias por peso de ciudades NE (+ área). Biomas: mapa PNG de dmcglinn/wwf_biome
  georreferenciado con ajuste (CALIB). Altitud: ETOPO1 10' (+ picos NE para la máxima).
- Godot: ZOOM_CONTINENTE_MAX=1.3, ZOOM_PROVINCIAS=3.0; `_seleccionar` -> continente/país/provincia/mar; panel con RichTextLabel; nombres de país
  desaparecen en ZOOM_PROVINCIAS*1.5; nombres de provincia empiezan en ZOOM_PROVINCIAS*0.95. Shader gradiente: brillo 0.36 en el ecuador -> 1.0 a 62° (norte y sur).

## Limitaciones conocidas (honestas)
- Natural Earth NO tiene subdivisiones por debajo de admin-1 salvo EE. UU.: Canadá (13), Alemania (16), Australia (11), Brasil (27), China (32)... quedan con sus provincias/estados.
- Etnias: solo nacionales y solo ~100 países; el resto muestra "sin datos". Flora/fauna: texto típico por bioma y reino (no inventario por provincia).
- Godot no se pudo ejecutar aquí: GDScript/shader sin probar. Posible lentitud con zoom alto por ~5.700 etiquetas.
