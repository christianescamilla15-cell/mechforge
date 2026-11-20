class_name HangarStage
extends MechStage
## El hangar entero, como pantalla de inicio (pedido del usuario el
## 2026-11-18: "la menor cantidad de botones, todo integrado como vista de
## taller, inmersivo y con muchos detalles"). Sobre el escenario del taller
## (MechStage) anade:
## - tus otros robots en tres bahias al fondo, mas pequenos y en penumbra
##   (un clic y pasas a usarlo; una bahia vacia es para adquirir uno);
## - tres terminales en la pared (tienda, mejoras y habilidades) que se
##   iluminan al pasar y abren su panel;
## - el monitor de misiones (MissionBoard): el cuadro de campana. Al pulsarlo
##   el hangar pasa al modo mision: se queda en penumbra y los rivales se
##   proyectan en el suelo delante de tu robot (RivalRow); pulsar al primero
##   es salir a combatir;
## - enchufes que brillan en los huecos de arma vacios del robot;
## - la plataforma del robot es giratoria: arrastrarla (o la rueda del raton)
##   lo gira 360 grados (TurntableMech); doble clic lo devuelve al perfil;
## - un estante de equipo con los huecos que no se ven en el dibujo (pecho,
##   especiales, asistente y modulos), con huecos de verdad (SlotCell).
## Pulsar el hangar vacio cierra el panel abierto.

signal terminal_pressed(terminal: String)
## El monitor de misiones, con el modo mision apagado.
signal missions_pressed
## El primero de la fila de rivales: salir a combatir.
signal rival_pressed
signal channel_picked(channel: String)
signal pick_changed(key: String, step: int)
signal bay_pressed(index: int)
signal background_pressed
signal dropped_on(slot: String, data: Dictionary)

const TERMINALS: Array[String] = ["tienda", "mejoras", "habilidades"]
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
## Modo mision: lo que tarda en bajar la luz y cuanto oscurece el hangar
## (menos sobre tu robot).
const MISSION_SECONDS := 0.35
const MISSION_DIM := 0.7
const MISSION_DIM_ROBOT := 0.3
## Salir a combatir: lo que dura y lo que anda tu robot (unidades del dibujo).
const LAUNCH_SECONDS := 0.85
const LAUNCH_WALK := 250.0

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
	# La alarma late: su tinte se repinta cada cuadro.
	if _alarm > 0.0:
		_dim.queue_redraw()


func _on_footstep(_at: Vector2) -> void:
	if _launching:
		Sfx.play("paso")


## La penumbra del modo mision: mas clara sobre tu robot, que sigue bajo su
## foco. Al salir a combatir, la alarma lo tine todo de rojo.
func _draw_dim() -> void:
	if mission <= 0.001 and _alarm <= 0.001:
		return
	var center := _platform_center()
	var reach := size.x * 0.17
	var columns: Array[float] = [0.0, center - reach, center, center + reach, size.x]
	var alphas: Array[float] = [
		MISSION_DIM, MISSION_DIM * 0.9, MISSION_DIM_ROBOT, MISSION_DIM * 0.85, MISSION_DIM
	]
	for i in columns.size() - 1:
		var from := Color(0.01, 0.02, 0.05, alphas[i] * mission)
		var to := Color(0.01, 0.02, 0.05, alphas[i + 1] * mission)
		_dim.draw_polygon(
			PackedVector2Array(
				[
					Vector2(columns[i], 0),
					Vector2(columns[i + 1], 0),
					Vector2(columns[i + 1], size.y),
					Vector2(columns[i], size.y)
				]
			),
			PackedColorArray([from, to, to, from])
		)
	if _alarm > 0.0:
		# La alarma: todo se tine de rojo a golpes y dos balizas barren el techo.
		var beat := 0.4 + 0.6 * absf(sin(_time * 9.0))
		_dim.draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.1, 0.05, 0.22 * _alarm * beat))
		for side: float in [0.2, 0.8]:
			var lamp := Vector2(size.x * side, size.y * 0.1)
			var sweep := sin(_time * 7.0 + side * 9.0) * size.x * 0.22
			var cone := PackedVector2Array(
				[
					lamp + Vector2(-6, 0),
					lamp + Vector2(6, 0),
					Vector2(lamp.x + sweep + size.x * 0.1, _floor_y),
					Vector2(lamp.x + sweep - size.x * 0.1, _floor_y)
				]
			)
			_dim.draw_colored_polygon(cone, Color(1.0, 0.2, 0.1, 0.16 * _alarm))
			_dim.draw_circle(lamp, 7.0, Color(1.0, 0.3, 0.2, 0.9 * _alarm * beat))


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
	}
	_board.position = Vector2(size.x * 0.72, size.y * 0.07)
	_board.size = Vector2(size.x * 0.255, size.y * 0.27)
	_row.layout(size, _floor_y, _world.scale.x, _board.position.y + _board.size.y + 4.0)
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
	# Estante: dos filas bajo el robot.
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
		_draw_turn_marks(Vector2(center, _floor_y))


