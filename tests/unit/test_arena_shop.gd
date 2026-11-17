extends GutTest
## Tienda de arena y perfil del jugador (GDD 8): el oro de los combates compra
## mejoras permanentes en niveles pequenos, como en el original.

const SHOP_PATH := "res://data/arena_shop.json"


func _shop() -> ArenaShop:
	return ArenaShop.load_file(SHOP_PATH)


func _build(upgrades: ArenaUpgrades) -> MechBuild:
	var build := Fx.build([Fx.gun({"range_min": 1, "range_max": 9, "backfire": 50})])
	build.torso = Fx.torso({"res_physical": 20})
	build.upgrades = upgrades
	return build


func test_la_tienda_del_juego_carga_sin_errores() -> void:
	var shop := _shop()
	assert_eq(shop.errors, [] as Array[String])
	assert_eq(shop.max_level(), 10)
	for track: String in ["damage", "energy", "heat", "resistance", "health", "backfire"]:
		assert_true(track in shop.track_ids(), track)


func test_los_pasos_son_los_del_original() -> void:
	var expected: Array[int] = [0, 1, 3, 5, 7, 9, 11, 13, 15, 17, 20]
	assert_eq(_shop().steps, expected)


func test_cada_mejora_llega_a_su_tope() -> void:
	var shop := _shop()
	assert_almost_eq(shop.value("damage", 10), 0.20, 0.0001)
	assert_almost_eq(shop.value("resistance", 10), 0.40, 0.0001)
	assert_almost_eq(shop.value("health", 10), 350.0, 0.0001)
	assert_almost_eq(shop.value("backfire", 10), 0.20, 0.0001)
	assert_almost_eq(shop.value("damage", 0), 0.0, 0.0001)
	assert_almost_eq(shop.value("damage", 3), 0.05, 0.0001, "nivel 3 = 5 por ciento")
	assert_almost_eq(shop.value("damage", 99), 0.20, 0.0001, "no pasa del tope")


func test_cada_nivel_mejora_un_poco_mas() -> void:
	var shop := _shop()
	for track in shop.track_ids():
		for level in range(1, shop.max_level() + 1):
			assert_gt(
				shop.value(track, level),
				shop.value(track, level - 1),
				"%s nivel %d" % [track, level]
			)
	for level in range(2, shop.max_level() + 1):
		assert_gt(shop.price(level), shop.price(level - 1), "cada nivel cuesta mas")


func test_sin_mejoras_el_mech_no_cambia() -> void:
	var r := Fx.rules()
	var none := _shop().upgrades_for({})
	assert_eq(_build(none).summary(r), _build(null).summary(r))


func test_las_mejoras_cambian_las_estadisticas() -> void:
	var r := Fx.rules()
	var shop := _shop()
	var plain := _build(null).summary(r)
	var top := {}
	for track in shop.track_ids():
		top[track] = shop.max_level()
	var maxed := _build(shop.upgrades_for(top)).summary(r)
	assert_eq(maxed["health"], plain["health"] + 350)
	assert_eq(maxed["energy_cap"], roundi(plain["energy_cap"] * 1.2))
	assert_eq(maxed["cooling"], roundi(plain["cooling"] * 1.2))
	assert_eq(maxed["res_physical"], roundi(plain["res_physical"] * 1.4))


func test_la_potencia_comprada_sube_el_dano() -> void:
	var r := Fx.rules()
	var upgrades := _shop().upgrades_for({"damage": 10})
	var engine := BattleEngine.new(r, _build(upgrades), _build(null), 1, 0, 0)
	# Arma de 100 por 1.2, menos 20 de resistencia del rival.
	assert_eq(engine.preview(BattleAction.weapon("side0"))["dmg_min"], 100)


func test_la_amortiguacion_reduce_el_dano_propio() -> void:
	var r := Fx.rules()
	var upgrades := _shop().upgrades_for({"backfire": 10})
	var engine := BattleEngine.new(r, _build(upgrades), _build(null), 1, 0, 0)
	var before := engine.mechs[0].health
	engine.apply(BattleAction.weapon("side0"))
	assert_eq(before - engine.mechs[0].health, 40, "50 de retroceso propio menos el 20 por ciento")


func test_ganar_y_perder_dan_oro() -> void:
	var shop := _shop()
	var profile := PlayerProfile.new()
	assert_eq(profile.earn(shop, true, false), shop.reward("win"))
	assert_eq(profile.earn(shop, false, false), shop.reward("loss"))
	assert_eq(profile.earn(shop, true, true), shop.reward("boss_win"))
	assert_eq(profile.gold, shop.reward("win") + shop.reward("loss") + shop.reward("boss_win"))
	assert_eq(profile.wins, 2)
	assert_eq(profile.losses, 1)
	assert_eq(profile.boss_wins, 1)
	assert_gt(shop.reward("win"), shop.reward("loss"), "ganar da mas que perder")


func test_comprar_gasta_oro_y_sube_un_nivel() -> void:
	var shop := _shop()
	var profile := PlayerProfile.new()
	assert_eq(profile.buy(shop, "damage"), "falta oro")
	profile.gold = shop.price(1) + 10
	assert_eq(profile.buy(shop, "damage"), "")
	assert_eq(profile.level_of("damage"), 1)
	assert_eq(profile.gold, 10)
	assert_eq(profile.buy(shop, "no_existe"), "esa mejora no existe")


func test_no_se_puede_pasar_del_nivel_maximo() -> void:
	var shop := _shop()
	var profile := PlayerProfile.new()
	profile.gold = 1000000
	for level in shop.max_level():
		assert_eq(profile.buy(shop, "health"), "")
	assert_eq(profile.buy(shop, "health"), "ya esta al maximo")
	assert_eq(profile.level_of("health"), shop.max_level())


func test_el_perfil_se_guarda_y_se_recupera() -> void:
	var profile := PlayerProfile.new()
	profile.gold = 777
	profile.wins = 4
	profile.shop_levels["damage"] = 3
	var path := "user://test_profile.json"
	assert_true(profile.save(path))
	var loaded := PlayerProfile.load_or_new(path)
	assert_eq(loaded.gold, 777)
	assert_eq(loaded.wins, 4)
	assert_eq(loaded.level_of("damage"), 3)
	assert_eq(loaded.to_dict()["schema_version"], PlayerProfile.SCHEMA_VERSION)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_un_guardado_roto_empieza_de_cero() -> void:
	var path := "user://test_profile_roto.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("esto no es json")
	file.close()
	var loaded := PlayerProfile.load_or_new(path)
	assert_eq(loaded.gold, 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
