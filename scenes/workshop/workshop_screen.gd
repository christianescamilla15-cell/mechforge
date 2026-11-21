class_name WorkshopScreen
extends Control
## El hangar: la pantalla de inicio, inmersiva y "casi como si no existiera
## un menu" (pedidos del usuario del 2026-11-18 y el 2026-11-20). Es el
## taller y la armeria a la vez, todo dentro de la escena (HangarStage):
## - tu robot en el centro: un clic en una pieza (o en el enchufe de un hueco
##   vacio) elige su hueco y saca el tablero de piezas (PartsRack): cuelgan
##   las tuyas y, como hologramas con su precio, las de la tienda. Se pulsan
##   o se arrastran al robot; al pie del tablero va la lectura del robot con
##   lo que cambiaria, y la diana prueba el arma del hueco;
## - el banco de equipo bajo el robot: las cunas de pecho, especiales,
##   asistente y modulos, que se eligen igual;
## - tus otros robots en las bahias del fondo: un clic y pasas a usarlo; una
##   bahia vacia proyecta lo que puede fabricar (BayProjector): un armazon
##   vacio o un diseno ya armado, que se adquiere pulsandolo dos veces;
## - las pantallas de la pared: la de la tienda saca el tablero con la
##   tienda delante; las de mejoras y habilidades se usan ahi mismo, de
##   cerca (WallConsole); el rotulo de tu robot ensena su ficha y el
##   cuadro de control de la esquina, los ajustes;
## - el monitor de misiones: al pulsarlo el hangar se queda en penumbra y los
##   rivales se proyectan delante de tu robot (RivalRow); pulsar al primero
##   es salir a combatir.
## No hay cajon, ni listas, ni barra de estado, ni botones fuera de la
## escena: pulsar el hangar vacio o Esc recoge lo que este abierto (y Esc, sin
## nada abierto, acerca los ajustes). Lo que se ensena lo arma WorkshopBrief;
## lee y cambia el perfil a traves de MainScreen, que lo guarda.

signal closed

## Lo que se puede abrir por su nombre (show_page).
const CONSOLES: Array[String] = ["mejoras", "habilidades", "robot", "ajustes"]
const COLOR_GOLD := Color("ffd36b")

var main: MainScreen

var _selected: String = "side0"
var _hover_id: String = ""
## Hueco con el que se compara la pieza bajo el raton.
var _hover_slot: String = ""
## El tablero de piezas esta fuera; y si ensena la tienda delante.
var _arming := false
var _store_first := false
## Pantalla que esta de cerca: "mejoras", "habilidades", "robot" o "".
var _console: String = ""
## Una bahia vacia esta proyectando lo que se puede adquirir.
var _offering := false
## Canal del modo mision ("campaign", "arena" o "free"); "" = apagado.
var _channel: String = ""
var _launching := false
var _stage: HangarStage
var _toast: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = HangarStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	_stage.picked.connect(_on_part_picked)
	_stage.dropped.connect(_on_stage_dropped)
	_stage.dropped_on.connect(_on_cell_dropped)
	_stage.terminal_pressed.connect(show_page)
	_stage.bay_pressed.connect(_on_bay_pressed)
	_stage.background_pressed.connect(_on_background_pressed)
	_stage.missions_pressed.connect(open_missions)
	_stage.rival_pressed.connect(_on_rival_pressed)
	_stage.channel_picked.connect(open_missions)
	_stage.pick_changed.connect(_on_pick_changed)
	_stage.sign_pressed.connect(show_page.bind("robot"))
	_stage.target_pressed.connect(test_fire)
	var rack := _stage.parts_rack
	rack.chosen.connect(_on_rack_chosen)
	rack.bought.connect(buy)
	rack.hovered.connect(hover_item)
	rack.upgrade_pressed.connect(upgrade_selected)
	rack.unmounted.connect(clear_slot)
	rack.slot_picked.connect(_on_part_picked)
	var console := _stage.console
	console.upgrade_picked.connect(buy_upgrade)
	console.skill_picked.connect(learn)
	console.remove_pressed.connect(_on_robot_removed)
	console.setting_changed.connect(_on_setting_changed)
	console.quit_pressed.connect(func() -> void: get_tree().quit(0))
	_stage.projector.bought.connect(_on_offer_bought)
	_build_bench()
	_build_hud()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _launching:
			return
		if current_page() != "":
			close_panels()
		elif _channel != "":
			close_missions()
		else:
			show_page("ajustes")


