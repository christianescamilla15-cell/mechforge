class_name LoadoutScreen
extends Control
## La computadora del taller (decision del usuario, 2026-11-21, OBS-030): "una
## especie de pantalla de computadora donde se va a mostrar un grafico... de
## robot de frente. En cada espacio donde va un arma, tu vas a poder
## seleccionar la casilla y, de acuerdo al nivel que tengas, se te va a
## desplegar a un lado de esa pantalla las armas disponibles, por tipo".
## Es la pantalla "TALLER" de la pared, que se acerca al pulsarla (o al
## pulsar tu robot). Sustituye al tablero que colgaba junto al robot, al banco
## de equipo y a elegir las piezas tocandolas en el propio robot.
##
## A la izquierda, el plano: tu robot (MechBlueprint, de perfil desde que se
## cancelo el giro en 3D, OBS-036) y, alrededor,
## una casilla por hueco, unida con una linea a su sitio en el robot; dentro,
## la pieza que lleva. A la derecha, el catalogo de la casilla elegida
## (PartsRack): tus piezas y las de la tienda, por tipo, con su ficha, la
## tecla para subirla y la lectura del robot.
##
## Ensena un estado (WorkshopBrief.loadout) y avisa de lo que se pulsa; no
## decide nada.

## Se pulso la casilla de un hueco.
signal slot_picked(slot: String)
## La tecla de cerrar de la esquina.
signal close_pressed

const GROW_SECONDS := 0.24
const REDRAW_SECONDS := 1.0 / 30.0
const BIG := 54.0
const SMALL := 38.0
const HEAD := 34.0
const GOLD := Color("ffd36b")
const TEXT := Color("d8f4ff")
const MUTED := Color("8fa3b8")
const LINE := Color("57d3ff")
const BAD := Color("ff7d6b")
## Parte del ancho que ocupa el plano; el resto es el catalogo.
const PLAN_SHARE := 0.47
## Donde va el robot dentro del plano (fracciones del plano).
const ROBOT_AREA := Rect2(0.2, 0.16, 0.6, 0.56)
## Centro de cada casilla, como fraccion del plano. Las de armas, a los lados
## del robot, cada una junto a su brazo o su hombro; el cuerpo arriba y
## abajo; lo que no se ve en el robot, al pie.
const BOXES := {
	"torso": Vector2(0.5, 0.075),
	# El robot mira a la derecha, como en el hangar: sus armas y su pecho
	# quedan de ese lado, y el asistente, que flota detras, del otro.
	"top0": Vector2(0.75, 0.1),
	"side0": Vector2(0.915, 0.33),
	"side1": Vector2(0.915, 0.52),
	"chest": Vector2(0.915, 0.71),
	"assist": Vector2(0.085, 0.33),
	"legs": Vector2(0.5, 0.795),
	"charge": Vector2(0.075, 0.805),
	"teleport": Vector2(0.175, 0.805),
	"hook": Vector2(0.275, 0.805),
	"drone": Vector2(0.775, 0.805),
	"drone_low": Vector2(0.875, 0.805),
	"module0": Vector2(0.0875, 0.93),
	"module1": Vector2(0.205, 0.93),
	"module2": Vector2(0.3225, 0.93),
	"module3": Vector2(0.44, 0.93),
	"module4": Vector2(0.5575, 0.93),
	"module5": Vector2(0.675, 0.93),
	"module6": Vector2(0.7925, 0.93),
	"module7": Vector2(0.91, 0.93),
}
## A que punto del robot apunta la linea de cada casilla (fraccion de la
## zona del robot). Lo que no tiene sitio en el dibujo no lleva linea.
const ANCHORS := {
	"torso": Vector2(0.5, 0.22),
	"top0": Vector2(0.3, 0.16),
	"side0": Vector2(0.16, 0.4),
	"side1": Vector2(0.2, 0.56),
	"chest": Vector2(0.44, 0.42),
	"assist": Vector2(0.9, 0.08),
	"legs": Vector2(0.5, 0.86),
}
## Casillas pequenas: lo que no es arma ni cuerpo.
const SMALL_PREFIXES: Array[String] = ["module", "charge", "teleport", "hook", "drone"]

## El catalogo de la casilla elegida. Quien usa la pantalla (WorkshopScreen)
## oye sus senales.
var rack := PartsRack.new()
var state: Dictionary = {}:
	set(value):
		state = value
		_slots.assign(value.get("slots", []))
		rack.state = value.get("list", {})
		queue_redraw()

