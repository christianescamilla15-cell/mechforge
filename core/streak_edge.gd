class_name StreakEdge
extends RefCounted
## El plus de los rivales de la racha cuenta lo que el jugador lleva de mas
## (OBS-051, PLAN A6). Del usuario: "recuerda que para los niveles mas altos
## yo ya tendre mejoras en mi armamento y armas, entonces tendre mas dano,
## resistencia, etc., y eso puede repercutir mucho en los resultados". El
## rival ya se mide con la clase y el nivel de sus piezas (Campaign.
## arena_fight); aqui se mide lo demas: el arbol de mejoras, los aspectos y
## las armas de arena (su ventaja sobre el laser de su forma y su rango) y,
## desde el 2026-11-26 (OBS-054), los prototipos del especialista.
## Una parte (ArenaGear.rival_share) pasa al plus del rival: mejorar ayuda,
## pero lo alto de la racha sigue siendo dificil.
##
## Es una medida, no el combate: lo que pega y lo que aguanta en una cifra.
## Sus pesos (abajo) solo ordenan lo que cuenta cada cosa; el reparto con el
## rival lo decide la parte, que esta en los datos y se calibra con el
## simulador de la racha (tools/sim/arena_streak_sim.gd).

## Turnos propios de un combate tipico (12 en total): lo que rinde la
## regeneracion por turno.
const TURNS := 6.0
## Lo que cuenta el calor y la energia que quita un arma, frente a su dano.
const DRAIN_WEIGHT := 0.5
## Cuanto pesa tener mas energia y enfriamiento para sostener el fuego
## (exponente del producto de las dos razones): poco; medido con el
## simulador, las ramas Reactor y Fundicion casi no mueven la racha.
const SUSTAIN_POWER := 0.1
## El rival de lo alto de la racha pega mas o menos el doble que el jugador
## sin lo de mas (su plus y la armeria de la liga): contra ese golpe se mide
## lo que paran las resistencias.
const RIVAL_HIT := 2.0


## Lo que se le multiplica al rival (menos 1) por la ventaja `extra` del
## jugador: la fraccion `share` de esa ventaja en escala logaritmica,
## (1 + extra) ^ share. Asi lo que se suma encima de mucho cuenta menos,
## como en el combate.
static func rival_extra(extra: float, share: float) -> float:
	return pow(1.0 + maxf(extra, 0.0), share) - 1.0


## Cuanto mas fuerte es el robot `full` que el `plain` (el mismo sin lo de
## mas), como fraccion: 0.3 = un 30 %. En `plain` las armas de arena cuentan
## sin su ventaja (`boost`). Nunca baja de 0.
static func extra(rules: RulesConfig, plain: MechBuild, full: MechBuild, boost: float) -> float:
	var before := BattleMech.new(plain, rules)
	var after := BattleMech.new(full, rules)
	# La misma vara para los dos: el golpe, la resistencia y lo que sostiene
	# el robot sin lo de mas, como si peleara contra si mismo.
	var ref := {
		"hit": _mean_hit(before, boost) * RIVAL_HIT,
		"res": (before.res[0] + before.res[1] + before.res[2]) / 3.0,
		"regen": maxf(1.0, before.energy_regen),
		"cooling": maxf(1.0, before.cooling),
	}
	var was := might(rules, before, ref, boost)
	var now := might(rules, after, ref, 1.0)
	return maxf(0.0, now / maxf(was, 0.001) - 1.0)


