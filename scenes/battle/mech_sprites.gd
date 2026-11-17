class_name MechSprites
extends RefCounted
## Sprites de un mech por piezas (docs/CHASIS.md): torso y piernas unidos por
## el aro de la cintura, en el color de su elemento. Cada juego de piezas lo
## exporta tools/art/export_parts.py junto con su JSON de anclas. El torso y
## las piernas pueden venir de juegos distintos: todos comparten el aro.

const DIR := "res://assets/mechs/"
## Unidades de MechView por pixel del PNG. Es fija porque todas las piezas se
## exportan a la misma escala; si cada una tuviera la suya no casarian.
const UNIT_SCALE := 0.54
## Juegos exportados que tienen torso y los que tienen piernas, del chasis ligero.
const TORSO_SETS: Array[String] = ["ligero_18", "ligero_13", "ligero_16"]
const LEGS_SETS: Array[String] = ["ligero_18", "ligero_14", "ligero_17"]
## Cuerpo de los jefes (linea robusta), entero y sin mezclar.
const BOSS_SET := "jefe_103"

static var _anchors: Dictionary[String, Dictionary] = {}
static var _textures: Dictionary[String, Texture2D] = {}

var torso_set: String = ""
## True si es un jefe: usa su propio cuerpo entero, de la linea robusta.
var is_boss: bool = false
var legs_set: String = ""


## Elige las piezas de un mech segun sus piezas del catalogo: la misma pieza
## se ve siempre igual. Devuelve null si no hay arte exportado.
static func for_build(build: MechBuild) -> MechSprites:
	var torsos := _available(TORSO_SETS, "torso")
	var legs := _available(LEGS_SETS, "legs")
	if torsos.is_empty() or legs.is_empty():
		return null
	var out := MechSprites.new()
	var boss := build.chassis != null and build.chassis.is_boss()
	if boss and _load_anchors(BOSS_SET).get("torso") is Dictionary:
		out.torso_set = BOSS_SET
		out.legs_set = BOSS_SET
		out.is_boss = true
		return out
	out.torso_set = torsos[absi(build.torso.id.hash()) % torsos.size()]
	out.legs_set = legs[absi(build.legs.id.hash()) % legs.size()]
	return out


## Punto de la cintura respecto a los pies del mech, en unidades de MechView.
func hip_point() -> Vector2:
	var legs: Dictionary = _load_anchors(legs_set)["legs"]
	return Vector2(0.0, -(float(legs["size"][1]) - float(legs["hip"][1])) * UNIT_SCALE)


## Dibuja piernas y torso con los pies en el origen del lienzo.
func draw(canvas: CanvasItem, torso_element: int, legs_element: int, tint: Color) -> void:
	draw_piece(canvas, legs_set, "legs", legs_element, tint)
	draw_piece(canvas, torso_set, "torso", torso_element, tint)


## Dibuja una pieza (torso, piernas o un arma montada) anclada a la cintura.
func draw_piece(
	canvas: CanvasItem,
	set_name: String,
	kind: String,
	element: int,
	tint: Color,
	offset := Vector2.ZERO
) -> void:
	var anchors := _load_anchors(set_name)
	if not anchors.get(kind) is Dictionary:
		return
	var texture := _texture(set_name, kind, element)
	if texture == null:
		return
	var anchor := Vector2(anchors[kind]["hip"][0], anchors[kind]["hip"][1])
	var top_left := hip_point() - anchor * UNIT_SCALE + offset
	canvas.draw_texture_rect(texture, Rect2(top_left, texture.get_size() * UNIT_SCALE), false, tint)


## Esqueleto de las piernas en el color de su elemento (null sin arte).
func leg_rig(element: int) -> LegRig:
	var texture := legs_texture(element)
	if texture == null:
		return null
	var legs: Dictionary = _load_anchors(legs_set)["legs"]
	return LegRig.for_texture(texture, Vector2(legs["hip"][0], legs["hip"][1]))


func legs_texture(element: int) -> Texture2D:
	return _texture(legs_set, "legs", element)


## Esquina de arriba a la izquierda del dibujo de las piernas, respecto a
## los pies, en unidades de MechView.
func legs_origin() -> Vector2:
	var legs: Dictionary = _load_anchors(legs_set)["legs"]
	return hip_point() - Vector2(legs["hip"][0], legs["hip"][1]) * UNIT_SCALE


## Punta delantera de una pieza (la boca de un arma), respecto a los pies.
func piece_tip(set_name: String, kind: String) -> Vector2:
	var piece: Variant = _load_anchors(set_name).get(kind)
	if not piece is Dictionary:
		return hip_point()
	var forward := (float(piece["size"][0]) - float(piece["hip"][0])) * UNIT_SCALE
	var middle := (float(piece["size"][1]) / 2.0 - float(piece["hip"][1])) * UNIT_SCALE
	return hip_point() + Vector2(forward, middle)


static func _available(names: Array[String], kind: String) -> Array[String]:
	var out: Array[String] = []
	for set_name in names:
		if _load_anchors(set_name).get(kind) is Dictionary:
			out.append(set_name)
	return out


static func _load_anchors(set_name: String) -> Dictionary:
	if not _anchors.has(set_name):
		var parsed: Variant = null
		var path := DIR + set_name + ".json"
		if FileAccess.file_exists(path):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		_anchors[set_name] = parsed if parsed is Dictionary else {}
	return _anchors[set_name]


## Textura de la pieza en el color del elemento; si falta, la del fisico.
static func _texture(set_name: String, kind: String, element: int) -> Texture2D:
	var names: Array = ItemDef.Element.keys()
	for element_name: String in [names[element], "PHYSICAL"]:
		var path := "%s%s_%s_%s.png" % [DIR, set_name, kind, element_name]
		if _textures.has(path):
			return _textures[path]
		if ResourceLoader.exists(path):
			_textures[path] = load(path)
			return _textures[path]
	return null
