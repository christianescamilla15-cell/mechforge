extends GutTest
## Ajustes del jugador (GameSettings): se guardan aparte de la partida, se
## leen con limites y ponen el volumen de cada canal de sonido.

const PATH := "user://test_settings.cfg"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_sin_archivo_da_los_valores_por_defecto() -> void:
	var s := GameSettings.load_from("user://no_existe.cfg")
	assert_eq(s.speed(), 1.0)
	assert_false(s.fullscreen)
	assert_eq(s.volumes["Master"], 1.0)


func test_ida_y_vuelta_por_el_archivo() -> void:
	var s := GameSettings.new()
	s.speed_index = 2
	s.fullscreen = true
	s.volumes["Music"] = 0.35
	assert_eq(s.save_to(PATH), OK)
	var back := GameSettings.load_from(PATH)
	assert_eq(back.speed(), 2.0)
	assert_true(back.fullscreen)
	assert_almost_eq(back.volumes["Music"], 0.35, 0.0001)
	assert_eq(back.volumes["Effects"], GameSettings.DEFAULT_VOLUMES["Effects"])


func test_lo_que_esta_fuera_de_rango_vuelve_al_limite() -> void:
	var file := ConfigFile.new()
	file.set_value("battle", "speed_index", 99)
	file.set_value("audio", "Master", 7.0)
	file.set_value("audio", "Music", -3.0)
	file.save(PATH)
	var s := GameSettings.load_from(PATH)
	assert_eq(s.speed(), GameSettings.SPEEDS[-1])
	assert_eq(s.volumes["Master"], 1.0)
	assert_eq(s.volumes["Music"], 0.0)


func test_crea_los_canales_y_les_pone_su_volumen() -> void:
	var s := GameSettings.new()
	s.volumes["Effects"] = 0.5
	s.volumes["Music"] = 0.0
	s.apply()
	for bus in GameSettings.BUSES:
		assert_gte(AudioServer.get_bus_index(bus), 0, "existe el canal %s" % bus)
	var effects := AudioServer.get_bus_index("Effects")
	assert_almost_eq(AudioServer.get_bus_volume_db(effects), linear_to_db(0.5), 0.01)
	assert_eq(AudioServer.get_bus_send(effects), &"Master")
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "a 0 se calla")
	GameSettings.new().apply()


func test_no_duplica_los_canales() -> void:
	GameSettings.ensure_buses()
	var count := AudioServer.bus_count
	GameSettings.ensure_buses()
	assert_eq(AudioServer.bus_count, count)
