class_name RuleFx
extends RefCounted
## Lo que se ve y se oye en combate del terreno y de los estados (OBS-055,
## TerrainConfig y StateConfig): la lava calienta, la reparacion cura, la
## trampa estalla y se gasta, la quemadura calienta y se apaga al enfriar; y
## en cada golpe, la cobertura que lo paro y el estado que dejo. Lo llama
## BattleScreen.

const COLOR_HEAT := Color("ff8a3d")
const COLOR_REPAIR := Color("7dff9b")
const COLOR_TRAP := Color("ffd23d")
const COLOR_COOL := Color("9fd8ff")
## Color de cada estado (tambien sus fichas en el HUD).
const STATE_COLORS := {
	"burn": Color("ff7a2f"), "corrosion": Color("b6d36b"), "static": Color("7fd4ff")
}


## Un evento del terreno o de los estados.
static func play(arena: ArenaView, entry: Dictionary, snapshot: Array, step: float) -> void:
	var who: int = entry["who"]
	var cell: int = snapshot[who]["pos"]
	match str(entry["event"]):
		"lava":
			Sfx.play("impacto_quemadura")
			arena.flash(arena.mechs[who].hit_point(), COLOR_HEAT, 90.0, step)
			arena.float_text(cell, Txt.t("terrain_lava_hit", [entry["heat"]]), COLOR_HEAT)
		"terrain_repair":
			Sfx.play("reparar")
			arena.float_text(cell, "+%d" % entry["amount"], COLOR_REPAIR)
		"trap":
			Sfx.play("impacto_explosion")
			arena.explode(arena.cell_point(cell), step)
			arena.mechs[who].hit(step, COLOR_TRAP)
			arena.float_text(cell, Txt.t("terrain_trap_hit", [entry["damage"]]), COLOR_TRAP)
			var left: Array[String] = []
			left.assign(entry["terrain"])
			arena.set_terrain(left)
		"burn":
			Sfx.play("impacto_quemadura")
			arena.flash(arena.mechs[who].hit_point(), STATE_COLORS["burn"], 70.0, step)
			arena.float_text(cell, Txt.t("state_burn_hit", [entry["heat"]]), STATE_COLORS["burn"])
		"burn_out":
			arena.float_text(cell, Txt.t("state_burn_out"), COLOR_COOL)
	await arena.get_tree().create_timer(step).timeout


## Los textos de un golpe: la cobertura que lo paro, el estado que dejo y la
## descarga de la estatica.
static func hit_texts(arena: ArenaView, entry: Dictionary, cell: int) -> void:
	if entry.get("cover", false):
		arena.float_text(cell, Txt.t("terrain_cover_hit"), COLOR_COOL)
	var kind := str(entry.get("applied", ""))
	if kind == "":
		return
	if entry.get("discharge", false):
		var key := (
			"state_discharge_resisted" if entry.get("stun_resisted", false) else "state_discharge"
		)
		arena.float_text(cell, Txt.t(key), STATE_COLORS[kind])
		return
	arena.float_text(cell, Txt.t("state_" + kind, [int(entry["stacks"])]), STATE_COLORS[kind])
