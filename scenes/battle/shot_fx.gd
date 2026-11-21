class_name ShotFx
extends Node2D
## Disparos e impactos de las armas (docs/CATALOGO_ARMAS.md, seccion 9). Cada
## arma lleva en el catalogo su disparo (ItemDef.fx) y data/shots.json dice
## como se ve: camino, cuerpo, cuantos proyectiles, velocidad e impacto. Es
## solo presentacion: el dano ya lo decidio el motor.
##
## Todo se dibuja a mano: cada efecto vivo es un diccionario con su inicio y
## su duracion, y _draw lo pinta segun lo que lleve de vida. Los impactos se
## programan para el momento en que llega su proyectil.

signal shake_requested(strength: float)

const SHOTS_PATH := "res://data/shots.json"
## Altura maxima del arco de la artilleria, en unidades del mundo.
const HIGH_ARC_CAP := 420.0
## Disparo de las armas que no traen el suyo.
const DEFAULT_SHOT := "perno"
## Paso del combate a velocidad normal (BattleScreen.STEP_SECONDS): los
## tiempos de shots.json valen a esa velocidad y se escalan con ella.
const REFERENCE_STEP := 0.42
const PATHS: Array[String] = [
	"straight",
	"arc",
	"high_arc",
	"missile",
	"drop",
	"stream",
	"beam",
	"orbital",
	"cable",
	"ring",
	"wave",
	"melee",
]
const BODIES: Array[String] = [
	"tracer",
	"pellet",
	"slug",
	"shell",
	"grenade",
	"bolt",
	"orb",
	"missile",
	"harpoon",
	"bomb",
	"beam",
	"tractor",
	"drain",
	"ring",
	"rays",
	"wave",
	"slash",
]
const IMPACTS: Array[String] = ["sparks", "explosion", "splash", "burn", "drain"]
const TRAILS: Array[String] = ["", "smoke", "glow", "streak"]
## Lo que vale cada campo de un disparo que no lo da.
const DEFAULTS := {
	"desc": "",
	"path": "straight",
	"body": "bolt",
	"count": 1,
	"gap": 0.0,
	"spread": 0.0,
	"speed": 3000.0,
	"max_travel": 0.5,
	"size": 1.0,
	"hold": 0.0,
	"trail": "",
	"impact": "sparks",
	"impact_size": 1.0,
	"core": "",
	## Fuerza del culatazo del arma (1 = el de siempre).
	"kick": 1.0,
}
## Nucleos de los disparos: "" blanco; "dark" el negro de la materia oscura.
const CORES: Array[String] = ["", "dark"]
const DARK_CORE := Color("12061f")
## Cargas de la materia oscura segun el tipo del arma de pecho: las
## particulas llegan derechas al canon, en espiral al plasma y en rayas a la
## lente del laser.
const CHARGE_STYLES: Array[String] = ["canon", "blaster", "laser"]
## Los tamanos de shots.json se multiplican por esto. Con la camara alejada
## (zoom de 0.5 a 0.7) los trazos finos apenas se leian.
const BODY_SCALE := 1.8
const IMPACT_SCALE := 1.4
## Luces de cada municion en los disparos. El acero de la cinetica, que en el
## dibujo del arma va bien, en un disparo queda apagado: va como metal al
## rojo blanco.
const AMMO_COLORS: Array[Color] = [
	Color("ffd98a"), Color("ff7a2e"), Color("3dd6ff"), Color("e8d27a")
]
const CORE := Color("fff3d6")
const FIRE := Color("ffb347")
const SMOKE := Color(0.62, 0.62, 0.66)
const METAL := Color("6a7384")
const CABLE := Color("c8d2de")

static var _table: Dictionary = {}

var _time := 0.0
var _effects: Array[Dictionary] = []
## Nucleo del disparo que se esta lanzando o dibujando.
var _core := CORE


## Los disparos de data/shots.json, por id.
static func table() -> Dictionary:
	if _table.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHOTS_PATH))
		if raw is Dictionary and raw.get("shots") is Dictionary:
			_table = raw["shots"]
	return _table


