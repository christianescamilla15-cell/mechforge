class_name PartsCase
extends Control
## El estuche de piezas junto a la pieza del robot desarmado (OBS-048, del
## usuario: "el taller no existe en una pantalla, no entramos a otra
## pantalla"). Al pulsar "Cambiar pieza" en la etiqueta de una pieza, en
## lugar de acercar la computadora del taller, un estuche rigido se abre al
## lado de esa pieza: sale de ella, crece hasta su sitio y se queda unido a
## ella por un cable. Dentro va el mismo catalogo de la OBS-039 (PartsRack):
## en la tapa, la vitrina con la pieza bajo el foco y su ficha; abajo, la
## espuma con un hueco por pieza (las de la tienda, proyectadas con su
## precio), y al pie la lectura del robot.
## El resto del hangar se queda en penumbra menos la pieza, que sigue a la
## vista: pulsar otra pieza mueve el estuche a ella; pulsar fuera o Esc lo
## cierra.
##
## Ensena un estado (WorkshopBrief.rack) y avisa de lo que se pulsa; no
## decide nada.

## La tecla de cerrar de su esquina.
signal close_pressed

const GROW_SECONDS := 0.3
## Parte del hangar que ocupa y sus topes, en pixeles.
const WIDE_SHARE := 0.36
const HIGH_SHARE := 0.88
const MIN_SIZE := Vector2(430.0, 500.0)
const MAX_SIZE := Vector2(620.0, 820.0)
## Lo de arriba que no tapa (parte del alto): el engrane de los ajustes.
const TOP_SHARE := 0.085
## Hueco entre la pieza y el estuche.
const GAP := 34.0
## Borde del estuche alrededor del catalogo.
const PAD := 14.0
## Lo que se oscurece el hangar detras (la pieza queda a la luz).
const ROOM_DIM := 0.55
const CLOSE_RADIUS := 13.0
const REDRAW_SECONDS := 1.0 / 30.0
const SHELL := Color("252b33")
const SHELL_EDGE := Color("566273")
const LINING := Color("101419")
const METAL := Color("8a97a8")
const GOLD := Color("ffd36b")
const HOLO := Color("57d3ff")

## El catalogo. Quien usa el estuche (WorkshopScreen) oye sus senales.
var rack := PartsRack.new()
var state: Dictionary = {}:
	set(value):
		state = value
		rack.state = value
		queue_redraw()
## Lo elegido del robot desarmado al que esta unido ("slot:<hueco>").
var key := ""
## La pieza, en coordenadas del hangar (que es quien contiene al estuche).
var piece := Rect2()
## Lo que se queda a la luz y el estuche no tapa: la pieza o, en la bandeja
## de herramientas, la bandeja entera (para pasar de un modulo a otro).
var around := Rect2()

var _target := Rect2()
## Cuanto esta abierto: 0 = cerrado sobre la pieza; 1 = en su sitio.
var _open := 0.0:
	set(value):
		_open = value
		var from := Rect2(piece.get_center(), Vector2.ZERO)
		position = from.position.lerp(_target.position, value)
		size = from.size.lerp(_target.size, value)
		_show_contents(value >= 0.999)
		queue_redraw()
var _wanted := false
var _grow: Tween
var _hover_close := false
var _flash := 0.0
var _flash_color := Color.WHITE
var _time := 0.0
var _since_draw := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	rack.embedded = true
	rack.framed = false
	add_child(rack)
	rack.visible = false
	mouse_exited.connect(_set_hover_close.bind(false))


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_since_draw += delta
	if _since_draw >= REDRAW_SECONDS or _flash > 0.0:
		_since_draw = 0.0
		queue_redraw()


# --- Abrirlo y cerrarlo ------------------------------------------------------------------


## Lo abre junto a la pieza `p_piece` (o cambia lo que ensena o la pieza a
## la que esta unido) en un hangar de tamano `room`.
func open(
	p_state: Dictionary,
	p_key: String,
	p_piece: Rect2,
	room: Vector2,
	instant: bool = false,
	p_around: Rect2 = Rect2()
) -> void:
	var moved := p_key != key
	key = p_key
	state = p_state
	place(p_piece, room, p_around)
	if _wanted and visible and not moved:
		return
	_wanted = true
	visible = true
	rack.open(p_state, true)
	Sfx.play("ui_abrir")
	_tween_open(1.0, 0.0 if instant else GROW_SECONDS)


