class_name MechView
extends Node2D
## Dibuja un mech en la arena. De momento con figuras provisionales por pieza
## (bloques de color segun el elemento); el arte definitivo de la fase F4
## sustituira a _draw sin tocar el resto.

const ELEMENT_COLORS: Array[Color] = [
	Color("9aa7b4"),  # fisico: acero
	Color("ff8a3d"),  # calor: naranja
	Color("3dd6ff"),  # energia: cian
	Color("c9b458"),  # combinado
]
const OUTLINE := Color("10151c")
## Escala del dibujo: un mech debe caber en su casilla con el rival al lado.
const DRAW_SCALE := 1.05
## Juego de sprites que tiene el canon de pecho (assets/mechs).
const CHEST_SET := "ligero_18"
## Cuanto suben las armas provisionales para quedar sobre el torso nuevo.
const SPRITE_WEAPON_LIFT := -44.0

var build: MechBuild
## 1 si mira a la derecha, -1 si mira a la izquierda.
var facing: int = 1
var heat_ratio: float = 0.0
var shut_down: bool = false

var _base_position := Vector2.ZERO
## Arte por piezas del mech; null mientras no este exportado (se usan bloques).
var _sprites: MechSprites


func setup(p_build: MechBuild, p_facing: int) -> void:
	build = p_build
	_sprites = MechSprites.for_build(build)
	set_facing(p_facing)


func set_facing(p_facing: int) -> void:
	facing = p_facing
	scale = Vector2(DRAW_SCALE * facing, DRAW_SCALE)
	queue_redraw()


func set_heat(ratio: float, p_shut_down: bool = false) -> void:
	heat_ratio = clampf(ratio, 0.0, 1.3)
	shut_down = p_shut_down
	queue_redraw()


## Fija la posicion de reposo (los efectos de golpe vuelven a ella).
func place(at: Vector2) -> void:
	_base_position = at
	position = at


func move_to(at: Vector2, seconds: float) -> Tween:
	_base_position = at
	var tween := create_tween()
	tween.tween_property(self, "position", at, seconds).set_trans(Tween.TRANS_SINE)
	return tween


## Pequeno avance hacia el rival y vuelta, al atacar.
func lunge(seconds: float) -> Tween:
	var tween := create_tween()
	var forward := _base_position + Vector2(18.0 * facing, 0.0)
	tween.tween_property(self, "position", forward, seconds * 0.4)
	tween.tween_property(self, "position", _base_position, seconds * 0.6)
	return tween


## Destello y sacudida al recibir un golpe.
func hit(seconds: float) -> Tween:
	var tween := create_tween()
	modulate = Color(2.2, 2.2, 2.2)
	tween.tween_property(self, "modulate", Color.WHITE, seconds)
	var shake := create_tween()
	for offset: float in [-7.0, 6.0, -4.0, 2.0, 0.0]:
		shake.tween_property(self, "position", _base_position + Vector2(offset, 0.0), seconds / 5.0)
	return tween