static func is_known(id: String) -> bool:
	return table().has(id)


## Un disparo con todos sus campos; el de por defecto si no existe.
static func shot(id: String) -> Dictionary:
	var raw: Dictionary = table().get(id, table().get(DEFAULT_SHOT, {}))
	var out := DEFAULTS.duplicate()
	out.merge(raw, true)
	out["size"] = float(out["size"]) * BODY_SCALE
	out["impact_size"] = float(out["impact_size"]) * IMPACT_SCALE
	return out


## Color de las luces del disparo para una municion (ItemDef.Element).
static func ammo_color(element: int) -> Color:
	return AMMO_COLORS[clampi(element, 0, AMMO_COLORS.size() - 1)]


## El gesto del arma de `mech` al disparar ese disparo: un golpe por cada
## proyectil (una rafaga tiembla; un tiro suelto da un solo culatazo), con
## la fuerza de su "kick". `play_seconds` es la duracion que se le da a play.
static func kick(
	mech: MechView, id: String, seconds: float, slot: String, play_seconds: float
) -> void:
	var s := shot(id)
	var k := clampf(play_seconds / REFERENCE_STEP, 0.3, 2.5)
	mech.fire(seconds, slot, int(s["count"]), float(s["gap"]) * k, float(s["kick"]))


## Lo que esta mal en data/shots.json (para los tests).
static func problems() -> Array[String]:
	var out: Array[String] = []
	if not table().has(DEFAULT_SHOT):
		out.append("falta el disparo por defecto '%s'" % DEFAULT_SHOT)
	for id: String in table():
		var raw: Dictionary = table()[id]
		for key: String in raw:
			if not DEFAULTS.has(key):
				out.append("%s: campo desconocido '%s'" % [id, key])
		var s := shot(id)
		if not s["path"] in PATHS:
			out.append("%s: camino desconocido '%s'" % [id, s["path"]])
		if not s["body"] in BODIES:
			out.append("%s: cuerpo desconocido '%s'" % [id, s["body"]])
		if not s["impact"] in IMPACTS:
			out.append("%s: impacto desconocido '%s'" % [id, s["impact"]])
		if not s["trail"] in TRAILS:
			out.append("%s: estela desconocida '%s'" % [id, s["trail"]])
		if not s["core"] in CORES:
			out.append("%s: nucleo desconocido '%s'" % [id, s["core"]])
		if int(s["count"]) < 1 or float(s["speed"]) <= 0.0 or float(s["size"]) <= 0.0:
			out.append("%s: count, speed y size deben ser positivos" % id)
		if str(s["desc"]) == "":
			out.append("%s: falta la descripcion" % id)
	return out


## Dispara `id` de `from` a `to` con el color de su municion. Vuelve cuando
## llega el ultimo impacto; los efectos siguen solos hasta apagarse.
func play(id: String, from: Vector2, to: Vector2, color: Color, seconds: float) -> void:
	var s := shot(id)
	_core = DARK_CORE if s["core"] == "dark" else CORE
	var k := clampf(seconds / REFERENCE_STEP, 0.3, 2.5)
	var count: int = s["count"]
	var arrival := 0.0
	var flashes: bool = s["path"] != "melee" and s["path"] != "orbital"
	# Los que salen todos a la vez (los perdigones) suenan como un solo tiro.
	var together := float(s["gap"]) <= 0.0
	for i in count:
		var delay: float = float(s["gap"]) * k * i
		var offset := _scatter(s, i, count)
		var origin := from + offset if s["path"] == "beam" else from
		# Un fogonazo por cada proyectil que sale en su momento.
		if flashes and (i == 0 or not together):
			_muzzle_flash(from, color, s, k, delay)
		var reach := delay + _launch(s, origin, to + offset, color, k, delay, i)
		_impact(s, to + offset, color, k, reach)
		# Un tajo suena desde que la hoja empieza a moverse: lo pide quien la
		# mueve (ArenaView.strike), antes de que llegue aqui el corte.
		if (i == 0 or not together) and s["path"] != "melee":
			Sfx.shot_fired(id, delay)
		if i < 2 or not together:
			Sfx.shot_hit(id, s["impact"], reach)
		arrival = maxf(arrival, reach)
	_core = CORE
	await get_tree().create_timer(maxf(arrival, 0.01)).timeout


