class_name TeardownTag
extends Control
## La etiqueta flotante de lo elegido en el robot desarmado (OBS-048): un
## holograma junto a la pieza, el sistema o el nucleo, unido a el con una
## linea, que se usa ahi mismo, sin pantalla. Del usuario: "las ranuras de
## mejora son lo que van entre cada fase... y la evolucion es lo que pasa
## despues de que ya terminas alguna fase".
## - pieza: su nombre, su fase y nivel, las ranuras que quedan hasta la fase
##   siguiente, la tecla para subirla (o transformarla, o evolucionarla) y la
##   de cambiarla;
## - sistema (una mejora permanente): sus diez niveles, lo que da y la tecla
##   para subirlo;
## - nucleo: las tres ramas de habilidades, con la siguiente de cada una;
## - aspectos de una pieza (OBS-051): una fila por aspecto con sus diez
##   niveles, lo que da y su precio; pulsar la fila sube un nivel.
## Solo ensena y dice que tecla hay bajo el raton (key_at).

const GOLD := Color("ffd36b")
const LINE := Color("3fd0e6")
const TEXT := Color("bfefff")
const MUTED := Color("7fb5c4")
const BAD := Color("ff7d6b")
const GOOD := Color("7dff9b")
const PANEL := Color(0.03, 0.09, 0.12, 0.88)
const WIDTH := 300.0
## Los aspectos llevan mas texto por fila: su etiqueta es mas ancha.
const ASPECT_WIDTH := 380.0
const PAD := 12.0
const KEY_HEIGHT := 30.0
const GAP := 26.0
const GROW_SECONDS := 0.18
const ASPECT_ROW := 44.0

## Lo que ensena: {"kind" ("piece", "system" o "skills"), "title", ...}.
var state: Dictionary = {}
## Lo que senala, en pixeles del padre.
var target := Rect2()
var hover_key: String = ""

var _box := Rect2()
var _keys: Dictionary[String, Rect2] = {}
var _font: Font
var _open := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()


func show_tag(p_state: Dictionary, p_target: Rect2) -> void:
	var fresh := not visible or str(p_state.get("title", "")) != str(state.get("title", ""))
	state = p_state
	target = p_target
	visible = true
	if fresh:
		_open = 0.0
	queue_redraw()


func hide_tag() -> void:
	visible = false
	state = {}
	hover_key = ""
	_keys.clear()


func is_open() -> bool:
	return visible and not state.is_empty()


## La tecla en ese punto ("" si ninguna).
func key_at(at: Vector2) -> String:
	if not is_open():
		return ""
	for key: String in _keys:
		if _keys[key].has_point(at):
			return key
	return ""


## True si el punto cae en la etiqueta (para que no cuente como fondo).
func has_point(at: Vector2) -> bool:
	return is_open() and _box.has_point(at)


func _process(delta: float) -> void:
	if visible and _open < 1.0:
		_open = minf(1.0, _open + delta / GROW_SECONDS)
		queue_redraw()


func _draw() -> void:
	_keys.clear()
	if not is_open():
		return
	var height := _height()
	_box = _place(height)
	var right := _box.position.x >= target.get_center().x
	var shown := Rect2(_box.position, Vector2(_box.size.x, _box.size.y * _open))
	var edge := Vector2(_box.position.x if right else _box.end.x, _box.position.y + 22.0)
	var aim := Vector2(target.end.x if right else target.position.x, target.get_center().y)
	if _box.position.y >= target.end.y:
		edge = Vector2(_box.get_center().x, _box.position.y)
		aim = Vector2(target.get_center().x, target.end.y)
	elif _box.end.y <= target.position.y:
		edge = Vector2(_box.get_center().x, _box.end.y)
		aim = Vector2(target.get_center().x, target.position.y)
	draw_line(aim, edge, Color(LINE, 0.7), 1.5)
	draw_circle(aim, 3.5, LINE)
	draw_rect(shown, PANEL)
	draw_rect(shown, Color(LINE, 0.8), false, 1.5)
	draw_rect(Rect2(shown.position, Vector2(shown.size.x, 3.0)), Color(LINE, 0.5))
	if _open < 1.0:
		return
	var at := Vector2(_box.position.x + PAD, _box.position.y + PAD)
	match str(state.get("kind", "")):
		"piece":
			_draw_piece(at)
		"system":
			_draw_system(at)
		"skills":
			_draw_skills(at)
		"aspects":
			_draw_aspects(at)


