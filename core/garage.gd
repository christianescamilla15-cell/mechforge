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
	"chest",
	"assist",
	"drone",
	"drone_low",
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
	if slot == "drone_low":
		return ItemDef.Type.DRONE
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


## Da al jugador los cuerpos del robot de asistencia (uno por protocolo, que
## se cambia gratis) y le monta uno si su mech no lo lleva, como en las
## partidas de antes del asistente; su progreso arranca del de su dron.
static func ensure_assist(profile: PlayerProfile, catalog: Catalog) -> void:
	var bodies := catalog.by_type(ItemDef.Type.ASSIST)
	if not profile.has_mech() or bodies.is_empty():
		return
	var ids: Array[String] = []
	for def in bodies:
		ids.append(def.id)
	ids.sort()
	for id in ids:
		if not id in profile.owned:
			profile.owned.append(id)
	if str(profile.build.get("assist", "")) == "":
		profile.build["assist"] = ids[0]
	var drone := str(profile.build.get("drone", ""))
	if not profile.parts.has(ItemDef.ASSIST_PROGRESS):
		profile.parts[ItemDef.ASSIST_PROGRESS] = profile.part(drone).duplicate()


## Hueco en el que se monta una pieza que se suelta sobre el mech: el
## `preferred` si le cabe; si no, el primer hueco vacio de su tipo; si no, el
## primero de su tipo. Se salta los huecos de `locked` (los que el nivel del
## jugador aun no abre). "" si no cabe en ninguno.
static func drop_slot(
	build: Dictionary,
	catalog: Catalog,
	id: String,
	preferred: String = "",
	locked: Array[String] = []
) -> String:
	var def := catalog.get_item(id)
	if def == null:
		return ""
	var fits: Array[String] = []
	for slot in SLOTS:
		if slot_type(slot) == def.type and not slot in locked:
			fits.append(slot)
	if preferred in fits:
		return preferred
	for slot in fits:
		if get_slot(build, slot) == "":
			return slot
	return fits[0] if not fits.is_empty() else ""


## Piezas de un mech de ejemplo que el jugador aun no tiene.
static func missing_parts(
	profile: PlayerProfile, library: BuildLibrary, design: String
) -> Array[String]:
	var out: Array[String] = []
	for id in library.item_ids(design):
		if not id in profile.owned and not id in out:
			out.append(id)
	return out


## Lo que cuesta adquirir un robot con ese diseno: solo las piezas que aun no
## tiene, al precio de la tienda de la zona. Los cuerpos del asistente no se
## cobran (se tienen todos).
func design_price(
	profile: PlayerProfile,
	library: BuildLibrary,
	catalog: Catalog,
	rules: RulesConfig,
	workshop: Workshop,
	design: String,
	zone_tier: int
) -> int:
	var total := 0
	for id in missing_parts(profile, library, design):
		if catalog.get_item(id).type != ItemDef.Type.ASSIST:
			total += price(catalog, rules, workshop, id, zone_tier)
	return total


func why_cant_buy_design(
	profile: PlayerProfile,
	library: BuildLibrary,
	catalog: Catalog,
	rules: RulesConfig,
	workshop: Workshop,
	design: String,
	zone_tier: int
) -> String:
	if not design in library.starter_ids():
		return "ese diseno no se vende"
	var reason := profile.why_cant_add_mech(rules)
	if reason != "":
		return reason
	var stock := stock_for(catalog, zone_tier)
	for id in missing_parts(profile, library, design):
		var def := catalog.get_item(id)
		if def.type != ItemDef.Type.ASSIST and not id in stock:
			return "lleva piezas que esta zona no vende"
	if design_price(profile, library, catalog, rules, workshop, design, zone_tier) > profile.gold:
		return "faltan celdas"
	return ""


## Adquiere un robot con un diseno de ejemplo: compra en la tienda de la zona
## las piezas que faltan (llegan en su clase, nivel 0) y lo monta con ellas.
## Pasa a ser el que usa. Devuelve "" o el motivo.
func buy_design(
	profile: PlayerProfile,
	library: BuildLibrary,
	catalog: Catalog,
	rules: RulesConfig,
	workshop: Workshop,
	design: String,
	zone_tier: int
) -> String:
	var reason := why_cant_buy_design(profile, library, catalog, rules, workshop, design, zone_tier)
	if reason != "":
		return reason
	for id in missing_parts(profile, library, design):
		if catalog.get_item(id).type == ItemDef.Type.ASSIST:
			profile.owned.append(id)
		else:
			buy(profile, catalog, rules, workshop, id, zone_tier)
	(
		profile
		. mechs
		. append(
			{
				"name": library.display_name(design),
				"design": design,
				"build": library.specs[design]["items"].duplicate(true),
			}
		)
	)
	profile.active = profile.mechs.size() - 1
	return ""


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
		# Los cuerpos del robot de asistencia no se venden: se tienen todos.
		if type == ItemDef.Type.ASSIST:
			continue
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
