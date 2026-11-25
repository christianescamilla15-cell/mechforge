extends GutTest
## Especializaciones del arbol de mejoras en combate (OBS-051, del usuario:
## "puntos de mejora, que ahora sera un arbol mas complejo y diferente"): cada
## bifurcacion da un efecto que cambia la pelea. Se mide cada uno con dano
## fijo (Fx.gun hace 100) y sin criticos ni bonificaciones.


func _skills(props: Dictionary) -> SkillSet:
	var out := SkillSet.new()
	for key: String in props:
		assert_true(key in out, "SkillSet no tiene %s" % key)
		out.set(key, props[key])
	return out


func _with(skills: Dictionary, sides: Array = [Fx.gun()], opts: Dictionary = {}) -> MechBuild:
	var build := Fx.build(sides, opts)
	build.skills = _skills(skills)
	return build


func _drone() -> ItemDef:
	var base := {"weight": 40, "dmg_min": 100, "dmg_max": 100, "energy_cost": 20, "heat_cost": 10}
	return Fx.item(ItemDef.Type.DRONE, base)


func _assisted(skills: Dictionary) -> MechBuild:
	var assist := Fx.item(ItemDef.Type.ASSIST, {"health": 75})
	return _with(skills, [Fx.gun()], {"assist": assist, "drone": _drone()})


func _armored(res: int) -> MechBuild:
	return Fx.build([], {"torso": Fx.torso({"res_physical": res})})


func _shoot(e: BattleEngine, slot: String = "side0") -> Dictionary:
	assert_eq(e.apply(BattleAction.weapon(slot)), "")
	for i in range(e.events.size() - 1, -1, -1):
		if e.events[i]["event"] == "weapon":
			return e.events[i]
	return {}


func test_perforacion_ignora_parte_de_la_resistencia() -> void:
	var plain := Fx.engine(Fx.build([Fx.gun()]), _armored(50), 1)
	assert_eq(_shoot(plain)["damage"], 50, "100 menos 50 de resistencia")
	var piercing := Fx.engine(_with({"pierce": 0.5}), _armored(50), 1)
	assert_eq(_shoot(piercing)["damage"], 75, "ignora la mitad: 100 menos 25")


func test_golpe_certero_suma_probabilidad_de_critico() -> void:
	var e := Fx.engine(_with({"crit": 0.06}), Fx.build(), 1)
	var gun: ItemDef = e.mechs[0].slots["side0"].def
	assert_almost_eq(e.crit_chance(gun, e.mechs[1], e.mechs[0]), 0.06, 0.0001)
	assert_almost_eq(e.crit_chance(gun, e.mechs[1]), 0.0, 0.0001, "sin quien dispara, nada")
	e.fixed_crit = 0.0
	assert_eq(_shoot(e)["damage"], 125, "el critico multiplica por 1,25")


func test_drenaje_quita_mas_energia() -> void:
	var gun := Fx.gun({"energy_dmg": 40})
	var e := Fx.engine(_with({"drain": 0.25}, [gun]), Fx.build(), 1)
	assert_eq(e.preview(BattleAction.weapon("side0"))["target_energy"], 150)
	_shoot(e)
	assert_eq(e.mechs[1].energy, 150, "40 mas un 25 %: 50")


func test_eficiencia_abarata_las_armas_y_no_las_piernas() -> void:
	var gun := Fx.gun({"energy_cost": 40})
	var legs := Fx.legs({"energy_cost": 40})
	var e := Fx.engine(_with({"efficiency": 0.15}, [gun], {"legs": legs}), Fx.build(), 1)
	var me := e.mechs[0]
	assert_eq(me.energy_cost(gun), 34)
	assert_eq(me.energy_cost(legs), 40)
	_shoot(e)
	assert_eq(me.energy, 200 - 34)


func test_ignicion_calienta_mas() -> void:
	var gun := Fx.gun({"heat_dmg": 40})
	var e := Fx.engine(_with({"ignition": 0.25}, [gun]), Fx.build(), 1)
	assert_eq(e.preview(BattleAction.weapon("side0"))["target_heat"], 50)
	_shoot(e)
	assert_eq(e.mechs[1].heat, 50)


func test_refrigeracion_enfria_mas_sin_subir_el_tope() -> void:
	var mech := BattleMech.new(_with({"cooling": 0.2}), Fx.rules(), 0)
	assert_eq(mech.cooling, 60, "50 mas un 20 %")
	assert_eq(mech.heat_cap, 200)


