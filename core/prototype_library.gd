class_name PrototypeLibrary
extends RefCounted
## Los prototipos del especialista (GDD 8.6, OBS-043, del usuario: "que cada
## ataque te de vida, que te regenere energia, te quite calor... varias
## combinaciones... cada rango te va dando mas nivel... se desbloquea en el
## nivel 10 nada mas... desde los 1 000 y hasta los 100 000").
##
## Las armas (brazo, hombro, pecho), el torso y las piernas llevan prototipos:
## todos los que les quepan a la vez, cada uno con su rango (I a V), que sube
## su efecto y se paga sobre el anterior. Comprar uno no quita los demas (el
## usuario, 2026-11-21: "cuando subo al maximo nivel y mejoro la siguiente,
## el primero se reinicia"). Van con la pieza (PlayerProfile.prototypes, por
## la clave de progreso de la pieza: dos brazos con la misma arma comparten).
##
## Lee data/prototypes.json:
## {"schema_version", "unlock_level", "ranks", "prices": {escala: [precio por
##  rango]}, "prototypes": [{"id", "name", "piece" ("weapon", "torso" o
##  "legs"), "effect", "price" (escala), "values": [efecto por rango]}]}.

const SCHEMA_VERSION := 1
const PIECES: Array[String] = ["weapon", "torso", "legs"]
## Lo que sabe hacer el motor con un prototipo:
## - por golpe de esa arma: "lifesteal" (vida, parte del dano hecho),
##   "energy_on_hit" (energia, parte de la maxima), "cool_on_hit" (calor que
##   se quita, parte del maximo), "crit" (probabilidad de critico) y "damage"
##   (dano de mas, fraccion);
## - en el robot: "cooling" y "regen" (fraccion de mas), "health" (fraccion
##   de mas de la vida) y "overheat_relief" (veces que se sobrecalienta sin
##   perder nada, por combate).
const EFFECTS: Array[String] = [
	"lifesteal",
	"energy_on_hit",
	"cool_on_hit",
	"crit",
	"damage",
	"cooling",
	"regen",
	"health",
	"overheat_relief",
]

var unlock_level: int = 10
var ranks: int = 5
var prices: Dictionary = {}
var defs: Dictionary = {}
var order: Array[String] = []
var errors: Array[String] = []


static func load_file(path: String) -> PrototypeLibrary:
	var library := PrototypeLibrary.new()
	if not FileAccess.file_exists(path):
		library.errors.append("no existe el archivo %s" % path)
		return library
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		library.errors.append("%s no es un objeto JSON valido" % path)
		return library
	library._parse(parsed)
	return library


func _parse(data: Dictionary) -> void:
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("schema_version distinto de %d" % SCHEMA_VERSION)
	unlock_level = int(data.get("unlock_level", 10))
	ranks = int(data.get("ranks", 5))
	var raw_prices: Variant = data.get("prices", {})
	if raw_prices is Dictionary:
		for scale: String in raw_prices:
			var list: Variant = raw_prices[scale]
			if not list is Array or (list as Array).size() != ranks:
				errors.append("la escala de precios '%s' no tiene %d rangos" % [scale, ranks])
				continue
			prices[scale] = list
	for raw: Variant in data.get("prototypes", []):
		if not raw is Dictionary:
			errors.append("hay un prototipo que no es un objeto")
			continue
		var id := str(raw.get("id", ""))
		var problem := _problem(raw)
		if problem != "":
			errors.append("%s: %s" % [id, problem])
			continue
		defs[id] = raw
		order.append(id)


func _problem(raw: Dictionary) -> String:
	if str(raw.get("id", "")) == "" or defs.has(str(raw.get("id", ""))):
		return "falta el id o esta repetido"
	if not str(raw.get("piece", "")) in PIECES:
		return "pieza desconocida"
	if not str(raw.get("effect", "")) in EFFECTS:
		return "efecto desconocido"
	if not prices.has(str(raw.get("price", ""))):
		return "escala de precios desconocida"
	var values: Variant = raw.get("values", [])
	if not values is Array or (values as Array).size() != ranks:
		return "no tiene un valor por rango"
	return ""


