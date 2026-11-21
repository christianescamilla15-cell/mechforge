class_name ChassisLibrary
extends RefCounted
## Chasis cargados desde JSON (data/chassis.json).
## Formato: {"schema_version": 1, "chassis": [{"id", "name", "unlock_level",
## y los multiplicadores de ChassisDef.MULTIPLIERS que cambie}]}
## Los de jefe llevan ademas "ability" y "ability_text" (su habilidad
## especial) y, si la tienen, "extra_actions".

var defs: Dictionary[String, ChassisDef] = {}
var errors: Array[String] = []


static func load_file(path: String) -> ChassisLibrary:
	var library := ChassisLibrary.new()
	if not FileAccess.file_exists(path):
		library.errors.append("no existe el archivo %s" % path)
		return library
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("chassis") is Array:
		library.errors.append("%s no tiene una lista 'chassis'" % path)
		return library
	for raw: Variant in parsed["chassis"]:
		library.add(raw)
	return library


## Anade un chasis desde su diccionario; anota los errores que encuentre.
func add(raw: Variant) -> void:
	if not raw is Dictionary or str(raw.get("id", "")) == "":
		errors.append("hay un chasis sin 'id'")
		return
	var id := str(raw["id"])
	if defs.has(id):
		errors.append("chasis repetido: %s" % id)
		return
	var def := ChassisDef.new()
	def.id = id
	def.display_name = str(raw.get("name", id))
	def.unlock_level = int(raw.get("unlock_level", 1))
	if def.unlock_level < 1:
		errors.append("%s: unlock_level debe ser 1 o mas" % id)
	for key: String in raw:
		if key in ["id", "name", "unlock_level"]:
			continue
		if key == "extra_actions":
			def.extra_actions = int(raw[key])
			if def.extra_actions < 0 or def.extra_actions > 2:
				errors.append("%s: extra_actions debe estar entre 0 y 2" % id)
			continue
		if key in ["ability", "ability_text"]:
			def.set(key, str(raw[key]))
			continue
		if key in ChassisDef.ABILITY_FLAGS:
			def.set(key, bool(raw[key]))
			continue
		if key in ChassisDef.ABILITY_COUNTS:
			def.set(key, int(raw[key]))
			if int(raw[key]) < 0 or int(raw[key]) > 2:
				errors.append("%s: %s debe estar entre 0 y 2" % [id, key])
			continue
		if key == "shield_chance":
			var chances: Variant = raw[key]
			if not chances is Dictionary:
				errors.append("%s: shield_chance no es un diccionario" % id)
				continue
			for group: String in chances:
				var chance := float(chances[group])
				if not group in ChassisDef.SHIELD_GROUPS or chance < 0.0 or chance > 1.0:
					errors.append("%s: shield_chance de '%s' no es valida" % [id, group])
					continue
				def.shield_chance[group] = chance
			continue
		if key == "regen_share":
			def.regen_share = float(raw[key])
			if def.regen_share < 0.0 or def.regen_share > ChassisDef.MAX_REGEN_SHARE:
				errors.append("%s: regen_share fuera de rango" % id)
			continue
		if not key in ChassisDef.MULTIPLIERS:
			errors.append("%s: campo desconocido '%s'" % [id, key])
			continue
		var value := float(raw[key])
		if value < ChassisDef.MIN_MULT or value > ChassisDef.MAX_MULT:
			errors.append("%s: %s fuera de rango (%s)" % [id, key, value])
			continue
		def.set(key, value)
	defs[id] = def


func ids() -> Array[String]:
	return defs.keys()


func get_def(id: String) -> ChassisDef:
	return defs.get(id)


## Chasis que puede usar un jugador de ese nivel.
func unlocked_at(player_level: int) -> Array[ChassisDef]:
	var out: Array[ChassisDef] = []
	for def: ChassisDef in defs.values():
		if def.unlock_level <= player_level:
			out.append(def)
	return out
