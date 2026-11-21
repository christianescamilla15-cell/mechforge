extends SceneTree
## Juega un solo combate de un tipo de robot inicial contra un rival de la
## arena con su mismo equipo, e imprime cada evento. Para entender por que un
## tipo gana o pierde (los numeros los da starter_sim.gd).
##
## Uso (tras `++`): --style=tirador [--stage=3] [--rival=0] [--seed=1]
##                  [--starter=0] [--difficulty=NORMAL]

const Sim := preload("res://tools/sim/starter_sim.gd")


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var rules := RulesConfig.new()
	rules.drops_enabled = true
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var styles := StyleLibrary.load_file("res://data/styles.json", catalog)
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var style_id := str(args.get("style", "tirador"))
	var stage := int(args.get("stage", "3"))
	var seed_value := int(args.get("seed", "1"))
	var difficulty: BattleAI.Difficulty = BattleAI.Difficulty[args.get("difficulty", "NORMAL")]
	if not styles.has(style_id):
		printerr("tipo desconocido '%s'. Hay: %s" % [style_id, styles.ids()])
		quit(2)
		return

	var player := Sim.player_build(styles, catalog, rules, style_id, stage)
	var rival_ids := library.band_ids(campaign.band_of(0))
	var rival_id: String = rival_ids[int(args.get("rival", "0")) % rival_ids.size()]
	var gear := Campaign.loadout_of(player)
	var rival := library.make(rival_id, catalog, rules, ItemDef.Tier.COMMON, 0, null, {}, gear)
	var names := [style_id, rival_id]
	for build: MechBuild in [player, rival]:
		var weapons: Array[String] = []
		for item in build.sides + build.tops:
			if item != null:
				weapons.append("%s [%d-%d]" % [item.id, item.range_min, item.range_max])
		print("%s: %s" % [build.summary(rules), ", ".join(weapons)])

	var engine := BattleEngine.new(rules, player, rival, seed_value, int(args.get("starter", "0")))
	var ais: Array[BattleAI] = [
		BattleAI.new(difficulty, seed_value * 2 + 1), BattleAI.new(difficulty, seed_value * 2 + 2)
	]
	var printed := 0
	while not engine.is_over() and engine.turn_number <= 200:
		var action := ais[engine.turn].choose_action(engine)
		if action == null or engine.apply(action) != "":
			break
		while printed < engine.events.size():
			_print_event(engine.events[printed], names)
			printed += 1
	print(
		(
			"ganador: %s en %d turnos"
			% [names[engine.winner] if engine.winner >= 0 else "nadie", engine.turn_number]
		)
	)
	quit(0)


func _print_event(entry: Dictionary, names: Array) -> void:
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
			"t%02d %-10s %-12s%-40s|%s"
			% [
				entry["turn"],
				str(names[entry["actor"]]).substr(0, 10),
				entry["event"],
				detail,
				state
			]
		)
	)
