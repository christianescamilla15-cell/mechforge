class_name ArenaUpgrades
extends Resource
## Mejoras permanentes compradas en la tienda de arena (GDD 8), ya resueltas a
## numeros: lo que le suman al mech del jugador en combate.

## Fraccion que se suma al dano de las armas (0.2 = +20 %).
@export var damage: float = 0.0
## Fraccion que se suma a la capacidad y a la regeneracion de energia.
@export var energy: float = 0.0
## Fraccion que se suma a la capacidad de calor y al enfriamiento.
@export var heat: float = 0.0
## Fraccion que se suma a las tres resistencias.
@export var resistance: float = 0.0
## Vida que se suma, en puntos.
@export var health: int = 0
## Fraccion que se quita al dano que las armas le hacen a quien las dispara.
@export var backfire: float = 0.0


## Aplica las mejoras a las estadisticas sumadas de un mech (MechBuild.summary).
func apply(stats: Dictionary) -> void:
	stats["health"] += health
	for key: String in ["energy_cap", "energy_regen"]:
		stats[key] = roundi(stats[key] * (1.0 + energy))
	for key: String in ["heat_cap", "cooling"]:
		stats[key] = roundi(stats[key] * (1.0 + heat))
	for key: String in ["res_physical", "res_heat", "res_energy"]:
		stats[key] = roundi(stats[key] * (1.0 + resistance))


func damage_mult() -> float:
	return 1.0 + damage


## Dano que un arma le hace a quien la dispara, con la amortiguacion comprada.
func backfire_of(def: ItemDef) -> int:
	return roundi(def.backfire * (1.0 - backfire))
