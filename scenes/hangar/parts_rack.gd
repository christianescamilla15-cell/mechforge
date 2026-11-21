class_name PartsRack
extends Control
## El catalogo de piezas de la computadora del taller (LoadoutScreen): la
## mitad de la pantalla donde se despliegan las piezas que caben en la
## casilla elegida del plano, "por tipo" (decision del usuario, 2026-11-21,
## OBS-030: "se te va a desplegar a un lado de esa pantalla las armas
## disponibles"). Las tuyas, solidas; las que vende la tienda, como
## hologramas con su precio.
## - pulsar una tuya la monta; pulsar la que ya llevas ahi la quita;
## - pulsar un holograma lo deja armado y una segunda pulsacion lo compra;
## - la rueda del raton (o sus flechas) pasa las filas;
## - cada tipo de pieza ("hojas", "cortas"...) lleva su rotulo en la primera.
## Hasta el 2026-11-21 era un tablero que colgaba de un riel junto al robot;
## con `embedded` (como va ahora) no tiene riel ni rueda: es parte de la
## pantalla que lo contiene.
## Abajo, su lector: la ficha de la pieza bajo el raton o, si no hay, la del
## hueco, con la tecla de subirla de nivel o transformarla. Y al pie, la
## lectura del robot (peso, vida, energia, calor, resistencias): al pasar el
## raton por una pieza ensena lo que quedaria con ella puesta y cuanto cambia.
##
## Ensena un estado (WorkshopBrief.rack) y avisa de lo que se pulsa; no
## decide nada.

## Una pieza tuya: montarla (o quitarla si es la que ya esta).
signal chosen(id: String)
## Un holograma de la tienda, confirmado.
signal bought(id: String)
signal hovered(id: String, inside: bool)
## La tecla del lector: subir de nivel o transformar la pieza del hueco.
signal upgrade_pressed
## Se pulso una muestra de color: pintar con el la pieza del hueco.
signal paint_picked(id: String)

const COLUMNS := 4
## Alto minimo de una fila: caben las que quepan y se reparten el sitio.
const MIN_CELL := 60.0
const RAIL_HEIGHT := 14.0
const HEAD_HEIGHT := 24.0
const PAGER_HEIGHT := 12.0
const READER_HEIGHT := 84.0
## Las muestras de pintura, en la cabecera.
const SWATCH := Vector2(22.0, 13.0)
const SWATCH_GAP := 6.0
const STATS_HEIGHT := 56.0
const STATS_COLUMNS := 3
const GOOD := Color("7dff9b")
const MARGIN := 8.0
const SLIDE_SECONDS := 0.3
const SCROLL_SECONDS := 0.16
## Lo que late en el tablero (los hologramas, el armado) va despacio: con
## repintarlo unas 30 veces por segundo sobra.
const REDRAW_SECONDS := 1.0 / 30.0
const GOLD := Color("ffd36b")
const BAD := Color("ff7d6b")
const MUTED := Color("8fa3b8")
const HOLO := Color("57d3ff")
const BOARD := Color(0.055, 0.08, 0.115, 0.93)

## Lo que ensena: {"slot", "title", "locked", "hint", "cells", "parts":
## [{"id", "item", "group" (su tipo), "owned", "mounted", "detail", "stats",
## "price", "reason", "note"}], "mounted": {} o {"item", "detail", "stats"},
## "key": {} o {"label", "enabled", "reason"}, "paints": [{"id", "color",
## "selected"}] (los colores con los que se pinta la pieza del hueco; vacio
## si no se pinta)}.
var state: Dictionary = {}:
	set(value):
		var same := str(value.get("slot", "")) == str(state.get("slot", ""))
		state = value
		_parts.assign(value.get("parts", []))
		if not same:
			_row = 0
			_shown_row = 0.0
		_row = clampi(_row, 0, _max_row())
		if _armed != "" and _index_of(_armed) < 0:
			_armed = ""
		queue_redraw()
## La lectura del robot: [{"label", "value", "delta", "better"}]. Cambia
## con la pieza bajo el raton, sin tocar lo demas.
var stats: Array = []:
	set(value):
		stats = value
		queue_redraw()
