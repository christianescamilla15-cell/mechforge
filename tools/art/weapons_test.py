"""Armas de brazo y de hombro, una por forma y tipo, a lienzo completo.

Las primeras armas montadas (tools/art/mounts_test.py) se dibujaron pequenas
sobre el robot base y salieron planas: tubos de color sin detalle. Aqui cada
arma se dibuja sola y grande, a partir de un bloque con su propio detalle
(details) y con el control a media fuerza. Lo que se probo antes de llegar
ahi esta en docs/CHASIS.md, seccion 6.

Un diseno por forma y tipo de arma del catalogo (docs/CATALOGO_ARMAS.md):
  brazo   medio, corto, largo  x  balas, canon, blaster, laser
          hoja                 x  balas, blaster, laser
          saboteador           x  blaster, laser
  hombro  bateria              x  balas, canon, blaster, laser
          artilleria           x  canon, blaster, laser
          ancla                x  canon, laser
El nombre del diseno es el de la pieza en el juego: arm_<forma>_<tipo> o
shoulder_<forma>_<tipo>.

Las coordenadas de cada bloque parten de la union con el robot: el eje del
hombro en las de brazo y el pie del pedestal en las de hombro. Cada bloque
se amplia hasta llenar su lienzo (placement), que en las de brazo es
apaisado (1536x640, los mismos pixeles que 1024x1024): un arma alargada en
un lienzo cuadrado solo ocupaba una franja y el modelo no tenia donde poner
detalle. tools/art/export_weapons.py deshace esa ampliacion y ancla el
sprite por la union.

Las imagenes van a art_raw/parts/<tanda>/<diseno>_<semilla>.png.
Uso:
  tools/art/run.ps1 tools/art/weapons_test.py --batch armas4 --seeds 101 102 103
  tools/art/run.ps1 -KeepWatcher tools/art/weapons_test.py --batch armas4 --blocks-only
  tools/art/run.ps1 tools/art/weapons_test.py --batch armas4 --designs arm_medio_balas
"""

import argparse
import math
import time
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

import blockout
import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "parts"
# Lienzo de las armas de brazo y de las de hombro (ancho, alto).
ARM_CANVAS = (1536, 640)
TOP_CANVAS = (1024, 1024)
# Aire alrededor del bloque y ampliacion maxima.
MARGIN = 40
MAX_ZOOM = 2.0
# Detalle dentro de cada pieza (details): tamano minimo para llevarlo, en
# unidades del bloque, y grosor de sus lineas en pixeles.
DETAIL_MIN_AREA = 2200.0
DETAIL_WIDTH = 3
RIB_EVERY = 42.0
# Grados que apunta hacia arriba el canon de la artilleria.
ARTILLERY_TILT = 16.0


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def ngon(cx, cy, radius, sides=8):
    step = 2.0 * math.pi / sides
    return [(cx + radius * math.cos(step * (i + 0.5)), cy + radius * math.sin(step * (i + 0.5))) for i in range(sides)]


def turned(parts, degrees, pivot):
    """Gira las piezas alrededor de `pivot` (positivo = boca hacia arriba)."""
    angle = math.radians(-degrees)
    cos, sin = math.cos(angle), math.sin(angle)
    out = []
    for role, polygon in parts:
        moved = []
        for x, y in polygon:
            dx, dy = x - pivot[0], y - pivot[1]
            moved.append((pivot[0] + dx * cos - dy * sin, pivot[1] + dx * sin + dy * cos))
        out.append((role, moved))
    return out


