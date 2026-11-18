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


## Mechs normales, sin jefes: los que usan el simulador de balance y los tests.
func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in specs:
		if not is_boss(id):
			out.append(id)
	return out


func boss_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in specs:
		if is_boss(id):
			out.append(id)
	return out


## Banda de un mech: el tipo de arma que lleva ("balas", "canon", "blaster"
## o "laser").
func band_of(id: String) -> String:
	return str(specs[id].get("band", ""))


## Mechs normales de una banda.
func band_ids(band: String) -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		if band_of(id) == band:
			out.append(id)
	return out


## Mechs con los que se puede empezar una partida.
func starter_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		if bool(specs[id].get("starter", false)):
			out.append(id)
	return out


## Todos, jefes incluidos: para los menus.
func all_ids() -> Array[String]:
	return specs.keys()


func element_of(id: String) -> String:
	return str(specs[id].get("element", ""))


func display_name(id: String) -> String:
	return str(specs[id].get("name", id))


## Chasis que pide ese mech en los datos, o "" si no pide ninguno.
func chassis_of(id: String) -> String:
	return str(specs[id].get("chassis", ""))


## Piezas distintas de ese mech, en el orden en que se montan.
func item_ids(id: String) -> Array[String]:
	return items_of(specs[id]["items"])


## Piezas distintas de un mech dado por sus "items" (formato de builds.json).
static func items_of(items: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in ["torso", "legs", "sides", "tops", "drone", "drone_low", "modules"]:
		var value: Variant = items.get(key)
		var list: Array = value if value is Array else [value]
		for item: Variant in list:
			if item != null and str(item) != "" and not str(item) in out:
				out.append(str(item))
	for key: String in ["assist", "chest", "charge", "teleport", "hook"]:
		var item: Variant = items.get(key)
		if item != null and str(item) != "" and not str(item) in out:
			out.append(str(item))
	return out


func is_boss(id: String) -> bool:
	return bool(specs[id].get("boss", false))


## Arma el mech con todas sus piezas al mismo tier y nivel. Si se pasa la
## biblioteca de chasis y el mech pide uno, lo monta a su nivel maximo.
## `parts` da a cada pieza su propia clase y nivel (Catalog.make_build).
func make(
	id: String,
	catalog: Catalog,
	rules: RulesConfig,
	tier: ItemDef.Tier,
	level: int,
	chassis: ChassisLibrary = null,
	parts: Dictionary = {}
) -> MechBuild:
	var build := catalog.make_build(specs[id]["items"], rules, tier, level, parts)
	var chassis_id := chassis_of(id)
	if chassis != null and chassis_id != "" and chassis.get_def(chassis_id) != null:
		build.chassis = chassis.get_def(chassis_id).at_level(rules.chassis_max_level, rules)
	return build
