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
	assert_eq(_campaign.streak_fights(), 5, "hasta el quinto combate")
	for step in 5:
		assert_eq(_campaign.streak_prize(step), pow(2.0, step), "el premio se dobla")
	assert_eq(_base(), 960, "los 960 de su ejemplo")


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
	for step in 5:
		out = _campaign.finish_fight(profile, _shop, "arena", true)
	assert_false(out["more"], "no hay sexto combate")
	assert_eq(out["gold"], 960 * 31, "960 + 1920 + 3840 + 7680 + 15360")
	assert_eq(profile.gold, 1000 + 960 * 31)
	assert_eq(profile.arena_pot, 0)
	assert_eq(profile.arena_streak, 0)


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
	resumed = _campaign.resume_arena(profile)
	assert_eq(resumed["lost"], 960)
	assert_eq(profile.gold, 2920, "no se cobra")
	assert_eq(profile.arena_pot, 0)


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
	assert_gt(float(top["edge"]), first_edge, "el ultimo, con plus")
	assert_gt(int(top["tier"]), _campaign.tier_of(zone), "pasa de la clase de la liga")


func test_la_racha_se_guarda_con_la_partida() -> void:
	var profile := _profile()
	profile.arena_pot = 2880
	profile.arena_streak = 2
	profile.arena_live = true
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(copy.arena_pot, 2880)
	assert_eq(copy.arena_streak, 2)
	assert_true(copy.arena_live)
	var old := PlayerProfile.from_dict({})
	assert_eq(old.arena_pot, 0, "una partida vieja no tiene bote")


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
