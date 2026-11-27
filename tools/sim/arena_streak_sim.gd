extends SceneTree
## La racha de la arena (OBS-049): tu robot guardado, armado como lo arma el
## juego, contra el rival de cada combate de una racha (Campaign.
## arena_streak_fight) con varias semillas, como en el juego. Da cuanto se
## gana cada paso, la probabilidad de llegar a cada bote y lo que vale de
## media seguir en cada punto. Solo lee el guardado.
##   Godot --headless --path . -s tools/sim/arena_streak_sim.gd ++
##     --save=<ruta>      el guardado (por defecto user://save.json)
##     --zone=N           otra liga (por defecto la suya)
##     --rivals=12        rivales (semillas) por paso
##     --battles=6        combates contra cada uno
##     --player=HARD      dificultad de la IA que hace de jugador
##     --only=N           solo el combate N de la racha (0 es el primero)
##     --campaign=<ruta>  otro campaign.json (para probar una rampa sin tocar
##                        los datos del juego)
##     --aspects=N        todos los aspectos de sus armas y su torso a N
##     --tree=a|b|<ids>   el arbol de mejoras entero (primera o segunda
##                        especializacion) o esos nodos
##     --arena=N          sus armas de brazo y hombro cambiadas por las de
##                        arena de su forma y elemento, de rango N (1-3)
##     --share=X          la parte de lo que lleva de mas que pasa al plus
##                        del rival (A6; por defecto la de arena_gear.json)
##     --rival=MASTER     la IA de todos los rivales (por defecto, la del paso)
##     --from=N           empieza en el rival N (para repartir en procesos)
##     --trace            con --only: imprime un combate jugada a jugada
##     --bench            con --only: juega un combate y mide en cada jugada
##                        lo que tarda en pensar cada dificultad
##     --exact=player|rival|both   esa IA valora los golpes como el motor
##                        (lo hace siempre la implacable, OBS-054)
##     --player-set=k=v,k=v  --rival-set=k=v  cambia valores de su AIConfig
##     --norace=player|rival|both   esa implacable no valora como una carrera
##     --noprotos         su robot sin los prototipos del especialista (como
##                        media el simulador antes del 2026-11-26)
##     --plain-protos     A6 cuenta los prototipos como base, no como de mas
##     --rival-mult=X     el rival multiplica vida y dano por X (en vez de A6)
##     --noterrain        sin el terreno de la arena (OBS-055)
##     --nostates         sin los estados (OBS-055)
##     --noult            sin la definitiva (OBS-055)
##     --exterminio       con --only=N: la oleada N del Exterminio, sus robots
##                        seguidos sin reparar (OBS-055)

## Desde este combate de la racha (0 es el primero) cuenta Titanes (MainScreen.TITAN_STEP).
const TITAN_STEP := 5
const DIFFICULTY := {
	"EASY": BattleAI.Difficulty.EASY,
	"NORMAL": BattleAI.Difficulty.NORMAL,
	"HARD": BattleAI.Difficulty.HARD,
	"MASTER": BattleAI.Difficulty.MASTER,
}

