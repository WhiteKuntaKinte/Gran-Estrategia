# Notas técnicas 0.1.7.6 (para IA / siguiente agente)
Base: 0.1.7.5 (estable). La 0.1.7.6 anterior (otro agente) estiraba el mapa (reproyección CEA) y borró diseño; se descartó.

## Decisiones
- Proyección: equirectangular 2400x1200 (x=(lon+180)*6.667, y=(90-lat)*6.667; ecuador y=600). NO reproyectar.
- Geometría: `herramientas/preparar_fuente.py` convierte Natural Earth 10m admin-1 (admin-0 si un país no tiene admin-1)
  a `datos/fuente_provincias.json` con simplificación Douglas-Peucker POR ARCOS COMPARTIDOS (tolerancia 0.10 px):
  vecinos comparten vértices idénticos. Países con >30 unidades se agrupan por `region` de NE. Islas <0.012 px² se descartan.
- `construir_mapa.py`: igual que 0.1.7.5 salvo: sin malla de agua; TOL de sellado 0.3; `provincias_juego.json` anillos ahora
  `{p,k,b,v0,n,i0,i1}` (los vértices se leen de malla_fill_v.bin: `vertices_fill.slice(v0, v0+n)`); Russia al este de x>=1600 = Asia;
  color continental envuelve x<600 (+2400) para Europa/Asia (arregla Chukotka); `geom.triangular` reescrito (ear clipping rápido).
- Profundidad: `construir_profundidad.py` rasteriza bandas NE bathymetry (L_0..A_10000) a 4096x2048, rellena huecos por vecino más cercano,
  interpola nivel continuo entre curvas (EDT) y calcula distancia a la costa del propio juego -> `datos/profundidad.bin` (RG8, 16 MB crudo).
  Godot: `_construir_mar()` crea Image RG8 + mipmaps y un ColorRect (z -1) de 3 mundos con `SHADER_MAR` (rampa de 12 niveles, halo costero,
  curvas con fwidth, zoom en uniform). Si cambias tonos, edita RAMPA en el shader.

## Verificado / NO verificado
- Verificado en Python: triangulación sin avisos de área, previsualizaciones del mundo/Europa sin estiramiento, textura de profundidad.
- NO se pudo ejecutar Godot aquí: GDScript y shader sin probar. Si falla, revisar primero SHADER_MAR (arrays const, fwidth) y _construir_mar.
- Riesgos: 2.415 etiquetas de provincia (antes 305) -> posible lentitud con zoom alto; carga inicial más larga (300k vértices de relleno).

## Pendiente (pedido antes, no hecho)
Detalle de Francia (ciudades/carreteras/clic en HUD), contador de fecha con control de velocidad, parámetros de provincias alterables en el tiempo.
