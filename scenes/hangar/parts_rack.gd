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
## Desde el 2026-11-21 (OBS-039, del usuario: "me gustaria que fuera mas
## inmersivo... como Resident Evil") se ve como un maletin de espuma: cada
## pieza en su hueco recortado, las de la tienda proyectadas en el suyo con su
## precio. Arriba, la vitrina (PartShowcase): la pieza bajo el raton (o la del
## hueco) en grande, bajo un foco, con su ficha de barras comparada con la que
## llevas, y la tecla de subirla de nivel o transformarla. Entre las dos, una
## linea de la terminal que dice, letra a letra, que hace pulsarla. Y al pie,
## la lectura del robot (peso, vida, energia, calor, resistencias): al pasar
## el raton por una pieza ensena lo que quedaria con ella puesta y cuanto
## cambia.
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
## La cabecera: el hueco y, debajo, que armas caben en el.
const HEAD_HEIGHT := 36.0
const PAGER_HEIGHT := 12.0
## La vitrina: parte del alto que ocupa (con su tope) y del ancho que es
## pedestal; el resto del ancho es su ficha.
const SHOWCASE_SHARE := 0.42
const SHOWCASE_MIN := 150.0
const SHOWCASE_MAX := 330.0
const STAGE_SHARE := 0.54
## Alto de la cabecera de la ficha (nombre y clase).
const SHEET_HEAD := 40.0
## La linea de la terminal y cuantas letras escribe por segundo.
const LINE_HEIGHT := 22.0
const TYPE_SPEED := 90.0
## Borde del maletin alrededor de la espuma.
const CASE_PAD := 10.0
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
const TEXT := Color("eef6ff")
## La espuma del maletin y el fondo de cada hueco recortado.
const FOAM := Color("15191e")
const CUT := Color("07090c")
const LAMP := Color("fff3dc")

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
## Con `embedded`, el marco fino de la pantalla; dentro del estuche junto a la
## pieza (PartsCase, OBS-048) no lo lleva: el borde es el del estuche.
var framed := true
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
## La linea de la terminal: lo que escribe y desde cuando.
var _typed := ""
var _typed_at := 0.0
var _cut := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = get_theme_default_font()
	mouse_exited.connect(_set_hover.bind(""))
	_cut.set_corner_radius_all(7)
	_cut.corner_detail = 4
	_cut.set_border_width_all(1)
	_cut.anti_aliasing = true


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


## Lo de arriba que no es del panel: el riel, si cuelga de el.
func _top() -> float:
	return 0.0 if embedded else RAIL_HEIGHT


func _showcase_rect() -> Rect2:
	var high := clampf(size.y * SHOWCASE_SHARE, SHOWCASE_MIN, SHOWCASE_MAX)
	return Rect2(MARGIN, _top() + HEAD_HEIGHT, size.x - MARGIN * 2.0, high)


## El pedestal de la vitrina, a la izquierda.
func _stage_rect() -> Rect2:
	var show := _showcase_rect()
	return Rect2(show.position, Vector2(show.size.x * STAGE_SHARE, show.size.y))


## La ficha de la vitrina, a la derecha del pedestal.
func _sheet_rect() -> Rect2:
	var show := _showcase_rect()
	var left := _stage_rect().end.x + 12.0
	return Rect2(left, show.position.y + 2.0, show.end.x - left, show.size.y - 2.0)


func _line_rect() -> Rect2:
	return Rect2(MARGIN, _showcase_rect().end.y + 6.0, size.x - MARGIN * 2.0, LINE_HEIGHT)


## Donde acaba la vitrina con su linea de la terminal (lo de arriba del
## maletin): ahi va la bisagra del estuche que lo contiene.
func lid_bottom() -> float:
	return _line_rect().end.y + 3.0