def arm_base(end):
    """Hombro y cuerpo del arma hasta `end`, donde empieza el canon."""
    return [
        ("frame", ngon(0, 0, 80)),
        ("armor", [(-104, -28), (-72, -110), (30, -130), (122, -94), (98, -36), (-10, -22), (-94, 10)]),
        ("frame", [(70, 40), (end - 20, 34), (end - 52, 94), (112, 102)]),
        ("armor", [(60, -78), (end - 30, -88), (end, -44), (end - 8, 44), (84, 58), (50, 8)]),
        ("armor2", [(130, -54), (end - 62, -62), (end - 48, -12), (142, -6)]),
        ("accent", [(160, 8), (end - 60, 2), (end - 60, 20), (160, 26)]),
        ("accent", ngon(0, 0, 26)),
    ]


def barrel_balas(x0, x1, h):
    """Tres canones finos, abrazadera y bocacha."""
    parts = [("frame", rect(x0, (cy - 10) * h, x1 - 30, (cy + 10) * h)) for cy in (-42, -10, 22)]
    clamp = x0 + (x1 - x0) * 0.5
    parts.append(("armor2", rect(clamp, -62 * h, clamp + 36, 42 * h)))
    parts.append(("armor", rect(x1 - 44, -68 * h, x1, 48 * h)))
    return parts


def barrel_canon(x0, x1, h):
    """Un canon grueso con manguito de retroceso y freno de boca."""
    return [
        ("armor2", [(x0, -44 * h), (x1 - 90, -40 * h), (x1 - 90, 30 * h), (x0, 36 * h)]),
        ("armor", rect(x0 + 20, -58 * h, x0 + 96, 50 * h)),
        ("frame", rect(x1 - 92, -66 * h, x1, 56 * h)),
        ("accent", rect(x1 - 70, -16 * h, x1 - 22, 6 * h)),
    ]


def barrel_blaster(x0, x1, h):
    """Nucleo luminoso entre dos carcasas, con bobinas."""
    parts = [
        ("accent", rect(x0, -18 * h, x1 - 30, 10 * h)),
        ("armor", [(x0, -76 * h), (x1 - 64, -62 * h), (x1, -26 * h), (x0, -24 * h)]),
        ("armor", [(x0, 16 * h), (x1, 18 * h), (x1 - 64, 54 * h), (x0, 66 * h)]),
    ]
    for step in (0.25, 0.5, 0.75):
        cx = x0 + (x1 - x0) * step
        parts.append(("armor2", rect(cx - 14, -48 * h, cx + 14, 40 * h)))
    return parts


def barrel_laser(x0, x1, h):
    """Dos railes finos, canal de haz, lente y aletas de refrigeracion."""
    parts = [
        ("armor", [(x0, -52 * h), (x1, -40 * h), (x1, -26 * h), (x0, -28 * h)]),
        ("armor", [(x0, 8 * h), (x1, 0), (x1, 14 * h), (x0, 30 * h)]),
        ("accent", [(x0, -18 * h), (x1 - 20, -16 * h), (x1 - 20, -8 * h), (x0, -2 * h)]),
        ("frame", [(x1 - 54, -64 * h), (x1 + 10, -56 * h), (x1 + 10, 28 * h), (x1 - 54, 38 * h)]),
        ("accent", rect(x1 - 6, -34 * h, x1 + 10, 6 * h)),
    ]
    for fx in (x0 + 30, x0 + 76, x0 + 122):
        parts.append(("armor2", [(fx, -52 * h), (fx + 18, -98 * h), (fx + 42, -98 * h), (fx + 32, -50 * h)]))
    return parts


BARRELS = {"balas": barrel_balas, "canon": barrel_canon, "blaster": barrel_blaster, "laser": barrel_laser}


def feed(kind, end):
    """Lo que alimenta el arma, bajo el cuerpo o encima."""
    if kind == "balas":
        return [("frame", ngon(end - 150, 128, 64)), ("armor2", ngon(end - 150, 128, 24))]
    if kind == "canon":
        return [("frame", [(end - 210, 92), (end - 80, 90), (end - 92, 172), (end - 196, 174)])]
    if kind == "blaster":
        return [
            ("frame", [(140, -92), (end - 60, -100), (end - 56, -82), (146, -76)]),
            ("accent", [(150, -124), (end - 78, -130), (end - 70, -98), (156, -92)]),
        ]
    return []


