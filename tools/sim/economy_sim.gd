extends SceneTree
## Simulador de economia (GDD 9.2): cuanto acerca al jefe de una zona juntar
## N victorias y gastarlas. El jugador compra siempre lo mas barato que pueda
## pagar entre subir una pieza, transformarla y las mejoras de la armeria,
## hasta quedarse sin celdas; despues pelea contra el jefe de la zona. Usa el
## mismo codigo de compra que el juego (PlayerProfile).
##
## Uso (tras `++`):
##   --zone=0                  zona
##   --wins=10;25;50;75;100    victorias que se cobran y se gastan
##   --battles=30              combates por mech y casilla
##   --start-tier=COMMON       clase de las piezas al llegar (por defecto, Basica)
##   --start-level=0           nivel de las piezas al llegar
##   --start-armory=0          nivel de las mejoras de la armeria al llegar
##   --start-xp=-1             experiencia al llegar a la zona; con ella el
##                             jugador lleva los puntos de habilidad de su
##                             nivel al llegar al jefe (los combates de la
##                             zona y las N victorias suman experiencia),
##                             repartidos por igual entre las ramas. -1 = sin
##                             habilidades
##   --boss-skills=N           puntos del jefe (por defecto, los de la campana)
##   --enemy-armory=N          armeria del Orden en la zona (por defecto, la
##                             de la campana)
##   --chest=bought|owned|none arma de pecho del jugador (canon pesado de su
##                             elemento): comprada en esta zona (se paga
##                             con las celdas), traida de antes, o ninguna
##   --seed=1
## Las victorias se cobran a la tarifa de la arena de la zona. Bonificaciones
## encendidas; el jugador juega con la IA dificil y el jefe con la de la
## campana. Se alterna quien empieza.

const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
}

var _rules := RulesConfig.new()
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _builds: Dictionary[String, MechBuild] = {}
var _boss_ai: BattleAI.Difficulty = BattleAI.Difficulty.HARD
var _states: Dictionary = {}


func _initialize() -> void:
	var args := _parse_args()
	var battles := int(args.get("battles", "30"))
	var seed_value := int(args.get("seed", "1"))
	var zone := int(args.get("zone", "0"))
	var start_tier: int = ItemDef.Tier[args.get("start-tier", "COMMON")]
	var start_level := int(args.get("start-level", "0"))
	var start_armory := int(args.get("start-armory", "0"))
	var chest_mode: String = args.get("chest", "none")
	var start_xp := int(args.get("start-xp", "-1"))
	var wins_list: Array[int] = []
	for text: String in str(args.get("wins", "10;25;50;75;100")).split(";"):
		wins_list.append(int(text))
	_rules.drops_enabled = true
	_rules.crits_enabled = not OS.get_cmdline_user_args().has("--no-crits")
	_rules.impact_enabled = not OS.get_cmdline_user_args().has("--no-impact")

	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var workshop := Workshop.load_file("res://data/workshop.json")
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var garage := Garage.load_file("res://data/part_shop.json")
	var tree := SkillTree.load_file("res://data/skills.json")
	var progression := Progression.load_file("res://data/progression.json")
	var problems := (
		catalog.errors
		+ library.errors
		+ chassis.errors
		+ shop.errors
		+ workshop.errors
		+ campaign.errors
	)
	if not problems.is_empty() or zone >= campaign.zone_count():
		printerr("datos con errores: ", problems)
		quit(2)
		return

	var tier := campaign.tier_of(zone)
	var boss := campaign.fight_at(zone, campaign.fights_in(zone))
	_builds["boss"] = library.make(boss["enemy"], catalog, _rules, tier, boss["level"], chassis)
	var enemy_armory := int(args.get("enemy-armory", str(campaign.enemy_armory(zone))))
	var enemy_levels := {}
	for track in shop.track_ids():
		enemy_levels[track] = enemy_armory
	_builds["boss"].upgrades = shop.upgrades_for(enemy_levels)
	var boss_skills := int(args.get("boss-skills", str(campaign.boss_skills(zone))))
	_builds["boss"].skills = tree.effects_for(tree.spread(boss_skills))
	var points_line: Array[String] = []
	_boss_ai = DIFFICULTY[boss["difficulty"]]
	var reward := shop.reward("arena_win") * campaign.reward_mult(zone)
	for wins in wins_list:
		var points := 0
		if start_xp >= 0:
			var fights := campaign.fights_in(zone) + wins
			var xp := start_xp + fights * progression.xp_for("win")
			points = (progression.level_for(xp) - 1) * tree.points_per_level
		var skills := tree.effects_for(tree.spread(points))
		points_line.append("%d vict. %d" % [wins, points])
		for id in library.band_ids(campaign.band_of(zone)):
			var items: Dictionary = library.specs[id]["items"].duplicate(true)
			var chest := ""
			if chest_mode != "none":
				chest = _chest_for(catalog, library.element_of(id), campaign.band_of(zone))
				items["chest"] = chest
				_fit_weight(items, catalog)
			var profile := PlayerProfile.new()
			var levelable := _levelable(items, catalog)
			for item: String in levelable:
				profile.parts[item] = {"tier": start_tier, "level": start_level}
			for track in shop.track_ids():
				profile.shop_levels[track] = start_armory
			profile.gold = roundi(wins * reward)
			if chest_mode == "bought":
				# Se compra en la tienda de la zona: llega en su clase, nivel 0.
				profile.parts[chest] = {"tier": tier, "level": 0}
				profile.gold -= garage.price(catalog, _rules, workshop, chest, tier)
			var cap := campaign.level_cap(zone)
			if profile.gold > 0:
				_spend(profile, levelable, tier, cap, workshop, shop)
			var key := "%s@%d" % [id, wins]
			_states[key] = profile
			var build := catalog.make_build(items, _rules, ItemDef.Tier.COMMON, 0, profile.parts)
			build.skills = skills
			build.upgrades = shop.upgrades_for(profile.shop_levels)
			_builds[key] = build
			for n in battles:
				seed_value += 1
				_tasks.append(
					{"player": key, "id": id, "wins": wins, "seed": seed_value, "starter": n % 2}
				)
	print(
		(
			(
				"Zona %d (%s), jefe %s (%s nivel %d, Orden %d, %d habilidades)."
				+ " Al llegar: %s %d, armeria %d."
			)
			% [
				zone + 1,
				campaign.zone_name(zone),
				library.display_name(boss["enemy"]),
				Txt.TIER_NAMES[tier],
				boss["level"],
				enemy_armory,
				boss_skills,
				Txt.TIER_NAMES[start_tier],
				start_level,
				start_armory,
			]
		)
	)
	if start_xp >= 0:
		print("Puntos de habilidad del jugador: ", ", ".join(points_line))
	_results.resize(_tasks.size())
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	_report(wins_list, library, library.band_ids(campaign.band_of(zone)), shop, battles, reward)
	quit(0)


