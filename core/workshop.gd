class_name Workshop
extends RefCounted
## Taller de la armeria (GDD 8): cada pieza del mech sube de nivel por
## separado y, al llegar al maximo de su clase, se transforma a la clase
## siguiente y vuelve al nivel 0. Todo se paga con celdas.
## Datos en data/workshop.json: {"schema_version", "level_price",
## "transform_prices"}.
## Subir una pieza del nivel N al N+1 de una clase cuesta
##   level_price × multiplicador de la clase (RulesConfig.tier_mult)
##   × (niveles de la Basica / niveles de la clase) × (1 + N / niveles de la clase).
## Asi recorrer una clase entera cuesta lo mismo en victorias en cualquier
## zona (las zonas pagan segun su clase) y cada nivel cuesta un poco mas que
## el anterior.

## Precio base de un nivel en la clase Basica.
var level_price: int = 0
## Lo que cuesta transformar una pieza desde cada clase a la siguiente:
## Basica→Intermedia, Intermedia→Avanzada, etc. La clase Unica no se alcanza
## transformando: solo la sueltan los jefes.
var transform_prices: Array[int] = []
var errors: Array[String] = []


static func load_file(path: String) -> Workshop:
	var workshop := Workshop.new()
	if not FileAccess.file_exists(path):
		workshop.errors.append("no existe el archivo %s" % path)
		return workshop
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		workshop.errors.append("%s no es un diccionario" % path)
		return workshop
	workshop.level_price = int(parsed.get("level_price", 0))
	for value: Variant in parsed.get("transform_prices", []):
		workshop.transform_prices.append(int(value))
	if workshop.level_price <= 0:
		workshop.errors.append("'level_price' debe ser mayor que 0")
	# Una transformacion por cada clase que se alcanza transformando.
	if workshop.transform_prices.size() != ItemDef.Tier.DIVINE - 1:
		workshop.errors.append(
			"'transform_prices' debe tener %d precios" % (ItemDef.Tier.DIVINE - 1)
		)
	return workshop


## Celdas que cuesta subir una pieza de esa clase del nivel `level` al siguiente.
func level_cost(rules: RulesConfig, tier: int, level: int) -> int:
	var levels := float(rules.tier_max_level[tier])
	var span := float(rules.tier_max_level[ItemDef.Tier.COMMON]) / levels
	return roundi(level_price * rules.tier_mult[tier] * span * (1.0 + level / levels))


## Celdas que cuesta transformar una pieza de esa clase a la siguiente; 0 si
## no se puede.
func transform_cost(tier: int) -> int:
	return transform_prices[tier] if tier >= 0 and tier < transform_prices.size() else 0


## Celdas para llevar una pieza desde Basica nivel 0 hasta esa clase y nivel.
func total_cost(rules: RulesConfig, tier: int, level: int) -> int:
	var total := 0
	for t in tier + 1:
		var top: int = level if t == tier else rules.tier_max_level[t]
		for l in top:
			total += level_cost(rules, t, l)
		if t < tier:
			total += transform_cost(t)
	return total
