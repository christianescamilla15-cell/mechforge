# MechForge — Plan de construcción

Actualiza la tabla de estado al terminar cada tarea. Una fase se cierra solo cuando se cumple su **puerta**, con la evidencia pegada en la columna de notas (resumen de tests, salida del simulador o ruta de la captura).

## Estado
| Fase | Nombre | Estado | Notas / evidencia |
|---|---|---|---|
| F0 | Preparación | **cerrada** 2026-11-16 | Godot 4.7.2 + GUT 9.7.1 + gdtoolkit 4.5.0. `tools/test.ps1` en verde y devuelve exit 1 con un test roto; `--import` sin errores |
| F1 | Motor de combate (core) | **cerrada** 2026-11-16 | 63 tests / 197 comprobaciones en verde (`test_battle_turns`, `test_battle_weapons`, `test_mech_build`). Prueba de mutación: quitar la rotura de energía hace fallar la suite. `gdlint` y `gdformat` limpios |
| F2 | Datos y catálogo | **cerrada** 2026-11-16 | 58 piezas en `data/catalog.json`; el validador pasa con los 214 nombres del original prohibidos. 4 mechs de ejemplo (994, 985, 983 y 984 kg). 95 tests / 333 comprobaciones; 96 combates de estrés con acciones al azar sin romper el estado. Añadida la mejora M6 |
| F3 | IA y simulador de balance | **cerrada** 2026-11-16 | Puertas en Divino máximo, 1600 combates: físico 51.5 %, calor 49.8 %, energía 48.8 %, híbrido 48.0 %; 12.3 turnos; sin apagados seguidos; IA normal 100 % contra IA al azar. 109 tests / 428 comprobaciones. Limitaciones en la sección F3 |
| F4 | Spike de arte | en curso | Decidido: generación local en la RTX 4050 y estilo mecha japonés (GDD §11). Entorno en `C:\Users\DANNY\dev\tools\mechforge-art\venv` (`tools/art/setup.ps1`); falta instalarle torch con CUDA y elegir el modelo. Requiere aprobación del estilo por el usuario |
| F5 | Combate jugable (UI) | en curso | Parte jugable con arte provisional hecha el 2026-11-16: combate completo contra la IA con previsión, casillas resaltadas, registro y resultado. `tools/live.ps1 -Ui` lo juega en la ventana real a través de los controles y guarda capturas (revisadas). 112 tests / 445 comprobaciones. Falta: arte definitivo, animación por piezas, partículas y medir 60 FPS |
| F6 | Taller de armado | pendiente | |
| F7 | Progresión y guardado | pendiente | |
| F8 | Campaña | pendiente | |
| F9 | Pulido y exportación | pendiente | |

Orden: F0 → F1 → F2 → F3 en serie (cada una depende de la anterior). A petición del usuario (2026-11-16), el combate jugable de F5 se hizo antes que F4, con figuras provisionales, para poder probar las mecánicas en vivo cuanto antes; el arte de F4 sustituye después el dibujo de `MechView` sin tocar el resto.

## Paso 1

### F0 — Preparación
- Crear el proyecto Godot (`project.godot`) con la estructura `core/`, `data/`, `scenes/`, `ui/`, `tests/`, `tools/`, `assets/`.
- Instalar GUT en `addons/gut/` con la versión compatible con Godot 4.7, e instalar gdtoolkit.
- `tools/test.ps1`: corre GUT en headless y devuelve código de salida distinto de 0 si algo falla.
- `tools/godot.ps1`: envuelve la ruta del ejecutable de Godot.
- Inicializar git con `.gitignore` para Godot (ya creado). Sin commit hasta que el usuario lo pida.

**Puerta:** `tools/test.ps1` corre un test de ejemplo en verde y el proyecto abre en el editor sin errores.

### F1 — Motor de combate (core)
- `BattleState` (dos mechs, posiciones, turno, acciones restantes, registro), `BattleEngine` (aplica acciones), `RulesConfig` (todos los números y los interruptores M1–M5) y `BattleLog` (eventos legibles para la UI y para las repeticiones).
- Acciones del GDD §2.3, ciclo de turno §2.2, fórmula §2.4, efectos §2.5, validaciones §2.6 y mejoras §2.7.
- RNG con semilla inyectada. Repetición: el mismo estado inicial, semilla y lista de acciones producen el mismo registro.

**Puerta:** al menos 1 test por regla del GDD §2 (incluidos los bordes: arena 0/9, sobrecarga 1000–1010 kg, rotura de energía, apagado y enfriado forzado, M2 sin apagados seguidos, y M5 iniciativa); test de repetición determinista; todo en verde.

