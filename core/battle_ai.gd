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
		if difficulty == Difficulty.EASY:
			best_score += _rng.randf_range(-config.easy_noise, config.easy_noise)
		candidates.append(
			{"action": first, "score": best_score, "state": best_state, "order": candidates.size()}
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

	var score := _ratio(mine.health, mine.max_health) - _ratio(foe.health, foe.max_health)

	# Acciones que el calor ya le quito al rival en el turno que empieza.
	if e.turn == me:
		score += foe_strike * per_turn + _slot_strike(foe, mine, "drone")
	else:
		score += foe_strike * (per_turn - e.actions_left)

	# Calor pendiente: cada `enfriamiento` de calor costara una accion. Enfriar
	# antes de tiempo no ahorra nada, asi que no se penaliza el riesgo de un
	# enfriado forzado: solo el calor acumulado.
	score += config.heat_discount * foe_strike * _ratio(foe.heat, foe.cooling)
	score -= config.heat_discount * my_strike * _ratio(mine.heat, mine.cooling)

	score += config.energy_discount * foe_strike * per_turn * _energy_starvation(foe, mine, false)
	score -= config.energy_discount * my_strike * per_turn * _energy_starvation(mine, foe, true)

	var distance := absi(mine.position - foe.position)
	score -= config.position_discount * my_strike * (1.0 - _reach(mine, distance))
	score += config.position_discount * foe_strike * (1.0 - _reach(foe, distance))
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
			value = _worst_reply_value(state, me)
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


func _turn_ended(after: BattleEngine, before: BattleEngine) -> bool:
	return after.is_over() or after.turn_number != before.turn_number


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


## Cuanta energia le falta a un mech para disparar sus dos armas mas caras,
## de 0 (le sobra) a 1 (no puede disparar nada).
func _energy_starvation(mech: BattleMech, enemy: BattleMech, before_enemy_turn: bool) -> float:
	var costs: Array[int] = []
	for key in mech.weapon_keys():
		var slot := mech.slots[key]
		if slot.uses_left != 0 and slot.def.energy_cost > 0:
			costs.append(slot.def.energy_cost)
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
	if mech.slots.has("drone") and mech.slots["drone"].uses_left != 0:
		total += mech.slots["drone"].def.get(stat)
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
