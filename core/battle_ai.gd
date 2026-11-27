class_name BattleAI
extends RefCounted
## IA por utilidad (GDD 7): prueba cada secuencia legal del turno en una copia
## del combate, valora el estado resultante y devuelve la primera accion de la
## mejor. Sirve para los enemigos de la campana y para el simulador de balance.
## La implacable (OBS-054) piensa un turno mas que la dificil y mide los golpes
## como el motor.

enum Difficulty { RANDOM, EASY, NORMAL, HARD, MASTER }

var difficulty: Difficulty
var config: AIConfig
## Valora los golpes con el dano que hace el motor (potencia, criticos,
## perforacion, asistente) y no con el de la pieza. Por defecto, solo la
## implacable: las demas siguen como se calibraron.
var exact_strike: bool
## Valora como una carrera: cada barra de vida vale lo que tarda el otro en
## vaciarla (con exact_strike). Por defecto, solo la implacable.
var race_eval: bool

var _rng := RandomNumberGenerator.new()
## Con exact_strike: lo que quita cada hueco de cada lado ([lado][hueco]),
## medido una vez al empezar a pensar la jugada (el motor tarda en medirlo).
var _hits: Array[Dictionary] = []
## Con race_eval: lo que vale cada punto de la barra de cada lado ([lado]),
## medido al empezar a pensar la jugada.
var _bar_worth: Array[float] = [1.0, 1.0]


func _init(
	p_difficulty: Difficulty = Difficulty.NORMAL, seed_value: int = 0, p_config: AIConfig = null
) -> void:
	difficulty = p_difficulty
	config = p_config if p_config else AIConfig.new()
	exact_strike = difficulty == Difficulty.MASTER
	race_eval = exact_strike
	_rng.seed = seed_value


## Devuelve la accion a ejecutar ahora, o null si no hay ninguna legal.
func choose_action(engine: BattleEngine) -> BattleAction:
	var actions := engine.legal_actions()
	if actions.is_empty():
		return null
	if difficulty == Difficulty.RANDOM:
		return actions[_rng.randi_range(0, actions.size() - 1)]

	var me := engine.turn
	_hits.clear()
	if exact_strike:
		_hits = _measure_hits(engine)
	_bar_worth = [1.0, 1.0]
	if race_eval and exact_strike:
		_bar_worth = _measure_bars(engine)
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
	if difficulty == Difficulty.MASTER:
		return _best_two_turns(candidates, me)
	return candidates[0]["action"]


## Valor del estado para el jugador `me`. Positivo es bueno para el.
func evaluate(e: BattleEngine, me: int) -> float:
	if e.is_over():
		return config.win_value if e.winner == me else -config.win_value
	if race_eval and not _hits.is_empty():
		return _race_value(e, me)
	var mine := e.mechs[me]
	var foe := e.mechs[1 - me]
	# Lo que vale una accion de cada uno, en fraccion de la vida del otro.
	var my_strike := _strike(mine, foe, me)
	var foe_strike := _strike(foe, mine, 1 - me)
	var per_turn := float(e.rules.actions_per_turn)

	# El temperamento (AIConfig): cuanto pesa cada cosa para este rival.
	var score := (
		# Con el manto de plasma (OBS-041): la vida que le queda contandolo.
		config.guard * _ratio(mine.toughness(), mine.max_toughness())
		- config.aggression * _ratio(foe.toughness(), foe.max_toughness())
	)

	# Acciones que el calor ya le quito al rival en el turno que empieza.
	if e.turn == me:
		score += config.pressure * (foe_strike * per_turn + _assist_strike(foe, mine, 1 - me))
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
	# El terreno en el que esta cada uno (OBS-055).
	var my_cell := _cell_terms(e, mine, my_strike, foe_strike)
	var foe_cell := _cell_terms(e, foe, foe_strike, my_strike)
	score += config.guard * my_cell.x - config.caution * my_cell.y
	score += config.pressure * foe_cell.y - config.aggression * foe_cell.x
	return score


