extends SceneTree
## Mide lo dificil que es un jefe: cada mech normal contra el jefe, IA contra
## IA, con y sin bonificaciones y con el equipo del jugador a varias clases.
## Sirve para comprobar que el jefe es muy dificil pero vencible con tactica,
## y cuanto ayuda llegar con mejor equipo.
##
## Uso (tras `++`):
##   --battles=N               combates por casilla de la tabla (por defecto 40)
##   --boss=jefe_final         jefe a medir
##   --boss-tier=MYTHIC        clase de las piezas del jefe
##   --player-tiers=LEGENDARY,MYTHIC   clases del equipo del jugador
##   --seed=1                  semilla base
## El jugador juega con la IA dificil, que es la que mas se parece a alguien
## que piensa sus jugadas. Se alterna quien empieza.

var _rules_plain := RulesConfig.new()
var _rules_drops := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _builds: Dictionary[String, MechBuild] = {}


func _initialize() -> void:
	var args := _parse_args()
	var battles := int(args.get("battles", "40"))
	var base_seed := int(args.get("seed", "1"))
	var boss_id: String = args.get("boss", "jefe_final")
	var boss_tier: ItemDef.Tier = ItemDef.Tier[args.get("boss-tier", "MYTHIC")]
	var tier_names: PackedStringArray = str(args.get("player-tiers", "LEGENDARY,MYTHIC")).split(",")
	_rules_drops.drops_enabled = true
	_rules_drops.crits_enabled = true

	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	if not (catalog.errors.is_empty() and library.errors.is_empty() and chassis.errors.is_empty()):
		printerr("datos con errores: ", catalog.errors, library.errors, chassis.errors)
		quit(2)
		return
	if not library.specs.has(boss_id):
		printerr("no existe el jefe ", boss_id)
		quit(2)
		return

	var boss_level := _rules_plain.tier_max_level[boss_tier]
	_builds["boss"] = library.make(boss_id, catalog, _rules_plain, boss_tier, boss_level, chassis)
	var seed_value := base_seed
	for tier_name in tier_names:
		var tier: ItemDef.Tier = ItemDef.Tier[tier_name]
		for id in library.starter_ids():
			var key := "%s@%s" % [id, tier_name]
			_builds[key] = library.make(
				id, catalog, _rules_plain, tier, _rules_plain.tier_max_level[tier]
			)
			for drops in [false, true]:
				for n in battles:
					seed_value += 1
					(
						_tasks
						. append(
							{
								"player": key,
								"id": id,
								"tier": tier_name,
								"drops": drops,
								"seed": seed_value,
								"starter": n % 2,
							}
						)
					)
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	_report(boss_id, args.get("boss-tier", "MYTHIC"), battles, tier_names, library)
	quit(0)


func _run_task(index: int) -> void:
	var task := _tasks[index]
	_results[index] = BattleRunner.run(
		_rules_drops if task["drops"] else _rules_plain,
		_builds[task["player"]],
		_builds["boss"],
		BattleAI.new(BattleAI.Difficulty.HARD, task["seed"] * 2 + 1),
		BattleAI.new(BattleAI.Difficulty.HARD, task["seed"] * 2 + 2),
		task["seed"],
		task["starter"]
	)


func _report(
	boss_id: String,
	boss_tier: String,
	battles: int,
	tier_names: PackedStringArray,
	library: BuildLibrary
) -> void:
	var boss := _builds["boss"]
	var stats := boss.summary(_rules_plain)
	print("Jefe %s (%s): vida %d, %d acciones por turno" % [boss_id, boss_tier, stats["health"], 3])
	print("Victorias del jugador sobre %d combates por casilla:" % battles)
	print("  %-22s %-12s %10s %10s %8s" % ["mech", "equipo", "sin bonif.", "con bonif.", "turnos"])
	var totals := {}
	for index in _tasks.size():
		var task := _tasks[index]
		var key := "%s|%s|%s" % [task["id"], task["tier"], task["drops"]]
		if not totals.has(key):
			totals[key] = [0, 0, 0.0]
		totals[key][0] += 1
		if _results[index]["winner"] == 0:
			totals[key][1] += 1
		totals[key][2] += _results[index]["turns"]
	for tier_name in tier_names:
		for id in library.starter_ids():
			var plain: Array = totals["%s|%s|%s" % [id, tier_name, false]]
			var drops: Array = totals["%s|%s|%s" % [id, tier_name, true]]
			print(
				(
					"  %-22s %-12s %8.1f %% %8.1f %% %8.1f"
					% [
						id,
						tier_name,
						100.0 * plain[1] / plain[0],
						100.0 * drops[1] / drops[0],
						(plain[2] + drops[2]) / (plain[0] + drops[0])
					]
				)
			)


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var parts := text.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
