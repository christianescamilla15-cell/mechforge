class_name FrontMechView
extends MechView
## El mech visto de frente y armado por piezas, para el hangar (pedido del
## usuario el 2026-11-19: "de frente, pero por piezas... debe mantenerse
## exactamente igual"). El torso y las piernas de frente son dibujos propios,
## sacados de su version de perfil (tools/art/turn_test.py) y exportados como
## "frente_<juego>", con el mismo aro de cintura. Las armas son exactamente
## los mismos dibujos de perfil, giradas: las de brazo cuelgan a los lados
## (las dos primeras de un brazo y las otras dos del otro) y las de hombro
## asoman por detras del casco. El asistente flota a un lado.
##
## Si el torso o las piernas no tienen su dibujo de frente, el mech se ve de
## perfil, como en combate. Asi van los de orugas y los de ruedas: de frente
## no se reconocian (el usuario vio "un cubo" y "un carrito", 2026-11-19).
## El canon de pecho no se dibuja de frente (apunta al que mira): su hueco
## esta en el estante del hangar.

const PREFIX := "frente_"
## Articulacion del brazo de un arma respecto a su ancla de cintura, en
## pixeles de su dibujo: la misma en todas (tools/art/mounts_test.py).
const ARM_PIVOT := Vector2(-22.0, -47.0)
## Donde apoya un arma de hombro, como parte de su dibujo.
const SHOULDER_PIVOT := Vector2(0.42, 0.9)
## Brazo de la derecha de la pantalla: donde va la articulacion de cada una
## de sus dos armas respecto a la cintura, en unidades de MechView, y hacia
## donde apunta (90 = abajo). El otro brazo es su espejo.
const ARM_JOINTS: Array[Vector2] = [Vector2(44.0, -36.0), Vector2(62.0, -48.0)]
const ARM_ANGLES: Array[float] = [62.0, 30.0]
## Hombro de la derecha: apoyo respecto a lo alto del torso, y angulo.
const SHOULDER_JOINT := Vector2(26.0, 32.0)
const SHOULDER_ANGLE := -52.0
## Donde flota el asistente respecto a lo alto del torso.
const ASSIST_AT := Vector2(-108.0, 16.0)
## Cuanto se aleja de la articulacion el enchufe de un hueco vacio.
const SOCKET_REACH := 30.0
## Dibujo que marca el sitio de un hueco de arma vacio.
const EMPTY_SIDE := "arm_medio_balas"
const EMPTY_TOP := "shoulder_bateria_balas"

## Para comparar las dos vistas (main.gd, --perfil): todos de perfil.
static var side_only := false

var _front_torso: String = ""
var _front_legs: String = ""


func setup(p_build: MechBuild, p_facing: int) -> void:
	super.setup(p_build, p_facing)
	_front_torso = ""
	_front_legs = ""
	if side_only or _sprites == null or _sprites.is_boss:
		return
	var torso := PREFIX + _sprites.torso_set
	var legs := PREFIX + _sprites.legs_set
	if MechSprites.has_piece(torso, "torso") and MechSprites.has_piece(legs, "legs"):
		_front_torso = torso
		_front_legs = legs


## True si este mech tiene sus dibujos de frente (si no, se ve de perfil).
func is_front() -> bool:
	return _front_torso != ""


func slot_rect(slot: String) -> Rect2:
	if not is_front():
		return super.slot_rect(slot)
	match slot:
		"torso":
			return _piece_rect(_front_torso, "torso")
		"legs":
			return _piece_rect(_front_legs, "legs")
		"assist", "drone", "drone_low":
			var kind := _assist_kind()
			if kind == "":
				return Rect2()
			var top := MechSprites.assist_top(kind)
			var height := top + MechSprites.assist_bottom(kind)
			var corner := _front_assist_at() - Vector2(height * 0.6, top)
			return Rect2(corner, Vector2(height * 1.2, height))
	var mount := _front_mount(slot, true)
	if mount.is_empty():
		return Rect2()
	return _bounds(mount["xform"], mount["rect"])


## Las armas van giradas: sus esquinas y su zona siguen la inclinacion.
func slot_quad(slot: String) -> PackedVector2Array:
	var mount := _front_mount(slot, true) if is_front() else {}
	if mount.is_empty():
		return super.slot_quad(slot)
	var xform: Transform2D = mount["xform"]
	var rect: Rect2 = mount["rect"]
	return PackedVector2Array(
		[
			xform * rect.position,
			xform * Vector2(rect.end.x, rect.position.y),
			xform * rect.end,
			xform * Vector2(rect.position.x, rect.end.y)
		]
	)


