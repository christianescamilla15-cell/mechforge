class_name PlayerProfile
extends RefCounted
## Lo que el jugador conserva entre combates: sus celdas, las mejoras
## compradas en la armeria, su avance en la campana y su historial. Se guarda
## en JSON con version de esquema (CLAUDE.md, regla 6).
## La moneda se llama `gold` en el codigo y en el guardado; en pantalla se
## muestra con el nombre de la tabla de textos (GDD 8).

const SCHEMA_VERSION := 2

var gold: int = 0
## Nivel comprado de cada mejora de la armeria: {id: nivel}.
var shop_levels: Dictionary[String, int] = {}
## Mech con el que pelea (id de data/builds.json); "" = el primero.
var mech: String = ""
## Avance en la campana: zona en la que esta y combates ganados en ella.
## Cuando `fight` llega al numero de combates de la zona, toca el jefe.
var zone: int = 0
var fight: int = 0
var wins: int = 0
var losses: int = 0
var boss_wins: int = 0
## Historial que sobrevive al final de una partida.
var runs_lost: int = 0
var best_boss_wins: int = 0


## Cobra las celdas de un combate terminado y lo apunta en el historial.
## `kind` es una recompensa de la armeria: "arena_win", "arena_loss",
## "campaign_win", "campaign_loss", "boss_win" o "boss_loss".
## Devuelve lo cobrado.
func earn(shop: ArenaShop, kind: String) -> int:
	if kind.ends_with("_win"):
		wins += 1
		if kind == "boss_win":
			boss_wins += 1
			best_boss_wins = maxi(best_boss_wins, boss_wins)
	else:
		losses += 1
	var amount := shop.reward(kind)
	gold += amount
	return amount


## Termina la partida (GDD 9: perder contra un jefe): se pierde todo menos el
## historial, y se vuelve al principio.
func end_run() -> void:
	best_boss_wins = maxi(best_boss_wins, boss_wins)
	runs_lost += 1
	gold = 0
	shop_levels.clear()
	zone = 0
	fight = 0
	wins = 0
	losses = 0
	boss_wins = 0


func level_of(track: String) -> int:
	return shop_levels.get(track, 0)


## Devuelve "" si se puede comprar el siguiente nivel de esa mejora; si no,
## el motivo.
func why_cant_buy(shop: ArenaShop, track: String) -> String:
	if not shop.tracks.has(track):
		return "esa mejora no existe"
	var next := level_of(track) + 1
	if next > shop.max_level():
		return "ya esta al maximo"
	if shop.price(next) > gold:
		return "faltan celdas"
	return ""


## Compra el siguiente nivel de una mejora. Devuelve "" o el motivo del fallo.
func buy(shop: ArenaShop, track: String) -> String:
	var reason := why_cant_buy(shop, track)
	if reason != "":
		return reason
	var next := level_of(track) + 1
	gold -= shop.price(next)
	shop_levels[track] = next
	return ""


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"gold": gold,
		"shop_levels": shop_levels.duplicate(),
		"mech": mech,
		"zone": zone,
		"fight": fight,
		"wins": wins,
		"losses": losses,
		"boss_wins": boss_wins,
		"runs_lost": runs_lost,
		"best_boss_wins": best_boss_wins,
	}


## Migraciones: la version 1 no tenia campana ni mech elegido; sus campos
## nuevos empiezan en cero y lo demas se conserva.
static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.gold = maxi(0, int(data.get("gold", 0)))
	profile.mech = str(data.get("mech", ""))
	profile.zone = maxi(0, int(data.get("zone", 0)))
	profile.fight = maxi(0, int(data.get("fight", 0)))
	profile.wins = int(data.get("wins", 0))
	profile.losses = int(data.get("losses", 0))
	profile.boss_wins = int(data.get("boss_wins", 0))
	profile.runs_lost = int(data.get("runs_lost", 0))
	profile.best_boss_wins = maxi(int(data.get("best_boss_wins", 0)), profile.boss_wins)
	var levels: Variant = data.get("shop_levels", {})
	if levels is Dictionary:
		for track: String in levels:
			profile.shop_levels[track] = maxi(0, int(levels[track]))
	return profile


func save(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	return true


## Carga el perfil guardado; si no existe o esta roto, empieza uno nuevo.
static func load_or_new(path: String) -> PlayerProfile:
	if FileAccess.file_exists(path):
		# JSON.parse no escribe un error en el registro si el archivo esta roto.
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
			return from_dict(json.data)
	return PlayerProfile.new()
