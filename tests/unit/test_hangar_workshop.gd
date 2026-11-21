extends GutTest
## El taller del hangar sin cajon ni listas (pedido del usuario el
## 2026-11-20: "casi como si no existiera un menu"): el tablero de piezas que
## cuelga junto al robot (PartsRack), las cunas del banco de equipo
## (SlotCell), las pantallas de mejoras y habilidades que se usan de cerca
## (WallConsole) y lo que todos ensenan (WorkshopBrief).

var _brief: WorkshopBrief
var _library: BuildLibrary
var _catalog: Catalog
var _chosen: Array[String] = []
var _bought: Array[String] = []
var _unmounted: Array[String] = []
var _picked: Array[String] = []
## Ajustes cambiados en la pantalla: [clave, valor].
var _changes: Array = []
var _pressed: Array[String] = []
var _counts := {}


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


func before_each() -> void:
	_chosen.clear()
	_bought.clear()
	_unmounted.clear()
	_picked.clear()
	_changes.clear()
	_pressed.clear()
	_counts = {"upgrade": 0, "target": 0, "remove": 0, "quit": 0}


func _profile(gold: int = 5000) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	Garage.ensure_assist(profile, _catalog)
	profile.gold = gold
	return profile


func _rack(state: Dictionary) -> PartsRack:
	var rack := PartsRack.new()
	add_child_autofree(rack)
	rack.home = Rect2(880, 250, 384, 455)
	rack.open(state, true)
	rack.chosen.connect(func(id: String) -> void: _chosen.append(id))
	rack.bought.connect(func(id: String) -> void: _bought.append(id))
	rack.unmounted.connect(func(slot: String) -> void: _unmounted.append(slot))
	rack.upgrade_pressed.connect(func() -> void: _counts["upgrade"] += 1)
	return rack


func _console(state: Dictionary) -> WallConsole:
	var console := WallConsole.new()
	add_child_autofree(console)
	console.open(state, Rect2(220, 60, 150, 140), Rect2(40, 60, 470, 450), true)
	console.upgrade_picked.connect(func(id: String) -> void: _picked.append(id))
	console.skill_picked.connect(func(id: String) -> void: _picked.append(id))
	console.remove_pressed.connect(func() -> void: _counts["remove"] += 1)
	console.setting_changed.connect(
		func(key: String, value: Variant) -> void: _changes.append([key, value])
	)
	console.quit_pressed.connect(func() -> void: _counts["quit"] += 1)
	return console


func _click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = true
	return event


func _first(parts: Array, owned: bool, buyable: bool = true) -> int:
	for index in parts.size():
		var part: Dictionary = parts[index]
		if bool(part["owned"]) != owned:
			continue
		if owned or (str(part["reason"]) == "") == buyable:
			return index
	return -1


# --- Lo que cuelga en el tablero (WorkshopBrief.rack) ----------------------------


func test_el_tablero_cuelga_tus_piezas_y_luego_las_de_la_tienda() -> void:
	var profile := _profile()
	var state := _brief.rack(profile, "side0")
	var parts: Array = state["parts"]
	assert_gt(parts.size(), 4, "las tuyas y las de la tienda")
	var seen_store := false
	for part: Dictionary in parts:
		var item: ItemDef = part["item"]
		assert_eq(item.type, ItemDef.Type.SIDE, "solo lo que cabe en el hueco")
		if bool(part["owned"]):
			assert_false(seen_store, "las tuyas van delante")
			assert_true(str(part["id"]) in profile.owned)
			assert_eq(int(part["price"]), -1)
		else:
			seen_store = true
			assert_false(str(part["id"]) in profile.owned, "lo que ya tienes no se vende")
			assert_gt(int(part["price"]), 0)
	assert_true(seen_store)
	assert_eq(state["title"], "Lateral 1")
	assert_eq(int(state["cells"]), 5000)


func test_la_tienda_delante_cuando_se_abre_desde_su_pantalla() -> void:
	var parts: Array = _brief.rack(_profile(), "side0", true)["parts"]
	assert_false(bool(parts[0]["owned"]), "primero lo que se vende")
	assert_true(bool(parts[-1]["owned"]), "al final las tuyas")


func test_el_tablero_marca_la_pieza_que_lleva_el_hueco() -> void:
	var profile := _profile()
	var mounted := Garage.get_slot(profile.build, "side1")
	var state := _brief.rack(profile, "side1")
	var marked: Array[String] = []
	for part: Dictionary in state["parts"]:
		if bool(part["mounted"]):
			marked.append(str(part["id"]))
	assert_eq(marked, [mounted] as Array[String])
	assert_eq((state["mounted"]["item"] as ItemDef).id, mounted)
	assert_true(bool(state["can_test"]), "un arma se puede probar en la diana")
	# Un hueco vacio no lleva ficha ni tecla.
	Garage.equip(profile, _catalog, "side1", "")
	state = _brief.rack(profile, "side1")
	assert_true((state["mounted"] as Dictionary).is_empty())
	assert_true((state["key"] as Dictionary).is_empty())
	assert_false(bool(state["can_test"]))


