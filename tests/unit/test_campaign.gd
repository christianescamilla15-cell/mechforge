extends GutTest
## Campana (GDD 9): cada zona son sus combates y un jefe; la arena da celdas
## sin avanzar; perder contra un jefe termina la partida.

const CAMPAIGN_PATH := "res://data/campaign.json"

var _library: BuildLibrary
var _shop: ArenaShop


func before_all() -> void:
	_library = BuildLibrary.load_file("res://data/builds.json")
	_shop = ArenaShop.load_file("res://data/arena_shop.json")


func _campaign() -> Campaign:
	return Campaign.load_file(CAMPAIGN_PATH, _library)


## Perfil que ya gano todos los combates normales de la primera zona.
func _at_boss(campaign: Campaign) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.fight = campaign.fights_in(0)
	profile.gold = 900
	profile.shop_levels["damage"] = 4
	profile.wins = 30
	return profile


func test_la_campana_del_juego_carga_sin_errores() -> void:
	var campaign := _campaign()
	assert_eq(campaign.errors, [] as Array[String])
	assert_gt(campaign.zone_count(), 0)
	assert_eq(campaign.world_bosses, 10, "el mundo tiene 10 jefes")


func test_cada_zona_son_10_combates_y_un_jefe() -> void:
	var campaign := _campaign()
	for zone in campaign.zone_count():
		assert_eq(campaign.fights_in(zone), 10)
		for fight in campaign.fights_in(zone):
			assert_false(campaign.is_boss_fight(zone, fight))
			assert_false(_library.is_boss(campaign.fight_at(zone, fight)["enemy"]))
		assert_true(campaign.is_boss_fight(zone, 10))
		assert_true(_library.is_boss(campaign.fight_at(zone, 10)["enemy"]))


func test_los_rivales_de_una_zona_no_bajan_de_nivel() -> void:
	var campaign := _campaign()
	for zone in campaign.zone_count():
		var top := RulesConfig.new().tier_max_level[campaign.tier_of(zone)]
		var last := 0
		for fight in campaign.fights_in(zone) + 1:
			var level: int = campaign.fight_at(zone, fight)["level"]
			assert_gte(level, last, "combate %d" % (fight + 1))
			assert_lte(level, top, "no pasa del tope de su clase")
			last = level


func test_ganar_un_combate_de_campana_avanza_y_paga() -> void:
	var campaign := _campaign()
	var profile := PlayerProfile.new()
	var result := campaign.finish_fight(profile, _shop, "campaign", true)
	assert_eq(profile.fight, 1)
	assert_eq(result["gold"], _shop.reward("campaign_win"))
	assert_eq(profile.gold, _shop.reward("campaign_win"))
	assert_false(result["game_over"])


func test_perder_un_combate_normal_no_avanza_ni_termina_la_partida() -> void:
	var campaign := _campaign()
	var profile := PlayerProfile.new()
	profile.fight = 3
	var result := campaign.finish_fight(profile, _shop, "campaign", false)
	assert_eq(profile.fight, 3)
	assert_eq(profile.losses, 1)
	assert_false(result["game_over"])


func test_la_arena_paga_sin_avanzar_la_campana() -> void:
	var campaign := _campaign()
	var profile := PlayerProfile.new()
	profile.fight = 2
	assert_eq(
		campaign.finish_fight(profile, _shop, "arena", true)["gold"], _shop.reward("arena_win")
	)
	assert_eq(
		campaign.finish_fight(profile, _shop, "arena", false)["gold"], _shop.reward("arena_loss")
	)
	assert_eq(profile.fight, 2)
	assert_eq(profile.zone, 0)
	assert_gt(_shop.reward("arena_win"), _shop.reward("arena_loss"), "ganar da mas que perder")


func test_vencer_al_jefe_abre_la_zona_siguiente() -> void:
	var campaign := _campaign()
	var profile := _at_boss(campaign)
	var result := campaign.finish_fight(profile, _shop, "campaign", true)
	assert_true(result["zone_cleared"])
	assert_true(result["boss"])
	assert_eq(profile.zone, 1)
	assert_eq(profile.fight, 0)
	assert_eq(profile.boss_wins, 1)
	assert_eq(profile.gold, 900 + _shop.reward("boss_win"))
	assert_eq(profile.level_of("damage"), 4, "conserva lo comprado")