## Lo que pega y aguanta un robot, en una cifra: la media geometrica de lo
## que pega por turno contra la resistencia de `ref` (el golpe medio de sus
## armas, una por accion, con su potencia, su critico, la perforacion y el
## calor y la energia que quitan; el asistente, que dispara aparte; lo que
## sostiene el fuego) y de los golpes de `ref` que
## aguanta (vida, escudos, resistencias, regeneracion y Bastion). El reflejo
## y el contraataque cuentan como dano devuelto. `boost`: lo que se le
## quita a las armas de arena.
static func might(rules: RulesConfig, mech: BattleMech, ref: Dictionary, boost: float) -> float:
	var res_ref := float(ref["res"])
	var hit := 0.0
	var weapons := 0
	# Lo que devuelven sus prototipos al golpear: vida, energia y calor.
	var stolen := 0.0
	var energy_back := 0.0
	var vented := 0.0
	for key in mech.weapon_keys():
		var def: ItemDef = mech.slots[key].def
		if def == null or not def.deals_damage():
			continue
		var fx := def.proto_effects
		var damage := _damage_of(def, boost) * mech.damage_mult()
		damage *= 1.0 + float(fx.get("damage", 0.0))
		var chance := def.crit / 100.0 + mech.skill("crit") + float(fx.get("crit", 0.0))
		var crit := clampf(chance, 0.0, rules.crit_cap)
		damage *= 1.0 + crit * (rules.crit_damage_mult - 1.0)
		var dealt := _after_res(mech, damage, res_ref)
		hit += dealt
		stolen += dealt * float(fx.get("lifesteal", 0.0))
		energy_back += mech.energy_cap * float(fx.get("energy_on_hit", 0.0))
		vented += mech.heat_cap * float(fx.get("cool_on_hit", 0.0))
		var drained := def.heat_dmg * (1.0 + mech.skill("ignition"))
		drained += def.energy_dmg * (1.0 + mech.skill("drain"))
		hit += DRAIN_WEIGHT * drained
		weapons += 1
	# Un arma por accion: la media de sus golpes, por las acciones del turno.
	var actions := (1 + mech.extra_actions()) / float(maxi(weapons, 1))
	hit *= actions
	stolen *= actions
	# El asistente dispara una de sus dos armas por turno (mas con Enjambre).
	var drones := 0.0
	var count := 0
	for key in ["drone", "drone_low"]:
		var def: ItemDef = mech.slots[key].def if mech.slots.has(key) else null
		if def != null and def.deals_damage():
			drones += _damage_of(def, boost) * mech.damage_mult() * mech.assist_power()
			count += 1
	if count > 0:
		var shot := _after_res(mech, drones / count, res_ref)
		hit += shot * (1.0 + mech.extra_drone_shots())
	# Sostener el fuego: mas energia que se recupera y mas enfriamiento.
	var regen := maxf(1.0, mech.energy_regen + energy_back * actions) / float(ref["regen"])
	var cool := maxf(1.0, mech.cooling + vented * actions) / float(ref["cooling"])
	hit *= pow(regen * cool, SUSTAIN_POWER)
	var res := (mech.res[0] + mech.res[1] + mech.res[2]) / 3.0
	var taken := maxf(1.0, float(ref["hit"]) - res)
	var guard := (mech.max_health + mech.barrier) / taken
	guard *= 1.0 + mech.regen_share() * TURNS
	# El robo de vida cura como la regeneracion, por lo que pega.
	guard += stolen * TURNS / taken
	guard += mech.skill("bastion")
	hit += taken * (mech.skill("reflect") + 0.5 * mech.skill("counter"))
	return sqrt(maxf(hit, 1.0) * guard)


static func _after_res(mech: BattleMech, damage: float, res_ref: float) -> float:
	var pierce := clampf(mech.skill("pierce"), 0.0, 1.0)
	return maxf(1.0, damage - res_ref * (1.0 - pierce))


## El golpe medio de las armas de un robot, antes de la resistencia.
static func _mean_hit(mech: BattleMech, boost: float) -> float:
	var total := 0.0
	var count := 0
	for key in mech.weapon_keys():
		var def: ItemDef = mech.slots[key].def
		if def != null and def.deals_damage():
			total += _damage_of(def, boost) * mech.damage_mult()
			count += 1
	return total / maxi(count, 1)


static func _damage_of(def: ItemDef, boost: float) -> float:
	var damage := (def.dmg_min + def.dmg_max) * 0.5
	if def.has_tag(ItemDef.TAG_ARENA):
		damage /= maxf(boost, 0.001)
	return damage
