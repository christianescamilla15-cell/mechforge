class_name FieldUpgrades
extends RefCounted
## Mejoras de campo (OBS-057, del usuario: "mejoras que ocurren dentro del
## juego en la que solo puedas mejorar escudo o armas, pero de manera
## organica"). Son concretas y se ven: placas de blindaje, un escudo de mas,
## un arma afinada, un percutor, municion especial. En el Exterminio, entre un
## robot y otro de la oleada, el jugador elige una de tres para lo que queda
## de oleada; y los rivales de lo alto traen las suyas, anunciadas. Cada
## mejora es {"id", "slot"} ("slot": el hueco del arma, "" si es del robot).
## Los numeros, en data/field_upgrades.json.

const KINDS: Array[String] = ["plates", "shield", "tuned", "striker", "ammo"]

## Cuantas se ofrecen para elegir.
var choices: int = 3
## Por tipo: {"weight", "value", "on" ("body" o "weapon")}.
var kinds: Dictionary = {}
## Cuantas trae cada rival de la racha, por combate (desde 0).
var streak: Array[int] = []
## En el Exterminio: desde que oleada (desde 0) y una mas cada cuantas.
var wave_from: int = 0
var wave_every: int = 0
var errors: Array[String] = []


static func load_file(path: String) -> FieldUpgrades:
	var out := FieldUpgrades.new()
	if not FileAccess.file_exists(path):
		out.errors.append("no existe %s" % path)
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		out.errors.append("%s no es un objeto JSON" % path)
		return out
	out.choices = int(data.get("choices", 3))
	var raw: Dictionary = data.get("kinds", {})
	for kind: String in raw:
		if kind in KINDS:
			out.kinds[kind] = (raw[kind] as Dictionary).duplicate()
		else:
			out.errors.append("mejora de campo desconocida: %s" % kind)
	var rivals: Dictionary = data.get("rivals", {})
	for count: Variant in rivals.get("streak", []):
		out.streak.append(int(count))
	var waves: Dictionary = rivals.get("exterminio", {})
	out.wave_from = int(waves.get("from", 0))
	out.wave_every = int(waves.get("every", 0))
	return out


func value(kind: String) -> float:
	return float((kinds.get(kind, {}) as Dictionary).get("value", 0.0))


## Cuantas trae el rival del combate `step` de la racha.
func for_streak(step: int) -> int:
	if streak.is_empty() or step < 0:
		return 0
	return streak[mini(step, streak.size() - 1)]


## Cuantas trae cada rival de la oleada `wave` del Exterminio.
func for_wave(wave: int) -> int:
	if wave_every <= 0 or wave < wave_from:
		return 0
	return 1 + (wave - wave_from) / wave_every


## `count` mejoras al azar para ese robot (las de arma, sobre una de sus armas
## de brazo, hombro o pecho). Con `distinct`, de tipos distintos (las que se
## ofrecen para elegir).
func draw(
	build: MechBuild, count: int, rng: RandomNumberGenerator, distinct: bool = false
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weapons := weapon_slots(build)
	var bag: Array[String] = []
	for kind: String in kinds:
		var on_weapon := str(kinds[kind].get("on", "body")) == "weapon"
		if (
			float(kinds[kind].get("weight", 0.0)) > 0.0
			and (not on_weapon or not weapons.is_empty())
		):
			bag.append(kind)
	if bag.is_empty():
		return out
	for n in count:
		var total := 0.0
		for kind in bag:
			total += float(kinds[kind]["weight"])
		var roll := rng.randf() * total
		var pick := bag[-1]
		for kind in bag:
			roll -= float(kinds[kind]["weight"])
			if roll <= 0.0:
				pick = kind
				break
		var slot := ""
		if str(kinds[pick].get("on", "body")) == "weapon":
			slot = weapons[rng.randi_range(0, weapons.size() - 1)]
		out.append({"id": pick, "slot": slot})
		if distinct:
			bag.erase(pick)
			if bag.is_empty():
				break
	return out


## Los huecos de arma que puede mejorar: brazos, hombros y pecho con dano.
static func weapon_slots(build: MechBuild) -> Array[String]:
	var out: Array[String] = []
	for i in build.sides.size():
		if build.sides[i] != null and build.sides[i].deals_damage():
			out.append("side%d" % i)
	for i in build.tops.size():
		if build.tops[i] != null and build.tops[i].deals_damage():
			out.append("top%d" % i)
	if build.chest != null and build.chest.deals_damage():
		out.append("chest")
	return out


## Pone las mejoras en el robot (antes del combate). No toca nada que pueda
## compartir con otro robot: copia sus habilidades y sus listas de armas.
func apply(build: MechBuild, picks: Array) -> void:
	if picks.is_empty():
		return
	build.skills = build.skills.duplicate() if build.skills != null else SkillSet.new()
	build.sides = build.sides.duplicate()
	build.tops = build.tops.duplicate()
	for pick: Dictionary in picks:
		var kind := str(pick.get("id", ""))
		match kind:
			"plates":
				build.skills.health += value(kind)
			"shield":
				build.skills.shield_uses += roundi(value(kind))
			"tuned", "striker", "ammo":
				var def := _weapon(build, str(pick.get("slot", "")))
				if def == null:
					continue
				def = def.duplicate()
				def.proto_effects = def.proto_effects.duplicate()
				if kind == "tuned":
					def.dmg_min = roundi(def.dmg_min * (1.0 + value(kind)))
					def.dmg_max = roundi(def.dmg_max * (1.0 + value(kind)))
				else:
					var key := "crit" if kind == "striker" else "state_bonus"
					def.proto_effects[key] = float(def.proto_effects.get(key, 0.0)) + value(kind)
				_set_weapon(build, str(pick["slot"]), def)


## El arma de ese hueco ("side0", "top0", "chest"); null si no hay.
static func weapon_at(build: MechBuild, slot: String) -> ItemDef:
	return _weapon(build, slot)


static func _weapon(build: MechBuild, slot: String) -> ItemDef:
	if slot == "chest":
		return build.chest
	var index := int(slot.right(1))
	var list: Array[ItemDef] = build.sides if slot.begins_with("side") else build.tops
	return list[index] if slot != "" and index < list.size() else null


static func _set_weapon(build: MechBuild, slot: String, def: ItemDef) -> void:
	if slot == "chest":
		build.chest = def
	elif slot.begins_with("side"):
		build.sides[int(slot.right(1))] = def
	else:
		build.tops[int(slot.right(1))] = def