var _slots: Array[Dictionary] = []
var _blueprint := MechBlueprint.new()
var _veil := Control.new()
var _from := Rect2()
var _to := Rect2()
## Cuanto esta de cerca: 0 = en la pared; 1 = delante.
var _open := 0.0:
	set(value):
		_open = value
		position = _from.position.lerp(_to.position, value)
		size = _from.size.lerp(_to.size, value)
		_show_contents(value >= 0.999)
		queue_redraw()
var _wanted := false
var _grow: Tween
var _hover := ""
var _flash_slot := ""
var _flash := 0.0
var _flash_color := Color.WHITE
var _time := 0.0
var _since_draw := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = get_theme_default_font()
	add_child(_blueprint)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.draw.connect(_draw_veil)
	add_child(_veil)
	rack.embedded = true
	add_child(rack)
	_show_contents(false)
	mouse_exited.connect(_set_hover.bind(""))
	resized.connect(_layout)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_since_draw += delta
	if _since_draw >= REDRAW_SECONDS or _flash > 0.0:
		_since_draw = 0.0
		queue_redraw()
		_veil.queue_redraw()


# --- Acercarla y devolverla -----------------------------------------------------------


## La acerca (o cambia lo que ensena): crece desde su sitio en la pared
## (`from`) hasta `to`. `instant`: sin crecer.
func open(p_state: Dictionary, from: Rect2, to: Rect2, instant: bool = false) -> void:
	_from = from
	_to = to
	state = p_state
	if _wanted and visible:
		position = _from.position.lerp(_to.position, _open)
		size = _from.size.lerp(_to.size, _open)
		return
	_wanted = true
	visible = true
	_hover = ""
	Sfx.play("ui_abrir")
	_tween_open(1.0, 0.0 if instant else GROW_SECONDS)


## La devuelve a la pared.
func close(instant: bool = false) -> void:
	if not _wanted:
		return
	_wanted = false
	_set_hover("")
	rack.close(true)
	_tween_open(0.0, 0.0 if instant else GROW_SECONDS * 0.8)


func is_open() -> bool:
	return _wanted


## El robot que ensena el plano. `ghosts`: lo que le falta.
func show_build(build: MechBuild, ghosts: Array[String]) -> void:
	_blueprint.show_build(build, ghosts)


## Destello en la casilla de un hueco (al montar, subir o transformar).
func flash(slot: String, color: Color) -> void:
	_flash_slot = slot
	_flash_color = color
	var tween := create_tween()
	tween.tween_property(self, "_flash", 0.0, 0.9).from(1.0)


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


## El plano y el catalogo solo estan con la pantalla ya delante: mientras
## crece no se rehacen a cada tamano.
func _show_contents(on: bool) -> void:
	if _blueprint.visible == on and rack.visible == on:
		return
	_blueprint.visible = on
	_veil.visible = on
	if on:
		_layout()
		rack.open(state.get("list", {}), true)
	else:
		rack.visible = false


# --- Medidas ----------------------------------------------------------------------------


func _glass() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-9.0)


## La mitad del plano, bajo la cabecera.
func plan_rect() -> Rect2:
	var glass := _glass()
	return Rect2(
		glass.position + Vector2(8, HEAD),
		Vector2(glass.size.x * PLAN_SHARE, glass.size.y - HEAD - 8)
	)


func _catalog_rect() -> Rect2:
	var glass := _glass()
	var plan := plan_rect()
	var left := plan.end.x + 10.0
	return Rect2(left, plan.position.y, glass.end.x - left - 8.0, plan.size.y)


func _robot_rect() -> Rect2:
	var plan := plan_rect()
	return Rect2(plan.position + plan.size * ROBOT_AREA.position, plan.size * ROBOT_AREA.size)


func _close_rect() -> Rect2:
	var glass := _glass()
	return Rect2(glass.end.x - 30.0, glass.position.y + 6.0, 22.0, 22.0)


## La casilla de un hueco (vacio si ese hueco no esta en el plano).
func box_rect(slot: String) -> Rect2:
	if not BOXES.has(slot):
		return Rect2()
	var plan := plan_rect()
	var side := SMALL if _is_small(slot) else BIG
	# En una pantalla estrecha las casillas encogen para no pisarse.
	side = minf(side, plan.size.x * (0.1 if _is_small(slot) else 0.14))
	var center: Vector2 = plan.position + plan.size * (BOXES[slot] as Vector2)
	return Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))


func _is_small(slot: String) -> bool:
	for prefix in SMALL_PREFIXES:
		if slot.begins_with(prefix):
			return true
	return false


