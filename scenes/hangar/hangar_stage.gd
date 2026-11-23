class_name HangarStage
extends MechStage
## El hangar entero, como pantalla de inicio (pedido del usuario el
## 2026-11-18: "la menor cantidad de botones, todo integrado como vista de
## taller, inmersivo y con muchos detalles"). Sobre el escenario del taller
## (MechStage) anade:
## - tus otros robots en tres bahias al fondo, mas pequenos y en penumbra
##   (un clic y pasas a usarlo; una bahia vacia es para adquirir uno);
## - tres pantallas en la pared: la del taller es la computadora donde se
##   arma el robot (LoadoutScreen: su plano de frente con una casilla por
##   hueco y, al lado, las piezas disponibles); las de mejoras y habilidades
##   se usan ahi mismo, de cerca (WallConsole); en la esquina, el cuadro de
##   control de los ajustes, que se usa igual;
## - la diana, que prueba el arma de la ultima casilla que tocaste;
## - el monitor de misiones (MissionBoard): el cuadro de campana. Al pulsarlo
##   el hangar pasa al modo mision: se queda en penumbra y los rivales se
##   proyectan en el suelo delante de tu robot (RivalRow); pulsar al primero
##   es salir a combatir;
## - lo que antes iba en una barra de arriba, repartido por la escena: el
##   nombre de tu robot en el rotulo que cuelga sobre su bahia (se pulsa para
##   ver su ficha), sus celdas en la pantalla de la tienda, su nivel en la de
##   habilidades, sus mejoras en la de mejoras y su peso en la bascula que
##   hay junto a la plataforma;
## - el robot, de perfil sobre su plataforma: pulsarlo acerca la computadora
##   del taller (OBS-030). Ya no gira (OBS-036, del usuario: "quitemos la
##   parte de la rotacion en 3D, eso ya queda cancelado").
## Pulsar el hangar vacio recoge lo que este abierto.

signal terminal_pressed(terminal: String)
## El monitor de misiones, con el modo mision apagado.
signal missions_pressed
## El primero de la fila de rivales: salir a combatir.
signal rival_pressed
signal channel_picked(channel: String)
signal pick_changed(key: String, step: int)
## Una proteccion de la campana, comprada en el monitor de misiones.
signal protection_picked(kind: String)
## El rotulo de la bahia: la ficha de tu robot.
signal sign_pressed
## La diana, con un arma que se puede probar en el hueco elegido.
signal target_pressed
signal bay_pressed(index: int)
signal background_pressed
## Se pulso tu robot, sin arrastrarlo.
signal robot_pressed
## Algo del robot desarmado (TeardownView): "slot:<hueco>",
## "system:<mejora>" o "core".
signal teardown_picked(key: String)
## Una tecla de la etiqueta de lo elegido (TeardownTag).
signal tag_pressed(key: String)

## Lo que hay en la pared y se pulsa: tres pantallas y el cuadro de control
## de los ajustes.
## "especialista" es su banco en el suelo (GDD 8.6), no una pantalla de pared.
const TERMINALS: Array[String] = ["taller", "mejoras", "habilidades", "ajustes", "especialista"]
## Centro de cada bahia, como parte del ancho. Las dos de la izquierda van
## separadas para que el arma de un robot no tape al de al lado.
const BAY_X: Array[float] = [0.085, 0.225, 0.815]
## En la zona de combate (OBS-048) tus otros robots esperan de pie a la
## izquierda del tuyo, grandes: "tus combatientes en tamano real".
const ZONE_BAY_X: Array[float] = [0.07, 0.165, 0.26]
const ZONE_BAY_HEIGHT := 0.4
const COLOR_SCREEN := Color("0b2a33")
const COLOR_SCREEN_LINE := Color("3fd0e6")
const COLOR_TEXT := Color("bfefff")
const COLOR_SOCKET := Color("57d3ff")
## Modo mision: lo que tarda en bajar la luz.
const MISSION_SECONDS := 0.35
## Radio de la diana al tocarla.
const TARGET_RADIUS := 40.0
## Salir a combatir: lo que dura y lo que anda tu robot (unidades del dibujo).
const LAUNCH_SECONDS := 0.85
const LAUNCH_WALK := 250.0

