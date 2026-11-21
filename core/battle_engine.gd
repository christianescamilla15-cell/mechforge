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
## Si es false no se guarda el registro (las copias de busqueda de la IA).
var logging: bool = true
## Si es >= 0, todas las tiradas de dano usan este valor en vez del RNG.
## La IA evalua con 0.5 (dano esperado) para no depender de la suerte.
var fixed_roll: float = -1.0

## Bonificacion que hay en la arena (GDD 2.8): {"cell", "kind", "amount"};
## vacio si no hay ninguna.
var drop: Dictionary = {}

## Si >= 0, la tirada de critico usa este valor (para tests): hay critico
## si es menor que la probabilidad.
var fixed_crit: float = -1.0
## Las copias de busqueda de la IA no tiran criticos: suman su dano esperado
## y no aplican sus efectos.
var expected_crits: bool = false
var _rng := RandomNumberGenerator.new()
var _first_turn := true
## Las copias que usa la IA para probar jugadas no hacen caer bonificaciones.
var _spawns_drops := true


## Sin argumentos crea un motor vacio; solo lo usa clone().
func _init(
	p_rules: RulesConfig = null,
	build_a: MechBuild = null,
	build_b: MechBuild = null,
	seed_value: int = 0,
	starter: int = 0,
	start_pair: int = -1
) -> void:
	if p_rules == null:
		return
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


## Copia independiente del estado. Con for_search no guarda registro y usa el
## dano esperado, que es lo que necesita la IA para probar jugadas.
func clone(for_search: bool = true) -> BattleEngine:
	var copy := BattleEngine.new()
	copy.rules = rules
	copy.mechs = [mechs[0].clone(), mechs[1].clone()]
	copy.turn = turn
	copy.actions_left = actions_left
	copy.turn_number = turn_number
	copy.winner = winner
	copy._first_turn = _first_turn
	copy.drop = drop.duplicate()
	copy._spawns_drops = _spawns_drops and not for_search
	copy.fixed_crit = fixed_crit
	if for_search:
		copy.logging = false
		copy.fixed_roll = 0.5
		copy.expected_crits = true
	else:
		copy.logging = logging
		copy.fixed_roll = fixed_roll
		copy.expected_crits = expected_crits
		copy.events = events.duplicate(true)
		copy._rng.seed = _rng.seed
		copy._rng.state = _rng.state
	return copy


# --- Consultas ---------------------------------------------------------------


## Devuelve "" si el mech puede usar ese hueco ahora; si no, el motivo (GDD 2.6).
func why_cant_use(user: BattleMech, target: BattleMech, key: String) -> String:
	if not user.slots.has(key):
		return "no tiene esa pieza"
	var slot := user.slots[key]
	var def := slot.def
	if user.energy_cost(def) > user.energy:
		return "falta energia"
	if def.backfire > 0 and user.backfire_of(def) >= user.health:
		return "falta vida"
	if slot.uses_left == 0:
		return "sin usos"
	if slot.used_this_turn:
		return "ya se uso este turno"
	if key == user.disabled_slot:
		return "arma inutilizada"
	if user.immobilized and _moves_user(user, target, key):
		return "inmovilizado"
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


## Si usar esa pieza mueve a quien la usa: lo que no puede hacer un mech
## inmovilizado por un critico (embestir, saltar, la espada que salta junto
## al rival y las armas que avanzan o retroceden).
func _moves_user(user: BattleMech, target: BattleMech, key: String) -> bool:
	if key in ["charge", "teleport"]:
		return true
	var def := user.slots[key].def
	if def.has_tag(ItemDef.TAG_SWORD) and absi(user.position - target.position) > 1:
		return true
	return def.advance > 0 or def.retreat > 0


func walkable_positions() -> Array[int]:
	if attacker().immobilized:
		return []
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
		BattleAction.Type.SHIELD, BattleAction.Type.REPAIR, BattleAction.Type.DARK_MATTER:
			return _why_no_skill(action, me, foe)
	return "accion desconocida"


## Habilidades del arbol: escudo, reparacion y materia oscura.
func _why_no_skill(action: BattleAction, me: BattleMech, foe: BattleMech) -> String:
	match action.type:
		BattleAction.Type.SHIELD:
			return "" if me.kits_left("shield") > 0 else "no le quedan escudos"
		BattleAction.Type.REPAIR:
			if me.kits_left("repair") <= 0:
				return "no le quedan reparaciones"
			return "" if me.health < me.max_health else "no tiene danos"
	return _why_no_dark_matter(me, foe)


