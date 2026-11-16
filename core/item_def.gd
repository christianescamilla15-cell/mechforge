class_name ItemDef
extends Resource
## Definicion de una pieza con sus estadisticas ya resueltas (GDD 3).
## Un valor 0 significa "no aplica": sin alcance = llega a toda la arena,
## sin usos = ilimitado.

enum Type { TORSO, LEGS, SIDE, TOP, DRONE, MODULE, CHARGE, TELEPORT, HOOK }
enum Element { PHYSICAL, HEAT, ENERGY, COMBINED }

const TAG_MELEE := "melee"
const TAG_SWORD := "espada"

@export var id: String = ""
@export var display_name: String = ""
@export var type: Type = Type.SIDE
@export var element: Element = Element.PHYSICAL
@export var tags: PackedStringArray = []

@export_group("Cuerpo")
@export var weight: int = 0
@export var health: int = 0
@export var energy_cap: int = 0
@export var energy_regen: int = 0
@export var heat_cap: int = 0
@export var cooling: int = 0
@export var res_physical: int = 0
@export var res_heat: int = 0
@export var res_energy: int = 0
@export var walk: int = 0
@export var jump: int = 0

@export_group("Ataque")
@export var dmg_min: int = 0
@export var dmg_max: int = 0
@export var heat_dmg: int = 0
@export var energy_dmg: int = 0
@export var res_dmg: int = 0
@export var heat_cap_dmg: int = 0
@export var cooling_dmg: int = 0
@export var energy_cap_dmg: int = 0
@export var energy_regen_dmg: int = 0
@export var range_min: int = 0
@export var range_max: int = 0

@export_group("Movimiento")
@export var push: int = 0
@export var pull: int = 0
@export var recoil: int = 0
@export var advance: int = 0
@export var retreat: int = 0

@export_group("Costos")
@export var uses: int = 0
@export var backfire: int = 0
@export var heat_cost: int = 0
@export var energy_cost: int = 0


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func deals_damage() -> bool:
	return dmg_max > 0
