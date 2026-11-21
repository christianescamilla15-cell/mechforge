class_name CatalogValidator
extends RefCounted
## Revisa que el catalogo cumpla las reglas de diseno (GDD 5 y 6, mejora M1).
## Los limites numericos llegan en `spec` (data/validation.json), no viven aqui.

const BODY_STATS: Array[String] = [
	"health",
	"energy_cap",
	"energy_regen",
	"heat_cap",
	"cooling",
	"res_physical",
	"res_heat",
	"res_energy",
]
const ATTACK_STATS: Array[String] = [
	"dmg_min",
	"dmg_max",
	"heat_dmg",
	"energy_dmg",
	"res_dmg",
	"heat_cap_dmg",
	"cooling_dmg",
	"energy_cap_dmg",
	"energy_regen_dmg",
	"range_min",
	"range_max",
	"push",
	"pull",
	"recoil",
	"advance",
	"retreat",
	"uses",
	"backfire",
	"heat_cost",
	"energy_cost",
]
const HEAT_ONLY: Array[String] = ["heat_dmg", "heat_cap_dmg", "cooling_dmg"]
const ENERGY_ONLY: Array[String] = ["energy_dmg", "energy_cap_dmg", "energy_regen_dmg"]
const WEAPON_TYPES: Array[ItemDef.Type] = [
	ItemDef.Type.SIDE, ItemDef.Type.TOP, ItemDef.Type.DRONE, ItemDef.Type.CHEST
]
const SPECIAL_TYPES: Array[ItemDef.Type] = [
	ItemDef.Type.CHARGE, ItemDef.Type.TELEPORT, ItemDef.Type.HOOK
]


