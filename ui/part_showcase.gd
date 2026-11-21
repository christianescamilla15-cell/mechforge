class_name PartShowcase
extends RefCounted
## La vitrina de la computadora del taller (OBS-039, del usuario: "esta parte
## del menu de la tienda me gustaria que fuera mas inmersivo... como Resident
## Evil, que es super inmersivo"): la pieza en grande, sola sobre un pedestal
## a oscuras, con su foco, su sombra, su reflejo en el suelo y un brillo que
## la recorre de vez en cuando, como al examinar un objeto; y su ficha, con
## una barra por dato que la compara con la que llevas montada: verde lo que
## gana, rojo lo que pierde.
## Solo dibuja sobre el lienzo que le pasan; no decide nada.

const TEXT := Color("eef6ff")
const MUTED := Color("8fa3b8")
const GOLD := Color("ffd36b")
const GOOD := Color("7dff9b")
const BAD := Color("ff7d6b")
## La barra de un dato y el hueco por el que corre.
const FILL := Color("d6e6f5")
const TRACK := Color(0.0, 0.0, 0.0, 0.5)
## La luz del foco: blanca, apenas calida. La de lo que esta en venta, de
## proyector.
const LAMP := Color("fff3dc")
const PROJECTOR := Color("8fe0ff")
const MAX_ROWS := 7
## Casillas minimas de la regla del alcance.
const RANGE_CELLS := 6
## Cada cuanto pasa el brillo por la pieza y cuanto tarda en cruzarla.
const GLINT_EVERY := 4.2
const GLINT_SECONDS := 0.85
## Motas de polvo que flotan en el foco.
const DUST := 9

## Los datos de la ficha, en orden: [campo, texto, mejor ("high", "low" o ""
## si no es ni mejor ni peor)]. "damage" y "range" solo salen en las armas.
const FIELDS := [
	["dmg_bonus", "sheet_boost_", "high"],
	["damage", "sheet_damage", "high"],
	["range", "sheet_range", ""],
	["heat_dmg", "sheet_heat_dmg", "high"],
	["energy_dmg", "sheet_energy_dmg", "high"],
	["res_dmg", "sheet_res_dmg", "high"],
	["push", "sheet_push", "high"],
	["pull", "sheet_pull", "high"],
	["uses", "sheet_uses", "high"],
	["health", "stat_health", "high"],
	["energy_cap", "stat_energy_cap", "high"],
	["energy_regen", "stat_energy_regen", "high"],
	["heat_cap", "stat_heat_cap", "high"],
	["cooling", "stat_cooling", "high"],
	["res_physical", "stat_res_physical", "high"],
	["res_heat", "stat_res_heat", "high"],
	["res_energy", "stat_res_energy", "high"],
	["walk", "sheet_walk", "high"],
	["jump", "sheet_jump", "high"],
	["energy_cost", "sheet_energy_cost", "low"],
	["heat_cost", "sheet_heat_cost", "low"],
	["weight", "sheet_weight", "low"],
]

# --- La ficha -------------------------------------------------------------------------