## Dentro de una pantalla (LoadoutScreen): sin riel, sin tablero perforado y
## sin entrar rodando; su sitio lo pone quien lo contiene.
var embedded := false
## Donde cuelga cuando esta fuera (lo pone quien lo contiene).
var home := Rect2():
	set(value):
		home = value
		size = value.size
		_place()

var _parts: Array[Dictionary] = []
var _font: Font
var _time := 0.0
var _since_draw := 0.0
## Zona bajo el raton: "", "part:<n>", "key", "up" o "down".
var _hover := ""
## Holograma armado: la siguiente pulsacion lo compra.
var _armed := ""
var _row := 0
var _shown_row := 0.0
## Cuanto esta fuera: 0 = recogido tras el borde; 1 = colgado en su sitio.
var _out := 0.0:
	set(value):
		_out = value
		_place()
## Si esta sacado (o saliendo); al recogerlo pasa a false enseguida.
var _wanted := false
var _slide: Tween
var _scroll: Tween


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
	# Al pasar filas, cada cuadro; si no, despacio.
	var scrolling := _scroll != null and _scroll.is_running()
	if scrolling or _since_draw >= REDRAW_SECONDS:
		_since_draw = 0.0
		queue_redraw()


func _place() -> void:
	var offset := 0.0 if embedded else (1.0 - _out) * (home.size.x + 30.0)
	position = home.position + Vector2(offset, 0.0)


# --- Entrar y salir ---------------------------------------------------------------


## Lo saca (o cambia lo que ensena). `instant`: sin rodar.
func open(p_state: Dictionary, instant: bool = false) -> void:
	state = p_state
	if _wanted and visible:
		return
	_wanted = true
	visible = true
	_tween_out(1.0, 0.0 if instant or embedded else SLIDE_SECONDS)


## Lo recoge tras el borde.
func close(instant: bool = false) -> void:
	if not _wanted:
		return
	_wanted = false
	_armed = ""
	_set_hover("")
	_tween_out(0.0, 0.0 if instant or embedded else SLIDE_SECONDS * 0.8)


func is_open() -> bool:
	return _wanted


func _tween_out(to: float, seconds: float) -> void:
	if _slide != null:
		_slide.kill()
	if seconds <= 0.0:
		_out = to
		visible = to > 0.0
		return
	_slide = create_tween().set_trans(Tween.TRANS_CUBIC)
	_slide.set_ease(Tween.EASE_OUT if to > 0.5 else Tween.EASE_IN)
	_slide.tween_property(self, "_out", to, seconds)
	if to <= 0.0:
		_slide.tween_callback(func() -> void: visible = false)


# --- Medidas ----------------------------------------------------------------------


func _grid_rect() -> Rect2:
	var top := RAIL_HEIGHT + HEAD_HEIGHT
	var height := size.y - top - PAGER_HEIGHT - READER_HEIGHT - STATS_HEIGHT - MARGIN
	return Rect2(MARGIN, top, size.x - MARGIN * 2.0, maxf(height, MIN_CELL))


func _visible_rows() -> int:
	return maxi(1, int(_grid_rect().size.y / MIN_CELL))


## Alto de una fila: las que caben se reparten el tablero.
func _cell_height() -> float:
	return _grid_rect().size.y / _visible_rows()


func _rows() -> int:
	return int(ceil(_parts.size() / float(COLUMNS)))


func _max_row() -> int:
	return maxi(0, _rows() - _visible_rows())


## Rectangulo de una pieza en el tablero (vacio si su fila no se ve).
func part_rect(index: int) -> Rect2:
	var grid := _grid_rect()
	var row := index / COLUMNS - _row
	if index < 0 or index >= _parts.size() or row < 0 or row >= _visible_rows():
		return Rect2()
	var w := grid.size.x / COLUMNS
	return (
		Rect2(
			grid.position + Vector2((index % COLUMNS) * w, row * _cell_height()),
			Vector2(w, _cell_height())
		)
		. grow(-2.0)
	)


func _reader_rect() -> Rect2:
	var top := size.y - READER_HEIGHT - STATS_HEIGHT - MARGIN
	return Rect2(MARGIN, top, size.x - MARGIN * 2.0, READER_HEIGHT)


