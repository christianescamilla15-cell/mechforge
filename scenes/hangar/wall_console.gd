class_name WallConsole
extends Control
## Una pantalla de la pared del hangar, de cerca (pedido del usuario el
## 2026-11-20: "casi como si no existiera un menu"). Al pulsar la pantalla de
## mejoras o la de habilidades (o el rotulo de tu robot), esa misma pantalla
## crece desde su sitio y se usa ahi, sin cajon ni botones:
## - mejoras: una fila por mejora permanente, con sus diez niveles como
##   segmentos, lo que da ahora y lo que dara, y su precio; se pulsa la fila
##   para subirla;
## - habilidades: las tres ramas del arbol, de abajo arriba; las aprendidas
##   encendidas, la siguiente de cada rama latiendo; se pulsa para aprenderla;
## - robot: la ficha del robot que usas y, si tienes mas de uno, desmontarlo;
## - ajustes (el cuadro de control de la pared): la velocidad de las
##   animaciones, la pantalla completa, el volumen de cada canal (se pulsa o
##   se arrastra su barra) y salir del juego, que pide dos pulsaciones.
## Al cerrarla vuelve a su sitio en la pared.
##
## Ensena un estado (WorkshopBrief) y avisa de lo que se pulsa; no decide
## nada.

signal upgrade_picked(track: String)
signal skill_picked(id: String)
signal remove_pressed
## Un ajuste cambiado: "speed" (indice), "fullscreen" (bool) o
## "volume:<canal>" (de 0 a 1).
signal setting_changed(key: String, value: Variant)
signal quit_pressed

const GROW_SECONDS := 0.26
## Lo que late en la pantalla va despacio: unas 30 veces por segundo.
const REDRAW_SECONDS := 1.0 / 30.0
const GOLD := Color("ffd36b")
const GOOD := Color("7dff9b")
const BAD := Color("ff7d6b")
const MUTED := Color("7fb5c4")
const LINE := Color("3fd0e6")
const TEXT := Color("bfefff")
const PAD := 16.0
const HEAD := 46.0
const FOOT := 58.0
## Segmentos de una barra de volumen (cada uno, un 5 %).
const VOLUME_STEPS := 20

## Lo que ensena. Siempre lleva "kind" ("mejoras", "habilidades", "robot" o
## "ajustes") y "title"; el resto depende de la pantalla (ver WorkshopBrief
## y settings_state).
var state: Dictionary = {}:
	set(value):
		state = value
		queue_redraw()

## Su sitio en la pared y el que ocupa de cerca.
var _from := Rect2()
var _to := Rect2()
## Cuanto esta de cerca: 0 = en la pared; 1 = abierta.
var _open := 0.0:
	set(value):
		_open = value
		position = _from.position.lerp(_to.position, value)
		size = _from.size.lerp(_to.size, value)
		queue_redraw()
var _kind := ""
var _font: Font
var _time := 0.0
var _since_draw := 0.0
var _hover := ""
## Barra de volumen que se esta arrastrando ("" = ninguna).
var _dragging := ""
## Salir del juego esta armado: la siguiente pulsacion sale.
var _quit_armed := false
var _zones: Dictionary[String, Rect2] = {}
var _grow: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = get_theme_default_font()
	mouse_exited.connect(_set_hover.bind(""))


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_since_draw += delta
	if _since_draw >= REDRAW_SECONDS:
		_since_draw = 0.0
		queue_redraw()


## La pantalla que esta de cerca ("" = ninguna).
func kind() -> String:
	return _kind


## Cuanto esta de cerca (para oscurecer el hangar detras).
func shown() -> float:
	return _open if visible else 0.0


## Acerca una pantalla: crece de `from` (su sitio en la pared) a `to`.
func open(p_state: Dictionary, from: Rect2, to: Rect2, instant: bool = false) -> void:
	var same := _kind == str(p_state.get("kind", ""))
	state = p_state
	_kind = str(p_state.get("kind", ""))
	_from = from
	_to = to
	if same and visible:
		# Ya esta de cerca: solo se recoloca (por si cambio el tamano).
		position = _from.position.lerp(_to.position, _open)
		size = _from.size.lerp(_to.size, _open)
		return
	_hover = ""
	_quit_armed = false
	visible = true
	_open = 0.0
	Sfx.play("ui_abrir")
	_tween_open(1.0, 0.0 if instant else GROW_SECONDS)


