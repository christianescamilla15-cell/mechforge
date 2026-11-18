class_name Progression
extends RefCounted
## Nivel del jugador (docs/CATALOGO_ARMAS.md, tabla 1): sube con la experiencia
## de los combates y abre huecos del mech. Lo fijo el usuario: el robot de
## soporte (el dron) se abre en el nivel 3 y el arma de pecho en el 10.
## Datos en data/progression.json: {"schema_version", "xp": {resultado:
## puntos}, "levels": [experiencia total para cada nivel, desde el 1],
## "unlocks": {hueco: nivel}}.

## Experiencia que da cada resultado: "win", "loss" y "boss_win".
var xp_rewards: Dictionary = {}
## Experiencia total que hace falta para cada nivel; levels[0] es el nivel 1.
var levels: Array[int] = []
## Nivel en el que se abre cada hueco del mech (ids de Garage.SLOTS).
var unlocks: Dictionary = {}
var errors: Array[String] = []


static func load_file(path: String) -> Progression:
	var progression := Progression.new()
	if not FileAccess.file_exists(path):
		progression.errors.append("no existe el archivo %s" % path)
		return progression
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		progression.errors.append("%s no es un diccionario" % path)
		return progression
	if parsed.get("xp") is Dictionary:
		progression.xp_rewards = parsed["xp"]
	if parsed.get("unlocks") is Dictionary:
		progression.unlocks = parsed["unlocks"]
	for value: Variant in parsed.get("levels", []):
		progression.levels.append(int(value))
	if progression.levels.is_empty() or progression.levels[0] != 0:
		progression.errors.append("'levels' debe empezar en 0 (nivel 1)")
	for i in range(1, progression.levels.size()):
		if progression.levels[i] <= progression.levels[i - 1]:
			progression.errors.append("'levels' debe crecer: nivel %d" % (i + 1))
	for slot: String in progression.unlocks:
		if not slot in Garage.SLOTS:
			progression.errors.append("hueco desconocido en 'unlocks': %s" % slot)
	return progression


func max_level() -> int:
	return levels.size()


## Nivel que corresponde a esa experiencia total.
func level_for(xp: int) -> int:
	var level := 1
	for i in levels.size():
		if xp >= levels[i]:
			level = i + 1
	return level


## Experiencia total que pide el nivel siguiente; -1 si ya esta al maximo.
func next_level_xp(xp: int) -> int:
	var level := level_for(xp)
	return levels[level] if level < levels.size() else -1


func xp_for(kind: String) -> int:
	return int(xp_rewards.get(kind, 0))


## Nivel en el que se abre ese hueco (1 si esta abierto desde el principio).
## El robot de asistencia y su arma inferior se abren con el dron.
func unlock_level(slot: String) -> int:
	if slot in ["assist", "drone_low"]:
		slot = "drone"
	return int(unlocks.get(slot, 1))


func is_unlocked(slot: String, level: int) -> bool:
	return level >= unlock_level(slot)


## Quita del mech las piezas de los huecos que el jugador aun no tiene: con
## ellas montadas no pelean.
func apply_locks(build: MechBuild, level: int) -> void:
	if not is_unlocked("drone", level):
		build.assist = null
		build.drone = null
		build.drone_low = null
	if not is_unlocked("chest", level):
		build.chest = null
