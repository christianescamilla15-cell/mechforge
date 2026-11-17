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
@export var health_mult: float = 1.0
@export var resistance_mult: float = 1.0
@export var heat_cap_mult: float = 1.0
@export var cooling_mult: float = 1.0
## Cuanta energia gastan sus armas respecto a lo normal.
@export var energy_cost_mult: float = 1.0
## Potencia de disparo: multiplica el dano de sus armas antes de resistencias.
@export var damage_mult: float = 1.0


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
