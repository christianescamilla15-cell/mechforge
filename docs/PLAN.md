# MechForge — Plan de construcción

Actualiza la tabla de estado al terminar cada tarea. Una fase se cierra solo cuando se cumple su **puerta**, con la evidencia pegada en la columna de notas (resumen de tests, salida del simulador o ruta de la captura).

## Estado
| Fase | Nombre | Estado | Notas / evidencia |
|---|---|---|---|
| F0 | Preparación | **cerrada** 2026-11-16 | Godot 4.7.2 + GUT 9.7.1 + gdtoolkit 4.5.0. `tools/test.ps1` en verde y devuelve exit 1 con un test roto; `--import` sin errores |
| F1 | Motor de combate (core) | **cerrada** 2026-11-16 | 63 tests / 197 comprobaciones en verde (`test_battle_turns`, `test_battle_weapons`, `test_mech_build`). Prueba de mutación: quitar la rotura de energía hace fallar la suite. `gdlint` y `gdformat` limpios |
| F2 | Datos y catálogo | **cerrada** 2026-11-16 | 58 piezas en `data/catalog.json`; el validador pasa con los 214 nombres del original prohibidos. 4 mechs de ejemplo (994, 985, 983 y 984 kg). 95 tests / 333 comprobaciones; 96 combates de estrés con acciones al azar sin romper el estado. Añadida la mejora M6 |
| F3 | IA y simulador de balance | **cerrada** 2026-11-16 | Puertas en Divino máximo, 1600 combates: físico 51.5 %, calor 49.8 %, energía 48.8 %, híbrido 48.0 %; 12.3 turnos; sin apagados seguidos; IA normal 100 % contra IA al azar. 109 tests / 428 comprobaciones. Limitaciones en la sección F3 |
| F4 | Spike de arte | en curso | Pasos 1 y 2 hechos el 2026-11-16. Entorno aislado en `C:\Users\DANNY\dev\tools\mechforge-art\env` (`tools/art/setup.ps1`). Illustrious-XL v1.0 genera 1024×1024 en unos 30 s con un pico de 2.8 GB (UNet guardado en 8 bits). **Estilo aprobado por el usuario**: `docs/reference/art/estilo_aprobado.png`, fijado en `tools/art/style.py`; la misma semilla lo regenera idéntico al píxel. El trazo y el color se mantienen en calor y energía, pero el diseño cambia mucho de una semilla a otra (de humanoide a bestia) y alguna composición sale rota. Falta: control de silueta, recorte, normales, 3 mechs por piezas y escenario |
| F5 | Combate jugable (UI) | en curso | Parte jugable con arte provisional hecha el 2026-11-16: combate completo contra la IA con previsión, casillas resaltadas, registro y resultado. `tools/live.ps1 -Ui` lo juega en la ventana real a través de los controles y guarda capturas (revisadas). 112 tests / 445 comprobaciones. **FPS medidos el 2026-11-18** (`tools/fps.ps1`; gráfica integrada Radeon 740M, monitor de 144 Hz): de 138 a 144 de media y ningún cuadro de más de 14 ms, también contra un jefe y con la materia oscura. Falta: arte definitivo y animación por piezas |
| F6 | Taller de armado | en curso | La armería ya tiene el taller (cambiar la pieza de cada hueco, subirla de nivel y transformarla) y la tienda de piezas. Puerta sin comprobar |
| F7 | Progresión y guardado | en curso | Celdas, nivel del jugador, árbol de habilidades y guardado en `user://save.json` con `schema_version`. Puerta sin comprobar |
| F8 | Campaña | en curso | Las 10 zonas de 10 combates y su jefe están en datos y se juegan desde la base; su ritmo está medido zona a zona (GDD §9.3). Puerta sin comprobar: ningún capítulo lo ha jugado entero una persona |
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

