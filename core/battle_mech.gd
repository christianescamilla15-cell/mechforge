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

	func clone() -> Slot:
		var copy := Slot.new(def)
		copy.uses_left = uses_left
		copy.used_this_turn = used_this_turn
		return copy


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
## Arma del asistente que disparo la ultima vez ("drone" o "drone_low"):
## dispara una por turno y las alterna.
var assist_last: String = ""
var shutdown_last_turn: bool = false
## Habilidades de jefe (GDD 9.1): golpes que su escudo todavia puede anular
## y esquivas que le quedan en el turno del rival.
var shield_left: int = 0
var evade_left: int = 0
## Escudo de energia activado (arbol de habilidades): golpes que absorbera,
## sean del turno que sean.
var barrier: int = 0
## Usos que le quedan de las habilidades de combate: "shield", "repair" y
## "dark_matter".
var kits: Dictionary = {}
## Si el arma de pecho ya disparo en este combate (esta desplegada).
var chest_fired: bool = false
## Efectos de un critico que duran el siguiente turno del mech (GDD 2.9): el
## hueco del arma inutilizada y si no puede moverse.
var disabled_slot: String = ""
var immobilized: bool = false
## Sobrecargado por un critico de blaster: pierde una accion en su turno.
var stunned: bool = false
## Bonificaciones en vigor (GDD 2.8): {"kind", "amount", "turns"}.
var buffs: Array[Dictionary] = []
## Huecos que actuan en combate: "legs", "side0", "side1", "top0",
## "chest", "drone", "charge", "teleport", "hook".
var slots: Dictionary[String, Slot] = {}


## Sin argumentos crea un mech vacio; solo lo usa clone().
func _init(p_build: MechBuild = null, rules: RulesConfig = null, p_position: int = 0) -> void:
	if p_build == null:
		return
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
	_add_slot("chest", build.chest)
	_add_slot("drone", build.drone)
	_add_slot("drone_low", build.drone_low)
	_add_slot("charge", build.charge)
	_add_slot("teleport", build.teleport)
	_add_slot("hook", build.hook)
	if build.skills != null and build.skills.point_blank > 0:
		# A quemarropa: sus armas de brazo y su rifle de hombro llegan desde
		# la casilla de al lado.
		for key: String in slots:
			var weapon := key.begins_with("side") or key.begins_with("top")
			if weapon and slots[key].def.range_min > 1:
				slots[key].def = slots[key].def.duplicate()
				slots[key].def.range_min = 1
	if build.skills != null:
		kits = {
			"shield": build.skills.shield_uses,
			"repair": build.skills.repair_uses,
			"dark_matter": build.skills.dark_matter_uses,
		}
		if slots.has("chest") and slots["chest"].uses_left > 0:
			slots["chest"].uses_left += build.skills.chest_uses


func clone() -> BattleMech:
	var copy := BattleMech.new()
	copy.build = build
	copy.position = position
	copy.max_health = max_health
	copy.health = health
	copy.energy = energy
	copy.energy_cap = energy_cap
	copy.energy_regen = energy_regen
	copy.heat = heat
	copy.heat_cap = heat_cap
	copy.cooling = cooling
	copy.res = res.duplicate()
	copy.assist_last = assist_last
	copy.shutdown_last_turn = shutdown_last_turn
	copy.shield_left = shield_left
	copy.evade_left = evade_left
	copy.barrier = barrier
	copy.kits = kits.duplicate()
	copy.chest_fired = chest_fired
	copy.disabled_slot = disabled_slot
	copy.immobilized = immobilized
	copy.stunned = stunned
	copy.buffs = buffs.duplicate(true)
	for key in slots:
		copy.slots[key] = slots[key].clone()
	return copy


## Energia que le cuesta a este mech usar una pieza: depende de su chasis.
func energy_cost(def: ItemDef) -> int:
	if build == null or build.chassis == null:
		return def.energy_cost
	return build.chassis.energy_cost(def)


## Armas del robot de asistencia: disparan solas al acabar el turno.
static func is_assist_slot(key: String) -> bool:
	return key == "drone" or key == "drone_low"


## Bateria del robot de asistencia: lo que la mejora de la armeria suma al
## dano de sus armas (1.0 = sin mejora). Solo al dano: no cambia cuantas
## veces dispara ni lo que le cuesta al mech.
func assist_power() -> float:
	if build == null or build.assist == null or build.upgrades == null:
		return 1.0
	return 1.0 + build.upgrades.assist