## Materia oscura (GDD 8): una vez por combate, con el arma de pecho ya
## desplegada y el rival a su alcance; gasta toda la energia.
func _why_no_dark_matter(me: BattleMech, foe: BattleMech) -> String:
	if me.kits_left("dark_matter") <= 0:
		return "no tiene materia oscura"
	if not me.slots.has("chest"):
		return "no lleva arma de pecho"
	if not me.chest_fired:
		return "el arma de pecho aun no se ha desplegado"
	var def := me.slots["chest"].def
	var distance := absi(me.position - foe.position)
	if def.range_max > 0 and (distance < def.range_min or distance > def.range_max):
		return "fuera de alcance"
	if me.energy < me.energy_cost(def):
		return "falta energia"
	return ""


func legal_actions() -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	if is_over() or actions_left <= 0:
		return out
	var me := attacker()
	var foe := defender()
	out.append(BattleAction.cool())
	if me.slots["legs"].def.deals_damage() and why_cant_use(me, foe, "legs") == "":
		out.append(BattleAction.stomp())
	for key in me.weapon_keys():
		if why_cant_use(me, foe, key) == "":
			out.append(BattleAction.weapon(key))
	if why_cant_use(me, foe, "charge") == "":
		out.append(BattleAction.charge())
	if why_cant_use(me, foe, "hook") == "":
		out.append(BattleAction.hook())
	for kind: BattleAction in [
		BattleAction.shield(), BattleAction.repair(), BattleAction.dark_matter()
	]:
		if why_illegal(kind) == "":
			out.append(kind)
	for pos in walkable_positions():
		out.append(BattleAction.walk(pos))
	if why_cant_use(me, foe, "teleport") == "":
		for pos in teleportable_positions():
			out.append(BattleAction.teleport(pos))
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
	if action.type == BattleAction.Type.DARK_MATTER:
		out["dmg_min"] = _dark_matter_damage(me, foe)
		out["dmg_max"] = out["dmg_min"]
		out["self_energy"] = 0
		return out
	var key := _slot_key(action)
	if action.type == BattleAction.Type.COOL:
		out["self_heat"] = maxi(0, me.heat - me.cooling)
	elif key != "" and me.slots.has(key):
		var def := me.slots[key].def
		var hits := true
		if action.type == BattleAction.Type.TELEPORT:
			hits = absi(action.position - foe.position) == 1
		if hits:
			out["dmg_min"] = _damage(def, me, foe, 0.0, 0.0, key)
			out["dmg_max"] = _damage(def, me, foe, 1.0, 0.0, key)
			out["crit_chance"] = crit_chance(def, foe)
			out["crit_effect"] = def.crit_effect
			out["target_heat"] = foe.heat + def.heat_dmg
			if not foe.free_energy():
				out["target_energy"] = maxi(0, foe.energy - def.energy_dmg)
			out["self_health"] = me.health - me.backfire_of(def)
		out["self_heat"] = me.heat + def.heat_cost
		out["self_energy"] = me.energy - me.energy_cost(def)
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
	var foe_health := foe.health
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
				me.energy -= me.energy_cost(tele.def)
				_spend_use(tele)
				_log("teleport", {"slot": "teleport", "damage": 0})
			if logging:
				events[-1]["from"] = from
				events[-1]["to"] = me.position
		BattleAction.Type.SHIELD:
			me.kits["shield"] -= 1
			me.barrier += 1
			_log("barrier")
		BattleAction.Type.REPAIR:
			me.kits["repair"] -= 1
			var healed := mini(
				roundi(me.max_health * me.build.skills.repair_share), me.max_health - me.health
			)
			me.health += healed
			_log("repair_kit", {"amount": healed})
		BattleAction.Type.DARK_MATTER:
			me.kits["dark_matter"] -= 1
			var blast := _dark_matter_damage(me, foe)
			me.energy = 0
			var soaked := foe.hurt(blast)
			var data := {"slot": "chest", "damage": blast}
			_note_layer(data, foe, soaked)
			if rules.impact_enabled:
				data.merge(_dark_matter_impact(me, foe))
			_log("dark_matter", data)
	_evade_if_hit(foe, me, foe_health)
	_check_pickup()
	actions_left -= 1
	if _check_winner():
		return ""
	if actions_left == 0:
		_end_turn(true)
	return ""


