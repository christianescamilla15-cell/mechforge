class_name PlayerProfile
extends RefCounted
## Lo que el jugador conserva entre combates: sus celdas, las mejoras
## compradas en la armeria, la clase y el nivel de cada pieza, su avance en
## la campana y su historial. Se guarda
## en JSON con version de esquema (CLAUDE.md, regla 6).
## La moneda se llama `gold` en el codigo y en el guardado; en pantalla se
## muestra con el nombre de la tabla de textos (GDD 8).

const SCHEMA_VERSION := 8

var gold: int = 0
## Experiencia total; de ella sale el nivel del jugador (Progression).
var xp: int = 0
## Habilidades aprendidas del arbol (ids de data/skills.json).
var skills: Array[String] = []
## Nivel comprado de cada mejora de la armeria: {id: nivel}.
var shop_levels: Dictionary[String, int] = {}
## Clase y nivel de cada pieza, por id del catalogo: {id: {"tier", "level"}}.
## Las que no estan van en clase Basica nivel 0. Dos piezas iguales del mech
## suben juntas.
var parts: Dictionary[String, Dictionary] = {}
## Nucleos unicos: los sueltan los 3 ultimos jefes y cada uno transforma una
## pieza Mitica al maximo en Unica (GDD 8).
var unique_cores: int = 0
## Piezas que tiene (ids del catalogo). Una pieza que se tiene se puede
## montar en tantos huecos como quiera; las copias suben juntas.
var owned: Array[String] = []
## Sus robots (GDD 8, garaje): hasta RulesConfig.max_mechs, cada uno
## {"name", "design", "build"}. "design" es el mech de ejemplo del que salio
## ("" si se armo desde un armazon vacio). Todos comparten las piezas que
## tiene el jugador (owned) y su clase y nivel (parts).
var mechs: Array[Dictionary] = []
## El que usa: el que pelea y el que se arma en el taller.
var active: int = 0
## El robot que usa, con el formato de los "items" de data/builds.json
## (Garage). Vacio si no tiene ninguno. Cambiarlo cambia ese robot.
var build: Dictionary:
	get:
		return mechs[active]["build"] if active < mechs.size() else {}
	set(value):
		if active < mechs.size():
			mechs[active]["build"] = value
		elif not value.is_empty():
			mechs.append({"name": "", "design": "", "build": value})
			active = mechs.size() - 1
## Mech de ejemplo con el que empezo la partida (id de data/builds.json).
var mech: String = ""
## Avance en la campana: zona en la que esta y combates ganados en ella.
## Cuando `fight` llega al numero de combates de la zona, toca el jefe.
var zone: int = 0
var fight: int = 0
## La campana de su liga esta en marcha: empezo su primer combate y aun no
## la ha terminado ni la ha perdido. Mientras, la arena y el combate libre
## estan cerrados (Campaign.mode_locked).
var campaign_on: bool = false
## Protecciones compradas para la campana, por tipo (Campaign.PROTECTIONS):
## cuantas lleva de cada una (0 o 1). Se gastan al perder.
var protections: Dictionary[String, int] = {}
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
func earn(shop: ArenaShop, kind: String, mult: float = 1.0) -> int:
	if kind.ends_with("_win"):
		wins += 1
		if kind == "boss_win":
			boss_wins += 1
			best_boss_wins = maxi(best_boss_wins, boss_wins)
	else:
		losses += 1
	var amount := roundi(shop.reward(kind) * mult)
	gold += amount
	return amount


## Empieza una partida con uno de los mechs de ejemplo: sus piezas pasan a
## ser del jugador y quedan montadas en su primer robot.
func start_run(library: BuildLibrary, mech_id: String) -> void:
	mech = mech_id
	mechs.clear()
	(
		mechs
		. append(
			{
				"name": library.display_name(mech_id),
				"design": mech_id,
				"build": library.specs[mech_id]["items"].duplicate(true),
			}
		)
	)
	active = 0
	owned.clear()
	for id in library.item_ids(mech_id):
		owned.append(id)


func has_mech() -> bool:
	return not mechs.is_empty()


## Devuelve "" si cabe otro robot; si no, el motivo.
func why_cant_add_mech(rules: RulesConfig) -> String:
	if mechs.size() >= rules.max_mechs:
		return "ya tienes %d robots" % rules.max_mechs
	return ""


## Adquiere un armazon vacio, gratis: se arma en el taller con las piezas que
## ya tiene. Pasa a ser el que usa. Devuelve "" o el motivo.
func add_frame(rules: RulesConfig, display_name: String) -> String:
	var reason := why_cant_add_mech(rules)
	if reason != "":
		return reason
	mechs.append({"name": display_name, "design": "", "build": {}})
	active = mechs.size() - 1
	return ""


