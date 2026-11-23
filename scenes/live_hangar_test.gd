class_name LiveHangarTest
extends LiveTest
## Pruebas en vivo del hangar que se fueron anadiendo despues (el resto
## estan en LiveTest, del que hereda el raton simulado y las capturas):
## probar una espada, la evolucion del dibujo de una pieza, las
## observaciones del usuario (docs/OBSERVACIONES.md) y los ajustes. Todas con
## eventos de raton y teclado de verdad y sin guardar nada.


## Prueba en vivo de probar una espada (`--menu-shot=espada`), con el raton:
## se elige la casilla del brazo que lleva la hoja y se pulsa la diana. El
## robot debe
## saltar junto a la diana, dar el tajo y volver a su plataforma; se guarda
## un cuadro cada poco para verlo.
func sword_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var stage := hangar._stage
	var slot := ""
	for i in 4:
		var id := Garage.get_slot(main._profile.build, "side%d" % i)
		var def := main._catalog.get_item(id) if id != "" else null
		if slot == "" and def != null and def.has_tag(ItemDef.TAG_SWORD):
			slot = "side%d" % i
	await get_tree().create_timer(0.8).timeout
	if slot == "":
		print("ESPADA el robot no lleva ninguna hoja")
		get_tree().quit(1)
		return
	# Su casilla en la computadora del taller; con ella elegida y la pantalla
	# de vuelta en la pared, la diana prueba esa arma.
	hangar.open_parts()
	await get_tree().create_timer(0.6).timeout
	await _click(_box_point(stage, slot))
	await get_tree().create_timer(0.4).timeout
	hangar.close_panels()
	await get_tree().create_timer(0.7).timeout
	var home := stage._mech.position
	var center := stage._platform_center()
	await _click(stage.target_rect().get_center())
	var farthest := 0.0
	for i in 16:
		await get_tree().create_timer(0.11).timeout
		farthest = maxf(farthest, stage._mech.position.x - home.x)
		await shot("tajo")
	await get_tree().create_timer(0.6).timeout
	print(
		(
			"ESPADA hueco=%s avanza=%.0f vuelve=%s plataforma quieta=%s"
			% [
				slot,
				farthest,
				stage._mech.position.is_equal_approx(home),
				is_equal_approx(center, stage._platform_center())
			]
		)
	)
	await shot("vuelta")
	get_tree().quit(0)


## Prueba en vivo de la evolucion del dibujo (`--menu-shot=evolucion`, sin
## guardar nada): la hoja del robot pasa, solo en memoria, por cada nivel de
## su clase y por la clase siguiente, y se guarda una captura de cada paso.
func evolution_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var slot := ""
	var id := ""
	for i in 4:
		var mounted := Garage.get_slot(main._profile.build, "side%d" % i)
		var def := main._catalog.get_item(mounted) if mounted != "" else null
		if slot == "" and def != null and def.has_tag(ItemDef.TAG_SWORD):
			slot = "side%d" % i
			id = mounted
	await get_tree().create_timer(0.8).timeout
	if slot == "":
		print("EVOLUCION el robot no lleva ninguna hoja")
		get_tree().quit(1)
		return
	var top: int = main._rules.tier_max_level[1]
	var steps: Array = [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4], [0, 5], [0, 6], [1, 0], [1, top]]
	for step: Array in steps:
		main._profile.parts[id] = {"tier": step[0], "level": step[1]}
		hangar.refresh()
		await get_tree().create_timer(0.35).timeout
		var item := main._bench.resolved(main._profile, id)
		print(
			(
				"EVOLUCION %s clase=%d nivel=%d dibujo=%s"
				% [id, step[0], step[1], MechSprites.weapon_look(item)]
			)
		)
		await shot("evolucion_c%d_n%02d" % [step[0], step[1]])
	get_tree().quit(0)