# --- Construccion ------------------------------------------------------------


## Las cunas del banco (los huecos que no se ven en el dibujo del robot).
func _build_bench() -> void:
	for slot in HangarStage.RACK_TOP + HangarStage.RACK_BOTTOM:
		var cell := SlotCell.new()
		cell.slot = slot
		cell.accepts = Garage.slot_type(slot)
		cell.title = slot_title(slot)
		cell.picked.connect(_on_part_picked)
		cell.dropped.connect(_on_cell_dropped)
		cell.hovered.connect(_on_cell_hovered)
		_stage.add_child(cell)
		_stage.rack[slot] = cell


## Lo unico que queda fuera de la escena: el aviso pasajero (lo que se cobro
## en el ultimo combate, etc.).
func _build_hud() -> void:
	_toast = Label.new()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 96
	_toast.add_theme_font_size_override("font_size", 17)
	_toast.add_theme_color_override("font_color", COLOR_GOLD)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


# --- Estado ------------------------------------------------------------------


## Gira el robot del hangar a ese angulo, en grados (0 = de perfil).
func turn_robot(degrees: float) -> void:
	_stage.turn = deg_to_rad(degrees)


## Vuelve a pintar todo con el perfil actual.
func refresh() -> void:
	var brief := main._bench
	var profile := main._profile
	var build := main._robot_build(profile.build)
	var ghosts: Array[String] = []
	var shown := build
	if build.torso == null or build.legs == null:
		# Sin torso o sin piernas se ve el hueco: una pieza fantasma en su sitio.
		shown = main._robot_build(profile.build)
		if shown.torso == null:
			shown.torso = _placeholder(ItemDef.Type.TORSO)
			ghosts.append("torso")
		if shown.legs == null:
			shown.legs = _placeholder(ItemDef.Type.LEGS)
			ghosts.append("legs")
	_stage.show_build(shown, ghosts)
	_stage.selected_slot = _selected if _arming else ""
	# El monitor de misiones siempre ensena la campana; en el modo mision, su
	# canal, con la fila de rivales delante.
	if _channel == "":
		_stage.set_board(main.mission_state("campaign"))
	else:
		_stage.show_mission(main.mission_state(_channel))
	_stage.set_bays(_bays())
	for slot: String in _stage.rack:
		_refresh_cell(_stage.rack[slot])
	_refresh_info()
	# El tablero de piezas, con lo del hueco elegido.
	if _arming:
		var state := brief.rack(profile, _selected, _store_first)
		_stage.parts_rack.open(state)
		_stage.can_test = bool(state["can_test"])
	else:
		_stage.parts_rack.close()
		_stage.can_test = false
	if _console != "":
		_stage.show_console(_console_state())
	else:
		_stage.hide_console()
	if _offering:
		_stage.projector.state = brief.offers(profile)
	else:
		_stage.hide_offers()


## Lo que ensenan los rotulos de la escena (tu robot, tus celdas, tu nivel
## y el peso) y la lectura del robot del tablero.
func _refresh_info() -> void:
	var brief := main._bench
	var profile := main._profile
	var build := main._robot_build(profile.build)
	var problems := build.validate(main._rules)
	var upgrades: Array[float] = []
	for track in main._shop.track_ids():
		upgrades.append(float(profile.level_of(track)) / maxf(main._shop.max_level(), 1.0))
	var reading := brief.diagnostic(profile, _hover_id, _hover_slot)
	_stage.info = {
		"name": main.robot_name(profile.active),
		"problems": "" if problems.is_empty() else Txt.t("mech_problems", [", ".join(problems)]),
		"cells": profile.gold,
		"level": brief.level(profile),
		"xp": profile.xp,
		"xp_next": main._progression.next_level_xp(profile.xp),
		"weight": int(reading["weight"]),
		"weight_delta": int(reading["weight_delta"]) if _arming else 0,
		"max_weight": main._rules.max_weight,
		"overload": main._rules.overload,
		"upgrades": upgrades,
	}
	_stage.parts_rack.stats = reading["rows"]


func _console_state() -> Dictionary:
	var brief := main._bench
	match _console:
		"mejoras":
			return brief.upgrades(main._profile)
		"habilidades":
			return brief.skill_tree(main._profile)
		"ajustes":
			return WallConsole.settings_state(main._settings, true)
	return brief.robot(main._profile, main.robot_name(main._profile.active))


