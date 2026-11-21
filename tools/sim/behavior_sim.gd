extends SceneTree
## Mide que hacen los rivales en combate (OBS-014: "es muy predecible; los
## enemigos no hacen mas que atacar; no usan habilidades, no usan
## estrategia"). Juega los combates de una zona y cuenta, por rival, en que
## gasta sus acciones: pegar con un arma, pisar, moverse, enfriar, los
## especiales y las habilidades. Tambien cuantas acciones distintas usa.
##
## Uso (tras `++`):
##   --zone=0      zona de la campana
##   --battles=N   combates por rival (por defecto 12)
##   --seed=1      semilla base
## El jugador es el mech de ejemplo fisico con la IA normal; cada rival juega
## con la dificultad que le pone la campana. Bonificaciones encendidas.

const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
}
## Como se agrupan las acciones del rival.
const GROUPS := {
	BattleAction.Type.WEAPON: "arma",
	BattleAction.Type.STOMP: "pisoton",
	BattleAction.Type.WALK: "moverse",
	BattleAction.Type.COOL: "enfriar",
	BattleAction.Type.CHARGE: "especial",
	BattleAction.Type.HOOK: "especial",
	BattleAction.Type.TELEPORT: "especial",
	BattleAction.Type.SHIELD: "habilidad",
	BattleAction.Type.REPAIR: "habilidad",
	BattleAction.Type.DARK_MATTER: "habilidad",
}
const ORDER: Array[String] = ["arma", "pisoton", "moverse", "enfriar", "especial", "habilidad"]

var _rules := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _player: MechBuild
var _rivals: Array[MechBuild] = []
var _ais: Array[int] = []


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var zone := int(args.get("zone", "0"))
	var battles := int(args.get("battles", "12"))
	var seed_value := int(args.get("seed", "1"))
	_rules.drops_enabled = true
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var skills := SkillTree.load_file("res://data/skills.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var tier := campaign.tier_of(zone)
	var player_id: String = library.band_ids(campaign.band_of(zone))[0]
	_player = library.make(player_id, catalog, _rules, tier, campaign.level_cap(zone))
	var labels: Array[String] = []
	for fight in campaign.fights_in(zone) + 1:
		var spec := campaign.fight_at(zone, fight)
		var rival := library.make(spec["enemy"], catalog, _rules, tier, spec["level"], chassis)
		rival.upgrades = campaign.enemy_upgrades(zone, shop)
		rival.skills = skills.effects_for(skills.spread(int(spec.get("skills", 0))))
		rival.skills.add(Campaign.kits_of(spec))
		_rivals.append(rival)
		_ais.append(DIFFICULTY[spec["difficulty"]])
		labels.append(
			(
				"%-5s %-22s %-7s"
				% [
					"jefe" if campaign.is_boss_fight(zone, fight) else str(fight + 1),
					library.display_name(spec["enemy"]),
					spec["difficulty"]
				]
			)
		)
		for n in battles:
			seed_value += 1
			_tasks.append({"fight": fight, "seed": seed_value, "starter": n % 2})
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	_report(labels, zone, campaign)
	quit(0)


func _run_task(index: int) -> void:
	var task := _tasks[index]
	var fight: int = task["fight"]
	var engine := BattleEngine.new(_rules, _player, _rivals[fight], task["seed"], task["starter"])
	var ais: Array[BattleAI] = [
		BattleAI.new(BattleAI.Difficulty.NORMAL, task["seed"] * 2 + 1),
		BattleAI.new(_ais[fight], task["seed"] * 2 + 2),
	]
	var counts := {}
	var kinds := {}
	while not engine.is_over() and engine.turn_number <= 200:
		var who := engine.turn
		var action := ais[who].choose_action(engine)
		if action == null or engine.apply(action) != "":
			break
		if who == 1:
			var group: String = GROUPS.get(action.type, "otra")
			counts[group] = int(counts.get(group, 0)) + 1
			kinds["%d/%s" % [action.type, action.slot]] = true
	_results[index] = {"counts": counts, "kinds": kinds.size(), "won": engine.winner == 1}


func _report(labels: Array[String], zone: int, campaign: Campaign) -> void:
	print("Zona %d (%s): en que gasta el rival sus acciones" % [zone + 1, campaign.zone_name(zone)])
	var header := "  %-36s" % "rival"
	for group in ORDER:
		header += " %9s" % group
	print(header + "   distintas   gana")
	var total := {}
	var all_actions := 0
	for fight in labels.size():
		var counts := {}
		var kinds := 0.0
		var wins := 0
		var games := 0
		for index in _tasks.size():
			if _tasks[index]["fight"] != fight:
				continue
			games += 1
			kinds += float(_results[index]["kinds"])
			wins += 1 if _results[index]["won"] else 0
			for group: String in _results[index]["counts"]:
				counts[group] = int(counts.get(group, 0)) + int(_results[index]["counts"][group])
		var sum := 0
		for group: String in counts:
			sum += int(counts[group])
			total[group] = int(total.get(group, 0)) + int(counts[group])
		all_actions += sum
		var line := "  %-36s" % labels[fight]
		for group in ORDER:
			line += " %7.1f %%" % (100.0 * int(counts.get(group, 0)) / maxi(sum, 1))
		print(
			(
				line
				+ (
					"   %7.1f   %3d %%"
					% [kinds / maxi(games, 1), roundi(100.0 * wins / maxi(games, 1))]
				)
			)
		)
	var line := "  %-36s" % "todos"
	for group in ORDER:
		line += " %7.1f %%" % (100.0 * int(total.get(group, 0)) / maxi(all_actions, 1))
	print(line)