## La devuelve a su sitio.
func close(instant: bool = false) -> void:
	if _kind == "":
		return
	_kind = ""
	_set_hover("")
	_tween_open(0.0, 0.0 if instant else GROW_SECONDS * 0.8)


func _tween_open(to: float, seconds: float) -> void:
	if _grow != null:
		_grow.kill()
	if seconds <= 0.0:
		_open = to
		visible = to > 0.0
		return
	_grow = create_tween().set_trans(Tween.TRANS_CUBIC)
	_grow.set_ease(Tween.EASE_OUT if to > 0.5 else Tween.EASE_IN)
	_grow.tween_property(self, "_open", to, seconds)
	if to <= 0.0:
		_grow.tween_callback(func() -> void: visible = false)


# --- Zonas y raton ---------------------------------------------------------------


func _glass() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-9.0)


## Rectangulo de una zona ("row:<mejora>", "node:<habilidad>", "remove").
func zone_rect(zone: String) -> Rect2:
	_layout_zones()
	return _zones.get(zone, Rect2())


func zone_at(at: Vector2) -> String:
	# Mientras crece no se pulsa nada.
	if _open < 0.99:
		return ""
	_layout_zones()
	for zone: String in _zones:
		if _zones[zone].has_point(at):
			return zone
	return ""


func _layout_zones() -> void:
	_zones.clear()
	var glass := _glass()
	match str(state.get("kind", "")):
		"mejoras":
			var rows: Array = state.get("rows", [])
			var top := glass.position.y + HEAD + 20.0
			var each := (glass.end.y - FOOT - top) / maxf(rows.size(), 1.0)
			for i in rows.size():
				_zones["row:" + str(rows[i]["id"])] = Rect2(
					glass.position.x + 6.0, top + i * each, glass.size.x - 12.0, each - 3.0
				)
		"habilidades":
			var branches: Array = state.get("branches", [])
			for b in branches.size():
				var nodes: Array = branches[b]["nodes"]
				for n in nodes.size():
					var at := _node_point(b, branches.size(), n, nodes.size())
					_zones["node:" + str(nodes[n]["id"])] = Rect2(
						at - Vector2(15, 12), Vector2(30, 24)
					)
		"robot":
			if bool(state.get("can_remove", false)):
				_zones["remove"] = Rect2(
					glass.position.x + PAD, glass.end.y - 40.0, glass.size.x - PAD * 2.0, 30.0
				)
		"ajustes":
			_layout_settings(glass)


## Zonas de los ajustes: una por velocidad, el interruptor de la pantalla
## completa, la barra de cada canal y salir.
func _layout_settings(glass: Rect2) -> void:
	var left := glass.position.x + PAD
	var wide := glass.size.x - PAD * 2.0
	var top := glass.position.y + HEAD + 20.0
	var speeds: Array = state.get("speeds", [])
	var each := wide / maxf(speeds.size(), 1.0)
	for i in speeds.size():
		_zones["speed:%d" % i] = Rect2(left + i * each, top, each - 4.0, 28.0)
	_zones["full"] = Rect2(left, top + 42.0, wide, 28.0)
	var volumes: Array = state.get("volumes", [])
	for i in volumes.size():
		_zones["vol:" + str(volumes[i]["bus"])] = Rect2(
			left + wide * 0.36, top + 86.0 + i * 32.0, wide * 0.5, 22.0
		)
	if bool(state.get("quit", false)):
		_zones["quit"] = Rect2(left, glass.end.y - FOOT - 40.0, wide, 30.0)


