class_name PartCard
extends PanelContainer
## Una pieza en el inventario o la tienda del taller (WorkshopScreen): su
## dibujo, su nombre, su clase y nivel y lo que hace. Las tuyas se pulsan o se
## arrastran al hueco o al mech; las de la tienda se compran con su boton.

signal chosen(id: String)
signal hovered(id: String, inside: bool)
signal bought(id: String)

const COLOR_BACK := Color("18212e")
const COLOR_MUTED := Color("9aa7b8")
const COLOR_MOUNTED := Color("ffe27a")

var item: ItemDef
## Clase y nivel ("Bás 3/6") o lo que cueste en la tienda.
var detail: String = ""
## Linea corta con lo que hace (dano, alcance, vida...).
var stats: String = ""
## Montada ya en el hueco elegido.
var mounted: bool = false
## En la tienda: precio y si se puede comprar ("" = se puede).
var price: int = -1
var buy_reason: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 62)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACK
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	style.set_border_width_all(2)
	style.border_color = (
		COLOR_MOUNTED if mounted else SlotCell.TIER_COLORS[item.tier].darkened(0.35)
	)
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon := TextureRect.new()
	icon.texture = MechSprites.icon_for(item)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(62, 48)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_line(text, item.display_name, 14, Color.WHITE)
	_line(text, detail, 12, SlotCell.TIER_COLORS[item.tier])
	_line(text, stats, 11, COLOR_MUTED)
	if price >= 0:
		var buy := Button.new()
		buy.text = Txt.t("store_buy", [price])
		buy.disabled = buy_reason != ""
		buy.tooltip_text = buy_reason
		buy.custom_minimum_size = Vector2(112, 0)
		buy.pressed.connect(func() -> void: bought.emit(item.id))
		row.add_child(buy)
	mouse_entered.connect(func() -> void: hovered.emit(item.id, true))
	mouse_exited.connect(func() -> void: hovered.emit(item.id, false))


func _line(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and price < 0:
		chosen.emit(item.id)
		accept_event()


## Las tuyas se arrastran al hueco o sobre el mech.
func _get_drag_data(_at: Vector2) -> Variant:
	if price >= 0:
		return null
	set_drag_preview(drag_preview(item))
	return {"id": item.id, "type": item.type}


## Lo que se ve bajo el raton mientras se arrastra una pieza: su dibujo.
static func drag_preview(def: ItemDef) -> Control:
	var holder := Control.new()
	var icon := TextureRect.new()
	icon.texture = MechSprites.icon_for(def)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(110, 80)
	icon.position = Vector2(-55, -40)
	icon.modulate = Color(1, 1, 1, 0.85)
	holder.add_child(icon)
	if icon.texture == null:
		var label := Label.new()
		label.text = def.display_name
		label.position = Vector2(-40, -10)
		holder.add_child(label)
	return holder
