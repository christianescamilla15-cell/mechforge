class_name TeardownView
extends Control
## Tu robot desarmado en el centro del hangar, en revision (OBS-048, del
## usuario: "lo que se deberia mostrar es unicamente el esqueleto de robot...
## por piezas separadas... como si estuviera en el taller revisandose").
## Cada pieza esta en su sitio de trabajo:
## - el torso, colgado de la grua; el arma de hombro, de otro gancho;
## - las piernas, en su soporte sobre el suelo;
## - las armas de brazo, en sus cunas a los lados; el arma de pecho, en la
##   suya, abajo;
## - el asistente (o el dron), en su muelle arriba a la izquierda;
## - las piezas especiales y los modulos, en la bandeja de herramientas;
## - entre el torso y las piernas, el esqueleto: la columna con el nucleo de
##   control en medio (las habilidades) y, a sus lados, los ocho sistemas
##   internos (las mejoras permanentes), cada uno con sus diez niveles.
## Solo ensena y dice que hay bajo el raton (item_at); quien la usa decide.
## Las claves: "slot:<hueco>", "system:<mejora>" y "core".

const GOLD := Color("ffd36b")
const LINE := Color("3fd0e6")
const TEXT := Color("bfefff")
const MUTED := Color("7fb5c4")
const STEEL := Color("2a3442")
const STEEL_LIGHT := Color("4a5768")
const STEEL_DARK := Color("121922")
const HAZARD_A := Color("d9a520")
const HAZARD_B := Color("1a1a1a")
## Donde va cada cosa, como parte del ancho y el alto de la vista: el
## centro de su dibujo.
const SPOTS: Dictionary[String, Vector2] = {
	"torso": Vector2(0.5, 0.33),
	"legs": Vector2(0.5, 0.78),
	"side0": Vector2(0.79, 0.5),
	"side1": Vector2(0.21, 0.5),
	"top0": Vector2(0.78, 0.2),
	"assist": Vector2(0.23, 0.2),
	"chest": Vector2(0.84, 0.83),
}
## Alto del torso, como parte del alto de la vista: marca la escala de todo.
const TORSO_SHARE := 0.22
## Los sistemas, a cada lado de la columna (de arriba abajo).
const SYSTEMS_LEFT: Array[String] = ["health", "resistance", "heat", "energy"]
const SYSTEMS_RIGHT: Array[String] = ["damage", "core", "assist", "backfire"]
const SYSTEM_TOP := 0.47
const SYSTEM_STEP := 0.058
const SYSTEM_SIDE := 0.095
## La bandeja de herramientas: especiales arriba y modulos debajo.
const TRAY := Rect2(0.125, 0.62, 0.17, 0.15)
const SPECIALS: Array[String] = ["hook", "charge", "teleport"]
const REDRAW_SECONDS := 1.0 / 30.0

## Lo que ensena (WorkshopBrief.teardown): "build" (MechBuild con las piezas
## a su nivel), "slots" (Array de WorkshopBrief.slots), "systems" (las filas
## de WorkshopBrief.upgrades) y "points" (habilidades por aprender).
var state: Dictionary = {}
## La clave elegida (con su etiqueta abierta) y la que esta bajo el raton.
var selected: String = ""
var hover: String = ""

var _sprites: MechSprites
var _build: MechBuild
var _unit := 1.0
var _rects: Dictionary[String, Rect2] = {}
var _slot_info: Dictionary[String, Dictionary] = {}
var _system_info: Dictionary[String, Dictionary] = {}
var _time := 0.0
var _redraw := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	resized.connect(_layout)


func show_state(p_state: Dictionary) -> void:
	state = p_state
	_build = state.get("build") as MechBuild
	_sprites = MechSprites.for_build(_build) if _build != null else null
	_slot_info.clear()
	for row: Dictionary in state.get("slots", []):
		_slot_info[str(row["slot"])] = row
	_system_info.clear()
	for row: Dictionary in state.get("systems", []):
		_system_info[str(row["id"])] = row
	_layout()
	queue_redraw()


## Lo que hay en ese punto (en pixeles de la vista): "slot:<hueco>",
## "system:<mejora>", "core" o "".
func item_at(at: Vector2) -> String:
	var best := ""
	var area := INF
	for key: String in _rects:
		var rect: Rect2 = _rects[key]
		if rect.has_point(at) and rect.get_area() < area:
			best = key
			area = rect.get_area()
	return best


