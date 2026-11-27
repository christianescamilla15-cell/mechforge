extends GutTest
## Las armas de arena (OBS-051, PLAN A5). Del usuario: "ganar el combate 10,
## 15 y 20 de una racha da una al azar, y el resto se forja en el arbol".

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _gear: ArenaGear
var _tree: UpgradeTree
var _brief: WorkshopBrief


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_gear = ArenaGear.load_file("res://data/arena_gear.json")
	_tree = UpgradeTree.load_file("res://data/upgrade_tree.json")
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
	_brief.gear = _gear
	_brief.tree = _tree


func _profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	profile.zone = 9
	profile.xp = 99999
	profile.gold = 10000000
	return profile


## Lo que da Campaign.finish_fight al ganar el combate `won` de la racha.
func _won(won: int, more := true) -> Dictionary:
	return {"prize": 1000, "step": won - 1, "more": more, "pot": 5000, "gold": 0}


func _rng(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_los_datos_y_las_doce_armas() -> void:
	assert_eq(_gear.errors, [] as Array[String])
	assert_eq(_gear.max_rank(), 3)
	var pool := ArenaGear.pool(_catalog)
	assert_eq(pool.size(), 12, "lanza, hoja y tridente de brazo y bateria de hombro, x 3")
	var stock := _brief.garage.stock_for(_catalog, ItemDef.Tier.DIVINE)
	for id in pool:
		var def := _catalog.get_item(id)
		assert_eq([def.tier_min, def.tier_max], [ItemDef.Tier.DIVINE, ItemDef.Tier.DIVINE], id)
		assert_false(id in stock, "%s no se vende" % id)


## Mas poderosas que el laser de su forma (del usuario: "armas mas poderosas").
func test_pegan_mas_que_el_laser_de_su_forma() -> void:
	for pair: Array in [
		["arena_lanza_ter", "medio_laser_ter"], ["arena_hoja_cin", "hoja_laser_cin"]
	]:
		var arena := _catalog.get_item(pair[0])
		var laser := _catalog.get_item(pair[1])
		assert_gt(arena.dmg_max, laser.dmg_max, pair[0])
		assert_eq(arena.form, laser.form, pair[0])


func test_los_hitos_son_10_15_y_20() -> void:
	assert_eq(_gear.rank_for_win(10), 1)
	assert_eq(_gear.rank_for_win(15), 2)
	assert_eq(_gear.rank_for_win(20), 3)
	assert_eq(_gear.rank_for_win(9), 0)
	var profile := _profile()
	assert_eq(_gear.reward(profile, _catalog, _won(9), {}, _rng()), {})
	assert_eq(profile.arena_gear, {})


func test_ganar_el_decimo_da_un_arma_de_bronce_al_azar() -> void:
	var profile := _profile()
	var prize := _gear.reward(profile, _catalog, _won(10), {}, _rng())
	assert_eq(prize["weapons"].size(), 1)
	var got: Dictionary = prize["weapons"][0]
	var id := str(got["id"])
	assert_true(id in ArenaGear.pool(_catalog))
	assert_true(id in profile.owned)
	assert_eq(int(got["rank"]), 1)
	assert_true(bool(got["new"]))
	assert_eq(profile.part(id), {"tier": ItemDef.Tier.DIVINE, "level": 0})
	assert_eq(ArenaGear.rank_of(profile, id), 1)


func test_el_azar_es_el_del_rng() -> void:
	var a := _gear.reward(_profile(), _catalog, _won(15), {}, _rng(3))
	var b := _gear.reward(_profile(), _catalog, _won(15), {}, _rng(3))
	assert_eq(a, b)


func test_perder_no_da_nada() -> void:
	var lost := {"prize": 0, "step": 9, "more": false}
	assert_eq(_gear.reward(_profile(), _catalog, lost, {}, _rng()), {})


func test_un_hito_sube_el_rango_de_la_que_ya_tienes() -> void:
	var profile := _profile()
	for id in ArenaGear.pool(_catalog):
		profile.owned.append(id)
		profile.arena_gear[id] = 1
	var prize := _gear.reward(profile, _catalog, _won(15), {}, _rng())
	var got: Dictionary = prize["weapons"][0]
	assert_false(bool(got["new"]))
	assert_eq(ArenaGear.rank_of(profile, str(got["id"])), 2)


func test_con_todas_de_ese_rango_da_celdas() -> void:
	var profile := _profile()
	for id in ArenaGear.pool(_catalog):
		profile.owned.append(id)
		profile.arena_gear[id] = 3
	var gold := profile.gold
	var prize := _gear.reward(profile, _catalog, _won(10), {}, _rng())
	assert_eq(prize["weapons"], [])
	assert_eq(int(prize["melted"]), roundi(1500000 * 0.25))
	assert_eq(profile.gold, gold + int(prize["melted"]))


## Los campeones del Exterminio (OBS-054) dan un arma del rango que toca,
## como un hito pero sin doble premio de celdas.
func test_un_campeon_da_un_arma_de_su_rango() -> void:
	var profile := _profile()
	var prize := _gear.grant(profile, _catalog, 2, {}, _rng())
	assert_eq(prize["weapons"].size(), 1)
	assert_eq(int(prize["weapons"][0]["rank"]), 2)
	assert_false(prize.has("double"))
	assert_eq(_gear.grant(profile, _catalog, 0, {}, _rng()), {"weapons": [], "melted": 0})


## A6 mide lo de mas sobre su robot sin prototipos, aspectos, rangos de
## arena ni arbol (OBS-054: los prototipos no se contaban).
func test_el_robot_sin_lo_de_mas() -> void:
	var profile := _profile()
	var weapon := str(profile.build["sides"][0])
	var key := _catalog.get_item(weapon).progress_id()
	profile.prototypes[key] = {"sobrecarga": 5}
	_brief.prototypes = PrototypeLibrary.load_file("res://data/prototypes.json")
	var full := _brief.build_of(profile, profile.build)
	var plain := _brief.plain_build(profile)
	_brief.prototypes = null
	assert_almost_eq(float(full.sides[0].proto_effects.get("damage", 0.0)), 0.2, 0.001)
	assert_eq(plain.sides[0].proto_effects, {})
	assert_true(profile.prototypes.has(key), "su partida no cambia")


## Rama Fortuna: otra arma, un rango mas y doble premio.
func test_fortuna_da_otra_arma_de_un_rango_mas_y_doble_premio() -> void:
	var profile := _profile()
	var luck := {"fortune": 1.0, "fortune_quality": 1, "fortune_double": 1.0}
	var result := _won(10)
	var prize := _gear.reward(profile, _catalog, result, luck, _rng())
	assert_eq(prize["weapons"].size(), 2)
	for got: Dictionary in prize["weapons"]:
		assert_eq(int(got["rank"]), 2, "Buena estrella: plata en el 10")
	assert_eq(int(prize["double"]), 1000)
	assert_eq(profile.arena_pot, 1000, "con la racha en marcha, al bote")
	assert_eq(int(result["pot"]), 1000)
	# Al acabar la racha (el 20), el doble va a las celdas.
	var done := _won(20, false)
	var gold := profile.gold
	_gear.reward(profile, _catalog, done, {"fortune_double": 1.0}, _rng())
	assert_eq(profile.gold, gold + 1000)
	assert_eq(int(done["gold"]), 1000)
	# Oro es el tope.
	var top := _gear.reward(_profile(), _catalog, _won(20), {"fortune_quality": 1}, _rng())
	assert_eq(int(top["weapons"][0]["rank"]), 3)


func test_la_forja_esta_cerrada_sin_la_rama() -> void:
	var profile := _profile()
	var reason := _gear.why_cant_forge(profile, _catalog, "arena_hoja_ter", {})
	assert_ne(reason, "")
	assert_ne(_gear.forge(profile, _catalog, "arena_hoja_ter", {}), "")
	assert_false("arena_hoja_ter" in profile.owned)
	assert_ne(_gear.why_cant_forge(profile, _catalog, "hoja_laser_ter", {"forge": 1}), "")


func test_forjar_cuesta_celdas_y_da_el_rango_de_la_rama() -> void:
	var profile := _profile()
	var gold := profile.gold
	assert_eq(_gear.forge(profile, _catalog, "arena_hoja_ter", {"forge": 1}), "")
	assert_true("arena_hoja_ter" in profile.owned)
	assert_eq(ArenaGear.rank_of(profile, "arena_hoja_ter"), 1)
	assert_eq(profile.gold, gold - 1500000)
	assert_eq(
		_gear.why_cant_forge(profile, _catalog, "arena_hoja_ter", {"forge": 1}), "ya la tienes"
	)
	# Con la Forja del hito 15, la misma sube a plata; Aleacion la abarata.
	gold = profile.gold
	var forge := {"forge": 2, "forge_discount": 0.25}
	assert_eq(_gear.forge(profile, _catalog, "arena_hoja_ter", forge), "")
	assert_eq(ArenaGear.rank_of(profile, "arena_hoja_ter"), 2)
	assert_eq(profile.gold, gold - 2250000)
	profile.gold = 0
	assert_eq(_gear.why_cant_forge(profile, _catalog, "arena_lanza_ion", forge), "faltan celdas")


func test_el_rango_y_el_temple_suben_el_dano() -> void:
	var def := ItemScaling.resolve(_catalog.get_item("arena_lanza_ion"), _rules, 5, 50)
	assert_eq(_gear.apply(def, 0, {}), def)
	var bronze := _gear.apply(def, 1, {})
	assert_eq(bronze.dmg_max, def.dmg_max)
	assert_eq(bronze.arena_rank, 1)
	var silver := _gear.apply(def, 2, {})
	assert_eq(silver.dmg_max, roundi(def.dmg_max * 1.15))
	assert_eq(silver.energy_dmg, roundi(def.energy_dmg * 1.15))
	assert_eq(silver.weight, def.weight)
	var gold := _gear.apply(def, 3, {"forge_quality": 0.2})
	assert_eq(gold.dmg_max, roundi(def.dmg_max * 1.5))


func test_el_robot_del_jugador_lleva_su_rango() -> void:
	var profile := _profile()
	profile.owned.append("arena_lanza_ter")
	profile.parts["arena_lanza_ter"] = {"tier": ItemDef.Tier.DIVINE, "level": 0}
	profile.arena_gear["arena_lanza_ter"] = 2
	Garage.set_slot(profile.build, "side0", "arena_lanza_ter")
	var build := _brief.build_of(profile, profile.build)
	var lance: ItemDef = build.sides[0]
	var plain := ItemScaling.resolve(_catalog.get_item("arena_lanza_ter"), _rules, 5, 0)
	assert_eq(lance.arena_rank, 2)
	assert_eq(lance.dmg_max, roundi(plain.dmg_max * 1.15))
	assert_string_contains(_brief.progress_text(profile, lance), "Plata 0/50")


func test_el_tablero_ensena_las_que_se_forjan() -> void:
	var profile := _profile()
	var forged := _forge_entries(_brief.rack(profile, "side0"))
	assert_eq(forged.size(), 9, "lanza, hoja y tridente en sus tres municiones")
	for part: Dictionary in forged:
		assert_ne(str(part["reason"]), "", "sin la rama, cerradas")
		assert_eq(int(part["price"]), 1500000)
	assert_eq(_forge_entries(_brief.rack(profile, "top0")).size(), 3)
	profile.tree.assign(["forja_1"])
	for part: Dictionary in _forge_entries(_brief.rack(profile, "side0")):
		assert_eq(str(part["reason"]), "", "con la Forja del hito 10, abiertas")
	profile.owned.append("arena_hoja_ion")
	assert_eq(_forge_entries(_brief.rack(profile, "side0")).size(), 8, "la que tienes no")


func test_se_guarda_y_se_pierde_con_la_partida() -> void:
	var profile := _profile()
	profile.arena_gear["arena_bateria_cin"] = 3
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(copy.arena_gear, {"arena_bateria_cin": 3})
	copy.end_run()
	assert_eq(copy.arena_gear, {})


func _forge_entries(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for part: Dictionary in state["parts"]:
		if bool(part.get("forge", false)):
			out.append(part)
	return out
