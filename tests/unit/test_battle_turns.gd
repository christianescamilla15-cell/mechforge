extends GutTest
## GDD 2.1, 2.2 y mejoras M2/M5: arena, ciclo de turno, calor, dron y victoria.


func test_posiciones_iniciales_del_par_elegido() -> void:
	var e := Fx.engine(Fx.build(), Fx.build(), 2)
	assert_eq(e.mechs[0].position, 2)
	assert_eq(e.mechs[1].position, 8)


func test_par_inicial_al_azar_es_uno_de_los_validos() -> void:
	var e := BattleEngine.new(Fx.rules(), Fx.build(), Fx.build(), 7)
	var pair := Vector2i(e.mechs[0].position, e.mechs[1].position)
	assert_true(pair in e.rules.start_positions)


func test_dos_acciones_por_turno_y_luego_pasa() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	assert_eq(e.actions_left, 2)
	e.apply(BattleAction.cool())
	assert_eq(e.turn, 0)
	assert_eq(e.actions_left, 1)
	e.apply(BattleAction.cool())
	assert_eq(e.turn, 1)
	assert_eq(e.actions_left, 2)


func test_empieza_con_energia_llena_y_calor_cero() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	assert_eq(e.mechs[0].energy, 200)
	assert_eq(e.mechs[0].heat, 0)
	assert_eq(e.mechs[0].health, 1000)


func test_regenera_energia_al_final_del_turno_sin_pasar_el_tope() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	e.mechs[0].energy = 10
	Fx.pass_turn(e)
	assert_eq(e.mechs[0].energy, 60)
	e.mechs[1].energy = 190
	Fx.pass_turn(e)
	assert_eq(e.mechs[1].energy, 200)


func test_enfriar_baja_el_calor_sin_pasar_de_cero() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	e.mechs[0].heat = 70
	e.apply(BattleAction.cool())
	assert_eq(e.mechs[0].heat, 20)
	e.apply(BattleAction.cool())
	assert_eq(e.mechs[0].heat, 0)


func test_no_hay_enfriamiento_pasivo() -> void:
	var e := Fx.engine(Fx.build([Fx.gun()]), Fx.build())
	e.mechs[1].heat = 150
	Fx.pass_turn(e)
	assert_eq(e.mechs[1].heat, 150, "por debajo del tope el calor no baja solo")


func test_enfriado_forzado_deja_una_accion() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	e.mechs[1].heat = 210
	Fx.pass_turn(e)
	assert_eq(e.turn, 1)
	assert_eq(e.actions_left, 1)
	assert_eq(e.mechs[1].heat, 160)
	assert_true(Fx.has_event(e, "forced_cool"))


func test_calor_igual_al_tope_no_fuerza_enfriado() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	e.mechs[1].heat = 200
	Fx.pass_turn(e)
	assert_eq(e.actions_left, 2)


func test_apagado_pierde_el_turno_y_enfria_doble() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	e.mechs[1].heat = 260
	Fx.pass_turn(e)
	assert_eq(e.turn, 0, "el turno vuelve al mech 0")
	assert_eq(e.actions_left, 2)
	assert_eq(e.mechs[1].heat, 160)
	assert_true(Fx.has_event(e, "shutdown"))


func test_apagado_no_dispara_dron_pero_si_regenera() -> void:
	var drone := Fx.item(ItemDef.Type.DRONE, {"dmg_min": 40, "dmg_max": 40})
	var e := Fx.engine(Fx.build(), Fx.build([], {"drone": drone}))
	e.mechs[1].heat = 260
	e.mechs[1].energy = 0
	Fx.pass_turn(e)
	assert_eq(e.mechs[0].health, 1000)
	assert_eq(e.mechs[1].energy, 50)


func test_m2_evita_dos_apagados_seguidos() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	e.mechs[1].heat = 260
	Fx.pass_turn(e)
	e.mechs[1].heat = 260
	Fx.pass_turn(e)
	assert_eq(e.turn, 1, "esta vez juega, con enfriado forzado")
	assert_eq(e.actions_left, 1)
	assert_eq(e.mechs[1].heat, 210)


