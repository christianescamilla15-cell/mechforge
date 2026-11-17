extends GutTest
## Chasis (docs/CHASIS.md): cambia las estadisticas del mech y lo que gastan
## sus armas, sin tocar las piezas.

const T := ItemDef.Type


func _chassis(props: Dictionary) -> ChassisDef:
	var def := ChassisDef.new()
	for key: String in props:
		def.set(key, props[key])
	return def


func _build(chassis: ChassisDef) -> MechBuild:
	var build := MechBuild.new()
	build.chassis = chassis
	build.torso = Fx.torso({"res_physical": 20, "res_heat": 10})
	build.legs = Fx.legs()
	build.sides.assign([Fx.gun({"energy_cost": 50, "range_min": 1, "range_max": 9})])
	return build


func test_sin_chasis_no_cambia_nada() -> void:
	var r := Fx.rules()
	var plain := _build(null).summary(r)
	var neutral := _build(ChassisDef.new()).summary(r)
	assert_eq(neutral, plain)


func test_el_pesado_sube_vida_y_resistencias() -> void:
	var r := Fx.rules()
	var plain := _build(null).summary(r)
	var heavy := _build(_chassis({"health_mult": 1.4, "resistance_mult": 1.5})).summary(r)
	assert_eq(heavy["health"], roundi(plain["health"] * 1.4))
	assert_eq(heavy["res_physical"], 30)
	assert_eq(heavy["res_heat"], 15)
	assert_eq(heavy["energy_cap"], plain["energy_cap"], "no toca lo que no le corresponde")


func test_el_chasis_cambia_calor_y_enfriamiento() -> void:
	var r := Fx.rules()
	var plain := _build(null).summary(r)
	var cool := _build(_chassis({"heat_cap_mult": 1.5, "cooling_mult": 2.0})).summary(r)
	assert_eq(cool["heat_cap"], roundi(plain["heat_cap"] * 1.5))
	assert_eq(cool["cooling"], plain["cooling"] * 2)


func test_el_ligero_gasta_menos_energia_al_disparar() -> void:
	var r := Fx.rules()
	var light := _build(_chassis({"energy_cost_mult": 0.6}))
	var engine := BattleEngine.new(r, light, _build(null), 1, 0, 0)
	var before := engine.mechs[0].energy
	assert_eq(engine.apply(BattleAction.weapon("side0")), "")
	assert_eq(before - engine.mechs[0].energy, 30, "50 de costo por 0.6")


func test_el_costo_reducido_permite_disparar_con_poca_energia() -> void:
	var r := Fx.rules()
	var light := _build(_chassis({"energy_cost_mult": 0.6}))
	var engine := BattleEngine.new(r, light, _build(null), 1, 0, 0)
	engine.mechs[0].energy = 30
	assert_eq(
		engine.why_cant_use(engine.mechs[0], engine.mechs[1], "side0"), "", "con 30 le alcanza"
	)
	engine.mechs[0].energy = 29
	assert_eq(engine.why_cant_use(engine.mechs[0], engine.mechs[1], "side0"), "falta energia")


func test_la_prevision_usa_el_costo_del_chasis() -> void:
	var r := Fx.rules()
	var light := _build(_chassis({"energy_cost_mult": 0.6}))
	var engine := BattleEngine.new(r, light, _build(null), 1, 0, 0)
	var preview := engine.preview(BattleAction.weapon("side0"))
	assert_eq(preview["self_energy"], engine.mechs[0].energy - 30)


func test_la_potencia_de_disparo_multiplica_el_dano() -> void:
	var r := Fx.rules()
	# El rival resiste 20 de dano fisico: sin chasis el arma de 100 hace 80.
	var plain := BattleEngine.new(r, _build(null), _build(null), 1, 0, 0)
	assert_eq(plain.preview(BattleAction.weapon("side0"))["dmg_min"], 80)
	var strong := _build(_chassis({"damage_mult": 1.2}))
	var engine := BattleEngine.new(r, strong, _build(null), 1, 0, 0)
	var before := engine.mechs[1].health
	assert_eq(engine.preview(BattleAction.weapon("side0"))["dmg_min"], 100, "100 por 1.2, menos 20")
	assert_eq(engine.apply(BattleAction.weapon("side0")), "")
	assert_eq(before - engine.mechs[1].health, 100)