func _draw() -> void:
	if build == null:
		return
	var dim := 0.45 if shut_down else 1.0

	if _sprites != null:
		_sprites.draw(self, build.torso.element, build.legs.element, _body_tint(dim))
		# Provisional: el canon de pecho hace de arma superior hasta que el
		# motor tenga el hueco de pecho (docs/CATALOGO_ARMAS.md).
		if not build.tops.is_empty():
			_sprites.draw_piece(self, CHEST_SET, "chest", build.tops[0].element, _body_tint(dim))
		# Las armas todavia no tienen arte: con el mech dibujado no se pintan
		# sus bloques provisionales, que taparian el dibujo. Solo el dron.
		draw_set_transform(Vector2(0.0, SPRITE_WEAPON_LIFT))
		_draw_drone(dim)
		draw_set_transform(Vector2.ZERO)
		return
	_draw_block_body(dim)

	# Armas laterales: dos delante y dos detras, apuntando al rival.
	var side_slots: Array[Vector2] = [
		Vector2(30, -116), Vector2(30, -90), Vector2(-4, -106), Vector2(-4, -80)
	]
	for i in mini(build.sides.size(), side_slots.size()):
		var weapon := build.sides[i]
		var color := _color(weapon, dim)
		var origin := side_slots[i]
		if weapon.has_tag(ItemDef.TAG_SWORD):
			_box(Rect2(origin.x, origin.y, 64, 7), color.lightened(0.25))
			_box(Rect2(origin.x - 6, origin.y - 5, 14, 17), color.darkened(0.3))
		elif weapon.has_tag(ItemDef.TAG_MELEE):
			_box(Rect2(origin.x, origin.y + 2, 46, 9), color.darkened(0.2))
			_box(Rect2(origin.x + 40, origin.y - 8, 22, 28), color)
		else:
			var length := 28.0 + 4.0 * weapon.range_max
			_box(Rect2(origin.x, origin.y, length, 13), color)
			_box(Rect2(origin.x - 4, origin.y - 3, 22, 19), color.darkened(0.25))

	# Armas superiores sobre el torso.
	for i in mini(build.tops.size(), 2):
		var color := _color(build.tops[i], dim)
		var y := -182.0 - 22.0 * i
		_box(Rect2(-30, y, 34, 20), color.darkened(0.25))
		_box(Rect2(0, y + 4, 60, 11), color)

	_draw_drone(dim)

	# El calor tine el torso de rojo.
	if heat_ratio > 0.02 and not shut_down:
		var glow := Color(1.0, 0.15, 0.05, minf(heat_ratio, 1.0) * 0.55)
		draw_rect(Rect2(-46, -158, 92, 98), glow)


func _draw_drone(dim: float) -> void:
	# Dron flotando detras.
	if build.drone != null:
		var color := _color(build.drone, dim)
		draw_circle(Vector2(-70, -206), 15, color)
		draw_arc(Vector2(-70, -206), 15, 0, TAU, 24, OUTLINE, 2.0)
		_box(Rect2(-62, -210, 20, 7), color.lightened(0.3))


## Bloques provisionales de piernas y torso, para cuando no hay arte.
func _draw_block_body(dim: float) -> void:
	# Piernas: dos patas, o ruedas si no saltan.
	var legs_color := _color(build.legs, dim)
	if build.legs.jump > 0:
		_box(Rect2(-34, -62, 22, 62), legs_color)
		_box(Rect2(10, -62, 22, 62), legs_color)
		_box(Rect2(-40, -8, 34, 8), legs_color.darkened(0.25))
		_box(Rect2(6, -8, 34, 8), legs_color.darkened(0.25))
	else:
		_box(Rect2(-46, -40, 92, 26), legs_color)
		for x: float in [-30.0, 0.0, 30.0]:
			draw_circle(Vector2(x, -14), 15, legs_color.darkened(0.3))
			draw_arc(Vector2(x, -14), 15, 0, TAU, 20, OUTLINE, 2.0)

	# Torso con sensor frontal.
	var torso_color := _color(build.torso, dim)
	_box(Rect2(-46, -158, 92, 98), torso_color)
	_box(Rect2(-36, -148, 72, 26), torso_color.lightened(0.18))
	_box(Rect2(20, -142, 20, 10), Color("fff3a0") if not shut_down else Color("3a3a3a"))


## Tinte del arte: se oscurece apagado y enrojece con el calor.
func _body_tint(dim: float) -> Color:
	var tint := Color(dim, dim, dim)
	if not shut_down:
		# Solo se nota a partir de media barra de calor.
		var hot := clampf((heat_ratio - 0.5) / 0.5, 0.0, 1.0)
		tint = tint.lerp(Color(1.0, 0.42, 0.3), hot * 0.55)
	return tint


func _color(item: ItemDef, dim: float) -> Color:
	var color := ELEMENT_COLORS[item.element]
	return Color(color.r * dim, color.g * dim, color.b * dim)


func _box(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, OUTLINE, false, 2.0)
