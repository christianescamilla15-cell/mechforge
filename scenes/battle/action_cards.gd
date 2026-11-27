class_name ActionCards
extends RefCounted
## El abanico de acciones del combate (salio de BattleScreen): por que no se
## puede usar una accion, cuantos usos le quedan y su tarjeta (nombre, dano,
## critico, costes y motivo). Lee el combate de `screen`.

var screen: BattleScreen


func reason_for(action: BattleAction) -> String:
	if action.type == BattleAction.Type.TELEPORT:
		return screen.engine.why_cant_use(
			screen.engine.mechs[screen.player], screen.engine.mechs[1 - screen.player], "teleport"
		)
	return screen.engine.why_illegal(action)


func uses_left_for(action: BattleAction) -> int:
	var kinds := {
		BattleAction.Type.SHIELD: "shield",
		BattleAction.Type.REPAIR: "repair",
		BattleAction.Type.DARK_MATTER: "dark_matter",
	}
	if kinds.has(action.type):
		return screen.engine.mechs[screen.player].kits_left(kinds[action.type])
	var key := slot_of(action)
	var slots := screen.engine.mechs[screen.player].slots
	return slots[key].uses_left if slots.has(key) else -1


static func slot_of(action: BattleAction) -> String:
	match action.type:
		BattleAction.Type.WEAPON:
			return action.slot
		BattleAction.Type.STOMP:
			return "legs"
		BattleAction.Type.CHARGE:
			return "charge"
		BattleAction.Type.HOOK:
			return "hook"
		BattleAction.Type.TELEPORT:
			return "teleport"
	return ""


## La tarjeta de una accion del abanico (BattleHud.card_for): su nombre y, en
## pequeno, su dano, su critico, lo que cuesta y, si no se puede usar, por que.
func card_for(action: BattleAction) -> Dictionary:
	var mine := screen.engine.mechs[screen.player]
	var lines: Array = []
	var title := ""
	var key := slot_of(action)
	var def: ItemDef = mine.slots[key].def if mine.slots.has(key) else null
	match action.type:
		BattleAction.Type.COOL:
			title = Txt.t("cool")
			lines.append(
				[
					Txt.t("card_cool", [mine.heat, maxi(0, mine.heat - mine.cooling)]),
					BattleScreen.COLOR_COOL
				]
			)
		BattleAction.Type.SHIELD:
			title = Txt.t("ability_shield")
			lines.append([Txt.t("card_shield"), BattleScreen.COLOR_COOL])
		BattleAction.Type.REPAIR:
			title = Txt.t("ability_repair")
			lines.append([Txt.t("card_repair"), BattleScreen.COLOR_REPAIR])
		BattleAction.Type.DARK_MATTER:
			title = Txt.t("ability_dark_matter")
		BattleAction.Type.ULTIMATE:
			title = Txt.t("ultimate")
			var foe := screen.engine.mechs[1 - screen.player]
			var shots := UltimateConfig.salvo(mine, foe).size()
			lines.append([Txt.t("card_ultimate", [shots]), RuleFx.COLOR_ULT])
		BattleAction.Type.STOMP:
			title = Txt.t("stomp")
		_:
			title = def.display_name if def != null else ""
	var my_turn := screen.engine.turn == screen.player and not screen.engine.is_over()
	var reason := reason_for(action) if my_turn else ""
	if my_turn and reason == "" and action.type != BattleAction.Type.TELEPORT:
		# Lo que hara de verdad ahora, contra este rival.
		var p := screen.engine.preview(action)
		if p["dmg_max"] > 0:
			lines.append([Txt.t("card_damage", [p["dmg_min"], p["dmg_max"]]), BattleHud.TEXT])
		var chance: float = p.get("crit_chance", 0.0)
		if chance > 0.0:
			var effect := Txt.t("crit_effect_" + str(p["crit_effect"]))
			lines.append(
				[Txt.t("card_crit", [roundi(chance * 100.0), effect]), BattleScreen.COLOR_CRIT]
			)
		if p["self_overheats"]:
			lines.append([Txt.t("preview_self_overheat"), BattleScreen.COLOR_WARNING])
		if p["target_overheats"]:
			lines.append([Txt.t("preview_target_overheat"), BattleScreen.COLOR_REPAIR])
	elif def != null and def.deals_damage():
		lines.append([Txt.t("card_damage", [def.dmg_min, def.dmg_max]), BattleHud.TEXT])
	if def != null:
		var costs: Array[String] = []
		if def.range_max > 0:
			costs.append(Txt.t("card_range", [def.range_min, def.range_max]))
		if mine.energy_cost(def) > 0:
			costs.append(Txt.t("card_energy", [mine.energy_cost(def)]))
		if def.heat_cost > 0:
			costs.append(Txt.t("card_heat", [def.heat_cost]))
		if def.backfire > 0:
			costs.append(Txt.t("card_backfire", [def.backfire]))
		if not costs.is_empty():
			lines.append([" · ".join(costs), BattleHud.MUTED])
	var uses := uses_left_for(action)
	if uses >= 0:
		lines.append([Txt.t("uses", [str(uses)]), BattleHud.MUTED])
	if reason.strip_edges() != "":
		lines.append(
			[reason.capitalize() if reason.length() < 3 else reason, BattleScreen.COLOR_WARNING]
		)
	return {"title": title, "lines": lines}
