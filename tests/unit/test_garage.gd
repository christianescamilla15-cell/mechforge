extends GutTest
## Taller de armado y tienda de piezas (GDD 4 y 8): el jugador arma su mech
## hueco a hueco con las piezas que tiene y compra piezas nuevas.

const T := ItemDef.Tier

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _workshop: Workshop
var _garage: Garage


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_workshop = Workshop.load_file("res://data/workshop.json")
	_garage = Garage.load_file("res://data/part_shop.json")


func _new_run(mech: String = "fisico_vanguardia") -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, mech)
	return profile


func test_la_tienda_del_juego_carga_sin_errores() -> void:
	assert_eq(_garage.errors, [] as Array[String])


func test_el_primer_mech_da_sus_piezas_y_queda_montado() -> void:
	var profile := PlayerProfile.new()
	assert_false(profile.has_mech())
	profile.start_run(_library, "calor_horno")
	assert_true(profile.has_mech())
	assert_eq(profile.owned, _library.item_ids("calor_horno"))
	var build := _catalog.make_build(profile.build, _rules, T.COMMON, 0, profile.parts)
	assert_eq(build.validate(_rules), [] as Array[String])
	assert_eq(build.torso.id, "torso_fragua")


func test_cada_hueco_acepta_solo_su_tipo_de_pieza() -> void:
	assert_eq(Garage.slot_type("torso"), ItemDef.Type.TORSO)
	assert_eq(Garage.slot_type("side3"), ItemDef.Type.SIDE)
	assert_eq(Garage.slot_type("top1"), ItemDef.Type.TOP)
	assert_eq(Garage.slot_type("module7"), ItemDef.Type.MODULE)
	assert_eq(Garage.slot_type("hook"), ItemDef.Type.HOOK)
	var profile := _new_run()
	assert_eq(Garage.equip(profile, _catalog, "side0", "torso_baluarte"), "no va en ese hueco")
	assert_eq(Garage.equip(profile, _catalog, "side0", "corto_balas_ter"), "no tienes esa pieza")
	assert_eq(Garage.equip(profile, _catalog, "brazo9", "corto_balas_cin"), "ese hueco no existe")


func test_montar_y_quitar_piezas() -> void:
	var profile := _new_run()
	assert_eq(Garage.get_slot(profile.build, "side1"), "corto_balas_cin")
	assert_eq(Garage.equip(profile, _catalog, "side1", "hoja_balas_cin"), "")
	assert_eq(Garage.get_slot(profile.build, "side1"), "hoja_balas_cin")
	assert_eq(Garage.equip(profile, _catalog, "side3", ""), "")
	assert_eq(Garage.get_slot(profile.build, "side3"), "")
	assert_eq(Garage.equip(profile, _catalog, "top1", "bateria_balas_cin"), "")
	assert_eq(profile.build["tops"], ["bateria_balas_cin", "bateria_balas_cin"])


func test_un_hueco_suelto_de_una_lista_se_rellena() -> void:
	var build := {}
	Garage.set_slot(build, "module2", "mod_blindaje")
	assert_eq(build["modules"], ["", "", "mod_blindaje"])
	Garage.set_slot(build, "module2", "")
	assert_eq(build["modules"], [])
	Garage.set_slot(build, "drone", "artillero_balas_cin")
	assert_eq(Garage.get_slot(build, "drone"), "artillero_balas_cin")
	Garage.set_slot(build, "drone", "")
	assert_false(build.has("drone"))


func test_sin_torso_el_mech_no_puede_pelear() -> void:
	var profile := _new_run()
	Garage.equip(profile, _catalog, "torso", "")
	var build := _catalog.make_build(profile.build, _rules, T.COMMON, 0, profile.parts)
	assert_has(build.validate(_rules), "falta el torso")


func test_la_tienda_vende_lo_que_existe_en_la_clase_de_la_zona() -> void:
	for tier in T.DIVINE:
		var stock := _garage.stock_for(_catalog, tier)
		assert_gt(stock.size(), 0)
		for id in stock:
			var def := _catalog.get_item(id)
			assert_between(tier, def.tier_min, def.tier_max, id)
	assert_has(_garage.stock_for(_catalog, T.COMMON), "corto_balas_cin")
	assert_does_not_have(_garage.stock_for(_catalog, T.EPIC), "corto_balas_cin")
	assert_has(_garage.stock_for(_catalog, T.EPIC), "corto_laser_cin")
	assert_does_not_have(_garage.stock_for(_catalog, T.COMMON), "corto_laser_cin")
	assert_has(_garage.stock_for(_catalog, T.MYTHIC), "torso_baluarte")


func test_comprar_una_pieza_la_da_en_la_clase_de_la_zona() -> void:
	var profile := _new_run()
	var id := "corto_balas_ter"
	assert_true(id in _garage.stock_for(_catalog, T.RARE))
	var cost := _garage.price(_catalog, _rules, _workshop, id, T.RARE)
	assert_eq(_garage.buy(profile, _catalog, _rules, _workshop, id, T.RARE), "faltan celdas")
	profile.gold = cost + 3
	assert_eq(_garage.buy(profile, _catalog, _rules, _workshop, id, T.RARE), "")
	assert_has(profile.owned, id)
	assert_eq(profile.part(id), {"tier": T.RARE, "level": 0})
	assert_eq(profile.gold, 3)
	assert_eq(_garage.buy(profile, _catalog, _rules, _workshop, id, T.RARE), "ya la tienes")
	assert_eq(Garage.equip(profile, _catalog, "side0", id), "")


func test_una_pieza_de_clase_alta_cuesta_lo_que_costaria_subirla() -> void:
	var id := "corto_balas_ter"
	var common := _garage.price(_catalog, _rules, _workshop, id, T.COMMON)
	var rare := _garage.price(_catalog, _rules, _workshop, id, T.RARE)
	assert_gt(rare - common, _workshop.total_cost(_rules, T.RARE, 0) - 1)


func test_lo_que_no_se_vende_en_la_zona_no_se_compra() -> void:
	var profile := _new_run()
	profile.gold = 1000000
	var rare_only := ""
	for id in _garage.stock_for(_catalog, T.LEGENDARY):
		if not id in _garage.stock_for(_catalog, T.COMMON) and not id in profile.owned:
			rare_only = id
			break
	assert_ne(rare_only, "")
	assert_eq(
		_garage.buy(profile, _catalog, _rules, _workshop, rare_only, T.COMMON),
		"no se vende en esta zona"
	)


func test_el_mech_armado_se_guarda_y_perder_la_partida_lo_borra() -> void:
	var profile := _new_run()
	Garage.equip(profile, _catalog, "side1", "hoja_balas_cin")
	var path := "user://test_profile_taller.json"
	assert_true(profile.save(path))
	var loaded := PlayerProfile.load_or_new(path)
	assert_eq(Garage.get_slot(loaded.build, "side1"), "hoja_balas_cin")
	assert_eq(loaded.owned, profile.owned)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.end_run()
	assert_false(profile.has_mech())
	assert_true(profile.owned.is_empty())
