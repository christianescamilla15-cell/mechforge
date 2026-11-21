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
## Pasos de aspecto de un arma dentro de una clase (GDD 8): el modelo de la
## clase y seis perifericos que se le van sumando al subir de nivel
## (tools/art/evolve_weapons.py). El dibujo se llama "<arma>_c<clase>_<paso>";
## el modelo de su primera clase, sin perifericos, es el de siempre.
const LOOK_STEPS := 6
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
## Nivel maximo de cada clase (RulesConfig), para saber por que paso va.
static var _tier_levels: Array[int] = []
static var _textures: Dictionary[String, Texture2D] = {}

var torso_set: String = ""
## True si es un jefe: usa su propio cuerpo entero, de la linea robusta.
var is_boss: bool = false
## Cuerpo entero de una pieza, sin anclas para armas (el jefe de siempre,
## BOSS_SET): no se le montan armas ni asistente.
var whole: bool = false
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
	# Un campeon con cuerpo propio (GDD 9.4): sus piezas, con sus armas
	# montadas como cualquiera, y mas grande.
	var own := build.body != "" and has_piece(build.body, "torso") and has_piece(build.body, "legs")
	if boss and own:
		out.torso_set = build.body
		out.legs_set = build.body
		out.is_boss = true
		return out
	if boss and _load_anchors(BOSS_SET).get("torso") is Dictionary:
		out.torso_set = BOSS_SET
		out.legs_set = BOSS_SET
		out.is_boss = true
		out.whole = true
		return out
	# Un rival con cuerpo propio (OBS-011): entero, de un solo juego, y con
	# sus armas montadas como cualquiera.
	if build.body != "" and has_piece(build.body, "torso") and has_piece(build.body, "legs"):
		out.torso_set = build.body
		out.legs_set = build.body
		return out
	out.torso_set = torsos[absi(build.torso.id.hash()) % torsos.size()]
	out.legs_set = legs[absi(build.legs.id.hash()) % legs.size()]
	for tag: String in SPECIAL_LEGS:
		if build.legs.has_tag(tag) and has_piece(SPECIAL_LEGS[tag], "legs"):
			out.legs_set = SPECIAL_LEGS[tag]
			out.rigid_legs = true
	return out


## Juego del dibujo de un arma de pecho: el suyo si lo tiene (las armas
## especiales de los campeones, "art": {"set"}) y, si no, el de todas.
static func chest_set(item: ItemDef) -> String:
	var own := str(item.art.get("set", "")) if item != null else ""
	return own if own != "" and has_piece(own, "chest") else MechView.CHEST_SET


static func has_piece(set_name: String, kind: String) -> bool:
	return _load_anchors(set_name).get(kind) is Dictionary


## Anclas de una pieza de un juego ({"hip", "size", ...}); {} si no existe.
static func piece_info(set_name: String, kind: String) -> Dictionary:
	var piece: Variant = _load_anchors(set_name).get(kind)
	return piece if piece is Dictionary else {}


## Dibujo de una pieza en el color del elemento (null si no existe).
static func texture(set_name: String, kind: String, element: int) -> Texture2D:
	return _texture(set_name, kind, element)


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


## Paso de aspecto de una pieza dentro de su clase, de 0 (recien llegada a
## la clase) a LOOK_STEPS (a su nivel maximo). En la primera clase, de seis
## niveles, cada nivel es un paso.
static func look_step(item: ItemDef) -> int:
	if _tier_levels.is_empty():
		_tier_levels = RulesConfig.new().tier_max_level
	var top := _tier_levels[clampi(item.tier, 0, _tier_levels.size() - 1)]
	return clampi(item.level * LOOK_STEPS / maxi(top, 1), 0, LOOK_STEPS)


## Dibujo con el que se ve un arma segun su clase y su nivel: el modelo de
## su clase con los perifericos de su paso. Si falta ese dibujo, el paso
## anterior que lo tenga; si su clase no tiene modelo, el mas avanzado de la
## clase anterior. Sin arte de evolucion, el de siempre (weapon_kind).
static func weapon_look(item: ItemDef) -> String:
	var base := weapon_kind(item)
	if base == "":
		return ""
	var anchors := _load_anchors(WEAPON_SET)
	var own := maxi(item.tier - item.tier_min, 0)
	for tier in range(own, -1, -1):
		var from := look_step(item) if tier == own else LOOK_STEPS
		for step in range(from, -1, -1):
			var look := base if tier == 0 and step == 0 else "%s_c%d_%d" % [base, tier, step]
			if anchors.get(look) is Dictionary:
				return look
	return base


## Dibujo de una pieza para su miniatura en el taller (el mismo que lleva el
## mech); null si esa pieza no tiene arte. `paint`: el color (elemento) con
## el que esta pintada; -1, el de su elemento.
static func icon_for(item: ItemDef, paint: int = -1) -> Texture2D:
	if item == null:
		return null
	var element := paint if paint >= 0 else int(item.element)
	match item.type:
		ItemDef.Type.SIDE, ItemDef.Type.TOP:
			var kind := weapon_look(item)
			return _texture(WEAPON_SET, kind, element) if kind != "" else null
		ItemDef.Type.TORSO:
			var torsos := _available(TORSO_SETS, "torso")
			if torsos.is_empty():
				return null
			return _texture(torsos[absi(item.id.hash()) % torsos.size()], "torso", element)
		ItemDef.Type.LEGS:
			for tag: String in SPECIAL_LEGS:
				if item.has_tag(tag) and has_piece(SPECIAL_LEGS[tag], "legs"):
					return _texture(SPECIAL_LEGS[tag], "legs", element)
			var legs := _available(LEGS_SETS, "legs")
			if legs.is_empty():
				return null
			return _texture(legs[absi(item.id.hash()) % legs.size()], "legs", element)
		ItemDef.Type.CHEST:
			return _texture(chest_set(item), "chest", element)
		ItemDef.Type.ASSIST:
			var form := assist_kind(item.tier)
			return _texture(ASSIST_SET, form, element) if form != "" else null
	return null


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


## Rectangulo que ocupa el dibujo de una pieza anclada a la cintura, con su
## desplazamiento, respecto a los pies; vacio si no hay esa pieza.
func piece_rect(set_name: String, kind: String, offset := Vector2.ZERO) -> Rect2:
	var piece: Variant = _load_anchors(set_name).get(kind)
	if not piece is Dictionary or not piece.has("size"):
		return Rect2()
	var anchor := Vector2(piece["hip"][0], piece["hip"][1])
	var size := Vector2(piece["size"][0], piece["size"][1]) * UNIT_SCALE
	return Rect2(hip_point() - anchor * UNIT_SCALE + offset, size)


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