func _begin_turn() -> void:
	var me := attacker()
	var foe := defender()
	turn_number += 1
	_maybe_spawn_drop()
	for slot: BattleMech.Slot in me.slots.values():
		slot.used_this_turn = false
	# El escudo y la evasion del rival se recargan en cada turno de quien ataca.
	foe.shield_left = foe.shield_hits()
	foe.evade_left = 1 if foe.evades() else 0
	if me.regen_share() > 0.0 and me.health < me.max_health:
		var repair := maxi(1, roundi(me.max_health * me.regen_share()))
		repair = mini(repair, me.max_health - me.health)
		me.health += repair
		_log("repair", {"amount": repair})
	if me.no_overheat():
		me.heat = mini(me.heat, me.heat_cap)
	# Valvula de alivio (prototipo): un sobrecalentamiento que no le cuesta
	# nada; el calor queda en su tope.
	if me.heat > me.heat_cap and me.relief_left > 0:
		me.relief_left -= 1
		me.heat = me.heat_cap
		_log("relief", {"left": me.relief_left})
	var actions := rules.actions_per_turn + me.extra_actions()
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
	if me.stunned:
		# Critico de blaster (GDD 2.9): pierde una accion, pero le queda una.
		me.stunned = false
		if actions > 1:
			actions -= 1
			_log("stunned")
	_first_turn = false
	if shutdown:
		actions_left = 0
		_end_turn(false)
	else:
		actions_left = actions


func _end_turn(fire_drone: bool) -> void:
	var me := attacker()
	var foe := defender()
	if fire_drone and _fire_assist(me, foe):
		return
	if not rules.m6_regen_at_turn_start:
		_regen(me)
	_check_pickup()
	_tick_buffs(me)
	# Los efectos de un critico duran el turno del mech que los sufrio.
	me.disabled_slot = ""
	me.immobilized = false
	turn = 1 - turn
	_begin_turn()


## El robot de asistencia dispara una de sus armas: alterna la superior y
## la inferior, y si a la que le toca no puede (alcance, usos o costo),
## dispara la otra. Un solo disparo por turno: medido el 2026-11-17, cada
## disparo de mas rompia el balance entre elementos. El enjambre de la
## Colmena repite el arma que disparo. Devuelve true si el combate termino.
func _fire_assist(me: BattleMech, foe: BattleMech) -> bool:
	var fired := ""
	for key in me.assist_order():
		if why_cant_use(me, foe, key) == "":
			fired = key
			break
	if fired == "":
		return false
	me.assist_last = fired
	for i in 1 + me.extra_drone_shots():
		if i > 0:
			# El enjambre no dispara con el rival pegado.
			if absi(me.position - foe.position) <= 1:
				break
			me.slots[fired].used_this_turn = false
			if why_cant_use(me, foe, fired) != "":
				break
		var before := foe.health
		_use(me, foe, fired, "drone")
		if _check_winner():
			return true
		_evade_if_hit(foe, me, before)
	return false


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
	var roll := 0.0
	if def.deals_damage():
		roll = fixed_roll if fixed_roll >= 0.0 else _rng.randf()
	var shielded := def.deals_damage() and (target.shield_left > 0 or target.barrier > 0)
	var crit := 0.0
	var chance := crit_chance(def, target)
	if chance > 0.0:
		if expected_crits:
			crit = chance
		else:
			var draw := fixed_crit if fixed_crit >= 0.0 else _rng.randf()
			crit = 1.0 if draw < chance else 0.0
	var damage := _damage(def, user, target, roll, crit, key)
	if shielded:
		if target.shield_left > 0:
			target.shield_left -= 1
		else:
			target.barrier -= 1
	if key == "chest":
		user.chest_fired = true

	user.health -= user.backfire_of(def)
	user.heat += def.heat_cost
	user.energy -= user.energy_cost(def)

	var soaked := target.hurt(damage)
	# Un critico tambien calienta y drena mas: si no, solo lo aprovechaban las
	# armas de dano directo (medido el 2026-11-18: el fisico laser gano el 67 %).
	target.heat += roundi(def.heat_dmg * _crit_factor(crit))
	if not target.free_energy():
		target.energy = maxi(0, target.energy - roundi(def.energy_dmg * _crit_factor(crit)))
	if def.element != ItemDef.Element.COMBINED:
		target.res[def.element] = maxi(0, target.res[def.element] - def.res_dmg)
	if def.heat_cap_dmg > 0:
		target.heat_cap = maxi(1, target.heat_cap - def.heat_cap_dmg)
	if def.cooling_dmg > 0:
		target.cooling = maxi(1, target.cooling - def.cooling_dmg)
	if def.energy_cap_dmg > 0 and not target.free_energy():
		target.energy_cap = maxi(1, target.energy_cap - def.energy_cap_dmg)
		target.energy = mini(target.energy, target.energy_cap)
	if def.energy_regen_dmg > 0 and not target.free_energy():
		target.energy_regen = maxi(1, target.energy_regen - def.energy_regen_dmg)

	var data := {"slot": key, "item": def.id, "damage": damage}
	_note_layer(data, target, soaked)
	if damage > 0 and def.proto_effect != "":
		_proto_on_hit(user, def, damage, data)
	if crit >= 1.0:
		data.merge(_apply_crit(def, target))
	# Un escudo que para el golpe tambien para su impacto.
	var knock := 0 if shielded else impact_push(def, target)
	if knock > 0:
		data["knock"] = knock
	if move:
		_apply_movement(user, target, def, knock)
	_spend_use(slot)
	if shielded:
		data["shielded"] = true
	_log(event, data)


