class_name HangarStage
extends MechStage
## El hangar entero, como pantalla de inicio (pedido del usuario el
## 2026-11-18: "la menor cantidad de botones, todo integrado como vista de
## taller, inmersivo y con muchos detalles"). Sobre el escenario del taller
## (MechStage) anade:
## - tus otros robots en tres bahias al fondo, mas pequenos y en penumbra
##   (un clic y pasas a usarlo; una bahia vacia es para adquirir uno);
## - cuatro terminales en la pared (tienda, mejoras, habilidades y misiones)
##   que se iluminan al pasar y abren su panel;
## - enchufes que brillan en los huecos de arma vacios del robot;
## - un estante de equipo con los huecos que no se ven en el dibujo (pecho,
##   especiales, asistente y modulos), con huecos de verdad (SlotCell).
## Pulsar el hangar vacio cierra el panel abierto.

signal terminal_pressed(terminal: String)
signal bay_pressed(index: int)
signal background_pressed
signal dropped_on(slot: String, data: Dictionary)

const TERMINALS: Array[String] = ["tienda", "mejoras", "habilidades", "misiones"]
## Huecos del estante: arriba lo especial, abajo los modulos.
const RACK_TOP: Array[String] = [
	"chest", "charge", "teleport", "hook", "assist", "drone", "drone_low"
]
const RACK_BOTTOM: Array[String] = [
	"module0", "module1", "module2", "module3", "module4", "module5", "module6", "module7"
]
## Centro de cada bahia, como parte del ancho. De frente y con las armas
## abiertas un robot es ancho: las dos de la izquierda van separadas.
const BAY_X: Array[float] = [0.085, 0.225, 0.815]
const COLOR_SCREEN := Color("0b2a33")
const COLOR_SCREEN_LINE := Color("3fd0e6")
const COLOR_TEXT := Color("bfefff")
const COLOR_SOCKET := Color("57d3ff")
const SOCKET_RADIUS := 13.0

## Lineas del panel de misiones (zona, combate y rival).
var mission_lines: PackedStringArray = []
## Robots de las bahias: [{"index", "build", "name"}]; uno con "index" -1 es
## una bahia vacia.
var bays: Array[Dictionary] = []
## Celdas del estante, por hueco (las crea WorkshopScreen).
var rack: Dictionary[String, SlotCell] = {}

var _bay_layer := Node2D.new()
var _bay_views: Array[MechView] = []
var _terminal_rects: Dictionary[String, Rect2] = {}
var _bay_rects: Array[Rect2] = []
var _hover_terminal: String = ""
var _hover_bay: int = -2
var _font: Font


func _ready() -> void:
	super._ready()
	add_child(_bay_layer)
	move_child(_bay_layer, 0)
	_font = get_theme_default_font()


# --- Colocacion ------------------------------------------------------------------


## En el hangar los robots se ven de frente (los que tienen ya ese dibujo).
func _make_mech() -> MechView:
	return FrontMechView.new()


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
	_floor_y = size.y * 0.79
	var height := maxf(-bounds.position.y, 200.0)
	var zoom := minf(1.3, (_floor_y - size.y * 0.13) / height)
	_world.scale = Vector2(zoom, zoom)
	var center := (bounds.position.x + bounds.size.x * 0.35) * zoom
	if (_mech as FrontMechView).is_front():
		# De frente es simetrico: sus pies van en el centro de la plataforma.
		center = 0.0
	_world.position = Vector2(size.x * 0.43 - center, _floor_y)
	var legs := _world_rect("legs")
	_platform_width = maxf(legs.size.x, 80.0) * zoom * 1.7
	_layout()
	queue_redraw()
	_overlay.queue_redraw()


## Bahias, terminales y estante, a la medida de la pantalla.
func _layout() -> void:
	_terminal_rects = {
		"tienda": Rect2(size.x * 0.025, size.y * 0.085, size.x * 0.135, size.y * 0.2),
		"mejoras": Rect2(size.x * 0.175, size.y * 0.085, size.x * 0.12, size.y * 0.2),
		"habilidades": Rect2(size.x * 0.585, size.y * 0.085, size.x * 0.12, size.y * 0.2),
		"misiones": Rect2(size.x * 0.72, size.y * 0.07, size.x * 0.255, size.y * 0.27),
	}
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
		var factor := (size.y * 0.23) / maxf(view.standing_height(), 200.0)
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
		var view := FrontMechView.new()
		_bay_layer.add_child(view)
		if bay["build"] != null:
			view.setup(bay["build"], 1)
			view.modulate = Color(0.62, 0.68, 0.8)
		else:
			view.visible = false
		_bay_views.append(view)
	_layout()


