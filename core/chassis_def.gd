class_name ChassisDef
extends Resource
## Chasis de un mech (docs/CHASIS.md): la base sobre la que se montan las
## piezas, con su caracter en combate. Un multiplicador vale 1.0 cuando el
## chasis no cambia esa estadistica.

## Multiplicadores que acepta data/chassis.json.
const MULTIPLIERS: Array[String] = [
	"health_mult",
	"resistance_mult",
	"heat_cap_mult",
	"cooling_mult",
	"energy_cost_mult",
	"damage_mult",
]
## Limites razonables de un multiplicador; fuera de ellos es un error de datos.
const MIN_MULT := 0.25
const MAX_MULT := 3.0

@export var id: String = ""
@export var display_name: String = ""
## Nivel del jugador a partir del cual se puede conseguir.
@export var unlock_level: int = 1
## Nivel al que esta resuelto (ver at_level).
@export var level: int = 0
@export var health_mult: float = 1.0
@export var resistance_mult: float = 1.0
@export var heat_cap_mult: float = 1.0
@export var cooling_mult: float = 1.0
## Cuanta energia gastan sus armas respecto a lo normal.
@export var energy_cost_mult: float = 1.0
## Potencia de disparo: multiplica el dano de sus armas antes de resistencias.
@export var damage_mult: float = 1.0


## Devuelve el chasis tal como rinde a ese nivel. Los multiplicadores de los
## datos son los del nivel maximo; en el nivel 0 solo se tiene una parte de
## la bonificacion (rules.chassis_start_share) y crece de forma lineal.
func at_level(p_level: int, rules: RulesConfig) -> ChassisDef:
	var out: ChassisDef = duplicate()
	out.level = clampi(p_level, 0, rules.chassis_max_level)
	var progress := float(out.level) / float(maxi(rules.chassis_max_level, 1))
	var share := rules.chassis_start_share + (1.0 - rules.chassis_start_share) * progress
	for key in MULTIPLIERS:
		out.set(key, 1.0 + (float(get(key)) - 1.0) * share)
	return out


## Aplica el chasis a las estadisticas sumadas de un mech (MechBuild.summary).
func apply(stats: Dictionary) -> void:
	stats["health"] = maxi(1, roundi(stats["health"] * health_mult))
	for key: String in ["res_physical", "res_heat", "res_energy"]:
		stats[key] = roundi(stats[key] * resistance_mult)
	stats["heat_cap"] = roundi(stats["heat_cap"] * heat_cap_mult)
	stats["cooling"] = roundi(stats["cooling"] * cooling_mult)


## Energia que gasta un arma montada en este chasis.
func energy_cost(def: ItemDef) -> int:
	return roundi(def.energy_cost * energy_cost_mult)
