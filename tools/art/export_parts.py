"""Exporta al juego un torso y unas piernas del chasis (docs/CHASIS.md).

Recorta cada pieza por el aro de cintura, le quita el fondo, la colorea por
elemento (blanco original, calor y energia) y guarda los PNG con un JSON de
anclas que lee el juego (scenes/battle/mech_sprites.gd).

No usa la GPU.
Uso: tools/art/run.ps1 tools/art/export_parts.py --torso t.png --legs l.png \
        --hip 530 493 --name ligero_18 --out assets/mechs
"""

import argparse
import json
from pathlib import Path

from PIL import Image

import cut_body
import cutout
import recolor

# Elemento del juego -> esquema de color (None = el dibujo original).
ELEMENTS = {"PHYSICAL": None, "HEAT": recolor.SCHEMES["calor"], "ENERGY": recolor.SCHEMES["energia"]}


def piece(path, hip, keep_upper):
    """Devuelve (imagen original, mascara de la pieza)."""
    image = Image.open(path).convert("RGB")
    mask = cutout.clean_figure(image)
    row = hip[0]
    if keep_upper:
        mask[row + cut_body.OVERLAP :] = False
    else:
        mask[: row - cut_body.OVERLAP] = False
    return image, mask


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--torso", type=Path, required=True)
    parser.add_argument("--legs", type=Path, required=True)
    parser.add_argument("--hip", type=int, nargs=2, metavar=("FILA", "X"), required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--scale", type=float, default=0.5, help="reduccion respecto al lienzo de 1024")
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    hip = tuple(args.hip)
    anchors = {"scale": args.scale}
    for kind, path, keep_upper in (("torso", args.torso, True), ("legs", args.legs, False)):
        image, mask = piece(path, hip, keep_upper)
        for element, scheme in ELEMENTS.items():
            colored = recolor.recolor(image, scheme)
            sprite, anchor = cut_body.crop_piece(colored, mask, hip)
            size = (round(sprite.width * args.scale), round(sprite.height * args.scale))
            sprite.resize(size, Image.LANCZOS).save(args.out / ("%s_%s_%s.png" % (args.name, kind, element)))
        anchors[kind] = {"hip": [round(anchor[0] * args.scale), round(anchor[1] * args.scale)], "size": list(size)}
    (args.out / (args.name + ".json")).write_text(json.dumps(anchors, indent=2), encoding="utf-8")
    print("exportado %s en %s: %s" % (args.name, args.out, json.dumps(anchors)))


if __name__ == "__main__":
    main()