func slot_has_point(slot: String, point: Vector2) -> bool:
	var mount := _front_mount(slot, true) if is_front() else {}
	if mount.is_empty():
		return super.slot_has_point(slot, point)
	var xform: Transform2D = mount["xform"]
	var rect: Rect2 = mount["rect"]
	return rect.has_point(xform.affine_inverse() * point)


## El enchufe de un hueco vacio va en la articulacion de su brazo u hombro.
func slot_socket(slot: String) -> Vector2:
	var mount := _front_mount(slot, true) if is_front() else {}
	if mount.is_empty():
		return super.slot_socket(slot)
	var xform: Transform2D = mount["xform"]
	return xform * Vector2(SOCKET_REACH, 0.0)


func standing_height() -> float:
	if not is_front():
		return super.standing_height()
	var top := _torso_top()
	for slot in _weapon_slots():
		if not _front_mount(slot, false).is_empty():
			top = minf(top, slot_rect(slot).position.y)
	if _assist_kind() != "":
		top = minf(top, _front_assist_at().y - MechSprites.assist_top(_assist_kind()) - 4.0)
	return -top * absf(scale.y)


func muzzle_point(from_drone: bool, slot: String = "") -> Vector2:
	if not is_front():
		return super.muzzle_point(from_drone, slot)
	var local := Vector2(0.0, _torso_top() * 0.6)
	if from_drone and _assist_kind() != "":
		var gun := "gun_low" if slot == "drone_low" else "gun_top"
		local = _front_assist_at() + MechSprites.assist_point(_assist_kind(), gun)
	var mount := _front_mount(slot, false)
	if not from_drone and not mount.is_empty():
		local = mount["xform"] * mount["tip"]
	return position + Vector2(local.x * facing, local.y) * scale.y


func _draw() -> void:
	if build == null:
		return
	if not is_front():
		super._draw()
		return
	var tint := _body_tint(1.0)
	# Respira: el cuerpo y lo que cuelga de el suben y bajan un poco.
	var body := Vector2(0.0, sin(_time * 2.2) * 1.2)
	if _locomotion == "hover" and not ("legs" in ghost_slots):
		_draw_hover_glow()
	# Las armas de hombro asoman por detras del casco.
	for slot: String in ["top0", "top1"]:
		_draw_weapon(slot, tint, body)
	# Las piernas que levitan se mecen con el cuerpo; las demas pisan firme.
	var legs_at := body * 2.0 if _locomotion == "hover" else Vector2.ZERO
	_draw_piece(_front_legs, "legs", build.legs.element, _ghost_tint(tint, "legs"), legs_at)
	# De cada brazo, primero el arma de fuera; el casco tapa las articulaciones.
	for slot: String in ["side1", "side3", "side0", "side2"]:
		_draw_weapon(slot, tint, body)
	_draw_piece(_front_torso, "torso", build.torso.element, _ghost_tint(tint, "torso"), body)
	if _assist_kind() != "":
		var bob := Vector2(0.0, sin(_time * 3.1) * 4.0)
		var element := build.torso.element
		MechSprites.draw_assist(self, _assist_kind(), element, tint, _front_assist_at() + bob)


## Cintura respecto a los pies, segun las piernas de frente. Las que
## levitan van separadas del suelo, como de perfil.
func _hip() -> Vector2:
	var legs := MechSprites.piece_info(_front_legs, "legs")
	var up := (float(legs["size"][1]) - float(legs["hip"][1])) * MechSprites.UNIT_SCALE
	if _locomotion == "hover":
		up += HOVER_HEIGHT
	return Vector2(0.0, -up)


func _torso_top() -> float:
	var torso := MechSprites.piece_info(_front_torso, "torso")
	return _hip().y - float(torso["hip"][1]) * MechSprites.UNIT_SCALE


func _front_assist_at() -> Vector2:
	return Vector2(ASSIST_AT.x, _torso_top() + ASSIST_AT.y)


func _piece_rect(set_name: String, kind: String) -> Rect2:
	var piece := MechSprites.piece_info(set_name, kind)
	if piece.is_empty():
		return Rect2()
	var anchor := Vector2(piece["hip"][0], piece["hip"][1])
	var size := Vector2(piece["size"][0], piece["size"][1])
	return Rect2(_hip() - anchor * MechSprites.UNIT_SCALE, size * MechSprites.UNIT_SCALE)


