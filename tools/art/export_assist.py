"""Exporta al juego una forma del robot de asistencia (tools/art/assist_test.py).

Recorta la figura del fondo, la colorea por elemento y la guarda con sus
anclas en assets/mechs/asistente_ligero.json: el centro del casco y las bocas
de sus dos armas (las del bloque con el que se dibujo), en pixeles del sprite.
El juego las lee en scenes/battle/mech_sprites.gd.

No usa la GPU.
Uso: tools/art/run.ps1 tools/art/export_assist.py --form 3 art_raw/parts/asistente_mecha/forma3_102.png
"""

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

import assist_test
import cutout
import export_parts
import recolor

ROOT = Path(__file__).resolve().parents[2]
SET = ROOT / "assets" / "mechs" / "asistente_ligero"
# Reduccion respecto al lienzo de 1024.
SCALE = 0.25
# Bocas de las armas en unidades del bloque (assist_test.PARTS).
GUN_TOP = (0.95, -0.515)
GUN_LOW = (0.85, 0.46)


def enclosed_background(image, tolerance=20, min_area=400, hole_color=8):
    """Fondo que quedo encerrado dentro de la figura (el hueco de un anillo):
    manchas grandes del color del fondo que no tocan el borde. Un hueco deja
    ver el fondo tal cual (de media, a 3 del color del borde); una plancha
    gris clara de la pieza se le parece pero no tanto (a unos 15: el cuerpo
    de la ancla laser en la fase 7 salia con agujeros): solo cuentan las
    manchas a menos de `hole_color` de media."""
    pixels = np.asarray(image).astype(np.int16)
    border = np.concatenate([pixels[:6].reshape(-1, 3), pixels[-6:].reshape(-1, 3)])
    difference = np.abs(pixels - np.median(border, axis=0)).max(axis=2)
    similar = (difference < tolerance).astype(np.uint8)
    similar = cv2.morphologyEx(similar, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(similar, connectivity=4)
    keep = [
        index
        for index in range(1, count)
        if stats[index, cv2.CC_STAT_AREA] >= min_area and difference[labels == index].mean() < hole_color
    ]
    return np.isin(labels, keep)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("image", type=Path)
    parser.add_argument("--form", type=int, required=True, choices=range(6))
    args = parser.parse_args()

    image = Image.open(args.image).convert("RGB")
    mask = np.logical_and(cutout.clean_figure(image), ~enclosed_background(image))
    rows = np.where(mask.any(axis=1))[0]
    columns = np.where(mask.any(axis=0))[0]
    box = (int(columns[0]), int(rows[0]), int(columns[-1]) + 1, int(rows[-1]) + 1)
    size = (round((box[2] - box[0]) * SCALE), round((box[3] - box[1]) * SCALE))
    kind = "assist_%d" % args.form
    for element, scheme in export_parts.ELEMENTS.items():
        sprite = cutout.to_rgba(recolor.recolor(image, scheme), mask).crop(box)
        sprite.resize(size, Image.LANCZOS).save("%s_%s_%s.png" % (SET, kind, element))

    anchors_path = SET.with_suffix(".json")
    anchors = {"scale": SCALE}
    if anchors_path.exists():
        anchors = json.loads(anchors_path.read_text(encoding="utf-8"))
        anchors["scale"] = SCALE
    unit = assist_test.unit_of(args.form)
    center = assist_test.CENTER
    anchors[kind] = {
        "center": [round((center[0] - box[0]) * SCALE), round((center[1] - box[1]) * SCALE)],
        "size": list(size),
        "gun_top": [round(unit * GUN_TOP[0] * SCALE), round(unit * GUN_TOP[1] * SCALE)],
        "gun_low": [round(unit * GUN_LOW[0] * SCALE), round(unit * GUN_LOW[1] * SCALE)],
    }
    anchors_path.write_text(json.dumps(anchors, indent=2), encoding="utf-8")
    print("exportada %s: %s" % (kind, json.dumps(anchors[kind])))


if __name__ == "__main__":
    main()
