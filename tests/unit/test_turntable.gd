extends GutTest
## La plataforma giratoria del hangar (scenes/hangar/hangar_stage.gd y
## turntable_mech.gd): arrastrarla gira el robot 360 grados; girado no se
## tocan sus piezas; casi de perfil vuelve solo a el; doble clic lo devuelve.
## El robot gira con volumen: de frente y de espalda se ve con los dibujos de
## frente de sus piezas, y las armas se abren a los lados.

var _catalog: Catalog
var _rules: RulesConfig
var _library: BuildLibrary


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	_rules = RulesConfig.new()
	_library = BuildLibrary.load_file("res://data/builds.json")


func _stage() -> HangarStage:
	var stage := HangarStage.new()
	stage.size = Vector2(1600, 900)
	add_child_autofree(stage)
	var build := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 6)
	stage.show_build(build, [] as Array[String])
	return stage


## Un punto de la plataforma, por debajo de los pies del robot.
func _platform(stage: HangarStage) -> Vector2:
	var legs := stage._world_rect("legs")
	var x := stage._world.position.x + legs.get_center().x * stage._world.scale.x
	return Vector2(x, stage._floor_y + 10.0)


func _button(at: Vector2, index: int, pressed: bool, double := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = index as MouseButton
	event.pressed = pressed
	event.double_click = double
	return event


func _drag(stage: HangarStage, pixels: float) -> void:
	var at := _platform(stage)
	stage._gui_input(_button(at, MOUSE_BUTTON_LEFT, true))
	var motion := InputEventMouseMotion.new()
	motion.position = at + Vector2(pixels, 0.0)
	motion.relative = Vector2(pixels, 0.0)
	stage._gui_input(motion)
	stage._gui_input(_button(motion.position, MOUSE_BUTTON_LEFT, false))


func test_de_perfil_se_ve_el_robot_de_siempre_y_el_giro_no_gasta() -> void:
	var stage := _stage()
	assert_false(stage.is_turned())
	assert_true(stage._mech.visible, "de perfil se dibuja el MechView del combate")
	assert_false(stage._turntable.visible)
	for viewport: SubViewport in stage._turntable._views.values():
		assert_eq(viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)


func test_arrastrar_la_plataforma_gira_el_robot() -> void:
	var stage := _stage()
	# Un cuarto de vuelta.
	_drag(stage, PI / 2.0 / HangarStage.TURN_PER_PIXEL)
	assert_almost_eq(stage.turn, PI / 2.0, 0.01)
	assert_true(stage.is_turned())
	assert_false(stage._mech.visible)
	assert_true(stage._turntable.visible, "girado se ven sus capas")
	assert_almost_eq(stage._turntable.angle, stage.turn, 0.001)
	# Y sigue hasta dar la vuelta entera, en los dos sentidos.
	_drag(stage, PI / HangarStage.TURN_PER_PIXEL)
	assert_almost_eq(stage.turn, PI * 1.5, 0.01)
	_drag(stage, -PI / HangarStage.TURN_PER_PIXEL)
	assert_almost_eq(stage.turn, PI / 2.0, 0.01)


func test_el_robot_se_agarra_por_cualquier_parte_para_girarlo() -> void:
	# Sus piezas ya no se eligen tocandolo (OBS-030): todo el robot gira.
	var stage := _stage()
	var torso := stage._world_rect("torso").get_center()
	var at := stage._world.position + torso * stage._world.scale.x
	assert_true(stage._grabs_platform(at), "de perfil, tambien por el torso")
	stage.turn = PI / 3.0
	assert_true(stage._grabs_platform(at), "y girado")


func test_casi_de_perfil_vuelve_solo_al_perfil() -> void:
	var stage := _stage()
	_drag(stage, deg_to_rad(5.0) / HangarStage.TURN_PER_PIXEL)
	await wait_seconds(0.4)
	assert_false(stage.is_turned(), "a 5 grados del perfil vuelve solo")
	assert_true(stage._mech.visible)
	# Mas lejos se queda donde lo dejas.
	_drag(stage, deg_to_rad(40.0) / HangarStage.TURN_PER_PIXEL)
	await wait_seconds(0.4)
	assert_almost_eq(stage.turn, deg_to_rad(40.0), 0.01)


func test_casi_de_frente_o_de_espalda_se_coloca_en_esa_vista() -> void:
	var stage := _stage()
	_drag(stage, deg_to_rad(85.0) / HangarStage.TURN_PER_PIXEL)
	await wait_seconds(0.4)
	assert_almost_eq(stage.turn, PI / 2.0, 0.001, "a 5 grados de la espalda se coloca de espaldas")
	assert_true(stage.is_turned())
	_drag(stage, deg_to_rad(186.0) / HangarStage.TURN_PER_PIXEL)
	await wait_seconds(0.4)
	assert_almost_eq(stage.turn, PI * 1.5, 0.001, "y a 6 del frente, de frente")


func test_doble_clic_en_la_plataforma_lo_devuelve_al_perfil() -> void:
	var stage := _stage()
	stage.turn = PI
	stage._gui_input(_button(_platform(stage), MOUSE_BUTTON_LEFT, true, true))
	await wait_seconds(0.5)
	assert_false(stage.is_turned())


func test_la_rueda_del_raton_gira_a_saltos() -> void:
	var stage := _stage()
	stage._gui_input(_button(_platform(stage), MOUSE_BUTTON_WHEEL_UP, true))
	await wait_seconds(0.35)
	assert_almost_eq(stage.turn, HangarStage.TURN_PER_NOTCH, 0.01)


func test_el_ancho_del_tronco_y_el_de_las_piernas_se_adaptan_entre_si() -> void:
	var stage := _stage()
	var table := stage._turntable
	var width := table.body_width()
	assert_gt(width, 0.0)
	# Las piernas van a ras del tronco por fuera, una a cada lado.
	for layer_name: String in ["far_leg", "near_leg"]:
		var leg := table._depths[layer_name]
		assert_almost_eq(absf(leg.x) + leg.y * 0.5, width * 0.5, 0.01, layer_name)
	# Con una base mas ancha (orugas) el tronco se ensancha con ella.
	var build := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 6)
	for legs in _catalog.by_type(ItemDef.Type.LEGS):
		if legs.id == "piernas_orugas":
			build.legs = ItemScaling.resolve(legs, _rules, ItemDef.Tier.COMMON, 6)
	assert_eq(build.legs.id, "piernas_orugas")
	stage.show_build(build, [] as Array[String])
	assert_gt(table.body_width(), width, "sobre orugas el robot es mas ancho")
	# Las armas van a los lados, a la misma distancia del eje.
	var near := table._depths["near"]
	var far := table._depths["far"]
	assert_almost_eq(near.x, table.body_width() * TurntableMech.ARM_OUT, 0.01)
	assert_almost_eq(far.x, -near.x, 0.01)


