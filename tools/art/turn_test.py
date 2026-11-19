"""Piezas de frente sacadas de su propio dibujo de perfil (pedido del usuario
el 2026-11-19: "de frente, pero por piezas... el ejemplo cambio por completo
el diseno del robot, debe mantenerse exactamente igual").

Hoja de vistas: a la izquierda va el robot de perfil tal como esta en el
juego, y no se toca; a la derecha el modelo dibuja el mismo robot de frente.
Como las dos vistas estan en la misma imagen, el modelo copia de la de perfil
los colores, las placas y los detalles en vez de inventar un robot nuevo
(que es lo que hacia tools/art/front_test.py, que partia de un boceto).

La vista de perfil se arma con el torso de una imagen y las piernas de otra,
unidos por el aro de cintura que comparten todas las piezas (docs/CHASIS.md).
Con --front y --zone solo se repinta el torso o las piernas de una vista de
frente ya elegida (el maniqui de frente), para que todas las piezas de frente
nazcan encajadas en el mismo aro, igual que las de perfil.

Sin guia de forma el modelo copia el lenguaje del robot pero le pone brazos
y piernas de humanoide (primera tanda del 2026-11-19). Por eso el contorno de
la vista de frente se calcula de la propia silueta de perfil, fila por fila
(front_outline): el casco, la cintura, las rodillas y los pies quedan a la
misma altura que en el perfil, y el ancho de cada fila es una fraccion de su
fondo. El aro de cintura es redondo, asi que de frente mide lo mismo.
Dentro de ese contorno la imagen de partida es el propio perfil "desplegado"
(front_unfold): en cada fila, lo de delante (el pico) va al centro y lo de
atras (la lente) a los dos bordes, con sus colores. Y solo se repinta la
envolvente de la figura: con medio lienzo libre el modelo dibuja figuras de
mas (segunda tanda).

Las imagenes van a art_raw/parts/frente/<tanda>_<semilla>.png (la hoja
entera) y <tanda>_<semilla>_frente.png (solo la vista de frente).
Uso:
  tools/art/run.ps1 tools/art/turn_test.py --torso art_raw/parts/lote_ligero/torso_13.png \
      --legs docs/reference/art/elegidos/ligero/robot_18.png --tag t13p18 --seeds 1 2 3 4
Los que estan en el juego salieron con --strength 0.7 --depth 0.8 --leg-depth 0.62
--leg-max 128 (t13p18d_2, t16p14_4 y t18p17_4).
"""

import argparse
import time
from pathlib import Path

import cv2
import numpy as np
import torch
from PIL import Image, ImageFilter

import blockout
import cut_body
import cutout
import halves_test
import sd
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "parts" / "frente"
# Lado de cada vista en la hoja: dos vistas de 768 ocupan lo mismo que un
# lienzo de 1024 y caben en la memoria de la tarjeta.
PANEL = 768
SUBJECT = "reference sheet, multiple views, turnaround, from side, straight-on, facing viewer, full body, standing"
COLORS = "white armor, steel grey armor"
# El negativo del estilo prohibe "multiple views": aqui hace falta.
NEGATIVE = style.NEGATIVE.replace("multiple views, ", "") + ", " + style.BODY_NEGATIVE + ", arms, hands, back view"


def side_view(torso, legs, hip_row):
    """El robot de perfil: el torso de una imagen sobre las piernas de otra,
    cortados por el aro de cintura."""
    upper = Image.open(torso).convert("RGB")
    if legs is None:
        return upper
    lower = Image.open(legs).convert("RGB")
    out = lower.copy()
    out.paste(upper.crop((0, 0, upper.width, hip_row + cut_body.OVERLAP)), (0, 0))
    return out


def _smooth(values, sigma=5):
    """Suaviza un perfil de anchos por fila."""
    return cv2.GaussianBlur(values.astype(np.float32).reshape(-1, 1), (1, 0), sigma).ravel()


