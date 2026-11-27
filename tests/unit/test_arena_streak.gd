extends GutTest
## La racha de la arena, doble o nada (OBS-049, del usuario): "si das otro
## combate se te duplica la cantidad... y asi sucesivamente al tercer, cuarto
## combate y quinto combate... el enemigo que viene es considerablemente mas
## fuerte... puedes tener un buen bonus o perder toda tu recompensa
## acumulada".

var _library: BuildLibrary
var _shop: ArenaShop
var _campaign: Campaign
var _rules := RulesConfig.new()


func before_all() -> void:
	_library = BuildLibrary.load_file("res://data/builds.json")
	_shop = ArenaShop.load_file("res://data/arena_shop.json")
	_campaign = Campaign.load_file("res://data/campaign.json", _library)


## Un jugador en la ultima liga (paga x 3.2: 960 por ganar en la arena).
func _profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.zone = _campaign.zone_count() - 1
	profile.gold = 1000
	return profile


func _base() -> int:
	return roundi(_shop.reward("arena_win") * _campaign.reward_mult(_campaign.zone_count() - 1))


func test_la_racha_esta_en_los_datos() -> void:
	assert_eq(_campaign.errors, [] as Array[String])
	# OBS-051: "lo podemos expandir hasta 20 veces".
	assert_eq(_campaign.streak_fights(), 20, "hasta el combate 20")
	for step in 5:
		assert_eq(_campaign.streak_prize(step), pow(2.0, step), "el premio se dobla")
	# Desde el sexto crece mas despacio (su eleccion: x 1.25 por combate).
	for step in range(5, 20):
		var ratio := _campaign.streak_prize(step) / _campaign.streak_prize(step - 1)
		assert_almost_eq(ratio, 1.25, 0.002, "paso %d: x 1.25" % step)
	assert_eq(_base(), 960, "los 960 de su ejemplo")


## OBS-051: "el bonus tambien sera de experiencia y demas para gastar en
## puntos de mejora". Cada combate da mas experiencia que el anterior y pone
## puntos en el bote; los hitos (10, 15 y 20) dan mas.
func test_la_racha_da_experiencia_y_puntos_que_crecen() -> void:
	var total := 0
	for step in 20:
		if step > 0:
			assert_gt(_campaign.streak_xp(step), _campaign.streak_xp(step - 1), "paso %d" % step)
		assert_gt(_campaign.streak_points(step), 0, "paso %d: da puntos" % step)
		total += _campaign.streak_points(step)
	for milestone: int in [9, 14, 19]:
		assert_gt(
			_campaign.streak_points(milestone),
			_campaign.streak_points(milestone - 1),
			"el combate %d es un hito" % (milestone + 1)
		)
	assert_eq(total, 66, "una racha entera")


func test_ganar_pone_el_premio_en_el_bote_sin_cobrarlo() -> void:
	var profile := _profile()
	var out := _campaign.finish_fight(profile, _shop, "arena", true)
	assert_eq(profile.gold, 1000, "no se cobra al momento")
	assert_eq(profile.arena_pot, 960)
	assert_eq(out["prize"], 960)
	assert_true(out["more"], "se puede pedir otro")
	assert_eq(profile.wins, 1)
	# "Ya recibirias el doble de 960 mas los 960".
	_campaign.finish_fight(profile, _shop, "arena", true)
	assert_eq(profile.arena_pot, 960 + 1920)
	assert_eq(profile.arena_streak, 2)


func test_perder_en_la_racha_pierde_el_bote_entero() -> void:
	var profile := _profile()
	_campaign.finish_fight(profile, _shop, "arena", true)
	_campaign.finish_fight(profile, _shop, "arena", true)
	var out := _campaign.finish_fight(profile, _shop, "arena", false)
	assert_eq(out["lost"], 2880, "el bote acumulado")
	assert_eq(profile.arena_pot, 0)
	assert_eq(profile.arena_streak, 0, "la siguiente racha empieza de cero")
	var consolation := roundi(_shop.reward("arena_loss") * 3.2)
	assert_eq(profile.gold, 1000 + consolation, "solo lo de perder, como siempre")
	assert_false(out["more"])


func test_la_racha_completa_se_cobra_sola() -> void:
	var profile := _profile()
	var out := {}
	var expected := 0
	for step in 20:
		expected += roundi(960 * _campaign.streak_prize(step))
		# Los ultimos son de varios robots seguidos (OBS-058).
		for robot in _campaign.streak_robots(step):
			out = _campaign.finish_fight(profile, _shop, "arena", true)
		if step < 19:
			assert_true(out["more"], "tras el %d se puede seguir" % (step + 1))
	assert_false(out["more"], "no hay combate 21")
	assert_eq(out["gold"], expected, "todo el bote de celdas")
	assert_eq(profile.gold, 1000 + expected)
	assert_eq(out["points_cashed"], 66, "y sus puntos")
	assert_eq(profile.upgrade_points, 66)
	assert_eq(profile.arena_pot, 0)
	assert_eq(profile.arena_points, 0)
	assert_eq(profile.arena_streak, 0)