var _rules := RulesConfig.new()
## El terreno de la arena, como en el juego (OBS-055); --noterrain lo quita.
var _terrain: TerrainConfig
## Los estados, como en el juego (OBS-055); --nostates los quita.
var _states: StateConfig
## La definitiva, como en el juego (OBS-055); --noult la quita.
var _ultimate: UltimateConfig


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var path := str(args.get("save", "user://save.json"))
	var rivals := int(args.get("rivals", "12"))
	var battles := int(args.get("battles", "6"))
	var player_ai: BattleAI.Difficulty = DIFFICULTY[str(args.get("player", "HARD"))]
	var only := int(args.get("only", "-1"))
	_rules.crits_enabled = true
	_rules.impact_enabled = true
	_rules.drops_enabled = true
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var campaign := Campaign.load_file(
		str(args.get("campaign", "res://data/campaign.json")), library
	)
	var skills := SkillTree.load_file("res://data/skills.json")
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var tempers := TemperLibrary.load_file("res://data/tempers.json")
	var brief := WorkshopBrief.new()
	brief.rules = _rules
	brief.catalog = catalog
	brief.library = library
	brief.campaign = campaign
	brief.skills = skills
	brief.shop = shop
	brief.progression = Progression.load_file("res://data/progression.json")
	brief.styles = StyleLibrary.load_file("res://data/styles.json", catalog)
	brief.workshop = Workshop.load_file("res://data/workshop.json")
	brief.garage = Garage.load_file("res://data/part_shop.json")
	brief.aspects = PieceAspects.load_file("res://data/aspects.json")
	var tree := UpgradeTree.load_file("res://data/upgrade_tree.json")
	brief.gear = ArenaGear.load_file("res://data/arena_gear.json")
	brief.tree = tree
	# Los prototipos del especialista, como en el juego (faltaban hasta el
	# 2026-11-26: el robot del simulador era mas flojo que el suyo).
	brief.prototypes = PrototypeLibrary.load_file("res://data/prototypes.json")
	if not args.has("noterrain"):
		_terrain = TerrainConfig.load_file("res://data/terrain.json")
	if not args.has("nostates"):
		_states = StateConfig.load_file("res://data/states.json")
	if not args.has("noult"):
		_ultimate = UltimateConfig.load_file("res://data/ultimate.json")
	if args.has("noprotos"):
		brief.prototypes = null
	if not campaign.errors.is_empty():
		print("ERRORES en campaign.json: ", campaign.errors)
		quit(1)
		return

	var profile := PlayerProfile.load_or_new(path)
	var zone := mini(int(args.get("zone", str(profile.zone))), campaign.zone_count() - 1)
	# --aspects=<nivel>: todos los aspectos de sus armas y su torso a ese
	# nivel (OBS-051), para medir cuanto ayudan. No se guarda nada.
	if args.has("aspects"):
		for id in BuildLibrary.items_of(profile.build) + [str(profile.build.get("chest", ""))]:
			var def := catalog.get_item(id)
			var levels := {}
			for aspect in brief.aspects.ids_for(def):
				levels[aspect] = int(args["aspects"])
			if not levels.is_empty():
				profile.aspects[def.progress_id()] = levels
	# --tree=a|b|<nodo,nodo>: el arbol de mejoras entero con la primera (a) o
	# la segunda (b) especializacion de cada bifurcacion, o esos nodos.
	if args.has("tree"):
		profile.tree.assign(_tree_nodes(tree, str(args["tree"])))
	if args.has("arena"):
		ArenaGear.dress(catalog, profile, profile.build, int(args["arena"]))
	var build := brief.build_of(profile, profile.build)
	var titan_build := brief.build_of(profile, profile.build)
	_apply_tree(tree, profile, build, false)
	_apply_tree(tree, profile, titan_build, true)
	# Lo que lleva de mas (A6, StreakEdge): su robot sin prototipos, arbol,
	# aspectos ni rangos de arena, y la parte que pasa al plus del rival.
	# Con --plain-protos los prototipos cuentan como base (como antes).
	var plain := brief.plain_build(profile)
	if args.has("plain-protos"):
		var bare := PlayerProfile.from_dict(profile.to_dict())
		bare.aspects.clear()
		bare.arena_gear.clear()
		bare.tree.clear()
		plain = brief.build_of(bare, bare.build)
	var share := float(args.get("share", str(brief.gear.rival_share)))
	var boost := brief.gear.boost
	var extra := StreakEdge.rival_extra(StreakEdge.extra(_rules, plain, build, boost), share)
	var titan_raw := StreakEdge.extra(_rules, plain, titan_build, boost)
	var titan_extra := StreakEdge.rival_extra(titan_raw, share)
	# --rival-mult=X: el rival multiplica vida y dano por X en vez de lo que
	# mide A6 (para buscar cuanto haria falta).
	if args.has("rival-mult"):
		extra = float(args["rival-mult"]) - 1.0
		titan_extra = extra
	# El poder del jugador, como lo mide el juego (MainScreen._player_items).
	var items: Array[String] = []
	var carried := profile.build.has("assist")
	for id in BuildLibrary.items_of(profile.build):
		var def := catalog.get_item(id)
		if def == null or (carried and def.type == ItemDef.Type.DRONE):
			continue
		if not def.progress_id() in items:
			items.append(def.progress_id())
	var power := Campaign.mean_power(_rules, profile, items)
	var gear := Campaign.loadout_of(build)
	var mult := campaign.reward_mult(zone)
	var base := shop.reward("arena_win") * mult
	print(
		(
			"Liga %d, tu %s (poder medio %.0f), %d rivales x %d combates por paso, %s"
			% [zone + 1, profile.style, power, rivals, battles, _extras(args)]
		)
	)
	print(
		(
			"  lleva de mas: rival x%.2f de vida y dano (x%.2f desde el %d.º, con Titanes; parte %.2f)"
			% [1.0 + extra, 1.0 + titan_extra, TITAN_STEP + 1, share]
		)
	)
	var reach := 1.0
	var pot := 0.0
	var rows: Array[Dictionary] = []
	# --exterminio: oleadas de robots seguidos sin reparar (OBS-055), con
	# --only=N la oleada N (desde 0; sirve pasada la 20).
	if args.has("exterminio"):
		var context := {
			"zone": zone,
			"library": library,
			"catalog": catalog,
			"chassis": chassis,
			"campaign": campaign,
			"shop": shop,
			"skills": skills,
			"tempers": tempers,
			"power": power,
			"gear": gear,
		}
		var mine := [build, titan_build]
		_exterminio(context, mine, [extra, titan_extra], maxi(only, 0), rivals, args)
		quit(0)
		return
	for step in campaign.streak_fights():
		if only >= 0 and step != only:
			continue
		var wins := 0
		var total := 0
		var spent := 0
		var decisions := 0
		var seen := {}
		for r in range(int(args.get("from", "0")), int(args.get("from", "0")) + rivals):
			var seed_value := 1000 + r * 7919
			var fight := campaign.arena_streak_fight(
				zone, library, seed_value, _rules, power, gear, step
			)
			var rival := library.make(
				fight["enemy"],
				catalog,
				_rules,
				fight["tier"],
				fight["level"],
				chassis,
				{},
				fight.get("loadout", {})
			)
			var more := titan_extra if step >= TITAN_STEP else extra
			var edge := float(fight.get("edge", 0.0))
			rival.upgrades = campaign.fight_upgrades(zone, shop, edge, more)
			rival.skills = skills.effects_for(skills.spread(int(fight.get("skills", 0))))
			rival.skills.add(Campaign.kits_of(fight))
			var rival_ai: BattleAI.Difficulty = BattleAI.Difficulty[str(
				args.get("rival", fight["difficulty"])
			)]
			var temper := tempers.config(library.temper_of(fight["enemy"]))
			seen["%s %d" % [Txt.TIER_NAMES[fight["tier"]], fight["level"]]] = true
			if args.has("trace"):
				var mine := titan_build if step >= TITAN_STEP else build
				var player := _ai(player_ai, 1 + r * 31, null, args, "player")
				var foe := _ai(rival_ai, 2 + r * 31, temper, args, "rival")
				_trace(mine, rival, player, foe, int(args.get("seed", "7")))
				quit(0)
				return
			if args.has("bench"):
				_bench(titan_build if step >= TITAN_STEP else build, rival, temper)
				quit(0)
				return
			for n in battles:
				var started := Time.get_ticks_msec()
				var result := BattleRunner.run(
					_rules,
					titan_build if step >= TITAN_STEP else build,
					rival,
					_ai(player_ai, n * 2 + 1 + r * 31, null, args, "player"),
					_ai(rival_ai, n * 2 + 2 + r * 31, temper, args, "rival"),
					n + 7 + r * 13,
					n % 2,
					200,
					_terrain,
					_states,
					_ultimate
				)
				spent += Time.get_ticks_msec() - started
				decisions += int(result["turns"])
				wins += 1 if result["winner"] == 0 else 0
				total += 1
		var rate := float(wins) / total
		var prize := base * campaign.streak_prize(step)
		var sample: Dictionary = campaign.arena_streak_fight(
			zone, library, 1000, _rules, power, gear, step
		)
		rows.append({"rate": rate, "prize": prize, "pot_before": pot})
		reach *= rate
		pot += prize
		print(
			(
				(
					"  combate %d: ganas %3.0f %%  premio %6.0f  bote si ganas %6.0f  llegas %4.1f %%"
					% [step + 1, 100.0 * rate, prize, pot, 100.0 * reach]
				)
				+ (
					"   rival: %s, IA %s, entrenamiento %d, plus %d %% y x%.2f, %.0f ms por turno"
					% [
						", ".join(PackedStringArray(seen.keys())),
						str(args.get("rival", sample["difficulty"])),
						int(sample.get("skills", 0)),
						roundi(100.0 * float(sample.get("edge", 0.0))),
						1.0 + (titan_extra if step >= TITAN_STEP else extra),
						float(spent) / maxf(1.0, float(decisions))
					]
				)
			)
		)
	# Lo que vale seguir: con el bote B tras ganar el combate k, pedir el
	# siguiente da de media p * (B + premio); cobrar da B.
	print("  Seguir o cobrar (media de seguir solo un combate mas):")
	for k in range(1, rows.size()):
		var before: float = rows[k]["pot_before"]
		var keep: float = rows[k]["rate"] * (before + rows[k]["prize"])
		print(
			(
				"    con bote %6.0f: cobrar %6.0f, otro combate %6.0f de media (%s)"
				% [before, before, keep, "conviene" if keep > before else "no conviene"]
			)
		)
	quit(0)


