extends GutTest
## Los tipos de robot con los que se empieza (decision del usuario,
## 2026-11-20, OBS-026): tres, con su historia y su manera de pelear; todos
## empiezan con el cuerpo y una sola arma, y el tipo dice que armas caben en
## sus brazos. El robot de asistencia ya no se regala: se compra (OBS-013).

const T := ItemDef.Tier

var _rules: RulesConfig
var _catalog: Catalog
var _styles: StyleLibrary
var _workshop: Workshop
var _garage: Garage
var _progression: Progression
var _brief: WorkshopBrief


func before_all() -> void:
	_rules = RulesConfig.new()
	_catalog = Catalog.load_file("res://data/catalog.json")
	_styles = StyleLibrary.load_file("res://data/styles.json", _catalog)
	_workshop = Workshop.load_file("res://data/workshop.json")
	_garage = Garage.load_file("res://data/part_shop.json")
	_progression = Progression.load_file("res://data/progression.json")
	var library := BuildLibrary.load_file("res://data/builds.json")
	_brief = WorkshopBrief.new()
	_brief.rules = _rules
	_brief.catalog = _catalog
	_brief.library = library
	_brief.campaign = Campaign.load_file("res://data/campaign.json", library)
	_brief.workshop = _workshop
	_brief.garage = _garage
	_brief.shop = ArenaShop.load_file("res://data/arena_shop.json")
	_brief.skills = SkillTree.load_file("res://data/skills.json")
	_brief.progression = _progression
	_brief.styles = _styles


func _run(style_id: String, gold: int = 0) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.start_style(_styles, style_id)
	profile.gold = gold
	return profile


func test_los_datos_cargan_sin_errores_y_son_tres_tipos() -> void:
	assert_eq(_styles.errors, [] as Array[String])
	assert_eq(_styles.ids(), ["asalto", "guardian", "tirador"] as Array[String])
	for id in _styles.ids():
		assert_ne(_styles.display_name(id), "")
		assert_ne(_styles.role(id), "")
		assert_ne(_styles.story(id), "")
		assert_ne(_styles.mechanic(id), "")


func test_todos_empiezan_con_el_cuerpo_y_una_sola_arma() -> void:
	for id in _styles.ids():
		var profile := _run(id)
		assert_eq(profile.mechs.size(), 1)
		assert_eq(profile.style, id)
		assert_eq(profile.mechs[0]["name"], _styles.display_name(id))
		var build := _catalog.make_build(profile.build, _rules, T.COMMON, 0)
		assert_eq(build.validate(_rules), [] as Array[String], "%s puede pelear" % id)
		var weapons := 0
		for item in build.sides + build.tops:
			if item != null:
				weapons += 1
		assert_eq(weapons, 1, "%s: una sola arma" % id)
		assert_eq(build.modules.size(), 0, "%s: sin modulos" % id)
		assert_null(build.drone, "%s: sin asistente" % id)
		assert_null(build.assist)
		assert_null(build.charge)
		assert_eq(profile.owned.size(), 3, "torso, piernas y su arma")
		assert_eq(profile.gold, 0)


func test_cada_tipo_empieza_con_un_cuerpo_y_un_arma_distintos() -> void:
	var seen := {}
	for id in _styles.ids():
		var spec := _styles.build(id)
		for key: String in ["torso", "legs"]:
			assert_false(seen.has(spec[key]), "%s repite %s" % [id, spec[key]])
			seen[spec[key]] = true
		var weapon: String = spec["sides"][0]
		assert_false(seen.has(_catalog.get_item(weapon).form), "%s repite forma de arma" % id)
		seen[_catalog.get_item(weapon).form] = true