## Lo quieto del hangar, sobre `c`: la textura o, mientras no esta, el
## propio escenario.
func _draw_still(c: CanvasItem) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	HangarArt.draw_wall(c, rect, _floor_y, 1.0)
	HangarArt.draw_gantry(c, rect, 1.0)
	_draw_back_row(c)
	for terminal in TERMINALS:
		if _terminal_rects.has(terminal):
			_draw_terminal_still(c, terminal, _terminal_rects[terminal])
	var board := Rect2(_board.position, _board.size)
	_draw_cable(c, Vector2(board.position.x + board.size.x * 0.8, board.end.y))
	var center := _platform_center()
	HangarArt.draw_floor(c, rect, _floor_y, Vector2(center, _floor_y - size.y * 0.9))
	_draw_floor_marks(c, center)
	HangarArt.draw_light_cone(c, rect, center, _floor_y)
	if _mech.build != null:
		HangarArt.draw_platform(c, Vector2(center, _floor_y), _platform_width)
	_draw_props(c)
	_draw_target_stand(c)
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


## Centro de la plataforma del robot, en la pantalla: bajo sus piernas.
func _platform_center() -> float:
	if _launching:
		return _launch_center
	var legs := _world_rect("legs")
	if legs.size == Vector2.ZERO:
		return _world.position.x
	return _world.position.x + legs.get_center().x * _world.scale.x


## Muescas de la plataforma giratoria: dan la vuelta con el robot; la larga
## marca hacia donde mira. Al pasar el raton o girarla, el borde se enciende.
func _draw_turn_marks(feet: Vector2) -> void:
	var rx := _platform_width * 0.5
	var ry := maxf(_platform_width * 0.09, 4.0)
	var live := _hover_platform or _turning
	if live:
		for i in 48:
			var a0 := TAU * i / 48.0
			var a1 := TAU * (i + 1) / 48.0
			draw_line(
				feet + Vector2(cos(a0) * rx, sin(a0) * ry),
				feet + Vector2(cos(a1) * rx, sin(a1) * ry),
				Color(COLOR_SOCKET, 0.95),
				3.0
			)
	for k in 12:
		# De perfil el robot mira a la derecha; al girar se aleja de quien mira.
		var a := -turn + TAU * k / 12.0
		var out := Vector2(cos(a) * rx, sin(a) * ry)
		var reach := 0.78 if k == 0 else 0.9
		var alpha := (0.9 if k == 0 else 0.4) * (1.0 if sin(a) > -0.2 else 0.55)
		var color := Color(
			COLOR_SELECTED if k == 0 else COLOR_SOCKET, alpha if live else alpha * 0.7
		)
		draw_line(feet + out * reach, feet + out * 0.97, color, 2.5 if k == 0 else 1.5)


