class_name TreeBrief
extends RefCounted
## Lo que ensena la pantalla del arbol de mejoras (WallConsole, OBS-051): una
## fila por rama con sus pasos; la bifurcacion es un paso con dos nodos.
## "state" de cada nodo: "done", "next" (con "reason" si aun no se puede),
## "closed", "soon" (su efecto aun no lo aplica el juego) u "other" (se eligio
## la otra especializacion).


static func state(tree: UpgradeTree, shop: ArenaShop, profile: PlayerProfile) -> Dictionary:
	var branches: Array[Dictionary] = []
	for branch: Dictionary in tree.branches:
		var open := tree.is_open(profile, branch)
		var done := tree.learned_in(profile, branch)
		var steps: Array = []
		var raw: Array = branch["steps"]
		for i in raw.size():
			var step: Array[Dictionary] = []
			for node: Dictionary in raw[i]:
				step.append(_node(tree, shop, profile, node, i, done, open, branch))
			steps.append(step)
		var from := str(branch["from"])
		(
			branches
			. append(
				{
					"id": str(branch["id"]),
					"name": str(branch["name"]),
					"open": open,
					"done": done,
					"from": shop.display_name(from) if from != "" else "",
					"steps": steps,
				}
			)
		)
	return {
		"kind": "arbol",
		"title": Txt.t("terminal_arbol"),
		"points": profile.upgrade_points,
		"branches": branches,
	}


static func _node(
	tree: UpgradeTree,
	shop: ArenaShop,
	profile: PlayerProfile,
	node: Dictionary,
	step: int,
	done: int,
	open: bool,
	branch: Dictionary
) -> Dictionary:
	var id := str(node["id"])
	var kind := "closed"
	var reason := ""
	if id in profile.tree:
		kind = "done"
	elif step < done:
		kind = "other"
		reason = Txt.t("tree_other")
	elif not open:
		var from := str(branch["from"])
		reason = (
			Txt.t("tree_closed", [shop.display_name(from)])
			if from != ""
			else Txt.t("tree_closed_arena")
		)
	elif not tree.is_ready(id):
		kind = "soon"
		reason = Txt.t("tree_soon")
	elif step == done:
		kind = "next"
		if profile.upgrade_points < tree.cost(id):
			reason = Txt.t("tree_poor", [tree.cost(id)])
	else:
		reason = Txt.t("tree_after")
	return {
		"id": id,
		"name": str(node["name"]),
		"text": effects_text(node.get("effects", {})),
		"state": kind,
		"reason": reason,
		"cost": tree.cost(id),
	}


## Lo que hace un nodo del arbol, en palabras ("+3 % de dano").
static func effects_text(effects: Dictionary) -> String:
	var parts: PackedStringArray = []
	for effect: String in effects:
		var amount: Variant = effects[effect]
		var shown := "%d %%" % roundi(float(amount) * 100.0)
		if effect in UpgradeTree.WHOLE:
			shown = str(int(amount))
		# Algunos no llevan cifra ("el asistente dispara dos veces").
		var text := Txt.t("tree_fx_" + effect)
		parts.append(text % [shown] if "%" in text else text)
	return ", ".join(parts)
