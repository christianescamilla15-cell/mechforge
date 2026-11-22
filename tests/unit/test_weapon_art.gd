extends GutTest
## Arte de las armas montadas (scenes/battle/mech_sprites.gd, docs/CHASIS.md
## seccion 6): cada arma de brazo y de hombro del catalogo tiene el dibujo de
## su forma y su tipo, en los tres elementos y con sus anclas.

const CATALOG_PATH := "res://data/catalog.json"

var _catalog: Catalog


func before_all() -> void:
	_catalog = Catalog.load_file(CATALOG_PATH)


func _mounted() -> Array[ItemDef]:
	return _catalog.by_type(ItemDef.Type.SIDE) + _catalog.by_type(ItemDef.Type.TOP)


func test_cada_arma_montada_tiene_el_dibujo_de_su_forma_y_su_tipo() -> void:
	var kinds := {}
	for item in _mounted():
		var prefix := "arm_" if item.type == ItemDef.Type.SIDE else "shoulder_"
		var wanted := prefix + item.form + "_" + item.weapon_type
		assert_eq(MechSprites.weapon_kind(item), wanted, "dibujo de %s" % item.id)
		kinds[wanted] = true
	assert_eq(kinds.size(), 26, "17 disenos de brazo y 9 de hombro")


func test_cada_dibujo_esta_en_los_tres_elementos() -> void:
	for item in _mounted():
		var kind := MechSprites.weapon_kind(item)
		for element: String in ["PHYSICAL", "HEAT", "ENERGY"]:
			var path := "%s%s_%s_%s.png" % [MechSprites.DIR, MechSprites.WEAPON_SET, kind, element]
			assert_true(ResourceLoader.exists(path), "falta %s" % path)


func test_la_boca_del_arma_queda_delante_de_su_union() -> void:
	var sprites := MechSprites.new()
	sprites.torso_set = MechSprites.TORSO_SETS[0]
	sprites.legs_set = MechSprites.LEGS_SETS[0]
	for item in _mounted():
		var kind := MechSprites.weapon_kind(item)
		var tip := sprites.piece_tip(MechSprites.WEAPON_SET, kind)
		assert_gt(tip.x, sprites.hip_point().x, "la boca de %s apunta hacia delante" % kind)
		assert_lt(tip.y, 0.0, "la boca de %s queda por encima del suelo" % kind)


func test_lo_que_no_va_montado_no_tiene_dibujo_de_arma() -> void:
	for type: ItemDef.Type in [ItemDef.Type.DRONE, ItemDef.Type.CHEST, ItemDef.Type.TORSO]:
		for item in _catalog.by_type(type):
			assert_eq(MechSprites.weapon_kind(item), "", "%s no es un arma montada" % item.id)
	assert_eq(MechSprites.weapon_kind(null), "")


# --- Evolucion del dibujo (GDD 8; tools/art/evolve_weapons.py) -------------------


func _resolved(id: String, tier: int, level: int) -> ItemDef:
	return ItemScaling.resolve(_catalog.get_item(id), RulesConfig.new(), tier, level)


func test_en_la_primera_clase_cada_nivel_es_un_paso_de_aspecto() -> void:
	for level in 7:
		var item := _resolved("hoja_balas_ter", ItemDef.Tier.COMMON, level)
		assert_eq(MechSprites.look_step(item), level, "nivel %d" % level)
	# En las siguientes los seis pasos se reparten entre mas niveles.
	var top := RulesConfig.new().tier_max_level[ItemDef.Tier.RARE]
	assert_eq(MechSprites.look_step(_resolved("hoja_balas_ter", ItemDef.Tier.RARE, 0)), 0)
	assert_eq(MechSprites.look_step(_resolved("hoja_balas_ter", ItemDef.Tier.RARE, 2)), 1)
	assert_eq(
		MechSprites.look_step(_resolved("hoja_balas_ter", ItemDef.Tier.RARE, top)),
		MechSprites.LOOK_STEPS
	)


func test_un_arma_sin_dibujos_de_evolucion_se_ve_como_siempre() -> void:
	var anchors := MechSprites._load_anchors(MechSprites.WEAPON_SET)
	for item in _mounted():
		var base := MechSprites.weapon_kind(item)
		if anchors.has(base + "_c0_1") or _has_phases(anchors, base):
			continue
		var grown := _resolved(item.id, item.tier_min, 6)
		assert_eq(MechSprites.weapon_look(grown), base, "%s sigue con su dibujo" % item.id)