## Fila del fondo: una tarima con tres bahias, cada una con sus columnas, su
## numero y su plataforma. Su luz y su holograma van aparte (se mueven).
func _draw_back_row(c: CanvasItem) -> void:
	var y := _bay_floor()
	var deck := Rect2(0, y - 4.0, size.x, 12.0)
	c.draw_rect(deck, Color("1a2533"))
	c.draw_line(deck.position, Vector2(deck.end.x, deck.position.y), Color(1, 1, 1, 0.12), 1.0)
	c.draw_line(Vector2(0, deck.end.y), deck.end, Color(0, 0, 0, 0.5), 2.0)
	for i in BAY_X.size():
		var x := size.x * BAY_X[i]
		var w := size.y * 0.2
		var top := y - size.y * 0.36
		# Columnas con sus franjas y una viga con el numero de la bahia.
		for side: float in [-1.0, 1.0]:
			var col := Rect2(x + side * w - 5.0, top, 10.0, y - top)
			c.draw_rect(col, Color("141c27"))
			c.draw_line(col.position, Vector2(col.position.x, col.end.y), Color(1, 1, 1, 0.08), 1.0)
			for k in 4:
				var band_y := top + (y - top) * (0.2 + 0.2 * k)
				c.draw_rect(
					Rect2(col.position.x, band_y, 10.0, 3.0), HangarArt.HAZARD_A.darkened(0.55)
				)
		var beam := Rect2(x - w - 5.0, top - 12.0, w * 2.0 + 10.0, 12.0)
		c.draw_rect(beam, Color("101721"))
		c.draw_line(beam.position, Vector2(beam.end.x, beam.position.y), Color(1, 1, 1, 0.1), 1.0)
		var plate := Rect2(x - 16.0, top - 11.0, 32.0, 10.0)
		c.draw_rect(plate, Color("d9a520").darkened(0.35))
		c.draw_string(
			_font,
			plate.position + Vector2(5, 8.5),
			"%02d" % (i + 2),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color("10151c")
		)
		HangarArt.draw_platform(c, Vector2(x, y), w * 1.1)


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
		if not full:
			# Vacia: para adquirir; con un armazon vacio: su nombre.
			var label := (
				str(bays[i]["name"]) if mine and i < bays.size() else Txt.t("robots_acquire")
			)
			_draw_hologram(Vector2(x, y), size.y * 0.24, hover, label)


## Holograma de una bahia vacia: un cilindro de luz con rejilla y un "+".
func _draw_hologram(feet: Vector2, height: float, hover: bool, label: String) -> void:
	var w := height * 0.32
	var alpha := 0.55 if hover else 0.32
	var flicker := 0.85 + 0.15 * sin(_time * 9.0)
	var color := Color(COLOR_SOCKET, alpha * flicker)
	draw_rect(
		Rect2(feet.x - w, feet.y - height, w * 2.0, height), Color(COLOR_SOCKET, 0.05 * flicker)
	)
	var k := 0.0
	while k < height:
		var y := feet.y - k
		draw_line(Vector2(feet.x - w, y), Vector2(feet.x + w, y), Color(color, color.a * 0.35), 1.0)
		k += 9.0
	draw_line(Vector2(feet.x - w, feet.y - height), Vector2(feet.x - w, feet.y), color, 1.5)
	draw_line(Vector2(feet.x + w, feet.y - height), Vector2(feet.x + w, feet.y), color, 1.5)
	var mid := Vector2(feet.x, feet.y - height * 0.55)
	draw_line(mid - Vector2(12, 0), mid + Vector2(12, 0), color, 3.0)
	draw_line(mid - Vector2(0, 12), mid + Vector2(0, 12), color, 3.0)
	_text(mid + Vector2(-w, 26), label, w * 2.0, 11, Color(COLOR_TEXT, alpha + 0.2), true)


