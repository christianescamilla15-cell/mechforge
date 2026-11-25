class_name PieceAspects
extends RefCounted
## Aspectos de cada pieza (OBS-051, del usuario: "personalizacion de cada uno
## de acuerdo a las mejoras o partes de la armadura que desees desarrollar";
## "al menos 5 aspectos del arma o armadura"; "hasta 10 niveles... cuesta cada
## vez mas"; "la potencia de disparo"). Cada arma (brazo, hombro, pecho) y
## cada torso del jugador sube cada aspecto por separado, con celdas, y cada
## nivel cambia sus numeros y su dibujo (AspectLook). Datos en
## data/aspects.json; los niveles, en PlayerProfile.aspects.

const WEAPON_TYPES: Array[ItemDef.Type] = [ItemDef.Type.SIDE, ItemDef.Type.TOP, ItemDef.Type.CHEST]
const ARMOR_TYPES: Array[ItemDef.Type] = [ItemDef.Type.TORSO]

var max_level: int = 10
var first_cost: int = 5000
var growth: float = 1.8
## {"id", "name", "melee_name", "for", "needs", "scale", "add", "spread"}.
var aspects: Array[Dictionary] = []
var errors: Array[String] = []


static func load_file(path: String) -> PieceAspects:
	var out := PieceAspects.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		out.errors.append("%s no es un objeto JSON" % path)
		return out
	out.max_level = int(parsed.get("max_level", out.max_level))
	out.first_cost = int(parsed.get("first_cost", out.first_cost))
	out.growth = float(parsed.get("growth", out.growth))
	var probe := ItemDef.new()
	for raw: Variant in parsed.get("aspects", []):
		if not raw is Dictionary or not raw.has("id") or not raw.get("for") in ["weapon", "armor"]:
			out.errors.append("aspecto mal formado: %s" % [raw])
			continue
		var aspect := {
			"id": str(raw["id"]),
			"name": str(raw.get("name", raw["id"])),
			"melee_name": str(raw.get("melee_name", raw.get("name", raw["id"]))),
			"for": str(raw["for"]),
			"needs": str(raw.get("needs", "")),
			"scale": raw.get("scale", {}),
			"add": raw.get("add", {}),
			"spread": float(raw.get("spread", 0.0)),
		}
		for stat: String in (
			(aspect["scale"] as Dictionary).keys() + (aspect["add"] as Dictionary).keys()
		):
			if not stat in probe:
				out.errors.append("%s: ItemDef no tiene %s" % [aspect["id"], stat])
		out.aspects.append(aspect)
	return out


## Si la pieza tiene aspectos: las armas de brazo, hombro y pecho y el torso.
static func has_aspects(def: ItemDef) -> bool:
	return def != null and (def.type in WEAPON_TYPES or def.type in ARMOR_TYPES)


