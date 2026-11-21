class_name PartIcon
extends Control
## Miniatura de una pieza con profundidad: su dibujo con sombra proyectada y
## un reflejo en la parte de arriba, ajustado sin deformarlo. Las piezas sin
## dibujo propio (modulos, especiales, armas del asistente) salen como su
## cartucho (PartGlyph). `paint` lo pinta en cualquier lienzo, sin nodo.

## Color de cada clase de pieza, de Basica a Unica.
const TIER_COLORS: Array[Color] = [
	Color("8a94a3"),
	Color("5fd07a"),
	Color("4aa8ff"),
	Color("b77bff"),
	Color("ffae3d"),
	Color("ff5a6e")
]

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## La pieza: si no hay `texture`, se pinta la suya.
var item: ItemDef:
	set(value):
		item = value
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
	var rect := Rect2(Vector2.ZERO, size)
	if texture != null:
		paint_texture(self, rect, texture, alpha)
	else:
		paint(self, rect, item, alpha)


## Pinta una pieza centrada en `rect` de un lienzo: su dibujo o su cartucho.
## `tint` la colorea (los hologramas de la tienda). False si no hay nada
## que pintar.
static func paint(
	c: CanvasItem, rect: Rect2, def: ItemDef, p_alpha: float = 1.0, tint: Color = Color.WHITE
) -> bool:
	if def == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	var drawing := MechSprites.icon_for(def)
	if drawing != null:
		paint_texture(c, rect, drawing, p_alpha, tint)
		return true
	if PartGlyph.has(def):
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		PartGlyph.draw(c, rect, def, p_alpha)
		if tint != Color.WHITE:
			# El cartucho no se tine: un velo del color lo deja en holograma.
			c.draw_rect(rect, Color(tint, 0.16 * p_alpha))
		return true
	return false


static func paint_texture(
	c: CanvasItem, rect: Rect2, drawing: Texture2D, p_alpha: float = 1.0, tint: Color = Color.WHITE
) -> void:
	if drawing == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tex_size := drawing.get_size()
	var fit := minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y) * 0.92
	var drawn := tex_size * fit
	var at := Rect2(rect.position + (rect.size - drawn) / 2.0, drawn)
	var drop := maxf(2.0, drawn.y * 0.05)
	c.draw_texture_rect(
		drawing,
		Rect2(at.position + Vector2(drop * 0.6, drop), at.size),
		false,
		Color(0, 0, 0, 0.5 * p_alpha)
	)
	c.draw_texture_rect(drawing, at, false, Color(tint, p_alpha))
	# Reflejo: la mitad de arriba un poco mas clara.
	var shine := Rect2(at.position, Vector2(at.size.x, at.size.y * 0.45))
	c.draw_texture_rect_region(
		drawing,
		shine,
		Rect2(Vector2.ZERO, Vector2(tex_size.x, tex_size.y * 0.45)),
		Color(1.25, 1.25, 1.3, 0.18 * p_alpha)
	)


## Lo que se ve bajo el raton mientras se arrastra una pieza: su dibujo.
static func drag_preview(def: ItemDef) -> Control:
	var holder := Control.new()
	var icon := PartIcon.new()
	icon.item = def
	icon.size = Vector2(110, 80)
	icon.position = Vector2(-55, -40)
	icon.alpha = 0.9
	holder.add_child(icon)
	return holder
