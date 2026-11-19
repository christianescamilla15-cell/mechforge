class_name LiveTest
extends Node
## Prueba en vivo automatica (tools/live.ps1, tools/fps.ps1, tools/clip.ps1):
## con `++ --autoplay` la IA juega por los dos lados en la ventana real, se
## guardan capturas de los momentos clave y se cierra el juego. Es una
## herramienta, no parte del juego: MainScreen solo la crea con esos
## argumentos.
## Con --ui, el lado del jugador actua a traves de los controles de la
## interfaz (prevision, botones y casillas), como lo haria una persona.
##   --player=<id> --enemy=<id> --tier=EPIC --seed=1 --speed=3
##   --fight=<n>  en vez de --enemy y --tier: el combate n de la primera zona,
##                contando desde 0 (el ultimo es el jefe); --level=<n> pone las
##                piezas del jugador en ese nivel de la clase Basica
##   --chest=<id> --skills=all   arma de pecho y todas las habilidades
##   --fps        mide los cuadros (FrameProbe) y lo que tarda la IA
##   --pause-test [--surrender]  prueba la pausa, los ajustes y rendirse
##   --record-audio  graba el canal general (audio.wav) y lo que pidio sonar
##                   el juego (sonidos.json), en la carpeta de capturas
## La carpeta de capturas se indica en la variable de entorno MECHFORGE_SHOTS.

const AUTOPLAY_TIMEOUT_SECONDS := 180.0

var main: MainScreen
var _shot_count: int = 0
var _shot_events: Dictionary = {}
var _probe: FrameProbe
var _record: AudioEffectRecord
var _record_start_ms: int = 0


func start_autoplay() -> void:
	print("AUTOPLAY argumentos: %s" % main._args)
	var ids := main._library.all_ids()
	var tier: ItemDef.Tier = ItemDef.Tier[main._args.get("tier", "EPIC")]
	var level := main._rules.tier_max_level[tier]
	var spec := {
		"mode": "free",
		"player": main._args.get("player", ids[0]),
		"items": {},
		"name": "",
		"enemy": main._args.get("enemy", ids[1]),
		"enemy_tier": tier,
		"enemy_level": level,
		"player_tier": tier,
		"player_level": level,
		"difficulty": 1,
		"seed": int(main._args.get("seed", "1")),
	}
	if main._args.has("fight"):
		# Un combate de la primera zona de la campana, con sus niveles y su
		# recompensa, sobre un perfil vacio que no se guarda.
		main._profile.fight = int(main._args["fight"])
		var fight := main._campaign.fight_at(0, main._profile.fight)
		spec["mode"] = "campaign"
		spec["zone"] = 0
		main._profile.parts = _uniform_parts(spec["player"], int(main._args.get("level", "0")))
		spec["enemy"] = fight["enemy"]
		spec["enemy_tier"] = main._campaign.tier_of(0)
		spec["enemy_level"] = int(fight["level"])
		spec["difficulty"] = MainScreen.DIFFICULTY_IDS.find(fight["difficulty"])
	for side: String in ["player", "enemy"]:
		if not spec[side] in ids:
			spec[side] = ids[0]
	spec["items"] = main._library.specs[spec["player"]]["items"].duplicate(true)
	# --chest=<id> monta un arma de pecho; --skills=all da todas las habilidades.
	if main._args.has("chest"):
		spec["items"]["chest"] = main._args["chest"]
	if main._args.get("skills", "") == "all":
		for branch in main._skills.branches:
			for node: Dictionary in branch["nodes"]:
				main._profile.skills.append(node["id"])
	spec["name"] = main._library.display_name(spec["player"])
	main._start_battle(spec)
	var driver := BattleAI.new(BattleAI.Difficulty.NORMAL, int(spec["seed"]) + 7)
	if main._args.has("ui"):
		# El jugador actua a traves de los controles de la interfaz.
		main._battle.ui_driver = driver
		main._battle.preview_shown.connect(_on_autoplay_preview)
	else:
		main._battle.player_ai = driver
	main._battle.speed = float(main._args.get("speed", "3"))
	main._battle.event_played.connect(_on_autoplay_event)
	main._battle.finished.connect(_on_autoplay_finished)
	if main._args.has("fps"):
		_probe = FrameProbe.new()
		add_child(_probe)
	if main._args.has("record-audio") and Sfx.current() != null:
		_record = AudioEffectRecord.new()
		AudioServer.add_bus_effect(AudioServer.get_bus_index("Master"), _record)
		_record.set_recording_active(true)
		_record_start_ms = Time.get_ticks_msec()
		Sfx.current().log_plays = true
	get_tree().create_timer(0.8).timeout.connect(shot.bind("inicio"))
	if main._args.has("pause-test"):
		# Tiempo real: la pausa para los temporizadores normales.
		get_tree().create_timer(3.0, true, false, true).timeout.connect(_autoplay_pause_test)
	# A menos velocidad el combate dura mas.
	var timeout := AUTOPLAY_TIMEOUT_SECONDS * maxf(1.0, 3.0 / main._battle.speed)
	get_tree().create_timer(timeout).timeout.connect(_on_autoplay_timeout)


