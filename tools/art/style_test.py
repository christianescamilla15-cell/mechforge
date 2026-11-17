"""Genera mechs completos de referencia, uno por elemento, con el estilo
aprobado (tools/art/style.py). Sirve para comprobar que el estilo se mantiene
al cambiar de elemento, de semilla o de ajustes.

Solo texto a imagen con el modelo base; sin control de silueta.
Las imagenes van a art_raw/style/ (carpeta ignorada por git).

Uso:
  tools/art/run.ps1 tools/art/style_test.py                  # los tres elementos
  tools/art/run.ps1 tools/art/style_test.py --only heat --seeds 11 12 13
"""

import argparse
import time
from pathlib import Path

import torch
from diffusers import AutoencoderKL, EulerAncestralDiscreteScheduler, StableDiffusionXLPipeline
from huggingface_hub import hf_hub_download

import style

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art_raw" / "style"


def load_pipeline(offload):
    checkpoint = hf_hub_download(style.MODEL_REPO, style.MODEL_FILE)
    vae = AutoencoderKL.from_pretrained(style.VAE_REPO, torch_dtype=torch.float16)
    pipe = StableDiffusionXLPipeline.from_single_file(
        checkpoint, vae=vae, torch_dtype=torch.float16, use_safetensors=True
    )
    pipe.scheduler = EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config)
    # El UNet ocupa unos 5 GB en 16 bits y en esta laptop quedan unos 4 GB de
    # VRAM libres. Si no cabe, el controlador lo pasa a memoria compartida y
    # cada imagen tarda mas de 10 minutos (medido el 2026-11-16).
    if offload == "fp8":
        # Pesos guardados en 8 bits y calculo en 16: el UNet baja a ~2.6 GB.
        pipe.unet.enable_layerwise_casting(
            storage_dtype=torch.float8_e4m3fn, compute_dtype=torch.float16
        )
        pipe.enable_model_cpu_offload()
    elif offload == "group":
        # Solo unos pocos bloques del UNet en la GPU a la vez.
        pipe.unet.enable_group_offload(
            onload_device=torch.device("cuda"),
            offload_device=torch.device("cpu"),
            offload_type="block_level",
            num_blocks_per_group=2,
        )
        for part in (pipe.text_encoder, pipe.text_encoder_2, pipe.vae):
            part.to("cuda")
    elif offload == "sequential":
        pipe.enable_sequential_cpu_offload()
    else:
        pipe.enable_model_cpu_offload()
    pipe.vae.enable_tiling()
    pipe.vae.enable_slicing()
    return pipe


def progress_printer(total_steps):
    """Avisa cada 5 pasos con los segundos transcurridos, para ver si va lento."""
    state = {"last": time.time()}

    def on_step(pipe, step, timestep, kwargs):
        if (step + 1) % 5 == 0 or step == 0:
            now = time.time()
            print(
                "    paso %d/%d  (+%.0f s)" % (step + 1, total_steps, now - state["last"]),
                flush=True,
            )
            state["last"] = now
        return kwargs

    return on_step


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=sorted(style.ELEMENT_COLORS), help="un solo elemento")
    parser.add_argument("--seeds", type=int, nargs="+", default=[101, 102])
    parser.add_argument("--steps", type=int, default=style.STEPS)
    parser.add_argument("--cfg", type=float, default=style.CFG)
    parser.add_argument("--width", type=int, default=style.SIZE)
    parser.add_argument("--height", type=int, default=style.SIZE)
    parser.add_argument(
        "--offload", choices=["fp8", "group", "sequential", "model"], default="fp8"
    )
    parser.add_argument(
        "--variant", choices=["approved", "clean"], default="approved", help="estilo del prompt"
    )
    parser.add_argument("--extra", default="", help="etiquetas extra para el sujeto")
    parser.add_argument("--tag", default="", help="sufijo para el nombre de los archivos")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    started = time.time()
    pipe = load_pipeline(args.offload)
    print("modelo cargado en %.0f s" % (time.time() - started), flush=True)

    subject = style.SUBJECT_WHOLE_MECH
    if args.extra:
        subject += ", " + args.extra
    elements = [args.only] if args.only else list(style.ELEMENT_COLORS)
    for element in elements:
        prompt = style.prompt(subject, style.ELEMENT_COLORS[element], args.variant)
        for seed in args.seeds:
            started = time.time()
            image = pipe(
                prompt=prompt,
                negative_prompt=style.NEGATIVE,
                num_inference_steps=args.steps,
                guidance_scale=args.cfg,
                width=args.width,
                height=args.height,
                generator=torch.Generator("cpu").manual_seed(seed),
                callback_on_step_end=progress_printer(args.steps),
            ).images[0]
            name = "%s_%d%s.png" % (element, seed, ("_" + args.tag) if args.tag else "")
            image.save(OUT / name)
            peak = torch.cuda.max_memory_allocated() / 2**30
            print(
                "ok  %s  %.0f s  pico VRAM %.1f GB" % (name, time.time() - started, peak),
                flush=True,
            )
    print("LISTO en", OUT)


if __name__ == "__main__":
    main()
