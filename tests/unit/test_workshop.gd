extends GutTest
## Taller (GDD 8): cada pieza del jugador sube de nivel por separado y, al
## maximo de su clase, se transforma a la siguiente si la zona lo permite.

const T := ItemDef.Tier

var _rules: RulesConfig
var _workshop: Workshop


func before_all() -> void:
	_rules = RulesConfig.new()
	_workshop = Workshop.load_file("res://data/workshop.json")


func test_el_taller_del_juego_carga_sin_errores() -> void:
	assert_eq(_workshop.errors, [] as Array[String])
	assert_gt(_workshop.level_price, 0)


func test_cada_nivel_cuesta_mas_y_las_clases_altas_mas() -> void:
	for tier in T.DIVINE:
		var top := _rules.tier_max_level[tier] - 1
		for level in range(1, top + 1):
			# Con redondeo, dos niveles seguidos pueden costar lo mismo.
			assert_gte(
				_workshop.level_cost(_rules, tier, level),
				_workshop.level_cost(_rules, tier, level - 1),
				"clase %d nivel %d" % [tier, level]
			)
		assert_gt(_workshop.level_cost(_rules, tier, top), _workshop.level_cost(_rules, tier, 0))
	# Recorrer una clase entera cuesta mas cuanto mas alta es, en proporcion a lo
	# que pagan sus zonas.
	for tier in range(1, T.DIVINE):
		var whole := _class_cost(tier)
		assert_gt(whole, _class_cost(tier - 1))
		var ratio := whole / _class_cost(T.COMMON) / _rules.tier_mult[tier]
		assert_almost_eq(ratio, 1.0, 0.1, "clase %d en proporcion" % tier)
	for tier in range(1, T.DIVINE - 1):
		assert_gt(_workshop.transform_cost(tier), _workshop.transform_cost(tier - 1))
	assert_eq(_workshop.transform_cost(T.MYTHIC), 0, "a Unica no se llega transformando")


func _class_cost(tier: int) -> float:
	var total := 0.0
	for level in _rules.tier_max_level[tier]:
		total += _workshop.level_cost(_rules, tier, level)
	return total


func test_una_pieza_nueva_empieza_en_basica_nivel_0() -> void:
	var profile := PlayerProfile.new()
	assert_eq(profile.part("lat_mandoble"), {"tier": 0, "level": 0})


func test_subir_una_pieza_gasta_celdas_y_sube_un_nivel() -> void:
	var profile := PlayerProfile.new()
	assert_eq(profile.level_up(_workshop, _rules, "lat_mandoble"), "faltan celdas")
	var cost := _workshop.level_cost(_rules, T.COMMON, 0)
	profile.gold = cost + 5
	assert_eq(profile.level_up(_workshop, _rules, "lat_mandoble"), "")
	assert_eq(profile.part("lat_mandoble"), {"tier": 0, "level": 1})
	assert_eq(profile.gold, 5)
	assert_eq(profile.part("lat_trabuco")["level"], 0, "las demas piezas no cambian")


func test_no_se_pasa_del_nivel_maximo_de_la_clase() -> void:
	var profile := PlayerProfile.new()
	profile.gold = 1000000
	for i in _rules.tier_max_level[T.COMMON]:
		assert_eq(profile.level_up(_workshop, _rules, "torso_baluarte"), "")
	assert_eq(
		profile.level_up(_workshop, _rules, "torso_baluarte"), "esta al nivel maximo de su clase"
	)


func test_transformar_pide_el_nivel_maximo_y_que_la_zona_lo_permita() -> void:
	var profile := PlayerProfile.new()
	profile.gold = 1000000
	var id := "torso_baluarte"
	assert_eq(
		profile.transform(_workshop, _rules, id, T.RARE), "primero hay que llevarla al nivel maximo"
	)
	profile.parts[id] = {"tier": T.COMMON, "level": _rules.tier_max_level[T.COMMON]}
	assert_eq(
		profile.transform(_workshop, _rules, id, T.COMMON),
		"la clase siguiente se abre en otra zona"
	)
	var gold := profile.gold
	assert_eq(profile.transform(_workshop, _rules, id, T.RARE), "")
	assert_eq(profile.part(id), {"tier": T.RARE, "level": 0}, "vuelve al nivel 0")
	assert_eq(profile.gold, gold - _workshop.transform_cost(T.COMMON))


func test_transformar_siempre_mejora_la_pieza() -> void:
	# GDD 8: el nivel 0 de una clase rinde mas que el maximo de la anterior.
	for tier in range(1, T.DIVINE):
		var below := ItemScaling.power(_rules, tier - 1, _rules.tier_max_level[tier - 1])
		assert_gt(ItemScaling.power(_rules, tier, 0), below)


