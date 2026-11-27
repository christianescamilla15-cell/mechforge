class_name BattleHud
extends Control
## Lo unico que se ve encima del combate (decisiones del usuario, 2026-11-20,
## OBS-015 a OBS-018 de docs/OBSERVACIONES.md: "toda la pantalla es el
## juego"). No hay barras, botones, registro ni avisos:
##  - Las armas van en el propio robot: al pasar el raton por el (o al
##    tocarlo) se despliegan en abanico, cada una con su icono; encendida la
##    que se puede usar, en gris la que no. Al pasar por una, su dano, su
##    critico y lo demas, en pequeno.
##  - La vida, el calor y la energia de cada robot son tres rayitas
##    translucidas sobre el, sin numeros, y dos rombos las acciones que le
##    quedan a quien le toca.
##  - El turno no esta fijo en pantalla: sale un rotulo un instante cuando
##    cambia, como el "fight" de un juego de lucha.
## La pantalla de combate decide que es legal y que pasa al elegir.

signal action_chosen(action: BattleAction)
## El jugador eligio el salto: falta elegir la casilla.
signal teleport_requested
## El raton entro en una accion o salio de todas (null).
signal action_hovered(action: BattleAction)

const ICON := 46.0
## Separacion entre iconos a lo largo del arco, en pixeles.
const SPACING := 56.0
## Hueco de mas entre las armas y lo demas (pisoton, especiales, enfriar).
const GROUP_GAP := 0.45
const OPEN_SECONDS := 0.16
const BANNER_SECONDS := 1.05
const GOLD := Color("ffe27a")
const TEXT := Color("e8f4ff")
const MUTED := Color("8fa3b8")
const BAD := Color("ff8a7a")
const LIT := Color(0.34, 0.83, 1.0)
const HEALTH := Color("5fe37a")
const HEAT := Color("ff8a3d")
const ENERGY := Color("4fd0ff")
## Lo que se ven las rayitas de un robot al que no se esta mirando.
const IDLE_ALPHA := 0.72
const VITALS_WIDTH := 76.0

var arena: ArenaView
## El mech que maneja el jugador.
var player: int = 0
## Tarjeta de una accion: Callable(action) -> {"title", "lines": [[texto,
## color], ...]}. La arma la pantalla de combate con lo que sabe el motor.
var card_for: Callable

## Una entrada por accion: {"action", "def" (su pieza, o null), "glyph" (el
## simbolo de las que no tienen pieza), "weapon" (si es un arma)}.
var _entries: Array[Dictionary] = []
var _reasons: Array[String] = []
var _uses: Array[int] = []
var _open := 0.0
var _inside := false
var _pinned := false
## Accion que se ensena sola (la prueba automatica "pasa el raton" por ella).
var _demo := -1
var _hover := -1
## Estado de cada mech: {"health", "heat", "energy"} de 0 a 1 y "over".
var _vitals: Array[Dictionary] = []
var _turn := -1
var _actions := 0
var _banner := {}
var _time := 0.0
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	_time += delta
	var wanted := 1.0 if (_inside or _pinned or _demo >= 0) and not _entries.is_empty() else 0.0
	_open = move_toward(_open, wanted, delta / OPEN_SECONDS)
	if not _banner.is_empty():
		_banner["age"] = float(_banner["age"]) + delta
		if float(_banner["age"]) >= BANNER_SECONDS:
			_banner = {}
	# Los robots se mueven y la camara tambien: todo va pegado a ellos.
	queue_redraw()


# --- Lo que le cuenta la pantalla de combate -------------------------------------


## Las acciones del mech del jugador, en el orden del abanico: sus armas y,
## despues, el pisoton, los especiales, las habilidades y enfriar.
func build_for(mech: BattleMech) -> void:
	_entries.clear()
	for key in mech.weapon_keys():
		_add(BattleAction.weapon(key), mech.slots[key].def, "", true)
	if mech.slots["legs"].def.deals_damage():
		_add(BattleAction.stomp(), mech.slots["legs"].def, "")
	if mech.slots.has("charge"):
		_add(BattleAction.charge(), mech.slots["charge"].def, "")
	if mech.slots.has("hook"):
		_add(BattleAction.hook(), mech.slots["hook"].def, "")
	if mech.slots.has("teleport"):
		_add(BattleAction.teleport(-1), mech.slots["teleport"].def, "")
	if mech.kits_left("shield") > 0:
		_add(BattleAction.shield(), null, "shield")
	if mech.kits_left("repair") > 0:
		_add(BattleAction.repair(), null, "repair")
	if mech.kits_left("dark_matter") > 0:
		_add(BattleAction.dark_matter(), null, "dark")
	if mech.ult_enabled:
		_add(BattleAction.ultimate(), null, "ultimate")
	_add(BattleAction.cool(), null, "cool")
	_reasons.resize(_entries.size())
	_reasons.fill(" ")
	_uses.resize(_entries.size())
	_uses.fill(-1)
	_hover = -1
	_demo = -1
	_pinned = false


