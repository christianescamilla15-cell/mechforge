extends SceneTree
## Compara los chasis entre si: el mismo mech con un chasis contra el mismo
## mech con otro, IA contra IA, para ver si alguno gana siempre.
##
## Uso (tras `++`):
##   --battles=N      combates por cruce, mech y escala de vida (por defecto 6)
##   --tier=MYTHIC    clase de todas las piezas (Mitica es el techo normal)
##   --seed=1         semilla base
##   --chassis-level=N nivel de los chasis (por defecto el maximo)
## Promedia sobre las mismas escalas de vida que el simulador de balance y
## alterna quien empieza, por la misma razon (ver balance_sim.gd).

const HP_SCALES: Array[float] = [0.92, 0.96, 1.0, 1.04, 1.08]

var _rules := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _builds: Dictionary[String, MechBuild] = {}


func _initialize() -> void:
	var args := _parse_args()
	var tier: ItemDef.Tier = ItemDef.Tier[args.get("tier", "MYTHIC")]
	var battles := int(args.get("battles", "6"))
	var base_seed := int(args.get("seed", "1"))
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	if not (catalog.errors.is_empty() and library.errors.is_empty() and chassis.errors.is_empty()):
		printerr("datos con errores: ", catalog.errors, library.errors, chassis.errors)
		quit(2)
		return

	var level := _rules.tier_max_level[tier]
	var chassis_level := int(args.get("chassis-level", str(_rules.chassis_max_level)))
	for id in library.ids():
		for chassis_id in chassis.ids():
			for s in HP_SCALES.size():
				var build := library.make(id, catalog, _rules, tier, level)
				for item in build.all_items():
					item.health = roundi(item.health * HP_SCALES[s])
				build.chassis = chassis.get_def(chassis_id).at_level(chassis_level, _rules)
				_builds["%s/%s@%d" % [id, chassis_id, s]] = build

	var ids := chassis.ids()
	var seed_value := base_seed
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			for build_id in library.ids():
				for s in HP_SCALES.size():
					for n in battles:
						seed_value += 1
						(
							_tasks
							. append(
								{
									"a": "%s/%s@%d" % [build_id, ids[i], s],
									"b": "%s/%s@%d" % [build_id, ids[j], s],
									"pair": "%s vs %s" % [ids[i], ids[j]],
									"build": build_id,
									"seed": seed_value,
									"starter": n % 2,
								}
							)
						)
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	_report(tier, battles)
	quit(0)


func _run_task(index: int) -> void:
	var task := _tasks[index]
	_results[index] = BattleRunner.run(
		_rules,
		_builds[task["a"]],
		_builds[task["b"]],
		BattleAI.new(BattleAI.Difficulty.NORMAL, task["seed"] * 2 + 1),
		BattleAI.new(BattleAI.Difficulty.NORMAL, task["seed"] * 2 + 2),
		task["seed"],
		task["starter"]
	)


func _report(tier: ItemDef.Tier, battles: int) -> void:
	print(
		"Chasis contra chasis, clase %s, %d combates" % [ItemDef.Tier.keys()[tier], _tasks.size()]
	)
	var by_pair: Dictionary[String, Array] = {}
	var by_pair_build: Dictionary[String, Array] = {}
	for index in _tasks.size():
		var task := _tasks[index]
		var winner: int = _results[index]["winner"]
		for key: String in [task["pair"], "%s | %s" % [task["pair"], task["build"]]]:
			var table := by_pair if key == task["pair"] else by_pair_build
			if not table.has(key):
				table[key] = [0, 0, 0, 0.0]
			table[key][0] += 1
			if winner == 0:
				table[key][1] += 1
			elif winner == 1:
				table[key][2] += 1
			table[key][3] += _results[index]["turns"]
	for key in by_pair:
		var row: Array = by_pair[key]
		print(
			(
				"  %-18s gana el primero %5.1f %%, el segundo %5.1f %%, %4.1f turnos"
				% [key, 100.0 * row[1] / row[0], 100.0 * row[2] / row[0], row[3] / row[0]]
			)
		)
	print("Por mech:")
	for key in by_pair_build:
		var row: Array = by_pair_build[key]
		print("  %-40s primero %5.1f %%" % [key, 100.0 * row[1] / row[0]])
	print("(%d combates por cruce, mech y escala de vida)" % battles)


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var parts := text.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
