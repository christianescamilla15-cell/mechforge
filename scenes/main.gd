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
##                contando desde 0 (el ultimo es el jefe)
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
## Combate en curso: {"mode" ("campaign", "arena" o "free"), "player",
## "enemy", "tier", "player_level", "enemy_level", "difficulty", "seed"}.
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
	if _args.has("autoplay"):
		_start_autoplay()
	elif _args.has("menu-shot"):
		# Prueba en vivo del menu: perfil de muestra, captura y salir.
		_profile.gold = 1500
		_profile.shop_levels = {"damage": 3, "health": 10}
		_profile.wins = 12
		_profile.fight = 4
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
	var mech_names: Array[String] = []
	for id in _library.ids():
		mech_names.append(_library.display_name(id))
	_add_picker(left, "player", Txt.t("menu_player"), mech_names, _library.ids().find(_player_id()))
	(_pickers["player"] as OptionButton).item_selected.connect(_on_mech_picked)
	_add_campaign(left)
	_add_arena(left)
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
func _add_campaign(box: VBoxContainer) -> void:
	_text(box, Txt.t("menu_campaign"), 20)
	var zone := _profile.zone
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
		_button(box, Txt.t("campaign_boss_fight"), 46, _on_campaign_pressed)
		if _campaign.on_boss_loss == "new_game":
			_text(box, Txt.t("campaign_boss_warning"), 14, COLOR_WARNING)
	else:
		var count := _campaign.fights_in(zone)
		_text(box, Txt.t("campaign_next", [_profile.fight + 1, count, rival]))
		_button(box, Txt.t("campaign_fight", [_profile.fight + 1]), 46, _on_campaign_pressed)


## Arena: combates sueltos contra un rival al azar, para juntar celdas.
func _add_arena(box: VBoxContainer) -> void:
	_text(box, Txt.t("menu_arena"), 20)
	_text(
		box,
		Txt.t("arena_info", [_shop.reward("arena_win"), _shop.reward("arena_loss")]),
		16,
		COLOR_MUTED
	)
	_button(box, Txt.t("arena_fight"), 46, _on_arena_pressed)


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


## Armeria (GDD 8): celdas, historial y mejoras permanentes que se compran
## con lo que dan los combates.
func _add_shop(box: VBoxContainer) -> void:
	_text(box, Txt.t("menu_shop"), 26).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cells := _text(box, Txt.t("menu_gold", [_profile.gold]), 24, COLOR_CELLS)
	cells.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var record := Txt.t(
		"menu_record", [_profile.wins, _profile.losses, _profile.boss_wins, _campaign.world_bosses]
	)
	if _profile.runs_lost > 0:
		record += "\n" + Txt.t("menu_runs", [_profile.runs_lost, _profile.best_boss_wins])
	if _last_result != "":
		record = "%s\n%s" % [_last_result, record]
	_text(box, record, 15, COLOR_MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		buy.custom_minimum_size = Vector2(140, 0)
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


## Mech con el que pelea el jugador: el guardado en su perfil o, si no vale,
## el primero.
func _player_id() -> String:
	var ids := _library.ids()
	return _profile.mech if _profile.mech in ids else ids[0]


func _save() -> void:
	if _persist:
		_profile.save(SAVE_PATH)


func _remember_picks() -> void:
	for key: String in ["enemy", "tier", "difficulty"]:
		if _pickers.has(key):
			_last[key] = (_pickers[key] as OptionButton).selected


func _on_mech_picked(index: int) -> void:
	_profile.mech = _library.ids()[index]
	_save()


func _on_buy_pressed(track: String) -> void:
	if _profile.buy(_shop, track) == "":
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
	_start_battle(_spec_for("arena", zone, _campaign.arena_fight(zone, _library, randi())))


func _on_free_pressed() -> void:
	_remember_picks()
	var tier: ItemDef.Tier = ItemDef.Tier.values()[_last["tier"]]
	var level := _rules.tier_max_level[tier]
	_start_battle(
		{
			"mode": "free",
			"player": _player_id(),
			"enemy": _library.all_ids()[_last["enemy"]],
			"tier": tier,
			"player_level": level,
			"enemy_level": level,
			"difficulty": _last["difficulty"],
			"seed": randi(),
		}
	)


## Combate de la campana o de la arena: la zona pone la clase y los niveles.
func _spec_for(mode: String, zone: int, fight: Dictionary) -> Dictionary:
	return {
		"mode": mode,
		"player": _player_id(),
		"enemy": fight["enemy"],
		"tier": _campaign.tier_of(zone),
		"player_level": _campaign.player_level(zone),
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
	var tier: ItemDef.Tier = spec["tier"]
	var rewarded: bool = spec["mode"] != "free"
	_battle = BattleScreen.new()
	# El escenario se puede pedir con --stage=<id>; si no, sale de la semilla.
	_battle.stage = _stages.get_stage(str(_args.get("stage", "")))
	if _battle.stage.is_empty():
		_battle.stage = _stages.pick(_stage_seed)
	_stage_seed += 1
	_battle.names = [
		"%s · %s" % [Txt.t("you"), _library.display_name(spec["player"])],
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
	var player_build := _library.make(
		spec["player"], _catalog, _rules, tier, spec["player_level"], _chassis
	)
	# Las mejoras de la armeria solo cuentan para el mech del jugador.
	if rewarded:
		player_build.upgrades = _shop.upgrades_for(_profile.shop_levels)
	_battle.start(
		_rules,
		player_build,
		_library.make(spec["enemy"], _catalog, _rules, tier, spec["enemy_level"], _chassis),
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
	var result := _campaign.finish_fight(_profile, _shop, _spec["mode"], player_won)
	_save()
	if result["game_over"]:
		_last_result = Txt.t("result_game_over")
	elif result["zone_cleared"]:
		_last_result = Txt.t("result_zone_cleared", [result["gold"]])
	else:
		_last_result = Txt.t("result_reward", [result["gold"]])
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
		"enemy": _args.get("enemy", ids[1]),
		"tier": tier,
		"player_level": level,
		"enemy_level": level,
		"difficulty": 1,
		"seed": int(_args.get("seed", "1")),
	}
	if _args.has("fight"):
		# Un combate de la primera zona de la campana, con sus niveles y su
		# recompensa, sobre un perfil vacio que no se guarda.
		_profile.fight = int(_args["fight"])
		var fight := _campaign.fight_at(0, _profile.fight)
		spec["mode"] = "campaign"
		spec["enemy"] = fight["enemy"]
		spec["tier"] = _campaign.tier_of(0)
		spec["player_level"] = _campaign.player_level(0)
		spec["enemy_level"] = int(fight["level"])
		spec["difficulty"] = DIFFICULTY_IDS.find(fight["difficulty"])
	for side: String in ["player", "enemy"]:
		if not spec[side] in ids:
			spec[side] = ids[0]
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
