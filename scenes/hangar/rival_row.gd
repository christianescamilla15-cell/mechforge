class_name RivalRow
extends Node2D
## La fila de rivales del hangar (pedido del usuario el 2026-11-20: "que el
## menu y todo este mas integrado, casi como si no existiera un menu"). Es el
## cuadro de campana del juego original (tu mech a la izquierda y, enfrente,
## una fila de rivales: el siguiente iluminado y los de detras cada vez mas
## oscuros), pero dentro del hangar: cada rival es una proyeccion sobre su
## proyector del suelo, delante de tu robot. El primero se ve a plena luz y
## se pulsa para salir a combatir; los demas se pierden en la sombra. Al
## ganar, el vencido se apaga y la fila avanza un sitio.
##
## En la zona de combate (`ring`, OBS-048, del usuario: "ahora si ves a tus
## combatientes en tamano real... como un combate previo a la WWE") el que
## toca no es una proyeccion: sale de verdad, a tu tamano, andando desde el
## lado derecho bajo un foco que lo sigue; al llegar pisa fuerte, saltan
## chispas y su nombre se enciende en grande frente al tuyo, con un VS entre
## los dos. Los de detras siguen siendo proyecciones en la sombra.
##
## No decide nada: ensena lo que le da MissionBrief ("rivals") y HangarStage
## le dice donde esta el suelo y si el raton esta encima del primero.

## Sitios de la fila, de delante atras: centro (parte del ancho), cuanto sube
## del suelo, tamano respecto a tu robot, sombra y cuanto de luz de proyector.
const SLOT_X: Array[float] = [0.735, 0.85, 0.93, 0.992]
const SLOT_LIFT: Array[float] = [0.0, 9.0, 16.0, 22.0]
const SLOT_SCALE: Array[float] = [0.8, 0.66, 0.56, 0.48]
const SLOT_SHADE: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.42, 0.5, 0.64), Color(0.22, 0.27, 0.39), Color(0.11, 0.14, 0.22)
]
const SLOT_HOLO: Array[float] = [0.05, 0.3, 0.45, 0.6]
## Lo que avanza hacia la derecha cada sitio mas alla del ultimo.
const BEYOND_STEP := 0.07
const BEAM := Color(0.34, 0.83, 1.0)
const BOSS_BEAM := Color(1.0, 0.3, 0.24)
const GOLD := Color("ffe27a")
const BAD := Color("ff8a7a")
const TEXT := Color("d8f4ff")
## Ancho de un robot con sus armas, en unidades del dibujo, para el proyector
## y para cuando no se puede medir.
const MECH_WIDTH := 190.0
## Piezas que cuentan para lo que ocupa un rival (el asistente, que flota
## arriba y detras, no).
const BODY_SLOTS: Array[String] = ["top0", "side0", "side1", "chest", "torso", "legs"]
const ENTER_SECONDS := 0.36
const ENTER_STAGGER := 0.1
const BEATEN_HOLD := 0.35
const BEATEN_SECONDS := 0.5
const ADVANCE_SECONDS := 0.55
## La entrada en la zona de combate: su tamano (el de tu robot), lo que tarda
## en llegar andando, el destello al pisar y lo que tarda su nombre.
const RING_SCALE := 1.0
const WALK_SECONDS := 1.5
const BURST_SECONDS := 0.8
const TITLE_SECONDS := 0.5
const RING_ACCENT := Color("ff5a3c")
const TITLE_SIZE := 34
## Hueco entre tu nombre y el suyo, donde va el VS.
const VS_GAP := 76.0
const HOLO_SHADER := """
shader_type canvas_item;
// Una proyeccion: el dibujo tira al color del haz y lleva lineas de barrido.
uniform float holo : hint_range(0.0, 1.0) = 0.1;
uniform vec3 beam : source_color = vec3(0.34, 0.83, 1.0);
void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb = mix(c.rgb, beam * (0.3 + 0.95 * lum), holo);
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 1.3 - TIME * 5.0);
	c.rgb *= 1.0 - scan * (0.08 + 0.3 * holo);
	COLOR = c;
}
"""

static var _shader: Shader


