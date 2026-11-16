extends GutTest
## GDD 7: copias del combate para la busqueda, decisiones de la IA y ejecutor.

const D := BattleAI.Difficulty

# --- Copias del motor ---


func test_la_copia_es_independiente_del_original() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"uses": 2})]), Fx.build())
	var copy := e.clone()
	copy.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 1000, "el original no cambia")
	assert_eq(e.actions_left, 2)
	assert_eq(e.mechs[0].slots["side0"].uses_left, 2)
	assert_false(e.mechs[0].slots["side0"].used_this_turn)
	assert_eq(copy.mechs[1].health, 900)
	assert_eq(copy.mechs[0].slots["side0"].uses_left, 1)


func test_la_copia_de_busqueda_usa_el_dano_esperado_y_no_registra() -> void:
	var gun := Fx.gun({"dmg_min": 100, "dmg_max": 200})
	var e := Fx.engine(Fx.build([gun]), Fx.build())
	var events_before := e.events.size()
	var copy := e.clone()
	copy.apply(BattleAction.weapon("side0"))
	assert_eq(copy.mechs[1].health, 850, "tirada fija a la mitad del rango")
	assert_eq(copy.events.size(), 0)
	assert_eq(e.events.size(), events_before)


func test_la_copia_exacta_reproduce_las_mismas_tiradas() -> void:
	var gun := Fx.gun({"dmg_min": 100, "dmg_max": 400})
	var e := Fx.engine(Fx.build([gun]), Fx.build([gun]), 1, null, 77)
	e.apply(BattleAction.weapon("side0"))
	var copy := e.clone(false)
	for engine: BattleEngine in [e, copy]:
		engine.apply(BattleAction.cool())
		engine.apply(BattleAction.weapon("side0"))
		engine.apply(BattleAction.cool())
		engine.apply(BattleAction.weapon("side0"))
	assert_eq(copy.mechs[0].health, e.mechs[0].health)
	assert_eq(copy.mechs[1].health, e.mechs[1].health)
	assert_eq(JSON.stringify(copy.events), JSON.stringify(e.events))


# --- Decisiones ---


func test_remata_cuando_puede_matar() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"dmg_min": 300, "dmg_max": 300})]), Fx.build())
	e.mechs[1].health = 250
	var action := BattleAI.new(D.NORMAL).choose_action(e)
	assert_eq(action.type, BattleAction.Type.WEAPON)
	assert_eq(action.slot, "side0")


func test_no_enfria_antes_de_tiempo_si_puede_atacar() -> void:
	# Regresion: la IA enfriaba cada turno por miedo a un enfriado forzado,
	# que cuesta la misma accion y ademas aprovecha el margen del tope.
	var heater := Fx.gun({"element": ItemDef.Element.HEAT, "heat_dmg": 60})
	var me := Fx.build([Fx.gun(), Fx.gun()])
	var e := Fx.engine(me, Fx.build([heater, heater]))
	e.mechs[0].heat = 150
	var ai := BattleAI.new(D.NORMAL)
	for i in 2:
		var action := ai.choose_action(e)
		assert_ne(action.type, BattleAction.Type.COOL, "accion %d" % i)
		e.apply(action)


func test_se_acerca_si_sus_armas_no_alcanzan() -> void:
	var short := Fx.gun({"range_min": 1, "range_max": 2})
	var e := Fx.engine(Fx.build([short]), Fx.build(), 2)
	var action := BattleAI.new(D.NORMAL).choose_action(e)
	assert_eq(action.type, BattleAction.Type.WALK)
	assert_gt(action.position, 2, "camina hacia el rival")


func test_no_dispara_un_arma_que_la_mataria_por_backfire() -> void:
	var risky := Fx.gun({"dmg_min": 500, "dmg_max": 500, "backfire": 100})
	var e := Fx.engine(Fx.build([risky]), Fx.build())
	e.mechs[0].health = 80
	var action := BattleAI.new(D.NORMAL).choose_action(e)
	assert_eq(e.why_illegal(action), "")
	assert_ne(action.type, BattleAction.Type.WEAPON)