## Lo que vale la casilla en la que esta `mech` (OBS-055, TerrainConfig), en
## fracciones de barra: x, lo que gana su barra (la reparacion de un turno y
## la cobertura frente a la mitad de lo que pega el otro); y, lo que se ahorra
## la del otro (las acciones que la lava le costara). `strike` es lo que pega
## una accion suya; `against`, una del otro.
func _cell_terms(e: BattleEngine, mech: BattleMech, strike: float, against: float) -> Vector2:
	var config_t := e.terrain_config
	match e.terrain_at(mech.position):
		"repair":
			return Vector2(config_t.value("repair", "heal"), 0.0)
		"cover":
			var per_turn := float(e.rules.actions_per_turn)
			return Vector2(config_t.value("cover", "cut") * against * per_turn * 0.5, 0.0)
		"lava":
			var heat := mech.heat_cap * config_t.value("lava", "heat")
			return Vector2(0.0, config.heat_discount * strike * heat / maxf(1.0, mech.cooling))
	return Vector2.ZERO


## Implacable (OBS-054): lo mismo que evaluate, pero como una carrera. Cada
## cosa se cuenta en la barra en la que pesa (la suya o la del rival), y cada
## barra vale lo que tarda el otro en vaciarla: contra un rival con mucha vida
## y que pega fuerte, quitarle un 10 % vale mas que guardarse un 10 % propio.
func _race_value(e: BattleEngine, me: int) -> float:
	var mine := e.mechs[me]
	var foe := e.mechs[1 - me]
	var my_strike := _strike(mine, foe, me)
	var foe_strike := _strike(foe, mine, 1 - me)
	var per_turn := float(e.rules.actions_per_turn)
	var distance := absi(mine.position - foe.position)
	# Lo que pesa en su barra: lo que le queda y lo que el rival no le quitara.
	var my_bar := config.guard * _ratio(mine.toughness(), mine.max_toughness())
	if e.turn == me:
		my_bar += config.pressure * (foe_strike * per_turn + _assist_strike(foe, mine, 1 - me))
	else:
		my_bar += config.pressure * foe_strike * (per_turn - e.actions_left)
	my_bar += (config.pressure * config.heat_discount * foe_strike * _ratio(foe.heat, foe.cooling))
	my_bar += (
		config.pressure
		* config.energy_discount
		* foe_strike
		* per_turn
		* _energy_starvation(foe, mine, false)
	)
	my_bar += config.barrier_value * foe_strike * mine.barrier
	my_bar += config.repair_hold * _repair_worth(mine)
	my_bar += config.evasion * config.position_discount * foe_strike * (1.0 - _reach(foe, distance))
	# Lo que pesa en la del rival: lo que le queda y lo que el no le quitara.
	var foe_bar := config.aggression * _ratio(foe.toughness(), foe.max_toughness())
	foe_bar += config.caution * config.heat_discount * my_strike * _ratio(mine.heat, mine.cooling)
	foe_bar += (
		config.caution
		* config.energy_discount
		* my_strike
		* per_turn
		* _energy_starvation(mine, foe, true)
	)
	foe_bar += config.barrier_value * my_strike * foe.barrier
	foe_bar += config.repair_hold * _repair_worth(foe)
	foe_bar += config.position_discount * my_strike * (1.0 - _reach(mine, distance))
	var my_cell := _cell_terms(e, mine, my_strike, foe_strike)
	var foe_cell := _cell_terms(e, foe, foe_strike, my_strike)
	my_bar += config.guard * my_cell.x + config.pressure * foe_cell.y
	foe_bar += config.aggression * foe_cell.x + config.caution * my_cell.y
	var buffs := config.buff_turn_value * (_buff_worth(mine) - _buff_worth(foe))
	return my_bar * _bar_worth[me] - foe_bar * _bar_worth[1 - me] + buffs


## Lo que vale la barra de cada lado: lo que tarda el otro en vaciarla (con
## sus golpes por turno y su asistente), sobre la media de los dos, entre
## bar_worth_min y bar_worth_max.
func _measure_bars(engine: BattleEngine) -> Array[float]:
	var per_turn := float(engine.rules.actions_per_turn)
	var rates: Array[float] = []
	for side in 2:
		var mech := engine.mechs[side]
		var target := engine.mechs[1 - side]
		rates.append(
			maxf(0.001, _strike(mech, target, side) * per_turn + _assist_strike(mech, target, side))
		)
	var mean := (rates[0] + rates[1]) / 2.0
	var out: Array[float] = []
	for side in 2:
		out.append(clampf(mean / rates[1 - side], config.bar_worth_min, config.bar_worth_max))
	return out


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