## A que tipo de hueco de prototipo pertenece un hueco del robot ("weapon",
## "torso", "legs"); "" si no lleva prototipo.
static func piece_of(slot: String) -> String:
	if slot.begins_with("side") or slot.begins_with("top") or slot == "chest":
		return "weapon"
	if slot in ["torso", "legs"]:
		return slot
	return ""


## Los prototipos que le caben a un hueco, en el orden del catalogo.
func ids_for(slot: String) -> Array[String]:
	var out: Array[String] = []
	var piece := piece_of(slot)
	for id in order:
		if str(defs[id]["piece"]) == piece:
			out.append(id)
	return out


func display_name(id: String) -> String:
	return str(defs[id]["name"]) if defs.has(id) else ""


func effect(id: String) -> String:
	return str(defs[id]["effect"]) if defs.has(id) else ""


## El efecto de un prototipo en un rango (1 a `ranks`).
func value(id: String, rank: int) -> float:
	if not defs.has(id) or rank < 1:
		return 0.0
	var values: Array = defs[id]["values"]
	return float(values[mini(rank, ranks) - 1])


## Lo que cuesta llegar a ese rango (desde el anterior).
func price(id: String, rank: int) -> int:
	if not defs.has(id) or rank < 1 or rank > ranks:
		return 0
	return int(prices[str(defs[id]["price"])][rank - 1])


## Los prototipos de una pieza: {id: rango}; vacio si no lleva.
static func installed(profile: PlayerProfile, part_key: String) -> Dictionary:
	var entry: Variant = profile.prototypes.get(part_key, {})
	return (entry as Dictionary).duplicate() if entry is Dictionary else {}


## El rango al que se llevaria ese prototipo en esa pieza: el siguiente al
## que tiene (el I si no lo tiene).
static func next_rank(profile: PlayerProfile, part_key: String, id: String) -> int:
	return int(installed(profile, part_key).get(id, 0)) + 1


## Devuelve "" si se puede comprar ese prototipo (o su rango siguiente) para la
## pieza de ese hueco; si no, el motivo. `level`: el nivel del jugador.
func why_cant_buy(
	profile: PlayerProfile, catalog: Catalog, level: int, slot: String, id: String
) -> String:
	if level < unlock_level:
		return Txt.t("proto_locked", [unlock_level])
	var def := catalog.get_item(Garage.get_slot(profile.build, slot))
	if def == null:
		return Txt.t("proto_no_piece")
	if not id in ids_for(slot):
		return Txt.t("proto_wrong_piece")
	var rank := next_rank(profile, def.progress_id(), id)
	if rank > ranks:
		return Txt.t("proto_max_rank")
	if profile.gold < price(id, rank):
		return Txt.t("proto_no_cells")
	return ""


## Lo compra (o sube su rango) y lo monta en la pieza de ese hueco. Devuelve
## "" si se hizo; si no, el motivo.
func buy(profile: PlayerProfile, catalog: Catalog, level: int, slot: String, id: String) -> String:
	var why := why_cant_buy(profile, catalog, level, slot, id)
	if why != "":
		return why
	var key := catalog.get_item(Garage.get_slot(profile.build, slot)).progress_id()
	var rank := next_rank(profile, key, id)
	profile.gold -= price(id, rank)
	var mounted := installed(profile, key)
	mounted[id] = rank
	profile.prototypes[key] = mounted
	return ""


## Pone en las piezas de un robot armado lo que hacen sus prototipos
## (ItemDef.protos y proto_effects), para el combate y la ficha.
func apply(build: MechBuild, profile: PlayerProfile) -> void:
	if build == null:
		return
	for item in build.all_items():
		if item == null:
			continue
		var mounted := installed(profile, item.progress_id())
		var ranks_of := {}
		var effects := {}
		for id: String in mounted:
			if not defs.has(id):
				continue
			var rank := int(mounted[id])
			ranks_of[id] = rank
			effects[effect(id)] = float(effects.get(effect(id), 0.0)) + value(id, rank)
		item.protos = ranks_of
		item.proto_effects = effects
