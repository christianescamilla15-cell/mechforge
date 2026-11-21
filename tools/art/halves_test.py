"""Piezas dibujadas sobre el chasis estandar (docs/CHASIS.md).

Parte de un cuerpo entero que hace de maniqui y vuelve a dibujar solo una
zona, dejando intacto el resto:
  ring   la cintura: le pone el aro de acople al maniqui
  torso  lo que hay por encima del aro
  legs   lo que hay por debajo
  chest  el arma pesada, montada en el pecho
Como el aro nunca se repinta al hacer torsos y piernas, todas las piezas
nacen encajadas en la misma union.

Las imagenes van a art_raw/parts/<tanda>/.
Uso:
  tools/art/run.ps1 tools/art/halves_test.py maniqui.png --batch aro --zones ring --ring 530 493
  tools/art/run.ps1 tools/art/halves_test.py maniqui.png --batch mitades --ring 530 493 --control-scale 0

Con --extra se suman etiquetas de diseno al sujeto del torso y de las piernas
(los rivales de cada liga, OBS-011: mas presencia de liga en liga):
  tools/art/run.ps1 tools/art/halves_test.py maniqui.png --batch rival_2 --ring 530 493
      --control-scale 0 --strength 1.0 --extra "heavy armor, horns"
"""

import argparse
import time
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageDraw, ImageFilter

import blockout
import sd
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "parts"
SIZE = blockout.SIZE
# Media altura de la franja del aro que nunca se repinta en torsos y piernas.
RING_BAND = 22
RING_RADIUS = (110, 24)
# Zona que se repinta, como (arriba, abajo, izquierda, derecha) respecto al
# centro del aro. Se repinta solo la envolvente de la pieza, no medio lienzo:
# si no, el modelo inventa suelo y horizonte.
ZONES = {
    "ring": (-46, 46, -175, 175),
    # Algo mas ajustada que el torso del maniqui (-409, -275, 250): acota el
    # tamano para que el conjunto se vea estable sobre las piernas finas.
    "torso": (-405, -RING_BAND, -275, 290),
    "legs": (RING_BAND, 440, -300, 330),
    # Arma del pecho: sale del frente del torso, bajo el casco.
    "chest": (-140, -RING_BAND, 25, 420),
}
# El torso va sin brazos: los brazos los ponen las armas (docs/CHASIS.md).
ZONE_NEGATIVE = {"torso": ", fingers, claws, mechanical arms, extra arms, gun, cannon, weapon"}
ZONE_SUBJECT = {
    "chest": "full body, standing, from side, profile, solo, armor, chest cannon, energy cannon, plasma cannon, gun barrel",
    "ring": "full body, standing, from side, profile, solo, armor, mechanical joint, waist",
}


def zone_mask(zone, row, x):
    """Blanco = zona que se vuelve a dibujar."""
    top, bottom, left, right = ZONES[zone]
    mask = np.zeros((SIZE, SIZE), dtype=np.uint8)
    mask[max(0, row + top) : min(SIZE, row + bottom), max(0, x + left) : min(SIZE, x + right)] = 255
    return Image.fromarray(mask, "L")


def ring_control(row, x):
    """El aro de acople como lineas blancas sobre negro."""
    control = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    rx, ry = RING_RADIUS
    ImageDraw.Draw(control).rounded_rectangle(
        [x - rx, row - ry, x + rx, row + ry], radius=ry, outline=(255, 255, 255), width=blockout.LINE_WIDTH
    )
    return control


def chest_control(row, x):
    """Silueta del canon de pecho: caja junto al torso, canon y boca."""
    control = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw = ImageDraw.Draw(control)
    white, width = (255, 255, 255), blockout.LINE_WIDTH
    draw.rounded_rectangle([x + 45, row - 122, x + 170, row - 38], radius=14, outline=white, width=width)
    draw.rectangle([x + 170, row - 100, x + 368, row - 62], outline=white, width=width)
    draw.rectangle([x + 368, row - 108, x + 408, row - 54], outline=white, width=width)
    draw.ellipse([x + 85, row - 100, x + 125, row - 60], outline=white, width=width)
    return control


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("mannequin", type=Path)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--zones", nargs="+", choices=sorted(ZONES), default=["torso", "legs"])
    parser.add_argument("--seeds", type=int, nargs="+", default=[1, 2, 3])
    parser.add_argument(
        "--ring",
        type=int,
        nargs=2,
        metavar=("FILA", "X"),
        default=[blockout.MECH_ORIGIN[1] + blockout.HIP_Y, blockout.MECH_ORIGIN[0] - 40],
        help="centro del aro de cintura en el lienzo",
    )
    parser.add_argument("--control-scale", type=float, default=0.45, help="0 = sin bloque: manda el maniqui")
    parser.add_argument("--control-end", type=float, default=0.35)
    parser.add_argument(
        "--strength",
        type=float,
        default=0.9,
        help="cuanto se aparta del maniqui en la zona repintada; por debajo de 1 hereda sus formas",
    )
    parser.add_argument(
        "--extra",
        nargs="+",
        default=[""],
        help="etiquetas de diseno que se suman al torso y a las piernas; con varias, una tanda por cada una",
    )
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    row, x = args.ring
    mannequin = Image.open(args.mannequin).convert("RGB")
    mannequin.save(out / "_maniqui.png")
    pipe = sd.load_pipeline("fp8", controlled="inpaint")
    _, block_control, _ = blockout.render("chassis", "physical")
    colors = style.colors_for("chassis", "physical")

    for zone in args.zones:
        mask = zone_mask(zone, row, x)
        soft = mask.filter(ImageFilter.GaussianBlur(4))
        if zone == "ring":
            control, scale, end = ring_control(row, x), 0.9, 0.8
        elif zone == "chest":
            control, scale, end = chest_control(row, x), 0.65, 0.5
        else:
            control, scale, end = block_control, args.control_scale, args.control_end
        for variant, extra in enumerate(args.extra if zone in ("torso", "legs") else [""]):
            subject = ZONE_SUBJECT.get(zone, style.subject_for("chassis"))
            if extra:
                subject += ", " + extra
            # Lo que pasa de 77 tokens se pierde sin avisar (y es el final: el estilo).
            prompt = style.prompt(subject, colors)
            tokens = len(pipe.tokenizer(prompt).input_ids)
            if tokens > 77:
                raise SystemExit("prompt de %d tokens (maximo 77): %s" % (tokens, prompt))
            print("zona %s: %d tokens" % (zone, tokens), flush=True)
            for seed in args.seeds:
                started = time.time()
                image = pipe(
                    prompt=prompt,
                    negative_prompt=style.negative_for("chassis") + ZONE_NEGATIVE.get(zone, ""),
                    image=mannequin,
                    mask_image=mask,
                    strength=1.0 if zone == "ring" else args.strength,
                    control_image=[control],
                    control_mode=[sd.MODE_SCRIBBLE],
                    controlnet_conditioning_scale=scale,
                    control_guidance_end=end,
                    num_inference_steps=style.STEPS,
                    guidance_scale=style.CFG,
                    width=SIZE,
                    height=SIZE,
                    generator=torch.Generator("cpu").manual_seed(seed),
                ).images[0]
                # Fuera de la zona repintada se conservan los pixeles del maniqui.
                image = Image.composite(image, mannequin, soft)
                name = "%s_%d.png" % (zone, seed)
                if len(args.extra) > 1:
                    name = "%s_v%d_%d.png" % (zone, variant + 1, seed)
                image.save(out / name)
                print("ok  %s  %.0f s  pico VRAM %.1f GB" % (name, time.time() - started, sd.peak_vram_gb()), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
