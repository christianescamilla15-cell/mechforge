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
	# Resistencia de un solo elemento, sobre la de resistance_mult.
	"res_physical_mult",
	"res_heat_mult",
	"res_energy_mult",
]
## Habilidades de jefe que son si o no.
const ABILITY_FLAGS: Array[String] = ["free_energy", "evade", "no_overheat"]
## Habilidades de jefe que se cuentan (0 a 2).
const ABILITY_COUNTS: Array[String] = ["shield_hits", "extra_drone_shots"]
## Los grupos de armas de shield_chance.
const SHIELD_GROUPS: Array[String] = ["arms", "shoulder", "chest", "other"]
## Tope de la regeneracion por turno, como fraccion de la vida maxima.
const MAX_REGEN_SHARE := 0.25
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
@export var res_physical_mult: float = 1.0
@export var res_heat_mult: float = 1.0
@export var res_energy_mult: float = 1.0
## Acciones de mas por turno. Solo para jefes: es lo que los hace dificiles
## sin darles mas vida. No crece con el nivel.
@export var extra_actions: int = 0
## Habilidad especial de un jefe (GDD 9.1): su nombre y lo que hace, para la
## interfaz. Es una ventaja que el jugador no puede tener en esa zona.
@export var ability: String = ""
@export var ability_text: String = ""
## Lo que hace la habilidad en el motor. Ninguna crece con el nivel.
## Energia infinita: sus armas no gastan energia y no se le puede drenar.
@export var free_energy: bool = false
## Regeneracion: parte de su vida maxima que repara al empezar su turno.
@export var regen_share: float = 0.0
## Escudo: golpes que anula en cada turno del rival.
@export var shield_hits: int = 0
## Probabilidad de que ese escudo pare el golpe, segun el arma (OBS-041,
## del usuario: "con armas de alto nivel... deberia de ser casi imposible
## que lo bloquee debido a la potencia"): {"arms", "shoulder", "chest",
## "other"} de 0 a 1. Vacio: lo para siempre. Lo intenta una vez por turno,
## con el primer golpe, pare o no.
@export var shield_chance: Dictionary = {}
## Evasion: al recibir dano salta al extremo de la arena de su lado, una
## vez por turno del rival.
@export var evade: bool = false
## Nucleo termico: nunca se sobrecalienta.
@export var no_overheat: bool = false
## Enjambre: disparos de mas de su dron al final del turno, si el rival no
## esta pegado a el.
@export var extra_drone_shots: int = 0


## Los chasis de jefe son los que tienen habilidad especial o acciones de mas.
func is_boss() -> bool:
	return ability != "" or extra_actions > 0


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
		stats[key] = roundi(stats[key] * resistance_mult * float(get(key + "_mult")))
	stats["heat_cap"] = roundi(stats["heat_cap"] * heat_cap_mult)
	stats["cooling"] = roundi(stats["cooling"] * cooling_mult)


## Energia que gasta un arma montada en este chasis.
func energy_cost(def: ItemDef) -> int:
	if free_energy:
		return 0
	return roundi(def.energy_cost * energy_cost_mult)
