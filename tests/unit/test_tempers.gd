extends GutTest
## Cada rival tiene su caracter al pelear (OBS-014 de docs/OBSERVACIONES.md:
## "es muy predecible; los enemigos no hacen mas que atacar; no usan
## estrategia"). Medido el 2026-11-21 con tools/sim/behavior_sim.gd: cambiar
## solo los pesos de la valoracion casi no movia nada (seguian disparando un
## 75-95 %); lo que cambia lo que hacen son sus gustos por cada tipo de accion
## (AIConfig.likes). Los temperamentos estan en data/tempers.json y cada
## diseno dice el suyo en data/builds.json.

const BATTLES := 6

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _tempers: TemperLibrary
var _brief: MissionBrief


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_tempers = TemperLibrary.load_file("res://data/tempers.json")
	_brief = MissionBrief.new()
	_brief.rules = _rules
	_brief.catalog = _catalog
	_brief.library = _library
	_brief.chassis = ChassisLibrary.load_file("res://data/chassis.json")
	_brief.campaign = Campaign.load_file("res://data/campaign.json", _library)
	_brief.shop = ArenaShop.load_file("res://data/arena_shop.json")


## Cuantas acciones de esos tipos hace ese rival en unos cuantos combates
## contra el mismo jugador, pensando con esa valoracion.
func _count(rival_id: String, config: AIConfig, kinds: Array) -> int:
	var player := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 3)
	var rival := _library.make(rival_id, _catalog, _rules, ItemDef.Tier.COMMON, 2)
	rival.skills = SkillSet.new()
	rival.skills.add({"shield_uses": 1, "repair_uses": 1, "repair_share": 0.2})
	var total := 0
	for seed_value in BATTLES:
		var engine := BattleEngine.new(_rules, player, rival, seed_value + 1, seed_value % 2)
		var ais: Array[BattleAI] = [
			BattleAI.new(BattleAI.Difficulty.NORMAL, seed_value * 2 + 1),
			BattleAI.new(BattleAI.Difficulty.NORMAL, seed_value * 2 + 2, config),
		]
		while not engine.is_over() and engine.turn_number <= 200:
			var who := engine.turn
			var action := ais[who].choose_action(engine)
			if action == null or engine.apply(action) != "":
				break
			if who == 1 and action.type in kinds:
				total += 1
	return total


func test_los_temperamentos_cargan_sin_errores() -> void:
	assert_eq(_tempers.errors, [] as Array[String])
	assert_eq(_tempers.ids(), ["agresivo", "defensivo", "desgaste", "esquivo"] as Array[String])
	assert_eq(_tempers.missing_in(_library), [] as Array[String], "cada diseno pide uno que existe")


func test_cada_rival_normal_tiene_su_caracter_y_los_jefes_no() -> void:
	for id in _library.ids():
		assert_true(_tempers.has(_library.temper_of(id)), "%s tiene caracter" % id)
	for id in _library.boss_ids():
		assert_eq(_library.temper_of(id), "", "%s piensa como siempre" % id)
	assert_eq(_library.temper_of("no_existe"), "")


func test_las_cuatro_familias_no_piensan_igual() -> void:
	var seen := {}
	for id in _library.starter_ids():
		seen[_library.temper_of(id)] = true
	assert_eq(seen.size(), 4, "fisico, calor, energia e hibrido: cada uno el suyo")
	# Y la familia lo conserva de una liga a otra.
	assert_eq(
		_library.temper_of("fisico_vanguardia_laser"), _library.temper_of("fisico_vanguardia")
	)