## Las filas de la ficha de una pieza: [{"key", "label", "value", "base" (el de
## la montada; igual a "value" si no se compara), "top" (el mayor de la
## lista, para la escala), "better", "text", "lo", "hi", "base_lo",
## "base_hi"}]. `base`: la pieza montada con la que se compara (null: ninguna);
## `peers`: las piezas de la lista, que marcan la escala de las barras.
static func rows(item: ItemDef, base: ItemDef = null, peers: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if item == null:
		return out
	var weapon := item.deals_damage()
	for field: Array in FIELDS:
		var key: String = field[0]
		if key in ["damage", "range"] and not weapon:
			continue
		var value := value_of(item, key)
		var before := value_of(base, key) if base != null else value
		if is_zero_approx(value) and is_zero_approx(before):
			continue
		var top := maxf(value, before)
		for peer in peers:
			top = maxf(top, value_of(peer as ItemDef, key))
		(
			out
			. append(
				{
					"key": key,
					"label": _label(field[1], item),
					"value": value,
					"base": before,
					"top": maxf(top, float(RANGE_CELLS) if key == "range" else 1.0),
					"better": field[2],
					"text": text_of(item, key),
					"lo": item.range_min,
					"hi": item.range_max,
					"base_lo": base.range_min if base != null else item.range_min,
					"base_hi": base.range_max if base != null else item.range_max,
				}
			)
		)
	# Si no caben, fuera los del medio: el peso, al final, siempre se ve.
	while out.size() > MAX_ROWS:
		out.remove_at(out.size() - 2)
	return out


## El nombre de una fila; el dano de mas, con las armas a las que va.
static func _label(key: String, item: ItemDef) -> String:
	if key.ends_with("_"):
		return Txt.t(key + (item.boost if item.boost != "" else "all"))
	return Txt.t(key)


## El numero de un dato de una pieza (el dano, su media).
static func value_of(item: ItemDef, key: String) -> float:
	if item == null:
		return 0.0
	match key:
		"damage":
			return (item.dmg_min + item.dmg_max) * 0.5 if item.deals_damage() else 0.0
		"range":
			return float(item.range_max) if item.deals_damage() else 0.0
	return float(item.get(key))


static func text_of(item: ItemDef, key: String) -> String:
	match key:
		"damage":
			return "%d–%d" % [item.dmg_min, item.dmg_max]
		"range":
			return "%d–%d" % [item.range_min, item.range_max]
	return str(int(item.get(key)))


## Lo que gana o pierde la pieza en una fila frente a la montada: 1 si es
## mejor, -1 si es peor, 0 si es igual o el dato no es ni mejor ni peor.
static func verdict(row: Dictionary) -> int:
	var gain := float(row["value"]) - float(row["base"])
	if is_zero_approx(gain) or str(row["better"]) == "":
		return 0
	var up := gain > 0.0
	return 1 if up == (str(row["better"]) == "high") else -1


## La ficha: una fila por dato, con su nombre, su barra (o la regla del
## alcance) y su numero, y una flecha si cambia frente a la montada.
static func draw_sheet(
	c: CanvasItem, font: Font, rect: Rect2, sheet: Array[Dictionary], alpha: float = 1.0
) -> void:
	if sheet.is_empty():
		return
	var high := minf(24.0, rect.size.y / sheet.size())
	var label_wide := minf(98.0, rect.size.x * 0.36)
	var value_wide := 62.0
	for index in sheet.size():
		var row := sheet[index]
		var y := rect.position.y + high * index
		var mid := y + high * 0.5
		HangarProps.text(
			c,
			font,
			Vector2(rect.position.x, mid + 4.0),
			str(row["label"]),
			label_wide - 4.0,
			10,
			Color(MUTED, alpha)
		)
		var bar := Rect2(
			rect.position.x + label_wide,
			mid - 3.5,
			rect.size.x - label_wide - value_wide - 6.0,
			7.0
		)
		if str(row["key"]) == "range":
			_draw_ruler(c, bar, row, alpha)
		else:
			_draw_bar(c, bar, row, alpha)
		var say := verdict(row)
		var tone := TEXT if say == 0 else (GOOD if say > 0 else BAD)
		var at := Vector2(bar.end.x + 6.0, mid + 4.0)
		HangarProps.text(c, font, at, str(row["text"]), value_wide - 14.0, 11, Color(tone, alpha))
		if say != 0:
			var up := float(row["value"]) > float(row["base"])
			_draw_arrow(c, Vector2(rect.end.x - 5.0, mid), up, Color(tone, alpha))


## Una barra por segmentos: lo comun con la montada en claro, lo que gana en
## verde (o rojo si sube algo que mejor baja) y lo que pierde, hueco.
static func _draw_bar(c: CanvasItem, bar: Rect2, row: Dictionary, alpha: float) -> void:
	c.draw_rect(bar, Color(TRACK, TRACK.a * alpha))
	var top := float(row["top"])
	var now := clampf(float(row["value"]) / top, 0.0, 1.0)
	var was := clampf(float(row["base"]) / top, 0.0, 1.0)
	var common := minf(now, was)
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * common, bar.size.y)), Color(FILL, alpha))
	var say := verdict(row)
	var tone := GOOD if say >= 0 else BAD
	if now > was:
		var extra := Rect2(
			bar.position.x + bar.size.x * was, bar.position.y, bar.size.x * (now - was), bar.size.y
		)
		c.draw_rect(extra, Color(tone if say != 0 else FILL, alpha))
	elif was > now:
		var lost := Rect2(
			bar.position.x + bar.size.x * now, bar.position.y, bar.size.x * (was - now), bar.size.y
		)
		var lost_tone := BAD if say < 0 else (GOOD if say > 0 else FILL)
		c.draw_rect(lost, Color(lost_tone, 0.22 * alpha))
		c.draw_rect(lost, Color(lost_tone, 0.8 * alpha), false, 1.0)
	# Las muescas de los segmentos.
	var step := bar.size.x / 10.0
	for i in range(1, 10):
		var x := bar.position.x + step * i
		c.draw_line(
			Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.55 * alpha), 1.0
		)


