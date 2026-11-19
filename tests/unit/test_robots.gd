extends GutTest
## Garaje (GDD 8; pedido del usuario el 2026-11-18): hasta 4 robots en total,
## el que usa y 3 mas. Uno nuevo es un armazon vacio gratis o un diseno de
## ejemplo, pagando solo las piezas que aun no tiene. Todos comparten las
## piezas y su nivel.

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


func _new_run(gold: int = 0) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, _library.starter_ids()[0])
	Garage.ensure_assist(profile, _catalog)
	profile.gold = gold
	return profile


func test_una_partida_empieza_con_un_robot_que_es_el_que_usa() -> void:
	var profile := _new_run()
	assert_eq(profile.mechs.size(), 1)
	assert_eq(profile.active, 0)
	assert_eq(profile.build, profile.mechs[0]["build"], "build es el robot que usa")


func test_en_total_caben_4_robots() -> void:
	var profile := _new_run()
	assert_eq(_rules.max_mechs, 4)
	for i in 3:
		assert_eq(profile.add_frame(_rules, "Robot %d" % (i + 2)), "")
	assert_eq(profile.mechs.size(), 4)
	assert_eq(profile.add_frame(_rules, "Robot 5"), "ya tienes 4 robots")


func test_un_armazon_vacio_es_gratis_y_pasa_a_ser_el_que_usa() -> void:
	var profile := _new_run(500)
	profile.add_frame(_rules, "Nuevo")
	assert_eq(profile.gold, 500)
	assert_eq(profile.active, 1)
	assert_true(profile.build.is_empty(), "se arma en el taller")


func test_cambiar_de_robot_no_toca_el_otro() -> void:
	var profile := _new_run()
	var first: Dictionary = profile.build.duplicate(true)
	profile.add_frame(_rules, "Nuevo")
	Garage.equip(profile, _catalog, "torso", str(first["torso"]))
	assert_eq(Garage.get_slot(profile.build, "torso"), str(first["torso"]))
	profile.select_mech(0)
	assert_eq(profile.build, first, "el primero sigue igual")
	profile.select_mech(1)
	assert_eq(profile.build.keys(), ["torso"], "el armazon solo lleva el torso")


func test_un_diseno_cobra_solo_las_piezas_que_faltan_en_la_clase_de_la_zona() -> void:
	var profile := _new_run(100000)
	var design: String = _library.starter_ids()[1]
	var missing := Garage.missing_parts(profile, _library, design)
	assert_gt(missing.size(), 0)
	var price := _garage.design_price(
		profile, _library, _catalog, _rules, _workshop, design, T.COMMON
	)
	var expected := 0
	for id in missing:
		if _catalog.get_item(id).type != ItemDef.Type.ASSIST:
			expected += _garage.price(_catalog, _rules, _workshop, id, T.COMMON)
	assert_eq(price, expected)
	var buy := _garage.buy_design(profile, _library, _catalog, _rules, _workshop, design, T.COMMON)
	assert_eq(buy, "")
	assert_eq(profile.gold, 100000 - price)
	assert_eq(profile.mechs.size(), 2)
	assert_eq(profile.active, 1)
	assert_eq(profile.mechs[1]["design"], design)
	for id in missing:
		assert_has(profile.owned, id)
	# Lo que ya tenia no se vuelve a cobrar: el mismo diseno cuesta 0.
	assert_eq(
		_garage.design_price(profile, _library, _catalog, _rules, _workshop, design, T.COMMON), 0
	)


func test_sin_celdas_no_se_compra_el_diseno() -> void:
	var profile := _new_run(0)
	var design: String = _library.starter_ids()[1]
	var reason := _garage.buy_design(
		profile, _library, _catalog, _rules, _workshop, design, T.COMMON
	)
	assert_eq(reason, "faltan celdas")
	assert_eq(profile.mechs.size(), 1)


func test_desmontar_un_robot_deja_sus_piezas() -> void:
	var profile := _new_run()
	var owned := profile.owned.duplicate()
	profile.add_frame(_rules, "Nuevo")
	assert_eq(profile.remove_mech(1), "")
	assert_eq(profile.mechs.size(), 1)
	assert_eq(profile.active, 0)
	assert_eq(profile.owned, owned)
	assert_eq(profile.remove_mech(0), "es tu unico robot")


func test_ida_y_vuelta_por_el_guardado() -> void:
	var profile := _new_run()
	profile.add_frame(_rules, "Nuevo")
	profile.select_mech(0)
	var back := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(back.mechs.size(), 2)
	assert_eq(back.active, 0)
	assert_eq(back.build, profile.build)
	assert_eq(back.mechs[1]["name"], "Nuevo")


func test_un_guardado_de_antes_pasa_a_ser_un_robot() -> void:
	# Version 6: un solo mech en "build".
	var old := {
		"schema_version": 6,
		"gold": 99700,
		"mech": "calor_horno",
		"owned": ["torso_fragua"],
		"build": {"torso": "torso_fragua", "sides": ["hoja_balas_ter"]},
	}
	var profile := PlayerProfile.from_dict(old)
	assert_eq(profile.mechs.size(), 1)
	assert_eq(profile.active, 0)
	assert_eq(profile.build["torso"], "torso_fragua")
	assert_eq(profile.mechs[0]["design"], "calor_horno")
	assert_eq(profile.gold, 99700)


func test_perder_la_partida_quita_los_robots() -> void:
	var profile := _new_run()
	profile.add_frame(_rules, "Nuevo")
	profile.end_run()
	assert_true(profile.mechs.is_empty())
	assert_false(profile.has_mech())
