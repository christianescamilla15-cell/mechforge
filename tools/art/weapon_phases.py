"""Las fases del dibujo de un arma (OBS-047), como las del torso.

Del usuario (2026-11-21), tras elegir las del torso: "ahora vamos a poner al
mismo nivel las armas". Cada tipo de arma vive en unas fases (sus clases,
ItemScaling.phase): balas 0-3, canon 2-5, blaster 2-7 y laser 4-10; con la
evolucion (balas -> canon -> blaster -> laser) un arma recorre las once.
El dibujo de siempre (tools/art/weapons_test.py, tanda armas4) es la primera
fase de su tipo; cada fase siguiente parte de la anterior y repinta la
silueta del arma, algo ampliada para que le crezcan piezas, sin tocar su
union con el robot. Las ultimas fases, al estilo de los torsos: dios robot
del anime, oro y blanco, con mas detalle (pasada final suave).

Las imagenes van a art_raw/parts/<tanda>/<pieza>_f<NN>_<semilla>.png.
Uso:
  tools/art/run.ps1 tools/art/weapon_phases.py arm_medio_laser arm_largo_laser --batch fases_armas
  tools/art/run.ps1 -KeepWatcher tools/art/weapon_phases.py arm_medio_laser --batch fases_armas
      --export arm_medio_laser=101
"""

import argparse
import json
import shutil
import time

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import cutout
import export_weapons
import gpu_turn
import style
import weapons_test as wt

OUT = wt.OUT
SOURCE = "armas4"
# Fases de cada tipo: (la de su dibujo de siempre, la ultima).
TYPE_PHASES = {"balas": (0, 3), "canon": (2, 5), "blaster": (2, 7), "laser": (4, 10)}
# Lo que se suma en cada fase, de la 1 a la 10 (la misma escalera que los
# torsos, en version arma).
PHASES = [
    "reinforced plating, extra vents, bolts",
    "glowing energy conduits, cooling fins, cables",
    "heavy armor plating, gold trim, glowing core",
    "sharp armor fins, glowing lines, power cells",
    "energy crystals, glowing coils, layered armor",
    "floating armor plates, radiant core, light trails",
    "ornate white and gold armor, glowing runes",
    "anime god weapon, ornate gold armor, star core, halo ring",
    "celestial weapon, gold filigree, intricate details",
    "divine weapon, golden halo ring, ornate gold filigree",
]
# Cuanto se amplia la silueta que se repinta (pixeles del lienzo, mas en
# las fases altas: halos y aletas necesitan sitio) y el radio de la union
# con el robot que no se toca (unidades del bloque).
GROW = 20
GROW_PER_PHASE = 6
KEEP_UNION = 60
# Los rifles de hombro llevan el mismo dibujo que los de brazo, mas arriba
# (OBS-033): se exportan copiando las fases del de brazo.
SHOULDER_COPY = {"arm_largo_": "shoulder_largo_"}


def kind_of(name):
    return name.rsplit("_", 1)[1]


def subject_options(name):
    """Sujetos del arma, del completo al mas corto (el prompt cabe en 77)."""
    full = wt.DESIGNS[name]["subject"]
    short = wt.TYPE_TAGS.get(kind_of(name), "").split(",")[0]
    base = "mechanical arm" if name.startswith("arm_") else "shoulder cannon, turret"
    return [full, "%s, %s, %s" % (base, short, wt.VIEW), "%s, %s" % (short, wt.VIEW)]


def negative(tags):
    """Lo del arma primero (CLIP corta en 77) y sin lo que la fase pide."""
    wanted = [word.strip() for word in tags.split(",")]
    kept = []
    for word in (wt.NEGATIVE + ", " + style.NEGATIVE).split(","):
        word = word.strip()
        if word and word not in kept and not any(word in want for want in wanted):
            kept.append(word)
    return ", ".join(kept)


def repaint_mask(image, name, phase, grow_base=GROW, grow_step=GROW_PER_PHASE):
    """La silueta del arma ampliada, sin la union con el robot."""
    figure = Image.fromarray((cutout.clean_figure(image) * 255).astype(np.uint8))
    # Dilatar con desenfoque y umbral: lo mismo que un filtro de maximo, rapido.
    grow = grow_base + grow_step * phase
    mask = figure.filter(ImageFilter.GaussianBlur(grow / 2.0)).point(lambda v: 255 if v > 6 else 0)
    zoom, origin = wt.placement(name)
    radius = KEEP_UNION * zoom
    ImageDraw.Draw(mask).ellipse((origin[0] - radius, origin[1] - radius, origin[0] + radius, origin[1] + radius), fill=0)
    return mask


def prompts_for(name, pipe, colors):
    """(fase, prompt, negativo) de cada fase que se pinta."""
    low, high = TYPE_PHASES[kind_of(name)]
    plan = []
    for phase in range(low + 1, high + 1):
        tags = PHASES[phase - 1]
        chosen = None
        for subject in subject_options(name):
            prompt = style.prompt(subject + ", " + tags, colors)
            if len(pipe.tokenizer(prompt).input_ids) <= 77:
                chosen = prompt
                break
        if chosen is None:
            raise SystemExit("sin prompt de 77 tokens para %s fase %d" % (name, phase))
        plan.append((phase, chosen, negative(tags)))
    return plan


