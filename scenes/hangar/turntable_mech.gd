class_name TurntableMech
extends Node2D
## El robot del hangar girando sobre su plataforma (pedido del usuario el
## 2026-11-19: "que el robot se pueda rotar 360 grados").
##
## Las piezas solo estan dibujadas de perfil, asi que el giro se hace con ese
## mismo dibujo partido en capas con fondo y grosor: las armas de un lado, una
## pierna, el cuerpo, la otra pierna y las armas del otro lado. Cada capa es
## una vista del propio MechView (`only_layer`) y gira como una plancha gruesa
## alrededor del eje de la plataforma: su cara es el dibujo y su canto, un
## color liso oscuro. De lado es exactamente el dibujo del combate (por la
## otra cara, el otro costado del robot); al pasar por el frente y la espalda
## se ve de canto, en bloques, porque esas caras no estan dibujadas.

## Capas: su nombre en MechView, de que lado van (-1 el lejano con el robot
## de perfil, 1 el cercano), cuanto se apagan al quedar detras y los huecos
## cuyas piezas llevan (para saber cuanto ocupan). Su fondo y su grosor salen
## de las piezas de cada robot (`_measure`).
const LAYERS: Array[Dictionary] = [
	{"name": "far", "side": -1.0, "dim": 0.62, "slots": ["side2", "side3", "top1"]},
	{"name": "far_leg", "side": -1.0, "dim": 0.65, "slots": ["legs"]},
	{"name": "body", "side": 0.0, "dim": 1.0, "slots": ["torso", "chest", "legs"]},
	{"name": "near_leg", "side": 1.0, "dim": 0.65, "slots": ["legs"]},
	{"name": "near", "side": 1.0, "dim": 0.62, "slots": ["side0", "side1", "top0"]},
	{"name": "float", "side": 1.0, "dim": 0.8, "slots": ["assist"]},
]
## Ancho del robot visto de frente, como parte de lo que miden de perfil su
## torso y sus piernas: el tronco y las piernas comparten ese ancho, asi que
## unas piernas mas anchas ensanchan el tronco y al reves (pedido del usuario
## el 2026-11-19). Una base de una pieza (orugas, ruedas, levitar) manda mas.
const WIDTH_FROM_TORSO := 0.2
const WIDTH_FROM_LEGS := 0.2
const WIDTH_FROM_TORSO_ON_BASE := 0.14
const WIDTH_FROM_BASE := 0.3
## Grosor de cada pierna, como parte del ancho del robot; van a ras del tronco.
const LEG_SHARE := 0.36
## Grosor de un arma y del asistente, y el aire entre capas.
const WEAPON_THICK := 12.0
const LAYER_GAP := 3.0
## El canto de una plancha se dibuja con copias de su silueta, una cada
## tantos pixeles de pantalla; la de detras, mas oscura.
const WALL_STEP := 2.0
const WALL_MAX_COPIES := 40
const WALL_BACK := 0.72
## La copia de en medio va algo mas oscura: se ve como una junta en el canto.
const WALL_SEAM := 0.8
## Linea de contorno por detras del canto, en pixeles de pantalla.
const WALL_OUTLINE := 1.6
## Ancho minimo de una plancha vista de canto, como parte de su ancho: de
## canto del todo el robot es una version estrecha de su silueta.
const MIN_WIDTH := 0.1
## Por debajo de este coseno la cara ya no se distingue: se pinta lisa, como
## el canto. Hasta el triple, se va apagando.
const FLAT_BELOW := 0.07
const FLAT_SHADE := 0.45
## Lo que se apaga el robot al dar la espalda a la luz.
const TURN_SHADE := 0.22
## Pixeles de cada vista por unidad del taller: algo mas que el aumento del
## hangar, para que no se vea borroso.
const RENDER_SCALE := 1.4
const MARGIN := 48.0
## Lo que crece la zona de cada capa alrededor de sus piezas (respiran).
const REGION_GROW := 30.0
## Pinta solo la silueta, del color con que se dibuja.
const SILHOUETTE := """shader_type canvas_item;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a);
}
"""

## Giro en radianes: 0 = de perfil mirando a la derecha.
var angle: float = 0.0:
	set(value):
		angle = wrapf(value, 0.0, TAU)
		_redraw()

