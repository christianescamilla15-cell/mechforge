"""Sonido del juego (PLAN F9): de los paquetes CC0 descargados a assets/audio.

    python -P tools/audio/curate.py [--fetch]

--fetch descarga los paquetes de SOURCES en art_raw/audio/src/<paquete>/ (que
no se sube al repo) y extrae solo el audio. Despues, cada sonido de CLIPS se
recorta, se le pone una caida suave, se iguala su volumen (RMS de la parte que
suena) sin pasar de -1 dB de pico y se guarda en OGG en assets/audio/. Los
disparos de bala, la hoja vibratoria y sus impactos se disenan por capas en
tools/audio/design.py, que es quien escribe esos archivos.

Escribe tambien assets/audio/CREDITOS.md con la fuente, el autor y la licencia
de cada archivo. Todo es CC0 (dominio publico) o sintetizado aqui.
Necesita numpy, scipy y soundfile.
"""

import io
import json
import os
import sys
import urllib.request
import zipfile

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art_raw", "audio", "src")
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 44100

# Paquetes: pagina, archivo, autor y licencia (comprobados en su pagina el
# 2026-11-18). Kenney rechaza las descargas automaticas desde kenney.nl, asi
# que se usan las copias que el propio Kenney subio a OpenGameArt.
SOURCES = {
    "kenney_scifi": {
        "name": "Sci-fi Sounds",
        "author": "Kenney (kenney.nl)",
        "page": "https://opengameart.org/content/sci-fi-sounds",
        "file": "https://opengameart.org/sites/default/files/sci-fi_sounds.zip",
    },
    "kenney_interface": {
        "name": "Interface Sounds",
        "author": "Kenney (kenney.nl)",
        "page": "https://opengameart.org/content/interface-sounds",
        "file": "https://opengameart.org/sites/default/files/kenney_interfaceSounds.zip",
    },
    "kenney_digital": {
        "name": "63 Digital sound effects",
        "author": "Kenney (kenney.nl)",
        "page": "https://opengameart.org/node/12493",
        "file": "https://opengameart.org/sites/default/files/Digital_SFX_Set.zip",
    },
    "rubberduck_100": {
        "name": "100 CC0 SFX",
        "author": "rubberduck",
        "page": "https://opengameart.org/content/100-cc0-sfx",
        "file": "https://opengameart.org/sites/default/files/100-CC0-SFX_0.zip",
    },
    "music_dark_scifi": {
        "name": "Dark Sci-Fi Audio Pack",
        "author": "SRG774",
        "page": "https://opengameart.org/content/dark-sci-fi-audio-pack",
        "file": "https://opengameart.org/sites/default/files/ogg.zip",
    },
    "music_space_battle": {
        "name": "Space Battle",
        "author": "MintoDog",
        "page": "https://opengameart.org/content/space-battle",
        "file": "https://opengameart.org/sites/default/files/space_battle_bpm130_0.ogg",
    },
    "music_robotic_battlefield": {
        "name": "Friendly Talk On a Robotic Battlefield (Looped)",
        "author": "illin",
        "page": "https://opengameart.org/content/friendly-talk-on-a-robotic-battlefield-looped",
        "file": "https://opengameart.org/sites/default/files/"
        "Friendly%20Talk%20On%20a%20Robotic%20Battlefield_0.ogg",
    },
}

# Volumen de referencia (RMS de la parte que suena, en dBFS) por tipo.
TARGET = {"sfx": -18.0, "ui": -22.0, "music": -20.0, "jingle": -17.0}
CEILING_DB = -1.0

