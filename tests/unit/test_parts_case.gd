extends GutTest
## Cambiar pieza sin la computadora del taller (OBS-048, del usuario: "el
## taller no existe en una pantalla, no entramos a otra pantalla"): el estuche
## de piezas se abre junto a la pieza del robot desarmado (PartsCase), unido a
## ella, sin taparla. Y el fallo que salio al probarlo: en el hangar desarmado
## los sitios de tus otros robots (que ya solo estan en la zona de combate)
## seguian pulsandose encima del brazo izquierdo y de la bandeja.

## Lo que asoma la tecla de cerrar por fuera del estuche.
const CLOSE_ROOM := 17.0

var _brief: WorkshopBrief
var _library: BuildLibrary
var _catalog: Catalog


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_brief = WorkshopBrief.new()
	_brief.rules = RulesConfig.new()
	_brief.catalog = _catalog
	_brief.library = _library
	_brief.campaign = Campaign.load_file("res://data/campaign.json", _library)
	_brief.workshop = Workshop.load_file("res://data/workshop.json")
	_brief.garage = Garage.load_file("res://data/part_shop.json")
	_brief.shop = ArenaShop.load_file("res://data/arena_shop.json")
	_brief.skills = SkillTree.load_file("res://data/skills.json")
	_brief.progression = Progression.load_file("res://data/progression.json")
	_brief.styles = StyleLibrary.load_file("res://data/styles.json", _catalog)


func _profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	Garage.ensure_assist(profile, _catalog)
	profile.gold = 5000
	return profile


## El hangar desarmado, con un robot tuyo en la primera bahia.
func _stage() -> HangarStage:
	var stage := HangarStage.new()
	stage.size = Vector2(1600, 900)
	add_child_autofree(stage)
	var build := _library.make("fisico_vanguardia", _catalog, _brief.rules, ItemDef.Tier.COMMON, 6)
	stage.show_build(build, [] as Array[String])
	stage.teardown.show_state(_brief.teardown(_profile(), build))
	stage.set_bays([{"index": 1, "build": build, "name": "Otro"}] as Array[Dictionary])
	return stage


func _click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func test_en_el_hangar_desarmado_las_piezas_no_son_bahias() -> void:
	var stage := _stage()
	var picked: Array[String] = []
	var bays: Array[int] = []
	stage.teardown_picked.connect(func(key: String) -> void: picked.append(key))
	stage.bay_pressed.connect(func(index: int) -> void: bays.append(index))
	var keys: Array[String] = ["slot:side1", "slot:assist", "slot:hook", "slot:charge"]
	for i in MechBuild.MODULE_SLOTS:
		keys.append("slot:module%d" % i)
	for key in keys:
		var rect := stage.teardown.rect_of(key)
		assert_ne(rect.size, Vector2.ZERO, key + " esta en el hangar")
		stage._gui_input(_click(rect.get_center()))
	assert_eq(picked, keys, "cada pieza se elige")
	assert_eq(bays, [] as Array[int], "ningun clic cambia de robot")
	# En la zona de combate tus otros robots si se pulsan.
	stage.show_mission({"rivals": [], "can_fight": true}, "none")
	stage._gui_input(_click(stage._bay_rects[0].get_center()))
	assert_eq(bays, [1] as Array[int], "en la zona, tu otro robot se elige")


func test_el_estuche_va_junto_a_la_pieza_sin_taparla() -> void:
	var stage := _stage()
	var room := stage.size
	for slot: String in ["side0", "side1", "top0", "torso", "legs", "assist", "module0", "chest"]:
		var piece := stage.teardown.rect_of("slot:" + slot)
		if piece.size == Vector2.ZERO:
			continue
		var box := PartsCase.target_for(piece, room)
		assert_true(Rect2(Vector2.ZERO, room).encloses(box), slot + ": cabe en el hangar")
		assert_false(box.intersects(piece), slot + ": no tapa su pieza")
		var gap := maxf(box.position.x - piece.end.x, piece.position.x - box.end.x)
		assert_true(gap <= PartsCase.GAP + 1.0, slot + ": esta a su lado")
		assert_gt(box.size.x, 400.0, slot + ": con sitio para el catalogo")


func test_cambiar_pieza_abre_el_estuche_unido_a_ella() -> void:
	var stage := _stage()
	var profile := _profile()
	stage.show_case(_brief.rack(profile, "side0"), "slot:side0", true)
	var box := stage.parts_case
	assert_true(box.is_open())
	assert_true(box.visible)
	assert_eq(box.key, "slot:side0")
	assert_true(box.rack.visible, "con el catalogo dentro")
	assert_false(box.rack.framed, "sin el marco de pantalla")
	assert_eq(box.piece, stage.teardown.rect_of("slot:side0"))
	assert_false(stage.loadout.is_open(), "sin la computadora del taller")
	var parts: Array = box.rack.state.get("parts", [])
	assert_gt(parts.size(), 0, "las piezas que caben en el brazo")
	# Llevarlo a otra pieza.
	stage.show_case(_brief.rack(profile, "top0"), "slot:top0", true)
	assert_eq(box.key, "slot:top0")
	assert_false(
		Rect2(box.position, box.size).intersects(stage.teardown.rect_of("slot:top0")),
		"junto a su nueva pieza"
	)
	# La tecla de su esquina avisa de cerrar; cerrarlo lo recoge.
	var closed: Array[bool] = []
	box.close_pressed.connect(func() -> void: closed.append(true))
	box._gui_input(_click(box.close_center()))
	assert_eq(closed, [true] as Array[bool])
	box.close(true)
	assert_false(box.is_open())
	assert_false(box.visible)


func test_el_estuche_sigue_a_su_pieza_si_cambia_el_tamano() -> void:
	var stage := _stage()
	stage.show_case(_brief.rack(_profile(), "side0"), "slot:side0", true)
	stage.size = Vector2(1280, 720)
	stage._fit()
	var box := stage.parts_case
	assert_eq(box.piece, stage.teardown.rect_of("slot:side0"))
	assert_true(Rect2(Vector2.ZERO, stage.size).encloses(Rect2(box.position, box.size)))


## Con un modulo o un especial, el estuche no tapa la bandeja: se pasa de un
## modulo a otro pulsandolos.
func test_en_la_bandeja_el_estuche_deja_ver_todos_los_modulos() -> void:
	var stage := _stage()
	var profile := _profile()
	var tray := stage.teardown.tray_rect()
	for key: String in ["slot:module0", "slot:module4", "slot:hook"]:
		stage.show_case(_brief.rack(profile, key.trim_prefix("slot:")), key, true)
		var box := Rect2(stage.parts_case.position, stage.parts_case.size)
		assert_false(box.intersects(tray), key + ": la bandeja entera a la vista")
		assert_eq(stage.parts_case.piece, stage.teardown.rect_of(key), "unido a su casilla")
	assert_false(TeardownView.in_tray("slot:side0"))


## El estuche no tapa el engrane de los ajustes, arriba a la derecha.
func test_el_estuche_deja_ver_el_engrane_de_los_ajustes() -> void:
	var stage := _stage()
	var gear: Rect2 = stage._terminal_rects["ajustes"]
	for slot: String in ["torso", "top0", "side0", "assist"]:
		stage.show_case(_brief.rack(_profile(), slot), "slot:" + slot, true)
		var box := Rect2(stage.parts_case.position, stage.parts_case.size).grow(CLOSE_ROOM)
		assert_false(box.intersects(gear), slot + ": el engrane a la vista")
