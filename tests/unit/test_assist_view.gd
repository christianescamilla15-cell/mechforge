extends GutTest
## El robot de asistencia flota por encima de su mech
## (scenes/battle/mech_view.gd): en ninguna de sus formas se monta sobre el
## torso ni sobre las armas de hombro, que son lo mas alto del mech.

var _catalog: Catalog
var _rules: RulesConfig
var _library: BuildLibrary


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	_rules = RulesConfig.new()
	_library = BuildLibrary.load_file("res://data/builds.json")


func _view(tier: int, top: ItemDef, legs_tag: String = "") -> MechView:
	var build := _library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 6)
	build.tops.clear()
	if top != null:
		var item := ItemScaling.resolve(top, _rules, ItemDef.Tier.COMMON, 6)
		build.tops.append(item)
		build.tops.append(item)
	if legs_tag != "":
		for legs in _catalog.by_type(ItemDef.Type.LEGS):
			if legs.has_tag(legs_tag):
				build.legs = ItemScaling.resolve(legs, _rules, ItemDef.Tier.COMMON, 6)
				break
	var body := _catalog.get_item("asistente_blindaje")
	build.assist = ItemScaling.resolve(body, _rules, tier as ItemDef.Tier, 0)
	var view := MechView.new()
	view.setup(build, 1)
	return autofree(view)


## Lo mas alto que dibuja el mech, contado pieza a pieza.
func _highest(view: MechView) -> float:
	var sprites := MechSprites.for_build(view.build)
	var top := sprites.piece_top(sprites.torso_set, "torso")
	for i in view.build.tops.size():
		var at: Vector2 = MechView.TOP_MOUNTS[mini(i, MechView.TOP_MOUNTS.size() - 1)]
		var kind := MechSprites.weapon_kind(view.build.tops[i])
		top = minf(top, sprites.piece_top(MechSprites.WEAPON_SET, kind, at))
	return top


func test_el_asistente_flota_por_encima_de_su_mech_en_todas_sus_formas() -> void:
	var tops: Array[ItemDef] = [null]
	for item in _catalog.by_type(ItemDef.Type.TOP):
		if item.element == ItemDef.Element.PHYSICAL:
			tops.append(item)
	for top in tops:
		for tier in 6:
			var view := _view(tier, top)
			var kind := view._assist_kind()
			assert_ne(kind, "", "hay dibujo del asistente de clase %d" % tier)
			var bottom := view._assist_at().y + MechSprites.assist_bottom(kind)
			var label := "forma %d con %s" % [tier, top.id if top != null else "nada"]
			# El asistente sube y baja 4 unidades al flotar: queda aire de sobra.
			assert_lt(bottom + 4.0, _highest(view), "%s: el asistente no toca el mech" % label)


func test_con_piernas_que_levitan_tampoco_toca_al_mech() -> void:
	var top := _catalog.get_item("bateria_laser_cin")
	for tier in 6:
		var view := _view(tier, top, ItemDef.TAG_HOVER)
		var bottom := view._assist_at().y + MechSprites.assist_bottom(view._assist_kind())
		# El mech que levita sube hasta HOVER_HEIGHT + 3 sobre el suelo.
		var lifted := _highest(view) - MechView.HOVER_HEIGHT - 3.0
		assert_lt(bottom + 4.0, lifted, "forma %d: el asistente no toca el mech que levita" % tier)
