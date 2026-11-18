extends GutTest
## Sonido (data/sounds.json y Sfx): cada archivo existe, cada disparo y cada
## clase de impacto tienen sonido, y cada sonido que el codigo pide existe.

const SOURCES: Array[String] = [
	"res://scenes/main.gd",
	"res://scenes/battle/battle_screen.gd",
	"res://scenes/battle/arena_view.gd",
	"res://scenes/battle/shot_fx.gd",
	"res://ui/settings_panel.gd",
	"res://scenes/workshop/workshop_screen.gd",
	"res://scenes/workshop/mech_stage.gd",
]

var _sfx: Sfx


func before_all() -> void:
	_sfx = Sfx.new()
	_sfx.load_data()


func after_all() -> void:
	_sfx.free()


func test_los_datos_cargan_sin_errores() -> void:
	assert_eq(_sfx.errors, [] as Array[String])
	assert_gt(_sfx.sounds.size(), 40)


func test_cada_disparo_tiene_sonido() -> void:
	for shot_id: String in ShotFx.table():
		assert_true(_sfx.shots.has(shot_id), "%s no tiene sonido" % shot_id)
		if _sfx.shots.has(shot_id):
			assert_true(_sfx.sounds.has(_sfx.shots[shot_id]["fire"]), shot_id)


func test_cada_clase_de_impacto_tiene_sonido() -> void:
	for kind in ShotFx.IMPACTS:
		assert_true(_sfx.impacts.has(kind), "el impacto %s no tiene sonido" % kind)


func test_la_musica_de_la_base_de_los_combates_y_de_los_jefes() -> void:
	for id in ["base", "combate", "jefe"]:
		assert_true(_sfx.tracks.has(id), "falta la musica %s" % id)
		var stream: AudioStream = _sfx.tracks[id]["stream"]
		assert_true(stream is AudioStreamOggVorbis and stream.loop, "%s va en bucle" % id)


## Lee el codigo: cada Sfx.play("x"), Sfx.rising("x"), Sfx.jingle("x") y
## Sfx.music("x") (y las dos ramas de un `"a" if c else "b"`) existe.
func test_cada_sonido_que_pide_el_codigo_existe() -> void:
	var call := RegEx.create_from_string("Sfx\\.(play|rising|jingle|music)\\(([^)]*)\\)")
	var literal := RegEx.create_from_string('"([a-z_]+)"')
	# Lo que se compara (`event == "shutdown"`) no es un sonido.
	var compared := RegEx.create_from_string('[=!]=\\s*"[a-z_]*"')
	var asked := 0
	for path in SOURCES:
		var code := FileAccess.get_file_as_string(path)
		for found in call.search_all(code):
			var kind := found.get_string(1)
			var args := compared.sub(found.get_string(2), "", true)
			for name in literal.search_all(args):
				var id := name.get_string(1)
				asked += 1
				if kind == "music":
					assert_true(_sfx.tracks.has(id), "%s pide la musica %s" % [path, id])
				else:
					assert_true(_sfx.sounds.has(id), "%s pide el sonido %s" % [path, id])
	assert_gt(asked, 25, "encontro las llamadas")


func test_sin_instancia_las_llamadas_no_hacen_nada() -> void:
	assert_null(Sfx.current())
	Sfx.play("bala")
	Sfx.shot_fired("rafaga")
	Sfx.music("base")
	assert_null(Sfx.current())
