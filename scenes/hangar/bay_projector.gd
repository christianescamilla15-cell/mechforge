class_name BayProjector
extends Control
## Una bahia vacia del hangar, usada para adquirir un robot (pedido del
## usuario el 2026-11-20: "casi como si no existiera un menu"; antes era un
## cuadro con una lista y botones). Al pulsar la bahia, ella misma proyecta
## lo que puede fabricar, de uno en uno: un armazon vacio, gratis, y los
## disenos ya armados. Las flechas de sus lados (o la rueda del raton) pasan
## de uno a otro; a sus pies, su nombre, lo que te falta y lo que cuesta.
## Pulsar el holograma lo deja armado y una segunda pulsacion lo adquiere
## (como al comprar una pieza o al desafiar al jefe).
##
## Ensena un estado (WorkshopBrief.offers) y avisa de lo que se elige; no
## decide nada.

## Se adquirio una oferta: el id del diseno, o "" si es el armazon vacio.
signal bought(id: String)

const LABEL_HEIGHT := 66.0
## Ancho de la franja de cada flecha, dentro de la bahia.
const SIDE := 26.0
const REDRAW_SECONDS := 1.0 / 30.0
const HOLO := Color("57d3ff")
const GOLD := Color("ffd36b")
const BAD := Color("ff7d6b")
const MUTED := Color("8fa3b8")

static var _shader: Shader

## Lo que ensena: {"offers": [{"id" ("" = armazon), "name", "hint", "price",
## "reason" ("" = se puede), "build" (MechBuild o null)}]}.
var state: Dictionary = {}:
	set(value):
		state = value
		_offers.assign(value.get("offers", []))
		_index = clampi(_index, 0, maxi(_offers.size() - 1, 0))
		_sync()

var _offers: Array[Dictionary] = []
var _index := 0
var _armed := false
var _hover := ""
var _view: MechView
var _shown_id := "?"
var _font: Font
var _time := 0.0
var _since_draw := 0.0
## Lo que ocupa la bahia (su robot) dentro de este control.
var _bay := Rect2()


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


## Enciende el proyector sobre una bahia (`bay`, en el hangar).
func open(p_state: Dictionary, bay: Rect2) -> void:
	position = bay.position
	size = bay.size + Vector2(0.0, LABEL_HEIGHT)
	_bay = Rect2(Vector2.ZERO, bay.size)
	_armed = false
	_index = 0
	_shown_id = "?"
	state = p_state
	if not visible:
		Sfx.play("ui_abrir")
	visible = true


func close() -> void:
	visible = false
	_armed = false
	_hover = ""


func is_open() -> bool:
	return visible


## La oferta que se esta viendo; vacio si no hay.
func current() -> Dictionary:
	return _offers[_index] if _index < _offers.size() else {}


func is_armed() -> bool:
	return _armed


## Pasa a la oferta siguiente (1) o a la anterior (-1), dando la vuelta.
func step(by: int) -> void:
	if _offers.size() < 2:
		return
	_index = posmod(_index + by, _offers.size())
	_armed = false
	Sfx.play("ui_clic")
	_sync()


## Pone el holograma de la oferta que toca.
func _sync() -> void:
	queue_redraw()
	var offer := current()
	var id := str(offer.get("id", "")) if not offer.is_empty() else "?"
	if id == _shown_id:
		return
	_shown_id = id
	if _view != null:
		_view.queue_free()
		_view = null
	var build: MechBuild = offer.get("build")
	if build == null:
		return
	_view = MechView.new()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = RivalRow.HOLO_SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("holo", 0.5)
	material.set_shader_parameter("beam", HOLO)
	_view.material = material
	add_child(_view)
	_view.setup(build, 1)
	if build.chest != null:
		_view.show_deployed()
	_view.place(Vector2(_bay.get_center().x, _bay.end.y - 8.0))
	_view.set_facing(1)
	_view.scale *= (_bay.size.y * 0.8) / maxf(_view.standing_height(), 200.0)
	# Un holograma: quieto.
	_view.set_process(false)


# --- Zonas y raton ---------------------------------------------------------------


## Rectangulo de una zona: "prev", "next" o "robot".
func zone_rect(zone: String) -> Rect2:
	match zone:
		"prev":
			return Rect2(0.0, _bay.size.y * 0.3, SIDE, _bay.size.y * 0.4)
		"next":
			return Rect2(size.x - SIDE, _bay.size.y * 0.3, SIDE, _bay.size.y * 0.4)
		"robot":
			return Rect2(SIDE, 0.0, size.x - SIDE * 2.0, size.y)
	return Rect2()


