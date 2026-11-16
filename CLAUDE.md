# MechForge — instrucciones del proyecto

Juego táctico por turnos de mechs armados por piezas, inspirado en Super Mechs. Godot 4, corre en local (Windows), un jugador contra IA, con progresión completa. "MechForge" es nombre de trabajo.

Hay dos pasos: **paso 1** = versión refactorizada y mejor del núcleo (este plan); **paso 2** = más diseños, mecánicas, armas y poderes (backlog en `docs/PLAN.md`).

## Leer primero, en este orden
1. `docs/PLAN.md` — fases, puertas de verificación y estado. Empieza por la primera fase sin cerrar y actualiza su estado al terminar cada tarea.
2. `docs/GDD.md` — diseño: reglas, fórmulas, armado, progresión, campaña y arte.
3. `docs/reference/original-mechanics.md` — cómo funciona el juego original, con fuentes. Es solo referencia: donde el GDD diga otra cosa, manda el GDD.

## Herramientas
- **Godot 4.7.2 estándar (GDScript, no .NET)**:
  - editor: `C:\Users\DANNY\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64.exe`
  - consola/headless: `C:\Users\DANNY\dev\tools\godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`
  - No está en el PATH; usa la ruta completa (o un script `tools/godot.ps1` que la envuelva).
- **Pruebas: GUT** (addon en `addons/gut/`, versión compatible con Godot 4.7). Ejecutar en headless:
  `& $GODOT_CONSOLE --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- **Formato y lint:** gdtoolkit (`pip install gdtoolkit`) → `gdformat` y `gdlint`.
- **Shell:** en Windows prefiere PowerShell para invocar Godot. Git Bash (MSYS) reescribe argumentos que empiezan con `/`; si lo usas, antepón `MSYS_NO_PATHCONV=1`.
- **Equipo:** RTX 4050 Laptop (6 GB VRAM, CUDA 12.1 con torch disponible en Python 3.12), 16 GB RAM.

## Arquitectura (reglas duras)
1. **`core/` es lógica pura** en GDScript (`RefCounted`/`Resource`): sin `Node`, sin escenas, sin UI. Es determinista: todo el azar pasa por un `RandomNumberGenerator` con semilla que se inyecta. Debe poder simular 10 000 combates en headless.
2. **`data/` contiene el catálogo y las reglas** como `Resource` (`.tres`) o JSON validado. No hay números de balance escritos en el código: todo vive en `RulesConfig` o en los datos.
3. **`scenes/` y `ui/` son presentación**: leen el estado del core y le envían acciones; nunca mutan el estado directamente.
4. **`tests/`** usa GUT. Cada regla del GDD §2 tiene al menos un test, y cada bug corregido añade el suyo.
5. **`tools/`** guarda el simulador de balance, el pipeline de arte y los scripts auxiliares.
6. **Guardado** en `user://save.json` con `schema_version` y migraciones.

## Cómo verificar antes de decir "listo"
- **Lógica:** tests GUT en verde en headless; pega el resumen de pasa/falla.
- **Balance:** corre el simulador IA contra IA y reporta las tasas de victoria.
- **UI y arte:** saca una captura del estado relevante y mírala antes de afirmar que se ve bien.
- Una fase no se cierra sin cumplir su "puerta" en `docs/PLAN.md`.

## Límites
- No copiar nombres de objetos, sprites, sonidos ni la marca "Super Mechs". Las mecánicas sí se pueden usar.
- Sin monetización ni moneda de pago: es un juego local de un solo jugador.
- Commit al cerrar cada fase y push a `origin` (repo público del usuario, autorizado el 2026-11-16). Los commits usan el correo noreply de GitHub configurado en este repo.
- Interfaz en español, con los textos en una tabla de traducción para poder añadir inglés después.