func test_reflejo_devuelve_parte_del_dano_de_lejos_y_de_cerca() -> void:
	var e := Fx.engine(Fx.build([Fx.gun()]), _with({"reflect": 0.1}, []), 1)
	var hit := _shoot(e)
	assert_eq(hit["reflected"], 10)
	assert_eq(e.mechs[0].health, 990, "a quien pego le llega el 10 %")


func test_contraataque_solo_de_cerca() -> void:
	var far := Fx.engine(Fx.build([Fx.gun()]), _with({"counter": 0.15}, []), 1)
	assert_false(_shoot(far).has("countered"), "a distancia 3 no contraataca")
	assert_eq(far.mechs[0].health, 1000)
	var near := Fx.engine(Fx.build([Fx.gun()]), _with({"counter": 0.15}, []), 0)
	assert_eq(_shoot(near)["countered"], 15)
	assert_eq(near.mechs[0].health, 985)


func test_absorcion_vuelve_energia_parte_del_dano() -> void:
	var e := Fx.engine(Fx.build([Fx.gun()]), _with({"absorb": 0.1}, []), 1)
	e.mechs[1].energy = 100
	assert_eq(_shoot(e)["absorbed"], 10)
	assert_eq(e.mechs[1].energy, 110)


func test_absorcion_no_pasa_del_tope() -> void:
	var e := Fx.engine(Fx.build([Fx.gun()]), _with({"absorb": 0.1}, []), 1)
	assert_false(_shoot(e).has("absorbed"), "con la energia llena no gana nada")
	assert_eq(e.mechs[1].energy, e.mechs[1].energy_cap)


func test_regeneracion_recupera_vida_cada_turno() -> void:
	var e := Fx.engine(_with({"regen": 0.02}), Fx.build(), 1)
	e.mechs[0].health = 500
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	assert_eq(e.mechs[0].health, 520, "el 2 % de 1000 al empezar su turno")
	assert_true(Fx.has_event(e, "repair"))


func test_bastion_para_el_primer_golpe_de_cada_turno() -> void:
	var e := Fx.engine(Fx.build([Fx.gun(), Fx.gun()]), _with({"bastion": 0.15}, []), 1)
	var first := _shoot(e, "side0")
	assert_eq(first["damage"], 85)
	assert_true(first.get("bastion", false))
	assert_eq(_shoot(e, "side1")["damage"], 100, "el segundo pega entero")
	Fx.pass_turn(e)
	assert_eq(_shoot(e, "side0")["damage"], 85, "en el turno siguiente vuelve")


func test_movilidad_suma_una_casilla_si_las_piernas_se_mueven() -> void:
	var moves := BattleMech.new(_with({"mobility": 1}), Fx.rules(), 0)
	assert_eq(moves.move_range(), 3, "salta 2, mas 1")
	var still := Fx.legs({"walk": 0, "jump": 0})
	var stays := BattleMech.new(_with({"mobility": 1}, [], {"legs": still}), Fx.rules(), 0)
	assert_eq(stays.move_range(), 0)


func test_doble_disparo_repite_el_arma_del_asistente() -> void:
	var e := Fx.engine(_assisted({"swarm": 1}), Fx.build(), 1)
	var before := e.mechs[1].health
	Fx.pass_turn(e)
	assert_eq(before - e.mechs[1].health, 200, "dispara dos veces")
	var close := Fx.engine(_assisted({"swarm": 1}), Fx.build(), 0)
	before = close.mechs[1].health
	Fx.pass_turn(close)
	assert_eq(before - close.mechs[1].health, 100, "con el rival pegado, una")


func test_escudo_del_dron_para_un_golpe_si_lleva_asistente() -> void:
	var e := Fx.engine(Fx.build([Fx.gun()]), _assisted({"drone_shield": 1}), 1)
	assert_eq(e.mechs[1].barrier, 1)
	var hit := _shoot(e)
	assert_eq(hit["damage"], 0)
	assert_true(hit.get("shielded", false))
	var alone := BattleMech.new(_with({"drone_shield": 1}), Fx.rules(), 0)
	assert_eq(alone.barrier, 0, "sin asistente no hay escudo")


func test_sin_especializaciones_nada_cambia() -> void:
	var e := Fx.engine(Fx.build([Fx.gun({"energy_dmg": 40, "heat_dmg": 40})]), Fx.build(), 0)
	var hit := _shoot(e)
	assert_eq(hit["damage"], 100)
	for key: String in ["bastion", "reflected", "countered", "absorbed"]:
		assert_false(hit.has(key), key)
	assert_eq(e.mechs[1].heat, 40)
	assert_eq(e.mechs[1].energy, 160)
