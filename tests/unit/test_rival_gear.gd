extends GutTest
## De donde sale la fuerza del rival (OBS-057): su kit (una parte de las
## mejoras del jugador) y las mejoras de campo.

var _rules := RulesConfig.new()
var _catalog: Catalog
var _library: BuildLibrary
var _gear: RivalGear
var _field: FieldUpgrades


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	_gear = RivalGear.load_file("res://data/rival_gear.json")
	_gear.rules = _rules
	_gear.catalog = _catalog
	_gear.shop = ArenaShop.load_file("res://data/arena_shop.json")
	_gear.aspects = PieceAspects.load_file("res://data/aspects.json")
	_gear.prototypes = PrototypeLibrary.load_file("res://data/prototypes.json")
	_gear.gear = ArenaGear.load_file("res://data/arena_gear.json")
	_gear.tree = UpgradeTree.load_file("res://data/upgrade_tree.json")
	_gear.skill_tree = SkillTree.load_file("res://data/skills.json")
	_field = FieldUpgrades.load_file("res://data/field_upgrades.json")


## Un jugador con todo: armeria 10, aspectos 10, prototipos V, armas de oro,
## 20 nodos del arbol y 30 habilidades.
func _player() -> PlayerProfile:
	var profile := PlayerProfile.new()
	for track in _gear.shop.track_ids():
		profile.shop_levels[track] = 10
	profile.aspects["arma"] = {"potencia": 10, "filo": 10}
	profile.prototypes["arma"] = {"percutor": 5, "sobrecarga": 5}
	profile.arena_gear["arena_lanza_cin"] = 3
	for i in 20:
		profile.tree.append("nodo_%d" % i)
	profile.skills.assign(_gear.skill_tree.spread(30))
	return profile


func _rival() -> MechBuild:
	var build := _library.make("calor_horno_laser", _catalog, _rules, ItemDef.Tier.DIVINE, 30)
	build.skills = SkillSet.new()
	return build


func test_los_datos() -> void:
	assert_eq(_gear.errors, [] as Array[String])
	assert_eq(_field.errors, [] as Array[String])
	# La parte crece en la racha y, en los combates de tres robots seguidos
	# (OBS-058), vuelve a crecer desde mas abajo.
	for start: int in [0, 15]:
		var before := -1.0
		for step in range(start, 15 if start == 0 else 20):
			assert_gte(_gear.share_for_streak(step), before, "combate %d" % (step + 1))
			before = _gear.share_for_streak(step)
	assert_lt(_gear.share_for_streak(15), _gear.share_for_streak(14))
	assert_lte(_gear.share_for_wave(500), _gear.wave_max)
	assert_eq(_field.for_wave(0), 0)
	assert_gt(_field.for_wave(30), _field.for_wave(10), "y las de campo, sin final")


## El kit es una parte de lo que lleva el jugador, nunca menos que la
## armeria de la zona.
func test_el_kit_es_una_parte_de_tus_mejoras() -> void:
	var kit := _gear.kit(_player(), 0.4, 0)
	for track: String in kit["armory"]:
		assert_eq(int(kit["armory"][track]), 4, track)
	assert_eq(int(kit["aspects"]), 4)
	assert_eq(kit["prototypes"], {"percutor": 2, "sobrecarga": 2})
	assert_eq(int(kit["arena"]), 1)
	assert_eq((kit["tree"] as Array).size(), 8)
	assert_eq((kit["skills"] as Array).size(), 12)
	var nothing := _gear.kit(_player(), 0.0, 3)
	assert_eq(int(nothing["armory"].values()[0]), 3, "la armeria de la zona, siempre")
	assert_eq(int(nothing["arena"]), 0)


