extends SceneTree
## Mide a todos los jefes (GDD 9.1) con la misma vara: cada mech normal contra
## cada jefe, todos en la misma clase y a su nivel maximo, con bonificaciones
## y la IA dificil en los dos lados. Se mide sin mejoras de armeria y con la
## armeria a los niveles que se pidan (todas las mejoras a la par).
## Sirve para ver que cada jefe es muy dificil pero vencible, y que su punto
## debil existe: algun mech le gana bastante mas que los otros.
##
## Uso (tras `++`):
##   --battles=N      combates por casilla (por defecto 20)
##   --tier=COMMON    clase de las piezas de todos
##   --levels=0;6     niveles de armeria del jugador (separados por ;)
##   --bosses=a;b     solo esos jefes (por defecto, todos)
##   --seed=1         semilla base
## Se alterna quien empieza.

var _rules := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _builds: Dictionary[String, MechBuild] = {}


func _initialize() -> void:
	var args := _parse_args()
	var battles := int(args.get("battles", "20"))
	var seed_value := int(args.get("seed", "1"))
	var tier: ItemDef.Tier = ItemDef.Tier[args.get("tier", "COMMON")]
	var levels: Array[int] = []
	for text: String in str(args.get("levels", "0;6")).split(";"):
		levels.append(int(text))
	_rules.drops_enabled = true

	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var problems := catalog.errors + library.errors + chassis.errors + shop.errors
	if not problems.is_empty():
		printerr("datos con errores: ", problems)
		quit(2)
		return
	var bosses := library.boss_ids()
	if args.has("bosses"):
		bosses.assign(str(args["bosses"]).split(";"))

	var top := _rules.tier_max_level[tier]
	for boss_id in bosses:
		_builds[boss_id] = library.make(boss_id, catalog, _rules, tier, top, chassis)
	for level in levels:
		var bought := {}
		for track in shop.track_ids():
			bought[track] = level
		for boss_id in bosses:
			for id in library.band_ids(library.band_of(boss_id)):
				var key := "%s@%d" % [id, level]
				if not _builds.has(key):
					_builds[key] = library.make(id, catalog, _rules, tier, top)
					_builds[key].upgrades = shop.upgrades_for(bought)
				for n in battles:
					seed_value += 1
					(
						_tasks
						. append(
							{
								"player": key,
								"boss": boss_id,
								"id": id,
								"level": level,
								"seed": seed_value,
								"starter": n % 2,
							}
						)
					)
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	_report(bosses, levels, library, chassis, battles, tier)
	quit(0)


func _run_task(index: int) -> void:
	var task := _tasks[index]
	_results[index] = BattleRunner.run(
		_rules,
		_builds[task["player"]],
		_builds[task["boss"]],
		BattleAI.new(BattleAI.Difficulty.HARD, task["seed"] * 2 + 1),
		BattleAI.new(BattleAI.Difficulty.HARD, task["seed"] * 2 + 2),
		task["seed"],
		task["starter"]
	)


func _report(
	bosses: Array[String],
	levels: Array[int],
	library: BuildLibrary,
	chassis: ChassisLibrary,
	battles: int,
	tier: ItemDef.Tier
) -> void:
	var wins := {}
	var draws := 0
	for index in _tasks.size():
		var task := _tasks[index]
		var key := "%s|%s@%d" % [task["boss"], task["id"], task["level"]]
		var winner := int(_results[index]["winner"])
		wins[key] = wins.get(key, 0) + (1 if winner == 0 else 0)
		if winner < 0:
			draws += 1
	var ids := library.starter_ids()
	print(
		(
			"Victorias del jugador contra cada jefe (clase %s al maximo, %d combates por casilla)"
			% [ItemDef.Tier.keys()[tier], battles]
		)
	)
	var header := "  %-20s %-26s armeria" % ["jefe", "habilidad"]
	for id in ids:
		header += "  %8s" % id.split("_")[0]
	print(header + "    media")
	for boss_id in bosses:
		var ability := chassis.get_def(library.chassis_of(boss_id)).ability
		for level in levels:
			var line := "  %-20s %-26s %7d" % [library.display_name(boss_id), ability, level]
			var total := 0.0
			for id in library.band_ids(library.band_of(boss_id)):
				var rate: float = 100.0 * int(wins["%s|%s@%d" % [boss_id, id, level]]) / battles
				total += rate
				line += "  %6.1f %%" % rate
			print(line + "  %5.1f %%" % (total / ids.size()))
	print("Empates por limite de turnos: %d de %d" % [draws, _tasks.size()])


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var parts := text.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
