# Notas técnicas 0.1.8.31 — Opciones: ventanas PANTALLA e INFORMACIÓN

## Qué es esta versión
Pedido de Camilo (3 de noviembre, 13:24): *«agregues dos ventanas en el menú de opciones, una para pantalla, o sea, opciones para cambiar resolución y configuraciones gráficas y la otra para la información que ya existe. Esta versión sería la 0.1.8.31»*.
El número de versión es exactamente `0.1.8.31` (`MapaPrincipal.gd` → `VERSION`, `project.godot` y las pruebas que lo comprueban).

**El juego (mapa, guerra, IA, economía, tiempo) no cambia.** Solo cambia el menú de OPCIONES del menú principal.

| | 0.1.8.25 | 0.1.8.31 |
|---|---|---|
| Archivos de código | 21 | 23 (`ajustes.gd`, `menu_pantalla.gd`) |
| Líneas de GDScript | 17.574 | 18.062 |
| Funciones | 857 | 892 |
| Funciones o variables duplicadas (auditoría estática) | 0 | 0 |

## 1. Cómo queda el menú
`OPCIONES` ya no enseña los datos del mapa directamente: abre un submenú con tres botones.

```
MENÚ PRINCIPAL ─ OPCIONES ─┬─ PANTALLA       (nuevo: resolución y gráficos)
                           ├─ INFORMACIÓN    (lo que antes era toda la pantalla de Opciones)
                           └─ VOLVER
```

- **INFORMACIÓN** (`MapaPrincipal._mostrar_opciones_info`): el mismo contenido de siempre (países/soberanías, provincias administrativas, unidades territoriales y la nota sobre las provincias), más una línea con la versión.
- **PANTALLA** (`MapaPrincipal._mostrar_opciones_pantalla`): monta `scripts/menu_pantalla.gd`.
- Se llega igual que antes: menú principal → OPCIONES, y también desde la partida en curso (Esc → MENÚ PRINCIPAL → OPCIONES).

## 2. Ventana PANTALLA
| Ajuste | Valores | Qué hace |
|---|---|---|
| Modo de pantalla | Ventana / Pantalla completa | Pantalla completa usa la resolución de tu pantalla. |
| Resolución de la ventana | 1024×576 … 3840×2160 (solo las que caben en tu pantalla; si arrastraste la ventana con el ratón, ese tamaño aparece también) | Tamaño de la ventana, que se centra. Se apaga en pantalla completa. |
| Ventana sin bordes | sí / no | Quita la barra de título. Se apaga en pantalla completa. |
| Sincronización vertical (VSync) | Desactivado / Activado / Adaptativo | |
| Límite de FPS | Sin límite, 30, 60, 75, 90, 120, 144, 165, 240 | `Engine.max_fps`. |
| Suavizado de bordes del mapa | Sin suavizado / 2x / 4x | MSAA 2D de la ventana. Quitarlo da FPS en PCs flojos. |
| Contador de FPS | mostrar / ocultar | La esquina siempre muestra la versión; los FPS son opcionales. |

Botones: **APLICAR** (apagado mientras no haya cambios), **RESTABLECER** (valores por defecto, sin aplicar hasta pulsar APLICAR) y **VOLVER**.

### Confirmar o revertir
Si el cambio mueve o redimensiona la ventana (modo, tamaño o «sin bordes»), tras APLICAR aparece **«¿Mantener estos cambios?»** con 10 segundos de cuenta atrás:
- **MANTENER**: queda aplicado y se guarda.
- **REVERTIR**, o dejar que se acabe el tiempo: la ventana vuelve a como estaba y no se guarda nada. Así una resolución que se vea mal nunca te deja sin imagen.
Los cambios que no tocan la ventana (VSync, FPS, suavizado, contador) se aplican y se guardan al instante.

