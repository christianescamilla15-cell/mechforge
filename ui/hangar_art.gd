class_name HangarArt
extends RefCounted
## El hangar dibujado, con profundidad (pedido del usuario el 2026-11-18:
## "especial detalle y profundidad"): pared de placas con biseles y remaches,
## viga con cadenas y ganchos, lamparas con halo, franja de seguridad, suelo
## en perspectiva hacia un punto de fuga, plataforma con borde iluminado,
## sombra del mech, cono de luz con polvo y vineta. Lo usan el escenario del
## taller (MechStage) y el fondo de la base.

const WALL_TOP := Color("0c131d")
const WALL_BOTTOM := Color("18222f")
const PLATE := Color("1a2431")
const FLOOR_NEAR := Color("27354a")
const FLOOR_FAR := Color("141d29")
const LAMP := Color("ffcf7a")
const TRIM := Color("5a7da6")
const HAZARD_A := Color("d9a520")
const HAZARD_B := Color("1a1a1a")
## Cristal de las pantallas de pared y el color de lo que ensenan.
const SCREEN := Color("0b2a33")
const SCREEN_LINE := Color("3fd0e6")
const SCREEN_TEXT := Color("bfefff")


## Pared del fondo: degradado y placas atornilladas, con una franja de
## seguridad abajo, a la altura del suelo (`floor_y`).
static func draw_wall(canvas: CanvasItem, rect: Rect2, floor_y: float, detail: float = 1.0) -> void:
	var steps := 16
	for i in steps:
		var t := float(i) / steps
		var band := Rect2(
			rect.position.x,
			rect.position.y + (floor_y - rect.position.y) * t,
			rect.size.x,
			(floor_y - rect.position.y) / steps + 1.0
		)
		canvas.draw_rect(band, WALL_TOP.lerp(WALL_BOTTOM, t))
	if detail <= 0.0:
		return
	# Placas: dos filas, cada una con su bisel y sus remaches.
	var height := floor_y - rect.position.y
	var rows := 2
	var cols := maxi(2, roundi(rect.size.x / 150.0))
	var w := rect.size.x / cols
	var h := (height - 26.0 * detail) / rows
	for r in rows:
		for c in cols:
			var plate := Rect2(
				rect.position.x + c * w + 3.0, rect.position.y + r * h + 3.0, w - 6.0, h - 6.0
			)
			if plate.size.x < 20.0 or plate.size.y < 20.0:
				continue
			var shade := 0.02 * float((r * 7 + c * 3) % 4)
			canvas.draw_rect(plate, PLATE.lightened(shade))
			canvas.draw_line(
				plate.position, Vector2(plate.end.x, plate.position.y), Color(1, 1, 1, 0.07), 1.0
			)
			canvas.draw_line(
				plate.position, Vector2(plate.position.x, plate.end.y), Color(1, 1, 1, 0.05), 1.0
			)
			canvas.draw_line(
				Vector2(plate.position.x, plate.end.y), plate.end, Color(0, 0, 0, 0.5), 1.5
			)
			canvas.draw_line(
				Vector2(plate.end.x, plate.position.y), plate.end, Color(0, 0, 0, 0.45), 1.5
			)
			if detail >= 0.6:
				for corner in [
					plate.position + Vector2(7, 7),
					Vector2(plate.end.x - 7, plate.position.y + 7),
					Vector2(plate.position.x + 7, plate.end.y - 7),
					plate.end - Vector2(7, 7)
				]:
					canvas.draw_circle(corner, 2.2, Color(0, 0, 0, 0.5))
					canvas.draw_circle(corner + Vector2(-0.4, -0.4), 1.5, PLATE.lightened(0.3))
				# Rejilla de ventilacion en algunas placas.
				if (r + c) % 3 == 1 and plate.size.y > 60.0:
					var vent := Rect2(
						plate.position + Vector2(plate.size.x * 0.25, plate.size.y * 0.55),
						Vector2(plate.size.x * 0.5, plate.size.y * 0.25)
					)
					for k in 5:
						var y := vent.position.y + vent.size.y * (k + 0.5) / 5.0
						canvas.draw_line(
							Vector2(vent.position.x, y),
							Vector2(vent.end.x, y),
							Color(0, 0, 0, 0.55),
							2.0
						)
						canvas.draw_line(
							Vector2(vent.position.x, y + 1.5),
							Vector2(vent.end.x, y + 1.5),
							Color(1, 1, 1, 0.05),
							1.0
						)
	# Franja de seguridad sobre el suelo.
	var band_h := 12.0 * detail
	if band_h >= 4.0:
		var band := Rect2(rect.position.x, floor_y - band_h, rect.size.x, band_h)
		canvas.draw_rect(band, HAZARD_B)
		var x := rect.position.x - band_h
		while x < rect.end.x:
			var stripe := PackedVector2Array(
				[
					Vector2(x, band.end.y),
					Vector2(x + band_h, band.position.y),
					Vector2(x + band_h * 1.8, band.position.y),
					Vector2(x + band_h * 0.8, band.end.y)
				]
			)
			canvas.draw_colored_polygon(stripe, HAZARD_A.darkened(0.45))
			x += band_h * 2.0
		canvas.draw_line(
			band.position, Vector2(band.end.x, band.position.y), Color(1, 1, 1, 0.12), 1.0
		)


