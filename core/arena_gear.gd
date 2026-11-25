class_name ArenaGear
extends RefCounted
## Las armas de arena (OBS-051, PLAN A5; data/arena_gear.json). Del
## usuario: "ganar el combate 10, 15 y 20 de una racha da una al azar, y el
## resto se forja en el arbol". Son las del catalogo con la etiqueta "arena"
## (ItemDef.TAG_ARENA), de clase Unica, y cada una tiene un rango (bronce,
## plata u oro) que le suma dano. El jugador las guarda en
## PlayerProfile.arena_gear ({id: rango}); el rango se puede subir ganando
## otro hito o forjandola de nuevo. Determinista: el azar llega con el rng.

const DATA_VERSION := 1

## Combate de la racha (1 es el primero) que da un arma -> su rango.
var milestones: Dictionary = {}
var ranks: Array[Dictionary] = []
var scale: Array[String] = []
var forge_prices: Array[int] = []
var melt: float = 0.0
## Lo que pegan sobre el laser de su forma (el x1.3 del catalogo) y la parte
## de lo que el jugador lleva de mas que pasa al rival de la racha (A6).
var boost: float = 1.0
var rival_share: float = 0.0
var errors: Array[String] = []


static func load_file(path: String) -> ArenaGear:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var missing := ArenaGear.new()
		missing.errors.append("no se pudo abrir %s" % path)
		return missing
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		var broken := ArenaGear.new()
		broken.errors.append("%s no es un objeto JSON" % path)
		return broken
	return from_dict(parsed)


static func from_dict(data: Dictionary) -> ArenaGear:
	var gear := ArenaGear.new()
	if int(data.get("schema_version", 0)) != DATA_VERSION:
		gear.errors.append("version de datos desconocida")
	var marks: Dictionary = data.get("milestones", {})
	for key: String in marks:
		gear.milestones[int(key)] = int(marks[key])
	for rank: Dictionary in data.get("ranks", []):
		gear.ranks.append({"id": str(rank["id"]), "damage": float(rank["damage"])})
	for key: String in data.get("scale", []):
		gear.scale.append(key)
	for price: Variant in data.get("forge_price", []):
		gear.forge_prices.append(int(price))
	gear.melt = float(data.get("melt", 0.0))
	gear.boost = float(data.get("boost", 1.0))
	gear.rival_share = float(data.get("rival_share", 0.0))
	if gear.forge_prices.size() != gear.ranks.size():
		gear.errors.append("un precio de forja por rango")
	for rank: int in gear.milestones.values():
		if rank < 1 or rank > gear.ranks.size():
			gear.errors.append("hito con un rango que no existe")
	return gear


func max_rank() -> int:
	return ranks.size()


## Las armas de arena del catalogo, ordenadas por id.
static func pool(catalog: Catalog) -> Array[String]:
	var out: Array[String] = []
	for def: ItemDef in catalog.items.values():
		if def.has_tag(ItemDef.TAG_ARENA):
			out.append(def.id)
	out.sort()
	return out


## El rango que da ganar ese combate de la racha (1 es el primero); 0 si no
## es un hito.
func rank_for_win(won: int) -> int:
	return int(milestones.get(won, 0))


static func rank_of(profile: PlayerProfile, id: String) -> int:
	return int(profile.arena_gear.get(id, 0))


