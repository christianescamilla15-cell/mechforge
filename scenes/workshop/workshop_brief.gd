class_name WorkshopBrief
extends RefCounted
## Lo que ensenan las cosas del taller del hangar, armado con el perfil del
## jugador y los datos del juego: el tablero de piezas (PartsRack) de un
## hueco, las pantallas de mejoras y habilidades y la ficha del robot
## (WallConsole) y la lectura del robot junto a su bascula. Aqui no se
## dibuja ni se cambia nada: solo se prepara lo que hay que ver.

## Lo que lee el diagnostico, en su orden.
const DIAGNOSTIC_KEYS: Array[String] = [
	"weight",
	"health",
	"energy_cap",
	"energy_regen",
	"heat_cap",
	"cooling",
	"res_physical",
	"res_heat",
	"res_energy"
]

## Orden de los tipos de pieza en el catalogo: las formas de arma de cerca a
## lejos y, lo que no es arma, por elemento. Son las claves de texto.
const GROUP_KEYS: Array[String] = [
	"hoja",
	"corto",
	"medio",
	"largo",
	"saboteador",
	"bateria",
	"ancla",
	"artilleria",
	"canon_pesado",
	"nova",
	"artillero",
	"zapador"
]
## Los nombres de los tipos, en su orden (se arma una vez, con los textos).
static var group_order: Array[String] = _group_order()

var rules: RulesConfig
var catalog: Catalog
var library: BuildLibrary
var campaign: Campaign
var workshop: Workshop
var garage: Garage
var shop: ArenaShop
var skills: SkillTree
var progression: Progression
var styles: StyleLibrary


static func _group_order() -> Array[String]:
	var out: Array[String] = []
	for key in GROUP_KEYS:
		out.append(Txt.t("form_" + key))
	for element_name in Txt.ELEMENT_NAMES:
		out.append(element_name.to_lower())
	out.append("")
	return out


# --- El jugador -------------------------------------------------------------------


func level(profile: PlayerProfile) -> int:
	return progression.level_for(profile.xp)


## Clase de las piezas de la zona en la que esta.
func zone_tier(profile: PlayerProfile) -> int:
	return campaign.tier_of(mini(profile.zone, campaign.zone_count() - 1))


## Tope de las mejoras permanentes en su zona.
func armory_cap(profile: PlayerProfile) -> int:
	return campaign.armory_cap(mini(profile.zone, campaign.zone_count() - 1), shop)


## Clase del robot de asistencia; -1 si no lleva.
func assist_tier(profile: PlayerProfile) -> int:
	if not profile.build.has("assist"):
		return -1
	return profile.part(ItemDef.ASSIST_PROGRESS)["tier"]


## Un robot armado con ese equipo, a la clase y el nivel de las piezas del
## jugador (`parts`: otras, para probar una pieza que aun no tiene).
func build_of(profile: PlayerProfile, spec: Dictionary, parts: Dictionary = {}) -> MechBuild:
	var progress := profile.parts if parts.is_empty() else parts
	var build := catalog.make_build(spec, rules, ItemDef.Tier.COMMON, 0, progress)
	progression.apply_locks(build, level(profile))
	build.skills = skills.effects_for(profile.skills)
	# Lo que da el tipo de su robot (el escudo del guardian...).
	styles.add_effects(profile.style, build.skills)
	build.upgrades = shop.upgrades_for(profile.shop_levels)
	return build


## Una pieza con la clase y el nivel que tiene el jugador.
func resolved(profile: PlayerProfile, id: String) -> ItemDef:
	var def := catalog.get_item(id) if id != "" else null
	if def == null:
		return null
	var p := profile.part(def.progress_id())
	if def.type == ItemDef.Type.DRONE and profile.build.has("assist"):
		# Las armas del asistente suben con el, sin salirse de su rango.
		var assist := profile.part(ItemDef.ASSIST_PROGRESS)
		var tier := clampi(assist["tier"], def.tier_min, def.tier_max)
		var part_level: int = assist["level"]
		if tier < assist["tier"]:
			part_level = rules.tier_max_level[tier]
		elif tier > assist["tier"]:
			part_level = 0
		p = {"tier": tier, "level": part_level}
	return ItemScaling.resolve(def, rules, p["tier"], p["level"])


