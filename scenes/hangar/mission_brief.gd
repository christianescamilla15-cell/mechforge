class_name MissionBrief
extends RefCounted
## Lo que el hangar ensena al salir a combatir: el monitor de misiones
## (MissionBoard) y la fila de rivales proyectada en el suelo (RivalRow). Hay
## cuatro canales: la campana (el combate que toca y los que le siguen, hasta
## el jefe), la arena (un rival a tu medida), el Exterminio (oleadas sin
## final, OBS-053) y el combate libre (el rival que elijas, sin recompensa).
##
## Cada estado es un diccionario:
## {"channel", "zone_line", "title", "fights", "fight", "lines", "warning",
##  "danger", "confirm", "confirm_text", "protections", "pickers", "rivals"}
## - "fights" y "fight": las luces de avance (combates normales de la zona y
##   el que toca; con "fights" 0 no hay luces);
## - "lines": lo que dice el monitor de ese combate;
## - "warning": lo que pasa si pierdes; "danger": perder acaba la partida;
## - "confirm": hay que pulsar dos veces (al entrar en la campana de una
##   liga y contra su campeon); "confirm_text": lo que dice al armarlo;
## - "protections": en la campana, las que se pueden comprar (protections());
## - "pickers": en el combate libre, [{"key", "value"}] para elegir;
## - "rivals": la fila, el primero es el que toca. Cada uno:
##   {"id", "build", "name", "boss", "tier", "level", "difficulty", "detail"
##   (clase, nivel y dificultad), "traits" (como pelea: "Agresivo · con
##   escudo"; "" si nada), "temper" (su caracter, "" si no tiene), "kits"}.

const CHANNELS: Array[String] = ["campaign", "arena", "exterminio", "free"]
## Rivales de la campana que se ven en fila: el que toca y los siguientes.
const ROW_SIZE := 4
const DIFFICULTY_KEYS: Array[String] = ["difficulty_easy", "difficulty_normal", "difficulty_hard"]
## Lo elegido en el combate libre si aun no se eligio nada.
const FREE_DEFAULTS := {"enemy": 1, "tier": 2, "difficulty": 1}

var rules: RulesConfig
var catalog: Catalog
var library: BuildLibrary
var chassis: ChassisLibrary
var campaign: Campaign
var shop: ArenaShop


## La campana: la zona, su avance y la fila desde el combate que toca.
func campaign_state(profile: PlayerProfile) -> Dictionary:
	var state := _blank("campaign")
	var zone := mini(profile.zone, campaign.zone_count() - 1)
	state["zone_line"] = Txt.t("mission_zone_of", [zone + 1, campaign.world_bosses])
	state["title"] = campaign.zone_name(zone)
	state["fights"] = campaign.fights_in(zone)
	var lines: Array[String] = []
	if campaign.is_complete(profile):
		state["fight"] = state["fights"] + 1
		lines.append(Txt.t("campaign_won", [campaign.world_bosses]))
		state["lines"] = lines
		return state
	if profile.zone >= campaign.zone_count():
		state["zone_line"] = Txt.t("mission_zone_of", [profile.zone + 1, campaign.world_bosses])
		state["title"] = ""
		state["fights"] = 0
		lines.append(Txt.t("campaign_pending", [profile.zone + 1, campaign.world_bosses]))
		state["lines"] = lines
		return state
	state["fight"] = profile.fight
	var rivals: Array[Dictionary] = []
	for entry in campaign.ladder(profile, ROW_SIZE):
		rivals.append(rival(entry, campaign.tier_of(zone)))
	state["rivals"] = rivals
	var mult := campaign.reward_mult(zone)
	if rivals.is_empty():
		# Un avance que no existe (mas alla del jefe): sin rival que ensenar.
		state["lines"] = lines
		return state
	var boss := campaign.is_boss_fight(zone, profile.fight)
	if boss:
		lines.append(Txt.t("mission_boss"))
		var ability := boss_ability(str(rivals[0]["id"]))
		if ability != "":
			lines.append(ability)
		if campaign.boss_skills(zone) > 0:
			lines.append(Txt.t("campaign_boss_skills", [campaign.boss_skills(zone)]))
		lines.append(Txt.t("mission_reward_boss", [roundi(shop.reward("boss_win") * mult)]))
		# Antes del campeon se puede entrenar en la arena (OBS-037).
		if profile.campaign_on:
			lines.append(Txt.t("mission_arena_open"))
	else:
		lines.append(Txt.t("mission_fight", [profile.fight + 1, state["fights"]]))
		lines.append(Txt.t("mission_reward_win", [roundi(shop.reward("campaign_win") * mult)]))
	if campaign.enemy_armory(zone) > 0:
		lines.append(Txt.t("mission_order", [campaign.enemy_armory(zone)]))
	state["lines"] = lines
	# Lo que se juega: perder acaba la partida, salvo que lleve proteccion.
	var guard := campaign.protection_in_use(profile)
	state["warning"] = Txt.t("mission_loss_" + (guard if guard != "" else "all"))
	state["danger"] = campaign.loss_ends_run(profile)
	# Dos pulsaciones para entrar en la campana de la liga (se cierran la
	# arena y el combate libre) y para desafiar al campeon.
	var entering := not profile.campaign_on and profile.fight == 0
	state["confirm"] = campaign.on_loss == "new_game" and (boss or entering)
	if entering and not boss:
		state["confirm_text"] = Txt.t("mission_confirm_enter")
	state["protections"] = protections(profile)
	return state


