"""Las seis formas del robot de asistencia (GDD 4), a lienzo completo.

Receta de los cuerpos aprobados (docs/reference/art-pipeline.md): bloque
inicial blanco y gris, todas sus lineas como control suelto (escala 0.5,
final 0.4) y fuerza 1.0, para que el modelo ponga el detalle de mecha y
nosotros solo la distribucion. Dibujarlo pequeno dentro de una zona, con el
control firme, daba discos planos sin detalle (tools/art/mounts_test.py).

Cada forma es mas grande y tiene mas piezas que la anterior:
  0 Sonda      casco, sensor, torreta y capsula inferior
  1 Vigia      + aleta de cola
  2 Centinela  + gondola de motor
  3 Custodio   + alas
  4 Guardian   + placas de escudo
  5 Arconte    + anillo y piezas flotantes

Las imagenes van a art_raw/parts/<tanda>/forma<k>_<semilla>.png.
Uso:
  tools/art/run.ps1 tools/art/assist_test.py --batch asistente_mecha --seeds 101 102 103 104
  tools/art/run.ps1 tools/art/assist_test.py --batch asistente_mecha --blocks-only
"""

import argparse
import time
from pathlib import Path

import torch
from PIL import Image, ImageDraw

import blockout
import sd
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "parts"
SIZE = blockout.SIZE
CENTER = (530, 520)

# Piezas en unidades del casco (mira a la derecha): (papel, poligono, forma
# desde la que aparece). El orden es de atras hacia delante.
PARTS = [
    ("armor", [(-0.35, -0.4), (-1.2, -1.05), (-0.95, -0.5)], 3),
    ("armor", [(-0.4, 0.3), (-1.15, 0.85), (-0.85, 0.32)], 3),
    ("armor", [(-0.75, -0.25), (-1.25, -0.75), (-0.5, -0.36)], 1),
    ("frame", [(-1.15, -0.14), (-0.85, -0.2), (-0.85, 0.2), (-1.15, 0.16)], 0),
    ("frame", [(-0.25, -0.62), (0.2, -0.62), (0.28, -0.38), (-0.32, -0.4)], 0),
    ("armor2", [(0.2, -0.58), (0.95, -0.56), (0.95, -0.47), (0.2, -0.46)], 0),
    ("frame", [(-0.3, 0.32), (0.25, 0.3), (0.2, 0.56), (-0.25, 0.58)], 0),
    ("armor2", [(0.2, 0.4), (0.85, 0.42), (0.85, 0.5), (0.2, 0.5)], 0),
    ("armor", [(-0.9, -0.18), (-0.3, -0.42), (0.5, -0.34), (1.0, -0.05), (0.75, 0.22), (-0.2, 0.34), (-0.85, 0.2)], 0),
    ("armor2", [(-0.7, 0.0), (-0.15, -0.05), (-0.1, 0.2), (-0.72, 0.24)], 2),
    ("accent", [(0.55, -0.2), (0.85, -0.1), (0.7, 0.02), (0.5, -0.02)], 0),
    ("armor", [(0.3, -0.5), (0.9, -0.42), (1.15, -0.1), (0.9, -0.2), (0.45, -0.36)], 4),
    ("armor", [(0.4, 0.2), (1.05, 0.05), (0.8, 0.35)], 4),
    ("accent", [(-0.2, -0.95), (-0.05, -1.08), (0.1, -0.95), (-0.05, -0.82)], 5),
    ("accent", [(0.45, -0.88), (0.57, -0.98), (0.69, -0.88), (0.57, -0.78)], 5),
]
# Anillo del Arconte: arco por detras del casco, en unidades.
RING = (-0.95, -0.8, 0.75, 0.8)

SUBJECT = "non-humanoid robot, drone, flying, floating, from side, profile, solo, armor, thrusters, cannon"
STAGE_EXTRA = [
    "compact, simple",
    "tail fin, antenna",
    "engine pods, twin cannons",
    "mechanical wings, twin cannons",
    "mechanical wings, heavy armor, shield",
    "mechanical wings, heavy armor, halo, intricate",
]
NEGATIVE = "humanoid, legs, arms, hands, propeller, airplane, energy beam, laser, firing, 1other"


def unit_of(form):
    """Pixeles por unidad: cada forma es mas grande."""
    return 230 + 26 * form


def to_canvas(form, point):
    unit = unit_of(form)
    return (CENTER[0] + unit * point[0], CENTER[1] + unit * point[1])


def render(form):
    """Devuelve (init, control) de la forma: bloque de color y sus lineas."""
    palette = blockout.PALETTES["physical"]
    init = Image.new("RGB", (SIZE, SIZE), blockout.BACKGROUND)
    control = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw_init, draw_control = ImageDraw.Draw(init), ImageDraw.Draw(control)
    width = blockout.LINE_WIDTH
    if form >= 5:
        left, top = to_canvas(form, RING[:2])
        right, bottom = to_canvas(form, RING[2:])
        draw_init.ellipse([left, top, right, bottom], outline=palette["frame"], width=width * 5)
        for grow in (0, width * 5):
            box = [left + grow, top + grow, right - grow, bottom - grow]
            draw_control.ellipse(box, outline=(255, 255, 255), width=width)
    for role, polygon, since in PARTS:
        if form < since:
            continue
        points = [to_canvas(form, p) for p in polygon]
        closed = points + [points[0]]
        draw_init.polygon(points, fill=palette[role])
        draw_init.line(closed, fill=blockout.OUTLINE, width=width, joint="curve")
        # En el control cada pieza tapa las lineas de lo que queda detras.
        draw_control.polygon(points, fill=(0, 0, 0))
        draw_control.line(closed, fill=(255, 255, 255), width=width, joint="curve")
    return init, control


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--forms", type=int, nargs="+", default=list(range(6)))
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102, 103, 104])
    parser.add_argument("--control-scale", type=float, default=0.5)
    parser.add_argument("--control-end", type=float, default=0.4)
    parser.add_argument("--blocks-only", action="store_true", help="solo guarda los bloques, sin GPU")
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    blocks = {}
    for form in args.forms:
        blocks[form] = render(form)
        blocks[form][0].save(out / ("_bloque_%d.png" % form))
    if args.blocks_only:
        print("LISTO (solo bloques) en", out)
        return

    pipe = sd.load_pipeline("fp8", controlled="img2img")
    colors = style.colors_for("chassis", "physical")
    for form in args.forms:
        init, control = blocks[form]
        prompt = style.prompt(SUBJECT + ", " + STAGE_EXTRA[form], colors)
        for seed in args.seeds:
            started = time.time()
            image = pipe(
                prompt=prompt,
                negative_prompt=style.NEGATIVE + ", " + NEGATIVE,
                image=init,
                strength=1.0,
                control_image=[control],
                control_mode=[sd.MODE_SCRIBBLE],
                controlnet_conditioning_scale=args.control_scale,
                control_guidance_end=args.control_end,
                num_inference_steps=style.STEPS,
                guidance_scale=style.CFG,
                width=SIZE,
                height=SIZE,
                generator=torch.Generator("cpu").manual_seed(seed),
            ).images[0]
            name = "forma%d_%d.png" % (form, seed)
            image.save(out / name)
            print("ok  %s  %.0f s  pico VRAM %.1f GB" % (name, time.time() - started, sd.peak_vram_gb()), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