## Una terminal de pared, lo quieto: marco con relieve, cristal con sus
## lineas de barrido, su nombre y el cable que baja a la pared.
func _draw_terminal_still(c: CanvasItem, terminal: String, rect: Rect2) -> void:
	var screen := HangarArt.draw_screen_still(c, rect)
	_text_on(
		c,
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
	var screen := HangarArt.draw_screen_live(self, rect, _hover_terminal == terminal, _time)
	var art := Rect2(screen.position + Vector2(8, 22), screen.size - Vector2(16, 30))
	match terminal:
		"tienda":
			_art_store(art)
		"mejoras":
			_art_upgrades(art)
		"habilidades":
			_art_skills(art)
	var led_at := Vector2(rect.end.x - 14.0, rect.position.y + 6.0)
	draw_circle(led_at, 2.4, Color("55ff9a", 0.4 + 0.4 * sin(_time * 4.0 + rect.position.x)))


## Cable que baja de una pantalla a la pared.
func _draw_cable(c: CanvasItem, from: Vector2) -> void:
	c.draw_line(from, from + Vector2(6.0, 28.0), Color("0e141c"), 3.0)


## Armas colgadas en un expositor.
func _art_store(art: Rect2) -> void:
	for i in 3:
		var y := art.position.y + art.size.y * (0.22 + 0.3 * i)
		var x := art.position.x + 6.0
		draw_rect(Rect2(x, y - 4.0, art.size.x * 0.7, 8.0), Color(COLOR_SCREEN_LINE, 0.55))
		draw_rect(
			Rect2(x + art.size.x * 0.7, y - 2.0, art.size.x * 0.18, 4.0),
			Color(COLOR_SCREEN_LINE, 0.8)
		)
		draw_rect(Rect2(x + 4.0, y + 4.0, 8.0, 7.0), Color(COLOR_SCREEN_LINE, 0.4))
	draw_line(
		art.position + Vector2(2, 0),
		Vector2(art.position.x + 2, art.end.y),
		Color(COLOR_SCREEN_LINE, 0.3),
		1.0
	)


## Barras que suben, como medidores.
func _art_upgrades(art: Rect2) -> void:
	var bars := 6
	var w := art.size.x / bars
	for i in bars:
		var fill := 0.35 + 0.55 * absf(sin(i * 1.7 + _time * 0.6))
		var h := art.size.y * 0.85 * fill
		var bar := Rect2(art.position.x + i * w + 3.0, art.end.y - h, w - 6.0, h)
		draw_rect(bar, Color(COLOR_SCREEN_LINE, 0.5))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x, 3.0)), Color(COLOR_TEXT, 0.9))


## Un arbol de nodos conectados.
func _art_skills(art: Rect2) -> void:
	var root := Vector2(art.get_center().x, art.end.y - 6.0)
	var color := Color(COLOR_SCREEN_LINE, 0.65)
	for branch in 3:
		var tip := Vector2(
			art.position.x + art.size.x * (0.18 + 0.32 * branch), art.position.y + 8.0
		)
		var mid := root.lerp(tip, 0.5)
		draw_line(root, mid, color, 2.0)
		draw_line(mid, tip, color, 2.0)
		for p in [mid, tip]:
			draw_circle(p, 5.0, Color(COLOR_SCREEN, 1.0))
			draw_arc(p, 5.0, 0, TAU, 12, color, 1.5)
	draw_circle(root, 6.0, Color(COLOR_TEXT, 0.9))


## Marcas pintadas en el suelo: el numero del robot y lineas de seguridad.
func _draw_floor_marks(c: CanvasItem, center: float) -> void:
	var y := _floor_y + (size.y - _floor_y) * 0.25
	var stripe := Color(HangarArt.HAZARD_A, 0.25)
	c.draw_line(Vector2(center - size.x * 0.22, y), Vector2(center - size.x * 0.12, y), stripe, 3.0)
	c.draw_line(Vector2(center + size.x * 0.12, y), Vector2(center + size.x * 0.22, y), stripe, 3.0)
	_text_on(
		c,
		Vector2(center - 20.0, _floor_y + (size.y - _floor_y) * 0.16),
		"01",
		40.0,
		14,
		Color(HangarArt.HAZARD_A, 0.35),
		true
	)


