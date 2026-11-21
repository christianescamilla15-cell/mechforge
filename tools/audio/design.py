"""Diseno de sonido por capas (OBS-029: "la espada, los disparos, son muy
sencillos"). Cada efecto se arma como lo haria un disenador de sonido: varias
capas con su papel (chasquido, cuerpo, golpe grave, mecanismo, metal, cola),
saturacion, estereo y la reverberacion de un hangar. Todo se sintetiza aqui,
con semilla fija: no usa ningun archivo de fuera.

    python -P tools/audio/design.py [--only bala,rifle] [--sheet salida.png]
                                    [--out carpeta]

Escribe en assets/audio/ (OGG estereo, 44.1 kHz) los sonidos de DESIGNS; con
--out, en otra carpeta (para probar una tanda sin tocar el juego). Con
--sheet guarda ademas una lamina con la onda y el espectrograma de cada uno,
para revisarlos sin oirlos. Necesita numpy, scipy, soundfile y pedalboard
(matplotlib solo para la lamina). Volumen: el tramo mas fuerte de cada sonido
(RMS en 50 ms) a -13 dB, sin pasar de -1 dB de pico.
"""

import os
import sys

import numpy as np
import soundfile as sf
from pedalboard import HighpassFilter, Pedalboard, Reverb
from scipy.signal import butter, sosfilt

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 44100
TARGET_DB = -13.0
CEILING_DB = -1.0


# --- Piezas ---------------------------------------------------------------------


def seconds(length):
    return np.arange(int(RATE * length)) / RATE


def band(x, low=None, high=None, order=2):
    """Deja pasar entre `low` y `high` Hz (cualquiera de los dos puede faltar)."""
    top = RATE / 2 - 100
    if low and high:
        sos = butter(order, [low, min(high, top)], "bandpass", fs=RATE, output="sos")
    elif low:
        sos = butter(order, low, "highpass", fs=RATE, output="sos")
    else:
        sos = butter(order, min(high, top), "lowpass", fs=RATE, output="sos")
    return sosfilt(sos, x)


def sweep(x, freqs, q=2.5):
    """Filtro pasabanda cuyo centro se mueve (`freqs`, uno por muestra)."""
    low = band_state = 0.0
    out = np.zeros(len(x))
    damp = 1.0 / q
    for i in range(len(x)):
        f = 2.0 * np.sin(np.pi * min(freqs[i], RATE / 6.5) / RATE)
        low += f * band_state
        high = x[i] - low - damp * band_state
        band_state += f * high
        out[i] = band_state
    return out


def bell(n, peak=0.5, sharp=1.5):
    """Envolvente que sube y baja, con el maximo en `peak` (de 0 a 1)."""
    t = np.linspace(0.0, 1.0, n)
    up = np.clip(t / max(peak, 1e-6), 0.0, 1.0)
    down = np.clip((1.0 - t) / max(1.0 - peak, 1e-6), 0.0, 1.0)
    return (np.sin(0.5 * np.pi * np.minimum(up, down))) ** sharp


def modes(rng, t, base, ratios, decays, gains, drift=0.0):
    """Suma de parciales que se apagan: el timbre de un metal golpeado."""
    out = np.zeros(len(t))
    for ratio, decay, gain in zip(ratios, decays, gains):
        freq = base * ratio * (1.0 + drift * np.exp(-t / 0.05))
        phase = 2 * np.pi * np.cumsum(freq) / RATE + rng.uniform(0, 2 * np.pi)
        out += gain * np.sin(phase) * np.exp(-t / decay)
    return out


def glide(t, start, end, tau):
    """Seno cuyo tono cae de `start` a `end` Hz."""
    freq = end + (start - end) * np.exp(-t / tau)
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE)


def clicks(rng, n, count, span, tone=(2500, 7000), decay=0.004):
    """Golpecitos metalicos sueltos en el primer tramo `span` (segundos)."""
    out = np.zeros(n)
    for _ in range(count):
        at = int(rng.uniform(0, span) ** 1.0 * RATE)
        size = min(n - at, int(RATE * decay * 8))
        if size <= 8:
            continue
        t = np.arange(size) / RATE
        ping = np.sin(2 * np.pi * rng.uniform(*tone) * t) * np.exp(-t / decay)
        out[at : at + size] += ping * rng.uniform(0.3, 1.0)
    return out


