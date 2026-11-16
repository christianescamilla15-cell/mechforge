class_name ArenaView
extends Control
## La arena: una fila de casillas con los dos mechs encima. Solo dibuja y
## avisa de los clics; no conoce las reglas.

signal cell_clicked(cell: int)
signal cell_hovered(cell: int)

const FLOOR_Y := 250.0
const CELL_HEIGHT := 46.0
const COLOR_CELL := Color("1c2633")
const COLOR_CELL_LINE := Color("3a4a5e")
const COLOR_FLOOR := Color("0e141c")

var cells: int = 10
var mechs: Array[MechView] = []

## Casillas resaltadas: {indice: color}.
var _highlights: Dictionary = {}
var _hovered: int = -1
## Textos flotantes vivos por casilla, para no encimarlos.
var _floating: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in 2:
		var view := MechView.new()
		add_child(view)
		mechs.append(view)
	mouse_exited.connect(_on_mouse_exited)


func cell_width() -> float:
	return size.x / cells


## Punto del suelo en el centro de una casilla.
func cell_point(cell: int) -> Vector2:
	return Vector2((cell + 0.5) * cell_width(), FLOOR_Y)


func set_highlights(highlights: Dictionary) -> void:
	_highlights = highlights
	queue_redraw()


## Hace que los dos mechs se miren.
func update_facing() -> void:
	var left := 0 if mechs[0].position.x <= mechs[1].position.x else 1
	mechs[left].set_facing(1)
	mechs[1 - left].set_facing(-1)


## Numero que sube y se desvanece sobre una casilla (dano, calor...).
func float_text(cell: int, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	# Cada texto nuevo sobre la misma casilla sale un poco mas abajo.
	var row: int = _floating.get(cell, 0)
	_floating[cell] = row + 1
	label.position = cell_point(cell) + Vector2(-30, -205 + 26 * row)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 1.1)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tween.tween_callback(_on_float_done.bind(label, cell))


func _on_float_done(label: Label, cell: int) -> void:
	label.queue_free()
	_floating[cell] = maxi(0, _floating.get(cell, 1) - 1)


func _draw() -> void:
	var width := cell_width()
	draw_rect(Rect2(0, FLOOR_Y, size.x, CELL_HEIGHT), COLOR_FLOOR)
	for cell in cells:
		var rect := Rect2(cell * width + 3, FLOOR_Y + 3, width - 6, CELL_HEIGHT - 6)
		var color := COLOR_CELL
		if _highlights.has(cell):
			color = _highlights[cell]
			if cell == _hovered:
				color = color.lightened(0.25)
		draw_rect(rect, color)
		draw_rect(rect, COLOR_CELL_LINE, false, 2.0)
		var font := get_theme_default_font()
		draw_string(
			font,
			rect.position + Vector2(rect.size.x / 2.0 - 5.0, 27.0),
			str(cell),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color("8fa3b8")
		)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		if cell != _hovered:
			_hovered = cell
			queue_redraw()
			cell_hovered.emit(cell)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var cell := _cell_at(event.position)
			if cell >= 0:
				cell_clicked.emit(cell)


func _on_mouse_exited() -> void:
	_hovered = -1
	queue_redraw()
	cell_hovered.emit(-1)


func _cell_at(point: Vector2) -> int:
	if point.x < 0 or point.x >= size.x:
		return -1
	return clampi(int(point.x / cell_width()), 0, cells - 1)
