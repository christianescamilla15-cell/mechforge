"""Exporta al juego las armas dibujadas a lienzo completo (tools/art/weapons_test.py).

De cada diseno toma la semilla elegida (CHOSEN), recorta la figura del fondo,
la colorea por elemento y la guarda en assets/mechs/armas_ligero_<pieza>_<ELEMENTO>.png
con sus anclas en assets/mechs/armas_ligero.json:
  hip   la cintura del robot en pixeles del sprite. Sale de la union del
        bloque (el eje del hombro o el pie del pedestal), que va donde iba
        la de las primeras armas montadas, asi que el juego las coloca igual.
  tip   la boca del arma, de donde sale el disparo.
  size  ancho y alto del sprite.
El juego las lee en scenes/battle/mech_sprites.gd.

No usa la GPU.
Uso:
  tools/art/run.ps1 -KeepWatcher tools/art/export_weapons.py --batch armas2
  tools/art/run.ps1 -KeepWatcher tools/art/export_weapons.py --batch armas2 --only arm_medio_balas
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import cutout
import export_assist
import export_parts
import recolor
import weapons_test

ROOT = Path(__file__).resolve().parents[2]
SET = ROOT / "assets" / "mechs" / "armas_ligero"
# Pixeles del sprite por unidad del bloque (weapons_test.py): cada imagen se
# reduce esto dividido por la ampliacion con la que se dibujo. Las de hombro
# van algo mas pequenas: a la escala de las de brazo tapaban medio robot.
ARM_SCALE = 0.36
TOP_SCALE = 0.3
# Donde va la union respecto a la cintura del robot, en pixeles del sprite:
# el eje del hombro (el de las primeras armas montadas) y el pie del
# pedestal, que se hunde un poco en la espalda para que no flote.
ARM_UNION = (-30, -65)
TOP_UNION = (-66, -158)
# Unidades del bloque que se conservan por debajo del pie del pedestal: el
# modelo a veces dibuja patas o soportes de mas ahi.
TOP_BELOW = 10
# Semilla elegida de cada diseno (se revisan en hoja antes de exportar).
CHOSEN = {
    "arm_corto_balas": 102,
    "arm_corto_blaster": 101,
    "arm_corto_canon": 102,
    "arm_corto_laser": 101,
    "arm_hoja_balas": 101,
    "arm_hoja_blaster": 101,
    "arm_hoja_laser": 101,
    "arm_largo_balas": 101,
    "arm_largo_blaster": 101,
    "arm_largo_canon": 101,
    "arm_largo_laser": 101,
    "arm_medio_balas": 102,
    "arm_medio_blaster": 101,
    "arm_medio_canon": 102,
    "arm_medio_laser": 101,
    "arm_saboteador_blaster": 101,
    "arm_saboteador_laser": 101,
    "shoulder_ancla_canon": 103,
    "shoulder_ancla_laser": 103,
    "shoulder_artilleria_blaster": 103,
    "shoulder_artilleria_canon": 101,
    "shoulder_artilleria_laser": 103,
    "shoulder_bateria_balas": 103,
    "shoulder_bateria_blaster": 103,
    "shoulder_bateria_canon": 103,
    "shoulder_bateria_laser": 101,
}


def export(name, source, sheet_row=None, placement=None, keep=None, tolerance=14):
    """`placement`: la ampliacion y el origen con los que se dibujo, si no
    son los del diseno `name` (las etapas de tools/art/evolve_weapons.py).
    `keep`: zonas del lienzo donde lo dibujado se conserva aunque quede
    suelto (los perifericos pequenos, que el recorte tomaria por motas).
    `tolerance`: cuanto se separa la figura del color del fondo (mas alta
    deja fuera el brillo y la sombra que pintan las fases altas)."""
    image = Image.open(source).convert("RGB")
    mask = np.logical_and(cutout.clean_figure(image, tolerance), ~export_assist.enclosed_background(image))
    if keep is not None:
        mask = np.logical_or(mask, np.logical_and(cutout.foreground_mask(image), keep))
    zoom, origin = placement or weapons_test.placement(name)
    arm = name.startswith("arm_")
    if not arm:
        mask[round(origin[1] + TOP_BELOW * zoom) :] = False
    rows = np.where(mask.any(axis=1))[0]
    columns = np.where(mask.any(axis=0))[0]
    box = (int(columns[0]), int(rows[0]), int(columns[-1]) + 1, int(rows[-1]) + 1)
    scale = (ARM_SCALE if arm else TOP_SCALE) / zoom
    size = (round((box[2] - box[0]) * scale), round((box[3] - box[1]) * scale))
    sprites = []
    for element, scheme in export_parts.ELEMENTS.items():
        sprite = cutout.to_rgba(recolor.recolor(image, scheme), mask).crop(box).resize(size, Image.LANCZOS)
        sprite.save("%s_%s_%s.png" % (SET, name, element))
        sprites.append(sprite)

    union = ARM_UNION if arm else TOP_UNION
    joint = ((origin[0] - box[0]) * scale, (origin[1] - box[1]) * scale)
    # La boca: el extremo derecho de la figura, a la altura de lo que hay alli.
    edge = max(6, (box[2] - box[0]) // 40)
    tip_rows = np.where(mask[:, box[2] - edge : box[2]].any(axis=1))[0]
    tip = ((box[2] - box[0]) * scale, (float(tip_rows.mean()) - box[1]) * scale)
    anchors = {
        "hip": [round(joint[0] - union[0]), round(joint[1] - union[1])],
        "size": list(size),
        "tip": [round(tip[0]), round(tip[1])],
    }
    return anchors, sprites


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--only", nargs="+", default=None)
    parser.add_argument("--sheet", type=Path, default=None, help="hoja con lo exportado, para revisarlo")
    args = parser.parse_args()

    anchors_path = SET.with_suffix(".json")
    anchors = {"scale": ARM_SCALE}
    if anchors_path.exists():
        anchors = json.loads(anchors_path.read_text(encoding="utf-8"))
        anchors["scale"] = ARM_SCALE
    names = args.only or sorted(CHOSEN)
    exported = {}
    for name in names:
        source = weapons_test.OUT / args.batch / ("%s_%d.png" % (name, CHOSEN[name]))
        anchors[name], exported[name] = export(name, source)
        print("exportada %s: %s" % (name, json.dumps(anchors[name])))
    anchors_path.write_text(json.dumps(anchors, indent=2), encoding="utf-8")

    if args.sheet:
        cell = (470, 170)
        sheet = Image.new("RGB", (cell[0] * 3, cell[1] * len(exported)), "#2b303a")
        draw = ImageDraw.Draw(sheet)
        for row, (name, sprites) in enumerate(exported.items()):
            for column, sprite in enumerate(sprites):
                at = (column * cell[0] + (cell[0] - sprite.width) // 2, row * cell[1] + (cell[1] - sprite.height) // 2)
                sheet.paste(sprite, at, sprite)
            draw.text((6, row * cell[1] + 4), name, fill="#d7dde6")
        args.sheet.parent.mkdir(parents=True, exist_ok=True)
        sheet.save(args.sheet)
        print("hoja:", args.sheet)


if __name__ == "__main__":
    main()