## Que se puede usar ahora. `reason_for(action)` devuelve "" si es legal y
## `uses_left_for(action)` cuantos usos le quedan (-1 = no lleva la cuenta).
## Sin `enabled` (no es su turno, o se esta jugando algo) todo va en gris.
func refresh(enabled: bool, reason_for: Callable, uses_left_for: Callable) -> void:
	for i in _entries.size():
		var action: BattleAction = _entries[i]["action"]
		_reasons[i] = str(reason_for.call(action)) if enabled else " "
		_uses[i] = int(uses_left_for.call(action))
	if not enabled:
		_demo = -1
		_pinned = false


## La vida, el calor y la energia de los dos mechs (de 0 a 1; `over` si el
## calor pasa del tope), de quien es el turno y cuantas acciones le quedan.
func show_state(vitals: Array[Dictionary], turn: int, actions_left: int) -> void:
	_vitals = vitals
	_turn = turn
	_actions = actions_left


## El rotulo que cruza la pantalla un instante: el turno, el comienzo.
func announce(text: String, color: Color, small: String = "") -> void:
	_banner = {"text": text, "color": color, "small": small, "age": 0.0}


## Abre el abanico con el raton "puesto" en esa accion, sin raton (lo usa la
## prueba que juega sola con los controles). Vuelve su sitio en pantalla.
func demo(action: BattleAction) -> Vector2:
	_demo = index_of(action)
	_open = 1.0
	_set_hover(_demo)
	return icon_rect(_demo).get_center() if _demo >= 0 else Vector2.ZERO


func is_open() -> bool:
	return _open > 0.5


func actions() -> Array[BattleAction]:
	var out: Array[BattleAction] = []
	for entry in _entries:
		out.append(entry["action"])
	return out


## Posicion de una accion en el abanico; -1 si el mech no la tiene.
func index_of(action: BattleAction) -> int:
	if action == null:
		return -1
	for i in _entries.size():
		var mine: BattleAction = _entries[i]["action"]
		if mine.type == action.type and mine.slot == action.slot:
			return i
	return -1


## True si esa accion esta encendida (se puede usar ahora).
func is_lit(index: int) -> bool:
	return index >= 0 and index < _reasons.size() and _reasons[index] == ""


# --- Donde esta cada cosa ---------------------------------------------------------


## El robot del jugador en pantalla.
func body_rect() -> Rect2:
	return arena.mech_rect(player) if arena != null else Rect2()


func _center() -> Vector2:
	var body := body_rect()
	var at := Vector2(body.get_center().x, body.position.y + body.size.y * 0.52)
	# Cerca de un borde el abanico se corre hacia dentro para verse entero.
	var reach := _radius() + ICON
	at.x = clampf(at.x, minf(reach, size.x * 0.5), maxf(size.x - reach, size.x * 0.5))
	at.y = maxf(at.y, minf(reach, size.y * 0.5))
	return at


func _radius() -> float:
	var body := body_rect()
	var slots := _entries.size() + GROUP_GAP
	return maxf(body.size.y * 0.68, slots * SPACING / deg_to_rad(215.0))


## Sitio del icono `index`, ya desplegado: sobre un arco por encima del robot,
## de izquierda a derecha.
func icon_rect(index: int) -> Rect2:
	if index < 0 or index >= _entries.size():
		return Rect2()
	var radius := _radius()
	var step := SPACING / radius
	var weapons := 0
	for entry in _entries:
		if entry["weapon"]:
			weapons += 1
	var gap := GROUP_GAP if weapons > 0 and weapons < _entries.size() else 0.0
	var slot := float(index) + (gap if index >= weapons else 0.0)
	var angle := (slot - (_entries.size() - 1 + gap) * 0.5) * step
	var at := _center() + Vector2(sin(angle), -cos(angle)) * radius
	return Rect2(at - Vector2(ICON, ICON) * 0.5, Vector2(ICON, ICON))


