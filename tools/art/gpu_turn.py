"""Turno de la tarjeta: el arte cede la GPU a una junta en vivo.

La RTX 4050 (6 GB) la comparten el arte (SDXL, pico de 3 a 5 GB) y la
transcripcion de juntas en vivo (trabajador_gpu.py del puente, puerto 8766),
que solo carga su modelo con 2500 MiB libres. El 2026-11-23 una tanda de
armas tiro una junta. Sin protocolo nuevo ni tocar el puente (que llega por
Syncthing desde la laptop): hay junta si en la GPU hay un proceso cuya linea
de comando lleva trabajador_gpu.py.

Uso en un script de generacion:
    turn = gpu_turn.Turn(lambda: sd.load_pipeline("fp8", controlled="inpaint"))
    image = turn.pipe()(prompt=...)   # antes de cada imagen
Si empieza una junta, Turn suelta el pipeline, espera a que termine y lo
vuelve a cargar; la imagen sigue donde iba. No guardar otra referencia al
pipeline fuera de Turn: no se podria soltar la memoria.
"""

import gc
import subprocess
import time

import psutil

WORKER = "trabajador_gpu.py"
POLL_SECONDS = 30


def meeting_pids():
    """PIDs que estan en la GPU y son el trabajador de las juntas."""
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-compute-apps=pid", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=20,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    found = []
    for word in out.split():
        if not word.strip().isdigit():
            continue
        pid = int(word)
        try:
            if any(WORKER in part for part in psutil.Process(pid).cmdline()):
                found.append(pid)
        except (psutil.Error, OSError):
            continue
    return found


def meeting_on():
    return bool(meeting_pids())


class Turn:
    """El pipeline, que se suelta mientras haya junta."""

    def __init__(self, load):
        self._load = load
        self._pipe = None

    def pipe(self):
        if meeting_on():
            self._release()
            print("junta en vivo: suelto la tarjeta y espero", flush=True)
            while meeting_on():
                time.sleep(POLL_SECONDS)
            print("junta terminada: vuelvo a cargar", flush=True)
        if self._pipe is None:
            self._pipe = self._load()
        return self._pipe

    def _release(self):
        if self._pipe is None:
            return
        import torch

        self._pipe = None
        gc.collect()
        torch.cuda.empty_cache()
