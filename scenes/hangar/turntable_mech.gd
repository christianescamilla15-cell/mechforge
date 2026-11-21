class_name TurntableMech
extends Node2D
## El robot del hangar girando sobre su plataforma (pedido del usuario el
## 2026-11-19: "que el robot se pueda rotar 360 grados"; y el 2026-11-20, al
## verlo de canto: "se ve incompleto en 90 grados").
##
## Cada parte del robot gira como un cuerpo con volumen. Su forma sale de dos
## dibujos: el de perfil (el del combate: una capa de MechView, `only_layer`)
## y el de frente de esa pieza ("frente_<juego>", sacado de su propio perfil
## con tools/art/turn_test.py). Un punto esta dentro del cuerpo si cae dentro
## de las dos siluetas. Lo que se ve de costado lleva el dibujo de perfil; lo
## que se ve de cara, el de frente, y por detras el de espalda
## ("espalda_<juego>"). El sombreador SOLID recorre cada rayo de vista hasta
## dar con el cuerpo.
##
## Lo que no tiene dibujo de frente (las armas, el canon de pecho, o un torso
## o unas piernas a los que les falte) es una plancha con grosor, y su canto
## lleva los colores del borde de su propio dibujo. Las armas se abren un
## poco hacia fuera al girar, para que de frente no queden de canto. El
## asistente flota siempre de lado.