## Las protecciones de la campana, de la mas barata a la mas cara: {"kind",
## "name", "text" (lo que hace), "price", "owned", "reason" (por que no se
## puede comprar; "" = se puede)}.
func protections(profile: PlayerProfile) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(Campaign.PROTECTIONS.size() - 1, -1, -1):
		var kind := Campaign.PROTECTIONS[i]
		(
			out
			. append(
				{
					"kind": kind,
					"name": Txt.t("protection_" + kind),
					"text": Txt.t("protection_text_" + kind),
					"price": campaign.protection_price(kind, profile.zone),
					"owned": int(profile.protections.get(kind, 0)) > 0,
					"reason": campaign.why_cant_protect(profile, kind),
				}
			)
		)
	return out


## La arena: un rival al azar (de la semilla) a la medida del jugador. La
## misma semilla da el mismo rival, asi que el que se ve es el que sale.
func arena_state(
	profile: PlayerProfile, seed_value: int, power: float, loadout: Dictionary = {}
) -> Dictionary:
	var state := _blank("arena")
	var zone := mini(profile.zone, campaign.zone_count() - 1)
	state["zone_line"] = Txt.t("mission_zone", [zone + 1, campaign.zone_name(zone)])
	state["title"] = Txt.t("menu_arena")
	var fight := campaign.arena_fight(zone, library, seed_value, rules, power, loadout)
	var rivals: Array[Dictionary] = [rival(fight, campaign.tier_of(zone))]
	state["rivals"] = rivals
	var mult := campaign.reward_mult(profile.zone)
	var lines: Array[String] = [
		Txt.t("mission_arena_info"),
		Txt.t("mission_arena_streak"),
		Txt.t("mission_arena_streak_risk"),
		Txt.t(
			"mission_reward_arena",
			[roundi(shop.reward("arena_win") * mult), roundi(shop.reward("arena_loss") * mult)]
		)
	]
	state["lines"] = lines
	return state


## El Exterminio (OBS-053): el rival de la oleada que toca (la misma semilla
## da el mismo rival, asi que el que se ve es el que sale), la oleada, el
## record y lo que paga.
func exterminio_state(
	profile: PlayerProfile, seed_value: int, power: float, loadout: Dictionary = {}
) -> Dictionary:
	var state := _blank("exterminio")
	var zone := mini(profile.zone, campaign.zone_count() - 1)
	var wave := profile.exterminio_wave
	state["zone_line"] = Txt.t("mission_zone", [zone + 1, campaign.zone_name(zone)])
	state["title"] = Txt.t("exterminio_title", [wave + 1])
	var fight := campaign.exterminio_fight(zone, library, seed_value, rules, power, loadout, wave)
	var rivals: Array[Dictionary] = [rival(fight, campaign.tier_of(zone))]
	state["rivals"] = rivals
	var pay := shop.reward("arena_win") * campaign.reward_mult(profile.zone)
	pay = roundi(pay * campaign.exterminio_gold(wave))
	var best := profile.exterminio_best
	var lines: Array[String] = [
		Txt.t("mission_exterminio_info"),
		Txt.t("mission_exterminio_rule"),
		(
			Txt.t("mission_exterminio_best", [best, pay])
			if best > 0
			else Txt.t("mission_exterminio_first", [pay])
		),
	]
	state["lines"] = lines
	state["warning"] = Txt.t("mission_exterminio_warning")
	return state