1. **Entorno** (`tools/art/setup.ps1`): entorno virtual aislado con torch para CUDA y diffusers. Comprobación: el script termina con "ENTORNO OK". **Hecho.**
2. **Prueba de estilo** (`tools/art/style_test.py`): mechs completos de referencia, uno por elemento, solo con el modelo base. Comprobación: mirar las imágenes; medir segundos por imagen y pico de VRAM. **Hecho: el usuario aprobó el estilo** con la imagen del mech físico de semilla 101 y pidió que el arte final sea exactamente ese. `tools/art/style.py` guarda el prompt y los ajustes, y todo script de arte los toma de ahí.
3. **Control de silueta:** generar desde una silueta nuestra con el ControlNet. Comprobación: el contorno recortado coincide con la silueta. **A medias (2026-11-16):** el ControlNet funciona en la laptop (42 s por imagen, pico de 4.3 GB). Hay receta para cuerpos enteros en los tres elementos, con curado de semillas; las piezas sueltas de torso y piernas no salen, así que se cortan del cuerpo entero por la cadera. Las armas sueltas salen desiguales. Mediciones en `docs/reference/art-pipeline.md` ("Control de silueta: lo medido"). El usuario eligió la línea esbelta (`docs/reference/art/cuerpo_elegido.png`). Falta: lote de cuerpos curado, corte por la cadera y mejorar armas. **Reformulado el 2026-11-16:** el diseño por piezas pasa a basarse en chasis con uniones estándar y piezas dibujadas ya montadas (docs/CHASIS.md); la prueba de concepto con 9 combinaciones encaja. Falta: aprobación del usuario, maniquí del chasis ligero, repintar solo la envolvente de cada pieza y torsos sin brazos.
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

**Primeros modelos en el juego (2026-11-16):** el combate ya dibuja el torso 18 y las piernas 18 del chasis ligero, unidos por el aro y coloreados por elemento (assets/mechs, scenes/battle/mech_sprites.gd, tools/art/export_parts.py). Comprobado con tools/live.ps1 y capturas revisadas. Después se añadieron dos torsos y dos pares de piernas más (cada mech elige los suyos según sus piezas del catálogo) y el cañón de pecho dibujado en su sitio, que de momento se muestra en los mechs con arma superior. Las demás armas aún no tienen arte; el dron sigue provisional.

**Armas montadas y piernas especiales (2026-11-17):** 5 armas de brazo, 3 de hombro y las piernas de orugas, ruedas y levitación, dibujadas sobre el robot base y recortadas por diferencia (docs/CHASIS.md, sección 6). En el combate cada arma va en su hueco, las del lado lejano detrás y más oscuras, dispara desde su boca y retrocede; las piernas especiales van de una pieza. Comprobado en la muestra de movimientos (`tools/clip.ps1 -Showcase`), que ahora también enseña las ruedas y un disparo por hueco. Los drones sueltos se retiraron: los sustituye el robot de asistencia. `tools/clip.ps1` graba en cuadros PNG: el AVI (MJPEG) salía con bloques verdes que no estaban en el juego.

**Un dibujo por forma y tipo de arma (2026-11-18):** las ocho armas montadas se rehicieron porque quedaban planas junto a los cuerpos y el asistente. Ahora son 26 dibujos, uno por cada forma y tipo del catálogo (balas, cañón, bláster y láser), en los tres elementos, cada uno con la boca de la que sale su disparo. La receta que quedó (bloque con detalle propio y control medio) y las cuatro que se descartaron están en docs/CHASIS.md, sección 6. 274 tests (4 nuevos: cada arma de brazo y de hombro tiene su dibujo en los tres elementos). Comprobado en la hoja de armas montadas (`tools/weapon_frames.gd`) y en la muestra de movimientos. Falta: que el usuario las revise; un dibujo por tipo para las armas de pecho; armas visibles en los jefes.

**El asistente flota por encima de su mech (2026-11-18, pedido del usuario):** con las armas de hombro nuevas se montaba sobre ellas. Su altura ya no es fija: flota 18 unidades por encima de lo más alto del mech (torso o arma de hombro, y más si las piernas levitan). La cámara de la arena encuadra también en vertical, para que las formas grandes no se salgan por arriba: con el Arconte se aleja un poco. Comprobado en combate real en clase Intermedia y Única, y en la hoja `tools/weapon_frames.gd ++ --assist`. 276 tests (2 nuevos).

**Ficha de cada arma (2026-11-18, propuesta):** antes de programar los disparos, el usuario pidió definir qué es cada arma y qué daño puede hacer. Está en docs/CATALOGO_ARMAS.md, sección 9: qué decide la forma, el tipo y la munición; cómo llega el daño de cada tipo; qué dispara cada una de las 37 armas y su daño de su primera clase a la última. El usuario eligió la A (el tipo cambia cómo llega el daño, no cuánto).

