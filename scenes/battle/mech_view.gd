class_name MechView
extends Node2D

## Un pie toca el suelo (pasos y aterrizajes), en las coordenadas del padre.
signal footstep(at: Vector2)
## Dibuja un mech en la arena. De momento con figuras provisionales por pieza
## (bloques de color segun el elemento); el arte definitivo de la fase F4
## sustituira a _draw sin tocar el resto.

const ELEMENT_COLORS: Array[Color] = [
	Color("9aa7b4"),  # fisico: acero
	Color("ff8a3d"),  # calor: naranja
	Color("3dd6ff"),  # energia: cian
	Color("c9b458"),  # combinado
]
const OUTLINE := Color("10151c")
## Escala del dibujo: un mech debe caber en su casilla con el rival al lado.
const DRAW_SCALE := 1.05
## Juego de sprites que tiene el canon de pecho (assets/mechs).
const CHEST_SET := "ligero_18"
## Cuanto suben las armas provisionales para quedar sobre el torso nuevo.
const SPRITE_WEAPON_LIFT := -44.0
## Cuanto retrocede el arma al disparar y cuanto queda metida al guardarse.
const RECOIL := 16.0
## Los jefes se dibujan mas grandes.
const BOSS_SCALE := 1.15
const RETRACT := 78.0
## Zancada: radianes de fase por segundo al andar.
const GAIT_SPEED := 10.0
## Cuanto se separa la pierna de detras y cuanto se oscurece.
const FAR_LEG_OFFSET := Vector2(-14.0, -2.0)
const FAR_LEG_DIM := 0.65
## Donde va cada arma respecto a la que se dibujo sobre el robot, en
## unidades de MechView. Desde el 2026-11-21 (OBS-033) son dos de brazo y una
## de hombro, todas del lado que se ve, delante del torso.
const SIDE_MOUNTS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(8.0, 34.0)]
const TOP_MOUNTS: Array[Vector2] = [Vector2(0.0, 0.0)]
## A partir de que indice las armas van del lado lejano.
const FAR_SIDE_FROM := 2
## Eje del hombro de un arma de brazo respecto a la cintura del robot (el
## de tools/art/export_weapons.py, ARM_UNION, en unidades de MechView): sobre
## el gira la hoja al dar un tajo. Y cuanto se levanta y cuanto cae.
const WEAPON_SHOULDER := Vector2(-30.0, -65.0) * MechSprites.UNIT_SCALE
const SWING_RAISE := -0.62
const SWING_FALL := 0.42
const FAR_TOP_FROM := 1
const FAR_WEAPON_DIM := 0.62
## Donde flota el robot de asistencia respecto a los pies del mech: detras
## del torso, y mas atras en cada transformacion (las formas grandes son mas
## anchas). La altura sale de su mech: flota por encima de lo mas alto (el
## torso o el arma de hombro) con este aire libre, para no montarse encima.
const ASSIST_BACK := -112.0
const ASSIST_BACK_STEP := -7.0
const ASSIST_CLEARANCE := 18.0
## Donde cuelga el arma inferior del robot de asistencia, respecto a la
## superior.
const DRONE_LOW_OFFSET := Vector2(10.0, 30.0)
## Altura a la que flotan las piernas que levitan.
const HOVER_HEIGHT := 16.0
const FLAME_CORE := Color(1.0, 0.95, 0.75)
const FLAME_EDGE := Color(1.0, 0.45, 0.12)
const HOVER_GLOW := Color(0.45, 0.9, 1.0)

var build: MechBuild
## Estado a la vista (MechWear): vida y energia como parte de su maximo, y
## los efectos de un critico que sufre en su turno.
var health_ratio := 1.0
var energy_ratio := 1.0
var immobilized := false
var disabled_slot := ""
var stunned := false
## 1 si mira a la derecha, -1 si mira a la izquierda.
var facing: int = 1
## Huecos ("torso", "legs") que se dibujan como fantasma: en el taller, un
## torso o unas piernas que faltan se ven transparentes, para que se note el
## hueco sin que el mech se quede flotando.
var ghost_slots: Array[String] = []
## Solo se dibuja esta capa del robot ("" = todas), para el giro del hangar
## (TurntableMech; desde OBS-033 ya no pide las del lado lejano): "far" y
## "far_top" (armas de brazo y de hombro del lado
## lejano), "far_leg", "body" (torso y piernas de una pieza), "chest" (canon
## de pecho), "near_leg", "near_top" y "near" (armas del lado cercano) y
## "float" (asistente o dron). Una capa suelta no se apaga por estar detras:
## eso lo decide quien la gira.
var only_layer: String = ""
var heat_ratio: float = 0.0
var shut_down: bool = false

