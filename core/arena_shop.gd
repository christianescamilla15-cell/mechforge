class_name ArenaShop
extends RefCounted
## Tienda de arena (GDD 8): mejoras permanentes que se compran con el oro que
## dan los combates. Sigue la estructura del original: cada mejora tiene 10
## niveles pequenos (docs/reference/original-mechanics.md).
## Datos en data/arena_shop.json: {"steps", "tracks", "prices", "rewards"}.

## Tabla de pasos: lo que da cada nivel, sobre 20. Es la del original.
var steps: Array[int] = []
## Mejoras a la venta, por id: {"name", "kind" ("percent" o "flat"), "max"}.
var tracks: Dictionary[String, Dictionary] = {}
## Oro que cuesta llegar a cada nivel desde el anterior.
var prices: Array[int] = []
## Oro que da cada resultado: "win", "loss" y "boss_win".
var rewards: Dictionary = {}
var errors: Array[String] = []


static func load_file(path: String) -> ArenaShop:
	var shop := ArenaShop.new()
	if not FileAccess.file_exists(path):
		shop.errors.append("no existe el archivo %s" % path)
		return shop
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		shop.errors.append("%s no es un diccionario" % path)
		return shop
	for value: Variant in parsed.get("steps", []):
		shop.steps.append(int(value))
	for value: Variant in parsed.get("prices", []):
		shop.prices.append(int(value))
	for raw: Variant in parsed.get("tracks", []):
		if not raw is Dictionary or str(raw.get("id", "")) == "":
			shop.errors.append("hay una mejora sin 'id'")
			continue
		if not str(raw.get("kind", "")) in ["percent", "flat"]:
			shop.errors.append("%s: 'kind' debe ser percent o flat" % raw["id"])
			continue
		shop.tracks[str(raw["id"])] = raw
	if parsed.get("rewards") is Dictionary:
		shop.rewards = parsed["rewards"]
	if shop.steps.size() < 2 or shop.steps[0] != 0:
		shop.errors.append("'steps' debe empezar en 0 y tener al menos dos niveles")
	if shop.prices.size() != shop.steps.size():
		shop.errors.append("'prices' debe tener un precio por nivel")
	return shop


func track_ids() -> Array[String]:
	return tracks.keys()


func max_level() -> int:
	return steps.size() - 1


func display_name(track: String) -> String:
	return str(tracks[track].get("name", track))


## Lo que da una mejora a ese nivel: una fraccion (0.2 = +20 %) si es de
## porcentaje, o puntos si es plana.
func value(track: String, level: int) -> float:
	var clamped := clampi(level, 0, max_level())
	var share := float(steps[clamped]) / float(steps[max_level()])
	var top := float(tracks[track]["max"])
	return share * top / 100.0 if tracks[track]["kind"] == "percent" else share * top


## Oro que cuesta subir una mejora a ese nivel desde el anterior.
func price(level: int) -> int:
	return prices[clampi(level, 0, max_level())]


## Oro total para llevar todas las mejoras del nivel 0 a ese nivel.
func total_cost(level: int) -> int:
	var per_track := 0
	for step in range(1, clampi(level, 0, max_level()) + 1):
		per_track += prices[step]
	return per_track * tracks.size()


func reward(kind: String) -> int:
	return int(rewards.get(kind, 0))


## Convierte los niveles comprados ({id: nivel}) en lo que suman en combate.
func upgrades_for(levels: Dictionary) -> ArenaUpgrades:
	var out := ArenaUpgrades.new()
	for track: String in tracks:
		var amount := value(track, int(levels.get(track, 0)))
		if track == "health":
			out.health = roundi(amount)
		elif track in out:
			out.set(track, amount)
	return out
