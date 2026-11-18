class_name GameSettings
extends RefCounted
## Ajustes del jugador (PLAN F9): velocidad de las animaciones del combate,
## pantalla completa y volumen de cada canal de sonido. Se guardan aparte de
## la partida, en user://settings.cfg. Es presentacion: no cambia ninguna
## regla del juego.

const PATH := "user://settings.cfg"
## Velocidades de las animaciones que se pueden elegir (multiplican el ritmo
## normal del combate).
const SPEEDS: Array[float] = [1.0, 1.5, 2.0, 3.0]
## Canales de sonido: el general y uno por tipo de sonido.
const BUSES: Array[String] = ["Master", "Music", "Effects", "Interface"]
const DEFAULT_VOLUMES: Dictionary[String, float] = {
	"Master": 1.0, "Music": 0.8, "Effects": 0.8, "Interface": 0.8
}

var speed_index: int = 0
var fullscreen: bool = false
## Volumen de cada canal, de 0 (silencio) a 1.
var volumes: Dictionary[String, float] = DEFAULT_VOLUMES.duplicate()


## Multiplicador de la velocidad de las animaciones.
func speed() -> float:
	return SPEEDS[clampi(speed_index, 0, SPEEDS.size() - 1)]


## Lee los ajustes guardados; lo que falte o este fuera de rango vuelve a su
## valor por defecto o al limite.
static func load_from(path: String = PATH) -> GameSettings:
	var out := GameSettings.new()
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return out
	out.speed_index = clampi(int(file.get_value("battle", "speed_index", 0)), 0, SPEEDS.size() - 1)
	out.fullscreen = bool(file.get_value("display", "fullscreen", false))
	for bus in BUSES:
		var value := float(file.get_value("audio", bus, DEFAULT_VOLUMES[bus]))
		out.volumes[bus] = clampf(value, 0.0, 1.0)
	return out


func save_to(path: String = PATH) -> Error:
	var file := ConfigFile.new()
	file.set_value("battle", "speed_index", speed_index)
	file.set_value("display", "fullscreen", fullscreen)
	for bus in BUSES:
		file.set_value("audio", bus, volumes[bus])
	return file.save(path)


## Pone el volumen de cada canal (creando los que falten) y la pantalla
## completa o la ventana. Sin ventana (pruebas) solo toca el sonido.
func apply() -> void:
	ensure_buses()
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		var linear: float = volumes[bus]
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.0)
	if DisplayServer.get_name() == "headless":
		return
	var mode := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Crea los canales de sonido que falten, todos mandando al general.
static func ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "Master")
