class_name HitJuice
extends RefCounted
## Lo que da peso a un golpe (OBS-052, del usuario: "juegos de hace 30 anos
## tenian efectos increibles visuales"; investigacion en
## docs/reference/efectos-combate.md). Los clasicos no lo sacaban de graficos
## pesados sino del ritmo: una pausa breve al golpear en la que se congela
## quien ataca mientras la victima tiembla, un destello de paleta (blanco y
## luego del color del golpe) y, en los golpes especiales, la pantalla que se
## oscurece un instante ("super flash").

const FRAME := 1.0 / 60.0
const SHADER := preload("res://scenes/battle/hit_flash.gdshader")
## Pausa al golpear, en cuadros a 60 por segundo: lo minimo, lo que suma la
## parte de la vida que quita (la mitad de la vida, +20) y el tope; el critico
## y el golpe final, aparte (los juegos de lucha van de 8 a 16 cuadros segun
## la fuerza; aqui, por turnos, algo menos).
const STOP_MIN := 3.0
const STOP_PER_SHARE := 40.0
const STOP_MAX := 12.0
const STOP_CRIT := 5.0
const STOP_KO := 20.0
## Cuadros del destello en blanco antes de pasar al color del golpe, y cuanto
## tine ese color (con 0.8 se perdia el dibujo de la pieza).
const WHITE_FRAMES := 2.0
const COLOR_FLASH := 0.55
## Lo que se oscurece la arena en el "super flash" y cuanto dura.
const DIM_ALPHA := 0.5
const DIM_FRAMES := 9.0


## Cuadros de pausa de un golpe que quita `share` de la vida maxima.
static func stop_frames(share: float, crit: bool) -> float:
	var frames := minf(STOP_MAX, STOP_MIN + STOP_PER_SHARE * maxf(share, 0.0))
	return frames + (STOP_CRIT if crit else 0.0)


## Segundos reales de una pausa de `frames` a la velocidad del combate (con
## velocidad 2 dura la mitad, nunca menos de 2 cuadros).
static func stop_seconds(frames: float, speed: float) -> float:
	return maxf(2.0, frames / maxf(speed, 1.0)) * FRAME


## El material de destello de un robot: se crea la primera vez.
static func flash_material(view: CanvasItem) -> ShaderMaterial:
	if not view.material is ShaderMaterial:
		var made := ShaderMaterial.new()
		made.shader = SHADER
		view.material = made
	return view.material as ShaderMaterial


## Destello de un golpe: blanco unos cuadros y luego del color del golpe,
## que se apaga en `seconds`.
static func flash(view: CanvasItem, color: Color, seconds: float) -> Tween:
	var made := flash_material(view)
	made.set_shader_parameter("flash_color", Color.WHITE)
	made.set_shader_parameter("flash", 1.0)
	var white := minf(WHITE_FRAMES * FRAME, seconds * 0.25)
	var tween := view.create_tween()
	tween.tween_interval(white)
	tween.tween_callback(made.set_shader_parameter.bind("flash_color", color.lightened(0.3)))
	var fade := func(value: float) -> void: made.set_shader_parameter("flash", value)
	tween.tween_method(fade, COLOR_FLASH, 0.0, maxf(seconds * 0.7 - white, FRAME))
	return tween


## Pausa al golpear: congela esos nodos (quien ataca, los disparos) y sus
## animaciones durante la pausa; lo demas sigue (la victima tiembla y la
## camara sacude). Vuelve al terminar.
static func hitstop(tree: SceneTree, frozen: Array[Node], seconds: float) -> void:
	var before: Array[Node.ProcessMode] = []
	for node in frozen:
		before.append(node.process_mode)
		node.process_mode = Node.PROCESS_MODE_DISABLED
	await tree.create_timer(seconds).timeout
	for i in frozen.size():
		if is_instance_valid(frozen[i]):
			frozen[i].process_mode = before[i]


## "Super flash": la arena se oscurece un instante por encima del mundo y por
## debajo de los avisos (`above`), y se aclara.
static func dim(arena: Control, above: Node, speed: float) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, DIM_ALPHA)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena.add_child(shade)
	arena.move_child(shade, above.get_index() + 1)
	var tween := shade.create_tween()
	tween.tween_property(shade, "color:a", 0.0, stop_seconds(DIM_FRAMES, speed))
	tween.tween_callback(shade.queue_free)