## Carga de la materia oscura en la boca del arma de pecho: particulas que
## llegan (derechas, en espiral o en rayas segun `style`) y una esfera negra
## que crece. Vuelve cuando esta cargada.
func charge(at: Vector2, color: Color, seconds: float, style: String) -> void:
	var kind := style if style in CHARGE_STYLES else "canon"
	_add(_effect("charge", _time, seconds, color, 1.0, {"at": at, "style": kind}))
	await get_tree().create_timer(seconds).timeout


func _process(delta: float) -> void:
	_time += delta
	var alive: Array[Dictionary] = []
	for effect in _effects:
		if effect["kind"] == "shake" and _time >= effect["start"]:
			shake_requested.emit(effect["strength"])
			continue
		if _time <= effect["start"] + effect["life"]:
			alive.append(effect)
	_effects = alive
	queue_redraw()


func _add(effect: Dictionary) -> void:
	_effects.append(effect)


# --- Salida -------------------------------------------------------------------


## Lanza un proyectil (o haz, onda, tajo) y devuelve cuanto tarda en llegar,
## contado desde su salida.
func _launch(
	s: Dictionary, from: Vector2, to: Vector2, color: Color, k: float, delay: float, index: int
) -> float:
	var path: String = s["path"]
	var start := _time + delay
	var size: float = s["size"]
	var distance := from.distance_to(to)
	var travel := minf(distance / float(s["speed"]), float(s["max_travel"])) * k
	var hold := maxf(float(s["hold"]), 0.12) * k
	match path:
		"melee":
			var facing := signf(to.x - from.x) if to.x != from.x else 1.0
			_add(_effect("slash", start, 0.24 * k, color, size, {"at": to, "facing": facing}))
			return 0.08 * k
		"beam":
			_add(
				_effect(
					"beam", start, hold, color, size, {"from": from, "to": to, "body": s["body"]}
				)
			)
			return 0.03 * k
		"orbital":
			var charge := 0.2 * k
			_add(_effect("reticle", start, charge + hold * 0.5, color, size, {"at": to}))
			var sky := to + Vector2(60.0, -1600.0)
			_add(_effect("beam", start + charge, hold, color, size, {"from": sky, "to": to}))
			return charge + 0.03 * k
		"ring":
			var reach := distance + 40.0
			var ring := {"at": from, "r0": 24.0, "r1": reach, "body": s["body"]}
			_add(_effect("ring", start, travel, color, size, ring))
			return travel
		"wave":
			_add(_effect("wave", start, travel, color, size, {"from": from, "to": to}))
			return travel
	var flight := {"path": path, "from": from, "to": to, "body": s["body"], "trail": s["trail"]}
	match path:
		"arc":
			flight["height"] = clampf(distance * 0.3, 60.0, 260.0)
		"high_arc":
			# Con techo: mas alto, el obus se salia por arriba de la arena.
			flight["height"] = minf(distance * 0.45 + 180.0, HIGH_ARC_CAP)
		"missile":
			var rise := 170.0 + 60.0 * _noise(index, 3.0)
			flight["control"] = from + Vector2(0.0, -rise) + (to - from) * 0.15
		"drop":
			flight["control"] = Vector2(lerpf(from.x, to.x, 0.85), from.y - 20.0)
		"cable":
			flight["path"] = "straight"
			var line := {"from": from, "to": to, "travel": travel}
			_add(_effect("cable", start, travel + hold, color, size, line))
	_add(_effect("projectile", start, travel, color, size, flight))
	return travel