## Una oleada del Exterminio (OBS-055) con varias semillas: sus robots
## seguidos, el del jugador sin reparar entre uno y otro. Da cuantas
## oleadas gana entera, y hasta que robot llega de media.
func _exterminio(
	context: Dictionary, mine: Array, extras: Array, wave: int, rivals: int, args: Dictionary
) -> void:
	var campaign: Campaign = context["campaign"]
	var library: BuildLibrary = context["library"]
	var titan := wave >= TITAN_STEP
	var player_build: MechBuild = mine[1] if titan else mine[0]
	var more: float = extras[1] if titan else extras[0]
	var robots := campaign.exterminio_robots()
	var whole := 0
	var beaten := 0
	var health := 0.0
	for r in rivals:
		var seed_value := 1000 + r * 7919
		var carry: BattleMech = null
		var down := 0
		for robot in robots:
			var fight := campaign.exterminio_fight(
				context["zone"],
				library,
				seed_value + robot * 101,
				_rules,
				context["power"],
				context["gear"],
				wave,
				robot
			)
			var rival := library.make(
				fight["enemy"],
				context["catalog"],
				_rules,
				fight["tier"],
				fight["level"],
				context["chassis"],
				{},
				fight.get("loadout", {})
			)
			rival.upgrades = campaign.fight_upgrades(
				context["zone"], context["shop"], float(fight.get("edge", 0.0)), more
			)
			var skills: SkillTree = context["skills"]
			rival.skills = skills.effects_for(skills.spread(int(fight.get("skills", 0))))
			rival.skills.add(Campaign.kits_of(fight))
			rival.body = Campaign.body_of(fight)
			var tempers: TemperLibrary = context["tempers"]
			var temper := tempers.config(library.temper_of(fight["enemy"]))
			var level: BattleAI.Difficulty = BattleAI.Difficulty[str(fight["difficulty"])]
			var engine := BattleEngine.new(
				_rules, player_build, rival, seed_value + robot, robot % 2
			)
			if carry != null:
				engine.mechs[0].carry_from(carry)
			engine.mechs[0].keep_buffs = true
			engine.set_terrain(_terrain, seed_value + robot)
			if _states != null:
				engine.extra_rules.append(_states)
			engine.set_ultimate(_ultimate)
			var ais: Array[BattleAI] = [
				_ai(
					BattleAI.Difficulty[str(args.get("player", "HARD"))],
					1 + r,
					null,
					args,
					"player"
				),
				_ai(level, 2 + r, temper, args, "rival"),
			]
			while not engine.is_over() and engine.turn_number <= 200:
				var action := ais[engine.turn].choose_action(engine)
				if action == null or engine.apply(action) != "":
					break
			if engine.winner != 0:
				break
			down += 1
			carry = engine.mechs[0].clone()
			health += float(carry.health) / carry.max_health
		beaten += down
		whole += 1 if down == robots else 0
	print(
		(
			"  oleada %d: la gana entera %3.0f %%, tumba %.1f de %d, vida tras cada uno %.0f %%"
			% [
				wave + 1,
				100.0 * whole / rivals,
				float(beaten) / rivals,
				robots,
				100.0 * health / maxf(1.0, float(beaten))
			]
		)
	)


