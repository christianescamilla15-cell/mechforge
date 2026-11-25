class_name Campaign
extends RefCounted
## Campana (GDD 9): un mundo dividido en zonas, que son ligas. Cada liga son
## sus combates normales, en orden, y su campeon (el jefe) al final.
##
## Reglas de liga (decision del usuario, 2026-11-20, docs/OBSERVACIONES.md
## OBS-020): antes de empezar la campana de una liga, la arena y el combate
## libre estan abiertos (la arena sirve para juntar celdas). Al empezar su
## primer combate, se cierran hasta terminarla. Perder un combate de la
## campana acaba la partida entera y se vuelve al principio, salvo que el
## jugador lleve una proteccion:
## - "rematch" (la revancha, la cara): vuelve al rival anterior al que le
##   vencio, es decir, contra el campeon, al penultimo; sigue en campana;
## - "league" (el seguro de liga): vuelve al comienzo de esa liga, con la
##   campana sin empezar.
## Se gasta la mejor que lleve.
##
## Datos en data/campaign.json:
## {"schema_version", "world_bosses", "on_loss", "protections": {"league":
##   precio, "rematch": precio}, "arena_streak": {"fights", "prize",
##   "steps"}, "zones": [{"id", "name",
##   "tier", "level_cap", "reward_mult", "stage", "drops_unique",
##   "arena": {"difficulty"},
##   "fights": [{"enemy", "level", "difficulty"}], "boss": {...}}]}
## "enemy_armory" es el nivel de la armeria del Orden en esa zona: todas las
## mejoras de sus rivales (jefe incluido) estan a ese nivel.
## "armory_cap" es el nivel mas alto al que el jugador puede subir las mejoras
## de su armeria mientras este en esa zona (sin el, el maximo): lo que se
## abre al vencer jefes no se compra por adelantado.
## "boss": {"skills"} son los puntos de habilidad del jefe: los jefes del
## Orden entrenan y los reparten por igual entre las ramas del arbol.
## "kits" en un combate son las habilidades que lleva ese rival (campos de
## KITS, de SkillSet): un escudo, un kit de reparacion. Decision tras medir
## OBS-014 (2026-11-21): sin ellas, un rival normal gastaba del 80 al 95 % de
## sus acciones en disparar y ninguna en otra cosa.
## "tier" es la clase de los rivales de la zona y la mas alta a la que el
## jugador puede transformar sus piezas mientras este en ella.
## "level_cap" es el nivel mas alto al que el jugador puede subir sus piezas
## de la clase de la zona mientras este en ella: el del jefe. Lo que farmee
## de mas va a las mejoras de la armeria.

## Que pasa al perder un combate de la campana: "new_game" termina la
## partida y se empieza de cero (salvo proteccion); "retry" deja volver a
## intentarlo sin perder nada.
const LOSS_RULES: Array[String] = ["new_game", "retry"]
## Protecciones, de la mejor a la peor: es el orden en que se gastan.
const PROTECTIONS: Array[String] = ["rematch", "league"]
const DIFFICULTIES: Array[String] = ["EASY", "NORMAL", "HARD"]
## Habilidades que puede llevar un rival ("kits" de su combate).
const KITS: Array[String] = ["shield_uses", "repair_uses", "repair_share"]

var zones: Array[Dictionary] = []
## Jefes que tendra el mundo entero; las zonas hechas pueden ser menos.
var world_bosses: int = 0
var on_loss: String = "new_game"
## Precio de cada proteccion en la primera liga (sube con la liga).
var protection_prices: Dictionary[String, int] = {}
## Otro combate en la arena, doble o nada (OBS-049, del usuario: "si das
## otro combate se te duplica la cantidad... el enemigo que viene es
## considerablemente mas fuerte... puedes tener un buen bonus o perder toda
## tu recompensa acumulada"): {"fights" (los de una racha), "prize" (lo
## que multiplica la paga de ganar en cada combate) y "steps" (como sale
## de mas fuerte el rival de cada uno: {"power", "tier_bonus", "skills",
## "difficulty", "edge"})}. "edge" es lo que el rival suma de vida y de dano
## (en parte) por encima de su armeria: cuando el jugador ya esta en lo mas
## alto, mas clase no lo hace mas fuerte.
var arena_streak: Dictionary = {"fights": 1, "prize": [1.0], "steps": [{}]}
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
	campaign.on_loss = str(parsed.get("on_loss", "new_game"))
	if not campaign.on_loss in LOSS_RULES:
		campaign.errors.append("'on_loss' debe ser uno de %s" % [LOSS_RULES])
	# Sin "protections" no se vende ninguna; si esta, lleva las dos.
	var prices: Variant = parsed.get("protections")
	for kind in PROTECTIONS:
		if prices == null:
			continue
		if prices is Dictionary and int(prices.get(kind, 0)) > 0:
			campaign.protection_prices[kind] = int(prices[kind])
		else:
			campaign.errors.append("falta el precio de la proteccion '%s'" % kind)
	campaign._load_streak(parsed.get("arena_streak"))
	for raw: Variant in parsed["zones"]:
		campaign._add_zone(raw, library)
	campaign.world_bosses = maxi(int(parsed.get("world_bosses", 0)), campaign.zones.size())
	return campaign


