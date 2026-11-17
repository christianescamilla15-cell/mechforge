extends GutTest
## Pantalla de combate: un combate completo se reproduce hasta el final, tanto
## con la IA jugando directamente como a traves de los controles del jugador.

const D := BattleAI.Difficulty

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")


func test_un_combate_con_la_ia_en_los_dos_lados_llega_al_resultado() -> void:
	var screen := _new_screen()
	screen.player_ai = BattleAI.new(D.NORMAL, 11)
	watch_signals(screen)
	screen.start(_rules, _build("fisico_vanguardia"), _build("calor_horno"), 3, D.NORMAL)
	await wait_for_signal(screen.finished, 60.0)
	assert_signal_emitted(screen, "finished")
	assert_true(screen.engine.is_over())
	assert_signal_emit_count(screen, "event_played", screen.engine.events.size())


func test_el_jugador_puede_ganar_usando_solo_los_controles() -> void:
	var screen := _new_screen()
	screen.ui_driver = BattleAI.new(D.NORMAL, 5)
	watch_signals(screen)
	screen.start(_rules, _build("energia_tempestad"), _build("fisico_vanguardia"), 5, D.RANDOM)
	await wait_for_signal(screen.finished, 60.0)
	assert_signal_emitted(screen, "finished")
	assert_signal_emitted(screen, "preview_shown")
	assert_eq(screen.engine.winner, screen.player, "la IA normal gana a la IA al azar")


func test_cada_evento_trae_la_foto_del_estado_que_usa_la_pantalla() -> void:
	# Sin M5 quedan dos acciones, asi que el pisoton es el ultimo evento.
	var engine := BattleEngine.new(
		Fx.rules(), _build("fisico_vanguardia"), _build("calor_horno"), 1, 0, 0
	)
	engine.apply(BattleAction.stomp())
	var entry: Dictionary = engine.events[-1]
	assert_eq(entry["event"], "stomp")
	assert_eq(entry["state"].size(), 2)
	for key: String in ["pos", "health", "heat", "energy", "heat_cap", "energy_cap", "res"]:
		assert_has(entry["state"][1], key)
	assert_eq(entry["state"][1]["health"], engine.mechs[1].health)
	assert_eq(entry["state"][1]["pos"], engine.mechs[1].position)


func test_en_la_campana_no_hay_revancha_y_se_ve_lo_que_se_cobra() -> void:
	var screen := BattleScreen.new()
	screen.speed = 400.0
	screen.allow_rematch = false
	add_child_autofree(screen)
	screen.player_ai = BattleAI.new(D.NORMAL, 11)
	screen.finished.connect(func(_won: bool) -> void: screen.set_result_note("+250 celdas"))
	screen.start(_rules, _build("fisico_vanguardia"), _build("calor_horno"), 3, D.NORMAL)
	await wait_for_signal(screen.finished, 60.0)
	assert_true(screen._result.visible)
	assert_true(screen._result_note.visible)
	assert_eq(screen._result_note.text, "+250 celdas")
	var shown := 0
	for button: Button in screen._result.find_children("*", "Button", true, false):
		if button.visible:
			shown += 1
			assert_eq(button.text, Txt.t("menu"))
	assert_eq(shown, 1, "solo queda el boton de volver")


func test_un_combate_nuevo_borra_la_nota_del_anterior() -> void:
	var screen := _new_screen()
	screen.player_ai = BattleAI.new(D.NORMAL, 11)
	screen.set_result_note("+250 celdas")
	screen.start(_rules, _build("fisico_vanguardia"), _build("calor_horno"), 3, D.NORMAL)
	assert_false(screen._result_note.visible)
	await wait_for_signal(screen.finished, 60.0)


func _new_screen() -> BattleScreen:
	var screen := BattleScreen.new()
	screen.speed = 400.0
	add_child_autofree(screen)
	return screen


func _build(id: String) -> MechBuild:
	return _library.make(id, _catalog, _rules, ItemDef.Tier.EPIC, 0)
