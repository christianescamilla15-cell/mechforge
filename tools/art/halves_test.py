"""Piezas dibujadas sobre el chasis estandar (docs/CHASIS.md).

Parte de un cuerpo entero que hace de maniqui. Deja intacta una mitad y el
aro de la cintura, y vuelve a dibujar solo la otra mitad. Asi cada torso
nuevo nace encajado en el mismo aro y sobre las mismas piernas, y cada par
de piernas nuevo bajo el mismo torso: todos comparten la union.

Las imagenes van a art_raw/parts/<tanda>/.
Uso:
  tools/art/run.ps1 tools/art/halves_test.py maniqui.png --batch mitades --seeds 1 2 3
"""

import argparse
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageFilter

import blockout
import sd
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "parts"
# Fila del lienzo donde esta el centro del aro de la cintura.
RING_ROW = blockout.MECH_ORIGIN[1] + blockout.HIP_Y
# Media altura de la franja del aro que nunca se repinta.
RING_BAND = 22


def half_mask(half):
    """Blanco = zona que se vuelve a dibujar."""
    mask = np.zeros((blockout.SIZE, blockout.SIZE), dtype=np.uint8)
    if half == "torso":
        mask[: RING_ROW - RING_BAND] = 255
    else:
        mask[RING_ROW + RING_BAND :] = 255
    return Image.fromarray(mask, "L")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("mannequin", type=Path)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--halves", nargs="+", choices=["torso", "legs"], default=["torso", "legs"])
    parser.add_argument("--seeds", type=int, nargs="+", default=[1, 2, 3])
    parser.add_argument("--control-scale", type=float, default=0.45)
    parser.add_argument("--control-end", type=float, default=0.35)
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    mannequin = Image.open(args.mannequin).convert("RGB")
    mannequin.save(out / "_maniqui.png")
    pipe = sd.load_pipeline("fp8", controlled="inpaint")
    _, control, _ = blockout.render("chassis", "physical")
    prompt = style.prompt(style.subject_for("chassis"), style.colors_for("chassis", "physical"))

    for half in args.halves:
        mask = half_mask(half)
        soft = mask.filter(ImageFilter.GaussianBlur(4))
        for seed in args.seeds:
            started = time.time()
            image = pipe(
                prompt=prompt,
                negative_prompt=style.negative_for("chassis"),
                image=mannequin,
                mask_image=mask,
                strength=1.0,
                control_image=[control],
                control_mode=[sd.MODE_SCRIBBLE],
                controlnet_conditioning_scale=args.control_scale,
                control_guidance_end=args.control_end,
                num_inference_steps=style.STEPS,
                guidance_scale=style.CFG,
                width=blockout.SIZE,
                height=blockout.SIZE,
                generator=torch.Generator("cpu").manual_seed(seed),
            ).images[0]
            # Fuera de la zona repintada se conservan los pixeles del maniqui.
            image = Image.composite(image, mannequin, soft)
            name = "%s_%d.png" % (half, seed)
            image.save(out / name)
            print("ok  %s  %.0f s  pico VRAM %.1f GB" % (name, time.time() - started, sd.peak_vram_gb()), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
