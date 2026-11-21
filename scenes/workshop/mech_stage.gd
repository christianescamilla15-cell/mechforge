class_name MechStage
extends Control
## El mech en el taller (WorkshopScreen), grande y armado con lo que lleva. Al
## subir o transformar una pieza destella, y "Probar" la dispara contra una
## diana con su efecto de combate. Sus piezas no se eligen ni se arrastran
## aqui: eso va en la computadora del taller (LoadoutScreen, OBS-030).

const COLOR_SELECTED := Color("ffe27a")
const COLOR_TARGET := Color("ff7d6b")
## Huecos que tienen sitio en el dibujo, del mas pequeno al mas grande.
const TOUCHABLE: Array[String] = [
	"top0", "top1", "side0", "side1", "side2", "side3", "chest", "assist", "torso", "legs"
]
## Suelo y aire de arriba, como parte del alto (con topes en pixeles).
const FLOOR_SHARE := 0.15
const TOP_SHARE := 0.05
const MAX_ZOOM := 1.45
## Sitio que se deja a la derecha para la diana y a los lados.
const TARGET_SPACE := 90.0
const SIDE_MARGIN := 14.0
## Probar un arma cuerpo a cuerpo: cuanto pasa la punta de la hoja del centro
## de la diana y lo que duran el salto de ida, el tajo y la vuelta.
const STRIKE_PAST := 18.0
const STRIKE_JUMP := 0.5
const STRIKE_SWING := 0.5

## Solo para ver (el hangar de la base): sin raton y sin diana.
var preview: bool = false

var _world := Node2D.new()
var _mech := MechView.new()
var _overlay := Node2D.new()
var _shots := ShotFx.new()
var _flash_slot: String = ""
var _flash: float = 0.0
var _flash_color := Color.WHITE
var _target_hit: float = 0.0
## Probando un arma cuerpo a cuerpo: el robot esta fuera de su sitio.
var _striking := false
## Cuanto se ve la diana (el hangar la apaga en el modo mision).
var _target_alpha: float = 1.0
var _floor_y: float = 0.0
## Ancho de la plataforma bajo el mech, en pixeles del escenario.
var _platform_width: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if preview else Control.MOUSE_FILTER_STOP
	add_child(_world)
	_world.add_child(_mech)
	_world.add_child(_overlay)
	_world.add_child(_shots)
	_overlay.draw.connect(_draw_overlay)
	resized.connect(_fit)


## Arma el mech con este equipo. `ghosts`: piezas que faltan ("torso",
## "legs") y se ven transparentes.
func show_build(build: MechBuild, ghosts: Array[String]) -> void:
	_mech.setup(build, 1)
	_mech.ghost_slots = ghosts
	if build.chest != null:
		_mech.show_deployed()
	_fit()


## Encuadra el mech entero (con su asistente y sus armas) a la izquierda y
## deja a la derecha sitio para la diana.
func _fit() -> void:
	if _mech.build == null or size.y <= 0.0:
		return
	_mech.place(Vector2.ZERO)
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	for slot in TOUCHABLE:
		var rect := _world_rect(slot)
		if rect.size != Vector2.ZERO:
			bounds = bounds.merge(rect)
	var height := maxf(-bounds.position.y, 200.0)
	var width := maxf(bounds.size.x, 200.0)
	var floor_margin := clampf(size.y * FLOOR_SHARE, 10.0, 64.0)
	var top_margin := clampf(size.y * TOP_SHARE, 3.0, 24.0)
	var room := 0.0 if preview else TARGET_SPACE
	var side := SIDE_MARGIN * minf(1.0, size.y / 300.0)
	var zoom := minf(MAX_ZOOM, (size.y - floor_margin - top_margin) / height)
	zoom = minf(zoom, (size.x - room - 2.0 * side) / width)
	_world.scale = Vector2(zoom, zoom)
	_floor_y = size.y - floor_margin
	# En el taller, a la izquierda (a la derecha va la diana); en las vistas
	# pequenas, centrado.
	var x := side - bounds.position.x * zoom
	if preview:
		x = size.x / 2.0 - (bounds.position.x + bounds.size.x / 2.0) * zoom
	_world.position = Vector2(x, _floor_y)
	var legs := _world_rect("legs")
	_platform_width = maxf(legs.size.x, 80.0) * zoom * 1.7
	queue_redraw()
	_overlay.queue_redraw()


## Destello sobre la pieza de un hueco (al subirla o transformarla).
func flash(slot: String, color: Color) -> void:
	_flash_slot = slot
	_flash_color = color
	var tween := create_tween()
	tween.tween_method(_set_flash, 1.0, 0.0, 0.9)


func _set_flash(value: float) -> void:
	_flash = value
	_overlay.queue_redraw()


