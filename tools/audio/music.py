"""Musica del juego, generada en local con ACE-Step 1.5 (OBS-028).

Del usuario (2026-11-20): "el apartado de la musica deja mucho que desear.
Creo que ahi tiene que estar al nivel de lo que estamos haciendo". El
generador (codigo abierto, licencia MIT) corre en la GPU de este equipo, sin
nube; lo aprobo el 2026-11-21. Esta en ACE_ROOT y tiene su propio entorno.

Por cada pista genera una o varias versiones (una por semilla), les quita la
entrada, las cierra en un bucle de compases enteros que empalma sin corte y
las deja en OGG al mismo volumen. Tambien imprime sus medidas, porque quien
las genera no las puede oir: duracion, compases, nivel, pico, cuanto se
parece el final al principio y lo marcado que esta el pulso.

Uso (con el Python del generador, no el del sistema):
  C:\\Users\\DANNY\\dev\\tools\\mechforge-audio-acestep\\.venv\\Scripts\\python.exe \\
      tools/audio/music.py --only base combate --seeds 11 12
Las pistas van a art_raw/audio/musica/ (carpeta ignorada por git); la elegida
se copia a assets/audio/musica/ con --install base=11.
"""

import argparse
import shutil
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

ROOT = Path(__file__).resolve().parents[2]
ACE_ROOT = Path(r"C:\Users\DANNY\dev\tools\mechforge-audio-acestep")
OUT = ROOT / "art_raw" / "audio" / "musica"
GAME = ROOT / "assets" / "audio" / "musica"
MODEL = "acestep-v15-turbo"

# Nivel de las pistas en su archivo (RMS, dBFS) y pico maximo. El volumen con
# el que suenan en el juego lo pone data/sounds.json.
TARGET_RMS_DB = -16.0
PEAK_DB = -1.0

# Cada pista: lo que se le pide al modelo, su tempo, su tono y cuanto dura lo
# que se genera (el bucle sale algo mas corto: se le quita la entrada).
STYLE = "instrumental, no vocals, mecha anime soundtrack, clean modern mix"
TRACKS = {
    # El hangar: calma de taller, con pulso; se oye mucho rato.
    "base": {
        "caption": (
            "atmospheric synthwave, warm analog pads, slow steady electronic drums, deep bass, "
            "soft arpeggio, distant metallic percussion, hopeful hangar theme, " + STYLE
        ),
        "bpm": 92,
        "key": "D minor",
        "duration": 120,
    },
    # El combate: empuje, guitarras y sintetizador.
    "combate": {
        "caption": (
            "driving electronic rock, distorted rhythm guitars, punchy drums, pulsing synth bass, "
            "heroic lead synth melody, energetic battle theme, " + STYLE
        ),
        "bpm": 140,
        "key": "E minor",
        "duration": 110,
    },
    # El campeon de la liga: lo mismo, mas grande y mas oscuro.
    "jefe": {
        "caption": (
            "epic hybrid orchestral metal, pounding taiko drums, heavy distorted guitars, dark choir pads, "
            "brass stabs, fast tempo, intense boss battle theme, " + STYLE
        ),
        "bpm": 152,
        "key": "C minor",
        "duration": 110,
    },
}


def db(value):
    return 20.0 * np.log10(max(float(value), 1e-9))


