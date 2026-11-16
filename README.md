# MechForge

Juego táctico por turnos de mechs armados por piezas, hecho en Godot 4. Duelos 1 contra 1 en una arena lineal de 10 casillas, con tres elementos (físico, calor y energía), límite de peso y progresión por tiers.

Es un proyecto de fans inspirado en las mecánicas de Super Mechs. No usa nombres, arte ni código del juego original. "MechForge" es un nombre de trabajo.

## Estado

En construcción. El avance por fases está en [docs/PLAN.md](docs/PLAN.md) y el diseño en [docs/GDD.md](docs/GDD.md).

## Requisitos

- Godot 4.7.2 estándar (GDScript).
- Para formato y lint: `pip install gdtoolkit`.

## Pruebas

Los tests usan [GUT](https://github.com/bitwes/Gut), incluido en `addons/gut/`. Para correrlos sin abrir el editor (PowerShell):

```powershell
.\tools\test.ps1
```

El script espera el ejecutable de Godot en la ruta indicada en `tools/godot.ps1`; ajústala si lo tienes en otro lugar.

## Estructura

| Carpeta | Contenido |
|---|---|
| `core/` | Lógica pura y determinista: motor de combate, armado, reglas |
| `data/` | Catálogo de piezas y configuración de balance |
| `scenes/`, `ui/` | Presentación |
| `tests/` | Pruebas GUT |
| `tools/` | Scripts de pruebas, simulador de balance y pipeline de arte |
| `docs/` | Diseño, plan y referencia de las mecánicas del original |
