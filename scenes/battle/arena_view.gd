class_name ArenaView
extends Control
## La arena: un campo mas ancho que la pantalla, con los dos mechs encima,
## una camara que los sigue y un paisaje de fondo en capas (GDD 12.1). Solo
## dibuja y avisa de los clics; no conoce las reglas.

signal cell_clicked(cell: int)
signal cell_hovered(cell: int)

## Ancho de una casilla en el mundo. Con 10 casillas el campo mide 2300, casi
## el doble que la pantalla: hay que recorrerlo.
const CELL_WIDTH := 230.0
const CELL_HEIGHT := 46.0
## Distancia del suelo al borde inferior de la vista.
const FLOOR_MARGIN := 58.0
## La camara se aleja cuando los mechs se separan y se acerca cuando se juntan.
const MIN_ZOOM := 0.5
const MAX_ZOOM := 1.0
## Aire que la camara deja sobre lo mas alto de los mechs (el robot de
## asistencia), en pixeles de pantalla.
const TOP_MARGIN := 12.0
## Casillas de margen que la camara deja a cada lado de los mechs.
const VIEW_MARGIN_CELLS := 1.6
## Rapidez con la que la camara alcanza su objetivo.
const CAMERA_SPEED := 4.0
## Color de la caja de bonificacion segun lo que da (GDD 2.8).
const DROP_COLORS := {"armor": Color("6fb6ff"), "firepower": Color("ffb347")}
## Paisaje provisional, dibujado por codigo hasta que haya escenarios con el
## estilo aprobado. Cuanto mas lejos esta una capa, menos se mueve.
## Escenario por defecto, por si no se indica ninguno (data/stages.json).
const DEFAULT_STAGE := {
	"sky_top": Color("070b16"),
	"sky_horizon": Color("2a2148"),
	"stars": 90,
	"body": "planet",
	"body_color": Color("4d3f86"),
	"ships": 3,
	"far": {"style": "towers", "color": Color("161d33"), "height": 150, "tile": 130},
	"near": {"style": "towers", "color": Color("0c111d"), "height": 230, "tile": 300},
	"ambient": "none",
	"haze": Color(0.45, 0.35, 0.7, 0.35),
	"floor": Color("0e141c"),
	"cell": Color("1c2633"),
	"cell_line": Color("3a4a5e"),
}
const PARALLAX_STARS := 0.03
const PARALLAX_PLANET := 0.06
const PARALLAX_SHIPS := 0.12
const PARALLAX_FAR := 0.22
const PARALLAX_NEAR := 0.5

var cells: int = 10
var mechs: Array[MechView] = []

## Casillas resaltadas: {indice: color}.
var _highlights: Dictionary = {}
var _hovered: int = -1
## Bonificacion que hay en la arena: {"cell", "kind"}; vacio si no hay.
var _drop: Dictionary = {}
## Textos flotantes vivos por casilla, para no encimarlos.
var _floating: Dictionary = {}
## Capa del mundo: suelo, mechs y textos. La camara la mueve y la escala.
var _world := Node2D.new()
var _floor := Node2D.new()
## Fogonazos, chispas y demas efectos, por delante de los mechs.
var _fx := Node2D.new()
## Disparos de las armas, cada uno el suyo (data/shots.json).
var _shots := ShotFx.new()
## Avisos que van por encima del mundo y no se mueven con la camara.
var _overlay := Node2D.new()
## Punto del mundo que queda en el centro de la vista; negativo = sin fijar.
var _camera_x := -1.0
var _zoom := 1.0
var _time := 0.0
## Escenario en uso: colores y elementos del paisaje.
var _stage: Dictionary = DEFAULT_STAGE.duplicate(true)
## Fuerza de la sacudida de camara en curso.
var _shake := 0.0
## Caida de la bonificacion desde la nave: 0 arriba, 1 en el suelo.
var _drop_fall := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	add_child(_world)
	_world.add_child(_floor)
	_floor.draw.connect(_draw_floor)
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	for i in 2:
		var view := MechView.new()
		_world.add_child(view)
		mechs.append(view)
		view.footstep.connect(_on_footstep)
	_world.add_child(_fx)
	_world.add_child(_shots)
	_shots.shake_requested.connect(shake)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	_time += delta
	_follow(delta)
	queue_redraw()
	_overlay.queue_redraw()
	if _drop_fall < 1.0:
		_floor.queue_redraw()


