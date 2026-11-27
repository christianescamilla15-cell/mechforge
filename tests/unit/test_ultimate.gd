extends GutTest
## El medidor de definitiva y la andanada (OBS-055, UltimateConfig).

var _ult := UltimateConfig.from_dict({"deal": 1.0, "take": 1.0, "modes": ["arena"]})


## Dos armas de 100 que alcanzan a todo y una de alcance 1 a 1.
func _engine() -> BattleEngine:
	var short := Fx.gun({"range_min": 1, "range_max": 1})
	var me := Fx.build([Fx.gun({"heat_cost": 30}), Fx.gun()], {"tops": [short]})
	var e := Fx.engine(me, Fx.build([Fx.gun()]), 2)
	e.fixed_roll = 0.0
	e.set_ultimate(_ult)
	return e


func test_los_datos_del_juego() -> void:
	var config := UltimateConfig.load_file("res://data/ultimate.json")
	assert_gt(config.deal, 0.0)
	assert_gt(config.take, 0.0)
	for mode: String in ["campaign", "arena", "exterminio", "free"]:
		assert_true(config.enabled_for(mode), mode)


## Se llena al dar dano y al recibirlo, por la parte de la barra.
func test_el_medidor_se_llena_al_dar_y_recibir() -> void:
	var e := _engine()
	e.apply(BattleAction.weapon("side0"))
	var share := 100.0 / e.mechs[1].max_health
	assert_almost_eq(e.mechs[0].ult, share, 0.0001, "quien pega")
	assert_almost_eq(e.mechs[1].ult, share, 0.0001, "quien recibe")


func test_sin_cargar_no_se_puede() -> void:
	var e := _engine()
	assert_string_contains(e.why_illegal(BattleAction.ultimate()), "no esta cargada")
	for action in e.legal_actions():
		assert_ne(action.type, BattleAction.Type.ULTIMATE)
	e.mechs[0].ult = 1.0
	assert_eq(e.why_illegal(BattleAction.ultimate()), "")


## La andanada: disparan a la vez las armas que alcanzan, sin calor ni
## energia, y vacia el medidor (que la propia andanada no vuelve a llenar).
func test_la_andanada() -> void:
	var e := _engine()
	var me := e.mechs[0]
	var foe := e.mechs[1]
	me.ult = 1.0
	assert_eq(UltimateConfig.salvo(me, foe), ["side0", "side1"] as Array[String], "sin la corta")
	e.apply(BattleAction.ultimate())
	assert_eq(foe.max_health - foe.health, 200)
	assert_eq(me.heat, 0, "no paga calor")
	assert_eq(me.ult, 0.0, "se vacia y no se rellena con la suya")
	assert_almost_eq(foe.ult, 200.0 / foe.max_health, 0.0001, "al rival si le llena")
	assert_true(Fx.has_event(e, "ultimate"))
	assert_eq(e.actions_left, 1, "cuesta una accion")


func test_sin_definitiva_en_el_combate() -> void:
	var e := Fx.engine(Fx.build([Fx.gun()]), Fx.build([Fx.gun()]))
	e.mechs[0].ult = 1.0
	assert_eq(e.why_illegal(BattleAction.ultimate()), "sin definitiva")
	assert_false(e.mechs[0].ult_enabled)


## Con el medidor lleno y dos armas, la IA la suelta en su turno (la
## andanada vuelve a disparar las que ya uso, asi que conviene despues).
func test_la_ia_la_usa() -> void:
	var e := _engine()
	e.mechs[0].ult = 1.0
	var ai := BattleAI.new(BattleAI.Difficulty.HARD)
	while e.turn == 0 and not e.is_over():
		e.apply(ai.choose_action(e))
	assert_true(Fx.has_event(e, "ultimate"))


## En el Exterminio el medidor pasa al robot siguiente de la oleada.
func test_el_medidor_pasa_al_robot_siguiente() -> void:
	var e := _engine()
	e.mechs[0].ult = 0.6
	var next := BattleMech.new(e.mechs[0].build, e.rules, 4)
	next.carry_from(e.mechs[0])
	assert_almost_eq(next.ult, 0.6, 0.0001)
