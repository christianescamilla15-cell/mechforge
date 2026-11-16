class_name BattleEngine
extends RefCounted
## Motor de combate determinista (GDD 2). Sin nodos ni UI: recibe acciones,
## muta el estado y deja un registro de eventos. Todo el azar sale de un RNG
## con semilla, asi que semilla + acciones reproducen el combate exacto.

var rules: RulesConfig
var mechs: Array[BattleMech] = []
## Indice (0 o 1) del mech que tiene el turno.
var turn: int = 0
var actions_left: int = 0
var turn_number: int = 0
## -1 mientras el combate sigue; si no, el indice del ganador.
var winner: int = -1
var events: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _first_turn := true


func _init(
	p_rules: RulesConfig,
	build_a: MechBuild,
	build_b: MechBuild,
	seed_value: int,
	starter: int = 0,
	start_pair: int = -1
) -> void:
	rules = p_rules
	_rng.seed = seed_value
	var pair_index := start_pair
	if pair_index < 0:
		pair_index = _rng.randi_range(0, rules.start_positions.size() - 1)
	var pair := rules.start_positions[pair_index]
	mechs = [BattleMech.new(build_a, rules, pair.x), BattleMech.new(build_b, rules, pair.y)]
	turn = starter
	_begin_turn()


func attacker() -> BattleMech:
	return mechs[turn]


func defender() -> BattleMech:
	return mechs[1 - turn]


func is_over() -> bool:
	return winner >= 0


# --- Consultas ---------------------------------------------------------------


## Devuelve "" si el mech puede usar ese hueco ahora; si no, el motivo (GDD 2.6).
func why_cant_use(user: BattleMech, target: BattleMech, key: String) -> String:
	if not user.slots.has(key):
		return "no tiene esa pieza"
	var slot := user.slots[key]
	var def := slot.def
	if def.energy_cost > user.energy:
		return "falta energia"
	if def.backfire > 0 and def.backfire >= user.health:
		return "falta vida"
	if slot.uses_left == 0:
		return "sin usos"
	if slot.used_this_turn:
		return "ya se uso este turno"
	if def.range_max > 0:
		var distance := absi(user.position - target.position)
		if distance < def.range_min or distance > def.range_max:
			return "fuera de alcance"
	if (def.advance > 0 or def.retreat > 0) and not def.has_tag(ItemDef.TAG_MELEE):
		if not user.can_jump():
			return "requiere salto"
	if def.retreat > 0:
		var future := user.position - def.retreat * _dir(user, target)
		if future < 0 or future >= rules.arena_size:
			return "la retirada sale de la arena"
	return ""


func walkable_positions() -> Array[int]:
	var me := attacker()
	var foe := defender()
	var reach := me.move_range()
	var out: Array[int] = []
	for pos in rules.arena_size:
		if pos == me.position or pos == foe.position:
			continue
		if absi(pos - me.position) > reach:
			continue
		var crosses := (pos - foe.position) * (me.position - foe.position) < 0
		if crosses and not me.can_jump():
			continue
		out.append(pos)
	return out


func teleportable_positions() -> Array[int]:
	var out: Array[int] = []
	for pos in rules.arena_size:
		if pos != mechs[0].position and pos != mechs[1].position:
			out.append(pos)
	return out


## Devuelve "" si la accion es legal ahora; si no, el motivo.
func why_illegal(action: BattleAction) -> String:
	if is_over():
		return "el combate ya termino"
	if actions_left <= 0:
		return "sin acciones"
	var me := attacker()
	var foe := defender()
	match action.type:
		BattleAction.Type.COOL:
			return ""
		BattleAction.Type.WALK:
			return "" if action.position in walkable_positions() else "casilla no alcanzable"
		BattleAction.Type.STOMP:
			if not me.slots["legs"].def.deals_damage():
				return "las piernas no hacen dano"
			return why_cant_use(me, foe, "legs")
		BattleAction.Type.WEAPON:
			if not (action.slot in me.weapon_keys()):
				return "no es un arma equipada"
			return why_cant_use(me, foe, action.slot)
		BattleAction.Type.CHARGE:
			return why_cant_use(me, foe, "charge")
		BattleAction.Type.HOOK:
			return why_cant_use(me, foe, "hook")
		BattleAction.Type.TELEPORT:
			var reason := why_cant_use(me, foe, "teleport")
			if reason != "":
				return reason
			if not (action.position in teleportable_positions()):
				return "casilla ocupada o fuera de la arena"
			return ""
	return "accion desconocida"


