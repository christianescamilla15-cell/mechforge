class_name SkillSet
extends Resource
## Lo que dan las habilidades aprendidas del arbol (SkillTree), ya sumado: las
## mejoras pasivas, las del arma de pecho y las habilidades que se activan en
## combate (escudo, reparacion y materia oscura).

## Efectos que se cuentan en enteros (usos y marcas); los demas son fracciones.
const WHOLE: Array[String] = [
	"chest_uses", "shield_uses", "repair_uses", "dark_matter_uses", "point_blank"
]

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
## A quemarropa (lo da el tipo Tirador, StyleLibrary): con 1 o mas, sus armas
## de brazo no tienen alcance minimo y disparan tambien con el rival pegado.
@export var point_blank: int = 0
## Habilidades de combate: cuantas veces por combate se pueden usar.
@export var shield_uses: int = 0
@export var repair_uses: int = 0
## Parte de la vida maxima que devuelve cada reparacion.
@export var repair_share: float = 0.0
@export var dark_matter_uses: int = 0
## Parte de la vida maxima del rival que quita la materia oscura.
@export var dark_matter_share: float = 0.0


## Suma un grupo de efectos ({campo: cuanto}): lo que da un tipo de robot
## (StyleLibrary) o lo que lleva un rival de la campana (Campaign.KITS). Los
## de WHOLE se cuentan en enteros; lo que no sea un campo se ignora.
func add(effects: Dictionary) -> void:
	for effect: String in effects:
		if not effect in self:
			continue
		if effect in WHOLE:
			set(effect, int(get(effect)) + int(effects[effect]))
		else:
			set(effect, float(get(effect)) + float(effects[effect]))


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