## Centro de un nodo del arbol: cada rama es una columna que sube en zigzag.
func _node_point(branch: int, branches: int, node: int, nodes: int) -> Vector2:
	var glass := _glass()
	var top := glass.position.y + HEAD + 34.0
	var bottom := glass.end.y - FOOT - 16.0
	var column := glass.size.x / maxf(branches, 1.0)
	var x := glass.position.x + column * (branch + 0.5) + (14.0 if node % 2 == 1 else -14.0)
	var y := bottom - (bottom - top) * node / maxf(nodes - 1.0, 1.0)
	return Vector2(x, y)


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hover(zone_at(motion.position))
		# Arrastrar una barra de volumen la lleva con el raton.
		if _dragging != "" and motion.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
			_set_volume(_dragging, motion.position.x)
		return
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if not click.pressed:
		_dragging = ""
		return
	accept_event()
	var zone := zone_at(click.position)
	if zone.begins_with("vol:"):
		_dragging = zone
		_quit_armed = false
		_set_volume(zone, click.position.x)
		return
	press(zone)


## Pone el volumen de una barra segun donde esta el raton, de 5 en 5 %.
func _set_volume(zone: String, x: float) -> void:
	var bar: Rect2 = zone_rect(zone)
	if bar.size.x <= 0.0:
		return
	var share := clampf((x - bar.position.x) / bar.size.x, 0.0, 1.0)
	var value := roundf(share * VOLUME_STEPS) / VOLUME_STEPS
	var bus := zone.trim_prefix("vol:")
	for entry: Dictionary in state.get("volumes", []):
		if str(entry["bus"]) == bus and is_equal_approx(float(entry["value"]), value):
			return
	setting_changed.emit("volume:" + bus, value)
	Sfx.play("ui_tic")


## Pulsa una zona.
func press(zone: String) -> void:
	if zone.begins_with("row:"):
		var row := _row(zone.trim_prefix("row:"))
		if str(row.get("state", "")) == "ok":
			upgrade_picked.emit(str(row["id"]))
		else:
			Sfx.play("ui_cerrar")
	elif zone.begins_with("node:"):
		var node := _node(zone.trim_prefix("node:"))
		if str(node.get("state", "")) == "next" and str(node.get("reason", "")) == "":
			skill_picked.emit(str(node["id"]))
		else:
			Sfx.play("ui_cerrar")
	elif zone == "remove":
		remove_pressed.emit()
	elif zone.begins_with("speed:"):
		setting_changed.emit("speed", int(zone.trim_prefix("speed:")))
		Sfx.play("ui_clic")
	elif zone == "full":
		setting_changed.emit("fullscreen", not bool(state.get("fullscreen", false)))
		Sfx.play("ui_clic")
	if zone == "quit":
		if _quit_armed:
			quit_pressed.emit()
		else:
			# La primera pulsacion solo lo deja armado.
			_quit_armed = true
			Sfx.play("ui_habilidad")
	else:
		_quit_armed = false
	queue_redraw()


func _row(id: String) -> Dictionary:
	for row: Dictionary in state.get("rows", []):
		if str(row["id"]) == id:
			return row
	return {}


func _node(id: String) -> Dictionary:
	for branch: Dictionary in state.get("branches", []):
		for node: Dictionary in branch["nodes"]:
			if str(node["id"]) == id:
				return node
	return {}


func _set_hover(zone: String) -> void:
	if zone == _hover:
		return
	_hover = zone
	if zone != "":
		Sfx.play("ui_tic")
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if zone != "" else Control.CURSOR_ARROW
	)
	queue_redraw()


# --- Dibujo -----------------------------------------------------------------------


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	HangarArt.draw_screen(self, rect, false, _time)
	draw_rect(rect, Color(GOLD, 0.75 * _open), false, 2.0)
	# Lo de dentro aparece cuando la pantalla ya esta casi de cerca.
	var alpha := clampf((_open - 0.6) / 0.4, 0.0, 1.0)
	if alpha <= 0.0:
		return
	_layout_zones()
	var glass := _glass()
	_text(glass.position + Vector2(PAD, 26), str(state.get("title", "")), 300.0, 18, TEXT, alpha)
	draw_line(
		glass.position + Vector2(PAD, HEAD - 8.0),
		Vector2(glass.end.x - PAD, glass.position.y + HEAD - 8.0),
		Color(LINE, 0.5 * alpha),
		1.0
	)
	match str(state.get("kind", "")):
		"mejoras":
			_draw_upgrades(glass, alpha)
		"habilidades":
			_draw_skills(glass, alpha)
		"robot":
			_draw_robot(glass, alpha)
		"ajustes":
			_draw_settings(glass, alpha)


