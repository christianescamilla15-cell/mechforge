class_name PlasmaMantle
extends Node2D
## El manto de plasma de un jefe (OBS-041, del usuario: "un escudo es como
## una capa de ozono... una vez que se vence esa resistencia ya se acabo"):
## un campo que envuelve al robot mientras le queda capa. Se va apagando al
## gastarse y estalla al romperse. Cuelga del MechView, con sus pies en el
## origen; solo dibuja.

const COLOR := Color("7fe8ff")
const EDGE := Color("d9fbff")
const POINTS := 40
const BURST_SECONDS := 0.7

## Lo que le queda de capa, de 0 a 1.
var share := 0.0:
	set(value):
		share = clampf(value, 0.0, 1.0)
		queue_redraw()
## Alto del cuerpo que envuelve, en unidades del robot.
var height := 220.0:
	set(value):
		height = maxf(value, 40.0)
		queue_redraw()

var _time := 0.0
var _burst := 0.0


func _process(delta: float) -> void:
	_time += delta
	if share > 0.0 or _burst > 0.0:
		queue_redraw()


## Se rompe: un estallido que se abre y se apaga.
func burst() -> void:
	var tween := create_tween()
	tween.tween_property(self, "_burst", 0.0, BURST_SECONDS).from(1.0)


func _draw() -> void:
	var center := Vector2(0.0, -height * 0.5)
	var radii := Vector2(height * 0.46, height * 0.6)
	if share > 0.0:
		# Capas tenues hacia dentro: un campo, no una pared.
		for i in 4:
			var shrink := 1.0 - 0.08 * i
			var glow := (0.035 + 0.02 * i) * (0.35 + 0.65 * share)
			draw_colored_polygon(_ellipse(center, radii * shrink, 0.0), Color(COLOR, glow))
		# El borde tiembla y late mas despacio cuanto mas gastado esta.
		var pulse := 0.55 + 0.25 * sin(_time * (2.0 + 3.0 * share))
		var rim := _ellipse(center, radii, 3.0 * sin(_time * 4.0))
		rim.append(rim[0])
		draw_polyline(rim, Color(EDGE, pulse * (0.25 + 0.6 * share)), 1.6, true)
		# Vetas de plasma que lo recorren.
		for i in 3:
			var start := fposmod(_time * (0.6 + 0.25 * i) + i * 2.1, TAU)
			draw_arc(
				center,
				radii.x * (0.98 - 0.05 * i),
				start,
				start + 0.9,
				12,
				Color(COLOR, 0.5 * share),
				1.2,
				true
			)
	if _burst > 0.0:
		var grow := 1.0 + (1.0 - _burst) * 0.6
		var ring := _ellipse(center, radii * grow, 0.0)
		ring.append(ring[0])
		draw_polyline(ring, Color(EDGE, _burst), 3.0, true)
		draw_colored_polygon(_ellipse(center, radii * grow, 0.0), Color(COLOR, 0.18 * _burst))


func _ellipse(center: Vector2, radii: Vector2, wobble: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in POINTS:
		var angle := TAU * i / POINTS
		var bend := 1.0 + wobble * 0.004 * sin(angle * 5.0 + _time * 3.0)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * bend)
	return points