func _stats_rect() -> Rect2:
	var top := size.y - STATS_HEIGHT - MARGIN + 4.0
	return Rect2(MARGIN, top, size.x - MARGIN * 2.0, STATS_HEIGHT - 4.0)


func _key_rect() -> Rect2:
	var reader := _reader_rect()
	return Rect2(reader.end.x - 138.0, reader.position.y + 8.0, 130.0, 28.0)


func _pager_rect(zone: String) -> Rect2:
	var grid := _grid_rect()
	var y := grid.end.y
	var x := size.x * 0.5 + (-34.0 if zone == "up" else 10.0)
	return Rect2(x, y - 1.0, 24.0, PAGER_HEIGHT + 2.0)


## Las muestras de pintura de la cabecera, en fila y centradas.
func _paints() -> Array:
	return state.get("paints", [])


func paint_rect(index: int) -> Rect2:
	var count := _paints().size()
	var wide := count * SWATCH.x + (count - 1) * SWATCH_GAP
	var x := size.x * 0.5 - wide * 0.5 + 34.0 + index * (SWATCH.x + SWATCH_GAP)
	return Rect2(Vector2(x, RAIL_HEIGHT + 4.0), SWATCH)


## Zona bajo un punto: "part:<n>", "paint:<n>", "key", "up", "down" o "".
func zone_at(at: Vector2) -> String:
	for index in _paints().size():
		if paint_rect(index).grow(2.0).has_point(at):
			return "paint:%d" % index
	for index in _parts.size():
		if part_rect(index).has_point(at):
			return "part:%d" % index
	if _has_key() and _key_rect().has_point(at):
		return "key"
	if _max_row() > 0:
		for zone: String in ["up", "down"]:
			if _pager_rect(zone).grow(4.0).has_point(at):
				return zone
	return ""


## Pieza de una zona; vacio si la zona no es una pieza.
func _part_of(zone: String) -> Dictionary:
	if not zone.begins_with("part:"):
		return {}
	var index := int(zone.trim_prefix("part:"))
	return _parts[index] if index >= 0 and index < _parts.size() else {}


func _index_of(id: String) -> int:
	for index in _parts.size():
		if str(_parts[index]["id"]) == id:
			return index
	return -1


## Indice en el tablero de una pieza (para las pruebas); -1 si no esta.
func index_of(id: String) -> int:
	return _index_of(id)


func armed_id() -> String:
	return _armed


func _has_key() -> bool:
	return not (state.get("key", {}) as Dictionary).is_empty() and _part_of(_hover).is_empty()


# --- Raton ------------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hover(zone_at(motion.position))
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	accept_event()
	match click.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			scroll_rows(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			scroll_rows(1)
		MOUSE_BUTTON_LEFT:
			_press(zone_at(click.position))


func _press(zone: String) -> void:
	if zone == "up" or zone == "down":
		scroll_rows(-1 if zone == "up" else 1)
		return
	if zone.begins_with("paint:"):
		var paint: Dictionary = _paints()[int(zone.trim_prefix("paint:"))]
		if not bool(paint["selected"]):
			paint_picked.emit(str(paint["id"]))
		return
	if zone == "key":
		var key: Dictionary = state.get("key", {})
		if bool(key.get("enabled", false)):
			upgrade_pressed.emit()
		else:
			Sfx.play("ui_cerrar")
		return
	var part := _part_of(zone)
	if part.is_empty():
		_armed = ""
		return
	var id := str(part["id"])
	if bool(part["owned"]):
		_armed = ""
		chosen.emit(id)
	elif str(part.get("reason", "")) != "":
		_armed = ""
		Sfx.play("ui_cerrar")
	elif _armed == id:
		_armed = ""
		bought.emit(id)
	else:
		# La primera pulsacion solo lo deja armado.
		_armed = id
		Sfx.play("ui_habilidad")
	queue_redraw()


## Pasa filas del tablero.
func scroll_rows(step: int) -> void:
	var to := clampi(_row + step, 0, _max_row())
	if to == _row:
		return
	_row = to
	Sfx.play("ui_tic")
	if _scroll != null:
		_scroll.kill()
	_scroll = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_scroll.tween_property(self, "_shown_row", float(to), SCROLL_SECONDS)


func _set_hover(zone: String) -> void:
	if zone == _hover:
		return
	var before := _part_of(_hover)
	_hover = zone
	var now := _part_of(zone)
	if not before.is_empty():
		hovered.emit(str(before["id"]), false)
	if not now.is_empty():
		hovered.emit(str(now["id"]), true)
	if zone != "":
		Sfx.play("ui_tic")
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if zone != "" else Control.CURSOR_ARROW
	)
	queue_redraw()