## La ficha del robot pidio desmontarlo (con sus dos pulsaciones): se
## desmonta y la ficha se recoge.
func _on_robot_removed() -> void:
	_console = ""
	main.remove_robot(main._profile.active)


## Un ajuste cambiado en el cuadro de control: se aplica y se guarda, y la
## pantalla ensena como queda.
func _on_setting_changed(key: String, value: Variant) -> void:
	main.change_setting(key, value)
	_stage.console.state = _console_state()


## Las tres bahias: tus otros robots (un armazon vacio se ve como bahia
## vacia, pero es tuyo) y, si caben mas, bahias para adquirir.
func _bays() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in main._profile.mechs.size():
		if i == main._profile.active or out.size() >= 3:
			continue
		var build := main._robot_build(main._profile.mechs[i]["build"])
		var armed := build.torso != null and build.legs != null
		out.append({"index": i, "build": build if armed else null, "name": main.robot_name(i)})
	while out.size() < main._rules.max_mechs - 1:
		out.append({"index": -1, "build": null, "name": ""})
	return out


func _refresh_cell(cell: SlotCell) -> void:
	var brief := main._bench
	var id := Garage.get_slot(main._profile.build, cell.slot)
	cell.item = brief.resolved(main._profile, id)
	cell.selected = cell.slot == _selected and _arming
	cell.locked_text = brief.lock_reason(main._profile, cell.slot)
	cell.progress_text = brief.progress_text(main._profile, cell.item)
	cell.refresh()


## Pieza con la que se dibuja un torso o unas piernas que faltan.
func _placeholder(type: ItemDef.Type) -> ItemDef:
	for id in main._profile.owned:
		var def := main._catalog.get_item(id)
		if def != null and def.type == type:
			return def
	return main._catalog.by_type(type)[0]


# --- Lo que se abre ------------------------------------------------------------


## Abre algo del hangar por su nombre: "pieza" (el tablero de piezas del
## hueco elegido), "tienda" (el tablero con la tienda delante), "mejoras",
## "habilidades" o "robot" (su pantalla, de cerca) o "misiones" (el modo
## mision).
func show_page(page: String) -> void:
	if page == "misiones":
		open_missions()
	elif page in CONSOLES:
		open_console(page)
	else:
		open_parts(page == "tienda")


## Saca el tablero de piezas del hueco elegido.
func open_parts(store_first: bool = false) -> void:
	if _launching:
		return
	close_missions()
	_console = ""
	_offering = false
	if not _arming:
		Sfx.play("ui_pagina")
	_arming = true
	_store_first = store_first
	_hover_id = ""
	_hover_slot = ""
	refresh()


## Acerca una pantalla de la pared: "mejoras", "habilidades", "robot" o
## "ajustes".
func open_console(kind: String) -> void:
	if _launching or not kind in CONSOLES:
		return
	close_missions()
	_arming = false
	_offering = false
	_console = kind
	_hover_id = ""
	_hover_slot = ""
	refresh()


## Una bahia vacia proyecta lo que se puede adquirir: un armazon vacio o un
## diseno ya armado.
func open_offers() -> void:
	if _launching:
		return
	close_missions()
	_arming = false
	_console = ""
	_offering = true
	refresh()
	_stage.show_offers(main._bench.offers(main._profile))
	_offering = _stage.projector.is_open()


## Se adquirio lo que proyectaba la bahia: "" es el armazon vacio.
func _on_offer_bought(id: String) -> void:
	_offering = false
	if id == "":
		main.acquire_frame()
	else:
		main.acquire_design(id)


## Recoge el tablero de piezas, la pantalla que este de cerca y el proyector
## de la bahia.
func close_panels() -> void:
	if current_page() == "":
		return
	_arming = false
	_console = ""
	_offering = false
	_hover_id = ""
	_hover_slot = ""
	Sfx.play("ui_cerrar")
	refresh()


## Lo que esta abierto: "pieza", "tienda", "mejoras", "habilidades", "robot",
## "adquirir" o "".
func current_page() -> String:
	if _console != "":
		return _console
	if _offering:
		return "adquirir"
	if _arming:
		return "tienda" if _store_first else "pieza"
	return ""


