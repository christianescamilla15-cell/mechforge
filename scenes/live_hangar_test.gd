class_name LiveHangarTest
extends LiveTest
## Pruebas en vivo del hangar que se fueron anadiendo despues (el resto
## estan en LiveTest, del que hereda el raton simulado y las capturas):
## probar una espada, la evolucion del dibujo de una pieza, las
## observaciones del usuario (docs/OBSERVACIONES.md) y los ajustes. Todas con
## eventos de raton y teclado de verdad y sin guardar nada.


## Prueba en vivo de probar una espada (`--menu-shot=espada`), con el raton:
## se elige el brazo que lleva la hoja y se pulsa la diana. El robot debe
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
	await _click(stage.slot_screen_point(slot))
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
	hangar.pick(slot)
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


## Prueba en vivo de las observaciones del 2026-11-20 (`--menu-shot=observaciones`,
## docs/OBSERVACIONES.md), con el raton y sin guardar nada: las casillas de
## la cabecera del tablero, lo que da una mejora, el disparo de la
## ametralladora y el de la escopeta, y el robot de media vuelta con la rueda
## para pulsar un arma del otro lado.
func observations_test() -> void:
	var hangar := main._menu as WorkshopScreen
	var stage := hangar._stage
	var rack := stage.parts_rack
	await get_tree().create_timer(0.8).timeout
	await _click(stage.slot_screen_point("side1"))
	await get_tree().create_timer(0.7).timeout
	print("OBS tablero: hueco=%s casillas=%d" % [hangar._selected, rack.sibling_rects().size()])
	await shot("tablero_casillas")
	# Pulsar otra vez en el mismo sitio pasa al arma de detras.
	var first := hangar._selected
	await _click(stage.slot_screen_point("side1"))
	await get_tree().create_timer(0.4).timeout
	print("OBS segundo clic en el mismo sitio: %s -> %s" % [first, hangar._selected])
	# La casilla 3 de la cabecera elige ese brazo directamente.
	await _click(rack.global_position + rack.sibling_rects()[2].get_center())
	await get_tree().create_timer(0.4).timeout
	print("OBS casilla 3: hueco=%s" % hangar._selected)
	await shot("casilla_3")
	# Cada arma de balas con su disparo.
	for slot: String in ["side2", "side1", "side3"]:
		var id := Garage.get_slot(main._profile.build, slot)
		if id == "":
			continue
		hangar.pick(slot)
		await get_tree().create_timer(0.5).timeout
		var item := hangar._selected_item()
		print("OBS disparo de %s: %s" % [id, item.fx])
		hangar.test_fire()
		for i in 4:
			await get_tree().create_timer(0.09).timeout
			await shot("disparo_" + item.fx)
		await get_tree().create_timer(0.7).timeout
	# La rueda sobre el robot lo gira; de media vuelta se pulsa el otro lado.
	var chest := stage.slot_screen_point("torso")
	await _move(chest)
	for i in 8:
		await _wheel(chest, MOUSE_BUTTON_WHEEL_UP)
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(0.4).timeout
	print(
		(
			"OBS tras 8 muescas de rueda: giro=%.0f grados, media vuelta=%s"
			% [rad_to_deg(stage.turn), stage.is_flipped()]
		)
	)
	await shot("media_vuelta")
	await _click(stage.slot_screen_point("side2"))
	await get_tree().create_timer(0.5).timeout
	print("OBS clic en el brazo del otro lado: hueco=%s" % hangar._selected)
	await shot("media_vuelta_elegida")
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