## Lo cierra sobre su pieza.
func close(instant: bool = false) -> void:
	if not _wanted:
		return
	_wanted = false
	_set_hover_close(false)
	rack.close(true)
	_tween_open(0.0, 0.0 if instant else GROW_SECONDS * 0.7)


func is_open() -> bool:
	return _wanted


## Lo pone junto a la pieza: al lado que da al centro del hangar (o al otro
## si no cabe), a su altura y sin salirse.
func place(p_piece: Rect2, room: Vector2, p_around: Rect2 = Rect2()) -> void:
	piece = p_piece
	if piece.size == Vector2.ZERO:
		piece = Rect2(room * 0.5, Vector2.ZERO)
	around = piece if p_around.size == Vector2.ZERO else p_around.merge(piece)
	_target = target_for(around, room)
	_open = _open


## Donde va el estuche para esa pieza en un hangar de ese tamano.
static func target_for(p_piece: Rect2, room: Vector2) -> Rect2:
	var wide := clampf(room.x * WIDE_SHARE, MIN_SIZE.x, MAX_SIZE.x)
	var high := clampf(room.y * HIGH_SHARE, MIN_SIZE.y, MAX_SIZE.y)
	wide = minf(wide, room.x - 20.0)
	high = minf(high, room.y - 20.0)
	var left := p_piece.position.x - GAP - wide
	var right := p_piece.end.x + GAP
	# Hacia el centro del hangar; si por ahi no cabe, al otro lado.
	var x := left if p_piece.get_center().x > room.x * 0.5 else right
	if x < 10.0 and right + wide <= room.x - 10.0:
		x = right
	elif x + wide > room.x - 10.0 and left >= 10.0:
		x = left
	x = clampf(x, 10.0, room.x - wide - 10.0)
	high = minf(high, room.y * (1.0 - TOP_SHARE) - 10.0)
	var top := room.y * TOP_SHARE
	var y := clampf(p_piece.get_center().y - high * 0.5, top, room.y - high - 10.0)
	return Rect2(x, y, wide, high)


## Destello en el estuche y en su pieza (al montar, subir o transformar).
func flash(color: Color) -> void:
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
	_grow = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if to <= 0.0:
		_grow.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_grow.tween_property(self, "_open", to, seconds)
	if to <= 0.0:
		_grow.tween_callback(func() -> void: visible = false)


## El catalogo solo esta con el estuche ya abierto: mientras crece no se
## rehace a cada tamano.
func _show_contents(on: bool) -> void:
	if on:
		rack.home = _inner()
	rack.visible = on and _wanted


# --- Medidas --------------------------------------------------------------------------------


## Lo de dentro del borde: donde va el catalogo.
func _inner() -> Rect2:
	return Rect2(Vector2(PAD, PAD), size - Vector2(PAD, PAD) * 2.0)


## La tecla de cerrar, en la esquina de arriba a la derecha, sobre el borde.
func close_center() -> Vector2:
	return Vector2(size.x - 4.0, 4.0)


## La pieza vista desde el estuche.
func _piece_local() -> Rect2:
	return Rect2(piece.position - position, piece.size)


# --- Raton ------------------------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hover_close(motion.position.distance_to(close_center()) <= CLOSE_RADIUS + 3.0)
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if click.position.distance_to(close_center()) <= CLOSE_RADIUS + 3.0:
		close_pressed.emit()


func _set_hover_close(on: bool) -> void:
	if on == _hover_close:
		return
	_hover_close = on
	if on:
		Sfx.play("ui_tic")
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if on else CURSOR_ARROW
	queue_redraw()


# --- Dibujo -------------------------------------------------------------------------------------


func _draw() -> void:
	var alpha := clampf(_open, 0.0, 1.0)
	_draw_dim(alpha)
	if size.x < 8.0 or size.y < 8.0:
		return
	_draw_tether(alpha)
	_draw_shell(alpha)
	_draw_close(alpha)