## Implacable (OBS-054): entre sus mejores jugadas, la que deja mejor parado
## despues de las respuestas del rival que peor le dejan y de su mejor turno
## tras cada una. Es la dificil con un turno mas.
func _best_two_turns(candidates: Array[Dictionary], me: int) -> BattleAction:
	var best_action: BattleAction = candidates[0]["action"]
	var best_value := -INF
	for i in mini(config.master_candidates, candidates.size()):
		var state: BattleEngine = candidates[i]["state"]
		var value: float = candidates[i]["score"]
		if not state.is_over() and state.turn != me:
			value = _deep_reply_value(state, me) + float(candidates[i]["taste"])
		if value > best_value:
			best_value = value
			best_action = candidates[i]["action"]
	return best_action


## Lo que le queda a `me` tras la respuesta del rival: de las que a primera
## vista peor le dejan, la peor despues de su mejor turno siguiente.
func _deep_reply_value(state: BattleEngine, me: int) -> float:
	var replies: Array[Dictionary] = []
	for line in _turn_ends(state, me, config.master_width):
		replies.append({"value": evaluate(line, me), "state": line})
	replies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["value"] < b["value"])
	var worst := INF
	for i in mini(config.master_replies, replies.size()):
		var after: BattleEngine = replies[i]["state"]
		var value: float = replies[i]["value"]
		if not after.is_over() and after.turn == me:
			value = -INF
			for line in _turn_ends(after, me, config.master_width):
				value = maxf(value, evaluate(line, me))
		worst = minf(worst, value)
	return worst


## Las formas de jugar el turno que empieza en `state` (hasta dos acciones),
## con el estado al acabar. Con `width` > 0 solo sigue con la segunda accion
## las `width` primeras que mejor dejan a quien juega (vistas desde `me`).
func _turn_ends(state: BattleEngine, me: int, width: int = 0) -> Array[BattleEngine]:
	var out: Array[BattleEngine] = []
	var open: Array[Dictionary] = []
	var sign := 1.0 if state.turn == me else -1.0
	for first in state.legal_actions():
		var after_first := state.clone()
		after_first.apply(first)
		if _turn_ended(after_first, state):
			out.append(after_first)
		else:
			open.append({"state": after_first, "value": sign * evaluate(after_first, me)})
	if width > 0 and open.size() > width:
		open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["value"] > b["value"])
		open.resize(width)
	for line in open:
		var after_first: BattleEngine = line["state"]
		for second in after_first.legal_actions():
			var after_second := after_first.clone()
			after_second.apply(second)
			out.append(after_second)
	return out


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
## `side`: el lado de `mech` (0 o 1).
func _strike(mech: BattleMech, target: BattleMech, side: int) -> float:
	var hits: Array[float] = []
	for key in mech.weapon_keys():
		if mech.slots[key].uses_left != 0:
			hits.append(_slot_strike(mech, target, key, side))
	if hits.is_empty():
		return _slot_strike(mech, target, "legs", side)
	hits.sort()
	hits.reverse()
	var count := mini(2, hits.size())
	var total := 0.0
	for i in count:
		total += hits[i]
	return total / count


## Fraccion de la vida de `target` que quita de media la pieza de ese hueco.
func _slot_strike(mech: BattleMech, target: BattleMech, key: String, side: int) -> float:
	if not mech.slots.has(key) or mech.slots[key].uses_left == 0:
		return 0.0
	var def := mech.slots[key].def
	if not def.deals_damage():
		return 0.0
	if not _hits.is_empty():
		return float(_hits[side].get(key, 0.0)) / float(maxi(target.max_health, 1))
	var damage := (def.dmg_min + def.dmg_max) / 2.0
	if def.element != ItemDef.Element.COMBINED:
		damage = maxf(1.0, damage - target.res[def.element])
	return damage / float(maxi(target.max_health, 1))


## Lo que pega el robot de asistencia al acabar el turno: el arma a la que
## le toca (dispara una por turno y las alterna).
func _assist_strike(mech: BattleMech, target: BattleMech, side: int) -> float:
	return _slot_strike(mech, target, mech.assist_order()[0], side)


## Lo que quita de media cada hueco de cada lado al otro, con el motor
## (BattleEngine.expected_hit): [{hueco: dano}, {hueco: dano}].
func _measure_hits(engine: BattleEngine) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{}, {}]
	for side in 2:
		var mech := engine.mechs[side]
		var target := engine.mechs[1 - side]
		for key: String in mech.slots:
			out[side][key] = engine.expected_hit(mech, target, key)
	return out


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