## Un rival de la fila: sus datos, su dibujo y como va de encendido.
class Rival:
	extends RefCounted
	var info: Dictionary
	var view: MechView
	var material: ShaderMaterial
	## Sitio en la fila (0 = delante); con decimales mientras avanza.
	var depth := 0.0
	## Cuanto se ve: 0 apagado, 1 encendido.
	var alpha := 0.0
	## Barrido al encenderse: de 0 (en los pies) a 1 (ya paso).
	var scan := 1.0
	## Lo que mide de alto con su asistente, sin agrandar ni encoger.
	var height := 200.0
	## Como estaba la ultima vez que se coloco (para no recolocar lo quieto).
	var placed_depth := -1.0
	var placed_alpha := -1.0
	## En la zona de combate: llegando andando, su nombre (0 a 1) y el
	## destello de chispas al pisar (de 1 a 0).
	var entering := false
	var title := 1.0
	var burst := 0.0
	## Lo que su dibujo agranda por su cuenta (MechView.DRAW_SCALE y, si es
	## jefe, BOSS_SCALE): cuenta para que quepa bajo el monitor.
	var draw_factor := 1.0


## El raton esta sobre el primero.
var hover := false:
	set(value):
		if hover != value:
			hover = value
			if value and can_press():
				Sfx.play("ui_tic")
## El jefe ya se pulso una vez: falta la segunda.
var armed := false
## Lo que dice bajo el primero en vez de "combatir": por que no se puede.
var blocked := ""
## Aviso bajo el primero: lo que pasa si pierdes. En rojo si perder acaba
## la partida (`danger`); en dorado si una proteccion lo cubre.
var warning := ""
var danger := true
## Lo que dice al pulsarlo la primera vez ("" = lo de siempre).
var confirm_text := ""
## Hay que pulsar dos veces.
var confirm := false
var font: Font
## En la zona de combate (OBS-048): el que toca sale de verdad y no como
## proyeccion. Y los pies de tu robot, para el VS entre los dos nombres.
var ring := false
var player_feet := Vector2.ZERO
var player_name := ""

var _rivals: Array[Rival] = []
var _leaving: Array[Rival] = []
var _signature := ""
var _size := Vector2(1280, 720)
var _floor_y := 560.0
var _zoom := 1.0
## Hasta donde puede llegar la cabeza de un rival (el borde del monitor).
var _ceiling := 0.0
var _time := 0.0
var _back := Node2D.new()
var _shade := Node2D.new()
var _front := Node2D.new()
var _fx := Node2D.new()
var _tweens: Array[Tween] = []


func _ready() -> void:
	add_child(_back)
	add_child(_shade)
	add_child(_front)
	add_child(_fx)
	_shade.draw.connect(_draw_shade)
	_fx.draw.connect(_draw_fx)
	if font == null:
		font = ThemeDB.fallback_font


## Donde esta el suelo, a que tamano se ve tu robot y hasta donde puede
## subir un rival (`p_ceiling`, el borde de abajo del monitor).
func layout(p_size: Vector2, p_floor_y: float, p_zoom: float, p_ceiling: float = 0.0) -> void:
	_size = p_size
	_floor_y = p_floor_y
	_zoom = p_zoom
	_ceiling = p_ceiling
	for rival in _rivals + _leaving:
		rival.placed_depth = -1.0
	_place_all()


## Pone la fila. `how`: "enter" (se encienden uno tras otro), "advance" (el
## vencido, `beaten`, se apaga delante y los demas avanzan un sitio) o
## "none" (ya encendidos). Si la fila es la que ya habia, no se toca.
func show_rivals(rivals: Array[Dictionary], how: String = "enter", beaten: Dictionary = {}) -> void:
	var signature := _signature_of(rivals)
	if signature == _signature and how != "advance" and not _rivals.is_empty():
		for i in _rivals.size():
			_rivals[i].info = rivals[i]
		return
	_signature = signature
	armed = false
	_stop_tweens()
	var instant := how == "advance"
	for rival in _rivals:
		_retire(rival, 0.0 if instant else 0.16)
	_rivals.clear()
	var walkers: Array[Rival] = []
	for i in rivals.size():
		var rival := _make(rivals[i])
		_rivals.append(rival)
		rival.depth = float(i)
		if ring and i == 0 and how != "none":
			rival.alpha = 1.0
			rival.title = 0.0
			rival.entering = true
			walkers.append(rival)
			continue
		match how:
			"advance":
				rival.depth = float(i + 1)
				rival.alpha = 1.0 if i + 1 < SLOT_X.size() else 0.0
			"none":
				rival.alpha = 1.0
			_:
				rival.scan = 0.0
				var delay := 0.12 + ENTER_STAGGER * i
				_animate(rival, "alpha", 1.0, ENTER_SECONDS, delay)
				_animate(rival, "scan", 1.0, ENTER_SECONDS * 1.5, delay)
				Sfx.play("ui_tic", delay)
	if how == "advance":
		_advance(beaten)
	_place_all()
	var wait := BEATEN_HOLD + BEATEN_SECONDS * 0.7 if how == "advance" else 0.15
	for rival in walkers:
		_walk_in(rival, wait)


