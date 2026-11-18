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
