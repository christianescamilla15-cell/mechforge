class_name BattleMech
extends RefCounted
## Estado de un mech durante un combate.


class Slot:
	extends RefCounted
	var def: ItemDef
	var uses_left: int = -1  # -1 = ilimitado
	var used_this_turn: bool = false

	func _init(p_def: ItemDef) -> void:
		def = p_def
		uses_left = p_def.uses if p_def.uses > 0 else -1


var build: MechBuild
var position: int = 0
var max_health: int = 0
var health: int = 0
var energy: int = 0
var energy_cap: int = 0
var energy_regen: int = 0
var heat: int = 0
var heat_cap: int = 0
var cooling: int = 0
## Resistencias indexadas por ItemDef.Element (fisico, calor, energia).
var res: Array[int] = [0, 0, 0]
var shutdown_last_turn: bool = false
## Huecos que actuan en combate: "legs", "side0".."side3", "top0", "top1",
## "drone", "charge", "teleport", "hook".
var slots: Dictionary[String, Slot] = {}


func _init(p_build: MechBuild, rules: RulesConfig, p_position: int) -> void:
	build = p_build
	position = p_position
	var s := build.summary(rules)
	max_health = s["health"]
	health = max_health
	energy_cap = s["energy_cap"]
	energy = energy_cap
	energy_regen = s["energy_regen"]
	heat_cap = s["heat_cap"]
	cooling = s["cooling"]
	res = [s["res_physical"], s["res_heat"], s["res_energy"]]
	_add_slot("legs", build.legs)
	for i in build.sides.size():
		_add_slot("side%d" % i, build.sides[i])
	for i in build.tops.size():
		_add_slot("top%d" % i, build.tops[i])
	_add_slot("drone", build.drone)
	_add_slot("charge", build.charge)
	_add_slot("teleport", build.teleport)
	_add_slot("hook", build.hook)


func _add_slot(key: String, def: ItemDef) -> void:
	if def != null:
		slots[key] = Slot.new(def)


func weapon_keys() -> Array[String]:
	var out: Array[String] = []
	for key in slots:
		if key.begins_with("side") or key.begins_with("top"):
			out.append(key)
	return out


func move_range() -> int:
	return maxi(build.legs.walk, build.legs.jump)


func can_jump() -> bool:
	return build.legs.jump > 0
