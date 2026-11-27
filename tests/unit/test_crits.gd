extends GutTest
## Golpes criticos (GDD 2.9): la probabilidad sale del arma y de su nivel, y
## la bajan la armadura gruesa y el escudo del rival; el critico pega mas
## y, segun el tipo de arma, atraviesa la resistencia, inmoviliza,
## le quita una accion o le inutiliza un arma durante su turno.
## Aqui el critico multiplica por 1.5 para que las cuentas se lean facil.


func _rules(props: Dictionary = {}) -> RulesConfig:
	# El multiplicador se fija aqui para que los tests no dependan del ajuste
	# de balance de RulesConfig.
	var base := {"crits_enabled": true, "crit_damage_mult": 1.5}
	base.merge(props, true)
	return Fx.rules(base)


## Arma de dano fijo 100 con esa probabilidad base y ese efecto.
func _gun(crit: int, effect: String = "pierce", props: Dictionary = {}) -> ItemDef:
	var base := {"crit": crit, "crit_effect": effect}
	base.merge(props, true)
	return Fx.gun(base)


func _target(torso: Dictionary = {}, shield_uses: int = 0, sides: Array = []) -> MechBuild:
	var build := Fx.build(sides, {"torso": Fx.torso(torso)})
	if shield_uses > 0:
		build.skills = SkillSet.new()
		build.skills.shield_uses = shield_uses
	return build


func _engine(gun: ItemDef, target: MechBuild, rules: RulesConfig = null) -> BattleEngine:
	var engine := Fx.engine(Fx.build([gun]), target, 0, rules if rules else _rules())
	engine.fixed_roll = 0.0
	return engine


func _chance(gun: ItemDef, target: MechBuild, rules: RulesConfig = null) -> float:
	var engine := _engine(gun, target, rules)
	return engine.crit_chance(gun, engine.mechs[1])


func _last(engine: BattleEngine, kind: String) -> Dictionary:
	for i in range(engine.events.size() - 1, -1, -1):
		if engine.events[i]["event"] == kind:
			return engine.events[i]
	return {}


func test_apagados_por_defecto() -> void:
	assert_eq(_chance(_gun(80), _target(), Fx.rules()), 0.0)


func test_el_pecho_es_casi_seguro_y_un_arma_media_no() -> void:
	assert_almost_eq(_chance(_gun(80), _target()), 0.8, 0.001)
	assert_almost_eq(_chance(_gun(10), _target()), 0.1, 0.001)


func test_la_armadura_gruesa_baja_la_probabilidad() -> void:
	# Resistencia 30 frente a 100 de dano: 0.8 x (1 - 2 x 0.3) = 0.32.
	assert_almost_eq(_chance(_gun(80), _target({"res_physical": 30})), 0.32, 0.001)


func test_el_escudo_de_alto_nivel_y_la_armadura_la_bajan_mucho() -> void:
	assert_almost_eq(_chance(_gun(80), _target({}, 2)), 0.4, 0.001)
	var both := _chance(_gun(80), _target({"res_physical": 30}, 2))
	assert_almost_eq(both, 0.16, 0.001, "pecho contra escudo doble y armadura gruesa")


func test_un_arma_de_mas_clase_acierta_mas_con_un_tope() -> void:
	var strong := _gun(40, "pierce", {"tier": ItemDef.Tier.DIVINE, "level": 50})
	var weak_armor := _target({"tier": ItemDef.Tier.COMMON})
	assert_almost_eq(_chance(strong, weak_armor), 0.6, 0.001, "x1.5 como mucho")
	assert_almost_eq(_chance(_gun(80, "pierce", {"level": 50}), weak_armor), 0.9, 0.001)


func test_un_escudo_activo_para_el_golpe_y_no_hay_critico() -> void:
	var engine := _engine(_gun(80), _target())
	engine.mechs[1].barrier = 1
	assert_eq(engine.crit_chance(engine.mechs[0].slots["side0"].def, engine.mechs[1]), 0.0)


