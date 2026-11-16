extends GutTest
## GDD 2.3 a 2.6: acciones, formula de dano, efectos, movimiento y validaciones.

# --- Dano ---


func test_dano_menos_resistencia() -> void:
	var foe := Fx.build([], {"torso": Fx.torso({"res_physical": 30})})
	var e := Fx.engine(Fx.build([Fx.gun()]), foe)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 930)


func test_la_resistencia_es_por_elemento() -> void:
	var foe := Fx.build([], {"torso": Fx.torso({"res_physical": 30})})
	var heat_gun := Fx.gun({"element": ItemDef.Element.HEAT})
	var e := Fx.engine(Fx.build([heat_gun]), foe)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 900)


func test_dano_minimo_uno() -> void:
	var foe := Fx.build([], {"torso": Fx.torso({"res_physical": 500})})
	var e := Fx.engine(Fx.build([Fx.gun()]), foe)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 999)


func test_la_tirada_cae_dentro_del_rango() -> void:
	for seed_value in 30:
		var gun := Fx.gun({"dmg_min": 100, "dmg_max": 130})
		var e := Fx.engine(Fx.build([gun]), Fx.build(), 0, null, seed_value)
		e.apply(BattleAction.weapon("side0"))
		var dealt := 1000 - e.mechs[1].health
		assert_between(dealt, 100, 130)


func test_rotura_de_energia_suma_el_sobrante_como_dano() -> void:
	var zap := Fx.gun(
		{"element": ItemDef.Element.ENERGY, "dmg_min": 50, "dmg_max": 50, "energy_dmg": 80}
	)
	var e := Fx.engine(Fx.build([zap]), Fx.build())
	e.mechs[1].energy = 30
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 1000 - 50 - 50)
	assert_eq(e.mechs[1].energy, 0)


func test_sin_rotura_si_al_rival_le_sobra_energia() -> void:
	var zap := Fx.gun(
		{"element": ItemDef.Element.ENERGY, "dmg_min": 50, "dmg_max": 50, "energy_dmg": 80}
	)
	var e := Fx.engine(Fx.build([zap]), Fx.build())
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 950)
	assert_eq(e.mechs[1].energy, 120)


# --- Efectos ---


func test_costos_y_backfire_sobre_el_atacante() -> void:
	var gun := Fx.gun({"heat_cost": 20, "energy_cost": 30, "backfire": 10})
	var e := Fx.engine(Fx.build([gun]), Fx.build())
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].heat, 20)
	assert_eq(e.mechs[0].energy, 170)
	assert_eq(e.mechs[0].health, 990)


func test_dano_de_calor_al_rival() -> void:
	var gun := Fx.gun({"element": ItemDef.Element.HEAT, "heat_dmg": 90})
	var e := Fx.engine(Fx.build([gun]), Fx.build())
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].heat, 90)


func test_danos_permanentes_con_sus_minimos() -> void:
	var gun := (
		Fx
		. gun(
			{
				"res_dmg": 50,
				"heat_cap_dmg": 999,
				"cooling_dmg": 20,
				"energy_cap_dmg": 150,
				"energy_regen_dmg": 999,
			}
		)
	)
	var foe := Fx.build([], {"torso": Fx.torso({"res_physical": 30})})
	var e := Fx.engine(Fx.build([gun]), foe)
	e.apply(BattleAction.weapon("side0"))
	var m := e.mechs[1]
	assert_eq(m.res[ItemDef.Element.PHYSICAL], 0, "la resistencia no baja de 0")
	assert_eq(m.heat_cap, 1)
	assert_eq(m.cooling, 30)
	assert_eq(m.energy_cap, 50)
	assert_eq(m.energy, 50, "la energia se recorta al nuevo tope")
	assert_eq(m.energy_regen, 1)


