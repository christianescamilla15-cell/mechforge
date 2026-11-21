extends GutTest
## Habilidades especiales de los jefes (GDD 9.1): cada una cambia una regla del
## combate y deja un punto debil. El mech 0 es el jugador y empieza el.


func _boss(props: Dictionary, sides: Array = [], opts: Dictionary = {}) -> MechBuild:
	var chassis := ChassisDef.new()
	chassis.ability = "prueba"
	for key: String in props:
		chassis.set(key, props[key])
	var build := Fx.build(sides, opts)
	build.chassis = chassis
	return build


func _drone(damage: int) -> ItemDef:
	return Fx.item(ItemDef.Type.DRONE, {"weight": 20, "dmg_min": damage, "dmg_max": damage})


func test_energia_infinita_no_gasta_ni_se_drena() -> void:
	var boss := _boss({"free_energy": true}, [Fx.gun({"energy_cost": 60})])
	var drainer := Fx.gun({"energy_dmg": 500, "dmg_min": 10, "dmg_max": 10})
	var e := Fx.engine(Fx.build([drainer]), boss)
	var before: int = e.mechs[1].energy
	assert_eq(e.preview(BattleAction.weapon("side0"))["target_energy"], before)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].energy, before, "no se le puede drenar")
	assert_eq(e.mechs[1].health, e.mechs[1].max_health - 10, "ni rotura de energia")
	Fx.pass_turn(e)
	assert_eq(e.turn, 1)
	var energy: int = e.mechs[1].energy
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].energy, energy, "sus armas no gastan energia")


func test_regeneracion_repara_al_empezar_su_turno_sin_pasar_del_maximo() -> void:
	var boss := _boss({"regen_share": 0.08})
	var e := Fx.engine(Fx.build([Fx.gun({"dmg_min": 300, "dmg_max": 300})]), boss)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 700)
	Fx.pass_turn(e)
	assert_eq(e.turn, 1)
	assert_eq(e.mechs[1].health, 780, "repara el 8 por ciento de 1000")
	assert_true(Fx.has_event(e, "repair"))
	e.mechs[1].health = 995
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	assert_eq(e.turn, 1)
	assert_eq(e.mechs[1].health, 1000, "no pasa de su vida maxima")


func test_el_escudo_anula_el_primer_golpe_de_cada_turno() -> void:
	var boss := _boss({"shield_hits": 1})
	var e := Fx.engine(Fx.build([Fx.gun(), Fx.gun()]), boss)
	assert_eq(e.preview(BattleAction.weapon("side0"))["dmg_max"], 0, "la prevision lo avisa")
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 1000, "el primer golpe no hace dano")
	assert_true(e.events[-1].get("shielded", false))
	assert_eq(e.preview(BattleAction.weapon("side1"))["dmg_min"], 100)
	e.apply(BattleAction.weapon("side1"))
	assert_eq(e.mechs[1].health, 900, "el segundo golpe si entra")
	Fx.pass_turn(e)
	assert_eq(e.turn, 0)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 900, "el escudo vuelve en el turno siguiente")


func test_el_escudo_no_para_el_segundo_disparo_del_dron() -> void:
	var boss := _boss({"shield_hits": 1})
	var e := Fx.engine(Fx.build([Fx.gun()], {"drone": _drone(30)}), boss)
	e.apply(BattleAction.weapon("side0"))
	Fx.pass_turn(e)
	assert_eq(e.mechs[1].health, 970, "el arma choca con el escudo y el dron entra")


## OBS-041, del usuario: "un escudo es como una capa de ozono... tu atacas,
## pero no quitas vida realmente, sino que atacas a ese mismo escudo". El manto
## de plasma es vida de mas que se gasta antes que la vida y, rota, no vuelve.
func test_el_manto_se_gasta_antes_que_la_vida() -> void:
	var boss := _boss({"shield_layer": 0.15})
	var e := Fx.engine(Fx.build([Fx.gun(), Fx.gun()]), boss)
	assert_eq(e.mechs[1].layer_max, 150, "el 15 % de su vida de 1000")
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].layer, 50, "el golpe de 100 se lo come el manto")
	assert_eq(e.mechs[1].health, 1000)
	assert_eq(e.events[-1]["layer"], 100)
	assert_false(e.events[-1].get("layer_broken", false))
	e.apply(BattleAction.weapon("side1"))
	assert_eq(e.mechs[1].layer, 0)
	assert_eq(e.mechs[1].health, 950, "lo que sobra pasa a la vida")
	assert_eq(e.events[-1]["layer"], 50)
	assert_true(e.events[-1]["layer_broken"], "y se rompe")
	Fx.pass_turn(e)
	assert_eq(e.turn, 0, "vuelve a ser tu turno")
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].layer, 0, "roto, no vuelve")
	assert_eq(e.mechs[1].health, 850)


func test_el_manto_cuenta_como_vida_para_la_ia_y_se_ve_en_el_estado() -> void:
	var boss := _boss({"shield_layer": 0.3})
	var e := Fx.engine(Fx.build([Fx.gun()]), boss)
	assert_eq(e.mechs[1].toughness(), 1300)
	assert_eq(e.mechs[1].max_toughness(), 1300)
	e.apply(BattleAction.weapon("side0"))
	var state: Dictionary = e.events[-1]["state"][1]
	assert_eq(state["layer"], 200)
	assert_eq(state["layer_max"], 300)
	var plain := Fx.engine(Fx.build([Fx.gun()]), Fx.build())
	assert_eq(plain.mechs[1].layer_max, 0, "sin manto, nada cambia")


