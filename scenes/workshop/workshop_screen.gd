class_name WorkshopScreen
extends Control
## Taller (GDD 4 y 8; como lo pidio el usuario el 2026-11-18, al estilo del
## taller del original). Es tambien la armeria: no hay otra pantalla. El mech
## montado en el centro; a la izquierda sus huecos, colocados como en su
## cuerpo; a la derecha su resumen y un panel que se desliza entre cuatro
## espacios: Pieza (la del hueco elegido: subir, transformar, probar, quitar,
## y las tuyas para ese hueco), Tienda (lo que se vende para tu zona y tu
## nivel), Mejoras (las permanentes) y Habilidades. Las piezas se arrastran al
## hueco o al mech (las de la tienda se compran y se montan), una montada se
## arrastra a otro hueco (se cambian) o al panel (se quita), y la X deja el
## hueco vacio. Lee y cambia el perfil a traves de MainScreen, que lo guarda.

signal closed

## Cuadricula del cuerpo, fila a fila: el lado lejano a la izquierda y el
## cercano a la derecha, como se ven en el dibujo (el mech mira a la derecha).
const BODY_GRID: Array[String] = [
	"top1", "assist", "top0", "side2", "torso", "side0", "side3", "legs", "side1"
]
const EXTRA_ROW: Array[String] = ["chest", "charge", "teleport", "hook"]
const ASSIST_ROW: Array[String] = ["drone", "drone_low"]
const MODULES: Array[String] = [
	"module0", "module1", "module2", "module3", "module4", "module5", "module6", "module7"
]
## Espacios del panel derecho, en el orden en que se deslizan.
const PAGES: Array[String] = ["pieza", "tienda", "mejoras", "habilidades"]
const SLIDE_SECONDS := 0.28
const COLOR_MUTED := Color("9aa7b8")
const COLOR_GOOD := Color("7dff9b")
const COLOR_BAD := Color("ff7d7d")
const COLOR_CELLS := Color("7fe3ff")
const SUMMARY_KEYS: Array[String] = [
	"weight",
	"health",
	"energy_cap",
	"energy_regen",
	"heat_cap",
	"cooling",
	"res_physical",
	"res_heat",
	"res_energy"
]

var main: MainScreen

var _selected: String = "side0"
var _hover_id: String = ""
## Hueco con el que se compara la pieza bajo el raton.
var _hover_slot: String = ""
var _page: String = "pieza"
var _store_group: String = "todo"
var _tabs: Dictionary[String, Button] = {}
var _pages: Control
var _page_scroll: ScrollContainer
var _page_box: VBoxContainer
var _cells: Dictionary[String, SlotCell] = {}
var _stage: MechStage
var _top_info: Label
var _weight: ProgressBar
var _weight_label: Label
var _problems: Label
var _summary: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color("0b1017")
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	_build_top_bar(root)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)
	_build_slots(body)
	_stage = MechStage.new()
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.picked.connect(pick)
	_stage.dropped.connect(_on_stage_dropped)
	body.add_child(_stage)
	_build_side_panel(body)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


# --- Construccion ------------------------------------------------------------


