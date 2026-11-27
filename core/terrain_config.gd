class_name TerrainConfig
extends RefCounted
## El terreno de la arena (OBS-055, del usuario: mecanicas "donde tambien
## cuente la estrategia, pero donde se vea mas implicada"). Algunas casillas
## son especiales:
## - lava: al empezar su turno en ella, el robot se calienta (parte de su
##   tope de calor), antes de mirar si se pasa; empujar al rival a la lava
##   puede dejarle sin acciones;
## - cobertura: los golpes desde lejos (a min_distance casillas o mas) le
##   quitan menos; los de cerca, no;
## - reparacion: al empezar su turno en ella, recupera parte de su vida;
## - trampa: al pisarla (andando, saltando o empujado) le hace dano y le deja
##   sin moverse ese turno; se gasta.
## Se reparten por parejas en espejo (la casilla i y la del otro lado), asi
## que ningun lado empieza con ventaja, y nunca donde esta un robot. Los
## numeros viven en data/terrain.json; la logica de cada casilla, aqui, y el
## motor (BattleEngine) solo la llama.

const KINDS: Array[String] = ["lava", "cover", "repair", "trap"]

## Parejas de casillas especiales por combate.
var pairs: int = 0
## Por tipo: {"weight", y sus numeros: "heat", "cut", "min_distance",
## "heal", "damage"}.
var kinds: Dictionary = {}
## Los modos de juego que llevan terreno ("campaign", "arena", ...).
var modes: Array[String] = []
var errors: Array[String] = []


static func load_file(path: String) -> TerrainConfig:
	var config := TerrainConfig.new()
	if not FileAccess.file_exists(path):
		config.errors.append("no existe %s" % path)
		return config
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		config.errors.append("%s no es un objeto JSON" % path)
		return config
	return from_dict(data)


static func from_dict(data: Dictionary) -> TerrainConfig:
	var config := TerrainConfig.new()
	config.pairs = int(data.get("pairs", 0))
	var raw: Variant = data.get("kinds", {})
	if raw is Dictionary:
		for kind: String in raw:
			if not kind in KINDS:
				config.errors.append("tipo de casilla desconocido: %s" % kind)
				continue
			config.kinds[kind] = (raw[kind] as Dictionary).duplicate()
	for mode: Variant in data.get("modes", []):
		config.modes.append(str(mode))
	return config


func enabled_for(mode: String) -> bool:
	return pairs > 0 and not kinds.is_empty() and mode in modes


## Un numero de un tipo de casilla (0 si no esta).
func value(kind: String, key: String) -> float:
	return float((kinds.get(kind, {}) as Dictionary).get(key, 0.0))


## El terreno de un combate: un tipo por casilla ("" la normal). Sale de la
## semilla del combate, con su propio azar (no mueve el del combate).
## `taken`: las casillas donde empiezan los robots.
func layout(seed_value: int, size: int, taken: Array[int]) -> Array[String]:
	var out: Array[String] = []
	out.resize(size)
	out.fill("")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "terreno"])
	var free: Array[int] = []
	for i in size / 2:
		if not (i in taken or size - 1 - i in taken):
			free.append(i)
	var bag: Array[String] = []
	for kind in KINDS:
		if value(kind, "weight") > 0.0:
			bag.append(kind)
	for n in mini(pairs, free.size()):
		if bag.is_empty():
			break
		var i: int = free.pop_at(rng.randi_range(0, free.size() - 1))
		var kind := _draw(bag, rng)
		bag.erase(kind)
		out[i] = kind
		out[size - 1 - i] = kind
	return out


func _draw(bag: Array[String], rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for kind in bag:
		total += value(kind, "weight")
	var roll := rng.randf() * total
	for kind in bag:
		roll -= value(kind, "weight")
		if roll <= 0.0:
			return kind
	return bag[-1]


# --- Lo que hace cada casilla (lo llama BattleEngine) ------------------------


## Al empezar el turno de `me`: la lava le calienta y la reparacion le cura.
func on_turn_start(engine: BattleEngine, me: BattleMech) -> void:
	var who := engine.mechs.find(me)
	match engine.terrain_at(me.position):
		"lava":
			var heat := roundi(me.heat_cap * value("lava", "heat"))
			me.heat += heat
			engine.note("lava", {"who": who, "heat": heat})
		"repair":
			var healed := mini(
				roundi(me.max_health * value("repair", "heal")), me.max_health - me.health
			)
			if healed > 0:
				me.health += healed
				engine.note("terrain_repair", {"who": who, "amount": healed})


## Lo que deja pasar la cobertura de `target` de un golpe de `user`: 1 si no
## esta cubierto o si el golpe viene de cerca.
func cover_factor(engine: BattleEngine, user: BattleMech, target: BattleMech) -> float:
	if engine.terrain_at(target.position) != "cover":
		return 1.0
	if absi(user.position - target.position) < roundi(value("cover", "min_distance")):
		return 1.0
	return 1.0 - clampf(value("cover", "cut"), 0.0, 1.0)


## Las trampas que pisa alguien: dano, sin moverse ese turno, y se gastan.
func spring(engine: BattleEngine) -> void:
	for who in 2:
		var mech := engine.mechs[who]
		if mech.health <= 0 or engine.terrain_at(mech.position) != "trap":
			continue
		engine.terrain[mech.position] = ""
		var damage := roundi(mech.max_health * value("trap", "damage"))
		mech.hurt(damage)
		mech.immobilized = true
		var data := {"who": who, "cell": mech.position, "damage": damage}
		data["terrain"] = engine.terrain.duplicate()
		engine.note("trap", data)
