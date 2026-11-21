extends GutTest
## El especialista (GDD 8.6, OBS-043, del usuario: "que cada ataque te de
## vida, que te regenere energia, te quite calor... cada rango te va dando mas
## nivel... se desbloquea en el nivel 10 nada mas... desde los 1 000 y hasta
## los 100 000"): los prototipos de cada pieza se combinan, con rangos I a V.

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _protos: PrototypeLibrary


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_protos = PrototypeLibrary.load_file("res://data/prototypes.json")


func _profile(gold: int = 1000000) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	profile.gold = gold
	return profile


func _proto_gun(effect: String, value: float) -> ItemDef:
	var gun := Fx.gun()
	gun.proto_effects = {effect: value}
	return gun


func test_los_prototipos_cargan_con_sus_rangos_y_precios() -> void:
	assert_eq(_protos.errors, [] as Array[String])
	assert_eq(_protos.unlock_level, 10)
	assert_eq(_protos.ranks, 5)
	assert_eq(_protos.order.size(), 9)
	var cheapest := 1 << 30
	var dearest := 0
	for id in _protos.order:
		for rank in range(1, 6):
			cheapest = mini(cheapest, _protos.price(id, rank))
			dearest = maxi(dearest, _protos.price(id, rank))
		assert_gt(_protos.value(id, 5), _protos.value(id, 1), "%s sube con el rango" % id)
	assert_eq(cheapest, 1000, "desde los 1 000")
	assert_eq(dearest, 100000, "hasta los 100 000")
	assert_eq(_protos.ids_for("side0").size(), 5, "cinco para las armas")
	assert_eq(_protos.ids_for("torso").size(), 3)
	assert_eq(_protos.ids_for("legs").size(), 1)
	assert_eq(_protos.ids_for("module0").size(), 0, "los modulos no llevan")


func test_solo_se_abre_en_el_nivel_10_y_lo_demas_es_el_precio() -> void:
	var profile := _profile()
	assert_ne(_protos.why_cant_buy(profile, _catalog, 9, "side0", "sifon_vital"), "")
	assert_eq(_protos.why_cant_buy(profile, _catalog, 10, "side0", "sifon_vital"), "")
	assert_ne(_protos.why_cant_buy(profile, _catalog, 10, "side0", "radiador"), "", "otra pieza")
	profile.gold = 500
	assert_ne(_protos.why_cant_buy(profile, _catalog, 30, "side0", "captador"), "", "sin celdas")


## El usuario, 2026-11-21: "cuando subo al maximo nivel y mejoro la
## siguiente, el primero se reinicia". Cada prototipo lleva su rango y comprar
## otro no quita los demas.
func test_comprar_sube_de_rango_y_otro_se_suma_sin_quitar_nada() -> void:
	var profile := _profile()
	var key := _catalog.get_item(Garage.get_slot(profile.build, "side0")).progress_id()
	var gold := profile.gold
	assert_eq(_protos.buy(profile, _catalog, 10, "side0", "sifon_vital"), "")
	assert_eq(profile.gold, gold - 2000)
	assert_eq(profile.prototypes[key], {"sifon_vital": 1})
	assert_eq(_protos.buy(profile, _catalog, 10, "side0", "sifon_vital"), "")
	assert_eq(profile.prototypes[key]["sifon_vital"], 2)
	assert_eq(profile.gold, gold - 2000 - 6000)
	for i in 3:
		_protos.buy(profile, _catalog, 10, "side0", "sifon_vital")
	assert_eq(profile.prototypes[key]["sifon_vital"], 5)
	assert_ne(_protos.buy(profile, _catalog, 10, "side0", "sifon_vital"), "", "el V es el tope")
	assert_eq(_protos.buy(profile, _catalog, 10, "side0", "purga_termica"), "")
	assert_eq(profile.prototypes[key], {"sifon_vital": 5, "purga_termica": 1}, "se suma")
	for id: String in ["captador", "percutor", "sobrecarga"]:
		assert_eq(_protos.buy(profile, _catalog, 10, "side0", id), "")
	assert_eq(profile.prototypes[key].size(), 5, "los cinco de arma a la vez")
	assert_eq(profile.prototypes[key]["sifon_vital"], 5, "y el primero sigue en V")


func test_una_partida_con_el_formato_de_uno_por_pieza_se_convierte() -> void:
	var data := _profile().to_dict()
	data["prototypes"] = {"medio_blaster_ter": {"id": "captador", "rank": 1}}
	var profile := PlayerProfile.from_dict(data)
	assert_eq(profile.prototypes["medio_blaster_ter"], {"captador": 1})


func test_un_arma_con_varios_prototipos_los_aplica_todos() -> void:
	var gun := Fx.gun()
	gun.proto_effects = {"lifesteal": 0.2, "damage": 0.1}
	var e := Fx.engine(Fx.build([gun]), Fx.build())
	e.mechs[0].health = 500
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.events[-1]["damage"], 110, "+10 % de dano")
	assert_eq(e.mechs[0].health, 522, "y el 20 % de 110 en vida")


