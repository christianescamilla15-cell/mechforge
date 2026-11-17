class_name LegRig
extends RefCounted
## Esqueleto 2D de unas piernas dibujadas de una pieza y vistas de lado: tres
## tramos (muslo, espinilla y pie) que giran sobre la cadera, la rodilla y el
## tobillo. El dibujo se reparte en una malla de franjas; cerca de cada
## articulacion las franjas mezclan el giro del tramo de arriba con el de
## abajo, asi que la pierna se dobla sin cortes. Con eso el mismo dibujo anda,
## se agacha, aguanta un empujon y recoge las piernas al volar.

## Alturas de las articulaciones, en fraccion de la altura del dibujo.
const KNEE := 0.46
const ANKLE := 0.8
## Franjas de la malla y ancho de la zona en que se mezclan dos tramos, en
## fraccion de la altura del dibujo.
const ROWS := 24
const BLEND := 0.05

static var _cache: Dictionary = {}

## Tamano del dibujo y articulaciones, en pixeles del dibujo.
var size := Vector2.ZERO
var hip := Vector2.ZERO
var knee := Vector2.ZERO
var ankle := Vector2.ZERO
## Punto mas bajo del pie, en el centro de la suela.
var sole := Vector2.ZERO


## Esqueleto de un dibujo de piernas; `hip_anchor` es la cintura (del JSON de
## anclas). Se calcula una vez por dibujo.
static func for_texture(texture: Texture2D, hip_anchor: Vector2) -> LegRig:
	var key := "%s|%s" % [texture.resource_path, hip_anchor]
	if _cache.has(key):
		return _cache[key]
	var rig := LegRig.new()
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	rig.size = Vector2(image.get_width(), image.get_height())
	rig.hip = hip_anchor
	rig.knee = Vector2(_center_x(image, rig.size.y * KNEE), rig.size.y * KNEE)
	rig.ankle = Vector2(_center_x(image, rig.size.y * ANKLE), rig.size.y * ANKLE)
	rig.sole = Vector2(_center_x(image, rig.size.y - 3.0), rig.size.y)
	_cache[key] = rig
	return rig


## Centro de la parte opaca de unas filas del dibujo.
static func _center_x(image: Image, row: float) -> float:
	var total := 0.0
	var count := 0
	for y in range(int(row) - 2, int(row) + 3):
		if y < 0 or y >= image.get_height():
			continue
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.3:
				total += x
				count += 1
	return total / count if count > 0 else image.get_width() / 2.0


## Dibuja la pierna con una pose: angulos en radianes del muslo (sobre la
## cadera), la espinilla (sobre la rodilla, relativo al muslo) y el pie (sobre
## el tobillo, relativo a la espinilla). `origin` es donde va la esquina de
## arriba a la izquierda del dibujo y `unit`, las unidades por pixel.
func draw(
	canvas: CanvasItem, texture: Texture2D, origin: Vector2, unit: float, pose: Vector3, tint: Color
) -> void:
	var transforms := _transforms(origin, unit, pose)
	var colors := PackedColorArray([tint, tint, tint, tint])
	var previous := _row(origin, unit, transforms, 0.0)
	for row in range(1, ROWS + 1):
		var y := size.y * row / ROWS
		var current := _row(origin, unit, transforms, y)
		var v0 := (y - size.y / ROWS) / size.y
		var v1 := y / size.y
		# Cuadrilatero sin triangular: aguanta franjas muy dobladas.
		canvas.draw_primitive(
			PackedVector2Array([previous[0], previous[1], current[1], current[0]]),
			colors,
			PackedVector2Array(
				[Vector2(0.0, v0), Vector2(1.0, v0), Vector2(1.0, v1), Vector2(0.0, v1)]
			),
			texture
		)
		previous = current
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Bordes izquierdo y derecho de una fila del dibujo, ya doblados.
func _row(origin: Vector2, unit: float, transforms: Array[Transform2D], y: float) -> Array[Vector2]:
	var left := origin + Vector2(0.0, y) * unit
	var right := origin + Vector2(size.x, y) * unit
	return [_bend(left, y, transforms), _bend(right, y, transforms)]


## Un punto del dibujo a la altura `y`, movido por los tramos que le tocan.
func _bend(point: Vector2, y: float, transforms: Array[Transform2D]) -> Vector2:
	var band := size.y * BLEND
	var to_shin := smoothstep(knee.y - band, knee.y + band, y)
	var to_foot := smoothstep(ankle.y - band, ankle.y + band, y)
	var upper: Vector2 = (transforms[0] * point).lerp(transforms[1] * point, to_shin)
	return upper.lerp(transforms[2] * point, to_foot)


## Punto de la suela con esa pose, en las coordenadas del lienzo.
func sole_point(origin: Vector2, unit: float, pose: Vector3) -> Vector2:
	return _transforms(origin, unit, pose)[2] * (origin + sole * unit)


## Transformaciones de muslo, espinilla y pie.
func _transforms(origin: Vector2, unit: float, pose: Vector3) -> Array[Transform2D]:
	var thigh := _about(origin + hip * unit, pose.x)
	var shin := thigh * _about(origin + knee * unit, pose.y)
	var foot := shin * _about(origin + ankle * unit, pose.z)
	return [thigh, shin, foot]


static func _about(point: Vector2, angle: float) -> Transform2D:
	return Transform2D(0.0, point) * Transform2D(angle, Vector2.ZERO) * Transform2D(0.0, -point)