## Probabilidad de que un golpe de esa arma sea critico (GDD 2.9): la del
## arma, por su poder frente al blindaje del rival, menos lo que paran su
## armadura gruesa (resistencia frente al dano del arma) y su escudo. 0 si
## los criticos estan apagados o un escudo para el golpe.
## Con el percutor del especialista (GDD 8.6) se suma la suya, aunque los
## criticos esten apagados o el arma no tenga.
func crit_chance(def: ItemDef, target: BattleMech) -> float:
	if not def.deals_damage() or target.shield_left > 0 or target.barrier > 0:
		return 0.0
	var extra := def.proto_value if def.proto_effect == "crit" else 0.0
	if not rules.crits_enabled or def.crit <= 0:
		return clampf(extra, 0.0, rules.crit_cap)
	var chance := def.crit / 100.0
	var level := ItemScaling.power(rules, def.tier, def.level) / target.armor_power(rules)
	chance *= clampf(level, rules.crit_level_min, rules.crit_level_max)
	if def.element != ItemDef.Element.COMBINED:
		var mean := maxf(1.0, (def.dmg_min + def.dmg_max) / 2.0)
		var armor := float(target.res[def.element]) / mean
		chance *= maxf(0.0, 1.0 - rules.crit_armor_weight * armor)
	chance *= maxf(0.0, 1.0 - rules.crit_shield_cut * target.shield_level())
	chance *= 1.0 - target.buff_amount("armor")
	return clampf(chance + extra, 0.0, rules.crit_cap)


## Efectos de un critico ademas del dano (el de "pierce" ya va en el dano).
## Devuelve lo que hay que anadir al registro.
func _apply_crit(def: ItemDef, target: BattleMech) -> Dictionary:
	var out := {"crit": true, "crit_effect": def.crit_effect}
	match def.crit_effect:
		"immobilize":
			target.immobilized = true
		"disable":
			var key := _hit_weapon(target)
			if key != "":
				target.disabled_slot = key
				out["disabled"] = key
		"stun":
			target.stunned = true
	return out


## El arma que inutiliza un critico de laser: una al azar de las que al mech
## le quedan, la que alcanza el haz. Medido el 2026-11-18: si era siempre la
## mas fuerte, al mech de calor o de energia le quitaba la pieza de su
## presion y el fisico laser ganaba el 57-67 %.
func _hit_weapon(mech: BattleMech) -> String:
	var ready: Array[String] = []
	for key in mech.weapon_keys():
		if mech.slots[key].uses_left != 0:
			ready.append(key)
	if ready.is_empty():
		return ""
	return ready[_rng.randi_range(0, ready.size() - 1)]


func _spend_use(slot: BattleMech.Slot) -> void:
	slot.used_this_turn = true
	if slot.uses_left > 0:
		slot.uses_left -= 1


