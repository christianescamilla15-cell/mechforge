class_name Campaign
extends RefCounted
## Campana (GDD 9): un mundo dividido en zonas. Cada zona son sus combates
## normales, en orden, y un jefe al final. El jugador avanza combate a
## combate; la arena, aparte, sirve para juntar celdas sin avanzar.
## Datos en data/campaign.json:
## {"schema_version", "world_bosses", "on_boss_loss", "zones": [{"id", "name",
##   "tier", "player_level", "arena": {"level", "difficulty"},
##   "fights": [{"enemy", "level", "difficulty"}], "boss": {...}}]}

## Que pasa al perder contra un jefe: "new_game" termina la partida y se
## empieza de cero; "retry" deja volver a intentarlo.
const BOSS_LOSS_RULES: Array[String] = ["new_game", "retry"]
const DIFFICULTIES: Array[String] = ["EASY", "NORMAL", "HARD"]

var zones: Array[Dictionary] = []
## Jefes que tendra el mundo entero; las zonas hechas pueden ser menos.
var world_bosses: int = 0
var on_boss_loss: String = "new_game"
var errors: Array[String] = []


static func load_file(path: String, library: BuildLibrary) -> Campaign:
	var campaign := Campaign.new()
	if not FileAccess.file_exists(path):
		campaign.errors.append("no existe el archivo %s" % path)
		return campaign
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("zones") is Array:
		campaign.errors.append("%s no tiene una lista 'zones'" % path)
		return campaign
	campaign.on_boss_loss = str(parsed.get("on_boss_loss", "new_game"))
	if not campaign.on_boss_loss in BOSS_LOSS_RULES:
		campaign.errors.append("'on_boss_loss' debe ser uno de %s" % [BOSS_LOSS_RULES])
	for raw: Variant in parsed["zones"]:
		campaign._add_zone(raw, library)
	campaign.world_bosses = maxi(int(parsed.get("world_bosses", 0)), campaign.zones.size())
	return campaign


func zone_count() -> int:
	return zones.size()


func zone_name(zone: int) -> String:
	return str(zones[zone].get("name", zones[zone]["id"]))


func tier_of(zone: int) -> ItemDef.Tier:
	return ItemDef.Tier[zones[zone]["tier"]]


## Nivel de las piezas del jugador en esa zona, mientras no exista la mejora
## pieza a pieza.
func player_level(zone: int) -> int:
	return int(zones[zone]["player_level"])


## Combates normales de la zona, sin contar al jefe.
func fights_in(zone: int) -> int:
	return (zones[zone]["fights"] as Array).size()


func is_boss_fight(zone: int, fight: int) -> bool:
	return fight >= fights_in(zone)


## El combate numero `fight` de la zona; pasados los normales, el del jefe.
## Devuelve {"enemy", "level", "difficulty"}.
func fight_at(zone: int, fight: int) -> Dictionary:
	if is_boss_fight(zone, fight):
		return zones[zone]["boss"]
	return zones[zone]["fights"][fight]


## Rival de un combate de arena en esa zona: sale al azar de la semilla entre
## los mechs normales. Devuelve {"enemy", "level", "difficulty"}.
func arena_fight(zone: int, library: BuildLibrary, seed_value: int) -> Dictionary:
	var arena: Dictionary = zones[zone]["arena"]
	var ids := library.ids()
	return {
		"enemy": ids[absi(seed_value) % ids.size()],
		"level": int(arena["level"]),
		"difficulty": str(arena["difficulty"]),
	}


## Apunta el resultado de un combate en el perfil del jugador: cobra, avanza
## la campana o, si perdio contra un jefe, termina la partida.
## `mode` es "arena" o "campaign". Devuelve {"gold", "game_over",
## "zone_cleared", "boss"}.
func finish_fight(profile: PlayerProfile, shop: ArenaShop, mode: String, won: bool) -> Dictionary:
	var out := {"gold": 0, "game_over": false, "zone_cleared": false, "boss": false}
	if mode != "campaign" or profile.zone >= zone_count():
		out["gold"] = profile.earn(shop, "arena_win" if won else "arena_loss")
		return out
	var boss := is_boss_fight(profile.zone, profile.fight)
	out["boss"] = boss
	if not boss:
		out["gold"] = profile.earn(shop, "campaign_win" if won else "campaign_loss")
		if won:
			profile.fight += 1
	elif won:
		out["gold"] = profile.earn(shop, "boss_win")
		profile.zone += 1
		profile.fight = 0
		out["zone_cleared"] = true
	elif on_boss_loss == "new_game":
		profile.end_run()
		out["game_over"] = true
	else:
		out["gold"] = profile.earn(shop, "boss_loss")
	return out


func _add_zone(raw: Variant, library: BuildLibrary) -> void:
	if not raw is Dictionary or str(raw.get("id", "")) == "":
		errors.append("hay una zona sin 'id'")
		return
	var id := str(raw["id"])
	if not ItemDef.Tier.has(str(raw.get("tier", ""))):
		errors.append("%s: 'tier' no es una clase valida" % id)
		return
	if not raw.get("fights") is Array or (raw["fights"] as Array).is_empty():
		errors.append("%s: no tiene combates" % id)
		return
	if not raw.get("boss") is Dictionary or not raw.get("arena") is Dictionary:
		errors.append("%s: le falta el jefe o la arena" % id)
		return
	var fights: Array = (raw["fights"] as Array) + [raw["boss"]]
	for index in fights.size():
		var problem := _fight_problem(fights[index], library)
		if problem != "":
			errors.append("%s, combate %d: %s" % [id, index + 1, problem])
			return
	if not library.is_boss(str(raw["boss"]["enemy"])):
		errors.append("%s: el jefe no esta marcado como jefe en los mechs" % id)
		return
	if not str(raw["arena"].get("difficulty", "")) in DIFFICULTIES:
		errors.append("%s: la dificultad de la arena no es valida" % id)
		return
	zones.append(raw)


func _fight_problem(raw: Variant, library: BuildLibrary) -> String:
	if not raw is Dictionary:
		return "no es un diccionario"
	if not library.specs.has(str(raw.get("enemy", ""))):
		return "no existe el mech '%s'" % raw.get("enemy", "")
	if not str(raw.get("difficulty", "")) in DIFFICULTIES:
		return "la dificultad no es valida"
	if int(raw.get("level", -1)) < 0:
		return "falta el nivel"
	return ""