func _index_at(point: Vector2) -> int:
	if _open < 0.6:
		return -1
	for i in _entries.size():
		if icon_rect(i).grow(4.0).has_point(point):
			return i
	return -1


## El raton solo es del abanico sobre el robot y, abierto, sobre sus iconos:
## lo demas (las casillas del suelo) es de la arena, que esta debajo.
func _has_point(point: Vector2) -> bool:
	if arena == null or _entries.is_empty():
		return false
	var body := body_rect()
	if body.grow(8.0).has_point(point):
		return true
	if _open < 0.05:
		return false
	return point.distance_to(_center()) <= _radius() + ICON and point.y <= body.end.y


# --- Entrada ----------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_inside = true
		_set_hover(_index_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var index := _index_at(event.position)
		if index >= 0:
			press(index)
		else:
			# Tocar el robot (en tactil no hay "pasar el raton") lo abre o lo cierra.
			_pinned = not _pinned
		accept_event()


## Pulsa la accion `index` del abanico: si esta encendida, se elige.
func press(index: int) -> void:
	if not is_lit(index):
		Sfx.play("ui_cerrar")
		return
	var action: BattleAction = _entries[index]["action"]
	_pinned = false
	_demo = -1
	if action.type == BattleAction.Type.TELEPORT:
		teleport_requested.emit()
	else:
		action_chosen.emit(action)


func _on_mouse_exited() -> void:
	_inside = false
	_set_hover(-1)


func _set_hover(index: int) -> void:
	if index == _hover:
		return
	_hover = index
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if is_lit(index) else CURSOR_ARROW
	action_hovered.emit(_entries[index]["action"] if index >= 0 else null)


func _add(action: BattleAction, def: ItemDef, glyph: String, weapon: bool = false) -> void:
	_entries.append({"action": action, "def": def, "glyph": glyph, "weapon": weapon})


# --- Dibujo ------------------------------------------------------------------------


func _draw() -> void:
	if arena == null:
		return
	for i in _vitals.size():
		_draw_vitals(i)
	if _open > 0.01:
		_draw_fan()
	if not _banner.is_empty():
		_draw_banner()


## Tres rayitas sobre el robot (vida, calor y energia) y, si le toca, dos
## rombos con las acciones que le quedan. Sin numeros.
func _draw_vitals(index: int) -> void:
	var body := arena.mech_rect(index)
	if body.size.y <= 0.0:
		return
	var state := _vitals[index]
	var mine := index == player
	var alpha := lerpf(IDLE_ALPHA, 1.0, _open) if mine else IDLE_ALPHA
	var width := VITALS_WIDTH
	var at := Vector2(body.get_center().x - width * 0.5, body.position.y + body.size.y * 0.5 - 10.0)
	if mine and _open > 0.01:
		at = _center() - Vector2(width * 0.5, 10.0)
	# Una placa oscura detras: sobre un robot blanco las rayitas no se veian.
	var plate := Rect2(at - Vector2(5, 5), Vector2(width + 10, 35))
	draw_rect(plate, Color(0.02, 0.04, 0.07, 0.62 * alpha))
	draw_rect(plate, Color(1, 1, 1, 0.12 * alpha), false, 1.0)
	var health := float(state["health"])
	var tone := HEALTH if health > 0.5 else (GOLD if health > 0.25 else BAD)
	_bar(at, width, 7.0, health, tone, alpha)
	# El manto de plasma (OBS-041): encima de la vida, mientras lo tenga.
	var layer := float(state.get("layer", -1.0))
	if layer > 0.0:
		var band := Rect2(at - Vector2(0, 2), Vector2(width * layer, 3.0))
		draw_rect(band, Color(PlasmaMantle.COLOR, alpha))
		draw_rect(Rect2(at, Vector2(width * layer, 7.0)), Color(PlasmaMantle.COLOR, 0.35 * alpha))
	var hot := HEAT
	if bool(state.get("over", false)):
		hot = BAD.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 10.0))
	_bar(at + Vector2(0, 10), width, 4.0, float(state["heat"]), hot, alpha)
	_bar(at + Vector2(0, 16), width, 4.0, float(state["energy"]), ENERGY, alpha)
	# El medidor de definitiva (OBS-055): dorado y, lleno, latiendo.
	var ult := float(state.get("ult", -1.0))
	if ult >= 0.0:
		var glow := RuleFx.COLOR_ULT
		if ult >= 1.0:
			glow = glow.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 8.0))
		_bar(at + Vector2(0, 22), width, 3.0, ult, glow, alpha)
	_draw_states(state.get("states", {}), at + Vector2(0, 30), alpha)
	if index != _turn:
		return
	for i in 2:
		var mid := at + Vector2(width * 0.5 - 9.0 + 18.0 * i, 34.0)
		var gem := PackedVector2Array(
			[mid + Vector2(0, -5), mid + Vector2(5, 0), mid + Vector2(0, 5), mid + Vector2(-5, 0)]
		)
		var on := i < _actions
		draw_colored_polygon(
			gem, Color(GOLD, alpha) if on else Color(0.08, 0.1, 0.14, 0.75 * alpha)
		)
		draw_polyline(gem + PackedVector2Array([gem[0]]), Color(GOLD, 0.9 * alpha), 1.2)