## Imprime un combate jugada a jugada con el estado de los dos.
func _trace(build: MechBuild, rival: MechBuild, a: BattleAI, b: BattleAI, seed_value: int) -> void:
	print("tu robot: ", build.summary(_rules))
	print("rival: ", rival.summary(_rules))
	var engine := BattleEngine.new(_rules, build, rival, seed_value, seed_value % 2)
	engine.set_terrain(_terrain, seed_value)
	if _states != null:
		engine.extra_rules.append(_states)
	engine.set_ultimate(_ultimate)
	print("terreno: ", engine.terrain)
	var ais: Array[BattleAI] = [a, b]
	var printed := 0
	while not engine.is_over() and engine.turn_number <= 80:
		var action := ais[engine.turn].choose_action(engine)
		if action == null or engine.apply(action) != "":
			break
		while printed < engine.events.size():
			var entry: Dictionary = engine.events[printed]
			printed += 1
			var detail := ""
			for key: String in entry:
				if not key in ["event", "turn", "actor", "state", "actions_left"]:
					detail += " %s=%s" % [key, entry[key]]
			var state := ""
			for i in 2:
				var m: Dictionary = entry["state"][i]
				state += (
					"  [%d] p%d v%d c%d/%d e%d/%d"
					% [
						i,
						m["pos"],
						m["health"],
						m["heat"],
						m["heat_cap"],
						m["energy"],
						m["energy_cap"]
					]
				)
			print(
				(
					"t%02d %s %-12s%-40s|%s"
					% [entry["turn"], entry["actor"], entry["event"], detail, state]
				)
			)
	print("gana: ", ["tu robot", "el rival"][engine.winner] if engine.winner >= 0 else "nadie")