## Arma del asistente a la que le toca disparar: alterna con la ultima.
func assist_order() -> Array[String]:
	if assist_last == "drone" and slots.has("drone_low"):
		return ["drone_low", "drone"]
	return ["drone", "drone_low"]


## Dano que un arma le hace a este mech al dispararla.
func backfire_of(def: ItemDef) -> int:
	if build == null or build.upgrades == null:
		return def.backfire
	return build.upgrades.backfire_of(def)


## Acciones de mas que tiene este mech en cada turno (los jefes).
func extra_actions() -> int:
	if build == null or build.chassis == null:
		return 0
	return build.chassis.extra_actions


## Habilidades de jefe: lo que dice su chasis, o nada si no tiene.
func free_energy() -> bool:
	return _chassis() != null and _chassis().free_energy


func regen_share() -> float:
	return _chassis().regen_share if _chassis() != null else 0.0


func shield_hits() -> int:
	return _chassis().shield_hits if _chassis() != null else 0


## Probabilidad de que su escudo de jefe pare un golpe del arma de ese hueco
## (OBS-041): la de su grupo ("side" = brazo, "top" = hombro, "chest" =
## pecho; lo demas, "other"). 1 si su chasis no dice nada: lo para siempre.
func shield_chance(slot: String) -> float:
	var chances: Dictionary = _chassis().shield_chance if _chassis() != null else {}
	if chances.is_empty():
		return 1.0
	var group := "other"
	if slot.begins_with("side"):
		group = "arms"
	elif slot.begins_with("top"):
		group = "shoulder"
	elif slot == "chest":
		group = "chest"
	return float(chances.get(group, chances.get("other", 1.0)))


## Nivel de escudo para los criticos (GDD 2.9): los escudos de energia del
## arbol de habilidades y el escudo de jefe.
func shield_level() -> int:
	var level := shield_hits()
	if build != null and build.skills != null:
		level += build.skills.shield_uses
	return level


## Poder del blindaje del mech (la clase y el nivel de su torso), para los
## criticos: un arma de mas clase encuentra mas puntos debiles.
func armor_power(rules: RulesConfig) -> float:
	if build == null or build.torso == null:
		return 1.0
	return ItemScaling.power(rules, build.torso.tier, build.torso.level)


func evades() -> bool:
	return _chassis() != null and _chassis().evade


func no_overheat() -> bool:
	return _chassis() != null and _chassis().no_overheat


func extra_drone_shots() -> int:
	return _chassis().extra_drone_shots if _chassis() != null else 0


func _chassis() -> ChassisDef:
	return build.chassis if build != null else null


## Potencia de disparo de este mech: su chasis, las mejoras de la tienda y
## las bonificaciones en vigor.
func damage_mult() -> float:
	var base := 1.0
	if build != null and build.chassis != null:
		base = build.chassis.damage_mult
	if build != null and build.upgrades != null:
		base *= build.upgrades.damage_mult()
	if build != null and build.skills != null:
		base *= build.skills.damage_mult()
	return base * (1.0 + buff_amount("firepower"))


## Dano de mas por golpe de los modulos de ataque al arma de ese hueco.
func module_damage(slot: String) -> int:
	return build.module_damage(slot) if build != null else 0


## Dano de mas del arma de pecho por las habilidades.
func chest_damage_mult() -> float:
	if build == null or build.skills == null:
		return 1.0
	return 1.0 + build.skills.chest_damage


func kits_left(kind: String) -> int:
	return int(kits.get(kind, 0))


## Suma de las bonificaciones en vigor de ese tipo (0 si no tiene ninguna).
func buff_amount(kind: String) -> float:
	var total := 0.0
	for buff in buffs:
		if buff["kind"] == kind:
			total += buff["amount"]
	return total


func _add_slot(key: String, def: ItemDef) -> void:
	if def != null:
		slots[key] = Slot.new(def)


func weapon_keys() -> Array[String]:
	var out: Array[String] = []
	for key in slots:
		if key.begins_with("side") or key.begins_with("top") or key == "chest":
			out.append(key)
	return out


func move_range() -> int:
	return maxi(build.legs.walk, build.legs.jump)


func can_jump() -> bool:
	return build.legs.jump > 0
