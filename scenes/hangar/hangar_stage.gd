class_name HangarStage
extends MechStage
## El hangar entero, como pantalla de inicio (pedido del usuario el
## 2026-11-18: "la menor cantidad de botones, todo integrado como vista de
## taller, inmersivo y con muchos detalles"). Sobre el escenario del taller
## (MechStage) anade:
## - tus otros robots en tres bahias al fondo, mas pequenos y en penumbra
##   (un clic y pasas a usarlo; una bahia vacia es para adquirir uno);
## - tres pantallas en la pared: la de la tienda saca el tablero de piezas
##   y las de mejoras y habilidades se usan ahi mismo, de cerca (WallConsole);
##   en la esquina, el cuadro de control de los ajustes, que se usa igual;
## - el tablero de piezas (PartsRack): al elegir un hueco entra rodando a la
##   derecha con las piezas que caben en el, las tuyas y las de la tienda, y
##   la lectura del robot; la diana prueba el arma del hueco;
## - el monitor de misiones (MissionBoard): el cuadro de campana. Al pulsarlo
##   el hangar pasa al modo mision: se queda en penumbra y los rivales se
##   proyectan en el suelo delante de tu robot (RivalRow); pulsar al primero
##   es salir a combatir;
## - enchufes que brillan en los huecos de arma vacios del robot;
## - lo que antes iba en una barra de arriba, repartido por la escena: el
##   nombre de tu robot en el rotulo que cuelga sobre su bahia (se pulsa para
##   ver su ficha), sus celdas en la pantalla de la tienda, su nivel en la de
##   habilidades, sus mejoras en la de mejoras y su peso en la bascula que
##   hay junto a la plataforma;
## - la plataforma del robot es giratoria: arrastrarla (o la rueda del raton)
##   lo gira 360 grados (TurntableMech); doble clic lo devuelve al perfil;
## - un banco de equipo con los huecos que no se ven en el dibujo (pecho,
##   especiales, asistente y modulos): cunas con su pieza dentro (SlotCell).
## Pulsar el hangar vacio recoge lo que este abierto.

signal terminal_pressed(terminal: String)
## El monitor de misiones, con el modo mision apagado.
signal missions_pressed
## El primero de la fila de rivales: salir a combatir.
signal rival_pressed
signal channel_picked(channel: String)
signal pick_changed(key: String, step: int)
## El rotulo de la bahia: la ficha de tu robot.
signal sign_pressed
## La diana, con un arma que se puede probar en el hueco elegido.
signal target_pressed
signal bay_pressed(index: int)
signal background_pressed
signal dropped_on(slot: String, data: Dictionary)

## Lo que hay en la pared y se pulsa: tres pantallas y el cuadro de control
## de los ajustes.
const TERMINALS: Array[String] = ["tienda", "mejoras", "habilidades", "ajustes"]
## Huecos del estante: arriba lo especial, abajo los modulos.
const RACK_TOP: Array[String] = [
	"chest", "charge", "teleport", "hook", "assist", "drone", "drone_low"
]
const RACK_BOTTOM: Array[String] = [
	"module0", "module1", "module2", "module3", "module4", "module5", "module6", "module7"
]
## Centro de cada bahia, como parte del ancho. Las dos de la izquierda van
## separadas para que el arma de un robot no tape al de al lado.
const BAY_X: Array[float] = [0.085, 0.225, 0.815]
const COLOR_SCREEN := Color("0b2a33")
const COLOR_SCREEN_LINE := Color("3fd0e6")
const COLOR_TEXT := Color("bfefff")
const COLOR_SOCKET := Color("57d3ff")
const SOCKET_RADIUS := 13.0
## Giro por pixel arrastrado, por muesca de la rueda, y a cuanto de una
## vista dibujada (de perfil, de espalda, del otro perfil o de frente) el
## robot se coloca solo en ella al soltar.
const TURN_PER_PIXEL := TAU / 620.0
const TURN_PER_NOTCH := TAU / 16.0
const TURN_SNAP := deg_to_rad(9.0)
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
## El tablero de piezas y la pantalla de cerca: WorkshopScreen les da lo que
## ensenan y oye lo que se pulsa en ellos.
var parts_rack := PartsRack.new()
var console := WallConsole.new()
## El proyector de la bahia vacia que se pulso: lo que se puede adquirir.
var projector := BayProjector.new()
## El hueco elegido lleva un arma que se puede probar: la diana se enciende.
var can_test := false:
	set(value):
		can_test = value
		_overlay.queue_redraw()

