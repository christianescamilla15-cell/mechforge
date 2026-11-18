class_name MovesShowcase
extends Control
## Muestra de los movimientos de un mech, uno detras de otro y con su rotulo,
## para revisar las animaciones con el usuario (tools/clip.ps1 -Showcase).
## No usa el motor de combate: mueve las figuras directamente.

signal finished

const STAGE := "desierto"
const BEAT := 0.5

var rules: RulesConfig
var catalog: Catalog
var library: BuildLibrary
var stages: StageLibrary

var _arena: ArenaView
var _caption: Label
var _hero: MechBuild


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("0b1017")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_arena = ArenaView.new()
	_arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena.offset_top = 90
	_arena.offset_bottom = -60
	_arena.set_stage(stages.get_stage(STAGE))
	add_child(_arena)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 22
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 38)
	add_child(_caption)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_arena.cells = rules.arena_size
	_hero = library.make("fisico_vanguardia", catalog, rules, ItemDef.Tier.COMMON, 6)
	# Con todos los huecos llenos, para ver cada arma en su sitio.
	_hero.tops.append(_hero.tops[0])
	_hero.chest = _item("canon_pesado_canon_cin")
	var rival := library.make("calor_horno", catalog, rules, ItemDef.Tier.COMMON, 6)
	var hero := _arena.mechs[0]
	var foe := _arena.mechs[1]
	hero.setup(_hero, 1)
	foe.setup(rival, -1)
	hero.place(_cell(2))
	foe.place(_cell(7))
	_arena.update_facing()
	await _pause(BEAT * 2)

	await _show("Caminar", hero.move_to(_cell(4), 1.5))
	await _show("Retroceder (de espaldas)", hero.move_to(_cell(2), 1.3))
	await _show("Volar con los propulsores", hero.jump_to(_cell(5), 1.4))
	_caption.text = "Volar por encima del rival"
	await hero.jump_to(_cell(8), 1.8).finished
	_arena.update_facing()
	await _pause(BEAT)
	await _show("Volar de espaldas", hero.jump_to(_cell(9), 1.2))
	await _show("Embestida", hero.dash_to(_cell(8), 0.55))
	await _show("Empujón: el rival sale despedido", foe.knockback_to(_cell(4), 1.0))
	await _show("Retroceso al disparar", hero.hop_back(_cell(9), 1.0))
	await _show("Gancho: el rival es arrastrado", foe.knockback_to(_cell(8), 1.0))

	hero.place(_cell(2))
	foe.place(_cell(7))
	_arena.update_facing()
	_swap_legs("piernas_deslizadores")
	_caption.text = "Levitar"
	await _pause(BEAT * 3)
	await _show("Levitar: deslizarse hacia delante", hero.move_to(_cell(4), 1.2))
	await _show("Levitar: hacia atrás", hero.move_to(_cell(2), 1.2))

	_swap_legs("piernas_orugas")
	await _show("Rodar (orugas)", hero.move_to(_cell(4), 1.2))
	await _show("Rodar hacia atrás", hero.move_to(_cell(2), 1.2))

	_swap_legs("piernas_rodillos")
	await _show("Rodar (ruedas)", hero.move_to(_cell(4), 1.2))
	await _show("Rodar hacia atrás", hero.move_to(_cell(2), 1.2))

	_swap_legs("piernas_zancos")
	await _fire("Disparar: brazos de delante", ["side0", "side1"])
	await _fire("Disparar: brazos del lado lejano", ["side2", "side3"])
	await _fire("Disparar: armas de hombro", ["top0", "top1"])
	await _fire("Disparar: arma de pecho", ["chest"])
	# El robot de asistencia: sus seis formas, y un disparo de cada arma.
	for form in 6:
		_set_assist(form)
		_caption.text = (
			"Asistente: %s (%s)" % [Txt.t("assist_form_%d" % form), Txt.TIER_NAMES[form]]
		)
		await _pause(BEAT * 2.4)
		if form in [2, 5]:
			await _arena.fire_between(0, 1, Color("ffb347"), 0.7, true, "drone")
			await _pause(BEAT * 0.6)
			await _arena.fire_between(0, 1, Color("ffb347"), 0.7, true, "drone_low")
			await _pause(BEAT)
	await _show("Salto con baliza (teletransporte)", hero.blink_to(_cell(5), 0.8))
	await _pause(BEAT * 2)
	finished.emit()


func _show(text: String, tween: Tween) -> void:
	_caption.text = text
	await tween.finished
	await _pause(BEAT)


## Dispara las armas de esos huecos, una tras otra.
func _fire(text: String, slots: Array[String]) -> void:
	_caption.text = text
	for slot in slots:
		await _arena.fire_between(0, 1, Color("ffb347"), 0.7, false, slot)
		await _pause(BEAT * 0.6)
	await _pause(BEAT)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _cell(index: int) -> Vector2:
	return _arena.cell_point(index)


## Pone al mech de muestra el robot de asistencia de esa clase, con sus dos armas.
func _set_assist(tier: int) -> void:
	var body := catalog.get_item("asistente_blindaje")
	_hero.assist = ItemScaling.resolve(body, rules, tier as ItemDef.Tier, 0)
	_hero.drone_low = _hero.drone
	var view := _arena.mechs[0]
	var at := view.position
	view.setup(_hero, view.facing)
	view.place(at)


## Cambia las piernas del mech de muestra (levitar, orugas...).
func _swap_legs(id: String) -> void:
	_hero.legs = _item(id)
	var view := _arena.mechs[0]
	var at := view.position
	view.setup(_hero, view.facing)
	view.place(at)


func _item(id: String) -> ItemDef:
	return ItemScaling.resolve(catalog.get_item(id), rules, ItemDef.Tier.COMMON, 6)
