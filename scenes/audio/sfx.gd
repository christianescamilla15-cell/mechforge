class_name Sfx
extends Node
## Sonido del juego (PLAN F9): efectos, musica e interfaz, todo desde
## data/sounds.json (archivos en assets/audio; fuentes y licencias en
## assets/audio/CREDITOS.md). Es presentacion: el nucleo no sabe que existe.
## La pantalla principal crea una instancia; sin ella (tests, simuladores) las
## llamadas estaticas no hacen nada.

const DATA_PATH := "res://data/sounds.json"
const AUDIO_DIR := "res://assets/audio/"
const BUSES: Array[String] = ["Effects", "Interface", "Music"]
## Voces de efectos que pueden sonar a la vez; si faltan se corta la mas vieja.
const VOICES := 24
## Un mismo sonido no se repite dentro de este margen: los perdigones que
## salen a la vez suenan una sola vez.
const SAME_SOUND_MS := 30
## El tic de los deslizadores no suena mas a menudo que esto.
const TICK_MS := 70
const MUSIC_FADE_SECONDS := 1.0
const SILENT_DB := -40.0

static var _instance: Sfx

## id -> {"streams": Array[AudioStream], "bus", "volume_db", "pitch": Vector2}
var sounds: Dictionary = {}
## Disparo (data/shots.json) -> {"fire", "impact"?}.
var shots: Dictionary = {}
## Clase de impacto -> sonido.
var impacts: Dictionary = {}
## Pista -> {"stream", "volume_db"}.
var tracks: Dictionary = {}
var errors: Array[String] = []
## Con log_plays, cada sonido que empieza queda en `played` ({"ms", "id"}):
## la prueba en vivo lo compara con lo que se grabo.
var log_plays: bool = false
var played: Array[Dictionary] = []

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music: Array[AudioStreamPlayer] = []
var _music_id: String = ""
var _last_ms: Dictionary = {}
var _last_tick_ms: int = 0
var _rng := RandomNumberGenerator.new()

# --- Llamadas desde el juego ---------------------------------------------------


## Suena ese sonido, ahora o dentro de `delay` segundos de juego.
static func play(id: String, delay: float = 0.0) -> void:
	if _instance != null:
		_instance._schedule(id, delay)


## Sale un disparo de ese tipo (data/shots.json).
static func shot_fired(shot_id: String, delay: float = 0.0) -> void:
	if _instance != null:
		_instance._schedule(str(_instance.shots.get(shot_id, {}).get("fire", "")), delay)


## Llega un disparo de ese tipo: el impacto propio del disparo o el de su clase.
static func shot_hit(shot_id: String, impact: String, delay: float = 0.0) -> void:
	if _instance == null:
		return
	var own: Dictionary = _instance.shots.get(shot_id, {})
	_instance._schedule(str(own.get("impact", _instance.impacts.get(impact, ""))), delay)


## Un sonido que sube de tono durante `seconds` (la carga de la materia oscura).
static func rising(id: String, seconds: float) -> void:
	if _instance != null:
		_instance._rising(id, seconds)


## Cambia la musica, con un fundido; "" la apaga.
static func music(id: String) -> void:
	if _instance != null:
		_instance._play_music(id)


## Corta la musica y toca un jingle (victoria o derrota).
static func jingle(id: String) -> void:
	if _instance != null:
		_instance._play_music("")
		_instance._play(id)


static func current() -> Sfx:
	return _instance


# --- Datos -------------------------------------------------------------------