func test_sin_celdas_los_hologramas_dicen_que_faltan() -> void:
	var state := _brief.rack(_profile(0), "side0")
	for part: Dictionary in state["parts"]:
		if not bool(part["owned"]):
			assert_eq(str(part["reason"]), "faltan celdas")


func test_la_tecla_del_lector_sube_la_pieza_o_dice_por_que_no() -> void:
	var profile := _profile()
	var key: Dictionary = _brief.rack(profile, "side1")["key"]
	assert_eq(key["action"], "level")
	assert_true(bool(key["enabled"]))
	profile.gold = 0
	key = _brief.rack(profile, "side1")["key"]
	assert_false(bool(key["enabled"]))
	assert_eq(str(key["reason"]), "faltan celdas")


func test_un_hueco_cerrado_lo_dice_y_avisa_en_lo_que_se_vende() -> void:
	var profile := _profile()
	var locked := ""
	for slot in Garage.SLOTS:
		if not _brief.progression.is_unlocked(slot, _brief.level(profile)):
			locked = slot
			break
	assert_ne(locked, "", "al empezar hay huecos cerrados")
	var state := _brief.rack(profile, locked)
	assert_ne(str(state["locked"]), "")
	assert_true((state["mounted"] as Dictionary).is_empty(), "cerrado no se sube ni se prueba")
	for part: Dictionary in state["parts"]:
		if not bool(part["owned"]):
			assert_ne(str(part["note"]), "", "se puede comprar, pero avisa")


func test_la_lectura_del_robot_dice_lo_que_cambia_una_pieza() -> void:
	var profile := _profile()
	var reading := _brief.diagnostic(profile)
	assert_eq((reading["rows"] as Array).size(), WorkshopBrief.DIAGNOSTIC_KEYS.size())
	for row: Dictionary in reading["rows"]:
		assert_eq(int(row["delta"]), 0, "sin comparar no cambia nada")
	assert_eq(int(reading["weight_delta"]), 0)
	# Un modulo de blindaje en un hueco vacio: mas vida y mas peso.
	var free := ""
	for i in 8:
		if Garage.get_slot(profile.build, "module%d" % i) == "":
			free = "module%d" % i
			break
	if _brief.lock_reason(profile, free) != "":
		profile.xp = 10000000
	reading = _brief.diagnostic(profile, "mod_blindaje", free)
	var health := {}
	for row: Dictionary in reading["rows"]:
		if row["key"] == "health":
			health = row
	assert_gt(int(health["delta"]), 0)
	assert_true(bool(health["better"]))
	assert_gt(int(reading["weight_delta"]), 0)


# --- El tablero (PartsRack) ---------------------------------------------------------


func test_pulsar_una_pieza_tuya_la_elige() -> void:
	var state := _brief.rack(_profile(), "side0")
	var rack := _rack(state)
	var index := _first(state["parts"], true)
	rack._gui_input(_click(rack.part_rect(index).get_center()))
	assert_eq(_chosen, [str(state["parts"][index]["id"])] as Array[String])
	assert_eq(_bought.size(), 0)


func test_un_holograma_se_compra_con_dos_pulsaciones() -> void:
	var state := _brief.rack(_profile(), "side0")
	var rack := _rack(state)
	var index := _first(state["parts"], false)
	var id := str(state["parts"][index]["id"])
	var at := rack.part_rect(index).get_center()
	rack._gui_input(_click(at))
	assert_eq(_bought.size(), 0, "la primera solo lo deja armado")
	assert_eq(rack.armed_id(), id)
	rack._gui_input(_click(at))
	assert_eq(_bought, [id] as Array[String])
	assert_eq(rack.armed_id(), "")


func test_pulsar_otra_cosa_desarma_el_holograma() -> void:
	var state := _brief.rack(_profile(), "side0")
	var rack := _rack(state)
	var holo := _first(state["parts"], false)
	rack._gui_input(_click(rack.part_rect(holo).get_center()))
	rack._gui_input(_click(rack.part_rect(_first(state["parts"], true)).get_center()))
	assert_eq(rack.armed_id(), "")
	rack._gui_input(_click(rack.part_rect(holo).get_center()))
	assert_eq(_bought.size(), 0, "vuelve a pedir las dos pulsaciones")


func test_un_holograma_que_no_puedes_pagar_no_se_compra_ni_se_arrastra() -> void:
	var state := _brief.rack(_profile(0), "side0")
	var rack := _rack(state)
	var index := _first(state["parts"], false, false)
	var at := rack.part_rect(index).get_center()
	rack._gui_input(_click(at))
	rack._gui_input(_click(at))
	assert_eq(_bought.size(), 0)
	assert_eq(rack.armed_id(), "")
	assert_null(rack.drag_data_at(at))


