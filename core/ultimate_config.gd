class_name UltimateConfig
extends ArenaRule
## El medidor de definitiva (OBS-055, del usuario: mecanicas "donde tambien
## cuente la estrategia"; eligio un medidor que se llena al dar y recibir dano
## y se gasta en un golpe especial: decidir cuando gastarlo). Se llena al dar
## dano y al recibirlo (quien va perdiendo carga antes) y, lleno, se gasta en
## una accion: la andanada, todas las armas de brazo y hombro que alcanzan al
## rival disparan a la vez sin pagar calor ni energia. Cuenta el momento: con
## el rival corroido o sin escudo, fuera de su cobertura, a la distancia a la
## que alcanzan mas armas. Los numeros, en data/ultimate.json; el medidor de
## cada uno, en BattleMech.ult (de 0 a 1).

## Lo que llena quitar una barra entera al rival, y perder una propia.
var deal: float = 0.0
var take: float = 0.0
var modes: Array[String] = []


static func load_file(path: String) -> UltimateConfig:
	if not FileAccess.file_exists(path):
		return UltimateConfig.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(data if data is Dictionary else {})


static func from_dict(data: Dictionary) -> UltimateConfig:
	var config := UltimateConfig.new()
	config.deal = float(data.get("deal", 0.0))
	config.take = float(data.get("take", 0.0))
	for mode: Variant in data.get("modes", []):
		config.modes.append(str(mode))
	return config


func enabled_for(mode: String) -> bool:
	return deal + take > 0.0 and mode in modes


## "" si `me` puede soltar la definitiva; si no, por que.
func why_not(me: BattleMech) -> String:
	if me.ult >= 1.0:
		return ""
	return "la definitiva no esta cargada (%d %%)" % floori(me.ult * 100.0)


## Los huecos que dispararia la andanada ahora: los de brazo y hombro con
## usos, sin inutilizar y con el rival a su alcance.
static func salvo(me: BattleMech, foe: BattleMech) -> Array[String]:
	var out: Array[String] = []
	var distance := absi(me.position - foe.position)
	for key in me.weapon_keys():
		if not (key.begins_with("side") or key.begins_with("top")):
			continue
		var slot := me.slots[key]
		if slot.uses_left == 0 or me.disabled_slot == key or not slot.def.deals_damage():
			continue
		var def := slot.def
		if def.range_max > 0 and (distance < def.range_min or distance > def.range_max):
			continue
		out.append(key)
	return out


## La andanada: vacia el medidor y dispara cada arma que alcanza; el calor y
## la energia quedan como estaban.
func fire(engine: BattleEngine, me: BattleMech, foe: BattleMech) -> void:
	me.ult = 0.0
	var keys := salvo(me, foe)
	engine.note("ultimate", {"who": engine.mechs.find(me), "slots": keys})
	var heat := me.heat
	var energy := me.energy
	me.firing_ult = true
	for key in keys:
		if foe.health <= 0:
			break
		engine.fire(me, foe, key, "weapon")
	me.firing_ult = false
	me.heat = heat
	me.energy = energy


# --- Como ArenaRule ------------------------------------------------------------


## Cada golpe llena el medidor de los dos: al que pega por lo que quita (no
## en su propia andanada) y al que lo recibe por lo que pierde.
func on_hit(
	_engine: BattleEngine,
	user: BattleMech,
	target: BattleMech,
	_key: String,
	damage: int,
	_data: Dictionary
) -> void:
	var share := float(damage) / float(maxi(target.max_health, 1))
	if not user.firing_ult:
		user.ult = minf(1.0, user.ult + deal * share)
	target.ult = minf(1.0, target.ult + take * share)
