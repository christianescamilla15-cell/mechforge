"""Corta cuerpos enteros en torso y piernas por la cadera (PLAN F4, paso 3).

Para cada imagen:
  1. separa la figura del fondo liso,
  2. busca la cadera: la fila mas estrecha de la figura en la franja central,
  3. guarda torso y piernas como PNG con transparencia, y en cuts.json el
     ancla de la cadera de cada pieza (en pixeles de su propio PNG).
Ademas guarda una hoja de control con la linea de corte, y con --mix otra con
cada torso montado sobre cada par de piernas, para ver si se pueden mezclar.

No usa la GPU.
Uso: tools/art/run.ps1 tools/art/cut_body.py art_raw/parts/lote/a.png b.png --out art_raw/cuts/prueba --mix
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import cutout

# Cuanto se solapan torso y piernas alrededor del corte, para que al montar
# piezas de cuerpos distintos no quede una rendija.
OVERLAP = 14
BACKGROUND = (172, 173, 174)


def find_hip(mask, band):
    """Devuelve (fila, x) de la cadera: la fila mas estrecha dentro de la
    franja dada, medida en fraccion de la altura de la figura desde arriba."""
    rows = np.where(mask.any(axis=1))[0]
    top, bottom = int(rows[0]), int(rows[-1])
    widths = mask.sum(axis=1).astype(float)
    smooth = np.convolve(widths, np.ones(9) / 9, mode="same")
    first = top + int(band[0] * (bottom - top))
    last = top + int(band[1] * (bottom - top))
    row = first + int(np.argmin(smooth[first:last]))
    columns = np.where(mask[row])[0]
    return row, int((columns[0] + columns[-1]) / 2)


def crop_piece(image, mask, hip):
    """Recorta la pieza a su caja y devuelve (png, ancla de cadera local)."""
    rows = np.where(mask.any(axis=1))[0]
    columns = np.where(mask.any(axis=0))[0]
    box = (int(columns[0]), int(rows[0]), int(columns[-1]) + 1, int(rows[-1]) + 1)
    piece = cutout.to_rgba(image, mask).crop(box)
    return piece, (hip[1] - box[0], hip[0] - box[1])


def cut(path, band, fixed=None):
    image = Image.open(path).convert("RGB")
    mask = cutout.clean_figure(image)
    # Con el chasis estandar la cintura esta siempre en el mismo punto.
    row, x = fixed if fixed else find_hip(mask, band)
    upper, lower = mask.copy(), mask.copy()
    upper[row + OVERLAP :] = False
    lower[: row - OVERLAP] = False
    torso, torso_anchor = crop_piece(image, upper, (row, x))
    legs, legs_anchor = crop_piece(image, lower, (row, x))
    check = image.copy()
    draw = ImageDraw.Draw(check)
    draw.line([(0, row), (image.width, row)], fill=(255, 0, 80), width=3)
    draw.ellipse([x - 9, row - 9, x + 9, row + 9], outline=(255, 0, 80), width=3)
    return {"torso": (torso, torso_anchor), "legs": (legs, legs_anchor), "check": check}


def sheet(images, columns, cell, labels=None):
    rows = (len(images) + columns - 1) // columns
    result = Image.new("RGB", (columns * cell, rows * cell), BACKGROUND)
    draw = ImageDraw.Draw(result)
    for index, image in enumerate(images):
        thumb = image.copy()
        thumb.thumbnail((cell, cell))
        origin = ((index % columns) * cell, (index // columns) * cell)
        result.paste(thumb, origin)
        if labels:
            draw.text((origin[0] + 6, origin[1] + 6), labels[index], fill=(20, 20, 20))
    return result


def mounted(torso, legs, cell=640, scale=0.6):
    """Monta un torso sobre unas piernas haciendo coincidir sus anclas."""
    canvas = Image.new("RGBA", (cell, cell), BACKGROUND + (255,))
    hip = (cell // 2, int(cell * 0.42))
    for piece, anchor in (legs, torso):
        small = piece.resize((max(1, int(piece.width * scale)), max(1, int(piece.height * scale))), Image.LANCZOS)
        canvas.alpha_composite(small, (hip[0] - int(anchor[0] * scale), hip[1] - int(anchor[1] * scale)))
    return canvas.convert("RGB")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("images", nargs="+", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument(
        "--band", type=float, nargs=2, default=[0.30, 0.58], help="franja donde buscar la cadera (fraccion de la altura)"
    )
    parser.add_argument("--hip", type=int, nargs=2, metavar=("FILA", "X"), help="cintura fija del chasis estandar")
    parser.add_argument("--torsos", nargs="*", type=Path, default=[], help="imagenes de las que solo se usa el torso")
    parser.add_argument("--mix", action="store_true", help="hoja con cada torso sobre cada par de piernas")
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    cuts, anchors = {}, {}
    for path in list(args.images) + list(args.torsos):
        result = cut(path, args.band, tuple(args.hip) if args.hip else None)
        cuts[path.stem] = result
        for kind in ("torso", "legs"):
            piece, anchor = result[kind]
            piece.save(args.out / ("%s_%s.png" % (path.stem, kind)))
            anchors["%s_%s" % (path.stem, kind)] = {"hip": list(anchor), "size": list(piece.size)}
    (args.out / "cuts.json").write_text(json.dumps(anchors, indent=2), encoding="utf-8")

    names = list(cuts)
    sheet([cuts[n]["check"] for n in names], min(4, len(names)), 512, names).save(args.out / "_corte.png")
    if args.mix:
        # Si se dieron torsos aparte, las imagenes principales solo ponen las piernas.
        tops = [p.stem for p in args.torsos] or names
        bottoms = [p.stem for p in args.images]
        combos = [mounted(cuts[t]["torso"], cuts[l]["legs"]) for l in bottoms for t in tops]
        sheet(combos, len(tops), 400).save(args.out / "_mezcla.png")
    print("%d cuerpos cortados en %s" % (len(names), args.out))


if __name__ == "__main__":
    main()
