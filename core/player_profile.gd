class_name PlayerProfile
extends RefCounted
## Lo que el jugador conserva entre combates: sus celdas, las mejoras
## compradas en la armeria, la clase y el nivel de cada pieza, su avance en
## la campana y su historial. Se guarda
## en JSON con version de esquema (CLAUDE.md, regla 6).
## La moneda se llama `gold` en el codigo y en el guardado; en pantalla se
## muestra con el nombre de la tabla de textos (GDD 8).

const SCHEMA_VERSION := 11
## Familia de los modulos que habia antes de las familias (OBS-040): los de
## los rivales y los de las partidas de la version 10.
const LEGACY_MODULE_FAMILY := {
	"mod_blindaje": "resistencia",
	"mod_placas": "resistencia",
	"mod_aislante": "resistencia",
	"mod_faraday": "resistencia",
	"mod_matriz": "resistencia",
	"mod_bateria": "sistemas",
	"mod_generador": "sistemas",
	"mod_sumidero": "sistemas",
	"mod_disipador": "sistemas",
	"mod_nucleo_dual": "sistemas",
}

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
## Aspectos de cada pieza (PieceAspects, OBS-051): clave de progreso de la
## pieza -> {aspecto: nivel}.
var aspects: Dictionary[String, Dictionary] = {}
## Armas de arena (ArenaGear, OBS-051): id -> rango (1 bronce, 2 plata, 3 oro).
var arena_gear: Dictionary[String, int] = {}
## Prototipos del especialista (GDD 8.6), por la clave de progreso de la
## pieza: {id del prototipo: rango}. Van con la pieza; se combinan.
var prototypes: Dictionary = {}
## Nucleos unicos: los sueltan los 3 ultimos jefes y cada uno transforma una
## pieza Mitica al maximo en Unica (GDD 8).
var unique_cores: int = 0
## Puntos de habilidad regalados, aparte de los del nivel (pedido del
## usuario el 2026-11-21: "me puedes dar 20 puntos de habilidad";
## tools/puntos.ps1). SkillTree.points_left los suma.
var skill_bonus: int = 0
## La racha de la arena (OBS-049): el bote sin cobrar, los combates ganados
## en ella y si hay uno en marcha con bote en juego (Campaign.begin_arena).
var arena_pot: int = 0
var arena_streak: int = 0
var arena_live: bool = false
## Puntos de mejora (OBS-051): se ganan en la racha de la arena y se gastan
## en las ramas del arbol que salen de la armeria. `arena_points` es el bote
## de puntos sin cobrar de la racha en marcha; se pierde con el de celdas.
var upgrade_points: int = 0
var arena_points: int = 0
## Nodos aprendidos del arbol de mejoras (UpgradeTree).
var tree: Array[String] = []
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
## Tipo del robot que usa (StyleLibrary); "" en los robots de antes de que
## hubiera tipos, que montan cualquier arma.
var style: String:
	get:
		if active < 0 or active >= mechs.size():
			return ""
		return str((mechs[active] as Dictionary).get("style", ""))
## Viene de un guardado en el que el asistente se regalaba: lo conserva
## (Garage.ensure_assist). No se guarda.
var legacy_assist: bool = false
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


## Empieza una partida con un robot de ese tipo (StyleLibrary): el cuerpo
## y una sola arma, que pasan a ser del jugador y quedan montados.
func start_style(styles: StyleLibrary, style_id: String) -> void:
	mech = style_id
	mechs.clear()
	(
		mechs
		. append(
			{
				"name": styles.display_name(style_id),
				"design": "",
				"style": style_id,
				"build": styles.build(style_id),
			}
		)
	)
	active = 0
	owned.clear()
	for id in styles.item_ids(style_id):
		owned.append(id)


## Empieza una partida con uno de los mechs de ejemplo, ya armado: sus piezas
## pasan a ser del jugador y quedan montadas en su primer robot. Es un robot
## sin tipo (monta cualquier arma): lo usan las pruebas y los simuladores.
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
	# Los modulos del rival, cada uno en un hueco de su familia.
	place_modules(mechs[0]["build"])
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