# --- Modo mision -------------------------------------------------------------------


## Pone el hangar en modo mision (o cambia de canal): en penumbra, con los
## rivales del canal proyectados delante de tu robot. `how` es como aparecen
## ("enter", "advance" al volver de ganar, "none"); `beaten`, el recien
## vencido.
func open_missions(
	channel: String = "campaign", how: String = "enter", beaten: Dictionary = {}
) -> void:
	if _launching:
		return
	if not channel in MissionBrief.CHANNELS:
		channel = "campaign"
	close_panels()
	_channel = channel
	_stage.show_mission(main.mission_state(channel), how, beaten)


## Vuelve al taller.
func close_missions() -> void:
	if _channel == "":
		return
	_channel = ""
	Sfx.play("ui_cerrar")
	_stage.hide_mission()
	_stage.set_board(main.mission_state("campaign"))


func missions_channel() -> String:
	return _channel


func _on_background_pressed() -> void:
	close_panels()
	close_missions()


## Una flecha del combate libre en el monitor.
func _on_pick_changed(key: String, step: int) -> void:
	main.change_free_pick(key, step)
	if _channel == "free":
		_stage.show_mission(main.mission_state("free"))


## Se pulso al primero de la fila: salir a combatir. Si tu robot no puede
## pelear se dice por que; el jefe pide una segunda pulsacion.
func _on_rival_pressed() -> void:
	if _launching or _channel == "":
		return
	var state := main.mission_state(_channel)
	if not bool(state["can_fight"]):
		Sfx.play("ui_cerrar")
		toast(str(state["problems"]))
		return
	if not _stage.confirm_rival():
		Sfx.play("ui_habilidad")
		return
	_launching = true
	var speed := main.animation_speed()
	await _stage.launch_out(speed)
	await main.drop_curtain(0.3 / speed)
	main.start_mission(_channel)


# --- Acciones ----------------------------------------------------------------


## Elige un hueco: se marca en el robot y sale el tablero con sus piezas.
func pick(slot: String) -> void:
	if not slot in Garage.SLOTS:
		return
	_selected = slot
	open_parts(_store_first and _arming)


func _on_part_picked(slot: String) -> void:
	Sfx.play("ui_tic")
	pick(slot)


func _on_bay_pressed(index: int) -> void:
	if index < 0:
		open_offers()
	else:
		main.use_robot(index)


## Una pieza tuya pulsada en el tablero: se monta en el hueco elegido; la
## que ya esta ahi, se quita.
func _on_rack_chosen(id: String) -> void:
	if Garage.get_slot(main._profile.build, _selected) == id:
		clear_slot(_selected)
	else:
		equip(_selected, id)


## Monta una pieza en el hueco elegido.
func equip_selected(id: String) -> void:
	equip(_selected, id)


func equip(slot: String, id: String) -> void:
	var locked := main._bench.lock_reason(main._profile, slot)
	if locked != "":
		Sfx.play("ui_cerrar")
		toast(Txt.t("workshop_locked", [locked]))
		return
	if Garage.equip(main._profile, main._catalog, slot, id) != "":
		return
	_selected = slot
	_hover_id = ""
	_hover_slot = ""
	main._save()
	Sfx.play("taller_montar")
	if _arming:
		refresh()
	else:
		open_parts()
	var item := main._bench.resolved(main._profile, id)
	if item != null:
		_stage.flash(slot, SlotCell.TIER_COLORS[item.tier])


## Deja un hueco vacio.
func clear_slot(slot: String) -> void:
	if Garage.get_slot(main._profile.build, slot) == "":
		return
	Garage.equip(main._profile, main._catalog, slot, "")
	_selected = slot
	main._save()
	Sfx.play("taller_quitar")
	refresh()


## La tecla del lector del tablero: sube de nivel o transforma la pieza del
## hueco elegido, lo que le toque.
func upgrade_selected() -> void:
	var item := _selected_item()
	if item == null:
		return
	var key := main._bench.upgrade_key(main._profile, item)
	if str(key.get("action", "")) == "transform":
		transform_selected()
	else:
		level_up_selected()


func level_up_selected() -> void:
	var item := _selected_item()
	if item == null:
		return
	var cap := main._campaign.level_cap(main._profile.zone)
	var key := item.progress_id()
	if main._profile.level_up(main._workshop, main._rules, key, main._zone_tier(), cap) != "":
		return
	main._save()
	Sfx.play("ui_subir_nivel")
	refresh()
	_stage.flash(_selected, SlotCell.TIER_COLORS[item.tier])