func _layout() -> void:
	if not is_inside_tree():
		return
	var robot := _robot_rect()
	_blueprint.position = robot.position
	_blueprint.size = robot.size
	_veil.position = robot.position
	_veil.size = robot.size
	rack.home = _catalog_rect()


## Hueco de la casilla que hay bajo un punto; "close" en la tecla de cerrar.
func zone_at(at: Vector2) -> String:
	if _open < 0.99:
		return ""
	if _close_rect().grow(3.0).has_point(at):
		return "close"
	for entry in _slots:
		if box_rect(str(entry["slot"])).grow(2.0).has_point(at):
			return str(entry["slot"])
	return ""


# --- Raton -------------------------------------------------------------------------------


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


## Pulsa una casilla (o la tecla de cerrar, "close").
func press(zone: String) -> void:
	if zone == "close":
		close_pressed.emit()
	elif zone != "":
		Sfx.play("ui_tic")
		slot_picked.emit(zone)


func _set_hover(zone: String) -> void:
	if zone == _hover:
		return
	_hover = zone
	if zone != "":
		Sfx.play("ui_tic")
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if zone != "" else CURSOR_ARROW
	queue_redraw()


# --- Dibujo ------------------------------------------------------------------------------


func _draw() -> void:
	var glass := HangarArt.draw_screen(self, Rect2(Vector2.ZERO, size), false, _time)
	var alpha := clampf((_open - 0.55) / 0.45, 0.0, 1.0)
	_text(glass.position + Vector2(10, 22), str(state.get("title", "")), 120.0, 16, TEXT, alpha)
	if alpha <= 0.0:
		return
	var robot := str(state.get("robot", "")).to_upper()
	_text(glass.position + Vector2(96, 22), robot, 240.0, 13, GOLD, alpha)
	var after := 96.0 + _font.get_string_size(robot, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12.0
	var plan := plan_rect()
	_text(
		glass.position + Vector2(after, 22),
		str(state.get("style", "")),
		plan.end.x - glass.position.x - after,
		10,
		MUTED,
		alpha
	)
	_draw_close(alpha)
	_draw_plan(plan, alpha)
	for entry in _slots:
		_draw_box(entry, alpha)


## El fondo del plano: una cuadricula de dibujo tecnico y sus cotas.
func _draw_plan(plan: Rect2, alpha: float) -> void:
	draw_rect(plan, Color(LINE, 0.03 * alpha))
	var step := plan.size.x / 16.0
	var x := plan.position.x
	while x <= plan.end.x + 0.5:
		draw_line(Vector2(x, plan.position.y), Vector2(x, plan.end.y), Color(LINE, 0.05 * alpha))
		x += step
	var y := plan.position.y
	while y <= plan.end.y + 0.5:
		draw_line(Vector2(plan.position.x, y), Vector2(plan.end.x, y), Color(LINE, 0.05 * alpha))
		y += step
	draw_rect(plan, Color(LINE, 0.35 * alpha), false, 1.0)
	# El eje del robot y el suelo, como en un plano.
	var area := _robot_rect()
	var axis := area.get_center().x
	var dash := area.position.y
	while dash < area.end.y:
		draw_line(Vector2(axis, dash), Vector2(axis, dash + 6.0), Color(LINE, 0.16 * alpha))
		dash += 12.0
	draw_line(
		Vector2(area.position.x - 14.0, area.end.y - MechBlueprint.PAD),
		Vector2(area.end.x + 14.0, area.end.y - MechBlueprint.PAD),
		Color(LINE, 0.4 * alpha),
		1.0
	)
	var modules := box_rect("module0")
	if modules.size != Vector2.ZERO:
		var at := Vector2(plan.position.x + 8.0, modules.position.y - 6.0)
		_text(at, Txt.t("loadout_modules"), 120.0, 8, MUTED, alpha)


## Una casilla del plano: la pieza que lleva (o un "+" si esta vacia), con el
## color de su clase; dorada la elegida; con candado la que tu nivel aun no
## abre. Las que tienen sitio en el robot llevan su linea hasta el.
func _draw_box(entry: Dictionary, alpha: float) -> void:
	var slot := str(entry["slot"])
	var rect := box_rect(slot)
	if rect.size == Vector2.ZERO:
		return
	var item: ItemDef = entry["item"]
	var locked := str(entry["locked"]) != ""
	var selected := bool(entry["selected"])
	var hot := slot == _hover
	var edge := MUTED
	if item != null:
		edge = PartIcon.TIER_COLORS[item.tier]
	if selected:
		edge = GOLD
	elif hot:
		edge = edge.lightened(0.45)
	# La linea va a la pieza en el robot; si no se ve, a su sitio de siempre.
	var on_robot := _blueprint.point_of(slot)
	if on_robot != Vector2.INF or ANCHORS.has(slot):
		var area := _robot_rect()
		var to: Vector2 = (
			area.position + on_robot
			if on_robot != Vector2.INF
			else area.position + area.size * (ANCHORS[slot] as Vector2)
		)
		var from := rect.get_center() + (to - rect.get_center()).normalized() * rect.size.x * 0.56
		var glow := 0.85 if selected or hot else 0.32
		draw_line(from, to, Color(edge if selected else LINE, glow * alpha), 1.0)
		draw_circle(to, 2.5, Color(edge if selected else LINE, minf(1.0, glow + 0.2) * alpha))
	draw_rect(rect, Color(0.03, 0.07, 0.1, 0.9 * alpha))
	if selected:
		draw_rect(rect.grow(3.0), Color(GOLD, (0.14 + 0.06 * sin(_time * 5.0)) * alpha))
	var fade := alpha * (0.4 if locked else 1.0)
	if item != null:
		PartIcon.paint(self, rect.grow(-5.0), item, fade, Color.WHITE, int(entry.get("paint", -1)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var mid := rect.get_center()
		var arm := rect.size.x * 0.16
		var plus := Color(edge, 0.7 * fade)
		draw_line(mid - Vector2(arm, 0), mid + Vector2(arm, 0), plus, 2.0)
		draw_line(mid - Vector2(0, arm), mid + Vector2(0, arm), plus, 2.0)
	draw_rect(
		rect,
		Color(edge, (0.95 if selected or hot or item != null else 0.5) * alpha),
		false,
		2.0 if selected else 1.0
	)
	if locked:
		_draw_lock(rect.position + Vector2(8, 9), Color(BAD, 0.9 * alpha))
	if _flash > 0.0 and slot == _flash_slot:
		var burst := rect.grow(10.0 * (1.0 - _flash))
		draw_rect(burst, Color(_flash_color, _flash * 0.4))
		draw_rect(burst, Color(_flash_color, _flash), false, 2.0)
	var tone := GOLD if selected else (TEXT if hot else MUTED)
	var label := _caption(entry)
	var wide := rect.size.x + 34.0
	draw_string(
		_font,
		Vector2(rect.get_center().x - wide * 0.5, rect.end.y + 10.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		wide,
		8,
		Color(tone, alpha)
	)


## El rotulo de una casilla: su hueco; los modulos, solo su numero.
func _caption(entry: Dictionary) -> String:
	var slot := str(entry["slot"])
	if slot.begins_with("module"):
		return str(int(slot.trim_prefix("module")) + 1)
	if slot.begins_with("drone"):
		return Txt.t("loadout_drone", [2 if slot == "drone_low" else 1])
	return str(entry["title"]).to_upper()


func _draw_lock(at: Vector2, color: Color) -> void:
	draw_rect(Rect2(at - Vector2(4, 0), Vector2(8, 6)), color)
	draw_arc(at, 3.0, PI, TAU, 8, color, 1.5)


func _draw_close(alpha: float) -> void:
	var rect := _close_rect()
	var hot := _hover == "close"
	var color := Color(GOLD if hot else MUTED, alpha)
	draw_rect(rect, Color(color, 0.12 * alpha))
	draw_rect(rect, color, false, 1.0)
	var mid := rect.get_center()
	draw_line(mid - Vector2(5, 5), mid + Vector2(5, 5), color, 2.0)
	draw_line(mid - Vector2(5, -5), mid + Vector2(5, -5), color, 2.0)


## Sobre el robot: las lineas de barrido de la pantalla y una que lo recorre,
## para que se lea como una proyeccion y no como el robot de verdad.
func _draw_veil() -> void:
	var rect := Rect2(Vector2.ZERO, _veil.size)
	var y := 0.0
	while y < rect.size.y:
		_veil.draw_line(Vector2(0, y), Vector2(rect.size.x, y), Color(0.01, 0.06, 0.09, 0.22), 1.0)
		y += 3.0
	var sweep := fposmod(_time * 46.0, rect.size.y)
	_veil.draw_rect(Rect2(0, sweep - 5.0, rect.size.x, 10.0), Color(LINE, 0.07))
	_veil.draw_line(Vector2(0, sweep), Vector2(rect.size.x, sweep), Color(LINE, 0.4), 1.0)


func _text(
	at: Vector2, text: String, width: float, font_size: int, color: Color, alpha: float
) -> void:
	HangarProps.text(self, _font, at, text, width, font_size, Color(color, color.a * alpha))
