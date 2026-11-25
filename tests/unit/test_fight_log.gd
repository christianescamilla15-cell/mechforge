extends GutTest
## El registro de combates (FightLog, OBS-051): "puedes revisar los combates
## que he tenido".

const PATH := "user://test_combates.jsonl"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_cada_combate_es_una_linea_que_se_vuelve_a_leer() -> void:
	assert_eq(FightLog.read(PATH).size(), 0, "sin archivo, nada")
	assert_true(FightLog.append({"mode": "arena", "step": 4, "won": true}, PATH))
	assert_true(FightLog.append({"mode": "arena", "step": 5, "won": false}, PATH))
	var fights := FightLog.read(PATH)
	assert_eq(fights.size(), 2, "se anade al final, no se pisa")
	assert_eq(int(fights[0]["step"]), 4)
	assert_false(bool(fights[1]["won"]))


func test_una_linea_rota_no_tumba_el_registro() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_line("{roto")
	file.close()
	FightLog.append({"mode": "campaign"}, PATH)
	assert_eq(FightLog.read(PATH).size(), 1)