# Cada recorte: (archivo de salida, paquete, archivo de origen, desde (s),
# duracion maxima (s) o None, caida final (s), tipo). El tipo fija el volumen.
CLIPS = [
    # Interfaz.
    ("ui/clic_1", "kenney_interface", "click_002.ogg", 0, None, 0, "ui"),
    ("ui/clic_2", "kenney_interface", "click_003.ogg", 0, None, 0, "ui"),
    ("ui/clic_3", "kenney_interface", "click_005.ogg", 0, None, 0, "ui"),
    ("ui/abrir", "kenney_interface", "maximize_007.ogg", 0, None, 0, "ui"),
    ("ui/cerrar", "kenney_interface", "minimize_007.ogg", 0, None, 0, "ui"),
    ("ui/tic", "kenney_interface", "tick_004.ogg", 0, None, 0, "ui"),
    ("ui/comprar", "kenney_interface", "confirmation_002.ogg", 0, None, 0, "ui"),
    ("ui/subir_nivel", "kenney_digital", "powerUp7.mp3", 0, None, 0.05, "ui"),
    ("ui/transformar", "kenney_digital", "powerUp3.mp3", 0, None, 0.1, "ui"),
    ("ui/habilidad", "kenney_digital", "zapThreeToneUp.mp3", 0, None, 0.1, "ui"),
    # Disparos.
    ("armas/canon_1", "kenney_scifi", "explosionCrunch_002.ogg", 0, 0.9, 0.3, "sfx"),
    ("armas/canon_pesado", "kenney_scifi", "lowFrequency_explosion_001.ogg", 0, None, 0.2, "sfx"),
    ("armas/lanzador", "kenney_scifi", "impactMetal_001.ogg", 0, 0.5, 0.2, "sfx"),
    ("armas/misil", "kenney_scifi", "thrusterFire_003.ogg", 0.9, 0.7, 0.3, "sfx"),
    ("armas/bomba_cae", "kenney_digital", "phaserDown1.mp3", 0, None, 0.05, "sfx"),
    ("armas/plasma_1", "kenney_scifi", "laserRetro_000.ogg", 0, None, 0.03, "sfx"),
    ("armas/plasma_2", "kenney_scifi", "laserRetro_001.ogg", 0, None, 0.03, "sfx"),
    ("armas/plasma_3", "kenney_scifi", "laserRetro_003.ogg", 0, None, 0.03, "sfx"),
    ("armas/plasma_grande", "kenney_scifi", "laserLarge_001.ogg", 0, None, 0.1, "sfx"),
    ("armas/plasma_chorro", "kenney_scifi", "thrusterFire_000.ogg", 0.9, 0.6, 0.25, "sfx"),
    ("armas/plasma_mortero", "kenney_digital", "phaserUp1.mp3", 0, None, 0.05, "sfx"),
    ("armas/plasma_nova", "kenney_scifi", "forceField_000.ogg", 0, None, 0.2, "sfx"),
    ("armas/laser_fino_1", "kenney_scifi", "laserSmall_000.ogg", 0, None, 0.03, "sfx"),
    ("armas/laser_fino_2", "kenney_scifi", "laserSmall_002.ogg", 0, None, 0.03, "sfx"),
    ("armas/laser_fino_3", "kenney_scifi", "laserSmall_004.ogg", 0, None, 0.03, "sfx"),
    ("armas/laser_grueso_1", "kenney_scifi", "laserLarge_000.ogg", 0, None, 0.1, "sfx"),
    ("armas/laser_grueso_2", "kenney_scifi", "laserLarge_003.ogg", 0, None, 0.1, "sfx"),
    ("armas/laser_grueso_3", "kenney_scifi", "laserLarge_004.ogg", 0, None, 0.1, "sfx"),
    ("armas/laser_nova", "kenney_scifi", "laserLarge_002.ogg", 0, None, 0.1, "sfx"),
    ("armas/tractor", "kenney_scifi", "forceField_001.ogg", 0, None, 0.2, "sfx"),
    ("armas/sifon", "kenney_scifi", "engineCircular_000.ogg", 0, 0.9, 0.35, "sfx"),
    ("armas/repulsor", "kenney_scifi", "forceField_002.ogg", 0, None, 0.2, "sfx"),
    ("armas/arpon", "rubberduck_100", "spring_03.ogg", 0, None, 0.1, "sfx"),
    ("armas/tajo_plasma", "kenney_scifi", "laserRetro_004.ogg", 0, None, 0.05, "sfx"),
    ("armas/tajo_luz", "kenney_scifi", "laserSmall_004.ogg", 0, None, 0.05, "sfx"),
    # Impactos segun lo que deja el disparo, y segun el tamano del arma.
    ("impactos/explosion_1", "kenney_scifi", "explosionCrunch_001.ogg", 0, None, 0.4, "sfx"),
    ("impactos/explosion_2", "kenney_scifi", "explosionCrunch_003.ogg", 0, None, 0.4, "sfx"),
    ("impactos/explosion_3", "kenney_scifi", "explosionCrunch_004.ogg", 0, 1.4, 0.5, "sfx"),
    ("impactos/plasma", "kenney_scifi", "slime_000.ogg", 0, None, 0.1, "sfx"),
    ("impactos/quemadura", "rubberduck_100", "noise_01.ogg", 0, None, 0.15, "sfx"),
    ("impactos/drenaje", "kenney_scifi", "computerNoise_002.ogg", 0, 0.5, 0.2, "sfx"),
    ("impactos/onda", "kenney_scifi", "forceField_004.ogg", 0, None, 0.2, "sfx"),
    ("impactos/medio", "rubberduck_100", "slam_03.ogg", 0, None, 0.1, "sfx"),
    ("impactos/grave", "kenney_scifi", "lowFrequency_explosion_001.ogg", 0, None, 0.2, "sfx"),
    ("impactos/ultimo", "kenney_scifi", "lowFrequency_explosion_000.ogg", 0, None, 0.6, "sfx"),
    # Movimiento y estados.
    ("mech/paso", "kenney_scifi", "impactMetal_001.ogg", 0, 0.35, 0.15, "sfx"),
    ("mech/pisoton", "rubberduck_100", "slam_02.ogg", 0, None, 0.1, "sfx"),
    ("mech/propulsor", "kenney_scifi", "thrusterFire_002.ogg", 1.0, 0.5, 0.25, "sfx"),
    ("mech/salto", "kenney_digital", "phaseJump1.mp3", 0, None, 0.05, "sfx"),
    ("mech/esquiva", "kenney_digital", "phaseJump3.mp3", 0, None, 0.05, "sfx"),
    ("mech/enfriar", "kenney_scifi", "thrusterFire_004.ogg", 1.0, 0.8, 0.4, "sfx"),
    ("mech/apagado", "kenney_digital", "lowDown.mp3", 0, None, 0.1, "sfx"),
    ("mech/critico", "kenney_digital", "highUp.mp3", 0, None, 0.05, "sfx"),
    ("mech/escudo", "kenney_scifi", "forceField_003.ogg", 0, None, 0.2, "sfx"),
    ("mech/reparar", "kenney_digital", "powerUp5.mp3", 0, None, 0.05, "sfx"),
    ("mech/nave", "kenney_scifi", "spaceEngine_001.ogg", 0, 1.6, 0.6, "sfx"),
    ("mech/bonificacion", "kenney_digital", "powerUp8.mp3", 0, None, 0.05, "sfx"),
    ("mech/destruido", "kenney_scifi", "explosionCrunch_004.ogg", 0, None, 0.6, "sfx"),
    ("mech/despliegue", "kenney_scifi", "doorOpen_001.ogg", 0, None, 0.1, "sfx"),
    ("mech/carga_oscura", "kenney_scifi", "spaceEngineLarge_000.ogg", 0, 3.2, 0.6, "sfx"),
    # Jingles y musica.
    ("musica/victoria", "music_dark_scifi", "victory.ogg", 0, None, 0.3, "jingle"),
    ("musica/derrota", "kenney_digital", "lowThreeTone.mp3", 0, None, 0.1, "jingle"),
    ("musica/base", "music_dark_scifi", "title.ogg", 0, None, 0, "music"),
    ("musica/combate", "music_space_battle", "space_battle_bpm130_0.ogg", 0, None, 0, "music"),
    (
        "musica/jefe",
        "music_robotic_battlefield",
        "Friendly_Talk_On_a_Robotic_Battlefield_0.ogg",
        0,
        None,
        0,
        "music",
    ),
]

