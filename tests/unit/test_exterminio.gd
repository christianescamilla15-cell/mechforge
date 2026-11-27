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


func _fight(wave: int, robot: int = 0) -> Dictionary:
	return _campaign.exterminio_fight(
		_campaign.zone_count() - 1, _library, 77, _rules, 4.6, {}, wave, robot
	)


## Gana los robots que quedan de la oleada; devuelve el resultado del ultimo.
func _win_wave(profile: PlayerProfile) -> Dictionary:
	var result := {}
	for robot in _campaign.exterminio_robots() - profile.exterminio_robot:
		_campaign.begin_exterminio(profile)
		result = _campaign.finish_fight(profile, _shop, "exterminio", true, _progression)
	return result


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
	# Con robots seguidos (OBS-055), su propia rampa: wave_edge por oleada.
	var step := float(_campaign.exterminio["wave_edge"])
	assert_gt(step, 0.0)
	assert_almost_eq(float(_fight(30)["edge"]), 30 * step, 0.0001)


## Cada oleada son tres robots seguidos (OBS-055): cada uno paga al ganarle,
## la oleada sigue en marcha entre uno y otro y se pasa al tumbar al ultimo.
func test_ganar_paga_ya_y_llega_la_siguiente() -> void:
	assert_eq(_campaign.exterminio_robots(), 3)
	var profile := _profile()
	_campaign.begin_exterminio(profile)
	assert_true(profile.exterminio_live)
	var first := _campaign.finish_fight(profile, _shop, "exterminio", true, _progression)
	assert_true(bool(first["next_robot"]))
	assert_true(profile.exterminio_live, "entre robots la oleada sigue en marcha")
	assert_eq([profile.exterminio_wave, profile.exterminio_robot], [0, 1])
	assert_eq(int(first["gold"]), 960)
	assert_eq(profile.gold, 1960, "se cobra ya: no hay bote")
	assert_gt(int(first["xp"]), 0)
	var result := _win_wave(profile)
	assert_false(bool(result["next_robot"]))
	assert_false(profile.exterminio_live)
	assert_eq([profile.exterminio_wave, profile.exterminio_robot], [1, 0])
	assert_eq(profile.exterminio_best, 1)
	assert_true(bool(result["record"]))
	assert_eq(int(result["wave"]), 0)
	assert_eq(profile.gold, 1000 + 3 * 960)
	# La siguiente paga mas.
	var next := _campaign.finish_fight(profile, _shop, "exterminio", true, _progression)
	assert_gt(int(next["gold"]), 960)
	assert_gt(int(next["xp"]), int(first["xp"]))
	assert_eq(profile.exterminio_wave, 1)


func test_perder_lo_acaba_y_el_record_queda() -> void:
	var profile := _profile()
	profile.exterminio_wave = 7
	profile.exterminio_robot = 2
	profile.exterminio_best = 9
	var gold := profile.gold
	var losses := profile.losses
	var result := _campaign.finish_fight(profile, _shop, "exterminio", false, _progression)
	assert_eq(profile.exterminio_wave, 0, "vuelve a la oleada 1")
	assert_eq(profile.exterminio_robot, 0)
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
	profile.exterminio_robot = 1
	assert_eq(_campaign.resume_exterminio(profile), 4)
	assert_eq([profile.exterminio_wave, profile.exterminio_robot], [0, 0])
	assert_false(profile.exterminio_live)


func test_se_guarda_y_el_record_sobrevive_a_la_partida() -> void:
	var profile := _profile()
	profile.exterminio_wave = 3
	profile.exterminio_best = 12
	profile.exterminio_live = true
	profile.exterminio_robot = 2
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq([copy.exterminio_wave, copy.exterminio_best, copy.exterminio_live], [3, 12, true])
	assert_eq(copy.exterminio_robot, 2)
	copy.end_run()
	assert_eq([copy.exterminio_wave, copy.exterminio_best, copy.exterminio_live], [0, 12, false])
	assert_eq(copy.exterminio_robot, 0)