**Un disparo por arma (2026-11-18):** hecho con la A. Cada una de las 111 armas lleva su disparo en el catálogo (`fx`, 35 distintos: ráfaga de trazadoras, perdigones en abanico, bala de rifle, granada en parábola, salva de misiles, arpón con cable, pernos y bolas de plasma, haces, rayo orbital, novas en anillo, tajos...), definidos en `data/shots.json` y dibujados por `scenes/battle/shot_fx.gd`. Las luces van del color de la munición. El motor y el balance no cambian. Los saboteadores cinéticos pasan a llamarse Repulsor de plasma y Haz repulsor. 283 tests (7 nuevos: cada arma tiene un disparo conocido y cada tipo dispara como dice su ficha). Para verlos: `tools/clip.ps1 -Shots`. Falta: que el usuario los revise; el sonido; que el disparo crezca con las etapas del arma.

**Golpes críticos y estado a la vista (2026-11-18, pedido del usuario):** regla nueva del motor (GDD §2.9). La probabilidad sale del arma (el pecho, casi seguro), de su nivel frente al blindaje del rival, y la bajan la armadura gruesa y el escudo. El crítico pega un 25 % más y, según el tipo, perfora, inmoviliza, quita una acción o inutiliza un arma durante el turno del rival. Ajustado con el simulador en cuatro pasos hasta que los cuatro tipos pasan las puertas (tabla en el GDD). Además, el robot enseña su estado: arañazos, hollín, humo y fuego según baje la vida, y arcos con poca energía (GDD §12.2). La campaña con críticos (tools/economy_sweep.ps1, 24 combates por casilla), con 50 victorias en la zona: 58, 81, 87, 91, 70, 24, 98, 54, 63 y 41 % (antes 46, 88, 88, 79, 66, 26, 96, 57, 63 y 32). Fuera del margen de ±10 puntos: zonas 1 y 4 (+12). Con 25 victorias la zona 3 sube de 17 a 46 %: ahí se compra el cañón pesado, casi seguro de crítico, y en la campaña solo lo lleva el jugador. El usuario decidió dejarla así (2026-11-18).

**Impacto de los golpes (2026-11-18, pedido del usuario):** el golpe empuja según el tamaño del arma (GDD §2.10): brazos solo chispas, hombros 1 casilla, pecho hasta 3 y la materia oscura hasta el borde, con el crítico de su arma de pecho y una secuencia propia de despliegue, carga y disparo por tipo. Los cuatro tipos siguen pasando las puertas con críticos e impacto. 311 tests (10 nuevos). Para verlo: `tools/clip.ps1 -Impact`. La campaña con críticos e impacto, con 50 victorias: 58, 82, 91, 84, 84, 24, 99, 74, 69 y 57 %; se facilitan las zonas 5, 8 y 10 (+14, +20 y +16) porque solo el jugador lleva arma de pecho. El usuario pidió endurecerlas: el entreno de esos jefes pasa a 19, 24 y 30 y, con 50 victorias, quedan en 70, 51 y 32 % (GDD §9.3).

**FPS y la IA en un hilo (2026-11-18):** medido con `tools/fps.ps1` (la IA juega por los dos lados a velocidad normal y `scenes/frame_probe.gd` registra cada cuadro). El dibujo va sobrado: de 138 a 144 FPS de media en un monitor de 144 Hz, con la gráfica integrada. Los tirones venían de la IA, que pensaba en el hilo principal: contra un jefe (IA difícil) una decisión tarda hasta 135 ms, y la imagen se congelaba 16 veces por combate, con cuadros de hasta 143 ms. Ahora la IA piensa en un hilo aparte, sobre su propia copia del combate, y empieza durante la pausa que ya había antes de actuar. Mismos combates (mismo ganador y mismos turnos), y el peor cuadro baja a 12.5–14 ms sin ningún tirón; contra el jefe, el 1 % más lento pasa de 40 a 130 FPS. Un test comprueba que la IA elige lo mismo sobre la copia que sobre el original en combates enteros (312 tests).

