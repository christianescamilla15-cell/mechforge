class_name TemperLibrary
extends RefCounted
## El caracter de cada rival (OBS-014 de docs/OBSERVACIONES.md, del usuario:
## "es muy predecible; los enemigos no hacen mas que atacar; no usan
## estrategia"). Un temperamento son pesos de la valoracion de la IA
## (AIConfig) y sus gustos por cada tipo de accion: con ellos un rival va a
## por el dano, se cuida, desgasta o guarda la distancia. Que rival lleva
## cual lo dice su diseno (data/builds.json, "temper"); los jefes no llevan:
## piensan como siempre.
## Datos en data/tempers.json: {"schema_version", "tempers": [{"id",
## "weights": {campo de AIConfig: valor}, "likes": {tipo de accion en
## minusculas: lo que suma}}]}.

## Los campos de AIConfig que un temperamento puede cambiar.
const WEIGHTS: Array[String] = [
	"guard",
	"aggression",
	"pressure",
	"caution",
	"evasion",
	"barrier_value",
	"repair_hold",
	"heat_discount",
	"energy_discount",
	"position_discount",
]

var errors: Array[String] = []
var _weights: Dictionary[String, Dictionary] = {}
var _likes: Dictionary[String, Dictionary] = {}
var _order: Array[String] = []


static func load_file(path: String) -> TemperLibrary:
	var library := TemperLibrary.new()
	if not FileAccess.file_exists(path):
		library.errors.append("no existe el archivo %s" % path)
		return library
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("tempers") is Array:
		library.errors.append("%s no tiene una lista 'tempers'" % path)
		return library
	for raw: Variant in parsed["tempers"]:
		library.add(raw)
	return library


func ids() -> Array[String]:
	return _order.duplicate()


func has(id: String) -> bool:
	return _weights.has(id)


## Los pesos de un temperamento ({} si no existe).
func weights(id: String) -> Dictionary:
	return _weights.get(id, {}).duplicate()


## Sus gustos: lo que suma a una jugada cada tipo de accion ({} si no tiene).
func likes(id: String) -> Dictionary:
	return _likes.get(id, {}).duplicate()


## La valoracion de la IA con ese temperamento. Sin temperamento (""), o con
## uno que no existe, es la de siempre.
func config(id: String) -> AIConfig:
	var out := AIConfig.new()
	var own: Dictionary = _weights.get(id, {})
	for key: String in own:
		out.set(key, float(own[key]))
	out.likes = likes(id)
	return out


## Anade un temperamento; si esta mal lo apunta en `errors` y no lo carga.
func add(raw: Variant) -> void:
	if not raw is Dictionary:
		errors.append("un temperamento no es un diccionario")
		return
	var id := str(raw.get("id", ""))
	if id == "" or _weights.has(id):
		errors.append("temperamento sin id o repetido: '%s'" % id)
		return
	var own: Variant = raw.get("weights", {})
	var tastes: Variant = raw.get("likes", {})
	if not own is Dictionary or not tastes is Dictionary:
		errors.append("%s: 'weights' y 'likes' son diccionarios" % id)
		return
	if own.is_empty() and tastes.is_empty():
		errors.append("%s: no cambia nada" % id)
		return
	var kinds: Array[String] = []
	for kind: String in BattleAction.Type.keys():
		kinds.append(kind.to_lower())
	for key: Variant in tastes:
		if not str(key) in kinds:
			errors.append("%s: tipo de accion desconocido '%s'" % [id, key])
			return
		if not (tastes[key] is float or tastes[key] is int):
			errors.append("%s: el gusto '%s' no es un numero" % [id, key])
			return
	for key: Variant in own:
		if not str(key) in WEIGHTS:
			errors.append("%s: peso desconocido '%s'" % [id, key])
			return
		if not (own[key] is float or own[key] is int) or float(own[key]) < 0.0:
			errors.append("%s: el peso '%s' no es un numero valido" % [id, key])
			return
	_weights[id] = own
	_likes[id] = tastes
	_order.append(id)


## Los disenos cuyo temperamento no existe (para validar los datos).
func missing_in(library: BuildLibrary) -> Array[String]:
	var out: Array[String] = []
	for build_id in library.all_ids():
		var temper := library.temper_of(build_id)
		if temper != "" and not has(temper):
			out.append("%s: temperamento desconocido '%s'" % [build_id, temper])
	return out
