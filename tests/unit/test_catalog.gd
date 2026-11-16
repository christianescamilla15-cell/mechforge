extends GutTest
## GDD 6 y mejora M1: carga del catalogo real y reglas del validador.

const CATALOG_PATH := "res://data/catalog.json"
const SPEC_PATH := "res://data/validation.json"
const FORBIDDEN_PATH := "res://docs/reference/original-item-names.txt"

# --- Catalogo real ---


func test_el_catalogo_real_carga_sin_errores() -> void:
	var catalog := Catalog.load_file(CATALOG_PATH)
	assert_eq(catalog.errors, [] as Array[String])
	assert_eq(catalog.items.size(), 58)


func test_el_catalogo_real_pasa_el_validador() -> void:
	var catalog := Catalog.load_file(CATALOG_PATH)
	var forbidden := _forbidden_names()
	assert_gt(forbidden.size(), 200, "la lista de nombres del original debe cargar")
	var problems := CatalogValidator.validate(catalog, RulesConfig.new(), _spec(), forbidden)
	assert_eq(problems, [] as Array[String])


func test_composicion_del_catalogo_real() -> void:
	var catalog := Catalog.load_file(CATALOG_PATH)
	assert_eq(catalog.by_type(ItemDef.Type.TORSO).size(), 6)
	assert_eq(catalog.by_type(ItemDef.Type.LEGS).size(), 6)
	assert_eq(catalog.by_type(ItemDef.Type.SIDE).size(), 18)
	assert_eq(catalog.by_type(ItemDef.Type.TOP).size(), 9)
	assert_eq(catalog.by_type(ItemDef.Type.DRONE).size(), 6)
	assert_eq(catalog.by_type(ItemDef.Type.MODULE).size(), 10)


# --- Carga ---


func test_carga_los_campos_de_una_pieza() -> void:
	var catalog := Catalog.from_dict(_data([_side({"tags": ["melee"], "tier_min": "RARE"})]))
	assert_eq(catalog.errors, [] as Array[String])
	var def := catalog.get_item("arma")
	assert_eq(def.display_name, "Arma de prueba")
	assert_eq(def.type, ItemDef.Type.SIDE)
	assert_eq(def.element, ItemDef.Element.PHYSICAL)
	assert_eq(def.tier_min, ItemDef.Tier.RARE)
	assert_eq(def.tier_max, ItemDef.Tier.DIVINE)
	assert_true(def.has_tag("melee"))
	assert_eq(def.dmg_max, 120)
	assert_eq(def.weight, 40)


func test_errores_de_formato() -> void:
	assert_has(_load_errors({"type": "ESPADA"}), "arma: valor 'ESPADA' no valido en 'type'")
	assert_has(
		_load_errors({"top": {"weight": 40, "fuerza": 3}}), "arma: estadistica desconocida 'fuerza'"
	)
	assert_has(
		_load_errors({"top": {"weight": -1}}), "arma: 'weight' debe ser un entero no negativo"
	)
	assert_has(
		_load_errors({"top": {"weight": 1.5}}), "arma: 'weight' debe ser un entero no negativo"
	)
	assert_has(_load_errors({"color": "rojo"}), "arma: campo desconocido 'color'")
	var dup := Catalog.from_dict(_data([_side(), _side()]))
	assert_has(dup.errors, "id repetido: arma")
	assert_has(
		Catalog.from_dict({"schema_version": 99, "items": []}).errors,
		"schema_version distinto de 1"
	)
	assert_has(
		Catalog.load_file("res://no_existe.json").errors,
		"no existe el archivo res://no_existe.json"
	)


# --- Validador ---


func test_m1_rechaza_demasiada_variacion_de_dano() -> void:
	var ok := _problems(_side({"top": {"weight": 40, "dmg_min": 100, "dmg_max": 135}}))
	assert_eq(ok, [] as Array[String], "variacion del 29.8 % entra")
	var bad := _problems(_side({"top": {"weight": 40, "dmg_min": 100, "dmg_max": 140}}))
	assert_string_contains(bad[0], "supera el 30 % (M1)")


func test_rechaza_nombres_del_original_sin_importar_mayusculas_ni_espacios() -> void:
	var bad := _problems(_side({"name": "back breaker"}), ["BackBreaker", "Void"])
	assert_string_contains(bad[0], "es del juego original")
	assert_eq(_problems(_side({"name": "Rompelomos"}), ["BackBreaker"]), [] as Array[String])


func test_rechaza_nombres_repetidos() -> void:
	var a := _side()
	var b := _side({"id": "arma2", "name": "ARMA  de prueba"})
	var problems := CatalogValidator.validate(
		Catalog.from_dict(_data([a, b])), RulesConfig.new(), _spec_min()
	)
	assert_string_contains(problems[0], "nombre repetido con arma")