## Dano final (GDD 2.4). roll en [0, 1]. crit: 1 si es critico, 0 si no, y
## entre medias el dano esperado (GDD 2.9). `key`: el hueco del que dispara,
## para el dano de mas de los modulos de ataque (OBS-040).
func _damage(
	def: ItemDef,
	attacker: BattleMech,
	target: BattleMech,
	roll: float,
	crit: float = 0.0,
	key: String = ""
) -> int:
	if def.deals_damage() and (target.shield_left > 0 or target.barrier > 0):
		return 0
	var damage := 0
	if def.deals_damage():
		damage = def.dmg_min + roundi(roll * (def.dmg_max - def.dmg_min))
		damage += attacker.module_damage(key)
		# Con potencia 1.0 el resultado es exactamente el de antes.
		damage = roundi(damage * attacker.damage_mult())
		if def.proto_effect == "damage":
			damage = roundi(damage * (1.0 + def.proto_value))
		if attacker.build != null and def == attacker.build.chest:
			damage = roundi(damage * attacker.chest_damage_mult())
		if attacker.build != null and def in [attacker.build.drone, attacker.build.drone_low]:
			damage = roundi(damage * attacker.assist_power())
		if crit > 0.0:
			damage = roundi(damage * _crit_factor(crit))
		if def.element != ItemDef.Element.COMBINED:
			var resistance: int = target.res[def.element]
			# El critico de balas atraviesa la resistencia.
			if def.crit_effect == "pierce":
				resistance = roundi(resistance * (1.0 - crit))
			damage = maxi(1, damage - resistance)
		# Bonificacion de armadura del rival (GDD 2.8); sin ella no cambia nada.
		var armor := target.buff_amount("armor")
		if armor > 0.0:
			damage = maxi(1, roundi(damage * (1.0 - armor)))
	# Rotura de energia: lo que el arma drena de mas se vuelve dano.
	if target.free_energy():
		return damage
	return damage + maxi(0, roundi(def.energy_dmg * _crit_factor(crit)) - target.energy)


## Cuanto multiplica un critico: 1 sin critico, el multiplicador entero con
## critico y entre medias el valor esperado.
func _crit_factor(crit: float) -> float:
	return 1.0 + crit * (rules.crit_damage_mult - 1.0)


## Impacto de la materia oscura (GDD 2.10): manda al rival hasta el borde de
## la arena y le deja el critico de su arma de pecho. Devuelve lo que hay que
## anadir al registro.
func _dark_matter_impact(me: BattleMech, foe: BattleMech) -> Dictionary:
	var out := {}
	var edge := rules.arena_size - 1 if _dir(me, foe) > 0 else 0
	var knock := absi(edge - foe.position)
	if knock > 0:
		foe.position = edge
		out["knock"] = knock
	var chest := me.slots["chest"].def
	if chest.crit_effect != "":
		out.merge(_apply_crit(chest, foe))
	return out


## Materia oscura: una parte de la vida maxima del rival, sin resistencias
## ni escudos.
func _dark_matter_damage(me: BattleMech, foe: BattleMech) -> int:
	return roundi(foe.max_health * me.build.skills.dark_matter_share)


## Evasion (GDD 9.1): si el golpe le hizo dano, salta al extremo de la
## arena de su lado, lejos de quien le pego.
func _evade_if_hit(target: BattleMech, user: BattleMech, health_before: int) -> void:
	if target.evade_left <= 0 or target.health <= 0 or target.health >= health_before:
		return
	var to := 0 if target.position < user.position else rules.arena_size - 1
	if to == target.position:
		return
	var from := target.position
	target.position = to
	target.evade_left -= 1
	_log("evade", {"who": mechs.find(target), "from": from, "to": to})


## Casillas que empuja el impacto de un golpe de esa arma (GDD 2.10): nada
## las de brazo, impact_push_top las de hombro (no el ancla, que jala) y
## hasta impact_push_chest las de pecho, menos si el blindaje del rival es de
## mas clase que el arma.
func impact_push(def: ItemDef, target: BattleMech) -> int:
	if not rules.impact_enabled or not def.deals_damage() or def.pull > 0:
		return 0
	match def.type:
		ItemDef.Type.TOP:
			return rules.impact_push_top
		ItemDef.Type.CHEST:
			var level := ItemScaling.power(rules, def.tier, def.level) / target.armor_power(rules)
			return clampi(roundi(rules.impact_push_chest * level), 1, rules.impact_push_chest)
	return 0


func _apply_movement(user: BattleMech, target: BattleMech, def: ItemDef, knock: int = 0) -> void:
	var last := rules.arena_size - 1
	var dir := _dir(user, target)
	if def.recoil > 0:
		user.position = clampi(user.position - def.recoil * dir, 0, last)
	if def.retreat > 0:
		user.position = clampi(user.position - def.retreat * dir, 0, last)
	if def.advance > 0:
		var gap := absi(target.position - user.position) - 1
		user.position += mini(def.advance, gap) * dir
	var push := maxi(def.push, knock)
	if push > 0:
		target.position = clampi(target.position + push * dir, 0, last)
	if def.pull > 0:
		var gap := absi(target.position - user.position) - 1
		target.position -= mini(def.pull, gap) * dir


