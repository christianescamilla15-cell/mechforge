extends Control
## Punto de entrada: la base del jugador (GDD 9). Desde aqui se entra a la
## campana (los combates de la zona y su jefe), a la arena (para juntar
## celdas) y a la armeria (mejoras permanentes). Hay ademas un combate libre,
## sin recompensa, para probar cualquier cruce.
##
## Prueba en vivo automatica (tools/live.ps1): con `++ --autoplay` la IA juega
## por los dos lados en la ventana real, guarda capturas y cierra el juego.
## Con --ui, el lado del jugador actua a traves de los controles de la
## interfaz (prevision, botones y casillas), como lo haria una persona.
##   --player=<id> --enemy=<id> --tier=EPIC --seed=1 --speed=3
##   --fight=<n>  en vez de --enemy y --tier: el combate n de la primera zona,
##                contando desde 0 (el ultimo es el jefe); --level=<n> pone las
##                piezas del jugador en ese nivel de la clase Basica
## Con `++ --menu-shot` guarda una captura del menu con un perfil de muestra
## (--menu-shot=jefe: delante del jefe) y sale.
## La carpeta de capturas se indica en la variable de entorno MECHFORGE_SHOTS.

const SAVE_PATH := "user://save.json"
const MENU_DIFFICULTIES: Array[BattleAI.Difficulty] = [
	BattleAI.Difficulty.EASY, BattleAI.Difficulty.NORMAL, BattleAI.Difficulty.HARD
]
const DIFFICULTY_IDS: Array[String] = ["EASY", "NORMAL", "HARD"]
const AUTOPLAY_TIMEOUT_SECONDS := 180.0
const COLOR_CELLS := Color("7fe3ff")
const COLOR_WARNING := Color("ff9a7d")
const COLOR_MUTED := Color("9aa7b8")

var _rules := RulesConfig.new()
var _stages := StageLibrary.load_file("res://data/stages.json")
var _chassis := ChassisLibrary.load_file("res://data/chassis.json")
var _shop := ArenaShop.load_file("res://data/arena_shop.json")
var _workshop := Workshop.load_file("res://data/workshop.json")
var _garage := Garage.load_file("res://data/part_shop.json")
var _progression := Progression.load_file("res://data/progression.json")
## Celdas, mejoras, avance e historial del jugador.
var _profile := PlayerProfile.new()
## Las pruebas automaticas no tocan el guardado del jugador.
var _persist := false
## Lo ultimo que paso, para contarlo en el menu.
var _last_result := ""
## Para ir cambiando de escenario de un combate al siguiente.
var _stage_seed: int = 0
var _catalog: Catalog
var _library: BuildLibrary
var _campaign: Campaign
var _menu: Control
var _battle: BattleScreen
var _pickers: Dictionary = {}
## Lo elegido en el combate libre, para conservarlo al volver al menu.
var _last: Dictionary = {}
## Combate en curso: {"mode" ("campaign", "arena" o "free"), "items" (el
## mech del jugador, formato de builds.json), "name", "enemy", "enemy_tier",
## "enemy_level", "difficulty", "seed"} y, en el combate libre, "player_tier"
## y "player_level". En la campana y la arena el jugador pelea con la clase y
## el nivel de sus piezas (PlayerProfile.parts).
var _spec: Dictionary = {}
var _args: Dictionary = {}
var _shot_count: int = 0
var _shot_events: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# En el juego la nave deja bonificaciones en la arena (GDD 2.8).
	_rules.drops_enabled = true
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_campaign = Campaign.load_file("res://data/campaign.json", _library)
	if _args.has("showcase"):
		# Muestra de movimientos para revisar animaciones (tools/clip.ps1 -Showcase).
		var showcase := MovesShowcase.new()
		showcase.rules = _rules
		showcase.catalog = _catalog
		showcase.library = _library
		showcase.stages = _stages
		showcase.finished.connect(func() -> void: get_tree().quit(0))
		add_child(showcase)
	elif _args.has("autoplay"):
		_start_autoplay()
	elif _args.has("menu-shot"):
		# Prueba en vivo del menu: perfil de muestra, captura y salir.
		_profile.start_run(_library, _library.ids()[0])
		_profile.gold = 1500
		_profile.shop_levels = {"damage": 3, "health": 10}
		_profile.parts = {"torso_baluarte": {"tier": 0, "level": 3}}
		_profile.parts["hoja_balas_cin"] = {"tier": 0, "level": 3}
		_last["tab"] = 1
		_profile.wins = 12
		_profile.fight = 4
		if _args["menu-shot"] == "nuevo":
			_profile = PlayerProfile.new()
		elif _args["menu-shot"] == "tienda":
			_last["tab"] = 2
		if _args["menu-shot"] == "jefe":
			_profile.fight = _campaign.fights_in(0)
		_show_menu()
		await get_tree().create_timer(0.6).timeout
		await _shot("menu")
		get_tree().quit(0)
	else:
		_profile = PlayerProfile.load_or_new(SAVE_PATH)
		_persist = true
		_show_menu()


