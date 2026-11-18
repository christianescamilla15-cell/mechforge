class_name ItemDef
extends Resource
## Definicion de una pieza con sus estadisticas ya resueltas (GDD 3).
## Un valor 0 significa "no aplica": sin alcance = llega a toda la arena,
## sin usos = ilimitado.

## CHEST: arma de pecho, aparte de las 6 laterales y superiores (decision del
## usuario, 2026-11-17).
enum Type { TORSO, LEGS, SIDE, TOP, DRONE, MODULE, CHARGE, TELEPORT, HOOK, CHEST, ASSIST }
enum Element { PHYSICAL, HEAT, ENERGY, COMBINED }
enum Tier { COMMON, RARE, EPIC, LEGENDARY, MYTHIC, DIVINE }

const TAG_MELEE := "melee"
const TAG_SWORD := "espada"
## Como se mueven unas piernas que no andan (la animacion, no las reglas).
const TAG_TRACKS := "orugas"
const TAG_WHEELS := "ruedas"
const TAG_HOVER := "levita"
const KNOWN_TAGS: Array[String] = [TAG_MELEE, TAG_SWORD, TAG_TRACKS, TAG_WHEELS, TAG_HOVER]

## Estadisticas que crecen con el tier y el nivel (GDD 8).
## Clave con la que se guarda el progreso del robot de asistencia: es uno
## solo aunque cambie de protocolo (cada protocolo es una pieza ASSIST).
const ASSIST_PROGRESS := "asistente"
const SCALED_STATS: Array[String] = [
	"health",
	"energy_cap",
	"energy_regen",
	"heat_cap",
	"cooling",
	"res_physical",
	"res_heat",
	"res_energy",
	"dmg_min",
	"dmg_max",
	"heat_dmg",
	"energy_dmg",
	"res_dmg",
	"heat_cap_dmg",
	"cooling_dmg",
	"energy_cap_dmg",
	"energy_regen_dmg",
	"backfire",
	"heat_cost",
	"energy_cost",
]
## Estadisticas que no cambian nunca.
const FIXED_STATS: Array[String] = [
	"weight",
	"walk",
	"jump",
	"range_min",
	"range_max",
	"push",
	"pull",
	"recoil",
	"advance",
	"retreat",
	"uses",
]

@export var id: String = ""
@export var display_name: String = ""
@export var type: Type = Type.SIDE
@export var element: Element = Element.PHYSICAL
@export var tags: PackedStringArray = []
## Tiers entre los que puede existir la pieza. Las estadisticas del catalogo
## son siempre las de Divino a nivel maximo; ItemScaling las baja al resto.
@export var tier_min: Tier = Tier.COMMON
@export var tier_max: Tier = Tier.DIVINE
## Tier y nivel a los que estan resueltas las estadisticas de esta instancia.
@export var tier: Tier = Tier.DIVINE
@export var level: int = 0
## Datos de arte: ruta del sprite y anclas de montaje (los define la fase F4).
@export var art: Dictionary = {}
## Tipo de arma (docs/CATALOGO_ARMAS.md): "balas", "canon", "blaster" o
## "laser"; vacio en lo que no es arma.
@export var weapon_type: String = ""
## Forma del arma: "hoja", "corto", "bateria"...; vacio en lo que no es arma.
@export var form: String = ""

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


## Clave de su clase y su nivel en PlayerProfile.parts: el robot de
## asistencia comparte la suya entre protocolos.
func progress_id() -> String:
	return ASSIST_PROGRESS if type == Type.ASSIST else id


func deals_damage() -> bool:
	return dmg_max > 0