def drive(x, amount):
    """Saturacion suave: junta las capas y les da densidad."""
    return np.tanh(x * amount) / np.tanh(amount)


def put(layers, length):
    """Mezcla capas [(senal mono, segundo en que entra, ganancia)]. El ultimo
    cuarto se cierra con una caida: nada se corta de golpe al acabar."""
    out = np.zeros(int(RATE * length))
    for signal, at, gain in layers:
        start = int(RATE * at)
        size = min(len(signal), len(out) - start)
        if size > 0:
            out[start : start + size] += gain * signal[:size]
    close = len(out) // 4
    out[-close:] *= np.cos(np.linspace(0.0, 0.5 * np.pi, close)) ** 2
    return out


def widen(rng, mid, side_gain, low=900):
    """Estereo: el centro igual en los dos lados y un aire distinto en cada uno."""
    n = len(mid)
    air = band(rng.standard_normal(n), low, None) * np.abs(mid) * side_gain
    delay = int(0.0004 * RATE)
    left = mid + air
    right = mid - np.concatenate([np.zeros(delay), air[: n - delay]])
    return np.stack([left, right], axis=1)


def room(stereo, size, wet, tail):
    """La sala: reflexiones de un hangar. Alarga el sonido `tail` segundos.
    Sin compresor: probado, y dejaba el golpe inicial en un zumbido plano."""
    padded = np.concatenate([stereo, np.zeros((int(RATE * tail), 2))])
    board = Pedalboard(
        [
            HighpassFilter(cutoff_frequency_hz=35.0),
            Reverb(room_size=size, damping=0.55, wet_level=wet, dry_level=1.0, width=1.0),
        ]
    )
    return board(padded.T.astype(np.float32), RATE).T.astype(np.float64)


def loudest_db(mono, window=0.05):
    """Nivel del tramo mas fuerte: el RMS mas alto en ventanas de 50 ms. Es lo
    que el oido toma por "lo fuerte que suena" un golpe con cola."""
    size = max(1, int(window * RATE))
    power = np.convolve(mono**2, np.ones(size) / size, mode="same")
    return 10 * np.log10(power.max() + 1e-12)


def finish(stereo, fade=0.08):
    """Recorta el silencio del final, cierra con una caida y nivela: el tramo
    mas fuerte a TARGET_DB y, si el pico pasa del techo, baja todo (no se
    aplasta: el golpe inicial tiene que seguir siendo un golpe)."""
    level = np.max(np.abs(stereo), axis=1)
    loud = np.nonzero(level > 10 ** (-52 / 20) * max(level.max(), 1e-9))[0]
    stereo = stereo[: loud[-1] + int(0.02 * RATE)] if len(loud) else stereo
    n = min(len(stereo), int(fade * RATE))
    stereo[-n:] *= np.linspace(1.0, 0.0, n)[:, None]
    stereo[: int(0.001 * RATE)] *= np.linspace(0.0, 1.0, int(0.001 * RATE))[:, None]
    gain = 10 ** ((TARGET_DB - loudest_db(stereo.mean(axis=1))) / 20)
    ceiling = 10 ** (CEILING_DB / 20)
    gain = min(gain, ceiling / max(np.abs(stereo).max(), 1e-9))
    return stereo * gain


# --- Recetas ---------------------------------------------------------------------


def clack(rng, tone):
    """Un golpe de mecanismo: cerrojo, corredera, eslabon."""
    t = seconds(0.07)
    metal = modes(rng, t, tone, [1, 1.83, 2.71, 3.9], [0.014, 0.01, 0.008, 0.006],
                  [1, 0.7, 0.5, 0.35])
    return metal + 0.7 * band(rng.standard_normal(len(t)), 1800, 7000) * np.exp(-t / 0.005)