func test_arrastrar_un_holograma_lleva_la_compra() -> void:
	var state := _brief.rack(_profile(), "side0")
	var rack := _rack(state)
	var holo: Dictionary = rack.drag_data_at(
		rack.part_rect(_first(state["parts"], false)).get_center()
	)
	assert_true(bool(holo.get("buy", false)))
	assert_eq(int(holo["type"]), ItemDef.Type.SIDE)
	var mine: Dictionary = rack.drag_data_at(
		rack.part_rect(_first(state["parts"], true)).get_center()
	)
	assert_false(mine.has("buy"), "una tuya no se compra")


func test_soltar_en_el_tablero_la_pieza_de_un_hueco_la_quita() -> void:
	var rack := _rack(_brief.rack(_profile(), "side0"))
	var data := {"id": "hoja_balas_ter", "type": ItemDef.Type.SIDE, "from_slot": "side2"}
	assert_true(rack._can_drop_data(Vector2(50, 50), data))
	rack._drop_data(Vector2(50, 50), data)
	assert_eq(_unmounted, ["side2"] as Array[String])
	# Lo que viene del propio tablero no se suelta en el.
	assert_false(rack._can_drop_data(Vector2(50, 50), {"id": "x", "type": 2}))


func test_la_tecla_del_lector_solo_avisa_si_se_puede() -> void:
	var profile := _profile()
	var rack := _rack(_brief.rack(profile, "side1"))
	assert_eq(rack.zone_at(rack._key_rect().get_center()), "key")
	rack._gui_input(_click(rack._key_rect().get_center()))
	assert_eq(_counts["upgrade"], 1)
	profile.gold = 0
	rack.state = _brief.rack(profile, "side1")
	rack._gui_input(_click(rack._key_rect().get_center()))
	assert_eq(_counts["upgrade"], 1, "sin celdas no avisa")


