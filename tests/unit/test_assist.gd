extends GutTest
## Robot de asistencia (pedido del usuario, 2026-11-17): hasta dos armas,
## superior e inferior; bateria propia que se puede ampliar; un protocolo que
## da una bonificacion al mech; y 5 transformaciones (las clases de pieza)
## que suben su ataque y su defensa. Debe ser estable en combate: dispara una
## sola arma por turno, alternandolas, el mech paga sus costos como siempre y
## la bateria solo sube el dano de sus armas.

const PROTOCOLS: Array[String] = [
	"asistente_escolta", "asistente_blindaje", "asistente_reactor", "asistente_criogenia"
]

var _catalog: Catalog
var _rules := RulesConfig.new()


func before_all() -> void:
	_catalog = Catalog.load_file("res://data/catalog.json")


func _assist(props: Dictionary = {}) -> ItemDef:
	var base := {"health": 75}
	base.merge(props, true)
	return Fx.item(ItemDef.Type.ASSIST, base)


func _drone(props: Dictionary = {}) -> ItemDef:
	var base := {"weight": 40, "dmg_min": 100, "dmg_max": 100, "energy_cost": 20, "heat_cost": 10}
	base.merge(props, true)
	return Fx.item(ItemDef.Type.DRONE, base)


func _with_assist(opts: Dictionary = {}) -> MechBuild:
	var full := {
		"assist": _assist(), "drone": _drone(), "drone_low": _drone({"dmg_min": 60, "dmg_max": 60})
	}
	full.merge(opts, true)
	return Fx.build([Fx.gun()], full)


## Dano que hace el asistente del mech 0 en cada uno de sus turnos.
func _assist_damage(e: BattleEngine, turns: int) -> Array[int]:
	var out: Array[int] = []
	for turn in turns:
		var before := e.mechs[1].health
		Fx.pass_turn(e)
		out.append(before - e.mechs[1].health)
		Fx.pass_turn(e)
	return out


func test_dispara_una_sola_arma_por_turno_y_las_alterna() -> void:
	var e := Fx.engine(_with_assist(), Fx.build())
	assert_eq(_assist_damage(e, 4), [100, 60, 100, 60], "superior, inferior, superior...")


func test_si_a_la_que_le_toca_no_alcanza_dispara_la_otra() -> void:
	var short := _drone({"dmg_min": 60, "dmg_max": 60, "range_min": 1, "range_max": 2})
	var e := Fx.engine(_with_assist({"drone_low": short}), Fx.build(), 2)
	assert_eq(_assist_damage(e, 3), [100, 100, 100], "a distancia 6 solo llega la superior")


func test_el_mech_paga_los_disparos_del_asistente() -> void:
	var e := Fx.engine(_with_assist(), Fx.build())
	Fx.pass_turn(e)
	assert_eq(e.mechs[0].energy, e.mechs[0].energy_cap - 20, "gasta su energia, como siempre")
	assert_eq(e.mechs[0].heat, 10, "y lo calienta")


func test_la_bateria_sube_el_dano_de_sus_armas_y_nada_mas() -> void:
	var build := _with_assist()
	build.upgrades = ArenaUpgrades.new()
	build.upgrades.assist = 0.2
	var e := Fx.engine(build, Fx.build())
	assert_eq(_assist_damage(e, 2), [120, 72], "+20 % a la superior y a la inferior")
	e = Fx.engine(build, Fx.build())
	e.apply(BattleAction.weapon("side0"))
	assert_eq(e.mechs[1].health, e.mechs[1].max_health - 100, "las armas del mech no cambian")


func test_sin_energia_el_asistente_no_dispara() -> void:
	var dry := _with_assist()
	dry.torso = Fx.torso({"energy_cap": 10, "energy_regen": 0})
	var e := Fx.engine(dry, Fx.build())
	Fx.pass_turn(e)
	assert_eq(e.mechs[1].health, e.mechs[1].max_health, "el drenaje de energia lo para")


func test_sin_asistente_el_dron_dispara_como_siempre() -> void:
	var e := Fx.engine(Fx.build([], {"drone": _drone()}), Fx.build())
	Fx.pass_turn(e)
	assert_eq(e.mechs[1].health, 900)
	assert_eq(e.mechs[0].energy, e.mechs[0].energy_cap - 20)