def gunshot(seed, crack=1.0, body=1.0, thump=1.0, body_tau=0.035, low=(160, 1700),
            thump_hz=(170, 60), thump_tau=0.05, ring_hz=1500, mech=(), tail=0.2,
            room_size=0.35, wet=0.14, bright=5200, length=0.45):
    """Un disparo de bala. Capas: chasquido (el aire que rompe la bala),
    cuerpo (la explosion en la boca), golpe grave (el pecho), tubo (el canon
    que resuena), mecanismo (cerrojo, corredera) y cola (el eco)."""
    rng = np.random.default_rng(seed)
    t = seconds(length)
    n = len(t)
    snap = band(rng.standard_normal(n), 2600, None, 3) * np.exp(-t / 0.004)
    blast = band(rng.standard_normal(n), low[0], low[1], 2) * np.exp(-t / body_tau)
    punch = glide(t, thump_hz[0], thump_hz[1], 0.02) * np.exp(-t / thump_tau)
    tube = modes(rng, t, ring_hz, [1, 1.47, 2.09, 2.9], [0.045, 0.035, 0.028, 0.02],
                 [0.5, 0.35, 0.25, 0.15])
    hiss = band(rng.standard_normal(n), 300, bright, 2) * np.exp(-t / tail)
    # El golpe se satura (las tres capas pegadas suenan a una sola explosion);
    # el tubo, la cola y el mecanismo van limpios por encima.
    hit = drive(put([(snap, 0, 1.2 * crack), (blast, 0, 1.6 * body),
                     (punch, 0, 1.2 * thump)], length), 1.5)
    layers = [(hit, 0.0, 1.0), (tube, 0.002, 0.16), (hiss, 0.006, 0.1)]
    for at, tone, gain in mech:
        layers.append((clack(rng, tone), at, gain))
    dry = put(layers, length)
    return finish(room(widen(rng, dry, 0.3), room_size, wet, tail * 2.0 + 0.2))


def blade_swing(seed, pitch=1.0, length=0.46):
    """El tajo de la hoja vibratoria. Capas: el aire que corta (un silbido
    cuyo tono sube y baja), el motor que la hace vibrar, el filo que canta y
    el chasquido del aire en el punto mas rapido."""
    rng = np.random.default_rng(seed)
    t = seconds(length)
    n = len(t)
    arc = bell(n, 0.45, 1.6)
    center = (380 + 2900 * bell(n, 0.45, 1.3)) * pitch
    whoosh = sweep(rng.standard_normal(n), center, 4.5) * arc
    breath = sweep(rng.standard_normal(n), center * 2.3, 2.0) * arc**2
    hum_freq = 132 * pitch * (1.0 + 0.6 * bell(n, 0.45, 1.0))
    saw = 2.0 * ((np.cumsum(hum_freq) / RATE) % 1.0) - 1.0
    motor = band(saw, 200, 2600) * arc * (0.55 + 0.45 * np.sin(2 * np.pi * 34 * t))
    start = 0.4 * length
    ring_t = seconds(0.42)
    edge = modes(rng, ring_t, 2250 * pitch, [1, 1.52, 2.37, 3.44, 4.93],
                 [0.11, 0.09, 0.075, 0.06, 0.045], [0.6, 0.5, 0.4, 0.3, 0.2], drift=0.03)
    edge *= np.minimum(1.0, ring_t / 0.012)
    snap = band(rng.standard_normal(n), 5500, None) * bell(n, 0.45, 18.0)
    mid = put([(whoosh, 0, 0.5), (breath, 0, 0.2), (motor, 0, 0.6), (snap, 0, 0.45)], length)
    mid = np.concatenate([mid, np.zeros(int(RATE * 0.3))])
    mid = mid / max(np.abs(mid).max(), 1e-9)
    size = min(len(edge), len(mid) - int(RATE * start))
    mid[int(RATE * start) : int(RATE * start) + size] += 0.22 * edge[:size]
    # El tajo cruza de un lado al otro.
    pan = np.linspace(-0.6, 0.6, len(mid))
    stereo = np.stack([mid * np.sqrt(0.5 * (1 - pan)), mid * np.sqrt(0.5 * (1 + pan))], axis=1)
    return finish(room(stereo, 0.3, 0.1, 0.35))


def blade_hit(seed, pitch=1.0, length=0.85):
    """El filo que entra en el blindaje. Capas: el corte, el golpe grave, la
    chapa que suena, el desgarro del metal y las chispas."""
    rng = np.random.default_rng(seed)
    t = seconds(length)
    n = len(t)
    cut = band(rng.standard_normal(n), 3500, None, 3) * np.exp(-t / 0.005)
    thud = glide(t, 175 * pitch, 60, 0.025) * np.exp(-t / 0.06)
    plate = modes(rng, t, 640 * pitch, [1, 2.76, 5.4, 8.93, 11.3],
                  [0.17, 0.13, 0.1, 0.07, 0.05], [1, 0.7, 0.5, 0.3, 0.2], drift=0.02)
    grain = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 94 * t + rng.uniform(0, 6)))
    tear = band(rng.standard_normal(n), 1400, 5200) * grain * np.exp(-t / 0.05)
    sparks = clicks(rng, n, 16, 0.28, (4200, 9500), 0.0025) * np.exp(-t / 0.14)
    hit = drive(put([(cut, 0, 1.1), (thud, 0, 1.3), (tear, 0.003, 0.8)], length), 1.6)
    dry = put([(hit, 0, 1.0), (plate, 0.001, 0.3), (sparks, 0.02, 0.22)], length)
    return finish(room(widen(rng, dry, 0.4), 0.4, 0.16, 0.5))