func test_el_critico_pega_mas() -> void:
	var engine := _engine(_gun(50, "immobilize"), _target())
	engine.fixed_crit = 0.0
	engine.apply(BattleAction.weapon("side0"))
	var entry := _last(engine, "weapon")
	assert_eq(entry["damage"], 150)
	assert_true(entry.get("crit", false))


func test_sin_critico_si_la_tirada_falla() -> void:
	var engine := _engine(_gun(50, "immobilize"), _target())
	engine.fixed_crit = 0.99
	engine.apply(BattleAction.weapon("side0"))
	assert_eq(_last(engine, "weapon")["damage"], 100)
	assert_false(engine.mechs[1].immobilized)


func test_el_critico_de_balas_atraviesa_la_resistencia() -> void:
	var engine := _engine(_gun(50, "pierce"), _target({"res_physical": 20}))
	engine.fixed_crit = 0.0
	engine.apply(BattleAction.weapon("side0"))
	assert_eq(_last(engine, "weapon")["damage"], 150, "sin restar los 20 de resistencia")
	var other := _engine(_gun(50, "immobilize"), _target({"res_physical": 20}))
	other.fixed_crit = 0.0
	other.apply(BattleAction.weapon("side0"))
	assert_eq(_last(other, "weapon")["damage"], 130, "los demas criticos si la restan")


func test_el_critico_de_canon_inmoviliza_durante_su_turno() -> void:
	var engine := _engine(_gun(50, "immobilize"), _target())
	engine.fixed_crit = 0.0
	engine.apply(BattleAction.weapon("side0"))
	engine.apply(BattleAction.cool())
	assert_eq(engine.turn, 1, "turno del rival")
	assert_eq(engine.walkable_positions(), [] as Array[int], "no puede moverse")
	Fx.pass_turn(engine)
	Fx.pass_turn(engine)
	assert_eq(engine.turn, 1)
	assert_false(engine.mechs[1].immobilized, "al acabar su turno se le pasa")
	assert_gt(engine.walkable_positions().size(), 0)


func test_el_critico_de_laser_inutiliza_un_arma_durante_su_turno() -> void:
	var small := Fx.gun({"dmg_min": 50, "dmg_max": 50})
	var big := Fx.gun({"dmg_min": 200, "dmg_max": 200})
	var engine := _engine(_gun(50, "disable"), _target({}, 0, [small, big]))
	engine.fixed_crit = 0.0
	engine.apply(BattleAction.weapon("side0"))
	var hit: String = _last(engine, "weapon")["disabled"]
	assert_has(["side0", "side1"], hit, "una de sus armas")
	engine.apply(BattleAction.cool())
	assert_eq(engine.why_illegal(BattleAction.weapon(hit)), "arma inutilizada")
	var other := "side1" if hit == "side0" else "side0"
	assert_eq(engine.why_illegal(BattleAction.weapon(other)), "", "la otra si la puede usar")
	Fx.pass_turn(engine)
	Fx.pass_turn(engine)
	assert_eq(engine.why_illegal(BattleAction.weapon(hit)), "", "vuelve en su turno siguiente")


func test_el_critico_de_plasma_le_quita_una_accion() -> void:
	var engine := _engine(_gun(50, "stun"), _target())
	engine.fixed_crit = 0.0
	engine.apply(BattleAction.weapon("side0"))
	engine.apply(BattleAction.cool())
	assert_eq(engine.turn, 1)
	assert_eq(engine.actions_left, 1, "pierde una de sus dos acciones")
	assert_true(Fx.has_event(engine, "stunned"))
	Fx.pass_turn(engine)
	Fx.pass_turn(engine)
	assert_eq(engine.actions_left, 2, "solo dura un turno")


## M7 (OBS-055): quien acaba de perder una accion por sobrecarga no la
## vuelve a perder en su turno siguiente; al otro, si.
func test_no_hay_dos_sobrecargas_seguidas() -> void:
	var engine := _engine(_gun(50, "stun"), _target())
	engine.fixed_crit = 0.0
	engine.apply(BattleAction.weapon("side0"))
	engine.apply(BattleAction.cool())
	assert_eq(engine.actions_left, 1, "la primera le quita una accion")
	Fx.pass_turn(engine)
	engine.apply(BattleAction.weapon("side0"))
	var last: Dictionary = engine.events[-1]
	assert_true(bool(last.get("stun_resisted", false)), "la segunda no entra")
	engine.apply(BattleAction.cool())
	assert_eq(engine.actions_left, 2)
	Fx.pass_turn(engine)
	engine.apply(BattleAction.weapon("side0"))
	engine.apply(BattleAction.cool())
	assert_eq(engine.actions_left, 1, "la tercera, con un turno libre entre medias, si")


