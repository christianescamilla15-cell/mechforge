extends SceneTree
## Captura del combate antes y despues de pulsar la baliza de salto (OBS-035):
## con ella en la mano la camara se aleja hasta ver la arena entera. Necesita
## ventana (no va en headless).
##   Godot --path . --resolution 1600x900 -s tools/teleport_shot.gd ++ --out=carpeta


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var out: String = args.get("out", "user://")
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var hero := library.make("fisico_vanguardia", catalog, rules, ItemDef.Tier.COMMON, 3)
	hero.teleport = ItemScaling.resolve(
		catalog.get_item("esp_baliza"), rules, ItemDef.Tier.COMMON, 3
	)
	var foe := library.make("calor_horno", catalog, rules, ItemDef.Tier.COMMON, 3)
	var screen := BattleScreen.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	# La pantalla arma su interfaz al entrar en el arbol: un cuadro despues.
	await process_frame
	await process_frame
	screen.start(rules, hero, foe, 4, BattleAI.Difficulty.RANDOM)
	var waited := 0.0
	while not screen._can_act() and waited < 20.0:
		await create_timer(0.1).timeout
		waited += 0.1
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("baliza_antes.png"))
	screen._on_teleport_requested()
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join("baliza_despues.png"))
	print("guardado en ", out)
	quit(0)