## Capas: su nombre en MechView, su tipo, de que lado van (-1 el lejano con
## el robot de perfil, 1 el cercano), cuanto se apagan al quedar detras y los
## huecos cuyas piezas llevan (para saber cuanto ocupan). Su fondo y su
## grosor salen de las piezas de cada robot (`_measure`).
const LAYERS: Array[Dictionary] = [
	{"name": "far", "kind": "arm", "side": -1.0, "dim": 0.62, "slots": ["side2", "side3"]},
	{"name": "far_top", "kind": "top", "side": -1.0, "dim": 0.62, "slots": ["top1"]},
	{"name": "far_leg", "kind": "leg", "side": -1.0, "dim": 0.65, "slots": ["legs"]},
	{"name": "body", "kind": "body", "side": 0.0, "dim": 1.0, "slots": ["torso"]},
	{"name": "chest", "kind": "chest", "side": 0.0, "dim": 1.0, "slots": ["chest"]},
	{"name": "near_leg", "kind": "leg", "side": 1.0, "dim": 0.65, "slots": ["legs"]},
	{"name": "near_top", "kind": "top", "side": 1.0, "dim": 0.62, "slots": ["top0"]},
	{"name": "near", "kind": "arm", "side": 1.0, "dim": 0.62, "slots": ["side0", "side1"]},
	{"name": "float", "kind": "float", "side": 0.0, "dim": 1.0, "slots": ["assist"]},
]
## Juegos de sprites con la pieza vista de frente y de espalda.
const FRONT := "frente_"
const BACK := "espalda_"
## Sin dibujo de frente, el ancho del robot es una parte de lo que miden de
## perfil su torso y sus piernas; una base de una pieza (orugas, ruedas,
## levitar) manda mas. Con dibujo de frente, el ancho es la media del de su
## torso y el de sus piernas, y los dos se ajustan a ese ancho: unas piernas
## mas anchas ensanchan el tronco y al reves (pedido del usuario el
## 2026-11-19).
const WIDTH_FROM_TORSO := 0.2
const WIDTH_FROM_LEGS := 0.2
const WIDTH_FROM_TORSO_ON_BASE := 0.14
const WIDTH_FROM_BASE := 0.3
## Sin dibujo de frente: grosor de cada pierna, como parte del ancho del
## robot; van a ras del tronco.
const LEG_SHARE := 0.36
## A que distancia del eje van las armas de brazo y las de hombro, como parte
## del ancho del robot, y su grosor.
const ARM_OUT := 0.5
const TOP_OUT := 0.24
const WEAPON_THICK := 14.0
## Grosor del canon de pecho, como parte de su alto.
const CHEST_SHARE := 0.6
## Cuanto se abren las armas hacia fuera con el robot de frente o de espalda.
const TOE_OUT := deg_to_rad(24.0)
## Una cara vista casi de canto recibe esta parte de la luz.
const FACE_SHADE := 0.6
## Con dibujo de frente, solo se ve a plena luz el dibujo que mas mira al
## que observa (el de perfil o el de frente); el otro queda en sombra, para
## que no se vea la misma pieza dos veces. El cambio se hace entre estos dos
## cosenos del giro (de unos 47 a unos 53 grados del perfil): pasado el medio
## giro de 45 grados, donde para la rueda del raton, para que ahi no se vean
## los dos a medias.
const LIT_FROM := 0.6
const LIT_FULL := 0.68
## Luz que recibe la cara en sombra y cuanto se va al color liso del canto.
const SHADOW_LIGHT := 0.5
const SHADOW_FLAT := 0.6
## Pixeles de cada vista de perfil por unidad del taller (algo mas que el
## aumento del hangar, para que no se vea borroso) y de cada lienzo de frente.
const RENDER_SCALE := 1.4
const FRONT_SCALE := 1.8
## Aire a cada lado del lienzo de frente, en unidades.
const FRONT_PAD := 4.0
const MARGIN := 48.0
## Lo que crece la zona de cada capa alrededor de sus piezas (respiran).
const REGION_GROW := 30.0
## Paso del rayo de vista, en pixeles de la vista de perfil.
const STEP_PIXELS := 2.0
## Tinte de una pieza que falta (como MechView._ghost_tint).
const GHOST := Color(0.55, 0.66, 0.82, 0.22)
## Cuerpo con volumen a partir de sus siluetas de perfil y de frente.
## `at`: punto de la pantalla, en unidades del taller. Cada rayo avanza en
## fondo `w` desde el que mira; (x, z) son el largo y el ancho del robot.
const SOLID := """shader_type canvas_item;

uniform sampler2D profile : filter_linear, repeat_disable;
uniform sampler2D front : filter_linear, repeat_disable;
uniform sampler2D back : filter_linear, repeat_disable;
uniform bool has_front = false;
uniform bool has_back = false;
uniform vec4 canvas = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 box = vec4(0.0);
uniform vec2 pivot = vec2(0.0);
uniform float pivot_x = 0.0;
uniform vec2 turn = vec2(1.0, 0.0);
uniform float front_half = 1.0;
uniform float bob = 0.0;
uniform float step_units = 1.4;
uniform vec3 wall = vec3(0.2);
uniform vec3 ink = vec3(0.06, 0.08, 0.11);
uniform vec2 light = vec2(1.0);
uniform vec2 shadow = vec2(0.0);
uniform float slope_light = 0.22;
uniform vec4 tint = vec4(1.0);

varying vec2 at;

void vertex() {
	at = VERTEX;
}

vec4 side_art(float x, float y) {
	return texture(profile, (vec2(x, y) - canvas.xy) / canvas.zw);
}

float depth_alpha(float z, float y) {
	if (has_front) {
		return texture(front, vec2(0.5 - z / (2.0 * front_half), (y - bob - canvas.y) / canvas.w)).a;
	}
	return step(box.z, z) * step(z, box.w);
}

void fragment() {
	float c = turn.x;
	float s = turn.y;
	float dx = at.x - pivot_x;
	float y = at.y;
	vec2 xr = box.xy - pivot.x;
	vec2 zr = box.zw - pivot.y;
	float lo = -100000.0;
	float hi = 100000.0;
	bool side_entry = true;
	bool miss = false;
	if (abs(c) > 0.0005) {
		float a = (zr.x - dx * s) / c;
		float b = (zr.y - dx * s) / c;
		lo = min(a, b);
		hi = max(a, b);
	} else if (dx * s < zr.x || dx * s > zr.y) {
		miss = true;
	}
	if (abs(s) > 0.0005) {
		float a = (dx * c - xr.x) / s;
		float b = (dx * c - xr.y) / s;
		lo = max(lo, min(a, b));
		if (max(a, b) < hi) {
			hi = max(a, b);
			side_entry = false;
		}
	} else if (dx * c < xr.x || dx * c > xr.y) {
		miss = true;
	}
	if (miss || hi <= lo) {
		discard;
	}
	float len = hi - lo;
	int n = clamp(int(ceil(len / step_units)), 2, 160);
	float dw = len / float(n);
	float best = 0.0;
	bool found = false;
	bool on_wall = false;
	float w_out = hi;
	float w_in = hi;
	bool was_side = false;
	bool was_depth = false;
	for (int i = 0; i < n; i++) {
		float w = hi - dw * (float(i) + 0.5);
		float x = pivot.x + dx * c - w * s;
		float z = pivot.y + dx * s + w * c;
		float pa = side_art(x, y).a;
		float fa = depth_alpha(z, y);
		float m = min(pa, fa);
		best = max(best, m);
		if (m > 0.5) {
			found = true;
			w_in = w;
			if (i == 0) {
				on_wall = !side_entry;
			} else if (was_side != was_depth) {
				on_wall = was_depth;
			} else {
				on_wall = abs(s) > abs(c);
			}
			break;
		}
		was_side = pa > 0.5;
		was_depth = fa > 0.5;
		w_out = w;
	}
	if (!found) {
		COLOR = vec4(ink, smoothstep(0.2, 0.5, best)) * tint;
	} else {
		for (int k = 0; k < 5; k++) {
			float w = 0.5 * (w_out + w_in);
			float x = pivot.x + dx * c - w * s;
			float z = pivot.y + dx * s + w * c;
			if (min(side_art(x, y).a, depth_alpha(z, y)) > 0.5) {
				w_in = w;
			} else {
				w_out = w;
			}
		}
		float x = pivot.x + dx * c - w_in * s;
		float z = pivot.y + dx * s + w_in * c;
		// Relieve: la luz viene de arriba, asi que lo que mira hacia arriba
		// se aclara y lo que mira hacia abajo se oscurece. La pendiente sale
		// del borde de la silueta por la que entro el rayo.
		vec2 grade = vec2(0.0);
		if (on_wall) {
			grade = vec2(
				side_art(x + 1.5, y).a - side_art(x - 1.5, y).a,
				side_art(x, y + 1.5).a - side_art(x, y - 1.5).a
			);
		} else if (has_front) {
			grade = vec2(
				depth_alpha(z + 1.5, y) - depth_alpha(z - 1.5, y),
				depth_alpha(z, y + 1.5) - depth_alpha(z, y - 1.5)
			);
		}
		// Una cara vista de lleno es su dibujo tal cual: sin relieve.
		float glancing = on_wall ? abs(c) : abs(s);
		float relief = 1.0 + slope_light * glancing * grade.y / max(length(grade), 0.2);
		vec3 color;
		if (!on_wall) {
			color = mix(side_art(x, y).rgb, wall, shadow.x) * light.x;
		} else if (has_front && (s < 0.0 || has_back)) {
			float v = (y - bob - canvas.y) / canvas.w;
			float u = z / (2.0 * front_half);
			vec4 art = s < 0.0 ? texture(front, vec2(0.5 - u, v)) : texture(back, vec2(0.5 + u, v));
			color = mix(mix(wall, art.rgb, smoothstep(0.3, 0.7, art.a)), wall, shadow.y) * light.y;
		} else {
			// Sin dibujo de esa cara: los colores del borde de su perfil.
			vec4 deep = side_art(x + sign(s) * 3.0, y);
			vec3 base = deep.a > 0.6 ? deep.rgb : side_art(x, y).rgb;
			color = mix(base, wall, 0.35) * 0.82 * light.y;
		}
		COLOR = vec4(color * relief, 1.0) * tint;
	}
}
"""

