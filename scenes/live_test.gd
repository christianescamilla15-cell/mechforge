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


## Ninguna prueba se queda colgada: si un fallo corta su secuencia, a los
## diez minutos (de tiempo real) el juego se cierra con error.
func _ready() -> void:
	var watchdog := get_tree().create_timer(600.0, true, false, true)
	watchdog.timeout.connect(
		func() -> void:
			printerr("PRUEBA: tiempo agotado")
			get_tree().quit(1)
	)


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


## Prueba en vivo del garaje (`--menu-shot=garaje`, con `--real-profile`
## sobre la partida de verdad, sin guardar nada), con el raton: pulsar una
## bahia vacia (proyecta lo que se puede adquirir), pasar con su flecha a un
## diseno y adquirirlo con dos pulsaciones; en otra bahia, el armazon vacio
## (sale el tablero con los torsos); cambiar de robot pulsando su bahia.
func garage_test() -> void:
	var profile := main._profile
	print(
		(
			"GARAJE robots=%d activo=%d celdas=%d"
			% [profile.mechs.size(), profile.active, profile.gold]
		)
	)
	var hangar := main._menu as WorkshopScreen
	var stage := hangar._stage
	var projector := stage.projector
	await get_tree().create_timer(0.8).timeout
	await shot("base")
	await _click(_empty_bay(stage))
	await get_tree().create_timer(0.5).timeout
	print(
		(
			"GARAJE bahia vacia: abierto='%s' ofertas=%d"
			% [hangar.current_page(), projector._offers.size()]
		)
	)
	await shot("adquirir")
	# Su flecha pasa de un tipo de robot al siguiente: un armazon de cada uno.
	await _click(projector.global_position + projector.zone_rect("next").get_center())
	await get_tree().create_timer(0.2).timeout
	var style := str(projector.current()["id"])
	var robot := projector.global_position + projector.zone_rect("robot").get_center()
	await _move(robot)
	await get_tree().create_timer(0.3).timeout
	await shot("adquirir_tipo")
	await _click(robot)
	await get_tree().create_timer(0.3).timeout
	print(
		(
			"GARAJE primera pulsacion en %s: armado=%s robots=%d"
			% [style, projector.is_armed(), profile.mechs.size()]
		)
	)
	await shot("adquirir_armado")
	await _click(robot)
	await get_tree().create_timer(0.8).timeout
	print(
		(
			"GARAJE armazon de %s: robots=%d activo=%d tipo=%s vacio=%s abierto='%s'"
			% [
				style,
				profile.mechs.size(),
				profile.active,
				profile.style,
				profile.build.is_empty(),
				hangar.current_page()
			]
		)
	)
	await shot("taller_armazon")
	# Las piernas que faltan se eligen pulsando su fantasma (OBS-004).
	var ghost := stage._world_rect("legs")
	var foot := ghost.position + ghost.size * Vector2(0.5, 0.85)
	await _click(stage.global_position + stage._world.position + foot * stage._world.scale.x)
	await get_tree().create_timer(0.5).timeout
	print(
		(
			"GARAJE clic en las piernas que faltan: hueco=%s piezas=%d"
			% [hangar._selected, stage.parts_rack._parts.size()]
		)
	)
	await shot("armazon_piernas")
	hangar.close_panels()
	await get_tree().create_timer(0.8).timeout
	await shot("base_dos_robots")
	# Un clic en la bahia de otro robot: pasas a usarlo.
	await _click(stage._bay_rects[0].get_center())
	await get_tree().create_timer(0.8).timeout
	print("GARAJE clic en la primera bahia: activo=%d" % profile.active)
	await shot("base_cambia_de_robot")
	# La ficha del robot: desmontarlo pide dos pulsaciones, sin ventanas.
	await _click(stage._sign_rect().get_center())
	await get_tree().create_timer(0.6).timeout
	var console := stage.console
	var remove := console.global_position + console.zone_rect("remove").get_center()
	await _click(remove)
	await get_tree().create_timer(0.25).timeout
	print(
		(
			"GARAJE desmontar, primera pulsacion: armado=%s robots=%d"
			% [console.armed() == "remove", profile.mechs.size()]
		)
	)
	await shot("desmontar_armado")
	await _click(remove)
	await get_tree().create_timer(0.6).timeout
	print(
		(
			"GARAJE desmontar, segunda pulsacion: robots=%d abierto='%s'"
			% [profile.mechs.size(), hangar.current_page()]
		)
	)
	await shot("desmontado")
	# Pulsar el hangar vacio apaga el proyector.
	main.open_acquire()
	await get_tree().create_timer(0.4).timeout
	var was := hangar.current_page()
	await _click(Vector2(stage.size.x * 0.33, stage.size.y * 0.4))
	await get_tree().create_timer(0.4).timeout
	print("GARAJE proyector: abierto='%s' y tras pulsar fuera '%s'" % [was, hangar.current_page()])
	get_tree().quit(0)