def arm_gun(kind, end, tip, h, extra=()):
    def build():
        return list(extra) + feed(kind, end) + BARRELS[kind](end, tip, h) + arm_base(end)

    return build


# Mira y contrapeso del arma larga.
LONG_EXTRA = [
    ("frame", [(-160, -22), (-78, -42), (-78, 42), (-160, 30)]),
    ("armor2", [(110, -150), (322, -158), (346, -120), (104, -112)]),
    ("accent", rect(330, -150, 350, -124)),
]


def arm_blade(kind):
    def build():
        parts = []
        if kind == "balas":
            parts += [
                ("armor", [(290, -62), (700, -48), (868, 2), (700, 28), (290, 42)]),
                ("armor2", [(300, 14), (700, 6), (868, 2), (700, 28), (290, 42)]),
                ("frame", [(290, -66), (690, -52), (700, -38), (290, -44)]),
                ("frame", [(270, -88), (410, -92), (430, -54), (270, -40)]),
            ]
        elif kind == "blaster":
            parts += [
                ("accent", [(300, -42), (720, -38), (884, -4), (720, 26), (300, 34)]),
                ("armor", [(360, -64), (700, -52), (690, -34), (360, -38)]),
                ("armor", [(270, -84), (384, -90), (404, 52), (270, 62)]),
                ("armor2", [(300, -60), (360, -62), (370, 30), (300, 36)]),
            ]
        else:
            parts += [
                ("accent", [(300, -22), (900, -12), (900, -2), (300, 12)]),
                ("armor", [(300, -60), (650, -44), (650, -30), (300, -32)]),
                ("armor", [(300, 22), (650, 10), (650, 24), (300, 46)]),
                ("frame", [(270, -84), (360, -88), (372, 56), (270, 62)]),
                ("armor2", rect(430, -52, 452, 34)),
                ("armor2", rect(540, -48, 560, 28)),
            ]
        return parts + arm_base(300)

    return build


def arm_siphon(kind):
    def build():
        if kind == "blaster":
            parts = [
                ("frame", rect(320, -24, 470, 8)),
                ("accent", ngon(530, -8, 48)),
                ("armor", [(320, -70), (470, -112), (606, -72), (594, -52), (470, -80), (320, -40)]),
                ("armor", [(320, 50), (470, 92), (606, 54), (594, 36), (470, 62), (320, 22)]),
                ("armor2", rect(380, -58, 404, 42)),
                ("armor2", rect(440, -66, 462, 50)),
            ]
        else:
            parts = [
                ("frame", rect(320, -30, 490, 14)),
                ("armor2", [(540, -102), (690, -72), (690, -60), (540, -84)]),
                ("armor2", [(540, 76), (690, 50), (690, 62), (540, 92)]),
                ("armor", [(470, -102), (522, -112), (562, -62), (562, 42), (522, 94), (470, 84)]),
                ("accent", [(562, -40), (594, -30), (594, 14), (562, 24)]),
                ("armor2", rect(390, -44, 412, 28)),
            ]
        return parts + arm_base(320)

    return build


def top_base():
    """Pedestal y aro de giro; el pie del pedestal es el origen."""
    return [
        ("frame", [(-62, 0), (62, 0), (46, -72), (-46, -72)]),
        ("armor2", [(-96, -72), (96, -72), (74, -112), (-74, -112)]),
    ]