## Lo que ensenan los rotulos del hangar (lo pone WorkshopScreen):
## {"name", "problems", "cells", "level", "xp", "xp_next" (-1 = nivel maximo),
##  "weight", "max_weight", "overload", "upgrades" (de 0 a 1, una por mejora)
##  y "weight_delta" (lo que cambiaria el peso con la pieza bajo el raton)}.
var info: Dictionary = {}
## El robot desarmado en revision (OBS-048) en lugar del robot armado,
## sin bahias, sin las pantallas de taller, mejoras y habilidades y sin
## el monitor de misiones.
var teardown_on := true
var teardown := TeardownView.new()
var tag := TeardownTag.new()
## El estuche de piezas que se abre junto a la pieza elegida (OBS-048).
var parts_case := PartsCase.new()
## La computadora del taller y la pantalla de cerca: WorkshopScreen les da
## lo que ensenan y oye lo que se pulsa en ellas.
var loadout := LoadoutScreen.new()
var console := WallConsole.new()
## El proyector de la bahia vacia que se pulso: lo que se puede adquirir.
var projector := BayProjector.new()
## El banco del especialista, de cerca (GDD 8.6, OBS-043).
var specialist := SpecialistScreen.new()
## La casilla elegida lleva un arma que se puede probar: la diana se enciende.
var can_test := false:
	set(value):
		can_test = value
		_overlay.queue_redraw()

## Cuanto esta el hangar en modo mision: 0 = el taller, 1 = en penumbra con
## los rivales delante.
var mission := 0.0:
	set(value):
		mission = value
		_target_alpha = 0.0 if teardown_on else 1.0 - value
		_board.open = value
		_apply_zone()
		_dim.queue_redraw()
		_overlay.queue_redraw()
## Robots de las bahias: [{"index", "build", "name"}]; uno con "index" -1 es
## una bahia vacia.
var bays: Array[Dictionary] = []

var _bay_layer := Node2D.new()
## La arena de la zona de combate, que tapa el hangar en el modo mision.
var _arena := Node2D.new()
var _arena_tick := 0.0
## Tu robot en holograma en la pantalla TALLER de la pared (OBS-042, del
## usuario: "por cierto, eso se ve muy chafa", del robot de palitos que habia).
var _wall_robot := MechBlueprint.new()
var _bay_views: Array[MechView] = []
var _terminal_rects: Dictionary[String, Rect2] = {}
var _bay_rects: Array[Rect2] = []
var _hover_terminal: String = ""
var _hover_bay: int = -2
## Ultima bahia pulsada (su sitio en la fila): ahi se enciende el proyector.
var _pressed_bay: int = -1
var _hover_sign := false
var _hover_target := false
var _font: Font
## Lo que ocupa el robot en el taller (para saber si se pulsa).
var _bounds := Rect2()
## El raton sobre tu robot: se pulsa para acercar la computadora.
var _hover_robot := false
var _dim := Node2D.new()
var _row := RivalRow.new()
var _board := MissionBoard.new()
var _mission_on := false
var _mission_tween: Tween
## Saliendo a combatir: ya no se toca nada. Y su alarma (0 a 1).
var _launching := false
var _alarm := 0.0
## Centro de la plataforma al salir: se queda en su sitio aunque el robot ande.
var _launch_center := 0.0
## Lo quieto del hangar, pintado una vez en una textura (ver _draw).
var _still := SubViewport.new()
var _still_art := Node2D.new()
var _still_ready := false
var _still_key := ""
## Cuadros que faltan para que la textura este pintada.
var _still_wait := 0


func _ready() -> void:
	super._ready()
	add_child(_bay_layer)
	move_child(_bay_layer, 0)
	add_child(_arena)
	move_child(_arena, 0)
	_arena.draw.connect(_draw_arena)
	# Sobre el fondo y las bahias, la penumbra del modo mision y la fila de
	# rivales; tu robot queda por delante de todo.
	add_child(_dim)
	move_child(_dim, 1)
	_dim.draw.connect(_draw_dim)
	add_child(_row)
	move_child(_row, 2)
	add_child(_board)
	_board.opened.connect(func() -> void: missions_pressed.emit())
	_board.channel_picked.connect(func(channel: String) -> void: channel_picked.emit(channel))
	_board.pick_changed.connect(func(key: String, step: int) -> void: pick_changed.emit(key, step))
	_board.protection_picked.connect(func(kind: String) -> void: protection_picked.emit(kind))
	add_child(teardown)
	move_child(teardown, _world.get_index() + 1)
	add_child(tag)
	move_child(tag, teardown.get_index() + 1)
	add_child(parts_case)
	move_child(parts_case, tag.get_index() + 1)
	add_child(projector)
	_wall_robot.scan = true
	add_child(_wall_robot)
	add_child(console)
	add_child(loadout)
	add_child(specialist)
	mouse_exited.connect(_clear_hover)
	_mech.footstep.connect(_on_footstep)
	_font = get_theme_default_font()
	_row.font = _font
	_still.disable_3d = true
	_still.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_still.add_child(_still_art)
	_still_art.draw.connect(func() -> void: _draw_still(_still_art))
	add_child(_still)
	get_viewport().size_changed.connect(_refresh_still)


# --- Modo mision -------------------------------------------------------------------