func test_el_cuerpo_gira_con_su_dibujo_de_frente() -> void:
	var stage := _stage()
	var table := stage._turntable
	# Andando: el torso y cada pierna tienen su vista de frente.
	for layer_name: String in ["body", "far_leg", "near_leg"]:
		assert_true(table.has_front(layer_name), layer_name)
	# Las armas no: giran como planchas.
	assert_false(table.has_front("near"))
	# El tronco y las piernas se ajustan al mismo ancho.
	var canvas := table._fronts["body"].get_size()
	assert_eq(canvas, table._fronts["near_leg"].get_size())
	assert_almost_eq(canvas.x / TurntableMech.FRONT_SCALE, table.body_width(), 9.0)
	# Sobre una base de una pieza, el cuerpo la lleva y no hay capas de piernas.
	var build := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 6)
	for legs_item in _catalog.by_type(ItemDef.Type.LEGS):
		if legs_item.id == "piernas_orugas":
			build.legs = ItemScaling.resolve(legs_item, _rules, ItemDef.Tier.COMMON, 6)
	stage.show_build(build, [] as Array[String])
	assert_true(table.has_front("body"))
	assert_false(table.has_front("near_leg"))
	assert_eq(table._regions["near_leg"].size, Vector2.ZERO)


func test_las_armas_se_abren_hacia_fuera_de_frente() -> void:
	var stage := _stage()
	var table := stage._turntable
	stage.turn = PI * 1.5
	# De frente el cuerpo se ve de cara; las armas, abiertas a cada lado.
	var body: Vector2 = table._materials["body"].get_shader_parameter("turn")
	assert_almost_eq(body.x, 0.0, 0.001)
	var near: Vector2 = table._materials["near"].get_shader_parameter("turn")
	var far: Vector2 = table._materials["far"].get_shader_parameter("turn")
	assert_almost_eq(absf(near.x), sin(TurntableMech.TOE_OUT), 0.001)
	assert_almost_eq(near.x, -far.x, 0.001, "una hacia cada lado")
	# De perfil no se abren.
	stage.turn = 0.3
	near = table._materials["near"].get_shader_parameter("turn")
	assert_almost_eq(near.x, cos(0.3 - TurntableMech.TOE_OUT * sin(0.3) * sin(0.3)), 0.001)


func test_una_pieza_que_falta_gira_como_fantasma() -> void:
	var stage := _stage()
	var table := stage._turntable
	var build := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 6)
	stage.show_build(build, ["legs"] as Array[String])
	stage.turn = 1.0
	# Las piernas que faltan se ven transparentes; el cuerpo, entero.
	var legs: Vector4 = table._materials["near_leg"].get_shader_parameter("tint")
	var body: Vector4 = table._materials["body"].get_shader_parameter("tint")
	assert_almost_eq(legs.w, TurntableMech.GHOST.a, 0.001)
	assert_almost_eq(body.w, 1.0, 0.001)


func test_las_capas_del_giro_reparten_el_robot() -> void:
	var stage := _stage()
	var table := stage._turntable
	var names: Array[String] = []
	for layer: Dictionary in TurntableMech.LAYERS:
		names.append(layer["name"])
		assert_eq(table._mechs[layer["name"]].only_layer, layer["name"])
	var expected: Array[String] = [
		"far", "far_top", "far_leg", "body", "chest", "near_leg", "near_top", "near", "float"
	]
	assert_eq(names, expected)
	# El cuerpo y las dos piernas siempre ocupan algo; cada zona cabe en el lienzo.
	for layer_name: String in ["far_leg", "body", "near_leg"]:
		var region := table._regions[layer_name]
		assert_gt(region.size.x, 0.0, layer_name)
		assert_true(table._canvas.encloses(region), "%s dentro del lienzo" % layer_name)