func _build_top_bar(root: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	root.add_child(bar)
	_label(bar, Txt.t("workshop_title"), 28)
	_top_info = _label(bar, "", 17, COLOR_CELLS)
	var weight := VBoxContainer.new()
	weight.custom_minimum_size = Vector2(240, 0)
	weight.add_theme_constant_override("separation", 0)
	bar.add_child(weight)
	_weight_label = _label(weight, "", 13)
	_weight = ProgressBar.new()
	_weight.show_percentage = false
	_weight.custom_minimum_size = Vector2(0, 10)
	weight.add_child(_weight)
	_problems = _label(bar, "", 14, COLOR_BAD)
	_problems.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := Button.new()
	back.text = Txt.t("workshop_back")
	back.custom_minimum_size = Vector2(170, 40)
	back.pressed.connect(func() -> void: closed.emit())
	bar.add_child(back)


func _build_slots(body: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size = Vector2(352, 0)
	body.add_child(column)
	_grid(column, BODY_GRID, 3, false)
	_grid(column, EXTRA_ROW, 4, true)
	_grid(column, ASSIST_ROW, 2, true)
	_grid(column, MODULES, 4, true)
	var hint := _label(column, Txt.t("workshop_hint"), 12, COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _grid(column: VBoxContainer, slots: Array[String], columns: int, compact: bool) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for slot in slots:
		var cell := SlotCell.new()
		cell.slot = slot
		cell.compact = compact
		cell.accepts = Garage.slot_type(slot)
		cell.title = slot_title(slot)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.picked.connect(pick)
		cell.dropped.connect(_on_cell_dropped)
		cell.cleared.connect(clear_slot)
		cell.hovered.connect(_on_cell_hovered)
		grid.add_child(cell)
		_cells[slot] = cell


func _build_side_panel(body: HBoxContainer) -> void:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	panel.add_theme_constant_override("separation", 6)
	body.add_child(panel)
	_summary = GridContainer.new()
	_summary.columns = 4
	_summary.add_theme_constant_override("h_separation", 10)
	panel.add_child(_summary)
	panel.add_child(HSeparator.new())
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	panel.add_child(tabs)
	for page in PAGES:
		var tab := Button.new()
		tab.text = Txt.t("page_" + page)
		tab.toggle_mode = true
		tab.button_pressed = page == _page
		tab.focus_mode = Control.FOCUS_NONE
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(show_page.bind(page))
		tabs.add_child(tab)
		_tabs[page] = tab
	# El espacio que se desliza: cada pagina es un ScrollContainer que entra
	# por un lado mientras la anterior sale por el otro.
	_pages = Control.new()
	_pages.clip_contents = true
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_pages)
	_page_scroll = _new_page()


# --- Estado ------------------------------------------------------------------


## Vuelve a pintar todo con el perfil actual.
func refresh() -> void:
	var build := _build_from(main._profile.build)
	var ghosts: Array[String] = []
	var shown := build
	if build.torso == null or build.legs == null:
		# Sin torso o sin piernas se ve el hueco: una pieza fantasma en su sitio.
		shown = _build_from(main._profile.build)
		if shown.torso == null:
			shown.torso = _placeholder(ItemDef.Type.TORSO)
			ghosts.append("torso")
		if shown.legs == null:
			shown.legs = _placeholder(ItemDef.Type.LEGS)
			ghosts.append("legs")
	_stage.show_build(shown, ghosts)
	_stage.selected_slot = _selected
	var level := main._player_level()
	_top_info.text = Txt.t("workshop_info", [main._profile.gold, level])
	var max_weight := main._rules.max_weight
	_weight.max_value = max_weight + main._rules.overload
	_weight.value = build.total_weight()
	_weight_label.text = Txt.t("mech_weight", [build.total_weight(), max_weight])
	var over := build.total_weight() > max_weight
	_weight.modulate = COLOR_BAD if over else Color.WHITE
	var problems := build.validate(main._rules)
	_problems.text = "" if problems.is_empty() else Txt.t("mech_problems", [", ".join(problems)])
	for slot: String in _cells:
		_refresh_cell(_cells[slot], level)
	_refresh_summary(build)
	_fill_page()


func _refresh_cell(cell: SlotCell, level: int) -> void:
	var id := Garage.get_slot(main._profile.build, cell.slot)
	cell.item = _resolved(id)
	cell.selected = cell.slot == _selected
	cell.locked_text = _lock_reason(cell.slot, level)
	cell.progress_text = _progress_text(cell.item)
	cell.refresh()


## Por que un hueco esta cerrado ("" si esta abierto).
func _lock_reason(slot: String, level: int) -> String:
	if not main._progression.is_unlocked(slot, level):
		return Txt.t("slot_locked", [main._progression.unlock_level(slot)])
	if slot == "drone_low" and main._assist_tier() < main._rules.assist_second_weapon_tier:
		return Txt.t("slot_second_weapon")
	return ""


## Una pieza con la clase y el nivel que tiene el jugador.
func _resolved(id: String) -> ItemDef:
	var def := main._catalog.get_item(id) if id != "" else null
	if def == null:
		return null
	var p := main._profile.part(def.progress_id())
	if def.type == ItemDef.Type.DRONE and main._profile.build.has("assist"):
		# Las armas del asistente suben con el, sin salirse de su rango.
		var assist := main._profile.part(ItemDef.ASSIST_PROGRESS)
		var tier := clampi(assist["tier"], def.tier_min, def.tier_max)
		var level: int = assist["level"]
		if tier < assist["tier"]:
			level = main._rules.tier_max_level[tier]
		elif tier > assist["tier"]:
			level = 0
		p = {"tier": tier, "level": level}
	return ItemScaling.resolve(def, main._rules, p["tier"], p["level"])


func _progress_text(item: ItemDef) -> String:
	if item == null:
		return ""
	if item.type == ItemDef.Type.DRONE and main._profile.build.has("assist"):
		return Txt.t("part_follows_assist")
	var p := main._profile.part(item.progress_id())
	var top: int = main._rules.tier_max_level[p["tier"]]
	return Txt.t("part_level", [Txt.TIER_NAMES[p["tier"]], p["level"], top])


func _build_from(spec: Dictionary) -> MechBuild:
	var build := main._catalog.make_build(
		spec, main._rules, ItemDef.Tier.COMMON, 0, main._profile.parts
	)
	main._progression.apply_locks(build, main._player_level())
	build.skills = main._skills.effects_for(main._profile.skills)
	build.upgrades = main._shop.upgrades_for(main._profile.shop_levels)
	return build


## Pieza con la que se dibuja un torso o unas piernas que faltan.
func _placeholder(type: ItemDef.Type) -> ItemDef:
	for id in main._profile.owned:
		var def := main._catalog.get_item(id)
		if def != null and def.type == type:
			return def
	return main._catalog.by_type(type)[0]


func _refresh_summary(build: MechBuild) -> void:
	for child in _summary.get_children():
		child.queue_free()
	var now := build.summary(main._rules)
	var then := now
	if _hover_id != "" and _hover_slot != "":
		var spec: Dictionary = main._profile.build.duplicate(true)
		Garage.set_slot(spec, _hover_slot, _hover_id)
		then = _build_from(spec).summary(main._rules)
	for key in SUMMARY_KEYS:
		_label(
			_summary,
			Txt.t("stat_weight_total" if key == "weight" else "stat_" + key),
			13,
			COLOR_MUTED
		)
		var value := _label(_summary, str(now[key]), 14)
		var delta: int = int(then[key]) - int(now[key])
		if delta != 0:
			value.text += "  %+d" % delta
			# Mas de todo es mejor, salvo mas peso.
			var better := delta < 0 if key == "weight" else delta > 0
			value.add_theme_color_override("font_color", COLOR_GOOD if better else COLOR_BAD)


## Espacio Pieza: la del hueco elegido y las tuyas que caben en el.
func _fill_part_page(box: VBoxContainer) -> void:
	var id := Garage.get_slot(main._profile.build, _selected)
	var item := _resolved(id)
	var head := slot_title(_selected) + " · "
	head += item.display_name if item != null else Txt.t("slot_empty")
	_label(box, head, 17).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var locked := _lock_reason(_selected, main._player_level())
	if locked != "":
		_label(box, Txt.t("workshop_locked", [locked]), 14, COLOR_MUTED)
		return
	if item == null:
		_label(box, Txt.t("workshop_empty_hint"), 13, COLOR_MUTED)
	else:
		var stats := _label(box, item_stats(item, false), 13, COLOR_MUTED)
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		_add_upgrade_button(row, item)
		if item.deals_damage() and item.fx != "":
			_button(row, Txt.t("workshop_test"), test_fire)
		_button(row, Txt.t("workshop_remove"), clear_slot.bind(_selected))
	box.add_child(HSeparator.new())
	_fill_owned(box, id)
	var to_store := _button(box, Txt.t("workshop_to_store"), show_store.bind(""))
	to_store.custom_minimum_size = Vector2(0, 40)


## Subir de nivel, transformar o el tope que lo para (como en la armeria).
func _add_upgrade_button(row: HBoxContainer, item: ItemDef) -> void:
	if item.type == ItemDef.Type.DRONE and main._profile.build.has("assist"):
		return
	var key := item.progress_id()
	var p := main._profile.part(key)
	var max_tier := main._zone_tier()
	var cap_level := main._campaign.level_cap(main._profile.zone)
	var profile := main._profile
	if p["level"] < main._rules.tier_max_level[p["tier"]]:
		var reason := profile.why_cant_level(main._workshop, main._rules, key, max_tier, cap_level)
		var cost := main._workshop.level_cost(main._rules, p["tier"], p["level"])
		var level_up := _button(row, Txt.t("part_level_up", [cost]), level_up_selected)
		level_up.disabled = reason != ""
		level_up.tooltip_text = reason
		if reason == "la zona no deja subirla mas":
			level_up.text = Txt.t("part_zone_max")
		return
	var item_max := main._catalog.get_item(item.id).tier_max
	var why := profile.why_cant_transform(main._workshop, main._rules, key, max_tier, item_max)
	var label := Txt.t("part_transform", [main._workshop.transform_cost(p["tier"])])
	if p["tier"] == ItemDef.Tier.MYTHIC:
		label = Txt.t("part_unique")
	if not why in ["", "faltan celdas"]:
		label = Txt.t("part_zone_max" if why.contains("zona") else "shop_max")
	var transform := _button(row, label, transform_selected)
	transform.disabled = why != ""
	transform.tooltip_text = why


func _fill_owned(box: VBoxContainer, mounted: String) -> void:
	_label(box, Txt.t("workshop_owned"), 14, COLOR_MUTED)
	var owned := Garage.owned_for(main._profile, main._catalog, _selected)
	if owned.is_empty():
		_label(box, Txt.t("workshop_none"), 13, COLOR_MUTED)
	for id in owned:
		var item := _resolved(id)
		var card := PartCard.new()
		card.item = item
		card.mounted = id == mounted
		card.detail = _progress_text(item)
		if card.mounted:
			card.detail += " · " + Txt.t("workshop_mounted")
		card.stats = item_stats(item, false)
		card.chosen.connect(equip_selected)
		card.hovered.connect(hover_item)
		box.add_child(card)


# --- Espacios que se deslizan --------------------------------------------------


## Lleva el panel derecho a otro espacio, deslizandolo: hacia la izquierda
## si va mas adelante en las pestanas y hacia la derecha si vuelve.
func show_page(page: String) -> void:
	for tab: String in _tabs:
		_tabs[tab].button_pressed = tab == page
	if page == _page:
		_fill_page()
		return
	var forward := PAGES.find(page) > PAGES.find(_page)
	_page = page
	var old := _page_scroll
	_page_scroll = _new_page()
	_fill_page()
	Sfx.play("ui_pagina")
	var width := maxf(_pages.size.x, 1.0)
	_page_scroll.position.x = width if forward else -width
	var slide := create_tween().set_parallel(true)
	slide.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(_page_scroll, "position:x", 0.0, SLIDE_SECONDS)
	slide.tween_property(old, "position:x", -width if forward else width, SLIDE_SECONDS)
	slide.chain().tween_callback(old.queue_free)


## Tienda, con un grupo de piezas ("" = el del hueco elegido).
func show_store(group: String) -> void:
	_store_group = group if group != "" else ArmoryPages.group_of(Garage.slot_type(_selected))
	show_page("tienda")


func current_page() -> String:
	return _page


func _new_page() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Soltar aqui una pieza montada la quita.
	scroll.set_drag_forwarding(
		Callable(),
		func(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and data.has("from_slot"),
		func(_at: Vector2, data: Variant) -> void: clear_slot(data["from_slot"])
	)
	_pages.add_child(scroll)
	_page_box = VBoxContainer.new()
	_page_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_box.add_theme_constant_override("separation", 5)
	scroll.add_child(_page_box)
	return scroll


func _fill_page() -> void:
	for child in _page_box.get_children():
		child.queue_free()
	match _page:
		"pieza":
			_fill_part_page(_page_box)
		"tienda":
			ArmoryPages.store(self, _page_box, _store_group)
		"mejoras":
			ArmoryPages.upgrades(self, _page_box)
		"habilidades":
			ArmoryPages.skills(self, _page_box)


# --- Acciones ----------------------------------------------------------------


## Elige un hueco: se marca en el mech y a la derecha salen sus piezas.
func pick(slot: String) -> void:
	if slot == "" or not slot in _cells:
		return
	_selected = slot
	_hover_id = ""
	refresh()


## Monta una pieza en el hueco elegido.
func equip_selected(id: String) -> void:
	equip(_selected, id)


func equip(slot: String, id: String) -> void:
	if _lock_reason(slot, main._player_level()) != "":
		return
	if Garage.equip(main._profile, main._catalog, slot, id) != "":
		return
	_selected = slot
	_hover_id = ""
	main._save()
	Sfx.play("taller_montar")
	refresh()
	var item := _resolved(id)
	if item != null:
		_stage.flash(slot, SlotCell.TIER_COLORS[item.tier])


## Deja un hueco vacio.
func clear_slot(slot: String) -> void:
	if Garage.get_slot(main._profile.build, slot) == "":
		return
	Garage.equip(main._profile, main._catalog, slot, "")
	_selected = slot
	main._save()
	Sfx.play("taller_quitar")
	refresh()


func level_up_selected() -> void:
	var item := _resolved(Garage.get_slot(main._profile.build, _selected))
	if item == null:
		return
	var cap := main._campaign.level_cap(main._profile.zone)
	var key := item.progress_id()
	if main._profile.level_up(main._workshop, main._rules, key, main._zone_tier(), cap) != "":
		return
	main._save()
	Sfx.play("ui_subir_nivel")
	refresh()
	_stage.flash(_selected, SlotCell.TIER_COLORS[item.tier])


func transform_selected() -> void:
	var item := _resolved(Garage.get_slot(main._profile.build, _selected))
	if item == null:
		return
	var item_max := main._catalog.get_item(item.id).tier_max
	var key := item.progress_id()
	var reason := main._profile.transform(
		main._workshop, main._rules, key, main._zone_tier(), item_max
	)
	if reason != "":
		return
	main._save()
	Sfx.play("ui_transformar")
	refresh()
	var now := _resolved(item.id)
	_stage.flash(_selected, SlotCell.TIER_COLORS[now.tier])


## Compra una pieza de la tienda. Si el hueco donde iria esta vacio, la
## monta; si no, queda en tus piezas.
func buy(id: String) -> void:
	if not _pay(id):
		return
	var slot := _slot_for(id)
	if slot != "" and Garage.get_slot(main._profile.build, slot) == "":
		equip(slot, id)
	else:
		refresh()


func _pay(id: String) -> bool:
	var tier := main._zone_tier()
	if main._garage.buy(main._profile, main._catalog, main._rules, main._workshop, id, tier) != "":
		return false
	Sfx.play("ui_comprar")
	main._save()
	return true


## Hueco donde iria una pieza: el elegido si le cabe, o el primero libre de su
## tipo que tu nivel ya abra.
func _slot_for(id: String) -> String:
	var locked: Array[String] = []
	for slot: String in _cells:
		if _lock_reason(slot, main._player_level()) != "":
			locked.append(slot)
	return Garage.drop_slot(main._profile.build, main._catalog, id, _selected, locked)


## Sube una de las mejoras permanentes (la armeria), con el tope de la zona.
func buy_upgrade(track: String) -> void:
	if main._profile.buy(main._shop, track, main._armory_cap()) != "":
		return
	Sfx.play("ui_comprar")
	main._save()
	refresh()


## Aprende la siguiente habilidad de una rama.
func learn(id: String) -> void:
	if main._skills.learn(main._profile, id, main._player_level()) != "":
		return
	Sfx.play("ui_habilidad")
	main._save()
	refresh()


## Una pieza de la tienda elegida: se marca en el mech el hueco donde iria.
func focus_item(id: String) -> void:
	var slot := _slot_for(id)
	if slot == "":
		return
	_selected = slot
	refresh()


## Dispara el arma del hueco elegido contra la diana.
func test_fire() -> void:
	var item := _resolved(Garage.get_slot(main._profile.build, _selected))
	if item == null or item.fx == "":
		return
	_stage.test_fire(_selected, item.fx, ShotFx.ammo_color(item.element))


func _on_cell_dropped(slot: String, data: Dictionary) -> void:
	if data.get("buy", false) and not _pay(data["id"]):
		return
	var from: String = data.get("from_slot", "")
	if from != "":
		# De un hueco a otro de su tipo: se cambian.
		var other := Garage.get_slot(main._profile.build, slot)
		Garage.equip(main._profile, main._catalog, from, other)
	equip(slot, data["id"])


func _on_stage_dropped(data: Dictionary) -> void:
	var slot := _slot_for(data["id"])
	if slot == "":
		return
	if data.get("buy", false) and not _pay(data["id"]):
		return
	equip(slot, data["id"])


## Pasar el raton por una pieza: el resumen ensena cuanto cambia el mech con
## ella en el hueco donde iria, y ese hueco se marca en el dibujo.
func hover_item(id: String, inside: bool) -> void:
	_hover_id = id if inside else ""
	_hover_slot = _slot_for(id) if inside else ""
	_stage.hover_slot = _hover_slot
	_refresh_summary(_build_from(main._profile.build))


func _on_cell_hovered(slot: String, inside: bool) -> void:
	_stage.hover_slot = slot if inside else ""


# --- Textos ------------------------------------------------------------------


## Nombre de un hueco: "Lateral 1", "Torso"...
static func slot_title(slot: String) -> String:
	var base := slot.rstrip("0123456789")
	var digits := slot.trim_prefix(base)
	var number := " %d" % (int(digits) + 1) if digits != "" else ""
	return Txt.t("slot_" + base) + number


## Lo que hace una pieza, en una linea (o en varias con `long`).
static func item_stats(item: ItemDef, long: bool) -> String:
	var parts: Array[String] = []
	if item.deals_damage():
		parts.append(Txt.t("stat_damage", [item.dmg_min, item.dmg_max]))
		parts.append(Txt.t("range", [item.range_min, item.range_max]))
		if item.energy_cost > 0:
			parts.append(Txt.t("cost_energy", [item.energy_cost]))
		if item.heat_cost > 0:
			parts.append(Txt.t("cost_heat", [item.heat_cost]))
		if item.uses > 0:
			parts.append(Txt.t("uses", [item.uses]))
	for key in ["health", "energy_cap", "energy_regen", "heat_cap", "cooling"]:
		var value: int = item.get(key)
		if value != 0:
			parts.append("%s %+d" % [Txt.t("stat_" + key), value])
	var res := [item.res_physical, item.res_heat, item.res_energy]
	if res.max() > 0:
		parts.append("%s %d/%d/%d" % [Txt.t("resist"), res[0], res[1], res[2]])
	if item.weight > 0:
		parts.append(Txt.t("stat_weight", [item.weight]))
	return ("\n" if long else " · ").join(parts)


func _label(parent: Node, text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
