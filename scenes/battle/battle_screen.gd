class_name BattleScreen
extends Control
## Pantalla de combate. Lee el estado del motor y le envia acciones; nunca
## cambia el estado por su cuenta. Reproduce los eventos del motor uno a uno
## usando la foto de estado que trae cada evento.

signal event_played(entry: Dictionary)
signal finished(player_won: bool)
signal rematch_requested
signal menu_requested
## Se mostro la prevision de una accion (lo usa la prueba en vivo).
signal preview_shown

const STEP_SECONDS := 0.42
const COLOR_BACKGROUND := Color("0b1017")
const COLOR_WALK := Color("1f5f3a")
const COLOR_TELEPORT := Color("4b2f7a")
const COLOR_DAMAGE := Color("ffe9e0")
const COLOR_HEAT := Color("ff8a3d")
const COLOR_COOL := Color("9fd8ff")
const COLOR_DROP := Color("ffe27a")
const COLOR_REPAIR := Color("7dff9b")

var rules: RulesConfig
var engine: BattleEngine
## Indice del mech que controla el jugador.
var player: int = 0
var enemy_ai: BattleAI
## Si no es null, la IA juega tambien por el jugador (pruebas automaticas).
var player_ai: BattleAI
## Si no es null, elige las jugadas del jugador pero las ejecuta a traves de
## los mismos controles que usaria una persona (pasar el raton, pulsar, elegir
## casilla). Sirve para probar la interfaz en vivo.
var ui_driver: BattleAI
## Multiplicador de velocidad de las animaciones.
var speed: float = 1.0
## Escenario del combate (data/stages.json); vacio = el de por defecto.
var stage: Dictionary = {}
var names: Array[String] = [Txt.t("you"), Txt.t("rival")]
## Si al terminar se ofrece repetir el combate, y con que texto ("" = revancha).
var allow_rematch: bool = true
var rematch_text: String = ""

var _arena: ArenaView
var _panels: Array[StatPanel] = []
var _turn_label: Label
var _actions_label: Label
var _hint_label: Label
var _preview: RichTextLabel
var _log: RichTextLabel
var _action_bar: ActionBar
var _result: PanelContainer
var _result_label: Label
var _result_note: Label

var _shown: int = 0
var _busy: bool = true
var _teleport_mode: bool = false
## Lo ultimo que se mostro de cada mech, para dibujar entre eventos.
var _state: Array[Dictionary] = []


func _ready() -> void:
	_build_ui()


## Empieza un combate nuevo. Llamar despues de anadir la pantalla al arbol.
func start(
	p_rules: RulesConfig,
	build_player: MechBuild,
	build_enemy: MechBuild,
	seed_value: int,
	difficulty: BattleAI.Difficulty
) -> void:
	rules = p_rules
	enemy_ai = BattleAI.new(difficulty, seed_value + 1)
	engine = BattleEngine.new(rules, build_player, build_enemy, seed_value, seed_value % 2)
	_shown = 0
	_busy = true
	_teleport_mode = false
	_result.hide()
	set_result_note("")
	_log.clear()
	_arena.cells = rules.arena_size
	for i in 2:
		_panels[i].set_title(names[i])
		_arena.mechs[i].setup(engine.mechs[i].build, 1 if i == 0 else -1)
	_action_bar.build_for(engine.mechs[player])
	# Espera a que el contenedor tenga tamano antes de colocar los mechs.
	await get_tree().process_frame
	await get_tree().process_frame
	_state = [_live_state(0), _live_state(1)]
	# Los eventos previos a la primera accion (por ejemplo, una regeneracion)
	# se dan por mostrados: el estado inicial ya los incluye.
	_shown = engine.events.size()
	_place_mechs()
	_show_state()
	_advance()


# --- Flujo del combate -------------------------------------------------------


func _advance() -> void:
	_busy = false
	_refresh()
	if engine.is_over():
		_show_result()
		return
	var ai := enemy_ai if engine.turn != player else player_ai
	if ai == null:
		if ui_driver != null:
			_drive_ui()
		return  # Turno del jugador: espera a que pulse algo.
	_busy = true
	_refresh()
	await get_tree().create_timer(0.3 / speed).timeout
	var action := ai.choose_action(engine)
	if action != null:
		_perform(action)


func _perform(action: BattleAction) -> void:
	_busy = true
	_teleport_mode = false
	_refresh()
	var reason := engine.apply(action)
	if reason != "":
		push_warning("accion rechazada: %s" % reason)
	await _play_new_events()
	_advance.call_deferred()


