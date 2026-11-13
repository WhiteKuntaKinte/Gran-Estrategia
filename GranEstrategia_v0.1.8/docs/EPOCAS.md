# Épocas del juego: 1 d. C., 1096, 1500 y 2026

El juego trae **4 escenarios**. Todos son el MISMO juego (mismas mecánicas); cambian los datos de partida: naciones, provincias, población, economía, ejércitos, ciudades, banderas, nombres de mandos y edificios de partida.
Se eligen en **MODO DEV → escenario** (cuatro botones) o en **Debug → Tiempo → Escenario** (reinicia el mundo con los datos de esa época). Cada escenario es una carpeta con los mismos archivos que `datos/`:

| Escenario | Carpeta | Cómo se genera | Naciones | Provincias | Población |
|---|---|---|---|---|---|
| 2026 | `datos/` | los datos de siempre | 249 | 7.653 | ~8.350 M |
| 1 d. C. | `datos/epocas/1dc/` | `herramientas/epoca/construir_epoca.py` | 186 | 4.181 | 254 M |
| 1096 (Primera Cruzada) | `datos/epocas/1096/` | `herramientas/epoca/construir_epoca_celdas.py --anio 1096` | 221 | 3.033 | 367 M |
| 1500 (Renacimiento) | `datos/epocas/1500/` | `herramientas/epoca/construir_epoca_celdas.py --anio 1500` | 202 | 3.049 | 468 M |

Lo que un escenario NO trae (el mar, la profundidad, los lagos, el catálogo de variables, de descubrimientos y de edificios) se lee de `datos/`. La **geometría de las celdas** (relleno, costas, pares de celdas vecinas) es única y vive en `datos/malla_*`; cada escenario solo trae su tabla «celda → provincia» (`provincias_juego.json`, campo `p` de cada anillo). Ver `docs/MAPA_CELDAS.md`.

## Cómo se arman 1096 y 1500 (sin recortar nada)

El año 1 se hizo recortando las provincias de hoy con los territorios de la época (Godot + `Geometry2D`) y de ahí salieron las celdas. Las épocas nuevas **reparten esas mismas celdas**:

1. **Territorios.** Estados: polígonos de **Cliopatria v0.2.1** (Seshat Global History Databank, **CC BY 4.0**) cortados en cada año por `extraer_cliopatria.py` → `fuentes/cliopatria_1096.json` y `cliopatria_1500.json` (135 y 130 estados; los nombres entre paréntesis de Cliopatria son «paraguas» de un señor feudal sobre otros y se descartan; solo anillos exteriores). Sus fichas (nombre, tipo, población, capital, moneda, división, etnias) están en `datos_medieval_estados.py` (117 fichas en 1096 y 112 en 1500). Pueblos sin estado: las zonas dibujadas a mano del año 1 (`datos_1dc_pueblos_*.py`) con el nombre y la población de cada época (`datos_medieval_pueblos.py`: 109 pueblos en 1096 y 99 en 1500; los pueblos de la Europa romana que ya son parte de un estado no entran).
2. **Reparto por mayoría (raster).** Cada celda se dibuja en una imagen de 4.800 × 2.400 px y cada territorio en otra (primero los pueblos, luego los estados; dentro de cada grupo se pinta primero lo más grande, así gana lo más pequeño). La celda es del territorio que cubre más de su superficie. Un territorio que no gana ninguna celda se queda con la que más cubre (si cubre un poco), para que los estados chicos no desaparezcan; si casi no le queda tierra, desaparece como en el año 1.
3. **Lo mismo que el año 1 desde ahí:** piezas = celdas de la misma provincia de hoy y el mismo territorio; **huecos habitados** (`reclamar_huecos`: lo habitable que queda sin dueño pasa al vecino; los estados solo se quedan astillas); agrupación de piezas pequeñas (`--min-area`, 45 px² ≈ 12.500 km²; el año 1 usa 70 con piezas más finas); `construir_mapa.py`, `construir_vecinos.py` y `construir_ids.py` con `GE_DATOS` apuntando al escenario.
4. **Datos de juego:** población por nación repartida por habitabilidad (`construir_info`), economía por arquetipo (`plantilla_med`), divisas de la época (`datos_medieval_estados.DIVISAS`), ejército = población × tasa por tipo de nación (`TASA`), ciudades (`datos_medieval_ciudades.py`: 303 en 1096 y 296 en 1500, más la capital de cada nación), banderas (estandartes dibujados por código con prefijo `e1096_` / `e1500_`, 96 y 256 px) y nombres de mandos (cultura por región, `cultura_estado`).
5. **Población:** las fichas son estimaciones de orden de magnitud (McEvedy y Jones, Maddison, Livi-Bacci, el consenso historiográfico); las de 1096 se multiplican por 0,88 (`ESCALA_POB`) porque sumaban ~415 M, por encima de lo habitual (300–400 M). **No son censos.**

