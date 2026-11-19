class_name ArmoryPages
extends RefCounted
## Los espacios del taller que antes eran la armeria (pedido del usuario el
## 2026-11-18: "no existe una armeria y un taller aparte; todo esta combinado
## en el taller"): la tienda con lo que se vende para tu zona y tu nivel, las
## mejoras permanentes y el arbol de habilidades. WorkshopScreen los desliza
## en su panel derecho; aqui solo se construyen.

## Grupos de la tienda, con los tipos de pieza de cada uno.
const STORE_GROUPS: Array[String] = [
	"todo", "brazo", "hombro", "pecho", "cuerpo", "modulo", "especial", "asistente"
]
const GROUP_TYPES := {
	"brazo": [ItemDef.Type.SIDE],
	"hombro": [ItemDef.Type.TOP],
	"pecho": [ItemDef.Type.CHEST],
	"cuerpo": [ItemDef.Type.TORSO, ItemDef.Type.LEGS],
	"modulo": [ItemDef.Type.MODULE],
	"especial": [ItemDef.Type.CHARGE, ItemDef.Type.TELEPORT, ItemDef.Type.HOOK],
	"asistente": [ItemDef.Type.DRONE],
}
const COLOR_MUTED := Color("9aa7b8")
const COLOR_CELLS := Color("7fe3ff")
const COLOR_GROUP := Color("ffe27a")


## Grupo de la tienda al que va un tipo de pieza.
static func group_of(type: ItemDef.Type) -> String:
	for group: String in GROUP_TYPES:
		if type in GROUP_TYPES[group]:
			return group
	return "todo"


## Tienda: las piezas que se venden en la clase de la zona, por grupos. Las
## tuyas no salen (estan en Pieza). Cada una se compra con su boton o se
## arrastra al hueco o al mech (se compra y se monta).
static func store(screen: WorkshopScreen, box: VBoxContainer, group: String) -> void:
	var main := screen.main
	var tier := main._zone_tier()
	var level := main._player_level()
	_label(box, Txt.t("store_page_info", [Txt.TIER_NAMES[tier], main._profile.zone + 1]), 14)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	box.add_child(chips)
	for id in STORE_GROUPS:
		var chip := Button.new()
		chip.text = Txt.t("store_group_" + id)
		chip.toggle_mode = true
		chip.button_pressed = id == group
		chip.focus_mode = Control.FOCUS_NONE
		if id == group:
			chip.add_theme_color_override("font_color", COLOR_GROUP)
		chip.pressed.connect(screen.show_store.bind(id))
		chips.add_child(chip)
	var shown := 0
	for id in main._garage.stock_for(main._catalog, tier):
		var def := main._catalog.get_item(id)
		if id in main._profile.owned:
			continue
		if group != "todo" and not def.type in GROUP_TYPES[group]:
			continue
		var card := PartCard.new()
		card.item = ItemScaling.resolve(def, main._rules, tier, 0)
		card.detail = Txt.t(
			"part_level", [Txt.TIER_NAMES[tier], 0, main._rules.tier_max_level[tier]]
		)
		# Lo que tu nivel aun no deja usar se puede comprar, pero lo avisa.
		var slot := Garage.drop_slot(main._profile.build, main._catalog, id)
		if slot != "" and not main._progression.is_unlocked(slot, level):
			card.detail += " · " + Txt.t("store_from_level", [main._progression.unlock_level(slot)])
		card.stats = WorkshopScreen.item_stats(card.item, false)
		card.price = main._garage.price(main._catalog, main._rules, main._workshop, id, tier)
		card.buy_reason = main._garage.why_cant_buy(
			main._profile, main._catalog, main._rules, main._workshop, id, tier
		)
		card.bought.connect(screen.buy)
		card.chosen.connect(screen.focus_item)
		card.hovered.connect(screen.hover_item)
		box.add_child(card)
		shown += 1
	if shown == 0:
		_label(box, Txt.t("store_nothing"), 13, COLOR_MUTED)


## Mejoras permanentes del mech (la armeria de antes), con el tope de la zona.
static func upgrades(screen: WorkshopScreen, box: VBoxContainer) -> void:
	var main := screen.main
	var shop := main._shop
	var cap := main._armory_cap()
	_label(box, Txt.t("upgrades_page_info", [cap, shop.max_level()]), 14)
	for track in shop.track_ids():
		var level := main._profile.level_of(track)
		var row := HBoxContainer.new()
		box.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 0)
		row.add_child(text)
		_label(text, shop.display_name(track), 15)
		var value := Txt.t(
			"upgrade_level", [level, shop.max_level(), value_text(shop, track, level)]
		)
		_label(text, value, 13, COLOR_MUTED)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(140, 40)
		row.add_child(buy)
		if level >= shop.max_level():
			buy.text = Txt.t("shop_max")
			buy.disabled = true
			continue
		var reason := main._profile.why_cant_buy(shop, track, cap)
		buy.text = Txt.t("shop_buy", [shop.price(level + 1)])
		buy.disabled = reason != ""
		buy.tooltip_text = reason
		if reason.begins_with("se abre"):
			buy.text = Txt.t("shop_locked_assist")
		elif reason == "la zona no deja subirla mas":
			buy.text = Txt.t("part_zone_max")
			buy.tooltip_text = Txt.t("shop_zone_cap", [cap])
		buy.pressed.connect(screen.buy_upgrade.bind(track))


## Lo que da una mejora a ese nivel: "+5 %" o "+123".
static func value_text(shop: ArenaShop, track: String, level: int) -> String:
	var amount := shop.value(track, level)
	if shop.tracks[track]["kind"] == "percent":
		return "+%d %%" % roundi(amount * 100.0)
	return "+%d" % roundi(amount)


## Arbol de habilidades: puntos por nivel y tres ramas que se aprenden en orden.
static func skills(screen: WorkshopScreen, box: VBoxContainer) -> void:
	var main := screen.main
	var tree := main._skills
	var level := main._player_level()
	var points := tree.points_left(main._profile, level)
	_label(box, Txt.t("skill_points", [points, level]), 15, COLOR_CELLS)
	for branch in tree.branches:
		var nodes: Array = branch["nodes"]
		var done := tree.learned_in(main._profile, branch["id"])
		_label(box, Txt.t("skill_branch", [branch["name"], done, nodes.size()]), 16)
		if done > 0:
			var learned: Array[String] = []
			for i in done:
				learned.append(str(nodes[i]["name"]))
			var line := _label(box, Txt.t("skill_learned", [", ".join(learned)]), 12, COLOR_MUTED)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var next := tree.next_in(main._profile, branch)
		if next.is_empty():
			_label(box, Txt.t("skill_done"), 13, COLOR_MUTED)
			continue
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Txt.t("skill_next", [next["name"], SkillTree.describe(next)])
		var text := _label(row, label, 13)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var learn := Button.new()
		learn.text = Txt.t("skill_learn")
		learn.custom_minimum_size = Vector2(110, 36)
		var reason := tree.why_cant_learn(main._profile, next["id"], level)
		learn.disabled = reason != ""
		learn.tooltip_text = reason
		learn.pressed.connect(screen.learn.bind(next["id"]))
		row.add_child(learn)


## Las etiquetas se parten en lineas: una larga no debe ensanchar la pagina
## (empujaria los botones fuera del panel).
static func _label(parent: Node, text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
