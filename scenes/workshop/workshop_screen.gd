class_name WorkshopScreen
extends Control
## El hangar: la pantalla de inicio, inmersiva y "casi como si no existiera
## un menu" (pedidos del usuario del 2026-11-18 y el 2026-11-20). Es el
## taller y la armeria a la vez, todo dentro de la escena (HangarStage):
## - tu robot en el centro, sobre su plataforma giratoria. Sus piezas no se
##   eligen tocandolo: pulsarlo acerca la computadora del taller;
## - la computadora del taller (LoadoutScreen; decision del usuario del
##   2026-11-21, OBS-030): la pantalla "TALLER" de la pared. De cerca ensena
##   el plano del robot de frente con una casilla por hueco y, al lado, las
##   piezas que caben en la casilla elegida, las tuyas y las de la tienda, por
##   tipo: se pulsan para montarlas o comprarlas, y ahi mismo se suben de
##   nivel. La diana del hangar prueba el arma de la ultima casilla tocada;
## - desde la OBS-048 el robot esta desarmado (TeardownView): cada pieza se
##   elige donde esta y "Cambiar pieza" abre a su lado el estuche de piezas
##   (PartsCase), sin la computadora;
## - tus otros robots en las bahias del fondo: un clic y pasas a usarlo; una
##   bahia vacia proyecta lo que puede fabricar (BayProjector): un armazon
##   de cada tipo de robot, que se adquiere pulsandolo dos veces;
## - las pantallas de mejoras y habilidades se usan ahi mismo, de cerca
##   (WallConsole); el rotulo de tu robot ensena su ficha y el cuadro de
##   control de la esquina, los ajustes;
## - el monitor de misiones: al pulsarlo el hangar se queda en penumbra y los
##   rivales se proyectan delante de tu robot (RivalRow); pulsar al primero
##   es salir a combatir.
## No hay cajon, ni listas, ni barra de estado, ni botones fuera de la
## escena: pulsar el hangar vacio o Esc recoge lo que este abierto (y Esc, sin
## nada abierto, acerca los ajustes). Lo que se ensena lo arma WorkshopBrief;
## lee y cambia el perfil a traves de MainScreen, que lo guarda.

signal closed

## Lo que se puede abrir por su nombre (show_page).
const CONSOLES: Array[String] = ["mejoras", "habilidades", "robot", "ajustes", "arbol"]
const COLOR_GOLD := Color("ffd36b")

var main: MainScreen