## El hangar en penumbra salvo la pieza, que queda a la luz con su marco.
func _draw_dim(alpha: float) -> void:
	var room := get_global_transform().affine_inverse() * get_viewport_rect()
	var hole := Rect2(around.position - position, around.size).grow(16.0)
	var shade := Color(0.0, 0.006, 0.014, ROOM_DIM * alpha)
	draw_rect(Rect2(room.position, Vector2(room.size.x, hole.position.y - room.position.y)), shade)
	draw_rect(
		Rect2(Vector2(room.position.x, hole.end.y), Vector2(room.size.x, room.end.y - hole.end.y)),
		shade
	)
	draw_rect(
		Rect2(
			Vector2(room.position.x, hole.position.y),
			Vector2(hole.position.x - room.position.x, hole.size.y)
		),
		shade
	)
	draw_rect(
		Rect2(Vector2(hole.end.x, hole.position.y), Vector2(room.end.x - hole.end.x, hole.size.y)),
		shade
	)
	# El borde de la luz, suave, y un destello al montar o subir.
	for i in 4:
		var ring := hole.grow(-2.0 - i * 2.0)
		draw_rect(ring, Color(0.0, 0.006, 0.014, ROOM_DIM * alpha * (0.18 - i * 0.04)), false, 2.0)
	if _flash > 0.0:
		draw_rect(hole.grow(-6.0), Color(_flash_color, 0.7 * _flash), false, 3.0)


## El cable que une el estuche a su pieza: sale del lado de la pieza que da
## al estuche y entra por su borde, con un conector en cada punta.
func _draw_tether(alpha: float) -> void:
	var part := _piece_local()
	var on_left := part.get_center().x < size.x * 0.5
	var start := Vector2(part.end.x if on_left else part.position.x, part.get_center().y)
	var dock_y := clampf(start.y, 60.0, size.y - 60.0)
	var dock := Vector2(0.0 if on_left else size.x, dock_y)
	var bend := Vector2((start.x + dock.x) * 0.5, start.y)
	var bend2 := Vector2(bend.x, dock.y)
	var path := PackedVector2Array([start, bend, bend2, dock])
	var tone := GOLD.lerp(_flash_color, _flash)
	draw_polyline(path, Color(tone, 0.16 * alpha), 7.0, true)
	draw_polyline(path, Color(tone, 0.85 * alpha), 2.0, true)
	# Pulsos que corren por el cable hacia el estuche.
	var total := start.distance_to(bend) + bend.distance_to(bend2) + bend2.distance_to(dock)
	for n in 3:
		var at := fposmod(_time * 120.0 + n * total / 3.0, maxf(total, 1.0))
		draw_circle(_along(path, at), 2.5, Color(1, 1, 1, 0.7 * alpha))
	draw_circle(start, 5.0, Color(tone, alpha))
	draw_circle(start, 2.0, Color(0.05, 0.05, 0.05, alpha))
	var plug := Rect2(dock - Vector2(6.0, 9.0), Vector2(12.0, 18.0))
	draw_rect(plug, Color(METAL, alpha))
	draw_rect(plug, Color(0, 0, 0, 0.5 * alpha), false, 1.0)


## Un punto a esa distancia del principio del camino.
static func _along(path: PackedVector2Array, distance: float) -> Vector2:
	var left := distance
	for i in range(1, path.size()):
		var step := path[i - 1].distance_to(path[i])
		if left <= step and step > 0.0:
			return path[i - 1].lerp(path[i], left / step)
		left -= step
	return path[path.size() - 1]


