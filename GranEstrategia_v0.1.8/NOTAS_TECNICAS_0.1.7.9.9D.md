# Notas técnicas 0.1.7.9.9D — ejército por pelotones

## Qué es esta versión
El ejército entra a la **base de datos principal** (no hay otra base). Todavía no hay guerra: las tropas existen, envejecen, se pueden mirar en
el panel y se pueden mover / reclutar / diezmar desde Debug. La devastación de provincia también existe como variable, con efectos
(producción, riesgo de motín) pero sin nada que la provoque salvo Debug.

## Modelo de datos
```
Mundo > Continente > País > Ejército > Pelotón        (cada flecha es «padre_id»)
                                         └── ubicacion → ID de una PROVINCIA (variable, con historial)
```
- Dos tipos nuevos de territorio en `scripts/base_datos.gd`: `ejercito` (`T_EJERCITO = 7`, IDs desde 10.000.000, padre = país) y `peloton`
  (`T_PELOTON = 8`, IDs desde 11.000.000, padre = ejército). Rangos de documentación en `datos/ids.json` y `herramientas/construir_ids.py`.
- **Se crean al empezar la partida** (`Mundo.iniciar_ejercito`), no están en `datos/ids.json` (que sigue con 15.304 filas). Un solo
  `BaseDatos.anadir_territorios(filas)` agrega todas las filas (249 ejércitos + ~21.600 pelotones) y hace crecer cada columna de cada variable.
  Los IDs de pelotón no se reutilizan; disolver un pelotón lo deja `activo = 0` con su historial.
- 10 variables nuevas en `datos/variables.json` (ahora 31): `devastacion` (provincia), `soldados`, `edad_media`, `experiencia`, `familiaridad`,
  `forma_fisica`, `bajas_mes`, `bajas_total`, `ubicacion` (pelotón) y `tasa_militar` (ejército).
  - Historial **por cambio** solo en `soldados`, `ubicacion`, `devastacion` y `tasa_militar`: cada baja, refuerzo o movimiento deja una fila.
  - Edad, experiencia, familiaridad, forma física y bajas: **sin historial** y se actualizan cada mes directo en las columnas (21.600 pelotones ×
    mes × 5 variables pesaría demasiado).
  - Agregaciones del catálogo: `soldados` y `bajas_total` = suma; edad/experiencia/familiaridad/forma = media ponderada por `soldados`.
    **Ojo:** `BaseDatos.agregado` suma sobre una lista explícita de IDs, no sube solo por la cadena padre→hijo; por eso `Ejercito.resumen(lista)`
    recibe la lista de IDs de pelotón que quieras sumar (los de un país, los de una provincia…).

## Reglas (`scripts/ejercito.gd`) — TODAS PROVISIONALES
- **Pelotón**: hasta 1.000 soldados (`TAM_PELOTON`).
- **Tropas de 2026** (`generar_inicial`): `soldados del país = población × tasa` (`datos/ejercito_2026.json`; estimaciones MÍAS de memoria, sin
  verificar; ~55 países con tasa propia, el resto `tasa_defecto` 0,0022; lista `sin_ejercito` para Costa Rica, Panamá, microestados…).
  Se reparten por provincias con peso `población^0,7` y ×1,25 para la provincia de la capital; pelotones completos de 1.000 + 1 pelotón con el
  resto (si pasa de 50). Resultado de la prueba: 249 ejércitos, 21.612 pelotones, 21,5 millones de soldados (Colombia 303 pelotones ≈ 302.000;
  Rusia 1.319; Europa 2.351). La primera versión (peso capital ×3 y población^0,85) dejaba 33–50 % del ejército de Colombia en Bogotá: se cambió.