## Canon pesado del elemento del mech (los hibridos, fisico) y del tipo de
## arma de la zona; si la zona no tiene, el de canon.
func _chest_for(catalog: Catalog, element: String, band: String) -> String:
	var ammo := {"PHYSICAL": "cin", "HEAT": "ter", "ENERGY": "ion"}
	var suffix: String = ammo.get(element, "cin")
	for type_id: String in [band, "canon", "blaster", "laser"]:
		var id := "canon_pesado_%s_%s" % [type_id, suffix]
		if catalog.get_item(id) != null:
			return id
	return ""


## Quita modulos (primero los repetidos) hasta que el mech pese lo permitido,
## como haria el jugador al montar el arma de pecho.
func _fit_weight(items: Dictionary, catalog: Catalog) -> void:
	var modules: Array = items.get("modules", []).duplicate()
	while _weight(items, catalog) > _rules.max_weight and not modules.is_empty():
		var repeated := modules.filter(func(m: Variant) -> bool: return modules.count(m) > 1)
		modules.erase(repeated[-1] if not repeated.is_empty() else modules[-1])
		items["modules"] = modules


func _weight(items: Dictionary, catalog: Catalog) -> int:
	var total := 0
	# El arma de pecho no cuenta para el limite (MechBuild.total_weight), ni
	# el robot de asistencia y su arma inferior.
	for key: String in ["torso", "legs", "drone", "charge", "teleport", "hook"]:
		if str(items.get(key, "")) != "":
			total += catalog.get_item(items[key]).weight
	for key: String in ["sides", "tops", "modules"]:
		for id: Variant in items.get(key, []):
			if str(id) != "":
				total += catalog.get_item(id).weight
	return total


## Claves de progreso de las piezas que se suben en el taller, con la clase
## maxima de cada una. Las armas del asistente no: suben con el.
func _levelable(items: Dictionary, catalog: Catalog) -> Dictionary:
	var out := {}
	var carried := items.has("assist")
	for id in BuildLibrary.items_of(items):
		var def := catalog.get_item(id)
		if carried and def.type == ItemDef.Type.DRONE:
			continue
		out[def.progress_id()] = def.tier_max
	return out


