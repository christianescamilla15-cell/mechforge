class_name SkillSet
extends Resource
## Lo que dan las habilidades aprendidas del arbol (SkillTree), ya sumado: las
## mejoras pasivas, las del arma de pecho y las habilidades que se activan en
## combate (escudo, reparacion y materia oscura).

## Fracciones que se suman: dano de las armas, energia y regeneracion, calor y
## enfriamiento, resistencias y vida.
@export var damage: float = 0.0
@export var energy: float = 0.0
@export var heat: float = 0.0
@export var resistance: float = 0.0
@export var health: float = 0.0
## Dano de mas del arma de pecho (fraccion) y usos de mas.
@export var chest_damage: float = 0.0
@export var chest_uses: int = 0
## Habilidades de combate: cuantas veces por combate se pueden usar.
@export var shield_uses: int = 0
@export var repair_uses: int = 0
## Parte de la vida maxima que devuelve cada reparacion.
@export var repair_share: float = 0.0
@export var dark_matter_uses: int = 0
## Parte de la vida maxima del rival que quita la materia oscura.
@export var dark_matter_share: float = 0.0


## Aplica las mejoras pasivas a las estadisticas sumadas de un mech.
func apply(stats: Dictionary) -> void:
	stats["health"] = roundi(stats["health"] * (1.0 + health))
	for key: String in ["energy_cap", "energy_regen"]:
		stats[key] = roundi(stats[key] * (1.0 + energy))
	for key: String in ["heat_cap", "cooling"]:
		stats[key] = roundi(stats[key] * (1.0 + heat))
	for key: String in ["res_physical", "res_heat", "res_energy"]:
		stats[key] = roundi(stats[key] * (1.0 + resistance))


func damage_mult() -> float:
	return 1.0 + damage