func test_el_tipo_dice_que_armas_caben_en_los_brazos() -> void:
	var blade := _catalog.get_item("hoja_balas_cin")
	var shotgun := _catalog.get_item("corto_balas_cin")
	var gun := _catalog.get_item("medio_balas_cin")
	var rifle := _catalog.get_item("largo_balas_cin")
	assert_eq(_styles.why_cant_mount("asalto", blade), "")
	assert_eq(_styles.why_cant_mount("asalto", shotgun), "")
	assert_ne(_styles.why_cant_mount("asalto", gun), "")
	assert_ne(_styles.why_cant_mount("asalto", rifle), "")
	assert_eq(_styles.why_cant_mount("guardian", gun), "")
	assert_eq(_styles.why_cant_mount("guardian", shotgun), "")
	assert_ne(_styles.why_cant_mount("guardian", blade), "")
	assert_ne(_styles.why_cant_mount("guardian", rifle), "")
	assert_eq(_styles.why_cant_mount("tirador", rifle), "")
	assert_eq(_styles.why_cant_mount("tirador", gun), "")
	assert_ne(_styles.why_cant_mount("tirador", shotgun), "")
	assert_ne(_styles.why_cant_mount("tirador", blade), "")
	# Arriba, el cuerpo y los modulos: lo que sea, en cualquier tipo.
	for id in _styles.ids():
		assert_eq(_styles.why_cant_mount(id, _catalog.get_item("bateria_balas_cin")), "")
		assert_eq(_styles.why_cant_mount(id, _catalog.get_item("torso_baluarte")), "")
		assert_eq(_styles.why_cant_mount(id, _catalog.get_item("mod_blindaje")), "")
	# Un robot sin tipo (los de antes) monta todo.
	assert_eq(_styles.why_cant_mount("", rifle), "")


func test_el_taller_no_deja_montar_lo_que_el_tipo_no_lleva() -> void:
	var profile := _run("asalto")
	profile.owned.append("largo_balas_cin")
	profile.owned.append("corto_balas_cin")
	var why := Garage.equip(profile, _catalog, "side1", "largo_balas_cin", _styles)
	assert_string_contains(why, "asalto")
	assert_eq(Garage.get_slot(profile.build, "side1"), "")
	assert_eq(Garage.equip(profile, _catalog, "side1", "corto_balas_cin", _styles), "")
	assert_eq(Garage.get_slot(profile.build, "side1"), "corto_balas_cin")


func test_el_tablero_solo_cuelga_lo_que_le_cabe_a_ese_robot() -> void:
	var profile := _run("guardian", 5000)
	profile.owned.append("hoja_balas_cin")
	var state := _brief.rack(profile, "side1")
	assert_ne(str(state["style"]), "", "el tablero dice que monta en los brazos")
	var forms: Array[String] = []
	for part: Dictionary in state["parts"]:
		if not (part["item"] as ItemDef).form in forms:
			forms.append((part["item"] as ItemDef).form)
	forms.sort()
	assert_eq(forms, ["corto", "medio"] as Array[String], "ni hojas ni armas largas")
	# Arriba ve lo de todos.
	var tops := _brief.rack(profile, "top0")
	assert_gt((tops["parts"] as Array).size(), 0)
	assert_eq(str(tops["style"]), "")


func test_el_guardian_sale_con_su_escudo_y_los_demas_con_lo_suyo() -> void:
	var guardian := _run("guardian")
	var build := _brief.build_of(guardian, guardian.build)
	assert_eq(build.skills.shield_uses, 1, "un escudo por combate, de serie")
	var mech := BattleMech.new(build, _rules)
	assert_eq(mech.kits_left("shield"), 1)
	var assault := _run("asalto")
	assert_gt(_brief.build_of(assault, assault.build).skills.damage, 0.0)
	assert_eq(_brief.build_of(assault, assault.build).skills.shield_uses, 0)
	var shooter := _run("tirador")
	assert_eq(_brief.build_of(shooter, shooter.build).skills.point_blank, 1)
	assert_eq(build.skills.point_blank, 0)


