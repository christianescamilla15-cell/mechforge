"""Evolucion del dibujo de un arma, por clase y por etapa (GDD 8).

Pedido del usuario el 2026-11-20: al subir de nivel una pieza se tiene que
notar en su dibujo, sin cambiar su estructura ("simplemente los
perifericos"); al pasar de clase, tras un jefe, evoluciona la estructura.
Es lo que hacia el original en su version antigua (docs/reference/
original-mechanics.md): cada arma era una familia Mark I, II y III sobre el
mismo modelo, y el modelo siguiente era otro dibujo.

Aqui cada arma tiene, por cada clase en la que existe, un modelo con tres
etapas: a (la base), b y c. Los pasos se llaman c<clase><etapa>:
  c0a  el dibujo que ya tiene el arma (tools/art/weapons_test.py).
  c0b  c0a con perifericos anadidos. Se repinta SOLO donde van (inpaint):
       el resto del dibujo no cambia ni un pixel.
  c0c  c0b con mas perifericos.
  c1a  el modelo de la clase siguiente: otra estructura, de su propio bloque.
  c1b, c1c  sus etapas.
Cada paso parte del anterior, asi que hay que elegir semilla antes de seguir
(--chosen). Las imagenes van a art_raw/parts/<tanda>/<diseno>_<paso>_<semilla>.png.

Uso:
  tools/art/run.ps1 -KeepWatcher tools/art/evolve_weapons.py --batch evo1 --blocks-only
  tools/art/run.ps1 tools/art/evolve_weapons.py --batch evo1 --steps c0b c1a
  tools/art/run.ps1 tools/art/evolve_weapons.py --batch evo1 --steps c0c c1b --chosen c0b=102 c1a=101
  tools/art/run.ps1 -KeepWatcher tools/art/evolve_weapons.py --batch evo1 --export --chosen c0b=102 ...

Al exportar, cada pasada se reparte en pasos de aspecto, uno por
periferico (seis por clase, MechSprites.LOOK_STEPS): el paso n es la base
con los n primeros perifericos tal como quedaron en el dibujo final. Asi
cada nivel de la primera clase anade algo sin pintar seis veces.
"""

import argparse
import json
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

import style
import weapons_test as wt

OUT = wt.OUT
# Lo que se agranda la zona que se repinta alrededor de cada periferico, en
# pixeles, y lo que se difumina su borde al pegarla sobre la base.
MASK_GROW = 13
MASK_BLUR = 4


def rect(x0, y0, x1, y1):
    return wt.rect(x0, y0, x1, y1)


# --- La hoja de balas (Cuchilla vibratoria) -----------------------------------
# Los perifericos de cada modelo van en el orden en que se suman, uno por
# paso de aspecto (MechSprites.LOOK_STEPS): ("b" o "c", piezas). La letra es
# la pasada en la que se pintan: los tres primeros en la b y los otros tres
# en la c, sobre la b.


def _blade_c0():
    return [
        # 1. El filo vibratorio se enciende bajo la hoja.
        ("b", [("accent", [(322, 40), (700, 26), (852, 3), (704, 37), (322, 54)])]),
        # 2. Dientes en el lomo.
        (
            "b",
            [
                ("armor", [(346, -64), (372, -98), (400, -63)]),
                ("armor", [(446, -61), (472, -95), (500, -60)]),
                ("armor", [(546, -58), (572, -92), (600, -57)]),
            ],
        ),
        # 3. El generador del filo, junto a la raiz de la hoja.
        ("b", [("frame", [(304, 56), (404, 50), (396, 92), (310, 96)]), ("accent", rect(326, 64, 380, 78))]),
        # 4. Celula de energia sobre el cuerpo, con su tubo hasta la hoja.
        (
            "c",
            [
                ("armor2", [(128, -152), (246, -160), (262, -124), (122, -116)]),
                ("accent", [(150, -146), (228, -151), (236, -131), (148, -127)]),
                ("frame", [(250, -140), (312, -112), (322, -84), (300, -80), (292, -100), (244, -122)]),
            ],
        ),
        # 5. Aletas de refrigeracion bajo el generador.
        (
            "c",
            [
                ("armor2", [(318, 98), (334, 132), (348, 132), (340, 96)]),
                ("armor2", [(352, 96), (368, 130), (382, 130), (374, 94)]),
            ],
        ),
        # 6. Sensor sobre la hombrera, apoyado en ella (suelto, el recorte
        #    lo descartaba al exportar).
        (
            "d",
            [
                ("frame", [(-70, -98), (-58, -152), (-18, -158), (-8, -108)]),
                ("accent", [(-52, -144), (-24, -148), (-20, -126), (-50, -122)]),
            ],
        ),
    ]


