extends SceneTree
## Simulador de balance: IA contra IA en headless, en paralelo.
##
## Uso (tras `--`):
##   --mode=round_robin   todos los mechs de data/builds.json entre si (por defecto)
##   --mode=ai_vs_random  IA normal contra IA al azar con el mismo mech
##   --battles=N          combates por emparejamiento (por defecto 100)
##   --tier=DIVINE        tier de todas las piezas
##   --levels=0,5,10      niveles sobre los que se promedia (por defecto, el
##                        maximo del tier). En tiers bajos los numeros son
##                        pequenos y el redondeo cambia quien va un 1 % por
##                        delante segun el nivel; promediar lo compensa.
##   --difficulty=NORMAL  dificultad de la IA
##   --seed=1             semilla base
##   --no-m2 --no-m5 --no-m6    apaga una mejora para medir su efecto
##   --hp-scales=0.92,0.96,1,1.04,1.08   escalas de vida sobre las que se promedia.
##                        Con poco azar en el dano, quien gana un cruce parejo
##                        depende de la paridad de las acciones que hacen falta
##                        para matar; promediar varias escalas mide el balance
##                        real y no ese artefacto. Usa --hp-scales=1 para una sola.
##   --band=balas         mechs de ese tipo de arma: balas, canon, blaster o laser
##   --json=ruta          guarda el resumen en JSON
## Sale con codigo 1 si no se cumple alguna puerta de la fase F3.

const GATE_MAX_ELEMENT_WINRATE := 0.55
const GATE_HYBRID_RANGE := [0.45, 0.55]
const GATE_TURNS_RANGE := [6.0, 14.0]
const GATE_AI_VS_RANDOM := 0.95

var _rules: RulesConfig
## Mechs ya armados, uno por id y por escala de vida: "id@indice".
var _builds: Dictionary[String, MechBuild] = {}
var _hp_scales: Array[float] = []
var _variants: Array[Dictionary] = []
var _library: BuildLibrary
var _tasks: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _difficulty: BattleAI.Difficulty
var _band := "balas"


func _initialize() -> void:
	var args := _parse_args()
	_rules = RulesConfig.new()
	_rules.m2_no_chain_shutdown = not args.has("no-m2")
	_rules.m5_first_turn_single_action = not args.has("no-m5")
	_rules.m6_regen_at_turn_start = not args.has("no-m6")
	var tier_name: String = args.get("tier", "DIVINE")
	var tier: ItemDef.Tier = ItemDef.Tier[tier_name]
	var levels: Array[int] = []
	for text: String in str(args.get("levels", str(_rules.tier_max_level[tier]))).split(","):
		levels.append(int(text))
	_difficulty = BattleAI.Difficulty[args.get("difficulty", "NORMAL")]
	var battles := int(args.get("battles", "100"))
	var base_seed := int(args.get("seed", "1"))
	var mode: String = args.get("mode", "round_robin")
	_band = args.get("band", "balas")

	var catalog := Catalog.load_file("res://data/catalog.json")
	_library = BuildLibrary.load_file("res://data/builds.json")
	for text: String in str(args.get("hp-scales", "0.92,0.96,1,1.04,1.08")).split(","):
		_hp_scales.append(float(text))
	# Cada variante combina una escala de vida y un nivel.
	for scale in _hp_scales:
		for level in levels:
			_variants.append({"scale": scale, "level": level})
	for id in _library.band_ids(_band):
		for v in _variants.size():
			var build := _library.make(id, catalog, _rules, tier, _variants[v]["level"])
			for item in build.all_items():
				item.health = roundi(item.health * _variants[v]["scale"])
			_builds["%s@%d" % [id, v]] = build
	if not (catalog.errors.is_empty() and _library.errors.is_empty()):
		printerr("datos con errores: ", catalog.errors, _library.errors)
		quit(2)
		return

	var ids := _library.band_ids(_band)
	# `battles` es el total por emparejamiento, repartido entre las variantes.
	for i in battles:
		var variant := i % _variants.size()
		var base := {"seed": base_seed + i, "starter": (i / _variants.size()) % 2, "scale": variant}
		if mode == "ai_vs_random":
			for id in ids:
				# El asiento 0 es siempre la IA; se alterna quien empieza.
				_tasks.append(base.merged({"a": id, "b": id, "random_b": true}))
		else:
			for a in ids:
				for b in ids:
					_tasks.append(base.merged({"a": a, "b": b}))
	_results.resize(_tasks.size())

	var started := Time.get_ticks_msec()
	var group := WorkerThreadPool.add_group_task(_run_task, _tasks.size())
	WorkerThreadPool.wait_for_group_task_completion(group)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print(
		(
			(
				"%d combates en %.1f s (%.0f ms por combate, %d hilos, %d escalas de vida)"
				+ " | tier %s niveles %s | IA %s | M2=%s M5=%s M6=%s"
			)
			% [
				_tasks.size(),
				seconds,
				seconds * 1000.0 / maxi(_tasks.size(), 1),
				OS.get_processor_count(),
				_hp_scales.size(),
				tier_name,
				levels,
				BattleAI.Difficulty.find_key(_difficulty),
				_rules.m2_no_chain_shutdown,
				_rules.m5_first_turn_single_action,
				_rules.m6_regen_at_turn_start,
			]
		)
	)

	var summary := _report_random(ids) if mode == "ai_vs_random" else _report_round_robin(ids)
	if args.has("json"):
		var file := FileAccess.open(args["json"], FileAccess.WRITE)
		file.store_string(JSON.stringify(summary, "  "))
	quit(0 if summary["gates_ok"] else 1)