### Regenerar
```
# 1. celdas del mundo (una vez; la carpeta temporal queda con celdas/)
python3 -I herramientas/epoca/construir_epoca.py --build /tmp/ge_b1
# 2. cada época
python3 -I herramientas/epoca/construir_epoca_celdas.py --anio 1096 --celdas /tmp/ge_b1/celdas [--png reparto.png]
python3 -I herramientas/epoca/construir_epoca_celdas.py --anio 1500 --celdas /tmp/ge_b1/celdas
# Cliopatria (si hace falta volver a cortar un año): herramientas/epoca/extraer_cliopatria.py
```
Escribe `datos/epocas/<año>/` y los estandartes en `banderas/` y `banderas_hd/`. Tarda ~2 minutos (casi todo `construir_mapa.py`). No hace falta Godot.
El script comprueba que las celdas son las del juego (mismo `v0, n, i0, i1` que `datos/provincias_juego.json`). Es determinista.

## Edificios de partida (0.1.8.42)
Cada escenario empieza con los edificios que ya habría (antes empezaba con las provincias vacías). Regla sin sorteo (`Edificios.sembrar_iniciales`, `cantidad_inicial`), la misma para las cuatro épocas:
- desarrollo de la provincia (0–1) = 60 % población (logarítmica, tope 400.000 hab.) + 40 % producción por habitante frente a la de referencia de la época (1.500 US$ antes de 1900, 25.000 desde 1900);
- difusión del edificio = 1 − e^(−años desde su descubrimiento ÷ tiempo de su clase) (A 250, B 300, C 400, D 600, E 900, F 1.500 años): lo antiguo ya está en todas partes y lo recién descubierto casi no;
- umbral de desarrollo por clase (A 0, B 0,12, C 0,28, D 0,45, E 0,62, F 0,80) y cantidad = máximo del edificio × difusión × suavizado; la parte decimal se redondea con un hash fijo de (provincia, edificio);
- las tierras sin reclamar no tienen edificios; no cuestan dinero ni quedan como historia; **siguen sin efectos de juego**.
Totales de partida (y por provincia reclamada): 1 d. C. ≈ 154.000 (41) · 1096 ≈ 156.000 (59) · 1500 ≈ 190.000 (71) · 2026 ≈ 687.000 (90). Tipos distintos presentes: 34 · 46 · 53 · 109 de 109.
(El año 1 tiene más provincias que 1096 y 1500, por eso su total se parece al de 1096 aunque cada provincia tenga menos.)
Coste al empezar la partida: 2026 ≈ 0,5 s y las otras ≈ 0,1 s (una sola vez; escribe el texto de cada provincia directo, sin historial: `sembrar_iniciales` usa `inicial_s` / `inicial_f` y se salta lo que la provincia aún no puede tener).

## Límites conocidos
- Las fronteras de Cliopatria son gruesas y se ajustan a celdas de ~10.000 km²: la frontera real puede quedar a una celda de distancia. Los estados chicos (condados, ciudades-estado) ocupan una celda o dos.
- Los pueblos sin estado usan las mismas zonas del año 1: en mil años cambian el nombre y la población, no el dibujo.
- Las provincias de 1096 y 1500 son las de hoy agrupadas (no hay divisiones históricas): ver la hoja de ruta de la 0.1.8.43 (provincias que cambian de forma con el tiempo, subprovincias y pinturas por provincia; `docs/SUBPROVINCIAS_FUENTES.md`).
- Las pinturas de 1096 y 1500 caen a la de su región, su continente o el mundo (todavía no hay pintura propia de cada nación para esas épocas).

## Créditos (también en el juego: Opciones → Información)
Fronteras de los estados: Cliopatria v0.2.1, Seshat Global History Databank (CC BY 4.0), https://github.com/Seshat-Global-History-Databank/cliopatria — adaptadas a las celdas del juego. El resto (pueblos, poblaciones, ciudades, economía, banderas): estimaciones y dibujos propios de este proyecto.