# --- Dibujo ------------------------------------------------------------------


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	HangarArt.draw_wall(self, rect, _floor_y, 1.0)
	HangarArt.draw_gantry(self, rect, 1.0)
	_draw_back_row()
	for terminal in TERMINALS:
		if _terminal_rects.has(terminal):
			_draw_terminal(terminal, _terminal_rects[terminal])
	var center := _world.position.x
	var legs := _world_rect("legs")
	if legs.size != Vector2.ZERO:
		center = _world.position.x + legs.get_center().x * _world.scale.x
	HangarArt.draw_floor(self, rect, _floor_y, Vector2(center, _floor_y - size.y * 0.9))
	_draw_floor_marks(center)
	HangarArt.draw_light(self, rect, center, _floor_y, _time)
	if _mech.build != null:
		HangarArt.draw_platform(self, Vector2(center, _floor_y), _platform_width)
	_draw_props()
	_draw_target_stand()
	_draw_shelf()
	HangarArt.draw_vignette(self, rect, 1.2)


## Fila del fondo: una tarima con tres bahias, cada una con sus columnas, su
## numero, su luz y su plataforma; las vacias, con un holograma.
func _draw_back_row() -> void:
	var y := _bay_floor()
	var deck := Rect2(0, y - 4.0, size.x, 12.0)
	draw_rect(deck, Color("1a2533"))
	draw_line(deck.position, Vector2(deck.end.x, deck.position.y), Color(1, 1, 1, 0.12), 1.0)
	draw_line(Vector2(0, deck.end.y), deck.end, Color(0, 0, 0, 0.5), 2.0)
	for i in BAY_X.size():
		var x := size.x * BAY_X[i]
		var w := size.y * 0.2
		var top := y - size.y * 0.36
		var hover := _hover_bay == i
		# Columnas con sus franjas y una viga con el numero de la bahia.
		for side: float in [-1.0, 1.0]:
			var col := Rect2(x + side * w - 5.0, top, 10.0, y - top)
			draw_rect(col, Color("141c27"))
			draw_line(col.position, Vector2(col.position.x, col.end.y), Color(1, 1, 1, 0.08), 1.0)
			for k in 4:
				var band_y := top + (y - top) * (0.2 + 0.2 * k)
				draw_rect(
					Rect2(col.position.x, band_y, 10.0, 3.0), HangarArt.HAZARD_A.darkened(0.55)
				)
		var beam := Rect2(x - w - 5.0, top - 12.0, w * 2.0 + 10.0, 12.0)
		draw_rect(beam, Color("101721"))
		draw_line(beam.position, Vector2(beam.end.x, beam.position.y), Color(1, 1, 1, 0.1), 1.0)
		var plate := Rect2(x - 16.0, top - 11.0, 32.0, 10.0)
		draw_rect(plate, Color("d9a520").darkened(0.35))
		draw_string(
			_font,
			plate.position + Vector2(5, 8.5),
			"%02d" % (i + 2),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color("10151c")
		)
		# Lamparita de la bahia: verde con robot, ambar vacia.
		var mine := i < bays.size() and int(bays[i]["index"]) >= 0
		var full := mine and bays[i]["build"] != null
		var led := Color("55ff9a") if full else Color("ffb347")
		draw_circle(
			Vector2(x + w - 12.0, top + 6.0), 3.0, Color(led, 0.35 + 0.25 * sin(_time * 3.0 + i))
		)
		draw_circle(Vector2(x + w - 12.0, top + 6.0), 1.6, led)
		HangarArt.draw_platform(self, Vector2(x, y), w * 1.1)
		if hover:
			draw_rect(Rect2(x - w, top, w * 2.0, y - top), Color(COLOR_SOCKET, 0.06))
			draw_rect(Rect2(x - w, top, w * 2.0, y - top), Color(COLOR_SOCKET, 0.5), false, 1.5)
		if not full:
			# Vacia: para adquirir; con un armazon vacio: su nombre.
			var label := str(bays[i]["name"]) if mine else Txt.t("robots_acquire")
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


