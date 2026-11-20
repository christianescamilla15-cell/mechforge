class_name MissionBoard
extends Control
## El monitor de misiones de la pared del hangar: el cuadro de campana. Sin
## pulsarlo ya ensena la zona, las luces de avance (una por combate y el
## rombo del jefe) y, en su camara, al rival que toca. Al pulsarlo el hangar
## pasa al modo mision (HangarStage): los rivales se proyectan en el suelo y
## el monitor ensena el combate y sus tres canales (campana, arena y combate
## libre). En el combate libre se eligen aqui el rival, la clase y la
## dificultad, con sus flechas.
##
## Ensena un estado de MissionBrief y avisa de lo que se pulsa; no decide
## nada.

## Se pulso con el modo mision apagado.
signal opened
signal channel_picked(channel: String)
## Una flecha del combate libre: `step` es -1 o 1.
signal pick_changed(key: String, step: int)

const FEED_WIDTH := 92.0
const TAB_HEIGHT := 22.0
const GOLD := Color("ffe27a")
const BAD := Color("ff8a7a")
const MUTED := Color("7fb5c4")
const TAB_KEYS := {
	"campaign": "mission_tab_campaign", "arena": "mission_tab_arena", "free": "mission_tab_free"
}

static var _shader: Shader

## Lo que ensena (MissionBrief), con "record" (el historial del jugador).
var state: Dictionary = {}:
	set(value):
		state = value
		_sync_feed()
		queue_redraw()
## Cuanto esta en modo mision: 0 = el monitor de la pared; 1 = abierto.
var open := 0.0:
	set(value):
		open = value
		queue_redraw()

var _font: Font
var _time := 0.0
## Zona bajo el raton: "", "board", "tab:<canal>" o "pick:<clave>:<paso>".
var _hover := ""
var _zones: Dictionary[String, Rect2] = {}
var _feed_clip := Control.new()
var _feed: MechView
var _feed_id := ""
## Luz de avance que acaba de encenderse (-1 = ninguna) y su destello.
var _lit := -1
var _flash := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_font = get_theme_default_font()
	_feed_clip.clip_contents = true
	_feed_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed_clip)
	resized.connect(_sync_feed)
	mouse_exited.connect(_set_hover.bind(""))
	_sync_feed()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Destello de la luz del combate recien ganado.
func flash_lamp(index: int, delay: float = 0.0) -> void:
	_lit = index
	_flash = 0.0
	var tween := create_tween()
	tween.tween_property(self, "_flash", 1.0, 0.25).set_delay(delay)
	tween.tween_property(self, "_flash", 0.0, 0.9)
	tween.tween_callback(func() -> void: _lit = -1)


## Zona del monitor bajo un punto (para las pruebas y el raton).
func zone_at(at: Vector2) -> String:
	if open < 0.5:
		return "board" if Rect2(Vector2.ZERO, size).has_point(at) else ""
	for zone: String in _zones:
		if _zones[zone].has_point(at):
			return zone
	return ""


## Rectangulo de una zona ("tab:arena", "pick:enemy:1"...), vacio si no esta.
func zone_rect(zone: String) -> Rect2:
	_layout_zones()
	return _zones.get(zone, Rect2())


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hover(zone_at(motion.position))
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	var zone := zone_at(click.position)
	if zone == "board":
		opened.emit()
	elif zone.begins_with("tab:"):
		Sfx.play("ui_clic")
		channel_picked.emit(zone.trim_prefix("tab:"))
	elif zone.begins_with("pick:"):
		var parts := zone.split(":")
		Sfx.play("ui_clic")
		pick_changed.emit(parts[1], int(parts[2]))


func _set_hover(zone: String) -> void:
	if zone == _hover:
		return
	_hover = zone
	if zone != "":
		Sfx.play("ui_tic")
	queue_redraw()


# --- La camara -----------------------------------------------------------------


func _screen() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-9.0)


func _feed_rect() -> Rect2:
	var screen := _screen()
	return Rect2(
		screen.position + Vector2(8, 24),
		Vector2(FEED_WIDTH, screen.size.y - 24.0 - TAB_HEIGHT - 12.0)
	)


## La camara ensena al rival que toca, en el color de la pantalla.
func _sync_feed() -> void:
	if not is_inside_tree():
		return
	var feed := _feed_rect()
	_feed_clip.position = feed.position
	_feed_clip.size = feed.size
	var rivals: Array = state.get("rivals", [])
	var id := "" if rivals.is_empty() else "%s/%s" % [rivals[0]["id"], rivals[0]["level"]]
	if id != _feed_id:
		_feed_id = id
		if _feed != null:
			_feed.queue_free()
			_feed = null
		if not rivals.is_empty():
			_feed = MechView.new()
			_feed.material = _feed_material(bool(rivals[0].get("boss", false)))
			_feed_clip.add_child(_feed)
			var build: MechBuild = rivals[0]["build"]
			_feed.setup(build, -1)
			if build.chest != null:
				_feed.show_deployed()
	if _feed == null:
		return
	_feed.place(Vector2(feed.size.x * 0.56, feed.size.y - 5.0))
	_feed.set_facing(-1)
	_feed.scale *= (feed.size.y - 14.0) / maxf(_feed.standing_height(), 200.0)