def front_unfold(side, side_mask, hip_row, depth, leg_depth, leg_max, single_legs=False):
    """Vista de frente de partida, deducida de la de perfil. Devuelve
    (imagen del panel, mascara de la figura).

    Sobre el aro es una sola masa centrada cuyo ancho en cada fila es `depth`
    veces el fondo del perfil en esa fila; bajo el aro, dos piernas iguales,
    cada una `leg_depth` veces su fondo y como mucho `leg_max` de ancho (con
    `single_legs`, una sola base centrada: orugas, ruedas o levitar). Cada
    mitad de cada masa lleva la fila del perfil entera: el borde de atras en
    el borde de fuera y el de delante (el robot mira a la derecha) en el
    centro."""
    pixels = np.asarray(side)
    height, width = side_mask.shape
    center = width // 2
    back = np.zeros(height, dtype=int)
    extent = np.zeros(height)
    for row in range(height):
        columns = np.flatnonzero(side_mask[row])
        if columns.size:
            back[row] = columns[0]
            extent[row] = columns[-1] - columns[0] + 1
    ring = int(halves_test.RING_RADIUS[0] * width / blockout.SIZE)
    band = int(halves_test.RING_RADIUS[1] * width / blockout.SIZE)
    torso = _smooth(extent * depth)
    legs = np.minimum(_smooth(extent * leg_depth), leg_max)
    apart = max(ring * 4 // 5, leg_max // 2 + 12)
    background = np.median(pixels[:6].reshape(-1, 3), axis=0)
    out = np.empty_like(pixels)
    out[:] = background
    front = np.zeros_like(side_mask, dtype=bool)

    def paint(row, middle, half):
        # De fuera al centro: de atras hacia delante en el perfil.
        source = back[row] + np.linspace(0, extent[row] - 1, half).astype(int)
        colors = pixels[row, source]
        inside = side_mask[row, source]
        left = slice(middle - half, middle)
        right = slice(middle + half - 1, middle - 1, -1)
        for side_slice in (left, right):
            out[row, side_slice] = np.where(inside[:, None], colors, out[row, side_slice])
            front[row, side_slice] |= inside

    for row in range(height):
        if extent[row] == 0:
            continue
        if abs(row - hip_row) < band:
            # El aro de acople: el mismo ancho que de perfil.
            paint(row, center, ring)
        elif row < hip_row:
            paint(row, center, int(max(torso[row], 8) / 2))
        elif single_legs:
            paint(row, center, int(max(legs[row], 8) / 2))
        else:
            # Separadas: entre las dos piernas tiene que verse el fondo.
            for leg_center in (center - apart, center + apart):
                paint(row, leg_center, int(max(legs[row], 8) / 2))
    # Cierra los agujeros de un pixel que deja el muestreo.
    front = cv2.morphologyEx(front.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)).astype(bool)
    return Image.fromarray(out, "RGB"), front


