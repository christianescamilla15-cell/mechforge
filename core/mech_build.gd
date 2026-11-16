class_name MechBuild
extends Resource
## Un mech armado: que pieza va en cada hueco (GDD 4).

const SIDE_SLOTS := 4
const TOP_SLOTS := 2
const MODULE_SLOTS := 8

@export var torso: ItemDef
@export var legs: ItemDef
@export var sides: Array[ItemDef] = []
@export var tops: Array[ItemDef] = []
@export var drone: ItemDef
@export var modules: Array[ItemDef] = []
@export var charge: ItemDef
@export var teleport: ItemDef
@export var hook: ItemDef


func all_items() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for item: ItemDef in [torso, legs, drone, charge, teleport, hook]:
		if item != null:
			out.append(item)
	for list: Array[ItemDef] in [sides, tops, modules]:
		for item in list:
			if item != null:
				out.append(item)
	return out


func total_weight() -> int:
	var total := 0
	for item in all_items():
		total += item.weight
	return total


## Devuelve los motivos por los que el mech no puede pelear; vacio si es valido.
func validate(rules: RulesConfig) -> Array[String]:
	var problems: Array[String] = []
	if torso == null:
		problems.append("falta el torso")
	if legs == null:
		problems.append("faltan las piernas")
	if sides.size() > SIDE_SLOTS:
		problems.append("demasiadas armas laterales")
	if tops.size() > TOP_SLOTS:
		problems.append("demasiadas armas superiores")
	if modules.size() > MODULE_SLOTS:
		problems.append("demasiados modulos")
	if total_weight() > rules.max_weight + rules.overload:
		problems.append("demasiado peso")
	var seen := [false, false, false]
	for module in modules:
		if module == null:
			continue
		var res := [module.res_physical, module.res_heat, module.res_energy]
		for i in 3:
			if res[i] > 0:
				if seen[i]:
					problems.append("resistencia repetida en modulos")
				seen[i] = true
	return problems


## Estadisticas sumadas del mech, con la penalizacion de sobrecarga aplicada.
func summary(rules: RulesConfig) -> Dictionary:
	var s := {
		"weight": 0,
		"health": 0,
		"energy_cap": 0,
		"energy_regen": 0,
		"heat_cap": 0,
		"cooling": 0,
		"res_physical": 0,
		"res_heat": 0,
		"res_energy": 0,
	}
	for item in all_items():
		for key: String in s:
			s[key] += item.get(key)
	var over: int = s["weight"] - rules.max_weight
	if over > 0:
		s["health"] = maxi(1, s["health"] - over * rules.overload_hp_penalty_per_kg)
	return s
