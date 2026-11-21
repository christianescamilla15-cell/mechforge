extends GutTest
## Habilidades especiales de los jefes (GDD 9.1): cada una cambia una regla del
## combate y deja un punto debil. El mech 0 es el jugador y empieza el.

## OBS-041, del usuario: el escudo del campeon de la liga 6 "exagera un
## poco": deberia parar segun el arma, mucho las medianas, menos las largas y
## casi nunca las pesadas.
const CHANCES := {"arms": 0.6, "shoulder": 0.4, "chest": 0.05, "other": 0.6}


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


func _egida_engine(draw: float) -> BattleEngine:
	var boss := _boss({"shield_hits": 1, "shield_chance": CHANCES})
	var chest := Fx.item(
		ItemDef.Type.CHEST, {"weight": 40, "dmg_min": 300, "dmg_max": 300, "uses": 1}
	)
	var player := Fx.build([Fx.gun()], {"tops": [Fx.gun()]})
	player.chest = chest
	var e := Fx.engine(player, boss)
	e.fixed_block = draw
	return e


func test_el_escudo_con_probabilidad_para_segun_el_arma() -> void:
	var boss := _boss({"shield_hits": 1, "shield_chance": CHANCES})
	var e := Fx.engine(Fx.build([Fx.gun()]), boss)
	assert_eq(e.mechs[1].shield_chance("side0"), 0.6, "brazo")
	assert_eq(e.mechs[1].shield_chance("top0"), 0.4, "hombro")
	assert_eq(e.mechs[1].shield_chance("chest"), 0.05, "pecho")
	assert_eq(e.mechs[1].shield_chance("drone"), 0.6, "lo demas")
	# Por debajo de su probabilidad lo para; por encima, entra entero.
	var low := _egida_engine(0.5)
	low.apply(BattleAction.weapon("side0"))
	assert_eq(low.mechs[1].health, 1000, "0.5 < 0.6: el brazo choca con el escudo")
	assert_true(low.events[-1].get("shielded", false))
	var high := _egida_engine(0.5)
	high.apply(BattleAction.weapon("top0"))
	assert_eq(high.mechs[1].health, 900, "0.5 > 0.4: el hombro entra")
	assert_false(high.events[-1].get("shielded", false))
	var chest := _egida_engine(0.1)
	chest.apply(BattleAction.weapon("chest"))
	assert_eq(chest.mechs[1].health, 700, "el pecho casi nunca se para")


func test_el_escudo_con_probabilidad_lo_intenta_una_vez_por_turno() -> void:
	var e := _egida_engine(0.9)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, 900, "no lo paro")
	e.fixed_block = 0.0
	e.apply(BattleAction.weapon("top0"))
	assert_eq(e.mechs[1].health, 800, "ya lo intento con el primero: el segundo entra")


func test_la_prevision_avisa_de_la_probabilidad_del_escudo() -> void:
	var e := _egida_engine(-1.0)
	var p := e.preview(BattleAction.weapon("top0"))
	assert_eq(p["dmg_min"], 100, "el dano entero, sin contar el escudo")
	assert_eq(p["block_chance"], 0.4)
	# Un escudo que para siempre se sigue avisando con dano 0.
	var old := Fx.engine(Fx.build([Fx.gun()]), _boss({"shield_hits": 1}))
	assert_eq(old.preview(BattleAction.weapon("side0"))["dmg_max"], 0)
	assert_false(old.preview(BattleAction.weapon("side0")).has("block_chance"))


func test_el_campeon_de_la_liga_6_lleva_el_escudo_con_probabilidad() -> void:
	var chassis := ChassisLibrary.load_file("res://data/chassis.json")
	var egida: ChassisDef = chassis.get_def("jefe_egida")
	assert_eq(egida.shield_hits, 1)
	assert_eq(egida.shield_chance, CHANCES)
	var library := ChassisLibrary.new()
	library.add({"id": "x", "shield_chance": {"arms": 1.5}})
	library.add({"id": "y", "shield_chance": {"cabeza": 0.5}})
	assert_eq(library.errors.size(), 2, "probabilidades fuera de rango o grupos desconocidos")


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
