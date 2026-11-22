extends GutTest
## Campana (GDD 9): cada zona es una liga, con sus combates y su campeon;
## la arena da celdas sin avanzar. Reglas de liga (docs/OBSERVACIONES.md,
## OBS-020 y OBS-021): empezar la campana cierra la arena y el combate
## libre; perder en ella acaba la partida, salvo que se lleve proteccion.

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


func test_perder_un_combate_de_la_campana_acaba_la_partida() -> void:
	var campaign := _campaign()
	assert_eq(campaign.on_loss, "new_game")
	var profile := PlayerProfile.new()
	profile.fight = 3
	profile.gold = 900
	profile.shop_levels["damage"] = 4
	var result := campaign.finish_fight(profile, _shop, "campaign", false)
	assert_true(result["game_over"], "sin proteccion, perder un combate cualquiera lo acaba todo")
	assert_eq(result["protected"], "")
	assert_eq(profile.fight, 0)
	assert_eq(profile.gold, 0)
	assert_eq(profile.level_of("damage"), 0)
	assert_eq(profile.runs_lost, 1, "el historial si se conserva")


func test_la_arena_paga_sin_avanzar_la_campana() -> void:
	var campaign := _campaign()
	var profile := PlayerProfile.new()
	profile.fight = 2
	# Ganar pone el premio en el bote de la racha (OBS-049); se cobra al volver.
	assert_eq(
		campaign.finish_fight(profile, _shop, "arena", true)["prize"], _shop.reward("arena_win")
	)
	assert_eq(campaign.cash_arena(profile), _shop.reward("arena_win"))
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


func test_perder_contra_el_campeon_termina_la_partida() -> void:
	var campaign := _campaign()
	var profile := _at_boss(campaign)
	var result := campaign.finish_fight(profile, _shop, "campaign", false)
	assert_true(result["game_over"])
	assert_eq(profile.gold, 0)
	assert_eq(profile.level_of("damage"), 0)
	assert_eq(profile.zone, 0)
	assert_eq(profile.fight, 0)
	assert_eq(profile.wins, 0)
	assert_false(profile.campaign_on)
	assert_eq(profile.runs_lost, 1, "el historial si se conserva")


func test_con_la_regla_de_reintentar_perder_no_borra_nada() -> void:
	var campaign := _campaign()
	campaign.on_loss = "retry"
	var profile := _at_boss(campaign)
	var result := campaign.finish_fight(profile, _shop, "campaign", false)
	assert_false(result["game_over"])
	assert_eq(profile.fight, campaign.fights_in(0), "sigue delante del jefe")
	assert_eq(profile.level_of("damage"), 4)
	assert_eq(profile.gold, 900 + _shop.reward("boss_loss"))


# --- Reglas de liga (OBS-020, OBS-021) ---------------------------------------------


func test_empezar_la_campana_cierra_la_arena_y_el_combate_libre() -> void:
	var campaign := _campaign()
	var profile := PlayerProfile.new()
	assert_false(campaign.mode_locked(profile, "arena"), "antes de empezar, la arena esta abierta")
	assert_false(campaign.mode_locked(profile, "free"))
	campaign.begin_fight(profile)
	assert_true(profile.campaign_on)
	assert_true(campaign.mode_locked(profile, "arena"))
	assert_true(campaign.mode_locked(profile, "free"))
	assert_false(campaign.mode_locked(profile, "campaign"), "la campana nunca se cierra")
	# Ganar sigue dentro de la campana.
	campaign.finish_fight(profile, _shop, "campaign", true)
	assert_true(campaign.mode_locked(profile, "arena"))


## OBS-037, del usuario: "en caso de que no pueda derrotar a un jefe porque
## sea muy dificil, tengo la opcion de farmear... y subir de nivel jugando
## en la arena".
func test_con_solo_el_campeon_por_delante_la_arena_se_abre_para_entrenar() -> void:
	var campaign := _campaign()
	var progression := Progression.load_file("res://data/progression.json")
	var profile := PlayerProfile.new()
	campaign.begin_fight(profile)
	profile.fight = campaign.fights_in(0) - 1
	assert_true(campaign.mode_locked(profile, "arena"), "con rivales por delante, cerrada")
	profile.fight = campaign.fights_in(0)
	assert_true(campaign.at_champion(profile))
	assert_false(campaign.mode_locked(profile, "arena"), "delante del campeon, abierta")
	assert_true(campaign.mode_locked(profile, "free"), "el combate libre sigue cerrado")
	# Lo que se gana en la arena se queda, y perder ahi no toca la campana.
	var xp := profile.xp
	var gold := profile.gold
	campaign.finish_fight(profile, _shop, "arena", true, progression)
	campaign.cash_arena(profile)
	assert_gt(profile.xp, xp)
	assert_gt(profile.gold, gold)
	campaign.finish_fight(profile, _shop, "arena", false, progression)
	assert_true(profile.campaign_on)
	assert_eq(profile.fight, campaign.fights_in(0), "sigue delante del campeon")