func test_el_campeon_de_la_liga_6_lleva_el_manto_y_ya_no_bloquea() -> void:
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var egida: ChassisDef = chassis.get_def("jefe_egida")
	assert_gt(egida.shield_layer, 0.0)
	assert_eq(egida.shield_hits, 0, "ya no para golpes enteros")
	assert_eq(egida.ability, "Manto de plasma")
	var library := ChassisLibrary.new()
	library.add({"id": "x", "shield_layer": 1.5})
	library.add({"id": "y", "shield_layer": -0.1})
	assert_eq(library.errors.size(), 2)


func test_la_evasion_salta_al_extremo_de_su_lado_una_vez_por_turno() -> void:
	var boss := _boss({"evade": true})
	var e := Fx.engine(Fx.build([Fx.gun(), Fx.gun()]), boss)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].position, 9, "empezo en la 5 y salta a la 9")
	assert_eq(e.mechs[1].health, 900, "esquivar no le quita el dano")
	e.apply(BattleAction.weapon("side1"))
	assert_eq(e.mechs[1].health, 800)
	var evades := e.events.filter(func(entry: Dictionary) -> bool: return entry["event"] == "evade")
	assert_eq(evades.size(), 1)
	assert_eq(evades[0]["who"], 1)


func test_la_evasion_no_salta_si_el_golpe_no_hace_dano() -> void:
	var boss := _boss({"evade": true})
	var heater := Fx.gun({"dmg_min": 0, "dmg_max": 0, "heat_dmg": 20})
	var e := Fx.engine(Fx.build([heater]), boss)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].position, 5)
	assert_false(Fx.has_event(e, "evade"))


func test_el_nucleo_termico_nunca_se_sobrecalienta() -> void:
	var heater := Fx.gun({"heat_dmg": 900})
	var e := Fx.engine(Fx.build([heater]), _boss({"no_overheat": true}))
	e.apply(BattleAction.weapon("side0"))
	Fx.pass_turn(e)
	assert_eq(e.turn, 1)
	assert_eq(e.actions_left, 2, "conserva sus dos acciones")
	assert_false(Fx.has_event(e, "forced_cool"))
	assert_false(Fx.has_event(e, "shutdown"))
	assert_lte(e.mechs[1].heat, e.mechs[1].heat_cap)
	# Sin la habilidad, el mismo calor lo apaga.
	var plain := Fx.engine(Fx.build([heater]), _boss({}))
	plain.apply(BattleAction.weapon("side0"))
	Fx.pass_turn(plain)
	assert_true(Fx.has_event(plain, "shutdown"))


func test_el_enjambre_dispara_dos_veces_salvo_con_el_rival_pegado() -> void:
	var swarm := _boss({"extra_drone_shots": 1}, [], {"drone": _drone(30)})
	var far := Fx.engine(swarm, Fx.build(), 2)
	Fx.pass_turn(far)
	assert_eq(far.mechs[1].health, 940, "a distancia disparan los dos drones")
	var near := Fx.engine(swarm, Fx.build(), 0)
	Fx.pass_turn(near)
	assert_eq(near.mechs[1].health, 970, "pegado a el solo dispara uno")


func test_la_resistencia_de_un_solo_elemento_se_puede_bajar() -> void:
	var build := _boss({"res_energy_mult": 0.25})
	build.torso = Fx.torso({"res_physical": 20, "res_energy": 20})
	var s := build.summary(Fx.rules())
	assert_eq(s["res_physical"], 20)
	assert_eq(s["res_energy"], 5)


func test_los_datos_de_habilidad_malos_se_avisan() -> void:
	var library := ChassisLibrary.new()
	library.add({"id": "a", "shield_hits": 5})
	library.add({"id": "b", "regen_share": 0.9})
	library.add({"id": "c", "res_energy_mult": 0.0})
	assert_eq(library.errors.size(), 3)


func test_los_diez_jefes_tienen_habilidades_distintas() -> void:
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var builds := BuildLibrary.load_file("res://data/builds.json")
	assert_eq(chassis.errors, [] as Array[String])
	assert_eq(builds.boss_ids().size(), 10, "un jefe por zona")
	var seen := {}
	for id in builds.boss_ids():
		seen[chassis.get_def(builds.chassis_of(id)).ability] = true
	assert_eq(seen.size(), 10)


func test_cada_jefe_termina_sus_combates() -> void:
	# Ninguna habilidad deja el combate atascado: regenerar o esquivar no lo
	# alargan hasta el limite de turnos.
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var builds := BuildLibrary.load_file("res://data/builds.json")
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var tier := ItemDef.Tier.COMMON
	var level := rules.tier_max_level[tier]
	var player := builds.make("calor_horno", catalog, rules, tier, level)
	for id in builds.boss_ids():
		var boss := builds.make(id, catalog, rules, tier, level, chassis)
		var result := BattleRunner.run(
			rules,
			player,
			boss,
			BattleAI.new(BattleAI.Difficulty.NORMAL, 3),
			BattleAI.new(BattleAI.Difficulty.NORMAL, 4),
			7,
			0
		)
		assert_gte(int(result["winner"]), 0, "%s termina con un ganador" % id)
