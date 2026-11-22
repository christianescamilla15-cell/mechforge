class_name ZoneArt
## La zona de combate (OBS-048), a la que se sale desde el hangar por su
## compuerta. Del usuario: "ahora si ves a tus combatientes en tamano real y
## puedes elegir entrar a campana... se ve mas como un combate como previo a
## la WWE". Es la arena antes de la lucha: oscura, con el publico como un mar
## de lucecitas y flashes, una armadura de focos arriba que barren la pista,
## la rampa de entrada al fondo con sus tiras de luz y el suelo de acero
## brillante, que refleja. Se pinta entera cada cuadro (los focos se
## mueven), encima del hangar, con la opacidad del modo mision.

const SKY_TOP := Color("05030c")
const SKY_LOW := Color("1a0c2e")
const CROWD := Color("2a1a40")
const LED_A := Color("3fd0e6")
const LED_B := Color("ff4fd8")
const BEAM := Color("bfe8ff")
const STEEL := Color("0d1119")
## Cuantas lucecitas tiene el publico (filas por columnas).
const CROWD_ROWS := 7
const CROWD_COLUMNS := 64


## Toda la arena sobre `c`. `alpha`: lo que se ve (el modo mision).
static func draw(c: CanvasItem, size: Vector2, floor_y: float, time: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	_sky(c, size, floor_y, alpha)
	_crowd(c, size, floor_y, time, alpha)
	_truss(c, size, time, alpha)
	_ramp(c, size, floor_y, time, alpha)
	_stage_floor(c, size, floor_y, time, alpha)
	_beams(c, size, floor_y, time, alpha)


static func _a(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


## El fondo: de negro arriba a morado sobre el publico.
static func _sky(c: CanvasItem, size: Vector2, floor_y: float, alpha: float) -> void:
	var bands := 16
	for i in bands:
		var t := float(i) / bands
		var rect := Rect2(0.0, floor_y * t, size.x, floor_y / bands + 1.0)
		c.draw_rect(rect, _a(SKY_TOP.lerp(SKY_LOW, t), alpha))
	c.draw_rect(Rect2(0.0, floor_y, size.x, size.y - floor_y), _a(STEEL, alpha))


## El publico: filas de cabezas en sombra y un mar de lucecitas (telefonos)
## que titilan, con algun flash de camara.
static func _crowd(c: CanvasItem, size: Vector2, floor_y: float, time: float, alpha: float) -> void:
	var top := floor_y * 0.42
	var bottom := floor_y * 0.93
	var rows := CROWD_ROWS
	for row in rows:
		var t := float(row) / (rows - 1)
		var y := lerpf(top, bottom, t)
		var rise := (1.0 - absf(t - 0.5)) * 4.0
		var shade := _a(CROWD.darkened(0.5 - 0.4 * t), alpha)
		var band := PackedVector2Array()
		band.append(Vector2(0.0, y + 16.0))
		var step := size.x / 48.0
		var x := 0.0
		var k := row * 7
		while x <= size.x + step:
			var bump := 5.0 + 3.0 * sin(float(k) * 1.7)
			band.append(Vector2(x, y - bump - rise))
			x += step
			k += 1
		band.append(Vector2(size.x, y + 16.0))
		c.draw_colored_polygon(band, shade)
		for column in CROWD_COLUMNS:
			var seed := row * 131 + column * 17
			var jitter := fposmod(sin(float(seed) * 12.9898) * 43758.5453, 1.0)
			var px := (float(column) + jitter) * size.x / CROWD_COLUMNS
			var py := y - 6.0 + jitter * 8.0
			var twinkle := 0.35 + 0.35 * sin(time * (1.3 + jitter * 2.0) + seed)
			var color := LED_A if seed % 5 == 0 else (LED_B if seed % 7 == 0 else Color("fff2c8"))
			c.draw_circle(Vector2(px, py), 1.1 + jitter, _a(Color(color, twinkle), alpha))
			# Un flash de camara de vez en cuando.
			var flash := fposmod(time * 0.37 + jitter * 9.0, 7.0)
			if flash < 0.035:
				c.draw_circle(Vector2(px, py), 2.5, _a(Color(1, 1, 1, 0.95), alpha))
				c.draw_circle(Vector2(px, py), 6.0, _a(Color(1, 1, 1, 0.18), alpha))


## La armadura de focos de arriba: una viga en celosia con sus lamparas.
static func _truss(c: CanvasItem, size: Vector2, time: float, alpha: float) -> void:
	var y := size.y * 0.03
	var height := size.y * 0.035
	var rect := Rect2(0.0, y, size.x, height)
	c.draw_rect(rect, _a(Color("0a0c12"), alpha))
	var step := height
	var x := 0.0
	var k := 0
	while x < size.x:
		var a := Vector2(x, y)
		var b := Vector2(x + step, y + height)
		if k % 2 == 1:
			a = Vector2(x, y + height)
			b = Vector2(x + step, y)
		c.draw_line(a, b, _a(Color("2c3340"), alpha), 1.5)
		x += step
		k += 1
	c.draw_line(Vector2(0, y), Vector2(size.x, y), _a(Color("3a4350"), alpha), 2.0)
	c.draw_line(
		Vector2(0, y + height), Vector2(size.x, y + height), _a(Color("3a4350"), alpha), 2.0
	)
	for i in 12:
		var at := Vector2(size.x * (i + 0.5) / 12.0, y + height + 6.0)
		var hot := 0.6 + 0.4 * sin(time * 2.0 + i * 1.3)
		var color := LED_A if i % 3 == 0 else (LED_B if i % 3 == 1 else BEAM)
		c.draw_rect(Rect2(at - Vector2(7, 4), Vector2(14, 9)), _a(Color("1a1f28"), alpha))
		c.draw_circle(at + Vector2(0, 5), 4.0, _a(Color(color, hot), alpha))
		c.draw_circle(at + Vector2(0, 5), 11.0, _a(Color(color, 0.18 * hot), alpha))


## La rampa de entrada, al fondo en el centro, con sus tiras de luz.
static func _ramp(c: CanvasItem, size: Vector2, floor_y: float, time: float, alpha: float) -> void:
	var back := floor_y * 0.62
	var center := size.x * 0.5
	var far_half := size.x * 0.07
	var near_half := size.x * 0.17
	var ramp := PackedVector2Array(
		[
			Vector2(center - far_half, back),
			Vector2(center + far_half, back),
			Vector2(center + near_half, floor_y),
			Vector2(center - near_half, floor_y),
		]
	)
	c.draw_colored_polygon(ramp, _a(Color("10131c"), alpha))
	var pulse := 0.5 + 0.5 * sin(time * 3.0)
	for side: float in [-1.0, 1.0]:
		var a := Vector2(center + side * far_half, back)
		var b := Vector2(center + side * near_half, floor_y)
		c.draw_line(a, b, _a(Color(LED_A, 0.5 + 0.4 * pulse), alpha), 3.0)
		c.draw_line(a, b, _a(Color(LED_A, 0.12), alpha), 12.0)
	# Las marcas de luz que suben por la rampa, hacia el fondo.
	for i in 6:
		var t := fposmod(float(i) / 6.0 - time * 0.15, 1.0)
		var y := lerpf(floor_y, back, t)
		var half := lerpf(near_half, far_half, t) * 0.9
		var glow := _a(Color(LED_B, 0.35 * (1.0 - t)), alpha)
		c.draw_line(Vector2(center - half, y), Vector2(center + half, y), glow, 2.0)


## La pista: acero oscuro que brilla, con lineas que llevan al centro y su
## borde de luz.
static func _stage_floor(
	c: CanvasItem, size: Vector2, floor_y: float, time: float, alpha: float
) -> void:
	var depth := size.y - floor_y
	for i in 10:
		var t := float(i) / 10.0
		var y := floor_y + depth * t * t
		c.draw_line(
			Vector2(0, y), Vector2(size.x, y), _a(Color(1, 1, 1, 0.025 + 0.03 * t), alpha), 1.0
		)
	var vanish := Vector2(size.x * 0.5, floor_y - size.y * 0.6)
	for i in 17:
		var x := size.x * (float(i) / 16.0)
		var top := vanish.lerp(Vector2(x, size.y), (floor_y - vanish.y) / (size.y - vanish.y))
		c.draw_line(top, Vector2(x, size.y), _a(Color(1, 1, 1, 0.035), alpha), 1.0)
	var sweep := 0.5 + 0.5 * sin(time * 1.4)
	c.draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), _a(Color(LED_B, 0.55), alpha), 2.5)
	c.draw_line(
		Vector2(0, floor_y + 3.0),
		Vector2(size.x, floor_y + 3.0),
		_a(Color(LED_A, 0.25 + 0.3 * sweep), alpha),
		2.0
	)