var _base_position := Vector2.ZERO
## Arte por piezas del mech; null mientras no este exportado (se usan bloques).
var _sprites: MechSprites
var _time := 0.0
var _walking := false
## Retroceso del arma, en unidades hacia atras.
var _recoil := 0.0
## Hueco del arma que acaba de disparar (la que retrocede).
var _fired_slot := ""
## Giro del arma que da un tajo, en radianes (negativo = levantada), y su
## hueco.
var _swing := 0.0
var _swing_slot := ""
## Cuanto ha salido el arma del torso: 0 guardada, 1 desplegada.
var _deploy := 0.0
var _deployed := false
## Cuanto se ha desplomado por estar apagado, de 0 a 1.
var _slump := 0.0
var _dead := false
## Como se mueve segun sus piernas: "walk" (anda y salta), "roll" (orugas o
## ruedas) o "hover" (levita).
var _locomotion := "walk"
## Fase de la zancada y sentido: 1 hacia delante, -1 marcha atras.
var _gait := 0.0
var _gait_dir := 1.0
## Propulsores (0 apagados, 1 a tope), agachado, inclinacion del cuerpo
## (+ hacia delante), pose de aguantar un empujon, y si va por el aire.
var _thrust := 0.0
var _crouch := 0.0
var _lean := 0.0
var _brace := 0.0
var _airborne := false
## Esqueleto de las piernas (null sin arte).
var _rig: LegRig


func setup(p_build: MechBuild, p_facing: int) -> void:
	build = p_build
	_sprites = MechSprites.for_build(build)
	_rig = null
	if _sprites != null and not _sprites.rigid_legs:
		_rig = _sprites.leg_rig(build.paint_of("legs"))
	_locomotion = locomotion_of(build.legs)
	# Con otro equipo, el arma de pecho vuelve a estar guardada.
	_deployed = false
	_deploy = 0.0
	set_facing(p_facing)


## Como se mueven unas piernas: las que levitan, las de orugas o ruedas, y
## las demas andan (y saltan si pueden).
static func locomotion_of(legs: ItemDef) -> String:
	if legs.has_tag(ItemDef.TAG_HOVER):
		return "hover"
	if legs.has_tag(ItemDef.TAG_TRACKS) or legs.has_tag(ItemDef.TAG_WHEELS):
		return "roll"
	return "walk"


func set_facing(p_facing: int) -> void:
	facing = p_facing
	var size := DRAW_SCALE * (BOSS_SCALE if _sprites != null and _sprites.is_boss else 1.0)
	scale = Vector2(size * facing, size)
	queue_redraw()


func set_heat(ratio: float, p_shut_down: bool = false) -> void:
	heat_ratio = clampf(ratio, 0.0, 1.3)
	if p_shut_down != shut_down:
		create_tween().tween_property(self, "_slump", 1.0 if p_shut_down else 0.0, 0.35)
	shut_down = p_shut_down
	queue_redraw()


## Lo que el mech ensena de su estado: desgaste por la vida, fallos por la
## energia y los efectos de un critico (GDD 2.9).
func set_condition(
	p_health: float,
	p_energy: float,
	p_immobilized: bool = false,
	p_disabled: String = "",
	p_stunned: bool = false
) -> void:
	health_ratio = clampf(p_health, 0.0, 1.0)
	energy_ratio = clampf(p_energy, 0.0, 1.0)
	immobilized = p_immobilized
	disabled_slot = p_disabled
	stunned = p_stunned


## Fija la posicion de reposo (los efectos de golpe vuelven a ella).
func place(at: Vector2) -> void:
	_base_position = at
	position = at


## Anda (o rueda, o se desliza) hasta otra casilla. Si va hacia atras sigue
## mirando al rival: anda de espaldas y se echa un poco hacia atras.
func move_to(at: Vector2, seconds: float) -> Tween:
	var backwards := (at.x - position.x) * facing < 0.0
	_gait_dir = -1.0 if backwards else 1.0
	_base_position = at
	var tween := create_tween()
	tween.tween_property(self, "position", at, seconds).set_trans(Tween.TRANS_SINE)
	_walking = true
	var lean := -0.07 if backwards else 0.05
	if _locomotion == "hover":
		lean *= 2.0
	create_tween().tween_property(self, "_lean", lean, seconds * 0.3)
	tween.finished.connect(_stop_walking)
	return tween


func _stop_walking() -> void:
	_walking = false
	create_tween().tween_property(self, "_lean", 0.0, 0.2)


## Salto en arco hasta otra casilla: asi se mueve cuando pasa por encima del
## rival o va mas lejos de lo que anda, y asi atacan las espadas.
## Vuela con los propulsores: se agacha, despega, recoge las piernas en el
## aire y aterriza flexionando. Si va hacia atras, vuela de espaldas.
func jump_to(at: Vector2, seconds: float, height_scale: float = 1.0) -> Tween:
	var from := position
	_base_position = at
	var height := clampf(absf(at.x - from.x) * 0.3, 60.0, 190.0) * height_scale
	var backwards := (at.x - from.x) * facing < 0.0
	var tween := create_tween()
	tween.tween_property(self, "_crouch", 1.0, seconds * 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_launch.bind(backwards))
	tween.parallel().tween_property(self, "_crouch", 0.0, seconds * 0.1)
	tween.tween_method(_arc_step.bind(from, at, height), 0.0, 1.0, seconds * 0.7)
	tween.tween_callback(_land)
	tween.tween_property(self, "_crouch", 0.8, seconds * 0.06)
	tween.tween_property(self, "_crouch", 0.0, seconds * 0.12).set_trans(Tween.TRANS_SINE)
	return tween


func _launch(backwards: bool) -> void:
	_airborne = true
	_thrust = 1.0
	create_tween().tween_property(self, "_lean", -0.18 if backwards else 0.14, 0.15)
	footstep.emit(position)


func _land() -> void:
	_airborne = false
	create_tween().tween_property(self, "_thrust", 0.0, 0.12)
	create_tween().tween_property(self, "_lean", 0.0, 0.2)
	footstep.emit(position)


