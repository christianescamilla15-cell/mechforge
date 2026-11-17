"""Arma piloto: un arma llevada por sus etapas tecnologicas (GDD 8 y 12.2).

La etapa 1 sale del bloque, como cualquier pieza. Cada etapa siguiente se
genera a partir de la imagen de la etapa anterior, para que siga siendo la
misma arma pero mas avanzada. Las imagenes van a art_raw/parts/<tanda>/.

Uso:
  tools/art/run.ps1 tools/art/evolve_test.py --batch plasma --seeds 101 102
"""

import argparse
import time
from pathlib import Path

import torch

import blockout
import sd
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "parts"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--blockout", default="cannon", choices=sorted(blockout.PARTS))
    parser.add_argument("--subject", default="plasma", choices=sorted(style.SUBJECT_PARTS))
    parser.add_argument("--element", default="energy", choices=sorted(style.PART_COLORS))
    parser.add_argument("--seeds", type=int, nargs="+", default=[101])
    parser.add_argument("--stages", type=int, default=len(style.WEAPON_STAGES))
    parser.add_argument("--strength", type=float, default=0.6, help="cuanto cambia cada etapa respecto a la anterior")
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    pipe = sd.load_pipeline("fp8", controlled="img2img")
    # Bloque blanco y gris: el color lo pide el prompt (ver art-pipeline.md).
    init, control, _ = blockout.render(args.blockout, "physical", fit=True)

    for seed in args.seeds:
        image = init
        for stage in range(1, args.stages + 1):
            subject = style.SUBJECT_PARTS[args.subject] + ", " + style.WEAPON_STAGES[stage - 1]
            first = stage == 1
            started = time.time()
            image = pipe(
                prompt=style.prompt(subject, style.PART_COLORS[args.element]),
                negative_prompt=style.negative_for(args.subject),
                image=image,
                strength=1.0 if first else args.strength,
                control_image=[control],
                control_mode=[sd.MODE_SCRIBBLE],
                controlnet_conditioning_scale=0.55 if first else 0.3,
                control_guidance_end=0.4 if first else 0.3,
                num_inference_steps=style.STEPS,
                guidance_scale=style.CFG,
                width=blockout.SIZE,
                height=blockout.SIZE,
                generator=torch.Generator("cpu").manual_seed(seed + stage),
            ).images[0]
            name = "%s_%s_%d_etapa%d.png" % (args.subject, args.element, seed, stage)
            image.save(out / name)
            print("ok  %s  %.0f s" % (name, time.time() - started), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
