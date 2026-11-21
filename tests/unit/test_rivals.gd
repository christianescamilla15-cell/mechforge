extends GutTest
## Los rivales normales de la campana saben hacer algo mas que disparar
## (OBS-014 de docs/OBSERVACIONES.md: "los enemigos no hacen mas que atacar;
## no usan habilidades, no usan estrategia"). Medido el 2026-11-21 con
## tools/sim/behavior_sim.gd: gastaban del 80 al 95 % de sus acciones en
## disparar y ninguna en habilidades, porque no llevaban. Ahora cada combate
## puede dar a su rival un escudo, un kit de reparacion o los dos ("kits").

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _campaign: Campaign
var _brief: MissionBrief


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_campaign = Campaign.load_file("res://data/campaign.json", _library)
	_brief = MissionBrief.new()
	_brief.rules = _rules
	_brief.catalog = _catalog
	_brief.library = _library
	_brief.chassis = ChassisLibrary.load_file("res://data/chassis.json")
	_brief.campaign = _campaign
	_brief.shop = ArenaShop.load_file("res://data/arena_shop.json")


func _rival(fight: Dictionary) -> MechBuild:
	var build := _library.make(fight["enemy"], _catalog, _rules, ItemDef.Tier.COMMON, 0)
	build.skills = SkillSet.new()
	build.skills.add(Campaign.kits_of(fight))
	return build


func test_la_campana_carga_con_las_habilidades_de_sus_rivales() -> void:
	assert_eq(_campaign.errors, [] as Array[String])
	for zone in _campaign.zone_count():
		var with_kits := 0
		# La liga 1 empieza desde abajo (OBS-031): un combate mas sin habilidades.
		var plain := 4 if zone == 0 else 3
		for fight in _campaign.fights_in(zone):
			var kits := Campaign.kits_of(_campaign.fight_at(zone, fight))
			if fight < plain:
				assert_true(kits.is_empty(), "los primeros de la zona %d solo disparan" % zone)
			elif not kits.is_empty():
				with_kits += 1
			for kit: String in kits:
				assert_has(Campaign.KITS, kit)
		assert_eq(with_kits, _campaign.fights_in(zone) - plain, "zona %d: los demas, todos" % zone)


func test_no_todos_llevan_lo_mismo() -> void:
	var seen := {}
	for fight in _campaign.fights_in(0):
		var kits := Campaign.kits_of(_campaign.fight_at(0, fight))
		var keys: Array = kits.keys()
		keys.sort()
		seen[",".join(keys)] = true
	assert_gte(seen.size(), 4, "sin nada, con escudo, con reparacion y con los dos")


func test_un_rival_sale_al_combate_con_lo_que_dice_su_combate() -> void:
	var shield := _rival({"enemy": "calor_horno", "kits": {"shield_uses": 1}})
	var mech := BattleMech.new(shield, _rules)
	assert_eq(mech.kits_left("shield"), 1)
	assert_eq(mech.kits_left("repair"), 0)
	var both := _rival(
		{"enemy": "calor_horno", "kits": {"shield_uses": 1, "repair_uses": 1, "repair_share": 0.2}}
	)
	mech = BattleMech.new(both, _rules)
	assert_eq(mech.kits_left("shield"), 1)
	assert_eq(mech.kits_left("repair"), 1)
	assert_almost_eq(both.skills.repair_share, 0.2, 0.0001)
	assert_eq(BattleMech.new(_rival({"enemy": "calor_horno"}), _rules).kits_left("shield"), 0)


func test_una_habilidad_que_no_existe_no_carga() -> void:
	var raw := {"enemy": "calor_horno", "level": 0, "difficulty": "EASY", "kits": {"volar": 1}}
	assert_string_contains(_campaign._fight_problem(raw, _library), "volar")
	raw["kits"] = {"shield_uses": 1}
	assert_eq(_campaign._fight_problem(raw, _library), "")


func test_con_habilidades_el_rival_las_usa_en_combate() -> void:
	var player := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 3)
	var rival := _rival(
		{"enemy": "calor_horno", "kits": {"shield_uses": 1, "repair_uses": 1, "repair_share": 0.2}}
	)
	var used := {"shield": 0, "repair": 0}
	for seed_value in 6:
		var engine := BattleEngine.new(_rules, player, rival, seed_value + 1, seed_value % 2)
		var ais: Array[BattleAI] = [
			BattleAI.new(BattleAI.Difficulty.NORMAL, seed_value * 2 + 1),
			BattleAI.new(BattleAI.Difficulty.NORMAL, seed_value * 2 + 2),
		]
		while not engine.is_over() and engine.turn_number <= 200:
			var who := engine.turn
			var action := ais[who].choose_action(engine)
			if action == null or engine.apply(action) != "":
				break
			if who == 1 and action.type == BattleAction.Type.SHIELD:
				used["shield"] += 1
			if who == 1 and action.type == BattleAction.Type.REPAIR:
				used["repair"] += 1
	assert_gt(used["shield"], 0, "en seis combates levanta el escudo alguna vez")
	assert_gt(used["repair"], 0, "y se repara alguna vez")
	assert_lte(used["shield"], 6, "una vez por combate como mucho")
	assert_lte(used["repair"], 6)


