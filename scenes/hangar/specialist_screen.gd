class_name SpecialistScreen
extends Control
## El banco del especialista, de cerca (GDD 8.6, OBS-043, del usuario: "este
## taller va a ser igual inmersivo"). Crece desde su banco del hangar y deja
## la sala a oscuras. A la izquierda, tus seis piezas que llevan prototipo
## (las dos armas de brazo, la de hombro, la de pecho, el torso y las piernas),
## cada una con el suyo y su rango; en el centro, la elegida bajo la lampara
## (PartShowcase); a la derecha, los prototipos que le caben, con lo que hace
## el rango siguiente y su precio. Comprar pide dos pulsaciones (la primera lo
## deja armado). Abajo habla el especialista, letra a letra.
##
## Ensena un estado (SpecialistBrief.state) y avisa de lo que se pulsa; no
## decide nada.

## Se pulso una de tus piezas.
signal piece_picked(slot: String)
## Se confirmo un prototipo (segunda pulsacion).
signal proto_confirmed(id: String)
signal close_pressed

const GROW_SECONDS := 0.24
const HEAD := 40.0
const LINE_HEIGHT := 24.0
const TYPE_SPEED := 70.0
const GOLD := Color("ffd36b")
const TEXT := Color("eef6ff")
const MUTED := Color("8fa3b8")
const BAD := Color("ff7d6b")
const GOOD := Color("7dff9b")
const PLASMA := Color("7fe8ff")
const LAMP_LINE := Color("ffd9a0")
const ROMAN: Array[String] = ["", "I", "II", "III", "IV", "V"]

var state: Dictionary = {}:
	set(value):
		state = value
		if _armed != "" and not _proto_ids().has(_armed):
			_armed = ""
		queue_redraw()

var _from := Rect2()
var _to := Rect2()
var _open := 0.0:
	set(value):
		_open = value
		position = _from.position.lerp(_to.position, value)
		size = _from.size.lerp(_to.size, value)
		queue_redraw()
var _wanted := false
var _grow: Tween
var _hover := ""
var _armed := ""
var _time := 0.0
var _sparks := 0.0
var _typed := ""
var _typed_at := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = get_theme_default_font()
	mouse_exited.connect(_set_hover.bind(""))


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


# --- Acercarlo y devolverlo -------------------------------------------------------------


func open(p_state: Dictionary, from: Rect2, to: Rect2, instant: bool = false) -> void:
	_from = from
	_to = to
	state = p_state
	if _wanted and visible:
		position = to.position
		size = to.size
		return
	_wanted = true
	visible = true
	_hover = ""
	_armed = ""
	Sfx.play("ui_abrir")
	_tween_open(1.0, 0.0 if instant else GROW_SECONDS)


func close(instant: bool = false) -> void:
	if not _wanted:
		return
	_wanted = false
	_armed = ""
	_tween_open(0.0, 0.0 if instant else GROW_SECONDS * 0.8)


func is_open() -> bool:
	return _wanted


## Chispas sobre la pieza: se acaba de instalar o subir un prototipo.
func celebrate() -> void:
	_armed = ""
	var tween := create_tween()
	tween.tween_property(self, "_sparks", 0.0, 1.1).from(1.0)


func armed_id() -> String:
	return _armed


func _tween_open(to: float, seconds: float) -> void:
	if _grow != null:
		_grow.kill()
	if seconds <= 0.0:
		_open = to
		visible = to > 0.0
		return
	_grow = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_grow.tween_property(self, "_open", to, seconds)
	if to <= 0.0:
		_grow.tween_callback(func() -> void: visible = false)


# --- Medidas ----------------------------------------------------------------------------


func _glass() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-9.0)


func _pieces_rect() -> Rect2:
	var glass := _glass()
	return Rect2(
		glass.position + Vector2(10, HEAD),
		Vector2(glass.size.x * 0.24, glass.size.y - HEAD - LINE_HEIGHT - 22.0)
	)


func _stage_rect() -> Rect2:
	var pieces := _pieces_rect()
	var glass := _glass()
	var left := pieces.end.x + 12.0
	return Rect2(left, pieces.position.y, glass.size.x * 0.34, pieces.size.y * 0.72)


func _protos_rect() -> Rect2:
	var stage := _stage_rect()
	var glass := _glass()
	var left := stage.end.x + 12.0
	var pieces := _pieces_rect()
	return Rect2(left, pieces.position.y, glass.end.x - left - 10.0, pieces.size.y)


func _line_rect() -> Rect2:
	var glass := _glass()
	var pieces := _pieces_rect()
	return Rect2(glass.position.x + 10.0, pieces.end.y + 10.0, glass.size.x - 20.0, LINE_HEIGHT)


func _close_rect() -> Rect2:
	var glass := _glass()
	return Rect2(glass.end.x - 30.0, glass.position.y + 8.0, 22.0, 22.0)


func _pieces() -> Array:
	return state.get("pieces", [])


func _protos() -> Array:
	return state.get("protos", [])


