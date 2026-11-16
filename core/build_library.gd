class_name BuildLibrary
extends RefCounted
## Mechs predefinidos cargados desde JSON (data/builds.json): los de ejemplo
## para el simulador y, mas adelante, los enemigos de la campana.
## Formato: {"schema_version": 1, "builds": [{"id", "name", "element", "items"}]}

var specs: Dictionary[String, Dictionary] = {}
var errors: Array[String] = []


static func load_file(path: String) -> BuildLibrary:
	var library := BuildLibrary.new()
	if not FileAccess.file_exists(path):
		library.errors.append("no existe el archivo %s" % path)
		return library
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("builds") is Array:
		library.errors.append("%s no tiene una lista 'builds'" % path)
		return library
	for raw: Variant in parsed["builds"]:
		if (
			not raw is Dictionary
			or str(raw.get("id", "")) == ""
			or not raw.get("items") is Dictionary
		):
			library.errors.append("hay un build sin 'id' o sin 'items'")
			continue
		if library.specs.has(raw["id"]):
			library.errors.append("build repetido: %s" % raw["id"])
			continue
		library.specs[raw["id"]] = raw
	return library


func ids() -> Array[String]:
	return specs.keys()


func element_of(id: String) -> String:
	return str(specs[id].get("element", ""))


func display_name(id: String) -> String:
	return str(specs[id].get("name", id))


## Arma el mech con todas sus piezas al mismo tier y nivel.
func make(
	id: String, catalog: Catalog, rules: RulesConfig, tier: ItemDef.Tier, level: int
) -> MechBuild:
	return catalog.make_build(specs[id]["items"], rules, tier, level)