## El estuche: casco rigido con nervios, esquineras de metal y asa; dentro,
## la tapa forrada (detras de la vitrina) y la bisagra sobre la espuma.
func _draw_shell(alpha: float) -> void:
	var shell := Rect2(Vector2.ZERO, size)
	var plate := TechStyle.plate(Color(SHELL, alpha), Color(SHELL_EDGE, alpha), 0.0, 14.0)
	plate.groove = false
	plate.bolts = false
	plate.shadow = 12.0
	plate.glow = 0.6 * _flash
	plate.draw(get_canvas_item(), shell)
	# Los nervios moldeados de los costados.
	for side: float in [5.0, size.x - 9.0]:
		var y := 40.0
		while y < size.y - 40.0:
			draw_rect(Rect2(side, y, 4.0, 18.0), Color(1, 1, 1, 0.05 * alpha))
			draw_rect(Rect2(side, y + 18.0, 4.0, 2.0), Color(0, 0, 0, 0.35 * alpha))
			y += 30.0
	# El asa, arriba en el centro.
	var grip := Rect2(size.x * 0.5 - 42.0, -12.0, 84.0, 14.0)
	draw_rect(grip, Color("161b21", alpha))
	draw_rect(grip.grow(-3.0), Color("2f3742", alpha))
	draw_line(
		grip.position + Vector2(6, 4),
		Vector2(grip.end.x - 6.0, grip.position.y + 4.0),
		Color(1, 1, 1, 0.12 * alpha),
		1.0
	)
	# Las esquineras.
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		var arm := 22.0
		draw_rect(
			Rect2(
				corner + Vector2(0.0 if sx > 0 else -arm, 0.0 if sy > 0 else -6.0),
				Vector2(arm, 6.0)
			),
			Color(METAL, 0.85 * alpha)
		)
		draw_rect(
			Rect2(
				corner + Vector2(0.0 if sx > 0 else -6.0, 0.0 if sy > 0 else -arm),
				Vector2(6.0, arm)
			),
			Color(METAL, 0.85 * alpha)
		)
		draw_circle(corner + Vector2(sx * 10.0, sy * 3.0), 1.4, Color(0, 0, 0, 0.6 * alpha))
	if not rack.visible:
		return
	var inner := _inner()
	# La tapa forrada, detras de la vitrina: tela acolchada en rombos.
	var lid := Rect2(inner.position, Vector2(inner.size.x, rack.lid_bottom()))
	draw_rect(lid, LINING)
	var step := 26.0
	var k := -lid.size.y
	while k < lid.size.x:
		var x0 := maxf(k, 0.0)
		var y0 := maxf(-k, 0.0)
		var run := minf(lid.size.x - x0, lid.size.y - y0)
		if run > 0.0:
			var a := lid.position + Vector2(x0, y0)
			draw_line(a, a + Vector2(run, run), Color(1, 1, 1, 0.035), 1.0)
			var b := Vector2(lid.end.x - x0, lid.position.y + y0)
			draw_line(b, b + Vector2(-run, run), Color(0, 0, 0, 0.4), 1.0)
		k += step
	draw_rect(lid, Color(0, 0, 0, 0.6), false, 1.0)
	# La bisagra: una barra con sus nudillos a todo lo ancho.
	var hinge_y := inner.position.y + rack.lid_bottom() + 1.0
	draw_rect(
		Rect2(inner.position.x - 4.0, hinge_y - 2.0, inner.size.x + 8.0, 4.0), Color("3a4350")
	)
	var knuckle := inner.position.x + 18.0
	while knuckle < inner.end.x - 18.0:
		draw_rect(Rect2(knuckle, hinge_y - 3.5, 22.0, 7.0), Color("5c6878"))
		draw_line(
			Vector2(knuckle, hinge_y - 3.0),
			Vector2(knuckle + 22.0, hinge_y - 3.0),
			Color(1, 1, 1, 0.18),
			1.0
		)
		knuckle += 64.0


## La tecla de cerrar: un boton redondo sobre la esquina.
func _draw_close(alpha: float) -> void:
	var at := close_center()
	var ring := GOLD if _hover_close else Color("9fb3c8")
	draw_circle(at, CLOSE_RADIUS + 2.0, Color(0, 0, 0, 0.5 * alpha))
	draw_circle(at, CLOSE_RADIUS, Color("1c232c", alpha))
	draw_arc(at, CLOSE_RADIUS, 0.0, TAU, 24, Color(ring, alpha), 1.5, true)
	var arm := 5.0
	draw_line(at + Vector2(-arm, -arm), at + Vector2(arm, arm), Color(ring, alpha), 2.0, true)
	draw_line(at + Vector2(arm, -arm), at + Vector2(-arm, arm), Color(ring, alpha), 2.0, true)
