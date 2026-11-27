class_name ArenaRule
extends RefCounted
## Una regla de combate que va aparte del motor (OBS-055): el terreno
## (TerrainConfig) y los estados (StateConfig). BattleEngine llama a cada una
## en estos momentos; por defecto no hacen nada. Lo que cambia en un combate
## vive en el motor o en los mechs, no aqui: la misma regla sirve para las
## copias de busqueda de la IA.


## Al empezar el turno de `me`, antes de mirar si se pasa de calor.
func on_turn_start(_engine: BattleEngine, _me: BattleMech) -> void:
	pass


## Lo que multiplica el dano de un golpe de `def` (1 = nada).
func damage_factor(
	_engine: BattleEngine, _user: BattleMech, _target: BattleMech, _def: ItemDef
) -> float:
	return 1.0


## Tras un golpe del hueco `key` que hizo dano; `data` va al registro.
func on_hit(
	_engine: BattleEngine,
	_user: BattleMech,
	_target: BattleMech,
	_key: String,
	_damage: int,
	_data: Dictionary
) -> void:
	pass


## Tras cada accion y al acabar cada turno.
func after_action(_engine: BattleEngine) -> void:
	pass


## Cuando `me` enfria.
func on_cool(_engine: BattleEngine, _me: BattleMech) -> void:
	pass
