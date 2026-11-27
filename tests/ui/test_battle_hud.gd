extends GutTest
## La pantalla del combate sin barras ni botones (decisiones del usuario,
## 2026-11-20, OBS-015 a OBS-018 y OBS-025): toda la pantalla es la arena,
## las armas se despliegan sobre el robot del jugador, la vida, el calor y la
## energia son unas rayitas sobre cada robot y el turno se anuncia y se va.

const D := BattleAI.Difficulty

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _chosen: Array[BattleAction] = []
var _teleports := 0


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")


func before_each() -> void:
	_chosen.clear()
	_teleports = 0


func _build(id: String) -> MechBuild:
	return _library.make(id, _catalog, _rules, ItemDef.Tier.EPIC, 0)


## Una pantalla con el combate empezado y parado en el turno del jugador.
func _screen(player_id: String = "energia_tempestad") -> BattleScreen:
	var screen := BattleScreen.new()
	screen.speed = 400.0
	add_child_autofree(screen)
	# La semilla 4 deja empezar al jugador (seed % 2 == 0).
	screen.start(_rules, _build(player_id), _build("fisico_vanguardia"), 4, D.RANDOM)
	await wait_seconds(0.3)
	return screen


func _click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	return event


func _move(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


func test_toda_la_pantalla_es_la_arena_y_no_quedan_barras_ni_registro() -> void:
	var screen := await _screen()
	assert_eq(screen._arena.size, screen.size, "la arena ocupa la pantalla entera")
	assert_eq(screen.find_children("*", "RichTextLabel", true, false).size(), 0, "sin registro")
	assert_eq(screen.find_children("*", "ProgressBar", true, false).size(), 0, "sin barras")
	var visible_buttons := 0
	for button: Button in screen.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			visible_buttons += 1
	assert_eq(visible_buttons, 0, "sin botones mientras se pelea")


func test_el_abanico_lleva_las_armas_y_despues_lo_demas() -> void:
	var screen := await _screen()
	var hud := screen._hud
	var mech := screen.engine.mechs[screen.player]
	var actions := hud.actions()
	var keys := mech.weapon_keys()
	for i in keys.size():
		assert_eq(actions[i].type, BattleAction.Type.WEAPON)
		assert_eq(actions[i].slot, keys[i])
	assert_eq(actions[-1].type, BattleAction.Type.COOL, "enfriar va el ultimo")
	assert_gt(hud.index_of(BattleAction.stomp()), keys.size() - 1)
	assert_eq(hud.index_of(BattleAction.repair()), -1, "sin esa habilidad no sale")


func test_se_abre_al_pasar_por_el_robot_y_se_cierra_al_salir() -> void:
	var screen := await _screen()
	var hud := screen._hud
	assert_false(hud.is_open())
	var body := hud.body_rect()
	assert_gt(body.size.y, 0.0)
	assert_true(hud._has_point(body.get_center()), "el robot es del abanico")
	assert_false(hud._has_point(Vector2(body.get_center().x, screen.size.y - 20.0)), "el suelo no")
	hud._gui_input(_move(body.get_center()))
	await wait_seconds(0.4)
	assert_true(hud.is_open())
	# Abierto, sus iconos tambien son suyos.
	assert_true(hud._has_point(hud.icon_rect(0).get_center()))
	hud._on_mouse_exited()
	await wait_seconds(0.4)
	assert_false(hud.is_open())


func test_tocar_el_robot_lo_deja_abierto() -> void:
	var screen := await _screen()
	var hud := screen._hud
	hud._gui_input(_click(hud.body_rect().get_center()))
	hud._on_mouse_exited()
	await wait_seconds(0.4)
	assert_true(hud.is_open(), "en tactil no hay raton que pase por encima")
	hud._gui_input(_click(hud.body_rect().get_center()))
	await wait_seconds(0.4)
	assert_false(hud.is_open())


func test_encendida_la_que_se_puede_usar_y_en_gris_la_que_no() -> void:
	var screen := await _screen()
	var hud := screen._hud
	var engine := screen.engine
	assert_eq(engine.turn, screen.player)
	var actions := hud.actions()
	var lit := 0
	for i in actions.size():
		var legal := engine.why_illegal(actions[i]) == ""
		if actions[i].type == BattleAction.Type.TELEPORT:
			continue
		assert_eq(hud.is_lit(i), legal, "accion %d" % i)
		if legal:
			lit += 1
	assert_gt(lit, 0)


func test_pulsar_una_encendida_la_elige_y_una_en_gris_no() -> void:
	var screen := await _screen()
	var hud := screen._hud
	hud.action_chosen.connect(func(action: BattleAction) -> void: _chosen.append(action))
	hud._gui_input(_move(hud.body_rect().get_center()))
	await wait_seconds(0.4)
	var grey := -1
	var bright := -1
	for i in hud.actions().size():
		if hud.is_lit(i) and bright < 0:
			bright = i
		elif not hud.is_lit(i) and grey < 0:
			grey = i
	assert_gte(bright, 0)
	if grey >= 0:
		hud._gui_input(_click(hud.icon_rect(grey).get_center()))
		assert_eq(_chosen.size(), 0, "una accion en gris no hace nada")
	hud._gui_input(_click(hud.icon_rect(bright).get_center()))
	assert_eq(_chosen.size(), 1)
	assert_eq(_chosen[0].type, hud.actions()[bright].type)


func test_la_tarjeta_dice_el_dano_el_critico_y_lo_que_cuesta() -> void:
	var screen := await _screen()
	var mech := screen.engine.mechs[screen.player]
	var key: String = mech.weapon_keys()[0]
	var card := screen._cards.card_for(BattleAction.weapon(key))
	assert_eq(card["title"], mech.slots[key].def.display_name)
	var text := ""
	for line: Array in card["lines"]:
		text += str(line[0]) + "\n"
	assert_string_contains(text, "Daño")
	assert_string_contains(text, "alcance")
	var cool := screen._cards.card_for(BattleAction.cool())
	assert_eq(cool["title"], Txt.t("cool"))
	assert_eq((cool["lines"] as Array).size(), 1)


func test_las_rayitas_siguen_la_vida_el_calor_y_la_energia() -> void:
	var screen := await _screen()
	var hud := screen._hud
	assert_eq(hud._vitals.size(), 2)
	for state in hud._vitals:
		assert_almost_eq(float(state["health"]), 1.0, 0.001, "empiezan enteros")
		assert_almost_eq(float(state["heat"]), 0.0, 0.001)
		assert_false(state["over"])
	assert_eq(hud._turn, screen.player)
	assert_eq(hud._actions, screen.engine.actions_left)


func test_el_turno_se_anuncia_y_se_va() -> void:
	var screen := await _screen()
	var hud := screen._hud
	assert_false(hud._banner.is_empty(), "al empezar el turno sale su rotulo")
	assert_eq(str(hud._banner["text"]), Txt.t("your_turn").to_upper())
	await wait_seconds(BattleHud.BANNER_SECONDS + 0.2)
	assert_true(hud._banner.is_empty(), "y no se queda en pantalla")


func test_un_combate_entero_por_los_controles_usa_el_abanico() -> void:
	var screen := BattleScreen.new()
	screen.speed = 400.0
	add_child_autofree(screen)
	screen.ui_driver = BattleAI.new(D.NORMAL, 5)
	var opened := [0]
	screen.preview_shown.connect(
		func() -> void:
			if screen._hud.is_open():
				opened[0] += 1
	)
	screen.start(_rules, _build("energia_tempestad"), _build("fisico_vanguardia"), 5, D.RANDOM)
	await wait_for_signal(screen.finished, 60.0)
	assert_gt(opened[0], 3, "cada arma se elige en el abanico abierto")


# --- El arma de pecho se despliega cada vez (OBS-025) --------------------------------


func test_el_arma_de_pecho_se_despliega_y_se_guarda_cada_vez() -> void:
	var build := _build("fisico_vanguardia")
	build.chest = ItemScaling.resolve(
		_catalog.get_item("canon_pesado_canon_cin"), _rules, ItemDef.Tier.EPIC, 0
	)
	var view := MechView.new()
	add_child_autofree(view)
	view.setup(build, 1)
	if not view.has_cannon():
		pending("este torso no dibuja el arma de pecho")
		return
	for round_number in 2:
		var out := view.deploy(0.05)
		assert_not_null(out, "vuelta %d: sale" % round_number)
		await out.finished
		assert_null(view.deploy(0.05), "ya esta fuera")
		var back := view.stow(0.05)
		assert_not_null(back, "vuelta %d: se guarda" % round_number)
		await back.finished
		assert_null(view.stow(0.05), "ya esta guardada")
