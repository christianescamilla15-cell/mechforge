class_name SlotCell
extends PanelContainer
## Un hueco del taller (WorkshopScreen): la pieza montada, con su dibujo, su
## nombre, su clase y su nivel, o vacio. Se pulsa para elegirlo; acepta piezas
## arrastradas de su tipo; su pieza se arrastra a otro hueco (se cambian) o
## fuera (se quita); la X lo deja vacio.

signal picked(slot: String)
signal dropped(slot: String, data: Dictionary)
signal cleared(slot: String)
signal hovered(slot: String, inside: bool)

## Color de cada clase, de Basica a Unica.
const TIER_COLORS: Array[Color] = [
	Color("8a94a3"),
	Color("5fd07a"),
	Color("4aa8ff"),
	Color("b77bff"),
	Color("ffae3d"),
	Color("ff5a6e")
]
const COLOR_BACK := Color("141c27")
const COLOR_EMPTY := Color("2a3647")
const COLOR_SELECTED := Color("ffe27a")
const COLOR_DROP := Color("7dff9b")
const COLOR_MUTED := Color("9aa7b8")

var slot: String = ""
var accepts: ItemDef.Type = ItemDef.Type.SIDE
var title: String = ""
var item: ItemDef
## Clase y nivel de la pieza ("Bás 3/6"); "" si no tiene progreso propio.
var progress_text: String = ""
## Por que esta cerrado ("Nivel 10"); "" si esta abierto.
var locked_text: String = ""
var selected: bool = false
var compact: bool = false

var _drop_glow: bool = false
var _icon: TextureRect
var _name: Label
var _detail: Label
var _clear: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(84, 46) if compact else Vector2(110, 84)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	# Cabecera: el nombre del hueco y la X para dejarlo vacio.
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	var head := Label.new()
	head.text = title
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", COLOR_MUTED)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(head)
	_clear = Button.new()
	_clear.text = "×"
	_clear.flat = true
	_clear.focus_mode = Control.FOCUS_NONE
	_clear.custom_minimum_size = Vector2(18, 16)
	_clear.add_theme_font_size_override("font_size", 14)
	_clear.add_theme_constant_override("h_separation", 0)
	_clear.tooltip_text = Txt.t("workshop_clear")
	_clear.pressed.connect(func() -> void: cleared.emit(slot))
	header.add_child(_clear)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(0, 18 if compact else 38)
	_icon.size_flags_vertical = (
		Control.SIZE_SHRINK_CENTER if compact else Control.SIZE_EXPAND_FILL
	)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_icon)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 11)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name)
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 10)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_detail)
	mouse_entered.connect(func() -> void: hovered.emit(slot, true))
	mouse_exited.connect(func() -> void: hovered.emit(slot, false))
	refresh()


## Vuelve a pintar el hueco con su pieza, su estado y si esta elegido.
func refresh() -> void:
	if _name == null:
		return
	_icon.texture = MechSprites.icon_for(item) if item != null else null
	# En los huecos pequenos el dibujo solo ocupa sitio si lo hay.
	_icon.visible = not compact or _icon.texture != null
	_icon.modulate = Color(1, 1, 1, 1) if locked_text == "" else Color(1, 1, 1, 0.3)
	if locked_text != "":
		_name.text = locked_text
		_name.add_theme_color_override("font_color", COLOR_MUTED)
	elif item == null:
		_name.text = Txt.t("slot_empty")
		_name.add_theme_color_override("font_color", COLOR_MUTED)
	else:
		_name.text = item.display_name
		_name.add_theme_color_override("font_color", Color.WHITE)
	_detail.text = progress_text if item != null else ""
	if item != null:
		_detail.add_theme_color_override("font_color", TIER_COLORS[item.tier])
	_detail.visible = not compact or progress_text != ""
	_clear.visible = item != null and locked_text == ""
	tooltip_text = item.display_name if item != null else title
	add_theme_stylebox_override("panel", _style())


func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACK if item != null else COLOR_BACK.darkened(0.3)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	style.set_border_width_all(2)
	style.border_color = TIER_COLORS[item.tier] if item != null else COLOR_EMPTY
	if _drop_glow:
		style.border_color = COLOR_DROP
		style.set_border_width_all(3)
	if selected:
		style.border_color = COLOR_SELECTED
		style.set_border_width_all(3)
		style.shadow_color = Color(COLOR_SELECTED, 0.35)
		style.shadow_size = 6
	return style


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(slot)
		accept_event()


## Arrastrar la pieza montada: a otro hueco de su tipo (se cambian) o fuera.
func _get_drag_data(_at: Vector2) -> Variant:
	if item == null or locked_text != "":
		return null
	set_drag_preview(PartCard.drag_preview(item))
	return {"id": item.id, "type": item.type, "from_slot": slot}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return accepts_data(data)


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(slot, data)


## True si una pieza que se arrastra cabe aqui.
func accepts_data(data: Variant) -> bool:
	if not data is Dictionary or locked_text != "" or not data.has("type"):
		return false
	return int(data["type"]) == accepts and data.get("from_slot", "") != slot


func _notification(what: int) -> void:
	# Mientras se arrastra una pieza, brillan los huecos donde cabe.
	if what == NOTIFICATION_DRAG_BEGIN:
		_drop_glow = accepts_data(get_viewport().gui_get_drag_data())
		refresh()
	elif what == NOTIFICATION_DRAG_END:
		_drop_glow = false
		refresh()
