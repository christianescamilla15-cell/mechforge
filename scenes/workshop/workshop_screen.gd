class_name WorkshopScreen
extends Control
## El hangar: la pantalla de inicio, inmersiva y con los menos botones posibles
## (pedido del usuario el 2026-11-18). Es el taller y la armeria a la vez,
## todo dentro de la escena (HangarStage):
## - tu robot en el centro: un clic en una pieza (o en el enchufe de un hueco
##   vacio) la elige; las piezas se arrastran al robot y del robot;
## - tus otros robots en las bahias del fondo: un clic y pasas a usarlo; una
##   bahia vacia es para adquirir otro;
## - las terminales de la pared: tienda, mejoras y habilidades;
## - el monitor de misiones: al pulsarlo el hangar se queda en penumbra y los
##   rivales se proyectan delante de tu robot (HangarStage, RivalRow); pulsar
##   al primero es salir a combatir. No hay cajon ni botones;
## - el estante de equipo bajo el robot: pecho, especiales, asistente y
##   modulos.
## Lo que se toca abre un cajon que se desliza desde la derecha; pulsar el
## hangar vacio o Esc lo cierra. Arriba, una barra con tu robot, tus celdas,
## tu nivel, la zona, el peso y los ajustes. Lee y cambia el perfil a traves
## de MainScreen, que lo guarda.

signal closed

const DRAWER_WIDTH := 420.0
const SLIDE_SECONDS := 0.3
## Cajones que muestran el resumen del robot (para ver lo que cambia).
const WITH_SUMMARY: Array[String] = ["pieza", "tienda", "mejoras", "robot"]
const COLOR_MUTED := Color("9aa7b8")
const COLOR_GOOD := Color("7dff9b")
const COLOR_BAD := Color("ff7d7d")
const COLOR_CELLS := Color("7fe3ff")
const COLOR_GOLD := Color("ffd36b")
const SUMMARY_KEYS: Array[String] = [
	"weight",
	"health",
	"energy_cap",
	"energy_regen",
	"heat_cap",
	"cooling",
	"res_physical",
	"res_heat",
	"res_energy"
]

var main: MainScreen

var _selected: String = "side0"
var _hover_id: String = ""
## Hueco con el que se compara la pieza bajo el raton.
var _hover_slot: String = ""
var _page: String = ""
## Canal del modo mision ("campaign", "arena" o "free"); "" = apagado.
var _channel: String = ""
var _launching := false
var _store_group: String = "todo"
var _stage: HangarStage
var _robot_button: Button
var _top_info: Label
var _xp: ProgressBar
var _weight: ProgressBar
var _weight_label: Label
var _problems: Label
var _toast: Label
var _drawer: PanelContainer
var _drawer_title: Label
var _summary: GridContainer
var _page_scroll: ScrollContainer
var _page_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = HangarStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	_stage.picked.connect(_on_part_picked)
	_stage.dropped.connect(_on_stage_dropped)
	_stage.dropped_on.connect(_on_cell_dropped)
	_stage.terminal_pressed.connect(show_page)
	_stage.bay_pressed.connect(_on_bay_pressed)
	_stage.background_pressed.connect(_on_background_pressed)
	_stage.missions_pressed.connect(open_missions)
	_stage.rival_pressed.connect(_on_rival_pressed)
	_stage.channel_picked.connect(open_missions)
	_stage.pick_changed.connect(_on_pick_changed)
	_build_rack()
	_build_hud()
	_build_drawer()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _launching:
			return
		if _page != "":
			close_drawer()
		elif _channel != "":
			close_missions()
		else:
			main.open_settings()


# --- Construccion ------------------------------------------------------------


## Los huecos del estante (los que no se ven en el dibujo del robot).
func _build_rack() -> void:
	for slot in HangarStage.RACK_TOP + HangarStage.RACK_BOTTOM:
		var cell := SlotCell.new()
		cell.slot = slot
		cell.compact = true
		cell.accepts = Garage.slot_type(slot)
		cell.title = slot_title(slot)
		cell.picked.connect(_on_part_picked)
		cell.dropped.connect(_on_cell_dropped)
		cell.cleared.connect(clear_slot)
		cell.hovered.connect(_on_cell_hovered)
		_stage.add_child(cell)
		_stage.rack[slot] = cell