def _blade_c1():
    """Modelo de la clase siguiente: hoja doble mas ancha con un canal de
    energia por el centro y una guarda grande. La misma union con el robot."""
    return [
        ("armor", [(290, -74), (650, -64), (872, -4), (650, 40), (290, 54)]),
        ("armor2", [(300, 18), (650, 12), (872, -4), (650, 40), (290, 54)]),
        ("accent", [(330, -16), (700, -12), (812, -5), (700, 2), (330, 6)]),
        ("armor", [(330, -118), (610, -104), (748, -66), (612, -78), (330, -88)]),
        ("frame", [(330, -90), (612, -80), (640, -66), (330, -74)]),
        ("frame", [(262, -128), (336, -134), (352, 72), (262, 78)]),
        ("armor2", rect(282, -96, 320, 40)),
    ] + wt.arm_base(300)


def _blade_c1_extras():
    return [
        # 1. Filo encendido en la hoja de abajo.
        ("b", [("accent", [(340, 44), (650, 30), (850, -2), (654, 42), (340, 58)])]),
        # 2. Filo encendido en la hoja de arriba.
        ("b", [("accent", [(350, -124), (606, -110), (736, -72), (610, -114), (350, -132)])]),
        # 3. Generador bajo la guarda.
        ("b", [("frame", [(300, 82), (410, 74), (400, 122), (308, 126)]), ("accent", rect(324, 90, 384, 106))]),
        # 4. Celula de energia con su conexion a la guarda.
        (
            "c",
            [
                ("armor2", [(120, -156), (250, -166), (266, -128), (114, -120)]),
                ("accent", [(142, -150), (232, -157), (240, -135), (140, -129)]),
                ("frame", [(254, -146), (300, -150), (306, -128), (258, -126)]),
            ],
        ),
        # 5. Aletas de refrigeracion tras el generador.
        (
            "c",
            [
                ("armor2", [(412, 78), (430, 116), (446, 116), (436, 76)]),
                ("armor2", [(450, 76), (468, 114), (484, 114), (474, 74)]),
            ],
        ),
        # 6. Segunda celula, apoyada en la hombrera.
        (
            "d",
            [
                ("armor2", [(-74, -98), (-62, -150), (-6, -158), (4, -110)]),
                ("accent", [(-54, -142), (-16, -148), (-12, -124), (-52, -120)]),
            ],
        ),
    ]


BLADE_SUBJECT = "mechanical arm, armor, machinery, arm blade, huge sword, serrated blade"
# Un arma: por cada clase, de que diseno sale su modelo (o su bloque), lo
# que pide su dibujo, sus perifericos y lo que se anade al prompt en cada
# pasada.
WEAPONS = {
    "arm_hoja_balas": [
        {
            "design": "arm_hoja_balas",
            "subject": BLADE_SUBJECT,
            "extras": _blade_c0,
            "tags": {
                "b": "glowing edge, vents",
                "c": "glowing edge, vents, cables, energy core",
                "d": "glowing edge, sensor, glowing screen",
            },
        },
        {
            "build": _blade_c1,
            "subject": "mechanical arm, armor, machinery, arm blade, twin blades, glowing line",
            "extras": _blade_c1_extras,
            "tags": {
                "b": "glowing edge, vents",
                "c": "glowing edge, vents, cables, energy core",
                "d": "glowing edge, energy core",
            },
            # En la pasada d se repinta ademas el filo de abajo, que en la b
            # quedo casi apagado.
            "retouch": {"d": [("accent", [(330, 38), (650, 24), (856, -4), (660, 44), (330, 60)])]},
        },
    ],
}