**Caídas del motor en los simuladores (2026-11-18, sin resolver):** dos corridas largas de `tools/economy_sweep.ps1` (de unas 22) murieron sin escribir nada; el registro de Windows las anota como `0xc0000005` en la dirección 0 de `Godot_v4.7.2-stable_win64.exe`. Repetir los mismos parámetros no las reproduce, así que apunta a la concurrencia: los simuladores reparten cientos de combates de IA difícil entre 12 hilos que comparten mechs, reglas y catálogo. En el juego no se ha visto. El barrido ahora avisa cuando una zona termina con error. Falta: un banco de pruebas que la reproduzca para encontrar la causa.

**Robot de asistencia (2026-11-17, pedido del usuario):** sustituye al dron de soporte. Un cuerpo con 5 transformaciones (Sonda, Vigía, Centinela, Custodio, Guardián y Arconte, una por clase), dos armas que alternan, un protocolo que bonifica al mech y la mejora "Batería del asistente" en la armería (GDD §4). En el Taller se sube y se transforma como una pieza y sus armas suben con él. 270 tests. Se midió hasta dar con una versión estable: tres diseños descartados por romper el balance entre elementos y uno final que pasa las puertas en los cuatro tipos de arma (docs/CATALOGO_ARMAS.md). Arte: seis formas detalladas, dibujadas a lienzo completo (docs/CHASIS.md, sección 6). La campaña se volvió a medir con asistentes el 2026-11-18 y el ritmo no cambió (GDD §9.3: todas las zonas dentro del margen de la medición anterior). Falta: revisar el clip con el usuario.

**Arena, animaciones y escenarios (2026-11-16):** campo más ancho que la pantalla con cámara que sigue y se aleja, y paisaje en capas con animaciones (scenes/battle/arena_view.gd). Primeras animaciones de combate: despliegue del cañón al primer disparo, retroceso, fogonazo, proyectil, chispas, sacudida de cámara, respiración, rebote al andar, desplome al apagarse, explosión y caída al ser destruido, y la nave que suelta la bonificación. Cuatro escenarios como datos (data/stages.json, scenes/battle/stage_library.gd). tools/clip.ps1 graba un combate real y saca un GIF para que el usuario lo revise; el primer clip ya se le envió. 142 tests.

**Falta en F5 (presentación del combate, GDD §12):**
- Campo `fx` en el catálogo y su validación.
- Animaciones por piezas de todos los grupos del GDD §12.2, con partículas, sacudida de cámara y pausa en los golpes fuertes.
- Sonido de cada evento del combate (GDD §12.3) y música de combate.
- Escenario de la arena en capas (GDD §12.1), al menos el de entrenamiento.

**Revisión con el usuario (pedido el 2026-11-16):** igual que con el arte, cada grupo de animación se le enseña en movimiento antes de darlo por bueno, y se corrige con sus comentarios. Grupos: caminar; saltar o volar; disparar cada tipo de arma; golpe cuerpo a cuerpo; activar poderes (carga, teletransporte y gancho); escudo y resistencias; recibir daño; sobrecalentarse y apagarse; destrucción. Se entrega un clip corto por grupo, grabado del juego real con `tools/live.ps1`, no un montaje aparte.

**Armas por familia y por etapa (pedido el 2026-11-16, GDD §12.2 y §8):** cada familia de arma tiene su forma de desplegarse, disparar e impactar, y cambia con la etapa tecnológica de la pieza (cada 6 niveles). Se empieza por un arma piloto llevada por todas sus etapas, para que el usuario la evalúe antes de repetirlo en las demás. El color personalizable se hace con un shader por zonas. Las armas se orientan a tecnología galáctica (plasma, iones, haces) y se despliegan desde dentro del cuerpo la primera vez que se usan en cada combate; cada arma se dibuja en tramos para poder animar ese despliegue. La propuesta de catálogo por hueco (brazos, hombros, pecho y robot de soporte, 13 familias y 39 armas) y los desbloqueos por nivel del jugador están en docs/CATALOGO_ARMAS.md. El usuario aprobó la estructura el 2026-11-16 y la amplió: división por tipo (balas, cañón, bláster y láser), 37 diseños y 111 armas, y la materia oscura como habilidad del arma del pecho dentro de un árbol de habilidades. Siguiente trabajo de motor: cambiar los huecos del mech en el motor (2 brazos, 2 hombros, 1 pecho), añadir el nivel del jugador, diseñar las 6 armas de pecho y repetir el balance.

