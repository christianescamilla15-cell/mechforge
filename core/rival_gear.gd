class_name RivalGear
extends RefCounted
## De donde sale la fuerza de los rivales de la racha y del Exterminio
## (OBS-057, del usuario: "el rival tiene mas energia y mas dano solo porque
## si, no hay una trazabilidad en base a las mejoras de sus armas y habilidad
## tecnica"). En vez de un plus de vida y dano, el rival lleva una parte
## (`share`, de 0 a 1) de las mismas mejoras que el jugador: su armeria, los
## aspectos de sus piezas, sus prototipos, el rango de sus armas de arena y
## su arbol de mejoras. Todo se ve en el monitor y en sus piezas. La parte
## de cada combate de la racha y de cada oleada esta en data/rival_gear.json.

## La parte de sus mejoras que lleva el rival en cada combate de la racha
## (desde 0) y, en el Exterminio, la de la primera oleada, lo que sube por
## oleada y su tope.
var streak: Array[float] = []
var wave_start: float = 0.0
var wave_step: float = 0.0
var wave_max: float = 1.0
var errors: Array[String] = []

## Los sistemas del juego (los pone quien lo usa).
var rules: RulesConfig
var catalog: Catalog
var shop: ArenaShop
var aspects: PieceAspects
var prototypes: PrototypeLibrary
var gear: ArenaGear
var tree: UpgradeTree
var skill_tree: SkillTree


static func load_file(path: String) -> RivalGear:
	var out := RivalGear.new()
	if not FileAccess.file_exists(path):
		out.errors.append("no existe %s" % path)
		return out
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		out.errors.append("%s no es un objeto JSON" % path)
		return out
	for share: Variant in (data as Dictionary).get("streak", []):
		out.streak.append(float(share))
	var waves: Dictionary = (data as Dictionary).get("exterminio", {})
	out.wave_start = float(waves.get("start", 0.0))
	out.wave_step = float(waves.get("per_wave", 0.0))
	out.wave_max = float(waves.get("max", 1.0))
	return out


## La parte del combate `step` de la racha (desde 0).
func share_for_streak(step: int) -> float:
	if streak.is_empty() or step < 0:
		return 0.0
	return streak[mini(step, streak.size() - 1)]


## La parte de la oleada `wave` del Exterminio (desde 0).
func share_for_wave(wave: int) -> float:
	return minf(wave_max, wave_start + wave_step * maxi(wave, 0))


## Lo que lleva el rival con esa parte de las mejoras del jugador:
## {"armory": {linea: nivel}, "aspects": nivel, "prototypes": {id: rango},
## "arena": rango, "tree": [nodos], "skills": [habilidades]}. `zone_armory`:
## la armeria del Orden de la zona, que lleva siempre; `training`: los puntos
## de entrenamiento que ya trae su combate (se queda con lo que mas sea).
func kit(player: PlayerProfile, share: float, zone_armory: int, training: int = 0) -> Dictionary:
	var armory := {}
	for track in shop.track_ids():
		var mine := int(player.shop_levels.get(track, 0))
		armory[track] = clampi(maxi(zone_armory, roundi(mine * share)), 0, shop.max_level())
	# Aspectos: la media de los suyos, en todas sus piezas.
	var total := 0
	var count := 0
	for levels: Variant in player.aspects.values():
		for level: Variant in (levels as Dictionary).values():
			total += int(level)
			count += 1
	var aspect_level := roundi(float(total) / maxf(1.0, count) * share)
	# Prototipos: el rango mas alto que tiene de cada uno.
	var protos := {}
	for mounted: Variant in player.prototypes.values():
		for id: String in mounted:
			var rank := roundi(int(mounted[id]) * share)
			if rank > 0:
				protos[id] = maxi(int(protos.get(id, 0)), rank)
	var arena := 0
	for rank: Variant in player.arena_gear.values():
		arena = maxi(arena, int(rank))
	var learned: Array[String] = []
	learned.assign(player.tree.slice(0, roundi(player.tree.size() * share)))
	# Su entrenamiento: las primeras habilidades que aprendio el jugador, o
	# las del combate si son mas.
	var trained: Array[String] = []
	trained.assign(player.skills.slice(0, roundi(player.skills.size() * share)))
	if trained.size() < training and skill_tree != null:
		trained = skill_tree.spread(training)
	return {
		"share": share,
		"armory": armory,
		"aspects": aspect_level,
		"prototypes": protos,
		"arena": roundi(arena * share),
		"tree": learned,
		"skills": trained,
	}


