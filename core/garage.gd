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
	"top0",
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
	"module8",
	"charge",
	"teleport",
	"hook",
]
## Huecos que son listas en el formato de builds.json, con su prefijo.
const LISTS := {"side": "sides", "top": "tops", "module": "modules"}
## La familia de cada hueco de modulo, en orden (OBS-040, del usuario:
## "para cada modulo tendria que haber una seleccion especial... 3 modulos
## dedicados a resistencia... 3 dedicados a ataque y asi"). Cada hueco solo
## monta modulos de su familia.
const MODULE_FAMILIES: Array[String] = [
	"resistencia",
	"resistencia",
	"resistencia",
	"ataque",
	"ataque",
	"ataque",
	"sistemas",
	"sistemas",
	"sistemas",
]
## Colores con los que se puede pintar una pieza (OBS-010): los tres en los
## que existe su dibujo, con el nombre de su elemento (blanco, rojo, azul).
const PAINTS: Array[String] = ["PHYSICAL", "HEAT", "ENERGY"]
## Huecos cuya pieza se ve en el robot y se puede pintar.
const PAINTABLE: Array[String] = ["torso", "legs", "chest", "assist", "side", "top"]

## Precio base de una pieza nueva por tipo (nombre de ItemDef.Type).
## Cuantas veces el precio de su tipo cuesta el arma especial de un campeon.
var boss_weapon_mult: int = 1
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
	garage.boss_weapon_mult = int(parsed.get("boss_weapon_mult", 1))
	if garage.boss_weapon_mult < 1:
		garage.errors.append("boss_weapon_mult debe ser 1 o mas")
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


## True si la pieza de ese hueco se ve en el robot y se puede pintar.
static func can_paint(slot: String) -> bool:
	for prefix in PAINTABLE:
		if slot == prefix or (prefix in LISTS and slot.begins_with(prefix)):
			return true
	return false


## Color con el que esta pintado un hueco (uno de PAINTS); "" si va con el
## color de su elemento.
static func paint_of(build: Dictionary, slot: String) -> String:
	var paint: Variant = build.get("paint")
	if not paint is Dictionary:
		return ""
	var color := str(paint.get(slot, ""))
	return color if color in PAINTS else ""


## Pinta un hueco de ese color (uno de PAINTS); "" le quita la pintura. Lo
## que no se puede pintar, o un color que no existe, no cambia nada.
static func set_paint(build: Dictionary, slot: String, color: String) -> void:
	if not can_paint(slot) or not (color == "" or color in PAINTS):
		return
	var paint: Dictionary = {}
	if build.get("paint") is Dictionary:
		paint = (build["paint"] as Dictionary).duplicate()
	if color == "":
		paint.erase(slot)
	else:
		paint[slot] = color
	if paint.is_empty():
		build.erase("paint")
	else:
		build["paint"] = paint


## Devuelve "" si el jugador puede montar esa pieza en ese hueco; si no, el
## motivo. Quitar una pieza ("") siempre se puede: lo que falte lo avisa
## MechBuild.validate. Con `styles`, el tipo de su robot dice que armas le
## caben (StyleLibrary.why_cant_mount).
static func why_cant_equip(
	profile: PlayerProfile, catalog: Catalog, slot: String, id: String, styles: StyleLibrary = null
) -> String:
	if not slot in SLOTS:
		return "ese hueco no existe"
	if id == "":
		return ""
	if not id in profile.owned:
		return "no tienes esa pieza"
	if catalog.get_item(id) == null or catalog.get_item(id).type != slot_type(slot):
		return "no va en ese hueco"
	if not fits(catalog.get_item(id), slot):
		return "ese modulo es de otra familia"
	if module_clash(profile.build, catalog, slot, id) != "":
		return "repite una resistencia"
	if styles != null:
		return styles.why_cant_mount(profile.style, catalog.get_item(id))
	return ""


static func equip(
	profile: PlayerProfile, catalog: Catalog, slot: String, id: String, styles: StyleLibrary = null
) -> String:
	var reason := why_cant_equip(profile, catalog, slot, id, styles)
	if reason == "":
		# Un modulo va en un solo hueco: si ya iba en otro, se pasa a este.
		var before := module_slot_of(profile.build, id, slot) if id != "" else ""
		if before != "":
			set_slot(profile.build, before, "")
		set_slot(profile.build, slot, id)
	return reason


## True si el jugador tiene el robot de asistencia (alguno de sus cuerpos).
static func has_assist(profile: PlayerProfile, catalog: Catalog) -> bool:
	for id in profile.owned:
		var def := catalog.get_item(id)
		if def != null and def.type == ItemDef.Type.ASSIST:
			return true
	return false