static var _shader: Shader

## Giro en radianes: 0 = de perfil mirando a la derecha. A un cuarto de
## vuelta se le ve la espalda; a tres cuartos, de frente.
var angle: float = 0.0:
	set(value):
		angle = wrapf(value, 0.0, TAU)
		_redraw()

var _views: Dictionary[String, SubViewport] = {}
var _mechs: Dictionary[String, MechView] = {}
var _solids: Dictionary[String, Node2D] = {}
var _materials: Dictionary[String, ShaderMaterial] = {}
## Zona de cada capa, en unidades del taller respecto a los pies.
var _regions: Dictionary[String, Rect2] = {}
## Fondo (x) y grosor (y) de cada capa, en unidades del taller.
var _depths: Dictionary[String, Vector2] = {}
## Rectangulo de pantalla que pinta cada capa ahora mismo.
var _quads: Dictionary[String, Rect2] = {}
## Capas que tienen dibujo de frente (y de espalda).
var _fronts: Dictionary[String, Texture2D] = {}
var _backs: Dictionary[String, Texture2D] = {}
## Lo que ocupa el robot, respecto a sus pies, en unidades del taller.
var _canvas := Rect2()
## Eje del giro (el centro de la plataforma).
var _pivot_x: float = 0.0
## Unidades del taller por unidad de MechView.
var _unit: float = 1.0
## Medio ancho de los lienzos de frente, en unidades.
var _front_half: float = 1.0
var _wall_color := Color("3a2416")
## True si sus piernas levitan: su brillo va pintado en la plataforma.
var _hovers := false
## Capas, de la de detras a la de delante, tal como estan puestas.
var _order: Array[String] = []