## Lee data/sounds.json. Devuelve los errores (archivo que falta, disparo o
## impacto sin sonido, canal que no existe); vacio si todo esta bien.
func load_data(path: String = DATA_PATH) -> Array[String]:
	errors.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		errors.append("%s no es un JSON valido" % path)
		return errors
	for id: String in parsed.get("sounds", {}):
		var raw: Dictionary = parsed["sounds"][id]
		var streams: Array[AudioStream] = []
		for file: String in raw.get("files", []):
			var stream := _load_stream(file)
			if stream == null:
				errors.append("%s: no existe el archivo %s" % [id, file])
			else:
				streams.append(stream)
		if streams.is_empty():
			errors.append("%s: no tiene archivos" % id)
			continue
		var bus: String = raw.get("bus", "Effects")
		if not bus in BUSES:
			errors.append("%s: el canal %s no existe" % [id, bus])
		var pitch: Array = raw.get("pitch", [1.0, 1.0])
		if pitch.size() != 2 or float(pitch[0]) <= 0.0 or float(pitch[0]) > float(pitch[1]):
			errors.append("%s: margen de tono invalido" % id)
			pitch = [1.0, 1.0]
		sounds[id] = {
			"streams": streams,
			"bus": bus,
			"volume_db": float(raw.get("volume_db", 0.0)),
			"pitch": Vector2(float(pitch[0]), float(pitch[1])),
		}
	shots = parsed.get("shots", {})
	impacts = parsed.get("impacts", {})
	for shot_id: String in shots:
		for key in ["fire", "impact"]:
			var id: String = shots[shot_id].get(key, "")
			if id != "" and not sounds.has(id):
				errors.append("disparo %s: el sonido %s no existe" % [shot_id, id])
	for kind: String in impacts:
		if not sounds.has(impacts[kind]):
			errors.append("impacto %s: el sonido %s no existe" % [kind, impacts[kind]])
	for id: String in parsed.get("music", {}):
		var raw: Dictionary = parsed["music"][id]
		var stream := _load_stream(str(raw.get("file", "")))
		if stream == null:
			errors.append("musica %s: no existe el archivo" % id)
			continue
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		tracks[id] = {"stream": stream, "volume_db": float(raw.get("volume_db", 0.0))}
	return errors


func _load_stream(file: String) -> AudioStream:
	var path := AUDIO_DIR + file + ".ogg"
	if file == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


# --- Reproduccion ------------------------------------------------------------


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.ensure_buses()
	for problem in load_data():
		push_warning("Sonido: %s" % problem)
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		_music.append(player)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _schedule(id: String, delay: float) -> void:
	if id == "":
		return
	if delay > 0.001:
		get_tree().create_timer(delay).timeout.connect(_play.bind(id))
	else:
		_play(id)


func _play(id: String) -> AudioStreamPlayer:
	if not sounds.has(id):
		return null
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -100000)) < SAME_SOUND_MS:
		return null
	_last_ms[id] = now
	var sound: Dictionary = sounds[id]
	var streams: Array = sound["streams"]
	var voice := _free_voice()
	voice.stop()
	voice.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	voice.bus = sound["bus"]
	voice.volume_db = sound["volume_db"]
	var pitch: Vector2 = sound["pitch"]
	voice.pitch_scale = _rng.randf_range(pitch.x, pitch.y)
	voice.play()
	if log_plays:
		played.append({"ms": now, "id": id})
	return voice


func _free_voice() -> AudioStreamPlayer:
	for i in VOICES:
		var voice := _voices[(_next_voice + i) % VOICES]
		if not voice.playing:
			_next_voice = (_next_voice + i + 1) % VOICES
			return voice
	var oldest := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	return oldest


func _rising(id: String, seconds: float) -> void:
	var voice := _play(id)
	if voice == null:
		return
	var tween := create_tween()
	voice.pitch_scale = 0.6
	tween.tween_property(voice, "pitch_scale", 1.5, maxf(0.05, seconds))


func _play_music(id: String) -> void:
	if id == _music_id:
		return
	_music_id = id
	var old := _music[0]
	var fresh := _music[1]
	_music.reverse()
	if old.playing:
		var out := create_tween()
		out.tween_property(old, "volume_db", SILENT_DB, MUSIC_FADE_SECONDS)
		out.tween_callback(old.stop)
	if not tracks.has(id):
		return
	fresh.stream = tracks[id]["stream"]
	fresh.volume_db = SILENT_DB
	fresh.play()
	var fade_in := create_tween()
	fade_in.tween_property(fresh, "volume_db", tracks[id]["volume_db"], MUSIC_FADE_SECONDS)


# --- Interfaz ----------------------------------------------------------------


## Todo boton suena al pulsarlo y todo deslizador hace tic al moverse.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_play.bind("ui_clic"))
	elif node is Slider:
		(node as Slider).value_changed.connect(_on_slider)


func _on_slider(_value: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick_ms >= TICK_MS:
		_last_tick_ms = now
		_play("ui_tic")