func _run_task(index: int) -> void:
	var task := _tasks[index]
	var ai_a := BattleAI.new(_difficulty, task["seed"] * 2 + 1)
	var b_difficulty := BattleAI.Difficulty.RANDOM if task.get("random_b", false) else _difficulty
	var ai_b := BattleAI.new(b_difficulty, task["seed"] * 2 + 2)
	var build_a := _builds["%s@%d" % [task["a"], task["scale"]]]
	var build_b := _builds["%s@%d" % [task["b"], task["scale"]]]
	_results[index] = BattleRunner.run(
		_rules, build_a, build_b, ai_a, ai_b, task["seed"], task["starter"]
	)


func _report_round_robin(ids: Array[String]) -> Dictionary:
	# wins[a][b] = victorias de a (asiento 0) contra b; games igual.
	var wins := {}
	var games := {}
	# Margen firmado: vida restante del ganador, positiva si gana la fila.
	var margin := {}
	for a in ids:
		wins[a] = {}
		games[a] = {}
		margin[a] = {}
		for b in ids:
			wins[a][b] = 0
			games[a][b] = 0
			margin[a][b] = 0.0
	var turns_total := 0
	var shutdown_turns := 0
	var forced_cools := 0
	var draws := 0
	var chained := 0
	var starter_wins := 0
	var decided := 0
	var uses := {}
	for i in _tasks.size():
		var task := _tasks[i]
		var result := _results[i]
		games[task["a"]][task["b"]] += 1
		turns_total += result["turns"]
		shutdown_turns += result["shutdowns"][0] + result["shutdowns"][1]
		forced_cools += result["forced_cools"][0] + result["forced_cools"][1]
		if result["chained_shutdown"]:
			chained += 1
		for id: String in result["uses"]:
			uses[id] = uses.get(id, 0) + result["uses"][id]
		if result["winner"] < 0:
			draws += 1
			continue
		decided += 1
		if result["winner"] == 0:
			wins[task["a"]][task["b"]] += 1
			margin[task["a"]][task["b"]] += result["margin"]
			margin[task["b"]][task["a"]] -= result["margin"]
		else:
			margin[task["a"]][task["b"]] -= result["margin"]
			margin[task["b"]][task["a"]] += result["margin"]
		if result["winner"] == result["starter"]:
			starter_wins += 1

	print("\nVictorias del mech de la fila contra el de la columna (%):")
	var header := "%-20s" % ""
	for b in ids:
		header += "%10s" % b.substr(0, 9)
	print(header)
	# Tasa combinando los dos asientos: fila a contra columna b.
	var rate := {}
	for a in ids:
		rate[a] = {}
		var line := "%-20s" % a
		for b in ids:
			var won: int = wins[a][b] + (games[b][a] - wins[b][a] - _draws_between(b, a))
			var played: int = (
				games[a][b] + games[b][a] - _draws_between(a, b) - _draws_between(b, a)
			)
			rate[a][b] = float(won) / maxi(played, 1)
			line += "%9.0f%%" % (rate[a][b] * 100.0)
		print(line)

	print("\nMargen medio (% de vida que le sobra al ganador; + gana la fila, - la columna):")
	print(header)
	for a in ids:
		var line := "%-20s" % a
		for b in ids:
			var played: int = games[a][b] + games[b][a]
			line += "%+9.0f%%" % (100.0 * margin[a][b] / maxi(played, 1))
		print(line)

	# Tasa global de cada mech contra los demas (sin contar el espejo).
	var elemental: Array[String] = []
	var hybrids: Array[String] = []
	for id in ids:
		if _library.element_of(id) == "HYBRID":
			hybrids.append(id)
		else:
			elemental.append(id)
	var overall := {}
	print("\nTasa de victoria global:")
	for id in ids:
		var rivals := elemental.filter(func(other: String) -> bool: return other != id)
		var total := 0.0
		for other: String in rivals:
			total += rate[id][other]
		overall[id] = total / maxi(rivals.size(), 1)
		print(
			(
				"  %-20s %5.1f%%  (%s, contra los mechs de un solo elemento)"
				% [id, overall[id] * 100.0, _library.element_of(id)]
			)
		)

	var mean_turns := float(turns_total) / maxi(_tasks.size(), 1)
	print("\nDuracion media: %.1f turnos | empates por limite: %d" % [mean_turns, draws])
	print(
		(
			"Turnos perdidos por apagado: %.1f%% | enfriados forzados: %.1f%% de los turnos"
			% [
				100.0 * shutdown_turns / maxi(turns_total, 1),
				100.0 * forced_cools / maxi(turns_total, 1)
			]
		)
	)
	print("Gana quien empieza: %.1f%%" % (100.0 * starter_wins / maxi(decided, 1)))
	# En los espejos los dos mechs son iguales: solo decide la iniciativa.
	var mirror := {}
	for i in _tasks.size():
		var result := _results[i]
		if _tasks[i]["a"] != _tasks[i]["b"] or result["winner"] < 0:
			continue
		var distance: int = result["start_distance"]
		if not mirror.has(distance):
			mirror[distance] = [0, 0]
		mirror[distance][1] += 1
		if result["winner"] == result["starter"]:
			mirror[distance][0] += 1
	var mirror_text := ""
	var mirror_wins := 0
	var mirror_games := 0
	var distances := mirror.keys()
	distances.sort()
	for distance: int in distances:
		mirror_wins += mirror[distance][0]
		mirror_games += mirror[distance][1]
		mirror_text += (
			"  distancia %d: %.0f%% (%d)"
			% [distance, 100.0 * mirror[distance][0] / mirror[distance][1], mirror[distance][1]]
		)
	var mirror_rate := float(mirror_wins) / maxi(mirror_games, 1)
	for id in ids:
		var line := "    espejo %-20s" % id
		for distance: int in distances:
			var won := 0
			var played := 0
			for i in _tasks.size():
				var result := _results[i]
				if _tasks[i]["a"] != id or _tasks[i]["b"] != id or result["winner"] < 0:
					continue
				if result["start_distance"] != distance:
					continue
				played += 1
				if result["winner"] == result["starter"]:
					won += 1
			line += "  d%d: %3.0f%% (%d)" % [distance, 100.0 * won / maxi(played, 1), played]
		print(line)
	print("En espejos gana quien empieza: %.1f%% |%s" % [mirror_rate * 100.0, mirror_text])
	var by_use := uses.keys()
	by_use.sort_custom(func(x: String, y: String) -> bool: return uses[x] > uses[y])
	print("Piezas mas usadas: ", _top(by_use, uses, 8))
	by_use.reverse()
	print("Piezas menos usadas: ", _top(by_use, uses, 8))

	var gates := {}
	var worst_element := 0.0
	for id in elemental:
		worst_element = maxf(worst_element, overall[id])
	gates["ningun elemento supera el 55 %"] = worst_element <= GATE_MAX_ELEMENT_WINRATE + 0.0001
	var hybrid_ok := false
	for id in hybrids:
		hybrid_ok = (
			hybrid_ok
			or (overall[id] >= GATE_HYBRID_RANGE[0] and overall[id] <= GATE_HYBRID_RANGE[1])
		)
	gates["un hibrido gana entre 45 y 55 %"] = hybrid_ok
	gates["duracion media de 6 a 14 turnos"] = (
		mean_turns >= GATE_TURNS_RANGE[0] and mean_turns <= GATE_TURNS_RANGE[1]
	)
	if _rules.m2_no_chain_shutdown:
		gates["sin apagados seguidos (M2)"] = chained == 0
	return _finish(
		gates,
		{"rate": rate, "overall": overall, "mean_turns": mean_turns, "draws": draws, "uses": uses}
	)


