"""Piloto de las armas de arena (OBS-051, PLAN A5).

Del usuario (2026-11-24): "me gusto la parte de los modelos y disenos de los
niveles mas altos, para este modo vamos a probar e implementar armas mas
poderosas"; "creemos disenos especiales, especialmente adaptados para la
arena, que seran los que se entregaran al azar". Cada arma de arena parte del
dibujo de la fase 10 de un arma del juego (el estilo de las fases altas que le
gusto) y se repinta con el tema de la arena: campeon de coliseo, carmesi y
negro con oro, laureles y trofeos, para que no se confunda con el blanco y oro
divino de las fases. Se repinta la silueta algo ampliada, sin tocar su union
con el robot (como weapon_phases.py), y despues una pasada de detalle suave.

Es un piloto: pocas armas y tres semillas, para elegir el estilo antes de
hacerlas todas (regla del proyecto: piloto antes de rehacer en masa).

Las imagenes van a art_raw/parts/<tanda>/<arma>_<semilla>.png.
Con --export se llevan al juego las elegidas (CHOSEN, sin GPU): recortadas,
coloreadas por elemento y con sus anclas, como "<hueco>_arena_<arma>" en
assets/mechs/armas_ligero (el "look" de las armas de arena del catalogo).
Uso:
  tools/art/run.ps1 -KeepWatcher tools/art/arena_weapons.py --batch arena_piloto
  tools/art/run.ps1 -KeepWatcher tools/art/arena_weapons.py --batch arena_piloto --designs arena_hoja
  tools/art/run.ps1 -KeepWatcher tools/art/arena_weapons.py --export
"""

import argparse
import json
import time

from PIL import Image, ImageFilter

import gpu_turn
import style
import weapon_phases as wp
import weapons_test as wt

OUT = wt.OUT
# Arma de arena: (dibujo del juego del que parte, tanda y semilla de su fase
# 10, sujeto del prompt).
DESIGNS = {
    "arena_lanza": ("arm_medio_laser", "fases_armas2", 101, "champion lance cannon, mechanical arm"),
    "arena_hoja": ("arm_hoja_laser", "fases_armas2", 101, "champion greatsword, mechanical arm"),
    "arena_artilleria": ("shoulder_artilleria_laser", "fases_armas2", 101, "champion shoulder cannon, turret"),
    "arena_bateria": ("shoulder_bateria_laser", "fases_armas2", 101, "champion missile pod, turret"),
    "arena_cuchilla": ("arm_corto_laser", "fases_armas2", 101, "champion war cannon, mechanical arm"),
}
# El juego recolorea cada arma por elemento al exportarla (export_weapons):
# el tema tiene que estar en la forma (puas, cresta, emblema), no en el color.
THEME = "arena champion weapon, ornate spikes, laurel crest, trophy emblem, gold trim, layered armor"
COLORS = "crimson, black, gold"
REFINE = "intricate details, ornate engravings, trophy emblem"
NEGATIVE_EXTRA = "white armor, blue, halo"
# Las elegidas del piloto (2026-11-25, hoja art_raw/parts/arena_elegidas_hoja.png):
# diseno -> (tanda, semilla, dibujo en el juego).
CHOSEN = {
    "arena_lanza": ("arena_piloto2", 311, "arm_arena_lanza"),
    "arena_hoja": ("arena_piloto", 302, "arm_arena_hoja"),
    "arena_cuchilla": ("arena_piloto2", 311, "arm_arena_tridente"),
    "arena_bateria": ("arena_piloto2", 311, "shoulder_arena_bateria"),
}


def flatten_background(image, step=3, far=70):
    """El fondo de estas armas es un degradado (oscuro en una esquina, un
    halo claro alrededor de la pieza), y el recorte de siempre compara con un
    solo color: se quedaba con trozos de fondo. Rellena el fondo desde el
    borde siguiendo el degradado (cada pixel comparado con su vecino, a
    `step`), que se para en el contorno de tinta de la pieza, y lo pinta del
    color mediano del borde."""
    import cv2
    import numpy as np

    pixels = np.asarray(image.convert("RGB")).copy()
    h, w, _ = pixels.shape
    border = np.concatenate([pixels[:6].reshape(-1, 3), pixels[-6:].reshape(-1, 3), pixels[:, -6:].reshape(-1, 3)])
    median = np.median(border, axis=0)
    mask = np.zeros((h + 2, w + 2), np.uint8)
    flags = 4 | cv2.FLOODFILL_MASK_ONLY | (255 << 8)
    seeds = [(x, y) for x in range(0, w, 16) for y in (0, h - 1)]
    seeds += [(x, y) for y in range(0, h, 16) for x in (0, w - 1)]
    for x, y in seeds:
        if mask[y + 1, x + 1] or np.abs(pixels[y, x].astype(int) - median).max() > far:
            continue
        cv2.floodFill(pixels, mask, (x, y), 0, (step,) * 3, (step,) * 3, flags)
    pixels[mask[1:-1, 1:-1] > 0] = median.astype(np.uint8)
    return Image.fromarray(pixels)


