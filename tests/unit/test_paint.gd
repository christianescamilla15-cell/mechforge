extends GutTest
## La pintura de las piezas (OBS-010 de docs/OBSERVACIONES.md, del usuario:
## "no hay para cambiar el color del arma. Deberia estar integrado dentro del
## mismo seleccionar... elegir un color, ya sea blanco, rojo, azul, de acuerdo
## al color del robot"). Cada pieza que se ve en el robot se pinta con uno de
## los tres colores en los que existe su dibujo; se guarda en el equipo del
## robot ("paint") y solo cambia como se dibuja.

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _brief: WorkshopBrief
var _painted: Array[String] = []


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_brief = WorkshopBrief.new()
	_brief.rules = _rules
	_brief.catalog = _catalog
	_brief.library = _library
	_brief.campaign = Campaign.load_file("res://data/campaign.json", _library)
	_brief.workshop = Workshop.load_file("res://data/workshop.json")
	_brief.garage = Garage.load_file("res://data/part_shop.json")
	_brief.shop = ArenaShop.load_file("res://data/arena_shop.json")
	_brief.skills = SkillTree.load_file("res://data/skills.json")
	_brief.progression = Progression.load_file("res://data/progression.json")
	_brief.styles = StyleLibrary.load_file("res://data/styles.json", _catalog)


func before_each() -> void:
	_painted.clear()


func _profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	Garage.ensure_assist(profile, _catalog)
	return profile


func test_solo_se_pinta_lo_que_se_ve_en_el_robot() -> void:
	for slot: String in ["torso", "legs", "chest", "assist", "side0", "side1", "top0"]:
		assert_true(Garage.can_paint(slot), slot)
	for slot: String in ["module0", "charge", "teleport", "hook", "drone", "drone_low", ""]:
		assert_false(Garage.can_paint(slot), slot)


func test_pintar_un_hueco_se_apunta_en_el_equipo_del_robot() -> void:
	var build := {"torso": "torso_fragua", "sides": ["hoja_balas_ter"]}
	assert_eq(Garage.paint_of(build, "side0"), "", "sin pintar")
	Garage.set_paint(build, "side0", "ENERGY")
	Garage.set_paint(build, "torso", "PHYSICAL")
	assert_eq(Garage.paint_of(build, "side0"), "ENERGY")
	assert_eq(build["paint"], {"side0": "ENERGY", "torso": "PHYSICAL"})
	# Lo que no existe no cambia nada.
	Garage.set_paint(build, "side0", "MORADO")
	Garage.set_paint(build, "module0", "HEAT")
	assert_eq(build["paint"], {"side0": "ENERGY", "torso": "PHYSICAL"})
	# Quitar la pintura; sin ninguna, el equipo queda como estaba.
	Garage.set_paint(build, "side0", "")
	Garage.set_paint(build, "torso", "")
	assert_false(build.has("paint"))
	assert_eq(build, {"torso": "torso_fragua", "sides": ["hoja_balas_ter"]})


func test_el_robot_armado_sabe_de_que_color_va_cada_pieza() -> void:
	var spec: Dictionary = _library.specs["calor_horno"]["items"].duplicate(true)
	var plain := _catalog.make_build(spec, _rules, ItemDef.Tier.COMMON, 0)
	assert_eq(plain.paints, {})
	assert_eq(plain.paint_of("torso"), plain.torso.element, "sin pintar, el de su elemento")
	assert_eq(plain.paint_of("side0"), plain.sides[0].element)
	Garage.set_paint(spec, "side0", "ENERGY")
	Garage.set_paint(spec, "torso", "PHYSICAL")
	spec["paint"]["legs"] = "MORADO"
	var build := _catalog.make_build(spec, _rules, ItemDef.Tier.COMMON, 0)
	assert_eq(build.paint_of("side0"), ItemDef.Element.ENERGY)
	assert_eq(build.paint_of("torso"), ItemDef.Element.PHYSICAL)
	assert_eq(build.paint_of("legs"), build.legs.element, "un color que no existe no pinta")
	assert_eq(build.paint_of("side1"), build.sides[1].element, "las demas, como eran")
	# El asistente hace juego con el torso mientras no se pinte aparte.
	assert_eq(build.paint_of("assist"), ItemDef.Element.PHYSICAL)
	Garage.set_paint(spec, "assist", "HEAT")
	build = _catalog.make_build(spec, _rules, ItemDef.Tier.COMMON, 0)
	assert_eq(build.paint_of("assist"), ItemDef.Element.HEAT)
	# La pintura no cambia nada mas: pesa y pelea igual.
	assert_eq(build.total_weight(), plain.total_weight())
	assert_eq(build.summary(_rules), plain.summary(_rules))