## Salto corto hacia atras con los propulsores (armas que retroceden). Las
## piernas que no saltan se deslizan hacia atras sin girarse.
func hop_back(at: Vector2, seconds: float) -> Tween:
	if _locomotion == "walk" and build.legs.jump > 0:
		return jump_to(at, seconds, 0.45)
	return knockback_to(at, seconds)


## Lo empujan o lo arrastran: resbala sin girarse, con las piernas
## clavadas y el cuerpo echado hacia el golpe, levantando polvo.
func knockback_to(at: Vector2, seconds: float) -> Tween:
	var pushed_back := (at.x - position.x) * facing < 0.0
	_base_position = at
	var tween := create_tween()
	tween.tween_property(self, "_brace", 1.0, seconds * 0.15)
	tween.parallel().tween_property(self, "_lean", -0.16 if pushed_back else 0.16, seconds * 0.15)
	tween.tween_callback(func() -> void: footstep.emit(position))
	tween.tween_property(self, "position", at, seconds * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_callback(func() -> void: footstep.emit(position))
	tween.tween_property(self, "_brace", 0.0, seconds * 0.25)
	tween.parallel().tween_property(self, "_lean", 0.0, seconds * 0.25)
	return tween


func _arc_step(progress: float, from: Vector2, to: Vector2, height: float) -> void:
	position = from.lerp(to, progress) + Vector2(0.0, -height * 4.0 * progress * (1.0 - progress))


## Teletransporte: se desvanece, cambia de sitio y reaparece.
func blink_to(at: Vector2, seconds: float) -> Tween:
	_base_position = at
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, seconds * 0.4)
	tween.tween_property(self, "position", at, 0.0)
	tween.tween_property(self, "modulate:a", 1.0, seconds * 0.4)
	return tween


## Embestida: arranca despacio y llega de golpe.
func dash_to(at: Vector2, seconds: float) -> Tween:
	_base_position = at
	_thrust = 1.0
	_lean = 0.2
	_crouch = 0.35
	var tween := create_tween()
	tween.tween_property(self, "position", at, seconds).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_IN
	)
	tween.tween_callback(_end_dash)
	return tween


func _end_dash() -> void:
	footstep.emit(position)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_thrust", 0.0, 0.15)
	tween.tween_property(self, "_lean", 0.0, 0.2)
	tween.tween_property(self, "_crouch", 0.0, 0.2)


## Pequeno avance hacia el rival y vuelta, al atacar.
func lunge(seconds: float) -> Tween:
	var tween := create_tween()
	var forward := _base_position + Vector2(18.0 * facing, 0.0)
	tween.tween_property(self, "position", forward, seconds * 0.4)
	tween.tween_property(self, "position", _base_position, seconds * 0.6)
	return tween


## El tajo de un arma cuerpo a cuerpo: la hoja se levanta sobre su hombro,
## cae de golpe y vuelve a su sitio. Con un arma que no es de cuerpo a
## cuerpo (o sin arte) no hace nada. Devuelve cuanto tarda en caer el golpe.
func swing(seconds: float, slot: String) -> float:
	var mounted := _mount_of(slot)
	if mounted.is_empty() or not (mounted["item"] as ItemDef).has_tag(ItemDef.TAG_MELEE):
		return 0.0
	_swing_slot = slot
	var tween := create_tween()
	tween.tween_property(self, "_swing", SWING_RAISE, seconds * 0.38).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "_swing", SWING_FALL, seconds * 0.14).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "_swing", 0.0, seconds * 0.48).set_trans(Tween.TRANS_SINE)
	return seconds * 0.52


## True si el arma de ese hueco pega cuerpo a cuerpo.
func is_melee(slot: String) -> bool:
	var mounted := _mount_of(slot)
	return not mounted.is_empty() and (mounted["item"] as ItemDef).has_tag(ItemDef.TAG_MELEE)


## Destello y sacudida al recibir un golpe.
func hit(seconds: float) -> Tween:
	var tween := create_tween()
	modulate = Color(2.2, 2.2, 2.2)
	tween.tween_property(self, "modulate", Color.WHITE, seconds)
	var shake := create_tween()
	for offset: float in [-7.0, 6.0, -4.0, 2.0, 0.0]:
		shake.tween_property(self, "position", _base_position + Vector2(offset, 0.0), seconds / 5.0)
	return tween


func _process(delta: float) -> void:
	_time += delta
	if _walking and _locomotion == "walk":
		var before := floorf(_gait / PI)
		_gait += delta * GAIT_SPEED * _gait_dir
		# Cada media zancada un pie toca el suelo.
		if floorf(_gait / PI) != before:
			footstep.emit(position)
	queue_redraw()


## True si este mech lleva el canon que se despliega del pecho. Mientras las
## armas superiores no tengan dibujo propio, el canon tambien las representa.
func has_cannon() -> bool:
	if _sprites == null or build == null or _sprites.is_boss:
		return false
	# Sin arte de armas, el canon de pecho hace de arma superior.
	if not MechSprites.has_weapon_art():
		return build.chest != null or not build.tops.is_empty()
	return build.chest != null


## Las armas montadas se dibujan en su hueco (con arte y sin ser jefe).
func _shows_weapons() -> bool:
	return _sprites != null and not _sprites.is_boss and MechSprites.has_weapon_art()


