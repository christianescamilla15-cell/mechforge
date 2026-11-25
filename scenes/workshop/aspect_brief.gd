class_name AspectBrief
extends RefCounted
## Lo que ensena la etiqueta de los aspectos de una pieza (TeardownTag, kind
## "aspects", OBS-051): una fila por aspecto con sus diez niveles, lo que da
## ya, lo que daria el siguiente y su precio en celdas. Se usa junto a la
## pieza del robot desarmado, que cambia en el momento con cada nivel.


static func state(aspects: PieceAspects, profile: PlayerProfile, item: ItemDef) -> Dictionary:
	var levels := PieceAspects.levels_of(profile, item)
	var rows: Array[Dictionary] = []
	for aspect in aspects.for_item(item):
		var id := str(aspect["id"])
		var level := int(levels.get(id, 0))
		var reason := aspects.why_cant_raise(profile, item, id)
		var at_max := level >= aspects.max_level
		var shown := level if level > 0 else 1
		var text := effect_text(aspect, shown)
		if level == 0:
			text = Txt.t("aspect_next", [text])
		(
			rows
			. append(
				{
					"id": id,
					"name": PieceAspects.name_on(aspect, item),
					"level": level,
					"max": aspects.max_level,
					"text": text,
					"cost": "" if at_max else HangarProps.thousands(aspects.cost(level)),
					"can": reason == "",
					"full": at_max,
				}
			)
		)
	return {
		"kind": "aspects",
		"title": item.display_name,
		"info": Txt.t("aspect_info", [HangarProps.thousands(profile.gold)]),
		"rows": rows,
		"back": Txt.t("aspect_back"),
	}


## La tecla de la etiqueta de la pieza que abre sus aspectos ("" si no
## tiene): con cuantos niveles lleva ya.
static func key_label(aspects: PieceAspects, profile: PlayerProfile, item: ItemDef) -> String:
	if item == null or aspects.for_item(item).is_empty():
		return ""
	var total := 0
	for level: Variant in PieceAspects.levels_of(profile, item).values():
		total += int(level)
	var top := aspects.max_level * aspects.for_item(item).size()
	return Txt.t("aspect_key", [total, top])


## Lo que da un aspecto en ese nivel, en palabras ("+12 % de dano").
static func effect_text(aspect: Dictionary, level: int) -> String:
	var amount := PieceAspects.amount_at(aspect, level)
	var shown := str(roundi(amount))
	if (aspect["add"] as Dictionary).is_empty():
		shown = "%d %%" % roundi(amount * 100.0)
	return Txt.t("aspect_fx_" + str(aspect["id"]), [shown])
