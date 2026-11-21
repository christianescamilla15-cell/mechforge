extends SceneTree
## Tu robot guardado, tal como lo arma el juego (sus piezas con su clase y
## nivel, sus habilidades, su tipo y su armeria), contra el combate de campana
## en el que esta, tal como lo arma el juego. Sirve para medir un cambio con
## la partida real antes de entregarlo: con `--modules` se prueba otro reparto
## de modulos (OBS-040). Solo lee el guardado; no escribe nada.
##   Godot --headless --path . -s tools/sim/save_fight_sim.gd ++
##     --save=<ruta>      el guardado (por defecto user://save.json)
##     --fight=N          otro combate de su liga (10 es el campeon)
##     --battles=40       combates por variante
##     --player=HARD      dificultad de la IA que hace de jugador
## Variantes que mide: los modulos como estaban antes de las familias (si el
## guardado es de antes), como quedan al pasar a familias y con tres de ataque.

const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
}
const ATTACK := ["mod_servo_brazos", "mod_servo_hombro", "mod_sobrealimentador"]


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var path := str(args.get("save", "user://save.json"))
	var battles := int(args.get("battles", "40"))
	var player_ai: BattleAI.Difficulty = DIFFICULTY[str(args.get("player", "HARD"))]
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var skills := SkillTree.load_file("res://data/skills.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var tempers := TemperLibrary.load_file("res://data/tempers.json")
	var brief := WorkshopBrief.new()
	brief.rules = rules
	brief.catalog = catalog
	brief.library = library
	brief.campaign = campaign
	brief.skills = skills
	brief.shop = shop
	brief.progression = Progression.load_file("res://data/progression.json")
	brief.styles = StyleLibrary.load_file("res://data/styles.json", catalog)
	brief.workshop = Workshop.load_file("res://data/workshop.json")
	brief.garage = Garage.load_file("res://data/part_shop.json")

	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var profile := PlayerProfile.load_or_new(path)
	var zone := profile.zone
	var fight := int(args.get("fight", str(profile.fight)))
	var spec := campaign.fight_at(zone, fight)
	var rival := library.make(
		spec["enemy"],
		catalog,
		rules,
		campaign.tier_of(zone),
		spec["level"],
		chassis,
		{},
		spec.get("loadout", {})
	)
	rival.upgrades = campaign.enemy_upgrades(zone, shop)
	rival.skills = skills.effects_for(skills.spread(int(spec.get("skills", 0))))
	rival.skills.add(Campaign.kits_of(spec))
	rival.body = str(spec.get("body", ""))
	var rival_ai: BattleAI.Difficulty = BattleAI.Difficulty[str(spec["difficulty"])]
	var temper := tempers.config(library.temper_of(spec["enemy"]))

	# Los modulos nuevos, a la clase y el nivel de su torso (lo que costaria
	# tenerlos al dia).
	var torso_id := str(profile.build.get("torso", ""))
	var parts := profile.parts.duplicate(true)
	for id: String in ATTACK:
		if not parts.has(id) and torso_id != "":
			parts[id] = profile.part(torso_id).duplicate()
	var variants := {}
	var old_build: Dictionary = (raw["mechs"][int(raw.get("active", 0))] as Dictionary)["build"]
	if int(raw.get("schema_version", 0)) < 11:
		variants["antes (8 sueltos)"] = old_build.get("modules", [])
	var now: Array = profile.build.get("modules", []).duplicate()
	variants["familias, sin ataque"] = now
	var full := now.duplicate()
	while full.size() < 9:
		full.append("")
	for index in ATTACK.size():
		full[3 + index] = ATTACK[index]
	variants["familias + 3 de ataque"] = full
	print(
		(
			"Liga %d, combate %d (%s, %s): tu %s contra el rival, %d combates por variante"
			% [zone + 1, fight + 1, spec["enemy"], spec["difficulty"], profile.style, battles]
		)
	)
	for label: String in variants:
		var spec_build := profile.build.duplicate(true)
		spec_build["modules"] = variants[label]
		var build := brief.build_of(profile, spec_build, parts)
		var wins := 0
		for n in battles:
			var result := BattleRunner.run(
				rules,
				build,
				rival,
				BattleAI.new(player_ai, n * 2 + 1),
				BattleAI.new(rival_ai, n * 2 + 2, temper),
				n + 7,
				n % 2
			)
			wins += 1 if result["winner"] == 0 else 0
		print(
			(
				"  %-24s %3.0f %%   peso %d / %d   modulos %s"
				% [
					label,
					100.0 * wins / battles,
					build.total_weight(),
					build.max_weight(rules),
					", ".join(PackedStringArray(variants[label]))
				]
			)
		)
	quit(0)