def bullet_hit(seed, pitch=1.0, whine=0.0, length=0.5):
    """Una bala contra el blindaje. Capas: el golpe seco, la chapa que suena,
    las esquirlas y, a veces, el silbido de la bala que rebota."""
    rng = np.random.default_rng(seed)
    t = seconds(length)
    n = len(t)
    tick = band(rng.standard_normal(n), 2800, None, 3) * np.exp(-t / 0.003)
    thud = glide(t, 220 * pitch, 85, 0.018) * np.exp(-t / 0.035)
    base = rng.uniform(1250, 2100) * pitch
    plate = modes(rng, t, base, [1, 1.63, 2.42, 3.71], [0.09, 0.07, 0.05, 0.035],
                  [1, 0.6, 0.45, 0.3], drift=0.015)
    chips = clicks(rng, n, 7, 0.16, (3800, 9000), 0.002) * np.exp(-t / 0.09)
    hit = drive(put([(tick, 0, 1.2), (thud, 0, 1.0)], length), 1.5)
    layers = [(hit, 0, 1.0), (plate, 0.0008, 0.32), (chips, 0.012, 0.2)]
    if whine > 0.0:
        vib = 1.0 + 0.012 * np.sin(2 * np.pi * 37 * t)
        freq = (1300 + 2400 * np.exp(-t / 0.09)) * vib * pitch
        zing = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * bell(n, 0.1, 1.0)
        layers.append((zing, 0.01, 0.16 * whine))
    dry = put(layers, length)
    return finish(room(widen(rng, dry, 0.35), 0.3, 0.12, 0.35))


# Cada sonido: (archivo, receta, parametros).
DESIGNS = [
    # Ametralladora: nueve balas seguidas, asi que cada una es corta y seca.
    ("armas/bala_1", gunshot, {"seed": 11, "length": 0.22, "tail": 0.07, "wet": 0.08,
                                "thump_hz": (200, 78), "thump_tau": 0.03, "body_tau": 0.025,
                                "mech": [(0.05, 2900, 0.12)]}),
    ("armas/bala_2", gunshot, {"seed": 23, "length": 0.22, "tail": 0.065, "wet": 0.08,
                                "thump_hz": (210, 82), "thump_tau": 0.03, "body_tau": 0.025,
                                "ring_hz": 1620, "mech": [(0.055, 3200, 0.11)]}),
    ("armas/bala_3", gunshot, {"seed": 37, "length": 0.22, "tail": 0.075, "wet": 0.08,
                                "thump_hz": (190, 74), "thump_tau": 0.03, "body_tau": 0.025,
                                "ring_hz": 1410, "mech": [(0.047, 2700, 0.13)]}),
    ("armas/bala_4", gunshot, {"seed": 41, "length": 0.22, "tail": 0.07, "wet": 0.08,
                                "thump_hz": (205, 80), "thump_tau": 0.03, "body_tau": 0.025,
                                "ring_hz": 1550, "mech": [(0.052, 3050, 0.12)]}),
    # Rifle: un solo tiro, seco y largo, con su eco y el cerrojo despues.
    ("armas/rifle", gunshot, {"seed": 53, "crack": 1.5, "body": 1.1, "thump": 1.2,
                               "body_tau": 0.045, "ring_hz": 1150, "tail": 0.3,
                               "room_size": 0.62, "wet": 0.22, "length": 0.9,
                               "mech": [(0.42, 2100, 0.22), (0.55, 2600, 0.18)]}),
    # Escopeta: mas cuerpo y mas grave, y la corredera al final.
    ("armas/escopeta", gunshot, {"seed": 67, "crack": 0.9, "body": 1.5, "thump": 1.6,
                                  "body_tau": 0.065, "low": (110, 1300),
                                  "thump_hz": (135, 46), "thump_tau": 0.08, "ring_hz": 820,
                                  "tail": 0.24, "room_size": 0.5, "wet": 0.2,
                                  "bright": 3800, "length": 0.95,
                                  "mech": [(0.48, 1500, 0.24), (0.63, 1900, 0.22)]}),
    # La hoja vibratoria: tres tajos algo distintos.
    ("armas/tajo_metal_1", blade_swing, {"seed": 71}),
    ("armas/tajo_metal_2", blade_swing, {"seed": 73, "pitch": 0.93, "length": 0.5}),
    ("armas/tajo_metal_3", blade_swing, {"seed": 79, "pitch": 1.07, "length": 0.43}),
    # El filo contra el blindaje.
    ("impactos/tajo_1", blade_hit, {"seed": 83}),
    ("impactos/tajo_2", blade_hit, {"seed": 89, "pitch": 0.9}),
    ("impactos/tajo_3", blade_hit, {"seed": 97, "pitch": 1.12}),
    # Las balas contra el blindaje; una de cada tres rebota silbando.
    ("impactos/chispas_1", bullet_hit, {"seed": 101}),
    ("impactos/chispas_2", bullet_hit, {"seed": 103, "pitch": 1.1}),
    ("impactos/chispas_3", bullet_hit, {"seed": 107, "pitch": 0.92, "whine": 1.0}),
]