## El combate libre: el rival, la clase y la dificultad que se elijan
## (`picks`: {"enemy", "tier", "difficulty"}, cada uno un indice). Las piezas
## de los dos van al nivel maximo de esa clase.
func free_state(picks: Dictionary) -> Dictionary:
	var state := _blank("free")
	state["zone_line"] = Txt.t("mission_free_info")
	state["title"] = Txt.t("mission_free_head")
	var pick := free_pick(picks)
	var tier: int = pick["tier"]
	var entry := {
		"enemy": library.all_ids()[pick["enemy"]],
		"tier": tier,
		"level": rules.tier_max_level[tier],
		"difficulty": Campaign.DIFFICULTIES[pick["difficulty"]],
	}
	var chosen := rival(entry, tier)
	var rivals: Array[Dictionary] = [chosen]
	state["rivals"] = rivals
	var pickers: Array[Dictionary] = [
		{"key": "enemy", "value": chosen["name"]},
		{"key": "tier", "value": Txt.TIER_NAMES[tier]},
		{"key": "difficulty", "value": Txt.t(DIFFICULTY_KEYS[pick["difficulty"]])},
	]
	state["pickers"] = pickers
	return state


## Lo elegido en el combate libre, ya dentro de lo que existe.
func free_pick(picks: Dictionary) -> Dictionary:
	var out := {}
	for key: String in FREE_DEFAULTS:
		out[key] = posmod(int(picks.get(key, FREE_DEFAULTS[key])), free_count(key))
	return out


## Cuantas opciones tiene cada cosa que se elige en el combate libre.
func free_count(key: String) -> int:
	match key:
		"enemy":
			return library.all_ids().size()
		"tier":
			return Txt.TIER_NAMES.size()
	return Campaign.DIFFICULTIES.size()


## Habilidad especial de un jefe, como texto; "" si no tiene.
func boss_ability(id: String) -> String:
	if chassis == null:
		return ""
	var def := chassis.get_def(library.chassis_of(id))
	if def == null or def.ability == "":
		return ""
	return Txt.t("campaign_boss_ability", [def.ability, def.ability_text])


func _blank(channel: String) -> Dictionary:
	var rivals: Array[Dictionary] = []
	var lines: Array[String] = []
	var pickers: Array[Dictionary] = []
	return {
		"channel": channel,
		"zone_line": "",
		"title": "",
		"fights": 0,
		"fight": 0,
		"lines": lines,
		"warning": "",
		"danger": false,
		"confirm": false,
		"confirm_text": "",
		"protections": [] as Array[Dictionary],
		"pickers": pickers,
		"rivals": rivals,
	}


## Un rival de la fila, armado como saldra al combate. `entry` es su combate
## ({"enemy", "level", "difficulty" y, si no es la de la zona, "tier"; en la
## arena, tambien "loadout": el equipo con el que sale).
func rival(entry: Dictionary, zone_tier: int) -> Dictionary:
	var id := str(entry["enemy"])
	var tier := int(entry.get("tier", zone_tier))
	var level := int(entry["level"])
	var difficulty := maxi(Campaign.DIFFICULTIES.find(str(entry["difficulty"])), 0)
	var detail := Txt.t(
		"mission_rival", [Txt.TIER_NAMES[tier], level, Txt.t(DIFFICULTY_KEYS[difficulty])]
	)
	# Como pelea, en su propio renglon: su caracter (TemperLibrary) y lo que
	# sabe hacer ademas de disparar. Se ve antes de salir.
	var traits: Array[String] = []
	var temper := library.temper_of(id)
	if temper != "":
		traits.append(Txt.t("temper_" + temper))
	var kits := Campaign.kits_of(entry)
	var known: Array[String] = []
	if int(kits.get("shield_uses", 0)) > 0:
		known.append(Txt.t("ability_shield").to_lower())
	if int(kits.get("repair_uses", 0)) > 0:
		known.append(Txt.t("mission_kit_repair"))
	if not known.is_empty():
		traits.append(Txt.t("mission_rival_kits", [" y ".join(known)]))
	var manner := " · ".join(traits)
	var build := library.make(
		id, catalog, rules, tier as ItemDef.Tier, level, chassis, {}, entry.get("loadout", {})
	)
	# Con su cuerpo propio, si su combate se lo da (OBS-011).
	build.body = Campaign.body_of(entry)
	return {
		"id": id,
		"build": build,
		"name": library.display_name(id),
		"boss": library.is_boss(id),
		"tier": tier,
		"level": level,
		"difficulty": difficulty,
		"detail": detail,
		"traits": manner.left(1).to_upper() + manner.substr(1),
		"temper": temper,
		"kits": kits,
	}