## Suelo en perspectiva: lineas que fugan hacia `vanish` y lineas de
## profundidad que se juntan al alejarse.
static func draw_floor(canvas: CanvasItem, rect: Rect2, floor_y: float, vanish: Vector2) -> void:
	var floor_rect := Rect2(rect.position.x, floor_y, rect.size.x, rect.end.y - floor_y)
	var steps := 10
	for i in steps:
		var t := float(i) / steps
		var band := Rect2(
			floor_rect.position.x,
			floor_y + floor_rect.size.y * t,
			floor_rect.size.x,
			floor_rect.size.y / steps + 1.0
		)
		canvas.draw_rect(band, FLOOR_FAR.lerp(FLOOR_NEAR, t))
	var grid := Color(0.55, 0.72, 0.95, 0.10)
	for i in range(-12, 13):
		var bottom_x := vanish.x + i * floor_rect.size.x / 9.0
		var t := (floor_y - vanish.y) / maxf(rect.end.y - vanish.y, 1.0)
		var top := vanish.lerp(Vector2(bottom_x, rect.end.y), t)
		canvas.draw_line(top, Vector2(bottom_x, rect.end.y), grid, 1.0)
	var y := floor_y
	var gap := floor_rect.size.y * 0.08
	while y < rect.end.y:
		canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), grid, 1.0)
		gap *= 1.45
		y += gap
	canvas.draw_line(
		Vector2(rect.position.x, floor_y),
		Vector2(rect.end.x, floor_y),
		Color(0.6, 0.78, 1.0, 0.35),
		2.0
	)


## Viga del techo con dos cadenas y sus ganchos.
static func draw_gantry(canvas: CanvasItem, rect: Rect2, scale: float = 1.0) -> void:
	var beam := Rect2(rect.position.x, rect.position.y + 6.0 * scale, rect.size.x, 14.0 * scale)
	canvas.draw_rect(beam, Color("101721"))
	canvas.draw_line(beam.position, Vector2(beam.end.x, beam.position.y), Color(1, 1, 1, 0.12), 1.5)
	canvas.draw_line(Vector2(beam.position.x, beam.end.y), beam.end, Color(0, 0, 0, 0.6), 2.0)
	var step := 26.0 * scale
	var x := beam.position.x + step * 0.5
	while x < beam.end.x:
		canvas.draw_line(
			Vector2(x, beam.position.y + 2),
			Vector2(x + step * 0.5, beam.end.y - 2),
			Color(1, 1, 1, 0.05),
			1.0
		)
		x += step
	for fx: float in [0.12, 0.88]:
		var cx := rect.position.x + rect.size.x * fx
		var length := rect.size.y * 0.32
		var link := 7.0 * scale
		var y := beam.end.y
		var k := 0
		while y < beam.end.y + length:
			var ring := Rect2(cx - 2.5 * scale, y, 5.0 * scale, link)
			if k % 2 == 0:
				canvas.draw_rect(ring, Color("3a4656"), false, 1.5)
			else:
				canvas.draw_line(Vector2(cx, y), Vector2(cx, y + link), Color("4a5768"), 1.5)
			y += link * 0.8
			k += 1
		var hook := Vector2(cx, y + 2.0)
		canvas.draw_arc(
			hook + Vector2(0, 6 * scale),
			6.0 * scale,
			-PI * 0.1,
			PI * 1.1,
			10,
			Color("6b7889"),
			2.5 * scale
		)


## Una lampara de pared con su halo.
static func draw_lamp(canvas: CanvasItem, at: Vector2, scale: float = 1.0) -> void:
	for i in 5:
		canvas.draw_circle(at, (40.0 - i * 7.0) * scale, Color(LAMP, 0.025 + i * 0.012))
	canvas.draw_rect(Rect2(at - Vector2(9, 4) * scale, Vector2(18, 8) * scale), Color("2b3442"))
	canvas.draw_rect(Rect2(at - Vector2(7, 2) * scale, Vector2(14, 4) * scale), LAMP)


