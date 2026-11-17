"""Convierte una grabacion del juego (AVI de Godot) en un GIF corto para
revisar animaciones. Recorta la zona de la arena y reduce el tamano.

No usa la GPU.
Uso: python movie_to_gif.py grabacion.avi salida.gif [--start 0] [--end 12]
         [--crop X Y ANCHO ALTO] [--width 800] [--fps 12]
"""

import argparse
from pathlib import Path

import cv2
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("movie", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--start", type=float, default=0.0, help="segundo en que empieza el clip")
    parser.add_argument("--end", type=float, default=1e9, help="segundo en que termina")
    parser.add_argument("--crop", type=int, nargs=4, metavar=("X", "Y", "ANCHO", "ALTO"))
    parser.add_argument("--width", type=int, default=800)
    parser.add_argument("--fps", type=float, default=12.0)
    args = parser.parse_args()

    video = cv2.VideoCapture(str(args.movie))
    source_fps = video.get(cv2.CAP_PROP_FPS) or 30.0
    every = max(1, round(source_fps / args.fps))
    frames, index = [], 0
    while True:
        ok, frame = video.read()
        if not ok:
            break
        second = index / source_fps
        index += 1
        if second < args.start or second > args.end or (index - 1) % every:
            continue
        if args.crop:
            x, y, w, h = args.crop
            frame = frame[y : y + h, x : x + w]
        image = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        height = round(image.height * args.width / image.width)
        image = image.resize((args.width, height), Image.LANCZOS)
        frames.append(image.convert("P", palette=Image.ADAPTIVE, colors=96))
    if not frames:
        raise SystemExit("la grabacion no tiene cuadros en ese tramo (duracion %.1f s)" % (index / source_fps))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        args.out, save_all=True, append_images=frames[1:], duration=round(1000 * every / source_fps), loop=0, optimize=True
    )
    size_mb = args.out.stat().st_size / 2**20
    print("gif: %s  %d cuadros  %.1f MB  (grabacion de %.1f s)" % (args.out, len(frames), size_mb, index / source_fps))


if __name__ == "__main__":
    main()
