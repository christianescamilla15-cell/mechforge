class_name AspectLook
extends RefCounted
## Como se ve cada nivel de los aspectos de una pieza (OBS-051, del usuario:
## "cada nivel mejora el arma o armadura en vivo... de manera notable"). Son
## capas que se suman a cualquier dibujo, asi valen para todas las armas y
## torsos sin dibujar cada combinacion:
## - debajo: el grosor engorda la silueta con tinta y un canto de placa; la
##   ligereza deja fantasmas detras; la refrigeracion y la disipacion, un halo
##   frio o caliente;
## - la pieza, con el tono de su material (acero templado, titanio, aleacion
##   negra y, al 10, oro estelar);
## - encima: el brillo del material que la recorre, el destello del filo, las
##   vetas de energia de la eficiencia, la escarcha y las brasas, la boca
##   cargada de la potencia, la mira de la precision y el nucleo del reactor.
## Brillo con tinta (GDD 12.0): todo lo que brilla lleva contorno de tinta.

const INK := Color(0.04, 0.05, 0.07)
const COLD := Color("7fe0ff")
const HOT := Color("ff6a2a")
const ENERGY := Color("5fd4ff")
const CORE := Color("a98bff")
const LASER := Color("ff3d5a")
## El tono de cada aspecto (el destello al subirlo, la tecla).
const COLORS: Dictionary[String, Color] = {
	"potencia": Color("ff9a3d"),
	"precision": LASER,
	"filo": Color("e8fbff"),
	"material": Color("c9d6e8"),
	"refrigeracion": COLD,
	"eficiencia": ENERGY,
	"grosor": Color("8a96a8"),
	"aleacion": Color("c9d6e8"),
	"ligereza": Color("bff7ff"),
	"disipacion": HOT,
	"reactor": CORE,
}
## Material por tramos de nivel: 1-3 acero templado, 4-6 titanio, 7-9
## aleacion negra y 10 oro estelar (por encima de 1, aclara).
const METALS: Array[Color] = [
	Color(0.7, 0.84, 1.0), Color(1.1, 1.14, 1.2), Color(0.62, 0.56, 0.86), Color(1.22, 1.06, 0.62)
]
## La boca cargada segun el elemento del arma: fisico, calor y energia.
const POWER: Array[Color] = [Color("ffd27a"), Color("ff7a2a"), Color("5fd4ff")]
const AROUND: Array[Vector2] = [
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1),
	Vector2(0.71, 0.71),
	Vector2(-0.71, 0.71),
	Vector2(0.71, -0.71),
	Vector2(-0.71, -0.71),
]

## Lo que crece el disparo por cada nivel de potencia (x1.5 al 10).
const SHOT_GROWTH := 0.05


## Cuanto crece el disparo de esa arma por su potencia (1 sin ella).
static func shot_scale(item: ItemDef) -> float:
	if item == null:
		return 1.0
	return 1.0 + SHOT_GROWTH * int(item.aspects.get("potencia", 0))


static func color_of(id: String) -> Color:
	return COLORS.get(id, Color.WHITE)


## Dibuja una pieza con sus aspectos. `box`: donde va el dibujo entero;
## `tip`: la boca del arma; `levels`: {aspecto: nivel}; `time`: el reloj de
## la vista (para lo que se mueve).
static func draw(
	canvas: CanvasItem,
	texture: Texture2D,
	box: Rect2,
	tip: Vector2,
	element: int,
	tint: Color,
	levels: Dictionary,
	time: float
) -> void:
	_under(canvas, texture, box, tint, levels, time)
	canvas.draw_texture_rect(texture, box, false, metal_tint(tint, levels))
	_over(canvas, texture, box, tip, element, tint, levels, time)


## El tono de la pieza por su material: cada nivel tine un poco mas, y los
## tramos 4, 7 y 10 cambian de metal.
static func metal_tint(tint: Color, levels: Dictionary) -> Color:
	var level := maxi(_level(levels, "material"), _level(levels, "aleacion"))
	if level <= 0:
		return tint
	var metal := METALS[mini(floori((level - 1) / 3.0), METALS.size() - 1)]
	var mixed := Color.WHITE.lerp(metal, minf(1.0, 0.32 + 0.068 * level))
	return Color(tint.r * mixed.r, tint.g * mixed.g, tint.b * mixed.b, tint.a)