func test_vencer_al_campeon_abre_la_liga_siguiente_con_todo_abierto() -> void:
	var campaign := _campaign()
	var profile := _at_boss(campaign)
	profile.campaign_on = true
	campaign.finish_fight(profile, _shop, "campaign", true)
	assert_eq(profile.zone, 1)
	assert_false(profile.campaign_on, "la liga nueva empieza sin tocar")
	assert_false(campaign.mode_locked(profile, "arena"))


func test_el_seguro_de_liga_devuelve_al_comienzo_de_la_liga() -> void:
	var campaign := _campaign()
	var profile := PlayerProfile.new()
	profile.zone = 1
	profile.fight = 5
	profile.campaign_on = true
	profile.gold = 900
	profile.shop_levels["damage"] = 4
	profile.protections["league"] = 1
	assert_false(campaign.loss_ends_run(profile))
	var result := campaign.finish_fight(profile, _shop, "campaign", false)
	assert_false(result["game_over"])
	assert_eq(result["protected"], "league")
	assert_eq(profile.zone, 1, "sigue en su liga")
	assert_eq(profile.fight, 0, "desde el primer combate")
	assert_false(profile.campaign_on, "con la campana sin empezar: arena abierta")
	assert_eq(profile.gold, 900, "conserva lo suyo")
	assert_eq(profile.level_of("damage"), 4)
	assert_eq(profile.losses, 1)
	assert_eq(int(profile.protections["league"]), 0, "el seguro se gasta")
	assert_true(campaign.loss_ends_run(profile), "y la siguiente derrota ya no perdona")


func test_la_revancha_devuelve_al_penultimo_rival() -> void:
	var campaign := _campaign()
	var profile := _at_boss(campaign)
	profile.campaign_on = true
	profile.protections["rematch"] = 1
	var result := campaign.finish_fight(profile, _shop, "campaign", false)
	assert_false(result["game_over"])
	assert_eq(result["protected"], "rematch")
	assert_eq(profile.fight, campaign.fights_in(0) - 1, "el rival de antes del campeon")
	assert_true(profile.campaign_on, "sigue dentro de la campana")
	assert_eq(profile.gold, 900)
	assert_eq(int(profile.protections["rematch"]), 0)
	# En el primer combate no hay rival anterior: se queda en el.
	var first := PlayerProfile.new()
	first.protections["rematch"] = 1
	campaign.finish_fight(first, _shop, "campaign", false)
	assert_eq(first.fight, 0)


func test_con_las_dos_protecciones_se_gasta_la_revancha() -> void:
	var campaign := _campaign()
	var profile := _at_boss(campaign)
	profile.protections["rematch"] = 1
	profile.protections["league"] = 1
	assert_eq(campaign.protection_in_use(profile), "rematch")
	campaign.finish_fight(profile, _shop, "campaign", false)
	assert_eq(int(profile.protections["league"]), 1, "el seguro sigue ahi")
	assert_eq(campaign.protection_in_use(profile), "league")


func test_las_protecciones_se_compran_una_de_cada_y_la_revancha_cuesta_mas() -> void:
	var campaign := _campaign()
	var profile := PlayerProfile.new()
	var league := campaign.protection_price("league", 0)
	var rematch := campaign.protection_price("rematch", 0)
	assert_gt(league, 0)
	assert_gt(rematch, league, "la revancha es la cara")
	assert_gt(campaign.protection_price("league", 2), league, "en las ligas altas cuestan mas")
	assert_eq(campaign.why_cant_protect(profile, "league"), "faltan celdas")
	profile.gold = league + rematch + 10
	assert_eq(campaign.buy_protection(profile, "league"), "")
	assert_eq(profile.gold, rematch + 10)
	assert_eq(campaign.buy_protection(profile, "league"), "ya la tienes")
	assert_eq(campaign.buy_protection(profile, "rematch"), "")
	assert_eq(profile.gold, 10)
	assert_eq(campaign.buy_protection(profile, "otra"), "esa proteccion no existe")


