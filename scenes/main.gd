extends Control
## Punto de entrada. Muestra un menu minimo para lanzar un combate de prueba
## contra la IA con los mechs de data/builds.json.
##
## Prueba en vivo automatica (tools/live.ps1): con `++ --autoplay` la IA juega
## por los dos lados en la ventana real, guarda capturas y cierra el juego.
## Con --ui, el lado del jugador actua a traves de los controles de la
## interfaz (prevision, botones y casillas), como lo haria una persona.
##   --player=<id> --enemy=<id> --tier=EPIC --seed=1 --speed=3
## La carpeta de capturas se indica en la variable de entorno MECHFORGE_SHOTS.

const SAVE_PATH := "user://save.json"
const MENU_TIERS: Array[ItemDef.Tier] = [
	ItemDef.Tier.COMMON, ItemDef.Tier.EPIC, ItemDef.Tier.DIVINE
]
const MENU_DIFFICULTIES: Array[BattleAI.Difficulty] = [
	BattleAI.Difficulty.EASY, BattleAI.Difficulty.NORMAL, BattleAI.Difficulty.HARD
]
const AUTOPLAY_TIMEOUT_SECONDS := 180.0

var _rules := RulesConfig.new()
var _stages := StageLibrary.load_file("res://data/stages.json")
var _chassis := ChassisLibrary.load_file("res://data/chassis.json")
var _shop := ArenaShop.load_file("res://data/arena_shop.json")
## Oro, mejoras e historial del jugador. Las pruebas automaticas usan uno
## vacio y no tocan el guardado.
var _profile := PlayerProfile.new()
var _last_reward := ""
## Para ir cambiando de escenario de un combate al siguiente.
var _stage_seed: int = 0
var _catalog: Catalog
var _library: BuildLibrary
var _menu: Control
var _battle: BattleScreen
var _pickers: Dictionary = {}
var _last: Dictionary = {}
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
	if _args.has("autoplay"):
		_start_autoplay()
	elif _args.has("menu-shot"):
		# Prueba en vivo del menu: perfil de muestra, captura y salir. No toca
		# el guardado del jugador.
		_profile.gold = 1500
		_profile.shop_levels = {"damage": 3, "health": 10}
		_profile.wins = 12
		_show_menu()
		await get_tree().create_timer(0.6).timeout
		await _shot("menu")
		get_tree().quit(0)
	else:
		_profile = PlayerProfile.load_or_new(SAVE_PATH)
		_show_menu()


# --- Menu --------------------------------------------------------------------


