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
## M5: quien empieza tiene 1 sola accion en su primer turno. Apagada desde el
## 2026-11-21 (OBS-034, del usuario: "si yo empiezo atacando, solamente tengo
## el uso de un arma y el de mi asistente... hay una desventaja"): los dos
## abren con todas sus acciones. Quien empieza se elige al azar.
@export var m5_first_turn_single_action: bool = false
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

@export_group("Chasis")
## Parte de la bonificacion de un chasis que ya se tiene en el nivel 0: al
## principio las diferencias entre chasis son pequenas (docs/CHASIS.md).
@export var chassis_start_share: float = 0.2
## Nivel maximo de un chasis; ahi su bonificacion es completa.
@export var chassis_max_level: int = 30

@export_group("Garaje")
## Robots que puede tener el jugador: el que usa y los del garaje (pedido del
## usuario el 2026-11-18: "en total puedes tener 4").
@export var max_mechs: int = 4

@export_group("Robot de asistencia")
## Clase del robot de asistencia desde la que pelea su segunda arma (la
## inferior): la primera transformacion, Intermedia (GDD 4).
@export var assist_second_weapon_tier: int = 1

@export_group("Criticos")
## Golpes criticos (GDD 2.9). Apagados por defecto, como las bonificaciones,
## para no alterar las pruebas ni el simulador; el juego los enciende.
@export var crits_enabled: bool = false
## Cuanto multiplica un critico el dano, el calor y el drenaje del arma.
## Medido el 2026-11-18: con 1.5 el balance entre elementos se salia.
@export var crit_damage_mult: float = 1.25
## Probabilidad maxima de un critico.
@export var crit_cap: float = 0.9
## Nivel: la probabilidad se multiplica por el poder del arma (clase y
## nivel) entre el del blindaje del rival (su torso), dentro de estos topes.
@export var crit_level_min: float = 0.5
@export var crit_level_max: float = 1.5
## Armadura gruesa: la probabilidad se multiplica por
## 1 - esto x (resistencia del rival / dano medio del arma).
@export var crit_armor_weight: float = 2.0
## Escudo: cada nivel de escudo del rival (los escudos de energia del arbol
## y el escudo de jefe) quita esta parte de la probabilidad.
@export var crit_shield_cut: float = 0.25

@export_group("Impacto")
## Impacto de los golpes (GDD 2.10): el golpe empuja al rival segun el tamano
## del arma. Apagado por defecto, como los criticos; el juego lo enciende.
@export var impact_enabled: bool = false
## Casillas que empuja un arma de hombro (impacto ligero a medio). Las de
## brazo solo hacen chispas.
@export var impact_push_top: int = 1
## Casillas que empuja como mucho un arma de pecho (impacto grave): menos si
## el blindaje del rival es de mas clase que el arma.
@export var impact_push_chest: int = 3

@export_group("Bonificaciones")
## Bonificaciones que deja caer una nave en la arena (GDD 2.8). Apagadas por
## defecto para no alterar los combates de prueba; el juego las enciende.
@export var drops_enabled: bool = false
## Turno en que cae la primera, y cada cuantos turnos cae otra si no queda ninguna.
@export var drop_first_turn: int = 3
@export var drop_every: int = 5
## Turnos propios que dura la ventaja de quien la toma.
@export var drop_duration: int = 3
## Cuanto da: al azar entre una ventaja ligera y una extrema.
@export var drop_min: float = 0.1
@export var drop_max: float = 0.5
## Tipos posibles: "armor" reduce el dano recibido; "firepower" sube el causado.
@export var drop_kinds: Array[String] = ["armor", "firepower"]
