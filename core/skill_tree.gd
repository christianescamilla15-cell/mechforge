class_name SkillTree
extends RefCounted
## Arbol de habilidades (decision del usuario, 2026-11-17): cada nivel del
## jugador da puntos; hay tres ramas (Asalto, Blindaje y Sistemas) y los
## puntos se reparten libremente. En cada rama las habilidades se aprenden en
## orden. Asalto termina en la materia oscura (nivel 25), Blindaje da el escudo
## de energia y Sistemas el kit de reparacion.
## Datos en data/skills.json: {"schema_version", "points_per_level",
## "dark_matter_share", "branches": [{"id", "name", "nodes": [{"id", "name",
## "level"?, "effects": {...}}]}]}.

## Efectos que acepta una habilidad (campos de SkillSet).
const EFFECTS: Array[String] = [
	"damage",
	"energy",
	"heat",
	"resistance",
	"health",
	"chest_damage",
	"chest_uses",
	"shield_uses",
	"repair_uses",
	"repair_share",
	"dark_matter",
]

var branches: Array[Dictionary] = []
var points_per_level: int = 1
var dark_matter_share: float = 0.0
var errors: Array[String] = []
## Habilidad por id, con su rama y su posicion: {id: {"node", "branch", "index"}}.
var _index: Dictionary = {}


static func load_file(path: String) -> SkillTree:
	var tree := SkillTree.new()
	if not FileAccess.file_exists(path):
		tree.errors.append("no existe el archivo %s" % path)
		return tree
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("branches") is Array:
		tree.errors.append("%s no tiene una lista 'branches'" % path)
		return tree
	tree.points_per_level = int(parsed.get("points_per_level", 1))
	tree.dark_matter_share = float(parsed.get("dark_matter_share", 0.0))
	for raw: Variant in parsed["branches"]:
		if not raw is Dictionary or not raw.get("nodes") is Array:
			tree.errors.append("hay una rama sin 'nodes'")
			continue
		var branch: Dictionary = raw
		for i in (branch["nodes"] as Array).size():
			var node: Dictionary = branch["nodes"][i]
			var id := str(node.get("id", ""))
			if id == "" or tree._index.has(id):
				tree.errors.append("habilidad sin id o repetida: '%s'" % id)
				continue
			for effect: String in node.get("effects", {}):
				if not effect in EFFECTS:
					tree.errors.append("%s: efecto desconocido '%s'" % [id, effect])
			tree._index[id] = {"node": node, "branch": branch["id"], "index": i}
		tree.branches.append(branch)
	return tree


func get_node_data(id: String) -> Dictionary:
	return _index[id]["node"] if _index.has(id) else {}


## Puntos que tiene el jugador a ese nivel y que aun no ha gastado.
func points_left(profile: PlayerProfile, level: int) -> int:
	var earned := (level - 1) * points_per_level + profile.skill_bonus
	return maxi(0, earned - profile.skills.size())


## Habilidades aprendidas de una rama.
func learned_in(profile: PlayerProfile, branch_id: String) -> int:
	var count := 0
	for id in profile.skills:
		if _index.has(id) and _index[id]["branch"] == branch_id:
			count += 1
	return count


## Siguiente habilidad que se puede aprender en una rama; {} si ya esta entera.
func next_in(profile: PlayerProfile, branch: Dictionary) -> Dictionary:
	var nodes: Array = branch["nodes"]
	var done := learned_in(profile, branch["id"])
	return nodes[done] if done < nodes.size() else {}


## Devuelve "" si el jugador puede aprender esa habilidad; si no, el motivo.
func why_cant_learn(profile: PlayerProfile, id: String, level: int) -> String:
	if not _index.has(id):
		return "esa habilidad no existe"
	if id in profile.skills:
		return "ya la tienes"
	var entry: Dictionary = _index[id]
	var branch := _branch(entry["branch"])
	if learned_in(profile, entry["branch"]) != entry["index"]:
		return "antes hay que aprender las anteriores de la rama"
	if level < int(entry["node"].get("level", 1)):
		return "se abre en el nivel %d" % int(entry["node"]["level"])
	if points_left(profile, level) <= 0:
		return "no quedan puntos"
	if branch.is_empty():
		return "rama desconocida"
	return ""


func learn(profile: PlayerProfile, id: String, level: int) -> String:
	var reason := why_cant_learn(profile, id, level)
	if reason == "":
		profile.skills.append(id)
	return reason


## Habilidades de quien reparte esos puntos por igual entre las ramas, una
## a una y en orden, con el nivel justo para tenerlos: los jefes del Orden
## (GDD 9.3) y el simulador de economia.
func spread(points: int) -> Array[String]:
	var profile := PlayerProfile.new()
	var level := 1 + ceili(float(points) / maxi(1, points_per_level))
	var branch := 0
	var stuck := 0
	while profile.skills.size() < points and stuck < branches.size():
		var next := next_in(profile, branches[branch % branches.size()])
		branch += 1
		if next.is_empty() or learn(profile, next["id"], level) != "":
			stuck += 1
			continue
		stuck = 0
	return profile.skills


## Suma lo que dan las habilidades aprendidas.
func effects_for(learned: Array[String]) -> SkillSet:
	var out := SkillSet.new()
	for id in learned:
		if not _index.has(id):
			continue
		var effects: Dictionary = _index[id]["node"].get("effects", {})
		for effect: String in effects:
			if effect == "dark_matter":
				out.dark_matter_uses += int(effects[effect])
				out.dark_matter_share = dark_matter_share
			elif effect in ["chest_uses", "shield_uses", "repair_uses"]:
				out.set(effect, int(out.get(effect)) + int(effects[effect]))
			else:
				out.set(effect, float(out.get(effect)) + float(effects[effect]))
	return out


## Texto corto de lo que da una habilidad, para el menu.
static func describe(node: Dictionary) -> String:
	var parts: Array[String] = []
	var effects: Dictionary = node.get("effects", {})
	var names := {
		"damage": "daño",
		"energy": "energía",
		"heat": "calor",
		"resistance": "resistencias",
		"health": "vida",
		"chest_damage": "daño del pecho",
		"repair_share": "reparación",
	}
	for effect: String in effects:
		var value: Variant = effects[effect]
		match effect:
			"chest_uses":
				parts.append("+%d uso del pecho" % int(value))
			"shield_uses":
				parts.append("escudo +%d por combate" % int(value))
			"repair_uses":
				parts.append("reparación +%d por combate" % int(value))
			"dark_matter":
				parts.append("materia oscura")
			_:
				parts.append("+%d %% %s" % [roundi(float(value) * 100.0), names[effect]])
	return ", ".join(parts)


func _branch(id: String) -> Dictionary:
	for branch in branches:
		if branch["id"] == id:
			return branch
	return {}
