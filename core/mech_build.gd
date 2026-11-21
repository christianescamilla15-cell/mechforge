class_name MechBuild
extends Resource
## Un mech armado: que pieza va en cada hueco (GDD 4).

const SIDE_SLOTS := 4
const TOP_SLOTS := 2
const MODULE_SLOTS := 8
## Dos modulos que dan la misma resistencia: se nombran los dos.
const RESISTANCE_CLASH := "dos módulos dan la misma resistencia (%s y %s): solo va uno de cada tipo"

## Chasis sobre el que va montado (docs/CHASIS.md); null = sin bonificaciones.
@export var chassis: ChassisDef
## Mejoras de la tienda de arena del jugador (GDD 8); null = ninguna.
@export var upgrades: ArenaUpgrades
## Habilidades del arbol del jugador (SkillTree); null = ninguna.
@export var skills: SkillSet
@export var torso: ItemDef
@export var legs: ItemDef
@export var sides: Array[ItemDef] = []
@export var tops: Array[ItemDef] = []
## Robot de asistencia (GDD 4): su cuerpo, con la bateria y el protocolo,
## y sus dos armas, la superior (`drone`) y la inferior (`drone_low`).
@export var assist: ItemDef
@export var drone: ItemDef
@export var drone_low: ItemDef
## Arma de pecho: un canon o una nova, aparte de las seis armas.
@export var chest: ItemDef
@export var modules: Array[ItemDef] = []
@export var charge: ItemDef
@export var teleport: ItemDef
@export var hook: ItemDef
## Pintura de sus piezas (decision del usuario, 2026-11-20, OBS-010: "elegir
## un color, ya sea blanco, rojo, azul, de acuerdo al color del robot"): hueco
## -> elemento (ItemDef.Element) con cuyo color se dibuja su pieza. Lo que no
## esta aqui se dibuja con el color de su elemento. Solo cambia el dibujo.
@export var paints: Dictionary = {}


## La pieza de un hueco ("torso", "side0", "top1", "module3", "chest"...), o
## null si esta vacio o no existe.
func item_at(slot: String) -> ItemDef:
	for prefix: String in ["side", "top", "module"]:
		if slot.begins_with(prefix):
			var list: Array[ItemDef] = get(prefix + "s")
			var index := int(slot.trim_prefix(prefix))
			return list[index] if index >= 0 and index < list.size() else null
	if (
		slot
		in ["torso", "legs", "assist", "drone", "drone_low", "chest", "charge", "teleport", "hook"]
	):
		return get(slot)
	return null


## Color (elemento) con el que se dibuja la pieza de un hueco: el que se le
## pinto o, si no, el de su elemento. El robot de asistencia, sin pintar, va
## del color del torso para hacer juego con su mech.
func paint_of(slot: String) -> int:
	if paints.has(slot):
		return int(paints[slot])
	if slot == "assist":
		return paint_of("torso")
	var item := item_at(slot)
	return item.element if item != null else ItemDef.Element.PHYSICAL


func all_items() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for item: ItemDef in [torso, legs, assist, drone, drone_low, chest, charge, teleport, hook]:
		if item != null:
			out.append(item)
	for list: Array[ItemDef] in [sides, tops, modules]:
		for item in list:
			if item != null:
				out.append(item)
	return out


## Peso que cuenta para el limite. El arma de pecho pesa (decision del
## usuario, 2026-11-20, OBS-027): quien la quiere llevar sin quitar nada
## amplia el nucleo (max_weight).
## El cuerpo del robot de asistencia y su arma inferior no cuentan: es un
## hueco nuevo, y si contara habria que quitar piezas para montarla. El arma
## superior pesa como siempre peso el dron.
func total_weight() -> int:
	var total := 0
	for item in all_items():
		if not _weightless(item):
			total += item.weight
	return total


func _weightless(item: ItemDef) -> bool:
	return item == assist or item == drone_low


## Peso que puede llevar: el limite de las reglas mas lo que el nucleo
## ampliado (mejora de la armeria, desde el nivel 10 del jugador) carga del
## arma de pecho. Nunca mas de lo que pesa el arma: el nucleo se amplia para
## ella, no para llevar mas de lo demas. Medido el 2026-11-17: sin esto,
## montarla obligaba a quitar modulos y el mech salia peor que sin ella.
func max_weight(rules: RulesConfig) -> int:
	if chest == null or upgrades == null:
		return rules.max_weight
	return rules.max_weight + mini(roundi(upgrades.core), chest.weight)


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
	if total_weight() > max_weight(rules) + rules.overload:
		problems.append("demasiado peso")
	# Como maximo un modulo por tipo de resistencia: se dice cuales chocan,
	# una vez por pareja.
	var first: Array[ItemDef] = [null, null, null]
	var clashes: Array[String] = []
	for module in modules:
		if module == null:
			continue
		var res := [module.res_physical, module.res_heat, module.res_energy]
		for i in 3:
			if res[i] <= 0:
				continue
			if first[i] == null:
				first[i] = module
				continue
			var clash := RESISTANCE_CLASH % [first[i].display_name, module.display_name]
			if not clash in clashes:
				clashes.append(clash)
	problems.append_array(clashes)
	return problems


## Estadisticas sumadas del mech, con el chasis y la penalizacion de
## sobrecarga aplicados.
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
	s["weight"] = total_weight()
	if chassis != null:
		chassis.apply(s)
	if upgrades != null:
		upgrades.apply(s)
	if skills != null:
		skills.apply(s)
	var over: int = s["weight"] - max_weight(rules)
	if over > 0:
		s["health"] = maxi(1, s["health"] - over * rules.overload_hp_penalty_per_kg)
	return s
