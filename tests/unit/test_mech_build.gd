extends GutTest
## GDD 4: armado, peso, sobrecarga y resistencias exclusivas.


func test_suma_las_estadisticas_de_todas_las_piezas() -> void:
	var plating := Fx.item(ItemDef.Type.MODULE, {"weight": 40, "health": 150})
	var engine := Fx.item(ItemDef.Type.MODULE, {"weight": 25, "energy_cap": 90, "cooling": 40})
	var b := Fx.build([Fx.gun()], {"modules": [plating, engine], "legs": Fx.legs({"health": 400})})
	var s := b.summary(Fx.rules())
	assert_eq(s["weight"], 300 + 100 + 40 + 40 + 25)
	assert_eq(s["health"], 1000 + 400 + 150)
	assert_eq(s["energy_cap"], 290)
	assert_eq(s["cooling"], 90)


func test_en_el_limite_de_peso_no_hay_penalizacion() -> void:
	var b := Fx.build([], {"torso": Fx.torso({"weight": 900})})
	assert_eq(b.total_weight(), 1000)
	assert_eq(b.summary(Fx.rules())["health"], 1000)
	assert_eq(b.validate(Fx.rules()), [] as Array[String])


func test_sobrecarga_quita_15_de_vida_por_kg() -> void:
	var b := Fx.build([], {"torso": Fx.torso({"weight": 905})})
	assert_eq(b.summary(Fx.rules())["health"], 1000 - 5 * 15)
	assert_eq(b.validate(Fx.rules()), [] as Array[String])
	var e := Fx.engine(b, Fx.build())
	assert_eq(e.mechs[0].health, 925, "el combate empieza con la vida penalizada")


func test_sobrecarga_maxima_es_valida_y_un_kg_mas_no() -> void:
	var justo := Fx.build([], {"torso": Fx.torso({"weight": 910})})
	assert_eq(justo.validate(Fx.rules()), [] as Array[String])
	var pasado := Fx.build([], {"torso": Fx.torso({"weight": 911})})
	assert_has(pasado.validate(Fx.rules()), "demasiado peso")


# --- El arma de pecho pesa y el nucleo ampliado la carga (OBS-027) -----------------


func _with_chest(chest_weight: int, core_kg: float) -> MechBuild:
	# Un mech justo en el limite de peso, mas el arma de pecho.
	var b := Fx.build([], {"torso": Fx.torso({"weight": 900})})
	b.chest = Fx.item(ItemDef.Type.CHEST, {"weight": chest_weight, "dmg_min": 10, "dmg_max": 10})
	b.upgrades = ArenaUpgrades.new()
	b.upgrades.core = core_kg
	return b


func test_sin_ampliar_el_nucleo_el_arma_de_pecho_sobrecarga() -> void:
	var b := _with_chest(60, 0.0)
	assert_eq(b.total_weight(), 1060)
	assert_eq(b.max_weight(Fx.rules()), 1000)
	assert_has(b.validate(Fx.rules()), "demasiado peso")


func test_el_nucleo_ampliado_carga_el_arma_de_pecho_sin_tocar_lo_demas() -> void:
	var b := _with_chest(60, 80.0)
	assert_eq(b.max_weight(Fx.rules()), 1060, "carga el arma entera, no mas")
	assert_eq(b.validate(Fx.rules()), [] as Array[String])
	assert_eq(b.summary(Fx.rules())["health"], 1000, "sin penalizacion de sobrecarga")


func test_un_nucleo_a_medio_ampliar_carga_solo_una_parte() -> void:
	var b := _with_chest(60, 52.0)
	assert_eq(b.max_weight(Fx.rules()), 1052)
	assert_eq(b.validate(Fx.rules()), [] as Array[String], "8 kg de mas: sobrecarga permitida")
	assert_eq(b.summary(Fx.rules())["health"], 1000 - 8 * 15)


func test_sin_arma_de_pecho_el_nucleo_ampliado_no_da_capacidad() -> void:
	var b := Fx.build([], {"torso": Fx.torso({"weight": 911})})
	b.upgrades = ArenaUpgrades.new()
	b.upgrades.core = 80.0
	assert_eq(b.max_weight(Fx.rules()), 1000, "se amplia para el arma, no para lo demas")
	assert_has(b.validate(Fx.rules()), "demasiado peso")


func test_torso_y_piernas_son_obligatorios() -> void:
	var b := MechBuild.new()
	var problems := b.validate(Fx.rules())
	assert_has(problems, "falta el torso")
	assert_has(problems, "faltan las piernas")


func test_un_solo_modulo_por_tipo_de_resistencia() -> void:
	var phys := Fx.item(ItemDef.Type.MODULE, {"res_physical": 40})
	var heat := Fx.item(ItemDef.Type.MODULE, {"res_heat": 40})
	var combo := Fx.item(ItemDef.Type.MODULE, {"res_physical": 20, "res_heat": 20})
	var ok := Fx.build([], {"modules": [phys, heat]})
	assert_eq(ok.validate(Fx.rules()), [] as Array[String])
	var dup := Fx.build([], {"modules": [phys, phys]})
	var clash := "dos módulos dan la misma resistencia"
	var problems := dup.validate(Fx.rules())
	assert_eq(problems.size(), 1)
	assert_true(problems[0].begins_with(clash))
	var mixed := Fx.build([], {"modules": [phys, combo]})
	problems = mixed.validate(Fx.rules())
	assert_eq(problems.size(), 1)
	assert_true(problems[0].begins_with(clash))
	# El aviso nombra los dos modulos y sale una sola vez, aunque choquen
	# en varias resistencias a la vez.
	combo.display_name = "Matriz"
	var twice := Fx.build([], {"modules": [combo, combo]})
	problems = twice.validate(Fx.rules())
	assert_eq(problems.size(), 1, "una vez por pareja")
	assert_string_contains(problems[0], "Matriz y Matriz")


func test_limites_de_huecos() -> void:
	var guns: Array = []
	for i in 5:
		guns.append(Fx.gun({"weight": 1}))
	assert_has(Fx.build(guns).validate(Fx.rules()), "demasiadas armas laterales")
