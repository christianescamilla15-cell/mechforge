class_name MechWear
extends RefCounted
## Estado del robot a la vista (pedido del usuario, 2026-11-18): conforme baja
## la vida aparecen aranazos; despues hollin y humo; con muy poca vida, humo
## negro, chispas y llamas. Con poca energia saltan arcos electricos y las
## luces parpadean. Los efectos de un critico tambien se ven: chispas en las
## piernas si esta inmovilizado.
##
## Todo se dibuja sin estado, a partir del tiempo y de una semilla del mech,
## sobre el lienzo del mech (MechView) y en sus coordenadas.

## Vida (parte de la maxima) por debajo de la que empieza cada etapa:
## aranazos, humo y fuego.
const SCRATCHES_BELOW := 0.75
const SMOKE_BELOW := 0.5
const FIRE_BELOW := 0.25
## Energia (parte de la capacidad) por debajo de la que fallan los sistemas.
const LOW_ENERGY_BELOW := 0.25
const SCRATCH_DARK := Color(0.07, 0.07, 0.09, 0.8)
const SCRATCH_SHINE := Color(0.93, 0.93, 0.96, 0.6)
const SOOT := Color(0.04, 0.04, 0.05, 0.42)
const FLAME_OUTER := Color(1.0, 0.42, 0.08, 0.9)
const FLAME_INNER := Color(1.0, 0.86, 0.35, 0.95)
const ARC := Color(0.6, 0.92, 1.0)


## Etapa de dano por la vida: 0 intacto, 1 aranazos, 2 humo, 3 fuego.
static func stage(health_ratio: float) -> int:
	if health_ratio < FIRE_BELOW:
		return 3
	if health_ratio < SMOKE_BELOW:
		return 2
	if health_ratio < SCRATCHES_BELOW:
		return 1
	return 0


## Aranazos y hollin sobre el torso. `torso` es el rectangulo del dibujo del
## torso; las marcas van en su parte alta, donde no las tapan las armas.
static func draw_marks(canvas: CanvasItem, torso: Rect2, health_ratio: float, salt: int) -> void:
	var level := stage(health_ratio)
	if level == 0 or torso.size == Vector2.ZERO:
		return
	if level >= 2:
		for i in 2 * (level - 1):
			var at := _inside(torso, salt, 40 + i)
			var radius := lerpf(14.0, 26.0, _noise(salt, 60 + i))
			canvas.draw_circle(at, radius, SOOT)
	for i in [0, 3, 6, 9][level]:
		var center := _inside(torso, salt, i)
		var angle := lerpf(-0.9, 0.9, _noise(salt, 20 + i))
		var half := Vector2.from_angle(angle) * lerpf(12.0, 22.0, _noise(salt, 30 + i))
		canvas.draw_line(center - half, center + half, SCRATCH_DARK, 4.5, true)
		var shine := Vector2(0.0, -2.2)
		canvas.draw_line(center - half + shine, center + half + shine, SCRATCH_SHINE, 1.8, true)


## Humo que sube del torso hacia atras (el mech mira a +x), y con muy poca
## vida, llamas y chispas.
static func draw_smoke_and_fire(
	canvas: CanvasItem, torso: Rect2, health_ratio: float, time: float, salt: int
) -> void:
	var level := stage(health_ratio)
	if level < 2 or torso.size == Vector2.ZERO:
		return
	var vents: Array[Vector2] = [
		torso.position + torso.size * Vector2(0.38, 0.22),
		torso.position + torso.size * Vector2(0.6, 0.34),
	]
	var heavy := level >= 3
	var shade := 0.2 if heavy else 0.62
	var puffs := 9 if heavy else 7
	for v in vents.size():
		for i in puffs:
			var phase := fposmod(time * 0.42 + (i + 0.5 * v) / puffs, 1.0)
			var sway := sin(time * 1.4 + i * 1.7 + v) * 6.0
			var drift := Vector2(-42.0 * phase + sway, -120.0 * phase)
			var radius := lerpf(6.0, 26.0, phase) * (1.35 if heavy else 1.1)
			var alpha := (0.5 if heavy else 0.48) * (1.0 - phase)
			canvas.draw_circle(vents[v] + drift, radius, Color(shade, shade, shade + 0.02, alpha))
	if not heavy:
		return
	_flames(canvas, vents[0] + Vector2(4.0, 6.0), time, 1.0)
	_flames(canvas, vents[1] + Vector2(-2.0, 8.0), time + 0.37, 0.75)
	_sparks(canvas, vents[1], time, salt)


