"""Cambia los colores de una pieza por zonas, sin generar arte nuevo.

Es la prueba del color personalizable (GDD 8) y de pintar el elemento sobre
un dibujo base blanco, que es donde el estilo aprobado sale mejor. Zonas:
  principal   blindaje claro y poco saturado
  secundario  estructura oscura y poco saturada
  luces       zonas saturadas y brillantes
La linea de tinta (lo mas oscuro) no se toca. En el juego esto mismo lo hara
un shader; aqui se hace con numpy para poder ensenarlo.

No usa la GPU.
Uso: tools/art/run.ps1 tools/art/recolor.py imagen.png --out art_raw/hoja_color.png
"""

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

import cutout

# nombre: (principal, secundario, luces)
SCHEMES = {
    "original": None,
    "calor": ((226, 96, 48), (74, 50, 54), (255, 208, 64)),
    "energia": ((62, 118, 222), (40, 48, 84), (120, 245, 255)),
    "a gusto: verde y negro": ((96, 168, 92), (38, 40, 44), (255, 96, 200)),
    "a gusto: dorado": ((224, 178, 70), (84, 60, 50), (255, 80, 60)),
}


def zones(image):
    """Devuelve las mascaras (principal, secundario, luces) y el brillo."""
    rgb = np.asarray(image.convert("RGB"))
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    saturation, value = hsv[..., 1] / 255.0, hsv[..., 2] / 255.0
    figure = cutout.clean_figure(image)
    ink = value < 0.22
    lights = figure & ~ink & (saturation > 0.45) & (value > 0.5)
    primary = figure & ~ink & ~lights & (value > 0.6)
    secondary = figure & ~ink & ~lights & ~primary
    return primary, secondary, lights, value


def recolor(image, scheme):
    if scheme is None:
        return image.convert("RGB")
    primary, secondary, lights, value = zones(image)
    out = np.asarray(image.convert("RGB")).astype(np.float32)
    for mask, color, reference in ((primary, scheme[0], 0.92), (secondary, scheme[1], 0.45), (lights, scheme[2], 0.9)):
        shade = np.clip(value / reference, 0.0, 1.25)[..., None]
        tinted = np.clip(np.array(color, dtype=np.float32) * shade, 0, 255)
        out[mask] = tinted[mask]
    return Image.fromarray(out.astype(np.uint8), "RGB")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("image", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--cell", type=int, default=480)
    args = parser.parse_args()
    image = Image.open(args.image)
    sheet = Image.new("RGB", (args.cell * len(SCHEMES), args.cell + 26), "#20242b")
    draw = ImageDraw.Draw(sheet)
    for index, (name, scheme) in enumerate(SCHEMES.items()):
        result = recolor(image, scheme)
        result.thumbnail((args.cell, args.cell))
        sheet.paste(result, (index * args.cell, 0))
        draw.text((index * args.cell + 8, args.cell + 6), name, fill="#d7dde6")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.out)
    print("hoja de color:", args.out)


if __name__ == "__main__":
    main()