## Centro de la primera bahia vacia del hangar.
func _empty_bay(stage: HangarStage) -> Vector2:
	for i in stage.bays.size():
		if int(stage.bays[i]["index"]) < 0:
			return stage._bay_rects[i].get_center()
	return Vector2.ZERO


## Prueba en vivo de la armeria (`--menu-shot=armeria`, con `--real-profile`
## sobre la partida de verdad, sin guardar nada): la pantalla de mejoras de
## cerca (se sube una con el raton y luego todo lo que deje la zona, para
## comprobar que lo que para es el tope y no el dinero), la tienda en el
## tablero de piezas (comparar, comprar arrastrando al robot y comprar con dos
## pulsaciones), el arbol de habilidades y la ficha del robot. Sigue con la
## prueba del taller.
func armory_test() -> void:
	var profile := main._profile
	var level := main._player_level()
	print(
		(
			"ARMERIA celdas=%d zona=%d nivel=%d mejoras=%s"
			% [profile.gold, profile.zone + 1, level, profile.shop_levels]
		)
	)
	main._show_menu()
	await get_tree().create_timer(0.8).timeout
	await shot("hangar")
	var workshop := main.open_workshop()
	var stage := workshop._stage
	await get_tree().create_timer(0.5).timeout
	# La pantalla de mejoras, pulsada con el raton: crece desde su sitio.
	await _click(stage._terminal_rects["mejoras"].get_center())
	await get_tree().create_timer(0.1).timeout
	await shot("mejoras_creciendo")
	await get_tree().create_timer(0.5).timeout
	await shot("mejoras_antes")
	var console := stage.console
	var first: String = main._shop.track_ids()[0]
	var before_first := profile.level_of(first)
	await _move(console.global_position + console.zone_rect("row:" + first).get_center())
	await get_tree().create_timer(0.2).timeout
	await shot("mejoras_fila")
	await _click(console.global_position + console.zone_rect("row:" + first).get_center())
	await get_tree().create_timer(0.3).timeout
	print("ARMERIA pulsar %s: nivel %d -> %d" % [first, before_first, profile.level_of(first)])
	var cap := main._armory_cap()
	var gold := profile.gold
	var changed := true
	while changed:
		changed = false
		for track in main._shop.track_ids():
			var before := profile.level_of(track)
			workshop.buy_upgrade(track)
			if profile.level_of(track) > before:
				changed = true
	var reasons := {}
	for track in main._shop.track_ids():
		reasons[track] = (
			"%d: %s"
			% [
				profile.level_of(track),
				profile.why_cant_buy(main._shop, track, cap, main._player_level())
			]
		)
	print("ARMERIA tope=%d gastado=%d quedan=%d" % [cap, gold - profile.gold, profile.gold])
	print("ARMERIA por mejora: %s" % reasons)
	await get_tree().create_timer(0.3).timeout
	await shot("mejoras_tope")
	# Pulsar fuera la devuelve a la pared.
	await _click(Vector2(stage.size.x * 0.55, stage.size.y * 0.9))
	await get_tree().create_timer(0.5).timeout
	print("ARMERIA tras pulsar fuera: abierto='%s'" % workshop.current_page())
	# La pantalla de la tienda saca el tablero con la tienda delante.
	workshop._selected = "side0"
	await _click(stage._terminal_rects["tienda"].get_center())
	await get_tree().create_timer(0.6).timeout
	await shot("tienda")
	var rack := stage.parts_rack
	var sold: Array[int] = []
	for index in rack._parts.size():
		var part: Dictionary = rack._parts[index]
		if not bool(part["owned"]) and str(part["reason"]) == "":
			sold.append(index)
	print(
		(
			"ARMERIA abierto='%s' piezas=%d comprables=%d"
			% [workshop.current_page(), rack._parts.size(), sold.size()]
		)
	)
	if not sold.is_empty():
		var bought := str(rack._parts[sold[0]]["id"])
		await _move(_rack_point(rack, sold[0]))
		await get_tree().create_timer(0.3).timeout
		await shot("tienda_comparar")
		await _drag_at(_rack_point(rack, sold[0]), stage.slot_screen_point("torso"))
		await get_tree().create_timer(0.6).timeout
		print(
			(
				"ARMERIA comprada al arrastrar: %s (la tienes: %s, celdas %d)"
				% [bought, bought in profile.owned, profile.gold]
			)
		)
		await shot("tienda_arrastrada")
	# Otra, con dos pulsaciones: la primera solo la deja armada.
	var other := -1
	for index in rack._parts.size():
		var part: Dictionary = rack._parts[index]
		if not bool(part["owned"]) and str(part["reason"]) == "":
			other = index
			break
	if other >= 0:
		var id := str(rack._parts[other]["id"])
		await _click(_rack_point(rack, other))
		await get_tree().create_timer(0.25).timeout
		print(
			(
				"ARMERIA primera pulsacion: armada='%s' la tienes: %s"
				% [rack.armed_id(), id in profile.owned]
			)
		)
		await shot("tienda_armada")
		await _click(_rack_point(rack, rack.index_of(id)))
		await get_tree().create_timer(0.4).timeout
		print(
			(
				"ARMERIA segunda pulsacion: la tienes: %s (celdas %d)"
				% [id in profile.owned, profile.gold]
			)
		)
		await shot("tienda_comprada")
	# La rueda del raton pasa las filas del tablero.
	await _move(rack.global_position + rack.size * 0.5)
	await _wheel(rack.global_position + rack.size * 0.5, MOUSE_BUTTON_WHEEL_DOWN)
	await get_tree().create_timer(0.4).timeout
	print("ARMERIA fila tras la rueda: %d" % rack._row)
	await shot("tienda_rueda")
	# El arbol de habilidades, de cerca.
	await _click(stage._terminal_rects["habilidades"].get_center())
	await get_tree().create_timer(0.7).timeout
	await shot("habilidades")
	var tree := console.state
	var next_id := ""
	for branch: Dictionary in tree.get("branches", []):
		for node: Dictionary in branch["nodes"]:
			if next_id == "" and str(node["state"]) == "next":
				next_id = str(node["id"])
	if next_id != "":
		var at := console.global_position + console.zone_rect("node:" + next_id).get_center()
		await _move(at)
		await get_tree().create_timer(0.25).timeout
		await shot("habilidades_nodo")
		await _click(at)
		await get_tree().create_timer(0.3).timeout
		print("ARMERIA pulsar %s: aprendida=%s" % [next_id, next_id in profile.skills])
		await shot("habilidades_pulsada")
	# El rotulo del robot: su ficha.
	await _click(stage._sign_rect().get_center())
	await get_tree().create_timer(0.6).timeout
	print("ARMERIA abierto='%s'" % workshop.current_page())
	await shot("robot")
	workshop.close_panels()
	await get_tree().create_timer(0.5).timeout
	workshop_test(workshop)