var _selected: String = "side0"
var _hover_id: String = ""
## Hueco con el que se compara la pieza bajo el raton.
var _hover_slot: String = ""
## La computadora del taller esta de cerca.
var _arming := false
## Pantalla que esta de cerca: "mejoras", "habilidades", "robot" o "".
var _console: String = ""
## Una bahia vacia esta proyectando lo que se puede adquirir.
var _offering := false
## El banco del especialista esta abierto (GDD 8.6), con esa pieza elegida
## y lo que acaba de decir.
var _special := false
## La etiqueta de la pieza elegida ensena sus aspectos (OBS-051).
var _aspecting := false
var _proto_slot := "side0"
var _said := ""
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
	_stage.robot_pressed.connect(_on_robot_pressed)
	_stage.teardown_picked.connect(_on_teardown_picked)
	_stage.tag_pressed.connect(_on_tag_pressed)
	_stage.terminal_pressed.connect(show_page)
	_stage.bay_pressed.connect(_on_bay_pressed)
	_stage.background_pressed.connect(_on_background_pressed)
	_stage.missions_pressed.connect(open_missions)
	_stage.rival_pressed.connect(_on_rival_pressed)
	_stage.channel_picked.connect(open_missions)
	_stage.pick_changed.connect(_on_pick_changed)
	_stage.protection_picked.connect(_on_protection_picked)
	_stage.sign_pressed.connect(show_page.bind("robot"))
	_stage.target_pressed.connect(test_fire)
	_stage.loadout.slot_picked.connect(pick)
	_stage.loadout.close_pressed.connect(close_panels)
	_stage.specialist.piece_picked.connect(pick_proto_slot)
	_stage.specialist.proto_confirmed.connect(buy_prototype)
	_stage.specialist.close_pressed.connect(close_panels)
	# El catalogo de la computadora y el del estuche junto a la pieza.
	for rack: PartsRack in [_stage.loadout.rack, _stage.parts_case.rack]:
		rack.chosen.connect(_on_rack_chosen)
		rack.bought.connect(buy)
		rack.hovered.connect(hover_item)
		rack.upgrade_pressed.connect(upgrade_selected)
		rack.paint_picked.connect(paint_selected)
	_stage.parts_case.close_pressed.connect(close_panels)
	var console := _stage.console
	console.upgrade_picked.connect(buy_upgrade)
	console.skill_picked.connect(learn)
	console.tree_picked.connect(learn_tree)
	console.page_picked.connect(open_console)
	console.remove_pressed.connect(_on_robot_removed)
	console.setting_changed.connect(_on_setting_changed)
	console.quit_pressed.connect(func() -> void: get_tree().quit(0))
	_stage.projector.bought.connect(_on_offer_bought)
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
	_stage.teardown.show_state(brief.teardown(profile, shown))
	_show_tag()
	_stage.show_build(shown, ghosts)
	# El monitor de misiones siempre ensena la campana; en el modo mision, su
	# canal, con la fila de rivales delante.
	if _channel == "":
		_stage.set_board(main.mission_state("campaign"))
	else:
		_stage.show_mission(main.mission_state(_channel))
	_stage.set_bays(_bays())
	# Cambiar pieza: en el robot desarmado, el estuche junto a la pieza
	# (OBS-048); en el hangar de antes, la computadora del taller, con el
	# plano y el catalogo de la casilla elegida.
	if _arming and _stage.teardown_on:
		_stage.hide_loadout()
		_stage.show_case(brief.rack(profile, _selected), "slot:" + _selected)
	elif _arming:
		_stage.loadout.show_build(shown, ghosts)
		_stage.show_loadout(brief.loadout(profile, main.robot_name(profile.active), _selected))
	else:
		_stage.hide_loadout()
		_stage.hide_case()
	_refresh_info()
	# Con todo recogido, la diana prueba el arma de la ultima casilla tocada.
	var item := _selected_item()
	_stage.can_test = (
		current_page() == ""
		and _channel == ""
		and item != null
		and item.deals_damage()
		and item.fx != ""
		and brief.lock_reason(profile, _selected) == ""
	)
	if _console != "":
		_stage.show_console(_console_state())
	else:
		_stage.hide_console()
	if _offering:
		_stage.projector.state = brief.offers(profile)
	else:
		_stage.hide_offers()
	if _special:
		var said := _said
		_stage.show_specialist(
			SpecialistBrief.state(profile, brief, main._prototypes, _proto_slot, said)
		)
	else:
		_stage.hide_specialist()


## Algo del robot desarmado (OBS-048): se elige (o se suelta si ya lo estaba).
func _on_teardown_picked(key: String) -> void:
	var view := _stage.teardown
	# Con el estuche abierto, otra pieza se lo lleva a su lado; la misma pieza
	# o lo que no es pieza lo cierra.
	if _arming:
		if key.begins_with("slot:") and key != view.selected:
			_selected = key.trim_prefix("slot:")
			view.selected = key
			_hover_id = ""
			_hover_slot = ""
			Sfx.play("ui_tic")
			refresh()
			return
		close_panels()
		if key == view.selected:
			return
	view.selected = "" if view.selected == key else key
	_aspecting = false
	if view.selected.begins_with("slot:"):
		_selected = view.selected.trim_prefix("slot:")
	Sfx.play("ui_tic")
	view.queue_redraw()
	_show_tag()


## La etiqueta de lo elegido en el robot desarmado, junto a ello.
func _show_tag() -> void:
	# Con el estuche abierto, la etiqueta se recoge: el estuche la sustituye.
	if _arming and _stage.teardown_on:
		_stage.tag.hide_tag()
		return
	var key := _stage.teardown.selected
	var brief := main._bench
	var profile := main._profile
	var state := {}
	if key.begins_with("slot:"):
		var slot := key.trim_prefix("slot:")
		state = brief.piece_tag(profile, slot)
		# Sus aspectos (OBS-051): la tecla que los abre, o sus filas.
		var item := brief.resolved(profile, Garage.get_slot(profile.build, slot))
		var label := AspectBrief.key_label(main._aspects, profile, item)
		if label != "" and brief.lock_reason(profile, slot) == "":
			if _aspecting:
				state = AspectBrief.state(main._aspects, profile, item)
			else:
				state["aspects"] = label
	elif key.begins_with("system:"):
		state = brief.system_tag(profile, key.trim_prefix("system:"))
		_add_tree_key(state, key.trim_prefix("system:"))
	elif key == "core":
		state = brief.core_tag(profile)
	if state.is_empty():
		_stage.tag.hide_tag()
	else:
		_stage.tag.show_tag(state, _stage.teardown.rect_of(key))


