extends GutTest
## Mechs de ejemplo (data/builds.json) y prueba de estres del motor con piezas reales.

const T := ItemDef.Tier

var _catalog: Catalog
var _library: BuildLibrary
var _rules: RulesConfig


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_rules = RulesConfig.new()


func test_la_biblioteca_carga_sin_errores() -> void:
	assert_eq(_library.errors, [] as Array[String])
	assert_eq(_library.starter_ids().size(), 4, "los cuatro mechs de ejemplo de balas")
	for band: String in ["balas", "canon", "blaster", "laser"]:
		assert_eq(_library.band_ids(band).size(), 4, "cuatro mechs de %s" % band)


func test_hay_un_mech_de_ejemplo_por_elemento_y_un_hibrido() -> void:
	var elements := _library.starter_ids().map(
		func(id: String) -> String: return _library.element_of(id)
	)
	for expected: String in ["PHYSICAL", "HEAT", "ENERGY", "HYBRID"]:
		assert_has(elements, expected)


func test_los_mechs_de_ejemplo_son_validos_y_caben_en_1000_kg() -> void:
	for id in _library.ids():
		var build := _library.make(id, _catalog, _rules, T.DIVINE, 40)
		assert_eq(_catalog.errors, [] as Array[String], "%s usa piezas que existen" % id)
		assert_eq(build.validate(_rules), [] as Array[String], "%s es valido" % id)
		# Con tres armas (OBS-033) pesan menos que con seis: queda sitio libre.
		assert_between(build.total_weight(), 820, 1000, "%s aprovecha el peso sin sobrecarga" % id)


func test_el_mech_de_cada_elemento_usa_armas_de_su_elemento() -> void:
	for id in _library.ids():
		var element := _library.element_of(id)
		if element == "HYBRID":
			continue
		var build := _library.make(id, _catalog, _rules, T.DIVINE, 40)
		for weapon in build.sides + build.tops:
			assert_eq(ItemDef.Element.find_key(weapon.element), element, "%s: %s" % [id, weapon.id])


func test_el_peso_no_cambia_con_el_tier() -> void:
	for id in _library.ids():
		var low := _library.make(id, _catalog, _rules, T.COMMON, 0)
		var top := _library.make(id, _catalog, _rules, T.DIVINE, 40)
		assert_eq(low.total_weight(), top.total_weight())
		assert_lt(low.summary(_rules)["health"], top.summary(_rules)["health"])


## Juega combates con acciones legales al azar y comprueba que el estado
## nunca se rompe, con piezas reales y en dos tiers distintos.
func test_estres_con_acciones_al_azar() -> void:
	var ids := _library.ids()
	var battles := 0
	var finished := 0
	for tier: ItemDef.Tier in [T.COMMON, T.DIVINE]:
		for a in ids:
			for b in ids:
				for seed_value in 3:
					var build_a := _library.make(a, _catalog, _rules, tier, 0)
					var build_b := _library.make(b, _catalog, _rules, tier, 0)
					var e := BattleEngine.new(_rules, build_a, build_b, seed_value, seed_value % 2)
					if not _play_random(e, seed_value + 100):
						return
					battles += 1
					if e.is_over():
						finished += 1
	gut.p("combates al azar: %d, terminados: %d" % [battles, finished])
	assert_gt(finished, battles / 2, "la mayoria de los combates al azar terminan")


func _play_random(e: BattleEngine, seed_value: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for step in 600:
		if e.is_over():
			return true
		var actions := e.legal_actions()
		if actions.is_empty():
			fail_test("sin acciones legales con el combate en curso (paso %d)" % step)
			return false
		var action := actions[rng.randi_range(0, actions.size() - 1)]
		var health_before := [e.mechs[0].health, e.mechs[1].health]
		var reason := e.apply(action)
		if reason != "":
			fail_test("una accion legal fue rechazada: %s" % reason)
			return false
		var problem := _invariant_problem(e, health_before)
		if problem != "":
			fail_test("%s (paso %d, accion %s)" % [problem, step, action.to_dict()])
			return false
	return true


func _invariant_problem(e: BattleEngine, health_before: Array) -> String:
	if e.mechs[0].position == e.mechs[1].position:
		return "dos mechs en la misma casilla"
	for i in 2:
		var m := e.mechs[i]
		if m.position < 0 or m.position >= e.rules.arena_size:
			return "mech fuera de la arena"
		if m.energy < 0 or m.energy > m.energy_cap:
			return "energia fuera de rango: %d de %d" % [m.energy, m.energy_cap]
		if m.heat < 0:
			return "calor negativo"
		if m.health > health_before[i]:
			return "la vida subio"
		if m.heat_cap < 1 or m.cooling < 1 or m.energy_cap < 1 or m.energy_regen < 1:
			return "una capacidad bajo de 1"
		if m.res.min() < 0:
			return "resistencia negativa"
	if e.actions_left < 0 or e.actions_left > e.rules.actions_per_turn:
		return "acciones restantes fuera de rango"
	if not e.is_over() and e.actions_left == 0:
		return "turno sin acciones y combate en curso"
	return ""
