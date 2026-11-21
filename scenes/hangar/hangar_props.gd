class_name HangarProps
extends RefCounted
## Las cosas del hangar del jugador (HangarStage), dibujadas: la fila de
## bahias del fondo y sus hologramas, lo que ensena cada pantalla de la
## pared, las marcas del suelo, las cajas y herramientas, el rotulo que
## cuelga sobre tu robot y la bascula de su plataforma. Cada funcion pinta
## sobre el lienzo que le dan (el escenario o la textura de lo quieto) con
## los datos que le dan: aqui no hay estado.

const SCREEN_LINE := Color("3fd0e6")
const SCREEN_TEXT := Color("bfefff")
const SOCKET := Color("57d3ff")
const GOLD := Color("ffd36b")
const BAD := Color("ff7d6b")
const DIM := Color("7fb5c4")
const GOOD := Color("7dff9b")
## Cuanto oscurece el hangar el modo mision (menos sobre tu robot) y cuanto
## una pantalla de cerca.
const MISSION_DIM := 0.7
const MISSION_DIM_ROBOT := 0.3
const FLAT_DIM := 0.55
## A partir de que parte del peso maximo la bascula avisa en dorado.
const WEIGHT_WARN := 0.92


## Texto con su sombra.
static func text(
	c: CanvasItem,
	font: Font,
	at: Vector2,
	line: String,
	width: float,
	font_size: int,
	color: Color,
	centered := false
) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	c.draw_string(font, at + Vector2(1, 1), line, align, width, font_size, Color(0, 0, 0, 0.6))
	c.draw_string(font, at, line, align, width, font_size, color)


## Un numero con sus millares separados ("99 700").
static func thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


# --- El fondo ---------------------------------------------------------------------


## Fila del fondo: una tarima con sus bahias (`bay_xs`, el centro de cada una
## como parte del ancho), cada una con sus columnas, su numero y su
## plataforma. Su luz y su holograma van aparte: se mueven.
static func back_row(
	c: CanvasItem, size: Vector2, floor_y: float, bay_xs: Array[float], font: Font
) -> void:
	var deck := Rect2(0, floor_y - 4.0, size.x, 12.0)
	c.draw_rect(deck, Color("1a2533"))
	c.draw_line(deck.position, Vector2(deck.end.x, deck.position.y), Color(1, 1, 1, 0.12), 1.0)
	c.draw_line(Vector2(0, deck.end.y), deck.end, Color(0, 0, 0, 0.5), 2.0)
	for i in bay_xs.size():
		var x := size.x * bay_xs[i]
		var w := size.y * 0.2
		var top := floor_y - size.y * 0.36
		# Columnas con sus franjas y una viga con el numero de la bahia.
		for side: float in [-1.0, 1.0]:
			var col := Rect2(x + side * w - 5.0, top, 10.0, floor_y - top)
			c.draw_rect(col, Color("141c27"))
			c.draw_line(col.position, Vector2(col.position.x, col.end.y), Color(1, 1, 1, 0.08), 1.0)
			for k in 4:
				var band_y := top + (floor_y - top) * (0.2 + 0.2 * k)
				c.draw_rect(
					Rect2(col.position.x, band_y, 10.0, 3.0), HangarArt.HAZARD_A.darkened(0.55)
				)
		var beam := Rect2(x - w - 5.0, top - 12.0, w * 2.0 + 10.0, 12.0)
		c.draw_rect(beam, Color("101721"))
		c.draw_line(beam.position, Vector2(beam.end.x, beam.position.y), Color(1, 1, 1, 0.1), 1.0)
		var plate := Rect2(x - 16.0, top - 11.0, 32.0, 10.0)
		c.draw_rect(plate, Color("d9a520").darkened(0.35))
		c.draw_string(
			font,
			plate.position + Vector2(5, 8.5),
			"%02d" % (i + 2),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			9,
			Color("10151c")
		)
		HangarArt.draw_platform(c, Vector2(x, floor_y), w * 1.1)