## Juega un combate (implacable contra implacable) y en cada jugada mide lo
## que tarda en pensar cada dificultad desde esa misma posicion.
func _bench(build: MechBuild, rival: MechBuild, temper: AIConfig) -> void:
	var engine := BattleEngine.new(_rules, build, rival, 7, 0)
	var levels := [BattleAI.Difficulty.NORMAL, BattleAI.Difficulty.HARD, BattleAI.Difficulty.MASTER]
	var spent := [0, 0, 0]
	var worst := [0, 0, 0]
	var count := 0
	while not engine.is_over() and engine.turn_number < 60:
		var chosen: BattleAction = null
		for i in levels.size():
			var ai := BattleAI.new(levels[i], 3, temper if engine.turn == 1 else null)
			var started := Time.get_ticks_usec()
			var action := ai.choose_action(engine.clone(false))
			var took := Time.get_ticks_usec() - started
			spent[i] += took
			worst[i] = maxi(worst[i], took)
			if i == levels.size() - 1:
				chosen = action
		count += 1
		if chosen == null or engine.apply(chosen) != "":
			break
	# Lo que cuesta cada pieza de la busqueda, en microsegundos.
	var probe := BattleEngine.new(_rules, build, rival, 7, 0)
	var plain_ai := BattleAI.new(BattleAI.Difficulty.HARD, 3)
	var exact_ai := BattleAI.new(BattleAI.Difficulty.MASTER, 3)
	var first: BattleAction = probe.legal_actions()[0]
	var marks := {}
	var t := Time.get_ticks_usec()
	for n in 2000:
		probe.clone()
	marks["clone"] = (Time.get_ticks_usec() - t) / 2000.0
	t = Time.get_ticks_usec()
	for n in 2000:
		probe.clone().apply(first)
	marks["clone+apply"] = (Time.get_ticks_usec() - t) / 2000.0
	t = Time.get_ticks_usec()
	for n in 2000:
		plain_ai.evaluate(probe, 0)
	marks["evaluate"] = (Time.get_ticks_usec() - t) / 2000.0
	t = Time.get_ticks_usec()
	for n in 2000:
		exact_ai.evaluate(probe, 0)
	marks["evaluate exacta"] = (Time.get_ticks_usec() - t) / 2000.0
	t = Time.get_ticks_usec()
	for n in 2000:
		probe.legal_actions()
	marks["legal_actions"] = (Time.get_ticks_usec() - t) / 2000.0
	print("  us: ", marks)
	for i in levels.size():
		print(
			(
				"  %s: %.0f ms de media por jugada, %.0f la peor (%d jugadas, %d acciones posibles al empezar)"
				% [
					BattleAI.Difficulty.keys()[levels[i]],
					spent[i] / 1000.0 / count,
					worst[i] / 1000.0,
					count,
					BattleEngine.new(_rules, build, rival, 7, 0).legal_actions().size()
				]
			)
		)