func test_el_tirador_dispara_a_quemarropa_y_los_demas_no() -> void:
	var rifle := "largo_balas_ion"
	assert_eq(_catalog.get_item(rifle).range_min, 3, "un rifle no llega a la casilla de al lado")
	var shooter := _run("tirador")
	var with_it := _brief.build_of(shooter, shooter.build)
	var plain := _catalog.make_build(shooter.build, _rules, T.COMMON, 0)
	for pair: Array in [[with_it, ""], [plain, "fuera de alcance"]]:
		var engine := BattleEngine.new(_rules, pair[0], plain, 1, 0)
		engine.mechs[0].position = 4
		engine.mechs[1].position = 5
		assert_eq(engine.why_cant_use(engine.mechs[0], engine.mechs[1], "side0"), pair[1])
		# De lejos llega igual que siempre.
		engine.mechs[1].position = 9
		assert_eq(engine.why_cant_use(engine.mechs[0], engine.mechs[1], "side0"), "")
	# El arma del catalogo no se toca: solo la que lleva ese mech en combate.
	assert_eq(with_it.sides[0].range_min, 3)
	assert_eq(BattleMech.new(with_it, _rules).slots["side0"].def.range_min, 1)


func test_lo_del_tipo_se_suma_a_las_habilidades_aprendidas() -> void:
	var skills := SkillSet.new()
	skills.shield_uses = 1
	skills.damage = 0.03
	_styles.add_effects("guardian", skills)
	assert_eq(skills.shield_uses, 2)
	_styles.add_effects("asalto", skills)
	assert_gt(skills.damage, 0.03)
	_styles.add_effects("", skills)
	assert_eq(skills.shield_uses, 2, "sin tipo no suma nada")


func test_la_pantalla_de_partida_nueva_ensena_los_tres() -> void:
	var entries := _brief.starters()
	assert_eq(entries.size(), 3)
	for entry in entries:
		assert_not_null(entry["build"])
		assert_string_contains(str(entry["kit"]), "Empieza con")
		assert_ne(str(entry["arms"]), "")
	var select := StarterSelect.new()
	add_child_autofree(select)
	select.entries = entries
	var picked: Array[String] = []
	select.chosen.connect(func(id: String) -> void: picked.append(id))
	var at := select.spot_rect(1).get_center()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = at
	select._gui_input(click)
	assert_eq(select.armed(), 1, "la primera pulsacion lo deja armado")
	assert_eq(picked.size(), 0)
	# Pasar el raton a otro lo desarma.
	var motion := InputEventMouseMotion.new()
	motion.position = select.spot_rect(0).get_center()
	select._gui_input(motion)
	assert_eq(select.armed(), -1)
	click.position = select.spot_rect(2).get_center()
	select._gui_input(click)
	select._gui_input(click)
	assert_eq(picked, ["tirador"] as Array[String])


# --- El robot de asistencia se compra --------------------------------------------


func test_una_partida_nueva_no_trae_asistente() -> void:
	var profile := _run("asalto")
	Garage.ensure_assist(profile, _catalog)
	assert_false(Garage.has_assist(profile, _catalog))
	assert_false(profile.build.has("assist"))


func test_el_asistente_se_compra_una_vez_y_trae_los_cuatro_protocolos() -> void:
	var profile := _run("asalto", 5000)
	var price := _garage.price(_catalog, _rules, _workshop, "asistente_reactor", T.COMMON)
	assert_gt(price, _garage.price(_catalog, _rules, _workshop, "corto_balas_cin", T.COMMON))
	var why := _garage.buy(profile, _catalog, _rules, _workshop, "asistente_reactor", T.COMMON)
	assert_eq(why, "")
	assert_eq(profile.gold, 5000 - price)
	assert_true(Garage.has_assist(profile, _catalog))
	assert_eq(profile.build["assist"], "asistente_reactor", "montado con el que eligio")
	var bodies := 0
	for id in profile.owned:
		if _catalog.get_item(id).type == ItemDef.Type.ASSIST:
			bodies += 1
	assert_eq(bodies, 4, "los cuatro protocolos, que se cambian gratis")
	assert_true(profile.parts.has(ItemDef.ASSIST_PROGRESS))
	# No se vuelve a cobrar por otro protocolo.
	assert_eq(
		_garage.why_cant_buy(profile, _catalog, _rules, _workshop, "asistente_escolta", T.COMMON),
		"ya la tienes"
	)


