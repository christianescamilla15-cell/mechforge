class_name PartGlyph
extends RefCounted
## Dibujo de las piezas que no tienen el suyo en MechSprites: los modulos,
## los tres especiales (embestida, salto y garfio) y las armas del
## asistente. Cada una es un cartucho de metal con relieve (sombra, bisel,
## tornillos y contactos), con una ventana del color de su elemento y, en
## ella, el simbolo de lo que hace: una placa, un escudo, un ventilador, unas
## aletas, una bateria, un rayo, un nucleo... Los especiales y las armas del
## asistente llevan su propia silueta.

const METAL := Color("2c3849")
const METAL_DARK := Color("161d28")
const EDGE := Color("6b85a6")
const PIN := Color("c9a24a")
const DRAWN: Array[ItemDef.Type] = [
	ItemDef.Type.MODULE,
	ItemDef.Type.CHARGE,
	ItemDef.Type.TELEPORT,
	ItemDef.Type.HOOK,
	ItemDef.Type.DRONE
]


## True si esa pieza se dibuja aqui.
static func has(item: ItemDef) -> bool:
	return item != null and item.type in DRAWN


## Simbolo de un modulo, segun lo que da.
static func module_symbol(item: ItemDef) -> String:
	# Los de ataque (OBS-040): una mira.
	if item.dmg_bonus > 0:
		return "target"
	var resists := 0
	for value: int in [item.res_physical, item.res_heat, item.res_energy]:
		if value > 0:
			resists += 1
	var energy := item.energy_cap > 0 or item.energy_regen > 0
	var heat := item.heat_cap > 0 or item.cooling > 0
	if resists >= 2:
		return "matrix"
	if resists == 1:
		return "shield"
	if energy and heat:
		return "core"
	if item.health > 0:
		return "armor"
	if item.cooling > 0:
		return "fan"
	if item.heat_cap > 0:
		return "fins"
	if item.energy_regen > 0:
		return "bolt"
	if item.energy_cap > 0:
		return "battery"
	return "core"


## Pinta la pieza centrada en `rect`, sin deformarla.
static func draw(c: CanvasItem, rect: Rect2, item: ItemDef, alpha: float = 1.0) -> void:
	if not has(item) or rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var w := minf(rect.size.x, rect.size.y * 1.45) * 0.88
	var box := Rect2(rect.get_center() - Vector2(w, w / 1.45) * 0.5, Vector2(w, w / 1.45))
	var glow := ShotFx.ammo_color(item.element)
	match item.type:
		ItemDef.Type.MODULE:
			var window := _cartridge(c, box, glow, alpha)
			_symbol(c, window, module_symbol(item), glow, alpha)
		ItemDef.Type.CHARGE:
			_thruster(c, box, glow, alpha)
		ItemDef.Type.TELEPORT:
			_beacon(c, box, glow, alpha)
		ItemDef.Type.HOOK:
			_hook(c, box, glow, alpha)
		ItemDef.Type.DRONE:
			_turret(c, box, item, glow, alpha)


# --- El cartucho ------------------------------------------------------------------