# --- Dibujo -----------------------------------------------------------------------


func _draw() -> void:
	_draw_board()
	_draw_head()
	var slide := (_shown_row - _row) * _cell_height()
	for index in _parts.size():
		var rect := part_rect(index)
		if rect.size != Vector2.ZERO:
			_draw_part(index, rect, slide)
	_draw_pager()
	_draw_reader()
	_draw_stats()


## El panel: riel con sus dos carros, tablero perforado y borde.
func _draw_board() -> void:
	if embedded:
		# Dentro de una pantalla solo queda un marco fino sobre el cristal.
		var frame := Rect2(Vector2.ZERO, size)
		draw_rect(frame, Color(HOLO, 0.05))
		draw_rect(frame, Color(HOLO, 0.35), false, 1.0)
		return
	var c := get_canvas_item()
	# El riel sigue hasta el borde de la pantalla.
	draw_rect(Rect2(-12.0, 2.0, size.x + 60.0, 5.0), Color("0e141c"))
	draw_line(Vector2(-12.0, 2.5), Vector2(size.x + 48.0, 2.5), Color(1, 1, 1, 0.14), 1.0)
	for x: float in [size.x * 0.16, size.x * 0.84]:
		draw_rect(Rect2(x - 11.0, 0.0, 22.0, 9.0), Color("2a3546"))
		draw_rect(Rect2(x - 11.0, 0.0, 22.0, 9.0), Color("5a7da6", 0.7), false, 1.0)
		draw_rect(Rect2(x - 2.5, 9.0, 5.0, RAIL_HEIGHT - 6.0), Color("3a4656"))
	var board := Rect2(0.0, RAIL_HEIGHT - 2.0, size.x, size.y - RAIL_HEIGHT + 2.0)
	var plate := TechStyle.plate(BOARD, Color("4f6380"), 0.0, 10.0)
	plate.groove = false
	plate.shadow = 7.0
	plate.bolts = false
	plate.draw(c, board)
	# Agujeros del tablero, entre las piezas.
	var grid := _grid_rect()
	var step := grid.size.x / (COLUMNS * 4.0)
	var y := grid.position.y + 6.0
	while y < grid.end.y:
		var x := grid.position.x + step * 0.5
		while x < grid.end.x:
			draw_rect(Rect2(x - 1.0, y - 1.0, 2.0, 2.0), Color(0, 0, 0, 0.45))
			x += step
		y += _cell_height() / 4.0