def top_pod(kind):
    def build():
        housing = [
            ("frame", [(-215, -300), (-264, -282), (-264, -180), (-215, -165)]),
            ("frame", [(-150, -112), (140, -112), (118, -84), (-128, -84)]),
            ("armor", [(-190, -330), (120, -372), (192, -340), (205, -150), (150, -112), (-170, -112), (-215, -165)]),
            ("armor2", [(-140, -296), (20, -318), (34, -160), (-140, -150)]),
            ("armor", [(-160, -352), (110, -396), (176, -364), (142, -338), (-168, -320)]),
            ("armor", [(60, -300), (176, -310), (184, -170), (70, -160)]),
            ("accent", rect(-120, -176, 10, -162)),
            ("accent", [(96, -388), (130, -394), (150, -372), (112, -366)]),
        ]
        front = []
        if kind == "balas":
            front = [("frame", rect(190, y, 520, y + 16)) for y in (-316, -286, -256, -226, -196)]
            front += [
                ("armor2", rect(320, -330, 352, -166)),
                ("armor", rect(480, -334, 524, -162)),
                ("frame", [(-120, -112), (20, -112), (30, -40), (-110, -40)]),
            ]
        elif kind == "canon":
            for y in (-348, -292, -236, -180):
                front.append(("armor2", rect(196, y, 262, y + 40)))
                front.append(("accent", rect(262, y + 8, 282, y + 32)))
            front.append(("frame", [(150, -380), (200, -420), (240, -420), (200, -340)]))
        elif kind == "blaster":
            for y in (-340, -272, -204):
                front.append(("accent", rect(196, y, 300, y + 44)))
                front.append(("armor2", rect(236, y - 8, 258, y + 52)))
            front.append(("armor", [(190, -372), (330, -360), (330, -338), (190, -340)]))
            front.append(("armor", [(190, -152), (330, -148), (330, -128), (190, -118)]))
        else:
            for y in (-338, -264, -190):
                front.append(("armor", [(196, y), (420, y + 6), (420, y + 20), (196, y + 34)]))
                front.append(("accent", rect(420, y + 4, 440, y + 24)))
            for fx in (-130, -70, -10):
                front.append(("armor2", [(fx, -372), (fx + 20, -430), (fx + 50, -430), (fx + 40, -370)]))
        return front + housing + top_base()

    return build


def turret_body():
    return [
        ("frame", [(-200, -150), (-150, -130), (-150, -230), (-200, -220)]),
        ("armor", [(-150, -112), (120, -112), (164, -172), (112, -262), (-110, -272), (-182, -200)]),
        ("armor2", [(-100, -150), (60, -150), (86, -214), (-80, -224)]),
        ("accent", rect(-70, -140, 30, -126)),
    ]


ARTILLERY_REACH = {"canon": 560, "blaster": 400, "laser": 640}
ARTILLERY_HEIGHT = {"canon": 1.15, "blaster": 1.5, "laser": 0.85}
ARTILLERY_PIVOT = (40, -196)


def top_artillery(kind):
    def build():
        barrel = BARRELS[kind](60, ARTILLERY_REACH[kind], ARTILLERY_HEIGHT[kind])
        barrel.append(("frame", ngon(40, 0, 62)))
        # El canon se dibuja horizontal desde el munon y se levanta.
        barrel = [(role, [(x, y + ARTILLERY_PIVOT[1]) for x, y in polygon]) for role, polygon in barrel]
        return turned(barrel, ARTILLERY_TILT, ARTILLERY_PIVOT) + turret_body() + top_base()

    return build


def top_anchor(kind):
    def build():
        if kind == "canon":
            launcher = [
                ("frame", ngon(-150, -196, 58)),
                ("armor2", ngon(-150, -196, 22)),
                ("armor2", rect(100, -208, 470, -186)),
                ("armor", [(440, -250), (600, -198), (440, -146), (478, -198)]),
                ("frame", rect(80, -236, 330, -158)),
                ("armor", rect(300, -246, 344, -148)),
            ]
        else:
            launcher = [
                ("accent", rect(100, -206, 520, -188)),
                ("armor", [(100, -258), (520, -236), (560, -222), (100, -226)]),
                ("armor", [(100, -168), (560, -172), (520, -156), (100, -134)]),
                ("frame", rect(80, -246, 240, -148)),
                ("armor2", rect(330, -246, 352, -150)),
                ("frame", ngon(-150, -196, 56)),
                ("accent", ngon(-150, -196, 30)),
            ]
        return launcher + turret_body() + top_base()

    return build