func test_la_campana_paga_mas_que_la_arena_y_el_campeon_mucho_mas() -> void:
	var campaign_win := _shop.reward("campaign_win")
	var arena_win := _shop.reward("arena_win")
	var boss_win := _shop.reward("boss_win")
	assert_gt(campaign_win, arena_win, "la arena paga menos que la campana")
	assert_between(float(campaign_win) / arena_win, 1.4, 2.0, "como 500 contra 300")
	assert_between(boss_win, 20000, 25000, "el premio grande del campeon")
	# El premio no alcanza para protegerse y ademas equiparse entero.
	var campaign := _campaign()
	var both := campaign.protection_price("league", 0) + campaign.protection_price("rematch", 0)
	assert_lt(both, boss_win, "las dos protecciones caben en un premio")
	assert_gt(both, boss_win / 4, "pero se llevan una parte seria")


func test_el_mejor_resultado_sobrevive_al_final_de_la_partida() -> void:
	var campaign := _campaign()
	var profile := _at_boss(campaign)
	campaign.finish_fight(profile, _shop, "campaign", true)
	profile.end_run()
	assert_eq(profile.boss_wins, 0)
	assert_eq(profile.best_boss_wins, 1)


func test_el_rival_de_arena_es_un_mech_normal_y_depende_de_la_semilla() -> void:
	var campaign := _campaign()
	var rules := RulesConfig.new()
	var power := ItemScaling.power(rules, ItemDef.Tier.COMMON, 0)
	var seen := {}
	for seed_value in 40:
		var rival := campaign.arena_fight(0, _library, seed_value, rules, power)
		assert_false(_library.is_boss(rival["enemy"]))
		seen[rival["enemy"]] = true
	assert_eq(
		seen.size(), _library.band_ids(campaign.band_of(0)).size(), "salen todos los de la banda"
	)
	assert_eq(
		campaign.arena_fight(0, _library, 7, rules, power),
		campaign.arena_fight(0, _library, 7, rules, power)
	)


func test_el_rival_de_arena_va_a_la_medida_del_jugador() -> void:
	var campaign := _campaign()
	var rules := RulesConfig.new()
	for level in rules.tier_max_level[ItemDef.Tier.COMMON] + 1:
		var power := ItemScaling.power(rules, ItemDef.Tier.COMMON, level)
		var rival := campaign.arena_fight(0, _library, 1, rules, power)
		assert_eq(rival["tier"], ItemDef.Tier.COMMON)
		assert_eq(rival["level"], level)
	# Sin pasar de la clase de la zona aunque el jugador vaya por delante.
	var strong := ItemScaling.power(rules, ItemDef.Tier.EPIC, 5)
	assert_eq(campaign.arena_fight(0, _library, 1, rules, strong)["tier"], campaign.tier_of(0))


func test_el_poder_medio_cuenta_cada_pieza_del_mech() -> void:
	var rules := RulesConfig.new()
	var profile := PlayerProfile.new()
	var ids: Array[String] = ["a", "b"]
	assert_almost_eq(Campaign.mean_power(rules, profile, ids), 1.0, 0.0001)
	profile.parts["a"] = {"tier": ItemDef.Tier.COMMON, "level": 6}
	assert_almost_eq(Campaign.mean_power(rules, profile, ids), (1.0 + 1.3) / 2.0, 0.0001)


func test_las_zonas_de_clase_alta_pagan_mas() -> void:
	var campaign := _campaign()
	for zone in range(1, campaign.zone_count()):
		assert_gte(campaign.reward_mult(zone), campaign.reward_mult(zone - 1))
	var profile := PlayerProfile.new()
	var result := campaign.finish_fight(profile, _shop, "arena", true)
	assert_eq(result["prize"], roundi(_shop.reward("arena_win") * campaign.reward_mult(0)))


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
								"level_cap": 0,
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
	assert_eq(campaign.why_cant_protect(PlayerProfile.new(), "league"), "esa proteccion no existe")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_un_guardado_de_la_version_1_se_migra() -> void:
	var old := {"schema_version": 1, "gold": 500, "shop_levels": {"heat": 2}, "wins": 9}
	var profile := PlayerProfile.from_dict(old)
	assert_eq(profile.gold, 500)
	assert_eq(profile.level_of("heat"), 2)
	assert_eq(profile.wins, 9)
	assert_eq(profile.zone, 0)
	assert_eq(profile.fight, 0)
	assert_eq(profile.to_dict()["schema_version"], PlayerProfile.SCHEMA_VERSION)


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


