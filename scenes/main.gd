class_name MainScreen
extends Control
## Punto de entrada: la base del jugador (GDD 9), que es el hangar
## (WorkshopScreen): taller, armeria (piezas, tienda, mejoras permanentes y
## habilidades) y, desde su monitor de misiones, la salida a combatir: la
## campana (los combates de la zona y su jefe), la arena (para juntar celdas)
## y un combate libre, sin recompensa, para probar cualquier cruce.
##
## Pruebas en vivo: `++ --autoplay` (ver LiveTest) y `++ --menu-shot`, que
## guarda una captura del menu con un perfil de muestra y sale
## (--menu-shot=jefe: delante del jefe; =ajustes: con los ajustes abiertos).

const SAVE_PATH := "user://save.json"
const MENU_DIFFICULTIES: Array[BattleAI.Difficulty] = [
	BattleAI.Difficulty.EASY, BattleAI.Difficulty.NORMAL, BattleAI.Difficulty.HARD
]
const DIFFICULTY_IDS: Array[String] = ["EASY", "NORMAL", "HARD"]
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
## Lo elegido en el combate libre ({"enemy", "tier", "difficulty"}, indices),
## para conservarlo al volver al hangar.
var _last: Dictionary = {}
## Arma lo que ensenan el monitor de misiones y la fila de rivales.
var _brief := MissionBrief.new()
## Arma lo que ensena el taller del hangar: el tablero de piezas, las
## pantallas de mejoras y habilidades y la lectura del robot.
var _bench := WorkshopBrief.new()
## Semilla del rival de la arena: el que se ve en el hangar es el que sale.
var _arena_seed: int = 0
## Como vuelve el hangar de un combate: {"channel", "how", "beaten"}
## (WorkshopScreen.open_missions); vacio = el hangar de siempre.
var _return: Dictionary = {}
## Telon negro entre el hangar y el combate.
var _curtain: ColorRect
## El hangar de fondo: solo se ve al elegir el primer robot (el hangar de
## verdad y el combate lo tapan, y pintarlo costaba cuadros).
var _backdrop := HangarBackdrop.new()
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
	add_child(_backdrop)
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
	_brief.rules = _rules
	_brief.catalog = _catalog
	_brief.library = _library
	_brief.chassis = _chassis
	_brief.campaign = _campaign
	_brief.shop = _shop
	_bench.rules = _rules
	_bench.catalog = _catalog
	_bench.library = _library
	_bench.campaign = _campaign
	_bench.workshop = _workshop
	_bench.garage = _garage
	_bench.shop = _shop
	_bench.skills = _skills
	_bench.progression = _progression
	_arena_seed = randi()
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
		# --torso=<id>: otro torso (cada uno tiene su dibujo).
		if _args.has("torso"):
			_profile.owned.append(_args["torso"])
			_profile.build["torso"] = _args["torso"]
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
		if _args["menu-shot"] in ["pieza", "tienda", "mejoras", "habilidades", "robot"]:
			# El hangar con eso abierto (--slot=<hueco>: el hueco elegido).
			var hangar := open_workshop()
			if _args.has("slot"):
				hangar._selected = _args["slot"]
			hangar.show_page(_args["menu-shot"])
		elif _args["menu-shot"] == "ajustes":
			_live_test().settings_test()
			return
		elif _args["menu-shot"] == "espada":
			_live_test().sword_test()
			return
		elif _args["menu-shot"] == "taller":
			_live_test().workshop_test(open_workshop())
			return
		elif _args["menu-shot"] == "armeria":
			_live_test().armory_test()
			return
		elif _args["menu-shot"] == "garaje":
			_live_test().garage_test()
			return
		elif _args["menu-shot"] == "misiones":
			_live_test().missions_test()
			return
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
		# --channel=<canal>: el hangar en modo mision, en ese canal (campaign,
		# arena o free). Se espera a que los rivales terminen de encenderse.
		if _args.has("channel") and _menu is WorkshopScreen:
			(_menu as WorkshopScreen).open_missions(_args["channel"])
			await get_tree().create_timer(1.5).timeout
		# --turn=<grados>: el robot del hangar, girado.
		if _args.has("turn") and _menu is WorkshopScreen:
			(_menu as WorkshopScreen).turn_robot(float(_args["turn"]))
		# --fps: cuadros por segundo tras tres segundos (con --disable-vsync
		# delante de "++" se ve lo que da de si el giro).
		if _args.has("fps"):
			await get_tree().create_timer(3.0).timeout
			print("FPS %d" % Engine.get_frames_per_second())
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
	Sfx.music("base")
	var back := _return
	_return = {}
	_backdrop.set_shown(not _profile.has_mech())
	if _profile.has_mech():
		var hangar := WorkshopScreen.new()
		hangar.main = self
		_menu = hangar
		add_child(hangar)
		hangar.toast.call_deferred(_last_result)
		# De vuelta de un combate, el hangar sigue en el modo mision: si
		# ganaste en la campana, el vencido se apaga y la fila avanza.
		if not back.is_empty():
			hangar.open_missions.call_deferred(
				back["channel"], back.get("how", "enter"), back.get("beaten", {})
			)
			_raise_curtain()
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