## Cuanto esta el hangar en modo mision: 0 = el taller, 1 = en penumbra con
## los rivales delante.
var mission := 0.0:
	set(value):
		mission = value
		_target_alpha = 1.0 - value
		_board.open = value
		for cell: SlotCell in rack.values():
			cell.modulate = Color.WHITE.lerp(Color(0.3, 0.36, 0.46), value)
		_dim.queue_redraw()
		_overlay.queue_redraw()
## Robots de las bahias: [{"index", "build", "name"}]; uno con "index" -1 es
## una bahia vacia.
var bays: Array[Dictionary] = []
## Celdas del estante, por hueco (las crea WorkshopScreen).
var rack: Dictionary[String, SlotCell] = {}
## Giro del robot sobre su plataforma, en radianes: 0 = de perfil, como en
## combate. Girado no se tocan sus piezas (se le da la vuelta para verlo).
var turn: float = 0.0:
	set(value):
		turn = wrapf(value, 0.0, TAU)
		_apply_turn()

var _bay_layer := Node2D.new()
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
var _turntable := TurntableMech.new()
## Lo que ocupa el robot en el taller (para las capas del giro).
var _bounds := Rect2()
var _turning := false
var _hover_platform := false
var _turn_tween: Tween
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
	add_child(projector)
	add_child(parts_rack)
	add_child(console)
	mouse_exited.connect(_clear_hover)
	_mech.footstep.connect(_on_footstep)
	_world.add_child(_turntable)
	_world.move_child(_turntable, _mech.get_index() + 1)
	_turntable.set_active(false)
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
	hover_slot = ""
	selected_slot = ""
	_row.hover = false
	if is_turned():
		await turn_to(0.0, 0.2)
	Sfx.play("despliegue")
	_row.collapse(0.25 / speed)
	create_tween().tween_property(self, "_alarm", 1.0, 0.2 / speed)
	_mech.move_to(_mech.position + Vector2(LAUNCH_WALK, 0.0), LAUNCH_SECONDS / speed)
	await get_tree().create_timer(LAUNCH_SECONDS * 0.6 / speed).timeout


func _process(delta: float) -> void:
	super._process(delta)
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
	var levels := Vector3(mission, _alarm, console.shown())
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
	return [plate, Rect2(plate.get_center().x - wide * 0.5, plate.end.y + 6.0, wide, 170.0)]


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
	return can_test and not _mission_on and not is_turned() and target_rect().has_point(at)


## Ensena el robot girado (con sus capas) o el de siempre si esta de perfil.
func _apply_turn() -> void:
	var turned := is_turned() and _mech.build != null
	_mech.visible = not turned
	_turntable.angle = turn
	_turntable.set_active(turned)
	if turned and (hover_slot != "" or selected_slot != ""):
		hover_slot = ""
	_overlay.queue_redraw()
	queue_redraw()


func is_turned() -> bool:
	return not (is_zero_approx(turn) or is_equal_approx(turn, TAU))


## Gira el robot hasta ese angulo con un movimiento suave, por el camino corto.
func turn_to(target: float, seconds: float = 0.3) -> void:
	if _turn_tween != null:
		_turn_tween.kill()
	var from := turn
	var delta := wrapf(target - from, -PI, PI)
	_turn_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_turn_tween.tween_method(func(t: float) -> void: turn = from + delta * t, 0.0, 1.0, seconds)
	await _turn_tween.finished


## Probar un arma: primero el robot vuelve al perfil.
func test_fire(slot: String, fx: String, color: Color) -> void:
	if is_turned():
		await turn_to(0.0)
	await super.test_fire(slot, fx, color)


# --- Colocacion ------------------------------------------------------------------