## Donde esta una cosa (para colgarle su etiqueta); vacio si no esta.
func rect_of(key: String) -> Rect2:
	return _rects.get(key, Rect2())


func _process(delta: float) -> void:
	_time += delta
	_redraw += delta
	if _redraw >= REDRAW_SECONDS:
		_redraw = 0.0
		queue_redraw()


# --- Colocacion ----------------------------------------------------------------


func _layout() -> void:
	_rects.clear()
	if _sprites == null or size.y <= 0.0:
		return
	var torso := _sprites.piece_rect(_sprites.torso_set, "torso")
	_unit = size.y * TORSO_SHARE / maxf(torso.size.y, 1.0)
	for slot: String in SPOTS:
		var rect := _piece_rect(slot)
		if rect.size != Vector2.ZERO:
			_rects["slot:" + slot] = rect
	var height := size.y * SYSTEM_STEP * 0.8
	for side in 2:
		var tracks := SYSTEMS_LEFT if side == 0 else SYSTEMS_RIGHT
		var x := size.x * (0.5 + (SYSTEM_SIDE if side == 1 else -SYSTEM_SIDE))
		for i in tracks.size():
			var center := Vector2(x, size.y * (SYSTEM_TOP + SYSTEM_STEP * i))
			var box := Rect2(center - Vector2(height, height) * 0.5, Vector2(height, height))
			_rects["system:" + tracks[i]] = box
	var core := size.y * 0.04
	var core_at := Vector2(size.x * 0.5, size.y * 0.555)
	_rects["core"] = Rect2(core_at - Vector2(core, core), Vector2(core, core) * 2.0)
	var tray := _tray_rect()
	var cell := tray.size.x / 3.0
	for i in SPECIALS.size():
		_rects["slot:" + SPECIALS[i]] = (
			Rect2(tray.position + Vector2(cell * i, 0.0), Vector2(cell, tray.size.y * 0.36))
			. grow(-3.0)
		)
	var chips := Rect2(
		tray.position + Vector2(0.0, tray.size.y * 0.4), Vector2(tray.size.x, tray.size.y * 0.6)
	)
	for i in MechBuild.MODULE_SLOTS:
		var cell_at := Vector2(chips.size.x / 3.0 * (i % 3), chips.size.y / 3.0 * (i / 3))
		var at := chips.position + cell_at
		_rects["slot:module%d" % i] = Rect2(at, chips.size / 3.0).grow(-2.0)


func _tray_rect() -> Rect2:
	return Rect2(
		Vector2(size.x * TRAY.position.x, size.y * TRAY.position.y),
		Vector2(size.x * TRAY.size.x, size.y * TRAY.size.y)
	)


## Rectangulo de una pieza dibujada en su sitio, en pixeles de la vista.
func _piece_rect(slot: String) -> Rect2:
	var art := _art_of(slot)
	if art.is_empty():
		return Rect2()
	var raw: Rect2 = art["rect"]
	var size_px := raw.size * _unit
	var spot: Vector2 = SPOTS[slot]
	var center := Vector2(size.x * spot.x, size.y * spot.y)
	return Rect2(center - size_px * 0.5, size_px)


## Con que se dibuja una pieza: {"set", "kind", "rect" (en unidades, sin
## desplazar)} o {"assist": tipo}; vacio si no hay pieza o dibujo.
func _art_of(slot: String) -> Dictionary:
	var item := _build.item_at(slot) if _build != null else null
	if item == null:
		if slot == "assist" and _build != null and _build.drone != null:
			return _weapon_art(_build.drone)
		return {}
	match slot:
		"torso":
			return _set_art(_sprites.torso_set, "torso")
		"legs":
			return _set_art(_sprites.legs_set, "legs")
		"chest":
			return _set_art(MechSprites.chest_set(item), "chest")
		"assist":
			var kind := MechSprites.assist_kind(item.tier)
			var unit := MechSprites.ASSIST_UNIT
			var anchors := MechSprites._load_anchors(MechSprites.ASSIST_SET)
			var piece: Dictionary = anchors.get(kind, {})
			if piece.is_empty():
				return {}
			var box := Vector2(piece["size"][0], piece["size"][1]) * unit
			var center := Vector2(piece["center"][0], piece["center"][1]) * unit
			return {"assist": kind, "rect": Rect2(-center, box)}
	return _weapon_art(item)


