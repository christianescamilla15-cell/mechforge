class_name MainScreen
extends Control
## Punto de entrada: la base del jugador (GDD 9). Desde aqui se entra a la
## campana (los combates de la zona y su jefe), a la arena (para juntar
## celdas) y al taller (WorkshopScreen), que es tambien la armeria: piezas,
## tienda, mejoras permanentes y habilidades. Hay ademas un combate libre, sin
## recompensa, para probar cualquier cruce.
##
## Pruebas en vivo: `++ --autoplay` (ver LiveTest) y `++ --menu-shot`, que
## guarda una captura del menu con un perfil de muestra y sale
## (--menu-shot=jefe: delante del jefe; =ajustes: con los ajustes abiertos).

const SAVE_PATH := "user://save.json"
const MENU_DIFFICULTIES: Array[BattleAI.Difficulty] = [
	BattleAI.Difficulty.EASY, BattleAI.Difficulty.NORMAL, BattleAI.Difficulty.HARD
]
const DIFFICULTY_IDS: Array[String] = ["EASY", "NORMAL", "HARD"]
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
var _skills := SkillTree.load_file("res://data/skills.json")
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
## Ajustes del jugador (velocidad, pantalla y volumen), aparte de la partida.
var _settings := GameSettings.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Toda la interfaz con relieve, y el hangar al fondo.
	theme = Look.theme()
	add_child(HangarBackdrop.new())
	# El sonido va primero: asi oye los botones de todo lo que se cree despues.
	add_child(Sfx.new())
	# En el juego la nave deja bonificaciones en la arena (GDD 2.8), hay
	# golpes criticos (GDD 2.9) y los golpes empujan (GDD 2.10).
	_rules.drops_enabled = true
	_rules.crits_enabled = true
	_rules.impact_enabled = true
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
		showcase.only_shots = _args.has("shots")
		showcase.only_wear = _args.has("wear")
		showcase.only_impacts = _args.has("impact")
		showcase.finished.connect(func() -> void: get_tree().quit(0))
		add_child(showcase)
	elif _args.has("autoplay"):
		_live_test().start_autoplay()
	elif _args.has("menu-shot"):
		# Prueba en vivo del menu: perfil de muestra, captura y salir.
		_profile.start_run(_library, _library.ids()[0])
		Garage.ensure_assist(_profile, _catalog)
		_profile.gold = 1500
		_profile.shop_levels = {"damage": 3, "health": 10}
		_profile.parts = {"torso_baluarte": {"tier": 0, "level": 3}}
		_profile.parts["hoja_balas_cin"] = {"tier": 0, "level": 3}
		_profile.wins = 12
		_profile.fight = 4
		if _args["menu-shot"] == "nuevo":
			_profile = PlayerProfile.new()
		elif _args["menu-shot"] == "habilidades":
			_profile.xp = 9500
			_profile.skills.assign(["asalto_1", "asalto_2", "asalto_3", "blindaje_1", "sistemas_1"])
		if _args["menu-shot"] == "jefe":
			_profile.fight = _campaign.fights_in(0)
		# --legs=<id>: otras piernas (para ver las de orugas, ruedas o levitar).
		if _args.has("legs"):
			_profile.owned.append(_args["legs"])
			_profile.build["legs"] = _args["legs"]
		# --xp=<n> y --chest=<id>: un perfil con huecos abiertos y arma de pecho.
		if _args.has("xp"):
			_profile.xp = int(_args["xp"])
		if _args.has("chest"):
			_profile.owned.append(_args["chest"])
			_profile.build["chest"] = _args["chest"]
		# --real-profile: la partida de verdad del jugador. No se guarda nada:
		# en esta prueba _persist es false.
		if _args.has("real-profile"):
			_profile = PlayerProfile.load_or_new(SAVE_PATH)
			Garage.ensure_assist(_profile, _catalog)
		_show_menu()
		if _args["menu-shot"] == "ajustes":
			open_settings()
		elif _args["menu-shot"] == "taller":
			_live_test().workshop_test(open_workshop())
			return
		elif _args["menu-shot"] == "armeria":
			_live_test().armory_test()
			return
		elif _args["menu-shot"] == "garaje":
			_live_test().garage_test()
			return
		elif _args["menu-shot"] in ["tienda", "mejoras", "habilidades"]:
			# El taller abierto en ese espacio.
			open_workshop().show_page(_args["menu-shot"])
		elif _args["menu-shot"] == "giro":
			# El robot dando la vuelta entera sobre su plataforma, cuadro a
			# cuadro (--step=<grados>, 10 si no se dice).
			var hangar := _menu as WorkshopScreen
			var step := float(_args.get("step", "10"))
			var live := _live_test()
			await get_tree().create_timer(0.6).timeout
			for i in roundi(360.0 / step):
				hangar.turn_robot(i * step)
				await get_tree().create_timer(0.1).timeout
				await live.shot("giro")
			get_tree().quit(0)
			return
		# --turn=<grados>: el robot del hangar, girado.
		if _args.has("turn") and _menu is WorkshopScreen:
			(_menu as WorkshopScreen).turn_robot(float(_args["turn"]))
		await get_tree().create_timer(0.6).timeout
		await _live_test().shot("menu")
		get_tree().quit(0)
	else:
		_profile = PlayerProfile.load_or_new(SAVE_PATH)
		Garage.ensure_assist(_profile, _catalog)
		_persist = true
		_settings = GameSettings.load_from()
		_settings.apply()
		_show_menu()