var _views: Dictionary[String, SubViewport] = {}
var _mechs: Dictionary[String, MechView] = {}
var _walls: Dictionary[String, Node2D] = {}
var _faces: Dictionary[String, Node2D] = {}
## Zona de cada capa, en unidades del taller respecto a los pies.
var _regions: Dictionary[String, Rect2] = {}
## Fondo (x) y grosor (y) de cada capa, en unidades del taller.
var _depths: Dictionary[String, Vector2] = {}
## Lo que ocupa el robot, respecto a sus pies, en unidades del taller.
var _canvas := Rect2()
## Eje del giro (el centro de la plataforma).
var _pivot_x: float = 0.0
var _wall_color := Color("3a2416")
## Hacia donde mira el robot con el orden de capas que hay puesto.
var _ordered_for: float = 0.0


## Arma las capas con este equipo. `bounds`: lo que ocupa el robot en el
## taller; `pivot_x`: el eje del giro.
func setup(
	build: MechBuild, ghosts: Array[String], bounds: Rect2, pivot_x: float, deployed: bool
) -> void:
	_canvas = bounds.grow(MARGIN)
	_pivot_x = pivot_x
	var base: Color = MechView.ELEMENT_COLORS[build.torso.element]
	_wall_color = base.darkened(0.5).lerp(MechView.OUTLINE, 0.22)
	var pixels := Vector2i((_canvas.size * RENDER_SCALE).ceil())
	for layer: Dictionary in LAYERS:
		var layer_name: String = layer["name"]
		if not _views.has(layer_name):
			_add_layer(layer)
		_views[layer_name].size = pixels
		var mech := _mechs[layer_name]
		mech.setup(build, 1)
		mech.ghost_slots = ghosts
		if deployed:
			mech.show_deployed()
		mech.place(-_canvas.position * RENDER_SCALE)
		mech.scale *= RENDER_SCALE
		_regions[layer_name] = _region_of(mech, layer["slots"])
	_measure(_mechs["body"])
	_ordered_for = 0.0
	_redraw()


## Ancho del robot visto de frente, en unidades del taller (ver WIDTH_*).
func body_width() -> float:
	return _depths["body"].y if _depths.has("body") else 0.0


## Reparte el fondo del robot segun sus piezas: el tronco y las piernas
## ocupan el mismo ancho (las piernas, a ras por fuera) y las armas van por
## fuera, a cada lado.
func _measure(mech: MechView) -> void:
	var torso := mech.slot_rect("torso").size.x
	var legs := mech.slot_rect("legs").size.x
	var width := WIDTH_FROM_TORSO * torso + WIDTH_FROM_LEGS * legs
	if mech.has_rigid_legs():
		width = WIDTH_FROM_TORSO_ON_BASE * torso + WIDTH_FROM_BASE * legs
	var leg := width * LEG_SHARE
	var weapon := width * 0.5 + LAYER_GAP + WEAPON_THICK * 0.5
	_depths = {
		"body": Vector2(0.0, width),
		"far_leg": Vector2(-(width - leg) * 0.5, leg),
		"near_leg": Vector2((width - leg) * 0.5, leg),
		"far": Vector2(-weapon, WEAPON_THICK),
		"near": Vector2(weapon, WEAPON_THICK),
		"float": Vector2(weapon + WEAPON_THICK + LAYER_GAP, WEAPON_THICK),
	}


func _add_layer(layer: Dictionary) -> void:
	var layer_name: String = layer["name"]
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var view := MechView.new()
	view.only_layer = layer_name
	viewport.add_child(view)
	_views[layer_name] = viewport
	_mechs[layer_name] = view
	var wall := Node2D.new()
	var silhouette := ShaderMaterial.new()
	silhouette.shader = Shader.new()
	silhouette.shader.code = SILHOUETTE
	wall.material = silhouette
	wall.draw.connect(_draw_wall.bind(layer))
	add_child(wall)
	_walls[layer_name] = wall
	var face := Node2D.new()
	face.draw.connect(_draw_face.bind(layer))
	add_child(face)
	_faces[layer_name] = face


## Zona que ocupan las piezas de esos huecos, en unidades del taller; vacia
## si no hay ninguna.
func _region_of(mech: MechView, slots: Array) -> Rect2:
	var region := Rect2()
	for slot: String in slots:
		var rect := mech.slot_rect(slot)
		if rect.size == Vector2.ZERO:
			continue
		var a := mech.transform * rect.position / RENDER_SCALE + _canvas.position
		var b := mech.transform * rect.end / RENDER_SCALE + _canvas.position
		var placed := Rect2(a, b - a).abs()
		region = placed if region.size == Vector2.ZERO else region.merge(placed)
	if region.size == Vector2.ZERO:
		return region
	return region.grow(REGION_GROW).intersection(_canvas)


