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