func _show_menu() -> void:
	if _battle != null:
		_battle.queue_free()
		_battle = null
	if _menu != null:
		_menu.queue_free()
	_pickers.clear()
	_menu = CenterContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	_menu.add_child(box)
	var title := Label.new()
	title.text = Txt.t("menu_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = Txt.t("menu_subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var build_names: Array[String] = []
	for id in _library.all_ids():
		build_names.append(_library.display_name(id))
	var tier_names: Array[String] = []
	for tier in MENU_TIERS:
		tier_names.append(Txt.TIER_NAMES[tier])
	var difficulty_names: Array[String] = [
		Txt.t("difficulty_easy"), Txt.t("difficulty_normal"), Txt.t("difficulty_hard")
	]
	_add_picker(box, "player", Txt.t("menu_player"), build_names, _last.get("player", 0))
	_add_picker(box, "enemy", Txt.t("menu_enemy"), build_names, _last.get("enemy", 1))
	_add_picker(box, "tier", Txt.t("menu_tier"), tier_names, _last.get("tier", 1))
	_add_picker(
		box, "difficulty", Txt.t("menu_difficulty"), difficulty_names, _last.get("difficulty", 1)
	)
	var fight := Button.new()
	fight.text = Txt.t("menu_fight")
	fight.custom_minimum_size = Vector2(0, 52)
	fight.add_theme_font_size_override("font_size", 20)
	fight.pressed.connect(_on_fight_pressed)
	box.add_child(fight)
	_add_shop(box)


## Oro, historial y tienda de arena (GDD 8): mejoras permanentes que se
## compran con lo que dan los combates.
func _add_shop(box: VBoxContainer) -> void:
	var gold := Label.new()
	gold.text = Txt.t("menu_gold", [_profile.gold])
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold.add_theme_font_size_override("font_size", 22)
	gold.add_theme_color_override("font_color", Color("ffd86b"))
	box.add_child(gold)
	var record := Label.new()
	record.text = Txt.t("menu_record", [_profile.wins, _profile.losses, _profile.boss_wins])
	if _last_reward != "":
		record.text = "%s\n%s" % [_last_reward, record.text]
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(record)
	var title := Label.new()
	title.text = Txt.t("menu_shop")
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	for track in _shop.track_ids():
		var level := _profile.level_of(track)
		var row := HBoxContainer.new()
		box.add_child(row)
		var label := Label.new()
		label.text = Txt.t(
			"shop_row",
			[_shop.display_name(track), level, _shop.max_level(), _shop_value(track, level)]
		)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(130, 0)
		if level >= _shop.max_level():
			buy.text = Txt.t("shop_max")
			buy.disabled = true
		else:
			buy.text = Txt.t("shop_buy", [_shop.price(level + 1)])
			buy.disabled = _profile.why_cant_buy(_shop, track) != ""
		buy.pressed.connect(_on_buy_pressed.bind(track))
		row.add_child(buy)


## Lo que da una mejora a ese nivel, como texto: "+5 %" o "+123".
func _shop_value(track: String, level: int) -> String:
	var amount := _shop.value(track, level)
	if _shop.tracks[track]["kind"] == "percent":
		return "+%d %%" % roundi(amount * 100.0)
	return "+%d" % roundi(amount)


func _on_buy_pressed(track: String) -> void:
	if _profile.buy(_shop, track) == "":
		_profile.save(SAVE_PATH)
	for key: String in _pickers:
		_last[key] = (_pickers[key] as OptionButton).selected
	_show_menu()


## Al terminar un combate el jugador cobra su oro y se guarda el progreso.
func _on_battle_finished(player_won: bool, against_boss: bool) -> void:
	var amount := _profile.earn(_shop, player_won, against_boss)
	_profile.save(SAVE_PATH)
	_last_reward = Txt.t("reward_line", [amount])


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
	picker.select(selected)
	row.add_child(picker)
	_pickers[key] = picker


func _on_fight_pressed() -> void:
	for key: String in _pickers:
		_last[key] = (_pickers[key] as OptionButton).selected
	_last["seed"] = randi()
	_menu.queue_free()
	_menu = null
	_start_battle()


# --- Combate -----------------------------------------------------------------


func _start_battle() -> void:
	if _battle != null:
		_battle.queue_free()
	var ids := _library.all_ids()
	var tier: ItemDef.Tier = MENU_TIERS[_last["tier"]]
	var level := _rules.tier_max_level[tier]
	var player_id := ids[_last["player"]]
	var enemy_id := ids[_last["enemy"]]
	_battle = BattleScreen.new()
	# El escenario se puede pedir con --stage=<id>; si no, sale de la semilla.
	_battle.stage = _stages.get_stage(str(_args.get("stage", "")))
	if _battle.stage.is_empty():
		_battle.stage = _stages.pick(_stage_seed)
	_stage_seed += 1
	_battle.names = [
		"%s · %s" % [Txt.t("you"), _library.display_name(player_id)],
		"%s · %s" % [Txt.t("rival"), _library.display_name(enemy_id)],
	]
	_battle.rematch_requested.connect(_on_rematch)
	_battle.menu_requested.connect(_show_menu)
	if not _args.has("autoplay"):
		_battle.finished.connect(_on_battle_finished.bind(_library.is_boss(enemy_id)))
	add_child(_battle)
	# Las mejoras de la tienda solo cuentan para el mech del jugador.
	var player_build := _library.make(player_id, _catalog, _rules, tier, level, _chassis)
	player_build.upgrades = _shop.upgrades_for(_profile.shop_levels)
	_battle.start(
		_rules,
		player_build,
		_library.make(enemy_id, _catalog, _rules, tier, level, _chassis),
		_last["seed"],
		MENU_DIFFICULTIES[_last["difficulty"]]
	)


func _on_rematch() -> void:
	_last["seed"] = randi()
	_start_battle()


# --- Prueba en vivo automatica -----------------------------------------------


func _start_autoplay() -> void:
	print("AUTOPLAY argumentos: %s" % _args)
	var ids := _library.all_ids()
	var tier_name: String = _args.get("tier", "EPIC")
	_last = {
		"player": maxi(ids.find(_args.get("player", ids[0])), 0),
		"enemy": maxi(ids.find(_args.get("enemy", ids[1])), 0),
		"tier": maxi(MENU_TIERS.find(ItemDef.Tier[tier_name]), 0),
		"difficulty": 1,
		"seed": int(_args.get("seed", "1")),
	}
	_start_battle()
	var driver := BattleAI.new(BattleAI.Difficulty.NORMAL, _last["seed"] + 7)
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


func _on_autoplay_event(entry: Dictionary) -> void:
	# Una captura la primera vez que pasa cada cosa interesante.
	var event: String = entry["event"]
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
			"drop_taken"
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