func test_el_prototipo_va_en_la_pieza_del_robot_y_se_guarda() -> void:
	var profile := _profile()
	_protos.buy(profile, _catalog, 10, "torso", "radiador")
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(copy.prototypes, profile.prototypes)
	var build := _catalog.make_build(profile.build, _rules, ItemDef.Tier.COMMON, 0, profile.parts)
	var plain := build.summary(_rules)
	_protos.apply(build, profile)
	assert_eq(build.torso.protos, {"radiador": 1})
	var cooled := build.summary(_rules)
	assert_eq(cooled["cooling"], roundi(plain["cooling"] * 1.1), "+10 % de enfriamiento")


func test_cada_golpe_devuelve_vida_energia_o_quita_calor() -> void:
	var e := Fx.engine(Fx.build([_proto_gun("lifesteal", 0.2)]), Fx.build())
	e.mechs[0].health = 500
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].health, 520, "el 20 % de 100 de dano")
	assert_eq(e.events[-1]["lifesteal"], 20)
	var gun := _proto_gun("energy_on_hit", 0.1)
	gun.energy_cost = 50
	var spark := Fx.engine(Fx.build([gun]), Fx.build())
	spark.apply(BattleAction.weapon("side0"))
	assert_eq(spark.mechs[0].energy, 200 - 50 + 20, "gasta 50 y recupera el 10 % de 200")
	var hot := _proto_gun("cool_on_hit", 0.25)
	hot.heat_cost = 80
	var vent := Fx.engine(Fx.build([hot]), Fx.build())
	vent.apply(BattleAction.weapon("side0"))
	assert_eq(vent.mechs[0].heat, 80 - 50, "se quita el 25 % de 200")


func test_sobrecarga_y_percutor() -> void:
	var e := Fx.engine(Fx.build([_proto_gun("damage", 0.2)]), Fx.build())
	assert_eq(e.preview(BattleAction.weapon("side0"))["dmg_min"], 120)
	var rules := Fx.rules({"crits_enabled": false})
	var crit := Fx.engine(Fx.build([_proto_gun("crit", 0.3)]), Fx.build(), 0, rules)
	var def := crit.mechs[0].slots["side0"].def
	assert_almost_eq(crit.crit_chance(def, crit.mechs[1]), 0.3, 0.0001, "aunque esten apagados")
	var plain := Fx.engine(Fx.build([Fx.gun()]), Fx.build(), 0, rules)
	var plain_def := plain.mechs[0].slots["side0"].def
	assert_eq(plain.crit_chance(plain_def, plain.mechs[1]), 0.0)


func test_la_valvula_perdona_el_sobrecalentamiento() -> void:
	var build := Fx.build([Fx.gun()])
	build.torso.proto_effects = {"overheat_relief": 1.0}
	var e := Fx.engine(Fx.build(), build)
	assert_eq(e.mechs[1].relief_left, 1)
	e.mechs[1].heat = 400
	Fx.pass_turn(e)
	assert_eq(e.mechs[1].heat, 200, "queda en su tope, sin perder nada")
	assert_eq(e.mechs[1].relief_left, 0)
	assert_eq(e.actions_left, 2, "conserva sus dos acciones")


func _brief() -> WorkshopBrief:
	var brief := WorkshopBrief.new()
	brief.rules = _rules
	brief.catalog = _catalog
	brief.library = _library
	brief.campaign = Campaign.load_file("res://data/campaign.json", _library)
	brief.workshop = Workshop.load_file("res://data/workshop.json")
	brief.garage = Garage.load_file("res://data/part_shop.json")
	brief.shop = ArenaShop.load_file("res://data/arena_shop.json")
	brief.skills = SkillTree.load_file("res://data/skills.json")
	brief.progression = Progression.load_file("res://data/progression.json")
	brief.styles = StyleLibrary.load_file("res://data/styles.json", _catalog)
	brief.prototypes = _protos
	return brief


func test_el_banco_ensena_tus_piezas_y_lo_que_hace_el_rango_siguiente() -> void:
	var brief := _brief()
	var profile := _profile()
	var locked := SpecialistBrief.state(profile, brief, _protos, "side0")
	assert_ne(str(locked["locked"]), "", "antes del nivel 10, cerrado")
	for entry: Dictionary in locked["protos"]:
		assert_ne(str(entry["reason"]), "")
	profile.xp = 99999
	_protos.buy(profile, _catalog, 30, "side0", "sifon_vital")
	var state := SpecialistBrief.state(profile, brief, _protos, "side0")
	assert_eq(str(state["locked"]), "")
	assert_eq(state["pieces"].size(), 6, "dos brazos, hombro, pecho, torso y piernas")
	assert_eq(state["pieces"][0]["proto"], "Sifón vital I")
	assert_eq(state["pieces"][0]["count"], 1)
	var sifon: Dictionary = state["protos"][0]
	assert_eq(sifon["id"], "sifon_vital")
	assert_eq(sifon["rank_now"], 1)
	assert_eq(sifon["price"], 6000, "el rango II")
	assert_string_contains(str(sifon["text"]), "9 %")
	assert_string_contains(str(sifon["text"]), "(ahora 6 %)")
	assert_eq(str(sifon["reason"]), "")
