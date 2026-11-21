class_name ArenaShop
extends RefCounted
## Armeria (GDD 8): mejoras permanentes que se compran con las celdas que
## dan los combates. Sigue la estructura del original: cada mejora tiene 10
## niveles pequenos (docs/reference/original-mechanics.md).
## Datos en data/arena_shop.json: {"steps", "tracks", "prices", "rewards"}.

## Tabla de pasos: lo que da cada nivel, sobre 20. Es la del original.
var steps: Array[int] = []
## Mejoras a la venta, por id: {"name", "kind" ("percent" o "flat"), "max"}
## y, si es plana, "unit" (en que se mide: "kg"). "gain" es el texto con el
## que la pantalla de mejoras cuenta lo que da el nivel siguiente, si no es el
## de todas.
## Con "assist_tier", la mejora se abre cuando el robot de asistencia llega a
## esa clase (antes no sirve) y no cuenta para el ritmo de la primera zona.
## Con "player_level", se abre cuando el jugador llega a ese nivel (el nucleo
## ampliado, que carga el arma de pecho) y tampoco cuenta para ese ritmo.
var tracks: Dictionary[String, Dictionary] = {}
## Oro que cuesta llegar a cada nivel desde el anterior.
var prices: Array[int] = []
## Celdas que da cada resultado: "arena_win", "arena_loss", "campaign_win",
## "campaign_loss", "boss_win" y "boss_loss".
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


## Clase del robot de asistencia que pide una mejora; -1 si no pide nada.
func assist_tier(track: String) -> int:
	return int(tracks[track].get("assist_tier", -1))


## En que se mide una mejora plana ("kg"); "" si no lo dice.
func unit(track: String) -> String:
	return str(tracks[track].get("unit", ""))


## Clave del texto que cuenta lo que da el nivel siguiente de una mejora.
func gain_key(track: String) -> String:
	return str(tracks[track].get("gain", "console_upgrade_gain"))


## Nivel del jugador que pide una mejora; 0 si no pide ninguno.
func player_level(track: String) -> int:
	return int(tracks[track].get("player_level", 0))


## Oro total para llevar del nivel 0 a ese nivel las mejoras que estan
## abiertas desde el principio (las que no piden nada).
func total_cost(level: int) -> int:
	var per_track := 0
	for step in range(1, clampi(level, 0, max_level()) + 1):
		per_track += prices[step]
	var open := 0
	for track in tracks:
		if assist_tier(track) < 0 and player_level(track) <= 0:
			open += 1
	return per_track * open


func reward(kind: String) -> int:
	return int(rewards.get(kind, 0))


## Convierte los niveles comprados ({id: nivel}) en lo que suman en combate.
func upgrades_for(levels: Dictionary) -> ArenaUpgrades:
	var out := ArenaUpgrades.new()
	for track: String in tracks:
		if track in out:
			out.set(track, value(track, int(levels.get(track, 0))))
	return out