# Los disparos de bala, la hoja vibratoria y sus impactos no salen de aqui: se
# disenan por capas en tools/audio/design.py (OBS-029). Aqui solo se apuntan
# en los creditos.
DESIGNED = "tools/audio/design.py"


def fetch():
    for pack, info in SOURCES.items():
        folder = os.path.join(SRC, pack)
        os.makedirs(folder, exist_ok=True)
        name = info["file"].rsplit("/", 1)[-1].replace("%20", "_")
        path = os.path.join(folder, name)
        if not os.path.exists(path):
            print("descargando", info["file"])
            with urllib.request.urlopen(info["file"]) as response:
                data = response.read()
            with open(path, "wb") as out:
                out.write(data)
        if name.endswith(".zip"):
            dest = os.path.join(folder, "files")
            os.makedirs(dest, exist_ok=True)
            with zipfile.ZipFile(path) as z:
                for entry in z.infolist():
                    flat = entry.filename.replace("\\", "/").split("/")[-1]
                    if entry.is_dir() or flat.startswith(".") or ".." in flat:
                        continue
                    if flat.lower().endswith((".ogg", ".wav", ".mp3", ".txt")):
                        with open(os.path.join(dest, flat), "wb") as out:
                            out.write(z.read(entry))


def source_path(pack, name):
    for candidate in (os.path.join(SRC, pack, "files", name), os.path.join(SRC, pack, name)):
        if os.path.exists(candidate):
            return candidate
    raise FileNotFoundError("%s/%s (falta --fetch?)" % (pack, name))


