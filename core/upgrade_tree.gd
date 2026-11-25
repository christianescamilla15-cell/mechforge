class_name UpgradeTree
extends RefCounted
## Arbol de mejoras (OBS-051, del usuario: "puntos de mejora, que ahora sera
## un arbol mas complejo y diferente"; GDD 9.2): la armeria es el tronco y
## cada una de sus lineas, al llegar al nivel 10, abre su rama, pagada con los
## puntos de mejora de la racha de la arena. Cinco nodos por rama, en orden;
## el tercero es una bifurcacion: se elige una de dos especializaciones y la
## otra queda cerrada. Botin, Titanes y Fortuna son ramas de la arena y se
## abren con cualquier linea a 10. Datos en data/upgrade_tree.json.

## Efectos que se cuentan en enteros; los demas son fracciones.
const WHOLE: Array[String] = ["mobility", "swarm", "drone_shield", "forge", "fortune_quality"]
## Lo que el juego ya sabe aplicar. Un nodo con otro efecto se ve en el arbol
## pero aun no se aprende (asi no se gastan puntos en algo que no hace nada).
const READY: Array[String] = [
	"damage",
	"energy",
	"heat",
	"resistance",
	"health",
	"backfire",
	"assist",
	"arena_gold",
	"arena_xp",
	"arena_points",
	"campaign_gold",
	"titan_damage",
	"titan_health",
	"pierce",
	"crit",
	"drain",
	"efficiency",
	"ignition",
	"cooling",
	"reflect",
	"absorb",
	"regen",
	"bastion",
	"counter",
	"mobility",
	"swarm",
	"drone_shield",
]
## Nivel de la linea de la armeria que abre su rama.
const OPENS_AT := 10

## Puntos de cada nodo, del primero al ultimo de su rama.
var costs: Array[int] = []
## Las ramas: {"id", "name", "from" (linea de la armeria, "" las de arena),
## "steps": [[nodo] o [nodo, nodo] si es bifurcacion]}.
var branches: Array[Dictionary] = []
var errors: Array[String] = []
## id del nodo -> {"node", "branch", "step"}.
var _nodes: Dictionary = {}


static func load_file(path: String) -> UpgradeTree:
	var tree := UpgradeTree.new()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		tree.errors.append("%s no es un objeto JSON" % path)
		return tree
	for cost: Variant in parsed.get("costs", []):
		tree.costs.append(int(cost))
	for raw: Variant in parsed.get("branches", []):
		tree._add_branch(raw)
	return tree


func _add_branch(raw: Variant) -> void:
	if not raw is Dictionary or not raw.has("id") or not raw.get("nodes") is Array:
		errors.append("rama mal formada: %s" % [raw])
		return
	var branch := {
		"id": str(raw["id"]),
		"name": str(raw.get("name", raw["id"])),
		"from": str(raw.get("from", ""))
	}
	var steps: Array = []
	for raw_step: Variant in raw["nodes"]:
		var options: Array = (
			raw_step["fork"] if raw_step is Dictionary and raw_step.has("fork") else [raw_step]
		)
		var step: Array[Dictionary] = []
		for option: Variant in options:
			if not option is Dictionary or not option.has("id"):
				errors.append("nodo mal formado en %s" % branch["id"])
				continue
			var node := {
				"id": str(option["id"]),
				"name": str(option.get("name", option["id"])),
				"effects": option.get("effects", {}),
			}
			_nodes[node["id"]] = {"node": node, "branch": branch, "step": steps.size()}
			step.append(node)
		steps.append(step)
	if steps.size() > costs.size():
		errors.append("%s tiene mas nodos que precios" % branch["id"])
	branch["steps"] = steps
	branches.append(branch)


func has_node(id: String) -> bool:
	return _nodes.has(id)


func node_data(id: String) -> Dictionary:
	return _nodes[id]["node"] if _nodes.has(id) else {}


## La rama esta abierta: su linea de la armeria a 10 (las de arena, cualquiera).
func is_open(profile: PlayerProfile, branch: Dictionary) -> bool:
	var from: String = branch["from"]
	if from != "":
		return profile.level_of(from) >= OPENS_AT
	for track: String in profile.shop_levels:
		if profile.shop_levels[track] >= OPENS_AT:
			return true
	return false


## Cuantos nodos de la rama ya tiene (en una bifurcacion cuenta el elegido).
func learned_in(profile: PlayerProfile, branch: Dictionary) -> int:
	var count := 0
	for step: Array in branch["steps"]:
		var taken := false
		for node: Dictionary in step:
			taken = taken or node["id"] in profile.tree
		if not taken:
			break
		count += 1
	return count


func cost(id: String) -> int:
	if not _nodes.has(id):
		return 0
	return costs[mini(int(_nodes[id]["step"]), costs.size() - 1)]


## Todos sus efectos los sabe aplicar ya el juego.
func is_ready(id: String) -> bool:
	for effect: String in node_data(id).get("effects", {}):
		if not effect in READY:
			return false
	return true


## "" si se puede aprender ese nodo; si no, por que.
func why_cant_learn(profile: PlayerProfile, id: String) -> String:
	if not _nodes.has(id):
		return "no existe"
	if id in profile.tree:
		return "ya la tienes"
	var info: Dictionary = _nodes[id]
	var branch: Dictionary = info["branch"]
	if not is_open(profile, branch):
		return "se abre con su linea de la armeria al nivel %d" % OPENS_AT
	var done := learned_in(profile, branch)
	if int(info["step"]) < done:
		return "elegiste la otra"
	if int(info["step"]) > done:
		return "antes, la anterior de la rama"
	if not is_ready(id):
		return "pronto"
	if profile.upgrade_points < cost(id):
		return "faltan puntos de mejora"
	return ""


## Aprende un nodo y gasta sus puntos. Devuelve "" o por que no.
func learn(profile: PlayerProfile, id: String) -> String:
	var reason := why_cant_learn(profile, id)
	if reason != "":
		return reason
	profile.upgrade_points -= cost(id)
	profile.tree.append(id)
	return ""


## Lo que suman los nodos aprendidos ({efecto: cuanto}).
func effects_for(learned: Array[String]) -> Dictionary:
	var out := {}
	for id in learned:
		var effects: Dictionary = node_data(id).get("effects", {})
		for effect: String in effects:
			if effect in WHOLE:
				out[effect] = int(out.get(effect, 0)) + int(effects[effect])
			else:
				out[effect] = float(out.get(effect, 0.0)) + float(effects[effect])
	return out
