class_name StarterSelect
extends Control
## Partida nueva: los tipos de robot con los que se puede empezar, de pie en
## el hangar, cada uno bajo su foco y con su historia proyectada en el suelo
## (decision del usuario, 2026-11-20: "solo 3 tipos de robot, tipo Metal
## Slug, con 3 historias y 3 estilos"). No hay botones: se pasa el raton por
## un robot y se pulsa dos veces para empezar con el.
## `entries` lo arma WorkshopBrief.starters: [{"id", "role", "name", "story",
## "mechanic", "arms", "kit", "build" (MechBuild)}].

signal chosen(style_id: String)

const REDRAW_SECONDS := 1.0 / 30.0
## Donde pisa cada robot, en fraccion del ancho, y el suelo, del alto.
const SPOTS: Array[float] = [0.19, 0.5, 0.81]
const FLOOR := 0.63
## Alto de un robot en pantalla, en fraccion del alto.
const MECH_HEIGHT := 0.33
const COLUMN := 330.0
const GOLD := Color("ffe27a")
const TEXT := Color("d8f4ff")
const MUTED := Color("8fa9bd")
const BEAM := Color(0.34, 0.83, 1.0)
## Lo que se apagan los robots por los que no pasa el raton.
const IDLE_SHADE := Color(0.5, 0.56, 0.68)

var entries: Array[Dictionary] = []:
	set(value):
		entries = value
		_build_views()
## Historial del jugador, abajo ("" = nada).
var record := ""
var _views: Array[MechView] = []
var _hover := -1
var _armed := -1
var _time := 0.0
var _since_draw := 0.0
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	resized.connect(_layout)
	mouse_exited.connect(_set_hover.bind(-1))
	_build_views()


func _process(delta: float) -> void:
	_time += delta
	_since_draw += delta
	if _since_draw >= REDRAW_SECONDS:
		_since_draw = 0.0
		queue_redraw()


## El robot que espera la segunda pulsacion; -1 si ninguno.
func armed() -> int:
	return _armed


## Sitio en pantalla del robot `index` con su texto: lo que se pulsa.
func spot_rect(index: int) -> Rect2:
	var feet := _feet(index)
	var top := feet.y - size.y * MECH_HEIGHT - 24.0
	return Rect2(feet.x - COLUMN * 0.5, top, COLUMN, size.y - top - 30.0)