## Pieza que da el color al canon del pecho.
func _cannon_item() -> ItemDef:
	return build.chest if build.chest != null else build.tops[0]


## Color con el que se dibuja el arma de pecho: su pintura o su elemento.
func _chest_paint() -> int:
	return int(build.paints.get("chest", _cannon_item().element))


## Guarda el arma de pecho dentro del torso: se despliega cada vez que se usa
## (decision del usuario, 2026-11-20, OBS-025). Null si no estaba fuera.
func stow(seconds: float) -> Tween:
	if not _deployed or not has_cannon():
		return null
	_deployed = false
	var tween := create_tween()
	tween.tween_property(self, "_deploy", 0.0, seconds).set_trans(Tween.TRANS_SINE)
	return tween


## Saca el arma de dentro del torso. Devuelve null si ya estaba desplegada o
## no tiene.
func deploy(seconds: float) -> Tween:
	if _deployed or not has_cannon():
		return null
	_deployed = true
	var tween := create_tween()
	tween.tween_property(self, "_deploy", 1.0, seconds).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	return tween


## Retroceso del arma al disparar: la del hueco que dispara.
## Con varios proyectiles seguidos (`shots`, cada `gap` segundos) da un
## golpe corto por cada uno; `strength` es la fuerza del culatazo.
func fire(
	seconds: float, slot: String = "", shots: int = 1, gap: float = 0.0, strength: float = 1.0
) -> void:
	_fired_slot = slot
	var tween := create_tween()
	var kick := RECOIL * strength
	if shots > 1 and gap > 0.0:
		for i in shots:
			tween.tween_property(self, "_recoil", kick * 0.6, gap * 0.3)
			tween.tween_property(self, "_recoil", kick * 0.12, gap * 0.7)
		tween.tween_property(self, "_recoil", 0.0, seconds * 0.4).set_trans(Tween.TRANS_SINE)
		return
	tween.tween_property(self, "_recoil", kick, seconds * 0.15)
	tween.tween_property(self, "_recoil", 0.0, seconds * 0.85).set_trans(Tween.TRANS_SINE)


## Punto del que sale el disparo, en las coordenadas del padre: la boca del
## canon, o el dron si dispara el.
func muzzle_point(from_drone: bool, slot: String = "") -> Vector2:
	var local := Vector2(-70.0, -206.0 + SPRITE_WEAPON_LIFT)
	if from_drone and _assist_kind() != "":
		var gun := "gun_low" if slot == "drone_low" else "gun_top"
		local = _assist_at() + MechSprites.assist_point(_assist_kind(), gun)
	elif from_drone and _drone_kind() != "":
		local = _sprites.piece_tip(MechSprites.WEAPON_SET, _drone_kind())
		var low_kind := _drone_kind(true)
		if slot == "drone_low" and low_kind != "":
			local = _sprites.piece_tip(MechSprites.WEAPON_SET, low_kind) + DRONE_LOW_OFFSET
	if not from_drone:
		local = Vector2(60.0, -110.0)
		var mounted := _mount_of(slot)
		if not mounted.is_empty():
			local = _sprites.piece_tip(MechSprites.WEAPON_SET, mounted["kind"]) + mounted["at"]
		elif has_cannon() and (slot == "chest" or not _shows_weapons()):
			local = _sprites.piece_tip(CHEST_SET, "chest")
	return position + Vector2(local.x * facing, local.y) * scale.y


## Punto del cuerpo donde impactan los disparos, en las coordenadas del padre.
func hit_point() -> Vector2:
	return position + Vector2(0.0, -120.0) * scale.y


