class_name Catalog
extends RefCounted
## Catalogo de piezas cargado desde JSON (data/catalog.json).
## Formato: {"schema_version": 1, "items": [{"id", "name", "type", "element",
## "tier_min", "tier_max"?, "tags"?, "top": {estadisticas de Divino maximo}}]}

const SCHEMA_VERSION := 1

var items: Dictionary[String, ItemDef] = {}
## Problemas de formato encontrados al cargar. El validador revisa el balance.
var errors: Array[String] = []


static func load_file(path: String) -> Catalog:
	var catalog := Catalog.new()
	if not FileAccess.file_exists(path):
		catalog.errors.append("no existe el archivo %s" % path)
		return catalog
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		catalog.errors.append("%s no es un objeto JSON valido" % path)
		return catalog
	catalog._load(parsed)
	return catalog


static func from_dict(data: Dictionary) -> Catalog:
	var catalog := Catalog.new()
	catalog._load(data)
	return catalog


func get_item(id: String) -> ItemDef:
	return items.get(id)


func by_type(type: ItemDef.Type) -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for def: ItemDef in items.values():
		if def.type == type:
			out.append(def)
	return out


## Arma un mech a partir de ids, con todas sus piezas al mismo tier y nivel.
## spec: {"torso", "legs", "sides": [], "tops": [], "drone", "modules": [],
## "charge", "teleport", "hook"}. Los ids desconocidos se anotan en errors.
## Arma un mech con todas sus piezas en esa clase y nivel. `parts` puede dar
## a cada pieza su propia clase y nivel: {id: {"tier", "level"}} (las piezas
## del jugador, PlayerProfile.parts).
func make_build(
	spec: Dictionary, rules: RulesConfig, tier: ItemDef.Tier, level: int, parts: Dictionary = {}
) -> MechBuild:
	var build := MechBuild.new()
	var resolve := func(id: Variant) -> ItemDef:
		if id == null or id == "":
			return null
		if not items.has(id):
			errors.append("build: no existe la pieza '%s'" % id)
			return null
		var own: Dictionary = parts.get((items[id] as ItemDef).progress_id(), {})
		var own_tier: ItemDef.Tier = own.get("tier", tier)
		return ItemScaling.resolve(items[id], rules, own_tier, own.get("level", level))
	build.torso = resolve.call(spec.get("torso"))
	build.legs = resolve.call(spec.get("legs"))
	build.assist = resolve.call(spec.get("assist"))
	# Con el progreso del asistente del jugador, sus armas suben con el.
	var follow: ItemDef = build.assist if parts.has(ItemDef.ASSIST_PROGRESS) else null
	build.drone = _assist_weapon(spec.get("drone"), follow, rules, resolve)
	build.drone_low = _assist_weapon(spec.get("drone_low"), follow, rules, resolve)
	# La segunda arma pelea desde la primera transformacion del asistente.
	if build.assist == null or build.assist.tier < rules.assist_second_weapon_tier:
		build.drone_low = null
	build.chest = resolve.call(spec.get("chest"))
	build.charge = resolve.call(spec.get("charge"))
	build.teleport = resolve.call(spec.get("teleport"))
	build.hook = resolve.call(spec.get("hook"))
	for key: String in ["sides", "tops", "modules"]:
		var list: Array[ItemDef] = []
		for id: Variant in spec.get(key, []):
			var def: ItemDef = resolve.call(id)
			if def != null:
				list.append(def)
		build.set(key, list)
	return build


## Arma del robot de asistencia del jugador: sube con el, a su clase y su
## nivel, sin salirse del rango de clases de su tipo. Sin ese progreso
## (rivales y simuladores, con todas las piezas a la misma clase) va como
## cualquier otra pieza.
func _assist_weapon(id: Variant, assist: ItemDef, rules: RulesConfig, resolve: Callable) -> ItemDef:
	if assist == null or id == null or id == "" or not items.has(id):
		return resolve.call(id)
	var def: ItemDef = items[id]
	var tier: ItemDef.Tier = clampi(assist.tier, def.tier_min, def.tier_max) as ItemDef.Tier
	var level := assist.level
	if tier < assist.tier:
		level = rules.tier_max_level[tier]
	elif tier > assist.tier:
		level = 0
	return ItemScaling.resolve(def, rules, tier, level)


func _load(data: Dictionary) -> void:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version distinto de %d" % SCHEMA_VERSION)
	var raw_items: Variant = data.get("items")
	if not raw_items is Array:
		errors.append("falta la lista 'items'")
		return
	for raw: Variant in raw_items:
		if not raw is Dictionary:
			errors.append("hay un item que no es un objeto")
			continue
		var def := _parse_item(raw)
		if def == null:
			continue
		if items.has(def.id):
			errors.append("id repetido: %s" % def.id)
			continue
		items[def.id] = def


func _parse_item(raw: Dictionary) -> ItemDef:
	var id: String = str(raw.get("id", ""))
	if id == "":
		errors.append("hay un item sin id")
		return null
	var def := ItemDef.new()
	def.id = id
	def.display_name = str(raw.get("name", ""))
	var ok := true
	ok = _parse_enum(raw, "type", ItemDef.Type, def, true) and ok
	ok = _parse_enum(raw, "element", ItemDef.Element, def, true) and ok
	ok = _parse_enum(raw, "tier_min", ItemDef.Tier, def, false) and ok
	ok = _parse_enum(raw, "tier_max", ItemDef.Tier, def, false) and ok
	def.tags = PackedStringArray(raw.get("tags", []))
	def.art = raw.get("art", {})
	def.weapon_type = str(raw.get("weapon_type", ""))
	def.form = str(raw.get("form", ""))
	def.fx = str(raw.get("fx", ""))
	def.crit_effect = str(raw.get("crit_effect", ""))
	if def.crit_effect != "" and not def.crit_effect in ItemDef.CRIT_EFFECTS:
		errors.append("%s: efecto de critico desconocido '%s'" % [id, def.crit_effect])
		return null
	var top: Variant = raw.get("top")
	if not top is Dictionary:
		errors.append("%s: falta el bloque 'top'" % id)
		return null
	for key: String in top:
		if not (key in ItemDef.SCALED_STATS or key in ItemDef.FIXED_STATS):
			errors.append("%s: estadistica desconocida '%s'" % [id, key])
			ok = false
			continue
		var value: Variant = top[key]
		if not (value is float or value is int) or value < 0 or value != floorf(value):
			errors.append("%s: '%s' debe ser un entero no negativo" % [id, key])
			ok = false
			continue
		def.set(key, int(value))
	for extra: String in raw:
		if not (
			extra
			in [
				"id",
				"name",
				"type",
				"element",
				"tier_min",
				"tier_max",
				"tags",
				"art",
				"top",
				"weapon_type",
				"form",
				"fx",
				"crit_effect",
			]
		):
			errors.append("%s: campo desconocido '%s'" % [id, extra])
			ok = false
	return def if ok else null


func _parse_enum(
	raw: Dictionary, key: String, values: Dictionary, def: ItemDef, required: bool
) -> bool:
	if not raw.has(key):
		if required:
			errors.append("%s: falta '%s'" % [def.id, key])
		return not required
	var name: String = str(raw[key])
	if not values.has(name):
		errors.append("%s: valor '%s' no valido en '%s'" % [def.id, name, key])
		return false
	def.set(key, values[name])
	return true