func test_al_maximo_nivel_el_chasis_rinde_completo() -> void:
	var r := RulesConfig.new()
	var heavy := _chassis({"health_mult": 1.25, "damage_mult": 0.9})
	var top := heavy.at_level(r.chassis_max_level, r)
	assert_almost_eq(top.health_mult, 1.25, 0.0001)
	assert_almost_eq(top.damage_mult, 0.9, 0.0001)
	assert_eq(top.level, r.chassis_max_level)


func test_al_principio_las_diferencias_son_pequenas() -> void:
	var r := RulesConfig.new()
	var heavy := _chassis({"health_mult": 1.25, "damage_mult": 0.9})
	var start := heavy.at_level(0, r)
	# En el nivel 0 solo se tiene la parte inicial de la bonificacion.
	assert_almost_eq(start.health_mult, 1.0 + 0.25 * r.chassis_start_share, 0.0001)
	assert_almost_eq(start.damage_mult, 1.0 - 0.1 * r.chassis_start_share, 0.0001)
	assert_almost_eq(heavy.health_mult, 1.25, 0.0001, "el chasis original no cambia")


func test_mejorar_el_chasis_potencia_su_bonificacion() -> void:
	var r := RulesConfig.new()
	var heavy := _chassis({"health_mult": 1.25})
	var previous := 1.0
	for step in [0, 10, 20, 30]:
		var current := heavy.at_level(step, r).health_mult
		assert_gt(current, previous, "nivel %d" % step)
		previous = current
	assert_almost_eq(heavy.at_level(999, r).health_mult, 1.25, 0.0001, "no pasa del maximo")


func test_los_tres_chasis_del_juego_cargan_sin_errores() -> void:
	var library := ChassisLibrary.load_file("res://data/chassis.json")
	assert_eq(library.errors, [] as Array[String])
	for id: String in ["ligero", "medio", "pesado"]:
		assert_true(id in library.ids(), id)
	assert_lt(library.get_def("ligero").energy_cost_mult, 1.0, "el ligero gasta menos energia")
	assert_gt(library.get_def("pesado").health_mult, 1.0, "el pesado tiene mas vida")
	assert_gt(library.get_def("pesado").resistance_mult, 1.0, "y mas resistencias")


func test_el_pesado_se_consigue_despues_del_nivel_10() -> void:
	var library := ChassisLibrary.load_file("res://data/chassis.json")
	var at_10: Array[String] = []
	for def in library.unlocked_at(10):
		at_10.append(def.id)
	assert_false("pesado" in at_10, "en el nivel 10 todavia no")
	var at_11: Array[String] = []
	for def in library.unlocked_at(11):
		at_11.append(def.id)
	assert_true("pesado" in at_11)
	assert_true("ligero" in at_10, "el ligero esta desde el principio")


func test_el_chasis_de_jefe_da_una_accion_mas_y_no_mas_vida() -> void:
	var library := ChassisLibrary.load_file("res://data/chassis.json")
	var boss := library.get_def("jefe")
	assert_eq(boss.extra_actions, 1)
	assert_almost_eq(boss.health_mult, 1.0, 0.0001, "dificil por como juega, no por vida")
	var ids: Array[String] = []
	for def in library.unlocked_at(50):
		ids.append(def.id)
	assert_false("jefe" in ids, "el jugador no puede conseguirlo")


func test_un_jefe_tiene_3_acciones_y_al_enfriar_a_la_fuerza_solo_1() -> void:
	var r := Fx.rules()
	var boss := _build(_chassis({"extra_actions": 1}))
	var engine := BattleEngine.new(r, boss, _build(null), 1, 0, 0)
	assert_eq(engine.actions_left, 3)
	for i in 3:
		engine.apply(BattleAction.cool())
	assert_eq(engine.turn, 1, "tras 3 acciones pasa el turno")
	assert_eq(engine.actions_left, 2, "el rival sigue con 2")
	# Sobrecalentado: el enfriado forzado le deja una sola accion, como a todos.
	engine.mechs[0].heat = engine.mechs[0].heat_cap + 1
	engine.apply(BattleAction.cool())
	engine.apply(BattleAction.cool())
	assert_eq(engine.turn, 0)
	assert_eq(engine.actions_left, 1)


func test_los_datos_malos_se_avisan() -> void:
	var library := ChassisLibrary.new()
	library.add({"name": "sin id"})
	library.add({"id": "a", "fuerza": 2.0})
	library.add({"id": "b", "health_mult": 9.0})
	library.add({"id": "b"})
	assert_eq(library.errors.size(), 4)
	assert_string_contains(library.errors[1], "campo desconocido")
	assert_string_contains(library.errors[2], "fuera de rango")
	assert_string_contains(library.errors[3], "repetido")