def read_mono(path):
    data, rate = sf.read(path, always_2d=True)
    x = data.mean(axis=1)
    if rate != RATE:
        # Remuestreo lineal: los paquetes vienen en 44.1 o 48 kHz.
        t = np.arange(0, len(x) * RATE / rate) * rate / RATE
        x = np.interp(t, np.arange(len(x)), x)
    return x


def active_rms_db(x):
    peak = np.max(np.abs(x)) + 1e-12
    frame = max(1, int(RATE * 0.01))
    env = np.sqrt(np.convolve(x**2, np.ones(frame) / frame, mode="same"))
    active = env > peak * 0.01
    seg = x[active] if active.any() else x
    return 20 * np.log10(np.sqrt(np.mean(seg**2)) + 1e-12)


def normalize(x, kind):
    gain_db = TARGET[kind] - active_rms_db(x)
    peak_db = 20 * np.log10(np.max(np.abs(x)) + 1e-12)
    gain_db = min(gain_db, CEILING_DB - peak_db)
    return x * 10 ** (gain_db / 20), gain_db


def cut(x, start, length, fade):
    x = x[int(start * RATE) :]
    if length is not None:
        x = x[: int(length * RATE)]
    # Quita el silencio del final.
    peak = np.max(np.abs(x)) + 1e-12
    loud = np.where(np.abs(x) > peak * 0.003)[0]
    if len(loud):
        x = x[: loud[-1] + 1]
    if fade > 0:
        n = min(len(x), int(fade * RATE))
        x = x.copy()
        x[-n:] *= np.linspace(1.0, 0.0, n) ** 2
    # Entrada de 2 ms para que no chasquee.
    n = min(len(x), int(0.002 * RATE))
    x[:n] *= np.linspace(0.0, 1.0, n)
    return x


def write(rel, x):
    path = os.path.join(OUT, rel + ".ogg")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sf.write(path, x.astype(np.float32), RATE, format="OGG", subtype="VORBIS")
    return path


def main():
    if "--fetch" in sys.argv:
        fetch()
    credits = []
    music_gain = {}
    for rel, pack, name, start, length, fade, kind in CLIPS:
        info = SOURCES[pack]
        credits.append((rel, "%s · %s" % (info["name"], name), info["author"], info["page"]))
        if kind == "music":
            # La musica se copia tal cual (libsndfile se cae al recodificar un
            # OGG largo) y su volumen se ajusta en el juego: data/sounds.json.
            src = source_path(pack, name)
            path = os.path.join(OUT, rel + ".ogg")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(src, "rb") as f_in, open(path, "wb") as f_out:
                f_out.write(f_in.read())
            x = read_mono(src)
            gain = TARGET[kind] - active_rms_db(x)
            music_gain[rel] = round(gain, 1)
            print("%-26s %6.1f s  volumen_db %+5.1f (en el juego)" % (rel, len(x) / RATE, gain))
            continue
        x = cut(read_mono(source_path(pack, name)), start, length, fade)
        x, gain = normalize(x, kind)
        write(rel, x)
        print("%-26s %6.2f s  %+5.1f dB  <- %s/%s" % (rel, len(x) / RATE, gain, pack, name))
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from design import DESIGNS

    for rel, _recipe, _params in DESIGNS:
        credits.append((rel, "diseñado por capas (%s)" % DESIGNED, "MechForge", ""))
    lines = [
        "# Créditos del sonido",
        "",
        "Generado por `tools/audio/curate.py`. Todo es **CC0** (dominio público, "
        "https://creativecommons.org/publicdomain/zero/1.0/) o se sintetizó aquí "
        "(`tools/audio/design.py`). Los créditos no son obligatorios con CC0, pero se "
        "dejan por agradecimiento y para saber de dónde sale cada archivo.",
        "",
        "| Archivo | Origen | Autor | Página |",
        "|---|---|---|---|",
    ]
    for rel, origin, author, page in credits:
        lines.append("| `%s.ogg` | %s | %s | %s |" % (rel, origin, author, page))
    with io.open(os.path.join(OUT, "CREDITOS.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print(json.dumps({"archivos": len(credits), "volumen_musica": music_gain}))


if __name__ == "__main__":
    sys.stdout.reconfigure(line_buffering=True)
    main()