static func _level(levels: Dictionary, id: String) -> int:
	return int(levels.get(id, 0))


static func _under(
	canvas: CanvasItem, texture: Texture2D, box: Rect2, tint: Color, levels: Dictionary, time: float
) -> void:
	var light := _level(levels, "ligereza")
	var ghosts := 1 + floori(light / 4.0) if light > 0 else 0
	for i in ghosts:
		# Fantasmas detras: cuanto mas ligera, mas lejos y mas visibles.
		var back := Vector2(-(2.0 + 1.1 * light) * (i + 1), 0.0)
		var alpha := (0.1 + 0.025 * light) / (i + 1) * tint.a
		canvas.draw_texture_rect(
			texture, Rect2(box.position + back, box.size), false, Color(0.7, 0.95, 1.0, alpha)
		)
	for id: String in ["refrigeracion", "disipacion"]:
		var level := _level(levels, id)
		if level <= 0:
			continue
		var tone := COLD if id == "refrigeracion" else HOT
		var pulse := 0.75 + 0.25 * sin(time * (2.0 + 0.2 * level))
		var glow := Color(tone.r * 2.0, tone.g * 2.0, tone.b * 2.0, (0.1 + 0.035 * level) * pulse)
		glow.a *= tint.a
		_ring(canvas, texture, box, 1.2 + 0.2 * level, glow)
	var thick := _level(levels, "grosor")
	if thick > 0:
		# El grosor: la silueta engorda con tinta y, desde el 4, un canto de
		# placa entre la tinta y la pieza.
		var width := 0.6 + 0.34 * thick
		_ring(canvas, texture, box, width, Color(INK, tint.a))
		if thick >= 4:
			_ring(canvas, texture, box, width * 0.55, Color(0.36, 0.41, 0.5, tint.a))


static func _over(
	canvas: CanvasItem,
	texture: Texture2D,
	box: Rect2,
	tip: Vector2,
	element: int,
	tint: Color,
	levels: Dictionary,
	time: float
) -> void:
	var metal := maxi(_level(levels, "material"), _level(levels, "aleacion"))
	if metal > 0:
		# El brillo del metal la recorre despacio, mas ancho cuanto mejor.
		var period := 4.2 - 0.18 * metal
		var u := fposmod(time, period) / period * 1.6 - 0.3
		var shine := Color(1.7, 1.7, 1.8, (0.16 + 0.03 * metal) * tint.a)
		_band(canvas, texture, box, u, 0.06 + 0.012 * metal, shine)
	var edge := _level(levels, "filo")
	if edge > 0:
		_edge(canvas, texture, box, tip, edge, tint, time)
	var flow := _level(levels, "eficiencia")
	var veins := 1 + floori(flow / 3.0) if flow > 0 else 0
	for i in veins:
		# Vetas de energia que corren por la pieza.
		var v := fposmod(time * (0.25 + 0.04 * flow) + float(i) / veins, 1.0)
		var vein := Color(0.7, 1.7, 2.2, (0.22 + 0.045 * flow) * tint.a)
		_row(canvas, texture, box, v, 0.03 + 0.003 * flow, vein)
	_motes(canvas, box, _level(levels, "refrigeracion"), COLD, tint, time, -1.0)
	_motes(canvas, box, _level(levels, "disipacion"), HOT, tint, time, 1.0)
	var power := _level(levels, "potencia")
	if power > 0:
		_power(canvas, tip, power, POWER[clampi(element, 0, POWER.size() - 1)], tint, time)
	var aim := _level(levels, "precision")
	if aim > 0:
		_sight(canvas, tip, aim, tint)
	var core := _level(levels, "reactor")
	if core > 0:
		_core(canvas, box.position + box.size * Vector2(0.5, 0.42), core, tint, time)


## La silueta de la pieza repetida alrededor: un contorno de ese color.
static func _ring(
	canvas: CanvasItem, texture: Texture2D, box: Rect2, width: float, color: Color
) -> void:
	for dir in AROUND:
		canvas.draw_texture_rect(texture, Rect2(box.position + dir * width, box.size), false, color)


