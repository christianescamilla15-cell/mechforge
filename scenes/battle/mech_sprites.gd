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
## Armas del chasis ligero, una por forma y tipo (tools/art/weapons_test.py
## y export_weapons.py): "arm_<forma>_<tipo>" las de brazo y
## "shoulder_<forma>_<tipo>" las de hombro, cada una anclada a la cintura
## del robot y con la boca de la que sale su disparo.
const WEAPON_SET := "armas_ligero"
const WEAPON_PREFIX: Dictionary[int, String] = {
	ItemDef.Type.SIDE: "arm_",
	ItemDef.Type.TOP: "shoulder_",
}
## Tipos de arma, en el orden en que se busca otro dibujo de la misma
## forma cuando falta el del tipo pedido.
const WEAPON_TYPES: Array[String] = ["balas", "canon", "blaster", "laser"]
## Formas del robot de asistencia, una por clase (tools/art/export_assist.py):
## "assist_0" (Sonda) .. "assist_5" (Arconte), con el centro del casco y las
## bocas de sus dos armas.
const ASSIST_SET := "asistente_ligero"
## Unidades de MechView por pixel de esos sprites.
const ASSIST_UNIT := 0.62
## Piernas que no andan, por su etiqueta del catalogo: se dibujan enteras,
## sin esqueleto.
const SPECIAL_LEGS: Dictionary[String, String] = {
	ItemDef.TAG_TRACKS: "orugas_ligero",
	ItemDef.TAG_WHEELS: "ruedas_ligero",
	ItemDef.TAG_HOVER: "levita_ligero",
}

static var _anchors: Dictionary[String, Dictionary] = {}
static var _textures: Dictionary[String, Texture2D] = {}

var torso_set: String = ""
## True si es un jefe: usa su propio cuerpo entero, de la linea robusta.
var is_boss: bool = false
var legs_set: String = ""
## True si las piernas son de una pieza (orugas, ruedas o levitar).
var rigid_legs: bool = false


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
	for tag: String in SPECIAL_LEGS:
		if build.legs.has_tag(tag) and has_piece(SPECIAL_LEGS[tag], "legs"):
			out.legs_set = SPECIAL_LEGS[tag]
			out.rigid_legs = true
	return out


static func has_piece(set_name: String, kind: String) -> bool:
	return _load_anchors(set_name).get(kind) is Dictionary


## Hay arte de armas montadas: entonces cada arma se dibuja en su hueco.
static func has_weapon_art() -> bool:
	for value: Variant in _load_anchors(WEAPON_SET).values():
		if value is Dictionary:
			return true
	return false


## Forma con la que se dibuja el robot de asistencia de esa clase: la suya
## o la mas cercana por debajo que tenga arte; "" si no hay ninguna.
static func assist_kind(tier: int) -> String:
	for form in range(tier, -1, -1):
		var piece: Variant = _load_anchors(ASSIST_SET).get("assist_%d" % form)
		if piece is Dictionary and piece.has("center"):
			return "assist_%d" % form
	return ""


## Dibuja el robot de asistencia con el centro de su casco en `at`.
static func draw_assist(
	canvas: CanvasItem, kind: String, element: int, tint: Color, at: Vector2
) -> void:
	var texture := _texture(ASSIST_SET, kind, element)
	if texture == null:
		return
	var piece: Dictionary = _load_anchors(ASSIST_SET)[kind]
	var center := Vector2(piece["center"][0], piece["center"][1])
	var rect := Rect2(at - center * ASSIST_UNIT, texture.get_size() * ASSIST_UNIT)
	canvas.draw_texture_rect(texture, rect, false, tint)


## Cuanto baja el dibujo del robot de asistencia por debajo del centro de
## su casco, en unidades de MechView.
static func assist_bottom(kind: String) -> float:
	var piece: Dictionary = _load_anchors(ASSIST_SET).get(kind, {})
	if piece.is_empty():
		return 0.0
	return (float(piece["size"][1]) - float(piece["center"][1])) * ASSIST_UNIT


## Cuanto sube el dibujo del robot de asistencia por encima del centro de
## su casco, en unidades de MechView.
static func assist_top(kind: String) -> float:
	var piece: Dictionary = _load_anchors(ASSIST_SET).get(kind, {})
	if piece.is_empty():
		return 0.0
	return float(piece["center"][1]) * ASSIST_UNIT


## Boca de un arma del asistente ("gun_top" o "gun_low") respecto al centro
## de su casco, en unidades de MechView.
static func assist_point(kind: String, key: String) -> Vector2:
	var piece: Dictionary = _load_anchors(ASSIST_SET).get(kind, {})
	var point: Array = piece.get(key, [0, 0])
	return Vector2(point[0], point[1]) * ASSIST_UNIT


## Pieza de WEAPON_SET con la que se dibuja un arma: la de su forma y su
## tipo, o la de otro tipo de esa forma si la suya no esta; "" si no
## tiene ninguna.
static func weapon_kind(item: ItemDef) -> String:
	if item == null or item.form == "" or not WEAPON_PREFIX.has(item.type):
		return ""
	var base: String = WEAPON_PREFIX[item.type] + item.form + "_"
	if has_piece(WEAPON_SET, base + item.weapon_type):
		return base + item.weapon_type
	for type in WEAPON_TYPES:
		if has_piece(WEAPON_SET, base + type):
			return base + type
	return ""


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


## Borde de arriba del dibujo de una pieza anclada a la cintura (torso o
## arma montada) con su desplazamiento, respecto a los pies (hacia arriba es
## negativo).
func piece_top(set_name: String, kind: String, offset := Vector2.ZERO) -> float:
	var piece: Variant = _load_anchors(set_name).get(kind)
	if not piece is Dictionary:
		return hip_point().y
	return hip_point().y - float(piece["hip"][1]) * UNIT_SCALE + offset.y


## Punta delantera de una pieza (la boca de un arma), respecto a los pies.
func piece_tip(set_name: String, kind: String) -> Vector2:
	var piece: Variant = _load_anchors(set_name).get(kind)
	if not piece is Dictionary:
		return hip_point()
	var hip := Vector2(piece["hip"][0], piece["hip"][1])
	# Sin boca marcada, el extremo de delante a media altura.
	var tip := Vector2(piece["size"][0], float(piece["size"][1]) / 2.0)
	if piece.has("tip"):
		tip = Vector2(piece["tip"][0], piece["tip"][1])
	return hip_point() + (tip - hip) * UNIT_SCALE


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