def outline_image(mask, line):
    """Contorno de una mascara como lineas blancas sobre negro."""
    contours, _ = cv2.findContours(mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    canvas = np.zeros(mask.shape, dtype=np.uint8)
    cv2.drawContours(canvas, contours, -1, 255, line)
    return canvas


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--torso", type=Path, required=True, help="imagen de perfil de la que sale el torso")
    parser.add_argument("--legs", type=Path, help="imagen de perfil de la que salen las piernas (por defecto, la misma)")
    parser.add_argument("--hip", type=int, nargs=2, metavar=("FILA", "X"), default=[530, 493])
    parser.add_argument("--front", type=Path, help="vista de frente ya elegida: solo se repinta --zone")
    parser.add_argument("--front-hip", type=int, help="fila del aro en la vista de frente (en su panel)")
    parser.add_argument("--zone", choices=["torso", "legs"], help="con --front: que parte se repinta")
    parser.add_argument("--tag", required=True)
    parser.add_argument("--seeds", type=int, nargs="+", default=[1, 2, 3, 4])
    parser.add_argument("--strength", type=float, default=0.85, help="1 = no queda nada del perfil desplegado")
    parser.add_argument("--margin", type=int, default=26, help="cuanto se repinta alrededor de la figura")
    parser.add_argument("--control-scale", type=float, default=0.55, help="0 = sin contorno: forma libre")
    parser.add_argument("--control-end", type=float, default=0.5)
    parser.add_argument("--depth", type=float, default=0.62, help="ancho de frente del torso / fondo de perfil")
    parser.add_argument("--leg-depth", type=float, default=0.5, help="lo mismo para cada pierna")
    parser.add_argument("--leg-max", type=int, default=104, help="ancho maximo de una pierna, en pixeles del panel")
    parser.add_argument("--single-legs", action="store_true", help="la base es una sola pieza (orugas, ruedas, levitar)")
    parser.add_argument("--sheet-only", action="store_true", help="solo guarda la hoja de partida, sin GPU")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    side = side_view(args.torso, args.legs, args.hip[0]).resize((PANEL, PANEL), Image.LANCZOS)
    background = tuple(int(v) for v in np.median(np.asarray(side)[:6].reshape(-1, 3), axis=0))
    sheet = Image.new("RGB", (PANEL * 2, PANEL), background)
    sheet.paste(side, (0, 0))
    hip_row = args.hip[0] * PANEL // blockout.SIZE
    side_mask = cutout.clean_figure(side)
    unfolded, front_mask = front_unfold(
        side, side_mask, hip_row, args.depth, args.leg_depth, args.leg_max, args.single_legs
    )
    envelope = cv2.dilate(front_mask.astype(np.uint8), np.ones((args.margin * 2 + 1,) * 2, np.uint8)) * 255
    mask = np.zeros((PANEL, PANEL * 2), dtype=np.uint8)
    if args.front:
        sheet.paste(Image.open(args.front).convert("RGB").resize((PANEL, PANEL), Image.LANCZOS), (PANEL, 0))
        row = args.front_hip
        if args.zone == "torso":
            mask[: row - 16, PANEL + 24 :] = 255
        else:
            mask[row + 16 :, PANEL + 24 :] = 255
    else:
        sheet.paste(unfolded, (PANEL, 0))
        mask[:, PANEL:] = envelope
    mask_image = Image.fromarray(mask, "L").filter(ImageFilter.GaussianBlur(4))
    # Control: las lineas del perfil a la izquierda y el contorno deducido de
    # la vista de frente a la derecha.
    lines = np.zeros((PANEL, PANEL * 2), dtype=np.uint8)
    edges = cv2.Canny(cv2.cvtColor(np.asarray(side), cv2.COLOR_RGB2GRAY), 60, 160)
    lines[:, :PANEL] = cv2.dilate(edges, np.ones((2, 2), np.uint8)) * side_mask
    lines[:, PANEL:] = outline_image(front_mask, 4)
    control = Image.fromarray(np.dstack([lines] * 3), "RGB")
    sheet.save(OUT / ("_hoja_%s.png" % args.tag))
    control.save(OUT / ("_control_%s.png" % args.tag))
    if args.sheet_only:
        print("LISTO (solo la hoja) en", OUT)
        return

    pipe = sd.load_pipeline("fp8", controlled="inpaint")
    prompt = style.prompt(SUBJECT, COLORS)
    tokens = len(pipe.tokenizer(prompt).input_ids)
    if tokens > 77:
        raise SystemExit("prompt de %d tokens (> 77): se perderia el final" % tokens)
    for seed in args.seeds:
        started = time.time()
        image = pipe(
            prompt=prompt,
            negative_prompt=NEGATIVE,
            image=sheet,
            mask_image=mask_image,
            strength=args.strength,
            control_image=[control],
            control_mode=[sd.MODE_SCRIBBLE],
            controlnet_conditioning_scale=args.control_scale,
            control_guidance_end=args.control_end,
            num_inference_steps=style.STEPS,
            guidance_scale=style.CFG,
            width=PANEL * 2,
            height=PANEL,
            generator=torch.Generator("cpu").manual_seed(seed),
        ).images[0]
        name = "%s_%d" % (args.tag, seed)
        image.save(OUT / (name + ".png"))
        image.crop((PANEL, 0, PANEL * 2, PANEL)).save(OUT / (name + "_frente.png"))
        print("ok  %s.png  %.0f s  pico VRAM %.1f GB" % (name, time.time() - started, sd.peak_vram_gb()), flush=True)
    print("LISTO en", OUT)


if __name__ == "__main__":
    main()