## Lo que ensena el monitor de misiones (MissionBrief), tambien sin abrir.
## Tu robot: en el hangar y, en holograma, en la pantalla TALLER.
func show_build(build: MechBuild, ghosts: Array[String]) -> void:
	super.show_build(build, ghosts)
	# En la pantalla, solo el robot: el asistente flota tan alto que lo
	# dejaba diminuto.
	var body := build
	if build != null and build.assist != null:
		body = build.duplicate() as MechBuild
		body.assist = null
		body.drone = null
		body.drone_low = null
	_wall_robot.show_build(body, ghosts)


func set_board(state: Dictionary) -> void:
	_board.state = state


## Pasa al modo mision (o cambia lo que ensena): el hangar se queda en
## penumbra y los rivales de `state` se proyectan delante de tu robot. `how`
## es como aparecen (RivalRow.show_rivals); `beaten`, el rival recien vencido.
func show_mission(state: Dictionary, how: String = "enter", beaten: Dictionary = {}) -> void:
	_board.state = state
	_row.blocked = "" if bool(state.get("can_fight", true)) else str(state.get("problems", ""))
	_row.warning = str(state.get("warning", ""))
	_row.confirm = bool(state.get("confirm", false))
	_row.confirm_text = str(state.get("confirm_text", ""))
	_row.danger = bool(state.get("danger", true))
	var rivals: Array[Dictionary] = []
	rivals.assign(state.get("rivals", []))
	_row.show_rivals(rivals, how, beaten)
	if how == "advance":
		_board.flash_lamp(int(state.get("fight", 0)) - 1, RivalRow.BEATEN_HOLD)
	if _mission_on:
		return
	_mission_on = true
	if how == "enter":
		Sfx.play("ui_abrir")
	_tween_mission(1.0, 0.0 if how == "none" else MISSION_SECONDS)


## Vuelve al taller: la fila se apaga y sube la luz.
func hide_mission() -> void:
	if not _mission_on:
		return
	_mission_on = false
	_row.clear()
	_tween_mission(0.0, MISSION_SECONDS * 0.8)


func is_mission_on() -> bool:
	return _mission_on


## El jefe pide pulsar dos veces: la primera lo deja armado. True si con
## esta pulsacion ya se sale a combatir.
func confirm_rival() -> bool:
	if not _row.confirm or _row.armed:
		return true
	_row.armed = true
	return false


func _tween_mission(to: float, seconds: float) -> void:
	if _mission_tween != null:
		_mission_tween.kill()
	if seconds <= 0.0:
		mission = to
		return
	_mission_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mission_tween.tween_property(self, "mission", to, seconds)


## Salir a combatir: las proyecciones se cortan, salta la alarma y tu robot
## echa a andar hacia la salida. Se espera a que termine. `speed` es la
## velocidad de las animaciones de los ajustes.
func launch_out(speed: float = 1.0) -> void:
	_launch_center = _platform_center()
	_launching = true
	_row.hover = false
	Sfx.play("despliegue")
	_row.collapse(0.25 / speed)
	create_tween().tween_property(self, "_alarm", 1.0, 0.2 / speed)
	_mech.move_to(_mech.position + Vector2(LAUNCH_WALK, 0.0), LAUNCH_SECONDS / speed)
	await get_tree().create_timer(LAUNCH_SECONDS * 0.6 / speed).timeout


func _process(delta: float) -> void:
	super._process(delta)
	if teardown_on and mission > 0.0:
		_arena_tick += delta
		if _arena_tick >= 1.0 / 30.0:
			_arena_tick = 0.0
			_arena.queue_redraw()
	if _still_wait > 0:
		_still_wait -= 1
		_still_ready = _still_wait == 0
	# La alarma late y la pantalla de cerca crece: su penumbra se repinta.
	if _alarm > 0.0 or console.visible:
		_dim.queue_redraw()


func _on_footstep(_at: Vector2) -> void:
	if _launching:
		Sfx.play("paso")


## La penumbra del hangar: el modo mision, una pantalla de cerca y la
## alarma de salir a combatir.
func _draw_dim() -> void:
	var levels := Vector3(0.0 if teardown_on else mission, _alarm, console.shown())
	HangarProps.dim(_dim, size, _platform_center(), _floor_y, levels, _time)


# --- El tablero y las pantallas de cerca ---------------------------------------


## Acerca una pantalla de la pared (o el rotulo del robot): crece desde su
## sitio y el hangar se oscurece detras.
func show_console(state: Dictionary, instant: bool = false) -> void:
	var rects := console_rects(str(state.get("kind", "")))
	console.open(state, rects[0], rects[1], instant)


func hide_console() -> void:
	console.close()


