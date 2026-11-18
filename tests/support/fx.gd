class_name Fx
extends RefCounted
## Fabricas de piezas, mechs y combates para los tests.


static func item(type: ItemDef.Type, props: Dictionary = {}) -> ItemDef:
	var def := ItemDef.new()
	def.type = type
	def.id = "test_%d" % type
	for key: String in props:
		assert(key in def, "ItemDef no tiene la propiedad %s" % key)
		def.set(key, props[key])
	return def


static func torso(props: Dictionary = {}) -> ItemDef:
	var base := {
		"weight": 300,
		"health": 1000,
		"energy_cap": 200,
		"energy_regen": 50,
		"heat_cap": 200,
		"cooling": 50,
	}
	base.merge(props, true)
	return item(ItemDef.Type.TORSO, base)


static func legs(props: Dictionary = {}) -> ItemDef:
	var base := {
		"weight": 100,
		"walk": 1,
		"jump": 2,
		"dmg_min": 50,
		"dmg_max": 50,
		"range_min": 1,
		"range_max": 1,
		"tags": PackedStringArray([ItemDef.TAG_MELEE]),
	}
	base.merge(props, true)
	return item(ItemDef.Type.LEGS, base)


## Arma lateral de dano fijo 100 y sin limite de alcance.
static func gun(props: Dictionary = {}) -> ItemDef:
	var base := {"weight": 40, "dmg_min": 100, "dmg_max": 100}
	base.merge(props, true)
	return item(ItemDef.Type.SIDE, base)


## opts: torso, legs, tops, drone, modules, charge, teleport, hook.
static func build(sides: Array = [], opts: Dictionary = {}) -> MechBuild:
	var b := MechBuild.new()
	b.torso = opts.get("torso", torso())
	b.legs = opts.get("legs", legs())
	b.sides.assign(sides)
	b.tops.assign(opts.get("tops", []))
	b.modules.assign(opts.get("modules", []))
	b.assist = opts.get("assist")
	b.drone = opts.get("drone")
	b.drone_low = opts.get("drone_low")
	b.charge = opts.get("charge")
	b.teleport = opts.get("teleport")
	b.hook = opts.get("hook")
	return b


## Reglas con M5 apagado por defecto para que los tests tengan 2 acciones.
static func rules(props: Dictionary = {}) -> RulesConfig:
	var r := RulesConfig.new()
	r.m5_first_turn_single_action = false
	for key: String in props:
		assert(key in r, "RulesConfig no tiene la propiedad %s" % key)
		r.set(key, props[key])
	return r


## pair: 0 = casillas (4,5), 1 = (3,6), 2 = (2,8). Empieza el mech 0.
static func engine(
	a: MechBuild, b: MechBuild, pair: int = 0, p_rules: RulesConfig = null, seed_value: int = 1
) -> BattleEngine:
	return BattleEngine.new(p_rules if p_rules else rules(), a, b, seed_value, 0, pair)


## Gasta las acciones del turno actual enfriando, hasta que pase el turno.
static func pass_turn(e: BattleEngine) -> void:
	var n := e.turn_number
	while e.turn_number == n and not e.is_over():
		e.apply(BattleAction.cool())


static func has_event(e: BattleEngine, event: String) -> bool:
	return e.events.any(func(entry: Dictionary) -> bool: return entry["event"] == event)
