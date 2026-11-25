extends GutTest
## Disparos de las armas (docs/CATALOGO_ARMAS.md seccion 9, data/shots.json,
## scenes/battle/shot_fx.gd): cada arma del catalogo dispara el suyo y cada
## tipo dispara como dice su ficha.

const CATALOG_PATH := "res://data/catalog.json"
## Las formas cuyo disparo depende de la municion y no del tipo.
const BY_AMMO: Array[String] = ["saboteador", "zapador"]

var _catalog: Catalog


func before_all() -> void:
	_catalog = Catalog.load_file(CATALOG_PATH)


func _weapons() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for type: ItemDef.Type in [
		ItemDef.Type.SIDE, ItemDef.Type.TOP, ItemDef.Type.CHEST, ItemDef.Type.DRONE
	]:
		out.append_array(_catalog.by_type(type))
	return out


func test_la_tabla_de_disparos_esta_bien_formada() -> void:
	assert_eq(ShotFx.problems(), [] as Array[String])


func test_cada_arma_del_catalogo_tiene_un_disparo_conocido() -> void:
	var used := {}
	for item in _weapons():
		assert_true(ShotFx.is_known(item.fx), "%s dispara '%s'" % [item.id, item.fx])
		used[item.fx] = true
	assert_eq(used.size(), 35, "35 disparos distintos en las 111 armas")


func test_cada_tipo_dispara_como_dice_su_ficha() -> void:
	for item in _weapons():
		if item.form in BY_AMMO:
			continue
		var shot := ShotFx.shot(item.fx)
		var label := "%s (%s)" % [item.id, item.fx]
		match item.weapon_type:
			"balas":
				# Proyectiles solidos: trazadoras, perdigones o una bala; la
				# cuchilla, un tajo.
				assert_has(["tracer", "pellet", "slug", "slash"], shot["body"], label)
				assert_eq(shot["impact"], "sparks", label)
			"canon":
				# Un proyectil pesado que estalla; el arpon se clava.
				if shot["path"] != "cable":
					assert_eq(shot["impact"], "explosion", label)
			"blaster":
				assert_eq(shot["impact"], "splash", label)
			"laser":
				# Instantaneo: no viaja.
				assert_has(["beam", "orbital", "ring", "melee"], shot["path"], label)
				assert_eq(shot["impact"], "burn", label)


func test_las_hojas_cortan_y_las_demas_disparan() -> void:
	for item in _weapons():
		var melee: bool = ShotFx.shot(item.fx)["path"] == "melee"
		assert_eq(melee, item.has_tag(ItemDef.TAG_MELEE), item.id)


func test_un_disparo_desconocido_usa_el_de_por_defecto() -> void:
	assert_false(ShotFx.is_known("no_existe"))
	assert_eq(ShotFx.shot("no_existe")["path"], ShotFx.shot(ShotFx.DEFAULT_SHOT)["path"])


func test_el_saboteador_dispara_segun_su_municion() -> void:
	assert_eq(_catalog.get_item("saboteador_blaster_cin").fx, "repulsor")
	assert_eq(_catalog.get_item("saboteador_laser_ion").fx, "sifon")
	assert_eq(
		_catalog.get_item("saboteador_blaster_cin").display_name, "Repulsor de plasma cinético"
	)


func test_cada_disparo_lanza_sus_efectos_y_termina() -> void:
	var fx := ShotFx.new()
	add_child_autofree(fx)
	for id: String in ShotFx.table():
		fx.play(id, Vector2.ZERO, Vector2(700.0, -40.0), Color.WHITE, 0.01)
		assert_gt(fx._effects.size(), 0, "%s dibuja algo" % id)
	var count: int = ShotFx.shot("rotativa")["count"]
	assert_eq(count, 14, "la rotativa suelta 14 balas")
	await fx.play("obus", Vector2.ZERO, Vector2(1800.0, 0.0), Color.WHITE, 0.01)
	assert_true(true, "el ultimo disparo termino")


## La potencia de disparo de los aspectos (OBS-051) agranda el disparo.
func test_la_potencia_agranda_el_disparo() -> void:
	var plain := ShotFx.new()
	add_child_autofree(plain)
	plain.play("obus", Vector2.ZERO, Vector2(700.0, 0.0), Color.WHITE, 0.01)
	var strong := ShotFx.new()
	add_child_autofree(strong)
	strong.play("obus", Vector2.ZERO, Vector2(700.0, 0.0), Color.WHITE, 0.01, 1.5)
	var biggest := func(fx: ShotFx) -> float:
		var top := 0.0
		for effect: Dictionary in fx._effects:
			if effect.get("kind", "") == "projectile":
				top = maxf(top, float(effect.get("size", 0.0)))
		return top
	assert_gt(biggest.call(plain), 0.0)
	assert_almost_eq(biggest.call(strong), biggest.call(plain) * 1.5, 0.001)
	var gun := Fx.gun()
	assert_eq(AspectLook.shot_scale(gun), 1.0)
	gun.aspects = {"potencia": 10}
	assert_almost_eq(AspectLook.shot_scale(gun), 1.5, 0.0001)