## Holograma de una bahia vacia: un cilindro de luz con rejilla y un "+".
static func hologram(
	c: CanvasItem, feet: Vector2, height: float, hover: bool, label: String, time: float, font: Font
) -> void:
	var w := height * 0.32
	var alpha := 0.55 if hover else 0.32
	var flicker := 0.85 + 0.15 * sin(time * 9.0)
	var color := Color(SOCKET, alpha * flicker)
	c.draw_rect(Rect2(feet.x - w, feet.y - height, w * 2.0, height), Color(SOCKET, 0.05 * flicker))
	var k := 0.0
	while k < height:
		var y := feet.y - k
		c.draw_line(
			Vector2(feet.x - w, y), Vector2(feet.x + w, y), Color(color, color.a * 0.35), 1.0
		)
		k += 9.0
	c.draw_line(Vector2(feet.x - w, feet.y - height), Vector2(feet.x - w, feet.y), color, 1.5)
	c.draw_line(Vector2(feet.x + w, feet.y - height), Vector2(feet.x + w, feet.y), color, 1.5)
	var mid := Vector2(feet.x, feet.y - height * 0.55)
	c.draw_line(mid - Vector2(12, 0), mid + Vector2(12, 0), color, 3.0)
	c.draw_line(mid - Vector2(0, 12), mid + Vector2(0, 12), color, 3.0)
	text(c, font, mid + Vector2(-w, 26), label, w * 2.0, 11, Color(SCREEN_TEXT, alpha + 0.2), true)


## Marcas pintadas en el suelo: el numero del robot y lineas de seguridad.
static func floor_marks(
	c: CanvasItem, size: Vector2, floor_y: float, center: float, font: Font
) -> void:
	var y := floor_y + (size.y - floor_y) * 0.25
	var stripe := Color(HangarArt.HAZARD_A, 0.25)
	c.draw_line(Vector2(center - size.x * 0.22, y), Vector2(center - size.x * 0.12, y), stripe, 3.0)
	c.draw_line(Vector2(center + size.x * 0.12, y), Vector2(center + size.x * 0.22, y), stripe, 3.0)
	text(
		c,
		font,
		Vector2(center - 20.0, floor_y + (size.y - floor_y) * 0.16),
		"01",
		40.0,
		14,
		Color(HangarArt.HAZARD_A, 0.35),
		true
	)


## Cosas del taller: una caja de herramientas, unas cajas y una manguera.
static func clutter(c: CanvasItem, size: Vector2, floor_y: float) -> void:
	var y := floor_y + 10.0
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


## Poste y disco de la diana del campo de pruebas (`target`, su centro).
static func target_stand(c: CanvasItem, target: Vector2, floor_y: float) -> void:
	var base := Vector2(target.x, floor_y + 4.0)
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


# --- Las pantallas ----------------------------------------------------------------


## Tienda: armas colgadas en un expositor.
static func store_art(c: CanvasItem, art: Rect2) -> void:
	for i in 3:
		var y := art.position.y + art.size.y * (0.22 + 0.3 * i)
		var x := art.position.x + 6.0
		c.draw_rect(Rect2(x, y - 4.0, art.size.x * 0.7, 8.0), Color(SCREEN_LINE, 0.55))
		c.draw_rect(
			Rect2(x + art.size.x * 0.7, y - 2.0, art.size.x * 0.18, 4.0), Color(SCREEN_LINE, 0.8)
		)
		c.draw_rect(Rect2(x + 4.0, y + 4.0, 8.0, 7.0), Color(SCREEN_LINE, 0.4))
	c.draw_line(
		art.position + Vector2(2, 0),
		Vector2(art.position.x + 2, art.end.y),
		Color(SCREEN_LINE, 0.3),
		1.0
	)


## Mejoras: una barra por mejora de la armeria, a su nivel (`levels`, de 0
## a 1 cada una).
static func upgrades_art(c: CanvasItem, art: Rect2, levels: Array, time: float) -> void:
	var bars := maxi(levels.size(), 1)
	var w := art.size.x / bars
	for i in bars:
		var level := 0.0 if i >= levels.size() else clampf(float(levels[i]), 0.0, 1.0)
		var slot := Rect2(art.position.x + i * w + 3.0, art.position.y, w - 6.0, art.size.y)
		c.draw_rect(slot, Color(SCREEN_LINE, 0.08))
		var h := art.size.y * (0.04 + 0.96 * level)
		var bar := Rect2(slot.position.x, art.end.y - h, slot.size.x, h)
		c.draw_rect(bar, Color(SCREEN_LINE, 0.5 + 0.08 * sin(time * 1.6 + i * 1.3)))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x, 3.0)), Color(SCREEN_TEXT, 0.9))


