class_name FightLog
extends RefCounted
## Registro de los combates jugados (OBS-051, del usuario: "puedes revisar los
## combates que he tenido"): una linea JSON por combate, para afinar la
## dificultad con sus combates de verdad y no solo con el simulador (la IA
## dificil en su lado ganaba el 4.o y el 5.o de la racha el 42 y el 28 %, y
## el los ganaba siempre). Solo lo escribe el juego de verdad, no las pruebas.

const PATH := "user://combates.jsonl"


## Anade un combate al final del registro. Devuelve false si no pudo.
static func append(entry: Dictionary, path: String = PATH) -> bool:
	var file: FileAccess
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	return true


## Los combates apuntados, del primero al ultimo (las lineas rotas se saltan).
static func read(path: String = PATH) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		# JSON.parse (y no parse_string) para que una linea rota no avise.
		var json := JSON.new()
		if json.parse(line) == OK and json.data is Dictionary:
			out.append(json.data)
	return out
