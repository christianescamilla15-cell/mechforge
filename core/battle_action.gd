class_name BattleAction
extends RefCounted
## Una accion de combate. Es serializable para poder repetir combates.

## SHIELD, REPAIR y DARK_MATTER son habilidades del arbol (SkillTree).
enum Type { WALK, STOMP, WEAPON, COOL, CHARGE, TELEPORT, HOOK, SHIELD, REPAIR, DARK_MATTER }

var type: Type
## Hueco del arma para WEAPON ("side0", "top1"...).
var slot: String = ""
## Casilla destino para WALK y TELEPORT.
var position: int = -1


func _init(p_type: Type, p_slot: String = "", p_position: int = -1) -> void:
	type = p_type
	slot = p_slot
	position = p_position


static func walk(to: int) -> BattleAction:
	return BattleAction.new(Type.WALK, "", to)


static func stomp() -> BattleAction:
	return BattleAction.new(Type.STOMP)


static func weapon(slot_key: String) -> BattleAction:
	return BattleAction.new(Type.WEAPON, slot_key)


static func cool() -> BattleAction:
	return BattleAction.new(Type.COOL)


static func charge() -> BattleAction:
	return BattleAction.new(Type.CHARGE)


static func teleport(to: int) -> BattleAction:
	return BattleAction.new(Type.TELEPORT, "", to)


static func hook() -> BattleAction:
	return BattleAction.new(Type.HOOK)


## Escudo de energia: absorbe el siguiente golpe.
static func shield() -> BattleAction:
	return BattleAction.new(Type.SHIELD)


## Kit de reparacion: recupera parte de la vida.
static func repair() -> BattleAction:
	return BattleAction.new(Type.REPAIR)


## Materia oscura: el disparo del arma de pecho que casi aniquila.
static func dark_matter() -> BattleAction:
	return BattleAction.new(Type.DARK_MATTER, "chest")


func to_dict() -> Dictionary:
	return {"type": type, "slot": slot, "position": position}
