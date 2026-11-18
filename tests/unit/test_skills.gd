extends GutTest
## Arbol de habilidades (decisiones del usuario, 2026-11-17): 1 punto por
## nivel, tres ramas libres que se aprenden en orden; escudo de energia, kit de
## reparacion y materia oscura (nivel 25, 60 % de la vida maxima del rival).

var _tree: SkillTree


func before_all() -> void:
	_tree = SkillTree.load_file("res://data/skills.json")


func _skills(props: Dictionary) -> SkillSet:
	var out := SkillSet.new()
	for key: String in props:
		out.set(key, props[key])
	return out


func _chest(props: Dictionary = {}) -> ItemDef:
	var base := {"weight": 60, "dmg_min": 100, "dmg_max": 100, "uses": 2}
	base.merge(props, true)
	return Fx.item(ItemDef.Type.CHEST, base)


func test_el_arbol_del_juego_carga_sin_errores() -> void:
	assert_eq(_tree.errors, [] as Array[String])
	assert_eq(_tree.branches.size(), 3)
	var names := _tree.branches.map(func(b: Dictionary) -> String: return b["name"])
	assert_eq(names, ["Asalto", "Blindaje", "Sistemas"])
	for branch in _tree.branches:
		assert_eq((branch["nodes"] as Array).size(), 12)


func test_cada_nivel_da_un_punto() -> void:
	var profile := PlayerProfile.new()
	assert_eq(_tree.points_left(profile, 1), 0)
	assert_eq(_tree.points_left(profile, 5), 4)
	profile.skills.append("asalto_1")
	assert_eq(_tree.points_left(profile, 5), 3)


func test_cada_rama_se_aprende_en_orden() -> void:
	var profile := PlayerProfile.new()
	assert_eq(
		_tree.why_cant_learn(profile, "asalto_2", 10),
		"antes hay que aprender las anteriores de la rama"
	)
	assert_eq(_tree.learn(profile, "asalto_1", 10), "")
	assert_eq(_tree.learn(profile, "asalto_2", 10), "")
	assert_eq(_tree.learn(profile, "blindaje_1", 10), "", "las ramas son libres")
	assert_eq(_tree.learn(profile, "asalto_1", 10), "ya la tienes")
	assert_eq(_tree.learn(profile, "no_existe", 10), "esa habilidad no existe")


func test_sin_puntos_no_se_aprende() -> void:
	var profile := PlayerProfile.new()
	assert_eq(_tree.learn(profile, "asalto_1", 2), "")
	assert_eq(_tree.learn(profile, "asalto_2", 2), "no quedan puntos")


func test_la_materia_oscura_se_abre_en_el_nivel_25() -> void:
	var profile := PlayerProfile.new()
	for i in range(1, 12):
		profile.skills.append("asalto_%d" % i)
	assert_eq(_tree.why_cant_learn(profile, "materia_oscura", 24), "se abre en el nivel 25")
	assert_eq(_tree.learn(profile, "materia_oscura", 25), "")
	var effects := _tree.effects_for(profile.skills)
	assert_eq(effects.dark_matter_uses, 1)
	assert_almost_eq(effects.dark_matter_share, 0.6, 0.0001)


func test_repartir_puntos_va_rama_por_rama() -> void:
	var expected: Array[String] = ["asalto_1", "blindaje_1", "sistemas_1", "asalto_2"]
	assert_eq(_tree.spread(4), expected)
	assert_eq(_tree.spread(0), [] as Array[String])
	var learned := _tree.spread(18)
	assert_eq(learned.size(), 18)
	assert_true("escudo" in learned, "seis de Blindaje dan el escudo")
	assert_true("reparacion" in learned, "cinco de Sistemas dan la reparacion")


func test_las_habilidades_suman_sus_efectos() -> void:
	var learned: Array[String] = ["asalto_1", "asalto_2", "asalto_3", "asalto_4"]
	learned.append_array(["sistemas_1", "sistemas_2", "sistemas_3", "sistemas_4", "reparacion"])
	var effects := _tree.effects_for(learned)
	assert_almost_eq(effects.damage, 0.06, 0.0001)
	assert_almost_eq(effects.chest_damage, 0.15, 0.0001)
	assert_eq(effects.chest_uses, 1)
	assert_almost_eq(effects.energy, 0.08, 0.0001)
	assert_eq(effects.repair_uses, 1)
	assert_almost_eq(effects.repair_share, 0.2, 0.0001)


func test_las_pasivas_cambian_las_estadisticas() -> void:
	var r := Fx.rules()
	var build := Fx.build([Fx.gun()])
	build.torso = Fx.torso({"res_physical": 20})
	var plain := build.summary(r)
	build.skills = _skills({"health": 0.1, "resistance": 0.5})
	var boosted := build.summary(r)
	assert_eq(boosted["health"], roundi(plain["health"] * 1.1))
	assert_eq(boosted["res_physical"], 30)


