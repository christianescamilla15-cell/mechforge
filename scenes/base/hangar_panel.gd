class_name HangarPanel
extends VBoxContainer
## Tus robots, en la base (GDD 8, garaje; pedido del usuario el 2026-11-18):
## el que usas en grande con sus estadisticas y la entrada al taller, y
## debajo los 3 espacios del garaje: tus otros robots (un clic y pasas a
## usarlo; la X lo desmonta) o "Adquirir robot" en los vacios. En total, 4.

const COLOR_MUTED := Color("9aa7b8")
const COLOR_CELLS := Color("7fe3ff")
const COLOR_ACTIVE := Color("ffd36b")
const COLOR_FRAME := Color("5f7fa6")
const STATS: Array[String] = ["health", "energy_cap", "heat_cap", "res", "weight"]

var main: MainScreen


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var profile := main._profile
	var head := HBoxContainer.new()
	add_child(head)
	var title := _label(head, Txt.t("robots_title"), 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(
		head, Txt.t("robots_count", [profile.mechs.size(), main._rules.max_mechs]), 15, COLOR_MUTED
	)
	var cells := _label(self, Txt.t("menu_gold", [profile.gold]), 20, COLOR_CELLS)
	cells.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if profile.unique_cores > 0:
		_label(self, Txt.t("menu_cores", [profile.unique_cores]), 16, COLOR_CELLS)
	_add_active()
	var enter := Button.new()
	enter.text = Txt.t("workshop_enter")
	enter.custom_minimum_size = Vector2(0, 48)
	enter.add_theme_font_size_override("font_size", 19)
	TechStyle.dress_button(enter, COLOR_ACTIVE)
	enter.pressed.connect(main.open_workshop)
	add_child(enter)
	_label(self, Txt.t("robots_garage"), 15, COLOR_MUTED)
	var garage := HBoxContainer.new()
	garage.add_theme_constant_override("separation", 8)
	add_child(garage)
	var others: Array[int] = []
	for i in profile.mechs.size():
		if i != profile.active:
			others.append(i)
	for i in main._rules.max_mechs - 1:
		if i < others.size():
			garage.add_child(_robot_card(others[i]))
		else:
			garage.add_child(_acquire_card())


## El robot que usas: su dibujo, su nombre y sus estadisticas.
func _add_active() -> void:
	var plate := PanelContainer.new()
	var style := TechStyle.plate(Color("17202e"), COLOR_ACTIVE, 10.0)
	style.glow = 0.4
	plate.add_theme_stylebox_override("panel", style)
	add_child(plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	plate.add_child(box)
	var index := main._profile.active
	var row := HBoxContainer.new()
	box.add_child(row)
	var name_label := _label(row, main.robot_name(index), 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(row, Txt.t("robots_in_use"), 13, COLOR_ACTIVE)
	var build := main._robot_build(main._profile.build)
	if build.torso == null or build.legs == null:
		var missing := _label(box, Txt.t("hangar_missing"), 15, Color("ff9a7d"))
		missing.custom_minimum_size = Vector2(0, 120)
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var stage := MechStage.new()
	stage.preview = true
	stage.custom_minimum_size = Vector2(0, 232)
	box.add_child(stage)
	stage.show_build(build, [])
	box.add_child(_stats_strip(build, 14))


## Estadisticas de un robot en una fila: vida, energia, calor, resistencias y
## peso.
func _stats_strip(build: MechBuild, font_size: int) -> GridContainer:
	var s := build.summary(main._rules)
	var grid := GridContainer.new()
	grid.columns = STATS.size()
	grid.add_theme_constant_override("h_separation", 12)
	for key in STATS:
		_label(grid, Txt.t("robot_stat_" + key), font_size - 3, COLOR_MUTED)
	for key in STATS:
		var value := str(s.get(key, 0))
		if key == "res":
			value = "%d/%d/%d" % [s["res_physical"], s["res_heat"], s["res_energy"]]
		_label(grid, value, font_size)
	return grid


## Uno de tus otros robots, en el garaje.
func _robot_card(index: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = Txt.t("robots_use_hint")
	var style := TechStyle.plate(Color("1a2433"), COLOR_FRAME, 6.0, 7.0)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var name_label := _label(row, main.robot_name(index), 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	var remove := Button.new()
	remove.text = "×"
	remove.flat = true
	remove.focus_mode = Control.FOCUS_NONE
	remove.tooltip_text = Txt.t("robots_remove")
	remove.pressed.connect(main.ask_remove_robot.bind(index))
	row.add_child(remove)
	var spec: Dictionary = main._profile.mechs[index]["build"]
	var build := main._robot_build(spec)
	if build.torso == null or build.legs == null:
		var empty := _label(box, Txt.t("robots_frame"), 13, COLOR_MUTED)
		empty.custom_minimum_size = Vector2(0, 84)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		var stage := MechStage.new()
		stage.preview = true
		stage.custom_minimum_size = Vector2(0, 84)
		box.add_child(stage)
		stage.show_build(build, [])
		var s := build.summary(main._rules)
		var line := Txt.t("robots_card_stats", [s["health"], s["weight"]])
		_label(box, line, 11, COLOR_MUTED)
	card.gui_input.connect(
		func(event: InputEvent) -> void:
			var click := event as InputEventMouseButton
			if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
				main.use_robot(index)
	)
	return card


## Un espacio vacio del garaje: adquirir un robot.
func _acquire_card() -> Control:
	var button := Button.new()
	button.text = Txt.t("robots_acquire")
	button.custom_minimum_size = Vector2(0, 150)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_MUTED)
	TechStyle.dress_button(button, Color("3d4c60"))
	button.pressed.connect(main.open_acquire)
	return button


func _label(parent: Node, text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