## Una franja vertical de la propia pieza, aclarada: solo brilla donde hay
## pieza. `u`: su centro de 0 (atras) a 1 (delante).
static func _band(
	canvas: CanvasItem, texture: Texture2D, box: Rect2, u: float, width: float, color: Color
) -> void:
	var from := clampf(u - width * 0.5, 0.0, 1.0)
	var to := clampf(u + width * 0.5, 0.0, 1.0)
	if to <= from:
		return
	var source := texture.get_size()
	var src := Rect2(source.x * from, 0.0, source.x * (to - from), source.y)
	var dest := Rect2(
		box.position.x + box.size.x * from, box.position.y, box.size.x * (to - from), box.size.y
	)
	canvas.draw_texture_rect_region(texture, dest, src, color)


## Lo mismo en horizontal: `v` de 0 (arriba) a 1 (abajo).
static func _row(
	canvas: CanvasItem, texture: Texture2D, box: Rect2, v: float, height: float, color: Color
) -> void:
	var from := clampf(v - height * 0.5, 0.0, 1.0)
	var to := clampf(v + height * 0.5, 0.0, 1.0)
	if to <= from:
		return
	var source := texture.get_size()
	var src := Rect2(0.0, source.y * from, source.x, source.y * (to - from))
	var dest := Rect2(
		box.position.x, box.position.y + box.size.y * from, box.size.x, box.size.y * (to - from)
	)
	canvas.draw_texture_rect_region(texture, dest, src, color)


## El filo: un destello fino y rapido que la recorre hasta la punta, donde
## brilla una estrella (desde el 3 brilla siempre un poco).
static func _edge(
	canvas: CanvasItem,
	texture: Texture2D,
	box: Rect2,
	tip: Vector2,
	edge: int,
	tint: Color,
	time: float
) -> void:
	var period := 2.6 - 0.12 * edge
	var u := fposmod(time + 0.7, period) / period * 1.4 - 0.2
	var glint := Color(2.2, 2.3, 2.5, (0.35 + 0.05 * edge) * tint.a)
	_band(canvas, texture, box, u, 0.025 + 0.004 * edge, glint)
	var flare := clampf(1.0 - absf(u - 0.95) * 6.0, 0.0, 1.0)
	if edge >= 3:
		flare = maxf(flare, 0.3)
	if flare > 0.0:
		_star(canvas, tip, (2.5 + 0.9 * edge) * flare, Color(0.95, 1.0, 1.0, tint.a))