**Puerta de presentación:** el test de cobertura pasa (ningún evento ni tipo de `fx` sin animación o sonido); la prueba en vivo deja capturas revisadas de cada tipo de acción sobre el escenario; el usuario da el visto bueno al sonido escuchándolo; 60 FPS medidos en la laptop.

### Rediseño del 2026-11-16: trabajo de motor pendiente
El usuario amplió el diseño en una sesión (GDD §1.1, §8, §9 y §12.2; docs/CATALOGO_ARMAS.md; docs/CHASIS.md). El motor de combate actual sigue con las reglas anteriores y pasa sus 113 tests. Lo que hay que construir, en este orden, cada paso con sus tests y su comprobación de balance:

1. **Chasis:** el mech pasa a tener chasis (ligero, medio o pesado) con sus bonificaciones: el ligero gasta mucha menos energía en sus armas; el pesado tiene mucha más vida y resistencias y se consigue después del nivel 10. El chasis sube de nivel. **Hecho en parte el 2026-11-16:** chasis en el motor con sus multiplicadores, tres chasis en datos, 10 tests (123 en total) y simulador de chasis contra chasis; todos los cruces quedan entre el 40 % y el 60 % (docs/CHASIS.md, sección 5). La bonificación ya crece con el nivel del chasis (20 % en el nivel 0, completa en el 30). Falta: elegir chasis en el menú y en los mechs de ejemplo, y repetir el ajuste con el catálogo nuevo.
2. **Huecos:** el usuario corrigió el 2026-11-16: seis armas como en el original, 4 laterales y 2 superiores, que el motor ya tiene. No hay que cambiar los huecos. **El arma de pecho va aparte** (usuario, 2026-11-17): séptimo hueco, que se abre en el nivel 10 del jugador; hecho el mismo día, con sus 15 armas y el nivel del jugador.
3. **Nivel del jugador:** experiencia por combate y desbloqueo de huecos. **Hecho el 2026-11-17:** soporte al 3 y pecho al 10, lo que fijó el usuario; las seis armas abiertas desde el principio, como en el original.
4. **Catálogo generado:** las 111 armas salen de la tabla forma × tipo × munición; el validador y el simulador comprueban el resultado. Hay que rehacer los mechs de ejemplo. **Hecho en parte el 2026-11-17:** 96 armas (brazos, hombros y soporte) y 16 mechs de ejemplo, 4 por tipo de arma; las cuatro pasan las puertas de F3 (docs/CATALOGO_ARMAS.md). Faltan las 15 de pecho, pendientes de la decisión del usuario.
5. **Árbol de habilidades y materia oscura:** diseñado con el usuario y **hecho el 2026-11-17** (GDD §8): tres ramas libres, 1 punto por nivel, escudo de energía, kit de reparación y materia oscura en el nivel 25.
6. **Bonificaciones que caen en la arena** (GDD §2.8): **hechas el 2026-11-16** en el motor, la IA y la pantalla (137 tests; comprobado con tools/live.ps1: cae la caja y un mech la toma). Falta medir su efecto en el balance. Las **habilidades de combate** del chasis siguen sin diseñar.
7. **Balance:** repetir las puertas de F3 con Mítica como techo de las piezas normales y con los tres chasis.


**Jefe final (2026-11-16):** hecho y medido (GDD §9.1, tools/sim/boss_sim.gd, 144 tests): 3 acciones por turno, misma vida, punto débil en el calor. En pelea directa el jugador gana del 0 al 6 %; con el mech de calor y las bonificaciones, del 13 al 23 %. Pendiente: suavizar el salto entre clases de equipo y la economía de monedas de la arena (fase F7).

**Oro de la arena y tienda (2026-11-16):** hecho y medido (GDD §9.2, 157 tests): perfil del jugador con guardado, oro por combate, tienda de arena con seis mejoras en 10 niveles como en el original, y botones de compra en el menú. Pendiente de F7: tienda de piezas, niveles y transformación de piezas, nivel del jugador.

