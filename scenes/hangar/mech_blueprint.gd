class_name MechBlueprint
extends Control
## El robot visto de frente, como plano en la pantalla de la computadora del
## taller (decision del usuario, 2026-11-21, OBS-030: "una pantalla de
## computadora donde se va a mostrar un grafico... de robot de frente"). No
## es un dibujo aparte: es tu robot, con las piezas que lleva, girado de
## cara con el mismo giro con volumen del hangar (TurntableMech) y tenido
## como una proyeccion. Solo se mira: las casillas de sus huecos las pone la
## pantalla alrededor (LoadoutScreen).

## El angulo en el que el giro ensena el frente.
const FRONT := deg_to_rad(270.0)
## El color de la proyeccion.
const TINT := Color(0.56, 0.93, 1.0, 0.96)
## Aire que se deja alrededor, en pixeles.
const PAD := 10.0

var _world := Node2D.new()
## Un robot de perfil que no se ve: de el salen las medidas.
var _probe := MechView.new()
var _turntable := TurntableMech.new()
var _build: MechBuild
var _ghosts: Array[String] = []
## Lo que mide de frente, en unidades del dibujo: medio ancho y alto.
var _half := 100.0
var _tall := 300.0
## El eje del giro, en unidades del dibujo: es el centro del robot de frente.
var _pivot := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)
	_world.modulate = TINT
	_probe.visible = false
	_world.add_child(_probe)
	_world.add_child(_turntable)
	_turntable.set_active(false)
	resized.connect(_frame)
	visibility_changed.connect(_wake)


## El robot que se ensena. `ghosts`: piezas que le faltan ("torso", "legs")
## y salen transparentes.
func show_build(build: MechBuild, ghosts: Array[String]) -> void:
	_build = build
	_ghosts = ghosts
	if build == null or build.torso == null or build.legs == null:
		_turntable.set_active(false)
		return
	_probe.setup(build, 1)
	_probe.ghost_slots = ghosts
	if build.chest != null:
		_probe.show_deployed()
	_probe.place(Vector2.ZERO)
	var bounds := Rect2()
	for slot in MechStage.TOUCHABLE:
		var rect := _rect(slot)
		if rect.size != Vector2.ZERO:
			bounds = bounds.merge(rect)
	var legs := _rect("legs")
	var pivot := legs.get_center().x if legs.size != Vector2.ZERO else 0.0
	_turntable.setup(build, ghosts, bounds, pivot, build.chest != null)
	_turntable.angle = FRONT
	_tall = maxf(-bounds.position.y, 200.0)
	# De frente, las armas de brazo quedan a los lados del cuerpo.
	_half = maxf(_turntable.body_width() * 1.25, 90.0)
	_pivot = pivot
	_frame()
	_wake()


## True si hay un robot que ensenar.
func has_robot() -> bool:
	return _build != null and _build.torso != null and _build.legs != null


func _rect(slot: String) -> Rect2:
	var rect := _probe.slot_rect(slot)
	if rect.size == Vector2.ZERO:
		return Rect2()
	var a := _probe.transform * rect.position
	var b := _probe.transform * rect.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## Lo encaja en el sitio que tiene, con los pies abajo y centrado.
func _frame() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var zoom := minf((size.y - PAD * 2.0) / _tall, (size.x - PAD * 2.0) / (_half * 2.0))
	_world.scale = Vector2(zoom, zoom)
	_world.position = Vector2(size.x * 0.5 - _pivot * zoom, size.y - PAD)


## El giro solo trabaja (y gasta) mientras el plano se ve.
func _wake() -> void:
	_turntable.set_active(is_visible_in_tree() and has_robot())