## Prueba en vivo de las fases del dibujo (`--menu-shot=fases`, con
## `--real-profile` y sin guardar nada; OBS-047): su torso y sus armas pasan,
## solo en memoria, por las fases 0 a 10 (cada arma dentro de las clases de su
## tipo) y se guarda una captura de cada una.
func phases_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var ids: Array[String] = []
	for slot: String in ["torso", "side0", "side1", "top0"]:
		var mounted := Garage.get_slot(main._profile.build, slot)
		if mounted != "":
			ids.append(mounted)
	await get_tree().create_timer(0.8).timeout
	for phase in 11:
		var looks: Array[String] = []
		for id in ids:
			var def := main._catalog.get_item(id)
			var tier := clampi(mini(phase / 2, ItemDef.Tier.DIVINE), def.tier_min, def.tier_max)
			var level: int = 0 if phase % 2 == 0 else main._rules.tier_max_level[tier]
			main._profile.parts[def.progress_id()] = {"tier": tier, "level": level}
		hangar.refresh()
		await get_tree().create_timer(0.35).timeout
		for id in ids:
			var item := main._bench.resolved(main._profile, id)
			if item.type == ItemDef.Type.TORSO:
				var torsos := MechSprites.TORSO_SETS
				var base: String = torsos[absi(item.id.hash()) % torsos.size()]
				looks.append(MechSprites.class_set(base, item, "torso"))
			else:
				looks.append(MechSprites.weapon_look(item))
		print("FASES fase=%d %s" % [phase, ", ".join(looks)])
		await shot("fase%02d" % phase)
	get_tree().quit(0)


## Prueba en vivo del robot desarmado (`--menu-shot=desarmado`, con
## `--real-profile` y sin guardar nada; OBS-048): con el raton, pasar por
## una pieza, elegir un arma, un sistema, el nucleo y el torso, y soltar
## pulsando el fondo; una captura de cada paso.
func teardown_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var view := hangar._stage.teardown
	await get_tree().create_timer(0.8).timeout
	await shot("base")
	var side := view.rect_of("slot:side0")
	await _move(side.get_center())
	await shot("encima_arma")
	for key: String in ["slot:side0", "system:health", "core", "slot:torso", "slot:hook"]:
		await _click(view.rect_of(key).get_center())
		await get_tree().create_timer(0.4).timeout
		print("DESARMADO elegido=%s etiqueta=%s" % [view.selected, hangar._stage.tag.is_open()])
		await shot(key.replace(":", "_"))
	await _click(Vector2(hangar.size.x * 0.62, hangar.size.y * 0.06))
	await get_tree().create_timer(0.3).timeout
	print("DESARMADO suelto=%s etiqueta=%s" % [view.selected == "", hangar._stage.tag.is_open()])
	get_tree().quit(0)


## Prueba en vivo del estuche de piezas (`--menu-shot=estuche`, con
## `--real-profile` y sin guardar; OBS-048): "Cambiar pieza" en la etiqueta
## de un arma abre el estuche a su lado; pasar por una pieza del estuche,
## llevarlo a otras piezas pulsandolas y cerrarlo pulsando la misma.
func case_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var stage := hangar._stage
	var view := stage.teardown
	var box := stage.parts_case
	await get_tree().create_timer(0.8).timeout
	await _click(view.rect_of("slot:side0").get_center())
	await get_tree().create_timer(0.4).timeout
	var change: Rect2 = stage.tag._keys.get("change", Rect2())
	await _click(change.get_center())
	await get_tree().create_timer(0.6).timeout
	print(
		(
			"ESTUCHE abierto=%s pieza=%s etiqueta=%s computadora=%s"
			% [box.is_open(), box.key, stage.tag.is_open(), stage.loadout.is_open()]
		)
	)
	await shot("brazo")
	var part := box.rack.part_rect(1)
	if part.size != Vector2.ZERO:
		await _move(box.position + box.rack.position + part.get_center())
		await get_tree().create_timer(0.5).timeout
		await shot("brazo_encima")
	# Llevarlo a otras piezas a la vista: el hombro y las de la izquierda.
	for key: String in ["slot:top0", "slot:side1", "slot:module0", "slot:module4", "slot:hook"]:
		if view.rect_of(key).size == Vector2.ZERO:
			continue
		await _click(view.rect_of(key).get_center())
		await get_tree().create_timer(0.6).timeout
		print("ESTUCHE en %s: abierto=%s hueco=%s" % [key, box.is_open(), box.key])
		await shot(key.trim_prefix("slot:"))
	# Pulsar la misma pieza lo cierra y vuelve su etiqueta.
	await _click(view.rect_of(box.key).get_center())
	await get_tree().create_timer(0.5).timeout
	print("ESTUCHE cerrado=%s etiqueta=%s" % [not box.is_open(), stage.tag.is_open()])
	await shot("cerrado")
	# El torso, desde su etiqueta; y cerrarlo con la tecla de su esquina.
	await _click(view.rect_of("slot:torso").get_center())
	await get_tree().create_timer(0.4).timeout
	change = stage.tag._keys.get("change", Rect2())
	await _click(change.get_center())
	await get_tree().create_timer(0.6).timeout
	print("ESTUCHE torso: abierto=%s hueco=%s" % [box.is_open(), box.key])
	await shot("torso")
	await _click(box.position + box.close_center())
	await get_tree().create_timer(0.5).timeout
	print(
		(
			"ESTUCHE cerrado con la tecla=%s robot=%s"
			% [not box.is_open(), main.robot_name(main._profile.active)]
		)
	)
	get_tree().quit(0)


