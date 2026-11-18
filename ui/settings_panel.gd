class_name SettingsPanel
extends Control
## Ajustes (GameSettings) sobre lo que haya debajo, en la base y en la pausa
## del combate. Cada cambio se aplica y se guarda al momento. Se cierra con
## el boton o con Esc.

signal changed
signal closed

const COLOR_DIM := Color(0.0, 0.0, 0.0, 0.55)
const COLOR_MUTED := Color("9aa7b8")
const WIDTH := 460.0

var settings: GameSettings
## Donde se guardan los ajustes; vacio = no se guardan (pruebas en vivo).
var save_path: String = GameSettings.PATH


## Abre el panel encima de `parent` y lo devuelve.
static func open(parent: Node, p_settings: GameSettings, p_save_path: String) -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel.settings = p_settings
	panel.save_path = p_save_path
	parent.add_child(panel)
	return panel


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
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	panel.add_theme_stylebox_override("panel", frame_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title(box, Txt.t("settings_title"))

	_label(box, Txt.t("settings_speed"))
	var speed := OptionButton.new()
	for i in GameSettings.SPEEDS.size():
		speed.add_item(Txt.t("settings_speed_%d" % i), i)
	speed.selected = settings.speed_index
	speed.item_selected.connect(_on_speed)
	box.add_child(speed)

	var fullscreen := CheckButton.new()
	fullscreen.text = Txt.t("settings_fullscreen")
	fullscreen.button_pressed = settings.fullscreen
	fullscreen.toggled.connect(_on_fullscreen)
	box.add_child(fullscreen)

	for bus in GameSettings.BUSES:
		_volume_row(box, bus)

	var close := Button.new()
	close.text = Txt.t("settings_close")
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(close_panel)
	box.add_child(close)
	close.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func close_panel() -> void:
	Sfx.play("ui_cerrar")
	closed.emit()
	queue_free()


## Marco de los paneles de la base y del combate.
static func frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("141c27")
	style.border_color = Color("5a6f88")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	return style


func _volume_row(box: VBoxContainer, bus: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var name_label := _label(row, Txt.t("settings_volume_%s" % bus.to_lower()))
	name_label.custom_minimum_size = Vector2(150, 0)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = roundi(settings.volumes[bus] * 100.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := _label(row, "%d %%" % slider.value)
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(_on_volume.bind(bus, value_label))


func _on_speed(index: int) -> void:
	settings.speed_index = index
	_commit()


func _on_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	_commit()


func _on_volume(value: float, bus: String, value_label: Label) -> void:
	settings.volumes[bus] = value / 100.0
	value_label.text = "%d %%" % value
	_commit()


func _commit() -> void:
	settings.apply()
	if save_path != "":
		settings.save_to(save_path)
	changed.emit()


func _title(parent: Node, text: String) -> void:
	var label := _label(parent, text, Color.WHITE, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(parent: Node, text: String, color: Color = Color.WHITE, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