## Cabecera: el hueco y, a la derecha, tus celdas (aqui se compra).
func _draw_head() -> void:
	var y := RAIL_HEIGHT + 15.0
	HangarProps.text(
		self,
		_font,
		Vector2(MARGIN + 4.0, y),
		str(state.get("title", "")).to_upper(),
		220.0,
		13,
		GOLD
	)
	var cells := HangarProps.thousands(int(state.get("cells", 0)))
	var wide := _font.get_string_size(cells, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var unit := Txt.t("hud_cells")
	var unit_wide := _font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var x := size.x - MARGIN - 6.0 - wide - unit_wide - 4.0
	HangarProps.text(self, _font, Vector2(x, y), cells, wide + 2.0, 12, HangarProps.SCREEN_TEXT)
	HangarProps.text(self, _font, Vector2(x + wide + 4.0, y), unit, unit_wide + 2.0, 9, MUTED)
	_draw_paints(y)
	draw_line(
		Vector2(MARGIN, RAIL_HEIGHT + HEAD_HEIGHT - 3.0),
		Vector2(size.x - MARGIN, RAIL_HEIGHT + HEAD_HEIGHT - 3.0),
		Color("4f6380", 0.6),
		1.0
	)


## Las muestras de pintura de la pieza del hueco: la que lleva, con su marco
## dorado; la del raton, encendida.
func _draw_paints(baseline: float) -> void:
	var paints := _paints()
	if paints.is_empty():
		return
	var label := Txt.t("loadout_paint")
	var label_wide := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var first := paint_rect(0)
	HangarProps.text(
		self,
		_font,
		Vector2(first.position.x - label_wide - 8.0, baseline),
		label,
		label_wide + 2.0,
		9,
		MUTED
	)
	for index in paints.size():
		var rect := paint_rect(index)
		var color: Color = paints[index]["color"]
		var lit := _hover == "paint:%d" % index
		draw_rect(rect, color if lit else color.darkened(0.12))
		draw_rect(rect, Color(0, 0, 0, 0.55), false, 1.0)
		if bool(paints[index]["selected"]):
			draw_rect(rect.grow(2.5), GOLD, false, 1.5)
		elif lit:
			draw_rect(rect.grow(2.5), Color(HOLO, 0.8), false, 1.0)


## Una pieza colgada de su gancho: solida si es tuya, holograma con su
## precio si es de la tienda.
func _draw_part(index: int, rect: Rect2, slide: float) -> void:
	var part := _parts[index]
	var item: ItemDef = part["item"]
	var owned := bool(part["owned"])
	var mounted := bool(part.get("mounted", false))
	var blocked := str(part.get("reason", "")) != ""
	var hover := _hover == "part:%d" % index
	var armed := _armed == str(part["id"])
	var fade := clampf(1.0 - absf(slide) / _cell_height(), 0.0, 1.0)
	rect.position.y += slide
	var tier := PartIcon.TIER_COLORS[item.tier]
	# El hueco del tablero donde cuelga.
	var back := Color(0.1, 0.14, 0.2, 0.75 if owned else 0.35)
	if hover:
		back = back.lightened(0.12)
	draw_rect(rect, Color(back, back.a * fade))
	var edge := tier.darkened(0.25) if owned else Color(HOLO, 0.45)
	if mounted:
		edge = GOLD
	if armed:
		edge = Color(GOLD, 0.6 + 0.4 * sin(_time * 8.0))
	elif hover:
		edge = edge.lightened(0.4)
	draw_rect(rect, Color(edge, edge.a * fade), false, 2.0 if mounted or armed or hover else 1.0)
	if not embedded:
		# El gancho.
		var hook := Vector2(rect.get_center().x, rect.position.y)
		draw_line(hook, hook + Vector2(0, 5), Color("8fa3b8", 0.8 * fade), 2.0)
	var well := Rect2(rect.position + Vector2(4, 6), rect.size - Vector2(8, 22))
	# El rotulo de su tipo, en la primera pieza de cada uno.
	var group := str(part.get("group", ""))
	if group != "" and (index == 0 or str(_parts[index - 1].get("group", "")) != group):
		var tag := Vector2(rect.position.x + 4.0, rect.position.y + 10.0)
		HangarProps.text(
			self, _font, tag, group.to_upper(), rect.size.x - 8.0, 8, Color(MUTED, fade)
		)
	if owned:
		PartIcon.paint(self, well, item, fade, Color.WHITE, int(part.get("paint", -1)))
	else:
		# Holograma: tenido de azul, con lineas de barrido y un parpadeo.
		var flicker := 0.72 + 0.1 * sin(_time * 5.0 + index * 1.7)
		var alpha := (0.4 if blocked else flicker) * fade
		PartIcon.paint(self, well, item, alpha, Color(0.55, 0.9, 1.0))
		var line := well.position.y + fposmod(_time * 22.0 + index * 9.0, 4.0)
		while line < well.end.y:
			draw_line(
				Vector2(well.position.x, line),
				Vector2(well.end.x, line),
				Color(0.02, 0.05, 0.08, 0.3 * fade),
				1.0
			)
			line += 4.0
	# Al pie: su clase y nivel, o su precio.
	var foot := Vector2(rect.position.x + 5.0, rect.end.y - 5.0)
	if owned:
		var label := Txt.t("workshop_mounted").to_upper() if mounted else str(part["detail"])
		var tone := GOLD if mounted else tier
		HangarProps.text(self, _font, foot, label, rect.size.x - 10.0, 9, Color(tone, fade))
	else:
		var price := HangarProps.thousands(int(part["price"]))
		var tone := BAD if blocked else GOLD
		HangarProps.text(self, _font, foot, price, rect.size.x - 22.0, 10, Color(tone, fade))
		_draw_cell_mark(Vector2(rect.end.x - 10.0, rect.end.y - 9.0), Color(tone, fade))
	if str(part.get("note", "")) != "":
		# Tu nivel aun no abre su hueco.
		draw_circle(rect.position + Vector2(9, 10), 3.0, Color(BAD, 0.8 * fade))


## La marca de las celdas: un rombo.
func _draw_cell_mark(at: Vector2, color: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array(
			[at + Vector2(0, -4), at + Vector2(4, 0), at + Vector2(0, 4), at + Vector2(-4, 0)]
		),
		color
	)


## Flechas para pasar filas y una raya que dice por donde vas.
func _draw_pager() -> void:
	if _max_row() <= 0:
		return
	for zone: String in ["up", "down"]:
		var rect := _pager_rect(zone)
		var can := _row > 0 if zone == "up" else _row < _max_row()
		var color := Color(GOLD if _hover == zone else HOLO, 0.95 if can else 0.25)
		var mid := rect.get_center()
		var dir := -1.0 if zone == "up" else 1.0
		draw_colored_polygon(
			PackedVector2Array(
				[
					mid + Vector2(-7, -3.5 * dir),
					mid + Vector2(7, -3.5 * dir),
					mid + Vector2(0, 4.0 * dir)
				]
			),
			color
		)
	var grid := _grid_rect()
	var track := Rect2(grid.end.x - 3.0, grid.position.y, 3.0, grid.size.y)
	draw_rect(track, Color(0, 0, 0, 0.5))
	var share := float(_visible_rows()) / _rows()
	draw_rect(
		Rect2(
			track.position.x,
			track.position.y + track.size.y * _shown_row / _rows(),
			3.0,
			track.size.y * share
		),
		Color(HOLO, 0.8)
	)


## El lector: la ficha de la pieza bajo el raton o la del hueco.
func _draw_reader() -> void:
	var reader := _reader_rect()
	draw_rect(reader.grow(2.0), Color("0a0f16"))
	draw_rect(reader, HangarArt.SCREEN)
	var line := reader.position.y
	while line < reader.end.y:
		draw_line(
			Vector2(reader.position.x, line), Vector2(reader.end.x, line), Color(0, 0, 0, 0.16), 1.0
		)
		line += 3.0
	draw_rect(reader, Color(HangarArt.SCREEN_LINE, 0.5), false, 1.0)
	var at := reader.position + Vector2(9, 0)
	var wide := reader.size.x - 18.0
	var part := _part_of(_hover)
	if not part.is_empty():
		_draw_card(at, wide, part["item"], _part_detail(part), str(part["stats"]), part)
		return
	if str(state.get("locked", "")) != "":
		var locked := Txt.t("workshop_locked", [str(state["locked"])])
		HangarProps.text(self, _font, at + Vector2(0, 22), locked, wide, 12, MUTED)
		return
	var mounted: Dictionary = state.get("mounted", {})
	if mounted.is_empty():
		_wrapped(at + Vector2(0, 22), str(state.get("hint", "")), wide, 12, MUTED, 4)
		return
	var key: Dictionary = state.get("key", {})
	var room := wide - (142.0 if not key.is_empty() else 0.0)
	_draw_card(at, room, mounted["item"], [str(mounted["detail"]), ""], str(mounted["stats"]), {})
	if not key.is_empty():
		_draw_key(key)


## Linea de detalle de una pieza del tablero y su color ("" = el de su clase).
func _part_detail(part: Dictionary) -> Array:
	var detail := str(part["detail"])
	if bool(part["owned"]):
		if bool(part.get("mounted", false)):
			return [detail + " · " + Txt.t("rack_click_remove"), "gold"]
		return [detail + " · " + Txt.t("rack_click_mount"), ""]
	if str(part.get("reason", "")) != "":
		return ["%s · %s" % [Txt.t("store_buy", [int(part["price"])]), str(part["reason"])], "bad"]
	if _armed == str(part["id"]):
		return [Txt.t("rack_buy_confirm", [int(part["price"])]), "gold"]
	var line := "%s · %s" % [detail, Txt.t("store_buy", [int(part["price"])])]
	if str(part.get("note", "")) != "":
		line += " · " + str(part["note"])
	return [line, ""]


## Una ficha: nombre, linea de detalle y lo que hace.
func _draw_card(
	at: Vector2, wide: float, item: ItemDef, detail: Array, effect: String, part: Dictionary
) -> void:
	HangarProps.text(self, _font, at + Vector2(0, 18), item.display_name, wide, 14, Color.WHITE)
	var tone := PartIcon.TIER_COLORS[item.tier]
	match str(detail[1]):
		"gold":
			tone = GOLD
		"bad":
			tone = BAD
	if not part.is_empty() and _armed == str(part["id"]):
		tone = Color(GOLD, 0.7 + 0.3 * sin(_time * 8.0))
	HangarProps.text(self, _font, at + Vector2(0, 33), str(detail[0]), wide, 11, tone)
	_wrapped(at + Vector2(0, 48), effect, wide, 10, HangarProps.SCREEN_TEXT, 3)


func _wrapped(
	at: Vector2, text: String, wide: float, font_size: int, color: Color, lines: int
) -> void:
	draw_multiline_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size, lines, color)