## Completa el robot de asistencia de quien ya lo tiene: los cuatro cuerpos
## (uno por protocolo, que se cambia gratis), uno montado en el robot que usa
## y su progreso, que arranca del de su dron. El asistente se compra
## (decision del usuario, 2026-11-20, OBS-013): solo se le da sin comprarlo a
## las partidas de cuando se regalaba (PlayerProfile.legacy_assist).
static func ensure_assist(profile: PlayerProfile, catalog: Catalog) -> void:
	var bodies := catalog.by_type(ItemDef.Type.ASSIST)
	if not profile.has_mech() or bodies.is_empty():
		return
	if not profile.legacy_assist and not has_assist(profile, catalog):
		return
	profile.legacy_assist = false
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


## Piezas que tiene el jugador y caben en ese hueco.
static func owned_for(profile: PlayerProfile, catalog: Catalog, slot: String) -> Array[String]:
	var out: Array[String] = []
	for id in profile.owned:
		var def := catalog.get_item(id)
		if def != null and fits(def, slot):
			out.append(id)
	return out


## True si la pieza va en ese hueco: su tipo y, en los modulos, su familia.
static func fits(def: ItemDef, slot: String) -> bool:
	if def == null or def.type != slot_type(slot):
		return false
	return def.type != ItemDef.Type.MODULE or def.family == slot_family(slot)


## Familia de un hueco de modulo (MODULE_FAMILIES); "" si no es de modulo.
static func slot_family(slot: String) -> String:
	if not slot.begins_with("module"):
		return ""
	var index := int(slot.trim_prefix("module"))
	return MODULE_FAMILIES[index] if index >= 0 and index < MODULE_FAMILIES.size() else ""


## Hueco de modulo en el que ya va esa pieza, sin contar `except`; "".
static func module_slot_of(build: Dictionary, id: String, except: String = "") -> String:
	for slot in SLOTS:
		if slot.begins_with("module") and slot != except and get_slot(build, slot) == id:
			return slot
	return ""


## Si montar ese modulo en ese hueco repetiria una resistencia que ya da
## otro (GDD: un modulo por tipo de resistencia), el hueco de ese otro; "".
## No cuentan el que se quita de ese hueco ni el mismo modulo si se mueve.
static func module_clash(build: Dictionary, catalog: Catalog, slot: String, id: String) -> String:
	var def := catalog.get_item(id)
	if def == null or def.type != ItemDef.Type.MODULE:
		return ""
	var res := [def.res_physical, def.res_heat, def.res_energy]
	for other_slot in SLOTS:
		if not other_slot.begins_with("module") or other_slot == slot:
			continue
		var other_id := get_slot(build, other_slot)
		var other := catalog.get_item(other_id) if other_id != id else null
		if other == null:
			continue
		var theirs := [other.res_physical, other.res_heat, other.res_energy]
		for i in 3:
			if res[i] > 0 and theirs[i] > 0:
				return other_slot
	return ""


## Piezas que vende la tienda en una zona de esa clase, por tipo y por id.
func stock_for(catalog: Catalog, zone_tier: int) -> Array[String]:
	var out: Array[String] = []
	for type in ItemDef.Type.values():
		# El robot de asistencia va aparte: se compra una vez (why_cant_buy).
		if type == ItemDef.Type.ASSIST:
			continue
		var ids: Array[String] = []
		for def in catalog.by_type(type):
			# Las armas de campeon no se venden aqui: se abren al vencerlo
			# (Campaign.boss_weapons_open).
			if def.has_tag(ItemDef.TAG_BOSS):
				continue
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
	# El arma especial de un campeon, "por un alto coste" (GDD 9.4).
	if catalog.get_item(id).has_tag(ItemDef.TAG_BOSS):
		base *= boss_weapon_mult
	return base + workshop.total_cost(rules, zone_tier, 0)


## El robot de asistencia se compra una vez, eligiendo cualquiera de sus
## cuerpos: con el vienen los cuatro protocolos, que luego se cambian gratis.
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
	var def := catalog.get_item(id)
	if def != null and def.type == ItemDef.Type.ASSIST:
		if has_assist(profile, catalog):
			return "ya la tienes"
	elif not id in stock_for(catalog, zone_tier):
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
	if catalog.get_item(id).type == ItemDef.Type.ASSIST:
		# El asistente entero: los demas protocolos, montado con el que se
		# eligio y con su progreso en la clase de la zona.
		profile.build["assist"] = id
		profile.parts[ItemDef.ASSIST_PROGRESS] = {"tier": zone_tier, "level": 0}
		ensure_assist(profile, catalog)
		return ""
	var current := profile.part(id)
	if current["tier"] < zone_tier:
		profile.parts[id] = {"tier": zone_tier, "level": 0}
	return ""
