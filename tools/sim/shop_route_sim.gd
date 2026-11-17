extends SceneTree
## Mide la segunda via para vencer al jefe: juntar oro en la arena y comprar
## mejoras. Para cada nivel de la tienda (todas las mejoras a ese nivel) da
## las victorias del jugador contra el jefe, lo que cuesta y cuantos combates
## de arena ganados hacen falta para pagarlo.
##
## Uso (tras `++`):
##   --battles=N           combates por mech y nivel (por defecto 40)
##   --levels=0;2;4;6;8;10 niveles de tienda que se miden (separados por ;)
##   --boss=jefe_final     jefe
##   --tier=MYTHIC         clase de las piezas de los dos
##   --seed=1              semilla base
## Las bonificaciones de la arena estan encendidas y los dos juegan con la IA
## dificil. Se alterna quien empieza.

var _rules := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _builds: Dictionary[String, MechBuild] = {}


func _initialize() -> void:
	var args := _parse_args()
	var battles := int(args.get("battles", "40"))
	var seed_value := int(args.get("seed", "1"))
	var boss_id: String = args.get("boss", "jefe_final")
	var tier: ItemDef.Tier = ItemDef.Tier[args.get("tier", "MYTHIC")]
	var levels: Array[int] = []
	for text: String in str(args.get("levels", "0;2;4;6;8;10")).split(";"):
		levels.append(int(text))
	_rules.drops_enabled = true

	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var problems := catalog.errors + library.errors + chassis.errors + shop.errors
	if not problems.is_empty() or not library.specs.has(boss_id):
		printerr("datos con errores: ", problems)
		quit(2)
		return

	var top := _rules.tier_max_level[tier]
	_builds["boss"] = library.make(boss_id, catalog, _rules, tier, top, chassis)
	for level in levels:
		var bought := {}
		for track in shop.track_ids():
			bought[track] = level
		for id in library.ids():
			var build := library.make(id, catalog, _rules, tier, top)
			build.upgrades = shop.upgrades_for(bought)
			var key := "%s@%d" % [id, level]
			_builds[key] = build
			for n in battles:
				seed_value += 1
				_tasks.append(
					{"player": key, "id": id, "level": level, "seed": seed_value, "starter": n % 2}
				)
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	_report(levels, library, shop, battles)
	quit(0)


func _run_task(index: int) -> void:
	var task := _tasks[index]
	_results[index] = BattleRunner.run(
		_rules,
		_builds[task["player"]],
		_builds["boss"],
		BattleAI.new(BattleAI.Difficulty.HARD, task["seed"] * 2 + 1),
		BattleAI.new(BattleAI.Difficulty.HARD, task["seed"] * 2 + 2),
		task["seed"],
		task["starter"]
	)


func _report(levels: Array[int], library: BuildLibrary, shop: ArenaShop, battles: int) -> void:
	var wins := {}
	for index in _tasks.size():
		var task := _tasks[index]
		var key := "%s@%d" % [task["id"], task["level"]]
		wins[key] = wins.get(key, 0) + (1 if _results[index]["winner"] == 0 else 0)
	var ids := library.ids()
	var header := "  nivel   oro total  victorias de arena"
	for id in ids:
		header += "  %10s" % id.split("_")[0]
	print(
		(
			"Victorias del jugador contra el jefe segun el nivel de la tienda (%d combates por casilla):"
			% battles
		)
	)
	print(header + "     media")
	for level in levels:
		var cost := shop.total_cost(level)
		var line := (
			"  %5d  %10d  %18d" % [level, cost, ceili(float(cost) / maxf(shop.reward("win"), 1.0))]
		)
		var total := 0.0
		for id in ids:
			var rate: float = 100.0 * int(wins["%s@%d" % [id, level]]) / battles
			total += rate
			line += "  %8.1f %%" % rate
		print(line + "  %6.1f %%" % (total / ids.size()))


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var parts := text.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