func _effect(
	kind: String, start: float, life: float, color: Color, size: float, extra: Dictionary
) -> Dictionary:
	var out := {"kind": kind, "start": start, "life": maxf(life, 0.01), "color": color}
	out["size"] = size
	out["dark"] = _core == DARK_CORE
	out.merge(extra)
	return out


## Desvio de cada proyectil respecto al blanco: en abanico parejo si salen a
## la vez (perdigones, haces paralelos) y al azar fijo si salen seguidos.
func _scatter(s: Dictionary, index: int, count: int) -> Vector2:
	var spread: float = s["spread"]
	if spread <= 0.0:
		return Vector2.ZERO
	if float(s["gap"]) <= 0.0 and count > 1:
		return Vector2(0.0, lerpf(-spread, spread, float(index) / float(count - 1)))
	return Vector2(0.0, (_noise(index, 5.0) - 0.5) * 2.0 * spread)


func _muzzle_flash(at: Vector2, color: Color, s: Dictionary, k: float, delay: float = 0.0) -> void:
	# El fogonazo crece con el culatazo del arma: el de una escopeta es grande.
	var size: float = float(s["size"]) * float(s["kick"])
	var glow := CORE.lerp(color, 0.45)
	var start := _time + delay
	var blob := {"at": at, "r0": 6.0, "r1": 14.0 + 12.0 * size}
	_add(_effect("blob", start, 0.12 * k, glow, size, blob))
	if s["path"] == "ring":
		var flash := {"at": at, "r0": 12.0, "r1": 40.0 * size, "body": "ring"}
		_add(_effect("ring", start, 0.16 * k, color.lightened(0.4), size * 0.5, flash))


# --- Impactos -------------------------------------------------------------------


func _impact(s: Dictionary, at: Vector2, color: Color, k: float, delay: float) -> void:
	var size: float = s["impact_size"]
	var start := _time + delay
	var hold := maxf(float(s["hold"]), 0.12) * k
	match s["impact"]:
		"sparks":
			_add(
				_effect(
					"blob", start, 0.1 * k, CORE, size, {"at": at, "r0": 6.0, "r1": 22.0 * size}
				)
			)
			_sparks(at, CORE.lerp(color, 0.4), size, start, k)
		"explosion":
			var fire := FIRE.lerp(color, 0.3)
			var ball := {"at": at, "r0": 14.0, "r1": 74.0 * size}
			_add(_effect("blob", start, 0.34 * k, fire, size, ball))
			var core := {"at": at, "r0": 8.0, "r1": 38.0 * size}
			_add(_effect("blob", start, 0.18 * k, CORE, size, core))
			var shock := {"at": at, "r0": 12.0, "r1": 120.0 * size, "body": "ring"}
			_add(_effect("ring", start, 0.28 * k, fire, size, shock))
			_sparks(at, fire, size * 1.4, start, k)
			for j in 4:
				var puff := Vector2(_noise(j, 7.0) - 0.5, _noise(j, 8.0) - 0.6) * 60.0 * size
				var smoke := {"at": at + puff, "r0": 12.0 * size, "r1": 38.0 * size}
				_add(_effect("puff", start + 0.05 * k * j, 0.7 * k, SMOKE, size, smoke))
			_add({"kind": "shake", "start": start, "life": 0.01, "strength": 3.0 + 6.0 * size})
		"splash":
			var glow := {"at": at, "r0": 10.0, "r1": 46.0 * size}
			_add(_effect("blob", start, 0.24 * k, color.lightened(0.3), size, glow))
			var ring := {"at": at, "r0": 8.0, "r1": 80.0 * size, "body": "ring"}
			_add(_effect("ring", start, 0.28 * k, color, size * 0.6, ring))
			_sparks(at, color.lightened(0.45), size, start, k)
		"burn":
			var heat := {"at": at, "r0": 16.0 * size, "r1": 42.0 * size}
			_add(_effect("blob", start, hold + 0.15 * k, color, size, heat))
			var white := {"at": at, "r0": 8.0 * size, "r1": 20.0 * size}
			_add(_effect("blob", start, hold + 0.1 * k, CORE, size, white))
			_sparks(at, color.lightened(0.5), size * 0.8, start, k)
		"drain":
			var pull := {"at": at, "r0": 34.0 * size, "r1": 10.0 * size}
			_add(_effect("blob", start, hold, color.lightened(0.3), size, pull))