func legal_actions() -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	if is_over() or actions_left <= 0:
		return out
	var candidates: Array[BattleAction] = [
		BattleAction.cool(), BattleAction.stomp(), BattleAction.charge(), BattleAction.hook()
	]
	for key in attacker().weapon_keys():
		candidates.append(BattleAction.weapon(key))
	for pos in walkable_positions():
		candidates.append(BattleAction.walk(pos))
	if attacker().slots.has("teleport"):
		for pos in teleportable_positions():
			candidates.append(BattleAction.teleport(pos))
	for action in candidates:
		if why_illegal(action) == "":
			out.append(action)
	return out


## M3: resultado esperado de una accion sin ejecutarla. El dano va de min a max.
func preview(action: BattleAction) -> Dictionary:
	var me := attacker()
	var foe := defender()
	var out := {
		"legal": why_illegal(action) == "",
		"dmg_min": 0,
		"dmg_max": 0,
		"self_heat": me.heat,
		"self_energy": me.energy,
		"self_health": me.health,
		"target_heat": foe.heat,
		"target_energy": foe.energy,
		"self_overheats": false,
		"target_overheats": false,
	}
	var key := _slot_key(action)
	if action.type == BattleAction.Type.COOL:
		out["self_heat"] = maxi(0, me.heat - me.cooling)
	elif key != "" and me.slots.has(key):
		var def := me.slots[key].def
		var hits := true
		if action.type == BattleAction.Type.TELEPORT:
			hits = absi(action.position - foe.position) == 1
		if hits:
			out["dmg_min"] = _damage(def, foe, 0.0)
			out["dmg_max"] = _damage(def, foe, 1.0)
			out["target_heat"] = foe.heat + def.heat_dmg
			out["target_energy"] = maxi(0, foe.energy - def.energy_dmg)
			out["self_health"] = me.health - def.backfire
		out["self_heat"] = me.heat + def.heat_cost
		out["self_energy"] = me.energy - def.energy_cost
	out["self_overheats"] = out["self_heat"] > me.heat_cap
	out["target_overheats"] = out["target_heat"] > foe.heat_cap
	return out


# --- Ejecucion ---------------------------------------------------------------


## Ejecuta la accion. Devuelve "" si se aplico; si no, el motivo y no cambia nada.
func apply(action: BattleAction) -> String:
	var reason := why_illegal(action)
	if reason != "":
		return reason
	var me := attacker()
	var foe := defender()
	match action.type:
		BattleAction.Type.COOL:
			var amount := mini(me.cooling, me.heat)
			me.heat -= amount
			_log("cool", {"amount": amount})
		BattleAction.Type.WALK:
			_log("walk", {"from": me.position, "to": action.position})
			me.position = action.position
		BattleAction.Type.STOMP:
			_use(me, foe, "legs", "stomp")
		BattleAction.Type.WEAPON:
			if me.slots[action.slot].def.has_tag(ItemDef.TAG_SWORD):
				me.position = foe.position - _dir(me, foe)
			_use(me, foe, action.slot, "weapon")
		BattleAction.Type.CHARGE:
			me.position = foe.position - _dir(me, foe)
			_use(me, foe, "charge", "charge")
		BattleAction.Type.HOOK:
			_use(me, foe, "hook", "hook", false)
			foe.position = me.position + _dir(me, foe)
		BattleAction.Type.TELEPORT:
			var from := me.position
			me.position = action.position
			var hits := absi(me.position - foe.position) == 1
			if hits:
				_use(me, foe, "teleport", "teleport", false)
			else:
				# Sin rival al lado no hay golpe, pero el salto se paga igual.
				var tele := me.slots["teleport"]
				me.heat += tele.def.heat_cost
				me.energy -= tele.def.energy_cost
				_spend_use(tele)
				_log("teleport", {"slot": "teleport", "damage": 0})
			events[-1]["from"] = from
			events[-1]["to"] = me.position
	actions_left -= 1
	if _check_winner():
		return ""
	if actions_left == 0:
		_end_turn(true)
	return ""


func _begin_turn() -> void:
	var me := attacker()
	turn_number += 1
	for slot: BattleMech.Slot in me.slots.values():
		slot.used_this_turn = false
	var actions := rules.actions_per_turn
	var shutdown := false
	if me.heat > me.heat_cap:
		shutdown = me.heat - me.cooling > me.heat_cap
		if shutdown and rules.m2_no_chain_shutdown and me.shutdown_last_turn:
			shutdown = false
		var amount := mini(me.cooling * (2 if shutdown else 1), me.heat)
		me.heat -= amount
		if shutdown:
			_log("shutdown", {"amount": amount})
		else:
			actions = 1
			_log("forced_cool", {"amount": amount})
	me.shutdown_last_turn = shutdown
	if rules.m6_regen_at_turn_start:
		_regen(me)
	if _first_turn and rules.m5_first_turn_single_action:
		actions = mini(actions, 1)
	_first_turn = false
	if shutdown:
		actions_left = 0
		_end_turn(false)
	else:
		actions_left = actions