## Prueba en vivo de la zona de combate (`--menu-shot=zona`, con
## `--real-profile` y sin guardar ni pelear; OBS-048): pasar por la
## compuerta del hangar, entrar, pasar por el rival y volver por el rotulo.
func zone_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var stage := hangar._stage
	await get_tree().create_timer(0.8).timeout
	var door: Rect2 = stage._terminal_rects.get("salida", Rect2())
	await _move(door.get_center())
	await get_tree().create_timer(0.3).timeout
	await shot("compuerta")
	await _click(door.get_center())
	await get_tree().create_timer(1.2).timeout
	print("ZONA abierta=%s canal=%s" % [stage.is_mission_on(), hangar.missions_channel()])
	await shot("zona")
	await _click(Vector2(stage.size.x * 0.5, stage.size.y * 0.55))
	await get_tree().create_timer(0.3).timeout
	print("ZONA tras pulsar el fondo sigue=%s" % stage.is_mission_on())
	var back: Rect2 = stage._terminal_rects.get("volver", Rect2())
	await _move(back.get_center())
	await shot("zona_volver")
	await _click(back.get_center())
	await get_tree().create_timer(0.8).timeout
	print("ZONA vuelta al hangar=%s" % (not stage.is_mission_on()))
	await shot("hangar")
	get_tree().quit(0)


## Prueba en vivo de la racha de la arena (`--menu-shot=racha`, con
## `--real-profile` y sin guardar nada; OBS-049): empieza un combate de
## arena, da por ganado el primero (resultado con "otro combate" y
## "cobrar"), pide otro y da por perdido el segundo (el bote se pierde).
func streak_test() -> void:
	await get_tree().create_timer(0.6).timeout
	main._on_arena_pressed()
	await get_tree().create_timer(1.2).timeout
	main._on_battle_finished(true)
	main._battle._result.show()
	await get_tree().create_timer(0.3).timeout
	var profile := main._profile
	print("RACHA gano el 1: bote=%d racha=%d" % [profile.arena_pot, profile.arena_streak])
	await shot("gano_1")
	main._on_rematch()
	await get_tree().create_timer(1.2).timeout
	print("RACHA rival del 2: %s, plus %.2f" % [main._spec["enemy"], main._spec["enemy_edge"]])
	main._on_battle_finished(false)
	main._battle._result.show()
	await get_tree().create_timer(0.3).timeout
	print("RACHA perdio el 2: bote=%d racha=%d" % [profile.arena_pot, profile.arena_streak])
	await shot("perdio_2")
	get_tree().quit(0)