## Quita mayusculas, espacios y signos para comparar nombres.
static func normalize_name(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
	return out


## Devuelve la lista de problemas; vacia si el catalogo es valido.
static func validate(
	catalog: Catalog, rules: RulesConfig, spec: Dictionary, forbidden_names: Array = []
) -> Array[String]:
	var problems: Array[String] = []
	problems.append_array(catalog.errors)
	var forbidden := {}
	for name: String in forbidden_names:
		forbidden[normalize_name(name)] = true
	var seen_names := {}
	for def: ItemDef in catalog.items.values():
		var before := problems.size()
		_check_identity(def, forbidden, seen_names, problems)
		_check_weight(def, spec, problems)
		_check_damage(def, rules, problems)
		_check_range(def, rules, problems)
		_check_type(def, problems)
		_check_module_fields(def, problems)
		_check_element(def, problems)
		for i in range(before, problems.size()):
			problems[i] = "%s: %s" % [def.id, problems[i]]
	_check_composition(catalog, spec, problems)
	return problems


static func _check_identity(
	def: ItemDef, forbidden: Dictionary, seen: Dictionary, problems: Array[String]
) -> void:
	var norm := normalize_name(def.display_name)
	if norm == "":
		problems.append("no tiene nombre")
	elif forbidden.has(norm):
		problems.append("el nombre '%s' es del juego original" % def.display_name)
	elif seen.has(norm):
		problems.append("nombre repetido con %s" % seen[norm])
	else:
		seen[norm] = def.id
	if def.tier_min > def.tier_max:
		problems.append("tier_min es mayor que tier_max")
	for tag in def.tags:
		if not tag in ItemDef.KNOWN_TAGS:
			problems.append("etiqueta desconocida '%s'" % tag)
	if def.has_tag(ItemDef.TAG_SWORD) and not def.has_tag(ItemDef.TAG_MELEE):
		problems.append("una espada debe llevar tambien la etiqueta melee")


static func _check_weight(def: ItemDef, spec: Dictionary, problems: Array[String]) -> void:
	var limits: Array = spec.get("weight", {}).get(_type_name(def), [])
	if limits.size() != 2:
		problems.append("no hay rango de peso definido para su tipo")
	elif def.weight < limits[0] or def.weight > limits[1]:
		problems.append("peso %d fuera de %d-%d" % [def.weight, limits[0], limits[1]])


static func _check_damage(def: ItemDef, rules: RulesConfig, problems: Array[String]) -> void:
	if def.dmg_min > def.dmg_max:
		problems.append("dmg_min es mayor que dmg_max")
		return
	if def.dmg_max == 0:
		return
	if def.dmg_min < 1:
		problems.append("si hace dano, dmg_min debe ser al menos 1")
	var mean := (def.dmg_min + def.dmg_max) / 2.0
	var spread := (def.dmg_max - def.dmg_min) / mean
	if spread > rules.m1_max_damage_spread + 0.0001:
		problems.append(
			(
				"variacion de dano %.0f %% supera el %.0f %% (M1)"
				% [spread * 100.0, rules.m1_max_damage_spread * 100.0]
			)
		)


static func _check_range(def: ItemDef, rules: RulesConfig, problems: Array[String]) -> void:
	if def.range_min == 0 and def.range_max == 0:
		return
	var farthest := rules.arena_size - 1
	if def.range_min < 1 or def.range_max > farthest or def.range_min > def.range_max:
		problems.append(
			(
				"alcance [%d,%d] no valido (debe estar en 1-%d)"
				% [def.range_min, def.range_max, farthest]
			)
		)


static func _check_type(def: ItemDef, problems: Array[String]) -> void:
	match def.type:
		ItemDef.Type.TORSO:
			for key: String in ["health", "energy_cap", "energy_regen", "heat_cap", "cooling"]:
				if def.get(key) <= 0:
					problems.append("a un torso le falta '%s'" % key)
			_forbid(def, ATTACK_STATS + ["walk", "jump"], problems)
		ItemDef.Type.LEGS:
			if def.health <= 0:
				problems.append("a unas piernas les falta 'health'")
			if def.walk <= 0 and def.jump <= 0:
				problems.append("unas piernas deben poder andar o saltar")
			if def.deals_damage():
				if def.range_min != 1 or def.range_max != 1:
					problems.append("el pisoton debe tener alcance [1,1]")
				if not def.has_tag(ItemDef.TAG_MELEE):
					problems.append("el pisoton debe llevar la etiqueta melee")
			_forbid(def, ["energy_cap", "energy_regen", "heat_cap", "cooling"], problems)
		ItemDef.Type.SIDE, ItemDef.Type.TOP, ItemDef.Type.CHEST:
			if not def.deals_damage() and def.heat_dmg == 0 and def.energy_dmg == 0:
				problems.append("un arma debe hacer dano, calor o drenar energia")
			_forbid(def, BODY_STATS + ["walk", "jump"], problems)
		ItemDef.Type.DRONE:
			if not def.deals_damage():
				problems.append("un dron debe hacer dano")
			_forbid(def, BODY_STATS + ["walk", "jump", "recoil", "advance", "retreat"], problems)
		ItemDef.Type.ASSIST:
			var bonus := false
			for key in BODY_STATS:
				bonus = bonus or def.get(key) > 0
			if not bonus:
				problems.append("un robot de asistencia debe dar alguna bonificacion")
			_forbid(def, ATTACK_STATS + ["walk", "jump"], problems)
		ItemDef.Type.MODULE:
			# Los de ataque dan dano de mas a unas armas (OBS-040).
			var gives_something := def.dmg_bonus > 0
			for key in BODY_STATS:
				gives_something = gives_something or def.get(key) > 0
			if not gives_something:
				problems.append("un modulo debe dar alguna estadistica de cuerpo o dano de mas")
			if def.family == "":
				problems.append("un modulo debe tener familia")
			if (def.dmg_bonus > 0) != (def.boost != ""):
				problems.append("el dano de mas de un modulo debe decir a que armas va")
			_forbid(def, ATTACK_STATS + ["walk", "jump"], problems)
		_:
			if def.uses < 1:
				problems.append("un especial debe tener usos limitados")
			_forbid(def, BODY_STATS + ["walk", "jump", "range_min", "range_max"], problems)


## Familia, armas y dano de mas: solo los modulos.
static func _check_module_fields(def: ItemDef, problems: Array[String]) -> void:
	if def.type == ItemDef.Type.MODULE:
		return
	if def.family != "" or def.boost != "" or def.dmg_bonus > 0:
		problems.append("familia, armas y dano de mas son solo de los modulos")


static func _check_element(def: ItemDef, problems: Array[String]) -> void:
	if def.element == ItemDef.Element.COMBINED:
		if def.type != ItemDef.Type.MODULE:
			problems.append("solo los modulos pueden ser de elemento combinado")
		return
	if def.type == ItemDef.Type.MODULE or def.type == ItemDef.Type.TORSO:
		return
	match def.element:
		ItemDef.Element.PHYSICAL:
			_forbid(def, HEAT_ONLY + ENERGY_ONLY, problems)
		ItemDef.Element.HEAT:
			_forbid(def, ENERGY_ONLY, problems)
			if def.type in WEAPON_TYPES and def.heat_dmg == 0:
				problems.append("un arma de calor debe tener heat_dmg")
		ItemDef.Element.ENERGY:
			_forbid(def, HEAT_ONLY, problems)
			if def.type in WEAPON_TYPES and def.energy_dmg == 0:
				problems.append("un arma de energia debe tener energy_dmg")


static func _check_composition(catalog: Catalog, spec: Dictionary, problems: Array[String]) -> void:
	var elements := [ItemDef.Element.PHYSICAL, ItemDef.Element.HEAT, ItemDef.Element.ENERGY]
	var per_element: Dictionary = spec.get("min_per_element", {})
	for type_name: String in per_element:
		for element: ItemDef.Element in elements:
			var count := 0
			for def: ItemDef in catalog.items.values():
				if _type_name(def) == type_name and def.element == element:
					count += 1
			if count < per_element[type_name]:
				problems.append(
					(
						"composicion: hay %d %s de %s y se piden %d"
						% [
							count,
							type_name,
							ItemDef.Element.find_key(element),
							per_element[type_name]
						]
					)
				)
	var totals: Dictionary = spec.get("min_total", {})
	for type_name: String in totals:
		var count := 0
		for def: ItemDef in catalog.items.values():
			if _type_name(def) == type_name:
				count += 1
		if count < totals[type_name]:
			problems.append(
				"composicion: hay %d %s y se piden %d" % [count, type_name, totals[type_name]]
			)
	if spec.get("legs_need_both_kinds", false):
		for element: ItemDef.Element in elements:
			var jumpers := 0
			var rollers := 0
			for def in catalog.by_type(ItemDef.Type.LEGS):
				if def.element == element:
					if def.jump > 0:
						jumpers += 1
					else:
						rollers += 1
			if jumpers == 0 or rollers == 0:
				problems.append(
					(
						"composicion: las piernas de %s necesitan una que salte y una de ruedas"
						% ItemDef.Element.find_key(element)
					)
				)


static func _forbid(def: ItemDef, keys: Array, problems: Array[String]) -> void:
	for key: String in keys:
		if def.get(key) > 0:
			problems.append("no deberia tener '%s'" % key)


static func _type_name(def: ItemDef) -> String:
	return ItemDef.Type.find_key(def.type)
