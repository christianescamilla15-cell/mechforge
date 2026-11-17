extends GutTest
## Bonificaciones que caen en la arena (GDD 2.8): una nave deja una ventaja
## al azar y quien la toma la tiene durante 3 turnos.


func _rules(props: Dictionary = {}) -> RulesConfig:
	var base := {"drops_enabled": true, "drop_first_turn": 1, "drop_every": 4}
	base.merge(props, true)
	return Fx.rules(base)


func _gun() -> ItemDef:
	return Fx.gun({"range_min": 1, "range_max": 9})


## Combate con los mechs en las casillas 2 y 8 y el primero al turno.
func _engine(r: RulesConfig, seed_value: int = 1) -> BattleEngine:
	return BattleEngine.new(r, Fx.build([_gun()]), Fx.build([_gun()]), seed_value, 0, 2)


func _events(engine: BattleEngine, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in engine.events:
		if entry["event"] == kind:
			out.append(entry)
	return out


func test_apagadas_por_defecto() -> void:
	var engine := BattleEngine.new(Fx.rules(), Fx.build([_gun()]), Fx.build([_gun()]), 1, 0, 2)
	for i in 12:
		engine.apply(BattleAction.cool())
	assert_true(engine.drop.is_empty())
	assert_eq(_events(engine, "drop_spawn").size(), 0)


func test_cae_en_una_casilla_libre_con_tipo_y_cantidad_validos() -> void:
	for seed_value in range(1, 21):
		var engine := _engine(_rules(), seed_value)
		assert_false(engine.drop.is_empty(), "semilla %d" % seed_value)
		var cell: int = engine.drop["cell"]
		assert_true(cell >= 0 and cell < engine.rules.arena_size)
		assert_ne(cell, engine.mechs[0].position)
		assert_ne(cell, engine.mechs[1].position)
		assert_true(engine.drop["kind"] in engine.rules.drop_kinds)
		assert_between(engine.drop["amount"], engine.rules.drop_min, engine.rules.drop_max)


func test_la_misma_semilla_da_la_misma_bonificacion() -> void:
	assert_eq(_engine(_rules(), 7).drop, _engine(_rules(), 7).drop)


func test_no_cae_antes_del_turno_indicado() -> void:
	var engine := _engine(_rules({"drop_first_turn": 3}))
	assert_true(engine.drop.is_empty(), "turno 1")
	engine.apply(BattleAction.cool())
	engine.apply(BattleAction.cool())
	assert_true(engine.drop.is_empty(), "turno 2")
	engine.apply(BattleAction.cool())
	engine.apply(BattleAction.cool())
	assert_false(engine.drop.is_empty(), "turno 3")


func test_quien_llega_a_la_casilla_la_toma_por_3_turnos() -> void:
	var engine := _engine(_rules())
	engine.drop = {"cell": 3, "kind": "firepower", "amount": 0.5}
	assert_eq(engine.apply(BattleAction.walk(3)), "")
	assert_true(engine.drop.is_empty(), "la bonificacion desaparece de la arena")
	var buffs := engine.mechs[0].buffs
	assert_eq(buffs.size(), 1)
	assert_eq(buffs[0]["kind"], "firepower")
	assert_eq(buffs[0]["turns"], 3)
	var taken := _events(engine, "drop_taken")
	assert_eq(taken.size(), 1)
	assert_eq(taken[0]["who"], 0)
	assert_eq(taken[0]["amount"], 0.5)


func test_la_potencia_de_disparo_sube_el_dano() -> void:
	var engine := _engine(_rules())
	engine.drop = {}
	var plain: int = engine.preview(BattleAction.weapon("side0"))["dmg_min"]
	engine.mechs[0].buffs.append({"kind": "firepower", "amount": 0.5, "turns": 3})
	assert_eq(engine.preview(BattleAction.weapon("side0"))["dmg_min"], roundi(plain * 1.5))


func test_la_armadura_reduce_el_dano_recibido() -> void:
	var engine := _engine(_rules())
	engine.drop = {}
	var plain: int = engine.preview(BattleAction.weapon("side0"))["dmg_min"]
	engine.mechs[1].buffs.append({"kind": "armor", "amount": 0.5, "turns": 3})
	assert_eq(engine.preview(BattleAction.weapon("side0"))["dmg_min"], roundi(plain * 0.5))
	var before := engine.mechs[1].health
	engine.apply(BattleAction.weapon("side0"))
	assert_eq(before - engine.mechs[1].health, roundi(plain * 0.5))


func test_la_ventaja_dura_3_turnos_propios() -> void:
	var engine := _engine(_rules({"drop_every": 99}))
	engine.drop = {"cell": 3, "kind": "armor", "amount": 0.3}
	engine.apply(BattleAction.walk(3))
	engine.apply(BattleAction.cool())
	# Fin del primer turno propio: le quedan 2.
	assert_eq(engine.mechs[0].buffs[0]["turns"], 2)
	for own_turn in 2:
		engine.apply(BattleAction.cool())
		engine.apply(BattleAction.cool())
		assert_eq(engine.turn, 0, "vuelve a tocarle")
		engine.apply(BattleAction.cool())
		engine.apply(BattleAction.cool())
	assert_eq(engine.mechs[0].buffs.size(), 0, "tras su tercer turno se acaba")
	assert_eq(_events(engine, "buff_end").size(), 1)


func test_si_lo_empujan_a_la_casilla_tambien_la_toma() -> void:
	var pusher := Fx.gun({"range_min": 1, "range_max": 9, "push": 1})
	var engine := BattleEngine.new(_rules(), Fx.build([pusher]), Fx.build([_gun()]), 1, 0, 2)
	engine.drop = {"cell": 9, "kind": "armor", "amount": 0.2}
	engine.apply(BattleAction.weapon("side0"))
	assert_eq(engine.mechs[1].position, 9)
	assert_eq(engine.mechs[1].buffs.size(), 1, "la toma el empujado")


func test_las_copias_de_la_ia_conservan_el_estado_y_no_hacen_caer_nada() -> void:
	var engine := _engine(_rules({"drop_first_turn": 2, "drop_every": 1}))
	engine.mechs[0].buffs.append({"kind": "armor", "amount": 0.3, "turns": 2})
	engine.drop = {"cell": 5, "kind": "firepower", "amount": 0.4}
	var copy := engine.clone()
	assert_eq(copy.drop, engine.drop)
	assert_eq(copy.mechs[0].buffs, engine.mechs[0].buffs)
	copy.mechs[0].buffs[0]["turns"] = 1
	assert_eq(engine.mechs[0].buffs[0]["turns"], 2, "la copia es independiente")
	copy.drop = {}
	copy.apply(BattleAction.cool())
	copy.apply(BattleAction.cool())
	assert_true(copy.drop.is_empty(), "en la copia de busqueda no cae otra")


func test_la_ia_va_a_por_una_bonificacion_cercana() -> void:
	var engine := _engine(_rules({"drop_every": 99}))
	engine.drop = {"cell": 3, "kind": "firepower", "amount": 0.5}
	var ai := BattleAI.new(BattleAI.Difficulty.NORMAL, 1)
	for step in 2:
		engine.apply(ai.choose_action(engine))
	assert_eq(_events(engine, "drop_taken").size(), 1, "la toma en su turno")