func test_las_piezas_unicas_no_salen_del_taller() -> void:
	var profile := PlayerProfile.new()
	profile.gold = 1000000
	profile.parts["lat_mandoble"] = {"tier": T.MYTHIC, "level": _rules.tier_max_level[T.MYTHIC]}
	assert_eq(
		profile.transform(_workshop, _rules, "lat_mandoble", T.DIVINE),
		"las piezas unicas solo las sueltan los jefes"
	)


func test_el_mech_pelea_con_la_clase_y_el_nivel_de_cada_pieza() -> void:
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var parts := {"torso_baluarte": {"tier": T.RARE, "level": 4}}
	var own := library.make("fisico_vanguardia", catalog, _rules, T.COMMON, 0, null, parts)
	var plain := library.make("fisico_vanguardia", catalog, _rules, T.COMMON, 0)
	assert_eq(own.torso.tier, T.RARE)
	assert_eq(own.torso.level, 4)
	assert_gt(own.torso.health, plain.torso.health)
	assert_eq(own.legs.tier, T.COMMON, "las piezas sin mejorar siguen en Basica 0")
	assert_eq(own.legs.health, plain.legs.health)


func test_las_piezas_del_mech_salen_sin_repetir() -> void:
	var library := BuildLibrary.load_file("res://data/builds.json")
	var ids := library.item_ids("calor_horno")
	assert_has(ids, "torso_fragua")
	assert_has(ids, "esp_garfio")
	assert_eq(ids.count("mod_blindaje"), 1, "los dos blindajes suben juntos")


func test_perder_la_partida_borra_las_piezas() -> void:
	var profile := PlayerProfile.new()
	profile.parts["lat_mandoble"] = {"tier": T.RARE, "level": 2}
	profile.end_run()
	assert_eq(profile.part("lat_mandoble"), {"tier": 0, "level": 0})


func test_las_piezas_se_guardan_y_un_guardado_viejo_se_migra() -> void:
	var profile := PlayerProfile.new()
	profile.parts["lat_mandoble"] = {"tier": T.RARE, "level": 2}
	var path := "user://test_profile_piezas.json"
	assert_true(profile.save(path))
	var loaded := PlayerProfile.load_or_new(path)
	assert_eq(loaded.part("lat_mandoble"), {"tier": T.RARE, "level": 2})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old := PlayerProfile.from_dict({"schema_version": 2, "gold": 40, "zone": 0})
	assert_eq(old.gold, 40)
	assert_true(old.parts.is_empty())
	assert_eq(old.to_dict()["schema_version"], PlayerProfile.SCHEMA_VERSION)


func test_el_costo_total_suma_niveles_y_transformaciones() -> void:
	var expected := 0
	for level in _rules.tier_max_level[T.COMMON]:
		expected += _workshop.level_cost(_rules, T.COMMON, level)
	expected += _workshop.transform_cost(T.COMMON)
	expected += _workshop.level_cost(_rules, T.RARE, 0)
	assert_eq(_workshop.total_cost(_rules, T.RARE, 1), expected)


func test_un_nucleo_unico_convierte_una_pieza_mitica_al_maximo_en_unica() -> void:
	var profile := PlayerProfile.new()
	var id := "lat_mandoble"
	profile.parts[id] = {"tier": T.MYTHIC, "level": _rules.tier_max_level[T.MYTHIC]}
	profile.unique_cores = 1
	profile.gold = 7
	assert_eq(profile.transform(_workshop, _rules, id, T.MYTHIC), "")
	assert_eq(profile.part(id), {"tier": T.DIVINE, "level": 0})
	assert_eq(profile.unique_cores, 0, "gasta el nucleo")
	assert_eq(profile.gold, 7, "no gasta celdas")
	assert_eq(profile.transform(_workshop, _rules, id, T.MYTHIC), "ya es una pieza unica")


func test_perder_la_partida_borra_los_nucleos_unicos() -> void:
	var profile := PlayerProfile.new()
	profile.unique_cores = 2
	profile.end_run()
	assert_eq(profile.unique_cores, 0)


func test_la_zona_pone_tope_al_nivel_de_las_piezas_de_su_clase() -> void:
	var profile := PlayerProfile.new()
	profile.gold = 1000000
	var id := "lat_trabuco"
	for i in 3:
		assert_eq(profile.level_up(_workshop, _rules, id, T.COMMON, 3), "")
	assert_eq(profile.level_up(_workshop, _rules, id, T.COMMON, 3), "la zona no deja subirla mas")
	assert_eq(profile.part(id)["level"], 3)
	# En una zona de clase superior el tope no afecta a las piezas de clase baja.
	assert_eq(profile.level_up(_workshop, _rules, id, T.RARE, 0), "")
	assert_eq(profile.part(id)["level"], 4)