## El maletin: de la linea de la terminal a la lectura del robot.
func _case_rect() -> Rect2:
	var top := _line_rect().end.y + 6.0
	var bottom := size.y - STATS_HEIGHT - MARGIN
	var least := MIN_CELL + CASE_PAD * 2.0 + PAGER_HEIGHT
	return Rect2(MARGIN, top, size.x - MARGIN * 2.0, maxf(bottom - top, least))


## La espuma, donde van los huecos de las piezas.
func _grid_rect() -> Rect2:
	var foam := _case_rect().grow(-CASE_PAD)
	return Rect2(foam.position, Vector2(foam.size.x, foam.size.y - PAGER_HEIGHT))


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


func _stats_rect() -> Rect2:
	var top := size.y - STATS_HEIGHT - MARGIN + 4.0
	return Rect2(MARGIN, top, size.x - MARGIN * 2.0, STATS_HEIGHT - 4.0)


## La tecla de subir o transformar, al pie de la ficha: tan ancha como su
## texto ("Hacerla Unica · 1 nucleo" no cabia en un estuche estrecho).
func _key_rect() -> Rect2:
	var sheet := _sheet_rect()
	var label := str(state.get("key", {}).get("label", ""))
	var wide := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0
	wide = clampf(wide, 96.0, sheet.size.x - 4.0)
	return Rect2(sheet.end.x - wide - 4.0, sheet.end.y - 32.0, wide, 28.0)


## El tamano de letra (de `biggest` a `smallest`) con el que un texto cabe
## en ese ancho.
func _fitting(text: String, wide: float, biggest: int, smallest: int) -> int:
	var font_size := biggest
	while font_size > smallest:
		if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= wide:
			break
		font_size -= 1
	return font_size


func _pager_rect(zone: String) -> Rect2:
	var grid := _grid_rect()
	var y := grid.end.y
	var x := size.x * 0.5 + (-34.0 if zone == "up" else 10.0)
	return Rect2(x, y, 24.0, PAGER_HEIGHT)


## Las muestras de pintura de la cabecera, en fila y centradas.
func _paints() -> Array:
	return state.get("paints", [])


func paint_rect(index: int) -> Rect2:
	var count := _paints().size()
	var wide := count * SWATCH.x + (count - 1) * SWATCH_GAP
	var x := size.x * 0.5 - wide * 0.5 + 34.0 + index * (SWATCH.x + SWATCH_GAP)
	return Rect2(Vector2(x, _top() + 6.0), SWATCH)


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
	if bool(part["owned"]) and str(part.get("reason", "")) != "":
		# Tuya, pero no se puede montar aqui (repite una resistencia).
		_armed = ""
		Sfx.play("ui_cerrar")
	elif bool(part["owned"]):
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
	_draw_showcase()
	_draw_terminal()
	_draw_case()
	var slide := (_shown_row - _row) * _cell_height()
	for index in _parts.size():
		var rect := part_rect(index)
		if rect.size != Vector2.ZERO:
			_draw_part(index, rect, slide)
	_draw_pager()
	_draw_stats()


## El panel: riel con sus dos carros, tablero perforado y borde.
func _draw_board() -> void:
	if embedded:
		if not framed:
			return
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


