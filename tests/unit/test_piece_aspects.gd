extends GutTest
## Aspectos de cada pieza (OBS-051, del usuario: "al menos 5 aspectos del arma
## o armadura"; "hasta 10 niveles en vez de 5, cada nivel mejora el arma o
## armadura en vivo"; "cuesta cada vez mas"; "la potencia de disparo").
## Decidido el 2026-11-24: se pagan con celdas, 5 000 el primer nivel y x 1.8
## cada uno.

var _aspects: PieceAspects
var _catalog: Catalog


func before_all() -> void:
	_aspects = PieceAspects.load_file("res://data/aspects.json")
	_catalog = Catalog.load_file("res://data/catalog.json")


func _gun() -> ItemDef:
	return (
		Fx
		. gun(
			{
				"dmg_min": 100,
				"dmg_max": 200,
				"crit": 10,
				"weight": 50,
				"heat_cost": 40,
				"energy_cost": 20,
			}
		)
	)


func _rich() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.gold = 10_000_000
	return profile


func test_los_datos_cargan_sin_errores() -> void:
	assert_eq(_aspects.errors, [] as Array[String])
	assert_eq(_aspects.max_level, 10)


## Cada arma y cada torso del juego tienen al menos cinco aspectos.
func test_cada_arma_y_torso_del_juego_tiene_cinco_o_mas() -> void:
	var counted := 0
	for def: ItemDef in _catalog.items.values():
		if not PieceAspects.has_aspects(def):
			continue
		counted += 1
		assert_gte(_aspects.for_item(def).size(), 5, def.id)
	assert_gt(counted, 90, "todas las armas y los torsos")


func test_el_precio_crece_por_1_8() -> void:
	assert_eq(_aspects.cost(0), 5000)
	assert_eq(_aspects.cost(1), 9000)
	assert_eq(_aspects.cost(2), 16200)
	var total := 0
	for level in 10:
		total += _aspects.cost(level)
	assert_between(total, 2_100_000, 2_300_000, "los diez niveles de un aspecto")


func test_subir_cobra_y_llega_hasta_10() -> void:
	var profile := _rich()
	var gun := _gun()
	assert_eq(_aspects.raise(profile, gun, "potencia"), "")
	assert_eq(profile.gold, 10_000_000 - 5000)
	assert_eq(PieceAspects.levels_of(profile, gun), {"potencia": 1})
	for i in 9:
		assert_eq(_aspects.raise(profile, gun, "potencia"), "")
	assert_eq(_aspects.raise(profile, gun, "potencia"), "ya esta al maximo")
	assert_eq(_aspects.raise(profile, gun, "grosor"), "esa pieza no tiene ese aspecto")
	var poor := PlayerProfile.new()
	assert_eq(_aspects.raise(poor, gun, "filo"), "faltan celdas")


func test_los_aspectos_de_un_arma_cambian_sus_numeros() -> void:
	var gun := _gun()
	var levels := {
		"potencia": 10,
		"precision": 10,
		"filo": 5,
		"material": 10,
		"refrigeracion": 10,
		"eficiencia": 4,
	}
	var shaped := _aspects.apply(gun, levels)
	assert_eq(shaped.dmg_max, 280, "+40 %")
	assert_eq(shaped.dmg_min, 140 + 98, "+40 % y la precision cierra el 70 % hasta el maximo")
	assert_eq(shaped.crit, 15)
	assert_eq(shaped.weight, 35, "-30 %")
	assert_eq(shaped.heat_cost, 20, "-50 %")
	assert_eq(shaped.energy_cost, 16, "-20 %")
	assert_eq(shaped.aspects, levels, "apunta sus niveles para dibujarlos")
	assert_eq(gun.dmg_max, 200, "la pieza del catalogo no cambia")


func test_los_aspectos_del_torso() -> void:
	var torso := Fx.torso({"res_physical": 20, "res_heat": 20, "res_energy": 20})
	var shaped := _aspects.apply(
		torso, {"grosor": 10, "aleacion": 10, "ligereza": 5, "disipacion": 5, "reactor": 5}
	)
	assert_eq(shaped.health, 1300)
	assert_eq(shaped.res_physical, 30)
	assert_eq(shaped.weight, 255)
	assert_eq(shaped.heat_cap, 240)
	assert_eq(shaped.cooling, 60)
	assert_eq(shaped.energy_cap, 240)
	assert_eq(shaped.energy_regen, 60)


func test_un_arma_cuerpo_a_cuerpo_tiene_filo_y_las_demas_calibre() -> void:
	var filo := _aspects.get_aspect("filo")
	var blade := Fx.gun({"crit": 10, "tags": PackedStringArray([ItemDef.TAG_MELEE])})
	assert_eq(PieceAspects.name_on(filo, blade), "Filo")
	assert_eq(PieceAspects.name_on(filo, _gun()), "Calibre")


func test_el_robot_del_jugador_lleva_sus_aspectos() -> void:
	var build := Fx.build([_gun()], {"tops": [_gun()]})
	var by_piece := {build.sides[0].progress_id(): {"potencia": 5}}
	_aspects.apply_build(build, by_piece)
	assert_eq(build.sides[0].dmg_max, 240)
	assert_eq(build.tops[0].dmg_max, 240, "misma pieza, mismos aspectos")
	assert_eq(build.torso.aspects, {}, "el torso sin mejorar no cambia")


func test_los_aspectos_se_guardan_y_una_partida_nueva_los_borra() -> void:
	var profile := _rich()
	profile.aspects["arma_a"] = {"potencia": 3}
	var path := "user://test_aspects_save.json"
	profile.save(path)
	var loaded := PlayerProfile.load_or_new(path)
	assert_eq(loaded.aspects, {"arma_a": {"potencia": 3}} as Dictionary[String, Dictionary])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.end_run()
	assert_true(profile.aspects.is_empty(), "una partida nueva empieza sin aspectos")


## La etiqueta de la pieza lleva la tecla de sus aspectos; la de los
## aspectos, una fila por aspecto con lo que da y lo que cuesta el siguiente.
func test_la_etiqueta_de_los_aspectos() -> void:
	var profile := _rich()
	var gun := _gun()
	assert_eq(AspectBrief.key_label(_aspects, profile, gun), "Aspectos: 0/60 ›")
	assert_eq(AspectBrief.key_label(_aspects, profile, Fx.legs()), "", "las piernas no tienen")
	assert_eq(_aspects.raise(profile, gun, "potencia"), "")
	var state := AspectBrief.state(_aspects, profile, gun)
	assert_eq(state["kind"], "aspects")
	var rows: Array = state["rows"]
	assert_eq(rows.size(), 6)
	assert_eq(rows[0]["level"], 1)
	assert_eq(rows[0]["text"], "+4 % de daño y disparo")
	assert_eq(rows[0]["cost"], HangarProps.thousands(9000))
	assert_true(rows[0]["can"])
	assert_string_contains(str(rows[1]["text"]), "el 1.º", "sin niveles dice lo que da el primero")
	assert_eq(AspectBrief.key_label(_aspects, profile, gun), "Aspectos: 1/60 ›")
