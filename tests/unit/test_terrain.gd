extends GutTest
## El terreno de la arena (OBS-055, TerrainConfig): lava, cobertura,
## reparacion y trampas, repartidos en espejo.

const NUMBERS := {
	"pairs": 2,
	"kinds":
	{
		"lava": {"weight": 1, "heat": 0.25},
		"cover": {"weight": 1, "cut": 0.3, "min_distance": 2},
		"repair": {"weight": 1, "heal": 0.06},
		"trap": {"weight": 1, "damage": 0.1},
	},
	"modes": ["arena"],
}

var _config := TerrainConfig.from_dict(NUMBERS)


## Un combate de prueba con terreno puesto a mano: {casilla: tipo}.
func _engine(a: MechBuild, b: MechBuild, cells: Dictionary, pair: int = 0) -> BattleEngine:
	var e := Fx.engine(a, b, pair)
	e.fixed_roll = 0.0
	e.terrain_config = _config
	e.extra_rules.append(_config)
	e.terrain.resize(e.rules.arena_size)
	e.terrain.fill("")
	for cell: int in cells:
		e.terrain[cell] = cells[cell]
	return e


func test_los_datos_del_juego() -> void:
	var config := TerrainConfig.load_file("res://data/terrain.json")
	assert_eq(config.errors, [] as Array[String])
	assert_gt(config.pairs, 0)
	for kind in TerrainConfig.KINDS:
		assert_gt(config.value(kind, "weight"), 0.0, kind)
	for mode: String in ["campaign", "arena", "exterminio", "free"]:
		assert_true(config.enabled_for(mode), mode)


## En espejo, sin tocar donde empiezan los robots, tipos distintos y siempre
## el mismo con la misma semilla.
func test_el_reparto_es_justo() -> void:
	for seed_value in 40:
		var cells := _config.layout(seed_value, 10, [4, 5])
		var special := 0
		var kinds := {}
		for i in 10:
			assert_eq(cells[i], cells[9 - i], "espejo, semilla %d" % seed_value)
			if cells[i] != "":
				special += 1
				kinds[cells[i]] = true
		assert_eq(special, 4)
		assert_eq(kinds.size(), 2, "dos tipos distintos")
		assert_eq([cells[4], cells[5]], ["", ""], "donde empiezan, nada")
	assert_eq(_config.layout(7, 10, [3, 6]), _config.layout(7, 10, [3, 6]))
	var no_terrain := TerrainConfig.from_dict({})
	assert_false(no_terrain.enabled_for("arena"))


func test_la_lava_calienta_al_empezar_el_turno() -> void:
	var e := _engine(Fx.build([Fx.gun()]), Fx.build([Fx.gun()]), {5: "lava"})
	Fx.pass_turn(e)
	assert_eq(e.mechs[1].heat, roundi(e.mechs[1].heat_cap * 0.25))
	assert_true(Fx.has_event(e, "lava"))


func test_la_reparacion_cura_al_empezar_el_turno() -> void:
	var e := _engine(Fx.build([Fx.gun()]), Fx.build([Fx.gun()]), {5: "repair"})
	e.mechs[1].health -= 500
	var before := e.mechs[1].health
	Fx.pass_turn(e)
	assert_eq(e.mechs[1].health, before + roundi(e.mechs[1].max_health * 0.06))


## La cobertura para los golpes de lejos, no los de cerca.
func test_la_cobertura_para_los_golpes_de_lejos() -> void:
	var far := _engine(Fx.build([Fx.gun()]), Fx.build(), {8: "cover"}, 2)
	far.apply(BattleAction.weapon("side0"))
	assert_eq(far.mechs[1].max_health - far.mechs[1].health, 70)
	assert_true(bool(far.events[-1].get("cover", false)))
	var near := _engine(Fx.build([Fx.gun()]), Fx.build(), {5: "cover"})
	near.apply(BattleAction.weapon("side0"))
	assert_eq(near.mechs[1].max_health - near.mechs[1].health, 100, "pegado, no cubre")


func test_la_trampa_hiere_inmoviliza_y_se_gasta() -> void:
	var e := _engine(Fx.build([Fx.gun()]), Fx.build(), {3: "trap"})
	e.apply(BattleAction.walk(3))
	var me := e.mechs[0]
	assert_eq(me.max_health - me.health, roundi(me.max_health * 0.1))
	assert_true(me.immobilized)
	assert_eq(e.terrain_at(3), "", "se gasta")
	assert_true(Fx.has_event(e, "trap"))


## Empujar al rival a una trampa tambien la hace saltar.
func test_empujado_a_la_trampa() -> void:
	var e := _engine(Fx.build([Fx.gun({"push": 1})]), Fx.build(), {6: "trap"})
	e.apply(BattleAction.weapon("side0"))
	var foe := e.mechs[1]
	assert_eq(foe.position, 6)
	assert_eq(foe.max_health - foe.health, 100 + roundi(foe.max_health * 0.1))
	assert_eq(e.terrain_at(6), "")


## La IA ve el terreno: estar en lava es peor y en reparacion mejor que en
## una casilla normal; sin terreno, nada cambia.
func test_la_ia_valora_la_casilla() -> void:
	var ai := BattleAI.new(BattleAI.Difficulty.HARD)
	var plain := _engine(Fx.build([Fx.gun()]), Fx.build([Fx.gun()]), {})
	var lava := _engine(Fx.build([Fx.gun()]), Fx.build([Fx.gun()]), {4: "lava"})
	var repair := _engine(Fx.build([Fx.gun()]), Fx.build([Fx.gun()]), {4: "repair"})
	assert_lt(ai.evaluate(lava, 0), ai.evaluate(plain, 0))
	assert_gt(ai.evaluate(repair, 0), ai.evaluate(plain, 0))
	var bare := Fx.engine(Fx.build([Fx.gun()]), Fx.build([Fx.gun()]))
	assert_eq(bare.terrain_at(4), "")
	assert_almost_eq(ai.evaluate(bare, 0), ai.evaluate(plain, 0), 0.000001)


func test_las_copias_llevan_el_terreno() -> void:
	var e := _engine(Fx.build([Fx.gun()]), Fx.build(), {3: "trap", 6: "trap"})
	var copy := e.clone()
	copy.apply(BattleAction.walk(3))
	assert_eq(e.terrain_at(3), "trap", "la copia no toca el original")
	assert_eq(copy.terrain_at(3), "")