func _sparks(at: Vector2, color: Color, size: float, start: float, k: float) -> void:
	var count := int(6.0 + 6.0 * size)
	for j in count:
		var direction := Vector2.from_angle(TAU * (j + _noise(j, 1.0)) / count)
		var reach := (50.0 + 70.0 * _noise(j, 2.0)) * size
		var ray := {"at": at, "dir": direction, "reach": reach}
		_add(_effect("spark", start, (0.2 + 0.12 * _noise(j, 4.0)) * k, color, size, ray))


# --- Dibujo ---------------------------------------------------------------------


func _draw() -> void:
	for effect in _effects:
		var t := (_time - float(effect["start"])) / float(effect["life"])
		if t < 0.0 or t > 1.0:
			continue
		_core = DARK_CORE if effect.get("dark", false) else CORE
		match effect["kind"]:
			"charge":
				_draw_charge(effect, t)
			"projectile":
				_draw_projectile(effect, t)
			"beam":
				_draw_beam(effect, t)
			"cable":
				_draw_cable(effect)
			"ring":
				_draw_ring(effect, t)
			"wave":
				_draw_wave(effect, t)
			"slash":
				_draw_slash(effect, t)
			"reticle":
				_draw_reticle(effect, t)
			"blob":
				_draw_blob(effect, t)
			"puff":
				var rise := Vector2(0.0, -50.0 * t)
				var radius := lerpf(effect["r0"], effect["r1"], t)
				draw_circle(effect["at"] + rise, radius, _alpha(SMOKE, 0.32 * (1.0 - t)))
			"spark":
				var eased := 1.0 - (1.0 - t) * (1.0 - t)
				var head: Vector2 = effect["at"] + effect["dir"] * effect["reach"] * eased
				var tail: Vector2 = head - effect["dir"] * (8.0 + 12.0 * (1.0 - t))
				draw_line(tail, head, _alpha(effect["color"], 1.0 - t), 3.0, true)


func _draw_charge(e: Dictionary, t: float) -> void:
	var at: Vector2 = e["at"]
	var color: Color = e["color"]
	var reach := 190.0
	for j in 18:
		var u := fposmod(t * 3.0 + j / 18.0, 1.0)
		var direction := Vector2.from_angle(TAU * j / 18.0)
		var tint := _alpha(color.lightened(0.3), u)
		match e["style"]:
			"blaster":
				var swirl := Vector2.from_angle(TAU * j / 18.0 + u * 4.0)
				draw_circle(at + swirl * reach * (1.0 - u), 5.0 * (1.0 - u) + 2.0, tint)
			"laser":
				var head := at + direction * reach * (1.0 - u)
				draw_line(head, head + direction * 30.0 * (1.0 - u), tint, 3.0, true)
			_:
				draw_circle(at + direction * reach * (1.0 - u), 4.0 + 3.0 * (1.0 - u), tint)
	var radius := 8.0 + 34.0 * t
	var pulse := 1.0 + 0.08 * sin(_time * 30.0)
	draw_circle(at, radius * 1.7 * pulse, _alpha(color, 0.25))
	draw_circle(at, radius, DARK_CORE)
	draw_arc(at, radius, 0.0, TAU, 40, color.lightened(0.35), 3.0, true)


## Punto del camino de un proyectil a esa altura de su viaje (0 a 1).
func _point(e: Dictionary, u: float) -> Vector2:
	var from: Vector2 = e["from"]
	var to: Vector2 = e["to"]
	match e["path"]:
		"arc", "high_arc":
			return from.lerp(to, u) + Vector2(0.0, -4.0 * float(e["height"]) * u * (1.0 - u))
		"missile", "drop":
			var control: Vector2 = e["control"]
			return from.lerp(control, u).lerp(control.lerp(to, u), u)
	return from.lerp(to, u)