## Habilidades: un arbol de nodos conectados.
static func skills_art(c: CanvasItem, art: Rect2) -> void:
	var root := Vector2(art.get_center().x, art.end.y - 6.0)
	var color := Color(SCREEN_LINE, 0.65)
	for branch in 3:
		var tip := Vector2(
			art.position.x + art.size.x * (0.18 + 0.32 * branch), art.position.y + 8.0
		)
		var mid := root.lerp(tip, 0.5)
		c.draw_line(root, mid, color, 2.0)
		c.draw_line(mid, tip, color, 2.0)
		for p: Vector2 in [mid, tip]:
			c.draw_circle(p, 5.0, HangarArt.SCREEN)
			c.draw_arc(p, 5.0, 0, TAU, 12, color, 1.5)
	c.draw_circle(root, 6.0, Color(SCREEN_TEXT, 0.9))


## Pie de la pantalla de la tienda: tus celdas.
static func cells_line(c: CanvasItem, font: Font, at: Vector2, width: float, cells: int) -> void:
	var amount := thousands(cells)
	text(c, font, at, amount, width, 13, SCREEN_TEXT)
	var after := font.get_string_size(amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	text(c, font, at + Vector2(after + 5.0, 0), Txt.t("hud_cells"), 80.0, 9, DIM)


## Pie de la pantalla de habilidades: tu nivel y lo que llevas del siguiente
## (`next` es la experiencia que pide; -1 en el nivel maximo).
static func level_line(
	c: CanvasItem, font: Font, at: Vector2, width: float, level: int, xp: int, next: int
) -> void:
	var label := Txt.t("hud_level", [level])
	text(c, font, at, label, width, 11, SCREEN_TEXT)
	var from := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
	var bar := Rect2(at.x + from, at.y - 7.0, width - from, 5.0)
	var share := 1.0 if next <= 0 else clampf(float(xp) / next, 0.0, 1.0)
	c.draw_rect(bar, Color(0, 0, 0, 0.45))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), SCREEN_LINE)
	c.draw_rect(bar, Color(SCREEN_LINE, 0.5), false, 1.0)


## Una pantalla de la pared, lo quieto: marco con relieve, cristal con sus
## lineas de barrido, su nombre y el cable que baja a la pared. El cuadro de
## control de los ajustes es una caja aparte.
static func terminal_still(c: CanvasItem, font: Font, terminal: String, rect: Rect2) -> void:
	if terminal == "ajustes":
		control_box(c, rect)
		return
	var screen := HangarArt.draw_screen_still(c, rect)
	var at := screen.position + Vector2(8, 15)
	text(c, font, at, Txt.t("terminal_" + terminal), screen.size.x - 16.0, 13, SCREEN_TEXT)
	cable(c, Vector2(rect.position.x + rect.size.x * 0.8, rect.end.y))


## Y lo que se mueve: la franja de luz, su dibujo con lo tuyo (`info`, el
## de HangarStage: celdas, nivel, mejoras), el led y el brillo al pasar el
## raton.
static func terminal_live(
	c: CanvasItem,
	font: Font,
	terminal: String,
	rect: Rect2,
	hover: bool,
	info: Dictionary,
	time: float
) -> void:
	if terminal == "ajustes":
		control_box_live(c, font, rect, hover, time)
		return
	var screen := HangarArt.draw_screen_live(c, rect, hover, time)
	var art := Rect2(screen.position + Vector2(8, 22), screen.size - Vector2(16, 30))
	var foot := Vector2(screen.position.x + 8.0, screen.end.y - 8.0)
	var wide := screen.size.x - 16.0
	match terminal:
		"tienda":
			# Abajo, tus celdas.
			art.size.y -= 16.0
			store_art(c, art)
			cells_line(c, font, foot, wide, int(info.get("cells", 0)))
		"mejoras":
			upgrades_art(c, art, info.get("upgrades", []), time)
		"habilidades":
			# Abajo, tu nivel y lo que llevas del siguiente.
			art.size.y -= 16.0
			skills_art(c, art)
			var next := int(info.get("xp_next", -1))
			level_line(c, font, foot, wide, int(info.get("level", 1)), int(info.get("xp", 0)), next)
	var led_at := Vector2(rect.end.x - 14.0, rect.position.y + 6.0)
	c.draw_circle(led_at, 2.4, Color("55ff9a", 0.4 + 0.4 * sin(time * 4.0 + rect.position.x)))