## Adquiere un armazon vacio, gratis, del tipo que se diga: se arma en el
## taller con las piezas que ya tiene. Pasa a ser el que usa. Devuelve "" o
## el motivo.
func add_frame(rules: RulesConfig, display_name: String, style_id: String = "") -> String:
	var reason := why_cant_add_mech(rules)
	if reason != "":
		return reason
	mechs.append({"name": display_name, "design": "", "style": style_id, "build": {}})
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
	aspects.clear()
	arena_gear.clear()
	unique_cores = 0
	skill_bonus = 0
	arena_pot = 0
	arena_streak = 0
	arena_live = false
	upgrade_points = 0
	arena_points = 0
	tree.clear()
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
func why_cant_buy(shop: ArenaShop, track: String, cap: int = 999, player_level: int = 0) -> String:
	if not shop.tracks.has(track):
		return "esa mejora no existe"
	if part(ItemDef.ASSIST_PROGRESS)["tier"] < shop.assist_tier(track):
		return "se abre con la primera transformacion del asistente"
	if player_level < shop.player_level(track):
		return "se abre en el nivel %d" % shop.player_level(track)
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


## Un arma al maximo de su clase que ya no puede pasar de clase porque su tipo
## no llega (el canon, hasta Avanzada) evoluciona en la del tipo siguiente,
## con su forma y su elemento, una clase mas arriba (OBS-045, del usuario:
## "ya no hay mas armas para seguir subiendolas de nivel").
## Devuelve "" si se puede; si no, el motivo.
func why_cant_evolve(
	workshop: Workshop, rules: RulesConfig, catalog: Catalog, id: String, max_tier: int
) -> String:
	var def := catalog.get_item(id)
	if def == null:
		return "no existe esa pieza"
	var p := part(id)
	if p["level"] < rules.tier_max_level[p["tier"]]:
		return "primero hay que llevarla al nivel maximo"
	if p["tier"] < def.tier_max or p["tier"] + 1 >= ItemDef.Tier.DIVINE:
		return "no evoluciona: se transforma"
	if catalog.successor(def, p["tier"] + 1) == null:
		return "esta pieza no pasa de su clase"
	if p["tier"] + 1 > max_tier:
		return "la clase siguiente se abre en otra zona"
	if workshop.transform_cost(p["tier"]) > gold:
		return "faltan celdas"
	return ""


## La evoluciona: el arma nueva sustituye a la vieja en tu inventario y en tus
## robots (mismo hueco y pintura), empieza en la clase siguiente a nivel 0 y
## se lleva sus prototipos. Devuelve "" o el motivo del fallo.
func evolve(
	workshop: Workshop, rules: RulesConfig, catalog: Catalog, id: String, max_tier: int
) -> String:
	var why := why_cant_evolve(workshop, rules, catalog, id, max_tier)
	if why != "":
		return why
	var p := part(id)
	var next := catalog.successor(catalog.get_item(id), p["tier"] + 1)
	gold -= workshop.transform_cost(p["tier"])
	owned.erase(id)
	if not next.id in owned:
		owned.append(next.id)
	for robot: Dictionary in mechs:
		_swap_item(robot["build"], id, next.id)
	var fresh := {"tier": p["tier"] + 1, "level": 0}
	var had := part(next.id)
	if parts.has(next.id) and (had["tier"] > fresh["tier"]):
		fresh = had
	parts.erase(id)
	parts[next.id] = fresh
	# Sus aspectos van con ella a la pieza nueva (lo mas alto de cada uno).
	if aspects.has(id):
		var into: Dictionary = aspects.get(next.id, {}).duplicate()
		for aspect: String in aspects[id]:
			into[aspect] = maxi(int(into.get(aspect, 0)), int(aspects[id][aspect]))
		aspects.erase(id)
		aspects[next.id] = into
	if prototypes.has(id):
		var moved: Dictionary = prototypes[id]
		var into: Dictionary = prototypes.get(next.id, {})
		for proto: String in moved:
			into[proto] = maxi(int(into.get(proto, 0)), int(moved[proto]))
		prototypes[next.id] = into
		prototypes.erase(id)
	return ""


## Un arma del asistente sube con el, sin salirse del rango de su tipo: cuando
## el asistente pasa del tope de ese tipo, evoluciona en la del tipo siguiente
## que llega a su clase (OBS-045). Devuelve "" si se puede; si no, el motivo.
func why_cant_evolve_with_assist(workshop: Workshop, catalog: Catalog, id: String) -> String:
	var def := catalog.get_item(id)
	if def == null or def.type != ItemDef.Type.DRONE:
		return "no es un arma del asistente"
	var tier: int = part(ItemDef.ASSIST_PROGRESS)["tier"]
	if tier <= def.tier_max:
		return "aun sube con el asistente"
	if catalog.successor(def, tier) == null:
		return "esta pieza no pasa de su clase"
	if workshop.transform_cost(def.tier_max) > gold:
		return "faltan celdas"
	return ""