func test_la_resistencia_rota_hace_mas_dano_despues() -> void:
	var gun := Fx.gun({"res_dmg": 20})
	var foe := Fx.build([], {"torso": Fx.torso({"res_physical": 30})})
	var e := Fx.engine(Fx.build([gun, gun]), foe)
	e.apply(BattleAction.weapon("side0"))
	e.apply(BattleAction.weapon("side1"))
	assert_eq(e.mechs[1].health, 1000 - 70 - 90)


# --- Validaciones (GDD 2.6) ---


func test_un_arma_solo_una_vez_por_turno() -> void:
	var e := Fx.engine(Fx.build([Fx.gun()]), Fx.build())
	assert_eq(e.apply(BattleAction.weapon("side0")), "")
	assert_eq(e.apply(BattleAction.weapon("side0")), "ya se uso este turno")
	assert_eq(e.actions_left, 1, "la accion rechazada no gasta nada")
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	assert_eq(e.apply(BattleAction.weapon("side0")), "", "en el turno siguiente vuelve a servir")


func test_dos_copias_de_la_misma_arma_son_huecos_distintos() -> void:
	var gun := Fx.gun({"uses": 1})
	var e := Fx.engine(Fx.build([gun, gun]), Fx.build())
	assert_eq(e.apply(BattleAction.weapon("side0")), "")
	assert_eq(e.apply(BattleAction.weapon("side1")), "")
	assert_eq(e.mechs[1].health, 800)


func test_sin_energia_no_dispara() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"energy_cost": 50})]), Fx.build())
	e.mechs[0].energy = 49
	assert_eq(e.apply(BattleAction.weapon("side0")), "falta energia")


func test_backfire_no_puede_matar_al_que_dispara() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"backfire": 100})]), Fx.build())
	e.mechs[0].health = 100
	assert_eq(e.apply(BattleAction.weapon("side0")), "falta vida")
	e.mechs[0].health = 101
	assert_eq(e.apply(BattleAction.weapon("side0")), "")


func test_usos_limitados_por_pelea() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"uses": 1})]), Fx.build())
	assert_eq(e.apply(BattleAction.weapon("side0")), "")
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	assert_eq(e.apply(BattleAction.weapon("side0")), "sin usos")


func test_fuera_de_alcance() -> void:
	var sniper := Fx.gun({"range_min": 3, "range_max": 6})
	var cerca := Fx.engine(Fx.build([sniper]), Fx.build(), 0)
	assert_eq(cerca.apply(BattleAction.weapon("side0")), "fuera de alcance")
	var justo := Fx.engine(Fx.build([sniper]), Fx.build(), 1)
	assert_eq(justo.apply(BattleAction.weapon("side0")), "")
	var limite := Fx.engine(Fx.build([sniper]), Fx.build(), 2)
	assert_eq(limite.apply(BattleAction.weapon("side0")), "", "distancia 6 entra en [3,6]")


func test_arma_con_retirada_requiere_piernas_que_salten() -> void:
	var gun := Fx.gun({"retreat": 1})
	var ruedas := Fx.legs({"walk": 3, "jump": 0})
	var e := Fx.engine(Fx.build([gun], {"legs": ruedas}), Fx.build(), 1)
	assert_eq(e.apply(BattleAction.weapon("side0")), "requiere salto")
	var melee := Fx.gun({"retreat": 1, "tags": PackedStringArray([ItemDef.TAG_MELEE])})
	var e2 := Fx.engine(Fx.build([melee], {"legs": ruedas}), Fx.build(), 1)
	assert_eq(e2.apply(BattleAction.weapon("side0")), "", "cuerpo a cuerpo no lo exige")


func test_la_retirada_no_puede_sacar_de_la_arena() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"retreat": 3})]), Fx.build(), 2)
	assert_eq(e.apply(BattleAction.weapon("side0")), "la retirada sale de la arena")