## Cabecera: el hueco y, debajo, que armas caben en el (OBS-038: "si es
## brazo... nada mas armas de mediano y corto alcance; parte superior
## unicamente armas de largo alcance"); a la derecha, tus celdas.
func _draw_head() -> void:
	var y := _top() + 16.0
	var title := str(state.get("title", "")).to_upper()
	HangarProps.text(self, _font, Vector2(MARGIN + 4.0, y), title, 220.0, 14, GOLD)
	var kind := str(state.get("kind", ""))
	var style := str(state.get("style", ""))
	if style != "":
		kind = style if kind == "" else "%s · %s" % [kind, style]
	if kind != "":
		var at := Vector2(MARGIN + 4.0, y + 14.0)
		HangarProps.text(self, _font, at, kind, size.x * 0.6, 10, MUTED)
	var cells := HangarProps.thousands(int(state.get("cells", 0)))
	var wide := _font.get_string_size(cells, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var unit := Txt.t("hud_cells")
	var unit_wide := _font.get_string_size(unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var x := size.x - MARGIN - 6.0 - wide - unit_wide - 4.0
	HangarProps.text(self, _font, Vector2(x, y), cells, wide + 2.0, 12, HangarProps.SCREEN_TEXT)
	HangarProps.text(self, _font, Vector2(x + wide + 4.0, y), unit, unit_wide + 2.0, 9, MUTED)
	_draw_paints(y)
	draw_line(
		Vector2(MARGIN, _top() + HEAD_HEIGHT - 4.0),
		Vector2(size.x - MARGIN, _top() + HEAD_HEIGHT - 4.0),
		Color("4f6380", 0.5),
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


## Una pieza en su hueco del maletin: solida si es tuya (y se levanta un
## poco bajo el raton), proyectada con su precio si es de la tienda.
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
	var cut := rect.grow(-3.0)
	# El hueco recortado: fondo hondo, sombra arriba y el labio de la espuma.
	var edge := Color(1, 1, 1, 0.07)
	if mounted:
		edge = GOLD
	if armed:
		edge = Color(GOLD, 0.6 + 0.4 * sin(_time * 8.0))
	elif hover:
		edge = Color(LAMP, 0.55)
	_cut.bg_color = Color(CUT.lightened(0.05 if hover else 0.0), 0.96 * fade)
	_cut.border_color = Color(edge, edge.a * fade)
	_cut.set_border_width_all(2 if mounted or armed else 1)
	draw_style_box(_cut, cut)
	draw_line(
		cut.position + Vector2(7.0, 2.5),
		Vector2(cut.end.x - 7.0, cut.position.y + 2.5),
		Color(0, 0, 0, 0.8 * fade),
		2.0
	)
	if hover:
		# La luz cae en el hueco que examinas.
		draw_rect(cut.grow(-3.0), Color(LAMP, 0.05 * fade))
	if not embedded:
		# El gancho.
		var hook := Vector2(rect.get_center().x, rect.position.y)
		draw_line(hook, hook + Vector2(0, 5), Color("8fa3b8", 0.8 * fade), 2.0)
	var well := Rect2(cut.position + Vector2(6, 8), cut.size - Vector2(12, 24))
	# El rotulo de su tipo, en la primera pieza de cada uno.
	var group := str(part.get("group", ""))
	if group != "" and (index == 0 or str(_parts[index - 1].get("group", "")) != group):
		var tag := Vector2(cut.position.x + 7.0, cut.position.y + 12.0)
		HangarProps.text(
			self, _font, tag, group.to_upper(), cut.size.x - 14.0, 8, Color(MUTED, fade)
		)
	if owned:
		if hover and not blocked:
			# Se levanta de la espuma.
			well = Rect2(well.position + Vector2(0, -3), well.size).grow(3.0)
		var shade := fade * (0.4 if blocked else 1.0)
		PartIcon.paint(self, well, item, shade, Color.WHITE, int(part.get("paint", -1)))
	else:
		# Proyectada: tenida de azul, con lineas de barrido y un parpadeo.
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
	var foot := Vector2(cut.position.x + 7.0, cut.end.y - 6.0)
	if owned:
		var label := Txt.t("workshop_mounted").to_upper() if mounted else str(part["detail"])
		var tone := GOLD if mounted else tier
		if not mounted and str(part.get("where", "")) != "":
			# Ya va en otro hueco de modulo: se dice cual.
			label = str(part["where"]).to_upper()
			tone = MUTED
		if blocked:
			tone = BAD
		HangarProps.text(self, _font, foot, label, cut.size.x - 14.0, 9, Color(tone, fade))
	else:
		var price := HangarProps.thousands(int(part["price"]))
		var tone := BAD if blocked else GOLD
		HangarProps.text(self, _font, foot, price, cut.size.x - 26.0, 10, Color(tone, fade))
		_draw_cell_mark(Vector2(cut.end.x - 12.0, cut.end.y - 10.0), Color(tone, fade))
	if str(part.get("note", "")) != "":
		# Tu nivel aun no abre su hueco.
		draw_circle(cut.position + Vector2(cut.size.x - 10.0, 10.0), 3.0, Color(BAD, 0.8 * fade))


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


# --- La vitrina, su ficha y la terminal ---------------------------------------------------


## Lo que ensena la vitrina: la pieza bajo el raton, la armada para comprar o,
## si no, la del hueco. {"item", "paint", "for_sale", "mounted", "detail",
## "price", "base" (la montada, para comparar; null si es ella)}; vacio si no
## hay nada que ensenar.
func _shown() -> Dictionary:
	var part := _part_of(_hover)
	if part.is_empty() and _armed != "" and _index_of(_armed) >= 0:
		part = _parts[_index_of(_armed)]
	var mounted: Dictionary = state.get("mounted", {})
	var mounted_item: ItemDef = mounted.get("item") if not mounted.is_empty() else null
	if not part.is_empty():
		var on := bool(part.get("mounted", false))
		return {
			"item": part["item"],
			"paint": int(part.get("paint", -1)),
			"for_sale": not bool(part["owned"]),
			"mounted": on,
			"detail": str(part["detail"]),
			"price": int(part["price"]) if not bool(part["owned"]) else -1,
			"base": null if on else mounted_item,
		}
	if mounted_item == null or str(state.get("locked", "")) != "":
		return {}
	var paint := -1
	for entry in _parts:
		if bool(entry.get("mounted", false)):
			paint = int(entry.get("paint", -1))
	return {
		"item": mounted_item,
		"paint": paint,
		"for_sale": false,
		"mounted": true,
		"detail": str(mounted["detail"]),
		"price": -1,
		"base": null,
	}


func _draw_showcase() -> void:
	var shown := _shown()
	var stage := _stage_rect()
	var item: ItemDef = shown.get("item")
	var for_sale := bool(shown.get("for_sale", false))
	var locked := str(state.get("locked", "")) != ""
	PartShowcase.draw_stage(self, stage, item, int(shown.get("paint", -1)), _time, for_sale, locked)
	if item == null:
		_draw_empty(stage, locked)
		return
	# La placa de la esquina: si esta en venta o si es la que llevas.
	var plate := ""
	var plate_tone := GOLD
	if for_sale:
		plate = Txt.t("rack_for_sale")
		plate_tone = HOLO
	elif bool(shown.get("mounted", false)):
		plate = Txt.t("workshop_mounted").to_upper()
	if plate != "":
		var wide := _font.get_string_size(plate, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 12.0
		var tag := Rect2(stage.position + Vector2(8, 8), Vector2(wide, 15))
		draw_rect(tag, Color(plate_tone, 0.16))
		draw_rect(tag, Color(plate_tone, 0.8), false, 1.0)
		HangarProps.text(self, _font, tag.position + Vector2(6, 11), plate, wide, 9, plate_tone)
	var sheet := _sheet_rect()
	var name_size := _fitting(item.display_name, sheet.size.x, 15, 11)
	var name_at := sheet.position + Vector2(0, 16)
	HangarProps.text(self, _font, name_at, item.display_name, sheet.size.x, name_size, TEXT)
	var tone := GOLD if bool(shown.get("mounted", false)) else PartIcon.TIER_COLORS[item.tier]
	var detail := str(shown.get("detail", ""))
	HangarProps.text(
		self, _font, sheet.position + Vector2(0, 32), detail, sheet.size.x - 90.0, 10, tone
	)
	if int(shown.get("price", -1)) >= 0:
		var price := HangarProps.thousands(int(shown["price"]))
		var wide := _font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var at := Vector2(sheet.end.x - wide - 18.0, sheet.position.y + 32.0)
		HangarProps.text(self, _font, at, price, wide + 2.0, 12, GOLD)
		_draw_cell_mark(Vector2(sheet.end.x - 7.0, sheet.position.y + 28.0), GOLD)
	draw_line(
		sheet.position + Vector2(0, SHEET_HEAD - 3.0),
		Vector2(sheet.end.x, sheet.position.y + SHEET_HEAD - 3.0),
		Color("4f6380", 0.45),
		1.0
	)
	var peers: Array = []
	for entry in _parts:
		peers.append(entry["item"])
	var rows := PartShowcase.rows(item, shown.get("base"), peers)
	var room := sheet.size.y - SHEET_HEAD - (40.0 if _has_key() else 4.0)
	var area := Rect2(sheet.position + Vector2(0, SHEET_HEAD + 2.0), Vector2(sheet.size.x, room))
	PartShowcase.draw_sheet(self, _font, area, rows)
	if _has_key():
		_draw_key(state.get("key", {}))


## Sin pieza que ensenar: el pedestal dice que la casilla esta vacia y la
## ficha, cuantas piezas hay en el maletin para ella.
func _draw_empty(stage: Rect2, locked: bool) -> void:
	if not locked:
		var at := Vector2(stage.position.x, stage.position.y + stage.size.y * 0.45)
		var label := Txt.t("rack_empty")
		HangarProps.text(self, _font, at, label, stage.size.x, 13, Color(MUTED, 0.9), true)
	var owned := 0
	for part in _parts:
		owned += 1 if bool(part["owned"]) else 0
	var sheet := _sheet_rect()
	var title := str(state.get("title", ""))
	HangarProps.text(self, _font, sheet.position + Vector2(0, 16), title, sheet.size.x, 15, TEXT)
	var count := Txt.t("rack_count", [owned, _parts.size() - owned])
	_wrapped(sheet.position + Vector2(0, 40), count, sheet.size.x, 11, MUTED, 3)


## La linea de la terminal: que hace pulsar la pieza bajo el raton (o, si no
## hay, que hacer aqui), escrita letra a letra cada vez que cambia.
func _draw_terminal() -> void:
	var rect := _line_rect()
	draw_rect(rect, Color(0, 0, 0, 0.45))
	draw_rect(rect, Color(HOLO, 0.22), false, 1.0)
	var line := _line()
	var text := str(line[0])
	if text != _typed:
		_typed = text
		_typed_at = _time
	var count := mini(text.length(), int((_time - _typed_at) * TYPE_SPEED))
	var shown := text.substr(0, count)
	var base := Vector2(rect.position.x + 8.0, rect.get_center().y + 4.5)
	HangarProps.text(self, _font, base, ">", 12.0, 11, GOLD)
	var at := base + Vector2(14.0, 0.0)
	var room := rect.size.x - 30.0
	HangarProps.text(self, _font, at, shown, room, 11, line[1])
	# El cursor, que parpadea al terminar de escribir.
	var wide := _font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if count < text.length() or fposmod(_time, 1.0) < 0.55:
		var cursor := Rect2(at.x + minf(wide, room) + 3.0, at.y - 9.0, 6.0, 11.0)
		draw_rect(cursor, Color(line[1], 0.7))


## [texto, color] de la linea de la terminal.
func _line() -> Array:
	var part := _part_of(_hover)
	if part.is_empty() and _armed != "" and _index_of(_armed) >= 0:
		part = _parts[_index_of(_armed)]
	if not part.is_empty():
		return _part_action(part)
	if str(state.get("locked", "")) != "":
		return [Txt.t("workshop_locked", [str(state["locked"])]), BAD]
	if (state.get("mounted", {}) as Dictionary).is_empty():
		return [str(state.get("hint", "")), MUTED]
	return [Txt.t("rack_line_browse"), MUTED]


## Que hace pulsar una pieza del maletin, y su color.
func _part_action(part: Dictionary) -> Array:
	var price := int(part["price"])
	if bool(part["owned"]):
		if bool(part.get("mounted", false)):
			return [_upper_first(Txt.t("rack_click_remove")), GOLD]
		if str(part.get("reason", "")) != "":
			return [str(part["reason"]), BAD]
		if str(part.get("where", "")) != "":
			return [Txt.t("rack_click_move", [str(part["where"])]), TEXT]
		return [_upper_first(Txt.t("rack_click_mount")), TEXT]
	if str(part.get("reason", "")) != "":
		return ["%s · %s" % [Txt.t("rack_click_buy", [price]), str(part["reason"])], BAD]
	if _armed == str(part["id"]):
		return [Txt.t("rack_buy_confirm", [price]), Color(GOLD, 0.75 + 0.25 * sin(_time * 8.0))]
	var line := Txt.t("rack_click_buy", [price])
	if str(part.get("note", "")) != "":
		line += " · " + str(part["note"])
	return [line, TEXT]


static func _upper_first(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1) if text != "" else text


## El maletin: un borde de metal con sus cierres y, dentro, la espuma con su
## trama; los huecos de las piezas se recortan encima.
func _draw_case() -> void:
	var box := _case_rect()
	var plate := TechStyle.plate(Color("1a1f26"), Color("3c4654"), 0.0, 8.0)
	plate.groove = false
	plate.shadow = 6.0
	plate.draw(get_canvas_item(), box)
	var foam := box.grow(-CASE_PAD + 3.0)
	draw_rect(foam, FOAM)
	# La trama de la espuma: diagonales finas en los dos sentidos.
	var step := 9.0
	var k := -foam.size.y
	while k < foam.size.x:
		var x0 := maxf(k, 0.0)
		var y0 := maxf(-k, 0.0)
		var run := minf(foam.size.x - x0, foam.size.y - y0)
		if run > 0.0:
			var a := foam.position + Vector2(x0, y0)
			draw_line(a, a + Vector2(run, run), Color(1, 1, 1, 0.025), 1.0)
			var b := Vector2(foam.end.x - x0, foam.position.y + y0)
			draw_line(b, b + Vector2(-run, run), Color(0, 0, 0, 0.2), 1.0)
		k += step
	draw_rect(foam, Color(0, 0, 0, 0.6), false, 1.0)
	# Los dos cierres del borde de arriba.
	for share: float in [0.28, 0.72]:
		var latch := Rect2(
			box.position.x + box.size.x * share - 13.0, box.position.y - 3.0, 26.0, 8.0
		)
		draw_rect(latch, Color("3a4350"))
		draw_rect(latch, Color("7a8899", 0.6), false, 1.0)
		draw_rect(Rect2(latch.get_center() - Vector2(3, 1.5), Vector2(6, 3)), Color("12161b"))


## La tecla de la ficha: subir de nivel o transformar. A su izquierda, lo
## que cambia al subirla o, si no se puede, por que.
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
	var sheet := _sheet_rect()
	var at := Vector2(sheet.position.x, rect.position.y + 11.0)
	var room := rect.position.x - sheet.position.x - 8.0
	if not enabled and str(key.get("reason", "")) != "":
		_wrapped(at, str(key["reason"]), room, 10, BAD, 2)
	elif str(key.get("gain", "")) != "":
		_wrapped(at, str(key["gain"]), room, 10, GOOD, 2)


func _wrapped(
	at: Vector2, text: String, wide: float, font_size: int, color: Color, lines: int
) -> void:
	draw_multiline_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size, lines, color)


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
		draw_rect(cell, Color(0, 0, 0, 0.42))
		draw_line(cell.position, Vector2(cell.end.x, cell.position.y), Color(1, 1, 1, 0.05), 1.0)
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