# Cortos a proposito: el prompt entero (estilo + sujeto + colores) tiene que
# caber en los 77 tokens de CLIP o se pierde el final, que es el fondo gris.
# Sin "weapon focus" ni "still life": con ellas salen objetos de fantasia,
# no piezas de mecha.
ARM_SUBJECT = "arm cannon, mechanical arm, armor, machinery"
TOP_SUBJECT = "shoulder cannon, turret, armor, machinery"
TYPE_TAGS = {
    "balas": "gatling gun, multiple barrels, ammunition belt",
    "canon": "cannon, thick barrel, muzzle brake",
    "blaster": "plasma cannon, glowing core, coils",
    "laser": "laser cannon, lens, glowing lines",
}
VIEW = "from side, profile, solo"
# Tambien corto: con style.NEGATIVE tiene que caber en 77 tokens.
NEGATIVE = "trigger, pistol grip, holding, hands, humanoid, firing, energy beam, lightning"
POD_TIP = {"balas": 524, "canon": 282, "blaster": 300, "laser": 440}


def _design(canvas, build, subject, tip):
    return {"canvas": canvas, "build": build, "subject": subject + ", " + VIEW, "tip": tip}


def _designs():
    out = {}
    for kind in ("balas", "canon", "blaster", "laser"):
        tags = ARM_SUBJECT + ", " + TYPE_TAGS[kind]
        out["arm_medio_" + kind] = _design(ARM_CANVAS, arm_gun(kind, 340, 650, 1.0), tags, (650, -10))
        out["arm_corto_" + kind] = _design(
            ARM_CANVAS, arm_gun(kind, 300, 520, 1.45), tags + ", short barrel", (520, -12)
        )
        out["arm_largo_" + kind] = _design(
            ARM_CANVAS, arm_gun(kind, 360, 830, 0.85, LONG_EXTRA), tags + ", long barrel, scope", (830, -10)
        )
        pod_tags = "missile pod, missile launcher" if kind == "canon" else TYPE_TAGS[kind]
        out["shoulder_bateria_" + kind] = _design(
            TOP_CANVAS, top_pod(kind), TOP_SUBJECT + ", " + pod_tags, (POD_TIP[kind], -256)
        )
    blades = {
        "balas": "arm blade, huge sword, serrated blade",
        "blaster": "arm blade, energy sword, glowing blade",
        "laser": "arm blade, beam saber, thin glowing blade",
    }
    for kind, tags in blades.items():
        subject = "mechanical arm, armor, machinery, " + tags
        out["arm_hoja_" + kind] = _design(ARM_CANVAS, arm_blade(kind), subject, (880, 0))
    siphons = {
        "blaster": "claw (weapon), tesla coil, energy orb",
        "laser": "satellite dish, antenna, lens",
    }
    for kind, tags in siphons.items():
        out["arm_saboteador_" + kind] = _design(ARM_CANVAS, arm_siphon(kind), ARM_SUBJECT + ", " + tags, (600, -8))
    angle = math.radians(ARTILLERY_TILT)
    for kind in ("canon", "blaster", "laser"):
        reach = ARTILLERY_REACH[kind] - ARTILLERY_PIVOT[0]
        tip = (ARTILLERY_PIVOT[0] + reach * math.cos(angle), ARTILLERY_PIVOT[1] - reach * math.sin(angle))
        out["shoulder_artilleria_" + kind] = _design(
            TOP_CANVAS,
            top_artillery(kind),
            TOP_SUBJECT + ", artillery, long barrel, " + TYPE_TAGS[kind],
            tip,
        )
    out["shoulder_ancla_canon"] = _design(
        TOP_CANVAS, top_anchor("canon"), TOP_SUBJECT + ", harpoon gun, harpoon, winch", (600, -198)
    )
    out["shoulder_ancla_laser"] = _design(
        TOP_CANVAS,
        top_anchor("laser"),
        TOP_SUBJECT + ", emitter, twin prongs, " + TYPE_TAGS["laser"],
        (560, -197),
    )
    return out


