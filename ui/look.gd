class_name Look
extends RefCounted
## Tema de toda la interfaz (pedido del usuario el 2026-11-18: "todos los
## componentes con especial detalle y profundidad"): botones, listas, menus,
## paneles, pestanas, barras y deslizadores con las placas en relieve de
## TechStyle. MainScreen lo pone en la raiz y lo hereda todo.

const TEXT := Color("dce6f2")
const TEXT_DIM := Color("6b7787")
const ACCENT := Color("5f7fa6")


static func theme() -> Theme:
	var t := Theme.new()
	for type: String in ["Button", "OptionButton", "MenuButton", "CheckButton"]:
		_button_styles(t, type)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color("ffe7a3"))
		t.set_color("font_disabled_color", type, TEXT_DIM)
		t.set_color("font_focus_color", type, TEXT)
	t.set_color("font_color", "Label", TEXT)
	var panel := TechStyle.plate(Color("19222f"), Color("3c4c62"), 8.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	var popup := TechStyle.plate(Color("161e2a"), ACCENT, 6.0, 6.0)
	popup.bolts = false
	popup.groove = false
	t.set_stylebox("panel", "PopupMenu", popup)
	var popup_hover := TechStyle.plate(Color("2a3b57"), Color("8fb3e0"), 4.0, 4.0)
	popup_hover.bolts = false
	popup_hover.groove = false
	popup_hover.shadow = 0.0
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_stylebox("panel", "TooltipPanel", popup)
	# Pestanas: la elegida, en relieve y con borde claro; las otras, hundidas.
	var tab_on := TechStyle.plate(Color("26354b"), Color("ffd36b"), 6.0, 6.0)
	tab_on.bolts = false
	tab_on.groove = false
	var tab_off := TechStyle.plate(Color("161e2a"), Color("33435a"), 6.0, 6.0)
	tab_off.bolts = false
	tab_off.groove = false
	tab_off.sunken = true
	t.set_stylebox("tab_selected", "TabContainer", tab_on)
	t.set_stylebox("tab_unselected", "TabContainer", tab_off)
	t.set_stylebox("tab_hovered", "TabContainer", tab_off)
	t.set_stylebox("panel", "TabContainer", panel)
	# Barras: un canal hundido y un relleno con brillo.
	var trough := TechStyle.plate(Color("0f151e"), Color("2a3546"), 0.0, 3.0)
	trough.bolts = false
	trough.groove = false
	trough.sunken = true
	trough.shadow = 0.0
	var fill := TechStyle.plate(Color("3f86c8"), Color("8fd0ff"), 0.0, 3.0)
	fill.bolts = false
	fill.groove = false
	fill.shadow = 0.0
	t.set_stylebox("background", "ProgressBar", trough)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_stylebox("slider", "HSlider", trough)
	var grabbed := fill.duplicate()
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", grabbed)
	return t


## Los cuatro estados de un boton con placas: normal, encima (brilla),
## pulsado (hundido) y desactivado (apagado y sin sombra).
static func _button_styles(t: Theme, type: String) -> void:
	var normal := TechStyle.plate(Color("223047"), ACCENT, 7.0, 6.0)
	normal.bolts = false
	normal.groove = false
	var hover := TechStyle.plate(Color("2a3b57"), ACCENT.lightened(0.3), 7.0, 6.0)
	hover.bolts = false
	hover.groove = false
	hover.glow = 0.35
	var pressed := TechStyle.plate(Color("17202f"), ACCENT, 7.0, 6.0)
	pressed.bolts = false
	pressed.groove = false
	pressed.sunken = true
	var off := TechStyle.plate(Color("1a212c"), Color("33404f"), 7.0, 6.0)
	off.bolts = false
	off.groove = false
	off.shadow = 1.0
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, off)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
