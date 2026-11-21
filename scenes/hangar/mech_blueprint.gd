class_name MechBlueprint
extends Control
## Tu robot en la pantalla de la computadora del taller (OBS-030), tenido como
## una proyeccion. Es tu robot de verdad, con las piezas que lleva y su dibujo
## de perfil, el mismo del hangar y del combate.
##
## Hasta el 2026-11-21 se ensenaba de frente, con el giro con volumen del
## hangar (TurntableMech). El usuario cancelo ese giro ("quitemos la parte de
## la rotacion en 3D... aqui no funciona", OBS-036) y en la computadora el
## robot de frente "se ve todo mal": las armas no tienen dibujo de frente y
## salian como cajas. De perfil se ve como es.
##
## Solo se mira: las casillas de sus huecos las pone la pantalla alrededor
## (LoadoutScreen), y cada linea va a su pieza (point_of).

## El color de la proyeccion.
const TINT := Color(0.56, 0.93, 1.0, 0.96)
## Aire que se deja alrededor, en pixeles.
const PAD := 10.0
## Huecos con pieza a la vista: de ellos sale lo que ocupa el robot.
const SEEN: Array[String] = ["torso", "legs", "side0", "side1", "top0", "chest", "assist"]

## Encima del robot, lineas de barrido y una franja de luz que lo recorre:
## la pantalla TALLER de la pared (OBS-042), que no tiene velo propio.
var scan := false:
	set(value):
		scan = value
		_veil.visible = value
var _world := Node2D.new()
var _veil := Control.new()
var _time := 0.0
var _mech := MechView.new()
var _build: MechBuild
## Lo que ocupa el robot, en unidades del dibujo (los pies en el 0).
var _bounds := Rect2(-100.0, -300.0, 200.0, 300.0)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_world.modulate = TINT
	_world.add_child(_mech)
	_mech.visible = false
	resized.connect(_frame)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.visible = scan
	_veil.draw.connect(_draw_veil)
	add_child(_veil)


func _process(delta: float) -> void:
	if not scan or not visible:
		return
	_time += delta
	_veil.queue_redraw()


## El robot que se ensena. `ghosts`: piezas que le faltan ("torso", "legs")
## y salen transparentes.
func show_build(build: MechBuild, ghosts: Array[String]) -> void:
	_build = build
	_mech.visible = has_robot()
	if not has_robot():
		return
	_mech.setup(build, 1)
	_mech.ghost_slots = ghosts
	if build.chest != null:
		_mech.show_deployed()
	_mech.place(Vector2.ZERO)
	var bounds := Rect2()
	for slot in SEEN:
		var rect := _mech.slot_rect(slot)
		if rect.size == Vector2.ZERO:
			continue
		bounds = rect if bounds.size == Vector2.ZERO else bounds.merge(rect)
	if bounds.size != Vector2.ZERO:
		_bounds = bounds
	_frame()


## True si hay un robot que ensenar.
func has_robot() -> bool:
	return _build != null and _build.torso != null and _build.legs != null


## Centro de la pieza de un hueco, en coordenadas de este plano; Vector2.INF
## si ese hueco no tiene pieza a la vista.
func point_of(slot: String) -> Vector2:
	if not has_robot() or not slot in SEEN:
		return Vector2.INF
	var rect := _mech.slot_rect(slot)
	if rect.size == Vector2.ZERO:
		return Vector2.INF
	return _world.position + rect.get_center() * _world.scale.x


## Las lineas de barrido y la franja que baja por el robot.
func _draw_veil() -> void:
	if not has_robot():
		return
	var line := 0.0
	while line < size.y:
		_veil.draw_line(Vector2(0, line), Vector2(size.x, line), Color(0.01, 0.05, 0.08, 0.28), 1.0)
		line += 3.0
	var sweep := fposmod(_time * 34.0, size.y + 20.0) - 10.0
	_veil.draw_rect(Rect2(0, sweep - 6.0, size.x, 12.0), Color(TINT, 0.08))
	_veil.draw_line(Vector2(0, sweep), Vector2(size.x, sweep), Color(TINT, 0.55), 1.0)


## Lo encaja en el sitio que tiene, con los pies abajo y centrado.
func _frame() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var zoom := minf(
		(size.y - PAD * 2.0) / maxf(-_bounds.position.y, 1.0),
		(size.x - PAD * 2.0) / maxf(_bounds.size.x, 1.0)
	)
	_world.scale = Vector2(zoom, zoom)
	_world.position = Vector2(size.x * 0.5 - _bounds.get_center().x * zoom, size.y - PAD)