## Estrella de cuatro puntas con contorno de tinta.
static func _star(canvas: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var radius := size if i % 2 == 0 else size * 0.28
		points.append(at + Vector2.from_angle(i * TAU / 8.0 - PI / 2.0) * radius)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_colored_polygon(points, color)
	canvas.draw_polyline(outline, Color(INK, color.a * 0.8), 1.0)


## Escarcha (sube y va hacia atras) o brasas (suben): una por nivel.
static func _motes(
	canvas: CanvasItem, box: Rect2, level: int, tone: Color, tint: Color, time: float, drift: float
) -> void:
	for i in level:
		var seed_x := fposmod(i * 0.618, 1.0)
		var rise := fposmod(time * (14.0 + i * 1.7) + i * 13.0, box.size.y * 1.1)
		var at := Vector2(
			box.position.x + box.size.x * seed_x + drift * rise * 0.15, box.end.y - rise
		)
		var fade := 1.0 - rise / (box.size.y * 1.1)
		var size := 1.1 + 0.12 * level
		canvas.draw_circle(at, size + 0.8, Color(INK, 0.6 * fade * tint.a))
		canvas.draw_circle(at, size, Color(tone, fade * tint.a))


## La boca cargada de la potencia: crece y late con cada nivel; desde el 4
## le giran chispas, desde el 7 un anillo y al 10 suelta rayos.
static func _power(
	canvas: CanvasItem, tip: Vector2, power: int, tone: Color, tint: Color, time: float
) -> void:
	var pulse := 0.8 + 0.2 * sin(time * (4.0 + 0.3 * power))
	var radius := (1.6 + 0.62 * power) * pulse
	canvas.draw_circle(tip, radius + 1.3, Color(INK, 0.75 * tint.a))
	canvas.draw_circle(tip, radius, Color(tone, 0.9 * tint.a))
	canvas.draw_circle(tip, radius * 0.5, Color(1.0, 0.97, 0.88, tint.a))
	if power >= 4:
		var sparks := floori(power / 2.0)
		for i in sparks:
			var angle := time * 3.2 + i * TAU / sparks
			var at := tip + Vector2.from_angle(angle) * radius * 1.9
			var tail := at - Vector2.from_angle(angle + 0.6) * 2.4
			canvas.draw_line(tail, at, Color(INK, 0.7 * tint.a), 2.2)
			canvas.draw_line(tail, at, Color(tone, tint.a), 1.1)
	if power >= 7:
		var spin := time * 1.8
		for i in 3:
			var start := spin + i * TAU / 3.0
			canvas.draw_arc(
				tip, radius * 2.5, start, start + 1.3, 10, Color(INK, 0.6 * tint.a), 2.4
			)
			canvas.draw_arc(
				tip, radius * 2.5, start, start + 1.3, 10, Color(tone, 0.85 * tint.a), 1.2
			)
	if power >= 10:
		_bolts(canvas, tip, radius * 3.2, tone, tint, time)


## Rayos cortos y quebrados que cambian diez veces por segundo.
static func _bolts(
	canvas: CanvasItem, at: Vector2, reach: float, tone: Color, tint: Color, time: float
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(time * 10.0)
	for i in 3:
		var angle := rng.randf() * TAU
		var points := PackedVector2Array([at])
		for step in 3:
			var along := reach * (step + 1) / 3.0
			var side := rng.randf_range(-0.35, 0.35)
			points.append(at + Vector2.from_angle(angle + side) * along)
		canvas.draw_polyline(points, Color(INK, 0.7 * tint.a), 2.4)
		canvas.draw_polyline(points, Color(tone.lightened(0.4), tint.a), 1.0)


## La mira de la precision: un haz hacia delante que se alarga con cada
## nivel; desde el 5, una reticula al final y, desde el 8, un segundo haz.
static func _sight(canvas: CanvasItem, tip: Vector2, aim: int, tint: Color) -> void:
	var length := 10.0 + 7.0 * aim
	var end := tip + Vector2(length, 0.0)
	var beams: Array[float] = [0.0]
	if aim >= 8:
		beams = [-1.2, 1.2]
	for lift in beams:
		var shift := Vector2(0.0, lift)
		canvas.draw_line(tip + shift, end + shift, Color(INK, 0.45 * tint.a), 2.4)
		canvas.draw_line(tip + shift, end + shift, Color(LASER, (0.4 + 0.05 * aim) * tint.a), 1.0)
	canvas.draw_circle(end, 1.6 + 0.12 * aim, Color(LASER, tint.a))
	if aim >= 5:
		var radius := 3.0 + 0.45 * aim
		canvas.draw_arc(end, radius, 0.0, TAU, 20, Color(INK, 0.6 * tint.a), 2.2)
		canvas.draw_arc(end, radius, 0.0, TAU, 20, Color(LASER, 0.85 * tint.a), 1.0)


## El nucleo del reactor en el pecho del torso: late, desde el 4 lo rodean
## dos arcos que giran y desde el 8 suelta rayos.
static func _core(canvas: CanvasItem, at: Vector2, core: int, tint: Color, time: float) -> void:
	var pulse := 0.75 + 0.25 * sin(time * (2.5 + 0.25 * core))
	var radius := (2.5 + 1.0 * core) * pulse
	canvas.draw_circle(at, radius + 1.5, Color(INK, 0.7 * tint.a))
	canvas.draw_circle(at, radius, Color(CORE, 0.75 * tint.a))
	canvas.draw_circle(at, radius * 0.4, Color(0.95, 0.92, 1.0, tint.a))
	if core >= 4:
		var spin := time * 2.2
		for i in 2:
			var start := spin + i * PI
			canvas.draw_arc(at, radius * 1.8, start, start + 1.6, 12, Color(INK, 0.6 * tint.a), 2.6)
			canvas.draw_arc(
				at, radius * 1.8, start, start + 1.6, 12, Color(CORE, 0.9 * tint.a), 1.3
			)
	if core >= 8:
		_bolts(canvas, at, radius * 2.6, CORE, tint, time)