func test_sin_celdas_no_se_compra_el_asistente() -> void:
	var profile := _run("asalto", 100)
	assert_eq(
		_garage.buy(profile, _catalog, _rules, _workshop, "asistente_blindaje", T.COMMON),
		"faltan celdas"
	)
	assert_false(Garage.has_assist(profile, _catalog))


func test_el_tablero_vende_el_asistente_y_cierra_sus_armas_hasta_tenerlo() -> void:
	var profile := _run("asalto", 9000)
	profile.xp = _progression.levels[2]
	assert_eq(_brief.lock_reason(profile, "assist"), "", "en el nivel 3 se puede comprar")
	assert_eq(_brief.lock_reason(profile, "drone"), Txt.t("slot_needs_assist"))
	var state := _brief.rack(profile, "assist")
	assert_eq((state["parts"] as Array).size(), 4)
	for part: Dictionary in state["parts"]:
		assert_false(part["owned"])
		assert_gt(int(part["price"]), 0)
		assert_eq(str(part["reason"]), "")
	_garage.buy(profile, _catalog, _rules, _workshop, "asistente_blindaje", T.COMMON)
	assert_eq(_brief.lock_reason(profile, "drone"), "")
	for part: Dictionary in _brief.rack(profile, "assist")["parts"]:
		assert_true(part["owned"], "ya son suyos: no se venden otra vez")


func test_antes_del_nivel_3_el_asistente_se_ve_pero_no_se_compra() -> void:
	var profile := _run("asalto", 9000)
	assert_ne(_brief.lock_reason(profile, "assist"), "")
	assert_ne(_brief.lock_reason(profile, "drone"), "")
	var state := _brief.rack(profile, "assist")
	assert_eq((state["parts"] as Array).size(), 4, "se ve desde el principio")
	for part: Dictionary in state["parts"]:
		assert_ne(str(part["reason"]), "", "cerrado hasta su nivel, aunque sobren celdas")


func test_sin_asistente_sus_armas_no_pelean() -> void:
	var profile := _run("asalto")
	profile.xp = _progression.levels[4]
	profile.owned.append("artillero_balas_cin")
	profile.build["drone"] = "artillero_balas_cin"
	var build := _brief.build_of(profile, profile.build)
	assert_null(build.drone)


# --- Guardados de antes ---------------------------------------------------------------


func test_una_partida_recien_empezada_con_las_reglas_de_antes_vuelve_a_elegir() -> void:
	var old := {
		"schema_version": 8,
		"mech": "hibrido_quimera",
		"owned": ["torso_centinela", "piernas_zancos", "asistente_blindaje"],
		"mechs": [{"name": "Quimera", "design": "hibrido_quimera", "build": {"torso": "x"}}],
		"parts": {"asistente": {"tier": 0, "level": 0}},
		"runs_lost": 2,
	}
	var profile := PlayerProfile.from_dict(old)
	assert_false(profile.has_mech(), "sin nada ganado: elige robot otra vez")
	assert_eq(profile.owned.size(), 0)
	assert_eq(profile.runs_lost, 2, "el historial se conserva")
	assert_false(profile.legacy_assist)


func test_una_partida_con_avance_conserva_su_robot_y_su_asistente() -> void:
	var old := {
		"schema_version": 8,
		"gold": 900,
		"wins": 4,
		"owned": ["torso_centinela", "piernas_zancos"],
		"mechs":
		[
			{
				"name": "Quimera",
				"design": "hibrido_quimera",
				"build": {"torso": "torso_centinela", "legs": "piernas_zancos"}
			}
		],
	}
	var profile := PlayerProfile.from_dict(old)
	assert_true(profile.has_mech())
	assert_eq(profile.style, "", "sin tipo: monta cualquier arma")
	assert_true(profile.legacy_assist)
	Garage.ensure_assist(profile, _catalog)
	assert_true(Garage.has_assist(profile, _catalog))
	# Y ya guardado con las reglas de ahora, no se vuelve a tocar.
	var again := PlayerProfile.from_dict(profile.to_dict())
	assert_true(again.has_mech())
	assert_false(again.legacy_assist)


