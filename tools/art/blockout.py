"""Bloques de partida para generar piezas: la silueta la ponemos nosotros.

Cada pieza es una lista de poligonos en "espacio de mech": el origen esta en
el suelo, bajo el centro del mech; x crece hacia donde mira (derecha) e y
crece hacia abajo, asi que las alturas son negativas. La unidad es el pixel
a la escala de la referencia de estilo (un mech entero mide unos 800).

De cada pieza salen tres imagenes:
  init     color plano sobre el gris de la referencia: fija paleta y encuadre
  control  lineas blancas sobre negro: lo que el ControlNet obliga a respetar
  mask     silueta en blanco y negro, para medir cuanto se respeto

Uso (solo dibuja los bloques, sin GPU):
  tools/art/run.ps1 tools/art/blockout.py [--element heat]
"""

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
# Gris de fondo medido en docs/reference/art/estilo_aprobado.png.
BACKGROUND = (172, 173, 174)
OUTLINE = (26, 29, 36)
LINE_WIDTH = 5

# Colores planos por elemento (GDD 5) y por papel dentro de la pieza.
PALETTES = {
    "physical": {
        "armor": (232, 232, 234),
        "armor2": (154, 163, 173),
        "frame": (61, 68, 80),
        "accent": (111, 168, 220),
    },
    "heat": {
        "armor": (217, 72, 43),
        "armor2": (240, 138, 46),
        "frame": (58, 48, 53),
        "accent": (255, 210, 62),
    },
    "energy": {
        "armor": (47, 95, 208),
        "armor2": (57, 198, 232),
        "frame": (43, 48, 64),
        "accent": (159, 246, 255),
    },
}


def _moved(points, dx, dy=0):
    return [(x + dx, y + dy) for x, y in points]


_THIGH = [(-60, -400), (60, -400), (112, -250), (18, -218)]
_SHIN = [(28, -262), (116, -250), (62, -70), (-22, -82)]
_FOOT = [(-52, -84), (82, -84), (152, -22), (152, 0), (-72, 0), (-72, -40)]
_TOE = [(92, -48), (152, -22), (152, 0), (82, 0)]

# Cada entrada: (papel, poligono). Se pintan en orden; lo ultimo tapa lo anterior.
PARTS = {
    "legs": [
        ("frame", _moved(_THIGH, -120)),
        ("frame", _moved(_SHIN, -120)),
        ("armor2", _moved(_FOOT, -120)),
        ("frame", [(-170, -432), (72, -432), (92, -368), (-190, -368)]),
        ("armor", _THIGH),
        ("armor", _SHIN),
        ("armor2", _FOOT),
        ("accent", _TOE),
    ],
    "torso": [
        ("frame", [(-200, -640), (-292, -662), (-302, -520), (-200, -500)]),
        ("armor", [(-170, -432), (-202, -600), (-150, -742), (40, -772), (172, -700), (202, -560), (130, -432)]),
        ("armor2", [(60, -690), (176, -680), (196, -566), (90, -520)]),
        ("armor", [(60, -772), (150, -792), (192, -740), (170, -700), (70, -720)]),
        ("accent", [(128, -766), (181, -748), (173, -727), (124, -740)]),
        ("armor", [(-122, -762), (-20, -802), (82, -762), (112, -670), (60, -600), (-82, -600), (-142, -670)]),
        ("frame", [(-50, -690), (10, -700), (40, -660), (0, -625), (-52, -640)]),
    ],
    "cannon": [
        ("frame", [(112, -556), (300, -548), (300, -520), (104, -520)]),
        ("armor2", [(140, -596), (470, -581), (470, -555), (140, -560)]),
        ("frame", [(470, -593), (522, -591), (522, -545), (470, -543)]),
        ("armor", [(-82, -602), (122, -612), (142, -540), (-72, -518)]),
        ("frame", [(-40, -585), (60, -590), (70, -556), (-36, -548)]),
    ],
}
# Conjuntos de piezas, en el orden en que se tapan. "body" es el mech sin
# armas: de ahi se cortan torso y piernas (las piezas sueltas no le salen
# bien al modelo, ver docs/reference/art-pipeline.md).
GROUPS = {
    "mech": ["legs", "torso", "cannon"],
    "body": ["legs", "torso"],
}
# Altura de la cadera en espacio de mech: por ahi se separan torso y piernas.
HIP_Y = -400
# Aumento comun de las piezas sueltas respecto a su tamano en el mech entero.
PART_ZOOM = 1.5
# Donde cae el origen del espacio de mech en el lienzo del mech entero.
MECH_ORIGIN = (400, 930)