### Se guarda y se aplica al arrancar
- Archivo `user://ajustes.cfg`. Se crea la primera vez que confirmas un cambio. **La carpeta es fija entre versiones**: `project.godot` ahora declara `config/custom_user_dir_name="GranEstrategia"` (en Windows `%APPDATA%\GranEstrategia\`). Sin eso Godot usaba una carpeta con el nombre del proyecto, que lleva el número de versión, y cada versión nueva habría empezado con los ajustes en blanco. Para borrar los ajustes basta con borrar `ajustes.cfg` de esa carpeta.
- Al arrancar, `MapaPrincipal._cargar_ajustes()` aplica lo guardado. **Sin archivo no se toca nada**: el juego arranca exactamente como antes.
- Un archivo roto, editado a mano o de otra versión no da error: lo válido se usa y lo demás vuelve a su valor por defecto (`Ajustes.sanear`).

## 3. Código nuevo
| Archivo | Qué hace |
|---|---|
| `scripts/ajustes.gd` (`Ajustes`) | Toda la lógica de valores, sin interfaz: `por_defecto`, `sanear`, `iguales`, `existe` / `cargar` / `guardar` (ConfigFile), `resoluciones_para`, `texto_resolucion`, `texto_fps`, `posicion_centrada`, `requiere_confirmacion`, `leer_actual(ventana, previo)` y `aplicar(ajuste, ventana)`. |
| `scripts/menu_pantalla.gd` (`MenuPantalla`) | La ventana: controles, `poner`, `restablecer`, `aplicar_pendiente`, `confirmar`, `revertir`, cuenta atrás. Señales `aplicado(ajustes)` y `volver_pedido`. |
| `MapaPrincipal.gd` | `_mostrar_opciones` (submenú), `_mostrar_opciones_pantalla`, `_mostrar_opciones_info`, `_cargar_ajustes`, la variable `ajustes` y `_actualizar_fps` (versión siempre, FPS si el ajuste lo permite). |

Decisiones:
- **Nada toca la ventana hasta APLICAR.** Los controles solo editan `pendiente`.
- **La verdad de la ventana se lee de la ventana.** Al abrir PANTALLA, tamaño y modo salen de la ventana real (por si la maximizaste o la arrastraste); VSync, FPS y suavizado salen del último ajuste aplicado, porque el sistema no los cambia por su cuenta (y algunos drivers no devuelven bien el VSync).
- **Pantalla completa no pisa el tamaño de ventana guardado**: al volver a modo ventana se recupera el tamaño elegido, no el de la pantalla.
- **No se añadió «resolución de render» ni escala de interfaz**: el HUD está maquetado para 1280×720 y el escalado es automático (`canvas_items`); cambiar eso es un trabajo aparte.

## 4. Pruebas
`test/runner74.tscn` — **124 comprobaciones**, 0 fallos:
- **Ajustes (lógica pura)**: valores por defecto, `sanear` (tipos equivocados, fuera de rango, decimales, claves desconocidas, sin modificar la entrada), `iguales`, guardar → cargar, archivo ausente, a medias o ilegible, resoluciones según la pantalla (y una actual que no está en la lista), centrar la ventana, cuándo se pide confirmación.
- **Sobre la ventana real**: aplicar FPS, suavizado, VSync y tamaño; ir a pantalla completa y volver (centrada, con el tamaño pedido, sin bordes); `leer_actual` con y sin ajuste previo.
- **MenuPantalla**: cada desplegable y casilla llega a `pendiente`; valores inválidos saneados; APLICAR apagado sin cambios; RESTABLECER; en pantalla completa se apagan resolución y «sin bordes»; APLICAR sin confirmación (se guarda ya), con confirmación (no se guarda), la cuenta atrás, MANTENER, REVERTIR con el botón, REVERTIR por tiempo, REVERTIR desde pantalla completa, y que `revertir()` o `_tick()` fuera de una confirmación no hacen nada.
- **MapaPrincipal**: el submenú OPCIONES (PANTALLA, INFORMACIÓN, VOLVER), la ventana INFORMACIÓN con sus cifras, ir y volver entre menús, que lo aplicado llegue a `main.ajustes`, el contador de FPS encendido y apagado, y `_cargar_ajustes` con y sin archivo.

Las pruebas usan un archivo temporal (`user://prueba_ajustes.cfg`) y dejan la ventana en 1280×720 y sin límite de FPS; no tocan tu archivo de ajustes real.
Además se hicieron capturas de las cuatro pantallas (submenú, PANTALLA, confirmación, INFORMACIÓN) para revisar el diseño.

Regresión: ver `CHECKLIST_TESTING.md`.

## 5. Lo que NO está probado
- **En tu PC real**: aquí la pantalla es virtual (Xvfb, 1280×720 y sin gráfica). VSync, límite de FPS y suavizado se comprueban contra el motor, pero el efecto en FPS depende de tu tarjeta.
- **Varias pantallas / DPI alto / escalado de Windows al 125–150 %**: la ventana se centra en la pantalla donde está; no se probó con dos monitores.
- **Pantalla completa de verdad** (cambio de modo con tu monitor): se probó el cambio de modo en Xvfb, no con tu monitor.
- **Adaptativo**: algunos drivers lo tratan como «Activado».
- **Esc dentro de OPCIONES** no hace nada (como en el resto del menú principal); se sale con VOLVER.
- **OPCIONES dentro de la pausa**: no hay botón (se llega por MENÚ PRINCIPAL, la partida sigue con CONTINUAR).