func _text(
	at: Vector2,
	line: String,
	width: float,
	font_size: int,
	color: Color,
	alpha: float = 1.0,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
) -> void:
	draw_string(
		_font, at + Vector2(1, 1), line, align, width, font_size, Color(0, 0, 0, 0.6 * alpha)
	)
	draw_string(_font, at, line, align, width, font_size, Color(color, color.a * alpha))


## A la derecha de la cabecera: una cifra con su nombre pequeno.
func _head_value(glass: Rect2, value: String, unit: String, color: Color, alpha: float) -> void:
	var wide := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var unit_wide := _font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var x := glass.end.x - PAD - wide - unit_wide - 5.0
	_text(Vector2(x, glass.position.y + 26.0), value, wide + 2.0, 16, color, alpha)
	_text(Vector2(x + wide + 5.0, glass.position.y + 26.0), unit, unit_wide + 2.0, 10, MUTED, alpha)


## Pie: lo que hay bajo el raton o una pista.
func _foot(glass: Rect2, title: String, body: String, tone: Color, alpha: float) -> void:
	var top := glass.end.y - FOOT
	draw_line(
		Vector2(glass.position.x + PAD, top),
		Vector2(glass.end.x - PAD, top),
		Color(LINE, 0.4 * alpha),
		1.0
	)
	var at := Vector2(glass.position.x + PAD, top + 18.0)
	var wide := glass.size.x - PAD * 2.0
	if title != "":
		_text(at, title, wide, 13, Color.WHITE, alpha)
		at.y += 16.0
	draw_multiline_string(
		_font, at, body, HORIZONTAL_ALIGNMENT_LEFT, wide, 11, 2, Color(tone, tone.a * alpha)
	)


# --- Mejoras ----------------------------------------------------------------------


func _draw_upgrades(glass: Rect2, alpha: float) -> void:
	_head_value(
		glass, HangarProps.thousands(int(state.get("cells", 0))), Txt.t("hud_cells"), TEXT, alpha
	)
	_text(
		glass.position + Vector2(PAD, HEAD + 8.0),
		str(state.get("info", "")),
		glass.size.x - PAD * 2.0,
		11,
		MUTED,
		alpha
	)
	var top_level := maxi(int(state.get("max", 10)), 1)
	var cap := int(state.get("cap", top_level))
	var hovered := {}
	for row: Dictionary in state.get("rows", []):
		var zone := "row:" + str(row["id"])
		var rect: Rect2 = _zones.get(zone, Rect2())
		var hover := _hover == zone
		if hover:
			hovered = row
		_draw_upgrade_row(row, rect, hover, top_level, cap, alpha)
	if hovered.is_empty():
		_foot(glass, "", Txt.t("console_upgrades_hint"), MUTED, alpha)
	else:
		var blocked := str(hovered.get("reason", "")) != ""
		_foot(
			glass,
			str(hovered["name"]),
			str(hovered["reason"]) if blocked else str(hovered.get("gain", "")),
			BAD if blocked else GOOD,
			alpha
		)