### F2 — Datos y catálogo
- Esquema `ItemDef` (tipo, elemento, tags, tier inicial y máximo, stats base, anclas de arte) y `MechBuild`.
- Validador de catálogo: rangos del GDD §6, M1 (variación de daño ≤ 30 % de la media), alcances dentro de 1–10 y nombres únicos que no coincidan con los del original (la lista de nombres prohibidos se genera desde `docs/reference/`).
- Las ~58 piezas propias del GDD §6 y los multiplicadores de tier y nivel del GDD §8.

**Puerta:** el validador pasa sin errores; un test arma 3 mechs de ejemplo (uno por elemento) dentro de 1000 kg.

### F3 — IA y simulador de balance
- IA por utilidad del GDD §7, con 3 dificultades.
- `tools/sim`: IA contra IA en headless, N combates con semillas distintas. Reporta tasas de victoria por elemento, duración media en turnos, porcentaje de turnos perdidos por apagado y uso de cada pieza.

**Puertas:**
- La IA normal gana al menos el 95 % de las veces a una IA que elige al azar.
- En espejos de tier, ningún elemento gana más del 55 %.
- Al menos un build híbrido gana entre el 45 % y el 55 %.
- Combates de 6 a 14 turnos de media.
- Con M2 encendido, ningún combate tiene dos apagados seguidos.

**Cómo se midió y qué queda pendiente:**
- El simulador promedia sobre 5 escalas de vida (0.92–1.08) para no medir la paridad de un valor concreto. Para reproducirlo: `tools/sim.ps1 --battles=100 --seed=4242`.
- Épico (100 combates por cruce) también pasa. En Común, promediando niveles, los elementos quedan en 50 % pero el híbrido sube al 61 %: el redondeo de números pequeños desplaza el balance. No se ha corregido.
- Con M5 quien empieza gana el 55–58 % de los espejos (71 % sin M5). Queda una ventaja pequeña para quien empieza.
- El balance vale para los cuatro mechs de ejemplo, que pelean casi siempre a distancia 1–2: las armas de largo alcance apenas se usan. Dar valor real a la distancia queda para el paso 2 (terreno) o para cuando existan los enemigos de la campaña.
- Rendimiento: unos 95 ms por combate con 12 hilos (10 000 combates ≈ 16 minutos).

### F4 — Spike de arte (IA)
Decidido con el usuario: generación local y estilo mecha japonés. El pipeline y sus alternativas están en `docs/reference/art-pipeline.md`. Pasos, cada uno con su comprobación:

1. **Entorno** (`tools/art/setup.ps1`): entorno virtual aislado con torch para CUDA y diffusers. Comprobación: el script termina con "ENTORNO OK".
2. **Prueba de estilo** (`tools/art/style_test.py`): mechs completos de referencia, uno por elemento, solo con el modelo base. Comprobación: mirar las imágenes; medir segundos por imagen y pico de VRAM. **Aquí el usuario aprueba o corrige el estilo** antes de seguir.
3. **Control de silueta:** generar una pieza desde una silueta nuestra con el ControlNet. Comprobación: el contorno recortado coincide con la silueta.
4. **Recorte y normales:** fondo transparente con BiRefNet y mapa normal con Marigold. Comprobación: bordes limpios; una esfera de prueba se ilumina en Godot desde el lado correcto.
5. **3 mechs completos por piezas** (uno por elemento) con su JSON de anclas, y visor de montaje en Godot con luces 2D y un shader de calor de prueba.
6. **Un escenario de arena en capas** con el mismo estilo (GDD §12.1), para aprobar mechs y fondo juntos.

Si SDXL resulta demasiado lento en 6 GB, el plan B es un modelo SD 1.5 de anime (cabe entero en la GPU, a menor resolución).

**Puerta:** el usuario aprueba el estilo viendo capturas de los 3 mechs montados, iluminados y con el shader de calor.

### F5 — Combate jugable (UI)
- Escena de arena, mechs montados con sus anclas, botones de acción (solo las legales), previsualización M3, barras de vida, calor y energía, y registro.
- Animación por piezas, partículas y sacudida de cámara (GDD §11).

**Puerta:** un combate completo contra la IA de principio a fin, con capturas de 3 momentos (inicio, apagado del rival y victoria); 60 FPS medidos en la laptop.

**Hecho en la parte jugable:**
- `scenes/main.tscn`: menú mínimo para elegir mech propio, rival, tier y dificultad.
- `BattleScreen` reproduce los eventos del motor uno a uno con la foto de estado que trae cada evento; nunca cambia el estado por su cuenta.
- `MechView` dibuja cada pieza como un bloque del color de su elemento, y el calor tiñe el torso de rojo.
- Los textos de la interfaz están en `ui/texts.gd`.
- Pruebas en vivo: `tools/live.ps1` abre el juego real, la IA juega el combate y se guardan capturas; con `-Ui` el lado del jugador pasa por los mismos controles que una persona. CDP no aplica: el juego es una app nativa de Godot, no un navegador.
- `tools/play.ps1` abre el juego para jugar a mano.