def shapes_of(name):
    """Poligonos de una pieza o de un conjunto de piezas."""
    if name in GROUPS:
        return [shape for part in GROUPS[name] for shape in PARTS[part]]
    return PARTS[name]


def placement(name, fit):
    """Escala y desplazamiento para llevar la pieza al lienzo.

    fit=False la deja al tamano y en el sitio que ocupa en el mech entero.
    fit=True la centra y la agranda PART_ZOOM veces: mas detalle por pieza.
    El aumento es el mismo para todas, asi al reducirlas al tamano del juego
    el grosor de linea queda igual en todas.
    """
    if name in GROUPS or not fit:
        return 1.0, MECH_ORIGIN
    xs = [x for _, polygon in PARTS[name] for x, _ in polygon]
    ys = [y for _, polygon in PARTS[name] for _, y in polygon]
    width, height = PART_ZOOM * (max(xs) - min(xs)), PART_ZOOM * (max(ys) - min(ys))
    assert max(width, height) <= 0.92 * SIZE, "la pieza %s no cabe con PART_ZOOM" % name
    offset_x = SIZE / 2 - PART_ZOOM * (max(xs) + min(xs)) / 2
    offset_y = SIZE / 2 - PART_ZOOM * (max(ys) + min(ys)) / 2
    return PART_ZOOM, (offset_x, offset_y)


def contour_of(mask):
    """Solo el borde exterior de la silueta, como lineas blancas sobre negro.

    Es el control "suelto": obliga el contorno y deja libre el interior, que
    es donde el modelo pone el detalle mecanico.
    """
    grown = mask.filter(ImageFilter.MaxFilter(LINE_WIDTH))
    shrunk = mask.filter(ImageFilter.MinFilter(LINE_WIDTH))
    return ImageChops.subtract(grown, shrunk).convert("RGB")


def render(name, element="physical", fit=False):
    """Devuelve (init, control, mask) como imagenes PIL de SIZE x SIZE."""
    palette = PALETTES[element]
    scale, (offset_x, offset_y) = placement(name, fit)
    init = Image.new("RGB", (SIZE, SIZE), BACKGROUND)
    control = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    mask = Image.new("L", (SIZE, SIZE), 0)
    draw_init, draw_control, draw_mask = (ImageDraw.Draw(i) for i in (init, control, mask))
    for role, polygon in shapes_of(name):
        points = [(offset_x + scale * x, offset_y + scale * y) for x, y in polygon]
        closed = points + [points[0]]
        draw_init.polygon(points, fill=palette[role])
        draw_init.line(closed, fill=OUTLINE, width=LINE_WIDTH, joint="curve")
        # En el control cada forma tapa las lineas de lo que queda detras.
        draw_control.polygon(points, fill=(0, 0, 0))
        draw_control.line(closed, fill=(255, 255, 255), width=LINE_WIDTH, joint="curve")
        draw_mask.polygon(points, fill=255)
        draw_mask.line(closed, fill=255, width=LINE_WIDTH)
    return init, control, mask


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--element", choices=sorted(PALETTES), default="physical")
    args = parser.parse_args()
    out = Path(__file__).resolve().parents[2] / "art_raw" / "blockout"
    out.mkdir(parents=True, exist_ok=True)
    for name in sorted(GROUPS) + sorted(PARTS):
        for fit in (False, True):
            if name in GROUPS and fit:
                continue
            init, control, _ = render(name, args.element, fit)
            suffix = "_fit" if fit else ""
            init.save(out / ("%s_%s%s_init.png" % (name, args.element, suffix)))
            control.save(out / ("%s%s_control.png" % (name, suffix)))
    print("bloques en", out)


if __name__ == "__main__":
    main()