## Adquirir un robot: una bahia vacia del hangar proyecta lo que hay.
func open_acquire() -> void:
	if _menu is WorkshopScreen:
		(_menu as WorkshopScreen).open_offers()


## Un armazon vacio, gratis: se abre el taller para armarlo.
func acquire_frame() -> void:
	var label := Txt.t("robot_default", [_profile.mechs.size() + 1])
	if _profile.add_frame(_rules, label) != "":
		return
	Sfx.play("ui_comprar")
	_save()
	# Un armazon vacio se arma ya: el tablero sale con los torsos.
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
	_refresh_hangar()


## Desmonta un robot; sus piezas se quedan. Quien lo pide ya confirmo (la
## ficha del robot pide dos pulsaciones).
func remove_robot(index: int) -> void:
	if _profile.remove_mech(index) != "":
		return
	Sfx.play("taller_quitar")
	_save()
	_refresh_hangar()


## Ajustes: en el hangar, su cuadro de control de la pared, de cerca; sin
## hangar (al elegir el primer robot), el panel de siempre.
func open_settings() -> void:
	if _menu is WorkshopScreen:
		(_menu as WorkshopScreen).show_page("ajustes")
		return
	var panel := SettingsPanel.open(self, _settings, GameSettings.PATH if _persist else "")
	panel.show_quit = true


## Cambia un ajuste desde el cuadro de control del hangar: "speed" (indice
## de GameSettings.SPEEDS), "fullscreen" o "volume:<canal>" (de 0 a 1). Se
## aplica y se guarda al momento.
func change_setting(key: String, value: Variant) -> void:
	if key == "speed":
		_settings.speed_index = clampi(int(value), 0, GameSettings.SPEEDS.size() - 1)
	elif key == "fullscreen":
		_settings.fullscreen = bool(value)
	elif key.begins_with("volume:") and _settings.volumes.has(key.trim_prefix("volume:")):
		_settings.volumes[key.trim_prefix("volume:")] = clampf(float(value), 0.0, 1.0)
	else:
		return
	_settings.apply()
	if _persist:
		_settings.save_to(GameSettings.PATH)


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


# --- Misiones --------------------------------------------------------------------


## Lo que ensenan el monitor de misiones y la fila de rivales en ese canal
## ("campaign", "arena" o "free"): un estado de MissionBrief con, ademas, si
## tu robot puede pelear ("can_fight", "problems") y tu historial ("record").
func mission_state(channel: String = "campaign") -> Dictionary:
	var state: Dictionary
	match channel:
		"arena":
			var power := Campaign.mean_power(_rules, _profile, _player_items())
			state = _brief.arena_state(_profile, _arena_seed, power)
		"free":
			state = _brief.free_state(_last)
		_:
			state = _brief.campaign_state(_profile)
	var problems := _player_build().validate(_rules)
	state["can_fight"] = problems.is_empty()
	state["problems"] = Txt.t("mech_problems", [", ".join(problems)])
	state["record"] = Txt.t(
		"mission_record",
		[_profile.wins, _profile.losses, _profile.boss_wins, _campaign.world_bosses]
	)
	return state