## Enciende o apaga el giro: apagado no se ve ni gasta.
func set_active(on: bool) -> void:
	visible = on
	var mode := SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	for viewport: SubViewport in _views.values():
		viewport.render_target_update_mode = mode


func _process(_delta: float) -> void:
	if visible:
		_redraw()


## Vuelve a pintar las capas, de la de detras a la de delante.
func _redraw() -> void:
	var toward := 1.0 if cos(angle) >= 0.0 else -1.0
	if toward != _ordered_for and not _walls.is_empty():
		_ordered_for = toward
		var order := LAYERS.duplicate()
		order.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				return _depths[a["name"]].x * toward < _depths[b["name"]].x * toward
		)
		var index := _views.size()
		for layer: Dictionary in order:
			move_child(_walls[layer["name"]], index)
			move_child(_faces[layer["name"]], index + 1)
			index += 2
	for node: Node2D in _walls.values():
		node.queue_redraw()
	for node: Node2D in _faces.values():
		node.queue_redraw()


## Cuanta luz le llega a una capa: menos si queda detras y con el robot de
## espaldas a la luz.
func _light(layer: Dictionary) -> float:
	var c := cos(angle)
	var behind := clampf(-float(layer["side"]) * c, 0.0, 1.0)
	return lerpf(1.0, layer["dim"], behind) * (1.0 - TURN_SHADE * (1.0 - absf(c)))


## El canto de una plancha: copias lisas de su silueta, de la cara de detras
## a la de delante.
func _draw_wall(layer: Dictionary) -> void:
	var layer_name: String = layer["name"]
	var region := _regions[layer_name]
	var c := cos(angle)
	var s := sin(angle)
	if region.size == Vector2.ZERO or absf(s) < 0.02:
		return
	var node := _walls[layer_name]
	var texture := _views[layer_name].get_texture()
	var facing := 1.0 if c >= 0.0 else -1.0
	var depth := _depths[layer_name]
	var half := depth.y * 0.5
	var light := _light(layer)
	var zoom := absf(get_global_transform().get_scale().x)
	var on_screen := depth.y * absf(s) * zoom
	var copies := clampi(ceili(on_screen / WALL_STEP), 1, WALL_MAX_COPIES)
	# Contorno: la silueta de la cara de detras, un poco mas atras.
	var back := (depth.x - facing * half) * s
	var outward := -signf(facing * s) * WALL_OUTLINE / maxf(zoom, 0.01)
	_card(node, texture, region, back + outward, Color(MechView.OUTLINE, 1.0))
	for k in copies:
		var t := float(k) / copies
		var z := depth.x + facing * half * (2.0 * t - 1.0)
		var shade := lerpf(WALL_BACK, 1.0, t) * light
		if copies >= 6 and k == copies / 2:
			shade *= WALL_SEAM
		_card(node, texture, region, z * s, Color(_wall_color * shade, 1.0))
	if absf(c) < FLAT_BELOW:
		# De canto: la cara tambien va lisa, algo mas clara.
		var front := depth.x + facing * half
		_card(node, texture, region, front * s, Color(_wall_color * light * 1.25, 1.0))


## La cara de una plancha: el dibujo de la capa.
func _draw_face(layer: Dictionary) -> void:
	var layer_name: String = layer["name"]
	var region := _regions[layer_name]
	var c := cos(angle)
	if region.size == Vector2.ZERO or absf(c) < FLAT_BELOW:
		return
	var facing := 1.0 if c >= 0.0 else -1.0
	var fade := smoothstep(FLAT_BELOW, FLAT_BELOW * 3.0, absf(c))
	var bright := _light(layer) * lerpf(FLAT_SHADE, 1.0, fade)
	var depth := _depths[layer_name]
	var front := depth.x + facing * depth.y * 0.5
	var texture := _views[layer_name].get_texture()
	_card(_faces[layer_name], texture, region, front * sin(angle), Color(bright, bright, bright))


## Una plancha: la zona de la capa, estrechada alrededor del eje y movida.
func _card(node: Node2D, texture: Texture2D, region: Rect2, shift: float, color: Color) -> void:
	var c := cos(angle)
	var squash := (1.0 if c >= 0.0 else -1.0) * maxf(absf(c), MIN_WIDTH)
	var origin := Vector2(_pivot_x * (1.0 - squash) + shift, 0.0)
	node.draw_set_transform_matrix(Transform2D(Vector2(squash, 0.0), Vector2(0.0, 1.0), origin))
	var source := Rect2(
		(region.position - _canvas.position) * RENDER_SCALE, region.size * RENDER_SCALE
	)
	node.draw_texture_rect_region(texture, region, source, color)
