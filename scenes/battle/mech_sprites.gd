class_name MechSprites
extends RefCounted
## Sprites de un mech por piezas (docs/CHASIS.md): torso y piernas unidos por
## el aro de la cintura, en el color de su elemento. Los exporta
## tools/art/export_parts.py junto con el JSON de anclas.

const DIR := "res://assets/mechs/"
## Altura en pantalla de un mech entero, en unidades de MechView.
const TARGET_HEIGHT := 215.0

static var _cache: Dictionary[String, MechSprites] = {}

var set_name: String = ""
## Ancla de la cintura y tamano de cada pieza, en pixeles del PNG.
var anchors: Dictionary = {}
## Unidades de MechView por pixel del PNG.
var unit_scale: float = 1.0
var _textures: Dictionary[String, Texture2D] = {}


## Devuelve el juego de sprites con ese nombre, o null si no esta exportado.
static func load_set(name: String) -> MechSprites:
	if _cache.has(name):
		return _cache[name]
	var out: MechSprites = null
	var path := DIR + name + ".json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if (
			parsed is Dictionary
			and parsed.get("torso") is Dictionary
			and parsed.get("legs") is Dictionary
		):
			out = MechSprites.new()
			out.set_name = name
			out.anchors = parsed
			out.unit_scale = TARGET_HEIGHT / maxf(out.torso_height() + out.legs_height(), 1.0)
	_cache[name] = out
	return out


## Pixeles del torso por encima de la cintura.
func torso_height() -> float:
	return float(anchors["torso"]["hip"][1])


## Pixeles de las piernas por debajo de la cintura.
func legs_height() -> float:
	return float(anchors["legs"]["size"][1]) - float(anchors["legs"]["hip"][1])


## Punto de la cintura respecto a los pies del mech, en unidades de MechView.
func hip_point() -> Vector2:
	return Vector2(0.0, -legs_height() * unit_scale)


## Dibuja piernas y torso con los pies en el origen del lienzo.
func draw(canvas: CanvasItem, torso_element: int, legs_element: int, tint: Color) -> void:
	draw_piece(canvas, "legs", legs_element, tint)
	draw_piece(canvas, "torso", torso_element, tint)


## Dibuja una pieza del juego (torso, piernas o un arma montada) en su sitio.
func draw_piece(canvas: CanvasItem, kind: String, element: int, tint: Color) -> void:
	if not anchors.get(kind) is Dictionary:
		return
	var texture := _texture(kind, element)
	if texture == null:
		return
	var anchor := Vector2(anchors[kind]["hip"][0], anchors[kind]["hip"][1])
	var top_left := hip_point() - anchor * unit_scale
	canvas.draw_texture_rect(texture, Rect2(top_left, texture.get_size() * unit_scale), false, tint)


## Textura de la pieza en el color del elemento; si falta, la del fisico.
func _texture(kind: String, element: int) -> Texture2D:
	var names: Array = ItemDef.Element.keys()
	for element_name: String in [names[element], "PHYSICAL"]:
		var key := "%s_%s" % [kind, element_name]
		if _textures.has(key):
			return _textures[key]
		var path := "%s%s_%s.png" % [DIR, set_name, key]
		if ResourceLoader.exists(path):
			_textures[key] = load(path)
			return _textures[key]
	return null