func _draw_upgrade_row(
	row: Dictionary, rect: Rect2, hover: bool, top_level: int, cap: int, alpha: float
) -> void:
	var kind := str(row.get("state", ""))
	var can := kind == "ok"
	if hover:
		draw_rect(rect, Color(LINE, 0.1 * alpha))
		draw_rect(rect, Color(GOLD if can else LINE, 0.7 * alpha), false, 1.5)
	var name_wide := rect.size.x * 0.46
	var mid := rect.get_center().y
	_text(Vector2(rect.position.x + 8.0, mid - 2.0), str(row["name"]), name_wide, 13, TEXT, alpha)
	_text(
		Vector2(rect.position.x + 8.0, mid + 12.0),
		str(row["value"]),
		name_wide,
		10,
		MUTED if kind == "locked" else GOOD,
		alpha
	)
	# Sus niveles, como segmentos: llenos los que tienes, late el siguiente y
	# los que la zona aun no deja van tachados.
	var level := int(row["level"])
	var bar := Rect2(rect.position.x + 8.0 + name_wide, mid - 7.0, rect.size.x * 0.31, 14.0)
	var w := bar.size.x / top_level
	for i in top_level:
		var cell := Rect2(bar.position.x + i * w, bar.position.y, w - 2.0, bar.size.y)
		draw_rect(cell, Color(0, 0, 0, 0.5 * alpha))
		if i < level:
			draw_rect(cell, Color(LINE, 0.9 * alpha))
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, 3.0)), Color(TEXT, 0.9 * alpha))
		elif i == level and can:
			draw_rect(cell, Color(GOLD, (0.25 + 0.3 * absf(sin(_time * 3.0))) * alpha))
			draw_rect(cell, Color(GOLD, 0.8 * alpha), false, 1.0)
		elif i >= cap or kind == "locked":
			draw_line(cell.position, cell.end, Color(BAD, 0.3 * alpha), 1.0)
		else:
			draw_rect(cell, Color(LINE, 0.35 * alpha), false, 1.0)
	# A la derecha: lo que cuesta o por que no sube.
	var right := Vector2(bar.end.x + 8.0, mid + 4.0)
	var room := rect.end.x - right.x - 8.0
	var tone := GOLD
	if kind in ["poor", "cap", "locked"]:
		tone = BAD
	elif kind == "max":
		tone = MUTED
	_text(right, str(row["label"]), room, 12, tone, alpha, HORIZONTAL_ALIGNMENT_RIGHT)


# --- Habilidades ------------------------------------------------------------------