## Barra de arriba: tu robot (abre su cajon), celdas, nivel con su barra,
## zona, peso con sus avisos y el engrane de los ajustes.
func _build_hud() -> void:
	var bar := PanelContainer.new()
	var style := TechStyle.plate(Color(0.07, 0.1, 0.14, 0.92), Color("3c4c62"), 6.0, 8.0)
	style.groove = false
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 6
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	_robot_button = Button.new()
	_robot_button.flat = true
	_robot_button.add_theme_font_size_override("font_size", 19)
	_robot_button.add_theme_color_override("font_color", COLOR_GOLD)
	_robot_button.tooltip_text = Txt.t("hud_robot_hint")
	_robot_button.pressed.connect(show_page.bind("robot"))
	row.add_child(_robot_button)
	_top_info = _label(row, "", 15, COLOR_CELLS)
	var xp_box := VBoxContainer.new()
	xp_box.custom_minimum_size = Vector2(120, 0)
	xp_box.add_theme_constant_override("separation", 0)
	row.add_child(xp_box)
	_label(xp_box, Txt.t("hud_xp"), 10, COLOR_MUTED)
	_xp = ProgressBar.new()
	_xp.show_percentage = false
	_xp.custom_minimum_size = Vector2(0, 8)
	xp_box.add_child(_xp)
	var weight := VBoxContainer.new()
	weight.custom_minimum_size = Vector2(200, 0)
	weight.add_theme_constant_override("separation", 0)
	row.add_child(weight)
	_weight_label = _label(weight, "", 11, COLOR_MUTED)
	_weight = ProgressBar.new()
	_weight.show_percentage = false
	_weight.custom_minimum_size = Vector2(0, 8)
	weight.add_child(_weight)
	_problems = _label(row, "", 13, COLOR_BAD)
	_problems.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var gear := Button.new()
	gear.text = "⚙"
	gear.tooltip_text = Txt.t("settings_open")
	gear.custom_minimum_size = Vector2(40, 34)
	gear.add_theme_font_size_override("font_size", 18)
	gear.pressed.connect(main.open_settings)
	row.add_child(gear)
	# Aviso pasajero (lo que se cobro en el ultimo combate, etc.).
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 58
	_toast.add_theme_font_size_override("font_size", 17)
	_toast.add_theme_color_override("font_color", COLOR_GOLD)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_toast)