func test_la_campana_en_marcha_y_las_protecciones_se_guardan() -> void:
	var profile := PlayerProfile.new()
	profile.campaign_on = true
	profile.protections["rematch"] = 1
	var loaded := PlayerProfile.from_dict(profile.to_dict())
	assert_true(loaded.campaign_on)
	assert_eq(int(loaded.protections["rematch"]), 1)
	# Un guardado de antes de las ligas: en campana quien ya gano algun combate.
	var old := {"schema_version": 7, "zone": 2, "fight": 4}
	assert_true(PlayerProfile.from_dict(old).campaign_on)
	old["fight"] = 0
	assert_false(PlayerProfile.from_dict(old).campaign_on)
	# Perder la partida se lo lleva todo.
	profile.end_run()
	assert_false(profile.campaign_on)
	assert_true(profile.protections.is_empty())


func test_el_mundo_tiene_10_zonas_y_cada_clase_ocupa_dos() -> void:
	var campaign := _campaign()
	assert_eq(campaign.zone_count(), 10)
	var classes := []
	for zone in campaign.zone_count():
		classes.append(campaign.tier_of(zone))
		assert_ne(campaign.stage_of(zone), "", "la zona %d tiene escenario" % (zone + 1))
	var expected := [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]
	assert_eq(classes, expected)


func test_los_tres_ultimos_jefes_sueltan_un_nucleo_unico() -> void:
	var campaign := _campaign()
	for zone in campaign.zone_count():
		var profile := PlayerProfile.new()
		profile.zone = zone
		profile.fight = campaign.fights_in(zone)
		var result := campaign.finish_fight(profile, _shop, "campaign", true)
		assert_eq(result["unique"], zone >= 7, "zona %d" % (zone + 1))
		assert_eq(profile.unique_cores, 1 if zone >= 7 else 0)


func test_vencer_al_jefe_10_completa_la_campana() -> void:
	var campaign := _campaign()
	var profile := PlayerProfile.new()
	profile.zone = 9
	profile.fight = campaign.fights_in(9)
	assert_false(campaign.is_complete(profile))
	campaign.finish_fight(profile, _shop, "campaign", true)
	assert_true(campaign.is_complete(profile))


func test_los_rivales_llevan_la_armeria_del_orden_de_su_zona() -> void:
	var campaign := _campaign()
	assert_eq(campaign.enemy_armory(0), 0, "en la primera zona el Orden no tiene mejoras")
	for zone in range(1, campaign.zone_count()):
		assert_gte(campaign.enemy_armory(zone), campaign.enemy_armory(zone - 1), "no baja")
		assert_lte(campaign.enemy_armory(zone), _shop.max_level())
	var last := campaign.zone_count() - 1
	assert_gt(campaign.enemy_armory(last), 0)
	var upgrades := campaign.enemy_upgrades(last, _shop)
	assert_almost_eq(upgrades.damage, _shop.value("damage", campaign.enemy_armory(last)), 0.0001)
	assert_almost_eq(campaign.enemy_upgrades(0, _shop).damage, 0.0, 0.0001)


func test_los_jefes_del_orden_entrenan_cada_zona_mas() -> void:
	var campaign := _campaign()
	var tree := SkillTree.load_file("res://data/skills.json")
	assert_gt(campaign.boss_skills(0), 0)
	for zone in range(1, campaign.zone_count()):
		assert_gte(campaign.boss_skills(zone), campaign.boss_skills(zone - 1), "no baja")
	var last := campaign.zone_count() - 1
	var learned := tree.spread(campaign.boss_skills(last))
	assert_eq(learned.size(), campaign.boss_skills(last), "le alcanzan los puntos")
	assert_false("materia_oscura" in learned, "la materia oscura es solo del jugador")