## Apaga la fila (al salir del modo mision).
func clear(seconds: float = 0.2) -> void:
	_signature = ""
	armed = false
	hover = false
	_stop_tweens()
	for rival in _rivals:
		_retire(rival, seconds)
	_rivals.clear()


## Al salir a combatir las proyecciones se cortan de golpe.
func collapse(seconds: float) -> void:
	_stop_tweens()
	for rival in _rivals:
		_animate(rival, "alpha", 0.0, seconds, 0.0)


func is_showing() -> bool:
	return not _rivals.is_empty()


## Lo que ocupa el primero de la fila (para el raton y las esquinas).
func front_rect() -> Rect2:
	if _rivals.is_empty():
		return Rect2()
	return _rect_of(_rivals[0])


func front_has_point(at: Vector2) -> bool:
	if _rivals.is_empty() or _rivals[0].entering:
		return false
	return _rivals[0].alpha > 0.5 and front_rect().has_point(at)


## True si pulsar al primero sirve de algo.
func can_press() -> bool:
	return not _rivals.is_empty() and blocked == ""


## Rivales que se ven, de delante atras (para las pruebas).
func shown_ids() -> Array[String]:
	var out: Array[String] = []
	for rival in _rivals:
		out.append(str(rival.info.get("id", "")))
	return out


# --- Montaje -------------------------------------------------------------------


func _make(info: Dictionary) -> Rival:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = HOLO_SHADER
	var rival := Rival.new()
	rival.info = info
	rival.view = MechView.new()
	rival.material = ShaderMaterial.new()
	rival.material.shader = _shader
	rival.view.material = rival.material
	_back.add_child(rival.view)
	var build: MechBuild = info["build"]
	rival.view.setup(build, -1)
	if build.chest != null:
		rival.view.show_deployed()
	# Lo que mide de verdad: el arma de hombro asoma por encima del torso y
	# standing_height no la cuenta.
	var top := rival.view.standing_height()
	for slot in BODY_SLOTS:
		var rect := rival.view.slot_rect(slot)
		if rect.size != Vector2.ZERO:
			top = maxf(top, -rect.position.y)
	rival.height = maxf(top, 120.0)
	rival.view.set_facing(-1)
	rival.draw_factor = absf(rival.view.scale.y)
	rival.view.footstep.connect(_on_step.bind(rival))
	return rival


## La entrada en la zona de combate: tras `delay`, el rival sale del borde
## derecho y anda hasta su sitio.
func _walk_in(rival: Rival, delay: float) -> void:
	var home := _feet(rival)
	rival.view.position = Vector2(_size.x + MECH_WIDTH * _scale(rival), home.y)
	var start := create_tween()
	start.tween_interval(delay)
	start.tween_callback(
		func() -> void:
			if rival in _rivals and is_instance_valid(rival.view):
				var walk := rival.view.move_to(home, WALK_SECONDS)
				walk.finished.connect(_arrived.bind(rival))
	)
	_tweens.append(start)


## Llego a su sitio: pisa fuerte, saltan chispas y se enciende su nombre.
func _arrived(rival: Rival) -> void:
	rival.entering = false
	if not rival in _rivals or not is_instance_valid(rival.view):
		return
	rival.view.place(_feet(rival))
	Sfx.play("pisoton")
	rival.burst = 1.0
	_animate(rival, "burst", 0.0, BURST_SECONDS, 0.0)
	_animate(rival, "title", 1.0, TITLE_SECONDS, 0.1)


func _on_step(_at: Vector2, rival: Rival) -> void:
	if rival.entering:
		Sfx.play("paso")


## Donde esta ahora (andando, su sitio de verdad; si no, el de la fila).
func _at(rival: Rival) -> Vector2:
	if rival.entering and is_instance_valid(rival.view):
		return rival.view.position
	return _feet(rival)