## El robot que usas, algo a la izquierda del centro y sobre el suelo.
func _fit() -> void:
	if _mech.build == null or size.y <= 0.0:
		return
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
	_layout()
	# Las capas del giro se arman con el mismo equipo y a la misma medida.
	var pivot := legs.get_center().x if legs.size != Vector2.ZERO else 0.0
	var deployed := _mech.build.chest != null
	_turntable.setup(_mech.build, _mech.ghost_slots, bounds, pivot, deployed)
	_apply_turn()
	_refresh_still()


## Bahias, terminales y estante, a la medida de la pantalla.
func _layout() -> void:
	_terminal_rects = {
		"tienda": Rect2(size.x * 0.025, size.y * 0.085, size.x * 0.135, size.y * 0.2),
		"mejoras": Rect2(size.x * 0.175, size.y * 0.085, size.x * 0.12, size.y * 0.2),
		"habilidades": Rect2(size.x * 0.585, size.y * 0.085, size.x * 0.12, size.y * 0.2),
		"ajustes": Rect2(size.x * 0.944, size.y * 0.012, size.x * 0.046, size.y * 0.05),
	}
	_board.position = Vector2(size.x * 0.72, size.y * 0.07)
	_board.size = Vector2(size.x * 0.255, size.y * 0.27)
	var under_board := _board.position.y + _board.size.y
	_row.layout(size, _floor_y, _world.scale.x, under_board + 4.0)
	parts_rack.home = Rect2(
		size.x * 0.692, under_board + 10.0, size.x * 0.3, size.y - under_board - 20.0
	)
	_bay_rects.clear()
	for i in BAY_X.size():
		var feet := Vector2(size.x * BAY_X[i], _bay_floor())
		var height := size.y * 0.3
		_bay_rects.append(
			Rect2(feet.x - height * 0.42, feet.y - height, height * 0.84, height + 8.0)
		)
	for i in _bay_views.size():
		var view := _bay_views[i]
		var feet := Vector2(size.x * BAY_X[i], _bay_floor())
		var factor := (size.y * 0.25) / maxf(view.standing_height(), 200.0)
		view.place(feet)
		view.set_facing(1)
		view.scale *= factor
	# El banco: dos filas de cunas bajo el robot.
	var shelf := _shelf_rect()
	var row_h := (shelf.size.y - 14.0) / 2.0
	for row in 2:
		var slots: Array[String] = RACK_TOP if row == 0 else RACK_BOTTOM
		var w := (shelf.size.x - 16.0) / RACK_BOTTOM.size()
		for i in slots.size():
			if not rack.has(slots[i]):
				continue
			var cell := rack[slots[i]]
			cell.position = shelf.position + Vector2(8.0 + i * w, 6.0 + row * (row_h + 2.0))
			cell.size = Vector2(w - 4.0, row_h)


func _bay_floor() -> float:
	return size.y * 0.715


func _shelf_rect() -> Rect2:
	return Rect2(size.x * 0.02, size.y * 0.835, size.x * 0.6, size.y * 0.155)


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
	_draw_bays_live()
	for terminal in TERMINALS:
		if _terminal_rects.has(terminal):
			_draw_terminal_live(terminal, _terminal_rects[terminal])
	var center := _platform_center()
	HangarArt.draw_light_dust(self, Rect2(Vector2.ZERO, size), center, _floor_y, _time)
	if _mech.build != null:
		var live := _hover_platform or _turning
		HangarProps.turn_marks(self, Vector2(center, _floor_y), _platform_width, turn, live)
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
	HangarProps.back_row(c, size, _bay_floor(), BAY_X, _font)
	for terminal in TERMINALS:
		if _terminal_rects.has(terminal):
			_draw_terminal_still(c, terminal, _terminal_rects[terminal])
	var board := Rect2(_board.position, _board.size)
	_draw_cable(c, Vector2(board.position.x + board.size.x * 0.8, board.end.y))
	var center := _platform_center()
	HangarArt.draw_floor(c, rect, _floor_y, Vector2(center, _floor_y - size.y * 0.9))
	HangarProps.floor_marks(c, size, _floor_y, center, _font)
	HangarArt.draw_light_cone(c, rect, center, _floor_y)
	if _mech.build != null:
		HangarArt.draw_platform(c, Vector2(center, _floor_y), _platform_width)
	HangarProps.clutter(c, size, _floor_y)
	HangarProps.target_stand(c, _world.position + _target_point() * _world.scale.x, _floor_y)
	_draw_shelf(c)
	HangarArt.draw_vignette(c, rect, 1.2)