func _proto_ids() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _protos():
		out.append(str(entry["id"]))
	return out


func piece_rect(index: int) -> Rect2:
	var area := _pieces_rect()
	var count := maxi(_pieces().size(), 1)
	var h := area.size.y / count
	return Rect2(area.position.x, area.position.y + h * index, area.size.x, h - 6.0)


func proto_rect(index: int) -> Rect2:
	var area := _protos_rect()
	var h := minf(area.size.y / maxi(_protos().size(), 1), 92.0)
	return Rect2(area.position.x, area.position.y + h * index, area.size.x, h - 6.0)


## Zona bajo un punto: "close", "piece:<hueco>", "proto:<id>" o "".
func zone_at(at: Vector2) -> String:
	if _open < 0.99:
		return ""
	if _close_rect().grow(3.0).has_point(at):
		return "close"
	for index in _pieces().size():
		if piece_rect(index).has_point(at):
			return "piece:" + str(_pieces()[index]["slot"])
	for index in _protos().size():
		if proto_rect(index).has_point(at):
			return "proto:" + str(_protos()[index]["id"])
	return ""


# --- Raton ------------------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hover(zone_at(motion.position))
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	press(zone_at(click.position))


## Pulsa una zona: cerrar, una pieza o un prototipo (dos pulsaciones).
func press(zone: String) -> void:
	if zone == "close":
		close_pressed.emit()
	elif zone.begins_with("piece:"):
		_armed = ""
		Sfx.play("ui_tic")
		piece_picked.emit(zone.trim_prefix("piece:"))
	elif zone.begins_with("proto:"):
		var id := zone.trim_prefix("proto:")
		var entry := _entry(id)
		if str(entry.get("reason", "")) != "":
			_armed = ""
			Sfx.play("ui_cerrar")
		elif _armed == id:
			proto_confirmed.emit(id)
		else:
			_armed = id
			Sfx.play("ui_habilidad")
	queue_redraw()


func _entry(id: String) -> Dictionary:
	for entry: Dictionary in _protos():
		if str(entry["id"]) == id:
			return entry
	return {}


func _set_hover(zone: String) -> void:
	if zone == _hover:
		return
	_hover = zone
	if zone != "":
		Sfx.play("ui_tic")
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if zone != "" else CURSOR_ARROW


# --- Dibujo -----------------------------------------------------------------------------


func _draw() -> void:
	# La sala, a oscuras detras.
	var room := get_global_transform().affine_inverse() * get_viewport_rect()
	draw_rect(room, Color(0.0, 0.004, 0.01, 0.78 * _open))
	var frame := TechStyle.plate(Color("15191f"), Color("4f5866"), 0.0, 10.0)
	frame.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	var glass := _glass()
	draw_rect(glass, Color("0a0d12"))
	if _open < 0.99:
		return
	_text(glass.position + Vector2(12, 26), Txt.t("specialist_title").to_upper(), 220.0, 17, GOLD)
	var sub := Txt.t("specialist_subtitle")
	_text(glass.position + Vector2(170, 26), sub, glass.size.x * 0.5, 11, MUTED)
	var cells := "%s %s" % [HangarProps.thousands(int(state.get("cells", 0))), Txt.t("hud_cells")]
	_text(Vector2(glass.end.x - 220.0, glass.position.y + 26.0), cells, 180.0, 12, TEXT)
	_draw_close()
	for index in _pieces().size():
		_draw_piece(index)
	_draw_stage()
	for index in _protos().size():
		_draw_proto(index)
	_draw_line()


func _draw_close() -> void:
	var rect := _close_rect()
	var color := GOLD if _hover == "close" else MUTED
	draw_rect(rect, color, false, 1.0)
	var mid := rect.get_center()
	draw_line(mid - Vector2(5, 5), mid + Vector2(5, 5), color, 2.0)
	draw_line(mid - Vector2(5, -5), mid + Vector2(5, -5), color, 2.0)


## Una de tus piezas: su dibujo, su hueco y su prototipo con el rango.
func _draw_piece(index: int) -> void:
	var entry: Dictionary = _pieces()[index]
	var rect := piece_rect(index)
	var selected := bool(entry.get("selected", false))
	var hot := _hover == "piece:" + str(entry["slot"])
	draw_rect(rect, Color(1, 1, 1, 0.05 if hot else 0.025))
	var edge := GOLD if selected else (Color(TEXT, 0.5) if hot else Color(1, 1, 1, 0.1))
	draw_rect(rect, edge, false, 2.0 if selected else 1.0)
	var icon := Rect2(
		rect.position + Vector2(6, 6), Vector2(rect.size.y - 12.0, rect.size.y - 12.0)
	)
	var item: ItemDef = entry.get("item")
	if item != null:
		PartIcon.paint(self, icon, item)
	var at := Vector2(icon.end.x + 8.0, rect.position.y + 18.0)
	var room := rect.end.x - at.x - 6.0
	_text(at, str(entry["title"]), room, 11, GOLD if selected else TEXT)
	var proto := str(entry.get("proto", ""))
	if proto == "":
		_text(at + Vector2(0, 16), Txt.t("specialist_none"), room, 10, MUTED)
	else:
		var rank := int(entry.get("rank", 0))
		_text(at + Vector2(0, 16), "%s %s" % [proto, ROMAN[rank]], room, 10, PLASMA)


