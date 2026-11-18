extends GutTest
## Impacto de los golpes (GDD 2.10): las armas de brazo solo hacen chispas,
## las de hombro empujan una casilla, las de pecho hasta tres (menos contra un
## blindaje de mas clase) y la materia oscura manda al rival hasta el borde
## de la arena con el critico de su arma de pecho.


func _rules(props: Dictionary = {}) -> RulesConfig:
	var base := {"impact_enabled": true}
	base.merge(props, true)
	return Fx.rules(base)


func _weapon(type: ItemDef.Type, props: Dictionary = {}) -> ItemDef:
	var base := {"weight": 40, "dmg_min": 100, "dmg_max": 100}
	base.merge(props, true)
	return Fx.item(type, base)


## El mech 0 en la casilla 3 con esa arma; el rival en la 6 (par 1).
func _engine(weapon: ItemDef, rules: RulesConfig = null, target: MechBuild = null) -> BattleEngine:
	var shooter := Fx.build([])
	match weapon.type:
		ItemDef.Type.SIDE:
			shooter.sides.assign([weapon])
		ItemDef.Type.TOP:
			shooter.tops.assign([weapon])
		ItemDef.Type.CHEST:
			shooter.chest = weapon
	var engine := Fx.engine(
		shooter, target if target else Fx.build(), 1, rules if rules else _rules()
	)
	engine.fixed_roll = 0.0
	return engine


func _fire(engine: BattleEngine, key: String) -> Dictionary:
	assert_eq(engine.apply(BattleAction.weapon(key)), "", "dispara %s" % key)
	for i in range(engine.events.size() - 1, -1, -1):
		if engine.events[i]["event"] == "weapon":
			return engine.events[i]
	return {}


func test_apagado_por_defecto() -> void:
	var engine := _engine(_weapon(ItemDef.Type.TOP), Fx.rules())
	_fire(engine, "top0")
	assert_eq(engine.mechs[1].position, 6)


func test_un_arma_de_brazo_solo_hace_chispas() -> void:
	var engine := _engine(_weapon(ItemDef.Type.SIDE))
	var entry := _fire(engine, "side0")
	assert_eq(engine.mechs[1].position, 6)
	assert_false(entry.has("knock"))


func test_un_arma_de_hombro_empuja_una_casilla() -> void:
	var engine := _engine(_weapon(ItemDef.Type.TOP))
	var entry := _fire(engine, "top0")
	assert_eq(engine.mechs[1].position, 7)
	assert_eq(entry["knock"], 1)


func test_el_ancla_jala_y_no_empuja() -> void:
	var engine := _engine(_weapon(ItemDef.Type.TOP, {"pull": 2}))
	_fire(engine, "top0")
	assert_eq(engine.mechs[1].position, 4, "la jala dos casillas, sin impacto que empuje")


func test_un_arma_de_pecho_empuja_hasta_tres() -> void:
	var engine := _engine(_weapon(ItemDef.Type.CHEST, {"uses": 2}))
	var entry := _fire(engine, "chest")
	assert_eq(engine.mechs[1].position, 9)
	assert_eq(entry["knock"], 3)


func test_contra_un_blindaje_de_mas_clase_empuja_menos() -> void:
	var chest := _weapon(ItemDef.Type.CHEST, {"uses": 2, "tier": ItemDef.Tier.COMMON})
	var engine := _engine(chest, null, Fx.build([], {"torso": Fx.torso()}))
	var entry := _fire(engine, "chest")
	assert_eq(entry["knock"], 1, "un pecho Basico contra un torso Divino: una casilla")


func test_el_empuje_propio_del_arma_manda_si_es_mayor() -> void:
	var engine := _engine(_weapon(ItemDef.Type.TOP, {"push": 2}))
	_fire(engine, "top0")
	assert_eq(engine.mechs[1].position, 8)


func test_no_se_sale_de_la_arena() -> void:
	var engine := _engine(_weapon(ItemDef.Type.CHEST, {"uses": 2}))
	engine.mechs[1].position = 8
	_fire(engine, "chest")
	assert_eq(engine.mechs[1].position, 9)


func test_un_escudo_que_para_el_golpe_para_el_impacto() -> void:
	var engine := _engine(_weapon(ItemDef.Type.TOP))
	engine.mechs[1].barrier = 1
	var entry := _fire(engine, "top0")
	assert_eq(engine.mechs[1].position, 6)
	assert_false(entry.has("knock"))


func test_la_materia_oscura_lo_manda_al_borde_con_su_critico() -> void:
	var chest := _weapon(ItemDef.Type.CHEST, {"uses": 3, "crit_effect": "immobilize"})
	var engine := _engine(chest, _rules({"crits_enabled": true}))
	var skills := SkillSet.new()
	skills.dark_matter_uses = 1
	skills.dark_matter_share = 0.6
	engine.mechs[0].build.skills = skills
	engine.mechs[0].kits["dark_matter"] = 1
	engine.mechs[0].chest_fired = true
	engine.mechs[1].position = 5
	assert_eq(engine.apply(BattleAction.dark_matter()), "")
	var entry: Dictionary = engine.events[-1]
	assert_eq(entry["event"], "dark_matter")
	assert_eq(engine.mechs[1].position, 9, "hasta el borde")
	assert_eq(entry["knock"], 4)
	assert_true(entry.get("crit", false))
	assert_true(engine.mechs[1].immobilized, "el critico de su arma de pecho")