## Prueba el arma de un hueco contra la diana, con su efecto de combate:
## las que disparan, desde su sitio; las de cuerpo a cuerpo, como en el
## combate: el robot salta junto a la diana, da el tajo y vuelve.
func test_fire(slot: String, fx: String, color: Color) -> void:
	var drone := slot.begins_with("drone")
	if not drone and _mech.is_melee(slot):
		await _test_strike(slot, fx, color)
		return
	var from := _mech.muzzle_point(drone, slot)
	var to := _target_point()
	if not drone:
		ShotFx.kick(_mech, fx, 0.35, slot, 0.42)
	if ShotFx.is_known(fx):
		await _shots.play(fx, from, to, color, 0.42)
	_flash_target()


## El robot salta hasta que su hoja alcanza la diana (andando si sus piernas
## no saltan), da el tajo y vuelve a su plataforma.
func _test_strike(slot: String, fx: String, color: Color) -> void:
	if _striking:
		return
	_striking = true
	var home := _mech.position
	var to := _target_point()
	var reach := _mech.muzzle_point(false, slot).x - home.x
	var near := Vector2(to.x - reach + STRIKE_PAST, home.y)
	if _mech.build.legs != null and _mech.build.legs.jump > 0:
		await _mech.jump_to(near, STRIKE_JUMP).finished
	else:
		await _mech.move_to(near, STRIKE_JUMP).finished
	_mech.lunge(STRIKE_SWING)
	var fall := _mech.swing(STRIKE_SWING, slot)
	if ShotFx.is_known(fx):
		Sfx.shot_fired(fx)
	await get_tree().create_timer(fall).timeout
	if ShotFx.is_known(fx):
		_shots.play(fx, _mech.muzzle_point(false, slot), to, color, 0.42)
	_flash_target()
	await get_tree().create_timer(STRIKE_SWING).timeout
	await _mech.hop_back(home, STRIKE_JUMP).finished
	_mech.place(home)
	_striking = false


## La diana acusa el golpe.
func _flash_target() -> void:
	_target_hit = 1.0
	var tween := create_tween()
	tween.tween_method(
		func(v: float) -> void:
			_target_hit = v
			_overlay.queue_redraw(),
		1.0,
		0.0,
		0.5
	)


## La diana, pegada al borde derecho, a la altura de las armas.
func _target_point() -> Vector2:
	var right := size.x - 44.0 - _world.position.x
	return Vector2(right / _world.scale.x, -175.0)


func _process(delta: float) -> void:
	# El polvo flota en la luz.
	_time += delta
	queue_redraw()


## El hangar detras del mech: pared de placas, viga con cadenas, lamparas,
## suelo en perspectiva, cono de luz con polvo, plataforma con su sombra y
## vineta (HangarArt). En las vistas pequenas, con menos detalle.
func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var floor_y := _floor_y if _floor_y > 0.0 else size.y * (1.0 - FLOOR_SHARE)
	var detail := clampf(size.y / 420.0, 0.0, 1.0)
	HangarArt.draw_wall(self, rect, floor_y, detail)
	if detail >= 0.5:
		HangarArt.draw_gantry(self, rect, detail)
		HangarArt.draw_lamp(self, Vector2(size.x * 0.08, floor_y * 0.42), detail)
		HangarArt.draw_lamp(self, Vector2(size.x * 0.92, floor_y * 0.42), detail)
	var center := _world.position.x
	var legs := _world_rect("legs")
	if legs.size != Vector2.ZERO:
		center = _world.position.x + legs.get_center().x * _world.scale.x
	HangarArt.draw_floor(self, rect, floor_y, Vector2(center, floor_y - size.y * 0.9))
	HangarArt.draw_light(self, rect, center, floor_y, _time)
	if _mech.build != null:
		HangarArt.draw_platform(self, Vector2(center, floor_y), _platform_width)
	HangarArt.draw_vignette(self, rect, 1.0)


func _draw_overlay() -> void:
	if _mech.build == null:
		return
	# Diana de las pruebas de disparo (no en la vista previa).
	var target := _target_point()
	for i in 0 if preview else 3:
		var radius := 34.0 - i * 11.0
		var ring := Color(COLOR_TARGET.darkened(0.2 * i), _target_alpha)
		_overlay.draw_arc(target, radius, 0, TAU, 32, ring, 3.0)
	if _target_hit > 0.0:
		_overlay.draw_circle(
			target, 40.0 * (1.5 - _target_hit), Color(1, 0.9, 0.7, _target_hit * 0.4)
		)
	if _flash > 0.0 and _flash_slot != "":
		var rect := _world_rect(_flash_slot).grow(10.0 * (1.0 - _flash))
		_overlay.draw_rect(rect, Color(_flash_color, _flash * 0.45))
		_overlay.draw_rect(rect, Color(_flash_color, _flash), false, 3.0)


## Rectangulo de la pieza de un hueco en las coordenadas del mundo del taller.
func _world_rect(slot: String) -> Rect2:
	var rect := _mech.slot_rect(slot)
	if rect.size == Vector2.ZERO:
		return Rect2()
	var a := _mech.transform * rect.position
	var b := _mech.transform * rect.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