## La regla del alcance: una casilla por distancia, encendidas las que
## alcanza; debajo, una raya con las de la montada.
static func _draw_ruler(c: CanvasItem, bar: Rect2, row: Dictionary, alpha: float) -> void:
	var cells := int(row["top"])
	var w := bar.size.x / cells
	var compare := int(row["base_lo"]) != int(row["lo"]) or int(row["base_hi"]) != int(row["hi"])
	for i in cells:
		var dist := i + 1
		var cell := Rect2(bar.position.x + w * i + 1.0, bar.position.y - 1.0, w - 2.0, 9.0)
		var lit := dist >= int(row["lo"]) and dist <= int(row["hi"])
		c.draw_rect(cell, Color(FILL, alpha) if lit else Color(TRACK, TRACK.a * alpha))
		if compare and dist >= int(row["base_lo"]) and dist <= int(row["base_hi"]):
			c.draw_rect(
				Rect2(cell.position.x, cell.end.y + 2.0, cell.size.x, 2.0), Color(MUTED, alpha)
			)


static func _draw_arrow(c: CanvasItem, at: Vector2, up: bool, color: Color) -> void:
	var dir := -1.0 if up else 1.0
	c.draw_colored_polygon(
		PackedVector2Array(
			[at + Vector2(-4, 2.5 * -dir), at + Vector2(4, 2.5 * -dir), at + Vector2(0, 3.5 * dir)]
		),
		color
	)


# --- El pedestal ----------------------------------------------------------------------