## El que sale de verdad (en la zona de combate y delante).
func _is_real(rival: Rival) -> bool:
	return ring and rival.depth < 0.5


func _signature_of(rivals: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for info in rivals:
		parts.append("%s/%s/%s" % [info.get("id", ""), info.get("tier", 0), info.get("level", 0)])
	return ",".join(parts)


## El vencido se apaga delante y los demas avanzan un sitio.
func _advance(beaten: Dictionary) -> void:
	if not beaten.is_empty():
		var fallen := _make(beaten)
		fallen.alpha = 1.0
		_leaving.append(fallen)
		Sfx.play("apagado", BEATEN_HOLD)
		var out := _animate(fallen, "alpha", 0.0, BEATEN_SECONDS, BEATEN_HOLD)
		out.finished.connect(_drop.bind(fallen))
	var wait := BEATEN_HOLD + BEATEN_SECONDS * 0.7
	for i in _rivals.size():
		var rival := _rivals[i]
		_animate(rival, "depth", float(i), ADVANCE_SECONDS, wait)
		if rival.alpha < 1.0:
			_animate(rival, "alpha", 1.0, ADVANCE_SECONDS, wait)


## Apaga un rival y lo quita.
func _retire(rival: Rival, seconds: float) -> void:
	if seconds <= 0.0:
		rival.view.queue_free()
		return
	_leaving.append(rival)
	var out := create_tween()
	out.tween_property(rival, "alpha", 0.0, seconds)
	out.finished.connect(_drop.bind(rival))


func _drop(rival: Rival) -> void:
	_leaving.erase(rival)
	if is_instance_valid(rival.view):
		rival.view.queue_free()


func _animate(rival: Rival, property: String, to: float, seconds: float, delay: float) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(rival, property, to, seconds).set_delay(delay)
	_tweens.append(tween)
	return tween


func _stop_tweens() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()


# --- Colocacion ------------------------------------------------------------------


func _process(delta: float) -> void:
	_time += delta
	if _rivals.is_empty() and _leaving.is_empty():
		return
	# Solo se recoloca lo que se mueve o se esta encendiendo; el resto late.
	var moving := false
	for rival in _rivals + _leaving:
		if rival.depth != rival.placed_depth or rival.alpha != rival.placed_alpha:
			moving = true
		elif rival.alpha < 0.999:
			moving = true
	if moving:
		_place_all()
	else:
		queue_redraw()
		_fx.queue_redraw()


func _place_all() -> void:
	# El que va delante se dibuja por encima de la sombra en la que se pierden
	# los demas; los de detras, del mas lejano al mas cercano.
	var ordered: Array[Rival] = _rivals.duplicate()
	ordered.sort_custom(func(a: Rival, b: Rival) -> bool: return a.depth > b.depth)
	for rival in ordered:
		var holder := _front if rival.depth < 0.5 else _back
		if rival.view.get_parent() != holder:
			rival.view.get_parent().remove_child(rival.view)
			holder.add_child(rival.view)
		holder.move_child(rival.view, -1)
	for rival in _leaving:
		if rival.view.get_parent() != _front:
			rival.view.get_parent().remove_child(rival.view)
			_front.add_child(rival.view)
	for rival in _rivals + _leaving:
		_apply(rival)
	queue_redraw()
	_shade.queue_redraw()
	_fx.queue_redraw()


## Valor de un sitio de la fila, tambien entre dos sitios.
func _slot(values: Array[float], depth: float) -> float:
	var last := values.size() - 1
	var d := clampf(depth, 0.0, float(last))
	var i := int(d)
	return lerpf(values[i], values[mini(i + 1, last)], d - i)


func _feet(rival: Rival) -> Vector2:
	var beyond := maxf(rival.depth - (SLOT_X.size() - 1.0), 0.0)
	var x := (_slot(SLOT_X, rival.depth) + beyond * BEYOND_STEP) * _size.x
	return Vector2(x, _floor_y - _slot(SLOT_LIFT, rival.depth))


## Tamano de un rival: el de su sitio, sin que su cabeza (o su asistente)
## pase del borde del monitor.
func _scale(rival: Rival) -> float:
	var room := _floor_y - _slot(SLOT_LIFT, rival.depth) - _ceiling
	var share := _slot(SLOT_SCALE, rival.depth)
	if ring:
		share = lerpf(RING_SCALE, share, clampf(rival.depth, 0.0, 1.0))
	return minf(share * _zoom, room / (rival.height * rival.draw_factor))


func _beam(rival: Rival) -> Color:
	return BOSS_BEAM if bool(rival.info.get("boss", false)) else BEAM


func _apply(rival: Rival) -> void:
	var view := rival.view
	if not is_instance_valid(view):
		return
	rival.placed_depth = rival.depth
	rival.placed_alpha = rival.alpha
	# El que toca respira; los de la sombra, apenas siluetas, se quedan quietos.
	view.set_process(rival.depth < 0.5)
	var last := SLOT_SHADE.size() - 1
	var d := clampf(rival.depth, 0.0, float(last))
	var i := int(d)
	var shade := SLOT_SHADE[i].lerp(SLOT_SHADE[mini(i + 1, last)], d - i)
	if not rival.entering:
		view.place(_feet(rival))
	view.set_facing(-1)
	view.material = null if _is_real(rival) else rival.material
	view.scale *= _scale(rival)
	# Mientras se enciende o se apaga, la proyeccion parpadea y es pura luz.
	var flicker := 1.0
	if rival.alpha < 0.999:
		flicker = 0.72 + 0.28 * sin(_time * 53.0 + rival.depth * 2.3)
	view.modulate = Color(shade.r, shade.g, shade.b, clampf(rival.alpha * flicker, 0.0, 1.0))
	view.visible = rival.alpha > 0.01
	rival.material.set_shader_parameter(
		"holo", lerpf(1.0, _slot(SLOT_HOLO, rival.depth), rival.alpha)
	)
	rival.material.set_shader_parameter("beam", _beam(rival))


## Lo que ocupa un rival, en las coordenadas del hangar.
func _rect_of(rival: Rival) -> Rect2:
	var view := rival.view
	var out := Rect2()
	var first := true
	for slot in BODY_SLOTS:
		var rect := view.slot_rect(slot)
		if rect.size == Vector2.ZERO:
			continue
		var a := view.transform * rect.position
		var b := view.transform * rect.end
		var box := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		out = box if first else out.merge(box)
		first = false
	if first:
		var feet := _feet(rival)
		var k := _scale(rival)
		out = Rect2(
			feet.x - MECH_WIDTH * k * 0.5,
			feet.y - rival.height * k,
			MECH_WIDTH * k,
			rival.height * k
		)
	return out


# --- Dibujo ------------------------------------------------------------------


## Bajo los robots: el foco del primero y el proyector de cada uno.
func _draw() -> void:
	var ordered: Array[Rival] = (_rivals + _leaving).duplicate()
	ordered.sort_custom(func(a: Rival, b: Rival) -> bool: return a.depth > b.depth)
	for rival in ordered:
		if rival.alpha <= 0.01:
			continue
		var feet := _at(rival)
		var k := _scale(rival)
		var rx := MECH_WIDTH * 0.42 * k
		var ry := maxf(rx * 0.17, 3.0)
		var near := clampf(1.0 - rival.depth, 0.0, 1.0)
		var beam := _beam(rival)
		if near > 0.0 and hover and can_press() and rival in _rivals:
			beam = beam.lerp(GOLD, 0.85)
		var glow := rival.alpha * (0.35 + 0.65 * near)
		# Foco del techo sobre el que toca.
		if near > 0.0:
			for step in 3:
				var spread := rx * (1.25 + 0.3 * step)
				var cone := PackedVector2Array(
					[
						Vector2(feet.x - 10.0, 0.0),
						Vector2(feet.x + 10.0, 0.0),
						Vector2(feet.x + spread, feet.y),
						Vector2(feet.x - spread, feet.y)
					]
				)
				draw_colored_polygon(cone, Color(0.62, 0.8, 1.0, 0.04 * near * rival.alpha))
		# En la zona de combate no hay proyector: un charco de luz en el suelo.
		if _is_real(rival):
			for step in 3:
				var spread := 1.0 + 0.35 * step
				var pool := Color(1.0, 0.86, 0.78, (0.12 - 0.03 * step) * rival.alpha)
				_ellipse(feet + Vector2(0, ry * 0.5), rx * spread, ry * spread * 1.3, pool)
			continue
		# Proyector: la base en el suelo, su aro encendido y el haz que sube.
		_ellipse(
			feet + Vector2(0, ry * 0.8), rx * 1.08, ry * 1.3, Color(0, 0, 0, 0.5 * rival.alpha)
		)
		_ellipse(feet + Vector2(0, ry * 0.35), rx, ry * 1.1, Color(0.07, 0.1, 0.15, rival.alpha))
		_ellipse(feet, rx, ry, Color(beam.darkened(0.72), rival.alpha))
		_ellipse(feet, rx * 0.8, ry * 0.8, Color(beam, 0.16 * glow))
		var pulse := 0.8 + 0.2 * sin(_time * 3.2 + rival.depth * 1.7)
		_ring(feet, rx, ry, Color(beam, 0.9 * glow * pulse), 2.0)
		_ring(feet, rx * 0.62, ry * 0.62, Color(beam, 0.4 * glow), 1.0)
		var height := rival.height * k
		var haze := PackedVector2Array(
			[
				feet + Vector2(-rx * 0.86, 0),
				feet + Vector2(rx * 0.86, 0),
				feet + Vector2(rx * 0.7, -height),
				feet + Vector2(-rx * 0.7, -height)
			]
		)
		draw_colored_polygon(haze, Color(beam, 0.05 * glow))


## La sombra en la que se pierde la fila, hacia la derecha.
func _draw_shade() -> void:
	var presence := 0.0
	for rival in _rivals:
		presence = maxf(presence, rival.alpha)
	if presence <= 0.01:
		return
	var left := _size.x * 0.79
	var top := _size.y * 0.36
	var bottom := _floor_y + 44.0
	var clear_color := Color(0.01, 0.02, 0.04, 0.0)
	var dark := Color(0.01, 0.02, 0.04, 0.82 * presence)
	_shade.draw_polygon(
		PackedVector2Array(
			[
				Vector2(left, top),
				Vector2(_size.x, top),
				Vector2(_size.x, bottom),
				Vector2(left, bottom)
			]
		),
		PackedColorArray([clear_color, dark, dark, clear_color])
	)


## Encima: el barrido de cada proyeccion al encenderse, las esquinas del
## primero al pasar el raton y su rotulo en el suelo.
func _draw_fx() -> void:
	for rival in _rivals:
		if rival.scan >= 0.999 or rival.alpha <= 0.01:
			continue
		var feet := _feet(rival)
		var rx := MECH_WIDTH * 0.5 * _scale(rival)
		var y := feet.y - rival.height * _scale(rival) * rival.scan
		var beam := _beam(rival)
		var fade := 1.0 - rival.scan
		_fx.draw_rect(Rect2(feet.x - rx, y - 5.0, rx * 2.0, 10.0), Color(beam, 0.12 * fade))
		_fx.draw_line(Vector2(feet.x - rx, y), Vector2(feet.x + rx, y), Color(beam, fade), 2.0)
	if _rivals.is_empty():
		return
	var front := _rivals[0]
	if front.alpha <= 0.3 or front.depth > 0.5:
		return
	var live := hover and can_press() and not front.entering
	if live:
		_brackets(front_rect().grow(6.0), GOLD)
	if _is_real(front):
		_draw_burst(front)
		_draw_ring_title(front, live)
	else:
		_draw_label(front, live)


## Rotulo del que toca, proyectado en el suelo delante de el: su nombre, su
## clase y nivel, como pelea (si se sabe) y lo que pasa al pulsarlo.
func _draw_label(front: Rival, live: bool) -> void:
	var feet := _feet(front)
	var boss := bool(front.info.get("boss", false))
	var accent := BOSS_BEAM if boss else BEAM
	var width := 250.0
	var left := feet.x - width * 0.5
	var y := feet.y + 34.0
	var alpha := front.alpha
	# Como pelea va en un renglon mas, y lo de debajo baja con el.
	var traits := str(front.info.get("traits", ""))
	var drop := 14.0 if traits != "" else 0.0
	# Dos trazos, como una proyeccion sobre el suelo.
	for side: float in [-1.0, 1.0]:
		var x := feet.x + side * width * 0.5
		var foot := y + 44.0 + drop
		_fx.draw_line(Vector2(x, y - 12.0), Vector2(x, foot), Color(accent, 0.55 * alpha), 2.0)
		_fx.draw_line(
			Vector2(x, y - 12.0),
			Vector2(x - side * 10.0, y - 12.0),
			Color(accent, 0.55 * alpha),
			2.0
		)
		_fx.draw_line(
			Vector2(x, foot), Vector2(x - side * 10.0, foot), Color(accent, 0.55 * alpha), 2.0
		)
	_text(
		Vector2(left, y + 4.0), str(front.info.get("name", "")).to_upper(), width, 15, TEXT, alpha
	)
	_text(
		Vector2(left, y + 20.0),
		str(front.info.get("detail", "")),
		width,
		11,
		accent.lightened(0.35),
		alpha * 0.9
	)
	if traits != "":
		_text(Vector2(left - 30.0, y + 34.0), traits, width + 60.0, 11, GOLD, alpha * 0.85)
	var cue := Txt.t("mission_go_boss" if boss else "mission_go")
	var cue_color := GOLD
	var cue_alpha := 0.5
	if blocked != "":
		cue = blocked
		cue_color = BAD
		cue_alpha = 1.0
	elif armed:
		cue = confirm_text if confirm_text != "" else Txt.t("mission_confirm")
		cue_color = BAD.lerp(GOLD, 0.5 + 0.5 * sin(_time * 9.0))
		cue_alpha = 1.0
	elif live:
		cue = "▶  %s  ◀" % cue
		cue_alpha = 0.8 + 0.2 * sin(_time * 7.0)
	_text(
		Vector2(left - 60.0, y + 38.0 + drop), cue, width + 120.0, 13, cue_color, alpha * cue_alpha
	)
	if warning != "" and blocked == "":
		var tone := BAD if danger else GOLD
		_text(Vector2(left - 60.0, y + 58.0 + drop), warning, width + 120.0, 11, tone, alpha * 0.95)


## Las chispas al pisar: dos fuentes a los lados y una onda en el suelo.
func _draw_burst(front: Rival) -> void:
	if front.burst <= 0.01:
		return
	var feet := _at(front)
	var k := _scale(front)
	var rx := MECH_WIDTH * 0.5 * k
	var life := 1.0 - front.burst
	# La onda, sobre el suelo.
	var reach := rx * (0.7 + 1.8 * life)
	var wave := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		wave.append(feet + Vector2(cos(a) * reach, sin(a) * reach * 0.2))
	_fx.draw_polyline(wave, Color(1.0, 0.92, 0.8, 0.75 * front.burst), 2.0, true)
	# Dos fuentes de chispas a los lados: cada una sale en arco y cae.
	var speed := front.height * k * 1.6
	for side: float in [-1.0, 1.0]:
		var base := feet + Vector2(side * rx * 1.1, 0.0)
		for n in 18:
			var spread := fposmod(n * 0.618, 1.0)
			var angle := deg_to_rad(62.0 + 26.0 * spread)
			var v := speed * (0.55 + 0.45 * fposmod(n * 0.371, 1.0))
			var t := life * 0.9
			var fly := Vector2(side * cos(angle) * v * t, -sin(angle) * v * t + speed * 1.1 * t * t)
			var at := base + fly
			var tone := GOLD if n % 3 else Color.WHITE
			var trail := Vector2(side * cos(angle), -sin(angle) + 2.2 * t).normalized() * 8.0
			_fx.draw_line(at - trail, at, Color(tone, 0.55 * front.burst), 1.5)
			_fx.draw_circle(at, 1.8 * front.burst + 0.6, Color(tone, front.burst))


## Su nombre en grande, como el tuyo, con su raya roja; un VS entre los dos
## nombres; debajo su clase y nivel, como pelea y lo que pasa al pulsarlo.
func _draw_ring_title(front: Rival, live: bool) -> void:
	var show := front.title
	if show <= 0.01:
		return
	var feet := _feet(front)
	var boss := bool(front.info.get("boss", false))
	var accent := BOSS_BEAM if boss else RING_ACCENT
	var label := str(front.info.get("name", "")).to_upper()
	# Su nombre, bajo el y del tamano del tuyo; nunca encima del tuyo: si no
	# cabe se corre a la derecha y, si aun asi no, encoge.
	var floor_from := _player_name_end() + VS_GAP
	var room := _size.x - 14.0 - floor_from
	var title_size := TITLE_SIZE
	var wide := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	while wide > room and title_size > 18:
		title_size -= 1
		wide = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var left_x := clampf(feet.x - wide * 0.5, floor_from, maxf(floor_from, _size.x - 14.0 - wide))
	var center := left_x + wide * 0.5
	var lift := 14.0 * (1.0 - show)
	var at := Vector2(left_x, feet.y + 58.0 + lift)
	var shadow := Color(0, 0, 0, 0.7 * show)
	_fx.draw_string(
		font, at + Vector2(2, 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, shadow
	)
	_fx.draw_string(
		font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, Color("ffe6dc", show)
	)
	var bar_wide := wide * 1.15 * show
	var bar := Rect2(center - bar_wide * 0.5, feet.y + 68.0, bar_wide, 3.0)
	_fx.draw_rect(bar, Color(accent, 0.9 * show))
	_fx.draw_rect(bar.grow(3.0), Color(accent, 0.18 * show))
	_draw_vs(Vector2((_player_name_end() + left_x) * 0.5, at.y - lift), show)
	feet.x = center
	var width := 320.0
	var left := feet.x - width * 0.5
	var y := feet.y + 92.0
	_text(
		Vector2(left, y), str(front.info.get("detail", "")), width, 12, accent.lightened(0.45), show
	)
	var traits := str(front.info.get("traits", ""))
	if traits != "":
		y += 16.0
		_text(Vector2(left, y), traits, width, 11, GOLD, show * 0.85)
	var cue := Txt.t("mission_go_boss" if boss else "mission_go")
	var cue_color := GOLD
	var cue_alpha := 0.55
	if blocked != "":
		cue = blocked
		cue_color = BAD
		cue_alpha = 1.0
	elif armed:
		cue = confirm_text if confirm_text != "" else Txt.t("mission_confirm")
		cue_color = BAD.lerp(GOLD, 0.5 + 0.5 * sin(_time * 9.0))
		cue_alpha = 1.0
	elif live:
		cue = "▶  %s  ◀" % cue
		cue_alpha = 0.8 + 0.2 * sin(_time * 7.0)
	y += 20.0
	_text(Vector2(left - 60.0, y), cue, width + 120.0, 13, cue_color, show * cue_alpha)
	if warning != "" and blocked == "":
		var tone := BAD if danger else GOLD
		_text(Vector2(left - 60.0, y + 18.0), warning, width + 120.0, 11, tone, show * 0.95)


## El VS, entre tu nombre y el suyo, en su misma linea (como en un cartel
## de pelea): con un halo detras y latiendo. `at`: su centro en la linea.
func _draw_vs(at: Vector2, show: float) -> void:
	if player_feet == Vector2.ZERO or player_name == "":
		return
	var vs := Txt.t("zone_vs")
	var vs_size := 28
	var vs_wide := font.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, vs_size).x
	var pulse := 0.85 + 0.15 * sin(_time * 4.0)
	for ring_step in 3:
		var r := (18.0 + ring_step * 8.0) * (0.8 + 0.2 * show)
		_fx.draw_circle(at + Vector2(0, -10), r, Color(RING_ACCENT, 0.08 * show))
	var left := at - Vector2(vs_wide * 0.5, 0.0)
	var outline := Color(0.05, 0.02, 0.02, 0.9 * show)
	_fx.draw_string_outline(font, left, vs, HORIZONTAL_ALIGNMENT_LEFT, -1, vs_size, 6, outline)
	var tone := Color(GOLD, show * pulse)
	_fx.draw_string(font, left, vs, HORIZONTAL_ALIGNMENT_LEFT, -1, vs_size, tone)


## Donde acaba el nombre de tu robot (ZoneArt.fighter_name, centrado bajo
## el, del mismo tamano).
func _player_name_end() -> float:
	if player_feet == Vector2.ZERO or player_name == "":
		return 0.0
	var text := player_name.to_upper()
	return (
		player_feet.x
		+ font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x * 0.5
	)


func _brackets(rect: Rect2, color: Color) -> void:
	var arm := 16.0
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	var dirs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for i in 4:
		_fx.draw_line(corners[i], corners[i] + Vector2(dirs[i].x * arm, 0), color, 3.0)
		_fx.draw_line(corners[i], corners[i] + Vector2(0, dirs[i].y * arm), color, 3.0)


func _text(
	at: Vector2, text: String, width: float, font_size: int, color: Color, alpha: float
) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER
	_fx.draw_string(
		font, at + Vector2(1, 1), text, align, width, font_size, Color(0, 0, 0, 0.7 * alpha)
	)
	_fx.draw_string(font, at, text, align, width, font_size, Color(color, color.a * alpha))


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _ring(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 29:
		var a := TAU * i / 28.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, color, width, true)