## Rehace la textura de lo quieto si cambio algo de lo que pinta: el tamano
## del hangar o de la ventana, el suelo o la plataforma del robot.
func _refresh_still() -> void:
	if not is_inside_tree() or size.x < 1.0 or size.y < 1.0:
		return
	var pixels := get_viewport().get_final_transform().get_scale().x
	var key := (
		"%s %.3f %.1f %.1f %.1f %s"
		% [size, pixels, _floor_y, _platform_center(), _platform_width, _mech.build != null]
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
	if _launching:
		return _launch_center
	var legs := _world_rect("legs")
	if legs.size == Vector2.ZERO:
		return _world.position.x
	return _world.position.x + legs.get_center().x * _world.scale.x


## Lo que se mueve en las bahias: su lamparita (verde con robot, ambar
## vacia), el marco al pasar el raton y el holograma de las vacias.
func _draw_bays_live() -> void:
	var y := _bay_floor()
	for i in BAY_X.size():
		var x := size.x * BAY_X[i]
		var w := size.y * 0.2
		var top := y - size.y * 0.36
		var hover := _hover_bay == i
		var mine := i < bays.size() and int(bays[i]["index"]) >= 0
		var full := mine and bays[i]["build"] != null
		var led := Color("55ff9a") if full else Color("ffb347")
		draw_circle(
			Vector2(x + w - 12.0, top + 6.0), 3.0, Color(led, 0.35 + 0.25 * sin(_time * 3.0 + i))
		)
		draw_circle(Vector2(x + w - 12.0, top + 6.0), 1.6, led)
		if hover:
			draw_rect(Rect2(x - w, top, w * 2.0, y - top), Color(COLOR_SOCKET, 0.06))
			draw_rect(Rect2(x - w, top, w * 2.0, y - top), Color(COLOR_SOCKET, 0.5), false, 1.5)
		if not full and not (projector.visible and i == _pressed_bay):
			# Vacia: para adquirir; con un armazon vacio: su nombre.
			var label := (
				str(bays[i]["name"]) if mine and i < bays.size() else Txt.t("robots_acquire")
			)
			HangarProps.hologram(self, Vector2(x, y), size.y * 0.24, hover, label, _time, _font)


## Una terminal de pared, lo quieto: marco con relieve, cristal con sus
## lineas de barrido, su nombre y el cable que baja a la pared.
func _draw_terminal_still(c: CanvasItem, terminal: String, rect: Rect2) -> void:
	if terminal == "ajustes":
		HangarProps.control_box(c, rect)
		return
	var screen := HangarArt.draw_screen_still(c, rect)
	HangarProps.text(
		c,
		_font,
		screen.position + Vector2(8, 15),
		Txt.t("terminal_" + terminal),
		screen.size.x - 16.0,
		13,
		COLOR_TEXT
	)
	_draw_cable(c, Vector2(rect.position.x + rect.size.x * 0.8, rect.end.y))


## Y lo que se mueve: la franja de luz, su dibujo, el led y el brillo al
## pasar el raton.
func _draw_terminal_live(terminal: String, rect: Rect2) -> void:
	if terminal == "ajustes":
		HangarProps.control_box_live(self, _font, rect, _hover_terminal == terminal, _time)
		return
	var screen := HangarArt.draw_screen_live(self, rect, _hover_terminal == terminal, _time)
	var art := Rect2(screen.position + Vector2(8, 22), screen.size - Vector2(16, 30))
	var foot := Vector2(screen.position.x + 8.0, screen.end.y - 8.0)
	var wide := screen.size.x - 16.0
	match terminal:
		"tienda":
			# Abajo, tus celdas.
			art.size.y -= 16.0
			HangarProps.store_art(self, art)
			HangarProps.cells_line(self, _font, foot, wide, int(info.get("cells", 0)))
		"mejoras":
			HangarProps.upgrades_art(self, art, info.get("upgrades", []), _time)
		"habilidades":
			# Abajo, tu nivel y lo que llevas del siguiente.
			art.size.y -= 16.0
			HangarProps.skills_art(self, art)
			HangarProps.level_line(
				self,
				_font,
				foot,
				wide,
				int(info.get("level", 1)),
				int(info.get("xp", 0)),
				int(info.get("xp_next", -1))
			)
	var led_at := Vector2(rect.end.x - 14.0, rect.position.y + 6.0)
	draw_circle(led_at, 2.4, Color("55ff9a", 0.4 + 0.4 * sin(_time * 4.0 + rect.position.x)))


## Cable que baja de una pantalla a la pared.
func _draw_cable(c: CanvasItem, from: Vector2) -> void:
	c.draw_line(from, from + Vector2(6.0, 28.0), Color("0e141c"), 3.0)


## Estante de equipo: una placa con su rotulo; los huecos van encima.
func _draw_shelf(c: CanvasItem) -> void:
	var shelf := _shelf_rect()
	var style := TechStyle.plate(Color("161e2a"), Color("3c4c62"), 0.0, 8.0)
	style.groove = false
	style.draw(c.get_canvas_item(), shelf)
	HangarProps.text(
		c,
		_font,
		shelf.position + Vector2(10, -4),
		Txt.t("rack_title"),
		shelf.size.x,
		11,
		Color("9aa7b8")
	)


func _draw_overlay() -> void:
	super._draw_overlay()
	if _mech.build == null or is_turned() or _mission_on:
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
	# Enchufes de los huecos de arma vacios: un anillo que late.
	for slot: String in ["side0", "side1", "side2", "side3", "top0", "top1"]:
		if _item_in(slot) != null:
			continue
		var at := socket_point(slot)
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		var selected := slot == selected_slot
		var color := COLOR_SELECTED if selected else COLOR_SOCKET
		var radius := SOCKET_RADIUS / _world.scale.x
		_overlay.draw_circle(at, radius * (1.2 + 0.4 * pulse), Color(color, 0.12 + 0.1 * pulse))
		_overlay.draw_arc(at, radius, 0, TAU, 20, Color(color, 0.85), 2.0 / _world.scale.x)
		_overlay.draw_circle(at, radius * 0.35, Color(color, 0.9))


## La diana del campo de pruebas: a la derecha del robot, sobre su poste.
func _target_point() -> Vector2:
	return Vector2((size.x * 0.655 - _world.position.x) / _world.scale.x, -180.0)


## Punto del enchufe de un hueco de arma, en el mundo del taller.
func socket_point(slot: String) -> Vector2:
	return _mech.transform * _mech.slot_socket(slot)


## Punto de la pantalla donde esta un hueco (su pieza o su enchufe).
func slot_screen_point(slot: String) -> Vector2:
	var world := socket_point(slot) if _item_in(slot) == null else _world_rect(slot).get_center()
	return get_global_rect().position + _world.position + world * _world.scale.x


func _text(
	at: Vector2, text: String, width: float, font_size: int, color: Color, centered := false
) -> void:
	HangarProps.text(self, _font, at, text, width, font_size, color, centered)


# --- Raton -------------------------------------------------------------------


## Hueco bajo un punto: una pieza del robot o el enchufe de un hueco vacio.
func slot_at(at: Vector2) -> String:
	# Girado no se tocan las piezas: se le da la vuelta para verlo.
	if is_turned():
		return ""
	var slot := super.slot_at(at)
	if slot != "" or _mech.build == null:
		return slot
	var world := (at - _world.position) / _world.scale.x
	for socket: String in ["side0", "side1", "side2", "side3", "top0", "top1"]:
		if _item_in(socket) == null:
			var radius := SOCKET_RADIUS * 1.6 / _world.scale.x
			if world.distance_to(socket_point(socket)) <= radius:
				return socket
	return ""


## El raton salio del hangar (o paso al tablero, a una cuna o a una pantalla
## de cerca): nada queda encendido.
func _clear_hover() -> void:
	_hover_terminal = ""
	_hover_bay = -2
	_hover_sign = false
	_hover_target = false
	_hover_platform = false
	_row.hover = false
	if hover_slot != "":
		hover_slot = ""
	_overlay.queue_redraw()


func _on_sign(at: Vector2) -> bool:
	return str(info.get("name", "")) != "" and _sign_rect().has_point(at)


func _terminal_at(at: Vector2) -> String:
	for terminal: String in _terminal_rects:
		if _terminal_rects[terminal].has_point(at):
			return terminal
	return ""


func _bay_at(at: Vector2) -> int:
	for i in _bay_rects.size():
		if _bay_rects[i].has_point(at):
			return i
	return -2


## True si ese punto agarra la plataforma giratoria: la plataforma y, con el
## robot ya girado, tambien el robot.
func _grabs_platform(at: Vector2) -> bool:
	if _mech.build == null:
		return false
	var legs := _world_rect("legs")
	var feet := Vector2(_world.position.x + legs.get_center().x * _world.scale.x, _floor_y)
	var rx := _platform_width * 0.5
	var ry := maxf(_platform_width * 0.09, 4.0) * 1.5
	var on_platform := (
		Vector2((at.x - feet.x) / rx, (at.y - feet.y - ry * 0.25) / ry).length() <= 1.0
	)
	if is_turned():
		var body := Rect2(
			_world.position + _bounds.position * _world.scale.x, _bounds.size * _world.scale.x
		)
		return on_platform or body.has_point(at)
	return on_platform and slot_at(at) == ""


func _gui_input(event: InputEvent) -> void:
	if _launching:
		return
	var button := event as InputEventMouseButton
	if button != null and _turn_input(button):
		return
	var dragged := event as InputEventMouseMotion
	if dragged != null and _turning:
		turn += dragged.relative.x * TURN_PER_PIXEL
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
		var platform := terminal == "" and bay < 0 and _grabs_platform(motion.position)
		if platform != _hover_platform:
			_hover_platform = platform
			queue_redraw()
		mouse_default_cursor_shape = (
			Control.CURSOR_HSIZE
			if platform
			else (
				Control.CURSOR_POINTING_HAND
				if (
					terminal != ""
					or bay >= 0
					or on_rival
					or on_sign
					or on_target
					or slot_at(motion.position) != ""
				)
				else Control.CURSOR_ARROW
			)
		)
		super._gui_input(event)
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
		if terminal != "":
			terminal_pressed.emit(terminal)
			return
		var bay := _bay_at(click.position)
		if bay >= 0 and bay < bays.size():
			_pressed_bay = bay
			bay_pressed.emit(int(bays[bay]["index"]))
			return
		if slot_at(click.position) == "":
			background_pressed.emit()
			return
	super._gui_input(event)


## El raton sobre la plataforma giratoria: arrastrar gira, la rueda gira a
## saltos y doble clic devuelve el robot al perfil. True si el gesto era suyo.
func _turn_input(button: InputEventMouseButton) -> bool:
	if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed and _turning:
		_turning = false
		queue_redraw()
		# Casi en una vista dibujada: se coloca en ella (de perfil, ademas,
		# se pueden tocar sus piezas).
		var quarter := snappedf(turn, PI / 2.0)
		if absf(wrapf(turn - quarter, -PI, PI)) < TURN_SNAP:
			turn_to(quarter, 0.18)
		return true
	if not button.pressed or not _grabs_platform(button.position):
		return false
	if _terminal_at(button.position) != "" or _bay_at(button.position) >= 0:
		return false
	match button.button_index:
		MOUSE_BUTTON_LEFT:
			if button.double_click:
				turn_to(0.0)
			else:
				if _turn_tween != null:
					_turn_tween.kill()
				_turning = true
				queue_redraw()
			return true
		MOUSE_BUTTON_WHEEL_UP:
			turn_to(turn + TURN_PER_NOTCH, 0.16)
			return true
		MOUSE_BUTTON_WHEEL_DOWN:
			turn_to(turn - TURN_PER_NOTCH, 0.16)
			return true
	return false


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("id"):
		return false
	var slot := slot_at(at)
	if slot != "" and Garage.slot_type(slot) == int(data.get("type", -1)):
		return data.get("from_slot", "") != slot
	return not data.has("from_slot")


func _drop_data(at: Vector2, data: Variant) -> void:
	var slot := slot_at(at)
	if slot != "" and Garage.slot_type(slot) == int(data.get("type", -1)):
		dropped_on.emit(slot, data)
	else:
		dropped.emit(data)
