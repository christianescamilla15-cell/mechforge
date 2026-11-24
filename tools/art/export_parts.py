"""Exporta al juego un torso y unas piernas del chasis (docs/CHASIS.md).

Recorta cada pieza por el aro de cintura, le quita el fondo, la colorea por
elemento (blanco original, calor y energia) y guarda los PNG con un JSON de
anclas que lee el juego (scenes/battle/mech_sprites.gd).

No usa la GPU.
Uso: tools/art/run.ps1 tools/art/export_parts.py --torso t.png --legs l.png \
        --hip 530 493 --name ligero_18 --out assets/mechs

Las piezas de frente (tools/art/turn_test.py) salen de un panel de 768, a
0.75 del lienzo: se exportan con --scale 0.6667 para que midan lo mismo que
las de perfil, con el aro en la fila 397 y la columna 384, y se llaman
frente_<juego>:
  tools/art/run.ps1 tools/art/export_parts.py --torso f.png --hip 397 384 \
        --scale 0.6667 --holes --name frente_ligero_13 --out assets/mechs

Las fases de un torso (tools/art/phase_chain.py) se exportan con --glow-free:
  tools/art/run.ps1 tools/art/export_parts.py --torso fase03_101.png \
        --hip 530 493 --glow-free --name ligero_13_f3 --out assets/mechs
"""

import argparse
import json
from pathlib import Path

from PIL import Image

import cut_body
import cutout
import recolor

# Elemento del juego -> esquema de color (None = el dibujo original).
ELEMENTS = {"PHYSICAL": None, "HEAT": recolor.SCHEMES["calor"], "ENERGY": recolor.SCHEMES["energia"]}


def piece(path, hip, keep_upper, holes=False, glow_free=False):
    """Devuelve (imagen original, mascara de la pieza). `holes`: quita tambien
    el fondo encerrado por la figura (de frente, entre las piernas).
    `glow_free`: deja fuera el brillo y la sombra suaves que pintan las fases
    altas (cutout.glow_free_figure), que si no se quedan como un halo."""
    image = Image.open(path).convert("RGB")
    if glow_free:
        mask, tolerance = cutout.glow_free_figure(image)
        print("recorte %s: tolerancia %d" % (path.name, tolerance))
    else:
        mask = cutout.clean_figure(image)
    if holes:
        mask = cutout.drop_holes(image, mask)
    row = hip[0]
    if keep_upper:
        mask[row + cut_body.OVERLAP :] = False
    else:
        mask[: row - cut_body.OVERLAP] = False
    return image, mask


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--torso", type=Path, help="imagen de la que sale el torso")
    parser.add_argument("--legs", type=Path, help="imagen de la que salen las piernas")
    parser.add_argument("--hip", type=int, nargs=2, metavar=("FILA", "X"), required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--scale", type=float, default=0.5, help="reduccion respecto al lienzo de 1024")
    parser.add_argument("--holes", action="store_true", help="quita el fondo encerrado por la figura")
    parser.add_argument("--glow-free", action="store_true", help="sin el brillo de alrededor (las fases)")
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    hip = tuple(args.hip)
    # Las anclas de las piezas que no se exportan ahora se conservan (un
    # juego puede sacar el torso y las piernas de imagenes distintas, y el
    # arma de pecho la anade tools/art/extract_overlay.py).
    anchors = {}
    existing = args.out / (args.name + ".json")
    if existing.exists():
        anchors = json.loads(existing.read_text(encoding="utf-8"))
    anchors["scale"] = args.scale
    for kind, path, keep_upper in (("torso", args.torso, True), ("legs", args.legs, False)):
        if path is None:
            continue
        image, mask = piece(path, hip, keep_upper, args.holes, args.glow_free)
        for element, scheme in ELEMENTS.items():
            colored = recolor.recolor(image, scheme)
            sprite, anchor = cut_body.crop_piece(colored, mask, hip)
            size = (round(sprite.width * args.scale), round(sprite.height * args.scale))
            sprite.resize(size, Image.LANCZOS).save(args.out / ("%s_%s_%s.png" % (args.name, kind, element)))
        anchors[kind] = {"hip": [round(anchor[0] * args.scale), round(anchor[1] * args.scale)], "size": list(size)}
    (args.out / (args.name + ".json")).write_text(json.dumps(anchors, indent=2), encoding="utf-8")
    print("exportado %s en %s: %s" % (args.name, args.out, json.dumps(anchors)))


if __name__ == "__main__":
    main()