## El premio de un hito, tras apuntar el combate (Campaign.finish_fight, que
## da `result`): un arma de arena al azar del rango del hito (uno mas con
## Buena estrella), otra con la probabilidad de Fortuna y, con la de Doble
## premio, otra vez las celdas de ese combate. Las armas no se arriesgan:
## son suyas aunque pierda despues. `effects`: los del arbol del jugador.
## Devuelve {"weapons": [{"id", "rank", "new"}], "double": celdas, "melted":
## celdas}; vacio si no fue un hito ganado.
func reward(
	profile: PlayerProfile,
	catalog: Catalog,
	result: Dictionary,
	effects: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	if int(result.get("prize", 0)) <= 0:
		return {}
	var base := rank_for_win(int(result.get("step", -1)) + 1)
	if base == 0:
		return {}
	var out := {"weapons": [], "double": 0, "melted": 0}
	var rank := mini(base + int(effects.get("fortune_quality", 0)), max_rank())
	var draws := 2 if rng.randf() < float(effects.get("fortune", 0.0)) else 1
	for i in draws:
		var got := _grant_random(profile, catalog, rank, rng)
		if got.is_empty():
			var cells := roundi(forge_prices[rank - 1] * melt)
			profile.gold += cells
			out["melted"] += cells
		else:
			out["weapons"].append(got)
	if rng.randf() < float(effects.get("fortune_double", 0.0)):
		var extra := int(result["prize"])
		out["double"] = extra
		if bool(result.get("more", false)):
			profile.arena_pot += extra
			result["pot"] = profile.arena_pot
		else:
			profile.gold += extra
			result["gold"] = int(result.get("gold", 0)) + extra
	return out


## El rango que forja la rama Forja (0 si no esta abierta).
func forge_rank(effects: Dictionary) -> int:
	return mini(int(effects.get("forge", 0)), max_rank())


## Lo que cuesta forjar un arma de ese rango (con el descuento de Aleacion).
func forge_price(rank: int, effects: Dictionary) -> int:
	if rank < 1 or rank > forge_prices.size():
		return 0
	var discount := clampf(float(effects.get("forge_discount", 0.0)), 0.0, 1.0)
	return roundi(forge_prices[rank - 1] * (1.0 - discount))


func why_cant_forge(
	profile: PlayerProfile, catalog: Catalog, id: String, effects: Dictionary
) -> String:
	var def := catalog.get_item(id)
	if def == null or not def.has_tag(ItemDef.TAG_ARENA):
		return "no es un arma de arena"
	var rank := forge_rank(effects)
	if rank == 0:
		return "abre la rama Forja"
	if rank_of(profile, id) >= rank:
		return "ya la tienes"
	if forge_price(rank, effects) > profile.gold:
		return "faltan celdas"
	return ""


## Forja esa arma en el rango que abre la rama (o sube la que ya tiene a
## ese rango). Devuelve "" o el motivo.
func forge(profile: PlayerProfile, catalog: Catalog, id: String, effects: Dictionary) -> String:
	var reason := why_cant_forge(profile, catalog, id, effects)
	if reason != "":
		return reason
	var rank := forge_rank(effects)
	profile.gold -= forge_price(rank, effects)
	_grant(profile, catalog, id, rank)
	return ""


## Cuanto suma al dano un arma de ese rango (con Temple y Forja maestra).
func damage_bonus(rank: int, effects: Dictionary) -> float:
	if rank < 1 or rank > ranks.size():
		return 0.0
	return float(ranks[rank - 1]["damage"]) + float(effects.get("forge_quality", 0.0))


## Una copia del arma con su rango (si no tiene, ella misma).
func apply(def: ItemDef, rank: int, effects: Dictionary) -> ItemDef:
	if def == null or rank <= 0:
		return def
	var out: ItemDef = def.duplicate()
	var grow := 1.0 + damage_bonus(rank, effects)
	for key in scale:
		var value: int = def.get(key)
		if value > 0:
			out.set(key, roundi(value * grow))
	out.arena_rank = rank
	return out


## Las armas de arena del robot del jugador, con su rango.
func apply_build(build: MechBuild, profile: PlayerProfile, effects: Dictionary) -> void:
	if profile.arena_gear.is_empty():
		return
	var shape := func(def: ItemDef) -> ItemDef:
		return apply(def, rank_of(profile, def.id), effects) if def != null else null
	build.chest = shape.call(build.chest)
	for key: String in ["sides", "tops"]:
		var list: Array[ItemDef] = []
		for def: ItemDef in build.get(key):
			list.append(shape.call(def))
		build.set(key, list)


func _grant_random(
	profile: PlayerProfile, catalog: Catalog, rank: int, rng: RandomNumberGenerator
) -> Dictionary:
	var open: Array[String] = []
	for id in pool(catalog):
		if rank_of(profile, id) < rank:
			open.append(id)
	if open.is_empty():
		return {}
	return _grant(profile, catalog, open[rng.randi_range(0, open.size() - 1)], rank)


static func _grant(profile: PlayerProfile, catalog: Catalog, id: String, rank: int) -> Dictionary:
	var fresh := not id in profile.owned
	if fresh:
		profile.owned.append(id)
		profile.parts[id] = {"tier": catalog.get_item(id).tier_min, "level": 0}
	profile.arena_gear[id] = maxi(rank, rank_of(profile, id))
	return {"id": id, "rank": rank, "new": fresh}


## Para las pruebas y el simulador (--arena): cada arma de brazo y de hombro
## del equipo `build`, por la de arena de su hueco y su elemento (la de su
## forma si la hay), nueva (nivel 0) y de ese rango.
static func dress(catalog: Catalog, profile: PlayerProfile, build: Dictionary, rank: int) -> void:
	for slot: String in ["side0", "side1", "top0"]:
		var def := catalog.get_item(Garage.get_slot(build, slot))
		if def == null:
			continue
		var best := ""
		for id in pool(catalog):
			var arena := catalog.get_item(id)
			if not Garage.fits(arena, slot) or arena.element != def.element:
				continue
			if best == "" or arena.form == def.form:
				best = id
		if best == "":
			continue
		if not best in profile.owned:
			profile.owned.append(best)
		profile.parts[best] = {"tier": ItemDef.Tier.DIVINE, "level": 0}
		profile.arena_gear[best] = rank
		Garage.set_slot(build, slot, best)