func test_el_hangar_dice_lo_que_sabe_hacer_el_rival() -> void:
	var plain := _brief.rival({"enemy": "calor_horno", "level": 0, "difficulty": "EASY"}, 0)
	assert_false(str(plain["traits"]).contains("escudo"))
	var shield := _brief.rival(
		{"enemy": "calor_horno", "level": 0, "difficulty": "EASY", "kits": {"shield_uses": 1}}, 0
	)
	assert_string_contains(str(shield["traits"]), "con escudo")
	var both := _brief.rival(
		{
			"enemy": "calor_horno",
			"level": 0,
			"difficulty": "EASY",
			"kits": {"shield_uses": 1, "repair_uses": 1, "repair_share": 0.2}
		},
		0
	)
	assert_string_contains(str(both["traits"]), "escudo y reparación")


# --- Un cuerpo propio (OBS-011: "cada enemigo de cada liga debe ser diferente") ---


func test_un_rival_puede_llevar_un_cuerpo_propio() -> void:
	assert_eq(Campaign.body_of({"enemy": "calor_horno"}), "")
	assert_eq(Campaign.body_of({"enemy": "calor_horno", "body": "jefe_103"}), "jefe_103")
	assert_eq(Campaign.body_of({"body": 7}), "", "lo que no es un nombre no cuenta")
	# El hangar lo arma con ese cuerpo: entero, de un solo juego de dibujos.
	var entry := {"enemy": "calor_horno", "level": 0, "difficulty": "EASY", "body": "jefe_103"}
	var build: MechBuild = _brief.rival(entry, 0)["build"]
	assert_eq(build.body, "jefe_103")
	var sprites := MechSprites.for_build(build)
	assert_eq(sprites.torso_set, "jefe_103")
	assert_eq(sprites.legs_set, "jefe_103")
	assert_false(sprites.is_boss, "no es un jefe: lleva sus armas a la vista")
	# Sin cuerpo propio, o con uno que no existe, se ve por sus piezas.
	entry.erase("body")
	var plain: MechBuild = _brief.rival(entry, 0)["build"]
	assert_eq(plain.body, "")
	assert_true(MechSprites.for_build(plain).torso_set in MechSprites.TORSO_SETS)
	plain.body = "no_existe"
	assert_true(MechSprites.for_build(plain).torso_set in MechSprites.TORSO_SETS)
	# El cuerpo no cambia como pelea: pesa y mide lo mismo.
	assert_eq(build.summary(_rules), plain.summary(_rules))


func test_los_cuerpos_que_pide_la_campana_estan_dibujados() -> void:
	for zone in _campaign.zone_count():
		for fight in _campaign.fights_in(zone) + 1:
			var body := Campaign.body_of(_campaign.fight_at(zone, fight))
			if body == "":
				continue
			var drawn := (
				MechSprites.has_piece(body, "torso") and MechSprites.has_piece(body, "legs")
			)
			assert_true(
				drawn, "liga %d, combate %d: falta el dibujo de '%s'" % [zone + 1, fight + 1, body]
			)
	# Un cuerpo mal escrito no carga.
	var bad := {"enemy": "calor_horno", "level": 0, "difficulty": "EASY", "body": 3}
	assert_ne(_campaign._fight_problem(bad, _library), "")


# --- La liga 1 empieza desde abajo (OBS-031) ----------------------------------------


## Cuantas piezas lleva el rival de un combate, armado como sale.
func _gear(fight: int) -> Dictionary:
	var build: MechBuild = _brief.rival(_campaign.fight_at(0, fight), 0)["build"]
	return {
		"sides": build.sides.size(),
		"tops": build.tops.size(),
		"modules": build.modules.size(),
		"assist": build.assist != null
	}


func test_el_primer_rival_de_la_campana_sale_como_tu_con_una_sola_arma() -> void:
	# Del usuario: "esta muy roto el primer rival de la campana, me derroto a
	# pesar de llevar todas las mejoras". Salia armado entero.
	assert_eq(_gear(0), {"sides": 1, "tops": 0, "modules": 0, "assist": false})
	var first := _campaign.fight_at(0, 0)
	assert_eq(first["difficulty"], "EASY")
	assert_eq(int(first["level"]), 0)
	# Y de ahi crece combate a combate, sin dar pasos atras.
	var before := 0
	for fight in _campaign.fights_in(0):
		var gear := _gear(fight)
		var total: int = gear["sides"] + gear["tops"] + gear["modules"]
		assert_gte(total, before, "combate %d" % (fight + 1))
		before = total
	assert_gte(_gear(9)["sides"], 4, "el decimo ya va con sus cuatro armas")
	# Las demas ligas no cambian: se llega a ellas con el robot armado.
	for fight in _campaign.fights_in(1):
		assert_false(_campaign.fight_at(1, fight).has("loadout"))


func test_un_robot_inicial_puede_con_el_primer_rival() -> void:
	var styles := StyleLibrary.load_file("res://data/styles.json", _catalog)
	var tempers := TemperLibrary.load_file("res://data/tempers.json")
	var spec := _campaign.fight_at(0, 0)
	var rival: MechBuild = _brief.rival(spec, 0)["build"]
	for style_id in styles.ids():
		var player := _catalog.make_build(styles.build(style_id), _rules, ItemDef.Tier.COMMON, 0)
		player.skills = SkillSet.new()
		styles.add_effects(style_id, player.skills)
		var wins := 0
		for seed_value in 6:
			var result := BattleRunner.run(
				_rules,
				player,
				rival,
				BattleAI.new(BattleAI.Difficulty.NORMAL, seed_value * 2 + 1),
				BattleAI.new(
					BattleAI.Difficulty.EASY,
					seed_value * 2 + 2,
					tempers.config(_library.temper_of(spec["enemy"]))
				),
				seed_value + 1,
				seed_value % 2
			)
			wins += 1 if result["winner"] == 0 else 0
		assert_gte(wins, 4, "%s, con su unica arma: %d de 6" % [style_id, wins])
