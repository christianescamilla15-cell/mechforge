extends SceneTree
## Tu robot guardado, tal como lo arma el juego (sus piezas con su clase y
## nivel, sus habilidades, su tipo y su armeria), contra un combate de
## campana tal como lo arma el juego. Sirve para medir un cambio con la
## partida real antes de entregarlo (OBS-040, OBS-041). Solo lee el guardado.
##   Godot --headless --path . -s tools/sim/save_fight_sim.gd ++
##     --save=<ruta>      el guardado (por defecto user://save.json)
##     --zone=N           otra liga (0 es la primera); con ella, su campeon
##     --fight=N          otro combate de la liga (el ultimo es el campeon)
##     --raise            el robot llevado a esa liga: piezas a su clase y
##                        nivel maximo (las armas que no llegan, la misma forma
##                        en la municion de esa clase) y la armeria al tope
##     --battles=40       combates por variante
##     --player=HARD      dificultad de la IA que hace de jugador
## Con las reglas del juego: criticos, empujes y bonificaciones en la arena.
## Variantes: el robot como esta y, si no lleva modulos de ataque, con tres.

const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
}
const ATTACK := ["mod_servo_brazos", "mod_servo_hombro", "mod_sobrealimentador"]
const WEAPON_SLOTS := ["sides", "tops", "chest", "drone", "drone_low"]

var _rules := RulesConfig.new()
var _catalog: Catalog


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var path := str(args.get("save", "user://save.json"))
	var battles := int(args.get("battles", "40"))
	var player_ai: BattleAI.Difficulty = DIFFICULTY[str(args.get("player", "HARD"))]
	# Las reglas del juego (MainScreen): criticos, empujes y bonificaciones en
	# la arena.
	_rules.crits_enabled = true
	_rules.impact_enabled = true
	_rules.drops_enabled = true
	_catalog = Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var skills := SkillTree.load_file("res://data/skills.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var tempers := TemperLibrary.load_file("res://data/tempers.json")
	var brief := WorkshopBrief.new()
	brief.rules = _rules
	brief.catalog = _catalog
	brief.library = library
	brief.campaign = campaign
	brief.skills = skills
	brief.shop = shop
	brief.progression = Progression.load_file("res://data/progression.json")
	brief.styles = StyleLibrary.load_file("res://data/styles.json", _catalog)
	brief.workshop = Workshop.load_file("res://data/workshop.json")
	brief.garage = Garage.load_file("res://data/part_shop.json")

	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var profile := PlayerProfile.load_or_new(path)
	var zone := int(args.get("zone", str(profile.zone)))
	var default_fight := campaign.fights_in(zone) if args.has("zone") else profile.fight
	var fight := int(args.get("fight", str(default_fight)))
	var raise := args.has("raise")
	var spec := campaign.fight_at(zone, fight)
	var rival := library.make(
		spec["enemy"],
		_catalog,
		_rules,
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

	var base_build := profile.build.duplicate(true)
	var parts := profile.parts.duplicate(true)
	# Los modulos de ataque que no tenga, a la clase y el nivel de su torso.
	var torso_id := str(base_build.get("torso", ""))
	for id: String in ATTACK:
		if not parts.has(id) and torso_id != "":
			parts[id] = profile.part(torso_id).duplicate()
	if raise:
		base_build = _raised_build(base_build, campaign.tier_of(zone))
		parts = _raised_parts(base_build, parts, campaign.tier_of(zone), campaign.level_cap(zone))
		for track in shop.track_ids():
			profile.shop_levels[track] = campaign.armory_cap(zone, shop)
	var variants := {}
	var old_build: Dictionary = (raw["mechs"][int(raw.get("active", 0))] as Dictionary)["build"]
	if int(raw.get("schema_version", 0)) < 11 and not raise:
		variants["antes (8 sueltos)"] = old_build.get("modules", [])
	var now: Array = base_build.get("modules", []).duplicate()
	variants["tu robot"] = now
	var attack := false
	for id: Variant in now:
		attack = attack or str(id) in ATTACK or str(id) == "mod_cebador"
	if not attack:
		var full := now.duplicate()
		while full.size() < MechBuild.MODULE_SLOTS:
			full.append("")
		for index in ATTACK.size():
			full[3 + index] = ATTACK[index]
		variants["con 3 de ataque"] = full
	print(
		(
			"Liga %d, combate %d (%s, %s, %s)%s: tu %s, %d combates por variante"
			% [
				zone + 1,
				fight + 1,
				spec["enemy"],
				spec["difficulty"],
				library.specs[spec["enemy"]].get("chassis", "-"),
				" con el robot llevado a la liga" if raise else "",
				profile.style,
				battles
			]
		)
	)
	for label: String in variants:
		var spec_build := base_build.duplicate(true)
		spec_build["modules"] = variants[label]
		var build := brief.build_of(profile, spec_build, parts)
		var wins := 0
		for n in battles:
			var result := BattleRunner.run(
				_rules,
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
				"  %-20s %3.0f %%   peso %d / %d   modulos %s"
				% [
					label,
					100.0 * wins / battles,
					build.total_weight(),
					build.max_weight(_rules),
					", ".join(PackedStringArray(variants[label]))
				]
			)
		)
	quit(0)


## Las armas que no llegan a esa clase, cambiadas por la misma forma y el
## mismo elemento en el tipo de esa clase (como al comprarlas).
func _raised_build(build: Dictionary, tier: ItemDef.Tier) -> Dictionary:
	var out := build.duplicate(true)
	for key: String in WEAPON_SLOTS:
		var value: Variant = out.get(key)
		if value is Array:
			var list: Array = []
			for id: Variant in value:
				list.append(_weapon_at(str(id), tier))
			out[key] = list
		elif value != null:
			out[key] = _weapon_at(str(value), tier)
	return out


func _weapon_at(id: String, tier: ItemDef.Tier) -> String:
	var def := _catalog.get_item(id)
	if def == null or def.form == "" or (def.tier_min <= tier and tier <= def.tier_max):
		return id
	for other: ItemDef in _catalog.by_type(def.type):
		var same := other.form == def.form and other.element == def.element
		same = same and not other.has_tag(ItemDef.TAG_ARENA)
		if same and other.tier_min <= tier and tier <= other.tier_max:
			return other.id
	return id


## Cada pieza a la clase de la liga (sin pasar de su rango) y a su nivel
## maximo en esa clase.
func _raised_parts(
	build: Dictionary, parts: Dictionary, tier: ItemDef.Tier, cap: int
) -> Dictionary:
	var out := parts.duplicate(true)
	var ids: Array[String] = []
	for id in BuildLibrary.items_of(build):
		ids.append(id)
	for id: String in parts:
		if not id in ids:
			ids.append(id)
	for id in ids:
		var def := _catalog.get_item(id)
		var key := def.progress_id() if def != null else id
		var at := tier
		if def != null:
			at = clampi(tier, def.tier_min, def.tier_max) as ItemDef.Tier
		var level := cap if at == tier else _rules.tier_max_level[at]
		out[key] = {"tier": at, "level": level}
	return out
