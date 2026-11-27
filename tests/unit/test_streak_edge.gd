extends GutTest
## El plus de los rivales de la racha cuenta lo que el jugador lleva de mas
## (OBS-051, PLAN A6): arbol de mejoras, aspectos, armas de arena y, desde
## OBS-054, los prototipos del especialista.

var _rules: RulesConfig
var _catalog: Catalog
var _library: BuildLibrary
var _gear: ArenaGear
var _aspects: PieceAspects


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_gear = ArenaGear.load_file("res://data/arena_gear.json")
	_aspects = PieceAspects.load_file("res://data/aspects.json")


func _build(spec: Dictionary) -> MechBuild:
	var build := _catalog.make_build(spec, _rules, ItemDef.Tier.DIVINE, 20)
	build.skills = SkillSet.new()
	return build


func _spec() -> Dictionary:
	return _library.specs["fisico_vanguardia"]["items"].duplicate(true)


func test_los_datos() -> void:
	assert_almost_eq(_gear.boost, 1.3, 0.001)
	assert_between(_gear.rival_share, 0.1, 1.0)


func test_sin_nada_de_mas_no_suma() -> void:
	var plain := _build(_spec())
	assert_almost_eq(StreakEdge.extra(_rules, plain, _build(_spec()), _gear.boost), 0.0, 0.0001)


func test_mas_dano_y_mas_vida_suman() -> void:
	var plain := _build(_spec())
	var strong := _build(_spec())
	strong.skills.damage += 0.2
	var hit := StreakEdge.extra(_rules, plain, strong, _gear.boost)
	assert_between(hit, 0.05, 0.2, "+20 % de dano: algo menos del 20 % (solo pega mas)")
	var tough := _build(_spec())
	tough.skills.damage += 0.2
	tough.skills.health += 0.2
	assert_gt(StreakEdge.extra(_rules, plain, tough, _gear.boost), hit)


func test_los_aspectos_cuentan() -> void:
	var plain := _build(_spec())
	var full := _build(_spec())
	var levels := {}
	for def in full.sides + full.tops:
		var each := {}
		for id in _aspects.ids_for(def):
			each[id] = 10
		levels[def.progress_id()] = each
	_aspects.apply_build(full, levels)
	assert_gt(StreakEdge.extra(_rules, plain, full, _gear.boost), 0.15)


## Un arma de arena de bronce cuenta su ventaja sobre el laser; de oro, mas.
func test_las_armas_de_arena_cuentan_su_ventaja() -> void:
	var spec := _spec()
	var profile := PlayerProfile.new()
	ArenaGear.dress(_catalog, profile, spec, 1)
	var plain := _build(spec)
	var bronze := StreakEdge.extra(_rules, plain, _build(spec), _gear.boost)
	assert_gt(bronze, 0.05)
	var gold := _build(spec)
	profile.arena_gear.clear()
	for id in profile.owned:
		profile.arena_gear[id] = 3
	_gear.apply_build(gold, profile, {})
	assert_gt(StreakEdge.extra(_rules, plain, gold, _gear.boost), bronze)


## El extra multiplica la vida y el dano del rival (su ventaja es una razon):
## pesa igual con el plus del primer combate que con el del vigesimo.
func test_el_extra_multiplica_al_rival() -> void:
	var library := BuildLibrary.load_file("res://data/builds.json")
	var campaign := Campaign.load_file("res://data/campaign.json", library)
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	for edge: float in [0.0, 1.0]:
		var plain := campaign.fight_upgrades(9, shop, edge)
		var more := campaign.fight_upgrades(9, shop, edge, 0.2)
		assert_almost_eq(1.0 + more.health, (1.0 + plain.health) * 1.2, 0.0001)
		assert_almost_eq(more.damage_mult(), plain.damage_mult() * 1.2, 0.0001)
	var same := campaign.fight_upgrades(9, shop, 0.5, 0.0)
	assert_almost_eq(same.health, campaign.fight_upgrades(9, shop, 0.5).health, 0.0001)


## Los prototipos del especialista tambien son de mas (OBS-054): pegan mas,
## critican mas y curan al golpear.
func test_los_prototipos_cuentan() -> void:
	var plain := _build(_spec())
	var harder := _build(_spec())
	for def in harder.sides + harder.tops:
		def.proto_effects = {"damage": 0.2, "crit": 0.3}
	var hit := StreakEdge.extra(_rules, plain, harder, _gear.boost)
	assert_gt(hit, 0.1)
	var thief := _build(_spec())
	for def in thief.sides + thief.tops:
		def.proto_effects = {"damage": 0.2, "crit": 0.3, "lifesteal": 0.2}
	assert_gt(StreakEdge.extra(_rules, plain, thief, _gear.boost), hit, "y el robo de vida")