func _heading(e: Dictionary, u: float) -> Vector2:
	var ahead := _point(e, minf(u + 0.02, 1.0)) - _point(e, maxf(u - 0.02, 0.0))
	if ahead.length() < 0.001:
		return (e["to"] - e["from"]).normalized()
	return ahead.normalized()


func _draw_projectile(e: Dictionary, t: float) -> void:
	var p := _point(e, t)
	var d := _heading(e, t)
	var size: float = e["size"]
	var color: Color = e["color"]
	_draw_trail(e, t)
	if e["path"] == "stream":
		# El chorro se abre y se apaga al alejarse de la boca.
		size *= 0.5 + 1.3 * t
		color = _alpha(color, 1.0 - 0.6 * t)
	match e["body"]:
		"tracer":
			_streak(p, d, 46.0 * size, color, 6.0 * size, 2.5 * size)
		"pellet":
			_streak(p, d, 18.0 * size, color, 5.0 * size, 2.2 * size)
		"slug":
			_streak(p, d, 84.0 * size, color, 5.0 * size, 2.6 * size)
		"bolt":
			_streak(p, d, 44.0 * size, color, 15.0 * size, 6.0 * size)
		"orb":
			_orb(p, size, color)
		"shell":
			_shell(p, d, size, color)
		"grenade":
			draw_circle(p, 9.0 * size, METAL)
			draw_circle(p + d.orthogonal() * 3.0 * size, 3.0 * size, color.lightened(0.4))
		"missile":
			_missile(p, d, size, color)
		"harpoon":
			_harpoon(p, d, size)
		"bomb":
			draw_circle(p, 16.0 * size, _alpha(color, 0.35))
			draw_circle(p, 10.0 * size, METAL.darkened(0.35))
			draw_line(p - d * 9.0 * size, p - d * 17.0 * size, METAL, 6.0 * size, true)
			draw_circle(p, 3.0 * size, color.lightened(0.3))


func _draw_trail(e: Dictionary, t: float) -> void:
	var size: float = e["size"]
	match e["trail"]:
		"smoke", "glow":
			var tint: Color = SMOKE if e["trail"] == "smoke" else e["color"]
			for j in range(1, 8):
				var u := t - j * 0.04
				if u < 0.0:
					break
				var alpha := 0.34 - j * 0.04
				draw_circle(_point(e, u), (4.0 + j * 2.4) * size, _alpha(tint, alpha))
		"streak":
			var u0 := maxf(0.0, t - 0.45)
			draw_line(_point(e, u0), _point(e, t), _alpha(CORE, 0.35), 2.0 * size, true)


## Trazo de luz: un halo del color de la municion y un nucleo blanco.
func _streak(p: Vector2, d: Vector2, length: float, glow: Color, width: float, core: float) -> void:
	draw_line(p - d * length, p, _alpha(glow, 0.45 * glow.a), width, true)
	draw_line(p - d * length * 0.7, p, _alpha(_core, glow.a), core, true)


func _orb(p: Vector2, size: float, color: Color) -> void:
	var flicker := 1.0 + 0.12 * sin(_time * 40.0)
	draw_circle(p, 17.0 * size * flicker, _alpha(color, 0.25 * color.a))
	draw_circle(p, 10.0 * size, _alpha(color.lightened(0.25), 0.7 * color.a))
	draw_circle(p, 5.0 * size, _alpha(_core, color.a))