## Vestido con su kit: sus armas de arena, sus prototipos, sus aspectos y
## su entrenamiento se ven en sus piezas.
func test_el_kit_se_ve_en_sus_piezas() -> void:
	var plain := _rival()
	var dressed := _rival()
	_gear.dress(dressed, _gear.kit(_player(), 1.0, 0))
	var arena := 0
	for def in dressed.sides + dressed.tops:
		if def != null and def.has_tag(ItemDef.TAG_ARENA):
			arena += 1
			assert_eq(def.arena_rank, 3)
	assert_gt(arena, 0, "sus armas pasan a ser de arena")
	var weapon: ItemDef = dressed.sides[0]
	assert_almost_eq(float(weapon.proto_effects.get("crit", 0.0)), 0.3, 0.001, "percutor V")
	assert_gt(dressed.skills.health, plain.skills.health, "y su entrenamiento")


## El monitor ensena lo mismo que sale: con la misma semilla, las mismas
## mejoras de campo.
func test_el_rival_que_se_ve_es_el_que_sale() -> void:
	var fight := {"streak": 25, "wave": 25, "robot": 0, "skills": 14}
	var a := _gear.outfit(_rival(), fight, _player(), 0, _field, 77)
	var b := _gear.outfit(_rival(), fight, _player(), 0, _field, 77)
	assert_eq(a["field"], b["field"])
	assert_eq((a["field"] as Array).size(), _field.for_wave(25))


func test_las_mejoras_de_campo() -> void:
	var build := _rival()
	var weapon: ItemDef = build.sides[0]
	var picks := [
		{"id": "plates", "slot": ""},
		{"id": "shield", "slot": ""},
		{"id": "tuned", "slot": "side0"},
		{"id": "striker", "slot": "side0"},
		{"id": "ammo", "slot": "side0"},
	]
	var copy: MechBuild = build.duplicate()
	_field.apply(copy, picks)
	assert_almost_eq(copy.skills.health, 0.15, 0.0001)
	assert_eq(copy.skills.shield_uses, 1)
	var tuned: ItemDef = copy.sides[0]
	assert_eq(tuned.dmg_max, roundi(weapon.dmg_max * 1.15))
	assert_almost_eq(float(tuned.proto_effects["crit"]), 0.1, 0.0001)
	assert_almost_eq(float(tuned.proto_effects["state_bonus"]), 1.0, 0.0001)
	assert_eq(build.sides[0], weapon, "no toca el robot del que se copio")
	assert_eq(build.skills.health, 0.0)


func test_se_sortean_sobre_sus_armas() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var build := _rival()
	var picks := _field.draw(build, 12, rng)
	assert_eq(picks.size(), 12)
	var slots := FieldUpgrades.weapon_slots(build)
	for pick in picks:
		if str(_field.kinds[pick["id"]]["on"]) == "weapon":
			assert_true(str(pick["slot"]) in slots)
		else:
			assert_eq(str(pick["slot"]), "")


## La municion especial deja dos cargas por golpe.
func test_la_municion_especial() -> void:
	var states := StateConfig.from_dict(
		{"burn": {"element": "HEAT", "turns": 2, "max": 3, "heat": 0.05}, "modes": ["arena"]}
	)
	var gun := Fx.gun({"element": ItemDef.Element.HEAT})
	gun.proto_effects = {"state_bonus": 1.0}
	var e := Fx.engine(Fx.build([gun]), Fx.build())
	e.extra_rules.append(states)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(StateConfig.stacks(e.mechs[1], "burn"), 2)


## Las del jugador en el Exterminio: le duran la oleada, se guardan y se
## borran al acabarla o al perder.
func test_las_tuyas_duran_la_oleada() -> void:
	var campaign := Campaign.load_file("res://data/campaign.json", _library)
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var profile := PlayerProfile.new()
	profile.zone = campaign.zone_count() - 1
	profile.exterminio_field.append({"id": "plates", "slot": ""})
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(copy.exterminio_field.size(), 1)
	profile.exterminio_robot = campaign.exterminio_robots() - 1
	campaign.finish_fight(profile, shop, "exterminio", true)
	assert_eq(profile.exterminio_field.size(), 0, "al pasar la oleada")
	profile.exterminio_field.append({"id": "plates", "slot": ""})
	campaign.finish_fight(profile, shop, "exterminio", false)
	assert_eq(profile.exterminio_field.size(), 0, "al perder")
