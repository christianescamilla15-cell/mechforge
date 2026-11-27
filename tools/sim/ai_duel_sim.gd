extends SceneTree
## Duelo de IAs (OBS-054): la IA "a" contra la "b" con los mismos robots, cada
## emparejamiento jugado dos veces cambiando de lado (misma semilla), asi que
## lo unico que cambia es como juega cada una. Con --edge, en la mitad de los
## emparejamientos un lado lleva ese plus de vida y dano (como los rivales de
## la racha), para ver como juega cada IA con ventaja y en desventaja.
##   Godot --headless --path . -s tools/sim/ai_duel_sim.gd ++
##     --a=MASTER --b=HARD     las dos IAs
##     --a-set=k=v,k=v         cambia valores del AIConfig de una (o --b-set)
##     --a-norace / --b-norace esa implacable no valora como una carrera
##     --band=laser            los robots de ese tipo de arma (o "all")
##     --tier=DIVINE --level=50   la clase y el nivel de sus piezas
##     --skills=14             puntos de entrenamiento de los dos
##     --edge=1.0              el plus del lado con ventaja (0 = sin ventaja)
##     --battles=2             semillas por emparejamiento
##     --part=0 --parts=1      reparte los emparejamientos entre procesos
##     --terrain               con el terreno de la arena (OBS-055)
##     --states                con los estados (OBS-055)
##     --ult                   con la definitiva (OBS-055)
## Ademas da, por robot, cuanto gana (para ver si un elemento sale ganando).

var _rules := RulesConfig.new()


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_rules.crits_enabled = true
	_rules.impact_enabled = true
	_rules.drops_enabled = true
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var skills := SkillTree.load_file("res://data/skills.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var tempers := TemperLibrary.load_file("res://data/tempers.json")
	var band := str(args.get("band", "laser"))
	var ids: Array[String] = library.ids() if band == "all" else library.band_ids(band)
	var tier: ItemDef.Tier = ItemDef.Tier[str(args.get("tier", "DIVINE"))]
	var level := int(args.get("level", "50"))
	var trained := skills.spread(int(args.get("skills", "14")))
	var edge := float(args.get("edge", "1.0"))
	var battles := int(args.get("battles", "2"))
	var part := int(args.get("part", "0"))
	var parts := int(args.get("parts", "1"))
	var a_level: BattleAI.Difficulty = BattleAI.Difficulty[str(args.get("a", "MASTER"))]
	var b_level: BattleAI.Difficulty = BattleAI.Difficulty[str(args.get("b", "HARD"))]
	var terrain: TerrainConfig = null
	if args.has("terrain"):
		terrain = TerrainConfig.load_file("res://data/terrain.json")
	var states: StateConfig = null
	if args.has("states"):
		states = StateConfig.load_file("res://data/states.json")
	var ultimate: UltimateConfig = null
	if args.has("ult"):
		ultimate = UltimateConfig.load_file("res://data/ultimate.json")
	var by_mech := {}
	# Cada emparejamiento: el robot del lado 0, el del lado 1 y quien lleva
	# el plus (-1 nadie).
	var pairings: Array[Array] = []
	for i in ids.size():
		for j in ids.size():
			pairings.append([i, j, -1])
			if edge > 0.0:
				pairings.append([i, j, 0])
	var tally := {"all": [0, 0], "ahead": [0, 0], "behind": [0, 0], "even": [0, 0]}
	var spent := 0
	var turns := 0
	var zone := campaign.zone_count() - 1
	for index in pairings.size():
		if index % parts != part:
			continue
		var pairing: Array = pairings[index]
		var builds: Array[MechBuild] = []
		for side in 2:
			var build := library.make(ids[pairing[side]], catalog, _rules, tier, level, chassis)
			var plus := edge if pairing[2] == side else 0.0
			build.upgrades = campaign.fight_upgrades(zone, shop, plus)
			build.skills = skills.effects_for(trained)
			builds.append(build)
		for n in battles:
			var seed_value := 101 + index * 31 + n * 7
			# Una vez con "a" en el lado 0 y otra con "a" en el lado 1.
			for a_side in 2:
				var ais: Array[BattleAI] = [null, null]
				for side in 2:
					var mine := side == a_side
					var temper := tempers.config(library.temper_of(ids[pairing[side]]))
					ais[side] = _ai(
						a_level if mine else b_level,
						seed_value + side,
						temper,
						args,
						"a" if mine else "b"
					)
				var started := Time.get_ticks_msec()
				var result := BattleRunner.run(
					_rules,
					builds[0],
					builds[1],
					ais[0],
					ais[1],
					seed_value,
					n % 2,
					200,
					terrain,
					states,
					ultimate
				)
				spent += Time.get_ticks_msec() - started
				turns += int(result["turns"])
				var won := 1 if result["winner"] == a_side else 0
				var kind := "even"
				if pairing[2] >= 0:
					kind = "ahead" if pairing[2] == a_side else "behind"
				for key: String in ["all", kind]:
					tally[key][0] += won
					tally[key][1] += 1
				# Por robot, en los emparejamientos parejos y de robots distintos.
				if pairing[2] < 0 and pairing[0] != pairing[1]:
					for side in 2:
						var id: String = ids[pairing[side]]
						var mine_won := 1 if result["winner"] == side else 0
						var row: Array = by_mech.get(id, [0, 0])
						by_mech[id] = [row[0] + mine_won, row[1] + 1]
	var line := "DUELO %s contra %s:" % [args.get("a", "MASTER"), args.get("b", "HARD")]
	for key: String in tally:
		line += " %s %d/%d" % [key, tally[key][0], tally[key][1]]
	print(line, " | %.0f ms por turno" % (float(spent) / maxf(1.0, float(turns))))
	for id: String in by_mech:
		print("ROBOT %s %d/%d" % [id, by_mech[id][0], by_mech[id][1]])
	quit(0)


## Una IA con los cambios de la linea de ordenes para ese lado ("a" o "b").
static func _ai(
	level: BattleAI.Difficulty, seed_value: int, temper: AIConfig, args: Dictionary, side: String
) -> BattleAI:
	var config: AIConfig = temper.duplicate() if temper != null else AIConfig.new()
	for pair in str(args.get(side + "-set", "")).split(",", false):
		var kv := pair.split("=")
		config.set(kv[0], type_convert(kv[1], typeof(config.get(kv[0]))))
	var ai := BattleAI.new(level, seed_value, config)
	if args.has(side + "-norace"):
		ai.race_eval = false
	if args.has(side + "-exact"):
		ai.exact_strike = true
	return ai
