extends GutTest
## Salir a combatir desde el hangar, sin menu (pedido del usuario el
## 2026-11-20): el monitor de misiones (MissionBoard) es el cuadro de campana
## y, al pulsarlo, los rivales se proyectan en fila delante de tu robot
## (RivalRow, HangarStage); pulsar al primero es salir a combatir. Lo que
## ensenan lo arma MissionBrief: la campana (la escalera de la zona hasta su
## jefe), la arena y el combate libre.

var _catalog: Catalog
var _rules: RulesConfig
var _library: BuildLibrary
var _campaign: Campaign
var _brief: MissionBrief


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	_rules = RulesConfig.new()
	_library = BuildLibrary.load_file("res://data/builds.json")
	_campaign = Campaign.load_file("res://data/campaign.json", _library)
	_brief = MissionBrief.new()
	_brief.rules = _rules
	_brief.catalog = _catalog
	_brief.library = _library
	_brief.chassis = ChassisLibrary.load_file("res://data/chassis.json")
	_brief.campaign = _campaign
	_brief.shop = ArenaShop.load_file("res://data/arena_shop.json")


func _profile(fight: int = 0, zone: int = 0) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.zone = zone
	profile.fight = fight
	return profile


func _stage() -> HangarStage:
	var stage := HangarStage.new()
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)
	var build := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 6)
	stage.show_build(build, [] as Array[String])
	return stage


func _click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


# --- La escalera (Campaign.ladder) ------------------------------------------------


func test_la_escalera_empieza_en_el_combate_que_toca() -> void:
	var ladder := _campaign.ladder(_profile(2), 4)
	assert_eq(ladder.size(), 4)
	for i in ladder.size():
		assert_eq(ladder[i]["fight"], 2 + i)
		assert_eq(ladder[i]["enemy"], _campaign.fight_at(0, 2 + i)["enemy"])
		assert_false(ladder[i]["boss"])


func test_la_escalera_acaba_en_el_jefe() -> void:
	var last := _campaign.fights_in(0)
	var ladder := _campaign.ladder(_profile(last - 2), 4)
	assert_eq(ladder.size(), 3, "dos combates y el jefe")
	assert_true(ladder[2]["boss"])
	assert_true(_library.is_boss(ladder[2]["enemy"]))
	assert_false(ladder[1]["boss"])
	# Delante del jefe, solo queda el.
	ladder = _campaign.ladder(_profile(last), 4)
	assert_eq(ladder.size(), 1)
	assert_true(ladder[0]["boss"])


func test_sin_campana_por_delante_no_hay_escalera() -> void:
	assert_eq(_campaign.ladder(_profile(0, _campaign.world_bosses), 4).size(), 0, "completa")
	# La escalera no toca los datos de la campana.
	var before: Dictionary = _campaign.fight_at(0, 0).duplicate()
	_campaign.ladder(_profile(0), 4)
	assert_eq(_campaign.fight_at(0, 0), before)


# --- Lo que ensena el hangar (MissionBrief) ------------------------------------------


func test_la_campana_ensena_la_fila_y_el_avance() -> void:
	var state := _brief.campaign_state(_profile(3))
	assert_eq(state["channel"], "campaign")
	assert_eq(state["fights"], 10)
	assert_eq(state["fight"], 3)
	var rivals: Array = state["rivals"]
	assert_eq(rivals.size(), MissionBrief.ROW_SIZE)
	assert_eq(rivals[0]["id"], _campaign.fight_at(0, 3)["enemy"])
	assert_eq(rivals[0]["level"], int(_campaign.fight_at(0, 3)["level"]))
	assert_true(rivals[0]["build"] is MechBuild)
	assert_false(state["confirm"], "un combate normal sale con una pulsacion")
	assert_has(state["lines"], Txt.t("mission_fight", [4, 10]))


func test_el_jefe_pide_confirmar_y_avisa() -> void:
	var state := _brief.campaign_state(_profile(_campaign.fights_in(0)))
	var rivals: Array = state["rivals"]
	assert_eq(rivals.size(), 1)
	assert_true(rivals[0]["boss"])
	assert_true(state["confirm"], "perder contra el jefe acaba la partida")
	assert_eq(state["warning"], Txt.t("mission_boss_warning"))
	assert_has(state["lines"], Txt.t("mission_boss"))


