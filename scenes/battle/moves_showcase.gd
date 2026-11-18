class_name MovesShowcase
extends Control
## Muestra de los movimientos de un mech, uno detras de otro y con su rotulo,
## para revisar las animaciones con el usuario (tools/clip.ps1 -Showcase).
## No usa el motor de combate: mueve las figuras directamente.

signal finished

const STAGE := "desierto"
const BEAT := 0.5
## Juegos de armas que se van montando para ver el dibujo de cada forma y
## tipo: [rotulo, laterales (las dos primeras van delante), superiores].
const LOADOUTS: Array[Array] = [
	[
		"Armas de balas",
		["medio_balas_cin", "corto_balas_cin", "largo_balas_cin", "hoja_balas_cin"],
		["bateria_balas_cin"],
	],
	[
		"Armas de cañón",
		["largo_canon_ter", "corto_canon_ter", "medio_canon_ter", "hoja_balas_ter"],
		["artilleria_canon_ter", "ancla_canon_ter"],
	],
	[
		"Armas bláster",
		["hoja_blaster_ion", "saboteador_blaster_ion", "medio_blaster_ion", "largo_blaster_ion"],
		["artilleria_blaster_ion", "bateria_blaster_ion"],
	],
	[
		"Armas láser",
		["saboteador_laser_cin", "hoja_laser_cin", "medio_laser_cin", "largo_laser_cin"],
		["artilleria_laser_cin", "ancla_laser_cin"],
	],
	[
		"Armas cortas y baterías",
		["corto_blaster_ter", "corto_laser_ter", "medio_balas_ter", "largo_balas_ter"],
		["bateria_canon_ter", "bateria_laser_ter"],
	],
]

var rules: RulesConfig
var catalog: Catalog
## Solo los disparos: cada uno de data/shots.json con un arma que lo lleve
## (tools/clip.ps1 -Shots).
var only_shots := false
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
	if only_shots:
		await _show_shots()
		finished.emit()
		return

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
	for loadout in LOADOUTS:
		_arm(loadout[1], loadout[2])
		await _fire(loadout[0], ["side0", "side1", "top0"])
	_arm(LOADOUTS[0][1], ["bateria_balas_cin", "artilleria_canon_cin"])
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
			await _fire_slot("drone")
			await _pause(BEAT * 0.6)
			await _fire_slot("drone_low")
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
		await _fire_slot(slot)
		await _pause(BEAT * 0.6)
	await _pause(BEAT)


## Dispara el arma de ese hueco del mech de muestra con su disparo y su color.
func _fire_slot(slot: String) -> void:
	var item := _slot_item(slot)
	var fx := item.fx if item != null else ""
	var color := ShotFx.ammo_color(item.element) if item != null else Color.WHITE
	var drone := slot.begins_with("drone")
	if item != null and item.has_tag(ItemDef.TAG_MELEE):
		_arena.strike(0, 1, fx, color, 0.7)
		await _pause(0.7)
		return
	await _arena.fire_between(0, 1, fx, color, 0.7, drone, slot)


func _slot_item(slot: String) -> ItemDef:
	var index := int(slot.right(1)) if slot.right(1).is_valid_int() else 0
	if slot.begins_with("side") and index < _hero.sides.size():
		return _hero.sides[index]
	if slot.begins_with("top") and index < _hero.tops.size():
		return _hero.tops[index]
	match slot:
		"chest":
			return _hero.chest
		"drone":
			return _hero.drone
		"drone_low":
			return _hero.drone_low
	return null


## Cada disparo de data/shots.json con un arma del catalogo que lo lleve, a
## una distancia dentro de su alcance; el rotulo dice que dispara. Las
## municiones se van turnando para ver los tres colores.
func _show_shots() -> void:
	var hero := _arena.mechs[0]
	var foe := _arena.mechs[1]
	var by_fx: Dictionary[String, Array] = {}
	for type: ItemDef.Type in [
		ItemDef.Type.SIDE, ItemDef.Type.TOP, ItemDef.Type.CHEST, ItemDef.Type.DRONE
	]:
		for def in catalog.by_type(type):
			if def.fx != "":
				if not by_fx.has(def.fx):
					by_fx[def.fx] = []
				by_fx[def.fx].append(def.id)
	var shown := 0
	for fx: String in by_fx:
		var ids: Array = by_fx[fx]
		var item := _item(ids[shown % ids.size()])
		shown += 1
		var slot := _mount_for_shot(item)
		var distance := item.range_max if item.range_max > 0 else 6
		if item.has_tag(ItemDef.TAG_MELEE):
			distance = 1
		foe.place(_cell(9))
		hero.place(_cell(9 - clampi(distance, 1, 8)))
		_arena.update_facing()
		_caption.text = ShotFx.shot(fx)["desc"]
		await _pause(BEAT * 1.2)
		await _fire_slot(slot)
		await _pause(BEAT * 1.6)


## Monta el arma en el mech de muestra y devuelve el hueco desde el que
## dispara.
func _mount_for_shot(item: ItemDef) -> String:
	var base := "medio_balas_cin"
	match item.type:
		ItemDef.Type.SIDE:
			_arm([item.id], [])
			return "side0"
		ItemDef.Type.TOP:
			_arm([base], [item.id])
			return "top0"
		ItemDef.Type.CHEST:
			_hero.chest = item
			_arm([base], [])
			return "chest"
	if _hero.assist == null:
		_set_assist(2)
	_hero.drone = item
	_hero.drone_low = item
	_arm([base], [])
	return "drone"


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


## Monta en el mech de muestra esas armas (ids del catalogo).
func _arm(sides: Array, tops: Array) -> void:
	_hero.sides.clear()
	for id: String in sides:
		_hero.sides.append(_item(id))
	_hero.tops.clear()
	for id: String in tops:
		_hero.tops.append(_item(id))
	var view := _arena.mechs[0]
	var at := view.position
	view.setup(_hero, view.facing)
	view.place(at)


func _item(id: String) -> ItemDef:
	return ItemScaling.resolve(catalog.get_item(id), rules, ItemDef.Tier.COMMON, 6)