## Como la arena: con la campana de la liga en marcha se cierra.
func test_se_cierra_con_la_campana_de_la_liga_en_marcha() -> void:
	var profile := _profile()
	assert_false(_campaign.mode_locked(profile, "exterminio"))
	profile.campaign_on = true
	profile.zone = 0
	assert_true(_campaign.mode_locked(profile, "exterminio"))


## Cada 10 oleadas, el campeon de una liga, por orden y vuelta a empezar
## (OBS-054), con su entrenamiento y al poder de la oleada.
func test_cada_diez_oleadas_un_campeon() -> void:
	var zones := _campaign.zone_count()
	assert_eq(_campaign.exterminio_champion(8), -1)
	assert_eq(_campaign.exterminio_champion(9), 0, "la oleada 10: el de la liga 1")
	assert_eq(_campaign.exterminio_champion(19), 1)
	assert_eq(_campaign.exterminio_champion(10 * zones - 1), zones - 1)
	assert_eq(_campaign.exterminio_champion(10 * zones + 9), 0, "y vuelta a empezar")
	assert_eq(_campaign.next_exterminio_champion(0), 9)
	assert_eq(_campaign.next_exterminio_champion(9), 9)
	assert_eq(_campaign.next_exterminio_champion(10), 19)
	var last := _campaign.exterminio_robots() - 1
	assert_false(_fight(19, 0).has("champion"), "los primeros de la oleada le escoltan")
	var fight := _fight(19, last)
	var boss: Dictionary = _campaign.zones[1]["boss"]
	assert_eq(str(fight["enemy"]), str(boss["enemy"]))
	assert_true(_library.is_boss(str(fight["enemy"])))
	assert_gte(int(fight["skills"]), int(boss.get("skills", 0)))
	assert_almost_eq(float(fight["edge"]), float(_fight(18)["edge"]), 0.2, "al poder de la oleada")
	assert_false(_fight(18).has("champion"))
	assert_eq(str(fight["difficulty"]), "MASTER", "con la implacable")


func test_vencer_al_campeon_da_puntos_y_un_arma() -> void:
	for case: Array in [[9, 5, 1], [19, 8, 2], [29, 12, 3], [59, 12, 3]]:
		var profile := _profile()
		profile.exterminio_wave = case[0]
		var points := profile.upgrade_points
		var result := _win_wave(profile)
		assert_eq(int(result["points"]), case[1], "oleada %d" % (case[0] + 1))
		assert_eq(profile.upgrade_points, points + case[1])
		assert_eq(int(result["champion_rank"]), case[2])
	var plain := _profile()
	plain.exterminio_wave = 4
	var normal := _win_wave(plain)
	assert_eq([int(normal["points"]), int(normal["champion_rank"])], [0, 0])
	assert_eq(int(normal["champion"]), -1)


## El robot del jugador pasa de un robot de la oleada al siguiente como
## quedo (OBS-055): vida, calor, energia, kits y usos; el sitio, no.
func test_entre_robots_no_se_repara() -> void:
	var a := Fx.build([Fx.gun({"uses": 3})])
	a.skills = SkillSet.new()
	a.skills.repair_uses = 2
	var first := BattleMech.new(a, _rules, 2)
	first.health -= 300
	first.heat = 40
	first.energy -= 50
	first.kits["repair"] = 1
	first.slots["side0"].uses_left = 1
	first.position = 7
	var next := BattleMech.new(a, _rules, 4)
	next.carry_from(first)
	assert_eq(next.health, first.health)
	assert_eq(next.heat, 40)
	assert_eq(next.energy, first.energy)
	assert_eq(next.kits_left("repair"), 1)
	assert_eq(next.slots["side0"].uses_left, 1)
	assert_eq(next.position, 4, "empieza en su sitio")