func test_sin_m2_se_pueden_encadenar_apagados() -> void:
	var rules := Fx.rules({"m2_no_chain_shutdown": false})
	var e := Fx.engine(Fx.build(), Fx.build(), 0, rules)
	e.mechs[1].heat = 260
	Fx.pass_turn(e)
	e.mechs[1].heat = 260
	Fx.pass_turn(e)
	assert_eq(e.turn, 0)
	assert_eq(e.mechs[1].heat, 160)


func test_m5_primer_turno_con_una_accion() -> void:
	var rules := Fx.rules({"m5_first_turn_single_action": true})
	var e := Fx.engine(Fx.build(), Fx.build(), 0, rules)
	assert_eq(e.actions_left, 1)
	e.apply(BattleAction.cool())
	assert_eq(e.turn, 1)
	assert_eq(e.actions_left, 2, "el segundo jugador ya tiene sus 2 acciones")
	Fx.pass_turn(e)
	assert_eq(e.actions_left, 2, "y el primero tambien desde su segundo turno")


func test_dron_dispara_tras_la_ultima_accion_sin_gastar_accion() -> void:
	var drone := Fx.item(
		ItemDef.Type.DRONE, {"dmg_min": 40, "dmg_max": 40, "range_min": 1, "range_max": 3}
	)
	var e := Fx.engine(Fx.build([], {"drone": drone}), Fx.build())
	e.apply(BattleAction.cool())
	assert_eq(e.mechs[1].health, 1000, "aun no dispara")
	e.apply(BattleAction.cool())
	assert_eq(e.mechs[1].health, 960)
	assert_eq(e.turn, 1)


func test_dron_no_dispara_fuera_de_alcance_ni_sin_energia() -> void:
	var drone := Fx.item(
		ItemDef.Type.DRONE,
		{"dmg_min": 40, "dmg_max": 40, "range_min": 1, "range_max": 3, "energy_cost": 30}
	)
	var lejos := Fx.engine(Fx.build([], {"drone": drone}), Fx.build(), 2)
	Fx.pass_turn(lejos)
	assert_eq(lejos.mechs[1].health, 1000)
	var seco := Fx.engine(Fx.build([], {"drone": drone}), Fx.build())
	seco.mechs[0].energy = 10
	Fx.pass_turn(seco)
	assert_eq(seco.mechs[1].health, 1000)


func test_victoria_al_dejar_al_rival_sin_vida() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"dmg_min": 5000, "dmg_max": 5000})]), Fx.build())
	e.apply(BattleAction.weapon("side0"))
	assert_true(e.is_over())
	assert_eq(e.winner, 0)
	assert_eq(e.legal_actions().size(), 0)
	assert_ne(e.apply(BattleAction.cool()), "", "ya no se aceptan acciones")


func test_el_dron_tambien_puede_ganar_el_combate() -> void:
	var drone := Fx.item(ItemDef.Type.DRONE, {"dmg_min": 5000, "dmg_max": 5000})
	var e := Fx.engine(Fx.build([], {"drone": drone}), Fx.build())
	Fx.pass_turn(e)
	assert_eq(e.winner, 0)


func test_repeticion_determinista() -> void:
	var a := _run_scripted(123)
	var b := _run_scripted(123)
	assert_eq(JSON.stringify(a.events), JSON.stringify(b.events))
	assert_eq(a.mechs[1].health, b.mechs[1].health)
	var c := _run_scripted(999)
	assert_ne(JSON.stringify(a.events), JSON.stringify(c.events), "otra semilla, otras tiradas")


func _run_scripted(seed_value: int) -> BattleEngine:
	var gun := Fx.gun({"dmg_min": 100, "dmg_max": 400})
	var e := Fx.engine(Fx.build([gun]), Fx.build([gun]), 1, null, seed_value)
	for i in 3:
		e.apply(BattleAction.weapon("side0"))
		e.apply(BattleAction.cool())
	return e
