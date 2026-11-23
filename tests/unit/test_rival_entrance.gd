extends GutTest
## La entrada del rival en la zona de combate (OBS-048, del usuario: "ahora si
## ves a tus combatientes en tamano real... y ya se ve mas como un combate
## como previo a la WWE"). En la zona el rival que toca no es una proyeccion:
## sale andando desde el borde derecho, a tu tamano, y al llegar se enciende
## su nombre. En el hangar de antes sigue siendo la proyeccion de siempre.

var _library: BuildLibrary
var _catalog: Catalog
var _rules := RulesConfig.new()


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")


func _rivals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ["fisico_vanguardia", "calor_horno"]:
		var build := _library.make(id, _catalog, _rules, ItemDef.Tier.RARE, 8)
		out.append({"id": id, "name": id, "detail": "Rara · nivel 8", "build": build})
	return out


func _row(ring: bool) -> RivalRow:
	var row := RivalRow.new()
	row.ring = ring
	add_child_autofree(row)
	row.layout(Vector2(1600, 900), 700.0, 1.0, 300.0)
	row.player_feet = Vector2(800, 700)
	return row


func test_en_la_zona_el_rival_entra_andando_y_de_verdad() -> void:
	var row := _row(true)
	row.show_rivals(_rivals(), "enter")
	var front: RivalRow.Rival = row._rivals[0]
	assert_true(front.entering, "llega andando")
	assert_eq(front.title, 0.0, "su nombre aun apagado")
	assert_null(front.view.material, "sin proyeccion: sale de verdad")
	assert_gt(front.view.position.x, 1600.0, "empieza fuera, por la derecha")
	assert_false(row.front_has_point(row.front_rect().get_center()), "no se pulsa mientras llega")
	var back: RivalRow.Rival = row._rivals[1]
	assert_not_null(back.view.material, "los de detras siguen siendo proyecciones")
	await wait_seconds(RivalRow.WALK_SECONDS + 0.5)
	assert_false(front.entering, "ya llego")
	assert_almost_eq(front.view.position.x, row._feet(front).x, 1.0, "en su sitio")
	await wait_seconds(RivalRow.TITLE_SECONDS + 0.2)
	assert_almost_eq(front.title, 1.0, 0.01, "su nombre encendido")
	assert_true(row.front_has_point(row.front_rect().get_center()), "ya se pulsa")


func test_en_la_zona_el_rival_mide_como_tu_robot() -> void:
	var ring := _row(true)
	var hangar := _row(false)
	ring.show_rivals(_rivals(), "none")
	hangar.show_rivals(_rivals(), "none")
	var big := ring._scale(ring._rivals[0])
	var small := hangar._scale(hangar._rivals[0])
	assert_gt(big, small, "mas grande que la proyeccion")
	var room := (700.0 - 300.0) / ring._rivals[0].height
	assert_almost_eq(big, minf(RivalRow.RING_SCALE, room), 0.001, "a tu tamano (si cabe)")


func test_en_el_hangar_de_antes_sigue_la_proyeccion() -> void:
	var row := _row(false)
	row.show_rivals(_rivals(), "enter")
	var front: RivalRow.Rival = row._rivals[0]
	assert_false(front.entering)
	assert_not_null(front.view.material, "proyeccion")
	assert_eq(front.title, 1.0)


func test_al_ganar_el_siguiente_tambien_entra_andando() -> void:
	var row := _row(true)
	var rivals := _rivals()
	row.show_rivals(rivals, "none")
	var beaten := rivals[0]
	var rest: Array[Dictionary] = [rivals[1]]
	row.show_rivals(rest, "advance", beaten)
	assert_true(row._rivals[0].entering, "el siguiente sale andando")
	assert_eq(row._leaving.size(), 1, "el vencido se apaga delante")