## El pedestal: fondo a oscuras, el cono del foco con su polvo, el charco de
## luz en el suelo y, encima, la pieza flotando un poco, con su sombra, su
## reflejo y el brillo que la recorre. `for_sale`: luz de proyector y la pieza
## algo azulada (aun no es tuya). `locked`: un candado en vez de la pieza.
static func draw_stage(
	c: CanvasItem,
	rect: Rect2,
	item: ItemDef,
	paint: int,
	time: float,
	for_sale: bool = false,
	locked: bool = false,
	alpha: float = 1.0
) -> void:
	var light := PROJECTOR if for_sale else LAMP
	var steps := 10
	for i in steps:
		var t := float(i) / steps
		var band := Rect2(
			rect.position.x,
			rect.position.y + rect.size.y * t,
			rect.size.x,
			rect.size.y / steps + 1.0
		)
		c.draw_rect(band, Color(0.015 + 0.03 * t, 0.02 + 0.035 * t, 0.03 + 0.045 * t, alpha))
	var mid := rect.get_center().x
	var floor_y := rect.position.y + rect.size.y * 0.8
	for i in 4:
		var spread := 0.16 + 0.09 * i
		var top_w := rect.size.x * (0.035 + 0.018 * i)
		var cone := PackedVector2Array(
			[
				Vector2(mid - top_w, rect.position.y),
				Vector2(mid + top_w, rect.position.y),
				Vector2(mid + rect.size.x * spread, floor_y),
				Vector2(mid - rect.size.x * spread, floor_y),
			]
		)
		c.draw_colored_polygon(cone, Color(light, 0.03 * alpha))
	_draw_dust(c, rect, floor_y, light, time, alpha)
	var pool := Vector2(rect.size.x * 0.36, rect.size.y * 0.07)
	_ellipse(c, Vector2(mid, floor_y), pool, Color(light, 0.08 * alpha))
	_ellipse(c, Vector2(mid, floor_y), pool * 0.6, Color(light, 0.1 * alpha))
	c.draw_rect(rect, Color(light, 0.18 * alpha), false, 1.0)
	if locked:
		_draw_lock(c, Vector2(mid, rect.position.y + rect.size.y * 0.45), Color(BAD, 0.85 * alpha))
		return
	if item == null:
		return
	var area := Rect2(
		rect.position.x + rect.size.x * 0.1,
		rect.position.y + rect.size.y * 0.12,
		rect.size.x * 0.8,
		rect.size.y * 0.56
	)
	var drawing := MechSprites.icon_for(item, paint)
	if drawing == null:
		# Sin dibujo propio (modulos, especiales): su cartucho, en grande.
		var side := minf(area.size.x, area.size.y) * 0.8
		var glyph := Rect2(area.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
		_ellipse(c, Vector2(mid, floor_y), Vector2(side * 0.4, 5.0), Color(0, 0, 0, 0.5 * alpha))
		PartIcon.paint(c, glyph, item, alpha)
		return
	var tex := drawing.get_size()
	var fit := minf(area.size.x / tex.x, area.size.y / tex.y)
	var drawn := tex * fit
	var bob := sin(time * 1.4) * 3.0
	var sway := sin(time * 0.7) * 0.03
	var center := Vector2(mid, area.get_center().y + bob)
	# La sombra en el suelo: mas chica y tenue cuanto mas sube la pieza.
	var shade := Vector2(drawn.x * (0.4 - bob * 0.004), 5.0)
	_ellipse(c, Vector2(mid, floor_y), shade, Color(0, 0, 0, (0.5 - bob * 0.02) * alpha))
	# El reflejo: la mitad de abajo de la pieza, volteada bajo el suelo.
	var lift := floor_y - (center.y + drawn.y * 0.5)
	var deep := minf(drawn.y * 0.3, rect.end.y - floor_y - lift - 2.0)
	if deep > 2.0:
		c.draw_set_transform(Vector2(mid, floor_y + lift), -sway, Vector2(1.0, -1.0))
		c.draw_texture_rect_region(
			drawing,
			Rect2(-drawn.x * 0.5, -deep, drawn.x, deep),
			Rect2(0.0, tex.y * 0.5, tex.x, tex.y * 0.5),
			Color(light, 0.1 * alpha)
		)
	c.draw_set_transform(center, sway, Vector2.ONE)
	var at := Rect2(-drawn * 0.5, drawn)
	# El filo de arriba, encendido por el foco.
	c.draw_texture_rect(
		drawing,
		Rect2(at.position + Vector2(0.0, -1.5), at.size),
		false,
		Color(light.r * 1.6, light.g * 1.6, light.b * 1.6, 0.35 * alpha)
	)
	var tint := Color(0.78, 0.93, 1.05) if for_sale else Color.WHITE
	c.draw_texture_rect(drawing, at, false, Color(tint, alpha))
	_draw_glint(c, drawing, at, time, alpha)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## El brillo: una franja de la propia pieza, mas clara, que la cruza.
static func _draw_glint(
	c: CanvasItem, drawing: Texture2D, at: Rect2, time: float, alpha: float
) -> void:
	var phase := fposmod(time, GLINT_EVERY) / GLINT_SECONDS
	if phase >= 1.0:
		return
	var wide := 0.14
	var from := clampf(lerpf(-wide, 1.0, phase), 0.0, 1.0)
	var to := clampf(lerpf(-wide, 1.0, phase) + wide, 0.0, 1.0)
	if to <= from:
		return
	var tex := drawing.get_size()
	c.draw_texture_rect_region(
		drawing,
		Rect2(at.position.x + at.size.x * from, at.position.y, at.size.x * (to - from), at.size.y),
		Rect2(tex.x * from, 0.0, tex.x * (to - from), tex.y),
		Color(1.9, 1.9, 2.0, 0.4 * sin(phase * PI) * alpha)
	)


## Motas que suben despacio por el foco.
static func _draw_dust(
	c: CanvasItem, rect: Rect2, floor_y: float, light: Color, time: float, alpha: float
) -> void:
	var high := floor_y - rect.position.y
	for i in DUST:
		var phase0 := float(i) * 12.9898
		var x := (
			rect.get_center().x + sin(phase0) * rect.size.x * 0.2 + sin(time * 0.5 + phase0) * 6.0
		)
		var y := floor_y - fposmod(time * (6.0 + i % 3 * 3.0) + fposmod(phase0 * 37.0, high), high)
		var glow := sin(PI * (floor_y - y) / high)
		c.draw_circle(Vector2(x, y), 1.1, Color(light, 0.35 * glow * alpha))


static func _ellipse(c: CanvasItem, at: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * i / 24.0
		points.append(at + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	c.draw_colored_polygon(points, color)


static func _draw_lock(c: CanvasItem, at: Vector2, color: Color) -> void:
	c.draw_rect(Rect2(at - Vector2(16, 0), Vector2(32, 24)), color)
	c.draw_arc(at, 11.0, PI, TAU, 16, color, 4.0)
	c.draw_circle(at + Vector2(0, 10), 3.5, Color(0, 0, 0, 0.6))