## El mech cae destruido: se inclina, se hunde y se oscurece.
func destroy(seconds: float) -> Tween:
	_dead = true
	var tween := create_tween()
	(
		tween
		. tween_property(self, "rotation", -0.38 * facing, seconds)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	tween.parallel().tween_property(self, "position:y", _base_position.y + 26.0, seconds)
	tween.parallel().tween_property(self, "modulate", Color(0.35, 0.33, 0.36), seconds)
	return tween


func _draw_sprites(dim: float) -> void:
	var tint := _body_tint(dim)
	# Vivo: respira; andando: rebota; apagado: se desploma hacia delante.
	var breath := _breath()
	var lift := _draw_legs(_ghost_tint(tint, "legs"))
	var body := Vector2(_slump * 9.0, breath + lift + _slump * 13.0)
	# El cuerpo se inclina sobre la cintura.
	var hip := _sprites.hip_point() + Vector2(0.0, lift)
	draw_set_transform_matrix(LegRig._about(hip, _lean))
	# El canon de pecho: mientras sale va por detras del torso, para que
	# parezca que viene de dentro.
	var cannon_at := body + Vector2((1.0 - _deploy) * -RETRACT - _recoil, 0.0)
	var cannon_tint := Color(tint.r, tint.g, tint.b, clampf(_deploy * 1.5, 0.0, 1.0))
	if has_cannon() and _deploy > 0.0 and _deploy < 1.0 and _layer("chest"):
		_sprites.draw_piece(self, CHEST_SET, "chest", _chest_paint(), cannon_tint, cannon_at)
	# El brazo y el hombro del lado lejano van detras del torso.
	if _layer("far") or _layer("far_top"):
		_draw_weapons(tint, body, true)
	var torso := _sprites.piece_rect(_sprites.torso_set, "torso", body)
	if _layer("body"):
		var torso_tint := _ghost_tint(tint, "torso")
		_sprites.draw_piece(
			self, _sprites.torso_set, "torso", build.paint_of("torso"), torso_tint, body
		)
		MechWear.draw_marks(self, torso, health_ratio, _wear_salt())
	if has_cannon() and _deploy >= 1.0 and _layer("chest"):
		_sprites.draw_piece(self, CHEST_SET, "chest", _chest_paint(), tint, cannon_at)
	if _layer("near") or _layer("near_top"):
		_draw_weapons(tint, body, false)
	if _layer("body"):
		_draw_condition(torso)
	if not _layer("float"):
		draw_set_transform(Vector2.ZERO)
		return
	# El dron flota aparte, sin inclinarse con el cuerpo.
	var bob := Vector2(0.0, sin(_time * 3.1) * 4.0)
	if _assist_kind() != "":
		# El asistente lleva sus armas en el dibujo de su forma; se tine con
		# el color del torso para que haga juego con su mech.
		draw_set_transform(Vector2.ZERO)
		var kick := (
			Vector2(-_recoil * 0.4, 0.0) if _fired_slot.begins_with("drone") else Vector2.ZERO
		)
		MechSprites.draw_assist(
			self, _assist_kind(), build.paint_of("assist"), tint, _assist_at() + bob + kick
		)
		return
	var drone_kind := _drone_kind()
	if drone_kind != "":
		draw_set_transform(Vector2.ZERO)
		var low_kind := _drone_kind(true)
		if low_kind != "":
			var low_at := bob + DRONE_LOW_OFFSET + Vector2(0.0, sin(_time * 3.1 + 1.3) * 2.0)
			var low_element := build.drone_low.element
			_sprites.draw_piece(self, MechSprites.WEAPON_SET, low_kind, low_element, tint, low_at)
		var element := build.drone.element
		_sprites.draw_piece(self, MechSprites.WEAPON_SET, drone_kind, element, tint, bob)
		return
	draw_set_transform(bob + Vector2(0.0, SPRITE_WEAPON_LIFT))
	_draw_drone(dim)
	draw_set_transform(Vector2.ZERO)


## True si sus piernas son de una pieza (orugas, ruedas o levitar).
func has_rigid_legs() -> bool:
	return _rig == null


## Juego de sprites de su torso y de sus piernas ("" sin arte o si es un
## jefe, que lleva su cuerpo entero).
func torso_set() -> String:
	return "" if _sprites == null or _sprites.is_boss else _sprites.torso_set


func legs_set() -> String:
	return "" if _sprites == null or _sprites.is_boss else _sprites.legs_set


## Cuanto sube todo el dibujo en reposo por levitar (negativo = hacia arriba).
func rest_lift() -> float:
	return -HOVER_HEIGHT if _locomotion == "hover" else 0.0


## Lo que se mueve ahora mismo el dibujo respecto a su reposo, en sus
## unidades: x = las piernas (al flotar), y = el cuerpo (flotar y respirar).
func sway() -> Vector2:
	var floating := -sin(_time * 2.6) * 3.0 if _locomotion == "hover" else 0.0
	return Vector2(floating, floating + _breath())


## Vivo, respira: cuanto sube y baja el cuerpo.
func _breath() -> float:
	return 0.0 if (shut_down or _dead) else sin(_time * 2.2) * 1.6


## True si esta capa se dibuja (ver `only_layer`).
func _layer(layer: String) -> bool:
	return only_layer == "" or only_layer == layer


## Tinte de una pieza que falta (ghost_slots): gris azulado y transparente.
func _ghost_tint(tint: Color, slot: String) -> Color:
	return Color(0.55, 0.66, 0.82, 0.22) if slot in ghost_slots else tint


## Saca el canon de pecho sin animacion (el taller lo ensena montado).
func show_deployed() -> void:
	_deployed = true
	_deploy = 1.0
	queue_redraw()


## Rectangulo que ocupa la pieza de un hueco en reposo, respecto a los pies.
## Un hueco de arma vacio da el sitio donde iria. Vacio si no se dibuja.
func slot_rect(slot: String) -> Rect2:
	if _sprites == null or build == null:
		return Rect2()
	match slot:
		"torso":
			return _sprites.piece_rect(_sprites.torso_set, "torso")
		"legs":
			return _sprites.piece_rect(_sprites.legs_set, "legs")
		"chest":
			return _sprites.piece_rect(CHEST_SET, "chest") if has_cannon() else Rect2()
		"assist", "drone", "drone_low":
			var kind := _assist_kind()
			if kind == "":
				return Rect2()
			var at := _assist_at()
			var top := MechSprites.assist_top(kind)
			var height := top + MechSprites.assist_bottom(kind)
			return Rect2(at - Vector2(height * 0.6, top), Vector2(height * 1.2, height))
	if not (slot.begins_with("side") or slot.begins_with("top")):
		return Rect2()
	var index := int(slot.right(1))
	var mounted := _mount_of(slot)
	if not mounted.is_empty():
		return _sprites.piece_rect(MechSprites.WEAPON_SET, mounted["kind"], mounted["at"])
	# Vacio: el sitio de un arma de su tipo en ese hueco.
	var side := slot.begins_with("side")
	var mounts := SIDE_MOUNTS if side else TOP_MOUNTS
	var kind := "arm_medio_balas" if side else "shoulder_bateria_balas"
	var at := mounts[mini(index, mounts.size() - 1)]
	return _sprites.piece_rect(MechSprites.WEAPON_SET, kind, at)


## Humo, fuego, arcos y chispas del estado del mech, sobre su cuerpo.
func _draw_condition(torso: Rect2) -> void:
	if _dead:
		return
	MechWear.draw_smoke_and_fire(self, torso, health_ratio, _time, _wear_salt())
	# Sobrecargado por un critico: los mismos arcos que con poca energia.
	var sparking := 0.0 if stunned else energy_ratio
	MechWear.draw_low_energy(self, torso, sparking, _time, _wear_salt())
	if immobilized:
		MechWear.draw_stuck(self, _sprites.hip_point() * 0.45, _time, _wear_salt())


## Semilla del desgaste: el mismo mech tiene siempre las mismas marcas.
func _wear_salt() -> int:
	return absi(build.torso.id.hash()) % 100000 if build != null and build.torso != null else 0


## Forma dibujada del robot de asistencia; "" si no lleva o no hay arte.
func _assist_kind() -> String:
	if build.assist == null or _sprites == null or _sprites.is_boss:
		return ""
	return MechSprites.assist_kind(build.assist.tier)


func _assist_at() -> Vector2:
	var x := ASSIST_BACK + ASSIST_BACK_STEP * float(build.assist.tier)
	var y := _body_top() - ASSIST_CLEARANCE - MechSprites.assist_bottom(_assist_kind())
	return Vector2(x, y)


## Alto de lo que dibuja el mech en reposo, robot de asistencia incluido,
## en unidades del mundo: la camara lo usa para que quepa entero.
func standing_height() -> float:
	if _sprites == null:
		return 0.0
	var top := _body_top()
	var kind := _assist_kind()
	if kind != "":
		# El asistente sube y baja 4 unidades al flotar.
		top = minf(top, _assist_at().y - MechSprites.assist_top(kind) - 4.0)
	return -top * absf(scale.y)


## Alto del cuerpo (sin el asistente que flota encima), en unidades del mundo.
func body_height() -> float:
	return 0.0 if _sprites == null else -_body_top() * absf(scale.y)


## Lo mas alto del mech en reposo (torso y armas montadas), respecto a sus
## pies; las piernas que levitan lo suben.
func _body_top() -> float:
	var top := _sprites.piece_top(_sprites.torso_set, "torso")
	for slot in _weapon_slots():
		var mounted := _mount_of(slot)
		if not mounted.is_empty():
			var kind: String = mounted["kind"]
			top = minf(top, _sprites.piece_top(MechSprites.WEAPON_SET, kind, mounted["at"]))
	if _locomotion == "hover":
		top -= HOVER_HEIGHT + 3.0
	return top


## Con `low`, la del arma inferior del asistente.
func _drone_kind(low: bool = false) -> String:
	var item := build.drone_low if low else build.drone
	if item == null or not _shows_weapons():
		return ""
	return MechSprites.weapon_kind(item)


## Armas laterales y superiores en sus huecos: las del lado lejano (`far`)
## o las de delante.
func _draw_weapons(tint: Color, body: Vector2, far: bool) -> void:
	if not _shows_weapons():
		return
	var dim := FAR_WEAPON_DIM if far and only_layer == "" else 1.0
	var weapon_tint := Color(tint.r * dim, tint.g * dim, tint.b * dim, tint.a)
	for slot: String in _weapon_slots():
		var mounted := _mount_of(slot)
		if mounted.is_empty() or mounted["far"] != far:
			continue
		# Por capas, las de hombro van aparte de las de brazo.
		if only_layer != "" and slot.begins_with("top") != only_layer.ends_with("_top"):
			continue
		var kick := Vector2(-_recoil, 0.0) if slot == _fired_slot else Vector2.ZERO
		var at: Vector2 = body + mounted["at"] + kick
		var element := build.paint_of(slot)
		var shade := weapon_tint
		if slot == disabled_slot:
			# Inutilizada por un critico: apagada y echando humo.
			shade = Color(weapon_tint.r * 0.45, weapon_tint.g * 0.45, weapon_tint.b * 0.45, tint.a)
		if slot == _swing_slot and _swing != 0.0:
			# El tajo: la hoja gira sobre el eje de su hombro.
			var pivot := at + _sprites.hip_point() + WEAPON_SHOULDER
			draw_set_transform(pivot, _swing, Vector2.ONE)
			_sprites.draw_piece(
				self, MechSprites.WEAPON_SET, mounted["kind"], element, shade, at - pivot
			)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		_sprites.draw_piece(self, MechSprites.WEAPON_SET, mounted["kind"], element, shade, at)
		if slot == disabled_slot:
			var joint := _sprites.piece_tip(MechSprites.WEAPON_SET, mounted["kind"]) + at
			MechWear.draw_broken_weapon(self, joint.lerp(_sprites.hip_point() + at, 0.5), _time)


func _weapon_slots() -> Array[String]:
	var out: Array[String] = []
	for i in build.sides.size():
		out.append("side%d" % i)
	for i in build.tops.size():
		out.append("top%d" % i)
	return out


## Arma de un hueco con su arte: {"item", "kind", "at", "far"}; {} si no
## es un arma montada o no tiene arte.
func _mount_of(slot: String) -> Dictionary:
	if not _shows_weapons() or slot.length() < 4:
		return {}
	var index := int(slot.right(1))
	var item: ItemDef = null
	var at := Vector2.ZERO
	var far := false
	if slot.begins_with("side") and index < build.sides.size():
		item = build.sides[index]
		at = SIDE_MOUNTS[mini(index, SIDE_MOUNTS.size() - 1)]
		far = index >= FAR_SIDE_FROM
	elif slot.begins_with("top") and index < build.tops.size():
		item = build.tops[index]
		at = TOP_MOUNTS[mini(index, TOP_MOUNTS.size() - 1)]
		far = index >= FAR_TOP_FROM
	if item == null:
		return {}
	# El dibujo de su clase y su nivel (o el de siempre si no lo tiene).
	var kind := MechSprites.weapon_look(item)
	if kind == "":
		return {}
	return {"item": item, "kind": kind, "at": at, "far": far}


## Dibuja las dos piernas con su pose y los propulsores o el brillo de
## levitar. Devuelve cuanto sube o baja el cuerpo para que el pie de apoyo
## toque el suelo (o para flotar).
func _draw_legs(tint: Color) -> float:
	var texture := _sprites.legs_texture(build.paint_of("legs"))
	if _rig == null or texture == null:
		return _draw_rigid_legs(tint)
	var origin := _sprites.legs_origin()
	var unit := MechSprites.UNIT_SCALE
	var near := _leg_pose(0.0)
	var far := _leg_pose(PI)
	# El pie mas bajo se apoya en el suelo; al levitar, todo flota.
	var lowest := maxf(
		_rig.sole_point(origin, unit, near).y, _rig.sole_point(origin + FAR_LEG_OFFSET, unit, far).y
	)
	var lift := -lowest
	if _locomotion == "hover":
		lift -= HOVER_HEIGHT + sin(_time * 2.6) * 3.0
	elif _locomotion == "roll" and _walking:
		lift += sin(_time * 47.0) * 0.8
	var far_dim := FAR_LEG_DIM if only_layer == "" else 1.0
	var far_tint := Color(tint.r * far_dim, tint.g * far_dim, tint.b * far_dim, tint.a)
	var shift := Vector2(0.0, lift)
	if _layer("far_leg"):
		_draw_jets(origin + FAR_LEG_OFFSET + shift, unit, far, 0.7)
		_rig.draw(self, texture, origin + FAR_LEG_OFFSET + shift, unit, far, far_tint)
	if _layer("near_leg"):
		_draw_jets(origin + shift, unit, near, 1.0)
		_rig.draw(self, texture, origin + shift, unit, near, tint)
	return lift


## Piernas de una pieza (orugas, ruedas o levitar): sin zancada. Las que
## levitan flotan con su brillo debajo; las que ruedan vibran al moverse.
func _draw_rigid_legs(tint: Color) -> float:
	var lift := 0.0
	if _locomotion == "hover":
		lift = -HOVER_HEIGHT - sin(_time * 2.6) * 3.0
		var glow := HOVER_GLOW
		for i in 3 if _layer("body") else 0:
			glow.a = 0.24 - 0.06 * i
			_ellipse(Vector2(0.0, -2.0), Vector2(70.0 + 16.0 * i, 8.0 + 3.0 * i), glow)
	elif _locomotion == "roll" and _walking:
		lift = sin(_time * 47.0) * 0.9
	if _layer("body"):
		_sprites.draw_piece(
			self, _sprites.legs_set, "legs", build.paint_of("legs"), tint, Vector2(0.0, lift)
		)
	return lift


## Pose de una pierna (muslo, espinilla, pie) segun lo que este haciendo.
## `phase` separa las dos piernas media zancada.
func _leg_pose(phase: float) -> Vector3:
	var thigh := 0.0
	var shin := 0.0
	if _airborne:
		# En el aire recoge las piernas, una un poco mas que la otra.
		thigh = -0.42 - 0.12 * cos(phase)
		shin = 0.75
	elif _walking and _locomotion == "walk":
		var step := _gait + phase
		thigh = -0.34 * sin(step)
		# La rodilla se dobla cuando la pierna pasa por delante en el aire.
		shin = 0.6 * maxf(0.0, cos(step))
	elif _locomotion == "hover":
		# Colgando, con un vaiven suave.
		thigh = -0.1 + 0.07 * sin(_time * 1.9 + phase)
		shin = 0.22
	# Agacharse (despegue y aterrizaje) y clavarse ante un empujon.
	thigh += -0.45 * _crouch + 0.3 * _brace * (1.0 if phase == 0.0 else -0.6)
	shin += 0.9 * _crouch + 0.15 * _brace
	# El pie queda plano respecto al suelo.
	return Vector3(thigh, shin, -(thigh + shin) * 0.9)


## Llamas de los propulsores bajo un pie, o el brillo de levitar.
func _draw_jets(origin: Vector2, unit: float, pose: Vector3, strength: float) -> void:
	var sole := _rig.sole_point(origin, unit, pose)
	if _locomotion == "hover":
		var glow := HOVER_GLOW
		for i in 3:
			glow.a = (0.22 - 0.06 * i) * strength
			var radius := Vector2(30.0 + 10.0 * i, 6.0 + 2.0 * i)
			_ellipse(sole + Vector2(0.0, HOVER_HEIGHT * 0.6), radius, glow)
	if _thrust <= 0.01:
		return
	var flicker := 0.8 + 0.2 * sin(_time * 53.0 + strength * 7.0)
	var length := 46.0 * _thrust * flicker * strength
	var width := 10.0 * strength
	var edge := FLAME_EDGE
	edge.a = 0.85 * _thrust
	draw_colored_polygon(
		PackedVector2Array(
			[sole + Vector2(-width, -4.0), sole + Vector2(width, -4.0), sole + Vector2(0.0, length)]
		),
		edge
	)
	var core := FLAME_CORE
	core.a = _thrust
	draw_colored_polygon(
		PackedVector2Array(
			[
				sole + Vector2(-width * 0.45, -4.0),
				sole + Vector2(width * 0.45, -4.0),
				sole + Vector2(0.0, length * 0.55)
			]
		),
		core
	)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)