## Arcos electricos alrededor del torso cuando le queda poca energia.
static func draw_low_energy(
	canvas: CanvasItem, torso: Rect2, energy_ratio: float, time: float, salt: int
) -> void:
	if energy_ratio >= LOW_ENERGY_BELOW or torso.size == Vector2.ZERO:
		return
	var tick := floori(time * 8.0)
	# Salta a ratos, no todo el tiempo.
	if _noise(salt + tick, 1) > 0.6:
		return
	for arc in 2:
		var from := _inside(torso, salt + tick * 3, 70 + arc)
		var to := _inside(torso, salt + tick * 5, 80 + arc)
		_zigzag(canvas, from, to, salt + tick * 7 + arc)


## Cuanto brillan las luces del mech: parpadean cuando le queda poca energia.
static func energy_flicker(energy_ratio: float, time: float, salt: int) -> float:
	if energy_ratio >= LOW_ENERGY_BELOW:
		return 1.0
	var tick := floori(time * 10.0)
	return 0.72 if _noise(salt + tick, 2) < 0.3 else 1.0


## Chispas en las piernas: el mech esta inmovilizado por un critico.
static func draw_stuck(canvas: CanvasItem, knee: Vector2, time: float, salt: int) -> void:
	var tick := floori(time * 9.0)
	for side in 2:
		var from := (
			knee + Vector2(-26.0 + 52.0 * side, -10.0 + 20.0 * _noise(salt + tick, 3 + side))
		)
		var to := knee + Vector2(-10.0 + 20.0 * side, 30.0 * _noise(salt + tick, 5 + side))
		_zigzag(canvas, from, to, salt + tick * 11 + side)


## Volutas de humo que salen de un arma inutilizada.
static func draw_broken_weapon(canvas: CanvasItem, at: Vector2, time: float) -> void:
	for i in 4:
		var phase := fposmod(time * 0.6 + i / 4.0, 1.0)
		var drift := Vector2(-18.0 * phase, -54.0 * phase)
		var puff := Color(0.25, 0.25, 0.27, 0.6 * (1.0 - phase))
		canvas.draw_circle(at + drift, lerpf(5.0, 16.0, phase), puff)


static func _flames(canvas: CanvasItem, base: Vector2, time: float, size: float) -> void:
	for j in 3:
		var flick := 0.7 + 0.3 * sin(time * 21.0 + j * 2.3)
		var foot := base + Vector2((j - 1) * 8.0 * size, 0.0)
		var height := (16.0 + 7.0 * float(j % 2)) * flick * size
		var width := 7.0 * size
		var outer := PackedVector2Array(
			[
				foot + Vector2(-width, 0.0),
				foot + Vector2(0.0, -height),
				foot + Vector2(width, 0.0),
				foot + Vector2(0.0, 5.0 * size),
			]
		)
		canvas.draw_colored_polygon(outer, FLAME_OUTER)
		var inner := PackedVector2Array(
			[
				foot + Vector2(-width * 0.5, 0.0),
				foot + Vector2(0.0, -height * 0.6),
				foot + Vector2(width * 0.5, 0.0),
				foot + Vector2(0.0, 3.0 * size),
			]
		)
		canvas.draw_colored_polygon(inner, FLAME_INNER)


static func _sparks(canvas: CanvasItem, at: Vector2, time: float, salt: int) -> void:
	var tick := floori(time * 6.0)
	var t := fposmod(time * 6.0, 1.0)
	for i in 4:
		var direction := Vector2.from_angle(-PI * _noise(salt + tick, 90 + i))
		var head := at + direction * (8.0 + 34.0 * t)
		canvas.draw_line(head - direction * 6.0, head, Color(1.0, 0.85, 0.45, 1.0 - t), 2.0, true)


static func _zigzag(canvas: CanvasItem, from: Vector2, to: Vector2, salt: int) -> void:
	var n := (to - from).normalized().orthogonal()
	var points := PackedVector2Array([from])
	for k in range(1, 6):
		var along := from.lerp(to, k / 6.0)
		points.append(along + n * (_noise(salt, k) - 0.5) * 18.0)
	points.append(to)
	canvas.draw_polyline(points, Color(ARC.r, ARC.g, ARC.b, 0.3), 6.0, true)
	canvas.draw_polyline(points, ARC, 2.0, true)


## Punto de la parte alta del torso (hombros y pecho), fijo para cada
## semilla e indice. El centro no: lo tapan las armas del brazo.
static func _inside(torso: Rect2, salt: int, index: int) -> Vector2:
	var x := lerpf(0.28, 0.74, _noise(salt, index * 2 + 101))
	var y := lerpf(0.1, 0.42, _noise(salt, index * 2 + 102))
	return torso.position + torso.size * Vector2(x, y)


static func _noise(salt: int, index: int) -> float:
	return fposmod(sin(salt * 0.0137 + index * 12.9898) * 43758.5453, 1.0)