## Su eleccion: al perder se pierden las celdas y los puntos del bote; la
## experiencia se gana siempre.
func test_los_puntos_van_al_bote_y_se_pierden_con_el() -> void:
	var profile := _profile()
	var progression := Progression.load_file("res://data/progression.json")
	var won := _campaign.finish_fight(profile, _shop, "arena", true, progression)
	assert_eq(won["points"], _campaign.streak_points(0))
	assert_eq(profile.arena_points, _campaign.streak_points(0), "al bote, sin cobrar")
	assert_eq(profile.upgrade_points, 0)
	var second := _campaign.finish_fight(profile, _shop, "arena", true, progression)
	var base_xp := progression.xp_for("win")
	assert_eq(second["xp"], roundi(base_xp * _campaign.streak_xp(1)), "mas experiencia")
	var xp_before := profile.xp
	var lost := _campaign.finish_fight(profile, _shop, "arena", false, progression)
	assert_eq(lost["points_lost"], _campaign.streak_points(0) + _campaign.streak_points(1))
	assert_eq(profile.arena_points, 0)
	assert_eq(profile.upgrade_points, 0, "no se cobra nada")
	assert_eq(profile.xp, xp_before + progression.xp_for("loss"), "la experiencia se queda")
	# Cobrar a mitad de racha pasa los puntos a los de gastar.
	_campaign.finish_fight(profile, _shop, "arena", true)
	_campaign.cash_arena(profile)
	assert_eq(profile.upgrade_points, _campaign.streak_points(0))


func test_cobrar_y_volver_a_abrir_el_juego() -> void:
	var profile := _profile()
	_campaign.finish_fight(profile, _shop, "arena", true)
	assert_eq(_campaign.cash_arena(profile), 960)
	assert_eq(profile.gold, 1960)
	assert_eq(profile.arena_streak, 0)
	# Cerrar el juego con el bote sin cobrar: se cobra al volver.
	_campaign.finish_fight(profile, _shop, "arena", true)
	var resumed := _campaign.resume_arena(profile)
	assert_eq(resumed["cashed"], 960)
	assert_eq(profile.gold, 2920)
	# Cerrarlo en mitad de un combate de la racha: se abandona y se pierde.
	_campaign.finish_fight(profile, _shop, "arena", true)
	_campaign.begin_arena(profile)
	assert_true(profile.arena_live, "con bote en juego, el combate queda marcado")
	var points := profile.upgrade_points
	resumed = _campaign.resume_arena(profile)
	assert_eq(resumed["lost"], 960)
	assert_eq(profile.gold, 2920, "no se cobra")
	assert_eq(profile.arena_pot, 0)
	assert_eq(profile.arena_points, 0, "los puntos tambien se pierden")
	assert_eq(profile.upgrade_points, points)


func test_el_primer_combate_no_marca_nada_que_perder() -> void:
	var profile := _profile()
	_campaign.begin_arena(profile)
	assert_false(profile.arena_live, "sin bote no hay nada en juego")


func test_cada_rival_de_la_racha_sale_mas_fuerte() -> void:
	var zone := _campaign.zone_count() - 1
	var power := ItemScaling.power(_rules, ItemDef.Tier.MYTHIC, 30)
	var first := _campaign.arena_fight(zone, _library, 4242, _rules, power)
	var same := _campaign.arena_streak_fight(zone, _library, 4242, _rules, power, {}, 0)
	assert_eq(same["enemy"], first["enemy"], "el primero es el de siempre")
	assert_eq(same["tier"], first["tier"])
	assert_eq(same["level"], first["level"])
	var last_power := 0.0
	var last_skills := -1
	for step in _campaign.streak_fights():
		var fight := _campaign.arena_streak_fight(zone, _library, 4242, _rules, power, {}, step)
		var strength := ItemScaling.power(_rules, fight["tier"], fight["level"])
		assert_true(strength >= last_power, "paso %d: no mas flojo" % step)
		assert_true(int(fight["skills"]) >= last_skills, "paso %d: nunca menos entrenado" % step)
		last_power = strength
		last_skills = int(fight["skills"])
	var first_edge := float(same.get("edge", 0.0))
	assert_eq(first_edge, 0.0, "el primero, sin plus")
	var top := _campaign.arena_streak_fight(zone, _library, 4242, _rules, power, {}, 4)
	assert_gt(float(top["edge"]), first_edge, "el quinto, con plus")
	assert_gt(int(top["tier"]), _campaign.tier_of(zone), "pasa de la clase de la liga")
	# OBS-051: "los enemigos deben ser realmente desafiantes": desde el sexto,
	# la IA dificil, y el plus sigue creciendo hasta el 20.
	var sixth := _campaign.arena_streak_fight(zone, _library, 4242, _rules, power, {}, 5)
	assert_eq(sixth["difficulty"], "HARD")
	var last := _campaign.arena_streak_fight(zone, _library, 4242, _rules, power, {}, 19)
	assert_gt(float(last["edge"]), float(sixth["edge"]))