## Prueba en vivo de las observaciones (`--menu-shot=observaciones`,
## docs/OBSERVACIONES.md), con el raton y sin guardar nada: las casillas del
## plano en la computadora del taller (OBS-030), el disparo de la
## ametralladora, el de la escopeta y el del rifle en la diana (OBS-009) y el
## robot girado con la rueda (OBS-006).
func observations_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var stage := hangar._stage
	var rack := stage.loadout.rack
	await get_tree().create_timer(0.8).timeout
	hangar.open_parts()
	await get_tree().create_timer(0.7).timeout
	for slot: String in ["side0", "side1", "top0"]:
		await _click(_box_point(stage, slot))
		await get_tree().create_timer(0.4).timeout
		print("OBS casilla %s: hueco=%s piezas=%d" % [slot, hangar._selected, rack._parts.size()])
	await shot("plano_casillas")
	# Cada arma con su disparo: sus dos brazos y su hombro (OBS-033), y la diana.
	for slot: String in ["side1", "top0"]:
		var id := Garage.get_slot(main._profile.build, slot)
		if id == "":
			continue
		hangar.pick(slot)
		await get_tree().create_timer(0.4).timeout
		hangar.close_panels()
		await get_tree().create_timer(0.6).timeout
		var item := hangar._selected_item()
		print("OBS disparo de %s: %s" % [id, item.fx])
		await _click(stage.target_rect().get_center())
		for i in 4:
			await get_tree().create_timer(0.09).timeout
			await shot("disparo_" + item.fx)
		await get_tree().create_timer(0.7).timeout
	get_tree().quit(0)


## Prueba en vivo de la partida nueva (`--menu-shot=inicio`), con el raton y
## sin guardar nada: pasar por los tres tipos de robot, elegir uno con dos
## pulsaciones, ver en el hangar que empieza con una sola arma y sin
## asistente, que su tablero solo cuelga lo que su tipo monta y que el rival
## de la arena sale con su mismo equipo; y salir a pelear contra el.
func starter_test() -> void:
	var select := main._menu as StarterSelect
	if select == null:
		print("INICIO no salio la pantalla de partida nueva")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.8).timeout
	await shot("tres_tipos")
	for i in select.entries.size():
		await _move(select.spot_rect(i).get_center())
		await get_tree().create_timer(0.25).timeout
		await shot("raton_en_%s" % select.entries[i]["id"])
	var pick := select.entries.size() - 1
	var style := str(select.entries[pick]["id"])
	await _click(select.spot_rect(pick).get_center())
	await get_tree().create_timer(0.3).timeout
	print("INICIO primera pulsacion en %s: armado=%d" % [style, select.armed()])
	await shot("armado")
	# El raton de verdad, si esta sobre la ventana, puede pasar por otro robot
	# y desarmarlo entre una pulsacion y la otra: se insiste.
	for attempt in 4:
		if not is_instance_valid(select) or main._menu != select:
			break
		await _click(select.spot_rect(pick).get_center())
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(0.6).timeout
	var profile := main._profile
	var hangar := main._menu as WorkshopScreen
	if hangar == null:
		print("INICIO tras elegir no salio el hangar")
		get_tree().quit(1)
		return
	print(
		(
			"INICIO empieza: tipo=%s robot=%s piezas=%s celdas=%d asistente=%s"
			% [
				profile.style,
				main.robot_name(profile.active),
				profile.owned,
				profile.gold,
				Garage.has_assist(profile, main._catalog)
			]
		)
	)
	await shot("hangar_recien_empezado")
	var stage := hangar._stage
	var rack := stage.loadout.rack
	# El segundo brazo: su catalogo solo ensena lo que monta su tipo.
	hangar.pick("side1")
	await get_tree().create_timer(0.7).timeout
	var forms: Array[String] = []
	for part: Dictionary in rack._parts:
		var form := (part["item"] as ItemDef).form
		if not form in forms:
			forms.append(form)
	print("INICIO tablero del brazo 2: %d piezas, formas=%s" % [rack._parts.size(), forms])
	await shot("tablero_del_tipo")
	# El asistente se ve, pero cerrado hasta su nivel.
	hangar.pick("assist")
	await get_tree().create_timer(0.6).timeout
	print(
		(
			"INICIO asistente: cerrado='%s' cuerpos a la vista=%d"
			% [rack.state.get("locked", ""), rack._parts.size()]
		)
	)
	await shot("asistente_cerrado")
	hangar.close_panels()
	await get_tree().create_timer(0.5).timeout
	# La arena: el rival sale con una sola arma, como tu.
	var board := stage._board
	await _click(board.get_global_rect().get_center())
	await get_tree().create_timer(1.4).timeout
	await _click(board.global_position + board.zone_rect("tab:arena").get_center())
	await get_tree().create_timer(1.4).timeout
	var state := main.mission_state("arena")
	var rival: MechBuild = state["rivals"][0]["build"]
	var weapons: Array[String] = []
	for item in rival.sides + rival.tops:
		if item != null:
			weapons.append(item.id)
	print(
		(
			"INICIO rival de la arena: %s armas=%s modulos=%d asistente=%s"
			% [state["rivals"][0]["id"], weapons, rival.modules.size(), rival.drone != null]
		)
	)
	await shot("arena_a_tu_medida")
	await _click(stage.global_position + stage._row.front_rect().get_center())
	await get_tree().create_timer(2.2).timeout
	print("INICIO combate=%s" % (main._battle != null))
	await shot("primer_combate")
	get_tree().quit(0)