func transform_selected() -> void:
	var item := _selected_item()
	if item == null:
		return
	var item_max := main._catalog.get_item(item.id).tier_max
	var key := item.progress_id()
	var reason := main._profile.transform(
		main._workshop, main._rules, key, main._zone_tier(), item_max
	)
	if reason != "":
		return
	main._save()
	Sfx.play("ui_transformar")
	refresh()
	var now := main._bench.resolved(main._profile, item.id)
	_stage.flash(_selected, SlotCell.TIER_COLORS[now.tier])


func _selected_item() -> ItemDef:
	return main._bench.resolved(main._profile, Garage.get_slot(main._profile.build, _selected))


## Compra una pieza de la tienda. Si el hueco donde iria esta vacio, la
## monta; si no, queda colgada entre las tuyas.
func buy(id: String) -> void:
	if not _pay(id):
		return
	var slot := _slot_for(id)
	if slot != "" and Garage.get_slot(main._profile.build, slot) == "":
		equip(slot, id)
	else:
		refresh()


func _pay(id: String) -> bool:
	var tier := main._zone_tier()
	if main._garage.buy(main._profile, main._catalog, main._rules, main._workshop, id, tier) != "":
		return false
	Sfx.play("ui_comprar")
	main._save()
	return true


## Hueco donde iria una pieza: el elegido si le cabe, o el primero libre de su
## tipo que tu nivel ya abra.
func _slot_for(id: String) -> String:
	return main._bench.slot_for(main._profile, id, _selected)


## Sube una de las mejoras permanentes, con el tope de la zona.
func buy_upgrade(track: String) -> void:
	if main._profile.buy(main._shop, track, main._armory_cap()) != "":
		return
	Sfx.play("ui_comprar")
	main._save()
	refresh()


## Aprende la siguiente habilidad de una rama.
func learn(id: String) -> void:
	if main._skills.learn(main._profile, id, main._player_level()) != "":
		return
	Sfx.play("ui_habilidad")
	main._save()
	refresh()


## Dispara el arma del hueco elegido contra la diana.
func test_fire() -> void:
	var item := _selected_item()
	if item == null or item.fx == "":
		return
	_stage.test_fire(_selected, item.fx, ShotFx.ammo_color(item.element))


## Aviso pasajero arriba (lo que paso en el ultimo combate, por ejemplo).
func toast(text: String) -> void:
	if text == "" or _toast == null:
		return
	_toast.text = text
	_toast.modulate = Color(1, 1, 1, 1)
	var fade := create_tween()
	fade.tween_interval(4.0)
	fade.tween_property(_toast, "modulate:a", 0.0, 1.0)


func _on_cell_dropped(slot: String, data: Dictionary) -> void:
	if data.get("buy", false) and not _pay(data["id"]):
		return
	var from: String = data.get("from_slot", "")
	if from != "":
		# De un hueco a otro de su tipo: se cambian.
		var other := Garage.get_slot(main._profile.build, slot)
		Garage.equip(main._profile, main._catalog, from, other)
	equip(slot, data["id"])


func _on_stage_dropped(data: Dictionary) -> void:
	var slot := _slot_for(data["id"])
	if slot == "":
		return
	if data.get("buy", false) and not _pay(data["id"]):
		return
	equip(slot, data["id"])


## Pasar el raton por una pieza del tablero: la lectura del robot ensena
## cuanto cambia con ella en el hueco donde iria, y ese hueco se marca en el
## dibujo.
func hover_item(id: String, inside: bool) -> void:
	_hover_id = id if inside else ""
	_hover_slot = _slot_for(id) if inside else ""
	_stage.hover_slot = _hover_slot
	_refresh_info()


func _on_cell_hovered(slot: String, inside: bool) -> void:
	_stage.hover_slot = slot if inside else ""


# --- Textos ------------------------------------------------------------------


## Nombre de un hueco: "Lateral 1", "Torso"...
static func slot_title(slot: String) -> String:
	return WorkshopBrief.slot_title(slot)


## Lo que hace una pieza, en una linea (o en varias con `long`).
static func item_stats(item: ItemDef, long: bool) -> String:
	return WorkshopBrief.item_stats(item, long)