## Cable que baja de una pantalla a la pared.
static func cable(c: CanvasItem, from: Vector2) -> void:
	c.draw_line(from, from + Vector2(6.0, 28.0), Color("0e141c"), 3.0)


## El banco de equipo: una placa con su rotulo; las cunas van encima.
static func shelf(c: CanvasItem, font: Font, rect: Rect2) -> void:
	var style := TechStyle.plate(Color("161e2a"), Color("3c4c62"), 0.0, 8.0)
	style.groove = false
	style.draw(c.get_canvas_item(), rect)
	text(
		c,
		font,
		rect.position + Vector2(10, -4),
		Txt.t("rack_title"),
		rect.size.x,
		11,
		Color("9aa7b8")
	)


# --- El cuadro de control ----------------------------------------------------------


## El cuadro de control de los ajustes, en la pared: una caja de metal con
## una rueda dentada y tres mandos deslizantes. Lo quieto.
static func control_box(c: CanvasItem, rect: Rect2) -> void:
	var plate := TechStyle.plate(Color("1c2533"), Color("4f6380"), 0.0, 5.0)
	plate.groove = false
	plate.draw(c.get_canvas_item(), rect)
	# El conducto que sube al techo.
	c.draw_rect(Rect2(rect.get_center().x - 3.0, 0.0, 6.0, rect.position.y), Color("121923"))
	var well := rect.grow(-5.0)
	c.draw_rect(well, Color(0, 0, 0, 0.5))
	# Tres ranuras con su mando, a la derecha.
	for i in 3:
		var x := well.position.x + well.size.x * (0.58 + 0.16 * i)
		c.draw_line(
			Vector2(x, well.position.y + 4.0), Vector2(x, well.end.y - 4.0), Color("0a0f16"), 3.0
		)


## Y lo que se mueve: la rueda, que gira al pasar el raton, los mandos, el
## led y, encendido, su nombre debajo.
static func control_box_live(
	c: CanvasItem, font: Font, rect: Rect2, hover: bool, time: float
) -> void:
	var well := rect.grow(-5.0)
	var tone := GOLD if hover else SCREEN_LINE
	var mid := Vector2(well.position.x + well.size.x * 0.27, well.get_center().y)
	var r := minf(well.size.y * 0.36, well.size.x * 0.2)
	var turn := time * 1.6 if hover else 0.0
	for i in 8:
		var a := turn + TAU * i / 8.0
		var out := Vector2(cos(a), sin(a))
		c.draw_line(mid + out * r * 0.7, mid + out * r * 1.3, Color(tone, 0.95), 3.0)
	c.draw_arc(mid, r * 0.78, 0, TAU, 20, Color(tone, 0.95), 3.0)
	c.draw_circle(mid, r * 0.26, Color(tone, 0.95))
	for i in 3:
		var x := well.position.x + well.size.x * (0.58 + 0.16 * i)
		var share := 0.5 + 0.3 * sin(i * 2.1 + (time * 2.0 if hover else 0.0))
		var y := well.position.y + 4.0 + (well.size.y - 8.0) * share
		c.draw_rect(Rect2(x - 4.0, y - 2.0, 8.0, 4.0), Color(tone, 0.9))
	if hover:
		c.draw_rect(rect, GOLD, false, 2.0)
		# Su nombre, a su izquierda (debajo queda el monitor de misiones).
		c.draw_string(
			font,
			Vector2(rect.position.x - 128.0, rect.get_center().y + 4.0),
			Txt.t("settings_title").to_upper(),
			HORIZONTAL_ALIGNMENT_RIGHT,
			120.0,
			11,
			GOLD
		)
	c.draw_circle(
		Vector2(rect.end.x - 5.0, rect.position.y + 5.0),
		1.8,
		Color("55ff9a", 0.5 + 0.4 * sin(time * 4.0))
	)


# --- El rotulo y la bascula -------------------------------------------------------


