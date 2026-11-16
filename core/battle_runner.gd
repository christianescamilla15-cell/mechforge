class_name BattleRunner
extends RefCounted
## Juega un combate completo entre dos IAs y resume lo que paso.
## Lo usan el simulador de balance y los tests de la IA.


## Devuelve {winner (-1 = empate por limite de turnos), turns, starter,
## margin (fraccion de vida que le queda al ganador), shutdowns [a, b],
## forced_cools [a, b], chained_shutdown, uses {id: veces}}.
static func run(
	rules: RulesConfig,
	build_a: MechBuild,
	build_b: MechBuild,
	ai_a: BattleAI,
	ai_b: BattleAI,
	seed_value: int,
	starter: int = 0,
	max_turns: int = 200
) -> Dictionary:
	var engine := BattleEngine.new(rules, build_a, build_b, seed_value, starter)
	var start_distance := absi(engine.mechs[0].position - engine.mechs[1].position)
	var ais: Array[BattleAI] = [ai_a, ai_b]
	while not engine.is_over() and engine.turn_number <= max_turns:
		var action := ais[engine.turn].choose_action(engine)
		if action == null or engine.apply(action) != "":
			break
	var summary := summarize(engine, starter)
	summary["start_distance"] = start_distance
	return summary


static func summarize(engine: BattleEngine, starter: int) -> Dictionary:
	var shutdowns := [0, 0]
	var forced := [0, 0]
	var last_shutdown := [-10, -10]
	var chained := false
	var uses := {}
	for entry in engine.events:
		var actor: int = entry["actor"]
		match entry["event"]:
			"shutdown":
				shutdowns[actor] += 1
				# El mismo mech vuelve a tener turno dos turnos despues.
				if entry["turn"] - last_shutdown[actor] == 2:
					chained = true
				last_shutdown[actor] = entry["turn"]
			"forced_cool":
				forced[actor] += 1
			"weapon", "stomp", "drone", "charge", "teleport", "hook":
				var id: String = entry.get("item", "")
				if id != "":
					uses[id] = uses.get(id, 0) + 1
	var margin := 0.0
	if engine.winner >= 0:
		var winner := engine.mechs[engine.winner]
		margin = float(maxi(winner.health, 0)) / float(maxi(winner.max_health, 1))
	return {
		"winner": engine.winner,
		"turns": engine.turn_number,
		"margin": margin,
		"starter": starter,
		"shutdowns": shutdowns,
		"forced_cools": forced,
		"chained_shutdown": chained,
		"uses": uses,
	}