func test_sin_temperamento_la_ia_es_la_de_siempre() -> void:
	var plain := _tempers.config("")
	var base := AIConfig.new()
	for key in TemperLibrary.WEIGHTS:
		assert_eq(plain.get(key), base.get(key), key)
	assert_eq(plain.likes, {})
	assert_eq(_tempers.config("no_existe").likes, {})
	for key: String in ["guard", "aggression", "pressure", "caution", "evasion"]:
		assert_eq(base.get(key), 1.0, "%s neutro: no cambia la valoracion" % key)
	# Mismo combate, misma semilla: con la valoracion neutra elige lo mismo.
	var player := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 3)
	var rival := _library.make("calor_horno", _catalog, _rules, ItemDef.Tier.COMMON, 2)
	var engine := BattleEngine.new(_rules, player, rival, 7, 0)
	var usual := BattleAI.new(BattleAI.Difficulty.HARD, 3)
	var neutral := BattleAI.new(BattleAI.Difficulty.HARD, 3, plain)
	var steps := 0
	while not engine.is_over() and steps < 12:
		var a := usual.choose_action(engine)
		var b := neutral.choose_action(engine)
		assert_eq([a.type, a.slot, a.position], [b.type, b.slot, b.position])
		engine.apply(a)
		steps += 1


func test_un_temperamento_lleva_sus_pesos_y_sus_gustos() -> void:
	var config := _tempers.config("defensivo")
	assert_gt(config.guard, 1.0, "se cuida")
	assert_gt(float(config.likes.get("shield", 0.0)), 0.0, "y le gusta cubrirse")
	assert_gt(_tempers.config("agresivo").aggression, 1.0)
	assert_gt(_tempers.config("desgaste").pressure, 1.0)
	assert_gt(_tempers.config("esquivo").evasion, 1.0)
	# Lo que devuelve es una copia: tocarla no cambia el temperamento.
	config.likes["shield"] = 9.0
	assert_lt(float(_tempers.config("defensivo").likes["shield"]), 1.0)


func test_un_temperamento_mal_escrito_no_carga() -> void:
	var library := TemperLibrary.new()
	library.add("agresivo")
	library.add({"weights": {"guard": 2.0}})
	library.add({"id": "raro", "weights": {"fuerza": 2.0}})
	library.add({"id": "negativo", "weights": {"guard": -1.0}})
	library.add({"id": "gusto", "likes": {"bailar": 0.1}})
	library.add({"id": "vacio"})
	assert_eq(library.ids(), [] as Array[String])
	assert_eq(library.errors.size(), 6)
	library.add({"id": "bien", "likes": {"cool": 0.02}})
	library.add({"id": "bien", "weights": {"guard": 1.2}})
	assert_eq(library.ids(), ["bien"] as Array[String], "repetido: se queda el primero")
	assert_eq(library.errors.size(), 7)


func test_el_caracter_cambia_lo_que_hace_el_rival() -> void:
	var t := BattleAction.Type
	var cases := [
		["fisico_vanguardia", [t.CHARGE, t.HOOK, t.STOMP], "el agresivo embiste, engancha y pisa"],
		["hibrido_quimera", [t.COOL, t.SHIELD, t.REPAIR], "el defensivo enfria y se cubre"],
		["calor_horno", [t.STOMP, t.HOOK], "el de desgaste se te echa encima"],
		["energia_tempestad", [t.WALK, t.TELEPORT], "el esquivo se mueve"],
	]
	for case: Array in cases:
		var id: String = case[0]
		var with := _count(id, _tempers.config(_library.temper_of(id)), case[1])
		var without := _count(id, AIConfig.new(), case[1])
		assert_gt(with, without, "%s (%d frente a %d)" % [case[2], with, without])


func test_el_hangar_dice_el_caracter_del_rival() -> void:
	var rival := _brief.rival({"enemy": "fisico_vanguardia", "level": 0, "difficulty": "EASY"}, 0)
	assert_eq(rival["temper"], "agresivo")
	assert_eq(rival["traits"], "Agresivo", "en su renglon, con mayuscula")
	assert_false(str(rival["detail"]).contains("gresivo"), "no alarga el de la clase")
	var names := {}
	for id in _library.starter_ids():
		var entry := _brief.rival({"enemy": id, "level": 0, "difficulty": "EASY"}, 0)
		names[Txt.t("temper_" + str(entry["temper"]))] = true
		assert_false(str(entry["traits"]).contains("temper_"), "tiene su texto")
	assert_eq(names.size(), 4)
	var boss := _brief.rival({"enemy": "jefe_zona_1", "level": 3, "difficulty": "HARD"}, 0)
	assert_eq(boss["temper"], "")
	assert_eq(boss["traits"], "")
