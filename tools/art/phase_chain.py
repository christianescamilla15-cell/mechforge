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
      --batch fases_torso --zone torso --seeds 101 102 103 --strength 0.7 --strength-end 0.92
"""

import argparse
import time
from pathlib import Path

import cv2
import numpy as np
import torch
from PIL import Image, ImageFilter

import blockout
import cutout
import gpu_turn
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
    # Las tres ultimas, al estilo "dios robot" del anime (el usuario, el
    # 2026-11-21: "los ultimos disenos deben ir enfocados a los disenos del
    # dios robot... no olvides el estilo japones"); el estilo mecha japones lo
    # pone style.prompt.
    "anime god robot, ornate gold armor, star core, halo",
    "colossal machine god, gold crown halo, radiant wings",
    "divine anime mecha god, golden halo, sun wings, majestic",
]


# Lo que se niega primero en una zona, ademas de lo de halves_test. Las
# piernas son UNA pierna de perfil: el juego la dibuja dos veces (la de
# delante y la de detras) y la dobla por cadera, rodilla y tobillo a alturas
# fijas (scenes/battle/leg_rig.gd); el primer piloto de fases de piernas
# (2026-11-23) dibujaba dos piernas en otra postura desde la fase 3 o 4.
EXTRA_NEGATIVE = {"legs": "two legs, extra legs, multiple legs, walking pose"}


def shape_control(image, mask):
    """El contorno de la pieza (lo opaco dentro de la zona) como lineas
    blancas sobre negro: guia la silueta y la postura, no el detalle."""
    figure = cutout.clean_figure(image) & (np.asarray(mask) > 0)
    contours, _ = cv2.findContours(figure.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    lines = np.zeros(figure.shape, dtype=np.uint8)
    cv2.drawContours(lines, contours, -1, 255, blockout.LINE_WIDTH)
    return Image.fromarray(lines).convert("RGB")


def negative(zone, tags):
    """El negativo de una fase: lo de la zona primero (CLIP corta en 77
    tokens y antes se perdian "claws, mechanical arms...", de ahi los punos
    dentro del torso) y sin lo que la fase pide (las alas de las ultimas
    fases chocaban con el "wings" del chasis)."""
    wanted = {word.strip() for word in tags.split(",")}
    words = (
        EXTRA_NEGATIVE.get(zone, "").split(",")
        + halves_test.ZONE_NEGATIVE.get(zone, "").split(",")
        + style.PART_NEGATIVE["chassis"].split(",")
        + style.NEGATIVE.split(",")
    )
    kept = []
    for word in (w.strip() for w in words):
        if word and word not in kept and not any(word in want for want in wanted):
            kept.append(word)
    return ", ".join(kept)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("start", type=Path)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--zone", default="torso", choices=["torso", "legs"])
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102, 103])
    parser.add_argument("--strength", type=float, default=0.6)
    # La fuerza sube de fase en fase hasta esta: las ultimas fases se apartan
    # mas (con 0.6 fija, la fase 10 seguia siendo casi el mismo casco).
    parser.add_argument("--strength-end", type=float, default=None)
    parser.add_argument("--ring", type=int, nargs=2, default=[530, 493], metavar=("FILA", "COLUMNA"))
    parser.add_argument("--phases", type=int, default=len(PHASES))
    # Empezar en otra fase: `start` es entonces el dibujo de la fase anterior.
    parser.add_argument("--first", type=int, default=1)
    # Otras etiquetas para una fase: --tag 9 "machine god, ...".
    parser.add_argument("--tag", nargs=2, action="append", default=[], metavar=("FASE", "ETIQUETAS"))
    parser.add_argument("--steps", type=int, default=style.STEPS)
    # Pasada final suave que solo suma detalle (grabados, lineas) sin
    # cambiar la forma (el usuario, 2026-11-21: "mas detallados y mas arte").
    parser.add_argument("--refine", type=float, default=0.0, help="fuerza de la pasada de detalle (0 = sin ella)")
    parser.add_argument("--refine-tags", default="intricate details, ornate engravings, detailed mechanical parts")
    # Que la pieza conserve su silueta y su postura (las piernas): fuerza del
    # control con el contorno del dibujo de partida (0 = sin el).
    parser.add_argument("--keep-shape", type=float, default=0.0)
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    row, x = args.ring
    start = Image.open(args.start).convert("RGB")
    # Cede la tarjeta si empieza una junta en vivo (gpu_turn): el pipeline
    # vive solo en `turn`; aqui se guarda el tokenizador, que no usa la GPU.
    turn = gpu_turn.Turn(lambda: sd.load_pipeline("fp8", controlled="inpaint"))
    tokenizer = turn.pipe().tokenizer
    _, block_control, _ = blockout.render("chassis", "physical")
    colors = style.colors_for("chassis", "physical")
    mask = halves_test.zone_mask(args.zone, row, x)
    soft = mask.filter(ImageFilter.GaussianBlur(4))
    control = dict(
        control_image=[block_control],
        control_mode=[sd.MODE_SCRIBBLE],
        controlnet_conditioning_scale=0.0,
        control_guidance_end=0.35,
    )
    if args.keep_shape > 0:
        control = dict(
            control_image=[shape_control(start, mask)],
            control_mode=[sd.MODE_SCRIBBLE],
            controlnet_conditioning_scale=args.keep_shape,
            control_guidance_end=0.6,
        )
    phases = list(PHASES[: args.phases])
    for number, tags in args.tag:
        phases[int(number) - 1] = tags
    refine_prompt = style.prompt(style.subject_for("chassis") + ", " + args.refine_tags, colors)
    if len(tokenizer(refine_prompt).input_ids) > 77:
        raise SystemExit("prompt de detalle de mas de 77 tokens")
    prompts = []
    negatives = []
    for tags in phases:
        prompt = style.prompt(style.subject_for("chassis") + ", " + tags, colors)
        tokens = len(tokenizer(prompt).input_ids)
        if tokens > 77:
            raise SystemExit("prompt de %d tokens (maximo 77): %s" % (tokens, tags))
        prompts.append(prompt)
        negatives.append(negative(args.zone, tags))
        # El negativo tambien se corta en 77: solo se avisa, lo que cae es
        # la cola generica (calidad), no lo de la zona.
        cut = len(tokenizer(negatives[-1]).input_ids)
        if cut > 77:
            print("aviso: negativo de %d tokens en: %s" % (cut, tags), flush=True)
    for seed in args.seeds:
        current = start
        current.save(out / ("fase%02d_%d.png" % (args.first - 1, seed)))
        for phase, prompt in enumerate(prompts, start=1):
            if phase < args.first:
                continue
            started = time.time()
            end = args.strength if args.strength_end is None else args.strength_end
            share = (phase - 1) / max(1, len(prompts) - 1)
            strength = args.strength + (end - args.strength) * share
            image = turn.run(
                seed + phase,
                prompt=prompt,
                negative_prompt=negatives[phase - 1],
                image=current,
                mask_image=mask,
                strength=strength,
                **control,
                num_inference_steps=args.steps,
                guidance_scale=style.CFG,
                width=halves_test.SIZE,
                height=halves_test.SIZE,
            ).images[0]
            current = Image.composite(image, current, soft)
            if args.refine > 0:
                image = turn.run(
                    seed + phase + 1000,
                    prompt=refine_prompt,
                    negative_prompt=negatives[phase - 1],
                    image=current,
                    mask_image=mask,
                    strength=args.refine,
                    **control,
                    num_inference_steps=args.steps,
                    guidance_scale=style.CFG,
                    width=halves_test.SIZE,
                    height=halves_test.SIZE,
                ).images[0]
                current = Image.composite(image, current, soft)
            name = "fase%02d_%d.png" % (phase, seed)
            current.save(out / name)
            print("ok  %s  fuerza %.2f  %.0f s" % (name, strength, time.time() - started), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