func world_width() -> float:
	return cells * CELL_WIDTH


func cell_width() -> float:
	return CELL_WIDTH


## Punto del suelo en el centro de una casilla, en coordenadas del mundo.
func cell_point(cell: int) -> Vector2:
	return Vector2((cell + 0.5) * CELL_WIDTH, 0.0)


func set_highlights(highlights: Dictionary) -> void:
	_highlights = highlights
	_floor.queue_redraw()


## Muestra u oculta la bonificacion que dejo la nave (GDD 2.8).
func set_drop(drop: Dictionary) -> void:
	if drop != _drop:
		_drop = drop.duplicate()
		_floor.queue_redraw()


## Hace que los dos mechs se miren.
func update_facing() -> void:
	var left := 0 if mechs[0].position.x <= mechs[1].position.x else 1
	mechs[left].set_facing(1)
	mechs[1 - left].set_facing(-1)


## Numero que sube y se desvanece sobre una casilla (dano, calor...).
func float_text(cell: int, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 7)
	_world.add_child(label)
	# Cada texto nuevo sobre la misma casilla sale un poco mas abajo.
	var row: int = _floating.get(cell, 0)
	_floating[cell] = row + 1
	label.position = cell_point(cell) + Vector2(-34, -250 + 30 * row)
	var tween := create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 1.1)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.5)
	tween.tween_callback(_on_float_done.bind(label, cell))


func _on_float_done(label: Label, cell: int) -> void:
	label.queue_free()
	_floating[cell] = maxi(0, _floating.get(cell, 1) - 1)


# --- Efectos (coordenadas del mundo) ---------------------------------------------


## Disparo completo de un mech a otro: despliega el arma si hace falta,
## retroceso y el disparo del arma (`fx`, de data/shots.json) con el color
## de su municion. Vuelve cuando llega el ultimo impacto.
## `slot` es el hueco del arma ("side0", "top1", "chest"...): el canon de
## pecho solo se despliega cuando dispara el.
func fire_between(
	actor: int,
	target: int,
	fx: String,
	color: Color,
	seconds: float,
	from_drone: bool,
	slot: String = ""
) -> void:
	var shooter := mechs[actor]
	if not from_drone:
		if slot == "chest" or not MechSprites.has_weapon_art():
			var deploying := shooter.deploy(seconds * 0.9)
			if deploying != null:
				await deploying.finished
		ShotFx.kick(shooter, fx, seconds * 0.6, slot, seconds)
	elif slot != "":
		# El robot de asistencia tambien retrocede al disparar.
		ShotFx.kick(shooter, fx, seconds * 0.6, slot, seconds)
	var from := shooter.muzzle_point(from_drone, slot)
	var to := mechs[target].hit_point()
	await _shots.play(fx, from, to, color, seconds)


## Impacto de un golpe sobre un mech (GDD 2.10): "light" apenas sacude,
## "medium" sacude y levanta polvo, "heavy" sacude fuerte con un destello y
## "ultimate" (materia oscura) sacude la arena entera.
func impact(target: int, tier: String, seconds: float) -> void:
	var view := mechs[target]
	match tier:
		"light":
			shake(2.5)
		"medium":
			shake(6.0)
			dust(view.position, seconds * 0.6)
			Sfx.play("impacto_medio")
		"heavy":
			shake(12.0)
			Sfx.play("impacto_grave")
			flash(view.hit_point(), Color("fff3d6"), 120.0, seconds * 0.5)
			dust(view.position, seconds * 0.8)
		"ultimate":
			shake(20.0)
			Sfx.play("impacto_ultimo")
			flash(view.hit_point(), Color("e8d6ff"), 220.0, seconds)
			dust(view.position, seconds)


