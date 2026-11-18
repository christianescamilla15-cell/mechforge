extends SceneTree
## Mide la curva de una zona de la campana: las victorias del jugador contra
## cada uno de sus combates y contra el jefe, sin mejoras de armeria. Sirve
## para ver que tan dificil es ir directo al jefe sin pasar por la arena.
##
## Uso (tras `++`):
##   --battles=N   combates por mech y por combate de la zona (por defecto 40)
##   --zone=0      zona
##   --seed=1      semilla base
## Las bonificaciones de la arena estan encendidas. Hace de jugador la IA
## dificil; el rival usa la dificultad que diga la campana. Se alterna quien
## empieza.

const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
}

var _rules := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _players: Dictionary[String, MechBuild] = {}
var _rivals: Array[MechBuild] = []
var _difficulties: Array[int] = []


func _initialize() -> void:
	var args := _parse_args()
	var battles := int(args.get("battles", "40"))
	var seed_value := int(args.get("seed", "1"))
	var zone := int(args.get("zone", "0"))
	_rules.drops_enabled = true
	_rules.crits_enabled = not OS.get_cmdline_user_args().has("--no-crits")

	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var problems := catalog.errors + library.errors + chassis.errors + campaign.errors
	if not problems.is_empty() or zone >= campaign.zone_count():
		printerr("datos con errores: ", problems)
		quit(2)
		return

	var tier := campaign.tier_of(zone)
	var count := campaign.fights_in(zone) + 1
	for fight in count:
		var spec := campaign.fight_at(zone, fight)
		_rivals.append(library.make(spec["enemy"], catalog, _rules, tier, spec["level"], chassis))
		_difficulties.append(DIFFICULTY[spec["difficulty"]])
	for id in library.band_ids(campaign.band_of(zone)):
		_players[id] = library.make(id, catalog, _rules, tier, campaign.level_cap(zone))
		for fight in count:
			for n in battles:
				seed_value += 1
				_tasks.append({"id": id, "fight": fight, "seed": seed_value, "starter": n % 2})
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	_report(campaign, zone, library, battles)
	quit(0)


func _run_task(index: int) -> void:
	var task := _tasks[index]
	var fight: int = task["fight"]
	_results[index] = BattleRunner.run(
		_rules,
		_players[task["id"]],
		_rivals[fight],
		BattleAI.new(BattleAI.Difficulty.HARD, task["seed"] * 2 + 1),
		BattleAI.new(_difficulties[fight], task["seed"] * 2 + 2),
		task["seed"],
		task["starter"]
	)


func _report(campaign: Campaign, zone: int, library: BuildLibrary, battles: int) -> void:
	var wins := {}
	var turns := 0
	for index in _tasks.size():
		var task := _tasks[index]
		var key := "%s@%d" % [task["id"], task["fight"]]
		wins[key] = wins.get(key, 0) + (1 if _results[index]["winner"] == 0 else 0)
		turns += int(_results[index].get("turns", 0))
	var ids := library.band_ids(campaign.band_of(zone))
	var header := "  combate  rival                 nivel  dificultad"
	for id in ids:
		header += "  %10s" % id.split("_")[0]
	print(
		(
			"Zona %d (%s): victorias del jugador sin mejoras (%d combates por casilla)"
			% [zone + 1, campaign.zone_name(zone), battles]
		)
	)
	print(header + "     media")
	var straight := 1.0
	for fight in campaign.fights_in(zone) + 1:
		var spec := campaign.fight_at(zone, fight)
		var label := "jefe" if campaign.is_boss_fight(zone, fight) else str(fight + 1)
		var line := (
			"  %7s  %-20s  %5d  %10s"
			% [label, library.display_name(spec["enemy"]), spec["level"], spec["difficulty"]]
		)
		var total := 0.0
		for id in ids:
			var rate: float = 100.0 * int(wins["%s@%d" % [id, fight]]) / battles
			total += rate
			line += "  %8.1f %%" % rate
		var mean := total / ids.size()
		straight *= mean / 100.0
		print(line + "  %6.1f %%" % mean)
	print("Pasar la zona entera sin perder ni un combate: %.2f %%" % (straight * 100.0))
	print("Turnos por combate, de media: %.1f" % (float(turns) / _tasks.size()))


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var parts := text.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
