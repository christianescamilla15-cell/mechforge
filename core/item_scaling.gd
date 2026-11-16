class_name ItemScaling
extends RefCounted
## Escala las estadisticas de una pieza segun su tier y nivel (GDD 8).
## El catalogo guarda los valores de Divino a nivel maximo; aqui se bajan en
## proporcion. Como todo escala con el mismo factor, un duelo entre mechs del
## mismo tier se comporta igual en cualquier tier.


## Poder relativo de un tier y nivel (Comun nivel 0 = 1.0).
static func power(rules: RulesConfig, tier: ItemDef.Tier, level: int) -> float:
	var max_level := rules.tier_max_level[tier]
	var clamped := clampi(level, 0, max_level)
	return rules.tier_mult[tier] * (1.0 + rules.level_bonus * clamped / max_level)


static func top_power(rules: RulesConfig) -> float:
	var top := ItemDef.Tier.DIVINE
	return power(rules, top, rules.tier_max_level[top])


## Fraccion de las estadisticas del catalogo que corresponde a ese tier y nivel.
static func factor(rules: RulesConfig, tier: ItemDef.Tier, level: int) -> float:
	return power(rules, tier, level) / top_power(rules)


static func is_reachable(def: ItemDef, tier: ItemDef.Tier) -> bool:
	return tier >= def.tier_min and tier <= def.tier_max


## Devuelve una copia de la pieza con las estadisticas de ese tier y nivel.
## No comprueba tier_min/tier_max: el simulador necesita poder bajar cualquier
## pieza a cualquier tier. Usa is_reachable para las reglas de progresion.
static func resolve(def: ItemDef, rules: RulesConfig, tier: ItemDef.Tier, level: int) -> ItemDef:
	var out: ItemDef = def.duplicate()
	var f := factor(rules, tier, level)
	for key in ItemDef.SCALED_STATS:
		var value: int = def.get(key)
		if value > 0:
			out.set(key, maxi(1, roundi(value * f)))
	out.tier = tier
	out.level = clampi(level, 0, rules.tier_max_level[tier])
	return out