## El cajon de la derecha: titulo con su X, el resumen del robot y la pagina.
func _build_drawer() -> void:
	_drawer = PanelContainer.new()
	var style := TechStyle.plate(Color(0.07, 0.1, 0.15, 0.96), COLOR_GOLD, 12.0, 12.0)
	style.glow = 0.25
	_drawer.add_theme_stylebox_override("panel", style)
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_drawer.offset_left = -DRAWER_WIDTH
	_drawer.offset_top = 58
	_drawer.offset_bottom = -8
	_drawer.offset_right = -8
	_drawer.visible = false
	add_child(_drawer)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_drawer.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	_drawer_title = _label(head, "", 22)
	_drawer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.add_theme_font_size_override("font_size", 22)
	close.tooltip_text = Txt.t("settings_close")
	close.pressed.connect(close_drawer)
	head.add_child(close)
	_summary = GridContainer.new()
	_summary.columns = 6
	_summary.add_theme_constant_override("h_separation", 8)
	box.add_child(_summary)
	_page_scroll = ScrollContainer.new()
	_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Soltar aqui una pieza montada la quita.
	_page_scroll.set_drag_forwarding(
		Callable(),
		func(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and data.has("from_slot"),
		func(_at: Vector2, data: Variant) -> void: clear_slot(data["from_slot"])
	)
	box.add_child(_page_scroll)
	_page_box = VBoxContainer.new()
	_page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_box.add_theme_constant_override("separation", 5)
	_page_scroll.add_child(_page_box)


# --- Estado ------------------------------------------------------------------


## Gira el robot del hangar a ese angulo, en grados (0 = de perfil).
func turn_robot(degrees: float) -> void:
	_stage.turn = deg_to_rad(degrees)


## Vuelve a pintar todo con el perfil actual.
func refresh() -> void:
	var build := _build_from(main._profile.build)
	var ghosts: Array[String] = []
	var shown := build
	if build.torso == null or build.legs == null:
		# Sin torso o sin piernas se ve el hueco: una pieza fantasma en su sitio.
		shown = _build_from(main._profile.build)
		if shown.torso == null:
			shown.torso = _placeholder(ItemDef.Type.TORSO)
			ghosts.append("torso")
		if shown.legs == null:
			shown.legs = _placeholder(ItemDef.Type.LEGS)
			ghosts.append("legs")
	_stage.show_build(shown, ghosts)
	_stage.selected_slot = _selected if _page == "pieza" else ""
	# El monitor de misiones siempre ensena la campana; en el modo mision, su
	# canal, con la fila de rivales delante.
	if _channel == "":
		_stage.set_board(main.mission_state("campaign"))
	else:
		_stage.show_mission(main.mission_state(_channel))
	_stage.set_bays(_bays())
	var level := main._player_level()
	_robot_button.text = main.robot_name(main._profile.active) + "  ▾"
	var zone := mini(main._profile.zone, main._campaign.zone_count() - 1)
	_top_info.text = Txt.t(
		"hud_info", [main._profile.gold, level, zone + 1, main._campaign.zone_name(zone)]
	)
	var next := main._progression.next_level_xp(main._profile.xp)
	_xp.max_value = maxi(next, 1)
	_xp.value = main._profile.xp if next >= 0 else 1
	var max_weight := main._rules.max_weight
	_weight.max_value = max_weight + main._rules.overload
	_weight.value = build.total_weight()
	_weight_label.text = Txt.t("mech_weight", [build.total_weight(), max_weight])
	_weight.modulate = COLOR_BAD if build.total_weight() > max_weight else Color.WHITE
	var problems := build.validate(main._rules)
	_problems.text = "" if problems.is_empty() else Txt.t("mech_problems", [", ".join(problems)])
	for slot: String in _stage.rack:
		_refresh_cell(_stage.rack[slot], level)
	_refresh_summary(build)
	if _page != "":
		_fill_page()


## Las tres bahias: tus otros robots (un armazon vacio se ve como bahia
## vacia, pero es tuyo) y, si caben mas, bahias para adquirir.
func _bays() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in main._profile.mechs.size():
		if i == main._profile.active or out.size() >= 3:
			continue
		var build := main._robot_build(main._profile.mechs[i]["build"])
		var armed := build.torso != null and build.legs != null
		out.append({"index": i, "build": build if armed else null, "name": main.robot_name(i)})
	while out.size() < main._rules.max_mechs - 1:
		out.append({"index": -1, "build": null, "name": ""})
	return out


func _refresh_cell(cell: SlotCell, level: int) -> void:
	var id := Garage.get_slot(main._profile.build, cell.slot)
	cell.item = _resolved(id)
	cell.selected = cell.slot == _selected and _page == "pieza"
	cell.locked_text = _lock_reason(cell.slot, level)
	cell.progress_text = _progress_text(cell.item)
	cell.refresh()


## Por que un hueco esta cerrado ("" si esta abierto).
func _lock_reason(slot: String, level: int) -> String:
	if not main._progression.is_unlocked(slot, level):
		return Txt.t("slot_locked", [main._progression.unlock_level(slot)])
	if slot == "drone_low" and main._assist_tier() < main._rules.assist_second_weapon_tier:
		return Txt.t("slot_second_weapon")
	return ""


## Una pieza con la clase y el nivel que tiene el jugador.
func _resolved(id: String) -> ItemDef:
	var def := main._catalog.get_item(id) if id != "" else null
	if def == null:
		return null
	var p := main._profile.part(def.progress_id())
	if def.type == ItemDef.Type.DRONE and main._profile.build.has("assist"):
		# Las armas del asistente suben con el, sin salirse de su rango.
		var assist := main._profile.part(ItemDef.ASSIST_PROGRESS)
		var tier := clampi(assist["tier"], def.tier_min, def.tier_max)
		var level: int = assist["level"]
		if tier < assist["tier"]:
			level = main._rules.tier_max_level[tier]
		elif tier > assist["tier"]:
			level = 0
		p = {"tier": tier, "level": level}
	return ItemScaling.resolve(def, main._rules, p["tier"], p["level"])


func _progress_text(item: ItemDef) -> String:
	if item == null:
		return ""
	if item.type == ItemDef.Type.DRONE and main._profile.build.has("assist"):
		return Txt.t("part_follows_assist")
	var p := main._profile.part(item.progress_id())
	var top: int = main._rules.tier_max_level[p["tier"]]
	return Txt.t("part_level", [Txt.TIER_NAMES[p["tier"]], p["level"], top])


func _build_from(spec: Dictionary) -> MechBuild:
	return main._robot_build(spec)


## Pieza con la que se dibuja un torso o unas piernas que faltan.
func _placeholder(type: ItemDef.Type) -> ItemDef:
	for id in main._profile.owned:
		var def := main._catalog.get_item(id)
		if def != null and def.type == type:
			return def
	return main._catalog.by_type(type)[0]


func _refresh_summary(build: MechBuild) -> void:
	for child in _summary.get_children():
		child.queue_free()
	_summary.visible = _page in WITH_SUMMARY
	if not _summary.visible:
		return
	var now := build.summary(main._rules)
	var then := now
	if _hover_id != "" and _hover_slot != "":
		var spec: Dictionary = main._profile.build.duplicate(true)
		Garage.set_slot(spec, _hover_slot, _hover_id)
		then = _build_from(spec).summary(main._rules)
	for key in SUMMARY_KEYS:
		var name_key := "stat_weight_total" if key == "weight" else "stat_" + key
		_label(_summary, Txt.t(name_key), 11, COLOR_MUTED)
		var value := _label(_summary, str(now[key]), 13)
		var delta: int = int(then[key]) - int(now[key])
		if delta != 0:
			value.text += " %+d" % delta
			# Mas de todo es mejor, salvo mas peso.
			var better := delta < 0 if key == "weight" else delta > 0
			value.add_theme_color_override("font_color", COLOR_GOOD if better else COLOR_BAD)


# --- El cajon -------------------------------------------------------------------


## Abre (o cambia) el cajon de la derecha con una pagina: "pieza", "tienda",
## "mejoras", "habilidades" o "robot". "misiones" no es un cajon: pone el
## hangar en modo mision.
func show_page(page: String) -> void:
	if page == "misiones":
		open_missions()
		return
	if _launching:
		return
	close_missions()
	var opening := _page == ""
	_page = page
	_hover_id = ""
	_drawer_title.text = Txt.t("drawer_" + page)
	_drawer.visible = true
	refresh()
	_page_scroll.scroll_vertical = 0
	if opening:
		Sfx.play("ui_pagina")
		_drawer.position.x = size.x
		var slide := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		slide.tween_property(_drawer, "position:x", size.x - DRAWER_WIDTH - 8.0, SLIDE_SECONDS)


## Cierra el cajon deslizandolo hacia fuera.
func close_drawer() -> void:
	if _page == "":
		return
	_page = ""
	Sfx.play("ui_cerrar")
	var slide := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	slide.tween_property(_drawer, "position:x", size.x, SLIDE_SECONDS * 0.8)
	slide.tween_callback(func() -> void: _drawer.visible = _page != "")
	refresh()


# --- Modo mision -------------------------------------------------------------------


## Pone el hangar en modo mision (o cambia de canal): en penumbra, con los
## rivales del canal proyectados delante de tu robot. `how` es como aparecen
## ("enter", "advance" al volver de ganar, "none"); `beaten`, el recien
## vencido.
func open_missions(
	channel: String = "campaign", how: String = "enter", beaten: Dictionary = {}
) -> void:
	if _launching:
		return
	if not channel in MissionBrief.CHANNELS:
		channel = "campaign"
	close_drawer()
	_channel = channel
	_stage.show_mission(main.mission_state(channel), how, beaten)


## Vuelve al taller.
func close_missions() -> void:
	if _channel == "":
		return
	_channel = ""
	Sfx.play("ui_cerrar")
	_stage.hide_mission()
	_stage.set_board(main.mission_state("campaign"))


func missions_channel() -> String:
	return _channel


func _on_background_pressed() -> void:
	close_drawer()
	close_missions()


## Una flecha del combate libre en el monitor.
func _on_pick_changed(key: String, step: int) -> void:
	main.change_free_pick(key, step)
	if _channel == "free":
		_stage.show_mission(main.mission_state("free"))


## Se pulso al primero de la fila: salir a combatir. Si tu robot no puede
## pelear se dice por que; el jefe pide una segunda pulsacion.
func _on_rival_pressed() -> void:
	if _launching or _channel == "":
		return
	var state := main.mission_state(_channel)
	if not bool(state["can_fight"]):
		Sfx.play("ui_cerrar")
		toast(str(state["problems"]))
		return
	if not _stage.confirm_rival():
		Sfx.play("ui_habilidad")
		return
	_launching = true
	var speed := main.animation_speed()
	await _stage.launch_out(speed)
	await main.drop_curtain(0.3 / speed)
	main.start_mission(_channel)


## Tienda, con un grupo de piezas ("" = el del hueco elegido).
func show_store(group: String) -> void:
	_store_group = group if group != "" else ArmoryPages.group_of(Garage.slot_type(_selected))
	show_page("tienda")


func current_page() -> String:
	return _page


func _fill_page() -> void:
	for child in _page_box.get_children():
		child.queue_free()
	match _page:
		"pieza":
			_fill_part_page(_page_box)
		"tienda":
			ArmoryPages.store(self, _page_box, _store_group)
		"mejoras":
			ArmoryPages.upgrades(self, _page_box)
		"habilidades":
			ArmoryPages.skills(self, _page_box)
		"robot":
			_fill_robot_page(_page_box)


## Pagina Pieza: la del hueco elegido y las tuyas que caben en el.
func _fill_part_page(box: VBoxContainer) -> void:
	var id := Garage.get_slot(main._profile.build, _selected)
	var item := _resolved(id)
	var head := slot_title(_selected) + " · "
	head += item.display_name if item != null else Txt.t("slot_empty")
	_label(box, head, 17).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var locked := _lock_reason(_selected, main._player_level())
	if locked != "":
		_label(box, Txt.t("workshop_locked", [locked]), 14, COLOR_MUTED)
		return
	if item == null:
		_label(box, Txt.t("workshop_empty_hint"), 13, COLOR_MUTED)
	else:
		var stats := _label(box, item_stats(item, false), 13, COLOR_MUTED)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		_add_upgrade_button(row, item)
		if item.deals_damage() and item.fx != "":
			_button(row, Txt.t("workshop_test"), test_fire)
		_button(row, Txt.t("workshop_remove"), clear_slot.bind(_selected))
	box.add_child(HSeparator.new())
	_fill_owned(box, id)
	var to_store := _button(box, Txt.t("workshop_to_store"), show_store.bind(""))
	to_store.custom_minimum_size = Vector2(0, 40)


## Pagina del robot que usas: su nombre, su diseno y desmontarlo.
func _fill_robot_page(box: VBoxContainer) -> void:
	var index := main._profile.active
	_label(box, main.robot_name(index), 18)
	var robot: Dictionary = main._profile.mechs[index]
	var design := str(robot.get("design", ""))
	if main._library.specs.has(design):
		var line := Txt.t("robot_design", [main._library.display_name(design)])
		_label(box, line, 13, COLOR_MUTED)
	var hint := _label(box, Txt.t("robot_page_hint"), 13, COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if main._profile.mechs.size() > 1:
		var remove := _button(box, Txt.t("robots_remove"), main.ask_remove_robot.bind(index))
		remove.custom_minimum_size = Vector2(0, 40)


## Subir de nivel, transformar o el tope que lo para.
func _add_upgrade_button(row: HBoxContainer, item: ItemDef) -> void:
	if item.type == ItemDef.Type.DRONE and main._profile.build.has("assist"):
		return
	var key := item.progress_id()
	var p := main._profile.part(key)
	var max_tier := main._zone_tier()
	var cap_level := main._campaign.level_cap(main._profile.zone)
	var profile := main._profile
	if p["level"] < main._rules.tier_max_level[p["tier"]]:
		var reason := profile.why_cant_level(main._workshop, main._rules, key, max_tier, cap_level)
		var cost := main._workshop.level_cost(main._rules, p["tier"], p["level"])
		var level_up := _button(row, Txt.t("part_level_up", [cost]), level_up_selected)
		level_up.disabled = reason != ""
		level_up.tooltip_text = reason
		if reason == "la zona no deja subirla mas":
			level_up.text = Txt.t("part_zone_max")
		return
	var item_max := main._catalog.get_item(item.id).tier_max
	var why := profile.why_cant_transform(main._workshop, main._rules, key, max_tier, item_max)
	var label := Txt.t("part_transform", [main._workshop.transform_cost(p["tier"])])
	if p["tier"] == ItemDef.Tier.MYTHIC:
		label = Txt.t("part_unique")
	if not why in ["", "faltan celdas"]:
		label = Txt.t("part_zone_max" if why.contains("zona") else "shop_max")
	var transform := _button(row, label, transform_selected)
	transform.disabled = why != ""
	transform.tooltip_text = why


func _fill_owned(box: VBoxContainer, mounted: String) -> void:
	_label(box, Txt.t("workshop_owned"), 14, COLOR_MUTED)
	var owned := Garage.owned_for(main._profile, main._catalog, _selected)
	if owned.is_empty():
		_label(box, Txt.t("workshop_none"), 13, COLOR_MUTED)
	for id in owned:
		var item := _resolved(id)
		var card := PartCard.new()
		card.item = item
		card.mounted = id == mounted
		card.detail = _progress_text(item)
		if card.mounted:
			card.detail += " · " + Txt.t("workshop_mounted")
		card.stats = item_stats(item, false)
		card.chosen.connect(equip_selected)
		card.hovered.connect(hover_item)
		box.add_child(card)


# --- Acciones ----------------------------------------------------------------


## Elige un hueco: se marca en el robot y el cajon ensena su pieza.
func pick(slot: String) -> void:
	if not slot in Garage.SLOTS:
		return
	_selected = slot
	_hover_id = ""
	show_page("pieza")


func _on_part_picked(slot: String) -> void:
	Sfx.play("ui_tic")
	pick(slot)


func _on_bay_pressed(index: int) -> void:
	if index < 0:
		main.open_acquire()
	else:
		main.use_robot(index)


## Monta una pieza en el hueco elegido.
func equip_selected(id: String) -> void:
	equip(_selected, id)


func equip(slot: String, id: String) -> void:
	if _lock_reason(slot, main._player_level()) != "":
		return
	if Garage.equip(main._profile, main._catalog, slot, id) != "":
		return
	_selected = slot
	_hover_id = ""
	main._save()
	Sfx.play("taller_montar")
	if _page == "":
		show_page("pieza")
	else:
		refresh()
	var item := _resolved(id)
	if item != null:
		_stage.flash(slot, SlotCell.TIER_COLORS[item.tier])


## Deja un hueco vacio.
func clear_slot(slot: String) -> void:
	if Garage.get_slot(main._profile.build, slot) == "":
		return
	Garage.equip(main._profile, main._catalog, slot, "")
	_selected = slot
	main._save()
	Sfx.play("taller_quitar")
	refresh()


func level_up_selected() -> void:
	var item := _resolved(Garage.get_slot(main._profile.build, _selected))
	if item == null:
		return
	var cap := main._campaign.level_cap(main._profile.zone)
	var key := item.progress_id()
	if main._profile.level_up(main._workshop, main._rules, key, main._zone_tier(), cap) != "":
		return
	main._save()
	Sfx.play("ui_subir_nivel")
	refresh()
	_stage.flash(_selected, SlotCell.TIER_COLORS[item.tier])


func transform_selected() -> void:
	var item := _resolved(Garage.get_slot(main._profile.build, _selected))
	if item == null:
		return
	var item_max := main._catalog.get_item(item.id).tier_max
	var key := item.progress_id()
	var reason := main._profile.transform(
		main._workshop, main._rules, key, main._zone_tier(), item_max
	)
	if reason != "":
		return
	main._save()
	Sfx.play("ui_transformar")
	refresh()
	var now := _resolved(item.id)
	_stage.flash(_selected, SlotCell.TIER_COLORS[now.tier])


## Compra una pieza de la tienda. Si el hueco donde iria esta vacio, la
## monta; si no, queda en tus piezas.
func buy(id: String) -> void:
	if not _pay(id):
		return
	var slot := _slot_for(id)
	if slot != "" and Garage.get_slot(main._profile.build, slot) == "":
		equip(slot, id)
	else:
		refresh()


func _pay(id: String) -> bool:
	var tier := main._zone_tier()
	if main._garage.buy(main._profile, main._catalog, main._rules, main._workshop, id, tier) != "":
		return false
	Sfx.play("ui_comprar")
	main._save()
	return true


## Hueco donde iria una pieza: el elegido si le cabe, o el primero libre de su
## tipo que tu nivel ya abra.
func _slot_for(id: String) -> String:
	var locked: Array[String] = []
	for slot in Garage.SLOTS:
		if _lock_reason(slot, main._player_level()) != "":
			locked.append(slot)
	return Garage.drop_slot(main._profile.build, main._catalog, id, _selected, locked)


## Sube una de las mejoras permanentes, con el tope de la zona.
func buy_upgrade(track: String) -> void:
	if main._profile.buy(main._shop, track, main._armory_cap()) != "":
		return
	Sfx.play("ui_comprar")
	main._save()
	refresh()


## Aprende la siguiente habilidad de una rama.
func learn(id: String) -> void:
	if main._skills.learn(main._profile, id, main._player_level()) != "":
		return
	Sfx.play("ui_habilidad")
	main._save()
	refresh()


## Una pieza de la tienda elegida: se marca en el robot el hueco donde iria.
func focus_item(id: String) -> void:
	var slot := _slot_for(id)
	if slot == "":
		return
	_selected = slot
	_stage.selected_slot = slot
	_stage.hover_slot = slot


## Dispara el arma del hueco elegido contra la diana.
func test_fire() -> void:
	var item := _resolved(Garage.get_slot(main._profile.build, _selected))
	if item == null or item.fx == "":
		return
	_stage.test_fire(_selected, item.fx, ShotFx.ammo_color(item.element))


## Aviso pasajero arriba (lo que paso en el ultimo combate, por ejemplo).
func toast(text: String) -> void:
	if text == "" or _toast == null:
		return
	_toast.text = text
	_toast.modulate = Color(1, 1, 1, 1)
	var fade := create_tween()
	fade.tween_interval(4.0)
	fade.tween_property(_toast, "modulate:a", 0.0, 1.0)


func _on_cell_dropped(slot: String, data: Dictionary) -> void:
	if data.get("buy", false) and not _pay(data["id"]):
		return
	var from: String = data.get("from_slot", "")
	if from != "":
		# De un hueco a otro de su tipo: se cambian.
		var other := Garage.get_slot(main._profile.build, slot)
		Garage.equip(main._profile, main._catalog, from, other)
	equip(slot, data["id"])


func _on_stage_dropped(data: Dictionary) -> void:
	var slot := _slot_for(data["id"])
	if slot == "":
		return
	if data.get("buy", false) and not _pay(data["id"]):
		return
	equip(slot, data["id"])


## Pasar el raton por una pieza: el resumen ensena cuanto cambia el robot con
## ella en el hueco donde iria, y ese hueco se marca en el dibujo.
func hover_item(id: String, inside: bool) -> void:
	_hover_id = id if inside else ""
	_hover_slot = _slot_for(id) if inside else ""
	_stage.hover_slot = _hover_slot
	_refresh_summary(_build_from(main._profile.build))


func _on_cell_hovered(slot: String, inside: bool) -> void:
	_stage.hover_slot = slot if inside else ""


# --- Textos ------------------------------------------------------------------


## Nombre de un hueco: "Lateral 1", "Torso"...
static func slot_title(slot: String) -> String:
	var base := slot.rstrip("0123456789")
	var digits := slot.trim_prefix(base)
	var number := " %d" % (int(digits) + 1) if digits != "" else ""
	return Txt.t("slot_" + base) + number


## Lo que hace una pieza, en una linea (o en varias con `long`).
static func item_stats(item: ItemDef, long: bool) -> String:
	var parts: Array[String] = []
	if item.deals_damage():
		parts.append(Txt.t("stat_damage", [item.dmg_min, item.dmg_max]))
		parts.append(Txt.t("range", [item.range_min, item.range_max]))
		if item.energy_cost > 0:
			parts.append(Txt.t("cost_energy", [item.energy_cost]))
		if item.heat_cost > 0:
			parts.append(Txt.t("cost_heat", [item.heat_cost]))
		if item.uses > 0:
			parts.append(Txt.t("uses", [item.uses]))
	for key in ["health", "energy_cap", "energy_regen", "heat_cap", "cooling"]:
		var value: int = item.get(key)
		if value != 0:
			parts.append("%s %+d" % [Txt.t("stat_" + key), value])
	var res := [item.res_physical, item.res_heat, item.res_energy]
	if res.max() > 0:
		parts.append("%s %d/%d/%d" % [Txt.t("resist"), res[0], res[1], res[2]])
	if item.weight > 0:
		parts.append(Txt.t("stat_weight", [item.weight]))
	return ("\n" if long else " · ").join(parts)


func _label(parent: Node, text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