func test_todas_las_dificultades_devuelven_acciones_legales() -> void:
	for difficulty: BattleAI.Difficulty in [D.RANDOM, D.EASY, D.NORMAL, D.HARD]:
		var e := Fx.engine(
			Fx.build([Fx.gun(), Fx.gun({"range_min": 3, "range_max": 6})]), Fx.build([Fx.gun()])
		)
		var ai := BattleAI.new(difficulty, 5)
		for step in 12:
			if e.is_over():
				break
			var action := ai.choose_action(e)
			assert_eq(e.why_illegal(action), "", "dificultad %d, paso %d" % [difficulty, step])
			e.apply(action)


func test_sin_combate_en_curso_no_hay_accion() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"dmg_min": 5000, "dmg_max": 5000})]), Fx.build())
	e.apply(BattleAction.weapon("side0"))
	assert_null(BattleAI.new(D.NORMAL).choose_action(e))


func test_la_ia_al_azar_es_determinista_por_semilla() -> void:
	var picks: Array[String] = []
	for attempt in 2:
		var e := Fx.engine(Fx.build([Fx.gun(), Fx.gun()]), Fx.build())
		var ai := BattleAI.new(D.RANDOM, 99)
		var sequence := ""
		for step in 6:
			var action := ai.choose_action(e)
			sequence += "%d:%s:%d " % [action.type, action.slot, action.position]
			e.apply(action)
		picks.append(sequence)
	assert_eq(picks[0], picks[1])


func test_la_valoracion_de_ganar_y_perder() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"dmg_min": 5000, "dmg_max": 5000})]), Fx.build())
	e.apply(BattleAction.weapon("side0"))
	var ai := BattleAI.new(D.NORMAL)
	assert_eq(ai.evaluate(e, 0), ai.config.win_value)
	assert_eq(ai.evaluate(e, 1), -ai.config.win_value)


# --- Ejecutor ---


func test_la_ia_normal_gana_a_la_ia_al_azar_con_mechs_reales() -> void:
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var wins := 0
	var battles := 0
	for id in library.ids():
		var build := library.make(id, catalog, rules, ItemDef.Tier.EPIC, 0)
		for seed_value in 2:
			var result := BattleRunner.run(
				rules,
				build,
				build,
				BattleAI.new(D.NORMAL, seed_value),
				BattleAI.new(D.RANDOM, seed_value + 50),
				seed_value,
				seed_value % 2
			)
			battles += 1
			if result["winner"] == 0:
				wins += 1
			assert_gt(result["turns"], 0)
			assert_between(result["margin"], 0.0, 1.0)
	assert_eq(wins, battles, "la IA normal gana los %d combates" % battles)


func test_el_ejecutor_es_determinista() -> void:
	var gun := Fx.gun({"dmg_min": 100, "dmg_max": 130})
	var results: Array[String] = []
	for attempt in 2:
		var result := BattleRunner.run(
			Fx.rules(),
			Fx.build([gun]),
			Fx.build([gun]),
			BattleAI.new(D.NORMAL, 1),
			BattleAI.new(D.NORMAL, 2),
			31
		)
		results.append(JSON.stringify(result))
	assert_eq(results[0], results[1])


func test_el_resumen_detecta_apagados_seguidos_del_mismo_mech() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	e.events = [
		{"event": "shutdown", "turn": 4, "actor": 1},
		{"event": "forced_cool", "turn": 5, "actor": 0},
		{"event": "shutdown", "turn": 6, "actor": 1},
		{"event": "weapon", "turn": 7, "actor": 0, "item": "arma", "damage": 10},
	]
	var summary := BattleRunner.summarize(e, 0)
	assert_true(summary["chained_shutdown"])
	assert_eq(summary["shutdowns"], [0, 2])
	assert_eq(summary["forced_cools"], [1, 0])
	assert_eq(summary["uses"], {"arma": 1})
	e.events = [
		{"event": "shutdown", "turn": 4, "actor": 1},
		{"event": "shutdown", "turn": 8, "actor": 1},
	]
	assert_false(
		BattleRunner.summarize(e, 0)["chained_shutdown"], "con un turno jugado en medio no cuenta"
	)