## Cono de luz desde arriba sobre `center`, con polvo que flota (`time`).
static func draw_light(
	canvas: CanvasItem, rect: Rect2, center_x: float, floor_y: float, time: float
) -> void:
	for i in 5:
		var spread := (40.0 + i * 30.0) * rect.size.y / 560.0
		var top := 12.0 + i * 3.0
		var light := PackedVector2Array(
			[
				Vector2(center_x - top, rect.position.y),
				Vector2(center_x + top, rect.position.y),
				Vector2(center_x + spread * 2.0, floor_y),
				Vector2(center_x - spread * 2.0, floor_y)
			]
		)
		canvas.draw_colored_polygon(light, Color(0.6, 0.78, 1.0, 0.045))
	var height := floor_y - rect.position.y
	for i in 18:
		var salt := float(i) * 12.9898
		var x := center_x + (fposmod(sin(salt) * 437.0, 1.0) - 0.5) * height * 0.5
		var y := (
			rect.position.y + fposmod(salt * 0.13 + time * (0.02 + 0.01 * (i % 3)), 1.0) * height
		)
		var alpha := 0.18 + 0.12 * sin(time * 2.0 + salt)
		canvas.draw_circle(Vector2(x, y), 1.2, Color(1, 0.95, 0.85, alpha))


## Plataforma bajo el mech, con borde iluminado, y su sombra encima.
static func draw_platform(canvas: CanvasItem, feet: Vector2, width: float) -> void:
	var rx := width * 0.5
	var ry := maxf(width * 0.09, 4.0)
	_ellipse(canvas, feet + Vector2(0, ry * 0.9), rx * 1.04, ry * 1.25, Color(0, 0, 0, 0.45))
	_ellipse(canvas, feet + Vector2(0, ry * 0.45), rx, ry * 1.1, Color("1c2838"))
	_ellipse(canvas, feet, rx, ry, Color("2a3a50"))
	_ellipse_line(canvas, feet, rx, ry, Color(0.45, 0.85, 1.0, 0.75), 2.0)
	_ellipse_line(canvas, feet, rx * 0.72, ry * 0.72, Color(1, 1, 1, 0.08), 1.0)
	_ellipse_line(canvas, feet, rx * 0.45, ry * 0.45, Color(1, 1, 1, 0.06), 1.0)
	# Sombra del mech.
	_ellipse(canvas, feet + Vector2(0, 1), rx * 0.62, ry * 0.55, Color(0, 0, 0, 0.5))


## Una pantalla de pared: marco con relieve y, dentro, el cristal con su
## degradado, sus lineas de barrido y una franja de luz que baja (`time`).
## Devuelve el rectangulo del cristal, para dibujar encima.
static func draw_screen(canvas: CanvasItem, rect: Rect2, hover: bool, time: float) -> Rect2:
	var frame := TechStyle.plate(
		Color("1c2533"), Color("ffd36b") if hover else Color("4f6380"), 0.0, 8.0
	)
	frame.glow = 0.7 if hover else 0.0
	frame.draw(canvas.get_canvas_item(), rect)
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
		canvas.draw_rect(band, SCREEN.lightened(0.08 * (1.0 - t) + (0.06 if hover else 0.0)))
	var line := 0.0
	while line < screen.size.y:
		canvas.draw_line(
			screen.position + Vector2(0, line),
			screen.position + Vector2(screen.size.x, line),
			Color(0, 0, 0, 0.18),
			1.0
		)
		line += 3.0
	var sweep := screen.position.y + fposmod(time * 40.0, screen.size.y - 6.0)
	canvas.draw_rect(Rect2(screen.position.x, sweep, screen.size.x, 6.0), Color(SCREEN_LINE, 0.08))
	return screen


## Oscurece los bordes, para que la vista se hunda hacia el centro.
static func draw_vignette(canvas: CanvasItem, rect: Rect2, strength: float = 1.0) -> void:
	var steps := 8
	for i in steps:
		var t := float(i) / steps
		var inset := rect.size.x * 0.06 * t
		var alpha := 0.06 * strength * (1.0 - t)
		canvas.draw_rect(
			Rect2(
				rect.position.x + inset,
				rect.position.y,
				rect.size.x * 0.06 / steps + 1.0,
				rect.size.y
			),
			Color(0, 0, 0, alpha)
		)
		canvas.draw_rect(
			Rect2(
				rect.end.x - inset - rect.size.x * 0.06 / steps,
				rect.position.y,
				rect.size.x * 0.06 / steps + 1.0,
				rect.size.y
			),
			Color(0, 0, 0, alpha)
		)


static func _ellipse(
	canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color
) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	canvas.draw_colored_polygon(points, color)


static func _ellipse_line(
	canvas: CanvasItem, center: Vector2, rx: float, ry: float, color: Color, width: float
) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	canvas.draw_polyline(points, color, width, true)
