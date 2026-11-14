# El mapa en celdas (0.1.8.35)

Cómo está hecho el mapa desde esta versión, cómo se cambia la forma de las provincias mientras se juega y dónde enchufar variables, funciones y texturas.

## 1. La idea

Antes, cada provincia era un dibujo fijo: su forma estaba «horneada» en las mallas y no se podía cambiar sin regenerar el mapa.

Ahora el mundo está cortado en **celdas** (16.056 piezas, los «anillos» del mapa) y **una provincia es un grupo de celdas**. Las celdas no cambian nunca; lo que
cambia es qué provincia es dueña de cada celda. Por eso:

- la forma de una provincia puede cambiar en pleno juego (cederle territorio a una vecina, fusionar dos, dividir una);
- una **época** (2026, año 1 d. C., las que vengan) es solo una tabla distinta «celda → provincia»; la geometría es **una sola** para todas;
- cualquier variable que se calcule por celda (relieve, ríos, urbanización…) se queda con la celda cuando esta cambia de provincia.

```
        datos/malla_*  (geometría de las celdas, igual para todas las épocas)
                │
   provincias_juego.json  ←  una por época: lista de provincias y, de cada una, sus celdas
                │
        anillos[c]["p"]  =  provincia de la celda c   (se carga de ahí)
                │
   FusionScript (scripts/fusion_mapa.gd)   relleno por dueño, fronteras, vecindad
   Territorio   (scripts/territorio.gd)    única puerta para CAMBIAR la forma
```

## 2. De dónde salen las celdas

`herramientas/epoca/construir_epoca.py` (≈3 min): corta las provincias de 2026 con los territorios del año 1 y con celdas de Voronoi en las tierras sin reclamar.
Cada trozo que resulta es una celda. Una provincia de 2026 es la unión de las celdas con el mismo padre de 2026; una de 1 d. C., la unión de las celdas que caen en su territorio.
Después `herramientas/construir_mapa.py` (modo `CELDAS`) las triangula, las reparte en teselas, calcula la tabla de pares de celdas vecinas con sus aristas y las costas.

## 3. Las tablas (FusionScript)

| Tabla | Qué es |
|---|---|
| `celda_prov[c]` | provincia a la que pertenece la celda `c` **ahora** |
| `prov_celdas[p]` | celdas de la provincia `p` (lista ordenada) |
| `par_a/par_b[k]`, `par_pa/par_pb[k]` | las dos celdas del par `k` y las dos provincias de cada lado (se mantienen al mover celdas) |
| `pp_ini/pp` | pares en los que participa cada celda |
| `runs_ofs/runs` | dónde están los vértices de cada celda dentro de las teselas (para repintarla) |
| `original_c[c]` | dueño con el que se hornearon los colores de esa celda |

## 4. Cambiar la forma: Territorio

`main.territorio` (clase `scripts/territorio.gd`). Todo cambio pasa por aquí; él avisa al dibujo, a las fronteras, a las cajas de las provincias, al punto donde van las
tropas y a los nombres de país.

Consultas:
`provincia_de(c)`, `celdas_de(p)`, `celda_en(punto)`, `provincias_vecinas(p)`, `celdas_frontera(origen, destino)`, `area_celda(c)`, `area_provincia(p)`,
`centro_celda(c)`, `centro_provincia(p)`, `contiene(p, punto)`, `modificado()`.

Cambios (todos devuelven cuántas celdas se movieron):
- `reasignar(celdas, destino)`: las celdas pasan a la provincia `destino`.
- `fusionar(a, b)`: todas las celdas de `b` pasan a `a`.
- `ceder(origen, destino, n)`: las `n` celdas de `origen` más cercanas a `destino` pasan a `destino` (mueve la frontera; deja al menos una celda).
- `dividir(prov, destino, fracción)`: una fracción de las celdas de `prov` pasa a `destino`. Si `destino` es vecina es `ceder`; si no tiene celdas, el trozo nace en el extremo
  más lejano de `prov` y crece hasta la fracción pedida.
- `deshacer()` (60 pasos), `restablecer()` (vuelve al reparto de la época).

Señal `forma_cambiada(provincias)`: cualquier sistema futuro (economía, población, guerra) puede engancharse para reaccionar a un cambio de forma.

En Debug > Provincia hay una sección «Forma del territorio» con estas operaciones.