def export(designs, sheet=None):
    import export_weapons

    path = export_weapons.SET.with_suffix(".json")
    anchors = json.loads(path.read_text(encoding="utf-8"))
    flat = OUT / "arena_exportadas"
    flat.mkdir(parents=True, exist_ok=True)
    exported = {}
    for design in designs:
        batch, seed, look = CHOSEN[design]
        source = flat / ("%s_%d.png" % (design, seed))
        flatten_background(Image.open(OUT / batch / source.name)).save(source)
        base = DESIGNS[design][0]
        anchors[look], exported[look] = export_weapons.export(look, source, placement=wt.placement(base))
        print("exportada %s: %s" % (look, json.dumps(anchors[look])))
    path.write_text(json.dumps(anchors, indent=2), encoding="utf-8")
    if sheet:
        cell = (470, 190)
        board = Image.new("RGB", (cell[0] * 3, cell[1] * len(exported)), "#2b303a")
        for row, sprites in enumerate(exported.values()):
            for column, sprite in enumerate(sprites):
                at = (column * cell[0] + (cell[0] - sprite.width) // 2, row * cell[1] + (cell[1] - sprite.height) // 2)
                board.paste(sprite, at, sprite)
        board.save(sheet)
        print("hoja:", sheet)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch", default="")
    parser.add_argument("--export", action="store_true", help="lleva al juego las elegidas (CHOSEN)")
    parser.add_argument("--sheet", default=None, help="con --export: hoja con lo exportado")
    parser.add_argument("--designs", nargs="+", default=sorted(DESIGNS), choices=sorted(DESIGNS))
    parser.add_argument("--seeds", type=int, nargs="+", default=[301, 302, 303])
    parser.add_argument("--strength", type=float, default=0.86)
    parser.add_argument("--refine", type=float, default=0.35)
    parser.add_argument("--steps", type=int, default=style.STEPS)
    args = parser.parse_args()
    if args.export:
        export([d for d in args.designs if d in CHOSEN], args.sheet)
        return
    if not args.batch:
        parser.error("hace falta --batch")

    import sd

    turn = gpu_turn.Turn(lambda: sd.load_pipeline("fp8", controlled="inpaint"))
    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    for design in args.designs:
        name, batch, seed_from, subject = DESIGNS[design]
        start = Image.open(OUT / batch / ("%s_f10_%d.png" % (name, seed_from))).convert("RGB")
        _, control = wt.render(name)
        prompt = style.prompt(subject + ", " + THEME, COLORS)
        refine = style.prompt(subject + ", " + REFINE, COLORS)
        for text in (prompt, refine):
            tokens = len(turn.pipe().tokenizer(text).input_ids)
            if tokens > 77:
                raise SystemExit("%s: el prompt tiene %d tokens (max 77)" % (design, tokens))
        negative = NEGATIVE_EXTRA + ", " + wp.negative(THEME)
        for seed in args.seeds:
            started = time.time()
            current = start
            for text, power, noise in ((prompt, args.strength, seed), (refine, args.refine, seed + 1000)):
                if power <= 0:
                    continue
                mask = wp.repaint_mask(current, name, 10)
                image = turn.run(
                    noise,
                    prompt=text,
                    negative_prompt=negative,
                    image=current,
                    mask_image=mask,
                    strength=power,
                    control_image=[control],
                    control_mode=[sd.MODE_SCRIBBLE],
                    controlnet_conditioning_scale=0.0,
                    control_guidance_end=0.4,
                    num_inference_steps=args.steps,
                    guidance_scale=style.CFG,
                    width=current.width,
                    height=current.height,
                ).images[0]
                current = Image.composite(image, current, mask.filter(ImageFilter.GaussianBlur(4)))
            file_name = "%s_%d.png" % (design, seed)
            current.save(out / file_name)
            print("ok  %s  %.0f s" % (file_name, time.time() - started), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
