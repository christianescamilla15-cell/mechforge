extends GutTest
## Las armas especiales de los campeones (GDD 9.4, del usuario: "mi robot
## conserva su estilo, salvo las armas especiales de cada jefe: esas si las
## puedo comprar, pero por un alto coste"). El campeon la lleva en su combate;
## no esta en la tienda hasta vencerlo, y entonces cuesta mucho mas.

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _brief: WorkshopBrief


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_brief = WorkshopBrief.new()
	_brief.rules = _rules
	_brief.catalog = _catalog
	_brief.library = _library
	_brief.campaign = Campaign.load_file("res://data/campaign.json", _library)
	_brief.workshop = Workshop.load_file("res://data/workshop.json")
	_brief.garage = Garage.load_file("res://data/part_shop.json")
	_brief.shop = ArenaShop.load_file("res://data/arena_shop.json")
	_brief.skills = SkillTree.load_file("res://data/skills.json")
	_brief.progression = Progression.load_file("res://data/progression.json")
	_brief.styles = StyleLibrary.load_file("res://data/styles.json", _catalog)


func _profile(zone: int) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, "calor_horno")
	profile.zone = zone
	profile.xp = 99999
	profile.gold = 10000000
	return profile


func _sold(state: Dictionary, id: String) -> Dictionary:
	for part: Dictionary in state["parts"]:
		if str(part["id"]) == id and not bool(part["owned"]):
			return part
	return {}


func test_el_campeon_de_la_liga_5_tiene_su_arma_y_la_lleva() -> void:
	var def := _catalog.get_item("pecho_centella")
	assert_not_null(def)
	assert_eq(def.type, ItemDef.Type.CHEST)
	assert_true(def.has_tag(ItemDef.TAG_BOSS))
	assert_eq(_brief.campaign.boss_weapon(4), "pecho_centella")
	var boss := _library.make("jefe_zona_5", _catalog, _rules, ItemDef.Tier.EPIC, 9)
	assert_not_null(boss.chest)
	assert_eq(boss.chest.id, "pecho_centella")


func test_no_esta_en_la_tienda_normal() -> void:
	for tier in ItemDef.Tier.values():
		for id in _brief.garage.stock_for(_catalog, tier):
			assert_false(_catalog.get_item(id).has_tag(ItemDef.TAG_BOSS), id)


func test_se_abre_al_vencer_a_su_campeon_y_cuesta_mucho_mas() -> void:
	assert_eq(_brief.campaign.boss_weapons_open(_profile(4)), [] as Array[String])
	assert_true(_sold(_brief.rack(_profile(4), "chest"), "pecho_centella").is_empty())
	var after := _profile(5)
	assert_eq(_brief.campaign.boss_weapons_open(after), ["pecho_centella"] as Array[String])
	var part := _sold(_brief.rack(after, "chest"), "pecho_centella")
	assert_false(part.is_empty(), "tras vencerlo se puede comprar")
	var normal := _sold(_brief.rack(after, "chest"), "canon_pesado_blaster_ion")
	assert_false(normal.is_empty())
	var tier := _brief.zone_tier(after)
	var plain := roundi(1000 * _rules.tier_mult[tier])
	var extra := int(part["price"]) - int(normal["price"])
	assert_eq(extra, plain * (_brief.garage.boss_weapon_mult - 1), "su tipo, por diez")
	assert_eq(_brief.garage.boss_weapon_mult, 10)


func test_sin_dibujo_propio_usa_el_de_todas_las_armas_de_pecho() -> void:
	var def := _catalog.get_item("pecho_centella")
	assert_eq(str(def.art.get("set", "")), "jefe5_centella")
	var expected := (
		"jefe5_centella" if MechSprites.has_piece("jefe5_centella", "chest") else MechView.CHEST_SET
	)
	assert_eq(MechSprites.chest_set(def), expected)
	assert_eq(MechSprites.chest_set(_catalog.get_item("nova_blaster_ion")), MechView.CHEST_SET)
	assert_eq(MechSprites.chest_set(null), MechView.CHEST_SET)
