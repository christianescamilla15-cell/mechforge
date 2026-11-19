class_name AcquirePanel
extends Control
## Adquirir un robot (pedido del usuario el 2026-11-18): un armazon vacio,
## gratis, que se arma en el taller con tus piezas, o uno de los 4 disenos ya
## armado, pagando solo las piezas que aun no tienes al precio de la tienda de
## tu zona. Se abre encima de la base y se cierra con el boton o con Esc.

const COLOR_DIM := Color(0, 0, 0, 0.6)
const COLOR_MUTED := Color("9aa7b8")
const COLOR_CELLS := Color("7fe3ff")
const COLOR_ACCENT := Color("ffd36b")

var main: MainScreen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play("ui_abrir")
	var dim := ColorRect.new()
	dim.color = COLOR_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	var style := TechStyle.plate(Color("161f2c"), COLOR_ACCENT, 16.0, 12.0)
	style.glow = 0.3
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := _label(head, Txt.t("acquire_title"), 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(head, Txt.t("menu_gold", [main._profile.gold]), 16, COLOR_CELLS)
	var why := main._profile.why_cant_add_mech(main._rules)
	_frame_row(box, why)
	var tier := main._zone_tier()
	for design in main._library.starter_ids():
		_design_row(box, design, tier)
	var close := Button.new()
	close.text = Txt.t("settings_close")
	close.custom_minimum_size = Vector2(0, 40)
	TechStyle.dress_button(close)
	close.pressed.connect(close_panel)
	box.add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func close_panel() -> void:
	Sfx.play("ui_cerrar")
	queue_free()


func _frame_row(box: VBoxContainer, why: String) -> void:
	var row := _row(box)
	var icon := _label(row, "", 13)
	icon.custom_minimum_size = Vector2(150, 96)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_label(text, Txt.t("acquire_frame"), 18)
	var hint := _label(text, Txt.t("acquire_frame_hint"), 13, COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var take := _buy_button(row, Txt.t("acquire_free"), why)
	take.pressed.connect(main.acquire_frame)


func _design_row(box: VBoxContainer, design: String, tier: int) -> void:
	var main_ref := main
	var row := _row(box)
	var stage := MechStage.new()
	stage.preview = true
	stage.custom_minimum_size = Vector2(150, 96)
	row.add_child(stage)
	var build := main_ref._robot_build(main_ref._library.specs[design]["items"])
	stage.show_build(build, [])
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	_label(text, main_ref._library.display_name(design), 18)
	var missing := Garage.missing_parts(main_ref._profile, main_ref._library, design)
	var line := Txt.t("acquire_design_hint", [main_ref._element_name(design), missing.size()])
	_label(text, line, 13, COLOR_MUTED)
	var price := main_ref._garage.design_price(
		main_ref._profile,
		main_ref._library,
		main_ref._catalog,
		main_ref._rules,
		main_ref._workshop,
		design,
		tier
	)
	var why := main_ref._garage.why_cant_buy_design(
		main_ref._profile,
		main_ref._library,
		main_ref._catalog,
		main_ref._rules,
		main_ref._workshop,
		design,
		tier
	)
	var label := Txt.t("store_buy", [price]) if price > 0 else Txt.t("acquire_free")
	var buy := _buy_button(row, label, why)
	buy.pressed.connect(main_ref.acquire_design.bind(design))


func _row(box: VBoxContainer) -> HBoxContainer:
	var plate := PanelContainer.new()
	var style := TechStyle.plate(Color("1c2737"), Color("44566e"), 8.0, 8.0)
	style.groove = false
	plate.add_theme_stylebox_override("panel", style)
	box.add_child(plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	plate.add_child(row)
	return row


func _buy_button(row: HBoxContainer, text: String, why: String) -> Button:
	var button := Button.new()
	button.text = text if why == "" else Txt.t("acquire_why_" + _why_key(why))
	button.tooltip_text = why
	button.disabled = why != ""
	button.custom_minimum_size = Vector2(150, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	TechStyle.dress_button(button, COLOR_ACCENT)
	row.add_child(button)
	return button


static func _why_key(why: String) -> String:
	if why.begins_with("ya tienes"):
		return "full"
	if why == "faltan celdas":
		return "cells"
	return "zone"


func _label(parent: Node, text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