func evolve_with_assist(workshop: Workshop, catalog: Catalog, id: String) -> String:
	var why := why_cant_evolve_with_assist(workshop, catalog, id)
	if why != "":
		return why
	var def := catalog.get_item(id)
	var next := catalog.successor(def, part(ItemDef.ASSIST_PROGRESS)["tier"])
	gold -= workshop.transform_cost(def.tier_max)
	if not next.id in owned:
		owned.append(next.id)
	for robot: Dictionary in mechs:
		_swap_item(robot["build"], id, next.id)
	if prototypes.has(id):
		prototypes[next.id] = prototypes[id]
		prototypes.erase(id)
	return ""


static func _swap_item(build: Dictionary, old: String, new: String) -> void:
	for key: String in build.keys():
		var value: Variant = build[key]
		if value is Array:
			var list: Array = value
			for i in list.size():
				if str(list[i]) == old:
					list[i] = new
		elif value is String and value == old:
			build[key] = new


## Compra el siguiente nivel de una mejora. Devuelve "" o el motivo del fallo.
func buy(shop: ArenaShop, track: String, cap: int = 999, player_level: int = 0) -> String:
	var reason := why_cant_buy(shop, track, cap, player_level)
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
		"aspects": aspects.duplicate(true),
		"arena_gear": arena_gear.duplicate(),
		"prototypes": prototypes.duplicate(true),
		"unique_cores": unique_cores,
		"skill_bonus": skill_bonus,
		"arena_pot": arena_pot,
		"arena_streak": arena_streak,
		"arena_live": arena_live,
		"upgrade_points": upgrade_points,
		"arena_points": arena_points,
		"tree": tree.duplicate(),
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
## habia un solo mech ("build"), que pasa a ser el primer robot, hasta la 7
## no habia campana en marcha ni protecciones, hasta la 8 no habia tipos de
## robot (_from_before_styles) y hasta la 9 habia cuatro armas de brazo y dos
## de hombro (_to_three_weapons); los campos nuevos empiezan vacios y lo
## demas se conserva. Sin robots, el menu pide elegir uno.
static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.gold = maxi(0, int(data.get("gold", 0)))
	profile.xp = maxi(0, int(data.get("xp", 0)))
	for id: Variant in data.get("skills", []):
		profile.skills.append(str(id))
	profile.mech = str(data.get("mech", ""))
	profile.unique_cores = maxi(0, int(data.get("unique_cores", 0)))
	profile.skill_bonus = maxi(0, int(data.get("skill_bonus", 0)))
	profile.arena_pot = maxi(0, int(data.get("arena_pot", 0)))
	profile.arena_streak = maxi(0, int(data.get("arena_streak", 0)))
	profile.arena_live = bool(data.get("arena_live", false))
	profile.upgrade_points = maxi(0, int(data.get("upgrade_points", 0)))
	profile.arena_points = maxi(0, int(data.get("arena_points", 0)))
	for id: Variant in data.get("tree", []):
		if not str(id) in profile.tree:
			profile.tree.append(str(id))
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
							"style": str(raw.get("style", "")),
							"build": raw["build"],
						}
					)
				)
		profile.active = clampi(int(data.get("active", 0)), 0, maxi(0, profile.mechs.size() - 1))
	elif data.get("build") is Dictionary and not (data["build"] as Dictionary).is_empty():
		profile.mechs.append(
			{"name": "", "design": profile.mech, "style": "", "build": data["build"]}
		)
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
	var saved_aspects: Variant = data.get("aspects", {})
	if saved_aspects is Dictionary:
		for id: String in saved_aspects:
			var raw: Variant = saved_aspects[id]
			if not raw is Dictionary:
				continue
			var levels := {}
			for aspect: Variant in raw:
				var level := int(raw[aspect])
				if level > 0:
					levels[str(aspect)] = level
			if not levels.is_empty():
				profile.aspects[id] = levels
	var saved_gear: Variant = data.get("arena_gear", {})
	if saved_gear is Dictionary:
		for id: Variant in saved_gear:
			var rank := int(saved_gear[id])
			if rank > 0:
				profile.arena_gear[str(id)] = rank
	var saved_protos: Variant = data.get("prototypes", {})
	if saved_protos is Dictionary:
		for key: String in saved_protos:
			var entry: Variant = saved_protos[key]
			if not entry is Dictionary:
				continue
			# Hasta la primera version era uno por pieza: {"id", "rank"}.
			if entry.has("id") and entry.has("rank"):
				entry = {str(entry["id"]): int(entry["rank"])}
			var mounted := {}
			for id: Variant in entry:
				mounted[str(id)] = clampi(int(entry[id]), 1, 5)
			profile.prototypes[key] = mounted
	var levels: Variant = data.get("shop_levels", {})
	if levels is Dictionary:
		for track: String in levels:
			profile.shop_levels[track] = maxi(0, int(levels[track]))
	if int(data.get("schema_version", 1)) < 9:
		profile._from_before_styles()
	if int(data.get("schema_version", 1)) < 10:
		profile._to_three_weapons()
	if int(data.get("schema_version", 1)) < 11:
		profile._to_module_families()
	return profile


