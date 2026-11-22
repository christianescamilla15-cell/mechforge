"""Las 10 fases del dibujo de una pieza, encadenadas (OBS-047).

Del usuario (2026-11-21): lo que se ensenaba de Basica a Mitica "perfectamente
podria ir entre una fase, entre base e intermedio... son 10 fases... va junto
con los 10 campeones". Cada fase parte del dibujo de la anterior y repinta solo
la zona de la pieza con sus etiquetas: el cambio se acumula fase a fase, asi
que la fase 10 queda muy lejos de la base sin dejar de ser la misma linea.

Una cadena por semilla. Las imagenes van a art_raw/parts/<tanda>/
fase<NN>_<semilla>.png (la fase 00 es la base).
Uso:
  tools/art/run.ps1 tools/art/phase_chain.py docs/reference/art/elegidos/ligero/robot_18.png \
      --batch fases_torso --zone torso --seeds 101 102 103 --strength 0.6
"""

import argparse
import time
from pathlib import Path

import torch
from PIL import Image, ImageFilter

import blockout
import halves_test
import sd
import style

OUT = halves_test.OUT
# Lo que se suma en cada fase, de la 1 a la 10: primero la maquina (placas,
# reactor, blindaje), luego la energia (aletas, alas, placas que flotan) y al
# final lo divino (halos, nucleo de estrella, luz).
PHASES = [
    "reinforced armor plates, extra vents, bolts",
    "glowing reactor core, energy conduits, layered armor",
    "heavy layered armor, gold trim, crest, glowing core",
    "sharp armor fins, glowing lines, shoulder spikes",
    "energy wings, crystal panels, glowing core",
    "floating armor plates, radiant core, light trails",
    "ornate white and gold armor, halo, glowing runes",
    "star core in chest, floating rings, light trails",
    "celestial armor, double halo, radiant wings",
    "divine machine god, golden halo, cosmic light, wings",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("start", type=Path)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--zone", default="torso", choices=["torso", "legs"])
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102, 103])
    parser.add_argument("--strength", type=float, default=0.6)
    parser.add_argument("--ring", type=int, nargs=2, default=[530, 493], metavar=("FILA", "COLUMNA"))
    parser.add_argument("--phases", type=int, default=len(PHASES))
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    row, x = args.ring
    start = Image.open(args.start).convert("RGB")
    pipe = sd.load_pipeline("fp8", controlled="inpaint")
    _, block_control, _ = blockout.render("chassis", "physical")
    colors = style.colors_for("chassis", "physical")
    mask = halves_test.zone_mask(args.zone, row, x)
    soft = mask.filter(ImageFilter.GaussianBlur(4))
    prompts = []
    for tags in PHASES[: args.phases]:
        prompt = style.prompt(style.subject_for("chassis") + ", " + tags, colors)
        tokens = len(pipe.tokenizer(prompt).input_ids)
        if tokens > 77:
            raise SystemExit("prompt de %d tokens (maximo 77): %s" % (tokens, tags))
        prompts.append(prompt)
    for seed in args.seeds:
        current = start
        current.save(out / ("fase00_%d.png" % seed))
        for phase, prompt in enumerate(prompts, start=1):
            started = time.time()
            image = pipe(
                prompt=prompt,
                negative_prompt=style.negative_for("chassis") + halves_test.ZONE_NEGATIVE.get(args.zone, ""),
                image=current,
                mask_image=mask,
                strength=args.strength,
                control_image=[block_control],
                control_mode=[sd.MODE_SCRIBBLE],
                controlnet_conditioning_scale=0.0,
                control_guidance_end=0.35,
                num_inference_steps=style.STEPS,
                guidance_scale=style.CFG,
                width=halves_test.SIZE,
                height=halves_test.SIZE,
                generator=torch.Generator("cpu").manual_seed(seed + phase),
            ).images[0]
            current = Image.composite(image, current, soft)
            name = "fase%02d_%d.png" % (phase, seed)
            current.save(out / name)
            print("ok  %s  %.0f s" % (name, time.time() - started), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