func _play_new_events() -> void:
	while _shown < engine.events.size():
		var entry := engine.events[_shown]
		_shown += 1
		await _play_event(entry)
		event_played.emit(entry)


func _play_event(entry: Dictionary) -> void:
	var actor: int = entry["actor"]
	var target := 1 - actor
	var snapshot: Array = entry["state"]
	var event: String = entry["event"]
	var step := STEP_SECONDS / speed
	var line := _log_line(entry)
	if entry.get("shielded", false):
		line += " · %s" % Txt.t("log_shielded")
	if line != "":
		_log.append_text(line + "\n")

	match event:
		"weapon", "stomp", "charge", "hook", "teleport", "drone":
			# Primero se mueve quien ataca (embestida, salto, espada).
			var attacker_cell: int = snapshot[actor]["pos"]
			if attacker_cell != _state[actor]["pos"]:
				await _approach(event, entry, actor, _arena.cell_point(attacker_cell), step)
				_arena.update_facing()
			if event == "hook":
				_arena.cable(actor, target, step * 1.6)
			var shot_color := _shot_color(entry, actor)
			if event == "drone":
				await _arena.fire_between(actor, target, shot_color, step, true)
			elif _is_ranged(entry, actor):
				await _arena.fire_between(actor, target, shot_color, step, false)
			else:
				_arena.mechs[actor].lunge(step)
			var damage: int = entry.get("damage", 0)
			if entry.get("shielded", false):
				_arena.float_text(_state[target]["pos"], Txt.t("shield_hit"), COLOR_COOL)
			if damage > 0:
				_arena.mechs[target].hit(step)
				_arena.shake(clampf(damage / 30.0, 2.0, 9.0))
				_arena.float_text(_state[target]["pos"], "-%d" % damage, COLOR_DAMAGE)
			var heat_gain: int = snapshot[target]["heat"] - _state[target]["heat"]
			if heat_gain > 0:
				_arena.float_text(_state[target]["pos"], "+%d" % heat_gain, COLOR_HEAT)
			await get_tree().create_timer(step).timeout
			# Despues, empujes, jalones y retrocesos.
			for i in 2:
				var cell: int = snapshot[i]["pos"]
				if cell != _state[i]["pos"] or _arena.mechs[i].position != _arena.cell_point(cell):
					# Al rival lo empujan o lo arrastran; quien dispara retrocede.
					if i == target:
						_arena.mechs[i].knockback_to(_arena.cell_point(cell), step * 0.9)
					else:
						_arena.mechs[i].hop_back(_arena.cell_point(cell), step * 0.9)
			await get_tree().create_timer(step * 0.9).timeout
		"walk":
			var destination := _arena.cell_point(entry["to"])
			if _is_jump(entry, actor):
				await _arena.mechs[actor].jump_to(destination, step).finished
				_arena.dust(destination, step * 0.6)
			else:
				await _arena.mechs[actor].move_to(destination, step).finished
		"cool", "forced_cool", "shutdown":
			var amount: int = entry.get("amount", 0)
			_arena.float_text(_state[actor]["pos"], "-%d" % amount, COLOR_COOL)
			if event == "shutdown":
				_arena.mechs[actor].set_heat(1.0, true)
				await get_tree().create_timer(step * 2.0).timeout
			else:
				await get_tree().create_timer(step).timeout
		"regen":
			pass
		"repair":
			_arena.float_text(_state[actor]["pos"], "+%d" % entry["amount"], COLOR_REPAIR)
			await get_tree().create_timer(step).timeout
		"evade":
			var who: int = entry["who"]
			await _arena.mechs[who].blink_to(_arena.cell_point(entry["to"]), step).finished
		"drop_spawn":
			await _arena.ship_drop(entry["drop"], step * 1.6)
		"drop_taken":
			var percent := roundi(float(entry["amount"]) * 100.0)
			var label := "+%d %% %s" % [percent, Txt.t("drop_%s_short" % entry["kind"])]
			_arena.float_text(snapshot[entry["who"]]["pos"], label, COLOR_DROP)
			await get_tree().create_timer(step).timeout
		"win":
			var loser := 1 - int(entry["winner"])
			_arena.explode(_arena.mechs[loser].hit_point(), step * 2.0)
			await _arena.mechs[loser].destroy(step * 2.0).finished

	_state = [snapshot[0], snapshot[1]]
	# Cada evento trae la bonificacion que queda en la arena tras el.
	_arena.set_drop(entry.get("drop", {}))
	_arena.update_facing()
	_show_state()


