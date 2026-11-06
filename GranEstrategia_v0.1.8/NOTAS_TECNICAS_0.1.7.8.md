# Notas técnicas 0.1.7.8
- Grosor constante: `GROSOR_PX` (px de pantalla) / `_zoom_real()` (final_transform * canvas_transform). `_process` detecta cambios de zoom (rueda, tween, ventana) y llama `_actualizar_zoom()`.
- Frontera continental rayada: `malla_cont_c.bin` guarda la distancia recorrida (2 canales de color); `SHADER_BORDE_FRANJA` la decodifica en vertex().
- Colores continentales: `SHADER_CONTINENTE` (saturacion 0.55, brillo 0.80; ajustables).
- Provincias por país: `malla_prov_*.bin` en bloques por país (`prov_rangos.json`), `etiquetas_prov.json` por país; se instancian en `_enfocar_pais` y se liberan en `_salir_foco`.
- Doble clic: `InputEventMouseButton.double_click` -> `_doble_click`. Países de 1 provincia seleccionan directo la provincia.
- Mar seleccionable: `mares.json` (ordenado por área) + resaltado con Polygon2D/Line2D.
- Rendimiento: -93k segmentos provinciales y ~1,5 MB de etiquetas fuera del arranque; textos de provincia solo en foco. Pendiente: dividir la malla de relleno por continente (culling), reducir `malla_costa` en zoom lejano (LOD).
- Sin probar en Godot.