## Sitio de una pantalla en la pared y el que ocupa de cerca.
func console_rects(kind: String) -> Array[Rect2]:
	match kind:
		"mejoras":
			return [
				_terminal_rects.get(kind, Rect2()),
				Rect2(size.x * 0.03, size.y * 0.085, size.x * 0.37, size.y * 0.63)
			]
		"habilidades":
			return [
				_terminal_rects.get(kind, Rect2()),
				Rect2(size.x * 0.585, size.y * 0.085, size.x * 0.4, size.y * 0.63)
			]
		"ajustes":
			return [
				_terminal_rects.get(kind, Rect2()),
				Rect2(size.x * 0.575, size.y * 0.012, size.x * 0.415, size.y * 0.56)
			]
	var plate := _sign_rect()
	var wide := maxf(plate.size.x, 300.0)
	return [plate, Rect2(plate.get_center().x - wide * 0.5, plate.end.y + 6.0, wide, 198.0)]


## Acerca la computadora del taller con ese estado (WorkshopBrief.loadout).
func show_loadout(state: Dictionary, instant: bool = false) -> void:
	var rects := loadout_rects()
	loadout.open(state, rects[0], rects[1], instant)


func hide_loadout() -> void:
	loadout.close()


## Abre el estuche de piezas junto a lo elegido del robot desarmado
## ("slot:<hueco>") con ese estado (WorkshopBrief.rack).
func show_case(state: Dictionary, key: String, instant: bool = false) -> void:
	var around := teardown.tray_rect() if teardown.in_tray(key) else Rect2()
	parts_case.open(state, key, teardown.rect_of(key), size, instant, around)


func hide_case() -> void:
	parts_case.close()


## Acerca el banco del especialista con ese estado (SpecialistBrief.state):
## crece desde su sitio en el suelo hasta casi todo el hangar.
func show_specialist(state: Dictionary, instant: bool = false) -> void:
	var to := Rect2(size.x * 0.03, size.y * 0.04, size.x * 0.94, size.y * 0.92)
	specialist.open(state, _terminal_rects.get("especialista", Rect2()), to, instant)


func hide_specialist() -> void:
	specialist.close()


## Sitio de la computadora del taller en la pared y el que ocupa de cerca:
## casi todo el hangar, que queda asomando por los bordes.
func loadout_rects() -> Array[Rect2]:
	return [
		_terminal_rects.get("taller", Rect2()),
		Rect2(size.x * 0.03, size.y * 0.04, size.x * 0.94, size.y * 0.92)
	]


## Enciende el proyector de la bahia vacia que se pulso (o de la primera
## vacia) con lo que se puede adquirir.
func show_offers(state: Dictionary) -> void:
	if _pressed_bay < 0 or _pressed_bay >= bays.size() or int(bays[_pressed_bay]["index"]) >= 0:
		_pressed_bay = -1
		for i in bays.size():
			if _pressed_bay < 0 and int(bays[i]["index"]) < 0:
				_pressed_bay = i
	if _pressed_bay < 0:
		return
	projector.open(state, _bay_rects[_pressed_bay])


func hide_offers() -> void:
	projector.close()


## Lo que ocupa la diana en la pantalla.
func target_rect() -> Rect2:
	var at := _world.position + _target_point() * _world.scale.x
	var reach := TARGET_RADIUS * _world.scale.x
	return Rect2(at - Vector2(reach, reach), Vector2(reach, reach) * 2.0)


func _on_target(at: Vector2) -> bool:
	return can_test and not _mission_on and not teardown_on and target_rect().has_point(at)


## Probar un arma: primero el robot vuelve al perfil. Si salta a la diana
## (un arma cuerpo a cuerpo), su plataforma se queda donde esta.
func test_fire(slot: String, fx: String, color: Color) -> void:
	if not _striking:
		_launch_center = _platform_center()
	await super.test_fire(slot, fx, color)


# --- Colocacion ------------------------------------------------------------------


## El robot que usas, algo a la izquierda del centro y sobre el suelo.
func _fit() -> void:
	if _mech.build == null or size.y <= 0.0:
		return
	_wall_robot.visible = not teardown_on
	_apply_zone()
	# Desarmado no hay diana: el robot no esta entero para probar.
	if teardown_on:
		_target_alpha = 0.0
	teardown.position = Vector2.ZERO
	teardown.size = size
	# En la zona de combate el rival sale de verdad, frente a tu robot.
	_row.ring = teardown_on
	tag.position = Vector2.ZERO
	tag.size = size
	_mech.place(Vector2.ZERO)
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	for slot in TOUCHABLE:
		var rect := _world_rect(slot)
		if rect.size != Vector2.ZERO:
			bounds = bounds.merge(rect)
	_bounds = bounds
	_floor_y = size.y * 0.79
	var height := maxf(-bounds.position.y, 200.0)
	var zoom := minf(1.3, (_floor_y - size.y * 0.13) / height)
	_world.scale = Vector2(zoom, zoom)
	var center := (bounds.position.x + bounds.size.x * 0.35) * zoom
	_world.position = Vector2(size.x * 0.43 - center, _floor_y)
	var legs := _world_rect("legs")
	_platform_width = maxf(legs.size.x, 80.0) * zoom * 1.7
	if teardown_on:
		var stand := teardown.rect_of("slot:legs")
		_platform_width = maxf(stand.size.x, 80.0) + 20.0
	_layout()
	_refresh_still()