## La tecla del lector: subir de nivel o transformar.
func _draw_key(key: Dictionary) -> void:
	var rect := _key_rect()
	var enabled := bool(key.get("enabled", false))
	var hover := _hover == "key"
	var accent := GOLD if enabled else Color("3c4c62")
	var plate := TechStyle.plate(Color("223047") if enabled else Color("1a212c"), accent, 0.0, 6.0)
	plate.groove = false
	plate.bolts = false
	plate.glow = 0.5 if hover and enabled else 0.0
	plate.shadow = 3.0
	plate.draw(get_canvas_item(), rect)
	var tone := Color.WHITE if enabled else MUTED
	HangarProps.text(
		self, _font, rect.position + Vector2(0, 18), str(key["label"]), rect.size.x, 12, tone, true
	)
	# Debajo: lo que cambia al subirla o, si no se puede, por que.
	var below := rect.position + Vector2(0, 42)
	if not enabled and str(key.get("reason", "")) != "":
		_wrapped(below, str(key["reason"]), rect.size.x, 10, BAD, 3)
	elif str(key.get("gain", "")) != "":
		_wrapped(below, str(key["gain"]), rect.size.x, 10, GOOD, 3)


## Al pie, la lectura del robot: una casilla por estadistica. Al comparar
## una pieza, el numero es el que quedaria y a su lado va lo que cambia.
func _draw_stats() -> void:
	if stats.is_empty():
		return
	var rect := _stats_rect()
	var rows := int(ceil(stats.size() / float(STATS_COLUMNS)))
	var w := rect.size.x / STATS_COLUMNS
	var h := rect.size.y / maxf(rows, 1.0)
	for i in stats.size():
		var row: Dictionary = stats[i]
		var cell := Rect2(
			rect.position + Vector2((i % STATS_COLUMNS) * w, (i / STATS_COLUMNS) * h),
			Vector2(w - 3.0, h - 3.0)
		)
		draw_rect(cell, Color(0, 0, 0, 0.35))
		var base := Vector2(cell.position.x + 4.0, cell.end.y - 5.0)
		draw_string(
			_font, base, str(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, cell.size.x - 30.0, 9, MUTED
		)
		var delta := int(row["delta"])
		var tone := HangarProps.SCREEN_TEXT
		var value := str(int(row["value"]) + delta)
		if delta != 0:
			tone = GOOD if bool(row["better"]) else BAD
			value = "%s %+d" % [value, delta]
			draw_rect(cell, Color(tone, 0.6), false, 1.0)
		draw_string(_font, base, value, HORIZONTAL_ALIGNMENT_RIGHT, cell.size.x - 8.0, 10, tone)
