extends GutTest
## Los modulos por familias (OBS-040, del usuario: "para cada modulo tendria
## que haber una seleccion especial... 3 modulos dedicados a resistencia... 3
## modulos dedicados a ataque y asi. Para que tengas de donde elegir"): nueve
## huecos, tres de resistencia, tres de ataque y tres de sistemas; cada uno
## solo monta los de su familia, un modulo va en un solo hueco y lo que
## repetiria una resistencia se avisa antes de montarlo.

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


## Un jugador sin modulos montados que tiene todos los del catalogo.
func _profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	profile.build.erase("modules")
	for def in _catalog.by_type(ItemDef.Type.MODULE):
		if not def.id in profile.owned:
			profile.owned.append(def.id)
	return profile


func test_nueve_huecos_en_tres_familias_de_tres() -> void:
	assert_eq(MechBuild.MODULE_SLOTS, 9)
	var count := {}
	for index in MechBuild.MODULE_SLOTS:
		var family := Garage.slot_family("module%d" % index)
		assert_true(family in ItemDef.MODULE_FAMILIES, family)
		count[family] = int(count.get(family, 0)) + 1
	for family in ItemDef.MODULE_FAMILIES:
		assert_eq(count[family], 3, family)
	assert_eq(Garage.slot_family("side0"), "")
	assert_eq(WorkshopBrief.slot_title("module0"), "Resistencia 1")
	assert_eq(WorkshopBrief.slot_title("module4"), "Ataque 2")
	assert_eq(WorkshopBrief.slot_title("module8"), "Sistemas 3")


func test_cada_familia_tiene_de_donde_elegir() -> void:
	var count := {}
	for def in _catalog.by_type(ItemDef.Type.MODULE):
		assert_true(def.family in ItemDef.MODULE_FAMILIES, def.id)
		count[def.family] = int(count.get(def.family, 0)) + 1
	for family in ItemDef.MODULE_FAMILIES:
		assert_gt(int(count.get(family, 0)), 3, "mas opciones que huecos en %s" % family)


func test_cada_hueco_solo_monta_los_de_su_familia() -> void:
	var profile := _profile()
	assert_eq(
		Garage.equip(profile, _catalog, "module3", "mod_placas"), "ese modulo es de otra familia"
	)
	assert_eq(
		Garage.equip(profile, _catalog, "module0", "mod_servo_brazos"),
		"ese modulo es de otra familia"
	)
	assert_eq(Garage.equip(profile, _catalog, "module0", "mod_placas"), "")
	assert_eq(Garage.equip(profile, _catalog, "module3", "mod_servo_brazos"), "")
	assert_eq(Garage.equip(profile, _catalog, "module6", "mod_generador"), "")
	for id in Garage.owned_for(profile, _catalog, "module4"):
		assert_eq(_catalog.get_item(id).family, "ataque", id)


func test_un_modulo_va_en_un_solo_hueco_y_se_pasa_de_uno_a_otro() -> void:
	var profile := _profile()
	Garage.equip(profile, _catalog, "module6", "mod_generador")
	assert_eq(Garage.equip(profile, _catalog, "module8", "mod_generador"), "")
	assert_eq(Garage.get_slot(profile.build, "module6"), "", "se fue del primero")
	assert_eq(Garage.get_slot(profile.build, "module8"), "mod_generador")


func test_lo_que_repetiria_una_resistencia_se_avisa_antes_de_montarlo() -> void:
	var profile := _profile()
	Garage.equip(profile, _catalog, "module0", "mod_placas")
	assert_eq(Garage.module_clash(profile.build, _catalog, "module1", "mod_matriz"), "module0")
	assert_eq(Garage.equip(profile, _catalog, "module1", "mod_matriz"), "repite una resistencia")
	# En el mismo hueco se cambia sin problema, y otro elemento no choca.
	assert_eq(Garage.module_clash(profile.build, _catalog, "module0", "mod_matriz"), "")
	assert_eq(Garage.equip(profile, _catalog, "module1", "mod_aislante"), "")
	assert_eq(Garage.equip(profile, _catalog, "module2", "mod_blindaje"), "")
	# El maletin lo dice en la pieza, con el nombre del que choca.
	var state := _brief.rack(profile, "module2")
	var matriz := {}
	for part: Dictionary in state["parts"]:
		if str(part["id"]) == "mod_matriz":
			matriz = part
	assert_false(matriz.is_empty())
	assert_string_contains(str(matriz["reason"]), "Placas Balísticas")
	assert_string_contains(str(matriz["reason"]), "Resistencia 1")


func test_el_maletin_de_un_hueco_solo_ensena_su_familia_y_dice_donde_va_cada_uno() -> void:
	var profile := _profile()
	Garage.equip(profile, _catalog, "module3", "mod_servo_hombro")
	var state := _brief.rack(profile, "module4")
	assert_gt(state["parts"].size(), 0)
	for part: Dictionary in state["parts"]:
		assert_eq((part["item"] as ItemDef).family, "ataque", str(part["id"]))
		if str(part["id"]) == "mod_servo_hombro":
			assert_eq(str(part["where"]), "Ataque 1")
	assert_eq(str(state["kind"]), "Daño de más para tus armas")


func test_los_de_ataque_suben_el_dano_de_sus_armas() -> void:
	var arms := Fx.item(ItemDef.Type.MODULE, {"dmg_bonus": 12, "boost": "arms"})
	var all := Fx.item(ItemDef.Type.MODULE, {"dmg_bonus": 5, "boost": "all"})
	var build := Fx.build([Fx.gun()], {"modules": [arms, all], "tops": [Fx.gun()]})
	assert_eq(build.module_damage("side0"), 17)
	assert_eq(build.module_damage("top0"), 5)
	assert_eq(build.module_damage("chest"), 5)
	assert_eq(build.module_damage("legs"), 0, "el pisoton no es un arma")
	var plain := Fx.engine(Fx.build([Fx.gun()]), Fx.build())
	var boosted := Fx.engine(Fx.build([Fx.gun()], {"modules": [arms]}), Fx.build())
	var before := int(plain.preview(BattleAction.weapon("side0"))["dmg_min"])
	var after := int(boosted.preview(BattleAction.weapon("side0"))["dmg_min"])
	assert_eq(after - before, 12)


func test_una_partida_de_antes_pasa_sus_modulos_a_su_familia() -> void:
	var old := {
		"schema_version": 10,
		"owned": ["mod_generador", "mod_faraday", "mod_disipador"],
		"mechs":
		[
			{
				"name": "Halcon",
				"design": "",
				"style": "tirador",
				"build":
				{
					"modules":
					[
						"mod_generador",
						"mod_faraday",
						"mod_bateria",
						"mod_sumidero",
						"mod_disipador",
						"",
						"mod_placas",
						"mod_blindaje",
					]
				},
			}
		],
	}
	var profile := PlayerProfile.from_dict(old)
	var modules: Array = profile.mechs[0]["build"]["modules"]
	assert_eq(
		modules,
		[
			"mod_faraday",
			"mod_placas",
			"mod_blindaje",
			"",
			"",
			"",
			"mod_generador",
			"mod_bateria",
			"mod_sumidero",
		]
	)
	assert_true("mod_disipador" in profile.owned, "el que no cabe se queda en el inventario")


func test_el_robot_de_un_rival_lleva_sus_modulos_en_su_familia() -> void:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "fisico_vanguardia")
	for index in MechBuild.MODULE_SLOTS:
		var slot := "module%d" % index
		var id := Garage.get_slot(profile.build, slot)
		if id != "":
			assert_eq(_catalog.get_item(id).family, Garage.slot_family(slot), slot)