## Piezas de un mech todas en clase Basica y ese nivel (para la prueba en vivo).
func _uniform_parts(mech: String, level: int) -> Dictionary[String, Dictionary]:
	var out: Dictionary[String, Dictionary] = {}
	if not main._library.specs.has(mech):
		return out
	for id in main._library.item_ids(mech):
		var def := main._catalog.get_item(id)
		var key := def.progress_id() if def != null else id
		out[key] = {"tier": ItemDef.Tier.COMMON, "level": level}
	return out


func _on_autoplay_event(entry: Dictionary) -> void:
	# Una captura la primera vez que pasa cada cosa interesante.
	var event: String = entry["event"]
	if entry.get("shielded", false) and not _shot_events.has("shielded"):
		_shot_events["shielded"] = true
		shot("escudo")
	if entry.get("crit", false) and not _shot_events.has("crit"):
		_shot_events["crit"] = true
		shot("critico")
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
			"evade",
			"barrier",
			"repair_kit",
			"dark_matter"
		]
	):
		if not _shot_events.has(event):
			_shot_events[event] = true
			shot(event)


## Prueba en vivo de la pausa (`--pause-test`): pausa, dos capturas
## separadas para ver que el combate esta congelado, los ajustes y, con
## `--surrender`, rendirse (dos clics); si no, sigue el combate.
func _autoplay_pause_test() -> void:
	if main._battle.engine.is_over():
		return
	main._battle.set_paused(true)
	print("AUTOPLAY pausa: escala de tiempo %.1f" % Engine.time_scale)
	await get_tree().create_timer(0.3, true, false, true).timeout
	await shot("pausa")
	await get_tree().create_timer(0.8, true, false, true).timeout
	await shot("pausa_congelada")
	main._battle.open_settings()
	await get_tree().create_timer(0.3, true, false, true).timeout
	await shot("pausa_ajustes")
	for child in main._battle.get_children():
		if child is SettingsPanel:
			child.close_panel()
	await get_tree().create_timer(0.3, true, false, true).timeout
	if main._args.has("surrender"):
		main._battle.surrender()
		await shot("rendirse_confirmar")
		main._battle.surrender()
	else:
		main._battle.set_paused(false)
		print("AUTOPLAY pausa: sigue, escala de tiempo %.1f" % Engine.time_scale)


## Prueba en vivo de la armeria (`--menu-shot=armeria`, con `--real-profile`
## sobre la partida de verdad, sin guardar nada): gasta en la armeria todo lo
## que deje la zona, comprueba que lo que para es el tope y no el dinero,
## ensena la tienda y sigue con la prueba del taller.
func armory_test() -> void:
	var profile := main._profile
	var level := main._player_level()
	print(
		(
			"ARMERIA celdas=%d zona=%d nivel=%d mejoras=%s"
			% [profile.gold, profile.zone + 1, level, profile.shop_levels]
		)
	)
	main._last["tab"] = 0
	main._show_menu()
	await get_tree().create_timer(0.6).timeout
	await shot("armeria_antes")
	var cap := main._armory_cap()
	var gold := profile.gold
	var changed := true
	while changed:
		changed = false
		for track in main._shop.track_ids():
			if profile.buy(main._shop, track, cap) == "":
				changed = true
	var reasons := {}
	for track in main._shop.track_ids():
		reasons[track] = (
			"%d: %s" % [profile.level_of(track), profile.why_cant_buy(main._shop, track, cap)]
		)
	print("ARMERIA tope=%d gastado=%d quedan=%d" % [cap, gold - profile.gold, profile.gold])
	print("ARMERIA por mejora: %s" % reasons)
	main._show_menu()
	await get_tree().create_timer(0.6).timeout
	await shot("armeria_tope")
	main._last["tab"] = 2
	main._show_menu()
	await get_tree().create_timer(0.6).timeout
	await shot("armeria_tienda")
	workshop_test(main.open_workshop())


