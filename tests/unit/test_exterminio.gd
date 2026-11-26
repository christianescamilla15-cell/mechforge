extends GutTest
## El Exterminio (OBS-053, del usuario): "una vez que entras no hay final,
## aqui unicamente te llega un rival mas fuerte que el otro y asi
## sucesivamente hasta que pierdes".

var _library: BuildLibrary
var _shop: ArenaShop
var _campaign: Campaign
var _progression: Progression
var _rules := RulesConfig.new()


func before_all() -> void:
	_library = BuildLibrary.load_file("res://data/builds.json")
	_shop = ArenaShop.load_file("res://data/arena_shop.json")
	_campaign = Campaign.load_file("res://data/campaign.json", _library)
	_progression = Progression.load_file("res://data/progression.json")


## Un jugador en la ultima liga (paga x 3.2: 960 por ganar en la arena).
func _profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.zone = _campaign.zone_count() - 1
	profile.gold = 1000
	return profile


func _fight(wave: int) -> Dictionary:
	return _campaign.exterminio_fight(
		_campaign.zone_count() - 1, _library, 77, _rules, 4.6, {}, wave
	)


func test_esta_en_los_datos() -> void:
	assert_eq(_campaign.errors, [] as Array[String])
	assert_gt(float(_campaign.exterminio["edge_growth"]), 0.0)
	assert_gt(float(_campaign.exterminio["gold_growth"]), 0.0)
	assert_true("exterminio" in MissionBrief.CHANNELS)


## Cada oleada, un rival mas fuerte que el anterior, y sin final: despues de
## la ultima de la racha sigue subiendo.
func test_cada_rival_es_mas_fuerte_y_no_hay_final() -> void:
	var before := -1.0
	for wave in [0, 5, 10, 19, 20, 30, 60]:
		var fight := _fight(wave)
		var edge := float(fight["edge"])
		assert_gt(edge, before, "oleada %d" % (wave + 1))
		assert_eq(int(fight["wave"]), wave)
		assert_eq(int(fight["streak"]), wave, "cuentan los Titanes y lo que llevas de mas")
		before = edge
	var last := _campaign.streak_fights() - 1
	var growth := float(_campaign.exterminio["edge_growth"])
	assert_almost_eq(
		float(_fight(last + 10)["edge"]), float(_fight(last)["edge"]) + 10 * growth, 0.0001
	)


func test_ganar_paga_ya_y_llega_la_siguiente() -> void:
	var profile := _profile()
	_campaign.begin_exterminio(profile)
	assert_true(profile.exterminio_live)
	var result := _campaign.finish_fight(profile, _shop, "exterminio", true, _progression)
	assert_false(profile.exterminio_live)
	assert_eq(profile.exterminio_wave, 1)
	assert_eq(profile.exterminio_best, 1)
	assert_true(bool(result["record"]))
	assert_eq(int(result["wave"]), 0)
	assert_eq(int(result["gold"]), 960)
	assert_eq(profile.gold, 1960, "se cobra ya: no hay bote")
	assert_gt(int(result["xp"]), 0)
	# La siguiente paga mas.
	var next := _campaign.finish_fight(profile, _shop, "exterminio", true, _progression)
	assert_gt(int(next["gold"]), 960)
	assert_gt(int(next["xp"]), int(result["xp"]))
	assert_eq(profile.exterminio_wave, 2)


func test_perder_lo_acaba_y_el_record_queda() -> void:
	var profile := _profile()
	profile.exterminio_wave = 7
	profile.exterminio_best = 9
	var gold := profile.gold
	var losses := profile.losses
	var result := _campaign.finish_fight(profile, _shop, "exterminio", false, _progression)
	assert_eq(profile.exterminio_wave, 0, "vuelve a la oleada 1")
	assert_eq(profile.exterminio_best, 9)
	assert_eq(int(result["wave"]), 7)
	assert_false(bool(result["record"]))
	assert_eq(profile.losses, losses + 1)
	assert_gt(profile.gold, gold, "paga lo de perder en la arena")
	assert_false(bool(result["game_over"]), "no acaba la partida")


## Salir o cerrar el juego en mitad de una oleada es perderla.
func test_dejarla_a_medias_es_perder() -> void:
	var profile := _profile()
	profile.exterminio_wave = 4
	assert_eq(_campaign.resume_exterminio(profile), -1, "sin combate a medias no pasa nada")
	assert_eq(profile.exterminio_wave, 4)
	_campaign.begin_exterminio(profile)
	assert_eq(_campaign.resume_exterminio(profile), 4)
	assert_eq(profile.exterminio_wave, 0)
	assert_false(profile.exterminio_live)


func test_se_guarda_y_el_record_sobrevive_a_la_partida() -> void:
	var profile := _profile()
	profile.exterminio_wave = 3
	profile.exterminio_best = 12
	profile.exterminio_live = true
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq([copy.exterminio_wave, copy.exterminio_best, copy.exterminio_live], [3, 12, true])
	copy.end_run()
	assert_eq([copy.exterminio_wave, copy.exterminio_best, copy.exterminio_live], [0, 12, false])


## Como la arena: con la campana de la liga en marcha se cierra.
func test_se_cierra_con_la_campana_de_la_liga_en_marcha() -> void:
	var profile := _profile()
	assert_false(_campaign.mode_locked(profile, "exterminio"))
	profile.campaign_on = true
	profile.zone = 0
	assert_true(_campaign.mode_locked(profile, "exterminio"))
