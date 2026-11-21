extends SceneTree
## Hoja para revisar el cuerpo de un rival (OBS-011): el mismo rival en grande
## con cada cuerpo que se le pasa, armado como sale en la campana y, debajo,
## sin armas, para ver el dibujo entero. Necesita ventana (no va en headless).
##   Godot --path . -s tools/rival_frames.gd ++ --enemy=calor_horno
##       --bodies=,liga2_horno --out=ruta.png
## En --bodies, un nombre vacio es el rival por sus piezas, como en la liga 1.

const SCALE := 1.5
const CELL := Vector2(620, 520)


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var enemy: String = args.get("enemy", "calor_horno")
	var bodies := str(args.get("bodies", ",liga2_horno")).split(",")
	var canvas := SubViewport.new()
	canvas.size = Vector2i(int(CELL.x * bodies.size()), int(CELL.y * 2.0))
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.transparent_bg = false
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("1b2230")
	background.size = Vector2(canvas.size)
	canvas.add_child(background)
	for column in bodies.size():
		for row in 2:
			var build := library.make(enemy, catalog, rules, ItemDef.Tier.COMMON, 4)
			build.body = bodies[column]
			build.assist = null
			build.drone = null
			build.drone_low = null
			if row == 1:
				build.sides.clear()
				build.tops.clear()
			var view := MechView.new()
			canvas.add_child(view)
			view.setup(build, 1)
			view.scale = Vector2(SCALE, SCALE)
			var cell := Vector2(column, row)
			view.position = cell * CELL + Vector2(CELL.x * 0.4, CELL.y - 34.0)
			view.set_process(false)
			var label := Label.new()
			var body_name := bodies[column] if bodies[column] != "" else "por sus piezas (liga 1)"
			label.text = "%s · %s" % [library.display_name(enemy), body_name]
			label.position = cell * CELL + Vector2(12, 8)
			canvas.add_child(label)
			var ground := ColorRect.new()
			ground.color = Color("3a4458")
			ground.position = cell * CELL + Vector2(20, CELL.y - 34.0)
			ground.size = Vector2(CELL.x - 40, 2)
			canvas.add_child(ground)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var out: String = args.get("out", "user://rival_frames.png")
	canvas.get_texture().get_image().save_png(out)
	print("guardado ", out)
	quit(0)