## Como llega el atacante junto al rival antes de golpear, segun la jugada:
## el teletransporte aparece, la embestida arranca de golpe y la espada salta.
## Las armas que retroceden o avanzan se mueven despues del disparo.
func _approach(event: String, entry: Dictionary, actor: int, point: Vector2, step: float) -> void:
	var mover := _arena.mechs[actor]
	match event:
		"teleport":
			await mover.blink_to(point, step).finished
		"charge":
			await mover.dash_to(point, step * 0.6).finished
		"weapon":
			var def := _event_def(entry, actor)
			if def != null and def.has_tag(ItemDef.TAG_SWORD):
				await mover.jump_to(point, step * 0.8).finished
				_arena.dust(point, step * 0.5)
		_:
			await mover.move_to(point, step).finished


## Un movimiento es un salto si va mas lejos de lo que el mech anda o si
## pasa por encima del rival (reglas del original).
func _is_jump(entry: Dictionary, actor: int) -> bool:
	var from: int = entry["from"]
	var to: int = entry["to"]
	var rival: int = _state[1 - actor]["pos"]
	var walk: int = engine.mechs[actor].slots["legs"].def.walk
	return absi(to - from) > walk or (from - rival) * (to - rival) < 0


## Pieza con la que se hizo la jugada de un evento, o null.
func _event_def(entry: Dictionary, actor: int) -> ItemDef:
	var slot: String = entry.get("slot", "")
	if slot != "" and engine.mechs[actor].slots.has(slot):
		return engine.mechs[actor].slots[slot].def
	return null


## Las armas que no son cuerpo a cuerpo disparan un proyectil.
func _is_ranged(entry: Dictionary, actor: int) -> bool:
	var def := _event_def(entry, actor)
	return entry["event"] == "weapon" and def != null and not def.has_tag(ItemDef.TAG_MELEE)


func _shot_color(entry: Dictionary, actor: int) -> Color:
	var def := _event_def(entry, actor)
	return MechView.ELEMENT_COLORS[def.element] if def != null else Color.WHITE


## Juega el turno del jugador usando los controles de la interfaz.
func _drive_ui() -> void:
	var pause := 0.5 / speed
	await get_tree().create_timer(pause).timeout
	var action := ui_driver.choose_action(engine)
	if action == null or not _can_act():
		return
	match action.type:
		BattleAction.Type.WALK:
			_on_cell_hovered(action.position)
			preview_shown.emit()
			await get_tree().create_timer(pause).timeout
			_on_cell_clicked(action.position)
		BattleAction.Type.TELEPORT:
			_on_teleport_requested()
			preview_shown.emit()
			await get_tree().create_timer(pause).timeout
			_on_cell_clicked(action.position)
		_:
			_on_action_hovered(action)
			preview_shown.emit()
			await get_tree().create_timer(pause).timeout
			_on_action_chosen(action)


# --- Entrada del jugador -----------------------------------------------------


func _on_action_chosen(action: BattleAction) -> void:
	if _can_act() and engine.why_illegal(action) == "":
		_perform(action)


func _on_teleport_requested() -> void:
	if not _can_act():
		return
	_teleport_mode = not _teleport_mode
	_refresh()


func _on_cell_clicked(cell: int) -> void:
	if not _can_act():
		return
	if _teleport_mode:
		if cell in engine.teleportable_positions():
			_perform(BattleAction.teleport(cell))
	elif cell in engine.walkable_positions():
		_perform(BattleAction.walk(cell))


func _on_action_hovered(action: BattleAction) -> void:
	if action == null or engine == null or not _can_act():
		_preview.text = ""
		return
	_preview.text = _preview_text(action)


func _on_cell_hovered(cell: int) -> void:
	if cell < 0 or engine == null or not _can_act():
		return
	if not _teleport_mode and cell in engine.walkable_positions():
		var distance := absi(cell - engine.mechs[1 - player].position)
		_preview.text = Txt.t("preview_move", [cell, distance])


func _can_act() -> bool:
	return not _busy and not engine.is_over() and engine.turn == player and player_ai == null


# --- Dibujo ------------------------------------------------------------------


func _refresh() -> void:
	if engine == null:
		return
	var mine := engine.turn == player
	var whose := Txt.t("your_turn") if mine else Txt.t("rival_turn")
	_turn_label.text = Txt.t("turn_of", [engine.turn_number, whose])
	_actions_label.text = Txt.t("actions_left", [engine.actions_left])
	var can_act := _can_act()
	_action_bar.refresh(can_act, _reason_for, _uses_left_for)
	var highlights := {}
	if can_act:
		if _teleport_mode:
			for cell in engine.teleportable_positions():
				highlights[cell] = COLOR_TELEPORT
			_hint_label.text = Txt.t("teleport_hint")
		else:
			for cell in engine.walkable_positions():
				highlights[cell] = COLOR_WALK
			_hint_label.text = Txt.t("walk_hint")
	else:
		_hint_label.text = "" if engine.is_over() or mine else Txt.t("thinking")
	_arena.set_highlights(highlights)


