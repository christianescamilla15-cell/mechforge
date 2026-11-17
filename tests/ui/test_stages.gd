extends GutTest
## Escenarios de la arena (GDD 12.1): los datos cargan y la vista los acepta.


func test_los_escenarios_del_juego_cargan_sin_errores() -> void:
	var library := StageLibrary.load_file("res://data/stages.json")
	assert_eq(library.errors, [] as Array[String])
	assert_eq(library.ids().size(), 4)
	assert_true("entrenamiento" in library.ids())


func test_los_colores_llegan_como_colores() -> void:
	var library := StageLibrary.load_file("res://data/stages.json")
	for stage in library.stages:
		assert_true(stage["sky_top"] is Color, stage["id"])
		assert_true(stage["far"]["color"] is Color, stage["id"])
		assert_true(stage["haze"] is Color, stage["id"])


func test_cada_escenario_define_todo_lo_que_la_vista_necesita() -> void:
	var library := StageLibrary.load_file("res://data/stages.json")
	for stage in library.stages:
		for key: String in ArenaView.DEFAULT_STAGE:
			assert_true(stage.has(key), "%s: falta %s" % [stage["id"], key])
		for layer: String in ["far", "near"]:
			assert_true(
				stage[layer]["style"] in ["towers", "dunes", "peaks", "trusses"], stage["id"]
			)


func test_la_misma_semilla_da_el_mismo_escenario() -> void:
	var library := StageLibrary.load_file("res://data/stages.json")
	assert_eq(library.pick(7)["id"], library.pick(7)["id"])
	assert_eq(library.get_stage("no_existe"), {})


func test_la_arena_dibuja_cualquier_escenario() -> void:
	var library := StageLibrary.load_file("res://data/stages.json")
	var arena: ArenaView = add_child_autofree(ArenaView.new())
	arena.size = Vector2(1280, 340)
	for stage in library.stages:
		arena.set_stage(stage)
		arena.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
	assert_true(is_instance_valid(arena))