## Arma las capas con este equipo. `bounds`: lo que ocupa el robot en el
## taller; `pivot_x`: el eje del giro.
func setup(
	build: MechBuild, ghosts: Array[String], bounds: Rect2, pivot_x: float, deployed: bool
) -> void:
	_canvas = bounds.grow(MARGIN)
	_pivot_x = pivot_x
	var base: Color = MechView.ELEMENT_COLORS[build.paint_of("torso")]
	_wall_color = base.darkened(0.5).lerp(MechView.OUTLINE, 0.22)
	var pixels := Vector2i((_canvas.size * RENDER_SCALE).ceil())
	for layer: Dictionary in LAYERS:
		var layer_name: String = layer["name"]
		if not _views.has(layer_name):
			_add_layer(layer)
		_views[layer_name].size = pixels
		var mech := _mechs[layer_name]
		mech.setup(build, 1)
		# Las piezas que faltan se tinen al pintar la capa, no en su vista.
		mech.ghost_slots = [] as Array[String]
		if deployed:
			mech.show_deployed()
		mech.place(-_canvas.position * RENDER_SCALE)
		mech.scale *= RENDER_SCALE
	var body := _mechs["body"]
	_unit = absf(body.scale.y) / RENDER_SCALE
	_hovers = body.rest_lift() < 0.0
	for layer: Dictionary in LAYERS:
		_regions[layer["name"]] = _region_of(body, _slots_of(layer, body))
	_measure(body)
	_bake(body, build)
	for layer: Dictionary in LAYERS:
		_dress(layer, ghosts)
	_order.clear()
	_redraw()


## Ancho del robot visto de frente, en unidades del taller.
func body_width() -> float:
	return _depths["body"].y if _depths.has("body") else 0.0


## True si esa capa gira con su dibujo de frente (si no, es una plancha).
func has_front(layer_name: String) -> bool:
	return _fronts.has(layer_name)


## Enciende o apaga el giro: apagado no se ve ni gasta.
func set_active(on: bool) -> void:
	visible = on
	var mode := SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	for viewport: SubViewport in _views.values():
		viewport.render_target_update_mode = mode


func _process(_delta: float) -> void:
	if visible:
		_redraw()


## El brillo de las piernas que levitan, sobre la plataforma: es redondo, asi
## que se ve igual desde cualquier lado (como MechView._draw_rigid_legs).
func _draw() -> void:
	if not _hovers:
		return
	var center := Vector2(_pivot_x - _pivot_x * cos(angle), -2.0 * _unit)
	var glow := MechView.HOVER_GLOW
	for i in 3:
		glow.a = 0.24 - 0.06 * i
		var radius := Vector2(70.0 + 16.0 * i, 8.0 + 3.0 * i) * _unit
		var points := PackedVector2Array()
		for k in 20:
			var around := TAU * k / 20.0
			points.append(center + Vector2(cos(around) * radius.x, sin(around) * radius.y))
		draw_colored_polygon(points, glow)


## Huecos cuyas piezas dibuja de verdad una capa en este robot: las piernas
## de una pieza van con el cuerpo, no en las capas de las piernas.
func _slots_of(layer: Dictionary, mech: MechView) -> Array:
	var rigid := mech.has_rigid_legs()
	match layer["kind"]:
		"body":
			return ["torso", "legs"] if rigid else ["torso"]
		"leg":
			return [] if rigid else ["legs"]
	return layer["slots"]