## Prueba en vivo del taller (`--menu-shot=taller`), con el raton: pulsar un
## hueco del robot (sale el tablero), dejarlo vacio, comparar una pieza,
## arrastrarla al enchufe del hueco, montar otra de un clic y quitarla con
## otro, subir un arma con la tecla del lector, probarla en la diana y elegir
## una cuna del banco.
func workshop_test(workshop: WorkshopScreen) -> void:
	var stage := workshop._stage
	var rack := stage.parts_rack
	var build := main._profile.build
	await get_tree().create_timer(0.8).timeout
	await shot("taller")
	# Un clic en el arma del brazo 1: sale el tablero de ese hueco.
	await _click(stage.slot_screen_point("side0"))
	await get_tree().create_timer(0.15).timeout
	await shot("taller_tablero_entrando")
	await get_tree().create_timer(0.5).timeout
	print(
		(
			"TALLER clic en el brazo 1: abierto='%s' hueco=%s piezas=%d"
			% [workshop.current_page(), workshop._selected, rack._parts.size()]
		)
	)
	await shot("taller_tablero")
	# Soltar su pieza en el tablero la quita.
	await _drag_at(stage.slot_screen_point("side0"), rack.global_position + rack.size * 0.5)
	await get_tree().create_timer(0.5).timeout
	print("TALLER brazo 1 tras soltarlo en el tablero: '%s'" % Garage.get_slot(build, "side0"))
	await shot("taller_brazo_vacio")
	var owned: Array[int] = []
	for index in rack._parts.size():
		if bool(rack._parts[index]["owned"]):
			owned.append(index)
	print("TALLER piezas tuyas en el tablero: %d" % owned.size())
	if owned.size() >= 2:
		await _move(_rack_point(rack, owned[0]))
		await get_tree().create_timer(0.3).timeout
		await shot("taller_comparar")
		# Al enchufe del hueco vacio, en el propio robot.
		await _drag_at(_rack_point(rack, owned[0]), stage.slot_screen_point("side0"))
		await get_tree().create_timer(0.6).timeout
		print("TALLER brazo 1 tras arrastrar: %s" % Garage.get_slot(build, "side0"))
		await shot("taller_arrastrado")
		# Un clic en otra la monta; un clic en la montada la quita.
		var clicked := str(rack._parts[owned[1]]["id"])
		await _click(_rack_point(rack, owned[1]))
		await get_tree().create_timer(0.3).timeout
		print("TALLER clic en %s -> brazo 1: %s" % [clicked, Garage.get_slot(build, "side0")])
		await _click(_rack_point(rack, rack.index_of(clicked)))
		await get_tree().create_timer(0.3).timeout
		print("TALLER clic en la montada -> brazo 1: '%s'" % Garage.get_slot(build, "side0"))
		await _click(_rack_point(rack, rack.index_of(clicked)))
		await get_tree().create_timer(0.3).timeout
	# Un arma a distancia: se sube con la tecla del lector y se prueba en la diana.
	var gun := ""
	for i in 4:
		var mounted := main._catalog.get_item(Garage.get_slot(build, "side%d" % i))
		if gun == "" and mounted != null and not mounted.has_tag(ItemDef.TAG_MELEE):
			gun = "side%d" % i
	workshop.pick(gun if gun != "" else "side1")
	await get_tree().create_timer(0.5).timeout
	var item := workshop._selected_item()
	if item != null:
		var before: Dictionary = main._profile.part(item.progress_id())
		await _move(rack.global_position + Vector2(rack.size.x * 0.5, 4.0))
		await _click(rack.global_position + rack._key_rect().get_center())
		await get_tree().create_timer(0.25).timeout
		var after: Dictionary = main._profile.part(item.progress_id())
		print(
			(
				"TALLER tecla del lector en %s: nivel %d -> %d"
				% [item.id, before["level"], after["level"]]
			)
		)
		await shot("taller_subir")
		await _move(stage.target_rect().get_center())
		await get_tree().create_timer(0.2).timeout
		await shot("taller_diana")
		await _click(stage.target_rect().get_center())
		await get_tree().create_timer(0.14).timeout
		await shot("taller_probar")
		await get_tree().create_timer(0.8).timeout
	# Una cuna del banco: el tablero pasa a ese hueco.
	var cell: SlotCell = stage.rack["module0"]
	await _move(cell.get_global_rect().get_center())
	await get_tree().create_timer(0.25).timeout
	await shot("taller_cuna")
	await _click(cell.get_global_rect().get_center())
	await get_tree().create_timer(0.5).timeout
	print("TALLER clic en la cuna: hueco=%s piezas=%d" % [workshop._selected, rack._parts.size()])
	await shot("taller_modulo")
	for slot: String in ["charge", "drone", "assist", "chest", "torso"]:
		workshop.pick(slot)
		await get_tree().create_timer(0.4).timeout
		await shot("taller_" + slot)
	workshop.clear_slot("legs")
	await get_tree().create_timer(0.4).timeout
	await shot("taller_sin_piernas")
	# Pulsar el hangar vacio recoge el tablero.
	await _click(Vector2(stage.size.x * 0.33, stage.size.y * 0.4))
	await get_tree().create_timer(0.5).timeout
	print("TALLER tras pulsar el hangar vacio: abierto='%s'" % workshop.current_page())
	await shot("taller_recogido")
	get_tree().quit(0)


