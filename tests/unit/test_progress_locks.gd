extends GutTest
## Bloqueos de la progresion (pedido del usuario, 2026-11-18): con dinero de
## sobra no se compra por adelantado lo que se abre al vencer jefes y subir
## de nivel. Una partida nueva en la zona 1 con 100 000 celdas intenta
## comprar todo lo que vende la tienda, subir cada pieza, transformarla y
## llenar la armeria; nada pasa de los topes de la zona.

var _catalog: Catalog
var _library: BuildLibrary
var _campaign: Campaign
var _rules: RulesConfig
var _garage: Garage
var _workshop: Workshop
var _shop: ArenaShop
var _progression: Progression


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_campaign = Campaign.load_file("res://data/campaign.json", _library)
	_rules = RulesConfig.new()
	_garage = Garage.load_file("res://data/part_shop.json")
	_workshop = Workshop.load_file("res://data/workshop.json")
	_shop = ArenaShop.load_file("res://data/arena_shop.json")
	_progression = Progression.load_file("res://data/progression.json")


## Gasta todo lo que deje la zona, en el orden en que lo haria un jugador con
## prisa: comprar, subir, transformar y la armeria, hasta que nada cambie.
func _spend_everything(profile: PlayerProfile, zone: int) -> void:
	var tier := _campaign.tier_of(zone)
	var cap := _campaign.level_cap(zone)
	var armory_cap := _campaign.armory_cap(zone, _shop)
	for id in _garage.stock_for(_catalog, tier):
		_garage.buy(profile, _catalog, _rules, _workshop, id, tier)
	var changed := true
	while changed:
		changed = false
		for id: String in profile.owned:
			var def := _catalog.get_item(id)
			var key := def.progress_id()
			if profile.level_up(_workshop, _rules, key, tier, cap) == "":
				changed = true
			elif profile.transform(_workshop, _rules, key, tier, def.tier_max) == "":
				changed = true
		for track in _shop.track_ids():
			if profile.buy(_shop, track, armory_cap) == "":
				changed = true


func _new_run(gold: int) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_run(_library, _library.starter_ids()[0])
	Garage.ensure_assist(profile, _catalog)
	profile.gold = gold
	return profile


func test_con_100000_celdas_la_zona_1_no_deja_pasar_de_sus_topes() -> void:
	var profile := _new_run(100000)
	_spend_everything(profile, 0)
	var cap := _campaign.level_cap(0)
	for key: String in profile.parts:
		var p: Dictionary = profile.parts[key]
		assert_eq(p["tier"], ItemDef.Tier.COMMON, "%s sigue en Basica" % key)
		assert_lte(p["level"], cap, "%s no pasa del nivel %d" % [key, cap])
	for track in _shop.track_ids():
		assert_lte(profile.level_of(track), _campaign.armory_cap(0, _shop), "armeria: %s" % track)
	# Sobra dinero: lo que para cada compra es un tope, nunca el precio.
	assert_gt(profile.gold, 0)
	var armory_cap := _campaign.armory_cap(0, _shop)
	for track in _shop.track_ids():
		assert_ne(profile.why_cant_buy(_shop, track, armory_cap), "faltan celdas", track)
	for id: String in profile.owned:
		var key := _catalog.get_item(id).progress_id()
		var reason := profile.why_cant_level(_workshop, _rules, key, ItemDef.Tier.COMMON, cap)
		assert_ne(reason, "faltan celdas", key)


func test_la_zona_1_no_vende_armas_de_pecho_ni_piezas_de_otra_clase() -> void:
	for id in _garage.stock_for(_catalog, _campaign.tier_of(0)):
		var def := _catalog.get_item(id)
		assert_ne(def.type, ItemDef.Type.CHEST, "%s es de pecho" % id)
		assert_lte(def.tier_min, ItemDef.Tier.COMMON, id)


func test_el_pecho_y_el_soporte_se_abren_por_nivel_del_jugador() -> void:
	assert_false(_progression.is_unlocked("chest", 1))
	assert_false(_progression.is_unlocked("chest", 9))
	assert_true(_progression.is_unlocked("chest", 10))
	assert_false(_progression.is_unlocked("drone", 4))
	assert_true(_progression.is_unlocked("drone", 5))


func test_sin_nucleo_de_jefe_no_hay_piezas_unicas() -> void:
	var profile := _new_run(10000000)
	for zone in _campaign.zone_count():
		profile.zone = zone
		_spend_everything(profile, zone)
	assert_eq(profile.unique_cores, 0)
	for key: String in profile.parts:
		assert_lt(profile.parts[key]["tier"], ItemDef.Tier.DIVINE, "%s no llega a Unica" % key)


func test_el_tope_de_la_armeria_crece_con_las_zonas_y_acaba_completo() -> void:
	assert_lt(_campaign.armory_cap(0, _shop), _shop.max_level(), "la zona 1 no deja llenarla")
	for zone in range(1, _campaign.zone_count()):
		assert_gte(
			_campaign.armory_cap(zone, _shop), _campaign.armory_cap(zone - 1, _shop), "no baja"
		)
	assert_eq(_campaign.armory_cap(_campaign.zone_count() - 1, _shop), _shop.max_level())
	assert_eq(_campaign.armory_cap(2, _shop), _shop.max_level(), "completa desde la zona 3")


func test_la_armeria_dice_por_que_no_sube_mas() -> void:
	var profile := _new_run(100000)
	profile.shop_levels["damage"] = 7
	assert_eq(profile.buy(_shop, "damage", 7), "la zona no deja subirla mas")
	assert_eq(profile.level_of("damage"), 7)
	assert_eq(profile.buy(_shop, "damage", 9), "")