## Reparte el fondo del robot segun sus piezas: el tronco y las piernas
## ocupan el mismo ancho, y las armas van a los lados.
func _measure(mech: MechView) -> void:
	var torso := mech.slot_rect("torso").size.x * _unit
	var legs := mech.slot_rect("legs").size.x * _unit
	var width := WIDTH_FROM_TORSO * torso + WIDTH_FROM_LEGS * legs
	if mech.has_rigid_legs():
		width = WIDTH_FROM_TORSO_ON_BASE * torso + WIDTH_FROM_BASE * legs
	var leg := width * LEG_SHARE
	var art := _art(FRONT, mech)
	if not art.is_empty():
		var pixel := MechSprites.UNIT_SCALE * _unit
		width = 0.5 * (float(art["torso"]["size"][0]) + float(art["legs"]["size"][0])) * pixel
		# Cada pierna, medio dibujo de frente.
		leg = width * 0.5
	var chest := clampf(mech.slot_rect("chest").size.y * _unit * CHEST_SHARE, 10.0, 30.0)
	_front_half = width * 0.5 + FRONT_PAD
	_depths = {
		"body": Vector2(0.0, width),
		"chest": Vector2(0.0, chest),
		"far_leg": Vector2(-(width - leg) * 0.5, leg),
		"near_leg": Vector2((width - leg) * 0.5, leg),
		"far": Vector2(-width * ARM_OUT, WEAPON_THICK),
		"near": Vector2(width * ARM_OUT, WEAPON_THICK),
		"far_top": Vector2(-width * TOP_OUT, WEAPON_THICK),
		"near_top": Vector2(width * TOP_OUT, WEAPON_THICK),
		"float": Vector2.ZERO,
	}


## Anclas del torso y de las piernas de este robot en esa vista ("frente_" o
## "espalda_"): {"torso": {...}, "legs": {...}}; {} si le falta alguna.
func _art(prefix: String, mech: MechView) -> Dictionary:
	if mech.torso_set() == "" or mech.legs_set() == "":
		return {}
	var torso := MechSprites.piece_info(prefix + mech.torso_set(), "torso")
	var legs := MechSprites.piece_info(prefix + mech.legs_set(), "legs")
	if torso.is_empty() or legs.is_empty():
		return {}
	return {"torso": torso, "legs": legs}


## Lienzos de frente y de espalda de las capas con dibujo propio: el cuerpo
## y, si anda, cada pierna (media vista de las piernas cada una).
func _bake(mech: MechView, build: MechBuild) -> void:
	_fronts.clear()
	_backs.clear()
	var front := _art(FRONT, mech)
	var torso_hip := MechSprites.piece_info(mech.torso_set(), "torso")
	if front.is_empty() or torso_hip.is_empty():
		return
	# Cuanto se estira a lo ancho cada pieza para ajustarse al ancho del
	# robot; la espalda, lo mismo que su frente (tienen la misma silueta).
	var pixel := MechSprites.UNIT_SCALE * _unit
	var torso_fit := body_width() / (float(front["torso"]["size"][0]) * pixel)
	var legs_fit := body_width() / (float(front["legs"]["size"][0]) * pixel)
	# La cintura: la fila del ancla del torso de perfil.
	var row := float(torso_hip["hip"][1]) * MechSprites.UNIT_SCALE
	var hip := (mech.slot_rect("torso").position.y + row + mech.rest_lift()) * _unit
	for prefix: String in [FRONT, BACK]:
		if _art(prefix, mech).is_empty():
			continue
		var into := _fronts if prefix == FRONT else _backs
		var torso_set := prefix + mech.torso_set()
		var legs_set := prefix + mech.legs_set()
		var body := _blank()
		if mech.has_rigid_legs():
			_paste(body, legs_set, "legs", build.paint_of("legs"), hip, 0, legs_fit)
		else:
			# De frente, el lado cercano del robot queda a la izquierda; de
			# espalda, a la derecha.
			var near_half := -1 if prefix == FRONT else 1
			var near := _blank()
			_paste(near, legs_set, "legs", build.paint_of("legs"), hip, near_half, legs_fit)
			into["near_leg"] = ImageTexture.create_from_image(near)
			var far := _blank()
			_paste(far, legs_set, "legs", build.paint_of("legs"), hip, -near_half, legs_fit)
			into["far_leg"] = ImageTexture.create_from_image(far)
		_paste(body, torso_set, "torso", build.paint_of("torso"), hip, 0, torso_fit)
		into["body"] = ImageTexture.create_from_image(body)