func _show_state() -> void:
	for i in 2:
		var state := _state[i]
		_panels[i].show_state(state, engine.mechs[i].max_health)
		var ratio := float(state["heat"]) / float(maxi(state["heat_cap"], 1))
		_arena.mechs[i].set_heat(ratio)


func _place_mechs() -> void:
	for i in 2:
		_arena.mechs[i].place(_arena.cell_point(_state[i]["pos"]))
	_arena.update_facing()


func _show_result() -> void:
	var won := engine.winner == player
	_result_label.text = Txt.t("victory") if won else Txt.t("defeat")
	_result_label.add_theme_color_override(
		"font_color", Color("7dff9b") if won else Color("ff7d7d")
	)
	_result.show()
	finished.emit(won)


## Linea bajo el resultado: lo que el jugador cobra o pierde con el combate.
func set_result_note(text: String) -> void:
	_result_note.text = text
	_result_note.visible = text != ""


func _live_state(index: int) -> Dictionary:
	var m := engine.mechs[index]
	return {
		"pos": m.position,
		"health": m.health,
		"heat": m.heat,
		"energy": m.energy,
		"heat_cap": m.heat_cap,
		"energy_cap": m.energy_cap,
		"cooling": m.cooling,
		"regen": m.energy_regen,
		"res": m.res.duplicate(),
	}


func _reason_for(action: BattleAction) -> String:
	if action.type == BattleAction.Type.TELEPORT:
		return engine.why_cant_use(engine.mechs[player], engine.mechs[1 - player], "teleport")
	return engine.why_illegal(action)


func _uses_left_for(action: BattleAction) -> int:
	var key := _slot_of(action)
	var slots := engine.mechs[player].slots
	return slots[key].uses_left if slots.has(key) else -1


func _slot_of(action: BattleAction) -> String:
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


func _preview_text(action: BattleAction) -> String:
	var mine := engine.mechs[player]
	var foe := engine.mechs[1 - player]
	if action.type == BattleAction.Type.COOL:
		return Txt.t("preview_cool", [mine.heat, maxi(0, mine.heat - mine.cooling)])
	var key := _slot_of(action)
	var def := mine.slots[key].def
	var title := "[b]%s[/b]" % def.display_name
	if action.type == BattleAction.Type.TELEPORT:
		return "%s\n%s" % [title, Txt.t("teleport_hint")]
	var reason := engine.why_illegal(action)
	if reason != "":
		return "%s\n%s" % [title, Txt.t("illegal", [reason])]
	var p := engine.preview(action)
	var lines: Array[String] = [title]
	if p["dmg_max"] > 0:
		lines.append(Txt.t("preview_damage", [p["dmg_min"], p["dmg_max"]]))
	else:
		lines.append(Txt.t("preview_no_damage"))
	if def.backfire > 0:
		lines.append(Txt.t("preview_backfire", [def.backfire]))
	lines.append(
		Txt.t("preview_self", [p["self_heat"], mine.heat_cap, p["self_energy"], mine.energy_cap])
	)
	lines.append(
		Txt.t(
			"preview_target", [p["target_heat"], foe.heat_cap, p["target_energy"], foe.energy_cap]
		)
	)
	if p["self_overheats"]:
		lines.append("[color=#ff6b5a]%s[/color]" % Txt.t("preview_self_overheat"))
	if p["target_overheats"]:
		lines.append("[color=#7dff9b]%s[/color]" % Txt.t("preview_target_overheat"))
	return "\n".join(lines)


## Lineas del registro de las habilidades de jefe (GDD 9.1).
func _ability_line(entry: Dictionary) -> String:
	if entry["event"] == "repair":
		var repair_args := [names[entry["actor"]], entry["amount"]]
		return "[color=#7dff9b]%s[/color]" % Txt.t("log_repair", repair_args)
	return Txt.t("log_evade", [names[entry["who"]], entry["to"]])