## Compra lo mas barato que pueda pagar hasta quedarse sin celdas. `items`
## son las claves de progreso con su clase maxima (_levelable). La bateria
## del asistente solo se compra cuando ya pelea con dos armas.
func _spend(
	profile: PlayerProfile,
	items: Dictionary,
	max_tier: int,
	cap_level: int,
	workshop: Workshop,
	shop: ArenaShop
) -> void:
	while true:
		var best_cost := -1
		var best: Callable
		var two_weapons: bool = (
			items.has(ItemDef.ASSIST_PROGRESS)
			and profile.part(ItemDef.ASSIST_PROGRESS)["tier"] >= _rules.assist_second_weapon_tier
		)
		for id: String in items:
			var p := profile.part(id)
			var item_max: int = items[id]
			var cost := -1
			var action: Callable
			var level_reason := profile.why_cant_level(workshop, _rules, id, max_tier, cap_level)
			if level_reason in ["", "faltan celdas"]:
				cost = workshop.level_cost(_rules, p["tier"], p["level"])
				action = profile.level_up.bind(workshop, _rules, id, max_tier, cap_level)
			elif (
				p["level"] >= _rules.tier_max_level[p["tier"]]
				and (
					profile.why_cant_transform(workshop, _rules, id, max_tier, item_max)
					in ["", "faltan celdas"]
				)
			):
				cost = workshop.transform_cost(p["tier"])
				action = profile.transform.bind(workshop, _rules, id, max_tier, item_max)
			if cost >= 0 and (best_cost < 0 or cost < best_cost):
				best_cost = cost
				best = action
		for track in shop.track_ids():
			if track == "assist" and not two_weapons:
				continue
			var level := profile.level_of(track)
			if level < shop.max_level() and (best_cost < 0 or shop.price(level + 1) < best_cost):
				best_cost = shop.price(level + 1)
				best = profile.buy.bind(shop, track)
		if best_cost < 0 or best_cost > profile.gold:
			return
		best.call()


func _run_task(index: int) -> void:
	var task := _tasks[index]
	_results[index] = BattleRunner.run(
		_rules,
		_builds[task["player"]],
		_builds["boss"],
		BattleAI.new(BattleAI.Difficulty.HARD, task["seed"] * 2 + 1),
		BattleAI.new(_boss_ai, task["seed"] * 2 + 2),
		task["seed"],
		task["starter"]
	)


func _report(
	wins_list: Array[int],
	library: BuildLibrary,
	ids: Array[String],
	shop: ArenaShop,
	battles: int,
	reward: float
) -> void:
	var won := {}
	for index in _tasks.size():
		var task := _tasks[index]
		var key := "%s@%d" % [task["id"], task["wins"]]
		won[key] = won.get(key, 0) + (1 if _results[index]["winner"] == 0 else 0)
	print("Victorias contra el jefe tras gastar N victorias (%d combates por casilla):" % battles)
	var header := "  victorias   celdas  piezas (media)  armeria (media)"
	for id in ids:
		header += "  %8s" % id.split("_")[0]
	print(header + "    media")
	for wins in wins_list:
		var parts_power := 0.0
		var armory := 0.0
		var total := 0.0
		var line := ""
		for id in ids:
			var key := "%s@%d" % [id, wins]
			var profile: PlayerProfile = _states[key]
			var items := library.item_ids(id)
			parts_power += Campaign.mean_power(_rules, profile, items)
			for track in shop.track_ids():
				armory += profile.level_of(track)
			var rate: float = 100.0 * int(won[key]) / battles
			total += rate
			line += "  %6.1f %%" % rate
		parts_power /= ids.size()
		armory /= ids.size() * shop.track_ids().size()
		print(
			(
				"  %9d  %7d  %14s  %15.1f%s  %5.1f %%"
				% [
					wins,
					roundi(wins * reward),
					_level_text(parts_power),
					armory,
					line,
					total / ids.size()
				]
			)
		)


## Poder medio de las piezas como "Basica 3.4": la clase y el nivel equivalentes.
func _level_text(power: float) -> String:
	for tier in range(ItemDef.Tier.DIVINE, -1, -1):
		var base := ItemScaling.power(_rules, tier, 0)
		if power >= base - 0.0001:
			var top := _rules.tier_max_level[tier]
			var level := (power / _rules.tier_mult[tier] - 1.0) / _rules.level_bonus * top
			return "%s %.1f" % [Txt.TIER_NAMES[tier].substr(0, 3), level]
	return "?"


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var parts := text.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