func test_el_escudo_absorbe_el_siguiente_golpe_aunque_pasen_turnos() -> void:
	var player := Fx.build([Fx.gun()])
	player.skills = _skills({"shield_uses": 1})
	var e := Fx.engine(player, Fx.build([Fx.gun()]))
	assert_eq(e.apply(BattleAction.shield()), "")
	assert_eq(e.mechs[0].barrier, 1)
	assert_ne(e.why_illegal(BattleAction.shield()), "", "solo tenia uno")
	Fx.pass_turn(e)
	assert_eq(e.turn, 1)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].health, e.mechs[0].max_health, "el golpe choca con el escudo")
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].health, e.mechs[0].max_health, "un arma no repite en el turno")
	Fx.pass_turn(e)
	Fx.pass_turn(e)
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[0].health, e.mechs[0].max_health - 100, "el escudo ya se gasto")


func test_la_reparacion_cura_una_parte_y_no_pasa_del_maximo() -> void:
	var player := Fx.build([Fx.gun()])
	player.skills = _skills({"repair_uses": 2, "repair_share": 0.2})
	var e := Fx.engine(player, Fx.build())
	assert_ne(e.why_illegal(BattleAction.repair()), "", "sin danos no repara")
	e.mechs[0].health = 500
	assert_eq(e.apply(BattleAction.repair()), "")
	assert_eq(e.mechs[0].health, 700)
	e.mechs[0].health = 950
	assert_eq(e.apply(BattleAction.repair()), "")
	assert_eq(e.mechs[0].health, 1000)
	assert_eq(e.mechs[0].kits_left("repair"), 0)


func test_la_materia_oscura_quita_el_60_por_ciento_sin_resistencias_ni_escudos() -> void:
	var player := Fx.build([Fx.gun()])
	player.chest = _chest()
	player.skills = _skills({"dark_matter_uses": 1, "dark_matter_share": 0.6})
	var foe := Fx.build()
	foe.torso = Fx.torso({"res_physical": 80})
	var e := Fx.engine(player, foe)
	assert_eq(e.why_illegal(BattleAction.dark_matter()), "el arma de pecho aun no se ha desplegado")
	e.apply(BattleAction.weapon("chest"))
	e.mechs[1].barrier = 1
	var before: int = e.mechs[1].health
	assert_eq(e.preview(BattleAction.dark_matter())["dmg_min"], 600)
	assert_eq(e.apply(BattleAction.dark_matter()), "")
	assert_eq(before - e.mechs[1].health, 600, "atraviesa resistencias y escudos")
	assert_eq(e.mechs[0].energy, 0, "gasta toda la energia")
	assert_eq(e.mechs[0].kits_left("dark_matter"), 0, "una vez por combate")


func test_el_pecho_mejorado_pega_mas_y_tiene_mas_usos() -> void:
	var player := Fx.build([Fx.gun()])
	player.chest = _chest()
	player.skills = _skills({"chest_damage": 0.5, "chest_uses": 1})
	var e := Fx.engine(player, Fx.build())
	assert_eq(e.mechs[0].slots["chest"].uses_left, 3)
	e.apply(BattleAction.weapon("chest"))
	assert_eq(e.mechs[1].health, e.mechs[1].max_health - 150)


func test_un_combate_con_habilidades_termina() -> void:
	var rules := RulesConfig.new()
	var catalog := Catalog.load_file("res://data/catalog.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	var items: Dictionary = library.specs["fisico_vanguardia_laser"]["items"].duplicate(true)
	items["chest"] = "canon_pesado_laser_cin"
	var player := catalog.make_build(items, rules, ItemDef.Tier.EPIC, 10)
	var learned: Array[String] = []
	for branch in _tree.branches:
		for node: Dictionary in branch["nodes"]:
			learned.append(node["id"])
	player.skills = _tree.effects_for(learned)
	var foe := library.make("calor_horno_laser", catalog, rules, ItemDef.Tier.EPIC, 10)
	var result := BattleRunner.run(
		rules,
		player,
		foe,
		BattleAI.new(BattleAI.Difficulty.NORMAL, 1),
		BattleAI.new(BattleAI.Difficulty.NORMAL, 2),
		3,
		0
	)
	assert_gte(int(result["winner"]), 0)


func test_las_habilidades_se_guardan_y_se_pierden_con_la_partida() -> void:
	var profile := PlayerProfile.new()
	profile.skills.append_array(["asalto_1", "blindaje_1"])
	var path := "user://test_profile_habilidades.json"
	assert_true(profile.save(path))
	assert_eq(PlayerProfile.load_or_new(path).skills, ["asalto_1", "blindaje_1"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.end_run()
	assert_true(profile.skills.is_empty())
	var old := PlayerProfile.from_dict({"schema_version": 5, "xp": 300})
	assert_true(old.skills.is_empty())
	assert_eq(old.to_dict()["schema_version"], PlayerProfile.SCHEMA_VERSION)
