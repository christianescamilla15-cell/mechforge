"""Extrae una pieza dibujada sobre el robot (un arma montada) y la exporta.

La pieza se dibujo en su sitio sobre una imagen base (tools/art/halves_test.py).
Lo que cambio respecto a la base es la pieza: se recorta por esa diferencia,
se colorea por elemento y se anade al juego de sprites del mech, con su
ancla respecto a la cintura (scenes/battle/mech_sprites.gd).

No usa la GPU.
Uso: tools/art/run.ps1 tools/art/extract_overlay.py base.png con_arma.png \
        --hip 530 493 --set assets/mechs/ligero_18 --kind chest
"""

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

import cut_body
import export_parts
import recolor


def changed_mask(base, result, threshold=26):
    """Mascara de lo que se dibujo nuevo sobre la base."""
    a = np.asarray(base.convert("RGB")).astype(np.int16)
    b = np.asarray(result.convert("RGB")).astype(np.int16)
    changed = (np.abs(a - b).max(axis=2) > threshold).astype(np.uint8)
    changed = cv2.morphologyEx(changed, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)))
    changed = cv2.morphologyEx(changed, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(changed, connectivity=8)
    if count <= 1:
        return changed.astype(bool)
    areas = stats[1:, cv2.CC_STAT_AREA]
    keep = [1 + index for index, area in enumerate(areas) if area >= 0.05 * areas.max()]
    return np.isin(labels, keep)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("base", type=Path)
    parser.add_argument("result", type=Path)
    parser.add_argument("--hip", type=int, nargs=2, metavar=("FILA", "X"), required=True)
    parser.add_argument("--set", type=Path, required=True, help="ruta del juego de sprites, sin extension")
    parser.add_argument("--kind", required=True, help="nombre de la pieza dentro del juego, por ejemplo chest")
    args = parser.parse_args()

    anchors_path = args.set.with_suffix(".json")
    anchors = json.loads(anchors_path.read_text(encoding="utf-8"))
    scale = anchors["scale"]
    result = Image.open(args.result).convert("RGB")
    mask = changed_mask(Image.open(args.base), result)
    if not mask.any():
        raise SystemExit("no hay diferencias entre la base y el resultado")
    for element, scheme in export_parts.ELEMENTS.items():
        sprite, anchor = cut_body.crop_piece(recolor.recolor(result, scheme), mask, tuple(args.hip))
        size = (round(sprite.width * scale), round(sprite.height * scale))
        sprite.resize(size, Image.LANCZOS).save("%s_%s_%s.png" % (args.set, args.kind, element))
    anchors[args.kind] = {"hip": [round(anchor[0] * scale), round(anchor[1] * scale)], "size": list(size)}
    anchors_path.write_text(json.dumps(anchors, indent=2), encoding="utf-8")
    print("pieza %s: %s (%d pixeles)" % (args.kind, json.dumps(anchors[args.kind]), int(mask.sum())))


if __name__ == "__main__":
    main()