## La ultima arma (GDD 2.10): la materia oscura sale del arma de pecho con su
## propia secuencia segun el tipo del arma: despliegue, carga, disparo y
## explosion. Vuelve al llegar el golpe.
func dark_matter(actor: int, target: int, chest_type: String, color: Color, seconds: float) -> void:
	var shooter := mechs[actor]
	var deploying := shooter.deploy(seconds * 1.2)
	if deploying != null:
		Sfx.play("despliegue")
		await deploying.finished
	var from := shooter.muzzle_point(false, "chest")
	var to := mechs[target].hit_point()
	shake(3.0)
	Sfx.rising("carga_oscura", seconds * 3.0)
	await _shots.charge(from, color, seconds * 3.0, chest_type)
	shooter.fire(seconds * 0.8, "chest")
	var shot := "materia_oscura_" + chest_type
	if not ShotFx.is_known(shot):
		shot = "materia_oscura"
	await _shots.play(shot, from, to, color, seconds * 1.5)
	explode(to, seconds * 2.0)
	impact(target, "ultimate", seconds)


## Golpe cuerpo a cuerpo: el mech se lanza, su hoja (`slot`) da el tajo y,
## si su arma lo tiene, se dibuja sobre el rival. No espera a que termine.
func strike(
	actor: int, target: int, fx: String, color: Color, seconds: float, slot: String = ""
) -> void:
	mechs[actor].lunge(seconds)
	mechs[actor].swing(seconds, slot)
	if fx == "" or ShotFx.shot(fx)["path"] != "melee":
		return
	var from := mechs[actor].hit_point()
	_shots.play(fx, from, mechs[target].hit_point(), color, seconds)


## Fogonazo: una estrella que se encoge y se apaga.
func flash(at: Vector2, color: Color, radius: float, seconds: float) -> void:
	var star := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 16:
		var reach := radius if i % 2 == 0 else radius * 0.42
		points.append(Vector2.from_angle(TAU * i / 16.0) * reach)
	star.polygon = points
	star.color = color.lightened(0.5)
	star.position = at
	_fx.add_child(star)
	var tween := create_tween()
	tween.tween_property(star, "scale", Vector2(0.2, 0.2), seconds)
	tween.parallel().tween_property(star, "modulate:a", 0.0, seconds)
	tween.tween_callback(star.queue_free)


## Chispas que saltan del punto de impacto.
func sparks(at: Vector2, color: Color, seconds: float) -> void:
	for i in 9:
		var ray := Line2D.new()
		ray.width = 3.0
		ray.default_color = color.lightened(0.4)
		var direction := Vector2.from_angle(TAU * (i + _noise(i, _time)) / 9.0)
		ray.points = PackedVector2Array([direction * 8.0, direction * 22.0])
		ray.position = at
		_fx.add_child(ray)
		var tween := create_tween()
		tween.tween_property(
			ray, "position", at + direction * (36.0 + 30.0 * _noise(i, 9.0)), seconds
		)
		tween.parallel().tween_property(ray, "modulate:a", 0.0, seconds)
		tween.tween_callback(ray.queue_free)


## Explosion: varios fogonazos escalonados y una sacudida fuerte.
func explode(at: Vector2, seconds: float) -> void:
	shake(14.0)
	var colors := [Color("ffd27a"), Color("ff8a3d"), Color("fff3d6"), Color("ff5a3d")]
	for i in colors.size():
		var offset := Vector2(_noise(i, 21.0) - 0.5, _noise(i, 22.0) - 0.5) * 120.0
		var delay := create_tween()
		delay.tween_interval(seconds * 0.18 * i)
		delay.tween_callback(flash.bind(at + offset, colors[i], 70.0 + 20.0 * i, seconds * 0.5))
		delay.tween_callback(sparks.bind(at + offset, colors[i], seconds * 0.5))


