class_name SpecialistBrief
extends RefCounted
## Lo que ensena el banco del especialista (SpecialistScreen, GDD 8.6): tus
## seis piezas con prototipo, la elegida y los prototipos que le caben, con lo
## que hace el rango siguiente, su precio y, si no se puede, por que. No
## decide nada: comprar es PrototypeLibrary.buy.

## Los huecos con prototipo, en el orden en que se ensenan.
const SLOTS: Array[String] = ["side0", "side1", "top0", "chest", "torso", "legs"]
const ROMAN: Array[String] = ["", "I", "II", "III", "IV", "V"]


## `slot`: la pieza elegida; `said`: lo que dice ahora el especialista ("" =
## lo de siempre).
static func state(
	profile: PlayerProfile,
	brief: WorkshopBrief,
	protos: PrototypeLibrary,
	slot: String,
	said: String = ""
) -> Dictionary:
	var level := brief.level(profile)
	var locked := (
		Txt.t("proto_locked", [protos.unlock_level]) if level < protos.unlock_level else ""
	)
	var pieces: Array[Dictionary] = []
	for each in SLOTS:
		var piece := brief.resolved(profile, Garage.get_slot(profile.build, each))
		var entry := {
			"slot": each,
			"title": WorkshopBrief.slot_title(each),
			"item": piece,
			"selected": each == slot,
			"proto": "",
			"rank": 0,
		}
		var mounted := _installed(profile, protos, piece)
		entry["proto"] = _summary(protos, mounted)
		entry["count"] = mounted.size()
		pieces.append(entry)
	var item := brief.resolved(profile, Garage.get_slot(profile.build, slot))
	var now := _installed(profile, protos, item)
	var list: Array[Dictionary] = []
	for id in protos.ids_for(slot):
		list.append(_proto_entry(profile, brief, protos, level, slot, id, now))
	var installed := _summary(protos, now)
	var line := said
	if line == "":
		if locked != "":
			line = Txt.t("specialist_line_locked", [protos.unlock_level])
		elif item == null:
			line = Txt.t("specialist_line_empty")
		else:
			line = Txt.t("specialist_line_pick")
	return {
		"cells": profile.gold,
		"level": level,
		"locked": locked,
		"slot": slot,
		"pieces": pieces,
		"item": item,
		"installed": installed,
		"protos": list,
		"line": line,
	}


static func _proto_entry(
	profile: PlayerProfile,
	brief: WorkshopBrief,
	protos: PrototypeLibrary,
	level: int,
	slot: String,
	id: String,
	now: Dictionary
) -> Dictionary:
	var rank_now := int(now.get(id, 0))
	var maxed := rank_now >= protos.ranks
	var rank_next := mini(rank_now + 1, protos.ranks)
	var reason := (
		Txt.t("proto_max_rank")
		if maxed
		else protos.why_cant_buy(profile, brief.catalog, level, slot, id)
	)
	var text := effect_text(protos, id, rank_next)
	if rank_now > 0 and not maxed:
		text = "%s %s" % [text, Txt.t("specialist_now", [short_value(protos, id, rank_now)])]
	var action := Txt.t("specialist_install", [ROMAN[rank_next]])
	if rank_now > 0:
		action = Txt.t("specialist_raise", [ROMAN[rank_next]])
	return {
		"id": id,
		"name": protos.display_name(id),
		"special": str(protos.defs[id]["price"]) == "especial",
		"ranks": protos.ranks,
		"rank_now": rank_now,
		"text": text,
		"price": 0 if maxed else protos.price(id, rank_next),
		"reason": reason,
		"action": action,
	}


## Los prototipos montados en una pieza ({id: rango}) que conoce la
## biblioteca, en su orden; vacio si no lleva.
static func _installed(
	profile: PlayerProfile, protos: PrototypeLibrary, item: ItemDef
) -> Dictionary:
	if item == null:
		return {}
	var now := PrototypeLibrary.installed(profile, item.progress_id())
	var out := {}
	for id in protos.order:
		if now.has(id):
			out[id] = int(now[id])
	return out


## Los prototipos de una pieza en una linea: "Sifon vital V · Captador II".
static func _summary(protos: PrototypeLibrary, mounted: Dictionary) -> String:
	var parts: Array[String] = []
	for id: String in mounted:
		parts.append("%s %s" % [protos.display_name(id), ROMAN[int(mounted[id])]])
	return " · ".join(parts)


## Lo que vale un prototipo en un rango, corto ("6 %" o "1").
static func short_value(protos: PrototypeLibrary, id: String, rank: int) -> String:
	var value := protos.value(id, rank)
	if protos.effect(id) == "overheat_relief":
		return str(roundi(value))
	return "%d %%" % roundi(value * 100.0)


## Lo que hace un prototipo en un rango, en una frase.
static func effect_text(protos: PrototypeLibrary, id: String, rank: int) -> String:
	var value := protos.value(id, rank)
	var effect := protos.effect(id)
	if effect == "overheat_relief":
		return Txt.t("proto_fx_" + effect, [roundi(value)])
	return Txt.t("proto_fx_" + effect, [roundi(value * 100.0)])
