extends SceneTree
## Hoja de armas montadas para revisar su dibujo, tamano y posicion: un mech
## en grande por cada juego de armas de la muestra de movimientos
## (MovesShowcase.LOADOUTS) y guarda una imagen. Necesita ventana (no va en
## headless).
##   Godot --path . -s tools/weapon_frames.gd ++ --out=ruta.png

const SCALE := 1.3
const CELL := Vector2(640, 430)
const COLUMNS := 3


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var loadouts: Array[Array] = MovesShowcase.LOADOUTS.duplicate()
	# El ultimo, solo con las armas de delante, para verlas sin nada detras.
	loadouts.append(["Solo las de delante", ["medio_laser_cin", "largo_canon_cin"], []])
	var rows := ceili(loadouts.size() / float(COLUMNS))
	# Lienzo aparte del tamano justo: la ventana no limita la hoja.
	var canvas := SubViewport.new()
	canvas.size = Vector2i(int(CELL.x * COLUMNS), int(CELL.y * rows))
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.transparent_bg = false
	root.add_child(canvas)
	var background := ColorRect.new()
	background.color = Color("1b2230")
	background.size = Vector2(canvas.size)
	canvas.add_child(background)
	for i in loadouts.size():
		var build := library.make("fisico_vanguardia", catalog, rules, ItemDef.Tier.COMMON, 6)
		build.assist = null
		build.drone = null
		build.drone_low = null
		build.sides.clear()
		for id: String in loadouts[i][1]:
			build.sides.append(_item(catalog, rules, id))
		build.tops.clear()
		for id: String in loadouts[i][2]:
			build.tops.append(_item(catalog, rules, id))
		var view := MechView.new()
		canvas.add_child(view)
		view.setup(build, 1)
		view.scale = Vector2(SCALE, SCALE)
		var cell := Vector2(i % COLUMNS, i / COLUMNS)
		view.position = cell * CELL + Vector2(CELL.x * 0.36, CELL.y - 30.0)
		view.set_process(false)
		var label := Label.new()
		label.text = loadouts[i][0]
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
	var out: String = args.get("out", "user://weapon_frames.png")
	image.save_png(out)
	print("guardado ", out)
	quit(0)


func _item(catalog: Catalog, rules: RulesConfig, id: String) -> ItemDef:
	return ItemScaling.resolve(catalog.get_item(id), rules, ItemDef.Tier.COMMON, 6)