func zone_at(at: Vector2) -> String:
	for zone: String in ["prev", "next", "robot"]:
		if zone_rect(zone).has_point(at):
			return zone
	return ""


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
			step(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			step(1)
		MOUSE_BUTTON_LEFT:
			press(zone_at(click.position))


## Pulsa una zona.
func press(zone: String) -> void:
	match zone:
		"prev":
			step(-1)
		"next":
			step(1)
		"robot":
			var offer := current()
			if offer.is_empty():
				return
			if str(offer.get("reason", "")) != "":
				_armed = false
				Sfx.play("ui_cerrar")
			elif _armed:
				_armed = false
				bought.emit(str(offer["id"]))
			else:
				# La primera pulsacion solo lo deja armado.
				_armed = true
				Sfx.play("ui_habilidad")
			queue_redraw()


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
	var offer := current()
	if offer.is_empty():
		return
	var blocked := str(offer.get("reason", "")) != ""
	var beam := BAD if blocked else (GOLD if _armed else HOLO)
	var flicker := 0.85 + 0.15 * sin(_time * 9.0)
	# El haz del proyector: una columna de luz con sus lineas de barrido.
	draw_rect(_bay, Color(0.02, 0.05, 0.09, 0.55))
	draw_rect(_bay, Color(beam, 0.07 * flicker))
	var k := fposmod(_time * 14.0, 9.0)
	while k < _bay.size.y:
		var y := _bay.end.y - k
		draw_line(
			Vector2(_bay.position.x, y), Vector2(_bay.end.x, y), Color(beam, 0.14 * flicker), 1.0
		)
		k += 9.0
	for x: float in [_bay.position.x, _bay.end.x]:
		draw_line(
			Vector2(x, _bay.position.y), Vector2(x, _bay.end.y), Color(beam, 0.8 * flicker), 1.5
		)
	if offer.get("build") == null:
		# El armazon vacio: una percha con su cruz.
		var mid := Vector2(_bay.get_center().x, _bay.position.y + _bay.size.y * 0.5)
		var w := _bay.size.x * 0.22
		draw_rect(
			Rect2(mid - Vector2(w, w * 1.6), Vector2(w * 2.0, w * 3.2)),
			Color(beam, 0.75),
			false,
			2.0
		)
		draw_line(mid - Vector2(w * 0.5, 0), mid + Vector2(w * 0.5, 0), Color(beam, 0.9), 3.0)
		draw_line(mid - Vector2(0, w * 0.5), mid + Vector2(0, w * 0.5), Color(beam, 0.9), 3.0)
	_draw_arrows()
	_draw_label(offer, beam)


## Las flechas de los lados y, arriba, por cual vas.
func _draw_arrows() -> void:
	if _offers.size() < 2:
		return
	for zone: String in ["prev", "next"]:
		var mid := zone_rect(zone).get_center()
		var dir := -1.0 if zone == "prev" else 1.0
		var color := Color(GOLD if _hover == zone else HOLO, 0.95)
		draw_colored_polygon(
			PackedVector2Array(
				[
					mid + Vector2(-5.0 * dir, -11.0),
					mid + Vector2(-5.0 * dir, 11.0),
					mid + Vector2(8.0 * dir, 0.0)
				]
			),
			color
		)
	var span := (_offers.size() - 1) * 10.0
	for i in _offers.size():
		var at := Vector2(_bay.get_center().x - span * 0.5 + i * 10.0, _bay.position.y + 8.0)
		draw_circle(at, 2.5 if i == _index else 1.5, Color(HOLO, 1.0 if i == _index else 0.45))


## A sus pies: el nombre, lo que te falta y lo que cuesta.
func _draw_label(offer: Dictionary, beam: Color) -> void:
	var plate := Rect2(0.0, _bay.end.y + 4.0, size.x, LABEL_HEIGHT - 6.0)
	draw_rect(plate, Color(0.03, 0.06, 0.1, 0.9))
	draw_rect(plate, Color(beam, 0.7), false, 1.0)
	var at := plate.position + Vector2(0, 17)
	HangarProps.text(self, _font, at, str(offer["name"]), size.x, 13, Color.WHITE, true)
	HangarProps.text(self, _font, at + Vector2(0, 15), str(offer["hint"]), size.x, 9, MUTED, true)
	var line := Txt.t("store_buy", [int(offer["price"])])
	var tone := GOLD
	if int(offer["price"]) <= 0:
		line = Txt.t("acquire_free")
	if str(offer.get("reason", "")) != "":
		line = str(offer["reason"])
		tone = BAD
	elif _armed:
		line = Txt.t("acquire_confirm")
		tone = Color(GOLD, 0.7 + 0.3 * sin(_time * 8.0))
	elif _hover == "robot":
		tone = tone.lightened(0.3)
	HangarProps.text(self, _font, at + Vector2(0, 33), line, size.x, 12, tone, true)