def pass_parts(weapon, tier, stage):
    """Piezas que se pintan en una pasada ("b" o "c"), todas juntas."""
    return [part for letter, parts in WEAPONS[weapon][tier]["extras"]() if letter == stage for part in parts]


def step_name(weapon, step):
    return "%s_%s" % (weapon, step)


def class_parts(weapon, tier):
    """Bloque del modelo de una clase y su colocacion en el lienzo."""
    entry = WEAPONS[weapon][tier]
    if "design" in entry:
        parts = wt.DESIGNS[entry["design"]]["build"]()
    else:
        parts = entry["build"]()
    zoom, origin = wt.placement_of(parts, wt.ARM_CANVAS)
    return parts, zoom, origin


def parse_step(step):
    """'c1b' -> (1, 'b')."""
    return int(step[1:-1]), step[-1]


PASSES = "bcd"


def previous_step(step):
    tier, stage = parse_step(step)
    return None if stage == "a" else "c%d%s" % (tier, "abc"[PASSES.index(stage)])


def stage_layers(weapon, step):
    """Lo que hace falta para pintar una etapa b o c: los perifericos nuevos,
    el control (el bloque del modelo con todos los perifericos hasta esa
    etapa) y la zona que se repinta."""
    tier, stage = parse_step(step)
    base_parts, zoom, origin = class_parts(weapon, tier)
    earlier = [part for letter in PASSES[: PASSES.index(stage)] for part in pass_parts(weapon, tier, letter)]
    new = pass_parts(weapon, tier, stage) + WEAPONS[weapon][tier].get("retouch", {}).get(stage, [])
    _, control = wt.render_parts(base_parts + earlier + new, wt.ARM_CANVAS, zoom, origin)
    mask = Image.new("L", wt.ARM_CANVAS, 0)
    draw = ImageDraw.Draw(mask)
    for _, polygon in new:
        draw.polygon([(origin[0] + zoom * x, origin[1] + zoom * y) for x, y in polygon], fill=255)
    mask = mask.filter(ImageFilter.MaxFilter(2 * MASK_GROW + 1))
    return new, control, mask, zoom, origin


def paint_new(parent, new, zoom, origin):
    """El dibujo anterior con los perifericos nuevos pintados como bloque:
    de ahi parte el repintado."""
    start = parent.copy()
    wt.render_parts(new, wt.ARM_CANVAS, zoom, origin, init=start, control=Image.new("RGB", wt.ARM_CANVAS))
    return start


def source_of(weapon, step, batch, chosen):
    """Imagen elegida de un paso (la base c0a es la del arma tal como esta)."""
    if step == "c0a" and "design" in WEAPONS[weapon][0]:
        import export_weapons

        design = WEAPONS[weapon][0]["design"]
        return OUT / "armas4" / ("%s_%d.png" % (design, export_weapons.CHOSEN[design]))
    if step not in chosen:
        raise SystemExit("falta elegir la semilla de %s (--chosen %s=<semilla>)" % (step, step))
    return OUT / batch / ("%s_%d.png" % (step_name(weapon, step), chosen[step]))


def subject_of(weapon, step):
    tier, stage = parse_step(step)
    entry = WEAPONS[weapon][tier]
    subject = entry["subject"]
    if stage != "a":
        subject += ", " + entry["tags"][stage]
    return subject + ", " + wt.VIEW


def save_blocks(weapon, out):
    """Guarda, sin GPU, el bloque de cada paso para revisarlo antes."""
    for tier in range(len(WEAPONS[weapon])):
        parts, zoom, origin = class_parts(weapon, tier)
        shown = list(parts)
        init, _ = wt.render_parts(shown, wt.ARM_CANVAS, zoom, origin)
        init.save(out / ("_bloque_%s.png" % step_name(weapon, "c%da" % tier)))
        for stage in PASSES:
            shown = shown + pass_parts(weapon, tier, stage)
            init, _ = wt.render_parts(shown, wt.ARM_CANVAS, zoom, origin)
            init.save(out / ("_bloque_%s.png" % step_name(weapon, "c%d%s" % (tier, stage))))