## Cable del gancho entre dos mechs; se desvanece mientras tira.
func cable(from_index: int, to_index: int, seconds: float) -> void:
	var line := Line2D.new()
	line.width = 5.0
	line.default_color = Color("c8d2de")
	line.points = PackedVector2Array([mechs[from_index].hit_point(), mechs[to_index].hit_point()])
	_fx.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, seconds)
	tween.tween_callback(line.queue_free)


## Polvo que levanta un mech al caer de un salto.
func dust(at: Vector2, seconds: float) -> void:
	sparks(at + Vector2(0.0, -6.0), Color("b9aa90"), seconds)


func _on_footstep(at: Vector2) -> void:
	dust(at, 0.35)


## Sacudida de camara; se apaga sola.
func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## La nave pasa sobre la arena y suelta la bonificacion, que cae a su casilla.
func ship_drop(drop: Dictionary, seconds: float) -> void:
	_drop = drop.duplicate()
	_drop_fall = 0.0
	var target := cell_point(drop["cell"])
	var ship := Polygon2D.new()
	ship.polygon = PackedVector2Array(
		[Vector2(92, 0), Vector2(20, -22), Vector2(-70, -16), Vector2(-104, 6), Vector2(-30, 18)]
	)
	ship.color = Color("33456e")
	ship.position = Vector2(target.x - 1100.0, -470.0)
	_fx.add_child(ship)
	var fly := create_tween()
	fly.tween_property(ship, "position:x", target.x + 1100.0, seconds * 1.7)
	fly.tween_callback(ship.queue_free)
	var fall := create_tween()
	fall.tween_interval(seconds * 0.8)
	(
		fall
		. tween_property(self, "_drop_fall", 1.0, seconds * 0.7)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)
	await fall.finished


# --- Camara ------------------------------------------------------------------


## Lleva la camara hacia el punto medio de los mechs y ajusta el acercamiento
## para que quepan los dos con margen.
func _follow(delta: float) -> void:
	if size.x <= 0.0 or mechs.size() < 2:
		return
	var a := mechs[0].position.x
	var b := mechs[1].position.x
	var span := absf(a - b) + 2.0 * VIEW_MARGIN_CELLS * CELL_WIDTH
	var target_zoom := size.x / span
	# Tambien en vertical: que el asistente que flota sobre su mech no se salga.
	var tallest := maxf(mechs[0].standing_height(), mechs[1].standing_height())
	if tallest > 0.0:
		target_zoom = minf(target_zoom, (size.y - FLOOR_MARGIN - TOP_MARGIN) / tallest)
	target_zoom = clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	var target_x := (a + b) / 2.0
	if _camera_x < 0.0:
		_camera_x = target_x
		_zoom = target_zoom
	var blend := 1.0 - exp(-CAMERA_SPEED * delta)
	_zoom = lerpf(_zoom, target_zoom, blend)
	_camera_x = lerpf(_camera_x, target_x, blend)
	var half := size.x / (2.0 * _zoom)
	if half * 2.0 >= world_width():
		_camera_x = world_width() / 2.0
	else:
		_camera_x = clampf(_camera_x, half, world_width() - half)
	_world.scale = Vector2(_zoom, _zoom)
	_world.position = Vector2(size.x / 2.0 - _camera_x * _zoom, size.y - FLOOR_MARGIN)
	if _shake > 0.0:
		_world.position += Vector2(sin(_time * 71.0), cos(_time * 53.0)) * _shake
		_shake = maxf(0.0, _shake - delta * 36.0)


## Cuanto se ha desplazado la camara desde el centro del campo.
func _camera_shift() -> float:
	return (_camera_x - world_width() / 2.0) if _camera_x >= 0.0 else 0.0


