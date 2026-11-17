class_name Garage
extends RefCounted
## Taller de armado (GDD 4 y 8): el jugador arma su mech hueco a hueco con las
## piezas que tiene, y la tienda de la armeria le vende piezas nuevas. El mech
## se guarda en PlayerProfile.build con el formato de los "items" de
## data/builds.json.
## Datos de la tienda en data/part_shop.json: {"schema_version",
## "base_prices": {tipo: celdas}}. Se vende lo que existe en la clase de la
## zona: las piezas cuyo rango de clases (tier_min a tier_max) la incluye.

## Huecos del mech, en el orden en que se muestran.
const SLOTS: Array[String] = [
	"torso",
	"legs",
	"side0",
	"side1",
	"side2",
	"side3",
	"top0",
	"top1",
	"drone",
	"module0",
	"module1",
	"module2",
	"module3",
	"module4",
	"module5",
	"module6",
	"module7",
	"charge",
	"teleport",
	"hook",
]
## Huecos que son listas en el formato de builds.json, con su prefijo.
const LISTS := {"side": "sides", "top": "tops", "module": "modules"}

## Precio base de una pieza nueva por tipo (nombre de ItemDef.Type).
var base_prices: Dictionary = {}
var errors: Array[String] = []


static func load_file(path: String) -> Garage:
	var garage := Garage.new()
	if not FileAccess.file_exists(path):
		garage.errors.append("no existe el archivo %s" % path)
		return garage
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		garage.errors.append("%s no es un diccionario" % path)
		return garage
	if parsed.get("base_prices") is Dictionary:
		garage.base_prices = parsed["base_prices"]
	for type: String in ItemDef.Type.keys():
		if int(garage.base_prices.get(type, 0)) <= 0:
			garage.errors.append("falta el precio base de %s" % type)
	return garage


## Tipo de pieza que va en un hueco.
static func slot_type(slot: String) -> ItemDef.Type:
	for prefix: String in LISTS:
		if slot.begins_with(prefix):
			return ItemDef.Type[prefix.to_upper()]
	return ItemDef.Type[slot.to_upper()]


## Pieza montada en un hueco del mech; "" si esta vacio.
static func get_slot(build: Dictionary, slot: String) -> String:
	for prefix: String in LISTS:
		if slot.begins_with(prefix):
			var list: Array = build.get(LISTS[prefix], [])
			var index := int(slot.trim_prefix(prefix))
			return str(list[index]) if index < list.size() and list[index] != null else ""
	var value: Variant = build.get(slot)
	return str(value) if value != null else ""


## Monta una pieza en un hueco ("" lo deja vacio). Las listas se rellenan con
## huecos vacios si hace falta.
static func set_slot(build: Dictionary, slot: String, id: String) -> void:
	for prefix: String in LISTS:
		if slot.begins_with(prefix):
			var list: Array = build.get(LISTS[prefix], []).duplicate()
			var index := int(slot.trim_prefix(prefix))
			while list.size() <= index:
				list.append("")
			list[index] = id
			while not list.is_empty() and str(list[-1]) == "":
				list.pop_back()
			build[LISTS[prefix]] = list
			return
	if id == "":
		build.erase(slot)
	else:
		build[slot] = id


## Devuelve "" si el jugador puede montar esa pieza en ese hueco; si no, el
## motivo. Quitar una pieza ("") siempre se puede: lo que falte lo avisa
## MechBuild.validate.
static func why_cant_equip(
	profile: PlayerProfile, catalog: Catalog, slot: String, id: String
) -> String:
	if not slot in SLOTS:
		return "ese hueco no existe"
	if id == "":
		return ""
	if not id in profile.owned:
		return "no tienes esa pieza"
	if catalog.get_item(id) == null or catalog.get_item(id).type != slot_type(slot):
		return "no va en ese hueco"
	return ""


static func equip(profile: PlayerProfile, catalog: Catalog, slot: String, id: String) -> String:
	var reason := why_cant_equip(profile, catalog, slot, id)
	if reason == "":
		set_slot(profile.build, slot, id)
	return reason


## Piezas que tiene el jugador y caben en ese hueco.
static func owned_for(profile: PlayerProfile, catalog: Catalog, slot: String) -> Array[String]:
	var out: Array[String] = []
	for id in profile.owned:
		var def := catalog.get_item(id)
		if def != null and def.type == slot_type(slot):
			out.append(id)
	return out


## Piezas que vende la tienda en una zona de esa clase, por tipo y por id.
func stock_for(catalog: Catalog, zone_tier: int) -> Array[String]:
	var out: Array[String] = []
	for type in ItemDef.Type.values():
		var ids: Array[String] = []
		for def in catalog.by_type(type):
			if def.tier_min <= zone_tier and zone_tier <= def.tier_max:
				ids.append(def.id)
		ids.sort()
		out.append_array(ids)
	return out


## Lo que cuesta una pieza nueva en una zona de esa clase. Llega en esa clase
## al nivel 0, asi que cuesta su precio base mas lo que costaria llevar una
## pieza hasta ahi en el taller.
func price(
	catalog: Catalog, rules: RulesConfig, workshop: Workshop, id: String, zone_tier: int
) -> int:
	var type: String = ItemDef.Type.keys()[catalog.get_item(id).type]
	var base := roundi(int(base_prices[type]) * rules.tier_mult[zone_tier])
	return base + workshop.total_cost(rules, zone_tier, 0)


func why_cant_buy(
	profile: PlayerProfile,
	catalog: Catalog,
	rules: RulesConfig,
	workshop: Workshop,
	id: String,
	zone_tier: int
) -> String:
	if id in profile.owned:
		return "ya la tienes"
	if not id in stock_for(catalog, zone_tier):
		return "no se vende en esta zona"
	if price(catalog, rules, workshop, id, zone_tier) > profile.gold:
		return "faltan celdas"
	return ""


## Compra una pieza: pasa a ser del jugador, en la clase de la zona y nivel 0.
func buy(
	profile: PlayerProfile,
	catalog: Catalog,
	rules: RulesConfig,
	workshop: Workshop,
	id: String,
	zone_tier: int
) -> String:
	var reason := why_cant_buy(profile, catalog, rules, workshop, id, zone_tier)
	if reason != "":
		return reason
	profile.gold -= price(catalog, rules, workshop, id, zone_tier)
	profile.owned.append(id)
	var current := profile.part(id)
	if current["tier"] < zone_tier:
		profile.parts[id] = {"tier": zone_tier, "level": 0}
	return ""
