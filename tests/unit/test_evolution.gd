extends GutTest
## Las armas que llegan al tope de su tipo evolucionan en la del tipo siguiente
## (OBS-045, del usuario: "en las armas ya no me deja subir al nivel, aparece
## el maximo, pero ya no hay mas armas... para seguir subiendolas de nivel"),
## y los drones del asistente suben con el desde su propia casilla.

const T := ItemDef.Tier

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _workshop: Workshop
var _brief: WorkshopBrief


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_workshop = Workshop.load_file("res://data/workshop.json")
	_brief = WorkshopBrief.new()
	_brief.rules = _rules
	_brief.catalog = _catalog
	_brief.library = _library
	_brief.campaign = Campaign.load_file("res://data/campaign.json", _library)
	_brief.workshop = _workshop
	_brief.garage = Garage.load_file("res://data/part_shop.json")
	_brief.shop = ArenaShop.load_file("res://data/arena_shop.json")
	_brief.skills = SkillTree.load_file("res://data/skills.json")
	_brief.progression = Progression.load_file("res://data/progression.json")
	_brief.styles = StyleLibrary.load_file("res://data/styles.json", _catalog)


## Un perfil con el canon medio cinetico en los dos brazos, al tope de Avanzada.
func _profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	profile.gold = 10000000
	profile.zone = 7
	profile.xp = 99999
	profile.owned.append("medio_canon_cin")
	profile.build["sides"] = ["medio_canon_cin", "medio_canon_cin"]
	profile.parts["medio_canon_cin"] = {"tier": T.EPIC, "level": 18}
	profile.prototypes["medio_canon_cin"] = {"sifon_vital": 3}
	return profile


func test_cada_arma_sigue_en_el_tipo_siguiente_con_su_forma_y_su_elemento() -> void:
	var canon := _catalog.get_item("medio_canon_cin")
	assert_eq(_catalog.successor(canon, T.LEGENDARY).id, "medio_blaster_cin")
	var blaster := _catalog.get_item("medio_blaster_cin")
	assert_eq(_catalog.successor(blaster, T.MYTHIC).id, "medio_laser_cin")
	var balas := _catalog.get_item("hoja_balas_ter")
	var next := _catalog.successor(balas, T.EPIC)
	assert_not_null(next)
	assert_eq(next.form, "hoja")
	assert_eq(next.element, balas.element)
	assert_null(_catalog.successor(_catalog.get_item("torso_baluarte"), T.EPIC), "un torso no")


func test_el_tope_de_su_tipo_ya_no_es_un_callejon() -> void:
	var profile := _profile()
	var item := _brief.resolved(profile, "medio_canon_cin")
	var key := _brief.upgrade_key(profile, item)
	assert_eq(key["action"], "evolve")
	assert_true(key["enabled"], str(key["reason"]))
	assert_string_contains(str(key["label"]), "Evolucionar")
	assert_string_contains(str(key["gain"]), _catalog.get_item("medio_blaster_cin").display_name)


func test_evolucionar_sustituye_el_arma_y_se_lleva_lo_suyo() -> void:
	var profile := _profile()
	var gold := profile.gold
	var why := profile.evolve(_workshop, _rules, _catalog, "medio_canon_cin", T.LEGENDARY)
	assert_eq(why, "")
	assert_false("medio_canon_cin" in profile.owned)
	assert_true("medio_blaster_cin" in profile.owned)
	assert_eq(profile.build["sides"], ["medio_blaster_cin", "medio_blaster_cin"], "los dos brazos")
	assert_eq(profile.parts["medio_blaster_cin"], {"tier": T.LEGENDARY, "level": 0})
	assert_false(profile.parts.has("medio_canon_cin"))
	assert_eq(profile.prototypes["medio_blaster_cin"], {"sifon_vital": 3}, "con sus prototipos")
	assert_eq(profile.gold, gold - _workshop.transform_cost(T.EPIC))


func test_no_evoluciona_antes_de_tiempo() -> void:
	var profile := _profile()
	profile.parts["medio_canon_cin"] = {"tier": T.EPIC, "level": 10}
	assert_ne(profile.evolve(_workshop, _rules, _catalog, "medio_canon_cin", T.LEGENDARY), "")
	profile.parts["medio_canon_cin"] = {"tier": T.EPIC, "level": 18}
	assert_ne(
		profile.evolve(_workshop, _rules, _catalog, "medio_canon_cin", T.EPIC),
		"",
		"la liga aun no abre Legendaria"
	)
	profile.gold = 0
	assert_ne(profile.evolve(_workshop, _rules, _catalog, "medio_canon_cin", T.LEGENDARY), "")


func test_los_drones_suben_con_el_asistente_desde_su_casilla() -> void:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	profile.legacy_assist = true
	Garage.ensure_assist(profile, _catalog)
	profile.gold = 1000000
	var drone := _brief.resolved(profile, Garage.get_slot(profile.build, "drone"))
	assert_not_null(drone)
	var key := _brief.upgrade_key(profile, drone)
	assert_false(key.is_empty(), "ya no sale vacia")
	assert_true(bool(key.get("via_assist", false)))
	assert_string_contains(str(key["gain"]), "Sube con el asistente")


