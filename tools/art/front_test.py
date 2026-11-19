"""Prueba de robots de frente (pedido del usuario el 2026-11-18: "los robots
no deben estar de lado sino de frente"; eligio probar con un robot antes de
rehacer todo el arte).

Receta de los cuerpos aprobados (docs/reference/art-pipeline.md y
tools/art/assist_test.py): bloque inicial de color, sus lineas como control
suelto (escala 0.5, final 0.4) y fuerza 1.0, para que el modelo ponga el
detalle de mecha y el bloque solo la distribucion. Dos tandas sobre el mismo
bloque de frente:
  maniqui  blanco y gris, sin armas: la base para dibujar piezas de frente
  horno    el Horno Andante del usuario de frente, en naranja: cuchilla en un
           antebrazo, escopeta en el otro y rotativa en un hombro, para
           compararlo con su version de perfil

Las imagenes van a art_raw/parts/frente/<tanda>_<semilla>.png.
Uso:
  tools/art/run.ps1 tools/art/front_test.py --blocks-only
  tools/art/run.ps1 tools/art/front_test.py --what maniqui horno --seeds 101 102 103 104
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
OUT = ROOT / "art_raw" / "parts" / "frente"
SIZE = blockout.SIZE
CENTER_X = 512


def mirror(points):
    """El mismo poligono al otro lado del eje del robot."""
    return [(2 * CENTER_X - x, y) for x, y in points]


# Piezas de frente, en pixeles del lienzo (el robot mira al espectador). El
# orden es de atras hacia delante; (papel, poligono). Lo que va a los dos
# lados se escribe una vez y se refleja.
LEFT = [
    ("frame", [(452, 600), (500, 600), (492, 760), (444, 760)]),  # muslo
    ("armor", [(430, 750), (500, 745), (498, 900), (436, 905)]),  # espinilla
    ("armor2", [(410, 895), (505, 895), (515, 945), (398, 945)]),  # pie
    ("accent", [(446, 770), (488, 768), (486, 800), (448, 802)]),  # rodillera
    ("frame", [(300, 330), (350, 318), (362, 470), (318, 480)]),  # brazo
    ("armor", [(240, 250), (372, 236), (388, 330), (270, 352)]),  # hombrera
    ("accent", [(262, 272), (360, 262), (366, 290), (270, 300)]),
]
TORSO = [
    ("frame", [(452, 540), (572, 540), (590, 610), (434, 610)]),  # cintura
    ("armor", [(380, 250), (644, 250), (620, 470), (560, 545), (464, 545), (404, 470)]),
    ("armor2", [(440, 300), (584, 300), (566, 420), (458, 420)]),  # pecho
    ("accent", [(488, 430), (536, 430), (532, 470), (492, 470)]),  # nucleo
    ("armor", [(470, 150), (554, 150), (572, 240), (452, 240)]),  # casco
    ("armor2", [(500, 95), (524, 95), (540, 160), (484, 160)]),  # cresta
    ("accent", [(478, 190), (546, 190), (540, 210), (484, 210)]),  # visor
]
# Armas del Horno Andante: cuchilla en el antebrazo izquierdo (del robot,
# a la derecha de la imagen), escopeta en el derecho y rotativa al hombro.
WEAPONS = [
    ("frame", [(286, 460), (346, 452), (352, 590), (290, 598)]),  # antebrazo escopeta
    ("armor2", [(262, 560), (370, 552), (376, 650), (256, 660)]),  # escopeta
    ("accent", [(278, 650), (358, 644), (360, 676), (280, 682)]),  # bocas
    ("frame", [(678, 460), (738, 452), (734, 590), (672, 598)]),  # antebrazo hoja
    ("accent", [(690, 590), (722, 588), (716, 860), (700, 860)]),  # hoja
    ("armor2", [(612, 150), (720, 140), (730, 236), (618, 246)]),  # rotativa
    ("accent", [(640, 110), (700, 104), (704, 150), (642, 156)]),  # canones
]
SUBJECTS = {
    "maniqui": "full body, standing, from front, facing viewer, symmetrical, solo, armor, thrusters",
    "horno": "full body, standing, from front, facing viewer, solo, arm blade, arm cannon, shoulder cannon",
}
ELEMENT = {"maniqui": "physical", "horno": "heat"}
NEGATIVE = "from side, profile, wings, energy beam, laser, firing, holding weapon, hands"


def render(what):
    """Devuelve (init, control) del robot de frente: bloque y sus lineas."""
    palette = blockout.PALETTES[ELEMENT[what]]
    init = Image.new("RGB", (SIZE, SIZE), blockout.BACKGROUND)
    control = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    draw_init, draw_control = ImageDraw.Draw(init), ImageDraw.Draw(control)
    width = blockout.LINE_WIDTH
    shapes = []
    for role, poly in LEFT:
        shapes.append((role, poly))
        shapes.append((role, mirror(poly)))
    shapes += TORSO
    if what == "horno":
        shapes += WEAPONS
    else:
        # El maniqui lleva antebrazos sin armas.
        for poly in [[(286, 460), (346, 452), (352, 590), (290, 598)]]:
            shapes.append(("frame", poly))
            shapes.append(("frame", mirror(poly)))
    for role, points in shapes:
        closed = points + [points[0]]
        draw_init.polygon(points, fill=palette[role])
        draw_init.line(closed, fill=blockout.OUTLINE, width=width, joint="curve")
        # En el control cada pieza tapa las lineas de lo que queda detras.
        draw_control.polygon(points, fill=(0, 0, 0))
        draw_control.line(closed, fill=(255, 255, 255), width=width, joint="curve")
    return init, control


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--what", nargs="+", default=["maniqui", "horno"], choices=list(SUBJECTS))
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102, 103, 104])
    parser.add_argument("--control-scale", type=float, default=0.5)
    parser.add_argument("--control-end", type=float, default=0.4)
    parser.add_argument("--blocks-only", action="store_true", help="solo guarda los bloques, sin GPU")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    blocks = {}
    for what in args.what:
        blocks[what] = render(what)
        blocks[what][0].save(OUT / ("_bloque_%s.png" % what))
        blocks[what][1].save(OUT / ("_control_%s.png" % what))
    if args.blocks_only:
        print("LISTO (solo bloques) en", OUT)
        return

    pipe = sd.load_pipeline("fp8", controlled="img2img")
    for what in args.what:
        init, control = blocks[what]
        colors = style.colors_for("chassis", ELEMENT[what])
        prompt = style.prompt(SUBJECTS[what], colors)
        tokens = len(pipe.tokenizer(prompt).input_ids)
        if tokens > 77:
            raise SystemExit("prompt de %d tokens (> 77): se perderia el final" % tokens)
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
            name = "%s_%d.png" % (what, seed)
            image.save(OUT / name)
            print("ok  %s  %.0f s  pico VRAM %.1f GB" % (name, time.time() - started, sd.peak_vram_gb()), flush=True)
    print("LISTO en", OUT)


if __name__ == "__main__":
    main()
