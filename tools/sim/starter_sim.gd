extends SceneTree
## Mide si los tres tipos de robot inicial (data/styles.json) estan
## equilibrados: cada uno pelea contra los rivales de la arena de la zona 1,
## que salen con su mismo equipo (Campaign.loadout_of y BuildLibrary.trim), en
## cuatro momentos de la partida: con su unica arma, con dos, con dos y dos
## modulos, y armado entero. Todo en clase Basica, nivel 0.
##
## Uso (tras `++`):
##   --battles=N     combates por casilla (por defecto 40)
##   --rival=NORMAL  dificultad de la IA del rival (la de la arena)
##   --player=HARD   dificultad de la IA que hace de jugador
##   --seed=1        semilla base
##   --stage=N       solo ese momento (0 a 3); sin el, los cuatro
##   --body=torso,piernas   los tres con ese mismo cuerpo (ids del catalogo),
##                   para medir solo lo que cambia el tipo: sus armas y lo suyo
## Las bonificaciones de la arena estan encendidas. Se alterna quien empieza.

const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
}
## El robot de cada tipo ya armado entero (dos armas de brazo y una de
## hombro, OBS-033), con lo que su tipo le deja montar y los mismos modulos
## que los mechs de ejemplo. De aqui se recorta cada momento.
const FULL := {
	"asalto": {"sides": ["hoja_balas_ter", "corto_balas_ter"], "tops": ["bateria_balas_ter"]},
	"guardian": {"sides": ["medio_balas_cin", "corto_balas_cin"], "tops": ["bateria_balas_cin"]},
	"tirador": {"sides": ["medio_balas_ion", "medio_balas_cin"], "tops": ["largo_balas_ion"]},
}
## En que orden gana armas cada tipo: la primera es la que trae de serie (el
## Tirador, su rifle de hombro).
const ORDER := {
	"asalto": ["sides", "sides", "tops"],
	"guardian": ["sides", "sides", "tops"],
	"tirador": ["tops", "sides", "sides"],
}
## Los modulos de los mechs de ejemplo: los cuerpos de calor y de energia,
## que pesan menos, llevan un segundo blindaje (GDD 7.1).
const MODULES := {
	ItemDef.Element.PHYSICAL: ["mod_blindaje", "mod_matriz", "mod_generador", "mod_disipador"],
	ItemDef.Element.HEAT:
	["mod_blindaje", "mod_matriz", "mod_generador", "mod_disipador", "mod_blindaje"],
	ItemDef.Element.ENERGY:
	["mod_blindaje", "mod_matriz", "mod_generador", "mod_disipador", "mod_blindaje"],
}
const STAGES: Array[Dictionary] = [
	{"name": "1 arma", "gear": {"weapons": 1}},
	{"name": "2 armas", "gear": {"weapons": 2}},
	{"name": "2 armas + 2 mod", "gear": {"weapons": 2, "modules": 2}},
	{"name": "entero", "gear": {"weapons": 3, "modules": 5, "specials": 2}},
]

## Cuerpo comun para los tres ([torso, piernas]); vacio = el de cada tipo.
static var body: PackedStringArray = []

var _rules := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _players: Dictionary = {}
var _rivals: Dictionary = {}
var _player_ai := BattleAI.Difficulty.HARD
var _rival_ai := BattleAI.Difficulty.NORMAL
## Momento que se mide; -1 = todos.
var _only := -1


func _initialize() -> void:
	var args := _parse_args()
	var battles := int(args.get("battles", "40"))
	var seed_value := int(args.get("seed", "1"))
	_player_ai = DIFFICULTY[str(args.get("player", "HARD"))]
	_rival_ai = DIFFICULTY[str(args.get("rival", "NORMAL"))]
	_only = int(args.get("stage", "-1"))
	body = str(args.get("body", "")).split(",", false)
	_rules.drops_enabled = true

	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var styles := StyleLibrary.load_file("res://data/styles.json", catalog)
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var problems := catalog.errors + library.errors + styles.errors + campaign.errors
	if not problems.is_empty():
		printerr("datos con errores: ", problems)
		quit(2)
		return

	var rival_ids := library.band_ids(campaign.band_of(0))
	for style_id in styles.ids():
		for stage in STAGES.size():
			if _only >= 0 and stage != _only:
				continue
			var build := player_build(styles, catalog, _rules, style_id, stage)
			var key := "%s@%d" % [style_id, stage]
			_players[key] = build
			var gear := Campaign.loadout_of(build)
			for r in rival_ids.size():
				for shift in 4:
					gear["shift"] = shift
					var rival_key := "%s/%d/%d" % [key, r, shift]
					_rivals[rival_key] = library.make(
						rival_ids[r], catalog, _rules, ItemDef.Tier.COMMON, 0, null, {}, gear
					)
					for n in battles / 4:
						seed_value += 1
						(
							_tasks
							. append(
								{
									"player": key,
									"rival": rival_key,
									"seed": seed_value,
									"starter": n % 2,
								}
							)
						)
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	_report(styles, rival_ids, library)
	quit(0)