## Los estados que lleva (OBS-055): una ficha por estado, de su color, con
## su inicial y sus cargas.
func _draw_states(states: Dictionary, at: Vector2, alpha: float) -> void:
	var x := 0.0
	for kind: String in states:
		var color: Color = RuleFx.STATE_COLORS.get(kind, Color.WHITE)
		var chip := Rect2(at + Vector2(x, 0), Vector2(30, 15))
		draw_rect(chip, Color(color.darkened(0.6), 0.85 * alpha))
		draw_rect(chip, Color(color, alpha), false, 1.0)
		var label := "%s%d" % [Txt.t("state_short_" + kind), int(states[kind]["stacks"])]
		draw_string(_font, chip.position + Vector2(0, 12), label, 1, 30, 11, Color(color, alpha))
		x += 34.0


func _bar(
	at: Vector2, width: float, height: float, share: float, color: Color, alpha: float
) -> void:
	draw_rect(Rect2(at, Vector2(width, height)), Color(0.0, 0.0, 0.0, 0.7 * alpha))
	var filled := width * clampf(share, 0.0, 1.0)
	if filled > 0.0:
		draw_rect(Rect2(at, Vector2(filled, height)), Color(color, alpha))


func _draw_fan() -> void:
	var center := _center()
	var ease_open := 1.0 - pow(1.0 - _open, 3.0)
	for i in _entries.size():
		var rect := icon_rect(i)
		var at := center.lerp(rect.get_center(), ease_open)
		_draw_icon(i, Rect2(at - rect.size * 0.5, rect.size), _open)
	if _hover >= 0 and _open > 0.8 and card_for.is_valid():
		_draw_card(_hover)