# --- Menu --------------------------------------------------------------------


## La pantalla de inicio: el hangar inmersivo (WorkshopScreen), que es
## tambien el taller y la armeria. Sin robot, se elige el primero.
func _show_menu() -> void:
	if _battle != null:
		_battle.queue_free()
		_battle = null
	if _menu != null:
		_menu.queue_free()
	_pickers.clear()
	Sfx.music("base")
	if _profile.has_mech():
		var hangar := WorkshopScreen.new()
		hangar.main = self
		_menu = hangar
		add_child(hangar)
		hangar.toast.call_deferred(_last_result)
		return
	# Partida nueva: una placa en el centro con los cuatro robots de ejemplo.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu = center
	add_child(center)
	var plate := PanelContainer.new()
	var style := TechStyle.plate(Color(0.07, 0.1, 0.15, 0.94), Color("ffd36b"), 24.0, 14.0)
	style.glow = 0.3
	plate.add_theme_stylebox_override("panel", style)
	center.add_child(plate)
	var box := _column(plate, 520)
	_text(box, Txt.t("menu_title"), 40).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_starters(box)
	_text(box, _record_text(), 14, COLOR_MUTED).horizontal_alignment = (HORIZONTAL_ALIGNMENT_CENTER)


## Historial: victorias, derrotas, jefes y partidas perdidas.
func _record_text() -> String:
	var record := Txt.t(
		"menu_record", [_profile.wins, _profile.losses, _profile.boss_wins, _campaign.world_bosses]
	)
	if _profile.runs_lost > 0:
		record += "\n" + Txt.t("menu_runs", [_profile.runs_lost, _profile.best_boss_wins])
	if _last_result != "":
		record = "%s\n%s" % [_last_result, record]
	return record


# --- Garaje -------------------------------------------------------------------


## Nombre de uno de tus robots: el suyo, el de su diseno o "Robot N".
func robot_name(index: int) -> String:
	var robot: Dictionary = _profile.mechs[index]
	if str(robot.get("name", "")) != "":
		return robot["name"]
	if _library.specs.has(str(robot.get("design", ""))):
		return _library.display_name(robot["design"])
	return Txt.t("robot_default", [index + 1])


## Pasa a usar otro de tus robots.
func use_robot(index: int) -> void:
	if index == _profile.active:
		return
	_profile.select_mech(index)
	Sfx.play("taller_montar")
	_save()
	_refresh_hangar()


func open_acquire() -> void:
	var panel := AcquirePanel.new()
	panel.main = self
	add_child(panel)


## Un armazon vacio, gratis: se abre el taller para armarlo.
func acquire_frame() -> void:
	var label := Txt.t("robot_default", [_profile.mechs.size() + 1])
	if _profile.add_frame(_rules, label) != "":
		return
	Sfx.play("ui_comprar")
	_save()
	_close_acquire()
	# Un armazon vacio se arma ya: el cajon abre el torso.
	_refresh_hangar()
	if _menu is WorkshopScreen:
		(_menu as WorkshopScreen).pick("torso")