## Bahias, terminales y estante, a la medida de la pantalla.
func _layout() -> void:
	_terminal_rects = {
		"taller": Rect2(size.x * 0.025, size.y * 0.085, size.x * 0.135, size.y * 0.2),
		"mejoras": Rect2(size.x * 0.175, size.y * 0.085, size.x * 0.12, size.y * 0.2),
		"habilidades": Rect2(size.x * 0.585, size.y * 0.085, size.x * 0.12, size.y * 0.2),
		"ajustes": Rect2(size.x * 0.944, size.y * 0.012, size.x * 0.046, size.y * 0.05),
		# El banco del especialista, en el suelo, abajo a la izquierda.
		"especialista": Rect2(size.x * 0.02, size.y * 0.78, size.x * 0.17, size.y * 0.2),
	}
	var wall := HangarProps.terminal_art(_terminal_rects["taller"], "taller")
	_wall_robot.position = wall.position
	_wall_robot.size = wall.size
	_board.position = Vector2(size.x * 0.72, size.y * 0.07)
	_board.size = Vector2(size.x * 0.255, size.y * 0.27)
	var under_board := _board.position.y + _board.size.y
	_row.layout(size, _floor_y, _world.scale.x, under_board + 4.0)
	_row.player_feet = Vector2(_robot_center(), _floor_y)
	if loadout.is_open():
		show_loadout(loadout.state)
	if parts_case.is_open():
		var key := parts_case.key
		var around := teardown.tray_rect() if teardown.in_tray(key) else Rect2()
		parts_case.place(teardown.rect_of(key), size, around)
	_bay_rects.clear()
	if teardown_on:
		for terminal: String in ["taller", "mejoras", "habilidades"]:
			_terminal_rects.erase(terminal)
		# La compuerta a la zona de combate y, alli, el rotulo de vuelta.
		var door_top := size.y * 0.3
		_terminal_rects["salida"] = Rect2(
			size.x * 0.93, door_top, size.x * 0.055, _floor_y - door_top
		)
		_terminal_rects["volver"] = Rect2(
			size.x * 0.015, size.y * 0.9, size.x * 0.12, size.y * 0.045
		)
	for i in BAY_X.size():
		var feet := _bay_feet(i)
		var height := _bay_height()
		var wide := 0.36 if teardown_on else 0.84
		_bay_rects.append(
			Rect2(feet.x - height * wide * 0.5, feet.y - height, height * wide, height + 8.0)
		)
	for i in _bay_views.size():
		var view := _bay_views[i]
		var feet := _bay_feet(i)
		var factor := (_bay_height() * 0.84) / maxf(view.standing_height(), 200.0)
		view.place(feet)
		view.set_facing(1)
		view.scale *= factor


func _bay_floor() -> float:
	return size.y * 0.715


## Los pies del robot de una bahia: al fondo del hangar o, en la zona de
## combate, de pie junto al tuyo.
func _bay_feet(i: int) -> Vector2:
	if teardown_on:
		return Vector2(size.x * ZONE_BAY_X[i], _floor_y)
	return Vector2(size.x * BAY_X[i], _bay_floor())


func _bay_height() -> float:
	return size.y * (ZONE_BAY_HEIGHT if teardown_on else 0.3)


## El robot desarmado (hangar) o la zona de combate (modo mision), con la
## opacidad de `mission`.
func _apply_zone() -> void:
	if not teardown_on:
		_world.modulate.a = 1.0
		_mech.visible = true
		_bay_layer.visible = true
		_bay_layer.modulate.a = 1.0
		_board.visible = true
		_board.modulate.a = 1.0
		_arena.visible = false
		teardown.visible = false
		return
	teardown.visible = mission < 1.0
	teardown.modulate.a = 1.0 - mission
	tag.modulate.a = 1.0 - mission
	_mech.visible = mission > 0.0
	_world.modulate.a = mission
	_bay_layer.visible = mission > 0.0
	_bay_layer.modulate.a = mission
	_board.visible = mission > 0.0
	_board.modulate.a = mission
	_arena.visible = mission > 0.0
	_arena.queue_redraw()