# --- La arena, a la medida de lo que lleva ---------------------------------------------


func _weapons(build: MechBuild) -> int:
	var total := 0
	for item in build.sides + build.tops:
		if item != null:
			total += 1
	return total


func test_quien_empieza_con_una_arma_pelea_contra_rivales_de_una_arma() -> void:
	var profile := _run("asalto")
	var gear := Campaign.loadout_of(_brief.build_of(profile, profile.build))
	assert_eq(gear["sides"], 1)
	assert_eq(gear["tops"] + gear["modules"] + gear["specials"], 0)
	assert_false(gear["assist"])
	assert_false(gear["chest"])
	for seed_value in 8:
		var fight := _brief.campaign.arena_fight(0, _brief.library, seed_value, _rules, 1.0, gear)
		var rival := _brief.library.make(
			fight["enemy"], _catalog, _rules, T.COMMON, 0, null, {}, fight["loadout"]
		)
		assert_eq(rival.validate(_rules), [] as Array[String])
		assert_eq(_weapons(rival), 1, "una sola arma, como el jugador")
		assert_eq(rival.modules.size(), 0)
		assert_null(rival.drone)
		assert_null(rival.assist)
		assert_null(rival.charge)
		assert_null(rival.hook)


func test_el_arma_del_rival_no_es_siempre_la_misma() -> void:
	var gear := {"sides": 1}
	var seen := {}
	for seed_value in 16:
		var fight := _brief.campaign.arena_fight(0, _brief.library, seed_value, _rules, 1.0, gear)
		var rival := _brief.library.make(
			fight["enemy"], _catalog, _rules, T.COMMON, 0, null, {}, fight["loadout"]
		)
		seen[rival.sides[0].form] = true
	assert_gt(seen.size(), 2, "hojas, cortas, medias, largas...")


func test_un_jugador_armado_entero_pelea_contra_rivales_enteros() -> void:
	var profile := PlayerProfile.new()
	profile.start_run(_brief.library, "fisico_vanguardia")
	profile.xp = _progression.levels[4]
	var gear := Campaign.loadout_of(_brief.build_of(profile, profile.build))
	var fight := _brief.campaign.arena_fight(0, _brief.library, 3, _rules, 1.0, gear)
	var whole := _brief.library.make(fight["enemy"], _catalog, _rules, T.COMMON, 0)
	var rival := _brief.library.make(
		fight["enemy"], _catalog, _rules, T.COMMON, 0, null, {}, fight["loadout"]
	)
	# Todas sus armas de brazo, y arriba tantas como lleve el jugador.
	assert_eq(rival.sides.size(), whole.sides.size())
	assert_eq(rival.tops.size(), mini(whole.tops.size(), int(gear["tops"])))
	assert_not_null(rival.drone)
	assert_not_null(rival.charge)
	# Lleva como mucho los modulos del jugador.
	assert_eq(rival.modules.size(), mini(whole.modules.size(), int(gear["modules"])))


func test_recortar_no_inventa_piezas() -> void:
	var items := {"torso": "torso_baluarte", "legs": "piernas_zancos", "sides": ["hoja_balas_cin"]}
	var out := BuildLibrary.trim(
		items, {"sides": 4, "tops": 2, "modules": 8, "specials": 3, "assist": true, "chest": true}
	)
	assert_eq(out["sides"], ["hoja_balas_cin"])
	assert_eq(out["tops"], [])
	assert_eq(out["modules"], [])
	assert_false(out.has("drone"))
	assert_false(out.has("chest"))
	assert_false(out.has("charge"))