## Rotulo de la bahia de tu robot: cuelga de la viga con dos cadenas; una
## placa con el numero y el nombre y, si no puede pelear, el aviso debajo
## (`problems`). Al pasar el raton se enciende.
static func bay_sign(
	c: CanvasItem,
	font: Font,
	rect: Rect2,
	label: String,
	problems: String,
	hover: bool,
	time: float
) -> void:
	for x: float in [rect.position.x + 16.0, rect.end.x - 16.0]:
		var y := 20.0
		var k := 0
		while y < rect.position.y:
			if k % 2 == 0:
				c.draw_rect(Rect2(x - 2.5, y, 5.0, 6.0), Color("3a4656"), false, 1.5)
			else:
				c.draw_line(Vector2(x, y), Vector2(x, y + 6.0), Color("4a5768"), 1.5)
			y += 4.8
			k += 1
	var plate := TechStyle.plate(Color("16202d"), GOLD if hover else Color("4f6380"), 0.0, 7.0)
	plate.groove = false
	plate.glow = 0.6 if hover else 0.0
	plate.draw(c.get_canvas_item(), rect)
	var tag := Rect2(rect.position + Vector2(10, 7), Vector2(30, 16))
	c.draw_rect(tag, HangarArt.HAZARD_A.darkened(0.25))
	c.draw_string(
		font,
		tag.position + Vector2(7, 13),
		"01",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		Color("10151c")
	)
	text(
		c,
		font,
		Vector2(tag.end.x + 6.0, rect.position.y + 21.0),
		label.to_upper(),
		rect.end.x - tag.end.x - 20.0,
		16,
		GOLD,
		true
	)
	if hover:
		text(c, font, Vector2(rect.end.x - 20.0, rect.position.y + 20.0), "▾", 14.0, 12, GOLD)
	if problems != "":
		var wide := font.get_string_size(problems, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 20.0
		var at := Vector2(rect.get_center().x - wide * 0.5, rect.end.y + 16.0)
		c.draw_rect(Rect2(at + Vector2(0, -13), Vector2(wide, 18)), Color(0.05, 0.02, 0.02, 0.6))
		text(c, font, at, problems, wide, 12, Color(BAD, 0.75 + 0.25 * sin(time * 5.0)), true)


## La bascula de la plataforma: una pantalla en un poste (`rect`) con el peso
## del robot sobre el maximo (`top`) y una barra hasta el limite con
## sobrecarga (`limit`), que pasa a dorado cerca del maximo y a rojo si lo
## supera.
static func scale(
	c: CanvasItem,
	font: Font,
	rect: Rect2,
	floor_y: float,
	weight: int,
	top: int,
	limit: int,
	time: float,
	delta: int = 0
) -> void:
	weight += delta
	var color := SCREEN_LINE
	if weight > top:
		color = Color(BAD, 0.7 + 0.3 * sin(time * 7.0))
	elif weight >= top * WEIGHT_WARN:
		color = GOLD
	# El poste y su pie, y el cable que va a la plataforma.
	var post := Vector2(rect.get_center().x, rect.end.y)
	c.draw_line(post, Vector2(post.x, floor_y + 2.0), Color("222c3a"), 5.0)
	c.draw_line(
		post + Vector2(-1.5, 0), Vector2(post.x - 1.5, floor_y + 2.0), Color(1, 1, 1, 0.08), 1.0
	)
	c.draw_rect(Rect2(post.x - 14.0, floor_y - 1.0, 28.0, 6.0), Color("1c2430"))
	c.draw_line(
		Vector2(post.x + 14.0, floor_y + 3.0),
		Vector2(rect.end.x + 18.0, floor_y + 5.0),
		Color("0e141c"),
		2.5
	)
	var plate := TechStyle.plate(Color("141c27"), Color("3c4c62"), 0.0, 5.0)
	plate.groove = false
	plate.bolts = false
	plate.draw(c.get_canvas_item(), rect)
	var glass := rect.grow(-4.0)
	c.draw_rect(glass, HangarArt.SCREEN)
	text(c, font, glass.position + Vector2(5, 10), Txt.t("hud_weight"), glass.size.x, 8, DIM)
	text(
		c,
		font,
		glass.position + Vector2(5, 23),
		Txt.t("hud_weight_value", [weight, top]),
		glass.size.x - 8.0,
		11,
		color if weight > top or delta != 0 else SCREEN_TEXT
	)
	if delta != 0:
		c.draw_string(
			font,
			glass.position + Vector2(0, 10),
			"%+d" % delta,
			HORIZONTAL_ALIGNMENT_RIGHT,
			glass.size.x - 4.0,
			9,
			GOOD if delta < 0 else GOLD
		)
	var bar := Rect2(glass.position.x + 5.0, glass.end.y - 8.0, glass.size.x - 10.0, 4.0)
	c.draw_rect(bar, Color(0, 0, 0, 0.5))
	var span := maxf(float(limit), 1.0)
	c.draw_rect(
		Rect2(bar.position, Vector2(bar.size.x * clampf(weight / span, 0.0, 1.0), 4.0)), color
	)
	# La raya del peso maximo: lo de despues es sobrecarga.
	var mark := bar.position.x + bar.size.x * top / span
	c.draw_line(
		Vector2(mark, bar.position.y - 2.0), Vector2(mark, bar.end.y + 2.0), SCREEN_TEXT, 1.0
	)


# --- La luz -----------------------------------------------------------------------


## La penumbra del hangar. En el modo mision (`mission`, de 0 a 1) baja mas
## a los lados que sobre tu robot (`center`), que sigue bajo su foco; con una
## pantalla de cerca (`flat`), baja por igual. Al salir a combatir, la
## alarma (`alarm`) lo tine todo de rojo a golpes y dos balizas barren el
## techo.
static func dim(
	c: CanvasItem, size: Vector2, center: float, floor_y: float, levels: Vector3, time: float
) -> void:
	var mission := levels.x
	var alarm := levels.y
	var flat := levels.z
	if flat > 0.001:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.05, FLAT_DIM * flat))
	if mission > 0.001:
		var reach := size.x * 0.17
		var columns: Array[float] = [0.0, center - reach, center, center + reach, size.x]
		var alphas: Array[float] = [
			MISSION_DIM, MISSION_DIM * 0.9, MISSION_DIM_ROBOT, MISSION_DIM * 0.85, MISSION_DIM
		]
		for i in columns.size() - 1:
			var from := Color(0.01, 0.02, 0.05, alphas[i] * mission)
			var to := Color(0.01, 0.02, 0.05, alphas[i + 1] * mission)
			c.draw_polygon(
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
	if alarm <= 0.0:
		return
	var beat := 0.4 + 0.6 * absf(sin(time * 9.0))
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.1, 0.05, 0.22 * alarm * beat))
	for side: float in [0.2, 0.8]:
		var lamp := Vector2(size.x * side, size.y * 0.1)
		var sweep := sin(time * 7.0 + side * 9.0) * size.x * 0.22
		var cone := PackedVector2Array(
			[
				lamp + Vector2(-6, 0),
				lamp + Vector2(6, 0),
				Vector2(lamp.x + sweep + size.x * 0.1, floor_y),
				Vector2(lamp.x + sweep - size.x * 0.1, floor_y)
			]
		)
		c.draw_colored_polygon(cone, Color(1.0, 0.2, 0.1, 0.16 * alarm))
		c.draw_circle(lamp, 7.0, Color(1.0, 0.3, 0.2, 0.9 * alarm * beat))


