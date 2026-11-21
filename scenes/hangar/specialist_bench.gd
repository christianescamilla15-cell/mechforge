class_name SpecialistBench
extends RefCounted
## El banco del especialista en el suelo del hangar (GDD 8.6, OBS-043): una
## mesa de trabajo de metal con su lampara colgada, un brazo robotico que
## suelda (chispas que saltan de vez en cuando) y su placa. Antes del nivel
## del especialista, una persiana bajada con el nivel que lo abre. Solo dibuja.

const LAMP := Color("ffd9a0")
const METAL := Color("1d242e")
const EDGE := Color("4f6380")
const SPARK := Color("ffe39a")
const TEXT := Color("d8f4ff")
const MUTED := Color("8fa3b8")


## Lo quieto no tiene nada: todo el banco se mueve un poco (la lampara, el
## brazo, las chispas), asi que va entero en `draw`.
static func draw(
	c: CanvasItem, font: Font, rect: Rect2, hover: bool, open: bool, unlock: int, time: float
) -> void:
	var floor_y := rect.end.y - 6.0
	var top := Rect2(
		rect.position.x + 8.0, rect.position.y + rect.size.y * 0.52, rect.size.x - 16.0, 10.0
	)
	# La luz de la lampara en el suelo y sobre la mesa.
	var mid := top.get_center().x
	var cone := PackedVector2Array(
		[
			Vector2(mid - 6.0, rect.position.y + 14.0),
			Vector2(mid + 6.0, rect.position.y + 14.0),
			Vector2(mid + rect.size.x * 0.42, floor_y),
			Vector2(mid - rect.size.x * 0.42, floor_y),
		]
	)
	var glow := 0.06 if open else 0.025
	c.draw_colored_polygon(cone, Color(LAMP, glow + (0.03 if hover else 0.0)))
	# La lampara: cable y pantalla.
	c.draw_line(
		Vector2(mid, rect.position.y - 10.0),
		Vector2(mid, rect.position.y + 8.0),
		Color("0e141c"),
		2.0
	)
	var shade := PackedVector2Array(
		[
			Vector2(mid - 4.0, rect.position.y + 6.0),
			Vector2(mid + 4.0, rect.position.y + 6.0),
			Vector2(mid + 11.0, rect.position.y + 15.0),
			Vector2(mid - 11.0, rect.position.y + 15.0),
		]
	)
	c.draw_colored_polygon(shade, Color("2a3442"))
	c.draw_circle(Vector2(mid, rect.position.y + 15.0), 3.0, Color(LAMP, 0.9 if open else 0.35))
	# La mesa: tablero, faldon y patas.
	for x: float in [top.position.x + 6.0, top.end.x - 10.0]:
		c.draw_rect(Rect2(x, top.end.y, 4.0, floor_y - top.end.y), Color("141a22"))
	c.draw_rect(Rect2(top.position.x, top.end.y, top.size.x, 14.0), METAL)
	c.draw_rect(top, Color("2b3644"))
	c.draw_rect(top, Color(EDGE, 0.8), false, 1.0)
	# Sobre la mesa: una pieza a medio abrir y el brazo que trabaja en ella.
	var piece := Rect2(mid - 26.0, top.position.y - 14.0, 40.0, 14.0)
	c.draw_rect(piece, Color("3c4a5c"))
	c.draw_rect(
		Rect2(piece.position.x + 6.0, piece.position.y + 4.0, 12.0, 6.0), Color("7fe8ff", 0.7)
	)
	var base := Vector2(top.end.x - 18.0, top.position.y)
	var swing := sin(time * 1.3) * 0.25 if open else 0.0
	var elbow := base + Vector2(-14.0, -26.0).rotated(swing)
	var tip := elbow + Vector2(-22.0, 14.0).rotated(swing * 1.6)
	c.draw_line(base, elbow, Color("9aa7b4"), 4.0)
	c.draw_line(elbow, tip, Color("9aa7b4"), 3.0)
	c.draw_circle(elbow, 3.5, Color("5a6878"))
	c.draw_circle(base, 4.5, Color("5a6878"))
	if open:
		# Chispas de soldadura a rafagas.
		var burst := fposmod(time, 1.7)
		if burst < 0.45:
			c.draw_circle(tip, 2.5, Color(1.0, 1.0, 1.0, 0.9))
			for i in 6:
				var angle := float(i) * 1.05 + time * 7.0
				var reach := 4.0 + burst * 30.0
				var spark := tip + Vector2(cos(angle), sin(angle) * 0.6 + 0.5) * reach
				c.draw_line(tip, spark, Color(SPARK, 0.8 * (1.0 - burst / 0.45)), 1.0)
	# La placa del banco.
	var plate := Rect2(rect.position.x + 10.0, floor_y - 18.0, rect.size.x - 20.0, 16.0)
	c.draw_rect(plate, Color(0.02, 0.03, 0.05, 0.85))
	var edge := Color("ffd36b") if hover else Color(EDGE, 0.9)
	c.draw_rect(plate, edge, false, 1.0)
	var label := Txt.t("specialist_title").to_upper()
	if not open:
		label = Txt.t("specialist_from_level", [unlock])
	c.draw_string(
		font,
		Vector2(plate.position.x, plate.end.y - 4.0),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		plate.size.x,
		10,
		TEXT if open else MUTED
	)
	if not open:
		# La persiana bajada sobre la mesa.
		var shutter := Rect2(
			top.position.x - 4.0,
			rect.position.y + 20.0,
			top.size.x + 8.0,
			top.end.y - rect.position.y - 6.0
		)
		c.draw_rect(shutter, Color(0.07, 0.09, 0.12, 0.92))
		var y := shutter.position.y + 5.0
		while y < shutter.end.y:
			c.draw_line(
				Vector2(shutter.position.x, y), Vector2(shutter.end.x, y), Color(1, 1, 1, 0.06), 1.0
			)
			y += 6.0
		c.draw_rect(shutter, Color(EDGE, 0.7), false, 1.0)
	if hover:
		c.draw_rect(rect.grow(2.0), Color(1.0, 0.83, 0.42, 0.35), false, 1.5)