## Donde va la etiqueta: hacia fuera de lo que senala, sin tapar la
## columna del robot (el torso, el nucleo y las piernas); si no cabe a un
## lado, debajo o encima; y si tampoco, del otro lado, sobre la columna,
## pero nunca encima de lo que senala (los aspectos se ven cambiar en la
## pieza mientras se suben).
func _place(height: float) -> Rect2:
	var middle := Rect2(size.x * 0.36, 0.0, size.x * 0.28, size.y)
	var center := target.get_center()
	var inside := middle.has_point(center)
	var y := clampf(center.y - height * 0.5, 8.0, size.y - height - 8.0)
	var candidates: Array[Rect2] = []
	if inside:
		# Lo del centro, a la derecha, mas alla de los sistemas.
		candidates.append(Rect2(maxf(target.end.x + GAP, middle.end.x), y, _width(), height))
	else:
		var left := center.x < size.x * 0.5
		var side_x := target.position.x - GAP - _width() if left else target.end.x + GAP
		candidates.append(Rect2(side_x, y, _width(), height))
		var x := clampf(center.x - _width() * 0.5, 8.0, size.x - _width() - 8.0)
		candidates.append(Rect2(x, target.end.y + GAP * 0.5, _width(), height))
		candidates.append(Rect2(x, target.position.y - GAP * 0.5 - height, _width(), height))
		var other := target.end.x + GAP if left else target.position.x - GAP - _width()
		candidates.append(Rect2(other, y, _width(), height))
	var room := Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))
	for box in candidates:
		if room.encloses(box) and (inside or not box.intersects(middle)):
			return box
	for box in candidates:
		if room.encloses(box) and not box.intersects(target):
			return box
	var last := candidates[0]
	last.position.x = clampf(last.position.x, 8.0, size.x - _width() - 8.0)
	last.position.y = clampf(last.position.y, 8.0, size.y - height - 8.0)
	return last


func _width() -> float:
	return ASPECT_WIDTH if str(state.get("kind", "")) == "aspects" else WIDTH


func _height() -> float:
	match str(state.get("kind", "")):
		"piece":
			var keys := KEY_HEIGHT + 8.0 if str(state.get("aspects", "")) != "" else 0.0
			return (196.0 if str(state.get("gain", "")) != "" else 176.0) + keys
		"aspects":
			var rows := (state.get("rows", []) as Array).size()
			return 58.0 + ASPECT_ROW * rows + KEY_HEIGHT + PAD
		"system":
			return 150.0 + (KEY_HEIGHT + 8.0 if state.has("tree") else 0.0)
		"skills":
			return 64.0 + 58.0 * (state.get("branches", []) as Array).size()
	return 100.0


func _line(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := _width() - PAD * 2.0
	var base := at + Vector2(0.0, font_size)
	draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)


func _draw_piece(at: Vector2) -> void:
	_line(at, str(state.get("title", "")), 17, GOLD)
	_line(at + Vector2(0.0, 24.0), str(state.get("phase", "")), 13, TEXT)
	# Las ranuras de mejora hasta la fase siguiente.
	var slots := int(state.get("slots", 0))
	var filled := int(state.get("filled", 0))
	var row := Vector2(at.x, at.y + 50.0)
	if slots > 0:
		var cell := minf(18.0, (_width() - PAD * 2.0 - 70.0) / slots)
		for i in slots:
			var pip := Rect2(row + Vector2(cell * i, 0.0), Vector2(cell - 3.0, 12.0))
			draw_rect(pip, GOLD if i < filled else Color(MUTED, 0.25))
		var next := str(state.get("next", ""))
		if next != "":
			var end := row + Vector2(cell * slots + 6.0, -2.0)
			var text_at := end + Vector2(0.0, 13.0)
			draw_string(_font, text_at, "> " + next, HORIZONTAL_ALIGNMENT_LEFT, 90.0, 12, MUTED)
	var reason := str(state.get("reason", ""))
	if reason != "":
		_line(at + Vector2(0.0, 70.0), reason, 12, BAD)
	var gain := str(state.get("gain", ""))
	var y := at.y + 92.0
	if gain != "":
		_line(Vector2(at.x, at.y + 86.0), gain, 12, MUTED)
		y += 20.0
	var upgrade := str(state.get("upgrade", ""))
	if upgrade != "":
		var can := bool(state.get("can", false))
		_key("upgrade", Rect2(at.x, y, _width() - PAD * 2.0, KEY_HEIGHT), upgrade, can)
	var change := str(state.get("change", ""))
	if change != "":
		var below := Rect2(at.x, y + KEY_HEIGHT + 8.0, _width() - PAD * 2.0, KEY_HEIGHT)
		_key("change", below, change, true)
	# Sus aspectos (OBS-051): la tecla que abre sus filas aqui mismo.
	var aspects := str(state.get("aspects", ""))
	if aspects != "":
		var third := Rect2(at.x, y + (KEY_HEIGHT + 8.0) * 2.0, _width() - PAD * 2.0, KEY_HEIGHT)
		_key("aspects", third, aspects, true)


## Los aspectos de una pieza (OBS-051): cada fila es una tecla que sube un
## nivel; lleva el nombre, sus diez niveles, lo que da y el precio.
func _draw_aspects(at: Vector2) -> void:
	_line(at, str(state.get("title", "")), 17, GOLD)
	_line(at + Vector2(0.0, 24.0), str(state.get("info", "")), 12, TEXT)
	var y := at.y + 46.0
	var width := _width() - PAD * 2.0
	for row: Dictionary in state.get("rows", []):
		var rect := Rect2(at.x, y, width, ASPECT_ROW - 6.0)
		_aspect_row(rect, row)
		y += ASPECT_ROW
	_key("aspects_back", Rect2(at.x, y, width, KEY_HEIGHT), str(state.get("back", "")), true)