## Un bloque de metal con chaflan: sombra, degradado de luz, bisel y borde.
static func _block(
	c: CanvasItem, box: Rect2, alpha: float, cut: float = -1.0, base: Color = METAL
) -> void:
	var k := cut if cut >= 0.0 else minf(box.size.x, box.size.y) * 0.16
	var points := PackedVector2Array(
		[
			box.position + Vector2(k, 0),
			Vector2(box.end.x - k, box.position.y),
			Vector2(box.end.x, box.position.y + k),
			Vector2(box.end.x, box.end.y - k),
			Vector2(box.end.x - k, box.end.y),
			Vector2(box.position.x + k, box.end.y),
			Vector2(box.position.x, box.end.y - k),
			Vector2(box.position.x, box.position.y + k)
		]
	)
	var drop := maxf(1.5, box.size.y * 0.07)
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(drop * 0.6, drop))
	c.draw_colored_polygon(shadow, Color(0, 0, 0, 0.5 * alpha))
	var top := Color(base.lightened(0.16), alpha)
	var low := Color(base.darkened(0.3), alpha)
	c.draw_polygon(points, PackedColorArray([top, top, top, low, low, low, low, top]))
	# Bisel: luz arriba, sombra abajo.
	c.draw_line(points[0], points[1], Color(1, 1, 1, 0.3 * alpha), 1.0)
	c.draw_line(points[7], points[0], Color(1, 1, 1, 0.18 * alpha), 1.0)
	c.draw_line(points[4], points[5], Color(0, 0, 0, 0.55 * alpha), 1.0)
	points.append(points[0])
	c.draw_polyline(points, Color(EDGE, 0.55 * alpha), 1.0, true)


## El cartucho de un modulo. Devuelve su ventana, para el simbolo.
static func _cartridge(c: CanvasItem, box: Rect2, glow: Color, alpha: float) -> Rect2:
	var body := Rect2(box.position, Vector2(box.size.x, box.size.y * 0.86))
	# Contactos dorados por debajo.
	var pins := 6
	var pin_w := body.size.x * 0.62 / pins
	for i in pins:
		var x := body.position.x + body.size.x * 0.19 + i * pin_w
		c.draw_rect(
			Rect2(x + 1.0, body.end.y - 1.0, pin_w - 2.0, box.size.y * 0.14),
			Color(PIN.darkened(0.15 if i % 2 == 0 else 0.0), alpha)
		)
	_block(c, body, alpha)
	var inset := body.size.y * 0.2
	var window := Rect2(
		body.position + Vector2(inset * 1.3, inset), body.size - Vector2(inset * 2.6, inset * 2.0)
	)
	_window(c, window, glow, alpha)
	# Tornillos y una muesca de agarre a cada lado.
	for corner: Vector2 in [
		body.position + Vector2(inset * 0.62, inset * 0.62),
		Vector2(body.end.x - inset * 0.62, body.end.y - inset * 0.62)
	]:
		c.draw_circle(corner, maxf(1.2, inset * 0.2), Color(0, 0, 0, 0.6 * alpha))
		c.draw_circle(corner - Vector2(0.4, 0.4), maxf(0.8, inset * 0.12), Color(EDGE, 0.8 * alpha))
	return window


## Una ventana hundida que brilla del color del elemento.
static func _window(c: CanvasItem, window: Rect2, glow: Color, alpha: float) -> void:
	c.draw_rect(window.grow(1.5), Color(0, 0, 0, 0.7 * alpha))
	c.draw_rect(window, Color(glow.darkened(0.82), alpha))
	c.draw_rect(
		Rect2(window.position, Vector2(window.size.x, window.size.y * 0.45)),
		Color(glow, 0.1 * alpha)
	)
	c.draw_rect(window, Color(glow, 0.55 * alpha), false, 1.0)