func _draw() -> void:
	if build == null:
		return
	var dim := 0.45 if shut_down else 1.0

	if _sprites != null:
		_draw_sprites(dim)
		return
	_draw_block_body(dim)

	# Armas laterales: dos delante y dos detras, apuntando al rival.
	var side_slots: Array[Vector2] = [
		Vector2(30, -116), Vector2(30, -90), Vector2(-4, -106), Vector2(-4, -80)
	]
	for i in mini(build.sides.size(), side_slots.size()):
		var weapon := build.sides[i]
		if weapon == null:
			continue
		var color := _color(weapon, dim)
		var origin := side_slots[i]
		if weapon.has_tag(ItemDef.TAG_SWORD):
			_box(Rect2(origin.x, origin.y, 64, 7), color.lightened(0.25))
			_box(Rect2(origin.x - 6, origin.y - 5, 14, 17), color.darkened(0.3))
		elif weapon.has_tag(ItemDef.TAG_MELEE):
			_box(Rect2(origin.x, origin.y + 2, 46, 9), color.darkened(0.2))
			_box(Rect2(origin.x + 40, origin.y - 8, 22, 28), color)
		else:
			var length := 28.0 + 4.0 * weapon.range_max
			_box(Rect2(origin.x, origin.y, length, 13), color)
			_box(Rect2(origin.x - 4, origin.y - 3, 22, 19), color.darkened(0.25))

	# Armas superiores sobre el torso.
	for i in mini(build.tops.size(), 2):
		if build.tops[i] == null:
			continue
		var color := _color(build.tops[i], dim)
		var y := -182.0 - 22.0 * i
		_box(Rect2(-30, y, 34, 20), color.darkened(0.25))
		_box(Rect2(0, y + 4, 60, 11), color)

	_draw_drone(dim)

	# El calor tine el torso de rojo.
	if heat_ratio > 0.02 and not shut_down:
		var glow := Color(1.0, 0.15, 0.05, minf(heat_ratio, 1.0) * 0.55)
		draw_rect(Rect2(-46, -158, 92, 98), glow)


