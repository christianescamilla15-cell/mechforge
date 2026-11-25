extends GutTest
## El arbol de mejoras (UpgradeTree, OBS-051): la armeria es el tronco y cada
## linea a 10 abre su rama, pagada con puntos de la racha de la arena.

var _tree: UpgradeTree
var _shop: ArenaShop
var _campaign: Campaign


func before_all() -> void:
	_tree = UpgradeTree.load_file("res://data/upgrade_tree.json")
	_shop = ArenaShop.load_file("res://data/arena_shop.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	_campaign = Campaign.load_file("res://data/campaign.json", library)


func _branch(id: String) -> Dictionary:
	for branch: Dictionary in _tree.branches:
		if branch["id"] == id:
			return branch
	return {}


## Un jugador con la Potencia de la armeria a 10 y puntos de sobra.
func _ready_profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.shop_levels["damage"] = 10
	profile.upgrade_points = 100
	return profile


func test_las_once_ramas_estan_en_los_datos() -> void:
	assert_eq(_tree.errors, [] as Array[String])
	assert_eq(_tree.branches.size(), 11, "8 de la armeria y Botin, Titanes y Fortuna")
	var from := []
	for branch: Dictionary in _tree.branches:
		assert_eq((branch["steps"] as Array).size(), 5, "%s: cinco nodos" % branch["id"])
		assert_eq(
			(branch["steps"][2] as Array).size(), 2, "%s: el tercero se bifurca" % branch["id"]
		)
		if branch["from"] != "":
			assert_true(branch["from"] in _shop.track_ids(), "%s sale de la armeria" % branch["id"])
			from.append(branch["from"])
	assert_eq(from.size(), _shop.track_ids().size(), "una rama por linea de la armeria")
	var total := 0
	for cost in _tree.costs:
		total += cost
	assert_eq(total, 26, "una rama entera")


func test_cada_rama_se_abre_con_su_linea_a_10() -> void:
	var profile := PlayerProfile.new()
	profile.shop_levels["damage"] = 9
	assert_false(_tree.is_open(profile, _branch("sobrecarga")))
	assert_false(_tree.is_open(profile, _branch("botin")), "las de arena, con alguna a 10")
	profile.shop_levels["damage"] = 10
	assert_true(_tree.is_open(profile, _branch("sobrecarga")))
	assert_false(_tree.is_open(profile, _branch("reactor")), "la de energia, con la energia")
	assert_true(_tree.is_open(profile, _branch("botin")))
	profile.upgrade_points = 100
	assert_ne(_tree.why_cant_learn(profile, "reactor_1"), "", "cerrada no se aprende")


func test_se_aprende_en_orden_y_gasta_sus_puntos() -> void:
	var profile := _ready_profile()
	assert_eq(_tree.why_cant_learn(profile, "sobrecarga_2"), "antes, la anterior de la rama")
	assert_eq(_tree.learn(profile, "sobrecarga_1"), "")
	assert_eq(profile.upgrade_points, 100 - _tree.costs[0])
	assert_eq(_tree.learn(profile, "sobrecarga_2"), "")
	assert_eq(profile.upgrade_points, 100 - _tree.costs[0] - _tree.costs[1])
	assert_eq(_tree.why_cant_learn(profile, "sobrecarga_1"), "ya la tienes")
	profile.upgrade_points = 1
	var poor := PlayerProfile.new()
	poor.shop_levels["damage"] = 10
	assert_eq(_tree.why_cant_learn(poor, "sobrecarga_1"), "faltan puntos de mejora")


## La bifurcacion: se elige una de las dos y la otra queda cerrada. Una cuyo
## efecto aun no aplica el juego (la forja) se ve pero no se aprende.
func test_la_bifurcacion_es_una_de_dos() -> void:
	var profile := _ready_profile()
	profile.shop_levels["health"] = 10
	for id: String in ["coraza_1", "coraza_2"]:
		assert_eq(_tree.learn(profile, id), "")
	assert_eq(_tree.learn(profile, "regeneracion"), "")
	assert_eq(_tree.why_cant_learn(profile, "bastion"), "elegiste la otra")
	assert_false(_tree.is_ready("forja_1"), "la forja llega con las armas de la arena")
	assert_true(_tree.is_ready("sobrecarga_1"))
	# Botin: sus dos caminos ya funcionan.
	for id: String in ["botin_1", "botin_2"]:
		assert_eq(_tree.learn(profile, id), "")
	assert_eq(_tree.learn(profile, "puntos_extra"), "")
	assert_eq(_tree.why_cant_learn(profile, "botin_campana"), "elegiste la otra")
	assert_eq(_tree.why_cant_learn(profile, "botin_4"), "", "y la rama sigue")


func test_los_efectos_se_suman() -> void:
	var grown := _tree.effects_for(["sobrecarga_1", "sobrecarga_2", "botin_1"] as Array[String])
	assert_almost_eq(float(grown["damage"]), 0.06, 0.0001)
	assert_almost_eq(float(grown["arena_gold"]), 0.25, 0.0001)
	assert_eq(_tree.effects_for([] as Array[String]), {})
	# Lo de las habilidades entra en el robot como cualquier habilidad.
	var skills := SkillSet.new()
	skills.add(grown)
	assert_almost_eq(skills.damage, 0.06, 0.0001)


## Rama Botin: mas celdas y mas puntos en la racha, mas experiencia en la arena
## y mas celdas en la campana.
func test_botin_sube_los_premios() -> void:
	var plain := PlayerProfile.new()
	plain.zone = _campaign.zone_count() - 1
	var rich := PlayerProfile.new()
	rich.zone = plain.zone
	var bonus := {"arena_gold": 0.5, "arena_points": 1.0, "arena_xp": 0.5}
	var progression := Progression.load_file("res://data/progression.json")
	var a := _campaign.finish_fight(plain, _shop, "arena", true, progression)
	var b := _campaign.finish_fight(rich, _shop, "arena", true, progression, bonus)
	assert_eq(b["prize"], roundi(a["prize"] * 1.5))
	assert_eq(b["points"], a["points"] * 2)
	assert_eq(b["xp"], roundi(a["xp"] * 1.5))


func test_el_arbol_se_guarda_con_la_partida() -> void:
	var profile := _ready_profile()
	_tree.learn(profile, "sobrecarga_1")
	var copy := PlayerProfile.from_dict(profile.to_dict())
	assert_eq(copy.tree, ["sobrecarga_1"] as Array[String])
	assert_eq(copy.upgrade_points, profile.upgrade_points)
	profile.end_run()
	assert_eq(profile.tree.size(), 0, "perder la partida lo pierde")


## Todas las especializaciones de las ramas de la armeria y de Botin y
## Titanes ya funcionan en combate; solo Forja y Fortuna esperan a las armas
## de la arena (A5).
func test_solo_forja_y_fortuna_esperan() -> void:
	for branch: Dictionary in _tree.branches:
		var waits: bool = branch["id"] in ["forja", "fortuna"]
		for step: Array in branch["steps"]:
			for node: Dictionary in step:
				var effects: Dictionary = node["effects"]
				var later := effects.keys().any(
					func(e: String) -> bool:
						return e.begins_with("forge") or e.begins_with("fortune")
				)
				assert_eq(_tree.is_ready(node["id"]), not later, node["id"])
				if not waits:
					assert_true(_tree.is_ready(node["id"]), node["id"])