## El simbolo de lo que hace un modulo, dentro de su ventana.
static func _symbol(
	c: CanvasItem, window: Rect2, symbol: String, glow: Color, alpha: float
) -> void:
	var color := Color(glow.lightened(0.25), alpha)
	var mid := window.get_center()
	var r := minf(window.size.x, window.size.y) * 0.36
	var line := maxf(1.2, r * 0.22)
	match symbol:
		"target":
			# Una mira: aro, cruz que no llega al centro y un punto.
			c.draw_arc(mid, r * 0.8, 0, TAU, 24, color, line * 0.8)
			for dir: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				c.draw_line(mid + dir * r * 0.35, mid + dir * r * 1.15, color, line)
			c.draw_circle(mid, r * 0.14, color)
		"armor":
			# Una placa con su cruz.
			c.draw_rect(Rect2(mid - Vector2(r, r), Vector2(r, r) * 2.0), color, false, line)
			c.draw_line(mid - Vector2(r * 0.55, 0), mid + Vector2(r * 0.55, 0), color, line)
			c.draw_line(mid - Vector2(0, r * 0.55), mid + Vector2(0, r * 0.55), color, line)
		"shield":
			_shield(c, mid, r, color, line)
			c.draw_polyline(
				PackedVector2Array(
					[
						mid + Vector2(-r * 0.45, -r * 0.15),
						mid + Vector2(0, r * 0.3),
						mid + Vector2(r * 0.45, -r * 0.15)
					]
				),
				color,
				line
			)
		"matrix":
			for dx: float in [-1.0, 0.0, 1.0]:
				_shield(c, mid + Vector2(dx * r * 1.05, 0), r * 0.55, color, line * 0.8)
		"fan":
			c.draw_arc(mid, r, 0, TAU, 20, color, line * 0.8)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				c.draw_line(mid, mid + Vector2(cos(a), sin(a)) * r * 0.85, color, line * 1.3)
			c.draw_circle(mid, r * 0.2, color)
		"fins":
			for i in 5:
				var x := mid.x + (i - 2) * r * 0.5
				var h := r * (0.6 + 0.35 * (1.0 - absf(i - 2.0) / 2.0))
				c.draw_line(Vector2(x, mid.y + r), Vector2(x, mid.y + r - h * 2.0), color, line)
			c.draw_line(mid + Vector2(-r * 1.3, r), mid + Vector2(r * 1.3, r), color, line)
		"battery":
			var cell := Rect2(mid - Vector2(r * 1.25, r * 0.7), Vector2(r * 2.3, r * 1.4))
			c.draw_rect(cell, color, false, line * 0.8)
			c.draw_rect(Rect2(cell.end.x, mid.y - r * 0.3, r * 0.22, r * 0.6), color)
			for i in 3:
				c.draw_rect(
					Rect2(
						cell.position.x + r * 0.22 + i * r * 0.68,
						cell.position.y + r * 0.25,
						r * 0.46,
						r * 0.9
					),
					color
				)
		"bolt":
			c.draw_colored_polygon(
				PackedVector2Array(
					[
						mid + Vector2(r * 0.35, -r * 1.1),
						mid + Vector2(-r * 0.6, r * 0.15),
						mid + Vector2(-r * 0.05, r * 0.15),
						mid + Vector2(-r * 0.35, r * 1.1),
						mid + Vector2(r * 0.6, -r * 0.2),
						mid + Vector2(r * 0.05, -r * 0.2)
					]
				),
				color
			)
		_:
			# Un nucleo: rombo con su punto.
			c.draw_polyline(
				PackedVector2Array(
					[
						mid + Vector2(0, -r),
						mid + Vector2(r * 1.2, 0),
						mid + Vector2(0, r),
						mid + Vector2(-r * 1.2, 0),
						mid + Vector2(0, -r)
					]
				),
				color,
				line
			)
			c.draw_circle(mid, r * 0.32, color)


static func _shield(c: CanvasItem, mid: Vector2, r: float, color: Color, line: float) -> void:
	c.draw_polyline(
		PackedVector2Array(
			[
				mid + Vector2(-r * 0.8, -r),
				mid + Vector2(r * 0.8, -r),
				mid + Vector2(r * 0.8, r * 0.1),
				mid + Vector2(0, r),
				mid + Vector2(-r * 0.8, r * 0.1),
				mid + Vector2(-r * 0.8, -r)
			]
		),
		color,
		line
	)


# --- Los especiales ---------------------------------------------------------------


