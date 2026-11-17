extends SceneTree
## Hoja de poses de las piernas para revisar el esqueleto (scenes/battle/leg_rig.gd):
## dibuja un mech en grande en varios momentos de cada movimiento y guarda una
## imagen. Necesita ventana (no va en headless).
##   Godot --path . -s tools/rig_frames.gd ++ --out=ruta.png [--legs=piernas_zancos]

const SCALE := 1.15
const CELL := Vector2(260, 300)


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var build := library.make("fisico_vanguardia", catalog, rules, ItemDef.Tier.COMMON, 6)
	if args.has("legs"):
		build.legs = ItemScaling.resolve(
			catalog.get_item(args["legs"]), rules, ItemDef.Tier.COMMON, 6
		)
	# Poses: [rotulo, ajustes del MechView].
	var poses: Array = []
	for k in 8:
		poses.append(["andar %d" % k, {"_walking": true, "_gait": k * PI / 4.0}])
	poses.append(["agachado", {"_crouch": 1.0}])
	poses.append(["en el aire", {"_airborne": true, "_thrust": 1.0, "_lean": 0.14}])
	poses.append(["empujado", {"_brace": 1.0, "_lean": -0.16}])
	poses.append(["de pie", {}])
	var columns := 6
	var rows := ceili(poses.size() / float(columns))
	# Lienzo aparte del tamano justo: la ventana no limita la hoja.
	var canvas := SubViewport.new()
	canvas.size = Vector2i(int(CELL.x * columns), int(CELL.y * rows))
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.transparent_bg = false
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("1b2230")
	background.size = Vector2(canvas.size)
	canvas.add_child(background)
	for i in poses.size():
		var view := MechView.new()
		canvas.add_child(view)
		view.setup(build, 1)
		view.scale = Vector2(SCALE, SCALE)
		var cell := Vector2(i % columns, i / columns)
		view.position = cell * CELL + Vector2(CELL.x * 0.5, CELL.y - 30.0)
		view.set_process(false)
		for key: String in poses[i][1]:
			view.set(key, poses[i][1][key])
		var label := Label.new()
		label.text = poses[i][0]
		label.position = cell * CELL + Vector2(10, 8)
		canvas.add_child(label)
		var ground := ColorRect.new()
		ground.color = Color("3a4458")
		ground.position = cell * CELL + Vector2(20, CELL.y - 30.0)
		ground.size = Vector2(CELL.x - 40, 2)
		canvas.add_child(ground)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := canvas.get_texture().get_image()
	var out: String = args.get("out", "user://rig_frames.png")
	image.save_png(out)
	print("guardado ", out)
	quit(0)