## La arena: su fondo, la luz bajo tu robot, lo vivo de las bahias y el
## rotulo de vuelta.
func _draw_arena() -> void:
	ZoneArt.draw(_arena, size, _floor_y, _time, mission)
	var feet := Vector2(_robot_center(), _floor_y)
	var pool := Color(0.75, 0.9, 1.0, 0.1 * mission)
	for i in 3:
		var radius := Vector2(size.x * (0.09 + 0.03 * i), size.y * (0.025 + 0.008 * i))
		var points := PackedVector2Array()
		for k in 24:
			points.append(feet + Vector2.from_angle(TAU * k / 24.0) * radius)
		_arena.draw_colored_polygon(points, pool)
	_draw_bays_live(_arena)
	ZoneArt.fighter_name(_arena, _font, feet, str(info.get("name", "")), mission)
	_row.player_name = str(info.get("name", ""))
	if _terminal_rects.has("volver"):
		var back := _terminal_rects["volver"]
		ZoneArt.back_sign(_arena, _font, back, _hover_terminal == "volver", mission)


## Centro de tu robot armado en la pantalla: bajo sus piernas.
func _robot_center() -> float:
	var legs := _world_rect("legs")
	if legs.size == Vector2.ZERO:
		return _world.position.x
	return _world.position.x + legs.get_center().x * _world.scale.x


## Lo que se puede pulsar de la pared: en la zona, solo volver y los
## ajustes; en el hangar desarmado, todo menos volver.
func _terminal_active(terminal: String) -> bool:
	if not teardown_on:
		return not terminal in ["salida", "volver"]
	if _mission_on:
		return terminal in ["volver", "ajustes"]
	return terminal != "volver"


## Pone los robots de las bahias.
func set_bays(p_bays: Array[Dictionary]) -> void:
	bays = p_bays
	for view in _bay_views:
		view.queue_free()
	_bay_views.clear()
	for bay in bays:
		var view := MechView.new()
		_bay_layer.add_child(view)
		if bay["build"] != null:
			view.setup(bay["build"], 1)
			view.modulate = Color(0.62, 0.68, 0.8)
		else:
			view.visible = false
		_bay_views.append(view)
	_layout()


# --- Dibujo ------------------------------------------------------------------


## Lo que se mueve se pinta cada cuadro; lo quieto (pared, viga, bahias,
## pantallas, suelo, plataforma, cosas del taller y estante) va en una
## textura que se pinta una sola vez (`_still`) y solo se rehace cuando algo
## cambia de sitio o de tamano. Rehacerlo todo cada cuadro dejaba el hangar
## en menos de 40 cuadros por segundo.
func _draw() -> void:
	if _still_ready:
		draw_texture_rect(_still.get_texture(), Rect2(Vector2.ZERO, size), false)
	else:
		# Hasta que la textura esta pintada, lo quieto va directo.
		_draw_still(self)
	if not teardown_on:
		_draw_bays_live(self)
	elif _terminal_rects.has("salida") and not _mission_on:
		var door := _terminal_rects["salida"]
		ZoneArt.hangar_door(self, _font, door, _hover_terminal == "salida", _time)
	for terminal in TERMINALS:
		if _terminal_rects.has(terminal):
			var hover := _hover_terminal == terminal
			var rect := _terminal_rects[terminal]
			var robot := terminal == "taller" and _wall_robot.has_robot()
			HangarProps.terminal_live(self, _font, terminal, rect, hover, info, _time, robot)
	var center := _platform_center()
	HangarArt.draw_light_dust(self, Rect2(Vector2.ZERO, size), center, _floor_y, _time)
	if str(info.get("name", "")) != "":
		HangarProps.bay_sign(
			self,
			_font,
			_sign_rect(),
			str(info["name"]),
			str(info.get("problems", "")),
			_hover_sign,
			_time
		)
	if _mech.build != null and info.has("weight"):
		var top := int(info.get("max_weight", 1000))
		HangarProps.scale(
			self,
			_font,
			_scale_rect(),
			_floor_y,
			int(info["weight"]),
			top,
			top + int(info.get("overload", 0)),
			_time,
			int(info.get("weight_delta", 0))
		)


## Lo quieto del hangar, sobre `c`: la textura o, mientras no esta, el
## propio escenario.
func _draw_still(c: CanvasItem) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	HangarArt.draw_wall(c, rect, _floor_y, 1.0)
	HangarArt.draw_gantry(c, rect, 1.0)
	if not teardown_on:
		HangarProps.back_row(c, size, _bay_floor(), BAY_X, _font)
	for terminal in TERMINALS:
		if _terminal_rects.has(terminal):
			HangarProps.terminal_still(c, _font, terminal, _terminal_rects[terminal])
	var board := Rect2(_board.position, _board.size)
	if not teardown_on:
		HangarProps.cable(c, Vector2(board.position.x + board.size.x * 0.8, board.end.y))
	var center := _platform_center()
	HangarArt.draw_floor(c, rect, _floor_y, Vector2(center, _floor_y - size.y * 0.9))
	HangarProps.floor_marks(c, size, _floor_y, center, _font)
	HangarArt.draw_light_cone(c, rect, center, _floor_y)
	if _mech.build != null and not teardown_on:
		HangarArt.draw_platform(c, Vector2(center, _floor_y), _platform_width)
	HangarProps.clutter(c, size, _floor_y)
	if not teardown_on:
		var target := _world.position + _target_point() * _world.scale.x
		HangarProps.target_stand(c, target, _floor_y)
	HangarArt.draw_vignette(c, rect, 1.2)


