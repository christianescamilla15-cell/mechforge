"""El icono del juego: dos robots peleando (pedido del usuario, 2026-11-25:
"dejalo en el escritorio como ejecutable con su icono de robots peleando
personalizado").

Dibuja varias semillas a 1024x1024 con el estilo de los robots del juego (sin
el fondo liso de las piezas: es una escena) y, con --ico, recorta la elegida,
le pone un borde y la guarda como icon.ico (16 a 256 px) e icon.png en la
raiz del proyecto, que usan la ventana y el exportador de Windows.

Uso:
  tools/art/run.ps1 -KeepWatcher tools/art/icon_art.py
  tools/art/run.ps1 -KeepWatcher tools/art/icon_art.py --ico 403
"""

import argparse
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import gpu_turn
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "icono"
PROMPT = (
    "masterpiece, best quality, absurdres, no humans, mecha, two robots fighting, duel, "
    "face to face, clash, laser beam, sparks, dynamic pose, from side, arena, sunset sky, "
    "detailed mechanical parts, glowing eyes, anime coloring"
)
NEGATIVE = (
    "worst quality, bad quality, low quality, lowres, displeasing, scan artifacts, "
    "jpeg artifacts, monochrome, signature, text, logo, watermark, 1girl, 1boy, pilot, "
    "multiple views, mobile suit, v-fin, simple background"
)
SIZES = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (24, 24), (16, 16)]


def make_ico(seed, zoom):
    """Recorta el centro (zoom: cuanto del lado se queda), redondea las
    esquinas con un borde oscuro y guarda icon.ico e icon.png."""
    image = Image.open(OUT / ("icono_%d.png" % seed)).convert("RGBA")
    side = round(image.width * zoom)
    left = (image.width - side) // 2
    top = (image.height - side) // 2
    square = image.crop((left, top, left + side, top + side)).resize((512, 512), Image.LANCZOS)
    mask = Image.new("L", square.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 511, 511), radius=88, fill=255)
    framed = Image.new("RGBA", square.size, (0, 0, 0, 0))
    framed.paste(square, (0, 0), mask)
    ring = Image.new("RGBA", square.size, (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle((4, 4, 507, 507), radius=86, outline=(255, 205, 96, 255), width=10)
    framed = Image.alpha_composite(framed, ring.filter(ImageFilter.GaussianBlur(0.6)))
    framed.resize((256, 256), Image.LANCZOS).save(ROOT / "icon.png")
    framed.save(ROOT / "icon.ico", sizes=SIZES)
    print("icono:", ROOT / "icon.ico", ROOT / "icon.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--seeds", type=int, nargs="+", default=[401, 402, 403, 404])
    parser.add_argument("--ico", type=int, default=None, help="semilla elegida: hace icon.ico")
    parser.add_argument("--zoom", type=float, default=0.86)
    args = parser.parse_args()
    if args.ico is not None:
        make_ico(args.ico, args.zoom)
        return

    import sd

    OUT.mkdir(parents=True, exist_ok=True)
    turn = gpu_turn.Turn(lambda: sd.load_pipeline("fp8"))
    tokens = len(turn.pipe().tokenizer(PROMPT).input_ids)
    if tokens > 77:
        raise SystemExit("el prompt tiene %d tokens (max 77)" % tokens)
    for seed in args.seeds:
        started = time.time()
        image = turn.run(
            seed,
            prompt=PROMPT,
            negative_prompt=NEGATIVE,
            num_inference_steps=style.STEPS,
            guidance_scale=style.CFG,
            width=1024,
            height=1024,
        ).images[0]
        image.save(OUT / ("icono_%d.png" % seed))
        print("ok  icono_%d  %.0f s" % (seed, time.time() - started), flush=True)
    print("LISTO en", OUT)


if __name__ == "__main__":
    main()