## Una IA con los cambios de la linea de ordenes para ese lado ("player" o
## "rival"): --exact y --player-set / --rival-set.
static func _ai(
	level: BattleAI.Difficulty, seed_value: int, temper: AIConfig, args: Dictionary, side: String
) -> BattleAI:
	var config: AIConfig = temper.duplicate() if temper != null else AIConfig.new()
	for pair in str(args.get(side + "-set", "")).split(",", false):
		var kv := pair.split("=")
		config.set(kv[0], type_convert(kv[1], typeof(config.get(kv[0]))))
	var ai := BattleAI.new(level, seed_value, config)
	if str(args.get("exact", "")) in [side, "both"]:
		ai.exact_strike = true
	if str(args.get("norace", "")) in [side, "both"]:
		ai.race_eval = false
	return ai


## Los nodos del arbol: "a" o "b" (todo, con esa especializacion en cada
## bifurcacion; solo los que ya funcionan) o una lista separada por comas.
static func _tree_nodes(tree: UpgradeTree, which: String) -> Array[String]:
	var out: Array[String] = []
	if not which in ["a", "b"]:
		out.assign(which.split(","))
		return out
	for branch: Dictionary in tree.branches:
		for options: Array in branch["steps"]:
			var node: Dictionary = options[mini(1 if which == "b" else 0, options.size() - 1)]
			if tree.is_ready(str(node["id"])):
				out.append(str(node["id"]))
	return out


## Lo mismo que MainScreen._apply_tree: el arbol en el robot del jugador.
static func _apply_tree(
	tree: UpgradeTree, profile: PlayerProfile, build: MechBuild, titan: bool
) -> void:
	var grown := tree.effects_for(profile.tree)
	build.skills.add(grown)
	build.upgrades.backfire += float(grown.get("backfire", 0.0))
	build.upgrades.assist += float(grown.get("assist", 0.0))
	if titan:
		build.upgrades.damage += float(grown.get("titan_damage", 0.0))
		build.skills.health += float(grown.get("titan_health", 0.0))


static func _extras(args: Dictionary) -> String:
	var said := [args.get("aspects", "suyos"), args.get("tree", "suyo"), args.get("arena", "-")]
	return "aspectos %s, arbol %s, arena %s" % said