## Una pulsacion en el robot `index`: la primera lo arma, la segunda empieza
## la partida con el. Fuera de todos (-1), lo desarma.
func press(index: int) -> void:
	if index < 0 or index >= entries.size():
		_armed = -1
	elif _armed == index:
		chosen.emit(str(entries[index]["id"]))
	else:
		_armed = index
		Sfx.play("ui_abrir")
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(_index_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			press(_index_at(event.position))


func _index_at(at: Vector2) -> int:
	for i in entries.size():
		if spot_rect(i).has_point(at):
			return i
	return -1


func _set_hover(index: int) -> void:
	if index == _hover:
		return
	_hover = index
	if index != _armed:
		_armed = -1
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if index >= 0 else CURSOR_ARROW
	_tint()
	queue_redraw()


func _feet(index: int) -> Vector2:
	var x: float = SPOTS[mini(index, SPOTS.size() - 1)]
	return Vector2(size.x * x, size.y * FLOOR)


func _build_views() -> void:
	if not is_inside_tree():
		return
	for view in _views:
		view.queue_free()
	_views.clear()
	for entry in entries:
		var view := MechView.new()
		add_child(view)
		view.setup(entry["build"], 1)
		_views.append(view)
	_layout()
	_tint()


func _layout() -> void:
	for i in _views.size():
		var view := _views[i]
		view.set_facing(1)
		view.place(_feet(i) - Vector2(0, 3))
		view.scale *= size.y * MECH_HEIGHT / maxf(view.standing_height(), 1.0)
	queue_redraw()


## El robot bajo el raton, a plena luz; los demas, en penumbra.
func _tint() -> void:
	for i in _views.size():
		_views[i].modulate = Color.WHITE if _hover < 0 or i == _hover else IDLE_SHADE


# --- Dibujo ------------------------------------------------------------------


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var floor_y := size.y * FLOOR
	HangarArt.draw_wall(self, rect, floor_y, 1.0)
	HangarArt.draw_gantry(self, rect, 1.0)
	HangarArt.draw_floor(self, rect, floor_y, Vector2(size.x * 0.5, floor_y - size.y * 0.8))
	for i in entries.size():
		var feet := _feet(i)
		var lit := _hover < 0 or i == _hover
		HangarArt.draw_lamp(self, Vector2(feet.x, floor_y * 0.24), 1.1)
		if lit:
			HangarArt.draw_light(self, rect, feet.x, floor_y, _time + i * 3.1)
		HangarArt.draw_platform(self, feet, size.y * MECH_HEIGHT * 0.78)
	HangarArt.draw_vignette(self, rect, 1.3)
	draw_rect(rect, Color(0.02, 0.03, 0.05, 0.22))
	_line(Vector2(0, 42), Txt.t("starter_title"), size.x, 26, TEXT)
	_line(Vector2(0, 64), Txt.t("starter_info"), size.x, 13, MUTED)
	for i in entries.size():
		_draw_entry(i)
	if record != "":
		_line(Vector2(0, size.y - 12.0), record, size.x, 11, Color(MUTED, 0.8))


## Lo que se proyecta en el suelo delante de cada robot: su tipo, su nombre,
## su historia, como pelea y con que empieza.
func _draw_entry(index: int) -> void:
	var entry := entries[index]
	var feet := _feet(index)
	var live := index == _hover
	var fade := 1.0 if _hover < 0 or live else 0.5
	var left := feet.x - COLUMN * 0.5
	var y := feet.y + 44.0
	var accent := GOLD if live else BEAM
	if live:
		_brackets(spot_rect(index).grow_individual(0, 0, 0, -4), GOLD)
	draw_line(Vector2(left + 60, y - 16), Vector2(left + COLUMN - 60, y - 16), Color(accent, 0.5))
	_line(Vector2(left, y), str(entry["role"]).to_upper(), COLUMN, 13, Color(accent, fade))
	y += 26.0
	_line(Vector2(left, y), str(entry["name"]), COLUMN, 24, Color(TEXT, fade))
	y += 20.0
	y = _paragraph(Vector2(left, y), str(entry["story"]), 11, Color(MUTED, fade))
	y += 6.0
	y = _paragraph(Vector2(left, y), str(entry["mechanic"]), 11, Color(TEXT, fade))
	y += 6.0
	_line(Vector2(left, y), str(entry["kit"]), COLUMN, 11, Color(BEAM, fade))
	y += 22.0
	if index == _armed:
		var pulse := 0.6 + 0.4 * sin(_time * 8.0)
		_line(Vector2(left, y), Txt.t("starter_confirm"), COLUMN, 13, Color(GOLD, pulse))
	elif live:
		_line(Vector2(left, y), Txt.t("starter_choose"), COLUMN, 13, GOLD)


## Un parrafo centrado en la columna; devuelve donde acaba.
func _paragraph(at: Vector2, text: String, font_size: int, color: Color) -> float:
	var align := HORIZONTAL_ALIGNMENT_CENTER
	var wrapped := _font.get_multiline_string_size(text, align, COLUMN, font_size)
	draw_multiline_string(
		_font, at + Vector2(1, 1), text, align, COLUMN, font_size, 4, Color(0, 0, 0, 0.6 * color.a)
	)
	draw_multiline_string(_font, at, text, align, COLUMN, font_size, 4, color)
	return at.y + wrapped.y


func _line(at: Vector2, text: String, width: float, font_size: int, color: Color) -> void:
	HangarProps.text(self, _font, at, text, width, font_size, color, true)


## Las cuatro esquinas de un marco.
func _brackets(rect: Rect2, color: Color) -> void:
	var arm := 14.0
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := rect.position + rect.size * corner
		var dx := arm if corner.x == 0.0 else -arm
		var dy := arm if corner.y == 0.0 else -arm
		draw_line(at, at + Vector2(dx, 0), color, 2.0)
		draw_line(at, at + Vector2(0, dy), color, 2.0)