func _feed_material(boss: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = RivalRow.HOLO_SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("holo", 0.82)
	material.set_shader_parameter("beam", RivalRow.BOSS_BEAM if boss else HangarArt.SCREEN_LINE)
	return material


# --- Dibujo ------------------------------------------------------------------


func _draw() -> void:
	var lit := _hover != "" or open > 0.5
	var screen := HangarArt.draw_screen(self, Rect2(Vector2.ZERO, size), lit, _time)
	var text := HangarArt.SCREEN_TEXT
	_text(screen.position + Vector2(8, 15), Txt.t("terminal_misiones"), 90.0, 13, text)
	_text(
		screen.position + Vector2(96, 14),
		str(state.get("record", "")),
		screen.size.x - 104.0,
		9,
		MUTED,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	var led_at := Vector2(size.x - 14.0, 6.0)
	draw_circle(led_at, 2.4, Color("55ff9a", 0.4 + 0.4 * sin(_time * 4.0)))
	# La camara: su marco y sus esquinas.
	var feed := _feed_rect()
	draw_rect(feed, Color(HangarArt.SCREEN_LINE, 0.07))
	draw_rect(feed, Color(HangarArt.SCREEN_LINE, 0.35), false, 1.0)
	if _feed == null:
		_text(
			feed.position + Vector2(0, feed.size.y * 0.55),
			"—",
			feed.size.x,
			16,
			MUTED,
			HORIZONTAL_ALIGNMENT_CENTER
		)
	else:
		var blink := 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(feed.position + Vector2(8, 8), 2.5, Color(1.0, 0.35, 0.3, 0.4 + 0.6 * blink))
	_draw_body(
		Rect2(feed.end.x + 9.0, feed.position.y, screen.end.x - feed.end.x - 16.0, feed.size.y)
	)
	_layout_zones()
	if open > 0.5:
		_draw_tabs()
	elif _hover != "":
		_text(
			Vector2(screen.position.x, screen.end.y - 8.0),
			Txt.t("mission_hint"),
			screen.size.x,
			11,
			GOLD,
			HORIZONTAL_ALIGNMENT_CENTER
		)


## La zona, sus luces de avance y lo que toca.
func _draw_body(area: Rect2) -> void:
	var text := HangarArt.SCREEN_TEXT
	var y := area.position.y + 8.0
	_text(Vector2(area.position.x, y), str(state.get("zone_line", "")), area.size.x, 9, MUTED)
	y += 16.0
	_text(Vector2(area.position.x, y), str(state.get("title", "")), area.size.x, 14, text)
	y += 9.0
	var fights := int(state.get("fights", 0))
	if fights > 0:
		_draw_lamps(Rect2(area.position.x, y, area.size.x, 9.0), fights, int(state.get("fight", 0)))
		y += 22.0
	else:
		y += 9.0
	var pickers: Array = state.get("pickers", [])
	if not pickers.is_empty() and open > 0.5:
		return
	var lines: Array = state.get("lines", [])
	for i in lines.size():
		var color := GOLD if i == 0 and str(lines[i]) == Txt.t("mission_boss") else text
		var wrapped := _font.get_multiline_string_size(
			str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, area.size.x, 10
		)
		if y + wrapped.y - 10.0 > area.end.y + 4.0:
			break
		draw_multiline_string(
			_font,
			Vector2(area.position.x, y),
			str(lines[i]),
			HORIZONTAL_ALIGNMENT_LEFT,
			area.size.x,
			10,
			3,
			color
		)
		y += wrapped.y + 2.0


## Luces de avance: una por combate y, al final, el rombo del jefe.
func _draw_lamps(area: Rect2, fights: int, fight: int) -> void:
	var gap := 3.0
	var boss_room := 15.0
	var w := minf((area.size.x - boss_room - gap * fights) / fights, 15.0)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	for i in fights:
		var lamp := Rect2(area.position.x + i * (w + gap), area.position.y, w, area.size.y)
		draw_rect(lamp, Color(0, 0, 0, 0.45))
		if i < fight:
			draw_rect(lamp, Color(HangarArt.SCREEN_LINE, 0.85))
			draw_rect(Rect2(lamp.position, Vector2(w, 2.0)), Color(1, 1, 1, 0.35))
		elif i == fight:
			draw_rect(lamp, Color(GOLD, 0.35 + 0.5 * pulse))
			draw_rect(lamp.grow(1.5), Color(GOLD, 0.25 * pulse), false, 1.0)
		else:
			draw_rect(lamp, Color(HangarArt.SCREEN_LINE, 0.3), false, 1.0)
		if i == _lit and _flash > 0.0:
			draw_rect(lamp.grow(4.0 * _flash), Color(1, 1, 1, 0.8 * _flash))
	# El jefe.
	var center := Vector2(area.position.x + fights * (w + gap) + 7.0, area.get_center().y)
	var r := 7.0
	var rhombus := PackedVector2Array(
		[
			center + Vector2(0, -r),
			center + Vector2(r, 0),
			center + Vector2(0, r),
			center + Vector2(-r, 0)
		]
	)
	draw_colored_polygon(rhombus, Color(0, 0, 0, 0.5))
	if fight > fights:
		draw_colored_polygon(rhombus, Color(HangarArt.SCREEN_LINE, 0.85))
	elif fight == fights:
		draw_colored_polygon(rhombus, Color(RivalRow.BOSS_BEAM, 0.45 + 0.5 * pulse))
	rhombus.append(rhombus[0])
	draw_polyline(rhombus, Color(RivalRow.BOSS_BEAM, 0.9), 1.5, true)


## Sitio de los canales y de las flechas del combate libre.
func _layout_zones() -> void:
	_zones.clear()
	var screen := _screen()
	var channels := MissionBrief.CHANNELS
	var gap := 6.0
	var w := (screen.size.x - 16.0 - gap * (channels.size() - 1)) / channels.size()
	for i in channels.size():
		_zones["tab:" + channels[i]] = Rect2(
			screen.position.x + 8.0 + i * (w + gap), screen.end.y - TAB_HEIGHT - 5.0, w, TAB_HEIGHT
		)
	var pickers: Array = state.get("pickers", [])
	if pickers.is_empty():
		return
	var feed := _feed_rect()
	var left := feed.end.x + 9.0
	var right := screen.end.x - 8.0
	var y := feed.position.y + 38.0
	for picker: Dictionary in pickers:
		var key := str(picker["key"])
		_zones["pick:%s:-1" % key] = Rect2(left, y, 20.0, 20.0)
		_zones["pick:%s:1" % key] = Rect2(right - 20.0, y, 20.0, 20.0)
		y += 24.0


## Los tres canales, como teclas encendidas del propio monitor.
func _draw_tabs() -> void:
	var current := str(state.get("channel", "campaign"))
	for channel in MissionBrief.CHANNELS:
		var rect: Rect2 = _zones["tab:" + channel]
		var on := channel == current
		var hot := _hover == "tab:" + channel
		var line := HangarArt.SCREEN_LINE
		draw_rect(rect, Color(line, 0.75 if on else (0.22 if hot else 0.08)))
		draw_rect(rect, Color(GOLD if hot and not on else line, 0.9), false, 1.0)
		if on:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), Color(1, 1, 1, 0.5))
		_text(
			Vector2(rect.position.x, rect.position.y + 15.0),
			Txt.t(TAB_KEYS[channel]),
			rect.size.x,
			11,
			HangarArt.SCREEN.darkened(0.4) if on else HangarArt.SCREEN_TEXT,
			HORIZONTAL_ALIGNMENT_CENTER,
			not on
		)
	# Combate libre: cada cosa que se elige, entre sus dos flechas.
	for picker: Dictionary in state.get("pickers", []):
		var key := str(picker["key"])
		var less: Rect2 = _zones["pick:%s:-1" % key]
		var more: Rect2 = _zones["pick:%s:1" % key]
		_draw_arrow(less, -1.0, _hover == "pick:%s:-1" % key)
		_draw_arrow(more, 1.0, _hover == "pick:%s:1" % key)
		var between := Rect2(less.end.x, less.position.y, more.position.x - less.end.x, less.size.y)
		draw_rect(between.grow_individual(-3, 0, -3, 0), Color(HangarArt.SCREEN_LINE, 0.1))
		_text(
			Vector2(between.position.x, between.position.y + 14.0),
			str(picker["value"]),
			between.size.x,
			11,
			HangarArt.SCREEN_TEXT,
			HORIZONTAL_ALIGNMENT_CENTER
		)


func _draw_arrow(rect: Rect2, side: float, hot: bool) -> void:
	var color := GOLD if hot else HangarArt.SCREEN_LINE
	draw_rect(rect, Color(color, 0.3 if hot else 0.12))
	draw_rect(rect, Color(color, 0.9), false, 1.0)
	var c := rect.get_center()
	draw_colored_polygon(
		PackedVector2Array(
			[
				c + Vector2(side * 5.0, 0),
				c + Vector2(-side * 4.0, -6.0),
				c + Vector2(-side * 4.0, 6.0)
			]
		),
		color
	)


func _text(
	at: Vector2,
	text: String,
	width: float,
	font_size: int,
	color: Color,
	align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
	shadow: bool = true
) -> void:
	if shadow:
		draw_string(_font, at + Vector2(1, 1), text, align, width, font_size, Color(0, 0, 0, 0.6))
	draw_string(_font, at, text, align, width, font_size, color)