func test_solo_pesa_el_arma_superior() -> void:
	var r := Fx.rules()
	var carried := _with_assist({"assist": _assist({"weight": 10})})
	var loose := Fx.build([Fx.gun()], {"drone": _drone()})
	assert_eq(loose.total_weight(), 480)
	assert_eq(carried.total_weight(), 480, "ni el cuerpo ni el arma inferior cuentan")
	assert_eq(carried.summary(r)["weight"], 480)


func test_el_protocolo_bonifica_al_mech() -> void:
	var r := Fx.rules()
	var plain := Fx.build().summary(r)
	var guarded := Fx.build([], {"assist": _assist({"res_physical": 12, "health": 150})})
	assert_eq(guarded.summary(r)["res_physical"], plain["res_physical"] + 12)
	assert_eq(guarded.summary(r)["health"], plain["health"] + 150)


func test_el_enjambre_repite_el_arma_que_disparo() -> void:
	var swarm := _with_assist()
	swarm.chassis = ChassisDef.new()
	swarm.chassis.extra_drone_shots = 1
	var e := Fx.engine(swarm, Fx.build(), 2)
	assert_eq(_assist_damage(e, 2), [200, 120], "dos veces la superior; luego, dos la inferior")


func test_los_huecos_del_asistente() -> void:
	assert_eq(Garage.slot_type("assist"), ItemDef.Type.ASSIST)
	assert_eq(Garage.slot_type("drone"), ItemDef.Type.DRONE)
	assert_eq(Garage.slot_type("drone_low"), ItemDef.Type.DRONE)
	var progression := Progression.load_file("res://data/progression.json")
	assert_eq(progression.unlock_level("assist"), progression.unlock_level("drone"))
	var build := _with_assist()
	progression.apply_locks(build, 1)
	assert_null(build.assist)
	assert_null(build.drone)
	assert_null(build.drone_low)


func test_el_catalogo_trae_los_cuatro_protocolos() -> void:
	assert_eq(_catalog.errors, [] as Array[String])
	for id in PROTOCOLS:
		var def := _catalog.get_item(id)
		assert_not_null(def, id)
		assert_eq(def.type, ItemDef.Type.ASSIST)
		assert_eq(def.tier_min, ItemDef.Tier.COMMON)
		assert_eq(def.tier_max, ItemDef.Tier.DIVINE, "cinco transformaciones, hasta Unica")
		assert_eq(def.progress_id(), ItemDef.ASSIST_PROGRESS, "un solo progreso para todos")


func test_las_armas_suben_con_el_asistente_del_jugador() -> void:
	var spec := {
		"torso": "torso_baluarte",
		"legs": "piernas_zancos",
		"assist": "asistente_escolta",
		"drone": "artillero_balas_cin",
		"drone_low": "zapador_blaster_cin",
	}
	var start := {ItemDef.ASSIST_PROGRESS: {"tier": ItemDef.Tier.COMMON, "level": 4}}
	var basic := _catalog.make_build(spec, _rules, ItemDef.Tier.COMMON, 0, start)
	assert_eq(basic.drone.tier, ItemDef.Tier.COMMON)
	assert_eq(basic.drone.level, 4)
	assert_null(basic.drone_low, "la inferior pelea desde la primera transformacion")
	var parts := {ItemDef.ASSIST_PROGRESS: {"tier": ItemDef.Tier.EPIC, "level": 3}}
	var advanced := _catalog.make_build(spec, _rules, ItemDef.Tier.COMMON, 0, parts)
	assert_eq(advanced.assist.tier, ItemDef.Tier.EPIC)
	assert_eq(advanced.drone.tier, ItemDef.Tier.RARE, "las balas no pasan de Intermedia")
	assert_eq(advanced.drone.level, _rules.tier_max_level[ItemDef.Tier.RARE])
	assert_not_null(advanced.drone_low)
	assert_eq(advanced.drone_low.tier, ItemDef.Tier.EPIC)
	assert_eq(advanced.drone_low.level, 3)