func test_con_la_campana_completa_no_hay_fila() -> void:
	var state := _brief.campaign_state(_profile(0, _campaign.world_bosses))
	assert_eq((state["rivals"] as Array).size(), 0)
	assert_gt(state["fight"], state["fights"], "todas las luces encendidas, jefe incluido")


func test_el_rival_de_la_arena_que_se_ve_es_el_que_sale() -> void:
	var profile := _profile(2)
	var power := ItemScaling.power(_rules, ItemDef.Tier.COMMON, 2)
	for seed_value: int in [1, 77, 4242]:
		var state := _brief.arena_state(profile, seed_value, power)
		var fight := _campaign.arena_fight(0, _library, seed_value, _rules, power)
		var rivals: Array = state["rivals"]
		assert_eq(rivals.size(), 1)
		assert_eq(rivals[0]["id"], fight["enemy"])
		assert_eq(rivals[0]["level"], fight["level"])
		assert_eq(rivals[0]["tier"], fight["tier"])


func test_el_combate_libre_da_la_vuelta_al_elegir() -> void:
	var count := _brief.free_count("enemy")
	var pick := _brief.free_pick({"enemy": -1, "tier": 6, "difficulty": 4})
	assert_eq(pick["enemy"], count - 1, "antes del primero, el ultimo")
	assert_eq(pick["tier"], 0, "despues de la ultima clase, la primera")
	assert_eq(pick["difficulty"], 1)
	var state := _brief.free_state({"enemy": 0, "tier": 1, "difficulty": 2})
	var rivals: Array = state["rivals"]
	assert_eq(rivals[0]["id"], _library.all_ids()[0])
	assert_eq(rivals[0]["level"], _rules.tier_max_level[1], "al maximo de su clase")
	assert_eq((state["pickers"] as Array).size(), 3)
	assert_eq(state["pickers"][2]["value"], Txt.t("difficulty_hard"))


# --- El hangar en modo mision ------------------------------------------------------


func test_el_modo_mision_proyecta_la_fila_delante_del_robot() -> void:
	var stage := _stage()
	assert_false(stage.is_mission_on())
	var state := _brief.campaign_state(_profile(0))
	stage.show_mission(state, "none")
	assert_true(stage.is_mission_on())
	assert_almost_eq(stage.mission, 1.0, 0.001)
	var ids := stage._row.shown_ids()
	assert_eq(ids.size(), MissionBrief.ROW_SIZE)
	assert_eq(ids[0], _campaign.fight_at(0, 0)["enemy"])
	# El primero queda a la derecha de tu robot, sobre el mismo suelo.
	var front := stage._row.front_rect()
	var robot := stage._world.position.x + stage._bounds.end.x * stage._world.scale.x
	assert_gt(front.position.x, robot - 80.0)
	assert_almost_eq(front.end.y, stage._floor_y, 30.0)
	# Y cabe bajo el monitor.
	assert_gt(front.position.y, stage._board.position.y + stage._board.size.y - 1.0)
	# Volver al taller apaga la fila y sube la luz.
	stage.hide_mission()
	assert_false(stage.is_mission_on())
	await wait_seconds(0.5)
	assert_almost_eq(stage.mission, 0.0, 0.001)
	assert_false(stage._row.is_showing())


func test_pulsar_al_primero_es_salir_a_combatir() -> void:
	var stage := _stage()
	stage.show_mission(_brief.campaign_state(_profile(0)), "none")
	watch_signals(stage)
	var front := stage._row.front_rect().get_center()
	stage._gui_input(_click(front))
	assert_signal_emit_count(stage, "rival_pressed", 1)
	assert_true(stage.confirm_rival(), "un combate normal sale a la primera")
	# Fuera del modo mision ese sitio no es un rival.
	stage.hide_mission()
	stage._gui_input(_click(front))
	assert_signal_emit_count(stage, "rival_pressed", 1)


func test_el_jefe_se_pulsa_dos_veces() -> void:
	var stage := _stage()
	stage.show_mission(_brief.campaign_state(_profile(_campaign.fights_in(0))), "none")
	assert_false(stage.confirm_rival(), "la primera pulsacion solo lo deja armado")
	assert_true(stage._row.armed)
	assert_true(stage.confirm_rival(), "la segunda sale a combatir")


