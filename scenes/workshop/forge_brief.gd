class_name ForgeBrief
extends RefCounted
## La forja de las armas de arena en el tablero del taller (OBS-051, PLAN A5).
## Del usuario: "ganar el combate 10, 15 y 20 de una racha da una al azar, y
## el resto se forja en el arbol". Las armas de arena que caben en el hueco y
## aun no tiene cuelgan entre las de la tienda con su precio de forja: con la
## rama Forja abierta se forjan en su rango (bronce, plata u oro); sin ella
## se ven cerradas, con de donde salen. Solo arma los datos: el tablero
## (PartsRack) las dibuja con "forge" y el taller las paga con ArenaGear.


## Entradas del tablero (las de WorkshopBrief.rack, con "forge": true).
static func entries(
	brief: WorkshopBrief, profile: PlayerProfile, slot: String
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if brief.gear == null:
		return out
	var effects := brief.tree_effects(profile)
	var rank := maxi(brief.gear.forge_rank(effects), 1)
	for id in ArenaGear.pool(brief.catalog):
		var def := brief.catalog.get_item(id)
		if id in profile.owned or not Garage.fits(def, slot):
			continue
		if brief.styles.why_cant_mount(profile.style, def) != "":
			continue
		var plain := ItemScaling.resolve(def, brief.rules, def.tier_min, 0)
		var item := brief.gear.apply(plain, rank, effects)
		var top: int = brief.rules.tier_max_level[def.tier_min]
		var named := Txt.t("arena_rank_name_%d" % rank)
		(
			out
			. append(
				{
					"id": id,
					"item": item,
					"group": WorkshopBrief.group_of(item),
					"owned": false,
					"mounted": false,
					"detail": Txt.t("part_level", [named, 0, top]),
					"stats": WorkshopBrief.item_stats(item, false),
					"price": brief.gear.forge_price(rank, effects),
					"reason": brief.gear.why_cant_forge(profile, brief.catalog, id, effects),
					"note": "",
					"forge": true,
				}
			)
		)
	return out