## Un sistema al nivel 10 abre su rama del arbol de mejoras (OBS-051): su
## etiqueta lleva la tecla que lo ensena.
func _add_tree_key(state: Dictionary, track: String) -> void:
	if state.is_empty() or int(state.get("level", 0)) < UpgradeTree.OPENS_AT:
		return
	for branch: Dictionary in main._tree.branches:
		if branch["from"] == track:
			state["tree"] = Txt.t("tag_tree", [branch["name"]])


## Una tecla de la etiqueta: subir la pieza, cambiarla, subir un sistema
## o aprender una habilidad.
func _on_tag_pressed(key: String) -> void:
	if key == "upgrade":
		upgrade_selected()
	elif key == "change":
		open_parts()
	elif key == "buy":
		buy_upgrade(_stage.teardown.selected.trim_prefix("system:"))
	elif key == "tree":
		_stage.tag.hide_tag()
		open_console("arbol")
	elif key == "aspects" or key == "aspects_back":
		_aspecting = key == "aspects"
		Sfx.play("ui_clic")
		_show_tag()
	elif key.begins_with("aspect:"):
		raise_aspect(key.trim_prefix("aspect:"))
	elif key.begins_with("learn:"):
		learn(key.trim_prefix("learn:"))


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
		"specialist_unlock": main._prototypes.unlock_level,
		"xp": profile.xp,
		"xp_next": main._progression.next_level_xp(profile.xp),
		"weight": int(reading["weight"]),
		"weight_delta": int(reading["weight_delta"]) if _arming else 0,
		"max_weight": main._player_build().max_weight(main._rules),
		"overload": main._rules.overload,
		"upgrades": upgrades,
	}
	_stage.loadout.rack.stats = reading["rows"]
	_stage.parts_case.rack.stats = reading["rows"]


func _console_state() -> Dictionary:
	var brief := main._bench
	match _console:
		"mejoras":
			return brief.upgrades(main._profile)
		"habilidades":
			return brief.skill_tree(main._profile)
		"arbol":
			return TreeBrief.state(main._tree, main._shop, main._profile)
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


## Pieza con la que se dibuja un torso o unas piernas que faltan.
func _placeholder(type: ItemDef.Type) -> ItemDef:
	for id in main._profile.owned:
		var def := main._catalog.get_item(id)
		if def != null and def.type == type:
			return def
	return main._catalog.by_type(type)[0]


# --- Lo que se abre ------------------------------------------------------------


## Abre algo del hangar por su nombre: "taller" (la computadora del taller,
## con la casilla elegida), "mejoras", "habilidades", "robot" o "ajustes" (su
## pantalla, de cerca) o "misiones" (el modo mision).
func show_page(page: String) -> void:
	if page == "misiones":
		open_missions()
	elif page == "especialista":
		open_specialist()
	elif page in CONSOLES:
		open_console(page)
	else:
		open_parts()


## Cambiar la pieza del hueco elegido: el estuche junto a ella en el robot
## desarmado (OBS-048) o, en el hangar de antes, la computadora del taller.
func open_parts() -> void:
	if _launching:
		return
	if _stage.teardown_on:
		_stage.teardown.selected = "slot:" + _selected
	close_missions()
	_console = ""
	_offering = false
	_special = false
	_arming = true
	_hover_id = ""
	_hover_slot = ""
	refresh()


## Acerca el banco del especialista (GDD 8.6).
func open_specialist() -> void:
	if _launching:
		return
	close_missions()
	_arming = false
	_console = ""
	_offering = false
	_special = true
	_said = ""
	refresh()


## Elige la pieza a la que el especialista le ensena sus prototipos.
func pick_proto_slot(slot: String) -> void:
	_proto_slot = slot
	_said = ""
	refresh()