func _draw_skills(glass: Rect2, alpha: float) -> void:
	var points := int(state.get("points", 0))
	_head_value(glass, str(points), Txt.t("console_points"), GOLD if points > 0 else MUTED, alpha)
	var branches: Array = state.get("branches", [])
	var column := glass.size.x / maxf(branches.size(), 1.0)
	var hovered := {}
	for b in branches.size():
		var branch: Dictionary = branches[b]
		var nodes: Array = branch["nodes"]
		var head := Vector2(glass.position.x + column * b, glass.position.y + HEAD + 10.0)
		_text(
			head,
			str(branch["name"]).to_upper(),
			column,
			12,
			TEXT,
			alpha,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_text(
			head + Vector2(0, 13),
			Txt.t("console_branch_done", [int(branch["done"]), nodes.size()]),
			column,
			9,
			MUTED,
			alpha,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		# Primero los cables, luego los nodos encima.
		for n in range(1, nodes.size()):
			var lit := str(nodes[n]["state"]) == "done"
			draw_line(
				_node_point(b, branches.size(), n - 1, nodes.size()),
				_node_point(b, branches.size(), n, nodes.size()),
				Color(TEXT if lit else LINE, (0.9 if lit else 0.3) * alpha),
				2.0 if lit else 1.0
			)
		for n in nodes.size():
			var node: Dictionary = nodes[n]
			var hover := _hover == "node:" + str(node["id"])
			if hover:
				hovered = node
			_draw_node(_node_point(b, branches.size(), n, nodes.size()), node, hover, alpha)
	if hovered.is_empty():
		_foot(glass, "", Txt.t("console_skills_hint"), MUTED, alpha)
		return
	var note := str(hovered.get("reason", ""))
	var tone := BAD
	if str(hovered["state"]) == "done":
		note = Txt.t("console_skill_done")
		tone = GOOD
	elif note == "":
		note = Txt.t("console_skill_learn")
		tone = GOLD
	_foot(glass, str(hovered["name"]), "%s · %s" % [str(hovered["text"]), note], tone, alpha)


## Un nodo: hexagono lleno si esta aprendido, latiendo si es el siguiente.
func _draw_node(at: Vector2, node: Dictionary, hover: bool, alpha: float) -> void:
	var kind := str(node["state"])
	var ready := kind == "next" and str(node.get("reason", "")) == ""
	var r := 8.5 + (1.5 if hover else 0.0)
	var points := PackedVector2Array()
	for i in 7:
		var a := TAU * i / 6.0 + PI / 6.0
		points.append(at + Vector2(cos(a), sin(a)) * r)
	var fill := Color(HangarArt.SCREEN.darkened(0.3), alpha)
	var edge := Color(LINE, 0.35 * alpha)
	if kind == "done":
		fill = Color(LINE, 0.95 * alpha)
		edge = Color(TEXT, alpha)
	elif ready:
		var beat := 0.5 + 0.5 * sin(_time * 4.0)
		fill = Color(GOLD, (0.2 + 0.35 * beat) * alpha)
		edge = Color(GOLD, alpha)
		draw_arc(at, r + 3.0 + 3.0 * beat, 0, TAU, 20, Color(GOLD, (0.5 - 0.4 * beat) * alpha), 1.5)
	elif kind == "next":
		edge = Color(LINE, 0.9 * alpha)
	var body := points.duplicate()
	body.resize(6)
	draw_colored_polygon(body, fill)
	draw_polyline(points, edge, 2.0 if hover or kind != "closed" else 1.0, true)
	if kind == "done":
		draw_circle(at, 2.5, Color(HangarArt.SCREEN, alpha))


# --- Tu robot ---------------------------------------------------------------------


func _draw_robot(glass: Rect2, alpha: float) -> void:
	var at := glass.position + Vector2(PAD, HEAD + 12.0)
	var wide := glass.size.x - PAD * 2.0
	if str(state.get("design", "")) != "":
		_text(at, str(state["design"]), wide, 12, TEXT, alpha)
		at.y += 20.0
	draw_multiline_string(
		_font,
		at,
		str(state.get("hint", "")),
		HORIZONTAL_ALIGNMENT_LEFT,
		wide,
		11,
		3,
		Color(MUTED, alpha)
	)
	if not _zones.has("remove"):
		return
	var rect := _zones["remove"]
	var hover := _hover == "remove"
	var plate := TechStyle.plate(Color("2a1a1c"), BAD if hover else Color("7a4040"), 0.0, 6.0)
	plate.groove = false
	plate.bolts = false
	plate.glow = 0.5 if hover else 0.0
	plate.draw(get_canvas_item(), rect)
	_text(
		rect.position + Vector2(0, 20),
		Txt.t("robots_remove"),
		rect.size.x,
		13,
		Color.WHITE if hover else BAD,
		alpha,
		HORIZONTAL_ALIGNMENT_CENTER
	)


# --- Ajustes ----------------------------------------------------------------------


## Lo que ensena la pantalla de ajustes para estos ajustes del jugador.
## `with_quit`: con la tecla de salir del juego.
static func settings_state(settings: GameSettings, with_quit: bool) -> Dictionary:
	var speeds: Array[String] = []
	for i in GameSettings.SPEEDS.size():
		speeds.append(Txt.t("settings_speed_%d" % i))
	var volumes: Array[Dictionary] = []
	for bus in GameSettings.BUSES:
		(
			volumes
			. append(
				{
					"bus": bus,
					"name": Txt.t("settings_volume_%s" % bus.to_lower()),
					"value": float(settings.volumes[bus]),
				}
			)
		)
	return {
		"kind": "ajustes",
		"title": Txt.t("settings_title").to_upper(),
		"speed": settings.speed_index,
		"speeds": speeds,
		"fullscreen": settings.fullscreen,
		"volumes": volumes,
		"quit": with_quit,
	}


func _draw_settings(glass: Rect2, alpha: float) -> void:
	var left := glass.position.x + PAD
	_text(
		Vector2(left, glass.position.y + HEAD + 12.0),
		Txt.t("settings_speed"),
		320.0,
		11,
		MUTED,
		alpha
	)
	var speeds: Array = state.get("speeds", [])
	for i in speeds.size():
		var zone := "speed:%d" % i
		_draw_choice(_zones[zone], str(speeds[i]), i == int(state.get("speed", 0)), zone, alpha)
	# La pantalla completa: un interruptor.
	var full: Rect2 = _zones["full"]
	var on := bool(state.get("fullscreen", false))
	if _hover == "full":
		draw_rect(full, Color(LINE, 0.1 * alpha))
	_text(
		Vector2(left, full.get_center().y + 5.0),
		Txt.t("settings_fullscreen"),
		300.0,
		13,
		TEXT,
		alpha
	)
	var track := Rect2(full.end.x - 62.0, full.get_center().y - 10.0, 56.0, 20.0)
	draw_rect(track, Color(0, 0, 0, 0.55 * alpha))
	draw_rect(track, Color(LINE if on else MUTED, 0.9 * alpha), false, 1.5)
	var knob := Rect2(track.position.x + (30.0 if on else 3.0), track.position.y + 3.0, 23.0, 14.0)
	draw_rect(knob, Color(LINE if on else MUTED, alpha))
	for entry: Dictionary in state.get("volumes", []):
		_draw_volume(entry, _zones["vol:" + str(entry["bus"])], left, alpha)
	if _zones.has("quit"):
		_draw_quit(_zones["quit"], alpha)
	_foot(glass, "", Txt.t("console_settings_hint"), MUTED, alpha)


## Una opcion de varias: llena si es la elegida.
func _draw_choice(rect: Rect2, label: String, chosen: bool, zone: String, alpha: float) -> void:
	var hover := _hover == zone
	draw_rect(rect, Color(LINE, (0.85 if chosen else (0.16 if hover else 0.06)) * alpha))
	draw_rect(
		rect, Color(GOLD if hover else LINE, (0.9 if hover or chosen else 0.4) * alpha), false, 1.5
	)
	var tone := HangarArt.SCREEN.darkened(0.4) if chosen else TEXT
	draw_string(
		_font,
		Vector2(rect.position.x, rect.get_center().y + 4.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		11,
		Color(tone, alpha)
	)


## El volumen de un canal: su nombre, su barra de segmentos y su tanto por
## ciento.
func _draw_volume(entry: Dictionary, bar: Rect2, left: float, alpha: float) -> void:
	var zone := "vol:" + str(entry["bus"])
	var live := _hover == zone or _dragging == zone
	var mid := bar.get_center().y
	_text(
		Vector2(left, mid + 5.0), str(entry["name"]), bar.position.x - left - 8.0, 13, TEXT, alpha
	)
	var level := roundi(float(entry["value"]) * VOLUME_STEPS)
	var w := bar.size.x / VOLUME_STEPS
	for i in VOLUME_STEPS:
		var cell := Rect2(bar.position.x + i * w, mid - 7.0, w - 2.0, 14.0)
		draw_rect(cell, Color(0, 0, 0, 0.5 * alpha))
		if i < level:
			draw_rect(cell, Color(GOLD if live else LINE, 0.9 * alpha))
		else:
			draw_rect(cell, Color(LINE, 0.3 * alpha), false, 1.0)
	_text(
		Vector2(bar.end.x + 6.0, mid + 5.0),
		"%d %%" % roundi(float(entry["value"]) * 100.0),
		52.0,
		12,
		GOLD if live else TEXT,
		alpha,
		HORIZONTAL_ALIGNMENT_RIGHT
	)


## Salir del juego: una tecla roja; armada, pide la segunda pulsacion.
func _draw_quit(rect: Rect2, alpha: float) -> void:
	var hover := _hover == "quit"
	var plate := TechStyle.plate(
		Color("2a1a1c"), BAD if hover or _quit_armed else Color("7a4040"), 0.0, 6.0
	)
	plate.groove = false
	plate.bolts = false
	plate.glow = 0.5 if hover or _quit_armed else 0.0
	plate.draw(get_canvas_item(), rect)
	var label := Txt.t("quit_confirm") if _quit_armed else Txt.t("quit_game")
	var tone := Color.WHITE if hover else BAD
	if _quit_armed:
		tone = Color(GOLD, 0.7 + 0.3 * sin(_time * 8.0))
	_text(
		rect.position + Vector2(0, 20),
		label,
		rect.size.x,
		13,
		tone,
		alpha,
		HORIZONTAL_ALIGNMENT_CENTER
	)