func test_los_rivales_llevan_todo_a_la_misma_clase() -> void:
	# Sin el progreso del jugador (rivales y simuladores) no hay recorte por
	# tipo de arma: todas las piezas van a la clase que se pide.
	var spec := {
		"torso": "torso_baluarte",
		"legs": "piernas_zancos",
		"assist": "asistente_escolta",
		"drone": "artillero_balas_cin",
	}
	var build := _catalog.make_build(spec, _rules, ItemDef.Tier.DIVINE, 50)
	assert_eq(build.drone.tier, ItemDef.Tier.DIVINE)
	assert_eq(build.drone.dmg_max, _catalog.get_item("artillero_balas_cin").dmg_max)


func test_cada_transformacion_sube_ataque_y_defensa() -> void:
	var spec := {
		"torso": "torso_baluarte",
		"legs": "piernas_zancos",
		"assist": "asistente_escolta",
		"drone": "artillero_laser_cin",
	}
	var previous: MechBuild = null
	for tier in [ItemDef.Tier.EPIC, ItemDef.Tier.LEGENDARY, ItemDef.Tier.MYTHIC]:
		var parts := {ItemDef.ASSIST_PROGRESS: {"tier": tier, "level": 0}}
		var build := _catalog.make_build(spec, _rules, ItemDef.Tier.COMMON, 0, parts)
		if previous != null:
			assert_gt(build.drone.dmg_max, previous.drone.dmg_max, "ataque")
			assert_gt(build.assist.res_physical, previous.assist.res_physical, "defensa")
		previous = build


func test_los_mechs_de_ejemplo_llevan_asistente() -> void:
	var library := BuildLibrary.load_file("res://data/builds.json")
	for id: String in library.specs:
		var items: Dictionary = library.specs[id]["items"]
		assert_true(str(items.get("assist", "")) in PROTOCOLS, id)
		assert_ne(str(items.get("drone_low", "")), "", id)
	var low := library.make("fisico_vanguardia", _catalog, _rules, ItemDef.Tier.COMMON, 0)
	assert_null(low.drone_low, "en Basica la segunda arma aun no pelea")
	var high := library.make("fisico_vanguardia_laser", _catalog, _rules, ItemDef.Tier.EPIC, 0)
	assert_not_null(high.drone_low)
	assert_eq(high.drone_low.id, high.drone.id, "gemela de la superior: alternan y pegan igual")


func test_la_bateria_de_la_armeria_se_abre_con_la_primera_transformacion() -> void:
	var shop := ArenaShop.load_file("res://data/arena_shop.json")
	var profile := PlayerProfile.new()
	profile.gold = 5000
	assert_eq(
		profile.why_cant_buy(shop, "assist"), "se abre con la primera transformacion del asistente"
	)
	profile.parts[ItemDef.ASSIST_PROGRESS] = {"tier": ItemDef.Tier.RARE, "level": 0}
	assert_eq(profile.buy(shop, "assist"), "")
	assert_almost_eq(shop.upgrades_for(profile.shop_levels).assist, shop.value("assist", 1), 0.0001)
	assert_almost_eq(shop.value("assist", shop.max_level()), 0.1, 0.0001, "hasta +10 %")


func test_una_partida_vieja_recibe_su_asistente() -> void:
	var profile := PlayerProfile.new()
	profile.build = {
		"torso": "torso_baluarte", "legs": "piernas_zancos", "drone": "artillero_balas_cin"
	}
	profile.owned.assign(["torso_baluarte", "piernas_zancos", "artillero_balas_cin"])
	profile.parts["artillero_balas_cin"] = {"tier": ItemDef.Tier.COMMON, "level": 4}
	Garage.ensure_assist(profile, _catalog)
	assert_true(str(profile.build["assist"]) in PROTOCOLS)
	for id in PROTOCOLS:
		assert_true(id in profile.owned, id)
	assert_eq(profile.part(ItemDef.ASSIST_PROGRESS)["level"], 4, "hereda el progreso de su dron")
	assert_false("asistente_escolta" in Garage.new().stock_for(_catalog, 0), "no se venden")
