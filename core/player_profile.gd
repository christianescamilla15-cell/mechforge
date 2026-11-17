class_name PlayerProfile
extends RefCounted
## Lo que el jugador conserva entre combates: su oro, las mejoras compradas
## en la tienda de arena y su historial. Se guarda en JSON con version de
## esquema (CLAUDE.md, regla 6).

const SCHEMA_VERSION := 1

var gold: int = 0
## Nivel comprado de cada mejora de la tienda de arena: {id: nivel}.
var shop_levels: Dictionary[String, int] = {}
var wins: int = 0
var losses: int = 0
var boss_wins: int = 0


## Cobra el oro de un combate terminado y lo apunta en el historial.
## Devuelve el oro ganado.
func earn(shop: ArenaShop, won: bool, against_boss: bool) -> int:
	var kind := "loss"
	if won:
		kind = "boss_win" if against_boss else "win"
		wins += 1
		if against_boss:
			boss_wins += 1
	else:
		losses += 1
	var amount := shop.reward(kind)
	gold += amount
	return amount


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
		return "falta oro"
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
		"wins": wins,
		"losses": losses,
		"boss_wins": boss_wins,
	}


static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	# Version 1 es la primera; aqui iran las migraciones cuando cambie.
	profile.gold = maxi(0, int(data.get("gold", 0)))
	profile.wins = int(data.get("wins", 0))
	profile.losses = int(data.get("losses", 0))
	profile.boss_wins = int(data.get("boss_wins", 0))
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
