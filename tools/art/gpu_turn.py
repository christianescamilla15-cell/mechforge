"""Turno de la tarjeta: el arte cede la GPU a una junta en vivo.

La RTX 4050 (6 GB) la comparten el arte (SDXL, pico de 3 a 5 GB) y la
transcripcion de juntas en vivo (trabajador_gpu.py del puente, puerto 8766),
que al empezar una junta espera hasta 90 s a tener 2500 MiB libres y, si no,
la da por perdida. El 2026-11-23 una tanda de armas tiro una junta. Sin
protocolo nuevo ni tocar el puente (llega por Syncthing desde la laptop):

- hay junta si el trabajador tiene una conexion ESTABLISHED con la laptop en
  el puerto 8766: la laptop solo la abre durante una junta, y se abre antes
  de que el trabajador pida la memoria (su registro: "conectado" y "tomando
  la tarjeta" en el mismo segundo);
- tambien, por si acaso, si el trabajador esta en la GPU (nvidia-smi).

Uso en un script de generacion:
    turn = gpu_turn.Turn(lambda: sd.load_pipeline("fp8", controlled="inpaint"))
    tokenizer = turn.pipe().tokenizer
    image = turn.run(seed, prompt=..., image=..., ...).images[0]
`run` mira la junta antes de la imagen y cada pocos pasos durante ella: si
empieza una, corta la imagen, suelta el pipeline, espera a que acabe, lo
vuelve a cargar y repite la imagen con la misma semilla. No guardar otra
referencia al pipeline fuera de Turn: no se podria soltar la memoria.
"""

import gc
import subprocess
import time

import psutil

WORKER = "trabajador_gpu.py"
BRIDGE_PORT = 8766
POLL_SECONDS = 20
## Durante una imagen se mira como mucho cada tantos segundos.
CHECK_EVERY = 3.0


def _is_worker(pid):
    try:
        return any(WORKER in part for part in psutil.Process(pid).cmdline())
    except (psutil.Error, OSError):
        return False


def _bridge_open():
    """El trabajador conectado a la laptop: hay junta (o esta empezando)."""
    try:
        connections = psutil.net_connections(kind="tcp")
    except (psutil.Error, OSError):
        return False
    for c in connections:
        if c.status == psutil.CONN_ESTABLISHED and c.raddr and c.raddr.port == BRIDGE_PORT:
            if c.pid and _is_worker(c.pid):
                return True
    return False


def _on_gpu():
    """El trabajador esta en la GPU."""
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-compute-apps=pid", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=20,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return any(word.isdigit() and _is_worker(int(word)) for word in out.split())


def meeting_on():
    return _bridge_open() or _on_gpu()


class MeetingStarted(Exception):
    """Empezo una junta a media imagen."""


class Turn:
    """El pipeline, que se suelta mientras haya junta."""

    def __init__(self, load):
        self._load = load
        self._pipe = None
        self._checked = 0.0

    def pipe(self):
        if meeting_on():
            self._wait_out()
        if self._pipe is None:
            self._pipe = self._load()
        return self._pipe

    def run(self, seed, **kwargs):
        """Una imagen con su semilla; si empieza una junta a media imagen, se
        corta, se espera y se repite igual."""
        import torch

        while True:
            pipe = self.pipe()
            kwargs["generator"] = torch.Generator("cpu").manual_seed(seed)
            kwargs["callback_on_step_end"] = self._step
            cut = False
            try:
                return pipe(**kwargs)
            except MeetingStarted:
                cut = True
            # Fuera del except: su traza guarda el pipeline y no dejaria
            # soltar la memoria.
            pipe = None
            if cut:
                self._wait_out()

    def _step(self, _pipe, _step, _timestep, callback_kwargs):
        now = time.time()
        if now - self._checked >= CHECK_EVERY:
            self._checked = now
            if _bridge_open():
                raise MeetingStarted()
        return callback_kwargs

    def _wait_out(self):
        self._release()
        print("junta en vivo: suelto la tarjeta y espero", flush=True)
        while meeting_on():
            time.sleep(POLL_SECONDS)
        print("junta terminada: vuelvo a cargar", flush=True)

    def _release(self):
        if self._pipe is None:
            return
        import torch

        self._pipe = None
        gc.collect()
        torch.cuda.empty_cache()