## Clase y nivel de una pieza, en corto: "Basica 3/6".
func progress_text(profile: PlayerProfile, item: ItemDef) -> String:
	if item == null:
		return ""
	if item.type == ItemDef.Type.DRONE and profile.build.has("assist"):
		return Txt.t("part_follows_assist")
	var p := profile.part(item.progress_id())
	var top: int = rules.tier_max_level[p["tier"]]
	return Txt.t("part_level", [Txt.TIER_NAMES[p["tier"]], p["level"], top])


## Por que un hueco esta cerrado ("" si esta abierto).
func lock_reason(profile: PlayerProfile, slot: String) -> String:
	if not progression.is_unlocked(slot, level(profile)):
		return Txt.t("slot_locked", [progression.unlock_level(slot)])
	if slot in ["drone", "drone_low"] and not Garage.has_assist(profile, catalog):
		return Txt.t("slot_needs_assist")
	if slot == "drone_low" and assist_tier(profile) < rules.assist_second_weapon_tier:
		return Txt.t("slot_second_weapon")
	return ""


## Formas de arma que monta en los brazos el tipo de ese robot, en una
## linea: "Brazos: hojas y armas cortas". "" si monta cualquiera.
func arms_text(style_id: String) -> String:
	var names: Array[String] = []
	for form in styles.forms(style_id, "sides"):
		names.append(Txt.t("form_" + form))
	if names.is_empty():
		return ""
	var last: String = names.pop_back()
	var listed := last if names.is_empty() else "%s y %s" % [", ".join(names), last]
	return Txt.t("style_arms", [listed])


## Hueco donde iria una pieza: el `preferred` si le cabe, o el primero libre
## de su tipo que su nivel ya abra.
func slot_for(profile: PlayerProfile, id: String, preferred: String) -> String:
	var locked: Array[String] = []
	for slot in Garage.SLOTS:
		if lock_reason(profile, slot) != "":
			locked.append(slot)
	return Garage.drop_slot(profile.build, catalog, id, preferred, locked)


# --- El tablero de piezas ----------------------------------------------------------


## El catalogo de un hueco (PartsRack.state): tus piezas de ese tipo y las
## que vende la tienda en tu zona, juntas y ordenadas por tipo (cada una con
## su "group": hojas, cortas...; las tuyas delante dentro de cada tipo), la
## que lleva el hueco y la tecla para subirla.
func rack(profile: PlayerProfile, slot: String) -> Dictionary:
	var mounted_id := Garage.get_slot(profile.build, slot)
	var tier := zone_tier(profile)
	var locked := lock_reason(profile, slot)
	var owned: Array[Dictionary] = []
	for id in Garage.owned_for(profile, catalog, slot):
		# Lo que su tipo no monta no cuelga en el tablero de este robot.
		if styles.why_cant_mount(profile.style, catalog.get_item(id)) != "":
			continue
		var item := resolved(profile, id)
		(
			owned
			. append(
				{
					"id": id,
					"item": item,
					"group": group_of(item),
					"owned": true,
					"mounted": id == mounted_id,
					"detail": progress_text(profile, item),
					"stats": item_stats(item, false),
					"price": -1,
					"reason": "",
					"note": "",
				}
			)
		)
	var note := ""
	if not progression.is_unlocked(slot, level(profile)):
		note = Txt.t("store_from_level", [progression.unlock_level(slot)])
	var sold: Array[Dictionary] = []
	for id in _on_sale(profile, slot, tier):
		var def := catalog.get_item(id)
		var item := ItemScaling.resolve(def, rules, tier, 0)
		var reason := garage.why_cant_buy(profile, catalog, rules, workshop, id, tier)
		if def.type == ItemDef.Type.ASSIST and locked != "":
			# El asistente se ve desde el principio, pero no se compra hasta
			# que el nivel del jugador abre su hueco.
			reason = locked
		(
			sold
			. append(
				{
					"id": id,
					"item": item,
					"group": group_of(item),
					"owned": false,
					"mounted": false,
					"detail":
					Txt.t("part_level", [Txt.TIER_NAMES[tier], 0, rules.tier_max_level[tier]]),
					"stats": item_stats(item, false),
					"price": garage.price(catalog, rules, workshop, id, tier),
					"reason": reason,
					"note": note,
				}
			)
		)
	var mounted := {}
	var key := {}
	var can_test := false
	if mounted_id != "" and locked == "":
		var item := resolved(profile, mounted_id)
		if item != null:
			mounted = {
				"item": item,
				"detail": progress_text(profile, item),
				"stats": item_stats(item, false)
			}
			key = upgrade_key(profile, item)
			can_test = item.deals_damage() and item.fx != ""
	# Lo que su tipo de robot monta en los brazos, delante de la pista.
	var arms := arms_text(profile.style) if slot.begins_with("side") else ""
	var hint := Txt.t("workshop_empty_hint" if owned.size() + sold.size() > 0 else "workshop_none")
	return {
		"slot": slot,
		"title": slot_title(slot),
		"locked": locked,
		"style": arms,
		"hint": hint if arms == "" else "%s. %s" % [arms, hint],
		"cells": profile.gold,
		"parts": _by_group(owned + sold),
		"mounted": mounted,
		"key": key,
		"can_test": can_test,
	}