## Pasa a usar otro de sus robots.
func select_mech(index: int) -> void:
	if index >= 0 and index < mechs.size():
		active = index


## Desmonta un robot (no el ultimo): sus piezas se quedan en el inventario.
func remove_mech(index: int) -> String:
	if index < 0 or index >= mechs.size():
		return "ese robot no existe"
	if mechs.size() == 1:
		return "es tu unico robot"
	mechs.remove_at(index)
	if active > index or active >= mechs.size():
		active = maxi(0, active - 1)
	return ""


## Termina la partida (GDD 9: perder contra un jefe): se pierde todo menos el
## historial, y se vuelve al principio.
func end_run() -> void:
	best_boss_wins = maxi(best_boss_wins, boss_wins)
	runs_lost += 1
	gold = 0
	xp = 0
	skills.clear()
	shop_levels.clear()
	parts.clear()
	unique_cores = 0
	owned.clear()
	mechs.clear()
	active = 0
	mech = ""
	zone = 0
	fight = 0
	campaign_on = false
	protections.clear()
	wins = 0
	losses = 0
	boss_wins = 0


func level_of(track: String) -> int:
	return shop_levels.get(track, 0)


## Devuelve "" si se puede comprar el siguiente nivel de esa mejora; si no,
## el motivo. La zona pone un tope a la armeria: `cap` (Campaign.armory_cap).
func why_cant_buy(shop: ArenaShop, track: String, cap: int = 999) -> String:
	if not shop.tracks.has(track):
		return "esa mejora no existe"
	if part(ItemDef.ASSIST_PROGRESS)["tier"] < shop.assist_tier(track):
		return "se abre con la primera transformacion del asistente"
	var next := level_of(track) + 1
	if next > shop.max_level():
		return "ya esta al maximo"
	if next > cap:
		return "la zona no deja subirla mas"
	if shop.price(next) > gold:
		return "faltan celdas"
	return ""


## Clase y nivel de una pieza: {"tier", "level"}.
func part(id: String) -> Dictionary:
	return parts.get(id, {"tier": 0, "level": 0}).duplicate()


## Devuelve "" si se puede subir esa pieza un nivel; si no, el motivo.
## La zona pone un tope a las piezas de su clase: `cap_tier` y `cap_level`
## (Campaign.tier_of y level_cap). Sin tope, llegan al maximo de su clase.
func why_cant_level(
	workshop: Workshop,
	rules: RulesConfig,
	id: String,
	cap_tier: int = ItemDef.Tier.DIVINE,
	cap_level: int = 999
) -> String:
	var p := part(id)
	if p["level"] >= rules.tier_max_level[p["tier"]]:
		return "esta al nivel maximo de su clase"
	if p["tier"] == cap_tier and p["level"] >= cap_level:
		return "la zona no deja subirla mas"
	if workshop.level_cost(rules, p["tier"], p["level"]) > gold:
		return "faltan celdas"
	return ""


## Sube esa pieza un nivel. Devuelve "" o el motivo del fallo.
func level_up(
	workshop: Workshop,
	rules: RulesConfig,
	id: String,
	cap_tier: int = ItemDef.Tier.DIVINE,
	cap_level: int = 999
) -> String:
	var reason := why_cant_level(workshop, rules, id, cap_tier, cap_level)
	if reason != "":
		return reason
	var p := part(id)
	gold -= workshop.level_cost(rules, p["tier"], p["level"])
	parts[id] = {"tier": p["tier"], "level": p["level"] + 1}
	return ""


## Devuelve "" si se puede transformar esa pieza a la clase siguiente; si
## no, el motivo. `max_tier` es la clase mas alta que permite la zona.
## `item_max` es la clase mas alta de esa pieza (ItemDef.tier_max): un arma
## no pasa del rango de su tipo; para ir mas alla hay que conseguir otra.
func why_cant_transform(
	workshop: Workshop,
	rules: RulesConfig,
	id: String,
	max_tier: int,
	item_max: int = ItemDef.Tier.MYTHIC
) -> String:
	var p := part(id)
	if p["tier"] >= ItemDef.Tier.DIVINE:
		return "ya es una pieza unica"
	if p["level"] < rules.tier_max_level[p["tier"]]:
		return "primero hay que llevarla al nivel maximo"
	if p["tier"] + 1 == ItemDef.Tier.DIVINE:
		# A Unica solo se llega con un nucleo unico, en cualquier zona.
		return "" if unique_cores > 0 else "las piezas unicas solo las sueltan los jefes"
	if p["tier"] + 1 > item_max:
		return "esta pieza no pasa de su clase"
	if p["tier"] + 1 > max_tier:
		return "la clase siguiente se abre en otra zona"
	if workshop.transform_cost(p["tier"]) > gold:
		return "faltan celdas"
	return ""