func test_la_racha_se_guarda_con_la_partida() -> void:
	var profile := _profile()
	profile.arena_pot = 2880
	profile.arena_streak = 2
	profile.arena_live = true
	profile.arena_points = 2
	profile.upgrade_points = 17
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(copy.arena_pot, 2880)
	assert_eq(copy.arena_streak, 2)
	assert_true(copy.arena_live)
	assert_eq(copy.arena_points, 2)
	assert_eq(copy.upgrade_points, 17)
	var old := PlayerProfile.from_dict({})
	assert_eq(old.arena_pot, 0, "una partida vieja no tiene bote")
	assert_eq(old.upgrade_points, 0, "ni puntos de mejora")
	# Perder la partida los pierde, como lo demas.
	profile.end_run()
	assert_eq(profile.upgrade_points, 0)
	assert_eq(profile.arena_points, 0)


## Cuando el jugador ya esta en lo mas alto, mas clase no hace al rival mas
## fuerte: el plus de la racha le suma vida y dano encima de su armeria.
func test_el_plus_suma_vida_y_dano_al_rival() -> void:
	var zone := _campaign.zone_count() - 1
	var plain := _campaign.fight_upgrades(zone, _shop)
	var boosted := _campaign.fight_upgrades(zone, _shop, 0.5)
	assert_almost_eq(boosted.health - plain.health, 0.5, 0.0001)
	assert_almost_eq(boosted.damage_mult() - plain.damage_mult(), 0.5, 0.0001)
	var last := -1.0
	for step in _campaign.streak_fights():
		var fight := _campaign.arena_streak_fight(zone, _library, 7, _rules, 1.0, {}, step)
		assert_true(float(fight["edge"]) >= last, "paso %d: nunca menos plus" % step)
		last = float(fight["edge"])


# --- Los ultimos combates, de tres robots seguidos (OBS-058) ---------------


func test_los_ultimos_son_de_tres_robots() -> void:
	for step in 15:
		assert_eq(_campaign.streak_robots(step), 1, "combate %d" % (step + 1))
	for step in range(15, 20):
		assert_eq(_campaign.streak_robots(step), 3, "combate %d" % (step + 1))


## Entre robots el bote sigue en juego y no entra el premio; al tumbar al
## ultimo, entra y toca el combate siguiente.
func test_entre_robots_el_bote_sigue_en_juego() -> void:
	var profile := _profile()
	profile.arena_streak = 15
	profile.arena_pot = 5000
	var first := _campaign.finish_fight(profile, _shop, "arena", true)
	assert_true(bool(first["next_robot"]))
	assert_eq([profile.arena_robot, profile.arena_pot, profile.arena_streak], [1, 5000, 15])
	assert_true(profile.arena_live, "salir ahora es abandonar")
	assert_eq(int(first["prize"]), 0)
	_campaign.finish_fight(profile, _shop, "arena", true)
	var last := _campaign.finish_fight(profile, _shop, "arena", true)
	assert_false(bool(last["next_robot"]))
	assert_eq([profile.arena_robot, profile.arena_streak], [0, 16])
	assert_gt(profile.arena_pot, 5000, "entra el premio")


func test_caer_en_el_segundo_pierde_el_bote() -> void:
	var profile := _profile()
	profile.arena_streak = 17
	profile.arena_robot = 1
	profile.arena_pot = 9000
	profile.arena_field.append({"id": "plates", "slot": ""})
	var out := _campaign.finish_fight(profile, _shop, "arena", false)
	assert_eq(int(out["lost"]), 9000)
	assert_eq([profile.arena_robot, profile.arena_pot, profile.arena_streak], [0, 0, 0])
	assert_eq(profile.arena_field.size(), 0)


## Salir o cerrar el juego entre robots es abandonar: se pierde el bote.
func test_salir_entre_robots_pierde_el_bote() -> void:
	var profile := _profile()
	profile.arena_streak = 15
	profile.arena_pot = 7000
	_campaign.finish_fight(profile, _shop, "arena", true)
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(copy.arena_robot, 1, "se guarda")
	var resumed := _campaign.resume_arena(copy)
	assert_eq(int(resumed["lost"]), 7000)
	assert_eq([copy.arena_robot, copy.arena_pot], [0, 0])