# --- Suelo (coordenadas del mundo) --------------------------------------------


func _draw_floor() -> void:
	_floor.draw_rect(Rect2(-3000, 0, world_width() + 6000, 600), _stage["floor"])
	var font := get_theme_default_font()
	for cell in cells:
		var rect := Rect2(cell * CELL_WIDTH + 4, 4, CELL_WIDTH - 8, CELL_HEIGHT - 8)
		var color: Color = _stage["cell"]
		if _highlights.has(cell):
			color = _highlights[cell]
			if cell == _hovered:
				color = color.lightened(0.25)
		_floor.draw_rect(rect, color)
		_floor.draw_rect(rect, _stage["cell_line"], false, 2.0)
		_floor.draw_string(
			font,
			rect.position + Vector2(0, 27),
			str(cell),
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			20,
			Color("8fa3b8")
		)
	if not _drop.is_empty():
		_draw_drop(font)


## La bonificacion como una caja sobre su casilla, del color de su tipo.
func _draw_drop(font: Font) -> void:
	var center := Vector2(cell_point(_drop["cell"]).x, -44.0 - 430.0 * (1.0 - _drop_fall))
	var color: Color = DROP_COLORS.get(_drop["kind"], Color.WHITE)
	var box := Rect2(center - Vector2(34, 28), Vector2(68, 56))
	_floor.draw_rect(box, color.darkened(0.55))
	_floor.draw_rect(box, color, false, 4.0)
	_floor.draw_line(center + Vector2(0, 28), Vector2(center.x, 0), color.darkened(0.3), 3.0)
	_floor.draw_string(
		font,
		box.position + Vector2(0, 36),
		Txt.t("drop_%s_short" % _drop["kind"]),
		HORIZONTAL_ALIGNMENT_CENTER,
		box.size.x,
		20,
		color.lightened(0.4)
	)


## Si la bonificacion queda fuera de la vista, una flecha en el borde dice
## hacia donde esta y de que tipo es.
func _draw_overlay() -> void:
	if _drop.is_empty():
		return
	var screen_x := _world.position.x + cell_point(_drop["cell"]).x * _zoom
	if screen_x >= 30.0 and screen_x <= size.x - 30.0:
		return
	var right := screen_x > size.x / 2.0
	var color: Color = DROP_COLORS.get(_drop["kind"], Color.WHITE)
	var tip := Vector2(size.x - 14.0 if right else 14.0, size.y - FLOOR_MARGIN - 70.0)
	var back := -34.0 if right else 34.0
	var arrow := PackedVector2Array([tip, tip + Vector2(back, -20.0), tip + Vector2(back, 20.0)])
	_overlay.draw_colored_polygon(arrow, color)
	var label_x := tip.x + (back * 3.2 if right else back * 1.2)
	_overlay.draw_string(
		get_theme_default_font(),
		Vector2(label_x, tip.y + 7.0),
		Txt.t("drop_%s_short" % _drop["kind"]),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		20,
		color.lightened(0.3)
	)


# --- Paisaje de fondo (coordenadas de pantalla) -----------------------------------


## Cambia el escenario: colores y elementos del paisaje (data/stages.json).
func set_stage(stage: Dictionary) -> void:
	_stage = DEFAULT_STAGE.duplicate(true)
	_stage.merge(stage, true)
	_floor.queue_redraw()