## Obus: cuerpo de metal con la punta hacia delante y el culote encendido.
func _shell(p: Vector2, d: Vector2, size: float, color: Color) -> void:
	var n := d.orthogonal()
	var grow := 1.2 * size
	var outline := PackedVector2Array()
	for point: Vector2 in [
		Vector2(15, 0), Vector2(6, -6), Vector2(-13, -6), Vector2(-13, 6), Vector2(6, 6)
	]:
		outline.append(p + d * point.x * grow + n * point.y * grow)
	draw_circle(p - d * 14.0 * grow, 7.0 * grow, _alpha(color.lightened(0.3), 0.8))
	# El obus de materia oscura es negro; los demas, de metal.
	var hull := DARK_CORE.lightened(0.12) if _core == DARK_CORE else METAL.lightened(0.15)
	draw_colored_polygon(outline, hull)
	draw_line(p + n * -6.0 * grow, p + n * 6.0 * grow, METAL.darkened(0.3), 2.0 * size)


func _missile(p: Vector2, d: Vector2, size: float, color: Color) -> void:
	draw_circle(p - d * 24.0 * size, 7.0 * size, _alpha(FIRE, 0.8))
	draw_circle(p - d * 24.0 * size, 3.5 * size, CORE)
	draw_line(p - d * 20.0 * size, p, METAL.lightened(0.3), 6.0 * size, true)
	draw_circle(p, 3.2 * size, color.lightened(0.35))


func _harpoon(p: Vector2, d: Vector2, size: float) -> void:
	var n := d.orthogonal()
	var head := PackedVector2Array(
		[
			p + d * 12.0 * size,
			p - d * 6.0 * size + n * 8.0 * size,
			p - d * 6.0 * size - n * 8.0 * size
		]
	)
	draw_line(p - d * 30.0 * size, p, METAL.lightened(0.4), 5.0 * size, true)
	draw_colored_polygon(head, CABLE)


func _draw_cable(e: Dictionary) -> void:
	var elapsed := _time - float(e["start"])
	var reach := clampf(elapsed / float(e["travel"]), 0.0, 1.0)
	var tip: Vector2 = e["from"].lerp(e["to"], reach)
	var fade := clampf((float(e["life"]) - elapsed) / (0.3 * float(e["life"])), 0.0, 1.0)
	draw_line(e["from"], tip, _alpha(CABLE, fade), 3.0, true)


func _draw_beam(e: Dictionary, t: float) -> void:
	var f := clampf(t / 0.15, 0.0, 1.0) * clampf((1.0 - t) / 0.35, 0.0, 1.0)
	if f <= 0.01:
		return
	var a: Vector2 = e["from"]
	var b: Vector2 = e["to"]
	var size: float = e["size"]
	var color: Color = e["color"]
	var body: String = e.get("body", "beam")
	if body == "drain":
		_draw_drain(a, b, size, color, f, t)
		return
	if body == "tractor":
		draw_line(a, b, _alpha(color, 0.22 * f), 16.0 * size, true)
		draw_line(a, b, _alpha(color.lightened(0.3), 0.5 * f), 3.0 * size, true)
		for j in 5:
			var u := fposmod(t * 1.8 + j / 5.0, 1.0)
			var ring := 20.0 * size * (1.0 - u * 0.45)
			var tint := _alpha(color.lightened(0.35), f * (1.0 - 0.7 * u))
			draw_arc(b.lerp(a, u), ring, 0.0, TAU, 24, tint, 3.0 * size, true)
		return
	draw_line(a, b, _alpha(color, 0.25 * f), 22.0 * size * f, true)
	draw_line(a, b, _alpha(color.lightened(0.3), 0.7 * f), 9.0 * size * f, true)
	draw_line(a, b, _alpha(_core, f), 3.2 * size * f, true)


## Haz que absorbe: una linea que ondula y bolitas que van del rival a quien
## dispara.
func _draw_drain(a: Vector2, b: Vector2, size: float, color: Color, f: float, t: float) -> void:
	var n := (b - a).normalized().orthogonal()
	var wave := PackedVector2Array()
	for j in 17:
		var u := j / 16.0
		wave.append(a.lerp(b, u) + n * sin(u * 14.0 + _time * 16.0) * 7.0 * size)
	draw_polyline(wave, _alpha(color, 0.75 * f), 3.0 * size, true)
	for j in 7:
		var u := fposmod(t * 2.2 + j / 7.0, 1.0)
		var bead := b.lerp(a, u) + n * sin(u * 14.0 + _time * 16.0) * 7.0 * size
		draw_circle(bead, 4.5 * size * (1.0 - u * 0.5), _alpha(color.lightened(0.4), f))