func test_rechaza_alcance_fuera_de_la_arena() -> void:
	var far := _side(
		{"top": {"weight": 40, "dmg_min": 100, "dmg_max": 120, "range_min": 5, "range_max": 10}}
	)
	assert_string_contains(_problems(far)[0], "alcance [5,10] no valido")
	var inverted := _side(
		{"top": {"weight": 40, "dmg_min": 100, "dmg_max": 120, "range_min": 4, "range_max": 2}}
	)
	assert_string_contains(_problems(inverted)[0], "alcance [4,2] no valido")


func test_rechaza_peso_fuera_del_rango_de_su_tipo() -> void:
	var heavy := _side({"top": {"weight": 200, "dmg_min": 100, "dmg_max": 120}})
	assert_string_contains(_problems(heavy)[0], "peso 200 fuera de 8-86")


func test_identidad_de_elemento() -> void:
	var phys_heat := _side({"top": {"weight": 40, "dmg_min": 100, "dmg_max": 120, "heat_dmg": 30}})
	assert_string_contains(_problems(phys_heat)[0], "no deberia tener 'heat_dmg'")
	var heat_plain := _side({"element": "HEAT"})
	assert_string_contains(_problems(heat_plain)[0], "un arma de calor debe tener heat_dmg")
	var energy_plain := _side({"element": "ENERGY"})
	assert_string_contains(_problems(energy_plain)[0], "un arma de energia debe tener energy_dmg")
	var combined := _side({"element": "COMBINED"})
	assert_string_contains(
		_problems(combined)[0], "solo los modulos pueden ser de elemento combinado"
	)


func test_reglas_por_tipo() -> void:
	var armored_gun := _side({"top": {"weight": 40, "dmg_min": 100, "dmg_max": 120, "health": 50}})
	assert_string_contains(_problems(armored_gun)[0], "no deberia tener 'health'")
	var useless := _side({"top": {"weight": 40}})
	assert_string_contains(_problems(useless)[0], "un arma debe hacer dano")
	var special := _side({"type": "CHARGE", "top": {"weight": 20, "dmg_min": 100, "dmg_max": 120}})
	assert_string_contains(_problems(special)[0], "un especial debe tener usos limitados")
	var sword := _side({"tags": ["espada"]})
	assert_string_contains(_problems(sword)[0], "una espada debe llevar tambien la etiqueta melee")
	var tagged := _side({"tags": ["volador"]})
	assert_string_contains(_problems(tagged)[0], "etiqueta desconocida 'volador'")
	var tiers := _side({"tier_min": "DIVINE", "tier_max": "RARE"})
	assert_string_contains(_problems(tiers)[0], "tier_min es mayor que tier_max")


func test_composicion_minima() -> void:
	var spec := _spec_min()
	spec["min_per_element"] = {"SIDE": 1}
	spec["min_total"] = {"MODULE": 1}
	var problems := CatalogValidator.validate(
		Catalog.from_dict(_data([_side()])), RulesConfig.new(), spec
	)
	assert_has(problems, "composicion: hay 0 SIDE de HEAT y se piden 1")
	assert_has(problems, "composicion: hay 0 SIDE de ENERGY y se piden 1")
	assert_has(problems, "composicion: hay 0 MODULE y se piden 1")
	assert_eq(problems.size(), 3)


func test_normalizar_nombres() -> void:
	assert_eq(CatalogValidator.normalize_name("Back Breaker!"), "backbreaker")
	assert_eq(CatalogValidator.normalize_name("  EMP-2 "), "emp2")


# --- Apoyo ---


func _side(overrides: Dictionary = {}) -> Dictionary:
	var item := {
		"id": "arma",
		"name": "Arma de prueba",
		"type": "SIDE",
		"element": "PHYSICAL",
		"top": {"weight": 40, "dmg_min": 100, "dmg_max": 120},
	}
	item.merge(overrides, true)
	return item


func _data(items: Array) -> Dictionary:
	return {"schema_version": 1, "items": items}


func _load_errors(overrides: Dictionary) -> Array[String]:
	return Catalog.from_dict(_data([_side(overrides)])).errors


func _problems(item: Dictionary, forbidden: Array = []) -> Array[String]:
	var catalog := Catalog.from_dict(_data([item]))
	return CatalogValidator.validate(catalog, RulesConfig.new(), _spec_min(), forbidden)


## Solo los rangos de peso: sin exigir composicion.
func _spec_min() -> Dictionary:
	return {"weight": _spec()["weight"]}


func _spec() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))


func _forbidden_names() -> Array:
	var names: Array = []
	for line in FileAccess.get_file_as_string(FORBIDDEN_PATH).split("\n"):
		var text := line.strip_edges()
		if text != "" and not text.begins_with("#"):
			names.append(text)
	return names
