"""Prueba del control de silueta (PLAN F4, paso 3).

Genera piezas a partir de nuestros bloques (tools/art/blockout.py) con el
estilo aprobado, y mide cuanto respeta el resultado la silueta dibujada.
Las imagenes van a art_raw/parts/<tanda>/ (carpeta ignorada por git).

Los ajustes de control admiten varios valores: se generan todas las
combinaciones con una sola carga del modelo, para compararlas en una hoja.

Uso:
  tools/art/run.ps1 tools/art/part_test.py --batch prueba
  tools/art/run.ps1 tools/art/part_test.py --batch rejilla --parts mech \
      --control full contour --control-scale 0.35 0.5 --control-end 0.3 0.4
"""

import argparse
import itertools
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image

import blockout
from cutout import foreground_mask
import sd
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "parts"


def silhouette_match(image, mask):
    """Compara la figura generada con la silueta pedida.

    Devuelve (iou, cubierto, fuera): cubierto es la parte de la silueta que la
    figura rellena; fuera es la parte de la figura que se sale de la silueta.
    """
    figure = foreground_mask(image)
    wanted = np.asarray(mask) > 127
    union = np.logical_or(figure, wanted).sum()
    inside = np.logical_and(figure, wanted).sum()
    iou = inside / union if union else 0.0
    covered = inside / wanted.sum() if wanted.sum() else 0.0
    outside = 1.0 - inside / figure.sum() if figure.sum() else 0.0
    return iou, covered, outside


def shape_from_image(path):
    """Usa la silueta de una imagen ya generada como molde: el contorno manda
    y el interior queda libre. El bloque inicial es gris neutro, para que el
    color lo ponga el prompt y no un relleno plano."""
    figure = foreground_mask(Image.open(path))
    mask = Image.fromarray((figure * 255).astype(np.uint8), "L")
    init = Image.new("RGB", mask.size, blockout.BACKGROUND)
    init.paste((205, 206, 210), mask=mask)
    return init, blockout.contour_of(mask), mask


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch", required=True, help="nombre de la tanda (subcarpeta de salida)")
    parser.add_argument("--parts", nargs="+", default=["mech", "torso", "legs", "cannon"])
    parser.add_argument("--element", nargs="+", choices=sorted(style.ELEMENT_COLORS), default=["physical"])
    parser.add_argument("--seeds", type=int, nargs="+", default=[101])
    parser.add_argument(
        "--control",
        nargs="+",
        choices=["full", "contour"],
        default=["contour"],
        help="full: todas las lineas del bloque; contour: solo el borde exterior",
    )
    parser.add_argument(
        "--strength", type=float, nargs="+", default=[1.0], help="cuanto se aparta del bloque de color (1 = casi nada queda)"
    )
    parser.add_argument("--control-scale", type=float, nargs="+", default=[0.5])
    parser.add_argument("--control-end", type=float, nargs="+", default=[0.4])
    parser.add_argument(
        "--init-palette",
        choices=sorted(blockout.PALETTES),
        help="paleta del bloque inicial; por defecto la del elemento. El color final lo pide el prompt",
    )
    parser.add_argument("--shape-from", type=Path, help="imagen cuya silueta se usa como molde en vez del bloque")
    parser.add_argument(
        "--min-match", type=float, default=0.0, help="coincidencia minima con la silueta; por debajo va a descartes/"
    )
    parser.add_argument("--fit", action="store_true", help="pieza agrandada al 80 %% del lienzo")
    parser.add_argument("--steps", type=int, default=style.STEPS)
    parser.add_argument("--offload", choices=sd.OFFLOAD_CHOICES, default="fp8")
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    started = time.time()
    pipe = sd.load_pipeline(args.offload, controlled="img2img")
    print("modelo cargado en %.0f s" % (time.time() - started), flush=True)

    grid = list(
        itertools.product(
            args.parts, args.element, args.control, args.strength, args.control_scale, args.control_end, args.seeds
        )
    )
    print("%d imagenes por generar" % len(grid), flush=True)
    for part, element, control_kind, strength, scale, end, seed in grid:
        init, control, mask = blockout.render(part, args.init_palette or element, args.fit)
        if control_kind == "contour":
            control = blockout.contour_of(mask)
        if args.shape_from:
            init, control, mask = shape_from_image(args.shape_from)
            control.save(out / "_molde_control.png")
        prompt = style.prompt(style.subject_for(part), style.colors_for(part, element))
        started = time.time()
        image = pipe(
            prompt=prompt,
            negative_prompt=style.negative_for(part),
            image=init,
            strength=strength,
            control_image=[control],
            control_mode=[sd.MODE_SCRIBBLE],
            controlnet_conditioning_scale=scale,
            control_guidance_end=end,
            num_inference_steps=args.steps,
            guidance_scale=style.CFG,
            width=blockout.SIZE,
            height=blockout.SIZE,
            generator=torch.Generator("cpu").manual_seed(seed),
        ).images[0]
        name = "%s_%s_%d%s_%s_s%03d_c%03d_e%03d.png" % (
            part,
            element,
            seed,
            "_fit" if args.fit else "",
            control_kind,
            round(strength * 100),
            round(scale * 100),
            round(end * 100),
        )
        iou, covered, outside = silhouette_match(image, mask)
        # Lo que no se parece a la silueta pedida se aparta, no se borra.
        folder = out if iou >= args.min_match else out / "descartes"
        folder.mkdir(exist_ok=True)
        image.save(folder / name)
        print(
            "%s  %s  %.0f s  pico VRAM %.1f GB  silueta: IoU %.2f, cubierto %.2f, fuera %.2f"
            % ("ok " if folder == out else "DESCARTE", name, time.time() - started, sd.peak_vram_gb(), iou, covered, outside),
            flush=True,
        )
    print("LISTO en", out)


if __name__ == "__main__":
    main()