## Los focos que barren la pista desde la armadura.
static func _beams(c: CanvasItem, size: Vector2, floor_y: float, time: float, alpha: float) -> void:
	var origins: Array[float] = [0.12, 0.32, 0.68, 0.88]
	for i in origins.size():
		var from := Vector2(size.x * origins[i], size.y * 0.075)
		var swing := sin(time * (0.45 + 0.1 * i) + i * 1.7)
		var hit := Vector2(size.x * (0.5 + 0.38 * swing), floor_y + size.y * 0.08)
		var spread := size.x * 0.05
		var color := LED_B if i % 2 == 0 else BEAM
		var beam := PackedVector2Array([from, hit + Vector2(-spread, 0), hit + Vector2(spread, 0)])
		var colors := PackedColorArray(
			[
				_a(Color(color, 0.22), alpha),
				_a(Color(color, 0.0), alpha),
				_a(Color(color, 0.0), alpha)
			]
		)
		c.draw_polygon(beam, colors)
		# Donde cae, una mancha de luz aplastada sobre el suelo.
		var pool := PackedVector2Array()
		for k in 20:
			pool.append(hit + Vector2.from_angle(TAU * k / 20.0) * Vector2(spread, spread * 0.22))
		c.draw_colored_polygon(pool, _a(Color(color, 0.07), alpha))
		c.draw_circle(from, 6.0, _a(Color(color, 0.9), alpha))


