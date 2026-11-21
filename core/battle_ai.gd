class_name BattleAI
extends RefCounted
## IA por utilidad (GDD 7): prueba cada secuencia legal del turno en una copia
## del combate, valora el estado resultante y devuelve la primera accion de la
## mejor. Sirve para los enemigos de la campana y para el simulador de balance.

enum Difficulty { RANDOM, EASY, NORMAL, HARD }

var difficulty: Difficulty
var config: AIConfig

var _rng := RandomNumberGenerator.new()


func _init(
	p_difficulty: Difficulty = Difficulty.NORMAL, seed_value: int = 0, p_config: AIConfig = null
) -> void:
	difficulty = p_difficulty
	config = p_config if p_config else AIConfig.new()
	_rng.seed = seed_value


## Devuelve la accion a ejecutar ahora, o null si no hay ninguna legal.
func choose_action(engine: BattleEngine) -> BattleAction:
	var actions := engine.legal_actions()
	if actions.is_empty():
		return null
	if difficulty == Difficulty.RANDOM:
		return actions[_rng.randi_range(0, actions.size() - 1)]

	var me := engine.turn
	# Cada candidato: la primera accion y el estado final de su mejor secuencia.
	var candidates: Array[Dictionary] = []
	for first in actions:
		var after_first := engine.clone()
		after_first.apply(first)
		var best_state := after_first
		var best_score := -INF
		if _turn_ended(after_first, engine):
			best_score = evaluate(after_first, me)
			if after_first.winner == me:
				# Ganar ya vale mas que ganar con la segunda accion.
				best_score += 1.0
		else:
			for second in after_first.legal_actions():
				var after_second := after_first.clone()
				after_second.apply(second)
				var score := evaluate(after_second, me)
				if score > best_score:
					best_score = score
					best_state = after_second
		# Su caracter: lo que le gusta hacer (AIConfig).
		var taste := _taste(first)
		best_score += taste
		if difficulty == Difficulty.EASY:
			best_score += _rng.randf_range(-config.easy_noise, config.easy_noise)
		candidates.append(
			{
				"action": first,
				"score": best_score,
				"state": best_state,
				"taste": taste,
				"order": candidates.size()
			}
		)

	# A igual valoracion gana la primera accion encontrada (orden estable).
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a["score"] != b["score"]:
				return a["score"] > b["score"]
			return a["order"] < b["order"]
	)
	if difficulty == Difficulty.HARD:
		return _best_against_reply(candidates, me)
	return candidates[0]["action"]


## Valor del estado para el jugador `me`. Positivo es bueno para el.
func evaluate(e: BattleEngine, me: int) -> float:
	if e.is_over():
		return config.win_value if e.winner == me else -config.win_value
	var mine := e.mechs[me]
	var foe := e.mechs[1 - me]
	# Lo que vale una accion de cada uno, en fraccion de la vida del otro.
	var my_strike := _strike(mine, foe)
	var foe_strike := _strike(foe, mine)
	var per_turn := float(e.rules.actions_per_turn)

	# El temperamento (AIConfig): cuanto pesa cada cosa para este rival.
	var score := (
		# Con el manto de plasma (OBS-041): la vida que le queda contandolo.
		config.guard * _ratio(mine.toughness(), mine.max_toughness())
		- config.aggression * _ratio(foe.toughness(), foe.max_toughness())
	)

	# Acciones que el calor ya le quito al rival en el turno que empieza.
	if e.turn == me:
		score += config.pressure * (foe_strike * per_turn + _assist_strike(foe, mine))
	else:
		score += config.pressure * foe_strike * (per_turn - e.actions_left)

	# Calor pendiente: cada `enfriamiento` de calor costara una accion. Enfriar
	# antes de tiempo no ahorra nada, asi que no se penaliza el riesgo de un
	# enfriado forzado: solo el calor acumulado.
	var foe_heat := config.heat_discount * foe_strike * _ratio(foe.heat, foe.cooling)
	var my_heat := config.heat_discount * my_strike * _ratio(mine.heat, mine.cooling)
	score += config.pressure * foe_heat - config.caution * my_heat

	var foe_dry := (
		config.energy_discount * foe_strike * per_turn * _energy_starvation(foe, mine, false)
	)
	var my_dry := (
		config.energy_discount * my_strike * per_turn * _energy_starvation(mine, foe, true)
	)
	score += config.pressure * foe_dry - config.caution * my_dry

	# Habilidades del arbol: un escudo activado vale lo que absorbera, y un kit
	# de reparacion sin usar vale parte de lo que curaria.
	score += config.barrier_value * (foe_strike * mine.barrier - my_strike * foe.barrier)
	score += config.repair_hold * (_repair_worth(mine) - _repair_worth(foe))
	# Bonificaciones en vigor (GDD 2.8): valen por lo que dan y lo que les queda.
	score += config.buff_turn_value * (_buff_worth(mine) - _buff_worth(foe))

	var distance := absi(mine.position - foe.position)
	score -= config.position_discount * my_strike * (1.0 - _reach(mine, distance))
	score += config.evasion * config.position_discount * foe_strike * (1.0 - _reach(foe, distance))
	return score


## En dificil: entre las mejores jugadas, elige la que deja mejor parado
## despues de la mejor respuesta del rival.
func _best_against_reply(candidates: Array[Dictionary], me: int) -> BattleAction:
	var best_action: BattleAction = candidates[0]["action"]
	var best_value := -INF
	for i in mini(config.hard_candidates, candidates.size()):
		var state: BattleEngine = candidates[i]["state"]
		var value: float = candidates[i]["score"]
		if not state.is_over() and state.turn != me:
			value = _worst_reply_value(state, me) + float(candidates[i]["taste"])
		if value > best_value:
			best_value = value
			best_action = candidates[i]["action"]
	return best_action


