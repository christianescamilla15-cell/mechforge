"""Genera mechs completos de referencia, uno por elemento, con el estilo
aprobado (tools/art/style.py). Sirve para comprobar que el estilo se mantiene
al cambiar de elemento, de semilla o de ajustes.

Solo texto a imagen con el modelo base; sin control de silueta.
Las imagenes van a art_raw/style/ (carpeta ignorada por git).

Uso:
  tools/art/run.ps1 tools/art/style_test.py                  # los tres elementos
  tools/art/run.ps1 tools/art/style_test.py --only heat --seeds 11 12 13
"""

import argparse
import time
from pathlib import Path

import torch

import sd
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "style"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=sorted(style.ELEMENT_COLORS), help="un solo elemento")
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102])
    parser.add_argument("--steps", type=int, default=style.STEPS)
    parser.add_argument("--cfg", type=float, default=style.CFG)
    parser.add_argument("--width", type=int, default=style.SIZE)
    parser.add_argument("--height", type=int, default=style.SIZE)
    parser.add_argument(
        "--offload", choices=sd.OFFLOAD_CHOICES, default="fp8"
    )
    parser.add_argument(
        "--variant", choices=["approved", "clean"], default="approved", help="estilo del prompt"
    )
    parser.add_argument("--extra", default="", help="etiquetas extra para el sujeto")
    parser.add_argument("--tag", default="", help="sufijo para el nombre de los archivos")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    started = time.time()
    pipe = sd.load_pipeline(args.offload)
    print("modelo cargado en %.0f s" % (time.time() - started), flush=True)

    subject = style.SUBJECT_WHOLE_MECH
    if args.extra:
        subject += ", " + args.extra
    elements = [args.only] if args.only else list(style.ELEMENT_COLORS)
    for element in elements:
        prompt = style.prompt(subject, style.ELEMENT_COLORS[element], args.variant)
        for seed in args.seeds:
            started = time.time()
            image = pipe(
                prompt=prompt,
                negative_prompt=style.NEGATIVE,
                num_inference_steps=args.steps,
                guidance_scale=args.cfg,
                width=args.width,
                height=args.height,
                generator=torch.Generator("cpu").manual_seed(seed),
                callback_on_step_end=sd.progress_printer(args.steps),
            ).images[0]
            name = "%s_%d%s.png" % (element, seed, ("_" + args.tag) if args.tag else "")
            image.save(OUT / name)
            peak = sd.peak_vram_gb()
            print(
                "ok  %s  %.0f s  pico VRAM %.1f GB" % (name, time.time() - started, peak),
                flush=True,
            )
    print("LISTO en", OUT)


if __name__ == "__main__":
    main()
