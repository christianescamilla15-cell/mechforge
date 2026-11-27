extends GutTest
## Los estados (OBS-055, StateConfig): quemadura, corrosion y estatica.

const NUMBERS := {
	"burn": {"element": "HEAT", "turns": 2, "max": 3, "heat": 0.05},
	"corrosion": {"element": "PHYSICAL", "turns": 2, "max": 3, "damage": 0.06},
	"static": {"element": "ENERGY", "turns": 2, "max": 3},
	"modes": ["arena"],
}

var _states := StateConfig.from_dict(NUMBERS)


func _engine(element: ItemDef.Element) -> BattleEngine:
	var gun := Fx.gun({"element": element})
	var other := Fx.gun({"element": element})
	var e := Fx.engine(Fx.build([gun, other]), Fx.build([Fx.gun()]))
	e.fixed_roll = 0.0
	e.extra_rules.append(_states)
	return e


func test_los_datos_del_juego() -> void:
	var config := StateConfig.load_file("res://data/states.json")
	assert_eq(config.errors, [] as Array[String])
	assert_eq(config.kind_for(ItemDef.Element.HEAT), "burn")
	assert_eq(config.kind_for(ItemDef.Element.PHYSICAL), "corrosion")
	assert_eq(config.kind_for(ItemDef.Element.ENERGY), "static")
	assert_eq(config.kind_for(ItemDef.Element.COMBINED), "")
	for mode: String in ["campaign", "arena", "exterminio", "free"]:
		assert_true(config.enabled_for(mode), mode)


## La quemadura calienta al empezar su turno, una vez por carga, y enfriar
## la apaga.
func test_la_quemadura_calienta_y_se_apaga_al_enfriar() -> void:
	var e := _engine(ItemDef.Element.HEAT)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(StateConfig.stacks(e.mechs[1], "burn"), 1)
	e.apply(BattleAction.weapon("side1"))
	assert_eq(StateConfig.stacks(e.mechs[1], "burn"), 2, "se suman")
	var foe := e.mechs[1]
	assert_eq(foe.heat, roundi(foe.heat_cap * 0.05 * 2), "al empezar su turno")
	assert_true(Fx.has_event(e, "burn"))
	e.apply(BattleAction.cool())
	assert_false(foe.states.has("burn"), "enfriar la apaga")
	assert_true(Fx.has_event(e, "burn_out"))


func test_las_cargas_tienen_tope_y_duran_dos_turnos() -> void:
	var e := _engine(ItemDef.Element.PHYSICAL)
	var foe := e.mechs[1]
	foe.states["corrosion"] = {"stacks": 3, "turns": 1}
	e.apply(BattleAction.weapon("side0"))
	assert_eq(StateConfig.stacks(foe, "corrosion"), 3, "no pasa del tope")
	assert_eq(int(foe.states["corrosion"]["turns"]), 2, "vuelve a durar")
	e.apply(BattleAction.cool())
	assert_eq(int(foe.states["corrosion"]["turns"]), 1, "un turno suyo menos")
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	assert_false(foe.states.has("corrosion"), "a los dos turnos se va")


## La corrosion hace que el siguiente golpe quite mas.
func test_la_corrosion_sube_el_dano() -> void:
	var e := _engine(ItemDef.Element.PHYSICAL)
	var foe := e.mechs[1]
	e.apply(BattleAction.weapon("side0"))
	var first := foe.max_health - foe.health
	e.apply(BattleAction.weapon("side1"))
	var second := foe.max_health - foe.health - first
	assert_eq(first, 100)
	assert_eq(second, 106, "con una carga, un 6 % mas")


## La estatica llena se descarga y le quita una accion; con M7, no dos
## turnos seguidos.
func test_la_estatica_llena_le_quita_una_accion() -> void:
	var e := _engine(ItemDef.Element.ENERGY)
	e.apply(BattleAction.weapon("side0"))
	e.apply(BattleAction.weapon("side1"))
	assert_eq(StateConfig.stacks(e.mechs[1], "static"), 2)
	assert_eq(e.actions_left, 2, "aun no")
	Fx.pass_turn(e)
	e.apply(BattleAction.weapon("side0"))
	assert_true(bool(e.events[-1].get("discharge", false)))
	assert_false(e.mechs[1].states.has("static"), "se vacia")
	e.apply(BattleAction.cool())
	assert_eq(e.actions_left, 1, "pierde una accion")


## Solo las armas: ni el asistente, ni las piernas, ni las especiales.
func test_solo_las_armas_dejan_estados() -> void:
	var e := _engine(ItemDef.Element.HEAT)
	e.mechs[0].slots["legs"].def.element = ItemDef.Element.HEAT
	e.apply(BattleAction.stomp())
	assert_eq(e.mechs[1].states, {})


## La IA ve los estados: quemado o corroido se esta peor.
func test_la_ia_valora_los_estados() -> void:
	var ai := BattleAI.new(BattleAI.Difficulty.HARD)
	var plain := _engine(ItemDef.Element.HEAT)
	var burnt := _engine(ItemDef.Element.HEAT)
	burnt.mechs[0].states["burn"] = {"stacks": 2, "turns": 2}
	var corroded := _engine(ItemDef.Element.HEAT)
	corroded.mechs[0].states["corrosion"] = {"stacks": 2, "turns": 2}
	assert_lt(ai.evaluate(burnt, 0), ai.evaluate(plain, 0))
	assert_lt(ai.evaluate(corroded, 0), ai.evaluate(plain, 0))