DESIGNS = _designs()


def placement(name):
    """Cuanto se amplia el bloque para llenar su lienzo y donde cae su union
    con el robot: (zoom, (x, y))."""
    design = DESIGNS[name]
    points = [point for _, polygon in design["build"]() for point in polygon]
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    width, height = design["canvas"]
    zoom = min(
        (width - 2 * MARGIN) / (max(xs) - min(xs)),
        (height - 2 * MARGIN) / (max(ys) - min(ys)),
        MAX_ZOOM,
    )
    origin = ((width - zoom * (max(xs) + min(xs))) / 2.0, (height - zoom * (max(ys) + min(ys))) / 2.0)
    return zoom, origin


def _area(polygon):
    total = 0.0
    for (x0, y0), (x1, y1) in zip(polygon, polygon[1:] + polygon[:1]):
        total += x0 * y1 - x1 * y0
    return abs(total) / 2.0


def _inset(polygon, factor):
    cx = sum(p[0] for p in polygon) / len(polygon)
    cy = sum(p[1] for p in polygon) / len(polygon)
    return [(cx + (x - cx) * factor, cy + (y - cy) * factor) for x, y in polygon]


def details(role, polygon):
    """Lineas de detalle de una pieza, como listas de puntos: costillas en
    lo alargado (canones y railes), filete y tornillos en las placas de
    blindaje, lamas en los paneles y refuerzos en la estructura. Sin ellas
    el bloque son pocas formas grandes y el modelo las deja planas; el
    detalle sale donde el control tiene lineas."""
    if role == "accent" or _area(polygon) < DETAIL_MIN_AREA:
        return []
    # Eje de la pieza: el de su lado mas largo.
    edges = list(zip(polygon, polygon[1:] + polygon[:1]))
    (ax, ay), (bx, by) = max(edges, key=lambda e: math.hypot(e[1][0] - e[0][0], e[1][1] - e[0][1]))
    length = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / length, (by - ay) / length
    along = [x * ux + y * uy for x, y in polygon]
    across = [-x * uy + y * ux for x, y in polygon]
    span, thick = max(along) - min(along), max(across) - min(across)

    def point(a, c):
        return (a * ux - c * uy, a * uy + c * ux)

    lines = []
    if span >= 3.2 * thick:
        count = max(2, int(span // RIB_EVERY))
        for i in range(1, count):
            a = min(along) + span * i / count
            lines.append([point(a, min(across)), point(a, max(across))])
        return lines
    if role == "armor":
        inner = _inset(polygon, 0.78)
        lines.append(inner + [inner[0]])
        for x, y in _inset(polygon, 0.62):
            lines.append([(x - 3, y), (x, y - 3), (x + 3, y), (x, y + 3), (x - 3, y)])
    elif role == "armor2":
        middle = (min(along) + max(along)) / 2.0
        for step in (-0.22, 0.0, 0.22):
            c = (min(across) + max(across)) / 2.0 + thick * step
            lines.append([point(middle - span * 0.3, c), point(middle + span * 0.3, c)])
    else:
        inner = _inset(polygon, 0.66)
        lines.append(inner + [inner[0]])
        for corner, inside in zip(polygon, inner):
            lines.append([corner, inside])
    return lines


def render(name):
    """Devuelve (bloque, control) del diseno: color plano y sus lineas."""
    design = DESIGNS[name]
    zoom, (ox, oy) = placement(name)
    palette = blockout.PALETTES["physical"]
    init = Image.new("RGB", design["canvas"], blockout.BACKGROUND)
    control = Image.new("RGB", design["canvas"], (0, 0, 0))
    draw_init, draw_control = ImageDraw.Draw(init), ImageDraw.Draw(control)
    width = blockout.LINE_WIDTH
    for role, polygon in design["build"]():
        points = [(ox + zoom * x, oy + zoom * y) for x, y in polygon]
        closed = points + [points[0]]
        draw_init.polygon(points, fill=palette[role])
        # En el control cada pieza tapa las lineas de lo que queda detras.
        draw_control.polygon(points, fill=(0, 0, 0))
        # El detalle, recortado a la pieza.
        strokes = details(role, polygon)
        if strokes:
            inside = Image.new("L", design["canvas"], 0)
            ImageDraw.Draw(inside).polygon(points, fill=255)
            layer = Image.new("L", design["canvas"], 0)
            draw_layer = ImageDraw.Draw(layer)
            for stroke in strokes:
                moved = [(ox + zoom * x, oy + zoom * y) for x, y in stroke]
                draw_layer.line(moved, fill=255, width=DETAIL_WIDTH)
            layer = ImageChops.multiply(layer, inside)
            init.paste(blockout.OUTLINE, mask=layer)
            control.paste((255, 255, 255), mask=layer)
        draw_init.line(closed, fill=blockout.OUTLINE, width=width, joint="curve")
        draw_control.line(closed, fill=(255, 255, 255), width=width, joint="curve")
    return init, control


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch", required=True)
    parser.add_argument("--designs", nargs="+", default=sorted(DESIGNS), choices=sorted(DESIGNS))
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102, 103])
    parser.add_argument("--control-scale", type=float, default=0.65)
    parser.add_argument("--control-end", type=float, default=0.5)
    parser.add_argument("--strength", type=float, default=1.0, help="menos de 1 conserva el color del bloque")
    parser.add_argument("--tag", default="", help="se anade al nombre de las imagenes")
    parser.add_argument("--blocks-only", action="store_true", help="solo guarda los bloques, sin GPU")
    args = parser.parse_args()

    out = OUT / args.batch
    out.mkdir(parents=True, exist_ok=True)
    blocks = {}
    for name in args.designs:
        blocks[name] = render(name)
        blocks[name][0].save(out / ("_bloque_%s.png" % name))
    if args.blocks_only:
        print("LISTO (solo bloques) en", out)
        return

    # Se cargan aqui para que --blocks-only no necesite la GPU.
    import torch

    import sd

    pipe = sd.load_pipeline("fp8", controlled="img2img")
    colors = style.colors_for("chassis", "physical")
    negative = style.NEGATIVE + ", " + NEGATIVE
    for name in args.designs:
        for text in (style.prompt(DESIGNS[name]["subject"], colors), negative):
            tokens = len(pipe.tokenizer(text).input_ids)
            if tokens > 77:
                raise SystemExit("prompt de %d tokens (maximo 77) en %s: %s" % (tokens, name, text))
    for name in args.designs:
        init, control = blocks[name]
        prompt = style.prompt(DESIGNS[name]["subject"], colors)
        for seed in args.seeds:
            started = time.time()
            image = pipe(
                prompt=prompt,
                negative_prompt=negative,
                image=init,
                strength=args.strength,
                control_image=[control],
                control_mode=[sd.MODE_SCRIBBLE],
                controlnet_conditioning_scale=args.control_scale,
                control_guidance_end=args.control_end,
                num_inference_steps=style.STEPS,
                guidance_scale=style.CFG,
                width=init.width,
                height=init.height,
                generator=torch.Generator("cpu").manual_seed(seed),
            ).images[0]
            file_name = "%s_%d%s.png" % (name, seed, args.tag)
            image.save(out / file_name)
            print("ok  %s  %.0f s  pico VRAM %.1f GB" % (file_name, time.time() - started, sd.peak_vram_gb()), flush=True)
    print("LISTO en", out)


if __name__ == "__main__":
    main()