func test_perder_contra_el_jefe_termina_la_partida() -> void:
	var campaign := _campaign()
	assert_eq(campaign.on_boss_loss, "new_game")
	var profile := _at_boss(campaign)
	var result := campaign.finish_fight(profile, _shop, "campaign", false)
	assert_true(result["game_over"])
	assert_eq(profile.gold, 0)
	assert_eq(profile.level_of("damage"), 0)
	assert_eq(profile.zone, 0)
	assert_eq(profile.fight, 0)
	assert_eq(profile.wins, 0)
	assert_eq(profile.runs_lost, 1, "el historial si se conserva")


func test_con_la_regla_de_reintentar_el_jefe_no_borra_nada() -> void:
	var campaign := _campaign()
	campaign.on_boss_loss = "retry"
	var profile := _at_boss(campaign)
	var result := campaign.finish_fight(profile, _shop, "campaign", false)
	assert_false(result["game_over"])
	assert_eq(profile.fight, campaign.fights_in(0), "sigue delante del jefe")
	assert_eq(profile.level_of("damage"), 4)
	assert_eq(profile.gold, 900 + _shop.reward("boss_loss"))


func test_el_mejor_resultado_sobrevive_al_final_de_la_partida() -> void:
	var campaign := _campaign()
	var profile := _at_boss(campaign)
	campaign.finish_fight(profile, _shop, "campaign", true)
	profile.end_run()
	assert_eq(profile.boss_wins, 0)
	assert_eq(profile.best_boss_wins, 1)


func test_el_rival_de_arena_es_un_mech_normal_y_depende_de_la_semilla() -> void:
	var campaign := _campaign()
	var seen := {}
	for seed_value in 40:
		var rival := campaign.arena_fight(0, _library, seed_value)
		assert_false(_library.is_boss(rival["enemy"]))
		seen[rival["enemy"]] = true
	assert_eq(seen.size(), _library.ids().size(), "salen todos los mechs normales")
	assert_eq(campaign.arena_fight(0, _library, 7), campaign.arena_fight(0, _library, 7))


func test_una_zona_con_un_mech_que_no_existe_da_error() -> void:
	var path := "user://test_campaign_mala.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	(
		file
		. store_string(
			(
				JSON
				. stringify(
					{
						"zones":
						[
							{
								"id": "z",
								"tier": "COMMON",
								"player_level": 0,
								"arena": {"level": 0, "difficulty": "NORMAL"},
								"fights":
								[{"enemy": "no_existe", "level": 0, "difficulty": "EASY"}],
								"boss": {"enemy": "jefe_final", "level": 0, "difficulty": "HARD"},
							}
						]
					}
				)
			)
		)
	)
	file.close()
	var campaign := Campaign.load_file(path, _library)
	assert_eq(campaign.zone_count(), 0)
	assert_eq(campaign.errors.size(), 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_un_guardado_de_la_version_1_se_migra() -> void:
	var old := {"schema_version": 1, "gold": 500, "shop_levels": {"heat": 2}, "wins": 9}
	var profile := PlayerProfile.from_dict(old)
	assert_eq(profile.gold, 500)
	assert_eq(profile.level_of("heat"), 2)
	assert_eq(profile.wins, 9)
	assert_eq(profile.zone, 0)
	assert_eq(profile.fight, 0)
	assert_eq(profile.to_dict()["schema_version"], 2)


func test_el_avance_de_campana_se_guarda_y_se_recupera() -> void:
	var profile := PlayerProfile.new()
	profile.zone = 1
	profile.fight = 7
	profile.mech = "calor_horno"
	profile.runs_lost = 2
	var path := "user://test_profile_campana.json"
	assert_true(profile.save(path))
	var loaded := PlayerProfile.load_or_new(path)
	assert_eq(loaded.zone, 1)
	assert_eq(loaded.fight, 7)
	assert_eq(loaded.mech, "calor_horno")
	assert_eq(loaded.runs_lost, 2)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