func _set_art(set_name: String, kind: String) -> Dictionary:
	var rect := _sprites.piece_rect(set_name, kind)
	if rect.size == Vector2.ZERO:
		return {}
	return {"set": set_name, "kind": kind, "rect": rect}


func _weapon_art(item: ItemDef) -> Dictionary:
	var kind := MechSprites.weapon_look(item)
	if kind == "":
		return {}
	return _set_art(MechSprites.WEAPON_SET, kind)


# --- Dibujo ----------------------------------------------------------------------


func _draw() -> void:
	if _sprites == null:
		return
	_draw_gantry()
	_draw_skeleton()
	_draw_stand("legs")
	for slot: String in ["side0", "side1", "chest"]:
		_draw_cradle(slot)
	_draw_dock()
	_draw_tray()
	for slot: String in ["legs", "torso", "top0", "side1", "side0", "chest", "assist"]:
		_draw_piece(slot)
	_draw_systems()
	_draw_core()
	_draw_marks()


func _draw_gantry() -> void:
	var y := size.y * 0.085
	var beam := Rect2(size.x * 0.17, y, size.x * 0.66, size.y * 0.022)
	draw_rect(beam, STEEL_DARK)
	draw_rect(Rect2(beam.position, Vector2(beam.size.x, 2.0)), Color(1, 1, 1, 0.12))
	var x := beam.position.x
	while x < beam.end.x:
		draw_line(
			Vector2(x, beam.position.y + 2.0), Vector2(x + 10.0, beam.end.y - 2.0), STEEL, 1.0
		)
		x += 22.0
	for slot: String in ["torso", "top0"]:
		var rect := rect_of("slot:" + slot)
		if rect.size == Vector2.ZERO:
			continue
		_draw_cable(Vector2(rect.get_center().x, beam.end.y), rect.position.y + rect.size.y * 0.12)


## Un cable con su gancho, del carro de la viga hasta lo que cuelga.
func _draw_cable(from: Vector2, to_y: float) -> void:
	var trolley := Rect2(from + Vector2(-14.0, -2.0), Vector2(28.0, 10.0))
	draw_rect(trolley, STEEL_LIGHT)
	draw_rect(trolley, Color(0, 0, 0, 0.5), false, 1.5)
	for dx: float in [-6.0, 6.0]:
		var end := Vector2(from.x + dx * 2.2, to_y - 8.0)
		draw_line(from + Vector2(dx, 8.0), end, Color("8a96a6"), 1.6)
	draw_arc(Vector2(from.x, to_y - 6.0), 7.0, PI * 0.1, PI * 0.9, 8, Color("b8c2cf"), 2.5)


## Las piernas, de pie en su soporte.
func _draw_stand(slot: String) -> void:
	var rect := rect_of("slot:" + slot)
	if rect.size == Vector2.ZERO:
		return
	var floor_y := rect.end.y + 4.0
	var base := Rect2(rect.position.x - 10.0, floor_y, rect.size.x + 20.0, size.y * 0.025)
	draw_rect(base, STEEL)
	_hazard(Rect2(base.position.x, base.position.y, base.size.x, 4.0))
	draw_rect(base, Color(0, 0, 0, 0.6), false, 1.5)
	# Las mordazas que lo sujetan por la cintura.
	for side: float in [-1.0, 1.0]:
		var x := rect.get_center().x + side * rect.size.x * 0.52
		draw_line(Vector2(x, floor_y), Vector2(x, rect.position.y + rect.size.y * 0.1), STEEL, 6.0)
		draw_line(
			Vector2(x, rect.position.y + rect.size.y * 0.1),
			Vector2(x - side * 12.0, rect.position.y + rect.size.y * 0.1),
			STEEL_LIGHT,
			4.0
		)


## Una cuna en V bajo un arma, con su placa.
func _draw_cradle(slot: String) -> void:
	var rect := rect_of("slot:" + slot)
	if rect.size == Vector2.ZERO:
		return
	var y := rect.end.y - rect.size.y * 0.18
	var width := clampf(rect.size.x * 0.5, 50.0, 150.0)
	var center := rect.get_center().x
	var floor_y := minf(y + size.y * 0.14, size.y * 0.93)
	for side: float in [-1.0, 1.0]:
		var top := Vector2(center + side * width * 0.5, y)
		draw_line(top, Vector2(center + side * width * 0.2, y + 16.0), STEEL_LIGHT, 5.0)
		var leg := Vector2(center + side * width * 0.3, y + 10.0)
		draw_line(leg, Vector2(center + side * width * 0.4, floor_y), STEEL, 5.0)
	var foot := Rect2(center - width * 0.55, floor_y, width * 1.1, 8.0)
	draw_rect(foot, STEEL)
	_hazard(Rect2(foot.position, Vector2(foot.size.x, 3.0)))