func _report_random(ids: Array[String]) -> Dictionary:
	var won := 0
	var per_build := {}
	for id in ids:
		per_build[id] = 0
	for i in _tasks.size():
		if _results[i]["winner"] == 0:
			won += 1
			per_build[_tasks[i]["a"]] += 1
	var rate := float(won) / maxi(_tasks.size(), 1)
	var battles := _tasks.size() / maxi(ids.size(), 1)
	print("\nIA contra IA al azar con el mismo mech:")
	for id in ids:
		print("  %-20s %5.1f%%" % [id, 100.0 * per_build[id] / maxi(battles, 1)])
	print("  total                %5.1f%%" % (rate * 100.0))
	return _finish(
		{"la IA gana al azar al menos el 95 %": rate >= GATE_AI_VS_RANDOM}, {"rate": rate}
	)


func _finish(gates: Dictionary, data: Dictionary) -> Dictionary:
	print("\nPuertas:")
	var all_ok := true
	for name: String in gates:
		print("  [%s] %s" % ["OK" if gates[name] else "FALLA", name])
		all_ok = all_ok and gates[name]
	data["gates"] = gates
	data["gates_ok"] = all_ok
	return data


func _draws_between(a: String, b: String) -> int:
	var count := 0
	for i in _tasks.size():
		if _tasks[i]["a"] == a and _tasks[i]["b"] == b and _results[i]["winner"] < 0:
			count += 1
	return count


func _top(order: Array, uses: Dictionary, count: int) -> String:
	var parts: Array[String] = []
	for i in mini(count, order.size()):
		parts.append("%s %d" % [order[i], uses[order[i]]])
	return ", ".join(parts)


func _parse_args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := arg.trim_prefix("--")
		var parts := text.split("=", true, 1)
		out[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return out