- **Atributos iniciales** (semilla fija 20260101): edad N(28; 3) entre 22–36, experiencia N(42; 8) entre 15–70, familiaridad N(50; 8) entre 20–80.
- **Cada mes** (`avanzar_mes`, lo llama `Mundo.avanzar_mes`): los soldados envejecen 1/12 de año y se retira ≈ 1,1 % al mes (≈ 8 años de servicio),
  reemplazados por reclutas de 19 años → la edad media se estabiliza. Experiencia y familiaridad suben con rendimientos decrecientes
  (+0,9 y +1,4 puntos/mes, frenados si hubo bajas ese mes). Forma física = 100·exp(−((edad−24)/16)²).
- **Bajas** (`aplicar_bajas`): quita soldados, suma `bajas_total`/`bajas_mes`, baja familiaridad (−70 % × fracción perdida) y algo de experiencia
  (los veteranos caen), dejando una fila de historial en `soldados`. Si no queda nadie, `disolver`.
- **Reforzar/reclutar**: los reclutas (edad 19, experiencia 0, familiaridad 0) se mezclan con los que ya estaban (promedio ponderado);
  `reclutar(país, provincia, n)` completa primero los pelotones incompletos de ese país en esa provincia y el resto crea pelotones nuevos.
- **Mover**: cambia `ubicacion` (con historial) y los índices `por_prov`.
- **Devastación** (`Provincia.devastacion`, 0–1): producción × (1 − 0,85 × devastación); se recupera −4 % relativo −0,2 puntos por mes (sin historial);
  `Mundo.riesgo_motin` = 3 % + 40 % × devastación + 25 % × descontento (favorabilidad < 50) + 20 % × (1 − familiaridad de las tropas allí).
  Todavía no provoca motines.
- Índices en memoria (no se guardan): `por_prov` (provincia → pelotones) y `por_pais`; `version` sube con cualquier cambio.

## Mandos con nombre (`scripts/mandos.gd`, `datos/nombres_cultura.json`)
- `herramientas/hacer_nombres_cultura.py` genera 43 culturas (nombres y apellidos masculinos, orden de escritura: nombre-apellido, hispano
  con dos apellidos, o apellido-nombre), el mapa de los 249 países a una cultura y 4 eras de títulos (Antigüedad < 500, Edad Media < 1500,
  Moderna < 1800, contemporánea).
- Los nombres **no se guardan**: se calculan al abrir el pelotón con un generador cuya semilla sale de IDs estables (país, provincia, pelotón) y el
  año (país: cada 4 años; provincia y pelotón: cada 3). Mismo pelotón = mismos jefes al reabrirlo; rotan solos con los años.
- El jefe de Estado sale de `Historia.gobernantes_en` (Wikidata) cuando se conoce y se muestra en dorado; el resto son nombres inventados.
- Corregido en esta versión: la cultura «eslavo oriental» mezclaba nombres ucranianos con rusos (un general ruso salía «Oleksandr Tkachenko»);
  ahora hay `ruso` (Rusia, Bielorrusia, Baikonur) y `ucraniano` (Ucrania).

## Interfaz
- Panel de información: 5.ª pestaña «Ejército» (`hud.gd` `_tab_ejercito`; los datos los arma `MapaPrincipal.ejercito_vista()`). País / continente /
  estado / provincia / ciudad; detalle de pelotón (`ejercito_detalle`) con barras y cadena de mando. Se refresca cada mes sin mover el scroll.
- Debug: 8.ª pestaña «Ejército» (`debug_menu.gd`): reclutar, bajas % (provincia o país), mover N pelotones, devastación (slider), pasar un mes,
  disolver. Todo con motivo «Debug».
- Iconos nuevos `i_ejercito.png`, `i_devast.png` (`herramientas/hacer_iconos_ejercito.py`).