func _load_streak(raw: Variant) -> void:
	if raw == null:
		return
	if not raw is Dictionary:
		errors.append("'arena_streak' debe ser un objeto")
		return
	var fights := int(raw.get("fights", 0))
	var prize: Variant = raw.get("prize")
	var steps: Variant = raw.get("steps")
	if fights < 1 or not prize is Array or not steps is Array:
		errors.append("'arena_streak' necesita 'fights', 'prize' y 'steps'")
		return
	if (prize as Array).size() != fights or (steps as Array).size() != fights:
		errors.append("'arena_streak': un premio y un paso por combate")
		return
	for step: Variant in steps:
		var hard := str((step as Dictionary).get("difficulty", "")) if step is Dictionary else "?"
		if hard != "" and not hard in DIFFICULTIES:
			errors.append("'arena_streak': dificultad '%s' desconocida" % hard)
			return
	# La experiencia (cuanto multiplica la de ganar) y los puntos de mejora de
	# cada combate (OBS-051); sin ellos, la de siempre y ninguno.
	var xp: Variant = raw.get("xp", [])
	var points: Variant = raw.get("points", [])
	for list: Variant in [xp, points]:
		if (
			not list is Array
			or ((list as Array).size() != fights and not (list as Array).is_empty())
		):
			errors.append("'arena_streak': 'xp' y 'points' llevan un valor por combate")
			return
	arena_streak = {"fights": fights, "prize": prize, "steps": steps, "xp": xp, "points": points}


func zone_count() -> int:
	return zones.size()


func zone_name(zone: int) -> String:
	return str(zones[zone].get("name", zones[zone]["id"]))


## Tipo de arma de los rivales de la zona (BuildLibrary.band_of).
func band_of(zone: int) -> String:
	return str(zones[mini(zone, zone_count() - 1)].get("band", ""))


## Escenario de la zona (data/stages.json); "" si no dice ninguno.
func stage_of(zone: int) -> String:
	return str(zones[mini(zone, zone_count() - 1)].get("stage", ""))


## Si el jugador ya vencio a todos los jefes del mundo.
func is_complete(profile: PlayerProfile) -> bool:
	return profile.zone >= world_bosses


func tier_of(zone: int) -> ItemDef.Tier:
	return ItemDef.Tier[zones[zone]["tier"]]


## Nivel mas alto de las piezas del jugador en la clase de esa zona.
func level_cap(zone: int) -> int:
	return int(zones[mini(zone, zone_count() - 1)]["level_cap"])


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


## Las habilidades que lleva el rival de un combate ({campo de SkillSet:
## cuanto}); vacio si no lleva ninguna.
static func kits_of(fight: Dictionary) -> Dictionary:
	var kits: Variant = fight.get("kits", {})
	return kits if kits is Dictionary else {}


## El cuerpo con el que se ve el rival de un combate (un juego de dibujos de
## assets/mechs); "" si se ve por sus piezas, como siempre.
static func body_of(fight: Dictionary) -> String:
	var body: Variant = fight.get("body", "")
	return body if body is String else ""


