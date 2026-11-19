class_name TechStyle
extends StyleBox
## Panel con relieve para toda la interfaz (pedido del usuario el 2026-11-18:
## "cada pieza con especial detalle y profundidad", nada plano). Dibuja una
## placa de metal: sombra proyectada, esquinas en chaflan, degradado de luz
## de arriba abajo, bisel claro arriba y oscuro abajo, una ranura de panel,
## tornillos en las esquinas, un borde de color (la clase de la pieza, la
## seleccion) y, si se pide, un brillo alrededor. Sirve para paneles,
## huecos, tarjetas y botones (con una variante por estado).

## Color de la placa (la parte de arriba sale mas clara y la de abajo mas
## oscura).
var base := Color("1b2534")
## Borde de color.
var accent := Color("4f6380")
var accent_width := 2.0
## Tamano del chaflan de las esquinas.
var chamfer := 9.0
## Brillo alrededor (0 = nada; 1 = fuerte), del color del borde.
var glow := 0.0
var shadow := 5.0
var bolts := true
## Ranura horizontal que cruza la placa (solo en placas altas).
var groove := true
## Hundido (boton pulsado): el bisel se invierte y la luz baja.
var sunken := false


## Una placa con estos colores y margenes de contenido.
static func plate(
	p_base: Color, p_accent: Color, margin: float = 8.0, p_chamfer: float = 9.0
) -> TechStyle:
	var style := TechStyle.new()
	style.base = p_base
	style.accent = p_accent
	style.chamfer = p_chamfer
	style.set_content_margin_all(margin)
	return style


## Estilos de un boton (normal, encima, pulsado, desactivado) aplicados a el.
static func dress_button(button: BaseButton, p_accent: Color = Color("5f7fa6")) -> void:
	var normal := plate(Color("223047"), p_accent, 6.0, 6.0)
	normal.bolts = false
	normal.groove = false
	var hover := plate(Color("2a3b57"), p_accent.lightened(0.3), 6.0, 6.0)
	hover.bolts = false
	hover.groove = false
	hover.glow = 0.35
	var pressed := plate(Color("17202f"), p_accent, 6.0, 6.0)
	pressed.bolts = false
	pressed.groove = false
	pressed.sunken = true
	var off := plate(Color("1a212c"), Color("33404f"), 6.0, 6.0)
	off.bolts = false
	off.groove = false
	off.shadow = 1.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", off)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _outline(rect: Rect2, cut: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	cut = minf(cut, minf(rect.size.x, rect.size.y) * 0.3)
	return PackedVector2Array(
		[
			Vector2(p.x + cut, p.y),
			Vector2(e.x - cut, p.y),
			Vector2(e.x, p.y + cut),
			Vector2(e.x, e.y - cut),
			Vector2(e.x - cut, e.y),
			Vector2(p.x + cut, e.y),
			Vector2(p.x, e.y - cut),
			Vector2(p.x, p.y + cut),
		]
	)


func _draw(item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	# Brillo alrededor: varios contornos que se desvanecen hacia fuera.
	if glow > 0.0:
		for i in 4:
			var grown := _outline(rect.grow(2.0 + i * 2.5), chamfer + i * 2.0)
			grown.append(grown[0])
			var color := Color(accent, glow * (0.32 - i * 0.07))
			rs.canvas_item_add_polyline(item, grown, PackedColorArray([color]), 2.5, true)
	# Sombra proyectada abajo a la derecha.
	if shadow > 0.0:
		var drop := _outline(Rect2(rect.position + Vector2(2, shadow * 0.7), rect.size), chamfer)
		rs.canvas_item_add_polygon(item, drop, PackedColorArray([Color(0, 0, 0, 0.45)]))
	# Placa con degradado: los vertices de arriba claros, los de abajo oscuros.
	var shape := _outline(rect, chamfer)
	var top := base.lightened(0.05 if sunken else 0.16)
	var bottom := base.darkened(0.05 if sunken else 0.32)
	var colors := PackedColorArray()
	for point in shape:
		var t := (point.y - rect.position.y) / maxf(rect.size.y, 1.0)
		colors.append(top.lerp(bottom, t))
	rs.canvas_item_add_polygon(item, shape, colors)
	# Bisel: luz arriba e izquierda, sombra abajo y derecha (al reves si se
	# hunde).
	var inner := _outline(rect.grow(-accent_width - 1.0), maxf(chamfer - 2.0, 0.0))
	var light := Color(1, 1, 1, 0.16 if not sunken else 0.05)
	var dark := Color(0, 0, 0, 0.45 if not sunken else 0.2)
	if sunken:
		var swap := light
		light = dark
		dark = swap
	var lit := PackedVector2Array([inner[7], inner[0], inner[1], inner[2]])
	rs.canvas_item_add_polyline(item, lit, PackedColorArray([light]), 1.5, true)
	var shade := PackedVector2Array([inner[3], inner[4], inner[5], inner[6]])
	rs.canvas_item_add_polyline(item, shade, PackedColorArray([dark]), 1.5, true)
	# Ranura de panel a un tercio de la altura, con su linea de luz debajo.
	if groove and rect.size.y > 70.0:
		var y := rect.position.y + rect.size.y * 0.34
		var x0 := rect.position.x + chamfer + 4.0
		var x1 := rect.end.x - chamfer - 4.0
		rs.canvas_item_add_line(item, Vector2(x0, y), Vector2(x1, y), Color(0, 0, 0, 0.35), 1.0)
		rs.canvas_item_add_line(
			item, Vector2(x0, y + 1.0), Vector2(x1, y + 1.0), Color(1, 1, 1, 0.06), 1.0
		)
	# Borde de color.
	var edge := shape.duplicate()
	edge.append(edge[0])
	rs.canvas_item_add_polyline(item, edge, PackedColorArray([accent]), accent_width, true)
	# Tornillos: anillo oscuro, cabeza y un punto de luz.
	if bolts and rect.size.x > 60.0 and rect.size.y > 40.0:
		var inset := chamfer * 0.55 + 6.0
		for corner in [
			rect.position + Vector2(inset, inset),
			Vector2(rect.end.x - inset, rect.position.y + inset),
			Vector2(rect.position.x + inset, rect.end.y - inset),
			rect.end - Vector2(inset, inset),
		]:
			rs.canvas_item_add_circle(item, corner, 2.6, Color(0, 0, 0, 0.55))
			rs.canvas_item_add_circle(item, corner, 1.9, base.lightened(0.35))
			rs.canvas_item_add_circle(item, corner + Vector2(-0.6, -0.6), 0.8, Color(1, 1, 1, 0.5))