## Propulsor de embestida: un bloque con su tobera y las llamas detras.
static func _thruster(c: CanvasItem, box: Rect2, glow: Color, alpha: float) -> void:
	var body := Rect2(
		box.position + Vector2(box.size.x * 0.3, box.size.y * 0.18),
		Vector2(box.size.x * 0.5, box.size.y * 0.64)
	)
	# La tobera, a la izquierda: un cono que se abre.
	var mouth := PackedVector2Array(
		[
			Vector2(body.position.x + 1.0, body.position.y + body.size.y * 0.22),
			Vector2(box.position.x + box.size.x * 0.14, body.position.y - box.size.y * 0.04),
			Vector2(box.position.x + box.size.x * 0.14, body.end.y + box.size.y * 0.04),
			Vector2(body.position.x + 1.0, body.end.y - body.size.y * 0.22)
		]
	)
	c.draw_colored_polygon(mouth, Color(METAL_DARK, alpha))
	c.draw_polyline(mouth, Color(EDGE, 0.6 * alpha), 1.0, true)
	for i in 3:
		var x := box.position.x + box.size.x * (0.1 - 0.045 * i)
		var h := box.size.y * (0.3 - 0.07 * i)
		c.draw_line(
			Vector2(x, box.get_center().y - h),
			Vector2(x - box.size.x * 0.04, box.get_center().y),
			Color(glow, (0.9 - 0.25 * i) * alpha),
			2.0
		)
		c.draw_line(
			Vector2(x - box.size.x * 0.04, box.get_center().y),
			Vector2(x, box.get_center().y + h),
			Color(glow, (0.9 - 0.25 * i) * alpha),
			2.0
		)
	_block(c, body, alpha)
	# El ariete, a la derecha: una cuna de metal claro.
	var ram := PackedVector2Array(
		[
			Vector2(body.end.x - 1.0, body.position.y),
			Vector2(box.end.x, box.get_center().y),
			Vector2(body.end.x - 1.0, body.end.y)
		]
	)
	c.draw_colored_polygon(ram, Color(METAL.lightened(0.3), alpha))
	c.draw_polyline(ram, Color(1, 1, 1, 0.35 * alpha), 1.0, true)
	_window(c, body.grow(-body.size.y * 0.24), glow, alpha)


## Baliza de salto: un pie, su antena y las ondas del salto por encima.
static func _beacon(c: CanvasItem, box: Rect2, glow: Color, alpha: float) -> void:
	var foot := Rect2(
		box.position + Vector2(box.size.x * 0.24, box.size.y * 0.66),
		Vector2(box.size.x * 0.52, box.size.y * 0.3)
	)
	_block(c, foot, alpha)
	_window(c, foot.grow(-foot.size.y * 0.28), glow, alpha)
	var top := Vector2(box.get_center().x, box.position.y + box.size.y * 0.3)
	c.draw_line(Vector2(top.x, foot.position.y), top, Color(METAL.lightened(0.3), alpha), 3.0)
	c.draw_circle(top, maxf(2.5, box.size.y * 0.08), Color(glow.lightened(0.3), alpha))
	for i in 3:
		var r := box.size.y * (0.2 + 0.14 * i)
		c.draw_arc(top, r, PI * 1.15, PI * 1.85, 12, Color(glow, (0.85 - 0.25 * i) * alpha), 1.5)


## Garfio magnetico: su carrete, el cable y la garra.
static func _hook(c: CanvasItem, box: Rect2, glow: Color, alpha: float) -> void:
	var reel := Rect2(
		box.position + Vector2(box.size.x * 0.04, box.size.y * 0.26),
		Vector2(box.size.x * 0.34, box.size.y * 0.5)
	)
	var tip := Vector2(box.position.x + box.size.x * 0.74, box.get_center().y)
	c.draw_line(Vector2(reel.end.x, box.get_center().y), tip, Color(ShotFx.CABLE, 0.9 * alpha), 2.0)
	_block(c, reel, alpha)
	_window(c, reel.grow(-reel.size.y * 0.26), glow, alpha)
	# La garra: tres unas abiertas.
	var r := box.size.y * 0.34
	for angle: float in [-0.95, 0.0, 0.95]:
		var elbow := tip + Vector2(cos(angle), sin(angle)) * r * 0.6
		var end := tip + Vector2(cos(angle * 0.45), sin(angle * 0.45)) * r * 1.15
		c.draw_line(tip, elbow, Color(METAL.lightened(0.35), alpha), 3.0)
		c.draw_line(elbow, end, Color(METAL.lightened(0.5), alpha), 2.0)
	c.draw_circle(tip, maxf(2.5, r * 0.26), Color(glow.lightened(0.2), alpha))
	c.draw_arc(tip, maxf(2.5, r * 0.26), 0, TAU, 12, Color(0, 0, 0, 0.6 * alpha), 1.0)