## Un robot con uno de los disenos de ejemplo: se queda en la base.
func acquire_design(design: String) -> void:
	var tier := _zone_tier()
	if _garage.buy_design(_profile, _library, _catalog, _rules, _workshop, design, tier) != "":
		return
	Sfx.play("ui_comprar")
	_save()
	_close_acquire()
	_refresh_hangar()


func _close_acquire() -> void:
	for child in get_children():
		if child is AcquirePanel:
			child.queue_free()


## Desmontar un robot pide confirmacion; sus piezas se quedan.
func ask_remove_robot(index: int) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = Txt.t("robots_remove")
	dialog.dialog_text = Txt.t("robots_remove_confirm", [robot_name(index)])
	dialog.ok_button_text = Txt.t("robots_remove_yes")
	dialog.cancel_button_text = Txt.t("campaign_boss_no")
	dialog.confirmed.connect(
		func() -> void:
			if _profile.remove_mech(index) == "":
				Sfx.play("taller_quitar")
				_save()
				_refresh_hangar()
	)
	add_child(dialog)
	dialog.popup_centered()


## Ajustes (el engrane del hangar y Esc), con el boton de salir del juego.
func open_settings() -> void:
	var panel := SettingsPanel.open(self, _settings, GameSettings.PATH if _persist else "")
	panel.show_quit = true


## El hangar (la pantalla de inicio), para quien lo pida por nombre.
func open_workshop() -> WorkshopScreen:
	_show_menu()
	return _menu as WorkshopScreen


## Vuelve a pintar el hangar sin rehacerlo (el cajon abierto se queda).
func _refresh_hangar() -> void:
	if _menu is WorkshopScreen:
		(_menu as WorkshopScreen).refresh()
	else:
		_show_menu()


## Lineas de la pantalla de misiones del hangar: la zona, el combate que toca
## y su rival.
func mission_lines() -> PackedStringArray:
	var zone := mini(_profile.zone, _campaign.zone_count() - 1)
	var lines := PackedStringArray([Txt.t("mission_zone", [zone + 1, _campaign.zone_name(zone)])])
	if _campaign.is_complete(_profile):
		lines.append(Txt.t("campaign_done"))
		return lines
	var fight := _campaign.fight_at(zone, _profile.fight)
	if _campaign.is_boss_fight(zone, _profile.fight):
		lines.append(Txt.t("mission_boss"))
	else:
		lines.append(Txt.t("mission_fight", [_profile.fight + 1, _campaign.fights_in(zone)]))
	lines.append(_library.display_name(fight["enemy"]))
	return lines