func test_legal_actions_solo_devuelve_acciones_legales() -> void:
	var sniper := Fx.gun({"range_min": 3, "range_max": 6})
	var e := Fx.engine(Fx.build([Fx.gun(), sniper]), Fx.build())
	var actions := e.legal_actions()
	for action in actions:
		assert_eq(e.why_illegal(action), "")
	var slots := actions.map(func(a: BattleAction) -> String: return a.slot)
	assert_has(slots, "side0")
	assert_does_not_have(slots, "side1")
	var types := actions.map(func(a: BattleAction) -> int: return a.type)
	assert_has(types, BattleAction.Type.COOL)
	assert_has(types, BattleAction.Type.STOMP)


# --- Movimiento ---


func test_caminar_sin_salto_no_cruza_al_rival() -> void:
	var ruedas := Fx.legs({"walk": 3, "jump": 0})
	var e := Fx.engine(Fx.build([], {"legs": ruedas}), Fx.build())
	assert_eq(e.walkable_positions(), [1, 2, 3] as Array[int])


func test_caminar_con_salto_cruza_pero_no_cae_encima() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	assert_eq(e.walkable_positions(), [2, 3, 6] as Array[int])
	assert_ne(e.apply(BattleAction.walk(5)), "")
	assert_eq(e.apply(BattleAction.walk(6)), "")
	assert_eq(e.mechs[0].position, 6)


func test_caminar_respeta_los_bordes() -> void:
	var e := Fx.engine(Fx.build(), Fx.build(), 2)
	e.mechs[0].position = 0
	assert_eq(e.walkable_positions(), [1, 2] as Array[int])


func test_pisoton_solo_pegado_al_rival() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	assert_eq(e.apply(BattleAction.stomp()), "")
	assert_eq(e.mechs[1].health, 950)
	var lejos := Fx.engine(Fx.build(), Fx.build(), 1)
	assert_eq(lejos.apply(BattleAction.stomp()), "fuera de alcance")


func test_empuje_se_detiene_en_el_borde() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"push": 3})]), Fx.build(), 2)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].position, 9)


func test_empuje_hacia_la_izquierda_cuando_el_rival_esta_a_la_izquierda() -> void:
	var e := Fx.engine(Fx.build(), Fx.build([Fx.gun({"push": 2})]), 1)
	Fx.pass_turn(e)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].position, 1)


func test_jalon_trae_al_rival_hasta_quedar_pegado() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"pull": 2}), Fx.gun({"pull": 10})]), Fx.build(), 2)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].position, 6)
	e.apply(BattleAction.weapon("side1"))
	assert_eq(e.mechs[1].position, 3)


func test_retroceso_y_retirada_mueven_al_atacante_hacia_atras() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"recoil": 1}), Fx.gun({"retreat": 1})]), Fx.build(), 2)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].position, 1)
	e.apply(BattleAction.weapon("side1"))
	assert_eq(e.mechs[0].position, 0)


func test_retroceso_se_detiene_en_el_borde() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"recoil": 5})]), Fx.build(), 2)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].position, 0)


func test_avance_acerca_sin_pasar_del_rival() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"advance": 3}), Fx.gun({"advance": 9})]), Fx.build(), 2)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].position, 5)
	e.apply(BattleAction.weapon("side1"))
	assert_eq(e.mechs[0].position, 7)


func test_la_espada_salta_junto_al_rival_antes_de_golpear() -> void:
	var sword := Fx.gun({"tags": PackedStringArray([ItemDef.TAG_MELEE, ItemDef.TAG_SWORD])})
	var e := Fx.engine(Fx.build([sword]), Fx.build(), 2)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].position, 7)
	assert_eq(e.mechs[1].health, 900)


# --- Especiales ---


func test_carga_embiste_hasta_quedar_pegado() -> void:
	var charge := Fx.item(ItemDef.Type.CHARGE, {"dmg_min": 150, "dmg_max": 150, "uses": 1})
	var e := Fx.engine(Fx.build([], {"charge": charge}), Fx.build(), 2)
	assert_eq(e.apply(BattleAction.charge()), "")
	assert_eq(e.mechs[0].position, 7)
	assert_eq(e.mechs[1].health, 850)
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	assert_eq(e.apply(BattleAction.charge()), "sin usos")