## Rehace la textura de lo quieto si cambio algo de lo que pinta: el tamano
## del hangar o de la ventana, el suelo o la plataforma del robot.
func _refresh_still() -> void:
	if not is_inside_tree() or size.x < 1.0 or size.y < 1.0:
		return
	var pixels := get_viewport().get_final_transform().get_scale().x
	var key := (
		"%s %.3f %.1f %.1f %.1f %s"
		% [
			size,
			pixels,
			_floor_y,
			_platform_center(),
			_platform_width,
			"%s %s" % [_mech.build != null, teardown_on],
		]
	)
	if key == _still_key:
		return
	_still_key = key
	_still_ready = false
	# A los pixeles de la ventana, para que no salga borroso al estirarlo.
	_still.size = Vector2i((size * pixels).ceil())
	_still.size_2d_override = Vector2i(size.ceil())
	_still.size_2d_override_stretch = true
	_still_art.queue_redraw()
	_still.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Se pinta en el siguiente cuadro: hasta entonces lo quieto va directo.
	_still_wait = 2


## El rotulo de la bahia de tu robot, colgado de la viga sobre el.
func _sign_rect() -> Rect2:
	var label := str(info.get("name", "")).to_upper()
	var wide := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var width := clampf(wide + 86.0, 190.0, size.x * 0.27)
	return Rect2(_platform_center() - width * 0.5, 30.0, width, 30.0)


## La pantalla de la bascula: en un poste, a la izquierda de la plataforma.
func _scale_rect() -> Rect2:
	var left := _platform_center() - _platform_width * 0.5
	return Rect2(left - 96.0, _floor_y - 78.0, 88.0, 42.0)


## Centro de la plataforma del robot, en la pantalla: bajo sus piernas.
func _platform_center() -> float:
	if _launching or _striking:
		return _launch_center
	if teardown_on and not _mission_on:
		return size.x * 0.5
	var legs := _world_rect("legs")
	if legs.size == Vector2.ZERO:
		return _world.position.x
	return _world.position.x + legs.get_center().x * _world.scale.x


## Lo que se mueve en las bahias: su lamparita (verde con robot, ambar
## vacia), el marco al pasar el raton y el holograma de las vacias.
func _draw_bays_live(c: CanvasItem) -> void:
	for i in BAY_X.size():
		var feet := _bay_feet(i)
		var x := feet.x
		var y := feet.y
		var w := _bay_height() * (0.3 if teardown_on else 0.66)
		var top := y - _bay_height() * 1.2
		var hover := _hover_bay == i
		var mine := i < bays.size() and int(bays[i]["index"]) >= 0
		var full := mine and bays[i]["build"] != null
		var led := Color("55ff9a") if full else Color("ffb347")
		c.draw_circle(
			Vector2(x + w - 12.0, top + 6.0), 3.0, Color(led, 0.35 + 0.25 * sin(_time * 3.0 + i))
		)
		c.draw_circle(Vector2(x + w - 12.0, top + 6.0), 1.6, led)
		if hover:
			c.draw_rect(Rect2(x - w, top, w * 2.0, y - top), Color(COLOR_SOCKET, 0.06))
			c.draw_rect(Rect2(x - w, top, w * 2.0, y - top), Color(COLOR_SOCKET, 0.5), false, 1.5)
		if not full and not (projector.visible and i == _pressed_bay):
			# Vacia: para adquirir; con un armazon vacio: su nombre.
			var label := (
				str(bays[i]["name"]) if mine and i < bays.size() else Txt.t("robots_acquire")
			)
			HangarProps.hologram(c, Vector2(x, y), size.y * 0.24, hover, label, _time, _font)


func _draw_overlay() -> void:
	super._draw_overlay()
	if _mech.build == null or _mission_on or teardown_on:
		return
	if can_test:
		# La diana llama: un aro que late y, debajo, que hace.
		var target := _target_point()
		var beat := 0.5 + 0.5 * sin(_time * 4.0)
		var glow := 1.0 if _hover_target else 0.45
		_overlay.draw_arc(
			target,
			40.0 + 4.0 * beat,
			0,
			TAU,
			32,
			Color(COLOR_SELECTED, glow * (0.9 - 0.5 * beat)),
			2.0
		)
		_overlay.draw_string(
			_font,
			target + Vector2(-60, 58),
			Txt.t("target_test"),
			HORIZONTAL_ALIGNMENT_CENTER,
			120.0,
			13,
			Color(COLOR_SELECTED, 0.55 + 0.45 * glow)
		)