## Prueba en vivo de los ajustes (`--menu-shot=ajustes`), con el raton y sin
## guardar nada: pulsar el cuadro de control de la pared, cambiar la
## velocidad, pulsar y arrastrar un volumen, armar la salida sin salir,
## cerrar pulsando fuera y volver a abrir con Esc.
func settings_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var stage := hangar._stage
	var console := stage.console
	var settings := main._settings
	var box: Rect2 = stage._terminal_rects["ajustes"]
	await get_tree().create_timer(0.8).timeout
	await _move(box.get_center())
	await get_tree().create_timer(0.3).timeout
	await shot("cuadro_de_control")
	await _click(box.get_center())
	await get_tree().create_timer(0.1).timeout
	await shot("ajustes_creciendo")
	await get_tree().create_timer(0.5).timeout
	print("AJUSTES clic en el cuadro: abierto='%s'" % hangar.current_page())
	await shot("ajustes")
	await _click(console.global_position + console.zone_rect("speed:2").get_center())
	await get_tree().create_timer(0.2).timeout
	print("AJUSTES velocidad: indice %d (x%.1f)" % [settings.speed_index, main.animation_speed()])
	var bar := console.zone_rect("vol:Music")
	var from := (
		console.global_position + Vector2(bar.position.x + bar.size.x * 0.25, bar.get_center().y)
	)
	await _click(from)
	await get_tree().create_timer(0.2).timeout
	print("AJUSTES musica tras pulsar: %d %%" % roundi(settings.volumes["Music"] * 100.0))
	await _drag_at(from, from + Vector2(bar.size.x * 0.4, 0.0))
	await get_tree().create_timer(0.2).timeout
	print("AJUSTES musica tras arrastrar: %d %%" % roundi(settings.volumes["Music"] * 100.0))
	await shot("ajustes_cambiados")
	# Salir pide dos pulsaciones: aqui solo la primera.
	await _click(console.global_position + console.zone_rect("quit").get_center())
	await get_tree().create_timer(0.25).timeout
	print("AJUSTES salir armado: %s" % (console.armed() == "quit"))
	await shot("ajustes_salir")
	await _click(Vector2(stage.size.x * 0.33, stage.size.y * 0.4))
	await get_tree().create_timer(0.5).timeout
	print("AJUSTES tras pulsar fuera: abierto='%s'" % hangar.current_page())
	# Esc, sin nada abierto, acerca los ajustes; otra vez, los devuelve.
	await _key(KEY_ESCAPE)
	await get_tree().create_timer(0.5).timeout
	var opened := hangar.current_page()
	await _key(KEY_ESCAPE)
	await get_tree().create_timer(0.5).timeout
	print("AJUSTES Esc: abierto='%s' y otra vez Esc: '%s'" % [opened, hangar.current_page()])
	await shot("hangar")
	get_tree().quit(0)


## Pulsa y suelta una tecla (eventos de verdad).
func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