func _aspect_row(rect: Rect2, row: Dictionary) -> void:
	var key := "aspect:" + str(row["id"])
	var can := bool(row["can"])
	var full := bool(row["full"])
	_keys[key] = rect
	var hot := key == hover_key and can
	var tone := GOLD if can or full else MUTED
	draw_rect(rect, Color(tone, 0.2 if hot else 0.07))
	draw_rect(rect, Color(tone, 0.8 if can else 0.35), false, 1.0)
	var inner := rect.grow(-6.0)
	var level := int(row["level"])
	var title := "%s  %d/%d" % [row["name"], level, int(row["max"])]
	var top := inner.position + Vector2(0.0, 12.0)
	draw_string(_font, top, title, HORIZONTAL_ALIGNMENT_LEFT, inner.size.x * 0.66, 13, TEXT)
	var price := Txt.t("aspect_full") if full else str(row["cost"])
	var price_tone := GOOD if full else (GOLD if can else BAD)
	draw_string(_font, top, price, HORIZONTAL_ALIGNMENT_RIGHT, inner.size.x, 12, price_tone)
	var top_level := maxi(int(row["max"]), 1)
	var cell := inner.size.x * 0.5 / top_level
	for i in top_level:
		var pip := Rect2(inner.position + Vector2(cell * i, 16.0), Vector2(cell - 2.0, 5.0))
		draw_rect(pip, GOLD if i < level else Color(MUTED, 0.25))
	var text_at := inner.position + Vector2(inner.size.x * 0.5 + 6.0, 22.0)
	var room := inner.size.x * 0.5 - 6.0
	draw_string(_font, text_at, str(row["text"]), HORIZONTAL_ALIGNMENT_LEFT, room, 10, MUTED)


func _draw_system(at: Vector2) -> void:
	_line(at, str(state.get("title", "")), 17, GOLD)
	_line(at + Vector2(0.0, 24.0), str(state.get("value", "")), 13, TEXT)
	var top := maxi(int(state.get("max", 10)), 1)
	var level := int(state.get("level", 0))
	var cell := (_width() - PAD * 2.0) / top
	for i in top:
		var pip := Rect2(at + Vector2(cell * i, 50.0), Vector2(cell - 3.0, 12.0))
		draw_rect(pip, GOLD if i < level else Color(MUTED, 0.25))
	var gain := str(state.get("gain", ""))
	if gain != "":
		_line(at + Vector2(0.0, 68.0), gain, 12, MUTED)
	var label := str(state.get("label", ""))
	if label != "":
		var can := str(state.get("state", "")) == "ok"
		_key("buy", Rect2(at.x, at.y + 92.0, _width() - PAD * 2.0, KEY_HEIGHT), label, can)
	# Al nivel 10, su rama del arbol de mejoras (OBS-051).
	if state.has("tree"):
		var below := at.y + 92.0 + KEY_HEIGHT + 8.0
		_key("tree", Rect2(at.x, below, _width() - PAD * 2.0, KEY_HEIGHT), str(state["tree"]), true)


func _draw_skills(at: Vector2) -> void:
	_line(at, str(state.get("title", "")), 17, GOLD)
	_line(at + Vector2(0.0, 24.0), str(state.get("info", "")), 12, TEXT)
	var y := at.y + 50.0
	for branch: Dictionary in state.get("branches", []):
		var done := int(branch.get("done", 0))
		var nodes: Array = branch["nodes"]
		_line(Vector2(at.x, y), "%s  %d/%d" % [branch["name"], done, nodes.size()], 13, TEXT)
		var cell := (_width() - PAD * 2.0) / maxf(nodes.size(), 1.0)
		for i in nodes.size():
			var node: Dictionary = nodes[i]
			var pip := Rect2(Vector2(at.x + cell * i, y + 20.0), Vector2(cell - 3.0, 8.0))
			var lit := str(node["state"]) == "done"
			draw_rect(pip, GOLD if lit else Color(MUTED, 0.25))
		if done < nodes.size():
			var next: Dictionary = nodes[done]
			var can := str(next.get("reason", "")) == ""
			var key := Rect2(Vector2(at.x, y + 32.0), Vector2(_width() - PAD * 2.0, 22.0))
			_key("learn:" + str(next["id"]), key, "%s · %s" % [next["name"], next["text"]], can, 12)
		y += 58.0


func _key(key: String, rect: Rect2, label: String, enabled: bool, font_size: int = 14) -> void:
	_keys[key] = rect
	var hot := key == hover_key and enabled
	var color := GOLD if enabled else MUTED
	draw_rect(rect, Color(color, 0.22 if hot else 0.1))
	draw_rect(rect, Color(color, 0.9 if enabled else 0.4), false, 1.5)
	draw_string(
		_font,
		rect.position + Vector2(0.0, rect.size.y * 0.5 + font_size * 0.36),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		font_size,
		color
	)
