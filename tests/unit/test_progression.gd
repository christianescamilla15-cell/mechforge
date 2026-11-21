extends GutTest
## Nivel del jugador y arma de pecho (decisiones del usuario, 2026-11-17): la
## experiencia sube el nivel; el robot de soporte se abre en el nivel 3 y el
## arma de pecho, que va aparte de las seis armas, en el 10.

var _progression: Progression
var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary


func before_all() -> void:
	_progression = Progression.load_file("res://data/progression.json")
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")


func test_los_niveles_del_juego_cargan_sin_errores() -> void:
	assert_eq(_progression.errors, [] as Array[String])
	assert_eq(_progression.level_for(0), 1, "se empieza en el nivel 1")
	assert_gt(_progression.max_level(), 20)


func test_la_experiencia_sube_el_nivel() -> void:
	var win := _progression.xp_for("win")
	assert_gt(win, _progression.xp_for("loss"), "ganar da mas que perder")
	assert_gt(_progression.xp_for("boss_win"), win, "el jefe da mas")
	assert_eq(_progression.level_for(3 * win), 3, "nivel 3 tras unas 3 victorias")
	var at_ten := _progression.levels[9]
	assert_between(at_ten / win, 50, 100, "nivel 10 tras unas 75 victorias")
	assert_eq(_progression.level_for(at_ten - 1), 9)
	assert_eq(_progression.level_for(at_ten), 10)
	assert_eq(_progression.next_level_xp(0), _progression.levels[1])
	assert_eq(_progression.next_level_xp(_progression.levels[-1]), -1, "nivel maximo")


## El asistente, en el nivel 5 (OBS-033; era el 3).
func test_el_soporte_se_abre_en_el_5_y_el_pecho_en_el_10() -> void:
	assert_eq(_progression.unlock_level("drone"), 5)
	assert_eq(_progression.unlock_level("chest"), 10)
	assert_eq(_progression.unlock_level("side0"), 1, "las tres armas desde el principio")
	assert_eq(_progression.unlock_level("top0"), 1)
	assert_false(_progression.is_unlocked("drone", 4))
	assert_true(_progression.is_unlocked("drone", 5))
	assert_false(_progression.is_unlocked("chest", 9))
	assert_true(_progression.is_unlocked("chest", 10))


func test_un_hueco_cerrado_no_pelea() -> void:
	var items: Dictionary = _library.specs["fisico_vanguardia_canon"]["items"].duplicate(true)
	items["chest"] = "canon_pesado_canon_cin"
	var build := _catalog.make_build(items, _rules, ItemDef.Tier.RARE, 0)
	assert_not_null(build.chest)
	assert_not_null(build.drone)
	_progression.apply_locks(build, 4)
	assert_null(build.drone, "sin soporte antes del nivel 5")
	assert_null(build.chest)
	var later := _catalog.make_build(items, _rules, ItemDef.Tier.RARE, 0)
	_progression.apply_locks(later, 10)
	assert_not_null(later.drone)
	assert_not_null(later.chest)


func test_el_arma_de_pecho_pelea_como_un_arma_mas() -> void:
	var build := Fx.build([Fx.gun()])
	build.chest = Fx.item(ItemDef.Type.CHEST, {"weight": 60, "dmg_min": 300, "dmg_max": 300})
	var engine := Fx.engine(build, Fx.build())
	assert_has(engine.mechs[0].weapon_keys(), "chest")
	assert_eq(engine.apply(BattleAction.weapon("chest")), "")
	assert_eq(engine.mechs[1].health, engine.mechs[1].max_health - 300)
	var plain := Fx.build([Fx.gun()])
	assert_eq(build.total_weight(), plain.total_weight() + 60, "pesa como cualquier arma")


func test_el_catalogo_tiene_las_111_armas_y_15_de_pecho() -> void:
	assert_eq(_catalog.by_type(ItemDef.Type.CHEST).size(), 15)
	var weapons := 0
	for type in [ItemDef.Type.SIDE, ItemDef.Type.TOP, ItemDef.Type.CHEST, ItemDef.Type.DRONE]:
		weapons += _catalog.by_type(type).size()
	assert_eq(weapons, 111)
	for def in _catalog.by_type(ItemDef.Type.CHEST):
		assert_true(def.weapon_type in ["canon", "blaster", "laser"], def.id)
		assert_gt(def.uses, 0, "%s tiene pocos usos" % def.id)


func test_el_pecho_se_monta_en_el_taller() -> void:
	assert_eq(Garage.slot_type("chest"), ItemDef.Type.CHEST)
	var profile := PlayerProfile.new()
	profile.start_run(_library, "fisico_vanguardia")
	profile.owned.append("nova_blaster_cin")
	assert_eq(Garage.equip(profile, _catalog, "chest", "nova_blaster_cin"), "")
	assert_eq(Garage.get_slot(profile.build, "chest"), "nova_blaster_cin")
	assert_eq(Garage.equip(profile, _catalog, "side0", "nova_blaster_cin"), "no va en ese hueco")


func test_los_combates_dan_experiencia_menos_la_derrota_ante_el_jefe() -> void:
	var campaign := Campaign.load_file("res://data/campaign.json", _library)
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var profile := PlayerProfile.new()
	var result := campaign.finish_fight(profile, shop, "arena", true, _progression)
	assert_eq(result["xp"], _progression.xp_for("win"))
	assert_eq(profile.xp, _progression.xp_for("win"))
	campaign.finish_fight(profile, shop, "arena", false, _progression)
	assert_eq(profile.xp, _progression.xp_for("win") + _progression.xp_for("loss"))
	profile.fight = campaign.fights_in(0)
	var lost := campaign.finish_fight(profile, shop, "campaign", false, _progression)
	assert_true(lost["game_over"])
	assert_eq(profile.xp, 0, "perder contra el jefe borra tambien la experiencia")


func test_subir_de_nivel_se_avisa_y_se_guarda() -> void:
	var campaign := Campaign.load_file("res://data/campaign.json", _library)
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var profile := PlayerProfile.new()
	profile.xp = _progression.levels[2] - 1
	var result := campaign.finish_fight(profile, shop, "arena", true, _progression)
	assert_true(result["level_up"])
	var path := "user://test_profile_nivel.json"
	assert_true(profile.save(path))
	assert_eq(PlayerProfile.load_or_new(path).xp, profile.xp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old := PlayerProfile.from_dict({"schema_version": 4, "gold": 10})
	assert_eq(old.xp, 0)
	assert_eq(old.to_dict()["schema_version"], PlayerProfile.SCHEMA_VERSION)