## Estado de pruebas (honesto)
Godot 4.3 en Linux, xvfb + render por software (sin tarjeta gráfica). Corrida final con todo el código de 0.1.7.9.9D:
- `runner9` (NUEVO, ejército): **49 comprobaciones, 0 fallos**, con los datos históricos REALES de Camilo (1.902 estados). Cubre: 249 ejércitos y 21.612
  pelotones creados en la base (bd.n = 15.304 + 1.902 + 249 + 21.612), cadena pelotón > ejército > país > continente > mundo, Colombia
  ≈ población × tasa (302.234 soldados), Costa Rica sin ejército, ningún pelotón > 1.000, ubicaciones coherentes con el dueño, promedios
  iniciales razonables, mandos por cultura (Rusia/Colombia/Japón; ningún apellido ucraniano en 1.800 mandos rusos), mismos jefes al reabrir, títulos
  que cambian con la época, 24 meses de servicio (experiencia sube, edad estable, sin historial mensual), bajas (soldados, bajas_total, familiaridad,
  1 fila de historial con motivo), refuerzo capado a 1.000, reclutar, mover (historial), disolver (sale de índices, queda inactivo), devastación
  (baja producción, sube riesgo de motín, se recupera sola), HUD (pestaña por país/provincia/continente, detalle de pelotón, capturas revisadas a ojo) y la
  pestaña Debug «Ejército» pulsando sus botones (reclutar, bajas 50 %, devastación 50 %, mover 7 pelotones, pasar mes, disolver) y coherencia final de índices.
- Regresión sobre el código nuevo: `runner3` (mapa/clics/pausa), `runner5` (base de datos, economía, historiales; el único `ERROR` que imprime es
  intencional), `runner6` (barra, Debug, «Mi país», velocidades: 48 OK), `runner7` (capa histórica con la semilla: 43 OK) y `runner8` (datos reales,
  fichas): todos sin fallos ni errores de script.
- Reparto por provincias: tras el ajuste (población^0,7, capital ×1,25) Bogotá tiene ~23 % del ejército de Colombia (14,6 % de la población).
- **NO probado**: jugar a mano (lo pruebas tú), tu PC real (rendimiento) ni Windows; partidas largas con tropas moviéndose; las tasas militares
  contra fuentes reales (son de memoria); tropas dibujadas en el mapa (no existen).

## Límites conocidos
- Las **tasas de soldados por país son estimaciones de memoria**, sin verificar con fuentes. Hay que revisarlas antes de tomarlas como datos.
- Solo nombres **masculinos**; los países con varias culturas usan la dominante (Nigeria, India, Bélgica…).
- La **guerra no existe**: nada genera bajas, devastación ni movimientos fuera de Debug; el motín solo se calcula como riesgo.
- El ejército de 2026 se crea una vez al empezar la partida; la máquina del tiempo (0.1.7.9.9E) tendrá que decidir cómo se arman los
  ejércitos de otras épocas.
- No hay tropas dibujadas en el mapa (solo en el panel).
- Rendimiento: `Ejercito.avanzar_mes` recorre 21.600 pelotones; en la prueba, 12 meses de TODO el mundo (economía + ejército) = 190–340 ms en CPU
  de servidor sin GPU (según la carga del momento), o sea ~16–28 ms por mes. A velocidad 6 (~8 meses/s) serían ~130–230 ms por segundo:
  se nota en un PC modesto; se puede optimizar (p. ej. actualizar las edades cada 3 meses) si hace falta.
- Los datos históricos reales (`datos/historico/`) que bajó Camilo (1.902 estados) van incluidos en el ZIP; las **imágenes** (`banderas_hist/`,
  2.543 archivos) NO van en el ZIP: si abres el proyecto en una carpeta nueva, copia `banderas_hist` de la carpeta anterior.
- Lo pendiente de versiones anteriores sigue igual (ver `NOTAS_TECNICAS_0.1.7.9.9C.md`).

## Cómo regenerar
- `python3 herramientas/hacer_nombres_cultura.py` → `datos/nombres_cultura.json`.
- `python3 herramientas/hacer_iconos_ejercito.py` → iconos.
- `python3 herramientas/construir_ids.py` → `datos/ids.json` (conserva los IDs; añade los rangos de ejército/pelotón).
- `python3 herramientas/hacer_diagrama_bd.py` → diagramas en `docs/`.