## El robot de ese tipo en uno de los momentos de STAGES, con lo que da su
## tipo y sus piezas a ese nivel. Lo usan tambien starter_trace.gd y
## league_start_sim.gd.
static func player_build(
	styles: StyleLibrary,
	catalog: Catalog,
	rules: RulesConfig,
	style_id: String,
	stage: int,
	level: int = 0
) -> MechBuild:
	return player_with(styles, catalog, rules, style_id, STAGES[stage]["gear"], level)


## El robot de ese tipo con un equipo dado ({"sides", "tops", "modules",
## "specials"}: cuantos lleva), con lo que da su tipo.
static func player_with(
	styles: StyleLibrary,
	catalog: Catalog,
	rules: RulesConfig,
	style_id: String,
	gear: Dictionary,
	level: int = 0
) -> MechBuild:
	var full: Dictionary = styles.build(style_id)
	full.merge(FULL[style_id], true)
	if body.size() == 2:
		full["torso"] = body[0]
		full["legs"] = body[1]
	full["modules"] = MODULES[catalog.get_item(str(full["torso"])).element]
	full["charge"] = "esp_embestida"
	full["hook"] = "esp_garfio"
	# "weapons": cuantas armas lleva, en el orden en que las gana su tipo.
	var cut := gear.duplicate()
	if cut.has("weapons"):
		var order: Array = ORDER[style_id]
		for key: String in ["sides", "tops"]:
			cut[key] = order.slice(0, int(cut["weapons"])).count(key)
		cut.erase("weapons")
	var items := BuildLibrary.trim(full, cut, catalog)
	var build := catalog.make_build(items, rules, ItemDef.Tier.COMMON, level)
	build.skills = SkillSet.new()
	styles.add_effects(style_id, build.skills)
	return build


func _run_task(index: int) -> void:
	var task := _tasks[index]
	_results[index] = BattleRunner.run(
		_rules,
		_players[task["player"]],
		_rivals[task["rival"]],
		BattleAI.new(_player_ai, task["seed"] * 2 + 1),
		BattleAI.new(_rival_ai, task["seed"] * 2 + 2),
		task["seed"],
		task["starter"]
	)


func _report(styles: StyleLibrary, rival_ids: Array[String], library: BuildLibrary) -> void:
	var wins := {}
	var games := {}
	var turns := {}
	for index in _tasks.size():
		var task := _tasks[index]
		var rival: String = str(task["rival"]).get_slice("/", 1)
		for key: String in [task["player"], "%s|%s" % [task["player"], rival]]:
			games[key] = games.get(key, 0) + 1
			wins[key] = wins.get(key, 0) + (1 if _results[index]["winner"] == 0 else 0)
			turns[key] = turns.get(key, 0) + int(_results[index].get("turns", 0))
	print(
		(
			"Tipos de robot inicial contra la arena de la zona 1 (jugador %s, rival %s)"
			% [DIFFICULTY.find_key(_player_ai), DIFFICULTY.find_key(_rival_ai)]
		)
	)
	var header := "  %-16s %-9s  victorias  turnos " % ["momento", "tipo"]
	for id in rival_ids:
		header += "  %9s" % library.display_name(id).left(9)
	print(header)
	for stage in STAGES.size():
		if _only >= 0 and stage != _only:
			continue
		for style_id in styles.ids():
			var key := "%s@%d" % [style_id, stage]
			var line := (
				"  %-16s %-9s  %7.1f %%  %6.1f "
				% [
					STAGES[stage]["name"],
					style_id,
					100.0 * wins[key] / games[key],
					float(turns[key]) / games[key]
				]
			)
			for r in rival_ids.size():
				var cell := "%s|%d" % [key, r]
				line += "  %7.1f %%" % (100.0 * wins[cell] / games[cell])
			print(line)
		print("")


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var parts := text.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