## Compra un prototipo (o su rango siguiente) para la pieza elegida.
func buy_prototype(id: String) -> void:
	var profile := main._profile
	var protos := main._prototypes
	var why := protos.buy(profile, main._catalog, main._bench.level(profile), _proto_slot, id)
	if why != "":
		Sfx.play("ui_cerrar")
		_said = why
		refresh()
		return
	main._save()
	Sfx.play("ui_subir_nivel")
	var item := main._catalog.get_item(Garage.get_slot(profile.build, _proto_slot))
	var rank := int(PrototypeLibrary.installed(profile, item.progress_id()).get("rank", 1))
	_said = Txt.t("specialist_line_done", [protos.display_name(id), SpecialistBrief.ROMAN[rank]])
	_stage.specialist.celebrate()
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


## Se adquirio lo que proyectaba la bahia: el armazon de un tipo de robot.
func _on_offer_bought(id: String) -> void:
	_offering = false
	main.acquire_frame(id)


## Recoge el tablero de piezas, la pantalla que este de cerca y el proyector
## de la bahia.
func close_panels() -> void:
	if current_page() == "":
		return
	_arming = false
	_special = false
	_console = ""
	_offering = false
	_hover_id = ""
	_hover_slot = ""
	Sfx.play("ui_cerrar")
	refresh()


## Lo que esta abierto: "taller", "mejoras", "habilidades", "robot",
## "ajustes", "adquirir" o "".
func current_page() -> String:
	if _special:
		return "especialista"
	if _console != "":
		return _console
	if _offering:
		return "adquirir"
	if _arming:
		return "taller"
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
	# A la zona de combate: lo elegido del robot desarmado se suelta.
	_stage.teardown.selected = ""
	_show_tag()
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
	# En la zona de combate (OBS-048) se vuelve por su rotulo o con Esc, no
	# al pulsar cualquier sitio de la arena.
	if not _stage.teardown_on or _stage.is_mission_on() == false:
		close_missions()
	elif _stage._hover_terminal == "volver":
		close_missions()
	# El robot desarmado: se suelta lo elegido y se recoge su etiqueta.
	_stage.teardown.selected = ""
	_stage.teardown.queue_redraw()
	_show_tag()


## Una flecha del combate libre en el monitor.
func _on_pick_changed(key: String, step: int) -> void:
	main.change_free_pick(key, step)
	if _channel == "free":
		_stage.show_mission(main.mission_state("free"))


## Una proteccion de la campana comprada en el monitor.
func _on_protection_picked(kind: String) -> void:
	var reason := main.buy_protection(kind)
	if reason != "":
		toast(reason)
	refresh()


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
	open_parts()


## Se pulso tu robot: se acerca la computadora del taller; con algo ya
## abierto, se recoge.
func _on_robot_pressed() -> void:
	if current_page() != "" or _channel != "":
		_on_background_pressed()
	else:
		open_parts()


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
	var why := Garage.equip(main._profile, main._catalog, slot, id, main._styles)
	if why != "":
		if why.begins_with("un robot de"):
			Sfx.play("ui_cerrar")
			toast(Txt.t("workshop_wrong_style", [main._styles.role(main._profile.style)]))
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
		_flash(slot, PartIcon.TIER_COLORS[item.tier])


## Pinta de ese color (Garage.PAINTS) la pieza del hueco elegido (OBS-010).
## Volver al color de su elemento es quitarle la pintura.
func paint_selected(color: String) -> void:
	var profile := main._profile
	if main._bench.paints(profile, _selected).is_empty():
		return
	Garage.set_paint(profile.build, _selected, "")
	if main._bench.paint_shown(profile, _selected) != color:
		Garage.set_paint(profile.build, _selected, color)
	main._save()
	Sfx.play("taller_montar")
	refresh()
	_flash(_selected, WorkshopBrief.PAINT_COLORS[color])


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
	match str(key.get("action", "")):
		"transform":
			transform_selected()
		"evolve":
			evolve_selected()
		_:
			level_up_selected()


## Evoluciona el arma del hueco elegido en la del tipo siguiente (OBS-045).
func evolve_selected() -> void:
	var item := _selected_item()
	if item == null:
		return
	var profile := main._profile
	var why := ""
	if item.type == ItemDef.Type.DRONE and profile.build.has("assist"):
		why = profile.evolve_with_assist(main._workshop, main._catalog, item.id)
	else:
		why = profile.evolve(main._workshop, main._rules, main._catalog, item.id, main._zone_tier())
	if why != "":
		return
	main._save()
	Sfx.play("ui_transformar")
	refresh()
	var now := _selected_item()
	if now != null:
		_flash(_selected, PartIcon.TIER_COLORS[now.tier])