func _draw_ring(e: Dictionary, t: float) -> void:
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var radius := lerpf(e["r0"], e["r1"], eased)
	var size: float = e["size"]
	var color: Color = e["color"]
	if e.get("body", "ring") == "rays":
		for j in 14:
			var direction := Vector2.from_angle(TAU * j / 14.0 + 0.2)
			var tail: Vector2 = e["at"] + direction * radius * 0.55
			var head: Vector2 = e["at"] + direction * radius
			draw_line(tail, head, _alpha(CORE.lerp(color, 0.4), 1.0 - t), 5.0 * size, true)
		return
	var width := (12.0 * (1.0 - t) + 2.0) * size
	draw_arc(e["at"], radius, 0.0, TAU, 64, _alpha(color, 1.0 - t), width, true)


## Onda de presion: un arco que avanza hacia el rival y se abre.
func _draw_wave(e: Dictionary, t: float) -> void:
	var d: Vector2 = (e["to"] - e["from"]).normalized()
	var size: float = e["size"]
	var center: Vector2 = e["from"].lerp(e["to"], t)
	var radius := 34.0 * size * (1.0 + 0.7 * t)
	var heading := d.angle()
	var color: Color = e["color"]
	var arc_from := heading - 0.95
	var arc_to := heading + 0.95
	draw_arc(center - d * radius, radius, arc_from, arc_to, 20, _alpha(color, 1.0 - 0.5 * t), 7.0)
	draw_arc(center - d * radius, radius, arc_from, arc_to, 20, _alpha(CORE, 0.8 - 0.5 * t), 2.5)


## Tajo: un arco de luz que barre el cuerpo del rival.
func _draw_slash(e: Dictionary, t: float) -> void:
	var size: float = e["size"]
	var facing: float = e["facing"]
	var sweep := 1.0 - (1.0 - t) * (1.0 - t)
	var start := -2.3
	var finish := 0.9
	var reach := lerpf(start, finish, sweep)
	var radius := 64.0 * size
	var color: Color = e["color"]
	var center: Vector2 = e["at"] - Vector2(facing * 20.0, 0.0)
	var points := PackedVector2Array()
	var steps := 18
	for j in steps + 1:
		var angle := lerpf(maxf(start, reach - 1.6), reach, float(j) / steps)
		var direction := Vector2.from_angle(angle)
		points.append(center + Vector2(direction.x * facing, direction.y) * radius)
	var fade := 1.0 - t * t
	var glow := _alpha(color.lightened(0.2), 0.7 * fade)
	draw_polyline(points, glow, 16.0 * size * fade + 3.0, true)
	draw_polyline(points, _alpha(CORE, fade), 5.0 * size * fade + 1.5, true)


## Mira que se cierra sobre el rival antes de que caiga el rayo orbital.
func _draw_reticle(e: Dictionary, t: float) -> void:
	var radius := lerpf(70.0, 22.0, minf(t * 1.6, 1.0))
	var color: Color = e["color"]
	var at: Vector2 = e["at"]
	var tint := _alpha(color.lightened(0.3), 0.95 * (1.0 - t * 0.5))
	draw_arc(at, radius, 0.0, TAU, 40, tint, 4.0, true)
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(at + direction * radius * 0.6, at + direction * radius * 1.4, tint, 4.0, true)


func _draw_blob(e: Dictionary, t: float) -> void:
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var radius := lerpf(e["r0"], e["r1"], eased)
	draw_circle(e["at"], radius, _alpha(e["color"], 0.85 * (1.0 - t)))


static func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


## Azar fijo para la presentacion: el mismo indice da siempre lo mismo.
static func _noise(index: int, salt: float) -> float:
	return fposmod(sin(index * 12.9898 + salt * 78.233) * 43758.5453, 1.0)