## Muescas de la plataforma giratoria (`feet`, de ancho `width`): dan la
## vuelta con el robot (`turn`); la larga marca hacia donde mira. Con `live`
## (el raton encima o girandola) el borde se enciende.
static func turn_marks(c: CanvasItem, feet: Vector2, width: float, turn: float, live: bool) -> void:
	var rx := width * 0.5
	var ry := maxf(width * 0.09, 4.0)
	if live:
		for i in 48:
			var a0 := TAU * i / 48.0
			var a1 := TAU * (i + 1) / 48.0
			c.draw_line(
				feet + Vector2(cos(a0) * rx, sin(a0) * ry),
				feet + Vector2(cos(a1) * rx, sin(a1) * ry),
				Color(SOCKET, 0.95),
				3.0
			)
	for k in 12:
		# De perfil el robot mira a la derecha; al girar se aleja de quien mira.
		var a := -turn + TAU * k / 12.0
		var out := Vector2(cos(a) * rx, sin(a) * ry)
		var reach := 0.78 if k == 0 else 0.9
		var alpha := (0.9 if k == 0 else 0.4) * (1.0 if sin(a) > -0.2 else 0.55)
		var color := Color(Color("ffe27a") if k == 0 else SOCKET, alpha if live else alpha * 0.7)
		c.draw_line(feet + out * reach, feet + out * 0.97, color, 2.5 if k == 0 else 1.5)
