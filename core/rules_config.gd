class_name RulesConfig
extends Resource
## Todos los numeros de reglas y los interruptores de mejoras (GDD 2 y 4).
## M3 (previsualizacion) vive en BattleEngine.preview y M4 (dron siempre
## activo) no necesita interruptor: no existe la accion de alternarlo.

@export var arena_size: int = 10
@export var start_positions: Array[Vector2i] = [Vector2i(4, 5), Vector2i(3, 6), Vector2i(2, 8)]
@export var actions_per_turn: int = 2

@export var max_weight: int = 1000
@export var overload: int = 10
@export var overload_hp_penalty_per_kg: int = 15

## M1: variacion maxima de dano (max - min) como fraccion de la media.
@export var m1_max_damage_spread: float = 0.30
## M2: sin apagados seguidos.
@export var m2_no_chain_shutdown: bool = true
## M5: quien empieza tiene 1 sola accion en su primer turno.
@export var m5_first_turn_single_action: bool = true
## M6: la energia se regenera al inicio del turno propio y no al final, para
## que un drenaje no deje al rival en cero justo antes de jugar.
@export var m6_regen_at_turn_start: bool = true

@export_group("Progresion")
## Multiplicador de estadisticas por tier, de Comun a Divino (GDD 8).
@export var tier_mult: Array[float] = [1.0, 1.35, 1.8, 2.4, 3.2, 4.2]
## Nivel maximo dentro de cada tier.
@export var tier_max_level: Array[int] = [6, 12, 18, 24, 30, 50]
## Bonus al llegar al nivel maximo del tier (0.3 = +30 %).
@export var level_bonus: float = 0.3