func test_cada_hueco_da_su_pieza() -> void:
	var spec: Dictionary = _library.specs["calor_horno"]["items"]
	var build := _catalog.make_build(spec, _rules, ItemDef.Tier.COMMON, 0)
	assert_eq(build.item_at("torso"), build.torso)
	assert_eq(build.item_at("side1"), build.sides[1])
	assert_eq(build.item_at("top0"), build.tops[0])
	assert_eq(build.item_at("module2"), build.modules[2])
	assert_null(build.item_at("side9"))
	assert_null(build.item_at("no_existe"))


func test_la_pintura_se_guarda_con_la_partida() -> void:
	var profile := _profile()
	Garage.set_paint(profile.build, "side0", "ENERGY")
	var copy := PlayerProfile.from_dict(JSON.parse_string(JSON.stringify(profile.to_dict())))
	assert_eq(Garage.paint_of(copy.build, "side0"), "ENERGY")
	assert_eq(_brief.build_of(copy, copy.build).paint_of("side0"), ItemDef.Element.ENERGY)


func test_el_catalogo_ofrece_los_tres_colores_y_marca_el_que_lleva() -> void:
	var profile := _profile()
	var paints := _brief.paints(profile, "side0")
	assert_eq(paints.size(), 3)
	var ids: Array[String] = []
	for paint in paints:
		ids.append(str(paint["id"]))
		assert_true(paint["color"] is Color)
	assert_eq(ids, Garage.PAINTS)
	# El Horno es de calor: sin pintar va elegido el rojo.
	assert_eq(_brief.paint_shown(profile, "side0"), "HEAT")
	assert_true(paints[1]["selected"])
	assert_false(paints[0]["selected"])
	Garage.set_paint(profile.build, "side0", "PHYSICAL")
	paints = _brief.paints(profile, "side0")
	assert_true(paints[0]["selected"], "ahora va de blanco")
	assert_false(paints[1]["selected"])
	# Y sale en lo que ensena el catalogo de esa casilla.
	assert_eq(_brief.rack(profile, "side0")["paints"], paints)
	# Lo que no se ve en el robot, o un hueco sin pieza, no se pinta.
	assert_eq(_brief.paints(profile, "module0"), [] as Array[Dictionary])
	Garage.set_slot(profile.build, "side1", "")
	assert_eq(_brief.paints(profile, "side1"), [] as Array[Dictionary])
	# El asistente, sin pintar, lleva el color del torso.
	Garage.set_paint(profile.build, "torso", "ENERGY")
	assert_eq(_brief.paint_shown(profile, "assist"), "ENERGY")


func _rack(state: Dictionary) -> PartsRack:
	var rack := PartsRack.new()
	rack.embedded = true
	add_child_autofree(rack)
	rack.position = Vector2(600, 40)
	rack.size = Vector2(560, 600)
	rack.open(state, true)
	rack.paint_picked.connect(func(id: String) -> void: _painted.append(id))
	return rack


func _click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	return event


func test_las_muestras_de_color_se_pulsan_en_la_cabecera_del_catalogo() -> void:
	var profile := _profile()
	var rack := _rack(_brief.rack(profile, "side0"))
	for index in 3:
		var at := rack.paint_rect(index).get_center()
		assert_eq(rack.zone_at(at), "paint:%d" % index)
		assert_true(rack.paint_rect(index).end.x < rack.size.x - 90.0, "no pisa las celdas")
		assert_true(rack.paint_rect(index).position.x > 150.0, "ni el titulo")
	# La que ya lleva no pide nada; otra, pintar con ella.
	rack._gui_input(_click(rack.paint_rect(1).get_center()))
	assert_eq(_painted, [] as Array[String])
	rack._gui_input(_click(rack.paint_rect(2).get_center()))
	assert_eq(_painted, ["ENERGY"] as Array[String])
	# Un hueco que no se pinta no tiene muestras.
	rack.state = _brief.rack(profile, "module0")
	assert_eq(rack.zone_at(rack.paint_rect(0).get_center()), "")