## Cosas del taller: una caja de herramientas, unas cajas y una manguera.
func _draw_props(c: CanvasItem) -> void:
	var y := _floor_y + 10.0
	var box := Rect2(size.x * 0.635, y - 30.0, 52.0, 30.0)
	c.draw_rect(box.grow(1.0), Color(0, 0, 0, 0.5))
	c.draw_rect(box, Color("8c2f2a"))
	c.draw_rect(Rect2(box.position, Vector2(box.size.x, 7.0)), Color("a63b33"))
	c.draw_line(
		box.position + Vector2(0, 14),
		Vector2(box.end.x, box.position.y + 14),
		Color(0, 0, 0, 0.4),
		1.0
	)
	c.draw_rect(Rect2(box.position + Vector2(18, -6), Vector2(16, 6)), Color("2b2b2b"), false, 2.0)
	for k in 2:
		var crate := Rect2(size.x * (0.665 + 0.045 * k), y - 44.0 + k * 14.0, 44.0, 44.0 - k * 14.0)
		c.draw_rect(crate, Color("4a3a24").darkened(0.1 * k))
		c.draw_rect(crate, Color("2a2014"), false, 2.0)
		c.draw_line(crate.position, crate.end, Color("2a2014"), 2.0)
		c.draw_line(
			Vector2(crate.end.x, crate.position.y),
			Vector2(crate.position.x, crate.end.y),
			Color("2a2014"),
			2.0
		)
	var hose := PackedVector2Array()
	for i in 12:
		var t := float(i) / 11.0
		hose.append(Vector2(size.x * (0.6 + 0.08 * t), y + 6.0 + sin(t * PI * 2.0) * 5.0))
	c.draw_polyline(hose, Color("1d1d1d"), 4.0, true)


## Estante de equipo: una placa con su rotulo; los huecos van encima.
func _draw_shelf(c: CanvasItem) -> void:
	var shelf := _shelf_rect()
	var style := TechStyle.plate(Color("161e2a"), Color("3c4c62"), 0.0, 8.0)
	style.groove = false
	style.draw(c.get_canvas_item(), shelf)
	_text_on(
		c, shelf.position + Vector2(10, -4), Txt.t("rack_title"), shelf.size.x, 11, Color("9aa7b8")
	)


func _draw_overlay() -> void:
	super._draw_overlay()
	if _mech.build == null or is_turned() or _mission_on:
		return
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


## Poste de la diana, desde el suelo.
func _draw_target_stand(c: CanvasItem) -> void:
	var target := _world.position + _target_point() * _world.scale.x
	var base := Vector2(target.x, _floor_y + 4.0)
	c.draw_line(Vector2(base.x, target.y + 30.0), base, Color("2a3442"), 5.0)
	c.draw_line(
		Vector2(base.x - 1.5, target.y + 30.0),
		Vector2(base.x - 1.5, base.y),
		Color(1, 1, 1, 0.08),
		1.0
	)
	c.draw_rect(Rect2(base.x - 18.0, base.y - 4.0, 36.0, 6.0), Color("1c2430"))
	c.draw_circle(target, 44.0, Color("1a2230"))
	c.draw_arc(target, 44.0, 0, TAU, 32, Color("3a4656"), 3.0)


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
	_text_on(self, at, text, width, font_size, color, centered)


func _text_on(
	c: CanvasItem,
	at: Vector2,
	text: String,
	width: float,
	font_size: int,
	color: Color,
	centered := false
) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	c.draw_string(_font, at + Vector2(1, 1), text, align, width, font_size, Color(0, 0, 0, 0.6))
	c.draw_string(_font, at, text, align, width, font_size, color)


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
		var terminal := "" if on_rival else _terminal_at(motion.position)
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
				if terminal != "" or bay >= 0 or on_rival or slot_at(motion.position) != ""
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
		var terminal := _terminal_at(click.position)
		if terminal != "":
			terminal_pressed.emit(terminal)
			return
		var bay := _bay_at(click.position)
		if bay >= 0 and bay < bays.size():
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