**Falta en F5 (presentación del combate, GDD §12):**
- Campo `fx` en el catálogo y su validación.
- Animaciones por piezas de todos los grupos del GDD §12.2, con partículas, sacudida de cámara y pausa en los golpes fuertes.
- Sonido de cada evento del combate (GDD §12.3) y música de combate.
- Escenario de la arena en capas (GDD §12.1), al menos el de entrenamiento.

**Puerta de presentación:** el test de cobertura pasa (ningún evento ni tipo de `fx` sin animación o sonido); la prueba en vivo deja capturas revisadas de cada tipo de acción sobre el escenario; el usuario da el visto bueno al sonido escuchándolo; 60 FPS medidos en la laptop.

### F6 — Taller de armado
- Equipar piezas por hueco, barra de peso con sobrecarga, resumen de stats, avisos (sin torso o piernas, resistencias repetidas, más de 1010 kg) y vista previa del mech montado.

**Puerta:** armar un mech, guardarlo, pelear con él y ver el resultado.

### F7 — Progresión y guardado
- Inventario, niveles por poder, fusión, transformación de tier, oro y núcleos, botín, cajas y taller de mejoras (GDD §8).
- Guardado en `user://save.json` con `schema_version`.
- Simulador de economía: horas estimadas hasta llevar un build completo a Divino.

**Puerta:** tests de economía y de guardado y carga de ida y vuelta en verde; el simulador da entre 8 y 12 horas hasta Divino.

### F8 — Campaña
- Visión en el GDD §9: un jugador, se empieza con un robot sencillo y se avanza hasta un jefe que exige táctica, como en la versión antigua del juego.
- Buscar antes si esa versión antigua (Flash, un jugador) se conserva, para tomar de referencia su ritmo y su nivel de detalle.
- Mapa de nodos, 3 capítulos con unos 10 combates y un jefe cada uno, enemigos en datos, recompensas y desbloqueos.

**Puerta:** el capítulo 1 se juega completo; el simulador confirma el 55–70 % de victorias del build esperado en cada capítulo.

### F9 — Pulido y exportación
- Los 4 escenarios, la música de menú y taller, y los sonidos de interfaz que falten (GDD §12).
- Ajustes (volumen de música, efectos e interfaz; velocidad de animación) y textos en la tabla de traducción.
- Exportar el `.exe` de Windows.

**Puerta:** el `.exe` arranca desde una carpeta limpia, en otra ruta, y se puede jugar un combate.

## Herramientas
| Herramienta | Estado | Para qué |
|---|---|---|
| Godot 4.7.2 (estándar) | instalada en `C:\Users\DANNY\dev\tools\godot\4.7.2\` | motor y editor |
| GUT | instalar en F0 | tests en headless |
| gdtoolkit | instalar en F0 (`pip`) | formato y lint de GDScript |
| Generación de imágenes | decidir en F4 | sprites (torch con CUDA 12.1 ya está; `diffusers` no) |
| rembg o similar | instalar en F4 | quitar fondos |
| Generador de normal maps (Laigter o mapa de profundidad) | decidir en F4 | relieve para la luz 2D |
| Bibliotecas de sonido CC0 | elegir en F5 | efectos y música (anotar cada archivo y su licencia) |
| Plantillas de exportación de Godot 4.7.2 | instalar en F9 | exportar el `.exe` |

## Estimación honesta
F0–F3 (lógica, datos, IA y balance) suman alrededor de un día de trabajo del agente. F4 depende de cuánto cueste fijar un estilo que guste. El paso 1 completo, con progresión y campaña, son varios días, no horas.

## Paso 2 — backlog (no empezar hasta cerrar el paso 1)
- **Terreno:** casillas de lava (calor), cobertura (reduce el daño a distancia), reparación (cura por turno) y trampas.
- **Estados:** quemadura (calor por turno), corrosión (baja resistencia), aturdimiento (−1 acción), sobrecarga (más daño y más calor).
- **Poderes o definitivas:** un medidor que se llena al recibir y hacer daño; se gasta en una habilidad del torso o del piloto.
- **Escudos y perks:** nuevos huecos con efectos pasivos.
- **Armas nuevas:** minas que se dejan en una casilla, rayos que atraviesan, torretas desplegables y armas que cambian de modo.
- **Sinergias híbridas:** bonus por combinar elementos (por ejemplo, plasma = calor + energía).
- **Pilotos:** con un árbol de habilidades.
- **Combates 2v2 y 3v3, y jefes tipo Titán.**
