extends SceneTree
## Juega un solo combate IA contra IA e imprime cada evento con el estado de
## los dos mechs. Sirve para entender por que un mech gana o pierde.
##
## Uso (tras `++`): --a=<id> --b=<id> [--seed=1] [--starter=0] [--tier=DIVINE]
##                  [--level=40] [--difficulty=NORMAL] [--no-m2 --m5 --no-m6]


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var rules := RulesConfig.new()
	rules.m2_no_chain_shutdown = not args.has("no-m2")
	rules.m5_first_turn_single_action = args.has("m5")
	rules.m6_regen_at_turn_start = not args.has("no-m6")
	var tier: ItemDef.Tier = ItemDef.Tier[args.get("tier", "DIVINE")]
	var level := int(args.get("level", str(rules.tier_max_level[tier])))
	var difficulty: BattleAI.Difficulty = BattleAI.Difficulty[args.get("difficulty", "NORMAL")]
	var seed_value := int(args.get("seed", "1"))
	var starter := int(args.get("starter", "0"))

	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var ids := [args.get("a", ""), args.get("b", "")]
	for id: String in ids:
		if not library.specs.has(id):
			printerr("mech desconocido '%s'. Disponibles: %s" % [id, library.ids()])
			quit(2)
			return
	var builds: Array[MechBuild] = []
	for id: String in ids:
		builds.append(library.make(id, catalog, rules, tier, level))
		var s := builds[-1].summary(rules)
		print("%s: %s" % [id, s])

	var engine := BattleEngine.new(rules, builds[0], builds[1], seed_value, starter)
	var ais: Array[BattleAI] = [
		BattleAI.new(difficulty, seed_value * 2 + 1), BattleAI.new(difficulty, seed_value * 2 + 2)
	]
	var printed := 0
	while not engine.is_over() and engine.turn_number <= 200:
		var action := ais[engine.turn].choose_action(engine)
		if action == null or engine.apply(action) != "":
			break
		while printed < engine.events.size():
			_print_event(engine.events[printed], ids)
			printed += 1
	print(
		(
			"ganador: %s en %d turnos"
			% [ids[engine.winner] if engine.winner >= 0 else "nadie", engine.turn_number]
		)
	)
	quit(0)


func _print_event(entry: Dictionary, ids: Array) -> void:
	var detail := ""
	for key: String in entry:
		if not key in ["event", "turn", "actor", "state", "actions_left"]:
			detail += " %s=%s" % [key, entry[key]]
	var state := ""
	for i in 2:
		var m: Dictionary = entry["state"][i]
		state += (
			"  [%d] pos %d vida %d cal %d/%d ene %d/%d"
			% [i, m["pos"], m["health"], m["heat"], m["heat_cap"], m["energy"], m["energy_cap"]]
		)
	print(
		(
			"t%02d %-10s %-12s%-34s|%s"
			% [entry["turn"], str(ids[entry["actor"]]).substr(0, 10), entry["event"], detail, state]
		)
	)