# --- Bonificaciones (GDD 2.8) --------------------------------------------------


## Hace caer una bonificacion en una casilla libre cuando toca. Que es y
## cuanto da salen del azar del combate, asi que se repite con la misma semilla.
func _maybe_spawn_drop() -> void:
	if not (rules.drops_enabled and _spawns_drops and drop.is_empty()):
		return
	var since := turn_number - rules.drop_first_turn
	if since < 0 or since % maxi(rules.drop_every, 1) != 0:
		return
	var free: Array[int] = []
	for cell in rules.arena_size:
		if cell != mechs[0].position and cell != mechs[1].position:
			free.append(cell)
	if free.is_empty() or rules.drop_kinds.is_empty():
		return
	var amount := lerpf(rules.drop_min, rules.drop_max, _rng.randf())
	drop = {
		"cell": free[_rng.randi_range(0, free.size() - 1)],
		"kind": rules.drop_kinds[_rng.randi_range(0, rules.drop_kinds.size() - 1)],
		"amount": snappedf(amount, 0.01),
	}
	_log("drop_spawn", {"cell": drop["cell"], "kind": drop["kind"]})


## Si un mech esta sobre la bonificacion, la toma: llego andando, saltando o
## empujado, da igual.
func _check_pickup() -> void:
	if drop.is_empty():
		return
	for who in 2:
		if mechs[who].position != drop["cell"]:
			continue
		var buff := {"kind": drop["kind"], "amount": drop["amount"], "turns": rules.drop_duration}
		mechs[who].buffs.append(buff)
		drop = {}
		var data := {"who": who, "kind": buff["kind"], "amount": buff["amount"]}
		data["turns"] = buff["turns"]
		_log("drop_taken", data)
		return


## Al acabar su turno, a las bonificaciones de un mech les queda un turno menos.
func _tick_buffs(mech: BattleMech) -> void:
	var kept: Array[Dictionary] = []
	for buff in mech.buffs:
		buff["turns"] -= 1
		if buff["turns"] > 0:
			kept.append(buff)
		else:
			_log("buff_end", {"who": mechs.find(mech), "kind": buff["kind"]})
	mech.buffs = kept


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
	if not logging:
		return
	var entry := {"event": event, "turn": turn_number, "actor": turn}
	entry.merge(data)
	# Foto del estado tras el evento: la pantalla la usa para animar paso a paso.
	entry["state"] = [_snapshot(mechs[0]), _snapshot(mechs[1])]
	entry["actions_left"] = actions_left
	entry["drop"] = drop.duplicate()
	events.append(entry)


## Lo que hace un prototipo del especialista con cada golpe que acierta su
## arma (GDD 8.6): devolver vida, devolver energia o quitar calor.
func _proto_on_hit(user: BattleMech, def: ItemDef, damage: int, data: Dictionary) -> void:
	match def.proto_effect:
		"lifesteal":
			var healed := mini(roundi(damage * def.proto_value), user.max_health - user.health)
			if healed > 0:
				user.health += healed
				data["lifesteal"] = healed
		"energy_on_hit":
			var gained := mini(
				roundi(user.energy_cap * def.proto_value), user.energy_cap - user.energy
			)
			if gained > 0:
				user.energy += gained
				data["energy_gain"] = gained
		"cool_on_hit":
			var vented := mini(roundi(user.heat_cap * def.proto_value), user.heat)
			if vented > 0:
				user.heat -= vented
				data["vented"] = vented


## Lo que paro el manto en un golpe, y si se rompio con el.
func _note_layer(data: Dictionary, target: BattleMech, soaked: int) -> void:
	if soaked <= 0:
		return
	data["layer"] = soaked
	if target.layer == 0:
		data["layer_broken"] = true


func _snapshot(mech: BattleMech) -> Dictionary:
	return {
		"pos": mech.position,
		"health": mech.health,
		"layer": mech.layer,
		"layer_max": mech.layer_max,
		"heat": mech.heat,
		"energy": mech.energy,
		"heat_cap": mech.heat_cap,
		"energy_cap": mech.energy_cap,
		"cooling": mech.cooling,
		"regen": mech.energy_regen,
		"res": mech.res.duplicate(),
		"buffs": mech.buffs.duplicate(true),
		"immobilized": mech.immobilized,
		"disabled": mech.disabled_slot,
		"stunned": mech.stunned,
	}