## Hasta la version 9 habia cuatro armas de brazo y dos de hombro, y los
## rifles ("largo_...") iban en el brazo (OBS-033). Cada robot se queda con
## sus dos primeras armas de brazo y su primera de hombro; si llevaba un
## rifle y el hombro estaba libre, el rifle pasa al hombro. Lo que no cabe
## sigue siendo suyo: solo se desmonta.
## Hasta la version 10 los ocho huecos de modulo montaban cualquiera (y el
## mismo dos veces). Desde la 11 son tres familias de tres (OBS-040): cada
## modulo pasa, en el orden en que iba, al primer hueco libre de su familia;
## el que no cabe o se repetia se queda en el inventario.
func _to_module_families() -> void:
	for robot: Dictionary in mechs:
		place_modules(robot["build"])


## Pone los modulos de un equipo (una lista suelta, como la de los rivales)
## cada uno en el primer hueco libre de su familia, en el orden en que iban.
## Los de familia desconocida, los repetidos y los que no caben se quitan.
static func place_modules(build: Dictionary) -> void:
	var placed: Array = []
	placed.resize(Garage.MODULE_FAMILIES.size())
	placed.fill("")
	for id: Variant in build.get("modules", []):
		var text := str(id) if id != null else ""
		var family := str(LEGACY_MODULE_FAMILY.get(text, ""))
		if family == "" or text in placed:
			continue
		for index in placed.size():
			if Garage.MODULE_FAMILIES[index] == family and str(placed[index]) == "":
				placed[index] = text
				break
	while not placed.is_empty() and str(placed[-1]) == "":
		placed.pop_back()
	if placed.is_empty():
		build.erase("modules")
	else:
		build["modules"] = placed


func _to_three_weapons() -> void:
	for robot: Dictionary in mechs:
		var build: Dictionary = robot["build"]
		var before := {
			"side0": Garage.get_slot(build, "side0"),
			"side1": Garage.get_slot(build, "side1"),
			"top0": Garage.get_slot(build, "top0"),
		}
		var sides: Array = []
		var rifles: Array = []
		for id: Variant in build.get("sides", []):
			var text := str(id) if id != null else ""
			if text.begins_with("largo_"):
				rifles.append(text)
			elif text != "" and sides.size() < MechBuild.SIDE_SLOTS:
				sides.append(text)
		var tops: Array = []
		for id: Variant in build.get("tops", []):
			if id != null and str(id) != "" and tops.size() < MechBuild.TOP_SLOTS:
				tops.append(str(id))
		if tops.is_empty() and not rifles.is_empty():
			tops.append(rifles[0])
		for key: String in ["sides", "tops"]:
			var list: Array = sides if key == "sides" else tops
			if list.is_empty():
				build.erase(key)
			else:
				build[key] = list
		# La pintura se queda donde sigue la misma arma; la de los huecos que
		# ya no existen, o que cambiaron de arma, se va.
		if build.get("paint") is Dictionary:
			var paint: Dictionary = build["paint"]
			for slot: String in ["side0", "side1", "side2", "side3", "top0", "top1"]:
				if not before.has(slot) or Garage.get_slot(build, slot) != before[slot]:
					paint.erase(slot)
			if paint.is_empty():
				build.erase("paint")


## Hasta la version 8 se empezaba con un robot ya armado y con el asistente
## regalado. Quien ya iba jugando conserva su robot (sin tipo: monta todo) y
## su asistente; una partida recien empezada, sin nada ganado ni comprado,
## vuelve a elegir robot con las reglas de ahora.
func _from_before_styles() -> void:
	var untouched := (
		wins + losses + gold + xp + zone + fight + unique_cores == 0
		and skills.is_empty()
		and shop_levels.is_empty()
	)
	for id: String in parts:
		if int(parts[id]["tier"]) > 0 or int(parts[id]["level"]) > 0:
			untouched = false
	if untouched:
		mechs.clear()
		owned.clear()
		parts.clear()
		active = 0
		mech = ""
		campaign_on = false
	else:
		legacy_assist = has_mech()


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