def envelope(mono, rate, out_rate=200):
    """Energia de la senal, suavizada y a pocos puntos por segundo."""
    b, a = signal.butter(2, 20.0 / (rate / 2.0))
    smooth = signal.filtfilt(b, a, np.abs(mono))
    return smooth[:: rate // out_rate], out_rate


def pulse_strength(mono, rate, bpm):
    """Cuanto se repite la energia de la pista cada pulso (0 a 1)."""
    env, env_rate = envelope(mono, rate)
    env = env - env.mean()
    lag = int(round(env_rate * 60.0 / bpm))
    if lag <= 0 or lag >= len(env):
        return 0.0
    num = float(np.dot(env[:-lag], env[lag:]))
    den = float(np.dot(env, env)) + 1e-12
    return max(0.0, num / den)


def seamless_loop(audio, rate, bpm, lead_bars=4, fade_beats=2.0, search=0.25):
    """Corta un bucle de compases enteros que empalma sin salto.

    Se salta la entrada (`lead_bars`), toma el mayor numero de compases
    (multiplo de 4) que cabe, ajusta el largo unas centesimas para que el
    final caiga donde la energia se parece mas a la del principio, y funde
    el final con lo que sonaba justo antes del principio: asi el final lleva
    de vuelta al comienzo. Devuelve (bucle, compases, parecido).
    """
    beat = 60.0 / bpm
    bar = 4.0 * beat
    start = int(round(lead_bars * bar * rate))
    total = len(audio) / rate
    bars = int((total - lead_bars * bar - bar) // bar)
    bars -= bars % 4
    if bars < 8:
        raise ValueError("la pista es demasiado corta para un bucle (%d compases)" % bars)
    length = int(round(bars * bar * rate))
    mono = audio.mean(axis=1)
    env, env_rate = envelope(mono, rate)
    window = int(env_rate * 4.0)
    head = env[start * env_rate // rate :][:window]
    head = head - head.mean()
    best_shift, best_score = 0, -2.0
    for shift in range(-int(search * env_rate), int(search * env_rate) + 1):
        at = (start + length) * env_rate // rate + shift
        tail = env[at : at + window]
        if len(tail) < window:
            continue
        tail = tail - tail.mean()
        score = float(np.dot(head, tail) / (np.linalg.norm(head) * np.linalg.norm(tail) + 1e-12))
        if score > best_score:
            best_shift, best_score = shift, score
    length += best_shift * rate // env_rate
    loop = audio[start : start + length].copy()
    fade = int(round(fade_beats * beat * rate))
    ramp = np.linspace(0.0, 1.0, fade)[:, None]
    before = audio[start - fade : start]
    loop[-fade:] = loop[-fade:] * np.cos(ramp * np.pi / 2.0) + before * np.sin(ramp * np.pi / 2.0)
    return loop, bars, best_score


def level(audio):
    """Lleva la pista a TARGET_RMS_DB sin pasar de PEAK_DB."""
    rms = np.sqrt(float((audio**2).mean()))
    gain = 10.0 ** ((TARGET_RMS_DB - db(rms)) / 20.0)
    peak = float(np.abs(audio).max()) * gain
    limit = 10.0 ** (PEAK_DB / 20.0)
    if peak > limit:
        gain *= limit / peak
    return audio * gain


def measures(audio, rate, bpm):
    mono = audio.mean(axis=1)
    rms = np.sqrt(float((audio**2).mean()))
    # Tramos de un segundo casi en silencio: una pista con huecos no sirve.
    seconds = len(mono) // rate
    quiet = sum(1 for i in range(seconds) if db(np.sqrt((mono[i * rate : (i + 1) * rate] ** 2).mean())) < db(rms) - 20.0)
    spectrum = np.abs(np.fft.rfft(mono[: rate * 30]))
    freqs = np.fft.rfftfreq(rate * 30, 1.0 / rate)
    centroid = float((spectrum * freqs).sum() / (spectrum.sum() + 1e-12))
    return {
        "rms": db(rms),
        "peak": db(np.abs(audio).max()),
        "quiet": quiet,
        "centroid": centroid,
        "pulse": pulse_strength(mono, rate, bpm),
    }


def load_generator():
    sys.path.insert(0, str(ACE_ROOT))
    from acestep.handler import AceStepHandler
    from acestep.inference import GenerationConfig, GenerationParams, generate_music

    handler = AceStepHandler()
    # 6 GB de VRAM: pesos en 8 bits y lo que no se usa, en la RAM.
    status, ok = handler.initialize_service(
        project_root=str(ACE_ROOT),
        config_path=MODEL,
        device="cuda",
        offload_to_cpu=True,
        quantization="int8_weight_only",
    )
    if not ok:
        raise SystemExit("el generador no arranco: %s" % status)
    return handler, GenerationParams, GenerationConfig, generate_music


def generate(tools, name, seed, raw_dir):
    handler, params_type, config_type, generate_music = tools
    spec = TRACKS[name]
    params = params_type(
        task_type="text2music",
        caption=spec["caption"],
        lyrics="[Instrumental]",
        instrumental=True,
        bpm=spec["bpm"],
        keyscale=spec["key"],
        timesignature="4",
        duration=float(spec["duration"]),
        inference_steps=8,
        shift=3.0,
        seed=seed,
        thinking=False,
    )
    config = config_type(batch_size=1, use_random_seed=False, seeds=[seed], audio_format="wav")
    result = generate_music(handler, None, params, config, save_dir=str(raw_dir))
    if not result.success or not result.audios:
        raise SystemExit("no se genero %s (semilla %d): %s" % (name, seed, result.error))
    return Path(result.audios[0]["path"])


def finish(name, seed, raw_path):
    audio, rate = sf.read(raw_path, always_2d=True)
    if audio.shape[1] == 1:
        audio = np.repeat(audio, 2, axis=1)
    bpm = TRACKS[name]["bpm"]
    loop, bars, match = seamless_loop(audio, rate, bpm)
    loop = level(loop)
    out = OUT / ("%s_%d.ogg" % (name, seed))
    sf.write(out, loop, rate, format="OGG", subtype="VORBIS")
    m = measures(loop, rate, bpm)
    print(
        "ok  %s  %.1f s  %d compases a %d  nivel %.1f dB  pico %.1f dB  empalme %.2f  pulso %.2f  "
        "centro %.0f Hz  segundos casi mudos %d"
        % (out.name, len(loop) / rate, bars, bpm, m["rms"], m["peak"], match, m["pulse"], m["centroid"], m["quiet"]),
        flush=True,
    )
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", nargs="+", choices=sorted(TRACKS), default=sorted(TRACKS))
    parser.add_argument("--seeds", type=int, nargs="+", default=[11])
    parser.add_argument("--redo", action="store_true", help="vuelve a cerrar el bucle de lo ya generado, sin la GPU")
    parser.add_argument("--install", nargs="+", metavar="PISTA=SEMILLA", help="copia al juego la version elegida")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    raw_dir = OUT / "crudo"
    raw_dir.mkdir(exist_ok=True)
    if args.install:
        for pair in args.install:
            name, seed = pair.split("=")
            shutil.copyfile(OUT / ("%s_%s.ogg" % (name, seed)), GAME / (name + ".ogg"))
            print("instalada %s (semilla %s) en %s" % (name, seed, GAME))
        return
    tools = None if args.redo else load_generator()
    for name in args.only:
        for seed in args.seeds:
            raw = raw_dir / ("%s_%d.wav" % (name, seed))
            if not args.redo:
                started = time.time()
                made = generate(tools, name, seed, raw_dir)
                shutil.move(str(made), raw)
                print("generada %s en %.0f s" % (raw.name, time.time() - started), flush=True)
            finish(name, seed, raw)
    print("LISTO en", OUT)


if __name__ == "__main__":
    main()