## Una terminal de pared: marco con relieve, pantalla con lineas de barrido,
## su dibujo, su nombre, un led y un brillo al pasar el raton.
func _draw_terminal(terminal: String, rect: Rect2) -> void:
	var hover := _hover_terminal == terminal
	var frame := TechStyle.plate(
		Color("1c2533"), Color("ffd36b") if hover else Color("4f6380"), 0.0, 8.0
	)
	frame.glow = 0.7 if hover else 0.0
	frame.draw(get_canvas_item(), rect)
	var screen := rect.grow(-9.0)
	var steps := 8
	for i in steps:
		var t := float(i) / steps
		var band := Rect2(
			screen.position.x,
			screen.position.y + screen.size.y * t,
			screen.size.x,
			screen.size.y / steps + 1.0
		)
		draw_rect(band, COLOR_SCREEN.lightened(0.08 * (1.0 - t) + (0.06 if hover else 0.0)))
	var line := 0.0
	while line < screen.size.y:
		draw_line(
			screen.position + Vector2(0, line),
			screen.position + Vector2(screen.size.x, line),
			Color(0, 0, 0, 0.18),
			1.0
		)
		line += 3.0
	var sweep := screen.position.y + fposmod(_time * 40.0, screen.size.y)
	draw_rect(Rect2(screen.position.x, sweep, screen.size.x, 6.0), Color(COLOR_SCREEN_LINE, 0.08))
	var art := Rect2(screen.position + Vector2(8, 22), screen.size - Vector2(16, 30))
	match terminal:
		"tienda":
			_art_store(art)
		"mejoras":
			_art_upgrades(art)
		"habilidades":
			_art_skills(art)
		"misiones":
			_art_missions(art)
	_text(
		screen.position + Vector2(8, 15),
		Txt.t("terminal_" + terminal),
		screen.size.x - 16.0,
		13,
		COLOR_TEXT
	)
	var led_at := Vector2(rect.end.x - 14.0, rect.position.y + 6.0)
	draw_circle(led_at, 2.4, Color("55ff9a", 0.4 + 0.4 * sin(_time * 4.0 + rect.position.x)))
	# Cable que baja de la terminal a la pared.
	var cable_x := rect.position.x + rect.size.x * 0.8
	draw_line(
		Vector2(cable_x, rect.end.y),
		Vector2(cable_x + 6.0, rect.end.y + 28.0),
		Color("0e141c"),
		3.0
	)


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


## Mapa con la ruta y las lineas de la mision.
func _art_missions(art: Rect2) -> void:
	var map := Rect2(art.position, Vector2(art.size.x * 0.42, art.size.y))
	var color := Color(COLOR_SCREEN_LINE, 0.5)
	draw_rect(map, Color(COLOR_SCREEN_LINE, 0.06))
	var points := PackedVector2Array()
	for i in 6:
		points.append(
			(
				map.position
				+ Vector2(
					map.size.x * (0.1 + 0.16 * i), map.size.y * (0.8 - 0.55 * absf(sin(i * 1.3)))
				)
			)
		)
	draw_polyline(points, color, 1.5, true)
	for i in points.size():
		draw_circle(
			points[i],
			3.0 if i < points.size() - 1 else 4.5,
			Color(COLOR_TEXT, 0.9) if i == points.size() - 1 else color
		)
	var x := map.end.x + 8.0
	var y := art.position.y + 12.0
	for line in mission_lines:
		_text(Vector2(x, y), line, art.end.x - x, 11, COLOR_TEXT)
		y += 15.0


## Marcas pintadas en el suelo: el numero del robot y lineas de seguridad.
func _draw_floor_marks(center: float) -> void:
	var y := _floor_y + (size.y - _floor_y) * 0.25
	var stripe := Color(HangarArt.HAZARD_A, 0.25)
	draw_line(Vector2(center - size.x * 0.22, y), Vector2(center - size.x * 0.12, y), stripe, 3.0)
	draw_line(Vector2(center + size.x * 0.12, y), Vector2(center + size.x * 0.22, y), stripe, 3.0)
	_text(
		Vector2(center - 20.0, _floor_y + (size.y - _floor_y) * 0.16),
		"01",
		40.0,
		14,
		Color(HangarArt.HAZARD_A, 0.35),
		true
	)


