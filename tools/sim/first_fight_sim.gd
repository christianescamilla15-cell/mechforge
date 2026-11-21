extends SceneTree
## El primer combate de la campana, con cada tipo de robot inicial y su unica
## arma, contra el primer rival con cada una de sus armas: para elegir con
## cual sale (OBS-034: sin la regla del primer turno de una accion, quien
## abre pega antes). IA normal contra la del rival.
##   Godot --headless --path . -s tools/sim/first_fight_sim.gd ++ --battles=40


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var battles := int(args.get("battles", "40"))
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var styles := StyleLibrary.load_file("res://data/styles.json", catalog)
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var tempers := TemperLibrary.load_file("res://data/tempers.json")
	var spec := campaign.fight_at(0, 0)
	# --enemy=<id>: probar otro rival en el primer combate.
	var enemy := str(args.get("enemy", spec["enemy"]))
	var difficulty: int = BattleAI.Difficulty[str(spec["difficulty"])]
	var sides: Array = library.specs[enemy]["items"].get("sides", [])
	print("Primer combate: %s, nivel %d, %s" % [enemy, spec["level"], spec["difficulty"]])
	for shift in sides.size():
		var gear := {"sides": 1, "shift": shift}
		var rival := library.make(
			enemy, catalog, rules, ItemDef.Tier.COMMON, int(spec["level"]), null, {}, gear
		)
		var line := "  rival con %-20s" % str(rival.sides[0].id)
		for style_id in styles.ids():
			var player := catalog.make_build(styles.build(style_id), rules, ItemDef.Tier.COMMON, 0)
			player.skills = SkillSet.new()
			styles.add_effects(style_id, player.skills)
			var wins := 0
			for n in battles:
				var result := BattleRunner.run(
					rules,
					player,
					rival,
					BattleAI.new(BattleAI.Difficulty.NORMAL, n * 2 + 1),
					BattleAI.new(difficulty, n * 2 + 2, tempers.config(library.temper_of(enemy))),
					n + 1,
					n % 2
				)
				wins += 1 if result["winner"] == 0 else 0
			line += "   %s %3.0f %%" % [style_id, 100.0 * wins / battles]
		print(line)
	quit(0)