# --- Las armas del asistente ----------------------------------------------------


## Un arma del asistente: un cuerpo pequeno con su anclaje arriba y, segun
## el tipo, dos canones finos (balas), una boca ancha (canon), un emisor con
## aros (blaster) o una lente larga (laser).
static func _turret(c: CanvasItem, box: Rect2, item: ItemDef, glow: Color, alpha: float) -> void:
	var body := Rect2(
		box.position + Vector2(box.size.x * 0.08, box.size.y * 0.3),
		Vector2(box.size.x * 0.44, box.size.y * 0.5)
	)
	var mid := body.get_center().y
	var steel := Color(METAL.lightened(0.3), alpha)
	var dark := Color(METAL_DARK, alpha)
	match item.weapon_type:
		"balas":
			for dy: float in [-0.14, 0.14]:
				var y := mid + box.size.y * dy
				c.draw_line(Vector2(body.end.x, y), Vector2(box.end.x, y), steel, 3.0)
				c.draw_circle(Vector2(box.end.x, y), 2.0, dark)
		"canon":
			var barrel := Rect2(body.end.x - 1.0, mid - box.size.y * 0.17, box.size.x * 0.3, 0.0)
			barrel.size.y = box.size.y * 0.34
			c.draw_rect(barrel, steel)
			c.draw_rect(
				Rect2(barrel.end.x - 4.0, barrel.position.y - 2.0, 6.0, barrel.size.y + 4.0), dark
			)
			c.draw_line(
				barrel.position,
				Vector2(barrel.end.x, barrel.position.y),
				Color(1, 1, 1, 0.3 * alpha),
				1.0
			)
		"blaster":
			c.draw_line(Vector2(body.end.x, mid), Vector2(box.end.x - 4.0, mid), steel, 4.0)
			for i in 3:
				var x := body.end.x + box.size.x * (0.08 + 0.1 * i)
				c.draw_line(
					Vector2(x, mid - box.size.y * 0.16),
					Vector2(x, mid + box.size.y * 0.16),
					Color(glow, 0.9 * alpha),
					2.0
				)
		_:
			c.draw_line(Vector2(body.end.x, mid), Vector2(box.end.x - 5.0, mid), steel, 2.5)
			c.draw_circle(Vector2(box.end.x - 5.0, mid), box.size.y * 0.11, Color(glow, alpha))
			c.draw_arc(Vector2(box.end.x - 5.0, mid), box.size.y * 0.11, 0, TAU, 12, dark, 1.0)
	# El anclaje con el que cuelga del asistente.
	var tab := Rect2(
		body.get_center().x - body.size.x * 0.18, box.position.y + box.size.y * 0.14, 0, 0
	)
	tab.size = Vector2(body.size.x * 0.36, body.position.y - tab.position.y + 2.0)
	c.draw_rect(tab, dark)
	c.draw_rect(tab, Color(EDGE, 0.5 * alpha), false, 1.0)
	_block(c, body, alpha)
	_window(c, body.grow(-body.size.y * 0.27), glow, alpha)
	if item.form == "zapador":
		# El que drena lleva una antena hacia atras.
		c.draw_line(
			Vector2(body.position.x + 3.0, body.position.y),
			Vector2(box.position.x, box.position.y + box.size.y * 0.1),
			steel,
			1.5
		)