## Un icono del abanico: encendido si se puede usar, en gris si no; dorado
## bajo el raton. Los usos que le quedan, en puntos.
func _draw_icon(index: int, rect: Rect2, alpha: float) -> void:
	var entry := _entries[index]
	var lit := is_lit(index)
	var hot := index == _hover
	var mid := rect.get_center()
	var radius := rect.size.x * 0.5
	var ring := GOLD if hot and lit else (LIT if lit else MUTED)
	if lit:
		var glow := 0.16 + 0.08 * sin(_time * 4.0 + index)
		draw_circle(mid, radius + 5.0, Color(ring, glow * alpha))
	draw_circle(mid, radius, Color(0.04, 0.07, 0.11, 0.86 * alpha))
	draw_arc(mid, radius, 0.0, TAU, 40, Color(ring, (0.95 if lit else 0.45) * alpha), 2.0)
	var fade := alpha * (1.0 if lit else 0.38)
	var art := rect.grow(-7.0)
	var def: ItemDef = entry["def"]
	if def == null or not PartIcon.paint(self, art, def, fade):
		_draw_glyph(str(entry["glyph"]), mid, radius * 0.5, Color(ring, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var uses := _uses[index]
	for u in clampi(uses, 0, 5):
		var dot := mid + Vector2((u - (clampi(uses, 0, 5) - 1) * 0.5) * 7.0, radius + 7.0)
		draw_circle(dot, 2.2, Color(GOLD, alpha))


## Simbolo de lo que no tiene pieza: el escudo, la reparacion, la materia
## oscura y enfriar.
func _draw_glyph(glyph: String, mid: Vector2, r: float, color: Color) -> void:
	match glyph:
		"shield":
			var shape := PackedVector2Array(
				[
					mid + Vector2(-r, -r * 0.9),
					mid + Vector2(r, -r * 0.9),
					mid + Vector2(r, r * 0.1),
					mid + Vector2(0, r * 1.1),
					mid + Vector2(-r, r * 0.1),
					mid + Vector2(-r, -r * 0.9)
				]
			)
			draw_polyline(shape, color, 2.0)
		"ultimate":
			for ray in 8:
				var angle := ray * TAU / 8.0
				var reach := r * (1.2 if ray % 2 == 0 else 0.7)
				draw_line(mid, mid + Vector2.from_angle(angle) * reach, color, 2.5)
			draw_circle(mid, r * 0.35, color)
		"repair":
			draw_rect(Rect2(mid - Vector2(r * 0.3, r), Vector2(r * 0.6, r * 2.0)), color)
			draw_rect(Rect2(mid - Vector2(r, r * 0.3), Vector2(r * 2.0, r * 0.6)), color)
		"dark":
			draw_circle(mid, r, Color(0.02, 0.0, 0.05, color.a))
			draw_arc(mid, r, 0.0, TAU, 28, Color(Color("b07bff"), color.a), 2.0)
			draw_arc(
				mid, r * 1.5, _time * 2.0, _time * 2.0 + PI, 16, Color("b07bff", 0.5 * color.a), 1.5
			)
		_:
			# Enfriar: un copo.
			for k in 3:
				var arm := Vector2.from_angle(PI * k / 3.0) * r * 1.15
				draw_line(mid - arm, mid + arm, color, 2.0)


## La tarjeta de la accion bajo el raton: su nombre y, en pequeno, su dano,
## su critico, lo que cuesta y por que no se puede usar, si es el caso.
func _draw_card(index: int) -> void:
	var card: Dictionary = card_for.call(_entries[index]["action"])
	var lines: Array = card.get("lines", [])
	var title := str(card.get("title", ""))
	var width := 60.0
	for line: Array in lines:
		width = maxf(
			width, _font.get_string_size(str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		)
	width = maxf(width, _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x) + 18.0
	var height := 24.0 + 15.0 * lines.size()
	var icon := icon_rect(index)
	var at := Vector2(icon.get_center().x - width * 0.5, icon.position.y - height - 10.0)
	if at.y < 6.0:
		at.y = icon.end.y + 14.0
	at.x = clampf(at.x, 6.0, size.x - width - 6.0)
	var box := Rect2(at, Vector2(width, height))
	draw_rect(box, Color(0.03, 0.06, 0.1, 0.9))
	draw_rect(box, Color(LIT, 0.55), false, 1.0)
	draw_string(_font, at + Vector2(9, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	for i in lines.size():
		var line: Array = lines[i]
		var color: Color = line[1]
		var y := at.y + 31.0 + 15.0 * i
		draw_string(
			_font, Vector2(at.x + 9, y), str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color
		)


## El rotulo: entra grande, se queda un momento y se va.
func _draw_banner() -> void:
	var age := float(_banner["age"])
	var enter := clampf(age / 0.14, 0.0, 1.0)
	var leave := clampf((BANNER_SECONDS - age) / 0.32, 0.0, 1.0)
	var alpha := enter * leave
	var font_size := roundi(lerpf(92.0, 58.0, 1.0 - pow(1.0 - enter, 3.0)))
	var text := str(_banner["text"])
	var color: Color = _banner["color"]
	var y := size.y * 0.36
	var strip := Rect2(0, y - 52.0, size.x, 84.0)
	draw_rect(strip, Color(0.0, 0.0, 0.0, 0.32 * alpha))
	draw_line(strip.position, strip.position + Vector2(size.x, 0), Color(color, 0.7 * alpha), 2.0)
	draw_line(strip.end - Vector2(size.x, 0), strip.end, Color(color, 0.7 * alpha), 2.0)
	var center := HORIZONTAL_ALIGNMENT_CENTER
	draw_string_outline(
		_font, Vector2(0, y + 8.0), text, center, size.x, font_size, 10, Color(0, 0, 0, 0.8 * alpha)
	)
	draw_string(_font, Vector2(0, y + 8.0), text, center, size.x, font_size, Color(color, alpha))
	var small := str(_banner["small"])
	if small != "":
		draw_string(
			_font, Vector2(0, y + 26.0), small, center, size.x, 14, Color(TEXT, 0.85 * alpha)
		)