## Cajon de misiones: el estado de tu robot, la campana, la arena, el combate
## libre y tu historial.
func fill_missions(box: VBoxContainer) -> void:
	var can_fight := _add_mech_status(box)
	_add_campaign(box, can_fight)
	_add_arena(box, can_fight)
	_add_free_fight(box)
	_text(box, _record_text(), 13, COLOR_MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


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
	_text(box, "%s · %s" % [_player_name(), line], 16)
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
	var zone_line := Txt.t(
		"campaign_zone", [zone + 1, _campaign.world_bosses, _campaign.zone_name(zone)]
	)
	if _campaign.enemy_armory(zone) > 0:
		zone_line += Txt.t("campaign_order_armory", [_campaign.enemy_armory(zone)])
	_text(box, zone_line, 16, COLOR_MUTED)
	var fight := _campaign.fight_at(zone, _profile.fight)
	var rival := _library.display_name(fight["enemy"])
	if _campaign.is_boss_fight(zone, _profile.fight):
		_text(box, Txt.t("campaign_boss", [rival]))
		var ability := _boss_ability(fight["enemy"])
		if ability != "":
			_text(box, ability, 14, COLOR_MUTED)
		var trained := _campaign.boss_skills(zone)
		if trained > 0:
			_text(box, Txt.t("campaign_boss_skills", [trained]), 14, COLOR_MUTED)
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


## Clase de la zona en la que esta el jugador.
func _zone_tier() -> int:
	return _campaign.tier_of(mini(_profile.zone, _campaign.zone_count() - 1))


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
## Nombre del robot que usa.
func _player_name() -> String:
	return robot_name(_profile.active) if _profile.has_mech() else ""


func _save() -> void:
	if _persist:
		_profile.save(SAVE_PATH)


func _remember_picks() -> void:
	for key: String in ["enemy", "tier", "difficulty"]:
		if _pickers.has(key):
			_last[key] = (_pickers[key] as OptionButton).selected


func _on_starter_picked(id: String) -> void:
	_profile.start_run(_library, id)
	Garage.ensure_assist(_profile, _catalog)
	_save()
	_show_menu()


## Mech armado del jugador con la clase y el nivel de cada pieza, sin lo que
## va en huecos que su nivel aun no abre.
func _player_build() -> MechBuild:
	return _robot_build(_profile.build)


## Un robot armado con las piezas del jugador (su clase y nivel), sus
## habilidades y su armeria, para verlo y medirlo.
func _robot_build(spec: Dictionary) -> MechBuild:
	var build := _catalog.make_build(spec, _rules, ItemDef.Tier.COMMON, 0, _profile.parts)
	_progression.apply_locks(build, _player_level())
	build.skills = _skills.effects_for(_profile.skills)
	build.upgrades = _shop.upgrades_for(_profile.shop_levels)
	return build


func _player_level() -> int:
	return _progression.level_for(_profile.xp)


## Piezas del mech armado del jugador que tienen clase y nivel propios (sus
## claves de progreso): las armas del asistente suben con el.
func _player_items() -> Array[String]:
	var out: Array[String] = []
	var carried := _profile.build.has("assist")
	for id in BuildLibrary.items_of(_profile.build):
		var def := _catalog.get_item(id)
		if def == null or (carried and def.type == ItemDef.Type.DRONE):
			continue
		if not def.progress_id() in out:
			out.append(def.progress_id())
	return out


## Clase del robot de asistencia del jugador; -1 si no lo lleva.
func _assist_tier() -> int:
	if not _profile.build.has("assist"):
		return -1
	return _profile.part(ItemDef.ASSIST_PROGRESS)["tier"]


## Tope de la armeria en la zona en la que esta el jugador.
func _armory_cap() -> int:
	return _campaign.armory_cap(mini(_profile.zone, _campaign.zone_count() - 1), _shop)


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
		"enemy_skills": int(fight.get("skills", 0)),
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
	_battle.speed = _settings.speed()
	_battle.settings = _settings
	_battle.settings_path = GameSettings.PATH if _persist else ""
	var boss: bool = (
		spec["mode"] == "campaign" and _campaign.is_boss_fight(spec["zone"], _profile.fight)
	)
	# Rendirse contra un jefe acaba la partida, como perder: la pausa lo avisa.
	_battle.surrender_ends_run = boss and _campaign.on_boss_loss == "new_game"
	Sfx.music("jefe" if boss else "combate")
	if rewarded:
		_battle.finished.connect(_on_battle_finished)
	add_child(_battle)
	var player_build: MechBuild
	if rewarded:
		player_build = _catalog.make_build(
			spec["items"], _rules, ItemDef.Tier.COMMON, 0, _profile.parts
		)
		_progression.apply_locks(player_build, _player_level())
		player_build.skills = _skills.effects_for(_profile.skills)
	else:
		var player_tier: ItemDef.Tier = spec["player_tier"]
		player_build = _catalog.make_build(spec["items"], _rules, player_tier, spec["player_level"])
		# Tambien en el combate libre el mech lleva las habilidades del jugador.
		player_build.skills = _skills.effects_for(_profile.skills)
	# Las mejoras de la armeria solo cuentan para el mech del jugador.
	if rewarded:
		player_build.upgrades = _shop.upgrades_for(_profile.shop_levels)
	var enemy_build := _library.make(
		spec["enemy"], _catalog, _rules, spec["enemy_tier"], spec["enemy_level"], _chassis
	)
	# En la campana y la arena los rivales llevan la armeria del Orden.
	if spec.has("zone"):
		enemy_build.upgrades = _campaign.enemy_upgrades(spec["zone"], _shop)
	# Los jefes del Orden llevan su entrenamiento (GDD 9.3).
	var trained := _skills.spread(int(spec.get("enemy_skills", 0)))
	enemy_build.skills = _skills.effects_for(trained)
	_battle.start(
		_rules, player_build, enemy_build, spec["seed"], MENU_DIFFICULTIES[spec["difficulty"]]
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


## Herramienta de prueba en vivo (LiveTest), solo con --autoplay o --menu-shot.
func _live_test() -> LiveTest:
	var live := LiveTest.new()
	live.main = self
	add_child(live)
	return live