### Qué hace y qué NO hace un cambio de forma
Hace: repinta el relleno con el color del dueño de cada celda, rehace las fronteras entre países, actualiza el clic, las cajas, el centro de las tropas y los nombres de país.
No hace (a propósito): mover edificios o tropas con las celdas; crear provincias que no existen en la época;
recalcular los kilómetros de los tramos del buscador de caminos (los vecinos de la época siguen valiendo); mover los nombres de provincia horneados ni la línea de los estados.

**Desde la 0.1.8.43** la regla de juego existe: `MapaPrincipal.ceder_parcial(origen, destino, fracción, motivo, diferir)` mueve las celdas y con ellas la población, la producción (por habitante) y las
ciudades por superficie, deja historial en los dos países y descarta las subprovincias guardadas; la paz con posesión la usa para partir una provincia grande (`Guerra.fraccion_conquista`).
**Desde la simulación se llama con `diferir = true`** (`Mundo.ceder_parcial_a`): los datos cambian al momento pero el repintado (relleno, fronteras, nombres, país enfocado: 15–25 ms por provincia) se hace
en los fotogramas siguientes, por etapas y agrupando varias cesiones (`_forma_pend` / `_repintar_forma_pendiente`). Repintar dentro de la paz daba picos de 300 ms con todas las IA a x6.

## 5. Cómo agregar variables al mapa

1. **Por celda** (relieve, ríos, urbanización…): un script de `herramientas/` escribe `datos/celda_<nombre>.json` con una cifra por celda (índice = orden de los anillos).
   En el juego se lee una vez y la provincia suma o promedia sus celdas de hoy: `terr.celdas_de(p)`.
2. **Por provincia** (las que ya existen: población, favorabilidad…): siguen en la base de datos como siempre; no dependen de la forma.
3. **Que reaccione al cambio de forma**: conéctate a `territorio.forma_cambiada`.

## 6. Texturas

Hay un gancho para una textura del mundo entero (proyección equirectangular):

- `main.poner_textura_relieve(textura, fuerza, neutro)` la pone (o la quita con `null`). Se multiplica sobre los colores de las provincias dentro del propio relleno:
  sin capas nuevas ni triángulos nuevos y sin depender de la forma de las provincias.
- Si existe `datos/texturas/relieve.png` se carga sola al abrir el mapa. `herramientas/preparar_relieve.py ENTRADA.png` convierte cualquier imagen del mundo (por ejemplo el
  relieve sombreado de Natural Earth) al formato correcto (gris, gris medio 0,5, tamaño elegido).
- Sin textura el relleno no lleva material (coste cero). La calidad gráfica Baja apaga el relieve.

Para cambiar el aspecto de un sistema entero (colores de provincias, fronteras, costa) siguen valiendo los materiales de `MapaPrincipal.gd` (`mat_frontera`, `mat_costa`…).

## 7. Rendimiento

- Cambiar la forma cuesta lo de un repintado forzado (relleno de las celdas tocadas + fronteras + nombres); no hay mallas que regenerar.
- La geometría compartida ocupa más que antes porque las celdas son más pequeñas que las provincias, pero el paquete de cada época (solo la tabla de provincias) es
  mucho más ligero: el año 1 d. C. pasó de 46 MB a 4,3 MB y la carpeta `datos/` de 113 MB a 80 MB.
- Coste frente a 0.1.8.34 (medido con `runner89`): +7 % a +18 % de triángulos en vista lejana (sin cambio con zoom cercano), ~+39 MB de memoria y ~0,1–0,2 s más de carga.
  Detalle en `NOTAS_TECNICAS_0.1.8.35.md`.
- **Clic y cursor**: buscar «qué celda hay bajo este punto» usa una rejilla de casillas de 20 px (`_anillo_en`): se miran solo las celdas de la casilla del punto, no las 16.056. Da exactamente lo
  mismo que recorrerlas todas (lo comprueba `runner76`) y es mucho más rápido. La rejilla se construye una vez porque las celdas no se mueven nunca.
- Regenerar con `construir_epoca.py` rehace también la geometría compartida de `datos/`, así que 2026 y el año 1 siguen cuadrando entre sí.
- Las pruebas de rendimiento están en `test/runner89.gd` y las de territorio en `test/runner76.gd`.