func test_sin_m7_se_encadenan() -> void:
	var engine := _engine(_gun(50, "stun"), _target())
	engine.rules.m7_no_chain_stun = false
	engine.fixed_crit = 0.0
	for turn in 2:
		engine.apply(BattleAction.weapon("side0"))
		engine.apply(BattleAction.cool())
		assert_eq(engine.actions_left, 1, "turno %d" % turn)
		Fx.pass_turn(engine)
	engine.rules.m7_no_chain_stun = true


func test_la_sobrecarga_le_deja_al_menos_una_accion() -> void:
	var engine := _engine(_gun(50, "stun"), _target({"heat_cap": 10, "cooling": 100}))
	engine.fixed_crit = 0.0
	engine.mechs[1].heat = 50
	engine.apply(BattleAction.weapon("side0"))
	engine.apply(BattleAction.cool())
	assert_eq(engine.actions_left, 1, "con el enfriado forzado ya tenia una: no baja de una")


func test_el_critico_tambien_calienta_y_drena_mas() -> void:
	var gun := _gun(50, "immobilize", {"heat_dmg": 20, "energy_dmg": 40})
	var engine := _engine(gun, _target())
	engine.fixed_crit = 0.0
	engine.apply(BattleAction.weapon("side0"))
	assert_eq(engine.mechs[1].heat, 30)
	assert_eq(engine.mechs[1].energy, engine.mechs[1].energy_cap - 60)


func test_la_ia_cuenta_el_dano_esperado_sin_efectos() -> void:
	var engine := _engine(_gun(40, "immobilize"), _target())
	var search := engine.clone()
	search.apply(BattleAction.weapon("side0"))
	# Dano 100 (tirada media) con un 40 % de critico: 100 x 1.2.
	assert_eq(search.mechs[1].health, search.mechs[1].max_health - 120)
	assert_false(search.mechs[1].immobilized)


func test_la_prevision_ensena_la_probabilidad_y_el_efecto() -> void:
	var engine := _engine(_gun(30, "disable"), _target())
	var preview := engine.preview(BattleAction.weapon("side0"))
	assert_almost_eq(preview["crit_chance"], 0.3, 0.001)
	assert_eq(preview["crit_effect"], "disable")


func test_la_misma_semilla_da_los_mismos_criticos() -> void:
	var runs: Array = []
	for i in 2:
		var engine := Fx.engine(Fx.build([_gun(50)]), _target(), 0, _rules(), 9)
		for j in 6:
			engine.apply(BattleAction.weapon("side0"))
			Fx.pass_turn(engine)
		runs.append(engine.events.map(func(e: Dictionary) -> bool: return e.get("crit", false)))
	assert_eq(runs[0], runs[1])
	assert_true(runs[0].has(true), "con un 50 % sale algun critico")


func test_cada_arma_del_catalogo_tiene_su_critico() -> void:
	var catalog := Catalog.load_file("res://data/catalog.json")
	var effects := {"balas": "pierce", "canon": "immobilize", "blaster": "stun", "laser": "disable"}
	for type: ItemDef.Type in [
		ItemDef.Type.SIDE, ItemDef.Type.TOP, ItemDef.Type.CHEST, ItemDef.Type.DRONE
	]:
		for item in catalog.by_type(type):
			assert_eq(item.crit_effect, effects[item.weapon_type], item.id)
			assert_gt(item.crit, 0, item.id)
			if type == ItemDef.Type.CHEST:
				assert_true(item.crit >= 70, "%s: el pecho es casi seguro" % item.id)
	for legs in catalog.by_type(ItemDef.Type.LEGS):
		assert_eq(legs.crit, 0, "%s: las piernas no hacen criticos" % legs.id)
