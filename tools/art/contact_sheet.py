"""Junta varias imagenes en una hoja de contactos con su nombre debajo, para
compararlas de un vistazo.

Uso: tools/art/run.ps1 tools/art/contact_sheet.py art_raw/style --out art_raw/hoja.png
     [--match texto] [--columns 3] [--cell 512]
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--match", default="", help="solo archivos cuyo nombre lo contenga")
    parser.add_argument("--columns", type=int, default=3)
    parser.add_argument("--cell", type=int, default=512)
    args = parser.parse_args()

    files = sorted(p for p in args.folder.glob("*.png") if args.match in p.name)
    if not files:
        raise SystemExit("no hay imagenes en %s" % args.folder)
    label = 26
    rows = (len(files) + args.columns - 1) // args.columns
    sheet = Image.new("RGB", (args.columns * args.cell, rows * (args.cell + label)), "#20242b")
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(files):
        image = Image.open(path).convert("RGB")
        image.thumbnail((args.cell, args.cell))
        x = (index % args.columns) * args.cell + (args.cell - image.width) // 2
        y = (index // args.columns) * (args.cell + label)
        sheet.paste(image, (x, y))
        draw.text(((index % args.columns) * args.cell + 8, y + args.cell + 6), path.stem, fill="#d7dde6")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print("hoja con %d imagenes: %s" % (len(files), args.out))


if __name__ == "__main__":
    main()