## Viste al rival con su kit, como el juego viste el robot del jugador: sus
## armas de brazo y hombro pasan a ser de arena (si le toca rango), y
## encima su entrenamiento (con las habilidades de su combate, `kits`), su
## armeria, sus prototipos, sus aspectos y su arbol.
func dress(build: MechBuild, rival_kit: Dictionary, kits: Dictionary = {}) -> void:
	if skill_tree != null:
		var trained: Array[String] = []
		trained.assign(rival_kit.get("skills", []))
		build.skills = skill_tree.effects_for(trained)
		build.skills.add(kits)
	var rank := int(rival_kit.get("arena", 0))
	if rank > 0:
		_to_arena(build, rank)
	build.upgrades = shop.upgrades_for(rival_kit.get("armory", {}))
	var temp := PlayerProfile.new()
	var protos: Dictionary = rival_kit.get("prototypes", {})
	var level := int(rival_kit.get("aspects", 0))
	var by_piece := {}
	for def: ItemDef in build.sides + build.tops + [build.chest, build.torso, build.legs]:
		if def == null:
			continue
		var piece := _piece_of(build, def)
		var mounted := {}
		for id: String in protos:
			if str(prototypes.defs.get(id, {}).get("piece", "")) == piece:
				mounted[id] = int(protos[id])
		if not mounted.is_empty():
			temp.prototypes[def.progress_id()] = mounted
		if level > 0 and piece != "legs":
			var levels := {}
			for aspect in aspects.ids_for(def):
				levels[aspect] = level
			if not levels.is_empty():
				by_piece[def.progress_id()] = levels
	prototypes.apply(build, temp)
	aspects.apply_build(build, by_piece)
	var learned: Array[String] = []
	learned.assign(rival_kit.get("tree", []))
	var grown := tree.effects_for(learned)
	build.skills.add(grown)
	build.upgrades.backfire += float(grown.get("backfire", 0.0))
	build.upgrades.assist += float(grown.get("assist", 0.0))


## Todo lo que lleva un rival de la racha o del Exterminio (`fight`, de
## Campaign: "streak" y, en el Exterminio, "wave" y "robot"): su kit, con la
## parte que toca, y sus mejoras de campo (`field`; null, ninguna), al azar
## de `seed_value` para que el monitor ensene lo mismo que sale. Devuelve
## {"kit", "field"} para ensenarlo.
func outfit(
	build: MechBuild,
	fight: Dictionary,
	player: PlayerProfile,
	zone_armory: int,
	field: FieldUpgrades,
	seed_value: int
) -> Dictionary:
	var wave := int(fight.get("wave", -1))
	var step := int(fight.get("streak", -1))
	var share := share_for_wave(wave) if wave >= 0 else share_for_streak(step)
	var rival_kit := kit(player, share, zone_armory, int(fight.get("skills", 0)))
	dress(build, rival_kit, Campaign.kits_of(fight))
	var picks: Array[Dictionary] = []
	if field != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, int(fight.get("robot", 0)), "campo"])
		var count := field.for_wave(wave) if wave >= 0 else field.for_streak(step)
		picks = field.draw(build, count, rng)
		field.apply(build, picks)
	return {"kit": rival_kit, "field": picks}


## Sus armas de brazo y hombro, cambiadas por las de arena de su forma y
## elemento, a su clase y nivel, con ese rango.
func _to_arena(build: MechBuild, rank: int) -> void:
	for key: String in ["sides", "tops"]:
		var list: Array[ItemDef] = []
		for def: ItemDef in build.get(key):
			list.append(_arena_for(def, "side0" if key == "sides" else "top0", rank))
		build.set(key, list)


func _arena_for(def: ItemDef, slot: String, rank: int) -> ItemDef:
	if def == null or not def.deals_damage():
		return def
	var best: ItemDef = null
	for id in ArenaGear.pool(catalog):
		var arena := catalog.get_item(id)
		if not Garage.fits(arena, slot) or arena.element != def.element:
			continue
		if best == null or arena.form == def.form:
			best = arena
	if best == null:
		return def
	var resolved := ItemScaling.resolve(best, rules, def.tier, def.level)
	return gear.apply(resolved, rank, {})


static func _piece_of(build: MechBuild, def: ItemDef) -> String:
	if def == build.torso:
		return "torso"
	if def == build.legs:
		return "legs"
	return "weapon"
