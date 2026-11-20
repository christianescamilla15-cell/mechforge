class_name MechStage
extends Control
## El mech en el taller (WorkshopScreen), grande y armado con lo que lleva. La
## pieza del hueco elegido se marca con esquinas; pasar el raton por una
## pieza la marca y un clic elige su hueco; una pieza se arrastra desde el
## mech (para cambiarla de hueco o quitarla) y se le sueltan piezas encima. Al
## subir o transformar una pieza destella, y "Probar" la dispara contra una
## diana con su efecto de combate.

signal picked(slot: String)
signal dropped(data: Dictionary)
signal hovered(slot: String)

const COLOR_SELECTED := Color("ffe27a")
const COLOR_HOVER := Color(1, 1, 1, 0.55)
const COLOR_TARGET := Color("ff7d6b")
## Huecos que se pueden tocar en el dibujo, del mas pequeno al mas grande:
## si se solapan, gana el arma sobre el torso.
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

var selected_slot: String = ""
var hover_slot: String = ""
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


## Dispara el arma de un hueco contra la diana, con su efecto de combate.
func test_fire(slot: String, fx: String, color: Color) -> void:
	var drone := slot.begins_with("drone")
	var from := _mech.muzzle_point(drone, slot)
	var to := _target_point()
	if not drone:
		_mech.fire(0.35, slot)
	if ShotFx.is_known(fx):
		await _shots.play(fx, from, to, color, 0.42)
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
	# Las esquinas siguen a la pieza mientras el mech respira.
	if selected_slot != "" or hover_slot != "":
		_overlay.queue_redraw()


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
	if hover_slot != "" and hover_slot != selected_slot:
		_brackets(hover_slot, COLOR_HOVER, 2.0)
	if selected_slot != "":
		_brackets(selected_slot, COLOR_SELECTED, 3.0)
	if _flash > 0.0 and _flash_slot != "":
		var rect := _world_rect(_flash_slot).grow(10.0 * (1.0 - _flash))
		_overlay.draw_rect(rect, Color(_flash_color, _flash * 0.45))
		_overlay.draw_rect(rect, Color(_flash_color, _flash), false, 3.0)


## Esquinas alrededor de la pieza de un hueco.
func _brackets(slot: String, color: Color, width: float) -> void:
	var quad := _mech.slot_quad(slot)
	if quad.size() != 4:
		return
	for i in 4:
		# Cada esquina, con sus dos lados.
		var p := _mech.transform * quad[i]
		var next := _mech.transform * quad[(i + 1) % 4] - p
		var before := _mech.transform * quad[(i + 3) % 4] - p
		var arm := minf(18.0, minf(next.length(), before.length()) * 0.35)
		var corner := p - (next.normalized() + before.normalized()) * 6.0
		_overlay.draw_line(corner, corner + next.normalized() * arm, color, width)
		_overlay.draw_line(corner, corner + before.normalized() * arm, color, width)


## Rectangulo de la pieza de un hueco en las coordenadas del mundo del taller.
func _world_rect(slot: String) -> Rect2:
	var rect := _mech.slot_rect(slot)
	if rect.size == Vector2.ZERO:
		return Rect2()
	var a := _mech.transform * rect.position
	var b := _mech.transform * rect.end
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


## Hueco cuya pieza esta bajo un punto de la pantalla del taller; "" si nada.
func slot_at(at: Vector2) -> String:
	if _mech.build == null:
		return ""
	var world := (at - _world.position) / _world.scale.x
	var local := _mech.transform.affine_inverse() * world
	for slot in TOUCHABLE:
		if _mech.slot_has_point(slot, local):
			# Un hueco vacio (o una pieza fantasma) no se toca en el dibujo.
			if _item_in(slot) == null:
				continue
			return slot
	return ""


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var slot := slot_at(motion.position)
		if slot != hover_slot:
			hover_slot = slot
			hovered.emit(slot)
			_overlay.queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var slot := slot_at(click.position)
		if slot != "":
			picked.emit(slot)


## Arrastrar una pieza desde el mech: a otro hueco de su tipo o fuera.
func _get_drag_data(at: Vector2) -> Variant:
	var slot := slot_at(at)
	var item := _item_in(slot)
	if item == null:
		return null
	set_drag_preview(PartIcon.drag_preview(item))
	return {"id": item.id, "type": item.type, "from_slot": slot}


func _item_in(slot: String) -> ItemDef:
	var build := _mech.build
	if build == null or slot == "" or slot in _mech.ghost_slots:
		return null
	match slot:
		"torso":
			return build.torso
		"legs":
			return build.legs
		"chest":
			return build.chest
		"assist":
			return build.assist
	var index := int(slot.right(1))
	var list: Array[ItemDef] = build.sides if slot.begins_with("side") else build.tops
	return list[index] if index < list.size() else null


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("id") and not data.has("from_slot")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(data)
