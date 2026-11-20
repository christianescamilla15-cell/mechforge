class_name HangarBackdrop
extends Control
## Fondo de la base y del taller: el hangar con profundidad (HangarArt),
## oscurecido por `dim` para que el contenido de encima se lea bien.

## Cuanto se oscurece (0 = nada, 1 = negro).
var dim: float = 0.35
var _time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true


## Solo se pinta mientras se ve: el hangar y el combate lo tapan entero.
func set_shown(shown: bool) -> void:
	visible = shown
	set_process(shown)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var floor_y := size.y * 0.78
	HangarArt.draw_wall(self, rect, floor_y, 1.0)
	HangarArt.draw_gantry(self, rect, 1.0)
	HangarArt.draw_lamp(self, Vector2(size.x * 0.25, floor_y * 0.4), 1.2)
	HangarArt.draw_lamp(self, Vector2(size.x * 0.75, floor_y * 0.4), 1.2)
	HangarArt.draw_floor(self, rect, floor_y, Vector2(size.x * 0.5, floor_y - size.y * 0.8))
	HangarArt.draw_light(self, rect, size.x * 0.73, floor_y, _time)
	HangarArt.draw_vignette(self, rect, 1.5)
	draw_rect(rect, Color(0.02, 0.03, 0.05, dim))