func test_la_rueda_pasa_las_filas_cuando_no_caben() -> void:
	var state := _brief.rack(_profile(), "side0")
	var parts: Array = state["parts"]
	while parts.size() <= PartsRack.COLUMNS * 8:
		parts.append_array(parts.duplicate())
	var rack := _rack(state)
	assert_ne(rack.part_rect(0), Rect2())
	assert_eq(rack.part_rect(parts.size() - 1), Rect2(), "la ultima fila no se ve")
	rack._gui_input(_click(Vector2(50, 100), MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(rack.part_rect(0), Rect2(), "la primera fila ya paso")
	rack._gui_input(_click(Vector2(50, 100), MOUSE_BUTTON_WHEEL_UP))
	rack._gui_input(_click(Vector2(50, 100), MOUSE_BUTTON_WHEEL_UP))
	assert_ne(rack.part_rect(0), Rect2(), "y no se pasa del principio")


func test_cambiar_de_hueco_vuelve_al_principio_y_recogerlo_lo_cierra() -> void:
	var profile := _profile()
	var state := _brief.rack(profile, "side0")
	(state["parts"] as Array).append_array((state["parts"] as Array).duplicate())
	(state["parts"] as Array).append_array((state["parts"] as Array).duplicate())
	var rack := _rack(state)
	rack.scroll_rows(1)
	rack.state = _brief.rack(profile, "torso")
	assert_ne(rack.part_rect(0), Rect2(), "otro hueco empieza por arriba")
	assert_true(rack.is_open())
	rack.close(true)
	assert_false(rack.is_open())
	assert_false(rack.visible)


# --- Las cunas del banco (SlotCell) -------------------------------------------------


func test_una_cuna_dice_que_lleva_y_acepta_solo_su_tipo() -> void:
	var cell := SlotCell.new()
	cell.slot = "module0"
	cell.accepts = ItemDef.Type.MODULE
	cell.title = "Módulo 1"
	add_child_autofree(cell)
	assert_eq(cell.tag_lines()[1], Txt.t("slot_empty"))
	cell.item = _brief.resolved(_profile(), "mod_blindaje")
	cell.progress_text = "Básica 0/6"
	assert_eq(cell.tag_lines(), ["Blindaje Reforzado", "Básica 0/6"] as Array[String])
	assert_true(cell.accepts_data({"id": "mod_matriz", "type": ItemDef.Type.MODULE}))
	assert_false(cell.accepts_data({"id": "x", "type": ItemDef.Type.SIDE}))
	var own := {"id": "mod_blindaje", "type": ItemDef.Type.MODULE, "from_slot": "module0"}
	assert_false(cell.accepts_data(own), "no sobre si misma")
	cell.locked_text = "Nivel 10"
	assert_eq(cell.tag_lines()[1], "Nivel 10")
	assert_false(cell.accepts_data({"id": "mod_matriz", "type": ItemDef.Type.MODULE}))
	assert_null(cell._get_drag_data(Vector2.ZERO), "cerrada no se arrastra")


func test_todas_las_piezas_del_catalogo_tienen_dibujo() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	var missing: Array[String] = []
	var symbols := {}
	for type in ItemDef.Type.values():
		for def in _catalog.by_type(type):
			if MechSprites.icon_for(def) == null and not PartGlyph.has(def):
				missing.append(def.id)
			if def.type == ItemDef.Type.MODULE:
				symbols[PartGlyph.module_symbol(def)] = true
	assert_eq(missing, [] as Array[String], "cada pieza se ve en el tablero y en su cuna")
	assert_gt(symbols.size(), 5, "los modulos se distinguen por su simbolo")


# --- Las pantallas de cerca (WallConsole) ---------------------------------------------


func test_la_pantalla_de_mejoras_dice_el_estado_de_cada_una() -> void:
	var profile := _profile(100000)
	var state := _brief.upgrades(profile)
	assert_eq((state["rows"] as Array).size(), _brief.shop.track_ids().size())
	var kinds := {}
	for row: Dictionary in state["rows"]:
		kinds[row["id"]] = row["state"]
	assert_eq(kinds["damage"], "ok")
	assert_eq(kinds["assist"], "locked", "la del asistente se abre al transformarlo")
	profile.gold = 0
	for row: Dictionary in _brief.upgrades(profile)["rows"]:
		if row["id"] == "damage":
			assert_eq(row["state"], "poor")
	# Al tope de la zona ya no sube aunque sobren celdas.
	profile.gold = 100000
	profile.shop_levels["damage"] = int(state["cap"])
	for row: Dictionary in _brief.upgrades(profile)["rows"]:
		if row["id"] == "damage":
			assert_eq(row["state"], "cap" if int(state["cap"]) < int(state["max"]) else "max")


func test_pulsar_una_mejora_la_pide_solo_si_se_puede() -> void:
	var profile := _profile(100000)
	var console := _console(_brief.upgrades(profile))
	console._gui_input(_click(console.zone_rect("row:damage").get_center()))
	assert_eq(_picked, ["damage"] as Array[String])
	console._gui_input(_click(console.zone_rect("row:assist").get_center()))
	assert_eq(_picked.size(), 1, "la cerrada no se pide")


func test_el_arbol_enciende_lo_aprendido_y_ofrece_la_siguiente() -> void:
	var profile := _profile()
	profile.xp = 9500
	profile.skills.assign(["asalto_1", "asalto_2"])
	var state := _brief.skill_tree(profile)
	assert_eq((state["branches"] as Array).size(), 3)
	var nodes: Array = state["branches"][0]["nodes"]
	assert_eq(nodes[0]["state"], "done")
	assert_eq(nodes[1]["state"], "done")
	assert_eq(nodes[2]["state"], "next")
	assert_eq(nodes[3]["state"], "closed")
	assert_gt(int(state["points"]), 0)
	var console := _console(state)
	var next_id := str(nodes[2]["id"])
	console._gui_input(_click(console.zone_rect("node:" + next_id).get_center()))
	console._gui_input(_click(console.zone_rect("node:" + str(nodes[3]["id"])).get_center()))
	console._gui_input(_click(console.zone_rect("node:" + str(nodes[0]["id"])).get_center()))
	assert_eq(_picked, [next_id] as Array[String], "solo la que toca")


func test_sin_puntos_la_siguiente_no_se_aprende() -> void:
	var profile := _profile()
	var state := _brief.skill_tree(profile)
	assert_eq(int(state["points"]), 0)
	var first: Dictionary = state["branches"][0]["nodes"][0]
	assert_eq(first["state"], "next")
	assert_ne(str(first["reason"]), "")
	var console := _console(state)
	console._gui_input(_click(console.zone_rect("node:" + str(first["id"])).get_center()))
	assert_eq(_picked.size(), 0)


func test_la_ficha_del_robot_solo_deja_desmontar_si_hay_otro() -> void:
	var profile := _profile()
	var state := _brief.robot(profile, "Horno")
	assert_false(bool(state["can_remove"]))
	var console := _console(state)
	assert_eq(console.zone_rect("remove"), Rect2())
	profile.mechs.append(profile.mechs[0].duplicate(true))
	state = _brief.robot(profile, "Horno")
	assert_true(bool(state["can_remove"]))
	console.state = state
	# Desmontarlo pide dos pulsaciones, sin ninguna ventana.
	console._gui_input(_click(console.zone_rect("remove").get_center()))
	assert_eq(_counts["remove"], 0, "la primera solo lo deja armado")
	assert_eq(console.armed(), "remove")
	console._gui_input(_click(console.zone_rect("remove").get_center()))
	assert_eq(_counts["remove"], 1)
	assert_eq(console.armed(), "")


func test_mientras_crece_la_pantalla_no_se_pulsa() -> void:
	var console := WallConsole.new()
	add_child_autofree(console)
	console.upgrade_picked.connect(func(id: String) -> void: _picked.append(id))
	console.open(
		_brief.upgrades(_profile(100000)), Rect2(220, 60, 150, 140), Rect2(40, 60, 470, 450)
	)
	assert_eq(console.kind(), "mejoras")
	assert_lt(console.shown(), 0.5)
	console._gui_input(_click(Vector2(60, 60)))
	assert_eq(_picked.size(), 0)
	console.close(true)
	assert_eq(console.kind(), "")
	assert_false(console.visible)


# --- Adquirir un robot en su bahia (BayProjector) --------------------------------------


func _projector(state: Dictionary) -> BayProjector:
	var projector := BayProjector.new()
	add_child_autofree(projector)
	projector.open(state, Rect2(100, 300, 180, 224))
	projector.bought.connect(func(id: String) -> void: _bought.append(id))
	return projector


func test_una_bahia_vacia_ofrece_un_armazon_de_cada_tipo() -> void:
	var profile := _profile(0)
	var offers: Array = _brief.offers(profile)["offers"]
	assert_eq(offers.size(), _brief.styles.ids().size())
	for i in offers.size():
		var style_id: String = _brief.styles.ids()[i]
		assert_eq(offers[i]["id"], style_id)
		assert_eq(int(offers[i]["price"]), 0, "los armazones son gratis")
		assert_null(offers[i]["build"], "llega vacio: se arma con tus piezas")
		assert_eq(str(offers[i]["reason"]), "")
		assert_string_contains(str(offers[i]["name"]), _brief.styles.role(style_id))
		assert_eq(str(offers[i]["hint"]), _brief.arms_text(style_id))


func test_con_el_garaje_lleno_la_bahia_lo_dice() -> void:
	var profile := _profile(100000)
	while profile.mechs.size() < _brief.rules.max_mechs:
		profile.mechs.append(profile.mechs[0].duplicate(true))
	for offer: Dictionary in _brief.offers(profile)["offers"]:
		assert_eq(str(offer["reason"]), Txt.t("acquire_why_full"))


func test_la_bahia_pasa_de_una_oferta_a_otra_y_da_la_vuelta() -> void:
	var state := _brief.offers(_profile(100000))
	var projector := _projector(state)
	var count := (state["offers"] as Array).size()
	assert_eq(projector.current()["id"], state["offers"][0]["id"])
	projector._gui_input(_click(projector.zone_rect("next").get_center()))
	assert_eq(projector.current()["id"], state["offers"][1]["id"])
	projector._gui_input(_click(projector.zone_rect("prev").get_center()))
	projector._gui_input(_click(projector.zone_rect("prev").get_center()))
	assert_eq(projector.current()["id"], state["offers"][count - 1]["id"], "da la vuelta")
	projector._gui_input(_click(Vector2(60, 60), MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(projector.current()["id"], state["offers"][0]["id"])


func test_un_robot_se_adquiere_con_dos_pulsaciones() -> void:
	var projector := _projector(_brief.offers(_profile(100000)))
	projector.step(1)
	var id := str(projector.current()["id"])
	var at := projector.zone_rect("robot").get_center()
	projector._gui_input(_click(at))
	assert_true(projector.is_armed())
	assert_eq(_bought.size(), 0, "la primera solo lo deja armado")
	# Pasar a otra oferta lo desarma.
	projector.step(1)
	assert_false(projector.is_armed())
	projector.step(-1)
	projector._gui_input(_click(at))
	projector._gui_input(_click(at))
	assert_eq(_bought, [id] as Array[String])


func test_lo_que_no_se_puede_adquirir_no_se_arma() -> void:
	var profile := _profile(0)
	while profile.mechs.size() < _brief.rules.max_mechs:
		profile.mechs.append(profile.mechs[0].duplicate(true))
	var projector := _projector(_brief.offers(profile))
	var at := projector.zone_rect("robot").get_center()
	projector._gui_input(_click(at))
	projector._gui_input(_click(at))
	assert_false(projector.is_armed())
	assert_eq(_bought.size(), 0)


func test_el_proyector_se_enciende_en_la_bahia_vacia_que_se_pulso() -> void:
	var stage := _stage()
	var none: MechBuild = null
	var bays: Array[Dictionary] = [
		{"index": 1, "build": stage._mech.build, "name": "Otro"},
		{"index": -1, "build": none, "name": ""},
		{"index": -1, "build": none, "name": ""},
	]
	stage.set_bays(bays)
	assert_false(stage.projector.is_open())
	stage._gui_input(_click(stage._bay_rects[2].get_center()))
	stage.show_offers(_brief.offers(_profile(100000)))
	assert_true(stage.projector.is_open())
	assert_true(
		stage.projector.get_rect().intersects(stage._bay_rects[2]), "sobre la bahia pulsada"
	)
	assert_false(stage.projector.get_rect().intersects(stage._bay_rects[0]))
	stage.hide_offers()
	assert_false(stage.projector.is_open())
	# Sin haber pulsado una vacia, se enciende en la primera vacia.
	stage._pressed_bay = 0
	stage.show_offers(_brief.offers(_profile(100000)))
	assert_true(stage.projector.get_rect().intersects(stage._bay_rects[1]))


# --- Los ajustes, en su cuadro de control ---------------------------------------------


func _drag_to(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _release(at: Vector2) -> InputEventMouseButton:
	var event := _click(at)
	event.pressed = false
	return event


func test_la_pantalla_de_ajustes_ensena_los_del_jugador() -> void:
	var settings := GameSettings.new()
	settings.speed_index = 2
	settings.fullscreen = true
	settings.volumes["Music"] = 0.35
	var state := WallConsole.settings_state(settings, true)
	assert_eq(state["kind"], "ajustes")
	assert_eq(int(state["speed"]), 2)
	assert_true(bool(state["fullscreen"]))
	assert_eq((state["speeds"] as Array).size(), GameSettings.SPEEDS.size())
	assert_eq((state["volumes"] as Array).size(), GameSettings.BUSES.size())
	for entry: Dictionary in state["volumes"]:
		assert_almost_eq(float(entry["value"]), settings.volumes[entry["bus"]], 0.001)
	assert_true(bool(state["quit"]))


func test_pulsar_una_velocidad_o_el_interruptor_cambia_el_ajuste() -> void:
	var console := _console(WallConsole.settings_state(GameSettings.new(), true))
	console._gui_input(_click(console.zone_rect("speed:3").get_center()))
	console._gui_input(_click(console.zone_rect("full").get_center()))
	assert_eq(_changes, [["speed", 3], ["fullscreen", true]])


func test_la_barra_de_volumen_se_pulsa_y_se_arrastra() -> void:
	var settings := GameSettings.new()
	var console := _console(WallConsole.settings_state(settings, true))
	var bar := console.zone_rect("vol:Music")
	var y := bar.get_center().y
	console._gui_input(_click(Vector2(bar.position.x + bar.size.x * 0.25, y)))
	assert_eq(_changes.size(), 1)
	assert_eq(_changes[0][0], "volume:Music")
	assert_almost_eq(float(_changes[0][1]), 0.25, 0.001)
	# Arrastrar mas alla del final la deja al maximo; a la izquierda, en silencio.
	console._gui_input(_drag_to(Vector2(bar.end.x + 40.0, y)))
	assert_almost_eq(float(_changes[-1][1]), 1.0, 0.001)
	console._gui_input(_drag_to(Vector2(bar.position.x - 40.0, y)))
	assert_almost_eq(float(_changes[-1][1]), 0.0, 0.001)
	# Al soltar deja de seguir al raton.
	var before := _changes.size()
	console._gui_input(_release(Vector2(bar.position.x, y)))
	console._gui_input(_drag_to(Vector2(bar.get_center().x, y)))
	assert_eq(_changes.size(), before)


func test_el_volumen_que_ya_esta_no_se_repite() -> void:
	var settings := GameSettings.new()
	settings.volumes["Effects"] = 0.5
	var console := _console(WallConsole.settings_state(settings, true))
	var bar := console.zone_rect("vol:Effects")
	console._gui_input(_click(bar.get_center()))
	assert_eq(_changes.size(), 0)


func test_salir_del_juego_pide_dos_pulsaciones() -> void:
	var console := _console(WallConsole.settings_state(GameSettings.new(), true))
	var at := console.zone_rect("quit").get_center()
	console._gui_input(_click(at))
	assert_eq(_counts["quit"], 0, "la primera solo lo deja armado")
	# Tocar otra cosa lo desarma.
	console._gui_input(_click(console.zone_rect("speed:1").get_center()))
	console._gui_input(_click(at))
	assert_eq(_counts["quit"], 0)
	console._gui_input(_click(at))
	assert_eq(_counts["quit"], 1)
	# Donde no se puede salir (sin hangar) no hay tecla.
	console.state = WallConsole.settings_state(GameSettings.new(), false)
	assert_eq(console.zone_rect("quit"), Rect2())


func test_el_cuadro_de_control_esta_en_la_pared_y_se_pulsa() -> void:
	var stage := _stage()
	stage.terminal_pressed.connect(func(terminal: String) -> void: _pressed.append(terminal))
	var box: Rect2 = stage._terminal_rects["ajustes"]
	assert_true(Rect2(Vector2.ZERO, stage.size).encloses(box))
	for other: String in ["tienda", "mejoras", "habilidades"]:
		assert_false(box.intersects(stage._terminal_rects[other]), "no pisa " + other)
	stage._gui_input(_click(box.get_center()))
	assert_eq(_pressed, ["ajustes"] as Array[String])
	stage.show_console(WallConsole.settings_state(GameSettings.new(), true), true)
	assert_eq(stage.console.kind(), "ajustes")
	assert_true(stage.console.get_rect().encloses(box), "crece desde su sitio")


# --- En el hangar (HangarStage) ---------------------------------------------------------


func _stage() -> HangarStage:
	var stage := HangarStage.new()
	stage.size = Vector2(1280, 720)
	add_child_autofree(stage)
	var build := _library.make("fisico_vanguardia", _catalog, _brief.rules, ItemDef.Tier.COMMON, 6)
	stage.show_build(build, [] as Array[String])
	stage.target_pressed.connect(func() -> void: _counts["target"] += 1)
	return stage


func test_la_diana_solo_prueba_si_hay_un_arma_elegida() -> void:
	var stage := _stage()
	var at := stage.target_rect().get_center()
	stage._gui_input(_click(at))
	assert_eq(_counts["target"], 0)
	stage.can_test = true
	stage._gui_input(_click(at))
	assert_eq(_counts["target"], 1)


func test_una_hoja_se_prueba_con_su_tajo_y_no_con_un_disparo() -> void:
	var stage := _stage()
	var blade := ""
	var gun := ""
	for i in 4:
		var slot := "side%d" % i
		if stage._item_in(slot) == null:
			continue
		if stage._mech.is_melee(slot):
			blade = slot
		else:
			gun = slot
	assert_ne(blade, "", "el robot de la prueba lleva una hoja")
	assert_ne(gun, "", "y un arma que dispara")
	# Un arma que dispara no da tajo ni mueve al robot.
	assert_eq(stage._mech.swing(0.4, gun), 0.0)
	var home := stage._mech.position
	stage.test_fire(gun, "rafaga", Color.WHITE)
	await wait_seconds(0.3)
	assert_false(stage._striking)
	assert_true(stage._mech.position.distance_to(home) < 1.0)
	await wait_seconds(0.6)
	# La hoja: como en el combate, salta junto a la diana, da el tajo y vuelve.
	var center := stage._platform_center()
	stage.test_fire(blade, "tajo_vibrante", Color.WHITE)
	await wait_seconds(0.7)
	assert_true(stage._striking)
	assert_gt(stage._mech.position.x, home.x + 10.0, "se acerca a la diana")
	assert_ne(stage._mech._swing, 0.0, "la hoja se mueve")
	assert_eq(stage._platform_center(), center, "su plataforma no se va con el")
	await wait_seconds(1.6)
	assert_false(stage._striking)
	assert_true(stage._mech.position.distance_to(home) < 0.5, "vuelve a su sitio")
	assert_eq(stage._mech._swing, 0.0)


# --- Observaciones del 2026-11-20 (docs/OBSERVACIONES.md) --------------------------


func _screen_point(stage: HangarStage, world: Vector2) -> Vector2:
	return stage._world.position + world * stage._world.scale.x


func test_obs004_las_piernas_que_faltan_se_eligen_en_su_fantasma() -> void:
	var stage := _stage()
	var build: MechBuild = stage._mech.build
	stage.show_build(build, ["legs"] as Array[String])
	var legs := _screen_point(stage, stage._world_rect("legs").get_center())
	assert_true("legs" in stage.slots_at(legs), "el fantasma se puede pulsar")
	var picked: Array[String] = []
	stage.picked.connect(func(slot: String) -> void: picked.append(slot))
	# Un punto de las piernas que no tape ningun arma.
	var foot := _screen_point(
		stage,
		stage._world_rect("legs").position + stage._world_rect("legs").size * Vector2(0.5, 0.85)
	)
	stage._gui_input(_click(foot))
	assert_eq(picked, ["legs"] as Array[String])
	assert_null(stage._get_drag_data(foot), "un fantasma no se arrastra")


func test_obs005_pulsar_otra_vez_pasa_al_arma_de_detras() -> void:
	var stage := _stage()
	var both := stage._world_rect("side0").intersection(stage._world_rect("side2"))
	assert_gt(both.get_area(), 0.0, "el brazo de detras queda tapado por el de delante")
	var at := _screen_point(stage, both.get_center())
	var under := stage.slots_at(at)
	assert_true("side0" in under and "side2" in under)
	assert_eq(stage.slot_to_pick(at), under[0], "el primer clic, el de encima")
	stage.selected_slot = under[0]
	assert_eq(stage.slot_to_pick(at), under[1], "el segundo, el de debajo")
	stage.selected_slot = under[under.size() - 1]
	assert_eq(stage.slot_to_pick(at), under[0], "y da la vuelta")


func test_obs005_la_cabecera_del_tablero_tiene_una_casilla_por_hueco() -> void:
	var profile := _profile()
	var state := _brief.rack(profile, "side1")
	var siblings: Array = state["siblings"]
	assert_eq(siblings.size(), 4, "los cuatro brazos")
	for entry: Dictionary in siblings:
		assert_eq(bool(entry["selected"]), entry["slot"] == "side1")
		assert_eq(bool(entry["filled"]), Garage.get_slot(profile.build, entry["slot"]) != "")
	assert_eq((_brief.rack(profile, "top0")["siblings"] as Array).size(), 2)
	# El torso y las piernas van juntos: de uno se pasa al otro.
	var body: Array = _brief.rack(profile, "torso")["siblings"]
	assert_eq(body.size(), 2)
	assert_eq(body[1]["slot"], "legs")
	assert_eq((_brief.rack(profile, "hook")["siblings"] as Array).size(), 0, "un hueco solo")
	var picked: Array[String] = []
	var rack := _rack(state)
	rack.slot_picked.connect(func(slot: String) -> void: picked.append(slot))
	rack._gui_input(_click(rack.sibling_rects()[2].get_center()))
	assert_eq(picked, ["side2"] as Array[String])
	assert_eq(_chosen.size(), 0)


func test_obs008_la_tecla_de_subir_dice_lo_que_cambia() -> void:
	var profile := _profile()
	var key: Dictionary = _brief.rack(profile, "side1")["key"]
	assert_string_contains(str(key["gain"]), "→")
	assert_string_contains(str(key["gain"]), "daño")
	# Un torso dice su vida; y lo que dice es lo que pasa al subirlo.
	var torso_key: Dictionary = _brief.rack(profile, "torso")["key"]
	assert_string_contains(str(torso_key["gain"]), Txt.t("stat_health"))
	var id := Garage.get_slot(profile.build, "torso")
	var before := _brief.resolved(profile, id).health
	profile.parts[id] = {"tier": 0, "level": 1}
	var after := _brief.resolved(profile, id).health
	assert_gt(after, before, "subir de nivel sube la vida del torso")
	assert_string_contains(str(torso_key["gain"]), "%d → %d" % [before, after])


func test_obs009_cada_arma_de_balas_dispara_a_su_manera() -> void:
	var burst := ShotFx.shot("rafaga")
	var blast := ShotFx.shot("perdigones")
	var slug := ShotFx.shot("bala_rifle")
	assert_gt(int(burst["count"]), 8, "la ametralladora, muchas balas")
	assert_gt(float(burst["gap"]), 0.0, "una detras de otra")
	assert_gt(int(blast["count"]), 10, "la escopeta, muchos fragmentos")
	assert_eq(float(blast["gap"]), 0.0, "de un solo tiro")
	assert_gt(float(blast["spread"]), float(burst["spread"]) * 3.0, "muy abiertos")
	assert_gt(float(blast["kick"]), float(burst["kick"]) * 2.0, "con mas culatazo")
	assert_eq(int(slug["count"]), 1, "el rifle, un tiro")
	# El arma da un golpe por bala en la rafaga y uno solo en la escopeta.
	var stage := _stage()
	for id: String in ShotFx.table():
		ShotFx.kick(stage._mech, id, 0.3, "side1", 0.42)
	assert_true(true, "ningun disparo rompe el gesto del arma")


func test_obs023_la_rueda_gira_el_robot_con_el_cursor_sobre_el() -> void:
	var stage := _stage()
	var chest := _screen_point(stage, stage._world_rect("torso").get_center())
	stage._gui_input(_click(chest, MOUSE_BUTTON_WHEEL_UP))
	await wait_seconds(0.3)
	assert_true(stage.is_turned(), "gira sin tener que acertar en la plataforma")
	# Lejos del robot la rueda no lo mueve.
	var before := stage.turn
	stage._gui_input(_click(Vector2(40, 40), MOUSE_BUTTON_WHEEL_UP))
	await wait_seconds(0.3)
	assert_eq(stage.turn, before)


func test_obs023_de_media_vuelta_se_tocan_las_armas_del_otro_lado() -> void:
	var stage := _stage()
	var both := stage._world_rect("side0").intersection(stage._world_rect("side2"))
	var at := _screen_point(stage, both.get_center())
	assert_eq(stage.slots_at(at)[0], "side0", "de perfil, delante el brazo cercano")
	# A medio girar no se toca nada.
	stage.turn = PI / 2.0
	assert_eq(stage.slots_at(at).size(), 0)
	# De media vuelta el robot se ve reflejado y manda el brazo del otro lado.
	stage.turn = PI
	assert_true(stage.is_flipped())
	var mirrored := _screen_point(stage, stage._robot_point(both.get_center()))
	var under := stage.slots_at(mirrored)
	assert_gt(under.size(), 1)
	assert_eq(under[0], "side2", "delante queda el brazo que de perfil estaba detras")
	var picked: Array[String] = []
	stage.picked.connect(func(slot: String) -> void: picked.append(slot))
	stage._gui_input(_click(mirrored))
	assert_eq(picked, ["side2"] as Array[String])


func test_el_tablero_cuelga_a_la_derecha_sin_tapar_al_robot_ni_el_banco() -> void:
	var stage := _stage()
	var home := stage.parts_rack.home
	assert_true(Rect2(Vector2.ZERO, stage.size).encloses(home), "cabe en la pantalla")
	assert_gt(home.position.x, stage.slot_screen_point("torso").x, "a la derecha del robot")
	assert_false(home.intersects(stage._shelf_rect()), "no tapa el banco")
	assert_false(home.intersects(Rect2(stage._board.position, stage._board.size)))
	assert_false(stage.parts_rack.visible, "recogido hasta que se elige un hueco")


func test_cada_pantalla_crece_desde_su_sitio() -> void:
	var stage := _stage()
	for kind: String in ["mejoras", "habilidades", "robot", "ajustes"]:
		var rects := stage.console_rects(kind)
		assert_gt(rects[1].get_area(), rects[0].get_area() * 2.0, kind + " crece")
		assert_true(Rect2(Vector2.ZERO, stage.size).encloses(rects[1]), kind + " cabe")
	assert_true(stage.console_rects("mejoras")[1].encloses(stage._terminal_rects["mejoras"]))
	var state := _brief.upgrades(_profile())
	stage.show_console(state, true)
	assert_eq(stage.console.kind(), "mejoras")
	assert_eq(stage.console.shown(), 1.0)
	stage.hide_console()
	assert_eq(stage.console.kind(), "")
