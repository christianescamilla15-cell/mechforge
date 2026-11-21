extends GutTest
## Tres armas (decision del usuario, 2026-11-21, OBS-033): "no van a ser 4
## armas de brazos, solamente van a ser 2. Y las armas superior... de un solo
## lado, que es el lado que se muestra. Entonces en total van a ser 3 armas."
## Los brazos, de corto y medio alcance; el hombro, de largo alcance. El arma
## de pecho, "de un solo disparo por partida". El asistente, en el nivel 5, y
## el arma de pecho, en el 10.

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _progression: Progression


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_progression = Progression.load_file("res://data/progression.json")


func test_dos_huecos_de_brazo_y_uno_de_hombro() -> void:
	assert_eq(MechBuild.SIDE_SLOTS, 2)
	assert_eq(MechBuild.TOP_SLOTS, 1)
	for slot: String in ["side0", "side1", "top0"]:
		assert_true(slot in Garage.SLOTS, slot)
	for slot: String in ["side2", "side3", "top1"]:
		assert_false(slot in Garage.SLOTS, slot + " ya no existe")
	var build := (
		_catalog
		. make_build(
			{
				"torso": "torso_baluarte",
				"legs": "piernas_zancos",
				"sides": ["corto_balas_cin", "medio_balas_cin", "hoja_balas_cin"],
			},
			_rules,
			ItemDef.Tier.COMMON,
			0
		)
	)
	assert_has(build.validate(_rules), "demasiadas armas laterales")


func test_los_brazos_son_de_corto_y_medio_alcance_y_el_hombro_de_largo() -> void:
	for def: ItemDef in _catalog.by_type(ItemDef.Type.SIDE):
		assert_lte(def.range_max, 4, "%s, de brazo, llega a %d" % [def.id, def.range_max])
		assert_ne(def.form, "largo", def.id)
	for def: ItemDef in _catalog.by_type(ItemDef.Type.TOP):
		assert_gte(def.range_max, 6, "%s, de hombro, llega a %d" % [def.id, def.range_max])
	# Los rifles pasaron del brazo al hombro.
	assert_eq(_catalog.get_item("largo_balas_cin").type, ItemDef.Type.TOP)


func test_el_arma_de_pecho_dispara_una_vez_por_partida() -> void:
	var chests := _catalog.by_type(ItemDef.Type.CHEST)
	assert_gt(chests.size(), 0)
	for def: ItemDef in chests:
		assert_eq(def.uses, 1, def.id)
	var items: Dictionary = _library.specs["fisico_vanguardia_canon"]["items"].duplicate(true)
	items["chest"] = "canon_pesado_canon_cin"
	var build := _catalog.make_build(items, _rules, ItemDef.Tier.RARE, 0)
	var mech := BattleMech.new(build, _rules)
	assert_eq(mech.slots["chest"].uses_left, 1)


func test_el_asistente_en_el_nivel_5_y_el_pecho_en_el_10() -> void:
	assert_eq(_progression.unlock_level("assist"), 5)
	assert_eq(_progression.unlock_level("drone"), 5)
	assert_eq(_progression.unlock_level("chest"), 10)


func test_los_rivales_llevan_tres_armas_como_mucho() -> void:
	for id in _library.all_ids():
		var items: Dictionary = _library.specs[id]["items"]
		assert_lte((items.get("sides", []) as Array).size(), 2, id)
		assert_lte((items.get("tops", []) as Array).size(), 1, id)
		var build := _library.make(id, _catalog, _rules, ItemDef.Tier.COMMON, 0)
		assert_eq(build.validate(_rules), [] as Array[String], id)


func test_una_partida_de_antes_se_queda_con_tres_armas() -> void:
	var old := {
		"schema_version": 9,
		"gold": 100,
		"wins": 3,
		"owned":
		[
			"torso_baluarte",
			"piernas_zancos",
			"hoja_balas_cin",
			"largo_balas_cin",
			"medio_balas_cin",
			"corto_balas_cin",
		],
		"mechs":
		[
			{
				"name": "Uno",
				"style": "",
				"build":
				{
					"torso": "torso_baluarte",
					"legs": "piernas_zancos",
					"sides":
					["hoja_balas_cin", "largo_balas_cin", "medio_balas_cin", "corto_balas_cin"],
					"paint": {"side3": "HEAT", "torso": "ENERGY"},
				},
			},
			{
				"name": "Dos",
				"style": "tirador",
				"build":
				{
					"torso": "torso_condensador",
					"legs": "piernas_deslizadores",
					"sides": ["largo_balas_ion"],
				},
			},
			{
				"name": "Tres",
				"style": "tirador",
				"build":
				{
					"torso": "torso_condensador",
					"legs": "piernas_deslizadores",
					"sides":
					["medio_canon_cin", "medio_balas_cin", "medio_balas_cin", "medio_balas_cin"],
					"tops": ["bateria_balas_cin", "bateria_balas_cin"],
					"paint":
					{
						"side0": "ENERGY",
						"side1": "ENERGY",
						"side2": "ENERGY",
						"side3": "ENERGY",
						"top0": "ENERGY",
						"top1": "ENERGY",
					},
				},
			},
		],
	}
	var profile := PlayerProfile.from_dict(old)
	var first: Dictionary = profile.mechs[0]["build"]
	assert_eq(first["sides"], ["hoja_balas_cin", "medio_balas_cin"], "las dos primeras de brazo")
	assert_eq(first["tops"], ["largo_balas_cin"], "el rifle pasa al hombro, que estaba libre")
	assert_eq(first["paint"], {"torso": "ENERGY"}, "la pintura del brazo 4 se va con el")
	var second: Dictionary = profile.mechs[1]["build"]
	assert_false(second.has("sides"))
	assert_eq(second["tops"], ["largo_balas_ion"], "el Tirador lleva su rifle en el hombro")
	# Pintado entero: conserva la pintura de las tres armas que se quedan.
	var third: Dictionary = profile.mechs[2]["build"]
	assert_eq(third["sides"], ["medio_canon_cin", "medio_balas_cin"])
	assert_eq(third["tops"], ["bateria_balas_cin"])
	assert_eq(third["paint"], {"side0": "ENERGY", "side1": "ENERGY", "top0": "ENERGY"})
	# Nada se pierde: lo que no cabe sigue siendo suyo.
	assert_has(profile.owned, "corto_balas_cin")
	assert_eq(profile.to_dict()["schema_version"], PlayerProfile.SCHEMA_VERSION)
	var build := _catalog.make_build(first, _rules, ItemDef.Tier.COMMON, 0)
	assert_eq(build.validate(_rules), [] as Array[String])


func test_con_el_hombro_ocupado_el_rifle_se_desmonta() -> void:
	var old := {
		"schema_version": 9,
		"wins": 1,
		"owned": ["torso_baluarte", "piernas_zancos", "largo_balas_cin", "bateria_balas_cin"],
		"mechs":
		[
			{
				"name": "",
				"style": "",
				"build":
				{
					"torso": "torso_baluarte",
					"legs": "piernas_zancos",
					"sides": ["largo_balas_cin"],
					"tops": ["bateria_balas_cin", "bateria_balas_cin"],
				},
			}
		],
	}
	var build: Dictionary = PlayerProfile.from_dict(old).mechs[0]["build"]
	assert_eq(build["tops"], ["bateria_balas_cin"])
	assert_false(build.has("sides"))