## Prueba en vivo del modo mision (`--menu-shot=misiones`, con
## `--real-profile` sobre la partida de verdad, sin guardar nada): pulsar el
## monitor, pasar el raton por el rival, la arena, el combate libre con sus
## flechas, la fila avanzando como al volver de ganar y salir a combatir.
## Todo con el raton, como lo haria una persona.
func missions_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var stage := hangar._stage
	var board := stage._board
	await get_tree().create_timer(0.8).timeout
	await shot("hangar")
	if main._args.has("boss"):
		await _missions_boss_test(hangar)
		return
	await _click(board.get_global_rect().get_center())
	await get_tree().create_timer(0.3).timeout
	await shot("encendiendo")
	await get_tree().create_timer(1.3).timeout
	print("MISION canal=%s fila=%s" % [hangar.missions_channel(), stage._row.shown_ids()])
	await shot("campana")
	var rival := stage.global_position + stage._row.front_rect().get_center()
	await _move(rival)
	await get_tree().create_timer(0.3).timeout
	await shot("raton_en_el_rival")
	await _click(board.global_position + board.zone_rect("tab:arena").get_center())
	await get_tree().create_timer(1.2).timeout
	print("MISION canal=%s fila=%s" % [hangar.missions_channel(), stage._row.shown_ids()])
	await shot("arena")
	await _click(board.global_position + board.zone_rect("tab:free").get_center())
	await get_tree().create_timer(1.2).timeout
	await shot("libre")
	for zone: String in ["pick:enemy:1", "pick:enemy:1", "pick:tier:1", "pick:difficulty:-1"]:
		await _click(board.global_position + board.zone_rect(zone).get_center())
		await get_tree().create_timer(0.15).timeout
	await get_tree().create_timer(1.0).timeout
	print("MISION canal=%s fila=%s" % [hangar.missions_channel(), stage._row.shown_ids()])
	await shot("libre_elegido")
	await _click(board.global_position + board.zone_rect("tab:campaign").get_center())
	await get_tree().create_timer(1.0).timeout
	# Como al volver de ganar: el vencido se apaga y la fila avanza.
	var beaten: Dictionary = main.mission_state("campaign")["rivals"][0]
	if bool(beaten.get("boss", false)):
		# Vencer al jefe abre la zona siguiente, que empieza por su primer combate.
		main._profile.zone += 1
		main._profile.fight = 0
	else:
		main._profile.fight += 1
	hangar.open_missions("campaign", "advance", beaten)
	for i in 6:
		await get_tree().create_timer(0.24).timeout
		await shot("avanza")
	await get_tree().create_timer(0.6).timeout
	print("MISION tras ganar: fila=%s" % [stage._row.shown_ids()])
	await shot("avanzada")
	# Salir a combatir: pulsar al primero.
	await _click(stage.global_position + stage._row.front_rect().get_center())
	await get_tree().create_timer(0.45).timeout
	await shot("saliendo")
	await get_tree().create_timer(0.5).timeout
	await shot("telon")
	await get_tree().create_timer(1.6).timeout
	print("MISION combate=%s rival=%s" % [main._battle != null, main._spec.get("enemy", "")])
	await shot("combate")
	get_tree().quit(0)