## Prueba en vivo del taller (`--menu-shot=taller`): elegir un hueco, dejar
## un brazo vacio, comparar una pieza, arrastrar una pieza de verdad (con el
## raton simulado) al hueco vacio, subirla de nivel y probar el disparo.
func workshop_test(workshop: WorkshopScreen) -> void:
	await get_tree().create_timer(0.8).timeout
	await shot("taller")
	workshop.clear_slot("side0")
	await get_tree().create_timer(0.5).timeout
	await shot("taller_brazo_vacio")
	var cards: Array[PartCard] = []
	for node in workshop.find_children("*", "PartCard", true, false):
		cards.append(node as PartCard)
	print("TALLER piezas en la lista: %d" % cards.size())
	if not cards.is_empty():
		cards[0].hovered.emit(cards[0].item.id, true)
		await get_tree().create_timer(0.3).timeout
		await shot("taller_comparar")
		await _drag(cards[0], workshop._cells["side0"])
		await get_tree().create_timer(0.6).timeout
		print("TALLER brazo 1 tras arrastrar: %s" % Garage.get_slot(main._profile.build, "side0"))
		await shot("taller_arrastrado")
	# Un arma a distancia en nivel 0: se sube (destello) y se prueba.
	workshop.pick("side1")
	workshop.level_up_selected()
	await get_tree().create_timer(0.25).timeout
	await shot("taller_subir")
	workshop.test_fire()
	await get_tree().create_timer(0.12).timeout
	await shot("taller_probar")
	workshop.pick("torso")
	workshop.clear_slot("legs")
	await get_tree().create_timer(0.4).timeout
	await shot("taller_sin_piernas")
	get_tree().quit(0)


## Arrastra con el raton (eventos de verdad) del centro de un control a otro.
func _drag(from: Control, to: Control) -> void:
	var a := from.get_global_rect().get_center()
	var b := to.get_global_rect().get_center()
	_mouse_button(a, true)
	await get_tree().process_frame
	for i in range(1, 13):
		var motion := InputEventMouseMotion.new()
		motion.position = a.lerp(b, i / 12.0)
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await get_tree().process_frame
	_mouse_button(b, false)
	await get_tree().process_frame


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)


func _on_autoplay_preview() -> void:
	# Capturas de las tres primeras previsiones (resaltado de casillas incluido).
	var count: int = _shot_events.get("preview", 0)
	if count < 3:
		_shot_events["preview"] = count + 1
		await get_tree().create_timer(0.1).timeout
		shot("prevision")


func _on_autoplay_finished(player_won: bool) -> void:
	print(
		(
			"AUTOPLAY fin: gana %s en %d turnos"
			% ["el jugador" if player_won else "el rival", main._battle.engine.turn_number]
		)
	)
	if _probe != null:
		print("FPS %s" % _probe.summary())
		var think := main._battle.ai_think_ms
		var worst := 0.0
		var total := 0.0
		for ms in think:
			worst = maxf(worst, ms)
			total += ms
		print(
			(
				"FPS la IA decidio %d veces: media %.1f ms, la mas lenta %.1f ms"
				% [think.size(), total / maxf(1.0, think.size()), worst]
			)
		)
	await get_tree().create_timer(0.4).timeout
	await shot("final")
	if _record != null:
		# Deja sonar el jingle antes de cortar.
		await get_tree().create_timer(3.0).timeout
		_save_recording()
	get_tree().quit(0)


## Guarda lo grabado y la lista de lo que sono, con el tiempo desde que
## empezo la grabacion (para compararlos en tools/audio).
func _save_recording() -> void:
	_record.set_recording_active(false)
	var folder := _folder()
	if folder == "":
		return
	var wav := _record.get_recording()
	var error := wav.save_to_wav(folder + "/audio.wav")
	var plays: Array[Dictionary] = []
	var counts := {}
	for entry in Sfx.current().played:
		plays.append({"t": (int(entry["ms"]) - _record_start_ms) / 1000.0, "id": entry["id"]})
		counts[entry["id"]] = int(counts.get(entry["id"], 0)) + 1
	var file := FileAccess.open(folder + "/sonidos.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(plays, " "))
	file.close()
	print(
		(
			"AUDIO grabado (%s), %d sonidos: %s"
			% ["ok" if error == OK else str(error), plays.size(), counts]
		)
	)


func _folder() -> String:
	var folder: String = main._args.get("shots", "")
	if folder == "":
		folder = OS.get_environment("MECHFORGE_SHOTS")
	return folder


func _on_autoplay_timeout() -> void:
	printerr("AUTOPLAY: tiempo agotado")
	get_tree().quit(1)


func shot(label: String) -> void:
	# La carpeta llega por variable de entorno: PowerShell parte en dos los
	# argumentos con "C:" al pasarlos de un script a otro.
	var folder: String = main._args.get("shots", "")
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