## Brillo bajo las piernas que levitan, sobre la plataforma.
func _draw_hover_glow() -> void:
	var legs := _piece_rect(_front_legs, "legs")
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var radius := Vector2(legs.size.x * 0.34, 5.0 + 2.0 * pulse)
	_ellipse(Vector2(0.0, -2.0), radius, Color(HOVER_GLOW, 0.28 + 0.14 * pulse))
	_ellipse(Vector2(0.0, -2.0), radius * 0.55, Color(HOVER_GLOW, 0.4 + 0.2 * pulse))


func _draw_piece(
	set_name: String, kind: String, element: int, tint: Color, offset: Vector2
) -> void:
	var texture := MechSprites.texture(set_name, kind, element)
	if texture == null:
		return
	var rect := _piece_rect(set_name, kind)
	draw_texture_rect(texture, Rect2(rect.position + offset, rect.size), false, tint)


## Arma de un hueco tal como va de frente: {"item", "kind", "xform", "rect",
## "tip"}. `xform` lleva el dibujo (con su articulacion en el origen, en
## unidades de MechView) a su sitio; `rect` y `tip` van antes de `xform`. Con
## `or_empty`, un hueco vacio da el sitio donde iria un arma de su tipo.
func _front_mount(slot: String, or_empty: bool) -> Dictionary:
	var side := slot.begins_with("side")
	if not (side or slot.begins_with("top")) or slot.length() < 4 or not _shows_weapons():
		return {}
	var index := int(slot.right(1))
	var items := build.sides if side else build.tops
	var item: ItemDef = items[index] if index < items.size() else null
	var kind := MechSprites.weapon_kind(item)
	if kind == "":
		if not or_empty:
			return {}
		kind = EMPTY_SIDE if side else EMPTY_TOP
	var piece := MechSprites.piece_info(MechSprites.WEAPON_SET, kind)
	if piece.is_empty():
		return {}
	var unit := MechSprites.UNIT_SCALE
	var size := Vector2(piece["size"][0], piece["size"][1])
	var pivot := size * SHOULDER_PIVOT
	var at := Vector2(SHOULDER_JOINT.x, _torso_top() + SHOULDER_JOINT.y)
	var angle := deg_to_rad(SHOULDER_ANGLE)
	# Las armas 0 y 1 van en el brazo de la izquierda; el hombro 0 tambien.
	var mirrored := index < (2 if side else 1)
	if side:
		pivot = Vector2(piece["hip"][0], piece["hip"][1]) + ARM_PIVOT
		at = _hip() + ARM_JOINTS[index % 2]
		angle = deg_to_rad(ARM_ANGLES[index % 2])
	var xform := Transform2D(angle, at)
	if mirrored:
		# El espejo de girar `angle`: voltear el dibujo y girar lo que falta.
		xform = Transform2D(PI - angle, Vector2(1.0, -1.0), 0.0, Vector2(-at.x, at.y))
	var tip := Vector2(size.x, size.y / 2.0)
	if piece.has("tip"):
		tip = Vector2(piece["tip"][0], piece["tip"][1])
	return {
		"item": item,
		"kind": kind,
		"xform": xform,
		"rect": Rect2(-pivot * unit, size * unit),
		"tip": (tip - pivot) * unit,
	}


func _draw_weapon(slot: String, tint: Color, body: Vector2) -> void:
	var mount := _front_mount(slot, false)
	if mount.is_empty():
		return
	var item: ItemDef = mount["item"]
	var texture := MechSprites.texture(MechSprites.WEAPON_SET, mount["kind"], item.element)
	if texture == null:
		return
	var xform: Transform2D = mount["xform"]
	xform.origin += body
	# El retroceso va a lo largo del arma.
	var kick := Vector2(-_recoil, 0.0) if slot == _fired_slot else Vector2.ZERO
	draw_set_transform_matrix(xform)
	var rect: Rect2 = mount["rect"]
	draw_texture_rect(texture, Rect2(rect.position + kick, rect.size), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Caja recta que contiene un rectangulo girado.
func _bounds(xform: Transform2D, rect: Rect2) -> Rect2:
	var out := Rect2(xform * rect.position, Vector2.ZERO)
	var corners: Array[Vector2] = [
		Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	]
	for corner in corners:
		out = out.expand(xform * corner)
	return out