func _draw() -> void:
	var horizon := size.y - FLOOR_MARGIN
	var top: Color = _stage["sky_top"]
	var low: Color = _stage["sky_horizon"]
	var bands := 16
	for i in bands:
		var t := float(i) / float(bands - 1)
		var band := Rect2(0, horizon * i / bands, size.x, horizon / bands + 1.0)
		draw_rect(band, top.lerp(low, t * t))
	var shift := _camera_shift()
	_draw_stars(shift * PARALLAX_STARS, horizon)
	_draw_body(shift * PARALLAX_PLANET, horizon)
	_draw_ships(shift * PARALLAX_SHIPS, horizon)
	_draw_layer(_stage["far"], shift * PARALLAX_FAR, horizon, 11.0)
	_draw_layer(_stage["near"], shift * PARALLAX_NEAR, horizon, 47.0)
	_draw_ambient(shift * PARALLAX_NEAR, horizon)
	# Bruma sobre el horizonte, para separar el fondo del suelo.
	var haze: Color = _stage["haze"]
	for i in 6:
		var strip := Rect2(0, horizon - 60.0 + i * 10.0, size.x, 10.0)
		draw_rect(strip, Color(haze.r, haze.g, haze.b, haze.a * (i + 1) / 6.0))


## Numero entre 0 y 1 que depende solo de sus argumentos: el paisaje es
## siempre el mismo sin guardar nada.
func _noise(index: float, salt: float) -> float:
	return fposmod(sin(index * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


func _draw_stars(offset: float, horizon: float) -> void:
	var span := size.x + 200.0
	for i in int(_stage["stars"]):
		var x := fposmod(_noise(i, 1.0) * span - offset, span) - 100.0
		var y := _noise(i, 2.0) * horizon * 0.85
		var twinkle := 0.55 + 0.45 * sin(_time * (0.6 + _noise(i, 3.0) * 2.0) + i)
		var radius := 1.0 + _noise(i, 4.0) * 1.6
		draw_circle(Vector2(x, y), radius, Color(0.85, 0.9, 1.0, 0.25 + 0.6 * twinkle))


## El astro del escenario: un planeta con anillo, dos soles o un gigante que
## ocupa media pantalla.
func _draw_body(offset: float, horizon: float) -> void:
	var color: Color = _stage["body_color"]
	match str(_stage["body"]):
		"planet":
			var center := Vector2(size.x * 0.74 - offset, horizon * 0.36)
			draw_circle(center, 96.0, color.darkened(0.25))
			draw_circle(center + Vector2(-22, -16), 96.0, color)
			draw_circle(center + Vector2(30, 24), 70.0, Color(0.1, 0.08, 0.2, 0.35))
			draw_arc(center, 138.0, -0.5, 0.9, 40, color.lightened(0.45) * Color(1, 1, 1, 0.4), 3.0)
			draw_circle(center + Vector2(-190, -70), 20.0, color.lightened(0.25))
		"suns":
			var big := Vector2(size.x * 0.3 - offset, horizon * 0.42)
			for i in 4:
				draw_circle(big, 150.0 - 26.0 * i, Color(color.r, color.g, color.b, 0.12 + 0.1 * i))
			draw_circle(big, 62.0, color.lightened(0.3))
			draw_circle(big + Vector2(210, -70), 26.0, Color("ff9a5a"))
		"giant":
			var center := Vector2(size.x * 0.68 - offset, horizon + 250.0)
			draw_circle(center, 560.0, color.darkened(0.45))
			draw_circle(center + Vector2(-30, -26), 545.0, color.darkened(0.2))
			for i in 5:
				var band_y := horizon - 60.0 - 44.0 * i
				var alpha := 0.1 + 0.03 * i
				draw_line(
					Vector2(0, band_y),
					Vector2(size.x, band_y + 16.0),
					color.lightened(0.4) * Color(1, 1, 1, alpha),
					9.0
				)


## Naves que cruzan el cielo a distintas alturas y velocidades.
func _draw_ships(offset: float, horizon: float) -> void:
	var span := size.x + 400.0
	for i in int(_stage["ships"]):
		var direction := 1.0 if i % 2 == 0 else -1.0
		var speed := 26.0 + 18.0 * i
		var x := fposmod(direction * _time * speed + _noise(i, 5.0) * span - offset, span) - 200.0
		var y := horizon * (0.14 + 0.11 * (i % 4)) + sin(_time * 0.7 + i) * 6.0
		var length := 34.0 + 10.0 * (i % 3)
		var nose := Vector2(x + direction * length, y)
		var hull := PackedVector2Array(
			[
				nose,
				Vector2(x, y - 7.0),
				Vector2(x - direction * length * 0.6, y),
				Vector2(x, y + 5.0)
			]
		)
		var top: Color = _stage["sky_top"]
		draw_colored_polygon(hull, top.lightened(0.16))
		var glow := 0.6 + 0.4 * sin(_time * 9.0 + i * 2.0)
		draw_circle(Vector2(x - direction * length * 0.62, y), 3.5, Color(0.45, 0.9, 1.0, glow))


## Una capa del paisaje segun su estilo.
func _draw_layer(layer: Dictionary, offset: float, horizon: float, salt: float) -> void:
	var color: Color = layer["color"]
	var height := float(layer["height"])
	var tile := float(layer["tile"])
	match str(layer["style"]):
		"towers":
			_draw_towers(offset, horizon, tile, height, color, salt)
		"dunes":
			_draw_dunes(offset, horizon, tile, height, color, salt)
		"peaks":
			_draw_peaks(offset, horizon, tile, height, color, salt)
		"trusses":
			_draw_trusses(offset, horizon, tile, height, color, salt)


## Una fila de torres. Cada una sale del numero de su tramo, asi que el
## paisaje se repite igual al volver sobre el mismo sitio.
func _draw_towers(
	offset: float, horizon: float, tile: float, max_height: float, color: Color, salt: float
) -> void:
	var first := int(floor(offset / tile)) - 1
	for step in int(size.x / tile) + 3:
		var index := first + step
		var x := index * tile - offset
		var height := 30.0 + _noise(index, salt) * max_height
		var width := tile * (0.35 + 0.4 * _noise(index, salt + 1.0))
		draw_rect(Rect2(x, horizon - height, width, height), color)
		# Antena y luz de aviso que parpadea en algunas torres.
		if _noise(index, salt + 2.0) > 0.45:
			var top := Vector2(x + width / 2.0, horizon - height)
			draw_line(top, top - Vector2(0, 26), color, 3.0)
			var blink := 0.5 + 0.5 * sin(_time * 2.2 + index * 1.7)
			draw_circle(top - Vector2(0, 28), 3.0, Color(1.0, 0.3, 0.25, blink))
		# Ventanas encendidas que tiemblan un poco.
		for row in int(height / 26.0):
			if _noise(index * 7.0 + row, salt + 3.0) > 0.6:
				var flicker := 0.35 + 0.25 * sin(_time * 1.3 + index + row * 2.0)
				var y := horizon - height + 12.0 + row * 26.0
				draw_rect(
					Rect2(x + width * 0.25, y, width * 0.5, 5.0), Color(0.55, 0.85, 1.0, flicker)
				)


## Dunas: una sola silueta ondulada.
func _draw_dunes(
	offset: float, horizon: float, tile: float, max_height: float, color: Color, salt: float
) -> void:
	var points := PackedVector2Array([Vector2(0, horizon)])
	var x := 0.0
	while x <= size.x + 24.0:
		var world := (x + offset) / tile
		var wave := (
			0.5 + 0.35 * sin(world * TAU + salt) + 0.15 * sin(world * TAU * 2.7 + salt * 2.0)
		)
		points.append(Vector2(x, horizon - 20.0 - wave * max_height))
		x += 24.0
	points.append(Vector2(size.x, horizon))
	draw_colored_polygon(points, color)


## Picos de roca, uno por tramo, con algun resto clavado en lo alto.
func _draw_peaks(
	offset: float, horizon: float, tile: float, max_height: float, color: Color, salt: float
) -> void:
	var first := int(floor(offset / tile)) - 1
	for step in int(size.x / tile) + 3:
		var index := first + step
		var x := index * tile - offset
		var height := 40.0 + _noise(index, salt) * max_height
		var lean := (_noise(index, salt + 1.0) - 0.5) * tile * 0.5
		var peak := Vector2(x + tile * 0.5 + lean, horizon - height)
		draw_colored_polygon(
			PackedVector2Array(
				[Vector2(x - tile * 0.2, horizon), peak, Vector2(x + tile * 1.2, horizon)]
			),
			color
		)
		if _noise(index, salt + 2.0) > 0.6:
			draw_line(peak, peak + Vector2(18, -34), color.lightened(0.12), 4.0)
			var blink := 0.5 + 0.5 * sin(_time * 1.6 + index)
			draw_circle(peak + Vector2(18, -36), 2.5, Color(1.0, 0.75, 0.3, blink))


## Estructura metalica: columnas, vigas cruzadas y luces de posicion.
func _draw_trusses(
	offset: float, horizon: float, tile: float, max_height: float, color: Color, salt: float
) -> void:
	var first := int(floor(offset / tile)) - 1
	var beam_y := horizon - max_height * 0.72
	draw_rect(Rect2(0, beam_y, size.x, 10.0), color)
	for step in int(size.x / tile) + 3:
		var index := first + step
		var x := index * tile - offset
		var height := max_height * (0.75 + 0.25 * _noise(index, salt))
		draw_rect(Rect2(x, horizon - height, 14.0, height), color)
		draw_line(Vector2(x + 7.0, beam_y), Vector2(x + tile + 7.0, horizon - 24.0), color, 4.0)
		draw_line(Vector2(x + tile + 7.0, beam_y), Vector2(x + 7.0, horizon - 24.0), color, 4.0)
		var blink := 0.5 + 0.5 * sin(_time * 2.6 + index * 2.1)
		draw_circle(Vector2(x + 7.0, horizon - height - 4.0), 3.0, Color(0.4, 1.0, 0.85, blink))


## Lo que flota en el aire: polvo que pasa o chispas que caen.
func _draw_ambient(offset: float, horizon: float) -> void:
	var kind := str(_stage["ambient"])
	if kind == "none":
		return
	var span := size.x + 120.0
	for i in 46:
		var drift := _time * (30.0 + 40.0 * _noise(i, 31.0))
		if kind == "dust":
			var x := fposmod(_noise(i, 32.0) * span + drift - offset, span) - 60.0
			var y := horizon * (0.45 + 0.55 * _noise(i, 33.0)) + sin(_time + i) * 5.0
			draw_circle(Vector2(x, y), 1.5 + 2.0 * _noise(i, 34.0), Color(1.0, 0.8, 0.6, 0.22))
		else:
			var x := fposmod(_noise(i, 32.0) * span - offset, span) - 60.0
			var y := fposmod(_noise(i, 33.0) * horizon + drift, horizon)
			var alpha := 0.25 + 0.5 * absf(sin(_time * 6.0 + i))
			draw_line(Vector2(x, y), Vector2(x - 2.0, y - 7.0), Color(1.0, 0.85, 0.5, alpha), 2.0)


# --- Raton -------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_at(event.position)
		if cell != _hovered:
			_hovered = cell
			_floor.queue_redraw()
			cell_hovered.emit(cell)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var cell := _cell_at(event.position)
			if cell >= 0:
				cell_clicked.emit(cell)


func _on_mouse_exited() -> void:
	_hovered = -1
	_floor.queue_redraw()
	cell_hovered.emit(-1)


## Casilla que hay bajo un punto de la vista, o -1 si cae fuera del campo.
func _cell_at(point: Vector2) -> int:
	var world_x := (point.x - _world.position.x) / maxf(_zoom, 0.01)
	if world_x < 0.0 or world_x >= world_width():
		return -1
	return clampi(int(world_x / CELL_WIDTH), 0, cells - 1)