def look_masks(weapon, tier):
    """Zona del lienzo de cada periferico, en el orden en que se suman."""
    _, zoom, origin = class_parts(weapon, tier)
    masks = []
    for _, parts in WEAPONS[weapon][tier]["extras"]():
        mask = Image.new("L", wt.ARM_CANVAS, 0)
        draw = ImageDraw.Draw(mask)
        for _, polygon in parts:
            draw.polygon([(origin[0] + zoom * x, origin[1] + zoom * y) for x, y in polygon], fill=255)
        masks.append(mask.filter(ImageFilter.MaxFilter(2 * MASK_GROW + 1)))
    return masks


def look_image(base, final, masks, count):
    """El modelo con sus `count` primeros perifericos: dentro de sus zonas,
    los pixeles del dibujo final; en lo demas (y donde iran los que aun no
    tiene), los de la base."""
    if count >= len(masks):
        return final
    shown = Image.new("L", base.size, 0)
    for mask in masks[:count]:
        shown = ImageChops.lighter(shown, mask)
    for mask in masks[count:]:
        shown = ImageChops.subtract(shown, mask)
    return Image.composite(final, base, shown.filter(ImageFilter.GaussianBlur(MASK_BLUR)))


def export(weapon, batch, chosen):
    """Lleva al juego los pasos de aspecto de cada clase que tenga sus
    pasadas elegidas: assets/mechs/armas_ligero_<arma>_c<clase>_<paso>_<ELEMENTO>.png
    y sus anclas. El paso 0 de la primera clase es el arma tal como ya esta.
    Con solo la pasada b elegida salen los tres primeros pasos."""
    import export_weapons

    anchors_path = export_weapons.SET.with_suffix(".json")
    anchors = json.loads(anchors_path.read_text(encoding="utf-8"))
    out = OUT / batch
    for tier in range(len(WEAPONS[weapon])):
        _, zoom, origin = class_parts(weapon, tier)
        base_step = "c%da" % tier
        if tier > 0 and base_step not in chosen:
            continue
        base_path = source_of(weapon, base_step, batch, chosen)
        base = Image.open(base_path).convert("RGB")
        masks = look_masks(weapon, tier)
        done = [letter for letter in PASSES if "c%d%s" % (tier, letter) in chosen]
        last = done[-1] if done else ""
        letters = [letter for letter, _ in WEAPONS[weapon][tier]["extras"]()]
        steps = len([letter for letter in letters if last and PASSES.index(letter) <= PASSES.index(last)])
        final = base
        if last:
            final = Image.open(source_of(weapon, "c%d%s" % (tier, last), batch, chosen)).convert("RGB")
        for count in range(0 if tier > 0 else 1, steps + 1):
            name = "%s_c%d_%d" % (weapon, tier, count)
            source = base_path
            if count > 0:
                source = out / ("_paso_%s.png" % name)
                look_image(base, final, masks, count).save(source)
            # Los perifericos que lleva se conservan aunque queden sueltos.
            keep = None
            if count > 0:
                zone = Image.new("L", wt.ARM_CANVAS, 0)
                for mask in masks[:count]:
                    zone = ImageChops.lighter(zone, mask)
                keep = np.asarray(zone) > 0
            anchors[name], _ = export_weapons.export(name, source, placement=(zoom, origin), keep=keep)
            print("exportada %s: %s" % (name, json.dumps(anchors[name])))
    anchors_path.write_text(json.dumps(anchors, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--weapon", default="arm_hoja_balas", choices=sorted(WEAPONS))
    parser.add_argument("--steps", nargs="+", default=[])
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102, 103])
    parser.add_argument("--chosen", nargs="*", default=[], help="semilla elegida de cada paso: c0b=102 c1a=101")
    parser.add_argument("--strength", type=float, default=0.88, help="cuanto se repinta la zona de los perifericos")
    parser.add_argument("--control-scale", type=float, default=0.85, help="fuerza del control en los perifericos")
    parser.add_argument("--control-end", type=float, default=0.75)
    parser.add_argument("--tag", default="", help="se anade al nombre de las imagenes")
    parser.add_argument("--blocks-only", action="store_true", help="solo guarda los bloques, sin GPU")
    parser.add_argument("--export", action="store_true", help="lleva al juego las etapas elegidas, sin GPU")
    args = parser.parse_args()

    chosen = {item.split("=")[0]: int(item.split("=")[1]) for item in args.chosen}
    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    save_blocks(args.weapon, out)
    if args.blocks_only:
        print("LISTO (solo bloques) en", out)
        return
    if args.export:
        export(args.weapon, args.batch, chosen)
        return

    import torch

    import sd

    colors = style.colors_for("chassis", "physical")
    negative = style.NEGATIVE + ", " + wt.NEGATIVE
    # Un modelo nuevo ("a") se pinta entero desde su bloque, como cualquier
    # arma (weapons_test.py): con el repintado a lienzo completo el modelo no
    # sigue el bloque. Los perifericos ("b" y "c") se repintan por zonas.
    for kind in ("img2img", "inpaint"):
        steps = [step for step in args.steps if (parse_step(step)[1] == "a") == (kind == "img2img")]
        if not steps:
            continue
        pipe = sd.load_pipeline("fp8", controlled=kind)
        for step in steps:
            for text in (style.prompt(subject_of(args.weapon, step), colors), negative):
                tokens = len(pipe.tokenizer(text).input_ids)
                if tokens > 77:
                    raise SystemExit("prompt de %d tokens (maximo 77) en %s: %s" % (tokens, step, text))
        for step in steps:
            tier, stage = parse_step(step)
            prompt = style.prompt(subject_of(args.weapon, step), colors)
            extra = {}
            if stage == "a":
                parts, zoom, origin = class_parts(args.weapon, tier)
                start, control = wt.render_parts(parts, wt.ARM_CANVAS, zoom, origin)
                parent = None
                strength, scale, end = 1.0, 0.65, 0.5
            else:
                parent = Image.open(source_of(args.weapon, previous_step(step), args.batch, chosen)).convert("RGB")
                new, control, mask, zoom, origin = stage_layers(args.weapon, step)
                start = paint_new(parent, new, zoom, origin)
                soft = mask.filter(ImageFilter.GaussianBlur(MASK_BLUR))
                extra = {"mask_image": mask}
                strength, scale, end = args.strength, args.control_scale, args.control_end
            for seed in args.seeds:
                started = time.time()
                image = pipe(
                    prompt=prompt,
                    negative_prompt=negative,
                    image=start,
                    strength=strength,
                    control_image=[control],
                    control_mode=[sd.MODE_SCRIBBLE],
                    controlnet_conditioning_scale=scale,
                    control_guidance_end=end,
                    num_inference_steps=style.STEPS,
                    guidance_scale=style.CFG,
                    width=wt.ARM_CANVAS[0],
                    height=wt.ARM_CANVAS[1],
                    generator=torch.Generator("cpu").manual_seed(seed),
                    **extra,
                ).images[0]
                share = 100.0
                if parent is not None:
                    # Fuera de los perifericos se conservan los pixeles de la base.
                    image = Image.composite(image, parent, soft)
                    changed = ImageChops.difference(image, parent).convert("L").point(lambda v: 255 if v > 8 else 0)
                    share = 100.0 * sum(changed.histogram()[255:]) / (image.width * image.height)
                file_name = "%s_%d%s.png" % (step_name(args.weapon, step), seed, args.tag)
                image.save(out / file_name)
                print(
                    "ok  %s  %.0f s  cambia el %.1f %% del dibujo  pico VRAM %.1f GB"
                    % (file_name, time.time() - started, share, sd.peak_vram_gb()),
                    flush=True,
                )
        del pipe
        torch.cuda.empty_cache()
    print("LISTO en", out)


if __name__ == "__main__":
    main()
