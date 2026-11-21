extends SceneTree
## Comprueba cuantas acciones tiene cada lado en el primer turno del combate
## (regla M5, OBS-034): juega el arranque con la pantalla de combate y con el
## motor solo, empezando el jugador y empezando el rival, y dice que hizo cada
## uno en su primer turno.


func _initialize() -> void:
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var a := library.make("fisico_vanguardia", catalog, rules, ItemDef.Tier.COMMON, 3)
	var b := library.make("calor_horno", catalog, rules, ItemDef.Tier.COMMON, 3)
	for seed_value: int in [2, 3]:
		var engine := BattleEngine.new(rules, a, b, seed_value, seed_value % 2)
		var ais: Array[BattleAI] = [
			BattleAI.new(BattleAI.Difficulty.NORMAL, 1), BattleAI.new(BattleAI.Difficulty.NORMAL, 2)
		]
		var opener := engine.turn
		var done := [[], []]
		var turns_seen := 0
		var last_turn := engine.turn_number
		while not engine.is_over() and turns_seen < 2:
			var who := engine.turn
			var action := ais[who].choose_action(engine)
			if action == null:
				break
			done[who].append(BattleAction.Type.keys()[action.type])
			engine.apply(action)
			if engine.turn_number != last_turn:
				last_turn = engine.turn_number
				turns_seen += 1
		print(
			(
				"empieza %s: %s hizo %s; luego %s hizo %s"
				% [
					"el jugador" if opener == 0 else "el rival",
					"jugador" if opener == 0 else "rival",
					done[opener],
					"rival" if opener == 0 else "jugador",
					done[1 - opener]
				]
			)
		)
	quit(0)
