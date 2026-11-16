extends GutTest


func test_rng_con_semilla_es_determinista() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 42
	b.seed = 42
	assert_eq(a.randi_range(1, 100), b.randi_range(1, 100))