## El rotulo para volver al hangar, abajo a la izquierda: casi no se ve.
static func back_sign(c: CanvasItem, font: Font, rect: Rect2, hover: bool, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var color := LED_A if hover else Color("5f7f8f")
	c.draw_rect(rect, _a(Color(0.02, 0.03, 0.05, 0.7), alpha))
	c.draw_rect(rect, _a(Color(color, 0.8 if hover else 0.35), alpha), false, 1.0)
	var mid := Vector2(rect.position.x + 14.0, rect.get_center().y)
	var arrow := PackedVector2Array(
		[mid + Vector2(-6, 0), mid + Vector2(4, -6), mid + Vector2(4, 6)]
	)
	c.draw_colored_polygon(arrow, _a(color, alpha))
	c.draw_string(
		font,
		Vector2(rect.position.x + 26.0, rect.get_center().y + 5.0),
		Txt.t("zone_back"),
		HORIZONTAL_ALIGNMENT_LEFT,
		rect.size.x - 30.0,
		13,
		_a(color, alpha)
	)


## La compuerta del hangar a la zona de combate: un portalon en la pared,
## casi parte de ella, con un panelito que apenas luce (del usuario: "un
## boton tan nativamente oculto en la pantalla que casi pasa desapercibido").
static func hangar_door(c: CanvasItem, font: Font, rect: Rect2, hover: bool, time: float) -> void:
	var frame := Color("1c2531")
	c.draw_rect(rect, Color("0d131b"))
	c.draw_rect(rect, frame, false, 3.0)
	var half := rect.size.x * 0.5
	c.draw_line(
		Vector2(rect.position.x + half, rect.position.y),
		Vector2(rect.position.x + half, rect.end.y),
		Color("05080c"),
		2.0
	)
	var y := rect.position.y + 18.0
	while y < rect.end.y - 8.0:
		c.draw_line(
			Vector2(rect.position.x + 6.0, y),
			Vector2(rect.end.x - 6.0, y),
			Color(1, 1, 1, 0.025),
			1.0
		)
		y += 22.0
	# El panelito, a un lado: una luz que late despacio.
	var panel := Rect2(rect.position.x - 22.0, rect.get_center().y - 18.0, 14.0, 26.0)
	c.draw_rect(panel, Color("141b24"))
	c.draw_rect(panel, Color("2b3542"), false, 1.0)
	var beat := 0.35 + 0.25 * sin(time * 1.6)
	var light := Color("55ff9a")
	c.draw_circle(panel.get_center() + Vector2(0, -5), 3.0, Color(light, 0.9 if hover else beat))
	if hover:
		c.draw_circle(panel.get_center() + Vector2(0, -5), 10.0, Color(light, 0.2))
		c.draw_rect(rect.grow(2.0), Color(light, 0.35), false, 1.5)
		var at := Vector2(rect.position.x - 140.0, panel.end.y + 22.0)
		HangarProps.text(c, font, at, Txt.t("zone_door"), 150.0, 13, Color(light, 0.9), false)


## El nombre de tu robot bajo sus pies, como el de un luchador al entrar.
static func fighter_name(
	c: CanvasItem, font: Font, feet: Vector2, label: String, alpha: float
) -> void:
	if alpha <= 0.0 or label == "":
		return
	var text := label.to_upper()
	var font_size := 34
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(feet.x - width * 0.5, feet.y + 58.0)
	c.draw_string(
		font,
		at + Vector2(2, 2),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		_a(Color(0, 0, 0, 0.7), alpha)
	)
	c.draw_string(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _a(Color("fff2c8"), alpha)
	)
	var bar := Rect2(feet.x - width * 0.6, at.y + 10.0, width * 1.2, 3.0)
	c.draw_rect(bar, _a(Color(LED_B, 0.85), alpha))
	c.draw_rect(bar.grow(3.0), _a(Color(LED_B, 0.15), alpha))
