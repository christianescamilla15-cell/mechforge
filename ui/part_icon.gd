class_name PartIcon
extends Control
## Miniatura de una pieza con profundidad: su dibujo con sombra proyectada y
## un reflejo en la parte de arriba, ajustado sin deformarlo. Sin dibujo no
## pinta nada.

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Transparencia (1 = normal); los huecos cerrados la bajan.
var alpha: float = 1.0:
	set(value):
		alpha = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var tex_size := texture.get_size()
	var fit := minf(size.x / tex_size.x, size.y / tex_size.y) * 0.92
	var drawn := tex_size * fit
	var rect := Rect2((size - drawn) / 2.0, drawn)
	var drop := maxf(2.0, drawn.y * 0.05)
	draw_texture_rect(
		texture,
		Rect2(rect.position + Vector2(drop * 0.6, drop), rect.size),
		false,
		Color(0, 0, 0, 0.5 * alpha)
	)
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))
	# Reflejo: la mitad de arriba un poco mas clara.
	var shine := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.45))
	draw_texture_rect_region(
		texture,
		shine,
		Rect2(Vector2.ZERO, Vector2(tex_size.x, tex_size.y * 0.45)),
		Color(1.25, 1.25, 1.3, 0.18 * alpha)
	)
