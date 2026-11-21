class_name StyleLibrary
extends RefCounted
## Los tipos de robot con los que se empieza una partida (decision del
## usuario, 2026-11-20, OBS-026 de docs/OBSERVACIONES.md): tres, cada uno con
## su historia y su manera de pelear, equilibrados entre si. Todos empiezan
## con el cuerpo y una sola arma. El tipo dice que formas de arma caben en
## sus brazos y arriba, y da una ventaja propia (campos de SkillSet).
## Datos en data/styles.json: {"schema_version", "styles": [{"id", "name" (del
## robot), "role" (el tipo), "story", "mechanic", "sides" y "tops" (formas de
## arma que monta; vacio = todas), "effects" (lo que da el tipo), "build" (con
## lo que empieza)}]}.

## Lo que puede dar un tipo ademas de los efectos del arbol de habilidades
## (menos la materia oscura): disparar a quemarropa.
const OWN_EFFECTS: Array[String] = ["point_blank"]
## Huecos de arma que limita el tipo, con su lista en los datos.
const LISTS := {ItemDef.Type.SIDE: "sides", ItemDef.Type.TOP: "tops"}

var styles: Array[Dictionary] = []
var errors: Array[String] = []
var _index: Dictionary = {}


static func load_file(path: String, catalog: Catalog) -> StyleLibrary:
	var library := StyleLibrary.new()
	if not FileAccess.file_exists(path):
		library.errors.append("no existe el archivo %s" % path)
		return library
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("styles") is Array:
		library.errors.append("%s no tiene una lista 'styles'" % path)
		return library
	for raw: Variant in parsed["styles"]:
		library._add(raw, catalog)
	return library


func ids() -> Array[String]:
	var out: Array[String] = []
	for style in styles:
		out.append(str(style["id"]))
	return out


func has(id: String) -> bool:
	return _index.has(id)


## Nombre del robot de ese tipo ("" si el tipo no existe).
func display_name(id: String) -> String:
	return str(_field(id, "name"))


## Nombre del tipo: "Asalto", "Guardian"...
func role(id: String) -> String:
	return str(_field(id, "role"))


func story(id: String) -> String:
	return str(_field(id, "story"))


## Como pelea, en una frase.
func mechanic(id: String) -> String:
	return str(_field(id, "mechanic"))


## Las piezas con las que empieza, montadas (el formato de un mech guardado).
func build(id: String) -> Dictionary:
	var spec: Variant = _field(id, "build")
	return (spec as Dictionary).duplicate(true) if spec is Dictionary else {}


## Ids de las piezas con las que empieza, sin repetir.
func item_ids(id: String) -> Array[String]:
	return BuildLibrary.items_of(build(id))


## Formas de arma que monta ese tipo en los brazos ("sides") o arriba
## ("tops"); vacio = cualquiera.
func forms(id: String, list: String) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = _field(id, list)
	if raw is Array:
		for form: Variant in raw:
			out.append(str(form))
	return out


## Devuelve "" si un robot de ese tipo puede montar esa pieza; si no, el
## motivo. Un robot sin tipo (los de antes de que existieran) monta todo.
func why_cant_mount(id: String, def: ItemDef) -> String:
	if not has(id) or def == null or not LISTS.has(def.type):
		return ""
	var allowed := forms(id, LISTS[def.type])
	if allowed.is_empty() or def.form in allowed:
		return ""
	return "un robot de %s no monta esa arma" % role(id).to_lower()


## Suma a las habilidades de un mech lo que da su tipo.
func add_effects(id: String, skills: SkillSet) -> void:
	var effects: Variant = _field(id, "effects")
	if effects is Dictionary and skills != null:
		skills.add(effects)


func _field(id: String, key: String) -> Variant:
	if not _index.has(id):
		return ""
	return (_index[id] as Dictionary).get(key, "")


func _add(raw: Variant, catalog: Catalog) -> void:
	if not raw is Dictionary or str(raw.get("id", "")) == "":
		errors.append("hay un tipo de robot sin 'id'")
		return
	var style: Dictionary = raw
	var id := str(style["id"])
	if _index.has(id):
		errors.append("tipo de robot repetido: %s" % id)
		return
	for key: String in ["name", "role", "story", "mechanic"]:
		if str(style.get(key, "")) == "":
			errors.append("%s: falta '%s'" % [id, key])
	for effect: String in style.get("effects", {}):
		var known := effect in SkillTree.EFFECTS and effect != "dark_matter"
		if not known and not effect in OWN_EFFECTS:
			errors.append("%s: efecto desconocido '%s'" % [id, effect])
	var spec: Variant = style.get("build")
	if (
		not spec is Dictionary
		or str(spec.get("torso", "")) == ""
		or str(spec.get("legs", "")) == ""
	):
		errors.append("%s: su 'build' necesita torso y piernas" % id)
		return
	_index[id] = style
	styles.append(style)
	# Lo que lleva tiene que existir y caberle a su propio tipo.
	for item_id in item_ids(id):
		var def := catalog.get_item(item_id) if catalog != null else null
		if def == null:
			errors.append("%s: no existe la pieza '%s'" % [id, item_id])
		elif why_cant_mount(id, def) != "":
			errors.append("%s: no puede montar su propia pieza '%s'" % [id, item_id])
