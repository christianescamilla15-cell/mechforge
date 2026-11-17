class_name StageLibrary
extends RefCounted
## Escenarios de la arena (GDD 12.1), cargados de data/stages.json. Son solo
## presentacion: los colores y los elementos del paisaje de cada uno.

## Campos que son colores (en el JSON van como texto hexadecimal).
const COLOR_KEYS: Array[String] = [
	"sky_top", "sky_horizon", "body_color", "haze", "floor", "cell", "cell_line", "color"
]

var stages: Array[Dictionary] = []
var errors: Array[String] = []


static func load_file(path: String) -> StageLibrary:
	var library := StageLibrary.new()
	if not FileAccess.file_exists(path):
		library.errors.append("no existe el archivo %s" % path)
		return library
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("stages") is Array:
		library.errors.append("%s no tiene una lista 'stages'" % path)
		return library
	for raw: Variant in parsed["stages"]:
		if not raw is Dictionary or str(raw.get("id", "")) == "":
			library.errors.append("hay un escenario sin 'id'")
			continue
		library.stages.append(_with_colors(raw))
	return library


func ids() -> Array[String]:
	var out: Array[String] = []
	for stage in stages:
		out.append(stage["id"])
	return out


## El escenario con ese id, o un diccionario vacio si no existe.
func get_stage(id: String) -> Dictionary:
	for stage in stages:
		if stage["id"] == id:
			return stage
	return {}


## Escenario para un combate: la misma semilla cae siempre en el mismo.
func pick(seed_value: int) -> Dictionary:
	if stages.is_empty():
		return {}
	return stages[absi(seed_value) % stages.size()]


static func _with_colors(raw: Dictionary) -> Dictionary:
	var out := {}
	for key: String in raw:
		var value: Variant = raw[key]
		if value is Dictionary:
			out[key] = _with_colors(value)
		elif key in COLOR_KEYS and value is String:
			out[key] = Color(value)
		else:
			out[key] = value
	return out
