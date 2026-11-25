extends SceneTree
## La racha de la arena (OBS-049): tu robot guardado, armado como lo arma el
## juego, contra el rival de cada combate de una racha (Campaign.
## arena_streak_fight) con varias semillas, como en el juego. Da cuanto se
## gana cada paso, la probabilidad de llegar a cada bote y lo que vale de
## media seguir en cada punto. Solo lee el guardado.
##   Godot --headless --path . -s tools/sim/arena_streak_sim.gd ++
##     --save=<ruta>      el guardado (por defecto user://save.json)
##     --zone=N           otra liga (por defecto la suya)
##     --rivals=12        rivales (semillas) por paso
##     --battles=6        combates contra cada uno
##     --player=HARD      dificultad de la IA que hace de jugador
##     --only=N           solo el combate N de la racha (0 es el primero)
##     --campaign=<ruta>  otro campaign.json (para probar una rampa sin tocar
##                        los datos del juego)

const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
}

var _rules := RulesConfig.new()


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var path := str(args.get("save", "user://save.json"))
	var rivals := int(args.get("rivals", "12"))
	var battles := int(args.get("battles", "6"))
	var player_ai: BattleAI.Difficulty = DIFFICULTY[str(args.get("player", "HARD"))]
	var only := int(args.get("only", "-1"))
	_rules.crits_enabled = true
	_rules.impact_enabled = true
	_rules.drops_enabled = true
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var campaign := Campaign.load_file(
		str(args.get("campaign", "res://data/campaign.json")), library
	)
	var skills := SkillTree.load_file("res://data/skills.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var tempers := TemperLibrary.load_file("res://data/tempers.json")
	var brief := WorkshopBrief.new()
	brief.rules = _rules
	brief.catalog = catalog
	brief.library = library
	brief.campaign = campaign
	brief.skills = skills
	brief.shop = shop
	brief.progression = Progression.load_file("res://data/progression.json")
	brief.styles = StyleLibrary.load_file("res://data/styles.json", catalog)
	brief.workshop = Workshop.load_file("res://data/workshop.json")
	brief.garage = Garage.load_file("res://data/part_shop.json")
	if not campaign.errors.is_empty():
		print("ERRORES en campaign.json: ", campaign.errors)
		quit(1)
		return

	var profile := PlayerProfile.load_or_new(path)
	var zone := mini(int(args.get("zone", str(profile.zone))), campaign.zone_count() - 1)
	var build := brief.build_of(profile, profile.build)
	# El poder del jugador, como lo mide el juego (MainScreen._player_items).
	var items: Array[String] = []
	var carried := profile.build.has("assist")
	for id in BuildLibrary.items_of(profile.build):
		var def := catalog.get_item(id)
		if def == null or (carried and def.type == ItemDef.Type.DRONE):
			continue
		if not def.progress_id() in items:
			items.append(def.progress_id())
	var power := Campaign.mean_power(_rules, profile, items)
	var gear := Campaign.loadout_of(build)
	var mult := campaign.reward_mult(zone)
	var base := shop.reward("arena_win") * mult
	print(
		(
			"Liga %d, tu %s (poder medio %.0f), %d rivales x %d combates por paso"
			% [zone + 1, profile.style, power, rivals, battles]
		)
	)
	var reach := 1.0
	var pot := 0.0
	var rows: Array[Dictionary] = []
	for step in campaign.streak_fights():
		if only >= 0 and step != only:
			continue
		var wins := 0
		var total := 0
		var seen := {}
		for r in rivals:
			var seed_value := 1000 + r * 7919
			var fight := campaign.arena_streak_fight(
				zone, library, seed_value, _rules, power, gear, step
			)
			var rival := library.make(
				fight["enemy"],
				catalog,
				_rules,
				fight["tier"],
				fight["level"],
				chassis,
				{},
				fight.get("loadout", {})
			)
			rival.upgrades = campaign.fight_upgrades(zone, shop, float(fight.get("edge", 0.0)))
			rival.skills = skills.effects_for(skills.spread(int(fight.get("skills", 0))))
			rival.skills.add(Campaign.kits_of(fight))
			var rival_ai: BattleAI.Difficulty = BattleAI.Difficulty[str(fight["difficulty"])]
			var temper := tempers.config(library.temper_of(fight["enemy"]))
			seen["%s %d" % [Txt.TIER_NAMES[fight["tier"]], fight["level"]]] = true
			for n in battles:
				var result := BattleRunner.run(
					_rules,
					build,
					rival,
					BattleAI.new(player_ai, n * 2 + 1 + r * 31),
					BattleAI.new(rival_ai, n * 2 + 2 + r * 31, temper),
					n + 7 + r * 13,
					n % 2
				)
				wins += 1 if result["winner"] == 0 else 0
				total += 1
		var rate := float(wins) / total
		var prize := base * campaign.streak_prize(step)
		var sample: Dictionary = campaign.arena_streak_fight(
			zone, library, 1000, _rules, power, gear, step
		)
		rows.append({"rate": rate, "prize": prize, "pot_before": pot})
		reach *= rate
		pot += prize
		print(
			(
				(
					"  combate %d: ganas %3.0f %%  premio %6.0f  bote si ganas %6.0f  llegas %4.1f %%"
					% [step + 1, 100.0 * rate, prize, pot, 100.0 * reach]
				)
				+ (
					"   rival: %s, IA %s, entrenamiento %d, plus %d %%"
					% [
						", ".join(PackedStringArray(seen.keys())),
						sample["difficulty"],
						int(sample.get("skills", 0)),
						roundi(100.0 * float(sample.get("edge", 0.0)))
					]
				)
			)
		)
	# Lo que vale seguir: con el bote B tras ganar el combate k, pedir el
	# siguiente da de media p * (B + premio); cobrar da B.
	print("  Seguir o cobrar (media de seguir solo un combate mas):")
	for k in range(1, rows.size()):
		var before: float = rows[k]["pot_before"]
		var keep: float = rows[k]["rate"] * (before + rows[k]["prize"])
		print(
			(
				"    con bote %6.0f: cobrar %6.0f, otro combate %6.0f de media (%s)"
				% [before, before, keep, "conviene" if keep > before else "no conviene"]
			)
		)
	quit(0)
