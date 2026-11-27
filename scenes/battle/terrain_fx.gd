class_name TerrainFx
extends RefCounted
## Lo que se ve y se oye del terreno en combate (OBS-055, TerrainConfig): la
## lava calienta, la reparacion cura y la trampa estalla y se gasta. Lo
## llama BattleScreen con cada evento del terreno.

const COLOR_HEAT := Color("ff8a3d")
const COLOR_REPAIR := Color("7dff9b")
const COLOR_TRAP := Color("ffd23d")


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
	await arena.get_tree().create_timer(step).timeout
