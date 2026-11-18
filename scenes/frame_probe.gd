class_name FrameProbe
extends Node
## Mide los cuadros de una prueba en vivo (tools/fps.ps1): FPS medio, el 1 %
## mas lento, el peor cuadro y cuantos pasan de 20 ms (se notan como tiron a
## 60 FPS). Solo para medir: el juego normal no lo crea.

## Un cuadro de mas de esto se nota como tiron a 60 FPS.
const HITCH_SECONDS := 0.020
## Los primeros cuadros cargan texturas y no cuentan.
const WARMUP_FRAMES := 30

var _deltas: PackedFloat32Array = []
var _skip: int = WARMUP_FRAMES


func _process(delta: float) -> void:
	if _skip > 0:
		_skip -= 1
		return
	_deltas.append(delta)


## Resumen en una linea.
func summary() -> String:
	if _deltas.is_empty():
		return "sin cuadros"
	var sorted := _deltas.duplicate()
	sorted.sort()
	var count := sorted.size()
	var total := 0.0
	var hitches := 0
	for delta in sorted:
		total += delta
		if delta > HITCH_SECONDS:
			hitches += 1
	var slowest := sorted.slice(mini(count - 1, int(count * 0.99)))
	var slow_total := 0.0
	for delta in slowest:
		slow_total += delta
	return (
		(
			"%d cuadros en %.1f s: FPS medio %.1f, 1 %% mas lento %.1f FPS, "
			+ "peor cuadro %.1f ms, tirones de mas de 20 ms: %d"
		)
		% [
			count,
			total,
			count / total,
			slowest.size() / slow_total,
			sorted[count - 1] * 1000.0,
			hitches,
		]
	)