## Sube un nivel un aspecto de la pieza elegida (OBS-051): cobra, guarda y
## la pieza cambia en el momento en el robot desarmado.
func raise_aspect(id: String) -> void:
	var item := _selected_item()
	if item == null or main._aspects.raise(main._profile, item, id) != "":
		Sfx.play("ui_cerrar")
		return
	main._save()
	Sfx.play("ui_subir_nivel")
	refresh()
	_flash(_selected, AspectLook.color_of(id))


func level_up_selected() -> void:
	var item := _upgrade_item()
	if item == null:
		return
	var cap := main._campaign.level_cap(main._profile.zone)
	var key := item.progress_id()
	if main._profile.level_up(main._workshop, main._rules, key, main._zone_tier(), cap) != "":
		return
	main._save()
	Sfx.play("ui_subir_nivel")
	refresh()
	_flash(_selected, PartIcon.TIER_COLORS[item.tier])


func transform_selected() -> void:
	var item := _upgrade_item()
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
	_flash(_selected, PartIcon.TIER_COLORS[now.tier])


func _selected_item() -> ItemDef:
	return main._bench.resolved(main._profile, Garage.get_slot(main._profile.build, _selected))


## La pieza que sube la tecla del hueco elegido: la suya o, en un dron del
## asistente, el asistente (sus armas suben con el).
func _upgrade_item() -> ItemDef:
	var item := _selected_item()
	var profile := main._profile
	if item != null and item.type == ItemDef.Type.DRONE and profile.build.has("assist"):
		return main._bench.resolved(profile, str(profile.build["assist"]))
	return item


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
	var def: ItemDef = main._catalog.get_item(id)
	if def != null and def.type == ItemDef.Type.ASSIST:
		# El asistente no se compra hasta que tu nivel abre su hueco.
		if main._bench.lock_reason(main._profile, "assist") != "":
			return false
	var open := main._campaign.boss_weapons_open(main._profile)
	var why := ""
	if def != null and def.has_tag(ItemDef.TAG_ARENA):
		# Las armas de arena se forjan (OBS-051, rama Forja del arbol).
		var effects := main._bench.tree_effects(main._profile)
		why = main._gear.forge(main._profile, main._catalog, id, effects)
	else:
		why = main._garage.buy(
			main._profile, main._catalog, main._rules, main._workshop, id, tier, open
		)
	if why != "":
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
	var level: int = main._player_level()
	if main._profile.buy(main._shop, track, main._armory_cap(), level) != "":
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


## Aprende un nodo del arbol de mejoras (OBS-051) con puntos de mejora.
func learn_tree(id: String) -> void:
	if main._tree.learn(main._profile, id) != "":
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


## Destello al montar, pintar, subir o transformar: en la casilla de la
## computadora y, si esta abierto, en el estuche y su pieza.
func _flash(slot: String, color: Color) -> void:
	_stage.loadout.flash(slot, color)
	if _stage.parts_case.is_open():
		_stage.parts_case.flash(color)


## Aviso pasajero arriba (lo que paso en el ultimo combate, por ejemplo).
func toast(text: String) -> void:
	if text == "" or _toast == null:
		return
	_toast.text = text
	_toast.modulate = Color(1, 1, 1, 1)
	var fade := create_tween()
	fade.tween_interval(4.0)
	fade.tween_property(_toast, "modulate:a", 0.0, 1.0)


## Pasar el raton por una pieza del catalogo: la lectura del robot ensena
## cuanto cambia con ella en la casilla elegida.
func hover_item(id: String, inside: bool) -> void:
	_hover_id = id if inside else ""
	_hover_slot = _selected if inside else ""
	_refresh_info()


# --- Textos ------------------------------------------------------------------


## Nombre de un hueco: "Lateral 1", "Torso"...
static func slot_title(slot: String) -> String:
	return WorkshopBrief.slot_title(slot)


## Lo que hace una pieza, en una linea (o en varias con `long`).
static func item_stats(item: ItemDef, long: bool) -> String:
	return WorkshopBrief.item_stats(item, long)
