class_name ResultNotes
extends RefCounted
## Lo que dice el panel al acabar un combate de la arena o del Exterminio y
## sus dos teclas (salio de MainScreen). Cada funcion recibe la nota que ya
## hay (lo que cobro, si subio de nivel) y devuelve {"note", "again",
## "back"}: la nota entera, la tecla de seguir y la de volver.

var campaign: Campaign
var shop: ArenaShop
var catalog: Catalog


## Lo que dio un hito de la racha o un campeon: sus armas de arena y su suerte.
func milestone(prize: Dictionary) -> String:
	var out := ""
	for got: Dictionary in prize.get("weapons", []):
		var rank := Txt.t("arena_rank_%d" % int(got["rank"]))
		var said := str(catalog.get_item(str(got["id"])).display_name)
		var key := "arena_weapon" if bool(got["new"]) else "arena_weapon_up"
		out += String.chr(10) + Txt.t(key, [said, rank])
	if int(prize.get("melted", 0)) > 0:
		out += String.chr(10) + Txt.t("arena_melted", [HangarProps.thousands(prize["melted"])])
	if int(prize.get("double", 0)) > 0:
		out += String.chr(10) + Txt.t("arena_double", [HangarProps.thousands(prize["double"])])
	return out


## La racha de la arena tras un combate (OBS-049): lo que paso con el bote
## y las dos teclas, otro combate (con lo que pagaria) o cobrar.
func arena(result: Dictionary, profile: PlayerProfile, level: int, note: String) -> Dictionary:
	var more := bool(result.get("more", false))
	var prize := int(result.get("prize", 0))
	var lost := int(result.get("lost", 0))
	var again := Txt.t("arena_again")
	var back := Txt.t("menu")
	if more:
		var pot := int(result["pot"])
		var mult := campaign.reward_mult(profile.zone)
		var factor := campaign.streak_prize(int(result["streak"]))
		var next := roundi(shop.reward("arena_win") * mult * factor)
		var said := [
			HangarProps.thousands(prize),
			int(result["points"]),
			HangarProps.thousands(pot),
			int(result["points_pot"]),
		]
		note = Txt.t("arena_pot_note", said)
		note += String.chr(10) + Txt.t("arena_risk")
		again = Txt.t("arena_more", [HangarProps.thousands(next)])
		back = Txt.t("arena_cash", [HangarProps.thousands(pot)])
	elif prize > 0:
		var done := [HangarProps.thousands(result["gold"]), int(result["points_cashed"])]
		note = Txt.t("arena_streak_done", done)
	elif lost > 0 or int(result.get("points_lost", 0)) > 0:
		var gone := [HangarProps.thousands(lost), int(result["points_lost"])]
		note = Txt.t("arena_pot_lost", gone)
		note += String.chr(10) + Txt.t("result_reward", [result["gold"]])
	if prize > 0:
		var boost := campaign.streak_xp(int(result["step"]))
		var xp := [HangarProps.thousands(result["xp"]), "%.1f" % boost]
		note += String.chr(10) + Txt.t("arena_xp", xp)
	if bool(result.get("level_up", false)):
		note += String.chr(10) + Txt.t("result_level_up", [level])
	return {"note": note, "again": again, "back": back}


## Tras un combate del Exterminio (OBS-053): el robot o la oleada superada y
## lo que pago, o hasta donde llego; y las dos teclas, el robot siguiente (o
## la oleada siguiente, o empezar de nuevo) y el menu. Entre robots de una
## oleada (OBS-055), volver al menu la acaba.
func exterminio(result: Dictionary, level: int) -> Dictionary:
	var wave := int(result["wave"]) + 1
	var robots := int(result.get("robots", 1))
	var robot := int(result.get("robot", 0)) + 1
	var won := bool(result.get("won", false))
	var gold := HangarProps.thousands(result["gold"])
	var note := ""
	var again := Txt.t("exterminio_restart")
	var back := Txt.t("menu")
	if won and bool(result.get("next_robot", false)):
		note = Txt.t("exterminio_robot_won", [robot, robots, gold])
		note += String.chr(10) + Txt.t("exterminio_carry")
		again = Txt.t("exterminio_robot_next", [robot + 1, robots])
		back = Txt.t("exterminio_leave")
	elif won:
		note = Txt.t("exterminio_won", [wave, gold])
		if bool(result.get("record", false)):
			note += String.chr(10) + Txt.t("exterminio_record", [int(result["best"])])
		if int(result.get("champion", -1)) >= 0:
			var beaten := [int(result["champion"]) + 1, int(result["points"])]
			note += String.chr(10) + Txt.t("exterminio_champion_won", beaten)
		again = Txt.t("exterminio_next", [wave + 1])
	else:
		note = Txt.t("exterminio_lost", [wave, int(result["best"])])
		note += String.chr(10) + Txt.t("result_reward", [result["gold"]])
	if won and int(result.get("xp", 0)) > 0:
		var boost := "%.2f" % campaign.exterminio_xp(wave - 1)
		var xp := [HangarProps.thousands(result["xp"]), boost]
		note += String.chr(10) + Txt.t("exterminio_xp", xp)
	if bool(result.get("level_up", false)):
		note += String.chr(10) + Txt.t("result_level_up", [level])
	return {"note": note, "again": again, "back": back}