## Sale a combatir en ese canal. El aviso del jefe (perder acaba la partida)
## ya lo dio el hangar, que pide pulsarlo dos veces.
func start_mission(channel: String) -> void:
	match channel:
		"arena":
			_on_arena_pressed()
		"free":
			_on_free_pressed()
		_:
			var zone := _profile.zone
			if zone < _campaign.zone_count() and not _campaign.is_complete(_profile):
				_start_battle(_spec_for("campaign", zone, _campaign.fight_at(zone, _profile.fight)))


## Cambia algo de lo elegido en el combate libre ("enemy", "tier" o
## "difficulty"), un paso adelante o atras, dando la vuelta.
func change_free_pick(key: String, step: int) -> void:
	var pick := _brief.free_pick(_last)
	_last[key] = posmod(int(pick[key]) + step, _brief.free_count(key))


## Velocidad de las animaciones que eligio el jugador.
func animation_speed() -> float:
	return _settings.speed()


## Baja el telon (la pantalla se va a negro) y espera a que termine.
func drop_curtain(seconds: float) -> void:
	var curtain := _get_curtain()
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade := create_tween()
	fade.tween_property(curtain, "color:a", 1.0, seconds)
	await fade.finished


## Sube el telon sobre la pantalla que acaba de entrar.
func _raise_curtain(seconds: float = 0.35) -> void:
	if _curtain == null or _curtain.color.a <= 0.0:
		return
	move_child(_curtain, -1)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(_curtain, "color:a", 0.0, seconds)


func _get_curtain() -> ColorRect:
	if _curtain == null:
		_curtain = ColorRect.new()
		_curtain.color = Color(0, 0, 0, 0)
		_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_curtain)
	move_child(_curtain, -1)
	return _curtain


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


## Clase de la zona en la que esta el jugador.
func _zone_tier() -> int:
	return _bench.zone_tier(_profile)


## Nombre del robot que usa.
func _player_name() -> String:
	return robot_name(_profile.active) if _profile.has_mech() else ""


func _save() -> void:
	if _persist:
		_profile.save(SAVE_PATH)


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
	return _bench.build_of(_profile, spec)


func _player_level() -> int:
	return _bench.level(_profile)


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
	return _bench.assist_tier(_profile)


## Tope de la armeria en la zona en la que esta el jugador.
func _armory_cap() -> int:
	return _bench.armory_cap(_profile)


## Un combate de arena, contra el rival que se ve en el hangar (el de la
## semilla); despues toca otro.
func _on_arena_pressed() -> void:
	var zone := mini(_profile.zone, _campaign.zone_count() - 1)
	var power := Campaign.mean_power(_rules, _profile, _player_items())
	var fight := _campaign.arena_fight(zone, _library, _arena_seed, _rules, power)
	_arena_seed = randi()
	_start_battle(_spec_for("arena", zone, fight))


func _on_free_pressed() -> void:
	var pick := _brief.free_pick(_last)
	var tier: ItemDef.Tier = ItemDef.Tier.values()[pick["tier"]]
	var level := _rules.tier_max_level[tier]
	_start_battle(
		{
			"mode": "free",
			"items": _profile.build,
			"name": _player_name(),
			"enemy": _library.all_ids()[pick["enemy"]],
			"enemy_tier": tier,
			"enemy_level": level,
			"player_tier": tier,
			"player_level": level,
			"difficulty": pick["difficulty"],
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
	# Al volver, el hangar sigue en el canal del que se salio.
	_return = {"channel": spec["mode"], "how": "enter"}
	_backdrop.set_shown(false)
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
	_raise_curtain()


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
	if _spec["mode"] == "campaign" and player_won:
		# En el hangar, el vencido se apaga y la fila avanza un sitio.
		_return["how"] = "advance"
		_return["beaten"] = (
			_brief
			. rival(
				{
					"enemy": _spec["enemy"],
					"tier": _spec["enemy_tier"],
					"level": _spec["enemy_level"],
					"difficulty": DIFFICULTY_IDS[_spec["difficulty"]],
				},
				_spec["enemy_tier"]
			)
		)
	if result["game_over"]:
		_return = {}
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
