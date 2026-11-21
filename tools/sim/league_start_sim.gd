extends SceneTree
## Mide lo que se encuentra un robot inicial al entrar en la campana (OBS-031,
## del usuario el 2026-11-21: "creo que esta muy roto el primer rival de la
## campana, me derroto a pesar de llevar todas las mejoras"). Cada tipo de
## robot inicial (data/styles.json), en cuatro momentos (con su unica arma,
## con dos, con dos y dos modulos, armado entero), pelea contra cada combate
## de una zona tal como lo arma el juego: el rival con su nivel, su
## dificultad, sus habilidades, su caracter y la armeria del Orden.
##
## Uso (tras `++`):
##   --zone=0        zona de la campana
##   --battles=N     combates por casilla (por defecto 16)
##   --player=HARD   dificultad de la IA que hace de jugador
##   --upgrades      el jugador lleva todas las mejoras de la armeria que su
##                   zona deja comprar
##   --level=N       nivel de las piezas del jugador (por defecto 0; "tope" =
##                   el maximo de la zona)
##   --stage=N       solo ese momento (0 a 3)
##   --parity        en vez de los cuatro momentos, en cada combate el jugador
##                   lleva el mismo equipo que su rival (tantas armas y
##                   modulos como el): lo que da para comprar la campana
##   --seed=1        semilla base

const StarterSim := preload("res://tools/sim/starter_sim.gd")
const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
}

var _rules := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _players: Dictionary = {}
var _rivals: Array[MechBuild] = []
var _rival_ais: Array[int] = []
var _configs: Array[AIConfig] = []
var _player_ai := BattleAI.Difficulty.HARD
## Equipo del rival de cada combate ({} = armado entero).
var _gears: Array[Dictionary] = []


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var zone := int(args.get("zone", "0"))
	var battles := int(args.get("battles", "16"))
	var seed_value := int(args.get("seed", "1"))
	var only := int(args.get("stage", "-1"))
	_player_ai = DIFFICULTY[str(args.get("player", "HARD"))]
	_rules.drops_enabled = true

	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var styles := StyleLibrary.load_file("res://data/styles.json", catalog)
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var skills := SkillTree.load_file("res://data/skills.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var tempers := TemperLibrary.load_file("res://data/tempers.json")
	var tier := campaign.tier_of(zone)
	var level := int(args.get("level", "0"))
	if str(args.get("level", "")) == "tope":
		level = campaign.level_cap(zone)
	# Todas las mejoras que la zona deja comprar.
	var bought: ArenaUpgrades = null
	if args.has("upgrades"):
		var levels := {}
		for track in shop.track_ids():
			levels[track] = campaign.armory_cap(zone, shop)
		bought = shop.upgrades_for(levels)

	var labels: Array[String] = []
	for fight in campaign.fights_in(zone) + 1:
		var spec := campaign.fight_at(zone, fight)
		# Con el equipo que su combate le deja llevar (en la liga 1 van creciendo).
		var rival := library.make(
			spec["enemy"],
			catalog,
			_rules,
			tier,
			spec["level"],
			chassis,
			{},
			spec.get("loadout", {})
		)
		rival.upgrades = campaign.enemy_upgrades(zone, shop)
		rival.skills = skills.effects_for(skills.spread(int(spec.get("skills", 0))))
		rival.skills.add(Campaign.kits_of(spec))
		_rivals.append(rival)
		_rival_ais.append(DIFFICULTY[spec["difficulty"]])
		_gears.append(spec.get("loadout", {}))
		_configs.append(tempers.config(library.temper_of(spec["enemy"])))
		labels.append("jefe" if campaign.is_boss_fight(zone, fight) else str(fight + 1))
	var parity := args.has("parity")
	for style_id in styles.ids():
		if parity:
			for fight in _rivals.size():
				var gear: Dictionary = _gears[fight].duplicate()
				if gear.is_empty():
					gear = StarterSim.STAGES[-1]["gear"].duplicate()
				gear.erase("shift")
				var same := StarterSim.player_with(styles, catalog, _rules, style_id, gear, level)
				same.upgrades = bought
				var same_key := "%s@p%d" % [style_id, fight]
				_players[same_key] = same
				for n in battles:
					seed_value += 1
					_tasks.append(
						{"player": same_key, "fight": fight, "seed": seed_value, "starter": n % 2}
					)
			continue
		for stage in StarterSim.STAGES.size():
			if only >= 0 and stage != only:
				continue
			var build := StarterSim.player_build(styles, catalog, _rules, style_id, stage, level)
			build.upgrades = bought
			var key := "%s@%d" % [style_id, stage]
			_players[key] = build
			for fight in _rivals.size():
				for n in battles:
					seed_value += 1
					_tasks.append(
						{"player": key, "fight": fight, "seed": seed_value, "starter": n % 2}
					)
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)

	var wins := {}
	var games := {}
	for index in _tasks.size():
		var cell := "%s|%d" % [_tasks[index]["player"], _tasks[index]["fight"]]
		games[cell] = int(games.get(cell, 0)) + 1
		wins[cell] = int(wins.get(cell, 0)) + (1 if _results[index]["winner"] == 0 else 0)
	print(
		(
			"Zona %d: victorias de un robot inicial en la campana (jugador %s%s, piezas de nivel %d)"
			% [
				zone + 1,
				DIFFICULTY.find_key(_player_ai),
				", con todas las mejoras" if bought != null else ", sin mejoras",
				level
			]
		)
	)
	var header := "  %-16s %-9s" % ["momento", "tipo"]
	for label in labels:
		header += " %5s" % label
	print(header)
	if parity:
		for style_id in styles.ids():
			var same_line := "  %-16s %-9s" % ["a la par", style_id]
			for fight in _rivals.size():
				var same_cell := "%s@p%d|%d" % [style_id, fight, fight]
				same_line += " %4.0f%%" % (100.0 * wins[same_cell] / games[same_cell])
			print(same_line)
		quit(0)
		return
	for stage in StarterSim.STAGES.size():
		if only >= 0 and stage != only:
			continue
		for style_id in styles.ids():
			var line := "  %-16s %-9s" % [StarterSim.STAGES[stage]["name"], style_id]
			for fight in _rivals.size():
				var cell := "%s@%d|%d" % [style_id, stage, fight]
				line += " %4.0f%%" % (100.0 * wins[cell] / games[cell])
			print(line)
	quit(0)


func _run_task(index: int) -> void:
	var task := _tasks[index]
	var fight: int = task["fight"]
	_results[index] = BattleRunner.run(
		_rules,
		_players[task["player"]],
		_rivals[fight],
		BattleAI.new(_player_ai, task["seed"] * 2 + 1),
		BattleAI.new(_rival_ais[fight], task["seed"] * 2 + 2, _configs[fight]),
		task["seed"],
		task["starter"]
	)