## El tipo de una pieza, para agruparla en el catalogo: su forma si es un
## arma ("hojas", "cortas"...) y, si no, su elemento.
static func group_of(item: ItemDef) -> String:
	if item.form != "":
		return Txt.t("form_" + item.form)
	if item.type in [ItemDef.Type.TORSO, ItemDef.Type.LEGS, ItemDef.Type.MODULE]:
		return Txt.ELEMENT_NAMES[item.element].to_lower()
	return ""


## Las piezas juntas por tipo, en el orden en que aparece cada tipo; dentro
## de un tipo quedan como venian (las tuyas delante de las de la tienda).
static func _by_group(parts: Array[Dictionary]) -> Array[Dictionary]:
	var order: Array[String] = []
	for part in parts:
		if not str(part["group"]) in order:
			order.append(str(part["group"]))
	# Los tipos, en el orden de las formas del catalogo (de cerca a lejos).
	order.sort_custom(
		func(a: String, b: String) -> bool: return group_order.find(a) < group_order.find(b)
	)
	var out: Array[Dictionary] = []
	for group in order:
		for part in parts:
			if str(part["group"]) == group:
				out.append(part)
	return out


## Las casillas del plano del robot (LoadoutScreen): una por hueco, con lo
## que lleva: {"slot", "title", "item" (o null), "locked" (por que esta
## cerrado, "" si no), "selected"}.
func slots(profile: PlayerProfile, selected: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in Garage.SLOTS:
		(
			out
			. append(
				{
					"slot": slot,
					"title": slot_title(slot),
					"item": resolved(profile, Garage.get_slot(profile.build, slot)),
					"locked": lock_reason(profile, slot),
					"selected": slot == selected,
				}
			)
		)
	return out


## Lo que ensena la computadora del taller (LoadoutScreen): el plano con sus
## casillas y, al lado, el catalogo de la casilla elegida.
func loadout(profile: PlayerProfile, robot_name: String, selected: String) -> Dictionary:
	var list := rack(profile, selected)
	var style := ""
	if styles.has(profile.style):
		style = Txt.t("robot_style", [styles.role(profile.style), arms_text(profile.style)])
	return {
		"title": Txt.t("terminal_taller"),
		"robot": robot_name,
		"style": style,
		"cells": profile.gold,
		"selected": selected,
		"slots": slots(profile, selected),
		"list": list,
	}


## Lo que vende la tienda para ese hueco y aun no tiene: lo de su tipo de
## pieza que le cabe a su robot. El robot de asistencia se vende entero, una
## vez, con cualquiera de sus cuerpos.
func _on_sale(profile: PlayerProfile, slot: String, tier: int) -> Array[String]:
	var out: Array[String] = []
	if Garage.slot_type(slot) == ItemDef.Type.ASSIST:
		if not Garage.has_assist(profile, catalog):
			for def in catalog.by_type(ItemDef.Type.ASSIST):
				out.append(def.id)
			out.sort()
		return out
	for id in garage.stock_for(catalog, tier):
		var def := catalog.get_item(id)
		if def.type != Garage.slot_type(slot) or id in profile.owned:
			continue
		if styles.why_cant_mount(profile.style, def) == "":
			out.append(id)
	return out


## Lo que cambia en una pieza entre como esta (`now`) y como quedaria
## (`then`): "daño 37–48 → 39–50 · Vida 222 → 233". Vacio si no cambia nada.
static func stat_changes(now: ItemDef, then: ItemDef) -> String:
	var parts: Array[String] = []
	if now.deals_damage() and (now.dmg_min != then.dmg_min or now.dmg_max != then.dmg_max):
		var before := Txt.t("stat_damage", [now.dmg_min, now.dmg_max])
		parts.append("%s → %d–%d" % [before, then.dmg_min, then.dmg_max])
	for key in DIAGNOSTIC_KEYS:
		if key == "weight":
			continue
		var a: int = now.get(key)
		var b: int = then.get(key)
		if a != b:
			parts.append("%s %d → %d" % [Txt.t("stat_" + key), a, b])
	if now.energy_cost != then.energy_cost:
		parts.append("%s → %d" % [Txt.t("cost_energy", [now.energy_cost]), then.energy_cost])
	if now.heat_cost != then.heat_cost:
		parts.append("%s → %d" % [Txt.t("cost_heat", [now.heat_cost]), then.heat_cost])
	return " · ".join(parts)


## La tecla del lector para la pieza de un hueco: subirla de nivel,
## transformarla o el tope que la para. {"label", "enabled", "reason",
## "action" ("level" o "transform"), "gain" (lo que cambia en la pieza)};
## vacio si la pieza no sube sola.
func upgrade_key(profile: PlayerProfile, item: ItemDef) -> Dictionary:
	if item.type == ItemDef.Type.DRONE and profile.build.has("assist"):
		return {}
	var id := item.progress_id()
	var p := profile.part(id)
	var max_tier := zone_tier(profile)
	if p["level"] < rules.tier_max_level[p["tier"]]:
		var cap := campaign.level_cap(profile.zone)
		var reason := profile.why_cant_level(workshop, rules, id, max_tier, cap)
		var label := Txt.t("part_level_up", [workshop.level_cost(rules, p["tier"], p["level"])])
		if reason == "la zona no deja subirla mas":
			label = Txt.t("part_zone_max")
		var raised := ItemScaling.resolve(
			catalog.get_item(item.id), rules, p["tier"], p["level"] + 1
		)
		return {
			"label": label,
			"enabled": reason == "",
			"reason": reason,
			"action": "level",
			"gain": stat_changes(item, raised),
		}
	var item_max := catalog.get_item(item.id).tier_max
	var why := profile.why_cant_transform(workshop, rules, id, max_tier, item_max)
	var text := Txt.t("part_transform", [workshop.transform_cost(p["tier"])])
	if p["tier"] == ItemDef.Tier.MYTHIC:
		text = Txt.t("part_unique")
	if not why in ["", "faltan celdas"]:
		text = Txt.t("part_zone_max" if why.contains("zona") else "shop_max")
	var gain := ""
	if p["tier"] < item_max:
		var next := ItemScaling.resolve(catalog.get_item(item.id), rules, p["tier"] + 1, 0)
		gain = stat_changes(item, next)
	return {"label": text, "enabled": why == "", "reason": why, "action": "transform", "gain": gain}


# --- Las pantallas ------------------------------------------------------------------


## La pantalla de mejoras (WallConsole): una fila por mejora permanente.
## "state" de cada fila: "ok" (se puede subir), "poor" (faltan celdas),
## "cap" (tope de la zona), "locked" (aun no se abre) o "max".
func upgrades(profile: PlayerProfile) -> Dictionary:
	var cap := armory_cap(profile)
	var top := shop.max_level()
	var rows: Array[Dictionary] = []
	for track in shop.track_ids():
		var now := profile.level_of(track)
		var row := {
			"id": track,
			"name": shop.display_name(track),
			"level": now,
			"value": Txt.t("upgrade_level", [now, top, value_text(track, now)]),
			"state": "ok",
			"label": "",
			"reason": "",
			"gain": "",
		}
		if now >= top:
			row["state"] = "max"
			row["label"] = Txt.t("shop_max")
			row["reason"] = Txt.t("shop_max")
		else:
			var reason := profile.why_cant_buy(shop, track, cap, level(profile))
			row["label"] = HangarProps.thousands(shop.price(now + 1))
			row["gain"] = Txt.t(
				shop.gain_key(track), [value_text(track, now + 1), shop.price(now + 1)]
			)
			row["reason"] = reason
			if reason.begins_with("se abre en el nivel"):
				row["state"] = "locked"
				row["label"] = Txt.t("slot_locked", [shop.player_level(track)])
			elif reason.begins_with("se abre"):
				row["state"] = "locked"
				row["label"] = Txt.t("shop_locked_assist")
			elif reason == "la zona no deja subirla mas":
				row["state"] = "cap"
				row["label"] = Txt.t("part_zone_max")
				row["reason"] = Txt.t("shop_zone_cap", [cap])
			elif reason != "":
				row["state"] = "poor"
		rows.append(row)
	return {
		"kind": "mejoras",
		"title": Txt.t("terminal_mejoras"),
		"info": Txt.t("upgrades_page_info", [cap, top]),
		"cells": profile.gold,
		"cap": cap,
		"max": top,
		"rows": rows,
	}


## Lo que da una mejora a ese nivel: "+5 %" o "+123".
func value_text(track: String, track_level: int) -> String:
	var amount := shop.value(track, track_level)
	if shop.tracks[track]["kind"] == "percent":
		return "+%d %%" % roundi(amount * 100.0)
	return ("+%d %s" % [roundi(amount), shop.unit(track)]).strip_edges()


## La pantalla de habilidades (WallConsole): las ramas con sus nodos. "state"
## de cada nodo: "done" (aprendida), "next" (la que toca en su rama; con
## "reason" si aun no se puede) o "closed".
func skill_tree(profile: PlayerProfile) -> Dictionary:
	var now := level(profile)
	var branches: Array[Dictionary] = []
	for branch: Dictionary in skills.branches:
		var done := skills.learned_in(profile, branch["id"])
		var nodes: Array[Dictionary] = []
		var raw: Array = branch["nodes"]
		for i in raw.size():
			var node: Dictionary = raw[i]
			var kind := "done" if i < done else ("next" if i == done else "closed")
			var reason := ""
			if kind == "next":
				reason = skills.why_cant_learn(profile, node["id"], now)
			elif kind == "closed":
				reason = Txt.t("console_skill_closed")
			(
				nodes
				. append(
					{
						"id": str(node["id"]),
						"name": str(node["name"]),
						"text": SkillTree.describe(node),
						"state": kind,
						"reason": reason,
					}
				)
			)
		branches.append(
			{"id": str(branch["id"]), "name": str(branch["name"]), "done": done, "nodes": nodes}
		)
	return {
		"kind": "habilidades",
		"title": Txt.t("terminal_habilidades"),
		"points": skills.points_left(profile, now),
		"level": now,
		"branches": branches,
	}


## La ficha del robot que usa (WallConsole): su nombre, su diseno y si se
## puede desmontar.
func robot(profile: PlayerProfile, robot_name: String) -> Dictionary:
	var entry: Dictionary = profile.mechs[profile.active]
	var design := str(entry.get("design", ""))
	var several := profile.mechs.size() > 1
	var line := ""
	if styles.has(profile.style):
		line = Txt.t("robot_style", [styles.role(profile.style), arms_text(profile.style)])
	elif library.specs.has(design):
		line = Txt.t("robot_design", [library.display_name(design)])
	return {
		"kind": "robot",
		"title": robot_name,
		"design": line,
		"hint": Txt.t("robot_page_hint") + (" " + Txt.t("robot_remove_note") if several else ""),
		"can_remove": several,
	}


# --- Adquirir un robot ----------------------------------------------------------------


## Los tipos de robot con los que se empieza (StarterSelect.entries): su
## tipo, su nombre, su historia, como pelea, que monta en los brazos y con
## que arma empieza, y el robot armado para verlo.
func starters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for style_id in styles.ids():
		var spec := styles.build(style_id)
		var weapons: Array[String] = []
		for id: Variant in spec.get("sides", []) + spec.get("tops", []):
			if catalog.get_item(str(id)) != null:
				weapons.append(catalog.get_item(str(id)).display_name)
		(
			out
			. append(
				{
					"id": style_id,
					"role": styles.role(style_id),
					"name": styles.display_name(style_id),
					"story": styles.story(style_id),
					"mechanic": styles.mechanic(style_id),
					"arms": arms_text(style_id),
					"kit": Txt.t("starter_kit", [", ".join(weapons)]),
					"build": catalog.make_build(spec, rules, ItemDef.Tier.COMMON, 0),
				}
			)
		)
	return out


## Lo que puede fabricar una bahia vacia (BayProjector.state): un armazon
## vacio de cada tipo de robot, gratis, que se arma con tus piezas. "reason"
## dice por que no se puede ("" = se puede).
func offers(profile: PlayerProfile) -> Dictionary:
	var out: Array[Dictionary] = []
	var why := _offer_reason(profile.why_cant_add_mech(rules))
	for style_id in styles.ids():
		(
			out
			. append(
				{
					"id": style_id,
					"name": Txt.t("acquire_style", [styles.role(style_id)]),
					"hint": arms_text(style_id),
					"price": 0,
					"reason": why,
					"build": null,
				}
			)
		)
	return {"offers": out}


## Por que no se puede adquirir, en corto ("" = se puede): los armazones son
## gratis, asi que solo lo impide el garaje lleno.
func _offer_reason(why: String) -> String:
	return "" if why == "" else Txt.t("acquire_why_full")


# --- El diagnostico -----------------------------------------------------------------


## Lo que lee el diagnostico del robot: una fila por estadistica, {"key",
## "label", "value", "delta", "better"}, con el peso la primera (y aparte,
## para la bascula). Con `hover_id` en `hover_slot`, "delta" es lo que
## cambiaria con esa pieza puesta ahi.
func diagnostic(
	profile: PlayerProfile, hover_id: String = "", hover_slot: String = ""
) -> Dictionary:
	var now := build_of(profile, profile.build).summary(rules)
	var then := now
	if hover_id != "" and hover_slot != "":
		var spec: Dictionary = profile.build.duplicate(true)
		Garage.set_slot(spec, hover_slot, hover_id)
		var parts := profile.parts.duplicate(true)
		var def := catalog.get_item(hover_id)
		if def != null and not hover_id in profile.owned:
			# Una pieza de la tienda llega en la clase de la zona, a nivel 0.
			parts[def.progress_id()] = {"tier": zone_tier(profile), "level": 0}
		then = build_of(profile, spec, parts).summary(rules)
	var rows: Array[Dictionary] = []
	for key in DIAGNOSTIC_KEYS:
		var delta := int(then[key]) - int(now[key])
		(
			rows
			. append(
				{
					"key": key,
					"label": Txt.t("stat_weight_total" if key == "weight" else "stat_" + key),
					"value": int(now[key]),
					"delta": delta,
					# Mas de todo es mejor, salvo mas peso.
					"better": delta < 0 if key == "weight" else delta > 0,
				}
			)
		)
	return {
		"rows": rows,
		"weight": int(now["weight"]),
		"weight_delta": int(then["weight"]) - int(now["weight"]),
	}


# --- Textos -----------------------------------------------------------------------


## Nombre de un hueco: "Lateral 1", "Torso"...
static func slot_title(slot: String) -> String:
	var base := slot.rstrip("0123456789")
	var digits := slot.trim_prefix(base)
	var number := " %d" % (int(digits) + 1) if digits != "" else ""
	return Txt.t("slot_" + base) + number


## Lo que hace una pieza, en una linea (o en varias con `long`).
static func item_stats(item: ItemDef, long: bool) -> String:
	var parts: Array[String] = []
	if item.deals_damage():
		parts.append(Txt.t("stat_damage", [item.dmg_min, item.dmg_max]))
		parts.append(Txt.t("range", [item.range_min, item.range_max]))
		if item.energy_cost > 0:
			parts.append(Txt.t("cost_energy", [item.energy_cost]))
		if item.heat_cost > 0:
			parts.append(Txt.t("cost_heat", [item.heat_cost]))
		if item.uses > 0:
			parts.append(Txt.t("uses", [item.uses]))
	for key in ["health", "energy_cap", "energy_regen", "heat_cap", "cooling"]:
		var value: int = item.get(key)
		if value != 0:
			parts.append("%s %+d" % [Txt.t("stat_" + key), value])
	var res := [item.res_physical, item.res_heat, item.res_energy]
	if res.max() > 0:
		parts.append("%s %d/%d/%d" % [Txt.t("resist"), res[0], res[1], res[2]])
	if item.weight > 0:
		parts.append(Txt.t("stat_weight", [item.weight]))
	return ("\n" if long else " · ").join(parts)
