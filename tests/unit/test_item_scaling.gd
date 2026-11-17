extends GutTest
## GDD 8: escalado de estadisticas por tier y nivel.

const T := ItemDef.Tier


func test_poder_por_tier_y_nivel() -> void:
	var r := RulesConfig.new()
	assert_almost_eq(ItemScaling.power(r, T.COMMON, 0), 1.0, 0.0001)
	assert_almost_eq(ItemScaling.power(r, T.COMMON, 10), 1.3, 0.0001)
	assert_almost_eq(ItemScaling.power(r, T.RARE, 0), 1.35, 0.0001)
	assert_almost_eq(ItemScaling.power(r, T.DIVINE, r.tier_max_level[T.DIVINE]), 5.46, 0.0001)
	assert_almost_eq(ItemScaling.top_power(r), 5.46, 0.0001)


func test_el_nivel_se_recorta_al_maximo_del_tier() -> void:
	var r := RulesConfig.new()
	assert_almost_eq(ItemScaling.power(r, T.COMMON, 999), 1.3, 0.0001)
	assert_almost_eq(ItemScaling.power(r, T.COMMON, -5), 1.0, 0.0001)


func test_transformar_siempre_mejora_aunque_reinicie_el_nivel() -> void:
	var r := RulesConfig.new()
	for tier in range(T.COMMON, T.DIVINE):
		var maxed := ItemScaling.power(r, tier, r.tier_max_level[tier])
		var next := ItemScaling.power(r, tier + 1, 0)
		assert_gt(next, maxed, "tier %d a nivel 0 debe superar al anterior al maximo" % (tier + 1))


func test_divino_al_maximo_devuelve_los_valores_del_catalogo() -> void:
	var r := RulesConfig.new()
	var gun := Fx.gun({"dmg_min": 205, "dmg_max": 255, "energy_cost": 25, "weight": 48})
	var top := ItemScaling.resolve(gun, r, T.DIVINE, r.tier_max_level[T.DIVINE])
	assert_eq(top.dmg_min, 205)
	assert_eq(top.dmg_max, 255)
	assert_eq(top.energy_cost, 25)
	assert_eq(top.tier, T.DIVINE)
	assert_eq(top.level, r.tier_max_level[T.DIVINE])


func test_comun_nivel_cero_baja_en_proporcion() -> void:
	var r := RulesConfig.new()
	var torso := Fx.torso({"health": 1300, "energy_cap": 250, "cooling": 95, "res_physical": 20})
	var low := ItemScaling.resolve(torso, r, T.COMMON, 0)
	assert_eq(low.health, roundi(1300 / 5.46))
	assert_eq(low.energy_cap, roundi(250 / 5.46))
	assert_eq(low.cooling, roundi(95 / 5.46))
	assert_eq(low.res_physical, roundi(20 / 5.46))


func test_lo_que_no_escala_se_conserva() -> void:
	var r := RulesConfig.new()
	var gun := Fx.gun(
		{"weight": 48, "range_min": 2, "range_max": 4, "push": 1, "uses": 2, "retreat": 1}
	)
	var low := ItemScaling.resolve(gun, r, T.COMMON, 0)
	assert_eq(low.weight, 48)
	assert_eq(low.range_min, 2)
	assert_eq(low.range_max, 4)
	assert_eq(low.push, 1)
	assert_eq(low.uses, 2)
	assert_eq(low.retreat, 1)
	assert_eq(low.id, gun.id)
	assert_eq(low.element, gun.element)


func test_una_estadistica_que_existe_nunca_baja_de_uno() -> void:
	var r := RulesConfig.new()
	var gun := Fx.gun({"res_dmg": 2, "heat_cost": 1})
	var low := ItemScaling.resolve(gun, r, T.COMMON, 0)
	assert_eq(low.res_dmg, 1)
	assert_eq(low.heat_cost, 1)
	assert_eq(low.energy_cost, 0, "y una que no existe sigue en cero")


func test_resolver_no_modifica_la_pieza_original() -> void:
	var r := RulesConfig.new()
	var gun := Fx.gun()
	ItemScaling.resolve(gun, r, T.COMMON, 0)
	assert_eq(gun.dmg_min, 100)


func test_alcanzable_segun_los_tiers_de_la_pieza() -> void:
	var gun := Fx.gun({"tier_min": T.EPIC, "tier_max": T.MYTHIC})
	assert_false(ItemScaling.is_reachable(gun, T.RARE))
	assert_true(ItemScaling.is_reachable(gun, T.EPIC))
	assert_true(ItemScaling.is_reachable(gun, T.MYTHIC))
	assert_false(ItemScaling.is_reachable(gun, T.DIVINE))


## Topes pedidos por el usuario (GDD 8): cada 6 niveles es una etapa tecnologica.
func test_topes_de_nivel_por_clase() -> void:
	var r := RulesConfig.new()
	var expected: Array[int] = [6, 12, 18, 24, 30, 50]
	for tier in expected.size():
		assert_eq(r.tier_max_level[tier], expected[tier], "clase %d" % tier)