func test_si_el_robot_no_puede_pelear_el_rival_lo_dice() -> void:
	var stage := _stage()
	var state := _brief.campaign_state(_profile(0))
	state["can_fight"] = false
	state["problems"] = "No puede pelear: falta el torso"
	stage.show_mission(state, "none")
	assert_eq(stage._row.blocked, "No puede pelear: falta el torso")
	assert_false(stage._row.can_press())
	state["can_fight"] = true
	stage.show_mission(state, "none")
	assert_true(stage._row.can_press())


func test_al_ganar_el_vencido_se_apaga_y_la_fila_avanza() -> void:
	var stage := _stage()
	var before := _brief.campaign_state(_profile(0))
	var after := _brief.campaign_state(_profile(1))
	stage.show_mission(after, "advance", before["rivals"][0])
	var row := stage._row
	# Al principio el vencido sigue delante y los demas, un sitio mas atras.
	assert_eq(row._leaving.size(), 1)
	assert_almost_eq(row._rivals[0].depth, 1.0, 0.001)
	await wait_seconds(
		RivalRow.BEATEN_HOLD + RivalRow.BEATEN_SECONDS + RivalRow.ADVANCE_SECONDS + 0.3
	)
	assert_eq(row._leaving.size(), 0, "el vencido ya se apago")
	for i in row._rivals.size():
		assert_almost_eq(row._rivals[i].depth, float(i), 0.001)
		assert_almost_eq(row._rivals[i].alpha, 1.0, 0.001)
	assert_eq(row.shown_ids()[0], _campaign.fight_at(0, 1)["enemy"])


func test_la_misma_fila_no_se_vuelve_a_encender() -> void:
	var stage := _stage()
	var state := _brief.campaign_state(_profile(0))
	stage.show_mission(state, "none")
	var first: MechView = stage._row._rivals[0].view
	stage.show_mission(_brief.campaign_state(_profile(0)))
	assert_eq(stage._row._rivals[0].view, first, "es la misma proyeccion")
	assert_almost_eq(stage._row._rivals[0].alpha, 1.0, 0.001)
	# Otro canal si la cambia.
	stage.show_mission(_brief.free_state({"enemy": 0, "tier": 0, "difficulty": 0}), "none")
	assert_eq(stage._row.shown_ids().size(), 1)


# --- El monitor ------------------------------------------------------------------


func test_el_monitor_apagado_abre_el_modo_mision() -> void:
	var stage := _stage()
	var board := stage._board
	stage.set_board(_brief.campaign_state(_profile(0)))
	watch_signals(stage)
	assert_eq(board.zone_at(board.size / 2.0), "board")
	board._gui_input(_click(board.size / 2.0))
	assert_signal_emit_count(stage, "missions_pressed", 1)


func test_el_monitor_abierto_cambia_de_canal() -> void:
	var stage := _stage()
	var board := stage._board
	stage.show_mission(_brief.campaign_state(_profile(0)), "none")
	watch_signals(stage)
	for channel in MissionBrief.CHANNELS:
		var at := board.zone_rect("tab:" + channel).get_center()
		assert_eq(board.zone_at(at), "tab:" + channel)
		board._gui_input(_click(at))
		assert_signal_emitted_with_parameters(stage, "channel_picked", [channel])
	assert_signal_emit_count(stage, "missions_pressed", 0, "abierto ya no se abre")


func test_las_flechas_del_combate_libre_avisan() -> void:
	var stage := _stage()
	var board := stage._board
	stage.show_mission(_brief.free_state({}), "none")
	watch_signals(stage)
	board._gui_input(_click(board.zone_rect("pick:tier:1").get_center()))
	assert_signal_emitted_with_parameters(stage, "pick_changed", ["tier", 1])
	board._gui_input(_click(board.zone_rect("pick:enemy:-1").get_center()))
	assert_signal_emitted_with_parameters(stage, "pick_changed", ["enemy", -1])
	# En la campana no hay flechas.
	stage.show_mission(_brief.campaign_state(_profile(0)), "none")
	assert_eq(board.zone_rect("pick:tier:1"), Rect2())