## Cosas del taller: una caja de herramientas, unas cajas y una manguera.
func _draw_props() -> void:
	var y := _floor_y + 10.0
	var box := Rect2(size.x * 0.635, y - 30.0, 52.0, 30.0)
	draw_rect(box.grow(1.0), Color(0, 0, 0, 0.5))
	draw_rect(box, Color("8c2f2a"))
	draw_rect(Rect2(box.position, Vector2(box.size.x, 7.0)), Color("a63b33"))
	draw_line(
		box.position + Vector2(0, 14),
		Vector2(box.end.x, box.position.y + 14),
		Color(0, 0, 0, 0.4),
		1.0
	)
	draw_rect(Rect2(box.position + Vector2(18, -6), Vector2(16, 6)), Color("2b2b2b"), false, 2.0)
	for k in 2:
		var crate := Rect2(size.x * (0.665 + 0.045 * k), y - 44.0 + k * 14.0, 44.0, 44.0 - k * 14.0)
		draw_rect(crate, Color("4a3a24").darkened(0.1 * k))
		draw_rect(crate, Color("2a2014"), false, 2.0)
		draw_line(crate.position, crate.end, Color("2a2014"), 2.0)
		draw_line(
			Vector2(crate.end.x, crate.position.y),
			Vector2(crate.position.x, crate.end.y),
			Color("2a2014"),
			2.0
		)
	var hose := PackedVector2Array()
	for i in 12:
		var t := float(i) / 11.0
		hose.append(Vector2(size.x * (0.6 + 0.08 * t), y + 6.0 + sin(t * PI * 2.0) * 5.0))
	draw_polyline(hose, Color("1d1d1d"), 4.0, true)


## Estante de equipo: una placa con su rotulo; los huecos van encima.
func _draw_shelf() -> void:
	var shelf := _shelf_rect()
	var style := TechStyle.plate(Color("161e2a"), Color("3c4c62"), 0.0, 8.0)
	style.groove = false
	style.draw(get_canvas_item(), shelf)
	_text(shelf.position + Vector2(10, -4), Txt.t("rack_title"), shelf.size.x, 11, Color("9aa7b8"))


func _draw_overlay() -> void:
	super._draw_overlay()
	if _mech.build == null:
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
func _draw_target_stand() -> void:
	var target := _world.position + _target_point() * _world.scale.x
	var base := Vector2(target.x, _floor_y + 4.0)
	draw_line(Vector2(base.x, target.y + 30.0), base, Color("2a3442"), 5.0)
	draw_line(
		Vector2(base.x - 1.5, target.y + 30.0),
		Vector2(base.x - 1.5, base.y),
		Color(1, 1, 1, 0.08),
		1.0
	)
	draw_rect(Rect2(base.x - 18.0, base.y - 4.0, 36.0, 6.0), Color("1c2430"))
	draw_circle(target, 44.0, Color("1a2230"))
	draw_arc(target, 44.0, 0, TAU, 32, Color("3a4656"), 3.0)


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
	var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	draw_string(_font, at + Vector2(1, 1), text, align, width, font_size, Color(0, 0, 0, 0.6))
	draw_string(_font, at, text, align, width, font_size, color)


# --- Raton -------------------------------------------------------------------


## Hueco bajo un punto: una pieza del robot o el enchufe de un hueco vacio.
func slot_at(at: Vector2) -> String:
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


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var terminal := _terminal_at(motion.position)
		var bay := _bay_at(motion.position) if terminal == "" else -2
		if terminal != _hover_terminal or bay != _hover_bay:
			_hover_terminal = terminal
			_hover_bay = bay
			if terminal != "" or bay >= 0:
				Sfx.play("ui_tic")
		mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
			if terminal != "" or bay >= 0 or slot_at(motion.position) != ""
			else Control.CURSOR_ARROW
		)
		super._gui_input(event)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
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