## Los aspectos que le sirven a esa pieza, en orden.
func for_item(def: ItemDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has_aspects(def):
		return out
	var kind := "weapon" if def.type in WEAPON_TYPES else "armor"
	for aspect in aspects:
		if aspect["for"] == kind and _has_need(def, str(aspect["needs"])):
			out.append(aspect)
	return out


## Los ids de los aspectos de esa pieza.
func ids_for(def: ItemDef) -> Array[String]:
	var out: Array[String] = []
	for aspect in for_item(def):
		out.append(str(aspect["id"]))
	return out


func get_aspect(id: String) -> Dictionary:
	for aspect in aspects:
		if aspect["id"] == id:
			return aspect
	return {}


## Su nombre en esa pieza: el filo de una espada es el calibre de un canon.
static func name_on(aspect: Dictionary, def: ItemDef) -> String:
	if def != null and def.has_tag(ItemDef.TAG_MELEE):
		return str(aspect["melee_name"])
	return str(aspect["name"])


## Celdas que cuesta subir un aspecto que esta en ese nivel.
func cost(level: int) -> int:
	return roundi(first_cost * pow(growth, level) / 100.0) * 100


## Niveles de los aspectos de una pieza del jugador ({aspecto: nivel}).
static func levels_of(profile: PlayerProfile, def: ItemDef) -> Dictionary:
	if def == null:
		return {}
	return profile.aspects.get(def.progress_id(), {})


## "" si se puede subir ese aspecto de esa pieza; si no, por que.
func why_cant_raise(profile: PlayerProfile, def: ItemDef, id: String) -> String:
	if not id in ids_for(def):
		return "esa pieza no tiene ese aspecto"
	var level := int(levels_of(profile, def).get(id, 0))
	if level >= max_level:
		return "ya esta al maximo"
	if profile.gold < cost(level):
		return "faltan celdas"
	return ""


## Sube un nivel ese aspecto y cobra sus celdas. Devuelve "" o por que no.
func raise(profile: PlayerProfile, def: ItemDef, id: String) -> String:
	var reason := why_cant_raise(profile, def, id)
	if reason != "":
		return reason
	var levels: Dictionary = levels_of(profile, def).duplicate()
	var level := int(levels.get(id, 0))
	profile.gold -= cost(level)
	levels[id] = level + 1
	profile.aspects[def.progress_id()] = levels
	return ""


## La pieza con sus aspectos: una copia con los numeros cambiados y los
## niveles apuntados (def.aspects, para dibujarlos). Sin niveles, la misma.
func apply(def: ItemDef, levels: Dictionary) -> ItemDef:
	if def == null or levels.is_empty():
		return def
	var out: ItemDef = def.duplicate()
	var shown := {}
	# Primero lo que escala (la potencia sube el minimo y el maximo) y luego
	# la precision, que acerca el minimo al maximo ya subido.
	for aspect in for_item(def):
		var level := clampi(int(levels.get(aspect["id"], 0)), 0, max_level)
		if level <= 0:
			continue
		shown[aspect["id"]] = level
		var scale: Dictionary = aspect["scale"]
		for stat: String in scale:
			var value: int = out.get(stat)
			if value > 0:
				out.set(stat, maxi(1, roundi(value * (1.0 + float(scale[stat]) * level))))
		var add: Dictionary = aspect["add"]
		for stat: String in add:
			out.set(stat, int(out.get(stat)) + roundi(float(add[stat]) * level))
	var precise := int(shown.get("precision", 0))
	var spread := float(get_aspect("precision").get("spread", 0.0))
	if precise > 0 and out.dmg_max > out.dmg_min:
		out.dmg_min += roundi((out.dmg_max - out.dmg_min) * minf(1.0, spread * precise))
	out.aspects = shown
	return out


## Pone sus aspectos a las piezas de un robot del jugador (las armas de
## brazo, hombro y pecho y el torso).
func apply_build(build: MechBuild, by_piece: Dictionary) -> void:
	if by_piece.is_empty():
		return
	var shape := func(def: ItemDef) -> ItemDef:
		return apply(def, by_piece.get(def.progress_id(), {})) if def != null else null
	build.torso = shape.call(build.torso)
	build.chest = shape.call(build.chest)
	for key: String in ["sides", "tops"]:
		var list: Array[ItemDef] = []
		for def: ItemDef in build.get(key):
			list.append(shape.call(def))
		build.set(key, list)


## Cuanto cambia un aspecto en ese nivel: el porcentaje (0.12 = 12 %) o,
## si suma, los puntos que suma.
static func amount_at(aspect: Dictionary, level: int) -> float:
	for stat: String in aspect["add"]:
		return float(aspect["add"][stat]) * level
	var step := float(aspect["spread"])
	for stat: String in aspect["scale"]:
		step = absf(float(aspect["scale"][stat]))
	return minf(1.0, step * level)


static func _has_need(def: ItemDef, need: String) -> bool:
	if need == "":
		return true
	if need == "spread":
		return def.dmg_max > def.dmg_min
	return int(def.get(need)) > 0