def generate(args):
    import torch

    import sd

    # Cede la tarjeta si empieza una junta en vivo (gpu_turn).
    turn = gpu_turn.Turn(lambda: sd.load_pipeline("fp8", controlled="inpaint"))
    colors = style.colors_for("chassis", "physical")
    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    refine_tags = args.refine_tags
    for name in args.names:
        low, _ = TYPE_PHASES[kind_of(name)]
        start = Image.open(OUT / SOURCE / ("%s_%d.png" % (name, export_weapons.CHOSEN[name]))).convert("RGB")
        _, control = wt.render(name)
        plan = prompts_for(name, turn.pipe(), colors)
        refine_prompt = style.prompt(subject_options(name)[1] + ", " + refine_tags, colors)
        for seed in args.seeds:
            current = start
            current.save(out / ("%s_f%02d_%d.png" % (name, low, seed)))
            for phase, prompt, neg in plan:
                started = time.time()
                strength = args.strength + (args.strength_end - args.strength) * (phase - 1) / 9.0
                passes = [(prompt, strength, seed + phase)]
                if args.refine > 0 and phase >= args.refine_from:
                    passes.append((refine_prompt, args.refine, seed + phase + 1000))
                for text, power, noise in passes:
                    mask = repaint_mask(current, name, phase, args.grow, args.grow_step)
                    image = turn.run(
                        noise,
                        prompt=text,
                        negative_prompt=neg,
                        image=current,
                        mask_image=mask,
                        strength=power,
                        control_image=[control],
                        control_mode=[sd.MODE_SCRIBBLE],
                        controlnet_conditioning_scale=args.control,
                        control_guidance_end=0.4,
                        num_inference_steps=args.steps,
                        guidance_scale=style.CFG,
                        width=current.width,
                        height=current.height,
                    ).images[0]
                    current = Image.composite(image, current, mask.filter(ImageFilter.GaussianBlur(4)))
                file_name = "%s_f%02d_%d.png" % (name, phase, seed)
                current.save(out / file_name)
                print("ok  %s  fuerza %.2f  %.0f s" % (file_name, strength, time.time() - started), flush=True)
    print("LISTO en", out)


def export(args):
    """Exporta las fases de la semilla elegida como <pieza>_f<N> en el juego."""
    path = export_weapons.SET.with_suffix(".json")
    anchors = json.loads(path.read_text(encoding="utf-8"))
    for pick in args.export:
        name, seed = pick.split("=")
        low, high = TYPE_PHASES[kind_of(name)]
        for phase in range(low + 1, high + 1):
            source = OUT / args.batch / ("%s_f%02d_%s.png" % (name, phase, seed))
            if not source.exists():
                continue
            key = "%s_f%d" % (name, phase)
            anchors[key], _ = export_weapons.export(key, source, placement=wt.placement(name))
            print("exportada %s: %s" % (key, json.dumps(anchors[key])))
            for arm, shoulder in SHOULDER_COPY.items():
                if not name.startswith(arm):
                    continue
                twin = shoulder + name[len(arm) :]
                lift = [anchors[twin]["hip"][i] - anchors[name]["hip"][i] for i in (0, 1)]
                twin_key = "%s_f%d" % (twin, phase)
                for element in ("PHYSICAL", "HEAT", "ENERGY"):
                    shutil.copyfile(
                        "%s_%s_%s.png" % (export_weapons.SET, key, element),
                        "%s_%s_%s.png" % (export_weapons.SET, twin_key, element),
                    )
                anchors[twin_key] = dict(anchors[key])
                anchors[twin_key]["hip"] = [anchors[key]["hip"][i] + lift[i] for i in (0, 1)]
                print("copiada %s: %s" % (twin_key, json.dumps(anchors[twin_key])))
    path.write_text(json.dumps(anchors, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("names", nargs="+", choices=sorted(export_weapons.CHOSEN))
    parser.add_argument("--batch", required=True)
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102, 103])
    parser.add_argument("--strength", type=float, default=0.6)
    parser.add_argument("--strength-end", type=float, default=0.85)
    parser.add_argument("--control", type=float, default=0.25, help="cuanto manda el bloque del arma")
    parser.add_argument("--steps", type=int, default=style.STEPS)
    parser.add_argument("--refine", type=float, default=0.35, help="pasada de detalle (0 = sin ella)")
    parser.add_argument("--refine-from", type=int, default=7)
    # Piloto 2 (2026-11-23): con el control a 0.25 y fuerza 0.6-0.85 el arma
    # casi no cambiaba de fase en fase; los torsos, que si evolucionaron,
    # iban con el control a 0 y fuerza 0.7-0.92.
    parser.add_argument("--grow", type=int, default=GROW, help="pixeles que crece la silueta")
    parser.add_argument("--grow-step", type=int, default=GROW_PER_PHASE, help="y cuanto mas por fase")
    parser.add_argument("--refine-tags", default="intricate details, ornate engravings, detailed mechanical parts")
    parser.add_argument("--export", nargs="+", default=None, metavar="PIEZA=SEMILLA")
    args = parser.parse_args()
    if args.export:
        export(args)
    else:
        generate(args)


if __name__ == "__main__":
    main()
