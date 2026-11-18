class_name StatPanel
extends PanelContainer
## Panel de un mech: nombre y barras de vida, calor y energia.

const COLOR_HEALTH := Color("4cd964")
const COLOR_HEAT := Color("ff6b3d")
const COLOR_ENERGY := Color("3dc8ff")

var _name_label: Label
var _detail_label: Label
var _bars: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(380, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_name_label)
	_add_bar(box, "health", Txt.t("health"), COLOR_HEALTH)
	_add_bar(box, "heat", Txt.t("heat"), COLOR_HEAT)
	_add_bar(box, "energy", Txt.t("energy"), COLOR_ENERGY)
	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.add_theme_color_override("font_color", Color("9fb0c3"))
	box.add_child(_detail_label)


func set_title(text: String) -> void:
	_name_label.text = text


## Actualiza las barras con la foto de estado de un evento del motor.
func show_state(state: Dictionary, max_health: int) -> void:
	_set_bar("health", state["health"], max_health)
	_set_bar("heat", state["heat"], state["heat_cap"])
	_set_bar("energy", state["energy"], state["energy_cap"])
	var res: Array = state["res"]
	var detail := "%s: %d / %d / %d" % [Txt.t("resist"), res[0], res[1], res[2]]
	# Ventajas en vigor (GDD 2.8): que da cada una y cuantos turnos le quedan.
	for buff: Dictionary in state.get("buffs", []):
		var percent := roundi(float(buff["amount"]) * 100.0)
		var short := Txt.t("drop_%s_short" % buff["kind"])
		detail += "  ·  +%d %% %s (%d)" % [percent, short, buff["turns"]]
	# Efectos de un critico que sufre en su turno (GDD 2.9).
	if state.get("immobilized", false):
		detail += "  ·  %s" % Txt.t("status_immobilized")
	if str(state.get("disabled", "")) != "":
		detail += "  ·  %s" % Txt.t("status_disabled")
	if state.get("stunned", false):
		detail += "  ·  %s" % Txt.t("status_stunned")
	_detail_label.text = detail


func _add_bar(box: VBoxContainer, key: String, title: String, color: Color) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var caption := Label.new()
	caption.text = title
	caption.custom_minimum_size = Vector2(70, 0)
	caption.add_theme_font_size_override("font_size", 14)
	row.add_child(caption)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 20)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("111821")
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	var value := Label.new()
	value.custom_minimum_size = Vector2(96, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 14)
	row.add_child(value)
	_bars[key] = [bar, value]


func _set_bar(key: String, current: int, maximum: int) -> void:
	var bar: ProgressBar = _bars[key][0]
	var label: Label = _bars[key][1]
	bar.max_value = maxi(maximum, 1)
	# El calor puede pasar del tope: la barra se queda llena y el numero lo dice.
	bar.value = clampi(current, 0, maximum)
	label.text = "%d / %d" % [maxi(current, 0), maximum]
	if key == "heat":
		label.add_theme_color_override(
			"font_color", Color("ff5a4d") if current > maximum else Color.WHITE
		)
