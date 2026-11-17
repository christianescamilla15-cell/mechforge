extends SceneTree
## Ciclos de movimiento de cerca, para revisar las animaciones con el usuario:
## el mech, grande y en el sitio (como en una cinta), anda, anda de espaldas,
## vuela, levita, rueda y aguanta un empujon, con su rotulo. Se graba con
## tools/clip.ps1 -Cycle (modo pelicula de Godot).

const SCALE := 2.0
const SEGMENT := 2.6

var _view: MechView
var _caption: Label
var _build: MechBuild
var _rules := RulesConfig.new()
var _catalog: Catalog


func _initialize() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	_build = library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 6)
	var background := ColorRect.new()
	background.color = Color("1b2230")
	background.size = Vector2(root.size)
	root.add_child(background)
	var ground := ColorRect.new()
	ground.color = Color("4a5670")
	ground.position = Vector2(240, 640)
	ground.size = Vector2(800, 3)
	root.add_child(ground)
	_caption = Label.new()
	_caption.position = Vector2(0, 30)
	_caption.size = Vector2(root.size.x, 60)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 40)
	root.add_child(_caption)
	_view = MechView.new()
	root.add_child(_view)
	_view.setup(_build, 1)
	_view.scale = Vector2(SCALE, SCALE)
	_view.place(Vector2(640, 640))
	_run.call_deferred()


func _run() -> void:
	await _segment("Andar", {"_walking": true, "_gait_dir": 1.0, "_lean": 0.05})
	await _segment("Andar de espaldas", {"_walking": true, "_gait_dir": -1.0, "_lean": -0.07})
	_caption.text = "Volar con los propulsores"
	_apply({"_crouch": 1.0})
	await _wait(0.35)
	_apply({"_crouch": 0.0, "_airborne": true, "_thrust": 1.0, "_lean": 0.14})
	var up := _view.create_tween()
	up.tween_property(_view, "position:y", 470.0, 0.5).set_trans(Tween.TRANS_SINE)
	up.tween_property(_view, "position:y", 500.0, 0.8).set_trans(Tween.TRANS_SINE)
	up.tween_property(_view, "position:y", 470.0, 0.8).set_trans(Tween.TRANS_SINE)
	up.tween_property(_view, "position:y", 640.0, 0.5).set_trans(Tween.TRANS_SINE)
	await up.finished
	_apply({"_airborne": false, "_thrust": 0.0, "_lean": 0.0, "_crouch": 0.8})
	await _wait(0.25)
	_apply({"_crouch": 0.0})
	await _wait(0.5)
	await _segment("Aguantar un empujón", {"_brace": 1.0, "_lean": -0.16})
	_swap_legs("piernas_deslizadores")
	await _segment("Levitar", {})
	await _segment("Levitar: deslizarse", {"_walking": true, "_lean": 0.1})
	_swap_legs("piernas_orugas")
	await _segment("Rodar (orugas)", {"_walking": true, "_lean": 0.04})
	quit(0)


func _segment(text: String, state: Dictionary) -> void:
	_caption.text = text
	_apply(state)
	await _wait(SEGMENT)
	_apply({"_walking": false, "_lean": 0.0, "_brace": 0.0})


func _apply(state: Dictionary) -> void:
	for key: String in state:
		_view.set(key, state[key])


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _swap_legs(id: String) -> void:
	_build.legs = ItemScaling.resolve(_catalog.get_item(id), _rules, ItemDef.Tier.COMMON, 6)
	_view.setup(_build, 1)
	_view.scale = Vector2(SCALE, SCALE)
