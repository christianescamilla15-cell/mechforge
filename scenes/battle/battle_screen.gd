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
const COLOR_DARK_MATTER := Color("b07bff")
const COLOR_CRIT := Color("ffd23d")
const COLOR_WARNING := Color("ff9a7d")
## Parte de la vida del rival desde la que el golpe de un arma de hombro es
## un impacto medio y no ligero.
const MEDIUM_IMPACT_SHARE := 0.07

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
## Cuanto tardo la IA en decidir cada accion, en ms (para tools/fps.ps1).
var ai_think_ms: PackedFloat32Array = []
## Ajustes del jugador: con ellos la pausa deja abrirlos y la velocidad los
## sigue. Sin ellos (pruebas en vivo) la pausa no los ensena.
var settings: GameSettings
## Donde se guardan los ajustes; vacio = no se guardan.
var settings_path: String = ""
## Rendirse contra un jefe acaba la partida: la pausa lo avisa.
var surrender_ends_run: bool = false
## Tarea del WorkerThreadPool en la que piensa la IA; -1 si no hay ninguna.
var _ai_task: int = -1
var _pause: Control
var _pause_resume: Button
var _pause_settings: Button
var _surrender_button: Button
var _paused: bool = false
## Primer clic en Rendirse: pide confirmacion.
var _surrender_armed: bool = false
var _surrendered: bool = false

var _arena: ArenaView
## Lo unico que hay encima de la arena: las armas en el robot, sus rayitas
## de vida, calor y energia y el rotulo del turno (BattleHud).
var _hud: BattleHud
## De quien era el turno la ultima vez que se anuncio, y lo que ensena el
## HUD de turno y acciones (va por detras del motor mientras se anima).
var _announced: int = -1
var _hud_turn: int = -1
var _hud_actions: int = 0
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
	difficulty: BattleAI.Difficulty,
	temper: AIConfig = null
) -> void:
	rules = p_rules
	# Con su caracter, si el rival lo tiene (TemperLibrary).
	enemy_ai = BattleAI.new(difficulty, seed_value + 1, temper)
	engine = BattleEngine.new(rules, build_player, build_enemy, seed_value, seed_value % 2)
	_shown = 0
	_busy = true
	_teleport_mode = false
	_surrendered = false
	_paused = false
	Engine.time_scale = 1.0
	_pause.hide()
	_result.hide()
	set_result_note("")
	_arena.cells = rules.arena_size
	for i in 2:
		_arena.mechs[i].setup(engine.mechs[i].build, 1 if i == 0 else -1)
	_hud.player = player
	_hud.build_for(engine.mechs[player])
	_announced = -1
	_hud_turn = -1
	# Espera a que el contenedor tenga tamano antes de colocar los mechs.
	await get_tree().process_frame
	await get_tree().process_frame
	_state = [_live_state(0), _live_state(1)]
	# Los eventos previos a la primera accion (por ejemplo, una regeneracion)
	# se dan por mostrados: el estado inicial ya los incluye.
	_shown = engine.events.size()
	_place_mechs()
	_show_state()
	# El combate empieza con su rotulo, y el del primer turno llega despues.
	_hud.announce(Txt.t("battle_start"), BattleHud.GOLD, names[1 - player])
	await get_tree().create_timer(0.9 / speed).timeout
	_advance()


# --- Flujo del combate -------------------------------------------------------


func _advance() -> void:
	if _surrendered:
		return
	_busy = false
	_hud_turn = engine.turn
	_hud_actions = engine.actions_left
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
	var action := await _think(ai)
	if action != null and not _surrendered:
		_perform(action)