func test_las_armas_del_asistente_evolucionan_cuando_el_pasa_de_su_tipo() -> void:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	profile.legacy_assist = true
	Garage.ensure_assist(profile, _catalog)
	profile.gold = 1000000
	profile.build["drone"] = "artillero_blaster_ter"
	profile.owned.append("artillero_blaster_ter")
	profile.parts[ItemDef.ASSIST_PROGRESS] = {"tier": T.MYTHIC, "level": 5}
	var drone := _brief.resolved(profile, "artillero_blaster_ter")
	assert_eq(drone.tier, T.LEGENDARY, "se quedaba en el tope de su tipo")
	var key := _brief.upgrade_key(profile, drone)
	assert_eq(key["action"], "evolve")
	assert_true(key["enabled"], str(key["reason"]))
	assert_eq(profile.evolve_with_assist(_workshop, _catalog, "artillero_blaster_ter"), "")
	var now := str(profile.build["drone"])
	assert_eq(_catalog.get_item(now).weapon_type, "laser")
	assert_eq(_brief.resolved(profile, now).tier, T.MYTHIC, "y ya sube con el asistente")


func test_el_dibujo_de_una_pieza_sigue_su_clase_si_existe() -> void:
	var torso := ItemScaling.resolve(_catalog.get_item("torso_baluarte"), _rules, T.COMMON, 0)
	assert_eq(
		MechSprites.class_set("ligero_18", torso, "torso"), "ligero_18", "en Basica, el de siempre"
	)
	var mythic := ItemScaling.resolve(_catalog.get_item("torso_baluarte"), _rules, T.MYTHIC, 0)
	var shown := MechSprites.class_set("ligero_18", mythic, "torso")
	assert_true(shown.begins_with("ligero_18"))
	if shown != "ligero_18":
		assert_true(MechSprites.has_piece(shown, "torso"), "solo uno que exista")
	assert_eq(
		MechSprites.class_set("no_existe", mythic, "torso"), "no_existe", "sin dibujo de clase"
	)


## OBS-047: diez fases, una por campeon, sacadas de la clase y el nivel.
func test_la_fase_de_una_pieza_va_con_las_ligas() -> void:
	assert_eq(ItemScaling.phase(_rules, T.COMMON, 0), 0)
	assert_eq(ItemScaling.phase(_rules, T.COMMON, 3), 0, "la liga 1 llega a Basica 3")
	assert_eq(ItemScaling.phase(_rules, T.COMMON, 4), 1)
	assert_eq(ItemScaling.phase(_rules, T.RARE, 6), 2)
	assert_eq(ItemScaling.phase(_rules, T.RARE, 12), 3)
	assert_eq(ItemScaling.phase(_rules, T.EPIC, 18), 5)
	assert_eq(ItemScaling.phase(_rules, T.LEGENDARY, 13), 7)
	assert_eq(ItemScaling.phase(_rules, T.MYTHIC, 30), 9)
	assert_eq(ItemScaling.phase(_rules, T.DIVINE, 0), 10, "la Unica")
	var campaign := Campaign.load_file("res://data/campaign.json", _library)
	for zone in campaign.zone_count():
		var tier := campaign.tier_of(zone)
		var cap := campaign.level_cap(zone)
		assert_eq(ItemScaling.phase(_rules, tier, cap), zone, "la liga %d, su fase" % (zone + 1))


## Las piernas de una pieza (orugas, ruedas, levitar) tambien cambian por fase:
## buscan `<su juego>_f<fase>` como las demas, y si no hay, el de siempre. Las
## orugas tienen sus diez fases dibujadas (art_raw/parts/fases_orugas).
func test_las_piernas_de_una_pieza_cambian_por_fase() -> void:
	var base: String = MechSprites.SPECIAL_LEGS[ItemDef.TAG_TRACKS]
	var spec := {"torso": "torso_baluarte", "legs": "piernas_orugas"}
	var basic := MechSprites.for_build(_catalog.make_build(spec, _rules, T.COMMON, 0))
	assert_eq(basic.legs_set, base, "en Basica, el de siempre")
	assert_true(basic.rigid_legs)
	var epic := _catalog.make_build(spec, _rules, T.EPIC, 18)
	var phase := ItemScaling.phase(_rules, epic.legs.tier, epic.legs.level)
	assert_gte(phase, 3)
	var shown := MechSprites.for_build(epic)
	assert_eq(shown.legs_set, "%s_f%d" % [base, phase], "el de su fase")
	assert_true(MechSprites.has_piece(shown.legs_set, "legs"))
	assert_true(shown.rigid_legs, "sigue siendo de una pieza")
	# Su miniatura del taller, la misma.
	assert_eq(MechSprites.legs_set_for(epic.legs), shown.legs_set)
	var element := int(epic.legs.element)
	assert_eq(
		MechSprites.icon_for(epic.legs),
		MechSprites.texture(shown.legs_set, "legs", element),
		"la miniatura de la pieza, igual"
	)
	# Sin dibujo de fase, el de siempre (unas piernas que andan, sin fases).
	assert_eq(MechSprites.class_set("no_existe", epic.legs, "legs"), "no_existe")