func _worst_reply_value(state: BattleEngine, me: int) -> float:
	var worst := INF
	for first in state.legal_actions():
		var after_first := state.clone()
		after_first.apply(first)
		if _turn_ended(after_first, state):
			worst = minf(worst, evaluate(after_first, me))
			continue
		for second in after_first.legal_actions():
			var after_second := after_first.clone()
			after_second.apply(second)
			worst = minf(worst, evaluate(after_second, me))
	return worst


## Lo que suma a una jugada el caracter del rival: su gusto por ese tipo de
## accion.
func _taste(action: BattleAction) -> float:
	var kind: String = BattleAction.Type.keys()[action.type]
	return float(config.likes.get(kind.to_lower(), 0.0))


func _turn_ended(after: BattleEngine, before: BattleEngine) -> bool:
	return after.is_over() or after.turn_number != before.turn_number


func _repair_worth(mech: BattleMech) -> float:
	if mech.build == null or mech.build.skills == null:
		return 0.0
	return mech.kits_left("repair") * mech.build.skills.repair_share


func _buff_worth(mech: BattleMech) -> float:
	var total := 0.0
	for buff in mech.buffs:
		total += buff["amount"] * buff["turns"]
	return total


func _ratio(value: int, total: int) -> float:
	return float(value) / float(maxi(total, 1))


## Fraccion de la vida de `target` que quita una accion media de `mech`: la
## media de sus dos mejores armas con usos (o el pisoton si no tiene armas).
func _strike(mech: BattleMech, target: BattleMech) -> float:
	var hits: Array[float] = []
	for key in mech.weapon_keys():
		if mech.slots[key].uses_left != 0:
			hits.append(_slot_strike(mech, target, key))
	if hits.is_empty():
		return _slot_strike(mech, target, "legs")
	hits.sort()
	hits.reverse()
	var count := mini(2, hits.size())
	var total := 0.0
	for i in count:
		total += hits[i]
	return total / count


## Fraccion de la vida de `target` que quita de media la pieza de ese hueco.
func _slot_strike(mech: BattleMech, target: BattleMech, key: String) -> float:
	if not mech.slots.has(key) or mech.slots[key].uses_left == 0:
		return 0.0
	var def := mech.slots[key].def
	if not def.deals_damage():
		return 0.0
	var damage := (def.dmg_min + def.dmg_max) / 2.0
	if def.element != ItemDef.Element.COMBINED:
		damage = maxf(1.0, damage - target.res[def.element])
	return damage / float(maxi(target.max_health, 1))


## Lo que pega el robot de asistencia al acabar el turno: el arma a la que
## le toca (dispara una por turno y las alterna).
func _assist_strike(mech: BattleMech, target: BattleMech) -> float:
	return _slot_strike(mech, target, mech.assist_order()[0])


## Cuanta energia le falta a un mech para disparar sus dos armas mas caras,
## de 0 (le sobra) a 1 (no puede disparar nada).
func _energy_starvation(mech: BattleMech, enemy: BattleMech, before_enemy_turn: bool) -> float:
	var costs: Array[int] = []
	for key in mech.weapon_keys():
		var slot := mech.slots[key]
		if slot.uses_left != 0 and slot.def.energy_cost > 0:
			costs.append(mech.energy_cost(slot.def))
	if costs.is_empty():
		return 0.0
	costs.sort()
	costs.reverse()
	var need := costs[0] + (costs[1] if costs.size() > 1 else 0)
	var available := mech.energy
	if before_enemy_turn:
		# Antes de volver a jugar recibe el drenaje del rival y luego regenera.
		available = maxi(0, available - _threat(enemy, "energy_dmg"))
		available = mini(mech.energy_cap, available + mech.energy_regen)
	return clampf(1.0 - float(available) / float(need), 0.0, 1.0)


## Lo maximo que un mech puede infligir de una estadistica en un turno: sus
## dos mejores armas con usos y el dron.
func _threat(mech: BattleMech, stat: String) -> int:
	var values: Array[int] = []
	for key in mech.weapon_keys():
		var slot := mech.slots[key]
		if slot.uses_left != 0:
			values.append(slot.def.get(stat))
	values.sort()
	values.reverse()
	var total := 0
	for i in mini(2, values.size()):
		total += values[i]
	# El asistente dispara una de sus dos armas: cuenta la que mas hace.
	var assist := 0
	for key: String in ["drone", "drone_low"]:
		if mech.slots.has(key) and mech.slots[key].uses_left != 0:
			assist = maxi(assist, mech.slots[key].def.get(stat))
	total += assist
	return total


## Fraccion (0 a 1) del mejor dano por turno de un mech que alcanza a esa
## distancia: sus dos mejores armas en alcance frente a sus dos mejores.
func _reach(mech: BattleMech, distance: int) -> float:
	var in_range: Array[int] = []
	var all: Array[int] = []
	for key in mech.weapon_keys():
		var slot := mech.slots[key]
		if slot.uses_left == 0:
			continue
		var def := slot.def
		var power := (def.dmg_min + def.dmg_max) / 2 + def.heat_dmg + def.energy_dmg
		all.append(power)
		if def.range_max == 0 or (distance >= def.range_min and distance <= def.range_max):
			in_range.append(power)
	if all.is_empty():
		return 0.0
	return float(_top_two(in_range)) / float(maxi(_top_two(all), 1))


func _top_two(values: Array[int]) -> int:
	values.sort()
	values.reverse()
	var total := 0
	for i in mini(2, values.size()):
		total += values[i]
	return total