## La diana del campo de pruebas: a la derecha del robot, sobre su poste.
func _target_point() -> Vector2:
	return Vector2((size.x * 0.655 - _world.position.x) / _world.scale.x, -180.0)


func _text(
	at: Vector2, text: String, width: float, font_size: int, color: Color, centered := false
) -> void:
	HangarProps.text(self, _font, at, text, width, font_size, color, centered)


# --- Raton -------------------------------------------------------------------


## El raton salio del hangar (o paso al tablero, a una cuna o a una pantalla
## de cerca): nada queda encendido.
func _clear_hover() -> void:
	_hover_terminal = ""
	_hover_bay = -2
	_hover_sign = false
	_hover_target = false
	_hover_robot = false
	_row.hover = false
	teardown.hover = ""
	_overlay.queue_redraw()


func _on_sign(at: Vector2) -> bool:
	return str(info.get("name", "")) != "" and _sign_rect().has_point(at)


func _terminal_at(at: Vector2) -> String:
	for terminal: String in _terminal_rects:
		if _terminal_active(terminal) and _terminal_rects[terminal].has_point(at):
			return terminal
	return ""


func _bay_at(at: Vector2) -> int:
	# Desarmado (OBS-048), tus otros robots solo estan en la zona de combate:
	# en el hangar sus sitios caen sobre el brazo izquierdo y la bandeja, y
	# pulsarlos cambiaba de robot sin verlos.
	if teardown_on and not _mission_on:
		return -2
	for i in _bay_rects.size():
		if _bay_rects[i].has_point(at):
			return i
	return -2


## True si ese punto cae sobre el robot (lo que ocupa de perfil).
func _over_robot(at: Vector2) -> bool:
	if _mech.build == null or teardown_on:
		return false
	var body := Rect2(
		_world.position + _bounds.position * _world.scale.x, _bounds.size * _world.scale.x
	)
	return body.grow(12.0).has_point(at)


func _gui_input(event: InputEvent) -> void:
	if _launching:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var on_rival := _mission_on and _row.front_has_point(motion.position)
		_row.hover = on_rival
		var on_sign := not on_rival and _on_sign(motion.position)
		if on_sign != _hover_sign:
			_hover_sign = on_sign
			if on_sign:
				Sfx.play("ui_tic")
		var on_target := not on_rival and not on_sign and _on_target(motion.position)
		if on_target != _hover_target:
			_hover_target = on_target
			_overlay.queue_redraw()
			if on_target:
				Sfx.play("ui_tic")
		var terminal := "" if on_rival or on_sign else _terminal_at(motion.position)
		var bay := _bay_at(motion.position) if terminal == "" and not on_rival else -2
		if terminal != _hover_terminal or bay != _hover_bay:
			_hover_terminal = terminal
			_hover_bay = bay
			if terminal != "" or bay >= 0:
				Sfx.play("ui_tic")
		var free := terminal == "" and bay < 0 and not on_rival and not on_sign and not on_target
		_hover_robot = free and _over_robot(motion.position)
		var tag_key := tag.key_at(motion.position) if free else ""
		if tag_key != tag.hover_key:
			tag.hover_key = tag_key
			tag.queue_redraw()
			if tag_key != "":
				Sfx.play("ui_tic")
		free = free and not tag.has_point(motion.position)
		var desk := free and teardown_on and not _mission_on
		var piece := teardown.item_at(motion.position) if desk else ""
		if piece != teardown.hover:
			teardown.hover = piece
			teardown.queue_redraw()
			if piece != "":
				Sfx.play("ui_tic")
		var pointing := terminal != "" or bay >= 0 or on_rival or on_sign or on_target
		pointing = pointing or piece != "" or tag_key != ""
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if pointing or _hover_robot else Control.CURSOR_ARROW
		)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if _mission_on and _row.front_has_point(click.position):
			rival_pressed.emit()
			return
		if _on_sign(click.position):
			sign_pressed.emit()
			return
		if _on_target(click.position):
			target_pressed.emit()
			return
		var terminal := _terminal_at(click.position)
		if terminal == "salida":
			missions_pressed.emit()
			return
		if terminal == "volver":
			background_pressed.emit()
			return
		if terminal != "":
			terminal_pressed.emit(terminal)
			return
		var bay := _bay_at(click.position)
		if bay >= 0 and bay < bays.size():
			_pressed_bay = bay
			bay_pressed.emit(int(bays[bay]["index"]))
			return
		var tag_key := tag.key_at(click.position)
		if tag_key != "":
			tag_pressed.emit(tag_key)
			return
		if tag.has_point(click.position):
			return
		var desk := teardown_on and not _mission_on
		var piece := teardown.item_at(click.position) if desk else ""
		if piece != "":
			teardown_picked.emit(piece)
			return
		# Tu robot: se acerca la computadora del taller.
		if _over_robot(click.position):
			robot_pressed.emit()
			return
		background_pressed.emit()