## La escalera de la zona: el combate que toca y los que le siguen, en
## orden, con el jefe al final; como mucho `count`. Cada uno es su combate
## ({"enemy", "level", "difficulty"...}) con "fight" (su numero en la zona) y
## "boss". Vacia si la campana esta completa o la zona no esta construida.
func ladder(profile: PlayerProfile, count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if is_complete(profile) or profile.zone >= zone_count():
		return out
	var boss_at := fights_in(profile.zone)
	for index in range(profile.fight, mini(profile.fight + count, boss_at + 1)):
		var entry: Dictionary = fight_at(profile.zone, index).duplicate()
		entry["fight"] = index
		entry["boss"] = index >= boss_at
		out.append(entry)
	return out


## Puntos de habilidad del jefe de esa zona (0 = sin entrenar).
## Las armas especiales de los campeones ya vencidos: se pueden comprar
## (GDD 9.4). Cada campeon dice la suya en su "weapon".
func boss_weapons_open(profile: PlayerProfile) -> Array[String]:
	var out: Array[String] = []
	for zone in mini(profile.zone, zone_count()):
		var weapon := boss_weapon(zone)
		if weapon != "":
			out.append(weapon)
	return out


## El arma especial del campeon de una zona; "" si aun no tiene.
func boss_weapon(zone: int) -> String:
	if zone < 0 or zone >= zone_count():
		return ""
	return str((zones[zone]["boss"] as Dictionary).get("weapon", ""))


func boss_skills(zone: int) -> int:
	return int(zones[mini(zone, zone_count() - 1)]["boss"].get("skills", 0))


## Nivel mas alto de las mejoras de la armeria del jugador en esa zona.
func armory_cap(zone: int, shop: ArenaShop) -> int:
	var raw: Variant = zones[mini(zone, zone_count() - 1)].get("armory_cap")
	return shop.max_level() if raw == null else int(raw)


## Nivel de la armeria del Orden en esa zona (0 = sin mejoras).
func enemy_armory(zone: int) -> int:
	return int(zones[mini(zone, zone_count() - 1)].get("enemy_armory", 0))


## Mejoras que llevan los rivales de esa zona: la armeria del Orden, con
## todas sus lineas al nivel de la zona.
func enemy_upgrades(zone: int, shop: ArenaShop) -> ArenaUpgrades:
	var levels := {}
	for track in shop.track_ids():
		levels[track] = enemy_armory(zone)
	return shop.upgrades_for(levels)


## La armeria de un rival de esa zona con su plus de la racha de la arena
## ("edge" de arena_streak: mas vida y mas dano).
func fight_upgrades(zone: int, shop: ArenaShop, edge: float = 0.0) -> ArenaUpgrades:
	var out := enemy_upgrades(zone, shop)
	out.health += edge
	out.damage += edge
	return out


## Multiplicador de las recompensas en esa zona: las zonas de clase alta
## pagan mas porque sus mejoras cuestan mas.
func reward_mult(zone: int) -> float:
	return float(zones[mini(zone, zone_count() - 1)].get("reward_mult", 1.0))


## Rival de un combate de arena en esa zona: un mech normal al azar (de la
## semilla), con la clase y el nivel cuyo poder mas se parece al del
## jugador, sin pasar de la clase de la zona, y con el mismo equipo que el
## (`loadout`, de loadout_of: quien empieza con una sola arma pelea contra
## rivales de una sola arma). Asi la arena siempre esta a la medida. Devuelve
## {"enemy", "tier", "level", "difficulty", "loadout"}.
func arena_fight(
	zone: int,
	library: BuildLibrary,
	seed_value: int,
	rules: RulesConfig,
	power: float,
	loadout: Dictionary = {},
	tier_bonus: int = 0
) -> Dictionary:
	var ids := library.band_ids(band_of(zone))
	if ids.is_empty():
		ids = library.ids()
	var best := {"tier": 0, "level": 0}
	var best_gap := INF
	var top := mini(tier_of(zone) + tier_bonus, rules.tier_max_level.size() - 1)
	for tier in top + 1:
		for level in rules.tier_max_level[tier] + 1:
			var gap := absf(ItemScaling.power(rules, tier, level) - power)
			if gap < best_gap:
				best_gap = gap
				best = {"tier": tier, "level": level}
	var gear := loadout.duplicate()
	if not gear.is_empty():
		# El arma con la que sale tambien cambia de un rival a otro.
		gear["shift"] = absi(seed_value) / ids.size()
	return {
		"enemy": ids[absi(seed_value) % ids.size()],
		"tier": best["tier"],
		"level": best["level"],
		"difficulty": str(zones[zone]["arena"]["difficulty"]),
		"loadout": gear,
	}


## Los combates de una racha de arena (OBS-049).
func streak_fights() -> int:
	return int(arena_streak["fights"])


## Lo que multiplica la paga de ganar el combate `step` (0 es el primero).
func streak_prize(step: int) -> float:
	var prize: Array = arena_streak["prize"]
	return float(prize[clampi(step, 0, prize.size() - 1)])


## Lo que multiplica la experiencia de ganar el combate `step` de la racha.
func streak_xp(step: int) -> float:
	var xp: Array = arena_streak.get("xp", [])
	return 1.0 if xp.is_empty() else float(xp[clampi(step, 0, xp.size() - 1)])


## Los puntos de mejora que pone en el bote ganar el combate `step`.
func streak_points(step: int) -> int:
	var points: Array = arena_streak.get("points", [])
	return 0 if points.is_empty() else int(points[clampi(step, 0, points.size() - 1)])


## El rival del combate `step` de una racha: el de arena_fight con mas poder
## (y, si hace falta, una clase mas), entrenado y con otra dificultad. El
## primero es el de siempre.
func arena_streak_fight(
	zone: int,
	library: BuildLibrary,
	seed_value: int,
	rules: RulesConfig,
	power: float,
	loadout: Dictionary,
	step: int
) -> Dictionary:
	var steps: Array = arena_streak["steps"]
	var boost: Dictionary = steps[clampi(step, 0, steps.size() - 1)]
	var stronger := power * float(boost.get("power", 1.0))
	var bonus := int(boost.get("tier_bonus", 0))
	var fight := arena_fight(zone, library, seed_value, rules, stronger, loadout, bonus)
	fight["skills"] = int(boost.get("skills", 0))
	var hard := str(boost.get("difficulty", ""))
	if hard != "":
		fight["difficulty"] = hard
	fight["streak"] = step
	fight["edge"] = float(boost.get("edge", 0.0))
	return fight


## Empieza un combate de arena: con bote en juego, queda marcado (cerrar el
## juego en mitad es abandonarlo y se pierde el bote).
func begin_arena(profile: PlayerProfile) -> void:
	profile.arena_live = profile.arena_pot > 0


## Cobra el bote de la arena. Devuelve lo cobrado.
func cash_arena(profile: PlayerProfile) -> int:
	var amount := profile.arena_pot
	profile.gold += amount
	profile.arena_pot = 0
	profile.upgrade_points += profile.arena_points
	profile.arena_points = 0
	profile.arena_streak = 0
	profile.arena_live = false
	return amount


## Al abrir el juego: un bote que se quedo sin cobrar se cobra; uno que se
## quedo en mitad de un combate de la racha se pierde. {"cashed", "lost"}.
func resume_arena(profile: PlayerProfile) -> Dictionary:
	if profile.arena_live:
		var lost := profile.arena_pot
		profile.arena_pot = 0
		profile.arena_points = 0
		profile.arena_streak = 0
		profile.arena_live = false
		return {"cashed": 0, "lost": lost}
	var pending := profile.arena_pot > 0 or profile.arena_points > 0
	return {"cashed": cash_arena(profile) if pending else 0, "lost": 0}


## El equipo con el que sale a pelear un mech, para medirle el rival de la
## arena (BuildLibrary.trim): cuantas armas laterales y superiores, modulos y
## especiales lleva, de que formas son sus armas de brazo (el rival saca las
## suyas de esas formas, si las tiene) y si lleva asistente y arma de pecho.
static func loadout_of(build: MechBuild) -> Dictionary:
	var forms: Array[String] = []
	for item in build.sides:
		if item != null:
			forms.append(item.form)
	var count := func(list: Array) -> int:
		var total := 0
		for item: Variant in list:
			if item != null:
				total += 1
		return total
	return {
		"sides": count.call(build.sides),
		"forms": forms,
		"tops": count.call(build.tops),
		"modules": count.call(build.modules),
		"specials": count.call([build.charge, build.hook, build.teleport]),
		"assist": build.drone != null or build.drone_low != null,
		"chest": build.chest != null,
	}


## Poder medio de las piezas del jugador en ese mech (ItemScaling.power).
static func mean_power(
	rules: RulesConfig, profile: PlayerProfile, item_ids: Array[String]
) -> float:
	if item_ids.is_empty():
		return ItemScaling.power(rules, ItemDef.Tier.COMMON, 0)
	var total := 0.0
	for id in item_ids:
		var p := profile.part(id)
		total += ItemScaling.power(rules, p["tier"], p["level"])
	return total / item_ids.size()


## True si ese modo ("arena" o "free") esta cerrado: lo esta mientras la
## campana de la liga este en marcha. Con solo el campeon por delante, la
## arena se abre para entrenar (OBS-037, del usuario: "en caso de que no
## pueda derrotar a un jefe porque sea muy dificil, tengo la opcion de
## farmear... y subir de nivel jugando en la arena"): lo que se gana ahi
## (celdas y experiencia) se queda, y perder en la arena no toca la campana.
func mode_locked(profile: PlayerProfile, mode: String) -> bool:
	if mode == "campaign" or not profile.campaign_on:
		return false
	if mode == "arena" and at_champion(profile):
		return false
	return true


## True si en la campana de la liga ya solo queda el campeon.
func at_champion(profile: PlayerProfile) -> bool:
	if profile.zone >= zone_count():
		return false
	return is_boss_fight(profile.zone, profile.fight)


## Empieza un combate de la campana: desde el primero, la campana de la liga
## esta en marcha y la arena y el combate libre se cierran.
func begin_fight(profile: PlayerProfile) -> void:
	if profile.zone < zone_count() and not is_complete(profile):
		profile.campaign_on = true


## Lo que cuesta una proteccion en la liga del jugador.
func protection_price(kind: String, zone: int) -> int:
	var at := mini(zone, zone_count() - 1)
	return roundi(int(protection_prices.get(kind, 0)) * reward_mult(at))


## Devuelve "" si puede comprar esa proteccion; si no, el motivo.
func why_cant_protect(profile: PlayerProfile, kind: String) -> String:
	if not kind in PROTECTIONS or not protection_prices.has(kind):
		return "esa proteccion no existe"
	if int(profile.protections.get(kind, 0)) > 0:
		return "ya la tienes"
	if is_complete(profile):
		return "la campana ya esta completa"
	if protection_price(kind, profile.zone) > profile.gold:
		return "faltan celdas"
	return ""


## Compra una proteccion (una de cada tipo como mucho). Devuelve "" o el motivo.
func buy_protection(profile: PlayerProfile, kind: String) -> String:
	var reason := why_cant_protect(profile, kind)
	if reason != "":
		return reason
	profile.gold -= protection_price(kind, profile.zone)
	profile.protections[kind] = 1
	return ""


## La proteccion que se gastaria si pierde ahora: la mejor que lleve, o "".
func protection_in_use(profile: PlayerProfile) -> String:
	for kind in PROTECTIONS:
		if int(profile.protections.get(kind, 0)) > 0:
			return kind
	return ""


## True si perder ahora un combate de la campana acabaria la partida.
func loss_ends_run(profile: PlayerProfile) -> bool:
	return on_loss == "new_game" and protection_in_use(profile) == ""


## Apunta el resultado de un combate en el perfil del jugador: cobra y avanza
## la campana o, si perdio en ella, gasta su proteccion o termina la partida
## (reglas de liga, arriba). Los jefes que lo dicen en los datos
## ("drops_unique") dan ademas un nucleo unico. Con `progression`, suma la
## experiencia del combate. `mode` es "arena" o "campaign". Devuelve {"gold",
## "game_over", "zone_cleared", "boss", "unique", "protected" (la proteccion
## gastada, "" si ninguna), "xp", "level_up"}.
func finish_fight(
	profile: PlayerProfile,
	shop: ArenaShop,
	mode: String,
	won: bool,
	progression: Progression = null
) -> Dictionary:
	var out := _settle(profile, shop, mode, won)
	# Experiencia: tambien en la arena y al perder (menos), nunca al perder
	# la partida contra un jefe. En la racha de la arena, ganar da mas cuanto
	# mas lejos va (OBS-051), y no se arriesga.
	out["xp"] = 0
	out["level_up"] = false
	if progression != null and not out["game_over"]:
		var kind := "loss"
		if won:
			kind = "boss_win" if out["boss"] else "win"
		var before := progression.level_for(profile.xp)
		var boost := streak_xp(int(out["step"])) if mode == "arena" and won else 1.0
		out["xp"] = roundi(progression.xp_for(kind) * boost)
		profile.xp += out["xp"]
		out["level_up"] = progression.level_for(profile.xp) > before
	return out


## Un combate de arena (OBS-049): ganar pone su premio en el bote (el doble
## que el del anterior de la racha) y deja pedir otro; perder pierde el
## bote y cobra lo de perder. Al ganar el ultimo de la racha, se cobra.
## Anade a `out`: "prize", "pot", "lost", "streak" y "more" (se puede
## pedir otro).
func _settle_arena(
	profile: PlayerProfile, shop: ArenaShop, won: bool, mult: float, out: Dictionary
) -> Dictionary:
	var step := clampi(profile.arena_streak, 0, streak_fights() - 1)
	profile.arena_live = false
	out["prize"] = 0
	out["lost"] = 0
	out["points"] = 0
	out["points_lost"] = 0
	out["step"] = step
	if won:
		profile.wins += 1
		var prize := roundi(shop.reward("arena_win") * mult * streak_prize(step))
		profile.arena_pot += prize
		profile.arena_points += streak_points(step)
		profile.arena_streak = step + 1
		out["prize"] = prize
		out["points"] = streak_points(step)
	else:
		out["lost"] = profile.arena_pot
		out["points_lost"] = profile.arena_points
		profile.arena_pot = 0
		profile.arena_points = 0
		profile.arena_streak = 0
		out["gold"] = profile.earn(shop, "arena_loss", mult)
	out["pot"] = profile.arena_pot
	out["points_pot"] = profile.arena_points
	out["streak"] = profile.arena_streak
	out["more"] = won and profile.arena_streak < streak_fights()
	out["points_cashed"] = 0
	if won and not out["more"]:
		out["points_cashed"] = profile.arena_points
		out["gold"] = cash_arena(profile)
	return out


func _settle(profile: PlayerProfile, shop: ArenaShop, mode: String, won: bool) -> Dictionary:
	var out := {
		"gold": 0,
		"game_over": false,
		"zone_cleared": false,
		"boss": false,
		"unique": false,
		"protected": "",
	}
	var mult := reward_mult(profile.zone)
	if mode == "arena":
		return _settle_arena(profile, shop, won, mult, out)
	if mode != "campaign" or profile.zone >= zone_count():
		out["gold"] = profile.earn(shop, "arena_win" if won else "arena_loss", mult)
		return out
	var boss := is_boss_fight(profile.zone, profile.fight)
	out["boss"] = boss
	if won and boss:
		out["gold"] = profile.earn(shop, "boss_win", mult)
		if bool(zones[profile.zone].get("drops_unique", false)):
			profile.unique_cores += 1
			out["unique"] = true
		# Liga ganada: la siguiente empieza con su campana sin tocar.
		profile.zone += 1
		profile.fight = 0
		profile.campaign_on = false
		out["zone_cleared"] = true
	elif won:
		out["gold"] = profile.earn(shop, "campaign_win", mult)
		profile.fight += 1
		profile.campaign_on = true
	elif on_loss != "new_game":
		out["gold"] = profile.earn(shop, "boss_loss" if boss else "campaign_loss", mult)
	else:
		_lose_campaign_fight(profile, out)
	return out


## Perder un combate de la campana: gasta la mejor proteccion que lleve o,
## sin ninguna, termina la partida.
func _lose_campaign_fight(profile: PlayerProfile, out: Dictionary) -> void:
	var used := protection_in_use(profile)
	out["protected"] = used
	if used == "":
		profile.end_run()
		out["game_over"] = true
		return
	profile.losses += 1
	profile.protections[used] = 0
	if used == "rematch":
		# Un paso atras: contra el campeon, al penultimo rival.
		profile.fight = maxi(profile.fight - 1, 0)
	else:
		profile.fight = 0
		profile.campaign_on = false


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
	if raw.has("body") and not raw["body"] is String:
		return "'body' no es un nombre"
	for kit: String in kits_of(raw):
		if not kit in KITS:
			return "habilidad desconocida en 'kits': %s" % kit
	return ""
