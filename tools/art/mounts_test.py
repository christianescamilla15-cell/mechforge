"""Armas y piernas especiales dibujadas ya montadas sobre el robot base.

Sigue la receta del canon de pecho (docs/CHASIS.md, seccion 6): el modelo
vuelve a dibujar solo la envolvente de la pieza, con su silueta como control,
y el resto del robot queda intacto. Despues tools/art/extract_overlay.py la
recorta por diferencia con la base.

Disenos (la silueta y el sujeto de cada uno estan en DESIGNS); el nombre
de la pieza en el juego es el del diseno con brazo -> arm y hombro -> shoulder:
  brazo_corto, brazo_medio, brazo_largo, brazo_hoja, brazo_saboteador
  hombro_bateria, hombro_artilleria, hombro_ancla
  piernas_orugas, piernas_ruedas, piernas_ruedas_cuna, piernas_levita
  dron_artillero, dron_zapador (flotando detras del casco; en el juego, drone_*)
  asistente_0 .. asistente_5: las seis formas del robot de asistencia (Sonda,
    Vigia, Centinela, Custodio, Guardian y Arconte), cada una mas grande y con
    mas piezas, con torreta arriba y capsula abajo para sus dos armas. Se
    dibujan con la base movida ASSIST_SHIFT (abajo, derecha) para que quepan.
Las de hombro no caben sobre el casco del robot base: se dibujan con la base
bajada SHOULDER_SHIFT pixeles (la cintura baja lo mismo).

Las imagenes van a art_raw/parts/<tanda>/<diseno>_<semilla>.png.
Uso:
  tools/art/run.ps1 tools/art/mounts_test.py docs/reference/art/elegidos/ligero/robot_18.png \
      --batch montadas --hip 530 493 --seeds 1 2 3 4
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
WHITE = (255, 255, 255)
WIDTH = blockout.LINE_WIDTH

ARM_ZONE = (-185, -55, -125, 485)
ARM_ZONE_LONG = (-215, -55, -125, 528)
SHOULDER_SHIFT = 170
SHOULDER_ZONE = (-590, -368, -300, 300)
LEGS_ZONE = (22, 440, -300, 330)
DRONE_ZONE = (-515, -322, -490, -250)
# (abajo, derecha): el robot base se aparta para dejar sitio a las formas.
ASSIST_SHIFT = (230, 330)


def _arm_base(draw, r, x):
    """Union redonda en el costado del torso y cuerpo del arma hacia delante."""
    draw.ellipse([x - 100, r - 170, x - 20, r - 90], outline=WHITE, width=WIDTH)
    draw.rounded_rectangle([x - 40, r - 165, x + 170, r - 95], radius=16, outline=WHITE, width=WIDTH)


def control_arm_gun(draw, r, x):
    _arm_base(draw, r, x)
    draw.rectangle([x + 170, r - 150, x + 360, r - 118], outline=WHITE, width=WIDTH)
    draw.rectangle([x + 340, r - 158, x + 385, r - 110], outline=WHITE, width=WIDTH)
    draw.rectangle([x + 60, r - 190, x + 140, r - 165], outline=WHITE, width=WIDTH)


def control_arm_blade(draw, r, x):
    _arm_base(draw, r, x)
    draw.polygon([(x + 170, r - 150), (x + 470, r - 128), (x + 170, r - 108)], outline=WHITE, width=WIDTH)
    draw.rectangle([x + 150, r - 172, x + 180, r - 88], outline=WHITE, width=WIDTH)


def control_arm_short(draw, r, x):
    _arm_base(draw, r, x)
    draw.rectangle([x + 170, r - 160, x + 290, r - 100], outline=WHITE, width=WIDTH)
    draw.polygon(
        [(x + 290, r - 165), (x + 335, r - 178), (x + 335, r - 82), (x + 290, r - 95)], outline=WHITE, width=WIDTH
    )


def control_arm_long(draw, r, x):
    _arm_base(draw, r, x)
    draw.rectangle([x + 170, r - 143, x + 480, r - 123], outline=WHITE, width=WIDTH)
    draw.rectangle([x + 470, r - 152, x + 515, r - 114], outline=WHITE, width=WIDTH)
    draw.rounded_rectangle([x + 30, r - 205, x + 160, r - 168], radius=10, outline=WHITE, width=WIDTH)


def control_arm_siphon(draw, r, x):
    _arm_base(draw, r, x)
    draw.rectangle([x + 170, r - 150, x + 240, r - 110], outline=WHITE, width=WIDTH)
    draw.ellipse([x + 240, r - 190, x + 300, r - 70], outline=WHITE, width=WIDTH)
    for tip in (r - 175, r - 130, r - 85):
        draw.line([(x + 285, tip), (x + 370, tip + (r - 130 - tip) // 3)], fill=WHITE, width=WIDTH)


def _shoulder_mount(draw, r, x):
    draw.rectangle([x - 170, r - 405, x - 80, r - 372], outline=WHITE, width=WIDTH)


def control_shoulder_pod(draw, r, x):
    _shoulder_mount(draw, r, x)
    draw.rounded_rectangle([x - 260, r - 545, x + 50, r - 405], radius=14, outline=WHITE, width=WIDTH)
    for cy in (r - 510, r - 440):
        for cx in (x - 5, x + 30):
            draw.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], outline=WHITE, width=WIDTH)


def control_shoulder_artillery(draw, r, x):
    _shoulder_mount(draw, r, x)
    draw.rounded_rectangle([x - 250, r - 490, x - 40, r - 405], radius=12, outline=WHITE, width=WIDTH)
    draw.polygon(
        [(x - 90, r - 485), (x + 240, r - 575), (x + 252, r - 538), (x - 70, r - 450)], outline=WHITE, width=WIDTH
    )


def control_shoulder_harpoon(draw, r, x):
    _shoulder_mount(draw, r, x)
    draw.rounded_rectangle([x - 240, r - 480, x - 30, r - 405], radius=12, outline=WHITE, width=WIDTH)
    draw.rectangle([x - 30, r - 462, x + 170, r - 428], outline=WHITE, width=WIDTH)
    draw.polygon([(x + 170, r - 480), (x + 250, r - 445), (x + 170, r - 410)], outline=WHITE, width=WIDTH)


def control_tracks(draw, r, x):
    draw.rectangle([x - 90, r + 30, x + 90, r + 300], outline=WHITE, width=WIDTH)
    draw.rounded_rectangle([x - 200, r + 300, x + 220, r + 400], radius=50, outline=WHITE, width=WIDTH)
    for cx in (x - 135, x - 45, x + 45, x + 135):
        draw.ellipse([cx - 34, r + 316, cx + 34, r + 384], outline=WHITE, width=WIDTH)


def control_wheels(draw, r, x):
    draw.rectangle([x - 70, r + 30, x + 70, r + 230], outline=WHITE, width=WIDTH)
    draw.rounded_rectangle([x - 170, r + 225, x + 190, r + 285], radius=20, outline=WHITE, width=WIDTH)
    for cx in (x - 110, x + 130):
        draw.ellipse([cx - 75, r + 250, cx + 75, r + 400], outline=WHITE, width=WIDTH)
        draw.ellipse([cx - 25, r + 300, cx + 25, r + 350], outline=WHITE, width=WIDTH)


def control_wheel_wedge(draw, r, x):
    """Base de ruedas en cuna, baja y larga: bajo la cadera, dos orugas
    blindadas en cuna (alta por detras, baja por delante), la de un lado
    asomando tras la otra, con sus ruedas en fila. Es la forma de la base con
    ruedas del juego original de 2012-2014, que el usuario pidio como modelo;
    el dibujo es nuestro."""
    floor = r + 400
    draw.polygon(
        [(x - 70, r + 30), (x + 70, r + 30), (x + 85, r + 100), (x - 85, r + 100)], outline=WHITE, width=WIDTH
    )
    # La oruga del otro lado: solo lo que asoma por detras y por arriba.
    draw.line(
        [(x - 285, floor - 38), (x - 265, floor - 293), (x - 90, floor - 323), (x + 235, floor - 123)],
        fill=WHITE,
        width=WIDTH,
    )
    # La de este lado: la cuna, su banda de rodadura y las ruedas.
    draw.polygon(
        [
            (x - 215, floor - 255),
            (x - 40, floor - 285),
            (x + 285, floor - 85),
            (x + 285, floor),
            (x - 235, floor),
        ],
        outline=WHITE,
        width=WIDTH,
    )
    draw.line([(x - 232, floor - 72), (x + 285, floor - 72)], fill=WHITE, width=WIDTH)
    for cx in (-190, -85, 20, 125, 230):
        draw.ellipse([x + cx - 30, floor - 66, x + cx + 30, floor - 6], outline=WHITE, width=WIDTH)


def control_hover(draw, r, x):
    draw.polygon(
        [(x - 110, r + 30), (x + 110, r + 30), (x + 160, r + 240), (x - 160, r + 240)], outline=WHITE, width=WIDTH
    )
    for cx in (x - 85, x + 85):
        draw.rounded_rectangle([cx - 50, r + 240, cx + 50, r + 300], radius=14, outline=WHITE, width=WIDTH)


def _drone_body(draw, r, x):
    draw.ellipse([x - 450, r - 490, x - 275, r - 390], outline=WHITE, width=WIDTH)
    draw.rectangle([x - 395, r - 390, x - 335, r - 366], outline=WHITE, width=WIDTH)


def block_drone(draw, r, x):
    """Bloque blanco del dron sobre la base: en una zona de fondo liso el
    modelo no dibuja nada si no tiene de donde partir."""
    draw.ellipse([x - 450, r - 490, x - 275, r - 390], fill=(232, 233, 238), outline=(26, 29, 36), width=WIDTH)
    draw.rectangle([x - 395, r - 392, x - 335, r - 366], fill=(70, 74, 92), outline=(26, 29, 36), width=WIDTH)
    draw.ellipse([x - 345, r - 462, x - 315, r - 432], fill=(90, 220, 255))


def control_drone_gunner(draw, r, x):
    _drone_body(draw, r, x)
    draw.rectangle([x - 290, r - 448, x - 255, r - 425], outline=WHITE, width=WIDTH)


def control_drone_sapper(draw, r, x):
    _drone_body(draw, r, x)
    for dx in (-400, -355, -310):
        draw.line([(x + dx, r - 400), (x + dx + 12, r - 350)], fill=WHITE, width=WIDTH)


def assist_shapes(k, r, x):
    """Piezas de la forma k del asistente: (tipo, caja o puntos, relleno)."""
    cx, cy = x - 560, r - 470
    w = 170 + 38 * k
    h = w // 2
    white, dark, glow = (232, 233, 238), (70, 74, 92), (90, 220, 255)
    shapes = []
    if k >= 3:
        shapes.append(("poly", [(cx - w * 0.2, cy - h * 0.3), (cx - w * 0.6, cy - h), (cx - w * 0.02, cy - h * 0.45)], white))
    if k >= 5:
        shapes.append(("ring", [cx - w * 0.3, cy - h * 1.32, cx + w * 0.3, cy - h * 1.05], glow))
        shapes.append(("poly", [(cx - w * 0.1, cy - h * 0.35), (cx - w * 0.38, cy - h * 1.15), (cx + w * 0.08, cy - h * 0.5)], white))
    if k >= 1:
        shapes.append(("poly", [(cx - w * 0.48, cy), (cx - w * 0.66, cy - h * 0.5), (cx - w * 0.4, cy - h * 0.12)], dark))
    if k >= 2:
        shapes.append(("ellipse", [cx - w * 0.46, cy + h * 0.05, cx - w * 0.14, cy + h * 0.5], dark))
    shapes.append(("rect", [cx - w * 0.12, cy - h * 0.82, cx + w * 0.18, cy - h * 0.42], dark))
    shapes.append(("rect", [cx + w * 0.18, cy - h * 0.74, cx + w * 0.42, cy - h * 0.6], dark))
    shapes.append(("rect", [cx - w * 0.16, cy + h * 0.42, cx + w * 0.14, cy + h * 0.82], dark))
    shapes.append(("ellipse", [cx - w * 0.5, cy - h * 0.5, cx + w * 0.5, cy + h * 0.5], white))
    shapes.append(("ellipse", [cx + w * 0.12, cy - h * 0.22, cx + w * 0.32, cy + h * 0.08], glow))
    if k >= 4:
        shapes.append(("ring", [cx - w * 0.6, cy - h * 0.66, cx + w * 0.6, cy + h * 0.66], dark))
    return shapes


def _draw_shapes(draw, shapes, filled):
    outline = (26, 29, 36) if filled else WHITE
    for kind, coords, fill in shapes:
        if kind == "ring":
            draw.ellipse(coords, outline=fill if filled else WHITE, width=WIDTH * (3 if filled else 1))
        elif kind == "poly":
            draw.polygon(coords, fill=fill if filled else None, outline=outline, width=WIDTH)
        elif kind == "ellipse":
            draw.ellipse(coords, fill=fill if filled else None, outline=outline, width=WIDTH)
        else:
            draw.rectangle(coords, fill=fill if filled else None, outline=outline, width=WIDTH)


def assist_design(k):
    subjects = [
        "small drone",
        "drone, tail fin",
        "drone, engine pods",
        "drone, mechanical wings",
        "drone, mechanical wings, armored ring",
        "drone, mechanical wings, halo, ornate",
    ]
    return {
        "zone": (-745, -250, -805, -335),
        "control": lambda draw, r, x: _draw_shapes(draw, assist_shapes(k, r, x), False),
        "block": lambda draw, r, x: _draw_shapes(draw, assist_shapes(k, r, x), True),
        "subject": "full body, from side, armor, flying robot, hovering, non-humanoid robot, gun turret, "
        + subjects[k],
        "negative": "holding, hands, propeller, 1other, humanoid",
        "control_scale": 0.8,
        "control_end": 0.6,
        "strength": 0.85,
        "shift": ASSIST_SHIFT,
    }


TORSO_SUBJECT = "full body, standing, from side, profile, solo, armor"
LEGS_SUBJECT = "lower body, from side, profile, solo, armor"
DRONE_SUBJECT = "full body, from side, armor, drone, flying robot, hovering, non-humanoid robot"
DESIGNS = {
    "dron_artillero": {
        "zone": DRONE_ZONE,
        "control": control_drone_gunner,
        "block": block_drone,
        "control_scale": 0.8,
        "control_end": 0.6,
        "strength": 0.85,
        "subject": DRONE_SUBJECT + ", gun",
        "negative": "holding, hands, wings, propeller, 1other",
    },
    "dron_zapador": {
        "zone": DRONE_ZONE,
        "control": control_drone_sapper,
        "block": block_drone,
        "control_scale": 0.8,
        "control_end": 0.6,
        "strength": 0.85,
        "subject": DRONE_SUBJECT + ", claws, antenna",
        "negative": "holding, hands, wings, propeller, 1other",
    },
    "brazo_corto": {
        "zone": ARM_ZONE,
        "control": control_arm_short,
        "subject": TORSO_SUBJECT + ", arm cannon, shotgun, flamethrower, short barrel",
        "negative": style.WEAPON_NEGATIVE,
    },
    "brazo_largo": {
        "zone": ARM_ZONE_LONG,
        "control": control_arm_long,
        "subject": TORSO_SUBJECT + ", arm cannon, railgun, sniper rifle, long barrel",
        "negative": style.WEAPON_NEGATIVE,
    },
    "brazo_saboteador": {
        "zone": ARM_ZONE,
        "control": control_arm_siphon,
        "subject": TORSO_SUBJECT + ", arm cannon, tesla coil, claw, emitter",
        "negative": style.WEAPON_NEGATIVE + ", lightning, electricity",
    },
    "hombro_artilleria": {
        "zone": SHOULDER_ZONE,
        "control": control_shoulder_artillery,
        "subject": TORSO_SUBJECT + ", shoulder cannon, artillery, howitzer, long barrel",
        "negative": "holding, hands, wings",
        "shift": SHOULDER_SHIFT,
    },
    "hombro_ancla": {
        "zone": SHOULDER_ZONE,
        "control": control_shoulder_harpoon,
        "subject": TORSO_SUBJECT + ", shoulder cannon, harpoon launcher, harpoon",
        "negative": "holding, hands, wings",
        "shift": SHOULDER_SHIFT,
    },
    "brazo_medio": {
        "zone": ARM_ZONE,
        "control": control_arm_gun,
        "subject": TORSO_SUBJECT + ", arm cannon, machine gun, gatling gun, gun barrel",
        "negative": style.WEAPON_NEGATIVE,
    },
    "brazo_hoja": {
        "zone": ARM_ZONE,
        "control": control_arm_blade,
        "subject": TORSO_SUBJECT + ", arm blade, energy sword, mechanical arm",
        "negative": "holding, hands, sheath, medieval",
    },
    "hombro_bateria": {
        "zone": SHOULDER_ZONE,
        "control": control_shoulder_pod,
        "subject": TORSO_SUBJECT + ", shoulder cannon, missile pod, missile launcher",
        "negative": "holding, hands, wings",
        "shift": SHOULDER_SHIFT,
    },
    "piernas_orugas": {
        "zone": LEGS_ZONE,
        "control": control_tracks,
        "subject": LEGS_SUBJECT + ", tank treads, caterpillar tracks, crawler",
        "negative": "feet, legs, humanoid legs, wings",
        "strength": 1.0,
    },
    "piernas_ruedas": {
        "zone": LEGS_ZONE,
        "control": control_wheels,
        "subject": LEGS_SUBJECT + ", wheels, tire, wheeled vehicle",
        "negative": "feet, legs, humanoid legs, wings",
        "strength": 1.0,
    },
    "piernas_ruedas_cuna": {
        "zone": LEGS_ZONE,
        "control": control_wheel_wedge,
        "subject": LEGS_SUBJECT + ", tank chassis, caterpillar tracks, road wheels, sloped armor",
        "negative": "feet, humanoid legs, wings, car, cart, wagon",
        "strength": 1.0,
    },
    "piernas_levita": {
        "zone": LEGS_ZONE,
        "control": control_hover,
        "subject": LEGS_SUBJECT + ", hovering, floating, thrusters, hover skirt",
        "negative": "feet, legs, humanoid legs, wings, wheels, flames",
        "strength": 1.0,
    },
}
for _k in range(6):
    DESIGNS["asistente_%d" % _k] = assist_design(_k)


def zone_mask(zone, row, x):
    """Blanco = zona que se vuelve a dibujar."""
    top, bottom, left, right = zone
    mask = np.zeros((SIZE, SIZE), dtype=np.uint8)
    mask[max(0, row + top) : min(SIZE, row + bottom), max(0, x + left) : min(SIZE, x + right)] = 255
    return Image.fromarray(mask, "L")


def _shift_of(design):
    """(abajo, derecha) en pixeles; un numero solo es hacia abajo."""
    shift = design.get("shift", 0)
    return shift if isinstance(shift, tuple) else (shift, 0)


def shifted(base, shift):
    """La base movida (abajo, derecha), rellenando con el color del fondo."""
    down, right = shift
    if down == 0 and right == 0:
        return base
    pixels = np.asarray(base)
    fill = tuple(int(v) for v in pixels[:8].reshape(-1, 3).mean(axis=0))
    out = Image.new("RGB", base.size, fill)
    out.paste(base.crop((0, 0, base.width - right, base.height - down)), (right, down))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("base", type=Path)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--designs", nargs="+", choices=sorted(DESIGNS), default=sorted(DESIGNS))
    parser.add_argument("--seeds", type=int, nargs="+", default=[1, 2, 3, 4])
    parser.add_argument("--hip", type=int, nargs=2, metavar=("FILA", "X"), default=[530, 493])
    parser.add_argument("--control-scale", type=float, default=0.65)
    parser.add_argument("--control-end", type=float, default=0.5)
    parser.add_argument("--strength", type=float, default=0.9)
    parser.add_argument("--controls-only", action="store_true", help="solo guarda las siluetas, sin GPU")
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    row, x = args.hip
    original = Image.open(args.base).convert("RGB")
    bases = {}
    for name in args.designs:
        shift = _shift_of(DESIGNS[name])
        if shift not in bases:
            bases[shift] = shifted(original, shift)
            label = "_base.png"
            if shift != (0, 0):
                label = "_base_bajada_%d.png" % shift[0] if shift[1] == 0 else "_base_movida_%d_%d.png" % shift
            bases[shift].save(out / label)
    controls = {}
    for name in args.designs:
        shift = _shift_of(DESIGNS[name])
        base = bases[shift]
        control = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
        DESIGNS[name]["control"](ImageDraw.Draw(control), row + shift[0], x + shift[1])
        controls[name] = control
        # Silueta sobre la base, para revisar a ojo donde cae cada pieza.
        preview = base.copy()
        preview.paste((255, 60, 60), mask=control.convert("L"))
        preview.save(out / ("_silueta_%s.png" % name))
    if args.controls_only:
        print("LISTO (solo siluetas) en", out)
        return

    pipe = sd.load_pipeline("fp8", controlled="inpaint")
    colors = style.colors_for("chassis", "physical")
    for name in args.designs:
        design = DESIGNS[name]
        shift = _shift_of(design)
        base = bases[shift]
        mask = zone_mask(design["zone"], row + shift[0], x + shift[1])
        start = base
        if "block" in design:
            start = base.copy()
            design["block"](ImageDraw.Draw(start), row + shift[0], x + shift[1])
        soft = mask.filter(ImageFilter.GaussianBlur(4))
        text = style.prompt(design["subject"], colors)
        print("%s: %d tokens" % (name, len(pipe.tokenizer(text).input_ids)), flush=True)
        for seed in args.seeds:
            started = time.time()
            image = pipe(
                prompt=style.prompt(design["subject"], colors),
                negative_prompt=style.NEGATIVE + ", " + design["negative"],
                image=start,
                mask_image=mask,
                strength=design.get("strength", args.strength),
                control_image=[controls[name]],
                control_mode=[sd.MODE_SCRIBBLE],
                controlnet_conditioning_scale=design.get("control_scale", args.control_scale),
                control_guidance_end=design.get("control_end", args.control_end),
                num_inference_steps=style.STEPS,
                guidance_scale=style.CFG,
                width=SIZE,
                height=SIZE,
                generator=torch.Generator("cpu").manual_seed(seed),
            ).images[0]
            # Fuera de la zona repintada se conservan los pixeles de la base.
            image = Image.composite(image, base, soft)
            file = "%s_%d.png" % (name, seed)
            image.save(out / file)
            print("ok  %s  %.0f s  pico VRAM %.1f GB" % (file, time.time() - started, sd.peak_vram_gb()), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