## El muelle del asistente: dos brazos que lo sujetan desde la pared.
func _draw_dock() -> void:
	var rect := rect_of("slot:assist")
	if rect.size == Vector2.ZERO:
		return
	var center := rect.get_center()
	var arm := Vector2(center.x - rect.size.x * 0.75, center.y)
	draw_line(arm, center + Vector2(-rect.size.x * 0.25, 0.0), STEEL, 7.0)
	draw_line(arm + Vector2(0.0, -14.0), arm + Vector2(0.0, 14.0), STEEL_LIGHT, 9.0)
	var glow := 0.35 + 0.2 * sin(_time * 2.3)
	draw_circle(center, rect.size.x * 0.62, Color(LINE, 0.05 * glow))
	draw_arc(center, rect.size.x * 0.62, 0.0, TAU, 40, Color(LINE, 0.3 * glow), 1.5)


## La bandeja de herramientas: especiales y modulos.
func _draw_tray() -> void:
	var tray := _tray_rect()
	var body := tray.grow(6.0)
	draw_rect(body, STEEL_DARK)
	draw_rect(body, STEEL_LIGHT, false, 2.0)
	var under := body.end.y + 2.0
	draw_line(Vector2(body.position.x, under), Vector2(body.end.x, under), Color(0, 0, 0, 0.5), 3.0)
	for leg: float in [body.position.x + 8.0, body.end.x - 8.0]:
		draw_line(Vector2(leg, body.end.y), Vector2(leg, size.y * 0.93), STEEL, 4.0)
	var keys: Array[String] = []
	for slot in SPECIALS:
		keys.append(slot)
	for i in MechBuild.MODULE_SLOTS:
		keys.append("module%d" % i)
	for slot in keys:
		var rect := rect_of("slot:" + slot)
		draw_rect(rect, Color(0, 0, 0, 0.45))
		draw_rect(rect, Color(STEEL_LIGHT, 0.8), false, 1.0)
		var row: Dictionary = _slot_info.get(slot, {})
		var item: ItemDef = row.get("item")
		if item != null:
			PartGlyph.draw(self, rect.grow(-2.0), item)
		elif str(row.get("locked", "")) != "":
			_lock(rect.get_center(), rect.size.y * 0.22)


## La columna del esqueleto, sus costillas y los cables a cada sistema.
func _draw_skeleton() -> void:
	var torso := rect_of("slot:torso")
	var legs := rect_of("slot:legs")
	if torso.size == Vector2.ZERO or legs.size == Vector2.ZERO:
		return
	var x := size.x * 0.5
	var top := torso.end.y - torso.size.y * 0.15
	var bottom := legs.position.y + legs.size.y * 0.12
	var width := size.x * 0.018
	var y := top
	var k := 0
	while y < bottom:
		var height := minf(size.y * 0.022, bottom - y)
		var vertebra := Rect2(x - width * 0.5, y, width, height * 0.8)
		draw_rect(vertebra, STEEL if k % 2 == 0 else STEEL_LIGHT)
		draw_rect(vertebra, Color(0, 0, 0, 0.55), false, 1.0)
		y += height
		k += 1
	var core := rect_of("core").get_center()
	for key: String in _rects:
		if not key.begins_with("system:"):
			continue
		var box: Rect2 = _rects[key]
		var side := signf(box.get_center().x - x)
		var near := Vector2(box.get_center().x - side * box.size.x * 0.5, box.get_center().y)
		draw_line(Vector2(x + side * width * 0.5, near.y), near, STEEL, 3.0)
		var row: Dictionary = _system_info.get(key.trim_prefix("system:"), {})
		var on := float(row.get("level", 0)) / 10.0
		draw_line(core, near, Color(LINE, 0.12 + 0.25 * on), 1.2)