func _blank() -> Image:
	var size := Vector2(_front_half * 2.0, _canvas.size.y) * FRONT_SCALE
	return Image.create_empty(ceili(size.x), ceili(size.y), false, Image.FORMAT_RGBA8)


## Pega en un lienzo de frente el dibujo de una pieza: su ancla de cintura va
## al eje y a la altura `hip`, y se estira a lo ancho `fit` veces.
## `half`: -1 solo su mitad izquierda, 1 la derecha, 0 entero.
func _paste(
	canvas: Image, set_name: String, kind: String, element: int, hip: float, half: int, fit: float
) -> void:
	var texture := MechSprites.texture(set_name, kind, element)
	var info := MechSprites.piece_info(set_name, kind)
	if texture == null or info.is_empty():
		return
	var image := texture.get_image()
	# Sin pantalla (las pruebas) las texturas no guardan su imagen.
	if image == null or image.is_empty():
		return
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var pixel := MechSprites.UNIT_SCALE * _unit
	var size := Vector2i(
		roundi(float(info["size"][0]) * pixel * fit * FRONT_SCALE),
		roundi(float(info["size"][1]) * pixel * FRONT_SCALE)
	)
	image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var axis := float(info["hip"][0]) * pixel * fit * FRONT_SCALE
	var left := canvas.get_width() * 0.5 - axis
	var top := (hip - float(info["hip"][1]) * pixel - _canvas.position.y) * FRONT_SCALE
	var source := Rect2i(Vector2i.ZERO, size)
	if half < 0:
		source.size.x = roundi(axis)
	elif half > 0:
		source.position.x = roundi(axis)
		source.size.x = size.x - roundi(axis)
	var at := Vector2i(roundi(left) + source.position.x, roundi(top))
	canvas.blend_rect(image, source, at)


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
	var solid := Node2D.new()
	if layer["kind"] == "float":
		solid.draw.connect(_draw_float.bind(layer))
	else:
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SOLID
		var solid_material := ShaderMaterial.new()
		solid_material.shader = _shader
		solid.material = solid_material
		_materials[layer_name] = solid_material
		solid.draw.connect(_draw_solid.bind(layer))
	add_child(solid)
	_solids[layer_name] = solid


## Lo que no cambia al girar: los dibujos de la capa y su tinte.
func _dress(layer: Dictionary, ghosts: Array[String]) -> void:
	var layer_name: String = layer["name"]
	if not _materials.has(layer_name):
		return
	var ghost := false
	if layer["kind"] == "leg":
		ghost = "legs" in ghosts
	elif layer["kind"] == "body":
		ghost = "torso" in ghosts
	var solid_material := _materials[layer_name]
	solid_material.set_shader_parameter("profile", _views[layer_name].get_texture())
	solid_material.set_shader_parameter("has_front", _fronts.has(layer_name))
	solid_material.set_shader_parameter("has_back", _backs.has(layer_name))
	solid_material.set_shader_parameter("front", _fronts.get(layer_name))
	solid_material.set_shader_parameter("back", _backs.get(layer_name))
	solid_material.set_shader_parameter("front_half", _front_half)
	solid_material.set_shader_parameter(
		"canvas", Vector4(_canvas.position.x, _canvas.position.y, _canvas.size.x, _canvas.size.y)
	)
	solid_material.set_shader_parameter("step_units", STEP_PIXELS / RENDER_SCALE)
	solid_material.set_shader_parameter(
		"wall", Vector3(_wall_color.r, _wall_color.g, _wall_color.b)
	)
	var ink := MechView.OUTLINE
	solid_material.set_shader_parameter("ink", Vector3(ink.r, ink.g, ink.b))
	var tint := GHOST if ghost else Color.WHITE
	solid_material.set_shader_parameter("tint", Vector4(tint.r, tint.g, tint.b, tint.a))


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