def write(rel, stereo, folder=OUT):
    path = os.path.join(folder, rel + ".ogg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, stereo.astype(np.float32), RATE, format="OGG", subtype="VORBIS")
    return path


def sheet(sounds, path):
    """Envolvente en dB y espectrograma de cada sonido, para revisarlos
    mirando: un golpe tiene que subir en nada y caer deprisa."""
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    cols = 3
    rows = (len(sounds) + cols - 1) // cols
    fig, axes = plt.subplots(rows * 2, cols, figsize=(cols * 5.2, rows * 3.4), squeeze=False)
    for index, (rel, stereo) in enumerate(sounds):
        mono = stereo.mean(axis=1)
        curve = axes[(index // cols) * 2][index % cols]
        spec = axes[(index // cols) * 2 + 1][index % cols]
        size = int(0.004 * RATE)
        power = np.convolve(mono**2, np.ones(size) / size, mode="same")
        curve.plot(np.arange(len(mono)) / RATE, 10 * np.log10(power + 1e-12), linewidth=0.7)
        curve.set_title("%s  %.2f s" % (rel, len(mono) / RATE), fontsize=9)
        curve.set_ylim(-70, 0)
        curve.grid(alpha=0.3)
        pxx, freqs, bins = matplotlib.mlab.specgram(mono + 1e-9, NFFT=512, Fs=RATE, noverlap=384)[:3]
        level = 10 * np.log10(pxx + 1e-18)
        spec.pcolormesh(bins, freqs, level, cmap="magma", vmin=level.max() - 80, vmax=level.max())
        spec.set_ylim(0, 12000)
    for index in range(len(sounds), rows * cols):
        axes[(index // cols) * 2][index % cols].axis("off")
        axes[(index // cols) * 2 + 1][index % cols].axis("off")
    fig.tight_layout()
    fig.savefig(path, dpi=70)


def main():
    only = []
    out_sheet = ""
    folder = OUT
    args = sys.argv[1:]
    for i, arg in enumerate(args):
        if arg == "--only" and i + 1 < len(args):
            only = args[i + 1].split(",")
        if arg == "--sheet" and i + 1 < len(args):
            out_sheet = args[i + 1]
        if arg == "--out" and i + 1 < len(args):
            folder = args[i + 1]
    made = []
    for rel, recipe, params in DESIGNS:
        if only and not any(key in rel for key in only):
            continue
        stereo = recipe(**params)
        write(rel, stereo, folder)
        made.append((rel, stereo))
        peak = 20 * np.log10(np.abs(stereo).max() + 1e-12)
        side = stereo[:, 0] - stereo[:, 1]
        width = np.sqrt(np.mean(side**2)) / (np.sqrt(np.mean(stereo.mean(axis=1) ** 2)) + 1e-12)
        print("%-24s %5.2f s  pico %5.1f dB  ancho %.2f" % (rel, len(stereo) / RATE, peak, width))
    if out_sheet and made:
        sheet(made, out_sheet)
        print("lamina: %s" % out_sheet)


if __name__ == "__main__":
    sys.stdout.reconfigure(line_buffering=True)
    main()