## La pieza elegida bajo la lampara del especialista, y las chispas al
## instalarle algo.
func _draw_stage() -> void:
	var stage := _stage_rect()
	var item: ItemDef = state.get("item")
	var locked := str(state.get("locked", "")) != ""
	PartShowcase.draw_stage(self, stage, item, -1, _time, false, locked)
	var below := Vector2(stage.position.x, stage.end.y + 22.0)
	if item != null:
		_text(below, item.display_name, stage.size.x, 14, TEXT)
		var now := str(state.get("installed", ""))
		var line := now if now != "" else Txt.t("specialist_none")
		_text(below + Vector2(0, 20), line, stage.size.x, 11, PLASMA if now != "" else MUTED)
	if _sparks > 0.0:
		var mid := stage.get_center()
		for i in 14:
			var angle := float(i) * TAU / 14.0 + _time * 3.0
			var reach := 20.0 + (1.0 - _sparks) * stage.size.x * 0.35
			var tip := mid + Vector2(cos(angle), sin(angle) * 0.7) * reach
			draw_line(mid.lerp(tip, 0.6), tip, Color(1.0, 0.9, 0.6, _sparks), 2.0)
		draw_circle(mid, 12.0 * _sparks, Color(1, 1, 1, 0.6 * _sparks))


## Un prototipo: su nombre, su rango en rombos, lo que hace el rango
## siguiente y su precio, o por que no se puede.
func _draw_proto(index: int) -> void:
	var entry: Dictionary = _protos()[index]
	var id := str(entry["id"])
	var rect := proto_rect(index)
	var hot := _hover == "proto:" + id
	var armed := _armed == id
	var blocked := str(entry.get("reason", "")) != ""
	draw_rect(rect, Color(1, 1, 1, 0.06 if hot else 0.03))
	var edge := Color(1, 1, 1, 0.12)
	if armed:
		edge = Color(GOLD, 0.6 + 0.4 * sin(_time * 8.0))
	elif hot and not blocked:
		edge = Color(PLASMA, 0.7)
	draw_rect(rect, edge, false, 2.0 if armed else 1.0)
	var at := rect.position + Vector2(10, 20)
	var name_tone := PLASMA if bool(entry.get("special", false)) else TEXT
	_text(at, str(entry["name"]), rect.size.x * 0.6, 13, name_tone)
	# Los cinco rangos: llenos los que tiene, el siguiente latiendo.
	var ranks := int(entry.get("ranks", 5))
	var now := int(entry.get("rank_now", 0))
	for r in ranks:
		var gem := Vector2(rect.end.x - 18.0 - (ranks - 1 - r) * 16.0, rect.position.y + 15.0)
		var shape := PackedVector2Array(
			[gem + Vector2(0, -6), gem + Vector2(6, 0), gem + Vector2(0, 6), gem + Vector2(-6, 0)]
		)
		if r < now:
			draw_colored_polygon(shape, PLASMA)
		elif r == now and not blocked:
			draw_colored_polygon(shape, Color(PLASMA, 0.2 + 0.2 * sin(_time * 5.0)))
		shape.append(shape[0])
		draw_polyline(shape, Color(PLASMA, 0.8), 1.0)
	_text(at + Vector2(0, 18), str(entry.get("text", "")), rect.size.x - 20.0, 11, GOOD)
	var foot := Vector2(at.x, rect.end.y - 9.0)
	if blocked:
		_text(foot, str(entry["reason"]), rect.size.x - 20.0, 10, BAD)
		return
	var label := Txt.t("specialist_buy_confirm") if armed else str(entry.get("action", ""))
	var price := "%s %s" % [HangarProps.thousands(int(entry.get("price", 0))), Txt.t("hud_cells")]
	_text(foot, "%s · %s" % [label, price], rect.size.x - 20.0, 11, GOLD)


## Lo que dice el especialista, letra a letra.
func _draw_line() -> void:
	var rect := _line_rect()
	draw_rect(rect, Color(0, 0, 0, 0.5))
	draw_rect(rect, Color(LAMP_LINE, 0.25), false, 1.0)
	var text := str(state.get("line", ""))
	if _armed != "":
		text = Txt.t("specialist_line_armed")
	if text != _typed:
		_typed = text
		_typed_at = _time
	var count := mini(text.length(), int((_time - _typed_at) * TYPE_SPEED))
	var at := Vector2(rect.position.x + 10.0, rect.get_center().y + 5.0)
	_text(at, ">", 12.0, 12, GOLD)
	_text(at + Vector2(16, 0), text.substr(0, count), rect.size.x - 40.0, 12, TEXT)


func _text(at: Vector2, text: String, width: float, font_size: int, color: Color) -> void:
	HangarProps.text(self, _font, at, text, width, font_size, color)