## Con `--boss`: delante del jefe de la zona. La primera pulsacion lo deja
## armado y avisa; pulsar fuera vuelve al taller sin pelear.
func _missions_boss_test(hangar: WorkshopScreen) -> void:
	var stage := hangar._stage
	main._profile.fight = main._campaign.fights_in(main._profile.zone)
	hangar.refresh()
	await _click(stage._board.get_global_rect().get_center())
	await get_tree().create_timer(1.6).timeout
	print("MISION jefe: fila=%s" % [stage._row.shown_ids()])
	await shot("jefe")
	var rival := stage.global_position + stage._row.front_rect().get_center()
	await _click(rival)
	await get_tree().create_timer(0.4).timeout
	print("MISION jefe armado=%s combate=%s" % [stage._row.armed, main._battle != null])
	await shot("jefe_armado")
	await _click(stage.global_position + Vector2(stage.size.x * 0.5, stage.size.y * 0.2))
	await get_tree().create_timer(0.7).timeout
	print("MISION fuera: canal='%s' combate=%s" % [hangar.missions_channel(), main._battle != null])
	await shot("de_vuelta_al_taller")
	get_tree().quit(0)


## Mueve el raton (un evento de verdad) a un punto del juego. Los eventos
## del raton van en pixeles de la ventana: con la ventana a otro tamano que
## el juego hay que pasarlos por su escala.
func _move(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_final_transform() * at
	motion.global_position = motion.position
	motion.relative = Vector2(1, 0)
	Input.parse_input_event(motion)
	await get_tree().process_frame


## Un clic con el raton en un punto del juego.
func _click(at: Vector2) -> void:
	await _move(at)
	var window_at := get_viewport().get_final_transform() * at
	_mouse_button(window_at, true)
	await get_tree().process_frame
	_mouse_button(window_at, false)
	await get_tree().process_frame


## Centro, en el juego, de una pieza del tablero.
func _rack_point(rack: PartsRack, index: int) -> Vector2:
	return rack.global_position + rack.part_rect(index).get_center()


## Arrastra con el raton (eventos de verdad) de un punto del juego a otro.
func _drag_at(from: Vector2, to: Vector2) -> void:
	var window := get_viewport().get_final_transform()
	var a := window * from
	var b := window * to
	await _move(from)
	_mouse_button(a, true)
	await get_tree().process_frame
	# Godot empieza a arrastrar cuando suma desplazamiento relativo: cada paso
	# lleva el suyo, como un raton de verdad.
	var last := a
	for i in range(1, 13):
		var motion := InputEventMouseMotion.new()
		motion.position = a.lerp(b, i / 12.0)
		motion.global_position = motion.position
		motion.relative = motion.position - last
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		last = motion.position
		Input.parse_input_event(motion)
		await get_tree().process_frame
	_mouse_button(b, false)
	await get_tree().process_frame
	await get_tree().process_frame


## Una muesca de la rueda del raton en un punto del juego.
func _wheel(at: Vector2, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = get_viewport().get_final_transform() * at
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame
	# Una rueda de verdad pulsa y suelta: sin soltar, el control se queda
	# con el raton.
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
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