func _draw_drone(dim: float) -> void:
	# Dron flotando detras.
	if build.drone != null:
		var color := _color(build.drone, dim)
		draw_circle(Vector2(-70, -206), 15, color)
		draw_arc(Vector2(-70, -206), 15, 0, TAU, 24, OUTLINE, 2.0)
		_box(Rect2(-62, -210, 20, 7), color.lightened(0.3))


## Bloques provisionales de piernas y torso, para cuando no hay arte.
func _draw_block_body(dim: float) -> void:
	# Piernas: dos patas, o ruedas si no saltan.
	var legs_color := _color(build.legs, dim)
	if build.legs.jump > 0:
		_box(Rect2(-34, -62, 22, 62), legs_color)
		_box(Rect2(10, -62, 22, 62), legs_color)
		_box(Rect2(-40, -8, 34, 8), legs_color.darkened(0.25))
		_box(Rect2(6, -8, 34, 8), legs_color.darkened(0.25))
	else:
		_box(Rect2(-46, -40, 92, 26), legs_color)
		for x: float in [-30.0, 0.0, 30.0]:
			draw_circle(Vector2(x, -14), 15, legs_color.darkened(0.3))
			draw_arc(Vector2(x, -14), 15, 0, TAU, 20, OUTLINE, 2.0)

	# Torso con sensor frontal.
	var torso_color := _color(build.torso, dim)
	_box(Rect2(-46, -158, 92, 98), torso_color)
	_box(Rect2(-36, -148, 72, 26), torso_color.lightened(0.18))
	_box(Rect2(20, -142, 20, 10), Color("fff3a0") if not shut_down else Color("3a3a3a"))


## Tinte del arte: se oscurece apagado y enrojece con el calor.
func _body_tint(dim: float) -> Color:
	if build != null and not shut_down:
		dim *= MechWear.energy_flicker(energy_ratio, _time, _wear_salt())
	var tint := Color(dim, dim, dim)
	if not shut_down:
		# Solo se nota a partir de media barra de calor.
		var hot := clampf((heat_ratio - 0.5) / 0.5, 0.0, 1.0)
		tint = tint.lerp(Color(1.0, 0.42, 0.3), hot * 0.55)
	return tint


func _color(item: ItemDef, dim: float) -> Color:
	var color := ELEMENT_COLORS[item.element]
	return Color(color.r * dim, color.g * dim, color.b * dim)


func _box(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	draw_rect(rect, OUTLINE, false, 2.0)
