extends GutTest
## La vitrina de la computadora del taller (OBS-039, del usuario: "esta parte
## del menu de la tienda me gustaria que fuera mas inmersivo... como Resident
## Evil"): la pieza en grande con su ficha de barras, comparada con la que
## llevas montada, sobre un maletin con un hueco por pieza.

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _brief: WorkshopBrief


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


func _item(id: String) -> ItemDef:
	return ItemScaling.resolve(_catalog.get_item(id), _rules, ItemDef.Tier.COMMON, 0)


func _row(rows: Array[Dictionary], key: String) -> Dictionary:
	for row in rows:
		if str(row["key"]) == key:
			return row
	return {}


func test_la_ficha_de_un_arma_lleva_dano_alcance_y_el_peso_al_final() -> void:
	var rows := PartShowcase.rows(_item("corto_balas_cin"))
	assert_false(_row(rows, "damage").is_empty())
	assert_false(_row(rows, "range").is_empty())
	assert_eq(str(rows[-1]["key"]), "weight", "el peso, siempre al final")
	assert_true(rows.size() <= PartShowcase.MAX_ROWS)
	var damage := _row(rows, "damage")
	var item := _item("corto_balas_cin")
	assert_eq(str(damage["text"]), "%d–%d" % [item.dmg_min, item.dmg_max])


func test_sin_montada_no_hay_ni_mejor_ni_peor() -> void:
	for row in PartShowcase.rows(_item("hoja_balas_cin")):
		assert_eq(PartShowcase.verdict(row), 0, str(row["key"]))


func test_frente_a_la_montada_dice_que_gana_y_que_pierde() -> void:
	var base := _item("hoja_balas_cin")
	var other := _item("hoja_balas_ion")
	var rows := PartShowcase.rows(other, base)
	for row in rows:
		var gain := float(row["value"]) - float(row["base"])
		var expected := 0
		if not is_zero_approx(gain) and str(row["better"]) != "":
			var up := gain > 0.0
			expected = 1 if up == (str(row["better"]) == "high") else -1
		assert_eq(PartShowcase.verdict(row), expected, str(row["key"]))
	# Un dato que solo tiene la montada tambien sale, para ver que se pierde.
	for row in PartShowcase.rows(base, other):
		if is_zero_approx(float(row["value"])):
			assert_ne(float(row["base"]), 0.0)


func test_menos_peso_o_menos_calor_es_mejor() -> void:
	var row := {"value": 40.0, "base": 52.0, "better": "low"}
	assert_eq(PartShowcase.verdict(row), 1)
	row["value"] = 60.0
	assert_eq(PartShowcase.verdict(row), -1)
	row["better"] = ""
	assert_eq(PartShowcase.verdict(row), 0, "el alcance no es ni mejor ni peor")


func test_una_pieza_que_no_dispara_no_lleva_dano_ni_alcance() -> void:
	var rows := PartShowcase.rows(_item("torso_baluarte"))
	assert_true(_row(rows, "damage").is_empty())
	assert_true(_row(rows, "range").is_empty())
	assert_false(_row(rows, "health").is_empty())
	assert_eq(str(rows[-1]["key"]), "weight")


func test_la_escala_de_las_barras_es_la_mayor_de_la_lista() -> void:
	var peers: Array = [_item("corto_balas_cin"), _item("hoja_balas_cin"), _item("hoja_balas_ion")]
	var rows := PartShowcase.rows(_item("corto_balas_cin"), null, peers)
	var top := 0.0
	for peer: ItemDef in peers:
		top = maxf(top, peer.weight)
	assert_eq(float(_row(rows, "weight")["top"]), top)
	assert_true(float(_row(rows, "range")["top"]) >= PartShowcase.RANGE_CELLS)


func test_la_cabecera_dice_que_armas_caben_en_cada_hueco() -> void:
	assert_eq(WorkshopBrief.slot_kind("side0"), "Armas de corto y medio alcance")
	assert_eq(WorkshopBrief.slot_kind("side1"), "Armas de corto y medio alcance")
	assert_eq(WorkshopBrief.slot_kind("top0"), "Armas de largo alcance")
	assert_eq(WorkshopBrief.slot_kind("chest"), "Un disparo por combate")
	assert_eq(WorkshopBrief.slot_kind("torso"), "")


func _rack(state: Dictionary) -> PartsRack:
	var rack := PartsRack.new()
	rack.embedded = true
	add_child_autofree(rack)
	rack.position = Vector2(600, 40)
	rack.size = Vector2(740, 740)
	rack.open(state, true)
	return rack


func _motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


func test_la_vitrina_ensena_la_pieza_bajo_el_raton_y_si_no_la_montada() -> void:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	Garage.ensure_assist(profile, _catalog)
	var state := _brief.rack(profile, "side0")
	var rack := _rack(state)
	var mounted: ItemDef = state["mounted"]["item"]
	assert_eq(rack._shown()["item"], mounted, "sin raton, la del hueco")
	assert_null(rack._shown()["base"], "la montada no se compara consigo")
	var other := -1
	for index in rack._parts.size():
		if not bool(rack._parts[index]["mounted"]):
			other = index
			break
	assert_gt(other, -1)
	rack._gui_input(_motion(rack.part_rect(other).get_center()))
	assert_eq(rack._shown()["item"], rack._parts[other]["item"])
	assert_eq(rack._shown()["base"], mounted, "y se compara con la montada")
	# Las cajas no se pisan: vitrina, linea de la terminal, maletin y lectura.
	assert_true(rack._showcase_rect().end.y <= rack._line_rect().position.y)
	assert_true(rack._line_rect().end.y <= rack._case_rect().position.y)
	assert_true(rack._case_rect().end.y <= rack._stats_rect().position.y)
	assert_true(rack._sheet_rect().encloses(rack._key_rect()))
