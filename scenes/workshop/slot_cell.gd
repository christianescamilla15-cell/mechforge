class_name SlotCell
extends Control
## Una cuna del banco de equipo del hangar (HangarStage): un hueco de los
## que no se ven en el dibujo del robot (pecho, especiales, asistente y
## modulos), con su pieza puesta dentro, dibujada, no escrita. Hundida y
## vacia si no lleva nada; con candado si tu nivel aun no la abre. Se pulsa
## para elegir el hueco; acepta piezas arrastradas de su tipo; su pieza se
## arrastra a otra cuna (se cambian) o al panel de piezas (se quita). Al
## pasar el raton ensena en una etiqueta que pieza es.

signal picked(slot: String)
signal dropped(slot: String, data: Dictionary)
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
## Alto de la franja de abajo, con el nombre del hueco.
const LABEL_HEIGHT := 12.0

var slot: String = ""
var accepts: ItemDef.Type = ItemDef.Type.SIDE
var title: String = ""
var item: ItemDef
## Clase y nivel de la pieza ("Bás 3/6"); "" si no tiene progreso propio.
var progress_text: String = ""
## Por que esta cerrado ("Nivel 10"); "" si esta abierto.
var locked_text: String = ""
var selected: bool = false

var _drop_glow: bool = false
var _hover: bool = false
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font = get_theme_default_font()
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	resized.connect(queue_redraw)


func _set_hover(inside: bool) -> void:
	_hover = inside
	hovered.emit(slot, inside)
	queue_redraw()


## Vuelve a pintar la cuna con su pieza, su estado y si esta elegida.
func refresh() -> void:
	queue_redraw()


## Lo que dice su etiqueta: la pieza y su clase, que esta vacia o por que
## esta cerrada.
func tag_lines() -> Array[String]:
	if locked_text != "":
		return [title, locked_text]
	if item == null:
		return [title, Txt.t("slot_empty")]
	return [item.display_name, progress_text]


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_style().draw(get_canvas_item(), rect)
	var well := Rect2(rect.position + Vector2(4, 3), rect.size - Vector2(8, LABEL_HEIGHT + 4.0))
	if locked_text != "":
		# Cerrada: el candado y desde cuando se abre.
		var r := minf(well.size.y * 0.3, 8.0)
		_draw_padlock(Vector2(well.position.x + r + 6.0, well.get_center().y + 1.0), r)
		draw_string(
			_font,
			Vector2(well.position.x + r * 2.0 + 12.0, well.get_center().y + 4.0),
			locked_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			well.size.x - r * 2.0 - 14.0,
			9,
			Color(COLOR_MUTED, 0.75)
		)
	elif item == null:
		# Vacia: la huella de la pieza que falta.
		var mid := well.get_center()
		var arm := minf(well.size.y * 0.24, 7.0)
		var faint := Color(COLOR_MUTED, 0.75 if _hover or _drop_glow else 0.3)
		draw_line(mid - Vector2(arm, 0), mid + Vector2(arm, 0), faint, 1.5)
		draw_line(mid - Vector2(0, arm), mid + Vector2(0, arm), faint, 1.5)
		draw_arc(mid, arm * 1.9, 0, TAU, 20, Color(faint, faint.a * 0.6), 1.0)
	else:
		PartIcon.paint(self, well, item)
	# Abajo, grabado, el nombre del hueco; con pieza, la luz de su clase.
	var label_at := Vector2(5.0, size.y - 3.5)
	var label_color := COLOR_SELECTED if selected else Color(COLOR_MUTED, 0.9 if _hover else 0.62)
	draw_string(
		_font, label_at, title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 14.0, 8, label_color
	)
	if item != null and locked_text == "":
		draw_circle(Vector2(size.x - 7.0, size.y - 7.0), 2.2, TIER_COLORS[item.tier])
	if _hover and not _drop_glow:
		_draw_tag()


## Etiqueta que sale encima al pasar el raton.
func _draw_tag() -> void:
	var lines := tag_lines()
	var wide := 0.0
	for i in lines.size():
		var font_size := 12 if i == 0 else 10
		wide = maxf(
			wide, _font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
	var box := Rect2(0, 0, wide + 16.0, 34.0 if lines[1] != "" else 22.0)
	box.position = Vector2(clampf((size.x - box.size.x) * 0.5, -40.0, 40.0), -box.size.y - 5.0)
	var plate := TechStyle.plate(Color(0.05, 0.09, 0.13, 0.96), Color("3fd0e6"), 0.0, 5.0)
	plate.groove = false
	plate.bolts = false
	plate.draw(get_canvas_item(), box)
	draw_line(
		Vector2(size.x * 0.5, box.end.y), Vector2(size.x * 0.5, 0.0), Color("3fd0e6", 0.7), 1.0
	)
	draw_string(
		_font,
		box.position + Vector2(8, 15),
		lines[0],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color.WHITE
	)
	if lines[1] != "":
		var tone := TIER_COLORS[item.tier] if item != null and locked_text == "" else COLOR_MUTED
		draw_string(
			_font, box.position + Vector2(8, 28), lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tone
		)


func _draw_padlock(at: Vector2, r: float) -> void:
	var color := Color(COLOR_MUTED, 0.55)
	draw_arc(at + Vector2(0, -r * 0.5), r * 0.62, PI, TAU, 12, color, 2.0)
	draw_rect(Rect2(at + Vector2(-r, -r * 0.5), Vector2(r * 2.0, r * 1.6)), color)
	draw_circle(at + Vector2(0, r * 0.3), r * 0.26, COLOR_BACK)


## Placa hundida: el borde del color de la clase de su pieza; brilla verde
## si cabe la pieza que se arrastra y dorada si esta elegida.
func _style() -> TechStyle:
	var accent := TIER_COLORS[item.tier].darkened(0.15) if item != null else COLOR_EMPTY
	var style := TechStyle.plate(
		COLOR_BACK if item != null else COLOR_BACK.darkened(0.3), accent, 0.0, 6.0
	)
	style.groove = false
	style.bolts = false
	style.sunken = true
	style.shadow = 2.0
	if locked_text != "":
		style.accent = COLOR_EMPTY.darkened(0.3)
	elif _hover:
		style.accent = accent.lightened(0.35)
		style.glow = 0.3
	if _drop_glow:
		style.accent = COLOR_DROP
		style.accent_width = 2.5
		style.glow = 0.6
	if selected:
		style.accent = COLOR_SELECTED
		style.accent_width = 2.5
		style.glow = 0.75
	return style


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(slot)
		accept_event()


## Arrastrar la pieza montada: a otra cuna de su tipo (se cambian) o fuera.
func _get_drag_data(_at: Vector2) -> Variant:
	if item == null or locked_text != "":
		return null
	set_drag_preview(PartIcon.drag_preview(item))
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
	# Mientras se arrastra una pieza, brillan las cunas donde cabe.
	if what == NOTIFICATION_DRAG_BEGIN:
		_drop_glow = accepts_data(get_viewport().gui_get_drag_data())
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		_drop_glow = false
		queue_redraw()