func _draw_piece(slot: String) -> void:
	var rect := rect_of("slot:" + slot)
	if rect.size == Vector2.ZERO:
		return
	var art := _art_of(slot)
	var key := "slot:" + slot
	if key == selected or key == hover:
		_glow(rect, GOLD if key == selected else LINE)
	var element := _element_of(slot)
	if art.has("assist"):
		var bob := Vector2(0.0, sin(_time * 3.1) * 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(_unit, _unit))
		var raw: Rect2 = art["rect"]
		var at := (rect.get_center() + bob) / _unit - raw.get_center()
		MechSprites.draw_assist(self, art["assist"], element, Color.WHITE, at)
		draw_set_transform(Vector2.ZERO)
		return
	var base: Rect2 = art["rect"]
	var offset := rect.get_center() / _unit - base.get_center()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_unit, _unit))
	if slot == "legs" and not _sprites.rigid_legs:
		var far := Color(0.62, 0.66, 0.72, 1.0)
		var back := offset + MechView.FAR_LEG_OFFSET
		_sprites.draw_piece(self, art["set"], art["kind"], element, far, back)
	_sprites.draw_piece(self, art["set"], art["kind"], element, Color.WHITE, offset)
	draw_set_transform(Vector2.ZERO)


## El color (elemento) con el que se ve una pieza: su pintura o el suyo.
func _element_of(slot: String) -> int:
	var row: Dictionary = _slot_info.get(slot, {})
	var paint := int(row.get("paint", -1))
	if paint >= 0:
		return paint
	var item := _build.item_at(slot) if _build != null else null
	if item == null and slot == "assist" and _build != null and _build.drone != null:
		item = _build.drone
	return int(item.element) if item != null else 0


func _draw_systems() -> void:
	for key: String in _rects:
		if not key.begins_with("system:"):
			continue
		var track := key.trim_prefix("system:")
		var box: Rect2 = _rects[key]
		var row: Dictionary = _system_info.get(track, {})
		var level := int(row.get("level", 0))
		var top := maxi(int(state.get("system_max", 10)), 1)
		var center := box.get_center()
		var radius := box.size.x * 0.5
		if key == selected or key == hover:
			draw_circle(center, radius * 1.35, Color(GOLD if key == selected else LINE, 0.16))
		draw_circle(center, radius, STEEL_DARK)
		draw_circle(center, radius * 0.72, STEEL)
		# Los diez niveles, como segmentos alrededor.
		for i in top:
			var start := -PI * 0.5 + TAU * float(i) / top + 0.06
			var end := -PI * 0.5 + TAU * float(i + 1) / top - 0.06
			var lit := i < level
			draw_arc(center, radius * 0.88, start, end, 4, GOLD if lit else Color(MUTED, 0.25), 3.0)
		_system_icon(track, center, radius * 0.5, level > 0)


## El simbolo de cada sistema, a mano.
func _system_icon(track: String, at: Vector2, r: float, on: bool) -> void:
	var color := LINE if on else MUTED
	match track:
		"health":
			draw_rect(Rect2(at - Vector2(r * 0.25, r * 0.8), Vector2(r * 0.5, r * 1.6)), color)
			draw_rect(Rect2(at - Vector2(r * 0.8, r * 0.25), Vector2(r * 1.6, r * 0.5)), color)
		"resistance":
			var hexagon := PackedVector2Array()
			for i in 6:
				hexagon.append(at + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r * 0.9)
			draw_colored_polygon(hexagon, Color(color, 0.35))
			hexagon.append(hexagon[0])
			draw_polyline(hexagon, color, 2.0)
		"heat":
			for i in 4:
				var x := at.x - r * 0.75 + r * 0.5 * i
				draw_line(Vector2(x, at.y - r * 0.8), Vector2(x, at.y + r * 0.8), color, 2.5)
		"energy":
			var bolt := PackedVector2Array(
				[
					at + Vector2(r * 0.2, -r),
					at + Vector2(-r * 0.5, r * 0.1),
					at + Vector2(0.0, r * 0.1),
					at + Vector2(-r * 0.2, r),
					at + Vector2(r * 0.5, -r * 0.1),
					at + Vector2(0.0, -r * 0.1),
				]
			)
			draw_colored_polygon(bolt, color)
		"damage":
			draw_arc(at, r * 0.75, 0.0, TAU, 20, color, 2.0)
			draw_line(at - Vector2(r, 0.0), at + Vector2(r, 0.0), color, 2.0)
			draw_line(at - Vector2(0.0, r), at + Vector2(0.0, r), color, 2.0)
		"core":
			draw_circle(at, r * 0.6, color)
			draw_arc(at, r * 0.95, 0.0, TAU, 20, color, 1.5)
		"assist":
			draw_rect(Rect2(at - Vector2(r * 0.7, r * 0.35), Vector2(r * 1.4, r * 0.7)), color)
			draw_line(at + Vector2(-r, -r * 0.55), at + Vector2(r, -r * 0.55), color, 2.0)
		"backfire":
			draw_arc(at, r * 0.7, PI * 0.25, PI * 1.75, 14, color, 2.5)
			draw_line(at + Vector2(r * 0.5, -r * 0.5), at + Vector2(r * 0.95, -r * 0.1), color, 2.5)
		_:
			draw_circle(at, r * 0.5, color)