func test_el_arma_piloto_suma_un_periferico_por_nivel_y_cambia_de_modelo_al_transformarla() -> void:
	var base := "arm_hoja_balas"
	var seen := {}
	for level in 7:
		var look := MechSprites.weapon_look(_resolved("hoja_balas_ter", ItemDef.Tier.COMMON, level))
		var wanted := base if level == 0 else "%s_c0_%d" % [base, level]
		assert_eq(look, wanted, "Basica nivel %d" % level)
		seen[look] = true
	assert_eq(seen.size(), 7, "cada nivel de la Basica se ve distinto")
	# Transformada a la clase siguiente, otro modelo, que empieza sin perifericos.
	var rare := _resolved("hoja_balas_ter", ItemDef.Tier.RARE, 0)
	assert_eq(MechSprites.weapon_look(rare), base + "_c1_0")
	var top := RulesConfig.new().tier_max_level[ItemDef.Tier.RARE]
	var rare_top := _resolved("hoja_balas_ter", ItemDef.Tier.RARE, top)
	assert_eq(MechSprites.weapon_look(rare_top), base + "_c1_6")
	# Cada dibujo esta en los tres elementos y con sus anclas, como cualquier arma.
	var anchors := MechSprites._load_anchors(MechSprites.WEAPON_SET)
	for tier in 2:
		for step in MechSprites.LOOK_STEPS + 1:
			if tier == 0 and step == 0:
				continue
			var look := "%s_c%d_%d" % [base, tier, step]
			assert_true(anchors.get(look) is Dictionary, "anclas de " + look)
			for key: String in ["hip", "size", "tip"]:
				assert_true((anchors[look] as Dictionary).has(key), "%s de %s" % [key, look])
			for element in 3:
				assert_not_null(
					MechSprites.texture(MechSprites.WEAPON_SET, look, element), "dibujo de " + look
				)
	# La miniatura del taller es ese mismo dibujo.
	var plain := MechSprites.icon_for(_resolved("hoja_balas_ter", ItemDef.Tier.COMMON, 0))
	var loaded := MechSprites.icon_for(_resolved("hoja_balas_ter", ItemDef.Tier.COMMON, 6))
	assert_ne(plain, loaded)


func _has_phases(anchors: Dictionary, base: String) -> bool:
	for phase in range(1, 11):
		if anchors.has("%s_f%d" % [base, phase]):
			return true
	return false


## OBS-047: las armas, como los torsos, se ven por fase ("<pieza>_f<fase>",
## o la mas alta que haya por debajo); sin fases, como siempre.
func test_un_arma_se_ve_por_su_fase() -> void:
	var real := MechSprites._load_anchors(MechSprites.WEAPON_SET)
	var fake := real.duplicate(true)
	for phase in range(1, 11):
		fake.erase("arm_medio_laser_f%d" % phase)
	fake["arm_medio_laser_f6"] = (real["arm_medio_laser"] as Dictionary).duplicate()
	fake["arm_medio_laser_f8"] = (real["arm_medio_laser"] as Dictionary).duplicate()
	MechSprites._anchors[MechSprites.WEAPON_SET] = fake
	var epic := _resolved("medio_laser_ter", ItemDef.Tier.EPIC, 0)
	assert_eq(MechSprites.weapon_look(epic), "arm_medio_laser", "fase 4: su dibujo de siempre")
	var top := RulesConfig.new().tier_max_level[ItemDef.Tier.EPIC]
	var epic_top := _resolved("medio_laser_ter", ItemDef.Tier.EPIC, top)
	assert_eq(MechSprites.weapon_look(epic_top), "arm_medio_laser", "fase 5 sin dibujo: la 4")
	var legendary := _resolved("medio_laser_ter", ItemDef.Tier.LEGENDARY, 0)
	assert_eq(MechSprites.weapon_look(legendary), "arm_medio_laser_f6", "fase 6")
	var legendary_top := _resolved("medio_laser_ter", ItemDef.Tier.LEGENDARY, 24)
	assert_eq(
		MechSprites.weapon_look(legendary_top), "arm_medio_laser_f6", "fase 7 sin dibujo: la 6"
	)
	var mythic_top := _resolved("medio_laser_ter", ItemDef.Tier.MYTHIC, 30)
	assert_eq(MechSprites.weapon_look(mythic_top), "arm_medio_laser_f8", "fase 9 sin dibujo: la 8")
	MechSprites._anchors[MechSprites.WEAPON_SET] = real