## Coloca cada capa segun el giro y las ordena de la de detras a la de
## delante.
func _redraw() -> void:
	if _solids.is_empty() or _depths.is_empty():
		return
	var c := cos(angle)
	var s := sin(angle)
	var sway := _mechs["body"].sway() * _unit
	queue_redraw()
	var keys: Dictionary[String, float] = {}
	var index := 0
	for layer: Dictionary in LAYERS:
		var layer_name: String = layer["name"]
		var region := _regions[layer_name]
		var depth := _depths[layer_name]
		var solid := _solids[layer_name]
		index += 1
		# Fondo del centro de la capa hacia el que mira; a igualdad, su orden.
		var along := region.get_center().x - _pivot_x
		keys[layer_name] = -along * s + depth.x * c + index * 0.001
		solid.visible = region.size != Vector2.ZERO
		if not solid.visible:
			continue
		solid.queue_redraw()
		if not _materials.has(layer_name):
			continue
		# Las armas se abren hacia fuera, alrededor de su hombro, al girar.
		var open := 0.0
		var pivot := Vector2(_pivot_x, 0.0)
		if layer["kind"] in ["arm", "top"]:
			open = -float(layer["side"]) * TOE_OUT * s * s
			pivot = Vector2(0.0, depth.x)
		var local := Vector2(cos(angle + open), sin(angle + open))
		var pivot_screen := _pivot_x + (pivot.x - _pivot_x) * c + pivot.y * s
		var near := depth.x + depth.y * 0.5
		var far := depth.x - depth.y * 0.5
		var solid_material := _materials[layer_name]
		solid_material.set_shader_parameter("turn", local)
		solid_material.set_shader_parameter("pivot", pivot)
		solid_material.set_shader_parameter("pivot_x", pivot_screen)
		solid_material.set_shader_parameter(
			"box", Vector4(region.position.x, region.end.x, far, near)
		)
		solid_material.set_shader_parameter("bob", sway.x if layer["kind"] == "leg" else sway.y)
		var behind := clampf(-float(layer["side"]) * c, 0.0, 1.0)
		var dim := lerpf(1.0, layer["dim"], behind)
		var face := dim * lerpf(FACE_SHADE, 1.0, absf(local.x))
		var edge := dim * lerpf(FACE_SHADE, 1.0, absf(local.y))
		var shadow := Vector2.ZERO
		if _fronts.has(layer_name) and (s < 0.0 or _backs.has(layer_name)):
			var side_lit := smoothstep(LIT_FROM, LIT_FULL, absf(c))
			face = dim * lerpf(SHADOW_LIGHT, 1.0, side_lit)
			edge = dim * lerpf(SHADOW_LIGHT, 1.0, 1.0 - side_lit)
			shadow = Vector2(1.0 - side_lit, side_lit) * SHADOW_FLAT
		solid_material.set_shader_parameter("light", Vector2(face, edge))
		solid_material.set_shader_parameter("shadow", shadow)
		# Lo que ocupa la caja de la capa en la pantalla.
		var left := INF
		var right := -INF
		for x: float in [region.position.x, region.end.x]:
			for z: float in [far, near]:
				var on_screen := pivot_screen + (x - pivot.x) * local.x + (z - pivot.y) * local.y
				left = minf(left, on_screen)
				right = maxf(right, on_screen)
		_quads[layer_name] = Rect2(left - 1.0, region.position.y, right - left + 2.0, region.size.y)
	var order: Array[String] = []
	order.assign(keys.keys())
	order.sort_custom(func(a: String, b: String) -> bool: return keys[a] < keys[b])
	if order != _order:
		_order = order
		for i in order.size():
			move_child(_solids[order[i]], _views.size() + i)


## Una capa con volumen: el sombreador pinta su caja.
func _draw_solid(layer: Dictionary) -> void:
	var layer_name: String = layer["name"]
	if _quads.has(layer_name):
		_solids[layer_name].draw_rect(_quads[layer_name], Color.WHITE)


## El asistente: gira alrededor del robot pero se ve siempre de lado.
func _draw_float(layer: Dictionary) -> void:
	var layer_name: String = layer["name"]
	var region := _regions[layer_name]
	if region.size == Vector2.ZERO:
		return
	var c := cos(angle)
	var flip := 1.0 if c >= 0.0 else -1.0
	var center := region.get_center().x
	var on_screen := _pivot_x + (center - _pivot_x) * c + _depths[layer_name].x * sin(angle)
	var node := _solids[layer_name]
	node.draw_set_transform_matrix(
		Transform2D(Vector2(flip, 0.0), Vector2(0.0, 1.0), Vector2(on_screen - center * flip, 0.0))
	)
	var source := Rect2(
		(region.position - _canvas.position) * RENDER_SCALE, region.size * RENDER_SCALE
	)
	node.draw_texture_rect_region(_views[layer_name].get_texture(), region, source)