## La IA piensa en un hilo aparte, sobre su propia copia del combate, para
## que la imagen no se congele: contra un jefe una decision tarda hasta unos
## 150 ms. Empieza a pensar durante la pausa de siempre antes de actuar, asi
## que casi nunca se espera de mas. Da la misma accion que pensar aqui.
func _think(ai: BattleAI) -> BattleAction:
	var copy := engine.clone(false)
	var result: Array = [null, 0.0]
	_ai_task = WorkerThreadPool.add_task(
		func() -> void:
			var started := Time.get_ticks_usec()
			result[0] = ai.choose_action(copy)
			result[1] = (Time.get_ticks_usec() - started) / 1000.0
	)
	await get_tree().create_timer(0.3 / speed).timeout
	while not WorkerThreadPool.is_task_completed(_ai_task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(_ai_task)
	_ai_task = -1
	ai_think_ms.append(result[1])
	return result[0]


## Si se cierra la pantalla mientras la IA piensa, se espera a que acabe; y
## si estaba en pausa, el tiempo vuelve a correr.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if _ai_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ai_task)
		_ai_task = -1


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
	if entry.get("shielded", false):
		Sfx.play("escudo")

	match event:
		"weapon", "stomp", "charge", "hook", "teleport", "drone":
			_event_sound(event)
			# Primero se mueve quien ataca (embestida, salto, espada).
			var attacker_cell: int = snapshot[actor]["pos"]
			if attacker_cell != _state[actor]["pos"]:
				await _approach(event, entry, actor, _arena.cell_point(attacker_cell), step)
				_arena.update_facing()
			if event == "hook":
				_arena.cable(actor, target, step * 1.6)
			var shot_color := _shot_color(entry, actor)
			var def := _event_def(entry, actor)
			var fx := def.fx if def != null else ""
			if event == "drone":
				var drone_slot: String = entry.get("slot", "drone")
				await _arena.fire_between(actor, target, fx, shot_color, step, true, drone_slot)
			elif _is_ranged(entry, actor):
				var slot: String = entry.get("slot", "")
				await _arena.fire_between(actor, target, fx, shot_color, step, false, slot)
			else:
				var blade := str(entry.get("slot", ""))
				await _arena.strike(actor, target, fx, shot_color, step, blade)
			var damage: int = entry.get("damage", 0)
			if entry.get("shielded", false):
				_arena.float_text(_state[target]["pos"], Txt.t("shield_hit"), COLOR_COOL)
			if damage > 0:
				_arena.mechs[target].hit(step)
				_arena.impact(target, _impact_tier(def, damage, target), step)
				_arena.float_text(_state[target]["pos"], "-%d" % damage, COLOR_DAMAGE)
			if entry.get("crit", false):
				# Critico (GDD 2.9): aviso y lo que le hace al rival.
				Sfx.play("critico")
				_arena.shake(12.0)
				var cell: int = _state[target]["pos"]
				_arena.float_text(cell, Txt.t("crit_hit"), COLOR_CRIT)
				_arena.float_text(cell, Txt.t("crit_" + str(entry["crit_effect"])), COLOR_CRIT)
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
						# Un impacto grave lo arrastra mas lejos: tarda mas.
						var knock: int = entry.get("knock", 1)
						var slide := step * (0.9 + 0.25 * maxi(0, knock - 1))
						_arena.mechs[i].knockback_to(_arena.cell_point(cell), slide)
					else:
						_arena.mechs[i].hop_back(_arena.cell_point(cell), step * 0.9)
			var sliding: int = entry.get("knock", 1)
			await get_tree().create_timer(step * (0.9 + 0.25 * maxi(0, sliding - 1))).timeout
		"walk":
			var destination := _arena.cell_point(entry["to"])
			if _is_jump(entry, actor):
				Sfx.play("propulsor")
				await _arena.mechs[actor].jump_to(destination, step).finished
				_arena.dust(destination, step * 0.6)
			else:
				Sfx.play("paso")
				Sfx.play("paso", step * 0.5)
				await _arena.mechs[actor].move_to(destination, step).finished
		"cool", "forced_cool", "shutdown":
			var amount: int = entry.get("amount", 0)
			_arena.float_text(_state[actor]["pos"], "-%d" % amount, COLOR_COOL)
			Sfx.play("apagado" if event == "shutdown" else "enfriar")
			if event == "shutdown":
				_arena.mechs[actor].set_heat(1.0, true)
				await get_tree().create_timer(step * 2.0).timeout
			else:
				await get_tree().create_timer(step).timeout
		"regen":
			pass
		"repair":
			Sfx.play("reparar")
			_arena.float_text(_state[actor]["pos"], "+%d" % entry["amount"], COLOR_REPAIR)
			await get_tree().create_timer(step).timeout
		"evade":
			var who: int = entry["who"]
			Sfx.play("esquiva")
			await _arena.mechs[who].blink_to(_arena.cell_point(entry["to"]), step).finished
		"drop_spawn":
			Sfx.play("nave")
			await _arena.ship_drop(entry["drop"], step * 1.6)
		"barrier":
			Sfx.play("escudo")
			_arena.float_text(_state[actor]["pos"], Txt.t("shield_hit"), COLOR_COOL)
			_arena.flash(_arena.mechs[actor].hit_point(), COLOR_COOL, 90.0, step)
			await get_tree().create_timer(step).timeout
		"repair_kit":
			Sfx.play("reparar")
			var healed := "+%d" % entry["amount"]
			_arena.float_text(_state[actor]["pos"], healed, COLOR_REPAIR)
			await get_tree().create_timer(step).timeout
		"dark_matter":
			# La ultima arma (GDD 2.10): secuencia propia segun el tipo del arma
			# de pecho, y el rival sale despedido hasta el borde.
			var chest_type := ""
			if engine.mechs[actor].slots.has("chest"):
				chest_type = engine.mechs[actor].slots["chest"].def.weapon_type
			await _arena.dark_matter(actor, target, chest_type, COLOR_DARK_MATTER, step)
			_arena.mechs[target].hit(step)
			var cell: int = _state[target]["pos"]
			_arena.float_text(cell, "-%d" % entry["damage"], COLOR_DARK_MATTER)
			if entry.get("crit", false):
				Sfx.play("critico")
				_arena.float_text(cell, Txt.t("crit_hit"), COLOR_CRIT)
				_arena.float_text(cell, Txt.t("crit_" + str(entry["crit_effect"])), COLOR_CRIT)
			await get_tree().create_timer(step).timeout
			var edge: int = snapshot[target]["pos"]
			if edge != cell:
				var away := _arena.cell_point(edge)
				await _arena.mechs[target].knockback_to(away, step * 2.6).finished
				_arena.dust(away, step)
			await get_tree().create_timer(step * 0.8).timeout
		"drop_taken":
			Sfx.play("bonificacion")
			var percent := roundi(float(entry["amount"]) * 100.0)
			var label := "+%d %% %s" % [percent, Txt.t("drop_%s_short" % entry["kind"])]
			_arena.float_text(snapshot[entry["who"]]["pos"], label, COLOR_DROP)
			await get_tree().create_timer(step).timeout
		"win":
			var loser := 1 - int(entry["winner"])
			Sfx.play("destruido")
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


## Tramo del impacto de un golpe (GDD 2.10): las armas de brazo (y las
## piernas y el asistente) ligero; las de hombro de ligero a medio segun el
## dano que hacen frente a la vida del rival; las de pecho grave.
func _impact_tier(def: ItemDef, damage: int, target: int) -> String:
	if def == null:
		return "light"
	match def.type:
		ItemDef.Type.CHEST:
			return "heavy"
		ItemDef.Type.TOP:
			var share := float(damage) / float(maxi(engine.mechs[target].max_health, 1))
			return "medium" if share >= MEDIUM_IMPACT_SHARE else "light"
	return "light"


## Las armas que no son cuerpo a cuerpo disparan un proyectil.
func _is_ranged(entry: Dictionary, actor: int) -> bool:
	var def := _event_def(entry, actor)
	return entry["event"] == "weapon" and def != null and not def.has_tag(ItemDef.TAG_MELEE)


func _shot_color(entry: Dictionary, actor: int) -> Color:
	var def := _event_def(entry, actor)
	return ShotFx.ammo_color(def.element) if def != null else Color.WHITE


## Juega el turno del jugador usando los controles de la interfaz.
func _drive_ui() -> void:
	var pause := 0.5 / speed
	await get_tree().create_timer(pause).timeout
	var action := ui_driver.choose_action(engine)
	if action == null or not _can_act():
		return
	match action.type:
		BattleAction.Type.WALK:
			preview_shown.emit()
			await get_tree().create_timer(pause).timeout
			_on_cell_clicked(action.position)
		BattleAction.Type.TELEPORT:
			_on_teleport_requested()
			preview_shown.emit()
			await get_tree().create_timer(pause).timeout
			_on_cell_clicked(action.position)
		_:
			# "Pasa el raton" por la accion: el abanico se abre con su tarjeta.
			_hud.demo(action)
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


func _can_act() -> bool:
	return (
		not _busy
		and not _paused
		and not _surrendered
		and not engine.is_over()
		and engine.turn == player
		and player_ai == null
	)


# --- Dibujo ------------------------------------------------------------------


func _refresh() -> void:
	if engine == null:
		return
	var can_act := _can_act()
	# Con la baliza en la mano se ve la arena entera, para saltar a donde sea
	# (OBS-035): el rival elige entre todas las casillas, y el jugador tambien.
	_arena.overview = _teleport_mode and can_act
	_hud.refresh(can_act, _reason_for, _uses_left_for)
	if engine.turn != _announced and not engine.is_over() and not _surrendered:
		# El turno no esta fijo en pantalla: se anuncia al cambiar y se va.
		_announced = engine.turn
		var mine := engine.turn == player
		var words := Txt.t("your_turn" if mine else "rival_turn").to_upper()
		_hud.announce(words, BattleHud.GOLD if mine else COLOR_WARNING)
	var highlights := {}
	if can_act:
		var tint := COLOR_TELEPORT if _teleport_mode else COLOR_WALK
		var cells := (
			engine.teleportable_positions() if _teleport_mode else engine.walkable_positions()
		)
		for cell in cells:
			highlights[cell] = tint
	_arena.set_highlights(highlights)
	_show_state()


func _show_state() -> void:
	var vitals: Array[Dictionary] = []
	for i in 2:
		var state := _state[i]
		var health := float(state["health"]) / float(maxi(engine.mechs[i].max_health, 1))
		var energy := float(state["energy"]) / float(maxi(state["energy_cap"], 1))
		var stuck: bool = state.get("immobilized", false)
		var disabled: String = state.get("disabled", "")
		_arena.mechs[i].set_condition(health, energy, stuck, disabled, state.get("stunned", false))
		var ratio := float(state["heat"]) / float(maxi(state["heat_cap"], 1))
		_arena.mechs[i].set_heat(ratio)
		vitals.append({"health": health, "heat": ratio, "energy": energy, "over": ratio > 1.0})
	_hud.show_state(vitals, _hud_turn, _hud_actions)


func _place_mechs() -> void:
	for i in 2:
		_arena.mechs[i].place(_arena.cell_point(_state[i]["pos"]))
	_arena.update_facing()


func _show_result() -> void:
	_show_outcome(engine.winner == player)


func _show_outcome(won: bool) -> void:
	Sfx.jingle("victoria" if won else "derrota")
	_result_label.text = Txt.t("victory") if won else Txt.t("defeat")
	_result_label.add_theme_color_override(
		"font_color", Color("7dff9b") if won else Color("ff7d7d")
	)
	_result.show()
	finished.emit(won)


## Linea bajo el resultado: lo que el jugador cobra o pierde con el combate.
func set_result_note(text: String) -> void:
	if _surrendered:
		text = Txt.t("surrendered") + (String.chr(10) + text if text != "" else "")
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
	var kinds := {
		BattleAction.Type.SHIELD: "shield",
		BattleAction.Type.REPAIR: "repair",
		BattleAction.Type.DARK_MATTER: "dark_matter",
	}
	if kinds.has(action.type):
		return engine.mechs[player].kits_left(kinds[action.type])
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


## La tarjeta de una accion del abanico (BattleHud.card_for): su nombre y, en
## pequeno, su dano, su critico, lo que cuesta y, si no se puede usar, por que.
func _card_for(action: BattleAction) -> Dictionary:
	var mine := engine.mechs[player]
	var lines: Array = []
	var title := ""
	var key := _slot_of(action)
	var def: ItemDef = mine.slots[key].def if mine.slots.has(key) else null
	match action.type:
		BattleAction.Type.COOL:
			title = Txt.t("cool")
			lines.append(
				[Txt.t("card_cool", [mine.heat, maxi(0, mine.heat - mine.cooling)]), COLOR_COOL]
			)
		BattleAction.Type.SHIELD:
			title = Txt.t("ability_shield")
			lines.append([Txt.t("card_shield"), COLOR_COOL])
		BattleAction.Type.REPAIR:
			title = Txt.t("ability_repair")
			lines.append([Txt.t("card_repair"), COLOR_REPAIR])
		BattleAction.Type.DARK_MATTER:
			title = Txt.t("ability_dark_matter")
		BattleAction.Type.STOMP:
			title = Txt.t("stomp")
		_:
			title = def.display_name if def != null else ""
	var my_turn := engine.turn == player and not engine.is_over()
	var reason := _reason_for(action) if my_turn else ""
	if my_turn and reason == "" and action.type != BattleAction.Type.TELEPORT:
		# Lo que hara de verdad ahora, contra este rival.
		var p := engine.preview(action)
		if p["dmg_max"] > 0:
			lines.append([Txt.t("card_damage", [p["dmg_min"], p["dmg_max"]]), BattleHud.TEXT])
		# El escudo de un jefe que puede parar este golpe (OBS-041).
		var block: float = p.get("block_chance", 0.0)
		if block > 0.0:
			lines.append([Txt.t("card_block", [roundi(block * 100.0)]), COLOR_WARNING])
		var chance: float = p.get("crit_chance", 0.0)
		if chance > 0.0:
			var effect := Txt.t("crit_effect_" + str(p["crit_effect"]))
			lines.append([Txt.t("card_crit", [roundi(chance * 100.0), effect]), COLOR_CRIT])
		if p["self_overheats"]:
			lines.append([Txt.t("preview_self_overheat"), COLOR_WARNING])
		if p["target_overheats"]:
			lines.append([Txt.t("preview_target_overheat"), COLOR_REPAIR])
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
	var uses := _uses_left_for(action)
	if uses >= 0:
		lines.append([Txt.t("uses", [str(uses)]), BattleHud.MUTED])
	if reason.strip_edges() != "":
		lines.append([reason.capitalize() if reason.length() < 3 else reason, COLOR_WARNING])
	return {"title": title, "lines": lines}


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Toda la pantalla es el juego: la arena la ocupa entera y encima solo
	# va el HUD, que no tiene barras ni botones.
	_arena = ArenaView.new()
	_arena.set_stage(stage)
	_arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena.cell_clicked.connect(_on_cell_clicked)
	add_child(_arena)
	_hud = BattleHud.new()
	_hud.arena = _arena
	_hud.card_for = _card_for
	_hud.action_chosen.connect(_on_action_chosen)
	_hud.teleport_requested.connect(_on_teleport_requested)
	add_child(_hud)

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
	_build_pause()


## Lo que suena al empezar una jugada (los disparos suenan desde ShotFx).
func _event_sound(event: String) -> void:
	match event:
		"stomp":
			Sfx.play("pisoton")
		"charge":
			Sfx.play("propulsor")
		"hook":
			Sfx.play("arpon")
		"teleport":
			Sfx.play("salto")


# --- Pausa -------------------------------------------------------------------


## Pausa (Esc): congela el combate por encima de todo, con Continuar, Ajustes
## y Rendirse.
func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = SettingsPanel.COLOR_DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_stylebox_override("panel", SettingsPanel.frame_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_label(box, 40).text = Txt.t("pause_title")
	var hint := _label(box, 15)
	hint.text = Txt.t("pause_hint")
	hint.add_theme_color_override("font_color", SettingsPanel.COLOR_MUTED)
	_pause_resume = _pause_button(box, Txt.t("pause_resume"), set_paused.bind(false))
	_pause_settings = _pause_button(box, Txt.t("settings_open"), open_settings)
	_surrender_button = _pause_button(box, Txt.t("surrender"), surrender)
	_pause.hide()


func _pause_button(box: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	box.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if engine == null or _result.visible or _surrendered:
		return
	get_viewport().set_input_as_handled()
	set_paused(not _paused)


func is_paused() -> bool:
	return _paused


## Congela o suelta el combate: con la escala de tiempo a 0 se paran las
## animaciones, los temporizadores y la pausa antes de cada accion de la IA.
func set_paused(on: bool) -> void:
	if on and (_surrendered or _result.visible):
		return
	if on != _paused:
		Sfx.play("ui_abrir" if on else "ui_cerrar")
	_paused = on
	Engine.time_scale = 0.0 if on else 1.0
	_pause.visible = on
	_pause_settings.visible = settings != null
	_surrender_armed = false
	_surrender_button.text = Txt.t("surrender")
	_surrender_button.remove_theme_color_override("font_color")
	if on:
		_pause_resume.grab_focus()
	if engine != null:
		_refresh()


## Abre los ajustes encima de la pausa; la velocidad del combate los sigue.
func open_settings() -> void:
	if settings == null:
		return
	var panel := SettingsPanel.open(self, settings, settings_path)
	panel.changed.connect(func() -> void: speed = settings.speed())


## Rendirse cuenta como derrota. El primer clic pide confirmacion (contra un
## jefe avisa de que se acaba la partida); el segundo termina el combate.
## El motor no cambia: el combate se deja sin terminar y se da por perdido.
func surrender() -> void:
	if _surrendered or _result.visible:
		return
	if not _surrender_armed:
		_surrender_armed = true
		_surrender_button.text = Txt.t(
			"surrender_confirm_boss" if surrender_ends_run else "surrender_confirm"
		)
		_surrender_button.add_theme_color_override("font_color", COLOR_WARNING)
		return
	_surrendered = true
	set_paused(false)
	_busy = true
	_refresh()
	set_result_note("")
	_show_outcome(false)


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