# --- Menu --------------------------------------------------------------------


func _show_menu() -> void:
	if _battle != null:
		_battle.queue_free()
		_battle = null
	if _menu != null:
		_menu.queue_free()
	_pickers.clear()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_menu = margin
	add_child(_menu)
	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 40)
	_menu.add_child(columns)

	var left := _column(columns, 560)
	var title := _text(left, Txt.t("menu_title"), 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not _profile.has_mech():
		_add_starters(left)
	else:
		var can_fight := _add_mech_status(left)
		_add_campaign(left, can_fight)
		_add_arena(left, can_fight)
		_add_free_fight(left)
	_add_shop(_column(columns, 520))


func _column(parent: Control, width: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	return box


func _text(parent: Control, text: String, font_size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if color != Color.WHITE:
		label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, height: int, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


## Campana: el combate que toca en la zona, o su jefe cuando ya se ganaron
## todos los normales.
## Partida nueva: el jugador elige su primer mech entre los de ejemplo.
func _add_starters(box: VBoxContainer) -> void:
	_text(box, Txt.t("starter_title"), 20)
	_text(box, Txt.t("starter_info"), 16, COLOR_MUTED)
	for id in _library.starter_ids():
		var label := Txt.t("starter_pick", [_library.display_name(id), _element_name(id)])
		_button(box, label, 44, _on_starter_picked.bind(id))


func _element_name(id: String) -> String:
	var element := _library.element_of(id)
	if element == "HYBRID":
		return Txt.t("element_hybrid")
	return Txt.ELEMENT_NAMES[ItemDef.Element[element]]


## Mech armado del jugador, con su peso y lo que le impide pelear. Devuelve
## si puede pelear.
func _add_mech_status(box: VBoxContainer) -> bool:
	var build := _player_build()
	var problems := build.validate(_rules)
	var line := Txt.t("mech_weight", [build.total_weight(), _rules.max_weight])
	_text(box, "%s · %s" % [Txt.t("menu_player"), line], 16)
	var next := _progression.next_level_xp(_profile.xp)
	var level_line := Txt.t("player_level", [_player_level(), _profile.xp])
	if next >= 0:
		level_line += Txt.t("player_next", [next])
	_text(box, level_line, 15, COLOR_MUTED)
	if not problems.is_empty():
		_text(box, Txt.t("mech_problems", [", ".join(problems)]), 14, COLOR_WARNING)
	return problems.is_empty()


func _add_campaign(box: VBoxContainer, can_fight: bool) -> void:
	_text(box, Txt.t("menu_campaign"), 20)
	var zone := _profile.zone
	if _campaign.is_complete(_profile):
		_text(box, Txt.t("campaign_won", [_campaign.world_bosses]), 16, COLOR_CELLS)
		return
	if zone >= _campaign.zone_count():
		_text(box, Txt.t("campaign_pending", [zone + 1, _campaign.world_bosses]), 16, COLOR_MUTED)
		return
	_text(
		box,
		Txt.t("campaign_zone", [zone + 1, _campaign.world_bosses, _campaign.zone_name(zone)]),
		16,
		COLOR_MUTED
	)
	var fight := _campaign.fight_at(zone, _profile.fight)
	var rival := _library.display_name(fight["enemy"])
	if _campaign.is_boss_fight(zone, _profile.fight):
		_text(box, Txt.t("campaign_boss", [rival]))
		var ability := _boss_ability(fight["enemy"])
		if ability != "":
			_text(box, ability, 14, COLOR_MUTED)
		_button(box, Txt.t("campaign_boss_fight"), 46, _on_campaign_pressed).disabled = not can_fight
		if _campaign.on_boss_loss == "new_game":
			_text(box, Txt.t("campaign_boss_warning"), 14, COLOR_WARNING)
	else:
		var count := _campaign.fights_in(zone)
		_text(box, Txt.t("campaign_next", [_profile.fight + 1, count, rival]))
		var fight_button := _button(
			box, Txt.t("campaign_fight", [_profile.fight + 1]), 46, _on_campaign_pressed
		)
		fight_button.disabled = not can_fight


## Arena: combates sueltos contra un rival al azar, para juntar celdas.
func _add_arena(box: VBoxContainer, can_fight: bool) -> void:
	_text(box, Txt.t("menu_arena"), 20)
	_text(
		box,
		(
			Txt
			. t(
				"arena_info",
				[
					roundi(_shop.reward("arena_win") * _campaign.reward_mult(_profile.zone)),
					roundi(_shop.reward("arena_loss") * _campaign.reward_mult(_profile.zone)),
				]
			)
		),
		16,
		COLOR_MUTED
	)
	_button(box, Txt.t("arena_fight"), 46, _on_arena_pressed).disabled = not can_fight


## Combate libre: cualquier rival, en cualquier clase. No da ni quita nada.
func _add_free_fight(box: VBoxContainer) -> void:
	_text(box, Txt.t("menu_free"), 20)
	var enemy_names: Array[String] = []
	for id in _library.all_ids():
		enemy_names.append(_library.display_name(id))
	var difficulty_names: Array[String] = [
		Txt.t("difficulty_easy"), Txt.t("difficulty_normal"), Txt.t("difficulty_hard")
	]
	_add_picker(box, "enemy", Txt.t("menu_enemy"), enemy_names, _last.get("enemy", 1))
	_add_picker(box, "tier", Txt.t("menu_tier"), Txt.TIER_NAMES, _last.get("tier", 2))
	_add_picker(
		box, "difficulty", Txt.t("menu_difficulty"), difficulty_names, _last.get("difficulty", 1)
	)
	_button(box, Txt.t("menu_free_fight"), 36, _on_free_pressed)


## Armeria (GDD 8): celdas, historial y, en dos pestanas, las mejoras
## permanentes y las piezas del mech, que se suben de nivel y se transforman.
func _add_shop(box: VBoxContainer) -> void:
	_text(box, Txt.t("menu_shop"), 26).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cells := _text(box, Txt.t("menu_gold", [_profile.gold]), 24, COLOR_CELLS)
	cells.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _profile.unique_cores > 0:
		var cores := _text(box, Txt.t("menu_cores", [_profile.unique_cores]), 18, COLOR_CELLS)
		cores.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var record := Txt.t(
		"menu_record", [_profile.wins, _profile.losses, _profile.boss_wins, _campaign.world_bosses]
	)
	if _profile.runs_lost > 0:
		record += "\n" + Txt.t("menu_runs", [_profile.runs_lost, _profile.best_boss_wins])
	if _last_result != "":
		record = "%s\n%s" % [_last_result, record]
	_text(box, record, 15, COLOR_MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 400)
	box.add_child(tabs)
	var upgrades := VBoxContainer.new()
	upgrades.name = Txt.t("shop_tab_upgrades")
	tabs.add_child(upgrades)
	_add_upgrades(upgrades)
	if _profile.has_mech():
		_add_parts(_scroll_tab(tabs, Txt.t("shop_tab_parts")))
		_add_store(_scroll_tab(tabs, Txt.t("shop_tab_store")))
	tabs.current_tab = _last.get("tab", 0)
	tabs.tab_changed.connect(func(tab: int) -> void: _last["tab"] = tab)


## Pestana con barra de desplazamiento; devuelve la caja donde van las filas.
func _scroll_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


## Mejoras permanentes de la armeria: seis lineas en 10 niveles.
func _add_upgrades(box: VBoxContainer) -> void:
	for track in _shop.track_ids():
		var level := _profile.level_of(track)
		var label := Txt.t(
			"shop_row",
			[_shop.display_name(track), level, _shop.max_level(), _shop_value(track, level)]
		)
		var buy := _shop_row(box, label)
		if level >= _shop.max_level():
			buy.text = Txt.t("shop_max")
			buy.disabled = true
		else:
			buy.text = Txt.t("shop_buy", [_shop.price(level + 1)])
			buy.disabled = _profile.why_cant_buy(_shop, track) != ""
		buy.pressed.connect(_on_buy_pressed.bind(track))


## Taller (GDD 4 y 8): cada hueco del mech con la pieza montada, que se cambia
## por otra que el jugador tenga, y su clase y nivel. Cada pieza sube de nivel
## por separado y, al maximo de su clase, se transforma si la zona lo permite.
func _add_parts(box: VBoxContainer) -> void:
	var max_tier := _zone_tier()
	var cap_level := _campaign.level_cap(_profile.zone)
	for slot in Garage.SLOTS:
		var row := HBoxContainer.new()
		box.add_child(row)
		var name_label := Label.new()
		name_label.text = Txt.t("slot_" + slot.rstrip("0123456789")) + _slot_number(slot)
		name_label.custom_minimum_size = Vector2(96, 0)
		row.add_child(name_label)
		var current := Garage.get_slot(_profile.build, slot)
		var unlocked := _progression.is_unlocked(slot, _player_level())
		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(190, 0)
		# Ancho fijo: los nombres largos se recortan en vez de empujar la fila.
		picker.fit_to_longest_item = false
		picker.clip_text = true
		picker.add_item(Txt.t("slot_empty"))
		var options := Garage.owned_for(_profile, _catalog, slot)
		for id in options:
			picker.add_item(_catalog.get_item(id).display_name)
		picker.select(options.find(current) + 1)
		picker.item_selected.connect(_on_slot_picked.bind(slot, options))
		picker.disabled = not unlocked
		row.add_child(picker)
		var level_label := Label.new()
		level_label.custom_minimum_size = Vector2(96, 0)
		level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(level_label)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(130, 0)
		row.add_child(buy)
		if not unlocked:
			level_label.text = Txt.t("slot_locked", [_progression.unlock_level(slot)])
			buy.text = "—"
			buy.disabled = true
			continue
		if current == "":
			buy.text = "—"
			buy.disabled = true
			continue
		var p := _profile.part(current)
		var top := _rules.tier_max_level[p["tier"]]
		level_label.text = Txt.t("part_level", [Txt.TIER_NAMES[p["tier"]], p["level"], top])
		_set_part_button(buy, current, p, max_tier, cap_level)


func _slot_number(slot: String) -> String:
	var digits := slot.trim_prefix(slot.rstrip("0123456789"))
	return " %d" % (int(digits) + 1) if digits != "" else ""


## Boton de una pieza: subir de nivel, transformar o el tope que la para.
func _set_part_button(
	buy: Button, id: String, p: Dictionary, max_tier: int, cap_level: int
) -> void:
	if p["level"] < _rules.tier_max_level[p["tier"]]:
		var level_reason := _profile.why_cant_level(_workshop, _rules, id, max_tier, cap_level)
		if level_reason == "la zona no deja subirla mas":
			buy.text = Txt.t("part_zone_max")
			buy.disabled = true
			return
		buy.text = Txt.t("part_level_up", [_workshop.level_cost(_rules, p["tier"], p["level"])])
		buy.disabled = level_reason != ""
		buy.pressed.connect(_on_part_level.bind(id, max_tier, cap_level))
		return
	var item_max := _catalog.get_item(id).tier_max
	var reason := _profile.why_cant_transform(_workshop, _rules, id, max_tier, item_max)
	if reason in ["", "faltan celdas"]:
		buy.text = Txt.t("part_transform", [_workshop.transform_cost(p["tier"])])
		if p["tier"] == ItemDef.Tier.MYTHIC:
			buy.text = Txt.t("part_unique")
		buy.disabled = reason != ""
		buy.pressed.connect(_on_part_transform.bind(id, max_tier, item_max))
		return
	var zone_cap := reason == "la clase siguiente se abre en otra zona"
	buy.text = Txt.t("part_zone_max" if zone_cap else "shop_max")
	buy.disabled = true
	buy.tooltip_text = reason


## Tienda de piezas: lo que se vende en la clase de la zona. Una pieza nueva
## llega en esa clase al nivel 0.
func _add_store(box: VBoxContainer) -> void:
	var zone_tier := _zone_tier()
	_text(box, Txt.t("store_info", [Txt.TIER_NAMES[zone_tier]]), 14, COLOR_MUTED)
	for id in _garage.stock_for(_catalog, zone_tier):
		var def := _catalog.get_item(id)
		var label := Txt.t(
			"store_row", [def.display_name, Txt.t("type_" + ItemDef.Type.keys()[def.type])]
		)
		var buy := _shop_row(box, label)
		if id in _profile.owned:
			buy.text = Txt.t("store_owned")
			buy.disabled = true
			continue
		buy.text = Txt.t("store_buy", [_garage.price(_catalog, _rules, _workshop, id, zone_tier)])
		var reason := _garage.why_cant_buy(_profile, _catalog, _rules, _workshop, id, zone_tier)
		buy.disabled = reason != ""
		buy.pressed.connect(_on_store_buy.bind(id, zone_tier))


## Clase de la zona en la que esta el jugador.
func _zone_tier() -> int:
	return _campaign.tier_of(mini(_profile.zone, _campaign.zone_count() - 1))


## Una linea de la armeria: texto a la izquierda y boton de compra.
func _shop_row(box: VBoxContainer, text: String) -> Button:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(150, 0)
	row.add_child(buy)
	return buy


## Lo que da una mejora a ese nivel, como texto: "+5 %" o "+123".
func _shop_value(track: String, level: int) -> String:
	var amount := _shop.value(track, level)
	if _shop.tracks[track]["kind"] == "percent":
		return "+%d %%" % roundi(amount * 100.0)
	return "+%d" % roundi(amount)


func _add_picker(
	box: VBoxContainer, key: String, title: String, items: Array[String], selected: int
) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items:
		picker.add_item(item)
	picker.select(clampi(selected, 0, items.size() - 1))
	row.add_child(picker)
	_pickers[key] = picker


## Habilidad especial de un jefe, como texto para el menu; "" si no tiene.
func _boss_ability(id: String) -> String:
	var def := _chassis.get_def(_library.chassis_of(id))
	if def == null or def.ability == "":
		return ""
	return Txt.t("campaign_boss_ability", [def.ability, def.ability_text])


## Nombre del mech del jugador: el del mech con el que empezo.
func _player_name() -> String:
	return _library.display_name(_profile.mech) if _library.specs.has(_profile.mech) else ""


func _save() -> void:
	if _persist:
		_profile.save(SAVE_PATH)


func _remember_picks() -> void:
	for key: String in ["enemy", "tier", "difficulty"]:
		if _pickers.has(key):
			_last[key] = (_pickers[key] as OptionButton).selected


func _on_starter_picked(id: String) -> void:
	_profile.start_run(_library, id)
	_save()
	_show_menu()


func _on_slot_picked(index: int, slot: String, options: Array[String]) -> void:
	var id := options[index - 1] if index > 0 else ""
	if Garage.equip(_profile, _catalog, slot, id) == "":
		_save()
	_remember_picks()
	_show_menu.call_deferred()


func _on_store_buy(id: String, zone_tier: int) -> void:
	if _garage.buy(_profile, _catalog, _rules, _workshop, id, zone_tier) == "":
		_save()
	_remember_picks()
	_show_menu()


## Mech armado del jugador con la clase y el nivel de cada pieza, sin lo que
## va en huecos que su nivel aun no abre.
func _player_build() -> MechBuild:
	var build := _catalog.make_build(_profile.build, _rules, ItemDef.Tier.COMMON, 0, _profile.parts)
	_progression.apply_locks(build, _player_level())
	return build


func _player_level() -> int:
	return _progression.level_for(_profile.xp)


## Piezas distintas del mech armado del jugador.
func _player_items() -> Array[String]:
	return BuildLibrary.items_of(_profile.build)


func _on_buy_pressed(track: String) -> void:
	if _profile.buy(_shop, track) == "":
		_save()
	_remember_picks()
	_show_menu()


func _on_part_level(id: String, cap_tier: int, cap_level: int) -> void:
	if _profile.level_up(_workshop, _rules, id, cap_tier, cap_level) == "":
		_save()
	_remember_picks()
	_show_menu()


func _on_part_transform(id: String, max_tier: int, item_max: int) -> void:
	if _profile.transform(_workshop, _rules, id, max_tier, item_max) == "":
		_save()
	_remember_picks()
	_show_menu()


func _on_campaign_pressed() -> void:
	var zone := _profile.zone
	var spec := _spec_for("campaign", zone, _campaign.fight_at(zone, _profile.fight))
	if not _campaign.is_boss_fight(zone, _profile.fight) or _campaign.on_boss_loss != "new_game":
		_start_battle(spec)
		return
	# Perder contra el jefe borra la partida: se avisa antes de entrar.
	var dialog := ConfirmationDialog.new()
	dialog.title = Txt.t("campaign_boss_fight")
	dialog.dialog_text = Txt.t("campaign_boss_confirm", [_library.display_name(spec["enemy"])])
	dialog.ok_button_text = Txt.t("campaign_boss_yes")
	dialog.cancel_button_text = Txt.t("campaign_boss_no")
	dialog.confirmed.connect(_start_battle.bind(spec))
	_menu.add_child(dialog)
	dialog.popup_centered()


func _on_arena_pressed() -> void:
	var zone := mini(_profile.zone, _campaign.zone_count() - 1)
	var power := Campaign.mean_power(_rules, _profile, _player_items())
	var fight := _campaign.arena_fight(zone, _library, randi(), _rules, power)
	_start_battle(_spec_for("arena", zone, fight))


func _on_free_pressed() -> void:
	_remember_picks()
	var tier: ItemDef.Tier = ItemDef.Tier.values()[_last["tier"]]
	var level := _rules.tier_max_level[tier]
	_start_battle(
		{
			"mode": "free",
			"items": _profile.build,
			"name": _player_name(),
			"enemy": _library.all_ids()[_last["enemy"]],
			"enemy_tier": tier,
			"enemy_level": level,
			"player_tier": tier,
			"player_level": level,
			"difficulty": _last["difficulty"],
			"seed": randi(),
		}
	)


## Combate de la campana o de la arena: el rival va en la clase de la zona (o
## en la que diga el combate) y el jugador con sus piezas.
func _spec_for(mode: String, zone: int, fight: Dictionary) -> Dictionary:
	return {
		"mode": mode,
		"zone": zone,
		"items": _profile.build,
		"name": _player_name(),
		"enemy": fight["enemy"],
		"enemy_tier": int(fight.get("tier", _campaign.tier_of(zone))),
		"enemy_level": int(fight["level"]),
		"difficulty": DIFFICULTY_IDS.find(fight["difficulty"]),
		"seed": randi(),
	}


# --- Combate -----------------------------------------------------------------


func _start_battle(spec: Dictionary) -> void:
	_spec = spec
	_remember_picks()
	if _menu != null:
		_menu.queue_free()
		_menu = null
	if _battle != null:
		_battle.queue_free()
	var rewarded: bool = spec["mode"] != "free"
	_battle = BattleScreen.new()
	# El escenario se puede pedir con --stage=<id>; en la campana y la arena es
	# el de la zona; si no, sale de la semilla.
	_battle.stage = _stages.get_stage(str(_args.get("stage", "")))
	if _battle.stage.is_empty() and spec.has("zone"):
		_battle.stage = _stages.get_stage(_campaign.stage_of(spec["zone"]))
	if _battle.stage.is_empty():
		_battle.stage = _stages.pick(_stage_seed)
	_stage_seed += 1
	_battle.names = [
		"%s · %s" % [Txt.t("you"), spec["name"]] if spec["name"] != "" else Txt.t("you"),
		"%s · %s" % [Txt.t("rival"), _library.display_name(spec["enemy"])],
	]
	# En la campana no hay revancha: se vuelve a la base y se decide de nuevo.
	_battle.allow_rematch = spec["mode"] != "campaign"
	if spec["mode"] == "arena":
		_battle.rematch_text = Txt.t("arena_again")
	_battle.rematch_requested.connect(_on_rematch)
	_battle.menu_requested.connect(_show_menu)
	if rewarded:
		_battle.finished.connect(_on_battle_finished)
	add_child(_battle)
	var player_build: MechBuild
	if rewarded:
		player_build = _catalog.make_build(
			spec["items"], _rules, ItemDef.Tier.COMMON, 0, _profile.parts
		)
		_progression.apply_locks(player_build, _player_level())
	else:
		var player_tier: ItemDef.Tier = spec["player_tier"]
		player_build = _catalog.make_build(spec["items"], _rules, player_tier, spec["player_level"])
	# Las mejoras de la armeria solo cuentan para el mech del jugador.
	if rewarded:
		player_build.upgrades = _shop.upgrades_for(_profile.shop_levels)
	_battle.start(
		_rules,
		player_build,
		_library.make(
			spec["enemy"], _catalog, _rules, spec["enemy_tier"], spec["enemy_level"], _chassis
		),
		spec["seed"],
		MENU_DIFFICULTIES[spec["difficulty"]]
	)


func _on_rematch() -> void:
	if _spec["mode"] == "arena":
		_on_arena_pressed()
		return
	_spec["seed"] = randi()
	_start_battle(_spec)


## Al terminar un combate de campana o de arena el jugador cobra, avanza o,
## si perdio contra un jefe, pierde la partida. Se guarda el progreso.
func _on_battle_finished(player_won: bool) -> void:
	var result := _campaign.finish_fight(_profile, _shop, _spec["mode"], player_won, _progression)
	_save()
	if result["game_over"]:
		_last_result = Txt.t("result_game_over")
	elif result["unique"]:
		_last_result = Txt.t("result_unique", [result["gold"]])
	elif result["zone_cleared"]:
		_last_result = Txt.t("result_zone_cleared", [result["gold"]])
	else:
		_last_result = Txt.t("result_reward", [result["gold"]])
	if result["level_up"]:
		_last_result += "\n" + Txt.t("result_level_up", [_player_level()])
	_battle.set_result_note(_last_result)


# --- Prueba en vivo automatica -----------------------------------------------


func _start_autoplay() -> void:
	print("AUTOPLAY argumentos: %s" % _args)
	var ids := _library.all_ids()
	var tier: ItemDef.Tier = ItemDef.Tier[_args.get("tier", "EPIC")]
	var level := _rules.tier_max_level[tier]
	var spec := {
		"mode": "free",
		"player": _args.get("player", ids[0]),
		"items": {},
		"name": "",
		"enemy": _args.get("enemy", ids[1]),
		"enemy_tier": tier,
		"enemy_level": level,
		"player_tier": tier,
		"player_level": level,
		"difficulty": 1,
		"seed": int(_args.get("seed", "1")),
	}
	if _args.has("fight"):
		# Un combate de la primera zona de la campana, con sus niveles y su
		# recompensa, sobre un perfil vacio que no se guarda.
		_profile.fight = int(_args["fight"])
		var fight := _campaign.fight_at(0, _profile.fight)
		spec["mode"] = "campaign"
		spec["zone"] = 0
		_profile.parts = _uniform_parts(spec["player"], int(_args.get("level", "0")))
		spec["enemy"] = fight["enemy"]
		spec["enemy_tier"] = _campaign.tier_of(0)
		spec["enemy_level"] = int(fight["level"])
		spec["difficulty"] = DIFFICULTY_IDS.find(fight["difficulty"])
	for side: String in ["player", "enemy"]:
		if not spec[side] in ids:
			spec[side] = ids[0]
	spec["items"] = _library.specs[spec["player"]]["items"]
	spec["name"] = _library.display_name(spec["player"])
	_start_battle(spec)
	var driver := BattleAI.new(BattleAI.Difficulty.NORMAL, int(spec["seed"]) + 7)
	if _args.has("ui"):
		# El jugador actua a traves de los controles de la interfaz.
		_battle.ui_driver = driver
		_battle.preview_shown.connect(_on_autoplay_preview)
	else:
		_battle.player_ai = driver
	_battle.speed = float(_args.get("speed", "3"))
	_battle.event_played.connect(_on_autoplay_event)
	_battle.finished.connect(_on_autoplay_finished)
	get_tree().create_timer(0.8).timeout.connect(_shot.bind("inicio"))
	get_tree().create_timer(AUTOPLAY_TIMEOUT_SECONDS).timeout.connect(_on_autoplay_timeout)


## Piezas de un mech todas en clase Basica y ese nivel (para la prueba en vivo).
func _uniform_parts(mech: String, level: int) -> Dictionary[String, Dictionary]:
	var out: Dictionary[String, Dictionary] = {}
	if not _library.specs.has(mech):
		return out
	for id in _library.item_ids(mech):
		out[id] = {"tier": ItemDef.Tier.COMMON, "level": level}
	return out


func _on_autoplay_event(entry: Dictionary) -> void:
	# Una captura la primera vez que pasa cada cosa interesante.
	var event: String = entry["event"]
	if entry.get("shielded", false) and not _shot_events.has("shielded"):
		_shot_events["shielded"] = true
		_shot("escudo")
	if (
		event
		in [
			"weapon",
			"drone",
			"forced_cool",
			"shutdown",
			"charge",
			"hook",
			"teleport",
			"drop_spawn",
			"drop_taken",
			"repair",
			"evade"
		]
	):
		if not _shot_events.has(event):
			_shot_events[event] = true
			_shot(event)


func _on_autoplay_preview() -> void:
	# Capturas de las tres primeras previsiones (resaltado de casillas incluido).
	var count: int = _shot_events.get("preview", 0)
	if count < 3:
		_shot_events["preview"] = count + 1
		await get_tree().create_timer(0.1).timeout
		_shot("prevision")


func _on_autoplay_finished(player_won: bool) -> void:
	print(
		(
			"AUTOPLAY fin: gana %s en %d turnos"
			% ["el jugador" if player_won else "el rival", _battle.engine.turn_number]
		)
	)
	await get_tree().create_timer(0.4).timeout
	await _shot("final")
	get_tree().quit(0)


func _on_autoplay_timeout() -> void:
	printerr("AUTOPLAY: tiempo agotado")
	get_tree().quit(1)


func _shot(label: String) -> void:
	# La carpeta llega por variable de entorno: PowerShell parte en dos los
	# argumentos con "C:" al pasarlos de un script a otro.
	var folder: String = _args.get("shots", "")
	if folder == "":
		folder = OS.get_environment("MECHFORGE_SHOTS")
	if folder == "":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [folder, _shot_count, label]
	_shot_count += 1
	var error := image.save_png(path)
	print("AUTOPLAY captura %s (%s)" % [path, "ok" if error == OK else "error %d" % error])