func test_teletransporte_solo_dana_si_cae_junto_al_rival() -> void:
	var tele := Fx.item(
		ItemDef.Type.TELEPORT,
		{
			"element": ItemDef.Element.ENERGY,
			"dmg_min": 80,
			"dmg_max": 80,
			"uses": 2,
			"energy_cost": 20
		}
	)
	var e := Fx.engine(Fx.build([], {"teleport": tele}), Fx.build(), 2)
	assert_eq(e.apply(BattleAction.teleport(0)), "")
	assert_eq(e.mechs[0].position, 0)
	assert_eq(e.mechs[1].health, 1000, "lejos no hace dano")
	assert_eq(e.mechs[0].energy, 180, "pero el salto se paga")
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	assert_eq(e.apply(BattleAction.teleport(9)), "", "puede caer al otro lado del rival")
	assert_eq(e.mechs[1].health, 920)
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	assert_eq(e.apply(BattleAction.teleport(5)), "sin usos")


func test_teletransporte_no_puede_caer_en_casilla_ocupada() -> void:
	var tele := Fx.item(ItemDef.Type.TELEPORT, {"uses": 1})
	var e := Fx.engine(Fx.build([], {"teleport": tele}), Fx.build(), 2)
	assert_ne(e.apply(BattleAction.teleport(8)), "")
	assert_ne(e.apply(BattleAction.teleport(2)), "")
	assert_ne(e.apply(BattleAction.teleport(10)), "")


func test_gancho_trae_al_rival_y_hace_dano() -> void:
	var hook := Fx.item(ItemDef.Type.HOOK, {"dmg_min": 120, "dmg_max": 120, "uses": 1})
	var e := Fx.engine(Fx.build([], {"hook": hook}), Fx.build(), 2)
	assert_eq(e.apply(BattleAction.hook()), "")
	assert_eq(e.mechs[1].position, 3)
	assert_eq(e.mechs[1].health, 880)


func test_especial_no_equipado_es_ilegal() -> void:
	var e := Fx.engine(Fx.build(), Fx.build())
	assert_ne(e.apply(BattleAction.charge()), "")
	assert_ne(e.apply(BattleAction.hook()), "")
	assert_ne(e.apply(BattleAction.teleport(0)), "")
	assert_ne(e.apply(BattleAction.weapon("side0")), "")
	assert_ne(e.apply(BattleAction.weapon("drone")), "", "el dron no se dispara a mano")


# --- Previsualizacion (M3) ---


func test_preview_coincide_con_el_resultado_real() -> void:
	var gun := (
		Fx
		. gun(
			{
				"element": ItemDef.Element.HEAT,
				"dmg_min": 100,
				"dmg_max": 130,
				"heat_dmg": 250,
				"heat_cost": 40,
				"energy_cost": 30,
			}
		)
	)
	var foe := Fx.build([], {"torso": Fx.torso({"res_heat": 20})})
	var e := Fx.engine(Fx.build([gun]), foe)
	var p := e.preview(BattleAction.weapon("side0"))
	assert_true(p["legal"])
	assert_eq(p["dmg_min"], 80)
	assert_eq(p["dmg_max"], 110)
	assert_eq(p["self_heat"], 40)
	assert_eq(p["self_energy"], 170)
	assert_eq(p["target_heat"], 250)
	assert_true(p["target_overheats"])
	assert_false(p["self_overheats"])
	assert_eq(e.mechs[1].health, 1000, "previsualizar no cambia nada")
	e.apply(BattleAction.weapon("side0"))
	assert_between(1000 - e.mechs[1].health, p["dmg_min"], p["dmg_max"])
	assert_eq(e.mechs[1].heat, p["target_heat"])