## El nucleo de control, en medio de la columna: late; las habilidades.
func _draw_core() -> void:
	var rect := rect_of("core")
	if rect.size == Vector2.ZERO:
		return
	var center := rect.get_center()
	var radius := rect.size.x * 0.5
	var pulse := 0.5 + 0.5 * sin(_time * 2.6)
	if selected == "core" or hover == "core":
		draw_circle(center, radius * 1.6, Color(GOLD if selected == "core" else LINE, 0.18))
	draw_circle(center, radius * (1.15 + 0.08 * pulse), Color(LINE, 0.12))
	draw_circle(center, radius, STEEL_DARK)
	draw_circle(center, radius * 0.62, Color(LINE, 0.55 + 0.3 * pulse))
	draw_circle(center, radius * 0.3, Color(1, 1, 1, 0.8))
	# La jaula del nucleo.
	for i in 4:
		var angle := TAU * i / 4.0 + _time * 0.4
		draw_arc(center, radius * 0.95, angle, angle + 0.9, 8, STEEL_LIGHT, 3.0)
	var points := int(state.get("points", 0))
	if points > 0:
		var badge := center + Vector2(radius * 0.85, -radius * 0.85)
		draw_circle(badge, 9.0, GOLD)
		var at := badge + Vector2(-4.0, 5.0)
		draw_string(_font, at, str(points), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, STEEL_DARK)


## Lo elegido y lo de bajo el raton: esquinas alrededor y su nombre.
func _draw_marks() -> void:
	for key: String in [hover, selected]:
		if key == "" or not _rects.has(key):
			continue
		var rect: Rect2 = _rects[key].grow(6.0)
		var color := GOLD if key == selected else LINE
		var arm := minf(16.0, rect.size.x * 0.3)
		var corners: Array[Vector2] = [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
		for corner in corners:
			var dx := arm if corner.x == rect.position.x else -arm
			var dy := arm if corner.y == rect.position.y else -arm
			draw_line(corner, corner + Vector2(dx, 0.0), color, 2.0)
			draw_line(corner, corner + Vector2(0.0, dy), color, 2.0)
	if hover != "" and hover != selected and _rects.has(hover):
		var rect: Rect2 = _rects[hover]
		var name := _name_of(hover)
		if name != "":
			var width := 260.0
			var at := Vector2(rect.get_center().x - width * 0.5, rect.position.y - 10.0)
			HangarProps.text(self, _font, at, name, width, 14, TEXT, true)


func _name_of(key: String) -> String:
	if key == "core":
		return Txt.t("teardown_core")
	if key.begins_with("system:"):
		return str(_system_info.get(key.trim_prefix("system:"), {}).get("name", ""))
	var slot := key.trim_prefix("slot:")
	var row: Dictionary = _slot_info.get(slot, {})
	var item: ItemDef = row.get("item")
	return item.display_name if item != null else str(row.get("title", ""))


func _glow(rect: Rect2, color: Color) -> void:
	var center := rect.get_center()
	var radius := rect.size.length() * 0.5
	for i in 3:
		draw_circle(center, radius * (0.55 + 0.15 * i), Color(color, 0.05))


func _hazard(rect: Rect2) -> void:
	var x := rect.position.x
	var k := 0
	while x < rect.end.x:
		var width := minf(12.0, rect.end.x - x)
		var stripe := HAZARD_A if k % 2 == 0 else HAZARD_B
		draw_rect(Rect2(x, rect.position.y, width, rect.size.y), stripe)
		x += 12.0
		k += 1


func _lock(at: Vector2, r: float) -> void:
	draw_arc(at - Vector2(0.0, r * 0.5), r * 0.6, PI, TAU, 10, MUTED, 2.0)
	draw_rect(Rect2(at - Vector2(r, r * 0.4), Vector2(r * 2.0, r * 1.4)), MUTED)