func _log_line(entry: Dictionary) -> String:
	var actor: int = entry["actor"]
	var who := names[actor]
	var item := ""
	var slot: String = entry.get("slot", "")
	if slot != "" and engine.mechs[actor].slots.has(slot):
		item = engine.mechs[actor].slots[slot].def.display_name
	var damage: int = entry.get("damage", 0)
	if entry["event"] in ["repair", "evade"]:
		return _ability_line(entry)
	match entry["event"]:
		"weapon":
			return Txt.t("log_weapon", [who, item, damage])
		"stomp":
			return Txt.t("log_stomp", [who, damage])
		"drone":
			return Txt.t("log_drone", [who, item, damage])
		"charge":
			return Txt.t("log_charge", [who, damage])
		"hook":
			return Txt.t("log_hook", [who, damage])
		"teleport":
			return Txt.t("log_teleport", [who, entry.get("to", 0), damage])
		"walk":
			return Txt.t("log_walk", [who, entry["from"], entry["to"]])
		"cool":
			return Txt.t("log_cool", [who, entry["amount"]])
		"forced_cool":
			return "[color=#ffb37a]%s[/color]" % Txt.t("log_forced", [who, entry["amount"]])
		"shutdown":
			return "[color=#ff6b5a]%s[/color]" % Txt.t("log_shutdown", [who, entry["amount"]])
		"drop_spawn":
			var spawn_args := [Txt.t("drop_" + entry["kind"]), entry["cell"]]
			return "[color=#ffe27a]%s[/color]" % Txt.t("log_drop_spawn", spawn_args)
		"drop_taken":
			var taken_args := [names[entry["who"]], Txt.t("drop_" + entry["kind"])]
			taken_args.append(roundi(float(entry["amount"]) * 100.0))
			taken_args.append(entry["turns"])
			return "[color=#ffe27a]%s[/color]" % Txt.t("log_drop_taken", taken_args)
		"buff_end":
			return Txt.t("log_buff_end", [names[entry["who"]], Txt.t("drop_" + entry["kind"])])
		"win":
			return "[b]%s[/b]" % Txt.t("log_win", [names[entry["winner"]]])
	return ""


# --- Construccion de la interfaz ---------------------------------------------


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Arriba: panel del jugador, turno y panel del rival.
	var top := HBoxContainer.new()
	root.add_child(top)
	_panels.append(StatPanel.new())
	top.add_child(_panels[0])
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(center)
	_turn_label = _label(center, 22)
	_actions_label = _label(center, 16)
	_hint_label = _label(center, 14)
	_hint_label.add_theme_color_override("font_color", Color("9fb0c3"))
	_panels.append(StatPanel.new())
	top.add_child(_panels[1])

	# Centro: la arena.
	_arena = ArenaView.new()
	_arena.set_stage(stage)
	_arena.custom_minimum_size = Vector2(0, 340)
	_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arena.cell_clicked.connect(_on_cell_clicked)
	_arena.cell_hovered.connect(_on_cell_hovered)
	root.add_child(_arena)

	# Abajo: registro, prevision y acciones.
	var bottom := HBoxContainer.new()
	bottom.custom_minimum_size = Vector2(0, 220)
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(400, 0)
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_font_size_override("bold_font_size", 13)
	bottom.add_child(_log)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(right)
	_preview = RichTextLabel.new()
	_preview.bbcode_enabled = true
	_preview.custom_minimum_size = Vector2(0, 92)
	_preview.add_theme_font_size_override("normal_font_size", 14)
	_preview.add_theme_font_size_override("bold_font_size", 15)
	right.add_child(_preview)
	_action_bar = ActionBar.new()
	_action_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_bar.action_chosen.connect(_on_action_chosen)
	_action_bar.teleport_requested.connect(_on_teleport_requested)
	_action_bar.action_hovered.connect(_on_action_hovered)
	right.add_child(_action_bar)

	# Resultado, centrado sobre la arena.
	_result = PanelContainer.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result.custom_minimum_size = Vector2(360, 170)
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color("141c27")
	result_style.border_color = Color("5a6f88")
	result_style.set_border_width_all(2)
	result_style.set_corner_radius_all(8)
	result_style.set_content_margin_all(18)
	_result.add_theme_stylebox_override("panel", result_style)
	_result.position -= _result.custom_minimum_size / 2.0
	add_child(_result)
	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 14)
	_result.add_child(result_box)
	_result_label = _label(result_box, 44)
	_result_note = _label(result_box, 18)
	_result_note.hide()
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	result_box.add_child(buttons)
	var rematch := Button.new()
	rematch.text = rematch_text if rematch_text != "" else Txt.t("rematch")
	rematch.visible = allow_rematch
	rematch.custom_minimum_size = Vector2(130, 42)
	rematch.pressed.connect(func() -> void: rematch_requested.emit())
	buttons.add_child(rematch)
	var menu := Button.new()
	menu.text = Txt.t("menu")
	menu.custom_minimum_size = Vector2(130, 42)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	buttons.add_child(menu)
	_result.hide()


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