func _end_turn(fire_drone: bool) -> void:
	var me := attacker()
	var foe := defender()
	if fire_drone and why_cant_use(me, foe, "drone") == "":
		_use(me, foe, "drone", "drone")
		if _check_winner():
			return
	if not rules.m6_regen_at_turn_start:
		_regen(me)
	turn = 1 - turn
	_begin_turn()


func _regen(mech: BattleMech) -> void:
	var before := mech.energy
	mech.energy = mini(mech.energy_cap, mech.energy + mech.energy_regen)
	if mech.energy != before:
		_log("regen", {"amount": mech.energy - before})


## Usa la pieza del hueco: tira el dano, aplica costos y efectos, y mueve.
func _use(
	user: BattleMech, target: BattleMech, key: String, event: String, move: bool = true
) -> void:
	var slot := user.slots[key]
	var def := slot.def
	var damage := _damage(def, target, _rng.randf() if def.deals_damage() else 0.0)

	user.health -= def.backfire
	user.heat += def.heat_cost
	user.energy -= def.energy_cost

	target.health -= damage
	target.heat += def.heat_dmg
	target.energy = maxi(0, target.energy - def.energy_dmg)
	if def.element != ItemDef.Element.COMBINED:
		target.res[def.element] = maxi(0, target.res[def.element] - def.res_dmg)
	if def.heat_cap_dmg > 0:
		target.heat_cap = maxi(1, target.heat_cap - def.heat_cap_dmg)
	if def.cooling_dmg > 0:
		target.cooling = maxi(1, target.cooling - def.cooling_dmg)
	if def.energy_cap_dmg > 0:
		target.energy_cap = maxi(1, target.energy_cap - def.energy_cap_dmg)
		target.energy = mini(target.energy, target.energy_cap)
	if def.energy_regen_dmg > 0:
		target.energy_regen = maxi(1, target.energy_regen - def.energy_regen_dmg)

	if move:
		_apply_movement(user, target, def)
	_spend_use(slot)
	_log(event, {"slot": key, "item": def.id, "damage": damage})


func _spend_use(slot: BattleMech.Slot) -> void:
	slot.used_this_turn = true
	if slot.uses_left > 0:
		slot.uses_left -= 1


## Dano final (GDD 2.4). roll en [0, 1].
func _damage(def: ItemDef, target: BattleMech, roll: float) -> int:
	var damage := 0
	if def.deals_damage():
		damage = def.dmg_min + roundi(roll * (def.dmg_max - def.dmg_min))
		if def.element != ItemDef.Element.COMBINED:
			damage = maxi(1, damage - target.res[def.element])
	# Rotura de energia: lo que el arma drena de mas se vuelve dano.
	return damage + maxi(0, def.energy_dmg - target.energy)


func _apply_movement(user: BattleMech, target: BattleMech, def: ItemDef) -> void:
	var last := rules.arena_size - 1
	var dir := _dir(user, target)
	if def.recoil > 0:
		user.position = clampi(user.position - def.recoil * dir, 0, last)
	if def.retreat > 0:
		user.position = clampi(user.position - def.retreat * dir, 0, last)
	if def.advance > 0:
		var gap := absi(target.position - user.position) - 1
		user.position += mini(def.advance, gap) * dir
	if def.push > 0:
		target.position = clampi(target.position + def.push * dir, 0, last)
	if def.pull > 0:
		var gap := absi(target.position - user.position) - 1
		target.position -= mini(def.pull, gap) * dir


## +1 si el rival esta a la derecha de user, -1 si esta a la izquierda.
func _dir(user: BattleMech, target: BattleMech) -> int:
	return 1 if user.position < target.position else -1


func _slot_key(action: BattleAction) -> String:
	match action.type:
		BattleAction.Type.STOMP:
			return "legs"
		BattleAction.Type.WEAPON:
			return action.slot
		BattleAction.Type.CHARGE:
			return "charge"
		BattleAction.Type.TELEPORT:
			return "teleport"
		BattleAction.Type.HOOK:
			return "hook"
	return ""


func _check_winner() -> bool:
	var a := mechs[0].health
	var b := mechs[1].health
	if a > 0 and b > 0:
		return false
	if a <= 0 and b <= 0:
		# Ambos caen: gana quien conserve mas vida; en empate, el defensor.
		winner = (0 if a > b else 1) if a != b else 1 - turn
	else:
		winner = 0 if b <= 0 else 1
	actions_left = 0
	_log("win", {"winner": winner})
	return true


func _log(event: String, data: Dictionary = {}) -> void:
	var entry := {"event": event, "turn": turn_number, "actor": turn}
	entry.merge(data)
	events.append(entry)
