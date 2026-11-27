class_name StateConfig
extends ArenaRule
## Estados (OBS-055, del usuario: mecanicas "donde tambien cuente la
## estrategia"; eligio quemadura, corrosion y aturdimiento con duracion).
## Cada golpe con dano de un arma deja en el rival el estado de su elemento,
## con cargas que se suman y que duran unos turnos suyos:
## - quemadura (termica): al empezar su turno se calienta por cada carga;
##   enfriar la apaga;
## - corrosion (cinetica): recibe mas dano por cada carga;
## - estatica (ionica): al llenarse se descarga y pierde una accion en su
##   turno siguiente (con M7, no dos turnos seguidos).
## Asi importa el orden: corroer antes del golpe fuerte, cargar la estatica
## para quitarle una accion cuando mas duele, quemar a quien esta en lava.
## Los numeros, en data/states.json; las cargas, en cada BattleMech.states.

const KINDS: Array[String] = ["burn", "corrosion", "static"]

## Por estado: {"element" (ItemDef.Element), "turns", "max", "heat" o "damage"}.
var kinds: Dictionary = {}
var modes: Array[String] = []
var errors: Array[String] = []


static func load_file(path: String) -> StateConfig:
	var config := StateConfig.new()
	if not FileAccess.file_exists(path):
		config.errors.append("no existe %s" % path)
		return config
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		config.errors.append("%s no es un objeto JSON" % path)
		return config
	return from_dict(data)


static func from_dict(data: Dictionary) -> StateConfig:
	var config := StateConfig.new()
	for kind in KINDS:
		var raw: Variant = data.get(kind)
		if not raw is Dictionary:
			continue
		var entry := (raw as Dictionary).duplicate()
		var element := str(entry.get("element", ""))
		if not ItemDef.Element.has(element):
			config.errors.append("%s: elemento desconocido %s" % [kind, element])
			continue
		entry["element"] = ItemDef.Element[element]
		config.kinds[kind] = entry
	for mode: Variant in data.get("modes", []):
		config.modes.append(str(mode))
	return config


func enabled_for(mode: String) -> bool:
	return not kinds.is_empty() and mode in modes


func value(kind: String, key: String) -> float:
	return float((kinds.get(kind, {}) as Dictionary).get(key, 0.0))


## El estado que deja un arma de ese elemento ("" ninguno).
func kind_for(element: ItemDef.Element) -> String:
	for kind: String in kinds:
		if int(kinds[kind]["element"]) == element:
			return kind
	return ""


## Las cargas que lleva un mech de ese estado.
static func stacks(mech: BattleMech, kind: String) -> int:
	return int((mech.states.get(kind, {}) as Dictionary).get("stacks", 0))


# --- Como ArenaRule ------------------------------------------------------------


## Un golpe de arma deja su estado: una carga mas y vuelve a durar. La
## estatica llena se descarga y le quita una accion.
func on_hit(
	_engine: BattleEngine,
	user: BattleMech,
	target: BattleMech,
	key: String,
	_damage: int,
	data: Dictionary
) -> void:
	var weapon := key.begins_with("side") or key.begins_with("top") or key == "chest"
	if not weapon or target.health <= 0:
		return
	var kind := kind_for(user.slots[key].def.element)
	if kind == "":
		return
	var top := maxi(1, roundi(value(kind, "max")))
	var count := mini(stacks(target, kind) + 1, top)
	target.states[kind] = {"stacks": count, "turns": roundi(value(kind, "turns"))}
	# "applied" y no "state": esa clave es la foto del estado en el registro.
	data["applied"] = kind
	data["stacks"] = count
	if kind == "static" and count >= top:
		target.states.erase(kind)
		data["discharge"] = true
		if target.stun_guard:
			data["stun_resisted"] = true
		else:
			target.stunned = true


## Al empezar su turno: la quemadura le calienta, y cada estado dura un
## turno menos.
func on_turn_start(engine: BattleEngine, me: BattleMech) -> void:
	var burn := stacks(me, "burn")
	if burn > 0:
		var heat := roundi(me.heat_cap * value("burn", "heat") * burn)
		me.heat += heat
		engine.note("burn", {"who": engine.mechs.find(me), "heat": heat, "stacks": burn})
	for kind: String in me.states.keys():
		me.states[kind]["turns"] -= 1
		if int(me.states[kind]["turns"]) <= 0:
			me.states.erase(kind)


## La corrosion de quien recibe el golpe: mas dano por carga.
func damage_factor(
	_engine: BattleEngine, _user: BattleMech, target: BattleMech, _def: ItemDef
) -> float:
	return 1.0 + value("corrosion", "damage") * stacks(target, "corrosion")


## Enfriar apaga la quemadura.
func on_cool(engine: BattleEngine, me: BattleMech) -> void:
	if me.states.has("burn"):
		me.states.erase("burn")
		engine.note("burn_out", {"who": engine.mechs.find(me)})