## Transforma esa pieza a la clase siguiente, en el nivel 0.
func transform(
	workshop: Workshop,
	rules: RulesConfig,
	id: String,
	max_tier: int,
	item_max: int = ItemDef.Tier.MYTHIC
) -> String:
	var reason := why_cant_transform(workshop, rules, id, max_tier, item_max)
	if reason != "":
		return reason
	var p := part(id)
	if p["tier"] + 1 == ItemDef.Tier.DIVINE:
		unique_cores -= 1
	else:
		gold -= workshop.transform_cost(p["tier"])
	parts[id] = {"tier": p["tier"] + 1, "level": 0}
	return ""


## Compra el siguiente nivel de una mejora. Devuelve "" o el motivo del fallo.
func buy(shop: ArenaShop, track: String, cap: int = 999) -> String:
	var reason := why_cant_buy(shop, track, cap)
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
		"xp": xp,
		"skills": skills.duplicate(),
		"shop_levels": shop_levels.duplicate(),
		"parts": parts.duplicate(true),
		"unique_cores": unique_cores,
		"owned": owned.duplicate(),
		"mechs": mechs.duplicate(true),
		"active": active,
		"mech": mech,
		"zone": zone,
		"fight": fight,
		"campaign_on": campaign_on,
		"protections": protections.duplicate(),
		"wins": wins,
		"losses": losses,
		"boss_wins": boss_wins,
		"runs_lost": runs_lost,
		"best_boss_wins": best_boss_wins,
	}


## Migraciones: la version 1 no tenia campana ni mech elegido, la 2 no tenia
## piezas, la 3 no tenia mech armado, la 4 no tenia experiencia, hasta la 6
## habia un solo mech ("build"), que pasa a ser el primer robot, y hasta la 7
## no habia campana en marcha ni protecciones; los campos nuevos empiezan
## vacios y lo demas se conserva. Sin robots, el menu pide elegir uno.
static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.gold = maxi(0, int(data.get("gold", 0)))
	profile.xp = maxi(0, int(data.get("xp", 0)))
	for id: Variant in data.get("skills", []):
		profile.skills.append(str(id))
	profile.mech = str(data.get("mech", ""))
	profile.unique_cores = maxi(0, int(data.get("unique_cores", 0)))
	for id: Variant in data.get("owned", []):
		if not str(id) in profile.owned:
			profile.owned.append(str(id))
	var saved_mechs: Variant = data.get("mechs")
	if saved_mechs is Array:
		for raw: Variant in saved_mechs:
			if raw is Dictionary and raw.get("build") is Dictionary:
				(
					profile
					. mechs
					. append(
						{
							"name": str(raw.get("name", "")),
							"design": str(raw.get("design", "")),
							"build": raw["build"],
						}
					)
				)
		profile.active = clampi(int(data.get("active", 0)), 0, maxi(0, profile.mechs.size() - 1))
	elif data.get("build") is Dictionary and not (data["build"] as Dictionary).is_empty():
		profile.mechs.append({"name": "", "design": profile.mech, "build": data["build"]})
	profile.zone = maxi(0, int(data.get("zone", 0)))
	profile.fight = maxi(0, int(data.get("fight", 0)))
	# Hasta la version 7 la campana no se "empezaba": lo esta quien ya ha
	# ganado algun combate de su liga.
	profile.campaign_on = bool(data.get("campaign_on", profile.fight > 0))
	var saved_protections: Variant = data.get("protections", {})
	if saved_protections is Dictionary:
		for kind: String in saved_protections:
			profile.protections[kind] = clampi(int(saved_protections[kind]), 0, 1)
	profile.wins = int(data.get("wins", 0))
	profile.losses = int(data.get("losses", 0))
	profile.boss_wins = int(data.get("boss_wins", 0))
	profile.runs_lost = int(data.get("runs_lost", 0))
	profile.best_boss_wins = maxi(int(data.get("best_boss_wins", 0)), profile.boss_wins)
	var saved_parts: Variant = data.get("parts", {})
	if saved_parts is Dictionary:
		for id: String in saved_parts:
			var raw: Variant = saved_parts[id]
			if raw is Dictionary:
				var tier := clampi(int(raw.get("tier", 0)), 0, ItemDef.Tier.DIVINE)
				profile.parts[id] = {"tier": tier, "level": maxi(0, int(raw.get("level", 0)))}
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