**Base del jugador, campaña y jefes con habilidad (2026-11-17):** hecho y medido (GDD §9, §9.1 y §9.2; 178 tests). El menú es la base: Campaña (zona 1: 10 combates y un jefe), Arena (rival al azar, para juntar celdas) y Armería. Perder contra un jefe termina la partida, con aviso antes. La moneda pasa a ser "celdas de plasma". Cada jefe tiene una habilidad especial en su chasis; el primero, Superblindaje. Precios ajustados al ritmo del usuario: 50 combates ganados = 47.5 % contra el primer jefe, 100 = 87.5 %. Pendiente: las otras 9 zonas y la progresión por piezas para después del primer jefe.

**Los 10 jefes con su habilidad (2026-11-17):** hecho y medido (GDD §9.1; 190 tests). Lista aprobada por el usuario. El motor tiene las habilidades nuevas en el chasis de jefe (energía infinita, regeneración, escudo, evasión, núcleo térmico y enjambre), la pantalla las enseña y tools/sim/bosses_sim.gd mide a todos con la misma vara. Pendiente: el diseño propio de cada jefe (arte y armas) y reajustarlos cuando exista cada zona.

**Economía de las zonas 2–10 (medida el 2026-11-17, pendiente de ajuste):** tools/economy_sweep.ps1 mide cada zona empezando con lo que tendría el jugador al salir de la anterior. La zona 1 cumple el ritmo del usuario (50 victorias ≈ 40–47 % contra el jefe; 100 ≈ 91–97 %), pero de la 3 en adelante va demasiado rápido:

| Zona | 10 victorias | 25 victorias | 50 victorias |
|---|---|---|---|
| 2 | 19 % | 47 % | 84 % |
| 3 | 3 % | 73 % | 98 % |
| 4 | 47 % | 100 % | 100 % |
| 5 | 3 % | 67 % | 100 % |

Causa: la armería llega al máximo hacia la zona 4 y los rivales no tienen nada equivalente. **Resuelto el mismo día** (aprobado por el usuario): el Orden tiene su armería, que sube zona a zona, y se retocaron cinco jefes. La campaña entera queda en una curva coherente (GDD §9.3).

### F6 — Taller de armado
- Equipar piezas por hueco, barra de peso con sobrecarga, resumen de stats, avisos (sin torso o piernas, resistencias repetidas, más de 1010 kg) y vista previa del mech montado.
- Tienda dentro del taller y garaje con varios mechs guardados (GDD §8): es lo que el usuario recuerda del juego antiguo.

**Puerta:** armar un mech, guardarlo, pelear con él y ver el resultado.

### F7 — Progresión y guardado
- Inventario, niveles por poder, fusión, transformación de tier, oro y núcleos, botín, cajas y taller de mejoras (GDD §8).
- Guardado en `user://save.json` con `schema_version`.
- Simulador de economía: horas estimadas hasta llevar un build completo a Divino.

**Puerta:** tests de economía y de guardado y carga de ida y vuelta en verde; el simulador da entre 8 y 12 horas hasta Divino.

**Pendiente por la ampliación del 2026-11-16 (GDD §8):** topes de nivel 6/12/18/24/30/50 ya en `RulesConfig` (113 tests en verde). Falta: confirmar con el usuario si la clase de una pieza es fija o puede subir; limitar la clase Única a las piezas de jefe y repetir las puertas de balance en Mítica, que pasa a ser el techo de las piezas normales; arte por etapa tecnológica y shader de color.

### F8 — Campaña
- Visión en el GDD §9: un jugador, se empieza con un robot sencillo y se avanza hasta un jefe que exige táctica, como en la versión antigua del juego.
- Buscar antes si esa versión antigua (Flash, un jugador) se conserva, para tomar de referencia su ritmo y su nivel de detalle.
- 10 zonas de 10 combates y un jefe cada una, enemigos en datos, recompensas y desbloqueos. La estructura (base con campaña, arena y armería) y la zona 1 ya están (2026-11-17).

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
| Generación de imágenes | Illustrious-XL v1.0 con diffusers 0.43, en el entorno de arte | sprites (detalle en `docs/reference/art-pipeline.md`) |
| BiRefNet | descargar en F4 (`tools/art/download_models.py`) | quitar fondos |
| Marigold normals (y Laigter para el detalle de línea) | descargar en F4 | relieve para la luz 2D |
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
